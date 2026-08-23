# M2.0 — release on reassignment, and the M2 gate restated

**2026-08-23.** `build/S27b` → `build/S31b`. Suite **141/141**, fixpoint `a31.ll == b31.ll`,
differential 17/17, corpus median **1.002×** (range 0.934–1.036×), RSS 0.992–1.010×.
**GATE PASSED.**

---

## 1 · What this closes

`g7.psm` leaked **3599 of its 5021 allocations** — 72% — while `HANDOFF.md` recorded that *all
seven* benchmark programs had a clean `--verify` ledger. Six of seven did. g7 was never in the set
that claim was measured on, and it is the newest program in the corpus.

| | allocated | released | leaked | violations |
|---|---|---|---|---|
| g7 on `S27b` | 5021 | 1422 | **3599** | 0 |
| g7 on `S31b` | 5022 | 5022 | **0** | 0 |

The other six are unchanged and still clean:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| leaked | 0 | 0 | 0 | 0 | 0 | 0 |
| violations | 0 | 0 | 0 | 0 | 0 | 0 |

## 2 · The defect was documented, deliberate, and had stopped being true

`src/ir/expr.psm`, above `nodeAssignsName`, said it in as many words:

> Deliberately syntactic and deliberately blunt. A reassigned binding is not droppable even when
> every value it receives is owned — that case leaks today regardless, since there is no drop on
> reassignment, so the strictness costs nothing that is not already lost.

Both halves were true and they held each other up. The drop list refused every reassigned binding,
because the slot might hold a borrow (`s = node.name` is a free of a value the AST still holds).
The assignment released nothing, because the drop list was where releases lived. So an
accumulator's intermediate values had **no owner at all** — the third instance in four sessions of
a leak that is a *missing owner* rather than a missing free, and the second where the analysis and
codegen each had a defensible answer and together lost the value.

The shape is the most common string idiom there is:

```prismio
let mut out = ""
while (i < n) { out = str_concat(out, "...") }
return out
```

That is `buildSource` in `g7.psm`, and it is 3600 of its allocations.

## 3 · The mechanism

**One fact, asked in two places.** `aif_releases_on_overwrite_node` (`runtime/aif_support.c`) is
`aif_frees_at_scope_node` with exactly one clause relaxed and one added back:

- **relaxed**: `s->E != s->scope`. An accumulator is never confined to the scope that allocates it
  — it binds outside the loop and allocates inside it, so E is the *binding's* scope, and `return
  out` lifts it to `Caller`.
- **added**: `s->E == AIF_E_GLOBAL` declines. Nothing else did once confinement was gone, and a
  value stored into a global outlives every scope.

Every other clause is untouched, and they are the whole soundness argument: `site_is_move_only`
(aliasing), `in_container` (a container owns its elements), `site_in_released_field` (a struct
field is the release point), `aif_arena_at_node` (an arena object is reclaimed in bulk).

Relaxing confinement is sound because the question is different. The scope-exit drop asks *where a
value dies*; this asks *whether the value is still reachable once the slot stops naming it*. A
return does not make it reachable — a return exits the function, so a value an assignment
displaces is one no return ever carried.

**Two flags, not one.** `owns_slot` is separate from `is_droppable` in the binding table
(`runtime/ir_symbols.c`) and had to be: a returned accumulator hands its *last* value to the
caller, so the scope must not drop it, while every value displaced before that one is still this
scope's to release. Conflating them is what made `return out` silently disable the release — caught
by the reproducer reading 11 allocated / 1 released before the split.

**Literals are cloned.** `let mut s = ""` puts a `.rodata` pointer in a slot the first assignment
frees. A qualifying binding clones its literal — one allocation per binding, not per iteration — so
the invariant *the slot always holds memory this binding owns* is total. The runtime had already
reached this conclusion once, in `str_substring`'s out-of-range answer.

## 4 · The two things that cost the most to find

**The clone was needed at the assignment as well as the declaration**, and one generation of the
compiler shipped without it. `s = "literal"` inside the loop leaves `.rodata` in a slot the *next*
assignment frees. The symptom was not a test failure: the compiler built every corpus program
correctly and then **aborted in libc at exit**, on `--verify` builds only, with `pointer being
freed was not allocated` for a suspiciously low address. It reproduced only through `$?` — a
`grep` in the pipeline had been swallowing the exit status.

**The rebinding guard was written and then deleted.** `let t = s` moves the value to a second owner
the model cannot see, since an identifier initialiser registers no site, so releasing at the next
`s = ...` frees what `t` names. A syntactic guard for it was built — and sema already rejects
assigning to a moved binding at all, in the loop form *and* the straight-line form, so the shape
cannot reach codegen. A guard that cannot fire reads like a hazard that has been handled, which is
worse than not having one.

## 5 · The fixture, and how it nearly measured nothing

`tests/test_72_reassigned_ownership.psm`. Discriminating in both directions, by compiler:

| | allocated | released | leaked |
|---|---|---|---|
| `S27b` (before) | 14 | 3 | **11** |
| `S31b` (after) | 20 | 19 | **1** |

The surviving 1 is the point of the negative half: `borrow_reassign`'s initialiser, which the guard
**must** decline because the slot ends up holding `h.name`. Declining it leaks 6 bytes; not
declining it frees a value the struct still owns. That entry going to 0 is a regression.

**Three of the five cases were written confined and tested nothing.** A confined accumulator is
served by an arena, `aif_releases_on_overwrite_node` declines every arena object, and the functions
passed while touching none of the path. Every case whose point is the release now *returns* its
accumulator, which puts E at `Caller` and keeps it on the heap. The allocation count is what proves
it — 14 → 20 as the cases moved onto the heap, and it scales with the loop bounds.

`test_45_aif_affine_collections` already guarded the negative direction and still passes unchanged:
its expectation names `holder.name`, "which `reassigned_from_borrow` must NOT free."

`test_44_aif_region` moved **2 → 1**, and the runner's own note predicted it: the leak it
describes as "it reaches its binding through an assignment rather than a `let`, so it never enters
a drop list — droppability is a property of a binding's initialiser" is this defect, recorded as an
explanation.

## 6 · Timing

Corpus median **1.002×**, and no program past 10%:

| g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|
| 1.034× | 0.997× | 1.008× | 1.036× | 0.934× | 0.978× |

RSS 0.992–1.010×. Checksums identical across all 29 variants — `milestone_bench` asserts this
before timing.

`g7` is not in `milestone_bench`'s corpus. Timed separately, five interleaved passes, median of its
own `frame_ns`: **0.080 ms → 0.073 ms, 0.921×**, checksums identical (`tokens 427914`, `bytes
21282`). The accumulator is in `buildSource`, outside the measured region, so this is allocator
state rather than the feature.

## 7 · What is left, measured

**A value returned by a Prismio callee and reassigned in a loop still leaks.** The predicate accepts
only `aif_releases_on_overwrite_node` and string literals; it does not accept
`aif_owns_call_result_at_node`, which is the weaker fact and carries syntactic guards at the
declaration (`chainAssignsName`, `chainReturnsName`) for reasons that have not been re-derived.
Measured on `S31b`:

```prismio
fn make(i: Int) -> String { return str_concat("val", "ue") }
fn loopCallee(n: Int) -> String {
    let mut s = make(0)
    while (i < n) { s = make(i) ; i = i + 1 }
    return s
}
```

`9 allocated, 2 released, 7 leaked, 0 violations`. Extending the predicate to cover it is the next
step and is **not** a one-line change: it is the fact whose guards exist because it cannot see
escape the way the other one can.

---

# Appendix — M2's closing state, 2026-08-23

`build/S27b` → `build/S44b`. Suite **143/143**, fixpoint `a44.ll == b44.ll`, differential 17/17,
fresh seed build byte-identical, all seven corpus programs `allocated == released` with 0
violations.

## Delivered

| item | evidence |
|---|---|
| M2.0 · release on reassignment | g7 **3599 leaked → 0**; `test_72` |
| M2.0b · callee-returned accumulators | probe **7 leaked → 1**; `test_72`, three-generation guard |
| M2.1a · recursive releases for self-referential types | `test_73` **100 leaked → 0**, allocations identical |
| M2.1c · assignment re-initialises a moved binding | `acc = f(acc)` compiles; `test_74`, discriminating by construction |
| M2.4 · borrow inference | decided: opt-in through existing annotations, no inference |

Three corpus gates, all within noise: medians **1.006×**, **1.006×**, **1.001×**; RSS never past
1.010×.

## Not delivered, and why

M2.1a-ii, M2.1a-iii, M2.1, M2.2 and M2.3 are blocked on one thing: **`field_release_of` answers per
`(type, field)` and needs to answer per site.** Confirmed three ways:

1. **M2.1a blocks M2.1a-ii.** Releasing `Tree`'s payload fields makes every `Tree` site
   `site_in_released_field`, so a `sink` parameter holding one is never reclaimable and the shallow
   free cannot fire. `g8_tree_rebuild.psm` did not move by one allocation with the full
   implementation in place.
2. **`type_is_reclaimed` means "has a disposition", not "is reclaimed"** — true for essentially
   every T2 struct type, so the released-field set is much wider than what anything frees.
3. **The call boundary has three owners** — caller drop list, parent field release, caller temporary
   cleanup. A callee-side free ignoring the third read `3 allocated, 3 released, 0 leaked` across
   142 tests and **5 violations** on a four-line probe.

Two complete implementations were built and reverted, both byte-clean against their baseline.

## The honest headline

**M2 removed leaks, not allocations.** Three classes of leak, each a *missing owner* rather than a
missing free, plus one language capability. No corpus program allocates less because of M2. Its
original exit text — "allocation count on g2 and g6 must drop by ≥ 10×" — was met during M3 by an
arena, which is why a gate has to name the mechanism as well as the number.
