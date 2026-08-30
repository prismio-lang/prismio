# Loop versioning exposes Prismio's flat-list fast path

**Status: GREEN, 2026-08-30.** Compiler `build/unswitch-gen2`, LLVM 22.1.8 on
Apple Silicon. Fixed point, suite **202/202**, AIF differential **19/19**, all
corpus checksums unchanged.

This is a backend optimization, not an AIF rule. It was found by comparing the
actual hot-loop machine code with Rust's and then checking the current LLVM
pipeline rather than changing the ownership model.

## The remaining branch

`List<T>` has two physical representations. Flat, non-counted `T` is stored
inline; other elements are boxed. `list_get_inline` is curated and inlined, and
ordinary `-O2` already hoists `data`, `len`, and `elem_size` into the loop
preheader. It does not version this invariant choice, so each iteration still
selects between:

```text
inline: data + index * elem_size
boxed:  data[index]
```

Rust's `Vec<T>` is monomorphic after generic specialization and has no matching
mode branch. Its source also keeps `push` small and outlines the capacity-growth
path. Prismio had already copied the outlining half, but not the monomorphic
loop shape.

Deleting Prismio's fallback is unsound. An empty list may remain boxed when
inline storage is disabled or when the element disposition requires identity.
The earlier `list_get_inline` evidence records the resulting wrong-address read.

LLVM's non-trivial loop unswitch pass is the safe form of the specialization:
clone the loop, test the invariant once, and preserve both representations. The
LLVM implementation describes the same transformation for uncertain alias
conditions: a runtime check selects an aggressive and a conservative loop
version. See LLVM's
[LoopVersioningLICM source](https://llvm.org/doxygen/LoopVersioningLICM_8cpp_source.html)
and [auto-vectorization documentation](https://llvm.org/docs/Vectorizers.html).

The driver now enables LLVM 22's existing non-trivial unswitching in optimized
program builds:

```text
-O2 -mllvm -enable-nontrivial-unswitch
```

Debug builds remain `-O0` and do not receive the flag.

## What changed in machine code

Before, g4's movement loop contains the representation branch in its loop body.
After, the preheader selects an inline or boxed loop and the inline loop walks
stable bases and strides. More importantly, later loops in g4 become eligible
for LLVM's loop vectorizer once their invariant representation branch is out of
the body.

This follows LLVM's documented legality/profitability split: the vectorizer can
generate runtime pointer checks and handles reductions and interleaved accesses,
but it still needs a loop body whose control flow exposes a profitable plan.
LLVM's current [VPlan design](https://llvm.org/docs/VectorizationPlan.html)
explicitly models and costs those alternatives.

## Seven-program A/B

Twenty-five interleaved runs, `build/v0.1-rc` against `build/unswitch-gen2`.
Raw result: `/tmp/prismio-unswitch-all-ab.json`.

| program | new / old | interpretation |
|---|---:|---|
| g1 | 1.032x | flat |
| g2 | 1.018x | flat |
| g3 | 0.999x | flat |
| g4 | **0.889x** | **11.1% faster** |
| g5 | 0.863x | not claimable; the g5 A/A floor is wider |
| g6 | 0.977x | flat |
| g9 | 0.999x | flat |
| **median** | **0.999x** | gate passed |

The separate balanced five-arm run reproduces g4 in the same direction:
34.291 ms old, 29.393 ms new, **0.857x**. Its raw result is
`/tmp/prismio-unswitch-five-arm.json`.

Direct old/new measurements of the hand-tuned Prismio sources are neutral at the
median: g1 1.001x, g2 0.998x, g3 0.999x, g4 1.012x, g5 0.958x, g6 0.977x,
g9 0.984x. The transformation helps a missed natural loop; it does not erase the
remaining algorithmic gap to tuned Rust.

## Cost

- g4's `program -O2` stage moves from a median of roughly 56 ms to 62 ms.
- g2 and g4 executables grow by 16 KiB because a loop body is cloned. They remain
  more than four times smaller than the Rust controls in this harness.
- Other measured executable sizes are unchanged.
- No allocation, ownership, layout, or ABI fact changes.

The cost is accepted because the corpus median is neutral, g4's improvement is
reproduced, and the toolchain is pinned to LLVM major 22, where the option exists.

## Why Prismio still loses to tuned Rust

The 2026-08-30 five-arm run after this change reads:

| program | Prismio natural / Rust idiomatic | Prismio tuned / Rust tuned |
|---|---:|---:|
| g1 | 1.05x | **0.99x** |
| g2 | 1.53x | 1.18x |
| g3 | **0.97x** | 1.15x |
| g4 | 1.35x | 1.16x |
| g5 | 1.13x | 1.83x |
| g6 | 1.61x | 1.62x |
| g9 | **0.91x** | 1.06x |

Three different gaps are being conflated if these are treated as one compiler
problem:

1. **Representation dispatch and optimization exposure.** This change attacks
   it. The remaining robust case is a compiler-level flat-list loop view: one
   checked `(base, len, stride)` descriptor per loop rather than one resolved
   element per iteration.
2. **Program transformations.** Tuned g4 fuses systems; tuned g5 precomputes CSR
   material buckets; tuned g6 resets worlds and buffers. These are not memory
   placement decisions. Automatic loop fusion, invariant partitioning, and
   bufferization need dependence proofs and profitability evidence.
3. **Runtime algorithms.** Tuned g9 measures channel and wake-up cost after both
   languages have persistent workers. Prismio sends heap objects through a
   general MPMC interface even where the topology is statically one producer and
   one consumer. A bounded SPSC specialization is a runtime/API task, not LLVM
   code generation.

## Research-directed next order

1. **Profile-guided, targeted loop versioning.** Global unswitching paid 6 ms and
   16 KiB to find one robust win. LLVM and rustc both support IR-level
   instrumentation PGO specifically to guide inlining, branch layout, register
   allocation, and similar decisions. Feed Prismio's existing declared workload
   into LLVM PGO and retain only versions whose hot path is observed. See the
   [rustc PGO implementation guide](https://rustc-dev-guide.rust-lang.org/profile-guided-optimization.html)
   and [LLVM PGO documentation](https://llvm.org/docs/HowToBuildWithPGO.html).
2. **A typed flat-list view in Prismio IR.** Keep the boxed fallback at the
   boundary, but version once and lower the hot body as direct GEPs. This is the
   compiler-level analogue of Rust's monomorphic `Vec<T>` and avoids relying on
   a hidden global LLVM switch for the core container abstraction.
3. **Dependence-driven fusion and DataView selection.** The existing DataView
   result already reaches parity with tuned Rust on g1. The 2025 data-view work
   argues for explicit or annotation-guided conversion rather than unconstrained
   automatic layout search: [annotation-guided AoS-to-SoA data views](https://arxiv.org/pdf/2502.16517).
4. **Reuse only on its real trigger.** Perceus pairs a dead constructor with a
   same-size new constructor and specializes the unique path; frame-limited reuse
   bounds token retention. That belongs on `g8_tree_rebuild`, which actually has
   destructure/rebuild shape, not on g2/g6's cross-frame buffers. See
   [Perceus](https://xnning.github.io/papers/perceus.pdf) and
   [frame-limited reuse](https://www.microsoft.com/en-us/research/wp-content/uploads/2021/11/flreuse-tr.pdf).
5. **Factored recursive layouts after reuse ownership is sound.** The May 2026
   SoCal work separates recursive ADT tags and fields into coordinated buffers
   and reports a 1.46x geometric-mean traversal gain. That is directly relevant
   to g3/g8, but it follows ownership/reuse correctness rather than replacing it:
   [SoCal](https://arxiv.org/pdf/2605.01140).
6. **Non-lexical, sized regions for temporary graphs.** Spegion's effect system,
   splittable regions, and sized allocations match Prismio's open region extent
   problem more closely than another allocator swap:
   [Spegion](https://arxiv.org/pdf/2506.02182).

## Experiments rejected during this investigation

- Curating `list_push_slot`: corpus median 0.998x; no durable win.
- Adding `noalias` to list constructors: emitted IR changed, g2 machine code did
  not; the slow helper's effects still blocked the desired proof.
- Lowering every `private` Prismio function as LLVM `internal`: corpus median
  1.038x and g6 1.225x. Blanket inlining/layout changes are not a substitute for
  hotness information.

Those three results are why the accepted change uses an existing loop transform
with a preserved fallback and why PGO is ranked above more global inlining.

## Gate

| check | result |
|---|---|
| bootstrap fixed point | `unswitch-g1.ll == unswitch-g2.ll` |
| suite | **202/202** |
| AIF differential | **19/19**, as-is and owned |
| corpus checksums | unchanged on every arm |
| source lists / `git diff --check` | clean |

