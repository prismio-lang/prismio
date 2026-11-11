# Language gaps, and the plan to close them

Written 2026-11-11. This is a planner in the style of the other `docs/*_PLAN.md` files: what is
missing, in the order to build it, with the design for the first item (nested structs) worked out
enough to start. **A1 (nested structs) was built the same day; see [A1: as built](#a1-as-built).**
Every other row is still open.

## How this list was made

1. Every "not implemented" / "Coming Soon" / "no support" statement in
   `../website/apps/docs/content/language/*.md`, `stdlib/*.md`, `roadmap.md` and the
   `Language surface` section of `docs/KNOWN_ISSUES.md`.
2. A probe: each feature written as a small `.psm` and run through `prismio check` (global
   toolchain, 2026-11-11). **Probed** below means the compiler's own answer, quoted. **Per docs**
   means the documentation says so and no probe was run. The two disagree in places; see
   [Documentation that is wrong](#documentation-that-is-wrong).

A probe that fails proves the spelling I tried is not accepted, not that no spelling exists. Each
row names the exact error so it can be re-run.

## What already works (do not rebuild)

Probed OK: nested structs by **named** type (`Outer { pos: Inner }`, `o.pos.x = 5`); struct
variants of enums (`Shape.Rect { w, h }`, with patterns); `dyn Trait` parameters; trait default
methods; `where` clauses; associated types in a trait; generic enums; string interpolation
(`"{x}"`); `1 | 2` alternatives in `match`; `const`; shadowing. Not repeated below.

## The gaps

Priority: **P0** blocks ordinary programs or is the stated ask, **P1** is something nearly every
other language has and users hit within a day, **P2** is real but can wait.

### A. Aggregate data (the ask)

| # | Gap | Evidence | Pri |
|---|---|---|---|
| A1 | ~~**Nested structs**~~ **done 2026-11-11** (not yet inside a generic struct): an inline field type `pos: struct { x: Int, y: Int }`, and a struct declared inside another (`Outer.Inner`) | `P3201 expected IDENTIFIER in field name, found struct` | P0 |
| A2 | ~~**Tuples**~~ **done 2026-11-11** (two to four elements; no `Ord`/`Key`/`Display`): `(1, 2)`, `-> (Int, Int)`, `let (a, b) = t`, `t.0` | `P3201 expected ) ... found ,` and `expected a type name, found (` | P0 |
| A3 | ~~**Struct patterns / destructuring**~~ **`let` form done 2026-11-11** (`match` arms and parameters not): `let P { x, y } = p` | `P3201 expected : in map literal entry, found ,` | P0 |
| A4 | **Nested patterns**: `F.X(E.A(v))` | `P4001 a variant pattern binds names, not expressions` | P1 |
| A5 | **Struct update**: `P { x: 5, ..p }` | `P3201 expected IDENTIFIER in struct literal field, found ..` | P1 |
| A6 | **Field defaults**: `x: Int = 3` | `P3201 expected IDENTIFIER in field name, found =` | P1 |
| A7 | **Tuple structs** `struct P(Int, Int)` and **unit structs** `struct Marker` | `P3201 expected { in struct body` | P2 |
| A8 | Compound assignment on a field or index: `p.x += 1`, `v[i] += 1` | `P3302 compound assignment += requires a plain variable on the left` | P1 |
| A9 | **Type aliases**: `type Id = Int` | `P3201 expected a declaration, found type` | P1 |
| A10 | **Union / sum types without a declaration**: `Int \| String` | per docs | P2 |
| A11 | Associated `const` in an `impl` | `P3201 an impl block holds fn, prop and let declarations, found const` | P2 |

### B. Control flow and expressions

| # | Gap | Evidence | Pri |
|---|---|---|---|
| B1 | ~~**`if` / `match` as expressions**~~ **done 2026-11-11** (a branch is one expression); `break` with a value still open | `P3201 expected an expression, found if` (roadmap: Coming Soon) | P0 |
| B2 | ~~**`?` operator**~~ **done 2026-11-11**: for `Result` and `T?` | `P3201 expected an expression, found ?` (roadmap: Coming Soon) | P0 |
| B3 | **`if let`, `while let`, `let ... else`** (the `T?` forms are F3, which raises their priority) | `P3201 expected an expression, found let` | P1 |
| B4 | **Match guards** `x if x > 2 =>` | `P3201 expected => in match arm, found if` | P1 |
| B5 | **Range patterns** `1..5 =>` | `P3201 expected => in match arm, found ..` | P1 |
| B6 | **String patterns** | `P4001 match scrutinee must be an integer or enum value, found String` | P1 |
| B7 | **Optional chaining** `p?.x` | `P3201 expected an expression, found ?` | P2 |
| B8 | **`defer`** | `P4001 unknown identifier defer` | P2 |
| B9 | **`Never` return type**; divergence decided by name today (`semaCallNeverReturns`) | KNOWN_ISSUES; roadmap | P2 |

### C. Functions, closures, traits

| # | Gap | Evidence | Pri |
|---|---|---|---|
| C1 | **User operator overloading** (`+`, unary `-`, `==` on a struct); only indexing has a hook (`at`) | `P4001 unknown trait Add`, `operator + requires numeric operands` | P1 |
| C2 | **Inferred closure parameter types**; **storing or returning a closure**; a **function type** `fn(Int) -> Int` | per docs; `closret` probe: `P3201 expected { in block, found (` | P1 |
| C3 | **Default and named arguments**; expression-bodied functions | per docs (`functions.md`, "Not implemented") | P2 |
| C4 | **Derive / attributes**: `#[derive(Eq)]`, `#[test]` (the lexer rejects `#`) | `P2001 unexpected character #` | P1 |
| C5 | **`impl Trait` in argument position** is accepted; **in return position** is not probed | none | P2 |
| C6 | A trait cannot declare a `prop`, nor a method taking a pack | KNOWN_ISSUES | P2 |
| C7 | **Aliased imports** `import m as n`; **re-exports** | roadmap, `modules.md` | P2 |

### D. Standard library

| # | Gap | Evidence | Pri |
|---|---|---|---|
| D1 | **Lazy iterator adapters** `v.iter().map(f).sum()` | per docs (`stdlib/vec.md`) | P1 |
| D2 | `VecDeque`, a sorted map, a priority queue, a linked list; chunked `Vec<T, N>`; `pop`/`removeAt` without `T: Copy` | per docs; `FEATURE_BACKLOG.md` item 3 | P1 |
| D3 | `wrapping_*` / `checked_*` / `saturating_*` arithmetic; random numbers | per docs; KNOWN_ISSUES | P1 |
| D4 | Dates, time zones, timers | roadmap | P2 |
| D5 | `select` over channels, non-blocking send/receive; mutexes, atomics, condition variables; cancellation, timeouts | `concurrency.md` "Not implemented" | P2 |
| D6 | Doc comments (`///`) that a tool can extract | `lexical-structure.md` | P2 |

### E. Tooling (this is the question that started the list)

| # | Gap | Evidence | Pri |
|---|---|---|---|
| E1 | **Ask the compiler for a type**: there is no `typeof`, no `prismio type`, and the only route is a forced mismatch error. Add `prismio check --type-of <file> <line> <col>` (the LSP already computes it for hover), and a compile-time `typeName(x)` builtin that folds to a string literal | no match in `src/sema/builtins.psm` | P0 |
| E2 | A linter | roadmap | P2 |
| E3 | Package registry and version solving; path dependencies on the import search | roadmap, KNOWN_ISSUES | P2 |
| E4 | WebAssembly past IR (blocked on a libc, not on the compiler) | roadmap | P2 |
| E5 | `unsafe` block; taking a field's address or a type's size | `low-level.md` | P2 |

### F. Absence handling (the "sshole" hole)

Added 2026-11-11 after reading [sshhole.com](https://sshhole.com) (HN `id=50378228`): on musl,
`crypt()` returns `*` instead of NULL when it fails, and `*` is also what a locked account stores,
so a failed hash compared equal to "no password" and sshd logged in. `sandbox/src/main.psm`
reproduces the shape in Prismio: `hasher(7) == hasher(12)` is `none == none`, which is `true`.
The design is in [Absence handling (F): design](#absence-handling-f-design).

| # | Gap | Evidence | Pri |
|---|---|---|---|
| F1 | **`T? == T?` is the easy path and says nothing.** Two optionals compare equal when both are `none`; the safe spelling needs a hand-written `and x != none`. No diagnostic fires | `src/sema/checker.psm:1516-1527` accepts it, rejects only `T? == T`; probe: `stored == attempt` with both `none` prints `Logged in` | P0 |
| F2 | **No absence-never-equal comparison.** There is no way to say "equal only when both are present and equal" | none in `std/option.psm` | P0 |
| F3 | **No safe way to ignore absence.** `if let h = x { … } else { deny }` and `let h = x else { return }`, where absence falls to the other branch. Today the options are `expect` (a panic), `== none` then `expect` (two steps), and `??` (a sentinel). This is B3 with a reason to be first | `P3201 expected an expression, found let`; `optionals.md` "Not in 0.2" | P0 |
| F4 | **Flow narrowing** after `x != none` (and through `and`, `else`, `let mut` invalidation) | `optionals.md`: "Comparing with `none` does not narrow the type" | P2 |
| F5 | **`match` on `T?`** | `optionals.md` "Not in 0.2"; `P4001 match scrutinee must be an integer or enum value` | P1 |
| F6 | **`??` recreates the bug.** `a ?? 0 == b ?? 0` is `true` when both are absent, which is musl's change. The docs present `??` as the safe form | `optionals.md` "None-coalescing" | P1 |
| F7 | A failure that must say *why* is returned as `T?`, so "locked" and "failed" are both `none`. `Result` exists but nothing steers an API to it | `optionals.md` "Results, and where `T?` stops" | P2 |

### Documentation that is wrong

Found while probing; fix these as part of whichever item touches the page.

- `pattern-matching.md` says alternatives are not implemented. `match (2) { 1 | 2 => ... }` checks.
- `language/index.md` says there is "no dynamic dispatch or trait object". `fn f(s: dyn Shape)`
  checks, and `traits.md` documents objects.
- `optionals.md` lists `a == b` as an ordinary reading of a `T?` and presents `??` as the safe
  fallback. Neither mentions that `none == none` is `true` or that a fallback is an in-band
  sentinel (F1, F6).
- `pattern-matching.md` also says "nested destructuring" and "guards" are not implemented; the
  nested-pattern probe fails with a different message than the page implies, so re-check the
  whole sentence when A4 and B4 land.

## Constraints that shape every item

These are the project's own rules, restated because each one decides an ordering below.

- **The seed must parse `src/`.** A new syntax lands in two steps: teach the frontend, cut a seed
  (`prismio seed`), have the maintainer commit it, *then* use the syntax in `src/`. No item below
  uses its own syntax inside the compiler until that has happened. The seed is never staged
  without the maintainer's word.
- **A behaviour-preserving change produces byte-identical compiler output** for every program in
  `tests/` and `benchmarks/hosted/prismio/`. Every item here is additive syntax, so this is the
  acceptance test: two generations to a fixpoint, the full suite, `tools/aif_differential.py`.
- **Desugar in sema, in place**, as `src/sema/enum_struct_variants.psm` does, so that type
  checking, ownership/AIF and codegen see only the forms they were built for. Prefer this over
  new IR node kinds.
- **A runtime symbol brings its `std/` wrapper and contract.** None of these items needs a new
  runtime symbol except possibly E1's `typeName`, which folds at compile time and needs none.
- **Documentation is part of the change**, in both `../website/apps/docs` and
  `../website/apps/developers`, with compiler-checked examples
  (`verify-doc-examples.mjs`, with a packaged toolchain).
- Editor surfaces: the language server, the formatter, the VS Code grammar and the JetBrains
  lexer all hard-code syntax (KNOWN_ISSUES records the lexer already lags on `is`, `not`, nested
  `fn`, closures and field visibility). Each syntax item lists its editor work.

## Nested structs (A1): design

### What "nested" should mean

Three different things get called nested structs. Prismio has the third already.

1. **Inline field type**, written where the field is declared and owned by it:

   ```psm
   struct Window {
       title: String,
       size: struct { w: Int, h: Int },
       origin: struct { x: Int, y: Int }
   }
   ```

2. **Scoped declaration**, a type that belongs to another and is named through it:

   ```psm
   struct Window {
       struct Size { w: Int, h: Int }
       title: String,
       size: Size
   }
   // outside: Window.Size { w: 1, h: 2 }
   ```

3. **Struct variants of an enum** (`Shape.Rect { w: Int, h: Int }`). Already implemented; it is
   the model to follow, because its desugaring is the proof that "named fields stored inline in the
   parent" already survives ownership, AIF and codegen.

I recommend building 1 and 2 together on one mechanism, because 2 is 1 with a name you can write.

### Lowering: hoist to an ordinary nominal struct

The parser records the inline struct on the field; **sema hoists it to a top-level `STRUCT_DECL`**
before type checking, exactly as `enum_struct_variants.psm` rewrites a struct variant into its
tuple form:

- `size: struct { w: Int, h: Int }` in `Window` becomes a declaration of `Window.size`
  (internally `Window$size`, never printed) and the field's annotation becomes that name.
- `struct Size { ... }` inside `Window` becomes a declaration `Window.Size`.
- Everything downstream (layout, `sink`/borrow rules, AIF tiers, codegen, `--verify`) sees an
  ordinary struct stored inline in its parent. **No change to ownership, AIF or the backend.**

This is why the byte-identical rule is cheap to meet: a program that writes no nested struct
produces the same declarations it did before.

### Decisions that need an answer before coding

1. **Literal syntax for the inner value.** `Window { size: { w: 1, h: 2 } }` collides with the map
   literal `{ k: v }` (the probe shows `a map literal needs import std.map`). Options:
   - (a) Contextual: sema re-types a brace literal whose expected type is a struct, the way it
     already re-types an `Int` literal in four contexts. Reads best; needs the expected type at
     every site, and a bare `let s = { w: 1 }` stays a map.
   - (b) Always spell it: `Window.size { w: 1, h: 2 }` / `Window.Size { w: 1, h: 2 }`. No
     ambiguity, a little verbose.
   - **Recommend (b) first, then (a) as sugar** where the expected type is a hoisted struct, so
     nothing is blocked on the re-typing work.
2. **Anonymous or nameable?** An inline struct is nominal, so two `struct { x: Int }` fields are
   two types, consistent with "two declarations with identical fields remain different types".
   Recommend nameable as `Outer.field`, so a function can take one.
3. **Generics.** `struct Box<T> { inner: struct { v: T } }` hoists to `Box<T>.inner` carrying the
   parent's type parameters. Recommend supporting it from the start; deferring it means a rewrite
   of the hoist.
4. **Visibility.** A hoisted type takes its field's visibility; a scoped `struct` takes the
   marker written on it, defaulting to `internal` like any struct. Its fields keep the field rule
   (private unless marked).
5. **Name collision with enum variants.** `Owner.Name` is already how `Shape.Rect` resolves
   (`expr.s1.contains(".")` in the struct-literal path). A struct and an enum variant cannot share
   a dotted name; resolution must report which it found, and a struct with a nested type of the
   same name as an enum variant is an error.
6. **Depth.** Allow nesting to any depth, `Outer.a.b`; refuse recursion (no finite layout), with
   the same diagnostic a directly recursive field gets today.

### Work items

| Step | What | Where |
|---|---|---|
| 1 | AST: a field may carry a nested `STRUCT_DECL` in a new slot; a `STRUCT_DECL` may carry nested declarations | `src/ast/nodes.psm` |
| 2 | Parse `struct { ... }` as a field type and `struct Name { ... }` in a struct body | `src/parse/decl.psm` (`parseStructDecl`), `parseTypeAnnotation` |
| 3 | Hoist in sema, before the struct table is built; qualified lookup `Outer.Inner` in type position | new `src/sema/nested_structs.psm`, `src/symbols/declarations.psm` |
| 4 | Literals: qualified name form first, contextual brace form second | `src/parse/expr.psm` (`parseStructLiteral`), sema |
| 5 | Diagnostics print the written name, never `Outer$field` | `src/common/diagnostics.psm` (`diagQuote`) |
| 6 | Traits and derives: the hoisted type is a normal struct, so `impl Display for Window.Size` works; the formatter and `Eq`/`Default` rules need no new cases | tests |
| 7 | Language server: hover shows `Window.size`, go to definition lands on the field, completion after `Window.` lists nested types, rename, semantic tokens | `lsp/` |
| 8 | Formatter: indentation of the inline body, one-line short form | `prismio fmt` |
| 9 | Editors: VS Code grammar, JetBrains lexer | extension, plugin |
| 10 | Docs: `structs.md` (new section), `types.md`, `grammar.md`; the developers app (hoisting, naming); `roadmap.md` row; 0.3.0 release notes | `../website` |

### Tests

A fixture each, positive and negative, in `tests/` (the runner picks `test_NNN_*.psm` and
`neg_NNN_*.psm`):

- inline field read, write, return by value, pass by borrow and by `sink`;
- two levels deep; two sibling inline fields of identical shape are distinct types;
- generic parent with an inline field using `T`;
- scoped declaration reached as `Outer.Inner` from another file, with each visibility level;
- the name-collision, recursion and unknown-field errors, each asserting its message;
- an owned (`String`, `Vec`) field inside an inline struct under `--verify`: this is where a
  hoist that confuses ownership would show, and a green suite alone proves nothing there;
- the same program written with separate named structs compiles to identical IR (the
  desugaring claim, tested directly).

### Cost and risk

Smallest item in section A. The risk is not the parse, it is (1) the contextual literal in
decision 1a, and (2) generics in decision 3. The ownership, AIF and backend risk is intentionally
zero by lowering to a plain struct; the `--verify` test above is what confirms it.

## Absence handling (F): design

### What the hole is

In sshole the failure value (`*`) and a legitimate value (the locked account's `*`) were the same
bytes, and a plain `==` joined them. Prismio's `T?` keeps the two apart in the type, but
`T? == T?` throws that away at the comparison: both absences become one `none`, and `none ==
none` is `true`. The shortest correct-looking program is the unsafe one.

The three lazy ways to deal with an absence today, none of which is a safe way to ignore it:

| Written | What it does on `none` |
|---|---|
| `a == b` | silently `true` if `b` is `none` too (F1) |
| `a.expect()` | panics; on attacker-controlled input that is a denial of service |
| `a ?? fallback` | substitutes an in-band value, which is the musl change (F6) |

### Fix 1: make `T? == T?` stop being the easy path (F1, F2, F6). Seed-safe, ships first

No new syntax, so none of it waits for a seed.

1. **Diagnostic** in the `==`/`!=` branch of `semaBinaryExpr` (`src/sema/checker.psm:1516-1527`),
   where `leftT` and `rightT` are both `OPTIONAL` and neither operand is a `none` literal. It says
   that `none == none` is `true` and names the two ways out. **Open: warning or error.** An error
   is the pit of success but breaks existing code; a warning is cheap and can become an error.
   Before choosing, grep `src/`, `std/`, `tests/`, `benchmarks/` for every such comparison: the
   compiler compiles itself, so a use in `src/` blocks an error until it is rewritten.
2. **`a.matches(b)`** in `std/option.psm` (name open: `matches`, `sameValue`): `true` only when both
   are present and equal; `none` is never equal to anything. A std method needs no seed refresh,
   and `std/` ships as `stdlib/`, so check the wrapper through an installed toolchain.
3. **Check what `String? == String?` lowers to.** The sema comment says an optional compared with a
   present `T` "would be an address comparison", and `generateScalarOptionalCompare`
   (`src/ir/expr.psm:4087`) covers only scalars. I did not run the reference-optional case; if it
   compares addresses it is a second bug and belongs in `KNOWN_ISSUES.md`, fixed here, not flagged.
4. **Docs** (`optionals.md`, both apps): rewrite the `a == b` row, add the login example from
   `sandbox/src/main.psm` as a `prismio-check: pass` and a `fail` pair, and add a caution to
   *None-coalescing* that `x ?? 0 == y ?? 0` is `true` for two absences.
5. **Tests:** a `neg_NNN_*` for the diagnostic asserting its message, a `test_NNN_*` for `matches`
   (both present equal, both present unequal, one absent, both absent) over `Int?` and `String?`.
6. **Acceptance:** `tests/` and `benchmarks/hosted/prismio/` produce byte-identical IR (a diagnostic
   and a std method change no existing program's output).

### Fix 2: a safe way to ignore absence (F3, F5; F4 deferred)

The aim is a form where the short spelling is the safe one: absence is not an error and not a
fallback, it is "this branch is not taken".

```psm
if let h = attempt {            // absence falls to else: deny
    if h == stored { println("Logged in") }
} else {
    println("denied")
}

let h = attempt else { return }  // early exit, h is the present value afterwards
```

- **Build the binder, not flow narrowing.** `if let x = e` and `let x = e else { … }` bind the
  present value, so no fact has to be tracked through `and`, `else` arms, loops or `let mut`
  mutation. Flow narrowing (F4) is a separate, larger analysis and stays out of 0.3.0; say so in
  the docs rather than leave the "Not in 0.2" bullet unexplained.
- **Lowering:** desugar in sema, in place. `if let h = e { A } else { B }` becomes
  `let tmp = e; if tmp != none { let h = expect(tmp); A } else { B }`. Splice into the statement
  chain: a sema rewrite that makes a bare block emits nothing.
- **Open: borrow or move for an owned reference `T?`** (`String?`, `Vec<T>?`, a struct). `expect`
  borrows, so the binder should borrow and leave `tmp` owning; test it under `--verify` in three
  shapes (a local, a field, a call result), because past optional-container work leaked exactly
  here.
- **`while let`** comes with it (one more parse rule over the same desugar). **`match` on `T?`** (F5)
  is bundled only if the existing pattern machinery makes `Some`/`none` arms cheap; otherwise it
  follows the pattern work in Phase 2.
- **Seed:** teach the frontend, build, `prismio seed`, the maintainer commits it, then use `if let`
  in `src/`. The parser change touches `src/parse/stmt.psm` and `src/ast/nodes.psm`; `src/parse/decl.psm`
  currently carries uncommitted nested-struct work, so land after it or coordinate.

| Step | What | Where |
|---|---|---|
| 1 | AST: `IF_LET_STATEMENT`, `WHILE_LET_STATEMENT`, `LET_ELSE_STATEMENT` | `src/ast/nodes.psm` |
| 2 | Parse them; `let` after `if`/`while` is no longer an error | `src/parse/stmt.psm` |
| 3 | Sema desugar and binder scope; ownership rule above | new `src/sema/optional_bind.psm`, `src/sema/checker.psm` |
| 4 | Definite-return and move analysis see the early exit of `let … else` (`semaBlockDiverges`, `semaMovedBranches*`) | `src/sema/flow.psm`, `checker.psm` |
| 5 | Language server (hover on the binder, scope), formatter, VS Code grammar, JetBrains lexer | `lsp/`, `prismio fmt`, extension, plugin |
| 6 | Docs: `optionals.md` "Not in 0.2" rewritten, `control-flow.md`, `grammar.md`, the developers app, `roadmap.md`, release notes | `../website` |
| 7 | Tests: positive and negative for each form; the login example; an owned `String?` under `--verify` | `tests/` |

### The sandbox

`sandbox/src/main.psm` is the reproducer and is uncommitted. Once Fix 1 lands, keep it as the
warning's fixture. Once Fix 2 lands, rewrite its login check with `if let`. Separately, its
`hasher` should return `Result<Int, HashError>` so "locked" and "failed" stay different (F7); that is
an example, not a language change.

### Open decisions

1. Warning or error for `T? == T?` (Fix 1, step 1).
2. Name of the absence-never-equal comparison (`matches`, `sameValue`, an operator).
3. Borrow or move for an owned reference `T?` in the binder.
4. Whether `match` on `T?` rides with the binder or waits for Phase 2 patterns.

## Order of work

Dependencies decide this, not priority alone. A2 (tuples) and A3 (struct patterns) reuse A1's
hoist and the pattern work, so they follow it.

**Phase 1: aggregate data (seed cut after).** A1 nested structs → A3 struct patterns and
destructuring `let` → A2 tuples (a tuple is an anonymous nominal struct with fields `0`, `1`, ...,
hoisted the same way; `(a, b)` literal, `-> (A, B)`, `.0`, destructuring) → A8 compound assignment
on places → A9 type aliases.

**Phase 2: expressions.** B1 `if`/`match` expressions and `break` with a value → B2 `?` (needs B1's
early-return lowering and the error-conversion rule via `From`, which already exists as a trait) →
B3 `if let` / `while let` / `let else` → B4–B6 guards, range and string patterns → A4 nested
patterns.

**Phase 3: types and abstraction.** C1 operator overloading (traits `Add`, `Sub`, `Neg`, `Eq`
hooks, as `at` is for indexing) → C2 stored/returned closures and a function type → C4
derive/attributes (`#[test]` unlocks a built-in test runner) → A5/A6 update syntax and defaults.

**Phase 4: library and tooling.** E1 type inspection (small; can ship **first**, independently of
everything else) → D1 iterator adapters (needs C2) → D2 collections → D3 explicit-overflow forms
→ the P2 rows.

**Phase 0: absence handling, Fix 1 (F1, F2, F6).** No syntax and no seed, so it ships before
Phase 1, alongside E1. **F3 (the binder) moves to the front of Phase 2**, ahead of B1 and B2: it
needs only the statement-level desugar, not expression-position `if`. F4 stays deferred.

E1 is the cheapest item on the list and the one the question was about. It has no dependency on
any other row, so it should ship in the same release as, or before, Phase 1.

## Done when

For each row: the probe in the Evidence column now passes `prismio check`; a positive and a
negative fixture exist; `prismio verify` is green; two generations reach a fixpoint with
byte-identical IR on `tests/` and `benchmarks/hosted/prismio/`; both doc apps and the roadmap row
are updated with compiler-checked examples; the language server and formatter handle it; and the
wrong documentation listed above for that area is corrected.

## A1: as built

Landed 2026-11-11, uncommitted. The design above held; these are the places the build decided
something the design left open, or differed from it.

| Question | Decision |
|---|---|
| Hoisted name | `Owner$$name`, not `Owner$name`. A single `$` already means "instance of a template" to `typeInstancesAsWritten`, so `Window$size` printed as `Window<size>`. `diagQuote` and `typeDisplay` print `$$` as `.`. |
| Where it is hoisted | The **parser** (`parseStructBody`, `parseInlineStruct`, `hoistStruct` in `src/parse/decl.psm`), through the hoist chain nested functions already use. Not sema, as the design said: the parser has the owner's name in hand, and sema then sees ordinary structs. |
| Reaching one | `src/sema/nested_structs.psm`: `Window.Size` in a type parses as a trait projection (`ASSOC_TYPE_REF`) and is rewritten to the hoisted name; `Window.Size { … }` parses as an enum struct-variant literal and is rewritten likewise. Only in a module that declares a nested struct (one shallow scan). |
| Literal syntax (decision 1) | **Both.** `Window.origin { x: 1 }` always works (the parser's variant-literal test now also accepts a lower-case member when the body starts `ident :`, `ident ,` or `ident }`), and `{ x: 1 }` works wherever the expected type is a struct, via `semaCheckValue`. The second is not limited to nested structs: `Holder { plain: { id: 7 } }` works for plain ones. |
| Anonymous or nameable (decision 2) | Nameable, as `Window.size`. |
| Generics (decision 3) | **Refused with a diagnostic**, not built. `struct Box<T> { inner: struct { v: Int } }` says to declare the inner struct beside the outer one. Supporting it needs the hoisted struct to carry the owner's type parameters and a spelling for `Box<T>.Inner`. |
| Visibility (decision 4) | A nested struct has **its owner's visibility**, copied in sema because the owner's marker is applied after the parser returns. There is no marker on a nested struct. |
| Bare name inside the owner | `limits: Limits` in `Config` resolves to `Config.Limits`, nearest scope first, **for field types only**. An `impl` block or a function must write `Config.Limits`. |
| Depth (decision 6) | Any depth; `Config.Server.tls` parses (the type parser now loops on `.`). |
| Enum collision (decision 5) | Not hit: `Owner.Name` is rewritten only when `Owner$$Name` is a declared struct. |

### Tests

`tests/test_381_nested_structs.psm` (inline, scoped, deep, `impl`, optional, brace literals),
`tests/test_382_nested_structs_owned.psm` (a `String` and a `Vec` two levels down, 50 iterations,
`sink`; `--verify` reported 201 allocated, 201 released, 0 leaked, 0 violations),
`tests/neg_384_nested_struct_unknown_field.psm`, `tests/neg_385_nested_in_generic.psm`.

### Not done

- Generic parents (above).
- Bare nested names inside `impl` blocks and signatures.
- **Editor surfaces:** the language server, `prismio fmt`, the VS Code grammar and the JetBrains
  lexer were not touched. Completion after `Window.` does not list nested structs; hover on a
  nested type is unverified. These are plan steps 7–9 and still open.
- `unknown type \`c\`` for `A.c` where `c` is not a nested struct names only the member; it should
  say `A` has no nested struct `c`. Left because the same node kind is a trait's `T.Item`.
- A seed refresh. Nothing in `src/` uses the new syntax, so none is needed yet; the first use of
  it inside the compiler needs the seed cut first.

## A3: as built

`let Point { x, y: b, c: Inner { d }, .. } = value`, rewritten by the parser (`src/parse/patterns.psm`) to
`let x = value.x` and so on, spilled behind the first statement through a chain `parseBlock` drains. A
variable or field path is read in place; anything else is held under a hidden `$dN` annotated with the
pattern's type. Decisions: the bindings are what `let x = p.x` is (copy, or borrow for `String`/`Vec`);
unlisted fields are allowed (`..` is accepted, not required); a binding named like the source is `P3016`;
a global `let` takes no pattern. Not done: `match` arms (a struct scrutinee is not matchable at all today,
so this only matters for nested patterns, A4), function parameters, the pattern's type is unchecked when
the value is a variable. Tests: `test_383`, `neg_386`..`neg_389`; `--verify` 80/80, 0 leaked.

## A2: as built

A tuple is the generic struct `Tuple2`..`Tuple4` (`std/tuple.psm`) and `src/parse/tuples.psm` writes the
spellings: `(A, B)` the type, `(a, b)` the call `tuple2(a, b)`, `t.0` and `t.0.1` the members `_0`, `_0._1`,
`let (a, b) = t` a pattern over `_0`, `_1` (A3's machinery, with nested and struct patterns inside). The first
tuple in a file parks an `import std.tuple`, appended by `parseModule` unless the file already has it. `Copy`
and `Eq` are generic impls; `==` needed `semaStructImplements` so that a template's generic impl answers for an
instance. Limits: two to four elements (`P3017`), no one-element tuple or `()`, no `Ord`/`Key`/`Display`.
Found on the way and recorded in KNOWN_ISSUES: `--verify` reports a struct literal inside a generic struct's
literal as leaked while the ordinary build allocates nothing.
Tests: `test_384_tuples`, `neg_390`..`neg_392`.

## B1: as built

`src/parse/value_exprs.psm` rewrites an `if` or `match` in expression position to `let $vN: $infer`, the statement, and
the name `$vN`; `parseBlock` places the queued statements in front of the statement being read. Refused where moving it
ahead is not equivalent (after a call in the statement, loop headers, right of `and`/`or`/`??`, `else if` conditions,
closure expression bodies, globals). `src/sema/value_exprs.psm` gives the temporary its type when the first branch's
assignment is checked, because a `match` arm may use its pattern's bindings; `ir_retype_var` updates the existing binding
(a second `ir_set_var_type` in the branch scope shadowed it, and read as not `mut`). A typed `let` passes its type to
the temporary so literals adopt it. Limits: a branch is one expression (no statements before the value), a `match` arm
has no braces, `return`/argument positions get the first branch's type (a literal is `Int`, not the parameter's type).
Tests: `test_385`, `neg_393`..`neg_397`. `break` with a value is the other half of B1 and is not built.

## B2: as built, and `match` syntax

`?` (`src/parse/try_exprs.psm`, `src/sema/try_exprs.psm`): the operand is held in `$qN`; a marker statement keeps a `Result`
lowering and an optional lowering; sema picks by type. **The rest of the block is nested inside the success arm** (`nestTries`)
rather than assigning the payload to a temporary: the first version assigned `$vN = payload` and leaked an owned `String` payload
on the way out (the same leak a hand-written `match ... { Ok(a) => { v = a } }` has; KNOWN_ISSUES), and the nesting keeps the
shape the compiler already releases correctly. Not built: converting the error (`From`), `?` in a closure's expression body,
`?` in a global.

`match` syntax: parentheses around the scrutinee optional (`parseScrutinee`), an arm is a block, one statement, or empty
(`parseArmBody`, using `parseBlockOf(single)` so the statement has a block's own context). Tests: `test_386`, `test_387`,
`neg_398`..`neg_401`.

## Editor support for A1, A2, A3, B1, B2 and the match syntax

Done 2026-11-11 (the second half of the session). None of the new syntax added a token, so the VS Code grammar and the
JetBrains lexer needed no change, and both gained tests for it (`grammar.test.mjs`, `PrismioLexerTest`, 29/29). The work was in
what the parser lowers, because the semantic index (`src/index/`) is the editor's only view of the program:

- nested structs are indexed under their owner and found by path (`Window.Limits`, `win.size.w`); an inline struct's fields sit
  inside the field that declares it, typed `Window.size`; `Window.` completes the structs written inside `Window`;
- a pattern's new name (`y: why`) is a local at the name written (the lowered `let` is positioned there);
- a tuple prints as `(Int, String)` everywhere a type is printed, including the compiler's own messages;
- `prismio fmt` keeps `, .. }` apart (a pattern's `..` is not a range).

Left, in order of what a user would notice:

1. An inline struct has no declaration of its own (it shares the position of its field), so go-to-definition on `Window.size`
   used as a type lands on the field. A real fix gives it a distinct position or lets the index key on the node.
2. `t.0.1` colours `0.1` as one float in TextMate; the server's semantic tokens do not correct it.
3. The snippets (`match`, `let`) still write the old spellings. They are valid, only longer than needed.
4. Hover and rename on hidden temporaries were not exercised; they carry `$` and are filtered, but no test looks.
5. `Window.size` has no outline entry of its own, only its fields do.

## Where the next session starts

Built so far and committed (not pushed): A1 nested structs, A3 destructuring `let`, A2 tuples, B1 `if`/`match` as values, B2 `?`,
the `match` syntax, and editor support for all of them. Next in the plan, in the order to build: **B3** `if let`, `while let`,
`let ... else` (the same hoisting and marker machinery as `?`: an optional/enum test with a binding), **B4/B5/B6** match guards,
range patterns and string patterns, **A4** nested patterns inside a variant (`F.X(E.A(v))`), **C1** operator overloading
(`Add`, `Neg`, `Eq` hooks), **C2** closures that can be stored or returned plus a function type, **C4** `#[derive]`/`#[test]`,
**A5/A6** struct update `..p` and field defaults, **D1** iterator adapters. `break` with a value is the other half of B1.
Open from this session: nested structs in generic structs, bare nested names in `impl` blocks and signatures, `From`-style
error conversion for `?`, a branch with several statements in an `if`/`match` expression, and the pattern-binding ownership
leak in KNOWN_ISSUES.
