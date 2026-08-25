# The cross-language benchmark — current standing and historical session-3 report

## Current update — inline runtime default candidate, 2026-08-25

M1's curated runtime module is now on by default in `build/inline-default-2`, with
`PRISMIO_INLINE_RUNTIME=0` retained as an opt-out and measurement control. The default change first
passed the old-vs-new milestone gate over 25 interleaved runs:

| program | new / old loop | RSS new / old | standing vs idiomatic Rust, old → new |
|---|---:|---:|---:|
| g1 | 0.983× | 1.000× | 1.37× → 1.34× |
| g2 | **0.897×** | 1.000× | 1.96× → **1.76×** |
| g3 | 0.999× | 1.008× | 1.10× → 1.09× |
| g4 | **0.913×** | 1.000× | 3.40× → **3.10×** |
| g5 | **0.635×** | 1.000× | 2.57× → **1.63×** |
| g6 | 1.000× | 0.993× | 2.71× → 2.71× |
| **corpus median** | **0.948×** | — | — |

Checksums matched, no program regressed, RSS stayed within 0.8%, and executable sizes were
unchanged. Raw result: `aif/evidence/xlang/results-inline-runtime-default.json`.

The standing harness then ran twice:

```bash
python3 aif/evidence/xlang/bench.py --compiler build/inline-default-2 --runs 25 \
    --json aif/evidence/xlang/results-current-inline-runtime.json
python3 aif/evidence/xlang/bench.py --compiler build/inline-default-2 --runs 25 --skip-build \
    --json aif/evidence/xlang/results-current-inline-runtime-pass2.json
```

| program | Prismio loop ms | pass 2 | Rust loop ms | pass 2 | Prismio / Rust | RSS MB, Prismio / Rust | RSS ratio |
|---|---:|---:|---:|---:|---:|---:|---:|
| g1 particles | 22.6 | 24.4 | 18.6 | 18.7 | **1.22×** | 1.77 / 1.94 | **0.91×** |
| g2 frame loop | 32.0 | 32.1 | 18.2 | 18.2 | **1.76×** | 1.94 / 2.19 | **0.89×** |
| g3 scene graph | 49.8 | 49.7 | 45.4 | 45.4 | **1.10×** | 2.03 / 2.03 | **1.00×** |
| g4 ECS | 67.5 | 67.3 | 21.7 | 21.7 | **3.11×** | 2.11 / 2.23 | **0.94×** |
| g5 asset cache | 51.8 | 51.1 | 30.3 | 28.8 | **1.71×** | 1.59 / 1.77 | **0.90×** |
| g6 engine + game | 150.5 | 150.4 | 55.5 | 55.5 | **2.71×** | 2.31 / 2.58 | **0.90×** |

The current pass-1 band is therefore **1.10×–3.11× idiomatic Rust**; the quiet pass reads
**1.10×–3.10×**. g1 moved 7.8% between passes, consistent with its recorded layout sensitivity;
g2–g6 Prismio medians agree within 1.5%. Peak RSS remains a win or tie at **0.89×–1.00× Rust**.
Compile time is 67–85 ms against rustc's 107–137 ms, and executable size remains 77–78 KiB.

Local release gates are green: fixed point, fresh-seed agreement, AIF differential 17/17, and
suite **150/150**. The new suite check requires the successful post-curation merge marker and also
tests the `=0` opt-out, so the existing Windows/Linux/macOS CI matrix now exercises the real path
instead of allowing its fail-open fallback to pass invisibly. The remote three-platform result is
still pending because these working-tree changes have not been pushed.

## Previous default-off measurement — `build/seedcheck-clean`, 2026-08-25

The standing item in [`TODO.md`](../../TODO.md) has been re-measured with the current self-hosted
compiler. The two commands were:

```bash
python3 aif/evidence/xlang/bench.py --compiler build/seedcheck-clean --runs 25 \
    --json aif/evidence/xlang/results-current.json
python3 aif/evidence/xlang/bench.py --compiler build/seedcheck-clean --runs 25 --skip-build \
    --json aif/evidence/xlang/results-current-pass2.json
```

The harness verified matching checksums before timing every variant. This is the current default
configuration: `PRISMIO_INLINE_ELEMS` is on, `PRISMIO_INLINE_RUNTIME` remains off, and Swift is
omitted by the Rust-only development-loop policy. The host reported Prismio 0.1.0 with LLVM
22.1.8, rustc 1.97.1, and Apple clang 21.0.0.

| program | Prismio loop ms | pass 2 | Rust loop ms | pass 2 | Prismio / Rust | RSS MB, Prismio / Rust | RSS ratio | loop allocations, Prismio / Rust |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| g1 particles | 24.7 | 25.6 | 18.3 | 18.6 | **1.35×** | 1.77 / 1.94 | **0.91×** | 4,279 / 270 |
| g2 frame loop | 35.5 | 35.6 | 18.1 | 18.2 | **1.97×** | 1.92 / 2.19 | **0.88×** | 42,284 / 160,269 |
| g3 scene graph | 49.6 | 49.7 | 45.3 | 45.3 | **1.09×** | 2.03 / 2.03 | **1.00×** | 5,741 / 270 |
| g4 ECS | 74.6 | 73.9 | 21.9 | 21.7 | **3.41×** | 2.11 / 2.23 | **0.94×** | 3,329 / 310 |
| g5 asset cache | 77.3 | 76.9 | 29.9 | 30.9 | **2.59×** | 1.61 / 1.77 | **0.91×** | 4,348 / 279 |
| g6 engine + game | 150.8 | 150.6 | 55.6 | 55.4 | **2.71×** | 2.36 / 2.58 | **0.92×** | 86,078 / 289,160 |

The 24 binary medians in the control pass agree within 3.8%; the only movement that large is g1
Prismio, the program this repository already records as layout-sensitive. The current answer is
therefore **1.09×–3.41× idiomatic Rust**, with g4 now the widest gap. The two deliberately stale
figures moved as expected: g2 is **5.89× → 1.97×**, and g6 is **4.07× → 2.71×** relative to the
idiomatic variants in this harness. Peak RSS is again a win or tie on every program,
**0.88×–1.00× Rust**, so M5.2's regression investigation is closed: the leaks were the cause.

Compile time is **63-72 ms** for Prismio versus **106-135 ms** for rustc (0.52x-0.62x); Prismio
executables are **77–78 KiB** versus **458–474 KiB**. The old `rust_boxed` residual is no longer a
single representation-held-constant band: current Prismio combines automatic arenas and inline
flat list elements, while that diagnostic intentionally retains boxed elements. It is still useful
per program (g1 1.24×, g2 0.22×, g4 1.41× in pass 1), but **1.24×–1.27× must not be quoted as the
current compiler-wide residual**.

Everything below this line is the preserved `build/S10b` report from the earlier 2026-08-25 run.
Its tables and conclusions are historical evidence, not the current standing.

---

`aif/evidence/xlang/bench.py`, unchanged: the same six programs, the same three-way Rust split
(idiomatic / bumpalo arena / hand-tuned), the same Swift baseline, the same `rust_boxed`
diagnostic, the same axes. Reproduce with:

```bash
python3 aif/evidence/xlang/bench.py --compiler build/S10b --runs 25
```

**Compiler under test:** `build/S10b`, bootstrapped from `build/E2` to a fixpoint (`a.ll == b.ll`),
suite **136/136** before measuring. rustc 1.97.1, Swift 6.3.3, Homebrew clang 22.1.8, Apple M5.

**Two independent 25-run passes.** Pass 1 is the matrix below; pass 2 (`--skip-build`) is the
reproducibility control. **Loop medians agree within 3% on every one of the 30 binaries** and the
ratios within 0.05×, so the medians are solid. The percentiles are not: pass 1 ran immediately
after 31 compilations and its `p99` is contaminated (g1 Prismio p99/p50 reads 2.16 in pass 1 and
1.06 in pass 2, with Rust moving the same way). **Loop time is quoted from pass 1; the tail is
quoted from pass 2, which is the quiet pass.** That split is the one methodological choice in this
document and §6 argues it.

The min–max spreads below are single-run-outlier driven, not median instability — g5's Rust
idiomatic spans 29.1–52.5 ms around a 29.7 ms median because one run of twenty-five was slow.
Read the spread as "what one bad run looks like", and the pass-1/pass-2 agreement as the real
error bar.

---

## 0 · The one-paragraph answer

**The claim under test — "as fast as *tuned* Rust, without the tuning" — is false on this corpus,
and it is not close.** Untuned Prismio is **1.13×–5.89×** idiomatic Rust and **1.70×–16.4×**
hand-tuned Rust. Idiomatic and tuned Rust do **not** bracket us: both are faster than Prismio on
all six programs, so we sit outside the bracket on the slow side everywhere. The band has not
moved in seven sessions — 1.12×–5.57× at session 3, 1.15×–5.59× at the 2026-08-17 midpoint,
1.13×–5.89× now — while four memory-model features landed in that window. **That non-movement is
the headline.** Two things did move, in opposite directions: the `region` annotation went from
inert to **2.2× faster on g2** (§4), and peak RSS went from a win to a loss (§5.3). The one number
that is a statement about the compiler's design — the residual against `rust_boxed`, with the data
representation held constant — is **1.24×–1.27×**, unchanged from session 3's 1.20×–1.30×.
**§9 is the exception to the flatness and was found by asking why hand-tuned Prismio still loses:
every container access is an un-inlinable call into the C runtime, and closing that seam is worth
1.07×–1.87× across the corpus with no language change.**

---

## 1 · The full matrix

Loop time: the sum of the program's own per-frame `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)`
samples, so process startup and the report dump are excluded. Median of 25 runs, min–max in
parentheses, and the pass-2 median in its own column.

| g1 particles | loop ms (min–max) | pass 2 | vs idiomatic | RSS MB | exe KB | cc ms | allocs |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Prismio** | **26.2** (23.9–29.8) | 26.2 | **1.38×** | 2.2 | 60 | 104 | 4,213 |
| Rust idiomatic | 19.0 (17.8–19.1) | 18.9 | 1.00× | 2.0 | 458 | 122 | 204 |
| Rust arena | 18.7 (16.9–19.4) | 18.8 | 0.99× | 2.1 | 475 | 132 | 204 |
| Rust hand-tuned | 4.9 (4.6–5.8) | 5.0 | 0.26× | 1.9 | 474 | 146 | 206 |
| *Rust boxed [dx]* | *20.7* (19.8–22.2) | *20.5* | *1.09×* | *1.9* | *458* | *125* | *2,204* |
| Swift idiomatic | 18.9 (17.1–19.4) | 18.7 | 1.00× | 6.3 | 54 | 301 | 939 |

| g2 frame loop | loop ms (min–max) | pass 2 | vs idiomatic | RSS MB | exe KB | cc ms | allocs |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Prismio** | **115.8** (109.7–171.5) | 115.5 | **5.89×** | 3.3 | 60 | 101 | 10,202,214 |
| Rust idiomatic | 19.7 (19.1–21.2) | 19.2 | 1.00× | 2.2 | 458 | 122 | 160,203 |
| Rust arena | 17.1 (16.9–18.3) | 17.2 | 0.87× | 2.1 | 476 | 132 | 210 |
| Rust hand-tuned | 10.8 (10.2–23.4) | 10.5 | 0.55× | 2.0 | 458 | 121 | 196 |
| *Rust boxed [dx]* | *181.7* (175.4–197.7) | *176.0* | *9.23×* | *2.2* | *458* | *125* | *10,181,203* |
| Swift idiomatic | 35.2 (33.1–38.9) | 34.7 | 1.79× | 6.8 | 55 | 323 | 200,939 |

| g3 scene graph | loop ms (min–max) | pass 2 | vs idiomatic | RSS MB | exe KB | cc ms | allocs |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Prismio** | **55.7** (53.2–58.7) | 54.0 | **1.13×** | 2.7 | 60 | 106 | 5,674 |
| Rust idiomatic | 49.4 (46.8–51.4) | 48.9 | 1.00× | 2.0 | 458 | 130 | 204 |
| Rust hand-tuned | 32.8 (31.3–33.6) | 32.9 | 0.66× | 2.1 | 474 | 148 | 550 |
| Swift idiomatic | 55.7 (55.1–58.8) | 54.7 | 1.13× | 6.6 | 55 | 318 | 940 |

| g4 ECS | loop ms (min–max) | pass 2 | vs idiomatic | RSS MB | exe KB | cc ms | allocs |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Prismio** | **74.4** (67.8–82.5) | 73.6 | **3.10×** | 2.7 | 60 | 108 | 9,259 |
| Rust idiomatic | 24.0 (23.4–27.4) | 24.2 | 1.00× | 2.2 | 474 | 138 | 244 |
| Rust hand-tuned | 19.5 (19.3–20.8) | 20.0 | 0.81× | 2.0 | 474 | 139 | 199 |
| *Rust boxed [dx]* | *60.1* (52.3–65.0) | *56.6* | *2.51×* | *2.3* | *458* | *139* | *7,744* |
| Swift idiomatic | 99.0 (96.4–174.7) | 99.1 | 4.13× | 6.8 | 59 | 367 | 994 |

| g5 asset cache | loop ms (min–max) | pass 2 | vs idiomatic | RSS MB | exe KB | cc ms | allocs |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Prismio** | **83.5** (78.9–87.4) | 82.8 | **2.81×** | 1.9 | 61 | 108 | 4,293 |
| Rust idiomatic | 29.7 (29.1–52.5) | 29.4 | 1.00× | 1.8 | 474 | 151 | 213 |
| Rust hand-tuned | 5.1 (4.4–6.5) | 4.7 | 0.17× | 1.8 | 474 | 170 | 298 |
| Swift idiomatic | 71.7 (71.2–147.2) | 70.9 | 2.41× | 6.1 | 59 | 395 | 965 |

| g6 engine+game | loop ms (min–max) | pass 2 | vs idiomatic | RSS MB | exe KB | cc ms | allocs |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Prismio** | **245.0** (235.1–305.7) | 245.0 | **4.07×** | 4.1 | 61 | 110 | 15,137,004 |
| Rust idiomatic | 60.2 (59.3–81.2) | 60.7 | 1.00× | 2.6 | 474 | 154 | 289,094 |
| Rust arena | 50.2 (47.7–54.1) | 50.6 | 0.83× | 2.8 | 476 | 165 | 13,102 |
| Rust hand-tuned | 43.8 (42.3–47.0) | 44.3 | 0.73× | 2.5 | 474 | 154 | 239 |
| Swift idiomatic | 189.9 (182.3–270.2) | 188.7 | 3.15× | 7.7 | 60 | 394 | 361,837 |

**All 29 programs print identical checksums.** `bench.py` refuses to time a program whose variants
disagree, so this is asserted on every run rather than checked once.

`cc ms` is the default configuration, which since 2026-08-17 includes a warm toolchain object
cache. §5.5 gives the cache-bypassed number, which is the one comparable to session 3.

### Prismio against each baseline, in one place

| | vs idiomatic | vs Rust arena | vs hand-tuned | vs Swift |
|---|---:|---:|---:|---:|
| g1 | 1.38× | 1.40× | 5.36× | 1.38× |
| g2 | 5.89× | 6.77× | 10.74× | 3.29× |
| g3 | 1.13× | — | 1.70× | **1.00×** |
| g4 | 3.10× | — | 3.82× | **0.75×** |
| g5 | 2.81× | — | 16.39× | 1.16× |
| g6 | 4.07× | 4.88× | 5.60× | 1.29× |
| **band** | **1.13–5.89×** | **1.40–6.77×** | **1.70–16.4×** | **0.75–3.29×** |

---

## 2 · Prediction → session-3 measurement → now, per axis

The trajectory column is the point of this table. "S3 predicted" is the handoff brief plus
BENCHMARKS §4.1/§4.2 as they stood; "S3 measured" is RESULTS-xlang §2; "midpoint" is RESULTS-xlang
§0.1 (2026-08-17); "now" is this document.

| Axis | S3 predicted | S3 measured | Midpoint | **Now** | Trajectory |
|---|---|---|---|---|---|
| vs **idiomatic** Rust | 0.71× (§4.1) | 1.12–5.57× ✗ | 1.15–5.59× | **1.13–5.89×** | **flat — 7 sessions, no movement** |
| Alloc-heavy vs idiomatic | 0.8–1.1× | 5.57× g2, 4.22× g6 ✗ | 5.59×, 3.89× | **5.89×, 4.07×** | flat |
| vs **tuned** Rust | 1.0–1.3× | 1.67–17.7× ✗ | — | **1.70–16.4×** | flat |
| §4.2 object graphs, kill > 1.00 | 0.70–0.90 | 1.12–5.57 ✗ **killed** | — | **1.13–5.89** | still killed |
| §4.2 data-parallel bulk, kill > 0.90 | 0.35–0.65 | 1.42 (g1) ✗ **killed** | 1.42 | **1.38** | still killed |
| §4.2 p99 tail, kill p99/p50 > 3× | ≈ C | 1.22–1.75 ✓ **held** | — | **1.06–1.88 ✓** | **still held** |
| p99/p50 distance from Rust | — | within 0.04 on 5 of 6 | — | **within 0.07 on 6 of 6** | held |
| p999/p50 vs Rust | — | lower on 6 of 6 | — | **lower on 5 of 6** | ~held |
| Peak RSS vs idiomatic | 1.0–1.2× | 0.84–1.00× ✗ *in our favour* | — | **1.09–1.60×** | **reversed — now a loss** |
| Allocator churn | 0.2–0.5× | 10.5–63.7× more ✗ | — | **20.2–63.7× more** | flat |
| §4.1 Swift at 1.94× of Rust | 1.94× | 0.99–3.88×, med 2.08× ✓ | — | **1.00–4.13×, med 2.10×** | **held** |
| **Residual** (Prismio ÷ boxed) | not predicted | 1.20–1.30× (g2 0.63×) | — | **1.24–1.27× (g2 0.64×)** | **held** |
| `region` on g2 | escape hatch | **1.73× slower, 0 served** ✗ | — | **0.46×, 10.2 M served** | **fixed — §4** |
| Executable size | not predicted | 39–40 KB | — | **60–61 KB** | +53%, still 7.6× < Rust |
| Cold compile | not predicted | 1.5× rustc | — | **0.71–0.85× rustc** (cached) | win — but see §5.5 |

Every speed row that was falsified at session 3 is still falsified, by the same margin. **No
speed verdict has changed in seven sessions.** The rows that moved are `region`, RSS, executable
size and compile time — one fix, one regression, and two tradeoffs.

---

## 3 · The claim, stated the way the numbers support it

The claim to test was not "faster than Rust". It was **"as fast as *tuned* Rust, without the
tuning"**, with the bracket test: if idiomatic-Rust and tuned-Rust straddle us, that is the
headline.

**They do not straddle us.** On all six programs the ordering is:

```
hand-tuned Rust  <  Rust arena  <  idiomatic Rust  <  Swift?  <  PRISMIO
                                                  ( Swift's position varies )
```

Prismio is slower than *both* ends of the Rust bracket on every program in the corpus. The
smallest gap to the near end is g3 at 1.13× idiomatic; the largest is g2 at 5.89×. Against the far
end — the claim as written — the range is 1.70× (g3) to 16.4× (g5).

**What the numbers do support, stated precisely:**

- **For the same data representation, this compiler is within 1.24×–1.27× of rustc** (§5.1). That
  is the only figure here that is a statement about the compiler's design rather than about
  `List<T>`, and it has held for seven sessions.
- **On the one program where a one-word annotation applies, it is worth 2.2×** (§4) — which is the
  two-tier story working for the first time, and still lands at 2.62× idiomatic Rust, not parity.
- **Prismio is at or ahead of idiomatic Swift on two of six** (g3 1.00×, g4 0.75×) and within 1.4×
  on two more.

The honest one-liner is **"between idiomatic Swift and idiomatic Rust on the easy half of the
corpus, and 3–6× off idiomatic Rust on the allocation-heavy half"** — not the tuned-Rust claim.

---

## 4 · `region` on g2: session 3's sharpest negative result is fixed

Session 3 measured `prismio/g2_region.psm` — `g2.psm` with `region frame_arena { … }` around the
frame body and nothing else changed — as **inert**: 0 of 10,201,215 allocations served, manifest
byte-identical, and **1.73× slower** for the privilege. It was called "the finding that most
changes the plan". Re-measured now, 25 runs each, same script:

| | loop ms (min–max) | vs plain g2 | windowed allocs | arena served |
|---|---:|---:|---:|---:|
| `g2.psm` (plain) | 111.5 (107.1–173.8) | 1.00× | 10,202,214 | 0 |
| `g2_region.psm` | **51.6** (48.8–58.6) | **0.46×** | **2,222** | **10,200,000** |
| `g2_capacity.psm` | 107.6 (104.0–118.4) | 0.97× | — | — |
| `g2_tuned.psm` | 27.4 (24.4–49.4) | 0.25× | 3,195 | — |

All four print identical checksums. The cross-check is exact: `--verify` on the plain build reports
`10,202,025 released`, on the region build `2,025 released` plus `arena_objects 10200000` — the
difference is 10,200,000 to the allocation, which is the count the arena claims. `0 violation(s)`
on both. (The `aif-verify: FAILED` verdict on both is leak-driven and pre-existing — the frame_ns
dump allocates ~4 times per printed line — and is documented in HANDOFF; `violations` is the column
that had to stay 0, and it is 0 on all six corpus programs.)

**The annotation tier works now, and it did not at session 3.** That is a 3.75× swing on the
annotated variant (1.73× slower → 2.16× faster).

**Automatic placement still does not fire.** Plain `g2.psm` allocates 10,202,214 times through
`malloc` — the same number session 3 measured, with 0 arena objects. The escape hatch is unblocked;
inference has not followed it. That gap is exactly the distance between the product claim
("tuned-Rust behaviour from untuned code") and what ships, and it is §7 item 1.

---

## 5 · The accepted tradeoffs, reported anyway

### 5.1 · The residual — the only design number, and it held

`rust_boxed` holds Prismio's representation fixed (a vector of pointers to individually
heap-allocated records) and lets rustc emit the code, so `Prismio ÷ boxed` is everything that is
*not* the representation.

| | session 3 | now (pass 1) | pass 2 | boxed ÷ idiomatic |
|---|---:|---:|---:|---:|
| g1 | 1.30× | **1.27×** | 1.28× | 1.09× |
| g4 | 1.20× | **1.24×** | 1.30× | 2.51× |
| g2 | 0.63× | **0.64×** | 0.66× | 9.23× |

Unchanged. On g2, Prismio still beats rustc's own code for the same allocation profile. The
representation remains the whole gap on the programs where a gap exists: g4's 3.10× is 2.51×
representation and 1.24× compiler.

### 5.2 · Executable size — still a large win, and it grew

Prismio **60–61 KB**, Rust **458–476 KB**, Swift **54–60 KB**. Prismio is **7.6× smaller than
Rust** and now level with Swift. Session 3 measured 39–40 KB, so the binary has grown **+53%**
across the DWARF, generics, payload-enum, concurrency, targets and JIT work. The three are not
measuring the same thing — Rust statically links its standard library, Swift dynamically links a
runtime that ships with the OS — but a self-contained 60 KB binary whose only dependency is libc
is a real property.

### 5.3 · Peak RSS — this reversed, and it is on the next list

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---:|---:|---:|---:|---:|---:|
| Prismio, session 3 | 1.7 MB | 2.0 | 2.0 | 2.0 | 1.5 | 2.2 |
| **Prismio, now** | **2.2** | **3.3** | **2.7** | **2.7** | **1.9** | **4.1** |
| Rust idiomatic (both) | 2.0 | 2.2 | 2.0 | 2.2 | 1.8 | 2.6 |
| Swift | 6.3 | 6.8 | 6.6 | 6.8 | 6.1 | 7.7 |
| ratio, session 3 | 0.87× | 0.90× | 1.00× | 0.90× | 0.87× | 0.84× |
| **ratio, now** | **1.10×** | **1.47×** | **1.32×** | **1.19×** | **1.09×** | **1.56×** |

Session 3's "peak RSS was wrong *in our favour*" no longer holds. Prismio grew **27%–86%** on every
program while **Rust's figure did not move at all** on any of them, so this is a Prismio-side
regression and not a host artifact. It reproduces to two decimal places across both passes
(§6). Sized and narrowed in §7 item 2.

### 5.4 · Toolchain size

The compiler binary is **1.09 MB**, but it dynamically links Homebrew's `libLLVM.dylib` at
**156 MB**, so the honest toolchain figure is **~157 MB** — against a 1.5 GB rustc toolchain and a
240 MB Swift runtime tree. Still a win; not a 1.09 MB win.

### 5.5 · Compile time — a win in the default configuration, a regression underneath it

The toolchain object cache landed after session 3, so `cc ms` in §1 no longer means what session
3's column meant. Both configurations, median of 3, cold output artifact:

| | Prismio, cache on | Prismio, `PRISMIO_OBJ_CACHE=0` | rustc | swiftc |
|---|---:|---:|---:|---:|
| g1 | **103 ms** | 235 ms | 122 | 301 |
| g6 | **110 ms** | 241 ms | 154 | 394 |
| session 3 | — | *183 / 203 ms* | *107 / 145* | *269 / 351* |

- **Default (cache warm): 0.71×–0.85× rustc and 0.28×–0.34× swiftc.** A genuine win, and the
  number a developer actually experiences from their second build onward.
- **Cache bypassed — the like-for-like comparison with session 3 — is 235/241 ms against session
  3's 183/203 ms: a 19%–28% regression**, and 1.56×–1.93× rustc against session 3's 1.5×. The
  cache more than pays for it in the default path, but it is masking a real slowdown on the
  genuinely-cold path (first build, CI with no cache). §7 item 3.

### 5.6 · Ecosystem

Not measurable on this corpus and not measured. Stated for completeness: Rust's 1.97.1 toolchain
ships with cargo and crates.io; the g*_arena variants pull `bumpalo` with one line. Prismio has
`std/`, no package manager and no registry. Every corpus program was written against `std` alone
because there was no alternative. This remains the largest accepted tradeoff in the project and
nothing in this session changes it.

### 5.7 · Allocator traffic

Prismio allocates **20.2×–63.7×** more than idiomatic Rust (session 3: 10.5×–63.7×; the window
definition changed on 2026-08-16, so the low end is not strictly comparable). The prediction was
0.2–0.5×. The assumption behind it — that the baseline allocates per object too — remains the
single wrong premise: `Vec<T>` had already deleted the cost by inline storage.

---

## 6 · Why the tail is quoted from pass 2

`p99/p50`, the BENCHMARKS §4.2 kill criterion, in both passes:

| | Prismio p1 | Prismio p2 | Rust p1 | Rust p2 |
|---|---:|---:|---:|---:|
| g1 | 2.16 | **1.06** | 1.25 | **1.11** |
| g2 | 2.20 | **1.20** | 1.22 | **1.13** |
| g3 | 2.08 | **1.11** | 2.03 | **1.08** |
| g4 | 2.24 | **1.11** | 2.39 | **1.05** |
| g5 | 1.95 | **1.34** | 2.33 | **1.28** |
| g6 | 2.30 | **1.88** | 2.12 | **1.81** |

Pass 1 ran immediately after 31 compilations and every p99 in it — Prismio's *and* Rust's — is
inflated. The loop medians in the same two passes agree within 3%, which is the coherent story:
**a median resists the interference that a 99th percentile is defined to catch.** Pass 2 is the
quiet pass and is the one to read.

From pass 2: **Prismio's p99/p50 is within 0.07 of idiomatic Rust on all six programs**, against a
3× kill criterion — session 3's result (within 0.04 on five of six) holds. `p999/p50` is lower
than Rust's on five of six — g1, at 4.20 against 3.96, is the only exception — against six
of six at session 3.

**The claim that survives is the narrow one, and it is still the right one: the memory model adds
no tail of its own.** Prismio's p99 on g2 is 6.7 µs against Rust's 1.1 µs — six times worse in the
only unit a frame budget is denominated in. What makes the tail large is the median it sits on.

---

## 7 · Still losing, and not an accepted tradeoff

Four items. Each is named, sized, and carried to HANDOFF's next list.

**1 · Automatic arena placement does not fire on the corpus — 0 of 10,202,214 on g2.**
The annotation now delivers 2.16× on exactly this program (§4), so the mechanism works and the
inference does not reach it. Sized: the whole distance between plain g2 at 5.89× idiomatic Rust
and `g2_region` at 2.62×, on the two programs of six that allocate per frame. This is the item
that decides whether the product claim can be restated as "tuned-Rust behaviour from untuned code"
or has to stay "…from code with one annotation".

**2 · Peak RSS regressed from 0.84–1.00× to 1.09–1.60× of idiomatic Rust.**
Sized: +27% (g5) to +86% (g6) in absolute MB, with Rust's figure unmoved on all six, reproducing
across both passes to two decimals. Two causes are already **excluded** by measurement, which is
the useful half of this finding:
  - **Not fixed runtime footprint.** A minimal `println` program is **1.34 MB** in Prismio against
    **1.47 MB** in Rust — Prismio's floor is still *below* Rust's.
  - **Not the hot/cold split on g3 and g6** — vetoed on g3, `unsplit` chosen and emitted on g6 —
    and those two carry a +35% and a **+86%** regression between them, so the split cannot be the
    general cause. It is **not** excluded on g1, g2, g4 and g5: those four *do* emit splits
    (`%Particle.cold`, `%Renderable.cold`, `%Sprite.cold`, and three on g5), and a split makes one
    logical object two allocations plus a pointer. **Correction:** an earlier draft of this
    section checked only g3 and g6 and generalised "no corpus program is paying for a split" from
    them; four of six are. The split remains a live candidate on those four and a refuted one on
    the two with the largest regressions.
  - It scales with **live set, not churn**: g3 has ~1,800× fewer allocations than g2 but carries
    54% of g2's excess. That points at per-object overhead in what is retained, not at allocator
    behaviour. Bisecting it needs a session-3-era compiler, which is not in the tree.

**3 · Genuinely-cold compile regressed 19%–28%.**
Sized: g1 183 → 235 ms, g6 203 → 241 ms with `PRISMIO_OBJ_CACHE=0`, i.e. 1.56×–1.93× rustc against
session 3's 1.5×. Invisible in the default configuration because the object cache more than covers
it, which is precisely why it should be tracked — the first build on a machine and every
uncached CI build pay it.

**5 · The runtime call boundary — new, and the largest item on this list.** Every container access
is an un-inlinable `bl` into the separately-compiled C runtime. Merging program IR and runtime IR
into one module is worth **1.07×–1.87×** across the corpus (§9), takes g3 to **0.94× of idiomatic
Rust** — the first time a Prismio program has beaten it — and takes hand-tuned g2 from 2.45× to
1.32× of hand-tuned Rust. Needs no language change. `-flto` does **not** achieve it (1.00×), which
is why this went unseen for seven sessions.

**4 · The idiomatic-Rust gap has not moved in seven sessions.**
1.12–5.57× → 1.15–5.59× → 1.13–5.89×, across the arena, hot/cold split, `pin`, generics, payload
enums, concurrency, DWARF, targets, packaged runtime and JIT work. Not a defect, but the largest
open fact about the project: **the features that landed were not the features this corpus
measures.** Inline `List<T>` storage — ranked item 2 at session 3, still unbuilt — remains the
only change with a projected effect large enough to move the band, at ~1.2–1.3× across the board.

---

## 8 · Threats to validity

Session 3's list stands and is not repeated. Added this session:

- **The midpoint column is documentation-only.** `xlang/results.json` in the tree is a **5-run,
  g1-only** file whose meta reads `"runs": 5`, while RESULTS-xlang §0.1 describes a 20-run pass
  over six programs. Its absolutes are also ~1.9× inflated relative to both session 3 and today
  (Rust idiomatic g1 reads 35.6 ms there against 18.5 ms at session 3 and 19.0 ms now), so that
  pass was taken on a loaded host. **Only §0.1's ratios are usable**, and they are what the
  midpoint column quotes. The artifact cannot reproduce them.
- **Two passes, one host, one hour.** Pass 1 and pass 2 agree, but they share a machine state.
  Nothing here is portable evidence.
- **`cc ms` in §1 is cache-warm** and is not comparable to session 3's column. §5.5 has the
  comparable number.
- **Compile times for rustc and swiftc drifted** ~14% slower than session 3 measured (g1 rustc 107
  → 122 ms) with no version change on this host, so compile-time *ratios* are safer than
  compile-time absolutes across sessions.

---

---

## 9 · Why hand-tuned Prismio still loses to hand-tuned Rust — it is the runtime call boundary

Asked directly after the matrix landed: *when both sides are hand-tuned and both allocate nothing
in the frame loop, why is there still a gap?* `g2_tuned.psm` and `g2_tuned.rs` apply the same
tuning — one buffer, allocated once, refilled every frame — and reach zero steady-state
allocations. Prismio is **2.45×** slower. Three candidate causes, measured in order.

### 9.1 · It is not the representation. The boxed layout is *free* here

`g2_tuned.rs` uses `Vec<DrawCmd>` (inline storage); Prismio's `List<T>` holds pointers, so
`g2_tuned.psm` must pre-fill a buffer of individually-allocated records and mutate them in place.
To price that, `g2_tunedboxed.rs` was written: **the Prismio tuning, in Rust** — `Vec<Box<DrawCmd>>`
pre-filled once and mutated in place, field for field and loop for loop. Identical checksums.

| variant | loop ms (25 runs) |
|---|---:|
| Rust hand-tuned, `Vec<DrawCmd>` inline | 10.1 |
| **Rust hand-tuned, `Vec<Box<DrawCmd>>` — Prismio's representation** | **8.7** |
| Prismio hand-tuned, as shipped | 24.7 |

**The boxed representation is 0.86× — slightly *faster* than inline storage on this program.**
Once allocation is out of the loop, chasing a pointer to a 24-byte record costs nothing measurable
against `clear()`+`push()` into inline storage. So the representation, which is the whole story on
*untuned* g2 (`rust_boxed` at 9.23×), explains **none** of the hand-tuned gap.

### 9.2 · It is the un-inlinable call into the C runtime, and it is worth 1.87×

Every container access in a Prismio loop is a `bl` into the separately-compiled runtime. The
post-`-O2` IR for `cull_into` is otherwise clean — allocas promoted, phi nodes, tight loop — and
the machine code is 53 instructions containing `bl _list_get` twice per iteration plus
`bl _list_len`. At 2,002 accesses per frame over 20,000 frames that is ~40 M calls the optimiser
cannot see through.

Forced by merging the program IR and the runtime IR into one module with `llvm-link` and
optimising the result (0 `bl _list_get` remain, checksums unchanged):

| | loop ms | vs Rust tuned |
|---|---:|---:|
| Prismio `g2_tuned`, as shipped | 24.7 | 2.45× |
| **Prismio `g2_tuned`, runtime inlined** | **13.2** | **1.32×** |
| Rust `g2_tuned`, boxed representation | 8.7 | 0.86× |
| Rust `g2_tuned`, inline `Vec` | 10.1 | 1.00× |

**The call boundary is worth 1.87× on this program**, and what remains — **1.32×** of hand-tuned
Rust, 1.52× of the boxed control — is the same 1.20×–1.30× residual §5.1 reports everywhere else.
The compiler's codegen was never the problem; the *seam* was.

### 9.3 · It generalises, and it is worth more than anything else on the open list

The same merge applied to the untuned corpus programs, each against its own identically-built
baseline (both compiled `clang -O2` by hand, so the ratio is controlled even though the absolute
numbers differ a little from §1's driver-built binaries):

| prog | shipped | runtime inlined | worth | vs idiomatic Rust, before → after | vs tuned Rust |
|---|---:|---:|---:|---|---|
| g1 | 24.9 ms | 21.3 ms | 1.17× | 1.31× → **1.12×** | 5.09× → 4.35× |
| g3 | 49.8 ms | 46.5 ms | 1.07× | 1.01× → **0.94×** | 1.52× → 1.42× |
| g4 | 68.0 ms | 53.0 ms | 1.28× | 2.84× → **2.21×** | 3.49× → 2.72× |
| g5 | 76.6 ms | 42.1 ms | **1.82×** | 2.58× → **1.42×** | 15.04× → 8.26× |
| g2 (tuned variant) | 24.7 ms | 13.2 ms | **1.87×** | — | 2.45× → 1.32× |

**On g3 this is the first time in the project that a Prismio program beats idiomatic Rust** — 0.94×
— and it is not a rewrite, an annotation or a layout change. g5, the program with the tightest
noise band in the corpus (3.6%), moves from 2.58× to 1.42×.

**This is larger than any item previously on the list**, and unlike inline `List<T>` storage it
needs no language change, no views, no slices and no new syntax — the program IR and the runtime
are already both LLVM IR by the time they meet.

### 9.4 · `-flto` does not do this, and that is why it looked speed-neutral

RESULTS-xlang records `-flto` as "speed-neutral and worth ~15% of binary size". Re-measured, that
holds — and it is a fact about the flag, not about the opportunity:

| | loop ms |
|---|---:|
| `g2_tuned`, `-O2` | 25.2 |
| `g2_tuned`, `-O2 -flto` | 25.3 (1.00×) |
| `g2_tuned`, IR-level merge | 13.2 (1.87×) |

The `-flto` link inlines `cull_into` into `main` and drops `_cull_into` as a symbol, but leaves
**two `bl _list_get` in the inner loop**; the IR-level merge leaves none. **Why the linker's LTO
declines an inline that the same pipeline performs on a merged module is not established here**
and is one experiment, not a conclusion — but it is the reason seven sessions of "LTO is
speed-neutral" did not surface a 1.87× effect.

*(Method note: an earlier pass of this section reported that `-flto` had eliminated the calls,
from a `sed` range keyed on `_cull_into` — a symbol LTO had deleted, so the range matched nothing
and the count read 0. The check was rewritten to count `bl _list_get` over the whole binary.
A grep that returns 0 because its input was empty looks exactly like a grep that returns 0 because
the thing is gone.)*

## 10 · Reproducing

```bash
bash tools/bootstrap.sh --compiler build/E2  --out build/S10a
bash tools/bootstrap.sh --compiler build/S10a --out build/S10b
python3 aif/evidence/xlang/bench.py --compiler build/S10b --runs 25 \
    --json aif/evidence/xlang/results-s10.json
python3 aif/evidence/xlang/bench.py --compiler build/S10b --runs 25 --skip-build \
    --json aif/evidence/xlang/results-s10-pass2.json
```

Both JSON files are in the tree. The annotation-tier numbers in §4 build
`prismio/g2{,_region,_capacity,_tuned}.psm` and time them through `bench.measure` at 25 runs; the
arena ledger is `--verify` on `g2.psm` and `g2_region.psm`.
