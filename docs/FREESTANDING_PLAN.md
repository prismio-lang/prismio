# Freestanding Prismio: what a kernel needs, and the order to build it

The plan for compiling Prismio programs that run with no operating system under
them: a kernel, a bootloader stage, firmware. Written 2026-10-08, with a
dependency probe (section 1) as its starting measurement. **Steps 0-6 and most of
step 7 are built** (section 3); step 6, the heap, landed 2026-10-09 (FREESTANDING_MEMORY.md).

A Prismio program now boots under QEMU's `aarch64` `virt` board and on a 32-bit x86
machine with no operating system and no C library, prints through a volatile store
or a port write, panics through a hook, and exits. The entry stub, the serial output,
the exit and the hook are written in Prismio; what remains in C is the failure core
the compiler adds (`runtime/freestanding/panic.c`).

"Kernel" means a standalone kernel written in Prismio that boots under QEMU, not
compiling the Linux kernel, which requires a C compiler's extensions.

The same blocker is `KNOWN_ISSUES.md`'s "WebAssembly is blocked": there is no C
library for the target, so the runtime cannot be built for it. A freestanding
runtime profile unblocks both.

## 1 · What the probe measured (2026-10-08)

Method: six programs built out of tree with a copy of `dist/Prismio` renamed to
`pprobe` (the launcher forwards by basename), on macOS arm64, `nm -u` on the
result. The packaged toolchain is the 2026-10-08 `dist`, not HEAD. Sources are in
the appendix.

| Probe | Uses | Binary | Undefined symbols |
|---|---|---|---|
| p0 | `return 0` | 16,784 B | none |
| p1 | `while` loop, `Int` arithmetic | 16,784 B | none |
| p2 | struct of `U8/U32/U16`, `Array<Int, 4>`, `as` | 16,784 B | none |
| p4 | indexed array loop, division | 16,784 B | none |
| p3 | `Vec<Int>.push`, `String` literal `.length` | 51,328 B | `malloc free realloc malloc_size memcpy`, `pthread_mutex_*`, `pthread_once` |
| p3, `--overflow-checks` | the same | 51,552 B | adds `fprintf fwrite __stderrp exit` |
| p5 | `println("hi")` | 50,496 B | `write fprintf __stderrp __error exit malloc free` |

**Linux (added 2026-10-08).** The same six programs on Ubuntu 26.04 aarch64 (glibc), hosted, `nm -u`:

| Probe | Binary | Undefined symbols |
|---|---|---|
| p0, p1, p2, p4 (scalars, structs, arrays, division) | 70,496 B | `abort`, `__libc_start_main` |
| p3 (`Vec`, `String`) | 72,400 B | the above plus `malloc free realloc malloc_usable_size memcpy`, `pthread_mutex*`, `pthread_once` |
| p3 with `--overflow-checks` | 72,664 B | adds `exit fprintf fwrite stderr` |
| p5 (`println`) | 71,376 B | adds `write __errno_location exit fprintf stderr malloc free` |

The picture matches macOS: scalars need only the C startup (`__libc_start_main`; `abort` is the compiler's
trap for unreachable code), heap types bring the allocator and `pthread`, I/O brings stdio. The
x86_64 Linux row is still unmeasured: the VM is aarch64.

**1.1 The compute core is already freestanding-clean.** Scalars, structs, fixed
arrays, loops and calls lower to plain LLVM with no runtime call. The 16 KB is
the OS loader's startup, not Prismio. The kernel does not need a rewrite of code
generation; it needs the *absence* of the runtime to be a supported mode.

**1.2 Heap types are the boundary.** `Vec`, `String` and anything else that
allocates pull in the allocator, `pthread` (the allocator and the cycle collector
take a mutex) and, with checks, stdio. `import std.io` costs about 34 KB and five
libc families for one `println`.

**1.3 Fixed arrays are not bounds-checked.** `a[i % 5]` on a 4-element array
lowers to `getelementptr inbounds` and a load: out-of-range is undefined behavior,
not a trap (p4's IR, read directly; the run's exit status 133 is the division
by zero that follows, not the out-of-range read). That is what a kernel wants for a
hot path and what it does not want for memory safety. Needs an explicit decision
(section 3, step 1). A `Vec` read out of range answers the element type's zero
(documented in `arrays-and-lists.md`), which is a third behavior.

**1.4 Division by zero is a raw `sdiv`.** No guard and no runtime call. On x86 that
is a #DE fault; the kernel's handler owns the result. Fine, and worth stating.

**1.5 The entry point is hosted.** Every program is emitted as
`main(i32 argc, ptr argv)` storing both into the globals `prismio_argc` and
`prismio_argv`. A kernel has neither. The IR also declares `malloc`, `rt_free` and
about 40 `list_*`/`str_*` runtime functions in every module, unused until called.

**1.6 The cross path is not shipped.** `--target x86_64-unknown-linux-gnu` writes
IR with the right triple and datalayout but the build stops at *"Missing runtime
module: `lib/runtime/x86_64-unknown-linux-gnu/lang_runtime.bc`"*. Even a program
that calls none of the runtime needs the file to exist. That check is the first
thing a freestanding mode removes.

**Not measured:**

- `--overflow-checks` on a scalar-only program (**resolved in step 0**). `sum(10)` constant-folded, so the
  call to `prismio_overflow_trap` (which is defined in `lang_runtime.c:3108` and
  prints through `fprintf`) never reached the link. Re-probe with a value the
  optimiser cannot see. It decides whether overflow trapping needs its own
  freestanding handler.
- Anything on a Linux or bare-metal host. All numbers are macOS arm64.
- Whether `-O3` changes the heap-type symbol set. The table is from `-O0` and the
  default.

## 2 · Gaps, ranked by how much each blocks

| # | Gap | Evidence | Blocks |
|---|---|---|---|
| G1 | ~~No freestanding build mode~~ **done for single-file builds (step 1)**; manifest surface open: link goes through `cc` and libc, the runtime `.bc` must exist per triple | 1.6, `KNOWN_ISSUES` "Linking needs the platform's C toolchain" | everything |
| G2 | Hosted entry point and argv globals | 1.5 | boot |
| G3 | Panic, overflow trap and bounds failure all end in `fprintf` + `exit` | `lang_runtime.c`, p3 with checks | any checked build |
| G4 | The allocator and cycle collector take a `pthread` mutex | p3 | any heap type |
| G5 | ~~`Ptr` is opaque~~ **address builtins (step 3)**; no typed pointer | `types.md`, `ffi.md` | |
| G6 | ~~No volatile, atomics, asm~~ **done (step 3)**; weaker orderings and multi-operand asm open | `concurrency.md` | |
| G7 | ~~Struct fields reordered~~ **`repr(C)`, `packed` (step 4)** | `KNOWN_ISSUES` | |
| G8 | ~~No `section`, `naked`~~ **done (step 4)**; no interrupt calling convention, no static data placement | | |
| G9 | `Bool` is one bit wide | `ffi.md` | hardware layouts (use `U8`) |
| G10 | ~~No target features~~ **done (step 1)**; no RISC-V | LLVM target list | |
| G11 | ~~No `core`~~ **three modules (step 5)**; the rest wait on G12 | `std/` listing | |
| G12 | Ownership with no heap: **designed (FREESTANDING_MEMORY.md)**, not built | AIF assumes `rt_base_alloc` | any heap type |

## 3 · The build order

Each step ends with a test that fails before and passes after, and a decision
recorded in this file. Steps 1-4 are the minimum for the first milestone; the
milestone itself is listed after.

### Step 0 · Finish the probe — done 2026-10-08

- [x] Re-probe overflow checks with a value the optimiser cannot see (G3). The
      value comes from a `volatile` the boot stub defines and the program reads
      with `extern let`. **Result:** a checked `+` calls
      `prismio_overflow_trap(op, file, line)`, which in the installed runtime
      prints through `fprintf` and calls `exit`. The first version of this test
      used a constant and the trap was folded out of the binary; it passed and
      proved nothing.
- [x] Probe on a non-macOS target. Docker (colima) was not running, so the Linux
      host row is **still unmeasured**; what was measured instead is an ELF
      target, `aarch64-unknown-none-elf` and `x86_64-unknown-none-elf`, linked by
      lld, where an undefined symbol is a link error naming it. That is a
      stricter check than `nm -u` on macOS, which hides `libSystem`.
- [x] A regression test: `run_freestanding_test` in `tests/test_runner.py`
      (fixtures in `tests/freestanding/`). It asserts a scalar-only program links
      with no runtime, that a `std` import is refused by name, and boots five
      kernels under QEMU. It skips, and says so, without `ld.lld` or
      `qemu-system-aarch64`.
- [ ] A negative probe per heap type asserting the exact symbol set. Dropped as
      unneeded: every heap type needs a `std` import, and the import is refused
      before codegen, so the symbol set is unreachable. A runtime symbol a
      program can reach without an import (`prismio_expect`, the failure
      functions) is covered by `runtime/freestanding/panic.c`.

### Step 1 · A `freestanding` profile — built

**Finding that changed this step:** most of the machinery already existed. A
manifest target with `runtime = "none"` skips the runtime merge (so the
per-triple `lang_runtime.bc` check goes with it), `native { source(...) }` compiles
C with the toolchain's clang, and `link { responseFile(...) }` carries arbitrary
linker arguments. What was missing was the **target triple** (a manifest cannot
name one, only the single-file CLI can), the **libc-free link command**, and the
**object settings** a kernel needs. Those are done; the manifest surface is not.

- [x] `--freestanding`. No installed runtime merged, so no
      `lib/runtime/<triple>/` is needed (1.6). Link is
      `-nostdlib -static -fuse-ld=lld` with no `-lm`/`-lpthread` and no
      `-dead_strip`. Native C compiles with
      `-ffreestanding -fno-pic -fno-stack-protector`. Object code is static, not
      PIC.
- [x] `--native <file>`, `--native-flag <flag>`, `--link-arg <arg>`: the boot stub,
      its compile flags, and `-T kernel.ld`, from the command line.
- [x] `--target-features <list>`, `--code-model <small|kernel|medium|large>`,
      `--no-red-zone` (a `noredzone` attribute on every defined function). Built
      for x86_64 with `-sse,-sse2,-mmx,+soft-float` and the kernel code model,
      and checked in the IR; **not booted**, because QEMU's `-kernel` does not
      load a 64-bit x86 ELF and a Multiboot stub is its own piece of work.
- [x] `std.*` is refused at the import (`P1094`), by module name, in every
      layout. An earlier draft did it in the C driver and was wrong: inside a
      checkout `std` is compiled from source, so the gate never fired and the
      failure was a page of undefined `list_*` symbols.
- [x] The entry stays `main`. A boot stub calls it as `main(0, 0)`; the two
      `prismio_argc`/`prismio_argv` stores are dead and fold away. A renamed entry
      symbol is not needed until a Prismio function must be the machine entry,
      which waits for `naked` (step 4).
- [x] **Manifest surface.** A target in `build.ums` takes `freestanding`, `triple`, `features`, `codeModel`
      and `noRedZone`, and `link { }` takes `script("kernel.ld")` and `arg("...")`. The triple is selected for
      the target and reset to the host after it, so one project can build a kernel and a host tool.
- [ ] Fixed-array bounds checks (1.3). Still unchecked; the decision stands as
      proposed (unchecked by default, `--bounds-checks` through the panic hook).
- [x] `runtime/freestanding/panic.c` ships in the toolchain (`lib/runtime/freestanding/`, by
      `tools/package.py --freestanding-target`) and `--freestanding` adds it itself.
- [ ] `tools/check_externs.py` reads the packaged `dist/`, so it reports the new
      externs as undefined until the toolchain is repackaged. Not a defect; do not
      mistake it for one.

### Step 2 · A pluggable panic path — built, as a separate file

**Departure from the plan:** `lang_runtime.c` is not split. Splitting it moves
`rt_free`, which codegen emits for every release, and the byte-identical-output
rule makes that a large change for no gain here. The freestanding failure core is
a new file that shares no code with it.

- [x] `runtime/freestanding/panic.c`, no includes, no libc: the six functions
      generated code calls when something fails (`prismio_overflow_trap`,
      `prismio_step_check`, `prismio_panic`, `prismio_unreachable`,
      `prismio_assert_failed`, `prismio_expect`), each one call to
      `prismio_panic_hook(kind, detail, file, line, col)`, which the program
      supplies. A weak default halts silently so a program that never fails need
      not define one. It lives in `runtime/freestanding/`, not `runtime/`, so
      `tools/check_source_lists.py` does not count it as a compiler source.
- [x] Tested end to end: an overflow with checks on reaches the hook with the
      file and line; the same program with checks off wraps to `-2`; `panic("boom")`
      reaches it; the exit status distinguishes a return from a panic.
- [ ] A hook written in Prismio. Needs a way to give a Prismio function an
      unmangled C symbol (`export`), so it is step 4's, not this step's.
- [ ] `prismio_expect` on a `T?`, and the Vec index failure, once a heap exists.

**Two defects the tests found in their own first drafts, worth keeping:** (1) a
stub that loaded a constant with a NEON `ldr q0` hung the kernel with no output,
because the first FP/SIMD instruction traps at the exception level QEMU enters and
nothing has installed a vector table. `-mgeneral-regs-only` and
`--target-features -neon,-fp-armv8` are the fix, and a real kernel needs the same
or an explicit FP enable. (2) The overflow test first passed with its trap
optimised out.

### Step 3 · Memory, atomics and assembly — built as builtins

**Decision that differs from the plan:** no `Ptr<T>` and no `unsafe` block. An address is a `Usize`,
the width is in the builtin's name, and `Ptr` stays an opaque foreign handle. The reasons: a typed
pointer needs provenance rules this language has not written, a register at 0x09000000 has none, and
builtins need no parser change, which keeps the seed out of it (nothing in `src/` calls them). The
price is that nothing marks the call sites as unsafe except their names.

- [x] `__builtin_mem_{load,store,vload,vstore}_{u8,u16,u32,u64}`: plain and volatile. Volatile stores to
      one address stay two stores; tested on the PL011 UART.
- [x] `__builtin_mem_{aload,astore,aswap,aadd,asub,aand,aor,axor,acas}_*` and `__builtin_mem_fence()`:
      atomics, sequentially consistent. They compile to `ldaxr`/`stlxr` loops and `dmb ish` on AArch64.
- [x] `__builtin_asm(text)`, `__builtin_asm_read(text)`, `__builtin_asm_write(text, v)`: inline
      assembly, the text a string literal, memory clobbered. `cli`/`sti`/`hlt`/`wfi`/`nop`, and `mrs`/`msr`
      round trips, are tested.
- [x] `__builtin_port_{in,out}_{u8,u16,u32}`: x86 port I/O, refused on any other target. They need their
      own builtins because `in` and `out` name their registers.
- [x] `__builtin_ptr_addr`, `__builtin_addr_ptr`: the one door between `Ptr` and a number, which is what
      lets a Prismio panic hook read the C strings the failure core hands it.
- [ ] Orderings weaker than sequentially consistent (acquire, release, relaxed). LLVM has them; the surface
      does not.
- [ ] Assembly with more than one operand, an output and an input together, or a declared clobber.
- [ ] A typed pointer (`Ptr<T>`) and an `unsafe` marker, if the name-only convention proves too weak.

### Step 4 · Layout and symbols — built

- [x] `repr(C)` and `packed` before `struct`. Declaration order, C padding (`repr(C)`) or none (`packed`);
      exempt from LAYOUT 7.2. Tested on the emitted type, because a program cannot take a field's address.
      This also closes the open `KNOWN_ISSUES` entry about a program's own struct handed to C.
- [x] `export`, `naked`, `section("...")` and `align(n)` before `fn`, in any order. `export` is an LLVM
      alias beside the function, so every call inside the program keeps working; `naked` adds `noinline`.
- [x] A kernel with no C in it but the shared failure core: the entry stub (`export naked
      section(".text.boot")`), the serial output, the exit and the panic hook are Prismio, on AArch64 and
      32-bit x86.
- [ ] An interrupt calling convention. A `naked` function with `__builtin_asm` does it by hand.
- [ ] Static data with a section and an alignment: a page table, a descriptor table. A function body is the
      only place assembly can emit data today, which is how the x86 PVH note is written.
- [ ] `align` on a struct or a global, and `sizeOf`/`offsetOf`, so a `repr(C)` struct can be pointed at.
- [ ] `Bool` in a `repr(C)` struct: still a one-bit type. Use `U8`.
- [ ] Linking a `.S` or `.o` the project did not compile: `--native` accepts any file clang compiles, but a
      manifest's `native { source(...) }` accepts `.c` only (`UMS2324`).

**Milestone A: "hello from kmain" — reached 2026-10-08**, on AArch64 `virt` and 32-bit x86 under QEMU,
with the boot code, serial output and panic path in Prismio. A 64-bit x86 kernel is not booted: QEMU's
`-kernel` does not load a 64-bit ELF, so it needs a 32-bit stub that enters long mode.

### Step 5 · A `core` library — built as an allowlist

- [x] `std.option`, `std.platform` and `std.iter` import and link with no runtime, on both architectures,
      from a checkout and from a packaged toolchain. Every other `std` module is `P1094`.
- [x] The modules over `Vec` and `String`, once step 6 gave them a runtime: `std.mem`, `std.string`,
      `std.vec`, `std.map`, `std.eq`, `std.ord`, `std.copy`, `std.key`, `std.default`, `std.unicode*`.
- [ ] `std.io`, `std.display`, `std.input`, `std.fs`, `std.process`, `std.time`, `std.term`: each needs a
      console, files, processes or clocks. `std.math` is excluded for a second reason: some of its functions
      are instructions on one target and C library calls on another.

### Step 6 · A heap in freestanding mode — built 2026-10-09

[FREESTANDING_MEMORY.md](FREESTANDING_MEMORY.md) holds the design, the measurement behind it, and section
7, what was built and where it departed from the design.

- [x] The design and the measurement.
- [x] Everything in its section 5. `lang_runtime.c` compiles with `PRISMIO_FREESTANDING` for AArch64 (with
      and without the FP unit) and i686; a kernel with a Prismio bump allocator uses `Vec`, `String` and
      std.mem under QEMU (`kernel_mem_aarch64.psm`); a kernel that imports none of them links what it did
      before.
- [ ] A spinlock spelling of the mutex seam, for a kernel that runs the runtime on several cores.
- [ ] Float text (`toString` on a Float, `parseFloat`) in a freestanding program: the hosted runtime's
      is `snprintf`/`strtod`. Today a kernel that calls one gets the linker's undefined-symbol error.

### Step 7 · Cross targets and shipping — partly built

- [x] `tools/package.py --freestanding-target <triple>`: the allowed `std` modules for the triple and the
      failure core, with no sysroot. Used from outside the checkout on AArch64 and i686 and booted.
- [x] `--freestanding` adds the failure core itself, from an installed toolchain or a checkout.
- [x] The manifest: `freestanding`, `triple`, `features`, `codeModel`, `noRedZone`, and `script` and `arg` in
      `link { }`. A kernel declared in `build.ums` builds in the debug profile (`-g`, overflow checks) and boots.
- [ ] The dev-loop toolchain `prismio build` leaves beside the project host carries neither the failure core
      nor a bare-metal section. A build from a checkout finds both in the checkout.
- [ ] RISC-V. It is a target-list change in two places that must agree (`PRISMIO_LLVM_TARGET_LIST` and
      `TARGET_COMPONENTS`, which `tools/check_source_lists.py` compares), plus `default_target_cpu`, the targets
      page, and an LLVM re-download with the RISCV component. Not started: it cannot be tested without the
      re-download.
- [ ] Embedded LLD. Stopped on 2026-09-24 because `cc` still needed the C library; that objection does not
      apply to `--freestanding`, so it is worth reopening, but `ld.lld` on `PATH` is the requirement today.
- [x] A Linux host row: Ubuntu 26.04 aarch64, glibc, LLVM 23 (section 1). A Linux **x86_64** row remains; the
      available VM is aarch64.

## 3b · Verification record (2026-10-08)

- `prismio suite`: 534 of 534, including the `freestanding` test, which boots eleven kernels under QEMU
  (AArch64 `virt`: a computed result, a checked overflow, a wrapped overflow, a panic, MMIO and atomics,
  a pure-Prismio kernel in two modes, and the same kernel built from `build.ums`; 32-bit x86: two modes) and
  checks the emitted struct layout. Five new negative fixtures (`neg_266` to `neg_270`).
- Compiler output unchanged: `src/main.psm` compiled by HEAD's compiler and by this tree's compiler is
  byte-identical IR, and `tools/ir_snapshot.py` over `tests/` and the benchmarks matches on 293 of 294 programs.
  The 294th, `test_55_workload_profile`, matches too when both compilers run from the same tree; its layout
  comes from running the program's `workload`, and that depends on where the compiler sits.
- The IntelliJ plugin's tests all pass, with new ones for the modifiers, the builtin completions and the
  manifest checks.
- `tools/aif_differential.py`: the in-compiler engine and the oracle agree on all 17 sources. None of them
  calls a new builtin, so the oracle's copy of that table (`MEM_BUILTIN_ARITY` and the port, asm and address
  entries) is updated and unexercised.
- **Linux aarch64 (Ubuntu 26.04 VM, 2026-10-08):** the compiler builds from this tree with the installed
  0.1.0, the `freestanding` test passes (9 kernels; the two x86 cases skip), and a toolchain packaged there with
  `tools/package.py --freestanding-target aarch64-unknown-none-elf` builds and boots the pure-Prismio kernel
  from outside the checkout, imports `std.option` and `std.platform`, and refuses `std.vec`. Two environment
  findings: the `ld.lld` in the LLVM tarball links against ICU 70 and does not run on this distribution, so the
  AArch64 kernels link with GNU ld (`--link-arg -fuse-ld=bfd`, which the test now falls back to); and a
  `--target` build runs `clang` as its link driver, which has to be on `PATH`.
- Not run: `prismio gate` and the two-generation fixpoint through `tools/bootstrap`.

## 4 · Risks

- **Seed ordering.** Any new syntax in step 3 or 4 is unusable in `src/` until a
  published seed parses it. Keep these features out of `src/` and the compiler's
  own source, so the seed does not become a dependency.
- **Behavior-preserving rule.** Splitting `lang_runtime.c` (step 2) must leave
  compiler output byte-identical for every program in `tests/` and
  `benchmarks/hosted/prismio/`: two generations to a fixpoint, the full suite,
  `tools/aif_differential.py`.
- **`rt_free` is the symbol codegen emits for every release**, and is routed
  through the verify seam. A core split that moves it changes every program.
- **Toolchain file table skew.** Splitting a `runtime/*.c` needs a re-bootstrapped
  host first (`prismio-toolchain-file-table-skew`).
- **Performance.** The user's goal is past C++ and Rust. A freestanding profile
  must not add a branch or a call to the hosted hot path; the probe's 1.1 result
  is the thing to preserve, so the test in step 0 doubles as a perf guard.
- **Scope.** Steps 3 and 4 are each a language-design change with a docs
  obligation (`docs`, `developers`, IntelliJ plugin, `std/` wrappers). Budget for
  that, not only the compiler.

## 5 · Not in this plan

- Compiling or modifying the Linux kernel.
- A scheduler, VFS, drivers, a network stack. Those are the kernel project that
  sits on top of Milestone B.
- Hosted `std.*` working freestanding.
- Windows freestanding.

## Appendix · Probe sources

Build line: `PRISMIO_INTERNAL_HOSTED=1 pprobe build pN.psm [-O0] [--overflow-checks] -o pN`,
then `nm -u pN`.

```prismio
// p0
fn main() -> Int { return 0 }
```

```prismio
// p1
fn sum(n: Int) -> Int {
    let mut total = 0
    let mut i = 0
    while (i < n) {
        total = total + i * 3
        i = i + 1
    }
    return total
}

fn main() -> Int { return sum(10) % 256 }
```

```prismio
// p2
struct Reg { lo: U8, hi: U32, mid: U16 }

fn main() -> Int {
    let a: Array<Int, 4> = [1, 2, 3, 4]
    let mut t = 0
    let mut i = 0
    while (i < 4) {
        t = t + a[i]
        i = i + 1
    }
    let r = Reg { lo: 1, hi: 2, mid: 3 }
    return t + (r.lo as Int)
}
```

```prismio
// p3
import std.vec
import std.string

fn main() -> Int {
    let mut v: Vec<Int> = []
    v.push(1)
    v.push(2)
    let s = "hello"
    return v.length + s.length
}
```

```prismio
// p4
fn div(a: Int, b: Int) -> Int { return a / b }

fn main() -> Int {
    let a: Array<Int, 4> = [1, 2, 3, 4]
    let mut t = 0
    let mut i = 0
    while (i < 9) {
        t = t + a[i % 5]
        i = i + 1
    }
    return t + div(8, t - t)
}
```

```prismio
// p5
import std.io

fn main() -> Int {
    println("hi")
    return 0
}
```
