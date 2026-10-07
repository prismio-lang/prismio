# Changelog

All notable changes to Prismio are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/) (pre-1.0, so a minor
release may still break things).

The full notes for each release, with downloads and known limits, are on the
[release notes page](https://docs.prismio.org/releases).

## [Unreleased]

### Added

- `std.fs`: `createSymbolicLink(target, linkPath)` → `Bool`, `readLink(path)` →
  `Option<String>` (none when the path is not a link) and `realPath(path)` →
  `Option<String>` (none when the path does not resolve). On Windows
  `readLink` always answers none.
- `std.process`: `process.allEnv()` returns every environment variable as
  `NAME=value` lines.
- `std.input`: `readLine()`, the free-function spelling of `stdin.readLine()`,
  returning `Option<String>`.
- Runtime groundwork in `program_support.c` for the host name, group ids, user
  and login names and disk usage (`statvfs`). No `std` wrapper exposes these yet.

### Changed

- The bootstrap seed is now `bootstrap/prismio-seed-0.1.0.ll`, named for the
  release it was cut at. `tools/bootstrap.*`, `tools/refresh_seed.*`,
  `tools/release_gate.py`, CI and the docs follow the new name; the seed's
  content is unchanged.
- The project host in `build.ums` and `sandbox/build.ums` is the release build
  (`.prismio/build/release/prismio`), and the `release` and `bench` commands use
  it. `verify`, `gate` and `package` still name the debug build.
- README: the "Changelog" link points to the release notes, and the archive
  list now names all five platforms, with which are tested in CI and which on
  virtual machines.
- Benchmark results are refreshed, measured with the release-profile compiler:
  0.85× of C++ and 0.83× of Rust by geometric mean over 62 workloads (was 0.87×
  and 0.84×). The README quotes the new figures.

## [0.1.0] - 2026-10-02

The first release. Archives for macOS arm64, Linux x64 and arm64, and Windows
x64 and arm64, each with a `.sha256`.

### Added

- `std.input` (`stdin.lines()`, `readLine`, `readAll`, `readLineOr`, `prompt`,
  `readInt`, `readFloat`, `readLines`, `readWords`, `isAtEnd`), `std.time`,
  `std.math`, `std.term`, `std.unicode`, `StringBuilder`, `Map` methods and
  O(1) removal, `Option` and `Result` methods, environment variables and the
  process id, `Process`/`Child`/`Stream`, `readLines(path)`, and more of
  `std.fs` (`listDirectory`, `appendFile`, `rename`, `removeDirectory`,
  `metadata`).
- `print`, `println`, `eprint` and `eprintln` accept any type with a `Display`
  implementation, including `Option<T>`.
- Constant array globals: a module-level `let words = ["alpha", "beta"]` is
  read-only data and builds nothing at run time.
- String interpolation, `"${x}"`.

### Changed

- The compiler links three LLVM backends (AArch64, X86, WebAssembly) instead of
  all 25 and is about half the size; `--target` accepts those three families.
- Compiling is faster: the allocation analysis answers its whole-program
  questions from indexes built once, and the compiler emits its own IR in about
  half the time with identical output.

### Fixed

- A function ending in `panic`, `unreachable` or `exit` while owning a value
  emitted invalid IR.

[Unreleased]: https://github.com/prismio-lang/prismio/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/prismio-lang/prismio/releases/tag/v0.1.0
