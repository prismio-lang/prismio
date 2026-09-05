# MEM-006: the whole-buffer copy is one `llvm.memmove`, and the benchmark it was aimed at is not a copy benchmark

**Status: GREEN, 2026-09-05.** Two-generation byte-identical fixpoint, suite
**291/291** (new `test_124_whole_buffer_copy.psm`), release gate 13 of 14 with the
one failure unchanged from baseline, all 34 checksums byte-identical, `--verify`
0 leaked / 0 violations on every corpus program.

## 1 · What was built

`generateWholeBufferCopy` in `src/ir/expr.psm` recognises

```prismio
while (k < n) {
    list_set(dst, k, list_get(src, k))
    k = k + 1
}
```

and versions the loop in the preheader, exactly as the range guard does. On the
true arm it emits one `ir_list_flat_copy`, which is an `llvm.memmove` over
`(n - k) * stride` bytes; on the false arm the ordinary loop is untouched.

The guard carries every precondition the loop satisfied implicitly, and each is
one arm of the new test: both containers flat at this stride, `k >= 0`,
`k <= n`, `n <= len(dst)` and `n <= len(src)`. **The last two are the ones that
matter.** `list_get` and `list_set` are total, so a bound past either length is
not an error today — reading past `src` yields 0, writing past `dst` does
nothing — and a transfer that ignored the lengths would turn both into memory it
does not own. The induction variable is left at the bound, because code after the
loop may read it.

`memmove` rather than `memcpy` is deliberate: `dst` and `src` are two names and
nothing stops them naming the same list, where a `memcpy` of exactly-coinciding
regions is undefined. On this target both reach the same libsystem entry for a
disjoint copy.

## 2 · Measured

15 alternating samples of in-process `elapsed_ns`. **Three functions changed** by
`tools/fn_mnemonic_diff.py`: `benchLargeBufferCopy` (265 -> 388 insns),
`benchMergeRange` (421 -> 449) and `__stubs`.

| benchmark | min B/A | p50 B/A |
|---|---:|---:|
| mergesort | **0.979** | 0.980 |
| large_buffer_copy | 0.985 - 1.000 | 0.988 - 1.004 |

`mergesort` was not a target. Its merge writes back with
`while (i < high) { list_set(values, i, list_get(scratch, i)); i = i + 1 }`,
which is the same shape.

## 3 · Why `large_buffer_copy` did not move much, and where its time actually is

The spec predicts 20.53 ms -> 6.10 ms from this lever. It is 7.87 ms before and
7.87 ms after, and the reason is that **the copy is not where the benchmark
spends its time.** Phase-timed against a C++20 `-O3` arm of the same three
phases, n = 2,000,000, steady state:

| phase | prismio before | prismio after | cpp |
|---|---:|---:|---:|
| fill (2 x `list_push`) | 2.76 ms | 2.58 ms | **0.61 ms** |
| copy (8 rounds) | 1.35 ms | **1.07 ms** | 0.16 ms |
| checksum (`% 1000000007`) | 5.55 ms | 5.19 ms | 5.04 ms |

The lowering is worth **0.79x on the phase it addresses**. That phase is about
15% of the benchmark. The checksum loop is 60% of it and is already at parity
with C++; the fill loop is 4.2x C++ and is the real gap — two `list_push` calls
per iteration against an indexed store into a pre-sized vector.

**So the 1.43x against C++ on this benchmark is a push-path problem wearing a
copy-benchmark's name.** Do not spend more on the copy.

## 4 · One number in the sweep that is not real, and the check that says so

`gcd_lcm` reads **1.147x min / 1.133x p50**, reproducibly, in both orderings, with
an A/A control of 0.975. `_benchGcdLcm__Int` is **not among the three changed
functions**: it is byte-identical *and at the identical address* — 0x10000c358 in
both binaries — with an inner loop of pure `umull` arithmetic and no calls. The
two binaries differ by 40 bytes, in `__stubs` and in `benchLargeBufferCopy`, both
after it.

There is no mechanism left in the compiler's output for this, so it is placement
or predictor aliasing at the process level. It is recorded rather than explained,
and it is the third time this suite has produced a double-digit reading on
unchanged code. **The mnemonic diff is the arbiter, not the timing.**
