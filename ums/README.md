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
- project-defined commands composed of build, run, and shell steps;
- `const` and `enum` declarations with `${NAME}` interpolation, resolved before lowering; and
- `import build`, the manifest's `project` values as a module the compiler writes in memory.

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
  stable prefix without parsing the remaining manifest). The path is relative
  to the manifest, or absolute, and may name another project's host -- a
  sub-project can use `../.prismio/build/debug/prismio`. Only a host under the
  project's own `.prismio/` is removed by `clean`. Write it without an extension: on
  Windows the host, like every executable and test target, is built as
  `<name>.exe`, and the path is resolved to match
- `project { name = "..."; version = "..."; prismio = "..." }`
- optional project metadata: `description = "..."`, `license = "MIT"`, and
  `authors = ["Name", "Another Name"]`
- `licenseFile = "LICENSE"` as a project-relative alternative to `license`;
  the two fields are mutually exclusive
- `targets { executable("name") { entry = "..." } }`
- `targets { library("name") { entry = "..." } }` (modeled and validated, but
  library artifact emission is not implemented yet)
- `targets { test("name") { entry = "..." } }`
- in a target, `runtime = "installed"` (the default: the Prismio runtime the
  toolchain ships is merged into the program) or `runtime = "none"` (the
  target's native sources provide every runtime symbol themselves)
- in a target, `exportDynamic = true` (the executable's symbols are visible to
  code it loads at run time, such as a JIT-compiled module)
- `native { source("c/codec.c", "c/util.c") }` (C files compiled with the
  toolchain's clang at `-O2`, `-g` in a profile with debug info, and linked in
  declaration order)
- `native { include("c/include") }`, `native { define("NAME=1") }`,
  `native { flag("-Wall") }` and `native { responseFile("flags.rsp") }` (the
  flags every native source compiles with)
- `link { library("sqlite3") }` (passes `-lsqlite3`)
- `link { search("native/lib") }` (a project-root-relative native search path)
- `link { file("native/libcodec.a") }` (an exact project-root-relative object or library)
- `link { framework("Security") }` (Mach-O targets only)
- `link { responseFile("link.rsp") }` (linker arguments from a file another
  tool wrote, as `pkg-config` or `tools/setup_llvm.py` would)
- `profiles { debug { debugInfo = false } release { overflowChecks = true } }`
  (the `debug` profile builds with `-g` and overflow checks, `release` with
  neither; a block changes that for its profile)
- `dependencies { implementation("name", "constraint") }`
- `dependencies { implementation("name", "constraint", "../local-path") }`
- `dependencies { api("name", "constraint") }`
- `dependencies { testImplementation("name", "constraint") }`
- `commands { command("name") { ... } }`

Local-path dependencies resolve against the directory containing `build.ums`,
and `prismio.lock` is written beside it, with paths relative to it, whenever
the project declares a dependency. Registry-shaped dependencies are represented
and locked, but report `UMS2211` because no registry exists yet; a resolved path
dependency is not yet on the import search, which `P1081` says.

Nothing about a target is built into the toolchain. The Prismio compiler is an
ordinary executable in this repository's `build.ums`: its C runtime and backend
are its `native` sources, it declares `runtime = "none"` because it carries the
checkout's runtime, and it links LLVM through the response files
`tools/setup_llvm.py` writes.

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
| a `.py` file | run under this host's Python (`py -3` on Windows when the launcher is installed, else `python`; `python3` elsewhere) |
| a `.psm` file | compiled into the profile's `tools/` directory, then executed |

Anything else is a manifest error rather than a guess, because the toolchain has
to know how to start what it is given. A `.psm` tool is not a declared target and
deliberately does not become one: a target is something the project builds every
time, a tool is something it runs when asked.

**`shell("program", "arg", ...)`** starts any program, and you own its
portability. A program written with a path separator resolves against the project
root; a bare name is looked up on `PATH`. Reach for it when `run` cannot help --
`git`, `clang`, a platform-specific script. Despite the name, no shell is
involved: a shell builtin needs the shell named, `shell("cmd", "/c", "dir")` or
`shell("sh", "-c", "...")`, and a `.sh` script needs `sh` on Windows.

No step goes through a shell. Each argument is one element of the program's
argument vector, so `$(...)`, backticks, quotes and a trailing backslash reach
it exactly as written. Every step starts in the project root, whatever directory
the command was run from, because the manifest's relative paths were written
relative to it. A step that fails ends the command with that step's exit
status. The bare word `args` splices in whatever the user typed after the
command name, keeping its position among the fixed arguments; it is the only
identifier a step argument accepts.

`--release` among those arguments selects the profile the command's build steps
use, and is still forwarded, so one flag reaches both halves of
`prismio dist --release`.

A `build` step may not name the `toolchain.host` target. Rebuilding the host
stages a candidate the global parent promotes only after the process exits, so
every later step in the command would still run the previous compiler while
reading as though it ran the new one. `prismio build` is how the host is
rebuilt.

Built-in commands win. A manifest that names one of `init`, `build`, `run`,
`test`, `clean`, `check`, `bootstrap`, `aif`, `dump-ast` or `runtime-hash`, or a
name ending `.psm`, is rejected when it loads (`P1062`), rather than silently
declaring a command that could never be dispatched. Which names are reserved is
CLI policy and lives in `src/project/commands.psm`; UMS validates a command's
shape and does not know the verb list. A command name starts with a letter or a
digit, so a flag can never be one.

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
prismio build [--release] [target...]
prismio run [--release] [target] [-- program-args...]
prismio test [--release] [test...]
prismio clean [--release]
prismio <command> [args...]
```

`run` exits with the program's own status. A word that does not end in `.psm`
names a target, so `prismio build server` builds the target called `server`.

UMS finds the nearest ancestor `build.ums`, validates it, creates a build plan,
and hands each planned entry/output pair to the existing compiler pipeline.
Artifacts are written below `.prismio/build/<profile>/`. The legacy
explicit-source form remains available:

```text
prismio build src/main.psm -o app
```

`toolchain.host` creates a two-layer command boundary. Global `prismio` reads
only that stable first block. It runs the host only if this machine promoted it:
promotion writes `<host>.trusted` with the file's identity (device, inode, size,
modification time), and a host that does not match -- one a cloned repository
brought with it, or one edited after promotion -- is never started, for any
command (`P1077`). If the host is absent, untrusted or cannot start, global
Prismio processes the command itself; otherwise it forwards the original
argument vector and working directory, and the host parses the full manifest. A
hosted failure is returned directly, with the host's exit status, and is never
replayed globally.

When the executable whose planned output equals `toolchain.host` rebuilds the
running host, it writes a checked `.next` sibling. The global parent promotes
that candidate only after the hosted process exits, which works on Windows and
preserves the last known-good compiler. Host identity comes from the configured
path, not from a special target kind or anything built into the toolchain.
`clean` follows the same ownership rule: the host plans the clean, then its
global parent removes the running host after it exits.

See [ARCHITECTURE.md](ARCHITECTURE.md) for subsystem boundaries and extension
points.
