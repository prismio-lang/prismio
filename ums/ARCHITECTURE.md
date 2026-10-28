# UMS architecture

## Decisions

### UMS is native Prismio and top-level

All manifest policy and domain logic is implemented in `.psm`. UMS does not
reuse the Prismio language parser because `build.ums` is a smaller,
forward-extensible project DSL with different recovery and validation needs.
It also does not live under compiler `src/`.

The compiler reserves the `ums` import root for this sibling subsystem. This is
the only compiler-facing source-layout rule; ordinary project imports retain
their existing entry-root behavior.

The sole new C surface is `current_directory()`. Reading the process working
directory is an OS capability, so `runtime/program_support.c` exposes it as an
allocated Prismio `String`. Discovery traversal and every decision made with
that value remain native Prismio.

### Syntax and semantics are separate phases

```text
build.ums
   -> parser/lexer.psm
   -> parser/parser.psm
   -> UmsAstDocument
   -> model/constants.psm      (const / enum resolved away)
   -> model/lowering.psm
   -> UmsProjectModel
   -> model/validation.psm
   -> builder/build_plan.psm
   -> compiler entry/output pairs
```

The parser AST is intentionally generic: assignments, scalar values, flat
scalar arrays, calls, arguments, and nested blocks. New DSL sections can be
parsed before the semantic model learns their meaning, and unknown schema
elements receive semantic diagnostics rather than requiring lexer/parser
changes.

Tokens and AST block nodes retain byte offsets in addition to diagnostic line
and column coordinates. `model/manifest_writer.psm` uses those offsets for
minimal source edits. It does not serialize `UmsProjectModel`, because doing so
would erase comments and formatting that have no semantic-model representation.

### Constants are resolved away, and the manifest is a module

`const` and `enum` are parsed into the same generic AST (two new statement kinds) and
removed by `model/constants.psm` before lowering: every use is replaced by a value and the
declarations leave the document's roots, so lowering, validation and the build plan are
unchanged and a new place that takes a value needs no constants code. A declaration sees
only those above it (no cycles to detect); a use sees all. `toolchain` takes literals,
because the launcher's prefix reader runs before any of this.

Code reads the manifest through `import build`. The compiler's import loader asks
`umsLoadBuildModule` for the module's text and parses it as it would a file's, so the module
is never on disk and never stale. The values are globals (`BUILD_VERSION`), spelled like
`PRISMIO_VERSION`: a global cannot be reached through a module name, and a property may not
return a `String`, so `build.version` is not expressible without a language change.

### The compiler executes; UMS orchestrates

`src/project/` is the adapter, in three parts: `ums_cli.psm` for the project
verbs, `host.psm` for routing to a project's own compiler, and `commands.psm`
for running a declared command. UMS owns discovery, manifest interpretation,
validation, target enumeration, and artifact paths. The adapter hands each
planned target's native inputs to the driver and calls the existing
`compileSource` with a `CompileOptions` built from the selected profile, so UMS
does not duplicate lexing, semantic analysis, AIF, LLVM generation, or native
linking.

### Host selection is a stable prefix

An optional `toolchain` block must be the first manifest block. The global
launcher scans only that finite prefix for a project-relative `host`; it does
not lex or lower the remaining manifest. If the host exists and starts, the
launcher forwards the original arguments and working directory. The host owns
the full UMS parse and command, so it may extend UMS independently of the older
global compiler. Without a usable host, global Prismio is stage 0 and processes
the manifest itself.

"Exists and starts" is not enough, because a host from an earlier toolchain
generation does both. What it cannot do is build: the code it emits names
runtime symbols the installed runtime has since stopped defining, and that
arrives as a linker's undefined-symbol list naming *generated* functions, with
nothing in it pointing at the compiler that emitted them. So the launcher also
asks. `prismio --internal-host-abi <token>` is hidden, takes the asking
compiler's own `PRISMIO_HOST_ABI` (`runtime/prismio_runtime.h`), and exits 0
only on agreement — a compiler predating the command rejects the argument and
exits 1, which is the same answer. On disagreement the launcher rebuilds *only*
the `toolchain.host` target with itself, re-asks, and then forwards the original
command to the promoted host; `P1064` reports that it did. `clean` is exempt,
because the launcher deletes that host immediately afterwards.

The launcher remains alive while the executable at `toolchain.host` builds its
`.next` sibling. It validates and promotes that candidate after the host exits. The
same split lets `clean` remove a running Windows compiler only after its process
has ended. A hosted command failure is returned directly and is never replayed.

Before any of that, the launcher asks whether this machine promoted the host.
Promotion writes `<host>.trusted` holding the file's identity -- device, inode,
size and modification time -- and a host whose identity does not match is never
started, because starting it is running whatever the project put there: the
probes run it too, and an editor's `check` reaches the launcher when a file is
opened. `toolchain.host` must also name a path under `.prismio/`, which a
checkout does not carry.

Artifact kind does not encode linkage, and nothing about a target is built into
the toolchain. `executable`, `test`, and the future `library` describe outputs;
a target's `native` block names the C it compiles (sources, include
directories, defines, flags, response files), its ordered `link` inputs name
what it links, `runtime` says whether the installed runtime is merged in, and
`exportDynamic` whether its symbols are visible to code it loads. The Prismio
compiler is one such target. There used to be a `component("prismio.backend")`
that selected a backend bundle every shipped compiler knew how to build; it is
gone, and the compiler's build.ums names those sources instead. Host promotion
is selected only by matching the planned output to `toolchain.host`.

### A command is manifest data; which names are free is not

`commands` needed no lexer or parser change, which is the generic AST paying for
itself: a command is a named block of calls, and calls with arguments are what
the parser already produces. Lowering, validation, and a dispatch hook were the
whole change.

The reserved-name rule is deliberately *not* here. UMS validates a command's
shape -- the name is well formed, the steps resolve, a `run` step names
something executable. Which names are still available is CLI policy, so
`src/main.psm` owns the list and reports `P1058`. UMS embedded by another
Prismio tool would have a different verb list and the same manifest rules.

Steps run in declaration order and stop at the first failure. `run` resolves its
subject -- a declared target, a `.py`, or a `.psm` -- rather than offering three
step kinds, because the manifest author's question is "run this", not "which
launcher does this need". Anything the toolchain cannot start is a manifest error
rather than a guess, and `shell` remains for the cases it genuinely cannot: there
is no portable way to start a `.sh`, which is why the project's own tools are
Python. A `build` step may
not name the `toolchain.host` target: the rebuilt host is promoted by the global
parent only after this process exits, so later steps would still be running the
previous compiler. That is `P1061`, and it is checked at execution rather than
in validation because host identity is a comparison against the planned output
path, which the build plan produces after validation has run.

### Generated state is project-local and isolated

`UmsBuildConfiguration` defaults to:

```text
.prismio/
  build/
    <profile>/
      <target artifact>
```

`.prismio/` is ignored by Git. Future object, metadata, and fingerprint stores
belong under this state root. Downloaded packages and shared artifacts do not;
they will use the platform-appropriate global Prismio cache.

## Module boundaries

- `parser/`: token vocabulary, DSL lexer, generic AST, recoverable parser
- `model/`: diagnostics, metadata/build models, AST lowering, validation,
  workspace facade, stable host-prefix selection, and token-preserving manifest
  edits
- `targets/`: executable, test, and library target kinds; ordered native link
  inputs and target lookup
- `commands/`: project command, step, and argument models, and command lookup
- `dependency/`: dependency scopes, local-path resolution, and lockfile output
- `resolver/`: upward manifest discovery
- `builder/`: deterministic build-plan and artifact-path construction
- `tests/`: manifest fixtures; `test_ums.psm` is the native subsystem test

## Incremental-build extension seam

The build plan already centralizes state and artifact roots. The next builder
layer should turn each target into build units carrying input hashes, compiler
identity, target triple, profile, dependency graph hash, and output metadata.
Fingerprints should be persisted below `.prismio/build/fingerprints/`; objects
and build metadata should use sibling directories. None of those concerns
belong in the parser or project metadata.

## Current limitations

- Only executable artifacts are emitted. Library declarations produce a clear
  validation diagnostic.
- Local-path dependencies resolve and all dependencies are written to a
  lockfile, but resolved sources are not added to import search or linked.
  Registry dependencies still have no fetch implementation.
- Profiles are `debug` and `release` only, and a `profiles` block sets two
  things for each: `debugInfo` and `overflowChecks`.
- Native sources are C only; a C++ source would need its runtime library
  linked, which nothing declares yet.
- Manifest edits exist as a tested source transformation, but no dependency CLI
  command writes the returned text to `build.ums` yet.
- Target selection, target triples in manifests, incremental fingerprints,
  package registries, publishing, and global caches are deferred.
- The declared Prismio version is syntax-validated but compatibility selection
  is not yet enforced.

## Next implementation sequence

1. Put a dependency CLI in front of the manifest writer, with a replacement
   strategy that cannot leave a partial `build.ums` behind.
2. Add resolved local dependency roots to module search through an explicit
   compiler capability interface.
3. Introduce fingerprint/build-unit models and no-op detection.
4. Add library emission and dependency linkage through the same capability
   interface.
5. Add target-selection and target-triple inputs without moving build policy
   into project metadata.
6. Define the registry and global-cache protocols before implementing a fetch.
