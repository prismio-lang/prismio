# Memory model and AIF: a research brief

Written 2026-11-22 for an outside research agent. Its job is to propose **innovations** in Prismio's
memory model. After that, the maintainer and a compiler session will discuss the proposals and turn
the good ones into a plan. This brief does not repeat the design record. It points into it, and it
writes down what the design record does not hold: what is built today as opposed to specified, the
numbers measured this session, the open problems grouped by root cause, the constraints a proposal
must respect, and what was already tried and rejected.

Paths are relative to the compiler checkout (`prismio/`). The documentation sites are a sibling
checkout, written here as `website/…` (`../website` from the compiler). If you cannot read the tree,
ask for the files in §10's reading list.

---

## 0 · What we want from you

**The goal.** Prismio should run faster than C++ and Rust (see `docs/STRUCTURAL_LEVERS_PLAN.md` §0 for
what counts as a lever), while the code reads like Kotlin or Swift: no lifetimes, no borrow
annotations, no required memory concepts (`docs/aif/implementation/TARGET.md`). Today the memory
model is *sound in practice* (0 violations across the suite) and *leaky by design* wherever the
analysis cannot prove a release. The innovations we want close the leak residue and the remaining
allocation cost without giving up either property.

**What a good proposal looks like.**

1. It names the problem cluster it attacks (§5) and the measurement it would move (§4).
2. It states the mechanism precisely enough that a compiler engineer can tell which file changes:
   engine (`src/aifcore/`), walk (`src/aif/walk.psm`), codegen (`src/ir/`), sema
   (`src/sema/ownership.psm`), runtime (`runtime/lang_runtime.c`), or a new layer such as a MIR.
3. It argues soundness against §7's invariants. The failure direction matters most: a proposal
   whose bug would show up as a double free needs a stronger argument than one whose bug would
   show up as a leak.
4. It says what it costs: compile time, binary size, run-time checks, language surface, and changes
   to the oracle (`tools/aif_oracle/aif.py` has to mirror any change to the engine).
5. It cites prior art (paper, language, compiler) and says how Prismio's situation differs. Prismio
   has whole-program analysis, a compiler that owns layout, and no user-visible lifetimes.
6. It checks §6 (rejected experiments). If it revisits one, it says what new evidence justifies that.

**Format.** A ranked list. Each entry gets: title, cluster, one-paragraph idea, mechanism, soundness
argument, expected effect with the number it moves, cost, prior art, risks, and the smallest
experiment that would confirm or kill it. Put bold ideas and incremental ones in separate sections.
Both are welcome.

---

## 1 · Prismio in one screen

- A self-hosted compiler written in Prismio (`src/`, about 4,000 functions in its own build), with an
  LLVM 23 backend driven through the C API (`runtime/llvm-api-backend.c`, `runtime/llvm_bridge.cpp`).
  The bootstrap comes from a committed LLVM IR seed (`bootstrap/seed.ll`).
- **There is no middle IR.** The checked AST is lowered straight to LLVM IR. AIF's results live in
  side tables keyed by AST node, and codegen queries them one question at a time
  (`aif_tier_at_node`, `aif_owns_call_result_at_node`, `aif_releases_on_overwrite_node`, and so on).
- `Int` is signed 32-bit, a measured decision (`website/apps/developers/content/performance/decisions-and-rejected-experiments.md`).
  Overflow is defined, and loops get range facts instead.
- Programs build at `-O3`. LLVM stays the optimiser. Prismio's job is to hand it facts.
- Targets: macOS and Linux (AArch64, x86-64), Windows, WebAssembly, freestanding, and Linux kernel
  modules.
- The hosted benchmark suite has 62 arms against hand-written C++ and Rust. As of the last recorded
  full run (not re-run for this brief), the median is at parity and the slow tail is blake3,
  channel_pipeline and mergesort. The methodology is
  `website/apps/developers/content/performance/`.

---

## 2 · The model as specified (read, do not re-derive)

| Topic | Where |
|---|---|
| The model in one screen, and the tier table | `docs/aif/README.md` |
| Normative spec: invariant, tier ladder T0–T4, derivation, annotations (`unique`, `region`, `workload`, `pin`), manifest, two-speed compilation, views, the budget rule | `docs/aif/spec/SPEC.md` |
| Decision procedure: the fact lattices E/A/T/C/L, transfer rules, fixed point, contexts, specialisation | `docs/aif/spec/INFERENCE.md` (§11 lists the known weaknesses) |
| Layout cost model and arena search | `docs/aif/spec/LAYOUT.md` |
| FFI boundary and contract vocabulary | `docs/aif/spec/FFI.md` |
| The T4 collector (trial deletion, cyclic-edge restriction, inferred weak refs) | `docs/aif/spec/CYCLES.md` |
| Sealed-library format (a design, not built) | `docs/aif/spec/PIR.md` |
| **Why the model is shaped this way, and which simplifications were tried and reverted** | `docs/aif/implementation/RATIONALE.md`. **Read this before proposing anything.** |
| The literature already surveyed (Perceus, Spegion, regions, PPAM data views, ThinLTO) | `docs/ARCHITECTURE-DIRECTION.md` §2–§8 |

The invariant everything hangs on (SPEC §1): *inference failure degrades performance only; it never
changes semantics and never fails the compile.* Tier is monotone in the facts, and every tier is
sufficient for every value.

---

## 3 · What is actually built (2026-11-22)

The spec describes more than the compiler does. This is the built subset. The authoritative
descriptions are the developer pages: `website/apps/developers/content/aif/overview.md`,
`compiler/aif-internals.mdx` (start with "Known conservative boundaries"),
`compiler/ownership-and-drop-lowering.md`, `aif/regions-views-and-provenance.md`,
`aif/tiers-and-analysis-domains.md`, `aif/ffi-contracts.md`, `aif/layout-selection.md`,
`runtime/allocation-arenas-rc-and-cycles.md` and `runtime/collection-representations.md`.

### 3.1 Two layers: legality, then storage

1. **Sema decides legality** (`src/sema/ownership.psm`). `String`, `Vec<T>` and structs are
   move-only. An ordinary parameter is a **borrow** with Swift `@guaranteed` semantics: the caller
   keeps the value and releases it after the call. Sema rejects retaining a parameter. `sink`
   consumes the argument, and `inout` gives caller-visible mutation. Moves are tracked per binding in
   source order, a move inside a loop is rejected, and branch joins are conservative. **There is no
   borrow checker and there are no lifetimes.**
2. **AIF decides storage** (`src/aif/` collects the evidence, and `src/aifcore/` is the engine, one
   module per responsibility). The engine was ported from C to Prismio on 2026-10-24 (`f502027`).
   Some docs still name `runtime/aif_support.c`, which no longer exists (§10).
3. **Codegen turns both into releases** (`src/ir/`): scope drop lists (`src/symbols/bindings.psm`),
   displaced-value release on overwrite, temporaries released after the call, and generated
   per-type release functions.

### 3.2 The engine's precision, plainly

From `aif-internals.mdx` "Known conservative boundaries", confirmed against the tree:

- **Context-insensitive sites.** A site is per allocating function, not per call. Every `concat` in
  a program is one site, so a fact about one use reaches all of them.
- **Flow-insensitive, field-sensitive per type, object-insensitive.** A field's points-to set belongs
  to the *type*, not the object. One function's use of `Bag.items` changes every function's.
- **Interprocedurally path-insensitive.** Joins are syntactic, and uncertain control flow is treated
  as unjoined.
- **The fixed point is monotone, with a budget and widening.** The compiler's own build converges in
  21 rounds over 196,189 constraints, in about 1 s of analysis.
- Ownership-context specialisation (INFERENCE §6–7) is **not built**.
- Several codegen questions are answered by a key-level flow graph over the constraints
  (`callResultHeld`, `callFnResultHeld`, `param_returns`, `E_held` / `ret_key` for a binding
  returned on only some paths). They patch context insensitivity one question at a time.

### 3.3 Tiers to mechanisms

The ladder as derived today, first match wins:

```text
T0  own defining scope, A ≤ Borrowed, eligible struct, known size ≤ 256 B   -> entry-block alloca
T1  E is a lexical Region                                                    -> bump arena, else region:none (heap)
T2  A ≤ Borrowed and T ≤ Transferred                                         -> owned, freed once
T3  T ≤ Transferred and C = Acyclic                                          -> rc, else rc:none
T4a T = CrossThread                                                          -> atomic rc
T4b otherwise                                                                -> rc + trial-deletion collector, else cycle:none
```

- **`rc:none` leaks.** An RC header is installed only for compiler-allocated **struct** sites held by
  containers. Strings, lists, opaque foreign returns and arrays never get one, so a T3 value of
  those kinds has no count and is never freed. `src/aif/report.psm:87-92` says so. §4.1 measures how
  much of a real program this covers.
- **Arenas** are placed automatically and innermost-first. The integer cost model is in
  `aif-internals.mdx` "Arena placement". Placements have non-lexical extents, cut from the first
  served allocation to the last use. **Call-site bracketing** (SPEC §5.2.1.1) lets a caller's arena
  serve a callee's allocations when every call site runs under one regime. The runtime arena is
  ambient, dynamically scoped and thread-local once `spawn` is used.
- **The cycle collector** is synchronous Bacon–Rajan trial deletion. It visits only fields inside a
  non-trivial SCC of the type graph and is omitted when no type is cyclic. Its phases are still
  recursive (MEM-015). The generated release of a recursive type loops along one self field and
  recurses on the others.

### 3.4 Containers and views

- **Element disposition** per container type: owned, counted, inert, or unknown. Unknown or mixed
  reclaims nothing.
- **Views** (SPEC §8.4): slices, element reads (`let n = v[i]` is a view), match binders, `expect`
  payloads and alias-returning calls are provenance edges. A live view keeps its base unreleased.
  Because `v[i] = x` may run while a view is read, **a displaced element is parked** until the Vec
  dies, unless one of two proofs holds:
  - a fresh local Vec whose elements nothing can view (`src/ir/overwrites.psm`, `semaRemovalVerdict`);
  - a **closed column** (`src/ir/columns.psm`, 2026-11-14): a private Vec field used only through
    list builtins, whose every `get` is consumed where it stands.
- Representations: Vec headers, inline flat elements, a one-allocation small Vec, German-string
  slots in containers, and strings of 12 bytes or fewer stored inline. See
  `runtime/collection-representations.md` and the `--verify` probing note in KNOWN_ISSUES.
- `HashMap` and `HashSet` are Prismio code over two dense parallel Vecs (`std/map.psm`).

### 3.5 Runtime

- **The allocation seam:** `rt_base_alloc`, `rt_base_realloc` and `rt_free`. Behind it, on 64-bit
  POSIX, sits a **slab**: a 64 GiB reservation, 64 KiB spans, 32 size classes from 16 to 512 B, and
  per-thread caches that spill in batches. The invariant is one-way: a slab block must never reach
  libc `free`. `docs/ALLOCATOR_PLAN.md` covers it, and stages 4–7 are still open (KNOWN_ISSUES,
  "The allocator").
- `--verify` swaps the seam for a ledger that counts allocated, released, leaked and violations,
  and tracks peak live bytes. **It cannot see a read after free** (ARCHITECTURE-DIRECTION §7), and
  it never exercises the slab.

### 3.6 Other memory surface

- **FFI contracts:** `borrow`, `consume`, `alias`, `produce(f)` (where `f` names the deallocator),
  `retain_in` and `bytes`. Covered by `docs/aif/spec/FFI.md` and `aif/ffi-contracts.md`.
- **The safety boundary** (`docs/MEMORY_SAFETY_PLAN.md`): code that does not import `std.raw` cannot
  corrupt memory. Bounds are checked, and range guards remove the checks in loops. `Ptr<T>` and
  `Block<T>` are the raw surface.
- **`std.mem`:** `Buffer`, manual alloc and `Arena`, written by hand.
- **Freestanding heap:** `docs/FREESTANDING_MEMORY.md` (built 2026-10-09). The kernel heap runs
  over `kmalloc`.
- **Layout:** field order and hot/cold split selection with measured vetoes. `workload NAME { … }`
  is parsed (`src/parse/decl.psm:2243`) and read by `src/aifcore/layout_search.psm`, although
  COMPILER-AUDIT and REQUIREMENTS #9 still say it was deliberately not built.
- **Concurrency:** tasks with three word-sized argument slots and typed channels (`docs/CHANNELS_PLAN.md`).
  Task handles are **copyable**.

---

## 4 · Measured state

### 4.1 New this session: the compiler's own tier distribution

`prismio aif src/main.psm --summary` and `--manifest`, release host at `HEAD 5757802`:

```text
src/main.psm  (4079 functions, 130 nominal types)   rounds=21  constraints=196189
sites 2004  (10467 string literals excluded; 387 opaque extern returns; 1855 extern-produced values)

  T0   34    1%      T1  586   29%      T2  317   15%      T3  1067   53%      T4  0
  T0-T2: 46%   -- SPEC's H1 kill criterion is < 70%: FAIL

  kind     sites   T0   T1    T2    T3
  struct   134     20    0    77    37
  string   725      0  450    84   191
  list     743      0  136   156   451
  array     15     14    0     0     1
  opaque   387      0    0     0   387

  T3 placement: rc 15, rc:none 1052
  T3 by type:   Ptr 387, List<Int> 352, String 191, List<String> 34, List<Ptr> 18, List<List<Int>> 18
```

> **Correction, the same day** (`RESEARCH_P1_RESIDUE.md`): every one of the 1,067 T3 sites was
> explained, and none has two owners. 386 are `ptr_null()` calls (null, no contract, counted as
> allocations), 485 are module-level global tables (`A-ESCAPE`), and 195 inherit sharing from the
> compiler's single `ASTNode` site. The language server (590 functions) reads 100% T0–T2. Read
> the paragraph below with that in mind.

The benchmark suite (`benchmarks/hosted/prismio/suite.psm`) reads **100% T0–T2, 0 T3**. **The
benchmarks never exercise the residue, and a real 4,000-function program is mostly residue.** In
the compiler, 1,052 of 1,067 T3 sites carry no count and are never freed. This is the strongest
single signal in this brief. The compiler is a batch process, so it tolerates the leak. The language
server, which runs for hours, has to work around it (KNOWN_ISSUES, "UMS resolution releases nothing
it allocates").

Reproduce with:

```bash
PRISMIO_INTERNAL_HOSTED=1 .prismio/build/release/prismio aif src/main.psm --summary
```

Add `--manifest` for per-site rows and `--why=<ID|symbol>` for the minimal cause behind one decision.

### 4.2 Leak ledger across the tests

The audit of 2026-10-09 (`docs/KNOWN_ISSUES.md` "What the test suite still leaks"): 281 programs
under `--verify`, **0 violations**, 463 leaked blocks in 20 programs. 300 of those blocks come from
one pinned fixture. Since then, `07d4bd0` (2026-11-15) holds the language-gaps tests at 0 leaked
and records a new frame-site payload leak whose obvious fix is unsound (§5 B). **The table has not
been re-run since 2026-10-09.**

### 4.3 Allocation-heavy workloads

`docs/GRAPH_CHURN_FINDINGS.md`: after the ownership fixes and the slab, the `graph_churn_*` arms
run at 0.83×–1.03× of C++, with peak RSS 1.1×–1.5× of C++. The allocator work took about 25% of run
time. Before the ownership fixes the arms were at 2×, with 8× to 32× the RSS, almost all of it
parked elements.

---

## 5 · Open problems, by root cause

KNOWN_ISSUES lists the open items one shape at a time. This section groups them by the mechanism
underneath, because that is the level where an innovation would apply. Each item names the
KNOWN_ISSUES entry that holds the reproducer.

**A. Context-insensitive sites.** One site serves every call of a producer, so ownership is a
whole-program fact. When `StringBuilder` stored `concat` results in a field, every `concat` argument
in any program importing `std.fs` and `std.string` stopped being released (`test_184` leaked 2,165
of 4,073 blocks). Adding an unrelated function that builds a `Vec<Int>` cost `make(i).name` its
release. `toUpper` and `toLower` are written as two bodies for this reason. *The planned fix* is
context-sensitive sites for library producers (MEMORY_PLAN §2.3; INFERENCE §6–7 specifies
contexts). KNOWN_ISSUES entries: "Library producers share one allocation site" and "A field or
element read off an owned temporary".

**B. Per-type field and element keys (object insensitivity).** A type used two ways declines. Stack
and heap `Inner`s in one field mean `Outer` releases nothing. A frame-site enum payload leaks, and
skipping frame sites was tried and freed a frame value (`07d4bd0`). One `Vec<String>` that hands out
an element makes every `Vec<String>` a non-owner. A counted and an uncounted element of one type in
one Vec leak the uncounted one. KNOWN_ISSUES entries: "A struct on the frame", "The Vec/Map
ownership model gives up on a shared container type", "A Vec that owns its elements", and the
frame-site payload entry under Language surface. The fixes on record are per-site field keys
(`thetaFields`, `--theta-fields`), holder-aware release, and per-instance tags.

**C. Views without lifetimes.** Elements are parked until their Vec dies. A view that outlives its
base's binding keeps the base unreleased (tests 185 and 53). A match binder returned from its arm
pins the whole `Result` (`test_273`, 300 blocks). The proposed fix on record is copy-on-escape:
materialise a view where it leaves its base's scope. *The open question:* how much lifetime
reasoning can be inferred, never written, without becoming a borrow checker the user can see?
SPEC §8.4 states the design stance.

**D. Facts that are only known at run time.** `pick(a, b)` returns one of its parameters, and which
one is dynamic, so the other one leaks (`test_269`). The proposal on record is a release guarded by
pointer equality with the result. The more general question is where a cheap run-time check
(a tag bit, an equality test, a per-instance flag) should replace a static proof that cannot exist.

**E. Literal and untracked storage mixed with owned storage.** A field or container that may hold a
`.rodata` literal releases nothing, because freeing a literal is a violation. `Process.program`
and `optionOr(x, "fallback")` pushed into a Vec are examples. Promoting the literal at the store
is not sound across a `.plib`. The borrowed-String tag (bit 34) is precedent for a tag-bit answer.

**F. The `rc:none` residue (§4.1).** T3 is derived for strings, lists and opaque pointers that have
no header to count. Either they need a representation that can carry a count, such as a header on
the seam's blocks, a count in the slab span's side table, or a refcounted string, or the analysis
needs to prove them T2 or T1 more often. This decides whether long-running Prismio programs leak.
Nothing in the tree attacks it yet.

**G. No middle IR.** Moves, borrows, lifetime ends and return provenance are gone before LLVM sees
them. Codegen carries a growing set of guards that re-derive facts syntactically:
`irHoistBorrowedTemporaries`, `irValueAliasesName`, `chainRetainsAliasOf`, `nodeReturnsAliasBeyondBare`,
the closed-column walk and others. The recurring bug class is **the analysis and codegen
disagreeing** about who owns a value. The temporary on the right of `and`/`or` cannot be bound
ahead of the statement. The backend emits no `llvm.lifetime` markers, structs are always passed by
pointer, and fresh struct returns get no result slot. MEMORY_PLAN §2.3 has the MEM-004/005/007/008/009/012/013
table, and its recommended order is telemetry, then effect summaries, then a MIR.

**H. Concurrency.** Task handles are copyable, so a struct or String result from `join` has no
owner and leaks (KNOWN_ISSUES "Concurrency"). A `spawn` that is not proved joined leaks its owned
temporaries. The collector's candidate state is process-global behind a lock.

**I. Allocator.** The slab has never run on Linux. Memory never goes back to the OS. Windows still
uses the old recycler. Two Prismio runtimes in one process each have their own slab (INTEROP_PLAN
D10). ALLOCATOR_PLAN stages 4–7 cover these.

**J. Representation.** A payload enum is a tagged product, not a union (MEM-026, blocked on struct
size introspection). There are no niches beyond the null-pointer optimisation (MEM-018). The arena
does not limit its peak, and capacity is not inferred (MEM-013).

**K. Observability.** The ledger does not record which site an allocation came from, and there is
no machine-readable per-site telemetry (MEM-001). Telemetry is the precondition MEMORY_PLAN sets
before choosing any target.

---

## 6 · Tried, measured and rejected: do not re-propose without new evidence

The sources: `docs/aif/implementation/RATIONALE.md` (reverted simplifications),
`docs/ARCHITECTURE-DIRECTION.md` §7 ("Measured dead ends"), and the developer docs' *Performance
decisions and rejected experiments* page. The ones closest to memory:

- **A general allocator replacement.** mimalloc came in at 1.021× time and 1.242× RSS, rpmalloc at
  1.003× and 1.627×. The slab that shipped is narrower: small size classes behind the seam.
  *Docs drift:* the decisions page still says "the system allocator stays".
- **Boxed layout costs indirection.** Measured 0.86×, so indirection is free here. The cost is the
  allocations, as the hot/cold split that broke inline list storage showed.
- **Fully automatic layout search before views existed.** The cost model ranked two layouts that
  measurement rejected.
- **Automatic borrow inference.** Koka declines it on space-safety grounds.
- **Building an analysis before asking the type system.** Parameters are already borrows, and a
  three-line probe settled what had been budgeted as a fixed-point change.
- **Skipping frame sites in `fieldReleaseOf`.** Unsound: it frees a frame value (`07d4bd0`).
- **`!invariant.load` on the List header.** Unsound, because `list_push` rewrites the header.
- **Whole-runtime LTO.** Dominated by curating 8 functions.
- **Reading a balanced `--verify` ledger as proof of correctness.** A read after free balances.

---

## 7 · Constraints any proposal must respect

1. **A leak is acceptable; a violation is not.** A violation is freeing something not live, reading
   a dead frame, or computing a wrong answer. When unsure, the conservative direction is the leak.
2. **No required annotations.** Deleting `unique`, `region`, `workload` and `pin` must leave a
   working program (SPEC §5). New syntax may be optional and must be a contextual identifier, not a
   reserved word.
3. **Performance decides trade-offs.** The target is to beat C++ and Rust. A mechanism that costs
   every program something, such as atomic counts everywhere or a tracing GC, needs an exceptional
   case.
4. **LLVM stays the optimiser.** Hand it facts (noalias, lifetime, dereferenceable, contiguous
   views). Do not replace it.
5. **Determinism.** The same input gives byte-identical IR (INFERENCE §5.4). A behaviour-preserving
   change must produce byte-identical output for every program in `tests/` and
   `benchmarks/hosted/prismio/`. The compiler must reach a two-generation fixpoint, read in the IR.
6. **The engine and the oracle move together.** `tools/aif_oracle/aif.py` and
   `tools/aif_differential.py` must agree on the default sources.
7. **Bootstrapping.** New syntax lands in two steps: teach the frontend and cut a seed, then use the
   syntax in `src/`. Committed seeds are expensive, at about 20 MB each.
8. **The allocation seam is one-way.** A seam block is released only by `rt_free` or
   `rt_base_realloc`. `produce(f)` and `alias` are read, never guessed.
9. **Parameters are borrows.** A proposal that needs a callee to keep an ordinary parameter is
   proposing a language change.
10. **Compile time.** The analysis is about 1 s on the compiler's own build. INFERENCE §5.7 and SPEC §7
    specify levels per module, but those are not built.
11. **Separate compilation exists.** `.plib` libraries ship bitcode compiled before the program that
    uses them (`docs/aif/spec/PIR.md` §5 covers sealed contracts). A fact that only the whole
    program knows cannot be baked into a library.

---

## 8 · Questions we would most like answered

These are starting points. Go beyond them.

1. **The `rc:none` residue.** What is the cheapest sound mechanism that lets strings, lists and
   opaque pointers that are genuinely shared be reclaimed? Options include headers on seam blocks,
   counts kept in slab span metadata, Perceus-style precise RC with reuse, or making T3 rarer through
   better proofs. What would the compiler's own T3 count fall to under each?
2. **Context sensitivity at an affordable price.** Selective k-CFA, contexts only for library
   producers, the relevant-parameter mask (INFERENCE §7.1), or summaries cloned per call site. What
   is the prior art for doing this cheaply inside whole-program points-to analysis?
3. **Object sensitivity for fields.** Per-site field keys are the recorded idea. Is there a
   formulation, such as allocation-site heap cloning or recency abstraction, that stays monotone and
   deterministic?
4. **Inferred lifetimes for views, never written.** How far can second-class references
   (Hylo/Val's mutable value semantics, Swift's `~Escapable`, Mojo's origins, Vale's
   generational references) be inferred so that parking and copy-on-escape become rare?
5. **Static proof plus a cheap dynamic check.** Where do generational references, a tag bit, or a
   pointer-equality guard beat a static proof? Clusters D and E above.
6. **A Memory MIR.** What is the smallest ownership-aware IR that would retire the codegen guards in
   cluster G? Can it land one function subset at a time, with byte-identical output elsewhere?
   What would it look like next to Swift's OSSA, Rust's MIR or Lean's IR?
7. **Regions.** Non-lexical and polymorphic regions (Spegion, Tofte–Talpin with its retrospective),
   explicit region handles in place of the ambient arena (MEM-012), and arena peak control (MEM-013).
8. **Structural levers.** Which memory-model rules let Prismio do something C++'s or Rust's language
   definition forbids, such as relocatable data through handles (SPEC §8.1), compiler-owned layout,
   or whole-program reuse? Use `docs/STRUCTURAL_LEVERS_PLAN.md`'s test.
9. **Concurrency.** Affine task handles, or join returning a copy. Biased RC for T4a. A collector
   whose state is per thread.
10. **Verification.** A checker that sees a read after free in the `--verify` build (the ledger
    poisons released storage, but nothing detects a read of it), and an independent validation for
    the slab.

---

## 9 · How to check a claim against the tree

```bash
# decisions, per site, and why
PRISMIO_INTERNAL_HOSTED=1 .prismio/build/release/prismio aif <file.psm> --summary
PRISMIO_INTERNAL_HOSTED=1 .prismio/build/release/prismio aif <file.psm> --why=<ID>
# run-time ledger; probe with strings longer than 12 bytes (shorter ones are inline)
.prismio/build/release/prismio build <file.psm> --verify -o /tmp/t && /tmp/t
PRISMIO_VERIFY_TRACE=1 /tmp/t          # where each leaked block was allocated
PRISMIO_COLUMN_TRACE=1 .prismio/build/release/prismio build <file.psm>   # closed-column verdicts
python3 tools/aif_differential.py      # engine vs oracle
```

The pinned ownership shapes are under `tests/` (`ownership_probes` in `tests/test_runner.py`), and
each KNOWN_ISSUES entry carries a reproducer.

---

## 10 · Reading list, in order, and known documentation drift

1. `docs/aif/README.md`, then `docs/aif/implementation/RATIONALE.md`
2. `website/apps/developers/content/aif/overview.md` and `compiler/aif-internals.mdx`
3. `website/apps/developers/content/compiler/ownership-and-drop-lowering.md`
4. `website/apps/developers/content/aif/regions-views-and-provenance.md`
5. `docs/KNOWN_ISSUES.md`, the sections "Ownership: leaks", "The AIF analysis and its oracle", "The
   allocator" and "Concurrency"
6. `docs/MEMORY_PLAN.md` (the roadmap: MEM-ids, MIR, representation)
7. `docs/aif/spec/SPEC.md` and `INFERENCE.md` (§11: known weaknesses), then `CYCLES.md`, `FFI.md`, `LAYOUT.md`
8. `docs/ALLOCATOR_PLAN.md`, `docs/GRAPH_CHURN_FINDINGS.md`, `docs/MEMORY_SAFETY_PLAN.md`, `docs/FREESTANDING_MEMORY.md`
9. `docs/ARCHITECTURE-DIRECTION.md` (literature and dead ends) and `docs/STRUCTURAL_LEVERS_PLAN.md`
10. The developer docs page `performance/decisions-and-rejected-experiments.md`
11. `docs/aif/implementation/COMPILER-AUDIT.md` (the build-out history, Levels 0–5, through 2026-08)

**Docs that disagree with the tree, as of today:**

- `runtime/aif_support.c` is named in `ownership-and-drop-lowering.md`, KNOWN_ISSUES, ALLOCATOR_PLAN
  and others. The engine is `src/aifcore/` since `f502027` (2026-10-24).
- "The system allocator stays" (decisions page) predates the slab (2026-10-24).
- `workload` is described as "deliberately not built" (COMPILER-AUDIT, REQUIREMENTS #9), but it is
  parsed and read by `layout_search.psm`.
- KNOWN_ISSUES' leak table and several entries marked **Not re-run** date from 2026-10-09 or earlier.
- MEMORY_PLAN's status line says "checked 2026-09-25". MEM-002 and the allocator have moved since.
