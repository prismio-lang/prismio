# Float reductions — an accumulator's sum is unordered

**Status:** built 2026-11-11 with D1 (default on), D2 (`--strict-float`, a `strictFloat` profile key, no
syntax) and D3 (no products) taken as recommended. The analysis is `src/ir/reductions.psm`, the harness
check `run_float_reductions_test` and the fixture `tests/test_386_float_reductions.psm`. Left: x86-64
measurement, the new hosted arms (§6), and the two doc apps.

## 1 · The proposal in one paragraph

Inside a loop, a `Float` local that the loop only ever updates as `acc = acc + e`, `acc += e`,
`acc = acc - e` or `acc -= e`, with `e` not reading `acc`, is a **reduction**: the language allows
its terms to be added in any grouping. The compiler marks exactly those adds `reassoc`, which is
the one flag LLVM's vectorizer needs to split the sum into SIMD lanes. Nothing else changes. Any
loop that reads the accumulator for another purpose keeps sequential order, including Kahan
summation and time-stepping. C++ and Rust cannot do this. Both promise sequential IEEE order for
`+=`, so their way out is a whole-file `-ffast-math` (C++) or hand-split accumulators (Rust).

## 2 · Evidence

Method: `PRISMIO_SAVE_IR` of the program, `reassoc` added by hand to the accumulator's
`fadd`/`fmuladd` only, then `opt -passes=internalize,globaldce` + `clang -O3` for both arms. The
unmodified arm ran within 1% of the real build. Apple Silicon (arm64), LLVM 23.1.5, medians of
15–31 interleaved runs, with an identical-binary control.

| Kernel | Sequential (today) | Reduction | Ratio | C++ / Rust (idiomatic) |
|---|---:|---:|---:|---|
| `numerical_integration` (hosted suite) | 2.187 ms | 1.114 ms | **0.509×** | 2.262 / 2.227 ms, so **0.49× / 0.50×** of them |
| plain sum of 1M `Float`s ×20 | 9.846 ms | 1.576 ms | **0.160×** | — |
| dot product of 1M ×20 (`sum += a[i] * b[i]`, an `fmuladd`) | 10.122 ms | 2.838 ms | **0.280×** | — |
| `max` of 1M ×20 (`best = best.max(a[i])`) | 2.408 ms | — | already vectorized | needs no flag (`llvm.maxnum`) |

- **Only the accumulator op needs the flag.** `reassoc` on the accumulator add alone (0.509×) gave
  the same result as `reassoc nsz` on every `fadd` in the function (0.510×). Neither `nsz` nor
  `nnan`/`ninf` is needed, so infinity, NaN and signed-zero handling are untouched.
- **Accuracy did not get worse.** The vectorizer used 2 lanes × 4 interleaved = 8 partial sums,
  then a pairwise tree. An exact Python model of that order reproduces both printed results
  digit-for-digit. Against the exactly-rounded sum:

  | Kernel | Sequential error | 8-lane error |
  |---|---:|---:|
  | harmonic sum, 1M terms | −414 ulp | **−52 ulp** |
  | dot product, 1M terms | −40 ulp | +38 ulp |

  Partial sums grow the rounding-error bound more slowly than one long chain, so this is the
  expected direction, not luck.
- **Not measured yet:** x86-64; `F32` (4 lanes on NEON, so likely a larger ratio); a corpus count
  of how many loops take the mark.

## 3 · The rule

Spec text, replacing the contraction sentence in `specification/behavior.md` ("Numeric behavior"):

> The compiler may contract `a * b + c` into a fused multiply-add. A *loop reduction* is a local
> of float type, declared outside a loop, that the loop's body references only as `x = x + e`,
> `x = x - e`, `x += e` or `x -= e`, where `e` does not reference `x`. For one execution of that
> loop, the terms of a loop reduction may be added in any grouping and order. Every term is still
> computed and added exactly once.

What the shape includes and excludes, each of which needs a test:

| Shape | Reduction? | Why |
|---|---|---|
| `sum += a[i]`, `sum = sum + f(i)` | yes | |
| `sum += a[i] * b[i]` (an `fmuladd`) | yes | LLVM's `FMulAdd` recurrence |
| `sum -= a[i]` | yes | `x - e` is `x + (−e)` |
| `if (c) { sum += a[i] }` | yes | every reference is an update; LLVM vectorizes it as a select |
| two updates in one body (`s += x` … `s += y`) | yes | both are terms of the same sum |
| update inside an inner loop, `s` read in the outer loop | yes, for the inner loop | the rule is per loop execution |
| Kahan: `t = sum + y; c = (t - sum) - y; sum = t` | **no** | `sum` is read outside an update |
| time-stepping: `t += dt; x = f(t)` | **no** | `t` is read |
| `sum = sum * 0.5 + x` | **no** | not `x ± e`; `e` would read `sum` |
| `sum = e - sum` | **no** | not the shape |
| `prod *= a[i]` | not in v1 | see §5, D3 |
| `Int` accumulators | unaffected | integer add is already associative; LLVM vectorizes them today |

Determinism: the same source, compiler, target and flags give the same bits, because LLVM's
choice of lanes is deterministic. Different targets can differ in the last bits. That is already
true today, since `contract` fuses on AArch64 (FMA always present) and does not on baseline
x86-64 (no FMA), so this adds no new class of non-portability.

## 4 · Implementation

1. **Backend entry point.** `ir_fp_mark_reassoc(temp)` in `runtime/llvm-api-backend.c`: if the
   value is an instruction (a folded constant has no flags; see `set_fp_contract`), OR in
   `reassoc` (`1 << 0`). It must reach the `llvm.fmuladd` call built by `fuse_multiply` as well as
   a plain `fadd`/`fsub`. Declare it in `src/ir/bridge.psm`, and keep `tools/check_externs.py`
   green. It is additive, so the seed is untouched. If the host refuses the new runtime (it has
   after a runtime edit before), bootstrap from a bare generation, then promote.
2. **Analysis.** A new `src/ir/reductions.psm`, run beside `nowrapAnalyse` at `module.psm:419`
   under the same `irFunctionHasLoop` gate. For each `for`/`while`/`repeat` body, key each float
   local by its declaration (`symbols.bindings`, as nowrap does, not by name; shadowing is the
   trap). Collect every reference to it inside the body. If each reference is the target, or the
   left operand, of an update of the §3 shape, and `e` references nothing bound to that
   declaration, mark the update's `BINARY_EXPR` through a side table keyed by node pointer and pass
   id (`ir_nowrap_of`'s pattern). `+=` reaches codegen as an `ASSIGNMENT_STATEMENT` holding a
   combined binary (`parseCompoundAssignment`, `src/parse/stmt.psm:131`), so it is the same shape.
3. **Codegen.** In `generateBinary`'s float branch (`src/ir/expr.psm:4597`), after `ir_fadd`/
   `ir_fsub`, call `ir_fp_mark_reassoc` when the node is marked.
4. **Opt-out.** `--strict-float` turns the analysis off for a build (a `profiles` key in
   `build.ums` too). Whether it should be per scope is D2.
5. **Trace.** `PRISMIO_REDUCTION_TRACE=1` prints each marked site as `file:line`, to audit `std/`
   and `src/` once. `std/float_text.psm` must take no mark, since correct rounding there depends on
   order. Its accumulators read themselves (`v = v * 10 + d`), so the shape already excludes them;
   the trace is how to confirm it.

## 5 · Decisions for the maintainer

- **D1 · Default or opt-in.** Recommended: **default**, for the narrow shape only. Accuracy
  measured equal or better, the shape excludes every order-sensitive idiom by construction, the
  spec already licenses contraction, and performance is the project's deciding criterion. The
  alternative is opt-in, either a scoped float mode (as Zig's `@setFloatMode`) or reductions only
  through std methods (`.sum()`, `.dot()`). It is safer to explain, but leaves every naive loop
  sequential, which is the case that beats C++ and Rust.
- **D2 · How to opt out.** `--strict-float` per build (no syntax, no seed step) is enough to ship.
  A scoped form needs new syntax, so it lands in two steps: teach the parser, cut a seed, *then*
  use it in `src/`.
- **D3 · Products.** `prod *= a[i]` vectorizes the same way, but over/underflow is far more
  order-sensitive than in a sum. Recommended: leave it out of v1 and add it only on a measured
  need.

## 6 · Done when

- `tests/test_NNN_float_reductions.psm`: answers for every §3 shape, compared with a tolerance
  where the grouping is free. A harness check in `tests/test_runner.py` (as
  `run_proved_index_nsw_test`) asserts `reassoc` on exactly the "yes" rows and nowhere else.
- `numerical_integration` ≤ 0.55× its current time in `prismio bench`, with C++ and Rust arms
  unchanged. New hosted arms for a float sum and dot product in all three languages, written
  idiomatically (no `-ffast-math`, no manual accumulators), with matching checksums by tolerance.
- x86-64 measured (a Linux or Windows CI run, or the VM).
- Two generations to a fixpoint. The compiler's own IR changes only where the trace shows a mark,
  and `tools/aif_differential.py` is green. This is a behaviour change, so suite expectations that
  move must each be explained, not regenerated.
- Both doc apps updated: the spec sentence above, the operators/types pages, and the release notes
  with the numbers.

