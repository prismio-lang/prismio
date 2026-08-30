# The flat-list element view: codegen keeps the stride it already computed

**Status: GREEN, 2026-08-30.** Compiler `build/flat-gen3`, LLVM 22.1.8 on Apple
Silicon. Fixed point, suite **202/202**, AIF differential **19/19**, `--verify`
sweep **0 leaked / 0 violations** on all 30 corpus programs, release gate PASSED.
All checksums unchanged.

This continues `RESULTS-loop-unswitch.md`. That change enabled LLVM's
non-trivial unswitching and took g4 by 11-14%. This one asks why it did not take
more, answers from the machine code, and moves the decision into Prismio IR.

## What the unswitched code actually looked like

The premise on record was that LLVM leaves the inline/boxed choice in the loop
body. The disassembly of `system_movement` says something narrower and more
useful. Header loads *are* hoisted -- M6's scalar TBAA is what allows it, since
a `store double` cannot alias an `i32` length -- and the loop *was* versioned.
Once:

```text
100001cb4:  cbz  w11, ...          ; versioned on velocities->elem_size
...
100001d00:  mov  x14, x10
100001d04:  cbnz w9, 0x100001cc4   ; positions->elem_size, still per iteration
100001d08:  ldr  x14, [x13]
```

Two lists, two loop-invariant representation tests, and LLVM cloned the loop for
one of them. The other stayed in the body. Both versions also advanced by a
*loaded* stride:

```text
100001cec:  add  x12, x12, x11     ; velocities stride, from the header
100001cf4:  add  x10, x10, x9      ; positions stride, from the header
```

Neither fact is discoverable to LLVM at a useful cost, and both are already
known to Prismio. `inlineElemSizeOfList` returns `ir_struct_size` of the element
type at every `list_get` site and then uses it only to pick a function *name*.
`list_get_inline` re-derives the same number from the header on every access.
`lang_runtime.c`'s own note on `elem_size` makes exactly this argument for the
entry points -- "the element type is a static fact at every call site, so the
branch belongs at compile time" -- and the branch that stayed *inside* the
inline entry point is the one this removes.

## The change

`ir_list_flat_elem` in `runtime/llvm-api-backend.c`, reached from `expr.psm`
when `list_get`'s receiver has a flat, uncounted element type:

```text
%es   = load i32  (elem_size)
%flat = icmp eq i32 %es, <stride>        ; an immediate
br %flat, flat, boxed
flat:   %in = icmp ult %idx, (len)
        %a  = gep i8, (data), sext(%idx) * <stride>
        %v1 = select %in, %a, null
boxed:  %v2 = call list_get_inline(%hdr, %idx)
join:   phi [%v1, flat], [%v2, boxed]
```

**The guard is `== stride`, not `!= 0`, and the false arm is the function it
replaces.** The static fact is weaker than the dynamic one: codegen knows the
element *type* is inline-eligible, not that this *list* is stamped inline -- the
stamp is lazy, and `PRISMIO_INLINE_ELEMS=0` leaves every list boxed. So the
specialisation fires only on the case `list_get_inline` would have answered with
`data + i * stride`, and every other case is still answered by
`list_get_inline`. That is what makes it semantics-preserving by construction
rather than by argument.

No offset is written down. `RtList` is mirrored as an LLVM struct type and the
addresses come from `LLVMBuildStructGEP2`, so the byte offsets are the module
data layout's answer. Hardcoding `elem_size` at 36 would have been correct on
every host this is measured on and silently wrong on wasm32.

### A select, not a branch

The bounds test was written first as a branch to a null-returning edge, which is
what `list_get_inline` does and reads as the more faithful translation. It is
worse, and not marginally: the extra control flow in that block left the
*second* list's representation test unhoisted, so the loop came back with
`cmp w10, #0x18` per iteration, a reloaded `data`, and `madd` in place of the
constant-stride post-index. Two straight-line instructions buy four versions of a
branch-free loop.

## What the loop looks like now

```text
100001cac:  cmp  w12, #0x18         ; both guards, in the preheader
100001cb0:  b.ne ...
100001cbc:  cmp  w9,  #0x18
100001cc0:  b.ne ...
...
100001ce8:  str  d1, [x10], #0x18   ; constant stride, post-indexed
100001cf0:  ldr  q2, [x12], #0x18
```

No `elem_size` test in the body, and both strides are immediates. LLVM now
versions on both lists, because each guard is an `icmp eq` against a constant on
an already-hoisted load.

## Measurement

Twenty-five interleaved runs per pair, `tools/milestone_bench.py`, host settled.
Raw: `/tmp/prismio-flat-list-ab2.json`, `/tmp/prismio-flat-vs-rc.json`,
A/A floor `/tmp/prismio-flat-aa.json`.

**Read the A/A floor first.** On this host: g1 0.990x, g2 0.999x, g3 1.000x,
g4 1.011x, g5 0.922x, g6 0.966x, g9 1.001x.

| program | vs `unswitch-gen4` | vs `v0.1-rc` (pre-unswitch) | mnemonic diff |
|---|---:|---:|---:|
| g1 | 1.022x | 1.016x | **0 functions changed** |
| g2 | **0.951x** | 0.965x | 2 |
| g3 | 0.986x | 0.983x | 5 |
| g4 | **0.962x** | **0.852x** | 5 |
| g5 | 1.000x | 1.065x | 4 |
| g6 | 0.980x | 0.967x | 10 |
| g9 | 1.001x | 1.000x | **0 functions changed** |
| **median** | **0.986x** | **0.983x** | |

g4 is **14.8% faster than the pre-unswitch compiler**, against a gate of 8%.

g1 and g9 emit byte-identical code -- zero functions changed -- and still read
1.02x and 1.00x. That is this host's noise, stated by a control rather than
estimated. g5 moves less than its own A/A floor and is not claimable in either
direction, exactly as its record says.

**A first A/B of this change reported g4 at 1.077x -- a regression -- and g1 at
1.062x on a binary with no changed functions.** It was run on a host hot from
three bootstraps. The A/A calibration and the mnemonic diff are what caught it;
the timing alone would have rejected a 14.8% win.

## Cost, which is real and uneven

| program | compile (obj cache off) | executable |
|---|---:|---:|
| g4 | 0.31s -> 0.31s (0%) | 96280B -> 96280B (0%) |
| g2 | 0.48s -> 0.76s (**+58%**) | 96072B -> 129112B (**+34%**) |
| g6 | 0.51s -> 0.81s (**+59%**) | 97128B -> 130168B (**+34%**) |

The program this was built for pays nothing; two programs that were not pay a
lot. Each `list_get` site now expands into three blocks, and LLVM versions a loop
around each invariant guard it finds there -- so the cost tracks the number of
sites, not the benefit. g2 buys 4.9% with it and g6 buys 2.0%.

This is the argument for the next slice rather than a reason to revert: one
conjunctive guard per *loop*, formed from every flat receiver in it, versions the
loop twice instead of once per site. Prismio can see all of them at once, which
is the whole advantage it has over LLVM here.

## What this does not do

- **It does not remove the `-mllvm -enable-nontrivial-unswitch` flag.** The
  guards are cheaper and LLVM now takes all of them, but hoisting them out of the
  loop is still LLVM's decision, not Prismio's. Step 2 of the handoff's order --
  "replace reliance on global unswitch" -- is not finished.
- **`list_set` is untouched.** g4 writes through the pointer `list_get` already
  returns, so the four systems are covered by the read.
- Slices, nested lists, and a receiver a call in the loop can reallocate all keep
  the runtime path. None of them is answered by the element type alone.

## Reproducing

```sh
python3 runtime/generate_embedded_sources.py
python3 tools/check_source_lists.py
bash tools/bootstrap.sh --compiler build/unswitch-gen4 --out build/flat-gen1
bash tools/bootstrap.sh --compiler build/flat-gen1 --out build/flat-gen2 --keep
bash tools/bootstrap.sh --compiler build/flat-gen2 --out build/flat-gen3 --keep
cmp build/.bootstrap-flat-gen2/compiler.ll build/.bootstrap-flat-gen3/compiler.ll
PRISMIO=$PWD/build/flat-gen3 python3 tests/test_runner.py
python3 tools/aif_differential.py --compiler build/flat-gen3
bash tools/release_gate.sh --rc build/flat-gen3 --old build/unswitch-gen4
python3 tools/milestone_bench.py --old build/unswitch-gen4 --new build/flat-gen3 \
    --runs 25 --calibrate --skip-baselines
python3 tools/milestone_bench.py --old build/unswitch-gen4 --new build/flat-gen3 \
    --runs 25 --label flat-list-view --skip-baselines
```

## A note on `PRISMIO_INLINE_ELEMS=0`

The boxed fallback is exercised and correct: g4's checksums are identical with it
set. The full suite under it reports **197/202**, and the same five failures
appear on `build/unswitch-gen4` -- they predate this change and are not evidence
about it. They are worth their own entry; see `KNOWN_ISSUES.md`.
