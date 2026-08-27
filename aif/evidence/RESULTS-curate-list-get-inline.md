# The hot element accessor was never curated

**Status: GREEN, 2026-08-29.** Compiler `build/cur-2`. Suite **174/174**, fixed
point, AIF differential **18/18**, **87 programs under `--verify` with 0
violations**, all corpus checksums unchanged.

One name added to one list. **Corpus median 0.861×**, and the standing against
idiomatic Rust goes from **0.90×–3.09×** to **0.92×–1.80×** — the widest gap
falls from 3.09× to 1.80×.

---

## 1 · How it was found

Not by looking for it. `RESULTS-final.md` records g4's 3.10× as *"2.51×
representation and 1.24× compiler"*, so the gap was attributed to data layout.
Disassembling the actual binary says otherwise:

```asm
_system_movement__Struct_World_Float:
    ...
    bl  _list_get_inline        <- a real call
    bl  _list_get_inline        <- a real call
    ldr d0, [x0]                <- scalar. one component at a time
    fmul d0, d8, d0
    fadd d0, d1, d0
    ...
```

**Two function calls per element, and no vectorization anywhere in the program**
— 2 NEON instructions in the whole of g4. That is not a representation cost. The
elements are already inline (`list_get_inline` is the flat-element accessor); the
seam M1.1 exists to remove was sitting in the hot loop.

## 2 · The defect

M1.1 built the curated inlinable module and listed the hot container ops:

```c
"list_get", "list_set", "list_len", ... "list_push",
```

M4.2 then added the `_inline` family and taught `inlineOpName`
(`src/ir/expr.psm`) to emit **those instead** wherever the element type is
statically flat — and this list was not updated with it. So codegen emitted
`list_get_inline` and the curated module contained `list_get`. Every corpus
program with a flat-element list paid a real `bl` per element access, into a
five-line function:

```c
void* list_get_inline(void* lp, int index) {
    RtList* l = (RtList*)lp;
    if (index < 0 || index >= l->len) return 0;
    if (!l->elem_size) return l->data[index];
    return (unsigned char*)l->data + (size_t)index * (size_t)l->elem_size;
}
```

Confirmed directly: dumping the cached curated module with
`PRISMIO_OBJ_CACHE_DIR` shows the eleven functions it carries, and no `_inline`
among them.

## 3 · The fix, and why only one of the three

`list_get_inline` added to `PRISMIO_CURATED_OPS`. It satisfies the closure rule
the comment above that list states — *a function may be curated only if every
symbol its body references is exported* — **trivially**, because its body
references no symbols at all, only fields of `RtList`.

**Its two siblings are deliberately still absent.** `list_set_inline` reaches
`list_copy_elem` and `list_release_source`; `list_push_inline` reaches those plus
`list_inline_grow` and `list_set_elem_inline`. All four are `static` in
`lang_runtime.c`, which is the exact failure that comment records for
`list_push`: inlining a body that reads a `static` produces a program
referencing a symbol nothing defines. They need the outlining treatment
`list_push_grow` was given first. `run_curated_closure_test` asserts the
property rather than trusting it.

No cache-schema bump: the key already hashes `PRISMIO_CURATED_OPS`, so adding a
name invalidates it correctly.

## 4 · Before / after

**The movement loop goes from 2 calls per iteration to 0.**

**Corpus, 25 runs, interleaved, checksums enforced:**

| program | new/old | | vs idiomatic Rust, before → after |
|---|---:|---|---|
| g4 | **0.576×** | | 3.07× → **1.77×** |
| g6 | **0.715×** | | 2.87× → **1.77×** |
| g5 | **0.754×** | | 1.69× → **1.22×** |
| g2 | **0.861×** | | 1.75× → **1.50×** |
| g3 | 0.923× | | 1.05× → **0.97×** |
| g9 | 1.013× | flat | 0.92× |
| g1 | 1.039× | flat | 1.08× |

**Corpus median `new/old` 0.861×**, range 0.576–1.039×.

**The standing against idiomatic Rust, from the cross-language harness at 25
runs:** g9 **0.92×**, g3 **0.97×**, g1 1.08×, g5 1.22×, g2 1.50×, g6 1.77×,
g4 1.80×. Previously 0.90×–3.09× with a median of 1.58×; now **0.92×–1.80×**.
Peak RSS 0.83×–1.00×. Every checksum is unchanged — g4's `entities 1500 / draws
1215783`, g6's `alive 120000 / orders 13800000 / kills 120000`, and so on.

**g9 beats idiomatic Rust at 0.92×**, which is the established result and sits
well below the harness's A/A floor. **g3 is level with it at 0.97×**, which is
close enough to that floor to be called level rather than ahead.

**g1 read 1.083× here and that was measurement noise — corrected in place.**
This section first reported it as a real regression (19.19 ms → 20.78 ms) and
attributed it to a mechanism: g1's loops read one list per iteration where g4's
read two, so inlining trades one call for six header loads and two branches.
The mechanism is plausible and the effect is **not reproducible**. Re-measured
later the same day at best-of-9, with **byte-identical IR** on both sides, g1
reads 20.14 ms before and 19.69 ms after — the opposite sign. Across the day's
runs it lands anywhere between 0.98× and 1.08×, so 1.083× is inside the spread
and the mechanism was fitted to a single sample.

**The lesson is the one this file already carries about models**: a confident
attribution needs a repeated measurement, not one run and a plausible story.
Nothing here regressed; the corpus median stands.

| gate | result |
|---|---|
| fixpoint (`cur-1` vs `cur-2`) | identical |
| suite | **174/174** |
| AIF differential | **18/18** |
| `--verify` sweep | 87 programs, **0 violations** |
| `check_source_lists.py` / `git diff --check` | agree / clean |

## 5 · What this opens up

**Vectorization is still absent**, and the cause has since been measured. The
loop is now call-free but the arithmetic is scalar `fmul`/`fadd` — 0 NEON in
`system_movement`. Removing the call barrier was necessary and not sufficient.

*This section first said the next step was `noalias` on the component arrays,
from AIF's aliasing lattice. **That was wrong and is corrected here rather than
left standing.*** It was priced and killed: `restrict` on the two arrays is worth
**1.11×**, and both arms vectorize without it. The model that produced that
answer omitted the List header indirection, which is the whole question.

With a faithful model:

| arm | time | NEON |
|---|---:|---:|
| header reloaded per element (what we emit) | 20.52 ms | 2 |
| bounds check + `elem_size` branch removed | 10.37 ms | 2 |
| header loads hoisted, flat indexed loop | **7.79 ms** | **6** |

The **branches are the bigger half at 1.98×** and removing them alone does not
vectorize; hoisting the header is a further 1.33× and is what unlocks it. The
blocking fact is that the element store may alias the List header — true of any
`RtList*` as far as LLVM can see, and false in reality, since the header and its
`data` block are separate allocations. Saying so needs scoped alias metadata
across the curation boundary, not an aliasing answer AIF already has.

**The `elem_size` branch looks free and is not.** `inlineOpName` picks
`list_get_inline` only where the element size is a compile-time constant, so the
runtime's reload-and-branch is waste at those sites. But `list_push_inline`
*lazily stamps* an empty list and falls back to boxed otherwise, so the static
size is not a guarantee about the value — an unstamped list would take the boxed
path while codegen assumed the flat one, which is a wrong-address read rather
than a leak. See `TODO.md`.

**The other two `_inline` ops.** Outlining their `static` reachers, exactly as
`list_push_grow` did, would let `list_set_inline` and `list_push_inline` be
curated too. g6 and g2 are write-heavy and are the programs that would move.

**And the general lesson.** This was one stale list, invisible for as long as it
existed because nothing checks that the ops codegen *emits* are the ops the
curated set *contains*. That check is cheap and does not exist: `inlineOpName`
knows the mapping and `PRISMIO_CURATED_OPS` knows the set.
