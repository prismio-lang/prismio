# One flat-List guard per loop, and the tuned-g4 regression it repairs

**Status: GREEN, 2026-08-30.** Compiler `build/loopguard-gen3`, LLVM 22.1.8 on
Apple Silicon. Fixed point, suite **202/202**, AIF differential **19/19**,
`--verify` sweep **0 leaked / 0 violations** on all 30 corpus programs, release
gate PASSED. All checksums unchanged.

This is the second slice of `RESULTS-flat-list-view.md`, and it exists because
the first slice **caused a regression that the release gate could not see.**

## 1 · What the first slice broke

`RESULTS-flat-list-view.md` priced its cost as compile time and binary size and
reported the corpus median as 0.986x. Both were true and both were measured on
the *natural* programs, which is all `milestone_bench.py` builds and all the
release gate's mnemonic diff covers. The five-arm harness also builds the
**hand-tuned** arm, and there:

| g4 arm | unswitch-gen4 | flat-gen3 |
|---|---:|---:|
| natural | 29.469 | 28.481 |
| hand-tuned | **20.539** | **30.059** |

A 46% regression, on the arm that exists specifically to price manual
transformation, in a program that was already the target. Tuned g4 became slower
than natural g4. `tools/fn_mnemonic_diff.py` put it in one function:

```text
CHANGED: _systems_fused__Struct_World_Float  95 -> 121 insns
```

## 2 · Why

`g4_tuned.psm` fuses four systems into one loop over **five** lists. A guard per
`list_get` site is five independent loop-invariant conditions, and LLVM does not
clone a loop 2^5 ways: it versions on one or two and leaves the rest in the body.
So the fused loop kept its representation tests per iteration —

```text
100001d34:  cmp  w17, #0x18
100001d4c:  csel x17, x1, xzr, lo
100001dd8:  cmp  w17, #0x18
```

— and additionally paid a `csel` per site for the bounds check, which the old
code did not have at all: `list_get_inline`'s branch-based check is deleted
outright by the ordinary UB argument when the result is dereferenced.

The first slice's own evidence file predicted the shape of this ("the cost tracks
the number of sites, not the benefit") and proposed the fix. It did not predict
that the cost would show up as *run time* on a fused loop rather than only as
code size, because it never measured the tuned arm.

## 3 · The change

**One conjunctive guard per loop, not one test per site.** Before the loop, every
flat receiver's `elem_size == stride` is ANDed into a single `i1`; every
`list_get` in that loop branches on that one loop-invariant value. LLVM then
versions the loop exactly twice whatever the number of lists.

The lowering now fires **only inside a loop whose guard was proved**. A single
`list_get` outside one keeps calling `list_get_inline`: three basic blocks are
worth their code only where a loop amortises them.

`generateLoopFlatGuard` declines, and the whole loop falls back, when:

- the loop contains **any other call** — it could `list_push` and reallocate the
  element block, which the element type cannot answer; or
- a receiver is not a name or a field read off one, since the preheader evaluates
  it a second time.

## 4 · Result

Twenty-five interleaved runs. Raw: `/tmp/prismio-5arm-loopguard.json`.

| program | new/old | vs Rust idiomatic | was | changed fns |
|---|---:|---:|---:|---:|
| g1 | 0.982x | 1.08x | 1.10x | **0** |
| g2 | **0.958x** | 1.46x | 1.52x | 2 |
| g3 | 1.001x | **0.97x** | 0.97x | 4 |
| g4 | **0.941x** | **1.27x** | 1.35x | 4 |
| g5 | 1.234x | — | — | **0** |
| g6 | **0.933x** | **1.42x** | 1.52x | 3 |
| g9 | 0.999x | **0.91x** | 0.91x | **0** |

**g5 moved 23% on byte-identical code.** Zero changed functions is the control,
and it is why g5 is not claimed in either direction here — the same reason its
own record gives. g1 and g9 are the same control and moved 2% and 0.1%.

The tuned arm, which is the point of this slice:

| tuned | before | after | handoff baseline |
|---|---:|---:|---:|
| g4 | 30.059 | **20.486** | 20.539 |
| g6 | 67.887 | **60.293** | 65.758 |
| g2 | 11.869 | **11.041** | 11.989 |

Tuned g4 is restored, and now beats *idiomatic* Rust at 0.95x.

## 5 · Cost, still uneven and still real

| program | exe | compile (cache off) |
|---|---|---|
| g4 | 96280B -> 96280B (0%) | 0.31s -> 0.32s |
| g2 | 96072B -> 129112B (**+34%**) | 0.48s -> 0.76s (**+58%**) |
| g6 | 97128B -> 130168B (**+34%**) | 0.52s -> 0.83s (**+58%**) |

Gating on the loop did **not** remove this, which was the expectation going in
and is worth recording as refuted: g2's and g6's hot loops do qualify — they call
nothing — so LLVM versions them and the loop body is duplicated. What changed is
what it buys: g6 is 6.7% faster and g2 4.2%, where the per-site version bought g6
2.0%. The trade is a real one and it is a policy decision, not a measurement:
a minimum-flat-sites threshold would decline the loops whose duplication does not
pay, and has not been tried.

## 6 · Two things this cost to find

**An exponential AST walk.** The first collector recursed into `n.next` *and*
called a chain walker that also recursed into `n.next`, visiting the tail of a
k-node sibling chain 2^k times. `tests/test_43_aif_scope_drop.psm` went from 0.2s
to over 90 seconds of 100%-CPU compile. `nodeAssignsName` in the same file has
the correct shape — children through the chain walker, siblings never from the
node function — and the comment there now says why.

**A `List` in the compiler is an `rc_alloc`.** Collecting the receivers into
`List<Ptr>` put two `list_new` sites in the compiler whose escape the analysis
cannot bound through recursion, so they landed T3 and `run_aif_rc_test` refused
the build: every T3 site in this codebase is an opaque extern return, and a
refcount header in front of one is memory nobody allocated. The collector counts
in one walk and emits in a second instead. Walking twice is cheaper than
allocating once here.

## 7 · What the gate could not see, and what to do about it

Neither `milestone_bench.py` nor `release_gate.sh` builds the hand-tuned arm, so
a change that only regresses tuned code passes both. That is how a 46%
regression on g4_tuned survived a green release gate. Until the gate covers it,
**run `tools/five_arm_bench.py` before believing a container or loop change**,
and read the tuned rows.
