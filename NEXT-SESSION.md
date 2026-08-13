# Prompt for the next session

Copy the block below.

---

Continue the Prismio work. Read `HANDOFF.md` — start at "Session of 2026-08-13" — and
`aif/evidence/RESULTS-layout.md`. Don't re-derive what's in them.

**Two corrections to inherit before you plan anything.**

- **Handles have not landed.** Two consecutive briefs have opened by saying they did.
  `ptr_to_node` in `runtime/lang_runtime.c` is still `return ptr` and there is no handle table.
  The check takes ten seconds; do it rather than trusting this paragraph either.
- **Build HEAD before reading it.** Twice now the committed tree has not compiled — eaten spaces
  from a rename, then a stray `/* */` in a language with no block comments. Both would have been
  caught by CI's first step, and neither was caught by anything local.

State: suite 98/98, fixpoint holds warm and cold, cold == warm, the oracle agrees on 13 sources,
seed refreshed, and 68 of 68 compilable programs in `tests/` and `aif/corpus/` emit byte-identical
IR across the last change. `workload` (LAYOUT 3) is built and measured.

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
