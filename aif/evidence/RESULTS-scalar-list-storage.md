# `List<Int>` and `List<Bool>` never reach the inline path, and the gate is one line

Diagnosis only. No compiler change here. Every number is
`build/host-routing-locked7`, LLVM 22.1.8, Apple Silicon.

The flat-list machinery is built and working — `RESULTS-flat-list-view.md` and
`RESULTS-curate-list-get-inline.md` are its evidence. What is not established
anywhere is that **it is only ever reached by a struct element type.** A scalar
element type is excluded by a single predicate, so `List<Bool>` stores one byte
of information in eight bytes of memory.

## 1 · The gate

`src/ir/expr.psm:633`:

```prismio
private fn inlineElemSizeOfList(listExpr: ASTNode) -> Int {
    if (nodeHasType(listExpr) == false) { return 0 }
    let lt = nodeGetType(listExpr)
    if (lt.kind != TypeKind.LIST) { return 0 }
    if (nodeIsNull(lt.child)) { return 0 }
    let ekey = typeIrKey(ptr_to_type(lt.child))
    if (isStructTypeKey(ekey) == false) { return 0 }    // <-- here
    return inlineElemSize(structTypeName(ekey))
}
```

A zero from this function means no `list_set_elem_inline` stamp at
`list_new`, which means `l->elem_size` stays 0, which means every access goes
through the boxed entry points rather than `list_get_inline` /
`list_set_inline` / `list_push_inline`. `inlineElemSizeOfSlice`, immediately
below it, carries the same restriction.

The scalar case is not handled and declined; it is not reached. `Int`, `Bool`,
`F64` and `Char` all have a known static size, and `inlineElemSize` is never
asked for it.

## 2 · What it costs, measured

4,000,000 elements pushed, peak RSS:

| list | peak RSS | bytes/element |
|---|---:|---:|
| `List<Bool>` | 64.0 MB | 8 |
| `List<Int>` | 64.0 MB | 8 |
| `List<B>` where `struct B { v: Bool }` | **9.2 MB** | **1** |

The third row is the same data through the same runtime, differing only in
that a one-field struct passes `isStructTypeKey` and a bare `Bool` does not.
**7.0× on footprint**, and it is the compiler's own existing path — nothing was
changed to obtain it. (64.0 MB is 8 M slots at 8 bytes: the doubling growth
leaves 2× slack above 4 M elements. 9.2 MB is 8 M slots at 1 byte plus the
binary.)

`List<Int>` is a different case: 8 bytes per element is already the right
density, so the cost there is not space but the access path — every `list_get`
is the boxed entry point carrying the `elem_size` branch that
`RESULTS-flat-list-view.md` went to some trouble to hoist out of the
struct-element loops.

Allocation behaviour confirms the storage is genuinely flat rather than boxed
in both cases: 1,000 pushes to a `List<Int>` costs **11 allocations**, one
header plus growth reallocations, not 1,011.

## 3 · What is *not* established here

The prompting claim for this work was roughly 8× on scalar-list code, from a
sieve. **The footprint half of that reproduces. The speed half is not measured
here, and the obvious way to measure it does not work.**

Using the struct wrapper as a stand-in for typed scalar storage is confounded:
a `B { v: false }` literal is heap-allocated and then copied into the flat row,
so the wrapper pays a per-element allocation that a real `List<Bool>` would
not. A sieve to 2,000,000 run both ways:

| | best of 5 | allocations at n=20,000 |
|---|---:|---:|
| `List<Bool>` (scalar, boxed storage) | 8.5 ms | 17 |
| `List<B>` (struct, inline storage) | 82.7 ms | 47,879 |

Both answer `primes 148933`, so they do the same work — but the struct arm is
10× slower because it is allocating, not because inline storage is slow. That
number measures struct-literal construction and should not be quoted as an
argument either for or against this change.

A real `List<Bool>` at `elem_size = 1` would have the flat row **without** the
per-element allocation, so it should be smaller *and* no slower than the scalar
arm above. That is the prediction the change has to be measured against, and it
cannot be measured before the change exists.

## 4 · The shape of the change

1. Give `inlineElemSizeOfList` and `inlineElemSizeOfSlice` a scalar arm: for an
   element key that is a known-width scalar, return that width rather than 0.
   The widths are already target-aware everywhere else; this must ask the same
   source, not a table.
2. `Bool` at one byte is the large win and also the one with a decision in it —
   one byte per element is 8× off a bit-packed representation, and bit-packing
   is a different change with a different access path. One byte first.
3. Check `list_push_slot`'s boxing fallback still behaves when `elem_size` is
   set for a type it previously never saw, and that a `List<Int>` built before
   the stamp and one built after cannot be mixed.

Gates: this changes emitted code for every scalar-element list, so it is not
covered by the byte-identical rule. It needs the full suite, the AIF
differential, a `--verify` sweep over the corpus, and a fixpoint. The corpus
uses struct-element lists almost throughout (`g4_ecs_world` is five
`List<Struct>`), so the corpus median is likely to be flat and **the evidence
for this change will have to come from a program written for it** — which is
the same hole `g8_tree_rebuild` was written to fill for reuse.
