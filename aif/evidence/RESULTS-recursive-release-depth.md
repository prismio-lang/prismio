# The generated release loops on its tail self field

**Status: LANDED, 2026-09-02.** M2.1a made generated releases for recursive
types reachable. That fixed the leak but exposed the release's native-stack
depth: a list-shaped value paid one call frame per element.

## Discriminator

`tests/test_73_recursive_release_depth.psm` builds this shape iteratively:

```prismio
enum Chain { End, Link(Int, Chain) }
```

The accumulator reassignment is important. Construction uses no recursion, so
the process can fail after printing its success line only while the scope drop
is traversing the chain. At 500,000 links the pre-change executable prints and
then exits **139**. At 250,000, where that host's stack still survived, its
verifier ledger was balanced; the defect is depth, not ownership accounting.

## Lowering

Generated releases retain reverse declaration order. The lowest-index owned
field is the last release in that walk; when it is a direct `AIF_ELEM_TYPED`
field of the same type, codegen loads it as the continuation instead of calling
the same release function.

Each iteration therefore:

1. releases all earlier non-tail fields normally, including recursive calls for
   other self fields;
2. loads the tail-self pointer;
3. releases the current object's cold block and base allocation; and
4. continues with the saved pointer, stopping on null.

The frontend bridge uses one entry alloca for the current pointer; LLVM's
mem2reg pass turns it into a loop phi in linked code. Raw `Chain` IR contains a
back edge and **zero** calls to `__aif_release_Chain`. A binary `Tree` retains
one recursive self call and loops on the other, preserving the existing reverse
field order.

The tail choice is intentionally stricter than merely finding any self field.
If an earlier-declared owned field would be released after it, the self call is
not tail and remains recursive; moving it across that field could invalidate
the release-order alias invariant. List-shaped nodes with scalar payloads have
one owned field and take the loop.

## Result

| build | depth | outcome | verifier ledger |
|---|---:|---|---:|
| recursive release | 500,000 | prints, then SIGSEGV (139) | 250k control balanced |
| tail-self loop | 500,000 | exits 0 | **500,001 / 500,001 / 0**, 0 violations |

Existing recursive ownership cases remain balanced:

- `test_73_recursive_release`: 50 / 50 / 0;
- `test_52_aif_cycle_collector`: 12 / 12 / 0;
- `g8_tree_rebuild`: 2,049 / 2,049 / 0, checksum 528891.

## Gates

- compiler IR fixpoint: `release-loop-gen3` and `release-loop-gen4` are
  byte-identical, SHA-256
  `3ea2ce80c615dca8f1a45020b9f972eb09d114baf00338ba7dbbcc0456670d64`;
- source lists agree and `git diff --check` is clean;
- the AIF differential and full-suite result are recorded after the final
  current-tree run.

## Remaining boundary

For a type with several self fields, the non-tail fields still recurse. A
balanced tree keeps logarithmic stack depth; a pathological chain through a
non-tail branch can still be deep. Eliminating that bound requires an explicit
worklist rather than this allocation-free tail-self transformation.
