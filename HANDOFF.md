# Handoff — continuing the Prismio work

Read `COMPILER_AUDIT.md` (defects, all closed) and `V1_GAP_ANALYSIS.md` (capability inventory
against the v1 bar, with a status box at the top) before starting. Current as of **2026-08-07**.
Don't re-derive what's in them.

---

## Current state

Everything below is verified, not asserted — the commands that verify it are in the next section.

- **Self-hosts to a fixed point.** Bootstrapping from the committed seed produces a compiler whose
  IR for `src/main.psm` is byte-identical to the warm build's.
- **136/136 tests** as of 2026-08-24 (135 before the candidate-list session, which added `jit`;
  133 before the packaged-runtime session, which added the `runtime_library` runner test — it
  packages a toolchain into a temporary directory rather than shipping a fixture — and
  `incremental_manifest`, which shells out to the tool of that name;
  132 before the targets session, which added the
  `target_cross` runner test and its fixture; 131 before the DWARF session, which added the
  `debug_info` runner test and its fixture; 128 before the concurrency session, which added the
  `aif_concurrency` runner test, `test_68_optional_returns.psm` and `test_69_task_results.psm`), of which
  **31** are negative and each asserts *which* diagnostic it
  expects. The runner globs `neg_*.psm`, so the count is `ls tests/neg_*.psm | wc -l` and nothing
  else; this line said 26 while the tree held 27, which is the same rot the note below describes. (This line read "76/76" for six sessions after it
  stopped being true. If you change the count, change it here.)
- Backend is the **LLVM C API** (`runtime/llvm-api-backend.c`); the old text emitter is gone.
  `ir_append()` survives only as a loud failure guarding against raw text creeping back in.
- Pinned to **LLVM 22.x**, enforced at build time (`tools/setup_llvm.py`) and at runtime
  (`LLVMGetVersion` in the backend). Bump `PRISMIO_LLVM_EXPECTED_MAJOR` (`runtime/prismio_llvm.h`)
  and `REQUIRED_MAJOR` (`tools/setup_llvm.py`) together.
- **CI on three platforms**: source-list check → LLVM → bootstrap from seed → fixpoint → suite →
  seed target-neutrality.
- **Cross-compilation exists** as of 2026-08-21: `--target <llvm-triple>` and `--sysroot <sdk>`,
  with the triple, pointer width and data layout all answered by LLVM rather than by a table.
  `x86_64-apple-macos` is the target it has actually been built and run against. `std.io` is an
  ordinary import, not a prelude, so a program that names no I/O carries none.

### File roles

Paths are current as of 2026-08-20. The 2026-08-08 split (`src/sema.psm` into `src/sema/`, and so
on for ir, aif, lexer, parse, ast) is folded in rather than left as a warning over a stale table.

| Path | Role |
|---|---|
| `src/lexer/{scanner,token}.psm` | tokens with spans, string/char escapes |
| `src/parse/{parser,expr,stmt,decl}.psm` | precedence, casts, compound-assignment desugaring, error recovery |
| `src/ast/{nodes,types,dump}.psm` | ASTNode, TypeInfo, width/signedness helpers, the JSON dump |
| `src/sema/{checker,flow,ownership,symbols,types,builtins,enums,generics}.psm` | type checking, ownership, scoping, flow analysis, monomorphisation |
| `src/aif/{walk,model,report,contracts,layout}.psm` | the memory model: AST walk, transfer rules, manifest, `--why`, layout search |
| `src/ir/{module,expr,stmt,types,context}.psm` | AST → backend calls. **Emits no IR text** |
| `src/ir/bridge.psm` | the backend FFI surface |
| `src/ir/debug.psm` | `-g`: where a location is stamped, and where it is declined |
| `src/common/{diagnostics,text}.psm` | the diagnostics FFI surface, string helpers |
| `std/` | the standard library, written in Prismio |
| `runtime/ir_symbols.c` | interned names, scoped symbol table, move/borrow state, loop targets |
| `runtime/diagnostics.c` | source-file registry, span rendering, error accounting |
| `runtime/aif_support.c` | the solver: bitsets, points-to, the fixed point, arena placement |
| `runtime/lang_runtime.c` | the language runtime a compiled program links against |
| `runtime/program_support.c` | files, paths, argv, threads and channels |
| `runtime/build_driver.c` | drives clang, the object cache, the toolchain sources |
| `runtime/llvm-api-backend.c` | the backend, including the DWARF emitter |
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

## What landed, and what to know before touching it

Named "What's next" for several sessions while every paragraph in it described something that had
already shipped. It is a reference for the memory model as built — read the part covering whatever
you are about to change. For what is actually next, see `SESSION-PROMPT.md`.

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

## Session of 2026-08-24 (the candidate list) — all five taken in order, and the list is empty

Every candidate in `SESSION-PROMPT.md`, one at a time, each through the full gate before the next
started. Five gates, five green.

**State on exit.** Suite **136/136**; fixpoint `E1b == E2`; cold seed chain `Es1 == E2`; AIF
differential agrees on 17 sources; source lists agree. Across all five tasks the IR snapshot moved
in exactly **two** files: `src/main.ll`, because `src/` changed four times, and
`tests/debug_info.ll`, because task C deliberately extended that fixture. Every other program is
byte-identical to the session's start. **Last-good: `build/E2`.**

### A. wasm32 past IR — the blocked half is genuinely blocked, and the other half was a bad diagnostic

**The external half cannot be done here and the reason is now precise.** There is no `wasm-ld` on
this box, and more importantly `wasm32-unknown-unknown` has **no C library at all**: the runtime
sources stop at `#include <stdio.h>`. No archive can be built for it from this repo, because what
`print` resolves to on the web is an embedder's decision. That is unchanged and remains the
blocker.

**What was doable was the failure.** A cross build with no shipped archive falls back to compiling
the runtime for the named target, and when that failed the compiler printed:

    NOTE: a normal build links against the Prismio runtime only.
          If you are building the Prismio compiler itself, use:
              prismio bootstrap src/main.psm

`prismio bootstrap` builds a compiler **for the host**. Telling that to someone cross-compiling to
wasm32 is a signpost pointing at a trap, which is the same shape of defect the 2026-08-17 session
found in `prismio bootstrap` itself. It now names what it looked for and where:

    NOTE: no runtime library was found for --target wasm32-unknown-unknown, so the
          runtime was compiled from source for that target instead.
          Ship lib/runtime-wasm32-unknown-unknown.a beside the compiler, or pass
          --sysroot pointing at an SDK that provides a C library for it.

The exact filename a framework has to ship is now in the diagnostic, which is the one thing the
person hitting this needs. Asserted in `run_runtime_library_test`, including that the note must
*not* say `prismio bootstrap`.

### B. The layout hardcodes — the prompt named two, and both were fine; the bug was next to them

The prompt flagged `aifTypeBytes` returning 4 for an enum and 8 for a `Float`. **Both are correct
and are now commented as deliberate**: `Float` lowers to `double` and an enum falls through to
`i32` (`src/ir/types.psm`), and those are the same width on every target LLVM emits for. Routing
them through the target would advertise a variation that does not exist.

**Two lines above them was the real thing.** `[T]` and `List<T>` returned a literal `8` under a
comment reading "both a pointer to elements held elsewhere" — while the String/Ptr case three lines
below already called `targetPointerBytes()`. On wasm32 a pointer is four bytes, so every container
field was modelled at twice its width, and `Theta_stack` is what decides T0. That is exactly the
`Isize` class the prompt was pointing at, one function away from where it pointed.

**Measured, before and after, on three structs of three fields each:** on wasm32 a struct of
`List<Int>` modelled 24 bytes where a struct of `String` modelled 16. They now agree.

`prismio aif` also learned `--target`, because without it the cost model could only ever be
inspected for the host while `prismio build --target` compiled against a different one — and the
fix would have had no way to be tested at all.

### C. Assignment spans — the compound case was worse than the prompt thought

`x = e` built its node *after* `parserMatchVal` consumed the `=`, so it took the column of the
right-hand side: right line, one token to the right, as described.

**`x op= e` was the 2026-08-22 expression-statement bug again**, and nobody had noticed because it
is invisible unless you look at columns. Its node was built after the *whole* right-hand side, so
it took the next statement's first token. Under `-g` that cost the compound assignment **a location
of its own entirely** — measured on a six-line program, `a += 3` on line 6 produced no entry at
all, the two statements collapsed into one, and a debugger stepped straight over it.

Both now stamp from the statement's first token. `// ASSIGN` joins `// MARK` and `// CLOSE` in
`tests/debug_info.psm`, checked with a new `_di_located_spans` that carries columns — because
`_di_located_lines` cannot see a defect that stays on the same line, which is the usual case for an
assignment.

### D. `-Woverride-module` — the option everyone assumed existed does not

The prompt offered two ways out and called neither obviously right. **Measurement removed one of
them.** The clang *driver* always compiles for the SDK's deployment target
(`arm64-apple-macosx26.0.0`) while a module carries at most `LLVMGetDefaultTargetTriple()`
(`arm64-apple-darwin25.5.0`). Those never match — and clang warns **identically against a module
with no triple at all**, which is exactly what a plain host build emits. So "stamp it better" and
"stamp nothing" were both already refuted by the compiler's own behaviour; nothing we write on the
module can silence it.

Suppressed with `-Wno-override-module`, and **the check it could in principle have done is now an
assertion instead**: `run_target_test` requires the data layout the module stamps to equal the one
clang computes for the same target, for the host and for wasm32. That is the half with teeth — the
layout is what `-g` member offsets and every size in the AIF model derive from, and a disagreement
there is an ABI disagreement. The triple is deliberately not compared, because the two forms name
one machine and never match textually.

Verified by making `ir_target_data_layout` return the host layout regardless of target: three
assertions fire, including the new one.

### E. `prismio run --jit` — the last planned item

`run` paid a full clang compile plus a link on every invocation to produce an executable it deleted
moments later. **Measured on this host: 10-20 ms against 220-530 ms.**

**Compiled in only on the real-headers path**, following the precedent set for DIBuilder and for
the same reason written over that block in `prismio_llvm.h`: the linker checks names and never
signatures, and Orc is opaque handles passed by pointer. Without real headers `--jit` says so and
exits rather than mis-executing.

Three things the prompt warned about, and what each turned into:

- **Registering runtime symbols.** Not a table. The compiler links the runtime it hands to user
  programs, so every extern the module names is already in this process; a
  `DynamicLibrarySearchGeneratorForProcess` resolves them. A hand-kept table of names and addresses
  would be a second copy of the runtime's surface, and the failure of a drifted entry is an
  unresolved symbol at lookup — which is what the generator reports anyway.
- **`prismio_argc`/`prismio_argv`, and this one was real.** Generated code *defines* those globals,
  so the jitted module holds its own copy and its `main` fills that one, while the runtime shims
  behind `cli_arg_count()` are the compiler's and read the compiler's. A jitted program asking for
  its arguments was told about `prismio run --jit prog.psm`, quietly. The host globals are set
  around the call and restored after. Confirmed by mutation: without it the fixture prints
  `argc: 4`.
- **`--jit` with `--target`.** Refused in both flag orders, and `--jit` on `build` is refused too.

**One thing the prompt did not anticipate.** LLJIT requires a module owned by the context inside
the ThreadSafeContext it is given, and `LLVMOrcThreadSafeContextGetContext` **does not exist in
LLVM 22**. The module is serialised to an in-memory bitcode buffer and re-parsed into a fresh
context which the ThreadSafeContext then adopts — one serialise and one parse of a module already
in memory, against the clang compile and link it replaces. Handing over the backend's own `g_ctx`
would have been a use-after-free at shutdown, since that call takes ownership.

`run --jit` and `run` are deliberately indistinguishable from outside: same stdout, same exit
status, same diagnostic on failure. That is what `run_jit_test` asserts first.

### And the last open question in the prompt, closed

`SESSION-PROMPT.md` carried a "suspected stale" note for three sessions saying `HANDOFF.md`'s
"Known gaps" still claimed compile time was superlinear at ~290 ms. **The note was itself stale** —
that bullet was struck through and corrected on 2026-08-20, and it ended "delete this bullet if it
stays clean". Re-measured here: the whole of `src/`, **646 KB through the frontend and codegen in
50-70 ms**. It stays clean, so the bullet is gone.

### What this leaves

The candidate list is empty. What remains is in "Deliberately not in this list" below, plus the one
external blocker: a `runtime-wasm32-unknown-unknown.a` and a `wasm-ld`, neither of which this repo
can produce, because the host imports a wasm build resolves against are an embedder's decision.

## Session of 2026-08-23 (packaged runtime) — the shipping path gets a test, and two things on it were already broken

Candidate A of `SESSION-PROMPT.md`, chosen over the optional `--jit` task because it is the one
path that matters most for shipping and the one path with no test — and then the follow-on it
produced, which was to stop `tools/verify_separation.*` being a script nobody runs.

**State, verified on the tree before starting.** The brief was accurate this time: `build/S16b`
present and alone in `build/`, suite 133/133 against it, HANDOFF's top entry the 2026-08-22 `-g`
session, `src/common/target.psm` and `tests/target_cross.psm` untracked but belonging to the
2026-08-21 targets work rather than to a half-finished feature.

**State on exit.** Suite **135/135**; two-generation fixpoint `P1 == P2`; cold seed chain
`Ps1 == P2`; AIF differential agrees on 17 sources; source lists agree. The IR snapshot over
`tests/`, `aif/corpus/`, `aif/evidence/` and `src/` moved in exactly **one** file, `src/main.ll`,
and only by the string-table renumbering that adding one string constant causes — §3 below is the
only line of `src/` that changed all session. The gate ran twice, once per task; the second task
touched `tests/` only and its snapshot came back byte-identical everywhere.
**Last-good: `build/P2`.** The gate ran three times, once per task; `N2`, `M2` and `P2` are
successive rebuilds of one unchanged `src/`, so all three emit identical IR.

### 1. What was actually untested

`tools/package.sh` builds `lib/runtime.a`, and nothing in the tree linked against one. A dev
checkout runs the compiler out of `build/`, where `find_in_lib_dir` looks in `build/../lib` and
`build/lib` and finds nothing, so **every build this suite has ever made took the
`build_from_toolchain_sources` fallback**. `find_runtime_library` → `link_against_runtime_library`
was reached only on an installed toolchain, and nothing in CI assembles one.

**The reason this could not be tested by checking that a build works.** A missing archive is
invisible: the fallback unpacks the runtime sources embedded in the compiler binary and the build
succeeds anyway. So `run_runtime_library_test` makes every assertion against
`PRISMIO_OBJ_CACHE_TRACE` — one `[objcache ...] <role>` line per toolchain source the fallback
compiles. No line means the archive was linked; a line means it was not. That is the same
observation channel `run_target_test` already uses for cache sharing, for the same reason: "the
build was faster" is not an observation a test can make on a shared host.

Seven assertions, and the negative control is not decoration — with the archive moved aside the
build must print trace lines, because "no trace lines" is also what a compiler with a broken trace
would print. Each assertion was checked by mutation before being believed: hiding the archive from
the lookup while leaving it on disk fires assertion 1, blinding `from_source` fires 2, 3 and 5,
naming the shipped cross archive with LLVM's normalised triple fires 4, and both directions of the
hash comparison fire 6 and 7.

**The seam works end to end.** A `runtime-x86_64-apple-macos.a` built the way a framework would
build one is found, linked, and produces an x86_64 binary that runs. A foreign target is *not*
handed the host's `runtime.a` — it falls back and compiles its own, which is the property that
stops an arm64 archive being linked into an x86_64 binary.

**Recorded because nothing else in the tree says it:** the triple in the archive name is the one
**as typed on the command line**. `ir_target_select` stores `use` verbatim rather than LLVM's
normalisation of it, so `--target x86_64-apple-macos` and `--target x86_64-apple-macosx26.0.0` look
for two different files describing one machine. A framework has to ship under the name its users
will type.

### 2. `tools/verify_separation.sh` and `.ps1` had not compiled since 2026-08-21

Both build a probe program to prove the link step pulls in only the runtime, and both wrote

```
fn main() -> Int {
    println("ok")
    return 0
}
```

with no `import std.io`. Since `std.io` stopped being a prelude the probe does not compile, so
`installed toolchain compiles a program` failed and **the three checks after it silently did not
run** — including `no LLVM backend code in the user binary`, which is the check the script exists
for. It is loud when run and nothing runs it, which is the same shape as the `prismio bootstrap`
break the 2026-08-17 session found.

Fixed in both scripts; all 11 checks pass against a freshly packaged toolchain.

### 3. The staleness guard named the wrong script on two platforms out of three

`checkRuntimeFreshness` told everyone to re-package with `tools/package.ps1`. On macOS and Linux
that file is `tools/package.sh`. This is the only line in `src/` that changed this session, and the
whole `src/main.ll` diff is the string-table renumbering it causes.

### 4. `tools/verify_separation.*` is now called by the suite

Fixing the probe left the script passing and still run by nothing, which is the state it was in when
it broke. So `run_runtime_library_test` now hands it the `--dist` it has already packaged, on both
platform flavours. CI runs the suite on three platforms, so **no CI change was needed** — the
Windows `.ps1` path is exercised there for the first time by this, and could not be run locally.

Two of its checks are ones the suite cannot make itself, which is the other half of the argument
for calling it rather than reimplementing it:

- **`nm` over the archives** proves `runtime.a` and `backend.a` were built from the right
  translation units in the first place — 0 `ir_*` symbols in one, 216 in the other.
- **A byte-signature scan of the linked binary** proves the *link step* pulled in only the runtime.
  A linked binary's symbol table says nothing about which static-archive members were folded into
  it, so nm cannot answer this; the scan looks for diagnostic strings that exist only in
  `llvm-api-backend.c`, and separately requires the compiler itself to contain them so the check
  cannot pass trivially.

**A missing `nm` is reported as a skip rather than a failure**, because the script exits 1 for that
exactly as it does for a failed check and the two are otherwise indistinguishable.

Verified by regressing a copy of the script to its 2026-08-21 state — probe with no
`import std.io` — and confirming the suite fails with the failing check named:
`installed toolchain compiles a program -- error: unknown function println`. That is the break that
went two days unnoticed, and it is now loud.

### 5. The same break, three more times — and the pattern behind it

Writing §4 up as "check whether other tools are unreachable" turned into a finding rather than a
note. The generalisable question is not "which scripts are unreachable" but **"which scripts embed
a Prismio program"** — that is the set the prelude change could break. `grep -rl "fn main() -> Int"`
over `*.py`, `*.sh`, `*.ps1` and `*.yml` answers it in one line and returns five files: the test
runner, and four tools. **Three of the four were broken, all since 2026-08-21, none of them
noticed.**

- **`tools/incremental_manifest.py` is INFERENCE 9's required check** — reuse of a per-function
  inference summary across a rebuild must change no answer, "because summary-cache bugs are silent
  and produce wrong-tier binaries rather than crashes". **All three of its program templates** had
  `println` with no `import std.io`. Fixed, and wired into the suite as
  `run_incremental_manifest_test` — 150 ms, and it reports discriminating / reversible /
  budget-sensitive separately.
- **`tools/install.ps1` is the one that reached users.** Its post-install probe had the identical
  break, so on Windows the installer verified a perfectly good install, printed
  `[FAIL] installed compiler cannot build a program`, and exited 1. Nothing in CI runs the
  installer, and the POSIX side has no counterpart script to disagree with it. Fixed. **It is not
  wired into anything and deliberately so** — it installs, and a test that runs it would be
  installing.
- **`tools/ir_slot_diff.py` is left manual, deliberately.** It compares two IR snapshot trees
  tolerating a global slot renumbering, which makes it an aid for *reading* a gate failure rather
  than an assertion about the compiler. It embeds no Prismio source, which is exactly why it is the
  one that did not break. Smoke-tested against this session's two snapshots:
  `101 identical, 0 slot-renumbered only, 0 really differ, 0 missing`.

**Four scripts, one commit, two days, zero failures anywhere** — and one of them was the installer.
The 2026-08-21 prelude change was correct; its blast radius was every `println` outside `tests/`,
and every one of those lived somewhere nothing runs. Two generalisations, and the second is the
cheaper one:

1. A script that asserts something and is called by nothing is not coverage. The two that assert
   are now called by the suite; the one that assists is not, and the installer cannot be.
2. **When a language change lands, grep for the construct in every file that embeds source, not
   just the ones under `tests/`.** One `grep -rl` would have caught all four on the day.

### What this leaves

Nothing on this seam. The archive lookup, the target-specific archive, the `--verify` bypass, the
staleness guard and the runtime/backend boundary all have assertions with teeth, and the script
that owns the last of them is now called by the thing that packages the toolchain it needs.

## Session of 2026-08-22 (finishing `-g`) — four holes closed, and two bugs the tasks walked into

Tasks 1–4 of `SESSION-PROMPT.md` (Phase 3), in order, each through the full gate before the next
started.

**State, verified on the tree.** Suite **133/133**; two-generation fixpoint `S16a == S16b`; cold
build from the refreshed seed byte-identical to the warm chain; AIF differential agrees on 17
sources. **Last-good: `build/S16b`.** The IR snapshot over `tests/`, `aif/corpus/`, `aif/evidence/`
and `src/` moved in exactly **two** files across all four tasks: `src/main.ll`, because `src/`
changed, and `tests/debug_info.ll`, because the fixture was deliberately extended four times. Every
other program is byte-identical to the session's start. That is the property this whole phase
rests on — `-g` is one flag, and a release build must carry none of it.

### 1. `DIGlobalVariable` for module-level globals

`ir_debug_global` beside `ir_debug_local`, called from `generateModule`'s global loop. The
description hangs off the global's own value as a `!dbg` attachment and the compile unit collects
it at finalize, so it runs before any function exists and needs no scope stack.

The type key passed is `varType`, **not** `storageType(varType)` — the uncollapsed key is what
tells `di_type_for` to describe a `T` rather than an anonymous pointer. A global whose key does not
map gets no entry.

Verified under lldb: `target variable counter name ratio ready wide` prints all five with their
declared types. `prismio_argc` and the string-literal globals get nothing, and the test says so —
naming codegen's own globals would put compiler internals in a user's `target variable` output.

### 2. `-g` for `prismio bootstrap`, and the dSYM that was missing with it

The flag is now parsed by `bootstrap`, and **`-g` had to be named in the guard that decides whether
argument 2 is the source path** — without that, `prismio bootstrap -g` compiles a file called `-g`.

**Decision, recorded: the toolchain's C sources are compiled `-g` and stay at `-O2`.** The program
object drops to `-O0` under `-g` because a Prismio local folded into a register is the whole
feature; the runtime is not being stepped through line by line, and what a backtrace across the FFI
boundary needs is a named frame with a source line, which `-O2 -g` gives. Measured: `str_concat`'s
*arguments* (`s1="std"`, `s2="."`) and its return value read correctly; its *locals* are
`<variable not available>`. Building the runtime at `-O0` would slow every `-g` build's execution
to fix inspection nobody asked for. The flags go in `compile_flags`, so the object cache keys on
them — proven by running a `-g` and a non-`-g` bootstrap against one empty cache directory and
getting seven misses each, then seven hits on a repeat.

**`compiler_bootstrap_executable` never called `write_dsym`.** `compiler_build_executable` does,
and for a reason that applies identically here: on Mach-O the executable carries a debug map and
the DWARF it points at is in the program object, which the next line deletes. So `bootstrap -g`
emitted every byte of the metadata and threw away the half describing Prismio code — the runtime's
C frames would still have resolved, because their objects live in the object cache and outlive the
build, and a Prismio frame would not. One line, and the test fails loudly without it.

**Stepped through the compiler under lldb, as the task required.** A backtrace through six Prismio
frames resolves with file and line on each, and scalar arguments print (`runAfterBuild=false`,
`debugInfo=false`). `n` steps line to line. The one rough edge: stepping past a `return` lands in
the **epilogue**, where the frame pointer chain is half torn down, so `bt` shows a bare address for
the caller and the parameter reads as garbage. That is ordinary "stopped in an epilogue" behaviour
and not a line-table defect — and it is also the clearest argument for task 4, since the epilogue
inherits the return statement's line.

### 3. Enums as `DW_TAG_enumeration_type`

`ir_get_enum_variant_count` / `_name_at` / `_value_at` over the flat variant table in
`ir_symbols.c` (the table holds every enum's variants in one array, so "index i of this enum" is
the i-th *matching* entry), then `di_enum_type` in the backend, cached under `$e:` like structs are
under `$s:`. `di_type_for` returns it when the key is `i32` **and** `ir_named_type_kind(name) == 2`.

An enum with no registered variants gets no type rather than an empty one: a
`DW_TAG_enumeration_type` with no enumerators tells a debugger the value has a name it cannot find,
which reads worse than plain `Int`.

**The half that makes it worth having is in the frontend, not the backend.** `debugTypeName` now
returns an inferred `TypeKind.ENUM`'s name, because `let kind = node.kind` — no annotation
anywhere — is how this compiler binds an enum nearly everywhere, and sema infers `NodeKind` from
the field's declared type. Verified: `(Colour) fromField = GREEN` for a binding with no annotation
in sight.

**What it deliberately does not reach: a bare variant.** Sema types `Colour.RED` as `Int`
(`semaExpr`'s `MEMBER_ACCESS_EXPR` arm, which returns `typeInt()` for a non-payload variant), so
`let c = Colour.RED` is an `Int` as far as the entire compiler is concerned. Describing it as a
`Colour` would have the debug layer assert a type the compiler does not hold. Changing that is a
*semantic* change — assignability, comparisons, `as`, match patterns — and is not a DWARF task.

### 4. A closing-brace span on BLOCK — which found a second bug first

`parseBlock` stamps the `}` token's line/col onto `blockNode.i1`/`i2` (both free on a BLOCK; `i3`
is not taken, because a block's brace cannot be in a different file from its opening), and
`generateBlock` sets the location from it before the drops, the arena pop and the region exit.

**The first attempt appeared to do nothing, and the reason was a real defect.**
`parseStatement` built an `EXPRESSION_STATEMENT` node *after* `parseExpression` had consumed the
whole statement, so `parserNode` stamped it with the token that **follows** it — the next
statement's first token, or the closing brace. So `println(x)` on line 7 was already reported as
line 8, and the cleanup that inherited it was accidentally landing on the right line for the wrong
reason. `break` and `continue` had the same shape.

Fixed with `parserNodeFrom(kind, tok)` and a token held before anything is consumed. Measured
containment: **no non-`-g` IR moved** (spans reach AIF's reporting and diagnostics, not codegen)
and all 133 tests pass, including every `neg_*` fixture — no diagnostic underline moved, because
they report against the expression inside the statement, which was always right.

After both, every instruction names the line it came from: the call on its own line, the arena pop
on the `}`, the `ret` on the `return`.

### 5. Unplanned, and it made a documented promise true

`docs/DEBUGGING.md` said a String prints its characters rather than its address. It did not:
`frame variable s` rendered `(signed char *) 0x1000042fc`. The cause is one word — lldb
auto-summarises a `char *` and prints a `signed char *` as a bare address, and tells them apart by
the base type's **name**, which was `"Char"`. Renaming just the String pointee to `"char"` gives
`(char *) lname = 0x… "local-string"`. Measured both ways on lldb 22.1.8.

Only the String pointee moved. An `i8` binding is Prismio's `Char` and keeps that name, because it
is a Char and not a C char.

### Six ways it was broken on purpose

`run_debug_info_test` and `run_bootstrap_command_test` grew assertions for each of the above, and
each was checked against a compiler built with the mechanism broken.

| break | what failed |
|---|---|
| `debugGlobal` call removed | no `DIGlobalVariable` for any of the five; compile unit lists no `globals:` |
| `LLVMGlobalSetMetadata` dropped | all five described and none reachable — `@name` carries no `!dbg` |
| the global's type key hardcoded to `i32` | `epoch`/`tolerance`/`enabled`/`unit` described as `Int` |
| `write_dsym` removed from the bootstrap path | `bootstrap -g` produced no `.dSYM` |
| the `TypeKind.ENUM` arm removed | `seen` flattened to `Int` |
| enumerator values taken from the index | `Channel` described as `[('NORTH', 1), …]` |
| `debugAtBlockEnd` removed | nothing attributed to the `}` line |
| the expression-statement span reverted | nothing attributed to the call's own line |

**Two of the new assertions were themselves wrong first, and only breaking them showed it.**

- The `bootstrap -g` guard check asserted `"main.psm" not in said`, which is never true: the error
  message's *help text* names `path/to/src/main.psm`. It passed against the broken compiler.
  Now it keys on the exact phrase `cannot read -g`.
- **`located` pooled every file's `DILocation` lines.** `std/io.psm` is 170 lines and is merged
  into every program here, so any line number under 170 was "located" whether or not the fixture
  put anything there — which is why the pre-existing `// MARK` assertions never caught the
  off-by-one they exist to catch. `_di_located_lines` now resolves each location's scope to a
  DIFile and counts only `debug_info.psm`. **This strengthens the assertions that were already
  there**, and is the most reusable thing in this session.

A third assertion was written and then deleted rather than kept: "a struct must not be described as
an enumeration" can never fire, because a struct's type key is never `i32` and `di_type_for`'s enum
branch is unreachable for it. A test that cannot fail is worse than no test.

### Left alone, deliberately

- **Assignment statements are stamped with the token after `=`.** Right line, wrong column. Same
  class as the expression-statement bug and not fixed with it, because the blast radius is
  diagnostics-only and nothing observed is wrong.
- **A bare enum variant is an `Int`.** See task 3 — a semantic change, not a DWARF one.

---

## Session of 2026-08-21 (layering + targets) — the wasm pretence is gone, `std.io` stops being a prelude, and a cross-compiled binary runs

Tasks 1–4 of `SESSION-PROMPT.md`, in order, each through the full gate before the next started.

**State, verified on the tree.** Suite **133/133** (the new one is `target_cross`); two-generation
fixpoint `S11a == S11b`; cold build from the **committed seed** byte-identical to the warm chain;
the IR snapshot over `tests/`, `aif/corpus/`, `aif/evidence/` and `src/` is unchanged from the
post-task-2 baseline except `src/main.ll` and the one new fixture; AIF differential agrees on 17
sources. **Last-good: `build/S11b`.** The seed was refreshed twice — once as the second half of
task 1's FFI removal, once at the end.

### 1. The wasm runtime and `--target wasm32` are gone

`runtime/lang_runtime.c` lost 523 lines: the whole `#ifdef PRISMIO_WASM` arm — bump allocator over
`__heap_base`, hand-written `memcpy`, `free` as a no-op, four `env`-module host imports. Nothing
defined `PRISMIO_WASM`, and which host functions exist is an embedder's decision, not a compiler's.
`ir_module_start_wasm` went with it, and the frontend's `irTargetWasm` boolean.

**The two-step mattered.** The committed seed's IR called `ir_module_start_wasm` twice. Step one
removed the *calls* from `src/` and refreshed the seed; step two deleted the C. Merging them would
have left a fresh checkout unable to link, and only CI's first step would have caught it.

### 2. `std.io` is an ordinary import

`resolveImports` no longer merges it into every program. **Decision, one rule always: explicit for
`run` as well as `build`.** A prelude that is implicit for one command and not the other is a rule
nobody can state, and `run` is the command people learn the language with.

111 files gained `import std.io`, placed above every other statement so the merge order — and
therefore emission order — is what it was.

**The diff is the deliverable, and it is smaller than expected.** 91 of 99 programs are
byte-identical, because a program that prints imports `std.io` and gets exactly what it got before.
Seven changed: the ones that print nothing. Each lost the same 499 lines — 33 `print`/`println`
bodies, three integer formatters, six declares, the digit table — and nothing else. Verified by
normalising the three compiler-assigned serials (local-slot suffix, string-constant id, basic-block
label), all three of which now start lower because `std/io`'s bodies are not consuming them first;
after that normalisation the seven are identical to their old selves. A program with no I/O went
from 546 lines of IR to **47**.

`test_runner.py` does catch the trap: a `neg_*` fixture that failed only with "unknown function
`println`" reports **"Rejected, but not for the expected reason"**. Confirmed by breaking one.

### 3–4. A target record, and it reaches clang

`--target` takes an **LLVM triple**, and there is no table of supported targets anywhere in the
tree. `ir_target_select` hands the triple to LLVM and reads back the data layout and the pointer
width; `src/common/target.psm` is the frontend's `Target` record over that one copy. A table would
be a second copy of facts LLVM owns, and a wrong row is a *miscompile* — which is the rule this
whole session was sorted by.

- **The record is in `common`, not `ir`.** `Isize`/`Usize` are pointer-width, so what a type *is*
  depends on the target, and `ast` needs the answer too. `common` is the only package both may
  import.
- **`--sysroot` is not in the record.** It is not a property of the triple — it is where *this*
  machine keeps the SDK. Two hosts building one target legitimately pass different paths.
- **The implicit host stamps nothing.** No triple, no layout on the module, so every existing
  build is byte-for-byte what it was. Only a named target stamps. This is also why the whole of
  tasks 3 and 4 moved no output except `src/main.ll`, which the prompt did not require.
- **The `#ifdef _WIN32` triple pin survives** as the implicit-host case. Routing it through the
  record would change the IR of every Windows build, on the one platform none of this was tested on.
- **`find_toolchain_library(…, "runtime")` is now `runtime-<triple>`** for a named target, falling
  back to compiling the runtime sources with the same `--target`/`--sysroot`. That fallback is what
  makes an SDK-based target work with no archive shipped at all; the archive is the seam a framework
  ships across.

**`Isize`/`Usize`, the bug that made `--target wasm32` build nothing.** Codegen lowered them through
`irPtrIntType()` (i32 on wasm32) while `ast.types` told sema they were `i64`. So `value as U64` in
`std/io` was a cast between two *equal* keys, which emits nothing, and every program failed
`LLVMVerifyModule` on a 32-bit value handed to a 64-bit parameter. The call site was already
written to widen — it just never got the chance. Fixed by making `typeIsize`/`typeUsize` read the
record, so sema and codegen give one answer. `aifTypeBytes`'s three pointer-width rows moved with
them. **All 78 fixtures now produce verifying wasm32 IR**, where before none did.

**`-g` across a target boundary was the sharp one.** `pin_data_layout()` asked
`LLVMGetDefaultTargetTriple()`; a cross-compiled `-g` build would have described the *host's* member
offsets. It already left an existing layout alone, so stamping the target's layout at module start
fixes it by construction. Verified: `struct { Int, String, I64 }` puts `name` at bit 64 on the host
and at bit **32** for wasm32.

**The object cache keys on the triple**, because the target flags go into `compile_flags`, which is
what the key hashes. Breaking that on purpose produces
`ld: ignoring file … found architecture 'arm64', required architecture 'x86_64'` — silent until it
is not.

### End to end

```bash
prismio build hello.psm --target x86_64-apple-macos --sysroot "$(xcrun --show-sdk-path)" -o hello
file hello    # Mach-O 64-bit executable x86_64
./hello       # runs under Rosetta on an arm64 host
```

**Web was the target the prompt named, and it could not be the one.** clang emits a wasm32 object
fine, but there is no `wasm-ld` here, and task 1 deleted the wasm runtime on purpose — a `.wasm`
with unresolved `env` imports and nothing to run it in is not "end to end". `x86_64-apple-macos` is
a real cross-compile (different arch, needs `-isysroot`) that this host can *run*, so it is what the
plumbing was proven against. Everything wasm above is IR-level and says so.

### The new test, and breaking it twice

`run_target_test` asserts: the host stamps nothing; a named target's triple and layout reach the
module; the allocator's size argument and `std/io`'s widening cast both follow the pointer width;
`-g` member offsets come from the target; an unresolvable triple is refused; two targets do not
share a cached object; and — on arm64 macOS only — the cross build links and runs.

Broken deliberately twice, per the house standard. Reverting `typeIsize` to a hardcoded `i64`
reproduces the original verifier failure; taking the target flags out of the cache key reproduces
the arm64-object-into-an-x86_64-link.

### Known-stale, corrected on the way

`V1_GAP_ANALYSIS.md` claimed `--target wasm32` existed, and its CLI row listed `--target` but not
`-g`/`-O`/`--verify`. Both fixed.

### Left alone, deliberately

- **`-Woverride-module` on every macOS build.** clang normalises `x86_64-apple-macos` to
  `x86_64-apple-macosx26.0.0` and warns that it differs from the module's. It warns on host builds
  with no triple at all, so this predates targets and is not a cross-compilation problem.
- **`aif/layout.psm`'s enum size (4) and Float (8)** are not pointer-width and were left as they are.

---

## Session of 2026-08-20 (DWARF) — `-g` lands, and the honest omissions are the interesting part

### What this closes

`V1_GAP_ANALYSIS.md`'s "Compiled programs cannot be source-debugged", and item 19's second
half. `prismio build x.psm -g` emits a compile unit, a line table, a DISubprogram per source
function, a DILexicalBlock per block, a DILocalVariable per binding and a DICompositeType per
struct. lldb resolves breakpoints by file and line, prints frame variables, and `type lookup
Point` prints the struct.

`docs/DEBUGGING.md` is the other half of the session and is not a README for `-g`: it is the
write-up of `--verify`, the manifest and `--why` as a debugging story, which is the thing this
compiler has that a debugger does not replace.

### 1. The property that let it land, and how it was checked

**Without `-g`, output is byte-identical.** `tools/ir_snapshot.py` over `tests/`,
`aif/corpus/`, `aif/evidence/` and `src/`: 98 pre-existing programs, and the only one that
moved is `src/main.ll`, which moved because `src/` did. The whole feature is one flag through
`irSetDebugInfo`, and `run_debug_info_test` asserts a no-`-g` build contains no
`!DICompileUnit`, no `!DILocation`, no `!dbg` and no `target datalayout` — because a stray
unconditional call into the DWARF layer would fail nothing else in the suite and would move
every program's IR.

### 2. Pinning the data layout is the load-bearing part, and it is not obvious

A module with no `target datalayout` is laid out by **LLVM's default specification**, in which
`i64` has a *4-byte* ABI alignment. Measured, on this host:

| | `{ i32, i64, i8 }` |
|---|---|
| empty layout | size 16, offsets 0 / 4 / 12 |
| host (arm64-apple) | size 24, offsets 0 / 8 / 16 |

So member offsets read from `LLVMGetModuleDataLayout` on a module the compiler never gave a
layout are four bytes out on the first 64-bit integer field of every struct that has one, and
clang then lays the object out its own way. That is not a missing answer, it is a debugger
confidently pointing at the wrong bytes. A `-g` build therefore asks the host target machine
for its layout and writes it onto the module, the way clang does for a C translation unit.
`tests/debug_info.psm` carries a `Checkpoint { tick: Int, stamp: I64 }` for exactly this: field
0 is pinned by the layout search, so its `i64` sits behind a lone `i32` and lands at bit 64 on
every supported target and at bit 32 under the default. Breaking the pin moves it, and the test
says so in those words.

`double` and `ptr` are 64-bit-aligned in the default spec too, so most structs come out the
same either way — which is precisely why this needed a fixture built to discriminate rather
than a spot check.

### 3. The three things AIF makes hard, and what each got

The brief asked for a DWARF expression or an honest omission per case. Two of the three are
omissions and one is a real description:

- **A T0 value's alloca is one slot per loop.** No change needed: the variable's storage *is*
  that slot and the DILexicalBlock bounds it to the declaring block, exactly as C bounds a
  loop-body local. The unexpressible part — a pointer from iteration 1 naming iteration 2's
  object — is a property of the promotion, not of the location, and is documented.
- **An arena-placed value has no individual lifetime.** Its slot holds a pointer that is right
  while the binding is in scope; the storage dies with the region. DWARF has no "valid until
  this other PC", so nothing claims one.
- **A field may not be where the source says.** This one is described rather than omitted.
  Offsets come from `LLVMOffsetOfElement` over the struct LLVM built, so a LAYOUT 7.2
  permutation needs no special handling. A LAYOUT 6 hot/cold split gets a `__cold` pointer
  member and a second `Foo.cold` composite behind it — verified on a forced split: hot record
  32 bytes with `id`/`x`/`y`/`__cold`, cold record 40 bytes with the other five in the
  search's order. Listing all eight at eight offsets in the 32-byte record would have been
  the exact failure this feature must not have.

Note that the cold record's *measured* size is 40 bytes where the layout model predicted 32.
The model estimates; the DWARF reports what was built. They are allowed to differ and the
DWARF is the one that has to be right.

### 4. Four ways it was broken on purpose, and what each one failed on

`run_debug_info_test` is 132's newest and the suite's only coverage of any of this, so it was
checked in the direction that matters: a compiler was built with each mechanism broken.

| break | what failed |
|---|---|
| the `-g` gate removed (`if (true)`) | five markers found in a no-flag build |
| data layout not pinned | `target datalayout` missing; `Checkpoint.stamp` at bit 32, not 64; `Checkpoint` 96 bits, not 128 |
| cold block not described | "`--force-layout` produced no split composite" |
| `debugAt` moved from the statement to the block | "nothing is attributed to line 39 (`describe-return`)" |

The forced cut is **read from `prismio aif --layout`** rather than written down, because a
forced candidate the search does not offer is a warning and no split — a hardcoded number
would turn "the model reranked" into "this test quietly stopped checking".

### 5. Two things about the build that are not the metadata

Both were discovered by the feature appearing to work and producing nothing usable.

- **`-g` drops the object step to `-O0`.** `compile_ir_to_object` compiles at `-O2` and the
  measurements behind that stand, but at `-O2` every Prismio local is promoted out of its
  stack slot and every question a debugger can ask is `<optimized out>`. LLVM does not lie
  there — it drops locations rather than keeping stale ones — so the result is empty, not
  wrong, and empty is what a user reports as "-g does not work". `prismio build x.psm -O2 -g`
  still gets both, with `isOptimized` recorded in the compile unit.
- **Mach-O keeps DWARF in the object file**, and `compiler_build_executable` has always ended
  with `delete_file(program_obj)`. So on macOS the metadata was emitted, linked, and then
  deleted. `dsymutil` runs before that, and its failure is a warning rather than a build
  failure: a `.dSYM` is a copy of information that exists elsewhere, and refusing to produce a
  binary because the bundle could not be written turns a degraded `-g` into no binary at all.

### 6. Where the fidelity actually stops

- **A signature is the declared one, not LLVM's**, because everything with an address is `ptr`
  in the LLVM function type — a `String`, a `List`, a `Point` and an opaque extern return
  would all read `void *`. `ir_debug_signature`/`_param` buffer the declared keys between
  `ir_function_begin` and `ir_function_body_start`. It is used only when the count matches
  what LLVM built; it will not for `main`, whose real argc/argv codegen prepends, and the
  mismatch falls back to storage types rather than misaligning the list.
- **`String` is `char *`** and that is a statement of fact, not a nicety: `str_concat` and
  friends treat it as a NUL-terminated buffer, so a debugger prints the characters.
- **A `List<T>`, a `T?` and an array are opaque pointers.** Each is an address of something
  this layer has no layout for, and naming it something it is not would be the whole point
  missed.
- **`DILexicalBlockFile` is built and nothing in the tree reaches it.** Checked, not assumed:
  no program in `tests/` or `aif/corpus/` emits one, because `resolveImports` flattens without
  moving nodes between files and a monomorphised clone keeps its template's file on both body
  and function. Kept anyway — a DILocation inherits its scope's file, so the first pass that
  copies an AST node across a file boundary would introduce a silently wrong filename, and
  this is the code that stops it.
- **Cleanup code inherits the preceding statement's line.** Scope drops, arena pops and region
  exits are emitted after a block's last statement and the AST records no closing-brace
  position. The fix, if someone wants it, is to stamp the `}` token's span onto the BLOCK node
  in `parseBlock`; it is a real improvement and it is not a correctness problem. It also does
  *not* affect variable liveness, which is the thing you would expect it to — LLVM derives a
  DW_TAG_lexical_block's low_pc/high_pc from the instructions in the scope, not from the
  DILexicalBlock's line, and the dumps confirm it.
- **Module-level globals get none.** A program with `let mut counter = 0` at the top level
  emits `@counter` and zero `DIGlobalVariable`. This is a plain hole rather than a fidelity
  limit -- `generateModule`'s global loop has the type key and the span in hand and nothing
  calls `LLVMDIBuilderCreateGlobalVariableExpression`. Ranked second in NEXT-SESSION.
- **`prismio bootstrap` takes no `-g`.** The flag is parsed on `build`/`run` only, so the one
  program in this repo that would most repay stepping through cannot be. Ranked first.
- **`-g` needs a backend built against real llvm-c headers.** `prismio_llvm.h`'s hand-written
  fallback path refuses with a message instead. Twenty DIBuilder signatures, the longest of
  which takes nineteen arguments, transcribed by hand into a file the linker checks by *name*
  only, is how you get DWARF that is subtly wrong rather than a build that fails.

### 7. The gate

- suite **132/132** (`run_debug_info_test` is new)
- two-generation fixpoint `S10c == S10d`
- IR snapshot: 98 pre-existing programs, only `src/main.ll` moved
- AIF differential agrees on 17 sources
- cold build from the **committed seed** byte-identical to the warm chain
- `-g` builds all 78 programs in `tests/` + `aif/corpus/` with no failure
- `--verify` on `test_44` unchanged from the pre-session compiler (0 released, 0 violations
  both sides — see the note about which columns are noisy)

**Last-good: `build/S10d`.** The seed was not refreshed and did not need to be: no new syntax.

### 8. Found in passing, and it is not this session's

**`--target wasm32` builds nothing at all.** `Isize`/`Usize` lower to `i32` there while
`std/io.psm` declares `I64`, so `LLVMVerifyModule` rejects four calls with "Call parameter type
does not match function signature" -- and `std/io.psm` is merged into *every* module, so this
fires even for a `main` that does no I/O whatsoever. Confirmed pre-existing rather than assumed:
a compiler built from the committed seed fails identically with no `-g`.

Two further things about that flag, checked while confirming the above, because they change what
"fix wasm32" would even mean:

- **The build driver never passes `--target` to clang** -- zero occurrences in
  `build_driver.c`. So even with the verifier satisfied, `--target wasm32 -o x.exe` would emit
  wasm-triple IR and then compile it for the *host*. The only coherent path today is `-o x.ll`,
  which stops after writing IR, leaving the caller to drive `clang`/`wasm-ld` themselves.
- **`PRISMIO_WASM` is never defined by anything in this repo** -- zero occurrences in the driver
  and in both bootstrap scripts. The `#ifdef PRISMIO_WASM` runtime in `lang_runtime.c` (a bump
  allocator over `__heap_base`, a hand-written `memcpy`, `free` as a no-op, four host imports
  from the `env` module) is compiled by no build in this tree.

So it is an unfinished escape hatch rather than a supported target, and `V1_GAP_ANALYSIS.md`'s
"Host only; `--target wasm32` switches pointer width and little else" is the accurate grade.
Nothing native depends on it and it is inert unless asked for.

### 9. Next, ranked

See NEXT-SESSION's 2026-08-20 entry for the full form. In order: `-g` for `prismio bootstrap`;
`DIGlobalVariable` for module-level globals; the closing-brace span on BLOCK; enums as
`DW_TAG_enumeration_type`; a `--verify` that instruments reads.

---

## Session of 2026-08-19 (concurrency) — the `T` domain stops being vacuous, and T4a is emitted for the first time

**State, verified on the tree.** Suite **129/129** (128 at the session's start; `aif_concurrency` is
new). Two-generation fixpoint `S9c1 == S9c2`. **93 of 94 pre-existing programs emit byte-identical
IR**, the exception being `src/main.ll`, which changed because `src/` did. Differential agrees on
**17** sources, two of them concurrent. **Last-good: `build/S9c2`.** The seed was not refreshed and
did not need to be — `src/` uses no `spawn`.

### What this closes

`aif/implementation/COMPILER-AUDIT.md` finding 7: "there is no concurrency, so the `T` domain is
vacuous and T3 vs T4a is undecidable-by-absence", rated *"Medium — actually simplifying, for now"*.
That was the right call and it had an expiry date. What it deferred was not the rules — those were
written in INFERENCE 4.3 all along — but the only question that matters: **T3's non-atomic count is
sound only because nothing crosses a thread boundary**, and nothing could establish that while
nothing could cross one.

Note the filename. There is also a root `COMPILER_AUDIT.md`, with an underscore, whose §7 is about
testing and CI. The brief said "COMPILER-AUDIT finding 7" and meant the hyphenated one in
`aif/implementation/`.

### 1. The assertion the session was built around, and it holds

A single-threaded program emits **byte-identical** code to before the change, and it does so
*structurally* rather than by measurement. A module with no `spawn` raises no site above
`AIF_T_ISOLATED`: T-SPAWN-\* fires only on a spawn constraint, T-REACH can only propagate what some
rule already raised, and T-STATIC is guarded on `program_has_tasks`. So `T <= Transferred` holds
everywhere, SPEC 4.2's two new conjuncts are tautologies, and the ladder reads exactly as it did.

The one place that argument had a hole was **widening**. `aif_widen` raises everything in the
frontier to top, and raising `T` to `CrossThread` made truncated single-threaded builds derive T4a
— which broke `aif_widening` immediately and would have put atomics in a program with no threads.
The raise is now guarded on `program_has_tasks`, and the guard is not a weakening: "this program
contains no spawn" is not something the iteration was trying to prove and ran out of rounds for, it
is something the constraint set already said. Skipping the raise entirely *would* have been
unsound; making it unconditional was merely false.

### 2. Two departures from INFERENCE 4.3, both deliberate, both invisible to the differential

Shared decisions are exactly what an independent oracle cannot catch, so both are argued at the
rule in `runtime/aif_support.c` and repeated in `aif/prototype/aif.py`.

**T-SPAWN-SHARE's premise is `A = Shared`, and the rule is per-site.** INFERENCE writes the premise
as "y is still live in the parent", which under affine references is never *syntactically* true —
the move checker rejects any program naming the value twice. `Shared` is INFERENCE 2.2's "two or
more references whose relative lifetimes are not statically ordered", which is the fact that
survives. This is the move C-UNIQUE already makes one domain over: the aliasing module does the
work and the derived domain reads its answer.

**Per-site, not on the spawn's arguments — and testing the arguments was the first version and it
was unsound.** The spawn's argument is the *container*; the shared thing is the element, which
reaches `Transferred` through T-REACH and appears in no spawn's value set.
`tests/aif_concurrency_shared.psm` is that program, and it derived **T3 with a non-atomic count for
a value two threads could reach**. Read the rule as one sentence: a value that crosses a task
boundary at all, and has two references nothing ordered, is cross-thread.

**E-SPAWN-J is decided syntactically** — a straight run of statements from spawn to join with
nothing in between that can leave the block. Anything else answers "not joined", which raises
escape and costs a tier rather than soundness. `src/sema/flow.psm` already computes per-path
reachability for the missing-return check; that is where a precise answer comes from and it is
deliberately not this session's.

### 3. The result, which is more interesting than the feature

**Under isolation, T4a is hard to reach on purpose.** A value cannot become cross-thread by being
passed around — `spawn f(x)` moves `x`, so the parent's binding is dead. The two doors left open
are the whole CrossThread population: a static root (T-STATIC, blunt by design), and a value that
was already `Shared` before it crossed. Both fixtures had to work at it, and *how* they had to work
at it is the evidence: one detaches a task so nothing joins it, the other launders a value through
a second container so no binding names it twice.

The second-order result is sharper. With both containers **local**, `aif_concurrency_shared.psm`'s
element is CrossThread and lands at **T1** — because SPEC 4.2's T1 clause tests only `E`, and a
joined task cannot outlive the scope its arguments were allocated in. Cross-thread and *no count at
all*, which is cheaper than the atomic one, reclaimed by the arena reset after the join. That is
INFERENCE 4.1's "this single distinction determines whether concurrent code lands at T1 or T4"
arriving somewhere nobody expected it. Making the fixture reach the atomic path took giving it a
container from the caller.

### 4. Four things that cost time and should not cost it twice

1. **`spawn` was already an identifier in the tree** — `fn spawn(...)` in `aif/corpus/g4_ecs_world.psm`
   and a struct field `spawn:` in `tests/test_62_split_release.psm`. A reserved keyword would have
   stopped both compiling and failed the byte-identity rule for a reason unrelated to the change,
   which is the worst way to lose that signal. Both keywords are **contextual**, settled by one
   token of lookahead: `spawn` followed by an IDENTIFIER is a spawn, followed by `(` it is a call.
2. **Adding the `thread` column to the manifest broke five parsers in `tests/test_runner.py` at
   once**, every one holding a hard-coded `parts[2]` or `parts[5]`. They failed loudly, which was
   luck — an index sliding onto a neighbouring column reads a plausible string and asserts against
   it. They now go through `manifest_records()`, which is keyed by column *name*. Two more places
   needed the same care and would have failed *silently*: `tools/aif_manifest_diff.py`'s `RECORD`
   regex did not list T4a (so every cross-thread record would have been unparseable, and `parse`
   ignores what it cannot match), and its `TIER_ORDER` had no T4a either.
3. **The `@elem` key is one per container *base* type**, and every `List<T>` shares the base `List`.
   A cross-container push anywhere in a file marks every pushed site in that file as multiply held.
   The shared-element fixture is a separate file for exactly this reason, and its "control" function
   had to move out too — it reported CrossThread beside the case it was meant to contrast with.
   test_48 is the real control: identical aliasing, no spawn, **T3 / Isolated / non-atomic `rc`**.
4. **An unmodelled `extern` returning a container makes its result `Shared`** (`AIF_CON_OPAQUE`),
   which then trips T-SPAWN-SHARE. The first draft of the fixture used custom `report_list()`
   externs and landed the "this must stay non-atomic" case at T4a. Use `list_new`/`list_push`/
   `list_get`, which the walk summarises.

### 4b. The join analysis was a defect, not a compromise — and the differential could not see it

The first E-SPAWN-J was a forward scan. Its early-exit helper recursed into the statement's `next`,
so it asked "does anything between here and the end of the block leave" rather than "can control
leave *this statement*" — and every such block ends in `return join t`, which answered yes.

**Measured before rebuilding, as the note said to.** Five ordinary shapes; four fell off the cliff.
A single inert `let x = 1` between a spawn and its join took the argument from **T0 with no count
at all to T4a with an atomic one**. A loop with no `break` and a bare `if` did the same. The one
shape that worked — joining on the very next statement — is the one nobody writes, and is what both
existing fixtures happened to do.

**The oracle had already diverged and the differential passed anyway.** `aif/prototype/aif.py`
represents sibling statements as child lists, so it never had the `next` bug; on the measurement
fixture it reported `CrossThread 2` where the compiler reported `0`. The differential agreed on all
17 sources throughout, because no fixture on either side had a statement between a spawn and its
join. That is HANDOFF rule 5 exactly — a check that cannot fail — and the cause was fixture coverage,
not the oracle.

Replaced with `chainJoins` / `chainEscapesUnjoined`, two mutually recursive judgements in
`src/sema/flow.psm`'s style, mirrored in the oracle. They are **not** negations: falling out of the
bottom of a chain is *not joined* for one and *did not escape* for the other. The escape test runs
first, which is what keeps `if (c) { return 0 }` followed by `return join t` correctly unjoined.
`break` now carries an `inLoop` flag, so a break absorbed by its own loop stops counting as an exit.

Five shapes added to `tests/aif_concurrency.psm` and asserted in the runner, including
`one_path_escapes_unjoined`, which must **stay** T4a — being wrong in that direction is a
use-after-free, not a lost tier. Verified the differential now has teeth: reverting the oracle's
break handling alone makes it report `DIFFER` on `aif_concurrency.psm`.

### 4c. `Task<R>` — the restriction was the lowering, and it lifted cleanly

`spawn` yields `Task<R>`; `join` yields R — Int, a reference type, or nothing. Safe because the
compiler knows R statically and picks a correctly-typed function pointer: `prismio_task_invoke` now
has three families across four arities, twelve typedefs. One signature plus a cast works on every
ABI anyone ships and is still undefined, and with *return values* it stops being formal — an
i32-returning function called through a `void*`-returning pointer leaves the upper half of the
register undefined on the targets this compiles for. Float and the sized integers are refused with a
diagnostic that says why.

The handle stays PTR-kinded with a `child`; a `Task` TypeKind would have to be added to every switch
in sema, AIF and codegen to reach the behaviour PTR already has. Two things worth keeping:

- **`Task<R>` had to become writable as an annotation.** Before it was, it resolved to Invalid — and
  Invalid matches everything, so `let t: Task<Int> = spawn name_span(j)` type-checked against a
  `Task<String>`. A type nobody can spell is a type nobody can get wrong; one that silently resolves
  to Invalid is worse than either.
- **The sem key was written with its decoder this time.** `task:<inner>` round-trips, because the
  optional bug three sections down was exactly the same hole and had sat there for twelve days.

### 4d. SPEC 11.0's levels table, resolved (1.2.4)

The row read `none` for AIF-2 while the same column's Inference row read "+ thread". Those cannot
both be requirements: a thread domain with no tasks is vacuous by construction, and an
implementation meets it by writing the lattice down and never consulting it — which is precisely
what this one did for its whole life, while emitting a `T` distribution that could only read
`Isolated N`.

AIF-2's cell is now `isolation`; AIF-3's is `+ unrestricted sharing`. The compiler still declares
**AIF-1** — it meets none of AIF-2's other seven rows — and the manifest records `exceeds
inference:thread concurrency:isolation` instead. Recorded as RATIONALE C11. This is a governance
call on a normative document; reverse it there if you disagree.

### 5. Found in passing, fixed immediately after (REQUIREMENTS 4)

**A function declared to return an optional lost the optional-ness through a binding.**
`let r = f()` on a `-> Node?` function gave a value that could not be compared with `none`.
Reproduced on `build/S9x2`, so not a regression from this session; it cost the channel fixture its
drain protocol.

**The cause was not where it looked.** `parseTypeAnnotation` sets `i3` for the `?`,
`semaDeclaredReturnType` delegates to `semaAnnotationType`, and that peels the suffix — the whole
path from source to call site was correct, and `f() == none` written *inline* compiled fine. The
loss was on the way back **out of a binding**: sema stores a local's type as a sem-key string,
`typeSemKey` wrote optionals as `opt:<inner>`, and `typeFromSemKey` had no branch to read it back,
so every optional through a `let` decoded to `Invalid`. Optional fields never enter a sem key, which
is why `tests/test_51_optional_refs.psm` — all fields — stayed green throughout.

One probe separates those two halves in a single build: compare the call result *without* binding
it. If that compiles, the parse and sema paths are fine and the fault is in the round-trip.

Fixed by adding the missing `opt:` case to `typeFromSemKey` (`src/ast/types.psm`).
`opt:Invalid` decodes to `none` rather than `typeOptional(Invalid)`, and that is load-bearing:
`typeSemKey` maps both to the one string, and only `none`'s empty child gets typeEquals's
"matches any optional" behaviour. Covered by `tests/test_68_optional_returns.psm`, which fails with
six errors on `build/S9c2`. Suite **130/130**; only `src/main.ll` moved.

### 6. Where the atomics actually are

`rc_retain_atomic` / `rc_release_atomic` in `runtime/lang_runtime.c`, reached through two new
element dispositions (`AIF_ELEM_RC_ATOMIC` 6, `AIF_ELEM_CYCLE_ATOMIC` 7) and `ir_free_rc_atomic`.
**A separate symbol chosen at compile time, not a flag the runtime tests** — the point of inferring
thread affinity is that the answer is known statically, so a value proved never to cross a thread
boundary should not pay even a predictable branch to establish it. Relaxed on the increment,
acq_rel on the decrement.

Verified in emitted IR, not just in the manifest: `aif_concurrency_shared.psm` emits
`list_set_elem_owner(..., i32 6)` and `test_48_aif_shared_elements.psm` emits `i32 3`, and
`run_aif_concurrency_test` asserts both.

### Next, ranked

1. **Give E-SPAWN-J a real flow analysis.** The syntactic version costs a tier on any spawn with a
   loop or a conditional between it and its join, which is most real code. `src/sema/flow.psm`
   already has the machinery.
2. **The optional-return gap in §5.** Small, pre-existing, and it blocks any FFI that wants to
   report absence.
3. **`Task<T>`.** A task handle is a `Ptr` and `join` yields `Int`, which is honest but thin. The
   restriction is the *lowering* (three `void*` slots and an arity switch), not the model —
   REQUIREMENTS 3a's closures are what a general answer wants.
4. **Decide the SPEC 11.0 levels question.** The table gives AIF-1 "Concurrency: none — `T` is
   vacuous", and this implementation declares AIF-1 and exceeds that row. Not a conformance
   violation; the table is now describing something the implementation is not.

---

## Session of 2026-08-19 (payload enums) — `Option` and `Result` land, and a partial struct literal turns out to have been reading uninitialised memory

**State, verified rather than remembered.** Suite **128/128**. Two-generation fixpoint
`S7x3 == S7x4`. Cold build from the **committed seed** byte-identical to the warm chain on all 89
programs. IR unchanged from the generics build on every pre-existing program except `src/main.ll`.
AIF differential agrees on **15** sources. **Last-good: `build/S7x4`.**

### 1. What landed

Enum variants that carry values, and `Option<T>` / `Result<T, E>` built on them in
`std/option.psm` — REQUIREMENTS 14, which was the item HANDOFF's own known-gaps list called the
first thing users hit.

**The representation is a tagged struct, and the desugaring is an AST transform** — the same
architecture as monomorphisation, for the same reason. `enum Shape { Dot, Circle(Int) }` becomes
`struct Shape { $tag: Int, Circle$0: Int }`, the original is parked on `module.child3` as a shadow
so construction and `match` can read tags and payload types, and **sema, AIF, the layout optimiser
and codegen were not taught what an enum with payloads is.** Field access is the `getelementptr` it
always was.

**A tagged product, not a tagged union, and that is forced rather than chosen.** Overlapping the
variants needs the size of the widest, and the size of a type is REQUIREMENTS 18 — still open. So
each payload slot gets its own field. `Option<T>` pays nothing for this; a many-armed enum with big
payloads pays space. When 18 lands the overlap goes in `src/sema/enums.psm` and no caller changes.

Generic payload enums compose with session 1's work for free: `monoIsTemplate` grew one clause,
instantiation desugars *after* substitution, and the shadow pushed is the instantiated enum — which
is why `fn optionOr<T>(o: Option<T>, …)` can still recover `T` after the type has become a struct
named `Option$Int`.

### 2. The bug this feature found, which predates it

**A struct literal that omitted a field type-checked and then read uninitialised memory.**
`struct P { a: Int, b: Int }` with `P { a: 1 }` was accepted, and the emitted IR loaded `b`'s slot
with nothing having stored to it — allocation is `malloc`, not `calloc`. It read 0 on a fresh page,
which is why nothing had noticed:

```llvm
%3 = getelementptr inbounds nuw %P, ptr %2, i32 0, i32 0
store i32 1, ptr %3, align 4          ; a
%5 = getelementptr inbounds nuw %P, ptr %4, i32 0, i32 1
%6 = load i32, ptr %5, align 4        ; b -- never stored
```

`semaFillOmittedFields` appends a zero for every omitted field, for **all** structs and not only
these. An inline struct field's zero is an empty literal of that struct, filled by the same rule one
level down; everything pointer-shaped takes `none`, which already lowered to `null`. No test or
corpus program changed, so nothing in the tree was relying on it.

It is also what makes `Option.None` safe: the literal mentions only the tag, and the `Some` slot has
to be a defined value rather than whatever was in that memory.

### 3. The node-lifetime rule, stated once because it cost three crashes

Every one of these compiled and then died in `SIGABRT` far from the cause, with no diagnostic.

> **A node bound to a name and reached only through `node_to_ptr` is on that scope's drop list.**
> It is freed at the closing brace — or, in a loop, at the end of each iteration — while the chain
> that points at it lives on.

The two safe shapes, both already used throughout the frontend:

- **Return it.** `fn build() -> ASTNode { let n = createNode(…) … return n }` moves it to the caller.
  `monoCopyOne` ended `return node_to_ptr(dup)` and was reclaimed before its first reader.
- **Build it inline as an argument.** `nodeListPush(fields, buildSlot(…))` is a temporary with no
  owner and no free point — HANDOFF's own "a temporary has no owner and so no free point", read from
  the useful direction.

`enumFieldNamed` and `enumPayloadSlot` are split into two functions each *only* for this. Folding
them back reintroduces the use-after-free.

A related one, from the same family: **an owned `String` may be named once.** Write it onto the node
that will keep it and read the field, which is a reborrow. `arm.s2` and `stmt.s1` in the match code
are that, not sloppiness.

### 4. Exhaustiveness, and what is deliberately not there

**Exhaustiveness is checked**, and so is arm reachability. A match over a payload enum must cover
every variant or carry a `_` arm; the diagnostic names the missing ones. A second arm for a variant
an earlier arm already matches is rejected as dead code. Both read the tags the arms already carry
(`i1`) against the variant list on the shadow chain, so neither needed new state.

Both are **payload enums only**. A fieldless enum still matches as an integer, where the scrutinee is
not confined to the declared variants and matching a subset is legitimate. Extending it there is a
separate decision that can reject existing code.

Nothing in `tests/` or `aif/corpus/` had a non-exhaustive or duplicated arm — the `SKIPPED` delta
across the change is the new negative fixtures and nothing else, which is how that was established
rather than assumed.

- **No `unwrap`.** `optionOr`/`resultOr` take a fallback; the absent case is unavoidable at the use
  site, which is the point of the type.
- **No propagation operator.** It needs a defined interaction with ownership and with cleanup during
  a non-local exit, and neither is specified.
- **`Result.Ok(5)` cannot infer `E`** — type arguments are solved from what a variant carries, and
  nothing in `Ok` mentions the error type. Written out, or diagnosed by name (`neg_28_enum_infer`).

### 4.5 Two fixtures in `tests/` are reconstructions, and how that was checked

`test_62_split_release.psm` and `test_63_placement_pin.psm` were deleted during this session by an
over-broad `rm` glob (`tests/test_6*_*` intended to remove stray built binaries, which also matches
the `.psm` sources). They were untracked -- written in the 2026-08-17 sessions and never committed
-- so git could not restore them.

Both were rebuilt from the emitted IR of the previous generation, held in an `ir_snapshot.py`
directory taken earlier in the session, plus the assertions in `run_split_release_test` and
`run_placement_pin_test`. **Both now compile to byte-identical IR to the originals**, which is the
strongest available statement that the programs are the same: same structs, same split, same
manifest records, same ledger, same emitted code. Only the comment prose is new, and each file says
so in its header.

The lesson worth keeping is the general one: `tests/*.psm` fixtures that are not committed have no
recovery path but the IR snapshots, and the snapshots only exist because CODE_STYLE's
byte-identical rule requires them. **Commit fixtures with the change that needs them.**

### 5. The gate

```bash
bash tools/bootstrap.sh --compiler build/S7x4 --out build/g1
bash tools/bootstrap.sh --compiler build/g1 --out build/g2
python3 tools/ir_snapshot.py --compiler build/g1 --out /tmp/a
python3 tools/ir_snapshot.py --compiler build/g2 --out /tmp/b
diff -r /tmp/a /tmp/b
PRISMIO=build/g2 python3 tests/test_runner.py
python3 tools/aif_differential.py --compiler build/g2
```

`neg_27_generic_arity`, `neg_28_enum_infer`, `neg_29_match_not_exhaustive` and
`neg_30_unreachable_arm` are expected in `SKIPPED`.

### 6. Next, ranked

1. **REQUIREMENTS 18 — the size of a type.** Now gates two things rather than one: containers in
   Prismio, and the tagged *union* that would shrink every payload enum.
3. **Bounds on type parameters**, which turn `std/map.psm` into a hash table.
4. **Ownership contexts** (INFERENCE 6), reusing the instantiation machinery.

---

## Session of 2026-08-19 (generics) — monomorphisation lands, and two of the brief's four premises were wrong

**State, verified rather than remembered.** Suite **123/123** (120 before `test_64_generics`,
`test_65_map`, `neg_27_generic_arity`). Two-generation fixpoint `S7g10 == S7g11`. Cold build from
the **committed seed** reaches a compiler byte-identical to the warm chain on all 89 programs
(`S7cold1 == S7g11`), so **the seed did not need refreshing** — `src/` uses no new syntax.
IR is byte-identical to the pre-session baseline on **88 of 89** programs; only `src/main.ll`
moved, which is `src/sema/generics.psm` existing. AIF differential agrees on **15** sources.
**Last-good: `build/S7g11`**; `build/S7base` is the pre-session generation.

### 1. What landed

Generic functions and types with monomorphisation, in `src/sema/generics.psm` (~430 lines) plus
hooks in four places. The shape is worth stating because it is what keeps the blast radius small:

**Instantiation is an AST-to-AST transform, and sema and codegen were not taught about generics at
all.** `Box<Int>` becomes an ordinary struct named `Box$Int`; `identity<T>` called on an `Int`
becomes an ordinary function named `identity$Int`. Everything downstream — field lookup, overload
resolution, AIF, the layout optimiser, codegen — sees only concrete declarations and needed no
change. The emitted types are the proof that this is monomorphisation rather than erasure:

```llvm
%"Box$Int"    = type { i32 }
%"Pair$Int$Int" = type { i32, i32 }
%"Box$String" = type { ptr }
```

`$` is the separator because it cannot occur in a Prismio identifier, so an instantiation can never
collide with a declared name.

- **Templates leave the module chain before sema**, parked on `module.child2` by
  `monoCollectTemplates` at the end of `resolveImports`. Not tidiness: `semaCacheFunctionSymbols`
  overwrites `s2` on every FUNCTION in the chain, and `s2` is where the parser puts the type
  parameters. A template left in the chain has its parameter list destroyed before the first
  instantiation can read it.
- **Instantiation is demand-driven and appends to the chain sema is still walking**, so the loop
  that asked for an instantiation reaches it in the same pass, and an instantiation may itself
  instantiate. A generic that is written and never called emits nothing.
- **Inference is structural and argument-position only.** `fn first<T>(xs: List<T>)` solves `T`
  from the element type. Nothing is solved from a return type, which is why constructors need
  `mapNew<Int, Int>()` written out.
- **The instantiation records what it was made from** (`copy.child2`). Without it a type parameter
  is unrecoverable the moment it is substituted: `Map<Int,Int>` becomes a struct named
  `Map$Int$Int`, and a later `fn mapLen<K,V>(m: Map<K,V>)` has nothing to match `K` against.
  Reading the mangled name back apart would work until an argument contained the separator.

`Map<K,V>` landed as `std/map.psm` — the first container written in Prismio rather than C — and
`std.*` imports now resolve against the compiler's own library rather than relative to the
importing file (`resolveImportPath`), which is what `import std.map` needed.

### 2. Two of the brief's four premises did not survive contact with the tree

Recorded because both were stated confidently and both cost time to disprove.

- **"Monomorphisation interacts with ownership contexts from session 1 — both duplicate bodies.
  Make sure the two mechanisms share one implementation."** There is no such mechanism. Nothing in
  `src/` duplicates a function body, and `aif_support.c:5156` says so in as many words: INFERENCE 6's
  ownership contexts are "the specified fix … and that is a project, not a clause." There was
  nothing to unify. What was done instead is the half that has value: instantiation is built in the
  shape INFERENCE 6.3 specifies for contexts — discovery at the call site, a key derived from the
  call, a monotonically growing module, and a dedup check before emission — so contexts can reuse
  `monoCopyOne` / `monoSubstituteChain` / `monoAppendDeclaration` with a context tuple as the key
  instead of a type tuple. **The next person should not rebuild that; it is one new key function.**
  INFERENCE 4.7's "the product collapses to a sum" then falls out: monomorphise on types, policy
  parameter on ownership, which is 7.0.1's middle strategy.
- **"`Vec<T>` is missing."** `List<T>` *is* the growable vector. `XefyList` is a `void**` that
  doubles on push and the runtime's own comment calls `list_new_with_capacity` "Vec::with_capacity".
  REQUIREMENTS 13 asked for two containers and was missing one.

### 3. The replacement test in the brief could not be run, and the reason is a capability

The brief made replacing the hardcoded `List<T>` "the test that the feature is real". Half of it
happened: the **parser's** `List` special case is gone — `str_equals(typeNode.s1, "List")` was the
only reason `List` was the sole generic type, and type arguments are now general for any name.

The other half is impossible today, and not for want of effort. **`List<T>` cannot be written in
Prismio**: it needs the size of its element type (REQUIREMENTS 18, still open) and a way to index
raw memory as `T`, and `Ptr` is opaque — no arithmetic, no deref, no indexing. `TypeKind.LIST`
survives because List's *implementation* is builtin, which is a different claim from the generic
system being fake. The same two gaps are the answer to "how much of `aif_support.c` moves into
Prismio": almost none, and it is a capability statement rather than a preference. See
REQUIREMENTS 13.

### 4. Three bugs, all of them the affine memory model, all worth not rediscovering

Every one of these compiled and then crashed or corrupted at runtime, far from the cause.

- **A node-building function must return `ASTNode`, never `String`.** `monoCopyOne` ended
  `return node_to_ptr(dup)`, handing back a pointer to a local the scope then dropped; the copy was
  reclaimed before its first reader, and `check` died in `SIGABRT` with no diagnostic. Returning
  the node moves it to the caller. Every node-builder in the frontend is shaped this way and
  `parseParameterList` returning `params.head` is the same rule seen from the other side. Chains
  are built with `nodeList()`/`nodeListPush`, which is where the move lands.
- **A freshly built `String` may be named once.** `let mangled = …` then using it four times is
  four moves. The fix is to write it onto the node that will keep it and read that field, because a
  field read is a reborrow. Parking it on a *scratch* node is worse than useless — automatic arena
  placement reclaims a scope's allocations at its exit, so the declaration outlives its own name.
- **Speculative parsing may not mutate.** `parserExpectCloseAngle` splits a `>>` token in place,
  and that edit survives a rewind — `a < b >> c` would come back from a failed speculation as
  `a < b > c`. `parserLooksLikeTypeArgs` is a pure scan over the token chain that builds nothing
  and edits nothing; only after it commits does the real parse run.

### 5. What did not land, and what it needs

**`Option<T>` / `Result<T,E>` — not started.** Generics did not make it cheap, which was the
session's working assumption and was wrong. It needs payload-carrying enum variants: a tagged
union, a layout sized by the widest variant, `match` arms that bind the payload, and move/drop
rules that know which variant is live. A struct cannot stand in — `Option<T> { present: Bool,
value: T }` has no `T` for the absent case. Once enums carry payloads, `enum Option<T>` instantiates
through this session's machinery unchanged: `monoIsTemplate` admits FUNCTION and STRUCT_DECL, and
ENUM_DECL is a one-line addition beside them. REQUIREMENTS 14 has the ordered list.

### 6. The gate

```bash
bash tools/bootstrap.sh --compiler build/S7g11 --out build/g1
bash tools/bootstrap.sh --compiler build/g1 --out build/g2
python3 tools/ir_snapshot.py --compiler build/g1 --out /tmp/a
python3 tools/ir_snapshot.py --compiler build/g2 --out /tmp/b
diff -r /tmp/a /tmp/b                      # fixpoint
PRISMIO=build/g2 python3 tests/test_runner.py
python3 tools/aif_differential.py --compiler build/g2
```

`ir_snapshot.py`'s `SKIPPED` file is part of the comparison: a program that *stops* building shows
up there rather than as a smaller directory. `neg_27_generic_arity` is expected in it.

### 7. Next, ranked

1. **Payload-carrying enums, then `Option`/`Result`** (REQUIREMENTS 14). The first thing users hit,
   and the machinery to instantiate them generically already exists.
2. **REQUIREMENTS 18 — the size of a type.** It is the gate on every remaining container question:
   `List<T>` in Prismio, `aif_support.c` migration, and any user-written allocator.
3. **Bounds on type parameters.** Turns `std/map.psm` from an association list into a hash table
   with no caller change, and is what INFERENCE's worklist wants.
4. **Ownership contexts** (INFERENCE 6), reusing this session's instantiation machinery with a
   context tuple as the key.

---

## Session of 2026-08-17 (compile time) — the frontend goes linear, the build caches its objects, and the measurement moves incrementality out of AIF

**Scope: REQUIREMENTS 16, INFERENCE §9, REQUIREMENTS 10 (specify only), and a compile-time
report.** Nothing here touches the arena, the layout model, the split transform, or any tier rule.
Every number below is in [RESULTS-compile-time.md](aif/evidence/RESULTS-compile-time.md).

### 1. REQUIREMENTS 16 was four scans in three passes, not one

The requirement names sema's per-identifier function lookup. That was the biggest of them and the
profile agrees — 331 of 363 samples inside `semaFindFunctionOverload` — but fixing only it leaves
a program with *no calls at all* still superlinear. The four:

| where | scanned | once per |
|---|---|---|
| `semaFindFunctionOverload` | every top-level declaration | call site |
| `find_binding` (`ir_symbols.c`) | the binding table, floored by one `$fn$` entry per function | identifier, in sema **and** codegen |
| `hasNamedTopLevel` (`main.psm`) | everything merged so far | merged declaration |
| `appendStatement` (`main.psm`) | to the end of the list | merged declaration |

Three mechanisms replace them, and each is smaller than what it replaced:

* **A name → declaration index in `ir_symbols.c`** (`ir_index_decl` / `ir_decl_count` /
  `ir_decl_at`), filled by `indexModuleDeclarations` in `src/ast/types.psm`. It is a cache of
  exactly what a walk of `module.child1` would find, in the same order — and source order is
  load-bearing twice: the duplicate-definition note points at the *first* declaration with a
  symbol, and overload resolution breaks a literal-score tie by keeping the first candidate.
  `analyzeModule` and `generateModule` each rebuild it, so neither depends on the other having run.
* **`ir_set_fn_return_type` / `ir_get_fn_return_type`**, a table of its own. The `$fn$<symbol>`
  key was a *binding*, deliberately surviving `ir_clear_local_var_types`, so `find_binding`'s
  backwards scan walked past one per function for every identifier in the program. The prefix is
  gone with it — there is no shared namespace left to disambiguate — and so is a `str_concat` per
  call expression in codegen.
* **A cached tail for the import merge**, plus `hasNamedTopLevel` asking the index.

Two deletions fall out. `semaFunctionSymbolCount` is gone: all candidates for a symbol collision
share a *name*, so they are one index entry, and "the earliest declaration with my symbol is not
me" is the whole duplicate condition — the count was only ever a guard on it. `findStructDecl` in
`src/ir/module.psm` is gone; it was a fifth copy of `findStructDeclNamed`.

**Measured** (minimum of 3–5, RESULTS-compile-time §1): `check` on a 4 000-function module
1.241 s → **0.088 s**; on the compiler's own 518 KB, `check` 0.126 → **0.039** and emit-IR
0.183 → **0.090**. Per-doubling cost goes from 3.3–3.8× to 1.9× once the ~12 ms process floor is
subtracted: **linear over 31 KB–922 KB.**

### 2. The IR delta is a slot renumbering, on all 89 programs, and it is worth understanding

`$fn$` bindings were *locals*, so `add_binding` gave each one a slot serial it never used. Taking
them out of the table shifts every `%name.N` in every program — `%value.43` becomes `%value.0` —
with no instruction, type or ordering changed. **89 of 89 programs move and none differ.**

Verified rather than asserted: `tools/ir_slot_diff.py` normalises `%name.N` to `%name.#` and
compares, *and* compares the count of distinct slot names per file, because normalising alone
would hide two bindings collapsing onto one slot — which is the exact defect the interning comment
in `ir_symbols.c` records. The alternative was to burn a serial per predeclared function to keep
the old numbering, i.e. to pad the IR to match a table entry that no longer exists.

**If you diff IR across this session, use `tools/ir_slot_diff.py`, not `diff`.** Within the
session everything is byte-identical: warm fixpoint, cold fixpoint, cold == warm, all 89.

### 3. INFERENCE §9: priced, then not built, and the price is the finding

`--debug` is a zero-round budget, so a `--debug` build and a release build differ by the entire
inference engine. On the compiler's own source that difference is **18 ms** — 19% of the frontend,
**under 1% of a build**. And a cold build of a 505 KB project is **75.8% `clang -O2` on the emitted
IR** and 3.7% Prismio frontend.

So the projection that Prismio's incremental rebuild might be 1.0–5× *worse* than Rust's because
whole-program inference is non-incremental is refuted at its premise. The fixed point is not what
makes a rebuild slow; LLVM is, exactly as it is for Rust. **A summary cache keyed per §9 would be
optimising 0.7% of a build**, and it needs the engine partitioned per function with a reverse call
graph — `aif_support.c` has one flat global constraint array and no per-function anything.

What was built instead is the thing the measurement points at, and it is REQUIREMENTS 10's
mechanism applied to the one module every build shares: **a content-keyed cache for the toolchain
objects** (§4 of RESULTS-compile-time). A 34-line program rebuilds in **0.18 s against 0.42 s**.

**`tools/incremental_manifest.py` is §9's required test, and it runs today.** §9 says an
implementation SHOULD verify that reuse changes no answer, "because summary-cache bugs are silent".
The compiler already carries state across invocations that can leak into the analysis — the
workload profile, whose path LAYOUT §2.2 deliberately makes predictable, the object cache, and any
`.prismio-*` left behind — so the harness applies a series of edits to one file at one path and
compares the manifest against the same text with that state wiped. It asserts three things about
itself, because the equality would otherwise be satisfied by a compiler that ignored its input:
the edits must produce distinct records, returning to the base text must return the base records,
and `--budget=1` must differ from the converged run. All pass on `R7`.

### 4. The object cache, and the one thing its test cannot reach

`$TMPDIR/prismio-objcache/<role>-<hash>.obj`, FNV-1a over role + flags + source text. Flags are in
the key because a `-DPRISMIO_AIF_VERIFY` object in a release build puts half the allocations
outside the ledger. Installed by rename from a pid-qualified temp, so two concurrent builds cannot
link a half-written object. `PRISMIO_OBJ_CACHE=0` bypasses and says so in the trace — "not
consulted" and "consulted and empty" are different facts, and a bypass reporting a miss is
indistinguishable from one that does not bypass.

Not covered: an in-place clang upgrade. Folding `clang --version` into the key costs 28 ms, 14% of
what the cache saves. The bypass is the documented escape.

`run_object_cache_test` (suite 117 → **118**) asserts cold-miss, warm-hit, that the linked program
runs, that `--verify` keys separately and hits itself, and that the bypass bypasses. Two of its
assertions were *seen* to fail during development, which is how it is known to discriminate.
**It cannot assert the content half of the key**: a normal build unpacks the runtime embedded in
the compiler binary rather than reading `runtime/` from disk, so nothing a test can edit reaches
what gets compiled. Stated in the docstring rather than implied.

**The bootstrap scripts cache too**, and that is where the money was: 1.44 s of the compiler's
2.67 s self-build was recompiling seven unchanged C files. Both `tools/bootstrap.sh` and
`tools/bootstrap.ps1` now consult the same directory on the same content key — **2.67 s → 1.58 s,
41% off the loop this project runs most.**

That path's contract is that an edit to `runtime/*.c` reaches the next generation, so a stale entry
poisons a compiler *generation* rather than a test binary. Two consequences worth not re-deriving:

* **Every `runtime/*.h` goes into every entry**, `embedded_sources.h` included. It is regenerated
  whenever any runtime source changes, so a runtime session invalidates all seven and gets nothing
  — deliberately the wrong-but-safe side. A `.psm`-only session hits all seven.
* **`openssl` is preferred over `shasum`**, which is a Perl script: eight invocations cost 0.178 s
  against 0.070 s, and 0.178 s is 16% of what the cache saves.

Both scripts expose `--print-cache-key` / `-PrintCacheKey`, which computes the key and nothing
else, so `run_bootstrap_cache_key_test` (suite → **119**) asserts stability, per-source
distinctness and sensitivity to *both* the source and the headers in milliseconds instead of by
bootstrapping. The header assertion is verified discriminating: drop the header term from the key
and exactly that one fires. **The PowerShell half is unverified** — there is no PowerShell on this
host, so it is written to mirror the shell one and read rather than run. CI's Windows leg sees it
first.

A compiler built entirely from cached objects produces **byte-identical IR on all 89 programs** to
one built with `PRISMIO_OBJ_CACHE=0`.

### 4.1 The same hole was in the build driver's cache, and it was mine

The first version of the object cache keyed on the compiled source alone. **A header changes what a
`.c` compiles to without changing a byte of it**, so a session that edits `prismio_runtime.h`,
regenerates `embedded_sources.h` and rebuilds — which is what a runtime session *is* — would have
been served an object built against the previous header. Fixed in both places, and the bootstrap
test is written around exactly that direction.

### 4.2 The first hard ceiling on program size is gone

`internal backend error: value table exhausted` at about 3 500 functions. `g_values` and `g_blocks`
were fixed arrays of 65 536 and 16 384 indexed by a counter that runs for the whole **module**, so
they bounded program size rather than anything a function could do. They grow now, the way every
table in `ir_symbols.c` does and for the reason stated there.

The initial capacity is the old fixed size, so nothing below the old ceiling allocates differently:
**IR byte-identical on all 89 programs**, warm and cold fixpoint unchanged. A 1.85 MB source (8 000
functions) now compiles — `check` 0.169 s, emit-IR 0.553 s, still linear.

### 5. REQUIREMENTS 10 is specified as SPEC §7.5

Four obligations that are not obvious, and are why it needed writing before building:

* **A level boundary is an inference boundary.** A `debug` module proved nothing, so a `release`
  module must treat its functions as an undeclared `extern` — FFI §1's conservative default. Read
  summaries across it and a tier rests on an analysis that never ran.
* **Lowering a level invalidates the dependents**, exactly as §9 invalidates a reverse-reachable
  set. The level is part of the cache key.
* **Layout is not per module** — one layout per type, chosen by the declaring module, read from the
  manifest by everyone else. Two modules disagreeing about a field offset is a miscompile.
* **`verify` is not per module** — the allocator seam swaps at both ends of every allocation.

Plus the normative half that makes the feature usable: the manifest SHALL record each module's
level, and a record whose module was built at a different level from the baseline's is *not
comparable* rather than a regression. Without it, dropping one module to `debug` reports several
hundred §6.3 regressions where one line is the explanation.

It also needs what this compiler does not have — a compilation unit. `resolveImports` merges
everything into one module and codegen emits one `.ll`, so there is no per-module object to compile
at a level or to cache. Same prerequisite as REQUIREMENTS 21 (PIR).

### 5.1 Benchmarked, and the answer to "are incremental builds done" is no

`aif/evidence/compile_bench.py`, four scenarios per program (RESULTS-compile-time §3). The column
that settles it is **no-change**: rebuilding with *nothing edited* costs the same as rebuilding
after a real edit — 0.176 s against 0.178 s on a small program, 2.692 s against 2.702 s on a
505 KB one. **Nothing about the program's own compilation is reused.** The cache reaches the
toolchain and stops.

| program | cache off | incremental | |
|---|---|---|---|
| 34-line | 0.535 | **0.178** | 3.0× |
| `g1_particles` | 0.541 | **0.358** | 1.5× |
| synthetic 505 KB | 2.985 | **2.702** | 1.10× |
| the compiler (`bootstrap.sh`) | 2.96 | **1.58** | 1.9× |
| **the suite** | **226.3** | **169.9** | **1.33×** |

The ratio falls as the program grows because `clang -O2` on the emitted IR is untouched — 2.5 s of
the 505 KB build. §6 prices the fix.

Two things worth knowing about the shape that is left: a small warm build is **frontend 0.015 +
program object 0.052 + link 0.14–0.18**, so *the link is now the floor*; and `-fuse-ld=lld` is the
obvious next lever but could not be measured, because this host's LLVM ships no `lld`.

### 5.15 The profile race is fixed, and two more bugs with it

**The workload profile race (RESULTS-layout §7) is closed.** It was the one known open defect in
the tree, and it mattered out of proportion to its size: it made `tools/ir_snapshot.py` — this
project's definition of a behaviour-preserving change — report a **false difference** whenever
anything else was compiling, silently and with no diagnostic.

Reproduced before fixing, because a fix for a bug you cannot make happen is a guess: racing
`aif --layout` against `build` on `test_55`, **2 of 30 rounds diverged**. After: **0 of 90**.

All three of the workload runner's temp paths carry the pid now
(`compiler_temp_private_path`), so a build writes and reads its own driver IR, driver executable
and profile. LAYOUT §2.2's predictable artifact is **published** afterwards by
`compiler_publish_file` — written to a sibling temporary and renamed, so a concurrent reader sees
the old file or the new one and never half of one. **Nothing reads the predictable copy; it only
has to exist**, which is what makes the two requirements compatible where they looked opposed.

The private copy is deleted by each of the three consumers of the path `runWorkloadProfile`
returns. It has to be explicit: the path carries this process's pid, so no later build will clean
it up, and the language has no `defer` — the same discipline `endWorkloadPass` already documents.

**`prismio bootstrap` had not been able to link a compiler since the backend moved to the LLVM C
API. It works again.** It compiled everything and then failed with several hundred undefined
`_LLVM*` symbols, because its link line had no `-lLLVM-C`. Nothing in the tree runs it — CI and
every session use `tools/bootstrap.sh` — so nothing noticed for months. Worse than the bug: on a
failed build of the compiler, `compiler_build_executable` printed a NOTE **telling the user to run
it**, a signpost pointing at a trap.

`find_llvm_paths` resolves LLVM from the same two places the bootstrap scripts read, in the same
order — `PRISMIO_LLVM_DIR`, then `third_party/llvm-paths.json` — so there is one answer to "where
is LLVM" rather than two that can drift. The backend half compiles with
`-DPRISMIO_LLVM_REAL_HEADERS -I<llvm>` and links with `-L<lib> -lLLVM-C`, and both land in the
object cache key, because the key hashes the whole flag string.

**Verified by the property that matters, not by "it linked".** A compiler can link and still be
wrong — built against the stub declarations in `prismio_llvm.h`, or against a different LLVM. The
compiler `prismio bootstrap` produces emits **byte-identical IR on all 89 programs** to one built
by `tools/bootstrap.sh`. `run_bootstrap_command_test` asserts that (suite → **120**) and is
verified discriminating: remove the `-lLLVM-C` and it fails, naming the link error.

That test is also the answer to the objection that nearly left this unfixed. There are two recipes
for linking a compiler, and two copies of a recipe that must agree is the defect this project
produces most — *these two already disagreed, which is how this got here*. A check is what makes
the next disagreement loud rather than silent, and that is cheaper than refusing to have the
feature.

### 5.2 Three bugs in the cache, two of them mine from earlier today

* **`rename()` cannot cross a filesystem.** The first version compiled the object next to the
  *output executable* and renamed it into `$TMPDIR`. On any host where those are different
  filesystems — `/tmp` as tmpfs on Linux, a build directory on a second volume — every install
  fails with `EXDEV`, **the build still succeeds, and the cache silently never populates.** It
  cannot fire on this Mac, which has one volume, so nothing local would ever have shown it. The
  temporary is a sibling of the entry now.
* **One environment variable, two meanings.** `build_driver.c` appended `prismio-objcache` to
  `PRISMIO_OBJ_CACHE_DIR`; the bootstrap scripts used it directly. Both reported hits the whole
  time, into two different directories. Found by an assertion added for the bug above —
  "the entry appears" rather than "a later build hits" — which looked in the directory the
  variable named and found it empty.
* **A header changes what a `.c` compiles to without changing a byte of it.** Written up at §4.1.
* **The bootstrap cache recomputed its key after the compile**, once the seven compiles went
  parallel — so a source edited *during* a build would have keyed the object compiled from the old
  text under the new text's name. A poisoned entry every later build would hit, in the one path
  whose contract is that an edit reaches the next generation. The key is carried from before the
  compile now.

The first two are the same shape as the one this project produces most: a mechanism that fails
into *looking fine*. The lesson that generalises is the assertion, not the fix — **"a later build
was faster" is not evidence that anything was stored.**

### 6. The per-module split is priced, and two of the three numbers are surprises

Item 2 of this section's first draft said nothing else was worth a session until someone priced
splitting the emitted IR per source file. Priced, with `llvm-split` standing in for a compilation
unit that does not exist yet. Full tables in RESULTS-compile-time §5.

* **LLVM's `-O2` pipeline is superlinear in module size.** Splitting the 505 KB project's 3.34 MB
  module four ways cuts the *total* work from 2.45 s to **1.48 s** — before any reuse and before
  any parallelism. A per-module split is a **cold**-build win on a large program, which is the same
  shape as §1's frontend result one layer down.
* **A rebuild touching one part costs 0.191 s of LLVM against 2.48 s** at *k* = 8, 0.109 s at
  *k* = 16. With the frontend floor (whole-program, so it does not shrink) a 505 KB rebuild would
  be **≈0.5 s against 3.31 s**.
* **There is a crossover and small programs are the wrong side of it.** `g1_particles` split eight
  ways costs 5× the total work — 27 KB of IR against a fixed ~30–40 ms per invocation. A per-file
  unit needs a floor of roughly 100 KB of IR.
* **The runtime cost is not measurable on this corpus**: `xlang/g2` 0.975×–0.986× over *k* = 2, 4,
  8 and `xlang/g6` 1.014×, all inside their run-to-run bands. There is a mechanism rather than luck
  — the hot code in these programs is `list_get`, `list_push` and the allocator, which live in
  `lang_runtime.c` and have always been a separate object. A program whose hot loop is its own code
  would have to be re-measured.

### 7. The gate

| check | result |
|---|---|
| suite | **120/120** (117 + `run_object_cache_test`, `run_bootstrap_cache_key_test`, `run_bootstrap_command_test`), 0 failed — and green again with `PRISMIO_OBJ_CACHE=0`, which is how the 226 s ↔ 170 s comparison was taken |
| warm fixpoint | `W2 == W3`, byte-identical IR on all 89 |
| cold fixpoint | `Uc1 == Uc2`, cold-started from the **committed** seed, before it was refreshed |
| cold == warm | byte-identical on all **89** |
| seed | refreshed from `W3`; its gen0 already produces the fixpoint IR on all 89 |
| profile race | `aif --layout` racing `build` on `test_55`: **2 of 30** rounds diverged before, **0 of 90** after |
| embedded runtime | a compiler copied to a bare directory with no `runtime/` still unpacks it and builds a running program |
| `prismio bootstrap` | builds a compiler whose IR is byte-identical to the script-built one on all 89 programs |
| oracle | agrees on **15** sources |
| IR delta vs `L5` | **89 of 89 slot-renumbered, 0 really differ** (`tools/ir_slot_diff.py`, §2) |
| IR delta since `R7` | **0 of 89 except `src/main.ll`**, which moves because the compiler's own source changed (§5.15) |
| parallel bootstrap | a deliberately broken `diagnostics.c` still fails the build, names the file, and produces no binary |
| `--verify` | `released` and `violation(s)` identical on **6 of 6** corpus programs with a ledger, 0 violations everywhere (`g6_engine` has no `main`) |
| incremental manifest | `tools/incremental_manifest.py`: 4 edits, cold == incremental on every one, all three self-checks pass |
| cached vs uncached compiler | byte-identical IR on every program the pair could build |
| embedded runtime | regenerated (`generate_embedded_sources.py`) |

**Last-good generation: `build/W3`** (warm), `build/Uc2` its cold twin from the committed seed and
`build/Wc1` from the refreshed one. `build/L5` is the
pre-session generation and is the one to diff against — with `ir_slot_diff.py`.

### 8. Next, ranked

1. **Build the per-module split.** It is now the only large win left and it is priced (§6): 6.5× on
   a 505 KB rebuild, a 40% *cold* saving on top, no measurable runtime cost, and it is the
   compilation unit SPEC §7.5, REQUIREMENTS 10 and REQUIREMENTS 21 all need. Two obstacles are
   known and small — string-literal names and slot serials are numbered per module, so per-file IR
   is not stable under an edit elsewhere (§2 is that failure in miniature) — and one is a design
   choice: the crossover says do not split below ~100 KB of IR.
2. **Compile the parts in parallel** once they exist. Everything in §6 is sequential; the cold
   number falls again by roughly the core count.
3. **Verify `tools/bootstrap.ps1`'s cache on Windows.** Written and read, never run (§4). The
   parallel compile in §5.1 is `bootstrap.sh` only — the `.ps1` half is still sequential, and
   bringing it into step is part of the same task.
4. **Do not build INFERENCE §9's summary cache** without re-taking the 18 ms first (§3).
5. §8's search loop, `list_get`'s call per element, the profile race, handles — all unchanged from
   the previous session's list.

---

## Session of 2026-08-17 (second) — §8's forced candidate lands, and the IR differential turns out to have a concurrency hole

**Scope: LAYOUT §8's missing mechanism, which the hot/cold session named as the only thing standing
between §8 and implementability.** Nothing here touches the arena, the pin gate, or the split
transform itself.

**Read this before planning from the brief that started this session.** That brief listed five items
and **three of them were already built** — item 1 (hot/cold) uncommitted in the working tree, item 2
(the cost model) committed on 2026-08-16, item 4 (`bench.py`'s allocation window) committed on
2026-08-16. Its `State:` paragraph said suite 98/98, 82 programs, oracle 13; the tree read
**116/116, 89 programs, oracle 15** before this session touched it. The two corrections the brief
*did* carry were both right — handles have not landed (`ptr_to_node` is still `return ptr`, no handle
table) and HEAD does build. The lesson is the one the brief already states in one direction: **verify
the state paragraph, in both directions.** A brief that understates what landed costs a session's
planning just as surely as one that overstates it.

### 1. What landed

`--force-layout=<Type>:<hot>` emits a named layout candidate instead of §7.2's argmin, on `build` as
well as `aif`, plus `aif_layout_cand_at_rank(k)` for §8's "top-`k` ranked by modelled cost". Full
design and the measured table are in
[RESULTS-layout §4.1](aif/evidence/RESULTS-layout.md). Four things worth not re-deriving:

* **A candidate is named by hot-field count, not by rank.** Ranks stop meaning the same layout when a
  cost constant is retuned, and §8's output is a durable manifest record. `hot_count` is what
  `--layout` prints, so the cut a reader picks off the table is the cut they can force.
* **The forced table lives outside `Nominal`.** `aif_reset` tears every `Nominal` down and a declared
  `workload` runs the whole engine twice in one process — so a force stored on the type would apply to
  the instrumented pass and silently not to the real one, which is the pass that ships.
* **The five vetoes divide in two, and the division is now load-bearing.** Vetoes 1–3 say the cold
  block cannot be reached (wild load, double free); vetoes 4–5 say the *model had no basis to choose*.
  A force clears 4 and 5 and never 1–3, because gathering the missing evidence is what §8 is. Veto 5
  needed its own channel, `aif_layout_no_split_unmodelled` — it arrives from the same discovery as
  veto 1 in `aifLayoutVetoInline` and means something completely different.
* **The release path is correct for cuts the model never chose**, verified by running: `test_62`'s
  `Body` forced to 4, 7 and 12 prints the exact total at every cut, with 0 violations, and the forced
  split releases exactly 4 096 more objects than the forced unsplit — one cold block per body.

### 2. The bug in it, which is the interesting part

The first version had `aif_layout_split_select` `continue` when a forced cut matched no candidate.
That leaves `hot_count` at 0 — so **a mistyped force did not fall back to the argmin, it turned the
split off.** The warning fired, so it was not silent; but a search script would have measured the
unsplit record, been told its force missed, and still had a plausible number filed against a cut
nothing emitted. "Did not apply" has to mean *nothing changed*.

The fix is not simply "fall through to the argmin", because a type that became admissible only
*because* it was forced (vetoes 4–5 relaxed) would then get a split the vetoes had excluded — the
force silently *enabling* what it never asked for. Re-asking `split_admissible` without the force is
what separates the two cases. `run_forced_layout_test` asserts this direction specifically, and it is
verified discriminating: reverting the fallback fires assertion 3 while the other two still pass.

### 3. `tools/ir_snapshot.py` reports a false difference under concurrency

Found while verifying, not by looking. A cold-vs-warm comparison reported exactly one differing
program — `test_55_workload_profile`, `%Cell.0`'s fields permuted across 26 GEPs — and the same
comparison run **sequentially** is byte-identical on all 89.

`runWorkloadProfile`'s three temp paths are the only ones in `runtime/build_driver.c` that are **not**
pid-qualified, so two concurrent compiles of the same source share one `profile.txt`. A build that
reads another process's profile picks a different field order, and unlike a profile that fails to load
it neither falls back nor warns. Reproduced: racing `aif --layout` against `build` on `test_55`, 8
rounds, 1 diverged. Six concurrent builds with *identical* flags do not — the racing writers have to
disagree about the content for the corruption to show.

**Deliberately not fixed**, because the pid omission is documented rather than accidental: LAYOUT §2.2
wants the profile path predictable so it can be checked in beside the manifest. Trading against that
is a design decision. RESULTS-layout §7 has the shape of a fix that keeps both properties. **Until
then, run `ir_snapshot.py` alone** — and confirm any one-file `test_55` difference by re-running
sequentially rather than assuming it is this bug, because a real layout regression would surface in
the same file.

### 4. The gate

| check | result |
|---|---|
| suite | **117/117** (116 + `run_forced_layout_test`), 0 failed |
| IR delta vs baseline | **0 of 89 programs move.** The change is inert with no flag, which is what makes it safe |
| warm fixpoint | `L3 == L4`, byte-identical IR on all 89 |
| cold fixpoint | `Lc1 == Lc2`, cold-started from the **committed** seed |
| cold == warm | byte-identical on all **89**, taken sequentially (§3) |
| seed parses `src/` | yes — the committed seed cold-started this tree before the refresh |
| refreshed seed | regenerated from `L4`; its cold start reaches the warm fixpoint in one generation |
| oracle | agrees on **15** sources |
| `--verify` | `released`/`violation(s)` identical to baseline on **6 of 6** corpus programs with a ledger, 0 violations everywhere (`g6_engine` has no `main`, so no ledger — reported rather than counted as a pass) |
| embedded runtime | regenerated with `generate_embedded_sources.py`; verified not to change compiler output (`L5 == L4` on all 89) |

**Last-good generation: `build/L5`** (warm). `build/Lc2` is its cold twin from the committed seed and
`build/Ls1` from the refreshed one. The binary-vs-binary comparison is *not* the fixpoint check — `L3`
and `L4` differ by 49 bytes, which is the linker's `LC_UUID`. Compare IR.

### 5. Next, ranked

1. **§8's search loop.** Compile the top-`k`, run the declared workload on each, keep the measured
   winner, record it with `origin = measured` and the machine identity §8 states as SHALL. Both
   mechanisms it needs now exist. Note that **§8's "at `max` only" is not expressible today**:
   `--debug` is the only non-`release` level `build` offers, and `max` was deliberately never added
   because it would have been byte-identical to `release`. §8 is the first thing that gives it content.
2. **Re-take the layout number — but on `g5`, not `g1`.** The corpus re-measurement ran here
   (`--runs 20`, [RESULTS-xlang §0.1](aif/evidence/RESULTS-xlang.md)) and its per-program spreads
   settle a question two sessions have argued about: **g1's own run-to-run band is 15.9%, wider than
   the 13% effect being hunted on it.** So "re-take g1 on a quiet host" is necessary but may not be
   sufficient, and the 0.958×–1.061× disagreement is fully explained. **g5 has a 3.6% band and three
   split types** (`Mesh 2/6`, `Texture 4/7`, `Entity 3/6`) — it is the program on this corpus with the
   headroom to resolve a layout effect. g4 is 29.1% and is hopeless for this purpose.
3. **`list_get`'s call per element** — the one structural difference left between `layout_repr.c` and
   g1's port, and the candidate explanation for the 0.87× not reproducing.
4. **The profile race** (§3), whenever the differential's trustworthiness is worth a session.
5. **Handles.** Still 0.35× on g1's shape and still the largest number in this document.

## Session of 2026-08-17 (hot/cold) — the split lands with its release path, and the measurement refutes two of the cuts

> **Scope note for whoever merges this.** This section covers the **hot/cold split** (NEXT-SESSION
> task 1) only. It ran in parallel with the `pin(<region-name>)` task in a separate tree; nothing
> here touches the arena/pin gate.
>
> **Files both sessions plausibly touch**, with what the hot/cold side did to each:
> `runtime/aif_support.c` — added `aif_layout_no_split` / `aif_layout_split_select` /
> `aif_layout_hot_count` / `split_slot` / `has_sequential_traversal` next to the existing cost model,
> three fields on `Nominal`, one `bits_free` in `aif_reset`, one early-return clause at the top of
> `type_releases_of`, and a comment on `aif_layout_field_bytes`. **No arena predicate, no gate clause,
> nothing in `site_arena_scope`, `arena_would_serve`, `bracket_place` or `region_confined`.**
> `src/aif/report.psm` — two calls inserted between `aifComputeSizes` and `aif_solve`, the manifest's
> `layout` column widened 8 → 12 and given a `+h/n` suffix, and `aifEmitLayout` given an `emitted`
> column. `src/aif/model.psm` — three `extern fn` declarations appended, one stale comment removed.
> `src/ir/module.psm` — one `ir_struct_type_split` call in `generateStructDecl`, one `ir_free_cold`
> call in `generateReleaseFn`. `src/ir/bridge.psm` — two `extern fn` declarations.
> `src/aif/layout.psm` — `aifFieldIsInlineStruct` + `aifLayoutVetoInline` appended at the end.
> `runtime/lang_runtime.c` — **the T3 section only**: `rc_cold_slot`, `rc_attach_cold`, two lines in
> `rc_alloc` and three in `rc_release`. Nothing in the arena, the list or the collector.
> `runtime/llvm-api-backend.c` — the struct table, the five allocator hooks, `ir_struct_field_ptr`,
> two new entry points and two `backend_fail` guards. `tests/test_runner.py` — rewrote
> `run_layout_cost_model_test`'s emission assertions, appended `run_split_release_test` and one
> registration. `runtime/embedded_sources.h` — **regenerated**, never merged.
> `runtime/prismio_llvm.h` — one prototype (`LLVMOffsetOfElement`).
>
> **Test numbering:** this session's fixture is `tests/test_62_split_release.psm`. Nothing was
> renumbered. Suite goes 111 → **113**: the fixture itself, plus `run_split_release_test`.

**Landed, release half included.** `prismio` emits LAYOUT §6's hot/cold split as a **linked** split
(§5.2.1): the hot record ends in a pointer to a separately allocated cold block. Suite **113/113**,
warm fixpoint, cold fixpoint from the committed seed, **cold == warm byte-identical on all 88**
compilable programs, oracle agrees on **15** sources, `--verify` reads **0 violations on every corpus
program** with `released` up by exactly the number of split objects and `leaked` unchanged.

### 1. The transform is four places, and the brief's four pieces all held

Nothing in the 2026-08-16 (layout) session's §4 had to be re-derived. For the record, each as built:

* **`ir_struct_field_ptr` is the choke point.** Codegen emits fields in the order `aif_layout_field`
  hands it and indexes them from 0; the split makes that order hot-fields-first, so an index at or
  above `hot_count` is a cold field and is reached by loading the link and GEPing into `%T.cold`.
  The frontend never learns a split happened.
* **The release half is one clause.** `type_releases_of` returns 1 for any type with `hot_count > 0`,
  ahead of its own cache. Every drop, every container element and every owned field of a split type
  then routes through the generated `__aif_release_T`, and the type-blind `ir_free_object` never sees
  a split object. One new backend entry point, `ir_free_cold(type, value)`, frees the cold block
  immediately before the base — a no-op for an unsplit type, which is what lets `generateReleaseFn`
  call it unconditionally and therefore never get it wrong for a particular type.
* **T3's spare word worked exactly as described.** `rc_release` frees one block and cannot name the
  type, and it is not on the generated release's path. `rc_alloc` now zeroes `((size_t*)p)[-2]` as
  well as `[-1]`, `rc_attach_cold(p, cold_size, link_offset)` allocates the cold block and stores the
  offset there, and `rc_release` frees the cold pointer at that offset before the base. Offset 0 is
  the "not split" sentinel and it is sound rather than convenient: field 0 is pinned hot and placed
  first, so no hot record can carry its link at byte 0.
* **Field 0 stayed hot and nothing read AIF.** The link word is *appended*, not prepended, so byte 0
  of the object is still field 0. `test_41` passes unchanged, including on a compiler whose own
  `ASTNode` was split.

### 2. Five vetoes, and three of them cost a build or a measurement to find

`aif_layout_split_select` takes the model's argmin unless one of these fires. Two were designed;
three were found by the tree.

1. **Inline-embedded types** (designed). An inline struct field is storage inside its owner — no
   allocator hook runs for it, so its link word is whatever the owner's allocation left there.
2. **Types in a non-trivial SCC** (designed). `cyc_free_object` calls the generated release on the
   *payload* while the base is `payload - CYC_HDR`; a split would put a second block behind that
   asymmetry. T4b is a separate question, not a harder one.
3. **The veto that did not fire, and the assertion that caught it.** The first version of
   `aifLayoutVetoInline` asked `ir_is_struct_type_name`, exactly as `fieldTypeFor` does — and the
   struct registry is filled by *codegen*, so during the analysis it answers 0 for every type in the
   program and the veto fired for nothing. `g3_scene_graph.psm` stopped building, with `internal
   backend error: byte-copy of a split struct (Transform)` from the `ir_copy_struct` guard written
   an hour earlier "because the failure it prevents is silent". The silent version is two `Node`s
   sharing one `Transform`'s cold block and a double free at the second teardown. **Write the
   assertion even when the veto is supposed to make it unreachable.** The registry half is now asked
   of the AST (`findStructDeclNamed`), which is what the registry is built from.
4. **Types with no sequential traversal** (measured, §3).
5. **Types with an inline struct field**, as owners rather than as fields (measured, §3).

### 3. The measurement refuted the model on two programs, and this time codegen was listening

Interleaved A/B against `build/mg3`, 20 pairs, on a contended host. Full table in
[RESULTS-layout.md §2.1](aif/evidence/RESULTS-layout.md).

* **`g3_scene_graph`'s `Node`: modelled 12, measured 1.110×.** `Node` holds two **inline**
  `Transform`s of 48 bytes each; `aifDeclare` sizes every field with `aifTypeBytes`, which answers 8
  for a struct-typed field because the registry is empty during the analysis. The model believed
  `Node` was 40 bytes. It is 112.
* **`g4_ecs_world`'s `World`: modelled 24, measured 1.042×.** `World` is a singleton. The cost model
  prices every type as if there were `AIF_N_ASSUMED = 2^20` of them, and `mu_for` reads a **cache
  tier** off `N_ASSUMED · size(hot)` — so shaving a singleton from 48 bytes to 24 crosses a boundary
  and divides its modelled cost by six. Written up as **LAYOUT §10.4.1**, which is new.

Both are now vetoes, and both are statements that a model *input is absent* rather than tuning knobs.
g3 returned to 0.997× and g4 to 1.016×.

### 4. And the prize did not reproduce — but not because the benchmark was unrepresentative

`layout_repr.c` variant B still measures **0.88×** for exactly the cut the compiler emits on g1
(`Particle 8/12`), and it measures it **at every size**: N = 2 000 × 6 000 frames 0.88×, N = 20 000 ×
600 0.87×, N = 200 000 × 200 0.89×. So it is not a working-set effect, and g1's port is not a
different shape from the benchmark.

The corpus port does not reproduce it. Four interleaved runs of the same pair span **0.958× to
1.061×** on the median and 0.967× to 0.976× on the minimum — the two statistics disagree in *sign*.
A second agent was building compilers on this host throughout, so the honest reading is **"this host
cannot resolve a 10% effect on g1's port"**, not a number. Re-take it on a quiet host; the reproducing
command is in RESULTS-layout §2.1.

The one structural difference left between the two is that `layout_repr.c` reaches an element with
`ps[i]` and the Prismio port reaches it with `list_get(ps, i)`, an out-of-line call per element —
the same overhead RESULTS-layout §2's F/C row already charges to generic indexing. **That is the next
measurement.**

### 5. The self-host was the budgeted risk, and it did not bite

Before vetoes 4 and 5, six of the compiler's sixteen types split — `ASTNode` 3/15, `Token` 2/7,
`TypeInfo` 3/5, `UmsProjectModel` 2/6, `UmsAstStatement` 3/9, `UmsLexer` 4/8. **That compiler reached
a warm fixpoint, a cold fixpoint from the committed seed, cold == warm byte-identical on all 88
programs, and 113/113 on the suite** — a compiler whose own AST is two blocks per node, building
itself to a fixed point, with every `node_to_ptr` pun and the punned-slot invariant riding on it.

Veto 4 then removed all six: nothing in `src/` is walked in container order. That is the veto working
rather than a capability lost, and the fixpoint above is the evidence that the transform is sound on
the hardest program in the tree. If §8's forced-layout override gets built, `src/main.psm` under a
forced `ASTNode` split is the measurement that says whether the model's 0.26× claim was ever real.

### 6. The IR delta, characterised

12 of 88 programs move, plus the new fixture. Every `tests/*.psm` fixture except `test_61` is
byte-identical; the movers are exactly the programs with a type that survives all five vetoes, plus
`src/main.psm` — whose IR *is* the compiler, and the compiler's source changed. Per split type:

* `%T = type { ... }` becomes the hot fields plus a trailing `ptr`, and a new `%T.cold` appears.
* One `define void @__aif_release_T(ptr)` per split type — null-guarded, `getelementptr` the link,
  `load ptr`, `call free` on it, then `call free` on the base.
* Every allocation site gains a second allocator call and a GEP+store of the link, through the *same*
  allocator: `malloc`/`aif_verify_alloc` for T2, `arena_alloc` for T1 (so the region reclaims both in
  bulk), two `alloca`s for T0, `rc_attach_cold` for T3.
* Every cold field access gains `getelementptr` link + `load ptr` before the GEP into `%T.cold`.
* Containers of split elements go from `list_set_elem_owner(l, OBJECT)` to
  `list_set_elem_owner(l, TYPED)` + `list_set_elem_releaser(l, @__aif_release_T)`.
* Downstream label numbering shifts, because the generated release consumes label ids.

### 7. Two things that cost time and should not cost it twice

* **`ir_is_struct_type_name` answers 0 during the analysis.** It is filled by codegen. Anything in
  `src/aif/` that asks it is asking about a table that does not exist yet — which is why AIF sizes an
  inline struct field as 8 bytes, why `Node` was modelled at 40, and why the first inline-embedding
  veto fired for nothing. Ask the AST (`findStructDeclNamed`) instead, or fix the ordering, but do
  not assume the two agree.
* **A generated header merges cleanly and is still wrong.** `runtime/embedded_sources.h` carries the
  runtime the compiler unpacks when the repo's copy is not there; four runtime files changed here, so
  it was regenerated with `python3 runtime/generate_embedded_sources.py`. The suite passes without
  that step, because a suite build finds the repo's sources — so nothing local catches a stale
  embedded runtime, and the first symptom is an undefined `rc_attach_cold` at someone else's link.

### Next, ranked

1. **Re-take g1's number on a quiet host** (§4). The headline is currently "unresolved", which is not
   the same as "no effect", and one uncontended run settles it.
2. **LAYOUT §8's empirical validation.** No longer blocked on anything: the split is emitted, so §8
   needs only a way to force a candidate other than the argmin. §3 is the argument for it — the model
   picked two layouts the measurement rejected, and both vetoes were written from regressions rather
   than from a search.
3. **`list_get`'s call per element** (§4). If it is what eats the 12%, it is worth more than any
   further layout dimension.
4. **Handles.** Still 0.35× on g1's shape and still the largest number in this document.
## Session of 2026-08-17 (pin) — `pin(<region-name>)` lands; regime (a)'s silent regression becomes a build failure

**Scope: task 2 of `NEXT-SESSION.md`'s consolidated prompt, and only that.** Task 1 (the hot/cold
split) was built in parallel in a separate tree by another session; nothing here touches
`runtime/llvm-api-backend.c`, `runtime/lang_runtime.c`, `aif_layout_select`, or `tests/test_61`.

SPEC 5.2.1.1 says of its own regime (a): *"(a) is fragile as a language guarantee — adding a second
call to a bracketed callee silently removes the placement — which is why an implementation using it
SHALL record in the manifest which call sites it bracketed, so the loss appears as a diff rather
than as a slowdown."* The manifest has recorded them since 2026-08-16. **A diff is only read by
somebody who looks.** `pin(<region-name>)` is the same fact asserted by the programmer, so the build
stops instead.

Suite **114/114** (was 111: `test_63_placement_pin.psm`, `neg_26_placement_pin_refuted.psm`, and the
runner's `placement_pin` check). Warm fixpoint `p2 == p3`; cold fixpoint `pc1 == pc2` from the
**committed, unrefreshed** seed; **cold == warm byte-identical on all 88 programs**; seed refreshed
afterwards and a cold start from it reaches the warm fixpoint in one generation; oracle agrees on
**15** sources; census **unchanged** at 40 of 234 served, 2 bracketed, PLACEABLE 0.

### 1. The form, and why it needed no grammar change

`let [mut] pin(<name>) x = <initialiser>`. The parser has accepted `pin(<identifier>)` since the
tier pin landed — `parseAifAnnotations` reads any IDENTIFIER — so **not one byte of the frontend
moved and the two-step syntax rule never engaged.** The 2026-08-14 handoff's §9 said exactly this
("the parser already accepts `pin(X)` with a bare identifier and only `aifTierFromName` rejects it")
and deferred the feature because its headline example refuted. Placement landing is what changed
that: in the example it gave, the `DrawCmd` is now `T2 region:frame_arena` rather than a stack slot.

One identifier, two meanings, told apart in exactly one place (`aifTierFromName` in
`src/aif/walk.psm`): a tier name is a tier pin, anything else is a region name.

### 2. What it asserts, stated so a reader can tell what it catches

**"The allocation this binding denotes is served by the arena of the `region` named `<name>`."**

The verdict is `aif_region_name_at_site(site)` string-compared with the pinned name, and *nothing
else*. That function is `site_arena_scope`, which is the one arena gate codegen, the manifest's
placement column, the zero-serving warning, the cost model and `--why` all already read. **There is
no second copy of the placement predicate and no second copy of the bracket record** — this file
has already paid for having four copies of the first, and the copy that had drifted was the one
placing arenas that served nothing.

| | |
|---|---|
| catches | a second call site appearing on a bracketed callee (regime (a) drops the bracket) |
| catches | the `region` being deleted, renamed, or moved so it no longer encloses the call |
| catches | the binding moving above the region (obligation 3), or a nested region taking the value |
| catches | a name that no `region` in the program carries — including a mistyped tier |
| does **not** catch | a site nobody pinned. `pin` is opt-in, SPEC 5.4.3 |
| does **not** catch | *how much* the arena serves. That is `region <name> pin(N)`, and its estimate is biased — see §6 |

**It is an assertion, never a directive** (SPEC 5.0.1). Nothing in `aif_check_placement_pins` writes
to `scopes[].arena` or to `site_bracket`, so deleting every one of these annotations emits the same
instructions. That is what makes "the IR must not move" the correct test for it, and it does not
move: **87 of 87 pre-existing programs byte-identical**, `src/main.psm` included.

### 3. The ordering is the whole difference from the tier pin, and it is not interchangeable

`aif_check_pins` runs **before** `aif_place_arenas`, because the cost model ranks scopes by tier and
a pin that moved a tier afterwards would place an arena for a site whose tier was about to change.
`aif_check_placement_pins` runs **after** it, because what it asserts is that pass's *output*.
Asking earlier reads an arena table that is still empty and refutes every pin in the program.

There is also no third branch here where `aif_check_pins` has one. SPEC 5.4.4's direction limit
exists because tiers are ordered and a *more expensive* one needs no proof; placement has no order —
an arena either serves a site or does not — so "served by some other region" is a refutation rather
than a weaker honour.

### 4. Sema stopped adjudicating the name, and that is a deletion worth reading

`semaCheckAnnotations` used to warn `unknown tier 'X'` for any name outside T0..T4b, after which
`aifApplyAnnotations` silently dropped the annotation. **That is this project's signature defect
wearing an annotation's clothes**: the programmer asserted something, the compiler said something
back, and no build could ever fail. `pin(T5)` is now an error naming the real problem.

Sema also *cannot* answer the question any more, and this is the load-bearing reason rather than a
convenience: the region that serves a bracketed callee's allocation is in the **caller** — routinely
another function, and with imports merged, another file. AIF holds the whole scope table.
`semaAnnotationPinTier` and `semaIsTierName` are deleted with the check; `src/aif/walk.psm` is now
the only reader of the `pin:` encoding, where there were two.

### 5. Broken on purpose, and the exact failure

The regression introduced deliberately: **a second call to the bracketed callee, inside the same
region**, so obligation 3 still holds for both sites and nothing but the call count differs.

```
error: pin(call_arena) cannot hold: this value is not served by that arena
  --> tests/neg_26_placement_pin_refuted.psm:34:29
   |
34 |     let pin(call_arena) c = Cmd { id: i, weight: i * 2 }
   |                             ^
  note: the call that reached it was bracketed into call_arena (SPEC 5.2.1.1 regime (a)) and no longer is:
  note: make now has 2 call sites, and a bracketed callee may have exactly one
error: aborting due to 1 previous error
```

The error is at the `let`, one function away from the edit that caused it, and the note is what
closes that distance — it names the callee, its call-site count and the obligation, from
`aif_fn_bracket_blockers`, which already answers that question for `--why`.

**Three fixtures, because none of them discriminates alone.**

| | asserts | passes on a compiler that |
|---|---|---|
| `test_63_placement_pin.psm` | both pins honoured, and `arena_objects()` really counts 50 + 50 | honours every placement pin |
| `neg_26_placement_pin_refuted.psm` | the second call site is rejected, with the regime-(a) note | refutes every placement pin |
| runner `placement_pin` | mutates *test_63* — a program known to compile — and requires the mutant rejected | neither |

The third is the one that cannot be satisfied by a degenerate implementation, and it is why the
mutation is performed on the file that compiles rather than on the one that does not. `neg_26`'s own
discrimination was checked by hand the same way: delete the second call and it compiles.

### 6. Verification, as numbers

| | |
|---|---|
| suite | **114/114**, 0 failed (was 111/111 on `build/mg3` before the change) |
| warm fixpoint | `p2 == p3` byte-identical on `src/main.psm` (1 799 134 bytes) |
| cold fixpoint | `pc1 == pc2`, from the **committed** seed — so the seed still parses `src/` |
| cold == warm | byte-identical on **88 of 88** programs |
| refreshed seed | `pseed0 == pseed1 == p3`; cold start reaches the fixpoint in one generation |
| IR delta | **none.** 87 of 87 pre-existing programs identical, `src/main.psm` included |
| `--verify` | 16 corpus programs with a ledger, `released` and `violation(s)` **identical on every one**; violations **0** everywhere; `g2_region` `released` 1 025 both sides |
| census | 40 of 234 served, 2 by a bracketed call, PLACEABLE 0, exit 0 — unchanged |
| oracle | agrees on 15 sources (run anyway: the analysis did not change, and a checklist item dismissed with a reason is still unchecked) |

`allocated`/`leaked` moved by 49 on `g2_region` and were not compared, which is what the
2026-08-16 lesson says to do with them.

### 7. A branch that cannot fire, found while checking that it could

**SPEC 5.4.2's UNPROVEN branch is unreachable from `prismio build` — for the placement pin *and*
for the tier pin that has shipped for four sessions.** Two independent reasons, and neither is new:

* The only non-converged mode `build` offers is `--debug`, whose budget is zero rounds. `aif_solve`
  returns at `if (!solve_points_to(max_rounds))` **before** the pass that applies SPEC 5 annotations,
  so no pin of either kind is ever recorded. `neg_25_pin_refuted.psm` builds clean at `--debug` on
  `build/mg3` too — this is the pre-existing behaviour, verified against the baseline compiler.
* `--budget=N` is accepted only by the `aif` subcommand, and `aifReportPins` is called only from
  `compileSource`. So the one path that can produce a truncated analysis is the one that does not
  report pins.

Recorded rather than fixed: the unreachable branch is the *lenient* one, so the effect is that pins
are stricter than SPEC 5.4.2 describes, not weaker. **I did not verify the UNPROVEN path and do not
claim it works.** It is written up as a task in `NEXT-SESSION.md`.

Worth noting how it was nearly missed: `prismio build --budget=3` prints `unknown argument` and
exits non-zero, and a first pass read that non-zero exit as "the program was rejected". An
instrument that fails to run looks exactly like an instrument that ran and found nothing — the
2026-08-16 `released\s+(\d+)` lesson, arriving through a third door.

### 8. Merge hazards for whoever integrates this

| file | what moved |
|---|---|
| `runtime/aif_support.c` | two `Site` fields, `AIF_CON_PIN_REGION` = **17** (appended past `AIF_CON_VIEW_OF`), `aif_con_pin_region`, the annotation pass's condition, and `aif_check_placement_pins` + two accessors inserted above `aif_scope_region_file` |
| `src/aif/report.psm` | one line in the `origin` column, `aif_check_placement_pins` at the end of `aifRunProfiled`, and `aifReportPlacementPin` + `aifRegionExists` after `aifReportPins` |
| `src/aif/model.psm` | four `extern fn` declarations after `aif_site_alias_axiom` |
| `src/sema/types.psm` | `semaAnnotationPinTier` and `semaIsTierName` **deleted**, and the `unknown tier` warning with them |
| `src/aif/walk.psm` | the `pin:` dispatch in `aifApplyAnnotations` |
| `tests/test_runner.py` | `run_placement_pin_test` added after `run_region_diagnostic_test`, and one registration in `main()` |
| `runtime/embedded_sources.h` | **regenerated, never merged** — run `runtime/generate_embedded_sources.py` |
| `bootstrap/prismio-seed.ll` | refreshed from `p3`; regenerate rather than merge |

`aif/spec/SPEC.md` gains §5.4.5 and nothing else. Not touched at all: `runtime/lang_runtime.c`,
`runtime/llvm-api-backend.c`, `aif_layout_select`, `tests/test_61`, any file under `src/ir/`,
`src/parse/` or `src/lexer/`.

---

## Session of 2026-08-16 (second) — call-site placement lands; `region` stops being inert on g2

The previous session measured the repair and stopped at task 4. This one built it. **`region
frame_arena` on `g2_region.psm` now serves 10 200 000 of 10 201 215 allocations, against 0**, and
the "serves no allocation" warning that has followed that file for three sessions is silent.

Suite **109/109** (was 108; `test_60_bracket_reset.psm` is the new one), fixpoint warm and cold,
**cold == warm**, seed still parses `src/`, oracle agrees on **15** sources, and IR is
byte-identical on every compilable program in `tests/`, `aif/corpus/` and `aif/evidence/` **except
the three that were supposed to move**.

### 1. There is no new codegen mechanism, and that is the shape of the result

The brief expected the Prismio call to be wrapped in `ir_arena_hint_begin/end`. It is not, and it
should not be. An arena is on a *dynamic* stack: `region` already emits `arena_push` at entry and
`arena_pop` at every exit, so while a bracketed callee runs, the caller's arena is the top of that
stack. The only thing missing was for the **analysis** to say a callee's site belongs to it — after
which `ir_alloc_region` (Level 3) takes a struct literal there and `ir_arena_hint_begin/end`
(Level 4) takes a producing runtime call there, both keyed on `aif_arena_at_node`, which is this
file's one gate.

Bracketing the Prismio call with the hint would have been **worse than unnecessary**: the hint is a
dynamic depth, so it would have routed *every* runtime allocation in the extent to the arena,
including the ones the per-site gate declines. Not one line of `src/ir/` changed.

### 2. Obligation 3, and why `E` cannot answer it

`AIF_CON_LIVE_IN` sets `E = Caller` for every site whose `fn` is not the binding function, by
construction — a scope id in one function does not order against one in another. So every site in
a bracketed extent has the *same* `E` whether or not it outlives the region, and a test on `E`
passes both. `tests/test_58`'s `make` and `make_out` are that pair: byte-identical bodies,
identical tiers, and the placement column is the only place the difference is visible.

The fact wanted is the **caller-side binding**, and the points-to graph already carries it. The
implementation asks two things of each extent site, both in `bracket_site_bounded`:

* **every key that may hold it** is a binding/parameter/return in a function confined to the
  region, or a binding in the bracketing caller declared at a scope at or below `r`. A `RET` key of
  the bracketing caller is `return f(...)` straight past the region — the case `E` cannot see at
  all.
* **every owner site** that stores it is in the extent. A `FIELD` key is object-insensitive
  (INFERENCE 3.1), so `Wrapper.list` says nothing about *which* Wrapper, and *which* is the whole
  question.

**One thing here was not in the brief and is load-bearing: `region_confined`.** The brief's
formulation — "every caller binding is in the bracketing caller" — rejects `g2_region` itself.
`submit(cmds)` takes the list `cull` returned, and the walk binds a parameter to a local of the
same name, so `cmds` lands in a VAR key belonging to a function in no extent at all. Accepting that
unconditionally would accept a function that also runs where the region does not. So a function
joins the confined set when **every** call site of it is inside the region — the same closure
discipline regime (a) uses one level down.

### 3. The list needed the runtime, and a flag would have been wrong

Lifting `is_list` for a bracketed extent is only 1.8% of g2's allocations (the struct literals are
98.2%), and it is the half that could corrupt the heap. `list_push` doubles the element block and
frees the old one long after the site that made it — which is exactly what the `is_list` clause
says. So `XefyList` now records which arena it came from.

**As a depth, not a flag**, and that distinction is the reason to read this paragraph:

```
region outer { let l = callee();  region inner { list_push(l, x) } }
```

with a flag the grown block comes from `inner` and dies at `inner`'s exit with `l` still pointing
at it. `arena_alloc_at(slot, size)` allocates from a named arena instead of the innermost one.
This is SPEC 5.2.1.1 resolution **(c) as a supplement to (a)** — which is what "(c) is never
sufficient alone" means: the bare `DrawCmd` still relies on (a).

### 4. Four mechanisms, each broken on purpose to confirm the check fails

| broken | fixture | reads |
|---|---|---|
| obligation 3 (`bracket_site_bounded` → always true) | `test_58` `outlives_serves_nothing` | **50**, expected 0; runner also flags the missing warning |
| regime (a) (`f_calls != 1` clause deleted) | `test_58` `shared_body_serves_nothing` | **51**, expected 0 |
| placement teardown, flag left set + state freed | `test_60` | **0**, expected 50 — and `test_58` still 50, which is the "wrong only on profiled sources" signature |
| placement teardown, flag *and* state left stale | `test_60` | **passes** — see below |

The fourth is a check that **cannot** fail, and `test_60`'s header says so rather than implying
otherwise. The second engine run analyses the same program, so the site ids are identical and last
run's answer happens to be this run's. The stale state is still a use-after-free waiting for a
program where the two runs disagree; what makes it safe today is that the teardown is complete, not
that it is tested.

### 5. The `--verify` comparison was vacuous the first time, and the fix changes the reading

The ledger line is `N allocated, N released, N leaked, N violation(s)` — **the count comes before
the word.** A comparison script written as `released\s+(\d+)` matched nothing on all 45 programs
and reported every one of them "identical". That is the previous session's `allocated`/`leaked`
lesson arriving through a different door: the column was not noisy, it was never read.

With the regex fixed, the correct reading is **not** "identical", and the difference is the result
rather than a regression:

| `g2_region.psm`, `--verify` | before | after |
|---|---:|---:|
| allocated | 10 301 045 | 81 065 |
| released | 10 201 025 | **1 025** |
| violation(s) | 0 | **0** |

`released` fell by exactly **10 200 000** — the number the arena serves. `ir_alloc_region` and
`arena_alloc` deliberately bypass verify accounting (an arena releases in bulk and the ledger has
nothing to pair a release with), so an arena-served allocation is counted neither as allocated nor
as released. **`violation(s)` is the column that had to stay 0, and it is 0 on every program.** The
`aif-verify: FAILED` verdict on the g2 family is leak-driven and pre-existing — the t3-built
baseline prints it too.

### 6. Timing — re-measured after the merge, and the flat line is still the stronger half

The number taken during this session was contended: a second agent was benchmarking on the host,
which is the exact condition RESULTS §6 says invalidates a timing number. It read 174.3 → 45.8 ms
(0.263×) over 7 and 5 interleaved pairs, and was **directionally right and quantitatively wrong**.
Re-measured on a quiet host against the merged compiler, 20 interleaved pairs with a warm pair
discarded — this is the number to quote:

| `g2_region.psm` whole-program, median of 20 | ms | ratio |
|---|---:|---:|
| before placement (`build/t3`) | 194.4 | 1.000 |
| after placement (`build/mg3`) | **64.6** | **0.332** |

**3.01× faster, distributions disjoint** — the slowest post run (66.2 ms) beats the fastest pre run
(188.1 ms), so the result does not turn on the choice of statistic. Checksums identical on every
run; `arena_objects` printed alongside, so a run that served nothing cannot pass as a fast one.

The other half of the brief's prediction needs no timing: g1, g3, g4, g5, g6 and g6_engine are
**byte-identical IR**, so nothing about them can have changed. That is a stronger flat line than
any benchmark.

### 7. What did not move, which is most of the point

`PLACEABLE` in the census went 2 → **0**, and that is the success condition rather than a
regression: a site that was placed is *served*, so it leaves the blocked column and the placeable
one with it. The census now prints `BRACKETED` and `br_served` beside it, cross-checks the count
against the manifest's required record on a second surface, and exits non-zero if they disagree.

Every corpus program without a `region` is byte-identical — g1, g3, g4, g5, g6 and g6_engine did
not move by one instruction, which is stronger than a flat timing line. `src/main.psm` moved
because its *source* moved: the only new symbol is the manifest's bracket-recording function, and
a normalised body-by-body diff shows the four functions that were edited and no others. No
placement decision in the compiler itself changed.

### 8. Known gap, recorded rather than papered over

`peak-bytes` and the `region name pin(N)` gate now include bracketed sites, but their weight is a
product of two *intra*-procedural loop-depth estimates — `weight_of` cannot span two functions
because `loop_depth` is counted within one. `g2_region.psm` reports 6144 bytes where the arena
really holds ~12 KB per frame. Right order, known bias, and it was **0** before, which was flatly
wrong. A fixed-budget target should read it as an estimate with a stated direction.
## Session of 2026-08-16 (layout) — the cost model lands, and it could not have ranked the cut it exists for

> **Scope note for whoever merges this.** This section covers the **layout** task (NEXT-SESSION
> prompt 2) only. It ran in parallel with the arena call-site-bracketing task (prompt 1) in a
> separate tree; nothing here touches arena placement, and the two sessions' notes are independent.
>
> **Files both sessions plausibly touch**, with what the layout side did to each:
> `runtime/aif_support.c` — added LAYOUT §5's cost model and a traversal table *after*
> `aif_layout_select`, plus one call into it from `aif_field_access` and two teardown calls in
> `aif_reset`; no arena predicate, no gate clause, and nothing in `site_arena_scope` or
> `arena_would_serve`. `src/aif/walk.psm` — bracketed the three loop forms with
> `aif_traversal_begin/end` and added a `list_get` element note in `VARIABLE_DECL`; no constraint or
> site change. `src/aif/model.psm` — appended eleven `extern fn` declarations. `src/aif/report.psm`
> — added `aifEmitLayout` and one branch in `aifAnalyzeProfiled`. `src/main.psm` — added the
> `--layout` flag and threaded one `Bool` through `aifCommand`. `tests/test_runner.py` — appended
> `run_layout_cost_model_test` and one registration. **`runtime/lang_runtime.c`,
> `runtime/aif_support.c`'s arena section, `aif/prototype/aif.py` and `tools/aif_differential.py`
> were not modified by this session at all.**
>
> **Test numbering:** this session's fixture is `tests/test_61_layout_cost_model.psm`. It was
> renumbered from 60 because the arena session independently took 60.

**Landed and verified: items 2 and 4** (LAYOUT §5's cost model; the benchmark harness's allocation
accounting). **Item 1, the hot/cold split, was deliberately not started** — §4 says why, and the
brief's own instruction is the reason: *do the release half or don't start*. **Item 3 (LAYOUT §8)
stays blocked**, now on one thing instead of two. Suite **110/110** (was 108; +1 fixture, +1 runner
check), fixpoint warm and cold, **cold == warm**, oracle agrees on **15** sources, cold start from
the committed seed works, and IR is **byte-identical on all 89** compilable programs in `tests/`,
`aif/corpus/` and `aif/evidence/` — the cost model is reported and changes no codegen, by design.

### 1. The premise reproduces, and the headline number was worth re-running

`layout_repr.c` re-run on this host: **B/A = 0.87×**, exactly as claimed. Worth noting because
RESULTS-layout's own table reads 0.92× from a different run and the prose reads 0.87× — the prose is
right and the table is one noisy run. The rest of the table reproduces within a point.

### 2. Restricted to what codegen can emit, the model picks the measured cut

This is the result the port exists to produce.

`aif/prototype/layout.py` on `g1_particles.psm` ranks **SoA** and returns 5.37×. SoA needs handles,
which do not exist, so a compiler ranking it would select a layout it cannot emit — the failure the
search already forbids itself one function up. Restricted to AoS × the split cuts, the same model on
the same program returns **`AoS+split(8/12)`**, which is exactly `layout_repr.c` variant B, the cut
measured at **0.87×**.

**And the cheap rule is wrong, which is why this is a cost model and not a comparison.** Cutting at
the first frequency boundary — available with no cost model at all — picks **2/12** on the same
program, pushing five of `integrate`'s six fields behind the cold pointer.
`tests/test_61_layout_cost_model.psm` is built to discriminate exactly that: first boundary 2/13
scoring 413, model picks 9/13 at 76.

### 3. A linked split is not an indexed split, and the prototype cannot tell them apart

The finding, and it is a specification defect rather than a porting detail. **LAYOUT §5.2.1 is new
and normative.**

`layout.py` prices a cold touch as `size(hot) + size(cold)` bytes scanned. That is right for an
*indexed* split — cold[i] at a computed offset in a parallel block. This implementation's split is
**linked**: the hot record points at a separately malloc'd cold block, which is precisely why
hot/cold needs no handles. A cold touch is therefore a **dependent miss**, not a longer scan, and the
hot record additionally pays 8 bytes for the link.

Ported faithfully, that flips the answer on the one program the port exists for — the compiler scored
**2/12 at 73 against 8/12 at 75**. Priced as a linked split: **75 against 300**, and 8/12 wins by a
margin the model can carry.

**The prototype is not safe here either — it is lucky.** Its own top two candidates on g1 score
**1188M and 1180M**, 0.7% apart, and it prefers the good one by that margin. Add the link word this
implementation actually pays and the order inverts. *A model that separates its best two candidates
by less than its calibration error is not selecting a layout*; §7.2's `argmin` inherits whatever
falls out of it. That is the general lesson and it is worth more than the cut.

Verified discriminating: with the prototype's pricing restored, `test_61` fails on both assertions
(chooses 3/13, and scores 2/13 at 88 — better than not splitting).

### 4. Why the hot/cold split was not started, which is a scope decision and not a discovery

The brief says *do the release half or don't start*, and this session did not start. That is the
whole of it; nothing is half-landed, and the split's IR is byte-identical to the baseline everywhere
because no codegen moved.

The reason is the size of the *verification*, not of the transform. The transform is contained —
`ir_struct_field_ptr` is the single choke point for field access and all five allocator hooks are
backend functions, so the redirection is ~200 lines of C. What follows it is not contained:

- `ASTNode` splits. The probe run this session says 13 of 16 types in `src/` have an admissible cut,
  `ASTNode` (15 fields, 88 bytes) among them with 13 of them. So the first generation that emits
  splits is a compiler whose own AST is split, and every `node_to_ptr`/`ptr_to_node` pun and the
  punned-slot invariant ride on it. Field 0 stays hot, so it *should* hold — but "should" here is a
  seed refresh, a cold start, and a self-host away from being known.
- **T3 is where it cracks, and the shape of the fix is now specific.** `rc_release` frees one block
  and cannot name the type. The fix is the one `cyc_set_type` already uses: tell the object at
  construction. `RC_HDR` is 16 bytes with 8 in use, so the **cold-block offset fits in the spare
  word** — no function pointer and no extra call, and `rc_release` frees the cold pointer at that
  offset before the base. `cyc_alloc` already carries a per-type release; `list_release` already has
  the element type. The type-blind frees that remain are codegen sites, where the type *is* known.
- Which makes the release half one clause: **force `aif_type_releases(T)` true for any split `T`**,
  so every drop routes through the generated `__aif_release_T` and the type-blind `ir_free_object`
  never sees a split object. That is the "generated release even when the type owns no fields" the
  brief names, arrived at from the other direction.

None of that is speculative and none of it is built. It is written down so the next session starts
from a design rather than from the row in LAYOUT §6.

### 5. The `allocs` column was measuring the report, and now measures the workload

`aif/evidence/xlang/bench.py` timed the frame loop and counted allocations for the whole process.
Once commit `901b494` moved the corpus's reporting loops onto the allocating `println` overload, g1
read **26,261** where the workload allocated **2,215** — ~4 allocations per print over 6,002 prints,
with the timing untouched.

Fixed in `allocount.c` by bracketing the window on the clock **every one of these programs already
reads per frame** — Prismio via its `extern fn`, Rust via `harness::now_ns`, Swift via `nowNs`, all
of them `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)`. No program in any of the three languages
changed. The window spans startup, setup and the loop and excludes the dump.

**Setup is deliberately inside the window.** It is where a boxed representation costs — g1 is 2,215
against Rust's 206, and almost all of Prismio's is `build_system`'s 2,000 individually malloc'd
particles. A loop-only window reads ~0 on both sides and erases the one difference the column exists
to show.

Two independent checks that the window is where it is claimed: it reproduces the pre-`901b494`
number (2,214) and it reproduces g2's separately documented **10,201,215** allocations. `clock_calls`
is emitted so the harness can assert the bracket — these programs read the clock twice per frame, so
anything outside `[2·frames, 2·frames+64]` exits loudly. Verified failing on a wrong frame count and
on a stale dylib.

**And the bias was one-sided, which is the part worth carrying.** Measured over the whole corpus, the
inflation is **Prismio-only**: g1 11.8×, g5 9.8×, g3 8.3×, g4 6.2× — while every Rust and Swift port
reads **1.0×**, because their `println` does not allocate and Prismio's allocates ~4 times per call.
A harness that exists to compare languages was overstating one of them by an order of magnitude on
four of seven programs.

Concretely: g1's real counts are **2,215 for Prismio against 2,206 for `g1_rust_boxed`** — the same
number, which is correct, because both box every particle. The old column read 26,226 against 2,209.
It survived this long because g2 and g6 read 1.0× (their 10.2 M and 15.1 M workload allocations dwarf
the dump), and those are the two programs the arena and capacity work has been aimed at. Full table
in [RESULTS-layout.md §6](aif/evidence/RESULTS-layout.md).

### 6. Two things that cost time and should not cost it twice

- **`aif_reset` again.** The traversal table is accumulated per loop id, and a declared `workload`
  runs the engine twice in one process. Left un-torn-down it does not merely double the counts — the
  second run's loops get fresh ids, so they arrive as **extra traversals** and every candidate's cost
  scales with the run count. Same defect class as the call graph in the session above, found by
  asking the question that session's notes told me to ask. `test_61`'s workload assertion covers it;
  verified reading 6 instead of 3 with the reset removed.
- **Do not run the suite while editing `runtime/*.c`.** `prismio build` compiles the runtime fresh
  into every program, so a suite run that straddles an edit compiles different fixtures against
  different runtimes. That produced a phantom `no_inference` failure on three basic fixtures —
  release and `--debug` builds of the same program straddling the swap. Nothing was wrong; the run
  was. Re-run clean it is 110/110.

### Next, ranked

1. **The hot/cold split.** Unchanged as the largest item not blocked on anything, and now with the
   cut chosen rather than guessed and the release path designed (§4).
2. **LAYOUT §8's empirical validation.** Now blocked on exactly one thing: a way to *force* a
   candidate layout, so the modelled ranking can be checked against measured runs. That is part of
   item 1, so §8 follows it and nothing else.
3. **Handles.** Still 0.35× on g1's shape and still the largest number in this document.

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

- ~~**No `-g`.**~~ Landed 2026-08-20 — see that session's entry. What it deliberately does
  not describe, and why, is `docs/DEBUGGING.md`.
- **No error-handling story.** The one users hit first: failure can only be signalled by a
  sentinel return value. Needs tagged unions → `Option`/`Result`, i.e. language design.
- **No methods, closures, or slices.** Generics landed on 2026-08-19 by monomorphisation, and
  `List<T>` is no longer a hardcoded special case — `Map<K,V>` in `std/map.psm` is written in
  Prismio. Methods, closures and slices are untouched.
- `resolve_imports` flattens every module into one AST. File identity survives on each node's
  `file` id, which is why diagnostics can still name the right file — but there is no module
  namespacing or visibility.
