# Numeric types: what is built, and what makes it production grade

`Int<N>` / `UInt<N>` (any width, 1 to 2^23 bits) and `F16` / `F32` / `F64` / `F128` / `BF16` landed on
2026-10-21. This file is the plan for the rest. Items are in the order to do them; each says how to know
it is done.

## Where things live

| Concern | File |
|---|---|
| Integer width names (`Int$24`), wide-literal range check, alloc sizes | `src/ast/int_width.psm` |
| Float names, LLVM keys, widths, intrinsic suffixes | `src/ast/float_width.psm` |
| `TypeInfo` for both (`typeIntFromName`, `typeFloatFromName`, `typeIntN`) | `src/ast/types.psm` |
| `Int<N>` / `F<N>` parsing and their diagnostics (P3011, P3012) | `src/parse/decl.psm` (`parseIntWidth`, `rejectFloatWidth`) |
| Literal retyping (`semaLiteralTakes`) | `src/sema/types.psm` and the five adoption sites |
| Numeric casts, checked casts | `src/ir/numeric.psm` |
| Printing an unnamed-width integer (sema rewrite) | `src/sema/number_text.psm` |
| `intText`, `floatText`, the `F32`/`F16`/`BF16`/`F128` print overloads | `std/number_text.psm` |
| Backend numeric keys (`key_int_width`, `float_type_from_key`) | `runtime/llvm-api-backend.c` |
| Container slots and `T?` carriers for the new types | `src/ir/types.psm` (`scalarToSlot`, `optPayloadBits`) |
| AIF sizes and alignment, and their Python twins | `src/aif/layout.psm`, `tools/aif_oracle/` |
| Tests | `tests/test_324`-`326`, `tests/neg_314`-`317` |
| Docs | `../website/apps/docs/content/language/types.md`, `stdlib/number-text.md`, `conversions.md`; developers `llvm/types-and-abi.md`, `compiler/semantic-analysis-and-types.md`, `compiler/frontend.md` |
| IntelliJ plugin | `../intellij-plugin` (`PrismioWords.BUILTIN_TYPES`, `SignatureParser`, `PrismioBlock.isArrayLength`, `NumericWidthTypesTest`) |

## Not yet verified (do these first)

1. **Byte-identical output for existing programs.** The change is meant to leave every program in `tests/`
   and `benchmarks/hosted/prismio/` compiling to the same IR. The suite is green and the fixpoint holds,
   but no IR A/B against a baseline was run. Use `tools/ir_snapshot.py` / `tools/compile_ab.py` against a
   HEAD build **plus the uncommitted graph_churn work** (the tree carries both; build the baseline from a
   worktree with only this feature reverted, or diff mnemonics per `tools/fn_mnemonic_diff.py`).
2. **`prismio gate`** (lint, release gate on a packaged candidate, fixpoint, `--verify` sweep, JIT, cross
   target) has not been run. Only `suite`, `verify` steps 1-3, `bootstrap` and lint were.
3. **Linux and Windows.** Everything was exercised on macOS aarch64. `F128`, and `F16`/`BF16` on a target
   without them, call compiler-rt/libgcc routines (`__multf3`, `__extendhfsf2`); they linked here and are
   expected to on Linux, and to fail to link with `link.exe`.
4. **Two failures that predate this work** and must not be mistaken for it: `aif_verify` (`test_273`
   leaks 200 not 300, `test_269` 0 not 9) and the `src/main.psm` AIF differential (T2 138 vs 137), both
   identical on the old release toolchain. They look like the unfinished fused-list work; settle them
   with whoever owns it.

## Work, in order

### 1. The seed step, then the standard traits for the floats
`F32`, `F16`, `BF16`, `F128` implement none of `Copy`, `Eq`, `Ord`, `Default`, `Display` (and their `T?`
forms where `Float` has them). They must be written in `std/copy.psm`, `eq.psm`, `ord.psm`, `default.psm`,
`display.psm` (orphan rule), which `src/` imports through `std.vec`, so **the seed must be cut and
committed by the maintainer first**; `prismio seed` bakes in whatever compiler is in the tree, including
uncommitted work, so confirm that is wanted. Then:
- add the impls; decide `Key` (Float deliberately has none: NaN) and keep the same decision;
- move the `print`/`println`/`toString` overloads out of `std/number_text.psm` into `std/io.psm` and
  `std/string.psm` beside `Float`'s, and keep `floatText` in `number_text` or fold it into `float_text`;
- `Vec<F32>.sort()`, `.filled`, `.contains`, `Map<_, F32>` values work; add them to `test_325`.
Done when `prismio bootstrap` works from the new seed and `import std.io` alone prints an `F32`.

### 2. Standard traits for `Int<N>` of an unnamed width
The hard one. A hand-written `impl Key for Int<24>` is refused by the orphan rule, and the language has no
blanket impls. Choose and build one:
- **Synthesis on first use** (preferred): when sema first resolves a width, it builds the impls for each
  std trait the program has imported, as it builds `dyn$Show` structs. Needs the method bodies as AST
  (`eq`, `compare`, `copyOf`, `default`, `show`, `hash`) — generate them from templates so they are
  one-line casts to a named type for N <= 64 and limb loops (see `intText`) for N > 64.
- or a `trait`-level mechanism for "all integers" (blanket impl over a builtin marker).
Done when `Map<Int<24>, V>`, `Vec<UInt<12>>.sort()`, `"${x}"`, `x.show()` and `default` work for any width,
with a test per trait, and the diagnostic for a missing impl no longer tells the user to write an impl
they cannot.

### 3. Numbers wider than 64 bits in containers
`Vec<Int<128>>`, `Vec<F128>`, `Vec<Int<128>?>` are refused (`typeIsWideScalar`). Every
`scalarInlineBytes` consumer in `src/ir/expr.psm` assumes a row of 1, 2, 4, 8 or 16 bytes read through an
`i64`. Make row size arbitrary (pass the size, load/store the `iN` by address), then lift the refusal.
Also check `Channel`, `spawn` thunks (`taskResultLane`), atomics (`std.raw`) and `Map` values with wide
scalars. Done when the refusal is gone and `test_324` pushes, reads, sorts and removes `Int<128>`.

### 4. The library around the types
- `std.math`: per-type limits and constants (`Int<24>.MAX`, `F32.EPSILON`, `F32.PI`, `F16.MAX`), the
  `F32` function set (the builtins already take their suffix from `floatIntrinsicSuffix`; decide which are
  correctly rounded in `F32` and which go through `Float`), `countOnes` etc. on odd widths (the builtins
  already work at any width; the std wrappers do not exist), `Float.toBits`-style `toBits`/`fromBits`
  for `F32`/`F16`/`BF16`.
- Text: `parse` for every width and float (`"12" as Int<24>?`, `parseF32` with correct single rounding, not
  double rounding through `Float`), `toString(radix)` past 64 bits, exact `F128` text (the `Decimal`
  machinery in `std/float_text.psm` is 53-bit).
- `std.mem`: `readF32LE`, `writeF32LE`, `readU24LE`-style helpers if wanted.
- Literal contexts: confirm and test an `F32` literal in a `return`, a struct field initialiser, an array
  literal, a default argument and `1.0 / 3.0` against an `F32` (today two float literals type as `Float`,
  as two int literals type as `Int`); hex float literals; per-type `NaN` / `INFINITY`.

### 5. FFI and ABI
`extern fn` with `F32` and `Int<24>` parameters, `repr(C)` / `packed` structs containing them, `export fn`,
and callbacks. `F32` must be C `float`, `F16` `_Float16`, `BF16` `__bf16`, `F128` `_Float128`/`__float128`
(x86-64 passes it in an SSE register, aarch64 in a Q register: check the backend's call lowering).
`Int<128>` is `__int128` (alignment 16). Test against a C file in `tests/` compiled by the project's
toolchain. Also bit-fields via `UInt<N>` in a `repr(C)` struct are a tempting follow-up; decide, do not drift.

### 6. Targets and the soft-float runtime
Run the new tests on Linux x86-64, Linux aarch64, Windows (the VM is provisioned: see the memory note on
the Windows VM), `wasm32` and freestanding aarch64 (`tests/freestanding/`). For `F128`/`F16`/`BF16`/wide
division either ship compiler-rt builtins in the toolchain (like the LLVM vendoring, `tools/setup_llvm.py`)
or provide the routines in `runtime/`, and say which in the docs. Replace the hard-coded `i128:128`
allocation constants (`intWidthAllocBytes`, the oracle's twin) with the target data layout's answer
(`LLVMABISizeOfType`), which is already how `-g` offsets are computed.

### 7. Correctness hardening
- Differential tests against C `_BitInt(N)` / `__int128` and `_Float16`/`__bf16`/`__float128`, and against
  Rust's `i128`, for + - * / % << >> comparisons and every cast pair, with edge values (MIN, -1, MAX, 0,
  NaN, subnormals, ties). Generate them; keep the generator in `tools/`.
- Property: for every pair of types, `x as T? != none` implies `(x as T) as U == x` where it should.
- Odd-width `sdiv` by -1 / MIN, `%` on negative, shift amounts >= N (poison today: decide masking or a
  checked build trap), `--overflow-checks` on `Int<N>` division.
- `Int<1>`: confirm `i1` storage never leaks into Bool paths (`typeFromIrKey("i1")` is `Bool`).
- Very wide integers (1M+ bits): compile time and the quadratic `intText`; set a documented practical cap
  or make text linear.
- `-g`: `UInt<N>` currently describes as signed (`di_type_for` sees only the key); thread signedness
  through for unsigned.
- Range analysis (`src/ir/ranges.psm`, `nowrap.psm`, `relations.psm`) assumes `i8..i64` keys in several
  tables; grep for `"i64"` and decide per site that an `iN` is safe or is declined.

### 8. Performance
Benchmarks for `Int<128>` multiply/divide, `Int<24>` packed loops, `F32` / `F16` vectorised loops
against C++ and Rust (`prismio bench`, `benchmarks/hosted/`), following `docs` guidance on measurement
(subprocess timing lies; mnemonic-diff every arm). Check that an `F32` loop vectorises 4-wide and that
`F16` on AArch64 uses native `fadd h`, not conversions.

### 9. Docs, plugin, changelog, release
Update both doc apps (`prismio-check` examples must compile), `CHANGELOG.md` as each item lands, the
IntelliJ plugin (`.MAX` completion once limits exist; `Int<N>` hover), and `graphify update .`. Cut the
release notes page for 0.2.0. Run `prismio gate` before any push.

## Rules to respect (they cost sessions before)

- New syntax in a file `src/` imports needs the seed first. `std.vec`, `std.io`, `std.string`, `std.option`,
  `std.fs`, `std.process`, `std.unicode` and everything they import are such files.
- Never `prismio build` or edit `src/` while `tools/run_suite.py` runs; name a test compiler anything but
  `prismio` and set `PRISMIO_INTERNAL_HOSTED=1`.
- One diagnostic code, one call site (`tools/lint.py`). Run `tools/format_sources.py --check`, never
  `--write` (it reformats untracked files).
- Commit by naming paths; never `git add -A`; leave `bootstrap/` out; the tree currently also holds the
  graph_churn / fused-list work, so most of `src/ir`, `src/aif`, `runtime/` is mixed.
- Two Python twins must move with the compiler: `tools/aif_oracle/aif.py` and `layout.py`.

## Prompt for the next session

```
Read docs/NUMERIC_TYPES_PLAN.md and CLAUDE.md, then use `graphify query` before grepping.

Context: Int<N>/UInt<N> (any width) and F16/F32/F64/F128/BF16 landed on 2026-10-21 and are
uncommitted in this tree beside unrelated graph_churn / fused-list work. The plan file lists what is
built, what is unverified, and nine work items in order.

Do, in this order, and keep each module single-purpose (one table per question; a new closed concern
gets its own file, not another case in expr.psm / checker.psm):

1. Verify before building: run an IR A/B proving existing tests/ and benchmarks/hosted/prismio/
   compile byte-identically with and without this feature; run `prismio gate`; reproduce the two
   pre-existing failures (aif_verify test_273/test_269, the src/main.psm AIF differential) on the old
   toolchain and report whose they are. Do not "fix" the expectations of someone else's work.
2. Ask me whether a seed refresh is wanted, then (only on my word) do plan item 1: the standard traits
   and io/string overloads for F32/F16/BF16/F128, dissolving the float half of std/number_text.psm.
3. Design and build plan item 2 (traits for unnamed-width Int<N>) — propose the mechanism with the
   trade-offs first, then implement with a test per trait.
4. Plan item 3 (wide scalars in containers), then item 4 (std.math, limits, parse, text, literal
   contexts), then item 5 (FFI/ABI against a C fixture).
5. Items 6-8 as far as the VM and targets allow; say plainly what could not be run.

For every item: tests (positive and negative), both doc apps (verify-doc-examples.mjs and
audit-content.mjs), CHANGELOG.md, docs/KNOWN_ISSUES.md (delete entries you fix, re-run reproducers
first), the IntelliJ plugin (../intellij-plugin, run its tests with -Dprismio.checkout=...), the
Python AIF oracle twins, and `graphify update .`. Fix what you find rather than flagging it, unless it
cannot be fixed soundly, and say why. Never commit unless I ask; commit by naming paths; never touch
bootstrap/seed.ll.
```
