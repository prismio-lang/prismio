# PIR: Prismio's middle IR, a layered hybrid

**Status:** design, revised 2026-11-27. Nothing is built. The first version of this plan
(2026-11-22) proposed a pure affine RVSDG. This revision keeps its goals, its measured motivation
and its migration discipline, and changes the structure: PIR is now **several representations
layered on one node set**, each taken from the IR family that is best at one of Prismio's problems.
The 2026-11-22 text was never committed; what still holds of it is folded in below.

**PIR** (Prismio Intermediate Representation) sits between the checked AST and LLVM IR. It is
written in Prismio, in `src/pir/`, deterministic by construction, and it is the place where
ownership, storage, views, loop facts and layout stop being re-derived from the shape of the AST.

The name is reserved twice. [`aif/spec/PIR.md`](aif/spec/PIR.md) designs PIR as "the compiler's
own IR and package-distribution format". This plan builds the compiler-IR half and designs the
upper level (PIR-H, §12) so that it *is* the distribution format later (§20, P10).

---

## 0 · Decisions in one screen

1. **One middle layer:** AST → sema → **PIR-H** → **PIR-L** → LLVM IR. AIF, layout, drop
   elaboration and the loop-fact passes become passes over PIR. No MLIR.
2. **PIR is a hybrid, not one textbook form.** Each layer answers one question, and each is
   borrowed from the IR family that answers it best:

   | Layer | Question it answers | Borrowed from |
   |---|---|---|
   | **Skeleton** (§4) | where control goes | RVSDG's nested regions + join points with arguments (Lean 4, *Compiling without continuations*) |
   | **Spine** (§4.3) | in what order effects happen | an instruction list per region, as in SIL / MIR / Cranelift's side-effect skeleton |
   | **Pure graph** (§5) | which values are equal and what they compute | a sea of nodes, floating and hash-consed, as Cranelift's aegraph does for pure instructions |
   | **Places and state** (§6) | which memory a write can affect | RVSDG state edges, split per place as LLVM's MemorySSA partitions them |
   | **Ownership** (§7) | who releases what, where, and how a view stays valid | OSSA (Swift SIL), Rust MIR drop elaboration, Perceus, Hylo's value `inout` |
   | **Heap model** (§8) | which allocations can reach which, and their tier | AIF as it is, made flow-, field- and context-sensitive by the layers above |
   | **Facts** (§9) | what is known about every value | a sparse abstract interpreter (SCCP's shape), e-SSA refinements (ABCD), Polonius-style relations with provenance |
   | **Levels** (§12) | what the program means versus how it is laid out | progressive lowering (MLIR's idea), done as two levels of one node set |

3. **Ownership is read off the graph, and every decision is a node.** A move-only value has
   exactly one consumer. Drops, delayed drops, delegated drops, run-time-settled drops and
   **leaks** are all explicit nodes, so a leak is something the compiler wrote down and can
   report, not something it forgot (§7.7).
4. **Prismio never rejects a view; it repairs it.** Where Rust's borrow checker would refuse a
   program, PIR chooses the cheapest repair: delay a drop, park, materialise a copy, raise the
   base's storage, or settle at run time (§7.4). This is SPEC §8.4's stance made mechanical.
5. **Static first, run-time witness second.** When a fact can only be known at run time (which
   argument `pick` returned, whether a slot holds a literal, whether a binding holds a frame value
   or a heap one), PIR carries an ownership claim conditioned on a **witness** value, and lowering
   picks the cheapest witness: a tag bit, a pointer compare, a carried flag, or the slab's span
   class (§7.5).
6. **Values are handles; contents are places.** An aggregate has identity (a struct in two Vecs is
   one struct, `RESEARCH_ROUND4.md` §4), so a struct or Vec value is an affine *handle*, and its
   fields and elements are places with state. Fields become SSA only when a fact proves the object
   identity-free (§6.4).
7. **Effect signatures are the one summary.** Every lambda carries a signature: parameter modes,
   result provenance, place effects, allocation context, failure. It is MEM-005, computed once and
   read by every caller, AIF and codegen alike (§10).
8. **Two levels.** PIR-H is target-neutral and layout-neutral: abstract fields, handles and views.
   PIR-L has storage, layout and runtime calls chosen. PIR-H is what a `.plib` will ship (§12,
   P10).
9. **A PIR interpreter checks ownership semantically**, independent of the allocator: drop
   poisons, a use of a poisoned object is reported with its span, and live objects at exit are the
   leak list. It is the read-after-free detector the slab hid from ASan, and a differential oracle
   for every pass (§14).
10. **It migrates one function at a time**, first as a planning IR whose decisions the existing
    AST codegen reads (byte-identical where no fix applies), later as the emission IR (§20).

## 1 · What PIR has to solve

### 1.1 · Prismio's memory model is not Rust's, C++'s or Swift's

A middle IR for Rust checks borrows, and one for Swift balances retains. Prismio's problems are
different, and PIR's design starts from them:

| # | Property of Prismio | What it demands of the IR |
|---|---|---|
| R1 | **No lifetimes, no borrow annotations.** A view is inferred, never written. | View extents are computed, not checked against user intent; a conflict is repaired, never an error (§7.4). |
| R2 | **Tiers T0–T4 with monotone fallback.** Every tier is sufficient for every value. | Storage class is an attribute ordered by a lattice, separate from the affine discipline; raising it is always a legal transformation (§7.1). |
| R3 | **A leak is acceptable; a violation is not.** | Every transformation has a stated failure direction; the default for "unknown" is an explicit leak node (§7.7). |
| R4 | **The compiler owns layout; views are `(handle, offset, length)`.** | The upper level never sees an address or an offset (§12). |
| R5 | **Parameters are borrows** (`@guaranteed`); `sink` consumes; `inout` is a mutable borrow; `unique` is an optional assertion. | A callee never consumes an ordinary parameter, so the caller's drop placement is local (§7.3, A8). |
| R6 | **Aggregates have identity.** Storing an element read shares; storing a String view copies. | Handles and places (decision 6); clone is an explicit node (A9). |
| R7 | **Ambient, dynamically scoped arenas**, automatic placement, call-site bracketing. | The allocation context is a value that flows into calls (§10.3). |
| R8 | **Whole-program analysis, and separate compilation through `.plib`.** | Summaries are a cache over bodies; bodies ship at the upper level (§12.3). |
| R9 | **Self-hosted, seed-bootstrapped, two-generation fixpoint read in the IR.** | Deterministic ids, canonical dumps, no hash-order iteration, no new syntax (§16). |
| R10 | **Structured control flow only** (no `goto`), labelled `break` / `continue`, early `return`. | Keep the structure (regions), and make early exits cheap (join-point exits, §4.4). |
| R11 | **Tasks, scopes, typed channels; copyable task handles.** | Capture is a move; a scope's join is an exit action; a shared handle's result is holder-owned (§13). |
| R12 | **Performance decides; LLVM stays the optimiser.** | Lowering is where facts become LLVM attributes and metadata (§12.4); PIR does no scalar optimisation LLVM already does. |

### 1.2 · What the research measured

The recurring bug is **the analysis and codegen disagreeing about who owns a value**. Codegen
re-derives ownership from the shape of the AST: 30 distinct AIF queries at 69 call sites, at least
24 ownership-guard helpers in `src/ir`, 1,349 lines in `overwrites.psm` and `columns.psm`, 50 guard
references in `expr.psm`, and 67 commits to those files since 2026-09-01
(`aif/RESEARCH_ROUND3.md` §6). Beside it sit nine loop-fact passes (`ranges`, `relations`/`dbm`,
`nowrap`, `counters`, `contents`, `residues`, `strides`, `reductions`, `tiling`, together over
7,000 lines) that each re-discover induction variables, assignments and loop structure from the
AST with their own walk.

| Shape (research doc) | Measured | Why the AST makes it hard | PIR mechanism |
|---|---|---|---|
| a field or payload taken out of a dying binding (`RESEARCH_BUILD_LIST.md` §2.2; `test_273`) | 900 of 907; 300 of 400 | "dead after this statement" is a liveness question | `take` at last use, typed remainder (A6) |
| a temporary on the right of `and`/`or` | leaks | a hoist runs it always | it lives in one arm of a branch and is dropped there (A3) |
| a binding returned on some paths (`test_205`) | 10 | the drop list is per scope, not per path | exit-edge elaboration (§4.4) |
| one of two parameters returned (`test_269`) | 9 | which one is dynamic | `settle` with a pointer-compare witness (§7.5) |
| frame and heap values in one binding (`test_58`) | 50 / 50 | codegen cannot tell which it holds | a storage witness or storage agreement, chosen by cost (§7.5) |
| a factory element shared once (§2.1 of the build list) | 200 / 410 | field keys are per type | holder-owned fields, per-object field keys (§7.6, §8.2) |
| parked elements; the closed-column proof | 8–32× RSS before the fixes | a whole-module syntactic walk | a delayed drop ordered on the place's state chain (§6.3, §7.4) |
| no `llvm.lifetime`, no result slots (MEM-008, MEM-009) | not started | moves are gone before LLVM | extents and destinations are explicit (§12.4) |
| nine loop walks over the AST | 7,000+ lines | each rebuilds induction variables | loop-carried ports and one fact engine (§9) |

What PIR does **not** fix: the engine rules that are independent of any IR (owned by its counted
holder, storage agreement, a global slot as one owner, the extern summary rule, copies as owned
allocations) and the runtime work (the slab, the sanitizer gate, a count for Vec). They land first,
on the AST (`RESEARCH_BUILD_LIST.md`), and PIR later re-expresses them (§19).

## 2 · Where PIR sits

```
source ─▶ parse ─▶ AST ─▶ sema (types, legality, rewrites, monomorphisation)
                               │
                               ▼
                 ┌──────── PIR builder (per function) ───────┐
                 ▼                                            │
   PIR-H passes: verify · signatures · AIF (heap model, tiers) · facts · drop elaboration
                 │           · view repair · witnesses · specialisation
                 │
     stage A     ├─▶ plan side table, keyed by AST node ──▶ existing AST codegen ──▶ LLVM IR
                 │
     stage B     └─▶ lower: storage + layout + representation ─▶ PIR-L ─▶ LLVM IR
                                                                    ▲
                                       PIR interpreter (§14) runs either level
```

- **Sema stays the legality authority.** Move errors, borrow errors and their diagnostics keep
  coming from `src/sema/ownership.psm`. PIR's verifier is an **assertion**: a function sema accepted
  that PIR rejects is a compiler bug, reported with the function's name. Whether sema's move checker
  later runs on PIR, for non-lexical diagnostics, is an open question (§22).
- **The existing loop passes keep running on the AST** until the fact engine (§9) reproduces each
  one's decisions byte for byte (P8).

## 3 · The layers at a glance

```
 lambda  fn itemsOf(i: copy Int) -> own Vec<String>            ← signature (§10)
 ├─ skeleton:  region tree   fn ─┬─ branch ─┬─ arm ─ …          ← §4: nesting, ports, exits
 │                               │          └─ arm
 │                               └─ loop ─── body
 ├─ spine (per region):  e0 → e1 → e2 → exit                    ← §4.3: total order of effects
 ├─ pure graph:  %a = add %i 1   %b = icmp lt %a %n             ← §5: floating, hash-consed
 ├─ places/state:  v.elems: s0 → s1 → s2   bag.label: s0        ← §6: per-place versions
 ├─ ownership:  %s own String  ·  %n view of v.elems@s1          ← §7: modes, drops, witnesses
 ├─ heap model:  site 14·ctx2 → held-by v.elems                  ← §8: AIF
 └─ facts:  %i ∈ [0, 99]  %i ≡ 0 mod 1  check#3 discharged       ← §9: sparse, with provenance
```

One node set carries all of them. A node is a record; the layers are views over it, kept consistent
by the verifier (§16.3).

## 4 · The skeleton: regions, spines, ports and exits

### 4.1 · Region kinds

| Region | Source | Ports in | Ports out | Exit ports it offers |
|---|---|---|---|---|
| `fn` | a `fn`, a method, a lifted closure body, a lifted `spawn {}` | parameters, the allocation context (§10.3) | — | `return(values)` |
| `branch` | `if`/`else`, `match`, `and`/`or`, `??`, `expect`, `if let`, `while let`'s test | the predicate or scrutinee; the owned values the arms consume | the merge values | `merge(values)` (one per arm path) |
| `loop` | `while`, `for`, `loop`, `repeat`, `while let` | the loop-carried values | the values carried out | `next(carried)`, `break(values)`, plus a label |
| `arena` | `region name {}` and every automatically placed arena | the region token | values that may leave (never arena-stored ones) | `out(values)` |
| `taskscope` | `scope {}` | — | — | `out(values)` |
| `block` | a lexical block, **debug information only** | — | — | — |

A `group` (one per strongly connected component of the call graph) holds mutually recursive
lambdas so signatures (§10) reach a fixed point over it. A `global` holds a module-level `let` or an
`extern let`.

`block` exists only so debug information keeps its lexical scopes. Drops do not follow blocks: they
follow liveness (§7.3).

### 4.2 · Why regions at all

Prismio's control flow is already structured. A CFG would throw that structure away and then
rediscover it, and four things in Prismio need it whole:

- an **arena** or **task scope** has one boundary that every path out crosses, and that is where its
  close action goes;
- the loop-fact passes are interpretations **of a loop**: the loop-carried ports are the induction
  variables, with no discovery step;
- liveness and last use on a region tree are one backward pass per region, plus one extra pass per
  loop for its carried values; no iterative dataflow is needed;
- lowering to LLVM's canonical loop form (preheader, header, one latch, dedicated exits) is direct.

### 4.3 · The spine

Inside a region, **effects form a spine**: a list in source order of the nodes that touch a place,
the world, the allocation context, or control (calls, stores, allocations, drops, nested regions,
and the terminating exit). Pure nodes are not on the spine (§5).

The spine is a deliberate departure from pure RVSDG, where order comes only from state edges:

- **Stage A needs it.** The plan side table is keyed by AST node and read in source order by the
  existing codegen. A total order that is source order maps one to one.
- **Determinism is free.** The emission order is the spine order; no scheduler has to break ties.
- **Analyses still get the partial order.** Place state edges (§6) say which spine entries actually
  depend on each other, and a pass that moves an effect (a drop sinking or rising, a store
  forwarded) checks the move against the state edges, then re-threads the spine.

### 4.4 · Exits are join-point jumps, and drops live on exit edges

A region body is straight-line: it diverges only by nesting a region, and it leaves only through an
**exit**. An exit is a terminator that names an exit port of the region itself or **of any
enclosing region**, with arguments that match that port:

```
exit @L1.break(%acc)       // leave the labelled loop L1, carrying %acc out
exit @fn.return(%v)        // an early return from any depth
exit @L1.next(%i1, %acc1)  // continue L1
exit fail                  // panic, a failed expect, a bounds failure, exit(): never returns
```

This replaces the first plan's exit predicates. RVSDG's single-exit rule made a deep `return` a
small enum threaded through every enclosing region and tested after each one; a join-point exit is a
direct jump with arguments (Maurer et al., PLDI 2017; Lean 4's `jp`/`jmp`), and the structure stays:
an exit can only target an *ancestor*, so the region tree remains a tree and lowering remains direct.

**Drop elaboration runs on exit edges.** An exit that leaves regions R1 … Rk (innermost first)
ends, on that path, every owned value that is live there, defined in or ported into R1 … Rk, and
not passed as an argument. Elaboration (§7.3) puts their drops right before the exit, in reverse
definition order. Then, innermost first, each crossed `arena` contributes its pop and each crossed
`taskscope` its `scope_end`. So:

- `test_205`'s binding is consumed by the return on one path and dropped before the exit on the
  others, with no `E_held` / `ret_key` machinery;
- an arena is closed on every path out, by construction rather than by `ir_drop_barrier_push`;
- `exit fail` gets no drops: the process ends, as today.

### 4.5 · Owned values cross region boundaries only through ports

A pure or `copy` value defined outside a region may be used inside it directly (implicit capture,
as MLIR allows for regions that are not isolated). An **owned** value may enter a region only as an
input port and leave only as an output port or exit argument. This makes the affine rule local: the
verifier checks one region at a time, and per-arm consumption (A3) is a property of each arm's
ports, not of a whole-function search.

## 5 · The pure graph

Pure nodes (arithmetic, comparisons, casts, literals, address-free projections of copy values,
`select`) float: they have operands and no spine position. Within a function they are
**hash-consed** on (op, operands, type, flags), so equal computations are one node, and every pass
sees value numbering for free. They are scheduled only when lowering:

- **at the latest point that dominates every use, but never into a loop deeper than its operands**,
  which is loop-invariant code motion by construction;
- with ties broken by node id, which is builder order, which is source order.

This is the part of sea of nodes that pays, without the part that does not. V8 moved its optimising
compiler away from a full sea of nodes, citing the cost of scheduling everything and of effect
chains on every node (from memory: the Turboshaft work, 2023–2025). Cranelift keeps a side-effect
skeleton and lets only pure instructions float in its aegraph. PIR does the same, without the
e-graph (§21).

Copy values never need ownership tracking. A `Copy` type (scalars, fieldless enums, `Ptr`) is a pure
value, even when it came from a load, once the load's state has been read.

## 6 · Places and state

### 6.1 · What a place is

Locals are not places. A `let mut x` of any type becomes SSA at build time: an assignment is a new
SSA value, and for an owned type the old value is consumed (dropped, or displaced into a delayed
drop). Only **memory** is made of places:

| Place | Written by |
|---|---|
| `o.f` — field `f` of the object a handle `o` names, per field path | field assignment, `take`/`put`, an `inout` callee |
| `o.elems` — the elements of a container, one place for all indices | `v[i] = x`, `push`, `remove`, `insert`, `clear`, sort |
| `o.hdr` — a container's length and capacity | `push`, `pop`, `clear`, growth |
| `g` — a global slot | assignment to a module-level `let mut` |
| `world` — I/O, externs without contracts, `std.raw` | every call that might touch the outside |

A place is identified by an abstract object (§8) and a path, so `a.items` and `b.items` are
different places when the heap model can tell `a` and `b` apart, and one place when it cannot. The
coarser answer is always sound.

### 6.2 · State versions

Every place has a chain of versions, `s0 → s1 → s2 …`, one per write. A write consumes one version
and produces the next. A read is pinned to one version. A call's effect signature (§10) names the
places it reads and writes, so a call is a write to exactly those places and no others; a call
with an opaque signature writes `world` and every place reachable from its arguments.

State is split per place, as LLVM's MemorySSA partitions memory. Two different places give two
independent chains, which is what later becomes LLVM alias scopes (§12.4).

### 6.3 · Ordering questions are reachability on one chain

"May the value displaced by `v[i] = x` be released now?" becomes: is any view taken from a version
`≤ sk` of `v.elems` used at a spine position after the store? That is a scan over the uses of the
views of one place in one function, bounded by the function's size. Across calls, a callee that
might keep or read such a view is visible in its signature (it reads `v.elems`, or retains a view of
it), so it counts as a later use. The same check covers what `overwritesMark`, `semaRemovalVerdict`
and the closed-column walk (`src/ir/columns.psm`) decide today, for any place in one function, and
crosses calls through signatures.

### 6.4 · Promoting a place to SSA

An object whose handle never escapes, is never viewed by a stored view and never reaches a call that
retains it is **identity-free**. Its fields can become SSA values (scalar replacement at the PIR
level), its storage becomes `frame`, and the struct may be passed in registers to a specialised
callee (MEM-008's second half, MEM-027). Identity-freedom is a fact (§9), so a later fact that
disproves it simply leaves the object as a handle.

## 7 · Ownership

### 7.1 · Modes and storage are two different things

Every value has a **mode**, which is part of its PIR type and is fixed by the builder from sema's
answer:

| Mode | Rule | Examples |
|---|---|---|
| `copy` | any number of uses | `Int`, `Bool`, fieldless enums, `Ptr` |
| `own` | **exactly one consumer** | a fresh `String`, `Vec<T>`, struct, payload enum, a `sink` argument |
| `view` | any number of uses; pinned to a **base** (§7.4) | a parameter, `v[i]` of an owning element, `x.f`, a match binder, an `alias` result |

Separately, every owned value carries a **storage class**, an attribute that AIF computes (§8) and
lowering reads:

```
frame  ⊑  arena(r)  ⊑  heap  ⊑  counted  ⊑  atomic
                      static      foreign(f)      mixed{…, witness}
```

The order is SPEC's monotone fallback: raising a value's storage class is always legal. The **drop
kind** (free, `list_release`, a typed release, an RC decrement, an arena no-op, `foreign(f)`'s
deallocator, nothing for `static`) is a function of the storage class and the type, so PIR decides
*where* a value ends and the storage class decides *how*. That is the division the first plan stated
as "PIR decides where, AIF decides how", kept.

### 7.2 · The affine rules

`pir_verify` checks these after the builder and after every pass.

- **A1 · One consumer.** Every `own` value has exactly one consumer: a `sink` argument, a store into
  a place, a push, a return or other exit argument, a region input port, a `take` (A6), a `drop`,
  or one of the ownership nodes below (`settle`, `delegate`, `leak`).
- **A2 · A drop is a missing consumer.** After the builder, an owned value with no consumer gets a
  drop at its last use (§7.3).
- **A3 · A branch consumes per arm.** An owned value entering a branch is an input port of every
  arm. An arm that does not consume it drops it on each of its exits. The `and`/`or` temporary built
  in the right arm is created, used and dropped in the right arm only.
- **A4 · A loop threads its owned values.** An owned value entering a loop is a carried port, and
  each `next` exit must supply a replacement. Consuming it in the body without one fails
  verification. Sema already refuses this ("moved inside a loop"), so here it is an assertion.
- **A5 · A view keeps its base.** A view's base must not be consumed before the view's last use.
  When the builder's first placement would break that, view repair (§7.4) moves something, and the
  verifier checks the result.
- **A6 · Take and put.** `%f, %rest = take %x.f` consumes the owned handle `%x` and produces the
  field's value and a **remainder** of type `Bag∖{items}`. The remainder's drop releases the other
  fields and the box, not `.f`. `put %rest.f, %v` restores a full value. A match arm that binds a
  payload of a scrutinee with no later use is a `take` of the payload; the shell is the remainder.
  Remainder types are interned per hole set, and each gets a generated release, memoised.
- **A7 · Containers.** `push %v, %x` consumes `%x` and writes `v.elems` and `v.hdr`. `v[i]` of an
  owning element type is a view pinned to the current version of `v.elems`; of a copy type, it is a
  copy. `%d = set %v[i], %x` consumes `%x` and produces the **displaced** element as an owned value,
  which elaboration ends where §6.3 allows (§7.4).
- **A8 · Calls.** A borrow parameter takes a view, a `sink` parameter consumes, an `inout`
  parameter takes the caller's place and gives it back written (Hylo's `inout`: as a value, an
  in/out pair; at PIR-L, an address). The result is fresh `own`, a `view` of the bases the signature
  names, or `copy`.
- **A9 · Copies are owned allocations.** `clone` is a node and produces a fresh `own` value. So is
  every copying conversion: a literal converted to `String?`, a String view copied on keep. That is
  `RESEARCH_ROUND4.md` §2's fix, as structure.

### 7.3 · Drop elaboration

After AIF has given storage classes, elaboration places every drop:

1. **Last use, per path.** On each path, an owned value with no consumer is dropped right after its
   last use on that path, or on the exit edge that leaves its region (§4.4). On a region tree this
   is one backward pass, plus one per loop. It is the F1 query of the build list, answered by
   structure.
2. **Policies.** The default is *release at last use*, which lowers peak memory (`RESEARCH_P9_LEVERS.md`
   §2, 1b). Two other policies are expressible on the same graph: *release at scope end* (today's
   placement, used by stage A wherever the plan must reproduce today's IR), and *elide at exit* on
   `main`'s return edge (lever 1, teardown elision), which turns those drops into
   `leak(exit)` nodes, except under `--verify`, with the slab off, and on freestanding targets.
3. **Drop kinds.** Each drop gets its kind from the storage class. A drop of an `arena(r)` value is
   removed (the arena frees it in bulk). A drop of a `frame` value becomes a `lifetime.end` (§12.4).
4. **Batching and reuse.** Two drops of `heap` values of the same size class next to an allocation
   of that class in the same region may become a **reuse** (Perceus's reset/reuse, MEM-007): the
   drop is replaced by a `reset` that keeps the block, and the allocation takes it. Only where the
   type's generated release can run its field releases first.

### 7.4 · Views and view repair

A view has a **base**: the owned value or place version it was read from. A5 requires the base to
outlive the view. Where Rust would reject a program, Prismio repairs it, choosing by cost:

| Repair | When it applies | Cost | Today's equivalent |
|---|---|---|---|
| **delay** the base's drop past the view's last use | the base is dropped (not moved) in this function | nothing | none: scope-end drops do this by accident |
| **delay** a displaced value's drop past the last use of any view of its old version | `set` or `remove` while a view is live, all in one function | nothing | parking until the Vec dies |
| **transfer** the dependency to the new holder | the base is moved into a place while the view is live | nothing; the view now pins that place's version | none |
| **park** the displaced value with its container | a view of the old version escapes the function, or crosses a call whose signature may retain it | memory until the container dies | parking |
| **materialise** the view (`clone`, copy-on-escape) | a view leaves its base's extent (returned, stored in a field, carried out of a loop) and the base cannot follow | one copy | F18, not built |
| **raise** the base's storage to the view's destination | as above, when the copy is dearer than the base | the base sinks a tier | `E-VIEW`, today's only answer |
| **settle** at run time | the view's base is one of several values, decided at run time | one compare per candidate | the `test_269` proposal |

Delay is the common case and costs nothing: a displaced element can be released right after its
last view instead of when its Vec dies, which is a precise answer where today's is "park" or "prove
no view exists". Parking stays for views that escape or cross a retaining call.

A view stored into a field (an enum payload view held by a struct, KNOWN_ISSUES) is a view consumed
by a store into a place: from then on that place's state pins the base, and the base's drop is
delayed past the holder's last use, or the view is materialised at the store. The choice is the same
cost question.

### 7.5 · Witnesses: ownership settled at run time

Some ownership facts cannot exist statically. PIR represents them as an **owned value conditioned
on a witness**: `own T ?w`, meaning "this value is owned, and must be released, exactly when the
witness says so". The verifier treats a conditioned value as owned on both sides of the witness.
Lowering chooses the witness's form:

| Witness | Cost | Case it fits |
|---|---|---|
| `static true/false` | nothing | the fact was proved after all |
| `tag(bit)` in the value | a test of a bit already loaded | literal versus owned String (bit 34 already is one) |
| `eq(%r, %a)` | a pointer compare | `pick(a, b)` returned one of its arguments |
| `flag` | one `i1` carried through the same ports as the value | a binding that holds a frame value on one path and a heap value on another (`test_58`) |
| `span` | one load from the slab's span table | arena memory versus heap memory in one body (`RESEARCH_ROUND3.md` §3), on targets with the slab |

Two nodes use witnesses:

- `settle %r from {%a, %b}`: `%r` is a view whose base is one of `%a`, `%b`. Settling transfers
  ownership of that one to `%r` and drops the others, through `eq` witnesses. `test_269` becomes a
  compare and a branch per call of the pass-through function, and leaks nothing.
- `mixed` storage: when a binding's sites are both `frame` and `heap`, AIF either raises the frame
  sites to `heap` (storage agreement: one allocation for the initial value) or keeps them and adds a
  `flag` witness (one register, one branch at each drop). Both are legal; the cost model picks per
  binding. Storage agreement lands first on the AST and is the default; the witness is the option
  PIR adds.

A witness is never an excuse to skip a proof: elaboration tries `static` first, and the manifest
counts witnesses per function as a cost, as it counts tiers.

### 7.6 · Delegated drops: owned by the holder

A store of an `own` value into a field of a `counted` object delegates the value's end to that
object: `delegate %x → o.f`. The object's generated release frees it when the count reaches zero.
This is build item 3 (owned by its counted holder, `RESEARCH_P1_RESIDUE.md` §4 C1) as a node: the
value has one holder, the holder is counted, and the drop is the holder's. The obligations of C1
(one holder, agreement over the field's points-to set, no move out of a counted holder's field)
become verifier checks on `delegate` nodes. A copyable task handle's result is the same shape: the
task object is counted, and its result field is holder-owned (§13).

### 7.7 · Leaks are explicit

When nothing can prove a release (an `rc:none` site, an opaque extern's result, a view that pins a
base past every consumer), elaboration writes `leak %x (reason)`. A leak is a consumer for A1, so
the verifier is satisfied, and:

- `prismio aif --leaks` lists every static leak with its reason and the source span, before the
  program runs. Today the only way to find one is `--verify` and a run;
- the manifest counts them per function, as a cost;
- every fix to the leak residue is visible as a `leak` node turning into a `drop`, `delegate` or
  `settle`, which makes each fix's effect checkable without a run.

## 8 · The heap model and AIF over PIR

### 8.1 · Sites with contexts

Every `alloc` node is a site. A site's identity is **(node, lambda instance)**, where a lambda
instance is one specialisation context of its function (§10.2). The default is one instance per
function, which is today's context-insensitive site. A library producer (`concat`, a factory)
specialised per caller context has one site per instance, which is selective context sensitivity
with a budget, chosen deterministically.

### 8.2 · Objects, holders and field keys

The heap model has abstract objects (sites), and **holder edges** from the places that may hold
them: `o.f`, `o.elems`, a global, a task's result. A field key is **(object, field)**, not
(type, field), so `Bag.items` in one function does not change `Bag.items` in another unless the same
abstract object reaches both. That is object sensitivity at site granularity (heap cloning with
k = 1), which is the per-site field keys (`--theta-fields`) of the build list, with the IR to read
them.

### 8.3 · The lattices do not change

AIF's lattices (E, A, T, C, L) and the tier ladder stay as SPEC and INFERENCE define them. What
changes is where constraints come from:

- **flow sensitivity** comes from SSA: a fact attaches to a value, not to a binding name, so two
  bindings called `a` are two values, and a store affects only the versions after it;
- **per-call result questions become local**: "is this call's result held" (`callResultHeld`) is
  where the result's consumer is;
- **the oracle reads PIR text.** `tools/aif_oracle/aif.py` gets a reader for `--emit-pir` (§15), so
  the oracle stops mirroring an AST walk and checks the engine against the IR both of them see. The
  first step keeps the walk emitting the same constraints from PIR that it emits from the AST, so
  `tools/aif_differential.py` stays unchanged until the oracle reader lands.

## 9 · Facts

### 9.1 · One sparse engine, many domains

Today each loop pass walks the AST with its own notion of assignment and loop. On PIR they become
**domains** of one sparse solver over SSA values (SCCP's shape: a worklist of values, a transfer per
node, a join at merge ports, widening at loop ports):

| Domain | Replaces | Read where |
|---|---|---|
| interval × congruence (reduced product) | `ranges`, `strides`, `nowrap`'s interval walk, `param_ranges` | `nsw`, bounds checks, `range` attributes |
| difference bounds per loop (DBM over the loop's carried ports) | `relations`, `dbm` | bisection, `low <= mid <= high` |
| counted-loop facts | `counters` | read straight from a loop's carried port and its `next` argument |
| residues | `residues` | `%` replaced by a conditional add |
| array contents per lifetime | `contents` | element arithmetic that cannot wrap |
| reductions | `reductions` | `reassoc` on a reduction's adds |
| nonnull, dereferenceable, identity-free | scattered | LLVM attributes, scalar replacement (§6.4) |
| place disjointness | header/element alias scopes | `!alias.scope` / `!noalias` |
| implementor sets for `dyn` | not built | devirtualisation (lever 5) |
| lengths and capacities | not built | capacity inference (MEM-013) |

Induction variables are not discovered: a loop's carried ports and the arguments of its `next` exits
*are* the update equations. That is why `counters`, `residues` and the induction part of `ranges`
shrink to transfer functions.

### 9.2 · Refinements at branch arms

A branch arm refines the values its predicate tests: on entry to the arm where `i < n` holds, uses of
`i` see a `refine %i (< %n)` node (e-SSA, as ABCD uses π-nodes). The node is pure and lowers to
nothing. A bounds check is an explicit `check_index %v, %i` node on the spine, and the solver
discharges it or leaves it.

### 9.3 · Guarded facts and versioning

A fact that holds only under a run-time condition is a **guarded fact**. Loop versioning, which
`ranges` does today on the AST, is a structural rewrite: a loop becomes
`branch (guard) { loop with the guarded facts assumed } else { the loop as written }`. Tiling and
the flat-list guard are rewrites of the same kind. Because the guard is a node, its cost (paid per
loop entry, `prismio-guard-cost-is-per-entry`) is visible to the cost model.

### 9.4 · Provenance

Each fact can record the rule that produced it and the facts it rests on. With `--why` on, the solver
keeps that record, and `prismio aif --why` answers for any fact, not only a tier: why a bounds check
stayed, why an element parked, why a value leaked. Off by default, so it costs nothing in an
ordinary build. Every removed `check_index` and every `nsw` must cite a fact; the verifier checks
that the citation exists, which keeps "removed a check without a reason" from being silent.

## 10 · Effect signatures, specialisation and the allocation context

### 10.1 · The signature

Every lambda has one record that every caller reads, replacing `param_returns`, `fn_ret_partial`,
`fn_may_return_view_of_param`, the extern contract tables and the guards that re-derive them:

```
sig pick(a: borrow Cmd, b: borrow Cmd) -> view {a | b}
sig concat(a: borrow String, b: borrow String) -> own String fresh  alloc: ambient
sig push<T>(self: inout Vec<T>, x: sink T)  writes self.elems self.hdr
sig keepInto(i: copy Int, keep: inout Vec<Vec<String>>)  writes keep.elems keep.hdr  alloc: ambient
sig fatal(msg: borrow String) -> never
```

| Part | Values |
|---|---|
| per parameter | `borrow` · `inout` · `sink` · `retain_in(place)` (FFI's `retain_in`) · `capture(task)` |
| result | `copy` · `own fresh` · `own partial(path)` · `view {params, paths}` · `static` · `opaque` |
| place effects | the places read and written, by parameter path, plus globals and `world` |
| allocation | `none` · `ambient` (polymorphic over the caller's regime) · `heap` · `arena(param)` |
| control | `returns` · `may fail` · `never` |

Signatures are computed bottom-up over `group` nodes (call-graph SCCs) to a monotone fixed point, in
id order. An extern's signature is its FFI contract, with the build list's extern summary rule (a
scalar or void return needs no contract). A sealed function's signature is its published contract
(`aif/spec/PIR.md` §5.1). A `.plib` ships signatures as a **cache** over the bodies, never as
content: deleting them changes compile time only.

### 10.2 · Specialisation contexts

A lambda instance is a function compiled for one **context**: per parameter, its storage class and
uniqueness; for the result, its destination (a caller's frame slot, the caller's arena, the heap).
The default instance is `⊤` and is today's behaviour. Instances are created where a pass shows a
profit (a library producer whose sites would otherwise merge across callers; a struct parameter that
could arrive in registers; a result that could be written in place), under a per-function budget,
in deterministic order. This is INFERENCE §6–7's ownership-context specialisation, given a place to
live.

### 10.3 · The allocation context is a value

The ambient arena is dynamically scoped at run time (`rt_arena_hint_push`). In PIR it is explicit:
every lambda takes an implicit **allocation context** input, every `alloc` reads it, and an `arena`
region gives its body a new one. Call-site bracketing becomes dataflow: a callee's allocations are
served by the caller's arena when the context reaching every one of its calls is that arena. Two
lowerings are available for the same graph:

- **ambient** (today's): the context lowers to the thread-local hint, and a body that runs under two
  regimes needs the arena-aware `rt_free` (a `span` witness) to stay sound;
- **explicit** (MEM-012): a specialised instance takes the arena as a parameter, which is MLKit's
  region parameter, and its drops of arena memory are removed statically.

## 11 · Representation of values: types in PIR

PIR has its own interned type table, built from sema's `TypeInfo` when a function is built, so no
pass after the builder reads a punned `Ptr`. A PIR type is one of: integer and float widths, `Bool`,
`Ptr`, a struct (fields in declaration order), a payload enum (variants and payloads), `Vec<T>`,
`HashMap`, arrays `Array<T, N>`, slices, `String`, `T?`, a function type, a `dyn` object, a task
handle, a channel, and a remainder `T∖{paths}`. Types carry no sizes at PIR-H (decision 8).

## 12 · Two levels

### 12.1 · PIR-H

The level the builder produces and AIF, facts, elaboration and repair run on. It has handles and
places, abstract container operations (`push`, `set`, `remove`, `len`), abstract field access, views
as `(base, index)` or `(base, start, length)`, `alloc T` with no size, `drop` with no kind, and no
runtime function names. It is **target-neutral**: nothing in it depends on pointer width, field
offsets, or a representation choice.

### 12.2 · Lowering to PIR-L

One pass per concern, in order:

1. **storage**: `alloc` becomes `frame.slot`, `arena.alloc`, `heap.alloc(class)` or `rc.alloc`,
   from the storage class; `drop` becomes its kind; witnesses get their form;
2. **layout**: field order, hot/cold split and the AoS/SoA choice (`LAYOUT.md`) turn abstract field
   access into offsets, and element views into `(handle, index)` resolution;
3. **representation**: container operations become runtime entry points or inline sequences (inline
   elements, the fused small Vec, German strings, inline short strings), so a later change of
   representation is a change to this pass only;
4. **calling convention**: `inout` becomes an address, a fresh struct result with a frame destination
   becomes a caller-provided slot (MEM-009), an identity-free small struct becomes scalars (MEM-027).

PIR-L is still structured (regions, spine, exits), so the interpreter and verifier run on it too.

### 12.3 · Distribution

PIR-H is what `aif/spec/PIR.md` asks a sealed-library format to carry: bodies, not summaries;
contracts that survive; target neutrality; published contracts on sealed functions. Today a `.plib`
ships bitcode per target triple, which hides std's bodies from whole-program AIF. Shipping PIR-H
instead lets the consuming compiler analyse std as it analyses the program, and removes the per-triple
sections. This is P10 and needs its own encoding and versioning design.

### 12.4 · From PIR-L to LLVM

- a `branch` becomes blocks and a `phi` (or the stack slot `generateShortCircuit` joins through
  today);
- a `loop` becomes LLVM's canonical form: preheader, header, one latch, dedicated exits, so
  `LoopSimplify` has nothing to repair and the vectoriser sees what it expects;
- an exit becomes a branch to the target's block, through the blocks its drops and close actions
  occupy;
- every `frame` value's extent becomes `llvm.lifetime.start` / `end` (MEM-008);
- place disjointness becomes `!alias.scope` / `!noalias`; facts become `nsw`, `range`, `nonnull`,
  `dereferenceable`, `noundef`; reductions become `reassoc`; `exit fail` paths get cold branch
  weights;
- pure nodes are scheduled as §5 says.

## 13 · Tasks, scopes and futures

- `spawn f(x)` and a lifted `spawn {}` consume the owned values they capture; those values' T fact
  becomes Transferred. A task's arguments are its ports, at most three words today (F17 is a runtime
  limit, not a PIR one).
- A `taskscope` region's close action is `scope_end` on every exit, from §4.4, as `ir_region_enter`
  arranges it today.
- A task handle is a `counted` object. `join` reads its result field. When the handle is never
  copied (a fact), the handle is unique and `join` takes the result as `own`. When it is copied,
  the result is holder-owned by the task object (§7.6) and released with it. That closes `test_69`
  without making handles affine in the language.
- Futures are tasks that have not started (`ASYNC_PLAN.md` §2), so they need nothing new. If
  futures ever become state machines, the skeleton is what makes the split tractable: a `suspend`
  node on a spine, the owned values live across it (read off liveness) become the frame's fields,
  and dropping an unstarted future drops exactly those.

## 14 · The PIR interpreter

An abstract machine for both levels, in `src/pir/interp.psm`:

- **objects, not bytes**: every allocation is an object with a site, a storage class and a state
  (live, dropped, delegated, leaked). A drop poisons the object; any later read, write or drop of
  it stops the run with the value id and the AST span of both the use and the drop;
- **the leak list** at exit: every live object, grouped by site, the same table `--verify` prints,
  but with site identity (part of MEM-001) and without depending on the allocator;
- **builtins**: the string and container builtins are modelled in the interpreter; std's Prismio
  code (maps, sets, most of `std.string`) runs as PIR; an extern with no model makes the program
  ineligible, and the harness skips it.

What it is for:

1. **Testing the builder.** Every `tests/` program with an expected output that the interpreter can
   run is run, and its output compared. This tests PIR's semantics before any emission exists.
2. **A read-after-free detector that the slab cannot hide** (`RESEARCH_ROUND4.md` §1). It works on
   macOS and Linux alike and needs no sanitizer build.
3. **Translation validation by testing.** Run a function before and after a pass on the same
   inputs; the output and the leak list must agree, except where the pass is meant to fix a leak.
4. Later, a host for `const` evaluation (`src/sema/const_eval.psm`) and an oracle for `run --jit`.

## 15 · The text format

`--emit-pir` (and `--emit-pir=l` for PIR-L) writes a canonical dump: ids in builder order, one node
per line, regions indented, types and modes on every value, state versions on every place access,
sites on every allocation. It is a fixpoint across two generations, like the IR. Three of the
research probes, as PIR-H after elaboration:

**`return bag.items` from a local `Bag`** (`RESEARCH_BUILD_LIST.md` §2.2: 500 of 501 leaked today):

```
fn itemsOf(%i: copy Int) -> own Vec<String> {
  %v0   = vec.new<String>                          : own Vec<String>   site 12  heap
  %s1   = call toString(%i)                        : own String        site 13  heap
  %s2   = call concat("an-element-…", %s1)         : own String        site 14  heap
          drop %s1                                 ; last use: concat
          push %v0, %s2                            ; v0.elems s0→s1, v0.hdr s0→s1
  %l1   = call toString(%i)                        : own String        site 15  heap
  %l2   = call concat("a-label-…", %l1)            : own String        site 16  heap
          drop %l1
  %b    = struct.new Bag { label: %l2, items: %v0 }  : own Bag         site 17  frame
  %it, %rest = take %b.items                       : own Vec<String>, own Bag∖{items}
          drop %rest                               ; releases label; frame: lifetime.end
  exit @fn.return(%it)
}
```

**A temporary on the right of `or`**:

```
  %c = branch %a -> copy Bool {
    true:  exit @merge(true)
    false: %t = call sorted(%v)                    : own Vec<Int>      heap
           %x = get %t[0]                          : copy Int          ; t.elems s0
           %r = icmp gt %x, 3
           drop %t                                 ; A3: in this arm only
           exit @merge(%r)
  }
```

**One of two parameters returned** (`test_269`):

```
  %r = call pick(%best, %cand)                     : view {best | cand}
  %o = settle %r from {%best, %cand}               : own Cmd           ; eq witnesses
  ...                                              ; %best and %cand are consumed here
```

## 16 · Building it in Prismio

### 16.1 · Data structures

Flat columns indexed by `Int` ids, the shape the compiler already uses for its engine tables, with
no `Ptr` puns:

```prismio
struct PirFunc {
    // nodes
    op: Vec<U16>, flags: Vec<U16>, region: Vec<Int>, spine: Vec<Int>, ast: Vec<Int>, site: Vec<Int>,
    opStart: Vec<Int>, opCount: Vec<Int>,          // operands live in `operands`
    resStart: Vec<Int>, resCount: Vec<Int>,        // results live in `values`
    operands: Vec<Int>,
    // values
    valDef: Vec<Int>, valType: Vec<Int>, valMode: Vec<U8>, valStorage: Vec<Int>,
    // regions
    regKind: Vec<U8>, regParent: Vec<Int>, regSpineStart: Vec<Int>, regSpineLen: Vec<Int>,
    regPortsIn: Vec<Int>, regPortsOut: Vec<Int>,
    // places and state
    placeObject: Vec<Int>, placePath: Vec<Int>, stateOf: Vec<Int>, statePrev: Vec<Int>,
}
```

Def-use lists are built on demand, per pass, in compressed-row form, and dropped after. A whole
program keeps every function's PIR-H for AIF's fixed point (about 4,000 functions for the compiler
itself), and PIR-L is built and lowered one function at a time, then discarded.

### 16.2 · Determinism

- Node, value, region and place ids are assigned in builder order, which is source order.
- Passes iterate by id. A `HashMap` may intern (the pure graph, the type table) but is never
  iterated for output.
- Dumps are canonical. The two-generation fixpoint is read in the IR and in `--emit-pir`.
- Each lambda gets a structural hash of its canonical PIR-H. It keys signature caching (§10.1)
  and, later, incremental compilation.

### 16.3 · The verifier

`pir_verify` checks, after the builder and every pass: the region tree (an exit targets an ancestor
port with matching arguments); the spine (a total order consistent with state edges); A1–A9;
ports for owned values (§4.5); state chains (one write per version, every read pinned); level
legality (no PIR-L op at PIR-H); witness and `delegate` obligations; and fact citations (§9.4). A
failure is a compiler bug with the function's name and the node's span.

### 16.4 · Bootstrapping and compile time

PIR needs no new syntax, so no seed cut before `src/` can contain it. `src/pir/` must join every
source list `tools/check_source_lists.py` checks. The budget: AIF is about 1 s on the compiler's own
build; PIR's build, verification and passes get no more than that again. Everything is linear per
function except view ordering (§6.3, bounded by one function) and the fact solver's loops (bounded
by widening).

## 17 · The pass pipeline

```
build (per fn)  → verify
signatures      → fixed point over call-graph SCCs
AIF             → heap model, contexts, tiers, storage classes
facts           → sparse solver; refinements; guarded facts
specialise      → instances where profitable; re-run the three above on new instances
elaborate       → drops at last use; exit-edge drops; policies
view repair     → delay · transfer · park · materialise · raise · settle
witnesses       → choose forms; storage agreement or flag
reuse           → reset/reuse pairs
                   ── stage A: write the plan side table, stop here ──
lower           → storage · layout · representation · calling convention   (PIR-L)
verify          → level L
emit            → LLVM IR
```

## 18 · What the clusters of the research brief become

| Cluster (`RESEARCH_BRIEF.md` §5) | PIR mechanism | Section |
|---|---|---|
| A · context-insensitive sites | sites per lambda instance; selective specialisation | §8.1, §10.2 |
| B · per-type field keys | field keys per abstract object | §8.2 |
| C · views without lifetimes | view repair, most often a free delay | §7.4 |
| D · run-time-only facts | witnesses; `settle` | §7.5 |
| E · literal storage mixed with owned | `static` storage, `tag` witnesses; copies as owned (A9) | §7.1, §7.5 |
| F · the `rc:none` residue | holder-owned fields; explicit leaks make the rest countable | §7.6, §7.7 |
| G · no middle IR | this plan | all |
| H · concurrency | moves into tasks; holder-owned results; scope exits | §13 |
| I · allocator | the `span` witness is what makes the arena-aware `rt_free` usable by codegen | §7.5, §10.3 |
| J · representation | the representation pass at PIR-L; remainder types; scalar replacement | §6.4, §12.2 |
| K · observability | site identity in the interpreter's ledger; `--leaks`; provenance for every fact | §7.7, §9.4, §14 |

## 19 · The build list, on PIR

The build list lands first, on the AST (decided 2026-11-22). Each item has a PIR form that later
replaces its AST implementation and must reproduce its decisions byte for byte:

| Build list item | On the AST | On PIR |
|---|---|---|
| 2 · move at last use (F1, F14) | a liveness query and slot nulling | `take` at last use (A6), elaboration (§7.3) |
| 3 · owned by its counted holder | a disposition in the engine | `delegate` (§7.6) |
| 5 · a global slot is one owner | the column proof widened to globals | place ordering on the global's chain (§6.3) |
| storage agreement | raise frame sites | `mixed` with the choice of raise or `flag` (§7.5) |
| copies are owned allocations | a fact in the engine | `clone` nodes (A9) |
| extern summary rule | `contracts.psm` | extern signatures (§10.1) |
| 4 · teardown elision | skip `main`'s drops | the *elide at exit* policy (§7.3) |
| 9 · pass-through release, copy-on-escape | not built | `settle`, *materialise* (§7.4–7.5) |

## 20 · Migration

Each stage is behind `--pir=plan` or `--pir=emit`, off by default, turned on per function, and
turned on by default only when the whole suite is byte-identical except for measured fixes, each
with a fixture.

| Stage | Scope | Exit criterion | What it retires |
|---|---|---|---|
| **P0** | `src/pir/`: types, the node set, the builder for straight-line code and `branch` in leaf functions, `pir_verify`, `--emit-pir`, a coverage count (`--pir-coverage`: how many functions built) | the dump is a fixpoint across two generations; the verifier accepts every leaf function in `tests/` that sema accepts | nothing |
| **P1** | the interpreter (§14) for P0's subset | every eligible test's output matches; the interpreter's leak list matches `--verify`'s on the ownership probes | nothing; it is the gate for every later stage |
| **P2** | elaboration for P0's functions (A1–A3, A6), stage A plan | the first two §15 probes and `test_273` at 0 leaked; byte-identical elsewhere; the sanitizer gate clean | `irHoistBorrowedTemporaries`, `irFindBorrowedTemporary` for covered functions |
| **P3** | `match`, `and`/`or`, `??`, `expect`; exits for `return` | the `and`/`or` temporary, `test_205` and the binder probes at 0 | `nodeReturnsAliasBeyondBare`, `E_held`/`ret_key` in codegen |
| **P4** | loops; `break`, `continue`, labels | every loop in `tests/` builds and verifies | `ir_loop_drop_floor` for covered functions |
| **P5** | places, state chains, view repair (A7, §6, §7.4) | `test_317`–`321`, `test_388`, `test_389` give the same verdicts or better; delays measured on `graph_churn` peak RSS | `overwritesMark`, `semaRemovalVerdict`, `columnsMark` |
| **P6** | signatures for every function; witnesses; `delegate` | the whole compiler builds under `--pir=plan`; the IR fixpoint holds; `test_269` at 0 | `chainRetainsAliasOf`, `chainAssignsAliasOf`, `irValueAliasesName` |
| **P7** | AIF's constraints from PIR; the oracle reads `--emit-pir` | `tools/aif_differential.py` agrees on every default source | the AST walk in `src/aif/walk.psm` |
| **P8** | the fact engine, one domain at a time | each domain reproduces its AST pass's marks byte for byte before that pass is deleted | `ranges`, `relations`, `nowrap`, `counters`, `contents`, `residues`, `strides`, `reductions`, `tiling`, as each lands |
| **P9** | stage B: PIR-L and emission, node kind by node kind; then lifetime markers, alias scopes, result slots, specialisation, reuse | see §22: the gate for a change that is meant to change the IR | the AST statement emitters, as each node kind moves |
| **P10** | PIR-H in `.plib` (`aif/spec/PIR.md` §1–§5) | a library's bodies and contracts ship and are read back; std is analysed as source | per-triple bitcode sections |

**Before P0:** build item 0 (the sanitizer gate) and the small engine items. They make each stage's
checks trustworthy, and none depends on PIR. **Decided 2026-11-22, unchanged:** move at last use is
built on the AST first (item 2); its probes and fixtures become P2's acceptance tests.

The order puts the interpreter (P1) before any decision is taken from PIR, and AIF and the facts
(P7, P8) before emission (P9), because the leak and range wins come from the analyses and the plan
table, and emission's wins (lifetime markers, alias scopes, result slots) are measured separately.

## 21 · Alternatives considered and rejected

| Alternative | Why not |
|---|---|
| **A pure RVSDG** (the first plan) | Single-exit regions make an early `return` an enum threaded through every enclosing region (its §5 called this the hardest part). Order only through state edges makes stage A's source-ordered plan hard to key and needs a scheduler for determinism. PIR keeps the regions and replaces both with exits and a spine. |
| **A CFG in SSA** (LLVM, MIR's shape) | Throws away the structure that arenas, task scopes, loop facts and canonical loop lowering need, then rediscovers it with dominators and loop analysis. Drop elaboration on a CFG needs iterative dataflow and drop flags; on a region tree it is a backward pass. |
| **A full sea of nodes** | Every node floating means every effect is chained and everything must be scheduled; the cost V8 reported. PIR floats only pure nodes. |
| **MLIR** | Decided against: a C++ dependency in a self-hosted Prismio compiler, and a dialect stack Prismio would mostly not use. The idea taken from it is progressive lowering, as two levels. |
| **Equality saturation / e-graphs** | LLVM already does the algebra. The one place a choice among equivalent forms matters to Prismio (layout and representation) is a cost-model search over a handful of candidates (`LAYOUT.md`), not saturation. |
| **A Datalog engine** for facts | The fact store is relational and Polonius-shaped, but a hand-written sparse solver is deterministic, has no dependency, and meets the compile-time budget. |
| **A borrow checker** | Prismio's model is to never reject a view (SPEC §8.4). PIR's view rule decides a repair, not an error. |
| **Drop flags everywhere** (Rust MIR) | In affine SSA a value is consumed on a path or not, so locals never need a flag. A flag is one of five witness forms, used only where the value really is decided at run time. |

## 22 · Open questions for the maintainer

1. **The gate for stage B.** CLAUDE.md requires byte-identical output for a behaviour-preserving
   change. Emitting from PIR changes temporaries' names and order even where it changes nothing
   else, so per-node-kind byte identity (the first plan's gate) is probably unreachable. A proposal:
   stage B is a *measured change*, gated by the suite, the sanitizer gate, the interpreter agreeing,
   benchmarks within noise, a mnemonic diff of `-O3` output on the benchmark arms, and then a new
   fixpoint; byte identity applies again among PIR-emitted functions afterwards.
2. **Does sema's move checker move to PIR?** It would give non-lexical diagnostics ("moved here, used
   there, on this path") and delete a second ownership walk. It also makes PIR a source of user
   errors, which this plan avoids until P6.
3. **Whole-program PIR-H in memory.** About 4,000 functions for the compiler; the column layout
   should keep it small, but it has to be measured at P0 (MEM-017, phase time and RSS).
4. **Generic bodies for distribution.** P10 needs PIR-H with type parameters, or std's generic
   templates shipped as source beside it. Today monomorphisation happens in sema.
5. **The interpreter's builtin coverage.** Which runtime builtins it models decides how many tests
   it can run. Measure at P1 and list the externs that make tests ineligible.
6. **Witness budget.** Which witnesses are allowed by default (`tag` and `eq` are cheap; a carried
   `flag` costs a register in a hot loop), and whether the manifest's budget rule (SPEC §9) counts
   them.

## 23 · Prior art to read before P0

From memory, not re-checked this session:

- Reissmann et al., *RVSDG: An Intermediate Representation for Optimizing Compilers*, ACM TECS 2020,
  and the jlm compiler.
- Maurer, Downen, Ariola and Peyton Jones, *Compiling without Continuations*, PLDI 2017 (join points);
  Lean 4's IR (`jp`, borrowed parameters, reset/reuse).
- Swift SIL in OSSA form (ownership on SSA values; `begin_borrow` / `end_borrow`; `@guaranteed`).
- Rust MIR: drop elaboration, drop flags; NLL and Polonius (borrows as Datalog relations).
- Reinking, Xie, de Moura and Leijen, *Perceus: Garbage Free Reference Counting with Reuse*, PLDI 2021.
- Tofte and Talpin's region inference; Birkedal, Tofte and Vejlstrup, POPL 1996 (storage modes); the
  MLKit retrospective.
- Hylo (formerly Val): mutable value semantics, `inout` as a value.
- LLVM's MemorySSA; Wegman and Zadeck's SCCP; Bodik, Gupta and Sarkar's ABCD (PLDI 2000);
  Granger's congruences (1989); Miné's octagons.
- Cranelift's aegraphs (Chris Fallin, 2022–2023): a side-effect skeleton with floating pure nodes.
- V8's move from Turbofan's sea of nodes to Turboshaft.

## 24 · Relation to the other plans

- `docs/MEMORY_PLAN.md` §2.3: PIR is MEM-004; signatures are MEM-005; stage B carries MEM-007,
  MEM-008, MEM-009 and MEM-027; the explicit allocation context is MEM-012; capacity facts are
  MEM-013; the interpreter's ledger is part of MEM-001.
- `docs/aif/RESEARCH_BUILD_LIST.md`: its items land first, on the AST; §19 says what each becomes.
- `docs/STRUCTURAL_LEVERS_PLAN.md`: lever 5 (devirtualisation) gets implementor-set facts; lever 3
  (compressed references) is a representation choice at PIR-L; teardown elision and release at last
  use are elaboration policies.
- `docs/ASYNC_PLAN.md`: §13.
- `docs/aif/spec/PIR.md`: the distribution half, P10.
