# Prompts for the next sessions

**Prompt 1 has been run.** Tasks 1-3 landed and were verified on 2026-08-16; **task 4 did not
land, deliberately** -- see HANDOFF "Session of 2026-08-16" §5 for why and for the two pieces it
needs, which are worked out and must not be re-derived. Prompt 1 below has been rewritten down to
that residue. Prompt 2 is unchanged and was never blocked on prompt 1.

---

# Prompt 1 (residual) -- call-site arena placement, the placement itself

Copy the block below.

---

Continue the Prismio work. Read, and do not re-derive: `HANDOFF.md` from "Session of 2026-08-16"
(especially §5), `aif/evidence/RESULTS-arena.md` §7 item 1 and §8, and SPEC 5.2.1 and **5.2.1.1**.

**Run the tools before reading source**, and against a *current* compiler -- the 2026-08-16 session
opened by running the census against a stale `build/gen6` and got 13 of 156 sites with every
blocker column zero, which is what a compiler predating the `--why` placement section reports. The
last-good generation is recorded at the end of this file; the census's own default (`build/gen2`)
is stale and `aif_differential.py`'s (`build/aif2.exe`) does not exist.

```bash
python3 aif/evidence/arena_census.py --compiler build/<gen>   # whole corpus, ~1.5 s, two tables
build/<gen> aif <file> --why=<symbol>                         # one site, every blocker + verdict
build/<gen> aif <file> --summary                              # the per-function counts
```

**State inherited, all verified.** Suite 108/108, fixpoint warm and cold, cold == warm, oracle
agrees on 15 sources, seed still parses `src/`, IR byte-identical on all 84 compilable programs in
`tests/`, `aif/corpus/` and `aif/evidence/`. The summary (obligations 1, 2, 4 as a fixpoint over
the call graph), the per-site `--why` verdict, the census's second table and the disposition clause
in `elem_disposition_of` are all in and all inert -- no placement decision changed.

**The measurement, already done -- do not re-measure before starting.** 70 of the 196 blocked sites
are in a function that clears every obligation; **2** of those are also called from inside a
region, and both are `g2_region.psm`'s `cull` and `submit`. Every corpus program without a `region`
contributes 0. `cull` is where the 10.02 M allocations are, and `--why` on its `DrawCmd` site
already reports `yes -- every obligation holds ... 1 of 1 call sites lie inside a region`.

**The regime is settled and normative.** SPEC 5.2.1.1 chose (a) -- bracket only a callee with
exactly one call site. Do not reopen it; if the measurement later says (b) is worth it, that is a
new section, not an edit to this one.

## The one task

**Call-site bracketing.** `ir_arena_hint_begin/end` already exists and already routes
runtime-internal allocation to the arena; `ir_alloc_region` already exists for a struct literal.
The new part is bracketing a *Prismio* call and making the callee's allocations reach the caller's
arena. Three things are worked out and must not be re-derived -- HANDOFF §5 and RESULTS-arena §7
item 1 state each with its reasoning:

1. **Obligation 3 is not readable from `E`.** `AIF_CON_LIVE_IN` sets `E = Caller` for any site
   whose `fn` is not the binding function, by construction. Recover the **caller-side binding
   scope** by walking `cons[]` for `AIF_CON_LIVE_IN` after the solve and recording
   `(site, k->c, k->b)` where `sites[s].fn != k->c`. Obligation 3 is then: every caller binding is
   in the bracketing caller, at a scope at or below `r`.
2. **Bracket only into `region`-pinned arenas.** Cost-model-chosen ones are circular:
   `enclosing_region` reads `scopes[].arena`, which `aif_place_arenas` sets from
   `arena_would_serve`, which would have to count bracketed sites as benefit. A `region` sets the
   flag before placement runs. This also leaves `arena_would_serve` -- the one clause-list copy
   deliberately *not* behind `site_arena_scope` -- correct without change.
3. **A bracketed site keeps its derived tier.** The manifest will read `T2  region:<name>`.
   Promoting it to T1 moves the tier distribution, and the oracle does not model placement, so the
   differential would fail on a difference that is not an inference difference.

A site in a bracketed extent must also stop being rejected by `in_container` and `is_list`: under
the bracket the container and its element block are in the same arena and die with it. The
disposition half for that is already in `elem_disposition_of` and is the single clause every
consumer reads -- do not add a second copy.

**Acceptance.** `g2_region.psm` must serve a large fraction of 10 201 215 and the "serves no
allocation" warning must stop firing. Add a fixture that asserts the served count **at run time**,
the way `test_58` does -- `arena_objects()` is the only thing that can tell an arena pointer from a
malloc'd one, and `ir_alloc_region` deliberately bypasses `--verify`'s accounting so the ledger
cannot see it. `test_58_region_serves.psm` says in its own header that `serves_nothing` is the test
that changes when this lands, and that it should change deliberately with the comment rewritten.

**Then measure.** Four of six corpus programs allocate nothing per frame, so g1, g3, g4 and g5
should move by ~0 -- and so should g6, which has no `region`: only `g2_region.psm` has region call
sites reaching a bracketable callee, so it is the only program that can move at all. A large win
there and a flat line everywhere else is the correct outcome. Interleaved runs, not back to back
(RESULTS-arena §6). Update RESULTS-arena.md's §8 census.

## Verify, in this order, and do not skip the last three

* Two generations before judging. A `.psm` change takes effect in the generation after next; a
  change to `runtime/*.c` is compiled fresh into every generation and takes effect immediately.
* Fixpoint warm and cold, cold == warm, full suite (108/108).
* IR for every program in `tests/`, `aif/corpus/` **and** `aif/evidence/` -- the last is not covered
  by the usual check. This task is the first that *should* move IR, so the delta must be
  characterised line by line rather than merely observed.
* `--verify` on every corpus program. Compare **`released` and `violation(s)` only**:
  `allocated` and `leaked` are run-to-run noise on the timing programs (~1500 allocations between
  two runs of one binary), which cost the last session a false alarm on seven programs.
* `test_58_region_serves.psm` must still report exactly 50 and exactly 0 unless you are changing it
  on purpose, in which case rewrite its header.
* The same change in `aif/prototype/aif.py` **if and only if** the analysis changes. Placement
  alone does not: the oracle does not model arenas, and `region-calls` is already a recorded
  divergence. If you move a tier, the oracle must move with it.
* Seed refresh + cold start if the FFI surface moves at all.

## Carry forward

* Read the whole gate, not the clause that explained last time. `--why` and `arena_census.py` exist
  so the fifth session cannot repeat it; use them, and against a current binary.
* **A check that cannot fail is the defect this project produces most.** Last session added four
  mechanisms and broke each one on purpose to confirm the check failed -- the oracle's obligation 2
  (`br-param: compiler=1 oracle=0`), the closure fixpoint (`br-drop` 3 → 2), the census's verdict
  guard (exit 1 on a compiler without the section), and the `aif_reset` teardown (`sole-regime` 0
  on a workload source). Do the same for anything you add.
* **A fixture must be built to discriminate**, and check that it does. `test_59`'s obligation-4 case
  had `main` calling `drops` directly at first and discriminated *nothing*, because a one-step walk
  finds a direct callee. `middle` between them is the minimum that fails.
* Price the experiment before building the feature.
* An annotation that does nothing is worse than no annotation.

## Not this session

Layout (prompt 2), incrementality, generics, concurrency. `pin(<region-name>)` becomes worth
building the day this lands -- so the session after this one, not this one.

---

# Prompt 2 — layout

Runs after prompt 1, or before it if you would rather have the measured 0.87x first. Not blocked on
prompt 1.

Copy the block below.

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

# The last-good generation

**`build/t3`** (2026-08-16), with **`build/cold_t2`** its cold-start twin — the two produce
byte-identical IR for `src/main.psm`, which is what "cold == warm" means. Keep both; a broken
compiler can be unable to build the fix to its own bug, and recovery is to build from the previous
good generation.

Pass it explicitly. **Both tools default to something that will mislead you:**

| tool | its default | state |
|---|---|---|
| `aif/evidence/arena_census.py` | `build/gen2` | 2026-08-08, predates the `--why` placement section entirely |
| `tools/aif_differential.py` | `build/aif2.exe` | does not exist on this host |

The 2026-08-16 session opened by running the census against `build/gen6` and read **13 of 156 sites
with every blocker column zero** — not a result, a stale binary whose `--why` prints no placement
section for the parser to match. The census now exits non-zero when no `--why` prints a bracketing
verdict, which catches exactly that; the tier columns have no such guard.

```bash
python3 aif/evidence/arena_census.py --compiler build/t3
python3 tools/aif_differential.py --compiler build/t3
cd tests && PRISMIO=../build/t3 python3 test_runner.py
```

Everything under `build/` is a working artefact and none of it is committed. If the directory is
empty, cold-start from the committed seed:

```bash
bash tools/bootstrap.sh --seed --out build/gen0
bash tools/bootstrap.sh --compiler build/gen0 --out build/gen1
bash tools/bootstrap.sh --compiler build/gen1 --out build/gen2
```
