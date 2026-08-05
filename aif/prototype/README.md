# AIF Prototype

A working implementation of the inference engine (`aif.py`) and layout optimiser (`layout.py`), run
against an AST dumped by `prismio dump-ast`. Python 3, no dependencies.

Together they produced every number in [../evidence/](../evidence/).

## Running

```bash
prismio dump-ast ../corpus/g4_ecs_world.psm > g4.json
```

```bash
python aif.py g4.json --owned-collections
```

Other flags: `--masks` (relevant-parameter mask, the H4 indicator), `--ffi retain` (the 33-point
default comparison), `--seal g6_engine` (treat a module as sealed, PIR §5), `--sites 20` (worst
T3/T4 sites with source positions). Without `--owned-collections` you get today's language
semantics instead of AIF's.

```bash
python layout.py g4.json --verbose
```

## Two roles

**Falsification.** It produces the tier distribution, the mask width and the layout decisions with
no codegen at all, so the model can be checked before it is built. That is what
[../evidence/RESULTS-L0-tiers.md](../evidence/RESULTS-L0-tiers.md) is.

**The oracle.** When the engine is ported into the compiler, both run over the same source and their
manifests must agree. That is differential testing against an independent implementation, and it is
the only reliable defence against a transfer function that is subtly wrong — because that failure
mode produces a *silently wrong tier*, not a crash. **Keep this working.**

## What it implements

`aif.py` — INFERENCE §§2–5: the four fact lattices, transfer rules, points-to, round-synchronous
iteration to a fixed point, tier derivation (SPEC §4.2), manifest emission.

`layout.py` — LAYOUT §§2, 4–7: static access profile extraction, machine and cost models, the
candidate space, coordinate-descent search.

## Approximations

Documented at the top of each file. **All are conservative** — they can only raise a tier, never
lower it — so a good number is trustworthy and a bad one may be pessimistic. The two that matter:

- **Flow-insensitive.** A value owned by two variables *sequentially* reads as shared. This is the
  second-largest cause of residue after collections.
- **`n(t)` assumed larger than L3**, since collection length is unknown statically. This **biases
  layout toward SoA**; real lengths would move some choices back to AoS.

## Two bugs found here, both worth remembering

Both were *optimistic*, and optimism in this analysis is unsoundness rather than imprecision:

1. String literals were counted as allocation sites. They lower to LLVM globals — static, never
   allocated — and were **69% of apparent allocation traffic**.
2. An unknown callee returning a reference was modelled as a fresh local allocation, when FFI §5.2
   makes `alias` the default return contract precisely because that assumption is unsafe.
