# Memory safety: writes, bounds, lifetimes and aliasing

Started 2026-10-16. Decisions are the user's, made after measuring what the compiler did; each
section says what was measured, what was decided and where it lands. The `Ptr<T>` design is
PTR_PLAN (removed; in git history); this file is what a program may *do* with pointers, arrays and
slices without corrupting memory. It is the work behind [MEMORY_PLAN.md](MEMORY_PLAN.md) §1's
rule: no known way to corrupt memory in a program that compiles.

**Scope of "safe".** Code that has not written `import std.raw` cannot corrupt memory: what it
does is accepted and correct, refused at compile time, or stopped at run time with a message.
`std.raw` is the one door to promises the compiler cannot check (`cast`, `atUnchecked`,
pointer stepping), and a foreign function's pointer is its author's promise.

## 1 · Writes through a pointer

| Rule | Measured 2026-10-16 | Decision |
|---|---|---|
| A compatible value may be written | `p.store(v)`, `p.field = v`; a literal takes the pointee's width and is range-checked | Holds |
| A convertible value needs an explicit conversion | `U8`→`Int`, `Int`→`U8`, `Float`→`Int`, `Bool`→`Int` all refused without `as` | Holds. Dropping `mut` from a pointer (`Ptr<mut S>` into a `Ptr<S>?` field) stays implicit: the value is the same, only the rights shrink |
| A larger type through an incompatible pointer is invalid unless every requirement holds | `Ptr<mut U64>.cast(bytePtr)` accepted unchecked; `p.byteOffset(1)` made a misaligned `Ptr<mut Int>` without `std.raw` | `cast` refuses a stricter-aligned target (names `castAligned` and the new `castUnchecked`); `offset`, `byteOffset`, `wrappingOffset` need `import std.raw`; `advance(n, limit)` stays safe |
| Assignment never changes an allocation's size | `Array<T, 3> = [4 elements]` and `= [2 elements]` refused; a `String` is a handle, so `s = "longer"` replaces it and never writes into the old storage; `Ptr<String>` is refused; `Buffer` writes are bounds-checked | Holds. The C `strcpy(char[4], "longer")` has no spelling except an out-of-range index or pointer step (§2) |
| A larger region than the object is never touched | `Array<T, N>` / `[T]` indexing unchecked (writes the neighbouring stack, even `a[3]` on three elements); `Vec` out of range reads `0` and ignores a write; `Slice` and `Buffer` trap | §2 |

## 2 · Bounds

Decided: **a constant index out of range is a compile error; any other index is checked at run
time and stops the program with a bounds error, except where the range prover already proves it
in range.**

Built 2026-10-16 for `Vec` and `Array<T, N>`. A `Vec` index fails in the runtime
(`list_index_fail`, curated accessors call it out of line) and in codegen's inline flat-list
paths (`list_bounds_or_fail`), which had implemented the old zero a second time; an array index
fails through `ir_array_index_check` / `array_index_fail`, skipped where `irAccessProved`. A
freestanding program reaches `prismio_panic_hook` (weak defaults in `runtime/freestanding/panic.c`),
which reverses FREESTANDING_PLAN 1.3's "unchecked by default" -- confirm with the user. The
fixtures that asserted the old zero were converted to `// expect-trap:` cases (one run per case).
Two findings on the way: a `Vec` loop whose wrapped index the old rule summed to the right answer
(test_123's `wrapUp`) now stops, as it should; and `for i in 0..<n { a[i] }` is not versioned for
its checks, because LLVM hoists them as one compare of `n` and still vectorises. `Array<T, N>`, `[T]` and `Vec<T>` all trap; a `Vec` no longer answers `0`. The check
is a compare and a cold branch; the benchmark matrix is run before and after, and an unproven
index in a hot loop is a range-prover gap to close, not a reason to drop the check.

**A `[T]` parameter becomes a fat view, `{ pointer, length }`** (decided 2026-10-16). It had no
length at all, so nothing could check it, and `xs.length`, `for x in xs` and the searches were
refused on it (neg_251). One compiled copy per function, one extra register per argument, and
every index is checked against the real length. This replaces COLLECTIONS.md step 3's
per-length instantiation, which is no longer needed. No `extern fn` takes a `[T]`, so the C ABI
is untouched; a C caller of an `export fn` that takes one is refused.

## 3 · Lifetimes

| Operation | Measured 2026-10-16 | Decision |
|---|---|---|
| Read a live pointer | allowed | allowed |
| Read or write after `free(p)` | compiles, no trap (read `0` from recycled memory) | rejected (§3.1), else trapped in a debug build (§3.2) |
| `free(p)` twice | compiles, silent; only `--verify` reports "release of a pointer that is not live" | rejected (§3.1), else trapped (§3.2) |
| A slice after its `Vec` is cleared | traps: "outside view [0..2] of collection length 0" | unchanged: `clear` keeps the storage, and the bound catches it |
| A slice after its `Vec` is reassigned | reads the freed header (`--verify` showed the poison length `-572662307`) | rejected (§3.3) |
| A slice of a local `Vec` returned from a function | compiles; the `Vec` was placed in the frame (0 heap allocations), so the slice points into a dead frame | rejected (§3.3) |

### 3.1 · An owning `Block<T>`

`allocOf<T>(count)` (and `allocZeroedOf`, `reallocOf`) answer a move-only `Block<T>` that owns
the memory. `free(block)` consumes it, so a second `free` or a use after it is *use of moved
value*; a block never freed is released at scope end like any owned value. Pointers into it
(`block.pointer`, `block.at(i)`) are views, and the ownership analysis (AIF) refuses one that is
used after the block it came from is freed, moved or out of scope, where it can see both.
`Ptr<T>` itself stays a copyable, non-owning word; a `Ptr<T>` from `std.raw` or a foreign
function is its author's promise.

### 3.2 · A debug-build trap

What the analysis cannot see -- a raw pointer, a view that crossed functions -- a debug or
`--verify` build checks at run time: freed blocks are quarantined and poisoned, and every access
through a typed pointer and every release is checked against the live set, stopping the program
on a use after free or a double free. Release builds do not pay for it.

### 3.3 · A slice dies with what it views

Decided: once the `Array` or `Vec` a slice views is dropped -- reassigned, moved, or out of
scope -- any later use of the slice is a compile error, named at the use and pointing at the
drop. A slice of a local cannot be returned or stored past its owner's scope. Growing the `Vec`
(`push`) is not a drop: the slice finds the block again, as it does today. Zero run-time cost.

## 4 · Two mutable pointers to one place

Measured: allowed. Since the soundness pass (PTR_PLAN) a pointer access carries no TBAA tag and no
`noalias`, so the optimiser assumes any two may overlap: always correct, sometimes slower (a
loop writing through one and reading through the other gets a run-time overlap check or no
vectorisation).

Decided: **may-overlap stays the default; `unique p: Ptr<mut T>` is the opt-in.** It gives LLVM
`noalias`. Sema refuses passing the same pointer to two `unique` parameters of one call (the rule
`unique` already has), and a debug build checks at entry that a `unique` pointer's pointee does
not overlap another pointer argument's.

## 5 · Order

Status 2026-10-16: **steps 1 and 2 built** except the fat `[T]` view; the rest not started.

1. §1's `std.raw` gate and `cast` rule, and two bugs found on the way: a struct with an inline
   `Array<U8, N>` field was refused as a pointee, and `??` in a file that had not imported
   `std.option` but reached it through another import failed as "declares no
   `optionCoalesce$Int`" instead of "needs `import std.option`".
2. §2 bounds.
3. §3.3 slice invalidation, including the returned frame slice.
4. §4 `unique` on pointer parameters.
5. §3.1 `Block<T>`.
6. §3.2 the debug-build trap.

**After step 2's fat view, not part of memory safety but waiting on it:** rest parameters,
`fn concat(self, ...parts: String)`, lowered at the call to a frame array and a `[String]` view.
`impl String` carries five hand-unrolled `concat` overloads (2-6 parts, each with its own
`__builtin_string_concat_inlineN`) and the parser groups an interpolation into sixes, because
there was no way to pass N parts to one body without a heap list. One body replaces all five;
measure the string benchmarks and a self-compile first, since 53% of the compiler's strings are
4 bytes or fewer and the inline path is the cost.

Each step: the suite, `--verify` on the new fixtures, a two-generation IR fixpoint, the AIF
differential, both docs apps' example gates, and (for §2) the benchmark matrix before and after.

## 6 · State at the end of the 2026-10-16 session (read this first)

**Nothing is committed.** Branch `ptr-slices` (stacked on `enum-visibility` on `ptr-typed-pointer`), last
commit `7a3b341`. Two rounds of work sit uncommitted beside other people's edits; keep them apart when committing.

**Not this session's, leave alone or ask:** `sandbox/src/main.psm` (the user's scratch, never commit);
`benchmarks/**` (graph_churn work), `benchmarks/run.py`, `docs/GRAPH_CHURN_FINDINGS.md`,
`tests/test_302_struct_in_two_vecs.psm`, the `test_302` entry in `tests/test_runner.py`'s aif_verify table,
`runtime/aif_support.c` (an A-CONTAIN edit, see below), `std/map.psm` (a typo, `fprismioindSlot`, in a
comment), `docs/FEATURE_BACKLOG.md`, and in `../website` the `.velite/*.json`, `globals.css`,
`prismio.tmLanguage.json` and `packages/docs-core/src/velite/index.ts`. Those last two files and
`FEATURE_BACKLOG.md` changed *during* the session: check `ps` / list_sessions for a concurrent session first.
`CHANGELOG.md`, `docs/KNOWN_ISSUES.md` and `tests/test_runner.py` mix both.

### Round 1: the `Ptr<T>` soundness pass (PTR_PLAN "What the soundness pass settled")

Pointer accesses carry no TBAA tag (`ir_ptr_load`/`ir_ptr_store`, replacing the `*_volatile` backend
functions; a real -O3 miscompile through two cast pointers was reproduced and fixed); no `dereferenceable`
on `Ptr<T>` params; `advance` is a plain GEP over a non-exact `sdiv`; `volatile` never converts to the
opaque `Ptr` nor casts to non-volatile (test_291's `forget` removed); packed-struct fields are accessed at
`align 1` (`access_align`, read off the GEP) and `semaCheckPackedStructs` refuses fields that would be read
through at a larger alignment. Fixtures `test_303`, `neg_305`, `typed_pointer_ir` cases. Verified then:
`prismio verify` suite 616/616, two-generation IR fixpoint, docs gates; the AIF differential failed on
`src/main.psm` **only** because of the pre-existing `aif_support.c` edit (proved: HEAD + round 1 agrees on
all 19 sources). That edit's oracle half (`tools/aif_oracle`) is unwritten.

### Round 2: this plan's steps 1 and 2

- §1 built: `offset`/`byteOffset`/`wrappingOffset` need `import std.raw` (`semaPtrStepIsRaw`); `cast` to a
  stricter-aligned pointee is refused (`semaPointeeAlign`, from the type, not the backend's layout) and
  `castUnchecked` added; an inline `Array<U8, N>` field is a valid pointee (`semaPtrFieldIsPlain`); `??`
  requires the *file* to import `std.option`. Fixtures `neg_306`, `neg_307`, `neg_308`, test_291/298/neg_296
  updated.
- §2 built for `Vec` and `Array<T, N>`: runtime `list_index_fail` / `array_index_fail` (`PRISMIO_FAILS`,
  weak freestanding defaults in `runtime/freestanding/panic.c`); codegen's inline flat-list paths trap via
  `list_bounds_or_fail` / `bounds_or_fail`; arrays via `generateArrayIndexCheck` → `ir_array_index_check`,
  skipped where `irAccessProved`; constant index → `semaCheckConstantIndex`. Harness form
  `// expect-trap: <arg> => <message>` (`run_expected_traps`); 20 fixtures converted from the old "reads 0"
  to trap cases, gated in place with `trapCase("…")`. New `test_309_array_bounds`, `test_310_vec_bounds`,
  `neg_309_constant_index`.
- Verified: suite 619/619 (before the three new fixtures; those pass on their own, 54/54 with the pointer
  and loop fixtures); bootstrap gb1→gb4 fixpoint identical (after the Vec trap, *before* the array checks —
  **re-run the fixpoint**); docs gates 306 + 50 and the content audit. **Not run since the array checks:**
  `prismio verify` (AIF differential), `prismio gate`.

### Open, in order

1. **DONE in round 5 (below).** Two Map benchmarks regressed; cause found 2026-10-16 (evening). The user
   chose std-only unchecked Vec builtins plus an `inline fn` modifier (KNOWN_ISSUES has the entry). Interleaved A/B
   (HEAD vs now, in-process `elapsed_ns`, checksums identical): `key_value_update` **1.13x**,
   `mixed_map_removal` **1.10x**. The cause is the runtime-side checks in the curated scalar accessors
   (`list_get_inline_scalar`, `list_set_inline_scalar`) inside the Map's own functions: `mapProbe` grew
   from 143 to 194 instructions (two checks per probe step: `slots[at]` and `entryKeys[entry]`) and LLVM
   stopped inlining it into the benchmark loops (4 -> 8 out-of-line call sites), and `mapRemove` lost its
   inlined `mapBucketOfEntry`/`list_swap`. The pre-optimisation IR of `mapProbe`, `mapSet`, `mapGetOr` and
   both benchmarks is identical to HEAD's apart from labels. Measured on the saved whole-program IR
   (`PRISMIO_SAVE_IR`, relinked with `clang -O3`, which reproduces 1.11x / 1.04x):
   - Refuted: the checks in codegen's inline paths (removed them all: still 1.11x); the accessors losing
     `memory(read) willreturn nosync` (clang infers less once they can call `exit`; restored them: still
     1.11x); and, from the earlier session, LICM blocked by the failure call.
   - Every Vec check removed: 0.96x. Checks removed only inside `map*` functions: `key_value_update`
     0.96x min, `mixed_map_removal` unchanged. `mapProbe` force-inlined alone: `mixed_map_removal` 0.96x.
   - **Both together: `key_value_update` 0.786x, `mixed_map_removal` 0.95x of HEAD** -- faster than before
     the checks existed.
   Those indices are proved by the table's invariants, not by anything LLVM can see (`at & mask` with
   `slots.length == mask + 1`; an `entry` read out of `slots` is below `entryKeys.length`). The fix is a
   std-only unchecked Vec read/write used where the invariant holds (as `strMatchesAtIn` already uses
   `__builtin_string_byte_at`), plus inlining `mapProbe`; both need a seed refresh if `src/` reaches
   `std.map`. **Method:** build both suites with `prismio build benchmarks/hosted/prismio/suite.psm` from a
   copy of HEAD's `benchmarks/` outside any source tree (each compiler then uses its own installed runtime),
   run `suite <name> input.txt out.txt` alternately and compare `elapsed_ns`. Sequential `run.py` runs
   drifted by 20% between runs and are not usable for this. A HEAD compiler must be bootstrapped by a
   HEAD-era generation (`build/gslice3`): the current one emits `array_index_fail`, which HEAD's runtime
   lacks.
2. **Freestanding default: confirmed checked** by the user (2026-10-16); FREESTANDING_PLAN 1.3 updated. The
   three freestanding rows the checks had cost are back (round 3).
3. §2's **fat `[T]` view** `{ptr, len}` (decided), then `[T]` indexing checks, `xs.length`, `for x in xs`.
4. Rest parameters `...parts: String` and collapsing `impl String`'s five `concat` overloads (§5 note).
5. §3.3 slice invalidation (a slice of a dropped/reassigned/moved Array or Vec is a compile error; the
   returned frame slice is a live memory-safety bug today), §4 `unique` on `Ptr` params, §3.1 `Block<T>`,
   §3.2 the debug-build trap.
6. KNOWN_ISSUES: the module has no data layout while IR is built (`i64` align 4, U64 atomics become
   `___atomic_compare_exchange`).
7. The original brief's items, untouched: commit the IntelliJ plugin follow-up (`../jetbrains-plugin`, branch
   `ptr-typed-pointer`, review first), cut and pin a seed (`tools/refresh_seed.sh`; publishing is the user's
   call), `prismio gate`, compound assignment on fields (P3302), named arguments for `advance`, `nonnull` on
   `Ptr<T>` returns, the plugin's corpus test.

### Round 3 (2026-10-16, evening): verification, proved indices, freestanding

Verified first: the two-generation IR fixpoint with the array checks; `prismio verify` (suite 622/622; the
AIF differential's two `src/main.psm` disagreements are the `aif_support.c` A-CONTAIN edit's alone: a
compiler built from this tree minus that edit agrees on all 19 sources); both docs gates. Then, all
UNCOMMITTED, suite 624/624, fixpoint identical, compile time unchanged:

- `src/ir/nowrap.psm` proves array indices: facts over `U32`/`U16`/`U8`/`I16`/`I8` with each type's wrap
  rule, comparison refinement on both branches, loop invariants by probing with widening
  (`nowrapInvariants`), `for` range facts, in-range marks read by `generateArrayIndexCheck`, and the walk
  runs for loop-free functions that subscript an array. `src/ir/contents.psm` takes narrow integer arrays
  and `let` read aliases; a too-narrow member fails alone. A program's own `min`/`max` is judged by its
  body. Fixtures `test_311_proved_indices` (12 adversarial trap cases) and harness `proved_indices`;
  `array_contents` and `array_nowrap` expectations moved to pin the wrapping op, not a variable.
- Freestanding partial unrolling (factor 4) in `ensure_codegen_initialized`; freestanding verdicts absolute
  in `benchmarks/freestanding/suite.py` and `benchmarks/templates/report.html` (user-requested).
- Developer docs page `compiler/async-and-scope` failed the content audit (a page from the async session):
  given a compiler-checked example.
- Freestanding vs C: 17 fewer, 3 level, 0 more (geomean 0.876); hosted 66-workload A/B: noise only.
- Not done: the Map fix (above); array rotation for `edit_distance`'s row copy and a congruence fact for
  `bytecode_interpreter`'s `reg[a]` (KNOWN_ISSUES); integer `min`/`max` for freestanding programs.

### Round 4 (2026-10-16, night): the Map fix, built and measured, NOT verified

State to resume from (all UNCOMMITTED, on top of rounds 1-3):

- **Step 1 (teach) is in the tree:** `__builtin_assume(cond)` (std-only; `ir_assume` in
  `runtime/llvm-api-backend.c`, `src/ir/bridge.psm`, emission in `generateCall` beside `__builtin_assert`,
  sema in `src/sema/builtins.psm`, AIF contract in `src/aif/contracts.psm` and `tools/aif_oracle/aif.py`,
  guard-safe in `src/ir/module.psm` and `irFlatGuardCount`), and `inline fn` (flag 8 in the
  `src/ast/fn_attrs.psm` table, `nodeIsInline`; top level via `isFnModifierWord`, methods via
  `atInlineDecl` in the impl parser; `inline` with `cold` is an error; lowered to `alwaysinline` beside
  the single-callsite rule). Deviation from the agreed design, to report to the user: one
  `__builtin_assume` instead of `__builtin_list_get/set_unchecked`, because those would have had to be
  recognised in every place that matches `list_get`/`list_set` by name and in every representation path
  (scalar, string, boxed, struct, codegen's flat paths); the assume is placed before an ordinary
  access and states the check's own unsigned compare, so LLVM folds the check, and an assume costs
  nothing in the inliner's model.
- **Seed:** cut locally from `build/gi2` (top-level `inline fn` and the builtin, before the impl-method
  form was added), pinned in `bootstrap/seed.json` (sha 41abf4cd...), from-seed bootstrap verified
  byte-identical to gi2. Old seed and pin backed up in the session scratchpad only. **Re-cut it from the
  final compiler before committing** (the impl-method parse came after). Not uploaded: the user's call,
  and the asset name `prismio-seed-0.1.0.ll` collides with the published v0.1.0 asset (see
  docs/VISIBILITY_AND_FLUENCY_PLAN.md step 1).
- **Step 2 (use) is in the tree:** `std/map.psm`: `entryKeys`/`entryValues` are now `private` (no
  program, test or benchmark used them; sema reads their types by name regardless), `mapProbe` is
  `private inline fn`, and four `__builtin_assume`s (slots read and entryKeys read in `mapProbe`, the
  write in `mapSet`, the read in `mapGetOr`), justified by the two invariants written on the struct.
  `prismio build --release` was needed to refresh `.prismio/build/stdlib/*.plib`.
- **Measured** (interleaved A/B, 21 runs, checksums identical), against HEAD before any check:
  `key_value_update` 0.781 (was 1.136), `mixed_map_removal` 0.915 (was 1.103), `hashmap_insert_lookup`
  0.891, `word_frequency` 0.884.
- **Not done:** fixtures (`test_312_inline_fn` with an `inline_fn` IR harness test beside
  `cold_function`; `neg_310` inline+cold; `neg_311` `__builtin_assume` outside std; `neg_312` a program
  reading `m.entryKeys`), the full suite, the two-generation fixpoint with the std change, `prismio
  verify` (AIF differential: the oracle has the contract), the hosted 66-workload A/B, CHANGELOG, both
  docs apps (stdlib map page: columns private; language docs: `inline fn` beside `cold fn`; developers:
  `__builtin_assume`), the IntelliJ plugin's lexer (`inline` modifier), and deleting the KNOWN_ISSUES
  Map entry once verified.
- **Code size, open decision for the user:** freestanding `.text` is 29.9 KB against C's 14.9 KB. The
  shared harness is 9.6 KB of each, so benchmark code is about 19.9 KB against C's 5.4 KB; rolled it was
  7.2 KB (bounds-check failure calls, the range prover's second loop copy, zero-filling memsets). Unroll
  settings measured on the 20 workloads (instructions geomean, `.text`): off 1.000 / 17.4 KB; factor 2
  0.942 / 21.4 KB; factor 4 with `-unroll-partial-threshold=60` 0.928 / 20.0 KB; factor 4 (current)
  0.914 / 29.9 KB. `mandelbrot_fixed` alone grew 784 -> 5,952 bytes, `matrix_multiply` 740 -> 2,792.

### Round 5 (2026-10-17): the Map fix verified

Done and verified: fixtures `test_312_inline_fn` (+ harness `inline_fn`, reads `alwaysinline` off the IR),
`neg_310_inline_cold`, `neg_311_assume_outside_std`, `neg_312_map_columns_private`; `cold inline fn` and
`cold export fn` now parse (a leading `cold` starts the modifier chain; `impl` methods take `cold`/`inline`
in either order, `atMethodMarker`). **Making the columns private broke map literals and `default`**: sema
reads the columns' types by name through `semaFindStructFieldType`, which applies the visibility check
(round 4's note said it did not). `semaCompilerFieldType` is the unchecked twin for those two sites.
Suite 638/638; two-generation IR fixpoint identical (gz1 = gz2, and a from-seed bootstrap of the re-cut
seed gives the same IR); `prismio verify` passes steps 1-4 and the AIF differential's only disagreements are
`src/main.psm`'s (T2 138/137 and 269/266, T3 612/613 and 481/484: the same 1/3 shape as before, the
`aif_support.c` A-CONTAIN edit's, not re-proved by a build without it). Seed re-cut and pinned
(`9b58ef08...`), NOT uploaded. Hosted 66-workload A/B vs the build before any check, both packaged:
`key_value_update` 0.79x, `hashmap_insert_lookup` 0.89x, `word_frequency` 0.88x, `mixed_map_removal` 0.94x,
geomean 0.984, nothing more than 6% slower. Docs gates 306 + 51, content audits, IntelliJ plugin tests pass.
KNOWN_ISSUES' Map entry deleted. **Open:** the project-built runtime (`.prismio/build/lib/runtime`) is
`macosx27.0.0` with no `SDK Version` flag, so programs a project-built compiler links say `sdk 11.0` and
allocate about 2x slower than the packaged toolchain's (tree_traversal 1.8x, manual_alloc_churn 2.1x);
time only packaged compilers.

### Things that cost time this session

- `python3 tests/test_runner.py` with no `--compiler` tests the launcher's **project host**
  (`.prismio/build/release`), not what you just built: pass `--compiler .prismio/build/debug/prismio` with
  `PRISMIO_INTERNAL_HOSTED=1`. It reported a non-compiling fixture as passing.
- After any `runtime/*.c` edit the host refuses ("installed Prismio runtime library is stale"):
  bootstrap from the last bare generation (`build/ge1` is current), then `build --release`, then
  `prismio build`.
- Codegen implements some runtime semantics a second time inline (the flat-list bounds paths did): change
  both, and grep `llvm-api-backend.c` for the old behaviour.
- A fixture whose arms "agree under the old rule" can hide a behaviour difference; test_123's `wrapUp`
  only showed its out-of-range reads once they trapped.
