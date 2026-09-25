# The benchmark matrix, 2026-09-25

**Status: MEASURED.** The baseline the planners in `docs/` quote. It replaces
the task board of 2026-09-05, which was measured on Apple Silicon, as the
current position.

- **Compiler:** the tree at `1e338c0` (std.map removal), packaged, LLVM 23.1.1.
- **Machine:** x86_64 Linux, Intel Xeon @ 2.10 GHz, 4 cores.
- **References:** clang++ 18.1.3 at `-O2`, rustc 1.94.1 at `-C opt-level=3`.
- **Command:** `python3 benchmarks/run.py --compiler <dist>/bin/prismio --llvm-bin third_party/llvm/bin --runs 7`
- Every implemented workload's three checksums agreed (the runner refuses a
  mismatch).

**Summary.** Geometric mean 0.90x of C++ (23 faster, 32 at parity, 8 slower)
and 0.90x of Rust (27 faster, 24 at parity, 12 slower). Peak RSS geomean 1.00x
of C++ and 1.01x of Rust.

**What moved since the 2026-09-05 board.** That board's largest gaps are closed
on this machine: `fft` 0.95x of C++ (was 1.77x), `mergesort` 0.93x (1.59x),
`prime_sieve` 0.96x (1.43x), `mandelbrot` 0.60x (1.27x), `binary_search` 0.95x
(1.26x), `graph_bfs` 1.00x (1.26x), `convolution` 0.94x (1.24x). They are two
machines as well as two compilers, so read the change as "no longer a gap", not
as a measured speedup.

**The slowest against C++ now:** `edit_distance` 2.18x, `base64_codec` 1.62x,
`quicksort` 1.38x, `lz4_compress` 1.28x, `string_search` 1.27x,
`key_value_update` 1.25x and `large_buffer_copy` 1.14x. Against Rust:
`memcpy_mix` 2.01x, `base64_codec` 1.59x, `vector_growth` 1.41x,
`quicksort` 1.28x, `lz4_compress` 1.23x, `dijkstra_shortest_path` 1.18x and
`raytracer_sphere` 1.15x.
(`dead_code_elimination` is a 2 µs workload and not a ratio to read.)

**`channel_pipeline` is not a gap on this machine:** 135.2 ms, against 151.6 ms
for C++ and 122.2 ms for Rust. At this scale, the handoff between threads
dominates, not the per-message box that `docs/CHANNELS_PLAN.md` §2 describes.

Seven runs is enough to see where each workload stands, and it is not an A/B.
Price a change against this with a balanced, interleaved run.

## The table

```text
Prismio benchmarks  63 workloads · 7 runs each · Prismio, C++ and Rust

    Compiled Prismio suite  5.50 s · 400.0 KB
    Compiled C++ suite  5.91 s · 171.1 KB
    Compiled Rust suite  1.53 s · 4.03 MB

    workload                   Prismio         C++        Rust    vs C++   vs Rust    RSS (P)  RSS vs C
  algorithms
    fibonacci                  21.5 ms     21.6 ms     21.6 ms     0.99×     1.00×   18.97 MB     1.00×
    prime_sieve                 1.3 ms      1.3 ms      1.9 ms     0.96×     0.66×   18.97 MB     1.00×
    gcd_lcm                    63.5 ms     62.9 ms     62.2 ms     1.01×     1.02×   18.97 MB     1.00×
    binary_search             224.2 ms    236.6 ms    261.4 ms     0.95×     0.86×   18.97 MB     1.00×
    quicksort                  12.7 ms      9.2 ms      9.9 ms     1.38×     1.28×   18.97 MB     1.00×
    mergesort                   8.3 ms      8.9 ms     11.4 ms     0.93×     0.73×   18.97 MB     1.00×
    string_search             282.3 µs    221.9 µs    377.7 µs     1.27×     0.75×   18.97 MB     1.00×
    graph_bfs                   1.5 ms      1.5 ms      1.7 ms     1.00×     0.87×   18.97 MB     1.00×
    knapsack                   98.2 µs    420.5 µs      1.1 ms     0.23×     0.09×   18.97 MB     1.00×
    tree_traversal            696.7 µs    757.7 µs    708.2 µs     0.92×     0.98×   18.97 MB     1.00×
    dijkstra_shortest_path      1.2 ms      1.2 ms      1.1 ms     1.02×     1.18×   19.10 MB     1.00×
    lz4_compress              982.1 µs    767.8 µs    796.2 µs     1.28×     1.23×   19.10 MB     1.00×
    s_expression_parse          3.6 ms      3.6 ms      5.2 ms     1.01×     0.70×   19.10 MB     1.00×
    regex_matching          unsupported
    word_frequency            996.4 µs      1.7 ms      1.2 ms     0.59×     0.82×   19.10 MB     1.00×
    sort_strings               13.2 ms     23.9 ms     14.9 ms     0.55×     0.89×   19.10 MB     1.00×
    edit_distance               2.5 ms      1.1 ms      2.5 ms     2.18×     1.00×   19.10 MB     1.00×
  data_structures
    hashmap_insert_lookup      14.4 ms     22.3 ms     31.7 ms     0.65×     0.45×   19.10 MB     1.00×
    vector_growth              35.4 ms     35.0 ms     25.1 ms     1.01×     1.41×   33.23 MB     1.71×
    vector_iteration          144.5 ms    146.6 ms    144.6 ms     0.99×     1.00×   19.10 MB     1.00×
    key_value_update           10.9 ms      8.7 ms     27.7 ms     1.25×     0.39×   19.10 MB     1.00×
    flat_bitset                 2.6 ms      2.8 ms      2.8 ms     0.91×     0.92×   19.10 MB     1.00×
    trie_search                10.0 ms     10.0 ms      9.6 ms     1.00×     1.05×   19.10 MB     1.00×
    linked_list             unsupported
    binary_search_tree      unsupported
    priority_queue          unsupported
    mixed_map_removal          11.0 ms     13.7 ms     17.3 ms     0.80×     0.63×   19.10 MB     1.00×
    lock_free_queue         unsupported
  compute
    matrix_multiply             8.2 ms      8.2 ms      8.4 ms     1.00×     0.97×   19.10 MB     1.00×
    mandelbrot                  9.7 ms     16.0 ms      9.8 ms     0.60×     0.99×   19.10 MB     1.00×
    fft                         8.4 ms      8.9 ms      8.7 ms     0.95×     0.97×   19.10 MB     1.00×
    numerical_integration       6.0 ms      5.9 ms      6.1 ms     1.01×     0.99×   19.10 MB     1.00×
    vector_dot                 37.7 ms     40.8 ms     38.2 ms     0.92×     0.99×   32.46 MB     0.96×
    convolution                10.1 ms     10.8 ms     10.0 ms     0.94×     1.01×   19.10 MB     1.00×
    monte_carlo                70.3 ms     69.6 ms     70.5 ms     1.01×     1.00×   19.10 MB     1.00×
    polynomial_evaluation      43.6 ms     43.4 ms     50.1 ms     1.00×     0.87×   19.10 MB     1.00×
    ecs_component_update       13.0 ms     12.9 ms     11.9 ms     1.00×     1.09×   19.10 MB     1.00×
    parallel_reduction         13.5 ms     13.7 ms     13.8 ms     0.99×     0.98×   19.10 MB     1.00×
    sha256                    323.1 µs    323.4 µs    303.4 µs     1.00×     1.07×   19.10 MB     1.00×
    blake3_chunk              289.5 µs    306.8 µs    293.8 µs     0.94×     0.99×   19.10 MB     1.00×
    raytracer_sphere            2.0 ms      1.9 ms      1.7 ms     1.02×     1.15×   19.10 MB     1.00×
    channel_pipeline          135.2 ms    151.6 ms    122.2 ms     0.89×     1.11×   19.10 MB     1.00×
    async_event_loop        unsupported
    mutex_contention        unsupported
    work_stealing_pool      unsupported
    simd_vector_ops         unsupported
    bytecode_interpreter      121.0 ms    120.8 ms    118.3 ms     1.00×     1.02×   19.10 MB     1.00×
  memory
    transient_allocation        2.9 ms      2.7 ms      3.7 ms     1.04×     0.76×   19.10 MB     1.00×
    struct_creation            28.2 ms     30.6 ms     29.5 ms     0.92×     0.96×   40.08 MB     0.97×
    allocation_mutation        25.3 ms     25.4 ms     25.6 ms     1.00×     0.99×   19.10 MB     1.00×
    nested_collection           5.1 ms      5.1 ms      5.4 ms     1.00×     0.95×   19.10 MB     1.00×
    large_buffer_copy          22.2 ms     19.5 ms     21.7 ms     1.14×     1.02×   19.10 MB     1.00×
    recursive_tree_rebuild      1.2 ms      2.5 ms      1.3 ms     0.48×     0.93×   19.10 MB     1.00×
    custom_allocator_churn  unsupported
    string_join                11.0 ms     20.9 ms     20.2 ms     0.52×     0.54×   19.10 MB     0.80×
  io
    file_read                   1.3 ms      2.3 ms      1.3 ms     0.57×     1.04×   19.10 MB     1.00×
    file_write                  1.4 ms      1.5 ms      1.4 ms     0.96×     1.00×   19.10 MB     1.00×
    line_processing           804.7 µs      2.1 ms    987.5 µs     0.39×     0.81×   19.10 MB     1.00×
    tokenization              417.2 µs    595.7 µs      1.1 ms     0.70×     0.36×   19.10 MB     1.00×
    base64_codec                2.4 ms      1.5 ms      1.5 ms     1.62×     1.59×   19.10 MB     1.00×
    csv_parse                   2.1 ms      2.1 ms      3.1 ms     1.00×     0.68×   19.10 MB     1.00×
    json_parse              unsupported
    json_serialize          unsupported
    tcp_echo_server         unsupported
    mmap_file_io            unsupported
    generic_serialization   unsupported
  adversarial
    pointer_chase             119.0 ms    120.2 ms    126.5 ms     0.99×     0.94×   19.10 MB     1.00×
    random_gather              46.5 ms     46.8 ms     53.1 ms     1.00×     0.88×   19.10 MB     1.00×
    branch_mispredict          95.0 ms     92.6 ms     95.9 ms     1.03×     0.99×   19.10 MB     0.93×
    strided_memory            126.1 ms    126.4 ms    124.9 ms     1.00×     1.01×   19.10 MB     0.99×
    allocation_escape          16.6 ms     16.6 ms     16.6 ms     1.00×     1.00×   19.10 MB     1.00×
    function_call_overhead     26.6 ms     26.5 ms     28.1 ms     1.01×     0.95×   19.10 MB     1.00×
    indirect_calls             85.6 ms     87.2 ms     85.6 ms     0.98×     1.00×   19.10 MB     1.00×
    dependency_chain            3.6 ms      3.6 ms      3.6 ms     1.00×     1.01×   19.10 MB     1.00×
    aos_vs_soa                 30.8 ms     32.7 ms     49.9 ms     0.94×     0.62×   19.10 MB     1.00×
    switch_dispatch           125.3 ms    127.7 ms    134.2 ms     0.98×     0.93×   19.10 MB     1.00×
    memcpy_mix                  5.0 ms      4.9 ms      2.5 ms     1.02×     2.01×   19.10 MB     1.00×
    dead_code_elimination       1.9 µs      7.6 µs      549 ns     0.25×     3.45×   19.10 MB     1.00×

Summary  63 workloads, 7 runs each, 56s
  vs C++   geomean 0.90×   23 faster · 32 parity · 8 slower
  vs Rust  geomean 0.90×   27 faster · 24 parity · 12 slower
```
