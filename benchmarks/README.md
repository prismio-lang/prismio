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
C++:     clang++ -O3 -std=c++20 -pthread benchmarks/cpp/{suite,algorithms,data_structures,compute,memory,io}.cpp -o benchmarks/build/cpp-suite
Rust:    rustc -C opt-level=3 --edition=2021 benchmarks/rust/suite.rs -o benchmarks/build/rust-suite
```

Each language mirrors the same production layout: category modules own the
workloads, a small common module owns shared types/helpers, and `suite` owns only
dispatch, timing, argument handling, and output. Prismio dispatch uses the
public `String.equals(...)` API.

## Coverage

The catalog contains 40 distinct workloads across the requested five
categories. Thirty-four are implemented in all three languages. Six remain
in the catalog as unsupported Prismio capabilities; their exact records are in
[`UNSUPPORTED.md`](UNSUPPORTED.md).

| Category | Implemented | Unsupported | Total |
|---|---:|---:|---:|
| Algorithms | 10 | 0 | 10 |
| Data structures | 4 | 4 | 8 |
| Compute | 10 | 0 | 10 |
| Memory | 6 | 0 | 6 |
| I/O and serialization | 4 | 2 | 6 |
| **Total** | **34** | **6** | **40** |

Every benchmark has one canonical workload definition so results stay directly
comparable between runs. `--runs` controls sampling without changing the work
being measured. The JSON manifest is the source of truth for category, support
status, and workload profile.

### Catalog by category

- Algorithms (10 implemented): `fibonacci`, `prime_sieve`, `gcd_lcm`,
  `binary_search`, `quicksort`, `mergesort`, `string_search`, `graph_bfs`,
  `knapsack`, `tree_traversal`.
- Data structures (4 implemented, 4 unsupported):
  `hashmap_insert_lookup`, `vector_growth`, `vector_iteration`,
  `key_value_update`; unsupported: `linked_list`, `binary_search_tree`,
  `priority_queue`, `mixed_map_removal`.
- Compute (10 implemented): `matrix_multiply`, `mandelbrot`, `fft`,
  `numerical_integration`, `vector_dot`, `convolution`, `monte_carlo`,
  `polynomial_evaluation`, `ecs_component_update`, `parallel_reduction`;
- Memory (6 implemented): `transient_allocation`, `struct_creation`,
  `allocation_mutation`, `nested_collection`, `large_buffer_copy`,
  `recursive_tree_rebuild`.
- I/O and serialization (4 implemented, 2 unsupported): `file_read`,
  `file_write`, `line_processing`, `tokenization`; unsupported: `json_parse`,
  `json_serialize`.

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
- JSON data model and parser: `json_parse`
- JSON data model, escaping, and serializer: `json_serialize`

Potential future workloads unlocked by these facilities include LRU caches,
ordered range queries, Dijkstra/A*, churn-heavy maps, and JSON processing
pipelines.

## Infrastructure changes

- Removed the superseded `aif/evidence/xlang` tree and its specialized
  `milestone_bench.py`, `five_arm_bench.py`, and `allocator_bench.py` drivers.
  The deleted tracked content is recoverable from Git history.
- Updated `tools/ir_snapshot.py` to compile the root Prismio benchmark source.
- Kept the AIF arena census scoped to the actual `aif/corpus` programs.
- Updated active documentation to point benchmark users at this root suite.
- Made no changes under `tests/`.
