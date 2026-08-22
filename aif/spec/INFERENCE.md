# AIF — The Inference Engine

**The decision procedure.** AIF v1.0 (as PMM) listed this as the highest-risk open item: *"the
keystone, and still unspecified: how it proves unique versus region-bound, what its give-up
condition is, and how the four annotations enter as axioms rather than hints. Everything else
assumes this works."* This document specifies it.

Companion to [SPEC.md](SPEC.md). Conformance language per SPEC §0.

**Contents**

1. [Architecture](#1--architecture)
2. [Fact domains](#2--fact-domains)
3. [The fact graph](#3--the-fact-graph)
4. [Transfer rules](#4--transfer-rules) — incl. §4.5 capture, §4.6 dispatch, §4.7 generics
5. [The fixed-point algorithm](#5--the-fixed-point-algorithm)
6. [Ownership contexts](#6--ownership-contexts)
7. [Monomorphization dedup](#7--monomorphization-dedup)
8. [Annotations as axioms and constraints](#8--annotations-as-axioms-and-constraints)
9. [Incrementality](#9--incrementality)
10. [Worked example](#10--worked-example)
11. [Known weaknesses](#11--known-weaknesses)

---

## 1 · Architecture

The engine is a set of independent **analysis modules** over one shared **fact graph**. Modules
never call each other and never depend on each other's internals; they read the graph and write
derived facts back into it. Iteration continues until no module can derive anything new (a
post-fixed point) or the budget is exhausted.

```
                    ┌──────────────────────────────┐
   PIR  ──build──▶  │        fact graph  G         │
   axioms ─seed──▶  │  nodes: abstract values      │
                    │  edges: flow / reachability  │
                    └───┬──────────────────────▲───┘
                        │ read                 │ join
             ┌──────────┴────┬────────┬────────┴──────┐
             ▼               ▼        ▼               ▼
        escape module   alias module  thread module  cyclicity module
             │               │        │               │
             └───────────────┴────────┴───────────────┘
                        round-synchronous iteration
                                  │
                         post-fixed point reached
                                  │
                                  ▼
                    tier assignment (SPEC §4.2)
                                  │
                                  ▼
                    layout search  ·  manifest emission
```

**Normative obligations on a module:**

- **M1.** A module SHALL communicate only through the fact graph.
- **M2.** A module's transfer function SHALL be **monotone** with respect to the product order on
  fact tuples. A non-monotone module breaks termination, uniqueness of the fixed point, and
  determinism simultaneously. This is the single most important obligation in this document.
- **M3.** A module SHALL be **sound in the ⊤ direction**: any fact it derives must remain true when
  any other fact rises. It may not derive a fact that depends on another fact being *low*.
- **M4.** Tier SHALL NOT be read by any module. Tier is derived once, after convergence
  (SPEC §4.2). A module that reads tier creates a cycle between the fact system and its own output
  and voids M2.

Modules: escape (§4.1), aliasing (§4.2), thread affinity (§4.3), cyclicity (§4.4). Closure capture
(§4.5), dynamic dispatch (§4.6) and generics (§4.7) add **no new module and no new lattice** — each
reduces to rules the existing modules already have, which is the strongest evidence available that
the four domains are the right four.

Layout search is **not** a module — it runs after convergence and consumes facts without producing
them.

---

## 2 · Fact domains

Each domain is a **join-semilattice of finite height**. Finite height is what removes the need for
widening operators and guarantees termination without any additional argument.

### 2.1 `E` — escape

The scope tree of a function (nested blocks, including every `region` block) is a tree. Escape
values are:

```
Region(s)   for each scope s,  ordered by nesting:  s inner  ⟹  Region(s) ⊏ Region(outer)
Caller      the value is reachable after the current activation returns
Global      the value is reachable from a static root, or from an unjoined task
```

with `Region(s) ⊏ Caller ⊏ Global` for every `s`.

**Join** of two `Region` values is their least common enclosing scope. Because scopes form a tree
and the tree has a root, every pair has a least upper bound, so this is a join-semilattice with top
`Global`. Height is bounded by (maximum scope nesting depth + 2).

The bottom element for a site `s` is `Region(defscope(s))` — the innermost scope containing the
allocation.

> **`Local` is not a separate value.** SPEC v1.0 treated stack-local and region-local as different
> kinds of fact. They are the same fact: T0 is the degenerate case of T1 where the region is the
> activation record. This collapse removes an entire analysis and is why the T0/T1 boundary is a
> *size* question (SPEC §4.2's `Θ_stack`), not an escape question.

### 2.2 `A` — aliasing

```
Unique  ⊏  Borrowed  ⊏  Shared
```

- **`Unique`** — exactly one reference exists, and it owns. Permits in-place mutation and
  drop-reuse.
- **`Borrowed`** — exactly one *owning* reference, plus zero or more borrows, none of which
  outlives the owner. Permits move and RAII; forbids in-place reuse while a borrow is live.
- **`Shared`** — two or more references whose relative lifetimes are not statically ordered.

Height 2.

### 2.3 `T` — thread affinity

```
Isolated  ⊏  Transferred  ⊏  CrossThread
```

- **`Isolated`** — never crosses a task boundary.
- **`Transferred`** — ownership moves between tasks, but only one task may reach it at a time.
- **`CrossThread`** — reachable from two or more tasks simultaneously.

Height 2.

`Transferred` is the tier that isolation-based concurrency exists to produce, and it is the reason
T3 can use a non-atomic counter: the transfer point itself is a synchronisation edge, so a
release/acquire pair there is sufficient and the counter never needs to be atomic. An
implementation SHALL emit that pair. Only `CrossThread` forces atomics.

### 2.4 `C` — cyclicity

```
Acyclic  ⊏  MaybeCyclic
```

Height 1. Derived rather than independently propagated — see §4.4.

### 2.5 `L` — lifetime determinacy *(derived)*

```
ScopeBound(s)  ⊏  OwnerBound  ⊏  Dynamic
```

`L` is **not independently inferred.** It is a function of `E` and `A`, computed once after
convergence, and it exists to name the deallocation obligation for codegen:

```
L =  ScopeBound(s)   if E = Region(s)          -- freed by arena reset at s exit
     OwnerBound      if A ⊑ Borrowed           -- freed when the single owner dies (RAII)
     Dynamic         otherwise                 -- freed when the count reaches zero
```

Because it is derived, `L` adds no inference power and appears in no transfer rule. SPEC §4.2's
tier clauses are stated over `E`, `A`, `T`, `C` only.

### 2.6 The product

`F = E × A × T × C`, ordered pointwise. Finite height ≤ (depth + 2) + 2 + 2 + 1.

Top `⊤ = ⟨Global, Shared, CrossThread, MaybeCyclic⟩` derives T4 by SPEC §4.2 — which is why
widening everything to `⊤` is always a legal answer, just a slow one.

---

## 3 · The fact graph

### 3.1 Nodes

One node per abstract value `⟨s, κ⟩` (SPEC §2.3), plus:

- one node per **parameter** of each `⟨f, κ⟩`, carrying that parameter's inbound facts;
- one node per **return position** of each `⟨f, κ⟩`;
- one node per **field** of each struct type, carrying the join of everything ever stored into it
  (field-sensitive, object-insensitive — see §11.1 for the precision this costs);
- one node per **static root**, permanently pinned at `⊤`.

### 3.2 Edges

A directed edge `m → n` labelled with a transfer function means "facts at `n` depend on facts at
`m`". Edges are created by the rules in §4 and are never removed during iteration.

### 3.3 Node ordering (normative)

Nodes SHALL carry a **deterministic total order**, defined as the lexicographic order on

```
( interned module id, byte offset of the defining span, node kind, context index )
```

where *context index* is the position of `κ` in the deterministically ordered context set of §6.2.
Every iteration order, tie-break, and budget cutoff in this document is defined against this order.
Without it, nothing below is deterministic.

---

## 4 · Transfer rules

Rules are stated over a small abstract IR. `⟦x⟧` is the node for the abstract value that `x`
denotes; `E(x)` is that node's escape fact, and so on. Every rule is of the form "raise a fact",
i.e. `⊒`, which is what makes every module monotone by construction (M2).

```
x = alloc τ            allocate
x = y                  move or copy of a reference
x = &y                 borrow
x.f = y                store into field
x = y.f                load from field
x = f(y₁ … yₙ)         call
return x               return
spawn f(y₁ … yₙ)       create a task
join t                 await a task
region r { … }         region block
```

### 4.1 Escape module

| # | Premise | Conclusion |
|---|---|---|
| E-ALLOC | `x = alloc τ` in scope `s` | `E(x) ⊒ Region(s)` |
| E-MOVE | `x = y`, `y` dead afterwards | `E(y) ⊒ E(x)` |
| E-COPY | `x = y`, `y` live afterwards | `E(y) ⊒ E(x)` |
| E-BORROW | `x = &y` | `E(y) ⊒ E(x)` |
| E-STORE | `x.f = y` | `E(y) ⊒ E(x)` and `E(field(τ,f)) ⊒ E(y)` |
| E-LOAD | `x = y.f` | `E(x) ⊒ E(field(τ,f))` |
| E-RETURN | `return x` | `E(x) ⊒ Caller` |
| E-CALL | `x = f(… yᵢ …)` | `E(yᵢ) ⊒ subst(summary_E(f@κ, paramᵢ))` |
| E-STATIC | `x` stored to a static root | `E(x) ⊒ Global` |
| E-SPAWN | `spawn f(… yᵢ …)`, task not joined on all paths before scope exit | `E(yᵢ) ⊒ Global` |
| E-SPAWN-J | `spawn f(… yᵢ …)`, joined on every path before scope `s` exits | `E(yᵢ) ⊒ Region(s)` |

`subst` translates a callee's summary escape into the caller's scope tree: `Caller` in the callee
becomes the call site's scope; `Global` stays `Global`; a callee-internal `Region` never escapes and
contributes nothing.

**E-SPAWN vs. E-SPAWN-J is where structured concurrency pays.** An unjoined task forces `Global`,
which forces T3/T4. A task joined inside the region keeps everything region-bound. This single
distinction determines whether concurrent code lands at T1 or T4, and it is why AIF wants
structured task scopes in the language.

### 4.2 Aliasing module

| # | Premise | Conclusion |
|---|---|---|
| A-ALLOC | `x = alloc τ` | `A(x) ⊒ Unique` |
| A-MOVE | `x = y`, `y` dead afterwards | nothing — a move creates no new reference |
| A-COPY | `x = y`, `y` live afterwards | `A(y) ⊒ Shared` |
| A-BORROW | `x = &y`, borrow does not outlive `y` | `A(y) ⊒ Borrowed` |
| A-BORROW-E | `x = &y`, borrow may outlive `y` | `A(y) ⊒ Shared` |
| A-STORE | `x.f = y` | `A(y) ⊒ A(x)` and `A(field(τ,f)) ⊒ A(y)` |
| A-LOAD | `x = y.f` | `A(x) ⊒ A(field(τ,f)) ⊔ Borrowed` |
| A-CALL | `x = f(… yᵢ …)` | `A(yᵢ) ⊒ summary_A(f@κ, paramᵢ)` |
| A-ESCAPE | `E(x) ⊒ Global` | `A(x) ⊒ Shared` |

A-STORE's first conclusion is the sharing-inheritance rule: **reachability from a shared root makes
you shared.** A-ESCAPE couples the modules: anything globally reachable is reachable more than once.

A-LOAD joins `Borrowed` because a load produces a second reference to the field's contents that the
load's consumer may hold. It rises no further than `Borrowed` on its own; A-COPY handles the case
where the loaded reference is duplicated.

### 4.3 Thread module

| # | Premise | Conclusion |
|---|---|---|
| T-DEFAULT | any node | `T ⊒ Isolated` |
| T-SPAWN-MOVE | `spawn f(… yᵢ …)`, `yᵢ` moved in and dead in the parent | `T(yᵢ) ⊒ Transferred` |
| T-SPAWN-SHARE | `spawn f(… yᵢ …)`, `yᵢ` still live in the parent | `T(yᵢ) ⊒ CrossThread` |
| T-REACH | `x` reachable from `y` (via E-STORE edges) | `T(x) ⊒ T(y)` |
| T-CALL | `x = f(… yᵢ …)` | `T(yᵢ) ⊒ summary_T(f@κ, paramᵢ)` |
| T-STATIC | `E(x) = Global` and the program creates any task | `T(x) ⊒ CrossThread` |

T-STATIC is deliberately blunt: a static root in a program with concurrency is assumed reachable
from every task. Refining it requires a global reachability analysis whose payoff is small, because
static mutable roots are rare in a value-semantics language.

### 4.4 Cyclicity module

Cyclicity is derived in two stages.

**Stage 1 — type level, computed once, before iteration.** Build the *type reference graph*: a node
per nominal type, an edge `τ → σ` when `τ` has a field that can reach a `σ` reference. Compute
SCCs. Define

```
TypeAcyclic(τ)  ⟺  τ's SCC is trivial and τ reaches no non-trivial SCC
```

**Stage 2 — value level, during iteration.**

| # | Premise | Conclusion |
|---|---|---|
| C-TYPE | `TypeAcyclic(type(x))` | `C(x) = Acyclic` (and no rule can raise it) |
| C-UNIQUE | `A(x) = Unique` | `C(x) = Acyclic` |
| C-OTHER | otherwise | `C(x) ⊒ MaybeCyclic` |

**C-UNIQUE is sound**: a cycle requires some node in it to be reachable by at least two distinct
references (its predecessor in the cycle, and whatever holds the cycle from outside). `Unique`
forbids the second. So uniqueness implies acyclicity, and the aliasing module does most of the
cyclicity module's work for it.

C-TYPE has priority over C-OTHER: a type-acyclic value can never be cyclic regardless of aliasing,
which is why most programs have a small T4b population — recursive reference-carrying types are a
minority of types.

> **Regions collect cycles for free.** A value with `E = Region(r)` is T1 by SPEC §4.2 regardless
> of `C`: the arena reset frees it whether or not it is part of a cycle. Cyclicity only matters for
> values that reach T3/T4, i.e. those that escaped every region. This is a second reason `region`
> is the highest-leverage annotation, and it is not stated anywhere in v1.0.

### 4.5 Closure capture

*(Added in 1.2. AIF does **not** require the language to have closures; it must say what the facts
do where it does.)*

A closure is a value with a compiler-synthesised record of its captured variables. **Capture is
therefore a store into that record**, and the store rules of §§4.1–4.2 apply unchanged:

| # | Premise | Conclusion |
|---|---|---|
| K-ALLOC | closure `f` created in scope `s` | `E(f) ⊒ Region(s)`, `A(f) ⊒ Unique` |
| K-CAPTURE-MOVE | `x` captured, and dead in the enclosing scope afterwards | `E(x) ⊒ E(f)`. `A` unchanged — a move creates no new reference |
| K-CAPTURE-REF | `x` captured and still live afterwards | `E(x) ⊒ E(f)` and `A(x) ⊒ Borrowed` |
| K-CAPTURE-SHARE | as above, and `f` may be invoked from two places, or `A(f) = Shared` | `A(x) ⊒ A(f)` |
| K-CALL | `f` invoked | the captured record is read; no fact rises |

**No new fact domain and no new lattice.** As with views (SPEC §8.4), the existing machinery
suffices — a closure is a container and its captures are its contents.

Three consequences worth stating, because they are where the populations actually change:

- **Non-escaping closures are free.** `map(|x| …)` passed to a callee that does not retain it keeps
  `E(f) = Region(s)`, so every capture stays region-bound and lands T0/T1. The common functional
  idiom costs nothing.
- **Escaping closures are the origin of T3.** A closure stored in a long-lived structure — an event
  handler on a widget, a registered callback — has `E(f) ⊒ Global`, so by A-ESCAPE every
  captured-by-reference value becomes `Shared`. **This is the mechanism by which genuine sharing
  arises in a language without explicit shared references**, and it is why
  [EVALUATION.md](../evidence/EVALUATION.md) §5 holds that the T3 population is unmeasurable until closures
  exist.
- **Move-capture SHOULD be inferred, not written.** Where a captured variable is dead in the
  enclosing scope after the closure is created, K-CAPTURE-MOVE applies and `A` stays `Unique`.
  Requiring a `move` keyword for this — as Rust does — would put the burden on the programmer for a
  fact the analysis already has. An implementation SHOULD default to move-capture whenever liveness
  permits it and SHOULD record the choice in the manifest.

### 4.6 Dynamic dispatch

*(Added in 1.2. Same scoping: AIF does not decide whether the language has interfaces.)*

A virtual call has no single callee, so §6.3's call-site context discovery has no single target.

**The key property is that the target set is bounded and known.** Whole-program analysis
(SPEC §10.2) sees every implementor, so unlike an FFI call — where the callee is genuinely opaque —
a virtual call's targets are enumerable. That difference is large: an FFI call must assume the
worst, a virtual call need only assume *the join over what actually exists*.

| # | Premise | Conclusion |
|---|---|---|
| D-MONO | the receiver's implementor is uniquely determined at this site | use that implementor's summary exactly — devirtualise |
| D-JOIN | otherwise | the effective summary is `⨆` over the summaries of all implementors reachable at this site |

An implementation SHALL attempt D-MONO before D-JOIN, and SHALL restrict the join to implementors
the receiver's points-to set can actually reach — not to every implementor of the interface.

**Cost, and how to see it.** A widely-implemented interface joins many summaries and its facts
converge toward `⊤`, so values crossing it sink. That is real and unavoidable, but it should not be
invisible: an implementation SHALL report polymorphic call sites in the manifest with their target
count.

```
poly  Renderer.submit@L88   14 targets   joined -> A=Shared, E=Global
```

A developer who sees that an interface has fourteen implementors and is sinking their hot path can
narrow the type, seal the hierarchy, or accept it — which is the same visibility principle the
manifest applies everywhere else.

### 4.7 Generics and ownership contexts

*(Added in 1.2, resolving TODO B12.)*

Type monomorphisation duplicates a body per type argument; ownership contexts (§6) would duplicate
it again per parameter mode. Naively these **multiply**.

They need not. §7.0.1's policy-parameter strategy applies *within* each type-specialised body: the
type is monomorphised, and ownership becomes a compile-time-constant argument inside it. **The
product collapses to a sum** — one body per type argument, each carrying an ownership policy the
backend may or may not choose to clone on.

Two notes:

- The relevant-parameter mask (§7.1) is computed **per type instantiation**, because it can differ:
  `Vec<Int>` and `Vec<Node>` need not have the same relevant parameters.
- Where `δ` is high enough that the monomorphise strategy is chosen, the multiplication returns for
  that function. That is the correct trade and it is bounded by the same budget-driven collapse
  (§7.4).

---

## 5 · The fixed-point algorithm

### 5.1 Iteration strategy (normative)

> **Iteration SHALL be round-synchronous (Jacobi-style) whenever the budget may truncate it. An
> implementation MAY use asynchronous worklist (Gauss–Seidel) iteration only when it runs to full
> convergence.**

The justification is in §5.4 and it is not optional: worklist iteration truncated by a budget
produces a schedule-dependent result, which violates SPEC §11 item 12.

Round-synchronous does not mean naive. **Semi-naive evaluation** — recomputing only nodes at least
one of whose predecessors changed in the previous round — has worklist-like cost with round-level
determinism, and is the recommended implementation.

### 5.2 The algorithm

```
INPUT   P        whole-program PIR
        Ax       annotation axioms (§8)
        B        budget, in ROUNDS
OUTPUT  Φ        a post-fixed point,  Node → E×A×T×C
        conv     whether the post-fixed point is the least one

 1  G  := build_fact_graph(P)                       -- §3
 2  Φ  := λn. ⊥(n)                                  -- ⊥(n) = ⟨Region(defscope(n)), Unique,
 3                                                  --         Isolated, Acyclic⟩
 4  Φ  := seed(Φ, Ax)                               -- §8; also marks cut edges
 5  Δ  := all nodes of G                            -- nodes to recompute this round
 6  r  := 0
 7
 8  while Δ ≠ ∅ and r < B:
 9      Φ' := Φ
10      for n in Δ, in node order (§3.3), independently:          -- parallel-safe
11          Φ'(n) := Φ(n) ⊔ ⨆ { transfer(m→n, Φ) | m ∈ preds(n) }
12      G  := G ∪ discover_contexts(Φ')             -- §6.3; monotone, deterministic
13      Δ  := { n | Φ'(n) ≠ Φ(n) }  ∪  succs(Δ) ∩ new_nodes
14      Φ  := Φ'
15      r  := r + 1
16
17  if Δ = ∅:
18      conv := true                                -- Φ = lfp(F); the precise answer
19  else:
20      conv := false
21      Φ := widen_and_close(Φ, Δ)                  -- §5.3 — MANDATORY
22
23  return Φ, conv
```

Note line 11 reads `Φ` (the previous round) and writes `Φ'`. That is what makes the loop body
order-independent and safely parallel.

### 5.3 The give-up condition — and why you cannot simply stop

This is the part v1.0 got wrong by omission. Its text read: *"If convergence cannot improve further
within the configured optimization budget, the compiler SHALL conservatively assign a
lower-performance tier while preserving semantic correctness."* That sentence assumes stopping is
conservative. **It is not.**

The iteration starts at `⊥` and ascends. An intermediate state `Φ_r` is a **pre-fixed point**
(`Φ_r ⊑ F(Φ_r)`), and it satisfies `Φ_r ⊑ lfp(F)` — it is *below* the true answer, meaning its
facts are **too optimistic**. Assigning tiers from a truncated iteration would hand a value T2 when
the unexplored rounds would have proved it Shared. That is a use-after-free, not a slowdown.

Soundness requires a **post-fixed point** (`F(Φ) ⊑ Φ`), because by Knaster–Tarski every post-fixed
point is above `lfp(F)`. So truncation SHALL be followed by:

```
widen_and_close(Φ, Δ):
    U := Δ  ∪  transitive_succs(Δ)        -- everything whose value may still be wrong
    for n in U:  Φ(n) := ⊤
    iterate §5.2 lines 8–15 with B = ∞, restricted to U ∪ succs(U)
    return Φ
```

This terminates quickly: `⊤` is absorbing, so no node in `U` can change again, and the closure only
has to push `⊤` outward one frontier at a time.

The result is a post-fixed point, hence sound, hence (by SPEC §4.3's monotonicity) yields tiers at
or above the true ones. **Correct, just slower.** That is the invariant of SPEC §1 discharged.

Two consequences worth stating:

- `U` is usually far smaller than `G`. A budget-exhausted build is not "everything becomes T4"; it
  is "the unresolved subgraph becomes T4". The manifest marks exactly those records
  `budget-exhausted` (SPEC §6.2), which is what makes a raised budget an informed decision.
- An implementation that *starts* at `⊤` and descends would make truncation trivially safe, but
  descending iteration over this system is not monotone and has no uniqueness guarantee. Ascending
  plus mandatory closure is the correct construction.

### 5.4 Determinism (normative)

> **The fact map `Φ`, the tier assignment, and the layout selection SHALL be identical for identical
> inputs, regardless of scheduling order, processor count, or wall-clock timing.**

This holds if and only if all four of the following are true. Each has been violated by a real
compiler at some point, and the first two were violated by AIF v1.0's own text.

1. **The budget SHALL be counted in rounds, not in elapsed time and not in individual transfer
   applications.** A time-based budget makes the output a function of machine load. A
   step-based budget on an asynchronous worklist makes the truncation point a function of thread
   interleaving — which nodes are still in `Δ` differs by schedule, so `U` differs, so `Φ` differs.
   Rounds are the only cutoff that is a pure function of the program.

2. **Iteration SHALL be round-synchronous while a truncating budget is in effect** (§5.1). At full
   convergence, order is irrelevant — Kleene's theorem gives the same `lfp(F)` from any fair
   schedule — so an implementation may use whatever schedule it likes *provided it does not stop
   early*.

3. **Every join SHALL be commutative, associative and idempotent**, which holds for all four
   domains by §2, so concurrent joins into the same node commute and the parallel loop at line 10
   is safe without ordering.

4. **Every discretionary choice SHALL be broken by the node order of §3.3**: context discovery
   order (§6.3), context-cap victim selection (§6.4), dedup collapse order (§7.4), and layout
   candidate ties (SPEC §9.1).

**Testing obligation.** An implementation SHALL provide a mode that runs inference twice — once
single-threaded, once with maximum parallelism — and compares the manifests byte-for-byte. See
BENCHMARKS §6.

### 5.5 Termination

Every domain has finite height `h`, the graph has `|N|` nodes bounded by §6.4's context cap, and
every transfer is monotone (M2). The state `Φ` therefore ascends in a lattice of height `h·|N|`,
so the loop terminates in at most `h·|N|` rounds with or without a budget. No widening operator is
required.

### 5.6 Minimal cause

*(New in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C4.)* SPEC §6.3 requires a manifest diff to report
why a tier changed. The derivation is already in the graph; this is how to read it back out.

For a fact `f` at node `n` holding value `v`, the **maximal contributors** are the predecessors `m`
whose `transfer(m→n, Φ)` equals `v` — the ones that actually set it, as opposed to those that
merely did not contradict it. Walking backward through maximal contributors yields a witness path
from a root cause to `n`; the shortest such path is the **minimal cause**.

```
minimal_cause(n, f):
    frontier := {n},  seen := {n}
    while frontier ≠ ∅:
        m := pop in node order (§3.3)
        if m is a root of f (an axiom, a static root, or an allocation): return path to m
        for p in preds(m) with transfer(p→m, Φ) = Φ(m).f  and  p ∉ seen:
            record parent[p] := m ;  seen ∪= {p} ;  frontier ∪= {p}
```

Breadth-first over a DAG, so it is linear in the visited subgraph and the first root reached gives
the shortest path. Practical depth is small — facts rarely propagate through more than a handful of
stores before hitting an allocation or a static root.

**Repairs** fall out of the path: breaking any edge on it restores the tier, and each edge carries
the rule that fired, so the cost of breaking it is known. An implementation SHOULD rank repairs by
that cost and SHOULD list unsound repairs as rejected with a reason (SPEC §6.3's third line) —
knowing which fix cannot work is worth as much as knowing which can.

**Requirement.** The derivation DAG SHALL be retained through tier assignment in any build that
emits a manifest. This is the only cost of §5.6 and it is memory, not time.

### 5.7 Optimisation levels

Levels are budget settings on the same algorithm (SPEC §7.2), never different algorithms.

| Level | `B` (rounds) | Context cap `Κ` | Layout |
|---|---|---|---|
| `debug` | 0 | 1 (the ⊤ context only) | none |
| `release` | bounded default | bounded default | static cost model |
| `max` | ∞ (run to convergence) | raised | full search |

`B = 0` means the loop body never runs, `Δ` is non-empty, `widen_and_close` sets everything to `⊤`,
and every value lands at T4. Correct, and produced in milliseconds. This is the zero-analysis build
of SPEC §7.1, and it falls out of the algorithm rather than being a separate code path — which is
what makes "behaviourally identical" credible rather than aspirational.

---

## 6 · Ownership contexts

### 6.1 What a context is

Per SPEC §2.2, `Ctx(f) = ⟨m₁ … mₙ⟩` with `mᵢ ∈ {Unique, Borrowed, Shared}` over the
reference-carrying parameters of `f`.

The purpose is to delete the **join at the call boundary**. Without contexts, one caller passing a
shared value forces the callee's parameter to `Shared` for every caller, forever — and that single
effect is the origin of most of the T3/T4 population. With contexts, `parse(buf)` called with a
`Unique` buffer gets a body that mutates in place and reclaims at exit; the same source called with
a `Shared` buffer gets a copy-on-write body.

What remains at T3/T4 afterwards is only values whose aliasing genuinely varies *within a single
execution* — a far smaller set than values whose aliasing varies across call sites.

### 6.2 Context ordering

The context set of a function SHALL be totally ordered by the lexicographic order on
`⟨m₁ … mₙ⟩` with `Unique < Borrowed < Shared`. The *context index* used in §3.3 is the position in
this order. This makes context identity independent of discovery order.

### 6.3 Discovery (demand-driven)

Contexts are not enumerated. They are discovered:

1. Roots — `main`, exported entry points, and anything reachable only via FFI — are instantiated at
   the `⊤` context `⟨Shared … Shared⟩`, because their callers are unknown.
2. At every call site `x = f(y₁ … yₙ)`, form `κ' = ⟨A(y₁) … A(yₙ)⟩` from the *current* round's
   facts. If `f@κ'` is not in `G`, instantiate it (line 12 of §5.2).
3. Instantiation adds nodes; it never removes or modifies them, so the graph grows monotonically
   and §5.5's termination argument is unaffected.

Because `A(yᵢ)` can only rise across rounds, a call site can migrate from a cheaper context to a
more expensive one but never back. Bodies for contexts that end up with no live call site are
discarded before codegen.

### 6.4 The context cap

`3ⁿ` is a real bound and `n` is not always small. Two caps:

- **Per-function cap `Κ`.** Once `f` has `Κ` contexts, additional call sites route to `f@⊤`.
- **Global cap** on total instantiated bodies, as a multiple of the un-specialised program size.

Victim selection when a cap binds SHALL be deterministic: route the call sites that appear *latest*
in node order (§3.3) to `⊤`. Capping costs performance at those sites and nothing else.

---

## 7 · Specialisation strategy and dedup

*(Reworked in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C1, C2. v1.1 required one body per context and
tried to control the resulting `3ⁿ` with a cap, which made binary bloat existential and produced the
`⊤`-context cliff of §11.5.)*

SPEC §2.3 requires the *analysis* to be context-sensitive. It does **not** require one compiled body
per context. This section chooses how context-dependent behaviour is realised, per function, by
cost.

### 7.0 The ownership-divergence ratio

For a function `f`, let `δ(f)` be the fraction of `f`'s emitted operations that differ across its
contexts.

`δ` is nearly free: §7.1 already analyses `f` under each parameter mode to build the
relevant-parameter mask, and `δ` is the diff that analysis already produced, counted rather than
discarded.

### 7.0.1 Three strategies

| `δ(f)` | Strategy | Emitted |
|---|---|---|
| **High** — ownership pervades the body; in-place mutation versus copy-on-write changes the algorithm | **Monomorphise** | One body per surviving context |
| **Low** — ownership affects only allocation, drop and count sites | **Policy parameter** | One body, with a compile-time-constant policy argument; ownership-dependent operations branch on it |
| **Cold** — low call frequency in the profile | **Shared** | One body at `⊤`; no specialisation |

The middle strategy is the important one. A body emitted once with a constant policy argument lets
the **backend's existing function-specialisation pass** decide whether cloning pays, with a cost
model already built and tuned for that question; constant propagation then deletes the dead policy
branches in whichever clones it creates. AIF stops making the code-size decision and delegates it to
the layer that has the information.

Two consequences:

- **Code size is bounded by construction**, not by a cap. Bodies are emitted once unless duplication
  is affirmatively worth it.
- **The `⊤` cliff becomes a slope.** A function that does not merit full specialisation still gets
  the policy-parameter form, which is most of the benefit at a fraction of the size.

Cost of the policy-parameter form when the backend declines to clone: a branch on a constant, which
folds away under inlining and is correctly predicted when it does not. Strictly better than the
cliff it replaces.

Strategy selection is a function of `δ` and the profile, both deterministic, with ties broken by
node order (§3.3). The chosen strategy SHALL be recorded in the manifest.

### 7.0.2 Dedup still applies

Where the monomorphise strategy is chosen, the three dedup layers below apply to it. Specialisation
SHALL be demand-driven, never unconditional.

### 7.1 Layer 1 — the relevant-parameter mask *(pre-instantiation, cheapest, does the most work)*

For each function `f`, compute the set of parameters whose mode can influence any derived fact,
tier, layout, drop placement, or synchronisation inside `f`. Call the rest **irrelevant**.

A parameter is irrelevant when its mode reaches no rule conclusion that changes an output — for
example a parameter that is only read scalar-wise and never stored, borrowed across a call, or
returned. Compute the mask by running §5.2 on `f` alone with each parameter set to `Unique` and to
`Shared`, and comparing outputs; the result is cached per function body.

Context identity is then taken **modulo the mask**: `⟨Unique, Shared⟩` and `⟨Borrowed, Shared⟩`
are the same context if parameter 1 is irrelevant.

*(Corrected in 1.2. v1.1 called this "the layer that makes `3ⁿ` survivable in practice."
[RESULTS-L0.md](../evidence/RESULTS-L0-tiers.md) §5 measured it and that is not what happens.)*

Measured over 166 reference-taking functions in the compiler: mean reference-parameter count
**1.48**, mean mask width **1.31**. The mask saves **15%** of the worst case — useful, not
decisive.

**`3ⁿ` is survivable because `n` is small, not because the mask shrinks it.** The mask may matter
more in a language with generics and closures, where signatures widen; it does not carry the
argument today, and the honest statement of why specialisation is affordable is that real functions
take one or two reference parameters.

### 7.2 Layer 2 — semantic equivalence *(pre-codegen)*

Before emitting a body for `f@κ`, check whether an existing `f@κ'` is **semantically equivalent**:
identical tier for every abstract value in `f`, identical layout selection, identical drop
placement, identical synchronisation, identical allocation strategy. If so, alias `κ` to `κ'` and
emit nothing.

Two ownership configurations are equivalent exactly when their differences cannot affect aliasing
behaviour, allocation strategy, synchronisation requirements, lifetime optimisation, layout
optimisation, or generated code.

An implementation MAY use any sound analysis to decide equivalence. A cheap and effective one is to
hash the tuple `(tier per node, layout per type, drop points, sync points)` after convergence and
compare hashes.

### 7.3 Layer 3 — structural dedup *(post-codegen)*

Merge machine-code-identical bodies. Standard identical-code folding; the backend or linker MAY
perform it.

### 7.4 Budget-driven collapse

If total code size exceeds the configured target after all three layers, collapse contexts in
ascending order of **estimated benefit**, where benefit is the cost-model estimate (SPEC §4.4) of
cycles saved by the specialisation versus its `⊤`-context alternative. Ties break by node order
(§3.3).

This makes code size a **dial with a stated cost**, rather than an emergent property — the same
shape as the compile-time budget, and for the same reason: collapsing is always semantically safe.

The manifest SHALL record collapsed contexts, so that a size-driven performance regression is
visible in review rather than mysterious.

---

## 8 · Annotations as axioms and constraints

SPEC §5 fixes each annotation's *kind*. This section fixes where each enters the algorithm.

| Annotation | Enters at | Mechanism |
|---|---|---|
| `unique` | line 4, `seed` | sets `A ⊒ Unique` and **cuts** inbound aliasing edges |
| `region` | line 4, `seed` | sets `E ⊒ Region(r)` for sites inside and **cuts** inbound escape edges |
| `workload` | after convergence | input to the layout cost model only; touches no node |
| `pin` | after tier assignment | constrains output; derives nothing |

### 8.1 Seeding and cutting

An axiom does two things. It **seeds** a fact — the node starts at the asserted value instead of
`⊥`. And it **cuts** — the incoming edges for that fact's domain are removed, so the module does not
propagate into the node from outside its declaring scope.

The cut is the whole point. It is what makes an annotation buy compile time (a smaller
interprocedural graph) rather than only precision, and it is the sense in which an annotation is a
firewall rather than a hint.

**Cutting is unsound unless the axiom is verified.** §8.2 and §8.3 state why each verification is
complete enough to license the cut.

### 8.2 `unique` — verification is complete

The completeness argument needs one language property, and it is weaker than full value semantics:
**creating a second owning reference must be a syntactically identifiable event.** Affine
references with checked moves — what `self/` already implements — satisfy it. So does value
semantics. Neither is required over the other; the enumeration below is what matters.

The complete set of ways a second owning reference arises within the declaring scope:

- A-COPY: a copy of the binding where the source stays live.
- A-STORE: storing the binding into a field of a value that is not itself unique.
- A-CALL at a call site whose context requires `Shared` for that parameter.
- Capture by an unjoined task (E-SPAWN).

The verifier checks exactly these at every use in the declaring scope. There is no fifth way, so
the check is **complete, not approximate**, and the cut is licensed: nothing outside the scope can
introduce an owning reference that the scope does not itself hand out.

On violation: warning naming the specific operation, axiom discarded, edges restored, `A` inferred
normally.

### 8.3 `region` — verification is sound, and imprecision costs only performance

The check is "does any value allocated inside the block reach a location that outlives `r`" — which
is exactly the escape module restricted to the block. It is sound but may be imprecise.

Imprecision here reports a **false escape**, which causes a **spill**: that one value is allocated
outside the arena at its inferred tier, a warning is emitted naming the value and the store, and the
block still compiles and still bulk-frees everything else. Cost: performance for one value. This is
SPEC §1 operating exactly as designed.

The cut for `region` is licensed by construction rather than by the check: values allocated inside
the block cannot be reached from outside except through a store that the check observes.

### 8.4 `pin`

Applied after §5.2 returns and after SPEC §4.2 assigns tiers.

```
if pinned_tier ⊒ derived_tier:            honour exactly
else if facts permit pinned_tier:         honour  (the solver was imprecise; the pin is a
                                           correct assertion the analysis failed to prove)
else:                                     warn, ignore the pin, use derived_tier
```

"Facts permit" means the SPEC §4.2 clause for `pinned_tier` is satisfiable under the converged
facts. Note the middle case is the interesting one and it is not a contradiction: a pin can be
*right* where the analysis gave up, which is precisely its use at a measured hot spot after a
budget-exhausted build.

Honoured pins SHALL appear in the manifest with `origin = pin`, so that an edit which invalidates
one shows up as a diff (SPEC §6.3).

### 8.5 Verification under budget

Annotation verification is itself analysis and may be truncated. A verification that does not
complete SHALL be treated as a failure: axiom discarded, fact inferred normally. Never as a pass.

---

## 9 · Incrementality

Implementations SHOULD cache per-function inference summaries keyed by

```
( hash of the function's PIR body,
  context κ,
  hashes of the summaries of every function it calls,
  hashes of every type definition it references,
  the annotation set in scope )
```

On a source edit, invalidate the edited functions and everything transitively reachable from them
in the *reverse* call graph, then re-run §5.2 with only the invalidated nodes in the initial `Δ`.
Unaffected summaries are reused.

Because the fixed point is unique (§5.4 item 2), an incremental result at full convergence is
identical to a from-scratch one. **An implementation SHOULD verify this**: BENCHMARKS §6 makes
"incremental manifest equals cold manifest" a required test, because summary-cache bugs are silent
and produce wrong-tier binaries rather than crashes.

Incremental results under a *truncating* budget are **not** guaranteed identical to cold ones,
because `Δ` differs and therefore `U` differs. An implementation SHALL either (a) run to convergence
when producing a manifest that will be diffed, or (b) mark incrementally produced manifests as
non-authoritative. This is a real limitation and it is the reason SPEC §7.4 makes layout search a
separate explicit step.

---

## 10 · Worked example

Prismio source, with the current language plus the `region` annotation:

```prismio
struct Token  { kind: Int, start: Int, len: Int }
struct Lexer  { source: String, pos: Int }
struct Module { tokens: List<Token>, name: String }

fn lex(source: String) -> List<Token> {
    let mut lx = Lexer { source: source, pos: 0 }      // site s₁
    let mut out = list_new()                            // site s₂
    while (lx.pos < str_len(lx.source)) {
        let t = next_token(&lx)                         // site s₃ inside next_token
        list_push(&out, t)
    }
    return out
}

fn compile(path: String) -> Int {
    region parse {
        let src  = read_file(path)                      // site s₄
        let toks = lex(src)                             // returns s₂
        let m    = Module { tokens: toks, name: path }  // site s₅
        return check(&m)
    }
}
```

Trace, with `κ` written for the single context each function acquires:

| Node | Rules applied | Converged facts | Tier |
|---|---|---|---|
| `s₁` `Lexer` | E-ALLOC `Region(lex-body)`; borrowed by `next_token` → A-BORROW; never stored, never returned | `⟨Region(lex), Borrowed, Isolated, Acyclic⟩` | **T0** — statically sized, under `Θ_stack` |
| `s₃` `Token` | E-ALLOC in `next_token`; E-RETURN → `Caller`; E-STORE into `out` → `E ⊒ E(out)` | `⟨Region(parse), Borrowed, Isolated, Acyclic⟩` | **T1** in `parse` |
| `s₂` `List<Token>` | E-ALLOC `Region(lex)`; E-RETURN → `Caller`; at the call site, `subst` maps `Caller` to `Region(parse)`; E-STORE into `m.tokens` keeps it at `Region(parse)` | `⟨Region(parse), Borrowed, Isolated, Acyclic⟩` | **T1** |
| `s₄` `String` src | E-ALLOC `Region(parse)`; moved into `lex` (A-MOVE, no new reference) | `⟨Region(parse), Unique, Isolated, Acyclic⟩` | **T1** |
| `s₅` `Module` | E-ALLOC `Region(parse)`; A-BORROW by `check`; `return check(&m)` returns an `Int`, so `m` itself never escapes | `⟨Region(parse), Borrowed, Isolated, Acyclic⟩` | **T1** |

Everything lands T0/T1. One annotation on one block moved four allocation sites out of the
reference-counted tiers, and the region reset at `parse` exit frees all of them with one pointer
store.

**Now delete the `region`.** `parse` is still a scope, so `E` bottoms at `Region(compile-body)`
instead — `s₄`, `s₂`, `s₅` are still `Region`-bound and still T1, because §2.1 makes every scope an
implicit region. The annotation did not change the *tier* here; it changed the *arena granularity*
and, more importantly, it let the analysis stop instead of proving non-escape through `lex` and
`check`.

**Now make it escape.** Add `logger.attach(&m)` where `logger` is a static root:

```
E-STATIC:  E(s₅) ⊒ Global
A-ESCAPE:  A(s₅) ⊒ Shared
T-STATIC:  T(s₅) ⊒ CrossThread     (if the program creates any task)
A-STORE:   A(s₂) ⊒ Shared,  E(s₂) ⊒ Global    -- reachable from m.tokens
```

`s₅` → T4a, and `s₂` follows it out of the region to T4a. The manifest diff:

```
− Module.instance   T1   region:parse   AoS   region
+ Module.instance   T4a  rc-atomic      AoS   inferred
  cause: E rose Region(parse) → Global
  at:    logger.attach stores the value into a static root
− Lexer.tokens      T1   region:parse   SoA[16]  region
+ Lexer.tokens      T4a  rc-atomic      AoS      inferred
  cause: A rose Borrowed → Shared via Module.tokens
  at:    reachable from Module.instance
```

Two lines in a pull request, with causes. That is what SPEC §6 buys, and this example is exactly
the shape of the regression it exists to catch: **one added line, non-local cost, invisible without
the manifest.**

---

## 11 · Known weaknesses

Stated so they can be attacked rather than discovered later.

### 11.1 Field sensitivity is object-insensitive

§3.1 gives one node per struct *field*, not per field per object. So one `Shared` value stored into
`Module.tokens` anywhere makes `Module.tokens` `Shared` for every `Module` in the program. This is
the standard precision/cost trade and it is the most likely source of spurious T3/T4 in real code.

Refinements exist (allocation-site-indexed field nodes, access paths of bounded length) and cost
graph size. Deferred: measure the realised false-sharing rate first (BENCHMARKS §2.3).

**A container's element node is keyed on its full type, not its base** *(narrowed in 1.2.3, from
measurement)*. The element field of a collection is a field node like any other, and keying it on
the base type — one `@elem` node for every `List` in the program — is a coarser partition than
object-insensitivity requires: it merges containers whose *types* already distinguish them. An
implementation SHALL key it on the container type as written, so `List<Actor>` and `List<Order>` are
separate nodes, **and SHALL fall back to the base type for every spelling of a base whenever any
spelling of that base is unresolved** — a bare `List`, or one whose element type inference could not
supply. Two spellings for one container would be a read that misses its own writes, which is an
element that appears to escape nowhere.

This is sound in a language with no subtyping whose generics are monomorphised before the analysis
runs, because a container's static type is then the same at every mention. It is not a general
result and an implementation adding either feature has to revisit it.

Measured on the reference implementation: with the base-keyed node, `list_get(w.actors, i)` came
back holding `Order`s that only ever went into a different list, and SPEC §5.2.1.1's obligation 3
then refused to bracket the call that built them — `g6_game.psm` lost its entire per-tick arena to a
type name. With the type-keyed node it serves 47 205 of its 50 470 allocations.

### 11.2 The context set is discovered from facts that are still moving

§6.3 forms `κ'` from the current round's `A(yᵢ)`, which can rise later, so a context instantiated
early may be dead by convergence. Harmless (dead bodies are discarded) but wasteful, and the waste
is unbounded in pathological programs. Mitigation: delay context discovery until `A` has been
stable for one round. Not specified as normative because the cost has not been measured.

### 11.3 Loops are handled by the lattice, not by a loop analysis

Flow through a back edge is just another set of transfer edges, so a value's facts at a loop head
are the join over all iterations. That is sound and cheap, and it is imprecise exactly where it
matters most: a value that is `Unique` on the first iteration and `Shared` afterwards is `Shared`
everywhere. Loop-peeling the first iteration would recover a common case. Unspecified.

### 11.4 There is no interprocedural path sensitivity

`if (c) { share(x) } else { }` makes `x` `Shared` on both paths. Path-sensitive refinement is the
obvious next precision lever and the obvious next cost.

### 11.5 ~~The `⊤` context is a cliff~~ — resolved in 1.2

A function routed to `f@⊤` by the cap used to lose *all* specialisation rather than a proportional
amount. §7.0.1's policy-parameter strategy removes the cliff: a function that does not merit
duplication still gets context-dependent behaviour through a constant argument, and the backend
decides whether to clone. The cap now bounds *duplication*, not *specialisation*.

What remains: `δ` is a heuristic threshold, and whether it separates functions cleanly in real code
is unmeasured (SPEC §11 open item 4).

### 11.6 Everything here assumes whole-program PIR

Separate compilation against object files cannot run §5.2. SPEC §10.2 accepts this and pays for it
with a distribution format. There is no partial-information fallback specified, and there should
be one, because the first real user will have a C library to link against.
