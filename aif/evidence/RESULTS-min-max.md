# min/max/abs, and the call that used to cost 1.79x

**Status: GREEN, 2026-09-05.** Compiler fixpoint `c113fa0`, LLVM 22.1.8 on Apple
Silicon. Suite **287/287** (new `test_120_min_max_abs.psm`), lint 411 files,
`prismio lists` agree (555 externs), AIF differential unchanged, corpus **0
leaked / 0 violations** on 7/7, seed bootstrap green, no benchmark regressed.

Three changes, built together because the first two are useless without the third.

## 1 · Why this existed

`knapsack` needed `max`. Prismio had none, and writing one was catastrophic:

| spelling | knapsack, 20 reps | NEON |
|---|---:|---:|
| `if (candidate > list_get(best, at)) { list_set(...) }` | 5,590,208 | 0 |
| hand-inlined max into a local | 4,915,041 | 26 |
| **`maxInt(a, b)` helper, before this work** | **9,441,708** | **0** |
| `maxInt(a, b)` helper, after | 5,068,709 | 26 |
| `__builtin_max` | 5,040,458 | 26 |
| `std.math`'s `max` | 5,040,000 | 26 |

**A two-line helper was 1.79x slower than the branch it replaced.** Not because
of the call -- LLVM inlines it, and the disassembly proves it: no `bl _maxInt`
survives. It was slower because `irFlatGuardCount` declines a loop on any call it
does not recognise, and that decision is made in *Prismio's* codegen, before LLVM
ever runs. The loop lost its representation guard and its range guard, and the
inlining that came later could not give them back.

## 2 · What was built

**`llvm.smax` / `llvm.smin` / `llvm.abs`.** `__builtin_max`, `__builtin_min` and
`__builtin_abs` are sema-owned builtins that lower straight onto the LLVM
intrinsics -- no runtime symbol, no branch, and on LLVM's *trivially
vectorisable* list, which is what lets `smax` widen into a vector loop where a
hand-written icmp/select does not always.

**A guard that looks through safe callees.** A module pass marks every function
whose body **calls nothing and indexes nothing**, and `irFlatGuardCount` stops
declining a loop for calling one. The criterion is deliberately the conservative
one Rust settled on for inferring cross-crate inlinability: no fixed point over
mutual recursion is needed, so one walk answers it. Keyed by source name, and one
unsafe overload poisons the name -- the guard sees a spelling, not a symbol.

**`std.math`.** `max`, `min`, `abs` over the builtins. The wrapper is itself a
call, and it qualifies through the one level of transitivity the pass allows: the
builtins are marked in the same table before the walk runs.

**Inlining was not built, and should not be.** LLVM already does it within the
module; the disassembly above is the evidence. The thing that was missing was
never inlining, it was Prismio's own analysis refusing to look through a call.

## 3 · What it is worth

`knapsack` is **1.06x of C++ and 0.354x of Rust**, with all three arms now
spelling the same statement the same way (`std::max` / `.max()` / `max`).
Checksum `12798` unchanged; all 34 benchmark checksums unchanged; nothing
regressed.

## 4 · The criterion is now an effect analysis, not a syntactic one

The first version admitted a function only if it called nothing and indexed
nothing. That is Rust's cross-crate-inlinability heuristic, and it was the wrong
shape for this question: the guard proves an element representation and an index
range, and **a read cannot change either -- nor can a write.** Only moving the
element block can.

So the pass now classifies by effect:

- **Moves the block:** `list_push` and family, `list_inline_grow`,
  `list_set_elem_inline`, `list_release`, and the reference-count releases, which
  can run a user releaser this pass has not seen.
- **Settled:** `list_get`, `list_set`, `list_len`, `rc_retain`.

A **greatest fixed point** over the call graph propagates the verdict. Every
function with a body starts assumed settled; each sweep takes that away from any
function reaching a block-moving primitive, an unknown `extern fn`, or a `spawn`;
sweeps repeat until stable. Starting optimistic is what admits recursion -- a
function calling only itself moves no block, and a pessimistic start would wait on
itself forever. Termination is immediate: a verdict only ever moves one way.

`test_121_guard_effect_analysis.psm` is the adversarial half. A helper that pushes
to the list under test must decline the guard, and so must one that reaches a
pusher through another call; both are checked, and both fail loudly rather than
quietly, because a stale length past a `list_push` is an out-of-bounds access
rather than a wrong answer. A reading helper and a writing helper must *keep* the
guard, and are checked too -- verified non-vacuously in the IR, not just by the
answers.

## 5 · What is still declined

An unknown `extern fn`, a `spawn`, and anything reaching one. That is the honest
boundary: a body written in another language is not analysable here, and a task
running elsewhere is not this loop's to reason about.
