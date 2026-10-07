# Contributing to Prismio

Thank you for your interest in contributing to Prismio. This document covers everything you need to know to get involved effectively.

---

## Table of Contents

- [Overview for Contributors](#overview-for-contributors)
- [What to Work On](#what-to-work-on)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Making Changes](#making-changes)
- [Running the Test Suite](#running-the-test-suite)
- [Writing Tests](#writing-tests)
- [Commit Messages](#commit-messages)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Code of Conduct](#code-of-conduct)

---

## Overview for Contributors

Prismio is a self-hosted systems programming language. The compiler — the lexer, parser, semantic analysis, allocation inference, and IR generator — is written in Prismio itself, in `.psm` files under `src/`. Most contributions are Prismio.

The LLVM backend and the runtime are C, under `runtime/` (see [C_CODE_STYLE.md](C_CODE_STYLE.md)); you only need to touch them for a backend or runtime change. The compiler produces LLVM IR, optimises and generates machine code in process with the LLVM it links (AArch64, X86 and WebAssembly), and hands the object to the system's linker.

A seed, published as a release asset and pinned in `bootstrap/seed.json`, builds the first compiler on a machine that has none.

---

## What to Work On

The most impactful areas for contributors right now are:

- **Correctness** — fixing compiler bugs, incorrect IR generation, or parser edge cases
- **Language features** — implementing new constructs consistent with the language design
- **Test coverage** — adding `.psm` test cases in `tests/` for language behaviors
- **Platform support** — CI configuration and cross-platform build validation
- **Documentation** — improving inline comments and examples in source files

For a list of open issues, see the [GitHub Issues tracker](https://github.com/prismio-lang/prismio/issues).

---

## Prerequisites

| Dependency | Version | Notes |
|---|---|---|
| Python | 3.9+ | The one thing you install yourself: it runs setup, the test runner and the AIF differential |
| A system C toolchain | — | The platform linker and C library: Xcode Command Line Tools on macOS, `build-essential` on Linux, Visual Studio's C++ tools on Windows. `python tools/setup.py` probes it by compiling and linking a program, and `--install-system-deps` installs it (asks first) |
| LLVM | 23.1.1, pinned | Provisioned into `third_party/llvm` by `python tools/setup.py` (through `tools/setup_llvm.py`) — do not install one |
| Prismio | any | Optional. You do not need an installed compiler — the release seed (downloaded and checked for you) builds the first one |

`python tools/setup_llvm.py` downloads the pinned LLVM release, checks its SHA-256,
and prepares it in `third_party/llvm` (about 2.5 minutes once; a no-op after
that). It does not look at any LLVM already on the machine: the compiler links
this one statically, so a Homebrew or apt upgrade cannot break a built compiler.
`--llvm-dir <path>` adopts a local build instead, for platforms with no release
archive.

---

## Building the compiler

**This is the step that is easy to miss: editing `src/` and running the tests
proves nothing until you have built a compiler from your change.** The compiler
is written in itself, so a build always takes an existing compiler as input.

From a fresh checkout with no `prismio` anywhere:

```bash
tools/bootstrap.sh --seed --out build/gen0
```

The seed is LLVM IR for a compiler built from an earlier tree. It is the only way out
of the cycle on a host that has none. It is not in the repository: `--seed` runs
`tools/fetch_seed.py`, which downloads the release asset pinned in `bootstrap/seed.json`,
checks its SHA-256, and caches it in `bootstrap/` (ignored by git).

After that, one generation per command — about **4 seconds**, because the C
runtime objects are cached and only the changed Prismio is recompiled:

```bash
tools/bootstrap.sh --compiler build/gen0 --out build/gen1
```

### The loop after a change

```bash
tools/bootstrap.sh --compiler build/gen0 --out build/gen1
tools/bootstrap.sh --compiler build/gen1 --out build/gen2

build/gen1 build src/main.psm -o /tmp/a.ll
build/gen2 build src/main.psm -o /tmp/b.ll
cmp /tmp/a.ll /tmp/b.ll

PRISMIO=$PWD/build/gen2 python3 tests/test_runner.py
```

The repository itself is a Prismio project. For the ordinary edit loop, bare
`prismio build` reads the stable first block of the root manifest:

```ums
toolchain { host = ".prismio/build/debug/prismio" }
```

On the first run that host is absent, so global Prismio processes `build.ums`
and builds it as stage 0. On later runs global Prismio forwards the complete
command to the last known-good project host. The host—not the older installed
compiler—then parses the complete manifest and builds a sibling candidate. The
global parent atomically promotes that candidate only after the host exits.

The bootstrap script remains necessary for a machine with no installed Prismio
and for the named generation chain, where the exact host compiler is part of the
check. The manifest declares `executable("prismio")` and explicitly links the
`prismio.backend` toolchain component. Artifact kind and native linkage remain
separate: application executables link only the runtime unless their own
`link { ... }` block names additional libraries, search paths, files, or
platform frameworks.
Do not run a project build
through `.prismio/build/debug/prismio` itself; it is the host generation being
replaced, while the installed stage-0 process is the orchestrator.

**Two generations before believing it.** A compiler that links may only have
linked because the *old* one built it; the second generation is the first one
built by your change. `cmp` failing means the two disagree about the compiler
they emit, which is a real bug even when every test passes.

Name generations explicitly for bootstrap and fixed-point checks. Bare
`prismio` is intentional only for the project-local loop described above. The
installed compiler reads only the stable `toolchain` prefix, so newer syntax in
the rest of the manifest is handled by the selected host.
`build/gen2 --version` prints the compiler directory and the standard library it
resolves, which is the fastest way to check you are running what you think.

### The project commands

Once you have a compiler (a bootstrapped generation, or an installed one), the
checkout is a Prismio project and `build.ums` declares its commands:

| Command | What it does |
|---|---|
| `prismio build` | builds the compiler this checkout runs (`.prismio/build/debug/prismio`) |
| `prismio suite` | the test suite, for the fast loop |
| `prismio verify` | suite, source lists, externs, AIF differential |
| `prismio gate` | lint, then the whole release gate on a packaged candidate |

Two things to know. **Do not run `prismio build`, or edit `src/`, while the suite
is running**: one of its fixtures replaces the project compiler, and some compile the
working tree. And the LLVM targets are listed twice, in `runtime/prismio_llvm.h` and
`tools/setup_llvm.py`; `python tools/check_source_lists.py` fails if they disagree.

### Before opening a pull request

```bash
prismio gate
```

Fourteen gates in one command: source lists, two-generation bootstrap, IR
fixpoint, self-reproduction, seed agreement, the full suite, the AIF oracle
differential, the corpus, a `--verify` sweep, curated-runtime-off,
object-cache-off, JIT, cross-target, and the packaged toolchain. It packages the
compiler first and puts the pinned LLVM on `PATH`, because a bare bootstrap
generation has no installed runtime and the system's `clang` cannot read LLVM 23
bitcode; running `tools/release_gate.py` by hand against `build/gen2` fails for
exactly those reasons.

### If you changed the syntax

New syntax lands in **two commits**, and the order is not negotiable: the pinned
seed has to be able to parse `src/`, so teach the frontend first without using the
syntax in `src/`, then cut a seed with `tools/refresh_seed.sh --compiler build/gen2`
(`tools/refresh_seed.ps1` on Windows), publish it as a release asset and commit the
new `bootstrap/seed.json`, and only then use the syntax. Skipping this leaves a fresh
clone unable to build. See [CODE_STYLE.md](CODE_STYLE.md).

CI only checks that the pinned seed can build the tree, not that it is recent, so a
seed that still parses `src/` stays pinned until something needs a newer one.

---

## Getting Started

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/prismio.git
   cd prismio
   ```
3. **Create a branch** for your work:
   ```bash
   git checkout -b feat/my-feature
   ```
4. Make your changes inside `src/` (or `tests/` for test-only contributions).
5. Run the test suite to verify nothing is broken (see below).
6. Commit your changes following the [commit message conventions](#commit-messages).
7. Push your branch and open a pull request against `main`.

---

## Project Structure

```
prismio/
├── src/
│   ├── main.psm           # Entry point, CLI, import resolver, build driver
│   ├── common/
│   │   ├── text.psm       # String and character primitives
│   │   └── diagnostics.psm# extern fn declarations for the diagnostics engine
│   ├── lexer/
│   │   ├── token.psm      # Token kinds, the Token struct, the keyword set
│   │   └── scanner.psm    # Source text → token list
│   ├── ast/
│   │   ├── nodes.psm      # AST node definitions
│   │   ├── types.psm      # Type system
│   │   └── dump.psm       # AST → JSON, read by the AIF oracle
│   ├── parse/
│   │   ├── parser.psm     # Parser state, recovery, module entry
│   │   ├── decl.psm       # Declarations, type annotations, FFI contracts
│   │   ├── stmt.psm       # Statements
│   │   └── expr.psm       # Expressions
│   ├── sema/
│   │   ├── checker.psm    # The checking passes
│   │   ├── symbols.psm    # Mangling and overload resolution
│   │   ├── types.psm      # Annotation resolution and assignability
│   │   ├── ownership.psm  # Move/borrow/drop, FFI contracts
│   │   ├── flow.psm       # Divergence and break analysis
│   │   └── builtins.psm   # Calls with a known shape
│   ├── aif/
│   │   ├── model.psm      # Tiers, site classification, value sets
│   │   ├── contracts.psm  # FFI ownership contracts
│   │   ├── walk.psm       # Site discovery and the fixpoint
│   │   ├── layout.psm     # Struct sizes and the type graph
│   │   └── report.psm     # Manifest, summary, minimal cause
│   └── ir/
│       ├── context.psm    # Emission state and constants
│       ├── types.psm      # Prismio types → LLVM types
│       ├── expr.psm       # Expression lowering
│       ├── stmt.psm       # Statement lowering, scope and region unwinding
│       ├── module.psm     # Functions, structs, whole-module emission
│       └── bridge.psm     # extern fn declarations for the LLVM C API backend
├── tests/
│   ├── test_runner.py    # Python test runner
│   ├── test_*.psm        # Language test cases (positive)
│   ├── neg_*.psm         # Language test cases (expected to fail compilation)
│   └── utils.psm         # Shared test utilities
└── runtime/               # Runtime library
```

A module's import path is its location: `src/ir/expr.psm` is `import ir.expr`, and `import ir.*`
takes every module in the package. Paths are always relative to `src/`, never to the importing file.

The compiler runs a dedicated semantic analysis pass (`src/sema/`) between parsing and IR
generation — it performs type checking and enforces move/borrow/drop ownership rules before any IR
is generated.

---

## Making Changes

- All compiler source lives under `src/`. Changes to language behavior or the compiler pipeline belong there.
- Prefer small, focused changes. A PR that fixes one thing well is easier to review than one that fixes many things at once.
- Add or update tests in `tests/` for any behavior you add or fix.
- Keep inline comments accurate and up to date with the code they describe.
- Do not commit compiled artifacts (`.exe`, `.o`, `.ll`, etc.) — these are covered by `.gitignore`.

---

## Running the Test Suite

The test runner compiles each `test_*.psm` file with the system `prismio` binary and executes the resulting binary, checking for a clean exit code.

```bash
PRISMIO=$PWD/build/gen2 python3 tests/test_runner.py
```

`$PRISMIO` wins over `PATH`, which is what lets a freshly bootstrapped compiler be
tested without installing it. With neither, the runner resolves `prismio` from
`PATH` — and that is almost never the compiler you just built.

`PRISMIO_TEST_JOBS=1` runs sequentially, which is what to reach for when a failure
looks like interference rather than a bug.

During development, run one positive or negative file fixture by exact stem:

```bash
PRISMIO=$PWD/build/gen2 python3 tests/test_runner.py test_92_field_view_provenance
```

Substring filters and repeated `-k` flags select several file fixtures. Use
`python3 tests/test_runner.py --list` to list them. Filtered runs intentionally
skip the suite's global integration checks; an unfiltered run remains the final
check.

The repository's dependency-free formatting and lint entry points are:

```bash
python3 tools/format_sources.py --write
python3 tools/format_sources.py --check
python3 tools/lint.py
```

Formatting (LF endings, no trailing spaces, one final newline) is a **warning**, in
CI and in `lint.py`: it never fails a run, and `--write` fixes it. Lint fails only
on real problems: a syntax error, a tab in Prismio source, a bad diagnostic code.

`python tools/sanitizer_smoke.py --compiler build/gen2` links representative ownership
and concurrency programs with AddressSanitizer. `python3 benchmarks/run.py`
builds, validates, and measures the Prismio/C++/Rust performance suite.

All tests must pass before a PR can be merged.

---

## Writing Tests

Test files live in `tests/` and follow the naming convention `test_<NN>_<description>.psm` (e.g., `test_17_string_runtime.psm`). Use the next available number when adding a new test.

Each test should:

- Be self-contained — compile and run without external dependencies beyond `utils.psm`
- Exit with code `0` on success (the runner treats any non-zero exit as a failure)
- Cover a single, clearly scoped language behavior
- Have a descriptive filename that makes the tested feature obvious

---

## Commit Messages

Prismio follows [Conventional Commits](https://www.conventionalcommits.org/). Each commit message should have the form:

```
<type>(<scope>): <short description>
```

**Common types:**

| Type       | When to use                                           |
|------------|-------------------------------------------------------|
| `feat`     | A new language feature or compiler capability         |
| `fix`      | A bug fix in the compiler, parser, or IR generator    |
| `test`     | Adding or updating test cases                         |
| `docs`     | Documentation changes only                           |
| `refactor` | Code restructuring with no behavior change            |
| `chore`    | Build scripts, CI, tooling, or dependency updates     |
| `perf`     | Performance improvements                              |

**Scope** (optional) refers to the compiler component: `lexer`, `parser`, `ir`, `ast`, `bridge`, `runtime`, `tests`, etc.

**Examples:**

```
feat(parser): add support for match expression syntax
fix(ir): correct pointer offset calculation for struct fields
test: add test_18 for nested struct access
docs: clarify bootstrap build steps in README
chore(ci): add Windows runner to test workflow
```

Keep the subject line under 72 characters. Use the commit body (separated by a blank line) for context, motivation, or notes on breaking changes.

---

## Pull Request Guidelines

- **Target `main`** — all PRs should be opened against the `main` branch.
- **Keep PRs focused** — one feature or fix per PR makes review faster and history cleaner.
- **Write a clear description** — explain what the change does, why it is needed, and how it was tested.
- **Link related issues** — reference any relevant GitHub issues using `Closes #<number>` or `Relates to #<number>` in the PR description.
- **Ensure tests pass** — run `prismio gate` locally (or at least `prismio suite`) and confirm everything is green before requesting review.
- **Respond to review feedback** — address review comments with follow-up commits or discussion; do not force-push a branch after review has started without discussion.

PRs that add new language behavior without accompanying tests are unlikely to be merged.

---

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/). By participating, you are expected to uphold this standard. Please report unacceptable behavior to the project maintainers.
