# Changelog

## Unreleased

### Language

- Generic parameters accept multiple trait bounds with `+`, such as
  `fn keep<T: Ord + Copy>(value: T) -> T`. Every bound is checked independently
  at instantiation, and diagnostics identify the requirement that failed.
- Trait conformance belongs to the exact `impl Trait for Type` block. An
  unrelated global or inherent method with the same signature can no longer
  satisfy an incomplete impl accidentally. `Map` now states its real
  `K: Key + Copy` requirement instead of relying on cross-impl conformance.
- Concrete trait implementations are coherent: a second `impl Trait for Type`
  is rejected at the later declaration with a note pointing to the first.
- Generic inherent impls are supported with structural targets, including
  `impl<T> Box<T>`, impl-level bounds, complete `Self` substitution, methods
  with additional type parameters, and concrete specializations such as
  `impl Box<Int>`. Unconstrained parameters and bare type-parameter targets are
  rejected. Generic methods sharing a name on different receiver constructors
  retain distinct demand-driven instantiations.
- Generic trait impls such as `impl<T: Bound> Trait for Box<T>` participate in
  bound satisfaction only when their structural target matches and every impl
  bound holds. Conformance is checked against the owning generic method
  templates, and coherence rejects overlapping generic/concrete targets while
  permitting provably disjoint concrete specializations.
- Traits may declare type parameters, as in `trait From<T>`. Structural trait
  applications such as `From<Int>` are supported in impls and bounds; their
  arguments participate in conformance, generic applicability, and coherence.
  Impl parameters may be constrained by the trait side (`impl<T> From<T> for
  String`), and arity mismatches receive declaration-directed diagnostics.

### Developer tooling

- The test runner accepts fixture stems or substrings, including repeatable
  `-k` filters, so one positive or negative test no longer requires a full
  suite run. `--list` prints the available fixtures.
- The compiler repository now has its own `build.ums`; `prismio build` treats
  the compiler as a normal Prismio project and writes the executable below
  `.prismio/build/<profile>/`. Seed bootstrapping remains an explicit toolchain
  operation because it is what creates the first local compiler.
- UMS keeps artifact shape separate from native linkage. Self-hosted Prismio is
  `executable("prismio")` with `component("prismio.backend")`; ordinary targets
  can declare ordered `library`, `search`, `file`, and Mach-O `framework`
  inputs without pretending to be compilers.
- Project metadata now supports optional descriptions, SPDX-shaped licenses,
  project-relative license files, and author lists. UMS array values are a
  reusable flat scalar syntax rather than an authors-only parser special case.
- An optional, first `toolchain { host = "..." }` block selects a project-local
  compiler. Global Prismio reads only that stable prefix, forwards the original
  command when the host is usable, and otherwise processes it as stage 0.
- `prismio aif <source>` now defaults to a source-oriented storage plan with
  numeric allocation IDs; `--why=<ID>` explains one decision and `--manifest`
  preserves the stable tier/symbol form used by compiler tooling and CI.
- `tools/format_sources.py` supplies a conservative repository formatter, and
  `tools/lint.py` checks formatting, Python and shell syntax, Prismio tabs,
  toolchain source-list agreement, and diagnostic-code integrity.
- Compiler errors and warnings now have stable `P####` identifiers in human and
  JSON diagnostics. CI asserts the protocol and rejects duplicate or uncoded
  call sites.
- Linux CI links ownership and concurrency fixtures under AddressSanitizer and
  runs the interleaved milestone benchmark as a regression gate.

### Project commands

`build.ums` is the project manifest, and the CLI now works off it the way
`cargo` works off `Cargo.toml`. A project command is the same command with no
source named: `prismio build` builds the project, `prismio build main.psm`
builds one file.

- **`prismio init [name]`** — scaffolds `build.ums`, `src/main.psm` and a
  `.gitignore` holding `.prismio/`, in this directory or a new one. One command
  rather than Cargo's `new` plus `init`: the only difference between them is
  whether a directory is created first, and the optional argument says that.
  Nothing is written if the manifest already exists. The derived name is checked
  by UMS's own validator rather than a copy of it, so a scaffold cannot be born
  invalid.
- **`prismio run [--release]`** — builds every target, then runs the executable
  one. Refuses when there is no executable target, or more than one.
- **`prismio test [--release]`** — a new `test(...)` target kind. A test is an
  ordinary program that **exits 0 when it passes**; that is the entire protocol,
  because Prismio has no assertion library and a richer contract would be a
  promise the language cannot keep. `prismio build` does not build test targets,
  for the reason `cargo build` does not.
- **`prismio clean [--release]`** — removes this profile's build output, leaving
  the lockfile alone.
- **`--release`** selects the profile; the plan already rooted output at
  `.prismio/build/<profile>/`, but the profile was hardcoded to `debug`.

**An unknown command is now an unknown command.** Any unrecognised first argument
was taken for a source path, so `prismio test` reported `error: cannot read test`
— sending the reader to the filesystem when the answer was the command name.
`prismio foo.psm` still means `prismio build foo.psm`; the shorthand is narrowed
to a path-shaped argument.

**`--version` reports the toolchain**, not just the version: the compiler
directory and the standard library that resolves from here. A compiler developer
has several generations in `build/` and `std` is found by search rather than
configuration, so "what am I compiling against" previously had no answer short of
reading source. `rustc -vV` and `go env` print this for the same reason.

### Fixed

- **A value read out of a parameter is a view of it.** `optionOr(f(), "!")`
  returned `""`: the release for the unbound `Option<String>` temporary was
  emitted between the call and the expression that read its result. `--verify`
  could not see it — both releases were ledger-legal, so the run reported a clean
  `4 allocated, 4 released, 0 leaked, 0 violation(s)` **and** the wrong answer.

  Three fixes, and the first two alone changed nothing: a reference-shaped field
  read now records a view of the object it came from; the AIF walk gained the
  `MATCH_STATEMENT` case it never had, so a payload arm binder is bound to the
  field it reads; and sema types the binder's *node* as well as its name, without
  which the walk could not tell a `String` payload from an `Int` one. Not
  Option-specific — a plain struct field and a concrete payload enum reproduced
  it too.

  The unbound form now leaks rather than dangling, which is the conservative
  direction and what the released 0.1 compiler did. Guard:
  `tests/test_92_field_view_provenance.psm`, which asserts values rather than the
  ledger. See `aif/evidence/RESULTS-field-view-provenance.md`.

### The String surface

`String` gets operators, properties, and a method surface. Every one of them is a
rewrite performed in semantic analysis into the `std.string` call it means, so
overload resolution, the ownership analysis, AIF and codegen meet an ordinary call
and none of them changed. All of it needs `import std.string` — there is still no
prelude.

- **Operators.** `a == b` and `a != b` are content equality; `<`, `<=`, `>`, `>=`
  are the sign of `strCompare`; `a + b` concatenates; `s[i]` is the byte at `i`;
  `s[start..end]` is a half-open slice. `==` on two Strings was previously a hard
  rejection naming `strEquals`.
- **A chain of `+` is one call.** `a + b + c` lowers to `strConcat(a, b, c)`, not
  to nested calls. The nested form leaks its intermediate — 2 allocated, 1
  released, on the released 0.1 compiler as well — so flattening is a correctness
  measure. Up to six parts; past that, `strJoin`.
- **Properties.** `s.length`, `s.isEmpty`, `c.isDigit` — a method call without the
  parentheses. **A property may not allocate**: the rewrite is refused when the
  resolved function returns an owned value, so `s.trim` is an error naming the fix
  while `s.length` is not. A struct field always wins over a property, so no
  existing program changes meaning.
- **`for c in s` and `for x in xs`.** Leaving out the `..` iterates a `String` by
  byte or a `List<T>` by element. The collection is borrowed, not moved. It must be
  a *name*: the loop needs it more than once, and an owned result has to be bound
  anyway. A desugaring over `s[i]`, not an extensible iterator protocol.
- **~35 new methods and functions**, including `slice`, `lines`, `chars`, `bytes`,
  `find`, `get`, `stripPrefix`, `stripSuffix`, `capitalize`, `padCenter`,
  `trimChars`, `insert`, `removeRange`, `equalsIgnoreCase`, `isBlank`, `countIf`,
  `parseFloat`, `parseBool`, `parseIntOr`, `parts.join(sep)`, `impl Char` for the
  `char*` predicates, and `toString` on `Int`, `U64`, `Bool` and `Char`.

The `str*` and `char*` free functions are unchanged and remain supported. The
prefix is not decoration: a method is a free function whose first parameter is the
receiver, so `std.string` now claims 64 unprefixed global names, and a program
defining its own `fn isDigit(c: Char)` alongside it will not compile. Three places
in this tree collided and were renamed. See KNOWN_ISSUES.md.


## 0.1.0

The first release. Prismio is a self-hosted, statically typed, ahead-of-time
compiled language with an inference-driven memory model: you write no `free`, no
lifetimes and no reference counts, and the compiler decides per allocation site
which of six implementation tiers a value needs.

Every code sample in the documentation is compiled by this compiler as part of
the docs build, and the compiler reaches a byte-identical two-generation fixpoint
building itself.

### Language

- Structs, enums with payloads, `Option`/`Result`, optionals (`T?`) with a
  checked `expect`, arrays, `List<T>`, `Slice<T>` views, and `String`
- **Generics** by monomorphisation, with per-specialisation container layout: an
  eligible `List<Flat>` uses inline storage while another instantiation of the
  same template stays boxed
- **Method-call syntax and `impl` blocks** — `x.f(a)` is the call `f(x, a)` after
  the checker's rewrite, so there is no separate method dispatch
- **Traits** with one bound per type parameter, checked statically at the
  instantiation. No trait objects, no vtables
- **Closures**: a struct plus a `call` function resolved by overloading, so no
  function pointer and no indirect call
- **Module namespacing and visibility** — `public`/`private`/`internal`,
  module-qualified calls, and selective imports (`import std.string.strTrim`)
- **Concurrency**: `spawn`/`join`/`Task<R>`, and a blocking typed `Channel<T>`
  whose receive answers `T?`, so a worker loop ends without a sentinel message
- Programmer-directed AoS↔SoA data views

### Memory model

Six tiers, inferred: frame storage, region arenas with automatic placement,
scope-bound ownership, non-atomic reference counting, atomic counting where a
value provably crosses threads, and a cycle collector this corpus omits entirely.
`--verify` checks the inference at run time, `--why` explains one site's tier,
and a differential test runs the whole engine against an independent oracle that
shares no code with it.

### Standard library

Ten importable modules: `std.io`, `std.string`, `std.fs`, `std.process`,
`std.list`, `std.map`, `std.option`, `std.key`, `std.ord`, `std.copy`. `std.io`
is an ordinary import rather than a prelude, so a program that names no I/O
carries none — which is what lets a target with no stdout link at all.

### Toolchain

- macOS, Linux and Windows, with a three-generation bootstrap from a committed,
  target-neutral LLVM IR seed
- Cross-compilation (`--target`, `--sysroot`) with a per-triple runtime archive
- `-g` DWARF describing the layout permutation and hot/cold split truthfully
- A JIT (`--jit`), an object cache, and a curated inlinable runtime module
- UMS package manifest (`build.ums`), lockfile, and local path dependencies

### Performance

Against idiomatic Rust on seven benchmark programs, 25 interleaved runs per arm
with checksum agreement asserted before any timing is read: **0.88×–1.57×**,
ahead on the scene-graph and parallel-bands programs. Written the way an expert
would write it, the same programs run at **0.25×–1.17×** of idiomatic Rust.

### Not in this release

`async`/`await`, an executor, atomics and other synchronization types, and a
specified memory-ordering model. User-written lifetimes, a non-owning typed
pointer (`Ptr<T>` is the first v0.2 pointer item), exceptions, macros, a package
*registry* and version solving, aliased imports, mobile toolchains, and a
formatter, linter or language server.

**WebAssembly is blocked, not in progress.** Prismio emits wasm32 IR, but there
is no C library for `wasm32-unknown-unknown`, so the runtime cannot be built for
it from this repository.

### Known limits

- `Char` is a byte, not a Unicode scalar; there is no string interpolation and no
  iterator protocol
- A heap value is reclaimed where it is bound to a name, so some inline temporary
  shapes still leak; `aif/evidence/` records the ones that are open with the
  measurement that found each
- Diagnostics have source spans and recovery but no stable numeric codes
