# Prompts for the next sessions

## 2026-08-21 — see `SESSION-PROMPT.md`

The live prompt moved to its own file at the repo root. This entry is a pointer so the archive
does not carry a second, diverging copy.

An earlier draft of it lived here and **was ordered wrong**: it put `-g` follow-through and JIT
ahead of cross-compilation. Two things settled after it was written moved JIT off the critical
path entirely — iOS is out of scope, and a web reload needs no JIT, because a whole-program
rebuild of a compiler-sized app measures 83 ms frontend + 116 ms LLVM at `-O0`. `SESSION-PROMPT.md`
carries the corrected order: layering, then targets, then `-g`, then JIT as optional.


## 2026-08-20 (DWARF) — `-g` is in; the compiler itself still cannot be stepped through

**State, verified on the tree.** Suite **132/132**; two-generation fixpoint `S10c == S10d`; cold
build from the **committed seed** byte-identical to the warm chain; the IR snapshot over
`tests/`, `aif/corpus/`, `aif/evidence/` and `src/` moves exactly one file, `src/main.ll`, which
moved because `src/` did; AIF differential agrees on 17 sources; `-g` builds all 78 programs in
`tests/` + `aif/corpus/` cleanly. **Last-good: `build/S10d`.** The seed was not refreshed and did
not need to be — no new syntax.

### What landed

`-g` on `build`/`run`: a DICompileUnit, a line table, a DISubprogram per source function, a
DILexicalBlock per block, a DILocalVariable per binding, and a DICompositeType per struct with
member offsets read from the type LLVM actually built. `runtime/llvm-api-backend.c` grew a
"Debug information (DWARF)" section; `src/ir/debug.psm` is the frontend half and is where the
"never emit a wrong location" rule is written down.

And `docs/DEBUGGING.md`, which is the write-up of `--verify` / the manifest / `--why` as a
debugging story. That was the half of the brief that was not engineering, and it is the half
nobody outside this repo knows exists.

**Read HANDOFF's 2026-08-20 entry before starting**, especially §2. The data-layout pin is the
one place where a plausible implementation produces DWARF that points four bytes past every
64-bit integer field, and the reason is not visible from the code.

### The tasks, ranked

1. **`-g` for `prismio bootstrap`.** The flag is on `build`/`run` only, so the one program in
   this repo that most needs stepping through — the compiler — is the one that cannot be. It is
   threading `debugInfo` through `compileSource`'s bootstrap branch, plus a decision about
   whether `build_from_toolchain_sources` should pass `-g` to the runtime's C objects so a
   stack trace crosses the FFI boundary intact.

2. **Module-level globals get no debug info.** Checked: a program with `let mut counter = 0`
   at the top level emits `@counter` and zero `DIGlobalVariable`, so a debugger cannot name it.
   `LLVMDIBuilderCreateGlobalVariableExpression` plus a call from `generateModule`'s global
   loop, where the type key and the span are both already in hand. Smaller than it sounds and
   it is a plain hole rather than a fidelity limit.

3. **A closing-brace span on BLOCK.** `parseBlock` knows the `}` token and throws it away, so
   every scope drop, arena pop and region exit inherits the *previous statement's* line.
   Stamping the span fixes that attribution. **It does not affect variable liveness** — LLVM
   derives a DW_TAG_lexical_block's low_pc/high_pc from the instructions in the scope, which
   the dumps confirm, so scoping is already right. This is a line-table nicety, ranked here
   because it is cheap, not because anything is broken.

4. **Enums as `DW_TAG_enumeration_type`.** `ir_register_enum_variant` already holds the
   name→value map. It needs one accessor in `ir_symbols.c` and about fifteen lines in the DWARF
   section, and it turns `p kind` from `12` into `STRUCT_DECL`.

5. **`--verify` that instruments reads.** It catches a double free and a leak today; a
   use-after-free is only made *loud*, by poisoning released memory with `0xDD`. SPEC 7.3's
   table says what each remaining row needs, and the header over the shims in
   `runtime/lang_runtime.c` says which are blocked on an object header.

### Found in passing, not this session's bug

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

### Two things not to re-derive

- **The data layout must be pinned under `-g`, and only under `-g`.** LLVM's default
  specification gives `i64` a 4-byte ABI alignment. `tests/debug_info.psm`'s `Checkpoint` exists
  solely to make that difference observable; if you touch `pin_data_layout`, that fixture is
  what tells you.
- **A forced layout candidate the search does not offer is a warning and no split.** That is why
  `run_debug_info_test` reads the cut out of `prismio aif --layout` instead of hardcoding one.

### Not this session

Another container. The `-g` work touched none of the memory model and the ranking above is
deliberately all debug-info follow-through — but the memory-model list from the concurrency and
payload-enum briefs below is untouched and still current.

---

## 2026-08-19 (concurrency) — the `T` domain is live; the join analysis is the hole

**State, verified on the tree.** Suite **131/131**; two-generation fixpoint `S9g1 == S9g2`; cold
build from the **committed seed** byte-identical to the warm chain on all 98 programs; **every one
of the 94 programs that predate this session emits byte-identical IR**, the exception being
`src/main.ll`, which changed because `src/` did; AIF differential agrees on 17 sources, two of them
concurrent, and now has teeth on the join analysis. **Last-good: `build/S9g2`.** The seed was not
refreshed and did not need to be — `src/` uses no `spawn`.

A REQUIREMENTS 4 follow-up landed after the concurrency work: optionals in *return* position were
decoding to `Invalid` through a binding (`typeFromSemKey` had no `opt:` case). See HANDOFF's
concurrency entry §5 — the interesting part is that the three obvious suspects were all innocent.

### What landed

`spawn f(a, b)` / `join t` (contextual keywords), real OS threads and channels in
`runtime/program_support.c`, INFERENCE 4.3's thread module in both the solver and the oracle, a
`thread` column in the manifest, and T4a emitted for the first time with an atomic count.
`aif/implementation/COMPILER-AUDIT.md` finding 7 is closed.

**Read HANDOFF's 2026-08-19 (concurrency) entry before starting**, especially §2 — the two
deliberate departures from INFERENCE 4.3 are shared by both implementations and so are exactly what
the differential *cannot* catch.

### The tasks, ranked

**All three of the previous list are done.** E-SPAWN-J has a real per-path analysis, `Task<R>`
carries its result type, and SPEC's levels table is resolved at 1.2.4. What is left is genuinely new
ground.

1. **Measure the tier distribution on concurrent code.** SPEC 11.0's open item #1 — "the whole
   performance thesis rests on typical code landing overwhelmingly at T0–T2, and nobody has
   measured it" — now has a concurrency arm for the first time. The corpus has no concurrent
   program. Write one (a worker pool over a channel is the obvious shape), run BENCHMARKS H1
   against it, and find out whether isolation actually keeps T4a near zero on code that was written
   to do work rather than to exercise a rule.

2. **`chan_*` is FFI surface, not language.** A channel is externed by hand and carries `Ptr`, so
   nothing type-checks what goes in or comes out. `Chan<T>` would want the same treatment `Task<R>`
   just got — a PTR-kinded type with a child and a sem-key round-trip. The pattern is now written
   down twice; a third use should probably generalise it rather than copy it.

3. **Arity 3 is still the ceiling.** Unchanged, and still not a restriction of the model: a general
   answer wants a per-site wrapper unpacking an argument pack, which is REQUIREMENTS 3a's closures.

### Two things not to re-derive

- **`spawn` is a contextual keyword and has to stay one.** `aif/corpus/g4_ecs_world.psm` has
  `fn spawn(...)` and `tests/test_62_split_release.psm` has a struct field named `spawn`.
- **The `@elem` key is one per container *base* type**, and every `List<T>` shares `List`. A
  cross-container push anywhere in a file marks every pushed site in that file as multiply held.
  That is why `tests/aif_concurrency_shared.psm` is a separate file and why its control lives in
  `tests/test_48_aif_shared_elements.psm`.

---

## 2026-08-19 (payload enums) — `Option`/`Result` are in; exhaustiveness is the hole, and REQUIREMENTS 18 now gates two things

**State, verified on the tree.** Suite **128/128**; two-generation fixpoint `S7x3 == S7x4`; cold
build from the **committed seed** byte-identical to the warm chain on all 89 programs; IR unchanged
from the previous build on every pre-existing program except `src/main.ll`; AIF differential agrees
on 15 sources. **Last-good: `build/S7x4`.** The seed was not refreshed and did not need to be —
`src/` still uses no new syntax.

### What landed across the whole session

Generics with monomorphisation (`src/sema/generics.psm`), `Map<K,V>` (`std/map.psm`),
payload-carrying enum variants (`src/sema/enums.psm`), `Option`/`Result` (`std/option.psm`), and
exhaustiveness plus arm-reachability checking over payload enums.
Both features are AST-to-AST transforms: sema, AIF, the layout optimiser and codegen learned nothing
about either. That is the pattern to keep.

**Read HANDOFF's two 2026-08-19 entries before starting**, especially §3 of the payload-enum one —
the node-lifetime rule cost three crashes and will cost a fourth otherwise.

### Two things found rather than built

- **A partial struct literal was reading uninitialised memory** and had been since struct literals
  existed. Fixed for all structs, not just enums. No test or corpus program changed.
- **`Vec<T>` was never missing** — `List<T>` is the growable vector. REQUIREMENTS 13 asked for two
  containers and was missing one.

### The tasks, ranked

1. **REQUIREMENTS 18 — the size of a type**, plus a way to index raw memory as `T`. It now gates
   *two* things, not one: containers written in Prismio (and therefore any migration out of
   `runtime/aif_support.c`), and the tagged **union** that would collapse a payload enum's
   per-variant fields into one overlapped slot. Decide whether `Ptr` grows arithmetic or whether a
   `RawBuffer<T>` primitive is the seam.

2. **Bounds on type parameters.** `std/map.psm` is an association list because a generic body may
   only use operations that typecheck at every instantiation, and `==` is the widest available.
   Every function there goes through `mapIndexOf`, so bounds turn one body into a hash table with no
   caller change.

3. **Ownership contexts** (INFERENCE 6), reusing the instantiation machinery keyed on a context
   tuple rather than a type tuple. There is still no such mechanism in the tree; `aif_support.c:5156`
   remains accurate.

4. **Inference from the expected type**, which is what `Result.Ok(5)` needs to solve `E`. A
   bidirectional pass, and the last ergonomic rough edge in the error-handling story.

Deliberately not on this list: a propagation operator for `Result`, which needs the ownership and
cleanup-during-non-local-exit story first; and `unwrap`, which is declined on purpose.

### Small, and it will pay for itself immediately

`tests/test_runner.py` takes **no arguments**. There is no way to run one check, so any change to a
single fixture costs a full ~4-minute suite run. Most of the runner is a chain of
`if run_X_test(): passed += 1 else: failed += 1`, so a `--only <substring>` that filters both the
fixture globs and that chain is a contained change. It cost real time this session.

### Not this session

DWARF, concurrency.

---

## 2026-08-19 (generics) — monomorphisation is in; the stdlib floor is now gated on one missing primitive

**State, verified on the tree.** Suite **123/123**; two-generation fixpoint `S7g10 == S7g11`; cold
build from the **committed seed** byte-identical to the warm chain on all 89 programs; IR unchanged
from the pre-session baseline on 88 of 89 (only `src/main.ll` moved); AIF differential agrees on 15
sources. **Last-good: `build/S7g11`.** The seed was **not** refreshed and did not need to be —
`src/` uses no new syntax.

### What landed

Generic functions and types with monomorphisation (`src/sema/generics.psm`), as an AST-to-AST
transform: sema and codegen were not taught about generics and needed no change. `Box<Int>` emits
`{ i32 }`. Inference is structural and argument-position only; explicit arguments cover the rest.
`Map<K,V>` shipped as `std/map.psm`, the first container written in Prismio, and `std.*` imports now
resolve against the compiler's library rather than the importing file.

Read HANDOFF's 2026-08-19 entry before starting. Do not re-derive §4 — three crashes, all the
affine model, all cheap to hit again.

### Two premises in the last brief were wrong, and the correction matters

- There is **no ownership-context mechanism** to share an implementation with; `aif_support.c:5156`
  says INFERENCE 6 is unbuilt. Instantiation was built in 6.3's shape so contexts can reuse it —
  one new key function, not a new pass.
- **`Vec<T>` was never missing.** `List<T>` is the growable vector. REQUIREMENTS 13 asked for two
  containers and was missing one.

### The tasks, ranked

1. **Payload-carrying enum variants, then `Option<T>` / `Result<T,E>`** (REQUIREMENTS 14). This is
   the one users hit first and it did *not* land this session — generics did not make it cheap,
   because a struct has no `T` to put in the absent case. Needs: payload variants in parser and
   sema, a `{ i32 tag, payload }` layout sized by the widest variant, `match` arms that bind the
   payload, and move/drop rules that know which variant is live. The generic half is already done —
   `monoIsTemplate` admits FUNCTION and STRUCT_DECL, and ENUM_DECL is a one-line addition.

2. **REQUIREMENTS 18 — the size of a type**, plus a way to index raw memory as `T`. This is the
   gate on everything left in the container story, and it is why this session answered "almost
   none" to how much of `aif_support.c` moves into Prismio. `List<T>` cannot be written in Prismio
   without it, which is also why the brief's "replace the hardcoded `List<T>`" test could not be
   run as written. Decide whether `Ptr` grows arithmetic or whether a `RawBuffer<T>` primitive is
   the seam.

3. **Bounds on type parameters.** `std/map.psm` is an association list because a generic body may
   only use operations that typecheck at every instantiation, and `==` is the widest one available.
   Every function there is written through `mapIndexOf`, so bounds turn one body into a hash table
   with no caller change. INFERENCE's worklist wants the O(1).

4. **Ownership contexts** (INFERENCE 6), reusing this session's machinery keyed on a context tuple.

### Not this session

DWARF, concurrency. And do not spend the session on a fifth container until task 2 lands — the
answer will be the same one this session got.

---

## 2026-08-17 (compile time) — the frontend is linear now, and incrementality is not an AIF problem

**State, verified on the tree rather than remembered.** Suite **120/120** (and green again with
`PRISMIO_OBJ_CACHE=0`); warm fixpoint `W2 == W3`; cold fixpoint `Uc1 == Uc2` from the **committed**
seed; **cold == warm byte-identical on all 89**; seed refreshed from `W3` afterwards and its gen0
already produces the fixpoint IR; oracle agrees on **15** sources; `--verify`
`released`/`violation(s)` identical on all 6 corpus ledgers with 0 violations.
**Last-good: `build/W3`** warm, `build/Uc2` cold, `build/Wc1` from the refreshed seed. `build/L5`
is the pre-session generation.

**Two things that were broken for months and are not any more.** The workload profile race is
**fixed** — `ir_snapshot.py` can be run concurrently again (2 of 30 rounds diverged before, 0 of 90
after). And **`prismio bootstrap` builds a compiler again**: it had no `-lLLVM-C` on its link line
since the move to the LLVM C API, so it compiled everything and then died in undefined symbols,
while the driver's own error message recommended it. It resolves LLVM from the same two places the
scripts do, and `run_bootstrap_command_test` requires the compiler it builds to emit byte-identical
IR to the script-built one — because a compiler can link and still be the wrong compiler.

**Incremental builds are half done, and the benchmark says which half.**
`python3 aif/evidence/compile_bench.py --compiler build/T3 --baseline build/L5` prints four
scenarios per program; the one that settles it is **no-change**, which costs the same as a real
edit (0.176 vs 0.178 s small, 2.692 vs 2.702 s on 505 KB). Nothing about the program's own
compilation is reused. What the cache does buy, measured: 34-line program **3.0×**, `g1` 1.5×,
505 KB project 1.10×, the compiler's self-build **1.9×**, **the suite 226 s → 170 s**.

**Diff IR across this session with `tools/ir_slot_diff.py`, not `diff`.** Taking the `$fn$` keys
out of the binding table freed the slot serials they were consuming, so every `%name.N` in every
program is renumbered: **89 of 89 programs move and 0 differ**. Inside the session everything is
byte-identical.

### What landed

* **REQUIREMENTS 16 — done.** It was four scans in three passes, not the one the requirement names.
  `check` on a 4 000-function module goes 1.241 s → **0.088 s**; on the compiler's own source
  0.126 → **0.039**. Frontend time is now linear over 31 KB–1.85 MB.
* **A content-keyed object cache, in the build driver and in both bootstrap scripts**, plus the
  seven bootstrap compiles issued in parallel. The compiler's self-build goes **2.96 s → 1.58 s**
  warm and 2.67 → **2.09 s** uncached. Three bugs were found in it and fixed, two of them the same
  day they were written — see HANDOFF §5.2; the one worth carrying is that `rename()` cannot cross
  a filesystem, so the cache would have silently never populated on a host whose `/tmp` is a
  different volume.
* **The first hard ceiling on program size is gone.** `value table exhausted` at ~3 500 functions
  was two fixed arrays indexed per module; they grow now, the IR is byte-identical below the old
  ceiling, and a 1.85 MB source compiles.
* **SPEC §7.5**, per-module optimisation levels, specified (REQUIREMENTS 10).
* **`tools/incremental_manifest.py`**, INFERENCE §9's required equality test, running today and
  asserting three things about itself so it cannot pass vacuously.
* **The per-module split is priced** — see below. It is the only large win left.

### The measurement that should decide the next few sessions

| | |
|---|---|
| `clang -O2` on the emitted IR | **75.8%** of a cold 505 KB build |
| Prismio frontend (parse, sema, AIF, codegen) | 3.7% |
| **AIF's entire whole-program fixed point** | **18 ms** on the compiler — 19% of the frontend, **<1% of a build** |

The projection that incremental rebuilds might be worse than Rust's *because* whole-program
inference is non-incremental is refuted at its premise. Compile time here is LLVM's time on the
emitted IR, the same as Rust's. Full detail and the phase tables:
[RESULTS-compile-time.md](aif/evidence/RESULTS-compile-time.md).

### The per-module split, priced (RESULTS-compile-time §5)

`llvm-split` stands in for the compilation unit the compiler does not have, so both halves of the
trade are measured rather than argued. On the 505 KB project's 3.34 MB module:

| | |
|---|---|
| unsplit `clang -O2` | 2.45 s |
| split 8, **all parts** | **1.44 s** — LLVM's pipeline is superlinear, so splitting is a *cold* win too |
| split 8, **one part** | 0.191 s — a rebuild touching one file |
| a 505 KB rebuild, end to end | **≈0.5 s against 3.31 s**, frontend floor included |
| runtime cost | `xlang/g2` 0.975×–0.986×, `xlang/g6` 1.014× — inside their noise bands |
| the catch | `g1_particles` split 8 ways costs **5×** the total work. Below ~100 KB of IR, do not split |

The runtime result has a mechanism behind it: the hot code in these programs is `list_get`,
`list_push` and the allocator, which live in `lang_runtime.c` and were always a separate object.
A program whose hot loop is its own code has to be re-measured.

### Next, ranked

1. **Build the per-module split.** Priced above; the only large win left, and the compilation unit
   SPEC §7.5, REQUIREMENTS 10 and REQUIREMENTS 21 all need. Two known obstacles, both small and
   both visible in this session's IR delta: string-literal names and slot serials are numbered per
   module, so per-file IR is not stable under an edit elsewhere. One design choice: the crossover
   says do not split a small program.
2. **Then compile the parts in parallel**, the way `bootstrap.sh` now compiles the toolchain.
   Everything in the table above is sequential; the cold number falls again by roughly the core
   count.
3. **Verify `tools/bootstrap.ps1` on Windows**, and give it the parallel compile `bootstrap.sh`
   has. Its object cache is written to mirror the shell one and was read, never run — there is no
   PowerShell on the host it was written on.
4. **Do not build INFERENCE §9's summary cache** without re-taking the 18 ms first. It needs
   `aif_support.c` partitioned per function with a reverse call graph, and it is worth 0.7% of a
   build.
5. §8's search loop, `list_get`'s call per element, the profile race, handles — unchanged from the
   previous session's list.

---

## 2026-08-17 (second) — LAYOUT §8's forced candidate landed; read this before writing another brief

**The brief that opened this session described three already-built items as open**, and cost a session
of planning to unpick. Its `State:` paragraph read "suite 98/98, 82 programs, oracle 13" against a
tree at **116/116, 89, 15**; it asked for the hot/cold split (built, uncommitted, in the tree), the
cost-model port (committed 2026-08-16), and `bench.py`'s allocation fix (committed 2026-08-16). It
also opened by instructing that a "hand-tuning prompt" be run first, for its container-disposition
change — **no such prompt exists in this repo**, and the disposition mechanism it wanted to inherit
had already landed with hot/cold.

Two consecutive briefs claimed handles had landed when they had not. This one claimed three landed
things had not. **The failure is the same failure and it has now gone in both directions**: a state
paragraph written from memory rather than from the tree. Ten seconds of `--layout` or `git diff
--stat` settles it either way.

### What landed here

`--force-layout=<Type>:<hot>` — emit a named layout candidate rather than §7.2's argmin, on `build`
as well as `aif` — plus `aif_layout_cand_at_rank(k)` for §8's top-`k`. This was the hot/cold session's
ranked #2 and the one mechanism it named as standing between §8 and implementability.

Gate: **117/117**, **0 of 89 programs move** with no flag, warm and cold fixpoint, cold == warm on 89,
oracle 15, `--verify` unmoved on all 6 corpus ledgers, seed refreshed and its cold start reaching the
fixpoint in one generation. **Last-good: `build/L5`** warm, `build/Lc2` cold, `build/Ls1` from the
refreshed seed.

Design notes not to re-derive are in `HANDOFF.md` "Session of 2026-08-17 (second)" §1 and
[RESULTS-layout §4.1](aif/evidence/RESULTS-layout.md): a candidate is named by hot-field count rather
than rank, the forced table must live outside `Nominal`, and the five vetoes divide into three that a
force may never clear and two that it must.

### Two things found, one fixed and one not

* **Fixed, and it is the reason the fixture exists.** An unmatched force first left `hot_count` at 0,
  so a mistyped cut turned the split *off* rather than falling back to the argmin — a warning plus a
  real measurement of a layout nothing emitted. `run_forced_layout_test` asserts this direction and is
  verified discriminating.
* **Not fixed: `tools/ir_snapshot.py` reports a false difference when anything else compiles the same
  tree.** `runWorkloadProfile`'s three temp paths are the only ones in `build_driver.c` without a pid,
  so concurrent builds of one source share `profile.txt`, and a build that reads another process's
  profile picks a different field order with no warning. It cost an hour here, presenting as
  "cold ≠ warm on exactly one program". **Run the snapshot alone**, and re-run sequentially before
  believing a one-file `test_55` difference. Mechanism, reproduction and the shape of a fix that keeps
  LAYOUT §2.2's predictable profile path: RESULTS-layout §7.

### Next, ranked

1. **§8's search loop** — compile top-`k`, run the workload on each, keep the measured winner, record
   `origin = measured` plus machine identity. Both mechanisms exist now. §8's "at `max` only" is not
   expressible: `max` was never added because it would have been byte-identical to `release`, and §8
   is the first thing that would give it content.
2. **Re-take the layout number on `g5`, not `g1`.** The `--runs 20` corpus pass ran here
   (RESULTS-xlang §0.1). **g1's run-to-run spread is 15.9%, wider than the 13% effect being hunted on
   it** — which explains the 0.958×–1.061× disagreement and means a quiet host may not be enough.
   **g5's band is 3.6% and it carries three split types**; g4's is 29.1%. Measure where the
   instrument can resolve the effect.
3. **`list_get`'s call per element.**
4. **The profile race** above.
5. **Handles.**

---

## 2026-08-17 — tasks 1 and 2 both landed, in parallel, and were merged

**Read this before either box below.** The hot/cold split (task 1) and `pin(<region-name>)` (task 2)
were built in separate trees at the same time and merged afterwards. Each box states the gate *its
own tree* passed, against a generation that **does not exist here** — `build/f2`/`build/n2` for
hot/cold, `build/p3`/`build/pc2` for pin. Neither had seen the other's change.

**The merged gate, which is the one that counts:**

| check | result |
|---|---|
| suite | **116/116** (111 + hot/cold's 2 + pin's 3), 0 failed |
| warm fixpoint | `x2 == x3` byte-identical on all 89 programs |
| cold fixpoint | `xc1 == xc2`, cold-started from the **committed** seed |
| cold == warm | byte-identical on all **89** programs |
| seed parses `src/` | yes — the committed seed cold-starts the merged tree |
| refreshed seed | regenerated from `x3`; reaches the warm fixpoint in one generation |
| oracle | agrees on **15** sources |
| IR delta vs `mg3` | **12** programs move, plus the 2 new fixtures. Pin contributes **0** — the 12 are hot/cold's, unchanged by the merge |
| `--verify` | **0 violations on all 16** ledger programs; `released` up by exactly the split-object count; `leaked` **exactly unchanged on all 6 deterministic corpus programs**, including `g1_particles`, which gained 2 000 released objects while `leaked` held at 4 |
| census | unchanged — 40 of 234 served, 2 bracketed, PLACEABLE 0 |

**Last-good generations: `build/x3` (warm) and `build/xc2` (its cold twin).** `build/mg3` /
`build/mcold2` are the pre-task-1-and-2 pair and are the ones to diff against. `build/f2`, `build/n2`,
`build/p3` and `build/pc2` were per-session and are gone.

> **On `leaked` in the xlang programs.** Those deltas run both positive and negative (−307 to +2198)
> and are noise, verified rather than assumed: four runs of `g4.psm` on **one** binary span 2 410,
> so a +2 198 single-sample delta sits inside the noise floor. The deterministic `aif/corpus/`
> programs are the ones that carry signal, and they are unchanged. Compare `released` and
> `violation(s)`; `allocated` and `leaked` remain uncomparable across runs on the timing programs.

---

> ## 2026-08-17 — task 1 is done. The hot/cold split landed, release path included.
>
> *Written by the hot/cold session, in its own tree, in parallel with the `pin(<region-name>)`
> session. Everything below this box is pre-hot/cold, and its task list is stale in exactly one
> place: **task 1 is no longer open**. Task 2 belongs to the other session. Tasks 3 and 4 stand.*
>
> `prismio` emits LAYOUT §6's hot/cold split as a **linked** split (§5.2.1) with a real release path.
> Gate, on `build/f2` (warm) and `build/n2` (cold): suite **113/113** (was 111; +`test_62`,
> +`run_split_release_test`), warm fixpoint `f2 == f3`, cold fixpoint from the committed seed
> `n2 == n3`, **cold == warm byte-identical on all 88** compilable programs, seed generation `n0`
> parses and checks `src/`, oracle agrees on **15** sources, `--verify` **0 violations everywhere**
> with `released` up by exactly the number of split objects and `leaked` unchanged on every program.
> IR moves on **12** programs plus the new fixture, characterised line by line in HANDOFF
> "Session of 2026-08-17 (hot/cold)" §6.
>
> **Read HANDOFF "Session of 2026-08-17 (hot/cold)" and RESULTS-layout §2.1–§2.3 before quoting a
> layout number.** Three things there are load-bearing and are not re-derivable from this file:
>
> * **The 0.87× did not reproduce on the corpus, and the benchmark is not the reason.**
>   `layout_repr.c` still reads 0.88× for exactly the cut the compiler emits on g1, at every size —
>   N = 2 000, 20 000 and 200 000 all read 0.87–0.89×. Four interleaved runs of the same
>   before/after pair on g1's port span **0.958×–1.061×** on a **contended host**, with the median
>   and the minimum disagreeing in sign. The number is *unresolved*, not zero. Re-take it on a quiet
>   host before anything else.
> * **The cost model chose two layouts the measurement rejected** — g3's `Node` at 1.110× and g4's
>   `World` at 1.042× — for two nameable reasons: it sizes an inline struct field as one pointer
>   (`ir_is_struct_type_name` answers 0 during the analysis), and it prices every type as if there
>   were 2^20 instances, which lets an 8-byte saving on a singleton cross a cache tier and divide its
>   modelled cost by six. Both are now vetoes; the second is written up as **LAYOUT §10.4.1**, new
>   and normative.
> * **The compiler self-hosted with its own `ASTNode` split** — warm and cold fixpoint, cold == warm,
>   113/113 — and *then* the sequential-traversal veto removed every split from `src/`. The fixpoint
>   is the evidence that the transform is sound on the hardest program in the tree; the veto is why
>   the shipping compiler does not use it on itself.
>
> **The new top item is LAYOUT §8's empirical validation**, and it is no longer blocked on anything:
> the split is emitted, so §8 needs only a way to force a candidate other than the argmin. The two
> refuted cuts above are the argument for it — both vetoes were written from measured regressions
> rather than from a search, which is what §8 exists to automate.
>
> **Last-good generations after this session:** `build/f2` (warm) and `build/n2` (its cold twin).
> `build/mg3` and `build/mcold2` are untouched and remain the pre-hot/cold pair to diff against.
> *(Superseded by the merged gate at the top of this file: `build/f2` and `build/n2` do not exist
> here; the merged pair is `build/x3` / `build/xc2`.)*

---

## Task 2 is done — `pin(<region-name>)`, 2026-08-17 (pin session)

**Item 2 of the consolidated prompt below has landed. Do not re-derive it; read `HANDOFF.md`
"Session of 2026-08-17 (pin)" and the new SPEC §5.4.5.** This section is written by that session and
covers only it — task 1 (the hot/cold split) was run in parallel in a separate tree and is not
described here.

`let pin(<region-name>) x = …` asserts that the allocation the binding denotes is served by the
arena of the `region` with that name. **It needed no grammar change**: the parser has accepted
`pin(<identifier>)` since the tier pin landed, so the two-step syntax rule never engaged. The
verdict is `aif_region_name_at_site` compared with the pinned name and nothing else — the one arena
gate, no second copy of it and no second copy of the bracket record. It is diagnostic-only and
**moves no IR**: 87 of 87 pre-existing programs byte-identical, `src/main.psm` included.

Verified on this tree: suite **114/114** (was 111), warm fixpoint `p2 == p3`, cold fixpoint
`pc1 == pc2` **from the committed seed** so the seed still parses `src/`, cold == warm byte-identical
on **88 of 88** programs, seed refreshed from `p3` afterwards and its cold start reaches the fixpoint
in one generation, oracle agrees on 15 sources, `--verify` `released`/`violation(s)` identical on all
16 corpus programs with a ledger and violations 0 everywhere, census unchanged at 40 of 234 served /
2 bracketed / PLACEABLE 0.

**Proven able to fail**, which is the whole point of it: adding a second call to a bracketed callee
inside the same region is rejected with `pin(call_arena) cannot hold: this value is not served by
that arena`, and a note naming the callee, its call-site count and the obligation.
`tests/neg_26_placement_pin_refuted.psm` is that program; `tests/test_63_placement_pin.psm` is the
one that compiles; and the runner's `placement_pin` check performs the edit on *test_63* and requires
the mutant to be rejected, because a compiler that honoured every placement pin passes the first
fixture and one that refuted every placement pin passes the second.

**One defect found and deliberately not fixed — it is now the cheapest task in this file.**
SPEC 5.4.2's UNPROVEN branch cannot fire from `prismio build`, **for the tier pin as well as this
one**, and it has been that way for four sessions:

* `--debug` is the only non-converged mode `build` offers, and its budget is zero rounds, so
  `aif_solve` returns at `if (!solve_points_to(max_rounds))` before SPEC 5's annotations are applied
  and no pin is recorded at all. `neg_25_pin_refuted.psm` builds clean at `--debug` on `build/mg3`
  too, so this is pre-existing rather than introduced.
* `--budget=N` is accepted only by the `aif` subcommand, and `aifReportPins` is called only from
  `compileSource`. The one path that can truncate the analysis is the one that never reports pins.

The unreachable branch is the *lenient* one, so pins are stricter than 5.4.2 describes rather than
weaker — which is why it was recorded instead of rushed. **Whoever takes it: build the fixture
first.** A pin that must warn-and-be-ignored needs a program the analysis genuinely cannot settle
inside the budget, and if `--budget` has to reach `build` to get one, that is a CLI change with its
own two-generation cost. `test_63_placement_pin.psm` is a ready starting shape.

Generations left behind: `build/p1`, `build/p2`, `build/p3` (warm), `build/pc0..pc2` (cold from the
committed seed), `build/pseed0..pseed1` (cold from the refreshed seed). `build/mg3` and
`build/mcold2` are untouched. `bootstrap/prismio-seed.ll` was refreshed from `p3` because the FFI
surface gained four `extern fn`s — regenerate it, never merge it, and the same goes for
`runtime/embedded_sources.h`.

---

**Both prompts have been run, in parallel, in separate trees, and merged.** Prompt 1 (arena
call-site placement) landed in full: `region` is no longer inert on `g2_region.psm`, which serves
**10 200 000 of 10 201 215** allocations against 0, measured at **0.332×** whole-program. Prompt 2
(layout) landed items 2 and 4 and **deliberately did not start item 1, the hot/cold split** — the
prize, and now the single largest piece of unbuilt work in the tree.

**Read the merged-state warning in "The last-good generation" at the foot of this file before you
quote any number.** The two sessions verified against half a tree each; only `build/mg3` has seen
both changes, and the per-session generations they name (`build/v4`, `build/M4`) do not exist here.

Everything left from both prompts is consolidated into the single prompt below. The two residual
prompts further down are kept because they carry worked-out designs that **must not be re-derived**
— but their "state inherited" paragraphs are pre-merge and are superseded by this one.

---

# The prompt for the next session

Copy the block below.

---

Continue the Prismio work. Read, and do not re-derive: `HANDOFF.md` from "Session of 2026-08-16
(second)" and "Session of 2026-08-16 (layout)", `aif/evidence/RESULTS-arena.md` §9,
`aif/evidence/RESULTS-layout.md` §2 and §5, **SPEC 5.2.1.1** and **LAYOUT §5.2.1**. The two residual
prompts in `NEXT-SESSION.md` carry the designs for tasks 1 and 2 below in full.

**Run the tools before reading source, and against `build/mg3`** — not `build/v4`, not `build/M4`,
neither of which exists, and not either tool's own default, which are stale (`build/gen2`) or absent
(`build/aif2.exe`). Two sessions have now opened against a stale binary and misread the result.

```bash
python3 aif/evidence/arena_census.py --compiler build/mg3      # whole corpus, two tables
build/mg3 aif <file> --why=<symbol>                            # one site, every blocker + verdict
build/mg3 aif <file> --layout                                  # ranked layout candidates per type
python3 tools/ir_snapshot.py --compiler build/mg3 --out /tmp/ir # all three program trees
```

**State inherited, all verified on the merged tree — this supersedes both residual prompts.** Suite
**111/111**; warm fixpoint `mg2 == mg3`; cold fixpoint `mcold1 == mcold2`; **cold == warm**
byte-identical on all **87** compilable programs; cold start from the committed seed works and the
seed still parses `src/`; oracle agrees on **15** sources; `--verify` `released`/`violation(s)`
identical to the pre-merge baseline on every corpus program except `g2_region` (which falls by
exactly 10 200 000, because `arena_alloc` bypasses the ledger by design), with **0** violations
everywhere. Census: 40 of 234 sites arena-served, 2 by a bracketed call, **PLACEABLE 0**.

## The tasks, ranked

1. **DONE 2026-08-17 — see the box at the top of this file.** *(Original text kept below because its
   design notes were correct and were used as written; only its status is stale.)*
   **The hot/cold split — the prize, and the reason this session exists.** Measured **0.87×** on g1's
   shape, and the cost model independently selects exactly that cut (`split 8/12`). *Do the release
   half or don't start* — the failure mode is a leak on the good path and a double free on the bad
   one. The residual prompt "Prompt 2 (residual)" below has the four worked-out pieces: the transform
   is contained at `ir_struct_field_ptr`, the release half is one clause (force `aif_type_releases(T)`
   for split `T`), T3's fix has room already in `RC_HDR`'s spare word, and field 0 stays hot.
   **Expect the self-host to be the hard part**: 13 of 16 types in `src/` have an admissible cut,
   `ASTNode` among them, so the first splitting generation is a compiler whose own AST is split.
   Budget a seed refresh and a cold start, and keep `build/mg3` and `build/mcold2` untouched — a
   broken compiler can be unable to build the fix to its own bug.

2. ~~**`pin(<region-name>)`.**~~ **DONE, 2026-08-17 (pin session)** — see the section at the top of
   this file and `HANDOFF.md` "Session of 2026-08-17 (pin)". What replaces it, and it is smaller:
   **SPEC 5.4.2's UNPROVEN branch cannot fire from `prismio build`, for the tier pin as well as the
   new placement pin.** Diagnosed, not fixed; the top section says why and what a fixture for it has
   to look like.

3. **The footprint estimate for bracketed sites.** `peak-bytes` and the `pin(N)` gate now count
   bracketed sites, but the weight is a product of two *intra*-procedural loop-depth estimates:
   `g2_region.psm` reports 6 144 bytes where the arena holds ~12 KB per frame. Right order, known
   bias, and it was 0 before, which was flatly wrong. A cross-function trip-count estimator is the
   real fix.

4. **The corpus re-measurement that was never run.** `bench.py --runs 20` has not been run since the
   harness's allocation accounting was fixed. Do it once task 1 lands, so the number covers the
   change with a measured prize attached. Interleaved, not back to back (RESULTS-arena §6).

## Verify, in this order

* Two generations before judging. A `.psm` change takes effect in the generation after next; a
  `runtime/*.c` change is compiled fresh into every generation. **Do not run the suite while editing
  `runtime/*.c`** — `prismio build` compiles the runtime into every program, and a run that straddles
  an edit produces phantom failures.
* Fixpoint warm and cold, cold == warm, full suite (**111/111**).
* IR for every program in `tests/`, `aif/corpus/` **and** `aif/evidence/` — `tools/ir_snapshot.py`
  walks all three in one command. Task 1 *should* move IR, so characterise the delta line by line.
* `--verify` on every corpus program, comparing **`released` and `violation(s)` only**. A split
  object is two allocations, so this is the check that catches a leaked cold block — and `allocated`
  will move legitimately, which is why it is not compared.
* Seed refresh + cold start if the FFI surface moves at all. For task 1 assume it does.
* `test_61_layout_cost_model.psm` asserts the manifest still reports AoS. **That assertion is the one
  task 1 deliberately changes** — rewrite it and its header when the split lands, the way
  `test_58_region_serves.psm` was rewritten when placement landed.

## Carry forward

* **Read the whole gate, not the clause that explained last time.** `--why`, `--layout` and
  `arena_census.py` exist so the seventh session cannot repeat it; use them, against a current binary.
* **A check that cannot fail is the defect this project produces most**, and it has now happened in
  the *measuring* code as well as the compiler: the `--verify` ledger prints `N released`, a
  comparison script asked for `released N`, and it reported all 45 programs "identical" while
  matching nothing on any of them. Assert that your instrument matched something.
* **A fixture must be built to discriminate, and where it cannot, say so.** `test_60` catches one of
  the two ways to get the placement teardown wrong and passes on the other; its header states which.
* **A timing number taken on a contended host is worth re-taking, not discarding.** The placement win
  first read 0.263× while another job ran, and 0.332× on a quiet host over 20 interleaved pairs —
  directionally right, quantitatively wrong, which is the usual shape.
* **A generated file merges cleanly and is still wrong.** `runtime/embedded_sources.h` took a clean
  three-way merge whose output did not match what `generate_embedded_sources.py` produces from the
  merged sources. Regenerate generated files; never merge them.
* Price the experiment before building the feature.
* An annotation that does nothing is worse than no annotation.

## Not this session

Incrementality, generics, concurrency. Bit-packing — LAYOUT §2.1 and §3.2's W4 still contradict each
other and that is a specification question, not an implementation one. SPEC 5.2.1.1 regime (b)
(specialisation) is ranked behind all four above; `br-shared` is the dominant blocker (102 of the
function-level counts) and is the only one that is a restriction rather than a soundness obligation,
so it is the next real feature after these — measure `br_shared` against "called from a region at
all" before building it.

---

# Prompt 1 is done — what it unblocked

## What landed, so it is not re-derived

* **Call-site placement (SPEC 5.2.1.1, regime (a)).** A call inside a `region` is bracketed when its
  callee clears the obligations and has exactly one call site; every allocation in the extent is
  then served by the caller's arena. `aif_support.c`'s `bracket_place` decides it,
  `site_arena_scope_full` applies it, and **no codegen changed** — the arena is on a dynamic stack,
  so `region`'s existing `arena_push`/`arena_pop` is the bracket and the two existing hooks
  (`ir_alloc_region`, `ir_arena_hint_begin/end`) route each site.
* **Obligation 3 comes from the points-to graph, never from `E`.** Every site in an extent has
  `E = Caller` by construction, so `E` cannot separate the sound case from the unsound one.
* **`region_confined`** — the piece the previous session's write-up did not have. A function joins
  when *every* call site of it is inside the region; without it `submit(cmds)` rejects
  `g2_region.psm` itself, because the walk binds a parameter to a local of the same name.
* **A list records which arena it came from, as a depth.** Needed for `is_list`; a flag is wrong
  under a nested `region`. SPEC 5.2.1.1 (c) supplementing (a).

## Next, ranked

1. **`pin(<region-name>)`.** This is the one the previous session deferred until placement landed,
   and it has landed. A `region` that serves something is now worth pinning: the failure mode it
   guards is real, because regime (a) means **a second call to a bracketed callee silently removes
   the placement**. The manifest records every bracket for exactly that reason — turn that record
   into an assertion a build can fail on.
2. **SPEC 5.2.1.1 regime (b), specialisation.** `br-shared` is the dominant blocker in every corpus
   program (102 of the function-level counts), and it is the only one that is a *restriction* rather
   than a soundness obligation. Measure before building: the census's `br_shared` column is the
   population, and the question is how many of those functions are called from a region at all.
3. **The footprint estimate for bracketed sites.** `peak-bytes` and the `pin(N)` gate now count
   them, but the weight is a product of two intra-procedural loop-depth estimates —
   `g2_region.psm` reports 6144 bytes where the arena holds ~12 KB per frame. Right order, known
   bias, and it was 0 before. A cross-function trip-count estimator is the real fix.

## Carry forward

* Read the whole gate, not the clause that explained last time. `--why` and `arena_census.py` exist
  so the sixth session cannot repeat it; use them, and against a current binary.
* **A check that cannot fail is the defect this project produces most**, and it happened again this
  session in the *measuring* code rather than the compiler: the `--verify` ledger prints
  `N released`, a comparison script asked for `released N`, and it reported all 45 programs
  "identical" while matching nothing on any of them. Both halves of the lesson apply — assert that
  your instrument matched something, and re-read the output format rather than the previous script.
* **A fixture must be built to discriminate, and where it cannot, say so.** `test_60` catches one of
  the two ways to get the placement teardown wrong and passes on the other; its header states which
  and why, instead of implying it covers both.
* Price the experiment before building the feature.
* An annotation that does nothing is worse than no annotation.

## Not this session

Layout (prompt 2), incrementality, generics, concurrency.

---

# Prompt 2 — layout

**Prompt 2 has been run (2026-08-16, layout session).** Items 2 and 4 landed and were verified;
**item 1, the hot/cold split, did not land and was deliberately not started** — see HANDOFF "Session
of 2026-08-16 (layout)" §4 for why, and for the release-path design it worked out, which must not be
re-derived. Item 3 stays blocked, now on one thing instead of two. The residual prompt is below,
rewritten down to what is left; the original follows it unchanged for reference.

---

# Prompt 2 (residual) — the hot/cold split, and only that

Copy the block below.

---

Continue the Prismio work. Read, and do not re-derive: `HANDOFF.md` from "Session of 2026-08-16
(layout)" (especially §3 and §4), `aif/evidence/RESULTS-layout.md` §2 and §5, and **LAYOUT §5.2.1**,
which is new and normative.

**Run the tool before reading source.** `prismio aif <file> --layout` prints LAYOUT §7.2's ranked
candidate set for every type in the program — the cut, the hot/cold byte split, and the modelled
cost against not splitting. The cost model is in and is *reported only*; nothing emits a split.

```bash
build/<gen> aif aif/corpus/g1_particles.psm --layout
python3 aif/evidence/xlang/bench.py --compiler build/<gen> --runs 20
clang -O2 aif/evidence/bench/layout_repr.c -o build/layout_repr && ./build/layout_repr
```

> **Superseded — do not quote these numbers.** This paragraph records the *layout tree before the
> merge* (suite 110/110, 89 programs, 46 ledgers, `build/M4`). The merged tree reads 111/111 over 87
> programs against `build/mg3`; see "The prompt for the next session" at the top of this file. The
> technical content below it is current; only the state line is not.

**State inherited, all verified.** Suite 110/110, fixpoint warm and cold, cold == warm, oracle agrees
on 15 sources, cold start from the committed seed works, seed still parses `src/`, IR byte-identical
on all 89 compilable programs, `--verify` identical on `released`/`violations` across all 46 programs
with a ledger.

**The measurement and the cut, already done — do not re-derive.** `layout_repr.c` variant B measures
**0.87×** on g1's shape. The cost model, restricted to what codegen can emit, independently selects
**exactly that cut** (`split 8/12`, hot 72 B / cold 32 B). The naive "cut at the first frequency
boundary" rule selects 2/12 and is badly wrong; `tests/test_61_layout_cost_model.psm` asserts the
difference and is verified discriminating.

## The one task

**Emit the split, with its release path.** *Do the release half or don't start* — the failure mode is
a leak on the good path and a double free on the bad one. Four things are worked out in HANDOFF §4
and must not be re-derived:

1. **The transform is contained.** `ir_struct_field_ptr` is the single choke point for field access
   and all five allocator hooks are backend functions, so redirection and dual allocation are ~200
   lines of C in `runtime/llvm-api-backend.c`. The five `.psm` call sites need no change.
2. **The release half is one clause.** Force `aif_type_releases(T)` true for any split `T`. Every
   drop then routes through the generated `__aif_release_T`, and the type-blind `ir_free_object`
   never sees a split object. That is the "generated release even when the type owns no fields"
   the original brief names.
3. **T3 is where it cracks, and the fix has room already.** `rc_release` frees one block and cannot
   name the type. `RC_HDR` is 16 bytes with 8 in use — put the **cold-block offset** in the spare
   word at `rc_alloc`, and `rc_release` frees the cold pointer before the base. No function pointer,
   no extra call. `cyc_alloc` already carries a per-type release and `list_release` already has the
   element type, so those two need nothing.
4. **Field 0 stays hot, and the split must not read AIF.** The punned-slot invariant (`test_41`) is
   about the first byte of the object; `aif_layout_select` already runs before the solve so that a
   layout cannot differ between `--debug` and release (SPEC 7.2, `test_49`'s note).

**Expect the self-host to be the hard part.** 13 of 16 types in `src/` have an admissible cut,
`ASTNode` among them. The first generation that emits splits is a compiler whose own AST is split.
Budget a seed refresh and a cold start, and keep `build/` known-good generations — a broken compiler
can be unable to build the fix to its own bug.

**Then measure.** `bench.py --runs 20`, interleaved (RESULTS-arena §6). g1 is the program with the
measured prize; the others should move little. Update RESULTS-layout §2.

## Verify, in this order

* Two generations before judging. A `.psm` change takes effect in the generation after next; a
  `runtime/*.c` change is compiled fresh into every generation. **Do not run the suite while editing
  `runtime/*.c`** — `prismio build` compiles the runtime into every program, and a run that straddles
  an edit produces phantom failures (HANDOFF §6).
* Fixpoint warm and cold, cold == warm, full suite (**111/111** on the merged tree; this line read
  110/110 pre-merge).
* IR for every program in `tests/`, `aif/corpus/` **and** `aif/evidence/`. This task *should* move
  IR, so characterise the delta rather than observing it.
* `--verify` on every corpus program, comparing **`released` and `violation(s)` only**. A split
  object is two allocations, so this is the check that catches a leaked cold block — and `allocated`
  will move legitimately, which is why it is not compared.
* Seed refresh + cold start if the FFI surface moves at all.
* `test_61_layout_cost_model.psm` asserts the manifest still reports AoS. **That assertion is the one
  you are deliberately changing** — rewrite it and its header when the split lands, the way
  `test_58_region_serves.psm` is written to be changed on purpose.

## Not this session

Incrementality, generics, concurrency. Bit-packing — LAYOUT §2.1 and §3.2's W4 still contradict each
other and that is a specification question. Handles, unless you are choosing them over this.

---

# Prompt 2 (original, for reference)

Runs after prompt 1, or before it if you would rather have the measured 0.87x first. Not blocked on
prompt 1.

---

Continue the Prismio work. Read `HANDOFF.md` — start at "Session of 2026-08-14" — and
`aif/evidence/RESULTS-layout.md`. Don't re-derive what's in them.

**Three corrections to inherit before you plan anything.**

- **Handles have not landed.** Three consecutive briefs have opened by saying they did.
  `ptr_to_node` in `runtime/lang_runtime.c` is still `return ptr` and there is no handle table.
  The check takes ten seconds; do it rather than trusting this paragraph either.
- **Build HEAD before reading it.** Twice now the committed tree has not compiled — eaten spaces
  from a rename, then a stray `/* */` in a language with no block comments. Both would have been
  caught by CI's first step, and neither was caught by anything local.
- **The container element-release path may not have changed, so check rather than assume.** The
  2026-08-14 session was scheduled to land the `CallerRegion` + container-disposition pair and
  deliberately did not: it measured the gate and found the pair buys **zero sites on every program
  in the tree**, because a third gate, `enclosing_region`, rejects every one of them and neither
  half touches it (HANDOFF §1; SPEC §5.2.1). Prompt 1 builds the real fix and *does* change that
  path — so if prompt 1 has run, read what it left. **Nothing in the plan below depends on it
  either way**; plan the release half from scratch as item 1 describes.

State: suite 106/106, fixpoint holds warm and cold, cold == warm, the oracle agrees on 14 sources,
the committed seed still parses `src/`, and 82 of 85 compilable programs in `tests/`, `aif/corpus/`
**and** `aif/evidence/` differ only by one added `declare` — the other three additionally lose an
`arena_push`/`arena_pop` pair for an arena that served nothing, which is the fix, not a regression.
`workload` (LAYOUT 3) is built and measured.

**Two tools landed that you should use before reading source.**
`prismio aif --why=<symbol>` now explains *placement* as well as tier, and lists **every** clause
that rejected a site rather than the first — the short-circuit is what sent two sessions to the wrong
work. `python3 aif/evidence/arena_census.py --compiler build/<gen>` answers the same question over
the whole corpus in 1.4 s. If you are about to reason about where a value lives, run one of them.

1. **The hot/cold split.** The one LAYOUT 6 dimension that is emittable today and pays: **0.87×**
   measured on g1's shape, with no missing mechanism, because the cold block hangs off the hot
   record so one pointer still reaches the object. `aif/evidence/bench/layout_repr.c` is the
   measurement and re-runs in one command.

   The whole risk is release, and it is nameable rather than vague. A split object is *two*
   allocations, so: all five allocator hooks must allocate both and wire the pointer; the type needs
   a generated `__aif_release_T` even when it owns no fields, or the cold block leaks; every free
   must route through it; `--verify`'s accounting must see both halves or every split object reads
   as a violation. **T3 is where it cracks** — `rc_release` frees one block and cannot name the
   type, which is the same shape as the problem `cyc_set_type` solves by telling the object its type
   at construction. Do the release half or don't start: the failure mode is a leak on the good path
   and a double free on the bad one.

   Two constraints that are not obvious. Field 0 must stay in the hot group — the punned-slot
   invariant (`test_41`) is about the first byte of the object, and a cut by frequency rank would
   happily put a never-read field there. And the split must not read AIF: `test_49`'s note records
   why a layout that differed between `--debug` and a release build would break SPEC 7.2, and
   `aif_layout_select` already runs before the solve for that reason.

2. **Port LAYOUT 5's cost model** from `aif/prototype/layout.py`. It is the precondition for three
   things at once: §7.2 as actually written (`argmin over candidates(τ) of Cost(…)` — the compiler
   has no cost function and enumerates no candidates, it runs one greedy placement), §8's "top-`k`
   ranked by modelled cost", and choosing a hot/cold cut by anything better than the frequency
   ranks. Note the defect `layout.py` already records at `traversal_cost`: LAYOUT 5.4 subtracts
   SimdCredit from a sum of memory costs, which lets the total go negative.

3. **LAYOUT 8's empirical validation** follows item 2 and nothing else — the build-time
   instrumented compile-link-run it needs is `workload`, and that is done. It is `compiler_run_workload`
   plus a way to force a candidate layout.

4. **Fix the harness's allocation accounting before quoting it.** `aif/evidence/xlang/bench.py`
   counts allocations for the whole process but times only the frame loop, and commit `901b494`
   moved the corpus's reporting loops onto the allocating `println` overload — so g1's `allocs`
   column went 2,214 → 26,326 (4.02 per print over 6,002 prints) with the timing untouched. The
   column is now reporting overhead, not workload behaviour.

5. **Then re-measure.** `python3 aif/evidence/xlang/bench.py --compiler build/<gen> --runs 20`.
   Hot/cold is the first layout change with a measured prize attached, so it is the first one whose
   effect on the corpus is worth a number rather than a projection.

NOT this session: incrementality, generics, concurrency. And **do not write the bit-packing
transform** — LAYOUT 2.1 and 3.2's W4 contradict each other on it (an observed range is not a
bound), and that is a specification question, not an implementation one. The measurement is already
emitted as advice at the foot of the manifest; the upper bound if it were legal is 9.4% of struct
bytes.

Carry forward:

- **A measurement is cheaper than an argument from the cost model, and has now refuted one twice.**
  λ was provably inert against a 512-byte ceiling; hot/cold was argued to be neutral on a
  pointer-vector runtime and is 13%. `layout_repr.c` took minutes to write.
- **A fixture must be built to discriminate.** `test_55`'s first draft declared its fields in
  frequency order, so the measured and static layouts came out identical and the test passed
  without exercising anything.
- **A watchdog inherits your pipes.** The workload timeout backgrounded a `sleep` that held the
  compiler's stdout, so any caller capturing output blocked until it expired — a 60-second *floor*
  wearing a ceiling's name, surfacing as a hung suite with nothing using CPU.
- **The manifest has to describe the build.** `prismio aif` runs a declared workload for the same
  reason the `owned_collections` default had to be inverted: a reporting command that analyses a
  different program from the one `prismio build` compiles is worse than no command.
- **Read the whole gate, not the clause that explained last time.** Three consecutive sessions
  designed an arena fix against `aif_arena_at_node` and each stopped reading at the clause the
  previous failure had named. The census that finally settled it was one `getenv`-gated `fprintf`
  and two throwaway scripts.
- **A duplicated predicate is a defect while the copies still agree.** Four copies of the arena gate
  existed; three agreed, and the fourth quietly placed arenas that served nothing and inflated the
  `peak-bytes` budget number by 64 bytes on a program whose arena held zero. Nothing failed.
- **Adding a builtin is an oracle change even when no inference rule moved.** Every `extern fn` a
  source declares carries its contract in the AST, so `aif/prototype/aif.py`'s fallback tables never
  fire for it — but a *builtin* is declared by nobody, so those tables are the only place it can be
  known. `list_new_with_capacity` was added without them: the differential agreed on all 13 sources
  while any program using it disagreed by eight tiers. The check was not wrong, it was unexercised.
  `run_oracle_vocabulary_test` now compares the two produce-lists directly, and
  `tests/test_56_list_capacity.psm` is in the differential's default sources.
- **The manifest emitted records its own CI differ could not parse.** A field wider than its column
  ran into the next one, the differ ignores what it cannot parse, and `g5_asset_cache.psm`'s 14
  records read as 13 — so a tier regression on `load_material` could not have failed the gate. Fixed,
  and `run_manifest_parseable_test` now counts emitted records against parsed ones. If you add a
  column or a longer symbol scheme, that test is the one that catches you.

---
---

# The last-good generation

**`build/mg3`** (2026-08-16, the merge of the arena and layout sessions), with **`build/mcold2`**
its cold-start twin — the two produce byte-identical IR for **all 87** compilable programs, which is
what "cold == warm" means here. Keep both; a broken compiler can be unable to build the fix to its
own bug, and recovery is to build from the previous good generation. `build/t3` is the generation
before both sessions, and it is the one to diff against when asking what they changed.

> **Read this before quoting a per-session number.** The arena and layout tasks ran in parallel in
> separate trees and were merged afterwards. Their own last-good generations — arena's `build/v4`,
> layout's `build/M4` — **do not exist in this tree**, and each was verified against only half of
> what is now here. `build/mg3` is the only binary that has seen both changes. The merged gate:
> suite **111/111**, warm fixpoint `mg2 == mg3`, cold fixpoint `mcold1 == mcold2`, `cold == warm`
> on all 87 programs, seed still parses `src/`, oracle agrees on **15** sources, `--verify`
> `released`/`violation(s)` identical to `build/t3` on every corpus program **except `g2_region`**,
> which falls by exactly 10 200 000 because `arena_alloc` bypasses the ledger by design, with **0**
> violations on both sides. IR moves on exactly three programs — `g2_region.psm`, `test_58`,
> `src/main.psm` — plus the two new fixtures; the layout cost-model port is inert *in the merged
> tree*, not merely in its own.

Pass it explicitly. **Both tools default to something that will mislead you:**

| tool | its default | state |
|---|---|---|
| `aif/evidence/arena_census.py` | `build/gen2` | 2026-08-08, predates the `--why` placement section entirely |
| `tools/aif_differential.py` | `build/aif2.exe` | does not exist on this host |

The 2026-08-16 session opened by running the census against `build/gen6` and read **13 of 156 sites
with every blocker column zero** — not a result, a stale binary whose `--why` prints no placement
section for the parser to match. The census now exits non-zero when no `--why` prints a bracketing
verdict *and* when `--summary` and the manifest disagree about how many calls were bracketed; the
tier columns still have no such guard.

```bash
python3 aif/evidence/arena_census.py --compiler build/mg3
python3 tools/aif_differential.py --compiler build/mg3
cd tests && PRISMIO=../build/mg3 python3 test_runner.py     # 111/111
python3 tools/ir_snapshot.py --compiler build/mg3 --out /tmp/ir   # all three trees, for the IR diff
```

Everything under `build/` is a working artefact and none of it is committed. If the directory is
empty, cold-start from the committed seed:

```bash
bash tools/bootstrap.sh --seed --out build/gen0
bash tools/bootstrap.sh --compiler build/gen0 --out build/gen1
bash tools/bootstrap.sh --compiler build/gen1 --out build/gen2
```
