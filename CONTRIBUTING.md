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

Prismio is a self-hosted systems programming language. The compiler — including the lexer, parser, AST, import resolver, and IR generator — is written in Prismio itself. **Contributors do not need to write or modify C++.** All compiler work is done in `.psm` files under `src/`.

A prebuilt bootstrap binary is used to compile the Prismio source files during toolchain setup. The compiler pipeline produces LLVM IR, which is then compiled to native machine code via `llvm-llc` and linked by Clang.

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
| clang + LLVM | 22.x | On macOS this must be a Homebrew `llvm`, **not** Apple's bundled clang — the two disagree on IR version and the seed will not read |
| Python | 3.8+ | The test runner and the AIF differential |
| Prismio | any | Optional. You do not need an installed compiler — the committed seed builds the first one |

`python tools/setup_llvm.py` provisions an LLVM with the C API headers and records
where it went.

---

## Building the compiler

**This is the step that is easy to miss: editing `src/` and running the tests
proves nothing until you have built a compiler from your change.** The compiler
is written in itself, so a build always takes an existing compiler as input.

From a fresh checkout with no `prismio` anywhere:

```bash
tools/bootstrap.sh --seed --out build/gen0
```

`bootstrap/prismio-seed.ll` is committed LLVM IR for a compiler built from an
earlier tree. It is the only way out of the cycle on a host that has none.

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

The repository itself is a Prismio project. Once a local generation exists,
`build/gen2 build` reads the root `build.ums` and writes the compiler to
`.prismio/build/debug/prismio`. The bootstrap script remains necessary for the
generation chain because it is what creates the first local compiler and names
each self-host generation separately. Neither path uses a globally installed
`prismio`. The manifest declares a `compiler(...)` target rather than an
ordinary `executable(...)`, because the compiler also links the backend and
LLVM while application executables link only the runtime.

**Two generations before believing it.** A compiler that links may only have
linked because the *old* one built it; the second generation is the first one
built by your change. `cmp` failing means the two disagree about the compiler
they emit, which is a real bug even when every test passes.

Name generations explicitly. Do not rely on whichever `prismio` is first on
`PATH` — a stale one makes a bootstrap failure look nondeterministic.
`build/gen2 --version` prints the compiler directory and the standard library it
resolves, which is the fastest way to check you are running what you think.

### Before opening a pull request

```bash
bash tools/release_gate.sh --rc build/gen2
```

Fourteen gates in one command: source lists, two-generation bootstrap, IR
fixpoint, self-reproduction, seed agreement, the full suite, the AIF oracle
differential, the corpus, a `--verify` sweep, curated-runtime-off,
object-cache-off, JIT, cross-target, and the packaged toolchain.

### If you changed the syntax

New syntax lands in **two commits**, and the order is not negotiable: the
committed seed has to be able to parse `src/`, so teach the frontend first
without using the syntax in `src/`, then `tools/refresh_seed.sh --compiler
build/gen2`, and only then use it. Skipping this leaves a fresh clone unable to
build. See [CODE_STYLE.md](CODE_STYLE.md).

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

`tools/sanitizer_smoke.sh --compiler build/gen2` links representative ownership
and concurrency programs with AddressSanitizer. `tools/milestone_bench.py` runs
the interleaved milestone regression gate against an explicitly named baseline.

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
- **Ensure tests pass** — run `python test_runner.py` locally and confirm all tests pass before requesting review.
- **Respond to review feedback** — address review comments with follow-up commits or discussion; do not force-push a branch after review has started without discussion.

PRs that add new language behavior without accompanying tests are unlikely to be merged.

---

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/). By participating, you are expected to uphold this standard. Please report unacceptable behavior to the project maintainers.
