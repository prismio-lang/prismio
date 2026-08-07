<p align="center">
  <img src="https://www.prismio.org/icons/prismio-banner.png" width="140" alt="Prismio"/>
</p>

<br/>

<div align="center">

[![License](https://img.shields.io/badge/license-Apache%202.0-6C63FF?style=for-the-badge&logoColor=white)](LICENSE)
[![LLVM](https://img.shields.io/badge/backend-LLVM%2022-6C63FF?style=for-the-badge&logoColor=white)]()
[![Status](https://img.shields.io/badge/status-active%20development-6C63FF?style=for-the-badge&logoColor=white)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-6C63FF?style=for-the-badge&logoColor=white)](CONTRIBUTING.md)

**A statically typed, compiled systems language. The compiler is written in Prismio.**

[Website](https://prismio.org) · [Documentation](https://docs.prismio.org/) · [Contributing](CONTRIBUTING.md) · [Issues](https://github.com/prismio-lang/prismio/issues)

</div>

---

## Overview

Prismio is an open-source systems programming language that compiles to native machine code via LLVM IR. The compiler — including the lexer, parser, AST, import resolver, and IR generator — is written in Prismio itself.

This repository contains the Prismio source files that constitute the compiler. A prebuilt bootstrap binary is used to compile them during toolchain setup; contributors do not write or modify C++.

The language has no garbage collector and no implicit runtime. All allocations are explicit. The C ABI is the foreign function interface — any C function is callable via an `extern fn` declaration with no additional tooling.

### Design Principles

- **Explicit over implicit** — mutability, types, and allocation are always visible at the call site
- **C ABI as the FFI** — no bindings layer, no marshalling, no overhead
- **Self-hosting as a design constraint** — the language must be expressive enough to implement its own compiler
- **LLVM as the backend** — no custom codegen; full access to LLVM's optimization passes and target support

---

Platform-specific contributions and CI configuration are welcome. See [Contributing](#contributing).

---

## Language

The language includes:
- explicit mutability (`let` / `let mut`)
- nominal type semantics
- structs and enums
- module imports
- C ABI interoperability
- control flow primitives
- arrays and string operations
- progressively self-hosted compiler infrastructure

The README intentionally avoids embedding extensive language examples or syntax documentation. The full language reference, compiler behavior, type system details, runtime APIs, and architecture documentation are maintained on the official documentation site.

---

## Architecture

### Compiler Pipeline

```
Source (.psm)
     │
     ▼
  Lexer                   ← src/lexer/
     │  Token stream
     ▼
  Parser                  ← src/parse/
     │  Untyped AST
     ▼
  Import Resolver         ← src/main.psm
     │  Flattens transitive imports into a single module AST
     ▼
  Semantic Analysis       ← src/sema/
     │  Type checking + move/borrow/drop ownership enforcement
     ▼
  Allocation Inference    ← src/aif/
     │  Assigns every allocation site a tier; drives what codegen emits
     ▼
  IR Generator            ← src/ir/
     │  AST walk → LLVM IR, built through the LLVM C API
     ▼
  llvm-llc
     │  Object file (.obj / .o)
     ▼
  Clang
     │  Links with the runtime (embedded in the compiler binary; see runtime/)
     ▼
  Native binary
```

IR is built through the LLVM C API by `runtime/llvm-api-backend.c`. The compiler calls into it
exclusively via the `extern fn` declarations in `src/ir/bridge.psm`, so the Prismio source has no
direct LLVM dependency of its own and a second backend can be linked in its place.

### Source layout

Each stage of the pipeline is a directory, and a module's path is its import path — `src/ir/expr.psm`
is `import ir.expr`, and `import ir.*` takes the whole package.

| Directory | Contents |
|---|---|
| `src/common/` | String and character primitives; the diagnostics FFI |
| `src/lexer/` | The token vocabulary and the scanner |
| `src/ast/` | Node and type representations, plus the AST dump used by the AIF oracle |
| `src/parse/` | Declarations, statements, expressions, and the parser itself |
| `src/sema/` | Type checking, overload resolution, ownership enforcement, control-flow analysis |
| `src/aif/` | Allocation inference: the model, the walk, layout, and reporting |
| `src/ir/` | Type lowering, expression and statement emission, and the LLVM bridge |
| `src/main.psm` | CLI, import resolution, and the build driver |

For a full breakdown of compiler internals, see [Architecture](https://docs.prismio.org/architecture)

---

## Getting Started

### Prerequisites

| Dependency | Version | Notes |
|---|---|---|
 Prismio | Latest | Includes LLVM toolchain and runtime |
| Python | 3.8+ | Test runner utilities |

### Using a Local Compiler Build

By default, the test runner resolves `prismio` from the system `PATH` (via `find_prismio_exe()`
in `test_runner.py`).

To verify changes against a local compiler build, put that build first on `PATH` for the session,
e.g. `PATH="/path/to/local/build:$PATH" python test_runner.py`.

### Run the Test Suite

```bash
cd tests
python test_runner.py
```

---

## Contributing

Contributions are welcome. All compiler work is done in Prismio — contributors do not need to touch C++. The most impactful work right now is infrastructure, correctness, and platform coverage.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contribution guide. This project follows the [Contributor Covenant](https://www.contributor-covenant.org/).

---

## License

Apache License 2.0. See [LICENSE](LICENSE).
