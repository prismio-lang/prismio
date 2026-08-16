# Arena placement: what `region` serves, and what stops the rest

Measured 2026-08-14, extended 2026-08-16. Everything here re-derives in one
command:

```bash
python3 aif/evidence/arena_census.py --compiler build/<gen>
```

The census reads only shipped compiler surface — the manifest's `placement`
column and `prismio aif --why`'s placement section — so it cannot drift from what
codegen does.

**Nothing in §1–§6 has moved.** 38 of 234 sites are still arena-served, `region`
still serves 0 of 10 201 215 on `g2_region.psm`, and the timings are unchanged
because no placement decision changed. §8 is new: it measures how much of the
196 **could** be served by call-site bracketing, which is SPEC 5.2.1's first
named repair. That measurement is the whole of the 2026-08-16 session's result.

---

## 1 · The headline

**38 of 234 allocation sites in `aif/corpus` and `aif/evidence` are arena-served.
Of the 196 that are not, 196 have no `region` in their own function.**

Not a majority. All of them.

| blocker | blocked sites |
|---|---:|
| **`no_region`** — no `region` encloses the allocation *in its own function* | **196 of 196** |
| `not_t1` — the tier is not T1 | 184 |
| `is_list` — a List reallocates its element block after the site returns | 56 |
| `in_container` — a container reclaims the value through the deallocator | 46 |
| `no_stack` — an explicit `drop` frees it | 0 |
| `escapes` — escapes to caller or static storage *(with a region present)* | 0 |
| `outlives` — outlives the enclosing region | 0 |

The blockers are not exclusive: the gate is a conjunction and a site typically
fails several. That is the point of reporting a mask rather than the first
failure — see §3.

The 38 served sites are all in `std/io`, where the region and the allocation
happen to share a function. **No user-written program in this tree has a single
arena-served allocation.**

## 2 · Why an escape-lattice change does not move this

`Region(s)` holds a **scope id in the site's own function**. `enclosing_region`
walks `scopes[].parent`, a lexical tree rooted per function, and `scope_lca`
returns −1 across owners by construction. The arena that would serve a callee's
allocation is chosen at **run time**, by `arena_depth` in
`runtime/lang_runtime.c`.

So the two are not the same kind of object, and no value of `E` bridges them. A
`CallerRegion` element — designed twice in earlier sessions, ordered
`Region(s) ⊏ CallerRegion ⊏ Caller ⊏ Global` — would make g2's `DrawCmd` T1 and
leave it with **no arena to be T1 in**. Simulated against the census before
building: the served set does not change by one site.

SPEC §5.2.1 states this normatively.

## 3 · The measurement that was wrong twice, and why

Two earlier sessions read `aif_arena_at_node` far enough to find the clause that
explained the *previous* failure, and stopped:

| session | clause found | conclusion drawn | actually still blocked by |
|---|---|---|---|
| 2026-08-08 | `in_container` | "do the E change *and* container disposition" | `no_region` |
| 2026-08-13 | `in_container` | same, re-ranked as highest-value | `no_region` |
| 2026-08-14 | — | measured the whole gate | — |

The gate short-circuits, so a diagnostic built on it short-circuits too, and
"the tier is not T1" is a true answer that sends a reader to the wrong work.
`--why` now reports **every** failing clause:

```
  placement
    heap  -- no arena serves this site
      because  the tier is not T1 -- see the cause above
      and      a container owns this value and tears it down through the deallocator
      and      no `region` encloses this allocation *in its own function*
      note     an arena is a lexical scope (SPEC 5.2.1). A `region` in a
               caller cannot reach an allocation made in a callee, so no
               change to the escape lattice moves this site.
```

That is `g2_region.psm`'s hot `DrawCmd` — 10.02 M allocations a run, and the
site every arena design so far has been aimed at.

## 4 · `region` measured on g2

`aif/evidence/xlang/prismio/g2_region.psm` is `g2.psm` with `region frame_arena`
around the frame body and nothing else changed. Five runs, frame-loop sum:

| | plain | `+ region` |
|---|---:|---:|
| loop time | 106.5 ms | **177.8 ms (1.67×)** |
| allocations served by the arena | — | **0 of 10 201 215** |
| regions entered | — | 20 000 |
| manifest | T2 owned ×4 | byte-identical |

The annotation costs 67% and reclaims nothing. It now warns:

```
warning: region frame_arena serves no allocation; it costs an arena push and pop
         per entry and reclaims nothing
```

**The 9.9× sometimes quoted for g2 is not a Prismio number.** It is headroom from
the C arena benchmark (`aif/evidence/bench`: C -O2 arena is 0.09× of C -O2
idiomatic on G2). It becomes a result when AIF places those allocations.

## 5 · What a region *can* serve

`tests/test_58_region_serves.psm` is the positive control, and it asserts the
count at run time — `arena_objects()` is the only way to tell an arena pointer
from a malloc'd one, since the values are identical.

```prismio
region work {
    let mut keep = Cmd { id: 0, weight: 0 }   // declared in the region's scope
    let mut i = 0
    while (i < 50) {
        keep = Cmd { id: i, weight: i * 2 }   // 50 allocations, all from the arena
        i = i + 1
    }
}
```

50 of 50 served. The allocation escapes its own block — so the T0 clause
declines — but not the region, is held by no container, and is in the same
function as the `region`. Move the same `Cmd { … }` one function down and it is
0 of 50, which is the other half of that fixture.

## 6 · `list_new_with_capacity`, the one speed result

Not an arena change, and the only measured win in this area. `cull` builds a
fresh ~501-element list every frame for 20 000 frames, paying seven
reallocations and 508 pointer copies each time.

| | loop ms, median | ratio |
|---|---:|---:|
| `g2.psm` | 110.3 | 1.000 |
| `g2_capacity.psm` | 101.7 | **0.923** |

21 interleaved runs (not back to back — see HANDOFF 2026-08-13 on ordering
drift). Checksums identical.

**Priced before it was built.** Raising `list_new`'s default capacity to 512 —
which removes exactly the same reallocations and is therefore the ceiling this
API can reach — measured **0.926×**. The shipped feature lands at 0.923×, so it
captures essentially all of the available win.

## 8 · How much call-site bracketing could reach *(2026-08-16)*

The census now prints a second table. §1's says what the lexical gate serves;
this says how much of the remainder is in a function a caller's `region` could
bracket — SPEC 5.2.1.1's obligations, computed per function as a fixed point
over the call graph and reported per site by `--why`.

| | of 196 blocked sites |
|---|---:|
| in a function that clears every obligation | **70** |
| …**and** whose call sites are inside a region | **2** |

Both halves are needed and the second is the one that is usually zero. Every
corpus program that does not say `region` contributes 0, because nothing calls
its functions from an arena. The two that count are `g2_region.psm`'s `cull` and
`submit`, which is the tuning fixture — and `cull` is where the 10.02 M
allocations are.

Per function, over `aif/corpus` and `aif/evidence`:

| | range across programs | `g2_region.psm` | `src/main.psm` |
|---|---|---:|---:|
| clears obligations 1, 2, 4 | 4–11 of 35–45 | 6 / 35 | 189 / 463 |
| …and regime (a): one call site | 1–5 | 4 | 48 |
| region call sites reaching one | 0 | **2 of 2** | 6 of 635 |

**The dominant blockers are not the interesting ones.** `opaque` (a callee with
no visible body and no complete FFI contract) sits on ~29 functions in every
program — that is `std/io`, not user code. `shared-body` is regime (a)'s
restriction rather than a soundness obligation, and SPEC 5.2.1.1 (b) lifts it.
`param-store` — obligation 2, the counterexample the whole summary exists for —
is on 0 functions in g2 and 9 in `g5_asset_cache`, which is a cache that writes
into structures its callers own. `global` is 0 everywhere.

**PLACEABLE is an upper bound, not a prediction.** It says the *call* may be
bracketed. Whether the site is then served still depends on §1's per-site
clauses: `in_container` and `is_list` reject a value the deallocator would take,
and clearing those for a bracketed extent is the disposition half. That half
landed 2026-08-16 as a single clause in `elem_disposition_of` and is **inert
today** — verified byte-identical IR on all 84 compilable programs in `tests/`,
`aif/corpus/` and `aif/evidence/`, and an unchanged `--verify` ledger
(`released` and `violations`, per program) against the previous generation.

Do not compare `allocated` or `leaked` from `--verify` across runs: the timing
programs print nanosecond clock values and the printing path allocates per
digit, so `g2.psm` moves by ~1500 allocations between two runs of **one**
executable. `released` and `violation(s)` are the stable numbers. Measured
before reading anything into a difference, because the first run of that
comparison showed seven programs "moving" and none of them had.

## 7 · What would actually close this

In rough order of cost:

1. **Call-site placement.** The caller brackets a call whose callee allocations
   are all provably bound by the region, using the `rt_arena_hint_push/pop`
   mechanism that already exists for runtime-internal allocation. **The summary
   and the disposition landed 2026-08-16** (§8, SPEC 5.2.1.1); what remains is
   the placement itself. Its two open pieces, both worked out and neither
   built — do not re-derive them:

   * **Obligation 3 needs a fact the model does not have.** "The returned value
     does not outlive `R`" is not readable from `E`: a callee's site binds in
     the caller through `AIF_CON_LIVE_IN`, whose transfer sets `E = Caller`
     whenever `sites[s].fn != k->c`, precisely because a scope id in one
     function does not order against one in another. The fact wanted is the
     **caller-side binding scope** of each callee-allocated site, and it can be
     recovered without any frontend change: after the solve, walk `cons[]` for
     `AIF_CON_LIVE_IN` and record `(site, k->c, k->b)` for every site whose `fn`
     is not `k->c`. Obligation 3 is then "every caller binding is in the
     bracketing caller, at a scope at or below `r`".
   * **Bracket only into `region`-pinned arenas, never cost-model-chosen ones.**
     Otherwise there is a circularity: `enclosing_region` reads
     `scopes[].arena`, which `aif_place_arenas` sets from `arena_would_serve`,
     which would have to count bracketed sites as benefit — placement depending
     on bracketing depending on placement. A `region` sets `scopes[].arena` at
     parse time, before placement runs, so restricting to it cuts the loop and
     leaves `arena_would_serve` (the one clause-list copy that is *not* behind
     `site_arena_scope`) correct without change.

   And one semantic decision it forces: a bracketed site keeps its **derived
   tier** — the manifest will show `T2  region:<name>`. The tier is the derived
   fact and placement is the codegen decision (SPEC 5.2 says so); making the
   tier T1 instead would change the tier distribution, and the oracle does not
   model arena placement, so the differential would fail on a difference that is
   not an inference difference.
2. **Ownership contexts** (INFERENCE §6–7) — instantiate the callee per call
   site, which makes the caller's region nameable. Item 1 is its cheap subset.
3. **Inline before placing.** No inliner exists.

None is a change to the escape lattice. A proposal that only changes `E` should
be run against `arena_census.py` before it is built.
