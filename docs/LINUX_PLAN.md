# Prismio in the Linux kernel: missing features

Feature names only. What exists today is in the Linux tree (`prismio/`,
`samples/prismio/`, `Documentation/prismio/`) and in `FREESTANDING_PLAN.md`;
measurements are in `LINUX_BENCHMARKS.md`. Each entry was hit by a real module,
not guessed.

## Language

- Variadic extern functions
- Overloaded extern functions
- String to `Ptr` conversion
- Typed pointers, `Ptr<T>`
- Field access through a pointer
- `sizeOf` and `offsetOf`
- `align` on structs and globals
- Module-level static data with a section and an alignment
- Module-level assembly
- Function pointers, and the address of a function
- Statically initialised structs and tables
- Weaker atomic orderings (acquire, release, relaxed)
- Multi-operand inline assembly with declared clobbers
- Hardware CRC and other CPU-specific instruction intrinsics
- `Bool` in a `repr(C)` struct
- An `unsafe` marker
- Negative errno and `ERR_PTR` return convention
- A heap over `kmalloc` (`Vec`, `String`, `Map` in a module)

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
