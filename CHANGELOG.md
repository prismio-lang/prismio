# Changelog

This file records what is changing in **0.2.0**, the release being prepared. It does not carry earlier
releases: those are on the [release notes page](https://docs.prismio.org/releases). The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/) (pre-1.0, so a minor release may still break things).

## [0.2.0] - Unreleased

### Added

- **`async fn`, `Future<T>` and `await`.** Calling an `async fn` does not run it: the call is a
  `Future<T>`, a task that has not started, and the body runs where it is awaited. `await f(x)` is
  the call itself, with no handle and no allocation; a held future is one small allocation, and a
  future that is built and never awaited does no work. It works on methods, on generic functions
  and on recursion, a `Vec<Future<Int>>` can be collected and awaited in a loop, `async fn main`
  is allowed, and a function that is not `async` runs a future with `join`. `Future<T>` is the
  type `Task<T>` already was (both spellings are accepted); `spawn` now takes an `async fn` and a
  scalar argument or result of any width, through a thunk that converts each to and from the
  runtime's word, so `async fn half(x: Float) -> Float` needs nothing in the runtime.
- **`scope { }` and `spawn { }`.** A scope cannot be left until every task started inside it has
  finished, on every way out: the closing brace, `return`, `break` and `continue`, nested scopes
  included. `spawn { ... }` starts a task whose body is the block and is only allowed inside a
  scope; it captures what it reads from the enclosing function by value, up to three, moving
  anything that owns something, and answers with the block's last expression. `spawn fut` starts
  a future built earlier. A spawn used as a statement is waited for by the scope with no handle
  to keep. 4,200 tasks in a loop leave no leak (`leaks`). Eight new negative fixtures
  (`neg_271`-`neg_278`) hold the diagnostics. See `docs/ASYNC_PLAN.md`.

  Known limits: an `await` of a task running on another thread blocks its thread (a task is
  still an operating-system thread), a task or held future takes three arguments, and a struct or
  String that came back through a handle is not freed by the awaiter (`docs/KNOWN_ISSUES.md`).
- **`spawn` of a function defined below it.** The target's address is taken before its
  definition exists, which failed with `address of unknown function`; the spawn now declares it
  first. This also affected the `spawn f(x)` form before, and every lifted block needs it.
- **A condition needs no parentheses.** `if x == 3 { }`, `while n < 10 { }` and
  `if o == none { }` read as written, and `if (x == 3) { }` is the parenthesised
  expression it always was. A struct literal in a bare condition has to be
  parenthesised (`if (Point { x: 1 }).x == 1`), as it is in a `for` header, because
  the `{` after a condition is the body.
- **`is`, `is not` and `not`** are the words for `==`, `!=` and `!`, read into the
  same nodes as the symbols. `not` binds like `!`: `not x == y` negates `x` alone.
  All three are reserved words now. They are operators between two operands, as in Python
  (`x is 3`, `x is not none`), so a `(` touching the word is refused: `x is(3)` read as a
  call and parsed only because `(3)` is a parenthesised operand. `x is (a + b)`, with a
  space, is a grouped operand and stays valid (`P3010`, `neg_293`, `test_293`).
- **`Ptr<T>`, the type (stage 1 of `docs/PTR_PLAN.md`).** A typed pointer: non-null, one machine
  word, `Ptr<T>?` for an absent one at no cost. `Ptr<mut T>` may write and `Ptr<volatile T>` makes
  every access volatile, in either order; `Ptr<mut T>` becomes `Ptr<T>`, and becomes the opaque
  `Ptr` (still the spelling for a foreign handle) -- a read-only `Ptr<T>` does not, because foreign
  code may write through an opaque one -- and nothing converts the other way. What it points at
  must own nothing: numbers, `Bool`, `Char`, enums, pointers and structs of those, so
  `Ptr<String>` and a pointer to a struct holding a `Vec` are refused. A struct may hold a
  `Ptr<Node>?` (`test_291`, `neg_291`, `neg_292`).
- **Reading through a `Ptr<T>` (stage 2).** `p.magic` reads a field of a struct pointee where it lies
  (a `getelementptr inbounds` and a load at the field's alignment), and a field that is itself a
  struct is a pointer to it, so `packet.header.magic` reads through two. A pointer to a scalar is
  read where a value is wanted: `p + 5`, `-p`, `p is 40`, `let n: Int = p`, `return p`, and as an
  argument to an `Int` parameter; `p.load()` says it outright. A pointer stays a pointer anywhere
  else, so `let q = p` copies the pointer. Two pointers under one operator, a struct as an
  operand and a read through `volatile` are refused with the method or stage that handles each.
  The reads lower to one builtin, `__builtin_ptr_load`, emitted as a typed `load` with the
  pointee's TBAA tag, and a `Ptr<T>` parameter carries `noundef nonnull align(A)
  dereferenceable(S)` from the data layout, plus `readonly` unless it is `mut`: `Ptr<Header>` over
  `{ i32, i32, i16 }` is `align 4 dereferenceable(12)`. Overloads on the pointee type or the
  capability are distinct functions, and the exactly-typed one wins (`test_292`, `test_294`,
  `neg_294`). Volatile access is stage 5.
- **Writing through a `Ptr<mut T>` (stage 3).** `p.field = v` stores into a field of the pointee (a store at the
  field's own width and alignment), `packet.header.magic = v` through two, and `p.store(v)` writes a scalar
  pointee (`__builtin_ptr_store`). A pointer field takes a pointer: `node.next = other`. Refused with the way
  out: a write through a read-only `Ptr<T>` (take a `Ptr<mut T>`), a struct-typed field (`p.header = q`; write
  its fields), `p.store` of a struct, and `p = 5`, which would replace the pointer rather than write the value.
  `p.field += 1` is still refused, as it is for any field (compound assignment needs a plain variable): write
  `p.field = p.field + 1`. Access through a `volatile` pointer, read or write, is refused until it has its own
  access (`test_295`, `neg_295`).
- **Where a `Ptr<T>` points, stepping it, and making one (stage 4).** `p.addr` is a `Usize` property. Motion is
  by method, so `p + 1` stays the value and a pointer cannot be stepped by accident: `p.offset(n)` (one
  `getelementptr inbounds`, in elements, so a 12-byte struct steps 12), `p.byteOffset(n)`,
  `p.wrappingOffset(n)` (no `inbounds`, for a ring), `p.offsetFrom(q)` (elements, exact), `p.isAligned(a)`,
  `p.sameAs(q)` (where they point, which `==` between two pointers refuses to guess), and
  `p.advance(n, limit)`, which answers `none` rather than pass `limit` in the direction of travel and
  compiles to a branchless select. The constructors are `std.raw`'s and need `import std.raw`, which is the
  whole of the unsafe marker: `Ptr<T>.at(address)` and `.castAligned(p)` answer `Ptr<T>?` (none for 0 or an
  address the pointee cannot sit at), `.atUnchecked(address)` and `.cast(p)` trust the caller, and a
  read-only pointer cannot be cast to a `mut` one. A `Ptr<T>?` is unwrapped with `expect`; there is no flow
  narrowing. `Ptr<mut T>.at(...)` also parses now, which the type-argument scan in expressions had missed
  (`test_296`, `neg_296`, `neg_297`).
- **Volatile and atomic access through a `Ptr<T>` (stage 5).** Every access through a `Ptr<volatile T>` is volatile:
  `p.load()`, `p.store(v)`, a scalar operand, a field read or write, and a struct inside it, so a driver cannot write
  one register access the optimiser may drop or hoist; a `Ptr<volatile T>` parameter is not promised readable, so it
  gets no `dereferenceable`. `p.readVolatile()` and `p.writeVolatile(v)` are the one-off form. The atomics are
  `p.atomicLoad(order)`, `atomicStore`, `atomicSwap`, `atomicAdd`, `atomicSub`, `atomicAnd`, `atomicOr`,
  `atomicXor` and `atomicCompareExchange`, with the ordering written at the call as a variant of the new
  `AtomicOrder` in `std.raw` (`Relaxed`, `Acquire`, `Release`, `AcqRel`, `SeqCst`), which also closes the weaker-orderings
  gap `docs/FREESTANDING_PLAN.md` listed. The pointee is an integer, a write needs `Ptr<mut T>`, a load cannot release and
  a store cannot acquire, and a compare-exchange derives its failure ordering from the success one. A new `typed_pointer_ir`
  harness test checks the emitted `load volatile`, `store atomic ... release`, `atomicrmw ... acq_rel` and `cmpxchg` and the
  parameter attributes, since none of it shows in a program's output (`test_297`, `test_298`, `neg_298`).
- **Nested functions.** A `fn` written in a function body is a private function that
  captures nothing, visible in the block that declares it, callable before its
  declaration and recursively; two functions may each have a `helper`, and a method
  may have one. The parser lifts it out as `outer$inner`.
- **A closure may have a block body**, `|x: Int| { let y = x + 1  y * 2 }`, and the
  block's last expression is its value. A function body still answers only through
  `return`, and its error now says so.
- **Visibility on global `let`s, structs and fields**, with the levels a function has:
  `public` (everywhere), `internal` (the package), `private` (the file). A struct is
  `internal` unless marked and a field `private`, so `public struct Point { public x:
  Int, y: Int }` is a public type with one public field; a struct literal needs every
  field visible. An unmarked global stays open to every file. Enums are not enforced
  yet and a marker on one is refused.
- **An array's length is a constant expression**, `Array<U32, N * N>`, over numbers and
  non-`mut` globals, and an integer global may be initialised by one:
  `let CELLS: Usize = N * N`.
- **Ranges and indexing across integer types.** `for i in 0..<MATRIX` over a `Usize`
  (or `U32`, `I64`, `U8` ...) counts in that type, and a `Vec`, array or `String` is
  indexed by any integer: a value no `Int` holds is out of range rather than wrapped
  into it. The loop is the `Int` one over a count (`sema/ranges.psm`), so every proof
  about loops still applies; a range with more than 2^31-1 values stops with an error
  when entered. `bench_matrix_multiply` written this way is 9.96 M instructions, the
  same as the C arm.
- **`std.raw`, `std.port` and `std.asm`**, the clean surface for what freestanding code
  used to reach with `__builtin_*`: address and pointer conversion, volatile and
  unaligned access, atomics on 8- to 64-bit words, a fence, `swapBytes`, and a Float's
  bits (`x.bits`, `Float.fromBits`) in `std.raw`; `portInU8` and friends in `std.port`; `asm`, `asmRead` and `asmWrite` in
  `std.asm`, which the compiler lowers where the text is written because the text has to
  be a literal. All three are freestanding-safe and call nothing in the C runtime.
- **Float text is Prismio** (`std/float_text.psm`): `toString`, `toString(places)`,
  `parseFloat`, `as String` and `as Float?` no longer call `snprintf` and `strtod`, so
  a `--freestanding` program can format and parse a Float (`kernel_float_aarch64.psm`
  boots under QEMU and does). A `Decimal` of up to 800 digits shifts and rounds the
  exact expansion of a double, so rounding is correct by construction; a Clinger fast
  path (one multiplication or division by an exact power of ten) takes the ordinary
  cases. Output is digit-for-digit what the C functions gave: 1.1 million bit patterns
  for `toString`, 200,000 for `toString(places)` and 300,000 texts for `parseFloat`
  (`tests/test_276_float_text.psm` keeps a table of the edge rows). One difference:
  `"nan(a-b)"` is `none` (C99 allows letters, digits and `_` between the brackets; macOS's
  `strtod` took anything), and `toString(places)` of NaN or an infinity is `nan`, `inf`
  or `-inf` on every platform where it used to follow the C library. `toString` of
  a Float is 2.7× faster than the C search on short values and 6× on 15-digit ones
  (0.25 µs against 0.67 µs and 0.16 against 1.0), `toString(places)` 1.75× slower
  (0.1 µs), `parseFloat` equal to C up to 19 digits and 7× slower past them (0.15 µs).
  Whole-suite A/B against the previous compiler: hosted Prismio geomean 0.996 over 65
  workloads, binaries the same size, 20 freestanding workloads with identical
  instruction counts, compiling the 66 programs 7% slower (837 ms to 910 ms) because
  `std.string` now carries 35 more functions. `print(Float)` and its siblings format
  through the same code, so the console and `toString` cannot disagree; what that
  costs a program that never prints a Float is what the unreachable-function pruning
  below removes. `std.float_text` is importable freestanding.
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
- **A heap in `--freestanding` programs: `Vec`, `String`, `Map` and `std.mem` in a kernel.** The
  program defines `prismio_alloc`, `prismio_realloc` and `prismio_free` (in Prismio with `export fn`, or
  in C), and the build compiles `lang_runtime.c` for the program's own triple and CPU features with
  `PRISMIO_FREESTANDING`: no C library, `runtime/freestanding/libc.c`'s weak `memcpy` family and `qsort`,
  runtime errors through `prismio_panic_hook`, no locks. Only a program that imports a module over `Vec`
  or `String` gets it; one that imports none links what it did before. Every `std` module but `io`,
  `display`, `input`, `fs`, `process`, `time`, `term` and `math` is now importable (was `option`,
  `platform`, `iter`). A freestanding program is internalised like a closed hosted one, since its C
  reaches Prismio only through `main` and `export`; the freestanding benchmarks did not move (0.95× C).
  `kernel_mem_aarch64.psm` boots under QEMU with a bump allocator
  written in Prismio, and a Buffer read out of range reaches the panic hook. FREESTANDING_PLAN step 6.
- **`__builtin_swap_bytes`, `__builtin_float_bits` and `__builtin_float_from_bits`**:
  byte order reversed at any integer width (one `rev`/`bswap`), and a Float and its
  64 bits reinterpreted either way. **`__builtin_mem_uload_*`/`ustore_*`**: loads and
  stores at any alignment, of memory the compiler may treat as byte storage only.
  They carry a type-based alias tag of their own, so a store through one does not
  force LLVM to reload a list's length or data pointer. `std.mem`'s typed Buffer
  accesses are built from them: `binary_codec` went 1.03× → 1.00× C++, with every
  bounds check gone from both of its loops.
- **`x[i] = v` on a struct calls its `set`**, as `x[i]` already called its `at`. A struct
  with an `at` and no `set` keeps the error, which now says to write
  `fn set(inout self, index, value)`. A generic struct's `set` is not reached yet, so a
  `Map` is still assigned with `m.set(k, v)`.

- **`-Os` and `-Oz`.** Size levels for `prismio build`: every function is marked `optsize`
  (`-Oz` also `minsize`, which turns on AArch64's machine outliner) and runs LLVM's O2 pipeline,
  since LLVM 23 has no Os pipeline of its own; `-Oz` also leaves the loop vectorizer off, as
  clang does. On the hosted benchmark program `__text` goes from 181,320 bytes to 115,368 at
  `-Os` and 81,532 at `-Oz` (the file from 242 KB to 177 KB and 152 KB). Not a default: the
  outliner alone cost 4.1% geomean time on the hosted benchmarks (`sort_strings` 43%).

### Changed

- **The second half of the IR pipeline runs in the codegen partitions, in parallel.** `default<O3>`
  is now run in two halves through the C++ bridge (`prismio_llvm_run_default_half`, built exactly as
  `buildPerModuleDefaultPipeline` builds it): the module simplification pipeline -- the inliner and
  everything it drives -- on the whole program, then the module optimisation pipeline (loop
  rotation, vectorisation, unrolling and their cleanups, one function at a time) inside each
  partition, on its thread. Every inlining decision is still made on the whole program. On the
  compiler's own build the pipeline plus machine code takes 3.63 s (was 4.30 s), on the hosted
  benchmark program 552 ms (was 662). It is not byte-identical to one `default<O3>` -- analyses the
  first half leaves cached cannot cross into another thread -- so it was measured: 47 hosted
  workloads at ten times their size, geomean 0.995 against 1.000 for an identical-binary control,
  every result equal. A program too small to partition keeps the single pipeline and its exact
  output. `PRISMIO_SPLIT_PIPELINE=0` turns it off; Windows, with no bridge yet, runs it whole.
- **Machine code is emitted in parallel for `-g` and `-O0` builds too, and every partition reads
  only its own functions.** A `-g` build used to emit on one thread, on the belief that the
  debug map wanted one object; each partition now carries the compile unit and the subprograms
  of what it emits, as an LTO-partitioned link does (`dwarfdump --verify` clean, breakpoints,
  locals and globals in lldb identical to a one-partition build). Each partition also used to
  parse the whole module and delete seven-eighths of it; it now loads the bitcode lazily and
  materialises only its own bodies (`prismio_llvm_drop_body` in the bridge drops the rest
  unread). On the compiler's own build, machine code takes 216 ms at `-g` (was 512) and 608 ms
  in release (was 754), with byte-identical output. Windows, which has no bridge yet, parses
  whole as before.
- **macOS programs bind through chained fixups, and a small one is 16 KB smaller.** At the
  deployment floor ld64 used lazy binding, whose `__la_symbol_ptr`, `__stub_helper` and
  `__dyld_private` gave `__DATA` file contents and so a whole 16 KiB page. Linked with
  `-fixup_chains`, hello is 33,952 bytes (was 50,504; C's is 33,424) and its `__DATA` is
  zero-fill only. A program whose `__DATA` has initialised data of its own keeps the page.
- **A build big enough for parallel codegen links through `ld` directly too.** The cached
  `ld` line (2026-10-10) took only a program with one object, so every build split into
  codegen partitions went back through the `cc` driver: the hosted benchmark program linked
  in 29.9 ms, now 16.9 ms, as hello does. The cached line names the first object once and
  the build puts the other partitions back after it, in the order the driver had them, so the
  executable is byte-identical to the driver's.
- **A local may be declared without a value, and every read the compiler cannot prove
  follows an assignment is an error** (`sema/assign.psm`): ``` `r` may be used before it
  is assigned ```. Branches join, a path that returns, breaks, continues or panics
  contributes nothing, a `match` must cover every variant or have a `_`, and a loop that
  may run no times assigns nothing as far as the code after it can tell. An immutable
  `let` declared this way takes one assignment (a second, or one a loop could repeat, is
  an error); assigning a field of an unassigned struct is a read of it. `let x: T =
  default` still asks for the type's default, and an array, a `Vec` and a `Map` keep
  their empty or zeroed start.
- **`__builtin_*` is the standard library's.** A program that writes one is refused,
  with the wrapper to write instead (`s.length`, `min(a, b)`, `portOutU8(port, v)`,
  `volatileLoadU32(address)`, `asm("nop")`). The compiler's own `src/`, `ums/`, the
  tests, the benchmarks and the sandbox moved to the wrappers. `nowrap` proofs treat
  `std.math`'s `min` and `max` as the builtins they wrap.
- **Structs are `internal` and their fields `private` unless marked.** The tree was
  migrated by compiling every entry point and widening each declaration to the level
  its uses need: `internal` within a package and `public` across them. The standard
  library's structs a program names (`Buffer`, `Arena`, `Duration`, `Instant`,
  `Args`, `Child`, ...) are `public`. **`src/` now uses the new syntax, so the pinned
  seed can no longer parse it.** A seed was cut from this tree and a compiler built from
  only that seed reproduces its own IR; publishing it and committing the pin is open
  (`docs/KNOWN_ISSUES.md`), and until then a clean checkout cannot bootstrap.
- **The runtime and library bitcode is merged lazily on macOS and Linux.** Every library module
  is read with `LLVMGetBitcodeModuleInContext2` (prototypes only), the set of definitions the
  program reaches is computed across all of them, and `Linker::LinkOnlyNeeded` links just that
  set, where every function was parsed and linked and most were then pruned. The one thing
  LLVM-C cannot say is in `runtime/llvm_bridge.cpp` (`prismio_llvm_materialize`,
  `prismio_llvm_link_only_needed`), a new compiler source; Windows links `LLVM-C.dll`, which
  has no C++ API, and keeps the whole-module merge until it links LLVM statically
  (`docs/LLVM_BRIDGE_PLAN.md`). A hello-world build is 36.1 -> 34.5 ms (median of 40); the
  library read alone is 1.1 ms cold against 3-4 for a whole parse. The program is the same
  in everything but order: the merged module has the same functions and globals, and 135 of the
  136 test programs whose binary changed have the identical symbol set and size (the other is
  16 bytes smaller). IRMover lays functions out in discovery order, which ran through bodies
  that are no longer read. The hosted benchmark suite, whole against lazy, is a geomean of
  1.0007 across 66 arms; two runs of the *same* compiler are 1.0154, with 7 arms beyond their
  own noise tolerance against 2, so the layout change is inside run-to-run noise.

- **A macOS program links by running `ld` directly**, not `system()` -> `/bin/sh` -> `cc` ->
  `ld`. The driver is asked once with `-###`, and its `ld` line is kept in
  `$TMPDIR/prismio-link-cache` with the object and output as markers, keyed on the driver
  line and `DEVELOPER_DIR`/`SDKROOT`/`MACOSX_DEPLOYMENT_TARGET`. Every absolute path the line
  names (the linker, the SDK, `libclang_rt.osx.a`) and `/var/db/xcode_select_link` are
  recorded by identity, so an Xcode update or `xcode-select --switch` sends the next build
  back to the driver; an `ld` that fails falls back to the driver and drops the entry. Only
  for a program with no native objects, link arguments or exports. Building one line that
  prints: 46.3 ms to 36.0; all 254 `tests/test_*.psm` programs build byte-identical
  binaries, in 26.1 s against 28.9. `PRISMIO_LINK_CACHE=0` links through the driver.
- **Standard-library functions a program cannot call are dropped after type checking**
  (`src/driver/prune.psm`), so the ownership analysis and IR generation never see them.
  Reachability is read off the calls sema resolved, closures and function values included,
  and a trait object keeps every method of the impl it was built from; a program's own
  functions are always kept, so no diagnostic depends on it. Printing one line: ownership
  analysis 0.61 ms to 0.09, IR generation 0.95 to 0.24. `PRISMIO_PRUNE=0` turns it off.
  **It is not output-neutral, deliberately:** a dead function used to decide how a live one
  compiled. `region_confined` counted dead callers, so the `eprintln` overloads a program
  never called made `std.io`'s `write` look reachable from outside a region and let the cost
  model bracket an arena around a `println` -- an opaque call the obligation exists to
  refuse. `test_62_split_release` and `forced_layout` leaned on that and now do their work
  outside the printing function. `prismio aif` lists the imported sites the program can
  reach, not every one in the modules it imports.
- **Flat-guard verdicts are per function, not per name.** A call is judged by the function
  sema resolved it to (`CALL_EXPR.s2`), falling back to its source name only when it has
  none. By name, one unsafe overload poisoned every call spelled the same: `Buffer.eq`
  reaching an extern took the guard from every `Map` probe in a program importing
  `std.mem`, and one closure that pushes took it from every closure call. The benchmark
  binary is now identical with pruning on and off. Against `65de043` (C Float printers, no
  pruning, name verdicts), with both compilers bootstrapped two generations and the suites
  interleaved, 3 x 15 runs: hosted geomean 0.998 over 66 workloads, five functions with
  different instructions (the two `listSortRange` instantiations gain their guards,
  sort_strings 5.9% faster), the binary the same 242,128 bytes, the suite compiled in
  842 ms against 862. `gcd_lcm` (+12%) and `edit_distance` (-15%) are identical
  instructions at another address.
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

- **A sieve runs as a segmented sieve, from the plain source** (`src/ir/tiling.psm`,
  developer docs: Stride tiling and square bounds). A nest that stores one value at a stride -- `while (..) {
  if (v[p]) { let mut m = ..  while (m <= n) { v[m] = false  m = m + p } }  p = p + 1 }` --
  gets a copy that runs the outer loop with each inner loop cut at a 64 KB window (32 KB off
  Apple silicon), then sweeps every later window across all the recorded iterations. Stores
  of one value commute, so only the guard's reads could tell, and those all land in the first
  window; any iteration the copy cannot match exactly hands over to a plain copy of the loop.
  Two windows or more, a flat list, every store in range; nothing else in `src/`, `tests/` or
  the benchmarks matches. Whole sieve on an M5: 1.18 ms to 0.70 ms at n = 10^6, 13.8 to 7.3 ms
  at 10^7, 339 to 80 ms at 10^8 -- the hand-tiled C's 0.71, 7.6 and 84. Hosted `prime_sieve`
  482 to 420 µs, against C++'s 454 and Rust's 622. Packing `Vec<Bool>` to bits was measured
  and rejected: 0.21x-1.06x, tiled or not.
- **`x * x <= n` bounds `x`** (`emitSquareBound`, `src/ir/ranges.psm`). The square is `Int`
  arithmetic, so the range guard folds a start within 46340 and `isqrt(n) + step <= 46340`,
  and then `x <= isqrt(n)` in the body. A sieve's outer loop proves `prime[p]` (it was checked)
  and its `p = p + 1` becomes `nsw`, the fact LLVM needed to count the inner `m += p` loop and
  interleave its stores: 8-15% on a sieve whose `n` is read at run time. The hosted benchmark's
  `n` is a constant LLVM had already propagated; there this alone measured 1.5% slower with the
  hot loop instruction-identical, which is layout.
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
- **A copy loop is one `memcpy`, and a repeated one is deleted.** `for i in a..<n
  { dst[i] = src[i] }` on two flat `Vec`s now becomes a single block transfer under
  a length guard, as the `while` spelling already did. The transfer is a `memcpy`
  skipped when both names are one list, and it tells LLVM the two blocks are
  separate allocations, so a copy nothing reads before the next identical one is
  deleted — which is what C++ and Rust do with `std::vector` and `Vec`.
  `large_buffer_copy` (eight identical rounds) goes from 1.16× of C++ and 1.17× of
  Rust to 1.00× and 1.02× (6.5 → 5.6 ms, three interleaved pairs).
- **A counted fill reserves its final size whatever else the body does.** `for i in
  0..<n { let v = i % 997  xs.push(v)  sum = sum + v }` used to reserve nothing,
  because the reservation required the push to be the loop's only statement, and
  the empty list then failed the capacity guard: every push was an out-of-line
  call. Any push that is a statement of the body (not in an `if`) now counts, in a
  body with no `break`, `continue` or `return`, and the reservation is one exact
  `list_reserve` rather than a doubling loop from 4. `vector_growth` goes from
  11.34 to 9.63 ms (0.85×; 1.06× of C++ to 0.90×) with peak RSS 34.7 → 17.1 MB, and
  `transient_allocation` from 0.593 to 0.395 ms (0.67×); minima of 15 interleaved
  pairs, checksums equal, 15 other changed benchmarks within ±1%.
- **A heap `Vec` grows by `realloc`.** `list_inline_grow` and `list_push_grow` allocated
  a block twice the size, copied and freed the old one; a list with no arena now asks
  the allocator to extend its block, which it can do in place or, for a large block,
  by remapping pages. A list from an arena, or grown while an arena hint is active,
  keeps the old path. `word_frequency` runs in 0.90× (31 interleaved pairs); the other
  hosted benchmarks are within noise, most of their fills being reserved up front by
  the change above.
- **A remainder by a literal is a conditional step when its dividend allows.** A
  local that a loop assigns only remainders by a literal keeps that remainder's range
  at the loop's head, and a `%` whose dividend then lies in (-2m, 2m) becomes compares
  and selects instead of a multiply-by-magic-constant `srem` (`src/ir/residues.psm`).
  `checksum = (checksum + value) % 1000000007` is the case: `vector_growth` goes from
  9.67 to 4.06 ms (0.42×), and in the suite from 1.06× of C++ to 0.46× (0.50× of
  Rust) with the reservation above; `polynomial_evaluation` 0.91×,
  `recursive_tree_rebuild` 0.97×; minima of 21 interleaved pairs, checksums equal.
  A dividend whose range is not bounded, or does not fit `Int`, keeps the `srem`.
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

- **`-O0`..`-O3` did not set how the program was optimised.** The program's object step was
  fixed at O3 (O0 with `-g`); the flag only ran a second `default<O<n>>` over the frontend's
  module before it. So `-O0` was a fully optimised build and `-O3` optimised twice: the hosted
  benchmark program built in 0.86 s with no flag, 0.89 s at `-O0` and 1.15 s at `-O3`. The flag
  now sets the object step's level (and the machine-code level, as clang maps it): `-O0` 0.30 s,
  `-O1` 0.58 s, `-O2` 0.81 s, `-O3` 0.86 s, all 66 workloads agreeing. With no flag nothing
  changes. `-g -O2` is an optimised build with DWARF. `-o x.ll -O<n>` still writes optimised IR,
  and `run --jit -O<n>` now optimises the merged module rather than the program alone.
- **A trait-object call in a loop could reallocate the Vec the loop read through its
  flat guard.** The guard analyses judged calls by `CALL_EXPR`, and a `dyn` call is a
  `DYN_CALL`, so it fell through as an ordinary expression: an impl that pushed to the list
  left the guarded copy reading the freed element block (`walk` in
  `tests/test_277_guard_dyn_call.psm` summed 27 for 28). `DYN_CALL`, `SPAWN_EXPR` and
  `JOIN_EXPR` now decline the loop in all three analyses.
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
- **A `match` arm that returned the payload it bound returned freed memory** when the
  scrutinee was bound first: `let r = parse(t); match (r) { Result.Ok(v) => { return v } }`
  printed eight NUL bytes where the text started (`--verify` does not show it, since its
  allocator does not reuse a freed block at once). The drop guards followed `let`s and
  assignments but not match binders, so `return v` was not seen to return `r`'s allocation
  and `r` was dropped at the scope exit. A binder now counts as an alias of its scrutinee,
  and a scalar identifier never does. The `Result` is kept alive on that path, which is a
  leak and not a free: `test_273_match_payload_returned` pins 300 of 400 blocks and asserts
  the values.
- **An owned temporary read by index in a condition, or matched on, leaked.**
  `if (v.sorted()[0] != 1)` (a `Vec` index is `list_get`, which the temporary-hoisting pass
  did not treat as a scalar read) and `match (parse(text)) { ... }` (the scrutinee was
  itself the temporary) now get a binding like the `let` the program could have written
  (`test_251` 4 of 45 blocks leaked, now 0). A temporary on the right of `and`/`or` is
  still not hoisted.
- **`p.arguments = [...]` on a fresh `Process()` leaked the list the constructor made**, one
  56-byte block per spawn. An assignment now releases the list it displaces when the
  receiver is a local declared in the same block, nothing has touched it since (a store to
  another field does not count), the right-hand side does not mention it, and the type is
  reclaimed and releases that field as a list. `test_153`, `test_183`, `test_188`,
  `test_258` and `test_259` read clean (33 blocks); a parameter, a loop, a second assignment
  or any earlier read keeps the old behaviour. Across `tests/` under `--verify`: 192 leaked
  blocks in 25 programs before, 163 in 19 after (plus the 300 pinned above), 0 violations.
- `test_259_display_print` no longer fails its own stderr check under `--verify`, where the
  child's ledger lands in the stderr it compares.
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

- **`prismio verify` and `prismio gate` package the freestanding failure core.** Neither passed
  `--freestanding-target`, so the candidate they tested had no `lib/runtime/freestanding`, and any
  freestanding benchmark with a failure path (`prismio_panic`) failed to link in `freestanding_bench`,
  while the project's own toolchain, which has the core, built it. Both now package
  `aarch64-unknown-none-elf`. `prismio release` still does not.
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
