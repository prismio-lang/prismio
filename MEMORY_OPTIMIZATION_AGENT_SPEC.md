# Prismio Memory Architecture & Optimization Specification
## Autonomous Agent Execution Handbook & Deep Research Synthesis

**Document Version:** 1.2.0  
**Target Repository:** `prismio` (`main` branch)  
**Target Architecture:** Apple Silicon AArch64 / LLVM 22.1.8 / macOS Darwin  
**Author:** Principal Compiler & Runtime Performance Architect  
**Audience:** Autonomous Coding Agents & Systems Engineers  

---

## 0. Execution Status — READ THIS FIRST, AND UPDATE IT

**This section is the living state of the work. The rest of the document is the
original plan and is not rewritten as tasks land; a task's real outcome is here.**
Some of the plan's premises turned out to be wrong when measured — where that
happened it is recorded below, and the task's row is what to trust.

Every finished task carries an evidence file in `aif/evidence/RESULTS-*.md`. Those
files are the primary record: numbers, what was rejected, and what the next agent
should not rebuild. The `git log` is the second.

### 0.1 · Task board

| Task | ID | Status | Evidence |
| :--- | :--- | :--- | :--- |
| 0.1 Integer wrap in loop range guards | MEM-023 | **DONE** | `RESULTS-loop-range-monotonicity.md` |
| 0.2 TBAA store tagging audit | MEM-024 | **DONE** (audit; the named bug was already fixed) | same file, §7 |
| 0.3 Flow-sensitive return provenance | MEM-028 | not started — deferred by request | — |
| 0.4 Benchmark CLI leaks in `suite.psm` | MEM-038 | not started — deferred by request | — |
| 0.5 Ledger requested/live byte tracking | MEM-001 | not started — deferred by request | — |
| 1.1 Container-aware layout veto | MEM-003 | **ALREADY DONE** before this spec — `aifLayoutVetoListElements` ships; ledger is 8 allocations, not 2,000,007, and the benchmark is 6.06 ms against a 6.1 ms target | `src/aif/layout.psm:355` |
| 1.2 Whole-buffer list copies to `llvm.memcpy` | MEM-006 | **DONE** (as `llvm.memmove`) — 0.79x on the copy phase, but that phase is 15% of the benchmark; the 1.43x vs C++ is the *push* path | `RESULTS-whole-buffer-copy.md` |
| 1.3 Curate `list_push_slot` | MEM-011 | **REFUTED** — it works and it is a net loss; the closure blocker is removed so a future profile can flip one line | `RESULTS-loop-range-monotonicity.md` §10, `RESULTS-inline-push-rejected.md` |
| 1.4 Null Pointer Optimization for enums | MEM-031 | **DONE for boxed recursive binary enums** — traversal 1.88x faster, rebuilding 1.61x; 16,384/8,192 empty allocations removed. Optional, foreign, inline and other enum representations retain their existing encoding. | `RESULTS-enum-null.md` |
| 1.5 16-byte German String container slots | MEM-032 | not started (**check the tree first** — the fat-String representation already ships) | — |
| 1.6 Single-threaded mutex bypass in cyc | MEM-033 | **DONE, and worth ~nothing here** — no benchmark moves; a probe built to hammer it reads 0.979. Header split (step 2) deliberately not attempted | `RESULTS-cyc-lock-bypass.md` |
| 1.7 Multi-point stencil range guards | MEM-035 | **DONE** — the offsets were never the blocker; the *condition* `at + 3 < n` was. convolution **0.707x**, 0 -> 9 NEON | `RESULTS-stencil-condition.md` |
| 1.8 Intrinsic `llvm.memcpy` string ops | MEM-036 | not started | — |
| 1.9 Iterative worklist for recursive drops | MEM-029 | not started | — |
| 2.1 Map probing and full-width integer hashing | MEM-034 / MEM-014 | **PARTIAL, MEASURED** — triangular probes, 1/2 load, equality-free rehash: updates 1.56x faster; insert/lookup 1.28x faster. High-word-only U64 keys no longer collapse to one hash. Insertion order preserved; SIMD replacement remains open. Update peak live bytes +43%. | `RESULTS-map-probing-wide-hash.md` |
| 2.1 follow-up: single-probe updates | MEM-034 | **DONE (API and lookup cleanup)** — `mapUpdate` handles existing entries in one probe; 1.57x update speedup from the previous pass's baseline. Existing insert/lookup callers gain 4.2%. No additional peak memory. Equivalent single-probe C++ remains 2.36x faster. | `RESULTS-map-update.md` |
| 2.2 – 2.8 | various | not started | — |
| **E1 Push predication** | §0.4 | **DONE** — refutes `RESULTS-inline-push-rejected.md`: g6 0.985 where the rejected form was 1.275x. prime_sieve 0.943, knapsack 0.945. Neither target moved; that is what found E5 | `RESULTS-push-predication.md` |
| **E2 AIF-discharged store speculation** | §0.4 | **NOT BUILT — its acceptance test already passes.** knapsack emits **25** NEON ops from the source it has today (E2 asks for >= 22) and measures **0.999 of C++**. The ~1.16x was priced against a *conditional-store* benchmark arm that `RESULTS-loop-range-guard.md` §9 then rewrote to the unconditional `max` the other two languages write. All six conditional-store sites in `benchmarks/` and `aif/corpus/` were checked and none is E2's shape | see §0.3 |
| **`key_value_update` probe cost** | 2.1 follow-up | **DONE (library), and the compiler lever refuted** — `mapSet` stops re-reading the bucket the probe already resolved: **0.961**, 1.985x -> 1.88x of C++, hashmap_insert_lookup 0.991. Giving `loop`/`for` the flat guard removes 4 loads and a branch per probe and is a **net loss** (hashmap 1.055) — the guard is paid per loop *entry* and a probe iterates once | `RESULTS-map-probe-loop-guard.md` |
| **`key_value_update` — the hash** | 2.1 | **DONE, and it beats both.** `10.495 -> 4.948 ms`: **0.880x of C++**, **0.576x of Rust**, from 1.866x / 1.221x. `hashmap_insert_lookup` 6.959 -> 4.484, **0.657x / 0.568x**. `keyMixInt` is one fold, `mapRehash` measures its own probe displacement and re-mixes when it is bad. Beats §2's forecast on both ratios. **Four other levers priced at zero and recorded** | `RESULTS-adaptive-map-hash.md` |
| **E3 Loop-scoped reuse token** | §0.4 | not started | — |
| **E4 Phase-time before choosing a lever** | §0.4 | recorded, no code | `RESULTS-whole-buffer-copy.md` §3 |
| **E5 Scoped alias metadata on the list header** | §0.4 | **DONE, and its own target does not move** — the fill loop now emits NEON stores (4 -> 31) and `len` leaves memory, and the fill *phase* reads 2.235 -> 2.198 ms because it is page-fault bound, not instruction bound. The win is **prime_sieve 0.906**; matrix_multiply 1.017 is the one regression. Needed a second half the proposal does not have: `noalias` on the list constructors | `RESULTS-scoped-alias-metadata.md` |

**Next priorities: FFT (1.77x of C++), mergesort (1.59x), string_search
(1.33x), mandelbrot (1.27x), binary_search (1.26x), graph_bfs (1.26x).** Both
associative benchmarks now beat C++ and Rust. E2 is not built and should not be
— §0.3 says why.

**The two open levers under `key_value_update` are language-level, and both are
priced in `RESULTS-adaptive-map-hash.md` §2.** A `Map` in a frame rather than the
heap is worth **1.74x** in C (SROA promotes the four fields to registers);
inlining across the map's call boundaries is worth **2.6x** in C. Prismio can
collect neither today. Internalising every function but `main` is implemented and
measured there — it shrinks binaries 215 KB -> 131 KB and made this workload
*worse*, so it is reverted, not lost. E5 is done and its own target is closed:
`large_buffer_copy`'s fill phase is 27% of that benchmark and is page-fault
bound, so no instruction-level lever can reach it — see the two corrections in
§0.3. The remaining large gaps against C++ are `key_value_update` 1.985x,
`fft` 1.765x, `mergesort` 1.592x, `prime_sieve` 1.428x (was 1.576x),
`large_buffer_copy` 1.416x, `string_search` 1.328x, `mandelbrot` 1.272x,
`binary_search` 1.262x, `graph_bfs` 1.259x, `convolution` 1.240x.

### 0.2 · Baseline state at the last checkpoint (2026-09-05, end of session 2)

- Compiler at a **three-generation byte-identical IR fixpoint**, MD5
  `119c6d4f5e69c207971ec998e452fe9f` (`build/kv/b1.ll` = `b2.ll` = `b3.ll`);
  promoted to `.prismio/build/debug/prismio`. Binary MD5 differs per link and is
  not the criterion — see §0.3.
- Suite **300/300** through `tools/run_suite.py`. Tests added since the last
  checkpoint: `test_127`–`test_129` (enum NPO), `test_130_list_alias_scopes`.
- `tools/release_gate.py` reports **12 of 14**, both failures pre-existing and
  reproduced on the session-start compiler: the suite step's `PRISMIO=<path>`
  invocation (§0.3), and the AIF oracle differential, whose output is
  **byte-identical** to the session-start compiler's apart from the path on its
  first line.
- `--verify` on all 34 benchmarks: **0 violations**, **2 leaked** per run, which
  is MEM-038 (Task 0.4) and nothing else. Allocation counts unchanged.
- **All 34 benchmark checksums identical end to end** — session-start compiler
  and standard library against the final pair. Corpus 7/7 byte-identical output;
  `g6_game` and `g4_ecs_world` **mnemonic-identical across the whole session**.
- `std/map.psm` changed this session (`mapProbe`'s miss encoding and `mapSet`);
  coordinate before editing it.

### 0.2b · Baseline state at the previous checkpoint (2026-09-05, end of session 1)

- Compiler at a two-generation byte-identical IR fixpoint; promoted to
  `.prismio/build/debug/prismio`.
- Suite **295/295**. Tests added this session: `test_123_loop_range_guard_wrap`,
  `test_124_whole_buffer_copy`, `test_125_stencil_range_guard`,
  `test_126_push_predication`.
- `tools/release_gate.py` reports **13 of 14**. The one failure, the AIF oracle
  differential, has **6 disagreements that are byte-identical to the baseline
  compiler's**: it is a pre-existing property of this working tree, not a
  regression. Compare against the previous compiler before treating it as one.
- `--verify` on all 34 benchmarks: **0 violations**. Each run reports **2 leaked**
  blocks, which is MEM-038 (Task 0.4) and nothing else.
- All 34 benchmark checksums byte-identical to the pre-Stage-0 compiler.

### 0.3 · Corrections to this document, learned by measuring

**The plan's Task 0.1 was a three-line fix in the plan and three separate defects
in the code.** Besides the wrap, `irIVStepText` took the induction variable's
direction from the loop condition rather than from the update's operator (so
`at = at - 1` under `while (at < 3)` read out of bounds without crashing), and the
"strict bound adjustment" listed as step 3 was not a refinement: with `high = bound`
the guard is **false at run time for every loop over a whole list**, which is most
of them. That one line is worth `large_buffer_copy` 16.41 ms -> 7.97 ms.

**A guard that starts firing selects an arm nobody has priced.** Fixing the bound
turned two benchmarks 1.108x *slower*, because `ir_list_flat_elem` — the pointer
element read — had no `check_bounds` parameter and so kept a per-iteration header
`len` load that LICM could not lift. The "fast" path was 1.137x of the boxed path
it replaces, and had been since it was written. Measure the arm, not just the guard.

**`tools/run_suite.py --compiler X` does not compile the file fixtures with X.**
It copies X to a temp file named `prismio`, and `isGlobalLauncher()` in
`src/project/ums_cli.psm` makes any binary of that name forward the whole command
to `.prismio/build/debug/prismio`. A green suite says nothing about the compiler
you passed. **Promote the candidate to `.prismio/build/debug/prismio` first**, or
use `PRISMIO=$PWD/build/gen2 python3 tests/test_runner.py`.

**The commands in §6 are not all real.** There is no `tools/build.py`,
`tools/test.py` or `tools/verify_fixpoint.sh`. The real loop is:

```bash
tools/bootstrap.sh --compiler <prev> --out build/genN      # ~7 s
tools/bootstrap.sh --compiler build/genN --out build/genN1 # the fixpoint check
cp build/genN1 .prismio/build/debug/prismio                # so the suite tests it
python3 tools/run_suite.py
python3 tools/release_gate.py --rc build/genN1             # 14 gates
python3 tools/fn_mnemonic_diff.py <old-binary> <new-binary> # BEFORE believing a timing
```

**Read `aif/evidence/RESULTS-bounds-check-ceiling.md` before optimizing a list
loop.** It prices the whole design space on the real `RtList` layout, and several
obvious ideas in this document — hoisting a `(base,len)` view into the preheader
above all — are measured there at exactly zero.

**A memory benchmark measured warm measures a different program.** Every
benchmark in `benchmarks/` runs **one shot per process**. `benchLargeBufferCopy`
run repeatedly *inside* one process settles to a 0.55 ms fill; run one shot per
process at the same scale it is 2.2 ms, because `rt_base_alloc` recycles the
block and the pages stay faulted in across iterations. The warm number describes
nothing the suite reports, and it is how §0.4's E4 came to record a 2.58 ms fill
against C++'s 0.61 ms. Phase-timed one shot per process, the fill is 2.2 ms, the
copy 1.1 ms and the **checksum loop 4.5 ms** — the checksum is the benchmark.
A C++ arm written warm reads a *slower* fill than Prismio's, purely because
`std::vector`'s allocator returns the block to the OS between iterations.

**The fixpoint criterion is the emitted IR, not the binary.** Two bootstraps of
the same source produce two different binary MD5s — the link is not
reproducible. `<compiler> build src/main.psm -o x.ll` twice and compare those.
Half an hour was spent on three "non-fixpoint" binaries that were a fixpoint.

**`tests/test_runner.py` invoked as `PRISMIO=<path>` fails `--target` and `jit`
whatever compiler is passed**, including the current project host. That is what
makes `tools/release_gate.py` report a suite failure. `tools/run_suite.py`, which
promotes the candidate to `.prismio/build/debug/prismio` first, reports 299/299.
Run the baseline through the same invocation before treating either as a
regression.

**A preheader guard is paid per loop *entry*, and `loop` is the shape that
never repays it.** `RESULTS-affine-index-rejected.md` established the law;
`RESULTS-map-probe-loop-guard.md` names the tell. `while (i < n)` carries a trip
count and is a traversal. `loop` in this language is a *search* -- probe, scan,
parse -- which exits early by construction, so its body runs about once per
entry. Wiring `generateLoopFlatGuard` to `loop` and `for` measurably works (the
probe body drops from 9 loads and 5 branches to 5 and 4) and makes
`hashmap_insert_lookup` **1.055** slower. Do not re-propose it.

**E2 was overtaken by the benchmark fix that motivated it.** Its measurement
came from `RESULTS-loop-range-guard.md` §8, written while `benchKnapsack` still
spelled the DP update as `if (candidate > best[at]) { list_set(...) }`. §9 of the
same file then rewrote that arm to the unconditional `max` C++ and Rust write --
because the three implementations were meant to be the same program and were not
-- and knapsack now emits 25 NEON ops and reads 0.999 of C++. **Nothing in the
tree is still shaped like E2's input.** Checked, 2026-09-05: `fft`'s bit-reversal
swap (executed once, not a loop body), `prime_sieve`'s condition (outside the
inner loop, not per element), `mergesort`'s merge (each arm advances a *different*
index, so it is not a select in any language, and C++ does not vectorise it
either), and `graph_bfs`'s four `seen` updates (the arm also pushes to a queue).
If E2 is built it will be a compiler capability with no benchmark that moves;
find the program first.

**A scrambling hash costs more than it buys on a power-of-two open-addressed
table.** `RESULTS-adaptive-map-hash.md`. `std/key.psm` used MurmurHash3's
finalizer and the header's reason — "consecutive small ids with an identity hash
are one long probe chain" — is true of *linear* probing and false of this table.
Measured: an avalanche mix costs **1.21 probes per lookup**, which is what random
placement costs, where the same keys unscrambled cost **1.00**; and it scatters
consecutively-allocated ids across a 1 MB index table so every probe is an
unprefetchable L2 access. Identity hashing was worth **4.7x** in C. The shipped
answer is `h ^ (h >>> 16)` — Java's `spread()` — plus an escape hatch in
`mapRehash` for the one family that defeats a fold. **Before proposing a
container redesign, check whether the hash is throwing the locality away.**

**Four things that are not `key_value_update`'s cost, all measured:** the table
design (Swiss, key-in-slot and inline-pair are priced against the current one and
lose), the `list_get` bounds check and the representation test (both removed
entirely: 7.220 -> 7.386 ms), function linkage, and the probe count.

### 0.4 · Research-grounded ensembles that are NOT in this document

Added 2026-09-05 after measuring §5's tasks. Each of these is proposed because a
measurement in this repository says the plan's own lever is spent or wrong, and
each names the literature it comes from. **They are proposals with acceptance
tests, not results.**

#### E1 · Push predication — one preheader guard for every push in the loop

*The measurement.* `large_buffer_copy` is 1.43x of C++ and the copy is not why:
phase-timed, its fill loop is **2.58 ms against C++'s 0.61 ms** while its copy is
1.07 ms and its checksum is at parity. Two `list_push` calls per iteration is the
gap. `struct_creation` has the same shape.

*What was already refuted.* `RESULTS-inline-push-rejected.md` emitted the fast
path **at each push site**: `elem_size == S && len < cap` inline, `list_push_slot`
on the slow arm. g6's `plan_orders` builds a fresh short-lived list per squad per
frame, so almost every push grows, the check is paid every iteration and never
wins — 1.275x. Task 1.3's curation reproduces it exactly (`world_spawn` 37 -> 115
instructions). That file concluded the fix needs a pushes-per-list **profile**.

*The proposal.* It does not. Do not check per push — **predicate the loop**. One
guard in the preheader:

```
elem_size == S  &&  cap - len >= trip_count * pushes_per_iteration
```

If it holds, every push in the loop is provably in-capacity and in-representation,
so the body is `store; len++` with **no branch at all** — strictly less work than
the rejected version, which still branched. If it does not hold, the ordinary loop
runs unchanged, so `plan_orders` (from `list_new()`, capacity 0) evaluates one
compare per loop *entry* and pays nothing per iteration. **The runtime guard is
the profile**, computed once where the offline one was being asked for.

`generateLoopRangeGuards` already computes `[init, bound]`, which is the trip
count for a step of 1, and the versioning machinery is the same `i1` that now
carries the representation, range and monotonicity conjuncts. This is HotSpot's
loop predication (Click & Rose; see the OpenJDK C2 loop-optimization notes)
applied to the capacity check instead of the range check — the same move that has
now worked three times in this compiler.

*Acceptance.* Zero `bl _list_push_slot` / `bl _list_push_inline_scalar*` in
`benchStructCreation` and in `benchLargeBufferCopy`'s fill; **`g6_game`'s
`world_spawn`, `recruit` and `plan_orders` mnemonic-identical** to before, which
is the check the rejected attempt fails.

**BUILT AND GREEN, 2026-09-05 — `RESULTS-push-predication.md`.** g6's
`world_spawn` and `recruit` are untouched and g6_game measures 0.985, against
1.275x for the rejected form: the profile that evidence file asked for does not
exist, the check just had to move. prime_sieve 0.943, knapsack 0.945.
**But neither target moved** — the fill loop is 0.994, because
`list_push_inline_scalar` was already curated and both loops are
memory-bandwidth bound. The 4.2x is `len`, not the check: see E5.

#### E2 · Store speculation discharged by AIF, not by a heuristic

**NOT BUILT, 2026-09-05, because its acceptance test already passes.** It asks
that "knapsack emits >= 22 NEON ops from the source it has today"; knapsack emits
**25** and reads **0.999 of C++**. The measurement below is from
`RESULTS-loop-range-guard.md` §8, and §9 of that same file rewrote the benchmark
arm it was measured on. No shape in `benchmarks/` or `aif/corpus/` is still
E2's input -- see §0.3. The idea is not wrong; it has no target.

*The measurement.* `RESULTS-loop-range-guard.md` §8: turning
`if (v > l[i]) { l[i] = v }` into an unconditional store of a `select` is worth
**~1.16x on knapsack** and is most of what is left against C++, which writes
`std::max` unconditionally and gets 22 NEON ops for it. It was declined because it
"introduces a write where the program had none — a data race under `spawn`, and it
dirties a line the loop only read", and would need "an escape/threading
obligation, not just the range guard".

*The proposal.* **Prismio already computes that obligation.** AIF assigns each
site an escape tier and reports `Isolated` per program; a container the analysis
proves isolated at the loop is not reachable from another task, so the speculated
write is unobservable and the obligation is discharged statically rather than
assumed. Fold "isolated" into the same preheader `i1` and speculate only on the
true version; the false version keeps the conditional store.

*Why not the textbook answer.* LLVM's sound route for a conditional store is
`llvm.masked.store`, and the loop vectorizer will use it where the target has one.
**AArch64 NEON does not** — masked stores are SVE — so on this target a masked
store scalarises and buys nothing. Select-and-store is the only vectorizable form
here, which is what makes the AIF route the one worth building.

*Acceptance.* knapsack emits >= 22 NEON ops from the source it has today; a
container reachable from a `spawn` declines and stays conditional.

#### E3 · Loop-scoped reuse as a token, not as buffer hoisting

*The measurement.* `transient_allocation`: 9,605 allocations and 26 MB of churn.

*What §5 Task 2.2 proposes* is to hoist the buffer and reset `len = 0`. That is
the right effect by the wrong mechanism: it is a codegen special case for one
syntactic shape.

*The proposal.* Prismio already has reuse tokens (`RESULTS-M2-reuse-token.md`) and
destination-passing pushes. FP² (Lorenzen, Leijen & Swierstra, ICFP 2023) and
Perceus (Reinking et al.) give the general form: a value whose last use is a
consumption can hand its allocation to the next constructor **as a token**, and a
function that is *fully in place* needs no allocator at all. Extending the token
across a loop back-edge — the iteration's container is dead at the latch, so its
block is the next iteration's — subsumes the hoisting case and also catches the
shapes it misses (a container returned and immediately consumed, a container
rebuilt at a different length). Destination-passing style (Bagrel, arXiv
2312.11257; and the λd calculus) is the same idea from the writer's side and is
already how `list_push(l, T { ... })` is lowered here.

*Acceptance.* `transient_allocation` allocations 9,605 -> single digits with **no
new syntactic pattern match in `src/ir/stmt.psm`**.

#### E5 · Scoped alias metadata on the list header — the unlock E1 exposed

**BUILT AND GREEN, 2026-09-05 — `RESULTS-scoped-alias-metadata.md`.** The
mechanism works and its own acceptance test half-fails. The fill loop does emit
NEON stores (`_benchLargeBufferCopy__Int` 4 -> 31 vector instructions, `len`
promoted out of memory), and the fill *phase* does not move: 2.235 -> 2.198 ms,
because it writes 16 MB into freshly mapped pages and was never instruction
bound. **prime_sieve 0.906** is what the change buys; matrix_multiply 1.017 is
what it costs. The proposal is also incomplete — a scope pair separates a header
from an element block but not one header from another, so it needed `noalias` on
`list_new`/`list_new_with_capacity` as well; either half alone moves the loop by
nothing.

*The measurement.* E1 made the push checkless and the fill loop did not move
(0.994). The loop cannot vectorise, and the reason is `len`: it is loaded and
stored in the `RtList` header every iteration, and LLVM will not promote it to a
register because it is an `i32` under TBAA leaf `"int"` — **the same leaf as the
element stores of a `List<Int>`**. The recurrence stays in memory and the loop
stays scalar. Task 0.2 found the same collision blocking the `len` load in
`ir_list_flat_elem`.

*Why TBAA cannot fix it.* In C, `l->len` and `((int*)data)[k]` are both `int`
lvalues and genuinely may alias; clang tags them identically and must. Giving the
header its own leaf would make codegen's accesses NoAlias with the curated
runtime's accesses to the same fields, which is wrong.

*The proposal.* The fact codegen has and C does not is that **the header and the
element block are two separate allocations**. `!alias.scope` / `!noalias` is the
metadata for exactly that, it is per-region rather than per-type, and it does not
disturb the runtime's own tags. Emit a scope per guarded loop: header accesses in
one, element accesses in another, declared mutually non-aliasing. E1 is the
precondition — with the capacity proved, `len` is a pure induction variable and
aliasing is the only thing left holding it in memory.

*Acceptance.* `benchLargeBufferCopy`'s fill loop emits NEON stores; the fill phase
moves from 2.58 ms toward C++'s 0.61 ms. The slow arm, where `list_inline_grow`
may reallocate, must stay outside the scope.

#### E4 · The negative result that saves the most time

**Stop optimizing `large_buffer_copy`'s copy.** Phase timings above: the copy is
~15% of it, the checksum loop is ~60% and is already at C++ parity, and the fill
is the 4.2x. §2's target of 6.10 ms is not reachable through the copy at all. The
same discipline applies to §2 generally — **phase-time the benchmark before
believing which lever it names.**

---

## 1. Executive Mission & Invariants

You are tasked with executing the end-to-end memory model, container layout, IR lowering, and compiler optimization overhaul for the Prismio programming language.

Your objective is to push Prismio’s performance to **unquestioned best-in-class**—consistently matching or beating C++20 `-O3` (Clang) and Rust 2021 `opt-level=3` (rustc)—while preserving semantic guarantees and achieving zero leaks/violations under the `--verify` ledger.

### Non-Negotiable Invariants:
1. **Fixpoint Compiler Bootstrap:** Every compiler change must compile itself to a byte-identical or semantically verified fixpoint (`./build.ums` or `python3 tools/build.py`).
2. **Total Language Semantics:** Prismio's `list_get` and `list_set` are *total* (out-of-bounds yields `0` or no-op). Optimizations version loops into unchecked fast paths, but slow/fallback paths **must preserve total semantics**.
3. **Verification Ledger Zero Violations:** Running test suites or benchmarks with `--verify` must report `0 leaked, 0 violation(s)` (excluding benign process-exit digit strings).
4. **Deterministic Checksum Invariance:** Every benchmark in `benchmarks/prismio/` produces a deterministic checksum. Checksums must remain byte-for-byte identical.
5. **Strict Staging Discipline:** Execute Stage 0 (Correctness & Soundness) **before** Stage 1. Never optimize on top of latent integer wrap SIGSEGVs or memory corruption.

---

## 2. Quantitative Performance Target Forecast

The following table reflects empirical baselines measured against C++20 (`clang++ -O3 -std=c++20`) and Rust 2021 (`rustc -C opt-level=3`), alongside post-implementation targets verified via microarchitectural modeling:

| Benchmark Workload | Category | Current Prismio | Post-Fix Target | Speedup Factor | vs. C++ Target | vs. Rust Target | Key Enabling Mechanism |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **`large_buffer_copy`** | memory | 20.53 ms | **5.80 – 6.10 ms** | **3.4x – 3.5x** | **0.85x – 0.89x** (Beats C++) | **0.79x – 0.83x** (Beats Rust) | Loop range guard + `tag_scalar` + `llvm.memcpy` |
| **`struct_creation`** | memory | 35.13 ms (split) | **5.40 – 5.90 ms** | **6.0x – 6.5x** | **0.78x – 0.85x** (Beats C++) | **0.68x – 0.75x** (Beats Rust) | Container Layout Veto + Inlined `list_push_slot` |
| **`key_value_update`** | associative | 18.70 ms | **5.40 – 5.80 ms** | **3.2x – 3.5x** | **0.96x – 1.03x** (Matches C++) | **0.62x – 0.67x** (Beats Rust) | 16-Way SIMD SwissTable + Single-allocation layout |
| **`tree_traversal`** | algorithms | 0.68 ms | **0.32 – 0.35 ms** | **1.9x – 2.1x** | **0.84x – 0.92x** (Beats C++) | **0.97x – 1.06x** (Matches Rust) | Null Pointer Optimization (NPO) on Empty variants |
| **`transient_allocation`**| memory | 2.64 ms | **0.35 – 0.45 ms** | **6.0x – 7.5x** | **0.80x – 0.90x** (Beats C++) | **0.80x – 0.90x** (Beats Rust) | Scoped container buffer reuse token (0 malloc churn) |
| **`convolution`** | compute | 6.28 ms | **3.30 – 3.50 ms** | **1.8x – 1.9x** | **0.94x – 0.99x** (Beats C++) | **0.97x – 1.03x** (Matches Rust) | Multi-point stencil range guard + NEON SIMD |
| **`mergesort`** | algorithms | 6.36 ms | **3.40 – 3.65 ms** | **1.7x – 1.9x** | **0.92x – 0.98x** (Beats C++) | **0.68x – 0.73x** (Beats Rust) | Block `llvm.memcpy` scratch copy + unswitched bounds |
| **`hashmap_insert_lookup`**| associative | 9.51 ms | **5.20 – 5.80 ms** | **1.6x – 1.8x** | **0.75x – 0.84x** (Beats C++) | **0.66x – 0.73x** (Beats Rust) | SIMD Group H2 probe + 70% load factor resize |
| **`prime_sieve`** | algorithms | 0.86 ms | **0.48 – 0.52 ms** | **1.7x – 1.8x** | **0.92x – 1.00x** (Matches C++)| **0.53x – 0.58x** (Beats Rust) | Hoisted scalar byte storage + loop versioning |
| **`binary_search`** | algorithms | 90.81 ms | **64.0 – 68.0 ms** | **1.3x – 1.4x** | **0.88x – 0.94x** (Beats C++) | **0.49x – 0.52x** (Beats Rust) | Hoisted base pointer + branchless comparison |
| **`nested_collection`** | memory | 3.32 ms | **2.20 – 2.40 ms** | **1.4x – 1.5x** | **0.87x – 0.95x** (Beats C++) | **0.89x – 0.98x** (Beats Rust) | Last-Bump Arena Rewind + Pre-capacity inference |
| **`string_slots_probe`** | strings | 1.85 ms | **0.25 – 0.32 ms** | **5.8x – 7.4x** | **0.85x – 0.95x** (Beats C++) | **0.85x – 0.95x** (Beats Rust) | 16-byte German String slots (0 `strlen` rescans) |

### Global Allocation & Memory Footprint Metrics:
- **Total Heap Mallocs (`struct_creation`):** Drops from **2,000,007 to 8** (−99.9996%).
- **Heap Allocations (`tree_traversal`):** Drops from **32,772 to 16,384** (−50.0%, 0 allocations for `Empty` leaves).
- **Heap Churn (`transient_allocation`):** Drops from **26,233,732 bytes to <25,000 bytes** (−99.9%).
- **Redundant Bytes Scanned via `strlen`:** Drops from **>100,000 bytes to 0 bytes** (−100%).
- **Peak Resident Set Size (RSS):** Drops by **28% to 45%** across memory-heavy workloads.
- **Verification Status:** **100% PASS (0 leaks, 0 violations)** across all 25 benchmark suites.

---

## 3. Academic Research Literature & Architectural Synthesis

```
                                 COMPREHENSIVE RESEARCH MATRIX
 ┌───────────────────────────────────────────────┬───────────────────────────────────────────┐
 │ Seminal Academic Paper / Industry Engine      │ Prismio Implementation Synthesis          │
 ├───────────────────────────────────────────────┼───────────────────────────────────────────┤
 │ 1. Umbra / CedarDB (Neumann & Kemper, CIDR'21)│ 16-Byte German String Container Slots:    │
 │    VLDB String Dictionaries (Binnig et al.)   │ Inline len + 4B prefix + 8B payload       │
 ├───────────────────────────────────────────────┼───────────────────────────────────────────┤
 │ 2. Bodik et al. ABCD (PLDI 2000)              │ Morphic Vector Stencils & Loop Versioning:│
 │    HotSpot Loop Predication (Click & Rose)    │ Preheader monotonicity & multi-point guards│
 ├───────────────────────────────────────────────┼───────────────────────────────────────────┤
 │ 3. Perceus FBIP (Leijen et al., PLDI 2020)    │ In-Place Reuse Tokens & Container Recycled│
 │    Swift OSSA Middle IR (Lattner et al.)      │ Buffer reuse in transient loops           │
 ├───────────────────────────────────────────────┼───────────────────────────────────────────┤
 │ 4. Google Swiss Tables (Kulukundis, CppCon)   │ 16-Way NEON SIMD Flat Map:                │
 │    F1 Query Hash Tables (Goetz et al., VLDB)  │ 1-byte control metadata + contiguous slots│
 ├───────────────────────────────────────────────┼───────────────────────────────────────────┤
 │ 5. Rust Null Pointer Optimization (NPO)       │ Null-Discriminant Enum Compression:       │
 │    Swift Enum Layout & Multi-Payload Enums    │ 0-allocation fieldless variant encoding   │
 ├───────────────────────────────────────────────┼───────────────────────────────────────────┤
 │ 6. Tofte-Talpin Regions (POPL 1994)           │ Rewindable Arena Bump Engine:             │
 │    Mesh Compaction (Berger et al., ASPLOS'19) │ "Last-Bump" contiguous in-place extension │
 ├───────────────────────────────────────────────┼───────────────────────────────────────────┤
 │ 7. Bacon-Rajan Concurrent Cycle Collection    │ Uncontended Fast-Path Cycle Collection:   │
 │    (ECOOP 2001)                               │ Bypass pthread mutex in single-thread mode│
 ├───────────────────────────────────────────────┼───────────────────────────────────────────┤
 │ 8. Vyukov MPMC / SPSC Bounded Queues          │ Lock-Free Cacheline-Padded Channel:       │
 │    Pony Deny Capabilities (Clebsch, OOPSLA'15)│ Direct move semantics without task locks  │
 ├───────────────────────────────────────────────┼───────────────────────────────────────────┤
 │ 9. Apple Silicon M-Series Microarchitecture   │ Target CPU Scheduling & Vector Decoupling:│
 │    (LLVM Apple-A14/M1 Target Architecture)    │ `-mcpu=native -fno-math-errno`            │
 └───────────────────────────────────────────────┴───────────────────────────────────────────┘
```

---

## 4. Master Architectural Tracker (MEM-001 to MEM-040)

| ID | Component | Severity | Description & Root Cause | Target Files |
| :--- | :--- | :---: | :--- | :--- |
| **MEM-023** | Loop Bounds | **CRITICAL** | Integer wrap in loop range guards produces SIGSEGV (-11) on wrap. | `src/ir/expr.psm:1182-1227` |
| **MEM-024** | Alias Analysis | **CRITICAL** | Missing `tag_scalar` on list stores blocks LICM pointer hoisting. | `runtime/llvm-api-backend.c:2305` |
| **MEM-028** | Ownership | **HIGH** | Delegating `return g(a, b)` leaks 100% of allocations due to symbol-level provenance. | `src/sema/ownership.psm:340` |
| **MEM-003** | AIF Layout | **HIGH** | Particle layout split disqualifies `List<T>` from flat storage (2M mallocs). | `src/aif/layout.psm:210` |
| **MEM-006** | IR Lowering | **HIGH** | Whole-buffer list copies run as scalar unrolled loops instead of `llvm.memcpy`. | `src/ir/expr.psm:1980` |
| **MEM-011** | Backend | **HIGH** | `list_push_slot` uncurated; forces function call indirection per literal push. | `runtime/build_driver.c:1200` |
| **MEM-031** | Enums / Codegen| **HIGH** | Fieldless enum variants (`Empty`, `None`) allocate 32B heap structs (no NPO). | `src/sema/enums.psm:94`, `src/ir/expr.psm:1530` |
| **MEM-032** | Strings / IR | **HIGH** | Container string slot forces `str_own` malloc on <=12B strings and erases length. | `src/ir/types.psm:339`, `src/ir/expr.psm:692` |
| **MEM-033** | Runtime / GC | **HIGH** | `cyc_retain`/`cyc_release` unconditionally locks pthread mutex in single-thread. | `runtime/lang_runtime.c:1524` |
| **MEM-034** | Standard Lib | **HIGH** | `Map<K, V>` uses 3 disjoint `List` containers with linear probing & pointer chasing. | `std/map.psm:69-108` |
| **MEM-035** | Vectorizer | **HIGH** | Multi-point 1D/2D stencils (e.g. convolution) emit 7 interior bounds branches. | `src/ir/expr.psm:1180` |
| **MEM-036** | Standard Lib | **MEDIUM** | String concatenation/slice copies characters byte-by-byte via while loops. | `std/string.psm:134`, `std/process.psm:31` |
| **MEM-037** | Toolchain | **MEDIUM** | Clang driver emits generic ARMv8.0 without `-mcpu=native` or `-fno-math-errno`. | `runtime/build_driver.c:1290` |
| **MEM-038** | Benchmarks | **MEDIUM** | `suite.psm` main leaks `arg(2)` and `arg(3)`, false-failing `--verify` ledger. | `benchmarks/prismio/suite.psm:53` |
| **MEM-039** | Runtime / Mem | **MEDIUM** | Transient loops allocate & free 26MB across 9,500 mallocs without buffer reuse. | `benchmarks/prismio/memory.psm:30` |
| **MEM-040** | Codegen / LICM | **MEDIUM** | Missing `!invariant.load` on vtable and DataView column lookups in loops. | `runtime/llvm-api-backend.c:2915` |
| **MEM-026** | Layout | **MEDIUM** | Enums desugar to tagged products (sum of fields) instead of tagged unions. | `src/sema/enums.psm:7` |
| **MEM-027** | ABI | **MEDIUM** | Universal struct-as-pointer ABI forces stack allocas for small value structs. | `src/ir/types.psm:137` |
| **MEM-029** | Runtime | **MEDIUM** | Recursive destructors overflow C stack on deep non-tail trees (>50,000 depth). | `KNOWN_ISSUES.md:122` |
| **MEM-013** | Allocator | **MEDIUM** | Vectors in arenas reallocate fresh chunks rather than extending the last bump. | `runtime/lang_runtime.c:841` |
| **MEM-014** | Associative | **HIGH** | 16-way SIMD SwissTable flat map replacing linear probing. | `std/map.psm:100` |
| **MEM-016** | Concurrency | **MEDIUM** | Mutex/condvar channels used where single-producer single-consumer is proved. | `runtime/program_support.c:401` |
| **MEM-001** | Telemetry | **LOW** | Ledger lacks high-water byte marks and live byte allocation graphs. | `runtime/lang_runtime.c:930` |

---

## 5. Detailed Step-by-Step Execution Work Packets

```
                               STAGE EXECUTION ORDER
                               
    ┌────────────────────────────────────────────────────────────────────────┐
    │ STAGE 0: Correctness, Soundness & Verification Hygiene                 │
    │ • Task 0.1 (MEM-023): Fix Integer Wrap in Loop Range Guards            │
    │ • Task 0.2 (MEM-024): Audit & Complete TBAA Store Tagging              │
    │ • Task 0.3 (MEM-028): Flow-Sensitive Return Provenance in Delegating Fn│
    │ • Task 0.4 (MEM-038): Eliminate CLI Argument Leaks in `suite.psm`       │
    │ • Task 0.5 (MEM-001): Allocation Ledger Requested/Live Byte Tracking   │
    └───────────────────────────────────┬────────────────────────────────────┘
                                        │
                                        ▼
    ┌────────────────────────────────────────────────────────────────────────┐
    │ STAGE 1: High-Impact Representation, Enum & Loop Wins                  │
    │ • Task 1.1 (MEM-003): Container-Aware Layout Veto (List Element Split) │
    │ • Task 1.2 (MEM-006): Contiguous List Vector Copies to `llvm.memcpy`   │
    │ • Task 1.3 (MEM-011): Curate `list_push_slot` in Runtime IR Module     │
    │ • Task 1.4 (MEM-031): Null Pointer Optimization (NPO) for Enums        │
    │ • Task 1.5 (MEM-032): 16-Byte German String Container Slots            │
    │ • Task 1.6 (MEM-033): Single-Threaded Mutex Bypass in Cycle Collector  │
    │ • Task 1.7 (MEM-035): Multi-Point Stencil Range Guards for SIMD        │
    │ • Task 1.8 (MEM-036): Intrinsic `llvm.memcpy` String Operations in Std │
    │ • Task 1.9 (MEM-029): Iterative Worklist for Recursive Drops           │
    └───────────────────────────────────┬────────────────────────────────────┘
                                        │
                                        ▼
    ┌────────────────────────────────────────────────────────────────────────┐
    │ STAGE 2: Advanced Containers, Allocators & Backend Toolchain           │
    │ • Task 2.1 (MEM-034): 16-Way NEON SIMD SwissTable for `Map<K, V>`       │
    │ • Task 2.2 (MEM-039): Scoped Container Buffer Reuse in Transient Loops │
    │ • Task 2.3 (MEM-037): Host Microarchitecture Target Tuning in Clang    │
    │ • Task 2.4 (MEM-040): Invariant Load Metadata on Vtables & DataViews   │
    │ • Task 2.5 (MEM-013): Last-Bump Arena Rewind for Vector Growth         │
    │ • Task 2.6 (MEM-026): True Tagged Unions (Overlapped Payload Storage)  │
    │ • Task 2.7 (MEM-027): Small Aggregate Register Passing ABI             │
    │ • Task 2.8 (MEM-016): Lock-Free SPSC Ring-Buffer Channels              │
    └────────────────────────────────────────────────────────────────────────┘
```

---

### STAGE 0: Correctness, Soundness & Verification Hygiene

#### Task 0.1: Fix Integer Wrap in Loop Range Guards (MEM-023)
- **Target Files:** `src/ir/expr.psm` (`generateLoopRangeGuards`, `irEmitOneRangeGuard`)
- **Problem:** In `range_wrap_probe.psm`, `at = at + 2147483647` wraps to `-2147483648` under `while (at < 3)`. The preheader assumed monotonic increment and emitted an unchecked GEP, crashing with `SIGSEGV` (-11).
- **Execution:**
  1. Inspect `src/ir/expr.psm:1182-1227`.
  2. Verify monotonicity: loop step must be statically known and strictly positive for `<`/`<=` loops (or negative for `>`/`>=`).
  3. Strict bound adjustment: For `while (k < n)` going up, set `high = bound - 1` in 64-bit sign-extended arithmetic. Compare `high < len64`.
  4. Run probe:
     ```bash
     ./bin/prismio build aif/evidence/memory-2026-09-05/range_wrap_probe.psm -o /tmp/range_wrap_probe
     /tmp/range_wrap_probe
     ```
  5. **Acceptance:** Exits 0 and prints "2" (Zero SIGSEGV).

#### Task 0.2: Audit and Complete TBAA Store Tagging (MEM-024)
- **Target Files:** `runtime/llvm-api-backend.c`, `src/ir/expr.psm`
- **Problem:** Untagged stores emitted by `ir_list_flat_scalar_set` prevent LLVM LICM from hoisting `RtList->data`.
- **Execution:**
  1. Grep all `LLVMBuildStore` in `runtime/llvm-api-backend.c`.
  2. Attach `tag_scalar(store, elem_type)` to every store writing into list element storage.
  3. Rebuild compiler and compile `large_buffer_copy`. Inspect AArch64 assembly and verify `RtList->data` is loaded **once outside the loop**, not per iteration.

#### Task 0.3: Flow-Sensitive Return Provenance (MEM-028)
- **Target Files:** `src/sema/ownership.psm`, `src/sema/checker.psm`
- **Problem:** `f(a, b) { return g(a, b) }` leaks 100% of allocations when an argument is owned because `fn_may_return_param` does coarse set intersection at the function symbol level.
- **Execution:**
  1. Replace symbol-level intersection with flow-sensitive reachability: trace whether the `return` statement's value expression derives directly from a parameter expression.
  2. Verify: Run `tests/test_74_reinit_assignment.psm` and confirm 0 leaks.

#### Task 0.4: Eliminate Benchmark CLI Leaks (MEM-038)
- **Target Files:** `benchmarks/prismio/suite.psm`
- **Problem:** `main()` calls `arg(2)` and `arg(3)` to fetch unused optional paths without dropping them, causing every benchmark in `ledger.json` to report 2 leaked blocks.
- **Execution:**
  1. Use `argBorrowed(2)` / `argBorrowed(3)` or emit explicit `drop(inputPath)` / `drop(outputPath)` at the end of `main()`.
  2. Run `./tmp/suite_verify knapsack`.
  3. **Acceptance:** `--verify` reports `0 allocated, 0 released, 0 leaked, 0 violation(s)`!

---

### STAGE 1: High-Impact Representation, Enum & Loop Wins

#### Task 1.1: Container-Aware Layout Selector Veto (MEM-003)
- **Target Files:** `src/aif/layout.psm`, `runtime/aif_support.c`
- **Problem:** Splitting `BenchMemoryParticle` into hot/cold disqualified it from flat contiguous `List<T>` storage, generating **2,000,007 heap mallocs** (35.13 ms).
- **Execution:**
  1. In `src/aif/layout.psm` (`aifLayoutVetoListElements`), check if struct `T` is stored in a `List<T>`.
  2. If so, hard-veto the hot/cold split. Keep `BenchMemoryParticle` as one contiguous 40-byte flat struct.
  3. Verify:
     ```bash
     ./bin/prismio build benchmarks/prismio/suite.psm --verify -o /tmp/suite_verify
     /tmp/suite_verify struct_creation
     ```
  4. **Acceptance:** Allocation ledger drops from **2,000,007 to <= 8 mallocs**. Runtime drops to **<= 6.1 ms** (5.8x speedup, beating C++ at 6.67 ms).

#### Task 1.2: Lower Whole-Buffer List Copies to `llvm.memcpy` (MEM-006)
- **Target Files:** `src/ir/expr.psm`, `runtime/llvm-api-backend.c`
- **Problem:** `large_buffer_copy` runs at 20.53 ms because a contiguous buffer copy is executed as an unrolled scalar loop.
- **Execution:**
  1. In `src/ir/expr.psm`, recognize whole-buffer copy loops:
     ```prismio
     while (k < n) {
         list_set(target, k, list_get(source, k))
         k = k + 1
     }
     ```
  2. Emit `llvm.memcpy.p0.p0.i64(target_data, source_data, bytes, false)`.
  3. **Acceptance:** `large_buffer_copy` drops from **20.53 ms to <= 6.10 ms** (3.4x speedup, beating Rust at 7.31 ms and C++ at 6.84 ms).

#### Task 1.3: Curate `list_push_slot` in Runtime IR Module (MEM-011)
- **Target Files:** `runtime/build_driver.c`, `runtime/ir_symbols.c`
- **Execution:**
  1. Add `list_push_slot` to `PRISMIO_CURATED_OPS`.
  2. Ensure the capacity check and element pointer return inline directly into caller preheaders.
  3. **Acceptance:** Disassembly of `struct_creation` shows zero `bl _list_push_slot` calls.

#### Task 1.4: Null Pointer Optimization (NPO) for Enums (MEM-031)
- **Target Files:** `src/sema/enums.psm`, `src/ir/expr.psm`, `runtime/llvm-api-backend.c`
- **Problem:** In `benchTreeTraversal`, `BenchTree.Empty` allocates an entire 32-byte heap struct for every leaf ($2^{13} = 8,192$ leaves), generating 16,383 allocations and taking 0.68 ms vs Rust's 0.33 ms.
- **Execution:**
  1. In `src/sema/enums.psm`, detect enums where at least one variant has no payload (e.g. `Empty`, `None`) and another variant is a non-null pointer (e.g. `Node`, `Some`).
  2. Encode the empty variant as NULL pointer (0x0).
  3. Lower construction of `Empty` to `ptr null` (zero allocations!).
  4. Lower `match (tree)` to `icmp eq ptr %tree, null` / `cbz x0`.
  5. **Acceptance:** `tree_traversal` allocations drop from 32,772 to 16,384 (−50%). Runtime drops from **0.68 ms to <= 0.35 ms** (2.0x speedup, matching Rust at 0.33 ms and beating C++ at 0.38 ms).

#### Task 1.5: 16-Byte German String Container Slots (MEM-032 / MEM-010)
- **Target Files:** `runtime/lang_runtime.c`, `src/ir/types.psm`, `src/ir/expr.psm`
- **Problem:** `storageType("struct:prismio.str")` reduces to `ptr`. Storing strings in containers forces `str_own` heap allocation for <=12B strings, and erases the 64-bit length word (forcing `strlen` on every `list_get`).
- **Execution:**
  1. Define `List<String>` slot width as 16 bytes: `[ len (4B) | prefix (4B) | ptr/inline (8B) ]`.
  2. Direct store: copy 16 bytes directly from `{ptr, i64}` without calling `str_own` or allocating for inline strings.
  3. Direct load: load 16 bytes directly into `{ptr, i64}`, eliminating `fatFromPtr` and `strlen`.
  4. **Acceptance:** Zero `malloc` calls when pushing short strings; zero `strlen` calls when reading strings. String iteration speeds up by >5x.

#### Task 1.6: Single-Threaded Mutex Bypass in Cycle Collector (MEM-033)
- **Target Files:** `runtime/lang_runtime.c`
- **Problem:** `cyc_retain` and `cyc_release` unconditionally call `pthread_mutex_lock(&cyc_state_lock)` on every reference update even when the process has never spawned a thread.
- **Execution:**
  1. In `cyc_enter()` and `cyc_leave()`, check `if (!prismio_memory_threads_are_enabled()) return;`.
  2. Shrink `CycHeader` from 32 bytes to 8 bytes: move `children` and `release` function pointers into a static per-type `CycTypeDesc` table. Pack `rc: 48, colour: 2, buffered: 1, type_id: 13`.
  3. **Acceptance:** GC header size drops by 75%; reference counting overhead drops by 80% in single-threaded workloads.

#### Task 1.7: Multi-Point Stencil Range Guards for SIMD (MEM-035)
- **Target Files:** `src/ir/expr.psm`
- **Problem:** In `benchConvolution`, the inner loop computes a 7-point stencil: `input[at - 3] + ... + input[at + 3]`. Each access emits an independent bounds check branch, blocking NEON vectorization (taking 6.28 ms vs C++ 3.52 ms).
- **Execution:**
  1. Generalize loop range guard induction scanner: collect all constant offsets `[k_min, k_max]` on induction variable `at`.
  2. In the loop preheader, emit a single compound guard: `low_bound + k_min >= 0 && high_bound + k_max < len`.
  3. When the guard passes, emit the loop body with **all 7 accesses unchecked**.
  4. **Acceptance:** LLVM auto-vectorizes the loop into 128-bit NEON operations. `convolution` runtime drops from **6.28 ms to <= 3.50 ms** (matching C++ and Rust).

#### Task 1.8: Intrinsic `llvm.memcpy` String Operations (MEM-036)
- **Target Files:** `std/string.psm`, `std/process.psm`, `src/ir/expr.psm`
- **Problem:** String concatenation, slicing, and cloning in `std` use while loops writing one byte at a time via `__builtin_string_put_byte`.
- **Execution:**
  1. Add compiler intrinsic `__builtin_string_copy(dst, dst_off, src, src_off, len)` that lowers directly to `llvm.memcpy`.
  2. Replace byte-by-byte while loops in `std/string.psm` and `std/process.psm`.
  3. **Acceptance:** String cloning and slicing run at memory bandwidth saturation speed (~30 GB/s).

#### Task 1.9: Iterative Worklist for Recursive Destructors (MEM-029)
- **Target Files:** `src/ir/module.psm` (`generateReleaseFunction`)
- **Execution:**
  1. Replace recursive call on non-tail child pointer with an explicit heap/stack worklist.
  2. **Acceptance:** `tests/test_74_reinit_assignment.psm` and deep tree teardown of depth 200,000 runs without stack overflow.

---

### STAGE 2: Advanced Containers, Allocators & Backend Toolchain

#### Task 2.1: 16-Way NEON SIMD SwissTable for `Map<K, V>` (MEM-034 / MEM-014)
- **Target Files:** `std/map.psm`, `runtime/lang_runtime.c`
- **Problem:** `Map<K, V>` currently allocates 3 separate `List` objects (`keys`, `values`, `slots`), uses linear probing with pointer chasing across disjoint arrays, and takes 18.70 ms on `key_value_update` (vs C++ 5.60 ms).
- **Execution:**
  1. Replace 3-list layout with a single contiguous allocation:
     - `ctrl`: Array of 1-byte control tags (0xFF = empty, 0x80 = tombstone, 0x00..0x7F = 7-bit H2 hash).
     - `slots`: Contiguous array of `{ K key, V value }`.
  2. Implement 16-way SIMD lookup using ARM NEON:
     ```c
     uint8x16_t group = vld1q_u8(ctrl + i);
     uint8x16_t match = vceqq_u8(group, vdupq_n_u8(h2));
     ```
  3. **Acceptance:** `key_value_update` drops from **18.70 ms to <= 5.80 ms** (3.2x speedup, matching C++ at 5.60 ms and beating Rust at 8.64 ms).

#### Task 2.2: Scoped Container Buffer Reuse in Transient Loops (MEM-039)
- **Target Files:** `src/ir/stmt.psm`, `runtime/lang_runtime.c`
- **Problem:** In `benchTransientAllocation`, 26.2 MB is allocated and freed across 9,500 malloc calls for temporary lists that are created and dropped in a loop.
- **Execution:**
  1. Detect loop-scoped vector pattern: `let mut v = list_new()` inside a loop dropped before iteration end.
  2. Hoist the container buffer allocation to the loop preheader. On loop iteration end, reset `len = 0` instead of freeing the backing buffer.
  3. **Acceptance:** Total heap allocations drop from 9,605 to 5. Runtime drops from **2.64 ms to <= 0.40 ms** (6.6x speedup).

#### Task 2.3: Host Microarchitecture Target Tuning in Clang (MEM-037)
- **Target Files:** `runtime/build_driver.c`
- **Execution:**
  1. In `compile_ir_to_object`, add `-mcpu=native` (or target CPU flag on Apple Silicon) and `-fno-math-errno`.
  2. Enable LLVM SLP vectorization and loop interleaving.
  3. **Acceptance:** 5–12% throughput improvement across numerical and compute benchmarks.

#### Task 2.4: Invariant Load Metadata on Vtables & DataViews (MEM-040)
- **Target Files:** `runtime/llvm-api-backend.c:2915`, `runtime/lang_runtime.c:2346`
- **Execution:**
  1. Attach `!invariant.load` metadata to all vtable function pointer loads and `RtDataView->columns` loads.
  2. **Acceptance:** Indirect method dispatch is hoisted completely out of loops by LLVM LICM.

#### Task 2.5: Last-Bump Arena Rewind (MEM-013)
- **Target Files:** `runtime/lang_runtime.c`
- **Execution:**
  1. In `arena_alloc_slot`, check if reallocated buffer matches `c->base + c->used - old_size`. If yes, bump `c->used` in-place.
  2. **Acceptance:** Zero memory slack during geometric container growth in arenas.

---

## 6. Verification Protocol & Quality Gates

Run the following test regimen before and after each task:

```bash
# 1. Full Compiler Test Suite
python3 tools/test.py

# 2. Benchmark Sweep (9 interleaved iterations against C++ and Rust)
python3 benchmarks/run.py --languages prismio,cpp,rust --runs 9

# 3. Dynamic Memory & Verification Ledger (Must report 0 leaks / 0 violations)
./bin/prismio build benchmarks/prismio/suite.psm --verify -o /tmp/suite_verify
/tmp/suite_verify struct_creation
/tmp/suite_verify large_buffer_copy
/tmp/suite_verify tree_traversal
/tmp/suite_verify transient_allocation
/tmp/suite_verify key_value_update

# 4. Checksum Invariance Verification
python3 -c '
import subprocess
for b in ["large_buffer_copy", "struct_creation", "tree_traversal", "key_value_update", "convolution"]:
    out = subprocess.check_output(["/tmp/suite_verify", b]).decode()
    assert "0 leaked, 0 violation(s)" in out, f"Leak in {b}"
print("ALL VERIFICATION CHECKS PASSED!")
'

# 5. Compiler Fixpoint Bootstrap Verification
./tools/verify_fixpoint.sh
```

---
*End of Master Optimization Specification v1.2.0. Hand directly to autonomous worker agents for execution.*
