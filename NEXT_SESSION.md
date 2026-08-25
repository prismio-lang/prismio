# M4.4 generic/container layout handoff (2026-08-25)

Current compiler remains `build/m4-dataview-c-12`; suite **166/166**. M4.4 changes no compiler or
runtime source, so M4.3c's fixed point, AIF differential 17/17, source lists, curated closure and
packaged-runtime gates remain the last generated-code baseline.

M4 is complete. Prismio removes generic templates before sema, substitutes concrete types into
demand-created AST clones, and only then selects a container representation from the clone's static
element type. `test_82_generic_layout.psm` plus `generic_layout_specialization_gate` proves the same
`singleton/get/set` templates use inline operations for a flat struct and boxed operations for a
pointer-bearing struct. Focused verifier: **8 allocated / 8 released / 0 leaked / 0 violations**.
Evidence is in `aif/evidence/RESULTS-M4-generic-layout.md`.

M4.4 deliberately changes no generated code. Its 25-run same-compiler A/A control is **0.997×**
corpus median, range **0.978–1.099×**; that range is the host floor, not an optimization effect.
The prior DataView result still holds: natural source is **0.221× Prismio AoS**, **0.273× idiomatic
Rust**, and **1.076× hand-tuned Rust SoA**, while the separately labelled tuned Prismio source is at
hot-loop parity.

Next sequential work is **M5.1: evaluate mimalloc** behind the allocator seam on g1/g3/g4/g5,
reporting each workload rather than hiding them in a corpus median. M4.4 also exposed a separate
backlog item: boxed `OBJECT` replacement cannot reclaim the overwritten value until the compiler
tracks the end of derived element borrows. It is recorded in TODO and must not be “fixed” by an
unconditional runtime free.

Everything below is the preceding native-string handoff, retained as history.

---

# Fat String / native std.string handoff

Continue the native-string work in Prismio. Verify the working tree before
planning: everything described here is still **uncommitted**, mixed with earlier
work already present when this session began.

```bash
git status --porcelain | grep -v graphify-out
bash tools/bootstrap.sh --seed --out build/v0
bash tools/bootstrap.sh --compiler build/v0 --out build/v1
PRISMIO=$PWD/build/v1 python3 tests/test_runner.py
```

The suite is now **150/150**. Test 150 makes the curated runtime merge's default
discriminating: it requires a successful merge marker on the normal path and
proves `PRISMIO_INLINE_RUNTIME=0` takes the old path. Four checks that previously failed were test-harness
drift rather than compiler regressions and were repaired after the work below:

- `forced_layout` now accounts for the inline list's one replacement allocation;
- `aif_layout` anchors declaration matching, so a struct example in a comment is
  not parsed as a second declaration;
- `aif_verify` expects the allocations that remain after flat `Item`s became
  inline list elements;
- `runtime_library` selects a foreign target the host clang can actually codegen,
  so runtime selection is reached even when Apple clang has no wasm backend.

Do not run benchmarks beside the suite. Its AIF subprocess timeout can turn CPU
contention into misleading `aif exited -9` cascades.

The first standing item in `TODO.md` is complete and has been refreshed after
the next item made the curated runtime merge the working-tree default. Two
isolated 25-run passes against `build/inline-default-2`, with matching
cross-variant checksums, put the current compiler at **1.10x-3.11x idiomatic
Rust** and **0.89x-1.00x its peak RSS**. g4 is the widest runtime gap; g2 is
1.76x and g6 is 2.71x. The current
table is at the top of `aif/evidence/RESULTS-final.md`, with raw evidence in
`results-current.json` and `results-current-pass2.json`.

## Current state

The fat String is on and self-hosting. `String` is `%prismio.str = {ptr, i64}`.
The final two self-host generations (`build/v28` and `build/v29`) emit identical
IR for `src/main.psm`:

```text
SHA-256 7b1e36ff0a61740e1fc763ae4891c5d25c459c6fd6b7b7a2c3d0e35253050986
```

The earlier fat-String changes remain in the working tree: type lowering,
literal construction, fat/raw FFI conversion, aggregate storage handling,
target layout and debug-info support, runtime embedding, and their tests.

The native standard-library pass is now complete down to the documented
compiler/runtime primitives.

### Spawn ABI thunk

Spawned Prismio functions with String parameters now get a pointer-only task
entry thunk. The runtime calls the thunk using its stable `void *` ABI; the thunk
reconstructs each `%prismio.str` with `fatFromPtr` and calls the real typed
function. LLVM therefore handles the native aggregate ABI on AArch64, SysV, and
Windows x64 instead of relying on coincidental register placement.

Implementation:

- `src/ir/module.psm` discovers spawn targets, marks only those with String
  parameters, and emits `__task` thunks immediately after their functions.
- The `SPAWN_EXPR` collector now traverses the call subtree, fixing the old
  string-literal collection gap as well.
- `src/ir/expr.psm` passes the thunk address to `prismio_task_spawn` when needed.
- `tests/test_77_spawn_literal.psm` spawns a two-String-argument function, so the
  old one-register accident cannot satisfy the assertion.

The emitted `x86_64-pc-windows-msvc` IR was inspected: the runtime-facing thunk
is pointer-only and its inner call uses the target's real `%prismio.str` ABI.
`tests/test_69_task_results.psm` still passes.

### O(1) String representation builtins

The old name-based foreign-call interception is gone. The compiler now owns
three reserved operations: `__builtin_string_len`,
`__builtin_string_byte_at`, and `__builtin_string_put_byte`. Sema checks their
signatures without declarations, AIF models them as non-retaining, and codegen
emits a field read, GEP/load, or GEP/store. No LLVM declaration or runtime symbol
is emitted. The obsolete C compatibility exports were removed in v0.1.

### Native `strConcat`

Public `strConcat` in `std/string.psm` is now native Prismio. It reads both
carried lengths, allocates once with `str_with_capacity`, and fills the buffer in
two byte loops. The older C `str_concat` remains a compiler-internal runtime
dependency; neither standard module declares or calls it.

`tests/test_75_std_string.psm` checks native concatenation against explicit
normal and empty-input expectations.

### Remaining `std.string` C calls removed

`strCharAt`, `strEquals`, `strCompare`, `strSubstring`, `strFromChar`,
`strEmpty`, and `strClone` are native Prismio now. All internal trim, pad,
replace, split, and join paths that still called `str_concat` or
`str_substring` were rewritten to allocate their final size once and fill it
with bounded byte copies.

The only declarations left in `std/string.psm` are real runtime boundaries:

- `str_with_capacity`, the allocation/verify seam;
- `str_find_byte` and `str_find_byte_pair`, optional bounded vector search
  accelerators. Pair selection, verification, Two-Way, and fallback policy are
  native Prismio; the pair primitive supplies NEON/SSE2 operations only.

`tests/test_75_std_string.psm` now has no foreign string declarations. It checks
the native boundaries directly and compares optimized substring search with an
independent O(n*m) Prismio reference. `tests/test_78_std_string_native.psm`
covers focused producer ownership. Under `--verify`, test 75 reports 562
allocated and 562 released, while test 78 reports 29 and 29; both have zero
leaks and zero violations. Emitted IR for both tests contains no call or
declaration for the older C string implementations.

### String-clone correctness fix

Self-host validation exposed an older fat-String boundary bug. The ownership
clone path in `src/ir/stmt.psm` called C `str_clone` as returning raw `ptr` and
stored only that pointer into a `%prismio.str` slot. The length half was
uninitialised, making AIF commands take seconds and eventually produce truncated
manifests or get killed.

`generateStringClone` now wraps the result with `fatFromPtr`. A regression in
`tests/test_72_reassigned_ownership.psm` reads the length of a cloned literal
before reassignment and asserts it is eight. All handwritten `ir_call_end("ptr"`
sites in `src/ir` were audited for similar String-producing paths.

## Verification completed

- Two-generation self-host fixpoint: `build/v28` and `build/v29` IR is identical.
- The committed seed rebuilt the default-on candidate and its compiler IR agrees
  with `build/inline-default-2`.
- Full suite with `build/inline-default-2`: **150/150**.
- `python3 tools/check_source_lists.py`: passed.
- `python3 tools/aif_differential.py --compiler build/v29`: all 17 sources agree
  in both as-is and owned modes.
- Documentation examples with `build/v29`: all 116 snippets passed.
- Focused spawn, ownership-clone, std.string, and AIF-concurrency checks passed.
- `test_77_spawn_literal.psm --verify`: clean `0/0/0/0` ledger.
- `test_78_std_string_native.psm --verify`: 29 allocated, 29 released, zero
  leaks and zero violations.
- Its emitted IR contains no declaration or call for any string builtin; the
  obsolete C length/byte-access/byte-write symbols no longer exist.
- The new negative fixture proves source cannot redeclare a reserved builtin.

## Performance evidence

A same-binary comparison ran 100,000 concatenations of 20 KB + 20 KB strings,
with equal checksums. Best of five:

| implementation | elapsed |
|---|---:|
| native Prismio `strConcat` | 46.96 ms |
| legacy C `str_concat` | 171.57 ms |

The native implementation is **3.65x faster** in that workload because it
reuses both carried lengths rather than scanning both inputs before copying.

Substring search now uses the same modern hybrid as `memchr::memmem`: packed-pair
SIMD for short needles, specialized Two-Way when candidates are dense, and an
effectiveness-guarded packed-pair prefilter around Two-Way for long needles.
The NEON loop checks 32 starts per iteration and uses a narrowed movemask.

Cross-language best times from three interleaved runs, retained in `RUNTIME.md`:

| workload | C | Rust std | Rust memchr | Prismio |
|---|---:|---:|---:|---:|
| selective 4-byte search miss | 2.979 s | 1.854 s | 0.149 s | **0.148 s** |
| dense false search candidates | 0.410 s | 0.053 s | 0.107 s | **0.048 s** |
| selective 40-byte search miss | 2.837 s | 2.143 s | 0.808 s | **0.740 s** |
| uppercase | 0.270 s | 0.399 s | — | **0.269 s** |
| integer formatting | 0.042 s | 0.039 s | — | **0.038 s** |
| corrected concat | **0.200 s** | **0.200 s** | — | 0.201 s |

The reproducible sources and checksum-enforcing runner are now in
`aif/evidence/xlang/strings/`. The concat checksum reads both halves so neither
C nor Rust can delete the second copy.

## Sensible next work

- Finish the `PRISMIO_INLINE_RUNTIME` default gate by committing/pushing the
  candidate and observing its new discriminating test on the existing
  Windows/Linux/macOS matrix. Local gates are green; the parent TODO is
  intentionally still unchecked until the remote jobs pass.
- For the next language milestone, design M4.1 views/slices and M4.3 data views.
  M4.2 inline flat `List<T>` storage is already implemented and checked off.
- Split `runtime/aif_support.c`, hoist the `rt_base_alloc` seam, complete the
  missing foreign ownership contracts, harden `tools/package.sh` for new LLVM
  API dependencies, and add supported channel wrappers when framework needs
  outrank the benchmark roadmap.

## Recurring traps

- Editing `runtime/*.c` has no effect until
  `python3 runtime/generate_embedded_sources.py` runs and the compiler is
  bootstrapped again.
- Both `mapType` and `typeIrKey` map frontend types to LLVM types.
- The LLVM context outlives a module; identified types may be uniqued with a
  suffix, so match `prismio.str` by prefix where appropriate.
- `strCharAt` is O(1) now; it checks the carried length before the byte load.
  The internal byte read/write builtins remain unchecked O(1) operations for an
  already-established bound.
- A function's returned owned allocation must be its own; pass-through returns
  are not dropped at the caller under the current ownership analysis.
