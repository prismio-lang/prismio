# AIF — The T4 Cycle Collector

Resolves SPEC §11 open item 4. v1.0 deferred this entirely: *"Open. Requires empirical evaluation
after implementation of the runtime. The collector design SHALL be informed by observed T4
allocation patterns, object lifetimes, cycle frequency, and runtime performance characteristics."*

That deferral was more cautious than necessary. Most of the collector's shape is **determined by
facts the model already establishes**, before any measurement:

- T1 values never reach T4 at all, because a bulk arena reset frees cycles as readily as anything
  else (INFERENCE §4.4). Everything region-bound is already out of scope.
- `Unique` implies acyclic (INFERENCE C-UNIQUE), so every T2 value is out of scope.
- `TypeAcyclic` — computable exactly from the type graph — excludes every type not in a non-trivial
  SCC, which is most types in most programs.

What remains is small, statically identifiable, and structurally constrained. That is enough to
choose an algorithm. What still needs measurement is *tuning*, not *design* — and §7 says which
constants those are.

**Contents**

1. [What is actually in scope](#1--what-is-actually-in-scope)
2. [The headline result](#2--the-headline-result)
3. [Algorithm](#3--algorithm)
4. [The cyclic-edge restriction](#4--the-cyclic-edge-restriction)
5. [Object header](#5--object-header)
6. [Trigger and work bounds](#6--trigger-and-work-bounds)
7. [Concurrency](#7--concurrency)
8. [Inferred weak references](#8--inferred-weak-references)
9. [Leak-and-report mode](#9--leak-and-report-mode)
10. [What still needs measurement](#10--what-still-needs-measurement)

---

## 1 · What is actually in scope

A value is subject to cycle collection exactly when it is **T4b** — by SPEC §4.2, when it reaches
the `T4` clause with `C = MaybeCyclic`. Unfolding the derivation, that requires **all** of:

1. `E ⊒ Caller` — it escaped every enclosing region, including the implicit ones. Any value that
   stayed inside any scope is T1 and is freed by arena reset regardless of cycles.
2. `A = Shared` — otherwise C-UNIQUE gives `Acyclic` and it is T2.
3. `¬TypeAcyclic(type(x))` — its type lies in, or reaches, a non-trivial SCC of the type reference
   graph.

Condition 3 is a **static, whole-program, exactly computable** property. Conditions 1 and 2 are
inferred facts already in the manifest.

So the collector's working set is not "the heap," and not even "everything reference-counted." It
is: *shared, fully-escaping values of recursively-referencing types.* In an AST, that is the node
type and nothing else — not tokens, not strings, not spans, not symbol entries.

---

## 2 · The headline result

> **A program whose types have no non-trivial SCC needs no cycle collector, and the compiler can
> prove it. The collector is then omitted from the binary entirely.**

This is checkable at compile time from the type graph, before any inference runs. It is not a
tuning outcome or a heuristic — it is a property of the program's type declarations.

For the large class of programs that qualify — most request handlers, most pipelines, most
numeric and data-parallel code, most CLI tools — AIF ships with **no cycle-collection machinery, no
extra header state, and no candidate buffer**, and the "Cycle reclamation" axis costs literally
nothing.

An implementation SHALL report this in the manifest:

```
cycles      none          # no type participates in a non-trivial SCC; collector omitted
```

or

```
cycles      collector     # 3 types in 1 SCC; 2 sites reach T4b
  scc#1     Node, List<Node>, Scope
  t4b       Parser.root@L118, Scope.parent@L204
```

Two lines in a build artifact that tell you whether your program can leak, which no
reference-counted language currently offers.

---

## 3 · Algorithm

> **Trial deletion (Bacon–Rajan synchronous cycle collection), scoped to the T4b residue, restricted
> to cyclic edges (§4).**

### 3.1 Why trial deletion and not tracing

Tracing cost scales with the **live heap**. Trial-deletion cost scales with the **subgraph
reachable from candidate roots**. AIF's entire premise is that the residue is small, so an
algorithm whose cost is proportional to the whole heap would reintroduce precisely the cost the
model exists to delete — and would do it in a program where 90%+ of allocations are not even
reference-counted and therefore have no headers to trace through.

Tracing also requires enumerating roots across the whole program, which means either a shadow
stack or precise stack maps at every safepoint — machinery that would be paid for by *all* code,
including the T0/T1 majority that has nothing to do with cycles. That is a violation of the model's
central discipline: **the residue pays for the residue.**

### 3.2 The procedure

Colours per object: `black` (in use), `grey` (candidate cycle member), `white` (provisionally
garbage), `purple` (candidate cycle root). Objects of `TypeAcyclic` types carry no colour and are
never entered.

```
on decrement(x):
    x.rc −= 1
    if x.rc == 0:
        free(x)                              -- ordinary RC path, no collector involvement
    else if x is T4b and not x.buffered:
        x.colour   := purple                 -- a count that dropped without reaching zero is
        x.buffered := true                   -- the only way a cycle can become garbage
        candidates.push(x)

collect():
    roots := candidates.take(K)              -- §6 bounds K
    for x in roots:  MarkGrey(x)
    for x in roots:  Scan(x)
    for x in roots:  CollectWhite(x)

MarkGrey(x):
    if x.colour ≠ grey:
        x.colour := grey
        for y in cyclicChildren(x):          -- §4: NOT all children
            y.rc −= 1                        -- trial deletion of internal references
            MarkGrey(y)

Scan(x):
    if x.colour == grey:
        if x.rc > 0:  ScanBlack(x)           -- externally reachable; the cycle is live
        else:
            x.colour := white
            for y in cyclicChildren(x):  Scan(y)

ScanBlack(x):                                -- restore counts along a live path
    x.colour := black
    for y in cyclicChildren(x):
        y.rc += 1
        if y.colour ≠ black:  ScanBlack(y)

CollectWhite(x):
    if x.colour == white and not x.buffered:
        x.colour := black
        for y in cyclicChildren(x):  CollectWhite(y)
        free(x)
```

The correctness argument is Bacon–Rajan's and is not restated: trial-deleting internal references
leaves a non-zero count exactly on objects with a reference from outside the candidate subgraph, so
`white` after `Scan` means unreachable.

Destructors on collected cycles run in reverse discovery order. Because a cycle has no
topologically first element, **destruction order within a cycle is unspecified** — an
implementation SHALL document its choice, and a program SHALL NOT depend on it. This is the one
place AIF cannot offer the deterministic destruction it guarantees on T0–T2 (SPEC §11 item 11,
which is scoped to T0–T2 precisely for this reason).

---

## 4 · The cyclic-edge restriction

This is AIF's specific contribution to the algorithm, and it is available because the compiler owns
the type graph.

> **Claim.** Every edge of a value-level reference cycle connects two types in the same SCC of the
> type reference graph.
>
> **Proof.** Let `x₁ → x₂ → … → x_k → x₁` be a value cycle with `xᵢ : τᵢ`. Each edge `xᵢ → xᵢ₊₁`
> arises from a field of `τᵢ` that can hold a `τᵢ₊₁` reference, so `τᵢ → τᵢ₊₁` is an edge of the
> type graph. The `τᵢ` therefore form a directed cycle in the type graph, hence all lie in one SCC.
> ∎

Define, for a type `τ` in SCC `S`:

```
cyclicFields(τ) = { f ∈ fields(τ) : type(f) ∈ S }
cyclicChildren(x) = the references held in cyclicFields(type(x))
```

Trial deletion traverses only `cyclicChildren`. By the claim, this finds every cycle.

**Why this matters more than it looks.** It does not merely skip a few fields — it prevents the
traversal from *leaving* the SCC at all. A `Node` with two child pointers and six fields holding
tokens, strings, spans and integers is traversed through two edges instead of eight, and, more
importantly, the collector never walks into the token and string graphs hanging off it. Those
subgraphs are typically far larger than the cyclic skeleton.

The candidate subgraph a collection touches is therefore bounded by the size of the **cyclic
skeleton**, not by the size of the object graph. That is what makes work-bounded collection (§6)
credible.

Bacon–Rajan's original "green" colour for acyclic types is the degenerate case of this restriction
— it excludes types outside every SCC. The refinement here also excludes *fields* of cyclic types
that point outside the SCC, which is the larger saving in practice.

---

## 5 · Object header

Only T4 objects carry a header. T0–T2 carry none, which is SPEC §3's cost claim.

```
T4a, TypeAcyclic:      [ atomic u64 rc ]                            8 bytes
T4a, T4b:              [ atomic u64 rc | u8 colour+buffered ]       16 bytes (aligned)
T4b, not cross-thread: [ u32 rc | u2 colour | u1 buffered | pad ]   8 bytes
T3:                    [ u32 rc ]  (or u64; see below)              4–8 bytes
```

`colour` needs 2 bits (black/grey/white/purple) and `buffered` one. On a 64-bit target with a
32-bit count these fit in the count word with room to spare; a 64-bit count for T4a needs a
separate byte, since the count word must remain atomically updatable on its own.

**A T4b object's header is larger than a T3 object's.** That is a real, if small, footprint cost
and it is a further reason the T4b population matters — it shows up in `FootprintCost`
(LAYOUT §5.3) as well as in collector time.

---

## 6 · Trigger and work bounds

### 6.1 Trigger

> **Collection SHALL be triggered by candidate-buffer occupancy, never by a timer.**

```
collect() when  |candidates| ≥ Θ_buffer,  or on allocation failure,  or on explicit request
```

A timer trigger would reintroduce exactly the unpredictable, workload-independent pause that SPEC's
latency claim rejects, and would make a program's pause profile a function of how fast the machine
is. Buffer occupancy is self-tuning: a program producing no cycle candidates never collects, and a
program producing many collects proportionally.

`Θ_buffer` default: 4096 candidates. This is a **tuning constant requiring measurement** (§10).

### 6.2 Work bound

Each collection processes at most `K` roots (default 256). Remaining candidates stay buffered.

Bounding by *roots* rather than by traversal steps means a collection can be started and finished
without an abort path: the traversal from `K` roots through cyclic edges only (§4) is bounded by
the cyclic skeleton reachable from those roots.

A hard traversal cap `W` remains as a backstop for pathological skeletons. Exceeding it aborts the
current collection by running `ScanBlack` over everything marked so far — which restores every
trial-deleted count exactly, leaves the heap unchanged, and re-buffers the roots. **Aborting is
always safe; it only delays reclamation.** This is the same discipline as INFERENCE §5.3: giving up
costs time, never correctness.

### 6.3 Latency

Because work per collection is bounded by `K` roots over the cyclic skeleton, and because the
skeleton excludes all non-SCC data (§4), pause length is bounded and is a function of program
structure rather than of heap size. This is what lets SPEC keep its `p99 ≈ p50` claim while having
a collector at all — and BENCHMARKS §4.2's p99 row is the test.

---

## 7 · Concurrency

Three cases, in increasing difficulty.

**T4b with `T ⊑ Transferred` — the common case.** The object is reachable from one task at a time.
Its candidate buffer is task-local and collection runs at that task's own quiescent points. No
synchronisation, no global safepoint, no coordination. This is isolation-based concurrency paying
off in the collector exactly as it does in the counts.

**T4a ∧ T4b, single reachable domain.** Cross-thread but reachable from one isolation domain at
collection time: collect at that domain's safepoint, with atomic count operations during trial
deletion.

**T4a ∧ T4b, multiply reachable — the residue of the residue.** A cyclic object graph
simultaneously reachable from two or more domains requires a safepoint across all domains that can
reach it. An implementation SHALL support this and MAY use a global safepoint.

This last case is the only construct in AIF that can produce a program-wide pause. It is therefore
the one thing a latency-sensitive program must be able to see and avoid, so:

> **An implementation SHALL report the `T4a ∧ T4b` population in the manifest**, per site.

A program with an empty `T4a ∧ T4b` set has no global pause anywhere, and can prove it from a build
artifact. That is a stronger latency guarantee than any tracing-GC language offers and it costs one
line of output.

---

## 8 · Inferred weak references

An optimisation, and explicitly the lower-confidence half of this document.

A field in a cyclic SCC that is compiled **weak** breaks the cycle, so the object never becomes a
T4b candidate at all and the collector never sees it. The classic shapes — parent pointers, back
references, observer registrations — are exactly the fields that create SCCs in the first place.

### 8.1 The proof obligation

> **An implementation SHALL NOT compile a field as weak unless it proves that at every store
> `x.f = y`, `y` is reachable from a root that outlives `x`.**

Getting this wrong is a premature free — a memory-safety bug, not a slowdown. The bar is therefore
absolute, and the fallback is safe:

> **Failing to infer a weak reference costs collector work, never correctness.** The field stays
> strong and the collector handles the cycle. So this optimisation is subject to the same
> discipline as everything else in AIF (SPEC §1), and a budget-limited or imprecise analysis simply
> declines to fire.

### 8.2 A checkable sufficient condition

The *back-edge* pattern, which covers parent pointers:

Field `f : σ` of `τ`, with `σ` and `τ` in the same SCC, may be compiled weak if:

1. Every store `x.f = y` in the whole program occurs at a point where `y` is already reachable from
   a live binding whose scope encloses `x`'s construction; **and**
2. `f` is never the sole reference to `y` — formally, at every store, `rc(y) ≥ 1` from a path not
   through `x`; **and**
3. `f` is never returned, stored into a longer-lived location, or moved out of.

Condition 1 is the dominance condition and is the hard one. It is provable in the common case where
`y` is a parameter or an enclosing local at every store site — which is what a parent pointer looks
like — and unprovable in general.

An implementation SHOULD report inferred weak fields in the manifest, because a field silently
becoming weak changes when destructors run, and that is exactly the kind of non-local cost change
SPEC §6 exists to surface.

---

## 9 · Leak-and-report mode

Because §1 identifies the T4b sites **statically**, a program may opt out of the collector entirely:

```
cycles      leak-and-report
  may-leak  Parser.root@L118, Scope.parent@L204
```

The binary then ships with no collector, no colour bits, and no candidate buffer, and the build
reports precisely which sites can leak.

This is what Swift and Rust do by default, except that they tell you nothing. **AIF can tell you,
because the manifest already knows.** For a short-lived process — a CLI, a compiler, a batch job —
this is the right default, and the report is a static, reviewable list rather than a runtime leak
hunt.

An implementation SHALL make the collector the default and this mode explicit opt-in. Leaking
should require a decision.

---

## 10 · What still needs measurement

The design above is determined by structure. These are genuinely empirical and should not be
guessed at with confidence:

| Constant / question | Why it needs data |
|---|---|
| `Θ_buffer` (4096) | Trades collection frequency against buffer footprint. The right value depends on candidate production rate, which is program-specific. |
| `K` roots per collection (256) | Sets the pause bound. Needs the observed cyclic-skeleton size per root. |
| `W` traversal backstop | Only matters if real skeletons are heavy-tailed. Measure the distribution first. |
| **Cyclic-skeleton size distribution** | The single most valuable measurement. If skeletons are small, §6's bounds are generous and pauses are negligible. If they are heavy-tailed, `K` must shrink and collection becomes incremental. |
| **T4b population in real programs** | If it is near-zero, as §1 predicts, most of this document is dead code that never runs — a good outcome, but one to confirm rather than assume. |
| **How often the weak inference of §8.2 fires** | If it fires rarely, §8 is not worth its implementation cost and should be cut. |

The first two of these are reportable from a Level 0 build (GAPS §5) with no collector implemented
at all, because the type-graph SCC analysis and the T4b site identification are pure compile-time
work. **Measure those before writing a line of the collector** — §1's argument predicts the
population is small, and if it is right, the tuning constants barely matter.
