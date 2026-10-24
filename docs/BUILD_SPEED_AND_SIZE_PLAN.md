# Build speed and binary size

What is open on compile time and output size, measured before it was written down. It
started as eight proposals, four for compile time and four for binary size. Each one was
tested against the tree on 2026-10-14, and this page keeps what survived. §4 is what was
rejected and why, so the same proposal is not re-run.

The numbers were taken with the release compiler of 2026-10-14 (`.prismio/build/release`,
copied out of the tree) while another session's suite was running, so treat any
difference under ~10% as noise. Programs: `hello` (one `println`), `suite.psm` (the
hosted benchmark program, 2,777 lines with its modules), and `src/main.psm` (the
compiler). Every row below can be reproduced with `PRISMIO_BUILD_TRACE=1
PRISMIO_PHASE_TIMES=1`, plus `PRISMIO_SAVE_IR=<file>` and `third_party/llvm/bin/opt
-time-trace` for the per-pass and per-function splits.

## Where a build goes

| stage | hello | suite.psm | compiler, release | compiler, `-g` |
|---|---|---|---|---|
| frontend (imports, sema, ownership, IR gen) | ~13 ms | ~130 ms | ~1.17 s | ~1.05 s |
| library bitcode merge | 7 | 36–96 | 179 ms | 324 ms |
| **IR pipeline** (`globaldce,default<O3>`, one thread) | 3 | **713** | **3.58 s** | 9 ms |
| machine code | 3 | 264 (8 threads) | 792 ms (8 threads) | **561 ms (1 thread)** |
| link | 17 (`ld`) | 31 (driver) | 121 ms | 117 ms |

For anything bigger than hello, the build time is LLVM's IR pipeline, and the pipeline
runs on one thread. On the compiler, the pipeline splits like this (opt `-time-trace`, `default<O3>`):

| part | ms | parallel today? |
|---|---|---|
| before the inliner (parse, early function passes, IPSCCP, globalopt) | 491 | no |
| CGSCC inliner + function simplification | 1,639 | no |
| **after the inliner** (LoopVectorize, SLP, unroll, InstCombine, ...) | **821**, of which ~650 is function-local pass work | no |

## 1 · Fix first

- [x] **`-O0`..`-O3` did not mean what the help said** (built 2026-10-14). The flag only turned
      on `run_optimization`, an extra pipeline over the frontend's module, while the object step
      stayed at O3 (`g_debug_info ? 0 : 3`). So `-O0` was fully optimised and `-O3` optimised
      twice (suite.psm: 0.86 s default, 0.89 s `-O0`, 1.15 s `-O3`). Now `program_opt_level`
      (build_driver.c) hands the level to `ir_emit_object`, which maps it to the pipeline and to
      the machine-code level as clang does: `-O0` 0.30 s, `-O1` 0.58, `-O2` 0.81, `-O3` 0.86, all
      66 workloads agreeing. No flag is unchanged. `-o x.ll -O<n>` optimises the written IR
      (`ir_write_output_file`), and `run --jit -O<n>` the merged module.

## 2 · Compile time

- [x] **2a. The post-inliner pipeline runs inside the codegen partitions** (built 2026-10-14).
      `prismio_llvm_run_default_half` (runtime/llvm_bridge.cpp) builds `default<O<n>>` in two
      halves exactly as `buildPerModuleDefaultPipeline` does: half 1 (MemProfRemoveInfo,
      Annotation2Metadata, ForceFunctionAttrs, the module simplification pipeline) on the whole
      program, half 2 (the module optimisation pipeline, AnnotationRemarks) in each partition.
      Run as one pass manager, the two halves give the old machine code exactly. Run apart, they
      do not: InstCombine's last-run tracking and the other cached analyses cannot cross into a
      partition's context. Measured instead: 47 hosted workloads at 10x scale, geomean 0.995
      against 1.000 for an identical-binary control, every result equal (worst
      `recursive_tree_rebuild` 1.028, control spread about ±1%, up to 7.8% on `flat_bitset`).
      Compiler build, pipeline + machine code: 4.30 s → 3.63 s; suite.psm 662 → 552 ms. A
      program too small to partition (counted after `globaldce`, before optimisation) keeps the
      single pipeline and its exact output. `PRISMIO_SPLIT_PIPELINE=0` turns it off.
- [x] **2b. Parallel machine code for `-g` and `-O0` builds, and lazy partitions** (built
      2026-10-14). Partitioning `-g` alone gained little, 518 → 461 ms on the compiler,
      because every partition parsed the whole module (~200 ms) and deleted seven-eighths of it.
      Each partition now loads the bitcode lazily, materialises its own bodies and drops the rest
      unread (`prismio_llvm_drop_body`). Machine code: `-g` 512 → 216 ms, release 754 → 608 ms,
      both byte-identical to the eager load (`-g` compared by DWARF and code, since two `-g`
      links never were byte-identical). `dwarfdump --verify` is clean with 8 compile units, and
      lldb resolves breakpoints, locals and globals the same as from one partition. lldb could
      not launch a process here (Developer Mode off), so stepping was not tested.
- [x] **2c. Cached `ld` for partitioned links** (built 2026-10-14). The cached line names the
      object once, and the build puts the partitions back after it, last first, which is the
      driver's order. suite.psm links in 16.9 ms (was 29.9), byte-identical to the driver.
- [ ] **2d (later, research). Frontend reuse across edits.** The inventory below is the first
      step. On the compiler's `-g` build (now ~1.8 s), the frontend is ~1.05 s and the library
      merge 324 ms. These whole-program facts make one function's code depend on code elsewhere,
      so an edit there must invalidate it:
      - **The AIF engine** (`src/aifcore/`) is one fixed point over the whole program:
        the points-to graph, the constraint solver, the call graph by caller
        (`caller_edges_build`), arena placement that counts every caller (`region_confined`), and
        callee summaries the callers read (`param_returns`, `fn_may_return_param`).
      - **Layout** (`src/aif/layout.psm`): a struct's hot/cold split and element layout are chosen
        from every use in the module.
      - **Guard-safe verdicts** (`ir_mark_guard_safe_fn`, `runtime/ir_symbols.c`): per callee, read
        by every caller's loop guard.
      - **Single-loop-call-site marks** (`markSingleLoopCallsiteFunctions`, src/ir/module.psm):
        a callee's codegen depends on how many loops call it.
      - **Reachability** (`src/driver/prune.psm`) and **the generic instantiation set**
        (`src/sema/generics.psm`): both come from the callers.
      Early cutoff would need a per-function summary of what each function contributes to every
      one of these, compared before and after an edit. The AIF fixed point is the hard part, and
      it is a research project, not a build step.

## 3 · Binary size

- [x] **3a. Chained fixups on macOS** (built 2026-10-14). `-Wl,-fixup_chains` on every Mach-O
      link: hello 50,504 → 33,952 bytes (C 33,424), `__DATA` zero-fill only. ld64 applies the flag
      at any deployment target (`Options.cpp`: an explicit `-fixup_chains` is not checked against
      the OS), and its source says chained fixups were back-deployed to iOS 13.4, which predates
      macOS 11. The user asked on 2026-10-14 not to hold anything back for macOS 11, so it was not
      run there.
- [x] **3b. `-Os` and `-Oz`** (built 2026-10-14). LLVM 23 has no Os/Oz pipeline ("Use O2 in
      conjunction with the optsize attribute"), so every function is marked `optsize` (`-Oz`
      also `minsize`) and the O2 pipeline runs; `-Oz` leaves the loop vectorizer off, as clang
      does. On suite.psm `__text` 181,320 → 115,368 (`-Os`) and 81,532 (`-Oz`). The outliner,
      which `minsize` turns on, is never on in a speed build: forced on, it cost 4.1% geomean.

## 4 · Rejected, with the measurement

- **Skip LLVM passes where AIF proves them unnecessary** (`optnone` or a micro-pipeline
  for "pure stack" functions, TBAA and MemorySSA off for non-aliased code; claimed
  40–55% of backend time). Per-function `-time-trace` attribution: on suite.psm, loop-free
  functions take 14% of function-pass time and loop-free functions under 30 lines take 4%.
  On the compiler the figures are 44% and 5%, and the loop-free 44% is big switch-heavy
  functions whose code quality matters. `optnone` requires `noinline`, so it would stop
  exactly the small functions that most need inlining from being inlined. MemorySSA is
  1.4% and the whole AA stack is under 5% of pipeline time. Prismio emits no TBAA, so there
  is nothing to turn off. What survived is 2a.
- **Patch one function's machine code into the binary when its AIF contract hash is
  unchanged** (claimed sub-15 ms rebuilds). A release build is whole-program: closed
  programs are internalised, then `globaldce,default<O3>`, so a body is inlined into its
  callers and a change to it changes their code. A `-g` build is already 0.35 s for
  suite.psm with no pipeline at all. The premise that rustc cannot do early cutoff is also
  wrong (query result fingerprints). What survived is 2d.
- **Pre-baked bitcode templates for generics, patched with sizes.** Generic
  instantiations are 48 of 363 definitions in suite.psm and 2 of 2,225 in the compiler.
  The whole frontend is ~130 ms of a 1 s suite.psm build. A template with only size,
  stride and drop as placeholders cannot carry the element-specific code the frontend
  emits (Bool bytes, String pairs, guard and AIF decisions per instantiation).
- **An in-memory linkerless binary emitter** (claimed 150–400 ms per build). The whole
  link is 17 ms for hello through cached `ld` and 31 ms for suite.psm; objects are already
  handed over in memory. A Mach-O writer would have to reproduce dyld binding, chained
  fixups and the arm64 ad-hoc code signature, all to save at most those milliseconds.
  Embedded LLD was stopped on 2026-09-24 for the same reason. 2c takes the part
  that is real.
- **A synthesised nano-runtime with no dead runtime code.** This is already true. Hosted
  hello has 868 bytes of `__text` and 11 symbols: whole-program merge, internalisation
  and `globaldce` keep only what is called. A freestanding `fn main() -> Int { return 42 }`
  with a two-instruction `_start` links to 16 bytes of `.text` and a 1,112-byte ELF,
  most of it symbol table.
- **Hashed panic messages with a sidecar symbol file.** suite.psm's whole `__cstring` is
  2,001 bytes, of which panic text is a few hundred. Bounds checks trap with no message.
  Removing all of it saves nothing in file size, because the pages are 16 KB.
- **One RX segment for text and read-only data, mutable data trailing.** Read-only data
  is already in `__TEXT` on Mach-O. On macOS a writable segment cannot share an RX
  mapping, and every segment with file contents is page-aligned in the file. The real
  saving is removing the only reason `__DATA` has file contents, which is 3a. The "2–6
  KB macOS binary" target is below what the format allows: C's hello is 33,424 bytes. On
  Linux, lld already defaults to `-z noseparate-code`; that was not measured here.

## Resuming

1, 2a-2c, 3a and 3b were built and verified on 2026-10-14 (see the CHANGELOG). What is left is 2d,
which starts from the inventory above. The Windows build has no bridge, so 2a and the lazy
partitions do nothing there until docs/LLVM_BRIDGE_PLAN.md step 2 lands.
