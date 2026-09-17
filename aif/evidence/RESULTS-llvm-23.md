# Results: LLVM 22.1.8 to 23.1.1 (2026-09-17)

The pinned LLVM line moved from 22.1.8 to 23.1.1, the current release
(2026-09-08). Three pins moved together: `PRISMIO_LLVM_EXPECTED_MAJOR`
(`runtime/prismio_llvm.h`), `DEFAULT_VERSION`/`REQUIRED_MAJOR`
(`tools/setup_llvm.py`) and `LLVM_MAJOR` (`.github/workflows/ci.yml`).
`PRISMIO_HOST_ABI` went to `3`.

Machine: an Apple M-series Mac, macOS 27.0, Homebrew `llvm` 23.1.1 and
`llvm@22` 22.1.8 side by side. Final compiler: `src/main.psm` IR
`eef56733d8152a3f659825a26a66d1a4`, the same from the seed and from two
generations.

## What changed in the code

**One crash.** A float add, subtract or multiply with two constant operands --
`0.0 - 2.5` in `tests/test_33_unary_operators.psm`, `0.0 - 100.0` in
`aif/corpus/g4_ecs_world.psm` -- folds in the builder to a `ConstantFP`, and
the backend then set `contract` on it with `LLVMSetFastMathFlags`, which casts
its argument to `Instruction` unchecked. LLVM 22 wrote the bit into the uniqued
constant; LLVM 23 faults (`EXC_BAD_ACCESS` at `LLVMSetFastMathFlags + 168`).
The compiler printed nothing and exited 139, so the only sign was two programs
moving into `tools/ir_snapshot.py`'s `SKIPPED` list. `set_fp_contract` now
checks `LLVMIsAInstruction`; a constant has no flags to carry, so no IR moves.

LLVM 23's C API notes -- `LLVMBr` split into `LLVMUncondBr`/`LLVMCondBr`, and
`CondBr`'s operand order -- touch nothing the backend calls, and the backend
compiled against the 23 headers with no diagnostics.

## IR

`tools/ir_snapshot.py` over the same tree, 22 (`2ce2ccd`'s compiler) against
23: the same 201 programs build and the same 129 are skipped. **97 are
byte-identical and 104 differ only in LLVM's printing**:

- float literals print as `f0x...` rather than `0x...`;
- the `memory(argmem: ...)` intrinsics gain `nosync` in their attribute list.

Normalising those two leaves no difference in any program. The refreshed seed
differs from the 22 seed in two lines, both `nosync`. A seed written by 22
parses under 23 (the first bootstrap of this work used it).

## Checks

- Fixpoint: seed, generation a and generation b all emit `eef56733...`.
- Full suite on a packaged, renamed compiler: 348/348, before and after the
  ABI bump.
- `tools/aif_differential.py`: the two known `src/main.psm` disagreements,
  unchanged from 22.
- `verify_separation`, `check_externs`: clean.
- Docs example gates: 202 (docs) and 50 (developers) snippets, both clean.

## Benchmarks

`benchmarks/prismio/suite.psm` built twice from the repository root: by the 22
toolchain (run against `llvm@22` with `DYLD_LIBRARY_PATH` and
`PRISMIO_LLVM_DIR`) and by the 23 toolchain. Each benchmark: one warm-up per
arm, then 7 rounds alternating which arm runs first; medians of the in-process
`elapsed_ns`; checksums equal in every run. The outliers were re-run with 31
rounds (last column). `dead_code_elimination` runs in under a microsecond and
is left out.

**Median 0.999x, geomean 0.978x** (23 over 22; lower is faster).

| Benchmark | 22 ms | 23 ms | 23/22, 7 rounds | 23/22, 31 rounds |
|---|---:|---:|---:|---:|
| `polynomial_evaluation` | 22.973 | 18.602 | 0.810 | 0.809 |
| `edit_distance` | 0.601 | 0.507 | 0.843 | 0.808 |
| `function_call_overhead` | 13.625 | 11.694 | 0.858 | 0.863 |
| `bytecode_interpreter` | 22.698 | 20.230 | 0.891 | 0.896 |
| `word_frequency` | 0.284 | 0.263 | 0.925 |  |
| `aos_vs_soa` | 8.674 | 8.143 | 0.939 |  |
| `recursive_tree_rebuild` | 0.335 | 0.319 | 0.953 |  |
| `knapsack` | 0.152 | 0.149 | 0.977 |  |
| `file_write` | 0.764 | 0.750 | 0.981 |  |
| `gcd_lcm` | 22.529 | 22.134 | 0.982 |  |
| `sort_strings` | 4.032 | 3.965 | 0.983 |  |
| `blake3_chunk` | 0.280 | 0.276 | 0.984 |  |
| `nested_collection` | 2.166 | 2.138 | 0.987 |  |
| `large_buffer_copy` | 6.730 | 6.661 | 0.990 |  |
| `string_join` | 2.434 | 2.415 | 0.992 |  |
| `quicksort` | 5.081 | 5.045 | 0.993 |  |
| `graph_bfs` | 0.601 | 0.597 | 0.993 |  |
| `ecs_component_update` | 3.227 | 3.205 | 0.993 |  |
| `mandelbrot` | 3.428 | 3.405 | 0.993 |  |
| `channel_pipeline` | 4.317 | 4.291 | 0.994 |  |
| `switch_dispatch` | 62.716 | 62.350 | 0.994 |  |
| `vector_dot` | 12.096 | 12.026 | 0.994 |  |
| `base64_codec` | 0.857 | 0.853 | 0.995 |  |
| `file_read` | 0.698 | 0.695 | 0.995 |  |
| `matrix_multiply` | 4.312 | 4.296 | 0.996 |  |
| `indirect_calls` | 35.668 | 35.541 | 0.996 |  |
| `hashmap_insert_lookup` | 4.212 | 4.198 | 0.997 |  |
| `csv_parse` | 1.010 | 1.007 | 0.997 |  |
| `fibonacci` | 11.503 | 11.482 | 0.998 |  |
| `fft` | 2.800 | 2.796 | 0.999 |  |
| `dependency_chain` | 18.116 | 18.101 | 0.999 |  |
| `allocation_escape` | 9.408 | 9.403 | 1.000 |  |
| `strided_memory` | 58.686 | 58.670 | 1.000 |  |
| `random_gather` | 23.313 | 23.316 | 1.000 |  |
| `sha256` | 0.187 | 0.187 | 1.001 |  |
| `monte_carlo` | 43.773 | 43.827 | 1.001 |  |
| `raytracer_sphere` | 0.409 | 0.410 | 1.001 |  |
| `s_expression_parse` | 1.392 | 1.395 | 1.002 |  |
| `vector_iteration` | 74.442 | 74.654 | 1.003 |  |
| `parallel_reduction` | 7.490 | 7.515 | 1.003 |  |
| `trie_search` | 3.995 | 4.011 | 1.004 |  |
| `struct_creation` | 5.050 | 5.073 | 1.005 |  |
| `mergesort` | 5.195 | 5.219 | 1.005 |  |
| `vector_growth` | 11.434 | 11.488 | 1.005 |  |
| `transient_allocation` | 0.567 | 0.570 | 1.005 |  |
| `binary_search` | 89.719 | 90.183 | 1.005 |  |
| `branch_mispredict` | 34.669 | 34.874 | 1.006 |  |
| `key_value_update` | 4.847 | 4.878 | 1.007 |  |
| `convolution` | 3.438 | 3.468 | 1.009 |  |
| `prime_sieve` | 0.569 | 0.574 | 1.009 |  |
| `numerical_integration` | 2.187 | 2.207 | 1.009 |  |
| `line_processing` | 0.296 | 0.299 | 1.012 |  |
| `dijkstra_shortest_path` | 0.577 | 0.585 | 1.013 |  |
| `lz4_compress` | 0.458 | 0.465 | 1.014 |  |
| `tree_traversal` | 0.281 | 0.286 | 1.015 |  |
| `pointer_chase` | 35.193 | 35.786 | 1.017 | 1.007 |
| `allocation_mutation` | 6.605 | 6.822 | 1.033 | 0.997 |
| `flat_bitset` | 1.181 | 1.226 | 1.038 | 0.999 |
| `tokenization` | 0.150 | 0.155 | 1.038 | 0.999 |
| `memcpy_mix` | 1.665 | 1.734 | 1.041 | 1.068 |
| `string_search` | 0.091 | 0.098 | 1.070 | 1.006 |

What survived the re-run:

- **Faster:** `polynomial_evaluation` 0.81x, `edit_distance` 0.81x,
  `function_call_overhead` 0.86x, `bytecode_interpreter` 0.90x.
- **Slower: `memcpy_mix` 1.07x**, twice. `tools/fn_mnemonic_diff.py` shows
  `benchMemcpyMix` growing from 926 to 975 instructions under 23. Not
  investigated further; it is LLVM's code choice on one 1.6 ms workload.
- The other four slow readings of the first pass (`string_search`,
  `tokenization`, `flat_bitset`, `allocation_mutation`) read 0.997-1.006x with
  31 rounds.

## What the upgrade showed about the toolchain

`brew upgrade llvm` moved `/opt/homebrew/opt/llvm`, which every Prismio binary
loads `libLLVM-C.dylib` through, and so stopped the installed `prismio`, the
project host and every `build/` generation at once. It also upgraded `z3`,
which left the old `Cellar/llvm/22.1.8` clang unable to load. A packaged
toolchain names that Cellar path in `third_party/llvm-paths.json`. KNOWN_ISSUES,
"Toolchain layout", records this and the proposed fix: ship the pinned LLVM
inside the toolchain.
