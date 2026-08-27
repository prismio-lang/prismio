# Handoff — 2026-08-29

**Current compiler: `build/ovf-4`. Suite 174/174, fixed point, AIF differential 18/18,
86 programs under `--verify` with 0 violations, a from-seed bootstrap reproducing it byte-for-byte.**

Two ownership items, debug-mode overflow checking, a parser defect, and the first real answer from
the three-platform CI matrix.

**The matrix says the `PRISMIO_INLINE_RUNTIME` default is not portable.** Pushed for the first time
on 2026-08-29 and all three platforms failed. Windows built and then failed *every* suite test
assembling the curated merge — `expected memory location (argmem, inaccessiblemem)` — because the
compiler links the provisioned LLVM-C while the native build step shells out to a bare `clang` from
`PATH`, and on `windows-latest` those are different versions: LLVM 22 writes
`memory(..., target_mem0: none, target_mem1: none)` and the image's clang cannot parse it. macOS and
Ubuntu never got that far, taking a **403** from the GitHub API — the unauthenticated per-IP rate
limit, not a missing release. **A control branch at `97ef065` fails identically**, so neither
predates nor was caused by this session's work. Two fixes are in the tree (`GITHUB_TOKEN` on the
provisioning step; the provisioned LLVM's `bin` prepended to `PATH`) and the parent item stays
unchecked until a green matrix is *observed*. The durable fix for the Windows half is in
`build_driver.c`, which should take clang from `llvm-paths.json` rather than `PATH`.

**Debug-mode overflow checking landed**, and the recorded premise did not survive measurement. TODO
said a native `llvm.sadd.with.overflow` lowering "should be cheaper than a sanitizer": it is not —
5.36×–5.95× against the sanitizer's 5.42×–5.72×, because the cost is the *branch*, which defeats
vectorization (17 NEON registers in the plain loops, none in either checked form). And the 4.1–4.4×
does not transfer to whole programs: on the corpus `--overflow-checks` is **1.00×–1.12×** with
checksums agreeing. Default stays off on the 6× worst case.
[`RESULTS-overflow-checks.md`](aif/evidence/RESULTS-overflow-checks.md).

**A parser defect it found:** every `BINARY_EXPR` carried the position of the token *after* it,
because `parserNode` ran after the right operand was parsed. Invisible until something reported a
position out of one. Both constructions now anchor on the operator token; zero of 128 programs
changed IR.

Two ownership items closed, and the first of them was not on the list.

1. **A binding that escapes through a callee's *return* was being freed under its caller.**
   Not a leak — a **use-after-free**, and `--verify` reports `0 violation(s)` while it segfaults,
   because the allocation is released exactly once and simply in the wrong frame. Found while
   trying to widen the same drop path for item 2 below, which is why item 2 was not safe first.
   `nodeReturnsName` saw `return t` and not `let x = passthru(t); return x`.
   `aif_fn_may_return_param` is the missing fact (`pt[RET(f)] ∩ pt[PARAM(f,i)]`);
   `nodeEscapesThroughCall` is the guard, **driven from the `return`, not from the argument** —
   the cheaper direction costs a correct drop in `test_47_aif_containers`.
   Discriminator `tests/test_85_passthrough_escape.psm`, observed at **exit 139 (SIGSEGV)**.
   IR byte-identical on 127 of 128 programs.
   [`RESULTS-passthrough-escape.md`](aif/evidence/RESULTS-passthrough-escape.md).

2. **An owned call result consumed directly as an argument now has an owner.**
   Codegen asks `aif_owns_call_result_at_node` in argument position and releases the temporary
   once the enclosing call returns — the caller is the last owner, because a Prismio parameter is
   a borrow (Swift's `@guaranteed`). **92/52/40 → 92/92/0**, both halves still printing 3010520;
   five other fixtures improved, none regressed.
   [`RESULTS-owned-temporary-argument.md`](aif/evidence/RESULTS-owned-temporary-argument.md).

**Two recorded beliefs were wrong and are corrected in the tree, not just here:**

- *"A Prismio callee needs the `RETAIN_IN_BASE` question answered from the escape facts before any
  drop is emitted."* It does not. **Sema already rejects it** — `list_push(dst, b)` on a by-value
  parameter is *"cannot move out of borrowed value"*. Parameters are borrows, so the retention half
  is the type system's, not the analysis's. The field-store route that sema *does* allow is already
  declined by `site_in_released_field`.
- *"`--verify`'s `violations` is what corruption looks like from outside."* True but incomplete: a
  **read** after free is not a double free, so the ledger balances and reports 0 while the program
  crashes. `violations` means corruption; it does not mean all corruption.

**Nothing is committed.** The `PRISMIO_INLINE_RUNTIME` remote three-platform gate is still blocked
on push authorisation, and three discriminating checks are waiting on it.

**What is still open on this path**, all in `TODO.md` as checkboxes: a `spawn`ed call's temporary
(needs a join-time release; `g9_helper_leak.psm` is the fixture and its IR was deliberately left
byte-identical), the argument release when the enclosing call returns a pointer, the same escape
through an `extern` declared `alias`, and ownership surviving a second return.

Everything below is retained history.

---

# Handoff — 2026-08-26, third session of the day

**Current compiler: `build/nostr-4`. Suite 172/172, fixed point, AIF differential 18/18.**

Two decisions and one large refactor, on top of the cold-compile/concurrency work below.

1. **`Int` stays signed 32-bit — decided by measurement, not inheritance.** The choice had never
   been justified anywhere in the tree. Go's and Swift's indexing argument is worth **zero** here
   (i32-wrapping, i32-`nsw` and i64 indices all read 0.225–0.226 ms; AArch64 emits no `sxtw`,
   x86-64 one `movslq` in every arm). Making overflow UB to unlock `nsw` is worth **less** than
   zero — 1.014×/1.006×/1.005× on the compiler's own emitted IR for g1/g3/g4. Rust RFC 0212's
   density argument is the one that survives: 64-bit fields cost **1.330×** in Prismio and
   1.76–2.15× in the C control. [`RESULTS-int-width.md`](aif/evidence/RESULTS-int-width.md).

2. **The C string layer is gone.** 1,093 call sites in `src/`, 109 in `ums/`, 82 in `tests/`.
   Twelve C functions and `StringArray` deleted; contracts removed from `contracts.psm` *and*
   `aif.py` together. **Parse+sema 0.843×**, full emit 1.030×, whole builds flat, and emitted IR
   **byte-identical on all 94 programs**. Nothing had ever been removed from `lang_runtime.c` —
   that is why the old functions still worked.
   [`RESULTS-string-migration.md`](aif/evidence/RESULTS-string-migration.md).

**Two ownership limitations, both with discriminating reproductions in `tests/`:**

- `owned_temporary_argument.psm` — an owned call result passed straight into another call has no
  owner. One `let` is the whole difference: **bound 27/27/0, unbound 107/27/80.** *This was first
  written up as a `spawn` defect; that was wrong — the same program leaks identically with the
  spawn removed.* An automatic region usually hides it; `prismio aif --why` says exactly when it
  cannot and names the repair.
- `owned_return_depth2.psm` — ownership does not survive a second return
  (`sites[s].fn != c->fn`). Depth 1 is **6/6/0**; one more level gives **12/7/5**. Invisible while
  `std.string` was C, because an `extern fn` carries its `produce` contract.

**Neither is fixable by removing the guard** — both guards prevent double frees. Enumerate the
existing owners first; that warning is in the tree because a previous attempt collided with three.

**Still externally blocked:** the `PRISMIO_INLINE_RUNTIME` remote three-platform gate needs
commit/push authorisation. Three discriminating checks are waiting on it now.

Everything below is retained history.

---

# Concurrency + cold-compile handoff (2026-08-26, second session of the day)

**Current compiler: `build/task-rel-2`. Suite 172/172, fixed point, AIF differential 18/18.**

Three items closed and one compiler defect fixed:

1. **Genuinely-cold compilation, closed.** A cold build was compiling `lang_runtime.c` twice — once
   for the curated module, once for the runtime object. The curated intermediate is now **bitcode**,
   is retained for the rest of the build, and the object is lowered from it with
   `-Xclang -disable-llvm-passes` (target backend only). Bitcode rather than textual IR because that
   round trip produces an object **byte-identical** to `clang -O2 -c` and the textual one does not.
   Cold and `PRISMIO_OBJ_CACHE=0` builds are **0.804–0.818×** of the previous compiler with the
   cached paths unmoved. Provably codegen-neutral: linked executables are byte-identical.
   `PRISMIO_BUILD_TRACE=1` is the new per-stage trace that made the attribution possible.
   [`RESULTS-cold-compile.md`](aif/evidence/RESULTS-cold-compile.md).

2. **The corpus has a concurrent program.** `g9_bands` — four `spawn`ed bands per frame, joined at
   the frame boundary — plus `g9_idiomatic.rs` (`std::thread::spawn` per frame, the honest peer) and
   `g9_tuned.rs` (a persistent worker pool). **Prismio is 0.89× idiomatic Rust** on it, with 0.13×
   the allocations, because E-SPAWN-J keeps the spawn argument **T0/stack** while Rust must box a
   `'static` closure every frame. Hand-tuned Rust is still **1.45×** faster: it has a pool and
   Prismio cannot express one. [`RESULTS-concurrency.md`](aif/evidence/RESULTS-concurrency.md).

3. **The task handle had no owner.** `prismio_task_release` existed from the day tasks did and
   codegen never emitted it — every `spawn` leaked one handle, invisible to `--verify` because the
   handle is plain `calloc`. Released at the **scope exit** (not the join: handles are copyable and
   nothing stops a second join) and only where E-SPAWN-J proved the join. **frees 23 → 8,019,
   RSS 2.1 → 1.5 MB, loop flat.**

**The one thing left open, and it is the next sequential work.** A `spawn` argument built in a
*callee* still leaks: `aif_con_return` has already put its escape at Caller before E-SPAWN-J sees
it, and `raise_escape` only raises. Two reproductions are in the tree —
`aif/evidence/xlang/prismio/g9_helper_leak.psm` (80 leaked of 107) and
`tests/test_69_task_results.psm` (4 of 4). **Do not fix it with an unconditional free at the join**:
a task result may alias its argument, a handle may be joined twice, and an unjoined task may outlive
every scope. See the TODO entry for the three candidates.

**Still externally blocked:** the `PRISMIO_INLINE_RUNTIME` remote three-platform gate needs
commit/push authorisation. It now has **two** discriminating checks waiting to run on it —
`run_inline_runtime_default_test` and `run_runtime_object_from_ir_test`.

Everything below is retained history.

---

# M5.1 allocator handoff (2026-08-26)

M5.1 is complete and no allocator dependency shipped. A sound direct seam moved generated object
allocation/release, runtime-owned allocations, verifier shims, and the curated inline module
together. mimalloc v3.4.5 measured **1.021×** corpus-median loop time with **1.242×** RSS; rpmalloc
v1.4.5 measured **1.003×** loop time with **1.627×** RSS. Both were rejected and all temporary
compiler/runtime hooks were removed. The retained-system A/B gate is **0.998×**, suite 166/166,
fixed point, and AIF differential 17/17. Evidence: `aif/evidence/RESULTS-M5-allocator.md`.

Next sequential work is boxed `OBJECT` replacement ownership. `list_set` must reclaim an
overwritten object only when no derived `list_get` borrow can still name it. An unconditional free
is a use-after-free. Research derived borrow liveness, an exclusive replacement operation, and
compiler-supported unique ownership before choosing. After that, profile the genuinely-cold
`PRISMIO_OBJ_CACHE=0` regression by compiler stage.

The inline-runtime remote Windows/Linux/macOS gate is still externally blocked on commit/push
authorization. Do not mark it complete from local evidence.

Everything below is retained history.

---

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

The next work at that point was **M5.1: evaluate mimalloc** behind the allocator seam on g1/g3/g4/g5,
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
