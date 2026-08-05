# AIF — Cross-Language Comparison Suite

**C++ · Rust · Swift · AIF.**

Companion to [BENCHMARKS.md](BENCHMARKS.md), which covers the internal metrics (tier distribution,
the `debug`-vs-`max` control, correctness gates). This document covers the external comparison: how
to run it so the numbers mean something, and what result would falsify the model.

Benchmarks here are numbered **X1–X8** to keep them distinct from BENCHMARKS.md's internal
suite (B1–B7). The two overlap in spirit but not in membership: the internal suite includes a
self-compile benchmark that has no cross-language port, and this one includes a scalar control the
internal suite does not need.

**No number here has been measured.** Targets are stated as predictions with kill criteria.

---

## 1 · The thesis, stated so it can be killed

AIF's claim is not "faster than C++." SPEC §12.3 concedes optimal C is the ceiling. The claim is
narrower and much more falsifiable:

> **AIF written with no memory annotations should land where the other three land only after
> deliberate memory tuning.**

Which makes the comparison a 2×2, not a ranking:

| | **Low effort** — what a competent developer writes first | **High effort** — deliberate memory work |
|---|---|---|
| **AIF** | **zero annotations** | 4 annotations + `workload` |
| **C++** | `vector`, `unique_ptr`, values | arena allocator, hand-rolled SoA, `reserve` |
| **Rust** | `Vec`, `Box`, `Rc` where needed | `bumpalo`, index-based graphs, SoA |
| **Swift** | `struct` where natural, `class` where needed | `UnsafeMutableBufferPointer`, manual layout |

**Compare within a column. The thesis is that AIF's left column sits in everyone else's right
column.**

Mixing columns is how language benchmarks lie in both directions — "AIF beats C++" (idiomatic C++,
tuned AIF) and "AIF loses to C++" (tuned C++, zero-annotation AIF) are both obtainable from the same
suite by choosing which cells to quote.

### Kill criteria

| # | Condition | What it kills |
|---|---|---|
| **K1** | AIF-low does not beat C++-low, Rust-low and Swift-low on the memory-dominated benchmarks (X2–X5) | The core thesis. If zero-annotation AIF is not faster than idiomatic everything-else, the model has no reason to exist. |
| **K2** | AIF-low is not within 25% of C++-high on X3 (data-parallel) | The layout optimizer, and with it SPEC §9's 80/20 budget rule — that benchmark is where automatic SoA is supposed to be worth the most. |
| **K3** | AIF-high does not beat AIF-low by a meaningful margin | The four annotations. If they buy nothing, cut them and the whole §5 surface with them. |
| **K4** | AIF-low is worse than 1.15× C++-low on X7 (scalar) | The handle design. AIF must not tax code that has nothing to do with memory. |

**K4 is the one to check first.** It is the cheapest to run, it needs no layout work, and it is the
only one that detects the model actively *costing* something rather than merely failing to help.

---

## 2 · Fairness rules

The rules are the deliverable. A suite without them produces numbers nobody outside the project has
any reason to believe.

**F1 · Same algorithm.** Identical asymptotics, identical data structure semantics, identical
output — verified byte-identical against a reference file, in CI. A port that changes the algorithm
is not a port.

**F2 · Ports reviewed by a fluent practitioner of each language.** This is the single largest source
of dishonest cross-language benchmarks, and it is not a formality. A Swift port written by someone
who does not write Swift will use classes where a Swift developer would use structs, and will
measure ARC overhead the real ecosystem does not pay. Same for `shared_ptr` in C++ and `Rc<RefCell>`
in Rust. **An unreviewed port SHALL NOT be published.**

**F3 · Default allocator per language** in both tracks. A tuned-allocator row may be reported
separately and labelled. Silently linking jemalloc into one language's build is the second-largest
source of bad numbers.

**F4 · Equivalent optimisation settings.** `-O2` / `--release` / `-O -wholemodule-optimization` /
AIF `release`. LTO on or off consistently, and stated. A separate `max`/PGO row is permitted and
must be labelled.

**F5 · No `unsafe` in the low-effort track.** Rust `unsafe`, Swift `Unsafe*`, C++ raw `new`/`delete`
and reinterpret casts all belong in the high-effort column. AIF has no unsafe construct, so the rule
costs it nothing and must not be used to claim credit for that.

**F6 · Publish everything.** Sources, build commands, machine spec, raw timings — not summaries. A
result nobody can re-run is an assertion.

**F7 · Report per benchmark. Never publish a geometric mean across the suite.** A single "AIF is
1.6× faster" number is not a finding; it is an average over workload classes with wildly different
sensitivities, and it hides exactly the rows AIF loses.

### Three traps worth naming

- **The Swift strawman.** Swift's value types are genuinely fast. A port that boxes everything
  measures a Swift nobody writes. Where a Swift developer would reach for `struct`, the port uses
  `struct`.
- **The Rust free lunch.** Idiomatic Rust already uses `Vec` indices, arena-shaped ownership and
  flat data far more often than idiomatic C++ or Swift — so "Rust-low" is *already* partly tuned.
  Do not weaken it to make room for AIF. Rust-low is the hardest low-effort baseline and it should
  be.
- **The C++ `shared_ptr` strawman.** Real C++ uses `unique_ptr` and values. `shared_ptr` everywhere
  produces the atomic-refcount traffic AIF wants to beat, and it is not what the language is.

---

## 3 · The suite

Eight programs. The claim column shows what each is primary evidence for.

| ID | Program | Class | Primary claim | Notes |
|---|---|---|---|---|
| **X1** | AST build + traverse + rewrite, 10⁶ nodes | Object graph | T1/T2 replacing malloc traffic | The AIF-native shape: recursive types, shared subtrees |
| **X2** | Lex + parse 10 MB of source into an AST | Object graph, string-heavy | Regions over per-token allocation | Strings are the majority of the traffic |
| **X3** | Particle/entity update, 10⁶ entities × 100 steps, touching 3 of 12 fields | **Data-parallel** | **Automatic SoA** — the flagship | The benchmark K2 rides on |
| **X4** | Request loop: build a per-request object graph, use, discard, ×10⁶ | Request/response | One `region` per request | Headline runtime claim |
| **X5** | `binary-trees`, depth 21 | Allocation churn / shared | T3 behaviour, RC elision | The classic; comparable to published numbers |
| **X6** | Trivial CLI: parse argv, print, exit | Startup | Static region (SPEC §8.3) | Measures process lifetime, not steady state. Report baked fraction alongside the time |
| **X7** | Dense numeric kernel, no dynamic allocation | **Scalar control** | **Parity** — the K4 check | Must show AIF costs nothing here |
| **X8** | Concurrent map-reduce, 1–64 threads | High-core | Non-atomic counts, isolation | **Blocked** — no concurrency in the language yet |

**X7 is not filler.** It is the control that detects handle indirection and deopt tripwires taxing
code that never allocates. If AIF regresses here, every other result inherits the loss.

**X3 is the one that decides the model.** It is the only benchmark where the layout optimizer — the
recipient of 80% of the compile budget — is the dominant effect. Touching 3 of 12 fields is
deliberate: it is the case where AoS streams 4× the bytes SoA does, and where the entire "compiler
owns layout" bet cashes out or does not.

---

## 4 · Isolating the memory-model tax

Wall time compares *compilers*. To compare *memory models*, count the operations each model forces.
Every language can be instrumented; the mechanisms differ.

| Language | Allocation count | Refcount traffic | Cache behaviour |
|---|---|---|---|
| **C++** | `malloc` / `operator new` hooks, or `LD_PRELOAD` | instrument `shared_ptr` control blocks, or count `lock inc`/`lock dec` | `perf stat -e LLC-load-misses` |
| **Rust** | custom `GlobalAlloc` wrapper | count `Rc::clone` / `Arc::clone` through a shim type | same |
| **Swift** | `malloc` hooks | `swift_retain` / `swift_release` symbol interposition, or Instruments | same |
| **AIF** | instrumented allocator, **plus the manifest for the static picture** | counted per tier by construction | same |

Report these alongside every timing:

```
X3 · low-effort track

              time(ms)   allocs      rc-ops       LLC-miss     RSS(MB)
C++            1240      1,000,012            0   412,000,000     96
Rust           1180      1,000,004            0   408,000,000     94
Swift          2610      3,004,881   18,400,000   455,000,000    142
AIF             ???      ???                ???   ???            ???
```

**This table is worth more than the timing column alone**, because it explains *why* a number came
out the way it did, and because it is the only way to distinguish "AIF's model is better" from
"AIF's LLVM inlined more."

AIF is also the only entry that can produce a **predicted** row from the manifest before running
anything. Comparing predicted against measured is a direct test of the cost model in LAYOUT §5, and
it is free — the manifest is emitted by every release build regardless.

---

## 5 · Where AIF is predicted to lose

Stated in advance, because a comparison that only reports wins is marketing. These rows get
published, not buried.

| Axis | Predicted result | Cause |
|---|---|---|
| **Compile time** | **Loses badly** — minutes to hours vs. seconds | The budget being spent (SPEC §7.2). A deliberate trade, not a defect, and it must be reported. |
| **Binary size** | **Loses** to C++ and Rust | Ownership monomorphization (SPEC §12). BENCHMARKS H4 is the test; worse than 1.5× and specialisation becomes opt-in. |
| **C FFI** | **Loses** to C++ and Rust | The freeze boundary is a real copy in the worst case (SPEC §10.1). Rust's `repr(C)` is zero-cost; AIF's is not. |
| **Scalar compute (X7)** | **Parity at best** | Handle indirection is a cost C does not pay. Anything worse than 1.15× is K4. |
| **Random-access pointer chasing** | **Parity** | Layout freedom cannot help a genuinely random access pattern. LAYOUT §5.1 scores AoS the winner there, so AIF simply chooses what C already does. |
| **Small short programs** | **Parity** | `malloc` is fine at low allocation counts. Startup (X6) is the exception, via the baked heap image. |
| **Maturity** | **Loses to everything** | The other three have shipped for years. |

Compile time and binary size are the honest cost of the model, and SPEC §12 already names them. The
FFI row is the one most likely to matter to a first real user, since a first real user has a C
library to link against.

---

## 6 · Predicted results

Normalised to **C++-low** on each benchmark. Lower is faster. Every cell is a prediction from the
cost model, not a measurement.

| | C++-low | Rust-low | Swift-low | **AIF-low** | C++-high | **AIF-high** |
|---|---|---|---|---|---|---|
| X1 object graph | 1.00 | 0.95 | 1.75 | **0.75** | 0.65 | **0.65** |
| X2 lex/parse | 1.00 | 0.92 | 1.80 | **0.70** | 0.60 | **0.55** |
| **X3 data-parallel** | 1.00 | 0.96 | 1.60 | **0.45** | 0.38 | **0.35** |
| X4 request loop | 1.00 | 0.90 | 1.85 | **0.65** | 0.55 | **0.50** |
| X5 binary-trees | 1.00 | 0.94 | 1.70 | **0.85** | 0.70 | **0.75** |
| X6 startup | 1.00 | 1.00 | 1.40 | **cond.** | 0.95 | **cond.** |
| **X7 scalar** | 1.00 | 1.00 | 1.05 | **1.02** | 1.00 | **1.00** |

X6 is **conditional**, not a number: startup cost falls in proportion to the pure fraction of
initialisation, which the compiler reports (SPEC §8.3). X6 is a CLI with large static tables, so it
should bake near-totally and land around 0.35–0.45; a server that opens sockets at init would show
almost nothing. Quoting a single startup figure across program shapes is what 1.1 did and it was
wrong — see [CHANGES-1.2.md](../implementation/RATIONALE.md) C5.

Read the shape rather than the digits:

- **X3 is the load-bearing row.** AIF-low at 0.45 against C++-low at 1.00 is the whole "compiler
  owns layout" bet. If it comes back near 0.9, K2 fires and SPEC §9's 80/20 budget rule is wrong.
- **X7 must be flat.** 1.02 is the honest handle cost. If it is 1.3, the model taxes everyone.
- **X5 is AIF's weakest memory-dominated row** (0.85) and that is correct — `binary-trees` builds
  genuinely shared, genuinely escaping structures, which is the T3/T4 case AIF has the least to say
  about. A suite where AIF wins everything is a suite that was designed to make it win.
- **AIF-low ≈ C++-high on X1** (0.75 vs 0.65) is the thesis in one cell: close, from unannotated
  source. Not equal — SPEC §12.3's "approaches from below" is the honest framing.
- **AIF-high barely improves on AIF-low** in several rows. If that holds up, K3 fires and the
  annotation set should shrink. The rows where annotations *should* pay are X2 and X4, via `region`.

---

## 7 · Reporting

Every published figure carries: benchmark ID, effort track, compiler and version for every entry,
LLVM version where applicable, CPU model, ≥30 runs, **median and p99**, and the operation counts
from §4.

A figure without its kill criterion attached is not a result. A geometric mean across the suite is
not a result (F7).

**Publish the losses in §5 in the same artifact as the wins.** The model's credibility rests
entirely on the parts of it that are falsifiable, and a comparison that reports only favourable
rows converts a falsifiable design into an unfalsifiable one.
