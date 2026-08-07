# Handoff — continuing the Prismio work

Read `COMPILER_AUDIT.md` (defects, all closed) and `V1_GAP_ANALYSIS.md` (capability inventory
against the v1 bar, with a status box at the top) before starting. Current as of **2026-08-07**.
Don't re-derive what's in them.

---

## Current state

Everything below is verified, not asserted — the commands that verify it are in the next section.

- **Self-hosts to a fixed point.** Bootstrapping from the committed seed produces a compiler whose
  IR for `src/main.psm` is byte-identical to the warm build's.
- **76/76 tests**, of which 20 are negative and each asserts *which* diagnostic it expects.
- Backend is the **LLVM C API** (`runtime/llvm-api-backend.c`); the old text emitter is gone.
  `ir_append()` survives only as a loud failure guarding against raw text creeping back in.
- Pinned to **LLVM 22.x**, enforced at build time (`tools/setup_llvm.py`) and at runtime
  (`LLVMGetVersion` in the backend). Bump `PRISMIO_LLVM_EXPECTED_MAJOR` (`runtime/prismio_llvm.h`)
  and `REQUIRED_MAJOR` (`tools/setup_llvm.py`) together.
- **CI on three platforms**: source-list check → LLVM → bootstrap from seed → fixpoint → suite →
  seed target-neutrality.

### File roles

| File | Role |
|---|---|
| `src/lexer.psm` | tokens with spans, string/char escapes |
| `src/parser.psm` | precedence, casts, compound-assignment desugaring, error recovery |
| `src/sema.psm` | type checking, ownership, scoping, flow analysis |
| `src/types.psm` | TypeInfo, width/signedness helpers |
| `src/ir.psm` | AST → backend calls. **Emits no IR text** |
| `src/bridge.psm` | the backend FFI surface |
| `src/diag.psm` | the diagnostics FFI surface |
| `runtime/ir_symbols.c` | interned names, scoped symbol table, move/borrow state, loop targets |
| `runtime/diagnostics.c` | source-file registry, span rendering, error accounting |
| `runtime/llvm-api-backend.c` | the backend |
| `runtime/prismio_llvm.h` | LLVM C API decls; real headers via `-DPRISMIO_LLVM_REAL_HEADERS` |

---

## Workflow — do this for every change

```powershell
.\tools\bootstrap.ps1 -Compiler build\<lastgood>.exe -Out build\next.exe
.\tools\bootstrap.ps1 -Compiler build\next.exe -Out build\next2.exe
.\build\next.exe  build src\main.psm -o build\a.ll
.\build\next2.exe build src\main.psm -o build\b.ll
# a.ll and b.ll must be identical -> fixpoint
```

```bash
cd tests && PRISMIO=../build/next2.exe python test_runner.py   # must stay 76/76
```

Then, only for a language or codegen change the seed must carry:
`.\tools\refresh_seed.ps1 -Compiler build\next2.exe`, followed by a cold start from it
(seed → gen0 → gen1 → gen2, and gen1/gen2 must agree).

If you touched anything in `runtime/`: `python runtime/generate_embedded_sources.py`.
If you added or removed a file in `runtime/`: `python tools/check_source_lists.py` will tell you
which of the six lists you missed.

### Five rules learned the hard way

1. **Keep known-good generations.** A broken compiler can be unable to build the fix to its own
   bug — this happened: `scope1.exe` mishandled a global and so couldn't compile the correction.
   Recovery was to build from the previous good generation. Never overwrite your only good binary.
2. **Two generations before judging.** A change to code the compiler uses *to compile itself* only
   takes effect in the generation after next. Gen N has the new source; gen N+1 is the first built
   *by* it. Both short-circuit and `char_code` needed this.
3. **The suite is a floor, not proof.** It was 36/36 green while `for` with a string literal was
   completely broken. Add a regression test with every fix.
4. **Write `.psm` files with an editor/tool, not shell heredocs.** The shell mangles backslashes —
   `'\0'` in a heredoc reached the file as a literal NUL byte, twice, in this session alone. And
   PowerShell's `-Encoding utf8` writes a BOM (the lexer skips it now, but other tools won't).
5. **A check that cannot fail is worse than no check.** `verify_separation` looked for strings the
   backend stopped containing when it moved to the C API; half of it passed for the wrong reason
   and half would have failed. When you change what something is made of, re-read what tests it.

---

## What's next

**The memory model, Level 1.** Level 0 landed on 2026-08-05: `prismio aif <source.psm>` runs AIF's
inference engine over the post-sema AST, assigns every allocation site a tier, and emits the
manifest. It changes no codegen — nothing allocates differently yet — which is why it could land
without risking the self-host.

| | |
|---|---|
| `src/aif.psm` | the pass: AST walk, transfer rules, tier derivation, manifest, `--why` |
| `runtime/aif_support.c` | its containers: bitsets, interning, points-to keys, the solver loop, the derivation, arena placement |
| `tools/aif_differential.py` | holds it against `aif/prototype/aif.py`, the independent oracle |
| `tools/aif_manifest_diff.py` | the SPEC §6.3 gate; with `--compiler`, the minimal cause too |
| `tests/aif_tiers.psm` | one fixture per SPEC §4.2 clause, asserted in the suite |

Run `python tools/aif_differential.py` after touching either implementation. They agree today on all
eight sources under both collection settings, and that agreement is the only thing standing between
a subtly wrong transfer function and a silently wrong tier. A deliberate divergence is fine and
should be commented at the site in both files; an accidental one fails the script.

**Level 1 also landed.** T0 reaches codegen: `ir_alloc_stack` emits an `alloca` hoisted to the entry
block, and `generate_expression` picks it over `ir_alloc_object` when `aif_tier_at_node` says T0.
Tiers are keyed by the AST node's address: both passes walk the same tree in the same process, so
it names the expression for free and cannot collide. It replaced a `file:line:col` key, which could
— an array literal and its first element share a column, and the collision cost a real promotion.

Three things to know before extending it:

1. **The self-host does not test this path.** The compiler has zero T0 sites, so a fixpoint check
   passes no matter what stack promotion does. `tests/test_42_aif_stack_promotion.psm` is the
   coverage; keep it working.
2. **A hoisted `alloca` is one slot per site, reused by every loop iteration.** That is only sound
   because T0 requires the value's escape to bottom at its own defining scope. The escape module was
   wrong about exactly this and it was a miscompile, not a slowdown — see `aif_var_scope`.
3. **`drop(x)` lowers to a free.** Anything an explicit `drop` names is barred from T0, or the free
   lands on a stack pointer. `test_24_drop` catches it.

**FFI ownership contracts landed too** (`aif/implementation/REQUIREMENTS.md` item 8). `extern`
declarations carry them postfix on the type:

```prismio
extern fn ptr_to_node(ptr: String borrow) -> ASTNode alias
extern fn list_push(list: List borrow, item: Ptr retain_in(0))
```

They are contextual identifiers, not keywords, so `borrow`/`out`/`alias` still work as ordinary
names. **The seed was refreshed for this** — `src/ast.psm` and `src/types.psm` now use the syntax,
so the previous seed could not have parsed the tree.

That took the compiler's own distribution from 27% to 58% T0–T2. Annotating the rest of the verified
runtime surface took it to **66%**, and **85% with affine collections** — the first time this corpus
clears BENCHMARKS H1's 70% bar. Opaque extern returns fell from 425 to 36.

Read the C before declaring a contract. `ir_get_temp_name` and `ir_get_label_name` sit among a dozen
interned-string accessors and `malloc`; guessing `alias` from the name would have been FFI §1's
unsafe-not-slow error. What could not be verified is still undeclared, which is what the remaining
36 opaque returns are.

**Three analysis gaps closed on 2026-08-06** — `List<T>`/`[T]` type-graph edges, array-literal
element sites, and a `widen_and_close` that raised the whole graph. `COMPILER-AUDIT.md`'s "Analysis
quality" section has the detail. Two things from it that change how you work here:

- `prismio aif <src> --budget=N` truncates the fixed point on purpose. That path had never executed
  before; `run_aif_widening_test` now checks, at every budget from 1 to convergence, that the
  truncated tier is at or above the converged one.
- Points-to is solved to a fixed point *before* the facts, and the manifest reports the split
  (`rounds 10 (points-to 8)`). No rule writing points-to reads a fact, so this changes no answer.

**Level 2 landed too** — drops at all four scope exits (fall-through, `return`, `break`,
`continue`), in reverse construction order. Read `COMPILER-AUDIT.md`'s Level 2 note before touching
it; the short version:

- It frees **nothing** in the compiler and nothing in the corpus. There is no T1 struct in either —
  small ones take T0, escaping ones take T2 — so `tests/test_43_aif_scope_drop.psm` is the entire
  safety net, as at Level 1. Its `Wide` is 33 fields because that is what it takes to be a struct
  that is neither.
- Droppability is `aif_frees_at_scope_node`, not the tier. T1 alone is not enough: it means *some*
  region, possibly an enclosing one, and freeing at the inner exit would be a use-after-free.
- **Do not add a `ir_is_moved` check to the drop path.** Move state is sema's and is cleared per
  function before codegen runs, so the answer is about some other function. Everything it would
  have caught is a fact: moving outward raises the escape, and `drop(x)` marks the site.

**`verify` mode landed** (SPEC 7.3): `prismio build <src> --verify`. It is a name swap through
`ir_set_alloc_function` / `ir_set_free_function` and nothing else — codegen is byte-identical to a
release build — and the shims in `runtime/lang_runtime.c` check that every object is released
exactly once, poisoning it on the way out. It reports to stderr and names the leaked allocation by
serial. The suite runs it over the four struct-allocating fixtures and asserts **zero violations**;
the leaks it does report are the T2 returns, which have no free point yet.

It paid for itself on the first run: **`drop(x)` was emitting a call to `free` by name**, bypassing
`ir_free_object` and therefore the allocator seam — so an explicit drop was invisible to verify and
would have handed an arena pointer to libc at Level 3. Routed through the seam now. If you add
another release path, put it through `ir_free_object` or it is outside the model.

Not all of SPEC 7.3's table is implementable yet; the header comment over the shims lists each row
and what it needs (`A` needs an object header word, `E = Region` needs arenas, `C` needs a heap
walk).

**Level 3 landed.** `region <name> { … }` is a keyword statement; the arena is a runtime stack in
`lang_runtime.c`, pushed on entry and popped at every exit. `ir_alloc_region` is the third hook the
seam always needed. A value comes from the arena only when `aif_arena_at_node` says its escape
bottoms at or below that region — lexical containment is not enough, and the nested case in
`tests/test_44_aif_region.psm` is why.

The handle is **dynamically scoped, not threaded**, against `COMPILER-AUDIT.md` §3's prediction. It
costs exactly one case: a value written inside an inner region but escaping to an outer one cannot
name the outer arena and falls back to the heap. See the Level 3 note in the audit before changing
this.

**Run a cold start after any change to the runtime's FFI surface:**

```powershell
.\tools\bootstrap.ps1 -Seed bootstrap\prismio-seed.ll -Out build\cold0.exe
```

The node-keyed tier lookup renamed `aif_tier_at`, and the committed seed's IR still called it — so
the seed could not link. CI's first step would have caught it; three local changes did not, because
bootstrapping from a warm binary never touches the seed. The seed is refreshed as of 2026-08-06.

**Level 4 landed.** `String` and `List` are move-only. This is where the compiler stops leaking
strings, and where its own distribution goes from **66% to 88% T0–T2** — the first time this corpus
clears BENCHMARKS H1's 70% bar without a hypothetical. The T3 residue falls from 102 sites to 37,
which is exactly the undeclared extern returns. Read `COMPILER-AUDIT.md`'s Level 4 note before
touching it; five things from it that change how you work here:

- **A `let` whose initialiser is a field read, an index, or an already-borrowed name is a reborrow,
  not a move** (`sema_binding_is_borrow`). Without it, affine strings break every pointer walk in the
  compiler, because a pointer is punned as a `String`. Consuming a borrow is still an error —
  `drop(x)` and `sink` go through `sema_consume_operand`, which is what `sema_move_operand` used to
  be. It is sound and not merely quiet: a borrowed binding's initialiser registers no allocation
  site, so the drop predicate cannot admit it.
- **Arrays are not affine and must not become so.** They lower to `ir_array_alloca`, so there is
  nothing to own and `drop(arr)` would free a stack pointer (`neg_18`). The C solver still calls them
  move-only, to stay in step with the oracle; `aif_frees_at_scope_node` declines them by kind.
- **The arena needed a second mechanism, not zero.** The prediction below was that T1 strings become
  arena-placed with no codegen change. They don't: a string is allocated inside `lang_runtime.c`,
  past the seam. Codegen brackets a producing runtime call the arena accepted with
  `rt_arena_hint_push`/`pop` and the runtime bumps instead of calling `malloc`. `aif_arena_at_node`
  is the whole gate and is sufficient — see the audit for why.
- **`--verify` now compiles the runtime with `-DPRISMIO_AIF_VERIFY`.** Both ends of every allocation
  pairing have to swap together or every string release reads as a pointer that was never live.
  Codegen is still byte-identical to a release build; the swap happens when the runtime is compiled.
  This is why a verify build skips an installed `runtime.lib`.
- **The compiler emits 11 frees against 186 T1 string sites.** Droppability is a property of a
  *binding*, and most sites are temporaries written inline as arguments. That is the level's
  remaining leak class and closing it needs a fact the model does not have — the audit says which.
- **A reassigned binding is never droppable.** The drop frees the *slot*, and `s = node.name` puts a
  borrowed pointer in a slot the exit expects to own. `node_assigns_name` asks at the declaration,
  because codegen is a forward walk and a `break` above the assignment still runs after it. This was
  latent from Level 2 and Level 4 made it reachable; `test_45`'s `reassigned_from_borrow` pins it,
  and it is the leak *count* that detects a regression, not a violation.

**Automatic arena placement landed** (LAYOUT §7.1), and it is what made Level 4 pay. The compiler
places **105 arenas** and serves **all 186 T1 string sites** from them; individual frees went from 11
to 0 because every one of those values is now reclaimed with its block. That closes the temporaries
leak class — a temporary has no owner and so no free point, but it does have a scope. `test_45`'s
allocation count fell from 420 to 7. Read `COMPILER-AUDIT.md`'s note before touching it; four things:

- **`entries(s)` factors out of the benefit formula**, so no loop-trip estimate is needed for the
  decision. Placement is greedy innermost-first, which makes LAYOUT's "only when values die
  materially earlier" true by construction rather than by a heuristic.
- **Inside a `region`, the region decides.** Automatic placement fills scopes with no enclosing
  region and never undercuts one — otherwise the arena in `many`'s loop body would take all 200
  objects and `batch` would serve nothing.
- **Arena chunks are pooled.** Without that, entering a region costs a malloc and a free, the model
  has to decline every small scope, and automatic placement can never fire.
- **An explicitly dropped value and a `List` are both barred from arenas.** `drop(x)` emits a
  deallocator call, and `list_push` reallocates its element block at whatever arena depth the program
  is at by then. The list exclusion is also what keeps Level 2's drop path exercised.

**`unique` and `pin` landed** (SPEC §5.1, §5.4) — contextual, not reserved, so `let unique = 5` is
still a variable. `unique` is sound here because the language is affine: a second owning reference in
the declaring scope is already `use of moved value`, so the move checker discharges the local
verification and the axiom does the interprocedural half. A refuted `pin` is the one thing AIF
reports (`neg_20`); `workload` is deliberately not implemented, because SPEC §5.3 leaves its syntax
open and there is no layout optimiser to consume it.

**Minimal cause landed** (SPEC §6.3, INFERENCE §5.6):

```bash
prismio aif src/main.psm --why=aif_base_type__String#0
```

and `tools/aif_manifest_diff.py old new --compiler build/prismio.exe` prints one under every
regression it gates on. The derivation is one maximal edge per site per domain rather than the full
DAG — see the audit for why that is still a maximal contributor, and for the two properties it costs.

**Ownership inside containers landed** (2026-08-07), and it is what moved the corpus: leaked
allocations under `--verify` went from **127 999 to 14 866**, zero violations, with `g1` and `g2`
reaching zero. Read `COMPILER-AUDIT.md`'s note before touching it; six things:

- **It had to precede Level 5.** A T3 value's escape is Caller or Global by definition of the tier,
  and `aif_frees_at_scope_node` opens with `E == scope` — so the Level 2 drop path is *unreachable*
  for T3 in every program. A container teardown is the only release point T3 can have.
- **Level 4's "the elements are not touched" was exactly inverted.** It argued the element is owned
  at its own binding; the raised escape that argument rests on is what makes the binding decline.
  Every element of every list leaked. The container owns them now, and is *told* so at `list_new` —
  it cannot ask, because reading a header in front of an element is reading memory we did not
  allocate.
- **A mixed container reclaims nothing.** One call per element, so the disposition is `NONE` unless
  every element site agrees. Arrays, opaques and T3 elements all fall out here.
- **A-CONTAIN is new and A-COPY is why it had to be.** A-COPY exempts move-only values because a
  second binding is a move; a container is not a binding and `list_push` is not a move, so one value
  in two lists read as T2. It is Shared now, i.e. T3 — zero containers is a scope drop, one is a
  teardown, two is a refcount. The half it cannot see (two pushes of one *name*) is a compile error:
  `list_push` consumes its operand. `neg_21`, `neg_22`.
- **`list_get` returned the list, not the element**, against its own comment — so an element moved
  between containers hid the sharing *and* made the receiver call `list_release` on a struct. A
  container's contents are a field key now. It is object-insensitive, and one cross-container push
  therefore poisons a whole file; that is why `test_47` and `test_48` are two files.
- **Ownership across a return is containers only, and that is soundness.** A `String`-returning
  function can `return "literal"`, which registers no site, so its return set looks exactly like one
  that always allocates — freeing that is a free of `.rodata`. The first build emitted 44 such frees
  and the next generation could not compile itself. A `List` has no literal form. It also survives
  one hop only: the returned site must belong to the callee.

`g4_ecs_world` is unchanged by all of it — its lists are fields of a struct that is returned and
never released. **Struct-field ownership is the sibling item**, and it wants a per-type release
function rather than a stamped mode, because a struct's fields are known statically.

**Level 5 landed** (2026-08-07). T3 is non-atomic refcounting with the count in a **prefix header** —
`rc_alloc` returns `base + 16`, `rc_of(p)` is `((size_t*)p)[-1]` — so the LLVM struct type is
untouched, every `ir_struct_field_ptr` index still means what it meant, and the seam really is just a
fourth allocator name (`ir_alloc_rc`). Read `COMPILER-AUDIT.md`'s note; five things:

- **The count starts at zero.** What is counted is container edges, because they are the only holder
  class this compiler both tracks and releases — a T3 value's escape is Caller or Global by the
  tier's definition, so its binding is never on a drop list. Counting the creating expression would
  pin every T3 value at one forever. At zero, one container is one count and the value dies with the
  last one holding it; a value in no container leaks, as it always did.
- **The retain and the release are the same container's**, driven by the one mode stamped at
  `list_new`. Putting them anywhere else would give the two a chance to disagree about whether an
  element is counted.
- **An OPAQUE site is never refcounted** — no header of ours in front of it. That is all 37 of the
  compiler's T3 sites, so `src/main.psm` emits **zero** `rc_alloc` calls while still declaring it,
  and `run_aif_rc_test` asserts exactly that. `STRING` and `LIST` are excluded too, for Level 4's
  reason: they are allocated past the seam.
- **The manifest says `rc` or `rc:none`.** T3 means the facts permit a count; whether one was emitted
  is a different question, and printing `rc` for a site nothing counts would assert a mechanism the
  binary does not contain.
- **It found a pre-existing unsoundness.** `list_set(list, index, value)`'s `retain_in(0)` named
  argument **1**, the integer index, so the stored value only borrowed and appeared never to escape.
  Both implementations had it identically. Invisible until a stored value took a stack slot and
  `list_set` wrote a frame pointer into a container that outlives the frame.

`test_48` goes 2 leaked → **0**, 24 allocated / 24 released, 0 violations. The corpus does not move:
no program in it reads an element out of one container and pushes it into another, which is the only
route to T3 once collections are affine. **T3 is rare here by construction**, and that is the model
working rather than a gap.

Not done: **Perceus-style elision** (needs a reference-level IR the AST walk does not have), and
release at anything finer than container granularity.

**The remaining FFI surface is declared** (2026-08-07). Twelve declarations — eight `alias`, four
`produce(free)` — take the T3 residue from **37 to 0** and the compiler's distribution to **100%
T0–T2** over 294 sites. Level 5 could not have reached any of them: every one is an opaque extern
return, which must never be refcounted.

The split came from reading the C each time. `alias`: `aif_extern_contract`, `aif_fn_symbol`,
`aif_order_symbol`, `aif_site_type` (all `aif_str` of an interned id), `ir_get_var_type`,
`ir_get_struct_field_type` (`ir_intern`, literal fallback), `cli_arg` (argv), `ir_llvm_version` (a
`static char buf[32]`). `produce(free)`: `compiler_default_exe_path`, `compiler_temp_ir_path`,
`compiler_installed_runtime_hash`, `compiler_runtime_source_hash`.

The four `produce` declarations needed Level 4's `str_substring` check: **every** path allocates,
including the failure paths, which return a one-byte empty string rather than a literal. A `produce`
true only on the happy path is a free of `.rodata`.

Two things move that are easy to misread. Sites fall 325 → 294 and `static-ret` rises 16 → 34,
because an `alias` return with nothing to alias stops being a site — so 100% is over a smaller set,
deliberately. T1 rises 205 → 209 and arenas 105 → 119, so the compiler still emits **zero**
individual frees.

**The ranking in the list below was wrong and the reason generalises.** This was item 2 and Level 5
item 1; measured, this is the one that moved the compiler and Level 5 moved nothing there. A tier is
a claim about what the analysis could prove, and an undeclared boundary is not a hard case — it is a
missing input. Reach for the input before the mechanism.

**The layout optimiser landed partly** (2026-08-07), and **`workload` deliberately did not**.

LAYOUT §7.2 runs over a statically estimated access profile and searches **one** of §6's five
candidate dimensions — field order within AoS. The other four are not deferred, they are not
implementable: SoA and a hot/cold split both make one logical object several allocations, so a field
reference stops being `getelementptr` on a pointer, which is `COMPILER-AUDIT.md` §1 finding 6
(handles, "touches every layer"). Choosing a layout codegen cannot emit would be a manifest
describing a binary nobody built. The `layout` column reads `AoS` or `AoS*`.

Three things to know before touching it:

- **The first field never moves.** The compiler puns a struct pointer as `String` and spells "empty
  slot" as `str_equals(ptr, "")`, which reads the first byte of the pointed-to struct — the reason
  `NodeKind` and `TypeKind` reserve ordinal 0. Sorting by width put an 8-byte pointer at offset 0,
  a pointer to `""` has a zero first byte, and every live node with an empty `s1` read as absent.
  The next generation could not parse its own source. `run_aif_layout_test` guards it, because the
  failure mode is "the next generation does not build" and no value test sees that.
- **LAYOUT §6's derived sort is wrong once a field is pinned.** A sort is optimal for padding only
  when placement starts at 0 with nothing fixed; a pinned 4-byte `kind` leaves a hole only a narrow
  field can fill. Sorting made `Health` 16 → 24 bytes and `Sprite` 40 → 48, and nothing smaller.
  Placement is greedy over the running offset now, with frequency demoted to a tie-break — §6 puts
  frequency first to decide a hot/cold cut, and there is no cut.
- **The differential is not the safety net here.** The oracle runs in `--theta-fields` mode, so it
  never sees a byte size and the layout is invisible to it. Fixpoint and the new test are the
  coverage.

Measured: one struct shrank across the compiler and all six corpus programs (`g6_game`'s `Order`,
32 → 24 bytes) and none grew. Small, and honest — declaration order was already near-optimal almost
everywhere, which is worth knowing before budgeting for the SoA half.

**`workload` is not built on purpose.** Its only contribution over the static estimate is *measured*
frequencies, and that needs a build-time instrumented compile-link-run inside the compile plus
LAYOUT §3.2's W3 sandbox obligations. Shipping the syntax without the runner is the same objection
this item was ordered around, pointed the other way: a producer that produces nothing. The
instrumentation point already exists when someone wants it — `ir_struct_field_ptr` is the single
choke point for field access, the way `ir_alloc_object` is for allocation.

---

## Session of 2026-08-07 (second) — the corpus reaches zero

**`--verify` over the whole corpus: 14 866 leaked allocations → 0, with 0 violations.** Six items
landed; the seventh was deliberately not started. Read
`aif/implementation/COMPILER-AUDIT.md` for the design notes on each — the short version is below.

| | before | after |
|---|---|---|
| `g3_scene_graph` | 4 095 | **0** |
| `g4_ecs_world` | 7 511 | **0** |
| `g5_asset_cache` | 47 | **0** |
| `g6_game` | 3 213 | **0** |
| `g1`, `g2` | 0 | 0 |
| **total** | **14 866** | **0** |

Suite **91/91** (was 82). Fixpoint holds cold and warm, cold == warm, the oracle agrees on all 12
sources, seed refreshed.

**No tier moved all session.** The compiler's distribution is byte-identical before and after —
248 T1 / 17 T2 / 79 T3 — because every change was a *codegen* change reading facts that already
existed, not a change to the facts. That is also why the differential kept agreeing, and it means
**the differential was not the safety net for any of this work**; the fixpoint, the corpus under
`--verify`, and per-item static checks on the emitted IR were.

What landed:

1. **Struct-field ownership** — a generated `__aif_release_T` per type, per-field disposition, and
   `type_is_reclaimed` so a field is only a release point when its owner has one. This is what took
   g3, g4, g5 and g6 to zero. **The first level the self-host exercises**: the compiler generates
   releases for `Token`, `Lexer`, `ASTNode` and `TypeInfo` and emits 11 calls to them.
2. **REQUIREMENTS 20** — `List<T>` for scalar elements. A real miscompile, now a pointer-slot
   coercion rather than a box, so the memory model needs no case for it at all.
3. **REQUIREMENTS 4** — `T?`, `none`, `expect(x)`. `none` is a **null pointer**, which is immune to
   the punned-slot hazard by construction: a null test reads no byte of any object.
4. **The T4b cycle collector** — trial deletion over cyclic edges only.
5. **SPEC 7.1's zero-analysis level** — `--debug`, plus a test that makes the invariant falsifiable.
6. **REQUIREMENTS 19** — `peak-bytes` in the manifest and `region name pin(N)` as the gate.

### Three things to carry forward

- **A pun must decline rather than guess.** The first struct-field build emitted a call to
  `__aif_release_String`, because this compiler puns an `ASTNode` pointer as `String`. Gen 1 linked
  (it was built by the *old* compiler); gen 2 did not. **Two generations before judging** earned its
  place again.
- **A guard must establish what it assumes.** Barring a binding's drop because "some type's release
  will take it" is wrong when that type lives in the frame and is never released — it deletes the
  release rather than moving it. That took g5 from 47 leaked to **2049** before `type_is_reclaimed`
  existed, and no value test sees it: the leak count is the only detector.
- **A mechanism must count every edge it traverses.** The first cycle collector **segfaulted**:
  trial deletion subtracted field references that nobody had ever incremented, so the arithmetic
  called a live object unreachable. Container edges were counted (Level 5's design); field edges
  were not.

### Not started: ownership contexts (INFERENCE §6–7)

Deliberately not begun rather than half-landed. Reading §6–7 against the current code, it needs
per-context fact graphs, demand-driven instantiation, a relevant-parameter mask, δ-based strategy
selection, caps with deterministic victim selection — **and an identical change to
`aif/prototype/aif.py`, or the differential stops meaning anything.** It is a project, and the
audit's own "each of these is a project on the scale of the current compiler" is accurate.

**What changed about its value, and this is the part worth reading.** It was ranked highest because
three recorded limitations were one missing feature *and* because `g4_ecs_world` would not move.
g4 now moves — struct-field ownership took it to zero — so **contexts no longer buy correctness on
this corpus; they buy precision.** The three limitations are still real and still one thing, but the
leak that motivated them is closed. Re-rank it against `workload` and Perceus on measurement rather
than inheriting the old order.

**Next, in order of measured value:**

1. **Ownership contexts (INFERENCE §6–7).** Still the highest-value *analysis* work, and still a
   project. See the note above for why its value changed. **Measure first** — the corpus is at zero
   leaks, so the question is now how much precision is left on the table, and nobody has that number.
2. **The undeclared-boundary residue.** The compiler reports **79 T3 sites** over `src/main.psm`,
   and this document's earlier "100% T0–T2, T3 residue 0" claim does not match the tree as it
   stands. That discrepancy pre-dates this session (the baseline binary reports the same 79) and was
   not chased. It is the cheapest measured win available if it is the same undeclared-extern shape
   as last time — **reach for the input before the mechanism**, twice recorded.
3. **`workload` and the rest of LAYOUT.** Unchanged: the runner needs a build-time instrumented
   compile-link-run, and SoA/hot-cold need handles. Do not build the syntax alone.
4. **Perceus-style elision** for T3. Needs a reference-level IR the AST walk does not have.

**One methodological result worth carrying forward.** The ranking above was wrong in the previous
handoff and wrong in the same way twice: Level 5 was ranked first and moved the compiler by nothing,
while declaring twelve FFI contracts took its entire T3 residue to zero. A tier is a claim about
what the analysis could *prove*, and an undeclared boundary is not a hard case — it is a missing
input. **Reach for the input before the mechanism.**

`src/aif.psm`'s `aif_runtime_contract` is a fallback table for the runtime's own functions, kept
because every corpus program declares `list_push` itself and none of them should have to get it
right for the analysis to be sound. It should shrink as declarations gain contracts.

Below is the seam as it was assessed before any of this; it is still accurate, and
`aif/implementation/COMPILER-AUDIT.md` §3 explains why it covers half the ladder rather than all
of it:

- `ir_alloc_object(struct_name)` and `ir_free_object(value)` are the only two places codegen
  allocates or releases anything.
- Both call whatever `ir_set_alloc_function` / `ir_set_free_function` name, defaulting to
  `malloc`/`free`. Declared in `src/bridge.psm`, so the frontend can drive them.
- Changing the model is therefore a change to those two policy hooks, not to codegen.

Things the memory model will want to settle. The first three are settled now; the last is not:

- ~~`String`, arrays and lists are **never freed**.~~ Strings and lists are affine and freed as of
  Level 4. Arrays are not, and the reason is above.
- Arrays are stack allocations, which is why returning one is rejected. If arrays become heap
  values, that restriction can be lifted — `sema_statement`'s `RETURN_STATEMENT` case is where.
  Level 4 did **not** do this, on purpose: an affine array with no allocation behind it buys the
  aliasing rule and costs a `drop` that frees a stack pointer.
- ~~There is no `defer` and no scope-based drop~~ — Level 2 added scope-based drop at all four
  exits; `drop(x)` is still the only explicit form and is still move-checked.
- **Do not add a pointer-keyed length cache to `str_char_at`.** It was considered and rejected
  precisely because it assumes string buffers are never freed and their addresses never reused —
  an invariant the memory model is about to break. The lexer got its speed from holding the
  length in the `Lexer` struct instead, which assumes nothing.

**Then the docs** (`../docs`), deliberately deferred until after the memory model so they are
written once against a settled language. `V1_GAP_ANALYSIS.md` §3 lists what the site currently
claims that the compiler does not implement.

### Known gaps, documented rather than fixed

- **Compile time is superlinear** in module size — ~290 ms for the 155 KB compiler, ~500 ms for a
  105 KB single module. The cubic term is gone (symbols are mangled once, type names resolve
  through a registry) and lexing is linear now, but sema still scans the module per identifier
  for function lookup. The fix is a name→declaration map built once in `analyze_module`.
- **No `-g`.** Nothing compiled can be source-debugged. Needs real DWARF design work.
- **No error-handling story.** The one users hit first: failure can only be signalled by a
  sentinel return value. Needs tagged unions → `Option`/`Result`, i.e. language design.
- **No generics, methods, closures, or slices.** `List<T>` is a hardcoded special case.
- `resolve_imports` flattens every module into one AST. File identity survives on each node's
  `file` id, which is why diagnostics can still name the right file — but there is no module
  namespacing or visibility.
