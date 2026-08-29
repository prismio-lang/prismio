# Prismio — v1 Readiness: What Exists, What's Missing

Date: 2026-07-30. Written as the companion to a `COMPILER_AUDIT.md` that catalogued *defects* and has since been deleted -- it graded a compiler with 36 tests, no CI and unparsed `impl`, and every line of it was overtaken; `git log` has it. This document
answers a different question: **measured against what a serious self-hosted compiler needs to
call itself v1, which capabilities exist and which don't** — independent of what any
documentation claims.

> ## Status — 2026-08-01
>
> **Tier 0 is complete. All ten blockers are closed**, and so is most of what mattered in Tier 1.
> The analysis below is left as written, because the reasoning still holds and the record of what
> was missing is worth keeping. This box is what changed.
>
> Closed since: casts (`as`) · unary `-`/`!`/`~` · bitwise ops and shifts · string escapes ·
> short-circuit `and`/`or` · scoped symbol table · enforced `mut` · arrays for every element type,
> taking their element type from an annotation · **source spans and real diagnostics with error
> recovery** · compound assignment · definite return · unreachable code · loop-aware move checking ·
> `-O0..-O3` · CI on three platforms.
>
> The central finding above has partly resolved itself. `char_code()` is now `return c as Int`
> rather than a 90-branch chain, and `str_equals(a, b) == 1` is now a *deliberate* spelling —
> `String ==` is rejected with a message naming the alternative, because comparing two string
> pointers silently answered "not equal" for equal strings. The pointer-punning through `String`
> and the hand-built linked lists remain, and still stand for missing pointers and generics.
>
> **Not done, and deliberately so:** the memory model (the next piece of work; the seam is in
> place — see `ir_set_alloc_function`/`ir_set_free_function`), an error-handling story, `-g` debug
> info, generics, methods, and closures. Tier 2 and Tier 3 are untouched.
>
> **Known limits worth stating plainly at v1:** compile time is superlinear in module size
> (~290 ms for the 155 KB compiler, ~500 ms for a 105 KB single module — the remaining cost is
> sema's per-identifier module scans); a heap value is freed only where it is bound to a name, so a
> temporary written inline as an argument still leaks (AIF Level 4); arrays are stack-allocated, so
> one cannot be returned from the function that created it and is never freed.

> ## Status — 2026-08-20
>
> The 2026-08-01 box below is kept as written. This one supersedes it; the body of the document
> is still deliberately frozen at 2026-07-30.
>
> **Everything the box below listed as "not done, and deliberately so" has landed except methods
> and closures.**
>
> - **The memory model.** AIF Levels 0–5: tier inference and the manifest, stack promotion,
>   scope drops, `region` arenas plus automatic placement, affine `String`/`List`, refcounting,
>   ownership inside containers, a cycle collector that this corpus can omit entirely. Plus
>   `--verify`, `--why` and a differential against an independent oracle.
> - **An error-handling story.** Payload-carrying enum variants, `Option`/`Result`, `match` with
>   exhaustiveness and arm-reachability checking.
> - **Generics**, by monomorphisation, as an AST-to-AST transform. `Map<K,V>` is written in
>   Prismio.
> - **`-g` debug info.** Line tables, subprograms, lexical blocks, locals and struct layouts,
>   with the layout permutation and hot/cold split described truthfully. See `docs/DEBUGGING.md`.
>   No PDB/CodeView, so an MSVC-targeted Windows build has no debug info.
> - **Concurrency**: `spawn`/`join`, OS threads and channels, thread-affinity inference.
>
> **Still not done:** methods / `impl` blocks, closures, slices, module namespacing and
> visibility, and first-class pointers. Cross-compilation landed 2026-08-21 (`--target`,
> `--sysroot`, a per-triple runtime archive) and has been proven against one non-host target.
>
> **The superlinear compile time in the box below no longer reproduces.** Measured 2026-08-20:
> 733 B → 29 ms, 3 KB → 21 ms, 60 KB → 72 ms, i.e. 82× the input for ~2.5× the time. The fixed
> cost is the `std.io` prelude, which dominates small programs — no longer implicit as of
> 2026-08-21, so a program with no I/O no longer pays it. The 2026-08-17 session removed
> the cubic term and made lexing linear.

## The bar being used

"v1 of a serious self-hosted compiler" is taken to mean, concretely:

> A competent third party who has never read the compiler's source can write a non-trivial
> program, build it, ship it, and debug it — without working around the compiler, without
> reading its internals to find out what's implemented, and without hitting silent wrong
> answers.

Reference points at their own 1.0/first-serious-release: Go 1.0, Rust 1.0, Zig's self-hosted
compiler, Nim, TCC. Not "matches Rust today" — matches what those projects shipped when they
first told outsiders to use them.

---

## The central finding

**Self-hosting proves the language is *minimally sufficient*, not that it's *adequate*.** Prismio
compiles itself, which is real. But it does so by systematically routing around its own missing
features, and those workarounds are visible throughout `src/`:

| Workaround in the compiler's own source | The missing feature it substitutes for |
|---|---|
| `char_code()` — a **90-branch `if` chain** over every ASCII character (`utils.psm:57-150`) | No cast from `Char` to `Int` |
| `ASTNode.child1: String` holding a node pointer; `ptr_to_node`/`node_to_ptr` FFI (`ast.psm:47-62`) | No pointer type, no unions, no generics |
| `extern fn parse_declaration(p: Parser) -> ASTNode` declared in the same file that defines it (`parser.psm:81-92`) | No declaration-order independence / no forward declarations |
| `str_equals(a, b) == 1` everywhere instead of `a == b` | `==` on `String` compares pointers; no `Bool`-returning comparison |
| `Token.tok_next: String` linked lists built by hand (`token.psm:34`) | No collections, no generics, no real stdlib |
| `let is_looping = true; while (is_looping) { ... is_looping = false }` | Idiom left from before `break`; still pervasive |

This is the same shape as early C, and it's not a scandal — it's how bootstrapping works. But it
means "it self-hosts" cannot be used as evidence that the language is ready for anyone else.
`char_code()` is the tell: a language where converting a character to its integer value requires
90 hand-written branches is not yet a language other people can write systems code in.

**Rough completeness against the v1 bar: ~35%.** Backend plumbing and bootstrap are in good
shape; the language core and all semantic analysis are roughly half-built; compiler engineering
(diagnostics, flow analysis, optimization, debug info) is largely absent.

---

## 1. Language core

### 1.1 Types

| Capability | Status | Notes |
|---|---|---|
| Sized integers `I8/16/32/64`, `U8/16/32/64` | ✅ | Declared and lowered correctly |
| `Isize`/`Usize` | ◑ | `types.psm:66,71` hardcode `i64`; `map_type` uses target width. Disagree on wasm |
| `Float` | ◑ | `double` only. **No `F32`** |
| `Bool`, `Char` | ✅ | `Char` is `i8` — no Unicode scalar / UTF-8 story |
| `String` | ◑ | Opaque `ptr` to C string. No length. Move-only and freed at scope exit as of AIF Level 4, but only where bound to a name |
| Structs | ◑ | Always heap-allocated via `malloc`, always by-pointer. No stack structs, no by-value passing |
| C-like enums | ✅ | `i32`, auto-numbered from 0. No explicit discriminants |
| **Tagged unions / enums with payloads** | ✗ | Blocks `Option`, `Result`, and every sum type |
| Arrays | ◑ | **`i32` element type only** (audit §1.5); stack `alloca`; **no length**, no bounds checks |
| **Slices** (ptr + len) | ✗ | The single most-missed type in a systems language |
| `List<T>` | ◑ | One hardcoded generic, matched by the literal string `"List"` (`parser.psm:161`) |
| **Tuples / multiple return** | ✗ | Functions return exactly one value |
| **Pointer type with `&` / deref** | ✗ | A `Ptr` type exists in `types.psm:59` but is unreachable — no syntax produces it |
| **Type aliases** | ✗ | |
| **`const` / compile-time constants** | ✗ | Only mutable globals |
| **Type casts / conversions** | ✅ *Added 2026-07-31.* `expr as T` between integer widths, int/float, Char/Int, Bool/Int, Enum/Int. Unsigned, Char and Bool zero-extend; signed integers sign-extend. Casting *to* Bool is rejected — write `x != 0` |

**The cast gap is the largest single hole in the type system.** Sized integer types exist but are
mutually unreachable: you can declare `I64` and `U8` and never convert between them. `Char`↔`Int`
requires `char_code()`. `Int`↔`Float` is impossible. This makes the entire sized-integer family
decorative — you can annotate with it, but you can't compute across it.

### 1.2 Operators

| Capability | Status |
|---|---|
| `+ - * /` | ✅ (`%` broken on sized ints — audit §1.10) |
| Comparison `== != < <= > >=` | ◑ signed/unsigned handled; `String`/struct silently compare pointers |
| `and` / `or` | ✅ *Short-circuiting since 2026-07-30* (audit §1.2) |
| **Unary `-`** | ✅ *Added 2026-07-30.* `-<numeric literal>` is folded into the literal, so negative constants work in global initializers and in sized-int coercion. Negating an unsigned type is rejected |
| **Unary `!` / `not`** | ✅ *Added 2026-07-30* |
| **Bitwise `& \| ^ ~`** | ✅ *Added 2026-07-31.* Bind **tighter than `==`**, unlike C — `flags & MASK != 0` reads as written |
| **Shifts `<< >>`** | ✅ *Added 2026-07-31.* `>>` is arithmetic for signed, logical for unsigned |
| **Compound assignment `+= -=` …** | ✅ *Added 2026-07-31.* Arithmetic and bitwise forms. Restricted to a plain variable target, so the desugaring cannot double-evaluate a subexpression |
| **Address-of / dereference** | ✗ |
| **Ternary / if-expression** | ✗ `if` is a statement only |

### 1.3 Literals and lexical

| Capability | Status |
|---|---|
| Decimal int, float, bool, char | ✅ |
| Char escapes (`'\n'`, `'\t'`, …) | ✅ |
| **String escapes** | ✅ *Added 2026-07-30.* `\n \t \r \\ \" \'`. A NUL escape is rejected with a reason rather than silently truncating, since `String` is NUL-terminated |
| **Hex / binary / octal literals** | ✗ |
| **Numeric separators** (`1_000_000`) | ✗ |
| **Float exponents** (`1e10`) | ✗ |
| **Literal type suffixes** (`1u8`) | ✗ |
| Line comments `//` | ✅ |
| **Block comments `/* */`** | ✗ |
| **Doc comments** | ✗ |
| **Raw / multiline strings** | ✗ |

### 1.4 Control flow

| Capability | Status |
|---|---|
| `if` / `else if` / `else` | ✅ Parens mandatory |
| `while`, `loop`, `for x in a..b` | ✅ Range end re-evaluated every iteration (`ir.psm:787`) |
| `break` / `continue` | ✅ |
| **Labeled break/continue** | ✗ |
| `return` | ✅ Bare `return` mid-block is broken (`parser.psm:505`) |
| `match` | ◑ It's a **switch**: arms are `expr => block` or `_`. No destructuring, bindings, guards, or-patterns, ranges. No exhaustiveness check. Arms after `_` silently discarded |
| **`for x in collection`** | ✗ Integer ranges only |
| **`defer` / scope guards** | ✗ |

### 1.5 Functions and abstraction

| Capability | Status |
|---|---|
| Functions, params, recursion | ✅ |
| **Overloading by parameter type** | ✅ Real, with mangling — genuinely nice |
| `sink` / `inout` parameter conventions | ✅ Distinctive and well-designed |
| C ABI FFI via `extern fn` | ✅ **Works well; the escape hatch that makes everything else possible** |
| **Methods / `impl` blocks** | ✗ Keyword lexes, node kind exists, parser rejects it |
| **Traits / interfaces** | ✗ Same |
| **Generics** | ✗ Beyond the hardcoded `List<T>` |
| **Closures / lambdas** | ✗ |
| **Function pointers / function types** | ✗ Not expressible in a type annotation |
| **Default args / varargs** | ✗ Also blocks calling C varargs like `printf` |

### 1.6 Modules

| Capability | Status |
|---|---|
| `import <ident>` | ◑ One identifier → sibling `.psm`. Whole-program flatten with first-wins dedupe |
| Import cycles / diamonds | ✅ Handled correctly and deliberately (`main.psm:131-165`) |
| **Namespacing** | ✗ All names are global. Two modules with the same struct name silently collapse |
| **Visibility (`pub`)** | ✗ Everything is public |
| **Import paths / aliasing / selective import** | ✗ |
| **Separate compilation** | ✗ Whole program re-parsed and re-lowered every build |

### 1.7 Memory and safety

| Capability | Status |
|---|---|
| Move tracking, `sink`/`inout`, borrow marking | ◑ Real design, but flow-insensitive — unsound in loops (audit §1.8) |
| Explicit `drop(x)` | ✅ |
| **Automatic drop at scope exit** | ✅ AIF Level 2 — all four exits, reverse construction order |
| **Leak freedom** | ◑ Structs, strings and lists are move-only and freed *where bound to a name*. A temporary written inline as an argument has no owner and no free point; arrays are frame storage |
| **Array bounds checking** | ✗ |
| **Null safety / optionals** | ✗ |
| **Integer overflow semantics** | ✗ Undefined; no wrapping/checked/saturating ops |
| **Panic / abort with a message** | ✗ No panic mechanism at all |
| **Error handling story** | ✗ No `Result`, no error unions, no exceptions. `throw` lexes as a keyword and is unparsed |

---

## 2. Compiler engineering

| Capability | Status | Notes |
|---|---|---|
| Lexer → Parser → AST | ✅ | Clean, readable |
| **Source spans** | ✗ | Tokens carry `line` only — no column, no file. **Never used in any message** |
| **Diagnostics** | ✗ | No file/line/col/snippet/code/note. `parser_expect` prints a raw integer |
| **Error recovery** | ✗ | First error calls `exit(1)`. **One diagnostic per run, always** |
| **Warnings** | ✗ | No unused-variable, unreachable-code, shadowing, or dead-store warnings |
| **Symbol table** | ◑ | Scoped (`runtime/ir_symbols.c`), still a linear array rather than a hash map |
| **Scope handling** | ✅ | *Added 2026-07-31.* Blocks, loop bodies, for-variables and parameters each scope. Each binding carries its own slot, so sibling blocks reusing a name get separate stack allocations |
| Type checking | ◑ | Works for the implemented subset; `Enum ≡ Int` by design defeats enum safety |
| Type inference | ◑ | `let x = expr` only. No bidirectional or generic inference |
| **CFG construction** | ✗ | **Nothing builds a control-flow graph** |
| **Dataflow analysis** | ✗ | No framework exists |
| **Definite return** | ✗ | Missing return silently emits `ret <t> 0` or invalid IR |
| **Definite assignment** | ✗ | |
| **Exhaustiveness checking** | ✗ | |
| **Unreachable-code detection** | ✗ | Emits instructions after terminators instead |
| Own IR / SSA | ✗ | AST → LLVM directly. Defensible for v1 |
| **Optimization** | ✗ | **No `-O` flag; no LLVM pass pipeline is ever run.** Output is unoptimized |
| **Debug info (DWARF/PDB)** | ✗ | **Compiled programs cannot be source-debugged** |
| Backend | ◑ | Text IR today; LLVM C API port in progress |
| Linking | ✅ | clang driver, embedded runtime sources, runtime-hash staleness guard |
| **Cross-compilation** | ◑ | `--target <triple>` + `--sysroot`; triple/pointer width/layout from LLVM. Built and run for `x86_64-apple-macos`; other triples produce verifying IR but are unlinked here |
| **Object output / `-c`** | ✗ | Whole-program to executable only |
| **Incremental compilation** | ✗ | |
| Compile speed | ◑ | **Quadratic** — 2.05× input costs 4.2× time (audit §5) |

**The structural point:** six of the missing Tier-1 semantic checks — definite return, definite
assignment, exhaustiveness, unreachable code, flow-sensitive moves, and correct scoping — all
require **two data structures the compiler does not have: a scoped symbol table and a CFG.**
Attempting them one at a time without those will produce six more ad-hoc AST walks like the four
that already exist (`sema_statement`, `generate_statement`, `predeclare_locals_stmt`,
`collect_strings_stmt`), which is exactly how audit §1.1 happened. **Build the symbol table and
the CFG first; they are the enabling work for roughly half the remaining v1 scope.**

---

## 3. Toolchain and infrastructure

| Capability | Status | Notes |
|---|---|---|
| **Self-hosting to a byte-identical fixed point** | ✅ | `a.ll` == `b.ll`. The strongest thing in the project |
| **Committed bootstrap seed** | ✅ | `bootstrap/prismio-seed.ll`, with a rationale comment. Correct practice |
| CLI driver | ◑ | `build`/`run`/`bootstrap`/`runtime-hash`, `-o`, `-g`, `-O`, `--verify` |
| **`--help` / `--version`** | ✗ | `prismio --help` is treated as a filename |
| **`-O` / `-g` / `-c` / `--emit` / `-D` / warning flags** | ✗ | None exist |
| Test runner | ◑ | **Exit-code-only oracle.** No expected-output comparison |
| **Conformance suite** | ✗ | 30 smoke tests that self-report `PASS`. No golden IR, no `llc`-verify, no multi-error tests, no fuzzing |
| **CI** | ✗ | No `.github/`, no workflows anywhere |
| **Build system for the compiler** | ✗ | No Makefile/CMake/build.sh — only paired `.ps1`/`.sh` that duplicate logic |
| Packaging / install | ✅ | `tools/package.*`, `install.ps1`, runtime hash recorded |
| **Editor support** | ◑ | Real IntelliJ plugin (`../prismio-intellij`): JFlex lexer, parser, highlighter, completion, formatter, run configs. **But it's a second, hand-written grammar in Java that will drift from `src/parser.psm`** |
| **LSP server** | ✗ | Plugin is IntelliJ-specific; nothing for VS Code/vim |
| **Formatter** | ◑ | Exists in the IntelliJ plugin only; no `prismio fmt` |
| **Standard library** | ✗ | `dist/stdlib/` contains one README. `libs/math/root.psm` is a stub. `print`/`println` are compiler builtins |
| **Documentation generator** | ✗ | |
| **Package manager** | ✗ | Correctly out of scope for v1 |

---

## 4. What to build, in order

### Tier 0 — v1 blockers. Ordinary programs cannot be written without these.

1. **Type casts** (`as`). Unblocks the entire sized-integer family and deletes `char_code()`.
2. **Unary `-` and `!`.** No negative numbers today.
3. **Bitwise ops and shifts.** Non-negotiable for a systems language.
4. **String escapes** in the lexer. Currently no newline/tab/quote in any string literal.
5. **Short-circuit `and`/`or`** (audit §1.2) — semantics, and it's crashing your own compiler.
6. **Scoped symbol table** → fixes block scoping, the global-shadow miscompile, and the stack
   smash (audit §1.4) in one change.
7. **Enforce `mut`** (audit §1.3).
8. **Arrays that work for all element types, plus slices with a length** (audit §1.5).
9. **Source spans + real diagnostics + error recovery.** Multiple errors per run with
   file:line:col. This is what makes the compiler usable by someone who isn't you.
10. **Compound assignment.** Cheap; large ergonomic return.

### Tier 1 — required before calling it "serious".

11. **CFG + dataflow framework**, then: definite return, definite assignment, unreachable code,
    exhaustiveness, and flow-sensitive move checking (audit §1.8) all fall out of it.
12. **Tagged unions (enum payloads)** → `Option`/`Result` → a real error-handling story.
13. **Pattern matching** worth the name: destructuring, bindings, exhaustiveness.
14. **Methods / `impl` blocks.**
15. **Generics.** Without them there are no containers, and `List<T>` stays a hardcoded hack.
16. **Pointers as a first-class type** with `&`/deref.
17. **`defer`** or scope-based drop, and free `String`/array/list — today they leak unconditionally.
18. **Module namespacing + visibility.**
19. **`-O` with an LLVM pass pipeline**, and **`-g` debug info.** Right now nothing you compile
    can be optimized or debugged.
20. **Panic with a message + array bounds checks + defined integer-overflow semantics.**
21. **CI running the full bootstrap to fixpoint**, and a conformance suite with expected output
    and IR verification.

### Tier 2 — expected at v1 by modern standards, defensible to defer.

Closures and function pointers · traits/interfaces · tuples and multiple return ·
`const`/comptime · labeled break · cross-compilation · separate/incremental compilation ·
`prismio fmt` · an LSP server · a real stdlib (`io`, `str`, `mem`, `fs`, `math`).

### Tier 3 — post-v1.

Package manager · concurrency · macros/metaprogramming · doc generator.

---

## 5. Honest summary

**Solid and worth protecting:** the bootstrap (fixpoint-verified, seeded), the C ABI FFI,
type-based overloading with mangling, the `sink`/`inout` ownership design, import cycle handling,
and the runtime-hash staleness guard. The IntelliJ plugin is more editor tooling than most
languages have at this stage.

**The gap is concentrated in two places**, and both are more tractable than the raw list suggests:

- **The language core is missing its connective tissue** — casts, unary operators, bitwise ops,
  string escapes, slices. Individually small; collectively they're why nobody but you can write
  Prismio. Most are days of work each, and they are the highest return per hour in the project.
- **There is no semantic-analysis infrastructure** — no scoped symbol table, no CFG, no dataflow.
  This is the real engineering work, and it gates roughly half of Tier 1 at once.

**The most useful reframing:** the backend is the part you're already planning to invest in (the
LLVM C API port), and it's the part that's in the best shape. The frontend and middle-end are
where v1 actually lives. If the LLVM port lands and nothing else changes, Prismio will have a
production-grade backend emitting code for a language that still can't write `-1`.
