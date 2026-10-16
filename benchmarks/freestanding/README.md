# Freestanding benchmarks

Prismio against C and Rust on a machine with **no operating system under it**: bare-metal
AArch64, no C library, no allocator, no startup files. The hosted suite
([`../hosted`](../hosted)) asks how fast a program runs on an operating system. This one asks what
the compilers do when there is nothing to lean on, which is the question a kernel, a boot stage
or firmware author has.

The two suites share a runner (`../run.py`), a results file (`../results/results.json`) and one
report, in tabs.

## What is measured, and why it is not time

QEMU runs each image with `-icount shift=0`, which makes the guest's virtual clock advance one
nanosecond per instruction executed. The generic timer counts that clock at 62.5 MHz, so one
tick is exactly 16 instructions, and the harness reads `CNTVCT_EL0` around each workload. The
difference is the workload's **guest instruction count**, to the nearest 16.

That count is the same on every run on every machine. It was calibrated against a loop of known
length (10,000,000 instructions reads 625,000 ticks, every time), and each arm is booted several
times and checked for agreement. So there is nothing to take a median of, no spread to measure
and no noise model. A verdict is absolute: fewer instructions than the other arm is a win, more
is a loss, and only an equal count (the same number of ticks) is level. The hosted suite's
tolerance exists for noise, and there is none here; a band of ±2% used to call a 5% loss parity.

What the number is **not**:

- It is not a time. It models no cache, no pipeline and no branch predictor. A workload
  dominated by memory stalls (`pointer_chase`, `mem_copy`) costs more on real silicon than its
  count says, and a count cannot show what a vectorised loop would gain.
- It is not a power or latency figure.

What it shows, without noise, is how much code each compiler asked the machine to run for the
same program. Code size is reported beside it: the `.text` of the linked image.

## The arms are the same program

The rule of the hosted suite holds here, for the reasons in [`../README.md`](../README.md): the
three arms express the same algorithm statement by statement, and a checksum agreeing is not
enough to show it. The runner refuses to report a workload whose arms return different results.

One thing is shared that the hosted suite cannot share: **the harness** (`harness/harness.c`)
is compiled once, with one compiler and one set of flags, and linked into all three arms. It owns
the boot code, the stack, the timer, the serial output, the exit and the `memset`/`memcpy` the
compilers emit calls to. Each arm provides `u32 bench_<name>(u32 scale)` for every workload and
nothing else, so the only code that differs between arms is the benchmarks themselves.

Sharing `memcpy` is not the same as sharing its cost. The arms call it a different number of times,
because the compilers differ in which loops they turn into a call: C is built with `-ffreestanding`,
which implies `-fno-builtin`, so it never turns a copy loop into `memcpy`, and Prismio and LLVM-built
Rust sometimes do. The harness's functions therefore move a word at a time (after the bytes before the
first aligned address, and only when source and destination share an alignment, since an unaligned
access faults with the MMU off). With a byte loop here, `edit_distance` read 2.0x C because Prismio called
it 600 times for 2,404 bytes each; with the word loop it reads 1.05x. Read the disassembly of any row that
calls `memcpy` or `memset` before reading it as code generation.

Configuration held equal for every arm:

| | |
|---|---|
| Target | `aarch64-unknown-none-elf` (Rust: `aarch64-unknown-none-softfloat`), CPU `generic` |
| FP and SIMD | off (`-mgeneral-regs-only`, `-neon,-fp-armv8`): the entry code leaves the unit off, and the first FP instruction would trap with no vector table |
| Alignment | strict (`-mstrict-align`, `+strict-align`): with the MMU off every access is to device memory and an unaligned one faults. Without this clang merges adjacent loads into a wider one and the guest dies at the exception vector |
| Optimisation | C `-O3`, Rust `opt-level=3` with fat LTO and one codegen unit, Prismio's default pipeline. Prismio's pipeline unrolls its hot loops partially (at most 4 copies) on a freestanding target, which clang and rustc do not for `generic`: see below |
| Linking | the same script (`harness/link.ld`), `--gc-sections` |
| Build directory | Prismio builds from `benchmarks/build/freestanding`, not the repository root, to keep the build away from the source tree. An earlier version of this note said a working directory containing `runtime/` made the compiler internalise nothing (512 bytes, 200,000 instructions on `heapsort`); that did not reproduce on 2026-10-09, when the suite built byte-identical (87,120 bytes) from the root and from an empty directory, with the runner's environment |
| Allocation | none. Every workload keeps its arrays in the frame |

**Integer overflow is a difference, kept on purpose.** C's signed overflow is undefined and Prismio's
`Int` wraps (so does Rust's in a release build), so LLVM may rewrite C's `min(a + 1, b + 1)` as
`min(a, b) + 1` and widen its loop indices, and cannot for Prismio unless it can prove no overflow.
In the first results that was the whole of the gap to C on `edit_distance`, `knapsack` and `quicksort`:
building the C arm with `-fwrapv` (add it to `C_FLAGS`) gave Prismio 4 fewer, 16 level and no more
instructions across the 20 workloads. The compiler now proves it instead: an unchecked access bounds
its index, which marks quicksort's scans `nsw` (11.30M to 9.99M, C 10.10M); knapsack's loop over a
sized array is versioned on `w >= 0` (5.69M to 3.14M, C 5.12M); and edit distance's rows are local
arrays whose elements stay in `[0, 360600]`, so `min(a + 1, b + 1)` becomes `min(a, b) + 1` (5.90M to
5.54M, C 5.60M); it had lost that bound to its own `min`, which the analysis now judges by its body.
`PRISMIO_NOWRAP=0` and `PRISMIO_RANGE_PROOFS=0` switch the mechanisms' marks off, to separate them.
The suite keeps C's default because that is what C is.

**Branch merging is a compiler setting, not a difference in the programs.** LLVM 23's AArch64
backend merges a branch on two conditions into one, even when one is a single bit test; Rust's LLVM
22 does not, which made `ring_buffer` 1.18x Rust. Prismio raises `-aarch64-br-merging-cbz-tbnz-bias`
to 8 and matches Rust's count; the C arm keeps clang's default.

**Unrolling is a compiler setting.** LLVM's AArch64 cost model unrolls partially only for a CPU
whose scheduling model has a loop buffer, and `generic` has none, so clang and rustc leave every
loop rolled; what C does get is LoopVectorize *interleaving* a loop whose iterations are independent
(four copies of a table fill as `stp` pairs). Prismio's freestanding pipeline adds its own pass,
`HotLoopUnroll` (`runtime/llvm_bridge.cpp`), after LoopVectorize: it unrolls a loop by up to 4 only
when the loop is hot (its nest's estimated iterations at least an eighth of the function's hottest),
innermost first, within 150 instructions, and at run time an outermost loop whose count comes from
the input (`K * scale`). That is `edit_distance`, `matrix_multiply`, `crc32`, `sha256` and `mem_copy`
near 0.7x, `pointer_chase` 0.63x and `atomic_counter` 0.53x, and set-up loops stay as C has them.
`PRISMIO_UNROLL_POLICY=0` turns it off.

`-funroll-loops` does nothing to the C arm on `generic` (the image is byte-identical), so it is not the
comparison. The C arm with the setting Prismio used before the pass is
`PRISMIO_BENCH_C_FLAGS="-mllvm -unroll-allow-partial -mllvm -unroll-max-count=4"`, measured 2026-10-16:

| | instructions vs C `-O3` | `.text` |
|---|---|---|
| C `-O3` | 1.000 | 14.9 KB |
| C `-O3` + partial unroll x4 | 0.91 | 21.5 KB |
| Prismio, module-wide partial unroll x4 (before) | 0.876 | 29.5 KB |
| Prismio, `HotLoopUnroll` + `CoveredFillElimination` | 0.793 | 18.0 KB |
| Prismio, + parameter ranges, congruences, `SelfRecursionUnfold` (2026-10-17) | 0.685 | 18.1 KB |

`PRISMIO_BENCH_C_FLAGS` adds any flags to the C arm, and the report records the command.

**A known difference, kept on purpose:** Rust and Prismio index with bounds checks; C does not.
Prismio checks an index it cannot prove in range and proves the rest (`src/ir/nowrap.psm`: `U32`
facts, comparisons, loop invariants and what a local array can hold), so `binary_search`,
`pointer_chase` and `bytecode_interpreter` pay for no check in their hot loops and are level with C
or ahead. Rust's checks are visible in `binary_search`, `heapsort`, `pointer_chase` and `knapsack`.

## Layout

```
freestanding/
  benchmarks.json        the catalog: name, category, profile, description, scale
  harness/harness.c      boot, timer, serial, exit, mem*; shared by every arm
  harness/link.ld        the linker script
  c/                     the C arm: one translation unit including the category files
  rust/                  the Rust arm: one no_std crate, bench_<name> with the C ABI
  prismio/               the Prismio arm: one program, `export fn bench_<name>`
  suite.py               builds the arms, boots them, reports; imported by ../run.py
```

The 20 workloads fall in four categories: **algorithms** (fibonacci, prime_sieve, gcd_lcm,
binary_search, quicksort, heapsort, knapsack, edit_distance, matrix_multiply), **compute** (crc32,
sha256, popcount, mandelbrot_fixed, bytecode_interpreter), **memory** (pointer_chase, ring_buffer,
mem_copy) and **hardware** (atomic_counter, spinlock, volatile_registers). The last category is
what only freestanding code does: atomics and volatile access on raw addresses, which Prismio
writes with `__builtin_mem_*` and the others with `__atomic_*` and `read_volatile`. Everything is
integer arithmetic.

## Run

```bash
python3 benchmarks/run.py --suite freestanding --compiler .prismio/build/debug/prismio
```

`prismio bench` runs both suites; the freestanding one is skipped, with a note, when its tools are
missing. `--only fibonacci` runs one workload, `--scale 4` multiplies every workload's size, and
`--list` shows the catalog.

It needs `clang` with the AArch64 target, a linker that runs (`ld.lld`; on an AArch64 Linux host
GNU ld is used when lld will not start), `qemu-system-aarch64`, and `rustc` with the `rust-src`
component. **No `rustup target add` is needed**: `suite.py` compiles `core` and
`compiler_builtins` for the bare-metal target straight from `rust-src`, once per `rustc`, into
`benchmarks/build/freestanding/rust-sysroot`. It takes a few seconds and needs no network.

A full run takes about ten seconds.

## Adding a workload

1. Write the **C** arm first, in the category file, as `u32 bench_<name>(u32 scale)`. Use
   wrapping integer arithmetic and the `LCG` step from `common.h` for any pseudo-random input.
   Size it to about 5 to 12 million instructions at `scale` 1: smaller and the timer's 16-instruction
   resolution matters, larger and a run is slower for nothing.
2. Translate it **statement by statement** into `rust/` and `prismio/`. Do not tidy: a different
   control flow is a different program (see the knapsack note in `../README.md`).
3. Add it to `benchmarks.json`. The harness's workload list is generated from that file.
4. Run it. All three checksums must agree, or the runner stops.

Run it against a native build as well: `clang -fsanitize=address,undefined` over the C arm, with
the raw-address workloads excluded, catches undefined behaviour that would otherwise make the
three arms agree on a wrong answer.
