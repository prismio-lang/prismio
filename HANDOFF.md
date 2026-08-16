# Handoff — continuing the Prismio work

Read `COMPILER_AUDIT.md` (defects, all closed) and `V1_GAP_ANALYSIS.md` (capability inventory
against the v1 bar, with a status box at the top) before starting. Current as of **2026-08-07**.
Don't re-derive what's in them.

---

## Current state

Everything below is verified, not asserted — the commands that verify it are in the next section.

- **Self-hosts to a fixed point.** Bootstrapping from the committed seed produces a compiler whose
  IR for `src/main.psm` is byte-identical to the warm build's.
- **108/108 tests** as of 2026-08-16, of which 26 are negative and each asserts *which* diagnostic
  it expects. (This line read "76/76" for six sessions after it stopped being true. If you change
  the count, change it here.)
- Backend is the **LLVM C API** (`runtime/llvm-api-backend.c`); the old text emitter is gone.
  `ir_append()` survives only as a loud failure guarding against raw text creeping back in.
- Pinned to **LLVM 22.x**, enforced at build time (`tools/setup_llvm.py`) and at runtime
  (`LLVMGetVersion` in the backend). Bump `PRISMIO_LLVM_EXPECTED_MAJOR` (`runtime/prismio_llvm.h`)
  and `REQUIRED_MAJOR` (`tools/setup_llvm.py`) together.
- **CI on three platforms**: source-list check → LLVM → bootstrap from seed → fixpoint → suite →
  seed target-neutrality.

### File roles

> **Stale as of `f791ab0` (2026-08-08).** That commit split every one of these into a directory and
> renamed the identifiers to camelCase: `src/sema.psm` → `src/sema/{checker,flow,ownership,symbols,
> types,builtins}.psm`, `src/ir.psm` → `src/ir/{module,expr,stmt,types,context}.psm`, `src/aif.psm`
> → `src/aif/{walk,model,report,contracts,layout}.psm`, `src/lexer.psm` → `src/lexer/`,
> `src/parser.psm` → `src/parse/`, `src/ast.psm` → `src/ast/nodes.psm`, `src/bridge.psm` →
> `src/ir/bridge.psm`, `src/diag.psm` → `src/common/diagnostics.psm`. The *roles* below are still
> accurate; the paths are not.

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

~~**`workload` is not built on purpose.**~~ **Built on 2026-08-13** — see that session's entry at the
top of this document. The reasoning below was right about what it needed and right that the choke
point was `ir_struct_field_ptr`; the one thing it got wrong is that `ir_struct_field_ptr` cannot
supply the read/write distinction, because a GEP is the same instruction either way.

Its only contribution over the static estimate is *measured*
frequencies, and that needs a build-time instrumented compile-link-run inside the compile plus
LAYOUT §3.2's W3 sandbox obligations. Shipping the syntax without the runner is the same objection
this item was ordered around, pointed the other way: a producer that produces nothing. The
instrumentation point already exists when someone wants it — `ir_struct_field_ptr` is the single
choke point for field access, the way `ir_alloc_object` is for allocation.

---

## Session of 2026-08-16 — the repair is measured before it is built, and it is worth building

Three sessions designed an arena fix from the source and each was refuted. This one **ran the tools
first** — `arena_census.py` and `--why`, which exist for that purpose — reproduced 2026-08-14's
numbers exactly, and then measured the repair SPEC 5.2.1 names rather than designing it.

**Landed and verified: tasks 1, 2 and 3. Stopped deliberately at task 4** (the placement change
itself); §5 says why and what it needs. Nothing is half-landed. Suite **108/108** (was 106),
fixpoint warm and cold, **cold == warm**, oracle agrees on **15** sources (was 14), and IR is
**byte-identical on all 84** compilable programs in `tests/`, `aif/corpus/` **and**
`aif/evidence/` — no binary moved this session, by design.

### 1. The number the session exists to produce

`region` cannot reach a callee's allocation (SPEC 5.2.1). The repair is to bracket the *call*. How
far could that reach? Per function, as a fixed point over the call graph:

| | corpus programs | `g2_region.psm` | `src/main.psm` |
|---|---|---:|---:|
| clears obligations 1, 2, 4 | 4–11 of 35–45 | 6 / 35 | 189 / 463 |
| …and regime (a): one call site | 1–5 | 4 | 48 |
| **region call sites reaching one** | **0** | **2 of 2** | 6 of 635 |

**Not "almost no function", so tasks 3–5 are worth doing** — that was the brief's gate and this is
the reading of it. And the second row is the one that matters: 70 of the 196 blocked sites are in a
bracketable function, but only **2** are also *called from inside a region*, and both are
`g2_region.psm`'s `cull` and `submit`. Every corpus program that does not say `region` contributes
zero, because nothing calls its functions from an arena.

`prismio aif <file> --summary` prints this; `--why=<symbol>` gives the per-site verdict, so the
count is auditable rather than a claim. On g2's hot `DrawCmd` — the site every arena design has been
aimed at:

```
    bracketing (SPEC 5.2.1.1) -- may a caller's region reach this function?
      yes  -- every obligation holds, and the body serves one regime (1 call site)
      callers  1 of 1 call sites lie inside a region
```

### 2. The regime question, settled and written into the spec

**SPEC §5.2.1.1 is new and normative.** A function body's frees are static decisions in codegen
while bracketing makes the allocation's *source* dynamic, so a body reachable both inside and
outside a bracket would free arena memory on one path or leak heap memory on the other. Three
resolutions exist; **the choice is (a)** — bracket only a callee with exactly one call site in the
program. It is the smallest sound one, (c) is never sufficient alone (a bare struct freed by a scope
drop has no header to read), and (b) is what lifts (a)'s limit when the measurement says it is
worth it. (a) is fragile as a *language guarantee* — a second call silently removes the placement —
so §5.2.1.1 requires the manifest to record when it fired.

The five obligations are written out there too, with the counterexample (`add_to(dest, n)` pushing
into a caller's list) that kills the naive version.

### 3. What the reports say, and where the numbers live

- `--summary` gained `bracketable`, `sole-regime`, `region-calls` and five `br-*` blocker counts.
- `--why`'s placement section gained a bracketing verdict on every `no_region` site, reporting
  **every** failing obligation rather than the first — the same discipline, and for the same reason,
  as the placement mask added 2026-08-14.
- `arena_census.py` prints a second table over the whole corpus and **exits non-zero** if no `--why`
  printed a verdict at all, which is what separates "zero because nothing qualifies" from "zero
  because the wording moved and every substring stopped matching".
- The differential compares all eight bracketing counters. `region-calls` is deliberately excluded
  and the reason is recorded in both files: it counts call sites inside an arena, and arena
  placement is a codegen decision `aif/prototype/aif.py` does not model. Mirroring it would make the
  oracle a second implementation of the thing it checks.

### 4. Two defects, one of them mine, and both now have a test that fails without the fix

**The call graph survived `aif_reset`, and a declared `workload` runs the whole engine twice in one
process.** So every call-site count doubled on exactly those sources — and regime (a) turns on that
count, so `sole-regime` read **0** and `br-shared` read **37 of 37** on `test_55_workload_profile`
while every other program was right. A silently wrong answer on the programs that carry a profile
and on no others. Found by asking what `aif_reset` had to tear down, not by a failing test.
`run_bracket_summary_test` now asserts `sole-regime >= 1` there; verified it reads 0 on the
pre-fix compiler. `test_46` also declares a workload and **cannot** discriminate — its workload run
falls back (W2), so the engine runs once. Measured before choosing the fixture.

**`--verify`'s `allocated` and `leaked` are not comparable across runs.** The timing programs print
nanosecond values and the printing path allocates per digit, so `g2.psm` moves by ~1500 allocations
between two runs of *one* executable. The first comparison of the ledger reported seven programs
"moved" and none had. `released` and `violation(s)` are the stable columns; both are identical to
the previous generation on all 45 programs with a ledger.

### 5. Why task 4 stopped, and the two things not to re-derive

Bracketing needs one fact the model does not have and one decision that removes a circularity. Both
were worked out this session and are written up in
[RESULTS-arena.md §7](aif/evidence/RESULTS-arena.md) item 1:

1. **Obligation 3 is not readable from `E`.** `AIF_CON_LIVE_IN` sets `E = Caller` for any site whose
   `fn` is not the binding function — by construction, since scope ids do not order across
   functions. The fact wanted is the **caller-side binding scope**, recoverable with no frontend
   change by walking `cons[]` for `LIVE_IN` after the solve.
2. **Bracket only into `region`-pinned arenas.** Otherwise placement depends on bracketing depends
   on placement: `enclosing_region` reads `scopes[].arena`, which `aif_place_arenas` sets from
   `arena_would_serve` — the one copy of the clause list that is deliberately *not* behind
   `site_arena_scope`, because it scores scopes that have no arena yet. A `region` sets the flag
   before placement runs, so the loop is cut and `arena_would_serve` needs no change.

And the semantic consequence to accept rather than fight: a bracketed site keeps its **derived
tier**, so the manifest will read `T2  region:<name>`. Promoting it to T1 would move the tier
distribution, and the oracle does not model placement — the differential would then fail on a
difference that is not an inference difference.

The disposition half **is** in, ahead of placement and deliberately so: one clause in
`elem_disposition_of`, which is the single function `aif_elem_owner_at_node`, `field_release_of`,
`type_is_reclaimed` and `aif_owns_call_result_at_node` all read. A second copy of that clause would
be 2026-08-14's four-copies defect with a use-after-free behind it instead of a wasted push. It is
inert today — the placement gate still rejects `in_container` and `is_list`, so no arena-served site
is ever an element — and inertness is the verified claim: byte-identical IR everywhere.

### 6. Fixtures built to discriminate

`tests/test_59_bracket_summary.psm` has one function per verdict, and the third exists only because
the first two would pass for the wrong reason:

- `bracketable` pushes into a list it allocated — the positive control.
- `stores_param` pushes into its caller's list — obligation 2. `br-param` must be **1**: a clause
  firing on every container store reads 2, one that stopped firing reads 0.
- `drops` calls `drop()`, and **`middle` sits between it and `main`**. `br-drop` must be **3**,
  because a blocker anywhere in the transitive set blocks the whole extent. The first version of
  this had `main` calling `drops` directly and **did not discriminate anything** — verified by
  replacing the closure with a one-step walk, which still read 2. Two levels is the minimum that
  fails.

Note what is deliberately absent: `main` has no `br-param`, because the list `stores_param` writes
into was allocated by `bracketable`, which is *inside* main's extent. Sound there, unsound one level
down — a summary that answered per function instead of per extent could not tell those apart.

---

## Session of 2026-08-14 — the arena is lexical and allocation is not, which refutes the fix three sessions have designed

**Read this before planning any arena work.** The `CallerRegion` + container-disposition pair has
been designed twice, deferred twice, and named "the highest-value item with a measured prize" in two
handoffs. **It was measured this session and it buys zero.** Not "less than hoped" — zero sites, on
every program in `tests/`, `aif/corpus/` and `aif/evidence/`. The reason is a third gate that
neither half touches, and it is structural rather than an oversight.

Suite **106/106** (was 98). Fixpoint holds warm and cold, **cold == warm**, the oracle agrees on 13
sources — **14 after this session added one**, see §8 — source lists agree, and the committed seed
still parses `src/` (no seed refresh needed: the FFI surface only grew). Across the session, 82 of 85 compilable programs in `tests/`, `aif/corpus/`
**and** `aif/evidence/` differ only by one added `declare`; the other three additionally lose an
`arena_push`/`arena_pop` pair for an arena that served nothing, which is §2's fix.

### 1. The measurement, and why the designed fix could not have worked

The arena gate has seven clauses. HANDOFF has recorded two of them as the blockers. The census below
is the whole gate, non-short-circuiting, over **234** allocation sites — and it now re-derives in one
command from shipped compiler surface rather than from a patched runtime:

```bash
python3 aif/evidence/arena_census.py --compiler build/<gen>
```

| blocker | blocked sites |
|---|---:|
| **`no_region`** — no `region` in the allocation's *own function* | **196 of 196** |
| `not_t1` | 184 |
| `is_list` | 56 |
| `in_container` | 46 |
| `no_stack`, `escapes`, `outlives` | 0 |

**38 of 234 sites are arena-served, all of them in `std/io`.** No user-written program in this tree
has a single arena-served allocation. The clauses are a conjunction, so a site typically fails
several — which is exactly why the mask matters and the first failure does not.

Simulating the designed fix — `E=Caller` becomes `CallerRegion` so the site reaches T1, and
`in_container` stops rejecting — leaves the served set **unchanged at 38**, because `no_region` is on
every blocked site both before and after. Full write-up and method:
[`aif/evidence/RESULTS-arena.md`](aif/evidence/RESULTS-arena.md).

**`no_region` is on every single non-served site, before and after.** It is
`enclosing_region(s->scope)`, which walks `scopes[].parent` — a lexical tree rooted **per function**,
which is also why `scope_lca` returns −1 across owners. A site in a callee has no arena in its own
function's scope tree to find, and no value of `E` puts one there.

**This is the category error, and it is worth stating precisely.** `Region(s)` holds a *scope id in
the site's own function*. The arena that would serve a callee's allocation is chosen at **run time**,
by `arena_depth` in `runtime/lang_runtime.c`. `CallerRegion` would make g2's `DrawCmd` T1 and leave
it with no arena to be T1 *in* — a manifest claiming a placement that did not happen, which is
exactly the failure the previous design note predicted for the previous gate. **This is the third
consecutive session in which a fully-worked arena design was refuted by reading the gate. The lesson
was recorded twice; reading the gate cost forty minutes this time and would have cost forty minutes
either of the previous two.**

Re-measured first, as the brief asked: `g2_region.psm` is still **0 of 10 201 215 allocations
served, 20 000 regions entered, 1.67× slower** (106.5 → 177.8 ms, 5 runs) on the current compiler.
The 1.73× stands within noise.

**And the 9.9× is still not a Prismio number.** It is the C arena benchmark's headroom. Nothing this
session moved it, and nothing will until placement can place something.

### 2. `region` warns when it serves nothing, and the manifest stopped lying

Both halves of the trap are closed. The warning:

```
warning: region frame_arena serves no allocation; it costs an arena push and pop
         per entry and reclaims nothing
   --> aif/evidence/xlang/prismio/g2_region.psm:112:16
  note: an arena serves a value only where the region and the allocation are in
        the same function: a value allocated in a callee cannot reach it
```

The note is the part that matters — it names the *repair*, and the repair is not one the programmer
would guess.

**And `region:scope` was renamed `region:none`.** This is the bigger of the two. `region:scope` was
printed for a T1 site with **no arena**, served by the heap, one column away from `region:auto` and
`region:frame_arena`, which are real placements. So `g2_region.psm`'s manifest showed `region:` on
every T1 line while the arena served nothing, and a programmer reading it for confirmation got it.
`rc:none` and `cycle:none` already exist for exactly this reason one tier down; T1 never got the
same treatment.

**Three predicates were one predicate wearing three copies.** `aif_arena_at_node` (codegen),
`aif_region_name_at_site` (manifest) and the new `aif_region_serves` (diagnostic) now all read
`site_arena_scope`. They agreed by inspection before; a diagnostic derived from a fourth copy would
have been the manifest defect again, in a new place.

**A fourth copy did disagree, and it was live.** `arena_would_serve` — the LAYOUT 7.1 cost model —
omitted the `in_container` clause, so it scored benefit from container elements codegen refuses to
place. Effect, measured: `test_28`, `test_45` and `test_49` each carried a live
`arena_push`/`arena_pop` pair for an arena that bump-allocated **nothing**, and `peak-bytes`
overstated the arena high-water mark on all three — `test_49` reported **64 bytes for an arena
holding zero**, and REQUIREMENTS 19's budget gate reads that number. Fixed; those three programs
lose the push/pop pair and report 0. **No tier and no placement moved anywhere in the corpus** —
verified byte-identical IR on the other 80 programs and a whitespace-normalised manifest diff on the
three.

### 3. `list_new_with_capacity(n)` — 0.92× on g2, and the only speed result here

Vec::with_capacity's equivalent. `cull` builds a fresh ~501-element list every frame for 20 000
frames and paid seven reallocations and 508 pointer copies each time.

**Priced before it was built**, which is why it exists: raising `list_new`'s default capacity to 512
— the upper bound this API can reach, since it removes exactly the same reallocations — measured
**0.926×** on g2. The shipped feature then measured **0.923× over 21 interleaved runs** (110.3 →
101.7 ms), so it captures essentially all of the available win. Checksums identical.

`aif/evidence/xlang/prismio/g2_capacity.psm` is the measurement artefact — `g2.psm` with one line
changed.

**It is a library call and not an annotation, and that is a governance point rather than a
convenience.** The argument is a *value*, not a fact the analysis must trust; a wrong hint costs a
reallocation and never correctness. So it spends none of SPEC 11 item 7's budget of four.

### 4. The governance question, settled and written down

**Annotations are assertions the compiler verifies and may refuse — option (a)** — now normative in
SPEC §5.0.1, with §5.4.4 for the direction limit. The implementation already behaved this way; the
*specification* did not agree with itself:

- §5 ¶4 said being wrong about an annotation is a **warning** and SHALL NOT fail compilation.
- §11 item 7 said all four are **warning-not-error**.
- §5.4.1, added in 1.2, said a refuted `pin` **SHALL fail compilation** — and the shipping compiler
  does exactly that.

**That is the third internally inconsistent pair found in this specification** (after §2.1 vs W4, and
SimdCredit), and the third found by trying to implement a clause rather than by reading it. Resolved
by kind rather than by compromise: an **axiom** (`unique`, `region`) warns and is discarded, because
discarding it leaves the inference that would have run anyway; the **constraint** (`pin`) fails,
because discarding it silently returns the value to the tier the programmer just said was
unacceptable.

### 5. `pin(T2)` and `pin(T3)` work, and are now tested rather than folklore

Box and Rc, working since Level 5, documented nowhere and tested nowhere. Verified, then fixed in
place: `test_57_pin_tiers.psm`, `neg_25_pin_refuted.psm`, and `run_pin_tier_test` in the runner,
which checks the manifest's tier/placement/origin **and** counts `rc_alloc` call sites in the IR —
because a pin that moved the report and not codegen looks identical from the source.

The brief's worry about `pin(T3)` emitting no count is **already handled**: a pinned-T3 value no
container holds reports `rc:none` and gets no header, which is the honest answer. `rc` and `rc:none`
are both asserted, so the distinction cannot rot.

### 6. `--why` explains placement, and lists *every* blocker

The tool that would have saved the two previous sessions, and it is the durable half of §1.

`prismio aif --why=<symbol>` explained the **tier** and said nothing about where the value lives.
Now:

```
  placement
    heap  -- no arena serves this site
      because  the tier is not T1 -- see the cause above
      and      a container owns this value and tears it down through the deallocator
      and      no `region` encloses this allocation *in its own function*
      note     an arena is a lexical scope (SPEC 5.2.1). A `region` in a
               caller cannot reach an allocation made in a callee, so no
               change to the escape lattice moves this site.
```

**Reporting a mask instead of the first failure is the load-bearing decision.** The gate
short-circuits, so a short-circuiting diagnostic answers "the tier is not T1" — true, and the wrong
thing to act on, because two further clauses reject the same site. That answer is precisely what two
sessions inferred by reading the source, and both then designed a tier fix. A reader who runs `--why`
on g2's `DrawCmd` now cannot make that mistake.

The gate itself computes the mask, so the diagnostic cannot drift from codegen — the same discipline
§2 applied to the other three copies.

### 7. The manifest emitted records its own CI gate could not read

Found while re-deriving the census from the manifest instead of from a patched runtime.

`aifPad` padded *up to* a column width and did nothing when the field was wider, so an
over-long field ran into the next one with no separator. SPEC 6.2's record table is
whitespace-separated, and `tools/aif_manifest_diff.py` ignores lines it cannot parse — correctly, for
comments and blanks, and silently for real records.

**`aif/corpus/g5_asset_cache.psm` emits 14 records; the differ read 13.**
`load_material__Struct_AssetCache_Int_Int_Float#0` is 45 characters against a 44-wide column and
merged with its own tier. **A tier regression on that site could not have failed CI** — SPEC 11 item
8's gate, unable to fail, on a symbol in this project's own corpus. That is the "check that cannot
fail" rule again, and it is the fourth instance this document records.

One line in `aifPad`: at or past the column, emit exactly one space. Every caller prints something
after it on the same line, so no trailing whitespace appears anywhere. **Exactly one line of output
changed across the whole corpus** — the broken one. `run_manifest_parseable_test` counts emitted
records against parsed ones over every corpus program, so the next overflow fails rather than hides;
verified to fail on the pre-fix compiler.

### 8. The oracle did not know about `list_new_with_capacity`, and the differential still passed

**The differential agreed on all 13 sources while the two implementations disagreed by eight tiers on
any program using the new builtin.** Caught only by going back to check the brief's explicit
requirement — "the same change in `aif/prototype/aif.py`, or the differential stops meaning
anything" — against a claim already made that no oracle change was needed.

The reasoning behind that claim was wrong in an instructive way. It ran: *this session changed no
transfer rule and no lattice, so the oracle needs nothing.* True of the rules, and irrelevant, because
the oracle also needs a **vocabulary**:

- Every `extern fn` a *source* declares carries its FFI contract in the AST, so the oracle reads it
  and `aif.py`'s fallback tables never fire. That is why `src/main.psm` — which gained five new
  externs this session — kept agreeing.
- A **builtin** is never declared by anyone. `list_new_with_capacity` therefore fell through to the
  tables, was absent, and became an undeclared extern with unknown provenance.

Measured on `tests/test_56_list_capacity.psm` before the fix:

```
T1: compiler=10 oracle=2   T3: compiler=3 oracle=11   opaque-ret: compiler=0 oracle=5
```

Five fresh containers read as opaque; eight sites sank to T3.

**Why nothing caught it: no source in the differential's list called the new builtin.** The check was
not wrong, it was unexercised — the same failure mode as §7's unparseable record, as SPEC 8.4's
E-VIEW ("both arms would agree by never running the rule"), and as `test_55`'s first draft. Fixed in
both tables, and `test_56_list_capacity.psm` is now in the default source list with the reason
written at the append, so the next builtin cannot be added silently. **14 sources, all agreeing.**

The rule this yields is sharper than "update the oracle": **adding a builtin is an oracle change even
when no rule moved, and a differential source list is part of the check, not a convenience.**

### 9. `pin(<region-name>)` — deliberately not built, and the reason is §1

Item 3 of the brief, and it would have been cheap: the parser already accepts `pin(X)` with a bare
identifier and only `aifTierFromName` rejects it.

**Not built, because it would have shipped an annotation that refutes almost everywhere it is
natural to write.** §1's census is the argument: placement can serve 32 sites in the whole corpus,
all of them strings in `std/io` where the region and the allocation share a function. The brief's own
example —

```prismio
region frame { let pin(frame) cmd = DrawCmd { … } }
```

— refutes as written: a `DrawCmd` that does not escape its scope is **T0, a stack slot**, not an
arena value. An annotation whose headline example fails to compile is the `weight` mistake with a
different name, and this document has now recorded three times that an annotation which does nothing
is worse than no annotation.

**It becomes worth building the day placement can place something in a callee**, and not before. The
assertion machinery it needs (`AIF_PIN_*`, `aif_check_pins`, `--why`) is all present and unchanged.

### Four things to carry forward

- **Read the gate, and read *all* of it.** Two sessions read `aif_arena_at_node` far enough to find
  the clause that explained the last failure and stopped there. The census that settled this took one
  `getenv`-gated `fprintf` and two throwaway scripts — cheaper than either design pass it replaced.
  It is now `aif/evidence/arena_census.py`, runs in 1.4 s off shipped compiler surface, and `--why`
  answers the same question for one site.
- **A short-circuiting gate makes a short-circuiting diagnostic, and that is a trap.** "The tier is
  not T1" was true about g2 and sent two sessions to the wrong work. A conjunction should report
  every conjunct it failed.
- **A duplicated predicate is a defect even while the copies agree.** Four copies of the arena gate
  existed; three agreed and the fourth silently placed arenas that served nothing and inflated a
  budget number. Nothing failed. The fix is one predicate, not four that match.
- **A column that reads like confirmation is worse than a blank one.** `region:scope` meant "no
  arena" and was read as "arena". The project had already invented `rc:none` for this exact problem
  and had not applied it one tier up.
- **Price the experiment before building the feature.** `list_new_with_capacity` was worth building
  because a two-line change to a default measured the ceiling first. The same discipline would have
  saved three sessions of arena design.
- **Deriving a measurement from a shipped artefact finds defects in the artefact.** Rebuilding the
  census on the manifest rather than on a patched runtime is what exposed §7 — a CI gate silently
  blind to one of its own corpus's records. A throwaway probe would have measured the same numbers
  and found nothing.
- **A checklist item dismissed with a reason is still unchecked.** "The oracle models tiers, not
  placement, so it needs no change" was sound about the rules and silent about the *vocabulary*, and
  §8 sat behind it for the rest of the session. Three of this session's findings — §7, §8, and the
  region warning itself — are checks that could not fail. When the argument for skipping a
  verification step is good, run the step anyway; it costs one command.

### Next, ranked on this session's measurements

1. **Call-site arena placement.** The smallest thing that makes `region` work at all: the *caller*
   brackets a call whose callee allocations are all provably bound by the region, using the
   `rt_arena_hint_push/pop` mechanism that already exists for runtime-internal allocation. Needs a
   per-function summary ("does this function allocate anything outliving its return value") and the
   container-disposition half, which is still unbuilt and still a use-after-free if done alone. This
   is the cheap subset of INFERENCE §6–7 and it is what the two designed halves were reaching for.
2. **Hot/cold split.** Unchanged from the last handoff: 0.87× measured, emittable today, no missing
   mechanism. Still the largest thing not blocked on anything.
3. **Inline element storage for `List<T>`.** Worth 1.09×–8.88×; would also delete most of g2's
   remaining gap, which item 1 is competing for.
4. **Port LAYOUT 5's cost model.** Precondition for §7.2 as written and for §8's ranking.

---

## Session of 2026-08-13 — `workload` lands; two of LAYOUT 6's dimensions are not blocked on what the brief said

**Read this section's first two paragraphs before the brief for your own session.** The brief for
this one opened by stating handles landed in "session 2", which is the second consecutive brief to
say so and the second time it is false. `ptr_to_node` is still `return ptr`, there is no handle table
in `src/` or `runtime/`, and the only 13 occurrences of "handle" in `src/` are comments. The
2026-08-09 section below records the identical correction against the identical claim.

**And HEAD did not compile, again.** `901b494` added a stray empty `/* */` block at
`src/parse/decl.psm:9`, in a language with no block comments. Every binary in `build/` failed on it
identically. Four lines, deleted. That is the second time a committed tree could not build itself
(`f791ab0` was the first, two eaten spaces), and the second time no check caught it — **CI's first
step would have, both times.**

Suite **98/98** (was 96). Fixpoint holds warm and cold, cold == warm, the oracle agrees on 13
sources, source lists agree, seed refreshed. **68 of 68 compilable programs in `tests/` and
`aif/corpus/` emit byte-identical IR** before and after — the other 25 are the negative tests, which
compile by design in neither.

### 1. `workload` landed (LAYOUT 3, SPEC 11 item 7's fourth annotation)

```prismio
workload cell_traffic {
    setup   { let warm = build(50) }     // excluded from the counts
    measure { hot(cells) }               // the profiled region
    repeat  3
    weight  1
}
```

The build-time pipeline is: run AIF over the module, generate a **second** program whose `main` is a
driver, compile it, run it under a timeout with no argv, read the profile it wrote, then throw the
whole thing away and do the real build with the measured counts in place of the static estimate.

It works. `test_55`'s profile, measured:

```
field Cell.hits      12000  6150  0..40      <- 40x hotter than the cold traversal
field Cell.scratch    6000  6150  0..869
field Cell.label       300   150  0..49
field Cell.kind          0   150  1..1
```

and the measured build puts `hits` and `scratch` at slots 1 and 2 where the static build scatters them
to 1 and 4. **That difference is the test.** Six things to know:

- **`workload` is contextual, not reserved**, unlike `region`. `region` opens a *statement*, where an
  identifier followed by a block is otherwise an expression statement; at top level an identifier
  cannot start a declaration at all, so there is no ambiguity to resolve and reserving the word would
  break `let workload = 5` for nothing.
- **W1 holds by absence, not by a guard.** Every top-level walk in codegen keys on
  `== NodeKind.FUNCTION`, so a workload is skipped everywhere without a single new check, and the
  `rt_profile_*` declarations are emitted *only* in a driver. The shipped IR contains no call to them
  and no declaration of them, so there is nothing for a later pass or a linker to resolve.
- **W4 holds because the profile has exactly one consumer.** It reaches codegen through
  `aif_layout_select`'s field counts and nothing else, and a layout is not observable. This is
  checkable by reading one assignment: `irSetProfileMode` is set true in one place.
- **The instrumentation is beside `ir_struct_field_ptr`, not inside it**, and the previous handoff's
  suggestion to put it inside is the one thing it got wrong. A GEP is the same instruction for a read
  and a write; only the caller knows which, and LAYOUT 2.1 wants `read(f)` and `write(f)` as separate
  columns. There are five call sites and two of them — the generated `__aif_release_T` and
  `__aif_cyclic_children_T` — are deliberately **not** counted: that is the memory model's own
  traffic, and counting it would let the layout decision be driven by the cost of the layout decision.
- **W3's sandbox is mostly codegen's, and the test is provenance rather than a blacklist.** A workload
  can declare `extern fn system(...)` like any other program, so every extern the Prismio runtime does
  not itself define is given a *stub definition* — `rt_workload_stub`, warns once, returns zero —
  instead of a declaration the linker would resolve against libc. A blacklist of dangerous names is
  wrong the first time someone names one nobody listed; "is this ours?" is closed. What is left for
  the runner is argv (empty, so a workload cannot see how the build was invoked), the working
  directory, and a 60-second bound.
- **`prismio aif` runs the workload too, and that is deliberate.** The manifest has to describe the
  build. This is the `owned_collections` trap in a new place — that default made `prismio aif` analyse
  one language while `prismio build` compiled another, both answers were true, and two sessions of
  notes were written off the wrong one. A declared workload changes the `layout` column, so the
  reporting command has to pay for it. It does: `prismio aif` on a program with a workload is now as
  slow as a build.

**One cost worth knowing before you use it.** A driver links the runtime **from source** rather than
against an installed `runtime.lib`, because an installed one may predate `rt_profile_*` — the same
shape as `--verify`'s reason, but about vintage rather than behaviour. So a build with a workload
compiles the runtime twice. It is opt-in and build-time.

**Two defects in this feature, both found after it "worked", both worth the shape rather than the
detail:**

- **The timeout was a floor, not a ceiling.** `compiler_run_workload` backgrounds a
  `(sleep N; kill $p)` watchdog, and the subshell inherited the compiler's stdout. Any caller
  capturing our output — the test runner, any CI — waits for EOF, and EOF needs *every* writer to
  close, so a driver that finished in 40 ms still blocked the reader for the full 60 seconds. It
  presented as the suite hanging with nothing using CPU. The watchdog's redirections
  (`>/dev/null 2>&1 </dev/null`) are the fix and are load-bearing.
- **Four early returns skipped the state restore, and one of them could have broken the shipped
  program.** `runWorkloadProfile` leaves three things behind — the workload build mode, the verify
  mode it cleared, and a struct registry the driver's own `generateModule` filled. W2 means most of
  its exits are failures. `generateStructDecl` returns early on an already-registered struct, so a
  workload that merely *failed to link* would have made the real build skip every struct body.
  Every exit goes through `endWorkloadPass` now, and `run_workload_test` asserts it: a workload that
  exits non-zero must warn, fall back, **and leave a program that still prints the right answer.**

### 2. Two of LAYOUT 6's four remaining dimensions were never blocked on handles

Full measurements in [`aif/evidence/RESULTS-layout.md`](aif/evidence/RESULTS-layout.md). The short
version, from `aif/evidence/bench/layout_repr.c` on g1_particles' shape:

| | rel. to today | needs |
|---|---:|---|
| boxed AoS — what is emitted today | 1.00× | — |
| **boxed hot/cold** | **0.87×** | **nothing** |
| inline AoS | 0.86× | inline `List<T>` |
| inline hot/cold | 0.66× | inline `List<T>` |
| SoA | **0.35×** | handles |

- **Hot/cold does not need handles and pays 13% today.** The cold block hangs off the hot record, so
  one pointer still reaches the object. I predicted it would be neutral on a pointer-vector runtime —
  reasoning from LAYOUT 5's `footprint = N · resident`, which assumes contiguity — and **the
  measurement refuted that**: the hot record goes 96 → 72 bytes and the allocator packs smaller blocks
  closer together. Not built, by an explicit scope decision: a second allocation behind every object
  touches all five allocator hooks, and T3 is where it cracks, because `rc_release` frees one block
  and cannot name the type.
- **Bit-packing is blocked by the specification, not by codegen.** LAYOUT 2.1 makes `range(f)` dynamic
  and says it enables packing; LAYOUT 3.2's W4 says two builds with different profiles must be
  behaviourally identical. **Both cannot hold**: an observed range is not a bound, so narrowing an
  `Int` that held `0..40` breaks on the input that stores 300. Upper bound if it were legal and free:
  **9.4% of struct bytes**, 12 of 48 structs, against a field-order search that shrank exactly one
  struct in the whole corpus. Resolving it needs a value analysis or a fifth annotation, and a fifth
  annotation is a governance change (SPEC 11 item 7 fixes the count at four). The compiler emits the
  measurement as **advice** at the foot of the manifest rather than acting on it.
- **SoA needs handles** (a reference becomes `(base, index)`) and **handle width is vacuous without
  them** — there is no handle to narrow, so it is not deferred, it is not a decision.

### 3. The harness re-run: no movement, which is the correct answer, and one thing it exposed

`python3 aif/evidence/xlang/bench.py --compiler build/f3 --runs 20`, against the committed baseline:

| | loop ms, baseline | loop ms, now | Δ | rel. idiomatic Rust |
|---|---:|---:|---:|---|
| g1 | 26.3 | 26.6 | +1.0% | 1.42× → 1.41× |
| g2 | 103.4 | 104.4 | +0.9% | 5.57× → 5.68× |
| g3 | 51.4 | 51.2 | −0.4% | 1.12× → 1.11× |
| g4 | 67.6 | 67.8 | +0.3% | 3.09× → 3.07× |
| g5 | 78.6 | 77.7 | −1.2% | 2.66× → 2.61× |
| g6 | 233.3 | 223.8 | −4.1% | 4.22× → 3.98× |

**Nothing moved, and nothing should have.** Neither SoA nor hot/cold landed — the brief named them as
the levers for pointer-chasing and neither is in the tree — and every corpus program compiles to
**byte-identical IR** before and after this session, including the fourteen under
`aif/evidence/xlang/` and `aif/evidence/bench/` that the `tests/` + `aif/corpus/` check does not
cover. So this is a regression check that passed, not a result.

**The table above spans several sessions**, because the committed baseline was taken with `gen4` and
the corpus sources changed in `901b494`. The true A/B for *this* session is the pre-session compiler
against the post-session one, both measured back to back on an idle machine:

| | loop ms, `s5c` | loop ms, `f3` | Δ | pre-run spread |
|---|---:|---:|---:|---|
| g1 | 26.2 | 26.5 | +1.1% | ±30% |
| g2 | 101.4 | 104.6 | +3.1% | ±15% |
| g3 | 49.6 | 50.3 | +1.3% | ±5% |
| g4 | 66.0 | 67.2 | +1.8% | ±12% |
| g5 | 77.1 | 77.7 | +0.8% | ±2% |
| g6 | 222.8 | 226.1 | +1.5% | ±8% |

Geometric mean against idiomatic Rust **2.540× → 2.580×**. Peak RSS is unchanged to 0.02 MB,
allocation counts are identical to within 205 on 15 million, and binaries grew 0–1 KB (the
never-called `rt_profile_*` code).

**Every delta is inside the run-to-run spread of a single run, but all six have the same sign**, and
that is worth saying rather than rounding away. The two runs were sequential, so ordering and thermal
drift are the obvious explanation, and the decisive evidence that no *code* changed is upstream of
the timer: byte-identical IR, unchanged allocations, unchanged RSS. If a future session wants the
sign settled, interleave the two arms rather than running them back to back.

**What it did expose is a measurement-hygiene defect in the harness, and it is not this session's.**
The `allocs` column moved by an order of magnitude on four programs — g1 2,214 → 26,326, g3 5,675 →
45,737, g4 7,760 → 47,896, g5 2,266 → 22,279 — with loop time unchanged. Chased to the cause:
commit `901b494` rewrote the corpus's reporting loops from `println_int` to the overloaded
`println`, which allocates a `String` per call. g1 prints 6,002 integers and gained 24,112
allocations: **4.02 per print, exactly.**

The allocations are real and they are *outside the measured region* — the reporting loop runs after
the frame loop — which is why the timing is untouched. But it means **the harness counts allocations
for a region it does not time**, so the `allocs` column and the `loop ms` column describe different
parts of the program, and the two runs' allocation figures are not comparable. Anyone quoting
"allocations per second" off this table is dividing reporting overhead by frame time. Fix the
harness before the next allocation claim, not after.

### 4. LAYOUT 8 is behind §7.2, not behind the runner

§8 reads as though it needs a way to compile and run a workload at build time, which now exists. It is
still not implementable, and the blocker is upstream: §8 ranks "the top-`k` candidates … by modelled
cost", and **this compiler has neither a cost model nor candidate enumeration.** §7.2 specifies
`argmin over candidates(τ) of Cost(…)`; `aif_layout_select` is a greedy best-fit placement that
produces exactly one layout and never scores it. LAYOUT 5's cost model exists only in
`aif/prototype/layout.py` and was never ported. So "top-`k`" names a set with one member.

The genuinely new half of §8 — a build-time instrumented compile-link-run, sandboxed and bounded — is
done and is reusable verbatim once the cost model lands.

### Four things to carry forward

- **A brief is not a source.** Two consecutive briefs asserted handles had landed; both were checked
  in under a minute (`ptr_to_node` is `return ptr`) and both were wrong. The check is cheaper than any
  work that would have rested on it.
- **"Reach for the input before the mechanism" has an inverse, and this session hit it.** Twice now a
  *measurement* has refuted an argument from the cost model: λ was unreachable against a 512-byte
  ceiling, and hot/cold's contiguity argument was wrong by 13%. When the model says a thing cannot
  pay, price the experiment before believing it — `layout_repr.c` is 250 lines and took minutes.
- **A specification can be internally inconsistent, and the implementation is where that surfaces.**
  §2.1 and W4 cannot both be honoured. This is the second such finding (SimdCredit was the first), and
  both were found by trying to implement the clause rather than by reading it.
- **A discriminating fixture has to be built to discriminate.** `test_55`'s first draft declared
  `Cell`'s fields in frequency order, so the measured and static layouts came out identical and the
  test passed while proving nothing. The fields are declared hot-last now, and every field is 4 bytes
  so padding cannot decide anything — frequency is the only input left.

### Next, re-ranked on this session's measurements

1. **Hot/cold split.** 0.87× measured, emittable today, no missing mechanism. The T3 interaction is
   the whole risk and it is nameable: give a split type a generated release and route every free
   through it.
2. **Port LAYOUT 5's cost model** from `aif/prototype/layout.py`. Precondition for §7.2 as written, for
   §8's ranking, and for choosing a hot/cold cut by anything better than the frequency ranks.
3. **Handles.** Still costed at 337 dereference sites + 190 punned empty-slot tests. Worth 0.35× on
   g1's shape — more than everything else here combined, and still nobody has paid for it.
4. **Resolve LAYOUT 2.1 against W4** in the specification before writing the packing transform.

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

---

## Session of 2026-08-08 (measurement) — the first cross-language numbers, and the optimiser was never on

The corpus g1–g6 was ported to Rust (idiomatic / bumpalo arena / hand-tuned) and Swift, 29 programs,
all asserting identical checksums, and measured on every axis the project claims. Everything is in
[`aif/evidence/RESULTS-xlang.md`](aif/evidence/RESULTS-xlang.md); the apparatus is
[`aif/evidence/xlang/`](aif/evidence/xlang/README.md) and re-runs in one command:

```bash
python3 aif/evidence/xlang/bench.py --compiler build/gen4 --runs 20
```

**One compiler change landed, and it is a build-flag fix, not a design change.**

### The defect: `prismio build` ran no optimiser, on either stage

- `compile_ir_to_object` ran `llc <ir> -filetype=obj` with **no flags**. llc runs the codegen pipeline
  but *not* the IR pipeline, so mem2reg, SROA, GVN, LICM, inlining and vectorisation never touched a
  user program. In the emitted IR for `integrate`, `p` was reloaded from its stack slot **five times**
  inside one `p.px = p.px + p.vx * dt`.
- `build_from_toolchain_sources` compiled the runtime with **no `-O`**, i.e. -O0 — and that is where
  `list_get`, `list_push` and the allocator live.
- `tools/bootstrap.sh` and `.ps1` did the same, so the compiler itself was built unoptimised.

All three now pass `-O2`, and the IR step uses `clang -O2 -c` rather than `llc` (clang runs both
pipelines in one process, was already needed for the link, takes `.ll` directly, and this drops llc
from the user-build path). Verified: **fixpoint warm and cold, cold == warm, 92/92, and the emitted
IR is byte-identical to the pre-change compiler's** — the right outcome for a build flag. No seed
refresh needed; the FFI surface did not move.

| | |
|---|---|
| worth | **1.43×–2.91×** on the corpus (`optgap.py`, checksums identical in all four cells) |
| costs | cold compile ~140 → ~190 ms per program (+35%) |
| saves | executables 56 → 39 KB (−30%); the compiler's own frontend 103 → 80 ms (−22%) |

**`-O3` was measured and rejected** — 0.98×–1.03× of `-O2` across the corpus, i.e. noise, at the same
compile time (`optlevel.py`). `-Os` likewise. `-flto` is speed-neutral and worth ~15% of binary size
but needs linker plugin support that is not portable enough to default to.

### Where Prismio stands, after the fix

**1.12×–5.57× idiomatic Rust; 1.7×–17.9× hand-tuned Rust.** Every speed projection in BENCHMARKS §4
is falsified; §4.2's kill criteria for object graphs and data-parallel bulk are both met. The gap now
has two parts:

1. **The representation.** `List<T>` is a vector of pointers to individually malloc'd records; `Vec<T>`
   stores inline. Measured by holding it fixed in Rust (`g1_boxed.rs`, `g2_boxed.rs`, `g4_boxed.rs`):
   costs **1.09×** on a 96-byte record, **2.58×** on 24-byte components, **8.88×** where the record is
   allocated per frame. This is now **the whole remaining gap on four of six programs**.
2. **A residual of 1.20×–1.30×** — with the representation held constant this compiler is within a
   quarter of rustc. The only figure that is a statement about the design. On g2 it is **0.63×**:
   Prismio beats rustc's own code for the same allocation profile.

Two results went the other way and are worth keeping: **p99/p50 is 1.22–1.75 against a 3× kill
criterion, within 0.04 of idiomatic Rust on five of six programs**, and p999/p50 is *lower* than
Rust's on all six — the model adds no tail of its own. **Peak RSS is 0.84–1.00× of idiomatic Rust**,
against a 1.0–1.2× prediction, because per-object allocation has no geometric slack.

**Four of six corpus programs allocate nothing per frame** (g1, g3, g4, g5), so the memory model
cannot help on two thirds of the corpus. On the two that do, the arena is worth **9.9× on g2**.

### Four things to carry forward

- **The internal control cannot see a missing optimiser.** `--debug` was built to isolate AIF and it
  does — which is why it never caught this: both sides of that comparison had the same -O0 runtime and
  the same unoptimised IR. **A control that holds everything constant cannot detect what is constantly
  wrong.** Every speed number this project recorded before today was taken against a baseline sharing
  the defect.
- **"Reach for the input before the mechanism" got its fourth outing, and the input was a build flag.**
  Twice a missing declaration, once a stale default, now two `-O` flags that were never there.
- **A prediction is also a claim about the baseline.** "Allocator churn 0.2–0.5×" was wrong by ~100×
  not because AIF underperformed but because `Vec<T>` had already deleted that cost by inline storage.
  Restate any allocator claim against inline-storage containers or it measures nothing.
- **Do not let one measurement of a representation stand for the class.** The boxed diagnostic reads
  1.09× on g1 and 2.58× on g4. Assuming g1's answer would have attributed g4's gap to the backend.

### The `region` annotation is inert on g2, and that is the sharpest result here

The language is not inference-only — `region`, `unique`, `pin`, `drop` exist so a programmer can tune
a hot scope by hand. That escape hatch was measured for the first time.
`aif/evidence/xlang/prismio/g2_region.psm` is `g2.psm` with `region frame_arena { … }` around the
frame body and nothing else changed:

| | plain | `+ region` |
|---|---|---|
| loop time | 101.3 ms | **175.5 ms (1.73×)** |
| allocations served by the arena | — | **0 of 10 201 215** |
| regions entered | — | 20 000 |
| manifest | T2 owned ×4 | **byte-identical** |

**Not unimplemented — inert.** The region is created and destroyed 20 000 times and serves nothing,
for the cause already recorded above: `aif_arena_at_node` rejects on `in_container` *before* it looks
at escape, and g2's `DrawCmd` reaches `list_push` with `retain_in(0)`. The exclusion is correct in
itself; it fires regardless of what the programmer asked for.

The 1.73× is ≈7 ns per allocation over 10.2 M, which points at a per-allocation arena check that is
paid then declined rather than at the 20 000 push/pops. **Inferred from the arithmetic, not proven** —
confirm before optimising.

Two consequences:

- **The `CallerRegion` + container-disposition item unblocks both tiers, not just inference.** That
  changes its value: it is the only thing standing between users and *any* working tuning story on
  container-bound values.
- **`region` should warn when it serves zero allocations.** Today a user writes the annotation, reads
  a manifest that says nothing changed, and gets a 1.73× slowdown with no diagnostic.

### Next, re-ranked on this session's measurements

1. **Inline element storage for `List<T>`** — the `Vec<T>` representation, which needs views/slices to
   be expressible. Worth 1.09×–8.88× depending on the record, and RESULTS-xlang §9 projects it lands
   Prismio at **~1.2–1.3× of idiomatic Rust across the board**. Bigger than anything previously on
   this list, and a prerequisite for the layout work.
2. **Caller-scope `E` plus container disposition** (designed two sessions ago, still not built).
   Measured prize **up to 9.9× on g2**, ~0 on four of six programs. Large and narrow — and it partly
   overlaps item 1, which removes most of g2's allocations by itself. **Re-valued upward by the
   `region` result above**: it is what makes the annotation tier work at all, not only the inference
   tier. Consider shipping the zero-allocation warning ahead of it, since that is cheap and the
   current silence is a user-visible trap.
3. **Layout search / SoA.** The largest measured headroom in the suite: `g1_tuned.rs` is *pure* SoA
   with no arena and no algorithmic change and runs at **0.26×** of idiomatic Rust. That is the only
   measured path to *beating* Rust rather than matching it, and it is the first evidence for
   BENCHMARKS H2's budget rule. Still blocked behind handles.
4. **Concurrency + T-domains: unmeasurable today.** The corpus is six single-threaded programs. Any
   ranking of it would be exactly the kind of unmeasured projection this session spent its time
   falsifying — the corpus needs a concurrent program first.

RESULTS-xlang §9 works the "can we beat Rust" question through end to end. Short version: parity with
idiomatic Rust is the realistic target for items 1–2; item 3 is the only large win available; beating
*hand-tuned* Rust is not on the table, because `g5_tuned` at 0.15× is an algorithmic change no memory
model produces.

---

## Session of 2026-08-09 (second) — views: the safety half landed, the speed half was somewhere else

Suite **94/94** (was 92). Fixpoint holds warm and cold, cold == warm, the oracle agrees on 13
sources, source lists agree, and **65 of 65 programs in `tests/` and `aif/corpus/` compile to
byte-identical IR** — the only program whose output changes is the new fixture that exercises the
new rule. **The seed did not need refreshing**: no new syntax, and the FFI surface only grew
(`aif_vs_view_of`, `str_slice`), so the committed seed still parses `src/` and still links. Cold
start from it verified.

**Read the brief for this session with two corrections.**

- **Handles did not land.** The brief said they had, in "session 2". HEAD was the xlang-measurement
  merge, the tree was clean, there is no handle table anywhere, and `ptr_to_node` is still
  `return ptr`. The previous section of this document says so too. Nothing here depends on them,
  and §1 below explains why views did not need them.
- **"209 T1 string sites" is stale.** It is **266**, of which **264** are arena-served. More
  importantly the number is the wrong measurement — see §3.

### 1. SPEC 8.4's E-VIEW landed, and it closes a real use-after-free

`list_get`'s result is a view of its container, and the container's escape now rises to cover it:

```
E-VIEW    v is a view of c    ⟹    E(c) ⊒ E(v)
```

**The bug it closes was live in the shipping compiler.** `tests/test_53_aif_views.psm`'s
`view_escapes_by_return` compiled, before this session, to:

```llvm
%12 = call ptr @list_get(ptr %11, i32 0)   ; take a reference into the list
call void @list_release(ptr %13)           ; free the list AND its elements
ret ptr %12                                ; return the freed pointer
```

It ran, exited 0, printed **0 and 0** where the answers are 7 and 41, and reported
`17 allocated, 17 released, 0 leaked, 0 violation(s)`.

**`--verify` cannot see this class of bug, and that is worth carrying forward.** Its accounting is
per allocation, and here every allocation *was* correctly released — reading one afterwards is a
different property. This is "a check that cannot fail" in the sense rule 5 already records, reached
from a new direction. The fixture asserts its values itself for exactly that reason, and exits 1 on
the old compiler.

Four things about the implementation, three of which are corrections of an earlier attempt:

- **It is provenance, not a points-to edge, and not a constraint.** The element key stays exactly
  what it was — a points-to edge saying *which values* a read returns. Provenance rides beside it
  saying *how long the container must live*. Merging them is the bug this reconciles: putting the
  container into the element set is what list_get used to do, and it made a receiving container call
  `list_release` on a struct.
- **Provenance must ride the points-to graph, not the value set.** A view is nearly always bound to
  a name before it travels, and `return e` sees the value set of `e`, not of the `list_get`. So a
  key accumulates the provenance of everything bound into it (`key_views`), grown in the points-to
  phase because it reads no fact.
- **The rule rides the rules that already bound a value's lifetime** — LIVE_IN, ESCAPE_CALLER,
  ESCAPE_GLOBAL, OPAQUE, STORE, RETAIN_IN — rather than being its own constraint. The direction is
  the opposite of every other rule in the solver: the *collection* is raised from the view.
- **A is deliberately untouched.** SPEC 8.4 permits overlapping mutable views.

**Three over-firings, each caught by measurement, each now a named control in `test_53`:**

| what it coupled | cost, measured |
|---|---|
| reading the element key directly | 9 sites T1 → T2; the key is object-insensitive, so a read from any list was a view of every list in the file. Demoted three untouched containers in `test_47`. |
| treating a scalar read as a view | `test_50`'s `List<Int>` demoted for returning an `Int` — a copy in a register that keeps nothing alive |
| bounding by "the caller" across a function boundary | `g5_asset_cache` lost its `list_release` for a view taken in a callee, which cannot outlive the activation it was taken in |

The last one is a **case analysis, not a shortcut**, and it is written at the site: a Region target
names a scope of the binding's function, so when the collection was allocated elsewhere it reached
that function as an argument (live across the call already), as a return (E-RETURN has it at Caller),
or from static storage (E-STATIC has it Global). All three are already implied. A view that really
outlives the callee arrives with a function-independent target instead.

**Net effect on the corpus: zero sites move.** g1–g6, test_47, test_48, test_50, test_52 and
`src/main.psm` are all untouched, and `test_53` moves exactly two. That is the correct answer, not
an inert one — and it is why the fixture had to go into `tools/aif_differential.py`. Without it both
arms would have agreed *by never running the rule*. Verified discriminating: the pre-session compiler
disagrees with the current oracle on exactly those two sites.

**The cost is 7 leaked allocations in `test_53`, and it is SPEC 8.4's stated trade** — the collection
sinks a tier, and a T2 return has no free point in this compiler. A leak instead of a use-after-free
is the sound direction. If that number drops, the container is being freed under a live reference
again, and only `test_53`'s own exit code says so.

**Handles were not needed, and the reason is a fact about the runtime.** A `List` is two
allocations: the `XefyList*` handle, which is stable, and `data`, the element block, which is what
`list_push` reallocs. So `(XefyList*, index)` already satisfies SPEC 8.4's invalidation clause
verbatim — "reallocation moves the buffer; the handle still resolves". What general handles would
additionally buy is object relocation and SoA element references, and SoA was out of scope.

### 2. The speed half: it was never the malloc

**`str_substring` cannot be linear.** A `String` is a NUL-terminated `char*`, so bounding `start` and
clamping `length` costs `strlen(s)` — the whole source, **once per token**. Measured on a 21 KB
buffer: **1.815 ms with the call, 0.031 ms with it removed — 98% of the tokenizer** — and doubling
the input multiplies the time by ~2.9 rather than by 2.

**This is the same defect `str_char_at` had, and half the fix was already in the tree.**
`createLexer` measures the input once into `Lexer.length`, and the comment there says why: a
per-character `strlen` made scanning quadratic. That fix reached the character reads and never
reached the slices, which is where the tokens are cut.

`str_slice(s, start, length, base_len)` takes the length the caller already has. One runtime
function, five call sites in the lexer.

| | before | after |
|---|---|---|
| g7 tokenizer, 21 KB | 1.833 ms | **0.074 ms** (24.8×) |
| the compiler's own frontend on `src/main.psm` | 78.0 ms | **62.1 ms** (−20%) |
| scaling, per doubling of input | ×2.9 | **×1.8** |

### 3. The cross-language numbers, and the axis that did not exist

**The harness had no string/parse workload.** g1–g6 are object-graph and numeric; BENCHMARKS §3.2
lists this one as **B2** and marks it buildable; it was never built. The "1.1–1.4× Rust for
string/parse" the brief asked for a delta against **is not recorded anywhere in this repository** —
there was nothing to re-run and no projection to compare with. So the axis was built:
`aif/evidence/xlang/{g7bench.py, prismio/g7.psm, prismio/g7_substring.psm, rust/g7_idiomatic.rs,
rust/g7_owned.rs}`, all asserting `checksum tokens 427914`.

| | median | rel |
|---|---:|---:|
| Rust idiomatic — `&src[a..b]`, no copy | 0.019 ms | 1.00× |
| Rust owned — copy per token | 0.103 ms | 5.49× |
| **Prismio — `str_slice`** (today) | **0.074 ms** | **3.92×** |
| Prismio — `str_substring` (before) | 1.833 ms | **97.31×** |
| Prismio — scan only, slicing removed | 0.031 ms | 1.78× |

Full write-up in [`aif/evidence/RESULTS-string.md`](aif/evidence/RESULTS-string.md). Three readings:

- **Prismio was 97× idiomatic Rust on string-heavy code** — by an order of magnitude the worst
  number this project has recorded, on the one axis nothing measured.
- **With the representation held constant this compiler beats rustc**: 3.92× against Rust-doing-the-
  same-copy at 5.49× is **0.71×**, the same shape as g2's 0.63×. The scan-only row agrees
  independently at 1.78×.
- **The whole remaining gap is the copy** — 3.92× against 1.78×, so ~2.2×. That is what a view
  deletes, measured rather than projected.

**The manifest did not move at all: 367 sites, 266 T1 / 101 T2, byte-identical.** Not one allocation
site disappeared, and the reason is the correction to the brief's question. The lexer's five
per-token slice sites are **T2 `owned`** — malloc — not among the 264 arena-served T1 at all. A T1
site is already a bump allocation and costs nearly nothing. **Views target the T2 population; the T1
count was the wrong measurement of the right thing.** And `str_trim` has **no callers** — one mention
in a comment — so making it non-allocating buys nothing and was not done.

### Four things to carry forward

- **"Reach for the input before the mechanism" got its fifth outing, and this time the input was a
  length.** Twice a missing declaration, once a stale default, once two `-O` flags, now a parameter
  that the caller already had in a struct field with a comment explaining why it was there.
- **A fix can land on half of its own instances and read as complete.** The `Lexer.length` comment
  states the principle correctly and the slices went on rescanning for however many sessions. Grep
  for the *other* callers of the thing you just fixed.
- **An unmeasured axis is not a small risk.** Six benchmark programs and not one of them touched a
  string, in a project whose flagship program is a compiler. The gap there was 97×, and it was
  invisible because nobody had a row for it.
- **A rule that fires everywhere passes the positive half of its own test.** E-VIEW's first three
  implementations all made `test_53`'s two escaping functions T2 and were all wrong. The controls
  are the test.

### Next, re-ranked on this session's measurements

1. **Views proper — the `(base, offset, length)` value — together with by-value POD returns.**
   They are the same project: a view is three words and this language has no by-value struct return,
   which is exactly the chain designed-and-not-built last session, ending at "the call expression
   must become an AIF allocation site in the caller" with a use-after-free failure mode. Now carries
   a measured prize of ~2.2× on string/parse **and** the 1.09×–8.88× inline-`List<T>` prize, which
   is what makes it worth the risk. `str_slice` took the cheap 24.8× that needed none of it.
2. **Caller-scope `E` plus container disposition.** Unchanged, and E-VIEW gives it a second reason:
   `test_53`'s 7 leaked allocations are the T2-return class, and views make that class bigger.
3. **Handles.** Unchanged and still uncosted since last session's count. Views did not need them;
   SoA still does.
4. `workload`, SoA, hot/cold: unchanged, still behind handles.

---

## Session of 2026-08-09 — inline struct fields, and two measured non-results

Three items landed and handles slipped. **Two of the three moved no number, and that is the
finding in both cases** — read the measurements, not the fact that the code exists.

Suite **92/92** (was 91). Fixpoint holds warm and cold, cold == warm, seed refreshed twice (the FFI
surface grew `ir_copy_struct` and `ir_function_param_unique`), the oracle agrees on all 12 sources,
source lists agree. Compiler peak RSS **30.3 → 30.7 MB**.

> The 27.3 MB baseline quoted in the brief is not reproducible here: the pre-session binary measures
> **30.3 MB** by polling `PeakWorkingSet64` and refreshing once more after exit. All figures in this
> section use that method, so the deltas are comparable to each other and not to the 27.3.

### 1. Inline struct fields — landed, 4× fewer allocations, one regression

`aifTypeBytes` returning 8 for every struct was the *symptom*; the cause was `storageType`
collapsing `struct:T` to `ptr` for fields. The registry now keeps `struct:T`, so the LLVM body
embeds by value and every access reaches the field by GEP.

New fixture `aif/evidence/bench/g7_particles.psm`, same source through the old and new compiler:

| | allocations | median | layout |
|---|---|---|---|
| pointer fields | 80 015 | 175.8 ms | `%Particle = { ptr, ptr, ptr, double }` |
| **inline fields** | **20 015** | **129.1 ms** | `%Particle = { %Vec3, %Vec3, %Vec3, double }` |

**Inline is restricted to plain data** — a field whose type transitively owns nothing. Anything
holding a `String`, `List`, array or `T?` keeps a pointer, because an inline field has no allocation
of its own for `__aif_release_T` to free. `Crate.inner: Inventory` correctly stayed a pointer.

Five things worth carrying:

- **The containment/reference split was already in the language.** A scan of `src/`, `tests/` and
  `aif/corpus/` found **no** self-referential plain struct field: every recursive type already
  spells itself `T?`, which is a pointer. So plain = containment, `T?`/`List`/`[T]` = reference,
  and requiring containment acyclic rejects nothing that exists. `typeAnnIsPod` is defined **once**
  in `src/ast/types.psm` because codegen picks the layout and AIF sizes it — if they disagreed,
  Θ_stack would describe a different object than LLVM emits.
- **Layout had to reach construction, not just declaration.** The first build laid fields out inline
  and left the nested literal allocating, copying in, and abandoning — 22 leaks in test_49.
  `generateStructLiteralFields` builds an inline field *in place*, so `Particle { position: Vec3 {…} }`
  allocates nothing for the Vec3. That is also where the 4× comes from.
- **The inline decision must not read AIF.** It is taken from declarations alone. A layout that
  depended on the analysis would differ between `--debug` and a release build, and SPEC 7.2 requires
  a level to change no observable behaviour — two physical layouts for one program is the largest
  observable difference there is.
- **Trap 5 fired exactly as predicted.** `Inventory` lost a free because `lead: Slot` stopped being
  an allocation site. Baseline regenerated with the reason written at the expectation.
- **The interior pointer is real and escapes.** A struct-typed field read returns the GEP. SPEC 11
  item 5 forbids that escaping and nothing stops it, because references are raw `ptr`. Recorded at
  the site in `src/ir/expr.psm`, not papered over.

**The regression: `g3_scene_graph` 0 → 4095 leaked, 0 violations.** `make_node` writes
`Node { local: t, world: identity_transform(), bounds: unit_bounds(), … }`; all three are allocated
in a callee and returned. The pointer layout made `Node` their accidental owner, and copying removes
that without providing another. E-RETURN gives them `Caller` unconditionally, so they have no free
point — the pre-existing T2-return class, previously masked.

**It cannot be fixed by freeing the source after the copy.** `world_transform(w,h)` in the same
corpus is `return list_get(w.transforms, h)` — a struct-returning function that yields an *alias
into a container*. So "a struct-returning call produces an owned value" is false, and a guard built
on it is a double free. This is the same soundness note already recorded for String returns.

### 2. By-value POD returns — designed, deliberately not built

The fix for the above, and the reason it is not a codegen tweak. The chain, worked out against the
code:

1. A POD return by value means the callee's literal is copied out, so it must stop being an escape —
   otherwise it stays T2/heap and leaks exactly as now.
2. Once it stops escaping it is T0 in the callee, so the **caller** needs storage for the result.
3. That storage cannot be an alloca. `Node` is itself POD and `g3_scene_graph.psm:96` is
   `list_push(nodes, make_node(…))` — an alloca there stores a frame pointer into a container that
   outlives the frame. **Use after free.**
4. It cannot be untracked heap either: nothing would free it, so the leak moves rather than closes.
5. So the **call expression must become an AIF allocation site in the caller**, tiered like a struct
   literal — and identically in `aif/prototype/aif.py`, or the differential stops meaning anything.

Step 5 is a site *migrating across a call boundary*, which nothing in the current model expresses:
every site today is where a literal is written. It is the same shape as the caller-scope `E` item
below, and it has a use-after-free failure mode. `ir_copy_struct` and `LLVMBuildMemCpy` are already
in place for whoever picks it up.

### 3. A footprint term in the arena cost model — landed and provably inert

Added exactly as LAYOUT 4 writes it, with λ kept as the ratio 2/100 because the model is integer:

```
ArenaBenefit(s) = allocs_in(s)·(α_T2 − α_T1) − entries(s)·arenaSetupCost − λ·(bytes_held − peak_live)
```

`bytes_held − peak_live` is `Σ bytes·(weight − 1)`: exactly the bytes a scope allocates and abandons
while still holding them. **It changed no decision — 261 arenas before and after — for two
independent reasons, and the second is the interesting one:**

- Every arena-served site in the compiler is dynamically sized (`261 dynamically-sized site(s)
  excluded`). They are strings, so both new inputs contribute 0 rather than a guess — the same rule
  the peak-bytes report already uses.
- **At λ = 0.02 the term cannot fire in this compiler at all.** Break-even is
  `size > (α_T2 − α_T1)/λ ≈ 87/0.02 ≈ 4350` bytes per object, and the backend caps a struct at 64
  fields, so the largest struct expressible is **512 bytes**. The term is unreachable by
  construction, not merely unexercised.

λ was **not** retuned to make it bite. LAYOUT 4 states the constant; measuring it says the constant
is wrong for this cost model, or that the term should price something other than bytes. Inventing a
replacement would be fabricating the input.

**The chunk pool is trimmed, not removed** — `ARENA_POOL_MAX 8`, a 64 KB resident ceiling. Removing
pooling is what would stop automatic placement firing at all (a region serving one allocation would
pay a malloc and a free). Compiler peak RSS **30.7 → 30.7 MB, unchanged**: the pool high-water here
is ~1 chunk, because regions are entered and left sequentially so each pop's chunk is reused by the
next push. The unbounded pool was a theoretical risk for this compiler, not a measured one; the cap
makes the ceiling explicit without changing behaviour.

**The differential is not the safety net for this item.** The oracle does not model arena placement
and the differential compares tiers and counters only, so its agreement confirms tier-neutrality and
nothing else. Coverage was the arena counts, peak RSS and the corpus.

### 4. `unique` on a parameter → `noalias` — landed, guarded, win unproven

`unique` was **already parsed** on parameters (`parseParameter`, `param.i2`) and simply never
reached codegen. It now lowers through `ir_function_param_unique`.

**Governance:** this is a lowering of an existing annotation, so SPEC 11 item 7's four stay four and
nothing needed amending. Deleting it still changes no observable behaviour of a correct program.

**It needed a guard, and that is the part worth reading.** `noalias` makes `unique` the one
annotation whose falsehood is undefined behaviour rather than a lost optimisation. The axiom's local
half is discharged by the affine discipline, but parameters *borrow*, so `f(x, x)` is two perfectly
legal borrows handing one object to two parameters each asserting it is the only one.
`semaCheckUniqueArgs` rejects that; `neg_24_unique_aliased_args.psm` pins it. What it still does not
catch is aliasing through two different names — which is what `unique` being an axiom means, and is
why deleting it is always safe.

**Measured, and this is a non-result:** no reliable win on either shape tested.

| shape | plain | `unique` |
|---|---|---|
| callee inlined into the loop | 777.6 ms | 812.9 ms |
| loop inside the callee | 422.7 ms | 418.7 ms |

The first is inlined, after which LLVM already knows the two allocas are distinct; the second is
within run-to-run noise. The brief called this "the cheapest real codegen win available" — it is
certainly cheap, and it has not been shown to be a win. Whoever revisits it should find a shape
where the callee is *not* inlined and the aliasing question actually blocks a reorder.

### Handles slipped, and here is the cost that says why

Counted rather than estimated. COMPILER-AUDIT finding 6 said "~104 externs"; the refactor grew it:

| | |
|---|---|
| `extern fn` declarations naming `String`/`Ptr` (a raw pointer at the C boundary) | **235** |
| `ptr_to_node` / `node_to_ptr` and siblings — currently the **identity** on a pointer | 8 |
| `ptr_to_node(` / `nodeExists(` call sites, each one a dereference | **337** |
| punned empty-slot tests, `str_equals(x, "")` — "empty" is a zero first byte | **190** |
| runtime sites reading a header *in front of* a raw pointer (`rc_of`, T3's mechanism) | 1 |
| `--verify` accounting sites keyed on raw addresses | 12 |
| field-access choke points (`ir_struct_field_ptr`) — the one piece of good news | 1 |
| `src/` total | 10 217 lines |

The 190 punned tests are the real obstacle and they are not mechanical: with handles, "empty" would
become handle 0, which is *cleaner* than a zero first byte and would retire `test_41`'s invariant
rather than preserve it — but every one of those sites is a place where the current encoding is load
bearing, and `NodeKind`/`TypeKind` reserving ordinal 0 exists only to serve it. Handles are a
rewrite of how this compiler represents its own AST, not a change to how it emits code.

Item 1 makes this worse, not better, and that should be said plainly: inline fields create interior
pointers, which is exactly what handles exist to prevent, so the debt grew this session.

### Next, re-ranked on this session's measurements

1. **By-value POD returns**, via the AIF site migration in §2. It closes g3's 4095 leaks, removes the
   last allocation from the inline-field win, and is the only item here with a measured prize.
2. **Caller-scope `E`** (previous session, still designed-not-built). Same shape of change, and the
   two would share most of the machinery — do them together or do §1 first and reuse it.
3. **Handles.** Costed above. A project, and now a slightly larger one.
4. `workload`, SoA, hot/cold: unchanged, still behind handles.

### Three things to carry forward

- **A layout change reaches construction.** Laying a field out inline and leaving the initialiser
  allocating produced a program that was correct, slower, and leaked — the copy took ownership of
  nothing. Any change to where a value lives has to be followed to where it is *made*.
- **Read the gate before designing for it.** The caller-scope `E` fix was fully designed last
  session and would have emitted a byte-identical binary, because `aif_arena_at_node` rejects on
  `in_container` before it ever reads escape. Same lesson twice now: the clause you are aiming at is
  rarely the only clause.
- **Two of three items here moved no number.** Both were implemented exactly as specified and both
  are inert for reasons only measurement could give: λ is off by an order of magnitude against a
  512-byte ceiling, and `noalias` is redundant wherever LLVM has already inlined. Implementing a
  specified thing is not evidence that it pays.

---

## Session of 2026-08-08 — the tree did not compile, and the T3 residue was never real

Four things, in the order they have to be read. **Nothing in the "Next, in order of measured value"
list below survived contact with measurement**, so read this section before that one.

### 0. HEAD did not compile, and that is not in any previous handoff

Commit `f791ab0` "Humanised" refactored `src/` into directories and renamed every identifier to
camelCase — so **the file-roles table above is stale** (`src/sema.psm` is now `src/sema/`, `src/ir.psm`
is `src/ir/`, `src/aif.psm` is `src/aif/`, and so on). That commit also left two eaten spaces:

| | |
|---|---|
| `src/sema/flow.psm:43` | `NodeKind.WHILE_STATEMENTorstmt.kind` |
| `src/sema/flow.psm:100` | `andelseDiverges` |

`59a0960` has ` or ` and ` and ` in both places, so this is corruption introduced by the rename and
not a design change. Two-line repair. **The committed tree could not build itself for a whole
commit, and no check caught it** — CI would have, on its first step.

A scan for glued keywords across `src/` found only these two (everything else it flagged —
`initValue`, `expectedReturn`, `astRoot` — is a real name). The compiler is the reliable detector.

### 1. The 79 T3 sites were a stale reporting default, not a residue

**Both claims in this document were true; they were about different runs of the same binary.**

`site_is_move_only` gates `String`/`List` behind `owned_collections`. `prismio build` has always
passed `true` (`aifRun(mergedAst, true, ..)` in `compileSource`). The `aif` *reporting* command
defaulted it to **false** — the pre-Level-4 language, where strings are copyable, so A-COPY fires on
any string site with two holders. Same binary, same source, same day:

| `prismio aif src/main.psm` | T1 | T2 | T3 |
|---|---|---|---|
| default, as it was (copyable) | 260 | 18 | **82** |
| `--owned-collections` (what `build` uses) | 260 | 100 | **0** |

So the manifest — the thing SPEC item 8 exists to make the build describable — was describing a
binary nobody builds, and `--why`'s "the answer describes the build a plain run would give" was
false. **Two sessions of handoff notes were written off that number.**

The archaeology, because the arithmetic in the FFI section above is still worth trusting. The
compiler *of that era*, rebuilt from `40438a7`'s own seed, reports 324 sites with T3 = 107 =
**37 E-OPAQUE + 70 A-COPY**. The twelve declarations did exactly what that section claims —
E-OPAQUE 37 → 0, reproducible — but it reported that subset as the whole T3 population. The 70
A-COPY were the flag, and were never counted.

**The default is inverted now**, in `src/main.psm` and identically in `aif/prototype/aif.py`.
`--copyable-collections` selects the old model and **the differential's second arm passes it** —
without that the two arms run the same analysis and agree by construction, which is worse than one
arm. Verified that the arms still differ (0 T3 vs 82 T3) and that a misspelled flag is still
rejected.

`prismio build` output is **byte-identical** across all 16 programs in `tests/` and `aif/corpus/`
before and after. Only the report moved.

### 2. What ownership contexts would buy, measured

The upper bound, from the derivation's own maximal contributor (`--why`) over every site. A site can
only be improved by contexts if its fact crossed a call boundary — E-RETURN, A-CALL, E-OPAQUE,
A-RETAIN; everything else is decided inside one function and is already as precise as it will get.

| | sites | call-boundary-determined | what they would become |
|---|---|---|---|
| `src/main.psm` | 360 | **41 (11%)** — all E-RETURN | all T2 → T1 |
| corpus g1–g6 + test_47/48 | 73 | **27 (37%)** | all T2 → T1 |

**Not one site would move to or from T3.** Contexts buy no correctness on this corpus, confirming
the previous session's re-ranking, and they buy exactly one transition: T2 → T1.

**The mechanism is not a join, and this is the part worth keeping.** E-RETURN raises to `Caller`
*unconditionally*. A struct allocated in the scope that consumes it is **T0**; the same struct
returned from a function with **exactly one caller** is **T2**. There is no caller disagreement to
blame — `E` simply has no value meaning "the caller's scope", which is the third of the three
recorded limitations, and it is the whole of the effect.

**The bound is loose in the other direction.** Realising it needs the transfer to survive more than
one hop. In `g3_scene_graph`, `identity_transform()` and `unit_bounds()` are stored into the `Node`
that `make_node` returns, so they escape onward; only `build_hierarchy`'s list dies in its immediate
caller. **1 of 4 at k=1**, against 4 of 4 in the bound.

**The element-key cliff is smaller than recorded.** The audit says merging `test_47` and `test_48`
makes all seventeen of test_47's sites T3. Measured: **10 of test_47's 14 sites** move T2 → T3
(3 T1 sites and 1 T2 are untouched). Real cliff, overstated number.

### 3. The benchmark, and it falsifies a claim the corpus makes about itself

`aif/evidence/bench/` — four baselines in BENCHMARKS §3.2's order, ≥30 runs, median and p99.
Peak RSS is beside the time because the control is not like-for-like on memory.

```bash
python aif/evidence/bench/bench.py --runs 40
```

| G2 frame loop | median | p99 | rel | peak RSS |
|---|---|---|---|---|
| C `-O2` idiomatic | 633.1 ms | 728.6 | 1.00× | 3.9 MB |
| **C `-O2` arena** | **56.1 ms** | 79.3 | **0.09×** | 3.8 MB |
| Prismio (inference) | 774.4 ms | 880.2 | 1.22× | 3.9 MB |
| Prismio `--debug` | 709.1 ms | 775.0 | 1.12× | **392.2 MB** |

| G6 engine+gameplay | median | p99 | rel | peak RSS |
|---|---|---|---|---|
| C `-O2` idiomatic | 1042.0 ms | 1126.2 | 1.00× | 4.0 MB |
| **C `-O2` arena** | **310.0 ms** | 366.6 | **0.30×** | 4.0 MB |
| Prismio (inference) | 1640.4 ms | 1778.5 | 1.57× | 4.1 MB |
| Prismio `--debug` | 1847.4 ms | 2009.8 | 1.77× | **823.3 MB** |

Read three things off this.

- **`--debug` is faster on G2 and slower on G6, and both are the same fact.** SPEC 7.1's zero level
  never frees (all sites T4b/`cycle:none`: heap, no drop, no arena, no count, no collector). On G2
  that buys 8% by skipping the frees; on G6 the 823 MB costs more in page faults than the frees
  would. **Leaking stops paying somewhere between 392 MB and 823 MB.** Anyone quoting the internal
  control as "AIF costs 6%" is quoting G2 and not reading the RSS column.
- **The arena column is the prize, and it is 11× on G2 and 3.3× on G6** — the same program, same
  data model, with only the transient batch bump-allocated. That is the transformation T1 exists to
  perform.
- **G2 does not get it.** Its four sites are **T2**, and `g2_frame_loop.psm`'s own header says
  *"This is the T1 case in its purest form… If these allocations do not land T1, the escape analysis
  is wrong."* By the corpus's own stated criterion, the escape analysis is wrong. AIF's projection
  (BENCHMARKS §4.1) is 0.70× of idiomatic C; it is at 1.22× and 1.57×.

### The fix, designed and deliberately not built

The measured defect is one line's worth of lattice: `escape_join` collapses any two scopes with
different owners to `Caller`, and `AIF_CON_ESCAPE_CALLER` raises to `Caller` with no idea which
function it is returning *from*.

The design that follows, worked out against the code:

- `AIF_E_CALLER_REGION` (−3), ordered `Region(s) ⊏ CallerRegion ⊏ Caller ⊏ Global`, joined in
  `escape_join`. `widen_sites` needs nothing — it goes straight to `Global`.
- `AIF_CON_ESCAPE_CALLER` must carry the emitting function (**an FFI-surface change**, so seed
  refresh and cold start). Then `sites[s].fn == k->b` → `CallerRegion` (one hop); otherwise
  `Caller` (returned again, so it escaped beyond one hop). That is "ownership transfer surviving
  one hop", closed to depth 1.
- `AIF_CON_LIVE_IN`'s cross-function arm becomes `CallerRegion` instead of `Caller`. Sound in both
  directions: for a value passed *down*, bounding it by its own caller's activation is longer than
  the truth, so conservative.
- `aif_tier_of` already returns T1 for anything that is not `Caller`/`Global`, so it needs nothing.
- **And the identical change in `aif/prototype/aif.py`**, or the differential stops meaning anything.

**Why it was not built.** `aif_arena_at_node` bars a site from an arena on `in_container` *before*
it ever looks at escape — and g2's hot site, the `DrawCmd` at 10.02M allocations, reaches
`list_push`, whose `retain_in(0)` sets `in_container`. The exclusion is correct: a container tears
its elements down through the deallocator, and an interior arena pointer is not something `free` can
take. So **the E change alone moves g2 from T2 to T1 and emits the identical binary**, plus a
manifest claiming a `region` placement that did not happen.

The prize needs the E change *and* the container-disposition change together: an arena-placed
element must make its container's element release a `NONE` disposition, the mechanism the
container-ownership work already has. Two coupled changes on the path where the failure mode is a
use-after-free. That is a project, not a narrow fix, and half of it is worse than none — which is
what this document has recorded twice already.

### Four things to carry forward

- **A committed tree that does not compile is a thing that happens.** Build before reading. The
  whole session's premise was numbers from a binary whose source no longer built.
- **A default is an input.** "Reach for the input before the mechanism" got its third outing, and
  the missing input was not a declaration this time — it was a flag whose default had been correct
  when it was written and was silently wrong two levels later. When a level changes what the
  language *is*, grep for the flags that describe what it *was*.
- **A control must be read with its cost column.** `--debug` looks like a 6% result and is a 112×
  memory result. The direction even flips with scale.
- **Read the gate before designing for it.** The E-lattice fix was fully designed and correct, and
  would have produced a byte-identical binary, because a different clause in `aif_arena_at_node`
  rejects the site first.

### Next, re-ranked on this session's measurements

1. **The caller-scope `E` value *plus* container disposition.** Now the highest-value item and the
   only one with a measured prize attached: 11× on G2, 3.3× on G6, against a corpus program that
   already declares landing T2 a falsification. Designed above. Do both halves or neither.
2. **Full ownership contexts (INFERENCE §6–7).** Still a project, and now known to be worth
   68/433 sites, all T2 → T1, with k=1 realising perhaps a quarter of that (1 of 4 on g3). Item 1
   above is the cheap subset of it; do that first and re-measure.
3. **`workload` and the rest of LAYOUT.** Unchanged — needs handles.
4. **Perceus elision.** Unchanged, and still nearly nothing to elide: T3 is 0 everywhere except
   `test_48`.

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
2. ~~**The undeclared-boundary residue.** The compiler reports **79 T3 sites** over `src/main.psm`,
   and this document's earlier "100% T0–T2, T3 residue 0" claim does not match the tree as it
   stands.~~ **Closed 2026-08-08 and there was no residue.** The 79 was `prismio aif`'s
   `owned_collections` default modelling the pre-Level-4 language; `prismio build` never used it.
   Both claims were true and about different runs. See the 2026-08-08 section.
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
