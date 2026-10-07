# AIF: the memory model

AIF (the Adaptive Inference Framework) is how Prismio manages memory. The compiler proves every
allocation down to the cheapest safe strategy (stack, region, unique owner, shared count, or cycle
management), owns physical layout, and whatever it cannot prove costs performance rather than
correctness. `prismio aif <file.psm>` shows the decisions.

This directory is the **design record**. The authoritative description of what the compiler does today
is the source (`src/aif/`, `runtime/aif_support.c`) and the two documentation sites:
[the language docs](https://docs.prismio.org/guides/memory-and-aif) for using it and
[the developer docs](https://developers.prismio.org/aif/overview) for working on it.

| Path | What it is |
|---|---|
| [`spec/SPEC.md`](spec/SPEC.md) | **Normative.** The tier ladder (T0-T4), tier derivation (4.2), annotations, the manifest, conformance levels. |
| [`spec/INFERENCE.md`](spec/INFERENCE.md) | The decision procedure: fact lattices, transfer rules, the fixed point, contexts. |
| [`spec/LAYOUT.md`](spec/LAYOUT.md) | Access profiles, the cost model, layout and arena search. |
| [`spec/FFI.md`](spec/FFI.md) | The C boundary: when a copy is mandatory, ownership contracts. |
| [`spec/CYCLES.md`](spec/CYCLES.md) | The T4 collector. |
| [`spec/PIR.md`](spec/PIR.md) | A distribution format for sealed libraries (a design; not implemented). |
| [`implementation/RATIONALE.md`](implementation/RATIONALE.md) | **Read before proposing a change.** Obvious simplifications that were tried and reverted, and why. |
| [`implementation/REQUIREMENTS.md`](implementation/REQUIREMENTS.md), [`ROADMAP.md`](implementation/ROADMAP.md), [`TARGET.md`](implementation/TARGET.md), [`COMPILER-AUDIT.md`](implementation/COMPILER-AUDIT.md) | What the implementation needs, in what order, and an audit of where it stood. |

Related, elsewhere in the tree:

- **The oracle**, an independent Python implementation of the analysis that the in-compiler engine is
  tested against: [`tools/aif_oracle/`](../../tools/aif_oracle/README.md), run by `tools/aif_differential.py`.
- **Open problems**: [`../KNOWN_ISSUES.md`](../KNOWN_ISSUES.md).
- **Measured decisions and rejected experiments** (allocator choice, the `Int` width, layout
  representations, loop-guard designs): the developer docs' *Performance decisions and rejected
  experiments* page.

## The model in one screen

1. Ordinary high-level code. No memory concept is required to appear in it.
2. Every value gets the cheapest tier the compiler can prove, T0 to T4, per ownership context.
3. The compiler owns physical layout and searches for it; references are handles, so data stays relocatable.
4. Four optional annotations: `unique`, `region`, `workload`, `pin`. None is required to compile.
5. Every release build can emit a tier manifest to review like a lockfile; a regression fails the build gate,
   never the compile.
6. What cannot be proved costs performance, never correctness.

| Tier | Strategy | Cost |
|---|---|---|
| T0 | stack or register (a frame array is T0 as well) | zero |
| T1 | region, bump-allocated, bulk-freed | a pointer bump |
| T2 | unique owned, moved, deterministic release | one allocation and one free |
| T3 | shared, non-atomic reference count | a count update where sharing survives analysis |
| T4 | atomic reference count and/or cycle-collected | the only real tax |

## The raw experiment records

Through 2026-10-07 this directory had a sibling, `aif/evidence/`: about 270 dated session records,
measurement data and scratch programs. They were removed from the working tree because their conclusions
live in the docs above and in `git log`. They remain in Git history; comments in the source that cite
`aif/evidence/RESULTS-<name>.md` name a file there. To read one:

```bash
git show <commit>:aif/evidence/RESULTS-<name>.md
```

where `<commit>` is the one recorded at the top of the developer docs page *Performance decisions and
rejected experiments*.
