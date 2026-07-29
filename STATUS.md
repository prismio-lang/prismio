# Prismio — Compiler Status

Working audit of what's actually built vs. what's missing/fragile, based on reading the source
directly (not just the docs). Generated 2026-07-29. Update this file as things change — it will
drift like every other doc here if it isn't kept honest.

## Verified build pipeline

```
main.psm source (.psm)
     │
     ▼
  Lexer (src/lexer.psm)              → token stream
     ▼
  Parser (src/parser.psm)            → untyped AST
     ▼
  Import Resolver (src/main.psm)     → flattens transitive imports into one module AST
     ▼
  Semantic Analysis (src/sema.psm)   → analyze_module(), 819 lines, type checking + move/borrow/drop
     ▼
  IR Generator (src/ir.psm)          → walks AST, emits LLVM IR text, delegates codegen to
     │                                 llvm-bridge.c via extern fn (src/bridge.psm)
     ▼
  llc                                → object file
     ▼
  clang                              → links program.obj + lang_runtime.obj + driver.obj +
     │                                 bridge.obj → native binary
     ▼
  Native executable
```

This matches README's diagram with one correction: **semantic analysis is real and runs on every
build**, contrary to what README/CONTRIBUTING currently claim (see Doc/Code Mismatches below).

### Runtime embedding (the part you asked about)

`compiler_build_executable()` in `runtime/driver.c` (L440) does not require `runtime/*.c` to sit
next to the compiler. The three runtime C files are embedded as C string literals inside
`runtime/embedded_sources.h` (2612 lines, generated) and get unpacked to a temp dir, compiled, and
linked on every build, then deleted.

**This only works if `embedded_sources.h` is in sync with the actual runtime C files**, and that
sync is 100% manual:

- `runtime/generate_embedded_sources.ps1` regenerates the header from `lang_runtime.c`, `driver.c`,
  `llvm-bridge.c`.
- Nothing calls it automatically — no Makefile, no CI (there is no CI config in this repo at all),
  no pre-commit hook, no mention in README or CONTRIBUTING.
- If you edit any runtime `.c` file and don't run the regen script **and** rebuild `prismio.exe`
  itself, the compiler keeps silently embedding the old runtime. No warning, no version check.

**Recommendation**: either wire the regen script into whatever builds `prismio.exe` (so it can't go
stale), or add a checksum/timestamp guard that fails the build if `embedded_sources.h` predates the
`.c` files it's derived from. Not done yet — still open, see below.

If the embedded path isn't compiled in, it falls back to `copy_toolchain_source_path()`, which
searches `../runtime/`, `./runtime/`, etc. relative to the compiler executable — so a "portable"
`prismio.exe` still silently depends on being run from a predictable relative location in that
fallback case.

## Cross-platform audit (macOS support)

Triggered by: compiling `main.psm` to `main.ll`, converting to a native binary by hand on macOS,
and the resulting binary couldn't read any CLI arguments. Root-caused and fixed — three real bugs,
all verified with an actual `clang`-built end-to-end binary on this machine (no `llc` available
here, but `clang` compiles `.ll` directly, which was enough to validate the fix).

1. **CLI args never reached compiled programs on non-Windows — this was the reported bug.**
   `cli_arg_count()`/`cli_arg()` in `runtime/driver.c` returned `0`/`""` unconditionally outside
   `#ifdef _WIN32`. Deeper cause: the IR generator emits `main` as `define i32 @main()` — zero
   parameters — because Prismio's `fn main() -> Int` never declares any. On Windows this
   accidentally worked anyway because `__argc`/`__argv` are CRT globals populated before `main`
   runs, independent of `main`'s own signature — a Windows-only quirk with no POSIX equivalent.
   **Fix**: `generate_function()` in `src/ir.psm` now emits `main` as the real C ABI entry point —
   `define i32 @main(i32 %p_argc, ptr %p_argv)` — and stores those into two new globals
   (`prismio_argc`/`prismio_argv`) in the prologue. `cli_arg_count()`/`cli_arg()` in `driver.c` now
   read those globals directly, unconditionally, on every platform. This is strictly more portable
   than the old Windows path, not just a macOS patch.

2. **`src/main.psm`'s `join_import_path()` hardcoded `\\`** when joining a non-`.` base directory
   with an imported module name. Silently broken on macOS/Linux for any compile invoked from
   outside the source directory (`prismio build somedir/main.psm` from elsewhere) — the import
   resolver would look for a literal file named `dir\module.psm`, which doesn't exist on a
   filesystem that treats `\` as a normal character. **Fix**: now calls the existing, already-correct
   `join_path()` extern (`driver.c`, uses `PRISMIO_PATH_SEP` per platform) instead of hand-rolling
   the separator.

3. **`compiler_executable_directory()` used Linux's `/proc/self/exe`** in the catch-all `#else`
   branch. macOS has no procfs — this always failed silently on Mac, so any self-relative
   `runtime/` lookup (the embedded-sources fallback path) degraded to a fragile cwd-relative
   search. **Fix**: added a real `#elif defined(__APPLE__)` branch using `_NSGetExecutablePath` +
   `realpath`, verified against the actual compiled binary's path.

4. **`generate_embedded_sources.ps1` is PowerShell-only** — no way to regenerate
   `embedded_sources.h` from macOS/Linux at all without installing PowerShell, which is likely why
   you were bypassing the embedded-build path entirely. **Fix**: added
   `runtime/generate_embedded_sources.py`, a byte-for-byte equivalent that runs anywhere Python 3
   runs. While writing it I also found and fixed two real bugs in the original `.ps1` (both now
   fixed there too, so Windows users get correct output as well):
   - `Get-Content -Raw` decodes the file with the system codepage, silently corrupting any
     non-ASCII byte in the source (e.g. an em-dash in a comment became three garbled characters).
   - Non-printable/non-ASCII characters were escaped with **decimal** codes (`'\{0:D3}' -f $code`)
     into a C string, but C's `\nnn` escape is **octal** — every such byte was silently wrong.
     `embedded_sources.h` had 2 real instances of this before the fix (confirmed via
     `clang -fsyntax-only`, which warned on `\8364`/`\8221` — not valid octal). Only affected
     comment text in the embedded copy, so it was cosmetic, not a runtime bug — but it would have
     corrupted real string data had any existed with non-ASCII content.

   `embedded_sources.h` has been regenerated with the corrected script and now reflects all of the
   above `driver.c` fixes.

**Not yet done — needs a real toolchain to complete**: none of this has been validated by actually
bootstrapping a new native `prismio.exe` from the fixed `.psm` source, because that requires `llc`
(not installed in this environment) and an existing trusted `prismio` binary to compile the fixed
`main.psm`/`ir.psm`/`bridge.psm`/`sema.psm` with (the checked-in `prismio.exe` files are Windows
binaries, unusable here). **Next step on your end**: rebuild `prismio.exe` from this source with
your existing toolchain, then re-run your `.ll` → native conversion — `cli_arg`/`cli_arg_count`
should now report real arguments.

## What's built

| Area | File(s) | Size | Status |
|---|---|---|---|
| Lexer | `src/lexer.psm` | — | Complete — full token stream incl. string/char/number/float literals |
| Parser | `src/parser.psm` | 43 fns | Complete — structs, enums, if/while/loop/for/match/break/continue, sink/inout param conventions, operator precedence |
| AST | `src/ast.psm` | 3 fns | Flat, pointer-punned node representation |
| Semantic analysis | `src/sema.psm` | 819 lines / 36 fns | Real type checker + move/borrow/drop enforcement — **actively wired in, despite docs claiming otherwise** |
| Type system | `src/types.psm` | 39 fns | Int widths (I8/16/32/64, U8/16/32/64), Isize/Usize, Float, Bool, String, Char, structs, enums |
| IR generation | `src/ir.psm` | 1364 lines / 35 fns | Full AST→LLVM-IR walk, delegates emission to C |
| IR/LLVM bridge | `src/bridge.psm` + `runtime/llvm-bridge.c` | 104 extern decls | Large surface — arithmetic, comparisons, control flow, struct/enum ops, ownership tracking (`ir_mark_moved`/`ir_is_borrowed`) |
| Runtime | `runtime/lang_runtime.c` | — | Arrays, strings, lists, malloc/free wrappers, WASM host-import variants behind `#ifdef PRISMIO_WASM` |
| Driver/build orchestration | `runtime/driver.c` | 621 lines | Path resolution, temp file management, embedded-source unpacking, clang/llc invocation |
| Ownership model | sema.psm + bridge.psm + ir.psm | — | Move-only structs, `sink`/`inout` params, drop tracking — has **6 dedicated negative tests** enforcing it at compile time |
| WASM target | `src/ir.psm` (`ir_set_target_wasm`) | — | Minimal: only switches pointer-int width (`i32` vs `i64`); `lang_runtime.c` has WASM-specific host imports behind `#ifdef PRISMIO_WASM` — narrow but real, not a stub |
| Test suite | `tests/*.psm` + `test_runner.py` | 29 positive + 6 negative | Compiles each `.psm` to a binary, runs it, checks exit code; negative tests assert compilation fails with `"type error:"` in output |

> **Note:** the `ums/` build-orchestration tool (previously documented here) was removed from the
> working tree during this session — not by this cleanup pass. `git status` shows its three files
> staged for deletion. If that wasn't intentional, `git checkout -- ums/` before it's committed
> will bring it back; otherwise this doc and `CONTRIBUTING.md`'s project structure no longer
> reference it.

## What's left / known issues

**Resolved in this cleanup pass:**

- ~~Dead duplicate parser code~~ — `src/parser_decls.psm` and `src/parser_expr.psm` deleted
  (unused, unreachable from `main.psm`, and behind the real `parser.psm` anyway).
- ~~Stale documentation claims~~ — README.MD and CONTRIBUTING.md now correctly describe
  `sema.psm` as implemented and wired in; the "edit line 18" instruction is replaced with the
  actual mechanism (`PATH` lookup via `find_prismio_exe()`).
- ~~Legacy C++ residue~~ — the stale "must match the C++ NodeType enum" / "Keywords from
  keywords.cpp" comments in `src/ast.psm` / `src/keywords.psm` are removed (no `.cpp` files exist
  anywhere in this repo).
- ~~`src/test.psm` scratch file~~ — deleted (unreferenced one-line smoke test, not part of the
  real test suite in `tests/`).
- CONTRIBUTING.md's project structure diagram updated to match reality (`sema.psm`/`types.psm`
  added, dead parser files and the now-removed `ums/` dropped).

**Resolved in the cross-platform audit pass:**

- ~~CLI args broken on non-Windows~~ — `main` now takes real argc/argv (see above).
- ~~Import path separator hardcoded to `\\`~~ — uses `join_path()` (correct per-platform separator).
- ~~macOS executable self-path resolution~~ — added `_NSGetExecutablePath` branch.
- ~~No way to regenerate `embedded_sources.h` off Windows~~ — added
  `runtime/generate_embedded_sources.py`; also fixed two correctness bugs in the original `.ps1`.

**Still open:**

1. **`embedded_sources.h` staleness risk (partially addressed)** — regeneration is no longer
   Windows-only, and `embedded_sources.h` was just regenerated with the fixes above. But nothing
   still *automatically* calls the regen script or rebuilds `prismio.exe` — that part of the
   recommendation (wire it into a build step, or add a staleness check) remains open.

2. **No CI, no build script for the compiler itself** — README says "a prebuilt bootstrap binary
   is used to compile them during toolchain setup" but there's no Makefile/build.sh/CMakeLists
   checked in, and no `.github/workflows`. The self-hosting bootstrap process (how you get from a
   fresh checkout to a working `prismio.exe`) isn't reproducible from what's in the repo. This is
   also why the cross-platform fixes above couldn't be validated by an actual `prismio.exe`
   rebuild in this session — no `llc` here, and the checked-in `prismio.exe` binaries are
   Windows-only.

3. **`POST_INSTALL.txt` and README point to `docs.prismio.org` / `github.com/prismio-lang/prismio`**
   — confirm these are real before shipping, otherwise they're broken links for anyone who
   installs this.

4. **Negative-test assertions are string-matched** — `test_runner.py` checks for the literal
   substring `"type error:"` in stderr/stdout rather than a structured error code, so any wording
   change in `sema.psm`'s error messages silently breaks test detection without a compiler bug.

5. **`compiler_default_exe_path()` no longer forces `.exe` on non-Windows** (fixed in this pass) —
   worth noting since it changes the default output filename on macOS/Linux from `foo.exe` to
   `foo`. Not a bug, but a behavior change if anything downstream assumed the `.exe` suffix.

## Test coverage snapshot

- **Positive**: variables, if/else, while, structs, enums, recursion, booleans, mutability,
  strings, expressions/precedence, returns, imports, globals, multi-arg calls, compiler-pipeline
  simulation, arrays, string runtime FFI, floats, driver/runtime split, integers, loops, match,
  move, drop, param conventions (sink/inout), borrow-reuse, for-loops, generic `List<T>`, function
  overloading.
- **Negative** (must fail to compile): type mismatch, integer width mismatch, use-after-move,
  use-after-drop, drop-of-borrowed-value, duplicate function overload.
- **Not covered by any test file found**: the embedded-sources build path itself (no test exercises
  `compiler_build_executable` end-to-end with a stale-vs-fresh header), WASM target output.

## How this was produced

Built from a `graphify` knowledge-graph pass over the repo (`graphify-out/GRAPH_REPORT.md` has the
full node/edge/community breakdown) plus direct source verification of every claim above — the
graph flags candidates (doc/code mismatches, dead-code hyperedges), but line numbers and behavior
here were confirmed by reading the actual files, not inferred from the graph alone.
