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
  them. Level 1 will need them, because codegen has to look a tier up.

And it did what this section said it would: the distribution was measurable cheaply, and it
immediately contradicted a recorded result. See the correction note atop
[RESULTS-L0.md](../evidence/RESULTS-L0-tiers.md).

### Level 1 — T0

Stack-promote non-escaping structs. Escape module only; `ir_alloc_stack` hoisting to the entry
block.

- Risk: struct literals reachable from a `return`. The escape module must be right or the compiler
  miscompiles itself — which the fixpoint test will catch loudly.
- Measurable: allocation count on a self-compile should drop.

### Level 2 — T2 and scope drop

Deterministic destruction at scope exit for uniquely owned structs. Needs §4.2.

- This is where the compiler stops leaking structs.
- Biggest correctness risk in the whole plan: a missed drop path leaks, a doubled one crashes.
  Both are caught by the existing 56-test suite plus a leak check under a debug allocator.

### Level 3 — T1 and `region`

Arena runtime, `region` keyword through lexer/parser/sema, the arena handle threaded to
allocation sites, `ir_alloc_region`.

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
