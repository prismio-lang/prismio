# Prompt for the next session

Copy the block below.

---

Continue the Prismio AIF work. Read `HANDOFF.md` (start at "Session of 2026-08-07 (second)") and
`aif/implementation/COMPILER-AUDIT.md` first. Struct-field ownership, `List<T>` for scalars,
optional references, the T4b collector, the zero-analysis level and memory-budget reporting all
landed on 2026-08-07 and are documented there. **The corpus is at 0 leaked / 0 violations across all
six programs**, 91/91 tests, fixpoint holds cold and warm, cold == warm, the oracle agrees on 12
sources, seed is current. Don't re-derive any of it.

The memory model is done to the point where benchmarking is the remaining work. So this session is
about knowing what we have before adding to it.

1. **The 79 T3 sites, and the claim that says there are none.** `prismio aif src/main.psm` reports
   **79 T3** over the compiler's own source. `HANDOFF.md` has an older section asserting "100%
   T0–T2 over 294 sites" and "the T3 residue from 37 to 0" after the FFI work. Both cannot be true.
   The discrepancy pre-dates last session — the pre-session binary reports the same 79 — so it was
   observed and deliberately not chased. Chase it now, and **find out which of the two is wrong
   before changing anything**: either the tree regressed against its own documentation, or the
   documentation was written against a state the tree no longer has (`git status` showed
   uncommitted modifications to `src/aif.psm`, `src/bridge.psm` and others at the start of last
   session, so the second is plausible). If it is the undeclared-extern shape again, it is the
   cheapest measured win available — that lesson is now recorded twice, and this would be the third.

2. **Measure what ownership contexts would actually buy.** INFERENCE §6–7. It was ranked the
   highest-value item left, on two grounds: three recorded limitations are one missing feature
   (ownership transfer surviving one hop, the container element key having to be object-insensitive,
   `E` unable to name a caller's scope), and `g4_ecs_world` would not move. **The second ground is
   gone** — struct-field ownership took g4 to zero — so contexts now buy precision rather than
   correctness on this corpus, and nobody has measured how much. Produce that number before
   building: how many sites are T3/T4b *because of* a call-boundary join, and what would they become.
   `test_47`/`test_48` merged into one file is the ready-made probe for the element-key half — the
   audit records that merging them makes all seventeen of test_47's sites T3.

   Do not start the implementation on inherited ranking. It needs per-context fact graphs,
   demand-driven instantiation, a relevant-parameter mask, δ-based strategy selection, caps with
   deterministic victim selection — **and an identical change to `aif/prototype/aif.py`, or the
   differential stops meaning anything.** It was deliberately not begun last session rather than
   half-landed.

3. **Then benchmark**, which is what the model was brought to this point for. `aif/spec/BENCHMARKS.md`
   H1's 70% T0–T2 bar is already cleared on the compiler; what has never been measured is Prismio
   against another language on the corpus. Pick the benchmark with COMPILER-AUDIT finding 9 in mind:
   *the compiler leaks by design and exits, so it is already a one-region program and AIF's first win
   on its own source will be small.* The corpus is the better target, and `g2_frame_loop` and
   `g6_game` are the two with real allocation traffic.

NOT this session: handles (REQUIREMENTS 12), concurrency (15), PIR (21), `workload`, SoA / hot-cold
/ bit-packing. Each needs handles or a task model. Perceus elision needs a reference-level IR the
AST walk does not have — and the corpus has almost no T3 to elide, so measure before building.

Carry forward:

- **Two generations before judging.** Earned its place again last session: the first struct-field
  build emitted `__aif_release_String` (this compiler puns an `ASTNode` pointer as `String`), gen 1
  linked because it was built by the *old* compiler, and gen 2 did not.
- **A guard must establish what it assumes.** Barring a binding's drop because "some type's release
  will take it" deletes the release when that type lives in the frame. 47 leaked → 2049, and the
  leak count was the only detector.
- **A mechanism must count every edge it traverses.** The first cycle collector segfaulted: trial
  deletion subtracted field references nobody had incremented.
- **The differential is not always the safety net.** It agreed on a wrong answer three times
  historically, is blind to layout, and was blind to *everything* last session — no tier moved, so
  its agreement confirmed tier-neutrality and nothing else. When you change something it cannot see,
  say what the coverage is.
- **Reach for the input before the mechanism.** Item 1 above is this lesson's third outing.

After each item: two generations to fixpoint, full suite, `tools/aif_differential.py --compiler
<exe>`, the corpus under `--verify` (leaks AND violations), and a cold start plus seed refresh if the
FFI surface changed.
