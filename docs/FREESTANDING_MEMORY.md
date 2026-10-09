# Freestanding memory: what a heap means with no operating system

The design for `Vec`, `String` and `Map` in a `--freestanding` program, which is step 6 of
[FREESTANDING_PLAN.md](FREESTANDING_PLAN.md). Written 2026-10-08, **built 2026-10-09**: section 7
says what was built and where it departed from the design. It existed first because the plan said not
to start this step with code: what ownership means with no global heap shapes the language, and the
measurements below were taken first.

## 1 · Where the program stands

A freestanding program has no heap types today. Every `std` module but `option`, `platform` and
`iter` is refused (`P1094`), because `Vec`, `String` and `Map` are Prismio code over C functions
in `lang_runtime.c` (`list_push`, `str_clone_n`, `map_*`), and those call the C library.

So the question is not whether the language can express an allocation: the compiler's analysis
(AIF) already decides, per allocation site, whether a value lives in a frame slot (T0), in an
arena (T1), or on the reference-counted heap (T2/T3). The question is what the **runtime** under
those decisions needs.

## 2 · What the runtime needs, measured

`lang_runtime.c` compiled at `-O2` for the host and read with `nm -u` has **48 undefined
symbols**. Grouped by what a freestanding target must provide:

| Group | Symbols | Freestanding answer |
|---|---|---|
| Allocation | `malloc`, `free`, `realloc`, `malloc_size` | the program's allocator (below) |
| Bytes and strings | `memcpy`, `memmove`, `memset`, `memcmp`, `memchr`, `strlen`, `strcmp`, `strcpy`, `strncpy`, `strchr`, `strrchr`, `bzero`, `__memcpy_chk` | any freestanding target must define the first four anyway (LLVM lowers struct copies to them); the rest are short loops |
| Diagnostics | `fprintf`, `fputs`, `fputc`, `fwrite`, `fflush`, `fopen`, `fclose`, `snprintf`, `sprintf`, `stdout`, `stderr`, `getenv` | the profile and verify output, which a freestanding build does not have; compiled out |
| Process | `exit`, `atexit`, `backtrace`, `dladdr` | `exit` becomes the panic hook; `atexit`, `backtrace`, `dladdr` are debugging aids and compile out |
| Threads | `pthread_mutex_init/lock/unlock`, `pthread_mutexattr_*`, `pthread_once`, `__tlv_bootstrap` (thread-locals) | the allocator and the cycle collector serialise on a mutex; single-core freestanding makes them no-ops, and SMP makes them spinlocks over the atomics that now exist |
| Other | `qsort`, `strtod`, `___stack_chk_*` | `qsort` is reached through `sort`; `strtod` through float parsing; the stack protector is off with `-fno-stack-protector` |

`aif_support.c` (9,028 lines) is the compiler's analysis engine and is never in a program.
`program_support.c` (2,163 lines) is the runtime half of `std.fs`, `std.process` and `std.term`, which
a freestanding program cannot import, so it is not merged either.

## 3 · Choices

**(a) No heap types in freestanding, permanently.** Arrays, structs and the frame are all there is.
Honest, and enough for a boot stage or a driver. A kernel's first allocator is written in Prismio over
raw addresses and could never use `Vec` itself, which is fine until the second allocator needs one.

**(b) A freestanding build of the runtime over a program-supplied allocator.** Compile
`lang_runtime.c` with `-DPRISMIO_FREESTANDING`: allocation goes through three functions the program
defines, the diagnostics and process groups compile out, the mutex macros become no-ops (or spinlocks),
and `exit` calls `prismio_panic_hook`. The program supplies the allocator and the four `mem*`
functions. Every `std` module that depends only on `lang_runtime` is then importable: `vec`, `string`,
`map`, `ord`, `eq`, `copy`, `key` and `unicode*`. `math` stays out for its own reason: some of its
functions are instructions on one target and C library calls on another.

**(c) AIF tiers T0/T1 only.** Refuse, at compile time, any allocation the analysis cannot place in a
frame slot or an arena. Needs (b)'s runtime anyway, because `Vec.push` calls `list_push` even when the
list is arena-backed; what (c) adds is a guarantee that no code path reaches the allocator.

## 4 · Recommendation

**(b), then (c) as an optional check on top.** (a) is what exists and nothing about (b) forecloses it:
a program that imports nothing from `std` still gets no runtime at all, which is the property the first
milestone measured and the `freestanding` test guards.

(b) is also the only choice that leaves the ownership model alone. A value is released by the same
`rt_free` the hosted build emits, which `release_call_temps` and every drop already name; only the
function behind it changes. Nothing in the language, in sema or in AIF has to learn about freestanding.

### The allocator contract

Three C functions, declared by the runtime and defined by the program (weak defaults that panic, so a
program that never allocates need not define them):

```c
void* prismio_alloc(unsigned long size);              /* never returns NULL; panics on exhaustion */
void* prismio_realloc(void* p, unsigned long size);
void  prismio_free(void* p);
```

- **Never NULL.** The hosted runtime checks `malloc` on user-reached paths (`C_CODE_STYLE.md`); a kernel
  decides what exhaustion means, once, in its allocator. Returning NULL would mean every call site
  checks, and the hosted code's checks assume an `exit` that a kernel does not have.
- **`malloc_size` goes.** `lang_runtime.c` reads a block's usable size through `RT_USABLE_SIZE`, which is
  `malloc_size` on macOS. The freestanding allocator records sizes itself or the runtime stores a header;
  the second is simpler and costs a word.
- **`rt_base_alloc` and `rt_free` keep their names.** Codegen emits `rt_free` for every release
  (`g_free_fn`), so the seam is in the runtime, not the compiler. This is the invariant `CLAUDE.md`
  states for the hosted build and it holds here unchanged.

## 5 · Order of work

Each step ends with a test that fails before and passes after.

1. **Probe the compile.** `clang --target=aarch64-unknown-none-elf -ffreestanding -c lang_runtime.c`
   with no libc headers fails at the first `#include <stdio.h>`. List every include and every use of
   it; most are behind `PRISMIO_AIF_VERIFY`, `PRISMIO_PROFILE` or `_WIN32` already.
2. **`runtime/prismio_freestanding.h`.** One header that, under `PRISMIO_FREESTANDING`, declares the
   handful of types and functions the file uses in place of `<stdlib.h>`, `<string.h>` and `<stdio.h>`.
3. **Guard the diagnostics and process groups.** `#ifndef PRISMIO_FREESTANDING` around the profile,
   verify, backtrace and `atexit` code. The byte-identical-output rule applies to the hosted build:
   two generations to a fixpoint, the full suite, `tools/aif_differential.py`.
4. **A mutex seam.** `PRISMIO_MUTEX_LOCK` already exists (`prismio_runtime.h`); give it a freestanding
   spelling, a no-op first and an atomic spinlock second.
5. **Package `lang_runtime.freestanding.bc`** per bare-metal triple beside the failure core, and merge
   it when `--freestanding` imports a module that needs it.
6. **Widen `freestandingSafeModule`** to the modules that now link, one at a time, each with a probe
   that imports it and links with only the three allocator functions defined. `FREESTANDING_STD` in
   `tools/package.py` follows, and `tools/check_source_lists.py` keeps them in step.
7. **The first heap test**: a bump allocator written in Prismio over `__builtin_mem_*`, exporting
   `prismio_alloc`, and a kernel that pushes into a `Vec<Int>`, sums it and prints the result under QEMU.

## 6 · What this does not decide

- **Per-core allocators and interrupt-safe allocation.** A kernel that allocates in an interrupt
  handler needs the allocator to be reentrant; that is the kernel's problem, not the runtime's, and the
  contract above puts it in the right place.
- **The cycle collector.** `lang_runtime.c` has one (`cyc_*`). It is single-threaded and walks roots
  from a stack of cyclic types. Whether to compile it into a kernel is a size question to answer by
  measuring step 5's bitcode.
- **Threads.** `spawn` and `Channel<T>` are `program_support.c` and `lang_runtime.c`'s task code and
  stay out of a freestanding program.

## 7 · What was built (2026-10-09)

Choice (b), as recommended. The departures from section 5, each for a reason found on the way:

- **Source, not packaged bitcode.** Step 5 planned a `lang_runtime.freestanding.bc` per bare-metal triple.
  The failure core already showed the better shape: `runtime/freestanding/runtime.c` is `lang_runtime.c`
  with `PRISMIO_FREESTANDING` defined, compiled by the build for the program's own triple and CPU
  features (`-neon,-fp-armv8`, `-mgeneral-regs-only`), cached with the native objects, and merged into the
  program like the hosted runtime. No triple has to be packaged in advance, and a kernel's FP-off flags
  reach the runtime too. `tools/package.py` ships the source beside the failure core.
- **Only when used.** The import resolver tells the build when a freestanding program imports a `std`
  module over `Vec` or `String` (`compiler_use_freestanding_runtime`); only then are the runtime merged and
  `runtime/freestanding/libc.c` linked. A kernel that imports nothing links what it did before.
- **A freestanding program is internalised.** Every function but `main` and the `export` aliases becomes
  internal, as in a closed hosted program, because a kernel's C can only call those names. Without it, a
  checkout -- which compiles `std` from source into the program -- kept every unused `std` function and
  their references to Float text. The freestanding benchmarks did not move: 5 fewer, 15 level, 0 more
  against C, as before.
- **`prismio_freestanding.h`** stands in for the C headers: the allocator is `prismio_alloc`,
  `prismio_realloc`, `prismio_free` (weak defaults in `panic.c` that stop the machine); the byte and string
  functions and `qsort` are `libc.c`'s, weak; `fprintf` keeps its format and `exit` hands it to
  `prismio_panic_hook`, so a runtime error still says what went wrong, without its numbers; locks and
  thread-locals are nothing.
- **Objects come from `rt_base_alloc`.** Codegen allocates objects with `malloc` in a hosted build, for the
  aliasing facts LLVM knows about that name; a freestanding build names the runtime's seam instead
  (`src/driver/compile.psm`), and `rt_free` was already the release half.
- **Float text is compiled out**, not stubbed: `str_from_double` and the rest are absent, so a kernel that
  formats a Float fails at link time naming the function, rather than printing nothing at run time.
- **The string hash builds its 128-bit product from four 32-bit ones** where there is no `__int128`
  (i686), and agrees with codegen's inline hash bit for bit (checked over 10 million pairs).
- **`int_to_str` formats its digits by hand** instead of `sprintf`, in every build.

