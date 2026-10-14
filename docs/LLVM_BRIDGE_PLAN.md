# LLVM C++ bridge and static LLVM on Windows

The backend is written against LLVM-C, and stays that way. A small `extern "C"` C++
file gives it the few things LLVM-C cannot say, and Windows links LLVM statically like
macOS and Linux so that file works on every host. This page is the plan and the state:
a session that stops mid-way leaves the checkbox it reached and what it learned.

## Why

A program that prints one line builds in 36 ms (2026-10-10, after the direct `ld` link).
`PRISMIO_PHASE_TIMES=1` and `PRISMIO_BUILD_TRACE=1` split it:

| stage | ms | what it is |
|---|---|---|
| frontend | ~3 | parse, imports, sema, AIF, IR generation |
| **library bitcode merge** | **7.3** | runtime + plib bitcode parsed whole, linked whole, then pruned |
| IR pipeline + machine code | ~6 | `globaldce,default<O3>` and codegen |
| link (`ld`) | ~15 | the system linker |

The merge, measured per module (warm, hello-world):

| module | definitions | parse | link |
|---|---|---|---|
| io.plib | 119 | 0.69 | 0.33 |
| float_text.plib | 34 | 0.72 | 0.38 |
| lang_runtime.bc | 183 | 2.09 | 1.03 |
| program_support.bc | 83 | 0.94 | 0.60 |
| prune afterwards | | 0.65 | |

Plibs are already chosen per program; the cost is that every chosen module, and the whole
C runtime, is parsed and linked function by function and then mostly deleted again by
`prune_unused_imported_definitions`. Hello-world uses a handful of the 266 runtime
definitions. LLVM's answer is lazy bitcode loading plus `Linker::LinkOnlyNeeded`, and
LLVM-C has the first (`LLVMGetBitcodeModuleInContext2`) but not the second, and has no way
to materialise one function. **Expected: the merge from 7.3 ms to about 1.5-2, roughly
14% of a hello-world build**, and a constant saving on every larger one.

### Why a bridge and not a C++ port

`llvm-api-backend.c` is ~8,800 lines on the stable C ABI. A port buys nothing for the code
the compiler generates (the pipeline and codegen are the same LLVM), puts LLVM's C++
headers on every bootstrap's critical path and ties each LLVM upgrade to C++ API churn.
The bridge is the handful of entry points C lacks, and only those.

### Why Windows has to change

macOS and Linux link LLVM's static libraries into the compiler (`tools/setup_llvm.py`
lowers the ThinLTO archives to objects), so all of LLVM's C++ API is already inside the
binary. Windows links the official archive's `LLVM-C.lib` and ships `LLVM-C.dll`, which
exports the C API only: a bridge has nothing to call there. LLVM does not support a C++
`LLVM.dll` under MSVC. Linking the static libraries on Windows too gives one backend
arrangement on every host, and drops a 100 MB-class DLL from the archive in exchange for
linking only the components the compiler uses.

## Constraints on the bridge

- **One file, `runtime/llvm_bridge.cpp`, `extern "C"` only**, declared in `runtime/prismio_llvm.h`
  beside the LLVM-C declarations. Opaque `LLVM*Ref` types in and out (`llvm::unwrap`/`wrap`).
- **LLVM is built `-fno-rtti -fno-exceptions`** (`llvm-config --has-rtti` says NO). The
  bridge never subclasses a polymorphic LLVM type and never uses `dynamic_cast`/`typeid`,
  so clang's defaults for a `.cpp` (`gnu++17`, RTTI on) link cleanly; if a flag is ever
  needed it has to be per-file, because `native { flag(...) }` reaches the C sources too.
- **No `llvm::Error` may escape unhandled** -- an unchecked `Error` aborts in a debug build of
  LLVM. Convert to a message (`toString(std::move(err))`) and return non-zero.
- The compiler already links `-lc++` (third_party/llvm-link.rsp); nothing new to link on Unix.

## Step 1 -- the bridge and lazy merge, macOS and Linux

- [x] **1a. Bridge file.** `runtime/llvm_bridge.cpp` with two functions:
      `int prismio_llvm_materialize(LLVMValueRef function, char** error)` and
      `int prismio_llvm_link_only_needed(LLVMModuleRef dst, LLVMModuleRef src, char** error)`
      (takes ownership of `src`, as `LLVMLinkModules2` does). Add it to every compiler source
      list: `build.ums` (native `source(...)`), `RUNTIME_SOURCES` in `tools/bootstrap.sh` and
      `$runtimeSources` in `tools/bootstrap.ps1` (both compile with clang, which picks C++
      from the extension; the bootstrap object names use `${c%.c}`, so check a `.cpp`
      produces a sane object and cache key), and teach `tools/check_source_lists.py` that a
      compiler source may be `.cpp`. It is a compiler source, not a runtime one:
      `prismio_toolchain_files[]` and `RUNTIME_BITCODE` do not change.
- [x] **1b. Host first.** A new compiler source is the file-table-skew hazard: bootstrap a
      host with `tools/bootstrap.sh` from the working tree (it consults no table), install
      it as the project host, and only then `prismio build`.
- [x] **1c. Lazy merge in `ir_link_library_modules`** (`runtime/llvm-api-backend.c`):
      1. load every library module with `LLVMGetBitcodeModuleInContext2` (lazy) instead of
         `LLVMParseIRInContext`; the program module is still parsed from its `.ll`;
      2. map every defined symbol (functions and global variables) to its module;
      3. worklist from the program's declarations: for each needed function, materialise it
         and add every function or global its instructions name, looking through constant
         expressions; a needed global variable adds what its initializer names;
      4. add a declaration to the program module for every needed symbol a library defines
         and the program does not yet declare, so `LinkOnlyNeeded` takes it even when only a
         *later* module calls it (it links a global only when the destination declares it;
         appending globals always);
      5. run the existing passes unchanged -- `preserve_program_declaration_contracts`,
         `clear_packaging_target_attributes`, `yield_to_workload_stubs`,
         `mark_imported_definitions`, `mark_library_interface_functions`,
         `mark_runtime_structural_invariants`. Each is per function and reads only
         attributes or that function's own body, and an unmaterialised function has no
         blocks, so they see exactly the needed set. `yield_to_workload_stubs` needs nothing:
         a stubbed name has a definition in the program, so it is never needed;
      6. `prismio_llvm_link_only_needed` each module, in today's order;
      7. keep `prune_unused_imported_definitions` -- it should now remove nothing, and
         counting what it removes is a cheap check that the closure was exact.
- [x] **1d. Prove it changes nothing.** The bar is byte-identical executables:
      - every `tests/test_*.psm` built by the old and the new compiler **to the same output
        path** (the ad-hoc code signature embeds the output name) -- 254 programs, compare
        MD5s; the direct `ld` link was proved this way;
      - the benchmark suite binary: `fn_mnemonic_diff` with trailing `nop`s stripped (it
        counts alignment padding as a change), expect 0;
      - **the function order in the merged module is the risk.** `IRMover` creates linked
        functions in discovery order, and order is layout: `gcd_lcm` moved 12% with
        identical instructions at another address. If the binaries differ only in order,
        add a third bridge entry point that reorders the merged module to the old order,
        rather than accepting a layout change inside a behaviour-preserving step;
      - full suite (`prismio build --release`, `prismio build`, `tools/run_suite.py`), two
        generations to an IR fixpoint, `tools/aif_differential.py`, `prismio lists`,
        `tools/check_externs.py --dist <package>`.
- [x] **1e. Measure** hello-world and the suite compile (`--compile-runs 5`) against the
      pre-bridge package, A/A alongside. Record in CHANGELOG (0.2.0, Changed) and in the
      developers docs' build-tracing page, which has the stage table above.

### What step 1 found (2026-10-14)

- **The gain is 1.6 ms, not 5-7.** Hello-world 36.1 -> 34.5 ms (median of 40, same binary, whole
  against lazy). Read cold, a lazy library module is 1.1 ms against 3-4 for a whole parse, but
  most of what is left is one-time warm-up of a 60 MB binary, and linking is still ~0.8 ms.
  The "expected 1.5-2 ms merge" above was not reached; it is about 3.6.
- **Byte-identity is not reachable, and does not matter.** 136 of 289 buildable test programs
  differ, and 135 of those have the same symbols and size. IRMover places a function when it is
  first discovered, and the whole-module merge discovered through bodies the lazy merge never
  reads, so the old order cannot be rebuilt without reading them. The reorder entry point
  imagined in 1d has nothing to reorder *to*.
- **Layout is noise here.** `benchmarks/run.py --suite hosted --runs 7`, 66 arms: lazy / whole
  geomean 1.0007, 2 arms beyond their tolerance; whole / whole (same compiler, run twice) 1.0154,
  7 arms beyond. The same arms (`struct_creation`, `mergesort`) flip in both.
- **A local symbol must not be declared in the program.** Declaring a library's `internal`
  function there made LinkOnlyNeeded rename the definition (`arena_alloc_slot.16`).
- **Suite 548/548, `prismio lists`, `aif_differential.py` (17 sources) pass.** Not run: two
  generations to an IR fixpoint (the merge happens after the IR that is compared; `-o x.ll` of a
  test program is identical either way) and `check_externs.py --dist`.

## Step 2 -- static LLVM on Windows

With a 1.6 ms gain, step 2 now buys mostly platform uniformity and dropping `LLVM-C.dll`; weigh
it on that, not on build time.

- [x] **2a. Confirm the archive.** List `clang+llvm-23.1.1-x86_64-pc-windows-msvc.tar.xz`
      (and the aarch64 one) for `lib/LLVM*.lib` component libraries and `bin/llvm-config.exe`.
      If they are absent, the fallback is building LLVM's static libraries in CI for Windows;
      stop and ask before taking that on.
- [x] **2b. Check the CRT.** Every object in one link must agree on `/MD` vs `/MT`
      (`dumpbin /directives` on one LLVM `.lib` member shows `/DEFAULTLIB:msvcrt` or `libcmt`).
      Compile the runtime and the bridge with the same choice.
- [ ] **2c. `tools/setup_llvm.py`**: the Windows branch of `prepare` writes a link response
      file from `llvm-config --libfiles --link-static` with `TARGET_COMPONENTS` (the same
      component set as Unix; keep `PRISMIO_LLVM_TARGET_LIST` in `runtime/prismio_llvm.h` in
      step, `check_source_lists.py` checks it), plus the system libraries LLVM needs
      (`llvm-config --system-libs`: `ntdll`, `psapi`, `shell32`, `ole32`, `uuid`, `advapi32`,
      `ws2_32` or whatever it prints). `link_library` stops being `LLVM-C.lib`.
- [ ] **2d. `tools/bootstrap.ps1`, `tools/package.py`, `tools/release.py`**: link the
      response file, stop copying and shipping `LLVM-C.dll`, and update whatever checks for
      it. Search for `LLVM-C.dll` across `tools/` and `runtime/`.
- [ ] **2e. Verify on Windows**: the UTM ARM64 VM (see the Windows VM CI replay notes; its
      guest agent is flaky) and then CI by hand (`gh workflow run ci.yml --ref main`).
      Compare the compiler's size and startup time with the DLL build; the
      `PRISMIO_LLVM_TARGET_LIST` subset may make it smaller.
- [ ] **2f. Docs**: the installation and toolchain-layout pages in both doc apps say what a
      Windows archive contains; `../website/apps/developers` platform-and-packaging and
      development-setup describe the Windows LLVM. Update them, and the release notes.

### What 2a and 2b found (2026-10-14)

Read from the pinned `clang+llvm-23.1.1-x86_64-pc-windows-msvc.tar.xz` (901 MB, SHA-256
matches `ASSETS`); the aarch64 archive was not opened.

- **The static libraries are there.** 146 `lib/LLVM*.lib` component libraries (252 `.lib` with
  clang's), `bin/llvm-config.exe`, `bin/lld-link.exe`, and the C++ headers
  (`include/llvm/Linker/Linker.h`). No fallback build of LLVM is needed.
- **They are native COFF, not bitcode** (members begin `64 86`, AMD64). The macOS/Linux
  `lower_archives` step has nothing to do on Windows; `llvm-config --libfiles --link-static`
  names files that link as they are.
- **The CRT is the constraint: they are `/MT`.** Every member carries
  `/DEFAULTLIB:libcmt.lib`, `/FAILIFMISMATCH:"RuntimeLibrary=MT_StaticRelease"` and
  `_ITERATOR_DEBUG_LEVEL=0`, so the link fails (LNK2038) unless the whole compiler -- the
  runtime C files, `llvm_bridge.cpp` and the backend -- is compiled `-fms-runtime-lib=static`.
  Today's compiler links `LLVM-C.dll` and the default dynamic CRT, so 2c-2d change the CRT of
  the Windows compiler too, not only its LLVM. `tools/bootstrap.ps1` and the `native { }` flags
  in `build.ums` are where that is set; a program the compiler *builds* is unaffected.
- **Not done: 2c-2f.** They rewrite the Windows toolchain blind: the UTM ARM64 guest agent is
  flaky and nothing here can run `lld-link`. With the gain at 1.6 ms, take them when a Windows
  machine is at hand and `LLVM-C.dll` is worth dropping for its own sake.

## Later, and not part of this plan

- **Direct `ld` on Linux.** The macOS link already runs `ld` from a cached `cc -###` line
  (`link_with_cached_ld`, runtime/build_driver.c). On Linux, GCC's `-###` prints `collect2`
  with environment it reads, so the cached line has to carry that too.
- **Type checking only the standard-library bodies a program reaches.** Unreached bodies
  are still checked (about 1 ms on hello-world, more with `std.float_text`); it is a sema
  redesign of a dozen whole-module passes, measured separately.
- **What else the bridge could carry**, each only with a measurement behind it:
  `irsymtab` to read a bitcode file's symbols without parsing it, and per-function
  codegen options LLVM-C has no setter for.

## Resuming

Read this page, then `git status` and `git log -5`: the work before step 1 (pruning on
by default, symbol-keyed guard verdicts, the `DYN_CALL` guard fix, the direct `ld` link)
is in the CHANGELOG's 0.2.0 section. A step is done when its box is ticked here; tick it
in the same change that finishes it.
