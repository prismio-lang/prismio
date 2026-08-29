# v0.1 release candidate — the complete local gate

**`build/v0.1-rc`.** Two-generation byte-identical fixpoint, suite 202/202,
differential 19/19, 30 corpus programs built *and run*, ASan and TSan clean,
`--verify` 0 leaked / 0 violations on every program checked.

Reproduce the whole of it with one command:

```bash
bash tools/release_gate.sh --old build/tbaa3 --rc build/v0.1-rc
```

## What the gate ran

```
source lists agree                         ok
two-generation bootstrap                   ok
compiler IR fixpoint                       ok    byte-identical
RC reproduces itself                       ok    the frozen binary emits generation 1's IR
seed agreement                             ok    committed seed builds the compiler
full suite                                 ok    202/202
AIF oracle differential                    ok    agree on all 19 sources
corpus builds and runs                     ok    30 programs
--verify sweep                             ok    0 leaked / 0 violations on every program
curated runtime off                        ok
object cache off                           ok
JIT                                        ok
cross-target                               ok    x86_64-apple-macos built
packaged toolchain                         ok    all separation checks passed
```

`RC reproduces itself` is the check worth naming: it asserts the *frozen binary*
emits the same compiler IR that a fresh generation off it does, so the file being
shipped is the fixpoint rather than something adjacent to it.

Two failures the gate script itself had, both fixed and both worth recording
because each read as a compiler defect:

- **`--target` without `--sysroot`.** There is no C library for the target, so the
  runtime cannot be compiled for it and `stdio.h` is not found. The diagnostic
  says exactly that; the gate was not passing the SDK the suite passes.
- **A textual `.ll` diff against the old compiler** reported 21 of 24 programs
  "moved". Alias metadata changes nearly every program's IR without changing one
  instruction. The gate now runs `tools/fn_mnemonic_diff.py`, which is the diff
  V0_1_FEATURES.md §2.2 actually asks to read.

## Per-function mnemonic diff, RC against `build/tbaa3`

Read before any timing below.

| | functions | changed | which |
|---|---:|---:|---|
| g1 | 190 | 4 | `fade`, `main`, + the two below |
| g2 | 187 | **2** | **only** the two below |
| g3 | 190 | 4 | `link_child` 23→22, `build_hierarchy` 191→190, + two |
| g4 | 191 | 5 | `system_movement` 48→44, `system_regen`, `main`, + two |
| g5 | 198 | 4 | `release` 35→33, `main` 669→667, + two |
| g6 | 198 | 3 | `world_step` 60→56, + two |
| g9 | 184 | **2** | **only** the two below |

**"The two below" are `aif_verify_alloc` and `aif_verify_release`**, which grew by
6 and 12 instructions when the ledger took a lock. They are linked into every
binary and **called only in a `--verify` build** — `rt_base_alloc` is plain
`malloc` otherwise — so they are unreachable in everything timed here. g2 and g9
are otherwise instruction-for-instruction what `tbaa3` produced.

## Timings

25 interleaved runs per arm, checksums asserted equal before any number is read.
`tools/milestone_bench.py`, raw in
[`xlang/results-v01-rc-ab.json`](xlang/results-v01-rc-ab.json).

| | g1 | g2 | g3 | g4 | g5 | g6 | g9 |
|---|---:|---:|---:|---:|---:|---:|---:|
| new / old | 1.015x | 0.988x | 1.000x | **0.945x** | 1.067x † | 1.003x | 1.001x |
| RSS | 1.000x | 1.008x | 1.000x | 1.000x | 1.000x | 0.993x | 1.000x |

Corpus median **1.001x**, range 0.945–1.067x. No RSS movement anywhere.

**† g5 is not measurable at this granularity, and this is now demonstrated rather
than asserted.** An A/A calibration — `build/tbaa3` against *itself*, 25 runs,
same binary both arms — reports:

```
old   33.1 ms   min 28.1   max 53.8
new   41.9 ms   min 28.7   max 54.5
new/old  1.266x  (REGRESSED)
```

**1.266x between one binary and itself.** Every g5 number this project has
recorded sits inside that. Earlier in this same session the harness put g5 at
1.142x against the RC and the five-arm rotation put it at 0.79x *for* the RC; the
mnemonic diff says its only changed function removes two dependent loads. Diff
the functions; do not read g5's clock.

## Five-arm standing

25 runs per arm, cyclic rotation of the arm order, `tools/five_arm_bench.py`.
Raw in [`xlang/results-v01-rc-five-arm.json`](xlang/results-v01-rc-five-arm.json).

| loop ms | g1 | g2 | g3 | g4 | g5 | g6 | g9 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Prismio (old) | 19.187 | 27.755 | 44.019 | 34.615 | 46.304 | 89.275 | 124.800 |
| **Prismio (RC)** | 19.849 | 27.337 | 44.189 | 33.256 | 36.705 | 89.547 | 124.020 |
| Prismio hand-tuned | 4.591 | 12.412 | 35.060 | 20.556 | 8.267 | 66.817 | 98.089 |
| Rust idiomatic | 18.189 | 18.091 | 45.145 | 21.712 | 29.027 | 57.035 | 140.612 |
| Rust hand-tuned | 4.607 | 10.094 | 30.416 | 17.692 | 4.310 | 40.789 | 97.184 |

**Prismio / Rust idiomatic: 1.09x, 1.51x, 0.98x, 1.53x, 1.26x, 1.57x, 0.88x.**
Hand-tuned: 0.25x, 0.69x, 0.78x, 0.95x, 0.28x, 1.17x, 0.70x.

Prismio is ahead of idiomatic Rust on the scene-graph program and on parallel
bands. g9's hand-tuned column exists for the first time — `Channel<T>` is what
made it writable — and the two tuned arms are within 1% of each other on this
run. The dedicated g9 measurement on a quieter machine read 82.0 against 71.3
(1.15x); the ratio is the stable part of both, the absolute times are not.

## Sanitizers

AddressSanitizer over g1, g3, g4, g5, g6, g9, `g9_tuned`, `test_96_channels` and
`test_97_generic_annotation`: **0 reports each.** ThreadSanitizer over the three
concurrent programs: **0 reports each.**

## What is *not* proved here

The three-platform matrix has not run on this commit. `build/tbaa3` is the last
compiler observed green on macOS, Ubuntu and Windows, and until CI runs on the RC
that is the honest statement of platform status — task 6.
