# One `list_set` was declining a loop of eligible reads

**Status: GREEN, 2026-09-05.** Compiler fixpoint from `43107cf` + this change,
LLVM 22.1.8 on Apple Silicon. Suite **285/285**, lint 403 files, `prismio lists`
agree, AIF differential byte-identical to baseline, corpus **0 leaked / 0
violations** on 7/7, seed bootstrap green. Checksums unchanged on every
benchmark.

`benchKnapsack` goes from **3.49x of C++ to 2.55x**, and from 1.17x of Rust to
**0.85x** -- faster than Rust on this workload for the first time.

## 1 · What the loop was paying

The DP loop is 576,000 scalar iterations over a `List<Int>`:

```
let candidate = list_get(best, at - weight) + value
if (candidate > list_get(best, at)) { list_set(best, at, candidate) }
```

Per iteration it emitted **three runtime element-size tests** (`cmp w11, #4;
b.ne <slow>`), six or seven reloads of the `RtList` header, and two bounds
checks. C++'s equivalent is two loads, a compare, a `csel` and a store.

## 2 · Three readings that were wrong, and the one that was not

The handoff proposed that the static element type was not being detected, so
codegen emitted a testing variant instead of a test-free `_inline_scalar` one.
**That is backwards.** `list_get_inline_scalar` *contains* the test by design --
it is the entry point's stated reason for existing, because `list_get_inline`
returns an address for an inline list and the slot's contents for a boxed one,
and only a scalar can tell those apart. The `cmp #4` in the disassembly is that
function, correctly selected and inlined. There was no mis-selection to find.

Nor was the fix a new header hoist: `RESULTS-list-header-hoist.md` already
priced that in the runtime, measured it a wash, and reverted it, concluding the
hoist belongs in codegen. It already is in codegen -- `generateLoopFlatGuard`
folds every flat receiver's `elem_size == stride` into one loop-invariant `i1`
in the preheader and lets LLVM version the loop twice.

The real question was why that guard was not firing on knapsack. A controlled
pair answered it in one step -- the same loop, with and without a write:

| probe | preheader `cmp #4` | loop versioned | `len` hoisted |
|---|---:|---:|---:|
| two `list_get` only | **1** | yes | yes |
| the same plus one `list_set` | **0** | no | no |

`irFlatGuardCount` declines a whole loop on **any** call it does not recognise,
and it recognised only `list_get`. One `list_set` in the body took a loop of
otherwise eligible reads off the flat path entirely.

## 3 · The change

`flatSetScalarStride`: a `list_set(l, i, v)` into a statically typed List of
scalar elements does not decline the loop. It contributes no guard term of its
own -- the write stays on `list_set_inline_scalar` -- it simply stops vetoing
the reads.

**Why it is sound.** No member of the `list_set` family stamps `elem_size`,
grows the block, or reallocates it: the boxed one bounds-checks and stores into
`l->data[index]`, the inline one copies into the existing row, and the scalar one
falls back to the boxed setter when the widths disagree. So the guard proved in
the preheader is still true at every read below it. `list_push` does all three --
`list_push_inline_scalar_slow` calls `list_set_elem_inline` and
`list_inline_grow` -- which is why it must keep declining.

**Scalars only, and not out of timidity.** The struct setter runs
`list_release_source` and the boxed one an `rc_release`; a releaser is user code
that could reach the same list and stamp or grow it behind the guard. A scalar
element has neither. Widening to struct elements is a separate slice with a
separate argument to make.

In the versioned fast loop both reads lose their element-size test. The write
keeps one, because this slice gave the store no guarded path.

## 4 · What it measured

31 alternating samples per binary, in-process `elapsed_ns`, medians and mins.
**The knapsack A/A floor on this harness is 1.0005 min / 1.0075 p50** -- far
tighter than g5's ±6%, which is what makes these readable.

| benchmark | min B/A | p50 B/A | code changed? |
|---|---:|---:|:--|
| **knapsack** | **0.774 / 0.779** | **0.735 / 0.748** | yes |
| fft | 0.874 | 0.877 | yes |
| convolution | 0.920 | 0.921 | yes |
| large_buffer_copy | 0.942 | 0.946 | yes |
| prime_sieve | 1.009 | 0.992 | yes (flat) |
| mergesort | 1.029 | 1.014 | yes (**regression**) |

Cross-language, knapsack, 21 alternating samples:

| | min ns | p50 ns | vs Prismio before | vs Prismio after |
|---|---:|---:|---:|---:|
| cpp | 141,000 | 148,167 | 3.49x | **2.55x** |
| rust | 417,875 | 451,542 | 1.17x | **0.85x** |

Cost is nil: the suite binary is **the same size to the byte**, the compiler
grows 96 bytes (1.00005x), and suite compile time is unchanged at 0.54s.

## 5 · What was rejected

**`gcd_lcm` read 0.868 min / 0.885 p50, reproducibly, across 31 alternating
samples -- and it is not a result.** Its mnemonic sequence is byte-identical
between the two binaries; the symbol simply moved, `0x10000b86c` ->
`0x10000b8f0`, changing its 64-byte alignment from 44 to 48. A per-symbol
mnemonic diff over all 53 `bench*` functions found **exactly 7 changed**, and
`_benchGcdLcm__Int` is not among them.

This is worth more than the win it isn't. The recorded floor for this suite is
±4%; a tight integer loop moved **13%** on identical instructions. Every other
sub-1.0 reading on unchanged code this session -- tree_traversal 0.969,
struct_creation 0.975, nested_collection 0.976 -- is the same effect. **Run the
mnemonic diff before believing any number here**, in either direction.

## 6 · The regression that was kept

`mergesort` costs 1.014x p50 against an A/A floor of 0.9999 / 1.0014, so it is
real. `benchMergeRange` is recursive and holds **four** loops whose trip counts
bottom out at one or two iterations, so each now pays a preheader guard and a
loop it cannot amortise -- the same shape `RESULTS-inline-push-rejected.md`
records, where the check is paid and never wins.

Kept anyway: 1.4% on one benchmark against 27% on knapsack, 12% on fft, 8% on
convolution and 6% on large_buffer_copy, at no compile-time or size cost. There
is no static trip count to gate on, and the push rejection already records that
gating on loop depth does not separate the two cases.

## 7 · What is left

- **The write still tests.** One `cmp #4` per iteration remains in the fast loop,
  for the `list_set`. A guarded flat *store* -- the `ir_list_flat_scalar_elem`
  twin -- is the next slice, and it is what would take the DP loop to C++'s
  shape.
- **`data` still reloads** per access even inside the versioned loop; only
  `elem_size` and `len` hoist. **Do not fix this by hoisting the pointer** --
  `RESULTS-bounds-check-ceiling.md` prices that plan at 1.77x against today's
  1.77x, i.e. nothing. The reload is *caused* by the bounds check making the load
  conditional; one range precondition per loop removes both at once and measures
  1.01x of a raw C array.
- **Struct elements** are still excluded, for the releaser reason in §3.
