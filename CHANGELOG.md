# Changelog

This file records what is changing in **0.2.0**, the release being prepared. It does not carry earlier
releases: those are on the [release notes page](https://docs.prismio.org/releases). The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/) (pre-1.0, so a minor release may still break things).

## [0.2.0] - Unreleased

### Added

- **`a ?? b`, none-coalescing.** `a` when it has a value and `b` when it is `none`,
  for any `T?`; `b` is a `T` (the result is a `T`) or another `T?` (the result stays
  one, so `a ?? b ?? 0` tries each in turn). The right side is evaluated only when it
  is needed, so `line ?? fail("no input")` runs `fail` only for `none`. It binds
  tighter than a comparison and looser than `|` and `+`, and associates to the right.
  It is the call `optionCoalesce(a, b)` in `std.option`, so a program using it
  imports `std.option`.
- **`from <directory> import {a, b}`** is `import {a, b} from <directory>` with the
  directory first, and `from <directory> import *` is `import * from <directory>`.
  Both orders can sit in one file.
- **`main` needs neither `-> Int` nor `return 0`.** `fn main() { ... }` exits with
  status 0: reaching its closing brace is `return 0`, and so is a bare `return`. Writing
  `-> Int` says the status is the program's, so that `main` is held to the rule of
  every `-> Int` function: each path must return a number, and falling off the end or a
  bare `return` is an error ("function `main` must return Int on every path"). A `main`
  that declares any other return type is refused.
- `std.input`: every read is a plain function, so there is no `stdin` to name first:
  `readLine()`, `readLineOr(fallback)`, `prompt(text)`, `readInt()`, `readFloat()`,
  `readLines()`, `readWords()`, `readAll()`, `atEndOfInput()` and `inputLines()` for a
  `for` loop.
- **Removed: the `stdin` value** (`stdin.readLine()`, `stdin.lines()`, `stdin.isAtEnd`,
  and the rest of its methods). Each is the plain function of the same name now:
  `stdin.lines()` is `inputLines()` and `stdin.isAtEnd` is `atEndOfInput()`.
- `std.option`: `unwrapOr`, `expect(o, message)`, `okOr`, `map` and `andThen` on any
  `T?`, as ordinary generics over it (`o.unwrapOr(x)` and `unwrapOr(o, x)` are one
  call).
- `std.fs`: `createSymbolicLink(target, linkPath)` → `Bool`, `readLink(path)` →
  `String?` (none when the path is not a link) and `realPath(path)` →
  `String?` (none when the path does not resolve). On Windows
  `readLink` always answers none.
- `std.process`: `process.allEnv()` returns every environment variable as
  `NAME=value` lines.
- Runtime groundwork in `program_support.c` for the host name, group ids, user
  and login names and disk usage (`statvfs`). No `std` wrapper exposes these yet.

### Changed

- **`Option<T>` is gone; `T?` is the optional.** Two spellings of "a `T` or nothing"
  were one more thing to learn and to convert between, and `T?` already did the same
  work for numbers, `Bool`, `Char`, fieldless enums, `String`, `Vec`, structs and `Ptr`.
  Every function that answered an `Option` answers a `T?` now: `Vec.get`, `pop`,
  `min`, `max`, `find`, `removeFirst` (and the array and slice forms), `Map.get` and
  `mapGet`, `String.get`, `find`, `stripPrefix` and `stripSuffix`, `process.env`,
  `readLine` and `prompt`, `tryReadFile`, `tryReadLines`, `readLink`, `realPath`,
  `metadata`, and `Result.ok()` and `err()`. A number's `T?` is a value that
  allocates nothing; a reference's is a pointer. To migrate: `Option.Some(x)` is `x`
  and `Option.None` is `none`; `optionOr(o, d)` and `o.unwrapOr(d)` are `o ?? d` or
  `o.unwrapOr(d)`; `o.isSome` and `o.isNone` are `o != none` and `o == none`;
  `optionIsSome(o)`, `optionIsNone(o)` are gone with `Option`; and `match` on an
  `Option` becomes a test against `none` and `expect(o)`. A `T?` parameter now takes
  its `T` from an optional argument only, so `a.map(f)` on a value that is not an
  optional never reaches `std.option`'s `map`.
- `println` of an optional shows the value or `none`, as before; a `String?`, an
  `Int?` and the other scalars need `import std.display`, as before.
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
  engine and oracle agree on all 17 differential sources. The README's `prismio aif`
  example is regenerated.
- **A `Vec` literal allocates exactly its length.** `vecOf` started from an empty list
  and grew it 0 → 4 → 8; each overload now starts from `list_new_with_capacity(n)`.
  A function building a four-element literal runs in 0.80× of the time and an
  eight-element one in 0.64× (`Vec` capacity of `[7]`, `[1, 2, 3]` and `[1, …, 8]`
  was 4, 4, 8 and is 1, 3, 8).
- Compiling the compiler's own source is about 3% faster (0.677 s → 0.658 s, median of
  seven interleaved runs).
- The bootstrap seed is no longer tracked in git. It is the `prismio-seed-<version>.ll`
  asset of a release, pinned by version and SHA-256 in `bootstrap/seed.json`;
  `tools/fetch_seed.py` downloads it into `bootstrap/` (ignored), checks the hash and
  reuses the file, and `tools/bootstrap.*` run it for `--seed`. `tools/refresh_seed.*`
  cut a seed, update the pin and print the `gh release upload` that publishes it. The
  CI step that required the committed seed to match `src/` is gone: a seed is the
  compiler as of a release, not of the working tree.
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
- **A struct handed to a function that returns one of its parameters was never
  released** when the call's result was bound or stored in a struct field
  (`let r = pick(a, b)`; 0 of 4 blocks released, now 4 of 4). The callee's `return`
  lifted the argument's escape to the caller, and the scope-exit drop read that as the
  value leaving the scope. A lift that came only from a return in another function no
  longer declines the drop (`aif_frees_unless_returned_node`); returning or storing the
  binding itself still does. `test_51_optional_refs` no longer leaks its one block.
  Where the result outlives the scope that made the arguments (returned, pushed, carried
  round a loop, assigned outward) the argument that is not returned is still leaked, and
  `docs/KNOWN_ISSUES.md` says what releasing it needs.
- `expect(<owned temporary>)` is hoisted so the temporary is released, and the hidden
  slots of `a ?? b` are zeroed before the enclosing branch, so a slot stored on one path
  is no longer released as garbage.
- The benchmark results are refreshed (release-profile compiler, five runs).

### Repository

- **`aif/` is gone.** The oracle (`aif/prototype`) is now `tools/aif_oracle/`, the specification and
  implementation notes are `docs/aif/`, and the 276-file evidence tree and the `g1`-`g9` corpus programs
  are removed (they stay in Git history). The release gate, the differential, the `workloads` check in the
  suite and `ir_snapshot` use the benchmark programs instead, and the gate now compares each workload's
  printed checksum with the one recorded in `benchmarks/results/results.json`.
- Build products are never tracked: six corpus executables were untracked, and `tools/lint.py` fails on
  any tracked executable, object or static library.
- `tests/test_runner.py`'s `ums` check follows the host profile `build.ums` names, and `install.sh` and
  `std/input.psm` end with a newline.

### Documentation

- The developer docs gain *Performance decisions and rejected experiments*, drawn from the removed evidence
  (allocator choice, the `Int` width, layout representations, loop-guard and map-hash designs, channel
  results); the language docs say why `Int` is 32-bit and when to use `I64`; and the FFI contracts page
  records what an opaque module boundary costs the analysis.
- `docs/KNOWN_ISSUES.md` is restructured: open items only, grouped by area, with the
  `--verify` leak table re-measured (272 programs, 0 violations, 171 leaked blocks in
  21 programs). What was fixed lives in `git log`.

[0.2.0]: https://github.com/prismio-lang/prismio/compare/v0.1.0...HEAD
