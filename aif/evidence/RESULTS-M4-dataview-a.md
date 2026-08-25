# M4.3a — explicit DataView conversion boundary

Measured 2026-08-25 on the standing Apple Silicon development host. The baseline is
`build/m4-slice-9`; the fixed compiler is `build/m4-dataview-a-6`.

## What landed

`soa(rows)` consumes an ordinary `List<T>` and emits a `DataView<T>` with one independently
allocated byte column for every physical field. `aos(view)` consumes the columns and reconstructs
the ordinary list. The conversion uses LLVM target-layout offsets and ABI sizes rather than source
order assumptions. Flat nested structs and layout reordering therefore round-trip; pointer-owning
structs and hot/cold splits are refused.

The view is move-only and has a dedicated release path. It can be borrowed through generic
functions, is released when abandoned in scope, and cannot cross an extern boundary or be stored in
a struct/List until those owners can name its custom release.

## Correctness and reproducibility

- Full suite: **163/163**.
- `--verify` round-trip: **12 allocated / 12 released / 0 leaked / 0 violations**.
- `--verify` scope-drop: **7 allocated / 7 released / 0 leaked / 0 violations**.
- Fixed point: byte-identical compiler builds when generations 5 and 6 build the same output path.
- Fresh committed-seed rebuild agrees byte-for-byte with generation 6 at the same output path.
- In-compiler AIF vs Python oracle: **17/17 sources agree**, in both as-is and owned modes.
- Toolchain source lists agree; packaged runtime, cross-target, JIT and runtime separation gates pass.

## Standard milestone benchmark

25-run interleaved ABBA measurement. The feature is unused by g1–g6, so this is the required
regression control, not a claimed speedup.

| Program | new / old | RSS new / old | New / Rust idiomatic |
|---|---:|---:|---:|
| g1 | 0.927× | 1.000× | 1.22× |
| g2 | 1.003× | 0.984× | 1.75× |
| g3 | 1.000× | 1.000× | 1.10× |
| g4 | 1.003× | 1.000× | 3.12× |
| g5 | 0.998× | 1.000× | 1.73× |
| g6 | 1.001× | 1.000× | 2.69× |

Corpus median: **1.000× new/old**, range **0.927–1.003×**. The milestone gate passed. Raw results:
[`results-m4-dataview-a.json`](results-m4-dataview-a.json).

## Boundary microbenchmark

[`g1_dataview_boundary.psm`](xlang/prismio/g1_dataview_boundary.psm) repeatedly converts 2,000
rows of a 12-float (96-byte) Particle AoS into twelve columns and back, with no field work between
the boundaries. Across 25 clean process runs, 400 samples per run:

| Metric | Result |
|---|---:|
| AoS→SoA→AoS median | **76.083 µs** |
| p99 | **91.250 µs** |
| Median per row | **38.0 ns** |
| Median total for 400 conversions | **31.033 ms** |
| Peak RSS | **1.891 MiB** |

The runtime copies 768,000 bytes of read/write traffic per round-trip, about **10.1 GB/s** at the
median. This number is a cost target: M4.3a changes representation only at the named boundary and
cannot accelerate work until M4.3b can read and mutate fields directly in those columns.
