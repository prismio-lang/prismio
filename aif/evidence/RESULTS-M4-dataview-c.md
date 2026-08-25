# M4.3c — mutable DataView round trip

Measured 2026-08-25 on the local Apple Silicon host. Raw 25-run results are in
[`results-m4-dataview-c.json`](results-m4-dataview-c.json) for the standard compiler gate and
[`results-m4-dataview-c-g1.json`](results-m4-dataview-c-g1.json) for the cross-language g1 gate.
The follow-up source-tuning matrix is
[`results-m4-dataview-c-g1-tuned.json`](results-m4-dataview-c-g1-tuned.json). The maintained
natural and hand-tuned workloads are
[`xlang/prismio/g1_dataview.psm`](xlang/prismio/g1_dataview.psm) and
[`xlang/prismio/g1_dataview_tuned.psm`](xlang/prismio/g1_dataview_tuned.psm).

## What changed

Field assignment through a `DataElement<T>` descriptor now resolves the selected physical column
at the store. Scalar and nested-flat fields can be mutated directly, and `aos(view)` reconstructs
the final rows from those columns. The focused test mutates both kinds, consumes the view back to
AoS, and checks the reconstructed values. Extern parameters and returns containing `DataView<T>`
remain rejected until an explicit C-compatible marshalling contract exists.

The first correct lowering was slower than AoS: repeated `data_view_column` calls and metadata
loads remained inside the row loop because LLVM could not prove that column stores did not alias
the view's metadata or other columns. The final lowering states only representation facts the
runtime guarantees:

- ready-view metadata loads are marked `!invariant.load`; the metadata is immutable until the
  consuming `aos` or release;
- direct top-level column accesses receive field-specific TBAA leaves; every physical column is a
  distinct live allocation;
- `data_view_column` is a `const` lookup, so its result can be reused;
- curated-runtime cache schema `curated-v2-invariant-dataview` prevents reuse of a runtime object
  produced by the older curation algorithm.

This hoists stable lookup/guard work and exposes disjoint column streams. After the natural helpers
inline into `main`, the integration loop is two-wide NEON and the fade loop processes eight values
per vectorised iteration. An in-loop `llvm.assume` experiment was slower and was not retained.

The design follows the semi-manual conversion boundary in the
[2025 data-views paper](https://arxiv.org/abs/2502.16517), while the alias facts use the semantics
documented by the [LLVM Language Reference](https://llvm.org/docs/LangRef.html). Clang's
[`__builtin_assume_separate_storage`](https://clang.llvm.org/docs/LanguageExtensions.html) was
evaluated as a model, but emitting an assume in the hot loop inhibited optimisation and is not in
the final implementation.

## Correctness and closure gates

- Bootstrap fixed point: `build/m4c-final-a.ll` and `build/m4c-final-b.ll` are byte-identical,
  SHA-256 `062fbdb295711e2fe1b08ff3f31baa0f1ecf8e978152027bd88255ccdb19f8c5`.
- Full suite: **164/164**.
- AIF differential: **17/17** sources agree in both as-is and owned modes.
- Focused verifier ledger: **12 allocated / 12 released / 0 leaked / 0 violations**.
- Runtime source lists, target/runtime/JIT checks, packaged runtime and curated closure are green.
- The test runner requires TBAA on DataView column reads and writes, making the optimisation fact a
  discriminating gate rather than a benchmark-only observation.

## Standard-corpus regression gate

Twenty-five runs, `build/m4-dataview-b-6` versus `build/m4-dataview-c-12`, with the calibrated 12%
per-program tolerance. Programs in this table do not use the new mutable view path.

| Program | New / old time | New / old peak RSS |
| --- | ---: | ---: |
| g1 | 1.089× | 1.000× |
| g2 | 1.001× | 1.008× |
| g3 | 0.997× | 0.992× |
| g4 | 0.999× | 0.985× |
| g5 | 0.987× | 1.000× |
| g6 | 0.999× | 1.007× |
| **Corpus median** | **0.999×** | — |

The gate passes. Five programs are within 1.3%; the isolated g1 shift remains below the calibrated
12% single-program band and its emitted feature-independent workload is covered again in the
matched representation gate below.

## Mutable g1 layout gate, side by side with Rust

All arms simulate 2,000 particles for 6,000 timed frames and produce identical checksums
(`alive 2000`, `beyond 1095`). Prismio DataView performs `soa` before the frame timer and consumes
the view through `aos` after it; the post-round-trip checksums prove the timed mutations survived.
Rust's representation setup is outside its frame timers as well. Values are medians over 25 clean
process runs.

| Variant | p50 / frame | p99 / frame | Total timed loop | Peak RSS | Window allocations |
| --- | ---: | ---: | ---: | ---: | ---: |
| Prismio AoS (before) | 3.792 µs | 4.792 µs | 23.065 ms | 1.766 MiB | 4,279 |
| **Prismio DataView (after)** | **0.833 µs** | **1.125 µs** | **5.092 ms** | 2.031 MiB | 2,294 |
| Rust idiomatic | 3.083 µs | 3.875 µs | 18.659 ms | 1.938 MiB | 270 |
| Rust hand-tuned SoA | 0.791 µs | 1.000 µs | 4.732 ms | 1.844 MiB | 272 |

DataView is **0.221× the AoS loop time (77.9% faster)** and **0.273× idiomatic Rust (3.66×
faster)**. It is **1.076× hand-tuned Rust** on total loop time, with p50 at **1.053×** and p99 at
**1.125×**. Peak RSS is 15.0% above Prismio AoS because the explicit conversion creates columns,
while allocation count in the harness window falls 46.4%.

The old g1 boxed-representation residual therefore moves from Prismio AoS at **1.145× Rust boxed**
to DataView at **0.253× Rust boxed**. M4's layout exit signal is green: the earlier projected 0.26×
factor materialised at 0.25× against the representation diagnostic and within 8% of deliberately
hand-tuned Rust SoA.

## Is Prismio DataView hand-tuned?

The normal `g1_dataview.psm` arm is **not source-hand-tuned**. It names the `soa` representation
boundary, then retains the natural two-helper/five-update row-loop structure of the AoS program.
Column selection, alias metadata, helper inlining and vectorisation are compiler work.

The separate hand-tuned arm mirrors the intent of Rust's tuned source: integration is fissioned
into one stream per position/velocity pair. The first transcription put all three loops in one
helper; that crossed LLVM's inline threshold, stayed scalar, and regressed to **10.2 ms**. The
retained form uses three small borrowing helpers. Each inlines and becomes an eight-elements-per-
iteration NEON loop without weakening the rule that an element descriptor from an owned local view
cannot be saved.

One 25-run matrix gives:

| Variant | p50 / frame | p99 / frame | Total timed loop | Peak RSS | Whole-process wall |
| --- | ---: | ---: | ---: | ---: | ---: |
| Prismio DataView, natural | 0.833 µs | 1.125 µs | 5.135 ms | 2.031 MiB | 19.426 ms |
| **Prismio DataView, hand-tuned** | **0.750 µs** | **0.958 µs** | **4.639 ms** | 2.031 MiB | 18.909 ms |
| Rust hand-tuned SoA | 0.791 µs | 0.959 µs | 4.752 ms | 1.844 MiB | 6.336 ms |

The hand-tuned Prismio source is **9.6% faster** than the natural DataView source. A second 25-run
ABBA pairing of only the tuned arms reads Prismio **4.631 ms** versus Rust **4.666 ms**, with both at
**0.750 µs p50** and approximately **0.959 µs p99**. The 0.8% loop-time difference is inside the
host's noise floor: the defensible result is **hot-loop parity with tuned Rust**, not a Prismio win.

The normal DataView arm loses roughly 0.4–0.5 ms over all 6,000 frames because its three integration
updates share one two-wide vector loop. Rust's split source and hand-tuned Prismio each expose three
smaller loops that LLVM vectorises and unrolls to eight values per iteration. Fade is already the
same eight-value shape in all tuned layouts. This is therefore an inlining/cost-model opportunity,
not a DataView representation deficit.

Whole-process time answers a different question. Hand-tuned Prismio takes 18.9 ms versus Rust's
6.3 ms even though their timed loops match, because both dump 6,002 lines *after* timing: Rust uses
a 1 MiB `BufWriter`, while Prismio formats each integer into a fresh `String` and calls the runtime
print boundary per line. The whole process records 8,300 allocations for Prismio versus 275 for
Rust. That I/O/reporting gap is real, but it is outside the particle-loop and DataView result.
