# Null empty variants for boxed recursive enums

Measured 2026-09-05 on this Apple Silicon host. The baseline includes the prior
loop, push, map-probing and map-update work. These gains come from compiler
representation changes applied to the existing benchmark source.

## Result

| Benchmark | Before ms | After ms | Speedup | C++ ms | Rust ms |
|---|---:|---:|---:|---:|---:|
| tree_traversal | 0.641291 | 0.340292 | **1.88x** | 0.365292 | 0.325375 |
| recursive_tree_rebuild | 0.557041 | 0.344958 | **1.61x** | 0.859208 | 0.489583 |

Traversal beats C++ by 6.8% and remains 4.6% slower than Rust in this run.
Rebuilding beats C++ by 59.9% and Rust by 29.5%. These are workload-specific
measurements, not a claim about the relative speed of the languages generally.

The experiment uses one frozen source/stdlib snapshot for all builds, identical
Prismio benchmark code in the before/after arms, and the maintained C++/Rust
sources. Target workloads have 20 discarded warmups and 31 measured samples per
arm, with deterministic randomized execution order. A repeated baseline arm
measures 0.633291 ms and 0.553375 ms respectively. Other workloads have four
warmups and nine samples. Compiler, executable and source hashes, samples and
toolchain versions are saved in `enum-npo-2026-09-05/measurements.json`.

After installing the compiler, `prismio bench --runs 7` completed all 34
implemented workloads and refreshed the normal HTML/JSON report. That shorter,
noisier run measured traversal at 0.400 ms (C++ 0.409, Rust 0.381) and rebuilding
at 0.346 ms (C++ 0.851, Rust 0.486). The table above reports the controlled
31-sample comparison; the CLI report is preserved as `prismio-bench-results.json`.

## Representation and safety boundaries

For a recursive binary payload enum with exactly one empty variant, such as
`enum Tree { Empty, Node(Tree, Int, Tree) }`, the compiler emits null for Empty.
Node keeps its existing allocation and field layout. A match selects the
variant from pointer nullness, eliminating the tag load. The existing release
helpers already terminate at null, as do the runtime RC/container operations.
Empty construction is handled before constructor reuse, so a consuming Empty
arm cannot write fields through a null reuse token.

This is an application of null pointer optimization, a technique also documented
for Rust's optional pointers. It is not a new representation algorithm.
[Rust Option representation](https://doc.rust-lang.org/std/option/#representation)
describes the related non-null pointer niche; Prismio uses the pointer to its
boxed recursive enum node rather than a Rust Box payload.

The implementation declines inline/POD enums, split layouts, non-recursive
enums, enums with other variant shapes, and direct foreign uses. A resolved-type
walk also reserves null for any `T?` use: a present `T.Empty` must remain distinct
from absence. This includes generic and container type annotations. All imported
code is considered before representations are registered.

Only six function instruction sequences change in the benchmark executable:
the two tree builders, two sums, consuming add, and rebuild entry point. See
`enum-npo-2026-09-05/codegen.txt`. No benchmark-specific function names occur in
the optimization.

## Why the pass is restricted to recursive enums

The first implementation also optimized non-recursive boxed options. Tree gains
were substantial, but knapsack slowed by about 6%, confirmed over 41 samples.
Its instruction sequence did not change; earlier String option helpers shrank
and moved its address from `0x10000ded8` to `0x10000deb0`.

Restricting the optimization to recursive enums restores that address and removes
those unrelated changes. The final confirmation measures knapsack at
138417 ns before, 137500 ns after, and 138666 ns for the repeated baseline.
This supports code placement as the cause of the rejected variant's regression;
it does not justify a general function-alignment policy. The broad experiment's
data is preserved under `enum-npo-2026-09-05/broad-*`.

File-write timings remain noisy: the final confirmation's baseline repeat is
15.7% faster than the same baseline executable in the other arm, larger than
the candidate's 4.8% difference. Its instruction sequence is unchanged. No file
I/O improvement or regression is attributed to this change. Allocation-mutation
also had a noisy initial result; confirmation is 7.056 ms before, 6.955 ms after,
and 7.073 ms for the repeated baseline.

## Allocation and validation evidence

The final compiler passes **299/299 tests**. Two self-hosted generations emit
byte-identical compiler IR with SHA-256
`0f1656a3256be8f9abaeccb416fb4f7d0c71e1b6b3c5c9434a0bdd7559d07ef5`.
The final direct-suite log and compiler/host hashes are recorded alongside the
measurement JSON. The validated binary is installed as the project host used
by `prismio bench`; the previous host is saved at `build/enum-npo/host-before`.

| Benchmark process | Allocations before | Allocations after |
|---|---:|---:|
| tree_traversal | 32,772 | **16,388** |
| recursive_tree_rebuild | 16,388 | **8,196** |

Exactly 16,384 and 8,192 empty-leaf allocations disappear. Process overhead is
included, so the totals differ from the spec's estimated 16,384/8,192 targets.
Peak live bytes approximately halve. All 34 benchmark checksums agree across
the five timing arms. All 68 paired verification runs report zero violations
and the same two pre-existing benchmark-process leaks (MEM-038).

Tests 127–129 cover both variant orders, consuming reconstruction, nested
options, inline enum storage, extra variants, optional-reference exclusion,
foreign-pointer exclusion, full-tree teardown, and shared empty values. The
isolated ownership fixture records **1,027 allocated / 1,027 released / zero
leaks / zero violations** after the change.

The broad semantic fixture also reaches pre-existing ownership-analysis limits;
its successful output is not treated as a clean memory ledger. An earlier
version exposing temporary/sink/inline-field ownership issues is retained in
`preexisting-ownership-repro.psm`. Those issues reproduce on the before compiler
and are outside this optimization. The isolated ownership test and benchmark
ledgers are the evidence for allocation savings and correct reclamation here.

The independent AIF oracle still disagrees on six cases. Before/after reports
are identical except for the compiler path; no AIF inference rule changed.
The saved intermediate release-gate log also contains two suite failures from
the test-development stage; final direct-suite results supersede that portion.

## Reproduction

`enum-npo-2026-09-05/measure.py` takes `--phase build`, `--phase measure`, and
`--phase verify`. Its work directory contains `before`, `compiler`, and the
frozen `snapshot/{std,benchmarks/...}` tree. Complete compilation and tests
before running the timing phase. `build/enum-npo/before-repo` preserves the
source/runtime/compiler baseline from before this pass.

The remaining large benchmark gaps include map updates and FFT. This pass does
not claim to solve their independent lookup and loop-access costs.
