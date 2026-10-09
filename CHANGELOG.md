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

- **Freestanding programs: a Prismio program with no operating system under it.**
  `prismio build app.psm --target <triple> --freestanding` links no installed runtime, no C
  library, no startup files and no `-lm`/`-lpthread`; the image is static, linked by lld.
  A kernel boots under QEMU on AArch64 (`virt`) and 32-bit x86 from this repository's
  tests, with the entry point, serial output, exit and panic hook written in Prismio.
  The rest of the build is flags: `--native <file>` (a C or assembly source, such as a boot
  stub), `--native-flag`, `--link-arg` (`-T kernel.ld`), `--target-features` (`-neon,-fp-armv8`;
  `-sse,-sse2,-mmx,+soft-float`), `--code-model <small|kernel|medium|large>` and
  `--no-red-zone`. A `build.ums` target declares the same with `freestanding = true`,
  `triple`, `features`, `codeModel`, `noRedZone`, and `script("kernel.ld")` and `arg("...")`
  in `link { }`. See `docs/FREESTANDING_PLAN.md` and the guide *Freestanding programs*.
  - A freestanding program may import `std.option`, `std.platform` and `std.iter` and no
    other `std` module (`P1094`): the rest are compiled against the C library.
  - `--freestanding` adds `runtime/freestanding/panic.c`, which defines the six functions
    generated code calls on a failure (a checked overflow, `panic`, `unreachable`, a failed
    `assert`, a bad range step, `expect` on `none`) and forwards each to one function the
    program supplies, `prismio_panic_hook(kind, detail, file, line, col)`. Every function in
    it is weak, so a program may replace any of them.
  - `tools/package.py --freestanding-target <triple>` packages the allowed `std` modules and
    the failure core for a bare-metal triple; no sysroot is needed.
- **Memory, atomics, assembly and port I/O as builtins**, for code that talks to hardware.
  An address is a `Usize`, not a `Ptr`, and the width is in the name:
  `__builtin_mem_{load,store,vload,vstore}_{u8,u16,u32,u64}` (plain and volatile),
  `__builtin_mem_{aload,astore,aswap,aadd,asub,aand,aor,axor,acas}_*` (atomic,
  sequentially consistent), `__builtin_mem_fence()`, `__builtin_asm(text)`,
  `__builtin_asm_read(text) -> U64`, `__builtin_asm_write(text, value)` (the text must be a
  string literal; `$0` is the operand), `__builtin_ptr_addr` and `__builtin_addr_ptr` (the one
  door between `Ptr` and a number), and on x86 `__builtin_port_{in,out}_{u8,u16,u32}`.
- **Declaration modifiers.** Before `fn`: `export` (the function is also reachable under its
  source name, the symbol an assembler stub or a linker script writes), `naked` (no prologue
  or epilogue; the body is `__builtin_asm`), `section("...")` and `align(n)`. Before
  `struct`: `repr(C)` (fields in the order written, C's padding) and `packed` (and no
  padding); an unmarked struct is still ordered by the compiler. All are contextual words, so
  a variable may still be called `export`.
- New diagnostics `P1090`–`P1096` (the command-line flags, and `P1094` for a refused `std`
  import) and `UMS2116` (an unknown `codeModel`).

- **Benchmarks are two suites, `hosted` and `freestanding`, in one tabbed report.** The existing
  Prismio/C++/Rust matrix moved to `benchmarks/hosted/`. The new `benchmarks/freestanding/` runs Prismio,
  C and Rust with no operating system: 20 integer workloads (algorithms, compute, memory, and a
  hardware category of atomics and volatile access on raw addresses) built for bare-metal AArch64 and run
  under QEMU with `-icount shift=0`, which makes the guest's timer count instructions. The result is an
  exact, repeatable instruction count per workload, plus `.text` size, not a time, so there is no noise
  model. One harness object (boot, timer, serial, exit) links into all three arms, and the runner stops if
  their checksums disagree. The Rust arm needs no `rustup target add`: `core` is built from `rust-src`.
  `prismio bench` runs both (`--suite hosted|freestanding`, `--scale N`); `results/results.json` is schema
  4, one report per suite, and the HTML report and the website's benchmarks page gain Hosted and
  Freestanding tabs. First numbers against C: 14 of 20 at parity, 3 fewer instructions and 3 more; against
  Rust, 9 fewer, 9 at parity and 2 more. The first run read `edit_distance` at 2.0x C, and that was the
  harness: Prismio's row copy became a call to a byte-loop `memcpy` that C's `-ffreestanding` build never
  made. The shared `memcpy`, `memmove` and `memset` now move a word at a time (aligned, so they are safe
  with the MMU off), and the row reads 1.05x. The three rows still behind C are one cause: C's signed overflow is undefined and Prismio's wraps, so LLVM can rewrite C's arithmetic and widen its loop indices. With the C arm built `-fwrapv`, Prismio is 4 fewer, 16 level and none more across the 20. All three are recovered since, without `-fwrapv`; see *Changed*.
- **`std.mem`: buffers and manual memory.** Three tools, in one import:
  - **`Buffer`**, a run of bytes with a length that is freed like any `Vec`. `Buffer(n)`
    (zeroed), `Buffer.withCapacity(n)`, `Buffer.fromString(s)`; `b[i]` and `b[i] = x`;
    typed reads and writes at any byte offset, little- and big-endian, for `U8`/`I8`
    through `U64`/`I64` and `Float` (`readU32BE`, `writeI16LE`, `readFloatLE`, ...);
    `fill`, `copyFrom` (overlap-safe), `slice`, `resize`, `push`, `append`, `clear`,
    `indexOf`, `toString`, `==`, and `b.address` for the builtins or C. Every access is
    bounds-checked, and a bad one exits with the offset and the length. The byte
    accessors are curated into the program, so a `readU32LE` in a loop compiles to one
    unaligned load per iteration with the check lifted out (AArch64: two `ldr`s per
    unrolled pair, no branch).
  - **`alloc`, `allocZeroed`, `realloc` and `free`** on `Usize` addresses, with `copy`,
    `fill`, `compare`, and `a.loadU8()` ... `a.storeU64(v)` over the `__builtin_mem_*`
    loads and stores. An allocation never returns 0; running out of memory exits with
    a message. The blocks go through the runtime's allocator seam, so a `--verify` build
    reports a block never freed as **leaked** and one freed twice as a **violation**.
  - **`Arena(capacity)`**, a bump allocator: `alloc(size, align)` answers an aligned
    address, `reset()` takes everything back at once, and `used`, `remaining` and
    `capacity` report on it. An allocation that does not fit, or an alignment that is
    not a power of two, panics.
  `tests/test_274_std_mem.psm` covers the surface and is held to 0 leaked and 0
  violations under `--verify` (55 allocated, 55 released); `std_mem_failures` checks
  each failure message and the two ledger answers. `sizeOf<T>()` is not part of it:
  a type's size is not exposed yet.
- **Benchmarks for `std.mem`**, in the hosted memory category, each the same program in
  Prismio, C++ and Rust: `binary_codec` (Buffer's typed big- and little-endian reads
  and writes), `manual_alloc_churn` (`alloc`/`free` against `malloc`/`free` and
  `std::alloc`) and `arena_bump` (a linked list built in an `Arena` and reset, against
  a hand-written bump arena). First numbers against C++: 1.03×, 0.98× and 1.00×.
  `arena_bump` read 1.61× until `Arena.alloc`'s failure messages moved into `cold`
  functions and the block's address and length were read once at construction;
  built in place, the messages stopped `alloc` inlining and gave it a 240-byte frame.
- **`x[i] = v` on a struct calls its `set`**, as `x[i]` already called its `at`. A struct
  with an `at` and no `set` keeps the error, which now says to write
  `fn set(inout self, index, value)`. A generic struct's `set` is not reached yet, so a
  `Map` is still assigned with `m.set(k, v)`.

### Changed

- **Tight integer loops get the no-wrap facts C gets from undefined overflow.** `Int` still
  wraps. Four analyses now tell LLVM where it provably cannot:
  - A loop over an `Array<T, N>` with no list guard is versioned on the facts that keep its
    accesses in range (`arrays` in `src/ir/ranges.psm`). Innermost loops only, and only when the
    proof marks arithmetic.
  - An unchecked access to a fixed array or a `[T]` view leaves its index in `[0, Int.MAX - 1]`,
    which marks the `+` and `-` it bounds `nsw` (`src/ir/nowrap.psm`).
  - A counted `while` (`i < e` or `i <= e` and the like as a conjunct, and a last statement that
    steps `i` by a literal) bounds its counter in the body and counts its iterations
    (`src/ir/counters.psm`).
  - A local `Array<Int, N>` that nothing but a subscript names keeps a bound on its elements
    (`src/ir/contents.psm`): each store's value is described relative to the elements it reads, and
    the counted loops bound how far stores can raise them in one lifetime of the array.

  Freestanding, in instructions: `quicksort` 11,304,368 to 9,991,296 (C 10,096,384); `knapsack`
  5,690,512 to 3,139,600 (C 5,122,624), because its guard holds `w >= 0`, a fact C's undefined
  overflow never supplied; and `edit_distance` 5,900,624 to 5,540,624 (C 5,596,832), because its
  rows stay in `[0, 360600]`, so `min(a + 1, b + 1)` becomes `min(a, b) + 1`. `sha256` moved
  9,018,112 to 8,634,112, from code shape rather than a proof. Against C the suite reads 4 fewer,
  16 level and none more, geomean 0.95x (it was 3, 14 and 3, 0.99x). The hosted suite's 140
  functions are instruction-identical against a baseline without the change. The compiler's own
  IR gains 41 `nsw` (369 to 410), and emitting it costs 0.9% more instructions. `PRISMIO_NOWRAP=0`
  turns the marks from the last three off, as `PRISMIO_RANGE_PROOFS=0` does the proofs', to
  separate what each buys. Because the compiler relies on it, an out-of-range index into a fixed
  array or a `[T]` view is now specified as undefined behaviour.

- **On AArch64, a branch on two conditions splits again when one is a single bit test.** LLVM 23's
  AArch64 backend gained a cost model that computes `a and b` together and branches once, and it
  merged even where one condition is a lone `tbnz`: `ring_buffer`'s
  `if (((s >> 8) & 1) == 0 and head != tail)` cost `ubfx; cmp; csinc; tbnz` on every iteration,
  where LLVM 22, and so rustc, emit `tbnz` and stop half the time. The compiler now passes
  `-aarch64-br-merging-cbz-tbnz-bias=8` (LLVM's default is 6), which splits that shape. Freestanding,
  `ring_buffer` runs 4,429,696 to 3,753,472 instructions (C 4,429,312, Rust 3,753,472), no other row
  moves, and the suite reads 5 fewer, 15 level and none more against C (geomean 0.95x) and 9, 11 and
  none against Rust (0.85x). Hosted, 11 of 140 functions change and the timings do not: geomean 0.999
  over 52 workloads, against 1.001 for an identical-binary control in the same interleaved runs.
  Compiling the compiler moves by +0.1% in cycles, inside its spread. `PRISMIO_LLVM_ARGS` overrides
  the option.

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
- **A line that starts with `(` or `[` was read as a call or an index of the line
  before.** Statements have no terminator, so `a.storeU32(7)` followed by
  `(a + 4).storeU32(7)` parsed as one expression and failed with an "unknown
  function" error naming a function with no name. Such a line now starts a new statement; a `.` still
  continues a method chain across lines, and a call's arguments still wrap. No program
  in `tests/`, `benchmarks/` or `src/` relied on the old reading: their IR is
  byte-identical (`tests/test_275_line_start_paren.psm`).

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

- `tests/freestanding/` holds the kernels and fixtures behind the `freestanding` test, which boots
  eleven of them under QEMU (AArch64 `virt` and 32-bit x86) and skips, saying so, without `ld.lld` or
  `qemu-system-*`; `runtime/freestanding/` holds the failure core, outside `runtime/*.c` so
  `tools/check_source_lists.py` does not count it as a compiler source. That check now also compares
  `freestandingSafeModule` in `src/driver/imports.psm` with `FREESTANDING_STD` in `tools/package.py`.

### Documentation

- *Freestanding programs* (guide) and *Low-level programming* (language) describe the above, with the
  flags in the CLI and manifest references; the developer docs record how the backend, the parser and the
  packager implement it.
- The developer docs gain *Performance decisions and rejected experiments*, drawn from the removed evidence
  (allocator choice, the `Int` width, layout representations, loop-guard and map-hash designs, channel
  results); the language docs say why `Int` is 32-bit and when to use `I64`; and the FFI contracts page
  records what an opaque module boundary costs the analysis.
- The developer docs gain *Wrapping integers and tight loops*: what the freestanding gap to C was made
  of, what was built, every alternative measured (among them undefined overflow, `freeze` semantics,
  `mustprogress` and `llvm.assume`), and the prior art. *Loop guards* describes both analyses, and
  the specification's *Bounds and storage* states the undefined behaviour above.
- `docs/KNOWN_ISSUES.md` is restructured: open items only, grouped by area, with the
  `--verify` leak table re-measured (272 programs, 0 violations, 171 leaked blocks in
  21 programs). What was fixed lives in `git log`.
- The language docs gain *Memory and buffers* (`std.mem`, with runnable examples for
  each tool); *Methods* describes `at` and `set`; *Lexical structure* states the
  line-start rule; *Low-level programming* points at `std.mem` for allocation. The
  developer docs' *supported surface* lists the `mem_*` runtime symbols and records
  that `borrow` becomes `readonly` on `String` arguments only, which `std.mem`'s writers
  depend on.

[0.2.0]: https://github.com/prismio-lang/prismio/compare/v0.1.0...HEAD
