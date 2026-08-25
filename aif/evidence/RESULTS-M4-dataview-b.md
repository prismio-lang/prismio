# M4.3b — DataView element reads

Measured 2026-08-25 on the local Apple Silicon host. Raw standard-corpus results are in
[`results-m4-dataview-b.json`](results-m4-dataview-b.json); the paired read fixtures are
[`g1_dataview_read_aos.psm`](xlang/prismio/g1_dataview_read_aos.psm) and
[`g1_dataview_read_soa.psm`](xlang/prismio/g1_dataview_read_soa.psm).

## What changed

`DataView<T>` indexing now yields an internal value descriptor containing the view handle and the
checked row index. A field read resolves the physical column each time and indexes it using the
field's compile-time LLVM type, so nested flat fields work and LLVM can vectorize contiguous scans.
No raw interior pointer survives as language state.

A descriptor can be saved when it borrows an existing `DataView` parameter. Saving one from an
owned local view is rejected, preventing `aos(view)` from consuming the handle while a saved element
still names it. Bounds checks occur when the descriptor is formed.

## Correctness and closure gates

- Bootstrap fixed point: `build/m4-dataview-b-5` and `build/m4-dataview-b-6` emit identical
  `src/main.psm` IR, SHA-256
  `22aaa1d47bfa5c6955c4b1086800f2da860a69e5fbfce6eeeb62d984280b8da1`.
- Full suite: **164/164**.
- AIF differential: **17/17** sources agree in both as-is and owned modes.
- Focused verifier ledger: **12 allocated / 12 released / 0 leaked / 0 violations**.
- Runtime source lists, target/runtime/JIT checks and curated closure are green. The curated module
  contains only exported dependencies; generated internal `.cold` helpers are retained with their
  parent when Clang emits them.

## Standard-corpus regression gate

Twenty-five runs, `build/m4-dataview-a-6` versus `build/m4-dataview-b-6`, with a calibrated 12%
tolerance. The gate passes.

| Program | New / old time | New / old peak RSS |
| --- | ---: | ---: |
| g1 | 0.989× | 1.000× |
| g2 | 1.010× | 1.008× |
| g3 | 0.997× | 1.000× |
| g4 | 1.007× | 0.992× |
| g5 | 1.020× | 1.000× |
| g6 | 1.002× | 1.007× |
| **Corpus median** | **1.004×** | — |

The executable is about 240 bytes smaller across the corpus. These programs do not use element
projection, so this gate establishes that the new machinery does not regress existing code.

## Read-only layout gate

The paired fixtures each hold 200,000 rows with twelve `Float` fields and perform 400 scans per
process. The AoS control touches one field in each 96-byte row; the DataView case touches the same
1.6 MiB logical column. Checksums match (`8.00796e+12`). Twenty-five paired ABBA process runs give:

| Metric | AoS | SoA DataView | SoA / AoS |
| --- | ---: | ---: | ---: |
| Median total loop time | 43.389 ms | 39.196 ms | **0.903×** |
| Per-scan p50 | 105.625 µs | 95.917 µs | **0.908×** |
| Per-scan p99 | 153.083 µs | 119.042 µs | **0.778×** |
| Peak RSS | 24.453 MiB | 38.203 MiB | **1.562×** |

The selected-column traversal is **9.7% faster**. Optimized assembly has one source-ready guard
outside the loop and an eight-double vectorized contiguous scan.

Peak RSS is a real conversion tradeoff: `soa` temporarily holds the 19.2 MiB AoS source and the new
columns at the same time before releasing the source. The steady-state selected column is compact,
but process peak captures the overlap.

## Next gate

M4.3c must lower field writes through the descriptor, prove they survive `aos`, preserve the
explicit extern-boundary rejection and clean verifier ledger, then measure the full mutable g1
residual. Read projection alone is not the milestone exit.
