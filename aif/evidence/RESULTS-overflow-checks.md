# Debug-mode integer overflow checking

**Status: GREEN, 2026-08-29.** Compiler `build/ovf-4`. Suite **174/174**, fixed
point, AIF differential **18/18**, `check_source_lists` agree, `git diff --check`
clean.

`Int` is signed 32-bit and wraps. That decision stands and was not reopened —
[`RESULTS-int-width.md`](RESULTS-int-width.md) settled it with numbers. What was
owed is the **diagnostic**, so the wrap is something a program can be made to
report rather than a silence. `--overflow-checks` is it, off by default, RFC
0560's "check in debug, wrap in release".

```
runtime error: integer overflow in `+` at tests/overflow_checks_probe.psm:13
note: Int is signed 32-bit and wraps in release builds; this check is on
      because the program was built with --overflow-checks
```

---

## 1 · The measurement that changed the plan

`TODO.md` recorded: *"a native `llvm.sadd.with.overflow` lowering should be
cheaper than a sanitizer, and that is the thing to measure."* Measured, and it
is **not cheaper** — the two are within noise of each other:

| shape | plain | `__builtin_*_overflow` | `-fsanitize=signed-integer-overflow` |
|---|---:|---:|---:|
| stride | 7.03 ms | 41.84 ms (**5.95×**) | 40.24 ms (**5.72×**) |
| saxpy | 5.48 ms | 29.35 ms (**5.36×**) | 29.72 ms (**5.42×**) |

Checksums identical across every arm. **The cause is not the check.** Reading
the generated arm64: the plain loops use **17** NEON registers each and both
checked forms use **none**. A branch out of the loop body per operation defeats
vectorization outright, and that — not the compare — is the whole cost. Any
lowering that can trap has this property, which is why the sanitizer and the
intrinsic land in the same place.

So the hoped-for cheap native lowering does not exist, and the conclusion is
firmer than before rather than weaker: this can only be a mode.

**Two measurement traps were hit on the first attempt and are defeated in the
committed fixture** — the plain `stride` arm read **0.00 ms** because the call is
loop-invariant and was hoisted out of the repetition loop, and the checksum
accumulator itself overflowed, so the sanitizer reported the harness instead of
the code under test.

## 2 · What it actually costs on real programs

The microbenchmark is the worst case, not the expected case:

| program | checks off | checks on | ratio | |
|---|---:|---:|---:|---|
| g1 | 19.47 ms | 21.74 ms | **1.116×** | checksums agree |
| g3 | 46.26 ms | 46.22 ms | **0.999×** | checksums agree |
| g4 | 64.63 ms | 65.19 ms | **1.009×** | checksums agree |
| g6 | 145.14 ms | 145.59 ms | **1.003×** | checksums agree |

**1.00×–1.12× on the corpus against 5.4×–6.0× on a vectorizable arithmetic
kernel**, and the difference is what the programs spend their time on: the corpus
is allocation- and pointer-bound, so the arithmetic that gets checked is a small
share of it and the loops were not vectorizing anyway.

This is worth stating plainly because the recorded 4.1–4.4× was a microbenchmark
number being used to reason about whole programs. **The default stays off** — a
6× worst case is not something to impose on a release build, and Rust's split is
the right one — but "too expensive to ever consider" is not what the corpus says.

## 3 · Implementation

- **`ir_checked_binop`** in `runtime/llvm-api-backend.c` emits the intrinsic, the
  aggregate extract, the branch, and a trap block ending in `unreachable` — so
  the continuation dominates every later use and no phi is needed. The whole
  sequence lives in the backend because all four are backend vocabulary; the
  frontend asks for a checked add and gets a value.
- Six entry points, `ir_{add,sub,mul}_checked` and the `u` family. **Rust checks
  both signednesses and so does this**: `0 as U32 - 1` is the wrap a reader is
  most likely to write by accident.
- **`prismio_overflow_trap`** in `runtime/lang_runtime.c` prints the operator and
  the source position and exits. Reached only down the `unreachable` arm, so a
  release build has neither the call nor the branch.
- `+ - *` only. `/` cannot overflow except at `INT_MIN / -1`, which is a
  different trap and not this item; comparisons and bitwise ops never can. `i1`
  is excluded — it is `Bool`, and `llvm.sadd.with.overflow.i1` is not a thing.

**The flag is provably inert when off**: emitted IR is **byte-identical on all
128** programs in `tests/`, `aif/corpus/` and the xlang corpus against the
previous compiler, and the suite check asserts that a default build contains no
`with.overflow` at all — absence of the intrinsic, not merely absence of a trap.

## 4 · A parser defect this found

The first diagnostic named **line 14** for an overflow on line 13, consistently.
The cause is in `src/parse/expr.psm`: `parserNode(p, NodeKind.BINARY_EXPR)` was
called *after* the right operand was parsed, so `parserCurrent` is the token
**after the whole expression** — the next line. Every `BINARY_EXPR` in the tree
carried the position of whatever followed it.

It had never shown because nothing reported a source position out of a
`BINARY_EXPR`: sema points at operands, and `-g` takes its locations from
statements. `--overflow-checks` is the first thing that does.

The tree already knew the shape of this bug — `src/parse/stmt.psm` carries a
comment about "the same off-by-one that made an expression statement report the
following line until 2026-08-22" and corrects the enclosing statement from the
first token. Both `BINARY_EXPR` constructions are now anchored on the **operator
token**, which is the right anchor: the position identifies the *operation*,
which is what overflowed and what a reader looks for on the line.

**Codegen-neutral**: the fix changed emitted IR on **zero** of the 128 existing
programs, which is the direct evidence that nothing else was reading that
position.

## 5 · The gate

| gate | result |
|---|---|
| fixpoint (`ovf-3` vs `ovf-4`) | identical |
| suite | **174/174** |
| AIF differential | **18/18** |
| `check_source_lists.py` / `git diff --check` | agree / clean |
| emitted IR, flag off, 128 programs | **byte-identical** |
| corpus answers, checks on | checksums agree on g1, g3, g4, g6 |

The discriminator is `run_overflow_checks_test`, and it asserts the pair rather
than the trap alone — a compiler that checked *always* would pass a
trap-only assertion and is exactly the version that must not ship:

1. the default build wraps to `-2147483596` and exits 0;
2. `--overflow-checks` reports the overflow, naming the operator and the line;
3. the default build's IR contains no `with.overflow` intrinsic.

## 6 · What this does not do

- **No `wrapping_*` / `checked_*` / `saturating_*` intent forms.** Rust's model
  has three parts and this is one of them; without the explicit forms, code that
  *wants* to wrap has no way to say so and would trap under the flag. That is the
  language half and it is a separate item.
- **No profile concept.** Rust ties this to `debug-assertions`; Prismio has no
  debug/release profile, so it is an explicit flag and the default is the release
  answer.
- **`/` at `INT_MIN / -1`** is unchecked, as above.

## 7 · Also in this change: the benchmark clock

`clock_gettime_nsec_np` returns `uint64_t` and was declared `-> Int` in **20**
sources. It worked only because every use takes a *difference* and frames are
short; a frame over ~2.1 s produced garbage. It is now declared `-> I64`, with
the narrowing moved to after the subtraction:

```prismio
list_set(samples, frame, (t1 - t0) as Int)
```

Every corpus checksum is unchanged — g1 `alive 2000 / beyond 1095` through g9
`total 1856014121 / last 1579165008` — so this is a declaration fix and not a
behaviour change.

## 8 · Sources

- [RFC 0560, integer overflow](https://rust-lang.github.io/rfcs/0560-integer-overflow.html) — the check-in-debug/wrap-in-release split, and the argument that overflow checking is analogous to a debug assertion.
- [rustc codegen options, `-C overflow-checks`](https://doc.rust-lang.org/rustc/codegen-options/index.html) — the flag this one is modelled on, including its independence from debug info.
