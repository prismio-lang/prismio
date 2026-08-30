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
   -> model/lowering.psm
   -> UmsProjectModel
   -> model/validation.psm
   -> builder/build_plan.psm
   -> compiler entry/output pairs
```

The parser AST is intentionally generic: assignments, calls, arguments, and
nested blocks. New DSL sections can be parsed before the semantic model learns
their meaning, and unknown schema elements receive semantic diagnostics rather
than requiring lexer/parser changes.

Tokens and AST block nodes retain byte offsets in addition to diagnostic line
and column coordinates. `model/manifest_writer.psm` uses those offsets for
minimal source edits. It does not serialize `UmsProjectModel`, because doing so
would erase comments and formatting that have no semantic-model representation.

### The compiler executes; UMS orchestrates

`src/main.psm` contains a thin `buildUmsProject` adapter. UMS owns discovery,
manifest interpretation, validation, target enumeration, and artifact paths.
The adapter calls the existing `compileSource` for each planned executable, so
UMS does not duplicate lexing, semantic analysis, AIF, LLVM generation, or
native linking.

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
  workspace facade, and token-preserving manifest edits
- `targets/`: executable, test, library, and self-hosted compiler target kinds,
  plus target lookup
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
- Debug and release profiles are CLI inputs; profile blocks are not parsed yet.
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
