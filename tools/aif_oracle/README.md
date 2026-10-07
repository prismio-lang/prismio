# AIF oracle

An independent Python implementation of the memory-model analysis: the inference engine (`aif.py`,
INFERENCE sections 2-5 and tier derivation per SPEC 4.2) and the layout optimiser (`layout.py`,
LAYOUT sections 2 and 4-7). It shares no code with the in-compiler engine in `src/aif/` and
`runtime/aif_support.c`, which is the point: `tools/aif_differential.py` runs both over the same sources
and their tier distributions must agree.

That is differential testing against an independent implementation, and it is the only reliable
defence against a transfer function that is subtly wrong, because that failure mode produces a
*silently wrong tier* rather than a crash. **Keep this working.** A rule changed in the compiler is
changed here in the same commit.

## Running it

```bash
python3 tools/aif_differential.py --compiler <compiler>          # every default source, both modes
prismio dump-ast tests/test_44_aif_region.psm > region.json       # the oracle reads an AST dump
python3 tools/aif_oracle/aif.py region.json --owned-collections
python3 tools/aif_oracle/layout.py region.json --verbose
```

Other flags: `--masks`, `--ffi retain`, `--seal <module>` (treat a module as sealed), `--sites N`
(the worst T3/T4 sites with source positions). Without `--owned-collections` the oracle uses the
language's current semantics. Python 3, no dependencies.

## Approximations

Documented at the top of each file, and **all conservative**: they can only raise a tier, never lower
it, so a good number is trustworthy and a bad one may be pessimistic.

- **Flow-insensitive.** A value owned by two variables *sequentially* reads as shared.
- **`n(t)` assumed larger than L3**, since a collection's length is unknown statically. This biases
  layout toward SoA; real lengths would move some choices back to AoS.

## Two bugs found here, both worth remembering

Both were *optimistic*, and optimism in this analysis is unsoundness rather than imprecision:

1. String literals were counted as allocation sites. They lower to LLVM globals (static, never
   allocated) and were 69% of the apparent allocation traffic.
2. An unknown callee returning a reference was modelled as a fresh local allocation, when FFI 5.2
   makes `alias` the default return contract precisely because that assumption is unsafe.
