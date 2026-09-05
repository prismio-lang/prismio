# A general affine index matcher, built and reverted

**Status: REJECTED, 2026-09-05.** Correct, checksums unchanged, suite green --
and slower on six benchmarks and faster on none.

## What was built

`matrix_multiply` is `1.005x min / 1.010x p50` of C++, and its inner loop was
getting the representation guard but not the range guard. The reason was the
index matcher, which accepted only `V`, `V + E` and `V - E` with `E` a bare name
or literal. The loop indexes `a` at `row * n + k` and `b` at `k * n + col`:

- `row * n + k` puts the induction variable on the **right** of the `+`, and its
  left operand is a compound invariant rather than a name.
- `k * n + col` **scales** the induction variable.

So it was generalised to a real affine matcher: invariance closed over `+`, `-`
and `*`; commuted operands; and interval arithmetic for the bounds, including
`[lo, hi] * c` with the factor's non-negativity folded into the same guard,
because the sign of `n` is not a compile-time property.

It worked. Range conjuncts in `benchMatrixMultiply` went from 1 to 3, and the
checksum was unchanged.

## What it measured

| benchmark | min | p50 |
|---|---:|---:|
| large_buffer_copy | **1.088** | 1.080 |
| convolution | 1.028 | 1.025 |
| allocation_mutation | 1.026 | 1.011 |
| fft | 1.014 | 1.018 |
| knapsack | 1.013 | 1.039 |
| **matrix_multiply** | **1.011** | 1.017 |

Nothing improved outside the noise floor, including the benchmark it was built
for.

## Why: a hypothesis, and the two experiments that refuted it

The obvious explanation is that **a preheader guard is paid per loop *entry* and
repaid per *iteration***, and that a wider matcher admits exactly the loops where
those numbers are close. `benchMatrixMultiply`'s `k` loop runs `n` times and is
entered `n^2` times -- 128 iterations against 16,384 entries at scale 4 -- while
`benchKnapsack` is the same shape with the opposite ratio, 180 entries against
576,000 iterations, which is why the guard is worth 26% there.

**That explanation is wrong, or at least not the mechanism here, and it is worth
recording how it failed rather than leaving it standing.**

Two experiments were run against it.

**Making the guard cheaper changed nothing.** The range conjunct called
`list_len`; it was replaced with a direct field load, on the theory that an
opaque call in the middle of the conjunction stops LICM hoisting it out of the
enclosing loop. Measured **1.0003 min / 0.9961 p50** on knapsack and **1.0003 /
0.9999** on matrix_multiply. Reverted. In hindsight the theory could not have
been right: `list_len` is a curated op, so it was already a load after inlining.

**Disabling the guard entirely made matrix_multiply slower, not faster.** With
`generateLoopFlatGuard` returning nothing at all, matrix_multiply measures
**1.0073 min / 1.0125 p50** -- so the guard it already has is a net *benefit*
there of about 0.7%, not a cost. (knapsack, as a control, is **3.11x** slower
with guards off.)

So the guard's absolute cost is not what made the wider matcher unprofitable, and
**the mechanism behind the 1.088x on large_buffer_copy is not isolated.** What is
established is the shape of the result: three more served index sites, measurably
worse on six benchmarks and better on none. That is enough to reject the change
and not enough to explain it.

## What would actually be needed

A trip-count estimate, or a profile. The literature is consistent that
multiversioning pays when the fast version is frequently executed and the win is
significant, and that hoisting checks with two loop versions runs 4-8x on some
kernels at roughly double the code size -- the cost is real and something has to
amortise it. Nothing in the current pass estimates either side of that trade; it
serves every loop whose indices it can prove and hopes.

Re-running this experiment behind a trip-count heuristic is the next honest
attempt. The matcher itself is sound and the diff is recoverable from this
session.

## Kept from the attempt

One genuine bug. `irIsInvariantTerm` rejected names *assigned* in the loop body
but not names **declared** in it, so a body-local `let` looked invariant and the
preheader tried to load a local the backend had never seen -- `internal backend
error: load from unknown local (mid)`. It was latent before this experiment,
reachable through any `list_get(xs, at - localDecl)`. `irBodyBindsName` now
checks declarations as well, and that fix stays.
