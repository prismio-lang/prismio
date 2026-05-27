# UMS (Unified Make System)

UMS is a lightweight build orchestration tool for Prismio projects. It is intentionally not a general-purpose scripting language.

The first implementation reads `build.ums` from the current directory and supports:

- `ums build`
- `ums run`
- automatic invocation of `prismio.exe`
- a config shape that leaves room for packages, external C sources, and multi-module builds

Current recognized calls:

- `prismio("path-or-command")`
- `source("src/main.psm")`
- `output("build/app.exe")`
- `args("--example")`

Unknown blocks such as `packages`, `cSources`, and extra `module` declarations are reserved for later expansion.
