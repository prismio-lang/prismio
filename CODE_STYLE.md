# Code Style

Rules for anyone — human or agent — writing code in this repository.

Prismio is a self-hosting compiler. A change that merely looks correct can
break the seed build, alter emitted output, or fail one generation later.
The goal of this document is therefore not to make the source look uniform.
It is to keep the codebase **correct, modular, readable, maintainable, and
safe to evolve**.

---

## 1. Architecture

### Modules own responsibilities

A module should own **one coherent subsystem**.

A module must be describable in one sentence. If a file contains several
independently describable responsibilities, split it.

Current compiler responsibilities include, for example:

- CLI parsing and command dispatch
- compiler/frontend orchestration
- import resolution
- workload profiling
- UMS project integration
- self-hosting and compiler promotion
- native compiler/FFI integration

These responsibilities may depend on one another, but they must not become
one implementation simply because they are used by the same executable.

`main.psm` is an entry point, not a dumping ground.

A useful dependency shape is:

```text
main
  -> cli
       -> compile
            -> imports
            -> workload
       -> project
       -> selfhost
       -> native interface
```

The exact names may change. The principle does not.

### Do not place code in the nearest convenient file

Before adding a non-trivial feature:

1. Identify the subsystem that owns it.
2. Check whether that subsystem already has a module.
3. Add the code there, or create a new module if the responsibility is new.

Do not add code to a large file merely because the required symbols are
already imported there.

### Do not split into meaningless fragments

Do not create modules such as:

```text
utils.psm
helpers.psm
manager.psm
misc.psm
common_extra.psm
```

merely to reduce line count.

Create a module when it represents a real boundary.

Likewise, do not create wrappers, managers, factories, or abstractions for
one caller or one hypothetical future case.

The rule is:

> **Split by responsibility, not by file count.**

### File size is a signal, not a law

There is no hard maximum line count.

However:

- around 500–800 lines: reconsider the module boundary
- around 1000+ lines: require a clear architectural reason not to split
- any file containing several unrelated subsystems should be split regardless
  of its size

A short but mixed-responsibility file is still badly structured.

### Keep subsystem boundaries explicit

A subsystem should expose a small, intentional interface.

Avoid allowing callers to depend on internal implementation details when a
small public operation can express the same intent.

Prefer:

```text
compileSource(path, options)
```

over making callers coordinate:

```text
parse(...)
resolveImports(...)
runAif(...)
generate(...)
writeIr(...)
build(...)
```

unless those individual stages are intentionally part of the public API.

This does not mean "add a manager." It means the owner of a subsystem should
own the coordination of that subsystem.

---

## 2. Production-code standard

Write code that looks like it will be maintained by an experienced compiler
engineer.

Prefer:

- straightforward control flow
- cohesive functions
- cohesive modules
- explicit ownership and lifetime boundaries
- descriptive names
- early returns
- existing abstractions
- minimal state
- narrow subsystem interfaces

Avoid:

- giant multipurpose functions
- giant multipurpose modules
- boolean-parameter explosions
- duplicated logic
- speculative abstractions
- deeply nested control flow
- code whose correctness depends on comments rather than structure
- historical/development narration in production code
- comments that merely restate syntax

Do not optimize for making a diff look small. Optimize for leaving the codebase
easier to understand than you found it.

Do not "clean up" unrelated code while implementing a feature unless the cleanup
is necessary to establish the correct architectural boundary.

---

## 3. Before changing code

### Understand the existing boundary first

Before modifying a subsystem:

- inspect its callers
- inspect its imports
- inspect the relevant tests
- identify the invariants it relies on
- identify whether the change belongs inside the subsystem or at its boundary

Do not infer architecture from one function or one file.

### Self-hosting comes first

The committed seed must be able to parse `src/`.

`bootstrap/prismio-seed.ll` is LLVM IR for a compiler built from an earlier tree.
If new syntax is added to the compiler source and used immediately, the seed
can no longer parse the source that it is supposed to rebuild.

New syntax therefore lands in two steps:

1. Teach the frontend the syntax. Do not use it in `src/`. Build and verify.
2. Refresh the seed with `tools/refresh_seed.ps1 -Compiler <gen2>`.
3. Only then use the new syntax in `src/`.

### Judge changes by emitted behavior

For behavior-preserving changes, the compiler's output is the contract.

The full validation loop is:

```bash
tools/bootstrap.ps1 -Compiler <known-good> -Out build/g1.exe
tools/bootstrap.ps1 -Compiler build/g1.exe -Out build/g2.exe
```

Then:

```bash
cd tests
python test_runner.py
```

and:

```bash
python tools/aif_differential.py --compiler build/g2.exe
```

For a refactor that is intended to preserve behavior, emitted IR,
diagnostics, and AIF results must remain identical for the checked corpus.

A successful first build is not enough.

### Two generations before trusting a compiler change

A compiler can produce a successful binary because the previous generation
built it.

Do not consider a self-hosting change validated until the next generation has
successfully rebuilt the compiler and passed the relevant tests.

---

## 4. Language and module layout

### Imports

A module's import path is its location.

```text
src/ir/expr.psm    -> import ir.expr
src/ir/*.psm       -> import ir.*
```

Wildcard package imports consume modules in sorted order. Merge order therefore
affects declaration/emission order and is load-bearing.

Import paths are resolved according to the compiler's import rules; do not add
ad-hoc per-module path logic.

### Internal functions do not need extern declarations

Sibling modules may call one another directly.

Do **not** write `extern fn` declarations for functions that this source tree
defines. The merged module is registered before semantic analysis.

A local function incorrectly declared as foreign can also affect AIF's
provenance reasoning.

### `extern fn` means foreign code

Use `extern fn` only when the implementation lives outside Prismio source.

Every extern declaration must have an accurate FFI contract:

```text
borrow
alias
produce(free)
...
```

Do not omit ownership/provenance information to make an extern easier to call.

---

## 5. Ownership, handles, and globals

These rules are part of the language/compiler contract.

### Handles are `Ptr`

AST nodes, tokens, `TypeInfo`, and similar opaque handles use `Ptr`.

Example:

```text
struct ASTNode {
    child1: Ptr
}
```

Use:

```text
ptr_to_node(p)
```

to recover the object.

Absent handles are real `NULL` pointers.

### Test pointer absence with pointer helpers

Use:

```text
nodeExists(...)
nodeIsNull(...)
ptr_is_null(...)
```

as appropriate.

Do not compare a `Ptr` with `""` or rely on string punning.

### The old string-punning invariant is retired

Handles were previously represented through `String`. That forced the old
"never-zero first field" rule because an empty string was used as the absent
sentinel.

That model is gone.

`NodeKind` and `TypeKind` still reserve ordinal zero. Those values are part of
the ABI and must not be reused.

### Globals holding handles need no initializer

A global such as:

```text
let mut tail: Ptr
```

is intentionally uninitialized.

Global initialization does not run arbitrary Prismio code before `main`, and a
zero-filled pointer is already `NULL`.

Do not invent initializer calls merely to make the declaration look explicit.

### Strings and structs are affine

Naming an affine value twice moves it.

When a value must be observed in two places, use the appropriate `alias`
accessor or create an intentional clone.

This is especially important in loops and conditional paths.

Do not fight the ownership model with unnecessary clones.

---

## 6. Naming

| Kind | Convention | Example |
|---|---|---|
| Functions, parameters, locals, fields | `camelCase` | `parseExpression`, `startCol` |
| Types | `PascalCase` | `ASTNode`, `TokenType` |
| Enum variants, constants, constant globals | `SCREAMING_SNAKE` | `STRUCT_DECL`, `AIF_TIER_T0` |
| `extern fn` symbols | C ABI spelling | `str_concat`, `ir_build_call` |

The extern-name exception is intentional.

An extern declaration is visible FFI surface. Preserve the exact C symbol name.

### Name by responsibility

Prefer short names that communicate the operation:

```text
lexIdentifier
parseExpression
emitLoad
advance
expect
resolveImport
```

Avoid names such as:

```text
processIdentifierAndDetermineTokenType
```

A good name should remove the need for a comment.

### Parser and lexer naming

Keep the distinction consistent:

```text
parserX / lexerX
```

for parser/lexer machinery, and:

```text
parseX / lexX
```

for grammar productions or language-level operations.

---

## 7. Functions and control flow

### One responsibility per function

A function may coordinate several calls when those calls together form one
clear operation.

Do not let one function simultaneously:

- parse arguments
- resolve a project
- mutate global compiler state
- generate IR
- invoke the native toolchain
- format user-facing output

Split those responsibilities at meaningful boundaries.

### Prefer early returns

Use guard clauses to keep the main path visible.

Prefer:

```text
if (invalid) {
    return false
}

doWork()
return true
```

over deep nesting.

### Use `loop` for unconditional loops

Do not write:

```text
while (flag) {
    ...
    flag = false
}
```

when the loop's actual meaning is "run until break."

Use:

```text
loop {
    ...
    break
}
```

### Do not repeat ownership-sensitive work

An ownership-aware compiler makes naming and aliasing semantically important.

Do not bind a value twice simply because two local names would look nicer.
Use an `alias` accessor when repeated borrowing is the intended operation.

---

## 8. Comments

Comments are for information the code cannot communicate by itself.

### Good comments explain

- a non-obvious invariant
- a correctness constraint
- why an apparently simpler implementation is wrong
- a subtle ownership/lifetime requirement
- a compatibility requirement
- a performance result or measurement
- a failure mode that is easy to reintroduce

For example:

```text
// The cache is invalid after the workload codegen pass because generateModule
// registers every struct globally. Resetting here prevents the real pass from
// mistaking those declarations for already-emitted output.
```

That is useful because the code alone does not explain the invariant.

### Bad comments explain

- what the next line literally does
- obvious control flow
- variable names
- syntax
- section headings that add no information
- ticket history
- agent history
- dates of local development
- "this used to work differently" when that history is not required to
  understand the current invariant
- restatements of the specification

Avoid:

```text
// increment i
i = i + 1
```

Prefer:

```text
// Preserve declaration order because merge order is also IR emission order.
```

when that is the actual invariant.

### Do not turn source files into the specification

If a rule is fully documented in an RFC or SPEC, do not copy the entire rule
into comments.

Use a short reference when necessary, for example:

```text
// A workload failure is an optimization fallback, not a build failure.
```

The detailed rationale belongs in the specification/design document.

### Preserve subtle bug explanations

When fixing a subtle bug, leave a compact explanation of why the bug was subtle
and what invariant prevents its return.

Do not preserve a full development diary.

### Comment density should be earned

A file with many comments is not automatically better.

The default should be:

> **Code explains what. Comments explain why.**

If a comment can be removed by choosing a better name or simplifying the code,
change the code and delete the comment.

---

## 9. Error handling and process control

Low-level compiler subsystems should report errors to their caller rather than
terminating the whole process whenever practical.

Prefer:

```text
resolver -> records diagnostic / returns failure
driver   -> decides whether compilation continues or exits
```

over:

```text
resolver -> prints diagnostic -> exits process
```

A subsystem should not assume that its only caller is the command-line
executable.

This keeps the compiler usable by:

- the CLI
- tests
- IDE tooling
- future library consumers
- other compiler commands

Process termination belongs at the application boundary unless immediate
termination is required to preserve a proven invariant.

---

## 10. State and cleanup

Global compiler state is dangerous.

Whenever a subsystem temporarily changes global state:

1. record what changed
2. restore it on every exit path
3. keep the restoration close to the code that establishes the temporary state
4. use one cleanup helper when the language has no `defer`

For example, a workload pass that changes allocator, profile, or IR state must
restore all of it before the real compilation continues.

Do not rely on "this normally returns at the bottom."

Every failure path matters.

---

## 11. CLI architecture

CLI parsing and compiler execution are separate responsibilities.

Prefer:

```text
argv
  -> parse command
  -> command/options representation
  -> execute command
```

over mutating many local flags while simultaneously deciding what the compiler
should do.

Avoid boolean-parameter explosions such as:

```text
compileSource(
    path,
    output,
    runAfterBuild,
    bootstrap,
    verify,
    debug,
    debugInfo,
    optimized,
    jit
)
```

Prefer an options structure when a command has several independent settings:

```text
CompileOptions {
    outputFile
    runAfterBuild
    bootstrap
    verify
    debug
    debugInfo
    optimized
    jit
}
```

Do not make this abstraction merely for style. Introduce it when the parameter
set represents a real concept.

---

## 12. FFI and native boundaries

Keep C/LLVM/runtime integration behind an obvious boundary.

Group native declarations and native-facing operations separately from language
frontend logic.

Do not scatter C ABI declarations throughout unrelated compiler modules.

Native interfaces should make ownership and lifetime explicit.

When a native function allocates memory, document who owns the result and how it
is released.

When a native function borrows memory, document that it does not take ownership.

When a native API uses process-global state, document when that state must be
reset.

---

## 13. Performance

Prefer the clear implementation unless measurement says otherwise.

### Scanner

Do not allocate in the scanner's per-byte path.

A `str_concat` inside a byte-by-byte loop can change a linear scan into a
quadratic operation. This is a structural performance constraint, not a
micro-optimization.

The keyword set may use a straightforward linear scan when that avoids
allocation-heavy lookup structures.

### Elsewhere

Optimize only when there is evidence.

When replacing a clear implementation with a faster one, document:

- what workload was measured
- what changed
- what improvement was observed
- what invariant the optimized version relies on

Do not add caches, indexes, specialized paths, or complicated data structures
without a measured reason.

---

## 14. Testing and validation

Tests are part of the architecture.

When changing a compiler subsystem:

1. run the focused tests
2. bootstrap the compiler
3. rebuild the next generation
4. run the full test suite
5. run AIF differential testing when relevant

A refactor should not be considered safe merely because the modified file
parses.

### Behavior-preserving refactors

For a behavior-preserving change:

- diagnostics should remain equivalent
- emitted IR should remain byte-identical where required
- AIF tiers should remain equivalent
- bootstrap/fixpoint behavior should remain intact

If output changes intentionally, state that explicitly and add/update the test
that defines the new behavior.

---

## 15. Working with agents

Agents must follow the repository architecture, not just the local coding style.

Before making a substantial change, an agent should:

1. inspect the relevant modules and callers
2. identify the owning subsystem
3. check the relevant tests/spec
4. determine whether the change requires a new module
5. make the smallest coherent architectural change
6. run the appropriate bootstrap/test loop

### Do not solve architecture problems with comments

If code is hard to understand because several subsystems are mixed together,
**split the responsibility**.

Do not add a long comment explaining why unrelated code happens to coexist.

### Do not solve architecture problems with one-off wrappers

If a function exists only to hide eight lines from one caller, it is probably
not an abstraction.

Use abstractions when they define a real boundary or eliminate repeated,
semantically identical coordination.

### Do not leave partial modularization

When moving a subsystem:

- move its implementation
- move its related state
- move its private helpers
- keep the public interface narrow
- remove the old copies
- update imports
- rebuild immediately

Do not leave two versions of the same responsibility "temporarily."

### Prefer one coherent refactor over many cosmetic edits

A module extraction is worthwhile when it makes the ownership boundary clearer.

Avoid unrelated formatting churn, renaming campaigns, or stylistic rewrites
during a functional change.

---

## 16. A practical review checklist

Before submitting compiler code, ask:

### Architecture
- Can this file be described as one subsystem?
- Did I put the code in the module that owns the responsibility?
- Did I add a new module instead of growing an unrelated one?
- Is the dependency direction still clear?

### Code
- Is each function cohesive?
- Are early returns keeping control flow shallow?
- Are ownership and lifetime operations explicit?
- Did I avoid speculative abstractions?

### Comments
- Does each comment explain something non-obvious?
- Could a better name remove the comment?
- Did I avoid development history and specification repetition?
- Is the subtle invariant preserved where it matters?

### Correctness
- Does the seed still parse `src/`?
- Does the compiler bootstrap?
- Does the next generation bootstrap?
- Did focused and full tests pass?
- Did emitted behavior remain unchanged where required?

### Performance
- Did I accidentally add allocation to a hot path?
- Is a new optimization supported by measurement?
- Did I preserve the simple implementation where performance is not proven to
  matter?

---

## 17. The governing principles

When rules appear to conflict, use these principles:

1. **Correctness before convenience.**
2. **Architecture before local cleverness.**
3. **Clear code before comments.**
4. **Comments explain why, not what.**
5. **Modules follow responsibilities.**
6. **Abstractions must earn their existence.**
7. **Measure before optimizing.**
8. **Validate through self-hosting, not just compilation.**
9. **Keep process control at the application boundary.**
10. **Leave the codebase easier to understand than you found it.**
