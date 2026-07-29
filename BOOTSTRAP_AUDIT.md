# Prismio — Bootstrap & Runtime-Linking Architecture Audit

Read-only audit. No code was modified to produce this report. All claims are cited to exact
files/lines in the current tree. Where a claim is derived from static analysis rather than an
actual compiler run (this environment has no `llc` and no working `prismio` binary — the checked-in
`prismio.exe` files are Windows PE binaries, unusable here), that is stated explicitly.

---

## 1. Current behavior

### 1.1 Pipeline trace: `prismio build file.psm` → executable

```
prismio build file.psm [-o out]
  └─ src/main.psm: main()                                    [L205]
       └─ compile_source(path, output_file, run_after_build) [L144]
            ├─ create_lexer + lex_all_tokens                 [L160-161]  (src/lexer.psm)
            ├─ parser_create + parse_module                  [L162-163]  (src/parser.psm)
            ├─ resolve_imports(ast_root, base_dir)            [L166]     (src/main.psm L108)
            ├─ analyze_module(merged_ast)                     [L168]     (src/sema.psm)
            ├─ ir_reset() + generate_module(merged_ast)        [L170-171] (src/ir.psm L1211)
            ├─ ir_write_file(out_file)                         [L173]     → writes the .ll text
            ├─ [if output ends in .ll: stop here, IR-only mode][L178-182]
            └─ compiler_build_executable(out_file, output_file)[L184]     (runtime/driver.c L462)
                 ├─ resolve runtime sources: embedded XOR filesystem search (see 1.2)
                 ├─ llc  <ir>.ll  -filetype=obj -o program.obj          [L556]
                 ├─ clang -c lang_runtime.c -o lang_runtime.obj         [L560]
                 ├─ clang -c driver.c       -o driver.obj               [L565]
                 ├─ clang -c llvm-bridge.c  -o bridge.obj                [L570]
                 ├─ clang program.obj lang_runtime.obj driver.obj
                 │        bridge.obj -o <exe_file>                       [L575]
                 └─ delete all four temp .obj + any unpacked embedded .c/.h [L580-588]
```

Three distinct output modes exist, selected by `compile_source` (`src/main.psm` L143-203):

1. **Native build** (default): full pipeline above, ends in a linked executable.
2. **IR-only** (`-o foo.ll`): stops after `ir_write_file`, never calls `compiler_build_executable` —
   no runtime linking occurs at all (`str_ends_with(output_file, ".ll")` check, L147-149).
3. **Build+run** (`prismio run`): same as native build, then `compiler_run_executable` (L196) shells
   out to the produced binary.

### 1.2 How runtime libraries are included: embedded, external, or both?

**Both — but as a mutually-exclusive, compile-time choice baked into whichever `prismio` binary is
doing the compiling, not a per-invocation or per-project choice.**

`compiler_build_executable()` (`runtime/driver.c` L462-611) decides via a **C preprocessor
directive**, `#ifdef PRISMIO_EMBEDDED_SOURCE_AVAILABLE` (L497), which branch runs:

- **Embedded path** (L497-517, active today): `runtime/embedded_sources.h` unconditionally defines
  `PRISMIO_EMBEDDED_SOURCE_AVAILABLE 1` (line 4 of that generated file) and is `#include`d
  unconditionally at the top of `driver.c` (L27-34: `#include PRISMIO_EMBEDDED_SOURCES_HEADER`).
  When this macro is defined, `compiler_build_executable` writes three string constants —
  `prismio_embedded_lang_runtime_c`, `prismio_embedded_driver_c`, `prismio_embedded_llvm_bridge_c`
  (all baked into `embedded_sources.h`, which is itself compiled into `driver.o` and therefore into
  whatever `prismio` binary that `driver.o` was linked into) — out to a temp directory
  (`compiler_temp_source_dir`, L498), then compiles and links **those temp copies**. No filesystem
  search of `runtime/` occurs.
- **Filesystem-search path** (L519-532, dead code today): if the macro were undefined,
  `copy_toolchain_source_path()` (L245-268) searches `runtime/lang_runtime.c`,
  `../runtime/lang_runtime.c`, `../../runtime/lang_runtime.c` (and back-slash variants) relative to
  the compiler executable's own directory, falling back to the same list relative to CWD.

These two branches are **structurally mutually exclusive within one build**: every filesystem-search
call is guarded by `!using_embedded_sources &&` (L519, 524, 529), so if the embedded path succeeds,
the fallback never runs. There is no scenario in the current code where both a compiled-in embedded
copy and a filesystem copy get linked into the same executable — confirmed by inspection, this
specific "duplicate linkage" shape does not occur.

**The macro is resolved once, at the time `driver.c` itself was last compiled into whatever
`prismio` binary you're running** — it is not a runtime flag, not a CLI option, not an environment
variable. A single `prismio` binary always takes the same branch, for every file it ever compiles,
for as long as that binary exists.

### 1.3 Every file and function responsible

| File | Role |
|---|---|
| `src/main.psm` | `compile_source()` (L144) orchestrates the pipeline; `resolve_imports()` (L108), `join_import_path()` (L100), `append_statement()`/`append_non_imports()` (L64/87) merge imports; declares the `extern fn`s into `driver.c` (`compiler_build_executable`, `cli_arg`/`cli_arg_count`, `join_path`, etc., L10-20) |
| `src/ir.psm` | `generate_module()` (L1211) emits the `prismio_argc`/`prismio_argv` globals (L1246-1247) and all runtime forward-declarations; `generate_function()` (L945) special-cases `is_main` to inject real argc/argv params (L964-967) and store them (L982-985) |
| `src/bridge.psm` | Pure `extern fn` surface (104 declarations, 0 real functions) — the Prismio-side prototypes for every `runtime/llvm-bridge.c` function |
| `runtime/driver.c` | **The core of this whole audit.** `compiler_build_executable()` (L462) does the embedded-vs-filesystem decision + orchestrates `llc`/`clang` invocations; `write_embedded_sources_header()` (L422), `write_c_string_literal()` (L380) support the embedded path; `copy_toolchain_source_path()` (L245), `copy_existing_path()`/`copy_existing_file_path()` (L188/201) support the filesystem-search path; `compiler_executable_directory()` (L219), `executable_directory()` (L241) locate the running binary; `cli_arg_count()`/`cli_arg()` read `prismio_argc`/`prismio_argv` |
| `runtime/embedded_sources.h` | **Generated** (2635 lines). Defines `PRISMIO_EMBEDDED_SOURCE_AVAILABLE` and the three `prismio_embedded_*` C string constants that are the actual embedded payload |
| `runtime/generate_embedded_sources.ps1` / `.py` | Offline regeneration tooling. **Not part of the compiler binary** — a separate step a human (or a build script, if one existed) must run and then rebuild `prismio` for the change to take effect |
| `runtime/lang_runtime.c`, `runtime/llvm-bridge.c` | The actual runtime implementations — these are what eventually gets compiled into `lang_runtime.obj`/`bridge.obj`, whether sourced from the embedded copy or the filesystem |
| `runtime/runtime.c` | 4-line `#include "lang_runtime.c"` + `#include "driver.c"` shim, labeled "Compatibility wrapper for older build paths." **Not referenced anywhere in the current build flow** — `compiler_build_executable`'s candidate-path arrays (L463-480) never name `runtime.c`, and it isn't part of the embedded set either. Dead in the automatic pipeline (see §4). |

---

## 2. Compiler self-hosting

### 2.1 What happens when the compiler compiles itself (`prismio build src/main.psm`)?

There is **no special-casing anywhere in the codebase for "I am compiling the compiler."**
`compile_source("src/main.psm", ...)` runs through the exact same pipeline as compiling any user
`app.psm` — same `resolve_imports`, same `compiler_build_executable`. The compiler has no concept of
its own identity, no self-detection, no separate code path.

- **Does it automatically inject the embedded runtime?** Yes — unconditionally, for the same reason
  as any other build: `PRISMIO_EMBEDDED_SOURCE_AVAILABLE` is a property of the `prismio` binary
  doing the compiling, not of what's being compiled.
- **Does it use the runtime from the source tree instead?** No, not by default, and not
  automatically under any circumstance. The only way the filesystem-search path (which *would* read
  live `runtime/*.c`) ever runs is if the compiler binary in use was itself built without an
  available `embedded_sources.h` — nothing about *what file you're building* changes this.
- **Does it risk using stale embedded runtime code? Yes — concretely, on every bootstrap:**

  Trace it precisely. Say you edit `runtime/driver.c` (as this session did, in the prior
  conversation turn), then run `prismio build src/main.psm -o prismio_new` using an **existing**
  `prismio` binary (`prismio_old`) to do the compiling:

  1. `prismio_old`'s own `compiler_build_executable` — compiled into `prismio_old` at *its own* last
     build time — runs. Its `#ifdef PRISMIO_EMBEDDED_SOURCE_AVAILABLE` branch was resolved back
     then, permanently, into `prismio_old`'s machine code.
  2. If that branch was "embedded" (the default/current state), it writes out
     `prismio_embedded_driver_c` — a **string constant baked into `prismio_old` itself**, reflecting
     whatever `runtime/driver.c` looked like when `prismio_old` was built — to a temp file, and
     compiles *that*.
  3. `prismio_new` is produced, linked against **`prismio_old`'s embedded (old) runtime** — not
     against the `runtime/driver.c` currently on disk, even though that's the file you just edited.
  4. Your edit is invisible to `prismio_new` unless, *before* step 1, you had separately regenerated
     `embedded_sources.h` from the edited `.c` files **and rebuilt `prismio_old` itself** so its own
     embedded copy was current. Nothing in the repo prompts, checks, or automates this.

  This is a self-referential propagation chain: **every generation's embedded runtime is inherited
  from the previous generation's compiler binary, not from the source tree**, unless a human
  manually breaks the chain by regenerating + rebuilding the *bootstrapping* compiler first. This is
  the literal mechanism behind the staleness risk already flagged in `STATUS.md`, now traced
  precisely for the self-hosting case specifically.

- **Is there a way to force "use the source tree" for a specific build?** No. There is no CLI flag,
  environment variable, or config option anywhere in `src/main.psm`'s argument parsing (L205-300) or
  `driver.c` that selects the filesystem-search path. It is unreachable except by rebuilding the
  compiler itself without `PRISMIO_EMBEDDED_SOURCE_AVAILABLE` defined — not a decision available at
  `prismio build` time.

### 2.2 Duplicate runtime linkage — two separate risks, at two separate layers

**At the C-object-file layer (what the question is most directly asking): no risk found.**
`compiler_build_executable` always links exactly four objects — `program.obj`, `lang_runtime.obj`,
`driver.obj`, `bridge.obj` (L575-577) — regardless of which path supplied the three runtime `.c`
files. The embedded/filesystem branches are mutually exclusive (§1.2), and all embedded temp files
are deleted after linking (L584-588), so there's no leftover-file collision risk between successive
builds either. `runtime.c`'s `#include "lang_runtime.c"` + `#include "driver.c"` (both full-text
includes into one translation unit) is a **latent** footgun only if some *other*, currently
nonexistent build script were to compile `runtime.c` **and** separately compile+link
`lang_runtime.c`/`driver.c` in the same link step — that would produce "duplicate symbol" linker
errors for every function in both files. Not triggered by anything in the current automatic
pipeline, since `compiler_build_executable` never names `runtime.c` as a candidate. Worth removing
regardless (see §4) — it's a footgun waiting for a future Makefile/CI script that naively globs
`runtime/*.c`.

**At the Prismio-source-merge layer (found during this audit, not part of the original question but
directly relevant to "what happens when compiling the compiler itself" — this is a second,
independent bug from the runtime-embedding question):**

`resolve_imports()` (`src/main.psm` L108-135) recursively re-reads, re-parses, and re-merges every
`import` statement with **no memoization** — there is no "already resolved this file" tracking
anywhere in the function. Combined with `same_top_level_name()` (L31-37), which explicitly exempts
`FUNCTION` and `EXTERN_FUNCTION` node kinds from duplicate detection (L33-35: returns `false`
— "not a duplicate" — whenever either node is a function or extern, regardless of matching names),
this means: **any file reachable via more than one import path gets every one of its top-level
functions and extern declarations merged into the final AST once per path**, with no deduplication.

`main.psm`'s own import graph is diamond-shaped and hits this directly:

```
main.psm imports: lexer, token, utils, ast, parser, bridge, ir, sema
  lexer  → token, utils, keywords
  parser → lexer, token, utils, ast
  ir     → types
  sema   → ast, token, types, bridge
  types  → ast, utils
```

`utils.psm` alone is reachable via at least 5 distinct paths (direct; via `lexer`; via `parser`; via
`parser→lexer`; via `sema→types` and `ir→types`). It declares 7 real functions
(`is_digit`, `is_alpha`, `is_alnum`, `is_space`, `is_separator`, `is_operator`, `char_code` —
`src/utils.psm` L12-57) and 10 `extern fn`s. `token.psm`'s `type_to_string` (L37) and `ast.psm`'s
`create_node` (L65) are similarly multiply-reachable.

I confirmed empirically (not just by reading the spec) that this is fatal, not harmless, by
compiling a minimal two-`declare` LLVM IR file with the `clang` available in this environment:

```
declare i32 @getpid()
declare i32 @getpid()
```
```
error: invalid redefinition of function 'getpid'
```

Duplicate `declare` is a hard compile error in LLVM IR; duplicate `define` (which is what would
actually happen here, since these are real `fn`, not `extern fn`) is worse. `struct`/`enum`
declarations are *correctly* deduplicated by the same merge logic (`same_top_level_name` only
exempts `FUNCTION`/`EXTERN_FUNCTION`, L33), so `TokenType`, `Token`, `ASTNode`, etc. are safe —
this is specifically a functions-and-externs bug.

**Caveat on confidence**: this is a static-analysis finding, traced precisely through the actual
merge/dedup code and confirmed against real LLVM semantics, but **not confirmed by actually running
`prismio build src/main.psm` end-to-end** (no working `prismio`/`llc` in this environment). It's
possible something outside the code paths I traced compensates for this (I found none), or that this
exact self-hosting invocation has simply never been exercised in this project's history — the
existing 29+ test files each import at most one or two files directly (mostly `tests/utils.psm`, a
small separate helper, not `src/utils.psm`), so they don't exercise a diamond anywhere near this
deep. If self-hosting has never actually been run against the current `src/` tree, this bug may be
latent and undiscovered rather than a regression.

---

## 3. Architecture evaluation against the desired design

| Desired | Current | Match? |
|---|---|---|
| **Normal users**: `prismio build app.psm` uses the runtime embedded in the released compiler; no external runtime files required | Exactly this, by default, since `embedded_sources.h` ships with `PRISMIO_EMBEDDED_SOURCE_AVAILABLE` defined and the filesystem-search fallback never runs while that's true | **Yes** |
| **Bootstrap/dev**: building Prismio itself should use the *latest* runtime sources from the repo, not the embedded copy | Never happens automatically. Bootstrap builds use whichever runtime was embedded in the compiler binary doing the build — i.e., the *previous* generation's runtime, not the current `runtime/*.c` on disk (§2.1) | **No** |
| **Bootstrap/dev**: runtime modifications should automatically appear in the newly built compiler | They don't, and can't, without a manual two-step dance (regenerate header, rebuild the *old* compiler, then use that to bootstrap again) that nothing in the repo documents or automates | **No** |

The gap is structural, not a bug in the embedded-path logic itself (which works correctly for its
one supported case). The architecture has exactly one build mode — "whatever this binary was last
compiled with" — where the desired design needs two: a default (embedded, for end users) and an
explicit override (source-tree, for whoever is developing the compiler/runtime).

---

## 4. Problems

**Incorrect behavior**
- Bootstrap builds silently produce a compiler linked against stale runtime, with the compiler
  logic (`.psm`) up to date but the runtime (`.c`) frozen at whatever the bootstrapping binary last
  embedded (§2.1).
- Diamond-shaped import graphs (which `main.psm`'s own import graph is) produce duplicate
  `FUNCTION`/`EXTERN_FUNCTION` AST nodes that, per LLVM's actual semantics (verified empirically),
  would fail to compile with "invalid redefinition" errors (§2.2).

**Stale runtime risks**
- No automated or even manual-but-documented process ties `embedded_sources.h` regeneration to
  `runtime/*.c` edits or to `prismio.exe` rebuilds. Three independent artifacts (`runtime/*.c`,
  `embedded_sources.h`, the compiled `prismio` binary) can each be at a different revision with
  nothing detecting the drift.
- This is now demonstrable in the repo's *own current state*: `embedded_sources.h` was regenerated
  in the prior session (reflecting the fixed `driver.c`), but no `prismio.exe` in this environment
  has been rebuilt against it — the checked-in Windows binaries (gitignored, local build artifacts,
  not part of version control per `.gitignore`'s `*.exe` rule) still embed whatever runtime existed
  whenever they were last built, which predates this session's fixes.

**Duplicate symbol risks**
- `runtime.c`'s full-text `#include` of both `lang_runtime.c` and `driver.c` is a footgun for any
  future manual/external build script that compiles it alongside the separately-compiled
  `lang_runtime.c`/`driver.c` — not triggered today, but a trap for whoever eventually writes the
  Makefile/CI config `STATUS.md` already flags as missing.
- The import-merge duplicate-`FUNCTION`/`EXTERN_FUNCTION` bug (§2.2) — a distinct, more severe risk
  that manifests as duplicate LLVM symbol definitions, specifically triggered by self-hosting's
  diamond import graph.

**Portability issues**
- Already audited and fixed in the prior session (cross-platform argc/argv, macOS executable-path
  resolution, PowerShell-only regen tooling) — out of scope for this report except as background;
  see `STATUS.md`.

**Packaging issues**
- No canonical "release" `prismio` binary exists anywhere in the repo or its build tooling — the
  `.exe` files present locally are gitignored build artifacts, not a checked-in or CI-produced
  reference. README's claim that "a prebuilt bootstrap binary is used to compile them during
  toolchain setup" names a mechanism this repository does not itself define, build, or verify —
  it's presumably distributed out-of-band (e.g. via the docs site), which means the actual
  provenance and freshness of *that* binary's embedded runtime is entirely unverifiable from here.

**Bootstrap issues**
- No build script, Makefile, or CI defines the bootstrap sequence at all (already flagged in
  `STATUS.md`, item 2) — this audit adds that even if one existed, using it naively (rebuild via
  the existing compiler, no extra steps) would still silently carry forward stale runtime per §2.1.
- No mechanism exists to intentionally select "use source tree" for a bootstrap build (§2.1, last
  point) — the desired dev-mode behavior isn't just unimplemented by default, it's *unreachable*
  through any documented or exposed interface.

**Design flaws**
- The embedded-vs-filesystem decision is a **compile-time property of the compiler binary**, not a
  **build-time property of the invocation**. This is the root architectural cause of both the
  staleness risk and the missing dev-mode: one binary can only ever do one thing, forever, until
  it's rebuilt — there's no way to ask a single `prismio` binary to behave differently for a
  bootstrap build vs. a normal build.
- `resolve_imports` has no per-file memoization, which is the root cause of the diamond-duplication
  bug — the `same_top_level_name` exemption for functions/externs (L33-35) appears to be a
  workaround for a *different*, legitimate case (letting a real `fn` definition coexist with an
  `extern fn` forward-declaration of the same name in the AST without them being flagged as
  conflicting duplicates) but, as a side effect, it also disables the *only* dedup mechanism that
  could have masked the missing import memoization.

---

## 5. Recommendation

### 5.1 Target architecture

Turn the embedded-vs-source-tree choice from a **compile-time fact about the binary** into a
**build-time decision the binary can make per invocation**, defaulting to embedded (today's
behavior, correct for end users) with an explicit opt-in for source-tree mode (for bootstrap/dev).

```
prismio build app.psm              → embedded runtime (default, unchanged for end users)
PRISMIO_DEV_RUNTIME=1 prismio build src/main.psm
                                    → forces the filesystem-search path against runtime/*.c,
                                      even though this binary also has an embedded copy available
```

### 5.2 Specific changes (described, not applied — user asked for no code changes)

**`runtime/driver.c`, `compiler_build_executable()` (L462-611)**
- Change the branch selection at L497 from a pure `#ifdef PRISMIO_EMBEDDED_SOURCE_AVAILABLE` to a
  compile-time-available-but-runtime-gated check: keep the `#ifdef` (still needed so the embedded
  string constants exist at all when `embedded_sources.h` is present), but add a runtime condition —
  e.g. `if (getenv("PRISMIO_DEV_RUNTIME") == NULL)` — wrapping the block at L504-516, so that even a
  binary built with embedded sources available will skip straight to the filesystem-search path
  (L519-532) when the env var is set. This makes both code paths coexist and be selectable per
  invocation, instead of one being permanently compiled out.
- This alone fixes §2.1 and §3's bootstrap-mode gap: a documented bootstrap command becomes
  `PRISMIO_DEV_RUNTIME=1 prismio build src/main.psm`, which picks up live `runtime/*.c` edits
  immediately, with no separate regeneration step needed for the *compiler logic* changes (only
  still needed to update what gets embedded into the *next released* binary — see below).

**A documented (or scripted) two-phase bootstrap procedure**, since `STATUS.md` already establishes
there's no build script for the compiler at all:
1. Dev loop: `PRISMIO_DEV_RUNTIME=1 prismio build src/main.psm` — always uses live `runtime/*.c`
   and live `.psm` source. Fast iteration, no embedding step.
2. Release cut: regenerate `embedded_sources.h` (`runtime/generate_embedded_sources.py`, cross-
   platform since the prior session's fix), then run `prismio build src/main.psm` **without** the
   env var — this produces the binary that gets distributed, with a fresh embedded copy baked in
   for downstream end users.

**`src/main.psm`, `resolve_imports()` (L108-135)**
- Add memoization keyed by resolved import path (e.g. a Prismio-level set/list checked before
  reading+parsing a file, populated as each import is resolved) so a file reachable via multiple
  diamond paths is parsed and merged exactly once. This is the correct general fix — it addresses
  the root cause (repeated re-resolution) rather than papering over it at the merge-dedup layer.
- Independently, consider tightening `same_top_level_name()` (L31-37) so `FUNCTION`/`EXTERN_FUNCTION`
  are only exempted from dedup when one side is genuinely a forward-declare/definition pair (i.e.
  keep today's intended behavior for that legitimate case) rather than unconditionally for every
  function-shaped node — this is a defense-in-depth fix, not a substitute for the memoization fix
  above, since the memoization fix prevents the duplicate nodes from being created in the first
  place.

**`runtime/runtime.c`**
- Delete it, or replace its contents with a comment pointing at `lang_runtime.c`/`driver.c`/
  `llvm-bridge.c` directly. It's unreferenced by the current build (§1.3) and exists purely as a
  duplicate-symbol trap for any future build script that doesn't know to exclude it.

**A staleness guard** (new, small addition — exact placement is a judgment call, e.g. a check inside
`compiler_build_executable` before using the embedded path, or a standalone script run in CI/pre-
build): compare `embedded_sources.h`'s mtime against `lang_runtime.c`/`driver.c`/`llvm-bridge.c`'s
mtimes; warn (or fail, for a release build) if the header is older. This directly targets the
"is there any possibility of duplicate/stale linkage going unnoticed" concern — right now nothing
detects drift between the three artifacts at all.

### 5.3 Why this shape specifically

The alternative — keeping the compile-time `#ifdef` as the only switch, and instead trying to
*discipline* the bootstrap process (always remember to regenerate + rebuild in the right order) —
is exactly the process that has already failed silently once in this repository's own history (the
mismatch between the regenerated `embedded_sources.h` and the not-yet-rebuilt `prismio.exe`
binaries, noted in §4). A runtime-checked env var costs one `getenv` call and a few lines, and
converts "a human must remember a multi-step manual sequence, with no verification" into "a human
sets one flag, and the wrong-runtime failure mode becomes structurally unreachable for whoever sets
it, while remaining the unchanged default for everyone who doesn't."
