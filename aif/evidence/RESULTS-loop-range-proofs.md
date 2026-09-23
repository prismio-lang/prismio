# Loop range proofs: multi-counter bounds, guard-certified `nsw`, typed GEPs

Status: measured on the working tree of 2026-09-23, committed 2026-09-24. All measurements are in-process
`elapsed_ns` from `benchmarks/build/*-suite`, alternating binaries, checksums equal.
The baseline is the project host at `0416128`, packaged with `tools/package.py`.

## What changed

- `src/ir/ranges.psm` (new) replaces `generateLoopRangeGuards` and its matcher in
  `src/ir/expr.psm`. It is an abstract interpretation over a loop's induction
  variables (`x = x ± step` updates, the step a literal or one invariant name,
  updates anywhere outside nested loops). A delta walk gives each access's span
  per variable, each variable's per-iteration growth, and relations
  (`out - left - right` constant on every continuing path). Head bounds come from
  the condition's `and` conjuncts (including `x + E < B` and `x < y` between
  counters moving in opposite directions), `for` bounds, and relations. Index
  intervals are evaluated in i64 in the preheader (`+ - *`, `/ %` by a positive
  literal with an operand-in-`Int` fact, `& m` with `m >= 0`).
- Proofs are **per access** (C table `ir_range_proof_*` in `runtime/ir_symbols.c`,
  keyed by AST node and a never-reused proof number), not per loop.
- Loops version up to three ways (`generateLoopVersions` in `src/ir/stmt.psm`):
  flat and proved / flat and checked / generic. When a proof covers every flat
  access, its facts join the flat guard and only two copies are emitted. The third
  copy measured a 7% spill-induced regression on a *neighbouring* fill loop in
  aos_vs_soa.
- Guard-certified flags. In the proved copy, updates of variables whose no-wrap
  facts are in the guard are `add nsw`/`sub nsw` (`ir_add_nsw`). A range `for`
  latch is always `nsw`. This is what lets IndVarSimplify widen the counters.
- `flat_element_address` in `runtime/llvm-api-backend.c`: one `[stride x i8]`
  GEP (inbounds where the index is known in range) instead of mul plus byte GEP.
  The mul was a separate instruction per branch arm, so MergedLoadStoreMotion
  could not merge the two arms' stores and the merge stayed branchy.
- Proved accesses use a preheader-loaded base (`rangeDataFor`).
- `for` loops now get the flat guard and range proofs; before, they had neither.
- The flat guard now walks the loop condition: its receivers were read flat but
  never representation-checked. It also skips `match` patterns, which were
  declining any loop that contained a payload match.
- Bug fix: payload match binders were bound in the enclosing scope in codegen
  (sema scoped them). A binder named like the loop counter hung the loop.
- Benchmark arms made the same program: lz4's Prismio input is `Vec<U8>` like
  C++/Rust. Dijkstra's heap now does Floyd's pop and hole-based sift-up, which is
  what libc++ `pop_heap` and Rust `BinaryHeap::pop` run.

## Numbers (scale 4)

| benchmark | before | after | C++ | Rust |
|---|---:|---:|---:|---:|
| mergesort | 5.09 ms | **3.75 ms** | 3.61 | 4.87 |
| dijkstra (arms matched) | 0.555 | 0.496 | 0.472 | 0.465 |
| lz4 (arms matched) | 0.445 | 0.426 | 0.334 | 0.379 |

Full 62-benchmark A/B against the baseline: everything else is within noise. Every
function whose mnemonics did not change moved only by layout, and knapsack sits at
1.009. `PRISMIO_RANGE_PROOFS=0` (measurement switch) keeps the versioning but
answers no access as proved.

## Findings worth keeping

- **For a wrapping `Int`, the lever is no-wrap, not the check.** A C model of
  binary_search: wrapping plus check 91 ms, wrapping without check **126 ms**,
  `nsw` plus check **75 ms**, `nsw` without check 74 ms (C++ 72, Prismio 89).
  binary_search needs relational facts (`L0 <= low <= mid <= high <= H0`) to
  certify `nsw`. That is a difference-bound-matrix tier, since built:
  `RESULTS-relational-tier.md` (binary_search 88.2 -> 69.9 ms, C++ 71.6).
- flat_bitset briefly regressed 1.15x. The check-free loop is *exactly* C++'s
  shape and runs at C++'s speed (1.44 ms). The baseline's 1.20 ms was block
  placement luck around the fused bounds-check `ccmp`. Two-copy versioning
  restored it.
- Prismio allows `copyInto(v, v)`: two `Vec` parameters may alias, so there is no
  language-level `noalias` to hand LLVM (Rust has one). Adding one is a language
  decision.

Tests: `tests/test_169_loop_range_proofs.psm` covers each shape with an adversarial
twin. The `loop_range_proofs` runner check asserts, via `PRISMIO_RANGE_TRACE=1`,
that every annotated loop is proved exactly `P/T`.
