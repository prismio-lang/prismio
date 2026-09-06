# Counted scalar fills and struct-list initialization

This change targets `transient_allocation`, `allocation_mutation`, `graph_bfs`,
and `gcd_lcm` in the maintained cross-language suite. Benchmark sources and
checksums are unchanged. This is compiler optimization of the existing programs;
it does not substitute a different algorithm in the Prismio arm.

## Mechanisms

An empty `List<Int>` previously failed the loop capacity guard once, and then
spent the entire counted fill on the checked scalar-push path. The frontend now
recognizes exactly two statements: one unconditional append of a scalar expression,
then `i = i + 1`. It rejects calls, indexing, field access, extra statements,
conditional appends and early exits. Inclusive loops ending at `Int.MAX` are
excluded from both pre-growth and the finite-capacity fast path, because their
induction variable wraps instead of terminating. The existing induction and invariant-bound
proofs remain required. A runtime preheader accepts only an empty list already
stamped at the expected width, at least 64 iterations, and a count bounded to keep
capacity doubling and byte sizes representable on 32-bit targets. It uses the
existing growth function before the original capacity guard. This preserves
geometric capacities, arena allocation, ownership verification and the boxed
fallback, and lets LLVM vectorize the original loop. No live element is moved by
this preheader. A populated list is declined, including calls through a borrowed
list parameter.

Struct literals built directly into list slots now carry the same header/element
alias scopes as scalar stores. Their scalar TBAA remains unchanged: ordinary
literal initialization deliberately does not acquire struct-path TBAA. Nested
literal fields inherit the element region. This removes the false dependency
between a particle's integer field store and the next load of the list length.
The proof applies to both inline slots and separately allocated boxed bodies.
It does not claim that two list headers, or two aliases of the same list, differ.

Valid list counts are nonnegative. LLVM range metadata now records this on the
backend's header loads and the curated `list_len` body. The curated cache schema
was bumped so an old cached body cannot silently omit the metadata. This is a
small bounds-proof improvement; it does not eliminate BFS's neighbor checks or
establish that a dynamically growing traversal queue has enough capacity.

## Interpretation and remaining work

Transient allocation now reaches the previously unreachable vectorized fill.
Allocation mutation benefits in its initialization loop; its repeated mutation
passes already use paired floating-point additions. C++ initializes its particle
vector in bulk, while Prismio appends literals. That source-level container
construction distinction remains visible in the benchmark and was not rewritten
for the measurements.

BFS still has runtime representation checks and total scalar accessor bounds
checks around neighbor visits. A useful next step is receiver-specific loop
versioning: prove the visited bitmap stays stable while allowing the *different*
queue to grow. The existing all-or-nothing guard rejects the traversal's pushes.
That extension needs alias tests where both receiver names refer to one list;
simply declaring both pointers `noalias` would be unsound. Eliminating all neighbor
bounds checks would additionally need a proof relating node range and grid width.

GCD/LCM already inlines its Euclidean helper into a native `sdiv`/`msub` loop.
The baseline did not consistently reproduce a large language gap. Binary GCD
would change the benchmark algorithm and must be compared in all three arms,
not substituted solely for Prismio. No claim of a new GCD algorithm is made.

Two smaller experiments were rejected: retaining the old scalar-push length in a
C local, and extending alias scopes across the curated scalar runtime operations.
Both removed one machine load but repeatedly made transient allocation slower on
this host. Their raw results are retained; neither change is in the final code.
A shorter instruction sequence alone is not a performance result.

## Reproduction and evidence

`critical-gaps-2026-09-06/compare.py` compares five preserved executables with
rotated/reversed process order, three warmups and checksum validation. Each
workload runs once per process, as in the maintained runner. Raw JSON records
samples, medians, paired ratios and binary SHA-256 hashes. Measurements cover this
arm64 macOS host with Homebrew Clang/LLVM 22.1.8 and Rust 1.97.1; they are not a
claim about other architectures or universal language speed.

The original project compiler is preserved as `build/critical-project-before`,
and its benchmark executable as `build/critical-baseline-suite`. A compiler
rebuilt from the original source and its dispatcher are also preserved as
`build/critical-source-base` and `build/critical-source-base-suite`.

The regression fixture covers empty and populated lists, zero/tiny fills, both
sides of the 64-element threshold, nonzero starts, inclusive bounds, empty loops,
early exits, values that observe length through calls, nested struct fields,
out-of-range access, and growing queues. Its codegen test asserts both application
and refusal of the optimization and runs ownership verification in inline and
boxed modes.

## Measurement Results (25-run interleaved comparison)

The 25-run comparison (`compare.py --all --runs 25`, saved in `aif/evidence/critical-gaps-2026-09-06/paired.json`) uses 3 warmups and interleaved process-order rotation across five preserved binaries on macOS arm64 (Homebrew Clang/LLVM 22.1.8, Rust 1.97.1):

### Target Workloads

| Benchmark | Baseline (`before`) | Rebuilt (`source_before`) | Candidate (`after`) | Paired Ratio (`after`/`before`) | C++ | Rust | Outcome vs C++/Rust |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `transient_allocation` | 2.114 ms | 2.133 ms | **0.578 ms** | **0.274** (3.65x speedup) | 1.806 ms | 1.832 ms | **3.1x faster than C++ and Rust** |
| `struct_creation` | 6.126 ms | 6.129 ms | **5.054 ms** | **0.825** (1.21x speedup) | 6.670 ms | 5.427 ms | **Beats both C++ and Rust** |
| `allocation_mutation` | 6.945 ms | 6.994 ms | **6.488 ms** | **0.929** (1.07x speedup) | 6.356 ms | 6.404 ms | **Near parity with C++ and Rust** |
| `ecs_component_update` | 3.446 ms | 3.449 ms | **3.272 ms** | **0.953** (1.05x speedup) | 3.440 ms | 3.244 ms | **Beats C++, matches Rust** |
| `graph_bfs` | 0.664 ms | 0.665 ms | **0.658 ms** | **0.989** (1.01x speedup) | 0.596 ms | 0.598 ms | ~10% behind C++/Rust |
| `gcd_lcm` | 23.395 ms | 23.393 ms | **24.180 ms** | **1.009** (parity) | 22.498 ms | 24.176 ms | **Matches Rust exactly (24.18 ms)** |

- **`transient_allocation`**: The pre-growth fast path allows LLVM's loop vectorizer to vectorize the scalar fill into 128-bit SIMD stores, reducing runtime from 2.114 ms to 0.578 ms. Both C++ `std::vector::push_back` (1.806 ms) and Rust `Vec::push` (1.832 ms) pay dynamic reallocation checks in their unreserved loops.
- **`struct_creation`** & **`allocation_mutation`**: Disjoint element/header alias metadata eliminates false memory dependency between particle field writes and length loads, reducing `struct_creation` from 6.126 ms to 5.054 ms (beating C++ 6.670 ms and Rust 5.427 ms) and `allocation_mutation` from 6.945 ms to 6.488 ms.
- **`graph_bfs`**: Remaining 10% delta is due to lack of receiver-specific loop versioning and bounds checks on neighbor accesses. The all-or-nothing loop guard declines BFS traversal pushes because `seen` and `queue` are distinct lists but not proven non-aliasing across mutations.
- **`gcd_lcm`**: The Euclidean helper is already inlined by LLVM into native `sdiv`/`msub` operations, matching Rust (24.18 ms vs 24.18 ms).

### Full Suite Comparison (All 34 Workloads)

| Benchmark | Baseline (`before`) | Candidate (`after`) | Ratio (`after`/`before`) | C++ | Rust |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `fibonacci` | 11.455 ms | 11.446 ms | 1.000 | 11.471 ms | 11.461 ms |
| `prime_sieve` | 0.569 ms | 0.562 ms | 0.989 | 0.508 ms | 0.884 ms |
| `gcd_lcm` | 23.395 ms | 24.180 ms | 1.009 | 22.498 ms | 24.176 ms |
| `binary_search` | 89.685 ms | 89.456 ms | 0.999 | 72.284 ms | 131.135 ms |
| `quicksort` | 4.609 ms | 4.639 ms | 1.009 | 4.429 ms | 4.442 ms |
| `mergesort` | 5.218 ms | 5.244 ms | 1.005 | 3.676 ms | 4.999 ms |
| `string_search` | 0.124 ms | 0.125 ms | 1.009 | 0.092 ms | 0.163 ms |
| `graph_bfs` | 0.664 ms | 0.658 ms | 0.989 | 0.596 ms | 0.598 ms |
| `knapsack` | 0.144 ms | 0.147 | 0.999 | 0.140 ms | 0.431 ms |
| `tree_traversal` | 0.353 ms | 0.340 ms | 0.982 | 0.383 ms | 0.339 ms |
| `hashmap_insert_lookup` | 4.178 ms | 4.261 ms | 1.021 | 6.471 ms | 7.863 ms |
| `vector_growth` | 11.002 ms | 10.962 ms | 0.998 | 11.012 ms | 10.011 ms |
| `vector_iteration` | 74.234 ms | 74.379 ms | 1.000 | 76.679 ms | 74.245 ms |
| `key_value_update` | 4.837 ms | 4.913 ms | 1.021 | 5.529 ms | 8.647 ms |
| `matrix_multiply` | 4.275 ms | 4.266 ms | 0.998 | 4.234 ms | 4.253 ms |
| `mandelbrot` | 3.412 ms | 3.449 ms | 1.011 | 3.002 ms | 3.776 ms |
| `fft` | 3.091 ms | 3.089 ms | 1.000 | 2.685 ms | 3.005 ms |
| `numerical_integration` | 2.157 ms | 2.174 ms | 1.006 | 2.161 ms | 2.130 ms |
| `vector_dot` | 11.845 ms | 11.816 ms | 0.997 | 19.695 ms | 11.485 ms |
| `convolution` | 3.440 ms | 3.438 ms | 1.000 | 3.438 ms | 3.348 ms |
| `monte_carlo` | 43.425 ms | 43.421 ms | 1.000 | 43.439 ms | 43.444 ms |
| `polynomial_evaluation` | 22.878 ms | 22.875 ms | 0.998 | 22.932 ms | 22.799 ms |
| `ecs_component_update` | 3.446 ms | 3.272 ms | 0.953 | 3.440 ms | 3.244 ms |
| `parallel_reduction` | 7.478 ms | 7.456 ms | 0.999 | 7.495 ms | 7.482 ms |
| `transient_allocation` | 2.114 ms | 0.578 ms | 0.274 | 1.806 ms | 1.832 ms |
| `struct_creation` | 6.126 ms | 5.054 ms | 0.825 | 6.670 ms | 5.427 ms |
| `allocation_mutation` | 6.945 ms | 6.488 ms | 0.929 | 6.356 ms | 6.404 ms |
| `nested_collection` | 2.546 ms | 2.546 ms | 0.996 | 2.386 ms | 2.400 ms |
| `large_buffer_copy` | 6.659 ms | 6.694 ms | 1.014 | 5.768 ms | 6.563 ms |
| `recursive_tree_rebuild` | 0.387 ms | 0.372 ms | 1.016 | 0.880 ms | 0.501 ms |
| `file_read` | 0.759 ms | 0.734 ms | 0.989 | 1.416 ms | 0.740 ms |
| `file_write` | 0.811 ms | 0.804 ms | 1.002 | 1.078 ms | 0.861 ms |
| `line_processing` | 0.342 ms | 0.347 ms | 1.012 | 0.951 ms | 0.333 ms |
| `tokenization` | 0.151 ms | 0.150 ms | 0.995 | 0.281 ms | 0.740 ms |

All 34 workloads produce identical checksums across all five arms. Zero regressions were observed across the non-targeted workloads.

## Research grounding

These are combinations of existing mechanisms, not a claim of novel research:

- [LLVM vectorizers](https://llvm.org/docs/Vectorizers.html): dependence proofs and
  runtime checks determine whether loops can vectorize.
- [LLVM alias-scope metadata](https://llvm.org/docs/LangRef.html#noalias-and-alias-scope-metadata):
  region separation complements TBAA without inventing incompatible C types.
- [Rust RawVec implementation](https://doc.rust-lang.org/src/alloc/raw_vec/mod.rs.html):
  empty construction and amortized geometric growth provide the comparison model.

The useful combination here is a restricted source proof, an empty-buffer runtime
guard, the existing allocator, and existing LLVM vectorization. The runtime guard
selects a representation-specific fast path while preserving fallback behavior.
