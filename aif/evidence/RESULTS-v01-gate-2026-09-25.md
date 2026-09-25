# The v0.1 gate and benchmark matrix on the branch head, 2026-09-25

**Status: GREEN locally, with the environment noted.** The compiler built from
`33590e4` (the memory-safety blockers, `readLines`, `StringBuilder`, and the
`test_181` fix), packaged. x86_64 Linux, Xeon @ 2.10 GHz, 4 cores, LLVM 23.1.1.
This is not the release candidate: RELEASE_CHECKLIST.md §5 asks for the gate on
`main`'s head after the merge, on all three platforms.

## 1 · `tools/release_gate.py`

Run as RELEASE.md §1 now says: a packaged RC, and the pinned LLVM first on
`PATH`. One run, `GATE PASSED`, every row below from it.

| check | result |
|---|---|
| source lists agree | ok |
| two-generation bootstrap | ok |
| compiler IR fixpoint | ok, byte-identical |
| RC reproduces itself | ok |
| seed agreement | ok, the committed seed builds the compiler |
| full suite | **435/435** with the pinned LLVM on `PATH` |
| AIF oracle differential | ok, all 19 sources agree |
| corpus builds and runs | ok, 7 programs |
| `--verify` sweep | ok, 0 leaked / 0 violations on every program |
| curated runtime off, object cache off | ok |
| JIT | ok |
| cross-target | skipped, no SDK on this host |
| packaged toolchain (`verify_separation.py`) | ok |

**Three failures were the environment, not the tree.** Two were one cause: the
system `llvm-nm` and `clang` are LLVM 18. They cannot read LLVM 23 bitcode
(`verify_separation`, and through it `module_artifacts`), and they disagree on
wasm32's data layout (`target_cross`). With `third_party/llvm/bin` first on
`PATH`, all three pass. The third was a test bug: `test_181` compared
`cbrt(27.0)` exactly, and glibc's `cbrt` answers 3.0000000000000004. That
would have failed CI's ubuntu-latest too. It now compares within an ulp.

The first gate run passed a bare generation as `--rc`. That has no
`lib/runtime/*.bc`, so 229 suite fixtures and every corpus build failed.
RELEASE.md §1 now says so.

## 2 · Benchmark matrix

`python3 benchmarks/run.py --compiler <dist>/bin/prismio --llvm-bin third_party/llvm/bin --runs 7`.
Geometric mean **0.92x of C++ and 0.92x of Rust** (0.90x and 0.90x in
`RESULTS-benchmarks-2026-09-25.md`, earlier the same day). Peak RSS is level
with both. The slowest against C++ are `edit_distance` 2.00x, `base64_codec`
1.56x, `quicksort` 1.30x and `lz4_compress` 1.29x.

**`channel_pipeline` read 1.40x of C++, and it is noise.** Its IR is identical
to the earlier run's, apart from renumbering and std code it never calls
(`__aif_release_StringBuilder`, the `fs_lines_*` declarations). Two more runs
of 15 read 1.22x and 1.06x. Across these runs C++ ranged 122 to 156 ms and
Rust 81 to 132 ms: on four cores the benchmark measures thread scheduling.
Price a channel change with an interleaved A/B, not against this table.

```text
Prismio benchmarks  63 workloads · 7 runs each · Prismio, C++ and Rust

    Compiled Prismio suite  5.57 s · 408.9 KB
      Cached C++ suite  built earlier in 5.91 s · 171.1 KB
      Cached Rust suite  built earlier in 1.53 s · 4.03 MB

    workload                   Prismio         C++        Rust    vs C++   vs Rust    RSS (P)  RSS vs C
  algorithms
    fibonacci                  22.1 ms     21.6 ms     22.3 ms     1.02×     0.99×   18.89 MB     1.00×
    prime_sieve                 1.4 ms      1.4 ms      1.9 ms     1.01×     0.73×   18.89 MB     1.00×
    gcd_lcm                    62.5 ms     62.1 ms     62.9 ms     1.01×     0.99×   18.89 MB     1.00×
    binary_search             237.4 ms    229.3 ms    258.1 ms     1.04×     0.92×   18.89 MB     1.00×
    quicksort                  11.6 ms      8.9 ms      9.4 ms     1.30×     1.23×   18.89 MB     1.00×
    mergesort                   8.0 ms      8.2 ms     11.0 ms     0.97×     0.72×   18.89 MB     1.00×
    string_search             272.4 µs    220.3 µs    378.9 µs     1.24×     0.72×   18.89 MB     1.00×
    graph_bfs                   1.6 ms      1.6 ms      1.8 ms     1.02×     0.92×   18.89 MB     1.00×
    knapsack                  111.2 µs    464.4 µs      1.1 ms     0.24×     0.10×   18.89 MB     1.00×
    tree_traversal            722.8 µs    826.5 µs    712.1 µs     0.87×     1.01×   18.89 MB     1.00×
    dijkstra_shortest_path      1.3 ms      1.2 ms      1.1 ms     1.09×     1.22×   18.89 MB     1.00×
    lz4_compress              969.4 µs    752.6 µs    797.4 µs     1.29×     1.22×   18.89 MB     1.00×
    s_expression_parse          3.7 ms      3.6 ms      5.3 ms     1.03×     0.71×   18.89 MB     1.00×
    regex_matching          unsupported
    word_frequency            984.3 µs      1.6 ms      1.2 ms     0.62×     0.82×   18.89 MB     1.00×
    sort_strings               12.3 ms     25.9 ms     15.4 ms     0.47×     0.80×   18.89 MB     1.00×
    edit_distance               2.3 ms      1.1 ms      2.3 ms     2.00×     0.98×   18.89 MB     1.00×
  data_structures
    hashmap_insert_lookup      13.4 ms     22.4 ms     26.9 ms     0.60×     0.50×   18.89 MB     1.00×
    vector_growth              32.6 ms     32.5 ms     23.9 ms     1.00×     1.36×   33.21 MB     1.71×
    vector_iteration          142.3 ms    143.3 ms    144.6 ms     0.99×     0.98×   18.89 MB     1.00×
    key_value_update           10.8 ms      8.4 ms     27.9 ms     1.28×     0.38×   18.89 MB     1.00×
    flat_bitset                 2.5 ms      2.8 ms      2.8 ms     0.90×     0.91×   18.89 MB     1.00×
    trie_search                 9.9 ms      9.9 ms      9.5 ms     1.00×     1.04×   18.89 MB     1.00×
    linked_list             unsupported
    binary_search_tree      unsupported
    priority_queue          unsupported
    mixed_map_removal          10.9 ms     13.6 ms     16.3 ms     0.81×     0.67×   18.89 MB     1.00×
    lock_free_queue         unsupported
  compute
    matrix_multiply             8.2 ms      8.2 ms      8.4 ms     1.00×     0.98×   18.89 MB     1.00×
    mandelbrot                 10.0 ms     16.7 ms     10.3 ms     0.60×     0.97×   18.89 MB     1.00×
    fft                         8.6 ms      8.4 ms      8.8 ms     1.03×     0.98×   18.89 MB     1.00×
    numerical_integration       5.8 ms      5.9 ms      5.9 ms     0.99×     1.00×   18.89 MB     1.00×
    vector_dot                 38.3 ms     39.3 ms     37.6 ms     0.97×     1.02×   32.49 MB     0.96×
    convolution                 9.9 ms     10.7 ms      9.9 ms     0.93×     1.00×   18.89 MB     1.00×
    monte_carlo                71.0 ms     70.4 ms     70.0 ms     1.01×     1.01×   18.89 MB     1.00×
    polynomial_evaluation      43.7 ms     43.7 ms     51.0 ms     1.00×     0.86×   18.89 MB     1.00×
    ecs_component_update       12.3 ms     13.1 ms     12.1 ms     0.94×     1.02×   18.89 MB     1.00×
    parallel_reduction         14.9 ms     13.7 ms     14.1 ms     1.09×     1.06×   18.89 MB     1.00×
    sha256                    334.4 µs    343.8 µs    313.5 µs     0.97×     1.07×   18.89 MB     1.00×
    blake3_chunk              277.6 µs    273.0 µs    280.8 µs     1.02×     0.99×   18.89 MB     1.00×
    raytracer_sphere            1.9 ms      1.9 ms      1.7 ms     1.00×     1.16×   18.89 MB     1.00×
    channel_pipeline          170.7 ms    122.2 ms     81.3 ms     1.40×     2.10×   18.89 MB     1.00×
    async_event_loop        unsupported
    mutex_contention        unsupported
    work_stealing_pool      unsupported
    simd_vector_ops         unsupported
    bytecode_interpreter      120.3 ms    120.0 ms    121.0 ms     1.00×     0.99×   18.89 MB     1.00×
  memory
    transient_allocation        2.6 ms      3.2 ms      3.8 ms     0.83×     0.70×   18.89 MB     1.00×
    struct_creation            29.1 ms     29.7 ms     28.3 ms     0.98×     1.03×   40.08 MB     0.97×
    allocation_mutation        24.5 ms     24.0 ms     24.2 ms     1.02×     1.01×   18.89 MB     1.00×
    nested_collection           5.4 ms      5.7 ms      5.5 ms     0.94×     0.99×   18.89 MB     1.00×
    large_buffer_copy          22.0 ms     18.2 ms     21.1 ms     1.21×     1.04×   18.89 MB     1.00×
    recursive_tree_rebuild      1.2 ms      2.4 ms      1.3 ms     0.50×     0.91×   18.89 MB     1.00×
    custom_allocator_churn  unsupported
    string_join                11.2 ms     21.2 ms     20.4 ms     0.53×     0.55×   18.89 MB     0.79×
  io
    file_read                   1.4 ms      2.4 ms      1.3 ms     0.57×     1.04×   18.89 MB     1.00×
    file_write                  1.4 ms      1.4 ms      1.4 ms     0.99×     1.02×   18.89 MB     1.00×
    line_processing           886.2 µs      1.8 ms    916.7 µs     0.50×     0.97×   18.89 MB     1.00×
    tokenization              442.8 µs    588.7 µs      1.1 ms     0.75×     0.39×   18.89 MB     1.00×
    base64_codec                2.3 ms      1.5 ms      1.6 ms     1.56×     1.47×   18.89 MB     1.00×
    csv_parse                   2.2 ms      2.1 ms      3.1 ms     1.07×     0.72×   18.89 MB     1.00×
    json_parse              unsupported
    json_serialize          unsupported
    tcp_echo_server         unsupported
    mmap_file_io            unsupported
    generic_serialization   unsupported
  adversarial
    pointer_chase             117.3 ms    121.8 ms    119.3 ms     0.96×     0.98×   18.89 MB     1.00×
    random_gather              49.7 ms     46.5 ms     54.2 ms     1.07×     0.92×   18.89 MB     1.00×
    branch_mispredict          91.9 ms     89.6 ms     99.4 ms     1.03×     0.92×   19.12 MB     0.93×
    strided_memory            125.1 ms    124.8 ms    124.9 ms     1.00×     1.00×   18.89 MB     0.98×
    allocation_escape          17.4 ms     16.5 ms     16.5 ms     1.05×     1.05×   18.89 MB     1.00×
    function_call_overhead     27.1 ms     26.5 ms     28.3 ms     1.02×     0.96×   18.89 MB     1.00×
    indirect_calls             88.0 ms     87.6 ms     86.5 ms     1.00×     1.02×   18.89 MB     1.00×
    dependency_chain            3.6 ms      3.6 ms      3.6 ms     1.02×     1.01×   18.89 MB     1.00×
    aos_vs_soa                 29.6 ms     30.8 ms     53.4 ms     0.96×     0.55×   18.89 MB     1.00×
    switch_dispatch           133.8 ms    127.6 ms    134.1 ms     1.05×     1.00×   18.89 MB     1.00×
    memcpy_mix                  4.9 ms      4.8 ms      2.3 ms     1.01×     2.07×   18.89 MB     1.00×
    dead_code_elimination       1.8 µs      6.1 µs      454 ns     0.30×     4.01×   18.89 MB     1.00×

Summary  63 workloads, 7 runs each, 49s
  vs C++   geomean 0.92×   19 faster · 30 parity · 14 slower
  vs Rust  geomean 0.92×   23 faster · 27 parity · 13 slower
```
