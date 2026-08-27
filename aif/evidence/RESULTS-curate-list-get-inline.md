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

**g1 regressed, and it is real: 19.19 ms → 20.78 ms, 1.083×.** Attributed rather
than waved at — the executable is byte-identical in *size*, so it is not code
bloat. g1's hot loops read **one** list per iteration; g4's read **two**.
Inlining trades one call for six header loads and two branches, which wins
clearly with two lists and roughly loses with one.

**So the regression and the remaining prize share a root cause.** Both are the
List header being reloaded per element because the element store may alias it.
Hoisting it would take g1's inlined loop below its call-based one as well; until
then this change is a large net win with one program paying for it.

| gate | result |
|---|---|
| fixpoint (`cur-1` vs `cur-2`) | identical |
| suite | **174/174** |
| AIF differential | **18/18** |
| `--verify` sweep | 87 programs, **0 violations** |
| `check_source_lists.py` / `git diff --check` | agree / clean |

## 5 · What this opens up

**Vectorization is still absent.** The loop is now call-free but the arithmetic
is scalar `fmul`/`fadd` on one component at a time — 0 NEON instructions in
`system_movement`. Removing the call barrier was necessary and is clearly not
sufficient. The next question is whether LLVM can prove the component lists do
not overlap: `w.positions` and `w.velocities` arrive as opaque pointers with no
aliasing information, and **AIF already computes an aliasing lattice per site**.
Feeding that to LLVM as `noalias` is the obvious next step and it is a fact the
compiler already owns.

**The other two `_inline` ops.** Outlining their `static` reachers, exactly as
`list_push_grow` did, would let `list_set_inline` and `list_push_inline` be
curated too. g6 and g2 are write-heavy and are the programs that would move.

**And the general lesson.** This was one stale list, invisible for as long as it
existed because nothing checks that the ops codegen *emits* are the ops the
curated set *contains*. That check is cheap and does not exist: `inlineOpName`
knows the mapping and `PRISMIO_CURATED_OPS` knows the set.
