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
# 3. the standing against Rust and Swift, full matrix
python3 aif/evidence/xlang/bench.py --compiler build/<next2> --runs 25 \
    --json aif/evidence/xlang/results-m<n>.json
```

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

> **Measured, through the driver: corpus median 0.864×**, range 0.481–0.982×, RSS and exe size
> unmoved. g5 goes **2.69× → 1.29× of idiomatic Rust**. **No language change.** Still the largest
> measured item in the project. M1.0 and M1.1 are done;
> [`RESULTS-M1-lto.md`](aif/evidence/RESULTS-M1-lto.md) has both.
> **The exit gate is not met** — g3 reads 1.05× of idiomatic Rust, not < 1.00×, and the 0.94×
> that number came from did not survive re-measurement. See the exit gate below.

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
- [ ] **M1.1b — What keeps it opt-in.** Each is a reason the default has not flipped:
      - [ ] **Port the merge off the `llvm-extract`/`llvm-link` binaries** to `LLVMLinkModules2`
            plus basic-block deletion, in `llvm-api-backend.c` where the LLVM dependency already
            lives (`:2667` already parses IR in process). `prismio_llvm.h` exists because the
            Windows installer is minimal, and CI runs three platforms.
      - [ ] **Measure cold compile time.** §7's 1.18× is warm and one program; this adds two tool
            invocations to a cold build, which already regressed 19–28%.
      - [ ] **Exercise `--verify`, the object cache and `--target`.** Covered by construction —
            verify define and target flags are both in the cache key — but not by measurement.

- [ ] **M1.2 — Cost it.** M1.1's route drops the two risks that dominated this item: no `-flto`
      means no linker-plugin portability question, and no attribute stamping means no per-target
      CPU string. What remains and is still unmeasured: compile time **cold** (§7 measures warm,
      one program; the cold path already regressed 19–28%), RSS, `--verify`, the object cache, and
      `--target`. **`-g` is the risk**: it drops the object step to `-O0`, so the merge must not
      silently change what `-g` builds.
- [ ] **M1.3 — Decide on the deeper form.** Either write the hot container ops in Prismio itself
      (they then land in the same module for free, and compound with monomorphisation), or adopt
      ThinLTO-style summaries if the merge stops scaling.

**Exit gate: NOT met.** The standard gate passes (median 0.864×). `--only g3` reads **1.05× of
idiomatic Rust**, not < 1.00×. §9's table has now been re-measured rather than cited, and it moved:
§9.3 put g3 at 1.01× of idiomatic Rust *before* the change, `milestone_bench` puts it at 1.12×.
The change's *worth* reproduced (1.064× against 1.07×); the baseline it was applied to did not.
**"The first Prismio program to beat idiomatic Rust" is not currently supported by a driver-built
measurement** — §9.3's table is hand-built with `clang -O2` invoked directly. Closing the last
0.05× is what M1.3 is for.

---

## M2 · Reuse analysis

> **Projected prize: large on g2 and g6** — the two programs where allocation dominates. Attacks
> the one axis that has never moved: Prismio allocates **20.2×–63.7×** more than idiomatic Rust.

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
      matched one, which is what turns g2's per-frame `DrawCmd` churn into a write.
- [ ] **M2.3 — Bound the tokens.** Frame-limited reuse, so a held token cannot leak. This is the
      answer to the space-safety objection; do not skip it.
- [ ] **M2.4 — Borrow inference: decide explicitly, do not drift into it.** Ullrich & de Moura's
      automatic version was judged **not safe for space** and Koka deliberately does not do it.
      Either bound it or make it opt-in, and write down which.

**Exit gate:** the standard gate, plus **allocation count on g2 and g6 must drop by ≥ 10×** —
`bench.py`'s `allocs` column, windowed, not the process total.

---

## M3 · Non-lexical and region-polymorphic regions

> **Measured prize: 2.16× on g2, already proven by the annotation.** `region` now serves
> 10,200,000 allocations and runs at 0.46× of plain g2. The mechanism works. **The inference does
> not reach it** — plain g2 still allocates 10,202,214 times with 0 arena objects.

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

- [ ] **M3.1 — `CallerRegion` + container disposition**, designed several sessions ago, still
      unbuilt. Unblocks *both* tiers, not only inference.
- [ ] **M3.2 — Non-lexical extent**: end a region at last use rather than scope close.
- [ ] **M3.3 — `region` must warn when it serves zero allocations.** Cheap, and the current silence
      is a user-visible trap — it was a 1.73× slowdown with no diagnostic for several sessions.

**Exit gate:** the standard gate, plus plain `g2.psm` must serve **> 0** arena objects without any
annotation, and `region` on a zero-serving scope must emit a diagnostic.

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
- [ ] **M5.2 — Bisect the RSS regression.** 0.84–1.00× → **1.09–1.60×** of idiomatic Rust,
      +27% (g5) to +86% (g6), Rust unmoved. Already excluded: fixed runtime footprint (ours is
      1.34 MB vs Rust's 1.47 MB) and the hot/cold split *on g3 and g6* — but g1, g2, g4 and g5 **do**
      emit splits and a split is two allocations plus a pointer, so it stays live there. Scales with
      live set, not churn. **Needs a session-3-era compiler to bisect against; there isn't one in
      the tree — build one from the tag first.**

---

## Standing items, not milestones

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
