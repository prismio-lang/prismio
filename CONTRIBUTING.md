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

| Dependency | Version | Notes                                        |
|------------|---------|----------------------------------------------|
| Prismio    | Latest  | Includes the LLVM toolchain and runtime      |
| Python     | 3.8+    | Required for the test runner (`test_runner.py`) |

Make sure `prismio` is installed and available on your system `PATH` before contributing.

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
│   ├── main.psm          # Entry point, import resolver
│   ├── lexer.psm         # Tokenizer
│   ├── token.psm         # Token type definitions
│   ├── keywords.psm      # Keyword definitions
│   ├── parser.psm        # Parser (declarations, statements, expressions)
│   ├── ast.psm           # AST node definitions
│   ├── sema.psm          # Semantic analysis (type checking, move/borrow/drop)
│   ├── types.psm         # Type system
│   ├── ir.psm            # IR generator (AST → LLVM IR)
│   ├── diag.psm          # extern fn declarations for the diagnostics engine
│   ├── bridge.psm        # extern fn declarations for the LLVM C API backend
│   └── utils.psm         # Shared utilities
├── tests/
│   ├── test_runner.py    # Python test runner
│   ├── test_*.psm        # Language test cases (positive)
│   ├── neg_*.psm         # Language test cases (expected to fail compilation)
│   └── utils.psm         # Shared test utilities
└── runtime/               # Runtime library
```

The compiler runs a dedicated semantic analysis pass (`src/sema.psm`) between parsing and IR
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
cd tests
python test_runner.py
```

The runner resolves `prismio` from your system `PATH` (via `find_prismio_exe()` in `test_runner.py`). To test against a **local build** instead, put that build first on `PATH` for the session, e.g. `PATH="/path/to/local/build:$PATH" python test_runner.py`.

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
