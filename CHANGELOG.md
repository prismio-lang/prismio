# Changelog

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
