# The loop range guard was not sound, and the bound it used was one too loose

**Status: GREEN, 2026-09-05.** Compiler fixpoint byte-identical over two
generations, suite **290/290** (new `test_123_loop_range_guard_wrap.psm`), lint
415 files, source lists agree, 555 externs all defined, corpus 7/7, release
gate 13 of 14 with the one failure unchanged from the baseline compiler. All 34
benchmark checksums byte-identical.

**`large_buffer_copy` is 0.486x** -- 16.41 ms to 7.97 ms, a 2.06x speedup -- and
no benchmark regressed.

## 1 · The bug

`generateLoopRangeGuards` proves "every index this loop forms lies in [lo, hi]"
from the loop condition and the body's single update to the induction variable.
That reasoning is arithmetic on unbounded integers. The loop runs on a wrapping
32-bit `Int`. Two ways they disagree, both of which emitted an unchecked GEP off
a value the range never contained:

**The update wraps.** `at = at + 2147483647` under `while (at < 3)` reaches
-2147483648 with the condition still true. The guard's conjuncts are `1 >= 0`
and `3 < 4`, both true, so the read was emitted unchecked and the program died
with `SIGSEGV` (exit -11). `aif/evidence/memory-2026-09-05/range_wrap_probe.psm`
is the reproduction.

**The update runs the wrong way.** `irIVStepText` accepted `+` and `-` alike and
returned only the magnitude, on the reasoning that "the direction comes from the
condition". It does not: `at = at - 1` under `while (at < 3)` never approaches
the bound, and the loop indexes off arbitrarily negative values. This one did
not crash. It read adjacent heap and returned plausible answers, which is why it
outlived the first.

Both are the same failure: monotonicity was assumed, never established.

## 2 · The fix, in three parts

**The step's operator is checked.** `irIVStepText` now takes the operator the
condition requires -- `+` going up, `-` going down -- and declines anything else.

**Monotonicity joins the guard.** One conjunct in the same preheader `i1`: the
update performed by the last value the condition admits has to land back inside
`Int`. `hi + step <= 2147483647` going up, `lo - step >= -2147483648` going
down, in i64 where neither can wrap. Every earlier value of the induction
variable lies between that and the initial value, so one conjunct covers the
whole loop.

For the ordinary `while (i < n)` with step 1 this is `sext(n) <= INT32_MAX`,
which instcombine folds to `true`. Verified at -O3: zero occurrences of the
constant survive in the optimised function.

**The bound is exact.** `while (k < n)` admits `n - 1`, not `n`. The guard used
the bound itself and called it "one step stricter than the true extreme, so it
can only decline, never admit". That was true and it was expensive: for a loop
over a whole list, `n == len`, so the conjunct `n < len` is **false at run
time, always**. The canonical loop in the language never took the fast path.
`sub i64 %n, 1` costs nothing and is what `large_buffer_copy` was waiting for.

## 3 · What the exact bound unlocked

`benchLargeBufferCopy`'s guarded arm, from the linked binary:

```
ldr  x8, [x21]              ; source->data, once
ldr  x9, [x20]              ; target->data, once
sub  x10, x9, x8            ; LLVM's own overlap test
cmp  x10, #0x40
b.hs .vector
...
ldp  q0, q1, [x8, #-0x20]   ; 64 bytes per iteration
ldp  q2, q3, [x8], #0x40
stp  q0, q1, [x9, #-0x20]
stp  q2, q3, [x9], #0x40
```

Both `RtList->data` loads are in the preheader and the body touches no header
field. This is MEM-024's acceptance criterion, and the code was already there:
the same block exists in the baseline binary and was never reached, because the
guard selecting it was false.

## 4 · The regression the exact bound exposed, and why it was not the bound's fault

Turning the guard on for `while (k < n)` cost **1.108x on
`ecs_component_update` and 1.108x on `allocation_mutation`**. Both are
struct-element loops, and both were *faster on the slow arm*.

Isolated on the **baseline** compiler, so the measurement owes nothing to this
work. Two runs of the same loop over the same data, differing only in whether
the guard can fire -- a list of exactly `n` cannot satisfy `n < len`, one of
`n + 1` can:

| ecs shape, 200k particles x 20 rounds | min ns | p50 ns |
|---|---:|---:|
| boxed arm (`list_get_inline`) | 2,573,167 | 2,697,083 |
| flat arm (`ir_list_flat_elem`) | 2,925,125 | 2,999,417 |
| **flat / boxed** | **1.137** | **1.112** |

The "fast" path was 14% slower than the one it replaces, and had been for as
long as it existed.

**The cause is that the pointer read had no way to drop its bounds check.**
`ir_list_flat_scalar_elem` and `ir_list_flat_scalar_set` both take
`check_bounds`, and the range conjuncts set it to 0. `ir_list_flat_elem` did
not: it always loaded `len` out of the header and answered the test with a
`select` to null. `len` is an `int`, under the same TBAA leaf as the `i32` the
ecs loop stores into `p.life` through the element it just addressed, so LICM
could not lift that load. The loop reloaded the header every iteration and
stayed scalar.

Giving `ir_list_flat_elem` the same `check_bounds` parameter -- sound by exactly
the argument the scalar twin already rests on, since the conjuncts cover pointer
reads too -- removes the length load and the select together. `benchEcsUpdate`
goes 214 -> 204 instructions, `benchAllocationMutation` 172 -> 164, and both
regressions go away.

## 5 · Measured

15 alternating samples of in-process `elapsed_ns`, whole 34-benchmark sweep.
A/A control on the same binary copied: ±0.5-2.5%.

| benchmark | monotonicity + exact bound | + pointer `check_bounds` |
|---|---:|---:|
| **large_buffer_copy** | **0.479** | **0.486** |
| ecs_component_update | 1.108 | 1.010 |
| allocation_mutation | 1.108 | 1.003 |
| tokenization | 1.081 | 0.995 |
| prime_sieve | 0.964 | 1.050 min / 0.996 p50 |

11 of 455 functions changed, by `tools/fn_mnemonic_diff.py`. **Neither
`benchTokenization` nor `benchPrimeSieve` is among them**, so both of their
numbers are the layout effect this suite produces on byte-identical code -- and
both read as a regression in one column and a win in the other, which is what
that looks like. Run the mnemonic diff before believing anything here.

## 6 · Totality

Nothing in this changes what an out-of-range access does. The guard chooses
between two loops; the false arm is untouched, and `list_get` still returns 0
and `list_set` still does nothing. `test_123_loop_range_guard_wrap.psm` is six
loops the analysis must decline or bound correctly -- a wrapping increment, a
wrapping decrement reached through an invariant offset, both direction
mismatches, and a stride-2 loop it must still serve -- each with one right
answer whether the guard fires or not. It exits -11 on the baseline compiler.

## 7 · The TBAA audit (MEM-024), in full

Every `LLVMBuildStore` in `runtime/llvm-api-backend.c`:

| site | tagged | note |
|---|---|---|
| `ir_list_flat_scalar_set` element store | `tag_scalar(elem_type)` | the MEM-024 fix, already in the tree |
| `ir_list_flat_push` length bump | `tag_scalar("i32")` | |
| `ir_store_ptr` | `tag_scalar(type)` | |
| `ir_struct_store_ptr` | struct-path | |
| `ir_data_store_ptr` | DataView column leaf | |
| cold-record link (x2) | struct-path | |
| `str_data_ptr` scratch (x3) | **deliberately untagged** | i64/i32/i8 overlap in one 16-byte scratch; a tag would assert NoAlias between writes that alias by construction |
| `ir_str_inline` copy ladder (x8) | **deliberately untagged** | same |
| `ir_store` (local alloca) | untagged | mem2reg promotes these before LICM runs |
| `ir_store_global` / `ir_load_global` | **untagged, open** | see below |

**No store into list element storage is untagged.** The one open item is
`ir_store_global`: two of its three emission sites are the once-per-program
`prismio_argc` / `prismio_argv` prologue stores, and the third is assignment to
a module-level `let mut`. Tagging it is sound by the same argument as
`ir_store_ptr` and costs four lines, but no benchmark has a mutable global in a
hot loop, so there is nothing here to measure it against. It belongs with a
workload that has one.

## 8 · A harness trap, recorded because it cost an hour

`tools/run_suite.py --compiler X` **does not compile the file fixtures with X**
when run inside the repository. It copies X to a temporary file *named
`prismio`*, and `isGlobalLauncher()` in `src/project/ums_cli.psm` makes any
binary of that name forward the whole command to `.prismio/build/debug/prismio`.
Proof: with the new compiler promoted to that path, `--compiler build/s0-gen2`
-- the compiler with the bug -- passes `test_123`.

Promote the candidate to `.prismio/build/debug/prismio` before running the
suite, or use `PRISMIO=$PWD/build/gen2 python3 tests/test_runner.py`, whose
binary is not named `prismio` and therefore does not redirect.

## 9 · Cross-language, on the final compiler

`benchmarks/run.py --runs 9`, medians of in-process `elapsed_ns`.

| benchmark | prismio ns | cpp ns | rust ns | vs C++ | vs Rust |
|---|---:|---:|---:|---:|---:|
| knapsack | 223,708 | 209,250 | 618,958 | 1.069 | **0.361** |
| ecs_component_update | 3,291,583 | 3,352,792 | 3,159,209 | **0.982** | 1.042 |
| allocation_mutation | 6,810,625 | 6,275,625 | 6,143,166 | 1.085 | 1.109 |
| large_buffer_copy | 7,874,875 | 5,513,125 | 6,381,167 | 1.428 | 1.234 |

`large_buffer_copy` was around 2.9x of C++ before this and is 1.43x now. The rest
of that gap is MEM-006: LLVM vectorised the copy but did not turn it into a
`memcpy`, and the loop still pays a per-iteration store-forward chain a real
`llvm.memcpy` would not. That is Stage 1's Task 1.2, not this one.

## 10 · Task 1.3 (MEM-011), curating `list_push_slot`: it works, and it loses

**Status: REFUTED, 2026-09-05. The curation is reverted; the split it needed is
kept.**

The spec's acceptance criterion is reachable. `list_push_slot` could not be
curated because `rt_alloc` drags `rt_arena_hint`, `arena_depth` and
`arena_alloc_slot` — all `static` — into its body, which is the closure violation
`run_curated_closure_test` exists to catch. Outlining the boxed fallback into an
exported `list_push_slot_boxed` closes it, and **`PRISMIO_NOINLINE` on that
outline is load-bearing**: two calls is under clang's threshold, so -O2 folded the
outline straight back in and the violation returned invisibly. With both,
`benchStructCreation`'s hot loop is Rust's shape —

```
ldr  w8, [x19, #0x24]      ; elem_size
cbz  w8, <stamp>
ldp  w9, w10, [x19, #0x8]  ; len, cap
cmp  w9, w10
b.ge <grow>
ldr  x10, [x19]
smaddl x0, w9, w8, x10     ; slot = data + len*elem_size
```

— and the `bl _list_push_slot` is gone from every push loop in the suite.

**It is still a loss.** `struct_creation` 0.984, `allocation_mutation` 0.998,
`ecs_component_update` 1.004 — and on the corpus, `tools/fn_mnemonic_diff.py`
reproduces `RESULTS-inline-push-rejected.md` exactly:

| g6_game function | before | after |
|---|---:|---:|
| `world_spawn` | 37 | **115** |
| `recruit` | 57 | **160** |
| `plan_orders` | 78 | 104 |

That evidence file rejected the same shape at 1.275x, and it named the reason:
`plan_orders` builds a fresh short-lived list per squad per frame, so almost every
push is a growth and the check is paid without ever winning. Letting the *inliner*
place the check instead of codegen does not change that.

**The static proxy for the profile it asks for does not exist either.** A capacity
hint would be the obvious discriminator — a list built with
`list_new_with_capacity(n)` takes the fast arm by construction — but g2's `cull`
and g6's `plan_orders` both use bare `list_new()`, so that gate separates neither.
The benchmarks that *do* use a capacity hint are the three above, worth 1.6% on one
of them.

**What is kept.** The `list_push_slot_boxed` split, so the curated set stays closed
with `list_push_slot` in it and turning this on is one line in
`PRISMIO_CURATED_OPS`. `../../docs/KNOWN_ISSUES.md` records that the blocker is now
performance rather than linkage. The prize behind it is unchanged and still
locked: struct-path TBAA on literal initialisers, 0.76x on g2 when the slot is
computed inline (`RESULTS-M6-struct-path-tbaa.md`).
