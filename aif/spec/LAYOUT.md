# AIF — Workload Declaration, Cost Model, and Layout Search

Resolves SPEC §11 open items 2 (workload declaration), 3 (the layout cost model) and the residue of
the layout search space. These are one problem: the workload exists only to feed the cost model,
and the cost model exists only to rank candidates.

This is where ~80% of the optimisation budget goes (SPEC §9), so it is where the model's
performance thesis actually lives.

**Contents**

1. [The key reframing](#1--the-key-reframing)
2. [The access profile](#2--the-access-profile)
3. [`workload` declaration](#3--workload-declaration)
4. [The machine model](#4--the-machine-model)
5. [The cost model](#5--the-cost-model)
6. [The candidate space](#6--the-candidate-space)
7. [The search](#7--the-search)
8. [Empirical validation](#8--empirical-validation)
9. [Determinism](#9--determinism)
10. [Known weaknesses](#10--known-weaknesses)

---

## 1 · The key reframing

The obvious reading of `workload` is "the compiler needs a representative input to know how the
program behaves." That reading makes the annotation load-bearing, and it is what produced SPEC
§12's honest complaint: *"It has a hard dependency on a representative workload. No declared
workload means no search, which means back to heuristics."*

That complaint is **half wrong**, and correcting it changes the annotation's status.

Split what layout selection needs into two parts:

| | Where it comes from |
|---|---|
| **Structure** — which fields are accessed together, in what order, in which loops | **Static.** The compiler reads the loop bodies. This is exact, not estimated. |
| **Frequency** — how many times each loop runs, how long collections are | Dynamic. This is what a workload supplies. |

The structural half — the co-access sets, the traversal order, the read/write split — is the part
that decides **AoS versus SoA**, which is the largest single layout decision. The compiler can see
all of it without running anything.

> **The workload buys frequencies, not structure.**

So a build with no workload is not "back to heuristics." It has exact co-access structure and
estimated frequencies, which is enough for the dominant decision. What it loses is the ability to
rank two candidates that differ only in how *often* the deciding loop runs — a second-order
concern. This is why `workload` remains genuinely optional (SPEC §5) rather than quietly mandatory.

---

## 2 · The access profile

The cost model consumes an **access profile**, never a workload directly. The profile is the
artifact; the workload is one of two ways to produce it.

```
                 ┌─ static extraction (always) ─┐
   PIR ──────────┤                              ├──▶  profile ──▶ cost model ──▶ layout
                 └─ workload run (if declared) ─┘         │
                                                          ▼
                                                   checked into the repo
```

### 2.1 Contents

Per type `τ`:

| Field | Meaning | Source |
|---|---|---|
| `alloc(τ)` | allocations executed | dynamic (static: estimated) |
| `live(τ)` | peak live instances | dynamic (static: unknown → assume large) |

Per field `f` of `τ`:

| Field | Meaning | Source |
|---|---|---|
| `read(f)`, `write(f)` | access counts | dynamic; **static: exact site list, estimated counts** |
| `range(f)` | observed value range, for integer fields | dynamic only — enables bit-packing |

Per **traversal** `t` — a loop that iterates a collection of `τ`:

| Field | Meaning | Source |
|---|---|---|
| `touched(t) ⊆ fields(τ)` | fields the loop body accesses | **static, exact** |
| `order(t) ∈ {sequential, strided(k), random}` | from the index expression | **static, exact** |
| `writes(t) ⊆ touched(t)` | which of them are written | **static, exact** |
| `arith(t)` | arithmetic ops per iteration on `touched` | **static, exact** |
| `iters(t)` | total iterations executed | dynamic (static: `10^depth`) |
| `n(t)` | mean collection length | dynamic (static: assume `> C3`) |
| `tasks(t)` | concurrent executors | static from the task structure |

Per field pair, `co(f,g)`: co-access count within a window — drives hot/cold splitting. Static
version: 1 if some traversal touches both, 0 otherwise.

**Four of the seven traversal attributes are statically exact**, including the two that dominate
§5's cost function. That is the substance of §1.

### 2.2 Format

Line-oriented UTF-8, sorted, checked in beside the manifest — same reasoning as SPEC §6.2, and the
same benefit: it makes the expensive step opt-in and the build reproducible.

```
aif-profile 1
source      workload:parse_heavy          # or: static
runs        1
compiler    prismio 0.4.0
#
# type              allocs      live
type  Token          4812390    120400
type  Node           1204881     98211
#
# type.field         reads       writes    range
field Token.kind     9624780     4812390   0..63
field Token.start    4812390     4812390   0..16777216
field Token.len       902114     4812390   0..4096
#
# traversal          type    iters     n       order       touched        writes   arith
trav  classify@L214  Token   1204      4000    sequential  kind,len       -        3
trav  reindex@L387   Node    88        98211   random      parent,flags   flags    1
```

An implementation SHALL treat a missing profile as the static profile, and SHALL record in the
manifest which was used.

---

## 3 · `workload` declaration

### 3.1 Syntax

```prismio
workload parse_heavy {
    setup   { build_source(10000) }      // produces the input; not measured
    measure { parse_module(input) }      // the region whose accesses are profiled
    repeat  200                          // executions of `measure`
}
```

- `setup` runs once per execution and is **excluded** from the profile. It exists so that input
  construction does not pollute the access counts of the code under study.
- `measure` is the profiled region.
- `repeat` bounds build-time cost. It is a hint; an implementation MAY reduce it under budget.

A program MAY declare several workloads. Their profiles are merged by summation, weighted equally
unless a `weight` is given. Merging by sum rather than by average is deliberate: a workload
declared twice as important should count twice, and summation makes that expressible without a
second annotation.

### 3.2 Execution semantics

A workload SHALL be executed at build time in a sandbox, under a **baseline layout** (AoS, source
field order, no packing), with access instrumentation.

Normative constraints:

- **W1.** The workload SHALL NOT affect program semantics. It is build-time only and no part of it
  appears in the shipped binary.
- **W2.** A workload that fails to build, fails to run, times out, or exceeds the budget SHALL
  cause a fallback to the static profile and a **warning**. It SHALL NOT fail the build. (SPEC §1
  applies to the layout half of the model exactly as it does to the inference half.)
- **W3.** Effects the sandbox cannot satisfy — network, absolute filesystem paths, environment
  access — SHALL be stubbed, and their use SHALL warn. A workload needing a real environment is
  not reproducible and is therefore not a workload.
- **W4.** The profile is an **input to codegen only**. Two builds with different profiles SHALL
  produce behaviourally identical programs.

### 3.3 Why not a data file, and why not a declarative pattern description

Two alternatives were considered and rejected.

- **A data file** (`workload("inputs/sample.json")`) supplies data but not *which code path
  consumes it*, so the compiler still cannot attribute accesses to traversals. It also makes the
  profile a function of a file the compiler cannot check.
- **A declarative access description** (`@access(hot: [kind, len], pattern: sequential)`) is the
  thing the compiler already derives statically and exactly (§1). It would be an annotation that
  restates a fact the compiler knows — which violates SPEC §11's governance rule that an annotation
  must communicate what cannot be reliably inferred.

The executable form is the only one that supplies the missing half, which is frequencies.

---

## 4 · The machine model

Per-target constants. An implementation SHALL document its values and SHOULD calibrate them by
measurement rather than by datasheet.

| Symbol | Meaning | Typical x86-64 |
|---|---|---|
| `LINE` | cache line bytes | 64 |
| `C₁, C₂, C₃` | cache capacities | 32 KiB, 1 MiB, 32 MiB |
| `μ₁, μ₂, μ₃, μ_M` | access cost by level, cycles | 4, 12, 40, 250 |
| `μ_coh` | coherence miss (false sharing) | 100 |
| `V` | SIMD register bytes | 32 (AVX2) |
| `π(order)` | fraction of misses the prefetcher does **not** hide | sequential 0.15, strided 0.5, random 1.0 |
| `α_T` | allocation cycles at tier T | T0 0, T1 3, T2 90, T3 95, T4 110 |
| `λ` | cache-pressure cost per wasted live byte | 0.02 |
| `υ` | bit-unpack cycles per access | 2 |

`π` is the parameter most likely to be wrong and most worth calibrating: hardware prefetchers are
the single largest source of error in analytical cache models, and a bad `π` systematically
mis-ranks AoS against SoA.

---

## 5 · The cost model

`Cost(L)` estimates **cycles attributable to memory behaviour** for one execution of the profiled
workload under layout `L`. Score is `−Cost`; lower cost wins.

### 5.1 Traversal cost — the dominant term

For traversal `t` over `n(t)` elements of type `τ` under layout `L`:

**Bytes streamed per element.** This is where the AoS/SoA decision is decided.

```
bytes(t, AoS)       = size(τ, L)                                  -- whole record, always
bytes(t, SoA)       = Σ_{f ∈ touched(t)} width(f, L)              -- only touched fields
bytes(t, AoSoA(w))  = (1/w) · Σ_{f ∈ touched(t)} ⌈w·width(f,L) / LINE⌉ · LINE
bytes(t, random)    = groups_touched(t, L) · LINE                 -- a full line per group
```

The first two lines are the whole argument. A sequential loop touching 2 of 12 fields streams the
entire record under AoS and only the two arrays under SoA — often a 5–6× difference in bytes moved,
which is the largest lever in the model. The fourth line is the counterweight: **random access
favours AoS**, because one cache line delivers every field of the element, while SoA pays a
separate line per field.

Hot/cold splitting is expressed by grouping: if `touched(t)` lies entirely within the hot group,
only the hot record's bytes are streamed.

**Footprint decides which cache level pays:**

```
footprint(t, L) = n(t) · Σ_{f ∈ resident(t,L)} width(f, L)

μ(t, L) = μ₁ if footprint ≤ C₁ ;  μ₂ if ≤ C₂ ;  μ₃ if ≤ C₃ ;  else μ_M
```

**Traversal cost:**

```
TraversalCost(t, L) = iters(t) · n(t) · (bytes(t,L) / LINE) · μ(t,L) · π(order(t))
```

### 5.2 Arithmetic and the SIMD credit

*(Corrected after measurement — see [RESULTS-L1.md](../evidence/RESULTS-L1-layout.md) §4. The 1.2 text subtracted
`SimdCredit` from a sum of memory-only terms, which is incoherent: an arithmetic saving has nothing
to net against there, so `Cost(L)` could go **negative** and the ratios it produced were
meaningless. Arithmetic must appear as a positive term for the credit to reduce.)*

Arithmetic is a cost the layout influences, so it belongs in the objective:

```
ArithCost(t) = iters(t) · n(t) · arith(t)
```

A traversal that touches one numeric field over contiguous elements vectorises; one that walks a
strided AoS record does not.

```
lanes(f, L) = V / width(f, L)   if L places f contiguously (SoA or AoSoA), else 1

SimdCredit(t, L) = ArithCost(t) · (1 − 1 / min_{f ∈ touched(t)} lanes(f, L))
```

**`SimdCredit(t,L) ≤ ArithCost(t)` by construction**, so the two together are non-negative and the
total is bounded below by the memory terms. An implementation SHALL maintain this bound; without
it, a layout can be scored as having negative cost and the search will chase it.

This term is what makes SoA win sequential traversals outright: it is vectorisable where a strided
AoS record is not.

### 5.2.1 Linked splits and indexed splits are not the same cost

*(Added 2026-08-16, when §5.1 was first implemented in the compiler rather than in the prototype.
See [RESULTS-layout.md](../evidence/RESULTS-layout.md) §5.)*

§6's hot/cold row does not say how the cold group is *reached*, and the two possibilities have
different costs. A split is **indexed** when the cold group is a parallel block and element `i`'s
cold half is at a computed offset — reaching it is more streaming. A split is **linked** when the
hot record holds a pointer to a separately allocated cold block — reaching it is a dependent load
into unrelated memory.

The distinction is not cosmetic: a linked split is the only kind expressible without handles
(§6 note 2), so it is what an implementation without them will build, and:

```
bytes(t,L) for a sequential traversal touching cold fields =
    size(hot)                                   -- linked:  plus one dependent miss,
                                                   priced at π(random), not π(order(t))
    size(hot) + size(cold)                      -- indexed: one longer sequential scan
```

A linked split SHALL also charge the link word to `size(hot)`.

**Why this is normative rather than an implementation note.** Scored as an indexed split, a cut that
pushes a hot loop's own fields into the cold block reads as merely *wider*, and the model's top
candidates then sit inside its own noise: on `g1_particles.psm` the prototype separates its best two
candidates by **0.7%** and picks the good one by that margin, while the same model with the link word
added picks the bad one. Priced as a linked split, the good cut wins by 75 against 300 and the
ranking is stable. A cost model that cannot separate its top two candidates by more than its
calibration error is not selecting a layout, and §7.2's `argmin` inherits whatever it returns.

### 5.3 Allocation, footprint, packing, sharing

```
AllocCost(τ, L)     = alloc(τ) · α_{tier(τ)}
FootprintCost(τ, L) = live(τ) · (size(τ,L) − size_min(τ)) · λ
PackCost(f, L)      = (read(f) + write(f)) · υ        if f is bit-packed, else 0
FalseShareCost(L)   = Σ_{t : tasks(t) > 1}  iters(t) · linesShared(writes(t), L) · μ_coh
HandleCost(L)       = derefs(L) · 1                    -- one add per resolution; see §10.2
```

`PackCost` against the `bytes` reduction it produces is exactly the trade the model should decide
rather than a heuristic: packing pays when the field is streamed more often than it is read
individually.

`FalseShareCost` is the term that stops SoA being unconditionally right under concurrency: SoA
packs the same field of adjacent elements into one line, which is the worst case when different
tasks own different elements.

### 5.4 Marshalling

A type that crosses an FFI boundary pays a copy whenever its layout is not C-compatible
([FFI.md](FFI.md) §2). The optimizer sees that cost directly:

```
MarshalCost(τ, L) = Σ over FFI call sites c passing τ :
                        crossings(c) · (copyBytes(τ,L) / LINE) · μ_M   if L is not C-compatible
                        0                                              otherwise
```

`crossings(c)` comes from the profile the same way `iters(t)` does — counted by the workload run,
estimated by loop depth in the static profile.

The consequence is that **a type crossing the boundary in a hot loop is laid out C-compatibly
automatically**, because the C-compatible candidate wins on cost. No annotation is needed to avoid
an FFI copy; `pin` exists to *guarantee* the choice against a later edit, not to obtain it. FFI §4
develops this.

### 5.5 Total

```
Cost(L) = Σ_t [ TraversalCost(t,L) + ArithCost(t) − SimdCredit(t,L) ]
        + Σ_τ AllocCost(τ,L)  +  Σ_τ FootprintCost(τ,L)
        + Σ_f PackCost(f,L)   +  FalseShareCost(L)  +  HandleCost(L)
        + Σ_τ MarshalCost(τ,L)
```

The bracketed group is non-negative by §5.2's bound, so `Cost(L) ≥ 0` for every candidate.

**Reported, not hidden.** An implementation SHOULD be able to emit the per-term breakdown for any
type on request. A cost model whose terms cannot be inspected cannot be debugged, and BENCHMARKS
H2 needs the breakdown to test the 80/20 budget rule at all.

---

## 6 · The candidate space

SPEC §9.1 forbids exhaustive enumeration. The reason is `n!` field permutations; the fix is to
search a **structured** space and *derive* the rest.

Per type:

| Dimension | Candidates | Searched? |
|---|---|---|
| Grouping | `AoS`, `SoA` | **Yes** — 2 |
| Hot/cold split | none, or a cut at each distinct access-frequency rank boundary | **Yes** — ≤ \|fields\| |
| Field order within a group | descending access frequency, then descending alignment | **No — derived** |
| Bit-packing | per field with known `range` | **No — greedy, after grouping** |
| Handle width | 32-bit if `live(τ) < 2³²`, else 64 | **No — derived** |

Candidates per type ≈ `2 · (|fields| + 1)`. For a 10-field type that is 22, not 3.6 million.

> **AoSoA was cut in 1.2.** It was three of five grouping candidates and was **never chosen once**
> across six programs ([RESULTS-L1.md](../evidence/RESULTS-L1-layout.md)). It exists to be simultaneously
> vectorisable and line-local, but SoA won every sequential case and AoS won every random one, so
> the middle ground never paid. An implementation MAY reintroduce it if a workload demonstrates a
> case neither pure form serves; it is not worth 60% of the search space on present evidence.

**Why field order is derived rather than searched.** Within a group, the cost model is almost
insensitive to order — it depends on which fields are in the group, not their sequence — except
through padding. Sorting by descending alignment is optimal for padding, and sorting by descending
frequency is optimal for the split point. The two agree often enough that a fixed rule loses very
little and removes the factorial. **This is a deliberate precision-for-tractability trade and it
should be revisited if measurement shows the loss is real** (BENCHMARKS H2 is the test).

**Why packing is greedy.** Packing a field is nearly separable from grouping: it changes `width(f)`
and nothing else structural. Decide grouping first, then accept each packing whose `bytes`
reduction exceeds its `PackCost`, in descending benefit order.

---

## 7 · The search

### 7.1 Arena placement

*(New in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C7.)* Because every scope is an implicit region
(SPEC §4.1), the compiler must decide *which* scopes get a real arena. Not all should: arena setup
and teardown cost something, and a scope that allocates twice does not deserve one.

All the inputs are already in the profile:

```
ArenaBenefit(s) = allocs_in(s) · (α_T2 − α_T1)  −  entries(s) · arenaSetupCost
```

`allocs_in(s)` and `entries(s)` come from the access profile exactly as `iters(t)` does. Scopes are
ranked by benefit and arenas placed greedily where it is positive, respecting nesting — an inner
arena inside an outer one is only worth it when the inner scope's values die materially earlier.

`arenaSetupCost` is a machine-model constant (§4), default ~40 cycles: one allocation of the first
block plus the reset.

**`region` is a pin on this decision, not an input to it.** It guarantees an arena at a scope the
cost model might decline, and records the guarantee in the manifest so a later edit cannot silently
remove it. It does not supply the escape fact — the analysis already has that.

Ties break by scope node order (§9).

**`allocs_in(s)` counts only sites the code generator will actually route to `s`, and the two
predicates SHALL be the same one.** *(Added in 1.2.1, from a measured defect.)* A site excluded from
arena placement for a codegen reason — an element a container reclaims, a value an explicit `drop`
frees, a collection that reallocates past its own site — contributes no benefit, because the arena
will never see it. Scoring it anyway places arenas whose entire justification is traffic they do not
receive: in the reference implementation this put a live `arena_push`/`arena_pop` pair into three
programs that bump-allocated nothing, and inflated the §REQUIREMENTS-19 `peak-bytes` estimate on all
three — one of them reporting 64 bytes of arena for an arena holding zero. A budget gate reads that
number.

The failure is a duplicated predicate rather than a wrong model, which is why the requirement is
that they be one predicate and not merely that they agree.

Note also §SPEC 5.2.1: a site is only ever servable by an arena in **its own function**, so
`allocs_in(s)` is a sum over the sites lexically within `s`, never over what its callees allocate.

### 7.2 Layout selection

```
INPUT   profile P, machine model M, budget B_layout (in candidate evaluations)
OUTPUT  L : Type → Layout

 1  for each τ, in node order:  L(τ) := baseline(τ)          -- AoS, source order, no packing
 2  repeat:
 3      changed := false
 4      for each τ, in node order:                            -- coordinate descent
 5          best := argmin over candidates(τ) of Cost(L[τ ↦ c])   -- parallel, deterministic ties
 6          if best ≠ L(τ):  L(τ) := best;  changed := true
 7          B_layout −= |candidates(τ)|
 8      apply greedy packing to each τ
 9  until not changed, or B_layout exhausted
10  return L
```

Types are optimised against the *current* layout of every other type, so inter-type effects (two
types traversed in the same loop, a field whose width depends on another type's handle width) are
captured by iteration rather than by a joint search.

**Termination:** each round either strictly reduces `Cost` or halts, and `Cost` is bounded below,
so the loop terminates. In practice it converges in 2–3 rounds.

**Early termination** (SPEC §9.1) is permitted when a round's total improvement is below a
threshold expressed as a *fraction of current cost* — never as elapsed time. See §9.

**Parallelism:** line 5 evaluates candidates for one type independently, and distinct types within
a round may be evaluated concurrently provided all of them read the previous round's `L`. This is
the same round-synchronous discipline INFERENCE §5.1 requires, for the same reason.

---

## 8 · Empirical validation

At `max` only, and only when a workload is declared: after §7 converges, compile the top-`k`
candidates (default `k = 3`, ranked by modelled cost) and **run** the workload on each. Select the
measured winner.

This is what makes SPEC §9.1's "autotuning, not heuristics" literal rather than aspirational, and
it is the FFTW / Halide-autoscheduler precedent applied to general program data rather than to
loop nests.

**The determinism problem, and its resolution.** Measured selection depends on wall-clock timing,
which SPEC §11 item 12 forbids for a build. The resolution is already in the architecture:

> The measured winner is **recorded in the manifest**. Ordinary builds read the manifest and do not
> re-measure. Empirical validation is an explicit, separately invoked, human-reviewed step.

So the *build* stays deterministic while the *search* is empirical — which is exactly the split
SPEC §7.4 set up, and the second time the manifest turns a liability into a feature.

An implementation SHALL mark manifest records selected this way with `origin = measured`, SHALL
record the measurement's machine identity, and SHOULD warn when a `measured` record is consumed on
a materially different target.

---

## 9 · Determinism

Layout selection SHALL satisfy SPEC §11 item 12. Four obligations, mirroring INFERENCE §5.4:

1. **Candidate ties SHALL be broken by a total order on candidates**, defined lexicographically on
   `(grouping ordinal, split rank, packing bitmask)`. Floating-point cost equality is possible and
   must not resolve by iteration order.
2. **Cost SHALL be computed in a fixed evaluation order** with a fixed floating-point rounding
   mode, or in fixed-point arithmetic. Summing `Σ_t TraversalCost` in parallel with
   nondeterministic reduction order changes the low bits and can flip a tie. **Fixed-point integer
   cycles are recommended** — the model's inputs are integers and its constants are approximations,
   so floating point buys nothing and costs determinism.
3. **Early termination SHALL be a function of cost improvement**, not of elapsed time.
4. **Empirical validation is exempt**, because its output is a manifest record rather than a build
   decision (§8).

Obligation 2 is the one most likely to be violated by accident, and the one BENCHMARKS G1 exists
to catch.

---

## 10 · Known weaknesses

### 10.1 The cache model has no associativity and no conflict misses

`μ(t,L)` is a pure capacity model. Real caches are set-associative, and layouts that place hot
fields at colliding strides — a classic SoA failure at power-of-two array sizes — will be scored as
if they were free. Mitigation: penalise power-of-two strides. Not specified, because the correct
penalty is a measurement question.

### 10.2 `HandleCost` is a placeholder

One cycle per dereference assumes the base register stays live. When it does not, or when a real
indirection table is required, the cost is a load and possibly a miss. The model cannot currently
distinguish those cases because it has no register-pressure estimate. This under-states the cost of
handles, which is the one place AIF pays something C does not (SPEC §8.1) — so the model is
optimistic exactly where the design is most exposed.

### 10.3 Profiles age

A checked-in profile drifts from the code it describes. A profile whose traversal ids no longer
resolve SHALL warn. Whether a stale profile should be *rejected* is a policy question left to the
build gate, not to the compiler.

### 10.4 Static frequency estimation is crude

`iters(t) = 10^depth` is a guess with no defence beyond convention. Branch-probability heuristics
and loop-bound analysis would both improve it. Since §1's argument is that structure matters more
than frequency, this is deliberately left weak — **and that argument is itself untested.**
BENCHMARKS should compare a workload-driven build against a static build directly; if the gap is
large, §1's reframing is wrong and `workload` is closer to mandatory than SPEC §5 claims.

### 10.4.1 A fabricated instance count decides the cache tier, and therefore the layout

*(Added 2026-08-17, when §6's hot/cold row was first emitted rather than reported. See
[RESULTS-layout.md](../evidence/RESULTS-layout.md) §2.2.)*

§5.3's `FootprintCost` and §5.1's `μ` both read `N`, the number of live instances of the type, and no
implementation has one: the compiler substitutes a constant (2²⁰ in this one, on §2.1's "length
unknown statically" grounds). That is not merely imprecise, because `μ` is a **step function** of
`N · size(τ,L)` over the cache hierarchy: shaving eight bytes off a type can cross a tier boundary
and divide its modelled cost by the ratio between two tiers — a factor of six here.

Measured: `g4_ecs_world`'s `World` is a **singleton** — one instance, five `List` fields and an `Int`
— and the model scored a 2/6 split at 24 against 100 for not splitting, on a footprint saving that
does not exist. It ran at 1.042×.

An implementation SHALL NOT select a layout for a type whose instance count it is fabricating, unless
some other input independently establishes that the layout pays. `alloc(τ)` and `live(τ)` are already
in §2.1's profile; a **measured** profile supplies them and a static estimate does not, so this is one
more thing `workload` decides rather than a defect in the cost function itself.

### 10.5 One profile, one target

The profile is collected on the build machine under the baseline layout. Cross-compilation to a
target with different cache sizes uses the target's machine model but the host's frequencies, which
is sound but imprecise. Multi-target builds select per target and produce one manifest section
each; that is specified nowhere yet.
