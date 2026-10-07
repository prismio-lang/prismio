# Changelog

All notable changes to Prismio are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/) (pre-1.0, so a minor
release may still break things).

The full notes for each release, with downloads and known limits, are on the
[release notes page](https://docs.prismio.org/releases).

## [0.2.0] - Unreleased

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

- **AIF reports an array as a frame slot.** An array literal and an `Array<T, N>`
  were always an `alloca`, but the analysis tiered them as heap blocks (78 of the
  1,025 allocation sites in the tests, corpus and benchmarks) or, in a bracketed
  call, as `arena:auto`. They are T0 now and `prismio aif` says *stack, fixed-length
  array; lives in the frame*. The wrong tier also made the analysis count the array as
  served by the caller's arena, so a call to a function that only built an array was
  wrapped in an `arena_push`/`arena_pop` pair that served nothing: 520 such brackets
  (1,365 pops) leave the IR of the tests, corpus and benchmarks, and the arena
  counters read 183 fewer regions entered with the same 19,528 objects and
  6,863,136 bytes served. SPEC 4.2 and the Python oracle carry the same rule, and the
  engine and oracle agree on all 19 differential sources. The README's `prismio aif`
  example is regenerated.
- **A `Vec` literal allocates exactly its length.** `vecOf` started from an empty list
  and grew it 0 → 4 → 8; each overload now starts from `list_new_with_capacity(n)`.
  A function building a four-element literal runs in 0.80× of the time and an
  eight-element one in 0.64× (`Vec` capacity of `[7]`, `[1, 2, 3]` and `[1, …, 8]`
  was 4, 4, 8 and is 1, 3, 8).
- Compiling the compiler's own source is about 3% faster (0.677 s → 0.658 s, median of
  seven interleaved runs).
- The bootstrap seed is now `bootstrap/prismio-seed-0.1.0.ll`, named for the
  release it was cut at. `tools/bootstrap.*`, `tools/refresh_seed.*`,
  `tools/release_gate.py`, CI and the docs follow the new name; the seed's
  content is unchanged.
- The project host in `build.ums` and `sandbox/build.ums` is the release build
  (`.prismio/build/release/prismio`, built by `prismio build --release`), and the
  `release` and `bench` commands use it. `verify`, `gate` and `package` still name the
  debug build.
- README: the "Changelog" link points to the release notes, the archive list names
  all five platforms with which are tested in CI and which on virtual machines, and
  the performance figures are those of the 2026-10-06 run: 0.85× of C++ and 0.83× of
  Rust by geometric mean over 62 workloads (0.87× and 0.84× before). The benchmark
  suite shows **no net change from the compiler work above** (1.006× against a 1.010×
  drift between two runs of the same compiler); four workloads moved 7–10% with none
  of their functions' IR changed, which is code layout.

### Fixed

- **`let big: Array<Int, N>` compiled in time linear in N with a large constant** (1.6 s
  at a million elements, 21 s at ten million, over two minutes at forty million). LLVM
  scalarises a first-class `store [N x T] zeroinitializer` before recovering the memset;
  an aggregate of 1,024 bytes or more is now one `llvm.memset` (forty million Ints:
  0.06 s). Smaller arrays keep the store and their IR.
- **A function returning `Array<T, N>` took superlinear compile time** (0.65 s at 8,000
  Ints, 2.2 s at 16,000, 21 s at 32,000; a struct holding one ran for over 27 minutes).
  An array of 4 KiB or more now returns through a hidden `ptr sret` parameter that the
  caller points at a frame slot of its own (32,000 Ints: 0.09 s; 400,000: 0.07 s).
  Behaviour is unchanged.
- The benchmark results are refreshed (release-profile compiler, five runs).

### Documentation

- `docs/KNOWN_ISSUES.md` is restructured: open items only, grouped by area, with the
  `--verify` leak table re-measured (273 programs, 0 violations, 173 leaked blocks in
  19 programs). What was fixed lives in `git log`.

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

[0.2.0]: https://github.com/prismio-lang/prismio/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/prismio-lang/prismio/releases/tag/v0.1.0
