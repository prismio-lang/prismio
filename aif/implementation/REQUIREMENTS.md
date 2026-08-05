# AIF — Compiler Requirements

*What a compiler must provide for AIF to work. Items are ordered by measured impact. Not every
entry is an AIF requirement — the tiers say which; see also ROADMAP §5.*

**A running list. Not a plan, and not a criticism of the current compiler** — its memory handling
is deliberate scaffolding, and AIF replaces it. This file exists so that requirements discovered
while designing and measuring AIF get recorded instead of re-derived later.

Append to it. Each entry says what AIF needs, why, and where the requirement came from.

Status legend: **[blocker]** AIF cannot work without it · **[needed]** required for a specified
feature · **[enabling]** unblocks work on AIF itself · **[minor]** small, found in passing.

---

## Tier 1 — measured, highest impact

### 1. Affine collections — `String`, `List<T>`, arrays become move-only **[blocker]**

`types.psm:92` makes only structs move-only. Everything else is freely copyable, so any collection
reachable from two places is `Shared`, and A-STORE propagates that to **every element inside it**.

**Measured impact: this single fact is 100% of the T3 residue in every program tested.** Turning it
on takes all five corpora from 0–75.7% to **100% T0–T2**.

*Source:* [RESULTS-L0.md](../evidence/RESULTS-L0-tiers.md) §2. Already required by SPEC §11 item 10;
`types.psm`'s own comment anticipates it.

### 2. `region { }` — keyword, arena runtime, handle threading **[needed]**

The frame arena is the dominant allocation pattern in real-time code. Currently untestable: no
keyword, no arena allocator, and `ir_alloc_object` takes only a size, so there is nowhere to pass
an arena handle.

**Measured relevance:** every game-corpus allocation lands T2 rather than T1 because values escape
to the caller. Frame-scoped arenas are the largest untested upside for the target workload.

*Source:* RESULTS-L0 §6, SPEC §5.2, LAYOUT §7.1.

### 3. Shared references **[blocker for T3/T4]**

There is no way to express two live owning references to one value. Consequences:

- T3 and T4 are **unreachable in the language** — not because programs don't need sharing, but
  because it cannot be written.
- The entire cycle collector ([CYCLES.md](../spec/CYCLES.md)) is specified against a feature that does not
  exist and cannot be validated.
- Engine-layer asset sharing — one mesh referenced by 1000 entities — is inexpressible, which is
  the core engine data shape ([TARGET.md](TARGET.md) §2.2).

*Source:* RESULTS-L0 §4.2. Found by trying to write a parent back-reference in `g3_scene_graph.psm`
and having the move checker reject it.

### 3a. Closures **[blocker for Xefy]**

Declarative UI is closures — `onPressed`, builder functions, state callbacks. A Flutter-shaped
framework cannot be written without them, so this gates the compiler's first real consumer
([TARGET.md](TARGET.md) §0).

They also capture, which makes them the main genuine source of shared ownership — the T3 case that
handle-based engine code avoids. Closure capture is where AIF's aliasing analysis will actually be
exercised.

### 4. Optional / nullable reference fields **[needed]**

No null literal and no `Option`, so a struct field of reference type cannot be "not set yet."
Blocks parent pointers, optional components, empty slots — all routine in engine code.

*Source:* RESULTS-L0 §4.2 (`parent: 0` → *expected Node, found Int*).

---

## Tier 2 — required by specified AIF features

### 5. A pass between sema and codegen **[enabling]**

`ir.psm` walks the AST emitting backend calls inline. AIF needs
`sema → [fact graph → inference → tier assignment → manifest] → ir`, because codegen has to know a
value's tier before emitting its allocation.

Smallest viable version: integer ids on AST nodes at parse time, plus a side table indexed by them.
Unblocks nearly everything else.

*Source:* GAPS §4.1.

### 6. Three allocation hooks, not one **[needed]**

`ir_alloc_object(struct_name)` emits a call to `fn(size) -> ptr`. That expresses T2/T3/T4 by
swapping a name and **cannot express T0 or T1** — the two tiers carrying the performance claim.

```
ir_alloc_stack (struct)               -> alloca, hoisted to entry block
ir_alloc_region(struct, arena_value)  -> bump, from a threaded handle
ir_alloc_heap  (struct)               -> the current path
```

*Source:* GAPS §3.

### 7. Scope-based drop / RAII **[needed]**

`drop(x)` is explicit and manual. SPEC §11 item 11 requires deterministic destruction on T0–T2,
which needs drops emitted at every scope exit — fallthrough, `return`, `break`, `continue`, and
early returns from nested blocks — in reverse construction order.

*Source:* GAPS §4.2.

### 8. Ownership contracts on `extern` declarations **[needed]**

`borrow` (default) · `retain` · **`retain_in(k)`** · `consume` · `out`, plus `alias` /
`produce(free_fn)` on returns and `nocallback` / `pure` at call sites.

Without them the analysis has to guess, and both guesses are wrong: `borrow` is optimistic
(unsound), `retain` costs 33 points of tier distribution. **Measured**, on the compiler corpus:
`borrow` 75.7% vs `retain` 42.8%.

`retain_in(k)` was added to FFI.md *because* of this measurement — `list_push` is neither `borrow`
nor `retain`, and collections are the most common FFI shape in a systems language.

*Source:* [FFI.md](../spec/FFI.md) §5, RESULTS-L0 §4.1 and §5.

### 9. The four annotations — `unique`, `region`, `workload`, `pin` **[needed]**

None exists in `keywords.psm`. Per TARGET §2.1 these are engine-layer tools; gameplay code should
never need them.

### 10. Per-module optimisation levels **[needed]**

SPEC §7.2 defines levels per *build*. The target needs them per *module*: engine at `max`, compiled
once and cached; gameplay at `debug`, rebuilt constantly. A single per-build level forces a choice
between a slow iteration loop and an unoptimised engine.

Sound by the invariant — every tier is semantically valid, so mixing levels cannot change
behaviour — but unspecified.

*Source:* TARGET §2.5.

### 11. `verify` build mode **[needed]**

Every inferred fact becomes a runtime assertion (SPEC §7.3). Required at every conformance level,
because without it a wrong transfer function produces a silently wrong binary rather than a crash.

### 12. Handles instead of raw pointers **[needed, long-horizon]**

`ir_struct_field_ptr` emits `getelementptr` on a raw `ptr`, and ~104 externs in `bridge.psm` pass
pointers. SPEC §11 item 5 requires relocatable handles — it is the enabling condition for the
entire layout optimiser and for the static region (SPEC §8.3).

Deepest change on this list.

---

## Tier 3 — enabling AIF's own implementation

### 13. Generic containers — `Map<K,V>`, growable `Vec<T>` **[enabling]**

The inference engine needs a graph with dynamic insertion, per-node lattice records, a worklist,
and hashing over context tuples. Prismio has structs, fixed arrays and a hardcoded `List<T>`; no
generics, methods, or closures.

It is writable with parallel arrays and integer indices — the current compiler is written that way
— but it is materially larger and more error-prone in the one component where a silent bug yields a
wrong-tier binary. **Land containers before the engine, not after.**

*Source:* GAPS §4.3.

### 14. Error handling — tagged unions, `Option` / `Result` **[enabling]**

Failure is signalled by sentinel return values. Overlaps with item 4.

### 15. Concurrency / task model **[needed for `T`]**

No tasks, so the thread-affinity domain is vacuous and T4a is unreachable by construction. For a
job-system target this moves from AIF-3 to gating: INFERENCE's E-SPAWN vs E-SPAWN-J rule is what
decides whether job-local data lands T1 or T4, and it needs a task model to attach to.

### 16. Fix superlinear compile time **[enabling]**

Sema scans the module per identifier for function lookup (~290 ms for the 155 KB compiler, ~500 ms
for a 105 KB single module). Whole-program fixed-point iteration lands on top of that; fix it first
or AIF's cost cannot be attributed.

*Source:* `self/HANDOFF.md` known gaps.

---

## Tier 4 — minor, found in passing

### 17. `Int` ↔ `Float` conversion **[minor]**

No `int_to_float`. Hit while writing `../corpus/g1_particles.psm`; worked around with a float
accumulator.

### 18. Struct size / layout introspection **[minor]**

Tier assignment needs real sizes for SPEC §4.2's `Θ_stack` threshold. The prototype approximates
with field count.

### 19. Memory budget reporting **[needed for consoles]**

Fixed memory budgets are a hard constraint on console targets and AIF has nothing on them. Arenas
make it tractable: compute an arena high-water mark from the profile, report it in the manifest,
and let `pin` carry an asserted cap that fails the build gate when exceeded.

*Source:* the AAA target; not yet in any spec document.

---

### 20. `List<T>` miscompiles for scalar element types **[minor, real bug]**

`list_push` on a `List<Int>` emits a call passing `i32` where the runtime signature expects `ptr`,
and LLVM module verification rejects the result. `List<T>` works only for pointer-shaped elements.

```
Call parameter type does not match function signature!
 ptr  call void @list_push(ptr %23, i32 %24)
```

*Source:* [RESULTS-L2.md](../evidence/RESULTS-L2-boundary.md) §5, hit writing `../corpus/g6_game.psm`.

---

### 21. PIR — the compiler's IR and package-distribution format **[compiler track]**

Not a memory-model concern. Needed because LLVM IR is version-locked and cannot be a package
format, the same reason Swift has `.swiftinterface`. Encoding, versioning, sections, content
hashing, merge and deduplication rules are toolchain design.

Design work is already done and kept as reference in [PIR.md](../spec/PIR.md) §§2–4, 6, 8–9. AIF's four
actual requirements on it are in that file's scope note.

---

## Already done

- **`prismio dump-ast`** — emits the post-sema AST as JSON. Additive: IR is byte-identical before
  and after, suite 57/57. `self/src/dumpast.psm` + `dump_ast_command` in `main.psm`.

- **Item 5, a pass between sema and codegen** — landed 2026-08-05 as `self/src/aif.psm`, with the
  containers item 13 asks for supplied by `self/runtime/aif_support.c` rather than by the language.
  That is the same split `ir_symbols.c` already makes and it removes item 13 from the critical path
  without removing the requirement: the engine is written in Prismio and its bitsets, interning and
  key map are written in C.

  It did **not** need the AST node ids this file proposed. Sites are identified by the walk that
  creates them and named in the manifest by `⟨function symbol, ordinal within function⟩`, which is
  what makes a diff readable — a record does not move when an unrelated line elsewhere in the file
  does. Node ids will still be wanted the moment codegen has to look a tier up (Level 1).

  Scope: COMPILER-AUDIT §5 Level 0 exactly. Facts, tiers, manifest; no codegen change.
  `prismio aif <source.psm> [--summary] [--owned-collections]`.

  Verified: agrees with `aif/prototype/aif.py` site-for-site on all eight sources under both
  collection settings (`python tools/aif_differential.py`); self-host reaches a fixed point from
  the committed seed; suite 58/58, the new one asserting one tier per SPEC §4.2 clause.

- **A number on item 8.** The first thing the engine found on its own source is that FFI contracts,
  not affine collections, dominate the compiler's residue — 383 of 552 sites are opaque extern
  returns. See the correction note in [RESULTS-L0.md](../evidence/RESULTS-L0-tiers.md).
