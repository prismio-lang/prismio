# std.math: Float's functions, and the three Float codegen bugs under them

**Status: GREEN, 2026-09-25.** LLVM 23.1.1, Apple Silicon. Seed bootstrap to a
two-generation fixpoint `366655dd`; suite **408/408** (new
`test_181_std_math.psm`, also green under `--overflow-checks`); AIF differential
agrees on all 19, and on test_181 and test_120; lint clean; both doc apps' example,
audit and velite gates green (235 + 50 snippets).

`std/math.psm` was three integer functions. It is now Float's roots, rounding,
powers, logarithms, trigonometry and IEEE constants, integer `pow`/`gcd`/`lcm`/
`floorDiv`/`floorMod`/`isqrt`, and every numeric type's `MAX`/`MIN` -- as methods,
which the language's UFCS also makes free functions (`x.sqrt()`, `sqrt(x)`). At the
time a method with no arguments could also be read as a property (`x.sqrt`);
since 2026-09-25 a property is declared `prop`, and the math operations are
methods only (RESULTS-declared-properties.md).

## 1 · The lowering

One builtin family, `__builtin_f64_<op>`, tabled once in
`src/common/float_builtins.psm` and read by sema (arity), codegen (symbol), the
flat-List guard (every name safe) and AIF (every name a borrow; the oracle
generates its entries from the same list). The five-table pattern `__builtin_max`
used is where a builtin goes missing silently -- see prismio-adding-a-builtin.

| op | symbol | AArch64 | x86-64 baseline |
|---|---|---|---|
| sqrt, abs, copysign, minnum, maxnum | `llvm.*.f64` | one instruction | one instruction |
| floor, ceil, trunc, round, rint | `llvm.*.f64` | one instruction (`frint*`) | libm call |
| fma | `llvm.fma.f64` | `fmadd` | libm `fma` |
| exp … tanh, pow, atan2 | `llvm.*.f64` | libm call, known pure | libm call, known pure |
| cbrt, expm1, log1p, asinh, acosh, atanh, hypot | libm name | libm call | libm call |

**`roundEven` is `llvm.rint`, not `llvm.roundeven`.** `llc -O3` over a probe for
`x86_64-pc-windows-msvc` and `x86_64-unknown-linux-musl` (the CPU a non-Apple x86
build targets is baseline `x86-64`, `default_target_cpu`) showed `llvm.roundeven`
falling back to C23 `roundeven`, which the UCRT does not export. `rint` rounds the
same way in the default mode -- which Prismio never changes -- and is C99. Before
the switch, five triples were probed (Windows MSVC, Linux GNU x86-64 and AArch64,
macOS x86-64 and AArch64); after it, the two x86-64 non-Apple ones were re-probed and
every call target is C99.

`as Int` from Float is now `llvm.fptosi.sat` (`fptoui.sat` for unsigned): out of
range clamps, NaN is 0. A bare `fptosi` was poison there. `fcvtzs` already
saturates, so AArch64 pays nothing.

## 2 · Three bugs the library could not be written over

| | before | after |
|---|---|---|
| `nan != nan` | `false` (`fcmp one`) | `true` (`fcmp une`) |
| `1.0 / -(0.0)` | `inf` (`fsub 0.0, x`) | `-inf` (`fneg`) |
| `7.5 % 2.0` | P4001 "requires integer operands" | `1.5` (`frem`) |
| `1e10 as Int` | poison | `Int.MAX` |
| `I64.MAX` | "does not fit in Int" | 9223372036854775807 |

The last is associated constants: `semaResolveAssocConst` substituted the value
expression and dropped the declared type, so the literal was re-typed as `Int` at
every use. A numeric constant now becomes `value as T`, which emits nothing when the
types already agree.

**IR snapshot, before vs after, over all 222 programs both compilers build:** 17
differ, and every changed line is one of `fcmp one`->`une` (15 programs),
`fsub contract 0.0, x`->`fneg` (test_33), or `fptosi`->`llvm.fptosi.sat`
(test_36, benchmarks/memory). Nothing else moved.
test_135's parse-float round-trip checks (`back != fifteen`) were vacuous against
a NaN until this: `one` answers false for one.

## 3 · Cost

`v1.psm`, `out[i] = (xs[i] * xs[i] + 1.0).sqrt().max(0.5).floor()`: the loop body is
`fsqrt d`, `fmaxnm d`, `frintm d` -- no call, the guard kept. It is scalar, and so is
the same loop without the math and its Int twin: an existing limit of that loop
shape, not the library's.

Benchmarks, `compute.psm` switched from its own `extern fn sqrt/sin/cos` to
`import std.math`, 15-25 runs, in-process timing:

| workload | before | after | C++ | Rust |
|---|---:|---:|---:|---:|
| raytracer_sphere | 454.1 µs (1.22x C++) | 390.8 µs (1.06x) | 371.0 µs | 416.6 µs |
| fft | 2.8 ms | 3.0 ms | 2.8 ms | 3.0 ms |

raytracer: `sqrt` stopped being a libm call. fft reads 6% slower and is **layout,
not code**: its transform's machine code is instruction-for-instruction the same
772 lines except that each `sin`+`cos` pair became one `__sincos_stret`, which a C
microbenchmark times at 2.93 ns against 3.81 ns for the pair. See
prismio-layout-sensitivity.

Size: a program importing `std.math` and calling `sqrt` is 32 bytes larger than
one printing a Float; unused functions are stripped. The benchmark binary shrank
from 416,816 to 400,320 bytes.

## 4 · Not done

Random numbers, `F32`, bit counting (`ctpop`/`ctlz`/`cttz` would join the same
table as `__builtin_i32_*`), checked integer arithmetic, `toBits`/`fromBits`.
Listed as "Not available yet" on the docs' `stdlib/math` page.
