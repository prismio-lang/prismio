# Code style

Rules for anyone — human or agent — writing code in this repository.

The compiler compiles itself. That single fact drives most of what follows: a change
that is merely *plausible* can break the ability to rebuild from a fresh checkout,
and it will do so one generation later, where nothing points at the cause.

---

## Before you change anything

**The committed seed must be able to parse `src/`.** `bootstrap/prismio-seed.ll` is
LLVM IR for a compiler built from an *earlier* tree. If you add syntax and use it in
`src/` in the same step, `bootstrap.ps1 --seed` stops working and a fresh checkout
cannot build. New syntax lands in two steps:

1. Teach the frontend the syntax. Do not use it in `src/`. Build, verify, then
   `tools/refresh_seed.ps1 -Compiler <gen2>`.
2. Now use it.

**Behaviour is checked by what the compiler emits, not by reading.** For any change
that is meant to be behaviour-preserving, the bar is that the compiler produces
byte-identical output for every program in `tests/` and `aif/corpus/` — IR,
diagnostics, and `aif` tiers. A refactor that changes one byte of that is not a
refactor. The full loop:

```bash
tools/bootstrap.ps1 -Compiler <known-good> -Out build/g1.exe
tools/bootstrap.ps1 -Compiler build/g1.exe -Out build/g2.exe
```

then g1 and g2 must emit identical IR for `src/main.psm` (the fixpoint), then
`cd tests && python test_runner.py`, then
`python tools/aif_differential.py --compiler build/g2.exe`.

**Two generations before judging.** A build that links may only have linked because
the *old* compiler built it. Build the next generation with it before believing it.

---

## Language and layout

- A module's import path is its location: `src/ir/expr.psm` is `import ir.expr`.
  `import ir.*` takes every module in that package, sorted by name — the sort is
  load-bearing, because merge order becomes emission order.
- Import paths are relative to the **source root**, never to the importing file.
- Sibling modules call each other freely. **Do not write `extern fn` forward
  declarations for functions this tree defines** — sema registers every function in
  the merged module before checking any of them, so they declare nothing, and they
  make AIF treat a local call as a foreign one.
- `extern fn` is for genuinely foreign code. Give it an FFI contract (`borrow`,
  `alias`, `produce(free)`, …) — an undeclared extern has unknown provenance, which
  the analysis has to widen to Shared, which spreads.

## Invariants that are not obvious from the code

- **Handles are `Ptr`, not `String`.** An AST node, a token and a `TypeInfo` are
  reached through an opaque machine pointer: `struct ASTNode { child1: Ptr }`,
  `ptr_to_node(p: Ptr)`, and absent is a real `NULL`. `Ptr` is copyable — it is
  absent from `typeIsMoveOnly` — so naming one twice is a copy, not a move.
- Test an absent handle with `nodeExists` / `nodeIsNull`. These are now a pointer
  compare rather than a `strcmp` against `""`.
- **The old punning invariant is retired.** Handles used to be `String`, which
  forced a rule that no type punned through `String` may have a zero-valued first
  field — an absent slot was a pointer to `""`, so a node whose first byte was NUL
  read as absent. `NodeKind` and `TypeKind` still reserve ordinal 0 as
  `NEVER_ZERO`; that is now ABI stability (the ordinals are load-bearing, see
  test_41) rather than a safety requirement. Do not reuse ordinal 0.
- A global holding a handle takes **no initializer** — `let mut tail: Ptr`.
  Nothing runs before `main`, so a global cannot be initialized by a call, and a
  zero-filled pointer is already NULL.
- Strings and structs are affine. Naming a value twice moves it. When a loop needs a
  pointer in two places, call the `alias` accessor twice rather than binding it.

## Naming

| Kind | Convention | Example |
|---|---|---|
| Functions, parameters, locals, struct fields | `camelCase` | `parseExpression`, `startCol`, `tokNext` |
| Types (struct, enum) | `PascalCase` | `ASTNode`, `TokenType` |
| Enum variants, constants, globals that are constants | `SCREAMING_SNAKE` | `STRUCT_DECL`, `AIF_TIER_T0` |
| `extern fn` names | **whatever C calls them** | `str_concat`, `ir_build_call` |

That last row is the exception that looks like an inconsistency and is not. Those are
C symbols: the runtime is a C ABI, and every `.psm` outside this compiler — including
every file in `tests/` — declares them by name. Renaming one is a breaking change to
the language's runtime surface, not a style choice. The visible seam is a feature; it
is how you tell at a glance that a call leaves Prismio.

- **Two prefixes, kept apart.** `parserX` / `lexerX` is the machinery — look at a
  token, consume one, complain about one. `parseX` / `lexX` is a grammar production,
  named after what it parses. Same split in every stage.
- Name by responsibility, in one to four words. `lexIdentifier`, `emitLoad`,
  `advance`, `expect`. Not `processIdentifierAndDetermineTokenType`.

## Writing the code

- **No `while (flag) { … flag = false }`.** `loop { … break }` says it directly.
- Early returns over nesting. A guard clause is not a special case, it is the shape.
- Build sibling chains with `nodeList()` / `nodeListPush()`. Do not open-code the
  "is this the first, or does it go after the tail" dance again.
- If a function no longer fits on a screen, it is doing more than one thing. Split it
  by responsibility, not by line count.

## What not to write

- Wrappers, managers, helpers, factories and utilities that exist for one caller.
  `semaStmtHasBreakWrapper` was a real function here; it duplicated eight lines of
  the walk it was "helping".
- Abstraction for a second case that does not exist yet.
- A generic `utils` module. If a module cannot be named after what it holds, its
  contents do not belong together.
- Comments that restate the code. `// increment i` above `i++` is noise, and so is a
  section banner over three lines.

## What to write instead

Comments here carry what the code cannot: **why**, and **what went wrong last time**.

> This was once an if-chain over every ASCII character […] It was also silently
> wrong: any character it had no branch for — `'^'` (94), `'~'` (126) […] came back
> as 0. That is precisely how `^` and `~` failed to lex when they were first added.

That comment is worth more than the function under it. Write those. Delete the rest.
When you fix a subtle bug, leave the reason it was subtle.

Prefer a name that removes the need for the comment. Then delete the comment.

---

## Performance

Do not make the scanner allocate. It runs once per byte of every source file, and a
`str_concat` on that path is not a micro-optimisation to weigh — it is the difference
between linear and quadratic. The keyword set is a linear scan of string compares for
exactly this reason; a lookup table would have to be built out of allocations.

Elsewhere, prefer the clear version. If you replace it with a faster one, say in a
comment what the measurement was.
