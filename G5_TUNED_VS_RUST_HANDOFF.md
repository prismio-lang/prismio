# G5 hand-tuned Prismio vs hand-tuned Rust: structural-gap handoff

**Date:** 2026-08-30  
**Status:** historical record. Both sources named below were removed with
`aif/evidence/xlang/` on 2026-09-03, superseded by `benchmarks/` and
`prismio bench`; they are recoverable from `git log`. The structural finding
still stands — it is about code generation, not about those two files — but no
path here can be run as written.  
**Scope:** `aif/evidence/xlang/prismio/g5_tuned.psm` against
`aif/evidence/xlang/rust/g5_tuned.rs` on Apple Silicon.  
**Goal:** hand-tuned Prismio must be at least at parity with hand-tuned Rust.
The stretch gate for claiming that Prismio *surpasses* Rust is Prismio/Rust
`<= 0.90x`, without source-specific peepholes or weaker semantics.

## Executive finding

This is not an algorithm gap. Both tuned programs build material buckets once
and then visit each entity once per frame in material order. The remaining loss
is a compiler representation/codegen ceiling:

1. Rust's `#[inline]` render kernel is inlined into the 4,000-frame loop;
   Prismio's render kernel remains an external call.
2. Rust lowers the inner bucket to a resolved slice and pointer walk. Prismio
   repeatedly interprets generic `List` headers and retains bounds/null fallback
   paths in the hot loop.
3. Rust bucket indices are packed `u32` values (4 bytes). Prismio `List<Int>`
   stores each `i32` in a pointer-sized slot (8 bytes on this target).
4. Rust's entity and mesh vectors have directly addressed records. Prismio's
   selected hot/cold layouts put `Entity` and `Mesh` behind pointer arrays, so
   the gather is a pointer chase followed by another pointer chase.
5. Prismio's layout search chooses a struct split separately from the container
   and access pattern. It has no candidate representing a packed, loop-specific
   hot view of the indirect stream.

The immediate route to parity is hotness-guided inlining plus typed list-loop
views. The plausible route to *surpass* Rust is an effect-guarded packed
DataView/inspector-executor schedule that resolves G5's repeated indirect stream
once, then scans only the fields used by the frame kernel.

## Fairness rule

The required comparison is:

```text
hand-tuned Prismio source + general Prismio compiler optimizations
vs
hand-tuned Rust source + rustc optimizations
```

Do not close this gap by hard-coding G5, by replacing the frame with a constant
submitted count, or by giving Prismio an algorithmic transformation that is not
available as a general compiler/library mechanism. A compiler may exploit a
proved invariant more aggressively than rustc; it may not change observable
mutation semantics. Any persistent packed view therefore needs an effect proof,
a mutation epoch/guard, or a correct fallback.

## Source-level equivalence

Prismio uses a CSR representation:

```text
start[m] .. start[m + 1] -> positions in items
items[p]                 -> entity index
entities[items[p]]       -> entity
meshes[entity.mesh]      -> mesh
```

Rust uses `Vec<Vec<u32>>`, one vector per material, then follows the same entity
and mesh indices. Both remove the natural program's twelve full entity scans.
The CSR-versus-vector-of-vectors distinction is not large enough to explain the
emitted-code gap below.

## What the machine code says

The standard Prismio build emits a separate
`render_bucketed__Struct_Scene_Struct_Buckets` function, approximately `0x138`
bytes. Rust's `render_bucketed` symbol disappears because it is inlined into
`main`.

Representative Prismio inner-loop operations:

```asm
ldr  x6, [x6, x4, lsl #3]     ; items[p], 8-byte scalar slot
ldr  x6, [x7, w6, sxtw #3]    ; entity pointer from pointer array
ldrb w7, [x6, #8]              ; Entity.visible
ldr  x7, [x9]                  ; meshes list/header path
ldr  x7, [x7]
ldr  x6, [x7, x6, lsl #3]     ; mesh pointer from pointer array
ldrb w6, [x6, #4]              ; Mesh.resident
```

This is surrounded by list-index bounds checks and null/fallback edges. Rust's
inlined loop instead keeps bucket, entity, and mesh bases/lengths in registers:

```asm
ldr    w12, [x10], #4          ; packed u32 item and pointer increment
cmp    entity_index, entity_len
umaddl entity_addr, index, 48, entity_base
ldrb   visible, [entity_addr, ...]
cmp    mesh_index, mesh_len
madd   mesh_addr, index, 48, mesh_base
ldrb   resident, [mesh_addr, ...]
```

The important difference is not one instruction. Rust has a typed, resolved
iteration view. Prismio keeps re-entering a generic container abstraction.

## Measurements and what is actually trustworthy

All rows below preserved these checksums:

```text
entities 2000
submitted 8000000
batches 12
evicted 0
```

### Stable conclusion, unstable magnitude

Recent balanced runs put standard tuned Prismio between roughly `1.52x` and
`2.11x` tuned Rust. The direction is stable; the precise magnitude is not.
Existing evidence already records a G5 A/A floor around 6%, and this session
found separately rebuilt binaries with identical render and main disassembly
that still timed very differently. Treat wall-clock ratios as evidence only
when accompanied by A/A controls and a changed hot loop.

### Rejected hypothesis: force full structs inline

A 30-round balanced run compared the current split layout with forced unsplit
layouts. `split_b` is the identical-binary A/A control.

| candidate | median loop ms | vs split | vs Rust |
|---|---:|---:|---:|
| selected split (`split_a`) | 6.654 | 1.000x | 1.522x |
| `Entity` unsplit | 6.858 | 1.031x | 1.569x |
| `Mesh` unsplit | 7.643 | 1.149x | 1.748x |
| both unsplit | 6.887 | 1.035x | 1.575x |
| selected split (`split_b`) | 6.647 | 0.999x | 1.521x |
| tuned Rust | 4.372 | 0.657x | 1.000x |

**Conclusion:** “turn splitting off so lists can inline records” is not the fix.
It enlarges the streamed row and leaves generic representation/bounds paths in
place. Preserve the current split as a candidate and add a better hot-view
candidate; do not globally veto splitting.

### Targeted inlining probe

Changing only the merged LLVM function definition from external to internal
`alwaysinline` removes the render symbol and folds the body into `main`.
Balanced trials observed `0.70x` to `0.89x` of the non-inlined Prismio time,
depending on which independently built control was used. The latest conservative
comparison was:

| arm | median loop ms |
|---|---:|
| ordinary Prismio A | 6.794 |
| forced-inline Prismio | 6.015 |
| ordinary Prismio B (A/A) | 6.685 |
| tuned Rust | 4.327 |

This is an approximately 11% conservative win and leaves the inline prototype
at `1.39x` Rust. A matched manual-IR rebuild showed a larger 30% win, but the
rebuild sensitivity means that magnitude is not accepted yet. The code-shape
result is still causal: the call disappears, some list state moves out of the
4,000-frame loop, and the remaining gap is visible in the inlined body.

**Decision:** targeted hot-function inlining is P0, but it is not “done” until a
same-process or independently rebuilt A/A design confirms the magnitude.

## Ranked structural gaps and implementation solutions

### P0 — The benchmark cannot reliably price small wins

**Gap**

- Each timed frame is only a few microseconds, close enough to timer
  quantization, scheduling, frequency, and code-layout effects to create false
  wins.
- Current A/A often compares one binary with itself. That detects process-order
  noise but not rebuild/code-layout noise.
- G5 has previously moved by 23% while zero relevant functions changed.

**Solution**

1. Add a G5 kernel mode that performs 32-128 render calls inside each timed
   sample, then divides by the repeat count. Keep total work/checksum equivalent.
2. Add independently rebuilt A/A controls from identical IR and flags.
3. For experimental compiler variants, build control/candidate twice, rotate all
   binaries in a balanced Latin schedule, and report bootstrap confidence
   intervals as well as medians.
4. Add a same-process kernel A/B harness where possible. Randomize or alternate
   the order and separate warm-up from measurement.
5. Require machine-code evidence: name the changed function, instruction shape,
   and removed/added hot-loop operations.

**Acceptance gate**

- A/A ratio within `[0.98, 1.02]` in the same run.
- Candidate confidence interval excludes `1.00` or the improvement is at least
  twice the measured A/A floor.
- No result is accepted from G5 wall time alone.

### P1 — Source-function hotness is invisible to LLVM inlining

**Gap**

Rust explicitly writes `#[inline]`. Prismio emits an ordinary externally visible
function and has no profile-guided call-edge hotness in the final optimization
pipeline. The existing workload profiler selects AIF layouts, but its profile is
not LLVM edge/call profile data.

**Solution: implement standard LLVM IR PGO first**

1. Reuse the declared-workload build in `runWorkloadProfile` to emit an
   instrumented program build (`-fprofile-instr-generate` or IR-PGO equivalent).
2. Run the representative workload, merge `.profraw` with `llvm-profdata`, and
   compile the real program with `-fprofile-instr-use`.
3. Pass the profile to the already-merged program/runtime IR so LLVM can use it
   for call-edge hotness, inlining, block placement, unswitching, and unrolling.
4. Keep failure best-effort exactly like the current AIF workload profile: a bad
   or missing optimization profile must fall back, not fail a build.
5. Only after ordinary PGO is measured should MLGO-style learned inlining be
   considered. G5 currently has a missing fact, not a demonstrated need for a
   neural policy.

**Small first slice**

Add a backend function attribute bridge and mark a function `hot`/`alwaysinline`
only when general AIF/workload evidence crosses a high threshold. This is useful
for validating the pipeline, but it must not become a G5 function-name rule or a
global always-inline switch.

**Implementation map**

- `src/main.psm:runWorkloadProfile`
- `runtime/build_driver.c:compiler_build_executable` and program `-O2` command
- `src/ir/module.psm:generateFunction`
- `runtime/llvm-api-backend.c:ir_function_body_start`

LLVM documents the instrumentation -> representative run -> `llvm-profdata`
merge -> profile-use workflow, and emphasizes that training inputs must match
real use. Thin/Full LTO can extend the profile's reach across modules. See
[Clang's PGO workflow](https://clang.llvm.org/docs/UsersManual.html),
[LLVM's PGO guide](https://llvm.org/docs/HowToBuildWithPGO.html), and
[LLVM's multi-stage PGO/LTO guide](https://llvm.org/docs/AdvancedBuilds.html).
MLGO demonstrates that LLVM's inliner policy is replaceable, while MLGOPerf
retargets it for runtime performance:
[MLGO](https://research.google/pubs/mlgo-a-machine-learning-guided-compiler-optimizations-framework/),
[MLGOPerf](https://arxiv.org/abs/2207.08389).

**Acceptance gate**

- `render_bucketed` is inlined because of general hotness evidence.
- Standard tuned Prismio improves outside the new A/A floor.
- Corpus median is `<= 1.03x`; no individual tuned program is `> 1.10x`.
- Debug builds and builds without a workload keep their current behavior.

### P2 — `List` has no typed loop view for boxed or scalar elements

**Gap**

`generateLoopFlatGuard` only serves statically flat struct-element lists. It
declines the entire loop when it encounters any other call. G5 contains boxed
`Entity`/`Mesh` lists and scalar `List<Int>`, so it receives none of the flat
loop-view optimization. `list_get` then reloads `len`/`data` and keeps a fallback
edge around each access. A previous runtime-level attempt to make these loads
unconditional shortened the loop but regressed other programs; the compiler is
the layer that knows a receiver is invariant.

**Solution: typed `(data, len, stride, representation)` loop views**

1. Extend loop analysis from “flat receiver” to “stable receiver.” Use existing
   call/effect summaries instead of rejecting every non-flat call.
2. Resolve each stable list header once in the loop preheader.
3. Version the loop once on its representations and route all accesses through
   the resolved view. Preserve the current generic slow loop as fallback.
4. Lower proved in-range accesses directly. For G5:
   - `m < material_count` plus `start.len >= material_count + 1` can guard both
     `start[m]` and `start[m+1]` once.
   - Before a bucket loop, guard `0 <= p <= past <= items.len` once.
   - Entity/mesh gather indices still need a check unless construction/effect
     analysis or an inspector proves them valid.
5. Emit pointer induction (`ptr += stride`) rather than recomputing
   `base + index*stride` where the loop is sequential.

**Implementation map**

- `src/ir/expr.psm:irFlatGuardCount`, `flatGetStride`,
  `generateLoopFlatGuard`
- `src/ir/context.psm:irLoopFlatGuard`
- `src/ir/bridge.psm:ir_list_flat_elem` bridge surface
- `runtime/llvm-api-backend.c:ir_list_is_flat`, `ir_list_flat_elem`
- `runtime/lang_runtime.c:list_get`

LLVM's ScalarEvolution, LICM, loop canonicalization, dependence analysis, and
strength reduction are the downstream machinery this representation should
unlock; they cannot recover facts discarded behind the generic ABI. See
[LLVM analysis and transform passes](https://llvm.org/docs/Passes.html).

**Acceptance gate**

- No `bl list_get*` in G5's fast render loop.
- List `data` and `len` loads dominate the element loop rather than occur inside
  it.
- At most one range/representation guard per bucket fast path, with a generic
  fallback loop.
- All out-of-range and representation-compatibility tests still pass.

### P3 — Scalars use pointer-sized `List` slots

**Gap**

Prismio `Int` is `i32`, but `List<Int>` is represented through pointer-sized
slots using scalar-to-slot conversion. On AArch64, G5 therefore loads 8 bytes
per bucket index and uses `lsl #3`; Rust loads a packed `u32` and advances four
bytes. This also blocks clean typed alias/range reasoning.

**Solution: specialize scalar list storage**

1. Add a representation tag/typed ABI for `List<Int>`, `List<Float>`, and
   `List<Bool>` rather than routing scalars through `void **`.
2. Store `Int` as contiguous `i32` and lower get/set/push to typed loads/stores.
3. Reuse the existing `elem_size` concept only if it remains unambiguous between
   inline records and scalars; otherwise add an explicit representation enum.
4. Keep an ABI/version guard and generic fallback for lists crossing opaque FFI
   boundaries.
5. Specialize at the monomorphized element type, not by recognizing G5's
   `Buckets` fields.

**Implementation map**

- `src/ir/types.psm:scalarToSlot`, `slotToScalar`
- `src/ir/expr.psm:inlineOpName` and container-call lowering
- `runtime/lang_runtime.c:RtList`, get/set/push/grow/release families
- `runtime/llvm-api-backend.c:rt_list_header_type` and typed list access builders
- list-header agreement tests in `tests/test_runner.py`

Profile-guided allocation-site-specific data-structure replacement has now been
demonstrated in an AOT compiler, which is a useful precedent for specializing a
built-in collection without asking the programmer to rewrite it:
[Automated Profile-Guided Replacement of Data Structures (2025)](https://arxiv.org/abs/2502.20536).

**Acceptance gate**

- G5 bucket item load is 4 bytes (`ldr w...`/equivalent), not an 8-byte pointer
  slot.
- Scalar-list functional, ownership, FFI, target-width, and verify suites pass.
- G5 improves; scalar-heavy corpus programs do not regress outside A/A.

### P4 — Layout selection is not joint over struct, container, and access path

**Gap**

The AIF split model prices field footprint and traversal but cannot choose among
these complete representations:

```text
split hot/cold object + pointer list
unsplit AoS + inline list
typed scalar index list
packed loop-specific hot columns
```

The access-pattern distinction is decisive. A sequential stream may benefit
from the smaller split hot row; an indexed gather may lose to allocation and
pointer chasing. The forced-unsplit experiment proves that a blanket boxing
penalty or global split veto is also wrong.

**Solution: representation-level candidate search**

1. Treat container representation and struct layout as one candidate.
2. Feed the existing profile's sequential-vs-gather fact into that joint cost.
3. Include conversion/build cost, number of executor repeats, mutation rate,
   hot bytes per visited element, allocation count, and expected cache lines.
4. Measure shortlisted candidates under the declared workload instead of using
   only a static score. Keep the static model as the cheap pruning stage.
5. Search per target; AArch64 and x86_64 do not have identical cache and gather
   tradeoffs.

**Implementation map**

- `src/aif/layout.psm` and the currently unwired
  `aifLayoutVetoListElements`
- `src/aif/model.psm` access/traversal facts
- `runtime/aif_support.c` layout candidate scoring and workload observations
- `src/aif/report.psm` candidate reporting/selection

The newest profile-guided optimizer work increasingly validates candidates on
real hardware instead of trusting one approximate cost function. The 2026
AI-PROPELLER work uses profile-guided variant generation and hardware
measurements for its search; the domain is code layout, but the evaluation
discipline is directly applicable here:
[AI-PROPELLER (2026)](https://research.google/pubs/ai-propeller-warehouse-scale-inter-procedural-code-layout-optimization-with-alphaevolve/).

**Acceptance gate**

- The report explains the complete selected representation, not only `split
  N/M`.
- Replaying the same workload and target selects the same candidate.
- G4 tuned keeps its beneficial narrow hot row while G5 may select a different
  gather-oriented view.

### P5 — No reusable packed view for the repeated indirect stream

**Gap**

Even after inlining and typed lists, G5 still performs:

```text
bucket index -> entity -> mesh -> resident
```

for every entity in every one of 4,000 frames. Rust does this efficiently but
still does it. This is the opportunity to surpass Rust rather than merely match
its AoS loop.

**Solution: effect-guarded packed DataView / inspector-executor schedule**

Build a schedule once for a stable frame region:

```text
material_start[]        packed i32 offsets
entity_index[]          packed i32, or eliminated after validation
visible[]               packed byte/bit column
mesh_resident[]         packed byte/bit column resolved through Entity.mesh
```

The executor scans these columns linearly. A stronger version stores one
`eligible` byte per scheduled entity when the effect system proves both source
fields stable. This is a general optimization for repeated indirect reads, not
a constant result: it remains valid only while the source epochs match.

Required legality contract:

1. The bucket/index list is not resized or reordered during schedule reuse.
2. `Entity.mesh`, `Entity.visible`, and `Mesh.resident` are not written through
   direct or aliased paths, or writes increment an epoch that invalidates the
   view.
3. No opaque call may mutate those fields unless its contract says so.
4. On an unproved effect or epoch mismatch, rebuild or run the original loop.
5. Writeable columns either write back at the view boundary or are excluded.

G5 satisfies the promising shape: relevant fields are stable throughout the
measured 4,000-frame region; visibility changes only afterward. The compiler
must prove that from the actual program, not assume it from the benchmark.

**Implementation strategy**

1. Extend the existing DataView from explicit whole-list conversion to a
   compiler-created persistent view for a repeated hot region.
2. Recognize `A[B[i]]` chains and clone an inspector plus executor.
3. Use AIF effects/alias contracts to find the maximal reuse region.
4. Add per-list/per-field mutation epochs in the runtime only where a persistent
   view is selected; do not tax every program globally.
5. Pack booleans as bytes first. Bit-packing may reduce bandwidth further but
   complicates updates and SIMD; measure it as a separate candidate.
6. Once linear, let LLVM vectorize the count/reduction. Verify the vectorization
   report and assembly rather than adding SIMD intrinsics first.

Recent data-view work implements compiler-managed AoS/SoA conversion that can
change with execution context and algorithm step, evaluated on Intel, ARM, and
GPU targets:
[Annotation-guided AoS-to-SoA conversions with data views (2025)](https://arxiv.org/abs/2502.16517).
Inspector-executor compilers target precisely the repeated indirect `A[B[i]]`
shape and preserve a generic execution path when runtime facts are unavailable:
[Compiler Optimization for Irregular Memory Access Patterns (2023)](https://arxiv.org/abs/2303.13954).
A dependency-driven inspector-executor has also shown that converting irregular
traces into regular codelets can unlock vectorization and locality:
[Vectorizing Sparse Matrix Codes with Dependency Driven Trace Analysis (2021)](https://arxiv.org/abs/2111.12243).

**Acceptance gate**

- With the G5 fields stable, the executor has no entity/mesh pointer chase in
  its inner loop.
- Mutating any guarded field before the next frame either refreshes/rebuilds the
  view or takes the original path, with identical checksums.
- View construction is included in whole-program time and amortizes under the
  declared repeat count.
- Tuned Prismio/Rust `<= 0.90x` on the target before claiming “surpasses Rust.”

### P6 — Later, not first: prefetching and learned/autotuned policies

Irregular gather prefetching and learned compiler policies are real modern
approaches, but they are downstream of the obvious representation waste.
APT-GET reports that profile-guided placement/timing improves software
prefetching for irregular accesses:
[APT-GET](https://research.google/pubs/apt-get-profile-guided-timely-software-prefetching/).
LLVM also exposes memory-profile-guided hot/cold allocation and data placement,
with LTO needed for context disambiguation:
[LLVM MemProf](https://llvm.org/docs/MemProf.html).

Do not start here. G5's working set is small and the present loop still pays
avoidable headers, bounds paths, wide scalar slots, and pointer indirections.
Prefetching inefficient accesses is weaker than eliminating them.

## Recommended execution order

### Slice 1 — make the number believable

- Add repeated-work timed samples and independent-rebuild A/A.
- Freeze a baseline artifact: source hashes, compiler hash, target, LLVM/rustc
  versions, checksums, disassembly, and balanced raw samples.

### Slice 2 — hotness/inlining

- Land standard LLVM PGO or the smallest general hot-function attribute bridge.
- Confirm render inlining and quantify the gap left after it.

### Slice 3 — boxed/scalar list loop view

- Resolve stable list headers once.
- Add per-bucket range guards and pointer induction.
- Add packed `List<Int>` storage.

Expected machine-code milestone: no generic list call in the fast loop, no
per-element header resolution, and 4-byte bucket item loads.

### Slice 4 — joint layout + packed persistent view

- Teach the layout search about gather paths and complete representations.
- Generate an effect/epoch-guarded inspector-executor DataView.
- Vectorize the packed executor.

This is the slice expected to cross from parity to a defensible lead over tuned
Rust.

## Explicitly rejected or deferred approaches

- **Force `Entity`/`Mesh` unsplit globally:** measured regression.
- **Speculatively load every list header in the C runtime:** shortened G5's loop
  but regressed other programs; the proof belongs in codegen.
- **Globally force all functions inline/internal:** code-size and cold-path risk,
  and it avoids solving hotness.
- **Trust one G5 timing run:** the benchmark has demonstrated false movements
  larger than many proposed wins.
- **Precompute the final submitted count as a G5 special case:** invalid fairness
  and not a general compiler feature.
- **Start with software prefetch:** premature while the loop has removable
  representation overhead.
- **Use MLGO before standard PGO:** learned policy is not a substitute for absent
  runtime profile facts.

## Final release gates

1. Exact checksum agreement for all five benchmark arms.
2. Independently rebuilt A/A within 2% under the improved harness.
3. Tuned Prismio/tuned Rust:
   - parity milestone: `<= 1.00x` median and confidence interval not above 1.00;
   - surpass milestone: `<= 0.90x`.
4. Natural Prismio and the other tuned programs do not regress:
   corpus median `<= 1.03x`, no individual `> 1.10x` without a documented
   workload-specific tradeoff.
5. Full functional, ownership, `--verify`, AIF convergence, target, and release
   gates pass.
6. The generated hot loop meets the structural checks for the slice being
   claimed; timings without the expected machine-code change are rejected.

## Evidence already in the repository

- `aif/evidence/xlang/prismio/g5_tuned.psm`
- `aif/evidence/xlang/rust/g5_tuned.rs`
- `aif/evidence/RESULTS-list-header-hoist.md`
- `aif/evidence/RESULTS-flat-list-loop-guard.md`
- `aif/evidence/RESULTS-flat-list-view.md`
- `aif/evidence/RESULTS-M4-dataview-c.md`
- `aif/evidence/RESULTS-inline-push-rejected.md`
- `src/ir/expr.psm:generateLoopFlatGuard`
- `runtime/llvm-api-backend.c:ir_list_flat_elem`
- `src/aif/layout.psm:aifLayoutVetoListElements`

## One-sentence handoff

Do not retune G5's source again: first make Prismio see and inline the hot call,
then replace generic list accesses with typed loop views and packed scalar
storage, and finally generate a mutation-safe packed execution view for the
repeated indirect stream—the last step is the credible route to beating Rust.
