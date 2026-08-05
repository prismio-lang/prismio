# AIF — Measurement and Falsification Plan

**No *performance* number in this document has been measured.** Every figure inherited from AIF
v1.0 is a projection from the cost model in SPEC §4.4, produced before any implementation existed.
They are recorded here as **hypotheses with kill criteria**, so the model can be falsified rather
than argued with.

> **H1 and the H4 indicator now have data.** See [RESULTS-L0.md](RESULTS-L0-tiers.md): 75.7% T0–T2 on the
> Prismio compiler's own source, which passes H1's kill criterion and falls short of SPEC §3's
> stated ≥90%. Every T3 in the program is a string. H4's `3ⁿ` risk did not materialise, because the
> mean reference-parameter count is 1.48. Two criteria below were corrected as a result — H4's, in
> §4.3, which tested the wrong quantity.

Companion to [SPEC.md](../spec/SPEC.md), [INFERENCE.md](../spec/INFERENCE.md), [GAPS.md](../implementation/COMPILER-AUDIT.md).

---

## 1 · The methodological point that matters most

The instinct is to benchmark Prismio against C, Rust, Go and Swift. That comparison is **not a test
of AIF**. It measures the whole compiler — parser, LLVM version, calling conventions, inlining
decisions, the standard library — and AIF's contribution is buried inside it. A bad result would be
unattributable and a good result would be unearned.

The comparison that isolates AIF is **internal**:

```
   Prismio, inference at `max`     ← the model
   ────────────────────────────
   Prismio, inference at `debug`   ← the same compiler, budget 0, everything at T4
```

Same frontend, same backend, same LLVM, same machine, same source. The only variable is the tier
assignment. **This ratio is AIF's actual effect size**, and SPEC §7.1's two-speed requirement is
what makes it available for free — the zero-analysis build is not a benchmarking harness, it is a
required product feature that happens to be the perfect control.

It is also available **years earlier** than the cross-language comparison. At GAPS Level 0 the
manifest alone yields the tier distribution, which is the leading indicator for every runtime claim
below. At Level 1 the allocation counts move. Neither needs the language to be finished.

**Cross-language numbers SHOULD NOT be published before the internal ratio is stable.** They will
be misread as a claim about the model when they are mostly a claim about LLVM.

---

## 2 · Primary metric: tier distribution

The leading indicator. Measurable from the manifest (SPEC §6) with no runtime and no codegen
changes — i.e. at GAPS Level 0.

### 2.1 Definitions

| Metric | Definition | Source |
|---|---|---|
| `D_static` | Share of abstract values ⟨site × context⟩ at each tier | manifest, counted |
| `D_dynamic` | Share of *executed* allocations at each tier | instrumented allocator on a run |
| `D_bytes` | Share of allocated bytes at each tier | instrumented allocator |
| `unresolved` | Share of records with `origin = budget-exhausted` or `speculated` | manifest |

`D_dynamic` is the one that predicts performance; `D_static` is the one available first. They can
diverge sharply — a single T4 allocation inside a hot loop outweighs a thousand T0 sites — so
report both and never substitute one for the other.

### 2.2 The claim under test

> SPEC §3: *"the overwhelming majority of allocations are provably T0–T2."*

**H1.** On the object-graph and request-shaped benchmarks (§3, B1/B2/B4) at `max` budget,
`D_dynamic(T0..T2) ≥ 0.90`.

**Kill criterion:** `D_dynamic(T0..T2) < 0.70`. Below that, the T3/T4 residue is doing enough work
that AIF is a reference-counting language with extra compile time, and the performance thesis is
dead regardless of what the layout optimizer does later.

**Intermediate result worth reporting either way:** the value of `unresolved`. A high
`D_dynamic(T4)` with high `unresolved` means the budget is too low. A high `D_dynamic(T4)` with
`unresolved ≈ 0` means the *analysis* is too weak. These need completely different responses and
the manifest distinguishes them for free (SPEC §6.2).

### 2.3 False sharing from field insensitivity

INFERENCE §11.1 flags object-insensitive field nodes as the most likely source of spurious T3/T4.

**Measurement:** for every field node that converged to `A = Shared`, count how many distinct
allocation sites store into it. A field made `Shared` by exactly one site, with the majority of
sites storing `Unique` values, is a false-sharing victim.

**Decision rule:** if false-sharing victims account for >15% of `D_dynamic(T3..T4)`, implement
allocation-site-indexed field nodes before anything else on the precision list. If <5%, the
refinement is not worth its graph-size cost and should be dropped from the roadmap.

---

## 3 · Benchmark programs

Constrained by what Prismio can currently express: no generics, no closures, no methods, no
`Option`/`Result` (GAPS §4.3). Every program below is writable in the language as it stands, which
is deliberate — a benchmark suite that needs unbuilt language features cannot gate the work that
builds them.

| ID | Program | Workload class | Available at |
|---|---|---|---|
| **B1** | The compiler compiling `src/main.psm` | Object graph | Now — already reproducible via the fixpoint test |
| **B2** | Lex + parse a large generated source (~10 MB) | Object graph, string-heavy | Now |
| **B3** | Fixed-size particle/entity update over parallel arrays, N = 10⁶, 100 steps | Data-parallel bulk | Now |
| **B4** | Request loop: allocate a per-iteration object graph, use it, discard, ×10⁶ | Request/response | Now |
| **B5** | `binary-trees` (the classic allocation-churn benchmark), depth 21 | Shared/cyclic stress | Now |
| **B6** | Trivial CLI: parse argv, print, exit | Startup | Now |
| **B7** | Concurrent map-reduce over partitioned data | High-core | **Blocked** — no concurrency in the language |

### 3.1 B1 is a weak headline and should not be the first result

GAPS finding 9: the compiler **leaks by design and exits**. Strings, arrays and lists are never
freed. It is already, in effect, a single-region program that never reclaims — which is close to
the best case AIF can produce. Measuring AIF on it will show a small improvement and understate the
model.

B1 is valuable as a **correctness and tier-distribution** subject, because it is large, real, and
self-verifying via the fixpoint test. It is a poor **speed** subject. Use B4 for the headline
runtime claim: it is the workload class whose claim is strongest (SPEC-inherited 0.60–0.80) and it
is where a per-request `region` is supposed to pay for the whole class.

### 3.2 Baselines

For each benchmark, in descending order of usefulness:

1. **Prismio at `debug` budget** — the internal control (§1). Required.
2. **C at `-O2`, straightforward implementation** — the normalisation point.
3. **C at `-O2`, hand-tuned** (SoA, arenas) — the ceiling AIF approaches from below.
4. Rust, Go, Java, Swift — context only, and only after 1–3 are stable.

Same machine, same LLVM major version where applicable, CPU frequency scaling pinned, ≥30 runs,
report median and p99, not mean.

---

## 4 · Inherited projections, as hypotheses

Recorded verbatim from AIF v1.0 §12 so they can be checked against. **Status of every row:
PROJECTED — no measurement exists.**

### 4.1 Relative runtime, normalised to idiomatic C `-O2`

Memory-behaviour-dominated mixed workload. Lower is faster.

| System | Projected | Status |
|---|---|---|
| Hand-tuned C++ (SoA + arenas) | 0.62 | reference point |
| **AIF (was "Prism R2")** | **0.70** | **PROJECTED** |
| Rust idiomatic | 0.98 | reference point |
| C / C++ idiomatic | 1.00 | normalisation |
| Koka / Perceus | 1.35 | reference point |
| Go | 1.45 | reference point |
| Java (JIT, warm) | 1.55 | reference point |
| Swift (ARC) | 1.90 | reference point |

### 4.2 By workload class

| Workload | Projected | Benchmark | Kill criterion |
|---|---|---|---|
| Scalar / compute-bound | 0.98–1.02 | — | > 1.15 (means the model is *costing* something on code it should not touch) |
| Object graphs | 0.70–0.90 | B1, B2 | > 1.00 |
| Data-parallel bulk | 0.35–0.65 | B3 | > 0.90 |
| Request / response | 0.60–0.80 | B4 | > 0.95 |
| High-core concurrent | 0.55–0.85 | B7 | > 1.00 |
| Startup / short-lived | **restated** — see below | B6 | see below |
| p99 tail latency | ≈ C | B4 | p99/p50 > 3× |

**The startup row was withdrawn in 1.2.** v1.0's flat 0.30–0.60 rested on a misdiagnosis of what
makes build-time initialisation hard — it assumed pointer relocation was the obstacle, when the
obstacle is initialisation that touches the environment ([CHANGES-1.2.md](../implementation/RATIONALE.md) C5). The
replacement claim is conditional and therefore testable per program:

> Startup cost falls in proportion to the **pure fraction of initialisation**, which the compiler
> reports (SPEC §8.3).

- Test: on B6 and on a server-shaped program, report baked fraction alongside startup time.
- **Kill:** a program with a baked fraction above 0.9 that does not reach 0.5 relative startup. That
  would mean the static region is not delivering even where the partition is favourable, and the
  mechanism is broken rather than merely conditional.
- A low baked fraction is **not** a kill. It is the mechanism correctly reporting that this program
  cannot benefit.

The **scalar row is the most important early check and the easiest to overlook.** It is the only
row where AIF claims *parity*, which means it is the row that detects the model actively hurting.
Handle indirection (SPEC §8.1) and deopt tripwires both show up here first, on code that has
nothing to do with memory management. If scalar regresses past 1.15, the handle design is wrong and
everything downstream inherits the loss.

### 4.3 Structural hypotheses

Beyond the speed table, four claims are load-bearing for the *design* rather than the numbers.

**H2 — the budget rule (SPEC §9).** *Layout search deserves ~80% of the budget because a cache miss
costs ~100× a refcount op.*

- Test: on B3, build three ways — full budget; layout search disabled with full lifetime proving;
  lifetime proving minimised with full layout search. Compare.
- **Kill:** if layout-disabled lands within 10% of full, layout is not worth 80% of the budget and
  SPEC §9's normative ordering is wrong.
- Requires the per-term cost breakdown of [LAYOUT.md](../spec/LAYOUT.md) §5.5; the aggregate score alone
  cannot attribute the difference.

**H2b — the static-versus-workload gap (LAYOUT §1).** *The workload buys frequencies, not
structure, so a build with no workload loses little.* This claim is what keeps `workload` optional
rather than quietly mandatory, and it is untested.

- Test: build B2/B3/B4 with a declared workload and with the static profile. Compare runtime and
  compare the *selected layouts* directly — the latter is the sharper signal, and it is free.
- **Kill:** if the static build is more than 15% slower, LAYOUT §1's reframing is wrong and SPEC
  §12's original "hard dependency on a representative workload" complaint stands.

**H3 — ownership monomorphization deletes the join (SPEC §11 item 4, INFERENCE §6).** *Most T3
values are forced by a call-site join, not by genuine sharing.*

- Test: build with contexts enabled vs. every function at the `⊤` context. Compare
  `D_dynamic(T3..T4)`.
- **Kill:** relative reduction < 25%. Below that, the single most expensive mechanism in the model —
  and the source of its worst risk (§4.4) — is not earning its cost, and it should be cut.

**H4 — specialisation holds code size (INFERENCE §7).** *(Downgraded in 1.2 from "the most likely
way AIF fails outright." SPEC §2.3 no longer requires body duplication, so a bad result here costs
one strategy on some functions rather than the specification — [CHANGES-1.2.md](../implementation/RATIONALE.md) C1,
C2.)*

- Test: on B1, `.text` size with contexts enabled versus disabled, after strategy selection and all
  three dedup layers. Report the strategy mix — what fraction of functions monomorphised, took the
  policy parameter, stayed shared.
- Also report the realised **relevant-parameter mask width** (INFERENCE §7.1), mean and p95, and the
  **ownership-divergence ratio `δ`** distribution (INFERENCE §7.0). `δ` is the input to strategy
  selection, so its shape decides whether selection is meaningful or arbitrary.
- **Kill:** `.text` growth > 1.5×, or I-cache miss rate on B1 rising enough to erase the tiering
  win. Either result means the monomorphise threshold is set too low.
- **Corrected criterion for the mask.** An earlier version asked whether the mask *proportionally*
  reduces the context space. That is meaningless when the base is small, and
  [RESULTS-L0.md](RESULTS-L0-tiers.md) §5 measured a base of 1.48 reference parameters. The quantity that
  decides code size is the **absolute body multiplier**, `Σ 3^mask / |functions|` — measure that.
- **Second kill, on `δ` itself:** if `δ` is unimodal — no clean separation between functions where
  ownership pervades the body and functions where it touches only alloc/drop sites — then strategy
  selection is guessing, and the policy-parameter form should simply be used everywhere.
- **Leading indicators, available before any codegen:** the mask width and the `δ` distribution.
  Both come out of a GAPS Level 0 build. This is measurable
  at GAPS Level 0.

**H5 — `region` is the highest-leverage annotation (SPEC §5.2).**

- Test: B4 with and without one `region` per request iteration.
- **Kill:** fewer than 50% of that iteration's dynamic allocations move to T1.

---

## 4.4 Measurements owned by other documents

Two measurement lists live where their design does, and are not duplicated here:

- **Layout** — cost-model calibration, especially the prefetch factor `π`, which is the parameter
  most likely to be wrong and the one that systematically mis-ranks AoS against SoA.
  [LAYOUT.md](../spec/LAYOUT.md) §10.
- **Cycles** — the cyclic-skeleton size distribution and the real T4b population, both of which are
  measurable at GAPS Level 0 with **no collector implemented**, because they are pure compile-time
  properties of the type graph. [CYCLES.md](../spec/CYCLES.md) §10.

The cycles list is worth running early and is nearly free: if the T4b population is near-zero as
CYCLES §1 predicts, an entire subsystem never needs to be written.

---

## 5 · Compile time

AIF spends compile time deliberately, so compile time is a **reported cost**, not a regression.
What must be measured is the *shape*, not the magnitude.

| Metric | Why |
|---|---|
| Wall time at `debug`, `release`, `max` on B1 | The two-speed dial's actual spread |
| Rounds to convergence, and `unresolved` at each level | Whether the budget is set anywhere near the knee |
| Inference time vs. layout time | Whether the realised split matches the 80/20 rule it claims |
| Contexts instantiated, before and after dedup | H4's input |
| Peak compiler RSS | The fact graph is one node per value per context; this can be the real limit |

**Requirement, not a target:** `debug` must stay in the same order of magnitude as today's ~290 ms
self-compile. If a zero-analysis build is not fast, SPEC §7.1's whole justification collapses — the
zero-analysis mode exists precisely so that development is unaffected by release-build cost.

GAPS §4.4 notes compile time is **already** superlinear in module size. Fix that first, or AIF's
cost cannot be attributed.

---

## 6 · Required correctness gates

These are not benchmarks. They are pass/fail conditions, and they matter more than any number
above, because every failure mode here produces a **silently wrong binary** rather than a crash.

| Gate | Test | Why it is easy to get wrong |
|---|---|---|
| **G1 · Determinism** | Run inference single-threaded and at maximum parallelism; manifests must be byte-identical | INFERENCE §5.4 — a time-based or step-based budget breaks this and nothing else detects it |
| **G2 · Incremental = cold** | Cold-build manifest and incrementally-rebuilt manifest must be identical at full convergence | INFERENCE §9 — summary-cache bugs are silent |
| **G3 · Two-speed equivalence** | All 56 tests pass at `debug` and `max`, with identical program output | SPEC §7.1. Currently trivially true; stops being trivial at GAPS Level 1 |
| **G4 · Annotation deletion** | Strip every annotation from every test; all must still compile and behave identically | SPEC §5. Catches an annotation that has quietly become load-bearing |
| **G5 · Soundness** | Full suite + B1–B6 under **`verify`** (SPEC §7.3), plus ASan and a debug allocator; zero assertion failures, zero leaks, zero use-after-free | `verify` is the strong form: ASan catches a wrong fact only when it *happens* to corrupt memory on that run, while `verify` asserts the fact itself. This is where a wrong escape fact becomes a security bug |
| **G6 · Self-host fixpoint** | The existing test: gen N and gen N+1 produce byte-identical IR | Already in CI. It is the strongest single correctness signal the project has, and every AIF level must preserve it |
| **G7 · Budget monotonicity** | For budgets B₁ < B₂, no value's tier is *higher* at B₂ than at B₁ | SPEC §4.3's monotonicity, tested rather than assumed. A violation means a transfer function is non-monotone (INFERENCE M2) |

**G7 deserves emphasis.** It is cheap to run, it directly tests the property that SPEC §1's entire
safety argument rests on, and a non-monotone module is otherwise almost undetectable — it produces
correct-looking builds that are wrong at one particular budget setting.

---

## 7 · Reporting

Every published figure SHALL carry: benchmark ID, budget level, compiler revision, LLVM version,
CPU model, run count, median and p99. A figure without a kill criterion attached is not a result.

Any figure inherited from v1.0 SHALL remain marked **PROJECTED** until it has been measured. The
R1→R2 gap — the claim that ownership monomorphization plus layout search moves the mixed-workload
number from 1.02 to 0.70 — is the least-supported claim in the entire model and the one to test
first. It is also, per H3 and H4, the one carrying the highest implementation risk.

**If the tier distribution at GAPS Level 0 comes back poor, stop.** That result arrives before any
codegen work and it falsifies the model at the cheapest possible point. Getting a discouraging
number early is the plan working, not the plan failing.
