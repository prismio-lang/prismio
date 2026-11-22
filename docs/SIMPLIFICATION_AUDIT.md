# Simplification audit: what to remove, merge and modernise in the compiler

Written 2026-11-20 against `main` at `972cfb5` plus the uncommitted working tree. This is a
planner in the style of the other `docs/*_PLAN.md` files. **Nothing in it is built.** Each
finding gives its evidence: a count you can re-run, or a `file:line` you can open.

Scope: `src/` (138 files, 95,363 lines; 78,689 without the generated
`lexer/identifier_tables.psm`), the backend seam in `runtime/llvm-api-backend.c`, and
`tools/`. `std/` and `ums/` come in only where the compiler duplicates something they hold.

Not to be confused with `aif/implementation/COMPILER-AUDIT.md`, which is about the memory model.

## Status

Steps 1 and 2 of section 8, and most of 3 and the `const` part of 4, are built and verified (2026-11-22), and what they did is removed from this file; the record is
the CHANGELOG (Repository and Changed sections, 0.3.0). The gates were the same each time: 772 of 772 programs in `tests/` and
`benchmarks/hosted/prismio/` give byte-identical IR, the suite passes, the AIF engine and oracle agree, `check_index.py` passes.

**Left over from steps 1 and 2:**

- **Commit the seed.** `src/` uses `const` of a `String` (the diagnostic-code registry, `ir/relations.psm`, `common/terminal.psm`), which the committed seed cannot compile; `bootstrap/seed.ll` is re-cut from this tree and left uncommitted, as CLAUDE.md asks. Until the maintainer commits it, a bootstrap from `HEAD`'s seed fails.
- The `check_layers.py` gate (5.2).
- Stale comments in `runtime/*.c` (`aif/evidence/...` at `build_driver.c:1349, 1365`, `lang_runtime.c:2644, 2750, 3718`,
  `llvm-api-backend.c:1697, 1865, 3394, 4027`; "the text backend" at `llvm-api-backend.c:317, 1045, 1501, 2027, 4991, 6422`).
  Editing the runtime changes its source hash and needs a re-bootstrapped host, so they ride with step 7.
- `.claude/worktrees/` (3.5 GB, three merged branches) and `tools/check_truncation.py` / `tools/ir_slot_diff.py`, which no
  command or doc references: give them a `build.ums` command or delete them (the maintainer's choice).
- `list_truncate` still discards one element at a time (`runtime/lang_runtime.c`), so `Vec<Int>.clear()` is O(length). A scalar
  fast path would take the rest of the `clear` win (5.3% measured against the audit's 10%); it needs the stale-runtime bootstrap.
- `str_with_capacity` is declared in both `std/io.psm` and `std/string.psm`. Left because `std.io`'s import of `std.string`
  is expensive (memory: "std.io's std.string import").
- `sema/decl_index.psm` is not merged into `symbols/declarations.psm`: the first is switched off while the merge makes the
  chain. The 18 "by-name lookups" of D6 were mostly impl scans and appends, not lookups; the trait walks are done.
- `index/lowered.psm`: the full `{head, name, signature, doc}` row table (probe a `String` field in a static table first).
- The `diverges` column of the D1 table, which waits for that table.

## How to read this

Every proposed change is tagged with what it needs:

- **Now**: the language feature is in the **committed seed** (`357f528`, cut 2026-11-10). It
  can go into `src/` today.
- **Seed**: the feature is built and tested, but it landed after 2026-11-10: tuples,
  destructuring `let`, nested structs, `if`/`match` as values, `?`, `if let`/`while let`/`let
  else`, match guards, range patterns, string patterns and nested patterns. The seed has to be
  cut, and the maintainer has to commit it, before `src/` may use any of them (CLAUDE.md, "The
  committed seed must be able to parse `src/`"). The working-tree seed (2026-11-15 00:57)
  predates the `if let` commit (02:12 the same day), so it needs one more cut.
- **Missing**: the language does not have the feature. These rows feed the "most optimal" column
  and [section 7](#7-features-to-add-so-the-compiler-can-use-the-optimal-structure).

**Acceptance rule for every change below.** These changes are source-only refactors. CLAUDE.md
requires **byte-identical compiler output** for every program in `tests/` and
`benchmarks/hosted/prismio/`: two generations to a fixpoint (compare the IR, not the binary),
the full suite, and `tools/aif_differential.py`. The compiler's *own* IR will change, which is
expected. Only its output must not.

### How the counts were made

The counts come from regular expressions over `src/**/*.psm`, excluding `identifier_tables.psm`.
The scripts are short Python and can be re-run, and each count below names its pattern. Treat a
count as a size, not a proof. "Unreferenced" means the name appears nowhere in `src/`, `std/`,
`ums/`, `lsp/`, `runtime/` or `tools/` except in its own definition and in comments. A function
reached only through `functionAddress("name")` would be miscounted, and none of the listed ones
is.

---

## 1. Headline findings, ranked by payoff

| # | Finding | Size | Tag |
|---|---|---|---|
| 1 | **The AST is one struct whose slots change meaning per kind.** `ASTNode` has `s1 s2 i1 i2 i3 child1 child2 child3 next` (`src/ast/nodes.psm:227`), and its comment spends 15 lines explaining which kind uses `i3` for what. | 3,493 `child1/2/3` reads, 2,190 `s1/s2` reads, 630 `i1/2/3` reads in 73 files | Now (accessors) / Missing (typed AST) |
| 2 | **121 hand-written recursive tree walkers** (4,081 lines), and **605 hand-rolled `while (nodeExists(p)) … p = n.next` loops**. Many walkers are the same descent around a one-line predicate, for example the 8 `chainXName`/`nodeXName` pairs in `src/ir/expr.psm`. | 121 walkers, 624 `= x.next` advances | Now |
| 3 | 121 recursive walkers; the nine body-fact pairs of `ir/expr.psm` are `astAny`/`astSum` | The rest are not "test, then descend" | A visitor that skips a subtree or carries a value | Later | **One pass computing facts per function** (def-use chains / dataflow over a CFG or SSA), queried in O(1) (profiled 2026-11-22: not where the time goes) | Stored function types; a derived visitor (`derive(Visit)`) |
| 4 | **Values and types cross into C as text.** 607 `ir_get_temp_name` calls format `"$$v%d"` and the backend `atoi`s it back. Types travel as `"i32"`/`"struct:Foo"` strings. Locals are found with a `strcmp` scan (`runtime/llvm-api-backend.c:501`). | 607 + 173 typed `ir_call_arg("…")` | Now |
| 5 | **The empty string means "absent"**, though `T?` has been in the language since 2026-10-07. | 406 `.equals("")` in 64 files | Now (`T?` + `??`), nicer after Seed |
| 6 | **Operators are strings in the AST.** They are compared in the parser (20 literals), sema (22), codegen (48) and the range/nowrap analyses (84 more). | 174+ | Now |
| 7 | **Closed sets are written as module-level `let`s.** Per the memory note, a module-level `let` is a mutable external global, but `const` and fieldless enums both exist. | 187 `let NAME =` constants; 121 of them are kind codes (`IR_DROP_*`, `AIF_*`, `BINDING_*`) | Now |
| 8 | **Strings are used as sets and maps**: `"id=spill;"` parsed with `indexOf` (`src/ir/expr.psm:4437`), `"\nType.field\n"` (`src/ir/columns.psm:51`) and space-delimited loop labels (`src/sema/flow.psm:42`). `HashMap` and `HashSet` sit in the same file. | 11 encoded tables | Now |
| 9 | **Codegen state is 98 module globals** (41 in `ir/context.psm`), saved and restored around loops by hand (`src/ir/stmt.psm:977/1028`). One function returns three of its results through globals (`irHoistCall/Arg/Prev`, `src/ir/context.psm:105`). | 98 | Now (struct), Seed (tuples) |
| 10 | `IR_DROP_*` `ir/context.psm:164-182`; `aifcore/constants.psm`; `BINDING_*` `symbols/bindings.psm` | All 187 constants are `const` already, `String` ones included. The kind codes cross into C as `Int` | fieldless `enum` for closed sets (cast at the bridge); `BINDING_*` are ORed flags and need a bitflags value, not an enum | Now | Enums with an explicit `repr`; flag sets as a typed bitflags value | `bitflags`-style enum sets |

---

## 3. Duplicated logic

### D1. Builtins: one fact, eight places

**Partly done (2026-11-22):** `generateCall` is 695 lines (was 1,459) and `semaCheckBuiltinCall` is 18 (was 676): their name chains are
moved, unchanged, into `generateCall{Core,Numeric,String}Builtin` (`ir/expr.psm`) and `semaCheckBuiltin{Core,Numeric,String,Container,Channel,VecOps,Slice}`
(`sema/builtins.psm`). The table below is what is still written eight times.

These functions each re-match the same builtin names:

| Function | Literal compares |
|---|---|
| `semaBuiltinCallType`, `src/sema/builtins.psm:17` | 67 |
| `semaCheckBuiltinCall`, `src/sema/builtins.psm:729` (676 lines) | 65 |
| `generateCall`, `src/ir/expr.psm:5127` (1,459 lines) | 67 |
| `aifCompilerBuiltinContract`, `src/aif/contracts.psm:79` | 36 |
| `aifRuntimeContract`, `src/aif/contracts.psm:167` | 27 |
| `aifFfiProduces`, `src/aif/contracts.psm:429` | 25 |
| `semaBuiltinSpelling`, `src/sema/vec.psm:406` | 25 |
| `semaArrayTakesCount`, `src/sema/array.psm:26` | 21 |
| `FFI_CONTRACTS`, `tools/aif_oracle/aif.py:93` | a hand copy |

The memory note "Adding a builtin" records five edits for one builtin, and says the oracle copy
fails silently: the suite stayed green while the differential went from 19 agreeing fixtures
to 15 differing. **Proposal (Now):** create one module, `sema/builtin_table.psm`, holding:

1. `enum Builtin { … }`.
2. One function that maps a name to a `Builtin`, built once into a `HashMap<String, Int>`.
3. One row per builtin: arity, result type, per-argument contract, produces/alias, and whether
   it diverges.

Sema then resolves a call's builtin **once** and stores it on the node (a free `i` slot, or a
side table keyed by node). Every later pass does `match` on the enum. The oracle's table comes
from a new `prismio dump-contracts` instead of being typed by hand.

### D2. Tree walking: 121 walkers

`astAny`/`astSum` (`ast/nodes.psm`) replace the nine same-shape body-fact walkers of `ir/expr.psm`. What is left is the
walkers that are not "test a node, then descend": the alias queries with a hop count (`nodeBindingAliasesName`), the
`String`-returning `chainUnwrapSource`, and the rest of the 121 (many carry state through the descent). A visitor that
can skip a subtree or carry a value would take those; it wants stored function types (section 7).

**A per-function fact pass is not worth building yet.** The audit proposed one to make the per-binding questions O(1).
A sampled self-compile (2026-11-22, 1 ms) shows none of these walkers in the top 25 frames: the AIF solver and bitset code
(`wordsMembers`, `solvePointsTo`, `aif_solve`, `wordsOr`, `regionConfinedFast`) and `list_discard_slot` are. Revisit if a
generated program with very large functions shows them.

### D3. Linked-list helpers copied across modules

Left: **splice a node before the current statement**, 3 copies: `hoistStruct` (`parse/decl.psm:2457`), `spill`
(`parse/patterns.psm:169`), `queueBefore` (`parse/value_exprs.psm:196`), and the **`NodeChain` iterator**
(`for n in chain(head)`, over `std.iter.Iterator`). The iterator is not built: 605 hand loops would each change shape, and
no measurement says the rewrite pays. Keep the manual loops where the body splices `next`.

### D4. Exact duplicate bodies

Left: `implParamNameAt` (`parse/decl.psm`) = `monoParamAt` (`sema/generics.psm`). `parse` is below `sema`, so one cannot
import the other; move the body to `common/text.psm` and have both call it.

### D7. The same name lists, written again

The remainder is the **lowered members** table: `ixLoweredSig`, `ixLoweredText` and `ixLoweredNames`
(`src/index/lowered.psm`) are three parallel chains, and sema keeps a fourth list. Replace them with one array of rows
`{head, name, signature, doc}`. Static struct tables exist since 2026-11-04 (`tests/test_380_static_table_array.psm`), but
that test shows only scalar fields, so **probe a `String` field first**. If it is refused, use a `Vec` built once.

### D8. Two lexers

`src/fmt/scan.psm` re-reads the language for the formatter and the index, because the compiler's
lexer drops trivia and reports errors. Its header justifies this, and it already shares
`lexer/token.psm` and `lexer/vocabulary.psm`. Keep it for now. The optimal shape is in
[section 6](#6-the-replacement-tracker), row 16.

---

## 4. Assumptions that no longer hold

| # | Assumption | Evidence it no longer holds | Change |
|---|---|---|---|
| S1 | "Values cross the backend as IR text." | There is no text backend now (see 2.3). Even so, `generateExpression` returns `String` temp names, and `resolve_value` (`runtime/llvm-api-backend.c:599`) `atoi`s `"$$vN"` back into the index it came from. Each name is a 32-byte `rt_base_alloc` (`:265`), 607 call sites. | Pass the `Int` id. The backend already stores values in `g_values[]`. |
| S2 | "A local is found by name." | `lookup_named` is a linear `strcmp` over every alloca (`:501`), once per use, so a function's cost is quadratic in its locals. The frontend already holds an interned slot id per binding (`bindSlot: Vec<Int>`, `src/symbols/bindings.psm`). | Send the slot id; index an array. |
| S3 | "`""` is the absent value." | `T?` and `??` exist since 2026-10-07. There are 406 `.equals("")` tests, and a real empty string and "absent" cannot be told apart. | `String?`; `if let`/`let else` after Seed. |
| S4 | "These `ir_*`/`aif_*` names are C." | 405 Prismio functions keep C-ABI snake_case from the port (`symbols/bindings.psm` alone has 68, such as `ir_scope_push`). CODE_STYLE §6 reserves that spelling for `extern fn`. The `ir_` prefix on the binding table is why sema imports `ir.bridge` 15 times for things that are not IR. | Rename by owner (`bindScopePush`, …), last, in one commit. |
| S5 | "A module-level `let` is a constant." | It is an external, mutable LLVM global (memory note `prismio-module-let-is-a-global`). `const` has existed since 2026-10-22 (`30f2630`, in the seed). | `const`. Use fieldless `enum`s for closed sets: `IR_DROP_*` (`ir/context.psm:164-182`), the AIF tier and kind codes (`aifcore/constants.psm`, 66 rows), and `BINDING_*` flags. |
| S6 | "One node kind, one meaning per slot." | `nodes.psm:233-249`: `i3` means "written `T?`", "inline state", "bare `self`", "needs a task thunk" or "match is exhaustive", depending on kind. Correctness rests on the comment "no node is both kinds". | Named accessors now; a typed AST later (section 6, row 1). |
| S7 | "Strings are cheap sets." | Delimited-string sets predate `HashMap`/`HashSet` in `src/`. `ir/context.psm` now holds both styles side by side (`irFrameReleaseTypes: HashSet<String>` next to `irOptionalDropTypes = ";"`). | `HashSet`/`HashMap`. |
| S8 | "`x == false` is the spelling." | `not` exists. There are 2,020 `== false`. | Mechanical; lowest priority. |

---

## 5. Complexity and modularity

### 5.1 Oversized files and functions

| File | Lines | Responsibilities that could each be a module |
|---|---|---|
| `ir/expr.psm` | 6,674 | Body-fact walkers (D2) → `ir/body_facts.psm`; `??` spill slots (`:4385-4460`) → `ir/coalesce.psm`; borrowed-temporary hoisting (`irFindBorrowedTemporary` and related, `:661-1100`) → `ir/temporaries.psm`; builtin emission out of `generateCall` → one handler per family, called from the D1 `match` |
| `sema/checker.psm` | 6,253 | `semaFor*` (16 functions) → `sema/for_loops.psm`; `semaClosure*` (9, including the 137-line `semaLowerClosure`) → `sema/closures.psm`; `semaSpawn*` → `sema/spawn.psm`; conformance (`semaFindTrait`, `semaCheckConformance`) → `sema/traits.psm` |
| `ir/module.psm` | 2,939 | `collectStrings*` (6) → `ir/strings.psm`; vtables → `ir/vtables.psm`; workload counting → `driver/workload.psm` |
| `src/main.psm` | 806 | `main` (331 lines, 41 string compares on `first`/`arg`) → a command table: `{name, handler}` rows, with `match` on the name after Seed |

Functions over 300 lines: `generateModule` (819), `generateCall` (695), `semaCallExpr` (394), `aif_solve` (384, nesting depth 9) and `main` (331). The deepest
nesting is `syscallConstraints` (`common/mem_builtins.psm:391`), depth 13 in 17 lines. It has
the same shape as `syscallAsmText` beside it, so both can be a table.

### 5.2 Layering

Assume the intended order is `common < lexer < ast < parse < symbols < sema < aif < ir < driver`.
These imports point upward:

| From → to | Count | Cause |
|---|---|---|
| `sema → ir` | 15 | `ir.bridge`, mostly because the binding table and type registry carry `ir_` names (S4); also `ir_target_triple`, which `common.target` should answer |
| `aifcore → ir` | 3 | `ir.context` globals read by `call_results`, `dispositions` and `ownership` |
| `ast → ir`, `ast → aifcore`, `ast → symbols` | 3 | `ast/types.psm` asks backend and AIF questions; move those helpers to their owners |
| `lexer → ast` | 3 | `dump_tokens` and `scanner` |

Imports cannot enforce this today, because the merge flattens every module into one. A
`tools/check_layers.py` in `prismio verify` can fail on a new upward edge. That costs one script
and protects every refactor in this document.

### 5.3 Global state

There are 98 `let mut` module globals; 41 are in `ir/context.psm`. Three habits come with them:

- **Save and restore by hand** around loops: `savedHeaderList` in `src/ir/stmt.psm:977/1028` and
  `:1216`. Forgetting the restore on one early return is the bug class this invites.
- **Strings standing in for booleans**: `irLoopFlatGuard.equals("1")` (`ir/expr.psm:2052`) is one
  of 26 places that compare against `"1"`, `"0"`, `"true"` or `"false"`.

**Proposal (Now):** add `struct LoopState` (header bound, hoisted bound, flat guard, push guard,
range proof), with a `Vec<LoopState>` stack pushed and popped by the loop emitter. Add `struct
FnState` for per-function counters and sets, reset in one place. **Not built:** the saved values are `String`
globals that the loop emitter re-clones on restore, and whether a struct holding them borrows or owns them is the kind of
thing the AIF ledger has to confirm (`--verify`) before it is trusted; try it with a leak run, not blind.

---

## 6. The replacement tracker

Columns:

- **Where**: the file and place.
- **Today**: the current logic.
- **Replace with (what we have)**: the best change using features the language has, tagged
  Now or Seed.
- **Most optimal (compiler theory)**: what the best compilers do for this.
- **Gap to add**: what Prismio needs so that the optimal form is expressible.

| # | Where | Today | Replace with (what we have) | Tag | Most optimal (compiler theory) | Gap to add |
|---|---|---|---|---|---|---|
| 1 | `ast/nodes.psm:227` and every reader | One `ASTNode` with generic slots whose meaning depends on kind | Named accessors per kind (`binaryLhs(n)`, `loopBody(n)`; `loopBodyOf` exists), one module owning slot meaning; `const` slot-flag names | Now | **Typed AST as a sum type in a typed arena**: `enum Node { Binary { op, lhs: NodeId, rhs: NodeId }, … }` in `IndexVec<NodeId, Node>`, children as contiguous ranges (Zig AST/ZIR, Carbon parse tree, rustc HIR) | Recursive payload enums referencing nodes by id; `Id<T>` newtype indices; `IndexVec` |
| 2 | 605 `while (nodeExists(p)) … p = n.next` loops | Manual linked-list walk | `NodeChain: Iterator` → `for n in chain(head)`. Keep manual loops where the body splices `next` | Now | Children stored contiguously (slice of `NodeId`); iteration is a slice walk, with no pointer chasing | Same as row 1, plus slices of ids |
| 3 | 121 recursive walkers; the nine body-fact pairs of `ir/expr.psm` are `astAny`/`astSum` | The rest are not "test, then descend" | A visitor that skips a subtree or carries a value | Later | **One pass computing facts per function** (def-use chains / dataflow over a CFG or SSA), queried in O(1) (profiled 2026-11-22: not where the time goes) | Stored function types; a derived visitor (`derive(Visit)`) |
| 4 | 840 `x.kind == NodeKind.X` tests; 20 functions with ≥6 on one node (`generateStatement` `ir/stmt.psm:1734`, `exec` `sema/const_eval.psm:454`, `collectStringsExpr` `ir/module.psm:970`, `semaStatement` `sema/checker.psm:3758`, …) | `if` chains | `match n.kind { … }` (enum `match` is in the seed; `ast/types.psm:803` uses it) | Decision | Exhaustive `match`, so a new `NodeKind` forces every pass to answer, lowered to one jump table | **Exhaustiveness diagnostic for a fieldless-enum `match` with no `_`.** Probed 2026-11-20: a `match` missing `K.C` checks clean |
| 5 | Operators: `parse/expr.psm:21`, `sema/checker.psm:1418`, `ir/expr.psm:4718`, `ir/nowrap.psm`, `ir/relations.psm`, `ir/ranges.psm` | Operator text in `s1`, compared everywhere | `enum BinaryOp` set by the parser (in an `i` slot); precedence by `match` | Now | Pratt parser with a binding-power table indexed by token kind; the op is an enum field of a typed node | None |
| 6 | Builtins (D1): 8 functions + `tools/aif_oracle/aif.py:93` | String dispatch repeated per pass; the oracle copied by hand | `sema/builtin_table.psm`: `enum Builtin`, name → enum resolved once, rows of facts; `match` per pass; `prismio dump-contracts` feeds the oracle | Now | Declarative intrinsic table generated at build time (LLVM `Intrinsics.td` + TableGen); pre-interned symbols with fixed ids (rustc `sym::`) | `const` tables with `String` fields; a compile-time `HashMap`/perfect hash; `std.symbol` (interned `Symbol` type) |
| 7 | Builtin emission inside `generateCall` (695 lines now; the builtin families are three functions) | One family function each; the rest is the ordinary call | One handler function per builtin family, dispatched by `match` on `Builtin` | Now | Table of handlers (`Builtin → fn`) | Stored function types (LANGUAGE_GAPS C2) |
| 8 | 406 `.equals("")` sentinels | `""` means absent | `String?` with `??`; then `if let`/`let else` | Now / Seed | Option with a niche (null pointer = absent), zero cost | Check that `String?` uses the pointer niche; if it does not, that is the gap |
| 9 | Encoded tables: `ir/context.psm:20` (`irCoalesceSpills`), `:202` (`irOptionalDropTypes`), `:195` (`irTaskScopes`), `ir/columns.psm:51`, `sema/flow.psm:42` (labels), `driver/derived_impls.psm`, `symbols/library.psm` | Delimited strings, `contains`/`indexOf`/`substring` | `HashMap<String, String>` / `HashSet<String>`; a `Vec<Int>` of label ids for the loop stack | Now | Interned symbols (`u32`) in dense bitsets or hash sets keyed by id | `Symbol` type in std; `BitSet` |
| 10 | `IR_DROP_*` `ir/context.psm:164-182`; `aifcore/constants.psm`; `BINDING_*` `symbols/bindings.psm` | All 187 constants are `const` already, `String` ones included. The kind codes cross into C as `Int` | fieldless `enum` for closed sets (cast at the bridge); `BINDING_*` are ORed flags and need a bitflags value, not an enum | Now | Enums with an explicit `repr`; flag sets as a typed bitflags value | `bitflags`-style enum sets |
| 11 | 98 globals; `ir/context.psm`; save/restore at `ir/stmt.psm:977/1028/1216` | Implicit dynamic scoping | `struct LoopState` stack and `struct FnState`, passed `inout` or owned by the emitter | Now | Explicit pass contexts (pass-manager style), which also enables parallel per-function codegen | `defer` (LANGUAGE_GAPS B8) for restore-on-every-exit; context parameters (Odin/Jai `context`) |
| 13 | IR seam: 607 `ir_get_temp_name`; `ir_call_arg("i32", …)`; `runtime/llvm-api-backend.c:265, 501, 599` | Values as `"$$vN"` text, types as key strings, locals by `strcmp` | `Int` value ids end to end (`ir_*_id` variants); slot ids for locals; an integer type id per key, cached | Now | Typed entity handles (`Value(u32)`, `Type(u32)`) as in the Cranelift and MLIR builders; no text at the seam | Newtype ids that do not mix (`distinct Int` or a one-field struct of guaranteed zero cost) |
| 14 | Type identity: `typeEquals` `ast/types.psm:798`; generic keys `HashMap$String$Int` | Structural compare on name strings; mangled-string keys | Intern each `TypeInfo` by canonical key in a `HashMap<String, Ptr>`; compare pointers | Now | **Hash-consed type table**: `TypeId` (`u32`), O(1) equality (rustc interned `Ty`, Zig `InternPool`) | `Id<T>` + `IndexVec`; interned keys |
| 15 | Declarations by name (D6): 18 chain walks; `semaFindTrait` `sema/checker.psm:5171`, `irFindTrait` `ir/module.psm:2892` | Linear walk with string compare | Use `ir_decl_at`; merge `decl_index.psm` into `symbols/declarations.psm` | Now | One symbol table built after resolution, mapping a name to definition ids partitioned by kind (rustc resolver / `DefId`) | `Symbol` + `Id<T>` |
| 16 | Two lexers: `lexer/scanner.psm`, `fmt/scan.psm` | The compiler lexer drops trivia; the formatter rescans | Keep both; share the char-class tables (partly done) | Now | One lossless lexer + concrete syntax tree with trivia (rust-analyzer `rowan`, Roslyn red-green trees) serving compiler, formatter and LSP | Arena/`Id<T>` + an incremental tree library |
| 17 | Desugaring in the parser: `parse/decl.psm:2457`, `parse/patterns.psm:169`, `parse/value_exprs.psm:196`; `index/lowered.psm` reverse-engineers `$` names | Hoist/spill/queue at parse time | One shared `spliceBefore` helper; one module owning the `$` naming scheme | Now | A separate lowering pass from surface AST to HIR (rustc AST → HIR), so tools see the syntax as written | Typed AST (row 1) |
| 18 | Kind- and name-driven text tables: `ast/dump.psm` (70 `else if`), `hexDigit` `:24`, `lexer/vocabulary.psm` (parallel word/context arrays) | `if` chains; parallel arrays | `match`; one array of rows (`[{word, context}]`) | Now | Derived `Display`/name reflection on enums | `derive` (LANGUAGE_GAPS C4); enum variant names at run time |
| 19 | CLI: `src/main.psm:476` (`main`, 41 string compares), `aifArg` parsing `:398-460` | Hand-rolled `if (flag.equals(…))` chains | Command and flag rows `{name, takesValue, handler}`; `match` on the string after Seed | Now / Seed | Declarative argument spec derived from a struct (Rust `clap` derive) | `derive` + attributes; stored fn types |
| 20 | Binding lookup: `symbols/bindings.psm` | Backward linear scan over the flat table | A `lastOf[nameId]` column plus a `prev` column: O(1) lookup, and shadowing still works | Now | Per-symbol shadow chains / scope "ribs" (rustc), which is the same thing | None (the ids are already interned) |
| 21 | Diverging-builtin lists ×3 (D7) | Three copies | `diverges` column in the D1 table | Now | `Never` return type in the type system (LANGUAGE_GAPS B9) | `Never` type |
| 23 | 405 snake_case Prismio functions (`aifcore/*`, `symbols/*`, `common/diagnostics.psm`) | C-ABI spelling on code that is no longer C | camelCase, prefixed by owner | Now (last) | n/a | None |
| 24 | 2,020 `x == false` | Comparison with a literal | `not x` | Now | n/a | None |

---

## 7. Features to add so the compiler can use the optimal structure

These are ranked by how many tracker rows each one unlocks.

| Feature | Unlocks rows | Notes |
|---|---|---|
| **Typed index arenas**: `Id<T>` newtype and `IndexVec<Id, T>` in std | 1, 2, 13, 14, 15, 16 | The single largest lever. It makes a data-oriented AST and type table expressible, and it is plain library code once newtype ids are zero-cost |
| **Recursive payload enums over ids**, with exhaustive `match` | 1, 4, 17 | The struct-variant machinery exists (`sema/enum_struct_variants.psm`); this needs variants that refer to other nodes by `Id` |
| **Exhaustiveness diagnostic** for a fieldless-enum `match` with no `_` | 4 | Small. Without it, converting the 840 kind tests to `match` buys readability but not safety |
| **Interned `Symbol` type** in std (a `u32` and a global interner) | 6, 9, 14, 15 | `symbols/names.psm` already interns names; promote it to a library type that `match` can use |
| **`const` tables with `String` fields, and a compile-time `HashMap`/perfect hash** | 6, 7, 18 | Static struct tables exist for scalar fields (`test_380`) |
| **Stored function types** (LANGUAGE_GAPS C2, XEFY X1) | 7, 19 | Already the top item of two plans |
| **`derive` and attributes** (LANGUAGE_GAPS C4) | 18, 19, and a `derive(Visit)` for row 3 | Needs `#` in the lexer |
| **`defer`** (LANGUAGE_GAPS B8) | 11 | Makes the save/restore idiom safe on every exit |
| **`BitSet` / enum sets** in std | 9, 10 | Flags such as `BINDING_*` become a typed set |
| **`Never` type** (LANGUAGE_GAPS B9) | 21 | Removes name-based divergence entirely |
| Lossless CST library | 16 | Long-term; only worth it with the LSP plan |

---

## 8. Proposed order (behaviour preserved at every step)

Steps 1 and 2 are done and removed; the numbers are kept so references to the others still hold.

Each step is one commit. Gate every step the same way: `prismio build`, two generations to an
IR fixpoint, `prismio verify` (suite, source lists, externs, AIF differential), and the
byte-identical-output check over `tests/` and `benchmarks/hosted/prismio/`. Measure compile
time with `prismio bench` where a step claims speed.

3. **Chains and walkers**: done except the `NodeChain` iterator and the splice helper (D3), and the per-function fact pass,
   which is not worth building (D2).
4. **Enums**: `const` for integers, the enum-match error (below), and the `match` form of `generateStatement`, `semaStatement`
   and `collectStringsStmt` are done. Left: `BinaryOp`, the closed-set enums (`IR_DROP_*`, AIF codes; the kind codes cross
   into C as `Int`, so each needs a cast at the bridge), and the remaining kind chains (`collectStringsExpr`, 9 tests).
5. **Builtin table** (D1, rows 6 and 7): the family split of `generateCall` and `semaCheckBuiltinCall` is done. Left: the table
   itself (`enum Builtin`, name resolved once, rows of facts) and generating the oracle's contracts from it in the same
   commit, so the differential checks the table instead of a copy. The facts are not enumerable today (they are predicates:
   `intBitCountBuiltin(name)`), so a `dump-contracts` command needs the table first.
6. **State** (rows 9, 11): the hoist triple is a returned struct. Left: `LoopState`/`FnState` (see 5.3 for why not blind) and
   maps instead of encoded strings.
7. **Backend seam** (rows 13, 14, 20; not started: it is `runtime/` work, and the binding-lookup column of row 20 has a
   compaction at `symbols/bindings.psm` that rewrites indices, with no profile evidence that the scan is hot): `Int` ids instead of `"$$vN"`, slot ids instead of
   names, interned types. This touches `runtime/`, so it needs a re-bootstrapped host (memory:
   "Host refuses a stale runtime").
8. **After the seed is committed**: string `match` for every name dispatch left after step 5,
   `if let`/`let else` for the `""` sentinels (row 8), and tuples for multi-results.
9. **Renames last** (rows 23, 24): mechanical, large diffs, with no behaviour to verify beyond
   the fixpoint.

Steps 3–7 all touch `ir/expr.psm`
and `sema/checker.psm`, so run them in sequence, not in parallel sessions.

---

## 9. What to expect when it is done (measured 2026-11-20)

**Programs the compiler builds: no change.** Every step is held to byte-identical output, so a
user program's size, speed and IR do not move. Any movement is a failed step.

**The compiler binary: under 1%.** The release compiler is 62 MB, with a 36.8 MB `__text`
section. About 33.5 MB of that is LLVM/C++, 1.1 MB is runtime C, and about 2.2 MB is code
compiled from `src/` (symbol sizes from `nm -n`). The unreferenced functions of 2.1 are likely
pruned already. Deduplication might remove a tenth of the Prismio part, about 0.2 MB.

**Self-compile time.** `build src/main.psm -o x.ll` with the release host takes 1.55 s
(1.44 s user) and 839 MB peak RSS, and writes 31.5 MB of IR. A 1 ms `sample` of one run gave 989
samples of self time:

| Where the time goes | Share of samples | Touched by this audit? |
|---|---|---|
| AIF solving and bitsets (`wordsMembers`, `solvePointsTo`, `raiseEscape`, `aif_solve`, `bits*`, `bracket*`) and the IR analyses' own scans | about 55% | No: those are analyses, not the old structures |
| **`list_discard_slot` + `list_truncate`** | **about 10%** | **Yes, new finding:** `bitsToVec` and `intsClear` (`src/aifcore/bits.psm:214, 226`) empty a `Vec<Int>` with `while (v.length > 0) { v.pop() }`. Each `pop` builds an optional and truncates by one. Use the `clear` lowering (check that it keeps the capacity) |
| LLVM verify and printing the `.ll` | about 15% | No |
| `strcmp`, `memcmp`, `strlen`, string equality and hashing | about 6% | Yes (rows 5, 6, 9, 13, 15) |
| `malloc`/`free`/slab | about 3% | Partly (row 13: the `"$$vN"` strings) |

So, as measured on today's source, the structural rows (string dispatch, chain walks, decl
lookups, the text seam) can win **5–10%** of a self-compile at most. The two-line `clear` fix
is worth about **10%** on its own. The per-binding body walks (D2) and the backend's
`strcmp` local lookup (S2) are quadratic: they barely show at today's function sizes, but grow
with function size. The AIF solver, half the time, is a separate question for
`ARCHITECTURE-DIRECTION.md`.

The 839 MB peak is not explained by this profile. Measure it (allocation sites under
`--verify`, or `leaks`/Instruments) before crediting the typed AST (row 1) with any of it.
