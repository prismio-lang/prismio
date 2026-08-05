# AIF — Adaptive Inference Framework

**Prismio's memory model. Specification 1.2, and the evidence behind it.**

Prismio is a general-purpose language — Swift and Rust are the reference points. AIF is how it
manages memory: the compiler proves every value down to the cheapest safe way to manage it, owns
physical layout, and whatever it cannot prove costs performance rather than correctness.

This directory is **self-contained and authoritative**. Everything needed to implement the model,
continue the design, or document it is here.

---

## Start here

| If you are… | Read, in this order |
|---|---|
| **Implementing** | [spec/SPEC.md](spec/SPEC.md) §§1–5 → [spec/INFERENCE.md](spec/INFERENCE.md) end to end → [implementation/REQUIREMENTS.md](implementation/REQUIREMENTS.md) → [implementation/ROADMAP.md](implementation/ROADMAP.md) |
| **Continuing the design** | [implementation/RATIONALE.md](implementation/RATIONALE.md) **first** → [evidence/](evidence/) → [implementation/ROADMAP.md](implementation/ROADMAP.md) |
| **Judging whether it works** | [evidence/EVALUATION.md](evidence/EVALUATION.md) → [evidence/RESULTS-L0-tiers.md](evidence/RESULTS-L0-tiers.md) → [evidence/BENCHMARKS.md](evidence/BENCHMARKS.md) §6 |
| **Documenting it** | [spec/SPEC.md](spec/SPEC.md) is normative; everything else explains or measures it |

**Before proposing a change, read [implementation/RATIONALE.md](implementation/RATIONALE.md).**
Several obvious-looking simplifications were tried and reverted; the reasons are recorded there and
re-deriving them is expensive.

---

## The model in one screen

1. Ordinary high-level code. **No memory concept is required to appear in it.**
2. Every value gets the **cheapest tier the compiler can prove**, T0–T4, per ownership context.
3. The compiler **owns physical layout** and searches for it — references are handles, so data
   stays relocatable.
4. Four optional annotations — `unique`, `region`, `workload`, `pin`. None is required to compile.
5. Every release build emits a **tier manifest** you review like a lockfile; a regression fails the
   build gate, never the compile.
6. What cannot be proved **costs performance, never correctness** — which is what makes the
   analysis budget a dial rather than a toll.

| Tier | Strategy | Cost |
|---|---|---|
| **T0** | stack / register | zero |
| **T1** | region, bump-allocated, bulk-freed | ~2–5 cyc alloc, ~0 free |
| **T2** | unique owned, moved, RAII destruction | alloc + free only |
| **T3** | shared, non-atomic refcount, Perceus elision | 1–2 cyc per surviving op |
| **T4** | residue: atomic RC (a) and/or cycle-collected (b) | the only real tax |

---

## Status

**Design: complete.** No structural question is open. What remains on
[spec/SPEC.md](spec/SPEC.md) §11's list is measurement or policy.

**Static validation: done for what is reachable without codegen.** Six programs, three result
documents.

**Implementation: not started.** The compiler has a `dump-ast` command and nothing else.

**Dynamic validation: blocked on codegen.** No runtime number exists, and none can until tiers
reach the emitted binary.

### Conformance is graded

An implementation states its level ([spec/SPEC.md](spec/SPEC.md) §11.0). **AIF-1 (Core) is a real,
shippable memory model buildable by one person** — and measurement says it delivers essentially all
of the tier benefit. AIF-2 and AIF-3 are a long tail at steeply rising cost. Do not read the
specification's length as a required scope.

---

## What has been measured

Static distribution over six programs — five game/engine-shaped, plus the Prismio compiler itself.

| Finding | Value |
|---|---|
| **T0–T2 share, with affine collections** | **100%** — zero T3, zero T4, every program |
| Same programs, today's compiler semantics | 0–75.7% |
| FFI default contract (`borrow` vs `retain`) | **33 points** of tier distribution |
| Layout: automatic SoA on array-shaped data | 3.96×–11.58× modelled |
| Layout: on graph-shaped data (the compiler) | **1.00× — zero traversals** |
| Sealing a module (no PIR) | **25 points**, bounded to boundary-crossing values |

**The single most important result:** the entire T3 residue across every program traced to **one
language decision** — whether collection types are affine. Details in
[evidence/RESULTS-L0-tiers.md](evidence/RESULTS-L0-tiers.md) §2.

**Read the caveats before quoting any of these.** Every number is *static* distribution, not
dynamic; the approximations are conservative, so they are floors; and no runtime performance figure
has been measured at all. [evidence/RESULTS-L0-tiers.md](evidence/RESULTS-L0-tiers.md) §6 states
the limits.

---

## Where to start building

**One thing dominates: make `String`, `List<T>` and arrays affine (move-only).**

It is 100% of the measured residue. Nothing else moves the number, and every other tier improvement
optimises a population that is already at 100%. It is a one-property change to the compiler's type
system with a wide blast radius through its own source — and it converts the model's biggest claim
from a projection into a fact.

Then `region` + an arena runtime: every corpus allocation lands T2 instead of T1 purely because the
keyword does not exist, which makes it the largest untested upside.

Full ordering in [implementation/REQUIREMENTS.md](implementation/REQUIREMENTS.md).

---

## Contents

```
spec/            Normative. SPEC is the specification; the rest resolve what it defers.
  SPEC.md          Tier ladder, derivation, annotations, manifest, conformance levels
  INFERENCE.md     The decision procedure: lattices, transfer rules, fixed point, contexts
  LAYOUT.md        Access profile, cost model, layout and arena search
  FFI.md           The C boundary: when a copy is mandatory, ownership contracts
  CYCLES.md        The T4 collector — DEFERRED, see below
  PIR.md           Distribution format — mostly compiler work, see its scope note

evidence/        What is measured, what is projected, and how to falsify the rest.
  RESULTS-L0-tiers.md      Tier distribution over six programs
  RESULTS-L1-layout.md     Static profile and AoS/SoA selection
  RESULTS-L2-boundary.md   Module boundaries, transparent vs sealed
  BENCHMARKS.md            Falsification plan: hypotheses with kill criteria
  COMPARISON.md            C++/Rust/Swift suite — BLOCKED on codegen, zero ports written
  EVALUATION.md            Honest assessment as a general-purpose model

implementation/  How to build it and what is left.
  REQUIREMENTS.md    What the compiler must provide, by measured impact
  ROADMAP.md         What is left; §5 lists what is NOT AIF's work
  RATIONALE.md       Why the model is shaped this way — read before changing it
  TARGET.md          The intended stack and what each layer demands
  COMPILER-AUDIT.md  Where the seams are in the existing compiler (dated 2026-08-01)

prototype/       A working implementation of the inference engine and layout optimiser.
corpus/          Seven programs, all compiling and running under the current compiler.
```

---

## Two things to know before extending this

**Deferred, deliberately.** [spec/CYCLES.md](spec/CYCLES.md) is fully specified and **cannot be
validated**: the language cannot express a reference cycle, so T4b had zero population in every
program measured. Ownership monomorphization is likewise specified and contributed **zero** to every
measured tier number. Both are correct work that is ahead of the evidence. See
[implementation/ROADMAP.md](implementation/ROADMAP.md) §6.

**The scope test.** *Would this exist in a language with a completely different memory model?* If
yes, it is not AIF's — it may still be necessary, but it belongs to the compiler or the language.
AIF's job is narrow: **when values die, and how they are arranged.** This test has already been
applied once and removed ten items; apply it before adding anything.

---

## Running the prototype

```bash
prismio dump-ast corpus/g4_ecs_world.psm > g4.json
python prototype/aif.py g4.json --owned-collections     # tier distribution
python prototype/layout.py g4.json --verbose            # traversals + layout choices
```

The prototype is **not** throwaway. Once the engine is ported into the compiler, both run over the
same source and their manifests must agree — differential testing against an independent
implementation, and the only reliable defence against a transfer function that is subtly wrong and
produces a silently wrong tier rather than a crash.
