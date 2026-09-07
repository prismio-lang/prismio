# Prismio performance benchmarks

This is the maintained cross-language performance suite for Prismio, C++, and
Rust. It lives at repository root because it evaluates the language as a whole;
it is not compiler correctness coverage and has no dependency on `tests/`.

The former `aif/evidence/xlang` programs were built to answer specific AIF
research questions. Their useful workload intent is represented here under
descriptive names. The superseded sources, raw results, and specialized
milestone scripts were removed from the working tree and remain recoverable from
Git history; narrative result documents are historical evidence, not inputs to
this runner.

## The three arms must be the same program

Not merely produce the same checksum -- **express the same algorithm**. This is
the invariant the suite exists to protect and it has been broken once, silently,
for as long as `knapsack` has existed.

`knapsack`'s C++ and Rust arms wrote the DP update as an unconditional store:

```cpp
best[at] = std::max(best[at], best[at - weight] + value);   // C++
best[at as usize] = best[at as usize].max(...);             // Rust
```

The Prismio arm wrote it as a *conditional* store -- `if (candidate > ...) {
list_set(...) }`. Same answer, different program: an unconditional store
vectorises and a conditional one does not, in **any** of the three languages.
Measured on a raw C array, the same loop is 220,000ns and 7 NEON ops written
with `if` against 188,000ns and 22 written with `max`. Prismio was being read as
1.37x of C++ when a third of that was the benchmark, not the compiler.

Checksums cannot catch this, and neither can review of one arm at a time. **When
adding or editing a benchmark, diff the three arms against each other
statement by statement**, and treat a difference in control flow -- a branch
where another arm has a select, a call where another has an inlined operation --
as a defect in the benchmark until measured otherwise.

A known and accepted difference remains in `mergesort`: C++ writes the merge
step as a ternary with side effects in both arms, Prismio as an `if`/`else` with
a store in each. Neither vectorises, so it is a spelling difference rather than
an algorithmic one -- recorded here so the next reader does not have to
re-derive that.

## Run

```bash
prismio bench
```

This uses `.prismio/build/debug/prismio`, defaults to the medium size and five
runs, and automatically uses Homebrew LLVM when it is installed. Runner options
can be appended when needed:

```bash
prismio bench --list
prismio bench --runs 1 --only prime_sieve
prismio bench --open
```

During execution, the command maintains one progress line instead of printing
every workload. On completion it writes two files to `benchmarks/results/`:

- `results.json` contains build timings, checksums, raw timing samples, and
  medians.
- `report.html` is a self-contained interactive report with searchable and
  sortable comparisons, precise nanoseconds, Prismio ratios, build timings, and
  unsupported coverage. It needs no server or external JavaScript dependency.

Use `prismio bench --open` to open the completed report automatically. The
default command only prints its path, which keeps CI and scripted runs quiet.

For unusual toolchains, invoke `benchmarks/run.py` directly and pass
`--compiler` or `PRISMIO`. `--llvm-bin` remains available when the system Clang
and the LLVM version used by the compiler differ.

The runner builds one release dispatcher per language, invokes only one named
workload per process, validates identical `result: <value>` output across all
three languages, and records the median workload-reported nanoseconds. Input
fixture creation is outside the timed region. Compilation and whole-process wall
time are recorded separately.

Release compilation:

```text
Prismio: <compiler> build benchmarks/prismio/suite.psm -o benchmarks/build/prismio-suite
C++:     clang++ -O3 -std=c++20 -pthread benchmarks/cpp/{suite,algorithms,data_structures,compute,memory,io,adversarial}.cpp -o benchmarks/build/cpp-suite
Rust:    rustc -C opt-level=3 --edition=2021 benchmarks/rust/suite.rs -o benchmarks/build/rust-suite
```

Each language mirrors the same production layout: category modules own the
workloads, a small common module owns shared types/helpers, and `suite` owns only
dispatch, timing, argument handling, and output. Prismio dispatch uses the
public `String.equals(...)` API.

## Coverage

The catalog contains 73 distinct workloads across six categories. Fifty-seven
are implemented in all three languages. Sixteen remain
in the catalog as unsupported Prismio capabilities; their exact records are in
[`UNSUPPORTED.md`](UNSUPPORTED.md).

| Category | Implemented | Unsupported | Total |
|---|---:|---:|---:|
| Algorithms | 13 | 1 | 14 |
| Data structures | 6 | 5 | 11 |
| Compute | 14 | 4 | 18 |
| Memory | 6 | 1 | 7 |
| I/O and serialization | 6 | 5 | 11 |
| Adversarial | 12 | 0 | 12 |
| **Total** | **57** | **16** | **73** |

Every benchmark has one canonical workload definition so results stay directly
comparable between runs. `--runs` controls sampling without changing the work
being measured. The JSON manifest is the source of truth for category, support
status, and workload profile.

### Catalog by category

- Algorithms (13 implemented, 1 unsupported): `fibonacci`, `prime_sieve`, `gcd_lcm`,
  `binary_search`, `quicksort`, `mergesort`, `string_search`, `graph_bfs`,
  `knapsack`, `tree_traversal`, `dijkstra_shortest_path`, `lz4_compress`,
  `s_expression_parse`; unsupported: `regex_matching`.
- Data structures (6 implemented, 5 unsupported):
  `hashmap_insert_lookup`, `vector_growth`, `vector_iteration`,
  `key_value_update`, `flat_bitset`, `trie_search`; unsupported: `linked_list`,
  `binary_search_tree`, `priority_queue`, `mixed_map_removal`, `lock_free_queue`.
- Compute (14 implemented, 4 unsupported): `matrix_multiply`, `mandelbrot`, `fft`,
  `numerical_integration`, `vector_dot`, `convolution`, `monte_carlo`,
  `polynomial_evaluation`, `ecs_component_update`, `parallel_reduction`,
  `sha256`, `blake3_chunk`, `raytracer_sphere`, `channel_pipeline`;
  unsupported: `async_event_loop`, `mutex_contention`, `work_stealing_pool`,
  `simd_vector_ops`.
- Memory (6 implemented, 1 unsupported): `transient_allocation`, `struct_creation`,
  `allocation_mutation`, `nested_collection`, `large_buffer_copy`,
  `recursive_tree_rebuild`; unsupported: `custom_allocator_churn`.
- I/O and serialization (6 implemented, 5 unsupported): `file_read`,
  `file_write`, `line_processing`, `tokenization`, `base64_codec`, `csv_parse`;
  unsupported: `json_parse`, `json_serialize`, `tcp_echo_server`, `mmap_file_io`,
  `generic_serialization`.
- Adversarial (12 implemented): `pointer_chase`, `random_gather`,
  `branch_mispredict`, `strided_memory`, `allocation_escape`,
  `function_call_overhead`, `indirect_calls`, `dependency_chain`, `aos_vs_soa`,
  `switch_dispatch`, `memcpy_mix`, `dead_code_elimination`.

### Adversarial benchmark design

These are diagnostic compiler and machine-behavior probes rather than general
algorithms. Their inputs are deterministic, and pseudo-random data is generated
before each hot loop rather than by a runtime RNG inside it.

- `pointer_chase` builds a shuffled single-cycle index chain, so each load
  determines the address of the next load. `random_gather` uses a separately
  generated irregular index stream.
- `branch_mispredict` uses pre-generated unpredictable conditions.
  `strided_memory` runs strides 1, 2, 4, 8, 16, 32, 64, and 128 with bounded
  offsets, covering contiguous through cache- and TLB-hostile access.
- `allocation_escape` repeatedly creates and consumes provably local structs.
  `function_call_overhead` repeatedly invokes a tiny direct-call candidate.
- Prismio closure values lower to statically specialized structs and calls; they
  are not runtime function pointers. Therefore `indirect_calls` uses the closest
  currently legitimate common workload: an unpredictable opcode dispatch to
  four same-signature functions. It should be upgraded to a true function-value
  table if Prismio gains an indirect callable representation.
- `dependency_chain` uses wrapping 32-bit arithmetic with a genuine
  loop-carried dependency. `aos_vs_soa` performs both equivalent layouts and
  rejects differing checksums.
- `switch_dispatch` contains 256 cases and runs sequential, randomized, and
  strongly biased case streams. `memcpy_mix` performs copy/modify/copy/modify
  sequences over 8, 16, 32, 64, 256, 4096, and 65536-byte logical buffers; the
  source loops intentionally leave recognition and lowering to each optimizer.
- `dead_code_elimination` computes a pure, expensive result that is deliberately
  unobserved and returns a constant. The loop must not be kept alive artificially.

## Original g1-g9 audit

| Original | Assessment | Root-suite disposition |
|---|---|---|
| g1 particles | Strong streaming/field-mutation workload | Retained as `ecs_component_update` |
| g2 frame cull | Strong transient-allocation workload, but coupled to rendering vocabulary | Retained as focused `transient_allocation` and `allocation_mutation` workloads |
| g3 scene graph | Strong retained recursive/index traversal | Retained as `tree_traversal` and `graph_bfs` |
| g4 ECS world | Strong component-array workload | Retained as `ecs_component_update` |
| g5 asset cache | Nested scan is useful, but the repository documents that its timing is below reliable A/A granularity | Replaced by focused `hashmap_insert_lookup`, `key_value_update`, and `nested_collection` workloads |
| g6 engine/game | Useful scenario but combines world rebuild, order allocation, simulation, and combat, making attribution weak | Decomposed into allocation, vector, and compute workloads |
| g7 tokenizer | Strong string/allocation discriminator | Retained as `tokenization` |
| g8 tree rebuild | Strong ownership/reuse discriminator | Retained as `recursive_tree_rebuild` |
| g9 parallel bands | Strong structured-concurrency discriminator | Retained as `parallel_reduction` |

No numeric `gN` names are used by the maintained suite.

## Interpretation cautions

- `hashmap_insert_lookup` and `key_value_update` compare each language's standard
  hash table. Hash functions, load policies, and randomized seeding differ, so
  the result measures the complete container implementation rather than only
  probing code.
- `tree_traversal` and `recursive_tree_rebuild` expose representation and
  ownership differences as well as traversal arithmetic.
- `parallel_reduction` includes creation and joining of four native tasks; it is
  not a persistent thread-pool benchmark.
- The in-memory data construction is intentionally part of allocation-oriented
  workloads. File fixture creation is excluded from I/O timing.
- `file_read` and `line_processing` are sensitive to the operating-system page
  cache. Use several interleaved runs and do not interpret tiny differences as
  language-runtime effects.
- `numerical_integration`, `mandelbrot`, and `ecs_component_update` use IEEE-754
  floating point. Checksums are validated, but cross-target reassociation or
  fused operations can affect boundary cases.

## Currently Unsupported by Prismio
 
- LinkedList/deque: `linked_list`
- Ordered tree set/map: `binary_search_tree`
- Binary heap/priority queue: `priority_queue`
- Map deletion: `mixed_map_removal`
- User-space atomics & memory barriers: `lock_free_queue`
- Mutual exclusion locks in std: `mutex_contention`
- Persistent work-stealing thread pool: `work_stealing_pool`
- Async runtime & non-blocking I/O loop: `async_event_loop`
- Network socket subsystem (std.net): `tcp_echo_server`
- Memory-mapped file I/O: `mmap_file_io`
- Regular expression engine & compiler: `regex_matching`
- JSON data model and parser: `json_parse`
- JSON data model, escaping, and serializer: `json_serialize`
- Compile-time derive / reflection: `generic_serialization`
- Explicit SIMD vector types & intrinsics: `simd_vector_ops`
- Pluggable custom container allocators: `custom_allocator_churn`

Potential future workloads unlocked by these facilities include LRU caches,
ordered range queries, Dijkstra/A*, high-concurrency event loops, lock-free ring
buffers, mmap log parsers, and zero-copy serialization pipelines.

## Infrastructure changes

- Removed the superseded `aif/evidence/xlang` tree and its specialized
  `milestone_bench.py`, `five_arm_bench.py`, and `allocator_bench.py` drivers.
  The deleted tracked content is recoverable from Git history.
- Updated `tools/ir_snapshot.py` to compile the root Prismio benchmark source.
- Kept the AIF arena census scoped to the actual `aif/corpus` programs.
- Updated active documentation to point benchmark users at this root suite.
- Made no changes under `tests/`.
