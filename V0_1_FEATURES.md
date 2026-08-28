# v0.1 — the feature work

The plan for the language features v0.1 still owes. `TODO.md` is the *compiler
improvement* plan (measured optimisations, defects); this file is the *language
surface* plan. They share the gate in §2 and neither supersedes the other.

**The published roadmap disagrees with this file and must be corrected.**
Corrected for `impl` and traits on 2026-08-29; `../docs/content/roadmap.md` now
carries "Method call syntax and `impl` blocks — Implemented" and "Traits and
bounded generics — Implemented", with `language/methods.md` and a rewritten
`language/traits.md` behind them. Still wrong, and still to be fixed by whichever
task lands them: "Closures — Coming Soon", "Package manager — Coming Soon".

---

## 1 · The bar

The one from `V1_GAP_ANALYSIS.md`, unchanged:

> A competent third party who has never read the compiler's source can write a
> non-trivial program, build it, ship it, and debug it — without working around
> the compiler, without reading its internals to find out what's implemented,
> and without hitting silent wrong answers.

Plus a v0.1-specific one: **a user should be able to write `list.sort()` and
`text.trim()`**, the way they would in Kotlin or Swift. Not because method
syntax is important in itself, but because it is the difference between a
standard library that reads like one and a pile of prefixed free functions.

**Small is fine; wrong-shaped is not.** Every item below should land in the
smallest form that has the *right structure* — the version a later release can
grow without a rewrite. A trait system that handles one bound is v0.1. A trait
system that cannot ever express two is not.

---

## 2 · The gate — after **every** task, no exceptions

### 2.1 · Correctness first

```bash
./tools/bootstrap.sh --compiler build/<lastgood> --out build/<next>
./tools/bootstrap.sh --compiler build/<next>     --out build/<next2>
./build/<next> build src/main.psm -o build/a.ll
./build/<next2> build src/main.psm -o build/b.ll
cmp build/a.ll build/b.ll                                    # fixpoint

PRISMIO=$PWD/build/<next2> python3 tests/test_runner.py      # 175/175 or higher
python3 tools/aif_differential.py --compiler build/<next2>   # 18/18
python3 tools/check_source_lists.py
git diff --check
```

Plus, for anything touching allocation or the drop path:

- the `--verify` sweep over `tests/`, `aif/corpus/` and
  `aif/evidence/xlang/prismio/` — **`violations` first**, then `released`
  against `allocated`;
- **AddressSanitizer on every program whose emitted IR changed.** `--verify`
  balances on a read-after-free and reports `0 violation(s)` while the program
  segfaults — that is how a heap corruption survived on two platforms until
  2026-08-29. The recipe:

```bash
prismio build <src> -o out.ll
clang -fsanitize=address -g -O1 out.ll runtime/lang_runtime.c \
      runtime/program_support.c -Iruntime -o probe && ./probe
```

### 2.2 · The five-arm benchmark

**Every task ends with all five arms**, on the whole corpus, 25 runs,
checksums enforced:

| arm | what it is |
|---|---|
| **old Prismio** | the last-good compiler, before this task |
| **new Prismio** | after this task |
| **Prismio hand-tuned** | the same program written the way a Prismio expert would |
| **Rust idiomatic** | the honest peer |
| **Rust hand-tuned** | the ceiling |

```bash
python3 tools/milestone_bench.py --old build/<lastgood> --new build/<next2> \
    --runs 25 --label "<task>" --json aif/evidence/results-<task>.json

python3 aif/evidence/xlang/bench.py --compiler build/<next2> --runs 25 \
    --json aif/evidence/xlang/results-<task>.json
```

**The harness supports four of the five arms today.** `milestone_bench.py` gives
old / new / Rust idiomatic / Rust hand-tuned, and `xlang/bench.py` adds the Rust
arena arm. What is missing is a **Prismio hand-tuned arm for every corpus
program** — only `g1_dataview_tuned.psm` and `g2_tuned.psm` exist, against
`g1_tuned.rs`, `g2_tuned.rs`, `g3_tuned.rs` and more on the Rust side. Filling
that in is part of §4's corpus work, and until it is filled the fifth column is
"absent", never "equal".

**Rules that have already been paid for:**

- **Never run the suite and benchmarks concurrently.** They share fixed paths
  and caches; contention shows up as `aif exited -9` cascades.
- **Do not claim Prismio beats Rust without a controlled side-by-side.** When it
  loses, read the emitted IR *and the machine code* and name a concrete cause.
- **Price on the corpus, never on a model.** A synthetic model mispredicted the
  real program twice on 2026-08-29 — once by omitting a level of indirection,
  once by reversing sign (1.49× on the model, 1.80× *slower* on real g4).
- **Repeat before attributing.** A single sample plus a plausible mechanism is
  how g1's "1.083× regression" got written down; it was noise.

---

## 3 · The features

Ordered so each one makes the next cheaper. Every entry names **the seam**,
because finding it is most of the work.

### 3.1 · Method call syntax — **DONE 2026-08-29**

`x.f(a)` is `f(x, a)`, rewritten in `semaExpr` before overload resolution. The
parser already accepted the shape; the receiver was being read off as the name
and dropped. Everything downstream sees an ordinary call.

**Known limit**: a postfix `.` directly on a literal (`"a,b".contains(",")`) is
still a parse error — the receiver must be a name. Parser gap, worth closing
with §3.6.

### 3.2 · `impl` blocks — **DONE 2026-08-29**

Landed as predicted: a naming construct, spliced into the module's declaration
chain by `parseModule`, with the whole feature in the parser (an IMPL_DECL, a
`p.implType` that types a bare `self`, and the splice). Nothing downstream
changed. `std/string.psm` gained a curated 30-method `impl String`; the `str*`
prefix stays until §3.5. A generic `impl` is rejected rather than mis-parsed.

Also closed here, because `impl String` is unusable without it: §3.1's known
limit. A postfix `.` on a literal was a parse error because `parsePrimary`
returned a literal *without offering its suffixes* — nothing was deciding that a
literal has no members, the question was never asked. `(a + b).x` and
`[1, 2, 3][1]` were the same gap and work now too.

**BLOCKED 2026-08-30, and on a missing feature rather than on the work.** The
migration is not a rename. Measured on the tree, not reasoned about:

- A recursive struct field already compiles: `struct Node { value: Int, next: Node? }`.
- A typed linked list already works end to end -- build three nodes, walk them
  with `expect`, sum them. So "recursive types" is *not* what is missing.
- But a typed struct field **owns** what it holds. Two fields referring to one
  node is `error: use of moved value`:

```prismio
let shared = Node { name: "shared", left: none, right: none }
let parent = Node { name: "parent", left: shared, right: shared }
//                                                       ^^^^^^ use of moved value
```

The AST is a *shared graph*: a node is reachable from `child1`, from `next`, from
the decl index and from `irFunctionBody` at the same time. Affine ownership cannot
express that, which is precisely why these fields are `Ptr` -- `Ptr` is how the
compiler opts *out* of ownership for a graph, not an accident of style.

So what 3.6 needs is a **non-owning typed reference** (`&T`, a borrow that can be
stored in a field), which the language does not have. Until it does, replacing
`Ptr` with `ASTNode?` would turn every shared node into a move error, and forcing
it through would make the AST an owned graph and double-free it.

That is a language design task, not a migration, and it is larger than the rest of
v0.1 put together. The four resolved "central finding" rows stay resolved; the two
live ones are this one row twice.

**The original plan, kept:**

**Cheap now, because §3.1 exists.** A method *is* a free function whose first
parameter is the receiver, so an `impl` block is a **naming construct**, not a
second dispatch mechanism.

```prismio
impl String {
    fn trim(self) -> String { ... }
}
```

- **Seam**: parse `impl <Type> { fn ... }` as a top-level declaration and lower
  each method to a plain `fn name(self: Type, ...)`. `impl` and `trait` are
  **already reserved keywords** in `src/lexer/token.psm` and
  `src/parse/parser.psm`.
- **Why it matters beyond syntax**: it gives the standard library short names
  without a rename. `std/string.psm` has 46 `str*`-prefixed functions and **848
  call sites in `src/` alone** — the prefix exists because there is no
  namespacing. `impl String { fn trim(self) }` delegating to `strTrim` is
  additive and costs no churn.
- **Update**: `std/string.psm`, `std/map.psm`, `std/io.psm` gain `impl` blocks;
  the docs' language reference gains a page.

### 3.3 · Traits, and bounded generics — **DONE 2026-08-29**

`trait`, `impl <Trait> for <Type>`, one bound per type parameter, `Self`. A trait
is a **check, not a dispatch mechanism**: monomorphisation runs before type
checking reaches a body, so a bound is checked at the instantiation and the trait
method call is resolved by ordinary overload resolution. No dynamic dispatch, no
trait objects, no vtables. The bound rides in the type-parameter list's own text
as `T:Ord`; conformance is checked syntactically against the trait's signatures.

**The `Then:` clause below is NOT done, and is the next task:** `Map` is still a
linear-scan association list, `std` ships no `sort`, and `Map` has not been
re-benchmarked. `sort<T: Ord>` is now *writable* — `tests/test_87_traits.psm`
writes one and calls it as `xs.sortInPlace()` — but nothing in `std` provides it.

**The original plan, kept:**

The first thing that is **not** sugar. Method syntax and overloading already
cover ad-hoc polymorphism — `std.io` has 28 `print`/`println` overloads. What is
missing is *abstraction over behaviour*, and `std/map.psm` documents the exact
price in its own header:

> *"Association list, not a hash table, and the reason is a missing language
> feature rather than a shortcut."* … *"the only operation the language can
> perform on every `K` it is instantiated at, which is `=="`* … *"Keys must be
> comparable with `==`, which means scalar keys."*

So `Map` is a **linear scan** and rejects `String` and struct keys. That is the
concrete thing traits buy.

- **Smallest right-shaped version**: `trait` declarations with method
  signatures; `impl <Trait> for <Type>`; **one bound per type parameter**
  (`fn sort<T: Ord>(...)`), resolved statically at monomorphisation. No dynamic
  dispatch, no associated types, no blanket impls — but the syntax must not
  preclude them.
- **Seam**: monomorphisation (`src/sema/generics.psm`) already specialises before
  type checking reaches the body. A bound is a check *at instantiation*, which is
  exactly where the concrete type is known.
- **Then**: `Map` becomes a hash table, `sort<T: Ord>` becomes writable, and
  `list.sort()` works. **Re-benchmark `Map` explicitly** — the linear scan is a
  measured cost this is meant to remove.

### 3.4 · Closures — **DONE 2026-08-29**

`|x: Int| x > threshold` lowers to a struct holding the captures, a `call` whose
first parameter is that struct, and a struct literal at the use site; `f(x)`
inside the generic that received it is rewritten to `call(f, x)`. **No function
pointer, no vtable, no indirect call** — the same trick 3.1, 3.2 and 3.3 all used.

**The prediction below was wrong, and the reason is worth keeping.** "AIF has to
be taught what a capture *is*" — it did not, because *a capture is spelled as a
struct literal field*. `Closure$N { needle: needle }` moves an owned capture into
a field exactly the way any other struct literal moves a value into one, and AIF
already models that. **No change to `aif/` at all.** The lattice did not have to
learn what a capture is; the lowering arranged for there to be nothing new to
learn. The syntax work was the larger half.

What it costs is the default: a capture is **by value**, so an owned capture is
moved and the original binding is dead. Prismio has no way to hold a borrow in a
struct field, so by-value is the only sound default it can have today.

`std/list.psm` gains `sortBy`, `filter`, `mapInto`, `countWhere`, `anyOf`,
`allOf`, and `sort` becomes one line over `sortBy`.

**The original plan, kept:**

Needed for `list.sortBy { ... }`, `map`, `filter` — the second half of what
makes a standard library feel modern.

- **Seam**: capture analysis, then lowering to a struct plus a function pointer.
  AIF has to be taught what a capture *is* — a captured binding escapes into the
  closure, which is an escape route the lattice does not currently model. **This
  is the item most likely to be underestimated.** Do it after traits, and expect
  the ownership work to dominate the syntax work.

### 3.5 · Module namespacing and visibility — **PART DONE 2026-08-29, extended 2026-08-30**

**2026-08-30 — the qualifier is now the import path, and there are three
visibility levels.**

`semaFileQualifier` returned the file's *leaf*. It now returns the full import
path recorded by the merge: `std.string`, not `string`; `lexer.token`, not
`token`. Two independent reasons, and the second is the one that would have bitten
silently:

- **Leaves collide.** `src/ir/expr.psm` and `src/parse/expr.psm`, and
  `src/{ir,sema,ast}/types.psm` three ways over. `types.foo(...)` was genuinely
  ambiguous and the best resolution could do was report it.
- **The path is not the module.** `resolveImportPath` flattens the package on
  install — `std/string.psm` ships as `stdlib/string.psm`. A qualifier *derived*
  from the file would read `std.string` in a checkout and `stdlib.string` from an
  installed toolchain: every qualified `std` call resolving here and failing in
  the shipped compiler, with the whole suite green. So the merge **records** the
  logical name (`diag_set_file_module`, one field on the file registry) instead of
  re-deriving it. This is the one place the "no registry" principle had to give,
  and the reason is that the disk genuinely does not know the answer.

The dispatch had to learn dotted receivers: `std.string.f(x)` arrives with a
receiver that is itself a MEMBER_ACCESS. A local anywhere in the chain still wins
first, so `p.state.reset()` stays a method call.

Migration cost was near zero, because **nothing in `src/` or `std/` used a
qualified call** — every apparent use was a comment. Two lines in
`tests/test_90_modules.psm`, and 138 doc snippets unaffected. A leaf that names no
module now gets a signpost rather than "unknown identifier":

```
error: no module `string`
  note: a module is qualified by its full import path -- did you mean `std.string`?
```

**Visibility is now three levels, Kotlin-shaped**, replacing the single `priv`:

| spelling | scope | `i2` |
|---|---|---|
| *(nothing)* / `public` | everywhere — still the default | 0 |
| `private` | the declaring file | 1 |
| `internal` | the declaring package | 2 |

`internal` is the level that only became expressible once qualifiers were import
paths: "the same package" is the qualifier minus its last segment, and a leaf
carried no package to compare. `priv` is **gone** rather than kept as an alias —
v0.1 is unreleased, so nothing outside the tree holds it, and two spellings for
one level is surface to document and keep in step forever. The 23 markers were
renamed (22 in `std/`, one test fixture).

`protected` is **deliberately absent**. It means "this type and its subtypes", and
there is no inheritance here to give it a referent — Kotlin rejects it at top
level for the same reason. It would be a spelling whose only outcome is an error.

Still only accepted on `fn`/`extern fn`; on a type or a global it is still
rejected, for the original reason (the check lives in overload resolution).

---

**As of 2026-08-29:**

Landed: `module.name(...)` qualified calls, and `priv fn` for module-private
functions. The seam was cheaper than the plan expected — **`resolveImports`
needed no change at all.** Every node already keeps the `file` id it was parsed
with, which is why diagnostics name the right file, and that surviving id *is*
the qualifier: `semaFileQualifier(file)` is the path's leaf, and overload
resolution filters on it. No module registry to build, fill, reset or keep in
step with the merge. `priv` is one flag on the declaration and one comparison of
two `file` ids.

`priv` is **opt-in** rather than private-by-default, which is the opposite of most
languages and the only non-breaking spelling available: every cross-module call in
`src/` and every `std` function is public today. 22 std internals are now marked.

**NOT done, and the plan's premise for it is wrong.** "With namespacing,
`string.trim` is available and the `str*` prefix can retire" — the first half is
true and the second does not follow. `import m` still brings every name in
*unqualified*, so a `std/string.psm` that renamed `strTrim` to `trim` would claim
`trim`, `length`, `split`, `contains` and thirty more in the global namespace of
every importing program. That is **worse** than the prefix, not better. The prefix
cannot retire until an import stops being unqualified by default, and that is a
breaking change to every program that exists.

So the 848-call-site rename is not merely deferred, it is **blocked on a decision
this file has not made**: whether `import m` should stop meaning "and bring
everything into scope". Making that decision is the real remaining work in 3.5.

> **2026-08-30 — this framing is wrong, and the rename may not be needed.**
> `impl String` already exposes `length`, `trim`, `split`, `contains` and 29 more
> as *methods* (`std/string.psm:1274`), and a method lives in the **type's**
> namespace, so it claims no global name at all. `s.trim()` works today and needed
> no import change. The `str*` prefix is therefore not a wart awaiting a rename;
> it is the free-function layer underneath the methods. What the dump actually
> costs is narrower than "worse than the prefix": a same-signature collision is a
> hard compile error naming the std declaration, not a silent mis-resolution — so
> the cost is that `std` *claims* those names, not that anything breaks.

**The original plan, kept:**

`resolve_imports` flattens every module into one AST; file identity survives on
each node's `file` id, which is why diagnostics still name the right file, but
there is **no namespacing and no visibility**. That is why the standard library
is prefixed.

- **Seam**: `resolve_imports` in `src/main.psm`, plus name resolution in
  `src/sema/symbols.psm`.
- **Pairs with §3.2**: with namespacing, `string.trim` is available and the
  `str*` prefix can retire — but that is the 848-call-site rename, so it should
  happen *once*, deliberately, with byte-identical IR as the check.

### 3.6 · First-class pointers, and the parser gaps — **PART DONE 2026-08-29**

The parser gaps are closed (see §3.2). First-class pointers are not: `src/` still
has **757 `ptr_to_node`/`node_to_ptr`/`ptr_to_token`/`ptr_to_type` occurrences**
(counted 2026-08-30; the plan's 722 was stale).

Of `V1_GAP_ANALYSIS.md`'s six "central finding" rows, four are resolved and two
are live. Verified against the tree on 2026-08-29 rather than read off the notes:
`char_code()`'s 90-branch chain is gone; `str_equals(a, b) == 1` has **0**
occurrences and `String ==` is a deliberate rejection; self-forward-declaring
`extern fn` has **0** occurrences out of 488 distinct externs, all of which are
genuinely foreign; the `while (flag)` idiom is down to **one** site
(`src/main.psm:162`). What is left is the pointer punning and the hand-built
linked lists, which are the same row twice.

**The original plan, kept:**

`ASTNode.child1: Ptr` with `ptr_to_node`/`node_to_ptr` is the compiler routing
around its own missing feature. Also here: postfix `.` on a literal (§3.1), and
anything else `V1_GAP_ANALYSIS.md` §"central finding" lists as a workaround —
that table is the checklist.

### 3.7 · Package manager — **DONE 2026-08-30**

Deliberately last and deliberately small: a manifest, a lockfile, a local path
dependency, and a registry-shaped fetch that need not have a registry behind it
yet. **The structure is the deliverable**; the network is not.

All four landed, and nothing here opens a socket.

**A local path dependency** is a third argument, so it needed no new grammar --
UMS calls are positional strings and a `path =` form would have been new syntax for
one argument:

```ums
dependencies {
    implementation("json", "1.2.0", "../json")   // path
    implementation("http", "2.0.0")              // registry
}
```

It resolves against the directory holding `build.ums`, **not** the working
directory. Those differ whenever `prismio build` runs from a descendant, which the
discovery walk explicitly supports, so resolving against the cwd would make one
manifest mean different things depending on where it was invoked.

**A lockfile** at `.prismio/prismio.lock`, tab-separated with a header, one row per
dependency recording scope, name, constraint, source and what it resolved to. It is
written **before** the failure check, not after: a failed resolve is exactly when a
reader wants the file, and an unresolved row is written as `-` rather than omitted
so the row count matches the manifest.

**The registry-shaped fetch** is `umsFetchRegistry`, which has the shape of a fetch
and performs none. Everything around it -- model, constraint, lockfile row,
diagnostic -- is already correct, so standing up a registry later touches that one
function. Two new diagnostics: `UMS2210` (a path that names no directory) and
`UMS2211` (no registry configured, naming the third-argument form as the fix).

**Three runtime primitives had to exist first.** `std/fs` could read a file and not
write one, so a lockfile was unwritable: `write_file`, `make_directory` and
`directory_exists` are new in `runtime/program_support.c` with wrappers and
contracts in `std/fs.psm`. `directory_exists` is the interesting one -- without it
the only way to ask "does this directory exist" was `make_directory`, which answers
by *creating* it, so a mistyped path dependency would have silently succeeded. The
first draft of the resolver had exactly that bug.

**`ums/test_ums.psm` existed since UMS landed and the suite never ran it** -- the
whole manifest subsystem was unexercised in CI. It is registered now
(`run_ums_test`) and extended to cover resolution and the lockfile, including that
a missing path dependency does not create the directory it names. Suite: **192**.

**Gate:** 192/192; two-generation fixpoint identical; the committed seed still
builds a compiler whose generation matches that fixpoint; docs 141 snippets; ASan
clean. The corpus binaries *differ* by 240 bytes and that is the three new runtime
functions being linked in -- every corpus workload function
(`_integrate`, `_fade`, `_count_alive`, `_count_beyond`, `_build_system`) is
byte-identical at the instruction level, and g1's ledger is 10026/10026/0/0 either
side.

**One honest debt.** The UMS ledger goes from `1150 allocated, 639 released, 511
leaked, 0 violations` to `2112 / 637 / 1475 / 0`. By the metrics that are stable --
`released` and `violations` -- that is flat, and there is no new unsoundness. But
allocations doubled while releases did not move, so the resolver and lockfile code
releases nothing it allocates, in a subsystem that already leaked 44% of what it
took. The compiler is a short-lived process and this is the tree's existing
pattern, but it is debt rather than a clean result and belongs on TODO.md.

---

## 3.8 · The compiler's own source, in the language it now has — **DONE 2026-08-30**

Not in the original plan. Added because §4's standing instruction is that the tree
should be written in the language as it stands, and `src/` was the largest thing in
it still written as though none of v0.1 had happened.

**Visibility, applied to all 579 top-level functions.** Every one was public. A
use-analysis over `src/` put 322 of them in one file and 164 in one package:

| | before | after |
|---|---|---|
| `private` | 0 | **322** |
| `internal` | 0 | **164** |
| public | 579 | **94** |

The public surface of the compiler fell by 84%, and **the emitted IR is
byte-identical** at every step -- which is the proof that visibility is a
resolution-time check and nothing else. Zero build errors on the first attempt, so
the analysis was right about all 486.

**Method syntax for the `Parser` receiver.** The `parser` prefix was a manual
namespace, exactly what `impl` replaces -- the same story as `str*` and
`impl String`. 23 functions, 380 occurrences, 5 files: `parserCurrent(p)` is
`p.current()`, and `src/parse/parser.psm`'s run is a real `impl Parser` block.

Two names could not lose the prefix. `expect` is sema's optional-unwrap builtin and
`match` is the match statement's keyword, so those became `expectToken` and
`matchToken` rather than shadowing either.

**A feature gap this uncovered, and closed: visibility and `impl` did not compose.**
`impl` is the natural home for the helpers most worth marking `private`, and the
parser rejected any marker inside a block -- "an `impl` block holds `fn`
declarations, found `internal`". So using one meant giving up the other. The impl
body loop now reads a visibility marker exactly as a top-level declaration does, and
the marker means the same thing, because a method *is* a free function whose first
parameter is the receiver and carries the same `file` id either way. Landed in the
two-step order the rule requires -- teach the frontend, refresh the seed, then use it
in `src/` -- with `tests/neg_54_private_method.psm` pinning the rejection.

`impl` blocks can hold a function with no `self`, which is what made this possible
without reordering: the three non-receiver functions inside `parser.psm`'s run stay
where they are, and g5 already showed that moving a function changes emission order
and with it the generated code.

**Gate:** 193/193; fixpoint identical; seed refreshed and its generation matches the
fixpoint; every corpus program's own functions byte-identical against the
session-start compiler (12/12 on g1, g3, g6).

### 3.8.1 · The measurement, and a use-after-free the suite could not see

**Runtime performance is unchanged, and that is proven rather than measured.**
Across the whole session -- qualifier redesign, three visibility levels, the
`no_stack` split, 486 markers in `src/`, the `impl Parser` rewrite, and the corpus
rewrite -- **596 of 596 generated program functions are byte-identical** to the
session-start compiler's output:

| g1 | g2 | g3 | g4 | g5 | g6 | g9 |
|---|---|---|---|---|---|---|
| 84/84 | 81/81 | 84/84 | 85/85 | 92/92 | 92/92 | 78/78 |

So every timing delta in the benchmark is noise, and **g5 proves it**: it read
**1.261x "regressed"** here and **0.692x "improved"** earlier in the same session,
on code that is byte-identical in both directions. Its number carries no
information and a sign test on it is meaningless.

Compile time is **1.055x** (median of 12 interleaved self-host runs, 1.065x on the
minimum, so not noise). Attributed rather than guessed at, and both first guesses
were wrong: `chainDropsName` costs **nothing** (removing it measured *slower*), and
the 486 visibility markers cost **nothing** (-0.5 pp). What remains is mostly that
there is more compiler to compile -- `src/`+`ums/`+`std/` grew 534 lines (2.3%) and
the runtime C grew 138.

**And the benchmark caught a use-after-free that 193 passing tests did not.**
Splitting `no_stack` was done in one step too few: the flag means both "explicitly
dropped" *and* "ownership transferred", and dropping the site-level check for the
first also dropped it for the second. An FFI `consume` -- which is how a `List`
becomes a `DataView` -- hands the allocation to a callee that frees it, so the
release this frame then emitted was a double free. `g1_dataview` aborted in
`list_release` on memory `data_view_finish` had already returned.

The fix is a separate `transferred` flag, set only by `consume`, which is what
`elem_disposition_of` now asks about; `no_stack` keeps its placement meaning and
`chainDropsName` keeps the binding-level drop question.

Why the suite missed it: `test_80` and `test_81` both build their `List` inline in
`main`, so the allocation site and the binding are in the same function.
`g1_dataview` builds it in a helper, which is the shape that shares one site across
call sites -- and the only shape that broke. `tests/test_93_data_view_from_helper.psm`
pins it: it passes on the fixed compiler and aborts (134) on the broken one.

**The corpus is not in the suite, and that is the real gap.** 30 corpus programs now
run clean under a full sweep; nothing runs them in CI, so the only reason this was
caught is that a benchmark happened to be run. `g6_engine` has no `main` and fails
identically at the session start -- it is a library module, not a regression.

## 4 · The corpus must move with the language

**DONE 2026-08-30 for the xlang corpus.** Six of the seven benchmark programs are
rewritten in the language as it now stands; g9 is unchanged and the reason is below.

| program | rewritten as | receiver |
|---|---|---|
| g1 | method syntax + `private` | `List<Particle>` |
| g2 | method syntax + `private` | `List<Renderable>`, `List<DrawCmd>` |
| g3 | method syntax + `private` | `List<Node>` |
| g4 | **`impl World`** + `private` | `World` |
| g5 | **`impl AssetCache`, `impl Scene`** + `private` | `AssetCache`, `Scene` |
| g6 | **`impl World`** + `private` | `World` |
| g9 | unchanged | -- |

**Old-vs-new, reported as the section requires, and stronger than a timing run:**
every one of the seven emits **byte-identical `__TEXT,__text`** against its
pre-rewrite self, with **identical checksums**. A method call *is* the free call
after the checker's rewrite and `private` is a resolution-time check, so there is
nothing left for a timing comparison to find -- the two arms are the same program,
which is what the "checksums identical" rule was reaching for.

Three things this turned up that the section's premise did not anticipate:

- **A generic `impl` is rejected.** g1/g2/g3 have `List<...>` receivers, and
  `impl List<Particle>` answers "a generic `impl` block is not supported yet; write
  the methods as generic free functions". Method syntax works on a free function
  regardless, so those three use it -- the diagnostic prescribes exactly that.
- **Declaration order is load-bearing.** g5 first came back DIFFERS with matching
  checksums, purely because merging `evict_unused` into an earlier `impl` block moved
  it in emission order. Restoring the original order made it identical. Any future
  rewrite must keep functions where they were.
- **g9 cannot take method syntax.** Its only workload call is
  `spawn simulate(Band { .. })`, and `spawn` takes a call expression; `spawn b.simulate()`
  is a different construct. Left alone rather than reshaped to suit the rewrite.

`aif/corpus/*.psm` is untouched -- the xlang ports carry the "verbatim from" note and
the two would diverge. That is the next slice of this section, not part of it.


**This is a standing instruction, not a task.** When a feature lands that makes
corpus or test code better, *rewrite that code to use it* — and say so in the
commit.

- If a program reads better with `impl`/traits, **use them**. The corpus exists
  to measure what a real Prismio program looks like, and a corpus frozen in the
  language of 2026-08 stops being that the moment the language moves.
- Every such rewrite must keep the program's **checksums identical**. That is
  what makes it a rewrite and not a different benchmark. Report old-vs-new for it
  like any other change.
- **Add the missing Prismio hand-tuned arms** (§2.2) — **DONE 2026-08-29 for six
  of seven.** g3, g4, g5 and g6 are new ports, g2's existing port was wired (the
  variant table had no `prismio_tuned` entry, so nothing had ever built it), and
  g1's arm is aliased to `g1_dataview_tuned.psm` because SoA *is* what a Prismio
  expert would reach for. Four of the six beat idiomatic Rust, and g1's ceiling
  is within 3% of Rust's — 4.6 ms against 4.7 ms. **g4 does not move at all**
  (38.3 → 38.5), which says its 1.76× gap is not layout and a memory-model change
  will not find it.
  `g9` stays **absent**: hand-tuned Rust keeps four workers alive across frames
  over channels, and Prismio has no way to keep a task alive past its join, so
  the arm is not writable rather than not written. When it is, that arm gets
  written and the 1.45× gap gets re-measured.
- The files that move together with any language change: `tests/*.psm`,
  `tests/test_runner.py` (hardcoded manifest and leak expectations),
  `aif/corpus/*.psm`, `aif/evidence/xlang/prismio/*.psm`, `std/*.psm`,
  `bootstrap/prismio-seed.ll` **if the frontend changed** — new syntax lands in
  two steps, teach the frontend, refresh the seed, *then* use it in `src/` — and
  the sibling docs repo at `../docs/content/`.

---

## 4.1 · Off the C externs, and the corpus in CI — **DONE 2026-08-30**

**`g7` was measuring C on the one axis it exists to measure.** It declared
`extern fn str_slice` / `str_substring` and called the *C* implementations, so
every string number this project recorded was C wearing a Prismio face. It now
calls native `std.string`. Checksums are unchanged (tokens 427914, bytes 21282),
so it is a rewrite; the verify ledger now *sees* the allocations the C version hid
(1048653 allocated, 1047073 released, 1580 leaked, 0 violations).

`g7_substring.psm` is now **byte-identical to `g7.psm`**. The pair existed only to
price C's `str_slice` against C's `str_substring`; on the native function there is
one program. Consolidating them is left open rather than decided here.

**Eight test files moved to `std.string`**, which the `no_stack`/`transferred` fix
unblocked — `test_45` on native `std` now leaks the same 2 its fixture documents.

**Four AIF fixtures keep their externs, deliberately, and now say so.**
`aif_tiers`, `test_44`, `test_46` and `test_47_aif_minimal_cause` assert *per-site*
facts, and an opaque `extern` is what gives each function its own allocation site.
Native `strConcat` routes every caller through one site inside itself, so migrating
them reported `tier_one_string__Void#0: no manifest record` -- the site had not
changed tier, it had stopped existing separately. That is the same collapse behind
the `no_stack` defect, seen from the other end.

**The corpus is in CI.** `run_corpus_test` builds *and runs* all 30 programs
(`g6_engine`/`g6_engine_tuned` are library modules with no `main` and are skipped by
name). Verified against the compiler that had the DataView bug: it fails, and it
names **four** affected programs, not the one a benchmark happened to surface.
Suite: **195**.

## 5 · What "done" means for v0.1

1. Every item in §3 landed in its smallest right-shaped form.
2. `../docs/content/roadmap.md` reflects reality — no "Coming Soon" on anything
   shipped, and no "Implemented" on anything the matrix has not run green.
3. The three-platform CI matrix **observed green**, not merely expected to be.
   **Observed 2026-08-30** (run 33072047347, the newest on this branch): Ubuntu
   green, macOS green, **Windows red at "Run the test suite", 173/175**. Every
   recorded run on this branch is red for the same reason -- the shape the note
   above described is right, the numbers were stale.

   The two Windows failures, both pre-existing and diagnosed:

   - **`test_76_std_fs` -- FIXED 2026-08-30.** A wrong assertion, not a wrong
     `join_path`. `join_path` normalises separators to the host's, so the literal
     `joinPath("/a/b", "c.psm")` comes back `\a\b\c.psm` on Windows and
     `strStartsWith(joined, "/a/b")` is false there while passing everywhere else.
     The test now builds its directory with `joinPath` and asserts the
     `joinPath`/`directoryOf` round trip, which is the property that has to hold on
     every host. The neighbouring `directoryOf("/a/b/c.psm")` literal is kept
     deliberately: `get_directory` scans for both separators on purpose.
     Unverifiable on this host -- it passes on macOS and needs a CI run to confirm
     Windows.
   - **`run --jit` -- open, and needs a Windows host.** The JIT cannot resolve its
     symbols there, and the list includes `prismio_argv`, which is a *runtime C*
     symbol rather than a generated one -- so the JIT is not seeing the runtime on
     Windows at all, and the generated `print__*` / `prismioStdIo*` failures follow
     from that rather than being separate. This is ORC symbol-resolution work that
     cannot be developed or verified from macOS; it wants either a Windows machine
     or a sequence of CI pushes.
4. `V1_GAP_ANALYSIS.md`'s "central finding" table — the workarounds in the
   compiler's own source — is empty, or every remaining row has a reason.
5. The five-arm benchmark exists for every corpus program, and the standing
   against idiomatic Rust is recorded. As of 2026-08-29: **0.92×–1.81×**
   idiomatic, and the fifth arm now exists for six of seven — hand-tuned Prismio
   reaches **0.25×–1.42×** of idiomatic Rust, and 0.97×–2.16× of hand-tuned Rust.
   g9's fifth arm is the one outstanding absence and its reason is recorded.
