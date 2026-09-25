# Who owns a call's result: asked of the call, not of its allocation site

**Status: GREEN, 2026-09-25.** LLVM 23.1.1, Apple Silicon. Two-generation fixpoint
`257d4001`, reached again from the refreshed seed over three generations; suite
**419/419**; AIF differential agrees on all 19; lint, extern and source-list
checks clean; 62 benchmarks give identical results with equal or fewer leaks and
0 violations; corpus clean; both doc apps' example and audit gates green
(237 + 50 snippets). The baseline below is `build/tc-xp1`, the compiler before
this work with the same tree otherwise.

Started as the leak that blocked docs/STDLIB_SHIP_PLAN.md item 5,
`optionOr(process.env("X"), d)`. Four separate causes turned up, plus two
use-after-frees `--verify` cannot see.

## 1 · One allocation site, every call's answer

`aif_owns_call_result_at_node` refused a call when any site it could return was
in a container or a released field **anywhere**. A site is per allocating
function, so every `concat` in a program is one site: a single
`Box { text: make(n) }` -- in a function nothing calls -- refused every temporary
`concat` result its release.

| probe (1,000 iterations) | before | after |
|---|---|---|
| `total + make(i).length`, with an uncalled `boxed()` storing `make(n)` | 1,001 / 1 / 1,000 | 1,001 / 1,001 / 0 |
| the same with an uncalled `listed()` pushing `make(n)` | 1,001 / 1 / 1,000 | 1,001 / 1,001 / 0 |
| `make(i).concat(make(i + 1))` bound | 3,001 / 1 / 3,000 | 3,001 / 3,001 / 0 |

Now (`flow_build`, runtime/aif_support.c): a key-level flow graph from the
constraints. `call_result_held` asks whether *this node's* value reaches a
holder -- each call gets a fresh value set, so the constraints consuming it are
its own. `call_fn_result_held` asks whether the callee's result can already be
held when it returns: the keys flowing into its RET key, not following edges out
of a RET key (those are callers'). Every path followed is one the points-to solve
propagated sites along, so every refusal it makes the old test made too.

## 2 · Pass-throughs, also asked of sites

`public fn toUpper(self) -> String { return strToUpper(self) }` returns
strToUpper's allocation; in `x.toUpper().toUpper()` that site is in both the
parameter's set and the return's, so every chained call looked like it returned
its receiver. `param_returns`: a path from PARAM(g, i) to RET(g) along moves g
itself makes (constraints now carry the function whose walk made them,
`aif_con_fn`), crossing into a callee only through the callee's own answer.

| `let y = <shape>` over an owned `x`, 1,000 iterations | before | after |
|---|---|---|
| `x.toUpper().toUpper()` | 3,001 / 1,001 / 2,000 | 3,001 / 3,001 / 0 |
| `x.trim().trim()` | 3,001 / 1,001 / 2,000 | 3,001 / 3,001 / 0 |
| `x.clone().clone()` | 3,001 / 1,001 / 2,000 | 3,001 / 3,001 / 0 |
| `optionOr(x.stripPrefix("  a s"), "no")` | 3,001 / 1,001 / 2,000 | 3,001 / 3,001 / 0 |

## 3 · A temporary the callee hands a view of back

`optionOr(lookup(i), d)` returns the String inside the Option, so codegen cannot
release the Option after the call, and nothing released it later.
`irHoistBorrowedTemporaries` (src/ir/expr.psm) splices `let bt.N = lookup(i)`
ahead of the statement before generation, so the scope drop and every guard on it
apply by name. Only where that reorders nothing: the temporary is the statement's
first effect, the statement runs once, and the block has no automatic arena
(its range is counted in statements). A scalar read off a temporary --
`text.split(',').length` -- is hoisted the same way, and `list_len`'s inline fast
path now releases its temporary.

| probe | before | after |
|---|---|---|
| `let s = optionOr(lookup(i), d)`, 1,000 | 1,667 / 1 / 1,666 | 1,667 / 1,667 / 0 |
| `optionOr(process.env("HOME"), "none").length`, 2,000 | 4,001 / 1 / 4,000 | 4,001 / 4,001 / 0 |
| `println(readFile(path))`, 3 | 6 / 3 / 3 | 6 / 6 / 0 |
| `println(a + b)`, 3 | 6 / 0 / 6 | 6 / 6 / 0 |
| `println(text.split(',').length)`, 3 | 15 / 3 / 12 | 15 / 15 / 0 |
| `makeCounted(i).count` + `makeList(i).length`, 50 | 401 / 1 / 400 | 401 / 401 / 0 |

An owned temporary given to an **extern** is released too where its contract only
borrows it and the result cannot be it (`aif_call_arg_outlives_call`); it never
was.

## 4 · Guards the new bindings needed, which user bindings needed already

A binding hoisted this way is exactly as safe as the same `let` written by hand,
and the written `let` was not safe in three shapes. Each read freed memory, and
each passed `--verify`, because every release it saw was legal:

- `irValueAliasesName` did not count a call returning a *view* of a parameter,
  so `return optionOr(o, d)` looked unrelated to `o`;
- nothing asked about a view **assigned** outward (`outer = optionOr(o, d)` in a
  loop): `chainAssignsAliasOf`;
- nothing asked about a view **kept by a container** (`keep.push(optionOr(o,
  d))`): `chainRetainsAliasOf`, with `aif_call_arg_retained` (the contract for
  `list_push`, the flow graph for a Prismio callee).

`tests/test_185_view_outlives_binding.psm` aborts on the previous compiler (5
violations, the Vec reading back the last string written) and reads back the
right strings now. The binding is kept, so these shapes leak -- pinned at 22 and
18 in run_aif_verify_test.

The guards ran the alias walk far more often, which exposed two false positives:
`acc = mapAdd(acc, 1)` chased `acc` into the 8-hop cap, which answers yes
(test_74 lost its tree, 15 leaked) -- now a per-query visited set; and `concat`'s
site-level "may return a parameter" is always yes (one site), which made
`acc = acc + line` look like it kept `line` (csv_parse, 19,867 leaked) -- now
exempt, as generateCall already exempts it.

A Vec that may be handed a string literal through a pass-through
(`keep.push(optionOr(x, "fallback"))`) freed `.rodata` at teardown -- 10
violations in 30 pushes on the previous compiler. `container_may_hold_untracked`
declines its element release; a String view is exempt (`copied_on_keep`), since
codegen copies a view into the container (test_141 would otherwise lose 5).

## 5 · What moved

IR changed in 12 test programs, `algorithms.psm`/`suite.psm` (only
`benchBuildOneExpr` and `benchSExprParse`) and the compiler. Every changed test
ends with equal or fewer leaks and 0 violations; stdout identical.

| program | before (alloc / rel / leak) | after |
|---|---|---|
| s_expression_parse | 16,138 / 33 / 16,105 | 16,138 / 16,138 / 0 |
| test_92_field_view_provenance | 18 / 8 / 10 | 18 / 18 / 0 |
| test_137_unicode | 57 / 51 / 6 | 57 / 57 / 0 |
| test_126_push_predication | 40 / 36 / 4 | 40 / 40 / 0 |
| test_177_type_functions | 5 / 1 / 4 | 5 / 4 / 1 |
| test_70_struct_field_release | 83 / 80 / 3 | 83 / 83 / 0 |
| test_171_default_values | 14 / 10 / 4 | 14 / 11 / 3 |
| test_67_option_result | 5 / 3 / 2 | 5 / 5 / 0 |
| test_178_default_trait | 2 / 0 / 2 | 2 / 1 / 1 |
| test_103_default_trait_methods | 1 / 0 / 1 | 1 / 1 / 0 |
| test_143_string_compare | 15 / 14 / 1 | 15 / 15 / 0 |
| test_184_call_result_ownership (new) | 4,073 / 206 / 3,867 | 4,073 / 4,073 / 0 |

s_expression_parse time: 1.45 -> 1.48 ms median of 7, interleaved, within noise.

## 6 · Still open

- A temporary whose callee returns a view of it, evaluated after another call in
  the same statement: `total + b.length + same(make(i)).length` leaks
  `make(i)`. Moving it ahead of `b.length` could reorder effects.
- A view kept past its binding's block leaks the binding rather than copying.
- A Vec that may hold a literal leaks its owned elements.

All three are in KNOWN_ISSUES.md.
