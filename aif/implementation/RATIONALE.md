# AIF — Design Rationale

*Why the model is shaped as it is: the ten changes from revision 1.1 to 1.2, each with the weakness
it fixes. **Read this before proposing a change** — several obvious-looking simplifications were
tried and reverted for reasons recorded here.*

Ten changes to the model, in descending order of how much they matter. Each states the weakness in
1.1, the fix, and what it costs. Applied to the specification set; this document is the reasoning.

Two of them are not new mechanisms at all — they are the removal of a conflation that was making
the model look riskier than it is. Those are C1 and C7, and they are the most valuable entries here.

| # | Change | Kills |
|---|---|---|
| [C1](#c1) | Un-conflate context-sensitive tiers from body duplication | The binary-bloat existential risk |
| [C2](#c2) | Graded specialisation: monomorphise / policy-parameter / shared | The `⊤`-context cliff |
| [C3](#c3) | `verify` mode — every inferred fact becomes a runtime assertion | Silent wrong-tier binaries |
| [C4](#c4) | Minimal cause and suggested repair for tier regressions | The disorienting non-local slowdown |
| [C5](#c5) | Bake the static *region*, not the heap | An unimplementable startup claim |
| [C6](#c6) | Fast-path guards instead of speculation-with-deopt | A subsystem that eats a compiler team |
| [C7](#c7) | Arena placement is a cost decision; `region` is a pin on it | `region` being load-bearing |
| [C8](#c8) | The annotation set is a complete basis, and here is why | An open governance question |
| [C9](#c9) | Conformance levels AIF-1 / AIF-2 / AIF-3 | Spec calcification |
| [C10](#c10) | Self-rebuilding binaries + manifest-driven fast rebuild | The security-patch problem |

---

## C1

### Un-conflate context-sensitive tiers from body duplication

**The weakness.** SPEC 1.1 §11 item 4 froze this: *"Tier is a property of ⟨site × ownership
context⟩ — ownership monomorphization is required, not optional."* That sentence bundles two
completely different claims:

1. **A semantic claim** — the *analysis* is context-sensitive, so a value's tier may differ by
   caller. This is what deletes the call-boundary join, and it is the whole reason the T3 residue
   shrinks.
2. **An implementation claim** — therefore the compiler emits a separate *body* per context.

Claim 2 does not follow from claim 1, and it is the source of the model's single largest risk: `3ⁿ`
bodies, I-cache pressure, and BENCHMARKS H4 as an existential test. Because it was frozen, a bad H4
result would have invalidated the specification rather than one optimisation.

**The fix.** Freeze claim 1. Un-freeze claim 2.

> **Tier SHALL be a property of ⟨site × ownership context⟩. How an implementation realises
> context-dependent behaviour in generated code is unconstrained.**

Body duplication is now one strategy among three (C2), chosen by cost.

**Why this is not a retreat.** Nothing about the analysis changes — contexts are still discovered,
tiers are still context-sensitive, the join still disappears. What changes is that the *code size*
consequence is no longer mandated. The elegant part of the design was always claim 1; claim 2 was
an implementation detail that got promoted into the conformance boundary because it happened to be
written in the same sentence.

**Cost.** None, except that "ownership monomorphization" is no longer an accurate name for a
required feature. The name survives for the strategy in C2 that actually does duplicate.

---

## C2

### Graded specialisation

**The weakness.** INFERENCE 1.1 §11.5 named it: *"The `⊤` context is a cliff. A function routed to
`f@⊤` by the cap loses all specialisation, not a proportional amount."* Specialisation was
all-or-nothing per function, and the context cap was a blunt instrument for a problem that deserved
a dial.

**The fix.** Three implementation strategies, selected per function by cost.

Define the **ownership-divergence ratio** `δ(f)`: the fraction of `f`'s emitted operations that
differ across its contexts. It is nearly free to compute, because INFERENCE §7.1 already analyses
`f` under each parameter mode to build the relevant-parameter mask — `δ` is the diff it already
produced, counted instead of discarded.

| `δ(f)` | Strategy | What is emitted |
|---|---|---|
| High (ownership pervades the body — in-place mutation versus copy-on-write changes the algorithm) | **Monomorphise** | One body per surviving context. The 1.1 behaviour. |
| Low (ownership affects only allocation, drop and count sites) | **Policy parameter** | One body, with a compile-time-constant policy argument. Ownership-dependent operations branch on it. |
| Cold (low call frequency in the profile) | **Shared** | One body at `⊤`. No specialisation, and correctly so — nobody is waiting on it. |

The middle strategy is the interesting one. A body emitted once with a constant policy argument
lets the **backend's existing function-specialisation pass** decide whether cloning pays, using a
cost model already built and tuned for exactly this question. Constant propagation deletes the dead
policy branches in whichever clones it creates. AIF stops making the code-size decision and
delegates it to the layer that has the information.

**What this buys.**

- Code size risk becomes **bounded by construction** rather than by a cap. Bodies are emitted once
  unless duplication is affirmatively worth it.
- The cliff becomes a slope. A function that does not merit full specialisation still gets the
  policy-parameter form, which is most of the benefit at a fraction of the size.
- BENCHMARKS H4 stops being existential. A bad mask-width result now costs you the monomorphise
  strategy on some functions, not the specification.

**Cost.** The policy-parameter form has a small overhead when the backend declines to clone: a
predictable branch on a constant, which folds away under inlining and costs a correctly-predicted
branch when it does not. This is strictly better than the `⊤` cliff it replaces.

**Determinism.** Strategy selection is a function of `δ` and the profile, both deterministic, with
ties broken by node order.

---

## C3

### `verify` mode — every inferred fact becomes a runtime assertion

**The weakness.** The scariest property of AIF: a wrong transfer function produces a *silently
wrong binary*, not a crash. BENCHMARKS §6 lists seven correctness gates and notes that every
failure mode there is silent. Soundness rested on a proof about an implementation nobody has read.

**The fix.** A third build mode, normative alongside `debug` and `release`.

> **`verify` compiles at full inference, then inserts a runtime assertion for every inferred fact.**

Every fact domain has a mechanical runtime predicate:

| Fact | Assertion inserted |
|---|---|
| `A = Unique` | A debug-only count word; assert it never exceeds 1 |
| `A ⊑ Borrowed` | Assert no second owning reference is created |
| `E = Region(r)` | Poison the arena on reset; assert no read of poisoned memory |
| `E ⊑ Caller` | Assert not reachable from any static root at return |
| `T = Isolated` | Assert accessing thread id equals creating thread id |
| `T ⊑ Transferred` | An ownership token; assert no two tasks hold it simultaneously |
| `C = Acyclic` | Periodic reachability check over values inferred acyclic |
| Tier T0 / T1 | Assert no access after frame or region exit |

**This is the highest-value addition in 1.2**, and it is close to free to build because the facts
are already discrete, finite, and per-node. It converts the inference engine from *proven correct
on paper* to *continuously tested against real executions*. A bug in a transfer function surfaces
as an assertion failure in the test suite instead of as a use-after-free in production.

It also gives the correctness gates something to run against: G5 (soundness) becomes "the full
suite under `verify`," which is a far stronger statement than "under ASan," because ASan can only
catch a fact violation that *happens* to corrupt memory on that run. `verify` catches the violation
itself.

**Cost.** `verify` builds are slow and use extra memory — debug count words on values that ship
without them, an ownership token per transferred value, poisoned arenas. All of it is test-only and
none of it appears in `release`. Slowness is the correct trade for a mode whose entire purpose is
to be run by CI rather than by users.

**Normative status.** A conformant implementation SHALL provide `verify` at AIF-1 (C9). It is not
an optional debugging nicety; it is how the model's central safety claim is checked.

---

## C4

### Minimal cause and suggested repair

**The weakness.** The manifest makes non-local regressions *visible*. It does not make them
*understandable*. "Your PR failed the tier gate because of something in a file you did not touch"
is a genuinely disorienting experience, and Rust's borrow checker — for all it is disliked — at
least yells at you on the line you wrote.

**The fix.** The fact graph already knows the derivation. Use it.

When a value's tier rises, walk backward through the derivation DAG following only **maximal
contributors** — for a fact `f` at node `n` with value `v`, the predecessors `m` whose
`transfer(m→n)` equals `v`. That yields a witness path from a root cause to the affected value.
Shortest such path is the **minimal cause**. It is a BFS on a DAG of small practical depth, not a
general min-cut, so it is cheap.

Each edge on the path carries the rule that fired, which means each edge also carries what would
have to change to break it. That produces a **suggested repair**:

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

Repair 3 being *rejected with a reason* matters as much as the two that are offered: the compiler
knows which fixes are unsound and says so, rather than letting the developer try them.

**Why this is better than Rust's experience, not worse.** A borrow-check error tells you the rule
you violated. This tells you the causal chain, the introducing edit, and a ranked set of fixes with
their costs. The information is strictly greater, and it is available because the compiler kept the
derivation rather than only the conclusion.

**Cost.** The derivation DAG must be retained through tier assignment rather than discarded at
convergence. Memory, and only in builds that emit a manifest.

---

## C5

### Bake the static region, not the heap

**The weakness.** SPEC 1.1 §8.3 claimed a build-time heap snapshot, justified by "GraalVM
native-image struggles with pointer relocation and handles make relocation a non-problem."

That justification is true and beside the point. **Relocation was never GraalVM's hard part.** The
hard part is what it means to run initialisation at build time when initialisation opens files,
reads clocks, queries the environment, or touches anything absent from the build sandbox. Handles
solve the easy half of a problem whose difficulty lies elsewhere. The projected 0.30–0.60 startup
row was resting on a misdiagnosis.

**The fix, in two parts.**

**Part 1 — bake a region, not a heap.** A T1 arena is already a contiguous byte block with no
internal freeing, and handles inside it are region-relative offsets. So a build-time-initialised
arena is *just bytes*. Emit it as a binary section; load it with one `mmap`. No object graph
traversal, no pointer fixup, no per-object work — not because relocation is cheap, but because
**there is nothing to relocate**. This is dramatically simpler than a heap snapshot and it is
available specifically because AIF has both regions and handles.

**Part 2 — partition initialisation by purity.** Do not attempt arbitrary initialisation at build
time. Classify initialisers using machinery the model already has — the FFI contract vocabulary
(`pure`, `nocallback`) plus an ordinary purity analysis:

- Provably pure and deterministic initialisation → runs at build time, lands in the static region.
- Everything else → runs at startup, exactly as today.

And report it:

```
static-region   1.8 MB · 43 of 51 initialisers baked
  deferred      Config.load (reads environment) · Log.open (opens file) · 6 more
```

**The honest claim** replaces the flat 0.30–0.60: *startup cost falls in proportion to the pure
fraction of initialisation, and the compiler tells you what that fraction is.* For a CLI with large
static tables, near-total. For a server that opens sockets at init, near-nothing. That is a
mechanism whose benefit is proportional to a measurable property of your program — which is a much
better thing to ship than a number that is right for some programs and badly wrong for others.

**Cost.** The claim gets smaller and more defensible. BENCHMARKS §4.2's startup row should be
restated as a function of baked fraction rather than a constant.

---

## C6

### Fast-path guards instead of speculation-with-deopt

**The weakness.** The v1.0 material specified speculation: *"compile the optimistic version with a
cheap runtime tripwire and a deopt path down to RC,"* with the elegant property that compile budget
buys removal of runtime checks.

Deopt requires transitioning a value's *representation* at runtime — materialising a count header
on an object that was compiled without one, and updating every reference to it. In most languages
that last step is impossible. In AIF it is merely expensive, because handles make references
updatable. But the machinery — deopt metadata, state mapping, on-stack replacement — is the kind of
subsystem that consumes a compiler team for two years.

**The fix.** Do not speculate on the tier. Assign the conservative tier, and specialise the *path*.

```
                  speculate + deopt                     fast-path guard
  tier            T2 (no header), deopt to T3           T3 (header present)
  runtime check   tripwire                              if (rc == 1)
  on failure      materialise header, fix all refs      take the shared branch
  machinery       deopt metadata, OSR, ref fixup        a branch
```

A value the solver suspects is usually unique gets T3 — so the header exists, and nothing has to be
materialised — with `if (rc == 1) { mutate in place } else { copy }` at the sites that care. This
is the standard copy-on-write check; Perceus already does exactly this for drop-reuse, so it is
proven rather than novel.

**The headline property survives intact.** As the budget rises, the solver proves uniqueness
statically and *deletes the guard*. Compile budget still literally buys the removal of runtime
checks — the same claim, reached without a deopt subsystem.

**Cost.** A value that would have been T2-by-speculation is now T3, so it carries a count word it
might not have needed. That is one word of footprint against an entire subsystem. Trivially worth
it.

---

## C7

### Arena placement is a cost decision; `region` is a pin on it

**The weakness.** `region` was described as the highest-leverage annotation and simultaneously as
optional. Both were true, but the second was true only by accident: since every scope is an
implicit region (SPEC §4.2's collapse), `region` was not supplying the *fact* — the escape analysis
already had it. It was choosing *arena granularity*, which is a cost decision, not information.

Meanwhile SPEC §12 listed the workload dependency as the model's honest annotation-burden rebuttal
while `region` — actually the more load-bearing annotation in practice — sat unexamined.

**The fix.** Make arena placement a decision the cost model makes.

Not every scope should get a real arena: arena setup and teardown cost something, and a scope that
allocates twice does not deserve one. So it is a cost question, with all the inputs already in the
profile:

```
ArenaBenefit(s) = allocs_in(s) · (α_T2 − α_T1)  −  entries(s) · arenaSetupCost
```

`allocs_in(s)` and `entries(s)` come from the access profile exactly as `iters(t)` does. Scopes are
ranked and arenas are placed where the benefit is positive, greedily, respecting nesting.

Then:

> **`region` is a pin on arena placement.** It does not supply a fact and it does not enable a tier
> the compiler could not reach. It *guarantees* an arena at a scope the cost model might otherwise
> decline, and — because it is recorded in the manifest — it makes that guarantee survive edits.

**Why this is the same shape as C1 and as FFI §4.** Three times now, an annotation turned out not
to supply information but to *stabilise a decision the cost model can make on its own*. That is a
pattern, and C8 turns it into an argument.

**Cost.** `region`'s marketing gets quieter: it is no longer "one line converts a subsystem from T3
to T1," because the compiler will often do that unprompted. It is "one line guarantees this stays
converted." Less dramatic, more honest, and it lowers the annotation burden rather than raising it.

---

## C8

### The annotation set is a complete basis

**The weakness.** SPEC §11 listed *"whether four annotations hold"* as open, with only the
observation that every language promising "a few optional hints" was eventually asked for a fifth.
That is a prediction, not a defence. A set defended only by resolve gets extended the first time
someone influential wants a fifth.

**The fix.** Argue that the four span the space, so a fifth is either a duplicate or out of scope.

An annotation can do exactly three things:

| Kind | What it does | AIF |
|---|---|---|
| **Information** | Supplies what the compiler cannot derive | `workload` |
| **Axiom** | Asserts a fact so the analysis can stop | `unique`, `region`* |
| **Constraint** | Fixes an output decision the compiler would otherwise make | `pin`, `region` |

`region` appears twice because C7 reclassified it: it is a constraint on arena placement, and it
*also* acts as an escape axiom that cuts the interprocedural graph.

**Why exactly two axioms, and why these two.** An axiom is worth having exactly where establishing
a fact requires *interprocedural* reasoning — that is where cutting the graph saves real compile
time and where inference is most likely to fail. Check each fact domain:

| Domain | Established how | Needs an axiom? |
|---|---|---|
| `E` escape | Interprocedural — must follow stores through calls | **Yes** → `region` |
| `A` aliasing | Interprocedural — must know what callees retain | **Yes** → `unique` |
| `T` thread affinity | Locally visible — task structure is syntactic (`spawn`, `join`) | No |
| `C` cyclicity | Derived from the type graph plus `A` | No |

So the two domains that need axioms have them, and the two that do not, do not. This is not four
arbitrary conveniences; it is one information channel, one axiom per interprocedurally-established
fact, and one output constraint.

**Test the argument against proposals.** `@threadlocal` — an axiom on `T`, which is locally
determined, so it asserts what the compiler already sees: rejected as duplicative. `@nocopy` — a
constraint, duplicates `pin`. `@inline` — a constraint, but on a codegen decision outside the
memory model's scope. `@acyclic` — an axiom on `C`, derived from the type graph: rejected.

The argument survives them, which is the point of having one.

**Cost.** None. This replaces a governance intention with a governance *argument*, which is what
makes it defensible when someone influential asks.

---

## C9

### Conformance levels

**The weakness.** The specification is now dramatically larger than any implementation of it, and
specifications that outrun their implementations calcify into monuments nobody can build. There was
no way to be *partially* AIF and say so honestly.

**The fix.** Three conformance levels. An implementation states its level; the manifest records it.

**Invariant at every level** — these are the model's identity and are not graded:

the invariant (SPEC §1) · the T0–T4 ladder and its ordering · tier is never a source-level type ·
the manifest · two-speed compilation · `verify` mode (C3) · pipeline determinism · deterministic
RAII on T0–T2

| | **AIF-1 · Core** | **AIF-2 · Optimising** | **AIF-3 · Full** |
|---|---|---|---|
| Inference | escape + aliasing | + thread, cyclicity | + full context discovery |
| Contexts | `⊤` only | discovered, graded specialisation (C2) | + raised caps |
| Layout | declaration order, AoS | search, static profile | + workload autotuning, empirical validation |
| Arenas | none — T1 = enclosing scope | cost-placed (C7) | + `region` pinning |
| T3 | naive counting | Perceus elision, reuse, fast-path guards (C6) | same |
| T4b | leak-and-report | collector | collector |
| Startup | ordinary | ordinary | static region (C5) |
| Distribution | source | source | PIR |
| Concurrency | none — `T` vacuous | none | full |

**AIF-1 is a real, shippable memory model**: no GC, no ARC tax, deterministic destruction, a cost
manifest, and a verify mode. It is already better than the status quo for a large class of
programs, and it is buildable by one person. AIF-2 is where the performance thesis is tested. AIF-3
is the model as specified.

**Cost.** More specification surface. Bought back many times over: a level ladder is what makes the
difference between a design that ships incrementally and one that waits for everything.

---

## C10

### Self-rebuilding binaries

**The weakness.** PIR §8's sharpest cost: a vulnerability in a widely used library requires
recompiling every dependent binary rather than replacing one shared object. I called this
unresolvable by specification. That was too quick.

**The fix, in three parts.**

**Part 1 — the binary carries what it needs to rebuild itself.** A release artifact embeds the PIR
closure of its dependencies, its manifest, and a compiler version pin.

```
aif rebuild --replace libssl@3.2.0=3.2.1 ./myserver
```

No source access, no build environment, no dependency resolution. The objection to "rebuild the
world" is almost never the compilation itself — it is that rebuilding requires reassembling a build
environment that may no longer exist. A self-contained artifact dissolves that objection, and
converts a **coordination problem into a compute problem.** Those are very different in kind.

**Part 2 — the rebuild is fast, because the manifest already made the expensive decisions.** A
security rebuild does not need to redo layout search or re-derive tiers. It needs the *same*
decisions applied to patched code, and the manifest records them. Rebuild reads the manifest rather
than re-searching: minutes, not hours. The manifest earns its keep for the third time.

**Part 3 — the consumer chooses the boundary, not just the library.** PIR §9's C-ABI shim becomes
consumer-selectable: *"link openssl dynamically even though it did not ask to be."* Whole-program
optimisation everywhere else, a patchable boundary exactly where the threat model wants one.

**What remains true.** It is still a rebuild. You still redistribute binaries; you still cannot
patch a running process; a distribution still recompiles rather than replaces. Part 1 makes it
mechanical, Part 2 makes it cheap, Part 3 makes it avoidable where it matters most. That is a real
answer and it is not a complete one, so it stays on SPEC §11's open list — demoted, not deleted.

**Cost.** Binary size grows by the embedded PIR. An implementation SHALL support stripping it, at
the cost of losing self-rebuild — which is the right trade for an embedded target and the wrong one
for a server.

---

## What changed about the risk profile

| Risk in 1.1 | Status in 1.2 |
|---|---|
| Binary bloat is existential (frozen requirement) | **Bounded by construction** — C1 + C2 |
| A wrong fact is a silent memory-safety bug | **Loud in CI** — C3 |
| Non-local regressions are disorienting | **Explained with ranked repairs** — C4 |
| Startup claim rests on a misdiagnosis | **Restated as proportional, and mechanically simpler** — C5 |
| Deopt subsystem | **Deleted; a branch does the same work** — C6 |
| `region` quietly load-bearing | **Cost model does it; annotation stabilises it** — C7 |
| Annotation set defended by resolve | **Defended by a basis argument** — C8 |
| Spec outruns implementation | **Three shippable levels** — C9 |
| Security patching unresolved | **Coordination problem → compute problem** — C10 |

The two that remain genuinely open are unchanged in kind: **the layout cost model has to be
calibrated by measurement**, and **the whole performance thesis rests on a tier distribution nobody
has measured**. Both are answered at GAPS Level 0, before any codegen work, which is still where
the project should start.
