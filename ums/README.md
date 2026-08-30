# Unified Manifest System (UMS)

UMS is Prismio's project manifest and build-orchestration subsystem. It is
self-hosted Prismio code and deliberately lives at the repository root, beside
the compiler rather than inside `src/`.

The initial implementation provides:

- upward `build.ums` discovery;
- a dedicated lexer and recoverable parser;
- a generic DSL AST followed by semantic lowering;
- separate project metadata and build configuration models;
- executable, library, and test target models;
- implementation, API, and test dependency models;
- validation with stable `UMSxxxx` diagnostic codes;
- local-path dependency resolution and a versioned lockfile;
- token-preserving dependency edits for existing manifests;
- build plans rooted at `.prismio/build/<profile>/`; and
- project-mode integration for `init`, `build`, `run`, `test`, and `clean`.

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
- `targets { test("name") { entry = "..." } }`
- `targets { compiler("name") { entry = "..." } }` (a self-hosted compiler;
  links the compiler backend and LLVM in addition to the runtime)
- `dependencies { implementation("name", "constraint") }`
- `dependencies { implementation("name", "constraint", "../local-path") }`
- `dependencies { api("name", "constraint") }`
- `dependencies { testImplementation("name", "constraint") }`

Local-path dependencies resolve against the directory containing `build.ums`.
Registry-shaped dependencies are represented and locked, but report `UMS2211`
because no registry exists yet.

## Manifest edits

`umsManifestAddDependency` edits source text instead of serializing a project
model. Existing comments, whitespace, newline style, quoting, and declaration
order remain byte-for-byte unchanged; the writer inserts only one declaration,
or appends a `dependencies` block when none exists. It refuses malformed
manifests and duplicate declarations without changing the returned source.

The writer returns text plus a `changed` flag. It deliberately does not open or
overwrite `build.ums`; a future dependency CLI can validate the edit before it
chooses when and how to replace the file.

## CLI behavior

From a project directory or any descendant, UMS backs these commands:

```text
prismio init [name]
prismio build [--release]
prismio run [--release]
prismio test [--release]
prismio clean [--release]
```

UMS finds the nearest ancestor `build.ums`, validates it, creates a build plan,
and hands each planned entry/output pair to the existing compiler pipeline.
Artifacts are written below `.prismio/build/<profile>/`. The legacy
explicit-source form remains available:

```text
prismio build src/main.psm -o app
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for subsystem boundaries and extension
points.
