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

The clean comparison baseline in this tree was **143/147**. These four runner
checks failed before the work below and fail with the same messages afterward:

- `forced_layout`: exact size 4095 versus 4096
- `aif_layout`: `ASTNode` first-field layout mismatch
- `aif_verify`: the existing `test_47_aif_containers` and
  `test_53_aif_views` ledger-count mismatches
- `runtime_library`: existing wasm/cross-runtime archive assertions

Do not run benchmarks beside the suite. Its AIF subprocess timeout can turn CPU
contention into misleading `aif exited -9` cascades.

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
two byte loops. Legacy C `str_concat` remains linked for compatibility and for
the differential test.

`tests/test_75_std_string.psm` compares native and C concatenation for normal and
empty inputs.

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

`tests/test_75_std_string.psm` now differentially checks all six removed C
operations. `tests/test_78_std_string_native.psm` covers their boundaries and
ownership; under `--verify` it reports 29 allocated, 29 released, zero leaks,
and zero violations. Emitted IR for that test contains no call or declaration
for any of the six compatibility symbols.

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
- The refreshed committed seed built `build/seedcheck-clean` successfully.
- Full suite with `build/v29`: **145/149**, exactly the four baseline failures
  listed above and no new failures.
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

- Split `runtime/aif_support.c`, hoist the `rt_base_alloc` seam, complete the
  missing foreign ownership contracts, harden `tools/package.sh` for new LLVM
  API dependencies, and add supported channel wrappers.

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
