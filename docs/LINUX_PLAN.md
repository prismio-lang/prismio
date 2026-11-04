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

Open, with what stops each (the order is the order they should be built in):

- Function pointers, and the address of a function: a function's name is not a value (`unknown identifier`),
  and `__builtin_fn_addr` is std-only and not implemented. A kernel ops table needs both
- Static data: `section("...")` and `align(n)` exist on functions only (the parser refuses them before a `let`),
  and a global array cannot be sized (`an array's length is written only on a local let`) or zero-filled, so a
  page table or a descriptor table cannot be written
- Statically initialised structs and tables: a global array's elements must be numbers, characters or string literals
- `align` on a struct
- Variadic extern functions: refused on purpose (`P3014`, "C varargs are not supported"). `printk` is the case that matters
- Overloaded extern functions: a second `extern fn` of the same name is dropped, not resolved, so only the first
  signature is callable
- String to `Ptr` conversion: `addressOf` takes a `Ptr`, and a `String` is not one
- Module-level assembly: `__builtin_module_asm` does not exist; the `.modinfo` section is the case that needs it
- Multi-operand inline assembly with declared clobbers: `asm`, `asmRead` and `asmWrite` take one operand
- Hardware CRC and other CPU-specific intrinsics: none exist
- A heap over `kmalloc` (`Vec`, `String`, `HashMap` in a module): the freestanding heap exists
  (FREESTANDING_MEMORY.md); pointing it at `kmalloc` is the open part

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
