# AIF — Layout Results (A1)

**The static access profile is exact, and the cost model picks the layouts a human would.**

Produced by `../prototype/layout.py` over the same dumps as [RESULTS-L0.md](RESULTS-L0-tiers.md). Static
profile only — **no workload was run and no annotation was written.** This is the first test of
[LAYOUT.md](../spec/LAYOUT.md) §1's central claim: that the *structural* half of layout selection is
statically exact, and a workload buys only frequencies.

Date: 2026-08-01.

---

## 1 · Headline

| Program | Chosen layouts | Modelled vs all-AoS |
|---|---|---|
| G1 particles | `Particle` → **SoA** | **5.37×** |
| G2 frame loop | `DrawCmd` → SoA, `Renderable` → SoA | **11.58×** |
| G3 scene graph | `Node` → SoA+split(1/7), `Transform` → AoS+split(3/6) | **5.92×** |
| G4 ECS world | 5 component types → SoA, 4 with hot/cold splits | **3.96×** |
| G5 asset cache | `Entity`/`Texture` → SoA, `Mesh`/`AssetCache` → **AoS** | **1.31×** |
| SELF compiler | all 5 types → AoS | 1.00× (no traversals) |

These are **modelled** memory-cost ratios from LAYOUT §5, not measured speedups. They say what the
optimiser believes it is buying, not what a binary would do.

---

## 2 · The static profile is exact

G1 was written with three loops touching deliberately different slices of a 12-field component.
Extraction recovered them precisely:

```
Particle  sequential  arith= 8  touched=6/12  [px,py,pz,vx,vy,vz]   @integrate:58
Particle  sequential  arith= 4  touched=2/12  [a,life]              @fade:71
Particle  sequential  arith= 4  touched=1/12  [life]                @count_alive:84
```

Every attribute LAYOUT §2.1 marks *"static, exact"* — the co-access set, the read/write split, the
traversal order, the arithmetic count — came out of the AST with no run and no annotation. **The
structural half of the profile is exactly as available as §1 claims.**

---

## 3 · The model discriminates, and that is the real result

A layout optimiser that always answers "SoA" is worthless. The test is whether it says AoS when AoS
is right.

**It does.** In G5:

```
Entity  sequential  touched=3/6  @render_batched:213   ->  SoA+split(3/6)   18.75x
Mesh    random      touched=1/6  @render_batched:213   ->  AoS              1.00x
```

Both are traversals in the *same loop nest*, over the same cache, in the same function. `Entity` is
walked by a counter — sequential — so SoA streams only the touched fields. `Mesh` is indexed by
`e.mesh` — random — so one cache line delivers the whole record and SoA would pay a line *per
field*. The optimiser reached opposite conclusions for the two, from the index expression alone.

This is LAYOUT §5.1's fourth formula doing its job: **random access favours AoS**, and it is the
counterweight that stops SoA being unconditionally right.

Two more choices worth naming, both of which match what engine programmers hand-write:

- **`Node` → SoA + split(1/7).** The scene graph's node is traversed randomly through
  `next_sibling` (link chasing) and sequentially through `world` (bulk read). The split puts the
  *traversal link* in the hot group and the payload cold — separating list structure from data,
  which is exactly the manual optimisation for linked structures.
- **`Transform` → AoS + split(3/6).** `count_visible` reads `world.px/py/pz` and never touches
  scale. The split isolates position from scale. Nobody said to.

**The compiler scores 1.00× with zero traversals**, which is correct rather than disappointing: it
walks pointer-linked AST nodes, not collections, so there is nothing for a layout optimiser to
choose between. It is the wrong workload for this half of the model, as [TARGET.md](../implementation/TARGET.md)
§3 already says.

---

## 4 · Spec defect found: LAYOUT §5.4's total could go negative

The first run produced ratios like `2703601120.00x` and an aggregate of **`-1.22×`**.

Cause: §5.4 summed the memory-cost terms and then **subtracted `SimdCredit`**. But SIMD saves
*arithmetic* cycles, and arithmetic appeared nowhere in the sum — so the credit had nothing to net
against and drove the total below zero. A search minimising that objective chases negative-cost
layouts, and every ratio computed from it is meaningless.

**Fix, applied to LAYOUT §§5.2 and 5.5:** `ArithCost(t) = iters · n · arith` becomes a positive
term, and `SimdCredit ≤ ArithCost` by construction. The bracketed group is then non-negative and
`Cost(L) ≥ 0` for every candidate.

This is the kind of defect only an implementation finds. The formula reads fine in prose.

---

## 5 · What this does not show

- **Modelled, not measured.** Every ratio is the cost model's own estimate. Validating it needs
  codegen, a real SoA lowering, and a benchmark — none of which exists. A wrong constant in
  LAYOUT §4 propagates straight into these numbers, and the prefetch factor `π` is the one most
  likely to be wrong (LAYOUT §10).
- **`n(t)` is assumed large.** Collection length is unknown statically, so the model assumes it
  exceeds L3, which **biases toward SoA**. A workload run would supply real lengths, and small
  collections would move some of these choices back to AoS. This is precisely the "frequencies"
  half §1 says a workload buys, and it is untested.
- **`iters(t) = 10^depth`** is LAYOUT §10.4's admitted weak point. G3's `propagate` recurses, and
  the depth heuristic sees depth 1.
- **No packing, no false sharing.** Packing needs observed value ranges; false sharing needs
  concurrency. Both skipped.
- **Nested structs are pointers.** Today's compiler stores a struct-typed field as a pointer, so
  `Node.world` is a real indirection and the model scores it as random access. Under AIF, inlining
  a nested struct is itself a layout decision — and **LAYOUT does not currently discuss it.** That
  is a gap, not a bug.

---

## 6 · What to do next

1. **Validate against a workload run.** The static-versus-workload gap (SPEC §11 open item 5,
   LAYOUT §10.4) is now directly testable: compare these choices against ones made with real `n(t)`
   and `iters(t)`. If they agree, §1's reframing holds and `workload` stays genuinely optional.
2. **Add nested-struct inlining to the candidate space** (§5). It is a layout decision AIF should
   own and LAYOUT omits.
3. **Calibrate LAYOUT §4**, especially `π`. Cheap microbenchmarks, no compiler needed, and every
   number above depends on it.
4. **Report layouts in the manifest** so they are diffable, per SPEC §6.

## Reproducing

```bash
python ../prototype/layout.py g1.json --verbose    # traversals + choices
python ../prototype/layout.py g5.json --verbose    # the AoS/SoA discrimination
```
