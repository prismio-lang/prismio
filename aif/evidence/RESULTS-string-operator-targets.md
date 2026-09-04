# The String operators lower to methods, and the prefixed names are gone

**Status: GREEN, 2026-09-04.** Compiler `build/strm-g4`, LLVM 22.1.8 on Apple
Silicon. Two-generation fixpoint **byte-identical** (`strm-g3` and `strm-g4` each
emit a 1,986,480-byte compiler from `src/main.psm`, to the same output basename in
different directories), the committed seed still builds `src/`, suite
**285/285** via `tools/run_suite.py`, `prismio lists` clean, AIF differential
**19/19**, doc examples **177/177**.

`==` stopped depending on a public `strEquals` in 2026-09-03 by becoming
`__builtin_string_eq`. This does the remaining four — `+`, `s[i]`, `s[a..b]` and
the four orderings — and it does **not** copy that recipe. `strConcat`,
`strCharAt`, `strSlice` and `strCompare` no longer exist; `concat`, `charAt`,
`slice` and `compare` in `impl String` carry the implementations, and the
rewrites in `src/sema/checker.psm` name those.

## 1 · The blocker, as recorded and as measured

The recorded account was that concat was blocked on a **contract** question:
`aifCompilerBuiltinContract` in `src/aif/contracts.psm` expresses only
per-parameter contracts, and a concat *builtin* returns an owned allocation,
which is a return contract that table cannot say.

**Both halves of that are wrong, and in opposite directions.**

**A producing builtin was never blocked.** The return contract for a call is
answered next door by `aifFfiProduces`, keyed on the same name, and three
compiler builtins already use it: `list_new`, `list_new_with_capacity`, `soa` and
`aos` each hand back an allocation the caller owns. A `__builtin_string_concat`
would have been one entry there and one in the parameter table. That the two live
in different functions — while index `-1` is the return everywhere else, which is
how `aifDeclaredContract` reads an `extern` — is a factoring wart, not a missing
mechanism.

**The real constraint is not about builtins at all**, and it is why no builtin
was added. It is rule 2 of `std/string.psm`'s header, which was still exactly
true and which the obvious probe does not see.

## 2 · The measurement, and the probe that lied

Every run below is 1,000 iterations under `--verify`, on the *pre-change*
compiler `dist/Prismio/bin/prismio`, so none of it depends on this work.

The first probe was `"c".concat("d")` — the delegating method as it then stood —
against `strConcat("c", "d")`:

| form | allocated | released | leaked |
|---|---:|---:|---:|
| `strConcat("c", "d")` | 1001 | 1001 | 0 |
| `"c".concat("d")` | 1001 | 1001 | 0 |

That reads as "delegation is free, the pass-through rule is stale", and it is
**vacuous**: both arguments are literals, and a literal contributes no allocation
site. The controlled pair is the same program with one *owned* argument —
`let t = f("a","b"); let u = f(t,"c")`:

| form | allocated | released | leaked |
|---|---:|---:|---:|
| `strConcat` — allocates in its own body | 2001 | 2001 | **0** |
| user-written `myConcat` — allocates in its own body | 2001 | 2001 | **0** |
| `wrap(a,b) { return strConcat(a,b) }` — delegates | 2001 | **1** | **2000** |
| `t.concat("c")` — the delegating method | 2001 | **1** | **2000** |

So the property that decides this is **not** free function versus method, and not
builtin versus native. It is whether the returned allocation was made in the
function's own body. `myConcat`, written in a test program out of nothing but the
three string builtins and `str_with_capacity`, is as clean as `strConcat`.

**Mechanism.** A site is per function, so `wrap`'s return points at
`strConcat`'s one site, and passing a previous `wrap` result back in puts that
same site in `wrap`'s parameter set. `fn_may_return_param` intersects the two
(`runtime/aif_support.c`), answers yes, and `irValueAliasesName` in
`src/ir/expr.psm` then withholds the drop for the argument *and*
`aif_owns_call_result_at_node` refuses ownership of the result. Both operands
leak. With only literals passed there is nothing in the parameter set to
intersect, which is what makes the naive probe silent.

## 3 · Why this rules the builtin route out for these four

A builtin would have been sound — the contract is expressible, section 1. It
would also have meant moving `concat` (five arities), `slice`, `charAt` and
`compare` out of Prismio and into codegen or back into C, undoing "the C string
layer is native Prismio now". The pass-through rule gives a target that costs
nothing: **put the body in the method.** `equals` already did exactly this, for
exactly this reason, and says so in its comment.

The four rewrites in `src/sema/checker.psm` therefore change one string each.

## 4 · Migrating the call sites

The body can live in only one place, so this is atomic with the rename: every
caller outside `std` had to reach the method directly.

Nested spines were **flattened, not transcribed**. `strConcat(strConcat(a,b),c)`
transcribes to `a.concat(b).concat(c)`, which leaks the intermediate — measured
2001 / 1001 / 1000 for the nested form, and the chained-method form is worse at
2001 / 1 / 2000. `a.concat(b, c)` is one allocation: 1001 / 1001 / 0.

Spine depth in `src/`, before: 193 two-part, 87 three, 27 four, 25 five, 8 six,
2 seven. The two seven-part spines have no overload and were rewritten by hand —
one folds a literal prefix into a neighbouring literal, the other binds an
intermediate rather than nesting one.

| tree | `strConcat(` before | `.concat(` after |
|---|---:|---:|
| `src/` | 604 | 351 |
| `ums/` | 133 | 90 |
| `tests/` | 60 | 59 |

`.concat(` did not appear anywhere in the tree before this, so the second column
is entirely this change. **297 nested intermediate allocations are no longer
created**, which is a leak the compiler was taking on itself once per nested
join.

## 5 · The guard, and why the fixture alone is not one

`tests/test_91_string_ergonomics.psm` asserts the operators' *values*, and every
operand in it was a literal — the vacuous case above. A regression to delegation
would type-check, answer every one of those assertions correctly, and leak. Two
lines were added with an owned left operand, and
`run_string_operator_ledger_test` in `tests/test_runner.py` now builds the
fixture with `--verify` and asserts the ledger: **30 allocated, 30 released, 0
leaked, 0 violations**, with a floor on `allocated` so that a fixture which
stopped exercising the operators cannot pass by balancing nothing.

## 6 · What is left

`strLength` is still the target of `for c in s` and is still public, so one
compiler contract remains on a prefixed name. It is not urgent for the same
reason the other four were: nothing forces it out of the public API, because
`strLength` is not being removed.

The pass-through rule itself is untouched and remains the sharpest edge in the
model: **a Prismio function cannot state that its return is its own allocation.**
`produce` says exactly that at the FFI boundary and has no native spelling, so
the workaround is to write the body twice — `strToUpper` and `strToLower` are
duplicated for this reason, and `std/string.psm` says so. Closing it means either
a native return contract (frontend syntax, so a seed refresh) or refining
`fn_may_return_param` from a points-to intersection to a flow question. The
second is the better answer and the more dangerous one: this predicate is what
stops a caller freeing a value it does not own, so a wrong narrowing is a double
free rather than a leak.
