# Handoff — continuing the Prismio v1 work

Read `COMPILER_AUDIT.md` (defects, with remediation status) and `V1_GAP_ANALYSIS.md` (capability
inventory against the v1 bar) before starting. They are current as of 2026-07-31. Don't re-derive
what's in them.

---

## Current state

- Backend is the **LLVM C API** (`runtime/llvm-api-backend.c`). The old text emitter
  (`llvm-bridge.c`) is deleted. `ir_append()` survives only as a loud failure guarding against raw
  text creeping back in.
- Compiler **self-hosts to a fixed point**, test suite is **45/45**, seed is current.
- Pinned to **LLVM 22.x**, enforced at build time (`tools/setup_llvm.py`) and at runtime
  (`LLVMGetVersion` check in the backend). Bump both `PRISMIO_LLVM_EXPECTED_MAJOR`
  (`runtime/prismio_llvm.h`) and `REQUIRED_MAJOR` (`tools/setup_llvm.py`) together.

### File roles

| File | Role |
|---|---|
| `src/lexer.psm` | tokens, string/char escapes |
| `src/parser.psm` | precedence, casts, compound assignment desugaring |
| `src/sema.psm` | type checking, ownership, scoping |
| `src/types.psm` | TypeInfo, width/signedness helpers |
| `src/ir.psm` | AST → backend calls. **Emits no IR text** |
| `src/bridge.psm` | the backend FFI surface |
| `runtime/ir_symbols.c` | scoped symbol table, move/borrow state, loop targets |
| `runtime/llvm-api-backend.c` | the backend |
| `runtime/prismio_llvm.h` | LLVM C API decls; real headers via `-DPRISMIO_LLVM_REAL_HEADERS` |

---

## Workflow — do this for every change

```powershell
.\tools\bootstrap.ps1 -Compiler build\<lastgood>.exe -Out build\next.exe
.\tools\bootstrap.ps1 -Compiler build\next.exe -Out build\next2.exe
.\build\next.exe  build src\main.psm -o build\a.ll
.\build\next2.exe build src\main.psm -o build\b.ll
# a.ll and b.ll must be identical -> fixpoint
```

```bash
cd tests && PRISMIO=../build/next2.exe python test_runner.py   # must stay 45/45
```

Then, only for a language or codegen change that the seed must carry:
`.\tools\refresh_seed.ps1 -Compiler build\next2.exe` (it enforces determinism itself).

### Four rules learned the hard way

1. **Keep known-good generations.** A broken compiler can be unable to build the fix to its own
   bug — this happened: `scope1.exe` mishandled a global and so couldn't compile the correction.
   Recovery was to build from the previous good generation. Never overwrite your only good binary.
2. **Two generations before judging.** A change to code the compiler uses *to compile itself* only
   takes effect in the generation after next. Gen N has the new source; gen N+1 is the first built
   *by* it. Both short-circuit and `char_code` needed this.
3. **The suite is a floor, not proof.** It was 36/36 green while `for` + a string literal was
   completely broken. Add a regression test with every fix.
4. **Write test files with the Write tool**, not shell heredocs — the shell mangles backslashes,
   and PowerShell's `-Encoding utf8` writes a BOM the lexer does not skip.

---

## Remaining work, in recommended order

### A. Contained — good for a mid-tier model with this doc in context

**A1–A4 are DONE (2026-07-31).** `String ==` is rejected with a message naming `str_equals`;
arrays work for every element type (`tests/test_39_typed_arrays.psm`); the lexer skips a UTF-8 BOM;
`--help`/`--version` exist, with `--version` reporting the LLVM actually loaded.

Known limitation left behind by A2, worth fixing when convenient: an array literal does not take
its element type from an annotation, so `let x: [I64] = [1, 2]` is rejected because bare integer
literals default to `Int`. The fix is to propagate an expected element type into
`ARRAY_LITERAL_EXPR` in sema, the same way `sema_check_value` already coerces a bare literal.

**A5. Symbol tables are linear arrays with 63-char name truncation** (`runtime/ir_symbols.c`).
Mangled overload symbols already exceed 63 characters, so two overloads sharing a long prefix
would collide. Replace with hash maps keyed on the full name. Contained, mechanical, removes a
latent silent-wrong-answer.

### B. Wide but mechanical — needs care, not deep design

**B1. Enforce `mut`** (audit §1.3). Sema currently ignores `VARIABLE_DECL.i1`, so `let x = 5; x = 6`
compiles. The sema change is small (record mutability per binding in `ir_symbols.c`, reject
assignment to an immutable one). **The work is the migration**: the compiler's own source uses
plain `let` with mutation throughout, so enforcement breaks the whole tree until every mutated
binding becomes `let mut`. Land it in one pass. Expect to fix a few dozen sites in `src/*.psm`.
Add a negative test.

**B2. Source spans and real diagnostics.** Tokens carry only a line number, and it is never
printed. There is no column, no file, no snippet, and the first error calls `exit(1)`. Add
`(file, line, col, len)` to `Token`, thread it through the AST, and report `file:line:col` with the
source line. Then add error recovery so more than one error is reported per run. Wide (touches
lexer/parser/ast/sema) but the design is well understood. Note: `resolve_imports` flattens all
modules into one AST, so file identity has to be carried per node — that's the part to get right.

### C. Real compiler engineering — use the strongest model

**C1. Build a CFG, then the analyses that need one.** These four are all blocked on it and should
be done together, not piecemeal:
- definite return (audit §1.6) — a missing return path silently emits `ret <t> 0`, or invalid IR
  for pointer returns;
- unreachable/dead code (§1.7) — statements after `return` produce instructions past a terminator,
  and `match` arms after a `_` are silently discarded;
- definite assignment;
- **loop-aware move checking** (§1.8) — `drop(x)` inside a loop is an uncaught double free that
  crashes at runtime. Move state is currently per-name and flow-insensitive, and
  `sema_move_operand` only handles bare identifiers, so moving out of a struct field or array
  element is untracked entirely.

This is the largest remaining correctness item and the one that most needs judgement about where
the analysis lives and what the IR between sema and codegen should be.

**C2. Optimization and debug info.** Now cheap to reach through the C API and both entirely
absent: no `-O` (no pass pipeline is ever run) and no `-g` (nothing you compile can be
source-debugged). `-O` is mostly plumbing; `-g` needs real DWARF design work.

**C3. Post-v1, needs language design:** tagged unions → `Option`/`Result` → an error-handling
story; real generics; methods/`impl`; slices; `defer` or scope-based drop. Note that today only
structs are move-only — `String`, arrays and lists are **never freed**.

---

## Also worth knowing

- Compile time is **quadratic** in source size (`str_char_at` does `strlen` per character;
  sema does linear module scans per identifier). ~1s for the 155 KB compiler today; a wall at 1 MB.
- There is **no CI** and no build script other than `tools/bootstrap.*`. A workflow that runs the
  bootstrap to a fixpoint plus the suite would have caught several of this session's regressions
  immediately.
- `tools/*.ps1` and `tools/*.sh` are hand-maintained pairs that must be edited in lockstep with
  nothing enforcing it. `tools/setup_llvm.py` is deliberately one Python file for this reason.
- The docs site (`../docs`) still describes a substantially larger language — closures, generics,
  `Result<T,E>`, `pub`, automatic scope-based drop. `V1_GAP_ANALYSIS.md` §3 has the list.
