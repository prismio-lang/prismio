# AIF — Gap Analysis

**What `self/` can actually support today, per frozen requirement.**

Written against the compiler as of 2026-08-01, by reading source rather than docs. Every claim
below cites a file and, where it matters, a line. Companion to [SPEC.md](../spec/SPEC.md) and
[INFERENCE.md](../spec/INFERENCE.md).

The short version: **the compiler is in good shape and AIF is much further away than the seam
comment suggests.** `HANDOFF.md` says the memory-model seam is ready because allocation funnels
through two policy hooks. That is true for half the ladder and misleading for the other half, and
there are three prerequisites nobody has costed.

---

## 1 · Headline findings

| # | Finding | Severity |
|---|---|---|
| 1 | The alloc seam is a **function-name swap**. It can express T2/T3/T4 and **cannot express T0 or T1** — the two tiers that carry the model's performance claim. | High |
| 2 | Structs today have **pointer semantics with move checking**, not value semantics. AIF's "aliasing is unrepresentable" premise does not hold in the implementation. | High |
| 3 | **No scope-based drop exists.** `drop(x)` is explicit and manual. Frozen item 11 (RAII on T0–T2) has no substrate. | High |
| 4 | ~~**Strings, arrays and lists are never freed and are not move-only**~~ — and they are the majority of real allocations. Anything AIF does to structs alone moves a minority of the traffic. **Closed by Level 4** for strings and lists; arrays stay copyable because they are frame storage. | Was High |
| 5 | **Prismio cannot comfortably express its own inference engine.** No generics, no closures, no hash maps; `List<T>` is a hardcoded special case. A worklist fixed-point solver needs all three. | High, underrated |
| 6 | **Handles do not exist.** References are raw `ptr`, field access is `getelementptr`, and 104 extern declarations pass pointers to C. Frozen item 5 touches every layer. | High, long-horizon |
| 7 | ~~**There is no concurrency**, so the `T` domain is vacuous and T3 vs. T4a is currently undecidable-by-absence. Everything shared lands T3.~~ **Closed 2026-08-19** by REQUIREMENTS 15: `spawn`/`join` with moved arguments, the full thread module (INFERENCE 4.3) in both the solver and the oracle, and T4a emitted with an atomic count. "Actually simplifying" was the right call at the time and it had an expiry date: what it was deferring was not the *rules* but the answer to whether T3's non-atomic count is sound, and nothing could establish that while nothing crossed a thread. Verified: a single-threaded program emits byte-identical IR to before the change. | Was Medium |
| 8 | Compile time is **already superlinear** in module size (`HANDOFF.md` known gaps). Whole-program fixed-point iteration lands on top of that. | Medium |
| 9 | The compiler **leaks by design and exits** — so it is already, in effect, a one-region program. AIF's first win on its own source will be small. Pick a different first benchmark. | Medium |

---

## 2 · Frozen items, one by one

Against SPEC §11's twelve normative items.

| # | Frozen item | Status | Evidence |
|---|---|---|---|
| 1 | The invariant | **Partial — needs a spec clarification** | See §2.1 below |
| 2 | Five-tier ladder | **Absent** | No tier concept anywhere in `src/` |
| 3 | Tier never a source type | **Satisfied vacuously** | No tiers to leak into signatures |
| 4 | Tier = ⟨site × ownership context⟩ | **Absent** | Every function is compiled once; no context notion in `ir.psm` |
| 5 | Compiler owns layout; handles | **Absent, deepest gap** | `ir_struct_field_ptr` emits `LLVMBuildStructGEP2` on a raw `ptr`; `src/bridge.psm` has ~104 externs passing pointers |
| 6 | Budget rule, ≈80/20 | **Absent** | No layout optimizer, no budget concept |
| 7 | Four annotations | **Absent** | None of `unique`/`region`/`workload`/`pin` in `src/keywords.psm` |
| 8 | Tier manifest | **Absent** | No emission path |
| 9 | Two-speed compilation | **Satisfied vacuously** | There is exactly one speed and it runs zero inference — which is the `debug` level of SPEC §7.2 |
| 10 | Value semantics, isolation concurrency | **Neither** | §2.2 below; no tasks exist |
| 11 | Deterministic RAII on T0–T2 | **Absent** | `drop(x)` is explicit ([sema.psm:629](../../../self/src/sema.psm:629)); no scope-exit drop |
| 12 | Pipeline determinism | **Satisfied vacuously** | Single-threaded, no search, no budget |

Three of the twelve are satisfied only because the feature they constrain does not exist yet.
That is worth naming: items 3, 9 and 12 will need real work the moment items 2, 6 and 8 land.

### 2.1 The invariant needs a boundary the spec does not currently draw

SPEC §1 says inference failure never fails compilation. The compiler today **does** fail
compilation on ownership violations — use-after-move, use-after-drop, drop-of-borrowed
([sema.psm:364–379](../../../self/src/sema.psm:364), 16 negative tests enforce it).

These are not in conflict, but the spec does not say so, and someone implementing it will
eventually delete a correct error in the name of the invariant. The distinction:

> **Move/borrow violations are semantic errors and SHALL remain compilation errors. The invariant
> governs *tier inference* only: failure to prove a value cheap SHALL NOT fail compilation.**

Two different failures. `use of moved value` is a program bug; `could not prove this unique` is an
analysis budget outcome. Added to the spec as a clarification — see §6 of this document.

### 2.2 Structs are affine references, not values

SPEC §11 item 10 requires value semantics, on the grounds that aliasing then becomes
unrepresentable and most of AIF's safety is true by construction.

What the compiler actually does: `STRUCT_LITERAL_EXPR` heap-allocates and yields a pointer
([ir.psm:284](../../../self/src/ir.psm:284)); `let a = b` copies that pointer; `type_is_move_only`
returns true for `TypeKind.STRUCT` only ([types.psm:92](../../../self/src/types.psm:92)), so the move
checker prevents the second use.

That is an **affine reference** discipline — Rust's model, roughly — not value semantics. It is
perfectly sound. But AIF's aliasing module (INFERENCE §4.2) is written assuming that creating a
second owning reference is a syntactically identifiable event, which is *true here* precisely
because of move checking. So the good news is that the premise survives; the bad news is that it
survives for a different reason than the spec claims, and the spec's justification ("aliasing is
unrepresentable") is not what is happening.

Either fix the spec's justification or actually implement value semantics. Recommend fixing the
justification: affine references give the same analysis guarantee at a fraction of the cost, and
`unique`'s completeness argument (INFERENCE §8.2) rests on move checking, not on value semantics.

---

## 3 · The seam, precisely

`HANDOFF.md`: *"Changing the model is therefore a change to those two policy hooks, not to
codegen."*

Here is `ir_alloc_object` ([llvm-api-backend.c:622](../../../self/runtime/llvm-api-backend.c:622)),
compressed:

```c
int ir_alloc_object(const char *struct_name) {
    LLVMValueRef size = LLVMSizeOf(named_struct(struct_name));      // narrowed to target width
    LLVMTypeRef  alloc_ty = LLVMFunctionType(ptr, &size_ty, 1, 0);  // fn(size) -> ptr
    LLVMValueRef alloc_fn = LLVMGetNamedFunction(g_module, g_alloc_fn)
                         ?: LLVMAddFunction(g_module, g_alloc_fn, alloc_ty);
    return intern_value(LLVMBuildCall2(g_builder, alloc_ty, alloc_fn, &size, 1, ""));
}
```

The policy surface is exactly one thing: **the name of a `fn(size) -> ptr`.**

| Tier | Expressible through the seam as it stands? |
|---|---|
| **T0** stack | **No.** Needs `LLVMBuildAlloca` in the entry block — an instruction, not a call. Different code path, and it must hoist to entry to avoid growing the frame in a loop. |
| **T1** region | **No.** Needs `fn(arena, size) -> ptr`. A second argument means a different function type, and the arena handle must be *threaded* — the region in scope has to reach the allocation site, which is frontend plumbing that does not exist. |
| **T2** unique | **Yes.** Name swap to a size-class allocator; free at the RAII point — but the RAII point does not exist (§4.2). |
| **T3/T4** RC | **Partly.** Name swap gets the allocation. The header word changes struct layout, which `named_struct` and every `ir_struct_field_ptr` index would have to account for. |

So the seam is real but narrow. **It covers the tiers that pay a runtime tax and not the two tiers
that don't** — which is inverted relative to where the model's value is.

Concretely, the seam needs to become three hooks, not one:

```
ir_alloc_stack (struct_name)                 -> alloca, hoisted to entry
ir_alloc_region(struct_name, arena_value)    -> bump, from a threaded handle
ir_alloc_heap  (struct_name)                 -> the current path
```

and the frontend must decide which to call, which means the frontend must know the tier, which
means inference must run before `generate_expression`. Today `ir.psm` walks the AST and emits
immediately; there is no pass between sema and codegen. **Adding one is the first structural
change AIF requires**, and it is independent of every other item here.

### 3.1 What isn't behind the seam at all

`ir_alloc_object` is called from exactly one place — `STRUCT_LITERAL_EXPR`. Strings, arrays and
lists never touch it. They allocate inside `runtime/lang_runtime.c` through its own `malloc`
wrappers and are **never freed**. (Still true of the *allocation*: Level 4 gave them a release path
and an arena, but both reach the runtime's own allocator rather than going through this seam. That
asymmetry is why `--verify` has to swap the runtime as well as the emitted names.)

So even a complete tier implementation for structs leaves the majority of a real program's
allocation traffic outside the model. Fixing that means making `String`, arrays and `List<T>`
move-only — which `types.psm:88`'s own comment defers ("*String/Array become move-only once
borrows land; for now they stay copyable to avoid churn*").

**This is the prerequisite with the widest blast radius in the whole compiler**, because every
string-handling function in `lexer.psm`, `parser.psm`, `sema.psm` and `ir.psm` currently assumes
strings are freely copyable.

> **Landed 2026-08-07, and the blast radius was nine errors.** Parameters borrow by default and a
> field read is not a move, so most of what looked like copying never was. See the Level 4 note in
> §5. Arrays stayed copyable: they are frame storage, so there is nothing to own.

---

## 4 · Prerequisites nobody has costed

### 4.1 A pass between sema and codegen

There isn't one. `ir.psm` (1399 lines) walks the AST emitting backend calls inline. AIF needs:

```
sema  →  [ fact graph build → inference → tier assignment → manifest ]  →  ir
```

The middle stage needs a representation to hang facts on. The AST is flat and pointer-punned
([ast.psm](../../../self/src/ast.psm), 113 lines) with `s1`/`s2`/`child1`/`next` fields — usable as a
node identity, but there is no side-table facility and no stable node numbering.

Smallest viable version: give every AST node an integer id at parse time, and keep facts in a
side array indexed by it. That is a small change and it unblocks everything else.

### 4.2 Scope-based drop

Frozen item 11 requires RAII on T0–T2. Today `drop(x)` is a call the programmer writes
([sema.psm:629](../../../self/src/sema.psm:629)).

Scope-exit drop needs drops emitted at *every* exit from a scope: fallthrough, `return`, `break`,
`continue`, and every early return in a nested block. `ir.psm` has the block structure to do it,
but there is no drop-list per scope and no unwinding concept.

Note the ordering constraint this creates: drops must run in reverse construction order, which
means the tier assignment must be known before codegen (§4.1 again).

### 4.3 Prismio cannot express its own solver

This is the finding that most changes the schedule.

INFERENCE §5.2 needs: a graph with dynamic node insertion, a per-node record of four lattice
values, a worklist, a map from context tuples to instantiated bodies, and hashing over tuples.

Prismio today has: structs, enums, fixed arrays, a hardcoded `List<T>`
([types.psm:111](../../../self/src/types.psm:111)), function overloading, and no generics, no methods,
no closures, and no hash maps. There is no `Option`/`Result` — failure is signalled by sentinel
return values (`HANDOFF.md` known gaps).

You can write a fixed-point solver with parallel arrays and integer indices. The existing compiler
is written exactly that way and it works. But it is a materially larger and more error-prone job
than the same code in a language with generic containers, and the engine is the piece where a
silent bug produces a wrong-tier binary rather than a crash.

**Recommendation:** land generic containers (at minimum a generic `Map<K,V>` and a growable
`Vec<T>`) *before* the inference engine, not after. It is the cheaper order, and `List<T>`'s
hardcoded special case is already the shape of the work.

### 4.4 Compile time

`HANDOFF.md` records compile time as superlinear in module size — ~290 ms for the 155 KB compiler,
~500 ms for a 105 KB single module, with sema still scanning the module per identifier for
function lookup.

AIF adds whole-program fixed-point iteration over a graph with one node per abstract value per
context. Fixing the existing superlinearity (the name→declaration map `HANDOFF.md` proposes) should
come first, or the inference cost will be impossible to attribute.

---

## 5 · A staged path

Each level is independently useful, independently testable, and does not require the next. Levels
0–2 fit the language as it exists. Level 3 onward needs the prerequisites in §4.

### Level 0 — facts, no behaviour change — **DONE, 2026-08-05**

Build the fact graph, run the escape and aliasing modules, assign tiers, **emit the manifest, and
change no codegen.** Everything still `malloc`s.

- Deliverable: a tier manifest for the compiler's own source.
- Value: the whole engine becomes testable and the tier distribution becomes measurable **before
  any risk to the self-host**. If the distribution is bad, the model is falsified cheaply.
- Prerequisite: §4.1 only.
- This is the right first step and it is much smaller than it sounds.

**It was.** `self/src/aif.psm` + `self/runtime/aif_support.c`, driven by `prismio aif`. Two notes
for whoever does Level 1:

- §4.3's recommendation to land generic containers first was **not** taken, and the reason is worth
  recording. The containers went into C, which is where `ir_symbols.c` already keeps the symbol
  tables, so the engine is ordinary Prismio over an FFI surface rather than parallel arrays and
  integer indices. The risk §4.3 names — a silent bug in the one component where that yields a
  wrong-tier binary — is answered instead by `tools/aif_differential.py`, which holds the engine
  against `aif/prototype/aif.py` on every corpus under both collection settings. Generic containers
  are still worth having; they are no longer on this critical path.
- §4.1's proposed AST node ids were not needed either. Sites are identified by the walk that creates
  them. Level 1 does need a key codegen can look a tier up by — see the note under Level 1.

And it did what this section said it would: the distribution was measurable cheaply, and it
immediately contradicted a recorded result. See the correction note atop
[RESULTS-L0.md](../evidence/RESULTS-L0-tiers.md).

### Level 1 — T0 — **DONE, 2026-08-05**

Stack-promote non-escaping structs. Escape module only; `ir_alloc_stack` hoisting to the entry
block.

- Risk: struct literals reachable from a `return`. The escape module must be right or the compiler
  miscompiles itself — which the fixpoint test will catch loudly.
- Measurable: allocation count on a self-compile should drop.

**Both of those predictions were wrong, and the way they were wrong is the useful part.**

- **The fixpoint test catches nothing here.** The compiler's own source has *zero* T0 sites, so a
  self-compile never emits a single `alloca` from this path and the fixpoint check is green whatever
  the escape module says. The safety net this section assumes does not exist for Level 1. What
  replaced it is `tests/test_42_aif_stack_promotion.psm`, which exercises the path directly, plus
  the oracle in `tools/aif_differential.py`.
- **Allocation count on a self-compile does not drop.** It is unchanged, for the same reason.
- The T0 population across the entire corpus is **two sites**. The suspicion was that `Θ_stack` was
  the binding constraint — the prototype approximates it with a field count of 8, which excludes
  ASTNode at 14 fields. Level 1 replaced that with a real byte threshold (256 B, computed from
  field types, since AIF-1's layout *is* declaration order) and the population **did not move**.
  Aliasing is the constraint, not size. The byte threshold is still the correct rule and is what a
  wide struct needs; it is not what was holding T0 back.

Two defects Level 1 surfaced, both of which were latent at Level 0 because nothing allocated
differently:

- **The escape module was unsound for assignment to an outer-scope binding.** `live_in` used the
  scope of the *assignment* rather than the scope the variable was *declared* in, so a value created
  in a loop body and assigned to a binding declared outside it kept the loop body's escape — which
  reads as "dies at the end of this iteration" and is false. At Level 0 that cost a tier and nothing
  else. At Level 1 a hoisted `alloca` gives every iteration the same slot, so it is a miscompile.
  Fixed in both implementations (`aif_var_scope`); the probe is in the git history of this change.
- **`drop(x)` lowers to a free, and a stack slot cannot be freed.** A promoted value passed to
  `drop` freed a stack pointer — heap corruption, caught by `test_24_drop`. T0 is now suppressed for
  any value an explicit `drop` names. That is a codegen constraint rather than a fact and is
  implemented as one, so the manifest does not claim the value escaped.

The seam is now two hooks of the three §3 says it needs: `ir_alloc_stack` and `ir_alloc_object`.
`ir_alloc_region` still does not exist.

**Postscript, 2026-08-06 — the tier lookup is keyed by AST node now.** It was keyed by
`file:line:col`, on the reasoning that a struct literal sits at exactly one position and that key
needed no AST change. It is not one position: an array literal and its first element start at the
same column, so `[Nested { v: 5 }]` put a T1 and a T0 site on the same key. A position key has to
resolve that by taking the *higher* tier, because codegen reads T0 as permission to use a stack
slot and rounding down there is heap corruption — so the collision was silently costing the
promotion. §4.1 was right that node identity is the answer; it does not need a numbering or a
parser change, because both passes walk the same tree in the same process and the node's address
already names it. `tests/test_42`'s `nested_in_array` is the case, and `run_aif_stack_slot_test`
asserts the `alloca` in the IR — the value test alone passes just as well with promotion off.

### Analysis quality — three recorded gaps closed, 2026-08-06

Not a level. Three approximations that Level 0 shipped with a comment rather than a fix, all of
which had to be fixed in both implementations at once to keep the oracle meaningful.

- **`List<T>` and `[T]` fields produced no type-graph edge.** The walk read the annotation's own
  name, which is `List` or empty; the element type hangs off `child1`. So `children: List<Node>`
  reported the whole module acyclic. This is the one direction in which the analysis was unsound
  rather than imprecise — a T3 refcount on a genuine cycle leaks — and the fixture for it is
  `Tree` in `tests/aif_tiers.psm`, which moves T3 → T4b once the edge exists.
  The oracle carried *dead code* for this: it parsed `List<...>` out of the field type string, and
  the dump never contains that spelling. Both implementations missed the edges, for different
  reasons, which is exactly how a differential test agrees on a wrong answer.
- **Array-literal elements produced no sites.** `[str_concat(a,b), …]` allocated twice and reported
  neither. Elements now store into the array under one shared element key, the same shape the
  struct-literal case uses for fields. Neither the compiler nor the corpus contains such a nesting,
  so `tier_array_elements` is the only coverage.
- **`widen_and_close` raised the whole graph** (INFERENCE §5.3 asks for the unresolved subgraph and
  its successors). Now it raises `Δ ∪ transitive_succs(Δ)`, over the owner → value edges of `store`
  and `retain_in` — the only two rules that carry a fact from one site to another.

That last one needed two supporting changes, and both are worth more than the narrowing itself:

- **The truncation path was unreachable, and an unreachable path is where a bug lives undisturbed.**
  `--budget=N` makes it reachable. `run_aif_widening_test` then checks the property that actually
  matters — for every site, every source, and every budget from 1 to convergence, the truncated tier
  is at or above the converged one. Disabling `aif_widen` fails it with
  `tier_four_cyclic is T0 truncated but T4b converged`, which is §5.3's use-after-free exactly.
- **Points-to is now solved to a fixed point before the facts.** No rule writing `pt` or `holders`
  reads a fact, so its least fixed point is independent and reaching it first changes no answer.
  What it changes is the frontier: solved together the two converge together, so a budget that bites
  always finds points-to still growing — and a set that may still gain members this pass cannot name
  makes every site a possible successor. Separated, the fact phase always truncates over a final
  graph. The manifest reports the split (`rounds 10 (points-to 8)`).

**Measured:** on the corpus the frontier is a proper subset — `g3_scene_graph` widens 2 of 4 sites
at budget 6, `g4_ecs_world` 5 of 11 at budget 5. On the compiler's own source it is not: the fact
phase there is two rounds, so there is no late truncation point to have. Records are marked
`budget-exhausted` individually now rather than wholesale, which is what makes a raised budget an
informed decision rather than a guess.

### Level 2 — T2 and scope drop — **DONE, 2026-08-06**

Deterministic destruction at scope exit for uniquely owned structs. Needs §4.2.

- This is where the compiler stops leaking structs.
- Biggest correctness risk in the whole plan: a missed drop path leaks, a doubled one crashes.
  Both are caught by the existing 56-test suite plus a leak check under a debug allocator.

**It is not where the compiler stops leaking structs, and the suite would not have caught it.**
Measured before writing any of it: the compiler has five struct sites and every one is **T2**, and
there is not a single **T1** struct in the compiler or in any of the seven corpus programs. A struct
small enough for a stack slot takes the T0 clause first, and one that escapes takes T2, so T1 —
the only tier a scope-exit free applies to — is left with structs that exceed Θ_stack and stay
local, which none of these programs has. The 184 T1 sites in the compiler are strings, and the
language does not own strings. So the self-host exercises this path zero times, exactly as at
Level 1, and `tests/test_43_aif_scope_drop.psm` is again the whole safety net.

Built anyway, because Levels 3 and 4 both need the mechanism and it is the cheaper half of them.
What it does:

- Drops at all four exits — fall-through, `return`, `break`, `continue` — in reverse construction
  order, which is what §4.2 asks for.
- No new structure: the binding table is already flat with a watermark per scope, so "what dies
  when this scope exits" is the droppable bindings above that watermark. A `return` reads the same
  list with floor 0 and `break`/`continue` with the loop's watermark.
- The predicate is `aif_frees_at_scope_node`, not the tier. T1 means "some region", which may be an
  *enclosing* scope if the value was also bound further out; freeing at the inner exit would be a
  use-after-free rather than a leak. What it tests is `E == defscope`, the same conjunct the T0
  clause opens with.

Three things this surfaced, all of which would have been silent:

- **The escape fact is not sufficient on its own — the language has to agree.** The first build
  freed every region-scoped value, which includes strings, and four tests died with
  `0xC0000374`. RAII needs a single owner, and today only structs are move-only. The predicate now
  also asks `site_is_move_only`, which is the same switch `--owned-collections` flips — so this
  widens by itself when affine collections land, and that is what makes Level 4, not Level 2, the
  point where the leaking stops.
- **Move state belongs to sema and is gone by codegen.** `ir_mark_moved` is called only from
  `sema.psm`, which clears it per function, so a `ir_is_moved` check in codegen reads an answer
  about some other function — and `drop(x)` followed by a scope drop was a double free. There is no
  move test in the drop path now: moving a value outward raises its escape past the scope, and an
  explicit `drop` already marks the site (the flag that bars T0, for the same reason).
- **The loop barrier codegen wanted did not exist.** `ir_loop_barrier_push` is sema's, so
  `break`/`continue` would have read a watermark of 0 and dropped the entire function — freeing
  outer bindings that the fall-through path then frees again. Codegen has its own stack now.

Coverage is `tests/test_43` for the values plus `run_aif_drop_emission_test` for the static free
counts per function, because a build that emitted no drops at all passes every value test.

### `verify` mode — **DONE, 2026-08-06**

SPEC §7.3, and the answer to the safety-net problem Levels 1 and 2 both hit. `prismio build <src>
--verify` swaps the allocator and deallocator names through the §3 seam and changes nothing else,
so codegen is byte-identical to a release build; the shims in `runtime/lang_runtime.c` check that
every object is released exactly once and poison it on the way out.

Two of SPEC §7.3's rows are covered — the T0/T1 "no access after exit" row, partially, by poisoning
rather than by instrumenting reads; and the balance itself, which the table omits and which is what
catches a missed or doubled drop path. The rest each need machinery that does not exist: `A` needs
a count word in the object header (the same layout change T3 needs), `E = Region(r)` needs arenas,
`E ⊑ Caller` needs static-root reachability, `T` is vacuous, and `C` needs a periodic heap walk.
The shim's header comment carries that table.

**It found a defect on its first run, in code this audit had already blessed.** §3 says the seam is
"exactly one thing: the name of a `fn(size) -> ptr`", and `HANDOFF.md` recorded `ir_alloc_object`
and `ir_free_object` as the only two places codegen allocates or releases. `drop(x)` was not going
through either — it emitted a call to `free` by name. Under `verify` that showed up as a leak the
accounting could not explain; at Level 3 it would have handed an arena pointer to libc `free`. The
lesson is the one §7.3 states: the bug was invisible to every existing test, because calling the
right deallocator by the wrong route is only wrong once the deallocator changes.

### Level 3 — T1 and `region` — **DONE, 2026-08-06**

Arena runtime, `region` keyword through lexer/parser/sema, the arena handle threaded to
allocation sites, `ir_alloc_region`.

**The handle is not threaded, and that is the one design choice here worth arguing about.** §3
predicted `fn(arena, size) -> ptr` with the region in scope reaching each allocation site — "frontend
plumbing that does not exist". The arenas are a runtime stack instead: `region r { … }` pushes on
entry and pops on every exit, and `arena_alloc` bumps from the top. That keeps `ir_alloc_region` a
`fn(size) -> ptr` like the other two hooks and needs no plumbing at all.

What it costs is exactly one case, and the fixture pins it:

```prismio
region outer { let mut held = Wide{…}; region inner { held = Wide{…} } use(held) }
```

The inner literal's escape is *outer*'s scope. It cannot come from `inner`'s arena, which is gone by
`use(held)` — and with a dynamically scoped stack there is no way to name `outer`'s arena from
inside `inner`, so it falls back to the heap. `aif_arena_at_node` declines it by testing
`lca(E, r) == r` rather than mere lexical containment, which is what keeps that a leak instead of a
use-after-free. A threaded handle would place it in `outer` and is the reason to want one.

Two smaller notes:

- **The seed did not need to carry the keyword**, contrary to the prediction above that this is the
  first level to touch it: `src/` does not use `region`, so the old seed still parsed the tree. The
  seed *did* need refreshing, but for an unrelated reason — the node-keyed tier lookup renamed
  `aif_tier_at`, and the committed seed's IR still called it, so a cold start failed to link. That
  had been broken for three changes and nothing caught it, because bootstrapping from a warm binary
  never exercises the seed. **Run a cold start after any change to the runtime's FFI surface**, not
  only after a language change.
- `placement` now names the region (`region:work`), which is what SPEC §6.2's example shows and what
  makes an arena traceable to the block that owns it.

Coverage is `tests/test_44_aif_region.psm`, which asserts `arena_objects()` and `arena_regions()`
rather than inspecting IR — an arena pointer and a malloc pointer are indistinguishable from the
value, so counting what the arena actually served is the only honest check. It is also in
`tools/aif_differential.py`'s default source list, since no corpus program opens a region and a
region opens a scope.

- The first level where the performance claim is actually testable.
- Also the first level that needs a new keyword, so it is the first that touches the seed and the
  bootstrap.

### Level 4 — strings and lists become move-only — **DONE, 2026-08-07**

The wide-blast-radius change of §3.1. Deliberately after Level 3 so that regions already exist to
absorb them — most string traffic in the compiler is region-shaped.

**The blast radius was nine errors.** §3.1 called this "the prerequisite with the widest blast radius
in the whole compiler", on the grounds that every string-handling function in `lexer.psm`,
`parser.psm`, `sema.psm` and `ir.psm` assumes strings are freely copyable. Flipping
`type_is_move_only` produced 25 errors, and 16 of them were one missing rule rather than sixteen
places that had to change:

- **A `let` whose initialiser is a field read, an index, or an already-borrowed name is a reborrow,
  not a move** (`sema_binding_is_borrow`). Reading `node.child1` yields a reference the AST still
  owns; naming a borrowed parameter yields another borrow. Neither is an ownership transfer, and
  the compiler's commonest idiom — `let mut p = node.child1`, walking a chain of pointers punned as
  strings — is nothing but those two.
- It is sound rather than merely quiet, and for a structural reason: a borrowed binding's
  initialiser registers no allocation site, so `aif_frees_at_scope_node` cannot admit it. The
  language can be permissive here precisely because the *drop* is keyed on allocation, not on the
  binding's declared ownership.
- Consuming a borrow is still an error. `drop(x)` and `sink` parameters go through
  `sema_consume_operand`, which is what `sema_move_operand` used to be; `neg_05` still passes.

The nine that remained were real double-uses of an owned string and were fixed at the site. Two are
worth naming because they are the shape the rest will take: `lex_all_tokens` held the token list head
in a second pointer binding, and `aif_sites_of` bound `ty` into a branch-local name that poisoned it
for every other branch — move state is per name over the whole body, so a move in one arm reports at
a use in another.

**Arrays are deliberately not affine.** They lower to `ir_array_alloca` — frame storage — so there is
nothing to own, nothing for a drop to reclaim, and `drop(arr)` would hand a stack pointer to the
deallocator (`neg_18`). This is the one place the language and `site_is_move_only` disagree: the
solver keeps SPEC's reading, so the oracle still agrees with it, and `aif_frees_at_scope_node`
declines arrays by kind next to the T0 clause it already had.

**"With no further codegen change" was wrong**, and it is the prediction from `HANDOFF.md` worth
correcting. The claim was that the arena serves any T1 site, so T1 strings become arena-placed for
free. `aif_arena_at_node` does ignore the kind — but codegen only *asks* it at `STRUCT_LITERAL_EXPR`,
because that is the only place `ir_alloc_region` can be called. A string is allocated by `str_concat`
inside `lang_runtime.c`, which cannot know where it was called from. So the call site says instead:
codegen brackets a producing runtime call whose value the arena accepted with
`rt_arena_hint_push`/`pop`, and `rt_alloc` bumps rather than calling `malloc`.

The gate is `aif_arena_at_node` alone, and it is sufficient rather than convenient. A site exists on
a call node only when the callee is opaque to this compilation; an `alias` return registers none and
an undeclared one is raised to `Caller`, which the arena test rejects. So the bracket fires exactly
on FFI `produce` calls inside a region whose result cannot outlive it. It wraps the call only —
arguments are evaluated before it — so a nested allocation the analysis declined does not inherit
the hint. `test_44`'s `arena_objects()` count went 207 → 209 for the two strings in `strings_inside`,
and `string_escapes` contributes none, which is the case that has to be declined.

**`verify` needed a second half.** SPEC §7.3's swap names the allocator and deallocator codegen
emits, which covers everything `ir_alloc_object` handed out — and strings and lists are allocated
past that seam, in the runtime. Their release would then be a pointer the accounting never saw, i.e.
a *violation* on every string a program drops. A verify build now compiles `lang_runtime.c` with
`-DPRISMIO_AIF_VERIFY`, pointing its own allocator at the same shims. Both ends of every pairing swap
together, the accounting balances (`test_45`: 418 allocated, 416 released, 0 violations), and the
property worth having survives — the *generated code* is still byte-identical either way, because
the swap happens when the runtime is compiled and not when the program is generated.

**Two functions returned a string literal.** `str_substring` out of range and `str_trim` of
all-whitespace both returned `""`. That was invisible while nothing freed a string and is a `free` of
a `.rodata` pointer the moment one does. Both allocate a one-byte empty string now, and the
invariant is worth stating: *anything declared to return `String` returns something a release can
take*. Found by reading the C, not by a test — the same lesson as the FFI contracts.

**A list needed its own deallocator.** A `XefyList` is a handle plus an element block, so the seam's
`fn(ptr) -> void` leaks the block. `ir_free_list` routes to `list_release`, which frees both through
the allocator the list came from. The storage type cannot tell you which to call — a String and a
List are both `ptr` — so `ir_mark_droppable` carries a kind. `list_push` also leaked the old element
block on every regrow; it does not now.

**The drop frees the slot, not the initialiser.** Level 2 marks a binding droppable because its
initialiser allocated something the scope owns, and then frees whatever the slot holds at the exit.
An assignment can put something else there:

```prismio
let mut s = str_concat(a, b)   // droppable
s = node.name                   // now a string the AST owns
```

The exit then frees a live value. This was latent from Level 2 — the same shape works for structs —
and Level 4 made it reachable everywhere, because strings are reassigned constantly and a field read
is a borrow. Codegen asks `node_assigns_name` over the enclosing function body before marking, and
declines any binding that is ever an assignment target.

The question has to be asked at the *declaration*. Codegen is a single forward walk, and run-time
order is not source order: a `break` written above the assignment still runs after it on the second
iteration, and its drops were emitted when the binding still looked droppable. The rule is blunt on
purpose — a binding reassigned only from owned allocations is refused too — and that costs nothing,
because reassignment already leaks the previous value either way.

`test_45`'s `reassigned_from_borrow` pins it, and the detector is the leak count rather than a
violation: freeing a value that *is* live is a perfectly legal release as far as the accounting goes.
The regression shows up as one fewer leak.

**What it measured.** The compiler's own distribution goes from **66% to 87% T0–T2**, clearing
BENCHMARKS H1's 70% bar on this corpus for the first time without a hypothetical. The T3 residue
falls from 102 sites to 37 — exactly the undeclared extern returns, which is the number FFI work
moves and this level cannot.

**What still leaks, and why it is not a bug.** The compiler emits 11 frees against 186 T1 string
sites. Droppability is a property of a *binding*, and most of those sites are temporaries —
`str_concat(...)` written directly as an argument, never named. Freeing one at the end of its
statement is not expressible with today's facts: `E == scope` says the value dies with the scope, not
with the statement, and `list_push(l, str_concat(a, b))` has a temporary whose escape is the list's.
Distinguishing the two needs a fact the model does not have. Binding the temporary is the workaround
and `test_45`'s `per_iteration` shows it.

One more imprecision the fixture pins: passing an owned string to a function that binds it to a local
name raises its escape to `Caller`, because E-BIND cannot name a scope inside a callee. Sound,
conservative, and the reason `test_45` leaks two rather than one.

### Automatic arena placement — **DONE, 2026-08-07**

LAYOUT §7.1. Every scope is already an implicit region (SPEC §4.1), so the question was never which
scopes *could* have an arena but which are worth the setup:

```
ArenaBenefit(s) = allocs_in(s)·(α_T2 − α_T1) − entries(s)·arenaSetupCost
```

Both inputs are supposed to come from an access profile. There is no profiler, so both are estimated
statically and the estimate is stated rather than hidden — and one of them turns out not to matter:

- **`entries(s)` factors out.** Written as "allocations per entry of `s`", `allocs_in` carries the
  same multiplier, so the *sign* of the benefit — the only thing the decision reads — is independent
  of how often the scope runs. That removes the need for any loop-trip estimate above `s`, which is
  the estimate most likely to be wrong.
- `allocs_in(s)` weights each served site by `AIF_LOOP_ITERS` per loop between it and `s`.

**Placement is greedy innermost-first, and that removes the nesting heuristic entirely.** LAYOUT says
an inner arena is worth it "only when the inner scope's values die materially earlier" — but a site
can only be served by an arena its escape bottoms at or below, so an inner arena takes exactly those
values by construction. Whatever it cannot take, the next scope out sees.

**`region` is a pin on the decision, and the pin has to bite.** Inside a `region`, the region decides:
automatic placement fills scopes with no enclosing region and never undercuts one. Without that,
`test_44`'s loop-body arena inside `region batch` would have taken all 200 objects and `batch` would
have served nothing — a manifest that can no longer say which block owns a value. A programmer who
wants per-iteration reclamation writes a nested `region`, which the same fixture does.

**The chunk pool is what makes the cost constant real.** LAYOUT §4's `arenaSetupCost` of ~40 cycles
assumes entering a region is cheap. It was not: `arena_pop` returned every chunk to libc, so a region
serving one allocation paid a malloc and a free — 180 cycles, more than the 87 an arena saves — and
the model would have had to decline every small scope. Chunks are pooled now and entering a region is
a depth increment and a pointer swap.

Three things it surfaced, all of which would have been silent:

- **An explicitly dropped value must not be arena-placed.** `drop(x)` emits a deallocator call and an
  arena pointer is not something a deallocator can take. Latent while arenas only appeared where a
  `region` was written; automatic placement puts one around almost every explicit drop. Same
  `no_stack` flag that bars T0, for the same reason.
- **A list cannot live in an arena.** `list_push` reallocates the element block long after the
  allocation site returned, at whatever arena depth the program is at then — so the block would be
  tied to a region the list can outlive, and freeing the old block would hand arena memory to the
  deallocator. Lists stay on the heap, which is also what keeps Level 2's drop path exercised.
- **`verify` could stop reporting entirely.** With arenas everywhere a program can run to completion
  without one call through the seam, and arming the report on the first allocation then prints
  nothing — which reads as "the seam was not redirected". Armed on the first region entry too.

**What it measured.** In the compiler: 105 arenas placed, **all 186 T1 string sites arena-served**,
and individual frees down from 11 to 0 — every one of them is now reclaimed with its block instead.
That closes the temporaries leak class the Level 4 note called the level's remaining residue: a
temporary has no owner and so no free point, but it does have a scope, and the arena reclaims by
scope. `test_45`'s allocation count fell from **420 to 7**.

Peak RSS on the compiler moved 28.0 → 27.3 MB and compile time not at all, which is what
finding 9 predicted: a program that leaks by design and exits is already a one-region program.
**The corpus gains nothing at all, and that is the more interesting number** — `g2_frame_loop` has
zero T1 sites (1 T0, 4 T2), so there is nothing for an arena to serve. Its 61 362 leaked allocations
are T2 values stored into containers that outlive the frame. Arenas pay where T1 lives, and T1 lives
in string-processing code, not in the struct-and-container corpus. Pick benchmarks accordingly.

### The four annotations — **`unique` and `pin` DONE, 2026-08-07**

SPEC §5. `region` landed at Level 3; `workload` is not implemented and should not be until there is a
layout optimiser to consume it — SPEC §5.3 leaves its syntax open, so building it now would be
inventing specification for a component that does not exist.

**Both are contextual, not reserved.** SPEC §5 requires that deleting every annotation leave a working
program; reserving two more words would break programs that already use them as names, which is the
same obligation pointing the other way. `unique` is an annotation only when another identifier
follows it, `pin` only when a `(` does — so `let unique = 5` is still a variable called `unique`, and
`test_46` pins that.

- **`unique` is the axiom, and the language is what makes it sound.** SPEC §5.1 asks for local
  verification that no second owning reference is created in the declaring scope. Under affine
  collections that is *already a compile error*: taking a second owner is a move, and using the
  original afterwards is `use of moved value`. So the move checker discharges the local half and the
  axiom does the interprocedural half — which is exactly the division §5.0 argues an axiom is for.
- **SPEC §5.4's middle branch is vacuous here, and that is worth knowing rather than silently
  skipping.** The pseudocode has a case for "the facts permit the pinned tier but the solver did not
  reach it". `derived_tier` returns the cheapest tier its clauses admit and the clauses read the
  facts directly; there is no search that could settle above its own optimum. An implementation whose
  tier assignment was a separate optimisation would need that branch. This one cannot enter it, so a
  pin below the derived tier is refuted rather than rescued.
- A refuted pin is the **one thing AIF reports** (SPEC §5.4.1, `neg_20`), and it does not weaken the
  invariant: §1 governs inference failure, and a false assertion about one's own program is the other
  thing.

### Minimal cause and ranked repairs — **DONE, 2026-08-07**

SPEC §6.3 and INFERENCE §5.6. `prismio aif <src> --why=<symbol>` prints the witness path for one
manifest record and the repairs that would undo it; `tools/aif_manifest_diff.py --compiler <exe>`
prints one under every regression it gates on.

**The derivation is kept as one edge per site per domain, not as the full DAG.** 5.6 specifies a
backward BFS through maximal contributors. Recording the rule that *first raises a fact to the value
it ends at* is a maximal contributor by construction — a rule that raises is one that set the value,
as opposed to one that merely did not contradict it — so walking those edges backward is a chain
rather than a search. Memory is O(sites) instead of O(edges).

Two honest consequences, both recorded at the site: the path is *a* witness rather than provably the
*shortest* one, and INFERENCE §5.1 lets constraint order vary, so "shortest" was never stable anyway.

Two details that are easy to get wrong and were:

- **Which domain explains a record is the reverse of the clause order.** A site is asked about
  because its tier is worse than someone wanted, so the interesting fact is the *last* one that was
  binding. Aliasing is checked before escape: a T3 record whose E is also Caller would otherwise be
  explained by the escape that only got it as far as T2 — a confident answer to the wrong question.
- **Repairs rank outermost-first.** The root cause is the cheapest thing to change, because
  everything downstream of it follows.

The output is worth reading once, because it derives an answer this project already reached by hand:
asked why a compiler string is T3 without affine collections, it answers `A-COPY` and ranks *"make
the type move-only so a second holder is a move"* first. That is Level 4.

### Ownership inside containers — **DONE, 2026-08-07**

Not a level. The item `HANDOFF.md` ranked third and the one that moved the corpus:
`g2_frame_loop` leaked 61 362 allocations, automatic arenas changed that by zero, and the residue
was values stored into containers that outlive the frame.

**It had to come before Level 5, and the reason is structural rather than a matter of taste.** A T3
value's escape is Caller or Global by the tier's own definition — anything lower is T1 — and
`aif_frees_at_scope_node` opens with `E == scope`. So the binding-drop path Level 2 built is
*unreachable* for T3, at every site, in every program. A container or field teardown is the only
release point a T3 value can have, and there was no such thing. Level 5 built first would have been
a refcount nothing ever decremented.

Two halves, and neither pays without the other. The container releases its elements; a binding that
receives a container from a known callee owns it. Without the second nothing tears the container
down, so the first never runs.

- **Level 4's rule was exactly inverted, and its reasoning is why.** `list_release` left elements
  alone, on the grounds that `list_push` is `retain_in(0)` so an element's escape is already the
  list's — "if it is owned anywhere it is owned at its own binding". Nobody owns it there: that
  raised escape is precisely what makes `aif_frees_at_scope_node` decline the binding. The two
  halves of that sentence contradict each other, and the consequence was that every element of every
  list leaked. One owner, and it is the container.
- **The container is told what it owns; it cannot ask.** `elem_own` is stamped by codegen at
  `list_new`. Probing a header in front of an element to find out would be reading memory this
  compilation did not allocate — the same unsound move that bars refcounting an OPAQUE site.
- **A teardown loop makes one call per element, so a mixed container has no answer.** The
  disposition is `NONE` unless every element site agrees, which makes an array element (frame
  storage), an opaque one (never ours) and a T3 one (wants a decrement that does not exist yet) all
  reclaim nothing. A leak rather than a wrong free.
- **Being in a container bars T0**, next to `no_stack` and for the same reason. Reachable whenever
  container and element share a scope, which leaves every other T0 conjunct satisfied — and the
  teardown would then hand a frame slot to the deallocator.

**The aliasing module had a hole exactly the width of a container.** A-COPY exempts move-only values
because a second *binding* is a move, so the earlier one is provably dead. A container is not a
binding and `list_push` is not a move, so that argument never reached it: one value in two lists was
`Borrowed`, which is T2, which is one owner too few. **A-CONTAIN** counts containers and makes it
Shared — which is T3, the tier built for this shape. The decomposition is the satisfying part: zero
containers and `E == scope` is a scope drop, one container is a teardown, two is a refcount.

**And the half A-CONTAIN cannot see, the language now refuses.** Two pushes of one *name* name one
container, so no count moves. `list_push` consumes its operand — the push is an ownership transfer,
so it is move-checked as one — which also recovers the loop case free, because
`ir_binding_predates_loop` already refuses a move that repeats. `neg_21` and `neg_22` pin both
halves. `neg_22` is the one worth reading: pushing a borrowed parameter was harmless until a
container released its elements, and is a use-after-free the moment one does. `sink` is the fix and
the language already had the word.

**`list_get` did not return the element.** Its comment said "an element read back out of a list is
the element rather than a new object", and the implementation returned the argument's value set,
which is *the list*. Reading an element and pushing it into a second container therefore recorded
the container as the element — so A-CONTAIN saw nothing, and the second container was told its
elements were lists when they were structs. `list_release` then called `list_release` on a struct.
Heap corruption, found by the fixture on its first run, in code this document had already described
as working.

A container's contents are a **field key** now (`@elem`), which is what makes that sentence true and
costs no new mechanism — INFERENCE 3.1's field-sensitivity already exists. Object-insensitive
through `aif_base_type`, and that is forced rather than chosen: `list_new()` types as
`List<Invalid>` and an annotated binding does not, so keying on the spelled type would put two
spellings of one container on different keys, and a lost edge is the unsound direction.

**The cliff that buys is worth stating.** One key per container base type means one cross-container
push marks every pushed site in the file as multiply held. `test_47` and `test_48` are two files
rather than one because of it: together, the single push in `test_48` would make all seventeen of
`test_47`'s sites T3 and nothing would be released. Contexts (INFERENCE 6) are what would fix it.

**Ownership transfer across a return is restricted to containers, and the restriction is soundness,
not caution.** A value set records sites, and a string literal is not a site — so for a function
returning `String`, `return "ptr"` contributes nothing and the return set is indistinguishable from
one that always allocates. Freeing that is a free of `.rodata`, which is Level 4's `str_substring`
defect arriving by a different road; the first build of this emitted 44 such frees into the compiler
and the next generation could not compile itself. A `List` has no literal form — `list_new` is the
only way to make one — so its return set is complete. Recovering strings and structs needs the
points-to lattice to carry "may hold something untracked".

It also survives exactly one hop: the returned site must belong to the callee, so `forwards`
returning `build`'s list is declined. That is `test_47`'s entire remaining leak.

**What it measured**, over the corpus under `--verify`, all with **0 violations**:

| | before | after |
|---|---|---|
| `g1_particles` | 2 002 | **0** |
| `g2_frame_loop` | 61 362 | **0** |
| `g3_scene_graph` | 5 462 | 4 095 |
| `g4_ecs_world` | 7 511 | 7 511 |
| `g5_asset_cache` | 2 049 | 47 |
| `g6_game` | 49 613 | 3 213 |
| total | 127 999 | **14 866** |

The compiler's own distribution does not move at all — it has no lists — and that is the fourth
consecutive level where the self-host exercises none of the new path. `test_47`/`test_48` are the
whole safety net, as at Levels 1–4.

**`g4_ecs_world` is unchanged, and it says what comes next.** Its lists are fields of a `World`
struct that is returned and never released. Struct-field ownership is the same problem with the same
answer, and it needs a per-type descriptor rather than a per-object word — a struct's fields are
known statically, so the release is a generated function per type rather than a stamped mode.

**Found in passing: `parser_expect_close_angle` never worked.** It splits `>>` into two `>` so
`List<List<T>>` parses, rewriting the token's text — and not its type, which the lexer had set to
arithmetic. The enclosing argument then failed with `expected `>`, found `>``. Written with a
correct comment and never exercised, because the thing it enables was unwritable and so nobody had
written one. The same lesson as `--budget`: an unreachable path is where a bug lives undisturbed.

### Struct-field ownership — **DONE, 2026-08-07**

The sibling of container ownership, and the item the previous handoff ranked first. It closes the
corpus: **14 866 leaked allocations → 0, with 0 violations, on all six programs.**

| | before | after |
|---|---|---|
| `g1_particles` | 0 | **0** |
| `g2_frame_loop` | 0 | **0** |
| `g3_scene_graph` | 4 095 | **0** |
| `g4_ecs_world` | 7 511 | **0** |
| `g5_asset_cache` | 47 | **0** |
| `g6_game` | 3 213 | **0** |
| total | 14 866 | **0** |

**Deliberately not the container mechanism, and the difference is the whole design.** A container is
*told* its element disposition at construction because its contents are dynamic — only the runtime
knows how many elements there are. A struct's fields are known statically, so the answer is a
**function generated per type**, `__aif_release_T`, with one release per owned field emitted in line.
Two things follow, and both are the point:

- **The disposition is per field.** A container reclaims nothing when its elements disagree, because
  a teardown loop makes one call for all of them. A generated function has a separate statement per
  field, so `World` — five owned `List`s and an `Int` — releases the five and steps over the Int. A
  single answer for the whole type would have to be NONE for all six, which *is* the leak.
- **No runtime word.** The container needs `elem_own` on the object; a struct needs nothing, because
  the type selects the function.

It needed no new fact. A struct literal's field initialiser has been a `STORE` into
`key_field(type, field)` since Level 0 — that is what carries E-STORE — so the sites that may reach a
field are exactly `pt[key_field(type, field)]`. This is a query, not a rule, which is why **no tier
moves**: the histogram over `src/main.psm` is identical before and after (212 T1, 13 T2, 73 T3).

Five things to know before touching it:

- **A pun must decline rather than guess, and the second generation is what said so.** The first
  build emitted a call to `__aif_release_String`, because this compiler puns an `ASTNode` pointer as
  `String` and walks node chains through it — so a `String`-declared field receives struct sites, and
  a release named from the sites alone names a function that does not exist. Gen 1 linked fine (it
  was built by the *old* compiler); gen 2 did not. `field_release_of` now requires the field's
  declared base type to match what the sites say is in the slot, and reclaims nothing when they
  disagree. Same discipline as arrays in `aif_frees_at_scope_node`, which decline by kind for exactly
  this reason.
- **A field is only a release point if its owner has one.** This is the rule `in_container` encodes
  one level out, and the naive version of it is wrong. A T0 struct lives in the frame: nothing frees
  it, so nothing runs its release, so barring the field's own binding does not *move* the release —
  it deletes it. `g5_asset_cache`'s `Scene` is four fields and does not escape `main`, so it takes
  the T0 clause, and barring its `entities` list took g5 from **47 leaked to 2049**. `type_is_reclaimed`
  is the guard. The leak count is the only detector; no value test sees it.
- **Ownership across a return now covers structs, and the soundness argument is different from
  `List`'s.** A `List` qualifies because it has no *literal* form. A struct qualifies because it has
  no *sentinel* form — there is no null, so every way to produce one is either a literal in the
  callee (a site) or a value from elsewhere (a site whose `fn` is not the callee's, which is already
  declined). **REQUIREMENTS 4 is the item that would make this false**, and the note is at the line.
  Restricted to structs that *own* something, which is a scope choice rather than a soundness one.
- **A container of owning structs is told a function, not an int.** `XEFY_ELEM_TYPED` plus
  `list_set_elem_releaser`, because the release differs per element *type* and the runtime cannot
  name a type. Same "told, cannot ask" rule as `elem_own`, one step less abstract. `ir_func_addr` is
  the new backend surface it needed.
- **This is the first level the self-host exercises.** Levels 1–5 were all fixture-only. The compiler
  now generates releases for `Token`, `Lexer`, `ASTNode` and `TypeInfo` and emits **11 calls** to
  them, and it still reaches a fixed point cold and warm — so the bootstrap is real coverage here for
  the first time, on top of `tests/test_49_aif_struct_fields.psm`.

**The differential is not the safety net here**, for the second time after layout. The oracle
compares tiers, and this changes none — so its agreement on all 12 sources is a check that the
change was *tier-neutral*, which is worth having and is not the same as checking it is correct. The
fixpoint, the corpus under `--verify`, and `run_aif_struct_field_test` are the coverage. That last
one is a static check on the emitted IR, because leaking is silently correct: a build that generated
no release function at all passes every value assertion in the fixture.

### Level 5 — T3 — **DONE, 2026-08-07**

Non-atomic reference counting for shared acyclic values.

**§1's finding 1 said the header word is what makes T3 only "partly" expressible** — "the header
word changes struct layout, which `named_struct` and every `ir_struct_field_ptr` index would have to
account for". That is true of a header word *inside* the object and avoided entirely by putting it
in front: `rc_alloc` returns `base + 16` and the count is `((size_t*)p)[-1]`. The LLVM struct type is
untouched, every field index still means what it meant, and the seam really is just a fourth
`fn(size) -> ptr`. The table's T3 row should read "Yes" with that caveat.

**The count starts at zero, and that is the design rather than an off-by-one.** What is counted is
*container edges*, because they are the only holder class this compiler both tracks and releases: a
T3 value's escape is Caller or Global by definition of the tier, so `aif_frees_at_scope_node` can
never admit its binding, and a struct field has no teardown. Counting the creating expression would
therefore put every T3 value permanently at one. At zero, one container is one count, the teardown
decrements, and the value dies with the last container that held it — while a value in no container
stays at zero and leaks, which is exactly what it did before this existed.

A release without a matching retain is not possible: only a container retains, and only the same
container releases, both driven by the one mode stamped at construction. That symmetry is the point
of putting them in `list_push`/`list_release` rather than at the call sites — a per-element answer
would be a chance for the two to disagree.

**Four exclusions, and each is a different sense of "we did not allocate this".** OPAQUE is the one
that matters: the pointer came back from a function this compilation cannot see, so there is no
header in front of it and a decrement writes into whatever the real allocator put there. `STRING`
and `LIST` are allocated inside `lang_runtime.c`, past the seam, so the site cannot choose its own
allocator — the same asymmetry Level 4 hit with the arena, and a hint would work here too. `ARRAY`
is frame storage. And the positive requirement: the site must be in a container, or it pays 16 bytes
of header for a count nothing will ever move.

**The self-host exercises none of it, for the fourth level running.** All 37 of the compiler's T3
sites are opaque extern returns, so `src/main.psm` emits **zero** calls to `rc_alloc` while still
declaring it. `run_aif_rc_test` asserts exactly that, and it is the more useful half of the test:
the compiler is the only program here large enough to violate the exclusion.

**The manifest now distinguishes `rc` from `rc:none`.** SPEC 6.2's placement column has to say what
was *built*, and printing `rc` for a T3 site nothing counts would assert a mechanism the binary does
not contain. All 37 compiler sites read `rc:none`.

**It found a pre-existing unsoundness, and both implementations had it identically.**
`list_set(list, index, value)`'s `retain_in(0)` named argument **1** — the integer index — so the
stored value was a plain `borrow` and appeared never to escape. Optimistic, i.e. exactly the
unsoundness the fallback table's own comment warns about. It was invisible while nothing acted on
the fact; at Level 5 a stored value took a *stack slot* and `list_set` wrote a frame pointer into a
container that outlives the frame. The oracle had the same off-by-one, which is how a differential
test agrees on a wrong answer — the third time this project has recorded that failure mode, after
the `List<T>` field edges and `parser_expect_close_angle`.

**What it measured.** `test_48_aif_shared_elements` goes from 2 leaked to **0 leaked, 24 allocated,
24 released, 0 violations**. The corpus does not move at all: no program in it reads an element out
of one container and pushes it into another, which is the only way to reach T3 once affine
collections are on. That is worth stating plainly — **T3 is rare by construction here**, and the
model is what makes it rare.

The fixture's load-bearing case is `survives_first_release`: a container is destroyed while another
still holds its element, and the element survives. No arrangement of single ownership can give that,
which is the whole argument for the tier.

**What is not done.** Perceus-style elision — a retain immediately followed by a release, or a
retain of a value whose only other holder is dying — needs the reference-level IR the codegen walk
does not have. Nothing here elides anything. And the release is at container granularity, so a T3
value held only by a binding or a struct field is still never freed.

### The zero-analysis level — **DONE, 2026-08-07**

SPEC §7.1's requirement, made falsifiable. `prismio build <src> --debug`.

**The invariant was asserted by a comment that had been false for five levels.** `src/aif.psm` said
the zero-analysis mode was true by construction, "because nothing it produces is an input to codegen
yet". That was accurate at Level 0. Inference now drives codegen at **eight** points — stack
promotion, arena placement, scope drops, container element disposition, refcounting, struct-field
release, cycle collection, and field order — and every one of them changes what is emitted.

**`--debug` is a budget of zero rounds, not a skipped pass**, which is what SPEC §7.2 actually says:
"levels are compile-time budgets, not different algorithms. The same engine runs at every level."
The graph is built and the pins are recorded; nothing is proved, so widening puts every value at its
top tier — heap, no drop, no arena, no count, no collector. Running the engine rather than skipping
it is what keeps §7.2's "a level SHALL NOT change which programs compile" true: a refuted `pin` is
still diagnosed.

`run_no_inference_test` builds every value fixture both ways and compares stdout and exit status —
**53 fixtures**, one excluded. The exclusion is principled and self-maintaining: a fixture is skipped
when its *source* reads the allocator's own counters, because §7.1 says "behaviourally identical"
does not mean same tier assignment, layout or performance. `test_44` asserts 209 arena objects and
gets 0 at `--debug`, which is §7.2's level table working rather than a violation.

**`max` is deliberately not offered.** With today's engine it would be byte-identical to `release` —
the bounds it raises are never reached on this corpus and there is no monomorphization cap to raise
— and a flag whose settings cannot be told apart is a check that cannot fail.

### The T4b cycle collector — **DONE, 2026-08-07**

CYCLES §3's trial deletion (Bacon–Rajan), scoped to the T4b residue, traversing only cyclic edges.
Before this a T4b site was *detected and then leaked* — plain `malloc`, no header, no release —
while the manifest printed `rc+cycle` for every one of them.

**Constructing a cycle at all was the hard part, and the finding is worth more than the collector.**
CYCLES §10 says to measure the T4b population *before writing a line of the collector*, and the
measurement is this: **a value cycle is not something a Prismio program can write by accident.** Two
independent things have to be defeated.

- The *type* must refer to itself, which needs REQUIREMENTS 4 — `parent: Node` had no terminating
  value and `parent: 0` did not typecheck. That is exactly why CYCLES had nothing to run against,
  and why item 3 was a hard prerequisite rather than a convenience.
- The *value* graph must close, and **affinity forbids every direct route**: `a.peer = b` is an
  ownership transfer, so `b.peer = a` is `use of moved value`. The container round-trip fails the
  same way. What is left is laundering a pointer through an `alias` extern — FFI §5.2's escape hatch
  doing exactly what it is for.

So `cycles none` is what the compiler and **all six corpus programs** report: no type in a
non-trivial SCC, collector omitted from the binary entirely. That is CYCLES §2's headline result
holding on every program in the project, and it is a stronger form of §1's prediction than §1 made.

Four things to know before touching it:

- **The counts have to include the edges the collector walks, and the first build did not.** Trial
  deletion subtracts internal edges and reads the remainder as "held from outside"; an edge that is
  traversed but was never counted makes it subtract a reference nobody added, and the arithmetic
  calls a live object unreachable. The first run **segfaulted** rather than leaking. `list_push`
  counted container edges (Level 5's design) but `a.peer = b` is a plain field store — so a store
  into a counted cyclic field now retains, and an assignment releases the old value, retain first.
- **The cyclic-edge restriction is what makes the work bound credible**, and it is available only
  because the compiler owns the type graph. `__aif_cyclic_children_T` visits exactly the fields whose
  type is in the owner's SCC, so the traversal cannot *leave* the skeleton into the string and token
  graphs hanging off it.
- **Struct-field ownership and the collector partition the field set.** `field_closes_cycle` makes a
  generated release decline any field that reaches its owner — otherwise `__aif_release_Node` would
  recurse until the stack gave out — and those are exactly the fields the collector walks. Neither
  mechanism can be understood without the other, and the boundary could not be drawn before
  REQUIREMENTS 4 made a self-referential type expressible.
- **`cycle:none` joins `rc:none` in the manifest**, for the reason Level 5 recorded: printing
  `rc+cycle` for a site nothing collects asserts a mechanism the binary does not contain.

Coverage is `tests/test_52_aif_cycle_collector.psm`. Its load-bearing case is `live_cycle_survives`,
which collects *while the cycle is still reachable* — trial deletion takes every count to zero
through the peer edges and `ScanBlack` has to put them all back. Getting that wrong is a
use-after-free rather than a leak, and the reads afterwards are what catch it. It needs CYCLES
§6.1's third trigger (explicit request) because the other two — buffer occupancy at 4096 and
allocation failure — are unreachable in a fixture small enough to reason about.

Not done: CYCLES §7's concurrency cases (there are no tasks), §8's inferred weak references, and
§10's tuning constants, which are the document's defaults and are **not** measured — this corpus
produces no candidates at all to measure with.

### The remaining FFI surface — **DONE, 2026-08-07**

`HANDOFF.md` ranked this second and said it "competes with item 1 directly": the compiler's 37 T3
sites were T3 only because provenance was unknown, and a declaration is cheaper than a refcount.

It is not close. Twelve declarations take the T3 residue from **37 to 0** and the compiler's
distribution to **100% T0–T2** over 294 sites. Level 5 could not have reached any of them — every
one is an opaque extern return, which must never be refcounted.

Eight are `alias`, four are `produce(free)`, and the split came from reading the C in every case:

| | |
|---|---|
| `alias` | `aif_extern_contract`, `aif_fn_symbol`, `aif_order_symbol`, `aif_site_type` (all `aif_str` of an interned id); `ir_get_var_type`, `ir_get_struct_field_type` (`ir_intern`, with a literal fallback); `cli_arg` (argv, which the C runtime owns); `ir_llvm_version` (a `static char buf[32]`) |
| `produce(free)` | `compiler_default_exe_path`, `compiler_temp_ir_path`, `compiler_installed_runtime_hash`, `compiler_runtime_source_hash` — all `malloc` and hand over |

The four `produce` declarations needed the check Level 4 had to make for `str_substring`: **every**
path allocates, including the failure paths, which return a one-byte empty string rather than a
literal. A `produce` that is true on the happy path only is a free of `.rodata`.

Two second-order effects worth recording. Site count falls 325 → 294 and `static-ret` rises 16 → 34,
because an `alias` return with nothing to alias is not an allocation and stops being a site at all —
so the denominator moves as well as the numerator, and "100%" is over a smaller set on purpose.
And T1 rose 205 → 209 with arenas 105 → 119: values that were T3 for want of a declaration are now
region-scoped and arena-served, so the compiler still emits **zero** individual frees.

**What this says about the ordering.** Level 5 was ranked first and this second; measured, the
ranking is inverted for this corpus, and the reason generalises. A tier is a claim about what the
analysis could prove, and an undeclared boundary is not a hard case — it is a missing input. Reach
for the input before the mechanism.

### The layout optimiser — **PARTLY DONE, 2026-08-07. `workload` deliberately not built**

LAYOUT §7.2, over a statically estimated access profile. **One of §6's five candidate dimensions is
searched, and the other four are not implementable rather than deferred:**

| Dimension | Status |
|---|---|
| Field order within a group | **Done** — searched and emitted |
| Grouping (AoS/SoA) | Needs handles. SoA makes one logical object several allocations, so a field reference stops being `getelementptr` on a pointer — §1 finding 6, "touches every layer" |
| Hot/cold split | Same reason: a second allocation and an indirection |
| Bit-packing | A mask and a shift at every access; self-contained but its own project |
| Handle width | There are no handles |

Choosing a layout codegen cannot emit would be a manifest describing a binary nobody built, so the
search is restricted to what it can act on. `layout` in the manifest reads `AoS` or `AoS*`, the star
meaning the physical order is not the declared one.

**Field order is safe to permute at all only because C sees a Prismio struct as an opaque `void*`.**
`ptr_to_node` and its siblings are the identity on a pointer and no runtime function reads a field.
`generate_struct_decl` feeds `ir_register_struct_field` and `ir_struct_type_field` from one loop, so
the name→index map and the LLVM body cannot disagree, and every access follows through
`ir_get_struct_field_index` without knowing a layout was chosen.

**The first field never moves, and finding that out cost two generations.** The compiler puns a
struct pointer as `String` and spells "this slot is empty" as `str_equals(ptr, "")`, which reads the
*first byte of the pointed-to struct* — which is why `NodeKind` and `TypeKind` both reserve ordinal
0 (`test_41_punned_slot_bytes.psm`). Sorting by width puts an 8-byte pointer at offset 0, and a
pointer to `""` has a zero first byte, so every live node with an empty `s1` read as absent. The
generation built by that compiler could not parse its own source. SPEC §8.2 grants the compiler
layout freedom; **this implementation has already spent the first field of it**, and the search has
to be told rather than allowed to rediscover it. `run_aif_layout_test` is the guard, because the
failure mode is "the next generation does not build", which no value test can see.

**LAYOUT §6's derived rule is wrong once a field is pinned, and measurement is what says so.** §6
derives field order as a *sort* — descending frequency, then descending alignment — and a sort is
optimal for padding only when placement starts at offset 0 with nothing fixed. Pinning a 4-byte
`kind` leaves a 4-byte hole that only a narrow field can fill; the sort puts the widest field next
and pays for it. Measured: `Health` 16 bytes → **24**, `Sprite` 40 → **48**. It made nothing smaller.

Placement is greedy over the running offset instead — the widest remaining field that needs *no*
padding where the last one ended, falling back to the widest overall — with frequency as a
tie-break and declaration index below that, so the result is total and deterministic (§9). Frequency
is demoted rather than dropped: §6 puts it first to decide where a hot/cold cut falls, and there is
no cut to decide.

**What it measured.** Across the compiler and all six corpus programs, one struct shrank and none
grew: `g6_game`'s `Order` 32 → 24 bytes. Several others were reordered to the same size. That is a
small result and it is the honest one — declaration order was already near-optimal almost
everywhere, which is worth knowing before anyone budgets for the SoA half.

**The differential is not the safety net here**, and this is the first item where that is true. The
oracle is run in `--theta-fields` mode, so it approximates Θ_stack by field count and never sees a
byte size — the layout is invisible to it by construction. The fixpoint and `run_aif_layout_test`
are the coverage.

**`workload` is not implemented, and building it now would be the same mistake pointed the other
way.** Its only contribution over the static estimate is *measured* frequencies, and producing those
needs a build-time instrumented compile-link-run inside the compile, plus §3.2's W3 obligations
(stubbing network and filesystem, warning on each). Shipping the syntax without the runner gives a
producer that produces nothing — exactly the "annotation with no consumer" objection, inverted. The
static profile is what LAYOUT §10.4 already names as the fallback, and it is the same estimator
automatic arena placement uses (`AIF_LOOP_ITERS`, now defined once so the two cannot drift).

When it is built, the instrumentation point already exists: `ir_struct_field_ptr` is the single
choke point for field access, the way `ir_alloc_object` is for allocation.

### Beyond

Ownership monomorphization (needs contexts and body duplication), the layout optimizer (needs
handles — see §1 finding 6), PIR, concurrency and therefore a non-vacuous `T` domain, the T4 cycle
collector. Each of these is a project on the scale of the current compiler.

**Honest read on schedule:** Levels 0–5 are all landed as of 2026-08-07, which is further than this
section's original estimate of "Levels 0–3 are a realistic near-term programme". What made the
difference was that four of the five levels turned out not to be exercised by the self-host at all,
so the risk each carried was fixture-shaped rather than bootstrap-shaped. Everything still under
"Beyond" is the part of SPEC that describes a language that does not exist yet, and the spec should
be read that way — with **ownership contexts (INFERENCE §6) now the single highest-value item**, because
three separate limitations recorded above are the same missing thing: ownership transfer surviving
only one hop, the element key having to be object-insensitive, and `g4_ecs_world` not moving.

---

## 6 · Spec changes this analysis forces

Findings that are defects in the specification rather than gaps in the compiler:

1. **The invariant needs a boundary** (§2.1). Move/borrow violations stay compilation errors; the
   invariant governs tier inference only. → SPEC §1.
2. **The value-semantics justification is wrong for the actual implementation** (§2.2). `unique`'s
   completeness rests on explicit moves, not on aliasing being unrepresentable. → SPEC §11 item 10
   and INFERENCE §8.2 should say "affine references with checked moves" as the sufficient
   condition.
3. **The seam needs three hooks, not a name** (§3). Not strictly a spec item, but SPEC's claim that
   T0 is the degenerate case of T1 is *architecturally* true and *not* true of the emitted code —
   `alloca` and arena-bump are different instructions. Worth a note so nobody plans around a
   one-line change.

Items 1 and 2 are applied in the current SPEC revision. Item 3 is recorded here only.
