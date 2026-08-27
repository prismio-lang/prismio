# A payload-free enum variant allocated uninitialised memory

**Status: GREEN, 2026-08-29.** Compiler `build/zero-2`. Suite **174/174**, fixed
point, AIF differential **18/18**, `check_source_lists` agree, `git diff --check`
clean.

The most serious defect the three-platform CI matrix found, and it **predates
this session** — a control branch at `97ef065` carrying only the CI fixes
reproduces it exactly. It is a correctness fix that also happens to be
**1.82× on `g8_tree_rebuild`**, because it removes half that program's
allocations.

---

## 1 · What the matrix saw, and what this host did not

| platform | `test_73_recursive_release` |
|---|---|
| ubuntu-latest | exit **-11** (SIGSEGV) |
| windows-latest | exit **3221226356** = `STATUS_HEAP_CORRUPTION` |
| macOS | **passes** — `106 allocated / 106 released / 0 leaked / 0 violation(s)` |

`--debug` passed where release did not, and the tree is **depth 3**, so it was
never stack exhaustion. It took three of the four Ubuntu failures with it: the
crash itself, the zero-analysis behavioural-equivalence check (*"stdout differs
between release and --debug"*), and `aif_verify` (*"no aif-verify report"* — it
died before printing one).

**This host could not reproduce it**, including under `MallocScribble`,
`MallocPreScribble` and `MallocGuardEdges`. What did reproduce it was building
the emitted IR by hand against the runtime under **AddressSanitizer**:

```
==64610==ERROR: AddressSanitizer: SEGV on unknown address 0xbebebebebebebece
    #0 __aif_release_Tree+0xc
```

`0xbe…` is a fill pattern: a *pointer* was read out of memory nothing had ever
written. That is the whole bug, and the recipe is worth keeping —

```bash
prismio build <src> -o out.ll
clang -fsanitize=address -g -O1 out.ll runtime/lang_runtime.c runtime/program_support.c -Iruntime -o probe
```

## 2 · The defect

Sema desugars a payload enum into a struct literal — `Tree.Node(l, v, r)` becomes
`Tree { $tag: 2, Node$0: l, Node$1: v, Node$2: r }` — and fills the slots a
variant does not use with `semaZeroValue`. That function answered **every**
`TypeKind.STRUCT` field with an empty struct literal of its type.

For an *inline* field that is right, and the comment said so: the empty literal
gets filled with zeros one level down. For a **pointer** field it is not, and
`Tree`'s payload slots are pointers — `fieldTypeFor` stores a struct field inline
only when its annotation is POD, and a self-referential type is not.

So each `Tree.Leaf` carried two empty `Tree` literals, and codegen turned each
into a `malloc` with **nothing stored into it at all — not even the tag**:

```
  %5  : 4 gep(s) targeting it      <- a real node, fully initialised
  %7  : 0 gep(s) targeting it      <- a filler. malloc'd, never written
  %10 : 0 gep(s) targeting it      <- a filler
```

`__aif_release_Tree` then loaded fields 3 and 2 of those blocks as child pointers
and recursed into whatever was there. On macOS a fresh `malloc` page reads as
zero, so the tag looked like variant 0 and the children looked like `NULL` — it
worked by accident, and `sum()`'s and `depth()`'s answers were correct by the
same accident. glibc and the Windows heap hand back dirty memory.

**The promised recursive fill could never have run here.** `Tree` contains
`Tree`; filling it inline does not terminate. The empty literal was not a
placeholder waiting to be filled, it was a permanent hole.

## 3 · The fix

`semaZeroValue` asks the same question `fieldTypeFor` does — inline iff the
annotation is POD — and returns `none` for a pointer-shaped field:

```prismio
if (t.kind == TypeKind.STRUCT) {
    if (typeAnnIsPodIn(module, annotation, 0, true)) {
        // inline storage: an empty literal, filled one level down
    }
    return createNode(NodeKind.NONE_LITERAL_EXPR)
}
```

Read **`byDecl`**, which matters: the struct registry is filled by codegen and is
empty during sema, so the registry reading answers "POD" for every struct-typed
field. `typeAnnIsPodIn` already documents that over-approximation as the unsafe
direction for exactly this class of question — this is a third instance of it.

## 4 · Before / after

**Correctness.** Under ASan, `test_73_recursive_release` goes from `SEGV in
__aif_release_Tree` to `recursive release ok`, exit 0. Every allocation in
`makeTree` now has all four fields written; there are no zero-gep blocks left.

**Allocations, because the fillers are simply not allocated any more:**

| program | before | after | |
|---|---:|---:|---|
| `g8_tree_rebuild` | 24,572 | **12,284** | checksum `tree 528891` unchanged |
| `test_74_reinit_assignment` | 511 | **255** | `released` 7 in both, violations 0 |
| `makeTree` (per call) | 15 | **7** | |

`test_74`'s expected leak count moves 504 → 248 in the runner. That is **fewer
allocations, not fewer frees** — `released` is 7 on both sides — which is the
direction its docstring asks for.

**Speed**, on the one corpus program the change touches:

| | frame_ns, best of 7 | |
|---|---:|---|
| `g8_tree_rebuild` before | 246,459 | |
| `g8_tree_rebuild` after | **135,208** | **0.549× — a 1.82× speedup** |

**Corpus, 25 runs:** median **1.002×**, range 0.996–1.047×. Only three of 129
programs change IR at all (`test_73`, `test_74`, `g8_tree_rebuild`); none of the
seven milestone programs does, so the flat median is expected.

| gate | result |
|---|---|
| fixpoint (`zero-1` vs `zero-2`) | identical |
| suite | **174/174** |
| AIF differential | **18/18** |
| `check_source_lists.py` / `git diff --check` | agree / clean |
| emitted IR | 3 of 129 programs changed |

## 5 · What to check next

The real verification is the matrix: `test_73` should stop crashing on
ubuntu-latest and windows-latest. Until that is observed, this is a fix validated
by a sanitizer on the platform that never failed.

Two things this does not address, both still recorded in `TODO.md`: `--jit`'s
unresolved `std.io` symbols on both non-macOS platforms, and `--target` plus
`test_76_std_fs` on Windows.
