# Prismio Memory & Allocation Deep-Dive

**Investigation date:** 2026-09-04  
**Repository revision:** `bf7ca2e59c0e41cf79ec435da9f63e8dd9a759f5`  
**Compiler binary SHA-256:** `4e2b37f44d3ad550bedd397977611cf79e395fb0bf884802840878f77e773efc`  
**Compiler/runtime:** Prismio 0.1.0, LLVM 22.1.8  
**Host:** macOS 26.6.2 (25G83), Darwin 25.6.0, arm64; Apple clang 21.0.0; Rust 1.97.1  
**Snapshot caveat:** the working tree was already dirty. No pre-existing source change was modified by this investigation. Measurements describe the compiler binary and source snapshot identified above, not a pristine release tag.

This is an architecture investigation, not an optimization patch. The only generated repository artifact is this report. Experimental binaries, raw LLVM IR, assembly, benchmark JSON, and forced-layout variants were written under `/tmp`.

## Evidence vocabulary

- **MEASURED** — observed in a benchmark, allocation ledger, manifest, IR, or final machine code during this investigation.
- **SOURCE FACT** — directly established by the implementation, but not necessarily performance-measured.
- **CONCLUSION** — the strongest explanation supported by multiple facts.
- **HYPOTHESIS** — plausible, but it still needs a controlled experiment.
- **PREDICTION** — an expected future result. Predictions are deliberately rare here.

## Executive findings

1. **The dominant measured allocation problem is not libc `malloc`; it is a representation decision.** The layout search splits `BenchMemoryParticle` into hot and cold records. That makes a type that otherwise fits in a flat, contiguous `List<T>` ineligible for inline storage, and emits two `malloc` calls per element. One million particle literals therefore make exactly 2,000,000 element allocations. **[MEASURED, CONCLUSION]**
2. Forcing the already-supported unsplit layout changes no language semantics and reduced `struct_creation` from 33.956 ms to 6.140 ms (81.9%, 5.53x) over 25 interleaved runs. It reduced `allocation_mutation` from 19.311 ms to 7.700 ms (60.1%, 2.51x). The unsplit creation result was 0.941x C++ and 1.125x Rust. **[MEASURED]**
3. The current layout cost model prices traversal, cache lines, record footprint, padding, and the cold link, but not the induced loss of flat container storage, per-element allocation/release, or cold-object construction. That missing cross-layer cost is the immediate root cause. **[SOURCE FACT, CONCLUSION]**
4. `large_buffer_copy` remains 3.048x C++ and 2.709x Rust. Final assembly contains an 8-pass scalar loop with per-element list representation/bounds guards and a `_list_set` slow fallback; it does not become a vector loop or `memcpy`. This is a loop-view/bufferization problem Prismio must expose before LLVM can solve it. **[MEASURED, CONCLUSION]**
5. Existing region and reuse work is materially effective. Nested collections are only 1.22–1.26x the references, and recursive tree rebuild is 0.631x C++ / 1.135x Rust. Final tree assembly mutates the unique source allocation in place and allocates only on the malformed/default path. **[MEASURED]**
6. The arena implementation is dynamically scoped through process-global mutable state (`rt_arena_hint`, stack, depth, pool, and counters), not thread-local state. Native tasks create OS threads. A region entered by concurrent tasks can therefore race or allocate into the wrong arena. This is a source-established correctness risk, not a measured failure. **[SOURCE FACT, CONCLUSION]**
7. Prismio lowers the post-sema AST directly to LLVM and keeps AIF results in side tables. It has no ownership-aware middle IR carrying moves, borrows, lifetime ends, regions, container layout, memory effects, or return provenance. Important semantic facts disappear before optimization, limiting scalar replacement, interprocedural escape analysis, return-slot construction, and loop transformation. **[SOURCE FACT, CONCLUSION]**
8. Replacing the general allocator is not a current priority. The repository's controlled allocator study found mimalloc at 1.021x time / 1.242x RSS and rpmalloc at 1.003x time / 1.627x RSS versus the baseline. Both were rejected. **[MEASURED in existing evidence]**
9. The maintained benchmark harness measures elapsed time, wall time, checksum, and build time. It does **not** normally measure allocation bytes, size distribution, peak live bytes, arena bytes, stack/heap split, RC traffic, cycle work, fragmentation, or hardware cache events. Those are `NOT CURRENTLY MEASURED` by the ordinary suite. **[SOURCE FACT]**

## Current baseline

### Method

The maintained dispatcher suite was run for the six implemented `memory` workloads at scale 4 with five samples per language. Each workload's checksum passed. Prismio uses its ordinary native build path: generated LLVM plus the curated runtime, then clang `-O2 -mllvm -enable-nontrivial-unswitch`. The C++ reference is built with `-O3`; Rust uses `opt-level=3`. These are end-to-end workload comparisons, not allocator-only microbenchmarks.

Raw results: `/tmp/prismio-memory-baseline-2026-09-04.json`. The committed historical result was also inspected; it has the same qualitative ordering, but timing drift is large enough that this report uses the fresh run for the current baseline.

| Workload | Prismio median | C++ median | Rust median | Prismio/C++ | Prismio/Rust | Result/checksum |
|---|---:|---:|---:|---:|---:|---:|
| `transient_allocation` | 3.670 ms | 2.826 ms | 2.619 ms | 1.298x | 1.401x | 339103 |
| `struct_creation` | 35.134 ms | 6.602 ms | 5.409 ms | 5.322x | 6.496x | 48996500 |
| `allocation_mutation` | 20.600 ms | 6.698 ms | 6.680 ms | 3.076x | 3.084x | 36000000 |
| `nested_collection` | 2.987 ms | 2.377 ms | 2.440 ms | 1.257x | 1.224x | 409805349 |
| `large_buffer_copy` | 17.792 ms | 5.838 ms | 6.568 ms | 3.048x | 2.709x | 90068056 |
| `recursive_tree_rebuild` | 0.560 ms | 0.888 ms | 0.494 ms | 0.631x | 1.135x | 4137497 |

The first `transient_allocation` Prismio sample was 8.863 ms and the last was 2.591 ms. This strong monotonic warm-up/frequency effect makes its five-run median less stable than the other rows. The layout experiment below used 25 deterministic interleaved rotations specifically to reduce ordering bias.

Build medians for the selected six-workload dispatcher were Prismio 0.547 s, C++ 2.113 s, and Rust 0.772 s. Binary build time is informative but is not a memory-runtime metric.

### Controlled representation experiment

`--force-layout=BenchMemoryParticle:5` selected the existing unsplit five-field layout. No compiler or runtime source was changed. Current, forced-unsplit, C++, and Rust binaries were run in deterministic rotating order for 25 samples each.

| Workload | Current Prismio | Forced unsplit | C++ | Rust | Unsplit/current | Measured reduction |
|---|---:|---:|---:|---:|---:|---:|
| `struct_creation` | 33.956 ms | 6.140 ms | 6.525 ms | 5.456 ms | 0.1808x | 81.9% (5.53x) |
| `allocation_mutation` | 19.311 ms | 7.700 ms | 6.324 ms | 6.416 ms | 0.3987x | 60.1% (2.51x) |

Ranges were 33.100–37.310 ms current and 5.950–6.592 ms unsplit for creation; 18.763–21.155 ms current and 7.404–8.744 ms unsplit for mutation. Raw data: `/tmp/prismio-layout-abba.json`.

This forced result is an **experimental ceiling for one representation choice**, not a prediction for a future general layout policy. It proves that the existing backend/runtime path can reach reference-class creation performance when the layout selector preserves the flat-list representation.

### Dynamic allocation ledger

The same workloads were built with `--verify`. This replaces the compiler allocation seam with a live-object ledger and instruments runtime string/list allocation. It counts heap allocation events, but arena-served objects and chunks are outside the ledger. Two small output digit strings intentionally remain live at dispatcher exit; every row reported zero ownership violations.

| Workload | Allocated | Released | Live at exit | Key interpretation |
|---|---:|---:|---:|---|
| `transient_allocation` | 9,605 | 9,603 | 2 | About 12 header/growth allocations per round plus process overhead |
| `struct_creation` | 2,000,007 | 2,000,005 | 2 | Exactly two allocations per 1,000,000 particle literals, plus seven |
| `allocation_mutation` | 800,007 | 800,005 | 2 | Exactly two allocations per 400,000 particle literals, plus seven |
| `nested_collection` | 5 | 3 | 2 | Payload is predominantly arena-served and therefore invisible here |
| `large_buffer_copy` | 5 | 3 | 2 | Both flat buffers are predominantly arena-served |
| `recursive_tree_rebuild` | 16,388 | 16,386 | 2 | Initial tree allocation; update reuse avoids rebuild allocation |
| forced-unsplit `struct_creation` | 8 | 6 | 2 | Element bodies are constructed directly in the list buffer |
| forced-unsplit `allocation_mutation` | 8 | 6 | 2 | Same; no per-particle heap allocations |

The verifier does not retain aggregate requested bytes, allocation-site identities, lifetime intervals, size histograms, or allocator time. Its counts cannot be treated as whole-process malloc counts because arena chunks and unrelated C-runtime allocations bypass it.

### Peak resident set observations

These are single `/usr/bin/time -l` process-maximum observations, not stable benchmark medians. They include code, runtime, allocator state, and process overhead.

| Workload | Current peak RSS | Forced unsplit peak RSS | Difference |
|---|---:|---:|---:|
| `struct_creation` | 57,704,448 B | 41,500,672 B | −28.1% |
| `allocation_mutation` | 24,035,328 B | 17,498,112 B | −27.2% |
| `transient_allocation` | 1,671,168 B | — | single observation |
| `nested_collection` | 14,680,064 B | — | single observation |
| `large_buffer_copy` | 17,563,648 B | — | single observation |
| `recursive_tree_rebuild` | 1,982,464 B | — | single observation |

### Metrics missing from the maintained harness

| Metric | Current status | Required measurement |
|---|---|---|
| Allocated/freed bytes and peak live bytes | `NOT CURRENTLY MEASURED` | Extend the verifier ledger with requested/usable size, live-byte high-water mark, and site ID |
| Allocation size distribution | `NOT CURRENTLY MEASURED` | Per-site logarithmic histogram, separated by heap/arena/RC/cycle/runtime handle |
| Stack versus heap object count/bytes | `NOT CURRENTLY MEASURED` | Emit site metadata and T0 frame-size records; correlate with stack high-water probes |
| Temporary and copy/move count | `NOT CURRENTLY MEASURED` | Ownership-MIR counters and opt remarks; list/string byte-copy counters |
| RC retain/release traffic | `NOT CURRENTLY MEASURED` | Counters by atomic/plain, zero/nonzero result, and call site |
| Cycle collector pause/work/retained graph | `NOT CURRENTLY MEASURED` | Candidate count, nodes/edges walked, bytes reclaimed, pause histogram |
| Fragmentation and allocator time | `NOT CURRENTLY MEASURED` | malloc-zone statistics or allocator profiler, with a portable fallback |
| Arena chunk count, slack, peak, reuse | `NOT CURRENTLY MEASURED` by suite | Promote existing arena counters and add peak/slack/pool telemetry to JSON |
| Cache misses, branch misses, memory bandwidth | `NOT CURRENTLY MEASURED` | Platform performance counters in an optional benchmark mode |
| Multithreaded allocation scaling | `NOT CURRENTLY MEASURED` | 1/2/4/N-thread task and channel workloads with per-thread telemetry |
| String capacity/reallocation/strlen scans | `NOT CURRENTLY MEASURED` | String/list-slot instrumentation and byte-volume counters |

## End-to-end memory path

```text
source expression / implicit closure, task, channel operation
    -> AST + TypeInfo (move-only classification, nominal field graph)
    -> semantic ownership checks (syntactic moves/borrows + extern contracts)
    -> AIF side-table graph (escape E, alias A, thread T, cycles C)
    -> tier + region + layout/reuse decisions
    -> direct AST-to-LLVM emission
       T0 alloca | T1 arena | T2 heap | T3 RC | T4a atomic RC | T4b cycle
    -> raw .ll
    -> curated runtime IR merge
    -> clang -O2 + nontrivial unswitch
    -> native object + separately compiled runtime/support objects
    -> libc allocator / Prismio arena / RC / cycle / OS threads and locks
```

There is no intervening Prismio memory IR. AIF deliberately does not rewrite the AST; codegen queries it per node (`src/driver/compile.psm:286-337`). That makes the implementation simple and fail-open, but forces every optimization to reconstruct context from AST shape or emit a runtime operation early and hope LLVM removes it.

## Source-level and type representation inventory

### Scalars, arrays, optionals, slices, and views

- Scalar integers, floats, and booleans remain values. Scalar list elements use typed inline storage at their native width. Existing evidence shows this was a major win, including `List<Bool>` shrinking from 64 MB to 9.2 MB in its study. **[SOURCE FACT, existing MEASURED evidence]**
- Array literals lower to entry-block `alloca`; AIF records a site but scope-drop logic knows no heap free is needed. This is fixed stack storage, not a dynamically promoted array. **[SOURCE FACT]**
- `Optional<T>` is a nullable pointer representation for reference-shaped `T`; it is not a general niche-optimized tagged value. **[SOURCE FACT]**
- `Slice<T>` is a value `(handle, offset, length)` view. It avoids a copied subarray and survives backing-list growth because it does not store an interior pointer. **[SOURCE FACT]**
- `DataView` is an explicit AoS-to-SoA conversion: a view header, column descriptors, and one allocation/copy per selected field; materialization performs the reverse full copy. It can pay for sustained columnar loops, but conversion break-even is not modeled or measured by the maintained suite. **[SOURCE FACT]**

### Structs and ABI

- A user struct's normal local/parameter storage type is a pointer. Scalar-only nested structs may be embedded in an owning struct through `fieldStorageType`, but ordinary user-struct calls are not passed by value. (`src/ir/types.psm:137-170`) **[SOURCE FACT]**
- T0 changes the backing allocation to an entry-block stack slot. It does not scalar-replace fields or change the public call ABI. The backend reuses one alloca per syntactic site across loop iterations, relying on AIF's non-escape proof. **[SOURCE FACT]**
- Hot/cold splitting makes a logical object two records connected by a pointer and therefore two allocations. The chosen `BenchMemoryParticle` layout is hot 32 B + cold 16 B rather than the 40 B unsplit record. The model assigns costs 92 versus 100 and selects the split. **[MEASURED manifest]**
- A flat `List<BenchMemoryParticle>` requires an unsplit, pointer-free element. The chosen split disables the 40-byte inline stride and forces boxed pointers. This dependency is not represented in the layout objective. **[SOURCE FACT, CONCLUSION]**

### Strings

- A Prismio `String` is a fat `{ptr,len}` value in internal IR. Runtime buffers are NUL terminated and normally exact-sized. **[SOURCE FACT]**
- The C ABI flattens a `String` to `char*`; a returned C string therefore has its length reconstructed. Strings placed in generic container pointer slots likewise lose the length and use `prismio_cstr_len`/`strlen` when read back. **[SOURCE FACT]**
- Literals are private LLVM constants and do not allocate dynamically. Concatenation, slicing to an owned string, formatting, numeric conversion, and C-return adaptation do allocate. **[SOURCE FACT]**
- There is no small-string representation, spare-capacity growth strategy, rope, or borrowed string-view type crossing the FFI/container boundary. Whether any is profitable is `NOT CURRENTLY MEASURED`.

### Lists and collections

- `RtList` is a 40-byte header with length, capacity, data pointer, element ownership mode/releaser, arena slot, and inline element width. The data block doubles in capacity. `list_new()` starts with no data allocation; the first push grows from four slots/elements. (`runtime/lang_runtime.c:1240-1516`) **[SOURCE FACT]**
- Flat scalar and flat unsplit-struct elements are contiguous bodies. Boxed/reference elements are pointer slots. A list can live in an arena; growth then leaves superseded buffers for bulk reclamation rather than freeing them. **[SOURCE FACT]**
- Construction of a flat struct literal uses destination passing through `list_push_slot`: reserve a destination body, then store fields directly. The function is not among the curated runtime operations, so final native code still calls it on the unsplit benchmark's hot construction loop. **[MEASURED assembly]**
- Reads and scalar writes have curated fast paths and loop versioning. `large_buffer_copy` still carries representation and bounds checks inside each pass and retains a call fallback, blocking vectorization/bulk copying. **[MEASURED assembly]**

### Closures, globals, tasks, and channels

- Closures are compiler-generated structs with a `call` method. Captures are by value; owned captures are moved. Closure allocation then follows ordinary struct/AIF placement. There is no borrowed-capture mode or closure-specific escape representation. **[SOURCE FACT]**
- Globals must be constant initializers. Static strings are LLVM constants; there is no runtime global constructor/destructor path. **[SOURCE FACT]**
- Each task spawn allocates a task record and creates an OS thread. The support ABI permits at most three captured arguments and a small return-kind set; string argument thunks add representation plumbing. **[SOURCE FACT]**
- Channels allocate a header and slot ring with `calloc`, use a mutex and condition variables, and carry pointer-shaped messages. `chan_share` returns the same raw handle; correct close/join/free ordering is a programmer/runtime protocol, not reference-counted handle ownership. These allocations bypass the AIF verifier seam. **[SOURCE FACT]**

## Ownership, lifetime, and AIF

### Semantic layer

Move-only types include structs, strings, lists, `DataView`, and recursively owning optionals (`src/ast/types.psm:141-151`). Direct identifier uses are checked as moves or borrows using syntactic source order. Member/index expressions are borrowed. This catches many double-use errors but is not a control-flow/liveness dataflow analysis with ownership phi nodes or nonlexical borrow ends.

Extern declarations carry explicit borrow, retain, `retain_in`, consume, out, return-alias, and return-produce contracts. This is a sound and useful boundary, but `Slice`/`DataView` are rejected at extern boundaries and ordinary Prismio callees do not expose inferred memory-effect summaries.

### AIF model and placement

AIF is field-sensitive but flow-insensitive, object-insensitive, and context-insensitive. It solves escape (`E`), alias (`A`), thread (`T`), and cyclicity (`C`) facts and classifies sites:

| Tier | Current placement/management |
|---|---|
| T0 | Entry-block stack slot; no runtime ownership bookkeeping |
| T1 | Local region/arena where a bracket is available |
| T2 | Unique heap ownership and generated deterministic release |
| T3 | Plain reference count for shared acyclic container elements |
| T4a | Atomic reference count for cross-thread values; cycle metadata if the type may cycle |
| T4b | Thread-local cycle participation with non-atomic decrement |

The benchmark dispatcher manifest reported 145 sites after nine solve rounds (six points-to rounds), converged: 9 T0, 30 T1, 106 T2, and no T3/T4 sites. By kind: 52 struct, 55 string, 38 list. Affinity was 141 isolated and four transferred. Static literals (47), extern allocations (93), static returns (4), and 22 dynamic-count sites were excluded from the peak arena estimate; therefore its reported 640 B estimate is not a process peak-memory result.

The bracketing analysis found 149/279 functions bracketable but only 14/381 calls both in-region and bracketable. It emitted 14 brackets serving 24 sites. The largest blockers were multiple calls (175) and opaque calls (123), followed by shared values (18), borrowed parameters (7), and drops (4). This quantifies why interprocedural memory effects and caller-provided regions are leverage points.

### Destruction and reclamation

- T1 arenas reclaim chunks at region exit. Default 8 KiB chunks are pooled up to eight chunks (64 KiB); oversized chunks are returned. Region growth is bump allocation aligned to 16 bytes. **[SOURCE FACT]**
- T2 owned structs get generated field-release functions. Releases are emitted in reverse field order. A tail self-field is looped to avoid linear recursive destruction; multiple recursive owned fields can still recurse. **[SOURCE FACT]**
- RC headers add 16 bytes. Counts start at zero and are incremented for the container edges AIF chooses to count. A zero-count `release` is a no-op, so correctness depends on placement and edge instrumentation agreeing. **[SOURCE FACT]**
- The cycle header stores count/color/buffer state and two function pointers. Candidate buffers and traversal arrays are process globals. Mark, scan, blacken, and collect-white are recursive, and collection allocates temporary root/child arrays. Threshold constants are explicitly not validated by current benchmarks. **[SOURCE FACT]**
- Arena state and cycle-collector global work state are not thread-local or synchronized, despite native task support. **[SOURCE FACT; HIGH correctness risk]**

### Design rationale and load-bearing assumptions

| Mechanism | Why the current design exists | Assumption it relies on | Consequence when the assumption fails |
|---|---|---|---|
| Fail-open AIF side tables | Memory inference can improve performance without changing which valid programs compile | Conservative fallback is always semantically safe | Easy deployment, but optimizations remain syntax/query-driven and facts are not transformable IR |
| Entry-block T0 slot | A fixed address is simple to lower and can be reused at a loop site | The object never escapes and iterations do not require simultaneous identities | Sound when proof holds; live range/frame can be larger than necessary |
| Dynamically scoped arena hint | Keeps every allocation hook at `fn(size)->ptr` and avoids threading handles through the frontend | Region activity is effectively single-threaded and the current dynamic arena is the desired one | Native task concurrency violates the ambient-state assumption |
| Linked hot/cold split | Prismio has no parallel cold-array handle, so a link preserves ordinary object identity/access semantics | Saved scan/cache bytes outweigh an extra allocation, link, release, and lost flat-container representation | The particle benchmarks invert the prediction by 2.51–5.53x |
| Separate inline-list entry points | Static type decides representation, avoiding a runtime branch in universally hot generic operations; an earlier branch cost 1.159x on a non-inline corpus | Codegen always selects/curates the needed typed operation | Missing `list_push_slot` curation leaves a call in a million-iteration loop |
| Lazy list data allocation | Matches empty `Vec` behavior and avoids allocate-then-replace when inline width becomes known | First growth cost is acceptable and capacity is not predictable | Repeated short lists/growth still produce allocator traffic; arena growth retains old blocks |
| Slice as handle + index | A list may grow and move its data block, so an interior pointer would become stale | Every access can cheaply re-resolve the base and backing owner outlives the slice | Safe and growth-tolerant, but loop contiguity/alias facts are not explicit to LLVM |
| Count only shared container edges | Unique ownership should pay no RC; identity sharing currently arises through known containers | Every shared edge is visible and instrumentation agrees with the zero-start count | Opaque/unmodeled sharing could leak or mismanage counts; needs verifier coverage |
| Recursive cycle trial deletion | Direct implementation of graph-color cycle reclamation with simple type callbacks | Cyclic skeleton depth and global access are bounded/single-threaded | Deep graphs risk call-stack overflow; task concurrency races global work state |
| C string ABI as `char*` | Maximizes compatibility with ordinary C APIs and NUL-terminated functions | Recovering length is infrequent/cheap and embedded NUL policy is acceptable | Repeated slot/return adaptation rescans bytes and loses ownership/capacity facts |
| Curated runtime IR | Recovers cross-boundary inlining without linking the whole runtime module that had target-attribute conflicts | A small stable hot-op whitelist captures important paths | Performance depends on manual coverage; new operations can silently remain opaque |
| Narrow reuse token | Same-tag, same-sink unique reconstruction is easy to prove without a full liveness IR | Valuable functional updates match that syntactic form | Proven wins are real, but return/branch/cross-call cases remain materialized |
| OS thread per task | Simple portable task semantics with direct join and no scheduler | Tasks are coarse enough to amortize thread/frame creation | Fine-grained task workloads may be dominated by runtime setup; currently unmeasured |

## LLVM boundary: responsibility split

| Opportunity | LLVM can do when exposed | What Prismio must establish first |
|---|---|---|
| Scalar replacement | SROA/mem2reg can remove a nonescaping aggregate whose address behavior is visible | Preserve identity/borrow facts; avoid opaque calls; emit lifetimes or scalarize in Memory MIR |
| Allocation elimination | Inline and remove an allocation whose result is local and allocator semantics are known | Choose a nonallocating representation, expose destination construction, add allocator attributes/effects |
| Vectorization | Vectorize canonical affine loops with known bounds, stride, alignment, and aliasing | Hoist list representation/bounds checks and expose typed stable buffer views |
| Bulk copy | Turn a recognized nonoverlapping copy into `memcpy`/vector moves | Prove element representation, length, overlap semantics, and absence of list growth/side effects |
| Tail calls/recursion | Eliminate suitable tail recursion and optimize loop-like control flow | Generate a tail form; Prismio already succeeds in the tree pass loop |
| Field reordering/layout | Optimize accesses within a fixed LLVM type, not change language/container representation globally | Select and encode AoS/split/SoA while pricing allocation, identity, ABI, and all consumers |
| Ownership/drop removal | DCE redundant operations after inlining if effects are visible | Preserve moves, last use, aliasing, destructor observability, and call effects explicitly |
| Runtime inlining | Inline linked, compatible runtime IR | Supply target-compatible definitions and cold-helper closure; control code size |
| Cross-call alias optimization | Use `noalias`, capture, readonly/writeonly, dereferenceability, and alignment attributes | Derive accurate parameter/return summaries, including fat-value components and ownership transfer |
| PGO machine optimization | Reorder/code-layout and tune branches from execution profiles | Keep memory representation/placement decisions semantics-safe and use a complete Prismio cost model |

## LLVM IR and final assembly audit

Raw IR was emitted to `/tmp/prismio-benchmark-current.ll` (15,070 lines) and `/tmp/prismio-benchmark-unsplit.ll`. Final binaries were disassembled to `/tmp/prismio-current-memory.asm` and `/tmp/prismio-unsplit-memory.asm`. The raw `.ll` precedes curated-runtime linking and final `-O2`; final assembly is authoritative for zero-cost claims.

### `struct_creation`

Current raw IR allocates a hot record and cold record for every particle, stores the cold pointer into the hot record, and pushes the hot pointer into the list. Final arm64 assembly retains two `bl _malloc` calls in the construction loop and later pointer-stride scans. The verifier's exactly 2,000,007 allocation count independently confirms this interpretation.

Forced-unsplit IR stamps a 40-byte inline element, calls `list_push_slot(…, 40)`, and stores five fields directly into the returned body. Final assembly has no `malloc` in the element loop and uses a 40-byte induction stride during reads. The remaining `bl _list_push_slot` is a credible smaller target, but its benefit is not measured.

### `allocation_mutation`

Current construction again has two heap allocations per particle. The mutation phase itself does not allocate; final assembly performs paired floating-point additions for position versus velocity but follows split/boxed object pointers. The forced-unsplit result removes 60.1% of total time, proving construction and locality dominate the current gap. Its remaining 20% gap to C++/Rust is not yet attributed.

### `large_buffer_copy`

List initialization largely receives scalar inline fast paths with cold growth fallbacks. The hot repeated copy is not lowered to a bulk operation: assembly contains direct fast-arm loads/stores surrounded by per-element representation and bounds tests, plus a possible `bl _list_set`. No vector instructions or `memcpy` lowering cover the copy body. LLVM cannot safely invent a stable, nonaliasing contiguous view while the list handle and fallback semantics remain visible inside the loop.

### `recursive_tree_rebuild`

The source has functional constructor syntax, but the AIF reuse token proves unique consumption and directs construction into the source node. Raw IR and final assembly recursively update the existing node; only the malformed/default arm allocates. Tail recursion in the pass loop is optimized. This is a machine-level zero-cost success.

One comparison caveat: the C++ and Rust implementations explicitly mutate `unique_ptr`/`Box`, while the Prismio source expresses reconstruction. Checksums and effective native work agree after reuse, but the source programs are not textually equivalent.

### Information LLVM receives too late or not at all

- Unique pointer parameters can receive LLVM `noalias`, but aggregates such as fat strings cannot carry equivalent component facts through the current bridge.
- Allocator calls lack systematic `allocsize`, `allockind`, `noalias` return, alignment, nonnull, or dereferenceable attributes.
- Generated code does not emit `llvm.lifetime.start/end`; T0 slots therefore expose whole-function lifetime to LLVM.
- Move kills, borrow ends, region extents, ownership-transfer returns, and nonescaping container views are not represented as first-class IR operations.
- Runtime curation recovers performance for a hand-selected set of list/RC/string operations. `list_push_slot` is outside that set, and full-runtime LTO previously failed on target-attribute mismatch. Curation is effective but structurally fragile.

## Real bottlenecks, ranked

| Rank | Bottleneck | Evidence | Classification |
|---:|---|---|---|
| 1 | Layout search destroys flat-list eligibility | 2 allocations/element; forced unsplit 5.53x and 2.51x faster | Proven root cause |
| 2 | No loop-level contiguous mutable view/bufferization | `large_buffer_copy` 2.71–3.05x references; guarded scalar assembly | Proven generated-code limitation |
| 3 | Missing memory telemetry | Most requested memory quantities unavailable; verifier counts only selected heap events | Foundational observability gap |
| 4 | Global arena/cycle state with native threads | Direct source inspection | Correctness blocker before scaling allocation work |
| 5 | No ownership-aware middle IR/effect summaries | Direct AST-to-LLVM and low bracketing coverage | Architectural limit; impact not yet quantified |
| 6 | Representation erasure for strings at FFI/container slots | Fat string becomes `char*`, length recomputed | Proven redundant work; workload impact unknown |
| 7 | Narrow reuse and return provenance | Existing reuse win; known ordinary producer-return gap | Proven opportunity, unquantified generally |
| 8 | Runtime fast-path coverage/LTO fragility | Hot `list_push_slot` call remains; hand-curated whitelist | Proven residual call; benefit unknown |
| 9 | Arena growth retains obsolete buffers until pop | Runtime algorithm | Peak-memory hypothesis, not measured |
| 10 | Cycle/RC runtime metadata and recursive work | Runtime algorithm; no maintained workloads exercise it | Risk/opportunity, not a current measured bottleneck |
| 11 | OS-thread-per-task and mutex MPMC-only channels | Support runtime | Likely costly for fine-grained concurrency; not measured |
| 12 | General allocator choice | Existing allocator A/B rejected alternatives | Explicitly deprioritized |

## Theoretical ceiling

There is no defensible single “maximum speedup.” Memory workloads exercise different mechanisms, and the suite lacks byte and hardware-counter telemetry. The useful ceilings are local:

- **Flat particle construction:** the existing backend already demonstrated 6.140 ms versus 33.956 ms by changing only the chosen representation. This is a measured attainable point, not speculation.
- **Particle mutation:** 7.700 ms is similarly attained. C++/Rust at 6.324/6.416 ms bound the remaining comparable work, but reaching either is not guaranteed.
- **Large buffer copy:** C++/Rust show that equivalent checksum work can finish in 5.838–6.568 ms versus Prismio 17.792 ms. That 2.71–3.05x gap is an opportunity bound, not a prediction; semantics and emitted loop shape must be matched first.
- **Nested arenas:** only 22–26% separates Prismio from the references. Optimization should preserve simplicity unless telemetry locates a specific remaining cost.
- **Tree rebuild:** Prismio already beats C++ and is within 13.5% of Rust. The architectural goal is to generalize its proven reuse without regressing this result.
- **Allocator replacement:** existing evidence offers no speed ceiling worth pursuing now. Representation and allocation elimination have orders-of-magnitude more leverage than swapping `malloc` implementations in the tested corpus.

From scratch, the ideal architecture would preserve source ownership and layout choices into a typed memory SSA/MIR; derive context-sensitive escape/effects; select stack, caller arena, unique heap, RC, or cycle management after representation/container costs are known; expose typed contiguous borrows to vectorizable loop IR; specialize container/runtime operations; and only then let LLVM optimize. This is not a call to replace LLVM: LLVM should remain the scalar, loop, vector, and machine optimizer after Prismio makes its semantic facts explicit.

## Target architecture

### Current architecture

Prismio has a strong experimental foundation: move-only owning values, explicit extern ownership contracts, field-sensitive AIF tiers, stack and region placement, inline scalar/flat-struct lists, deterministic drops, narrow unique-update reuse, optional RC/cycle handling, explicit DataView, workload-informed layouts, a verifier, and curated runtime IR. The weakness is composition. Layout, placement, ownership, containers, loop lowering, and ABI are separate decisions connected through queries and special cases rather than a shared costed memory representation.

### Near-term architecture

1. Make runtime arena/cycle state thread-safe and add site/byte/lifetime telemetry.
2. Add a hard container-representation cost/veto to layout selection. A split that turns an inline list into a boxed list must price allocation frequency, release frequency, link/header bytes, and loss of vectorizable stride. Gate with the measured particle regression.
3. Add scoped typed read/write list views in codegen so loops pay representation/bounds validation once, then expose `(base, len, stride, ownership)` to LLVM. Lower provably equivalent copies to `memcpy` or a canonical vectorizable loop.
4. Add function memory-effect summaries: parameter escape/consume/borrow, return alias/fresh/transfer, region requirements, and container mutation. Use these to expand arena brackets and close return-provenance leaks.
5. Complete runtime specialization/curation for typed list construction and string/container access while normalizing runtime IR attributes enough to make the process less whitelist-dependent.
6. Generalize reuse only after a liveness proof makes destination/source identity and field destruction explicit.

These are incremental: they fit the existing language and AIF model, though effect summaries and typed views should be designed as the first slice of a future MIR rather than more AST-only flags.

### Long-term architecture

Introduce a typed ownership-and-memory MIR between sema and LLVM with:

- SSA values plus explicit `move`, `borrow`, `end_borrow`, `drop`, `destroy`, `reuse`, `region.enter/exit`, and allocation-site identities;
- ownership phi nodes and path-sensitive definite initialization/destruction;
- interprocedural summaries, bounded context sensitivity, and allocation-object sensitivity;
- representation types separating logical values from ABI/container layout, including flat AoS, split objects, SoA/AoSoA, borrowed views, inline/niche variants, and boxed identities;
- a whole-program profitability model combining dynamic frequency, allocation/release cost, bytes copied, cache-line traffic, vectorization eligibility, conversion cost, code size, and concurrency;
- explicit caller-provided region handles and thread-local region allocators, not ambient process globals;
- typed monomorphized containers and closure/task frames where profitable;
- return-slot/destination-passing construction and scalar replacement before LLVM;
- LLVM lowering with accurate allocation, alias, lifetime, alignment, dereferenceability, readonly/writeonly, and capture attributes;
- optional PGO that guides decisions but never changes observable semantics, with reproducible static fallback.

This is the path to predictability and best-in-class behavior. A custom general allocator, pointer compression, pervasive object pools, and automatic copy-on-write should remain workload-driven experiments rather than architectural defaults.

## Memory Optimization Tracker

The IDs below are stable worker handles. “Expected benchmark” describes an implemented candidate only when this investigation measured that exact mechanism. Otherwise it uses the required unknown marker.

### MEM-001 — Allocation and lifetime telemetry

- **Optimization:** Add first-class memory telemetry to the benchmark/verifier pipeline.
- **Area:** allocator, runtime, compiler, benchmarks.
- **Current implementation:** `--verify` records selected heap allocations/releases and live objects. Arena stats exist separately. Neither path emits per-site bytes, size distributions, peak-live intervals, stack bytes, copy volume, RC/cycle traffic, or unified JSON.
- **Evidence:** `src/driver/compile.psm:362-375`; verifier and arena code in `runtime/lang_runtime.c:510-789`; missing-metric table above.
- **Problem:** Most proposed changes cannot be accepted or rejected on memory behavior, and arena-heavy programs misleadingly show almost no ledger allocations.
- **Proposed improvement:** Assign stable allocation-site IDs and kinds in IR; route heap/arena/RC/cycle/runtime-handle events through low-overhead counters; record requested bytes, high-water live bytes, lifetime histogram, and optional sampled event traces; integrate results into `benchmarks/run.py` JSON.
- **Difficulty:** MEDIUM.
- **Risk:** LOW.
- **Dependencies:** None; design the event schema so MEM-004 can consume MIR site IDs later.
- **Current benchmark:** Allocation counts are available only via ad hoc verify runs; all byte and lifetime metrics are `NOT CURRENTLY MEASURED`.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`; the deliverable is observability, with disabled-mode overhead required to be statistically neutral.
- **Expected improvement:** No runtime speedup claimed; enables defensible decisions and regression gates.
- **Confidence:** HIGH.
- **Priority:** P0 — foundational.

### MEM-002 — Thread-local region and cycle state

- **Optimization:** Make allocator/collector ambient state safe under native tasks.
- **Area:** allocator, runtime, ownership, concurrency.
- **Current implementation:** Arena hint, stack, depth, pool, and counters are process-global mutable statics. Cycle candidates, walk buffers, and counters are also global and unsynchronized. Tasks use `pthread_create`/`CreateThread`.
- **Evidence:** `runtime/lang_runtime.c:52-68`, `:498-637`, `:1021-1154`; `runtime/program_support.c:468-578`.
- **Problem:** Concurrent region entry/allocation can race and select the wrong region. Concurrent cycle activity can corrupt collector work state. This blocks trusting memory tiers in threaded code.
- **Proposed improvement:** Move arena hint/stack/pool to TLS; aggregate counters safely; choose either per-thread cycle buffers with explicit transferred-object ownership or synchronized global collection; add task-exit cleanup and cross-thread region escape assertions.
- **Difficulty:** HIGH.
- **Risk:** HIGH.
- **Dependencies:** MEM-001 for stress-test evidence; semantic decision for T4b objects transferred across threads.
- **Current benchmark:** `NOT CURRENTLY MEASURED`; no maintained multithreaded region/cycle benchmark exists.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`; correctness under race/stress is the first acceptance criterion.
- **Expected improvement:** No performance percentage claimed. TLS should remove sharing, but OS TLS access and aggregation cost must be measured.
- **Confidence:** HIGH for the correctness problem; LOW for performance effect.
- **Priority:** P0 — foundational.

### MEM-003 — Container-aware layout selection

- **Optimization:** Price the representation consequences of hot/cold splitting.
- **Area:** object layout, arrays/collections, allocator, cache/locality.
- **Current implementation:** The cost model ranks unsplit and linked hot/cold AoS candidates using access/traversal evidence, record/cache footprint, padding, and link cost. It does not price that a split element cannot use flat list storage.
- **Evidence:** `runtime/aif_support.c:798-1179`, `:1318-1490`; manifest choice `BenchMemoryParticle` split 3/5 at cost 92 versus unsplit 100; verifier and assembly results above.
- **Problem:** A nominal 8% model win creates two heap objects per element, destroys contiguous storage and destination construction, and produces the suite's largest regressions.
- **Proposed improvement:** Evaluate layout in use context. Add dynamic element-construction count, container flatness, allocation/release cost, actual linked bytes, pointer chasing, and vectorization eligibility. At minimum, veto automatic split for types stored in hot flat lists until the full model proves a win. Permit profile-guided override only after candidate A/B measurement.
- **Difficulty:** MEDIUM.
- **Risk:** MEDIUM.
- **Dependencies:** MEM-001 for generalization; the immediate particle regression guard can be implemented independently.
- **Current benchmark:** Current 25-run medians: `struct_creation` 33.956 ms; `allocation_mutation` 19.311 ms.
- **Expected benchmark:** 5.950–6.592 ms creation and 7.404–8.744 ms mutation **if** the policy selects the exact measured unsplit candidate and emits identical IR; other workloads require measurement.
- **Expected improvement:** Measured candidate reduction: 81.9% creation and 60.1% mutation; 5.53x and 2.51x respectively.
- **Confidence:** HIGH for these two workloads; MEDIUM for a general cost model.
- **Priority:** P0 — foundational.

### MEM-004 — Ownership-aware Memory MIR

- **Optimization:** Preserve memory semantics in a typed middle representation.
- **Area:** compiler, IR, ownership, stack/heap, LLVM.
- **Current implementation:** Sema annotates an AST; AIF stores facts in side tables; the AST is lowered directly to LLVM. Moves, borrow ends, region boundaries, reuse, and representation decisions are not first-class SSA operations.
- **Evidence:** `src/driver/compile.psm:277-390`; generator under `src/ir`; absence of a separate ownership/memory IR.
- **Problem:** Analyses and transforms are coupled to syntax, path-sensitive destruction is hard, and LLVM receives allocations/calls after source ownership facts have been erased.
- **Proposed improvement:** Introduce a staged MIR with allocation-site identities, ownership-qualified values, memory effects, explicit moves/borrows/drops/reuse/regions, representation types, and a verified lowering to LLVM. Begin with one function at a time and differential IR/execution tests.
- **Difficulty:** ARCHITECTURAL.
- **Risk:** HIGH.
- **Dependencies:** Lock a language-level ownership/destruction contract; reuse MEM-001 site schema and current AIF as an analysis producer.
- **Current benchmark:** `NOT CURRENTLY MEASURED` as an isolated mechanism.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`; early milestones should be performance-neutral and unlock later items.
- **Expected improvement:** None claimed directly; enables MEM-005, MEM-007, MEM-008, and MEM-009 without accumulating AST special cases.
- **Confidence:** HIGH as an architectural enabler; LOW for standalone speedup.
- **Priority:** P0 — foundational.

### MEM-005 — Interprocedural ownership and region effects

- **Optimization:** Infer precise escape, return provenance, and callable memory effects.
- **Area:** ownership, escape analysis, regions, compiler.
- **Current implementation:** AIF is field-sensitive but flow-, context-, and object-insensitive. Known calls connect formal/actual graph nodes; externs use declared contracts. Ordinary functions lack reusable borrow/consume/escape/return-alias/fresh summaries.
- **Evidence:** `src/aif/model.psm`; AIF walker/support; manifest found only 14/381 call sites both in-region and bracketable, with 123 opaque-call and 175 multicall blockers.
- **Problem:** Callees force conservative escape/arena decisions, delegating producer returns can lose provenance, and local uniqueness is merged across calls/objects.
- **Proposed improvement:** Compute SCC-safe function summaries for parameter capture/consume, return alias/fresh/transfer, field effects, drop behavior, and region requirements. Add bounded call-site specialization for hot functions and allocation-object sensitivity for containers.
- **Difficulty:** HIGH.
- **Risk:** HIGH.
- **Dependencies:** Can start on current AIF; durable path depends on MEM-004. MEM-001 must distinguish heap elimination from work movement.
- **Current benchmark:** 14 bracketed calls and 24 arena-served sites in the benchmark manifest; runtime effects are `NOT CURRENTLY MEASURED` separately.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`; determined by newly bracketable dynamic allocation counts, not static site counts.
- **Expected improvement:** Unknown. Existing nonlexical-arena evidence (10,285,886 to 82,052 heap allocations on g2) proves the mechanism can be large when dynamic coverage is high, but does not predict this change.
- **Confidence:** HIGH for improved precision; MEDIUM for broad runtime impact.
- **Priority:** P0 — foundational.

### MEM-006 — Typed contiguous list loop views

- **Optimization:** Validate a list once and lower hot loops over a stable contiguous view.
- **Area:** arrays/collections, IR, LLVM, cache/locality.
- **Current implementation:** Curated list operations inline fast paths, but repeated copy/write loops still carry representation, bounds, and slow-fallback logic per element/pass.
- **Evidence:** `large_buffer_copy` current 17.792 ms versus C++ 5.838 ms/Rust 6.568 ms; final assembly retains guarded scalar loads/stores and `_list_set`, with no vector body or `memcpy`.
- **Problem:** The loop shape obscures alias, bounds, stride, and contiguity facts, preventing canonical loop optimization and vectorization.
- **Proposed improvement:** Add scoped immutable/mutable buffer views carrying base, length, element width/alignment, and no-growth/noalias guarantees. Hoist validation, version when necessary, canonicalize copies to `llvm.memcpy` or vectorizable loops, and forbid structural list mutation while a mutable view is live.
- **Difficulty:** HIGH.
- **Risk:** HIGH.
- **Dependencies:** A narrow AST/codegen proof can prototype it; general safety and composition depend on MEM-004. Benchmark telemetry from MEM-001 is recommended.
- **Current benchmark:** 17.792 ms; 3.048x C++ and 2.709x Rust.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`; 5.838–6.568 ms is a reference opportunity bound, not a prediction.
- **Expected improvement:** Unknown; maximum comparable gap is 63–67%, but parity is not assumed.
- **Confidence:** HIGH that current loop shape is limiting; MEDIUM that one view abstraction closes most of the gap.
- **Priority:** P1 — high impact.

### MEM-007 — Generalized destination passing and unique reuse

- **Optimization:** Extend zero-allocation reconstruction beyond the narrow same-tag pattern.
- **Area:** ownership, temporaries, stack/heap, compiler.
- **Current implementation:** A reuse token redirects proven unique same-tag constructor updates into the consumed source. Flat list literals can construct into `list_push_slot`. General call returns, conditional construction, cross-block updates, and different-tag replacements still materialize conservatively.
- **Evidence:** `aif/evidence/RESULTS-M2-reuse-token.md`; `recursive_tree_rebuild` final assembly; current list destination path in `runtime/lang_runtime.c:1492-1516` and generator call sites.
- **Problem:** Semantically move-only reconstruction may still allocate/copy when the destination and last use are not visible in one AST pattern.
- **Proposed improvement:** Represent destination capabilities and last-use in MIR; support return-slot construction, branch-merged destinations, field-wise overwrite with precise old-field destruction, and safe reuse across inlined/summarized calls.
- **Difficulty:** HIGH.
- **Risk:** HIGH.
- **Dependencies:** MEM-004 and MEM-005 for the general form; preserve current token as the oracle.
- **Current benchmark:** Tree rebuild 0.560 ms, 16,388 initial allocations, and no normal rebuild allocations. Existing g8 evidence measured 189.92 to 51.94 µs and 12,539 to 2,304 window allocations for the narrow mechanism.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`; new producer/return benchmarks must establish reachable cases.
- **Expected improvement:** Unknown outside the existing measured patterns.
- **Confidence:** HIGH for more elimination opportunities; MEDIUM for their frequency.
- **Priority:** P1 — high impact.

### MEM-008 — Scalar replacement and precise stack lifetimes

- **Optimization:** Split eligible T0 objects into SSA scalars and reuse stack slots by live range.
- **Area:** stack/heap, IR, LLVM, object layout.
- **Current implementation:** T0 allocates one entry-block stack record per syntactic site and reuses it across loop iterations. The object remains addressable; there are no lifetime intrinsics.
- **Evidence:** `src/ir/expr.psm` allocation lowering; `runtime/llvm-api-backend.c:1154-1197`; generated IR contains no `llvm.lifetime.start/end` for these objects.
- **Problem:** Address identity and whole-function lifetime can prevent SROA/register promotion, inflate frames, and hide nonoverlapping storage.
- **Proposed improvement:** In Memory MIR, distinguish identity-observed from field-only objects, run scalar replacement before LLVM, sink materialization to actual address-taking boundaries, and emit lifetime start/end plus alignment/dereferenceability metadata.
- **Difficulty:** HIGH.
- **Risk:** MEDIUM.
- **Dependencies:** MEM-004; MEM-005 for call capture; MEM-001 for frame and spill measurements.
- **Current benchmark:** `NOT CURRENTLY MEASURED`; only nine static T0 sites appear in the dispatcher manifest.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`; depends on dynamic T0 frequency and register pressure.
- **Expected improvement:** Unknown.
- **Confidence:** HIGH for better IR; LOW for suite-wide effect.
- **Priority:** P1 — high impact.

### MEM-009 — Return-slot construction and ABI specialization

- **Optimization:** Elide temporary struct/string return objects across Prismio calls.
- **Area:** ABI, temporaries, compiler, IR.
- **Current implementation:** User structs are pointer-shaped locals/parameters. Calls do not have a general caller-provided result destination or an inferred ownership-return ABI. Fat strings are values internally but flattened at extern boundaries.
- **Evidence:** `src/ir/types.psm:137-202`; call lowering; known producer-return provenance issue in AIF evidence.
- **Problem:** Fresh results may be allocated in the callee and transferred/copy-adapted rather than built at their final destination; ABI boundaries lose ownership and sometimes length facts.
- **Proposed improvement:** Classify return conventions per function/representation: register scalar/fat value, caller `sret` destination, borrowed alias, unique owned pointer, or region result. Specialize internal ABI while keeping stable extern adapters.
- **Difficulty:** ARCHITECTURAL.
- **Risk:** HIGH.
- **Dependencies:** MEM-004 and MEM-005; ABI compatibility policy.
- **Current benchmark:** `NOT CURRENTLY MEASURED`; no maintained argument/return allocation benchmark isolates the cost.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown; measure allocations and bytes per call before prioritizing concrete ABI cases.
- **Confidence:** MEDIUM.
- **Priority:** P1 — high impact.

### MEM-010 — Length-preserving string slots and FFI views

- **Optimization:** Preserve string length and ownership across containers and C adapters.
- **Area:** strings, ABI, arrays/collections, FFI.
- **Current implementation:** Internal strings are `{ptr,len}`; generic pointer slots and C ABI expose `char*`, and reads/returns reconstruct length with `strlen`. Owned runtime strings are exact-size NUL buffers.
- **Evidence:** `src/ir/types.psm:9-151`, `:332-341`; string helpers in `runtime/lang_runtime.c:178-441`.
- **Problem:** Repeated container/FFI reads can rescan strings; ownership/capacity are implicit; temporary adapters are difficult to optimize.
- **Proposed improvement:** Add an ABI-level borrowed `StringView {ptr,len}` and typed inline string slots where layout permits. Preserve `char*` adapters for C compatibility. Consider owned `{ptr,len,cap}` only if append benchmarks prove growth demand; do not impose capacity globally without evidence.
- **Difficulty:** HIGH.
- **Risk:** HIGH.
- **Dependencies:** MEM-001 telemetry; MEM-004 representation types for the general solution; FFI compatibility tests.
- **Current benchmark:** `NOT CURRENTLY MEASURED`; `string_search` exists but does not isolate slot rescans or FFI adaptation.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown; proportional to repeated scanned bytes, which must be instrumented.
- **Confidence:** HIGH that scans exist; LOW for application-level impact.
- **Priority:** P1 — high impact.

### MEM-011 — Complete typed runtime specialization and robust LTO

- **Optimization:** Remove residual hot runtime calls without a fragile hand-curated whitelist.
- **Area:** runtime, LLVM, arrays/collections, compiler.
- **Current implementation:** Selected runtime operations are compiled to LLVM, extracted, linked into program IR, and optimized at `-O2`; the rest remains in separately compiled objects. `list_push_slot` is not curated. A previous whole-runtime path failed on target-attribute conflicts.
- **Evidence:** `runtime/build_driver.c:1021-1270`; forced-unsplit final assembly retains `bl _list_push_slot`; existing curated list-get evidence.
- **Problem:** A hot typed operation can remain opaque based on whitelist/linkage accidents, while expanding the whitelist increases maintenance and code-size risk.
- **Proposed improvement:** Normalize target attributes and data layouts, place compiler-facing typed intrinsics in a small stable runtime IR module, expose cold helpers externally, and add size-aware inlining tests. Include `list_push_slot` only after an isolated A/B.
- **Difficulty:** MEDIUM.
- **Risk:** MEDIUM.
- **Dependencies:** MEM-001 for call/size telemetry; complements MEM-006 and MEM-015.
- **Current benchmark:** Forced-unsplit creation 6.140 ms with one `list_push_slot` call per element; isolated call cost is `NOT CURRENTLY MEASURED`.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown; the current unsplit result already meets C++ creation, so code size and regressions matter more than an assumed win.
- **Confidence:** HIGH that the call remains; LOW that removing it materially improves wall time.
- **Priority:** P1 — high impact.

### MEM-012 — Explicit/caller-provided regions

- **Optimization:** Replace ambient-only arenas with explicit region capabilities and widen safe arena coverage.
- **Area:** allocator, regions, ownership, ABI.
- **Current implementation:** Lexical brackets push a dynamically scoped arena; only lexically contained/proven sites route to the current slot. A callee cannot receive a distinct arena handle. Fourteen calls were bracketed in the dispatcher manifest.
- **Evidence:** `runtime/lang_runtime.c:483-637`; AIF bracketability logic in `runtime/aif_support.c:3539-4042`; manifest blocker counts.
- **Problem:** Ambient state complicates threads and constrains interprocedural placement; multiple/opaque calls inhibit brackets even when a caller-owned result lifetime is clear.
- **Proposed improvement:** Thread a typed region capability through internal ABIs, support caller-region return construction, and make the capability non-escaping/non-sendable unless explicitly transferred. Retain lexical sugar and a stack-like fast path.
- **Difficulty:** ARCHITECTURAL.
- **Risk:** HIGH.
- **Dependencies:** MEM-002, MEM-004, and MEM-005.
- **Current benchmark:** `nested_collection` 2.987 ms and 24 arena-served static sites in the dispatcher; dynamic arena bytes are `NOT CURRENTLY MEASURED`.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown; must be correlated with dynamic heap allocations newly moved into caller regions.
- **Confidence:** HIGH for composability/correctness; MEDIUM for runtime benefit.
- **Priority:** P1 — high impact.

### MEM-013 — Arena peak control and capacity planning

- **Optimization:** Reduce arena slack and growth-copy retention.
- **Area:** allocator, arrays/collections, peak memory.
- **Current implementation:** Regions allocate linked chunks with an 8 KiB minimum and keep up to eight default chunks pooled. Arena-backed list growth bump-allocates a new doubled buffer and leaves every previous buffer until region pop.
- **Evidence:** `runtime/lang_runtime.c:498-637`, `:1463-1473`; peak RSS observations above.
- **Problem:** Repeated geometric growth can make transient region peak approach the sum of all capacities rather than the final capacity. Small regions can retain pooled pages after use.
- **Proposed improvement:** First use exact/estimated list capacity from loop/range facts; add region checkpoints for compiler-proven last-use subscopes; record slack; consider large-buffer dedicated chunks that can be reclaimed early without invalidating other arena pointers.
- **Difficulty:** MEDIUM.
- **Risk:** MEDIUM.
- **Dependencies:** MEM-001; MEM-005 for capacity/last-use facts. No allocator replacement required.
- **Current benchmark:** Peak/slack attributable to arena growth is `NOT CURRENTLY MEASURED`.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown; derive from measured obsolete-buffer bytes per region.
- **Confidence:** HIGH that obsolete buffers are retained; LOW that current workloads suffer materially.
- **Priority:** P2 — worthwhile.

### MEM-014 — Profitable AoS/SoA/AoSoA planning

- **Optimization:** Unify object/container layout selection and eliminate unnecessary DataView conversion.
- **Area:** object layout, cache/locality, arrays/collections, compiler.
- **Current implementation:** Automatic layout emits AoS or linked hot/cold records. `DataView` is explicit and copies selected fields into separate columns, then may copy back.
- **Evidence:** `runtime/aif_support.c:529-1490`; `runtime/lang_runtime.c:1881-1991`; layout evidence under `aif/evidence`.
- **Problem:** The compiler can select a harmful object split yet cannot directly materialize a profitable SoA/AoSoA container. Explicit conversion pays allocation and full-copy costs even when the data could be born columnar.
- **Proposed improvement:** Make layout a container-level representation decision with AoS, flat reordered AoS, AoSoA, and SoA candidates. Price construction, conversion, mutation/materialization, vector width, and all consumers. Construct directly in the chosen layout where observable identity permits.
- **Difficulty:** ARCHITECTURAL.
- **Risk:** HIGH.
- **Dependencies:** MEM-003, MEM-004, MEM-006, and MEM-001; PGO in MEM-019 may guide but must not be required.
- **Current benchmark:** DataView conversion/break-even is `NOT CURRENTLY MEASURED`; the harmful linked split is measured under MEM-003.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown. Existing DataView evidence may motivate candidates but cannot predict direct-layout results.
- **Confidence:** MEDIUM.
- **Priority:** P2 — worthwhile after flat-layout correctness.

### MEM-015 — RC and cycle-management hardening

- **Optimization:** Make shared/cyclic ownership measurable, iterative, and concurrency-safe.
- **Area:** ownership, runtime, metadata, concurrency.
- **Current implementation:** T3/T4 container edges select plain/atomic RC with a 16-byte header. Possibly cyclic types add cycle headers, global candidate/walk buffers, recursive trial-deletion traversal, and temporary allocations. Dispatcher uses no T3/T4 sites.
- **Evidence:** `runtime/lang_runtime.c:790-1160`; AIF element disposition in `runtime/aif_support.c:5680-5838`; dispatcher manifest.
- **Problem:** Recursive traversal can overflow on deep cyclic graphs; global state races; metadata is substantial; zero-start counts make correctness depend on complete edge instrumentation. No benchmark validates pause or throughput.
- **Proposed improvement:** First add edge/collector verification and workloads. Then use iterative worklists, per-thread deferred decrement/candidate buffers where sound, compact type metadata, bounded pause budgets, and explicit cross-thread handoff. Preserve deterministic destruction for unique acyclic values.
- **Difficulty:** HIGH.
- **Risk:** HIGH.
- **Dependencies:** MEM-001 and MEM-002; MEM-004/005 for stronger edge ownership.
- **Current benchmark:** `NOT CURRENTLY MEASURED`; zero relevant sites in the current memory dispatcher.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown; correctness and bounded stack/pause behavior precede speed claims.
- **Confidence:** HIGH for the risks; LOW for workload importance.
- **Priority:** P2 — worthwhile.

### MEM-016 — Specialized containers, closures, tasks, and channels

- **Optimization:** Monomorphize hot representations and remove generic handle/frame overhead.
- **Area:** compiler, runtime, arrays/collections, closures, concurrency.
- **Current implementation:** Lists share a generic header and ownership-mode dispatch; closures are generated structs; tasks use a fixed three-argument generic frame and one OS thread per spawn; channels are mutex/condition MPMC pointer rings.
- **Evidence:** `runtime/lang_runtime.c:1240-1800`; closure rewriting in `src/sema/checker.psm`; `runtime/program_support.c:430-701`.
- **Problem:** Static element/type/ownership facts become runtime fields/branches. Fine-grained tasks pay thread creation; SPSC/local channels pay MPMC synchronization; borrowed captures cannot avoid ownership transfer.
- **Proposed improvement:** Monomorphize hot list operations and releasers; generate typed closure/task frames; add borrow-capture analysis; pool worker threads; select SPSC/MPSC/MPMC channel implementations from proven topology while retaining a generic fallback.
- **Difficulty:** ARCHITECTURAL.
- **Risk:** HIGH.
- **Dependencies:** MEM-002, MEM-004, MEM-005, and MEM-001; separate container and concurrency milestones.
- **Current benchmark:** Container specialization and task/channel throughput are `NOT CURRENTLY MEASURED` by the memory suite.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown; thread creation versus work duration must be measured before designing a scheduler.
- **Confidence:** MEDIUM.
- **Priority:** P2 — worthwhile.

### MEM-017 — Linear-time ownership/drop lowering

- **Optimization:** Replace repeated whole-function ownership scans with dataflow facts.
- **Area:** compiler, ownership, compile time.
- **Current implementation:** Scope-drop and alias/last-use decisions include syntax-tree/function scans and special guards. This is separate from native runtime performance.
- **Evidence:** ownership logic in `src/sema/ownership.psm`; free-at-scope and containment scans in `runtime/aif_support.c:5171-5655`; direct AST codegen.
- **Problem:** Large functions can repeatedly rediscover the same alias/ownership relationships, risking superlinear compile time and making path-sensitive drops harder.
- **Proposed improvement:** Build ownership def-use chains and per-block liveness once, attach destruction sets to CFG edges, and consume them in AIF/codegen. Add compile-time complexity fixtures with generated large functions.
- **Difficulty:** HIGH.
- **Risk:** MEDIUM.
- **Dependencies:** MEM-004 is the durable solution; a cached-analysis precursor can be built earlier.
- **Current benchmark:** `NOT CURRENTLY MEASURED`; the suite reports only total dispatcher build time (Prismio 0.547 s), not pass-level scaling.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown; target asymptotic behavior first, then wall time.
- **Confidence:** MEDIUM until pass-level profiles confirm the hot scans.
- **Priority:** P2 — worthwhile.

### MEM-018 — Compact value representations

- **Optimization:** Add evidence-driven niches, bit packing, and small inline values.
- **Area:** object layout, strings, arrays/collections, ABI.
- **Current implementation:** Optional reference values use null; booleans in flat lists use one byte; owned strings are external buffers; enums/optionals do not have a general niche-layout engine.
- **Evidence:** type mapping in `src/ast/types.psm` and `src/ir/types.psm`; scalar-list evidence; string runtime.
- **Problem:** Dense boolean/enum/short-string workloads may spend excess bytes and bandwidth, but more complex encodings add branches, inhibit FFI, and can worsen mutation.
- **Proposed improvement:** Implement a representation calculator that discovers valid null/tag niches; separately prototype bit-packed boolean collections and a small-string form behind typed APIs. Never change generic representation without size, speed, and code-size A/B results.
- **Difficulty:** HIGH.
- **Risk:** HIGH.
- **Dependencies:** MEM-001 and preferably MEM-004; ABI versioning policy.
- **Current benchmark:** `NOT CURRENTLY MEASURED`; no maintained density/short-string benchmark exists.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown. Byte reduction can be calculated per representation, but application speed cannot.
- **Confidence:** MEDIUM for space opportunities; LOW for speed.
- **Priority:** P3 — experimental.

### MEM-019 — Profile-guided memory decisions

- **Optimization:** Use workload profiles for placement/layout frequencies with guarded reproducibility.
- **Area:** PGO, compiler, object layout, regions.
- **Current implementation:** A declared workload is built/run before the real AIF pass, and its profile informs layout selection. Failure falls back to a static profile. Current frequency data still omits allocation/release bytes and cross-representation consequences.
- **Evidence:** `src/driver/compile.psm:178-205`, `:308-337`; workload/layout support.
- **Problem:** Profile guidance can amplify an incomplete cost model—as the particle split demonstrates—and build-time workload execution is expensive and potentially unrepresentative.
- **Proposed improvement:** Version profile schemas, include site/edge/layout frequencies from MEM-001, validate top candidate layouts by budgeted A/B when requested, cap code-size changes, and preserve deterministic static fallback. Separate offline production PGO from ordinary builds.
- **Difficulty:** HIGH.
- **Risk:** HIGH.
- **Dependencies:** MEM-001 and MEM-003; representation framework from MEM-004/014 for broader use.
- **Current benchmark:** The layout profile selected a modeled 0.92x particle split that measured 5.53x slower than unsplit in creation.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT` for the improved PGO system.
- **Expected improvement:** Unknown; primary acceptance is “never repeat the measured representation inversion.”
- **Confidence:** HIGH that richer costs are required; MEDIUM that automated candidate measurement is worth build cost.
- **Priority:** P2 — worthwhile.

### MEM-020 — General allocator, slab, and pool policy

- **Optimization:** Revisit allocator choice only after allocation elimination and telemetry.
- **Area:** allocator, runtime, fragmentation.
- **Current implementation:** General unique allocations use libc `malloc/free`; regions use bump chunks; default chunks are pooled. Existing trials evaluated mimalloc and rpmalloc and rejected both.
- **Evidence:** `aif/evidence/RESULTS-M5-allocator.md`; `runtime/lang_runtime.c:57-68`, `:483-637`.
- **Problem:** A custom allocator can add portability and RSS costs while treating the symptom—too many/poorly represented allocations—rather than the cause. Size-class/slab wins are workload-dependent.
- **Proposed improvement:** Keep libc as default. After MEM-001, inspect dominant surviving sizes/lifetimes; only then A/B per-thread slabs for homogeneous T2/RC headers or large-object paths. Require release, fragmentation, RSS, and multithreaded evidence.
- **Difficulty:** HIGH.
- **Risk:** HIGH.
- **Dependencies:** MEM-001, MEM-002, and high-impact elimination items first.
- **Current benchmark:** mimalloc 1.021x median time and 1.242x RSS; rpmalloc 1.003x time and 1.627x RSS versus baseline in the repository study.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT` for any future workload-specific slab/pool.
- **Expected improvement:** None demonstrated; current general replacements regress or are neutral.
- **Confidence:** HIGH that this is not a near-term priority.
- **Priority:** P3 — experimental.

### MEM-021 — Immutable sharing and copy-on-write

- **Optimization:** Share large immutable buffers only where mutation/lifetime profiles justify it.
- **Area:** ownership, arrays/collections, strings, copying.
- **Current implementation:** Owning lists/strings are move-only; slices provide non-owning views; copy/update behavior is explicit or optimized through uniqueness/reuse. There is no generic COW header.
- **Evidence:** move-only classification in `src/ast/types.psm:141-151`; slice/list/string representations; reuse evidence.
- **Problem:** Some large immutable copies may be avoidable, but unconditional COW adds reference counts, atomicity questions, aliasing, and a uniqueness branch to every mutation.
- **Proposed improvement:** First measure copy volume and shared-read lifetimes. Prefer borrowed slices and moves. Prototype COW only for a typed immutable buffer/string abstraction with cheap unique-mutation recovery, not as the default `List<T>` semantic.
- **Difficulty:** ARCHITECTURAL.
- **Risk:** HIGH.
- **Dependencies:** MEM-001, MEM-004, MEM-005, and clear language semantics.
- **Current benchmark:** `NOT CURRENTLY MEASURED`; `large_buffer_copy` intentionally copies and is not evidence that semantic sharing is allowed.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown.
- **Confidence:** LOW that generic COW is beneficial; MEDIUM for a dedicated immutable type.
- **Priority:** P3 — experimental.

### MEM-022 — Pointer compression and software prefetch

- **Optimization:** Explore constrained-heap indices or prefetch only for proven graph bottlenecks.
- **Area:** cache/locality, object layout, runtime.
- **Current implementation:** Objects and list slots use native pointers; no compressed heap or explicit prefetch is emitted.
- **Evidence:** IR type mapping and runtime layouts; tree workload is already competitive.
- **Problem:** Pointer compression restricts addressability/FFI and adds decode cost; prefetch can waste bandwidth. Neither addresses the measured flat-list/layout failure.
- **Proposed improvement:** Do nothing by default. If telemetry finds memory-bound, pointer-dense arenas with bounded heaps, prototype 32-bit arena-relative offsets. If hardware counters identify latency-bound graph walks, test profile-guided prefetch distance.
- **Difficulty:** ARCHITECTURAL.
- **Risk:** HIGH.
- **Dependencies:** MEM-001 and a demonstrated qualifying workload; explicit region representations from MEM-004/012 for compression.
- **Current benchmark:** `NOT CURRENTLY MEASURED`; tree rebuild offers no current justification.
- **Expected benchmark:** `EXPECTED BENCHMARK: UNKNOWN — REQUIRES IMPLEMENTATION/MEASUREMENT`.
- **Expected improvement:** Unknown.
- **Confidence:** LOW.
- **Priority:** P3 — experimental.

## Optimization dependency hierarchy

The correct order is not simply “better escape analysis, then stack allocation.” Prismio already has both. The immediate problem is that independently correct subsystems compose into a bad representation.

```text
                     ┌─────────────────────────────┐
                     │ MEM-001 unified telemetry   │
                     └──────────────┬──────────────┘
                                    │ evidence gates almost everything
              ┌─────────────────────┼────────────────────────┐
              ▼                     ▼                        ▼
   MEM-002 thread safety   MEM-003 container-aware   MEM-017 pass scaling
      │ correctness first        layout policy
      │                            │ immediate measured win
      ▼                            ▼
 MEM-012 explicit regions   preserve flat representation
      ▲                            │
      │                            ▼
      │                    MEM-006 typed loop views
      │                            │
      │                            ▼
      │                    MEM-014 AoS/SoA/AoSoA
      │
      └──────────────┐
                     │
              ┌──────▼──────────────────────────────┐
              │ MEM-004 ownership-aware Memory MIR │
              └──────┬──────────────────────────────┘
                     ▼
              MEM-005 call/effect summaries
                ┌────┼──────────────┬──────────────┐
                ▼    ▼              ▼              ▼
             MEM-007 MEM-008      MEM-009        MEM-010
              reuse   SROA/life   return ABI     string views
                │      │              │              │
                └──────┴──────┬───────┴──────────────┘
                              ▼
                 MEM-011/MEM-016 specialization
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
          MEM-015 RC/cycles       task/channel specialization
```

Ordering rules:

1. **Do MEM-001 and the MEM-002 correctness work first.** Performance experiments on racy region/collector state are not trustworthy.
2. **Ship the narrow MEM-003 regression prevention without waiting for a new MIR.** Its current failure and candidate remedy are already measured. Do not build broad SoA machinery first.
3. **Prototype MEM-006 narrowly, but design its view contract to migrate into MEM-004.** Another collection-specific AST flag would create rework.
4. **Define the MIR before broadening escape/reuse/ABI transformations.** MEM-005/007/008/009 all need the same def-use, path, and effect facts; implementing each as a separate AST scan would multiply correctness surfaces.
5. **Make explicit regions depend on TLS correctness and call summaries.** Passing an unsafe ambient allocator through more code would widen the risk.
6. **Defer compact representations, COW, allocators, pointer compression, and prefetch.** They need telemetry and qualifying workloads; none attacks the measured top two gaps.

## Memory benchmark roadmap

Targets below are acceptance thresholds, not predictions. Ratio targets should be evaluated from interleaved runs on the same host/build and must preserve the exact checksum. For new workloads, the first task is to establish and commit a baseline before any optimization candidate is accepted.

| Benchmark | What it measures / why it matters | Current Prismio result | Reference result | Target result | Optimization(s) | Regression detection |
|---|---|---|---|---|---|---|
| `transient_allocation` | Repeated short-lived list construction/growth; allocator and capacity overhead | 3.670 ms; 9,605 ledger allocations; noisy warm-up | C++ 2.826 ms; Rust 2.619 ms | ≤1.15x fastest reference p50, with p90 reported | MEM-001, MEM-013 | Interleaved ≥25 runs; checksum; alloc/byte and p50/p90 gates |
| `struct_creation` | Flat record construction and scan; representation/allocation frequency | 35.134 ms suite; 33.956 ms controlled; 2,000,007 allocations | C++ 6.525 ms; Rust 5.456 ms controlled | Preserve measured unsplit band 5.950–6.592 ms and ≤8 ledger allocations | MEM-003, MEM-011 | Fail on automatic split, >8 allocations, >10% p50 drift, or reappearing malloc in loop |
| `allocation_mutation` | Record creation plus repeated field mutation/locality | 20.600 ms suite; 19.311 ms controlled; 800,007 allocations | C++ 6.324 ms; Rust 6.416 ms controlled | Preserve measured unsplit band 7.404–8.744 ms and ≤8 allocations; later ≤1.15x fastest reference | MEM-003, MEM-006, MEM-011 | Same representation/allocation gate plus assembly check for constant 40-byte stride |
| `nested_collection` | Nested list/struct arenas and destruction | 2.987 ms; five ledger-visible allocations | C++ 2.377 ms; Rust 2.440 ms | ≤1.15x fastest reference; no heap-event or peak-arena regression | MEM-001, MEM-012, MEM-013 | Timing plus arena bytes/chunks/slack and heap-event thresholds |
| `large_buffer_copy` | Bulk flat scalar read/write and vectorization | 17.792 ms | C++ 5.838 ms; Rust 6.568 ms | ≤1.25x fastest reference; no per-element fallback call in selected loop | MEM-006, MEM-011 | IR/assembly structural check, vectorization remark, checksum, p50/p90 |
| `recursive_tree_rebuild` | Unique recursive reuse and destruction | 0.560 ms; rebuild path allocation-free | C++ 0.888 ms; Rust 0.494 ms | No time/allocation regression; ≤1.15x fastest reference | MEM-007 | Allocation-window gate plus final-assembly no-allocation check in normal node arm |
| `allocation_size_matrix` (new) | Throughput and bytes for 8 B–1 MiB objects across tiers | `NOT CURRENTLY MEASURED` | Add equivalent C++/Rust/libc cases | Commit baseline; every candidate reports ops/s, requested/peak bytes by size/tier | MEM-001, MEM-020 | Fixed distributions/seeds; per-bin confidence intervals and RSS |
| `allocation_lifetime_mix` (new) | Short/medium/long lifetime interleaving and fragmentation | `NOT CURRENTLY MEASURED` | C++ RAII and Rust ownership variants | Peak live/requested ratio and post-free RSS tracked; no unexplained >10% regression | MEM-001, MEM-013, MEM-020 | Deterministic trace replay and post-phase allocator stats |
| `stack_escape_matrix` (new) | T0/T1/T2 boundary for local, returned, captured, container, and opaque-call objects | `NOT CURRENTLY MEASURED` | Semantic oracle rather than language speed | Expected tier manifest + dynamic site counts exactly match each case | MEM-004, MEM-005, MEM-008 | Golden AIF/MIR decisions, verifier, stack-frame size check |
| `return_and_temporary` (new) | Fresh return, alias return, branch return, chained calls, argument forwarding | `NOT CURRENTLY MEASURED` | C++ NRVO/Rust move versions | Zero avoidable intermediate allocations for eligible cases; checksum parity | MEM-005, MEM-007, MEM-009 | Per-site allocation/copy counts and IR result-destination checks |
| `string_lifecycle` (new) | Literal, concatenate, append, slice, list store/read, format, and destruction | `NOT CURRENTLY MEASURED` | `std::string`/Rust `String` plus views | Track bytes allocated/copied/scanned; repeated slot read scans zero bytes | MEM-001, MEM-010, MEM-018 | Counter gates per subcase, UTF-8/NUL/empty boundary fixtures |
| `ffi_string_contracts` (new) | Borrow/retain/consume/out/alias/produce adapters and length preservation | `NOT CURRENTLY MEASURED` | C helper oracle | Zero uncontracted ownership events; length scans explicit and then eliminated for view ABI | MEM-005, MEM-009, MEM-010 | C/Prismio differential suite, sanitizer/verifier, scan counters |
| `region_growth` (new) | List growth inside regions, chunk pooling, slack, and checkpoints | `NOT CURRENTLY MEASURED` | Heap and pre-reserved variants | Report final bytes, obsolete-buffer bytes, chunks, peak, pool retention; reserved path near final capacity | MEM-001, MEM-012, MEM-013 | Exact telemetry assertions across capacities and nested regions |
| `layout_matrix` (new) | Same records as scalar, flat list, boxed list, split list, explicit DataView | Particle rows measured; general matrix `NOT CURRENTLY MEASURED` | C++/Rust AoS and SoA variants | Selector never chooses a candidate slower than baseline beyond configured noise budget | MEM-003, MEM-014, MEM-019 | Candidate A/B, manifest/layout golden, timing and RSS gates |
| `dataview_break_even` (new) | Conversion cost versus repeated columnar traversal count | `NOT CURRENTLY MEASURED` | Handwritten AoS/SoA references | Publish break-even curve by rows/fields/passes; selector uses only validated domain | MEM-014, MEM-019 | Sweep sizes/pass counts and compare predicted versus observed choice |
| `rc_fanout` (new) | Plain/atomic retain-release traffic and shared acyclic destruction | `NOT CURRENTLY MEASURED` | Rust `Arc`/`Rc` and C++ shared pointer where semantics match | Exact edge-count oracle; bounded overhead curve by fanout/thread count | MEM-001, MEM-015 | Retain/release counter equality, zero live bytes, scaling curve |
| `cycle_graph` (new) | Cycle discovery, pause, bytes reclaimed, false candidates | `NOT CURRENTLY MEASURED` | Algorithmic oracle; reference timing secondary | Reclaim exact unreachable graph; iterative depth safety; p99 pause and work/node reported | MEM-002, MEM-015 | Graph generators for rings/SCCs/live tails; leak and timeout gates |
| `deep_destructor` (new) | Stack safety for one- and multi-recursive owned fields | `NOT CURRENTLY MEASURED` | Iterative C++/Rust teardown variants | No stack overflow at configured million-node depth; exact release count | MEM-004, MEM-015 | Depth sweep under constrained stack plus ledger equality |
| `closure_capture` (new) | Moved versus borrowed captures, escaping closures, task transfer | `NOT CURRENTLY MEASURED` | Rust closure variants | Placement/ownership matches oracle; zero allocation for nonescaping borrowed closure where legal | MEM-004, MEM-005, MEM-016 | MIR/AIF golden plus allocation-site counters |
| `task_allocation_scale` (new) | OS thread/frame cost and allocator safety at 1/2/4/N workers | `NOT CURRENTLY MEASURED` | Native thread and thread-pool references | Race-free; throughput/latency/RSS curves committed before scheduler decision | MEM-002, MEM-016 | Thread sanitizer where available, stress checksums, per-thread counters |
| `channel_topology` (new) | SPSC/MPSC/MPMC message throughput and ownership transfer | `NOT CURRENTLY MEASURED` | Bounded reference queues with matching semantics | Exact delivery/close behavior; topology-specific candidate must beat generic without regressions | MEM-002, MEM-016 | Long stress, close races, order checks, latency percentiles |
| `compiler_ownership_scaling` (new) | Compile-time/memory complexity versus functions, blocks, sites, aliases | Dispatcher build 0.547 s only; pass split `NOT CURRENTLY MEASURED` | Previous Prismio revision | Near-linear slope for fixed-density generated inputs; no IR/runtime drift | MEM-004, MEM-017 | Generated size sweep, per-pass timer/RSS, checksum and IR differential |

### Harness rules

- Run at least 25 interleaved rotations for decisions expected below 20%; report median, min/max, p90, and confidence interval or bootstrap interval.
- Record compiler SHA, repository revision/dirty marker, target triple, toolchain versions, flags, CPU architecture, OS, scale, seed, and thermal/power mode when available.
- Treat checksums and verifier correctness as hard gates before timing.
- Record both dynamic sites/events and bytes. Static allocation-site counts are not a proxy for runtime frequency.
- Keep warm and cold process modes separate. The transient baseline proves they can disagree sharply.
- Check raw IR and final assembly for structural expectations, but never accept an optimization from assembly alone; require wall time and memory results.
- Compare equivalent ownership semantics. Explicitly annotate exceptions such as functional Prismio tree syntax versus mutating reference source.

## Worker-ready implementation tasks

Each row is a bounded task that can be assigned verbatim as “Implement `TASK-ID` from `MEMORY_ALLOCATION_DEEP_DIVE.md`.” The worker must not silently broaden the parent architecture. Where a task says “baseline first,” no optimizing change should be merged in the same commit as the baseline.

### Stage 0 — Evidence and correctness

| Task | Parent | Isolated scope and likely files | Benchmark link | Acceptance criteria |
|---|---|---|---|---|
| `MEM-001-A` | MEM-001 | Define stable allocation-site ID/kind metadata in `src/ir/bridge.psm`, generator allocation calls, `runtime/llvm-api-backend.c`, and verifier records in `runtime/lang_runtime.c`. Count requested bytes, live bytes, and peak live bytes without changing placement. | `allocation_size_matrix`, all six current memory workloads | Existing verifier tests pass; two builds of identical source emit stable IDs; counts/bytes match hand-computed fixtures; verify-off assembly has no counter calls. |
| `MEM-001-B` | MEM-001 | Extend arena/RC/cycle counters and add one machine-readable report. Integrate optional capture into `benchmarks/run.py` and schema; do not enable it for ordinary timing samples. | `region_growth`, `rc_fanout`, `cycle_graph` | JSON schema/version documented; heap + arena categories do not double-count; counter fixtures exact; normal timing mode unchanged within the suite's noise protocol. |
| `MEM-002-A` | MEM-002 | Convert arena hint, stack, depth, pool, and per-thread stats in `runtime/lang_runtime.c` to portable TLS; add explicit thread cleanup/aggregation hooks from `runtime/program_support.c`. | `task_allocation_scale`, nested-region tests | Concurrent tasks can nest/exit regions independently for a long stress run; no cross-thread chunk use; existing single-thread arena stats/tests retain meaning; Windows and POSIX builds compile. |
| `MEM-002-B` | MEM-002/MEM-015 | Add a concurrency contract for cycle-managed values, protect or partition candidate/walk state, and add a deterministic stress fixture. Limit this task to correctness; do not add deferred RC. | `cycle_graph`, `task_allocation_scale` | No races/corruption under supported sanitizer or repeated stress; exact graph reclamation; no global unsynchronized mutation reachable from task threads; current nonthreaded cycle tests pass. |
| `MEM-017-A` | MEM-017 | Add pass-level time/RSS counters around sema, AIF solve, profile, codegen, runtime curation, native optimization, and link. Add a generated ownership-scaling input tool under benchmark/test infrastructure. | `compiler_ownership_scaling` | Size sweep and JSON output reproducible; disabled instrumentation is inert; no optimization in this task. |

### Stage 1 — Measured regressions and narrow wins

| Task | Parent | Isolated scope and likely files | Benchmark link | Acceptance criteria |
|---|---|---|---|---|
| `MEM-003-A` | MEM-003 | In `src/aif/layout.psm` / `runtime/aif_support.c`, add a sound policy guard that keeps a pointer-free nominal unsplit when hot dynamic uses place it in a flat list and no measured split override exists. Add a manifest reason code. | `struct_creation`, `allocation_mutation`, `layout_matrix` | Default build selects unsplit `BenchMemoryParticle`; verifier counts ≤8; 25-run medians stay inside measured forced-unsplit ranges; all layout/representation tests pass; unrelated chosen layouts diff is reviewed. |
| `MEM-003-B` | MEM-003/MEM-019 | Add container-context features to candidate cost: dynamic constructions, inline eligibility, allocation/release events, total linked bytes, and scan stride. Keep the Stage 1 guard as fallback. | `layout_matrix`, all maintained workloads | Model ranks the particle unsplit candidate; prediction versus candidate A/B recorded for every matrix row; no candidate over the noise budget is automatically selected; schema/version golden updated. |
| `MEM-011-A` | MEM-011 | Make `list_push_slot` and only its required cold closure available to curated IR; normalize linkage/attributes in `runtime/build_driver.c`. | forced/default-unsplit `struct_creation` | Final hot loop contains no call to `list_push_slot`; code size recorded; 25-run A/B shows no regression before enabling; all inline/boxed/arena list fixtures pass. If timing is neutral/regressive, retain evidence and do not enable. |
| `MEM-006-A` | MEM-006 | Define internal `list_read_view`/`list_write_view` IR/runtime contracts with one-time null, representation, bounds, stride, and no-growth validation. Add borrow-conflict sema fixtures; do not transform loops yet. | `large_buffer_copy`, `stack_escape_matrix` | Valid views expose base/len/stride; structural mutation while mutable view lives is rejected or versioned safely; boxed/inline/slice cases have explicit behavior; no current benchmark regression. |
| `MEM-006-B` | MEM-006 | Recognize the bounded full-buffer copy loop and lower it through the typed views to canonical LLVM copy/vector IR. Limit pattern to identical flat scalar element type and proven nonoverlap or correct overlap semantics. | `large_buffer_copy` | Checksum parity; bounds/alias negative tests; selected loop has no per-element runtime fallback; LLVM opt remark or final assembly confirms bulk/vector lowering; 25-run result is reported against the ≤1.25x reference target. |
| `MEM-013-A` | MEM-013 | Add compile-time capacity inference for list literals and simple counted loops; pass capacity to existing `list_new_with_capacity`. No checkpoint allocator in this task. | `transient_allocation`, `region_growth` | Expected capacity/growth counts exact in fixtures; wrong hints remain correctness-safe; timing, peak, obsolete-buffer bytes reported; enable only with no corpus regression. |

### Stage 2 — Memory IR and analysis foundation

| Task | Parent | Isolated scope and likely files | Benchmark link | Acceptance criteria |
|---|---|---|---|---|
| `MEM-004-A` | MEM-004 | Write and implement the in-memory data model for one-function Memory MIR: typed values, blocks, allocation sites, `move`, `borrow`, `end_borrow`, `drop`, and CFG edge arguments. Add textual dump/golden tests; do not route production codegen through it. | `stack_escape_matrix`, ownership test corpus | Every supported test function round-trips to a deterministic dump; verifier rejects double-move, use-after-end, and missing edge ownership; no production IR change. |
| `MEM-004-B` | MEM-004 | Translate a deliberately limited function subset AST→Memory MIR→existing LLVM calls behind a flag. Cover scalars, flat structs, conditionals, calls without closures, and deterministic drops. | `return_and_temporary`, current semantic tests | Differential checksum/diagnostics and normalized LLVM behavior against direct lowering; unsupported constructs cleanly fall back or diagnose only under the experimental flag; no mixed ownership ambiguity. |
| `MEM-005-A` | MEM-005 | Implement SCC-safe per-function summaries for parameter borrow/consume/capture, returned alias/fresh, and opaque extern contracts. Initially report only; do not change tiers. | `stack_escape_matrix`, `return_and_temporary`, FFI tests | Summary golden files match hand-authored oracle; recursive SCCs converge; no compile decision changes; performance and memory cost of summary construction recorded. |
| `MEM-005-B` | MEM-005/MEM-012 | Consume proven summaries in AIF call edges and arena bracketing, with a flag and manifest derivations. | `region_growth`, `stack_escape_matrix`, `nested_collection` | No ownership test regression; dynamic heap/arena counts show only expected movement; bracketed-call increase reported; nested benchmark no time/RSS regression. |
| `MEM-017-B` | MEM-017/MEM-004 | Replace one repeated whole-function free-at-scope/alias scan with MIR def-use/liveness results. Limit to a single documented scan family. | `compiler_ownership_scaling` | Semantics/IR equivalent on full tests; size sweep slope improves or remains linear; pass memory/time reported; remove, rather than duplicate, the old scan on supported paths. |

### Stage 3 — Transformations unlocked by MIR/effects

| Task | Parent | Isolated scope and likely files | Benchmark link | Acceptance criteria |
|---|---|---|---|---|
| `MEM-007-A` | MEM-007 | Generalize reuse across branch-merged same-type constructors with explicit MIR last-use and field destruction. Exclude calls and tag changes. | `recursive_tree_rebuild`, new branch-reuse cases | Zero normal-path allocations for eligible cases; ineligible alias/borrow cases allocate normally; destructor counts exact; existing tree time/allocation does not regress. |
| `MEM-007-B` | MEM-007/MEM-009 | Add destination passing through one layer of summarized fresh-return call. Exclude recursion and FFI in first version. | `return_and_temporary` | One caller slot, zero callee temporary for oracle cases; alias-return and escaping cases remain correct; final IR/assembly and ledger prove elimination. |
| `MEM-008-A` | MEM-008 | Emit precise `llvm.lifetime.start/end` for T0/MIR stack objects with path-correct ends. Do not add SROA logic. | `stack_escape_matrix` | LLVM verifier passes; no lifetime spans a live use; frame/assembly changes recorded; full tests and sanitizers pass. |
| `MEM-008-B` | MEM-008 | Scalar-replace identity-unobserved flat T0 structs in Memory MIR. Materialize only at summarized address-taking calls. | `stack_escape_matrix`, `return_and_temporary` | Eligible fixture has no aggregate alloca after optimization; address-observed fixtures retain identity; spills/frame size and timing reported; no debug-mode semantic regression. |
| `MEM-009-A` | MEM-009 | Add an internal caller-result-slot convention for one nonrecursive, nonextern fresh struct return class. Preserve current external ABI adapters. | `return_and_temporary` | ABI golden documented; allocation ledger shows eliminated result temporary; separate-module and function-pointer exclusions tested; checksum/ownership tests pass. |
| `MEM-010-A` | MEM-010 | Add an explicit borrowed `{ptr,len}` string-view internal/FFI type and C adapter, without changing `String` representation. | `ffi_string_contracts`, `string_lifecycle` | No length scan for view round-trip; lifetime escape rejected; embedded NUL semantics explicit; legacy `char*` extern behavior unchanged. |
| `MEM-010-B` | MEM-010/MEM-015 | Add a typed inline string slot for lists, preserving `{ptr,len}` plus ownership disposition. Do not add capacity/SSO. | `string_lifecycle` | Repeated list reads perform zero `strlen` scans; move/drop counts exact; empty/long/NUL and mixed ownership tests pass; memory/time A/B reported. |
| `MEM-012-A` | MEM-012 | Introduce an internal explicit region-handle ABI and lower one annotated lexical-region callee path through it. Retain ambient compatibility temporarily. | `region_growth`, `stack_escape_matrix` | Handle cannot escape or cross task without an explicit checked transfer; nested caller/callee regions reclaim exact bytes; no process-global lookup on the experimental path. |

### Stage 4 — Advanced runtime and representation work

| Task | Parent | Isolated scope and likely files | Benchmark link | Acceptance criteria |
|---|---|---|---|---|
| `MEM-014-A` | MEM-014 | Add `dataview_break_even` sweep and calibrate construction/traversal/materialization counters. No automatic selection. | `dataview_break_even`, `layout_matrix` | Committed rows/fields/passes matrix with AoS/explicit view/reference results; conversion bytes exact; noise method documented. |
| `MEM-014-B` | MEM-014 | Add direct SoA construction for one identity-free list-of-flat-struct experimental representation behind a force flag. | `layout_matrix`, `dataview_break_even` | No AoS→SoA conversion allocation; field semantics/checksum parity; all consumers either support representation or force a measured materialization; timing/bytes/code size reported. |
| `MEM-015-A` | MEM-015 | Replace recursive cycle mark/scan/collect traversal with explicit reusable worklists; do not change RC policy or thresholds. | `cycle_graph`, `deep_destructor` | Million-node qualifying depth does not overflow; exact reclamation and visit counts match old algorithm on bounded cases; pause/allocation deltas reported. |
| `MEM-015-B` | MEM-015 | Prototype per-thread batched plain-RC decrements only for types proven thread-confined. Keep immediate deterministic flush at observable boundaries. | `rc_fanout`, `task_allocation_scale` | Destructor timing semantics defined and tested; exact final releases; batch sizes/pause/throughput measured; reject if memory retention dominates. |
| `MEM-016-A` | MEM-016 | Generate typed closure/task frames for captures instead of the fixed generic three-argument task ABI on one supported path. | `closure_capture`, `task_allocation_scale` | More than three captures supported on typed path; move/drop ownership exact; no adapter allocation for eligible calls; old ABI remains fallback. |
| `MEM-016-B` | MEM-016 | Add a fixed-size worker-pool prototype behind an opt-in runtime flag; leave task semantics unchanged. | `task_allocation_scale` | Join/error semantics parity; race-free stress; latency/throughput/RSS curves at 1/2/4/N; do not enable by default without a workload win. |
| `MEM-016-C` | MEM-016 | Add an SPSC channel implementation selected only from a proven single-producer/single-consumer topology. | `channel_topology` | Selection proof golden; close/order/blocking behavior equals generic channel; MPSC/MPMC fall back; throughput and tail latency reported. |
| `MEM-018-A` | MEM-018 | Implement a pure representation calculator for enum/optional niches and expose layout reports only. | `layout_matrix`, new enum-size fixtures | Byte/align/tag output matches ABI oracle across nested cases; no production layout change; invalid niches rejected deterministically. |
| `MEM-018-B` | MEM-018 | Prototype either bit-packed booleans **or** small strings as a distinct opt-in type, not both and not generic default. | `string_lifecycle` or new boolean-density sweep | Space and operation curves reported; mutation/iteration boundaries tested; ABI conversions explicit; no default behavior change. |
| `MEM-019-A` | MEM-019 | Version the workload profile schema and ingest MEM-001 dynamic site/representation counters. Add stale-profile rejection and static fallback tests. | `layout_matrix`, build/profile tests | Profile reproducible and validated against source/compiler identity; corruption/staleness cannot change correctness; ordinary builds without profile are deterministic. |
| `MEM-019-B` | MEM-019/MEM-003 | Add an opt-in budgeted top-k layout candidate A/B runner with checksum gate and noise threshold. | `layout_matrix` | Harmful particle split is rejected; failed/timed-out candidate falls back; build cost and selected evidence are reported; no profile changes semantics. |

### Stage 5 — Experiments that require a qualifying result first

| Task | Parent | Entry condition, scope, and likely files | Benchmark link | Acceptance criteria |
|---|---|---|---|---|
| `MEM-020-A` | MEM-020 | **Entry:** MEM-001 identifies a dominant surviving size/lifetime class. Prototype one per-thread slab in `runtime/lang_runtime.c`, behind a flag; never replace all allocations. | `allocation_size_matrix`, `allocation_lifetime_mix`, task scaling | Beats libc on qualifying workload and aggregate suite; RSS/fragmentation no worse by agreed bounds; cross-thread free and teardown correct; otherwise record rejection. |
| `MEM-021-A` | MEM-021 | **Entry:** telemetry finds large semantically immutable copies. Add a distinct immutable shared buffer prototype, not COW `List<T>`. | new immutable-sharing case, `string_lifecycle` | Copy bytes eliminated; counts/lifetime correct; mutation requires explicit materialization; RC overhead and multithread behavior measured. |
| `MEM-022-A` | MEM-022 | **Entry:** a bounded arena is dominated by pointer bytes and hardware counters show memory-bandwidth/latency pressure. Prototype arena-relative 32-bit offsets for one closed representation. | qualifying layout/graph case | Heap bound statically/runtime enforced; FFI adapter explicit; ≥25-run time and peak-byte win; no default ABI change. |
| `MEM-022-B` | MEM-022 | **Entry:** hardware counters identify a latency-bound stable graph traversal. Add one target-aware prefetch experiment behind a flag. | qualifying graph traversal | Prefetch distance sweep and cache/bandwidth counters reported; no nonqualifying suite regression; remove or disable if neutral. |

## Allocation-site and mechanism appendix

| Source/runtime event | Current lowering | Placement/reclamation authority | Information lost or limiting |
|---|---|---|---|
| Struct literal | Heap/arena/stack/RC/cycle allocation chosen per AIF site; optional reuse destination; split can allocate cold record too | AIF tier, region query, reuse token, generated release | Flow/context identity, destination across calls, container representation cost |
| List literal / `list_new` | 40-byte header; lazy contiguous data; typed inline or pointer slots; destination construction for flat literals | AIF region for header/data; element disposition for drops | Stable loop view, capacity range, fully specialized ownership path |
| Array literal | Entry-block `alloca` | Function frame; no runtime drop for storage | Dynamic promotion/demotion model and live-range slot sharing |
| String literal | Private static LLVM constant | Static lifetime | None significant; ABI may later discard length |
| Owned string operation | Exact-sized NUL buffer through runtime allocator | AIF/arena-aware runtime drop | Capacity/growth intent, scan/copy volume, typed container slot length |
| Closure | Generated nominal capture struct plus method | Ordinary struct AIF placement and capture moves | Borrowed capture lifetime and callable effect summary |
| Function return/argument | Pointer-shaped struct ABI; fat internal strings; C adapters | Sema/AIF plus callee/caller conventions | Fresh/alias destination, borrow extent, component alias attributes |
| Optional | Nullable reference shape for supported owning values | Underlying pointee ownership | General niche/tag layout choices |
| Slice | `(handle, offset,len)` value | Backing owner; view borrowed | Explicit LLVM alias/no-grow scope |
| DataView | Header + descriptor array + per-column buffers and full copy | Runtime release/materialize | Direct birth in chosen layout and conversion profitability |
| T0 object | Entry-block alloca | Stack frame | Scalar replacement and lifetime intervals |
| T1 object | 16-byte-aligned bump allocation in linked chunks | Region pop; default chunk pool | Explicit thread ownership, individual last use, slack/growth peak |
| T2 object | General heap allocation | Generated deterministic release | Cross-call destination and unique provenance |
| T3/T4 object | Header-prefixed count, optionally atomic/cycle metadata | Container edge instrumentation/collector | Complete edge proof, concurrency partition, bounded collector work |
| Task | Support-runtime allocation + native thread | Explicit join/release | AIF/verifier bypass, typed capture frame, scheduler reuse |
| Channel | `calloc` header/ring + mutex/conditions | Explicit close/free protocol | AIF/verifier bypass, handle ownership, topology specialization |
| Verifier | Allocation-function name swap plus runtime hooks | Live linked-list ledger | Arena chunks/objects, site IDs, byte histories, reads |

## Evidence artifact index

- Fresh suite JSON: `/tmp/prismio-memory-baseline-2026-09-04.json`
- Controlled 25-run layout experiment: `/tmp/prismio-layout-abba.json`
- Current/forced verifier binaries: `/tmp/prismio-benchmark-verify`, `/tmp/prismio-benchmark-unsplit-verify`
- AIF manifest: `/tmp/prismio-memory-aif-manifest.txt`
- Raw generated IR: `/tmp/prismio-benchmark-current.ll`, `/tmp/prismio-benchmark-unsplit.ll`
- Final disassembly: `/tmp/prismio-current-memory.asm`, `/tmp/prismio-unsplit-memory.asm`
- Focused assembly extracts include `/tmp/current-struct.asm` and `/tmp/current-LargeBufferCopy.asm`

Temporary artifacts are investigation evidence, not durable repository fixtures. Reproducible versions of the decisive checks should be moved into the benchmark/test infrastructure by the worker tasks above.

## Decision summary

The first optimization implementation should be `MEM-003-A`, in parallel only with the nonsemantic telemetry work in `MEM-001-A/B` and the correctness work in `MEM-002-A/B`. It has direct machine-code evidence, a controlled candidate, a large repeatable effect, and a narrow regression gate. The next performance project should be `MEM-006-A/B` for contiguous loop views. The MIR program should begin as an architecture foundation, not be used to delay those two measured fixes.

Do **not** begin with a custom allocator, generic COW, pointer compression, prefetching, or a wholesale cycle-collector rewrite. Current evidence says Prismio's largest gains come from eliminating representation-induced allocation and exposing contiguous memory semantics—not making already-unnecessary allocations marginally faster.
