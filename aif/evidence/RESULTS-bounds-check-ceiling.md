# What is actually left on a `List<Int>` loop: the check, not the header

**Status: DESIGN STUDY, 2026-09-05.** No compiler change. Seven implementable
designs priced against each other and against a raw C array on the real `RtList`
layout, `clang -O2`, Apple Silicon, 41 reps, min ns, all seven producing
knapsack's checksum `12798`.

**The result overturns two recorded plans and identifies a design that reaches
parity with C.**

## 1 · The measured design space

| # | design | min ns | vs raw C |
|---|---|---:|---:|
| V0 | before `flatSetScalarStride` -- element-size test per access | 505,000 | 2.89x |
| V1 | **today**, after the flat-set change | 309,000 | 1.77x |
| V3 | **the recorded plan**: `(base,len)` hoisted into the preheader | 310,000 | **1.77x** |
| V7 | per-iteration check that *exits* instead of yielding 0 | 252,000 | 1.44x |
| V5 | **one range precondition per loop**, then unchecked access | 176,000 | **1.01x** |
| V6 | V5 plus the `(base,len)` view | 181,000 | 1.03x |
| V2 | no bounds checks at all (unsound; the ceiling) | 173,000 | 0.99x |
| V4 | raw `int*` array, the C++ arm | 175,000 | 1.00x |

## 2 · The recorded plan is worth nothing

`RESULTS-list-header-hoist.md` concluded that the fix "belongs in codegen", and
described emitting `(base, len)` into the preheader and handing them to each
access. **Measured, that is V3: 310,000 against V1's 309,000.** It is not a small
win, it is no win, and it would have been real work.

V6 says the same thing from the other side: once the checks are gone, adding the
view moves 176,000 to 181,000 -- nothing, or slightly worse.

The reason both are flat is the same, and it is the whole finding.

## 3 · Why the header reloads, and what actually fixes it

`l->data` is loaded **only on the in-range path**. A conditional load is one LICM
will not hoist, because it cannot prove the address dereferenceable on the path
that skips it. That is the mechanism the header-hoist file correctly identified.

Its conclusion -- hoist the pointer yourself -- does not follow. **Remove the
condition and LLVM hoists the pointer for you.** In V5 the base lives in `x21`
and `x22` across the whole loop, and the inner loop is eight instructions:

```
ldr  w16, [x22], #-0x4        ; base auto-decrementing, hoisted
ldr  w27, [x21, x24, lsl #2]  ; base hoisted
add  w26, w16, w23
cmp  w26, w27
b.le <next>
str  w26, [x21, x24, lsl #2]
sub  x24, x24, #0x1
cmp/b.le
```

against eighteen for V1, which reloads `len` once and `l->data` twice per
iteration between the two bounds branches. **The bounds check is not a cost
beside the header reload. It is the cause of it.** Pay it once per loop instead
of once per access and both disappear together.

## 4 · Why no LLVM pass will do this for us

`default<O3>,function(irce)` and `,function(loop-predication)` change nothing --
61 memory ops before and after. IRCE is not in the standard pass order and
LLVM's own frontend guidance recommends it for range-checked languages, so it
was the obvious first thing to try. It does not fire here, and the reason is a
**language semantics** fact, not a pass-ordering one:

| check form | loads in the loop, plain `-O2`, no IRCE |
|---|---:|
| out-of-range yields `0` and continues (Prismio) | **15** |
| out-of-range exits (Rust, Java) | **6** |

IRCE, loop predication and HotSpot's range-check elimination all require a check
that is *speculated never to fail* and whose failure leaves the loop. Prismio's
`list_get` is total -- it returns `0` -- so the check produces a value rather
than exiting, the load sits on one arm of a diamond, and every one of these
techniques declines. **The totality of `list_get` is what makes its bounds check
ineliminable by stock LLVM.**

Two further notes, both load-bearing for anyone who retries this:

- **`run_optimization` never runs on a program build.** `g_opt_level` is 0 and
  the function returns immediately; `clang -O2` on the emitted `.ll` does 100% of
  the IR optimisation. An `-O1`/`-O3` in-process pipeline produces byte-identical
  output, and an invalid pass name does not error, because neither is ever
  reached. Adding a pass means adding it to the clang step.
- Julia hit the mirror image of our problem after enabling IRCE -- loops that
  vectorised stopped doing so -- so this is fragile ground even when it works.

## 5 · The design that follows

**Extend the loop's existing preheader `i1` from a representation guard to a
representation-and-range guard.** `generateLoopFlatGuard` already computes one
loop-invariant `i1` and lets LLVM version the loop twice; the true version can
then emit unchecked GEPs. The false version is today's code, so **the total
semantics of `list_get` are unchanged** -- no access in the fast version can be
out of range, and anything not provable takes the arm that still returns `0`.

This is HotSpot's loop predication with a better failure mode: HotSpot must
deoptimise when a hoisted check fails, and Prismio simply keeps both loops.

What it needs that does not exist yet: recognising the loop's induction variable
and its bounds, and relating each index to it affinely (`IV + loop-invariant`).
For knapsack the whole obligation is `capacity < len`.

**Projected, not measured:** the model's V1 -> V5 is 1.76x on the DP loop. The
benchmark is not only that loop, so the honest projection for `knapsack` is
**roughly 1.4x-1.6x of C++, from today's 2.55x** -- and it cannot be confirmed
without building it.

## 6 · If the induction-variable analysis is too much

V7 is the fallback and needs none of it: keep a per-iteration check but make it
**exit to a cold continuation** rather than yield `0`. That alone restores
domination, hoists the base, and measures **1.44x against today's 1.77x** -- a
third of the available win. It costs a resumable slow tail, because the loop has
side effects and cannot simply restart.

## 7 · Sources

- LLVM, *Performance Tips for Frontend Authors* -- "If your language uses range
  checks, consider using the IRCE pass. It is not currently part of the standard
  pass order"; and the note that LICM is limited for loads not in the header.
- OpenJDK HotSpot wiki, *LoopPredication*; Red Hat, *Range check elimination in
  loops in OpenJDK's HotSpot JVM*.
- Bodik, Gupta, Sarkar, *ABCD: Eliminating Array Bounds Checks on Demand*, PLDI 2000.
- Wurthinger, Wimmer, Mossenbock, *Array bounds check elimination for the Java
  HotSpot client compiler*, PPPJ 2007.
- Julia Discourse, *IRCE appreciation and gripes*.

Harness: `scratchpad/ceiling.c`.
