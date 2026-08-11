# Unified Manifest System (UMS)

UMS is Prismio's project manifest and build-orchestration subsystem. It is
self-hosted Prismio code and deliberately lives at the repository root, beside
the compiler rather than inside `src/`.

The initial implementation provides:

- upward `build.ums` discovery;
- a dedicated lexer and recoverable parser;
- a generic DSL AST followed by semantic lowering;
- separate project metadata and build configuration models;
- executable and library target models;
- implementation, API, and test dependency models;
- validation with stable `UMSxxxx` diagnostic codes;
- build plans rooted at `.prismio/build/<profile>/`; and
- `prismio build` project-mode integration for executable targets.

## Manifest syntax

```ums
project {
    name = "http"
    version = "1.0.0"
    prismio = "1.0"
}

targets {
    executable("http") {
        entry = "src/main.psm"
    }
}

dependencies {
    implementation("json", "1.2.0")
}
```

Statements do not require semicolons, although semicolons are accepted. UMS
accepts `//` and `#` line comments. Strings support `\\`, `\"`, `\n`, `\r`, and
`\t` escapes.

Supported top-level blocks and declarations are:

- `project { name = "..."; version = "..."; prismio = "..." }`
- `targets { executable("name") { entry = "..." } }`
- `targets { library("name") { entry = "..." } }` (modeled and validated, but
  library artifact emission is not implemented yet)
- `dependencies { implementation("name", "constraint") }`
- `dependencies { api("name", "constraint") }`
- `dependencies { testImplementation("name", "constraint") }`

Dependency declarations are represented in the project model but are not yet
resolved or downloaded.

## CLI behavior

From a project directory or any descendant:

```text
prismio build
```

UMS finds the nearest ancestor `build.ums`, validates it, creates a build plan,
and hands each executable entry/output pair to the existing compiler pipeline.
Artifacts are written below `.prismio/build/debug/`. The legacy explicit-source
form remains available:

```text
prismio build src/main.psm -o app
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for subsystem boundaries and extension
points.
