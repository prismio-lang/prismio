# The integer-print leak, and g6's arena

Session of **2026-08-28**, second half. Compiler `build/S25b` → `build/S26b`.
Entry gate: suite 140/140, fixpoint `a25.ll == b25.ll`.
Exit gate: suite **140/140**, fixpoint `a26.ll == b26.ll`, seed path matches, differential 17/17,
corpus median **0.994×**, **GATE PASSED**.

Two items the first half of the session left behind, taken in order.

---

## 1. Every program that printed a number leaked

`println(12345)` under `--verify`: **5 allocated, 0 released, 5 leaked.** On `g2.psm` that was
~80 000 leaked digit strings and the reason its `--verify` verdict had never been anything but
FAILED.

### Where it was

`prismio_std_io_unsigned_integer` built its result by concatenating in a loop:

```prismio
let mut text = ""
while (remaining > 0) {
    text = str_concat(prismio_std_io_decimal_digit(digit), text)   // N-1 of these leak
    remaining = remaining / 10
}
return text                                                        // and so does this one
```

Two distinct leaks, and they need different fixes:

* **The intermediates.** An assignment releases nothing, and a reassigned binding is deliberately
  never droppable — the note over `ir_mark_droppable` says so and says why ("that leaks rather than
  double-frees"). Flow-insensitively, all N concats are one site whose escape is `Caller`, so no
  arena and no drop reaches them.
* **The result.** A `String` returned across a call had **no owner at all**.
  `aif_owns_call_result_at_node` transfers ownership of a returned `List` or owning struct and
  declined everything else, on an argument its own comment gives: the completeness of the returned
  value set rests on the type having no literal form, and a `String` has one. `return "0"`
  contributes no site and is invisible.

### What landed

**`fn_returns_partial`** (`runtime/aif_support.c`) derives the missing fact from the returns
themselves. Every `return <expr>` binds the RET key, and a bind whose value set resolves to **no
site at all** — a literal, a borrowed parameter, an `Int` — is a path this pass cannot account for.
One such return makes the function partial and its result unowned. Read off the constraints, so
there is no second record to keep in step, and no frontend change at all.

With the fact, `aif_owns_call_result_at_node` accepts a plain object. `std/io.psm` then has to
satisfy it, which took two changes and neither is cosmetic:

* **`prismio_std_io_unsigned_integer` is recursive and always allocates.** Recursion gives each
  intermediate its own `let`, which the drop analysis can see; `str_concat(digit, "")` in the base
  case rather than the digit itself is what keeps the function from ever returning a literal. The
  C runtime has carried the same rule since values became affine — `str_substring`'s comment:
  *anything declared to return String hands back something a release can take.*
* **`prismio_std_io_signed_integer` returns a concat on both paths.**
  `return prismio_std_io_unsigned_integer(...)` is a **pass-through**, and a pass-through is
  declined: from the call site a value made below is indistinguishable from one handed *down*, and
  freeing the second is a double free. One concat makes the returned string this function's own
  allocation. It costs one small allocation per formatted number.

And the 20 `print`/`println` overloads bind the result instead of nesting it in the call — an owned
value nothing names is a value nothing frees.

### Measured

| `--verify` | S25b | S26b |
|---|---|---|
| `println(12345)` | 5 alloc, **0 released, 5 leaked** | 6 alloc, **6 released, 0 leaked** |
| g1 | 4016 / 4011 / **5 leaked** | 4016 / 4016 / **0** |
| g2 (benchmarked) | ~10.28 M / 10 202 025 / **~83 000 leaked** | 102 066 / 102 066 / **0** |
| g4 | 9067 / 9056 / **11 leaked** | 9067 / 9067 / **0** |
| g5 | 4108 / 4092 / **16 leaked** | 4108 / 4108 / **0** |
| g6 | 50 470 / 50 456 / **14 leaked** | 3265 / 3265 / **0** |
| g3 | 5486 / 1376 / 4110 leaked | 5486 / 1391 / **4095** |

0 violations throughout. **Six of the seven now have a completely clean ledger**; g3's remaining
4095 is the pre-existing struct-field residue `elem_disposition_of`'s comment names (1365 Nodes,
three owned fields each) and is untouched by this.

**Peak RSS fell across the whole corpus**: 2.25→1.78, 3.47→1.94, 2.84→2.08, 2.84→2.05, 1.98→1.63,
4.55→2.23 MB — **0.49×–0.82×**. That is the direction the standing "peak RSS reversed" candidate
wanted; the ×-against-Rust figure in `RESULTS-final.md` needs its own harness to restate and has
not been re-run.

`tests/test_runner.py`'s `aif_verify` expectations went 1→0, 1→0 and 3→2, which its own docstring
had promised in advance: *"each one is a T2 value returned to a caller... when that lands these
numbers go to zero and this test says so."* What is left is `test_47`'s 6 — a value returned **two**
hops, which needs INFERENCE §6's contexts.

---

## 2. g6 was not blocked on the obligation the notes said it was

`SESSION-PROMPT.md` and `TODO.md` both recorded g6 as blocked on **obligation 2** (`br-param=4`).
`--why` on the site that matters says otherwise:

```
plan_orders__Struct_World_Struct_Squad#1
    bracketing (SPEC 5.2.1.1) -- may a caller's region reach this function?
      no   -- the obligations hold, but the body has 2 call sites
```

`br-param` is real and it is about `recruit`, which allocates the squad roster — genuinely
long-lived, and declining it is correct. The transient allocator, `plan_orders`, clears every
allocation obligation. Three things blocked it, and all three had to go.

### 2a. Regime (a) asked the wrong question

SPEC 5.2.1.1's table gives the requirement as *"one body, one placement regime"* and *"exactly one
call site"* as the way to get it. The second is a **sufficient** condition for the first, not a
necessary one: a body every one of whose call sites is bracketed into the same region is also only
ever entered with that arena innermost. `plan_orders` is called once per squad from the same loop
body.

Split into two blockers. `SHARED_BODY` keeps the region-independent half; the new `MULTI_CALL` is
the half that depends on where the region is, and `bracket_regime_ok` answers it per region —
every call in the region's own function, lexically inside it, with no nearer arena between, and
inside the emitted statement range. **It reads `scopes[].arena`, so it is a filter the callers of
`bracket_edge_ok` apply rather than a clause inside it**; the obligations stay one-way, as M3.1 left
them.

### 2b. Shared-body bit on bodies that allocate nothing

`plan_orders` reaches `world_actor` and `world_transform`, two accessors that do nothing but
`list_get`, and `resolve_combat` calls `world_actor` too — so the extent read as shared on a pair of
getters. A body with no allocation anywhere below it compiles identically inside and outside a
bracket, so sharing it decides no regime. `fn_allocs_reach` is the test, and it is **transitive**:
a site-free function that calls an allocating one *is* changed, one hop down.

### 2c. Every `List` in the program shared one element node

The `@elem` field key was interned on the container's **base** type, so `list_get(w.actors, i)`
came back holding `Order`s that only ever went into a different list, and obligation 3 refused the
bracket because a function outside the extent appeared to hold one. `AIF_BRACKET_TRACE` said
`bound in 38` — a raw index, which is why it now prints the name.

Keyed on the full type instead. Sound because a container's static type is the same at every
mention: Prismio has no subtyping and monomorphises generics into concrete types before this walk
(`src/sema/generics.psm`), so `List<T>` never reaches it. **The exception is a spelling the frontend
could not resolve** — a bare `List`, or `List<Invalid>` — and `elem_key_reconcile` binds every key
of such a base together, restoring exactly the previous behaviour for it. Verified in both
directions: silent on `g6`, on `src/main.psm` and on a resolved two-list fixture, and firing on
`let xs = list_new()` with no annotation.

### Measured

| | S25b | S26b |
|---|---|---|
| bracketed call sites | 0 | **2** (one per `plan_orders` call) |
| arena-served sites | 0 | **4** |
| emitted extent | — | statements **[0,3]** of the tick body, excluding `world_step` and `resolve_combat` |
| allocations | 50 470 | **3265** (15×) |
| `--verify` | 50 456 released, 14 leaked | **3265 released, 0 leaked, 0 violations** |
| wall clock | — | **0.599×** |
| vs idiomatic Rust | 4.31× | **2.58×** |
| peak RSS | 4.55 MB | **2.23 MB** (0.49×) |

Checksums identical: alive 400, orders 46000, kills 400.

---

## 3. The corpus

`python3 tools/milestone_bench.py --old build/S25b --new build/S26b --runs 9`, interleaved,
checksums agreed across 5 variants for every program:

| | new/old | RSS | vs idiomatic Rust |
|---|---|---|---|
| g1 | 1.020× | 0.792× | 1.25× → 1.27× |
| g2 | 0.989× | 0.559× | 2.62× → 2.59× |
| g3 | 0.980× | 0.731× | 1.11× → 1.09× |
| g4 | 1.050× | 0.720× | 3.08× → 3.23× |
| g5 | 0.998× | 0.819× | 2.70× → 2.70× |
| **g6** | **0.599×** | **0.491×** | **4.31× → 2.58×** |

**corpus median 0.994×, range 0.599–1.050×. GATE PASSED.** g4's 1.050× is inside the 10% tolerance
and is the only program that moved the wrong way; it is worth a look before it moves further.

---

## 4. Four tests changed meaning, and why that is the system working

Generalising regime (a) broke exactly the five checks that assert it, which is what they are for.
None was deleted; each was repointed at the rule that replaced it.

* **`test_58_region_serves.psm`** gains a fifth function. `shared_body_in_one_region` is the
  newly-legal case — two calls, both inside one region, **51 served** — and
  `shared_body_serves_nothing` becomes the limit: one call **outside** every region, 0 served.
  The outside call's result is **discarded**, and that is load-bearing. Bind it instead and
  obligation 3 rejects too, because the points-to graph is context-insensitive and the binding then
  holds the loop's sites as well — the fixture would pass whichever of the two clauses was deleted,
  which is the defect this suite produces most. The original fixture's own header said the call
  count was the only thing separating it from the legal case.
* **`test_63_placement_pin.psm`** moves its MUTATION-POINT outside the region and gains a second
  call inside it, so the positive half now covers the generalised rule and the mutation still
  removes the placement.
* **`neg_26_placement_pin_refuted.psm`** moves its second call outside the region, discarded, for
  the same reason.
* **`region_diagnostics`** and **`bracket_summary`** follow the fixture: `shared_work` moved from
  the inert side to the serving side, `outside_work` took its place, and the bracketed-call count
  on test_58 is 3 rather than 1.

The **oracle** (`aif/prototype/aif.py`) was updated in step and the differential now compares
`br-multicall` as well — two implementations sharing no code agree on all 17 sources, which is the
only check that the new blocker means the same thing in both.

---

---

## 5. The three items this session left open, taken in the same sitting

Compiler `build/S26b` → `build/S27b`. Suite **140/140**, fixpoint `a27.ll == b27.ll`, seed path
matches, differential 17/17, corpus median **1.003×**, **GATE PASSED**.

### 5.1 g3's 4095 — and the recorded cause was wrong

The note said "struct fields leaked through a container teardown that frees the object and not its
fields". The teardown is fine. `Node`'s three struct fields are **inline** — `Transform` and
`Bounds` are POD, so the layout copies them into the object's own storage — and the leak is the
value that was copied *from*:

```prismio
let mut t = identity_transform()     // heap Transform, copied into `local`, then abandoned
return Node { local: t, world: identity_transform(), bounds: unit_bounds(), ... }
```

1365 × 3 = 4095, to the allocation.

**Underneath it was a disagreement, not a gap.** `field_release_of` reported an inline field as a
*released* field — its points-to set is non-empty and the disposition of what it holds is not NONE
— while `generateReleaseFn` emitted no release for it, because the address is interior. Both
answers are individually defensible and together they lose the value: the analysis's answer is also
what `site_in_released_field` reads, so reporting the field as owner is what stopped
`aif_owns_call_result_at_node` from letting the *caller* own it.

Fixed on the analysis side, from the layout's own definition. `aif_struct_field_inline` records the
flag; `field_release_of` returns NONE for an inline field; the walk computes it with
`aifFieldIsInlineExact`, which asks `typeAnnIsPodIn(..., byDecl = true)`.

**`byDecl` is the load-bearing part.** `typeAnnIsPod` decides whether to recurse into a struct by
asking the struct *registry*, which codegen fills and which is **empty during the analysis** — so
mid-analysis it stops recursing and calls a non-POD struct POD. For the split veto that
over-approximation is deliberate and safe (`aifFieldIsInlineStruct` documents the corpus failure
that established it). For ownership it is the **unsafe** direction: a field wrongly read as inline
is a field reported to own nothing, and the caller then frees a value the field still points at. So
the ownership reading recurses through `findStructDeclNamed` — the AST the registry is built from.

And the value with no binding to hang a drop on is freed at the literal: `generateStructLiteralFields`
asks `aif_owns_call_result_at_node` after the copy.

| g3 `--verify` | S25b | S26b | S27b |
|---|---|---|---|
| allocated | 5486 | 5486 | 5486 |
| released | 1376 | 1391 | **5486** |
| leaked | 4110 | 4095 | **0** |
| violations | 0 | 0 | 0 |

Checksums unchanged (nodes 1365, visited 1365, visible 1365). **All seven benchmark programs now
have a completely clean ledger.**

The IR diff is three files — g3's two copies and `src/main.ll` — and in g3 it is three `free`s added
in `make_node`, `__aif_release_Node` gone (a `Node` owns nothing, so there is nothing for the
wrapper to do) and the list's element disposition moving from TYPED to OBJECT.

### 5.2 `test_47`'s 6 — correctly deferred, and now for a better reason

`forwards(n)` is `let items = build(n); return items`. The returned site belongs to `build`, so
`aif_owns_call_result_at_node`'s `sites[s].fn != c->fn` declines and ownership survives exactly one
hop.

The obvious relaxation is "the site's function is reachable from the callee" — which distinguishes
`forwards` (allocated below) from `identity` (handed down from above). **It is not safe in this
compiler**, and the reason is sharper than "needs contexts":

The relaxation leans entirely on `in_container` and `site_in_released_field` to catch a value that
is *also* stored somewhere outliving the call. `site_in_released_field` has a known hole, recorded
at `field_release_of`: this compiler puns an `ASTNode` pointer as `String`, so a `String` field can
receive struct sites, the declared-type test declines, and the field is not reported as released.
`src/` is full of node pointers returned through helpers and stored into `.next` and `.child1`. A
widened rule would hand those to the deallocator.

So it stays one hop until INFERENCE §6's contexts put the site where the value dies. Six
allocations in one fixture against a use-after-free in the compiler is not a trade worth taking, and
that is the entry this line should have carried the first time.

### 5.3 g4's 1.050× — measurement, not regression

At `--runs 9` g4 read 1.050×; at `--runs 15` it reads 1.022×, with the arms' ranges overlapping
(old 64.1–69.0 ms, new 66.8–71.6 ms). The attribution settles it: comparing g4's IR before and
after, **22 functions changed and every one of them is in `std/io`** — `print`/`println` and the two
integer formatters. Not one function of g4's own compiles differently, and the four print calls it
makes are outside the timed loop. The same check on g1, which read 1.048× on the final run, gives
the same answer: 22 changed, 0 outside `std/io`.

The noise band on this corpus is about ±5%, which is what `milestone_bench`'s own default tolerance
says. Two programs sitting at 1.02–1.05× with byte-identical loop code is that band, not a
finding.

---

## 6. What is still open

* **`test_47`'s 6.** Deferred with the reasoning in §5.2 — it needs contexts, and the guards that
  would substitute for them have a hole this compiler exercises.
* **`test_45`'s 2.** A binding reborrowed into a callee's local name (E-BIND cannot name a scope
  inside a callee) and a field a reassignment guard deliberately protects. Both documented in
  `run_aif_verify_test`.
* **`recruit`'s obligation 2** (`br-param`) is untouched and declining it is correct — the squad
  roster outlives the tick.
