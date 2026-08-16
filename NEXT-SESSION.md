# Prompts for the next sessions

**Both prompts have been run, in parallel, in separate trees, and merged.** Prompt 1 (arena
call-site placement) landed in full: `region` is no longer inert on `g2_region.psm`, which serves
**10 200 000 of 10 201 215** allocations against 0, measured at **0.332×** whole-program. Prompt 2
(layout) landed items 2 and 4 and **deliberately did not start item 1, the hot/cold split** — the
prize, and now the single largest piece of unbuilt work in the tree.

**Read the merged-state warning in "The last-good generation" at the foot of this file before you
quote any number.** The two sessions verified against half a tree each; only `build/mg3` has seen
both changes, and the per-session generations they name (`build/v4`, `build/M4`) do not exist here.

Everything left from both prompts is consolidated into the single prompt below. The two residual
prompts further down are kept because they carry worked-out designs that **must not be re-derived**
— but their "state inherited" paragraphs are pre-merge and are superseded by this one.

---

# The prompt for the next session

Copy the block below.

---

Continue the Prismio work. Read, and do not re-derive: `HANDOFF.md` from "Session of 2026-08-16
(second)" and "Session of 2026-08-16 (layout)", `aif/evidence/RESULTS-arena.md` §9,
`aif/evidence/RESULTS-layout.md` §2 and §5, **SPEC 5.2.1.1** and **LAYOUT §5.2.1**. The two residual
prompts in `NEXT-SESSION.md` carry the designs for tasks 1 and 2 below in full.

**Run the tools before reading source, and against `build/mg3`** — not `build/v4`, not `build/M4`,
neither of which exists, and not either tool's own default, which are stale (`build/gen2`) or absent
(`build/aif2.exe`). Two sessions have now opened against a stale binary and misread the result.

```bash
python3 aif/evidence/arena_census.py --compiler build/mg3      # whole corpus, two tables
build/mg3 aif <file> --why=<symbol>                            # one site, every blocker + verdict
build/mg3 aif <file> --layout                                  # ranked layout candidates per type
python3 tools/ir_snapshot.py --compiler build/mg3 --out /tmp/ir # all three program trees
```

**State inherited, all verified on the merged tree — this supersedes both residual prompts.** Suite
**111/111**; warm fixpoint `mg2 == mg3`; cold fixpoint `mcold1 == mcold2`; **cold == warm**
byte-identical on all **87** compilable programs; cold start from the committed seed works and the
seed still parses `src/`; oracle agrees on **15** sources; `--verify` `released`/`violation(s)`
identical to the pre-merge baseline on every corpus program except `g2_region` (which falls by
exactly 10 200 000, because `arena_alloc` bypasses the ledger by design), with **0** violations
everywhere. Census: 40 of 234 sites arena-served, 2 by a bracketed call, **PLACEABLE 0**.

## The tasks, ranked

1. **The hot/cold split — the prize, and the reason this session exists.** Measured **0.87×** on g1's
   shape, and the cost model independently selects exactly that cut (`split 8/12`). *Do the release
   half or don't start* — the failure mode is a leak on the good path and a double free on the bad
   one. The residual prompt "Prompt 2 (residual)" below has the four worked-out pieces: the transform
   is contained at `ir_struct_field_ptr`, the release half is one clause (force `aif_type_releases(T)`
   for split `T`), T3's fix has room already in `RC_HDR`'s spare word, and field 0 stays hot.
   **Expect the self-host to be the hard part**: 13 of 16 types in `src/` have an admissible cut,
   `ASTNode` among them, so the first splitting generation is a compiler whose own AST is split.
   Budget a seed refresh and a cold start, and keep `build/mg3` and `build/mcold2` untouched — a
   broken compiler can be unable to build the fix to its own bug.

2. **`pin(<region-name>)`.** Deferred until placement landed, and it has. Regime (a) means **a second
   call to a bracketed callee silently removes the placement** — the manifest already records every
   bracket for exactly that reason; turn that record into an assertion a build can fail on. Small
   next to task 1, and it is the one that makes the placement safe to depend on.

3. **The footprint estimate for bracketed sites.** `peak-bytes` and the `pin(N)` gate now count
   bracketed sites, but the weight is a product of two *intra*-procedural loop-depth estimates:
   `g2_region.psm` reports 6 144 bytes where the arena holds ~12 KB per frame. Right order, known
   bias, and it was 0 before, which was flatly wrong. A cross-function trip-count estimator is the
   real fix.

4. **The corpus re-measurement that was never run.** `bench.py --runs 20` has not been run since the
   harness's allocation accounting was fixed. Do it once task 1 lands, so the number covers the
   change with a measured prize attached. Interleaved, not back to back (RESULTS-arena §6).

## Verify, in this order

* Two generations before judging. A `.psm` change takes effect in the generation after next; a
  `runtime/*.c` change is compiled fresh into every generation. **Do not run the suite while editing
  `runtime/*.c`** — `prismio build` compiles the runtime into every program, and a run that straddles
  an edit produces phantom failures.
* Fixpoint warm and cold, cold == warm, full suite (**111/111**).
* IR for every program in `tests/`, `aif/corpus/` **and** `aif/evidence/` — `tools/ir_snapshot.py`
  walks all three in one command. Task 1 *should* move IR, so characterise the delta line by line.
* `--verify` on every corpus program, comparing **`released` and `violation(s)` only**. A split
  object is two allocations, so this is the check that catches a leaked cold block — and `allocated`
  will move legitimately, which is why it is not compared.
* Seed refresh + cold start if the FFI surface moves at all. For task 1 assume it does.
* `test_61_layout_cost_model.psm` asserts the manifest still reports AoS. **That assertion is the one
  task 1 deliberately changes** — rewrite it and its header when the split lands, the way
  `test_58_region_serves.psm` was rewritten when placement landed.

## Carry forward

* **Read the whole gate, not the clause that explained last time.** `--why`, `--layout` and
  `arena_census.py` exist so the seventh session cannot repeat it; use them, against a current binary.
* **A check that cannot fail is the defect this project produces most**, and it has now happened in
  the *measuring* code as well as the compiler: the `--verify` ledger prints `N released`, a
  comparison script asked for `released N`, and it reported all 45 programs "identical" while
  matching nothing on any of them. Assert that your instrument matched something.
* **A fixture must be built to discriminate, and where it cannot, say so.** `test_60` catches one of
  the two ways to get the placement teardown wrong and passes on the other; its header states which.
* **A timing number taken on a contended host is worth re-taking, not discarding.** The placement win
  first read 0.263× while another job ran, and 0.332× on a quiet host over 20 interleaved pairs —
  directionally right, quantitatively wrong, which is the usual shape.
* **A generated file merges cleanly and is still wrong.** `runtime/embedded_sources.h` took a clean
  three-way merge whose output did not match what `generate_embedded_sources.py` produces from the
  merged sources. Regenerate generated files; never merge them.
* Price the experiment before building the feature.
* An annotation that does nothing is worse than no annotation.

## Not this session

Incrementality, generics, concurrency. Bit-packing — LAYOUT §2.1 and §3.2's W4 still contradict each
other and that is a specification question, not an implementation one. SPEC 5.2.1.1 regime (b)
(specialisation) is ranked behind all four above; `br-shared` is the dominant blocker (102 of the
function-level counts) and is the only one that is a restriction rather than a soundness obligation,
so it is the next real feature after these — measure `br_shared` against "called from a region at
all" before building it.

---

# Prompt 1 is done — what it unblocked

## What landed, so it is not re-derived

* **Call-site placement (SPEC 5.2.1.1, regime (a)).** A call inside a `region` is bracketed when its
  callee clears the obligations and has exactly one call site; every allocation in the extent is
  then served by the caller's arena. `aif_support.c`'s `bracket_place` decides it,
  `site_arena_scope_full` applies it, and **no codegen changed** — the arena is on a dynamic stack,
  so `region`'s existing `arena_push`/`arena_pop` is the bracket and the two existing hooks
  (`ir_alloc_region`, `ir_arena_hint_begin/end`) route each site.
* **Obligation 3 comes from the points-to graph, never from `E`.** Every site in an extent has
  `E = Caller` by construction, so `E` cannot separate the sound case from the unsound one.
* **`region_confined`** — the piece the previous session's write-up did not have. A function joins
  when *every* call site of it is inside the region; without it `submit(cmds)` rejects
  `g2_region.psm` itself, because the walk binds a parameter to a local of the same name.
* **A list records which arena it came from, as a depth.** Needed for `is_list`; a flag is wrong
  under a nested `region`. SPEC 5.2.1.1 (c) supplementing (a).

## Next, ranked

1. **`pin(<region-name>)`.** This is the one the previous session deferred until placement landed,
   and it has landed. A `region` that serves something is now worth pinning: the failure mode it
   guards is real, because regime (a) means **a second call to a bracketed callee silently removes
   the placement**. The manifest records every bracket for exactly that reason — turn that record
   into an assertion a build can fail on.
2. **SPEC 5.2.1.1 regime (b), specialisation.** `br-shared` is the dominant blocker in every corpus
   program (102 of the function-level counts), and it is the only one that is a *restriction* rather
   than a soundness obligation. Measure before building: the census's `br_shared` column is the
   population, and the question is how many of those functions are called from a region at all.
3. **The footprint estimate for bracketed sites.** `peak-bytes` and the `pin(N)` gate now count
   them, but the weight is a product of two intra-procedural loop-depth estimates —
   `g2_region.psm` reports 6144 bytes where the arena holds ~12 KB per frame. Right order, known
   bias, and it was 0 before. A cross-function trip-count estimator is the real fix.

## Carry forward

* Read the whole gate, not the clause that explained last time. `--why` and `arena_census.py` exist
  so the sixth session cannot repeat it; use them, and against a current binary.
* **A check that cannot fail is the defect this project produces most**, and it happened again this
  session in the *measuring* code rather than the compiler: the `--verify` ledger prints
  `N released`, a comparison script asked for `released N`, and it reported all 45 programs
  "identical" while matching nothing on any of them. Both halves of the lesson apply — assert that
  your instrument matched something, and re-read the output format rather than the previous script.
* **A fixture must be built to discriminate, and where it cannot, say so.** `test_60` catches one of
  the two ways to get the placement teardown wrong and passes on the other; its header states which
  and why, instead of implying it covers both.
* Price the experiment before building the feature.
* An annotation that does nothing is worse than no annotation.

## Not this session

Layout (prompt 2), incrementality, generics, concurrency.

---

# Prompt 2 — layout

**Prompt 2 has been run (2026-08-16, layout session).** Items 2 and 4 landed and were verified;
**item 1, the hot/cold split, did not land and was deliberately not started** — see HANDOFF "Session
of 2026-08-16 (layout)" §4 for why, and for the release-path design it worked out, which must not be
re-derived. Item 3 stays blocked, now on one thing instead of two. The residual prompt is below,
rewritten down to what is left; the original follows it unchanged for reference.

---

# Prompt 2 (residual) — the hot/cold split, and only that

Copy the block below.

---

Continue the Prismio work. Read, and do not re-derive: `HANDOFF.md` from "Session of 2026-08-16
(layout)" (especially §3 and §4), `aif/evidence/RESULTS-layout.md` §2 and §5, and **LAYOUT §5.2.1**,
which is new and normative.

**Run the tool before reading source.** `prismio aif <file> --layout` prints LAYOUT §7.2's ranked
candidate set for every type in the program — the cut, the hot/cold byte split, and the modelled
cost against not splitting. The cost model is in and is *reported only*; nothing emits a split.

```bash
build/<gen> aif aif/corpus/g1_particles.psm --layout
python3 aif/evidence/xlang/bench.py --compiler build/<gen> --runs 20
clang -O2 aif/evidence/bench/layout_repr.c -o build/layout_repr && ./build/layout_repr
```

> **Superseded — do not quote these numbers.** This paragraph records the *layout tree before the
> merge* (suite 110/110, 89 programs, 46 ledgers, `build/M4`). The merged tree reads 111/111 over 87
> programs against `build/mg3`; see "The prompt for the next session" at the top of this file. The
> technical content below it is current; only the state line is not.

**State inherited, all verified.** Suite 110/110, fixpoint warm and cold, cold == warm, oracle agrees
on 15 sources, cold start from the committed seed works, seed still parses `src/`, IR byte-identical
on all 89 compilable programs, `--verify` identical on `released`/`violations` across all 46 programs
with a ledger.

**The measurement and the cut, already done — do not re-derive.** `layout_repr.c` variant B measures
**0.87×** on g1's shape. The cost model, restricted to what codegen can emit, independently selects
**exactly that cut** (`split 8/12`, hot 72 B / cold 32 B). The naive "cut at the first frequency
boundary" rule selects 2/12 and is badly wrong; `tests/test_61_layout_cost_model.psm` asserts the
difference and is verified discriminating.

## The one task

**Emit the split, with its release path.** *Do the release half or don't start* — the failure mode is
a leak on the good path and a double free on the bad one. Four things are worked out in HANDOFF §4
and must not be re-derived:

1. **The transform is contained.** `ir_struct_field_ptr` is the single choke point for field access
   and all five allocator hooks are backend functions, so redirection and dual allocation are ~200
   lines of C in `runtime/llvm-api-backend.c`. The five `.psm` call sites need no change.
2. **The release half is one clause.** Force `aif_type_releases(T)` true for any split `T`. Every
   drop then routes through the generated `__aif_release_T`, and the type-blind `ir_free_object`
   never sees a split object. That is the "generated release even when the type owns no fields"
   the original brief names.
3. **T3 is where it cracks, and the fix has room already.** `rc_release` frees one block and cannot
   name the type. `RC_HDR` is 16 bytes with 8 in use — put the **cold-block offset** in the spare
   word at `rc_alloc`, and `rc_release` frees the cold pointer before the base. No function pointer,
   no extra call. `cyc_alloc` already carries a per-type release and `list_release` already has the
   element type, so those two need nothing.
4. **Field 0 stays hot, and the split must not read AIF.** The punned-slot invariant (`test_41`) is
   about the first byte of the object; `aif_layout_select` already runs before the solve so that a
   layout cannot differ between `--debug` and release (SPEC 7.2, `test_49`'s note).

**Expect the self-host to be the hard part.** 13 of 16 types in `src/` have an admissible cut,
`ASTNode` among them. The first generation that emits splits is a compiler whose own AST is split.
Budget a seed refresh and a cold start, and keep `build/` known-good generations — a broken compiler
can be unable to build the fix to its own bug.

**Then measure.** `bench.py --runs 20`, interleaved (RESULTS-arena §6). g1 is the program with the
measured prize; the others should move little. Update RESULTS-layout §2.

## Verify, in this order

* Two generations before judging. A `.psm` change takes effect in the generation after next; a
  `runtime/*.c` change is compiled fresh into every generation. **Do not run the suite while editing
  `runtime/*.c`** — `prismio build` compiles the runtime into every program, and a run that straddles
  an edit produces phantom failures (HANDOFF §6).
* Fixpoint warm and cold, cold == warm, full suite (**111/111** on the merged tree; this line read
  110/110 pre-merge).
* IR for every program in `tests/`, `aif/corpus/` **and** `aif/evidence/`. This task *should* move
  IR, so characterise the delta rather than observing it.
* `--verify` on every corpus program, comparing **`released` and `violation(s)` only**. A split
  object is two allocations, so this is the check that catches a leaked cold block — and `allocated`
  will move legitimately, which is why it is not compared.
* Seed refresh + cold start if the FFI surface moves at all.
* `test_61_layout_cost_model.psm` asserts the manifest still reports AoS. **That assertion is the one
  you are deliberately changing** — rewrite it and its header when the split lands, the way
  `test_58_region_serves.psm` is written to be changed on purpose.

## Not this session

Incrementality, generics, concurrency. Bit-packing — LAYOUT §2.1 and §3.2's W4 still contradict each
other and that is a specification question. Handles, unless you are choosing them over this.

---

# Prompt 2 (original, for reference)

Runs after prompt 1, or before it if you would rather have the measured 0.87x first. Not blocked on
prompt 1.

---

Continue the Prismio work. Read `HANDOFF.md` — start at "Session of 2026-08-14" — and
`aif/evidence/RESULTS-layout.md`. Don't re-derive what's in them.

**Three corrections to inherit before you plan anything.**

- **Handles have not landed.** Three consecutive briefs have opened by saying they did.
  `ptr_to_node` in `runtime/lang_runtime.c` is still `return ptr` and there is no handle table.
  The check takes ten seconds; do it rather than trusting this paragraph either.
- **Build HEAD before reading it.** Twice now the committed tree has not compiled — eaten spaces
  from a rename, then a stray `/* */` in a language with no block comments. Both would have been
  caught by CI's first step, and neither was caught by anything local.
- **The container element-release path may not have changed, so check rather than assume.** The
  2026-08-14 session was scheduled to land the `CallerRegion` + container-disposition pair and
  deliberately did not: it measured the gate and found the pair buys **zero sites on every program
  in the tree**, because a third gate, `enclosing_region`, rejects every one of them and neither
  half touches it (HANDOFF §1; SPEC §5.2.1). Prompt 1 builds the real fix and *does* change that
  path — so if prompt 1 has run, read what it left. **Nothing in the plan below depends on it
  either way**; plan the release half from scratch as item 1 describes.

State: suite 106/106, fixpoint holds warm and cold, cold == warm, the oracle agrees on 14 sources,
the committed seed still parses `src/`, and 82 of 85 compilable programs in `tests/`, `aif/corpus/`
**and** `aif/evidence/` differ only by one added `declare` — the other three additionally lose an
`arena_push`/`arena_pop` pair for an arena that served nothing, which is the fix, not a regression.
`workload` (LAYOUT 3) is built and measured.

**Two tools landed that you should use before reading source.**
`prismio aif --why=<symbol>` now explains *placement* as well as tier, and lists **every** clause
that rejected a site rather than the first — the short-circuit is what sent two sessions to the wrong
work. `python3 aif/evidence/arena_census.py --compiler build/<gen>` answers the same question over
the whole corpus in 1.4 s. If you are about to reason about where a value lives, run one of them.

1. **The hot/cold split.** The one LAYOUT 6 dimension that is emittable today and pays: **0.87×**
   measured on g1's shape, with no missing mechanism, because the cold block hangs off the hot
   record so one pointer still reaches the object. `aif/evidence/bench/layout_repr.c` is the
   measurement and re-runs in one command.

   The whole risk is release, and it is nameable rather than vague. A split object is *two*
   allocations, so: all five allocator hooks must allocate both and wire the pointer; the type needs
   a generated `__aif_release_T` even when it owns no fields, or the cold block leaks; every free
   must route through it; `--verify`'s accounting must see both halves or every split object reads
   as a violation. **T3 is where it cracks** — `rc_release` frees one block and cannot name the
   type, which is the same shape as the problem `cyc_set_type` solves by telling the object its type
   at construction. Do the release half or don't start: the failure mode is a leak on the good path
   and a double free on the bad one.

   Two constraints that are not obvious. Field 0 must stay in the hot group — the punned-slot
   invariant (`test_41`) is about the first byte of the object, and a cut by frequency rank would
   happily put a never-read field there. And the split must not read AIF: `test_49`'s note records
   why a layout that differed between `--debug` and a release build would break SPEC 7.2, and
   `aif_layout_select` already runs before the solve for that reason.

2. **Port LAYOUT 5's cost model** from `aif/prototype/layout.py`. It is the precondition for three
   things at once: §7.2 as actually written (`argmin over candidates(τ) of Cost(…)` — the compiler
   has no cost function and enumerates no candidates, it runs one greedy placement), §8's "top-`k`
   ranked by modelled cost", and choosing a hot/cold cut by anything better than the frequency
   ranks. Note the defect `layout.py` already records at `traversal_cost`: LAYOUT 5.4 subtracts
   SimdCredit from a sum of memory costs, which lets the total go negative.

3. **LAYOUT 8's empirical validation** follows item 2 and nothing else — the build-time
   instrumented compile-link-run it needs is `workload`, and that is done. It is `compiler_run_workload`
   plus a way to force a candidate layout.

4. **Fix the harness's allocation accounting before quoting it.** `aif/evidence/xlang/bench.py`
   counts allocations for the whole process but times only the frame loop, and commit `901b494`
   moved the corpus's reporting loops onto the allocating `println` overload — so g1's `allocs`
   column went 2,214 → 26,326 (4.02 per print over 6,002 prints) with the timing untouched. The
   column is now reporting overhead, not workload behaviour.

5. **Then re-measure.** `python3 aif/evidence/xlang/bench.py --compiler build/<gen> --runs 20`.
   Hot/cold is the first layout change with a measured prize attached, so it is the first one whose
   effect on the corpus is worth a number rather than a projection.

NOT this session: incrementality, generics, concurrency. And **do not write the bit-packing
transform** — LAYOUT 2.1 and 3.2's W4 contradict each other on it (an observed range is not a
bound), and that is a specification question, not an implementation one. The measurement is already
emitted as advice at the foot of the manifest; the upper bound if it were legal is 9.4% of struct
bytes.

Carry forward:

- **A measurement is cheaper than an argument from the cost model, and has now refuted one twice.**
  λ was provably inert against a 512-byte ceiling; hot/cold was argued to be neutral on a
  pointer-vector runtime and is 13%. `layout_repr.c` took minutes to write.
- **A fixture must be built to discriminate.** `test_55`'s first draft declared its fields in
  frequency order, so the measured and static layouts came out identical and the test passed
  without exercising anything.
- **A watchdog inherits your pipes.** The workload timeout backgrounded a `sleep` that held the
  compiler's stdout, so any caller capturing output blocked until it expired — a 60-second *floor*
  wearing a ceiling's name, surfacing as a hung suite with nothing using CPU.
- **The manifest has to describe the build.** `prismio aif` runs a declared workload for the same
  reason the `owned_collections` default had to be inverted: a reporting command that analyses a
  different program from the one `prismio build` compiles is worse than no command.
- **Read the whole gate, not the clause that explained last time.** Three consecutive sessions
  designed an arena fix against `aif_arena_at_node` and each stopped reading at the clause the
  previous failure had named. The census that finally settled it was one `getenv`-gated `fprintf`
  and two throwaway scripts.
- **A duplicated predicate is a defect while the copies still agree.** Four copies of the arena gate
  existed; three agreed, and the fourth quietly placed arenas that served nothing and inflated the
  `peak-bytes` budget number by 64 bytes on a program whose arena held zero. Nothing failed.
- **Adding a builtin is an oracle change even when no inference rule moved.** Every `extern fn` a
  source declares carries its contract in the AST, so `aif/prototype/aif.py`'s fallback tables never
  fire for it — but a *builtin* is declared by nobody, so those tables are the only place it can be
  known. `list_new_with_capacity` was added without them: the differential agreed on all 13 sources
  while any program using it disagreed by eight tiers. The check was not wrong, it was unexercised.
  `run_oracle_vocabulary_test` now compares the two produce-lists directly, and
  `tests/test_56_list_capacity.psm` is in the differential's default sources.
- **The manifest emitted records its own CI differ could not parse.** A field wider than its column
  ran into the next one, the differ ignores what it cannot parse, and `g5_asset_cache.psm`'s 14
  records read as 13 — so a tier regression on `load_material` could not have failed the gate. Fixed,
  and `run_manifest_parseable_test` now counts emitted records against parsed ones. If you add a
  column or a longer symbol scheme, that test is the one that catches you.

---
---

# The last-good generation

**`build/mg3`** (2026-08-16, the merge of the arena and layout sessions), with **`build/mcold2`**
its cold-start twin — the two produce byte-identical IR for **all 87** compilable programs, which is
what "cold == warm" means here. Keep both; a broken compiler can be unable to build the fix to its
own bug, and recovery is to build from the previous good generation. `build/t3` is the generation
before both sessions, and it is the one to diff against when asking what they changed.

> **Read this before quoting a per-session number.** The arena and layout tasks ran in parallel in
> separate trees and were merged afterwards. Their own last-good generations — arena's `build/v4`,
> layout's `build/M4` — **do not exist in this tree**, and each was verified against only half of
> what is now here. `build/mg3` is the only binary that has seen both changes. The merged gate:
> suite **111/111**, warm fixpoint `mg2 == mg3`, cold fixpoint `mcold1 == mcold2`, `cold == warm`
> on all 87 programs, seed still parses `src/`, oracle agrees on **15** sources, `--verify`
> `released`/`violation(s)` identical to `build/t3` on every corpus program **except `g2_region`**,
> which falls by exactly 10 200 000 because `arena_alloc` bypasses the ledger by design, with **0**
> violations on both sides. IR moves on exactly three programs — `g2_region.psm`, `test_58`,
> `src/main.psm` — plus the two new fixtures; the layout cost-model port is inert *in the merged
> tree*, not merely in its own.

Pass it explicitly. **Both tools default to something that will mislead you:**

| tool | its default | state |
|---|---|---|
| `aif/evidence/arena_census.py` | `build/gen2` | 2026-08-08, predates the `--why` placement section entirely |
| `tools/aif_differential.py` | `build/aif2.exe` | does not exist on this host |

The 2026-08-16 session opened by running the census against `build/gen6` and read **13 of 156 sites
with every blocker column zero** — not a result, a stale binary whose `--why` prints no placement
section for the parser to match. The census now exits non-zero when no `--why` prints a bracketing
verdict *and* when `--summary` and the manifest disagree about how many calls were bracketed; the
tier columns still have no such guard.

```bash
python3 aif/evidence/arena_census.py --compiler build/mg3
python3 tools/aif_differential.py --compiler build/mg3
cd tests && PRISMIO=../build/mg3 python3 test_runner.py     # 111/111
python3 tools/ir_snapshot.py --compiler build/mg3 --out /tmp/ir   # all three trees, for the IR diff
```

Everything under `build/` is a working artefact and none of it is committed. If the directory is
empty, cold-start from the committed seed:

```bash
bash tools/bootstrap.sh --seed --out build/gen0
bash tools/bootstrap.sh --compiler build/gen0 --out build/gen1
bash tools/bootstrap.sh --compiler build/gen1 --out build/gen2
```
