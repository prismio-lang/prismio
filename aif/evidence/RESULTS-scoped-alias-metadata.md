# E5 · Scoped alias metadata on the list header

Measured 2026-09-05, continuing from `RESULTS-push-predication.md` (E1).

**The mechanism works and the benchmark it was proposed for does not move.** The
fill loop E5 names now emits NEON stores — `benchLargeBufferCopy` goes from 4 to
31 vector instructions and `len` leaves memory entirely — and the phase those
stores are in measures **2.235 ms before and 2.198 ms after**. The fill loop was
never instruction-bound. The win the change does buy is elsewhere:
**prime_sieve 0.906**.

## What was built

Two independent facts, both required. Either alone moves the two-list fill loop
by nothing; together they vectorise it.

### 1. A module-wide `!alias.scope` pair for header versus elements

`runtime/llvm-api-backend.c`. Every access this backend emits to an `RtList`
header field — `elem_size`, `len`, `cap`, `data`, in all nine list intrinsics —
carries `!alias.scope !{header}, !noalias !{elements}`. Every access to an
element body — the flat scalar load and store, the boxed slot load, and the
whole-buffer `llvm.memmove` — carries the mirror.

The statement is universal, so it is one pair for the module rather than one per
loop: `data` is its own `rt_alloc` or its own arena bump on every path in
`lang_runtime.c`, and an element type is stored inline only when it is *flat* —
no pointer anywhere inside it — while a header is two pointers and five
counters. `List<List<Int>>` keeps the boxed representation and never reaches
these tags.

Scope names are `MDString`s rather than the self-referential form. LangRef
permits either; a string is already unique within the module, and the
self-referential form needs `LLVMTemporaryMDNode`, which `prismio_llvm.h`'s
hand-written fallback declarations do not have.

### 2. `noalias` on the return of the list constructors

`ir_declare_function_fresh()`, applied to `list_new` and
`list_new_with_capacity` in `src/ir/module.psm`. This is the same statement
clang puts on `malloc`.

**This half is not in the proposal, and without it the proposal buys nothing on
its own target.** The scope pair says a header field is not an element body. It
says nothing about one header and *another* header: in
`benchLargeBufferCopy`'s fill loop both receivers are header accesses, so
`target`'s length store still clobbers `source`'s length load and both lengths
stay in memory. Measured on the isolated fixture:

| Fixture | vector `stp q` | header reloads in loop |
|---|---:|---:|
| baseline | 0 | 2 |
| `noalias` on the constructor only | 0 | 2 |
| scope pair only | 0 | 2 |
| **both** | **4** | **0** |

The alternative was per-receiver scopes discharged by a preheader
`hdr_i != hdr_j` conjunct — two bindings can name one list, so cross-receiver
scopes need a runtime distinctness proof. That was built and measured
equivalent (also 4 `stp q`, 0 reloads) and then dropped: allocation identity is
a fact BasicAA already knows how to use, it needs no new conjunct in the guard,
no receiver identity threaded through the backend API, and it generalises to
every pair of constructor results rather than to the receivers of one loop.

`list_push_slot` and `list_get_inline` return interior pointers into an element
block the caller already holds and must never carry this attribute. The comment
on `ir_declare_function_fresh` says so.

## What it costs and what it buys

Interleaved, 31 samples after 6 warmups per benchmark, rotating order, one
process per sample. The `noise` column is a second arm running the **same**
before-binary; it is what a 1.000 reading looks like on this suite.

Only benchmarks whose generated body actually changed are listed —
`tools/fn_mnemonic_diff.py` was run on the two suite binaries first, and the
other 15 are byte-identical code. The full 34-benchmark sweep is in
`e5-scoped-alias-2026-09-05/measurements.json`; its double-digit readings on
`recursive_tree_rebuild` (1.166) and `tree_traversal` (0.961) are both on
**mnemonic-identical functions** and are noise, which is the third time this
suite has produced one.

| Benchmark | before ms | after ms | ratio | noise |
|---|---:|---:|---:|---:|
| **prime_sieve** | 0.799 | **0.724** | **0.906** | 0.997 |
| quicksort | 4.716 | 4.603 | 0.976 | 0.993 |
| fft | 4.747 | 4.660 | 0.982 | 0.998 |
| tokenization | 0.151 | 0.149 | 0.988 | 1.000 |
| line_processing | 0.332 | 0.329 | 0.992 | 0.993 |
| transient_allocation | 2.114 | 2.110 | 0.998 | 0.996 |
| vector_iteration | 75.410 | 75.366 | 0.999 | 1.000 |
| binary_search | 90.816 | 90.774 | 1.000 | 0.996 |
| mergesort | 5.652 | 5.653 | 1.000 | 0.999 |
| vector_dot | 14.330 | 14.332 | 1.000 | 0.999 |
| graph_bfs | 0.723 | 0.723 | 1.001 | 1.013 |
| large_buffer_copy | 7.931 | 7.938 | 1.001 | 0.999 |
| knapsack | 0.137 | 0.137 | 1.002 | 1.002 |
| convolution | 4.240 | 4.249 | 1.002 | 1.006 |
| nested_collection | 2.775 | 2.783 | 1.003 | 1.008 |
| vector_growth | 10.787 | 10.831 | 1.004 | 1.003 |
| **matrix_multiply** | 4.210 | **4.282** | **1.017** | 0.999 |

`file_read` and `file_write` were measured and are not listed: their noise arm
reads 1.000 and 0.765 respectively, so nothing under a few percent is
distinguishable there.

prime_sieve moves from 1.576x of C++ to 1.428x. matrix_multiply is the one
regression: its body grows 402 -> 476 instructions because LLVM now versions and
vectorises its push-based fill loop, and that loop is bandwidth-bound, so the
versioning is paid and the vector body wins nothing back. That is 1.7% against
prime_sieve's 9.4%.

## Why the target did not move — E4 was measuring page faults

The acceptance test was "`benchLargeBufferCopy`'s fill loop emits NEON stores;
the fill phase moves from 2.58 ms toward C++'s 0.61 ms." The first half holds:
`_benchLargeBufferCopy__Int` goes from 4 to 31 NEON instructions, and the
`ldrsw`/`str` pair on `[hdr, #8]` that carried the length is gone from the loop.
The second half does not, and the reason is that the 2.58 ms was never
instructions.

Phase-timed at the benchmark's real scale (`scale = 4`, n = 2,000,000, so 16 MB
of element block), **one shot per process, exactly as the harness runs it**, 18
samples interleaved:

| Phase | before | after | ratio |
|---|---:|---:|---:|
| fill | 2.235 ms | 2.198 ms | 0.984 |
| copy | 1.115 ms | 1.129 ms | 1.012 |
| checksum | 4.545 ms | 4.542 ms | 0.999 |

The fill writes 16 MB in 2.2 ms — 7.3 GB/s including first-touch page faults on
freshly mapped memory. Vectorising the stores cannot help: the kernel maps and
zero-fills the same 16 MB either way.

Two corrections to §0.4 follow, and they are worth more than this pass's timings:

- **The fill is 27% of the benchmark, not the 4.2x.** The checksum loop is 58%,
  and it is not at C++ parity either. E4's instruction to phase-time before
  choosing a lever was right; the phase numbers it recorded were taken warm
  and one of them was taken on a different scale.
- **A one-shot process is the measurement.** `benchLargeBufferCopy` run in a
  loop inside one process settles to a 0.55 ms fill, because `rt_base_alloc`
  recycles the block and the pages are already faulted in. The harness runs one
  benchmark per process, so the recycled number describes nothing the suite
  reports. A C++ arm written the same way reads a *slower* fill than Prismio's
  (1.27–1.74 ms against 0.54–0.66 ms) purely because `std::vector`'s allocator
  returns the 8 MB block to the OS between iterations and Prismio's does not.

## Verification

- Compiler at a **three-generation byte-identical IR fixpoint**:
  `build/e5/e5gen1.ll`, `e5gen2.ll` and `e5gen3.ll` all MD5
  `1012a822640a4b2e3c61618c45411d6a`. Binary MD5 differs between generations and
  always has — the link is not reproducible; the emitted IR is the fixpoint
  criterion.
- Full suite **299/299** with the candidate promoted to
  `.prismio/build/debug/prismio` (`python3 tools/run_suite.py`).
- **All 34 benchmark checksums identical** across all five timing arms; the
  harness aborts on a mismatch.
- `--verify` on all 34 benchmarks in both arms: **0 violations**, and the same
  **2 leaked** blocks in every run, which is MEM-038 and nothing else.
  `e5-scoped-alias-2026-09-05/verification.json`.
- `tools/fn_mnemonic_diff.py` run on the compiler, on the two suite binaries and
  on three corpus programs **before any timing was believed**. On the compiler
  the diff is the nine list intrinsics, the two declaration entry points, two new
  functions, and four self-hosted bodies that changed because the compiler now
  compiles itself with this codegen.
- **Corpus: 7 programs build and produce byte-identical output.** `g6_game` and
  `g4_ecs_world` are **mnemonic-identical, zero functions changed** — the check
  the rejected inline-push form failed. `g2_frame_loop`'s `build_scene` shrinks
  76 -> 69 instructions.
- `tools/release_gate.py` reports 12 of 14, and **both failures are
  pre-existing**:
  - *full suite*: `--target` and `jit` fail when the runner is invoked as
    `PRISMIO=<path> tests/test_runner.py`. The **baseline** compiler fails the
    same two under the same invocation (and one more). Through
    `tools/run_suite.py`, which makes the candidate the project host, it is
    299/299.
  - *AIF oracle differential*: `tools/aif_differential.py` output is
    **byte-identical** between the baseline and the candidate apart from the
    compiler path in its first line. `oracle-before.txt` / `oracle-after.txt`.

## For the next agent

- **The scope pair now exists and costs nothing to extend.** Any backend access
  that is provably in one of the two regions can join it. `Map`'s probe did not
  change at all — `mapProbe` performs no stores, so there was no false
  dependence to remove — which says where the map's cost is not.
- **Do not price a memory benchmark from a warm loop.** Every phase number in
  this file was taken one shot per process for that reason, and the warm numbers
  disagree with the cold ones by 4x on the same code.
- The matrix_multiply regression is loop versioning on a bandwidth-bound fill.
  If a cost model for "vectorising this loop cannot pay" is ever wanted, that is
  the case to build it against.

## Reproduce

```bash
tools/bootstrap.sh --compiler <previous> --out build/e5/e5gen1
tools/bootstrap.sh --compiler build/e5/e5gen1 --out build/e5/e5gen2
cp build/e5/e5gen2 .prismio/build/debug/prismio
python3 tools/run_suite.py
python3 build/e5-measure/measure.py --phase build
python3 build/e5-measure/measure.py --phase verify
python3 build/e5-measure/measure.py --phase measure
```

`e5-scoped-alias-2026-09-05/` holds the harness, the raw samples, the
verification ledgers, the four mnemonic diffs, the phase fixtures in both
languages, and the oracle differential from both compilers.
