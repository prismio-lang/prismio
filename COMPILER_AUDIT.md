# Prismio — Compiler Audit

Date: 2026-07-30. Audited against the benchmark of a serious self-hosted compiler
(rustc/go/zig-class expectations), not against a toy-language bar.

**Method.** Every source file in `src/` read in full; `runtime/llvm-bridge.c` and the
string/array runtime read directly; 21 targeted probe programs written and compiled with the
freshly bootstrapped `build/gen1.exe` (LLVM 22.1 toolchain present on this machine). Every
defect marked **CONFIRMED** below was reproduced end-to-end — compiled, and where relevant
run — not inferred from reading. Doc claims were checked by sampling 11 of the 94 pages in
`../docs/content`.

---

## Backend replacement (completed 2026-07-31)

The text emitter is gone. `runtime/llvm-bridge.c` has been deleted and
`runtime/llvm-api-backend.c`, built on the real LLVM C API, is the only backend.

- The compiler **self-hosts on it to a fixed point** and passes **41/41**.
- `src/ir.psm` emits no IR text at all; struct literals, member access, array
  literals, indexing, string literals and struct type definitions go through
  typed builders. `ir_append()` survives only as a loud failure that stops raw
  text creeping back in.
- Compiler bookkeeping (symbol tables, move/borrow state, loop targets) moved to
  `runtime/ir_symbols.c`. It was never backend state — §2 of this document
  flagged it, and a second backend proved it: linking failed on precisely those
  symbols and nothing else.
- Allocation is a policy hook (`ir_set_alloc_function` / `ir_set_free_function`,
  `ir_alloc_object` / `ir_free_object`), so the memory model is one place to
  change rather than being spelled out in codegen.
- Building now requires LLVM's headers and C API library. `tools/setup_llvm.py`
  finds or fetches one and records it in `third_party/llvm-paths.json`.

Two consequences worth noting. `LLVMVerifyModule` now runs before anything is
written, so a malformed module is reported against the code that built it rather
than surfacing later as an `llc` parse error. And several defects below became
structurally impossible rather than merely fixed: writes into a terminated block
are dropped (§1.7 can no longer emit invalid IR), and an unknown type key is a
hard error instead of silently defaulting to `i32`.

---

## Remediation status (updated 2026-07-30, verified on `build/gen12.exe`)

Seven items below are **FIXED**, each verified end-to-end and covered by a new regression test.
The bootstrap still reaches a byte-identical IR fixed point and the suite is **41/41** (was 36/36;
five tests added).

| Item | Status |
|---|---|
| 1.1 Strings in `for`/`loop`/`match` bodies | **FIXED** — `tests/test_31_strings_in_control_flow.psm` |
| 1.2 `and`/`or` short-circuiting | **FIXED** — `tests/test_35_short_circuit.psm`. The compiler segfault on `print()` is fixed as a consequence |
| 1.10 `%` on sized integers | **FIXED** — `tests/test_32_sized_int_modulo.psm` |
| 1.11 Global initializers | **FIXED** — string globals work; non-constant initializers are now a clear error |
| 1.12 `print_bool` ABI | **FIXED** — explicit `zext i1 → i32` at the call site |
| Unary `-` and `!` | **ADDED** — `tests/test_33_unary_operators.psm` |
| String escape sequences | **ADDED** — `tests/test_34_string_escapes.psm` |

**1.4 (scoping) is now FIXED** — all three symptoms, 2026-07-31. `runtime/ir_symbols.c` carries a
scope stack, and every binding gets its own slot name:

- bindings no longer leak past their block (`tests/neg_07_scope_leak.psm`);
- a local shadowing a global reads and writes the same place (`tests/test_38_scoping.psm`);
- sibling blocks reusing a name get separate, correctly-sized allocations — the `alloca i8`
  written with an 8-byte pointer is now `%v.1 = alloca i8` and `%v.2 = alloca ptr`.

The `predeclare_locals` pre-pass is gone; locals are created at their declaration and the backend
hoists every alloca into the entry block, so a `let` inside a loop body still allocates once.

**1.5, 1.6, 1.7, 1.8 and 1.9 are also FIXED** (2026-07-31):

- **1.5** arrays take their element type from sema, so `["a","b"]`, `[1.5]` and `['A']` allocate
  `[N x ptr]`, `[N x double]`, `[N x i8]` (`tests/test_39_typed_arrays.psm`);
- **1.6** definite return — a value-returning function that can fall off its end is rejected
  (`tests/neg_08_missing_return.psm`);
- **1.7** unreachable code after `return`/`break`/`continue` is rejected
  (`tests/neg_09_unreachable_code.psm`);
- **1.8** moving out of a binding that predates the enclosing loop is rejected — the `drop(x)`
  in a loop that used to be a runtime double free (`tests/neg_10_move_in_loop.psm`);
- **1.9** `==` on `String`/struct is rejected with a message naming `str_equals`.

1.6–1.8 are done by structured analysis over the AST rather than a CFG. Prismio's control flow is
fully structured — no goto, no labeled break — so "can control continue past this statement?" is
answerable directly, and the analysis is conservative in the safe direction: when unsure it
reports that control *can* continue, which risks demanding an unreachable return rather than
letting a function fall off its end.

**1.3 (mutability) is FIXED** (2026-07-31). Assigning to a binding not declared `let mut` is
rejected (`tests/neg_11_immutable_assign.psm`). Landing it needed the compiler's own source
migrated — 159 `let mut` annotations across `src/*.psm`. The violations were collected in a single
run by shipping the check as a warning first, then flipping it to an error once the tree was
clean; one-error-per-build would have taken 75 rebuilds.

**Every defect in this document is now closed.**

---

## Closed after the original audit (2026-08-01)

These were not in the numbered list above — they were found by re-auditing once the numbered
defects were closed. Recorded here because each was a live silent-wrong-answer, not a stylistic
concern.

**Symbol tables truncated names at 63 characters and silently stopped recording when full**
(`runtime/ir_symbols.c`). Mangled overload symbols in this compiler's own source already reach 77
characters, so two overloads sharing a long prefix would have been recorded as one symbol and
given each other's return type, with no diagnostic at any point. Names are now interned at full
length and every table grows; an allocation failure is a hard error rather than a silent drop.

**Returning an array was a use-after-free that appeared to work.** Arrays are stack-allocated, so
`fn make() -> [Int] { let a = [1,2,3]  return a }` handed back a pointer into a discarded frame —
and reading it still found the values, so the program printed the right answer and exited 0.
Rejected outright now (`tests/neg_16_return_local_array.psm`); returning an array that came in as
a borrowed parameter is still allowed, because the caller owns that storage.

**Every builtin arity check reported and then dereferenced the argument it had just called
missing.** Harmless only because reporting an error exited the process; the moment sema started
recovering, `print()` with no arguments would have followed a null pointer. Arity is now checked
before any argument is walked (`tests/neg_14_wrong_arity.psm`).

**A non-constant global initializer was caught in codegen**, which meant no span, after every
other check had passed, and only for whichever global came first. Moved into sema.

**`generate_embedded_sources.ps1` had silently drifted.** It still listed `llvm-bridge.c`, deleted
several changes earlier, and had never learned about `ir_symbols.c` or `llvm-api-backend.c` —
running it would have written a header for a runtime that no longer existed. The script is deleted
(the Python one is cross-platform and was the only one anything used), and `tools/check_source_lists.py`
now fails the build if any of the six hand-maintained source lists disagree. It runs first in CI.

**`tools/verify_separation.*` had stopped checking anything.** Its byte signatures were IR text
(`getelementptr`, `icmp `) emitted by the old text backend. The C API builds instructions through
calls rather than by printing them, so those strings could no longer appear in *either* binary:
the user-binary check passed for the wrong reason and the compiler check would have failed. Both
now key on diagnostic strings that only `llvm-api-backend.c` contributes, and the sanity check
confirms the compiler does contain them.

Note on 1.2: the fix took two generations to take full effect. gen10 contains the new lowering but
its *own* code was compiled by gen9 without it; gen11 is the first compiler whose own guards
short-circuit. That is normal bootstrap behaviour and worth remembering for any future change to
code the compiler itself relies on.

---

## 0. Headline

The compiler genuinely self-hosts, and that is not a small thing. `build/a.ll` and `build/b.ll`
are **byte-identical** — gen1 and gen2 reach a fixed point, which is the real test of a
self-hosting bootstrap. The committed `bootstrap/prismio-seed.ll` with its rationale comment is
exactly how serious projects break the chicken-and-egg cycle. The ownership model (`sink`/`inout`,
move tracking, `drop`) is a real, deliberate design with negative tests behind it, and the
runtime-hash staleness guard in `main.psm` shows good instincts about build integrity.

The gap is not effort or ambition. It's that **the test suite validates far less than it appears
to**. All 36 tests pass. In under an hour of probing I found 15 defects, four of which make
headline language features unusable. The suite passes because it only checks process exit codes,
and because the tests happen to sidestep the broken paths — `test_27_for.psm` has no string
literal in its loop body, and that single accident is the only reason a completely broken `for`
loop looks green.

**Grades against the benchmark:**

| Dimension | Grade | One-line verdict |
|---|---|---|
| Self-hosting & bootstrap reproducibility | **A−** | Fixpoint-verified, seed committed. Genuinely good. |
| Ownership model design | **B** | Real and novel; enforcement is flow-insensitive and unsound in loops. |
| Lexer | **C−** | No string escapes, no block comments, no hex/underscore literals. |
| Parser | **C−** | No unary operators; `trait`/`impl` unparsed; dies on first error. |
| Name resolution & scoping | **F** | No block scopes at all. Locals leak; locals shadowing globals read the global. |
| Type system soundness | **D** | Enum≡Int by design; no casts; `%` broken on sized ints. |
| Semantic checks | **D−** | No definite-return, no exhaustiveness, **no mutability enforcement**. |
| Codegen correctness | **D** | Four confirmed miscompiles/invalid-IR paths in common code. |
| Diagnostics | **F** | No line, column, file, or snippet. One error then `exit(1)`. |
| Test suite | **D** | Exit-code-only oracle; no expected output; no IR verification. |
| CI / build infra | **F** | No CI, no Makefile, no build script. Installed binary already stale. |
| Docs ↔ reality | **F** | Docs describe a substantially different, larger language. |

---

## 1. Bugs that SURVIVE the LLVM C API port

You mentioned you're replacing the text emitter with a real LLVM C API layer behind a thin C
shim. That's the right call, but be precise about what it buys you: these defects live in
**`ir.psm`'s lowering logic and in sema**, not in the text formatter. They will all still be
there afterwards.

Worse — **the port will make several of them harder to find.** Today they fail loudly as `llc`
text parse errors. Against the C API the same logic produces a `NULL` `LLVMValueRef`, an
assertion inside LLVM, or a silently invalid module. **Fix these before the port, not after.**

### 1.1 CRITICAL — String literals inside `for` / `loop` / `match` bodies are never emitted — **FIXED**

`src/ir.psm:1157-1194` — `collect_strings_stmt` handles `VARIABLE_DECL`, `EXPRESSION_STATEMENT`,
`RETURN_STATEMENT`, `ASSIGNMENT_STATEMENT`, `IF_STATEMENT`, `WHILE_STATEMENT`. It does **not**
handle `FOR_STATEMENT`, `LOOP_STATEMENT`, or `MATCH_STATEMENT`. Those bodies are never walked, so
no `@.str.N` global is created and `expr.s2` stays empty.

**CONFIRMED.** Both of these fail to build:

```prismio
fn main() -> Int {
    for i in 0..3 { println("hello from loop") }
    return 0
}
```

```
%t3 = getelementptr inbounds [16 x i8], ptr @, i64 0, i64 0
llc: error: expected value token
```

Same for any `match` arm containing a string. Two of your three loop forms plus all of pattern
matching are unusable with string literals — which is to say, unusable in most real code.

*After the port:* `expr.s2` is still empty, so you'll pass a null/garbage name into the API and
get a NULL deref or a bogus global. Strictly worse to debug.

**Fix:** add the three missing statement kinds. Better: replace the collect pre-pass with a
generic AST visitor so a new node kind can never silently skip it again. This class of bug —
"add a node kind, forget one of the four hand-written walkers" — will recur; `predeclare_locals_stmt`,
`collect_strings_stmt`, `sema_statement` and `generate_statement` are four parallel switches over
the same enum, and only one of them is complete.

### 1.2 CRITICAL — `and` / `or` do not short-circuit — **FIXED**

`src/ir.psm:488-490` generates both operands before dispatching the operator; `535-536` then emits
a plain `and`/`or` instruction. Both sides are always evaluated.

**CONFIRMED** — `false and boom(1)` and `true or boom(2)` both executed `boom`:

```
SIDE EFFECT RAN
SIDE EFFECT RAN
or-taken
```

This is a language-semantics bug, not an optimization gap. Every null/empty guard of the shape
`if (p != "" and deref(p))` is a latent crash.

**It already bites the compiler itself.** `src/sema.psm:394`:

```prismio
if (str_equals(arg_ptr, "") == 1 or str_equals(ptr_to_node(arg_ptr).next, "") == 0) {
```

When `arg_ptr` is empty the right operand still evaluates and dereferences it.

**CONFIRMED:** `print()` with no arguments **segfaults the compiler** (exit 139) instead of
reporting "print expects one argument". Same pattern at `sema.psm:404` and `sema.psm:457`.

**Fix:** lower `and`/`or` to branches with a phi (or a stack temp). Then fix the three sema call
sites, which are currently only safe by accident.

### 1.3 CRITICAL — No mutability enforcement whatsoever

`src/parser.psm:174-176` records `let mut` into `var_node.i1`. **Nothing ever reads it.**
`sema_statement`'s `VARIABLE_DECL` arm (`sema.psm:659-684`) ignores `i1`, and the
`ASSIGNMENT_STATEMENT` arm (`sema.psm:686-692`) only type-checks.

**CONFIRMED** — this compiles and runs, printing 6:

```prismio
fn main() -> Int {
    let x = 5
    x = 6            // no error
    println_int(x)
    return 0
}
```

README lists "explicit mutability (`let` / `let mut`)" as a language feature and design principle
#1 is "mutability, types, and allocation are always visible". Right now `mut` is a comment. There
is no negative test for it, which is why it went unnoticed.

### 1.4 CRITICAL — No block scoping; locals shadowing globals read the global

There is no scope stack anywhere. `ir_set_var_type` is one flat name→type list
(`llvm-bridge.c:920-957`), cleared once per function, never per block. `sema_block`
(`sema.psm:770-777`) pushes nothing.

**CONFIRMED (a) — bindings leak out of their block:**

```prismio
if (true) { let inner = 42 }
println_int(inner)      // prints 42; should be "unknown identifier"
```

**CONFIRMED (b) — a local shadowing a global silently reads the global:**

```prismio
let counter = 100
fn main() -> Int {
    let counter = 7
    println_int(counter)   // prints 100
    return 0
}
```

`generate_statement` stores `7` into the local slot `%counter`, but `generate_expression`
(`ir.psm:299-305`) sees `ir_is_global_name("counter")` is true and loads from `@counter`. Writes
and reads go to different places. Silent wrong answer, no diagnostic.

**CONFIRMED (c) — sibling-block shadowing at different types corrupts the stack:**

```prismio
if (true)  { let v: I8 = 1 ... }
else       { let v: String = "aaaa..." ... }
```

emits

```
%v = alloca i8          ; 1 byte — first declaration wins the slot
store i8 1, ptr %v
store ptr %t1, ptr %v   ; 8 bytes into a 1-byte slot
```

`ir_alloca` dedupes by name (`llvm-bridge.c:326-348`) and `predeclare_locals_block` hoists every
local in the function to entry, so both `v`s share one slot sized by whichever came first. This
is a genuine stack smash that `llc` accepts without complaint.

**Fix:** a real scope stack in sema, and unique per-scope mangled slot names in codegen. This is
the single largest structural gap and it blocks fixing several other items cleanly.

### 1.5 HIGH — Arrays only work for 32-bit integers

`src/ir.psm:405-411` always emits `alloca [N x i32]` for a non-nested array literal, and
`ir.psm:456-486` hardcodes `elem_type = "i32"` for indexing (only `ptrptr` is special-cased).
Sema, meanwhile, correctly types `arr[i]` as the real element type — so the two disagree.

**CONFIRMED** — `let a = ["alpha", "beta"]`:

```
llc: error: '%t2' defined with type 'ptr' but expected 'i32'
```

An array of `Float` or `I64` would hit the same path. Note that arrays are also `alloca`-based
(stack), so returning one from a function returns a dangling pointer — there is no escape
analysis. `test_16_arrays.psm` only uses `Int`, which is why this is green.

### 1.6 HIGH — Any missing return path emits an invalid or wrong value

`src/ir.psm:1009-1019`: if control reaches the end of a non-void function, it emits
`ir_ret(ret_sig_type, "0")`. There is no definite-return analysis in sema.

**CONFIRMED** — for a `-> String` function with one uncovered path:

```
ret ptr 0
llc: error: integer constant must have integer type
```

For an `Int` function it silently returns `0` instead of erroring at compile time. A serious
compiler rejects this at the frontend; here it's either a cryptic backend error or a wrong value.

### 1.7 HIGH — Statements after `return`/`break` produce invalid IR

`generate_block` (`ir.psm:861-868`) keeps emitting into a block that already has a terminator.
`break`/`continue` reuse the `has_returned` flag (`ir.psm:807-821`) for the same purpose.

**CONFIRMED:**

```
ret i32 0
%t1 = getelementptr ...    ; after the terminator
llc: error: expected instruction opcode
```

No unreachable-code diagnostic exists. Related: **`match` arms after a `_` wildcard are silently
discarded** — `ir.psm:823-858` runs the wildcard body in the current fall-through block and then
keeps emitting later arms after the terminator. A `_` placed first silently kills every arm below
it, with no warning. **CONFIRMED** (printed `99`, the wildcard, for input `2`).

### 1.8 HIGH — `drop` in a loop is a double free the checker doesn't see

Move state is per-name and flow-insensitive (`sema.psm:205-214`), and the comment at
`sema.psm:696-705` documents the tradeoff honestly. But the consequence isn't only false
positives:

```prismio
let b = Box { v: 1 }
while (i < 3) { drop(b); i = i + 1 }
```

**CONFIRMED:** compiles clean, crashes at runtime (exit 127). The textual `drop(b)` appears once,
so the move checker never sees a second use — but it executes three times. Moving out of a
struct field or array element is also untracked, since `sema_move_operand` only handles
`IDENTIFIER_EXPR`.

This is the soundness hole in the headline feature. Fixing it needs the move check to run over a
CFG rather than over the AST in source order.

### 1.9 MEDIUM — `==` on `String` compares pointers, silently

`sema.psm:539-543` accepts `String == String` and returns `Bool`; `ir.psm:515` lowers it to
`icmp eq` on two `ptr`s.

**CONFIRMED:** two separately built strings both spelling `"hello"` compare as **NOT EQUAL**.
No warning. This is why the whole compiler is written with `str_equals(a, b) == 1` — the idiom
exists because the natural spelling is quietly wrong. Same applies to struct `==` (pointer
identity).

**Fix:** either reject `==` on `String`/struct in sema, or lower it to `str_equals`.

### 1.10 MEDIUM — `%` is rejected on every sized integer type — **FIXED**

`sema.psm:532-537` hardcodes `type_int()` for both operands of `%`, while `+ - * /` correctly use
the left operand's type.

**CONFIRMED:** `let a: U64 = 100; let b = a % 7` → `type error: modulo left operand: expected Int,
got U64`. Codegen already handles this properly (`ir_urem`/`ir_srem` at `ir.psm:531-534`) — it's
a one-line sema bug gating working codegen.

### 1.11 MEDIUM — Global initializers are dropped unless they're literals — **FIXED**

`ir.psm:1341-1348` only propagates an initializer when the node is a `LITERAL_EXPR`; anything else
silently becomes `0`. And for a string literal it emits the raw text as the initializer:

**CONFIRMED:** `let greeting = "hello global"` produces

```
@greeting =  global ptr hello global
llc: error: expected value token
```

So global strings are broken, and `let g = compute()` at global scope silently initializes to
zero with the call never emitted.

### 1.12 LOW — `print_bool` is declared `i32` and called with `i1` — **FIXED**

`ir.psm:1305-1311` declares `void @print_bool(i32)`; the call site passes the `Bool` as `i1`.
**CONFIRMED** in generated IR. LLVM tolerated it here, but it's an ABI mismatch against the C
`print_bool(int)` — the upper bits are undefined. Works by luck on x86-64.

---

## 2. Issues in the current text emitter (moot after the LLVM C API port)

Listing these only so they aren't accidentally *re-implemented* in the new shim. The registries
in the middle of this file are **not** emitter code — they're your symbol table, and they need a
home after the port.

- **Fixed buffers, silently truncating.** `append_to_buffer` (`llvm-bridge.c:54-60`) drops output
  when full — 8 MB module, 2 MB per function — with no error. Silent truncation is the worst
  possible failure mode.
- **`ir_call_arg` (`llvm-bridge.c:272-278`) `strcat`s into a 1 KB static with no bounds check.**
  Unbounded overflow with enough arguments.
- **`ir_get_temp_name` (`:771`) mallocs 64 bytes per call and never frees.** Called once per SSA
  value; steady leak across a compile.
- **Nested-call stack asymmetry** (`:262-290`): `ir_call_begin` refuses to push past depth 64 but
  `ir_call_end` always pops — mismatched beyond depth 64.
- **No escape processing for string literals** (`lexer.psm:112-127`): `"a\nb"` keeps a literal
  backslash-n. `ir_global_string` then escapes the backslash so it survives to the output. There
  is currently **no way to put a newline, tab, or `"` inside a string literal** — only `println`
  gives you a newline. Char literals *do* decode escapes (`lexer.psm:134-144`), so the two are
  inconsistent. **This one is a lexer bug, not an emitter bug — it survives the port.**

**Carry these over deliberately** (they're compiler data structures living in the wrong file):

| Registry | Limit | Failure mode |
|---|---|---|
| `sm_alloca_names` | 512/function, 63-char names | silently stops deduping → duplicate allocas |
| struct registry | 128 structs, 32 fields, 63-char | fields past 32 silently dropped; index −1 emitted |
| enum variants | 512 | silently dropped |
| `var_types` | 4096 entries, 63-char keys | silently stops recording |

The 63-char truncation is the sharp one: mangled overload symbols like
`sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String` exceed it, so two
overloads sharing a long prefix would collide in the return-type table while emitting distinct
LLVM symbols. Use real hash maps in the new layer.

---

## 3. Missing language features (present in docs, absent in the compiler)

Confirmed absent by reading `parse_declaration` / `parse_primary` / `parse_type_annotation`:

| Feature | Status | Notes |
|---|---|---|
| **Unary operators** (`-x`, `!x`) | **Absent** | `parse_primary` has no unary case. **CONFIRMED:** `let x = -5` → `Unexpected token in expression: OPERATOR '-'`. There is no way to write a negative literal. `UNARY_EXPR` and `ir_neg` exist but are unreachable. |
| `trait` / `impl` | **Absent** | Keywords lex, `TRAIT_DECL`/`IMPL_DECL` node kinds exist, `parse_declaration` handles neither → "Unknown declaration". No methods, no interfaces. |
| Closures / lambdas | **Absent** | No syntax, no function types. `docs/language/functions/closures.md` is entirely aspirational. |
| Generics | **Absent** | Only a hardcoded `List<T>` special case (`parser.psm:161`, matched by the literal string `"List"`). No user generics. |
| Enum payloads / ADTs | **Absent** | `parse_enum_decl` reads bare variant names only. No `Option`, no `Result` — `docs/guides/error_handling.md` documents `Result<T,E>` in detail. |
| Pattern matching | **Minimal** | Arms are `expr => block` or `_`. No destructuring, bindings, guards, or-patterns, ranges. It's a switch. |
| Type casts | **Absent** | No `as`, no cast builtin. Sized integer types exist but cannot interoperate — you can declare `I64` and `U8` but not convert between them. |
| `pub` / visibility | **Absent** | Not a keyword. Everything is global. `docs/reference/keywords.md` lists `pub`. |
| Module paths / namespaces | **Absent** | `import x` takes one identifier resolved to a sibling `.psm`. No `import a.b.c`, no aliasing, no selective import. Docs show `import prismio.net.AsycnLoader`. |
| Compound assignment, bitwise ops | **Absent** | No `+=`, `&`, `\|`, `^`, `<<`, `>>`, `~`. |
| Hex/binary/octal, numeric underscores, exponents, literal suffixes | **Absent** | `docs/language/types.md` shows `9_000_000_000`; the lexer stops at `_` and lexes the rest as an identifier. |
| Block comments `/* */` | **Absent** | `//` only. |
| String interpolation | **Absent** | Docs show `"Hello, ${name}!"`. |
| Standard library | **Absent** | `dist/stdlib/` contains only a README. `print`/`println` are compiler builtins, not `std.io`. Docs mark `std.io`, `std.core`, `std.string`, `std.math` as "✅ Available". |
| Automatic drop at scope exit | **Present, partial** | AIF Levels 2 and 4: structs, strings and lists are move-only and dropped at all four scope exits in reverse construction order. A value is dropped only where it is *bound to a name* — a temporary written inline as an argument has no owner and no free point — and arrays are frame storage, so `docs/language/memory/ownership.md`'s "no memory leaks — all enforced at compile time" is still stronger than the model delivers. |
| Debug info (DWARF/PDB) | **Absent** | No `-g`, no line tables. Compiled programs cannot be source-debugged. |
| Optimization levels | **Absent** | No `-O` flag; no LLVM pass pipeline is run. |

---

## 4. Diagnostics — the weakest area against the benchmark

Tokens carry a `line` (`token.psm:30-35`) but **no column and no file identity**, and even the
line is never used in an error message.

**CONFIRMED** — a type error on line 4 of a 5-line file reports:

```
type error: operator +: expected Int, got String
```

No file, no line, no column, no source snippet, no error code, no note, no suggestion. Then
`exit(1)` — **one diagnostic per run, always**. `parser_expect` (`parser.psm:62-68`) is worse: it
prints the expected token type as a raw integer.

Compounding it: `resolve_imports` flattens every module into one AST, and since tokens have no
file identity, a line number would be ambiguous even if it were printed. Fixing diagnostics
properly means adding a `(file, line, col, len)` span to tokens and threading it through the AST
first.

Also: `compile_source` (`main.psm:276`) deletes the temporary `.ll` on build failure, so when the
backend does reject the IR you can't inspect what was generated. Keep it on failure, or add
`--emit-ir`.

---

## 5. Performance — quadratic and already measurable

`str_char_at` (`lang_runtime.c:319-327`) calls `strlen` on every access, and the lexer calls it
per character (`lexer.psm:22-28`). Lexing is therefore **O(n²) in file size**. Sema compounds it:
every identifier and call does a linear scan of the whole module (`sema_has_struct`,
`sema_find_function_overload`, `ir_get_var_type`), and `append_statement` walks the merged list
tail on every import merge.

**Measured** (single function, N `let` bindings):

| Source size | Compile time |
|---|---|
| 9.8 KB | 128 ms |
| 19.8 KB | 189 ms |
| 41.8 KB | 390 ms |
| 85.8 KB | 1325 ms |

Netting out ~100 ms of fixed startup: 2.05× the input costs 4.2× the time. That is textbook
quadratic. The full 155 KB self-compile takes ~1.0 s today, so it isn't hurting you yet — but at
1 MB of source it would be minutes. Fix `str_char_at` (pass length, or intern the source as a
counted buffer) and add hash maps for the symbol tables; both are localized changes.

---

## 6. Overload resolution has a speculative-execution hazard

`sema_find_function_overload` (`sema.psm:278-321`) tests candidates by calling
`sema_signature_matches_call` → `sema_arg_matches_type` → **`sema_expr` on the argument**. But
`sema_expr` isn't a pure query — it can call `sema_error`, which calls `exit(1)`.

So while *probing* one candidate, an argument that is itself an unresolvable call aborts the
entire compilation rather than just rejecting that candidate. It also mutates state: it caches
types onto nodes and assigns `expr.s2`. Any future work on overloading (or on better errors) will
trip over this. Resolution needs a non-fatal type query that returns `Invalid` instead of exiting.

---

## 7. Testing, CI, and packaging

- **The test oracle is exit code only.** `test_runner.py:78-83` runs the binary and checks
  `returncode != 0`. Nothing compares stdout to an expected value. A test that prints garbage but
  exits 0 passes. Every `test_*.psm` self-reports `PASS: ...`, so the suite is really 30
  hand-written self-checks whose assertions live inside the test programs.
- **No expected-output files, no golden IR tests, no `llc`-verify step, no fuzzing, no
  multi-error tests, no parser-error tests.** A `--verify-ir` step alone would have caught items
  1.1, 1.5, 1.6, 1.7 and 1.11 automatically.
- **Negative tests string-match `"type error:"`** — a wording change silently disarms them, and
  they can't distinguish *which* error fired.
- **No CI.** No `.github/`, no workflow files anywhere in the repo.
- **No build script for the compiler.** No Makefile, no CMakeLists, no `build.sh` — only paired
  `tools/*.ps1` and `tools/*.sh` that duplicate the same logic in two languages and can drift.
- **Installed-toolchain drift is unguarded.** During this audit the installed
  `C:\Program Files\Prismio\prismio.exe` predated `for`/`match` support and failed to parse them
  at all, so the default `python test_runner.py` (which resolves via `which("prismio")`) was
  silently exercising a months-old binary. *Resolved 2026-07-30 — the install was refreshed and
  all 36 tests now pass against it via the default path.* The durable point stands: nothing
  detects this. There is no CI, no install step tied to a successful bootstrap, and no version or
  build-hash check between the compiler binary and the source tree it is being tested against.
  The `$PRISMIO` override in `test_runner.py:20-26` anticipates the problem but isn't the default,
  so the failure mode is silent-and-green rather than loud. Worth adding a `prismio --version`
  carrying the source hash (the runtime already has `compiler_runtime_source_hash()` — the same
  idea applied to the compiler itself).
- `runtime/lang_runtime.c` is `#ifdef PRISMIO_WASM` / `#else` with **~390 lines duplicated nearly
  verbatim** between the two branches. A fix applied to one branch silently misses the other.

---

## 8. Docs vs. reality

The docs site is 94 pages describing a substantially larger and different language. It is written
in a Kotlin-derived idiom (```kotlin fences, `fun`, `val`) and reads as adapted from Kotlin's
documentation rather than from this compiler.

The `stdlib/` and `spec/` pages honestly mark unfinished work with 🚧 — that part is well done.
The problem is the **`language/` and `reference/` pages, which carry no such markers** and
document unary operators, closures, `pub`, `Result<T,E>`, generics, string interpolation, numeric
underscores, dotted imports, and automatic scope-based drop as if they exist today.

Two specific corrections worth making first, because they mislead about *design* and not just
status:

1. `language/memory/ownership.md` states there are no manual frees and no leaks, enforced at
   compile time. The reality is the opposite: `drop()` is manual, and everything that isn't a
   struct leaks unconditionally.
2. `toolchain/compiler.md` says source files are `.prism`; they're `.psm`.

Also stale in-repo: `STATUS.md` predates `bootstrap` mode, the runtime-hash guard, and the
`ums/` removal, and it describes `runtime/driver.c` which is now `build_driver.c` +
`program_support.c`. `README.MD`'s pipeline diagram is accurate.

---

## 9. Recommended order of work

**Before the LLVM C API port** — these are cheap now and expensive later:

1. **1.1** `collect_strings_stmt` — add `FOR`/`LOOP`/`MATCH`. One-line-ish; unblocks the two most
   broken features. Then refactor the four parallel AST walkers into one visitor.
2. **1.2** Short-circuit `and`/`or`, then fix the three `sema.psm` sites that assume it.
3. **1.6 / 1.7** Definite-return analysis and unreachable-code rejection in sema. These two turn
   "invalid IR from the backend" into real frontend errors — and against the C API they'd become
   LLVM assertions instead.
4. **1.10** Two-line fix for `%` on sized ints.

**The structural one** (do it next; several others depend on it):

5. **1.4** A real scope stack in sema + per-scope unique slot names in codegen. Fixes the leak,
   the global-shadow miscompile, and the stack smash together.

**Then:**

6. **1.3** Enforce `mut` — and add the negative test that should have caught it.
7. **1.5** Type-directed array element lowering.
8. **1.9 / 1.11** String `==`, global initializers.
9. **1.8** Move the ownership check onto a CFG so loops are handled. This is the real fix for the
   headline feature.
10. Spans on tokens → real diagnostics with file/line/col, and error recovery so more than one
    error is reported per run.
11. Test suite: expected-output files, an IR verification step, and CI running the full bootstrap
    to fixpoint on every push.
12. Reconcile the docs — or add 🚧 markers to the `language/` and `reference/` pages the way
    `stdlib/` already does.

**On the port itself:** keep the registries (structs, enums, globals, var types) as real hash maps
in the new shim rather than reproducing the fixed 63-char arrays, and run
`LLVMVerifyModule` on every build. That check alone replaces the accidental safety net that
`llc`'s text parser is currently providing.
