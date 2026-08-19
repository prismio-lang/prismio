# AIF — Adaptive Inference Framework

**Prismio's memory model. Normative specification.**

| | |
|---|---|
| Version | 1.2 |
| Status | Draft — normative sections marked; §11 is the conformance boundary |
| Dated | 2026-08-01 |
| Supersedes | *The Prism Memory Model* v1.0 (2026-07-30), the PMM v1.1 open-choice resolutions, and AIF 1.1 |

AIF is the name of the whole model. "PMM" and "Prism Memory Model" are retired; where older
material says PMM, read AIF. The tier names (T0–T4), the annotation names, and PIR are unchanged.

Companion documents:

- [INFERENCE.md](INFERENCE.md) — the decision procedure. The keystone; v1.0 left it open.
- [LAYOUT.md](LAYOUT.md) — workload declaration, the cost model, and the layout search. Where 80%
  of the compile budget goes.
- [CYCLES.md](CYCLES.md) — the T4 cycle collector.
- [FFI.md](FFI.md) — the C boundary: marshalling rules and ownership contracts.
- [PIR.md](PIR.md) — library distribution, merging, and the ecosystem consequences.
- [BENCHMARKS.md](../evidence/BENCHMARKS.md) — internal metrics and the falsification plan.
- [COMPARISON.md](../evidence/COMPARISON.md) — the C++ / Rust / Swift / AIF suite.
- [GAPS.md](../implementation/COMPILER-AUDIT.md) — an implementation audit against one specific compiler; see its caveat.
- [CHANGES-1.2.md](../implementation/RATIONALE.md) — the ten design changes from 1.1 to 1.2, with reasoning.

---

## 0 · Conformance language

**SHALL** / **SHALL NOT** are normative requirements. **SHOULD** is a strong recommendation with
stated exceptions. **MAY** is permission. Sections marked *(informative)* impose no requirement.

An implementation that violates a **SHALL** is not AIF-conformant. Everything in §11's *open*
column is not yet specified and carries no conformance obligation.

---

## 1 · The invariant

> **Inference failure SHALL degrade performance only. It SHALL NOT affect program semantics, and
> it SHALL NOT cause compilation to fail.**

Every other decision in this document is downstream of this one. It is what makes the analysis
budget a dial rather than a toll: a build may run zero inference and still be correct.

This is not a promise; it is a consequence of two structural properties, both required:

1. **Tier is a monotone function of the inferred facts** (§4.3). A more conservative fact set
   yields an equal or higher tier, never a lower one.
2. **Every tier is semantically sufficient for every value.** T4 is universally safe. Any value may
   be assigned any tier at or above the one it requires, at a cost in performance only.

Together: giving up early raises facts toward the conservative end, which raises tiers, which is
always safe. §INFERENCE 5.3 states the one place this can go wrong (a truncated ascending
iteration is *not* conservative) and the required remedy.

### 1.1 What the invariant does not cover

> **The invariant governs tier inference only. Move and borrow violations are semantic errors and
> SHALL remain compilation errors.**

These are two different failures and conflating them would delete correct diagnostics:

| | Kind | Outcome |
|---|---|---|
| `use of moved value x` | A program bug. The source is wrong. | Compilation error |
| *could not prove `x` unique within budget* | An analysis outcome. The source is fine. | `x` sinks a tier; build succeeds |

An implementation SHALL NOT weaken the first in the name of the invariant.

---

## 2 · The objects of the model

### 2.1 Allocation site

A syntactic point that creates a value with independent identity: a struct literal, an array or
list construction, a string-producing operation, a boxed enum payload. Written `s`.

### 2.2 Ownership context

A function is analysed and compiled once per **ownership context** — the tuple of ownership modes
of its reference-carrying parameters.

```
Ctx(f) = ⟨m₁, …, m_n⟩       m_i ∈ { Unique, Borrowed, Shared }
```

Parameters of scalar type carry no mode and do not appear in the tuple. The number of contexts for
a function is therefore bounded by `3^n` in `n` reference-carrying parameters, and in practice by
the set of contexts that actually occur at call sites (§INFERENCE 6).

### 2.3 Abstract value

The unit the model assigns a tier to:

```
⟨s, κ⟩       s = allocation site,  κ = the ownership context of the enclosing function
```

**Tier SHALL be a property of `⟨s, κ⟩`, not of `s` alone.** The same source-level allocation may be
T2 in one caller's context and T3 in another's. This is what deletes the join at the call boundary,
and that join is the origin of most of the T3/T4 population.

**How an implementation realises context-dependent behaviour in generated code is unconstrained.**
Emitting one body per context — ownership monomorphization — is one strategy; INFERENCE §7 defines
three and selects among them by cost. *(Changed in 1.2. v1.1 froze body duplication as required,
which bundled a semantic claim with an implementation strategy and made binary bloat an existential
risk to the specification rather than to one optimisation. See [CHANGES-1.2.md](../implementation/RATIONALE.md)
C1.)*

### 2.4 What tier is not

**Tier SHALL NOT appear in the source language.** No tier is written in a signature, no type is
parameterised by one, no API is versioned by one, and no diagnostic requires the programmer to
choose one. Tier is an output of compilation, observable through the manifest (§6) and constrained
through `pin` (§5.4) — never an input to type checking.

---

## 3 · The tier ladder

Five tiers, totally ordered by cost. `T0 ⊏ T1 ⊏ T2 ⊏ T3 ⊏ T4`. The order is **frozen**; the
membership conditions are §4.

Each tier below states its **obligation** (what the implementation must guarantee), its **codegen
contract** (what is emitted), and its **cost**.

### T0 — Value / stack

- **Obligation:** the value does not outlive the activation record that creates it.
- **Codegen:** stack slot or register. `alloca` at function entry, or SSA value if never addressed.
  No allocation call, no deallocation, no header word.
- **Cost:** zero. No instruction is attributable to memory management.

### T1 — Region / arena

- **Obligation:** the value dies no later than the exit of a statically identified region `r`.
- **Codegen:** bump allocation from `r`'s arena. `r` exit emits a single arena reset. Individual
  values are never freed. Destructors, if any, run in reverse allocation order at reset.
- **Cost:** ~2–5 cycles per allocation (pointer bump + bounds check), amortized ~0 per
  deallocation. Values allocated in the same region are contiguous, which is the locality win.

### T2 — Unique owned

- **Obligation:** exactly one owning reference exists at any instant; ownership transfers by move.
- **Codegen:** general allocation (`malloc`-class or a size-class allocator). Moves are pointer
  transfers with no copy. Deallocation is emitted at the statically determined end of ownership
  (RAII). Non-escaping borrows are permitted and are plain reads.
- **Cost:** allocation and free only. No header, no counter, no barrier.

### T3 — Shared, non-atomic reference counting

- **Obligation:** multiple references may exist; no two tasks may hold references simultaneously;
  the reference graph over this value is acyclic.
- **Codegen:** one non-atomic count word per object. Perceus-style elision and drop-reuse SHALL be
  applied. Ownership transfer across a task boundary SHALL emit a release/acquire pair at the
  transfer point; the counter itself remains non-atomic, because the transfer serialises access.
- **Cost:** 1–2 cycles per surviving count operation, one word of footprint.

### T4 — Managed residue

Two sub-classes. Both are T4 for ordering and conformance purposes; **T4 is one tier, not two.**
The distinction exists so that a value pays only the tax it actually incurs.

| | Condition | Codegen | Cost |
|---|---|---|---|
| **T4a** | Reachable from ≥2 tasks simultaneously, acyclic | Atomic count word | 15–20 cycles uncontended, 50–300 contended |
| **T4b** | May participate in a reference cycle | Count word + cycle-collector registration | Count cost plus collector participation |

A value meeting both conditions pays both. An implementation SHALL distinguish the sub-classes; it
SHALL NOT charge atomics to a T4b value that is thread-local, nor collector participation to a T4a
value that is provably acyclic.

The design objective is to drive T4 membership toward empty. §BENCHMARKS 2 makes T4 share the
primary leading metric.

---

## 4 · Tier derivation

### 4.1 Inputs

Tier is computed from **four** inferred fact domains, each defined as a join-semilattice in
[INFERENCE.md](INFERENCE.md) §2. Summarised here:

| Domain | Values, cheapest first |
|---|---|
| `E` escape | `Region(s)`, ordered by scope nesting (inner ⊏ outer) ⊏ `Caller` ⊏ `Global` |
| `A` aliasing | `Unique` ⊏ `Borrowed` ⊏ `Shared` |
| `T` thread affinity | `Isolated` ⊏ `Transferred` ⊏ `CrossThread` |
| `C` cyclicity | `Acyclic` ⊏ `MaybeCyclic` |

Two notes on this table, both changes from v1.0:

- **There is no separate `Local` fact.** Every scope is an implicit region, so a stack-local value
  is simply one whose escape bottoms at `Region(defining scope)`. T0 is the degenerate case of T1
  where the region is the activation record, which makes the T0/T1 boundary a *size* question
  rather than an escape question.
- **Lifetime determinacy `L` is derived, not inferred.** `L = ScopeBound(s)` when `E = Region(s)`,
  `OwnerBound` when `A ⊑ Borrowed`, `Dynamic` otherwise. It names the deallocation obligation for
  codegen and adds no inference power, so it appears in no transfer rule and in no tier clause.

### 4.2 The derivation function

Tier SHALL be assigned only after the inference engine reaches a post-fixed point (§INFERENCE 5),
by the following total function. The first matching clause wins.

```
tier⟨s,κ⟩ =
  T0   if  E = Region(defscope(s))                  -- does not leave its own frame
       and A ⊑ Borrowed
       and size(s) is statically known
       and size(s) ≤ Θ_stack                        -- implementation-defined threshold

  T1   if  E = Region(r)  for any r                 -- allocate in r's arena

  T2   if  A ⊑ Borrowed  and  T ⊑ Transferred

  T3   if  T ⊑ Transferred  and  C = Acyclic

  T4   otherwise
         sub-class T4a  if  T = CrossThread
         sub-class T4b  if  C = MaybeCyclic
```

`Θ_stack` is implementation-defined and SHALL be documented by the implementation. It exists to
keep stack frames bounded; it is a performance parameter, not a semantic one.

Three properties of this function are worth stating explicitly, because each is a design result
rather than a restatement:

- **Region membership dominates aliasing.** The T1 clause tests only `E`. A value that is `Shared`
  within a region is still T1, because a bulk arena reset does not care how many references
  existed — nothing is freed individually. This is why `region` is the highest-leverage annotation.
- **Regions collect cycles for free.** The T1 clause does not test `C` either, for the same reason.
  Cyclicity only ever matters for values that escaped every region, which is what keeps the T4b
  population small.
- **T2 does not need to test lifetime.** `A ⊑ Borrowed` means exactly one owner exists, so death is
  located at that owner's death — `L = OwnerBound` by construction. An implementation MAY assert
  this as an internal consistency check.

### 4.3 Monotonicity (normative property)

Order fact tuples pointwise on the product `E × A × T × C × L`. Then:

> **`tier` is monotone: if `F ⊑ F'` pointwise, then `tier(F) ⊑ tier(F')`.**

Sketch: each clause's guard is a conjunction of downward-closed predicates (`x ⊑ c` is downward
closed). Raising any component can only falsify guards, never satisfy a previously false one, so
the first matching clause can only move later in the list, i.e. to a higher tier. ∎

This property is what §1 rests on, and it is the reason an implementation may abandon inference at
any point and remain correct — *provided* the fact state it abandons at is conservative. It is not
automatically conservative; see §INFERENCE 5.3.

### 4.4 Cost model constants *(informative)*

Used by §9 and by BENCHMARKS. Order-of-magnitude, contemporary x86-64 / AArch64:

| Event | Cycles |
|---|---|
| Bump allocation | 2–5 |
| `malloc` / `free` pair | 35–160 |
| Non-atomic count op | 1–2 |
| Atomic count op, uncontended | 15–20 |
| Atomic count op, contended | 50–300 |
| L1 hit | ~4 |
| L2 hit | ~12 |
| L3 hit | ~40 |
| **DRAM miss** | **200–300** |

The ratio that drives §9 is the last row against the third: a layout mistake costs roughly 100× a
lifetime mistake.

---

## 5 · Annotations

Exactly four. All optional; none is required to compile any program. **A conformant implementation
SHALL accept every AIF program with all annotations deleted, and SHALL produce a program with
identical observable behaviour.**

An annotation SHALL NOT be viral: none propagates an obligation into a signature that did not
already carry one, and none forces a caller to change.

Being wrong about an **axiom** (`unique`, `region`) SHALL produce a diagnostic of severity *warning*
and SHALL NOT fail compilation: the axiom is discarded and the value is inferred normally. Being
wrong about the **constraint** (`pin`) SHALL fail compilation when inference converged (§5.4.1) and
SHALL warn when it did not (§5.4.2).

*(Corrected in 1.2.1. v1.1 stated the warning rule for all four, and 1.2's C-change to §5.4.1 made
`pin` an error without revising this paragraph or §11 item 7 — so the specification asserted both.
The split is not a compromise between them: an axiom has somewhere to fall back to, because
discarding it leaves the ordinary inference that would have run anyway, and a constraint does not.
Discarding a refuted `pin` silently returns the value to the tier the programmer just said was
unacceptable, which is the one outcome `pin` exists to prevent — see §5.0.1.)*

The four are not the same kind of object. This distinction is normative because it determines
where each one enters the pipeline:

| Annotation | Kind | Enters at |
|---|---|---|
| `unique` | **axiom** — seeds a fact and cuts the graph | Fact graph, before iteration |
| `region` | **axiom**, and a **constraint** on arena placement | Fact graph, before iteration |
| `workload` | **information** — not a fact about any value | Layout cost model only |
| `pin` | **constraint** — restricts the result, derives nothing | After convergence |

### 5.0 Why exactly these four *(normative rationale)*

*(New in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C8. v1.1 defended the set only by resolve, which is
a prediction rather than an argument, and a set defended by resolve gets extended.)*

An annotation can do exactly three things: **supply information** the compiler cannot derive,
**assert a fact** so the analysis can stop, or **constrain an output decision** the compiler would
otherwise make. AIF has one of the first, two of the second, and two of the third — `region` is
both an axiom and a constraint.

The question that decides whether the set is complete is *how many axioms are warranted*. An axiom
earns its place exactly where establishing a fact requires **interprocedural** reasoning — that is
where cutting the graph saves real compile time and where inference is most likely to fail:

| Domain | Established how | Axiom warranted? |
|---|---|---|
| `E` escape | Interprocedural — must follow stores through calls | **Yes** → `region` |
| `A` aliasing | Interprocedural — must know what callees retain | **Yes** → `unique` |
| `T` thread affinity | Locally visible — task structure is syntactic | No |
| `C` cyclicity | Derived from the type graph and `A` | No |

The two domains needing axioms have them; the two that do not, do not. So the set is not four
conveniences — it is one information channel, one axiom per interprocedurally-established fact, and
one output constraint.

The argument is meant to be used. `@threadlocal` is an axiom on `T`, which is locally determined,
so it asserts what the compiler already sees — rejected as duplicative. `@acyclic` is an axiom on
`C`, which is derived — rejected. `@nocopy` is a constraint that duplicates `pin`. `@inline` is a
constraint on a decision outside the memory model's scope.

### 5.0.1 Annotations are assertions, not directives *(normative)*

*(New in 1.2.1. §5.4.1 already decided this for `pin`; stating it for the tier is what stops the
question being reopened one annotation at a time.)*

Every AIF annotation is a claim about the program that **the compiler verifies and MAY refuse**. No
annotation is an instruction the compiler carries out on the programmer's authority.

```
assertion:  the programmer states a fact; the compiler proves it, refutes it, or runs out of budget
directive:  the programmer states a decision; the compiler performs it, verified or not
```

AIF is assertions. Three independent reasons, any one of which is sufficient:

- **A directive needs `unsafe`, and AIF's host language does not have one.** A wrong assertion is a
  build error. A wrong directive is undefined behaviour — an arena-placed value that outlives its
  arena is a use-after-free, and no diagnostic follows it. A language may choose to offer that, but
  it must be designed as one feature with one clearly marked boundary, not accumulated one
  annotation at a time. Until such a boundary exists, an annotation that the compiler obeys without
  proof is a hole in the memory model.
- **§11's governance rule forbids it.** "An annotation SHALL NOT alter program semantics" is frozen.
  A directive that is wrong alters them.
- **It is the thesis.** Rust's leverage comes from the programmer *specifying* ownership; AIF's
  claim is that the compiler *infers* it and the programmer *constrains the result*. A directive
  tier would make AIF a worse Rust — the same annotation burden, without the soundness.

**What this costs, stated plainly.** The annotation tier cannot make anything faster than inference
already proved possible; it can only stop a regression, or pessimise deliberately. Anything a
programmer wants that the analysis cannot prove is a request to improve the analysis, not to
override it. §5.4's direction limit is the concrete form of this cost, and lifting it — permitting a
pin *below* the derived tier — requires a discharge obligation per tier written into this
specification, not a relaxed comparison in an implementation.

This is a hard boundary. A proposal to make any annotation a directive is a proposal to design
`unsafe` for the host language first.

### 5.1 `unique`

Asserts `A = Unique` for the annotated binding or parameter.

- **Effect as axiom:** the solver takes `A = Unique` as given and does not propagate aliasing facts
  into the annotated binding from outside its declaring scope. This cuts the interprocedural
  aliasing graph, which is where most of the analysis cost lives.
- **Local verification:** within the declaring scope, no operation that creates a second owning
  reference may be observed. This check is intra-procedural and cheap.
- **On violation:** warning, axiom discarded, `A` inferred as usual.

`unique` is the only one of the four with a Rust-shaped counterpart.

### 5.2 `region { … }`

Introduces a named region `r` and asserts `E ⊑ Region(r)` for every value allocated lexically
inside the block.

**Arena placement is a cost decision the compiler makes on its own, and `region` pins it.**
*(Changed in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C7.)* Because every scope is already an
implicit region (§4.1), `region` does not supply the escape fact — the analysis has it. What it
chooses is *arena granularity*, and that is a cost question with all its inputs already in the
profile: an arena is worth placing at a scope when the allocation volume there exceeds the
setup cost. LAYOUT §7.1 specifies the placement rule.

So `region`'s honest description is quieter than v1.1's: not "one line converts a subsystem from T3
to T1" — the compiler will often do that unprompted — but "one line guarantees it stays converted,
and records the guarantee in the manifest." It remains the highest-leverage annotation, and it is
less load-bearing than v1.1 implied.

- **Effect as axiom:** all sites inside the block are seeded at `Region(r)`, and `L` at
  `ScopeBound(r)`. The T1 clause then fires without any escape analysis.
- **Local verification:** no value allocated inside the block is stored into a location that
  outlives `r`. Checked by the ordinary escape analysis, restricted to the block.
- **On violation:** warning naming the escaping value and the store that causes it; **that value
  alone** is spilled — reallocated outside the arena at its inferred tier — and the block still
  compiles and still bulk-frees everything else.
- **Non-viral by construction:** block-scoped, so `r` never appears in a signature.

Regions nest. `Region` values are ordered by scope nesting, and their join is the least common
enclosing scope (§INFERENCE 2.1).

This is the highest-payoff annotation per character: it supplies the one fact no analysis can
recover, because it is intent — *this is a frame / a request / a parse / a level.*

#### 5.2.1 A region only reaches allocations in its own function *(normative limitation)*

*(New in 1.2.1, from measurement. Recorded here because three separate design passes proposed
escape-lattice fixes for a problem that is not in the escape lattice.)*

`Region(s)` names a **lexical scope** in one function. An implementation therefore serves a site
from an arena only when the `region` and the allocation are in the same function, because that is
the only case in which the site's escape and the region are comparable at all — a scope id from one
function and a scope id from another have no ordering, and their join is `Caller` by definition.

**This is a limitation of the model as specified, not of any implementation.** An allocation
performed in a callee cannot name its caller's region, however its escape is spelled, because the
arena that would serve it is selected at run time by the dynamic region stack while `E` holds a
static scope id. A value of `E` meaning "one activation up" does not close the gap: it makes the
site T1 without giving it an arena to be T1 *in*.

Measured on the reference implementation, 2026-08-14: of **234** allocation sites across
`aif/corpus` and `aif/evidence`, 38 are arena-served and 196 are not — and **all 196 fail this
test**. Every one of the 38 that pass is a case where the region and the allocation share a
function, and all 38 are in `std/io`: no user-written program in that tree has a single
arena-served allocation. The corpus's own tuning fixture — `g2_region.psm`, a frame loop wrapped in
`region frame_arena` — served **0 of 10 201 215 allocations** and ran **1.67× slower** than the
unannotated program, because its allocations happen inside `cull`.
([RESULTS-arena.md](../evidence/RESULTS-arena.md); re-derives in one command.)

An implementation SHALL warn when a `region` serves no allocation, naming the block. A region that
costs a push and a pop per entry and reclaims nothing is a pessimisation, and silence about it is
what lets an annotation be believed in for three sessions without being measured.

Closing this needs one of: **call-site placement** (the caller brackets a callee whose allocations
are all provably bound by the region — an interprocedural summary, cheaper than full contexts),
**ownership contexts** (INFERENCE §6–7, which instantiate the callee per call site so the region
becomes nameable), or **inlining before placement**. All three are real work; none is a change to
the escape lattice, and a proposal that only changes `E` should be measured against this section
before it is built.

#### 5.2.1.1 Call-site placement, and which regime it uses *(normative)*

*(New in 1.2.2.)*

An implementation MAY serve a callee's allocations from a caller's arena by **bracketing the
call** — pushing the region's arena onto the dynamic allocation stack for the call's extent. Where
it does, this section governs.

**The regime question, and the answer.** A function body's frees are *static* decisions in code
generation: which values a scope exit releases, and what disposition a container's element release
carries. Bracketing makes the *source* of an allocation dynamic. A body reachable both inside and
outside a bracket would therefore have to free arena memory on one path or leak heap memory on the
other. Three resolutions exist, and an implementation SHALL choose exactly one and record it:

| | regime | cost |
|---|---|---|
| **(a)** | Bracket only where the callee has **exactly one call site** in the program, so one body serves one regime | none; reaches less |
| (b) | Specialise the callee per regime — INFERENCE §7's body duplication, of which (a) is the degenerate case | binary size; needs a cap with deterministic victim selection |
| (c) | Record placement on the object and branch at release | works for containers; a bare struct freed by a scope drop has no header to read, so (c) is never sufficient alone |

**The reference implementation uses (a).** It is the smallest sound choice, and (c) cannot stand on
its own. **(a) is fragile as a language guarantee** — adding a second call to a bracketed callee
silently removes the placement — which is why an implementation using it SHALL record in the
manifest which call sites it bracketed, so the loss appears as a diff rather than as a slowdown.

**The obligations.** For a call `f(args)` inside region `R` to be bracketed, all of the following
SHALL hold. Each one is a use-after-free if omitted, not a lost optimisation:

1. Nothing `f` transitively allocates escapes to `Global`.
2. Nothing the extent allocates is stored into a location it did not itself allocate. The
   counterexample is the whole of this clause:

   ```
   fn add_to(dest: List<Node>, n: Int) { list_push(dest, Node { id: n }) }
   region R { add_to(long_lived_list, 5) }      // the Node comes from R and outlives it
   ```
3. The value the call returns does not outlive `R`. This is a property of the call site, not of
   `f`, and is the ordinary escape test in the caller.
4. The summary is a **least fixed point over the call graph**. Recursion and mutual recursion make
   the transitive callee set a closure rather than a walk.
5. Every exit from `R` — including an early return or a break out of a loop containing the call —
   pops the bracket. This is why the mechanism is a depth rather than a flag.

An implementation SHALL treat a callee whose body it cannot see, and whose FFI contract does not
describe every parameter and its return, as failing these obligations. FFI §5.1's `borrow` default
is an assumption adequate for assigning a tier and **not** adequate for handing a callee arena
memory.

**Measured on the reference implementation, 2026-08-16**, over `aif/corpus` and `aif/evidence`:
between 4 and 11 of ~35–45 functions per program clear obligations 1, 2 and 4, of which 1 to 5 also
satisfy regime (a). `region` is what turns that into placement: `g2_region.psm` has **2 call sites
inside its region and both reach a qualifying callee**, while every corpus program without a
`region` has none.

**Implemented, 2026-08-16.** Both calls are bracketed and `g2_region.psm` now serves
**10 200 000 of its 10 201 215 allocations** from `frame_arena`, against 0 before. No corpus
program without a `region` moved by a byte — the two halves of the measurement above are exactly
the two halves of the result.

Three consequences of this section that an implementer should not have to re-derive:

- **A bracketed site keeps its derived tier.** SPEC 5.2 makes the tier the derived fact and the
  placement a codegen decision, so the manifest reads `T2  region:<name>`: a value that crossed a
  function boundary has `E = Caller` by construction and nothing about bracketing changes that.
  Promoting it to T1 would move the tier distribution for a reason that is not an inference
  difference.
- **Only a `region`-pinned arena may be bracketed into**, never one an implementation's own cost
  model chose. Otherwise placement depends on bracketing depends on placement. `region` fixes the
  arena before placement runs, which cuts the loop.
- **Obligation 3 is not readable from the escape lattice.** `E` is already `Caller` for every site
  in the extent — that is what makes the extent an extent. The fact wanted is the *caller-side*
  binding of each callee-allocated value, which a points-to graph already carries: the locations
  that may hold it, and for a local binding the scope it was declared in. An implementation that
  tries to answer obligation 3 from `E` will find both the sound and the unsound case reporting the
  same value.

An implementation MAY additionally record placement on a container that has a header, and the
reference one does: a `List` stores which arena its element block came from, because `list_push`
reallocates that block long after the site that made it and would otherwise hand a bump pointer to
the deallocator. That is resolution (c) used as a *supplement* to (a), which is what the table above
means by (c) never being sufficient alone — the bare struct still relies on (a).

### 5.3 `workload(…)`

A declared representative input. It is **not** a fact about any value and SHALL NOT enter the fact
graph. It is consumed by the layout cost model (§9) to turn layout selection from estimation into
measurement.

Its concrete syntax and semantics are **open** (§11).

Absent a workload, the layout optimizer SHALL fall back to its static cost model. It SHALL NOT
fail, and it SHALL NOT block the build.

### 5.4 `pin`

Freezes a tier, a layout, or both, at a named point.

`pin` is how a programmer states **"this must be at least this cheap."** Where performance is a
requirement rather than a preference, that assertion has to be enforceable: a silent tier drop in a
frame loop is not a survivable outcome, and a build gate someone can rubber-stamp is not always
sufficient.

Applied **after** convergence. `pin` derives nothing and seeds nothing; it constrains the output.

```
if pinned_tier ⊒ derived_tier:        honour exactly

else if facts permit pinned_tier:     honour
                                      (the solver was imprecise; the pin is a correct
                                       assertion it failed to prove)

else if the analysis CONVERGED:       ERROR -- the assertion is provably false  (§5.4.1)

else (budget exhausted, unproven):    warn, ignore the pin, use derived_tier.
                                      SHALL NOT be an error  (§5.4.2)
```

A `pin` that is honoured SHALL be recorded in the manifest (§6) as honoured, so a later edit which
invalidates it is visible as a diff rather than as a silent slowdown.

#### 5.4.1 A proven-false pin is a compile error

*(Changed in 1.2. v1.1 warned in this case, which left `pin` unable to do the one job it exists
for.)*

If inference **converged** and the converged facts make the pinned tier unreachable — the value
demonstrably escapes, or is demonstrably shared — the programmer has asserted something false about
their own program. That is a **program error**, in the same category as `use of moved value`
(§1.1), and it SHALL fail compilation.

**This does not weaken the invariant.** §1 governs *inference failure*: the analysis being unable to
prove a value cheap. It has never governed *a programmer assertion being wrong* — §1.1 already draws
that line. A pin a converged analysis refutes is the second thing, not the first.

#### 5.4.2 An unproven pin is never an error

If the analysis did **not** converge — the budget ran out and the value is marked
`budget-exhausted` (§6.2) — the pin is unproven, not disproven. Failing the build here would punish
the programmer for an analysis limitation, which is precisely what §1 forbids.

The implementation SHALL warn, ignore the pin, use the derived tier, and SHOULD report that raising
the budget may resolve it. **The two cases are distinguishable for free**, because the manifest
already records convergence per record.

#### 5.4.3 Strictness is opt-in, per value

The default remains: degrade, record it, fail the *gate* (§6). That is right for most code, and
making everything strict is how a language becomes Rust.

`pin` buys strictness exactly where it is worth having — the hot loop, the frame arena, the
allocation path with a budget. This is the same shape as [TARGET.md](../implementation/TARGET.md) §2.1: **the
framework or engine author pins the handful of values whose cost is load-bearing; the application
author writes nothing and is never blocked.**

#### 5.4.4 The direction limit *(normative)*

*(Stated in 1.2.1. It was implicit in §5.4's pseudocode and in every implementation of it, and
naming it is what makes the cost of §5.0.1 legible rather than a surprise.)*

A `pin` is honoured when the pinned tier is **at or above** the derived tier, and refuted below it
on a converged analysis. So a programmer MAY pessimise deliberately and MAY NOT optimise past the
analysis. This is sound in one direction only, and the asymmetry is the point: every tier is
semantically valid, so weakening needs no proof, while strengthening needs exactly the proof the
analysis just failed to find.

The consequence, stated plainly because it is the whole cost of §5.0.1: **the annotation tier cannot
make a program faster than inference already proved it could be.** It stops regressions, it records
guarantees in the manifest, and it lets a programmer choose a more expensive tier on purpose. It is
not a tuning knob.

Lifting the limit — permitting a pin *below* the derived tier — requires a **discharge obligation
per tier** written into this specification: what the compiler must check, what it may assume, and
what happens at run time when the assumption is wrong. Absent that, a pin below the derived tier is
a directive, and §5.0.1 forbids directives until the host language has an `unsafe` boundary. A
relaxed comparison in an implementation is not a discharge obligation.

**Two of the tiers have working Rust counterparts today**, and they are what `pin` currently buys:

| | Rust | effect |
|---|---|---|
| `let pin(T2) node = …` | `Box::new` | heap, uniquely owned, freed at its owner's teardown |
| `let pin(T3) shared = …` | `Rc::new` | reference counted, freed at zero |

`pin(T3)` emits a count only where a count has something to count — a value no container holds has
no edge to increment, and the manifest SHALL say so (`rc:none`) rather than claim a mechanism the
binary does not contain.

#### 5.4.5 `pin(<region-name>)` — the placement form *(normative)*

*(New in 1.2.3. Deferred through three sessions because until call-site placement landed its
headline example refuted; §5.2.1.1's "Implemented, 2026-08-16" is what unblocked it.)*

`pin`'s argument is one identifier and it names one of two things. A **tier name** constrains the
tier, per §5.4 above. **Any other identifier is the name of a `region`**, and the annotation asserts:

> the allocation this binding denotes is served by the arena of the `region` named `<name>`.

An implementation SHALL adjudicate it **after** arena placement, unlike a tier pin, which §5.4
applies after convergence and before it. A tier pin is an *input* to placement — a cost model ranks
scopes by tier — and a placement pin is an assertion about its *output*.

The outcomes are §5.4's, minus one. Honoured when the arena serving the site is the named region;
**refuted, and an error, when the analysis converged and it is not** (§5.4.1); unproven and a
warning when it did not (§5.4.2). §5.4.4's direction limit has nothing to apply to: tiers are
ordered and placement is not — an arena either serves a site or it does not — so "served by a
different region" is a refutation and not a weaker honour. A name no `region` in the program carries
is likewise refuted, which is also what a mistyped tier now produces.

**This exists because of §5.2.1.1's own admission.** Regime (a) brackets a call only while its
callee has exactly one call site, so a second call silently removes the placement; that section
requires the manifest to record every bracket so the loss "appears as a diff rather than as a
slowdown". A diff is read by whoever looks. This is the same fact asserted by the programmer, so a
build fails on it.

Two obligations on an implementation, both of which the reference one meets:

- **It SHALL derive the verdict from the same predicate that decides placement**, not from a second
  reading of the bracket record. Two predicates that agree today are two predicates, and §5.2 already
  records what four copies of an arena gate cost.
- **It SHALL NOT alter placement.** §5.0.1 makes every annotation an assertion; a placement pin that
  *caused* an arena to be chosen would be a directive, and the tier it pinned would then be
  unverifiable. Deleting every `pin(<region-name>)` from a program SHALL leave the emitted code
  unchanged — which is a testable property, and the test for this feature.

---

## 6 · The tier manifest

Every release build SHALL emit a tier manifest. The manifest is checked into the repository and
diffed by CI.

**A manifest regression SHALL fail the build gate. It SHALL NOT fail compilation.** These are
different things: the compiler still produces a correct binary; the pipeline refuses to accept it
without review.

### 6.1 Purpose

Three, in order of importance:

1. **Cost predictability.** Inferred tiers move non-locally on a small edit. The manifest makes
   that movement a reviewable line in a pull request rather than an invisible regression.
2. **Build reproducibility.** Search-based layout selection would otherwise make builds
   non-reproducible. With chosen layouts *recorded* rather than re-derived, the ordinary build is
   deterministic and the expensive search becomes an explicit, opt-in step (§7.4).
3. **Falsifiability.** The manifest is the primary data source for the tier-distribution metric in
   BENCHMARKS §2.

### 6.2 Format

Line-oriented UTF-8 text, so that `git diff` is readable. Records sorted by symbol, byte-wise
ascending — the sort is normative, because an unstable order makes every diff useless.

```
aif-manifest 1
build       release
budget      8000000 steps
converged   yes
compiler    prismio 0.4.0
llvm        22.1.0
#
# symbol                      tier  placement          layout       origin
Lexer.source                  T2    owned              AoS          inferred
Lexer.tokens                  T1    region:lex_module  SoA[16]      region
Parser.node_pool              T1    region:parse       AoS          region
Token                         T0    stack              packed:12    inferred
Diagnostic.message            T3    rc                 AoS          inferred
Module.imports                T4a   rc-atomic          AoS          inferred
Session.cache                 T2    owned              AoS          pin
```

`origin` is one of `inferred`, `unique`, `region`, `pin`, `speculated`, `budget-exhausted`. The
last two matter: they mark values whose tier is not a settled proof, and a reviewer should treat a
large `budget-exhausted` population as a signal to raise the budget, not as a result.

### 6.3 Diff semantics

A diff SHALL report, for each changed record, a **minimal cause** and SHOULD report **ranked
repairs**. *(Strengthened in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C4. v1.1 reported only the fact
that changed, which made regressions visible without making them understandable.)*

```
Session.buffer   T1 → T4a

  minimal cause
    E rose Region(handle_request) → Global
      ← A-STORE   Session.buffer stored into Logger.sink      api.psm:88   [this change]
      ← E-STATIC  Logger.sink is a static root                logger.psm:12

  repairs, cheapest first
    1. make Logger.sink region-scoped                    restores T1, no runtime cost
    2. store a copy instead of the buffer                restores T1, +1 copy per request
    3. pin Session.buffer T1                             rejected — provably escapes
```

The minimal cause is computable and cheap: walk backward through the derivation DAG following only
**maximal contributors** — for a fact `f` at node `n` with value `v`, the predecessors whose
transfer produced `v`. The shortest such witness path is the minimal cause. It is a breadth-first
search on a DAG of small practical depth, not a general min-cut. INFERENCE §5.6 specifies it.

Each edge on the path carries the rule that fired, which is what makes repairs derivable: breaking
any edge restores the tier, and the cost of breaking it is known. **A repair that is unsound SHALL
be listed as rejected with its reason** — knowing which fix will not work is worth as much as
knowing which will.

Retaining the derivation DAG through tier assignment is required for this and is the only cost.

Any tier increase, any layout change on a symbol marked hot, and any `pin` that stops being
honoured SHALL be treated as a regression by the default gate.

---

## 7 · Two-speed compilation

### 7.1 Requirement

A conformant implementation SHALL provide a zero-analysis build mode, and its output SHALL be
behaviourally identical to the optimised build's.

"Behaviourally identical" means: same observable program semantics, including destruction order and
the timing of externally visible effects (file and socket close, in particular). It does **not**
mean same performance, same tier assignment, same layout, or same binary size.

### 7.2 Levels

Levels are compile-time **budgets**, not different algorithms. The same engine runs at every level.

| Level | Inference budget | Layout search | Ownership monomorphization |
|---|---|---|---|
| `debug` | 0 rounds — every value goes straight to its ⊤ tier | none | none |
| `release` | Bounded, implementation-defined default | Static cost model, bounded candidate set | Demand-driven |
| `max` | Raised bounds, raised context cap | Full search, workload-driven if declared | Demand-driven, raised cap |
| `verify` | As `release` | As `release` | As `release` |

`verify` (§7.4) is not a budget level — it is `release` inference with fact assertions inserted. It
is listed here because it is the third artifact a project builds, alongside `debug` and `release`.

All levels SHALL preserve identical program semantics. A level SHALL NOT change which programs
compile.

### 7.3 `verify` — facts as runtime assertions

> **A conformant implementation SHALL provide a `verify` build mode: full inference, plus a runtime
> assertion for every inferred fact.**

Every fact domain has a mechanical runtime predicate, so this is close to free to build and it is
what makes the model's central safety claim checkable rather than merely proved on paper.

| Fact | Assertion |
|---|---|
| `A = Unique` | A debug-only count word; assert it never exceeds 1 |
| `A ⊑ Borrowed` | Assert no second owning reference is created |
| `E = Region(r)` | Poison the arena on reset; assert no read of poisoned memory |
| `E ⊑ Caller` | Assert not reachable from any static root at return |
| `T = Isolated` | Assert accessing thread id equals creating thread id |
| `T ⊑ Transferred` | An ownership token; assert no two tasks hold it simultaneously |
| `C = Acyclic` | Periodic reachability check over values inferred acyclic |
| Tier T0 / T1 | Assert no access after frame or region exit |

Without this, a bug in a transfer function produces a **silently wrong binary** — a use-after-free
in production months later, with no path back to the analysis that caused it. With it, the same bug
is an assertion failure in CI, on the value whose fact was wrong.

`verify` is stronger than running under a memory sanitiser, which can only catch a fact violation
that *happens* to corrupt memory on that particular run. `verify` catches the violation itself.

Assertions, count words, ownership tokens and arena poisoning appear only in this mode and never in
`release`. `verify` builds are slow and use more memory; that is the correct trade for a mode whose
purpose is to be run by CI rather than by users.

*(New in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C3. Required at every conformance level.)*

### 7.4 Layout search is opt-in

Because layout search is the expensive half of the budget (§9) and its output is recorded in the
manifest, an implementation SHOULD make search a separate explicit step. The ordinary build reads
chosen layouts from the manifest; the search step rewrites them.

This is what keeps a "release" build fast enough to run in CI while still permitting an hours-long
autotuning pass on a schedule.

### 7.5 Levels are per module, not per build

§7.2 states levels as a property of a build. The target needs them as a property of a **module**:
an engine compiled once at `max` and reused, beside gameplay code rebuilt at `debug` on every
keystroke. A single per-build level forces a choice between a slow iteration loop and an
unoptimised engine, and neither is the trade anyone wants to make.

An implementation MAY assign a level per module. §7.1's guarantee is what makes it sound: every
level assigns a semantically valid tier to every value, so mixing them cannot change what a program
does. It changes *which* facts were proved, and that has consequences the rest of this section
states.

**A level boundary is an inference boundary.** A module compiled at `debug` proves nothing — its
budget is zero rounds and every value takes its ⊤ tier. A module analysed at `release` or `max`
therefore SHALL treat every function of a lower-level module exactly as it treats an `extern`
whose contract is undeclared: with the conservative default of FFI §1, and never with facts the
lower-level module did not compute. **An implementation that reads summaries across a level
boundary without this rule produces a value whose tier rests on an analysis that never ran**, which
is the one failure mode SPEC §1's invariant does not survive.

The direction is asymmetric and only one way is safe. Raising a module's level can only refine
facts, so a caller compiled against the conservative assumption stays correct; lowering it discards
facts a caller may already rest on. An implementation SHALL therefore invalidate every module that
depends on a module whose level falls, exactly as INFERENCE §9 invalidates the reverse-reachable
set of an edited function. **The level is part of the cache key**, alongside the body hash and the
callee summaries.

**Layout is not per module.** A type has one layout in every module that uses it: two modules
disagreeing about a field's offset is a miscompile, not a lost optimisation. Layout selection
(§7.4, LAYOUT §7.2) is therefore a property of the module that *declares* the type, is recorded in
the manifest, and is read from there by every other module regardless of that module's level. A
module at `debug` that allocates a type declared at `max` allocates the `max` layout.

**`verify` is not per module.** §7.3's assertions replace the allocator, and an implementation
that swaps allocators has to swap both ends together: an object allocated by the verifying
allocator and released by the ordinary one, or the reverse, is a spurious violation report at best.
`verify` is a property of the whole artifact.

**The manifest SHALL record each module's level.** Without it a diff is unreadable in exactly the
case the feature creates: dropping one module from `max` to `debug` moves every tier in it, and
§6.3 would report several hundred regressions where one line — the level changed — is the whole
explanation. A record whose module was compiled at a different level from the baseline's SHALL be
reported as *not comparable*, not as a regression. This is the same rule §9 states for a manifest
produced under a truncated budget, and for the same reason: the two runs did not ask the same
question.

---

## 8 · Representation

### 8.1 Handles

**No raw interior pointer SHALL escape the compiler's control.** References in AIF are *handles* —
opaque, resolvable, and, critically, **relocatable**.

This is the enabling condition for everything in §9 and for §8.3. It is also the one place AIF
pays a cost C does not: one extra add per dereference when the base register is live, and worse if
a real indirection table is required. Hot loops resolve the base once, which mostly amortises it.

### 8.2 The compiler owns layout

Because no interior pointer escapes, physical representation is the compiler's property, the way
storage is a database's property. The layout optimizer MAY choose:

- field order and padding
- array-of-structs vs. struct-of-arrays vs. AoSoA at several widths
- hot/cold field splitting
- bit-packing widths for range-known integers
- handle widths

per type, per access pattern, and per target.

### 8.3 The static region

*(Reworked in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C5. v1.1 specified a build-time heap snapshot,
justified by handles making pointer relocation trivial. That justification is true and beside the
point: relocation was never the hard part of build-time initialisation.)*

An implementation MAY execute **provably pure and deterministic** initialisation at build time,
into a dedicated **static region**, and embed that region in the binary.

Two properties make this far simpler than a heap snapshot:

- A region is already a contiguous byte block with no internal freeing, and handles inside it are
  region-relative offsets. So the artifact is *just bytes* — emitted as a binary section, loaded
  with one `mmap`. There is no object graph to walk and nothing to relocate, not because relocation
  is cheap but because there is nothing to relocate.
- Initialisation is **partitioned by purity** rather than attempted wholesale. Pure, deterministic
  initialisers bake; anything touching the environment, the clock, or the filesystem runs at
  startup as normal. The FFI contract vocabulary ([FFI.md](FFI.md) §5.3) already supplies most of
  the classification.

An implementation that bakes SHALL report the partition:

```
static-region   1.8 MB · 43 of 51 initialisers baked
  deferred      Config.load (reads environment) · Log.open (opens file) · 6 more
```

**The claim this supports** is not a fixed startup number. It is that *startup cost falls in
proportion to the pure fraction of initialisation, and the compiler tells you what that fraction
is.* For a CLI with large static tables that is near-total; for a server that opens sockets at
init it is near-nothing. BENCHMARKS §4.2's startup row is restated accordingly.

This is permission, not requirement, and is an AIF-3 feature (§11).

---

### 8.4 Views — slices and element references

*(Added in 1.2 after [TODO.md](../implementation/ROADMAP.md) B10. A slice is an interior pointer into a collection, and
§8.1 forbids those escaping. The concern was that bounding a view's lifetime would force AIF to
name a concept it exists to avoid — a borrow with an explicit lifetime. **It does not.** Views need
no new machinery: escape, handles and bounds checks already present are sufficient.)*

A **view** is a reference to part of a collection: a slice `a[2..8]`, or a reference to a single
element `a[i]`.

> **A view SHALL be represented as `(handle, offset, length)` — the collection's identity plus a
> range. It SHALL NOT hold an interior address.**

#### Lifetime, without lifetimes

A view must not outlive the collection it views. AIF gets this from the escape lattice it already
has, with no annotation:

```
E-VIEW    v is a view of c    ⟹    E(c) ⊒ E(v)
```

A view that escapes to the caller forces the *collection* to escape to the caller.

This inverts Rust's construction, and the inversion is the whole point:

| | A view outliving its collection |
|---|---|
| Rust | The borrow checker proves it cannot. Violation is a **compile error**. |
| **AIF** | The collection's escape rises to match. The collection **sinks a tier**. Compilation succeeds. |

That is SPEC §1's invariant applied to views. A long-lived slice does not need to be rejected; it
needs the collection to be T2 instead of T1. The programmer writes nothing, and the cost appears in
the manifest.

**Where that cost is unacceptable, `pin` makes it an error.** A collection pinned T1 whose tier a
*converged* analysis says must rise fails compilation and names the escaping view (§5.4.1). So the
default is permissive and visible, and strictness is available per value — you are not obliged to
discover a frame-loop regression from a profiler.

#### Invalidation, without a borrow checker

The classic hazard — take a slice, grow the collection, reallocation strands the slice — **cannot
occur**, because the view holds the collection's *identity*, not its buffer address. Reallocation
moves the buffer; the handle still resolves. This is the same property that makes §8.3's static
region relocation-free, applied to a different problem.

What remains is a *bounds* question, not a memory-safety one: a view whose range exceeds the
collection's current length after removal. That SHALL be a bounds violation, checked like any other
element access. **A stale view reads a bounds error, never freed memory.**

#### Overlapping mutable views are permitted

Rust forbids two overlapping `&mut` slices because its safety property includes no-aliasing. AIF's
safety property is narrower — no use-after-free and no data race — and neither is threatened by two
views of one collection in one task. Concurrent access is governed by the `T` domain as usual.

**This is an ergonomic gain over Rust, not a concession**: the pattern that requires `split_at_mut`
and its relatives is simply expressible.

#### Element references are views too — the deep consequence

Under SoA (§8.2), **an element does not exist as a contiguous object.** A `Particle` in an
SoA-lowered collection is twelve values in twelve separate arrays; there is no address that denotes
it.

So a reference to a single element is not a pointer and cannot be one. It is `(handle, index)`, and
field access resolves through the chosen layout to `field_array[index]`.

This is the sharpest consequence of "the compiler owns physical layout" (§11 item 5), and it is why
handles are load-bearing rather than a stylistic preference: **layout freedom and raw interior
pointers are mutually exclusive.** A language that lets you take `&collection[i]` as a machine
pointer has already promised AoS.

#### Cost, stated plainly

- A view is three words rather than two. An implementation MAY pack `offset`/`length` or narrow the
  handle where the collection's size permits.
- Each access resolves a handle (§8.1's one add, when the base is live) plus a bounds check. Hot
  loops resolve the base once, and the bounds check is one an array access pays regardless.
- **A view of an SoA collection is not contiguous**, so it cannot be handed to C as a buffer. That
  is the ordinary FFI case: non-C-compatible layout forces a copy (FFI §3), and the copy cost is
  already in the layout objective via `MarshalCost` (LAYOUT §5.4). Views, SoA and FFI compose
  through rules that already exist.

## 9 · The budget rule

> **The optimisation budget SHALL be allocated in proportion to measured opportunity. Where layout
> opportunity exists, it SHALL be prioritised over lifetime proving.**

*(Changed in 1.2. v1.1 froze "approximately 80/20" as normative. That is measurably wrong for a
large class of programs — see below — and it was the one place the specification was confidently
incorrect.)*

The arithmetic behind favouring layout is unchanged and still right: a wrong lifetime decision costs
a reference-count operation (1–2 cycles, most elided anyway); a wrong layout decision costs a cache
miss (200–300 cycles). Two orders of magnitude, in layout's favour — **when there is a layout
decision to make.**

**Often there is not.** [RESULTS-L1.md](../evidence/RESULTS-L1-layout.md) measured layout opportunity across six
programs:

| Program shape | Traversals | Layout benefit |
|---|---:|---:|
| Particle system, ECS world, frame loop | 3–9 | 3.96×–11.58× |
| **The Prismio compiler** | **0** | **1.00×** |

The compiler walks pointer-linked AST nodes and has *zero* collection traversals. Spending 80% of
its budget on layout search would produce nothing at all. That is not an edge case — it is the shape
of compilers, interpreters, UI frameworks, business logic and graph algorithms, i.e. most non-numeric
code, and a general-purpose language gets both shapes.

**The allocation SHALL therefore be derived, not fixed.** The static access profile (LAYOUT §2) is
cheap and reports traversal count *before* any budget is committed, so an implementation can see
whether the opportunity exists. A program with no traversals SHOULD spend approximately none of its
budget on layout search.

80/20 remains a reasonable **default for traversal-rich programs**. It is not a constant of nature
and it is no longer normative.

### 9.1 Layout search

The layout optimizer SHALL use a cost-driven search rather than exhaustive enumeration or fixed
heuristics. It generates candidate representations, scores them under a cost model, and selects
the highest-scoring candidate found within budget.

The cost model MAY consider cache locality, memory footprint, allocation behaviour, ownership
facts, lifetime facts, declared workload, SIMD opportunity, false sharing, and pointer indirection.

Search MAY terminate early when further exploration is unlikely to improve the score. Candidate
evaluation MAY run in parallel.

**Determinism obligation.** Early termination and parallel evaluation SHALL NOT make the result
depend on timing or scheduling. Specifically: the termination condition SHALL be a function of the
candidates examined, not of elapsed time; and ties in the score SHALL be broken by a deterministic
total order on candidates. See INFERENCE §5.4, which states the same obligation for the fact
solver and explains why it is easy to violate by accident.

The search space, the scoring function, and the exploration heuristics are implementation-defined
and MAY change between compiler releases without affecting language semantics.

### 9.2 Where the solver gives up: guards, not speculation

*(Reworked in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C6.)*

Where inference cannot prove a value cheap, an implementation MAY assign the conservative tier and
**specialise the path** rather than the tier:

```
T3 assigned (the header exists)
    if (rc == 1)  { mutate in place }      -- the fast path the solver suspected
    else          { copy }                 -- the general path
```

This is the standard copy-on-write check, and Perceus already does exactly it for drop-reuse.

**An implementation SHALL NOT speculate on a tier with a deoptimisation path.** Deopt would require
materialising a count header on an object compiled without one and updating every reference to it.
Handles make that possible in AIF where it is impossible elsewhere — but it needs deopt metadata,
state mapping and on-stack replacement to buy what a predictable branch buys, and the branch does
not risk being wrong.

The headline property is unaffected: **as the compile budget rises, the solver proves uniqueness
statically and deletes the guard.** Compile budget still literally buys the removal of runtime
checks. The number of guards in the binary SHALL fall monotonically as the budget rises, and an
implementation SHALL report the count in the manifest so that the trend is observable.

Cost: a value that a speculative design would have made T2 is T3 here, so it carries a count word.
One word of footprint against an entire subsystem.

---

## 10 · Boundaries

### 10.1 FFI

A foreign-function interface boundary SHALL constitute an **ownership proof barrier**.

- Immediately before entering foreign code, the implementation SHALL freeze ownership facts for all
  values the call may observe or modify, and SHALL resolve their handles to C-compatible pointers
  with a C-compatible layout. This may require a copy.
- Facts for unrelated values SHALL remain valid.
- On return, the implementation SHALL invalidate only those facts the foreign execution may have
  affected, and SHALL resume inference from the affected dependency subgraph.
- An implementation MAY invalidate more conservatively when precise attribution is not possible.

An FFI boundary SHALL NOT alter program semantics. Its only effect is to limit optimisation until
facts are re-established.

Marshalling rules, the contract vocabulary an `extern` declaration carries, and the precise
condition under which a copy becomes mandatory are specified in [FFI.md](FFI.md). In summary: a
copy is mandatory exactly when the value's chosen layout is not C-compatible, which the compiler
always knows because it chose the layout.

**The FFI boundary is the one place in AIF where being wrong is unsafe rather than slow.** An
`extern` declaration's ownership contract describes opaque foreign code and cannot be verified; it
is a trusted assertion. Every other failure in this specification costs performance. FFI §1 states
the mitigations, all of which are required.

### 10.2 Library distribution

The canonical distributable form of a Prismio library SHALL be **PIR** (Prism Semantic IR).

PIR SHALL retain everything whole-program AIF requires: ownership relationships, generic
information, layout candidates, and optimisation metadata — sufficient for a consuming compiler to
run full inference, ownership monomorphization, and layout search as though the library had been
compiled together with the application.

The consuming compiler SHALL merge application PIR with all dependency PIR **before** inference
begins, and SHALL lower to the backend only after whole-program optimisation completes.

An implementation MAY additionally emit object files or native libraries for interoperability and
tooling. Those are not canonical and MAY reduce optimisation opportunity.

PIR SHALL be versioned and forward-compatible across compiler releases, and its emission SHALL be
deterministic. The content model, merge rules, sealing, and the stability guarantee are specified
in [PIR.md](PIR.md).

The consequence, stated plainly: **whole-program monomorphization is incompatible with conventional
dynamic linking.** Shipping IR is the answer, and it constrains the ecosystem from day one — PIR §8
enumerates the costs, of which the sharpest is that a security patch to a widely used library
requires recompiling every dependent binary rather than replacing one shared object. PIR §9
specifies the per-boundary escape hatch.

PIR carries full function bodies, not summaries, because ownership contexts are discovered at call
sites and a library author cannot enumerate the contexts their consumers will produce. Shipping a
Prismio library therefore means shipping something functionally equivalent to source; PIR §5
specifies sealing for code that cannot.

---

## 11 · Conformance boundary

### 11.0 Conformance levels

*(New in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C9. A specification substantially larger than any
implementation of it calcifies into something nobody can build. Levels are the antidote: an
implementation states its level, and the manifest records it.)*

**Required at every level** — these are the model's identity and are not graded:

the invariant (§1) · the T0–T4 ladder and its ordering · tier is never a source-level type ·
the manifest (§6) · two-speed compilation (§7.1) · `verify` mode (§7.3) · pipeline determinism ·
deterministic RAII on T0–T2

| | **AIF-1 · Core** | **AIF-2 · Optimising** | **AIF-3 · Full** |
|---|---|---|---|
| Inference | escape + aliasing | + thread, cyclicity | + full context discovery |
| Contexts | `⊤` only | discovered; graded specialisation | + raised caps |
| Layout | declaration order, AoS | search, static profile | + `workload` autotuning, empirical validation |
| Arenas | none — T1 is the enclosing scope | cost-placed | + `region` pinning |
| T3 | naive counting | elision, reuse, fast-path guards (§9.2) | same |
| T4b | leak-and-report | collector | collector |
| Startup | ordinary | ordinary | static region (§8.3) |
| Distribution | source | source | PIR |
| Concurrency | none — `T` is vacuous | none | full |

**AIF-1 is a real memory model**, not a stub: no GC, no ARC tax, deterministic destruction, a cost
manifest, and a verify mode. It is better than the status quo for a large class of programs and is
buildable by one person. AIF-2 is where the performance thesis is actually tested. AIF-3 is the
model as specified below.

An implementation SHALL declare its level and SHALL NOT claim a level whose requirements it does
not meet. A manifest SHALL record the level that produced it.

### Frozen — normative

1. **The invariant.** Inference failure degrades performance, never correctness, never compilation.
2. **The five-tier ladder** T0–T4 and its ordering. Every abstract value carries exactly one tier.
   T4's sub-classes are a codegen distinction, not a sixth tier.
3. **Tier is never a source-level type.** No tier in a signature, no API versioned by one.
4. **Tier is a property of `⟨site × ownership context⟩`.** The *analysis* is context-sensitive. How
   an implementation realises that in generated code is **not** constrained — body duplication is
   one strategy among three (INFERENCE §7). *(Narrowed in 1.2; v1.1 froze duplication itself, which
   made binary bloat an existential risk to the specification rather than to one optimisation.)*
5. **The compiler owns physical layout.** No raw interior pointer escapes; references are handles;
   data stays relocatable.
6. **The budget rule.** Layout search is prioritised over lifetime proving, ≈80/20.
7. **Exactly four annotations** — `unique`, `region`, `workload`, `pin`. All optional, none viral,
   and **all assertions rather than directives** (§5.0.1): the compiler verifies each and may
   refuse it. Deleting all annotations SHALL NOT change observable behaviour. A wrong *axiom*
   (`unique`, `region`) is a warning and is discarded; a *refuted* `pin` is a compile error
   (§5.4.1) and an *unproven* one is a warning (§5.4.2). §5.0 argues the set is a complete basis
   rather than an arbitrary four. *(Item corrected in 1.2.1: it read "all warning-not-error", which
   1.2's own §5.4.1 had already contradicted.)*
8. **The tier manifest.** Every release build emits one; CI diffs it; a regression fails the gate,
   never the compile. A diff carries a minimal cause (§6.3).
9. **Two-speed compilation.** A zero-analysis build exists and is behaviourally identical, and a
   `verify` build asserts every inferred fact at runtime (§7.3).
10. **Affine references and isolation concurrency.** No shared mutable heap; no atomic counts on
    the common path. The requirement the analysis actually depends on is weaker than full value
    semantics: **creating a second owning reference SHALL be a syntactically identifiable event.**
    Affine references with checked moves satisfy this, and are what `unique`'s completeness
    argument rests on (INFERENCE §8.2). Value semantics is a sufficient condition, not a necessary
    one. *(Corrected in 1.1; v1.0 justified this by "aliasing is unrepresentable," which is
    stronger than anything downstream needs and is not what implementations do.)*
11. **Deterministic destruction (RAII) on T0–T2.** Destructors SHALL run on **every** path that
    leaves a scope, including error paths and partially-constructed values. Which mechanism carries
    that is a language decision AIF does not make, but the two differ in cost: with `Result`-style
    returns an error exit is ordinary control flow and needs nothing extra, whereas with unwinding
    **every call site becomes a potential scope exit**, multiplying drop points and constraining
    T1/T2 codegen. **AIF therefore recommends `Result`-style propagation** — not for ergonomics, but
    because it keeps the number of drop edges proportional to the source rather than to the call
    graph. *(Added in 1.2; v1.1 said "every scope exit" without saying what counts as one.)*
12. **Determinism of the whole pipeline.** Inference and layout results SHALL be identical
    regardless of scheduling order, processor count, or wall-clock timing. *(New in 1.1; v1.0
    required it of the solver but not of layout search, and specified budgets in a way that
    silently violated it — see INFERENCE §5.4.)*

### Resolved in 1.1 — was open in v1.0

**All eight of v1.0's open items are now specified.** What remains open below is either a
measurement question or a governance question — no structural decision is outstanding.

| v1.0 open item | Where it is now specified |
|---|---|
| Inference engine decision procedure | [INFERENCE.md](INFERENCE.md) §§2–6 |
| Monomorphization dedup | [INFERENCE.md](INFERENCE.md) §7 — three layers, mask / semantic / structural |
| Workload declaration | [LAYOUT.md](LAYOUT.md) §3 — executable `setup`/`measure`/`repeat` form |
| The layout search space and cost model | [LAYOUT.md](LAYOUT.md) §§5–7 — structured candidates, cycle-cost scoring, coordinate descent |
| The T4 cycle collector | [CYCLES.md](CYCLES.md) — trial deletion over cyclic edges only |
| FFI freeze semantics and marshalling | [FFI.md](FFI.md) — C-compatible layout, contract vocabulary, invalidation |
| IR distribution | [PIR.md](PIR.md) — content model, merging, sealing, stability |
| Four-annotation governance | §11 governance rules below |

### Open — by descending risk

**No structural decision is outstanding.** Everything below is a measurement question or a policy
question. Nothing on this list can invalidate the specification — 1.2's C1 and C9 were specifically
about removing the two entries that could.

1. **The tier distribution itself.** The whole performance thesis rests on typical code landing
   overwhelmingly at T0–T2, and nobody has measured it. BENCHMARKS H1, available at GAPS Level 0
   before any codegen work. This is the cheapest way to falsify the model and it should be run
   first.
2. **Cost-model constants** — `Θ_stack`, and LAYOUT §4's machine model, especially the prefetch
   factor `π`. These need calibration, not argument; a wrong `π` systematically mis-ranks AoS
   against SoA, which is the largest single layout decision.
3. **The security-patch model.** [PIR.md](PIR.md) §8: patching a library means recompiling
   dependents. PIR §9 turns this from a coordination problem into a compute problem — self-rebuilding
   binaries, manifest-driven fast rebuild, consumer-selectable dynamic boundaries — which is a real
   answer and not a complete one. *(Demoted in 1.2; it was #2 and unaddressed.)* Still the ecosystem
   consequence with the least precedent.
4. **Specialisation strategy selection, measured.** INFERENCE §7 selects among three strategies by
   the ownership-divergence ratio `δ`. Whether `δ` separates functions cleanly in real code is
   unmeasured. *(Demoted in 1.2: a bad result now costs one strategy on some functions rather than
   the specification — see C1, C2.)*
5. **The static-versus-workload gap.** LAYOUT §1 argues the workload buys frequencies, not
   structure, and that a build with no workload therefore loses little. That argument is untested
   and it is what keeps `workload` optional. LAYOUT §10.4 states the experiment.
6. **Collector tuning** — `Θ_buffer`, `K`, and the cyclic-skeleton size distribution.
   [CYCLES.md](CYCLES.md) §10; measurable before the collector is written.
7. **The FFI trust surface in practice.** FFI §1 accepts that contracts are unverifiable, matching
   Rust and Swift. Whether the manifest's trust-surface count is enough to keep it small is a
   question about people, not about the design.
8. **Whether four annotations hold.** Governance — but §5.0 now supplies an argument rather than an
   intention, which is what makes it defensible when someone asks for a fifth.

### Annotation governance

Every AIF annotation SHALL satisfy all of:

- It SHALL NOT alter program semantics.
- It SHALL remain optional.
- It SHALL communicate information the compiler cannot reliably infer.
- It SHALL provide measurable optimisation or predictability value.
- It SHALL NOT duplicate another annotation's purpose.

AIF SHALL prefer improving inference over adding annotations. Future revisions MAY add, change, or
remove standardised annotations with implementation experience as justification. Implementation-
specific experimental annotations MAY exist, SHALL be explicitly namespaced, and are not part of
AIF.

---

## 12 · What this model gives up *(informative)*

Stated plainly, because a model that hides this much has real costs and pretending otherwise makes
the rest untrustworthy.

- **Cost predictability** is the structural weakness. A small edit can move a value from T1 to T3
  and change its cost non-locally. The manifest (§6) converts this from invisible to reviewable —
  it does not eliminate it.
- **Compile time.** Release builds may run for minutes to hours. Two-speed compilation makes this
  survivable at the cost of a testing obligation: the fast binary and the binary you develop
  against are different artifacts and must be behaviourally identical.
- **Binary size.** Ownership monomorphization multiplies code. This is how C++ templates go wrong.
- **Dynamic linking.** Whole-program analysis is incompatible with it; PIR is the answer, and it is
  an ecosystem commitment made on day one.
- **FFI is not seamless.** The freeze boundary has a real marshalling cost.
- **Dependence on a declared workload.** No workload means no search, which means heuristics. That
  is real developer effort — arguably comparable to Rust annotations, just a different and more
  transferable kind of work. It is the honest rebuttal to "zero annotation burden."
- **No raw low-level control**, by design. Kernels and allocators are out of scope.
- **It is a design, not a compiler.** Everything it compares itself against has shipped for years.
