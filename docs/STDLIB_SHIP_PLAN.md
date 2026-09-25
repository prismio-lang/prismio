# Standard library: what shipping needs

The gaps between today's `std` and a compiler someone can write ordinary
programs with, in the order they are being closed. Like
[`FEATURE_BACKLOG.md`](FEATURE_BACKLOG.md), this is long-lived work, not
session scaffolding: `KNOWN_ISSUES.md` records defects, `aif/evidence/` the
measurements, and this file what is left and how each piece is meant to land.

**How the list was made (2026-09-25).** Every public function in `std/*.psm`
was listed. Every `extern fn` a program in this repo declares for itself was
counted, since each one is a gap a user would hit. Each candidate API was then
compiled against the current toolchain, so "missing" below means *the compiler
rejects it*, not "grep did not find it".

**Status key:** `todo` · `in progress` · `done <commit or date>` · `blocked: <why>`.

## Tier 1 — before shipping

A normal command-line program cannot be written without these, or the API
exists in a shape that would break every user to change later.

| # | Gap | Status | Needs C | Needs compiler |
|---|---|---|---|---|
| 1 | [Exit, panic, assert](#1-exit-panic-assert) | done 2026-09-25 | yes (`lang_runtime.c`) | yes (builtins, divergence) |
| 2 | [Standard input](#2-standard-input) | done 2026-09-25 | yes (`program_support.c`) | no |
| 3 | [Environment and process identity](#3-environment-and-process-identity) | done 2026-09-25 | yes | no |
| 4 | [`std.time`](#4-stdtime) | done 2026-09-25 | yes (Windows half too) | no |
| 5 | [`Option` / `Result` methods](#5-option--result-methods) | todo | no | maybe (generic `impl`) |
| 6 | [`Map` removal and methods](#6-map-removal-and-methods) | todo | no | maybe (generic `impl`) |
| 7 | [Files](#7-files) | done 2026-09-25, except the file line reader | yes | no |
| 8 | [Building strings](#8-building-strings) | todo | no | no (interpolation is separate) |

Items 5 and 6 go before anything that returns an `Option` or a `Map` gets
more callers: they are the two public APIs still spelled `optionIsSome(o)` /
`mapGet(m, k)` against the method-first rule (`s.length`, not `strLength(s)`).

## Tier 2 — soon after

| Gap | Notes |
|---|---|
| `std.random` | seeded PCG/xorshift, ranges, shuffle; no OS entropy needed for v1 |
| `Set<T>`, `VecDeque<T>`, priority queue | `FEATURE_BACKLOG.md` item 3 is the heap |
| `Mutex`, atomics | tasks and channels exist; shared state does not |
| Path helpers | file name, extension, parent, normalise; today only `joinPath`, `directoryOf` |
| Argument parsing | `process.args` exists, flags do not |
| Test harness | `assert` (item 1) plus `prismio test` discovery |
| Diverging user functions | a `Never` return type, so `fn fail(msg) -> Never` ends a block the way `panic` does |
| Math follow-ups | bit counting, checked/saturating integers, `F32` — see `RESULTS-std-math.md` §4 |

## Tier 3 — later

Networking (`std.net`), date and calendar, JSON (`FEATURE_BACKLOG.md` item 2),
regular expressions, hashing and cryptography, compression, logging.

## Doc contradictions to fix along the way

- ~~The docs sidebar lists Filesystem under "Planned · Coming Soon"~~ — fixed 2026-09-25.
- ~~`stdlib/io.md` tells readers to write a C wrapper for file access~~ — fixed
  2026-09-25; it now says plainly that standard input is not available yet.

---

## 1. Exit, panic, assert

**Why first.** Three programs in this repo declare `extern fn exit` or
`extern fn abort` for themselves, and a program has no way to fail loudly with
a message and its location. Every later item wants `panic` for its "cannot
happen" paths and `assert` for its tests.

**Surface.** Compiler builtins, available without an import, as `expect` and
`drop` are:

| Call | Does | Returns? |
|---|---|---|
| `panic(message)` | prints `panic: <message>` and `  --> file:line:col` to stderr, exits 101 | never |
| `unreachable()` / `unreachable(message)` | the same, as `entered unreachable code[: message]` | never |
| `assert(condition)` / `assert(condition, message)` | nothing when true; otherwise `assertion failed: <message, or the source line>` with the location, exits 101 | yes |
| `exit(code)` | ends the process with `code`, flushing C stdio | never |

**Decisions.**
- **Exit status 101** for panic, unreachable and a failed assert, Rust's choice. It
  tells a crash apart from a program's own `exit(1)`. Existing runtime errors
  (overflow, step) keep 1.
- **`assert` is always on**, release builds too. A passing check is one compare and
  a branch to a cold block. **The message is evaluated only on failure**, so
  `assert(ok, "bad: " + name)` allocates nothing on the passing path.
- **`exit` yields to the program's own `exit`.** A module that declares
  `extern fn exit` (the compiler's own `src/` does, six times) keeps calling its
  own, unchanged. The builtin applies only where no `exit` is declared.
- **Divergence.** `panic`, `unreachable` and `exit` end a block for sema:
  a function may end with one instead of a `return`, and code after one is the
  existing "unreachable code" error. `assert` does not diverge.
- **Guard-safe.** All four are in the flat-List guard's safe table, so an `assert`
  in a hot loop does not cost the loop its guard.
- **AIF** describes all four as borrowing their arguments (contracts and oracle).

**Not in this item:** a user function that always panics is not known to
diverge (tier 2, `Never`), and there is no unwinding or `catch`.

**Done when:** a test covering each call's output, status and divergence (with
the failing ones run as subprocesses), guard-safety of `assert` in a loop,
suite and AIF differential green, seed fixpoint, docs (stdlib index "Available
without imports", a page for failure and exit) updated.

**Landed 2026-09-25.** test_182, neg_189, neg_190 and the `failure_builtins`
harness test; seed fixpoint `43feb82f`. Two things found on the way:
- An `assert` whose message called anything (`"bad: ".concat(name)`) cost its
  loop the flat guard, because `irFlatGuardCount` saw the call. It now counts
  only the condition: the message runs only on the way out of the process.
- In a hot loop, one `assert` per element measured +37.6 ms over 200M elements
  against C's +37.5 ms for the same check. Both lose vectorisation to the early
  exit; the check itself costs what C's does.

The doc contradictions listed above (filesystem sidebar, `stdlib/io.md`) were
fixed in the same pass.

## 2. Standard input

Partly there, undocumented: `Stream { descriptor: 0 }.readAll()` (std.process)
reads all of stdin -- test_153 uses it. What is missing is the line-oriented API.

`std.io` is output only. Add `readLine() -> String?` (without the newline;
`none` at end of input), `readAll() -> String`, and `for line in stdin.lines()`
(or the closest spelling the iterator protocol allows). It must be buffered in
the runtime: one `read` per line would make a line-oriented filter slower than
`cat`. A benchmark (line count / word frequency over a large file, against C++
and Rust) comes with it.

**Landed 2026-09-25.** `stdin` is a global in a new module, `std.input`, as
`process` is in `std.process`. It is not in `std.io`: every printing program
imports that module, and each would carry the global into its debug info and
link, and `std.option`'s allocation sites into its analysis. `stdin` has
`lines()` (an `Iterator` of String), `readLine() -> Option<String>` (not
`String?`, matching `process.env`) and `readAll()`. All three share one 64 KiB
runtime buffer (`io_stdin_*`, `runtime/program_support.c`), so they can be
mixed. `\r\n` ends a line as `\n` does. test_188 covers terminators, empty input,
mixing, and a 200,000-byte line; every stdin path reads 0 leaked under `--verify`.

Measured over 3M lines / 118 MB, a median of 11 runs (aif/evidence/RESULTS-std-stdin.md):
line count 134 ms against C++ `getline` 156 ms and Rust `lines()` 274 ms;
line+word count 212 ms against 450 ms and 606 ms (Rust reusing its buffer: 462 ms).

Found on the way, and fixed:
- AIF let a loop's arena "serve" a C-produced value, which the arena cannot
  allocate. Each line leaked, and each iteration paid a region push/pop that
  served nothing (277 ms before the fix). The same fix covers `read_file`,
  `join_path` and every application extern (KNOWN_ISSUES, Ownership).
- The workload sandbox stubs `io_stdin_*`, as it stubs every capability, and the
  runtime module defines them too. The driver failed to link, so any workload
  importing `std.fs` or `std.process` had already been falling back to the static
  profile. The runtime's definition now yields to the stub.

Not done: word frequency (it measures `Map` more than input and waits on item 6);
reading bytes rather than text; a line with a NUL byte is cut there.

## 3. Environment and process identity

**Landed 2026-09-25**, picked as the smallest tier-1 gap: `process.env(name) ->
Option<String>` (`None` unset, `Some("")` empty), `setEnv`/`removeEnv -> Bool`,
`process.pid`. Five C functions in `runtime/program_support.c`, the wrapper in
`std/process.psm`, test_183 (including a child that inherits a variable set by
its parent). `Option<String>` rather than `String?`, matching `parseInt` and
`Vec.get`. The working directory stays `currentDirectory()` in `std.fs`.

Found on the way: `optionOr(process.env("X"), "d")` leaks, because a producing
call nested in another leaks its result (KNOWN_ISSUES); bound first it is clean
(4000/4000 over 2000 lookups). **Fixed the same day** (RESULTS-call-result-ownership.md):
the one-expression form is clean too, 3001/3001, so it no longer blocks item 5.

Not done: listing all variables at once, a child with its own environment.

The AIF differential over test_183 disagrees on the one site where the C-produced
value enters `Option.Some`, in the copyable model only. Pre-existing (reproduced
with `read_file` on the pre-change compiler); recorded in KNOWN_ISSUES under
"The AIF oracle".

## 4. `std.time`

Monotonic `Instant.now()`, `Duration` (with `elapsed`, `asMillis`,
`asSeconds`), wall-clock seconds since the epoch, and `sleep(duration)`.
Windows needs `QueryPerformanceCounter` where POSIX has `clock_gettime`; the
benchmarks' own `extern fn clock_gettime` is the first caller to move over.
Calendar and time zones are tier 3.

**Landed 2026-09-25.** `std/time.psm` over three C functions in
`program_support.c` (`time_monotonic_nanos`, `time_unix_nanos`,
`time_sleep_nanos`). Counts are `I64` nanoseconds everywhere, because an `Int`
holds 2.1 s of them. A `Duration` is signed, so `a.since(b)` with `b` later is
negative rather than an error. The `as*` accessors are properties. `elapsed()` is
a method because a property may not return a struct. `sleep` resumes after
`EINTR` for what is left. test_189 covers every unit conversion, a sleep measured
by `Instant`, monotonicity, and a sane wall clock; 0 leaked under `--verify`.

The benchmark suite's Prismio arm now times with `Instant`. The move found two
defects: it printed `(t1 - t0) as Int`, wrapping any run over 2.1 s, and it read
`CLOCK_MONOTONIC_RAW` where the C++ and Rust arms read `CLOCK_MONOTONIC`.

Not verified here: the Windows half compiles only on Windows, and this session
ran on Linux. Not done: a calendar, formatting a time, and `Instant` arithmetic
beyond `since`.

## 5. `Option` / `Result` methods

`isSome`, `isNone`, `unwrapOr`, `expect(message)`, `map`, `andThen`, `okOr`;
`isOk`, `isErr`, `unwrapOr`, `mapErr`, `ok`, `err`. Keep the prefixed functions
as the implementation, per the String precedent.

**Probed 2026-09-25 — three compiler prerequisites, not a library-only item:**
- `impl<T> Option<T>` works for `o.isSome()` and `o.unwrapOr(x)`.
- `o.isSome` wants to be a property, declared `prop` (properties are declared
  since 2026-09-25). The spelling still fails ("struct `Option$Int` has no
  field"): `semaPropertyRewrite` asks `semaDeclaresFunction`, and a generic
  method is a template the declaration index does not hold
  (prismio-generic-templates-not-indexed).
- `map<U, F>` cannot be called: `n.map<Int>(…)` does not parse (a method takes no
  written type arguments), and `U` is not inferred from the closure's return.
- `x.unwrapOr(d)` on a freshly produced Option was the nested-producer leak;
  fixed 2026-09-25, `optionOr(process.env("X"), d)` measures clean, and a chain
  of methods releases every intermediate.

## 6. `Map` removal and methods

`FEATURE_BACKLOG.md` item 1 (`mixed_map_removal`) is the detailed spec for
`remove`. Add, together with it: `m.get(k)`, `m.set(k, v)`, `m.has(k)`,
`m.length`, `m.isEmpty`, `m.clear()`, `m.keys()`, `m.values()`, `m[k]`.

## 7. Files

`listDirectory(path)` (today's `listModules` lists only `.psm` files),
`appendFile`, `rename`, `removeDirectory`, `metadata` (size, modified time,
is-directory), and a buffered line reader shared with item 2. Make the raw
`read_file`/`join_path`/... externs `internal`: RUNTIME.md says applications do
not call them, and today they are public beside their wrappers.

**Landed 2026-09-25**, all but the line reader. `listDirectory(dir) ->
Vec<String>` gives every entry's name except `.` and `..`, sorted by byte, and
an empty Vec for an unreadable directory. It reads one name at a time
(`fs_list_begin`/`fs_list_name`/`fs_list_end`), not a newline-joined string as
`listModules` does, because a POSIX file name may contain a newline.
`appendFile` returns Bool. `rename` replaces an existing destination on Windows
too (`MoveFileExA`). `removeDirectory` removes only an empty directory.
`metadata(path) -> Option<Metadata>` gives `size`, `modified` (a `Duration`
since the epoch, from std.time), `isDirectory` and `isFile`, and follows
symbolic links. The eleven raw externs are `internal`; neg_193 pins that.
test_190 runs all of it in a scratch directory; 0 leaked under `--verify`.

Not done: **the buffered line reader for files.** Stdin's reader is one
process-wide buffer on descriptor 0. A file needs a handle that is opened and
closed, and with no destructor to hang the close on, that is an API decision
(an explicit `close`, or a `withLines(path, f)` that closes for you) to make
first. Until then, `readFile(path).split('\n')` reads a small file.
Not verified here: the Windows branches (`FindFirstFileA`,
`GetFileAttributesExA`, `MoveFileExA`).

## 8. Building strings

**Measured 2026-09-25:** `s = s + x` on a local is already linear -- codegen's
consuming append doubles capacity (100K, 400K, 1.6M appends all ~0.3 s). Through
a struct field it is quadratic: `b.text = b.text + piece` via `inout` took 0.87,
2.01, 7.79 s for 20K, 40K, 80K appends. So a builder is needed exactly where text
accumulates in a field or across calls. Options: a `StringBuilder` over
`Vec<Char>` (owned by Vec, so no `Drop` needed), or extend the consuming append
to a field AIF proves owned -- which would fix every such program without a new
type. Measure both before choosing. Interpolation is separate.

**Measured again 2026-09-25, x86_64 Linux** (one run each; "piece-" appended N
times through `inout b: Builder`):

| N | `b.text = b.text + piece` | local `s = s + piece` | `b.parts.push(piece)`, then `join(b.parts, "")` |
|---:|---:|---:|---:|
| 20,000 | 0.77 s | 0.006 s | 0.005 s |
| 80,000 | killed after 43 s | 0.012 s | 0.016 s |
| 320,000 | OOM-killed at 13.8 GB RSS | 0.011 s | 0.021 s |

So the field form is not only quadratic: **it leaks every intermediate**, which
is KNOWN_ISSUES' "assigning a struct field does not release the value it
replaces". Any builder that keeps a String in a field and reassigns it inherits
that leak, so a `StringBuilder { buffer: String }` that regrows its buffer is
ruled out until that issue is fixed. A `Vec<String>` of parts joined at the end
works today, is linear, and never reassigns a field; it costs one copy per
piece (`piece.concat("")`, because a borrowed parameter cannot be pushed).

