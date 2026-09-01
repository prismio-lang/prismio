# `List<Int>` and `List<Bool>` never reach the inline path, and the gate is one line

**Status: LANDED with a measured regression, 2026-09-01.** §1–4 are the diagnosis
against `build/host-routing-locked7`; §5 is what changed and what it cost. The
space win is large and the sieve gets faster; a pure read loop does not, and that
is recorded here rather than left for someone to find.

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

## 4 · The shape of the change (as planned)

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

## 5 · What landed, and what it cost

`inlineElemSizeOfList` and `inlineElemSizeOfSlice` answer with the scalar's width
now. Four consequences had to be handled, and three of them are the same hazard:

**The two conventions are not interchangeable.** The boxed entry points take a
scalar *punned into* a pointer slot and hand back the slot's contents; the inline
ones take an address and hand back an address. Crossing them is a wild read, not
a wrong answer. There turned out to be **three** read paths — the `list_get`
call, the `l[i]` subscript, and the slice subscript — and missing the second is
what made `nums[0]` return `19160624` instead of `7`.

**Only a scalar can tell the two apart**, which is why it is resolved in the
runtime rather than in codegen. `list_get_inline` returns the slot's address for
an inline list and its contents for a boxed one; for a struct both are addresses,
so the existing guarded fast path can select between them. For a scalar they are
different kinds of value and no single load covers both — so a scalar goes
through `list_get_inline_scalar`, which branches on `elem_size` itself and
returns a value either way. The flat fast path stays pointer-shaped for exactly
this reason; extending it to scalars type-checks and is unsound in the fallback
arm.

**Writes go by value.** Reaching the inline setters with an address meant
codegen spilling the scalar to a stack slot; that measured **1.76×** against the
pointer slot it replaced, and it stores a stack address as the element if the
list turns out boxed. `list_set_inline_scalar` / `list_push_inline_scalar` /
`list_slice_set_inline_scalar` take the value widened to `i64` and store it back
under the element's width — by assignment rather than by byte copy, which is what
keeps it endian-safe.

**`list_get_inline_scalar` is curated.** It calls nothing and touches only
`RtList` fields, so it satisfies the closure rule the same way `list_get_inline`
does. Left out it cost **8.9×** on a read loop, which is the whole of what the
change was supposed to buy. Its write siblings stay out: they reach
`scalar_store`, `list_inline_grow` and `list_set_elem_inline`, all `static`.

### Measured, `build/base-gen1` against `build/rc-gen2`

| | before | after | |
|---|---:|---:|---|
| `List<Bool>`, 4M elements | 64.0 MB | **9.2 MB** | **7.0× smaller** |
| `List<Int>`, 4M elements | 64.0 MB | **32.7 MB** | **2.0× smaller** (`Int` is `i32`) |
| sieve to 2,000,000 | 8.54 ms | **6.82 ms** | **1.25× faster** |
| write loop, 20M `list_set` | 21.17 ms | **18.76 ms** | 1.13× faster |
| read loop, 20M `list_get` | 2.14 ms | 4.94 ms | **2.31× slower** |

**The read loop is a real regression and it is the one number to argue with.**
Putting scalars inline takes them out of `isStaticBoxedListGet`, whose
`ir_list_boxed_elem` lowering inlines the access into a guarded loop and
vectorises; the curated call does not vectorise. The sieve still wins because it
is write- and cache-bound, and 20M reads at 4.94 ms is 0.25 ns each — but a
read-dominated scalar loop is slower than it was.

**The fix is shaped and not done**: a scalar `ir_list_flat_elem`, which resolves
the representation inside the intrinsic so the true arm can be address
arithmetic and a load. That is a backend change and wants its own measurement.

**Gates:** fixpoint identical, suite **206/206**, AIF differential 36 agree with
the same 2 pre-existing `src/main.psm` disagreements the baseline has.
`test_79_slices` — which already had a scalar-slice case — is what caught the
subscript path, and `test_82_generic_layout` and `test_88_map_keys` caught a
`zext ptr` from testing "not a struct key" where the question was the width.
