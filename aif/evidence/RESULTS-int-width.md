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
