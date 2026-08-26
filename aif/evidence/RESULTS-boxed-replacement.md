# Boxed `List` replacement ownership

**Status: GREEN, 2026-08-26.** Prismio now provides
`list_set_exclusive(list, index, value)` for the boxed struct case. It releases
the displaced element with the same disposition and typed releaser the List
would use at teardown. Ordinary `list_set` remains conservative and compatible.

Raw results:

- [`results-boxed-replacement.json`](results-boxed-replacement.json)
- [`xlang/results-boxed-replacement.json`](xlang/results-boxed-replacement.json)

## Why an exclusive operation

The old `list_set` could not release a boxed `OBJECT`: a previous `list_get`
may still name that object. Prismio's AIF carries element-view provenance, but
sema does not yet carry a control-flow-graph lifetime for a derived borrow.
Adding a partial source-order approximation would make a memory-safety decision
from a fact weaker than the language needs.

The design follows the common rule that mutation which can invalidate a borrow
requires exclusive access. [Rust RFC 2094](https://rust-lang.github.io/rfcs/2094-nll.html)
defines borrow lifetimes from CFG liveness and forbids mutation or movement while
the borrow is live. [Swift's memory-safety model](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/memorysafety/)
requires exclusive access for modification unless non-overlap is proven. Rust's
[`mem::replace`](https://doc.rust-lang.org/std/mem/fn.replace.html) also makes the
ownership transfer explicit rather than silently dropping the old value.

Prismio takes the smaller sound step available today: a scoped positive
capability starts only on a local `list_new`/`list_new_with_capacity` binding.
It is cleared permanently when:

- `list_get` or List indexing exposes an element;
- a Slice is made from the List; or
- the List crosses an arbitrary borrowing call.

`list_set_exclusive` requires that capability and a boxed struct element type.
It rejects borrowed/observed Lists and flat inline elements with targeted
diagnostics. A full non-lexical liveness analysis can relax the conservative
rule later without changing the operation's safety contract.

## Discriminator

`tests/test_83_list_set_exclusive.psm` replaces a boxed `Named` value which owns
a String. Under `--verify`:

| path | allocated | released | leaked | violations |
|---|---:|---:|---:|---:|
| ordinary boxed `list_set` behavior | 4 | 3 | 1 | 0 |
| `list_set_exclusive` | 4 | 4 | 0 | 0 |

`neg_41_list_set_exclusive_observed.psm` proves a prior element borrow closes
the capability. `neg_42_list_set_exclusive_inline.psm` proves inline storage is
not admitted.

## Gates

- fixed point: `m5-exclusive-a.ll == m5-exclusive-b.ll`;
- suite: **169/169**;
- AIF differential: **17/17** in both modes;
- source lists and `git diff --check`: green;
- 25-run milestone: **1.002×** corpus median, range **0.999–1.102×**, gate passed;
- all corpus checksums agree and peak RSS is flat apart from g6 at **1.027×**;
- 25-run cross-language refresh completed in
  [`xlang/results-boxed-replacement.json`](xlang/results-boxed-replacement.json).

The standard corpus does not call the new operation, so this milestone is a
correctness and API result, not a claimed corpus speedup.
