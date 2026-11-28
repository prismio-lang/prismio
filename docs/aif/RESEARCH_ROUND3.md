# AIF research, round 3: regions, externs and the guard surface

Written 2026-11-22. It covers prompts 7 (regions), 5 and 8 (briefly) and 6 (the middle IR) of
`RESEARCH_BRIEF.md`, and continues `RESEARCH_BUILD_LIST.md`, whose ranking §5 below extends.
**Nothing is built.** The numbers come from the release host at `5757802`. Every probe is inline.

## 1 · `test_58`'s leak is not about regions: a binding that mixes stack and heap

`test_58_region_serves` leaks 100 of 101 blocks. Its harness entry blames values that escape their
region. Taking the region away does not change the result:

```prismio
struct Cmd { id: Int, weight: Int }
fn make_out(i: Int) -> Cmd { return Cmd { id: i, weight: i * 2 } }
fn main() -> Int {
    let mut keep = Cmd { id: 0, weight: 0 }      // a T0 stack site
    for i in 0..<50 { keep = make_out(i) }      // T2 heap sites, from the callee
    return keep.id - 49
}
```

| Variant | `--verify` |
|---|---|
| as written, with or without a `region` around the loop | 50 allocated, 0 released, **50 leaked** |
| `let mut keep = make_out(0)` (every value from the heap) | 51 / 51 / 0 |
| the same shape with `String`s, starting from a literal | 51 / 51 / 0 |
| conditional reassignment (`if (i % 7 == 0) { keep = make_out(i) }`) | 8 / 0 / 8 |

A binding whose sites mix a stack (T0) struct and heap structs releases **neither**: not the
displaced values, and not the last one. Codegen cannot release a stack slot, and it does not know
which kind the binding holds at a given moment. `let mut best = Point { … }; … best = f(…)` is the
natural way to write a running best or a state variable, so this is common.

**Fix: storage agreement.** When a binding key or a field key holds both T0 sites and heap sites,
raise the T0 sites' escape so they are placed on the heap as well. Raising escape is always sound
(SPEC §4.3, monotonicity). The cost is one allocation for the initial value. KNOWN_ISSUES
already records this as the sound fix for the frame-site payload enum ("raise the escape of a
frame site stored into a field that heap sites also fill"), and `test_171`'s single leak is the
field version. **One rule covers all three.** It is an engine rule, so the oracle needs the same
rule, and the probe above becomes its fixture.

## 2 · Most externs make every caller unbracketable

`aifCallIsSummarised` (`src/aif/contracts.psm:288`) treats an extern as opaque unless it has a
**return** contract *and* a contract on every parameter. A void or scalar return has no contract
word to declare (`alias` and `produce` are for pointers). An `Int` parameter can be annotated
`borrow`, but that changes nothing, because the return check fails first. An opaque call makes its
caller, and everything that transitively calls it, unbracketable (`br-opaque`).

The probe: a 50-iteration loop inside `region work { … }` calls `make(i)`, which returns a struct.

| What `make` does first | Arena allocations served |
|---|---:|
| nothing | **50** |
| `let k = labs(i)` (libc, `extern fn labs(x: Int) -> Int`) | **0** |
| the same, declared `labs(x: Int borrow)` | 0 |
| `srand(i)` (void), with or without `borrow` | 0 |

Of the 86 distinct std externs, **63 have no return contract** (14 void, 49 with a scalar or other
return). Some of these the runtime and builtin tables in `contracts.psm` summarise anyway; the rest
make every program that reaches them pay. The language server reports `br-opaque` on 363 of its
590 functions. That count overlaps with the other reasons, so it is an upper bound on what this
fix unlocks.

**Fix.** A void or scalar return needs no contract, and a scalar parameter (not `Ptr`) needs no
contract either. A scalar carries no ownership. An address passed as a `Usize` falls under
`std.raw`'s rule: the extern's author promises what it means. Mirror the rule in the oracle. The
size of the effect is measured by `bracketed` in `prismio aif --summary` on `lsp/main.psm` and
`suite.psm`, before and after.

## 3 · Releasing arena memory recognised in `rt_free`: one body, two placement regimes

**The rule that blocks most bracketing.** SPEC §5.2.1.1's regime (a) requires each emitted body to
run under one placement regime. "Otherwise one static callee body would need to free heap memory on
one path and avoid freeing arena memory on another." The three rejections that rule produces
dominate the counts:

| Program | functions | `br-multicall` | `br-shared` | `br-drop` | bracketed call sites |
|---|---:|---:|---:|---:|---:|
| compiler (`src/main.psm`) | 4,079 | 2,303 | 2,620 | 28 | 6 |
| language server | 590 | 326 | 295 | 0 | 7 |
| benchmark suite | 283 | 98 | 38 | 10 | 33 |

A worked case: a String accumulator in a region (`s = s.concat(piece(i))`, 20,000 iterations) is
served nothing. `concat` has one call site inside the region and one through `piece`, and `--why`
names both an opaque extern and "the body has more than one call site".

**Observation.** The arena is already ambient and dynamic (`rt_arena_hint_push`, the arena slot),
so the **allocation** in a shared body switches regime on its own at run time. Only the **free** is
static, and arena memory reaching `rt_free` is the danger. Arena chunks come from `malloc`
(`arena_chunk_new`, 8 KiB), so `rt_free` on one hands an interior pointer to libc `free`, which
corrupts memory.

**Design.**

1. Carve arena chunks from the slab's reserved range, as whole 64 KiB spans (or runs of spans)
   whose entry in `slab_span_class` is a reserved value, `SLAB_CLASS_ARENA`.
2. `rt_free` already loads that byte (`lang_runtime.c:400`). It adds
   `if (c == SLAB_CLASS_ARENA) return;`, one compare that is predictably not taken.
   `rt_base_realloc` of an arena block copies the block into a fresh bump allocation.
3. The obligations about freeing are then discharged at run time: regime (a)'s multi-call and
   shared-body clauses, and the explicit `drop`. One emitted body frees heap memory on the heap
   path, and the same free is a no-op on the arena path. The obligations about **lifetime**
   (nothing allocated in the extent outlives the call, no store into an outside owner, no global)
   stay static and unchanged. So does the inverse obligation: an arena-served container must not
   own a heap element from outside the extent.

**Prior art.** MLKit's storage-mode analysis passes a region's mode at run time (whether an
allocation may reset the region), so one function body serves several regimes. Birkedal, Tofte and
Vejlstrup, POPL 1996, "From region inference to von Neumann machines via region representation
inference", is from memory and not checked this session. Here the ambient arena plus tagged spans
play that role, with no extra parameter.

**What it needs, and the risks.**

- The arena chunk spans need allocator stage 4: reserve with `PROT_NONE` and commit in steps.
  Without it there is no way to hand whole spans to arenas.
- The verify build's `aif_verify_release` must recognise arena memory too, or it will report
  releases of a pointer that is not live.
- On Windows (the recycler), on freestanding targets and when the reservation is refused, the old
  static rule must stay, so codegen needs a per-target flag.
- **This is a performance lever, not a leak fix.** Its prize is the arena tier on code that today
  takes the heap: `transient_allocation` and `recursive_tree_rebuild` are 0.27–0.30× of C++ where
  arenas already apply.

## 4 · Arena growth: not a problem today

The brief's prompt 7 asked about the peak of a Vec that grows inside an arena. A `region` around
1M pushes into a local `Vec<Int>` serves nothing (`P5007`: "region work serves no allocation"),
and peak RSS is the same with and without the region (5.8 MB). Lists are not arena-placed in this
shape, so retained growth does not happen. It is worth revisiting after §3, which would arena-place
much more.

## 5 · Prompts 5 and 8: designs on record, nothing new measured

- **The pass-through guarded release** (`test_269`, 9 blocks) is unchanged from KNOWN_ISSUES:
  release each argument unless it equals the result. It is the one place where a pointer-equality
  check is the right tool. The cost is one compare per call of a pass-through function. Lower
  priority than §1, whose leaking shape is far more common.
- **Task results** (`test_69`, 4 blocks): the handle is copyable, so `join` cannot own its result.
  Making the handle affine is the language-level fix and needs a seed. Returning a copy on `join` is
  the no-syntax fix, at one copy per join.

## 6 · Prompt 6: sizing a middle IR

| Measure | Value |
|---|---:|
| distinct AIF queries codegen asks (`aif_*` from `src/ir`) | 30 |
| their call sites | 69 |
| ownership-guard helpers in `src/ir` (aliasing, hoisting, release, drop and view guards) | at least 24 |
| lines in `overwrites.psm` + `columns.psm` | 1,349 |
| `expr.psm`, where 50 guard references live | 6,594 lines |
| commits touching those four files since 2026-09-01 | 67 (at least 13 name an ownership fix) |

**Recommendation: not yet, and not as the next step.** The build list's items do not need a
middle IR, and each one removes a reason for a guard. Effect summaries (MEM-005) are the right
first slice: `param_returns`, `fn_ret_partial` and §2's extern rule are summaries already, scattered
across tables. Gather them into one per-function record that callers consume, then decide on the IR
once the remaining guards are counted again.

## 7 · Additions to the build list

These slot into `RESEARCH_BUILD_LIST.md` §3:

| Rank | Build | Prize | Cost |
|---|---|---|---|
| after #1 | **The extern summary rule** (§2) | bracketing restored in any extent that calls a scalar or void extern: 0 → 50 in the probe | small: `contracts.psm` and the oracle |
| after #2 | **Storage agreement for bindings and fields** (§1) | `test_58` 100 → 0, `test_171` 1 → 0, the frame-site payload enum, the `let mut best = …` idiom | small-medium: engine and oracle |
| after #7 | **`rt_free` that recognises arena memory** (§3) | removes most bracketing rejections; a performance lever | medium, after allocator stage 4 |
