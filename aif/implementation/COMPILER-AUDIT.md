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
| 4 | **Strings, arrays and lists are never freed and are not move-only** — and they are the majority of real allocations. Anything AIF does to structs alone moves a minority of the traffic. | High |
| 5 | **Prismio cannot comfortably express its own inference engine.** No generics, no closures, no hash maps; `List<T>` is a hardcoded special case. A worklist fixed-point solver needs all three. | High, underrated |
| 6 | **Handles do not exist.** References are raw `ptr`, field access is `getelementptr`, and 104 extern declarations pass pointers to C. Frozen item 5 touches every layer. | High, long-horizon |
| 7 | **There is no concurrency**, so the `T` domain is vacuous and T3 vs. T4a is currently undecidable-by-absence. Everything shared lands T3. | Medium — actually simplifying, for now |
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
wrappers and are **never freed**.

So even a complete tier implementation for structs leaves the majority of a real program's
allocation traffic outside the model. Fixing that means making `String`, arrays and `List<T>`
move-only — which `types.psm:88`'s own comment defers ("*String/Array become move-only once
borrows land; for now they stay copyable to avoid churn*").

**This is the prerequisite with the widest blast radius in the whole compiler**, because every
string-handling function in `lexer.psm`, `parser.psm`, `sema.psm` and `ir.psm` currently assumes
strings are freely copyable.

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

### Level 4 — strings, arrays, lists become move-only

The wide-blast-radius change of §3.1. Deliberately after Level 3 so that regions already exist to
absorb them — most string traffic in the compiler is region-shaped.

### Level 5 — T3

Non-atomic reference counting for shared acyclic values. Header word, layout consequences,
Perceus-style elision.

### Beyond

Ownership monomorphization (needs contexts and body duplication), the layout optimizer (needs
handles — see §1 finding 6), PIR, concurrency and therefore a non-vacuous `T` domain, the T4 cycle
collector. Each of these is a project on the scale of the current compiler.

**Honest read on schedule:** Levels 0–3 are a realistic near-term programme against this codebase.
Everything from "Beyond" is the part of SPEC that describes a language that does not exist yet, and
the spec should be read that way.

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
