# AIF — The Target Workload

AIF exists to make one thing possible: **a language that performs like hand-tuned C++ and reads
like Kotlin or Swift.**

## 0 · The actual stack

Prismio is not used to write a game engine directly. The intended layering is:

```
  Prismio        the language and compiler
      ↓
  Xefy           a cross-platform app/web framework, Flutter-shaped
      ↓
  game engine    built on Xefy, because the UI layer was needed anyway
      ↓
  games
```

**Xefy is therefore AIF's first and most demanding consumer, not the game engine.** That matters,
because a declarative UI framework and an ECS have almost opposite memory profiles, and the
framework is the one being built first.

| | **Xefy** (framework) | **Engine / game** |
|---|---|---|
| Dominant allocation | Widget subtrees rebuilt every frame — enormous short-lived churn | Component arrays, mutated in place |
| Data shape | Trees with parent links, retained across frames | Flat arrays, index-linked |
| Closures | **Everywhere** — builders, callbacks, event handlers. Not optional | Rare |
| Layout opportunity | Modest — tree-shaped, pointer-chasing | Large — SoA over component arrays |
| Sharing | Themes, inherited state propagated down the tree | Assets, referenced by handle |

Three consequences, and the first is the important one:

**Widget rebuild is the best region case in existence.** Flutter's core loop rebuilds a widget
subtree, diffs it against the element tree, and throws the whole subtree away. That is precisely
`region { … }` — allocate freely, discard in bulk, never free individually. Flutter pays a
generational GC for exactly this, and GC jank on rebuild churn is its most persistent performance
complaint. **A framework where widget rebuild is allocation-free is a product-level differentiator,
not a memory-model curiosity.**

**Closures move from optional to blocking.** Declarative UI is closures — `onPressed`, builder
functions, state callbacks. Xefy cannot be written without them, and closures capture, which makes
them the main genuine source of shared ownership. This reverses the deprioritisation of T3 work
that [RESULTS-L0.md](../evidence/RESULTS-L0-tiers.md) §3a suggested: handles eliminate T3 in *engine* code, and
closures reintroduce it in *framework* code.

**Parent-linked persistent trees become certain, not hypothetical.** An element tree with parent
references is the standard shape, and RESULTS-L0 §4.2 found that shape is currently inexpressible.
Either cycles must be supported or the tree must be handle-indexed — and that is a decision Xefy
forces early.

One correction this forces on earlier work: the Prismio compiler corpus was dismissed in
RESULTS-L0 §3 as unrepresentative because it is tree-building and string-heavy rather than
array-shaped. Against **Xefy** it is a considerably better proxy than the game corpus is — the
compiler builds and retains an AST, which is structurally what a widget/element tree is.

---

## 0.1 · Engine and game remain two workloads

Everything below still applies, one layer further up the stack. The engine/game split is real and
they pull in opposite directions on nearly every axis; treating them as one is how a language ends
up either too complex for gameplay code or too weak for engine code.

---

## 1 · The two halves

| | **Engine** | **Game** |
|---|---|---|
| What it is | Allocators, ECS storage, render graph, job scheduler, asset streaming, resource management | Entity behaviour, state machines, AI, quests, UI, gameplay rules |
| Written by | Few people, rarely changed | Many people, changed constantly |
| Lifetimes | Program-long: asset caches, GPU resources, component pools | Frame- and tick-scoped, transient |
| **Ownership** | **Genuinely shared** — one mesh referenced by 1000 entities, one material across many draw calls | **Mostly single-owner**, tree-shaped, plus *references into* engine data |
| Layout sensitivity | Extreme — SoA, cache lines, false sharing | Moderate |
| **Annotation tolerance** | **High** — engine authors will annotate for performance | **Zero** — must be invisible |
| **Compile-time tolerance** | Higher — built rarely, cacheable | **Very low** — iteration speed is the job |
| FFI | Heavy: Vulkan, DirectX, platform audio, physics | Almost none |
| Concurrency | Job system, 8–16 cores | Occasional, usually via engine |

---

## 2 · What this changes

### 2.1 The annotations belong to the engine layer

This is the most useful consequence.

`unique`, `region`, `workload` and `pin` are exactly the tools an *engine author* wants: declare
the frame arena, pin the component layout, describe the traffic. They are exactly what a *gameplay
programmer* must never have to think about.

> **The annotation budget is spent by the five people writing the engine, not the fifty writing
> gameplay.**

That is a much stronger statement of "easier than Rust" than the specification currently makes.
Rust's cost is that *everyone* pays the ownership tax in every file. AIF's four annotations
concentrate in the layer whose authors are already writing custom allocators by hand — and gameplay
code, which is most of the code, stays annotation-free and still fast, because the engine already
established the regions and layouts its data flows through.

SPEC §5 says annotations are optional. This says something sharper: **they are optional everywhere
and used in one place.**

### 2.2 T3 lives in the engine, T0–T2 in the game

[RESULTS-L0.md](../evidence/RESULTS-L0-tiers.md) §6 flags that the current corpus contains no genuinely shared data
and therefore never exercises T3. The engine/game split explains why and where to look: **shared
ownership is an engine-layer phenomenon.** A mesh, a texture, a material, a shader — referenced by
many entities, owned by none of them.

So the tier distribution should be expected to differ sharply by layer, and measuring them
together averages away the thing worth knowing. The corpus needs an engine-shaped program with real
asset sharing before any tier number is trustworthy.

### 2.3 The engine/game boundary is where whole-program analysis must hold

Game code calls engine APIs constantly — `world.spawn`, `renderer.submit`, `assets.load`. If those
calls are opaque, every value crossing them sinks, and the model collapses at exactly the boundary
it most needs to work across.

Two consequences, both already half-specified elsewhere:

- **The engine must ship as PIR, not as a compiled library.** [PIR.md](../spec/PIR.md) §1 already requires
  this for ownership contexts; the engine/game boundary is the concrete reason it matters.
- **Engine APIs that store their arguments need ownership contracts**, exactly as FFI does.
  `world.spawn(entity)` and `renderer.submit(cmd)` are the container-store shape that
  [FFI.md](../spec/FFI.md) §5.3a's `retain_in(k)` was added for. That contract was found by measurement on
  `list_push`; it generalises to every engine API that takes ownership of something.

### 2.4 The manifest becomes a contract between teams

[SPEC.md](../spec/SPEC.md) §6 motivates the tier manifest as a defence against non-local regressions inside
one codebase. Across the engine/game boundary it does more:

> An engine change that sinks gameplay code's tiers shows up as a diff in the **game's** manifest,
> with a minimal cause pointing at the engine API that caused it (SPEC §6.3).

That is a genuinely new thing. Today an engine team learns they regressed gameplay performance from
a profiler, weeks later, if at all.

### 2.5 Optimisation level has to be **per module**, not per build

This is a real gap in the current specification.

SPEC §7.2 defines `debug`, `release`, `max` as properties of a *build*. For this workload that is
wrong. The engine is built rarely and wants `max`, including hours of layout search. Game code is
rebuilt every few minutes and needs `debug` speed. A single per-build level forces you to choose
between a slow iteration loop and an unoptimised engine.

> **Required: per-module optimisation levels, with cached engine artifacts.** Engine at `max`,
> compiled once and cached; gameplay at `debug`, rebuilt constantly; the two linked together.

The invariant makes this sound — every tier is semantically valid, so mixing levels across modules
cannot change behaviour, only performance. But it needs specifying: what the manifest records when
levels differ, and how a cached `max` engine artifact stays valid when gameplay code changes.

Related: **hot reload** for gameplay code. Whole-program monomorphization is hostile to it. This is
unaddressed and it is the thing most likely to make a studio decline the language regardless of how
fast the binary is.

---

## 3 · Consequences for the benchmark suite

[COMPARISON.md](../evidence/COMPARISON.md)'s suite was written before this split was explicit, and it
under-weights the target.

- **X3 (data-parallel) is the primary benchmark, not one of eight.** ECS storage is hand-rolled SoA
  in every engine that exists. Automatic SoA is the single thing a studio would switch languages
  for.
- **Add an engine-layer benchmark with shared assets** — the T3 case, currently untested.
- **Add a game-layer benchmark that calls engine APIs across a module boundary** — the case §2.3
  says must not collapse.
- **Drop the compiler as a proxy workload.** It is string-heavy and struct-light, and
  RESULTS-L0 §3 shows it reports a misleading number for this target.
- **Iteration time becomes a first-class measurement**, not a footnote: time to rebuild gameplay
  code against a cached engine, which is the number a studio actually feels.

---

## 4 · What stays the same

Nothing in the model's structure changes. The tier ladder, the invariant, the inference procedure,
the manifest and the determinism rules are all unaffected — this is a statement about *where each
tier shows up* and *who spends the annotation budget*, not about what the tiers are.

The one substantive addition is §2.5's per-module levels, which is new work.
