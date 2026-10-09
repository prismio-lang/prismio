# Prismio performance benchmarks

This is the maintained cross-language performance suite for Prismio, C/C++, and
Rust. It lives at repository root because it evaluates the language as a whole;
it is not compiler correctness coverage and has no dependency on `tests/`.

## Two suites

| Suite | Compares | Measures | Directory |
| --- | --- | --- | --- |
| **hosted** | Prismio, C++, Rust on the host operating system | time: median of several runs, with a noise model | [`hosted/`](hosted) |
| **freestanding** | Prismio, C, Rust on bare-metal AArch64, no operating system | guest instructions under QEMU: exact and repeatable | [`freestanding/`](freestanding) |

They share this directory's runner (`run.py`), its results file
(`results/results.json`) and one report (`results/report.html`), which has a tab for each.
Everything below describes the **hosted** suite unless it says otherwise; the freestanding
suite, what it measures and why that is not time, is described in
[`freestanding/README.md`](freestanding/README.md).

```text
benchmarks/
  run.py            builds, runs and reports either suite
  hosted/           benchmarks.json, UNSUPPORTED.md, prismio/, cpp/, rust/
  freestanding/     benchmarks.json, harness/, prismio/, c/, rust/, suite.py
  templates/        report.html and report.css, the tabbed report
  results/          results.json (schema 4: one report per suite) and report.html
  build/            hosted/ and freestanding/ build products (not tracked)
```

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
`Int`s per node in one flat `Vec<Int>`, so it pays for one growing buffer where
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

### Manual memory: `std.mem`

Three workloads measure what a program does when it manages memory itself, which
every other memory benchmark leaves to the compiler:

| Benchmark | `std.mem` tool | C++ / Rust arm |
| --- | --- | --- |
| `binary_codec` | `Buffer`'s typed writes and reads: 16-byte records, three fields big-endian and one little-endian, encoded once and decoded eight times | `memcpy` and `__builtin_bswap*` over a `std::vector<unsigned char>` / `to_be_bytes` and `from_be_bytes` over a `Vec<u8>` |
| `manual_alloc_churn` | `alloc` and `free` in a window of 64 live blocks of 16 to 256 bytes | `malloc`/`free` / `std::alloc::alloc`/`dealloc` |
| `arena_bump` | a 20,000-node linked list built in an `Arena` per round, walked, then `reset` | a hand-written bump arena over a byte vector, the same in both |

The arena is hand-written in the C++ and Rust arms rather than taken from
`std::pmr` or a crate, so all three run the same alignment arithmetic and the
same capacity check. `custom_allocator_churn` stays unsupported: an `Arena` hands
out addresses, and a `Vec` or `Map` still cannot be given one to allocate from.

First numbers (Apple M-series, 9 runs): `binary_codec` 1.03× C++ and Rust,
`manual_alloc_churn` 0.98×, `arena_bump` 1.00×. `arena_bump` read 1.61× until
`Arena.alloc`'s panic messages moved into `cold` functions: built in place they
kept `alloc` from inlining and gave it a 240-byte frame on every call.

## Run

```bash
prismio bench
```

This uses `.prismio/build/debug/prismio`, defaults to the medium size and five
runs, and automatically uses Homebrew LLVM when it is installed. It runs **both
suites**; the freestanding one is skipped, with a note, when its tools (`qemu-system-aarch64`,
a working `ld.lld`, `rustc` with `rust-src`) are not installed. Runner options
can be appended when needed:

```bash
prismio bench --list
prismio bench --suite hosted
prismio bench --suite freestanding
prismio bench --runs 1 --only prime_sieve
prismio bench --open
```

`--only` takes workloads from either suite. Running one suite leaves the other's
last results in `results.json`, so a freestanding run does not discard the hosted numbers.

During execution, the command maintains one progress line instead of printing
every workload. On completion it writes two files to `benchmarks/results/`:

- `results.json` contains build timings, checksums, raw timing samples, and
  medians.
- `report.html` is a self-contained interactive report with searchable and
  sortable comparisons, precise nanoseconds, Prismio ratios, build timings, and
  unsupported coverage. It needs no server or external JavaScript dependency.

### When a difference counts

A flat percentage cannot be right for a 0.2 ms workload and a 200 ms one. The short
ones are dominated by things no code change moves -- process start, which core the
scheduler picks, the clock ramping up -- and they appear as **two timing modes**, not a
smooth spread: `edit_distance` runs in about 560 us or about 700 us in every language,
and the share of runs landing in each differs. So a result is a `win` or a `loss` only
when **both** the ratio of medians and the ratio of best runs leave a tolerance:

- on medians, the largest of `0.04`, either arm's own spread (interquartile range over
  the median) and a 25 us floor as a fraction of the run;
- on best runs, the larger of `0.04` and the same floor, because noise only adds time and
  the best run is the steadiest estimate of what the code costs.

Equal best runs with different medians is the signature of timing modes, and is parity.
The terminal summary, the row colours and the HTML report all read the recorded
`verdict`, so they cannot disagree, and each pill's tooltip says what it was judged
against. The measure is the interquartile range because a median-and-MAD figure reads a
bimodal run as 0% noise.

### What `results.json` records

The file is the single source for the HTML report and for the website's
benchmark page, so it carries everything needed to read a number against the
machine that produced it. Nothing in it is typed in: the harness probes the host
and toolchains each run, and a probe that finds nothing leaves its key out.

| Field | Meaning |
| --- | --- |
| `schema_version` | `4`. The file holds one report per suite under `suites` (`hosted`, `freestanding`), plus `generated_at` and `artifacts`. A file from before the split is the hosted report itself, and the report reads that too. Each suite's report keeps its own `schema_version` (the fields below are the hosted report's, `3`). |
| `generated_at`, `runs` | When the run finished (UTC) and the samples taken per arm. |
| `parity`, `noise_model` | The flat fraction (`0.04`) and the rest of the rule a verdict is decided by: a floor in nanoseconds for very short runs and the spread measure. See below. |
| `elimination_ns` | Below this an elimination workload counts as deleted. |
| `build_commands` | The exact build command per arm. **Repo-relative**: a path inside the checkout is relative to it and one outside (`clang++`) is its file name, so the file carries no path from the machine that wrote it. |
| `compile_ns`, `compile_cpu_ns`, `compile_runs`, `binary_bytes` | Build time (wall, then user + system CPU) and executable size per arm. The time is the median of `compile_runs` builds made in this run (default 1; `--compile-runs N`). CPU time is there because the arms do not use the machine alike: Prismio's backend is multi-threaded, `clang++ -flto` and `rustc -C codegen-units=1` are not, so wall time alone credits one arm with cores the others never asked for. |
| `cached_builds`, `cached_built_at` | Arms whose build was reused from an earlier run (only with `--reuse-reference-builds`); their times are that build's, dated here. Empty by default. |
| `compiler`, `build_skipped` | The compiler measured (path, size, modified time), and whether `--skip-build` left every executable as an earlier run built it. |
| `environment` | `processor`, `cores`, `memory_bytes`, `os`, `target`, `power`; `toolchains` (`prismio` with its `version` and the `profile` it was built in, `clang`, `rustc`, `llvm`); `source` (`commit`, `dirty`); `harness`. |
| `benchmarks` | One entry per workload with each arm's median, raw samples, and peak RSS, and a `verdict` against C++ and against Rust: `outcome` (`win`, `parity`, `loss`), the median `ratio`, the `best_ratio`, the `tolerance` it was judged against and the `noise` measured. |
| `artifacts` | Repo-relative paths of the report and the raw data. |

`environment.toolchains.prismio.profile` is worth reading before a compile-time
comparison: `prismio bench` measures the compiler built into `.prismio/build/debug/`,
so the Prismio compile time is a debug build's.

Use `prismio bench --open` to open the completed report automatically. The
default command only prints its path, which keeps CI and scripted runs quiet.

For unusual toolchains, invoke `benchmarks/run.py` directly and pass
`--compiler` or `PRISMIO`. `--llvm-bin` remains available when the system Clang
and the LLVM version used by the compiler differ.

**Every arm is rebuilt, and timed, on every run.** A compile time reused from an
earlier run was measured under another load and another toolchain state, and a
report that sets it beside a fresh Prismio figure compares two different days.
That is a cost of about 2 s of `clang++ -O3 -flto` and 2.6 s of `rustc` per run.
`--reuse-reference-builds` brings back the earlier behaviour for a quick check of
run time only: each of those two arms is then keyed on the *contents* of every
file under `cpp/` or `rust/`, the exact build command and the toolchain's own
`--version`, stamped beside the binary in `benchmarks/build/`, and the report
names what it reused (`cached_builds`, dated in `cached_built_at`). `--rebuild`
forces a rebuild even then, and `--compile-runs N` times N builds of each arm.

**The C++ arm uses LTO when the machine's linker can.** It is built `-O3 -flto` to match
the Rust arm's fat LTO, but on Linux the pinned LLVM ships neither the gold plugin GNU ld
needs nor an `ld.lld` that starts on every distribution, so `run.py` tries LTO with lld,
LTO with the default linker, and then no LTO, on a one-line program, and uses the first
that links. A run that fell back says so on stderr, and `build_commands` records the exact
command either way. Without LTO the C++ arm can only be slower, never faster.

**The compiler must be newer than its sources.** `prismio bench` measures
`.prismio/build/debug/prismio`, which is whatever was last promoted there. If
`src/`, `std/` or `runtime/` has been edited since, the bench refuses to run
(`--allow-stale-compiler` overrides) rather than describe the compiler from before
the edit. The check applies to the project's own compiler only, and the report
records which compiler it measured. `--skip-build` is the other way to get an old
number, and it says so on stderr and in the report.

The runner builds one release dispatcher per language, invokes only one named
workload per process, validates identical `result: <value>` output across all
three languages, and records the median workload-reported nanoseconds. Input
fixture creation is outside the timed region. Compilation and whole-process wall
time are recorded separately.

Release compilation:

```text
Prismio: <compiler> build benchmarks/hosted/prismio/suite.psm -o benchmarks/build/hosted/prismio-suite
C++:     clang++ -O3 -flto -std=c++20 -pthread benchmarks/hosted/cpp/{suite,algorithms,data_structures,compute,memory,io,adversarial}.cpp -o benchmarks/build/hosted/cpp-suite
Rust:    rustc -C opt-level=3 -C lto=fat -C codegen-units=1 --edition=2021 benchmarks/hosted/rust/suite.rs -o benchmarks/build/hosted/rust-suite
```

The C++ and Rust arms are built with whole-program optimisation (`-flto`, fat LTO
with one codegen unit) because the Prismio arm always is: the compiler internalises
every function but `main`, so the dispatcher's `scale = 4` reaches each workload as
a constant. Without it the other two arms receive `scale` across a translation-unit
boundary and divide by a run-time value with hardware `sdiv`, which on Apple
silicon beat the constant multiply-shift sequence by about 8% in `graph_bfs` and
made that workload read as a Prismio loss that C++ at the same constant does not
show (576 us against 575-578 us).

Each language mirrors the same production layout: category modules own the
workloads, a small common module owns shared types/helpers, and `suite` owns only
dispatch, timing, argument handling, and output. Prismio dispatch uses the
public `String.equals(...)` API.

## Coverage

The catalog contains 81 distinct workloads across six categories. Sixty-six
are implemented in all three languages. Fifteen remain
in the catalog as unsupported Prismio capabilities; their exact records are in
[`hosted/UNSUPPORTED.md`](hosted/UNSUPPORTED.md).

| Category | Implemented | Unsupported | Total |
|---|---:|---:|---:|
| Algorithms | 16 | 1 | 17 |
| Data structures | 7 | 4 | 11 |
| Compute | 15 | 4 | 19 |
| Memory | 10 | 1 | 11 |
| I/O and serialization | 6 | 5 | 11 |
| Adversarial | 12 | 0 | 12 |
| **Total** | **66** | **15** | **81** |

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
- Data structures (7 implemented, 4 unsupported):
  `hashmap_insert_lookup`, `vector_growth`, `vector_iteration`,
  `key_value_update`, `mixed_map_removal`, `flat_bitset`, `trie_search`;
  unsupported: `linked_list`, `binary_search_tree`, `priority_queue`,
  `lock_free_queue`.
- Compute (15 implemented, 4 unsupported): `matrix_multiply`, `mandelbrot`, `fft`,
  `numerical_integration`, `vector_dot`, `convolution`, `monte_carlo`,
  `polynomial_evaluation`, `ecs_component_update`, `parallel_reduction`,
  `sha256`, `blake3_chunk`, `raytracer_sphere`, `channel_pipeline`,
  `bytecode_interpreter`; unsupported: `async_event_loop`, `mutex_contention`, `work_stealing_pool`,
  `simd_vector_ops`.
- Memory (10 implemented, 1 unsupported): `transient_allocation`, `struct_creation`,
  `allocation_mutation`, `nested_collection`, `large_buffer_copy`,
  `recursive_tree_rebuild`, `string_join`, `binary_codec`, `manual_alloc_churn`,
  `arena_bump`; unsupported: `custom_allocator_churn`.
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
- Kept the AIF arena census scoped to the actual the retired corpus programs.
- Updated active documentation to point benchmark users at this root suite.
- Made no changes under `tests/`.
