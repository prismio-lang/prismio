# `Int` width — the decision, and the three measurements that made it

**Decision: `Int` stays signed 32-bit, 2026-08-26.** Not by inheritance — the
choice had never been justified anywhere in the tree, only stated
([`src/ast/types.psm:94`](../../src/ast/types.psm)) — and not by analogy to other
languages either. Three measurements on this host decide it, and two of them kill
arguments that were made *for* changing it.

## 1 · What the literature actually claims

| source | choice | stated reason |
|---|---|---|
| [Rust RFC 0212](https://rust-lang.github.io/rfcs/0212-restore-int-fallback.html) | `i32` fallback | "half of the memory of i64 meaning half the memory bandwidth used, half as much cache consumption and twice as much vectorization"; faster multiply/divide; platform-independent |
| [Go](https://groups.google.com/g/golang-nuts/c/AQS9oYoTk_w/m/IR2QP9cV7q4J) | word size (64 on 64-bit) | fastest arithmetic for loop counters and indices; "the length of an array can always be represented by an `int`" |
| [Swift](https://github.com/swiftlang/swift/blob/main/docs/StdlibRationales.rst) | pointer width | "Converging APIs to use `Int` as the default integer type allows users to write fewer explicit type conversions"; 32-bit concerns judged "pretty marginal" |

Go and Swift both argue from **indexing**: a default integer that can address any
array. Rust argues from **density**. Those are testable against each other, and
they are not equally true here.

## 2 · Index width is free. Measured, on both targets.

The theoretical case against a wrapping 32-bit `Int` is real and specific:
LLVM's IndVarSimplify can only widen an i32 induction variable to i64 when it can
rely on `nsw`, and **Prismio emits no `nsw` at all** — `grep -c "add nsw" ` over
g1's emitted IR is 0. So the concern was that Prismio has 32-bit's range limit
*and* pays a sign-extend per index that C does not.

It does not. Same loop, index type varied, `-fwrapv` where the arm is meant to
wrap, checksums identical across all arms (`1998000040/239772002454`):

| arm | stride | saxpy |
|---|---:|---:|
| i32 index, wrapping, i32 data | 0.226 ms | 0.529 ms |
| i32 index, `nsw` allowed, i32 data | 0.225 ms | 0.526 ms |
| i64 index, i32 data | 0.225 ms | 0.526 ms |

Statically, too: AArch64 emits **zero** `sxtw` in the loop for every arm — it
vectorizes with `ldp q4, q5` and folds the extend into addressing. x86-64 emits
exactly **one** `movslq` in all three arms, and it is loop-setup, not per-index.

**The index argument — Go's and Swift's — does not survive contact with this
host.** It may still hold on a target whose addressing modes are weaker; it does
not hold on the two Prismio ships for.

## 3 · Making overflow UB buys nothing. Measured, on real Prismio programs.

If the index argument had held, the fix would have been to emit `nsw` — which
means making `Int` overflow undefined rather than wrapping. That was priced
directly: take the compiler's own emitted IR for three corpus programs, add `nsw`
to every `add`/`sub`/`mul i32`, and compile both with the same `clang -O2`.

The objects genuinely differ (and the `nsw` ones are ~200 bytes *smaller*), so the
flag is reaching the optimizer. The loop time does not move:

| program | plain | `nsw` | ratio | checksums |
|---|---:|---:|---:|---|
| g1 | 21.75 ms | 22.06 ms | 1.014× | agree |
| g3 | 46.10 ms | 46.36 ms | 1.006× | agree |
| g4 | 71.85 ms | 72.23 ms | 1.005× | agree |

**All three are slightly slower.** Trading away defined wrapping semantics — the
thing that makes Prismio's arithmetic predictable — would buy a negative number.
That option is closed.

## 4 · Data width costs 1.33×. Measured, in Prismio.

The remaining argument is Rust's, and it is the one that holds. 20 000 records of
eight integer fields, a step touching four of the eight — the corpus's
narrow-slice shape — 2000 frames, same source with only the field type changed:

| field type | loop |
|---|---:|
| `Int` (32-bit) | **27.15 ms** |
| `I64` (64-bit) | 36.11 ms |
| | **1.330×** |

The C control is larger still, because it isolates streaming from the container:
1.76× on a stride sum and **2.15×** on a vectorizable saxpy.

This is the argument that matters *for this project specifically*. Prismio's whole
measured thesis is layout — AoS vs SoA, inline flat elements, DataView. `Int` is
what goes in the structs those benchmarks are made of. Doubling it halves the
useful bytes per cache line and halves the SIMD lane count, which is exactly what
1.33× and 2.15× are.

## 5 · The cost, stated plainly

**Silent wrapping is real and this session tripped over it three times**, which is
the honest counterweight to §4:

- the g9 Rust ports were written in `i64` first and the checksums disagreed;
- §4's own two arms disagree — the `I64` arm sums to 800 720 000 000 and the
  `Int` arm reports **1 856 082 944**, because it wrapped. That is not a
  measurement error, it is the defect the width makes reachable, appearing
  unprompted in a 40-line benchmark;
- every corpus program declares `extern fn clock_gettime_nsec_np(clk: Int) -> Int`
  against a function returning `uint64_t`. It works only because the code takes a
  *difference* and frames are short.

The standard mitigation is Rust's: check in debug, wrap in release, with explicit
`wrapping_*`/`checked_*` for intent. Priced here with clang's signed-overflow
sanitizer as a stand-in — **4.1× on stride, 4.4× on saxpy** — which confirms it
can only ever be a debug mode, never a default. A native
`llvm.sadd.with.overflow` lowering would be cheaper than a sanitizer, but not
free.

## 6 · Verdict

**Keep `Int` at signed 32-bit.** Both arguments for widening it are measured at
zero on this host, and the argument against widening it is measured at 1.33× on
the exact program shape this project exists to make fast. The full sized family
(`I8 I16 I64`, `U8…U64`) and pointer-width `Isize`/`Usize` are already there for
the cases that need them.

**What this decision leaves owed**, recorded in TODO rather than waved at:

1. a debug-mode overflow check, so §5's wrap is a diagnostic and not a silence;
2. `__builtin_string_len` returns `Int` while `%prismio.str` carries its length in
   **i64** — the read emits `trunc i64 … to i32`. The representation is wider than
   every path that reads it, which is incoherent under either width choice;
3. `clock_gettime_nsec_np` should be declared `-> I64` in the benchmark sources
   and narrowed after the subtraction.

## 7 · Re-examined 2026-09-24: the whole benchmark suite

The v0.1 review asked the question again, so it was measured at the scale §2–§4
could not reach: all 62 workloads of the benchmark suite's **C++ arm**, which is
the same programs on the same LLVM 23 at `-O3`, with plain `int` throughout (574
uses). Prismio itself cannot switch `Int` without changing ~480 of its 717
`extern fn` declarations and the C behind them.

Every `int` became `bint`; A is `std::int32_t`, B `std::int64_t`. Each workload
ran 7 times, interleaved A, B, A, timed in-process; the second A is an A/A
control. All 62 checksums agreed between widths in every run. Three B variants:

| B variant | geomean B/A | control A/A | 64-bit faster >5% | slower >5% |
|---|---|---|---|---|
| all 64-bit, C++ overflow rules | 1.081 | 0.999 | 6 | 33 |
| all 64-bit, `-fwrapv` (Prismio's semantics) | **1.080** | 1.004 | 10 | 30 |
| hybrid, `-fwrapv`: the 49 `vector<int>` element types and 12 struct fields stay 32-bit | **1.032** | 1.007 | 7 | 21 |

| workload | all-64 | all-64 wrap | hybrid |
|---|---|---|---|
| aos_vs_soa | 3.50 | 3.50 | 1.02 |
| convolution | 1.42 | 1.43 | 1.15 |
| large_buffer_copy | 1.36 | 1.34 | 1.16 |
| vector_growth | 1.23 | 1.25 | 1.08 |
| matrix_multiply | 1.13 | 1.12 | 1.13 |
| knapsack | 1.05 | **0.54** | **0.57** |
| fibonacci | 0.93 | 0.93 | 0.93 |

**§4 holds suite-wide.** 64-bit costs 8%, and the cost is storage: keeping stored
elements 32-bit removes more than half of it (3.2%, against a 0.7% control).

**§2 has a counterexample.** On simple strided loops the index width was free; on
knapsack, whose indices are computed (`w - weight`) rather than counted, 32-bit
wrapping arithmetic makes the loop **1.85x slower** than 64-bit. It is one
workload in 62, and ten run 5% or more faster at 64-bit under wrapping. Prismio
now emits `nsw` on range-proved loop counters, which §2 says it did not; computed
indices are still `add i32` and `sext` at each Vec access.

**A cost §5 did not list:** the runtime's Vec header stores `len` and `cap` as C
`int` (runtime/lang_runtime.c), so a Vec holds at most 2^31-1 elements and a
`Vec<U8>` at most 2 GiB. The benchmark sources cast to `I64` 44 times and std 31
times, mostly for checksum arithmetic and time.

What other languages chose, beyond §1: Julia, Nim, Odin and Dart make the one
general integer 64-bit; Java, Kotlin and C# keep 32 and cap every array at 2^31-1
elements; C, C++ and Rust keep 32 and add a separate 64-bit size type. A language
with one integer for arithmetic *and* lengths that stays 32-bit takes the
Java trade.

**Where that leaves the verdict.** §6 stands on performance, which is this
project's deciding axis: 32-bit `Int` is 3-8% faster across the suite. The
alternative is `Int` = 64 with an `I32` for storage (the hybrid row), which gives
up ~3% for no Vec cap and fewer `as I64` casts. Either way §6's first owed item,
a debug-mode overflow check, is what turns the silent wrap into a diagnostic, and
it is still owed.

## 8 · Adaptive width: `Int` means 64 bits, AIF stores it narrow (2026-09-24)

The hypothesis: `Int` is semantically 64-bit, and AIF stores each integer in the
smallest width it fits, widening a container when a value does not. Modelled in
the same harness: every stored integer (the 49 `vector<int>` element types and 12
struct fields) is a 4-byte `nint` whose meaning is 64-bit; scalars are 64-bit. A
store that does not fit reaches a cold widen path (tested: 2^31 widens, 2^31-1
does not). Nothing widened in any benchmark, so this measures the checks alone.

| variant | geomean vs 32-bit | control |
|---|---|---|
| A: `Int` = 32 (today) | 1.000 | |
| B: everything 64-bit | 1.080 | 1.004 |
| C: 32-bit storage, no checks (ideal static narrowing) | 1.032 | 1.007 |
| D: adaptive, branch on every store | 1.052 | 0.997 |
| D3: adaptive, branchless store flag (checked after the loop) | **1.045** | 1.000 |
| D2: adaptive, branch on every store *and* every read (no loop versioning) | 1.116 | 0.998 |

| workload | C static | D branch | D3 branchless | D2 read branch |
|---|---|---|---|---|
| aos_vs_soa | 1.02 | 2.06 | 1.52 | 2.61 |
| edit_distance | 1.16 | 2.29 | 1.23 | 2.33 |
| convolution | 1.15 | 1.32 | 1.26 | 1.42 |
| tree_traversal | 1.01 | 0.92 | 1.11 | 3.68 |
| knapsack | 0.57 | 0.60 | 0.84 | 1.00 |

What it says:

1. **It works, and recovers about half of 64-bit's cost:** 8.0% becomes 4.5%.
   Ideal static narrowing (C) would recover 60%.
2. **The check has to stay out of the loop's branches.** A branch per store
   stops vectorisation: aos_vs_soa 2.06x and edit_distance 2.29x under D, 1.52x
   and 1.23x once the check is a branchless flag. A per-read width branch (D2) is
   worse than simply being 64-bit (1.116 vs 1.080), so the width test has to be
   hoisted to loop entry, the way the bounds-check guard is.
3. **About 3% is intrinsic.** Even with every stored integer 32-bit, lz4
   (1.21), base64 (1.12), monte_carlo (1.13) and polynomial_evaluation (1.10)
   stay slower. Their hot arithmetic is hash mixing and generators whose values
   really exceed 32 bits under 64-bit meaning, so no range proof could narrow them.

**Verdict on the hypothesis:** the best realistic adaptive design is ~4.5%
slower than a 32-bit `Int`, and ~3.5 points faster than a plain 64-bit one. It
buys 64-bit semantics (no 2^31 Vec cap, no `as I64`) for that 4.5%, at the cost
of a sizeable compiler feature (range narrowing, container re-layout on
overflow, loop versioning on width). It does not beat 32-bit on speed.

## 9 · Idea #1: keep `Int` 32-bit, do index arithmetic in 64 bits where it is proved (2026-09-24)

A 32-bit `Int` that the compiler *computes* in 64 bits wherever that provably
changes no result: the meaning stays 32-bit, no ABI moves, and only the arithmetic
that feeds an index is affected. Modelled on Prismio's own output, not on C++:

- the benchmark suite's IR from the compiler at aa0253c, through `opt -passes=sroa`
  so the arithmetic-to-index chains are visible (O3 runs it anyway);
- for every `sext i32 ... to i64`, the `add`/`sub`/`mul`/`shl i32` chain that
  computes its operand is marked `nsw` -- what a range proof would license, and
  what lets LLVM do the index math in 64 bits. 262 operations over 1385 index
  sites. Applied to *all* of them, so this is the upper bound a perfect range
  proof reaches; the checksums are the check that nothing relied on wrapping;
- both arms linked identically (`llvm-link` of the program, the std `.plib`
  bitcode and the runtime bitcode, then `clang -O3 -mllvm
  -enable-nontrivial-unswitch`), within a few percent of `prismio build` on
  knapsack. 7 interleaved runs, A/B/A.

| | result |
|---|---|
| checksums | all 62 identical |
| geomean, 61 workloads (without the one below) | **0.975** (control 1.002) |
| geomean, 56 workloads whose control stayed within 5% | 0.977 |
| knapsack | **0.267**: 147 us to 37 us; C++ 139 us, Rust 423 us, all returning 12798 |
| trie_search | 0.94 |
| gcd_lcm, channel_pipeline, pointer_chase | 1.06, 1.05, 1.03 |
| dead_code_elimination | 18.9x, from 0.2 us to 1.1 us: base folds the whole loop away and the `nsw` on `mul 5000000, %n` leaves about a microsecond of it |

edit_distance (0.83) and recursive_tree_rebuild (0.85) moved by as much in their
A/A controls, so they are noise here.

**Verdict:** the idea is sound, and on this suite it is one large, targeted win:
knapsack 3.7x faster, the rest unchanged. It keeps everything §6 kept -- 32-bit
storage, wrapping semantics, the ABI -- so it is an optimisation, not a language
change. The DCE row says the marking must be selective: `nsw` on a trip-count
multiply can cost a closed-form fold.

### 9.1 · Why knapsack gains 3.7x, and why C++ `int` does not (2026-09-25)

The session that measured §9 left one thing unexplained: C++'s `int` is 32 bits
too, signed overflow is UB there, so `at - weight` is already `sub nsw` in the
C++ arm -- yet that arm ran at 139 us, level with unwidened Prismio. So "widened
Prismio is 3.7x ahead of C++" was a number without a cause. The cause, measured
on the real toolchains (`prismio build`, and `clang++ -O3` of the suite's own
C++):

- **Both 32-bit arms run the scalar loop, always.** Both are vectorised, and
  both put the vector loop behind the same two run-time checks
  (`vector.scevcheck`, then `vector.memcheck`). The memcheck is a *whole-range*
  overlap test between the store's range `best[w..cap]` and the load's range
  `best[0..cap-w]` -- which overlap for every item. So the vector loop never
  runs. Checked directly: the C++ loop with vectorisation disabled
  (`-fno-vectorize`) runs in the same time as with it (372 vs 389 us in a
  standalone copy), and so does a 64-bit-index copy with vectorisation off (407).
- **With a 64-bit index, the check is not there at all.** LLVM's dependence
  analysis needs the distance between `best[at]` and `best[at - weight]` as an
  expression. With `sext(at - weight)` it does not form one and falls back on
  range overlap. C++'s `sub nsw` does not change that: its vectorised loop still
  carries a wrap-predicate check on the 32-bit index before the memcheck. Why
  the flag reaches LLVM from Prismio's IR and not from clang's was not
  established; the outer loop's `weight` is strength-reduced differently in the
  two, which is the likeliest place to look. With the subtraction in 64
  bits the distance is `weight`, a backward dependence the vectoriser can prove
  safe, and it emits no check: standalone, the same C++ goes from 389 us to 82 us
  (4.8x) by changing `int at` to `int64_t at`.
- **Prismio's proved copy has what that needs and C++ does not.** The range guard
  already folds `0 <= at - weight < len` into the preheader, so the subtraction
  provably cannot wrap. Marking it `nsw` in the proved copy is enough: the
  compiled knapsack loses both the scevcheck and the memcheck, and the vector
  loop runs.

So the gain is real, but it is not Prismio against C++'s code generator: it is
the vector loop running at all. The C++ arm as written (`int at`) never runs
its vector loop; C++ written with a 64-bit index (`size_t`, which idiomatic C++
would use) gets the same 4.8x. Claiming "3.7x faster than C++" would be claiming
a win over one spelling of the C++ program. The fair statement is that Prismio
now vectorises this loop from 32-bit source, where C++ needs a 64-bit index to.


### 9.2 · Built (2026-09-25)

`rangeMarkIndex` (src/ir/ranges.psm) marks the `+` and `-` of an index the delta
tier proved, and the proved copy emits them `nsw`; the difference-bound tier
already marked the terms it interprets (`relCommit`). The rule is the congruence
argument: the tier's i64 interval equals the loop's i32 value modulo 2^32, so a
node whose value is inside `Int` *is* the loop's value, and an op whose result
and operands are all inside `Int` cannot have wrapped. Known inside `Int`, from
facts the guard already holds: the index (in `[0, len)`), the operand of `/` and
`%`, and whatever a literal offset carries down from them (`c - 1` in `[0, len)`
puts `c` in `[1, len]`). Nothing else is marked, no fact is added for a mark,
and multiplies are never marked, so the DCE row above cannot recur.

The first version marked only an op whose operands were leaves. That marked
`current + c` but not `current + c - 1` in edit_distance, which left the
vectoriser half the information. The loop was then 22 instructions instead of
27, and it never reached a fast mode that the old code and C++ both hit in about
40% of runs (565 us against 715; 0 of 70 runs). Carrying bounds through literal
offsets marks the whole index: 18 instructions, all four accesses
strength-reduced to pointers, as C++ has them.

Measured with the real toolchain (`prismio build` of the suite by the compiler
at aa0253c and by this one), 9 interleaved A/B/A rounds, in-process `elapsed_ns`:

| | result |
|---|---|
| checksums | all 62 identical |
| knapsack | **142.8 -> 37.6 us (0.263)**; C++ 151 us |
| edit_distance | **748 -> 600 us (0.802)**; C++ median 648 in a 30-run check |
| geomean, 60 others with a control within 5% | 1.009 (control 1.005) |
| IR | 12 of 225 programs change, and only by ` nsw `; the compiler's own IR does not change |

Four rows moved in the full run and were re-measured at 25 rounds: convolution
0.997, recursive_tree_rebuild 0.978, function_call_overhead 1.000, tokenization
0.970. The last three have no code change of their own, only shifted neighbours,
and the full run's outliers were bimodal distributions in both arms.
dead_code_elimination read 1.5x on samples of 0-333 ns, which is the timer's
41 ns tick; its code did not change.

Against §9's upper bound, which marked every chain feeding an index: knapsack
gets all of it (0.263 here, 0.267 there). trie_search, which read 0.94 there,
gets no marks here (its IR is unchanged) and reads 0.968 against a 0.980
control in this run; whether a proof could earn that 6% was not examined.
