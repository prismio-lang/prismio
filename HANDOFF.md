# Handoff — continuing the Prismio work

Read `COMPILER_AUDIT.md` (defects, all closed) and `V1_GAP_ANALYSIS.md` (capability inventory
against the v1 bar, with a status box at the top) before starting. Current as of **2026-08-01**.
Don't re-derive what's in them.

---

## Current state

Everything below is verified, not asserted — the commands that verify it are in the next section.

- **Self-hosts to a fixed point.** Bootstrapping from the committed seed produces a compiler whose
  IR for `src/main.psm` is byte-identical to the warm build's.
- **68/68 tests**, of which 17 are negative and each asserts *which* diagnostic it expects.
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
cd tests && PRISMIO=../build/next2.exe python test_runner.py   # must stay 68/68
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
| `src/aif.psm` | the pass: AST walk, transfer rules, tier derivation, manifest |
| `runtime/aif_support.c` | its containers: bitsets, interning, points-to keys, the solver loop |
| `tools/aif_differential.py` | holds it against `aif/prototype/aif.py`, the independent oracle |
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

**Next, in order of measured value:**

1. Level 4 — affine `String`/`List`/arrays. It is the item that makes Levels 2 and 3 both pay: the
   drop predicate already asks `site_is_move_only`, and the arena serves any T1 site, so the 184 T1
   string sites become arena-placed and freeable the day collections are affine — with no further
   codegen change. It is also the widest blast radius in the compiler (`COMPILER-AUDIT.md` §3.1).
2. Level 5 — T3 refcounting.
3. Automatic arena placement (LAYOUT §7.1). `region` pins an arena; the compiler placing one
   unprompted is the other half of SPEC §5.2 and needs a cost model.

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

Things the memory model will want to settle, all of which are currently open:

- `String`, arrays and lists are **never freed**. Only structs are move-only, so only structs
  participate in ownership at all.
- Arrays are stack allocations, which is why returning one is rejected. If arrays become heap
  values, that restriction can be lifted — `sema_statement`'s `RETURN_STATEMENT` case is where.
- There is no `defer` and no scope-based drop; `drop(x)` is explicit and move-checked.
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
