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

**A second near-miss, caught by the checksums rather than by review.**
`bytecode_interpreter`'s multiply overflows a signed 32-bit int. Prismio's `Int`
wraps; C++'s signed overflow is undefined, so the C++ arm was first written to
promote to `int64_t` to stay defined. Same intent, different program — and the
three checksums disagreed immediately. The fix was not to make one arm match the
other but to remove the overflow from all three: stack values are reduced modulo
**46337**, because 46336 squared is the largest product that fits. Prefer a
value range where the three languages cannot disagree over a cast that hides the
disagreement.

A known and accepted difference remains in `mergesort`: C++ writes the merge
step as a ternary with side effects in both arms, Prismio as an `if`/`else` with
a store in each. Neither vectorises, so it is a spelling difference rather than
an algorithmic one -- recorded here so the next reader does not have to
re-derive that.

**A known difference that is *not* accepted remains in `s_expression_parse`, and
it favours Prismio.** C++ and Rust allocate a node per expression
(`std::make_unique`, `Box`) and free every tree; the Prismio arm stores three
`Int`s per node in one flat `List<Int>`, so it pays for one growing buffer where
the others pay for about 50,000 allocations and frees. Read its ratio as a
parse-and-evaluate comparison, not an allocation one.

It stays that way because Prismio cannot yet write the allocating version
correctly, and that is measured rather than assumed. An enum AST built the
natural way -- `let left = ...; let right = ...; return Op(op, left, right)` --
**double-frees** (`release of a pointer that is not live`, then an abort). The
same tree with the children built inside the constructor call matches the
checksum, 466763307, but **leaks 14,505 of its 65,719 allocations**, so it would
measure allocation without the frees the other arms pay for. Both reproduce on
the compiler at `727c704`; KNOWN_ISSUES has the reproducer. When they are fixed,
this arm should build a node per expression like the other two.

## What each benchmark is for

Most entries are microbenchmarks isolating one behaviour. Five deliberately are
not, and they were added because the suite had no coverage of these shapes:

| Benchmark | What it exercises that nothing else did |
| --- | --- |
| `word_frequency` | The only **multi-phase** workload: split, hash-map count, lookup, sort, with data shared across phases. A whole-program memory model makes escape and placement decisions that a single-phase loop cannot force into conflict. |
| `sort_strings` | Comparison sort where the compare is a **call** and the element is not a word. `quicksort`/`mergesort` sort `Int`, where the comparison vectorises. |
| `edit_distance` | **Two-dimensional** DP indexing two buffers and a source string per iteration. `knapsack` is one-dimensional over one array. |
| `string_join` | Owned-string **construction**. `tokenization`, `string_search` and `csv_parse` all read strings; none builds one. |
| `bytecode_interpreter` | Dispatch with a **carried stack**, so the branch sees a trace rather than a distribution. `switch_dispatch` branches on a value and carries nothing. |

Three of the five landed in the suite's slowest-for-Prismio group on their first
run, which is the point: a benchmark that only confirms what the existing ones
already say has not earned its place.

Two of them make a deliberate library-facility choice rather than hand-rolling.
`word_frequency` uses each language's standard hash map, and `sort_strings` each
language's standard unstable sort — `std::sort`, `sort_unstable`, and `sort`.
Comparing those *is* the comparison, the same way `linked_list` is unsupported
rather than hand-built. Where a language has no such facility the arm writes the
loop the library would: C++ has no `join`, so `string_join`'s C++ arm sizes the
result and copies once, which is what the other two do internally.

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

**The C++ and Rust arms are cached; the Prismio arm never is.** Those two are
fixed reference points, so rebuilding them on every run is pure waiting -- about
3.5 s of `clang++ -O3` and 0.9 s of `rustc` -- and a one-workload run drops from
7.0 s to 2.1 s without them. Each is keyed on the *contents* of every file under
`cpp/` or `rust/`, the exact build command, and the toolchain's own `--version`,
stamped beside the binary in `benchmarks/build/`. Headers and the Rust modules
`suite.rs` only declares are in the key even though they are not on the command
line, which is the case an mtime-against-the-command cache gets wrong. A
toolchain upgrade invalidates, so a Homebrew LLVM bump is never measured against
a binary the previous one built. `results.json` names the arms it served from
cache in `cached_builds`, because their `compile_ns` is the earlier build's.

The Prismio arm is excluded on purpose: its *compiler* is the working tree, and
"the sources did not change but the compiler did" is exactly what this matrix
exists to measure. Pass `--rebuild` to force the other two.

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

The catalog contains 78 distinct workloads across six categories. Sixty-two
are implemented in all three languages. Sixteen remain
in the catalog as unsupported Prismio capabilities; their exact records are in
[`UNSUPPORTED.md`](UNSUPPORTED.md).

| Category | Implemented | Unsupported | Total |
|---|---:|---:|---:|
| Algorithms | 16 | 1 | 17 |
| Data structures | 6 | 5 | 11 |
| Compute | 15 | 4 | 19 |
| Memory | 7 | 1 | 8 |
| I/O and serialization | 6 | 5 | 11 |
| Adversarial | 12 | 0 | 12 |
| **Total** | **62** | **16** | **78** |

Every benchmark has one canonical workload definition so results stay directly
comparable between runs. `--runs` controls sampling without changing the work
being measured. The JSON manifest is the source of truth for category, support
status, and workload profile.

### Catalog by category

- Algorithms (16 implemented, 1 unsupported): `fibonacci`, `prime_sieve`, `gcd_lcm`,
  `binary_search`, `quicksort`, `mergesort`, `string_search`, `graph_bfs`,
  `knapsack`, `tree_traversal`, `dijkstra_shortest_path`, `lz4_compress`,
  `s_expression_parse`, `word_frequency`, `sort_strings`, `edit_distance`;
  unsupported: `regex_matching`.
- Data structures (6 implemented, 5 unsupported):
  `hashmap_insert_lookup`, `vector_growth`, `vector_iteration`,
  `key_value_update`, `flat_bitset`, `trie_search`; unsupported: `linked_list`,
  `binary_search_tree`, `priority_queue`, `mixed_map_removal`, `lock_free_queue`.
- Compute (15 implemented, 4 unsupported): `matrix_multiply`, `mandelbrot`, `fft`,
  `numerical_integration`, `vector_dot`, `convolution`, `monte_carlo`,
  `polynomial_evaluation`, `ecs_component_update`, `parallel_reduction`,
  `sha256`, `blake3_chunk`, `raytracer_sphere`, `channel_pipeline`,
  `bytecode_interpreter`; unsupported: `async_event_loop`, `mutex_contention`, `work_stealing_pool`,
  `simd_vector_ops`.
- Memory (7 implemented, 1 unsupported): `transient_allocation`, `struct_creation`,
  `allocation_mutation`, `nested_collection`, `large_buffer_copy`,
  `recursive_tree_rebuild`, `string_join`; unsupported: `custom_allocator_churn`.
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
