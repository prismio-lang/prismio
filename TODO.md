# TODO — compiler improvement plan, with a measured gate on every milestone

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
> **Still opt-in** behind `PRISMIO_INLINE_RUNTIME=1`: the portability claim is a macOS PATH test,
> and a green CI on three platforms is what should gate flipping the default.

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
      [`RESULTS-M1-lto.md`](aif/evidence/RESULTS-M1-lto.md) §9 and §10. **The default is still
      off, on purpose:** the portability claim is a PATH test on macOS showing the compiler no
      longer *invokes* `llvm-extract`/`llvm-link`, which is not the same as a green CI on three
      platforms. That run is what should gate flipping it, not another local measurement.
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

- [ ] **M2.1 — Reuse tokens.** Pair a dead value with a constructor of the same size in the same
      branch; reuse the block instead of free-then-malloc.
- [ ] **M2.2 — Reuse specialisation.** In-place field update when the reused block *is* the
      matched one. **Blocked on M2.1, which is blocked on the per-site field disposition** — there
      is no token to specialise until one exists. Note also that the g2 motivation in the original
      line was already superseded: M3 took g2's allocation count from 10 285 886 to 82 052 with an
      arena, so the prize this would add on g2 is whatever is left after that, and nobody has
      measured it.
- [ ] **M2.3 — Bound the tokens.** Frame-limited reuse, so a held token cannot leak. **Blocked on
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

**Five items done and gated; four blocked on one named thing.** Every item is either finished or
closed with a reason, which is what "finished" can mean for this milestone today.

| | |
|---|---|
| M2.0 · release on reassignment | **done** — g7 3599 leaks → 0 |
| M2.0b · callee-returned accumulators | **done** — probe 7 leaked → 1 |
| M2.1a · recursive releases for self-referential types | **done** — `test_73` 100 leaked → 0 |
| M2.1c · assignment re-initialises a moved binding | **done** — `acc = f(acc)` now compiles |
| M2.4 · borrow inference | **decided** — opt-in through existing annotations, no inference |
| M2.1a-ii · shallow free of a destructured block | **blocked** |
| M2.1a-iii · ownership transfer past one hop | **blocked** |
| M2.1 / M2.2 / M2.3 · tokens, specialisation, bounds | **blocked** |

**All four blocked items are blocked on the same thing: `field_release_of` answers per
`(type, field)` and needs to answer per site.** Three independent confirmations, all measured:

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
- [ ] **M2.1a-ii — the shallow free of a destructured block. Attempted 2026-08-23, reverted, and
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
- [ ] **M2.1a-iii — ownership transfer past one hop.** The second reason `g8` does not move: a
      recursively-built tree returns sites belonging to its own recursive calls, so the caller owns
      nothing and no drop runs at all. INFERENCE 6's contexts, the same gap
      `test_47_aif_containers` records as its 6. **It also blocks measuring the recursive release's
      stack-depth limit**, since a deep structure has to be built recursively to exist.
- [ ] **M2.1b — the token.** Only then: `drop` + same-size `alloc` in one branch becomes reuse.
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

> **Projected prize: 0.26×** where layout dominates (`g1_tuned.rs`, pure SoA). One language feature,
> two unlocks. **The expensive one — needs real language design.**

**Read the correction before ranking this.** Inline `List<T>` storage is worth having because it
removes **allocations**, not indirection: Prismio's exact boxed layout in Rust, mutated in place,
runs at **0.86× of inline `Vec<T>`**. If M2 removes those allocations another way, the urgency
drops. What does *not* drop is that **views are the prerequisite for the layout work**.

**Concepts:** [data views](#data-views), [unboxed/flat layout](#unboxed-flat-layout),
[monomorphisation and flattening](#monomorphisation-and-flattening).
**Papers:** PPAM 2024 / arXiv 2502.16517 data views — **semi-manual AoS↔SoA**; OCaml unboxed types;
Java Valhalla JEP 401; MLton *Unboxing using Specialisation*.

- [ ] **M4.1 — Views/slices in the language**, with the ownership story worked out first.
- [ ] **M4.2 — Inline element storage for `List<T>`.**
- [ ] **M4.3 — Data views for layout**, the semi-manual AoS↔SoA framing: the programmer names the
      layout, the compiler converts. **More defensible than LAYOUT.md's automatic search** — the
      cost model already ranked two layouts the measurement rejected.
- [ ] **M4.4 — Watch for the Valhalla collision:** polymorphic variables cannot be flattened. This
      is where generics and the container representation will fight.

**Exit gate:** the standard gate, plus a re-run of the `rust_boxed` residual — it should move for
the first time in eight sessions.

---

## M5 · Allocator

> Cheap, mechanical, and it also touches the unexplained RSS regression.

**Concepts:** [free-list sharding](#free-list-sharding).
**Paper:** Mimalloc (APLAS 2019) — built specifically as the backend for reference-counted
runtimes (Koka, Lean), which is Prismio's workload shape.

- [ ] **M5.1 — Evaluate mimalloc** behind the existing allocator seam. Weighted 20–63× more heavily
      here than in the Rust baseline, because that is how much more we allocate.
- [ ] **M5.2 — Bisect the RSS regression. Largely answered, 2026-08-28, and by accident.**
      The standing text was 0.84–1.00× → **1.09–1.60×** of idiomatic Rust, +27% (g5) to +86% (g6),
      Rust unmoved, with the fixed runtime footprint and the hot/cold split already excluded.
      **The cause was the leaks.** Removing the integer-print leak and the inline-field leak dropped
      peak RSS to **0.49×–0.82×** of the previous compiler across the whole corpus, in the same two
      changes that took the ledgers to zero — a leak scales with live set rather than churn, which
      is exactly the signature this entry recorded and nobody read as a leak.
      **What is left is one measurement, not an investigation:** re-run
      `RESULTS-final.md`'s own harness and restate the ×-against-Rust figure. The
      `milestone_bench` numbers above are old-vs-new and cannot answer it.
      Absolute peaks now: g1 1.78, g2 1.94, g3 2.08, g4 2.05, g5 1.63, g6 2.23 MB.

---

## Standing items, not milestones

*(The first two were promoted here from `SESSION-PROMPT.md` on 2026-08-28. That file is the live
prompt and this one is the plan — anything it tells the next session to do has to exist here as a
checkbox, or the two drift and only one of them gets read.)*

- [ ] **Re-measure `RESULTS-final.md`, before ranking anything. Do this first.** Three figures in
      that matrix are stale in the same direction after 2026-08-28 and nothing in this file can be
      ranked honestly until they are refreshed: **g2** (5.77× → ~2.6× of idiomatic Rust), **g6**
      (4.31× → 2.58×), and **peak RSS on all six** (0.49×–0.82× of the previous compiler).
      Its harness is the only thing that produces the ×-against-Rust RSS figure —
      `tools/milestone_bench.py` is old-vs-new and cannot answer it. The band quoted throughout
      this repo as **1.13×–5.89×** is roughly **1.09×–3.23×** on the driver's own numbers; do not
      propagate either until the harness has run. Half a session, no design.
- [ ] **Decide `PRISMIO_INLINE_RUNTIME`'s default.** M1's remainder, and the only part of it that
      is not "M1 cannot close this". M1.1b is built, byte-identical to `llvm-extract`'s output,
      ~5% warm compile cost, corpus median **0.812×** measured, and off by default for exactly one
      reason: the portability claim is a macOS PATH test rather than **a green CI on three
      platforms**. That run is the task; the flip follows from it, or the entry says why not.
      Largest measured prize on this list per unit of work.
- [ ] **Genuinely-cold compile regressed 19–28%** — g1 183 → 235 ms, g6 203 → 241 ms with
      `PRISMIO_OBJ_CACHE=0`. Hidden by the object cache in the default path (103–110 ms, 0.71–0.85×
      rustc). Affects first builds and uncached CI.
- [ ] **Keep the corpus honest.** It is six single-threaded programs; concurrency is unmeasured and
      it is the axis where Rust's claim is strongest. Any concurrency ranking needs a concurrent
      program in the corpus first.

---

## Public docs — what to check in `../docs/content`

The site is Velite + Next.js at `/Users/vibrant/Desktop/Projects/Prismio/docs`. Pages are
auto-discovered by `**/*.md`; **frontmatter is schema-enforced** (`title`, `description` 20–180
chars, `status` ∈ `implemented|experimental|draft|coming-soon`, `version`, `lastUpdated` ISO date,
`tags`, `related`). A malformed page fails the build.

Per milestone, check:

| Milestone | Pages that likely need an edit |
|---|---|
| M1 | `compiler/overview.md`, `compiler/cli.md` (if flags or build stages change), `roadmap.md` |
| M2 | `guides/memory-and-aif.md`, `compiler/aif.md`, `specification/memory-model.md`, `glossary.md` |
| M3 | `language/annotations.md`, `language/lifetimes.md`, `errors/unnamed-region.md`, `errors/region-budget-exceeded.md`, `guides/memory-and-aif.md` |
| M4 | `language/arrays-and-lists.md`, `language/generics.md`, `language/types.md`, `specification/memory-model.md` |
| M5 | `compiler/overview.md` — only if the allocator becomes user-visible |

**Always:** bump `lastUpdated`, and correct `roadmap.md` if a row's status changed. Do not let a
`status:` field claim more than the suite proves — the repo has a documented history of exactly
that rot ("this line read 76/76 for six sessions after it stopped being true").

---

## Concepts

Definitions for the terms the milestones use, so a task does not have to be decoded from a paper.

#### Cross-module inlining
Making a function defined in one compilation unit inlinable at a call site in another. Rust
serialises MIR for generic and `#[inline]` functions into the rlib and inlines **before** LLVM;
Swift's `@inlinable` exports the body into the module interface. The general lesson: **inline at
your own IR level, before the backend.**

#### Whole-program compilation
Compiling the entire program as one unit so every optimisation is interprocedural. MLton does
defunctorisation, monomorphisation, inlining, unboxing and argument flattening this way. Maximal
version of M1; Prismio is closer to it than it looks, being self-hosting.

#### Summary-based LTO
ThinLTO's design: instead of merging every module, attach a compact **summary** to each bitcode
module, do a fast serial whole-program analysis over summaries only, then import just the functions
that matter. The answer to "won't merging wreck compile time".

#### Reuse analysis
Pairing a value that is about to die with a constructor of the same size in the same branch, and
**reusing the block** rather than freeing and re-allocating. Origin: *Counting Immutable Beans*
(Lean 4). This is the mechanism that attacks the 20–63× allocation ratio.

#### Reuse specialisation
The stronger form: when the reused block *is* the matched one, the constructor becomes an in-place
field update rather than a copy. This is what makes reuse worth a large factor rather than a small
one.

#### FBIP (functional but in-place)
The programming style reuse analysis enables: write an algorithm in a value-semantics style and
have it execute as in-place mutation. Perceus's framing — *"much like tail-call optimization
enables writing loops with regular function calls"*.

#### Borrow inference
Automatically marking parameters as borrowed so reference-count operations can be cancelled.
**Caveat, and it is load-bearing:** the automatic version was judged **not safe for space**, and
Koka deliberately does not do it — it borrows only for built-in primitives. Decide explicitly.

#### Non-lexical regions
A region whose extent ends at the **last use** of the values in it, rather than at the close of the
syntactic scope, computed by flow-sensitive dataflow. Directly addresses the recorded blocker
*"the arena is lexical and allocation is not"*.

#### Region polymorphism
Region **parameters** on functions, so a callee allocates into a region the caller supplies —
Tofte–Talpin. This is the mechanism behind the `CallerRegion` item: it is how a caller's region
reaches a callee's allocations.

#### Sized allocation
Attaching a size to a region at creation, so fragmentation and layout are statically analysable
(Spegion). Useful for a systems language that wants predictable memory, not just safe memory.

#### Data views
A named alternative layout over the same logical data, with the compiler converting between them at
declared points. The PPAM/arXiv 2502.16517 framing is **semi-manual** — the programmer names the
layout, the compiler does the work — which is more defensible than a fully automatic search.

#### Unboxed / flat layout
Storing a value's fields directly inside its container rather than behind a pointer. OCaml flattens
unboxed products into the enclosing block; Valhalla flattens value classes into fields and arrays.
**Valhalla's hard-won limit: polymorphic variables cannot be flattened.**

#### Monomorphisation and flattening
Duplicating generic code per concrete type to erase polymorphism, which then permits good
representations (MLton, Rust). Prismio already monomorphises, which is why M1.3 and M4.2 compound.

#### Free-list sharding
mimalloc's core trick: several page-local free lists per page rather than one global list, which
buys locality and a very short fast path, and avoids contention.

---

## Reading order

1. [Perceus](https://xnning.github.io/papers/perceus.pdf) (PLDI 2021) — reframes the memory model
   from *classify* to *reuse*, the axis that has never moved.
2. [Spegion](https://arxiv.org/pdf/2506.02182) (2025) — the named blocker, current state of the art.
3. [ThinLTO](https://llvm.org/devmtg/2016-11/Slides/Amini-Johnson-ThinLTO.pdf) (CGO 2017) — M1.

Then [the region retrospective](https://link.springer.com/article/10.1023/B:LISP.0000029446.78563.a4)
for what goes wrong, and [PPAM data views](https://arxiv.org/html/2502.16517v1) before any further
layout work. Full annotated list with links:
[`docs/ARCHITECTURE-DIRECTION.md`](docs/ARCHITECTURE-DIRECTION.md).
