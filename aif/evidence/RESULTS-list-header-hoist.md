# Hoisting the List header out of the loop: what worked, what did not, and the
# noise floor that decided it

**Status: NEUTRAL. One half kept for simplicity, one half reverted.**
Compiler `build/ucmp-gen1`, LLVM 22.1.8 on Apple Silicon.

## The finding

Reading g5_tuned's render loop against Rust's, per the handoff's research rule:

```rust
for &i in bucket {                       // slice iteration: base resolved once,
    let e = &scene.entities[i as usize]; // no per-element bounds check
```

```text
Prismio, per element and per list:
  ldr w4, [x3, #0x8]      ; reload items->len
  ldr x4, [x3]            ; reload items->data
  ldr w5, [x2, #0x8]      ; reload entities->len
  ldr x5, [x2]            ; reload entities->data
```

Three lists are indexed per iteration, so this is six redundant loads. The cause
is in `list_get`:

```c
if (index < 0 || index >= l->len) return 0;
return l->data[index];      // <- loaded only on the in-range path
```

`l->data` is a **conditional** load, and LICM will not hoist one out of a loop
unless it can prove the address dereferenceable — which it cannot for an opaque
list handle. That is a real mechanism, and it is why the reloads are there.

## What was tried

**(a) Read `data` and `len` into locals before the bounds test.** This works:
both bases move to the preheader and the loop uses them.

**(b) Collapse `index < 0 || index >= len` into one unsigned compare.** Needed
alongside (a), and interesting on its own: with the signed pair LLVM evaluates
`index < 0` first, needs no memory for it, and *sinks* the `len` load into the
branch that uses it — undoing (a) for `len`. With one unsigned compare, `len` is
unconditionally needed and hoists.

Together they took g5's inner loop from about 13 instructions to 9.

## What the measurement said

Wall-clock A/B, 15 balanced rounds, and then the same harness run A/A on
identical binaries:

| tuned program | (a)+(b) | (b) alone | **A/A floor** |
|---|---:|---:|---:|
| g5_tuned | 0.963x | 0.953x | **0.942x** |
| g3_tuned | 1.001x | 1.027x | 1.015x |
| g2_tuned | **1.021x** | 0.993x | 1.012x |
| g6_tuned | 1.000x | 1.002x | 1.008x |
| g4_tuned | **1.029x** | 1.002x | 1.007x |

**g5_tuned's A/A floor is 0.942x.** Every apparent win on it — 0.963x, 0.953x —
is inside that. Nothing in this table is a result.

(a) additionally cost a consistent 1.01-1.02x on the natural arms and 1.02-1.03x
on g2_tuned and g4_tuned, which is outside their tighter floors. **The
speculative load costs more elsewhere than the hoist saves**, so (a) is reverted.
(b) is kept: one compare instead of two on the hottest read in the language, with
no path that does more work.

## What this leaves for the real fix

The mechanism is still true and the redundant loads are still there. LICM cannot
hoist them, and making them unconditional in C trades one cost for another.

**It belongs in codegen, not in the runtime.** Prismio already proves a list
receiver loop-invariant when it emits the per-loop flat guard
(`generateLoopFlatGuard`, `RESULTS-flat-list-loop-guard.md`); the same analysis
can emit `(base, len)` into the preheader and hand them to each access, which is
what Gap 2's original `(base pointer, logical length, element stride,
representation guard)` view described. That version pays no speculative load,
because the hoist is unconditional by construction rather than by hoping LICM
will speculate.

Blocking that today: the guard declines any loop containing another call, and
g5's three receivers are all *boxed* — `List<Int>`, and two split types that
`ir_struct_is_flat` refuses — so the flat view does not apply to them at all.
Extending the loop view to boxed receivers is the prerequisite.

## Note on measuring g5 at all

`g5_tuned` has a **±6% A/A floor** on this harness. The handoff already records a
false 1.266x on g5 from an earlier session. Do not accept or reject anything on
g5 alone, and calibrate before reading it — three separate g5 numbers this
session (1.234x, 1.092x, 0.953x) were all noise.
