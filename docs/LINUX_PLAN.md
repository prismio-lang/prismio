# Prismio in the Linux kernel: missing features

Feature names only. What exists today is in the Linux tree (`prismio/`,
`samples/prismio/`, `Documentation/prismio/`) and in `FREESTANDING_PLAN.md`;
measurements are in `LINUX_BENCHMARKS.md`. Each entry was hit by a real module,
not guessed.

## Language

Audited against the compiler on 2026-11-04: each entry below was tried, not remembered.

Done:

- ~~Typed pointers, `Ptr<T>`~~ and ~~field access through a pointer~~ (`Ptr<mut T>`, `p.field`, volatile and atomic pointees)
- ~~Weaker atomic orderings~~ (`AtomicOrder.Relaxed`, `Acquire`, `Release`, `AcqRel`, `SeqCst` on a typed pointer)
- ~~An `unsafe` marker~~: `import std.raw` is the marker; the address functions are refused in a file that has not written it
- ~~`sizeOf` and `offsetOf`~~: `sizeOf<T>()` is read off the pointer type and folds to a constant;
  `offsetOf<S>("field")` is the backend's answer for the target, for a `repr(C)` or `packed` struct
  (`tests/test_371_size_and_offset.psm`, two `neg_` fixtures)
- ~~`Bool` in a `repr(C)` struct~~: it is one byte, laid out as C's `_Bool` is (pinned in `test_371`)
- ~~Negative errno and `ERR_PTR` return convention~~: `std.errno` (`isErrno`, `errPointer`, `isErrPointer`,
  `isErrOrNull`, `errnoOf`), pure arithmetic, freestanding-safe (`tests/test_372_errno.psm`)

Built on 2026-11-04, each with a test:

- ~~Overloaded extern functions~~: two `extern fn`s of one name are kept when their parameters differ, resolved by
  argument types, and called at their own signature (`tests/test_373_overloaded_externs.psm`)
- ~~Function pointers, and the address of a function~~: `functionAddress("name")` in `std.raw`, a link-time constant,
  also for a function defined later in the file (`test_374`)
- ~~String to `Ptr` conversion~~: `cString("literal")`, a pointer to read-only NUL-terminated data (`test_375`). A
  String built at run time is passed to C by an `extern fn` parameter declared `String borrow`
- ~~Variadic extern functions~~: a bare `...` after the named parameters, a variadic declaration in LLVM, C's default
  promotions on each extra, a String passed as a C string (`test_376`, against `snprintf`)
- ~~Multi-operand inline assembly with declared clobbers~~: `asmOps` / `asmOpsOut` in `std.asm`
  (`run_asm_ops_test`)
- ~~Hardware CRC and other CPU-specific instruction intrinsics~~: reached through `asmOpsOut` with the instruction
  and `.arch_extension` in the text; the Armv8 CRC32C step is the worked example. There is no portable intrinsic
  function because which instruction exists is the target's, so a module built for one architecture holds it
- ~~Module-level static data with a section and an alignment~~: `export section("...") align(n) let` for scalars and
  for the byte and halfword arrays a `[U8]` / `[U16]` annotation gives, which covers a kernel module's `.modinfo`
  (`run_data_placement_test`)
- ~~A heap over `kmalloc`~~: `prismio_alloc`, `prismio_realloc` and `prismio_free` written in Prismio over
  `__kmalloc`, `krealloc` and `kfree`, with a `Vec`, a `HashMap` and a `String` on it (`run_kmalloc_heap_test`)

Still open, with what stops each:

- Module-level assembly: there is no top-level form for it. `.modinfo` is covered by exported data above; a
  `.pushsection` of instructions is covered by a `naked` function in a `section`
- Statically initialised structs and tables: a global array is read-only data, every element a number, a
  character or a string literal, because nothing runs before `main`. A table of function addresses or of structs
  needs constant evaluation of `functionAddress` and struct literals in an initialiser
- A mutable global array, so a page table or a descriptor table cannot be written. It needs the sized-array form
  (`Array<U8, 4096>`) on a global, which sema refuses today, and the access paths for a written global aggregate
- `align` on a struct: LLVM carries alignment on the storage, not the type, so `sizeOf` and an array's stride would
  not follow it without padding the type itself

## Compiler and driver

- Object-file output (`-c`) without clang
- Import search path, so modules share one bindings file
- A dependency file for imported `.psm` sources
- A kernel-aware panic and overflow hook, selectable per module
- Checked and unchecked arithmetic selectable per function
- Debug info and BTF for kernel modules
- x86_64 kernel target flags
- RISC-V target
- A packaged toolchain for Kbuild, without a Prismio checkout

## Kernel integration

- `EXPORT_SYMBOL` from Prismio code
- Symbol versioning (`CONFIG_MODVERSIONS`) for Prismio-exported symbols
- Built-in (`obj-y`) Prismio code
- kCFI type hashes
- Shadow call stack and pointer-authentication return protection
- Bindings generated from, or checked against, kernel headers
- Inlining of C helpers into Prismio code
- KUnit integration
- `make prismiofmt` and a `make prismiodoc` target
- A `MAINTAINERS` entry

## Before a pull request

Order: release first, then testing and licensing, then the commit split.

- A Prismio release that has `--freestanding`
- Freestanding work committed in all three repositories, and `prismio gate` run on it
- Minimum Prismio version in `scripts/prismio-is-available.sh` set to that release
- Failure-path tests for `make prismioavailable` (missing, old and broken `prismio` and clang)
- `CONFIG_PRISMIO=n` build unchanged (plain `defconfig`)
- `defconfig` build with BTI and pointer authentication on
- External module build (`make M=`)
- `LLVM=1` build
- `depends on` limits for untested configs (KASAN, GCOV, KCOV, LTO, BTF)
- Licence and attribution for the glob port (`lib/glob.c` is `GPL-2.0 OR MIT`)
- `scripts/checkpatch.pl`, whitespace and `make W=1` clean
- Commit split in kernel style with `Signed-off-by`: availability script and Kconfig, Kbuild rule and arm64 flags, helpers, docs, minimal sample
- Automatic QEMU boot test that loads the samples and checks the log
- Prismio side: `CHANGELOG` entry, a docs page for Linux, `LINUX_PLAN.md` and `LINUX_BENCHMARKS.md` committed
- Stated scope: arm64, modules only, tested under QEMU on Apple silicon

Later patch, not the first: the `glob` and `crc32` samples, once their workarounds
(String to `Ptr`, variadic and overloaded externs, `.modinfo` as data) are gone.

Not in the first pull request: x86_64, the failure core in Prismio, `EXPORT_SYMBOL` from Prismio.

Upstream note: mainline Linux takes patches by email (LKML and the kbuild list), not
pull requests, and a new language needs an RFC series first. A pull request goes to
the `saksham1319/linux` fork.
