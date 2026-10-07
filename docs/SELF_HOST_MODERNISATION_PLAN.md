# Self-hosting: using the language in `src/`

`src/` is 41.7k lines of Prismio (not counting the 16.7k generated lines of
`lexer/identifier_tables.psm`), and it reads like the language of August 2026. This
is the list of what the compiler's own source does not yet use, what each item is
worth, and how each is measured before it is kept.

Counts are regex counts over comment-stripped source, taken 2026-10-02 at
`1dc470f`. They size a change; they do not prove one.

## Status at the end of 2026-10-02

Everything below is in the working tree and **uncommitted**. The full suite passes on the
final tree (512 of 512, `tools/run_suite.py` on a packaged compiler), the
compiler-checked examples in the docs pass (277), the bootstrap reaches a fixpoint from the
refreshed seed, and the IR every compiled program gets is byte-identical before and after
the refactors (the old and new compiler emit identical IR for the same input). Linux and
Windows have not been built.

| Done | What |
|---|---|
| M1 | `match` for 32 enum if-chains (+6 in `src/` and `ums/` later) |
| M5a | `isKeyword` as an array and `contains`; `reservedWords` is now a global (M12) |
| M9 | AIF scans replaced by indexes: self-build IR step 1.40 s to 0.68 s |
| M10 | LLVM targets 25 to 3: compiler 129 MB to 67 MB |
| M11 | `prismio bench` re-measures every arm, reports CPU time, refuses a stale compiler |
| M12 | constant array globals (`let words = [..]`) in sema, codegen and the backend; seed refreshed |
| Scanner | `Lexer` is an `impl` with methods, `Interpolation` is an enum, `Lexer.create` / `lex.allTokens()` |
| Parser, RelLoop, RangeLoop | 76 + 37 + 36 free functions became methods of their struct |
| M2 | 11 redeclared file/path externs replaced by `std.fs` (`Bool` results, `listModules`) |
| Compiler bug | `panic` / `unreachable` / `exit` last in a function with an owned local emitted invalid IR; fixed, test 261, six `extern fn exit` redeclarations removed |
| Input and print | `docs/INPUT_PLAN.md` items A, B, C; `std.term` styles any `Display` |

**Seed**: `../bootstrap/prismio-seed-0.1.0.ll` was refreshed twice (global arrays; the `exit` fix).
**Project host**: replaced twice with a newer generation, because the old host could not build
a source tree that needs the feature it lacks. If `prismio build` ever reports that the host
"is not runnable", it was caught mid-suite (the `ums` fixture moves it aside), or it is older
than the tree: rerun `prismio build`, or install a current generation as the host first.

**Open, in order of value**: `??` and `let-else` for `Option` / `T?` (INPUT_PLAN E); one
optional type, finishing `T?` for references (INPUT_PLAN D); the remaining `Int` modes as
enums (`Parser.implPosition`, `allowStructLit`, `RangeLoop.mode`, `RelLoop.mode`);
M3, M4, M6 and M7 as written below; `TypeInfo`'s 51 free functions.

## 1 · Where `src/` stands

| Feature | Uses in `src/` |
|---|---|
| `match` | 0 before M1 (32 chains / 238 arms converted by it) |
| `T?`, `Option<>`, `Result<>`, payload enums | 0 |
| `trait`, closure | 0 |
| `Map<>` | 2 (`sema/maps.psm`) |
| `import std.vec`, `std.fs`, `std.map` | 0 |
| `struct` | 11, plus 58 mutable globals (35 in `ir/context.psm`) |
| `impl`/`self` | only `parse/parser.psm` |
| `extern fn` | 702 (335 LLVM bindings, 200 AIF tables, ~30 symbol tables, 11 duplicating `std.fs`) |

The seed (`../bootstrap/prismio-seed-0.1.0.ll`, refreshed 2026-10-02) already parses every
construct below, so none of this waits on a seed refresh.

**Not doing:** rewriting `a.equals(b)` to `a == b` and `.concat` to `+` (decided
2026-10-02), and `std.term`, traits, closures and `Result` in the compiler (it
has no dispatch, capture or recoverable-error need they would serve).

## 2 · How a step is measured

Every step is one commit and is judged by an A/B of two compilers built from the
same seed: **A** from `HEAD`, **B** from `HEAD` plus the step. The change is
kept if it is correct and not slower or larger beyond the noise floor.

1. **Build both arms from the seed.** A in a clean worktree (copy
   `third_party/llvm-paths.json` into it, or bootstrap fails and still exits 0):

   ```bash
   git worktree add --detach "$W/head" HEAD
   (cd "$W/head" && tools/bootstrap.sh --seed --out "$W/A/gen0" \
      && tools/bootstrap.sh --compiler "$W/A/gen0" --out "$W/A/gen1")
   tools/bootstrap.sh --compiler "$W/A/gen0" --out "$W/B/gen1"   # B: the working tree
   ```

   gen0 is the seed, so both arms start from the same compiler. Name the
   binaries anything but `prismio` (it is a launcher).
2. **Fixpoint, in the IR and never the binary.** `gen1 build src/main.psm` and
   `gen2 build src/main.psm` must produce the same `.ll` for each arm.
3. **Behaviour.** `tools/ir_snapshot.py --compiler <armN>/gen1` for both arms must
   give identical directories (285 programs build today), and the 202 programs that
   do not build must fail with the same exit code and diagnostics. Then the full
   suite through `tools/run_suite.py` and `tools/aif_differential.py`.
4. **Size.** From `clang -O2 -c gen1.ll`: `.ll` bytes, `__text` bytes of
   `program.o`, and the linked binary. Diff **`program.o`**, not the linked
   binary, with `tools/fn_mnemonic_diff.py`: the link carries all of LLVM and
   `objdump` on it does not finish in two minutes.
5. **Time.** Interleaved, 15 runs per arm after two warm-ups, min and median of
   wall and CPU, with an **A/A control** (the same binary against a copy of
   itself) printed beside every result. The tasks:
   - T1: arm A's gen1 against arm B's gen1, compiling the same `src/main.psm`
     (is the *compiler* faster or slower).
   - T2: one compiler compiling A's `src/` against B's `src/` (does the *source
     form* cost the frontend anything).
   - T3: `clang -O2 -c` on each arm's compiler IR (does the backend mind).
   - T4: each compiler on `benchmarks/prismio/suite.psm` (user-program compile).
6. **Decision rule.** Keep a step when 2 and 3 pass, T1/T3/T4 sit within the A/A
   spread (about ±0.5%) or better, and `__text` does not grow by more than 0.1%.
   A step that moves a function's code must be explained by `fn_mnemonic_diff`
   before a timing is believed; layout alone has moved a program 19% on
   identical code.

The harness used for M1 lives in the session scratchpad. **Step 0** is to promote
it into `tools/` (arguments: base repo, head repo, work dir, runs) so the other
steps do not rebuild it.

## 3 · Steps

### M1 · `match` for enum if-chains: done in the working tree, uncommitted

`if (x.kind == K.A) {…}` chains on one scrutinee became `match (x.kind)`. Only
chains where the rewrite is exactly equivalent were touched: one plain
`Enum.Variant` comparison per arm, the same pure scrutinee, no duplicated
variants, and every arm of a non-final `if` ending in `return`, `break` or
`continue`. 32 chains, 238 arms, 15 files (`aif/walk`, `ast/types`, `ir/*`,
`lexer/token`, `parse/expr`, `sema/*`). Not touched: chains with `or`/`and`
conditions, arms that fall through, and `String` tests (a `match` takes no string
pattern, so `isKeyword` stays).

Measured 2026-10-02 (A = `1dc470f`, B = `1dc470f` + M1; macOS arm64):

| Check | Result |
|---|---|
| Fixpoint (gen1 IR = gen2 IR) | holds in both arms |
| IR of 285 programs (`tests/`, `aif/corpus/`, `benchmarks/prismio/`, `src/main.psm`) | byte-identical |
| 202 non-building programs | same exit code and diagnostics |
| String literals in the 15 files | unchanged |
| Compiler `.ll` | 17,562,560 → 17,507,289 B (−0.31%) |
| `program.o` `__text` | 1,095,592 → 1,095,592 B (0) |
| Linked compiler | 135,191,560 B in both |
| Functions changed | 13 of 2,218, net instruction delta 0 |

| Time (15 interleaved runs) | A/B min | A/B median | A/A control (median) |
|---|---|---|---|
| T1 compiler speed on `src/main.psm` | 0.995 | 0.993 | 1.004 |
| T2 source form, `src/` as `match` | 0.992 | 0.990 | 1.004 |
| T3 `clang -O2` on the compiler IR | 0.999 | 1.004 | 1.004 |
| T4 `benchmarks/prismio/suite.psm` | 0.999 | 0.998 | 1.004 |

**Reading.** Neutral. LLVM's `-O2` already turned these chains into switches, so
the machine code is the same size, and none of the four timings leaves the A/A
spread; T2 (the frontend reading `match` source) is about 1% quicker, which is
only just outside it. The change is for the reader. A `match` on a fieldless enum
does not check exhaustiveness, so it adds no safety either.

**Still to run before committing:** the full suite and `tools/aif_differential.py`.

### M9 · AIF arena-placement cost: done in the working tree, uncommitted

Not a style item. Profiling a self-build with `sample` (2026-10-02) put **58% of
the main thread in the AIF pass**, in `runtime/aif_support.c`, and none of M2 to M6
touches it: 297 of 755 samples in arena placement (`bracket_regime_ok` →
`cand_stmt_range` → `bracket_edge_ok_at` → `region_confined`) and 61 in
`aif_fn_may_return_param`, which codegen asks once per call site. Every one of
them was a scan of a whole table for an answer that lives in one row:

| Where | Was | Now |
|---|---|---|
| `region_confined` | one pass over all call edges per function added, per candidate edge | worklist over per-caller edge lists (same least fixpoint) |
| `bracket_site_bounded` | every key's points-to set, then every site, twice, per site | site → keys, site → owners, owners → site rows built once |
| `bracket_edge_ok_at` | every site | the sites of the extent's functions, sorted into site order |
| `aif_place_arenas`, `aif_arena_high_water` | every site against every scope | the sites of the scope's own function |
| `cand_range_compute`, `stmt_range_over` | reset, scan and key loops over every site and key | the served sites kept in a list; keys reached through the site → keys rows |
| `fn_may_return_param` and three siblings | every key in the program | the function's own PARAM keys |

Nothing about *what* is decided changed: each index lists the same entries in the
same ascending order as the scan it replaces, so the first rejection and the
`PRISMIO_AIF_BRACKET_TRACE` line that names it are the same.

Measured against arm B (M1, old C), macOS arm64, 15 interleaved runs:

| Check | Result |
|---|---|
| Cross-check build (`-DAIF_XCHECK`, new `region_confined` against the old scan) | no mismatch over 285 programs and the compiler's source |
| Fixpoint (gen1 IR = gen2 IR) | holds |
| IR of 285 programs | byte-identical |
| 202 non-building programs | same exit code and diagnostics |
| `prismio aif` report for 285 programs | identical (only a PID in a temp filename differs) |
| `tools/aif_differential.py` | identical to arm B; engine and oracle agree on 19 sources |
| Linked compiler | 135,191,560 → 135,192,776 B (+1.2 KB) |

| Time | B/C min | B/C median | A/A (median) |
|---|---|---|---|
| T1 compiling `src/main.psm` (41.7k lines) | 0.726 | 0.726 | 0.999 |
| T4 `benchmarks/prismio/suite.psm` | 0.933 | 0.954 | n/a |
| T5 `tests/test_48_aif_shared_elements.psm` (8 ms) | 0.982 | 0.982 | n/a |

**Reading.** This is the AIF pass inside `prismio build`, so it applies to every
program, but only to the front half of a build (source to IR). The scans were
quadratic in sites, scopes and edges, so the saving grows with program size: the
41.7k-line compiler's IR step is 27% quicker, the benchmark suite's 5%, and an 8 ms
program is inside the noise. A *complete* build also runs LLVM `-O3` and the link,
which dominate: `prismio bench` reports the suite's whole compile (`compile_ns`) at
855 / 854 / 857 ms for arms A / B / C, i.e. no measurable change end to end.
`binary_bytes` of the suite is 225,216 B in all three, and the compiled programs are
byte-identical, so nothing about a program's speed or size changes.

`prismio bench` is the metric source for compile time and size from here on (it
records `compile_ns` and `binary_bytes` per language beside run time and RSS); the
scratch harness above is only for the front-end-only numbers it cannot isolate.

**Second pass (same day).** Four more scans of the same kind went the same way:
`bracket_prepare`'s owner-site loop (bit iteration), `bracket_blockers_compute` and
`bracket_regime_ok` (a callee-indexed edge list instead of every edge),
`aif_place_arenas` and `aif_arena_high_water` (a scope's subtree is a contiguous
range of scope ids, checked rather than assumed, so each scope sums only its own
subtree's sites), `bracket_candidate_serves` (the function's own calls and the
extent's own sites), and `auto_arena_scope_at_node` (a node-keyed table that keeps the
first scope, as the scan returned). The cross-checks are the same as before and all
come back identical: fixpoint, IR of 285 programs, 202 failing programs, `prismio aif`
for 285 programs, `tools/aif_differential.py`, and 504 / 504 in `tools/run_suite.py`.

| Time, 15 interleaved runs, old AIF (arm B) / new | min | median | A/A (median) |
|---|---|---|---|
| T1 `src/main.psm` to IR (41.7k lines) | 0.481 | 0.481 | 1.000 |
| T4 `benchmarks/prismio/suite.psm` to IR | 0.857 | 0.853 | n/a |
| T5 an 8 ms program | 0.961 | 0.962 | n/a |

Through `prismio bench`, the suite's *whole* build (IR, LLVM `-O3`, link): 863 to
913 ms before, 835 to 837 ms after (about -5%), binary 225,216 B in both. The
self-build IR step went 1.40 s to 0.68 s; the profile is now the solver itself
(`aif_solve` and `bits_*`, 137 of 475 samples) and codegen, which is where it should be.

**Still to run before committing:** the full suite and `tools/aif_differential.py`.

### M9 · AIF arena-placement cost: done in the working tree, uncommitted

Not a style item. Profiling a self-build with `sample` (2026-10-02) put **58% of
the main thread in the AIF pass**, in `runtime/aif_support.c`, and none of M2 to M6
touches it: 297 of 755 samples in arena placement (`bracket_regime_ok` →
`cand_stmt_range` → `bracket_edge_ok_at` → `region_confined`) and 61 in
`aif_fn_may_return_param`, which codegen asks once per call site. Every one of
them was a scan of a whole table for an answer that lives in one row:

| Where | Was | Now |
|---|---|---|
| `region_confined` | one pass over all call edges per function added, per candidate edge | worklist over per-caller edge lists (same least fixpoint) |
| `bracket_site_bounded` | every key's points-to set, then every site, twice, per site | site → keys, site → owners, owners → site rows built once |
| `bracket_edge_ok_at` | every site | the sites of the extent's functions, sorted into site order |
| `aif_place_arenas`, `aif_arena_high_water` | every site against every scope | the sites of the scope's own function |
| `cand_range_compute`, `stmt_range_over` | reset, scan and key loops over every site and key | the served sites kept in a list; keys reached through the site → keys rows |
| `fn_may_return_param` and three siblings | every key in the program | the function's own PARAM keys |

Nothing about *what* is decided changed: each index lists the same entries in the
same ascending order as the scan it replaces, so the first rejection and the
`PRISMIO_AIF_BRACKET_TRACE` line that names it are the same.

Measured against arm B (M1, old C), macOS arm64, 15 interleaved runs:

| Check | Result |
|---|---|
| Cross-check build (`-DAIF_XCHECK`, new `region_confined` against the old scan) | no mismatch over 285 programs and the compiler's source |
| Fixpoint (gen1 IR = gen2 IR) | holds |
| IR of 285 programs | byte-identical |
| 202 non-building programs | same exit code and diagnostics |
| `prismio aif` report for 285 programs | identical (only a PID in a temp filename differs) |
| `tools/aif_differential.py` | identical to arm B; engine and oracle agree on 19 sources |
| Linked compiler | 135,191,560 → 135,192,776 B (+1.2 KB) |

| Time | B/C min | B/C median | A/A (median) |
|---|---|---|---|
| T1 compiling `src/main.psm` (41.7k lines) | 0.726 | 0.726 | 0.999 |
| T4 `benchmarks/prismio/suite.psm` | 0.933 | 0.954 | n/a |
| T5 `tests/test_48_aif_shared_elements.psm` (8 ms) | 0.982 | 0.982 | n/a |

**Reading.** This is the AIF pass inside `prismio build`, so it applies to every
program, but only to the front half of a build (source to IR). The scans were
quadratic in sites, scopes and edges, so the saving grows with program size: the
41.7k-line compiler's IR step is 27% quicker, the benchmark suite's 5%, and an 8 ms
program is inside the noise. A *complete* build also runs LLVM `-O3` and the link,
which dominate: `prismio bench` reports the suite's whole compile (`compile_ns`) at
855 / 854 / 857 ms for arms A / B / C, i.e. no measurable change end to end.
`binary_bytes` of the suite is 225,216 B in all three, and the compiled programs are
byte-identical, so nothing about a program's speed or size changes.

`prismio bench` is the metric source for compile time and size from here on (it
records `compile_ns` and `binary_bytes` per language beside run time and RSS); the
scratch harness above is only for the front-end-only numbers it cannot isolate.

**Left in the profile** (about 580 samples now, from 755): `aif_place_arenas` itself
(126), `aif_auto_arena_at_node` (53), `bracket_blockers_compute` (53, once per
distinct callee: walk the closure's bits and a per-callee edge list instead of all
functions and all edges) and `bits_to_vec` (42). The next pass starts there.

**Still to run before committing:** the full suite (`tools/run_suite.py` on a
packaged toolchain) and the Linux and Windows builds, since `aif_support.c` is
shared C.

### M10 · Link three LLVM targets, not 25: done in the working tree, uncommitted

The compiler was 125 to 135 MB and about 5% of that is Prismio. `tools/setup_llvm.py`
linked LLVM's `all-targets`, 25 backends. Decided 2026-10-02: keep AArch64, X86 and
WebAssembly, the three the documentation names. `--target` now accepts only those
families; any other triple stops with `P1043 unknown target triple`, which is also a
clearer message than the "installation is incomplete" it gave before.

What changed: `PRISMIO_LLVM_TARGET_LIST` in `runtime/prismio_llvm.h` (what the
backend initialises, replacing `LLVMInitializeAll*`), `TARGET_COMPONENTS` in
`tools/setup_llvm.py` (what is linked), a check that the two agree in
`tools/check_source_lists.py`, the `docs/KNOWN_ISSUES.md` entry, and a "Which targets
`--target` accepts" section in the website's `compiler/targets.md`.

| | Before | After |
|---|---|---|
| Compiler | 128.9 MB | 67.1 MB (-48%) |
| LLVM libraries linked | 172 | 87 |
| Benchmark suite binary (`prismio bench`) | 225,216 B | 225,216 B |
| Suite compile, 9 alternating runs, median | 864 ms | 860 ms |
| `prismio bench`, 62 workloads, geomean vs C++ / Rust | 0.84x / 0.82x | 0.85x / 0.82x (identical code; noise) |
| Full suite (`tools/run_suite.py` on the packaged compiler) | | 504 / 504 |

The 80.2 MB alternative (keeping 32-bit ARM and RISC-V as well) was also measured and
is not taken. To bring a target back: both lists, `default_target_cpu`, the docs.

Applying it to an existing checkout: `third_party/llvm` prepared before this change
is redone by the next `tools/setup_llvm.py` run (the marker records the component
list), and that downloads LLVM again. The working tree here had its `link.rsp` and
marker edited to the same result instead, to avoid the download.

**Not run:** the Linux and Windows builds. `link.rsp` is generated per platform, and
Windows links `LLVM-C.lib`, so confirm the Windows CI leg before committing.

### M11 · `prismio bench` must not report stale numbers: done in the working tree, uncommitted

Found 2026-10-02 while checking a report that read Prismio 1.02 s, C++ 2.88 s, Rust
3.58 s. The C++ and Rust figures were stamps from the previous evening (one build
each, shown as "cached" only in the JSON), set beside a fresh Prismio figure. Re-measured
in the bench's own configuration, interleaved, median of 5 to 7:

| | wall | CPU |
|---|---|---|
| Prismio | 0.83 s | 1.51 s |
| C++20 (`clang++ -O3 -flto`) | 2.00 s | 2.02 s |
| Rust (`-C opt-level=3 -C lto=fat -C codegen-units=1`) | 2.60 s | 2.64 s |

Prismio's backend is multi-threaded and the other two are not, so the wall ratios
(2.4x and 3.1x) credit it with cores the others never used; by CPU time it is 1.3x
and 1.7x. Both are reported now. The project host measures about 6% slower than a
release-built compiler (0.88 s against 0.83 s), which is the "debug build" the README
already warns about, and the 1.02 s was probably the host from before the AIF changes.

Changes in `benchmarks/run.py` and `templates/report.html`: every arm is rebuilt and
timed on every run (`--reuse-reference-builds` restores the old cache and then labels
what it reused, with the date); CPU time beside wall time; `--compile-runs N` for a
median of N builds; the run refuses to measure the project compiler if `src/`, `std/`
or `runtime/` is newer than it (`--allow-stale-compiler` overrides); the report records
which compiler it measured and whether `--skip-build` left old executables (which also
warns on stderr); the HTML card states all of this. `benchmarks/README.md` documents it.

### Binary size: where it goes

*Compiler (67 MB after M10).* `__TEXT,__text` is 53 MB and `__const` 56 MB, almost all
LLVM; the Prismio code is 2.2 MB of object. Further levers, none taken: `-dead_strip`
already runs; the remaining mass is LLVM's own code and tables, so the next real step
is a smaller LLVM (fewer passes, `libLLVM` without the JIT and Orc components the
compiler links for `run --jit`).

*User programs* (the benchmark suite, 225 KB against C++ 154 KB and Rust 611 KB).
`__text` is 172,744 B: runtime 11.6 KB, the rest the program's own functions and the
std generics it instantiates (two `listSortRange` specialisations are 16 KB; `main` is
7 KB). Re-running the optimiser on the merged module shows what the 1.9x over C++
is: no unrolling is -12%, no vectorisation -10%, neither -21%, `-Os` -18%, `-Oz` -24%.
So it is the performance-first `-O3` pipeline, not runtime bloat or missing dead-code
removal. `-O1` and `-O2` produce larger binaries than the default, because the driver
runs the same pipeline either way. A size-oriented build mode (unroll and vectorise
off, or `-Os`) would be a flag for people who want it, not a default.

### M2 · Take the redeclared externs from `std.fs`

`src/` redeclares 11 externs that `std/fs.psm` already declares: `read_file`,
`file_exists`, `write_file`, `delete_file`, `join_path`, `make_directory`,
`directory_exists`, `current_directory`, `executable_directory`, `get_directory`,
`list_modules` (in `driver/compile.psm`, `driver/imports.psm`, `main.psm`,
`project/host.psm`, `project/ums_cli.psm`). CLAUDE.md says an application uses
`std.*`, and the ownership contract (`produce(free)`, `borrow`) is then declared
once. Cost to watch: `std.fs` pulls its own imports into the compiler, so check
the `.ll` size and the AIF site count as well as the timings. Expected IR: identical
program output, a different compiler.

### M3 · Booleans as `Bool`

`Parser.allowStructLit: Int`, eight `let mut found = 0` style flags, and externs
that take `isConst: Int` / `isBorrow: Int` / `isOptimized: Int` become `Bool`. The
~326 `ext() == 0` / `== 1` tests on extern predicates (`ir_has_returned() == 0`)
get one `Bool` wrapper each instead of repeating the comparison. An extern
keeps returning `Int` (the C ABI), the wrapper is what changes.

### M4 · `T?` where a sentinel stands in for absence

136 `return ""`, nine index functions returning `-1` (`monoParamIndex`,
`enumVariantTag`, `aifHumanSiteAtId`, `aifHumanIdOf`, `listElementArgIndex`,
`visibilityLevel`, …), and `Parser.implType: Ptr` whose comment says "or null".
A scalar `T?` is a flag beside the value and allocates nothing, so this should
not move the binary; confirm it with the A/B. A `String?` is a nullable pointer.
Do the index functions first: they are the clearest and have the fewest callers.

### M5 · `std.vec` in place of hand-rolled search loops

`irStringListContains`, `irHoldersContain`, `stringDispatchLengthSeen`,
`stringDispatchByteSeen`, `identifierIndex` and the like become `.contains` /
`.indexOf`. `src/` never imports `std.vec`, so check what the import costs in AIF
sites first (see the `std.io` → `std.string` precedent: 5 sites became 85).

### M5a · `isKeyword` as an array and `contains`: done in the working tree, uncommitted

`src/lexer/token.psm`: the 31-way chain of `word.equals("...")` is a list of the
words and `keywords.contains(word)`, with the explanatory comments kept beside the
words they explain. Measured (arm H = before, K = after): IR of every test, corpus and
benchmark program identical; fixpoint holds; compiler `.ll` 17,507,523 to 17,476,511 B;
`__text` 1,095,592 to 1,094,728 B; `isKeyword` 494 to 161 instructions (plus the two
shared `contains` / `indexOf` instantiations); self-compile to IR 0.998 / 0.999
(A/A 0.994), i.e. no change in speed. The comment on the old code said a table would
allocate on the hottest path; an array of literals does not.

It is a local array, rebuilt per call. A module-level one is the better shape and is
refused: `error[P4001]: global needs a constant initializer`. See M12.

### M12 · Constant aggregate globals: language gap, not started

`variables.md` says a global initializer "must be a static literal value supported by
the compiler". Scalars and a `String` literal are supported; an array of literals, a
`Vec`, a struct literal and `[]` are not (all hit P4001). LLVM can emit a constant
aggregate directly, so this is the compiler not lowering one, not a rule of the
language. It would let `isKeyword`'s list, the operator tables and the AIF rule tables
in `src/` be read-only data built once, not stores on entry. Work: sema accepts an
array or struct literal of constants as a global initializer (and rejects a mutable
one that is not scalar until ownership of a global aggregate is decided), codegen
emits an LLVM constant, tests, docs. It is new syntax-adjacent behaviour, so the usual
two steps apply: compiler first, seed refresh, then use it in `src/`.

### M6 · The AST walks as an iterator: experiment, not a commitment

288 `while (nodeExists(p))` loops over `next` chains were left as `while` in
043bc2e because an iterator adds a call per step to the hottest loops. Try one
`Iterator` over a `next` chain in one hot walk (`ir/expr.psm`) and keep it only if
`fn_mnemonic_diff` shows the loop body unchanged and T1 does not move. If the call
does not inline, close this item with the measurement.

### M7 · Move the compiler's C containers into Prismio: needs its own design first

`runtime/aif_support.c` (8.5k lines) and `runtime/ir_symbols.c` (1.6k) exist, by
their own header comments, because "Prismio has no generics, no maps and no
growable vectors". All three exist now. About 230 of `src/`'s externs
(`aif/model.psm` 200, `ir/context.psm` 29) reach these tables.

Constraints to settle in the design, not here:

- a `Map` cannot hold an owned value yet, which blocks the symbol tables whose
  entries are owned structs;
- the solver loop is on the compile-time path, so T1 decides each piece;
- parallel codegen reads these tables from several threads;
- `tools/aif_differential.py` plus `--verify` are the oracle, and the AIF engine
  must give the same manifests.

Deliverable of this item is `docs/` text choosing the order (symbol tables
before the solver) and the exit test, not code. Update the stale header comments
in both C files in the same commit as the first port.

### M8 · The AST as raw `Ptr`: parked

About 2,950 uses of `ptr_to_node` / `node_to_ptr` / `nodeExists` / `nodeIsNull`,
and `ASTNode` carrying `s1`/`s2`/`i1`/`i2`/`i3` whose meaning depends on `kind`.
`ASTNode?` fields would make a parent own its children, but sema rewrites
re-parent subtrees (`keys.child1 = node.child1` in `sema/maps.psm`) and there is
no borrowed or weak field reference (`lifetimes.md` is a stub). Revisit when the
language has one. Do not start on typed accessors in the meantime: they would
churn every file for no change in what the compiler can express.

### Left as it is

The 335 LLVM bindings in `ir/bridge.psm` and `runtime/llvm-api-backend.c` are
FFI to the LLVM C API and stay. The module-level mutable globals in
`ir/context.psm` are not a defect to fix on their own.

## 4 · Order

M1, M9 and M10 (suite is green on all three together; commit separately, and see M9 and M10 for the Linux and Windows legs still to check) → Step 0 (harness into
`tools/`) → M3 → M2 → M4 → M5 → M6 experiment → M7 design. Each is its own commit
with its A/B table in the message. M8 waits for the language. M2 to M6 are for the
reader and are not expected to move a timing; M9 is the one that does.
