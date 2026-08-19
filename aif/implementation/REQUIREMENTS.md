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

### 1. Affine collections — `String`, `List<T>`, arrays become move-only **[done, 2026-08-07]**

~~`types.psm:92` makes only structs move-only.~~ Everything else is freely copyable, so any collection
reachable from two places is `Shared`, and A-STORE propagates that to **every element inside it**.

Done for `String` and `List`. **Arrays deliberately excluded**: an array literal lowers to
`ir_array_alloca`, so there is no allocation to own and `drop(arr)` would free a stack pointer. See
COMPILER-AUDIT's Level 4 note.

**Measured impact: this single fact is 100% of the T3 residue in every program tested.** Turning it
on takes all five corpora from 0–75.7% to **100% T0–T2**.

*Source:* [RESULTS-L0.md](../evidence/RESULTS-L0-tiers.md) §2. Already required by SPEC §11 item 10;
`types.psm`'s own comment anticipates it.

### 2. `region { }` — keyword, arena runtime, handle threading **[done, 2026-08-07]**

~~The frame arena is the dominant allocation pattern in real-time code. Currently untestable~~: the
keyword landed at Level 3, the arena runtime with it, and automatic placement (LAYOUT §7.1) at
Level 4. The handle is **not** threaded — the arenas are a dynamically scoped stack, which keeps
`ir_alloc_region` a `fn(size) -> ptr` and costs exactly one case; see the Level 3 note.

**Measured relevance:** every game-corpus allocation lands T2 rather than T1 because values escape
to the caller. Frame-scoped arenas are the largest untested upside for the target workload.

**And that prediction did not survive contact.** The corpus gained *nothing* from arenas, because it
has no T1 sites at all — its allocations are T0 or T2, and a value that escapes to the caller cannot
come from a frame arena no matter how the arena is placed. The compiler gained everything: 186 T1
string sites, all arena-served. Arenas pay where T1 lives, and T1 turned out to live in
string-processing code rather than in the struct-and-container corpus this section was written from.
The corpus's residue needs item 3's shared references and container ownership, not arenas.

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

### 4. Optional / nullable reference fields — **DONE, 2026-08-07**

`T?` for any reference type, a `none` literal, `==`/`!=` against `none`, and `expect(x)` as the
checked unwrap. Implicit widening from `T` to `T?`; never the reverse.

**`none` is a null pointer, and that choice is the whole of the punned-slot question.** This
compiler already had a way to spell "empty slot" — a pointer to `""`, tested with `str_equals(p, "")`
— and that encoding reads the *first byte of the pointed-to object*, so a live value whose first
field is zero is byte-for-byte an empty slot. It is why `NodeKind` and `TypeKind` reserve ordinal 0,
why the layout search pins field 0, and what `test_41` characterises. A null comparison reads no byte
of any object, so **nothing can collide with it**, whatever a live value's first field holds. Reusing
`""` would have inherited the collision and spread it from the compiler's own punned pointers into
every user program. `test_51`'s `zero_first_field_is_still_present` aims exactly that case at the new
encoding.

Four things worth keeping:

- **The unwrap is checked, not narrowed.** Flow-sensitive narrowing of `if (x != none) { … }` is a
  real feature and is not this item; `expect(x)` costs one branch in the runtime and fails loudly
  where narrowing would have failed silently. It is also the shape this compiler already writes by
  hand — `if (node_exists(p)) { let n = ptr_to_node(p) }`.
- **`expect` borrows.** Treating it as a move would make `while (cur.parent != none) { cur =
  expect(cur.parent) }` fail on the second iteration. It is declared `alias` to the analysis for the
  same reason: it is the identity on a pointer, and an opaque extern return would have raised the
  unwrapped value's escape to Caller.
- **Optionals change the type, not the ownership.** Storing a `Node` into a `Node?` field is a move,
  exactly as into a `Node` field. `none` registers no allocation site, so a sometimes-absent field's
  release is derived from the sites that *are* there — which is why every release path now has to
  tolerate a null, and all four do.
- **It forced a guard into struct-field ownership.** `struct Node { parent: Node?, … }` is the first
  type in this project that can reach itself, and a generated release for it would recurse until the
  stack gave out. `field_closes_cycle` declines any field whose type reaches its owner. That is the
  boundary between statically generated release and the T4b collector, and it could not be drawn
  before this item existed — which is precisely why CYCLES had nothing to run against.

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

**Landed 2026-08-06** — parameter and return contracts, in FFI §5.4's postfix form:

```prismio
extern fn ptr_to_node(ptr: String borrow) -> ASTNode alias
extern fn list_push(list: List borrow, item: Ptr retain_in(0))
extern fn fopen(path: String borrow) -> File produce(fclose)
```

Contextual identifiers rather than reserved keywords, so `borrow`, `out` and `alias` remain usable
as ordinary names; parsed only inside an `extern` declaration, never by the shared type parser.
Sema rejects a return contract on a parameter, a parameter contract on a return, an out-of-range or
self-naming `retain_in(k)`, and a `produce` with no deallocator — FFI §1 makes this the one place in
AIF where being wrong is unsafe rather than slow, and nothing downstream can catch it.

`pure` and `nocallback` (§5.3) are **not** implemented: they drive the fact invalidation of FFI §6,
which AIF-1 does not model at all. They trail the declaration, so adding them later breaks nothing.

The measured effect is in [RESULTS-L0.md](../evidence/RESULTS-L0-tiers.md)'s correction note: 27% →
58% T0–T2 on the compiler from four `alias` declarations, and 72% with affine collections — the
first time this corpus clears H1's kill criterion.

### 9. The four annotations — `unique`, `region`, `workload`, `pin` **[all four done, 2026-08-13]**

~~None exists in `keywords.psm`.~~ Per TARGET §2.1 these are engine-layer tools; gameplay code should
never need them.

- `region` — done at Level 3. A keyword, because it opens a statement.
- `unique`, `pin` — done. **Contextual identifiers, not keywords**, so a program may still use both
  as names: SPEC §5 requires that deleting every annotation leave a working program, and reserving
  the words would break the programs that never asked for them. Same treatment as the FFI contracts.
- `workload` — **deliberately not implemented.** SPEC §5.3 leaves its syntax and semantics open, and
  it feeds a layout cost model (§9) that does not exist. Building it now would mean inventing
  specification for a consumer that cannot use it. Do it with LAYOUT §7.2, not before.

### 10. Per-module optimisation levels **[specified 2026-08-17, not implemented]**

SPEC §7.2 defines levels per *build*. The target needs them per *module*: engine at `max`, compiled
once and cached; gameplay at `debug`, rebuilt constantly. A single per-build level forces a choice
between a slow iteration loop and an unoptimised engine.

Sound by the invariant — every tier is semantically valid, so mixing levels cannot change
behaviour — ~~but unspecified~~. **Specified as SPEC §7.5.** Four obligations that are not obvious
and are the reason it needed writing down rather than building:

- A level boundary is an **inference boundary**: a module analysed at `release` must treat a
  `debug` module's functions as an undeclared `extern` (FFI §1's conservative default), because a
  `debug` module proved nothing. Reading summaries across the boundary rests a tier on an analysis
  that never ran.
- Lowering a module's level invalidates every module that depends on it, the same way INFERENCE §9
  invalidates a reverse-reachable set. The level is part of the cache key.
- **Layout is not per module** — one layout per type, chosen by the declaring module, read from the
  manifest by every other. Two modules disagreeing about a field offset is a miscompile.
- **`verify` is not per module** — the allocator seam has to swap at both ends of every allocation.

It also needs the thing this compiler does not have: a compilation unit. Everything is merged into
one module before sema runs (`resolveImports`), and the emitted IR is one `.ll`, so there is no
per-module object to compile at a level or to cache. That is the same prerequisite REQUIREMENTS 21
(PIR) names, and it is what makes this item large rather than the specification.

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

### 13. Generic containers — `Map<K,V>`, growable `Vec<T>` — **PARTLY DONE, 2026-08-19**

The inference engine needs a graph with dynamic insertion, per-node lattice records, a worklist,
and hashing over context tuples. Prismio has structs, fixed arrays and a hardcoded `List<T>`; no
generics, methods, or closures.

It is writable with parallel arrays and integer indices — the current compiler is written that way
— but it is materially larger and more error-prone in the one component where a silent bug yields a
wrong-tier binary. **Land containers before the engine, not after.**

**Generics landed** (`src/sema/generics.psm`), with monomorphisation: `fn f<T>`, `struct S<K,V>`,
inference from argument types, explicit arguments where inference has nothing to read. One body per
distinct type-argument tuple, so `Box<Int>` emits `{ i32 }` and not a boxed pointer.

**`Vec<T>` needed nothing, and that is the finding.** `List<T>` *is* the growable vector —
`XefyList` in `lang_runtime.c` is a `void**` that doubles on push, and the runtime's own comment
calls `list_new_with_capacity` "Vec::with_capacity". A `Vec<T>` would have been a second name for
it. This item read as two missing containers for six sessions and was one.

**`Map<K,V>` landed** as `std/map.psm`, in Prismio, over two `List`s. Two limits, both language
gaps rather than unfinished work:

- **Lookup is linear, not hashed.** Hashing `K` needs a hash function per key type and a way to
  dispatch to it, which is bounded type parameters — traits. Every function is written in terms of
  `mapIndexOf`, so bounds turn that one body into a hash table with no caller change.
- **Keys must be `==`-comparable, i.e. scalar.** `Map<String, V>` does not instantiate, because
  `String ==` is deliberately rejected. Less limiting than it looks for the caller this item exists
  for: `aif_support.c` interns everything to `int` ids and keys its tables on those.

**How much of `runtime/aif_support.c` should now move into Prismio? Almost none, and the blocker is
item 18 rather than a judgement call.** Its containers are bitsets, interning tables, points-to key
tuples and a worklist, all over raw memory. Writing any of them in Prismio needs two things the
language does not have: the size of a type (item 18, still open) and a way to index raw memory as
`T` — `Ptr` is opaque, with no arithmetic, no deref and no indexing. `List<T>` cannot be written in
Prismio either, for exactly this reason, which is why item 1's replacement test could not be run as
written. What *can* move today is anything expressible as a map or list over interned integer ids,
which is the solver's bookkeeping but not its storage. Revisit when item 18 lands; until then the
answer is "none", and it is a capability statement rather than an inherited preference.

*Source:* GAPS §4.3.

### 14. Error handling — tagged unions, `Option` / `Result` — **DONE, 2026-08-19**

Failure was signalled by sentinel return values. Overlaps with item 4.

**Done.** Enum variants carry payloads (`src/sema/enums.psm`), and `Option<T>` / `Result<T, E>` are
ordinary generic enums in `std/option.psm` — nothing about them is in the compiler.

**The representation is a tagged *product*, not a tagged union, and that is forced by item 18.**
Overlapping the variants needs the size of the widest one, so instead each payload slot gets its
own field: `enum Shape { Dot, Circle(Int), Rect(Int, Int) }` becomes
`struct Shape { $tag: Int, Circle$0: Int, Rect$0: Int, Rect$1: Int }`. `Option<T>` loses nothing —
one variant carries anything — while a many-armed enum is larger than it needs to be. When item 18
lands, the overlap goes in that one file and no caller changes.

The desugaring is an AST transform, so sema, AIF, the layout optimiser and codegen were not taught
what a payload enum is; they see a struct, and field access stays a `getelementptr`. Same
architecture as monomorphisation, deliberately.

Four things to know before touching it:

- **Tags are one-based.** The tag is the struct's first field, and no type punned through `String`
  may have a zero-valued first field — a struct whose first four bytes are zero is
  indistinguishable from an empty slot. A first variant with tag 0 would make every value of it
  read as absent.
- **Variant order is the compiled form.** The tag is the variant's position, so reordering the
  variants of `Option` changes what already-compiled code expects. Append, never insert.
- **It found and fixed a pre-existing defect.** A struct literal that omitted a field type-checked
  and then *read uninitialised memory*: allocation is `malloc`, and codegen only stored the fields
  the literal listed. `semaFillOmittedFields` now appends a zero for every omitted field, for all
  structs rather than only these. That is also what makes `Option.None` safe — it mentions only the
  tag, and the `Some` slot has to be a defined value.
- **`Result.Ok(5)` cannot infer `E`.** Type arguments are solved from what a variant carries, and
  nothing in `Ok` mentions the error type; there is no inference from the expected type. It must be
  written `Result<Int, String>.Ok(5)`, and the compiler says so by name (`neg_28_enum_infer`).

**Exhaustiveness is checked.** A match over a payload enum must cover every variant or carry a `_`
arm, and the diagnostic names what is missing (`neg_29_match_not_exhaustive`). A second arm for a
variant an earlier arm already matches is rejected as unreachable (`neg_30_unreachable_arm`). Both
are payload enums only: a fieldless enum still matches as an integer, where the scrutinee is not
confined to the declared variants, so matching a subset stays legal.

Not done, each for a stated reason rather than for lack of time:

- **No propagation operator.** It needs a defined interaction with ownership and with cleanup during
  a non-local exit; neither is specified, and shipping the syntax first is the producer-with-no-
  product mistake this file has made before.
- **No `unwrap`.** Deliberate. `optionOr`/`resultOr` take a fallback, so the absent case is handled
  at the use site rather than deferred to a crash.
- **`Result.Ok(5)` cannot infer `E`.** Type arguments are solved from what a variant carries, and
  nothing in `Ok` mentions the error type. Fixing it means inference from the *expected* type — a
  bidirectional pass, which is its own feature. Diagnosed by name in the meantime.

### 15. Concurrency / task model **[needed for `T`]**

No tasks, so the thread-affinity domain is vacuous and T4a is unreachable by construction. For a
job-system target this moves from AIF-3 to gating: INFERENCE's E-SPAWN vs E-SPAWN-J rule is what
decides whether job-local data lands T1 or T4, and it needs a task model to attach to.

### 16. Fix superlinear compile time — **DONE, 2026-08-17**

Sema scans the module per identifier for function lookup (~290 ms for the 155 KB compiler, ~500 ms
for a 105 KB single module). Whole-program fixed-point iteration lands on top of that; fix it first
or AIF's cost cannot be attributed.

**Fixed.** There were four scans, not one, and they were in three passes:

| where | what it scanned | per |
|---|---|---|
| `semaFindFunctionOverload` | every top-level declaration | call site |
| `find_binding` (`ir_symbols.c`) | the whole binding table, whose floor is one `$fn$` entry per function | identifier, in sema *and* in codegen |
| `hasNamedTopLevel` (`main.psm`) | everything merged so far | merged declaration |
| `appendStatement` (`main.psm`) | to the end of the list | merged declaration |

All four are gone: a name → declaration index in `ir_symbols.c` filled once per module, a
dedicated table for function return types, and a cached tail for the merge. Measured, minimum of
five runs, on a 4 000-function module: `check` 1.241 s → **0.088 s**. On the compiler's own 518 KB
of source: `check` 0.126 s → **0.039 s**, emit-IR 0.183 s → **0.090 s**. Frontend time is linear in
module size over 31 KB–922 KB.

Attribution, which is what this item existed for: the whole AIF fixed point costs **18 ms** on the
compiler's own source — 19% of the frontend and under 1% of a build. See HANDOFF "Session of
2026-08-17 (compile time)".

*Source:* `self/HANDOFF.md` known gaps.

---

## Tier 4 — minor, found in passing

### 17. `Int` ↔ `Float` conversion **[minor]**

No `int_to_float`. Hit while writing `../corpus/g1_particles.psm`; worked around with a float
accumulator.

### 18. Struct size / layout introspection **[minor]**

Tier assignment needs real sizes for SPEC §4.2's `Θ_stack` threshold. The prototype approximates
with field count.

### 19. Memory budget reporting — **DONE, 2026-08-07**

`peak-bytes` in the manifest, and `region <name> pin(N)` as the gate.

**The peak is the largest sum along a root-to-leaf chain of arena scopes**, not the total: arenas
nest lexically, so sibling regions are never live together and adding them would report a number the
program cannot reach. Weighted by `AIF_LOOP_ITERS` per enclosing loop — the same estimator automatic
placement uses for `allocs_in(s)`, so the two cannot disagree about how much a scope serves.

Three things worth keeping:

- **The estimate names the part it cannot see.** `arena_bytes()` is a *run-time* counter and a
  manifest is a build artifact, so this is computed statically. A struct's size comes from its
  layout; a string's is its length, which is a run-time value. Sites of unknown size are counted
  separately (`247 dynamically-sized site(s) excluded` on the compiler's own source) rather than
  given a fabricated per-string constant — which would make the gate turn on a number nobody
  computed. On the compiler that leaves the estimate at 0 bytes, which is the honest answer: every
  arena-served site there is a string.
- **The cap goes on a `region`, not on a binding.** A budget is a property of a block's peak and not
  of one value, which is the one thing SPEC §5.4's `pin` had nothing to say about. Contextual like
  every other use of `pin`, so a region may still be called `pin`.
- **It is only checked when the analysis converged.** A truncated one raises unproven facts to the
  conservative end, which *lowers* an arena's estimated load — fewer sites stay T1 — so a budget
  could pass for want of analysis and fail on the next build.

A refuted budget is an error rather than a warning for the reason SPEC §5.4.1 gives about pins: an
inference *failure* degrades performance, and a proven-false claim about one's own program is a
different thing. `test_53_memory_budget.psm` and `neg_24_region_budget_refuted.psm`.

*Source:* the AAA target; not yet in any spec document.

---

### 20. `List<T>` miscompiles for scalar element types — **DONE, 2026-08-07**

`list_push` on a `List<Int>` emitted a call passing `i32` where the runtime signature expects `ptr`,
and LLVM module verification rejected the result. `List<T>` worked only for pointer-shaped elements.

```
Call parameter type does not match function signature!
 ptr  call void @list_push(ptr %23, i32 %24)
```

**A scalar rides in the container's pointer-sized slot rather than being boxed.** Boxing was the
alternative and is worse twice over: an allocation per element, and the container would then have
something to *own*. A scalar element allocates nothing, so it registers no site, so
`aif_elem_owner_at_node` answers NONE and the teardown steps over the list — **the memory model needs
no case for this at all**, which is the property that makes the representation the right one. A
container that thought it owned scalars would hand `42` to the deallocator, which is a *violation*
under `--verify` rather than a leak.

Three details worth keeping:

- **The round trip preserves bits, not value.** A `Float` bitcasts to its 64 bits and reinterprets;
  an `fptosi` would store `0.5` as `0`. The integer family widens to pointer width and truncates on
  the way back, which is what recovers a negative `Int`.
- **The coercion is keyed on argument position**, not on "the last argument": `list_push(l, v)` is
  index 1 and `list_set(l, i, v)` is index 2.
- `list_get` is declared to return `ptr` while sema types it as the element type, so the return side
  needed the same treatment as the argument side and was equally broken.

`tests/test_50_scalar_lists.psm` is the coverage, and the *allocation* count in the runner is the
half that matters — 12 for six lists, two each, nothing per element.

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
