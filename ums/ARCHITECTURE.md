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
  workspace facade
- `targets/`: target kinds and target lookup
- `dependency/`: dependency scopes and declarations
- `resolver/`: upward manifest discovery; future dependency resolution belongs
  behind a separate resolver API
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
- Dependencies are modeled but not resolved, downloaded, or linked.
- Build profiles are an internal configuration value; profile blocks and CLI
  selection are not parsed yet.
- Project mode is integrated for `prismio build`; `run`, `test`, and `clean`
  still use their existing behavior or are not yet implemented.
- Target selection, target triples in manifests, incremental fingerprints,
  package registries, lockfiles, publishing, and global caches are deferred.
- The declared Prismio version is syntax-validated but compatibility selection
  is not yet enforced.

## Next implementation sequence

1. Add profile and target-selection inputs to `UmsBuildConfiguration` without
   moving them into project metadata.
2. Introduce fingerprint/build-unit models and no-op detection.
3. Define a dependency resolver interface plus lockfile model before choosing a
   registry protocol.
4. Add executable `run`, then test-target and clean orchestration against the
   same workspace/build-plan API.
5. Add library emission and dependency linkage through an explicit compiler
   capability interface.
6. Add target triples and platform-aware artifact naming.
