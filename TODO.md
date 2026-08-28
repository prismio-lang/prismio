# TODO — compiler improvement plan

> **Language features live in [`V0_1_FEATURES.md`](V0_1_FEATURES.md), not here.** This file is
> measured compiler work — optimisations, defects, evidence. That one is the v0.1 language surface:
> `impl`, traits, closures, namespacing, pointers, the package manager. They share the gate, and
> that file adds two requirements this one does not have: a **five-arm** benchmark after every task,
> and a standing instruction to **rewrite the corpus in the new language** as features land., with a measured gate on every milestone

Derived from [`aif/evidence/RESULTS-final.md`](aif/evidence/RESULTS-final.md) (the measurements)
and [`docs/ARCHITECTURE-DIRECTION.md`](docs/ARCHITECTURE-DIRECTION.md) (the ranking and the
papers). **Every prize below is measured on this host unless marked *projected*.**

Ordering rule: measured prize ÷ cost, with "needs no language change" breaking ties.
One milestone at a time. **Do not start M(n+1) until M(n)'s gate is green.**

---

## The gate — run this at the end of every milestone, no exceptions

```bash
# 1. correctness first, always
bash tools/bootstrap.sh --compiler build/<lastgood> --out build/<next>
bash tools/bootstrap.sh --compiler build/<next>     --out build/<next2>
./build/<next> build src/main.psm -o build/a.ll && ./build/<next2> build src/main.psm -o build/b.ll
cmp build/a.ll build/b.ll          # fixpoint: must be identical
cd tests && PRISMIO=../build/<next2> python3 test_runner.py   # must be 137/137 or higher
```

```bash
# 2. old vs new vs Rust, over the whole corpus, interleaved
python3 tools/milestone_bench.py --old build/<lastgood> --new build/<next2> \
    --runs 25 --label "M<n> <name>"
```

```bash
# 3. the standing against Rust
python3 aif/evidence/xlang/bench.py --compiler build/<next2> --runs 25 \
    --json aif/evidence/xlang/results-m<n>.json
```

**Swift is off by default as of 2026-08-23** — the development loop compares against Rust, and a
`swiftc -O -wmo` build of every program was the slowest part of a run. `--with-swift` on either
harness puts it back, which is what reproduces the Swift columns in the older `RESULTS-*` files. A
Rust-only run records `"swiftc": null` in its JSON, so it cannot be mistaken for one where Swift
was measured.

### What the gate asserts

| | requirement |
|---|---|
| Fixpoint | `a.ll == b.ll` |
| Suite | 137/137 or higher, never lower |
| Checksums | all 29 corpus variants identical — `milestone_bench` asserts this before timing |
| Time | corpus median `new/old` within 3%; **fewer than 2** programs past 10% |
| RSS | no program past 10% — this axis reversed once with nobody watching |
| Exe size | reported, never a gate (accepted tradeoff) |

### Before trusting a single-program number

```bash
python3 tools/milestone_bench.py --old build/<lastgood> --new build/<lastgood> \
    --runs 25 --calibrate --skip-baselines
```

**A/A calibration is not optional ceremony.** Measured on this host: `build/E2` against a compiler
bootstrapped from it with **no source change** reads **1.098× on g1** while the other five read
0.989–1.019×, and their emitted IR for `g1.psm` is byte-identical. g1 is layout-sensitive. A gate
that failed on one program would have failed that. **The corpus median is the number that holds;
one regressed program is layout luck, two is a pattern.**

### Docs — part of the gate, not a follow-up

**Every milestone must leave the documentation true.** Check these and update whatever the change
touched, in the same session:

- [ ] `HANDOFF.md` — session entry, "Current state" bullets, last-good compiler
- [ ] `SESSION-PROMPT.md` — re-rank the candidate list; it is the *live* prompt and goes stale first
- [ ] `aif/evidence/RESULTS-*.md` — the measurement writeup for this milestone
      (M1: [`RESULTS-M1-lto.md`](aif/evidence/RESULTS-M1-lto.md))
- [ ] `docs/ARCHITECTURE-DIRECTION.md` — if a measurement changes the ranking or kills an approach
- [ ] **`../docs/content/` (the public docs site)** — see the checklist in
      [§ Public docs](#public-docs-what-to-check-in-docscontent) below. Velite enforces the
      frontmatter schema, so a bad edit fails the site build rather than shipping quietly.
- [ ] `graphify update .`

---

## M1 · Close the runtime call seam

> **Done, except for its own exit gate. Measured through the driver: corpus median 0.812×**, range
> 0.450–0.963×, RSS and exe size unmoved, suite 137/137. g5 goes **2.69× → 1.26× of idiomatic
> Rust**. **No language change**, and it remained the largest measured item in the project.
> All of M1.0–M1.3 in [`RESULTS-M1-lto.md`](aif/evidence/RESULTS-M1-lto.md).
> **The exit gate is not met and M1 cannot meet it** — g3 reads 1.04×, not < 1.00×, and the seam on
> g3 is already fully closed. The 0.94× that set the target was hand-built and did not survive
> re-measurement. See the exit gate below.
> **Default-on candidate is built and locally green.** The suite now requires a successful curated
> merge and exercises `PRISMIO_INLINE_RUNTIME=0` as the rollback path, so the existing
> Windows/Linux/macOS matrix is finally a real portability gate. Remote CI is the one unchecked
> sub-step because these working-tree changes have not been pushed.

**The problem.** Every container access (`list_get`, `list_set`, `list_len`, `list_push`) is a
`bl` into the separately-compiled C runtime. `cull_into` compiles to 53 instructions containing two
`bl _list_get` per iteration. The post-`-O2` IR is otherwise clean. The codegen was never the
problem; the seam was.

**Concepts:** [cross-module inlining](#cross-module-inlining), [whole-program
compilation](#whole-program-compilation), [summary-based LTO](#summary-based-lto).
**Papers:** ThinLTO (CGO 2017); Swift SE-0193 `@inlinable`; MLton whole-program compilation.

- [x] **M1.0 — Find out why `-flto` declines the inline.** **Answered** —
      [`aif/evidence/RESULTS-M1-lto.md`](aif/evidence/RESULTS-M1-lto.md). It does not decline on
      cost, it refuses: `cost=never: conflicting attributes`. The backend emits program functions
      with **no function attributes at all**; the clang-compiled runtime carries
      `target-cpu=apple-m1` plus 33 `target-features`, so `areInlineCompatible` fails before the
      call is priced. Stamp clang's exact string on the program's functions and `-flto` reaches
      **1.87× on g2_tuned, 1.07×–2.00× across the corpus, identical checksums, and a 42% smaller
      binary** — matching the `llvm-link` merge on speed and beating it on size. The merge was
      never doing something LTO cannot; `clang -O2` on the merged module was quietly filling in the
      missing attributes first. **It does not reduce M1 to a flag**: see M1.1.
- [x] **M1.1 — Curated `available_externally` bitcode module.** **Built and gated** —
      [`RESULTS-M1-lto.md`](aif/evidence/RESULTS-M1-lto.md) §8. `PRISMIO_CURATED_OPS` +
      `build_curated_module` + `merge_curated_into_program` in `runtime/build_driver.c`, merged
      before `-O2`, cached in the object-cache directory on runtime content plus flags. Behind
      `PRISMIO_INLINE_RUNTIME=1` while the three items in M1.1b are open.
      **Corpus median 0.864×, range 0.481–0.982×, gate passed.** g5 **0.481×** (2.69× → 1.29× of
      idiomatic Rust), g4 0.772×, g6 0.837×, g2 0.892×, g3 0.940×, g1 flat. RSS regresses nowhere
      and improves on three; exe size unchanged, because `available_externally` emits no code.
      Suite **137/137** with the feature off and on; fixpoint holds.
      **The curated set is closed over exported symbols, and that is now a test.** `list_push` is
      excluded because its body reads `rt_arena_hint`, `arena_depth` and `arena_alloc_slot`, all
      `static`; forcing its inline reproduces `Undefined symbols … _arena_alloc_slot`. It stays
      quiet in the shipped configuration only because the cost model declines it at its current
      size, so `run_curated_closure_test` asserts the property rather than trusting it — verified
      to fail when `list_push` is added back.
- [x] **M1.1b — What kept it opt-in.** All three done; see
      [`RESULTS-M1-lto.md`](aif/evidence/RESULTS-M1-lto.md) §9 and §10. The working tree now makes
      the merge the default and adds a discriminating suite check: a successful build is not
      enough, because the optimization fails open; the check requires the post-curation merge
      marker. Local macOS is green, and the existing three-OS CI matrix will run the same check.
      - [x] **Merge ported off the `llvm-extract`/`llvm-link` binaries.** `ir_curate_module` and
            `ir_link_modules` in `llvm-api-backend.c`; `LLVMLinkModules2` added to
            `prismio_llvm.h` on both paths. Output is **byte-identical** to what `llvm-extract`
            produced apart from the `ModuleID`/`source_filename` path lines, and `g2_tuned` builds
            correctly with **only `clang` on PATH**. Also **cheaper**: two process spawns removed
            takes the warm compile-time cost from ~16% to **~5%**, first build 1.26× → 1.16×.
            The C API has no `Function::deleteBody` and erasing blocks front-to-back breaks on any
            CFG back edge, so the body is emptied in three passes — RAUW to `undef`, erase
            instructions (which is what drops the block-to-block references), then erase blocks —
            followed by a fixpoint sweep for unreferenced declarations, which is what
            `llvm-extract` gets from GlobalDCE.
      - [x] **Cold compile time measured.** **+74 ms once, +16 ms per build after** — 1.35× on a
            first build, **1.18× warm**, 1.31–1.37× permanently uncached. The one-time cost is
            compiling lang_runtime.c to IR (49 ms) plus the extract (8 ms); reusing that IR to
            produce the object too would recover only ~14 ms of 57.
      - [x] **`--verify`, the object cache and `--target` exercised.** All three work.
            `--verify` and each `--target` take their own cache entry, as the key intends.
            **Found and fixed a real defect on the way**: `PRISMIO_OBJ_CACHE=0` did not reach the
            curated module, which is the same stale-after-a-clang-upgrade hazard the bypass exists
            for. `PRISMIO_OBJ_CACHE_TRACE=1` now reports the curated module too.

- [x] **M1.2 — Cost it.** Done; the route chosen in M1.1 dropped the two risks that dominated
      this item before it started. **Compile time**: +~5% warm, 1.16× on a first build after the
      in-process port (was 1.18×/1.35× when it shelled out). **RSS**: unmoved — 1.000× on four
      programs, 0.968× and 0.996× on the other two. **Exe size**: unchanged, because
      `available_externally` emits no code. **`--verify`, the object cache and `--target`**: all
      exercised and working, each taking its own cache entry. **`-g`**: the merge is declined
      outright under `-g`, since the object step is `-O0` there and nothing would inline — so it
      cannot change what `-g` builds, which was the named risk.
- [x] **M1.3 — Decided by measurement, and it is neither option.**
      [`RESULTS-M1-lto.md`](aif/evidence/RESULTS-M1-lto.md) §11.
      **ThinLTO summaries: trigger not met** — the merge costs ~5% warm with a 13.4 KB cached
      module; it has not stopped scaling. **Hot ops in Prismio: would change nothing for the seam**
      — with the merge on, g3's `propagate` and `count_visible` already contain *zero* runtime
      calls, so "landing in the same module" is already true. That option's real prize is
      monomorphisation and layout, which is M4's inline storage, not M1.
      **What the corpus actually still called was `list_push`**, and the obvious fix — export the
      three `static`s it reads and curate it — was built and **changed nothing**: the inliner
      declines it at `cost=675` against a threshold of 225, and emitted call counts were identical
      on all six programs. *(That experiment's timing table showed g5 swinging 1.48× → 2.57× from a
      change that provably emitted identical code. Check what was emitted before believing what was
      timed.)*
      **The answer was to outline the growth path.** 159 of `list_push`'s 227 IR lines are
      realloc-and-copy that runs once per doubling; moving them into `list_push_grow` drops the
      fast path to 69 lines, takes all three statics with it — so **no mutable global has to be
      exported** — and removes every `bl _list_push` in the corpus (3,5,3,6,15,9 → all 0).
      **Corpus median 0.858× → 0.812×**, g5 **0.450×** and now **1.26× of idiomatic Rust** (from
      2.69× before M1), RSS still regressing nowhere. The compiler emits byte-identical IR with the
      feature off, since this is a runtime change and not a codegen one.

**Exit gate: NOT met, and M1 cannot meet it.** The standard gate passes (median **0.812×** after
M1.3). `--only g3` reads **1.04× of idiomatic Rust**, not < 1.00× — measured three times across
three compiler generations at 1.05×, 1.05× and 1.04×, so the shortfall is a result, not a draw.
**And it is no longer a seam problem**: with the merge on, g3's hot functions `propagate` and
`count_visible` contain zero runtime calls (§11.1). There is nothing left in M1 to close it with.
The remaining distance is the 1.24–1.27× residual §5.1 has reported for eight sessions, and
whatever g3-specific codegen sits under it — neither is what this milestone was about. §9's table has now been re-measured rather than cited, and it moved:
§9.3 put g3 at 1.01× of idiomatic Rust *before* the change, `milestone_bench` puts it at 1.12×.
The change's *worth* reproduced (1.064× against 1.07×); the baseline it was applied to did not.
**"The first Prismio program to beat idiomatic Rust" is not currently supported by a driver-built
measurement** — §9.3's table is hand-built with `clang -O2` invoked directly. Closing the last
0.05× is what M1.3 is for.

---

## M2 · Reuse analysis

> **Retired as an active milestone, 2026-08-25.** M2's original gate named g2 and g6, neither
> program contains the destructure/dead-block/same-size-constructor shape a reuse token needs, and
> M3 has already exceeded that allocation-count gate on both through automatic arenas. The
> remaining token path is also blocked on per-site field disposition and ownership transfer across
> calls; two implementations that ignored those facts were measured and reverted below.
>
> This is a scope decision, not a claim that reuse was implemented. M2.1-M2.3 and their ownership
> prerequisites are closed as dormant research. **Reactivate them only when a real, maintained
> workload contains the immutable rebuild shape and a paired baseline shows a material allocation
> prize.** The reactivated gate must name that workload, require equal output and a clean verifier
> ledger, bound token lifetime, and measure allocation count against the no-reuse control. An
> author-only synthetic fixture may guard correctness, but may not by itself reopen the milestone.

> **M2.0 is done, 2026-08-23** — see below. The gate is restated and the premise it rested on was
> wrong; read that before the entry.
>
> **Reordered behind M3.1, 2026-08-27, and the exit gate below is not reachable as written.**
> Reuse tokens pair a dead value with a same-size constructor *in the same branch*, which needs a
> destructure-then-rebuild shape. **g1–g6 contain none**: `match` appears only in `g7.psm` and
> `g7_substring.psm`. g2's 10.2 M allocations are `DrawCmd` literals pushed inside `cull`
> ([g2.psm:62](aif/evidence/xlang/prismio/g2.psm)) — ~510 per frame × 20000 frames — which die in
> `main` when the frame's `cmds` list drops and are rebuilt **in a different function** on the next
> iteration. Cross-call, cross-iteration, ~510 blocks at once: that is an arena or a free list, not
> a single same-branch token. g6 has the identical shape with `Order`.
>
> **The cited evidence does not say what this section said it said.** `g2_tuned.psm`'s own header:
> the buffer is allocated **once outside the frame loop** and elements are mutated in place, and
> "clearing and re-pushing would still allocate one DrawCmd per element per frame" because `List`
> holds pointers. That is allocation hoisting plus boxed-element avoidance — **M4.2** — not reuse
> analysis. Before building M2, restate its exit gate against a program that has the shape.

**The problem.** AIF is a *classifier*. It reports 100% T0–T2 on g6 and still allocates 15.1 M
times where Rust allocates 289 K. **Classification without reuse does not reduce allocation count.**

**The evidence it will work is already in the tree:** `g2_tuned.psm` hand-writes exactly this
(pre-fill once, mutate in place) and reaches **0.25× of plain g2**. Reuse analysis is the compiler
doing that automatically.

**Concepts:** [reuse analysis](#reuse-analysis), [reuse specialisation](#reuse-specialisation),
[FBIP](#fbip-functional-but-in-place), [borrow inference](#borrow-inference).
**Papers:** Perceus (PLDI 2021) — **read first**; Counting Immutable Beans (IFL 2019);
Reference Counting with Frame-Limited Reuse (MSR-TR 2021).

- [x] **M2.1 — Reuse tokens: retired as dormant research, 2026-08-25.** Pair a dead value with a
      constructor of the same size in the same branch; reuse the block instead of
      free-then-malloc. Reactivation is governed by the measured-workload trigger above.
- [x] **M2.2 — Reuse specialisation: retired with M2.1.** In-place field update when the reused block *is* the
      matched one. **Blocked on M2.1, which is blocked on the per-site field disposition** — there
      is no token to specialise until one exists. Note also that the g2 motivation in the original
      line was already superseded: M3 took g2's allocation count from 10 285 886 to 82 052 with an
      arena, so the prize this would add on g2 is whatever is left after that, and nobody has
      measured it.
- [x] **M2.3 — Bound the tokens: retired with M2.1, mandatory if it is reactivated.** Frame-limited reuse, so a held token cannot leak. **Blocked on
      M2.1 for the same reason as M2.2**, and it stays on the list rather than being folded into it:
      the bound is the answer to the space-safety objection that M2.4 has now declined to take on
      inference, and a token implementation that arrives without it inherits the objection.
- [x] **M2.4 — Borrow inference: decided 2026-08-23. Opt-in, through the annotations the language
      already has, and no automatic inference.** Written down as the entry asked, with the reason.
      **Prismio is not in the position the paper is in.** Ullrich & de Moura infer borrowing on top
      of a model where everything is owned; Koka judged the automatic version not safe for space and
      declined it. Prismio's default is the *other* one — `let` and `inout` parameters borrow and
      only `sink` takes ownership (`src/sema/checker.psm`, "let/inout params are non-owning
      borrows"). So the thing borrow inference would buy is already the default, and what would be
      inferred is the narrower question of where a `sink` could be weakened to a borrow.
      **The measured reason not to.** This session found the call boundary already has **three**
      owners that can each claim a value — the caller's drop list, the parent's field release, and
      the caller's temporary cleanup — and a fourth, implicit one is what an inferred borrow would
      be. That was not a design worry: a callee-side free that ignored one of them read
      `3 allocated, 3 released, 0 leaked` on the suite and **5 violations** on a four-line probe.
      Inference here would make the boundary less predictable at exactly the point the compiler is
      already having trouble agreeing with itself.
      **If it is ever revisited**, the space-safety bound is the thing to build first, not the
      inference — Koka's objection is about a held borrow keeping a large value alive, and nothing
      in AIF currently bounds that.

**Exit gate — restate before starting.** The standing text was *"allocation count on g2 and g6
must drop by ≥ 10×"*, and the note above is why that cannot be met by reuse tokens: neither program
contains the pattern they fire on. Either re-target the gate at `g7`, which does, or fold the g2/g6
allocation count into M3 where the mechanism that moves it already lives.

---

## M2 — closing state, 2026-08-23

**Five items done and gated; four retired after one named prerequisite and no workload trigger.**
Every item is either finished or closed with a reason, which is what "finished" means for this
milestone today.

| | |
|---|---|
| M2.0 · release on reassignment | **done** — g7 3599 leaks → 0 |
| M2.0b · callee-returned accumulators | **done** — probe 7 leaked → 1 |
| M2.1a · recursive releases for self-referential types | **done** — `test_73` 100 leaked → 0 |
| M2.1c · assignment re-initialises a moved binding | **done** — `acc = f(acc)` now compiles |
| M2.4 · borrow inference | **decided** — opt-in through existing annotations, no inference |
| M2.1a-ii · shallow free of a destructured block | **retired** — blocked prerequisite, no maintained trigger |
| M2.1a-iii · ownership transfer past one hop | **retired** — blocked prerequisite, no maintained trigger |
| M2.1 / M2.2 / M2.3 · tokens, specialisation, bounds | **retired** — reactivate only on the measured-workload trigger |

**All four retired items share the same prerequisite: `field_release_of` answers per
`(type, field)` and would need to answer per site.** Three independent confirmations, all measured:

1. **M2.1a blocks M2.1a-ii.** Making `Tree`'s payload fields released — correct, and what M2.1a is
   — makes *every* `Tree` site `site_in_released_field`, so a `sink` parameter holding one is never
   reclaimable and the shallow free can never fire. `g8` did not move by one allocation.
2. **`type_is_reclaimed` is "has a disposition", not "is actually reclaimed".** It is true for
   essentially every T2 struct type, so the released-field set is far wider than the values anything
   really frees. Its own comment says it exists for the T0 case, and for T2 it never says no.
3. **The call boundary has three owners, not one** — caller drop list, parent field release, caller
   temporary cleanup. A callee-side free that ignored the third read `3 allocated, 3 released,
   0 leaked` across 142 tests and **5 violations** on a four-line probe.

### Is the per-site disposition worth building? Not yet, and the check is one command

**It is a build, not a fix.** The per-`(type, field)` answer is *conservative* — it says "a parent
might free this", which prevents double frees. All seven corpus programs are `allocated ==
released`, 0 leaked, 0 violations today. Per-site would let the compiler reclaim *more*, not stop it
doing something wrong.

**And nothing measured has the shape.** Checked 2026-08-23:

```bash
grep -l "sink " aif/evidence/xlang/prismio/g[1-7]*.psm        # none
grep -l "^enum \|match (" aif/evidence/xlang/prismio/g[1-7]*.psm  # none
```

Zero corpus programs use `sink`; zero use payload enums or `match`; the only `sink` in `src/` is the
string literal in `checker.psm` implementing the convention. The one program with the shape is
`g8_tree_rebuild.psm`, **written in the same session that found the blocker** because the corpus had
nothing. Building this would make an author-supplied benchmark faster and move no standing number —
which is the trap M2 started in, where the gate promised 10× on two programs that do not contain the
pattern.

**Revisit when something real has the shape.** The honest trigger is the app framework: immutable
state updates over UI or AST trees are exactly the Perceus pattern, and M2.1c made that idiom
writable. Until a program that is measured does it, M4 is the better spend — measured projected
prize, and unblocked.

**What the next attempt must not do:** start at the match-binder keys. They were built, they work,
and they are not the blocker — see M2.1a-ii's notes. Start at the disposition, expect to touch
`field_release_of`, `type_is_reclaimed`, `compute_released_fields` and every reader of
`site_in_released_field`, and expect it to be the largest single change in the milestone.

**What M2 delivered against its original claim.** The standing text wanted an allocation-count drop
on g2 and g6 from reuse. M3 took both by a different mechanism and the note above says so. What M2
actually removed is **leaks, not allocations** — three classes of them, each a *missing owner*
rather than a missing free — plus one language capability (`acc = f(acc)`). No corpus program
allocates less because of M2, and none of its five gates moved the timing band: corpus medians
1.006×, 1.006×, 1.001×, all within noise.

**M3 took both halves, 2026-08-28: g2 10 285 886 → 82 052 (125×) and g6 50 470 → 3265 (15×).** So
the standing text is met by a different mechanism, which is exactly the reason a gate has to name
the mechanism as well as the number. **The note that g6 was blocked on obligation 2 was wrong** —
`br_param` is `recruit`'s, and its `Member`s genuinely outlive the tick; the transient allocator
cleared every allocation obligation and was refused on its call-site count. An M2 restated against
g7 is what is left.

---

### The restatement, 2026-08-23 — and "re-target the gate at g7" was a bad grep

**`g7` does not contain the pattern either. Nothing in the corpus does.** The note above says
`match` appears in `g7.psm` and `g7_substring.psm`; both hits are the word *match* in a comment —
"a port which tokenized differently could not match." `grep -n match aif/evidence/xlang/prismio/*.psm`
returns those two lines and nothing else. **There are zero `match` expressions in the whole
corpus**, so there is no program to re-target the reuse-token gate at, and M2.1–M2.3 cannot be
gated on a measured prize until one is written.

That is worth stating plainly rather than working around: **M2.1's exit gate is not "≥ 10× on some
program", it is "a program with the shape exists, and reuse tokens move it."** Writing that program
is the first task of M2.1, not a preliminary to it, and it should go in `aif/evidence/xlang/` with
Rust and Swift ports like every other `g`.

**What was in the way, and is now gone.** M2 is about a value that becomes dead and is reused
instead of freed. The compiler could not identify a value that became dead **at an assignment** at
all — it did not even free one. That is M2.0.

- [x] **M2.0 — Release on reassignment.** **Done 2026-08-23.** `g7` leaked **3599 of 5021
      allocations** — the `let mut out = ""` + `str_concat` accumulator, which is `buildSource` —
      while `HANDOFF.md` recorded a clean ledger for "all seven benchmark programs". Six of seven.
      The hole was **documented and deliberate**, in `src/ir/expr.psm` above `nodeAssignsName`: a
      reassigned binding was not droppable even when every value it received was owned, "since
      there is no drop on reassignment, so the strictness costs nothing that is not already lost."
      Both halves were true and held each other up, and the value ended up with **no owner at
      all** — a missing owner rather than a missing free, for the third time in four sessions.
      - **`aif_releases_on_overwrite_node`** is `aif_frees_at_scope_node` with the confinement
        clause relaxed and `AIF_E_GLOBAL` added back. An accumulator is never confined to the scope
        that allocates it, and `return out` puts E at `Caller` — for a value **no return ever
        carried**, because a return exits the function. Every other clause is untouched, and those
        are the soundness argument: aliasing, containers, released fields, arenas.
      - **`owns_slot` is a second flag, not `is_droppable`.** A returned accumulator must not be
        dropped at the scope exit and must still release what its assignments displace. Conflating
        them made `return out` silently disable the release.
      - **String literals are cloned**, at the declaration *and* at the assignment. Missing the
        second one shipped a compiler that built every program correctly and then aborted in libc
        at exit on `--verify` builds — `pointer being freed was not allocated`, on `.rodata`.
      **Result: all seven programs now report `allocated == released`, 0 leaked, 0 violations.**
      Suite 141/141, fixpoint `a31.ll == b31.ll`, differential 17/17, corpus median 1.002×
      (0.934–1.036×), RSS 0.992–1.010×. **GATE PASSED.**
      Evidence: [`RESULTS-M2-reassignment.md`](aif/evidence/RESULTS-M2-reassignment.md).
### M2.1's ground, surveyed 2026-08-23 — the shape is expressible and there is nothing to reuse yet

The first task was "write a program with the destructure-then-rebuild shape". It was written and it
**runs correctly**; what it found is that the *token* half of M2.1 has a prerequisite nobody had
named. Prototype (`build` a balanced `Tree`, `mapAdd` destructures and rebuilds every node,
checksum): depth 10, five passes, computes 528891 — arithmetically correct.

**What the language does support**, all verified against `build/S31b`:

- **Recursive payload enums compile and run.** `enum Tree { Leaf, Node(Tree, Int, Tree) }`.
- **`sink` gives the consuming destructure**, which is what reuse needs — the modifier goes before
  the name, `fn mapAdd(sink t: Tree, ...)`, not before the type.
- **A `sink` parameter of a flat struct, a `String`, or a one-level payload enum is released
  correctly** — 4 allocated, 4 released, 0 leaked on each.

**What it does not, and these are the constraints on the program:**

- **Patterns bind names only.** `Tree.Node(Tree.Node(a, x, b), y, c)` is "a variant pattern binds
  names, not expressions", so an Okasaki `balance` has to be written as nested `match` statements.
  The map/rebuild shape needs no nesting and is the token's home ground anyway.
- **`acc = f(acc)` in a loop is rejected** — "`acc` is moved inside a loop". Sema tracks move state
  per name in source order and **an assignment does not re-initialise a moved binding**, so the
  functional-update loop cannot be written. The workload uses recursion instead
  (`passes(mapAdd(t, 1), n - 1)`), which works. `ir_unmark_moved` already exists and is called for
  a `let`; not calling it for an assignment is the whole of the gap, and it is also why M2.0's
  rebinding guard turned out unreachable.

**The blocker: there is no drop for a reuse token to convert.** Perceus is drop-guided — `drop` +
`alloc` in one branch becomes `drop-reuse`. On a depth-3 tree, a `sink` consume reads **33
allocated, 3 released, 30 leaked**, and `__aif_release_Tree` **is never generated at all**. Two
independent clauses of `type_releases_of` (`runtime/aif_support.c`) each produce that on their own,
and both are deliberate, with reasons written next to them:

1. `if (nominals[nominal].is_enum) return 0;` — enums never own their payload.
2. A self-referential type hits the in-progress marker and reads as "does not release", because
   *"`struct Node { child: Node }` would otherwise have to know whether Node releases in order to
   decide whether Node releases"* — deferred to the cycle collector as C-MAYBE.

But the collector is not reclaiming it either: the summary says *"collector needed: 1 of 1 struct
types lie in or reach a non-trivial SCC"* while every site stays **T2/owned**, so neither path runs.
A tree has no cycles, so T4b is the wrong answer for it anyway — **the right answer is a recursive
generated release, which clause 2 declines by design.**

**So M2.1 is a fork, and it is an ARCHITECTURE-DIRECTION decision rather than a task:**

- **(a) Generated recursive releases for self-referential types.** Revisits clause 2's recorded
  reasoning — the in-progress marker can answer "yes" for a type whose recursion is through an
  *owning* field, since the recursion is structural rather than a value cycle. Gives M2.1 its drop,
  and closes a leak class that is currently unbounded for every tree-shaped program.
- **(b) Drive reuse off the RC/T4b path**, where recursive types are already supposed to live.
  Closer to Perceus, which *is* a reference-counting discipline, and it is the path CYCLES.md
  already argues for. Costs a count on every node.

**Do not pick this from the code.** Both clauses were written with their reasons attached, which is
the signal that changing one is a design decision and not a repair.

**Fork (a) was chosen, 2026-08-23, and half of it is built.** See M2.1a below. The remaining halves
are M2.1a-ii and M2.1a-iii, and the first of them is the same design as M2.1b.

- [x] **M2.1a — the drop, fork (a), half of it. Done 2026-08-23.** A self-referential type now has
      a generated recursive release: `field_closes_cycle`'s veto is replaced by a disposition test,
      so a re-entering field is released when every site it can hold answers `AIF_ELEM_TYPED` or
      `AIF_ELEM_OBJECT`, and a counted or collected one still declines because those edges are the
      collector's. `test_73_recursive_release` goes **100 leaked → 0**, with the allocation count
      identical at 106 — the feature reclaims, it does not allocate less. Suite 142/142, fixpoint
      `a35.ll == b35.ll`, differential 17/17, corpus median 1.006×, all seven corpus programs still
      `allocated == released`. Evidence:
      [`RESULTS-M2-recursive-release.md`](aif/evidence/RESULTS-M2-recursive-release.md).
      **Two failures on the way, and the second is the rule.** Removing the veto wholesale gave
      `test_52` 8 violations; the first repair — giving `AIF_ELEM_CYCLE` the release branch it had
      never had, since it was unreachable while the veto stood — turned that into a crash. The rule
      is not "recursion is safe", it is **"recursion is safe for the edges the collector does not
      own"**.
- [x] **M2.1a-ii — retired 2026-08-25; the shallow free of a destructured block. Attempted 2026-08-23, reverted, and
      the attempt is the useful part.** Built and measured: freeing the scrutinee block after the
      arm's binders took `g8` from **24570 leaked to 14335**, checksum unchanged. Then it was
      reverted, because it is unsound for a reason that reframes both this item and M2.1b.
      **`sink` is a sema-level move check, not a codegen ownership transfer.** Two things follow,
      both measured rather than reasoned:
      - **A `sink` parameter's tier is decided at the *caller's* site and may be T0.** In
        `sink2.psm` every `Tree` in `main` is `alloca %Tree` — stack — so the callee's free was
        `free()` on a stack pointer: **2 violations**, "released without being allocated". The
        callee sees only a pointer and cannot tell. *(The 4 allocated / 4 released this fixture
        reported before were `std/io`'s digit strings, not the tree — a vacuous reading that an
        earlier note took at face value.)*
      - **The caller still drops a binding it moved into a `sink`.** Move state belongs to sema and
        is cleared before codegen, so `let t = makeTree(); eat(t)` frees `t` in the caller. A
        callee-side free is then a double free even when the argument *is* heap.
      **So the callee cannot free — or reuse — its `sink` block without both halves:** a per-call
      fact that every value reaching the parameter is a heap block it may reclaim, and the caller
      dropping its claim. The first has a home already: `AIF_KEY_PARAM` (`aif_key_param(fn, index)`)
      keys the points-to set of a parameter, so the fact is the same shape as `field_release_of`'s
      agreement over a field's sites — require every one to be T2, move-only, not `in_container`,
      not `no_stack`, not in a released field. The second is a syntactic pass over the caller: a
      binding passed at a `sink` position leaves the drop list.
      **This is M2.1b's problem too, not only this item's.** A reuse token writes into the
      incoming block, so it needs exactly the same guarantee — which is why they are one design.
      **The prerequisite chain, established 2026-08-23 by inspection and measurement.** Three
      things, and they have to go in this order:
      1. **AIF must model match payload binders.** `src/aif/walk.psm` binds a VAR key for a
         `VARIABLE_DECL` (line 601), an assignment (621) and a parameter (1028) — and **nothing for
         a match binder**; `enumPayloadField`, `arm.child1` and "binder" appear nowhere in the walk.
         So `l` and `r` in `Tree.Node(l, v, r)` have no key, no sites, and no escape. **This is what
         decides shallow versus deep**: a block whose payloads were moved on needs its own block
         freed and nothing else, and one whose payloads were not needs the full release. Without the
         binder key the compiler cannot tell those apart, and picking either unconditionally is a
         leak in one direction and a double free in the other.
      2. **A reclaimability fact on the parameter**, consulted by *both* sides so they cannot
         disagree: `aif_key_param(fn, index)` keys the points-to set and `aif_fn_lookup(symbol)`
         resolves the function — codegen spells the symbol identically (`functionSymbolName` and the
         walk both use `s2` falling back to `s1`). Require every site to be T2, move-only, not
         `in_container`, not `no_stack`, not in a released field. A T0 site is what made the first
         attempt free a stack pointer.
      3. **The caller stops dropping.** Verified by measurement, not assumed: with
         `let t = makeTree(i)` passed to `eat(sink t: Tree)`, `main` still emits
         `__aif_release_Tree` for `t`. The caller half needs a callee-parameter lookup that codegen
         does not have today — there is no module global and no `findFunctionNamed`.
      **Second attempt, 2026-08-23: all three were built, and all three were reverted.** The tree is
      byte-identical to `S36b` again. What it established, in order of how much it changes the plan:
      - **(1) is done-able and is *not* inert.** Binding each payload name to its
        `aif_key_field(type, Variant$index)` value set — the same shape `let l = t.Node$0` gets —
        works. But it changes the compiler's own IR, so it does not clear the bar M3.2a set for
        landing a staged prerequisite (byte-identical output). **And it must not call
        `aif_con_live_in`**: claiming the payload is live in the matching scope said every payload
        outlives the arm, which pushed `sink2.psm`'s trees off the frame onto the heap — 4
        allocations became 10. The `MEMBER_ACCESS_EXPR` case does not claim it either, and a binder
        is a field read.
      - **(2) and (3) work and are still not enough, because M2.1a and M2.1b now fight.** With both
        halves in, `g8` did not move at all, and the trace says why in one line:
        `site_in_released_field` declines every `Tree` site. M2.1a made `Tree.Node$0`/`Node$2`
        released fields, so a payload is already spoken for by its parent's release, so a `sink`
        parameter holding one is never "reclaimable", so the shallow free can never fire. **The
        milestone's own previous step is what blocks it.** Resolving that needs the field
        disposition to be per-site rather than per-`(type, field)`, which `field_release_of` is not.
      - **A callee-side free collides with *three* existing owners, not one.** The caller's drop
        list (known), the parent's field release (above), and — found by measurement —
        **the caller's temporary cleanup**: `consumeStr(str_concat("ab", "cd"))` reads
        `3 allocated, 3 released, 0 leaked` today and **5 violations** with the transfer in, because
        something already reclaims a temporary passed to a call. `sink` transferring ownership is
        not a local change to the callee.
      **So the order in the list above is wrong.** Doing (1) first does not unblock (2) and (3); the
      thing that blocks them is the per-`(type, field)` disposition, and that is where the next
      attempt should start. Expect to touch `field_release_of` and everything that reads it.
- [x] **M2.1a-iii — retired 2026-08-25; ownership transfer past one hop.** The second reason `g8` does not move: a
      recursively-built tree returns sites belonging to its own recursive calls, so the caller owns
      nothing and no drop runs at all. INFERENCE 6's contexts, the same gap
      `test_47_aif_containers` records as its 2 after inline list storage removed four element
      boxes. **It also blocks measuring the recursive release's
      stack-depth limit**, since a deep structure has to be built recursively to exist.
- [x] **M2.1b — retired 2026-08-25; the token.** Only then: `drop` + same-size `alloc` in one branch becomes reuse.
      Gate: allocations on the rebuild workload fall to ~the tree's node count, once, instead of
      once per pass.
- [x] **M2.1c — assignment re-initialises a moved binding. Done 2026-08-23.** `acc = f(acc)` — the
      functional-update idiom, and the one M2.1b exists to optimise — could not be written at all.
      Two separate errors, and the second is the one that made it look like a loop problem when it
      is not:
      - **the move was reported as one that repeats.** `ir_binding_predates_loop` fires on any move
        of an outer binding inside a loop, which is right for `drop(b)` and wrong for an assignment
        whose target *is* the binding it moved from: the store puts a fresh value in the slot before
        the next iteration reads it. `ir_set_reinit_target` names the target while the right-hand
        side is checked, and the loop rule makes that one exception.
      - **the name stayed moved-from afterwards**, so the *straight-line* form failed too —
        `consume(s)` then `s = f("x")` reported "use of moved value" **on the assignment's target**.
        An assignment is the one place a moved-from name is legal. Cleared before the target is read
        as well as after the right-hand side's own move.
      `neg_10_move_in_loop` still fails, which is the other direction: `drop(b)` in a loop is still
      a move that repeats. Guard: `test_74_reinit_assignment`, **discriminating by construction** —
      it does not compile on the previous generation, so a regression is a build failure rather than
      a number. Suite 143/143, fixpoint `a44.ll == b44.ll`, corpus clean.

- [x] **M2.0b — the same for a callee-returned value. Done 2026-08-23.** `nodeProducesOwnedValue`
      now also accepts `aif_owns_call_result_at_node`, so an accumulator fed by a Prismio callee
      releases what it displaces: the probe goes `9 allocated, 2 released, 7 leaked` →
      **9 / 8 / 1**, and the remaining 1 is a two-hop return, not this.
      **The two guards were re-derived rather than assumed stale, and they are different.**
      `chainAssignsName == false` was there because an assignment could put a *borrow* in the slot
      and because nothing released what an assignment displaced — `irOwningAccumulator` rules out
      the first and M2.0 fixed the second, so it no longer applies to an accumulator.
      `chainReturnsName == false` is about the **last** value only, so it still guards the
      scope-exit drop and the declaration still applies it; it was never about a displaced value.
      Suite 142/142, fixpoint `a36.ll == b36.ll`, differential 17/17, corpus median 1.006×
      (0.944–1.042×), all seven corpus programs still `allocated == released`, seed path clean.
      `test_72_reassigned_ownership` now discriminates across three generations —
      18 → 8 → **2** leaked — so it guards M2.0 and M2.0b separately.

---

## M3 · Non-lexical and region-polymorphic regions

> **DONE, 2026-08-28. The prize was 2.16× on g2 and the inference now reaches it.** Plain
> `g2.psm` — no annotation, no source change — allocates **82 052** times against 10 285 886, and
> runs at **0.469×**: the same figure `region frame_arena` earns by hand. Corpus median 0.991×,
> the first movement in the band in eight sessions.
> [`RESULTS-M3-nonlexical.md`](aif/evidence/RESULTS-M3-nonlexical.md).
>
> *The entry as it stood, for the record: "Measured prize: 2.16× on g2, already proven by the
> annotation. `region` now serves 10,200,000 allocations and runs at 0.46× of plain g2. The
> mechanism works. **The inference does not reach it** — plain g2 still allocates 10,202,214 times
> with 0 arena objects."*

**Two recorded blockers, both named in the literature:**

1. *"The arena is lexical and allocation is not."* → **Spegion (2025)**: regions end at *last use*,
   computed by flow-sensitive dataflow, plus *sized* allocations.
2. *`in_container` rejects before escape is examined*, so a caller's region cannot reach a callee's
   allocations. → **Tofte–Talpin region polymorphism** — region parameters on functions — which is
   exactly the `CallerRegion` item.

**Concepts:** [non-lexical regions](#non-lexical-regions), [region
polymorphism](#region-polymorphism), [sized allocation](#sized-allocation).
**Papers:** Spegion (arXiv 2506.02182); *A Retrospective on Region-Based Memory Management* (HOSC
2004) — **read the retrospective before the original**, it documents where region inference fails;
Region-based memory management for Mercury.

- [x] **M3.1 — `CallerRegion` + container disposition.** **Built 2026-08-27.** Automatic
      placement now reaches a callee's allocations, which is what the second recorded blocker
      asked for. Three parts:
      - **The obligations were factored out, not copied.** `bracket_edge_ok` in
        `runtime/aif_support.c` asks SPEC 5.2.1.1's obligations of an *arbitrary* region scope
        instead of the one `enclosing_region` returns. It reads the call graph, the points-to
        graph and scope shape — **never `scopes[].arena`** — and that is the whole argument:
        `aif_place_arenas` can ask it about a scope it has not chosen yet, so the recorded
        circularity ("placement depends on bracketing depends on placement") is cut by making the
        dependency one-way rather than by weakening an obligation.
      - **`bracket_candidate_serves` feeds cross-function traffic into LAYOUT 7.1's cost model.**
        `arena_would_serve` could not see it by construction — `is_ancestor_or_self` is a lexical
        test on a per-function scope tree — so the frame-loop scope in `main` was never a
        candidate at all: its lexical sum is 0 because every DrawCmd is allocated inside `cull`.
      - **`bracket_place` now brackets into cost-model arenas**, not only `region`-pinned ones,
        guarded by an ordering flag so a bracket answer cached before placement cannot survive it.
      **Container disposition needed no work** — `elem_disposition_of`'s arena clause was landed
      inert several sessions ago *in anticipation of exactly this change*, and its comment says so.
- [x] **M3.4 — the corpus has a clean `--verify` ledger, 2026-08-28.** All seven benchmark
      programs report `allocated == released`, 0 leaked, 0 violations. Two causes, both a *missing
      owner* rather than a missing free:
      - **A `String` returned across a call had none.** `aif_owns_call_result_at_node` transferred a
        returned `List` or owning struct and declined the rest, because the completeness of a
        returned value set rests on the type having no literal form. `fn_returns_partial` derives
        the fact instead — a callee with one `return` it cannot place a site behind returns
        something the caller does not own — and `std/io.psm`'s formatter was rewritten to satisfy
        it. Every program that printed a number leaked before this; g2 went ~83 000 → 0.
      - **An inline struct field was reported as owning what it holds.** `field_release_of` said
        released, `generateReleaseFn` emitted nothing (the address is interior), and the value
        copied *in* was left with no owner at all — 4095 of g3's 5486. The analysis is now told the
        layout's own answer (`aif_struct_field_inline`), and the value with no binding is freed at
        the literal.
      **Peak RSS fell 0.49×–0.82× across the corpus** as a consequence, which is the standing "peak
      RSS reversed" candidate moving without anyone taking it.
      Evidence: [`RESULTS-M3-leaks-and-regime.md`](aif/evidence/RESULTS-M3-leaks-and-regime.md).
- [x] **M3.1c — g6 is placed, 2026-08-28.** Not obligation 2, whatever the line below M3.1 said.
      `plan_orders` clears every allocation obligation; what refused it was regime (a)'s call-site
      count, plus two things behind that. **Regime (a) widened** from "exactly one call site in the
      program" to "every call site bracketed into the same region" — the second is what SPEC's
      table actually asks for and the first is only a sufficient condition for it; `bracket_regime_ok`
      answers it per region and reads `scopes[].arena`, so it is a filter the callers of
      `bracket_edge_ok` apply and the obligations stay one-way. **The shared-body clause narrowed**
      to bodies that allocate: two engine accessors that do nothing but `list_get` were making the
      extent read as shared. **And the `@elem` points-to node is keyed on the container's full type**
      rather than its base, so `list_get(w.actors, i)` stops coming back holding `Order`s — with
      `elem_key_reconcile` restoring the base-keyed answer for any base with an unresolved spelling.
      50 470 → 3265 allocations, **0.599×**, 4.31× → **2.58×** of idiomatic Rust, RSS 0.491×,
      extent `[0,3]` of the tick body, 0 leaked, 0 violations.
      Evidence: [`RESULTS-M3-leaks-and-regime.md`](aif/evidence/RESULTS-M3-leaks-and-regime.md).
- [x] **M3.1b — the benchmarked `g2.psm` is placed, 2026-08-28.** M3.2c-ii + M3.2d derive the
      sub-block extent this entry said was needed: the frame body's extent is statements `[1,2]`,
      excluding both `clock_gettime_nsec_np` calls, and the program runs at **0.469×** — the same
      figure `g2_region.psm` earns by hand. `g2.psm` was not edited. The original entry, for the
      record: Its
      timing harness calls `clock_gettime_nsec_np` **inside** the frame loop, and an opaque extern
      in the region body is a sound rejection — it could be handed arena memory. `g2_region.psm`
      earns its 0.46× by hand-placing `region frame_arena` *between* the two clock calls, which is
      a sub-block extent. **So M3.2 is what unblocks the measured program, not more of M3.1**, and
      the corpus copy `g2_frame_loop.psm` — same workload, no harness — is placed automatically
      today. Do **not** "fix" this by editing `g2.psm`: it is the baseline every prior g2 number
      was measured on.
- [x] **M3.2 — Non-lexical extent**: end a region at last use rather than scope close.
      **Done 2026-08-28.** All five parts (a, b, c-i, c-ii, d) are in, and M3's exit gate is green:
      plain `g2.psm` serves 4 arena-placed sites unannotated and runs at 0.469×, corpus median
      0.991×, suite 140/140, fixpoint `a25.ll == b25.ll`.
      Evidence: [`RESULTS-M3-nonlexical.md`](aif/evidence/RESULTS-M3-nonlexical.md).
      The original entry, for the record:
      **This is what M3's exit gate now turns on**, because M3.1 built the placement machinery and
      the only thing keeping the *benchmarked* `g2.psm` out is that its frame-loop block also holds
      two `clock_gettime_nsec_np` calls. `g2_region.psm` gets its 0.46× by hand-placing the region
      *between* them; M3.2 is the compiler deriving that range.
      - [x] **M3.2a — statement positions.** Done 2026-08-27. `Site.stmt` and `CallEdge.stmt`,
            stamped through `aifWalkChain` by a **one-based** cursor (`0` = not in a statement
            list: a global needs a constant initializer and the language has no negative literal).
            A scope is a lexical *set* of statements and carries no order, so nothing downstream
            could express "ends at last use" without this. **Verified inert**: fixpoint holds and
            the IR is byte-identical to S19b for all 29 corpus programs and 72 test programs.
      - [x] **M3.2b — last use.** Done 2026-08-27. `scope_stmt[]` (per scope, the statement of
            *that* scope the walk is inside) plus `key_last_stmt[]`, fed by `aif_var_note_use` at
            every read of a reference. The array rather than one cursor is what answers a nested
            use: while the walk is inside an inner block, `scope_stmt[outer]` still names the
            statement of `outer` containing it, because only `outer`'s chain writes it. One slot
            per key suffices because statements are walked in source order, so the max lands on
            the last mention without knowing in advance which that is.
            **Verified inert *and* verified correct** — byte-identical IR across corpus and tests,
            and `AIF_STMT_TRACE=1` on `g2.psm` reports `main.cmds scope 92 stmt 2` against
            statements `0: t0=clock`, `1: cmds=cull`, `2: drawn=submit`, `3: t1=clock`. The derived
            extent is **[1,2]**, excluding both clock calls — exactly the range `g2_region.psm`
            places by hand. A field nothing reads yet is a field nothing has checked; "the IR did
            not change" only proves it inert.
            **Caveat M3.2c must honour:** `aif_var_note_use` reads `var_scope[key]`, which the walk
            is still LCA-merging, and skips when it is -1. The data is **not total** — a missing
            last use must fall back to the *lexical* extent, never to a narrower one.
      - [x] **The M3.2d fixture, written before the feature.**
            `tests/test_71_nonlexical_extent.psm`, five exit shapes: straight-line, `continue`
            after last use, `break` between allocation and last use, `return` from the middle, and
            nested extents whose ranges differ. Baseline on S22b:
            **79 allocated, 79 released, 0 leaked, 0 violations.** `allocated` may fall once an
            arena serves these sites; what must not change is that whatever stays on the heap is
            fully released and violations stay 0.
      - [x] **M3.2c-i — the range of a *placed* arena.** Done 2026-08-27. `arena_stmt_range`
            derives `[first, last]` in the region scope's own numbering: the start from the
            statement of each served site (for a bracketed one, the **call's** statement, since
            the site's own index is a position in the callee's block), the end from
            `key_last_stmt` over the keys holding what the arena serves. **Every uncertainty
            returns "whole block" rather than a guess** — a too-wide range is the arena already
            emitted, a too-narrow one frees memory still in use.
            Keys belonging to a *different* function are skipped rather than declined: they live
            in the bracketed extent and `region_confined` already proved those activations are
            gone before the region exits. Declining on them declined every bracketed region, which
            is all the interesting ones — that was the first version and the trace caught it.
            Verified: `AIF_STMT_TRACE=1` on `g2_frame_loop.psm` gives `arena scope 91 extent [0,1]`
            against `0: cmds=cull`, `1: drawn=submit`, then three statements holding nothing.
            Byte-identical IR vs S22b; suite 139/139.
      - [x] **M3.2c-ii — the range of a *candidate*, and this is the one that unblocked g2.**
            Done 2026-08-28, with M3.2d. `cand_stmt_range` derives the range **before** the
            accept/reject decision, from a served set drawn only from the call graph, the points-to
            graph and scope shape — the lexical half is `arena_would_serve` minus its one clause
            that reads a placement, the bracketed half is every call in the scope that passes
            `bracket_edge_ok_at(..., ask_opaque = 0)` and serves something. That makes it a
            **superset** of what c-i computes once the decision is made, so an opaque call outside
            it is outside the range codegen emits — which is the whole safety argument.
            `bracket_opaque_ok` then asks for the range only when there *is* an opaque call in the
            region body, so every other region in the program pays nothing.
            `stmt_range_over` is the half c-i and c-ii share, because two answers to
            "which keys hold what this arena serves" is a use-after-free.
      - [x] **M3.2d — range-aware codegen.** Done 2026-08-28. `generateBlock` walks
            `block.child1` with an index and opens/closes at `first`/`last` instead of at the
            braces; `aif_arena_range_first`/`_last` answer -1 for "the whole block", which is what
            every arena got before and what every uncertainty still returns.
            **Verified prerequisite:** the parser sets only `child1` on a BLOCK
            (`src/parse/stmt.psm:36`), while the AIF walk chains `child1`/`child2`/`child3` — the
            latter two are always empty, so the analysis and codegen numberings agree. If that
            ever stops being true the arena opens at the wrong statement.
            `generateRegionExits` and `ir_region_depth` needed no change: a `return`/`break`/
            `continue` inside the range sees the arena in the depth and pops it, one outside sees a
            depth that `ir_region_exit` already decremented.
            **The guard was not one, and rewriting it was most of the work.**
            `tests/test_71_nonlexical_extent.psm` placed no arena at all — five shapes sharing one
            `build`/`consume` pair made every callee `br-shared` under regime (a) — so its
            79/79/0/0 baseline measured a program the feature never touched. It now has nine
            builders (regime (a) needs one call site each) and consumes through `list_len` rather
            than a shared helper, because **any `list_get` outside the extent aliases every element
            site in the program** and un-brackets every other shape. 12 arenas, six exit shapes,
            loops of 80 so a missed pop trips `ARENA_MAX_DEPTH` rather than passing.
            Discriminating in both directions, by mutated compiler:
            [`RESULTS-M3-nonlexical.md`](aif/evidence/RESULTS-M3-nonlexical.md) §5.
- [x] **M3.3 — `region` warns when it serves zero allocations.** **Already built — this line was
      stale, verified against the tree 2026-08-27.** `report.psm` emits
      `region <name> serves no allocation; it costs an arena push and pop per entry and reclaims
      nothing` plus a repair note, and `region_diagnostics` asserts all four cases on
      `test_58_region_serves.psm`: it fires on the two inert regions and stays silent on the two
      that serve 50 allocations each, which is what makes it a discriminator rather than a
      substring search.
      **M3.1 falsified its note and the note was corrected in the same session.** It read "a value
      allocated in a callee cannot reach it", which is precisely what call-site placement changed.
      It now names the real conditions: a callee called from more than one place, or a region
      holding a call this compilation cannot see through.

**Exit gate:** the standard gate, plus plain `g2.psm` must serve **> 0** arena objects without any
annotation, and `region` on a zero-serving scope must emit a diagnostic.

**GREEN, 2026-08-28.** `g2.psm` serves 4 (2 of them the frame loop's, via a bracketed `cull`),
against 2 before — both of which were in `std/io` and neither in the program. The diagnostic half
was already green (M3.3). Suite 140/140, fixpoint `a25.ll == b25.ll`, differential 17/17, corpus
median 0.991× with g2 at 0.469×, **GATE PASSED**.
[`RESULTS-M3-nonlexical.md`](aif/evidence/RESULTS-M3-nonlexical.md).

---

## M4 · Views and slices

> **M4 is complete.** Mutable DataView reaches 0.25× of the boxed-layout diagnostic and 1.08×
> hand-tuned Rust SoA on g1, with a separately labelled hand-tuned Prismio arm at hot-loop parity.
> The generic-layout gate proves representation selection happens only after concrete
> monomorphisation.

**Read the correction before ranking what remains.** Inline `List<T>` storage was worth having
because it removes **allocations**, not indirection: Prismio's exact boxed layout in Rust, mutated
in place, runs at **0.86× of inline `Vec<T>`**. M4.2 now implements the safe flat subset. What
remains is that **views are the prerequisite for the layout work**.

**Concepts:** [data views](#data-views), [unboxed/flat layout](#unboxed-flat-layout),
[monomorphisation and flattening](#monomorphisation-and-flattening).
**Papers:** PPAM 2024 / arXiv 2502.16517 data views — **semi-manual AoS↔SoA**; OCaml unboxed types;
Java Valhalla JEP 401; MLton *Unboxing using Specialisation*.

- [x] **M4.1 — Views/slices in the language. Done 2026-08-25.** `Slice<T>` is a copyable
      `{ List handle, i32 offset, i32 length }` value; `a[start..end]` works on Lists and Slices,
      nested slices compose offsets, and indexing plus explicit `slice_set` resolve the handle on
      every access. Construction and access are bounds checked, overlapping mutable views are
      permitted, and list growth cannot strand an interior pointer because no interior pointer is
      stored. Generic parameters/returns/inference and debug info are covered. E-VIEW raises the
      underlying collection to the view's escape; the return-specific solver rule preserves a
      borrowed caller collection instead of spuriously making it T2. Direct `List<Slice<T>>` is
      rejected because the list's boxed slot is one word; wrapping in a struct preserves all three.
      Extern Slice parameters/returns are rejected until explicit marshalling exists.
      [`RESULTS-M4-slices.md`](aif/evidence/RESULTS-M4-slices.md).
- [x] **M4.2 — Inline element storage for `List<T>`.** Flat, non-counted, non-split struct
      elements are stored directly in the list block by default; pointer-bearing, counted, split,
      and unknown layouts stay boxed. Construction stamps the element mode from the list's static
      type, literal pushes use destination passing, every inline operation has a boxed fallback,
      and `PRISMIO_INLINE_ELEMS=0` retains the measurement control. The 149-test suite covers the
      allocation/layout and verifier consequences. The 2026-08-25 standing remeasurement below
      confirms that the old `rust_boxed` 1.24×–1.27× band is no longer representation-matched:
      after the inline-runtime default, g1/g2/g4 read roughly 1.13×, 0.20×, and 1.22×.
- [x] **M4.3 — Data views for layout**, the semi-manual AoS↔SoA framing: the programmer names the
      layout, the compiler converts. **More defensible than LAYOUT.md's automatic search** — the
      cost model already ranked two layouts the measurement rejected.
      - [x] **M4.3a — Name the conversion boundary, not a global type promise. Done 2026-08-25.**
            `soa(List<T>) -> DataView<T>` consumes a flat-struct row list into one real allocation
            per physical field; `aos(DataView<T>) -> List<T>` consumes it back, and `data_len`
            borrows it. Ordinary structs remain AoS everywhere else. `DataView<T>` is move-only,
            generic-aware, scope-released, excluded from T0/arenas and hot/cold splitting, and
            rejected at extern and unsupported aggregate-storage boundaries. Column offsets and
            sizes come from LLVM's target data layout, so padding and reordered/nested flat fields
            round-trip exactly. Suite **163/163**, fixed point, fresh-seed agreement, AIF
            differential **17/17**, source lists, packaged runtime and `--verify` are green.
            Existing-corpus median is **1.000×** new/old (25 runs); the isolated 2,000-row ×
            12-field round-trip costs **76.1 µs median / 91.3 µs p99** (**38.0 ns/row**). This is
            conversion cost only; M4.3b is where column-local work must earn it back.
            [`RESULTS-M4-dataview-a.md`](aif/evidence/RESULTS-M4-dataview-a.md).
      - [x] **M4.3b — Flat structs first, with `(collection handle, index)` element views. Done
            2026-08-25.** `DataView<T>` indexing produces a checked, non-escaping
            `(DataView handle, i32 index)` descriptor; field reads resolve the selected column at
            each access, including nested flat fields, without storing raw interior pointers.
            Saving a descriptor from an owned local view is rejected, while a descriptor borrowed
            from a `DataView` parameter is valid for that borrow. The suite is **164/164**, the
            compiler is at a fixed point, the AIF differential is **17/17**, and `--verify` reports
            **12 allocated / 12 released / 0 leaked / 0 violations** for the focused case. The
            standard corpus is flat at **1.004×** median new/old. A 200,000-row, 12-field,
            single-column scan is **0.903× AoS time** (**9.7% faster**, 25 paired runs), with p50
            falling from **105.6 µs to 95.9 µs** per scan. Peak RSS rises from **24.5 MiB to
            38.2 MiB** during conversion because the source rows and destination columns overlap
            transiently. [`RESULTS-M4-dataview-b.md`](aif/evidence/RESULTS-M4-dataview-b.md).
      - [x] **M4.3c — Round-trip and boundary gates. Done 2026-08-25.** Scalar and nested-flat
            field mutation lowers through the checked handle/index descriptor and survives the
            consuming SoA→AoS conversion; extern DataView boundaries remain explicitly rejected.
            Ready-view metadata is invariant and physical columns carry field-specific TBAA, so
            LLVM hoists stable lookup work without an unsafe language-visible interior pointer.
            Suite **164/164**, fixed point, differential **17/17**, packaged runtime and focused
            verifier **12 / 12 / 0 / 0** are green. The ordinary corpus is flat at **0.999×**
            median. On the 25-run g1 gate, DataView is **0.221× Prismio AoS**, **0.273× idiomatic
            Rust**, and **1.076× hand-tuned Rust SoA**; the boxed residual moves from **1.145×** to
            **0.253×**. A separately labelled hand-tuned Prismio arm fissions the three integration
            streams into small inlinable borrowing helpers and reaches **4.631 ms versus 4.666 ms**
            tuned Rust in a paired run: parity inside noise. The natural source remains the
            language result. [`RESULTS-M4-dataview-c.md`](aif/evidence/RESULTS-M4-dataview-c.md).
- [x] **M4.4 — Watch for the Valhalla collision. Done 2026-08-25.** Prismio's AST-to-AST,
      demand-driven monomorphisation structurally avoids an erased polymorphic container body:
      templates leave the module before sema, concrete types are substituted into clones, and only
      then does codegen ask the static `List<T>` element layout whether inline storage is legal.
      `test_82_generic_layout.psm` instantiates the same `singleton/get/set` templates for a flat
      16-byte struct and a pointer-bearing struct; the permanent gate extracts all six clone bodies
      and requires inline operations only in the first three. Focused verifier **8 / 8 / 0 / 0**;
      suite **166/166**. Because this milestone adds a discriminator rather than generated code,
      its 25-run A/A control is **0.997×** median (0.978–1.099×), explicitly no performance change.
      [`RESULTS-M4-generic-layout.md`](aif/evidence/RESULTS-M4-generic-layout.md).

**Exit gate:** the standard gate, plus a re-run of the `rust_boxed` residual — it should move for
the first time in eight sessions.

**M4.1's own gate is green:** suite **155/155**, fixed point, fresh-seed agreement, AIF
differential 17/17, source lists, and the milestone corpus gate. Existing non-Slice programs emit
the same IR after unused helper declarations were made conditional. The `rust_boxed` residual is
therefore deliberately unchanged; it is M4.3's exit signal, not a Slice-only signal.

---

## M5 · Allocator

> Cheap and mechanical. The RSS regression is explained and closed; this item is now about
> allocation cost only.

**Concepts:** [free-list sharding](#free-list-sharding).
**Paper:** Mimalloc (APLAS 2019) — built specifically as the backend for reference-counted
runtimes (Koka, Lean), which is Prismio's workload shape.

- [x] **M5.1 — Allocator evaluation complete; retain system malloc, 2026-08-26.** Dynamic
      interposition was followed by sound direct-seam experiments in which generated objects, the
      runtime, verifier shims, and curated inline bodies all selected the same allocator. Direct
      mimalloc v3.4.5 loses at **1.021×** corpus-median loop time and raises RSS **24.2%**; direct
      rpmalloc v1.4.5 is runtime-flat at **1.003×** and raises RSS **62.7%**. g1/g3/g4/g5 are
      reported separately, all checksums agree, all four ledgers are clean, compile time is flat,
      and static linkage grows executables. Both dependencies and the temporary production hooks
      were removed. The retained-system milestone gate is **0.998×** and 166/166. See
      [`RESULTS-M5-allocator.md`](aif/evidence/RESULTS-M5-allocator.md).
- [x] **M5.2 — Bisect the RSS regression. Closed by measurement, 2026-08-25.**
      The standing text was 0.84–1.00× → **1.09–1.60×** of idiomatic Rust, +27% (g5) to +86% (g6),
      Rust unmoved, with the fixed runtime footprint and the hot/cold split already excluded.
      **The cause was the leaks.** Removing the integer-print leak and the inline-field leak dropped
      peak RSS to **0.49×–0.82×** of the previous compiler across the whole corpus, in the same two
      changes that took the ledgers to zero — a leak scales with live set rather than churn, which
      is exactly the signature this entry recorded and nobody read as a leak.
      The owed cross-language measurement is now complete: the latest two isolated 25-run passes
      put Prismio at **0.89×–1.00× idiomatic Rust RSS**, with absolute pass-1 peaks g1 1.77, g2 1.94,
      g3 2.03, g4 2.11, g5 1.59, g6 2.31 MB. The original regression is gone, confirming the leak diagnosis.
      See [`RESULTS-final.md`](aif/evidence/RESULTS-final.md) and the two `results-current*.json`
      files beside the harness.

---

## Standing items, not milestones

*(The first two were promoted here from `SESSION-PROMPT.md` on 2026-08-28. That file is the live
prompt and this one is the plan — anything it tells the next session to do has to exist here as a
checkbox, or the two drift and only one of them gets read.)*

- [x] **The hot element accessor was never curated — fixed 2026-08-29, and it is the largest
      single speedup measured on this corpus.** M1.1 curated `list_get`; M4.2 then added the
      `_inline` family and taught `inlineOpName` to emit *those* wherever the element type is
      statically flat, and `PRISMIO_CURATED_OPS` was never updated. So codegen emitted
      `list_get_inline` and the curated module contained `list_get`, and every flat-element access
      in the corpus paid a real `bl` into a five-line function. g4's movement loop was **two calls
      per iteration and 2 NEON instructions in the whole program**.
      Found by disassembling the binary, against a record that attributed g4's gap to
      *"2.51× representation"* — it was not representation.
      **Corpus median 0.861×** (g4 0.576×, g6 0.715×, g5 0.754×, g2 0.861×), and the standing
      against idiomatic Rust moves from **0.90×–3.09×** to **0.92×–1.80×**: g4 3.07× → 1.77×,
      g6 2.87× → 1.77×, g3 now level at 0.97×, g9 still ahead at 0.92×. All checksums unchanged,
      87 programs at 0 violations, suite 174/174, fixed point.
      See [`RESULTS-curate-list-get-inline.md`](aif/evidence/RESULTS-curate-list-get-inline.md).
- [x] **Curating `list_set_inline` and `list_push_inline` was tried and is worth nothing —
      2026-08-29.** The blocker was real and removable: giving `list_release_source` and
      `list_inline_grow` external linkage makes `run_curated_closure_test` pass at 14 ops.
      (`list_copy_elem` never needed it — clang inlines it into both callers before curation.)
      Then it measured **0.999× corpus median** (range 0.981–1.024×) for **+3.1% compile time**
      (415 → 428 ms). **Reverted on the gate's own prize-over-cost rule.**
      The prediction that *"g6 and g2 are write-heavy so they would move"* was mine and it was
      wrong: they push in a **setup phase**, not in the hot loop. Read is what the loops do.
      Recorded as a waiver in `run_curated_emits_test` so the next reader sees the measurement
      rather than the blocker. Re-attempt only with a program whose *hot loop* pushes — and check
      such a program exists first.
- [x] **Nothing checked that the ops codegen emits are the ops the curated set contains — closed
      2026-08-29.** `run_curated_emits_test` parses `inlineOpName` (`src/ir/expr.psm`) and
      `PRISMIO_CURATED_OPS` (`runtime/build_driver.c`) and requires every emitted op to be curated
      **or waived with a recorded reason**. Observed discriminating: with `list_get_inline` removed
      from the set it reports exactly that name. The waiver half matters as much as the check — it
      also fails if an op is waived *and* curated, so removing a blocker and updating only one of
      the two lists is caught from either side.
- [ ] **The corpus does not vectorize, and the cause is now measured rather than guessed.**
      After curating the accessor, `system_movement` is call-free and still emits **0 NEON**.
      **It is not array aliasing** -- that was the first hypothesis and it was priced and killed:
      `restrict` on the two component arrays is worth **1.11x** and both arms already vectorize.
      The faithful model is the one that keeps the *List header* indirection, and it separates
      cleanly into two costs:

      | arm | time | NEON |
      |---|---:|---:|
      | header reloaded per element (what we emit) | 20.52 ms | 2 |
      | bounds check + `elem_size` branch removed | 10.37 ms | 2 |
      | header loads hoisted, flat indexed loop | **7.79 ms** | **6** |

      **The two branches are the bigger half at 1.98x, and removing them alone does not
      vectorize**; hoisting the header is a further 1.33x and is what unlocks it. Together
      **2.11x-2.63x** on g4's movement shape, which is currently 1.80x of idiomatic Rust.

      **The `elem_size` branch is pure waste and codegen already knows the answer.** `inlineOpName`
      picks `list_get_inline` *only* where `inlineElemSizeOfList(expr) > 0` -- the element type is
      statically flat and the size is a compile-time constant -- and then the runtime reloads
      `l->elem_size` and branches on it anyway. Emitting `data + i * <const>` in codegen removes the
      load, the branch, **and makes the stride a compile-time constant**, which is the same fact
      `src/ir/expr.psm` already credits for DataView: *"the row type makes the stride a
      compile-time LLVM type rather than the runtime column's dynamic byte size. That is what lets
      a column scan vectorise."*
      **The hazard to design around first**: a statically-known element size is a property of the
      *expression's type*, and the runtime stamp (`list_set_elem_inline`) is a property of the
      *list value*. A list arriving from elsewhere unstamped would take the boxed path at run time
      while codegen assumed the flat one. That is a wrong-address read, not a leak, so the stamp has
      to be proved and not assumed.
      **Not attempted** -- a wrong answer here is a memory-safety bug, and it deserves its own
      session rather than the tail of one.
- [x] **g1's 1.083x "regression" was measurement noise — corrected 2026-08-29.** It was recorded
      here as real and attributed to a mechanism (one list per iteration rather than two, so
      inlining trades a call for six header loads and two branches). Re-measured at best-of-9 with
      **byte-identical IR** on both sides, g1 reads 20.14 ms before and 19.69 ms after — the
      opposite sign — and across the day's runs it lands anywhere in 0.98x-1.08x. The mechanism was
      fitted to a single sample. Nothing regressed; the final session corpus has **every** program
      at or below 1.0x (range 0.587x-0.998x).
- [ ] **Scoped alias metadata: priced at 1.40x, does not vectorize, and NOT worth building on
      this evidence.** The fact — the element store cannot reach the List header, because the header
      and its `data` block are separate allocations — was tested directly by giving the model a
      *local copy* of the header, which is an `alloca` the store provably cannot reach and is
      exactly what the metadata would license:

      | arm | time | NEON |
      |---|---:|---:|
      | header reloaded per element (what we emit) | 20.51 ms | 2 |
      | **aliasing fact given (local header)** | **14.62 ms** | **2** |
      | bounds + `elem_size` branch removed | 10.42 ms | 2 |
      | both — header hoisted, flat loop | 7.79 ms | 6 |

      **1.40x, and still scalar.** The branches survive and they are what keeps it from
      vectorizing, so the metadata buys the smaller half of the prize for machinery that has to
      span the curation boundary. Revisit only together with the branch half.

- [x] **Three optimisation hypotheses tested and killed, 2026-08-29.** Recorded so nobody spends
      the day re-deriving them:
      1. **`noalias` on the component arrays**, from AIF's aliasing lattice — `restrict` is worth
         **1.11x** and both arms vectorize without it. The wrong question: the arrays were never
         the problem, the List header is.
      2. **IRCE** (LLVM's inductive range check elimination, not in the default `-O2`) — the loop's
         bounds check *is* a range check on an induction variable, so it looked ideal. Worth
         **nothing**: `O2,irce,O2` measured 14.10 ms and the control `O2,O2` measured **13.82 ms**,
         so the entire apparent gain was the second `-O2` and IRCE made it slightly worse.
      3. **A second `-O2` over the merged module** — **1.49x on the model and 1.80x SLOWER on the
         real g4** (38.5 ms -> 69.4 ms, checksums equal, same executable size). The synthetic model
         has now mispredicted the real program twice; price pipeline changes on the corpus, never
         on a model.
- [ ] **`!invariant.load` on the List header would hoist it, and would be unsound.** The mechanism
      exists -- `ir_mark_data_view_lookup_loads_invariant` does exactly this for the three DataView
      lookups, justified by *"ready DataView metadata does not change before the view is consumed"*.
      A `List`'s `len`, `data` and `elem_size` **do** change: `list_push` and `list_inline_grow`
      rewrite all three. Marking them invariant would break any loop that both pushes and reads.
      Recorded so the next reader does not reach for the obvious tool.
- [x] **Re-measure `RESULTS-final.md`, before ranking anything. Completed and refreshed
      2026-08-25.** The default-off run first established 1.09×–3.41×. After making the curated
      runtime merge the default, two more 25-run passes with matching cross-variant checksums put
      the working-tree candidate at **1.10×–3.11× idiomatic Rust**. g2 is **1.76×**, g6 is
      **2.71×**, and g4 remains widest at **3.11×**. Peak RSS is **0.89×–1.00× Rust**; compile time
      is 67–85 ms against rustc's 107–137 ms, and executables remain 77–78 KiB.
      Evidence: [`RESULTS-final.md`](aif/evidence/RESULTS-final.md),
      `aif/evidence/xlang/results-current-inline-runtime.json`, and its pass-2 companion.
- [ ] **Decide `PRISMIO_INLINE_RUNTIME`'s default — candidate implemented; remote CI pending.**
      - [x] Make the merge default-on while retaining `PRISMIO_INLINE_RUNTIME=0` as an opt-out.
      - [x] Add a discriminating suite check that requires the successful merge marker and proves
            the opt-out avoids it. Because the normal suite runs on Windows, Linux, and macOS,
            this closes the old “silent fallback can look green” hole without a separate workflow.
      - [x] Local gate: fixpoint, fresh-seed agreement, AIF differential 17/17, suite **150/150**,
            and milestone corpus median **0.948×** (range 0.635×–1.000×), RSS flat, checksums equal.
      - [ ] Observe that new check green on the remote three-platform CI matrix. **Pushed and run
            on 2026-08-29, and the matrix answered: the default is NOT portable as it stands.**
            Windows built and then failed *every* suite test with
            `expected memory location (argmem, inaccessiblemem)` while assembling the curated merge.
            Cause: the compiler links the provisioned LLVM-C but the native build step shells out to
            a bare `clang` from `PATH`, and on `windows-latest` those were different versions --
            LLVM 22 writes `memory(..., target_mem0: none, target_mem1: none)` and the image's older
            clang cannot parse it. macOS and Ubuntu never got that far: `setup_llvm.py` took a
            **403** from the GitHub API, which is the unauthenticated per-IP rate limit and not a
            missing release. **A control branch at `97ef065` fails identically**, so both predate
            the ownership work. Two fixes are in the tree -- `GITHUB_TOKEN` on the provisioning step,
            and the provisioned LLVM's `bin` prepended to `PATH` -- and the parent stays unchecked
            until a green matrix is actually observed. The durable fix for the Windows half is
            arguably in `build_driver.c`, which should take clang from `llvm-paths.json` rather than
            from `PATH`, so there is one answer to "where is LLVM" as that file already claims.
            **Second run, after both fixes: both worked.** Windows went from every test failing to
            **168/174**, and the six that remain are real Windows gaps seen for the first time —
            `--jit` symbol resolution, `--target`, verify mode, and the zero-analysis equivalence
            check. macOS and Ubuntu got past the 403 and then failed on asset *naming*: LLVM 22
            ships `LLVM-22.1.8-macOS-ARM64.tar.xz` and `LLVM-22.1.8-Linux-X64.tar.xz`, while every
            pattern in `setup_llvm.py` knew only the older `clang+llvm-<version>-<triple>`, which
            survives for Windows alone. Patterns updated.
            **Third run: the patterns were right and the *packaging* is the problem.**
            `LLVM-22.1.8-Linux-X64.tar.xz` downloaded and extracted, and then
            `setup_llvm.py` correctly refused it — it ships no `llvm-c/Core.h` and no shared link
            library, so a downloaded release **cannot satisfy the C API dependency at all** on
            macOS or Linux. Windows never hit this because it uses `clang+llvm-<triple>`, which does
            carry them. Both platforms now install LLVM natively before `setup_llvm.py` runs (brew;
            apt.llvm.org), which also puts one LLVM on PATH for both ends of the build.
            `setup_llvm.py` additionally learns the *versioned* Homebrew keg — `llvm@22` is keg-only
            at `opt/llvm@22`, and only the unversioned formula gets `opt/llvm`, which tracks
            whatever major is current and is the one a pinned check is most likely to reject.
            **Fourth run: both Unix platforms got past provisioning** and then failed at
            `tools/bootstrap.sh: Permission denied` (exit 126) — the four `tools/*.sh` scripts were
            committed **mode 100644** despite carrying shebangs, and the workflow invokes
            `tools/bootstrap.sh` directly. Nothing had ever reached that line on a Unix runner
            before, which is the whole reason this gate exists. Modes are now 100755.
            **Fifth run: macOS went fully GREEN** — the first platform ever to pass this matrix.
            Ubuntu got to the *link* step and failed with `cannot find -lLLVM-C`: apt.llvm.org's
            `llvm-N-dev` ships `libLLVM.so` and no LLVM-C at all, while Homebrew and the Windows
            package ship `libLLVM-C.dylib` / `LLVM-C.lib`. `setup_llvm.py` had always recorded which
            library it validated, in `link_library`; `tools/bootstrap.sh` and `build_driver.c` both
            read the include and lib *directories* from that file and then hardcoded the library
            *name*. Both now derive it — drop a leading `lib`, truncate at the first dot — which
            extends "one answer to where is LLVM" to *which library*, as `build_driver.c` already
            claimed.
            **Sixth run: macOS is GREEN and stays green**; ubuntu reached the suite at 170/174 and
            windows at 168/174. The inline-runtime checks themselves pass on all three — what is
            left red is `test_73`'s heap corruption and `--jit`, both pre-existing and both their
            own items below.
            **The parent stays unchecked until a matrix is observed green.**
- [x] **`test_73_recursive_release` corrupted the heap on every platform except this one — fixed
      2026-08-29.** A payload-free enum variant filled its unused *pointer* payload slots with
      freshly `malloc`'d nodes that nothing ever wrote to — not even the tag — and
      `__aif_release_Tree` then read their contents as child pointers. macOS returns zeroed pages
      from a fresh `malloc`, so it worked by accident; glibc and the Windows heap do not.
      `semaZeroValue` answered every `TypeKind.STRUCT` field with an empty struct literal; it now
      asks `fieldTypeFor`'s question — inline iff the annotation is POD, read **byDecl** — and
      returns `none` for a pointer field. **Reproduced on this host only under AddressSanitizer**,
      by building the emitted IR against the runtime by hand; `MallocScribble` and friends were not
      enough. Also **1.82× on `g8_tree_rebuild`** (246,459 → 135,208 ns) with the checksum
      unchanged, because half that program's allocations were fillers: 24,572 → 12,284.
      Suite **174/174**, differential 18/18, fixpoint, corpus median 1.002×, 3 of 129 programs
      changed IR. See [`RESULTS-enum-zero-value.md`](aif/evidence/RESULTS-enum-zero-value.md).
      **Still to observe:** the matrix agreeing — this is a fix validated by a sanitizer on the one
      platform that never failed.
- [ ] ~~**`test_73_recursive_release` corrupts the heap, on every platform except this one.**~~
      The most serious thing the matrix found, and it **predates the 2026-08-29 work** — a control
      branch at `97ef065` carrying only the CI fixes reproduces it exactly.

      | platform | result |
      |---|---|
      | ubuntu-latest | exit **-11** (SIGSEGV) |
      | windows-latest | exit **3221226356** = `STATUS_HEAP_CORRUPTION` |
      | macOS | passes, `106 allocated / 106 released / 0 leaked / 0 violation(s)` |

      **`--debug` passes and release does not**, so it is the AIF-driven release path —
      `__aif_release_Tree`, from M2.1a's recursive release for self-referential types. The tree is
      **depth 3**, so it is not stack exhaustion. macOS's allocator tolerates whatever it does;
      glibc and the Windows heap do not. It also survives `MallocScribble`/`MallocGuardEdges` here,
      so this host cannot reproduce it at all — a Linux or Windows runner is the only instrument.

      It takes three of the four Ubuntu failures with it: the execution failure itself, the
      zero-analysis behavioural-equivalence check (`stdout differs between release and --debug`),
      and `aif_verify` (`no aif-verify report` — it dies before printing one).

- [ ] **Windows- and Linux-only suite failures.** With the toolchain fixed, ubuntu reached
      **173/174** once the enum zero-value fix landed and windows ~168/174; a control at `97ef065`
      scores 168/172, so all of these predate this session's work.
      **`--jit` has a candidate fix awaiting the matrix (2026-08-29).** `ir_jit_run_main` resolves
      the jitted module's externals with `LLVMOrcCreateDynamicLibrarySearchGeneratorForProcess`,
      which is a `dlsym` on the running process. On Mach-O an executable's own symbols are visible
      there by default — which is why `--jit` has always passed on this host — and **on ELF they are
      not without `-rdynamic`**. That matches the reported failure exactly: the unresolved list is
      `prismio_argv` plus the `std.io` functions that depend on it. `-rdynamic` is now passed by
      `tools/bootstrap.sh` and by `build_driver.c`'s compiler link, not on Windows, where clang-cl
      does not take it and the JIT's symbol story differs. **Unverified until the matrix runs it.**
      Still open beyond that: `--target` and `test_76_std_fs` on Windows, neither reproducible here.
- [x] **Reclaim overwritten boxed `OBJECT` list elements through an explicit exclusive operation,
      2026-08-26.** `list_set_exclusive` is admitted only for a locally created boxed-struct List
      whose scoped capability has not been cleared by element access, slicing, or an arbitrary
      borrowing call. It releases the displaced element through the List's actual disposition and
      typed releaser. Ordinary `list_set` remains conservative; no partial source-order lifetime
      approximation was added. The discriminator moves **4 allocated / 3 released / 1 leaked** to
      **4 / 4 / 0**, while observed and inline cases are compile errors. Fixed point, suite
      **169/169**, differential 17/17, and the **1.002×** milestone gate are green. See
      [`RESULTS-boxed-replacement.md`](aif/evidence/RESULTS-boxed-replacement.md).
- [x] **Genuinely-cold compile regression — attributed by stage and closed, 2026-08-26.** The
      cost was never the extract or the merge (2.3 ms together): a cold inline-runtime build ran the
      C frontend and the `-O2` middle end over `lang_runtime.c` **twice**. The curated intermediate
      is now bitcode, is retained for the rest of the build, and the runtime object is lowered from
      it with `-Xclang -disable-llvm-passes` — target backend only. Bitcode rather than textual IR
      because that round trip produces an object **byte-identical** to `clang -O2 -c` and the
      textual one does not. Cold and `PRISMIO_OBJ_CACHE=0` builds are **0.804–0.818×** of the
      previous compiler with the cached paths unmoved (0.984–1.002×), and the inline-runtime cold
      penalty falls from 1.359×/1.334× to **1.103×/1.091×** on g1/g6. Codegen-neutral by
      construction and by check: emitted IR is byte-identical everywhere and the **linked
      executables are byte-identical**, which is stricter than this host's floor. `--save-temps`
      was measured (200 ms against 145 ms) and rejected. `PRISMIO_BUILD_TRACE=1` is the stage trace
      that made the attribution possible and is now maintained. It fails open like the merge, so
      `run_runtime_object_from_ir_test` requires the `(from IR)` stage on the cold path and its
      absence under the opt-out; a `PATH` shim that refuses the flag was used to observe the test
      failing, so the assertion is not vacuous. Suite **170/170**, differential 17/17, milestone
      **1.000×**. See [`RESULTS-cold-compile.md`](aif/evidence/RESULTS-cold-compile.md).
- [x] **Keep the corpus honest — the corpus has a concurrent program, 2026-08-26.** `g9_bands` is a
      per-frame parallel reduction: four `spawn`ed bands, joined at the frame boundary. Two Rust
      ports, and the split between them is the result — `g9_idiomatic.rs` is `std::thread::spawn`
      per frame (the honest peer, one OS thread per task either way) and `g9_tuned.rs` keeps four
      workers alive over channels (what a tuned Rust program does). `aif_differential.py` globs the
      corpus, so 17 sources became **18** and `spawn` is now in the differential.
      **Prismio beats idiomatic Rust here**: loop **0.89×**, p50 0.90×, p99 0.90×, p999 0.91×,
      RSS 0.83×, allocations **0.13×** — measured twice on two harnesses (0.89× and 0.92×) with an
      A/A floor of 1.001×, tighter than g1's 1.098×. The mechanism is E-SPAWN-J: Rust's
      `std::thread::spawn` needs a `'static` closure and boxes it every frame, while a proved join
      keeps the argument **T0/stack** and allocates nothing.
      **Hand-tuned Rust is still 1.45× faster** — a thread pool does not pay `pthread_create` per
      frame and Prismio has no way to express one. That is a language question, not codegen.
      See [`RESULTS-concurrency.md`](aif/evidence/RESULTS-concurrency.md).
- [x] **The task handle had no owner — fixed 2026-08-26.** `prismio_task_release` existed from the
      day tasks did and codegen never emitted it, so every `spawn` leaked one handle. Invisible to
      `--verify` because the handle is plain `calloc` (correctly — it is a runtime temporary the
      runtime frees itself); `allocount` read **8,201 allocations against 23 frees** on g9. Now
      released at the **scope exit**, not at the join: a handle is copyable, nothing stops a second
      join, and a scope exit runs once after all of them. Emitted only where E-SPAWN-J already
      proved the join, so a task that may still be running is never freed under.
      **frees 23 → 8,019, RSS 2.1 → 1.5 MB (1.17× → 0.83× of Rust), loop flat at 1.002×.**
      `run_task_release_test` asserts the release is emitted for a proved join and **withheld** for
      a copied handle and an unprovable one; it fails against the pre-fix compiler.
- [x] **A binding that escapes through a callee's *return* was freed under its caller — fixed
      2026-08-29.** Not a leak: a **use-after-free**, and `--verify` reports `0 violation(s)` while
      it segfaults, because the allocation is released exactly once and simply in the wrong frame.
      `aif_owns_call_result_at_node` makes a callee-allocated value droppable and E cannot guard it
      (a returned value is already `Caller`), so the guard was the syntactic `nodeReturnsName` —
      which sees `return t` and not `let x = passthru(t); return x`.
      `aif_fn_may_return_param` is the missing fact, read off `pt[RET(f)] ∩ pt[PARAM(f,i)]`;
      `nodeEscapesThroughCall` is the guard, and it is **driven from the `return`, not from the
      argument**, because the cheaper direction declines `let same = identity(items)` in
      `test_47_aif_containers` and costs a correct drop.
      Discriminator `tests/test_85_passthrough_escape.psm`, **observed at exit 139 (SIGSEGV)**
      against `build/nostr-4`. Suite **173/173**, differential 18/18, fixed point, IR
      **byte-identical on 127 of 128** programs and executables byte-identical on all seven corpus
      programs; corpus median **1.000×**, compile time 418 → 417 ms.
      **One guard this was told to build does not exist and does not need to**: a Prismio callee
      cannot retain a by-value parameter, because sema rejects it — *"cannot move out of borrowed
      value"*. The retention half is the type system's, not the analysis's.
      See [`RESULTS-passthrough-escape.md`](aif/evidence/RESULTS-passthrough-escape.md).
- [ ] **The same escape, through an `extern` declared `alias`, is still open.**
      `let t = f(); let x = <extern alias>(t); return x` frees `t` at the scope exit.
      `aif_fn_may_return_param` deliberately answers *no* for a symbol it does not know, because
      "unknown" there means extern and answering yes declines the drop at every `print(value)` in
      `std/io.psm` — measured, and it costs three suite fixtures. The answer for an extern lives in
      `aifFfiAliasOf` (`src/aif/contracts.psm`), which is a hardcoded table whose only entry is
      `expect`, so closing this is a frontend change. Same shape as the fixed item above; narrower,
      because it needs a declared `alias` to reach.
- [x] **An owned call result consumed directly as an argument now has an owner — 2026-08-29.**
      Codegen asks `aif_owns_call_result_at_node` in **argument position** as well as at a binding,
      and releases the temporary once the enclosing call returns — the caller is the last owner,
      because a Prismio parameter is a borrow (Swift's `@guaranteed`). The discriminator moves
      **92/52/40 → 92/92/0** with both halves still printing 3010520; five other fixtures improved
      and none regressed. **86 programs under `--verify`, 0 violations.** Suite **173/173**,
      differential 18/18, fixed point, corpus median **0.999×**, compile time flat (421 → 417 ms),
      Rust standing unmoved (g9 0.90×). Asserted through `expected_leaks` rather than exit status,
      and **observed failing** at "40 leaked, expected 0" against the pre-fix compiler.
      **Three conditions gate the release**, each a reachable hazard: a known Prismio callee, a
      callee that does not return one of its parameters ([[aif_fn_may_return_param]], from the item
      above), and a result carrying no pointer — which covers a returned *view*, whose provenance
      the set intersection cannot see. **`spawn` is excluded structurally** and must be: a spawned
      task may still be running, and `SPAWN_EXPR` lowers through its own codegen path.
      **The retention guard this item asked for does not exist and is not needed** — sema rejects
      moving a by-value parameter into a container, and the field-store route is already declined by
      `site_in_released_field`. See
      [`RESULTS-owned-temporary-argument.md`](aif/evidence/RESULTS-owned-temporary-argument.md).
      Still open, and recorded there: `spawn` (needs a join-time release, `g9_helper_leak.psm` is
      the fixture), and a pointer-carrying enclosing return.
- [ ] **A `spawn`ed call's owned temporary argument still has no owner.** The argument-position
      release above is withheld for `spawn` because a spawned task may still be running when the
      `spawn` returns, so the release point has to be the **join**, not the call. The premise is
      already there — INFERENCE 4.1's E-SPAWN-J is what licensed the task-handle release at the
      scope exit — so this is the same shape a second time: release at a point that runs once, after
      every join. Fixture: `aif/evidence/xlang/prismio/g9_helper_leak.psm`, which leaks on purpose
      and whose IR this change deliberately left byte-identical.
- [ ] **The argument-position release is withheld when the enclosing call returns a pointer.**
      A blunt third condition: `strConcat(a, band(...))` gets no release even though `strConcat`
      demonstrably does not hand back its parameter. It is there because
      `aif_fn_may_return_param` intersects *sites* and a callee returning a **view** of a parameter
      carries provenance instead (SPEC 8.4), so the intersection is silent about it. Sharpening
      means teaching the predicate about view provenance — not relaxing the condition.
- [x] **Ownership survives a second return — 2026-08-29.** `aif_owns_call_result_at_node` required
      `sites[s].fn == c->fn`, which is one hop and declined every producer written in Prismio the
      moment a second frame appeared. **12/7/5 → 12/12/0** on `tests/owned_return_depth2.psm`.
      **It was not a fixed-point change**, which is what this entry and `SESSION-PROMPT.md` both
      predicted. The two halves come apart: *"no intermediate frame owns it"* needs nothing
      computed, because **returning a value already implies not dropping it** — `nodeReturnsName`
      and `nodeEscapesThroughCall` decline every frame on the path. (That second guard is the
      pass-through fix from earlier the same day; this item was blocked on it and the dependency
      was invisible until it existed.) And *"escaped through every intermediate frame"* was
      approximating the hazard the old comment names exactly — a value handed **in** and handed
      straight back belongs to the caller's argument — which is `fn_may_return_param`, now asked
      directly. The guard became a disjunction, so nothing safe became unsafe.
      **`test_47_aif_containers` 2 → 0** (its note said two hops needed INFERENCE 6's contexts; it
      did not) and **`test_72_reassigned_ownership` is migrated to native `std.string`** at last —
      48/46/**2**, the same 2 leaks the C version had, against the 48/35/**13** its header recorded
      for a premature migration.
      Suite **175/175**, differential 18/18, fixpoint, 87 programs at 0 violations, **ASan clean on
      all six changed programs**, corpus median 0.993×.
      See [`RESULTS-owned-return-depth2.md`](aif/evidence/RESULTS-owned-return-depth2.md).

- [x] **The C string layer is gone, 2026-08-26.** 1,093 call sites in `src/`, 109 in `ums/` and 82
      in `tests/` moved off `extern fn str_*` onto native `std.string`; twelve C functions and the
      orphaned `StringArray` deleted (`lang_runtime.c` 2,192 → 2,041 lines), with their AIF
      contracts removed from `src/aif/contracts.psm` and `aif/prototype/aif.py` together.
      `str_slice` went with them: it existed only to avoid a `strlen` that a fat String no longer
      performs. **Parse+sema is 0.843×**; full emit is 1.030× and a whole build is flat.
      Emitted IR is byte-identical on all 94 corpus and test programs. Suite **172/172**.
      See [`RESULTS-string-migration.md`](aif/evidence/RESULTS-string-migration.md).
- [x] **`Int` stays signed 32-bit, decided by measurement 2026-08-26.** The index-width argument
      (Go's and Swift's) is worth **zero** on both targets — i32-wrapping, i32-`nsw` and i64 indices
      all read 0.225–0.226 ms, AArch64 emits no `sxtw` and x86-64 one `movslq` in every arm. Making
      overflow UB to unlock `nsw` is worth **less** than zero: adding `nsw` to the compiler's own
      emitted IR for g1/g3/g4 gives 1.014×/1.006×/1.005×. Rust RFC 0212's density argument is the
      one that holds — 64-bit fields cost **1.330×** in Prismio on a corpus-shaped traversal and
      1.76–2.15× in the C control. See [`RESULTS-int-width.md`](aif/evidence/RESULTS-int-width.md).
- [x] **Debug-mode integer overflow checking — landed 2026-08-29.** `--overflow-checks`, off by
      default, RFC 0560's "check in debug, wrap in release". Six entry points
      (`ir_{add,sub,mul}_checked` and the `u` family) lowering to `llvm.s*/u*.with.overflow`, a
      branch, and `prismio_overflow_trap`, which names the operator and the source position.
      **Provably inert when off**: emitted IR byte-identical on all 128 programs, and the suite
      check asserts the *absence of the intrinsic*, not merely the absence of a trap.
      **The recorded premise did not survive measurement.** "A native `llvm.sadd.with.overflow`
      lowering should be cheaper than a sanitizer" is **false** — the two are within noise
      (5.36×–5.95× vs 5.42×–5.72×), because the cost is not the check but the branch, which defeats
      vectorization outright: the plain loops use 17 NEON registers and both checked forms use none.
      **And the 4.1–4.4× does not transfer to whole programs**: on the corpus it is
      **1.00×–1.12×** (g3 0.999×, g6 1.003×, g4 1.009×, g1 1.116×), with checksums agreeing, because
      those programs are allocation-bound rather than arithmetic-bound. The default stays off on the
      6× worst case, but "too expensive to consider" is not what the corpus says.
      See [`RESULTS-overflow-checks.md`](aif/evidence/RESULTS-overflow-checks.md).
- [x] **A `BINARY_EXPR` carried the position of the token *after* it — fixed 2026-08-29.**
      `parserNode` was called after the right operand was parsed, so every binary expression in the
      tree pointed at the next line. Invisible because nothing reported a position out of one: sema
      points at operands and `-g` takes locations from statements. `--overflow-checks` is the first
      thing that does, and it named the line below the addition that overflowed. Both constructions
      now anchor on the **operator token**. Codegen-neutral: **zero** of 128 programs changed IR,
      which is the evidence that nothing else read it.
- [ ] **`wrapping_*` / `checked_*` / `saturating_*` intent forms.** Rust's model has three parts and
      only the check landed. Without the explicit forms, code that *wants* to wrap has no way to say
      so and traps under `--overflow-checks`. Language surface, not codegen. `/` at `INT_MIN / -1`
      is also still unchecked — a different trap, and one this deliberately did not fold in.
- [x] **`clock_gettime_nsec_np` is declared honestly — 2026-08-29.** It returns `uint64_t` and was
      declared `-> Int` in **20** sources; it worked only because the code takes a difference and
      frames are short, and a frame over ~2.1 s produced garbage. Now `-> I64`, with the narrowing
      moved to *after* the subtraction — `list_set(samples, frame, (t1 - t0) as Int)` — which is
      where it is safe. Every corpus checksum is unchanged (g1 alive 2000/beyond 1095 … g9 total
      1856014121), suite **174/174**, differential 18/18.
- [x] **`__builtin_string_len`'s truncation is now bounded and checked — 2026-08-29, and the ABI
      change it was thought to need was measured away.** `%prismio.str` carries its length in
      **i64** while `Int` is signed 32-bit, so the read emits `trunc i64 … to i32`. That was
      recorded as an incoherence to resolve by narrowing the representation.
      **The trunc costs nothing**: 5 of them in the whole of g7's IR, none surviving into the hot
      loop's machine code, because taking the low half of a register is free on AArch64. Narrowing
      `%prismio.str` is an ABI change across the runtime struct, the backend's type construction
      and the committed seed — for a coherence argument and no measurable byte or cycle.
      So the invariant is **made explicit and enforced** instead, at the one place an unbounded C
      length becomes a Prismio `Int`: `prismio_cstr_len` was `(int)strlen(s)` and now refuses above
      `INT32_MAX` with a diagnostic. `str_with_capacity` cannot exceed it — its parameter is `int`.
      Above the bound the old code returned a negative or wrapped length and every bounds check
      downstream compared against a lie, which is a silent wrong-memory read rather than a loud
      failure. Suite **175/175**, differential 18/18, fixed point.
- [ ] **"Four C string functions survive only as an FFI test surface" — the premise is wrong, and
      the corrected inventory is below (2026-08-29).** Three of the four are **live benchmark
      subjects**, not dead code kept alive by fixtures:

      | function | status | evidence |
      |---|---|---|
      | `str_slice` | **live** | measured in `g7.psm`'s `tokenize`, inside the timed region |
      | `str_equals` | **live** | `g7.psm:157`, in that same timed loop |
      | `str_substring` | **live** | `g7_substring.psm` — the benchmark's whole point |
      | `str_concat` | removable | `g7`'s `buildSource` **setup** only, plus fixtures |
      | `int_to_str` | removable | down to **one** fixture after this session |

      `g7`/`g7_substring` are BENCHMARKS §3.2's B2, the string axis of the corpus — the only
      cross-language programs that touch strings at all. Deleting what they measure is not cleanup.

      **So the reachable prize is 15 lines of 2,056** (`str_concat` 10, `int_to_str` 5), not the 40
      claimed, and it costs migrating a benchmark's setup plus the remaining fixture sites.
      **Done this session**: the 12 incidental `print(int_to_str(x))` diagnostics became native
      `print(x)` — no coverage lost, they were never FFI coverage — and two dead declarations were
      removed from `test_56`/`test_57`. `int_to_str` now has one genuine user,
      `test_45_aif_affine_collections`.
      **What is left is a judgement call, not a task**: whether 15 lines justifies migrating a
      benchmark's setup. Recorded rather than taken.
---

## Defect · `no_stack` answers two different questions, and one of them wrongly

**Found and FIXED 2026-08-30.** Was latent in the shipped compiler and blocked
migrating `tests/` off the C string externs.

An explicit `drop` in a function that is **never called** suppresses the automatic
scope-exit release in a *different* function:

```prismio
import std.io
import std.string

fn plain() -> Int {
    let s = strConcat("ab","cde")
    return __builtin_string_len(s)          // s must be released at the brace
}

fn other() -> Int {                          // never called
    let q = strConcat("uvw","x")
    let n = __builtin_string_len(q)
    drop(q)
    return n
}

fn main() -> Int { println(plain()) return 0 }
```

| variant | ledger |
|---|---|
| `plain` alone | `2 allocated, 2 released, 0 leaked` |
| `+ other()` **without** the `drop` | `2 allocated, 2 released, 0 leaked` |
| `+ other()` **with** `drop(q)` | `2 allocated, 1 released, **1 leaked**` |

Not name-keyed — renaming `s` changes nothing.

**Cause.** With native `std`, every string `strConcat` produces comes from *one*
allocation site, `str_with_capacity` at `std/string.psm:177`. `aif --summary` shows
a single `strConcat__String_String#0`; `--why` says "an explicit `drop` frees this
value" and "the body has more than one call site". `NodeSite` is a many-nodes →
one-site map, so `plain`'s initialiser node and `other`'s share that site.

`AIF_CON_NO_STACK` (`runtime/aif_support.c:3004`) marks **every site** in the
resolved value set `no_stack = 1`. That flag then serves two different questions:

1. *Can this site live in a stack slot or an arena?* — **site-level, and correct.**
   `walk.psm:282` calls it "a codegen constraint rather than a fact".
2. *Has this binding already been freed, so the scope must not free it again?* —
   asked at `aif_support.c:5687`, and **binding-level**. Answering it with the site
   flag makes one `drop` silently cancel the release for every other binding of
   that site.

The tree already states the intended rule, in `test_45`'s own header: *"droppability
is a property of a binding"*.

**Why the C externs hid it.** An opaque `extern fn str_concat` produced a per-call
`extern-alloc` value, so each call site was its own producer and the sites never
collapsed. Porting to native `std` is what merges them.

**Fix shape.** Split the two questions: keep `site->no_stack` for placement/tier,
and add a binding-level "explicitly dropped" flag consulted at 5687.
`aif_frees_at_scope_node` is asked about the *initialiser* node (`stmt.child2`,
`src/ir/stmt.psm:152`), and `NodeSite` already keys on that node — so the flag
belongs there. The missing piece is that `aif_con_no_stack(vs)` carries only a value
set, so `drop(q)` cannot currently name the binding's initialiser node.

### The fix, as landed

Two lines of behaviour, in the two places the two questions belong.

- `runtime/aif_support.c`, `elem_disposition_of`: **stop** consulting `s->no_stack`.
  That was the clause returning `AIF_ELEM_NONE` for every binding sharing a dropped
  site, which is what made `aif_owns_call_result_at_node` decline and the release
  vanish.
- `src/ir/stmt.psm`: add `chainDropsName(irFunctionBody, varName) == false` to
  **both** branches that mark a binding droppable — the `aif_frees_at_scope_node`
  one and the `aif_owns_call_result_at_node` one. New helper in `src/ir/expr.psm`,
  in the same shape as `chainAssignsName`.

`aif_frees_at_scope_node` **keeps** its own `s->no_stack` test: that clause is
reached only when `E` is the site's own scope, where site and binding coincide.
The first attempt removed *that* one instead and changed nothing, because the
`s->E != s->scope` test above it declines first — the wrong line in the right
neighbourhood.

FFI `consume` never depended on either clause: it raises E to Caller alongside its
`no_stack`, so the E test declines it before any of this.

### Gate

| | |
|---|---|
| suite | 191/191 |
| two-generation fixpoint | identical |
| corpus `__TEXT,__text`, pre vs post | 7/7 identical |
| `test_45` ported to native `std` | **215 leaked → 2 leaked** (the 2 it documents) |
| `test_45` unmigrated | `8/6/2`, unchanged |
| ASan | clean, no double free |
| doc snippets | 141 |

Compare `released`/`violations`, not `allocated`/`leaked` — the native port
legitimately allocates 221 where the C one allocated 8, because native `strConcat`
is visible to the ledger and the C one was not.

---

## Debt · UMS resolution releases nothing it allocates

**Incurred 2026-08-30 by v0.1 3.7.** Not unsoundness -- `violations` is 0 either
side -- but it is a real regression in allocation hygiene and it was measured, so
it is written down rather than left for someone to find.

`ums/test_ums.psm` under `--verify`:

| | allocated | released | leaked | violations |
|---|---|---|---|---|
| before 3.7 | 1150 | 639 | 511 | 0 |
| after 3.7 | 2112 | **637** | 1475 | 0 |

`released` is flat while allocations doubled, so `umsResolveDependencies`,
`umsLockfileContents` and `umsWriteLockfile` release none of the strings they
build -- and they build a lot of them, since every row is assembled with nested
`strConcat`. The subsystem already leaked 44% of what it took, so this is a worse
instance of a standing condition rather than a new class of problem.

**Why it is not a crisis:** the compiler is a short-lived process and every one of
these dies at exit. **Why it is still debt:** the same code is what a future
`prismio add` or a watch mode would call in a loop.

**How to approach it:** bind the intermediates rather than nesting the
`strConcat` calls -- TODO.md's argument-position release is withheld when the
enclosing call returns a pointer, which is exactly the shape
`strConcat(strConcat(a, b), c)` has, and every row builder here is written that
way. Measure with `released`, not `leaked`.
