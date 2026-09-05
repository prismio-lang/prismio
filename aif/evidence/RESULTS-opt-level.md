# -O3 for program builds, and the measurement that had gone stale

**Status: GREEN, 2026-09-05.** Suite 288/288, corpus clean, all checksums
unchanged.

## The claim that was there

`runtime/build_driver.c` compiled every program with `clang -O2`, over this note:

> -O2 rather than -O3: measured across the corpus, -O3 lands between 0.98x and
> 1.03x of -O2, which is noise, and costs the same compile time.

That was true when it was written. It was measured on the corpus, with a compiler
that could not vectorise a container loop.

## What it measures now

Benchmark suite, 31 alternating samples, -O2 against -O3:

| benchmark | min | p50 |
|---|---:|---:|
| **tokenization** | **0.680** | **0.641** |
| knapsack | 0.961 | 0.973 |
| convolution | 0.964 | 0.966 |
| mergesort | 0.968 | 0.957 |
| large_buffer_copy | 0.982 | 0.980 |
| prime_sieve | **1.058** | **1.037** |

`tokenization` is 32-36% faster at -O3. The old reading of "noise" no longer
holds anywhere near it. `prime_sieve` is the one loss.

Cost: **+16 bytes** on the benchmark suite executable, and suite compile time
0.56s -> 0.59s.

## The fairness half

The cross-language suite builds its C++ arm `-O3` and its Rust arm
`opt-level=3`. An -O2 Prismio was being compared against two rivals at their
highest setting -- a second instance of the asymmetry
`benchmarks/README.md` now warns about, in the build flags rather than the source.

Prismio was **not** being built in debug: `g_debug_info` defaults to 0 and the
benchmark runner passes no `-g`, so it was a real optimised build. The
`.prismio/build/debug/prismio` in the runner is the *compiler's* own build mode,
which affects compile time and nothing about the generated program.

## Result

Default changed to `-O3 -mllvm -enable-nontrivial-unswitch`. With all three arms
at their highest level, `knapsack` is **1.03x of C++** and `tokenization` is
**0.56x** -- faster than the C++ arm.
