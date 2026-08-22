# M3.1 — automatic call-site placement reaches a callee's allocations

Session of **2026-08-27**. Compiler `build/S15b` → `build/S18b`.
Entry gate: suite 137/137, fixpoint `S15a == S15b`.
Exit gate: suite **138/138**, fixpoint `a18.ll == b18.ll`, corpus median **1.002×**, **GATE PASSED**.

---

## 0. What this session was asked to do, and why it did something else

The session opened on **M2, reuse analysis**. It is not what got built, and the reason is a
measurement, not a preference.

M2.1 pairs a dead value with a same-size constructor **in the same branch**. That needs a
destructure-then-rebuild shape. The corpus does not have one:

* `match` appears in **no corpus program at all** — not g1–g6, and not g7 either. Checked for
  the syntax (`match` at statement position, `=>` arms), not the word: there are **zero** `=>`
  arms in any file under `aif/corpus/` or `aif/evidence/xlang/prismio/`. The construct is used
  only in `tests/` fixtures and in the compiler's own `src/`.
* g2's 10.2 M allocations are `DrawCmd` literals pushed inside `cull`
  (`aif/evidence/xlang/prismio/g2.psm:62`) — ~510 per frame × 20000 frames. They die in `main`
  when the frame's `cmds` list drops, and are rebuilt **in a different function** on the next
  iteration. Cross-call, cross-iteration, ~510 blocks at once. A single same-branch token cannot
  express that; an arena or a free list can.
* g6 is the same shape with `Order` (`aif/corpus/g6_game.psm:84`).

TODO.md cited `g2_tuned.psm` as "the evidence it will work". Its own header says otherwise: the
buffer is allocated **once outside the frame loop** and elements are mutated in place, and
"clearing and re-pushing would still allocate one DrawCmd per element per frame" because `List`
holds pointers. That is allocation hoisting plus boxed-element avoidance — **M4.2** — not reuse
analysis.

Meanwhile the mechanism that *does* remove those allocations was already measured:
`g2_region.psm` is g2 plus one word, serves all 10.2 M allocations, and runs at 0.46×. The only
thing missing was inference reach. That is M3.1.

## 1. The census, before

`python3 aif/evidence/arena_census.py --compiler build/S15b`:

| | |
|---|---|
| sites arena-served | **0 of 236** (2 by a bracketed call, in `g2_region` — the annotated cell) |
| blocked on `no_region` | **198 of 236** |
| `g2.psm` functions clearing every bracket obligation (`br_yes`) | **4** |
| `g2.psm` calls bracketed | **0** |

Four functions in g2 pass every obligation SPEC 5.2.1.1 imposes. None is bracketed, for exactly
one reason: `bracket_place` accepted only a `region`-**pinned** scope, and plain g2 has none.

## 2. The recorded blocker was a circularity, not a missing obligation

`aif_support.c` states it in as many words:

> **Only a `region`-pinned arena, never a cost-model-chosen one.** Otherwise placement depends on
> bracketing depends on placement.

That is real, and it is breakable, because **every bracket obligation is arena-flag-independent**.
`aif_fn_bracket_blockers`, `region_confined` and `bracket_site_bounded` read the call graph, the
points-to graph and scope shape. `aif_tier_of` reads a pin verdict and `derived_tier`. None reads
`scopes[].arena`. So the dependency can be made one-way instead of cut by weakening an obligation.

**Three changes:**

1. **`bracket_edge_ok`** — the obligations, factored out of `bracket_place` and parameterised on
   the region scope. Asked of a scope that has not been chosen yet.
2. **`bracket_candidate_serves`** — the cross-function traffic, fed into LAYOUT 7.1's cost model.
   `arena_would_serve` cannot see it by construction: `is_ancestor_or_self` is lexical over a
   per-function scope tree. Without this the frame-loop scope in `main` is never a candidate at
   all, because its lexical sum is 0 — every DrawCmd is allocated inside `cull`.
3. **`bracket_place` accepts cost-model arenas**, guarded by `arenas_placed` so a bracket answer
   cached before placement cannot survive it.

**Container disposition needed no work.** `elem_disposition_of`'s arena clause was landed inert
several sessions ago, its comment saying it was placed first *because* "call-site placement
removes exactly those two rejections". It was correct as written.

## 3. A latent soundness hole, found by turning the feature on

The pre-existing bracketed gate discharged only an **escape** obligation: nothing outside the
extent holds this value. A container's teardown does a second job that has nothing to do with
escape — it applies the element disposition, and for a counted element that is a decrement.
Serving the container from the arena deletes the teardown, and the decrement goes with it.

`test_48_aif_shared_elements`: `temp` in `borrow_into_temp` is a `List<Item>` whose one element is
borrowed out of `src`, allocated in the caller. Bracketed, it read:

```
22 allocated, 21 released, 1 leaked, 0 violation(s)
```

**and the program still printed `PASS`.** The leaked Item is one nobody reads again, so the ledger
is the only witness. An intermediate fix — refusing lists in the bracketed gate — made it worse
(`test_49`: 54 allocated, 10 released, **44 leaked**), because a heap container holding arena
elements frees neither. The invariant is that **an extent is served whole or not at all**.

`bracket_site_bounded` now carries the inverse of its owner clause: this value may own nothing
from outside the extent. Both fixtures return to `0 leaked, 0 violations`.

## 4. What it buys, measured

`aif/corpus/g2_frame_loop.psm`, `--verify`, no annotation and no source change:

| compiler | allocated | released | leaked | violations |
|---|---|---|---|---|
| `S15b` | 63,220 | 63,210 | 10 | 0 |
| `S18b` | **2,020** | 2,010 | 10 | 0 |

**31× fewer heap allocations.** This is the axis TODO records as never having moved, and it clears
the ≥10× bar M2's exit gate was asking for — from M3, not M2.

Every other corpus program is unchanged in allocation count: g1 4015, g3 5483, g4 9065, g5 4103,
g6_game 50467, identical on both compilers.

## 5. Where it does not fire, and why each is correct

**The benchmarked `g2.psm` — an opaque extern in the region body.** Its harness calls
`clock_gettime_nsec_np` **inside** the frame loop. `bracket_edge_ok` rejects, and rejecting is
right: FFI 5.1's `borrow` default is adequate for assigning a tier and not for handing a callee
arena memory. `g2_region.psm` earns its 0.46× by hand-placing `region frame_arena` *between* the
two clock calls — a **sub-block extent**, which is M3.2. The corpus copy `g2_frame_loop.psm`, same
workload without the harness, is placed automatically today.

**This is why the timing gate reads 1.002×.** The change is performance-neutral on the benchmarked
corpus because the benchmarked corpus contains no program it fires on. The prize is real and it is
measured in §4; it is not visible in a wall-clock median.

**`g2.psm` must not be edited to make this fire.** It is the baseline every prior g2 number was
measured on, and `milestone_bench` compares its checksums before it times anything.

**g6 — obligation 2.** Its callees store into parameters: `br_param=4` in the census, unchanged.

## 6. Gate

| | |
|---|---|
| Fixpoint | `a18.ll == b18.ll` |
| Suite | **138/138** (137 + `test_70_struct_field_release.psm`) |
| Checksums | all 29 corpus variants agree |
| Time | corpus median **1.002×**, range 0.945–1.030× — **GATE PASSED** |
| RSS | worst case 1.008×, no program past 10% |
| AIF differential | engine and oracle agree on all 17 sources |

**Two test expectations moved, and neither was relaxed to make the suite green.**
`aif_struct_fields` asserted `__aif_release_Inventory` and `__aif_release_Crate` on `test_49`,
whose structs placement now arena-serves — correct, and it cost the test two of its three
subjects. The coverage moved to **`test_70_struct_field_release.psm`**, which carries the same
types with **two call sites per constructor**, a shape regime (a) refuses to bracket, so they stay
on the heap in the shipped configuration. `region_diagnostics`' `peak-bytes` for test_49 goes
`0 → 108`: the assertion was never "zero", it is that the estimate describes the build.
