# AIF research, round 4: the sanitizer gate, copies counted as literals, and prompt 2

Written 2026-11-22, continuing `RESEARCH_ROUND3.md`. **Nothing is built.** The numbers come from
the release host at `5757802`, on macOS arm64. Every probe is inline.

## 1 · The sanitizer gate cannot see the slab (it covers F10)

`tools/sanitizer_smoke.py` is the existing check for use-after-free. It builds a fixture to LLVM
IR, links it with `clang -fsanitize=address` against the runtime **sources**, and runs it. Since
the slab became the default (2026-10-24), that check is blind to the very class it exists for.
`rt_base_alloc` and `rt_free` recycle slab blocks themselves, so ASan never sees an allocation or a
free of anything 512 B or smaller. Nothing turns the slab off under ASan: the runtime does not
test `__has_feature(address_sanitizer)` or `__SANITIZE_ADDRESS__`, and the tool does not set
`PRISMIO_SLAB=0`.

**Read after free** (C, against the runtime: allocate 48 B, free it, allocate again, read the old
pointer):

| Run | Result |
|---|---|
| default (slab on) | `read after free: 7 (same block: 1)`: the program silently read the new owner's data |
| `PRISMIO_SLAB=0` | `ERROR: AddressSanitizer: heap-use-after-free` |

**Leaks** (round 2's factory probe, which leaks 200 blocks under `--verify`):

| Run | LeakSanitizer |
|---|---|
| default (slab on) | nothing reported |
| `PRISMIO_SLAB=0` | `9600 byte(s) leaked in 200 allocation(s)` |

**Second gap:** the tool's link does not include std. A program that imports `std.string` fails to
link (`_concat__String_String` undefined), because std ships as `.plib` bitcode and `-o x.ll` writes
only the program's own functions. Building from a working directory inside the checkout compiles
std from source into the `.ll`, which links. All four of the tool's current fixtures avoid std.

**The fix, and it is small:**

1. In `runtime/lang_runtime.c`, leave `PRISMIO_SLAB_ACTIVE` undefined when the runtime is compiled
   with ASan or TSan. A compile-time switch, so no environment variable can be forgotten.
2. In the tool, build each program with std from source (a working directory inside the checkout),
   or link the `.plib`s' bitcode.
3. Run every fixture in `ownership_probes` and the research probes, not four files. Run on macOS
   as well as Linux: the macOS toolchain has ASan, and this session used it.

That makes F10 ("a read-after-free detector") mostly done. **It should be build item 0**, before
any change that moves a release earlier. A balanced `--verify` ledger cannot see a read after
free, and today ASan cannot see one either.

## 2 · Copies counted as literals: two small leaks with one cause

Both remaining leaks the audit marked "not isolated" in the small range turn out to have the same
shape. **A conversion that copies a String is still treated as if the result might be a literal**,
so whatever holds the copy releases nothing.

| Shape | Leak | Where the copy happens |
|---|---|---|
| `let text: String? = "here"` (`test_67`, line 41) | 1 block, 5 B, allocated by `str_own` in `main` | the literal is copied into a `String?`, which has no tag bit for a literal, so it has to be owned |
| `words.push("a-literal…")` then `kw.push(words[0])` | 1 block | pushing a String view copies it into a block of its own, but `kw` declines to release its elements because one of them "may be a literal" |

Controls: `kw.push(words[0].clone())` reads 7 / 7 / 0, and so does making the first push an owned
string. The engine already records the second case (`vsCopiedOnKeep`, `src/aifcore/constraints.psm`:
"pushed into a container, it is copied into a block of its own"). The container's check for a
possible literal does not consult it, and the `String?` conversion has no equivalent marker.

**The fix:** treat each copying conversion as a fresh owned allocation in the facts. A literal
copied into a `String?`, a view copied on keep, and any other `str_own` at a boundary.
`binder_return_probe` and `option_methods_probe` (1 block each) are probably this shape too, as is
KNOWN_ISSUES' "A container that may be handed a string literal releases none of its elements".
Confirm each after the fix.

## 3 · `test_127`'s six blocks

Symbolised with `--verify -g`, `PRISMIO_VERIFY_TRACE=1` and `atos`:

- Four of the blocks are `Tree.Node`s built in `add(sink t: Tree, k: Int)`, from the match binders
  of a consumed `t`, and in `makeTree`. That is the dying-scrutinee shape: a binder taken out of a
  value that is dead after the match. **Item 2 (move at last use)** should cover it.
- Two blocks belong to `makeNested()`'s inner `Maybe<String>` (`strClone` in `makeInner`), passed
  as a temporary: a nested payload enum. It is probably the mixed-storage payload (round 3 §1,
  storage agreement). Re-run after both items land.

## 4 · Prompt 2: are context-sensitive library sites still needed?

**What a stored element read means.** It shares. Storing it does not copy, except for Strings:

```prismio
keep.push(all[0])         // all: Vec<Vec<Int>>
keep[0].push(9)           // all[0].length is now 4: the two containers share one Vec
fav.push(items[0])        // items: Vec<Item>
fav[0].qty = 5            // items[0].qty is now 5: they share one struct
kw.push(words[0])         // a String is copied into a block of its own
```

| Shared value | `--verify` | Why |
|---|---|---|
| a struct in two Vecs | 6 / 6 / 0 | the struct site is T3 and **counted**; compiler-allocated struct sites get headers |
| a `Vec` in two Vecs | 6 / 5 / **1** | a genuine share, and a list has no header, so it is `rc:none` |
| a String in two Vecs | copied, so not shared (the leak in that probe is §2's) | |

**Conclusion.** A String site never reaches Shared by being genuinely held twice, because storing a
String view copies it. It is Shared only by inheritance (`A-STORE`, `A-RETAIN`, a view-store
`A-CONTAIN`), by a global (`A-ESCAPE`) or by an opaque extern (`E-OPAQUE`). The build list removes
each of those: items 3, 2, 5, 1 and the extern rule. **Once those land, context-sensitive sites
for String producers (`concat`, `toUpper`, …) are not needed**, and F19 can wait. Re-measure the
library-site sensitivity cases after items 2 and 3 to confirm. `concat_argument_probe.psm` and
the "Library producers share one allocation site" entry in KNOWN_ISSUES are the cases to check.

**What is left: a count for `Vec`.** A Vec held by two containers is a genuine share with no
count. `RtList` has two 4-byte padding holes: after `elem_own`, at offset 20, and after `fused`,
at offset 60. A count fits in the first one **without growing the header**. The release paths
(`list_release` and container teardown) would decrement it for a list site whose tier is T3, the
same way `rc_release` works for structs today, and the engine would give `rc` instead of `rc:none`
to such list sites. If F13 (the compact header) lands first, the count belongs in its hot part:
data, len, cap and count, 24 bytes.

## 5 · Additions to the build list

| Rank | Build | Prize | Cost |
|---|---|---|---|
| **0** | **The sanitizer gate sees the slab, and links std** (§1) | turns ASan back into a working read-after-free detector, before release-moving changes land | small: one `#if` in the runtime, the tool's build and its list of fixtures |
| with the extern rule | **Copies are owned allocations** (§2) | `test_67` 1 → 0, the literal-in-container shape, probably both binder probes | small: engine and oracle |
| after item 3 | **A count for a genuinely shared `Vec`** (§4), in `RtList`'s padding | the last `rc:none` that is a real share | medium: runtime release paths, engine, oracle |
| deferred | F19, context-sensitive library sites | probably unnecessary after items 2, 3 and 5; re-measure first | |
