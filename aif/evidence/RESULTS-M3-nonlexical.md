# M3.2c-ii + M3.2d — an arena that opens and closes between statements

Session of **2026-08-28**. Compiler `build/S24b` → `build/S25b`.
Entry gate: suite 139/139, fixpoint `a24.ll == b24.ll`.
Exit gate: suite **140/140**, fixpoint `a25.ll == b25.ll`, corpus median **0.991×**, **GATE PASSED**.

**M3's exit gate is green.** Plain `g2.psm` — no annotation, no source change, the same file every
prior g2 number was measured on — now serves arena objects and runs at **0.469×** of its own
previous time.

---

## 0. The two halves, and why neither ships alone

**c-ii** is the statement range of a *candidate* arena, computed inside the obligation check before
the accept/reject decision. **d** is codegen emitting that range: `generateBlock` walks
`block.child1` with an index and opens the arena at `first`, closes it after `last`.

c-i (landed the session before) answers "how narrow can this arena be", which needs an arena to
already exist. The benchmarked `g2.psm` has none — M3.1 rejects it on the two
`clock_gettime_nsec_np` calls in its frame loop, *before* any range is computed — so c-i can never
fire there. That was the whole of the confusion in the earlier note.

Landing c-ii without d would narrow the obligation while codegen still bracketed the whole block,
putting the opaque calls **inside** the arena: the exact hazard the obligation exists to catch.

## 1. The circularity, cut the same way M3.1 cut it

The range depends on which sites are served, which depends on acceptance, which depends on the
range. `cand_stmt_range` breaks it by drawing its served set only from the call graph, the
points-to graph and scope shape — **nothing it reads is `scopes[].arena`**:

* the **lexical** half is `arena_would_serve` minus its one clause that reads a placement ("a
  nearer arena claimed it"), which can only ever *remove* a site;
* the **bracketed** half is every call in the scope belonging to its owner, filtered by
  `bracket_edge_ok_at(..., ask_opaque = 0)` — the obligations that mention no statement — and by
  whether the edge's extent contains anything the arena could take at all.

The set is therefore a **superset** of what c-i computes once the decision is made. A superset can
only widen the range or force "whole block", never narrow it, so an opaque call outside the
candidate range is outside the range codegen emits. `arena_emit_range` picks c-i's tighter answer
when it lies inside c-ii's and falls back to c-ii's otherwise — never to the whole block, which is
the one answer the obligation was not asked about.

`stmt_range_over` is the half both share: which keys count as holding the value, which may be
skipped (a key in another function — `region_confined` already proved those activations are gone),
and which force "whole block". A second copy of that would be a second answer to a question codegen
and the obligation check have to agree on.

## 2. `g2.psm`, unannotated

`AIF_STMT_TRACE=1`, frame-loop body scope 92, against its statements
`0: t0=clock`, `1: cmds=cull`, `2: drawn=submit`, `3: t1=clock`:

```
aif: arena scope 92 extent [1,2] (auto)
aif: arena scope 92 emit [1,2]
aif: candidate scope 92 extent [1,2] (placed)
```

Both clock calls fall outside. The emitted IR is the hand-placement `g2_region.psm` writes:

```llvm
  %16 = call i32 @clock_gettime_nsec_np(i32 4)
  call void @arena_push()
  %18 = call ptr @cull__List_Struct_Renderable_Float_Float(...)
  %20 = call i32 @submit__List_Struct_DrawCmd(ptr %19)
  call void @arena_pop()
  %21 = call i32 @clock_gettime_nsec_np(i32 4)
```

| | S24b | S25b |
|---|---|---|
| arena-served sites | 2 (both in `std/io`) | **4** — `cull`'s list and its `DrawCmd` |
| peak arena (est.) | 0 bytes | 384 bytes |
| heap allocations (`--verify`) | 10 285 886 | **82 052** (125×) |
| `released` | 10 202 025 | 2 025 |
| `violation(s)` | 0 | 0 |
| frame time, median of 20 000 | 5 250 ns | **2 416 ns** |
| frame time, p99 | 12 042 ns | **2 917 ns** |
| checksums | `10020000 / 9980000` | identical |

`allocated` and `leaked` are run-to-run noisy on this program — S24b reported 10 285 886 /
10 284 474 / 10 282 184 across three runs — so `released` and `violations` are the columns to read.
The `--verify` verdict is `FAILED` on **both** arms for a reason that predates this work: the
printing loop leaks ~80 000 digit strings from `int_to_str`, unchanged in kind and count by
anything here.

## 3. The corpus

`python3 tools/milestone_bench.py --old build/S24b --new build/S25b --runs 9`, interleaved,
checksums agreed across 5 variants for every program:

| | new/old | vs idiomatic Rust |
|---|---|---|
| g1 | 0.979× | 1.40× → 1.37× |
| **g2** | **0.469×** | **5.77× → 2.70×** |
| g3 | 1.041× | 1.09× → 1.13× |
| g4 | 0.989× | 3.16× → 3.12× |
| g5 | 0.994× | 2.56× → 2.54× |
| g6 | 1.003× | 3.96× → 3.97× |

**corpus median 0.991×, range 0.469–1.041×. GATE PASSED.** RSS 0.971–1.008×; executable sizes
unmoved. Bracketed call sites across `aif/corpus` and `aif/evidence`: **6 → 12**.

This is the first session in eight where the corpus band moved, and it moved on one program.

## 4. What the IR diff is, all of it

20 files differ against the S24b snapshot; `src/main.ll` and `test_71` are expected. Every one of
the other 18 is `arena_push`/`arena_pop` moving inward, plus the allocations that follow from a
placement that did not exist before. Two examples of the shape:

* `test_09_strings` — the push moves past two statements that bind string literals, and the pop
  moves *before* the closing `println` rather than after it.
* `g7` — the push moves out of one basic block and into the one that actually allocates.

`test_44_aif_region.psm`'s `arena_regions` went **20 → 11** and the expectation was updated. The
nine that went are `check`'s own: the cost model gave its body an arena because its *failure* path
builds two strings, and a lexical bracket pushed and popped that arena once per call whether the
check failed or not. The extent now opens past the `if (got == want) { return 0 }`, so a passing
check pushes nothing. The eleven from `region` statements did not move — **M3.2d does not narrow a
written region**, by SPEC 5.2 and by an explicit clause in `arena_emit_range`.

## 5. The guard, which was not one

`tests/test_71_nonlexical_extent.psm` was written before the feature, and against this compiler it
**placed no arena at all** — five shapes sharing one `build`/`consume` pair made every callee
`br-shared` under SPEC 5.2.1's regime (a). Its baseline of 79/79/0/0 was a measurement of a program
the feature never touched, and all five assertions passed vacuously.

Two constraints had to be measured before it could be rewritten, and both were found by running the
compiler rather than by reading it:

1. **Regime (a) needs exactly one call site per bracketed callee**, so each shape needs its own
   builder. Nine of them.
2. **Any `list_get` outside the extent un-brackets every other shape.** The points-to graph does
   not separate element sets by list, so one shared `consume` — even an *unused* one, even one
   typed on a different struct — aliases every element site in the program. Adding a single unused
   `consume(cmds: List<Cmd>)` drops the placement from nine arenas to none;
   `AIF_BRACKET_TRACE=1` names the site and the binding. The shapes therefore consume through
   `list_len`, which reads the list handle and creates no key.

The rewritten fixture places **12** arenas with non-trivial extents and covers: statements on both
sides of the extent, `continue` after it, `break` inside it, `return` from the middle of it, and
`return` *as* its last statement, plus two nesting levels. Loops run 80 times, above
`ARENA_MAX_DEPTH` (64), so a pop lost on a per-iteration path aborts rather than passing; every
early-exit shape holds a list in an *outer* arena so a doubled pop lands on something real.

`AIF_BRACKET_TRACE` now arms in `bracket_prepare` rather than in `bracket_place`, because the pass
that *decides* is the candidate pass and a trace that starts after the decision cannot say why a
scope was never a candidate.

### Verified discriminating, by mutating the compiler and rebuilding it

| mutation | result |
|---|---|
| close at `rangeLast` emits no `ir_region_end` | `internal error: regions nested more than 64 deep`, exit 1, on `straight_line` |
| close emits no `ir_region_exit`, so the compile-time depth stays one too high and every later exit over-pops | four of five shapes fail; `held` reads back 2 instead of 6 |
| close drops its `ir_has_returned()` guard | **byte-identical IR** — the extra `arena_pop` would be emitted after a terminator and the backend drops it. The clause is inert; it is kept because the lexical close carries the same guard and a reader comparing them should not have to work that out |

The third row is recorded because it is a negative result about the code that shipped, and a later
session deleting that clause on the grounds that nothing covers it should find this line first.

`run_nonlexical_extent_test` reads the extents out of `AIF_STMT_TRACE` **before** it believes any
value, so a fixture that stops being bracketed fails rather than passing quietly — which is the
failure this section is about.

## 6. What did not change, and is worth knowing

* **A written `region` keeps its lexical extent.** SPEC 5.2 says it is pushed on entry and popped
  on every exit; narrowing it would make the manifest's account of which block owns a value
  disagree with the source. A programmer wanting a tighter one writes a nested `region`.
* **Every uncertainty is still the whole block.** A call or an allocation in a nested block, a
  binding with no use on record, a bracket whose call this pass cannot position — each returns
  "no range". A too-wide range is the arena that was already emitted; a too-narrow one frees memory
  the program is still using.
* **`key_last_stmt` is still not total** (it declines when `var_scope` is unsettled), and a missing
  last use still falls back to the lexical extent. `stmt_range_over` returns 0 on it.
* **g6 is still blocked by obligation 2** (`br_param=4`, its callees store into parameters), and
  nothing here touches that.
