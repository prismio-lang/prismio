# Prismio Toolchain Architecture Refactor — Session Handoff

**Read this note first:** this session did the audit and design work for a large toolchain
refactor, but stopped short of implementing it because this machine (macOS) has no `llc`, no
`pwsh`, and no working `prismio` binary — none of the actual bootstrap/self-hosting changes below
can be compile-tested here. The user is switching to Windows (where a real toolchain exists) to
implement and iterate. This document is the full context needed to resume there with a fresh
Claude Code session, with no information lost.

**Once you (the next session) have this context loaded: read `STATUS.md` and `BOOTSTRAP_AUDIT.md`
in the repo root first** — they contain a prior general codebase audit and a detailed bootstrap/
runtime-linking audit respectively, both already validated against the actual source. This document
is the third layer: the confirmed refactor design built on top of those two, ready to implement.

---

## What's already been done in this repo (do not redo)

A prior turn in this session fixed a real cross-platform bug (compiled programs couldn't read CLI
args on macOS/Linux) and audited the runtime-embedding architecture. These changes are **already
applied** to the working tree:

- `src/ir.psm` — `generate_module()` now declares `prismio_argc`/`prismio_argv` globals (~L1246-1247);
  `generate_function()` special-cases `is_main` to emit real C-ABI `main(i32 %p_argc, ptr %p_argv)`
  and store into those globals (~L964-967, ~L982-985).
- `src/main.psm` — added `extern fn join_path` (L12); `join_import_path()` (L100) now uses it
  instead of a hardcoded `\\` separator.
- `runtime/driver.c` — `cli_arg_count()`/`cli_arg()` now read `prismio_argc`/`prismio_argv`
  unconditionally on every platform (no more `#ifdef _WIN32` stub); `compiler_executable_directory()`
  got a real `#elif defined(__APPLE__)` branch using `_NSGetExecutablePath` + `realpath`;
  `compiler_default_exe_path()` no longer forces `.exe` on non-Windows.
- `runtime/embedded_sources.h` — regenerated with the above fixes baked in.
- `runtime/generate_embedded_sources.py` — **new**, cross-platform (Python) equivalent of the
  PowerShell regen script, since that script can't run on macOS at all.
- `runtime/generate_embedded_sources.ps1` — fixed two real bugs found while writing the Python
  port: `Get-Content -Raw` was silently mangling non-ASCII bytes (wrong codepage), and non-printable
  characters were escaped in **decimal** (`\{0:D3}`) when C's `\nnn` string escape is **octal** —
  both fixed, verified via `clang -fsyntax-only` (the mojibake escape warnings disappeared).
- All of the above was **validated end-to-end** on this Mac using `clang` directly on hand-written
  `.ll` files standing in for what the compiler now generates (no `llc` needed for that — `clang`
  compiles `.ll` directly). Confirmed: real `argc`/`argv` correctly reach `cli_arg_count()`/`cli_arg()`
  through the actual (edited) `driver.c`, and `_NSGetExecutablePath` correctly resolves the running
  binary's directory.
- **Not yet done**: none of this has been proven by actually bootstrapping a new native
  `prismio.exe` from the fixed `.psm` source — that requires `llc` and a trusted existing `prismio`
  binary, neither available here. **This is the first thing to verify on Windows.**

Also already done, unrelated to the refactor but touching the same area: `STATUS.md` (general
codebase cleanup audit — dead duplicate parser files removed, stale docs fixed) and
`BOOTSTRAP_AUDIT.md` (the detailed runtime-linking/self-hosting audit that this refactor is based
on — read it in full before starting implementation, it has exact file:line citations for
everything referenced below).

---

## The original refactor request (verbatim, this is the task)

> # Prismio Toolchain Architecture Refactor
>
> You are acting as the lead compiler engineer for Prismio.
>
> Your goal is to refactor the build system into a production-quality architecture while
> preserving existing language behaviour.
>
> Do not modify language semantics.
>
> Focus on compiler infrastructure, bootstrap, runtime linkage, packaging, portability, and
> maintainability.
>
> ## Overall Architecture
>
> The compiler must support two completely different build modes.
>
> ### Mode 1 — Normal User Mode (default)
>
> When the user runs `prismio run main.psm` / `prismio build main.psm`, the compiler must
> automatically locate the installed Prismio toolchain. Installation layout:
>
> ```
> Prismio/
> ├── bin/
> │   prismio.exe
> ├── lib/
> │   runtime.lib
> │   runtime.a
> │   backend.lib
> │   backend.a
> └── stdlib/
> ```
>
> Discovered relative to the compiler's own executable location. No hardcoded paths. No environment
> variables. No runtime source files. No extraction from the executable. The user never manually
> links runtime libraries — the compiler does all linking automatically.
>
> ### Mode 2 — Bootstrap / Compiler Development
>
> Only for developing Prismio itself. During bootstrap the compiler MUST NOT use the installed
> runtime libraries — it must build against the repository sources (`runtime/`, `backend/`,
> `compiler/`). Guarantees every runtime modification immediately appears in the next compiler
> generation. The installed runtime must never influence bootstrap builds.
>
> ## Bootstrap Command
>
> Implement an explicit bootstrap command, e.g. `prismio bootstrap`. Do not use environment
> variables. Do not rely on compile-time `#ifdef` decisions. Runtime selection must occur through
> the build mode (i.e. the explicit command), not a flag/env var.
>
> ## Runtime Libraries
>
> Convert the runtime into proper libraries: `runtime.lib`/`runtime.a`, `backend.lib`/`backend.a`.
> Normal users should never compile `runtime.c`. The runtime should already exist as compiled
> libraries.
>
> ## Backend
>
> Prepare the architecture for a future LLVM backend. Do not implement LLVM API integration yet.
> Isolate backend responsibilities, create a backend abstraction layer, prevent LLVM-specific logic
> from leaking into frontend or semantic analysis. Future goal: Frontend → Semantic → Prismio IR →
> Backend → LLVM.
>
> ## Import System
>
> Rewrite import resolution: every module parsed once, analysed once, code-generated once.
> Memoization. Deterministic ordering. Prevent duplicate declarations and duplicate codegen.
>
> ## Duplicate Symbol Protection
>
> Guarantee no duplicate runtime symbols, functions, globals, or extern declarations. Compiler
> should emit each symbol exactly once.
>
> ## Driver Refactor
>
> Split responsibilities: CLI, configuration, runtime selection, build orchestration, linker
> invocation, diagnostics. Avoid a monolithic driver.
>
> ## Runtime Freshness
>
> Bootstrap builds must verify the runtime libraries actually correspond to the current runtime
> sources. Use hashes rather than timestamps. If stale: clearly explain the issue; rebuild
> automatically if appropriate, or fail with a precise diagnostic. Never silently continue with
> stale runtime code.
>
> ## Cross Platform
>
> Audit and eliminate platform assumptions. Support Windows, Linux, macOS. Avoid Windows-only code
> paths. Use portable path handling.
>
> ## Testing
>
> Automated tests for: user build, bootstrap build, duplicate imports, runtime linkage, stale
> runtime detection, compiler self-hosting, installation path discovery, cross-platform behaviour.
>
> ## Deliverables
>
> 1. Refactored architecture. 2. Clean bootstrap pipeline. 3. Automatic runtime discovery for
> installed toolchains. 4. Proper runtime library linkage. 5. Bootstrap using repository runtime
> sources. 6. Updated documentation. 7. Architecture report explaining every design decision.
>
> Do not introduce LLVM API integration yet.

---

## Confirmed design decisions (from this session's clarifying questions — do not re-ask these)

**1. "Prismio IR" depth: formalize the existing boundary, do NOT write a new IR data structure.**

`ir.psm` keeps its current design — it walks the AST and directly emits LLVM text through
`bridge.psm`'s `ir_*` calls. No new intermediate-representation data structure, no separate lowering
pass. Instead: make the LLVM-specific surface explicit and fully contained in
`bridge.psm`/`llvm-bridge.c`, and remove LLVM-string leakage from `ir.psm` itself where it exists
(e.g. `map_type()` in `ir.psm` directly returns raw LLVM type strings like `"i32"`, `"ptr"`,
`"double"`, `"i1"` — this is a concrete instance of backend detail leaking into what should be a
backend-agnostic layer; consider whether this can be pushed behind a `bridge.psm` call instead, e.g.
`ir_map_type_i32()`-style, so `ir.psm` deals in Prismio-level type names only).

Rationale for choosing this over a full IR rewrite: `bridge.psm` is **already** a clean, 100%
`ir_*`-prefixed, 104-function pure-FFI surface with zero non-extern functions (verified by direct
grep) — the isolation the spec asks for already mostly exists structurally. A full rewrite of
`ir.psm`'s ~1364 lines carries real risk of subtly changing generated code, is unverifiable without
a working toolchain, and directly risks violating "do not modify language semantics." Formalizing
what's already there is lower-risk and delivers the actual goal (LLVM specifics isolated from
frontend/semantic layers) without the rewrite risk.

**2. Runtime/backend library split: STRICT separation, confirmed by the user with this exact framing:**

> "The LLVM backend (bridge.psm + llvm-bridge.c) is a compiler-only component and must never be
> linked into user executables. Split the toolchain into runtime.lib (required by compiled
> programs) and backend.lib (required only by prismio.exe). User programs should link only against
> the runtime library, while the compiler links against both the runtime and backend libraries.
> Ensure this separation is enforced by the build system and verified by tests."

This confirms a finding from this session's audit: `llvm-bridge.c`'s functions (`ir_add`,
`ir_function_begin`, etc.) are only ever called by the compiler while generating `.ll` text — a
compiled Prismio program never calls them at runtime — yet today's `compiler_build_executable()`
(`runtime/driver.c` L462-611) links `bridge.obj` into **every** compiled program's output regardless
(L575-577: `clang program.obj lang_runtime.obj driver.obj bridge.obj -o exe`, unconditionally).

**Library contents, per this decision:**
- `runtime.lib`/`runtime.a` — `lang_runtime.c` + the parts of `driver.c` that a compiled Prismio
  program can legitimately need at its own runtime: `cli_arg()`/`cli_arg_count()` (reads
  `prismio_argc`/`prismio_argv`, populated by the program's own `main` prologue — see "already
  done" above) and any other plain path/string helpers a user program might `extern fn` against
  (check `tests/*.psm` for which `driver.c` externs are actually used by test programs, e.g.
  `tests/test_19_runtime_split.psm` already externs `join_path` — anything a test file externs from
  `driver.c` belongs in `runtime.lib`, not `backend.lib`).
- `backend.lib`/`backend.a` — `llvm-bridge.c` (all 104 `ir_*` functions) plus the
  compiler-build-orchestration parts of `driver.c`: `compiler_build_executable()`,
  `copy_toolchain_source_path()`, the embedded-sources-adjacent helpers, temp-file management. None
  of this is ever needed by a compiled user program.

This means `driver.c` itself needs to be **split** (not just relabeled) into a "program-support"
piece (→ `runtime.lib`) and a "compiler-build-orchestration" piece (→ `backend.lib`), because it
currently mixes both concerns in one file. This split directly serves the separately-requested
"Driver Refactor" section too — see Phase 1 below.

**3. Delivery**: the user redirected this question entirely — they want this handoff document
instead of a phased-vs-single-pass answer. **Recommend defaulting to the phased approach outlined
below anyway** once implementation resumes on Windows, since it was the reasoning already laid out
(checkpointed stages are safer for a refactor this size, especially now that a real toolchain makes
verification possible at each stage) — but this wasn't explicitly re-confirmed, so raise it again
briefly when resuming on Windows rather than assuming.

---

## Recommended phased implementation plan

### Phase 1 — Import memoization + driver.c split (foundational, do this first)

- **`src/main.psm`, `resolve_imports()` (L108-135)**: add memoization keyed by resolved import path
  — track already-resolved paths (e.g. a simple list built alongside recursion, checked before
  `read_file`+`parse_source`) so a file reachable via multiple diamond paths is parsed and merged
  exactly once. This is required groundwork — `BOOTSTRAP_AUDIT.md` §2.2 traces a live bug where
  `main.psm`'s own import graph is diamond-shaped (`utils.psm` reachable via ≥5 paths) and
  `same_top_level_name()` (L31-37) explicitly exempts `FUNCTION`/`EXTERN_FUNCTION` nodes from
  dedup, meaning without this fix, self-hosting (`prismio build src/main.psm`) likely fails to
  compile at all with "invalid redefinition of function" (verified this is a hard LLVM error, not
  a warning, via a minimal test on this Mac). **This blocks Mode 2 entirely — fix it first.**
  Also gives "every module parsed once / analysed once / code-generated once" and "deterministic
  ordering" from the spec's Import System section directly.
- **`runtime/driver.c` split**: break into (at minimum) two translation units along the boundary
  decided above:
  - Program-support file (name TBD, e.g. `runtime/program_support.c`): `cli_arg_count()`,
    `cli_arg()`, and whichever path helpers are actually externed by test/user programs.
  - Build-orchestration file (e.g. `runtime/build_driver.c`): `compiler_build_executable()` and
    everything only the compiler itself needs.
  - Within the CLI/config side (currently all in `src/main.psm`'s `main()`, L205-300): consider a
    parallel split there too — e.g. a small `src/cli.psm` handling `build`/`run`/`bootstrap`
    argument parsing and a config struct, imported by `main.psm`, so "CLI" and "configuration" are
    separated per the spec's Driver Refactor section, not just the C side.
  - Delete or repurpose `runtime/runtime.c` (currently a 4-line `#include "lang_runtime.c"` +
    `#include "driver.c"` compatibility shim, unreferenced by the live build — flagged in
    `BOOTSTRAP_AUDIT.md` §4 as a latent duplicate-symbol footgun for any future build script that
    doesn't know to exclude it).

### Phase 2 — Library packaging + Mode 1 (installed-toolchain discovery)

- Build `runtime.a`/`runtime.lib` and `backend.a`/`backend.lib` from the Phase 1 split files.
  `ar` is available on this Mac (`/usr/bin/ar`, no `llvm-ar`) for `.a` creation — verified. Windows
  `.lib` creation needs `lib.exe` (MSVC) — untestable here, needs Windows to verify; design the
  packaging step to shell out appropriately per platform (mirroring the pattern already used for
  `llc`/`clang` invocation in `driver.c`'s `run_build_command`).
  - `stdlib/` (mentioned in the desired install layout) doesn't exist as a concept anywhere in the
    current codebase — clarify/define scope for this if it comes up; not addressed by the current
    audit.
- **Installed-toolchain discovery**: extend the existing `compiler_executable_directory()` /
  `executable_directory()` pattern (`runtime/driver.c`, already fixed for macOS this session) — it
  already does exactly the "locate relative to own executable, no hardcoded paths, no env vars"
  thing the spec wants, just currently for finding *source* files as a fallback. Repurpose/extend
  it to locate `../lib/runtime.a` (or `.lib`) relative to the running `prismio` binary for Mode 1,
  replacing the current embedded-C-source unpacking entirely for the normal-user path. **No
  extraction from the executable, no runtime source files** — this replaces the
  `embedded_sources.h` mechanism for Mode 1 (see Phase 3 note on what happens to that mechanism).
- Update `compiler_build_executable()` to link against the discovered `.lib`/`.a` files instead of
  compiling `lang_runtime.c`/`driver.c`/`llvm-bridge.c` from embedded string constants.

### Phase 3 — `prismio bootstrap` command + Mode 2 + hash-based freshness

- Add `bootstrap` as a recognized first argument in `src/main.psm`'s CLI parsing (alongside
  `build`/`run`, L219-257) — or in the new `src/cli.psm` if Phase 1's CLI split happens.
  Per the spec: **no env var, no `#ifdef`** — the command itself is the mode switch. When invoked,
  it must compile `runtime/*.c` + `backend`-equivalent sources fresh (via `copy_toolchain_source_path`-
  style filesystem discovery relative to the repo, not the installed toolchain) and link them into
  the new compiler binary, guaranteeing runtime edits appear immediately — this is the literal fix
  for the staleness chain traced in `BOOTSTRAP_AUDIT.md` §2.1.
- **Hash-based freshness check**: no existing hash/checksum utility found anywhere in the runtime
  (verified via grep). Recommend implementing a small, portable hash (e.g. FNV-1a, ~10 lines of C)
  directly rather than shelling out to `shasum`/`sha256sum`/`openssl`/`certutil` — those exist on
  this Mac but aren't guaranteed present/consistent across a fresh Windows install, and a built-in
  hash keeps this dependency-free, consistent with the project's existing "no environment
  variables, no hidden magic, C ABI is the FFI" philosophy. Use it to compare the runtime library's
  recorded source hash (stored alongside the `.lib`/`.a`, e.g. a sidecar `.hash` file or embedded
  symbol) against a fresh hash of `runtime/*.c` at bootstrap time; **on mismatch, per spec: explain
  clearly and either rebuild automatically or fail with a precise diagnostic — never silently
  continue.**
- Once this mechanism exists, decide whether the embedded-sources system (`embedded_sources.h`,
  `generate_embedded_sources.py`/`.ps1`, `PRISMIO_EMBEDDED_SOURCE_AVAILABLE`) is fully replaced by
  the library-based Mode 1 discovery, or kept as a packaging step that *produces* the libraries
  (i.e. repurposed rather than deleted). Leaning toward replacement — the spec explicitly says "No
  extraction from the executable" for Mode 1, which the embedded-C-string mechanism directly is.

### Phase 4 — Backend boundary cleanup

- Apply the "formalize existing boundary" decision: audit `ir.psm` for LLVM-string leakage (start
  with `map_type()`) and push it behind `bridge.psm`. Document the boundary explicitly (e.g. a
  comment block at the top of `bridge.psm` and/or in the architecture report) so a future LLVM-API
  backend swap only requires reimplementing `llvm-bridge.c`'s 104 functions, touching nothing in
  `ir.psm`, `sema.psm`, `parser.psm`, etc.

### Phase 5 — Tests, docs, architecture report

- Extend `tests/test_runner.py` (already read in full this session — `find_prismio_exe()` via
  `PATH`, `run_test`/`run_negative_test`, globs `test_*.psm`/`neg_*.psm`) or add a parallel test
  driver for the new non-`.psm` test categories the spec asks for: user build, bootstrap build,
  duplicate-import handling, runtime linkage (verify `backend.lib` symbols are absent from a
  compiled user program's binary — e.g. `nm`/`dumpbin` check for `ir_add` etc. being absent),
  stale-runtime detection, self-hosting (`prismio bootstrap` producing a working new compiler),
  install-path discovery, cross-platform behavior.
- Update `README.MD`/`CONTRIBUTING.md`/`STATUS.md` to reflect the new architecture (they currently
  describe the embedded-sources mechanism this refactor may replace).
- Write the architecture report (spec deliverable #7) — this handoff doc plus `BOOTSTRAP_AUDIT.md`
  are the raw material; the final report should explain every design decision made across all 5
  phases, referencing the two confirmed decisions above and citing exact files/functions changed.

---

## Verification (once on Windows, with a real toolchain)

1. First, before any refactor work: confirm the **already-applied** argv/path fixes actually work
   by bootstrapping — run the existing (old) `prismio` build against the current `src/main.psm` to
   produce a new binary, then check it accepts CLI args correctly. This validates the "already
   done" section above, which was only validated via isolated `clang`+hand-written-`.ll` tests on
   Mac, never a real bootstrap.
2. Phase 1: after adding import memoization, bootstrap-compile `src/main.psm` and confirm it
   succeeds (previously predicted to fail with "invalid redefinition" — this is the direct test of
   that prediction).
3. Phase 2: build a trivial user program (`prismio build hello.psm`) against the packaged
   `runtime.lib`, confirm no `runtime/*.c` files or environment variables were needed, and confirm
   (via `dumpbin /symbols` or `nm`) that no `ir_*` (backend) symbols appear in the output binary.
4. Phase 3: run `prismio bootstrap`, edit a runtime `.c` file, run it again, confirm the edit is
   reflected in the new binary without any manual regeneration step. Then edit only a `.psm` file
   and confirm the freshness check does *not* force an unnecessary runtime rebuild.
5. Phase 5: run the full test suite (`python test_runner.py` plus whatever new tests Phase 5 adds)
   and confirm the existing 29 positive + 6 negative tests still pass unchanged — this is the
   concrete check on "do not modify language semantics."

---

## Kickoff prompt for the new session

Paste this as the first message in the new Windows Claude Code session, in this same repo:

> Continue the Prismio toolchain architecture refactor. Read `STATUS.md`, `BOOTSTRAP_AUDIT.md`, and
> `REFACTOR_HANDOFF.md` in the repo root first — they contain a prior audit, a detailed bootstrap/
> runtime-linking analysis, and the full confirmed design for this refactor (including two design
> decisions already settled: formalize the existing AST→bridge.psm boundary instead of building a
> new IR data structure, and strictly separate runtime.lib from backend.lib so the LLVM backend
> never links into user-compiled programs). Start with Phase 1 (import-resolution memoization in
> `src/main.psm`'s `resolve_imports()`, then the `runtime/driver.c` split) since it's blocking —
> self-hosting likely can't even compile until the diamond-import duplicate-declaration bug is
> fixed. You have a real toolchain here (llc, existing prismio binary) — use it to actually verify
> each phase as you go, unlike the prior session which could only validate in isolation with clang.
