# Prismio structural-gap and performance handoff

**Prepared:** 2026-08-30  
**Repository:** `/Users/vibrant/Desktop/Projects/Prismio/prismio`  
**Target:** make Prismio's natural and tuned programs consistently match or beat
equivalent Rust programs without weakening ownership, representation, or checksum
correctness.

This document is the starting brief for the next AI session. It separates
compiler/runtime gaps from benchmark source-algorithm gaps because treating them
as one problem has repeatedly produced attractive but false explanations.

## The two standing rules

These come before the priority map, and they are not negotiable per-session
preferences — they are how this work is done here.

### 1 · Research discipline: read before you measure

**The order is: our model, then Rust's model, then the literature, then a
hypothesis, then one experiment.** Not: guess, build a probe, measure, repeat.

Concretely, for any gap:

1. Read what Prismio does — the runtime function, the lowering, the AIF fact.
   Ask the compiler (`aif --summary`, `--layout`, `--why`) rather than inferring.
2. Read what Rust does for the *same* program — `aif/evidence/xlang/rust/` has
   the counterpart of every benchmark, and `rustc -C opt-level=3` plus `objdump`
   gives you its loop. **Put the two loop bodies side by side.** Nearly every
   real finding in this file came from that and from nothing else.
3. Search for current work on the mechanism. The reference implementation is
   often already documented — Rust's `RawVec::NEW` allocating nothing until the
   first push, Perceus's reuse analysis, LLVM's loop versioning, static memory
   planning's liveness-plus-interference buffer assignment.
4. *Then* form one hypothesis with a stated mechanism, and test that.

The session that wrote this rule burned three compiler builds refuting
hypotheses — condvar wake-up latency on g9, the layout cost model on g5, buffer
growth policy on g2 — that ten minutes of reading would have killed for free.
It also found the two real defects (the eagerly-allocated `list_new` block, the
`bl _list_push_slot` in g2's loop) in the first ten minutes of actually reading
Rust's output next to ours.

**A probe is for confirming a mechanism you can already name.** If you cannot
say *why* a change should help before you build it, do not build it.

### 2 · The first goal is tuned-to-tuned parity

**Hand-tuned Prismio should match hand-tuned Rust, and that comparison is the
ceiling.** When a human has written the best algorithm in both languages, the
remaining difference is the compiler and the runtime and nothing else — no
source-algorithm gap left to blame. Natural-vs-idiomatic is a softer number
because it mixes in what the language makes convenient.

So read the **tuned** rows of `tools/five_arm_bench.py` first, and treat the
tuned ratio as the target. As of the run that wrote this:

| workload | Prismio tuned / Rust tuned |
|---|---:|
| g1 | **1.01x** — matched, and proof the bar is reachable |
| g2 | 1.08x |
| g3 | 1.13x |
| g9 | 1.13x |
| g4 | 1.16x |
| g6 | **1.49x** |
| g5 | **1.87x** |

g1 already meets the bar. g5 and g6 are where the compiler is actually losing,
and they are where to work. A change that improves a natural arm while leaving a
tuned arm behind has not moved the ceiling.

**Corollary, learned the hard way twice:** run the five-arm and read the tuned
rows after *every* change. `milestone_bench.py` and `release_gate.sh` build only
the natural programs, so a tuned-only regression passes both — a 46% regression
on `g4_tuned` and a 27% regression on `g6` both reached a green gate this way.
`release_gate.sh` now mnemonic-diffs the tuned arms as well, which catches the
shape of such a change but not its cost.

## Read this first

1. Read `CLAUDE.md`, `CODE_STYLE.md`, and `C_CODE_STYLE.md` before editing.
2. Use Graphify first for codebase questions, as required by `CLAUDE.md`.
3. Read `KNOWN_ISSUES.md` and
   `aif/evidence/RESULTS-loop-unswitch.md` before choosing a change.
4. Preserve the current worktree. At handoff it contains:

   ```text
    M KNOWN_ISSUES.md
    M aif/evidence/README.md
    M runtime/build_driver.c
    M runtime/embedded_sources.h
   ?? aif/evidence/RESULTS-loop-unswitch.md
   ```

   These are the accepted loop-unswitch experiment and its evidence. Do not
   reset, discard, or overwrite them. Inspect the diff and build on it.
5. Do one bounded hypothesis at a time. Record rejected experiments as well as
   wins. Do not make a performance claim from fewer than 25 balanced runs.

## Where the hand-tuned controls are

The five-arm harness is `tools/five_arm_bench.py`. It deliberately builds all of
these in one balanced rotation and checks that their checksums agree.

- Natural Prismio: `aif/evidence/xlang/prismio/g1.psm` through `g9.psm`
  (the measured set is g1, g2, g3, g4, g5, g6, and g9).
- Hand-tuned Prismio: `aif/evidence/xlang/prismio/g*_tuned.psm`.
- The g1 expert arm is `aif/evidence/xlang/prismio/g1_dataview_tuned.psm`.
- Idiomatic Rust: `aif/evidence/xlang/rust/g*_idiomatic.rs`.
- Hand-tuned Rust: `aif/evidence/xlang/rust/g*_tuned.rs`.

Do not compare a natural source in one language to a tuned source in the other.
The useful comparisons are natural/idiomatic, tuned/tuned, and old/new for the
same Prismio source.

## Current measured position

LLVM 22.1.8, Apple Silicon, 25-run balanced five-arm measurement after enabling
non-trivial loop unswitching in optimized program builds:

| workload | Prismio natural | Rust idiomatic | P/R | Prismio tuned | Rust tuned | P/R |
|---|---:|---:|---:|---:|---:|---:|
| g1 | 19.389 ms | 18.549 ms | 1.05x | 4.636 ms | 4.681 ms | **0.99x** |
| g2 | 27.809 ms | 18.189 ms | 1.53x | 11.989 ms | 10.169 ms | 1.18x |
| g3 | 44.041 ms | 45.241 ms | **0.97x** | 34.825 ms | 30.327 ms | 1.15x |
| g4 | 29.393 ms | 21.700 ms | 1.35x | 20.539 ms | 17.733 ms | 1.16x |
| g5 | 34.270 ms | 30.301 ms | 1.13x | 7.949 ms | 4.346 ms | 1.83x |
| g6 | 88.423 ms | 54.868 ms | 1.61x | 65.758 ms | 40.635 ms | 1.62x |
| g9 | 99.947 ms | 110.284 ms | **0.91x** | 74.509 ms | 70.077 ms | 1.06x |

Interpretation:

- g1's compiler-supported DataView path is already at tuned-Rust parity.
- g3 natural already beats idiomatic Rust. Its tuned gap is small enough that a
  global representation rewrite is not justified.
- g4 has a real compiler optimization-exposure gap. Loop unswitching improved
  natural g4 by 11--14%, but Rust still has a monomorphic loop and the tuned Rust
  program also fuses systems.
- g9 natural beats idiomatic Rust; the remaining tuned gap is a narrow runtime
  channel-topology problem.
- g2, g5, and g6 are dominated by buffer lifetime and program transformations,
  not by a single allocator or ownership-classification mistake.
- g5 is too noisy for ordinary A/B attribution. Its A/A calibration has produced
  a false 1.266x regression. Inspect machine code before believing its timing.

The direct old/new hand-tuned ratios for the unswitch change were neutral at the
median: g1 1.001x, g2 0.998x, g3 0.999x, g4 1.012x, g5 0.958x, g6 0.977x, and
g9 0.984x. The compiler change exposed a missed natural loop; it did not erase
source-algorithm gaps.

## Priority map

| priority | structural gap | why it matters | first bounded deliverable |
|---|---|---|---|
| P0 | Owned temporaries crossing `spawn` can leak | correctness precedes aggressive reuse | owner/release fact and regression for `spawn f(g(x))` |
| P0 | `extern alias` pass-through and overly broad pointer-return withholding | blocks sound ownership/reuse decisions | per-argument return-alias fact with tests |
| P1 | Flat-list representation branch remains in hot loops | direct, robust g4 opportunity | one guarded flat-list loop view in Prismio IR |
| P1 | General MPMC channel used for statically SPSC endpoints | explains most remaining tuned g9 gap | bounded SPSC runtime path selected from endpoint facts |
| P1 | Hotness information reaches layout but not LLVM optimization | global unswitch pays compile/code-size cost broadly | g4-only LLVM instrumentation-PGO prototype |
| P2 | No conservative loop fusion/bufferization pass | tuned g4/g5/g6 win by doing less work | fuse one proven-safe g4 loop pair |
| P2 | Destructure/rebuild has no reset/reuse token | g8 is the real functional-update trigger | frame-limited same-size reuse on unique g8 path |
| P2 | Temporary allocation extents stop at coarse regions/FFI | g2 retains repeated buffer allocation patterns | non-lexical sub-block extent probe |
| P3 | Recursive ADTs stay pointer-chasing layouts | future g3/g8 traversal ceiling | factored-layout prototype only after ownership is sound |
| P3 | DataView choice is not a stable source/annotation contract | automatic cost model can mispredict | explicit `soa`/DataView policy and diagnostics |
| P3 | Curated functions cannot carry private constants | blocks safe runtime curation/debugging | copy constant dependency closure or decline curation |
| P4 | Windows self-host exports and wasm runtime absent | portability, not current Rust benchmark gap | implement only on a verifiable target runner |

## Gap 1: sound owner facts at calls, `spawn`, and FFI

### Evidence and root cause

- `spawn f(g(x))` loses the ordinary call's argument-position release, so the
  owned temporary returned by `g` has no owner.
- Ordinary argument-position release is conservatively withheld whenever the
  enclosing call returns a pointer, even if that result cannot alias the
  argument.
- Prismio pass-through facts cover Prismio callees but not an `extern` declared
  `alias` that returns its argument.
- UMS resolution allocates internal facts without releasing them.

These gaps force later reuse/region work either to leak or to retain values too
long. Fix them before adding ownership-driven reuse.

### Solution

Model ownership transfer per call argument and per return path, rather than by
the return's broad pointer kind. A call fact needs to answer:

```text
argument i is borrowed | consumed | escaped | may be returned as result
```

Propagate the same fact through the `spawn` lowering. For `extern alias`, make
the declared alias contract produce the same return-alias relation as a Prismio
callee. Do not infer a foreign alias relation that was not declared.

### First slice and gate

1. Add focused corpus/tests for `spawn f(g(x))`, an owned direct spawn argument,
   a pointer-returning callee that does not return its argument, and a declared
   `extern alias` pass-through.
2. Emit a release exactly once on each non-escaping path.
3. Run ordinary, `--verify`, AIF differential, and ASan/LSan variants.
4. Require no change to unrelated AIF ownership reports.

Read: `KNOWN_ISSUES.md`, `src/sema/ownership.psm`, `src/ir/stmt.psm`,
`src/aif/contracts.psm`, `runtime/aif_support.c`, and the concurrency evidence.

## Gap 2: flat-list representation is resolved once per element

### Evidence and root cause

`List<T>` supports inline flat elements and boxed elements. `list_get_inline` in
`runtime/lang_runtime.c` tests `elem_size` and chooses:

```text
inline: data + index * elem_size
boxed:  data[index]
```

LLVM hoists the header loads but normally leaves this invariant choice inside
the loop. Rust's specialized `Vec<T>` has no equivalent mode branch. Enabling
LLVM 22's non-trivial loop unswitch clones the loop and improves g4 by 11--14%,
proving the missing optimization. It also adds about 6 ms to g4's program `-O2`
stage and 16 KiB to g2/g4 binaries, so a global backend switch is a useful
stopgap rather than the final container design.

### Solution

Add a typed flat-list loop view in Prismio IR:

```text
(base pointer, logical length, element stride, representation guard)
```

For a loop-invariant `List<T>` receiver, guard `elem_size != 0` once before the
loop. Lower the inline fast loop to direct GEPs from stable `base` and `stride`.
Keep a complete boxed fallback loop. The optimization must decline if the loop
can mutate/reallocate the list header, if identity semantics require boxed
elements, or if the receiver is not loop-invariant.

This is loop versioning in Prismio's typed IR, not a global promise that every
list is flat.

### First slice and gate

Implement only read/write indexing of one loop-invariant `List<Struct>` in g4.
Do not begin with generic nested lists, calls that can mutate the receiver, or
multiple aliases.

Acceptance criteria:

- boxed fallback remains and tests also pass with `PRISMIO_INLINE_ELEMS=0`;
- the flat loop's machine code has no per-iteration `elem_size` branch;
- checksum, verifier, suite, and ASan results are unchanged;
- natural g4 retains at least an 8% improvement over the pre-unswitch compiler;
- g2 does not regress by more than 3%; corpus median new/old is at most 1.03x;
- compile-time/code-size are reported, not hidden.

Read first: `src/ir/expr.psm` (list index lowering), `src/ir/stmt.psm` (loop
lowering), `src/ir/module.psm`, `runtime/lang_runtime.c` (`list_get_inline`),
`runtime/llvm-api-backend.c`, and
`aif/evidence/RESULTS-curate-list-get-inline.md`.

Do not:

- delete the boxed fallback;
- attach `!invariant.load` to the list header globally (`list_push` rewrites it);
- treat `noalias` on constructors as a substitute (it changed IR but not g2
  machine code);
- globally internalize all Prismio functions (measured corpus median 1.038x,
  g6 1.225x regression).

Research basis: LLVM's
[loop-versioning implementation](https://llvm.org/doxygen/LoopVersioningLICM_8cpp_source.html),
[loop vectorizer](https://llvm.org/docs/Vectorizers.html), and
[VPlan design](https://llvm.org/docs/VectorizationPlan.html).

## Gap 3: measured workloads do not guide LLVM optimization

### Evidence and root cause

Prismio already runs declared workloads and feeds a measured profile into AIF
layout selection. That profile contains layout/access facts, not LLVM edge and
value counts. Consequently, LLVM must make global unswitch/inlining decisions
without observed hotness. Global unswitching found g4, but also paid compile and
code-size costs where the clone did not help.

### Solution

Add a separate, optional LLVM instrumentation-PGO path:

1. emit an instrumented optimized program;
2. run the declared workload in the same isolated way as the layout profiler;
3. merge `.profraw` into `.profdata`;
4. rebuild using the profile;
5. include compiler version, target, source hash, workload identity, and profile
   mode in cache keys/manifests;
6. keep the reproducible non-PGO build as the default until the gate is stable.

Do not mix the AIF layout profile format with LLVM's profile. They have different
semantics and invalidation rules.

### First slice and gate

Prototype g4 only, behind an explicit flag. Compare ordinary `-O2`, current
global unswitch, and LLVM-PGO plus ordinary optimization. A successful slice:

- retains g4's >=8% win;
- avoids unnecessary g2 loop cloning/code growth;
- keeps corpus median <=1.03x and program compile-time overhead <=10%;
- invalidates stale/mismatched profiles with a clear diagnostic;
- produces behaviorally identical output with and without a profile.

Research basis: the official
[rustc PGO guide](https://rustc-dev-guide.rust-lang.org/profile-guided-optimization.html)
and [LLVM PGO documentation](https://llvm.org/docs/HowToBuildWithPGO.html).

## Gap 4: channel runtime ignores endpoint topology

### Evidence and root cause

The tuned g9 programs in both languages already use persistent workers. Prismio
is only about 1.06x slower than tuned Rust, but each job channel still uses a
general mutex/condition-variable MPMC queue and heap-object messages even when
static analysis can prove one producer and one consumer. `Channel<Int>` is also
currently rejected because channels use optional references for closure/empty
signaling.

### Solution

Teach AIF/sema to classify endpoint multiplicity from channel creation, sharing,
capture, and `chan_share`:

```text
SPSC | MPSC | SPMC | MPMC | unknown
```

Select a bounded SPSC ring for proven SPSC job channels. Use atomic head/tail
indices with the minimum acquire/release ordering needed by the queue; preserve
blocking, close, and drain semantics. Keep the existing MPMC implementation as
the fallback. A second slice may inline scalar payloads or use an explicit tagged
optional representation so `Channel<Int>` need not box.

### First slice and gate

Specialize only g9's one-producer/one-consumer job channels; leave the shared
result channel general. Require:

- tuned Prismio g9 at or below 1.00x tuned Rust on the balanced harness, or a
  clearly reproduced >=5% improvement if the host noise prevents parity;
- ThreadSanitizer clean runs;
- close-before-send, close-after-send, drain, empty, full, and spurious-wakeup
  tests;
- ownership moves exactly once and no message leaks;
- unknown or shared topology keeps the existing MPMC path.

Read: `runtime/program_support.c` (channel implementation),
`src/sema/builtins.psm`, `src/ast/types.psm`, `src/aif/contracts.psm`,
`aif/evidence/RESULTS-v01-channels.md`, `aif/evidence/RESULTS-concurrency.md`, and
`aif/evidence/xlang/prismio/g9_tuned.psm`.

## Gap 5: no conservative loop fusion or bufferization

### Evidence and root cause

The tuned programs change algorithms:

- g4 fuses four elementwise systems;
- g5 precomputes CSR-like material buckets;
- g6 reuses/resets worlds and buffers.

These wins are not consequences of stack-vs-heap placement. Automatic layout or
reference-counting changes cannot remove entire passes over data.

### Solution

Start with conservative adjacent-loop fusion. Fuse loops only when they have the
same bounds and step, no early exit, no opaque calls, and a dependence proof that
rules out cross-iteration hazards. A small analysis should classify each memory
access by base object, field/path, index expression, and read/write effect.

Add bufferization separately: a capacity-preserving `list_clear`/reset operation
with a precisely specified live length and ownership effect lets code reuse
storage without keeping old elements alive. Automatic hoisting is permitted only
when lifetime/effect facts prove equivalence.

Treat g5's material bucketing as an explicit library/compiler API or an
annotation/profile-guided transformation, not an automatic side effect of
layout. Treat g6's world reset as semantic program restructuring; never infer it
blindly.

### First slice and gate

Fuse one adjacent g4 loop pair, then extend only after the corpus is green.
Require identical checksums, verifier/ASan success, no extra allocations, a
visible reduction in loop count in IR/machine code, and a reproduced speedup.

Do not edit the natural benchmark to claim a compiler win. The source-tuned arm
exists specifically to price manual transformations.

## Gap 6: functional-update reuse is not represented

### Evidence and root cause

`g8_tree_rebuild.psm` is the real destructure/rebuild trigger. A consuming match
destroys a constructor and creates another of the same size, but Prismio has no
reset/reuse token connecting those events. Existing `field_release_of` facts are
per `(type, field)` and do not answer the necessary per-site question. Ownership
transfer also needs to survive more than one return hop before reuse is safe.

This mechanism does **not** solve g2/g6: their buffers are cross-call and
cross-iteration, not same-branch constructor replacement.

### Solution

Implement Perceus-style reset/reuse on a consuming payload match:

1. when a constructor is uniquely owned, destructuring can produce a reuse token
   after releasing its owned fields;
2. a same-size constructor in the same control-flow branch may consume it;
3. a shared value follows the ordinary allocate path;
4. tokens are frame-limited and cannot be retained without bound;
5. each token is consumed at most once and never crosses an opaque call.

### First slice and gate

Target only the unique-path same-tag/same-size rebuild in g8. The checksum must
remain `528891`; allocations should fall from nodes-times-passes toward nodes;
the shared path must still allocate; verifier, ASan, and the full corpus must be
clean.

Read: `aif/evidence/RESULTS-M2-reassignment.md`,
`aif/evidence/RESULTS-M2-recursive-release.md`, `src/ir/stmt.psm` match lowering,
enum construction, and `runtime/aif_support.c` around `field_release_of`.

Research basis: [Perceus](https://xnning.github.io/papers/perceus.pdf),
[Lean's functional but in-place compilation](https://www.microsoft.com/en-us/research/wp-content/uploads/2019/09/perceus.pdf),
and [frame-limited reuse](https://www.microsoft.com/en-us/research/wp-content/uploads/2021/11/flreuse-tr.pdf).

## Gap 7: temporary allocation extents are still coarse

### Evidence and root cause

Non-lexical extents have partly shipped, but caller/callee region polymorphism
and opaque FFI effects remain barriers. g2's timing extern inside its loop makes
whole-loop region inference unsafe even when a smaller allocation-only sub-block
could have a bounded extent.

### Solution

Infer the smallest sub-block whose allocations share an exit set, and split the
region before/after opaque externs. Add explicit effect summaries for calls that
cannot retain region pointers. Sized-allocation facts can reserve an appropriate
chunk without changing escape semantics.

### First slice and gate

Create a focused probe with a temporary aggregate on both sides of an opaque
call. Prove that only the safe sub-block becomes a region. Then price it on g2
without editing the benchmark source. Require unchanged peak liveness, no pointer
escaping the region, and ASan/verify success.

Research basis: [Spegion](https://arxiv.org/pdf/2506.02182), particularly its
sized allocation, effects, and splittable-region design.

## Gap 8: recursive data remains pointer chasing

### Evidence and root cause

Recursive enums use conventional per-node object layouts. That is simple and
sound but limits traversal locality for tree-heavy g3/g8-like programs.

### Solution

After owner/reuse facts are sound, prototype a factored recursive layout:
separate tag and payload-field buffers with stable cursors/indices and retain a
boxed fallback at ABI/identity boundaries. Selection must be explicit or
profile-guided because update-heavy and identity-sensitive structures may lose.

This is P3, not a substitute for fixing ownership. Build a dedicated recursive
traversal/update benchmark before touching g3/g8 baselines.

Research basis: the May 2026
[SoCal factored recursive-layout work](https://arxiv.org/pdf/2605.01140), which
reports a 1.46x geometric-mean traversal improvement on its evaluated workloads.

## Gap 9: DataView policy and automatic layout selection

### Evidence and root cause

The g1 DataView result is already good: tuned Prismio slightly beats tuned Rust.
The remaining structural issue is choosing AoS, SoA, or a view predictably.
Earlier unconstrained cost-model attempts mispredicted, while explicit DataView
conversion was measurable and explainable.

### Solution

Prefer an explicit `soa`/DataView source or annotation contract, with
workload-guided diagnostics that suggest conversion. A later conservative pass
may fission loops when fields are disjoint and conversion cost is amortized, but
it should never silently change identity/extern behavior.

Research basis: 2025
[annotation-guided AoS-to-SoA data views](https://arxiv.org/pdf/2502.16517).

Read: `aif/evidence/RESULTS-M4-dataview-c.md`, `src/aif/layout.psm`, DataView
lowering in `src/ir/stmt.psm`, and DataView metadata in
`runtime/llvm-api-backend.c`.

## Gap 10: runtime curation has an incomplete dependency closure

### Evidence and root cause

`ir_curate_module` copies selected function bodies into the user's module as
`available_externally`, but does not copy referenced private string constants.
Adding a string literal to a curated function produces an undefined `_.str.*`
symbol at link time. `list_push_slot` is also outside the curated set because it
reaches three static objects.

### Solution

Compute and copy the transitive constant/global dependency closure for a curated
function, remapping private names per module. If the closure contains an
unsupported initializer or mutable private state, decline curation with a clear
reason and keep the external call.

Do not curate `list_push_slot` solely for performance. That experiment measured
a 0.998x corpus median with no durable win. It remains relevant only if a future
struct-path TBAA change has a machine-code and benchmark proof.

Read: `runtime/build_driver.c`, `runtime/ir_symbols.c`,
`aif/evidence/RESULTS-M6-struct-path-tbaa.md`, and
`aif/evidence/RESULTS-curate-list-get-inline.md`.

## Other product gaps, not current performance priorities

These should remain visible but should not distract the next performance
session:

- A self-hosted Windows compiler has no export table. `--target` and the std-fs
  test also need a real Windows runner.
- wasm32 IR emission exists, but `wasm32-unknown-unknown` has no shipped Prismio
  C runtime archive.
- Resolved path dependencies are not included in import search.
- Explicit `wrapping_*`, `checked_*`, and `saturating_*` integer intent forms do
  not exist.
- `Char` is one byte, not a Unicode scalar; there is no interpolation or iterator
  protocol.
- UMS resolution has an allocation-hygiene leak that needs owners enumerated
  before widening any release clause.

## Recommended execution order

If the next session can do only one performance task, do the typed flat-list
loop-view prototype on g4. It has the cleanest causal evidence and a robust
existing win to preserve.

For a longer sequence:

1. Close the P0 call/`spawn`/FFI ownership facts.
2. Replace reliance on global unswitch with the typed flat-list loop view.
3. Specialize proven-SPSC g9 channels.
4. Prototype LLVM PGO and decide whether it can target unswitch/inlining without
   broad code growth.
5. Add one conservative g4 loop-fusion case.
6. Add reset/reuse on g8, then revisit recursive layouts.
7. Investigate region sub-blocks and bufferization for g2/g6.
8. Keep g5's partitioning explicit until its measurement noise and dependence
   requirements are understood.

Do not start with a new allocator, blanket LTO/internalization, global noalias,
or automatic AoS-to-SoA conversion. Existing measurements do not support them.

## Verification protocol

Use the configured LLVM 22 toolchain from `third_party/llvm-paths.json` (or the
repository's documented `PRISMIO_LLVM_DIR`). Keep toolchain and thermal state
stable during A/B runs.

After any edit to `runtime/*.c`, regenerate embedded sources:

```sh
python3 runtime/generate_embedded_sources.py
python3 tools/check_source_lists.py
```

Build through a fixed point, not just one generation:

```sh
bash tools/bootstrap.sh --compiler build/unswitch-gen4 --out build/next-gen1
bash tools/bootstrap.sh --compiler build/next-gen1 --out build/next-gen2
bash tools/bootstrap.sh --compiler build/next-gen2 --out build/next-gen3
```

Compare the compiler IR produced by generations 2 and 3 using the same method as
the existing bootstrap evidence; do not accept a source-only bootstrap.

Run correctness gates before benchmarks:

```sh
PRISMIO=build/next-gen3 python3 tests/test_runner.py
python3 tools/aif_differential.py --compiler build/next-gen3
bash tools/release_gate.sh --rc build/next-gen3 --old build/unswitch-gen4
git diff --check
```

Then calibrate and measure:

```sh
python3 tools/milestone_bench.py --old build/unswitch-gen4 --new build/next-gen3 --runs 25 --label structural-gap
python3 tools/five_arm_bench.py --old build/unswitch-gen4 --new build/next-gen3 --runs 25 --label structural-gap --json /tmp/prismio-structural-gap-five-arm.json
```

For g5, first run:

```sh
python3 tools/milestone_bench.py --old build/unswitch-gen4 --new build/next-gen3 --calibrate --only g5 --skip-baselines
```

For any surprising single-program result, use
`tools/fn_mnemonic_diff.py` to establish whether relevant machine code changed.
Record exact commands, compiler checksum, LLVM version, raw JSON path, medians,
checksum results, compile time, and executable size in a new
`aif/evidence/RESULTS-*.md` file.

## Decision rules for the next AI

- Preserve semantics first: a boxed fallback, shared-owner path, MPMC fallback,
  or non-PGO build is part of the feature, not cleanup to remove later.
- A benchmark speedup is not an ownership proof. Use verifier, differential,
  sanitizer, and focused negative tests.
- A changed LLVM IR is not a performance result. Inspect machine code and run a
  balanced A/B.
- Reject a change if the corpus median regresses beyond 1.03x unless a documented
  target win is large, robust, and explicitly accepted with its cost.
- Do not use g5 alone to accept or reject a change.
- Keep natural and hand-tuned sources separate. Compiler transformations must
  improve the unchanged natural source; source algorithms belong in tuned arms.
- Update `KNOWN_ISSUES.md` when a structural gap is closed or a new limitation is
  found, and link the evidence from `aif/evidence/README.md`.
