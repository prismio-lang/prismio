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
- build plans rooted at `.prismio/build/<profile>/`;
- project-mode integration for `init`, `build`, `run`, `test`, and `clean`; and
- project-defined commands composed of build, run, and shell steps.

## Manifest syntax

```ums
project {
    name = "http"
    version = "1.0.0"
    prismio = "1.0"
    description = "HTTP client library"
    license = "MIT"
    authors = [
        "Saksham Jaiswal"
    ]
}

targets {
    executable("http") {
        entry = "src/main.psm"
    }
}

dependencies {
    implementation("json", "1.2.0")
}

commands {
    command("dist") {
        description = "Package a release archive"
        build("http")
        run("tools/package.py", "--out", "dist", args)
    }
}
```

Statements do not require semicolons, although semicolons are accepted. UMS
accepts `//` and `#` line comments. Strings support `\\`, `\"`, `\n`, `\r`, and
`\t` escapes. Assignments may also use flat arrays of scalar values; a trailing
comma is accepted.

Supported top-level blocks and declarations are:

- `toolchain { host = ".prismio/build/debug/compiler" }` (optional; when
  present it must be the first block so an older global compiler can read this
  stable prefix without parsing the remaining manifest)
- `project { name = "..."; version = "..."; prismio = "..." }`
- optional project metadata: `description = "..."`, `license = "MIT"`, and
  `authors = ["Name", "Another Name"]`
- `licenseFile = "LICENSE"` as a project-relative alternative to `license`;
  the two fields are mutually exclusive
- `targets { executable("name") { entry = "..." } }`
- `targets { library("name") { entry = "..." } }` (modeled and validated, but
  library artifact emission is not implemented yet)
- `targets { test("name") { entry = "..." } }`
- `link { library("sqlite3") }` (passes `-lsqlite3`)
- `link { search("native/lib") }` (a project-root-relative native search path)
- `link { file("native/libcodec.a") }` (an exact project-root-relative object or library)
- `link { framework("Security") }` (Mach-O targets only)
- `link { component("prismio.backend") }` (the local Prismio backend plus LLVM)
- `dependencies { implementation("name", "constraint") }`
- `dependencies { implementation("name", "constraint", "../local-path") }`
- `dependencies { api("name", "constraint") }`
- `dependencies { testImplementation("name", "constraint") }`
- `commands { command("name") { ... } }`

Local-path dependencies resolve against the directory containing `build.ums`.
Registry-shaped dependencies are represented and locked, but report `UMS2211`
because no registry exists yet.

`license` accepts a non-empty SPDX-shaped expression. The manifest validator
checks its structure; a future package registry owns validation against its
versioned SPDX identifier catalogue. Authors and descriptions must not be empty.
`prismio init` keeps its generated manifest minimal and does not write empty
metadata placeholders.

## Project commands

A `commands` block declares commands the project owns. Each is a name, an
optional `description`, and one or more steps run in declaration order; the
command stops at the first step that fails.

```ums
commands {
    command("dist") {
        description = "Package a release archive"
        build("http")
        run("tools/package.py", "--out", "dist", args)
    }
}
```

Two step forms.

**`build("target")`** builds a declared target, and takes nothing else.

**`run(subject, "arg", ...)`** runs one thing, and works out how from the
subject:

| Subject | What happens |
|---|---|
| a declared target | it is built, then executed |
| a `.py` file | run under this host's Python (`python` on Windows, `python3` elsewhere) |
| a `.psm` file | compiled into the profile's build directory, then executed |

Anything else is a manifest error rather than a guess, because the toolchain has
to know how to start what it is given. A `.psm` tool is not a declared target and
deliberately does not become one: a target is something the project builds every
time, a tool is something it runs when asked.

**`shell("program", "arg", ...)`** is the escape hatch, and you own its
portability. A program written with a path separator resolves against the project
root; a bare name is left to `PATH`. Reach for it when `run` cannot help -- `git`,
`clang`, a platform-specific script -- and remember that a `.sh` step is a broken
step on Windows, where the line is handed to `cmd /S /C`.

Every argument of every step is quoted for the platform's shell, so an argument
containing spaces or metacharacters stays one argument. The bare word `args`
splices in whatever the user typed after the command name, keeping its position
among the fixed arguments; it is the only identifier a step argument accepts.

`--release` among those arguments selects the profile the command's build steps
use, and is still forwarded, so one flag reaches both halves of
`prismio dist --release`.

A `build` step may not name the `toolchain.host` target. Rebuilding the host
stages a candidate the global parent promotes only after the process exits, so
every later step in the command would still run the previous compiler while
reading as though it ran the new one. `prismio build` is how the host is
rebuilt.

Built-in commands win. A manifest that names one of `init`, `build`, `run`,
`test`, `clean`, `check`, `bootstrap`, `aif`, `dump-ast` or `runtime-hash` is
rejected when it loads (`P1062`), rather than silently declaring a command
that could never be dispatched. Which names are reserved is CLI policy and lives in
`src/main.psm`; UMS validates a command's shape and does not know the verb list.

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
prismio <command> [args...]
```

UMS finds the nearest ancestor `build.ums`, validates it, creates a build plan,
and hands each planned entry/output pair to the existing compiler pipeline.
Artifacts are written below `.prismio/build/<profile>/`. The legacy
explicit-source form remains available:

```text
prismio build src/main.psm -o app
```

`toolchain.host` creates a two-layer command boundary. Global `prismio` reads
only that stable first block. If the project-relative host is absent or cannot
start, global Prismio processes the command itself; otherwise it forwards the
original argument vector and working directory, and the host parses the full
manifest. A hosted failure is returned directly and is never replayed globally.

When the executable whose planned output equals `toolchain.host` rebuilds the
running host, it writes a checked `.next` sibling. The global parent promotes
that candidate only after the hosted process exits, which works on Windows and
preserves the last known-good compiler. Host identity comes from the configured
path, not from a special target kind; that executable must link
`component("prismio.backend")`.
`clean` follows the same ownership rule: the host plans the clean, then its
global parent removes the running host after it exits.

See [ARCHITECTURE.md](ARCHITECTURE.md) for subsystem boundaries and extension
points.
