<p align="center">
  <img src="https://www.prismio.org/icons/prismio-banner.png" width="80" alt="Prismio"/>
</p>

<br/>

<div align="center">

[![License](https://img.shields.io/badge/license-Apache%202.0-6C63FF?style=for-the-badge&logoColor=white)](LICENSE)
[![LLVM](https://img.shields.io/badge/backend-LLVM%2018-6C63FF?style=for-the-badge&logoColor=white)]()
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
  Lexer                   ← src/lexer.psm
     │  Token stream
     ▼
  Parser                  ← src/parser.psm
     │  Untyped AST
     ▼
  Import Resolver         ← src/main.psm
     │  Flattens transitive imports into a single module AST
     ▼
  IR Generator            ← src/ir.psm
     │  AST walk → LLVM IR text (.ll)
     │  Delegates emission to llvm-bridge (C, via extern fn)
     ▼
  llvm-llc
     │  Object file (.obj / .o)
     ▼
  Clang
     │  Links with runtime.c
     ▼
  Native binary
```

IR emission is handled by `llvm-bridge.c` — a C library that constructs LLVM IR as formatted text. The compiler calls into it exclusively via `extern fn` declarations in `src/bridge.psm`. There is no direct LLVM API dependency in the Prismio source.

The compiler currently performs no semantic analysis pass between parsing and IR generation. Type information is resolved structurally during the IR walk. A dedicated analysis phase is planned.

For a full breakdown of compiler internals, see [Architecture](https://docs.prismio.org/architecture)

---

## Getting Started

### Prerequisites

| Dependency | Version | Notes |
|---|---|---|
 Prismio | Latest | Includes LLVM toolchain and runtime |
| Python | 3.8+ | Test runner utilities |

### Using a Local Compiler Build

By default, the test runner resolves `prismio` from the system `PATH`.

To verify changes against a local compiler build, update the `prismio`
path at **Line: 18** inside `test_runner.py` before running the test suite.

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
