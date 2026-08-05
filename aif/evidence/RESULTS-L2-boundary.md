# AIF — Engine/Game Boundary Results (A2)

**Tiers survive the boundary when the engine ships as source or PIR. Sealing costs 25 points, and
the damage is bounded to values that actually cross.**

Corpus: `../corpus/g6_engine.psm` (component storage, spawn/query/step API) and
`../corpus/g6_game.psm` (squads, per-tick order planning, combat) — two modules, gameplay importing
engine, compiled and run together. 800 entities, 100 ticks, 46,000 orders issued.

Gameplay code contains **no annotations and no memory vocabulary of any kind**, which is
[TARGET.md](../implementation/TARGET.md) §2.1's ergonomic claim stated as a program.

---

## 1 · Result

| Engine ships as | T0–T2 | T3 | Sites |
|---|---:|---:|---:|
| **Source / PIR** (bodies visible) | **100%** | 0 | 12 |
| **Sealed** (PIR §5, bodies invisible) | **75%** | 4 | 16 |

**The 12 gameplay-owned sites are T2 in both cases.** Sealing did not touch them. The four T3s are
exactly the values whose provenance became unknown: what `world_create`, `world_transform` and
`world_actor` return.

> Sealing degrades **only** the values that cross the boundary. It is not a global loss.

This is TARGET §2.3's question answered: whole-program analysis does hold across the engine/game
boundary, and when it cannot — because the engine is sealed — the failure is local and bounded
rather than a collapse.

---

## 2 · The boundary is cheap because the API is handle-based

`world_spawn` returns an `Int`. Every subsequent call takes that `Int` back. Gameplay never holds a
reference into engine storage.

That is why only four values cross in an ownership-carrying way at all, and it is the same property
[RESULTS-L0.md](RESULTS-L0-tiers.md) §3a found eliminates T3: **handles carry no ownership**. A
handle-based API minimises the crossing surface, so it minimises what sealing can cost.

The consequence for [PIR.md](../spec/PIR.md) §8 is worth stating, because that section lists whole-program
distribution's ecosystem costs as severe:

> If engine APIs are handle-based — which they are, universally — then the surface over which PIR's
> whole-program requirement actually pays is small. The 25-point loss here is real, but it is
> concentrated in a handful of API returns rather than spread across the program.

That does not remove PIR's argument. It bounds it.

---

## 3 · Most of the sealing loss is recoverable with contracts

The four T3s arise because an undeclared return has unknown provenance: it may already be shared,
and may already outlive the caller. The prototype models that conservatively, which is correct.

But `world_transform(w, h)` returns storage owned by `w`. That is precisely FFI §5.2's `alias`
contract, and if the sealed engine *declares* it, the analysis recovers the fact without seeing the
body.

> **A sealed library can recover most of what sealing costs by publishing ownership contracts on
> its API** — exactly as a C library must, and for exactly the same reason.

PIR §5 already frames sealed functions as internal FFI boundaries. This measurement shows the
framing is not just an analogy: the same contract vocabulary applies, and applying it closes most
of the gap. **PIR §5 should require published contracts on sealed API surfaces**, not merely permit
them.

---

## 4 · A prototype bug worth recording

The first run reported sealed at 100% — better-looking than it should have been. Cause: an unknown
callee returning a reference type was modelled as a **fresh local allocation**, so
`world_transform` looked like it minted a new Transform that never escaped.

FFI §5.2 makes `alias` the default return contract precisely because the opposite assumption is
unsafe. Fixed: undeclared returns now get `E ⊒ Caller, A ⊒ Shared`, and a `FFI_RETURNS_PRODUCE` set
names the runtime functions that genuinely allocate (`list_new`, `str_concat`, …).

Worth recording because the wrong version was *optimistic*, and optimism in this analysis is
unsoundness, not imprecision — the same failure mode FFI §1 warns about, hit twice now.

---

## 5 · Compiler bug found: `List<Int>` miscompiles

`list_push(list_of_int, some_int)` emits a call passing `i32` where the runtime signature expects
`ptr`, and LLVM module verification rejects it:

```
Call parameter type does not match function signature!
  %24 = load i32, ptr %h.56, align 4
 ptr  call void @list_push(ptr %23, i32 %24)
```

`List<T>` works only for pointer-shaped elements. Recorded as COMPILER-TODO item 20. The corpus
uses a `Member` struct instead, which is more realistic gameplay code anyway.

---

## 6 · What this does not show

- One program, one API shape. A reference-passing engine API — which cannot be written today
  (RESULTS-L0 §4.2) — would cross far more ownership and could lose much more to sealing.
- Sealing costs more than tiers: no inlining, no cross-boundary specialisation, and fixed layouts
  the consumer cannot influence. **Only the tier effect is measured here.**
- Static distribution, as before. See RESULTS-L0 §6.
