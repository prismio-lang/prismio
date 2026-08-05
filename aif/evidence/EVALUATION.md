# AIF — Evaluation as a General-Purpose Memory Model

Prismio is a general-purpose language: Swift and Rust are the reference points, not Unity. UI
frameworks, engines and games are *consumers* of the language, not its definition.

This document evaluates AIF against that, using measured evidence
([RESULTS-L0](RESULTS-L0-tiers.md), [L1](RESULTS-L1-layout.md), [L2](RESULTS-L2-boundary.md)) rather than the
specification's own claims. It is a judgement, not a summary, and it disagrees with the
specification in three places.

---

## 1 · The finding that should drive planning

> **The cheap half of AIF delivered all of the measured tier benefit. The expensive half added
> nothing to it.**

Every tier number measured — 100% T0–T2 across six programs — was produced with:

- escape and aliasing inference only
- **no ownership contexts** (every function at `⊤`)
- **no monomorphization**
- **no layout search**
- **no cycle collector** (no type needed one)
- flow-*insensitive* analysis

That is AIF-1 (Core) from SPEC §11.0, near enough. The machinery that makes AIF expensive and
risky — context discovery, specialisation, `3ⁿ` bodies, hours-long layout search — contributed
zero to the tier distribution, because the distribution was already saturated.

Layout search does add value on top (RESULTS-L1: 3.96×–11.58× modelled on array-shaped code), but
it is a *separate* axis, and §3 argues it is far more workload-dependent than the spec admits.

**Implication:** AIF-1 is not a stepping stone toward the real thing. On this evidence it *is* most
of the thing, and AIF-2/AIF-3 are a long tail bought at steeply rising cost. For a general-purpose
language that has to ship, that reordering matters more than any individual feature.

---

## 2 · What holds up as general-purpose

**The invariant.** *Inference failure degrades performance, never correctness, never the build.*
This is workload-independent and it is the best idea in the model. It is what lets one language
serve a throwaway script (zero analysis, instant build) and a shipped product (full analysis) with
no semantic difference between them. Rust structurally cannot offer this; a GC pays regardless.

**The five-tier ladder.** T0 stack / T1 region / T2 unique / T3 shared / T4 residue is a good
taxonomy for any workload, not a game-shaped one. Swift is essentially T3-everywhere. Rust is
T0/T2 with T1 hand-rolled. Go is a GC. Spanning all five automatically is a genuine generalisation
— and it is *more* compelling for a general-purpose language than for a specialised one, because
general-purpose code varies more in what it needs.

**The manifest.** Cost as a reviewable diff, with a minimal cause and ranked repairs. Nothing about
it is domain-specific, and it is the piece most obviously worth having even in a language with none
of the rest of AIF.

**Two-speed compilation.** Non-negotiable for general purpose: a CLI tool must not take an hour to
build. It falls out of the budget being a dial rather than being bolted on.

**Determinism.** Rounds not wall-clock, round-synchronous truncation, deterministic tie-breaks.
Table stakes for a build system, and easy to get wrong — v1.0 did.

---

## 3 · Where the spec is over-fitted — the 80/20 budget rule

SPEC §9 freezes this as normative: *"Layout search SHALL be prioritised over lifetime proving, at
approximately 80/20."*

**Measured, that rule is wrong for a large class of programs.** RESULTS-L1:

| Program shape | Traversals found | Layout benefit |
|---|---:|---:|
| Particle system, ECS world | 3–9 | 3.96×–11.58× |
| **The Prismio compiler** | **0** | **1.00×** |

The compiler has *zero* collection traversals. It walks pointer-linked AST nodes. There is nothing
for a layout optimiser to choose between, so 80% of the compile budget would be spent producing
nothing.

That is not an edge case. It is the shape of compilers, interpreters, UI frameworks, business
logic, graph algorithms — most non-numeric code. The 80/20 rule is right for **array-shaped** data
and close to worthless for **graph-shaped** data, and a general-purpose language gets both.

**Recommendation:** the split should be *derived from measured opportunity*, not frozen. The
compiler can see whether traversals exist before spending anything — the static profile
(LAYOUT §2) is cheap and it already reports the traversal count. A program with no traversals
should spend ~0% on layout, and the budget rule should be a default that adapts, not a constant.

This is the one place the specification is confidently wrong.

---

## 4 · Regions generalise better than layout, and are under-emphasised

Every general-purpose workload has a natural region:

| Workload | Region |
|---|---|
| CLI tool | the whole process |
| HTTP server | one request |
| UI framework | one widget build pass |
| Game | one frame |
| Compiler | one parse, one function's analysis |
| Batch job | one record |

T1 is *the* general-purpose tier, and it is the one AIF is best at: bump allocate, bulk reset, no
per-object bookkeeping, cache-local by construction, and — per INFERENCE §4.4 — it collects cycles
for free and does not care about aliasing.

Measured support: the game corpus wanted T1 and landed T2 only because `region` does not exist yet
(RESULTS-L0 §6). That is the largest untested upside in the model and it is workload-independent.

**If effort had to be ranked, regions rank above layout search for a general-purpose language.**
The spec ranks them the other way.

---

## 5 · The biggest hole: closures

AIF's fact domains say nothing about **capture**, and INFERENCE §4 has no transfer rule for it.

Closures are universal in general-purpose code — callbacks, iterators, async continuations, event
handlers, comparators, builder functions. They are also precisely where aliasing gets hard: a
capture creates a reference whose lifetime is decoupled from the enclosing scope, which is the
canonical way a value becomes genuinely shared.

This matters more than the measurements suggested. RESULTS-L0 §3a found zero T3 across six
programs and I read that as "T3 may be rare." That reading is wrong for general-purpose code:
**handles eliminate sharing in engine code; closures reintroduce it everywhere else.** The corpus
had no closures because the language has none.

Until capture is specified, the T3 population is not merely unmeasured — it is unmeasurable.

---

## 6 · PIR is a heavier liability for general-purpose than for games

A game ships one monolithic binary and PIR §8's costs are survivable. A general-purpose language
has a package ecosystem, and the same costs land differently:

- every library ships source-equivalent IR
- no dynamic linking
- a security patch requires rebuilding every dependent

Rust pays part of this for generics and it is a recurring complaint. A language requiring it for
*everything* is a harder sell, and PIR §9's self-rebuilding binaries reduce the coordination
problem without removing it.

**The good news is measured.** RESULTS-L2: sealing the G6 engine cost 25 points of tier
distribution, the damage was confined to values that actually crossed the boundary, and **most of
it is recoverable by publishing ownership contracts** (now PIR §5.1). That points at a more
general-purpose-friendly posture than the spec currently takes: **sealed + contracted should be a
first-class distribution mode**, not a degraded fallback for proprietary code. Most libraries would
take a small, bounded, *declared* loss in exchange for a normal ABI.

---

## 7 · Honest scorecard

| | Verdict | Evidence |
|---|---|---|
| The invariant | **Strong** — the model's best idea, fully general | Structural |
| Tier ladder | **Strong** — good taxonomy for any workload | 6 programs, 100% T0–T2 |
| Regions (T1) | **Strong, under-emphasised** | Untested — `region` unimplemented |
| Manifest | **Strong**, worth shipping alone | Structural |
| Two-speed / determinism | **Strong**, table stakes | Structural |
| Layout search | **Real but workload-dependent** | 11.58× on arrays, 1.00× on graphs |
| 80/20 budget rule | **Wrong as a constant** | §3 |
| Monomorphization | **Unnecessary so far** | Added nothing to tiers |
| T3 / T4 / cycles | **Unmeasurable until closures exist** | §5 |
| Concurrency | **Vacuous** — `T` domain untestable | No task model |
| PIR ecosystem cost | **Heaviest general-purpose liability** | §6 |
| FFI | **Sound, and the one unsafe seam** | 33-point default swing measured |

---

## 8 · What I would change

1. **Un-freeze the 80/20 rule** (§3). Make it opportunity-derived, defaulting to layout-heavy only
   when traversals exist.
2. **Promote regions above layout** in implementation priority (§4). Bigger, more general, cheaper.
3. **Specify closure capture** in INFERENCE §4 (§5). It is the largest hole and it gates any honest
   T3 measurement.
4. **Make sealed + contracted a first-class distribution mode** (§6), not a fallback.
5. **Re-scope AIF-1 as the product**, with AIF-2/3 as opt-in tails (§1). On current evidence the
   cheap half is the model.

None of these changes the ladder, the invariant, or the inference procedure. They change what gets
built, in what order, and what the specification insists on.

---

## 9 · The comparison that matters

Against the languages Prismio is actually measured against:

- **vs Swift** — AIF's claim is Swift's ergonomics with T0–T2 where Swift has only T3. The measured
  tier distribution says that is achievable. This is the strongest, most defensible comparison.
- **vs Rust** — same safety, no borrow checker, at the cost of compile time and cost
  predictability. The manifest is the answer to predictability and it is a good one.
- **vs Go/Java** — no GC, no pauses, deterministic destruction, comparable ergonomics.

**The honest headline is not "as fast as C."** It is: *the ergonomics of Swift, with the allocation
behaviour of hand-written Rust, on code nobody annotated.* That is a claim the measurements
support, and it is a big enough claim without reaching further.
