# Graph Report - prismio  (2026-08-17)

## Corpus Check
- 123 files · ~364,868 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2523 nodes · 4539 edges · 178 communities (170 shown, 8 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 321 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `63c132b3`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- malloc
- fn compile_source(path, output_file, run_after_build) -> Int
- g6_bench.c
- ir_symbols.c
- free
- lang_runtime.c
- SECURITY.md
- Borrow Checking
- Prismio — Compiler Audit
- use_globals() function
- g2_bench_arena.c
- bench.py
- ir_intern
- setup_llvm.py
- arena_would_serve
- cyc_hdr
- While Loops
- 1. Language core
- Function Overloading
- main
- main
- generate_embedded_sources.py
- llvm-api-backend.c
- Enum Types
- main
- layout.py
- diagnostics.c
- test_runner.py
- check_source_lists.py
- main() function (test_09_strings)
- compile(input_size)
- bad_value() function (neg_01_type_mismatch)
- Prismio — Compiler Status
- Prismio — Bootstrap & Runtime-Linking Architecture Audit
- World
- main
- Struct (Custom Data Type) Declarations
- aif_tier_of
- main() function (test_07_booleans)
- main() function (test_02_if_else)
- main
- fibonacci(n) function
- main() function (test_11_returns)
- aif_support.c
- main
- Prismio Toolchain Architecture Refactor — Session Handoff
- add_binding
- g2_bench.c
- strcmp
- strlen
- The G2 / G6 benchmark set
- g5_tuned.rs
- g5_idiomatic.rs
- bench.py
- World
- g3.swift
- g4.swift
- strncpy
- g4_idiomatic.rs
- g3_tuned.rs
- g3_idiomatic.rs
- Building Prismio on macOS (and Linux)
- Cross-language results — Prismio vs Rust vs Swift
- g4_tuned.rs
- The cross-language suite — Prismio vs Rust vs Swift
- g1_arena.rs
- struct Counter
- struct Res
- Session of 2026-08-08 — the tree did not compile, and the T3 residue was never real
- aif_str
- Code style
- bootstrap.sh
- verify_separation.sh
- Engine
- package.sh script
- Tier 2 — required by specified AIF features
- bootstrap.ps1
- die
- AIF — Workload Declaration, Cost Model, and Layout Search
- AIF — Design Rationale
- 5 · A staged path
- 1 · AIF core — genuinely ours
- AIF — The FFI Boundary
- aif_intern
- AIF — The T4 Cycle Collector
- AIF — Measurement and Falsification Plan
- PIR — Prism Semantic IR
- aif_solve
- AIF — Level 0 Results
- AIF — The Target Workload
- AIF — Adaptive Inference Framework
- AIF — Cross-Language Comparison Suite
- AIF — Evaluation as a General-Purpose Memory Model
- AIF — Adaptive Inference Framework
- 8.4 Views — slices and element references
- aif.py
- nominal_find
- 5 · Annotations
- AIF — Layout Results (A1)
- AIF — The Inference Engine
- 4 · Transfer rules
- 5 · The fixed-point algorithm
- 7 · Specialisation strategy and dedup
- AIF — Engine/Game Boundary Results (A2)
- AIF Prototype
- 11 · Known weaknesses
- 2 · Fact domains
- 8 · Annotations as axioms and constraints
- 11 · Conformance boundary
- 3 · The tier ladder
- Model
- .solve
- AIF Evidence
- 6 · Ownership contexts
- 2 · The objects of the model
- 4 · Tier derivation
- 7 · Two-speed compilation
- g1_boxed.rs
- AIF Corpus
- 6 · The tier manifest
- Profile
- namelist_contains
- NEXT-SESSION.md
- find_binding
- aif_manifest_diff.py
- g1_idiomatic.rs
- g2_arena.rs
- g7_idiomatic.rs
- g7_owned.rs
- g1_tuned.rs
- g2_boxed.rs
- RESULTS — the string/parse axis
- g2_idiomatic.rs
- g2_tuned.rs
- Frames
- Arena placement: what `region` serves, and what stops the rest
- Handoff — continuing the Prismio work
- Session of 2026-08-09 (second) — views: the safety half landed, the speed half was somewhere else
- Session of 2026-08-08 (measurement) — the first cross-language numbers, and the optimiser was never on
- optgap.py
- RESULTS — the string/parse axis
- g7bench.py
- optlevel.py
- aif_tier_of
- Prismio IDE protocol
- Session of 2026-08-13 — `workload` lands; two of LAYOUT 6's dimensions are not blocked on what the brief said
- arena_chunk_new
- LAYOUT 6's candidate space, measured against what this compiler can emit
- The cross-language suite — Prismio vs Rust vs Swift
- arena_census.py
- Session of 2026-08-16 (second) — call-site placement lands; `region` stops being inert on g2
- Session of 2026-08-16 (layout) — the cost model lands, and it could not have ranked the cut it exists for
- Session of 2026-08-08 (measurement) — the first cross-language numbers, and the optimiser was never on
- Prompt 1 is done — what it unblocked
- str_split
- ir_snapshot.py
- 2 · Prediction vs measurement, per axis
- g2r_time.py
- 9 · The budget rule
- Session of 2026-08-17 (second) — §8's forced candidate lands, and the IR differential turns out to have a concurrency hole
- The prompt for the next session
- Prompt 1 is done — what it unblocked
- str_split
- decl_entry
- ir_slot_diff.py
- 10 · Boundaries
- backend_fail
- struct_entry
- block_done
- LLVMValueRef

## God Nodes (most connected - your core abstractions)
1. `free()` - 38 edges
2. `strlen()` - 37 edges
3. `main()` - 37 edges
4. `malloc()` - 34 edges
5. `intern_value()` - 33 edges
6. `type_from_key()` - 32 edges
7. `resolve_value()` - 32 edges
8. `aif_intern()` - 31 edges
9. `bits_test()` - 30 edges
10. `main()` - 30 edges

## Surprising Connections (you probably didn't know these)
- `Test naming convention (test_<NN>_<description>.psm)` --conceptually_related_to--> `fn main() -> Int`  [AMBIGUOUS]
  CONTRIBUTING.md → src/main.psm
- `xcalloc()` --calls--> `calloc()`  [INFERRED]
  runtime/aif_support.c → aif/evidence/xlang/allocount.c
- `diag_reset()` --calls--> `free()`  [INFERRED]
  runtime/diagnostics.c → runtime/lang_runtime.c
- `ir_reset_fn_return_types()` --calls--> `free()`  [INFERRED]
  runtime/ir_symbols.c → runtime/lang_runtime.c
- `compare_names()` --calls--> `strcmp()`  [INFERRED]
  runtime/program_support.c → runtime/lang_runtime.c

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Negative tests validating move/drop/borrow ownership checking** — tests_neg_03_use_after_move_main, tests_neg_04_use_after_drop_main, tests_neg_05_drop_borrow_main [INFERRED 0.85]
- **Negative tests validating semantic/type checking (type mismatch, integer width, duplicate overload)** — tests_neg_01_type_mismatch_bad_value, tests_neg_02_int_width_main, tests_neg_06_duplicate_overload_same [INFERRED 0.75]
- **Shared fail(message) test-harness helper pattern across feature tests** — tests_test_01_variables_fail, tests_test_02_if_else_fail, tests_test_03_while_loops_fail, tests_test_04_structs_fail, tests_test_05_enums_fail, tests_test_06_recursion_fail, tests_test_07_booleans_fail, tests_test_08_mutability_fail, tests_test_09_strings_fail, tests_test_10_expressions_fail, tests_test_11_returns_fail, tests_test_12_imports_fail, tests_test_13_globals_fail [INFERRED 0.95]
- **Prismio Ownership System (Move/Drop/Borrow) Demonstration** — tests_test_23_move_main, tests_test_24_drop_main, tests_test_25_conventions_main, tests_test_26_borrow_reuse_main [INFERRED 0.85]

## Communities (178 total, 8 thin omitted)

### Community 0 - "malloc"
Cohesion: 0.13
Nodes (16): aif_field_access(), aif_is_enum(), aif_is_struct(), aif_layout_field_bytes(), aif_layout_hot_count(), aif_layout_no_split(), aif_layout_no_split_unmodelled(), aif_layout_reordered() (+8 more)

### Community 1 - "fn compile_source(path, output_file, run_after_build) -> Int"
Cohesion: 0.07
Nodes (30): Contributor Covenant Code of Conduct, Conventional Commits convention, Prismio Project Structure (src/ layout), Claim: no dedicated semantic analysis pass (planned), Test naming convention (test_<NN>_<description>.psm), POST_INSTALL.txt (install success message), Documented Compiler Pipeline (README architecture diagram), Contributor Covenant (README reference) (+22 more)

### Community 2 - "g6_bench.c"
Cohesion: 0.07
Nodes (67): Actor, arena_alloc(), arena_reserve(), arena_reset(), build_scene(), List, cull(), list_init() (+59 more)

### Community 3 - "ir_symbols.c"
Cohesion: 0.07
Nodes (5): drop_index(), ir_drop_kind(), ir_drop_slot(), ir_drop_type(), ir_reset_fn_return_types()

### Community 4 - "free"
Cohesion: 0.12
Nodes (45): FILE, accept_if_exists(), build_from_toolchain_sources(), compile_ir_to_object(), compiler_bootstrap_executable(), compiler_build_executable(), compiler_default_exe_path(), compiler_installed_runtime_hash() (+37 more)

### Community 5 - "lang_runtime.c"
Cohesion: 0.04
Nodes (39): RtProfField, RtProfType, aif_live_hash(), aif_verify_alloc(), aif_verify_arm(), aif_verify_release(), arena_current_slot(), arena_push() (+31 more)

### Community 7 - "Borrow Checking"
Cohesion: 0.08
Nodes (30): Borrow Checking, Drop Semantics, Move Semantics, Parameter Passing Conventions (borrow/inout/sink), Struct Types, main() function (neg_03_use_after_move), struct Point (neg_03_use_after_move), main() function (neg_04_use_after_drop) (+22 more)

### Community 8 - "Prismio — Compiler Audit"
Cohesion: 0.07
Nodes (26): 0. Headline, 1.10 MEDIUM — `%` is rejected on every sized integer type — **FIXED**, 1.11 MEDIUM — Global initializers are dropped unless they're literals — **FIXED**, 1.12 LOW — `print_bool` is declared `i32` and called with `i1` — **FIXED**, 1.1 CRITICAL — String literals inside `for` / `loop` / `match` bodies are never emitted — **FIXED**, 1.2 CRITICAL — `and` / `or` do not short-circuit — **FIXED**, 1.3 CRITICAL — No mutability enforcement whatsoever, 1.4 CRITICAL — No block scoping; locals shadowing globals read the global (+18 more)

### Community 9 - "use_globals() function"
Cohesion: 0.09
Nodes (27): Arithmetic Operators, Global Variables, Mutability (mut bindings), Operator Precedence / Expression Evaluation, Variable Declarations, bump_global(amount) function, fail(message) function (test_01_variables), main() function (test_01_variables) (+19 more)

### Community 10 - "g2_bench_arena.c"
Cohesion: 0.07
Nodes (60): buildSystem(), countAlive(), countBeyond(), fade(), G1, integrate(), Particle, spawnParticle() (+52 more)

### Community 11 - "bench.py"
Cohesion: 0.43
Nodes (7): main(), pct(), PROCESS_MEMORY_COUNTERS, Run the AIF benchmark set and report to BENCHMARKS 3.2's protocol.      python a, One run: wall milliseconds, and peak working set in MB.      The counters stay r, run_once(), suite()

### Community 12 - "ir_intern"
Cohesion: 0.19
Nodes (16): add_binding(), hash_str(), ir_get_enum_variant(), ir_get_fn_return_type(), ir_intern(), ir_register_enum_variant(), ir_register_struct(), ir_register_struct_field() (+8 more)

### Community 13 - "setup_llvm.py"
Cohesion: 0.25
Nodes (20): candidate_roots(), detect_version(), download(), extract(), fetch(), find_existing(), inspect(), lib_names() (+12 more)

### Community 14 - "arena_would_serve"
Cohesion: 0.27
Nodes (11): aif_arena_high_water(), aif_arena_unsized_sites(), aif_place_arenas(), aif_scope_served(), arena_bytes_of(), arena_would_serve(), bracket_bytes_of(), is_ancestor_or_self() (+3 more)

### Community 15 - "cyc_hdr"
Cohesion: 0.22
Nodes (14): CycHeader, cyc_alloc(), cyc_buffer(), cyc_collect(), cyc_collect_now(), cyc_collect_white(), cyc_final(), cyc_free_object() (+6 more)

### Community 16 - "While Loops"
Cohesion: 0.21
Nodes (13): While Loops, Range-Based For Loops (a..b), factorial(n) function, fail(message) function (test_03_while_loops), main() function (test_03_while_loops), sum_to_n(n) function, count_to(limit), fail(message) (+5 more)

### Community 17 - "1. Language core"
Cohesion: 0.10
Nodes (19): 1.1 Types, 1.2 Operators, 1.3 Literals and lexical, 1.4 Control flow, 1.5 Functions and abstraction, 1.6 Modules, 1.7 Memory and safety, 1. Language core (+11 more)

### Community 18 - "Function Overloading"
Cohesion: 0.27
Nodes (12): Function Overloading, main() function (neg_06_duplicate_overload), same(value: Int) function, first declaration (neg_06_duplicate_overload), same(other: Int) function, duplicate declaration (neg_06_duplicate_overload), choose(value: Float), choose(value: Int), choose(value: String), combine(left: Int, right: Int) (+4 more)

### Community 19 - "main"
Cohesion: 0.23
Nodes (12): Module Imports, Multi-Argument Function Calls, fail(message) function (test_12_imports), main() function (test_12_imports), add3(a,b,c), add4(a,b,c,d), add5(a,b,c,d,e), fail(message) (+4 more)

### Community 20 - "main"
Cohesion: 0.25
Nodes (8): Driver/Runtime Split (OS-level extern functions), extern fn command_quote_arg, extern fn executable_directory, fail(message), extern fn file_exists, extern fn join_path, main(), extern fn str_length

### Community 21 - "generate_embedded_sources.py"
Cohesion: 0.83
Nodes (3): add_c_string(), escape_c_string(), main()

### Community 22 - "llvm-api-backend.c"
Cohesion: 0.11
Nodes (20): check_llvm_version(), ensure_context(), ir_append(), ir_append_line(), ir_arena_call(), ir_arena_hint_begin(), ir_arena_hint_end(), ir_free_list() (+12 more)

### Community 23 - "Enum Types"
Cohesion: 0.24
Nodes (11): Enum Types, Pattern Matching (match expressions), enum Color, enum ExitCode, fail(message) function (test_05_enums), main() function (test_05_enums), classify(n), enum Color (+3 more)

### Community 24 - "main"
Cohesion: 0.15
Nodes (13): String Runtime (extern str_* FFI functions), fail(message), extern fn int_to_str, main(), extern fn str_char_at, extern fn str_concat, extern fn str_contains, extern fn str_equals (+5 more)

### Community 25 - "layout.py"
Cohesion: 0.26
Nodes (13): candidates(), field_align(), field_width(), Layout, main(), min_size(), mu_for(), grouping in {AoS, SoA, AoSoA(w)}; `hot` is the field subset kept in the     prim (+5 more)

### Community 26 - "diagnostics.c"
Cohesion: 0.16
Nodes (17): diag_digits(), diag_emit(), diag_emit_json(), diag_emit_json_summary(), diag_error(), diag_error_at(), diag_finish(), diag_json_string() (+9 more)

### Community 27 - "test_runner.py"
Cohesion: 0.05
Nodes (73): aif_records(), cleanup_files(), compile_prismio_file(), emitted_layout_for(), expected_errors(), main(), The candidate `--layout` marks `emitted` for one type, as a label string.      R, REQUIREMENTS 10, applied to the one module every build shares: the runtime. (+65 more)

### Community 28 - "check_source_lists.py"
Cohesion: 0.20
Nodes (21): Exception, compare(), main(), parse_bracketing(), parse_compiler(), parse_oracle(), run(), bootstrap_ps1_list() (+13 more)

### Community 29 - "main() function (test_09_strings)"
Cohesion: 0.48
Nodes (7): FFI / Extern Function Declarations, String Operations, fail(message) function (test_09_strings), main() function (test_09_strings), extern fn str_concat(s1, s2), extern fn str_equals(s1, s2), extern fn str_length(s)

### Community 30 - "compile(input_size)"
Cohesion: 0.33
Nodes (7): Function Composition / Pipeline Simulation, compile(input_size), create_token(t,v,l), fail(message), main(), parse(token_count), tokenize(input)

### Community 31 - "bad_value() function (neg_01_type_mismatch)"
Cohesion: 0.33
Nodes (7): Fixed-Width Integer Typing, Static Type Checking, bad_value() function (neg_01_type_mismatch), main() function (neg_01_type_mismatch), main() function (neg_02_int_width), fail(message), main()

### Community 32 - "Prismio — Compiler Status"
Cohesion: 0.22
Nodes (8): Cross-platform audit (macOS support), How this was produced, Prismio — Compiler Status, Runtime embedding (the part you asked about), Test coverage snapshot, Verified build pipeline, What's built, What's left / known issues

### Community 33 - "Prismio — Bootstrap & Runtime-Linking Architecture Audit"
Cohesion: 0.13
Nodes (14): 1.1 Pipeline trace: `prismio build file.psm` → executable, 1.2 How runtime libraries are included: embedded, external, or both?, 1.3 Every file and function responsible, 1. Current behavior, 2.1 What happens when the compiler compiles itself (`prismio build src/main.psm`)?, 2.2 Duplicate runtime linkage — two separate risks, at two separate layers, 2. Compiler self-hosting, 3. Architecture evaluation against the desired design (+6 more)

### Community 34 - "World"
Cohesion: 0.11
Nodes (37): apply_orders(), main(), make_squad(), Member, Order, plan_orders(), recruit(), resolve_combat() (+29 more)

### Community 35 - "main"
Cohesion: 0.47
Nodes (5): Array Types (1D/2D indexing), array_sum(), fail(message), main(), matrix_diagonal()

### Community 36 - "Struct (Custom Data Type) Declarations"
Cohesion: 0.40
Nodes (6): Struct (Custom Data Type) Declarations, struct Parser, struct Token, struct Point, struct Point, struct Item

### Community 37 - "aif_tier_of"
Cohesion: 0.17
Nodes (12): 1. The measurement, and why the designed fix could not have worked, 2. `region` warns when it serves nothing, and the manifest stopped lying, 3. `list_new_with_capacity(n)` — 0.92× on g2, and the only speed result here, 4. The governance question, settled and written down, 5. `pin(T2)` and `pin(T3)` work, and are now tested rather than folklore, 6. `--why` explains placement, and lists *every* blocker, 7. The manifest emitted records its own CI gate could not read, 8. The oracle did not know about `list_new_with_capacity`, and the differential still passed (+4 more)

### Community 38 - "main() function (test_07_booleans)"
Cohesion: 0.50
Nodes (5): Boolean Logic, fail(message) function (test_07_booleans), is_between(n) function, main() function (test_07_booleans), test_equal(a, b) function

### Community 39 - "main() function (test_02_if_else)"
Cohesion: 0.50
Nodes (5): If/Else Conditionals, fail(message) function (test_02_if_else), main() function (test_02_if_else), max(a, b) function, test_nested_if(x) function

### Community 40 - "main"
Cohesion: 0.60
Nodes (5): Float Arithmetic & Comparisons (f64), blended(offset), comparisons(value), fail(message), main()

### Community 41 - "fibonacci(n) function"
Cohesion: 0.70
Nodes (5): Recursion, fail(message) function (test_06_recursion), fibonacci(n) function, gcd(a, b) function, main() function (test_06_recursion)

### Community 42 - "main() function (test_11_returns)"
Cohesion: 0.50
Nodes (5): Return Statements / Early Return, classify_number(n) function, early_return(x) function, fail(message) function (test_11_returns), main() function (test_11_returns)

### Community 43 - "aif_support.c"
Cohesion: 0.02
Nodes (24): CallEdge, aif_call_edge(), aif_call_opaque(), aif_check_pins(), aif_con_arg(), aif_con_bind(), aif_con_borrow(), aif_con_escape_caller() (+16 more)

### Community 44 - "main"
Cohesion: 0.67
Nodes (3): Generic Collections (List<T>), fail(message), main()

### Community 45 - "Prismio Toolchain Architecture Refactor — Session Handoff"
Cohesion: 0.15
Nodes (12): Confirmed design decisions (from this session's clarifying questions — do not re-ask these), Kickoff prompt for the new session, Phase 1 — Import memoization + driver.c split (foundational, do this first), Phase 2 — Library packaging + Mode 1 (installed-toolchain discovery), Phase 3 — `prismio bootstrap` command + Mode 2 + hash-based freshness, Phase 4 — Backend boundary cleanup, Phase 5 — Tests, docs, architecture report, Prismio Toolchain Architecture Refactor — Session Handoff (+4 more)

### Community 46 - "add_binding"
Cohesion: 0.18
Nodes (10): 1.1 What was actually quadratic, 1 · The frontend was quadratic in module size, and is now linear, 2.1 AIF's whole fixed point is 18 ms, 2 · The frontend is 4% of a cold build, 3.1 The compiler's own self-build, 3 · Cold and incremental, 4 · The toolchain object cache, 5 · Pricing the per-module split, without building one (+2 more)

### Community 48 - "g2_bench.c"
Cohesion: 0.20
Nodes (27): applyOrders(), Actor, EngTransform, EngVelocity, Bool, Double, Int, World (+19 more)

### Community 49 - "strcmp"
Cohesion: 0.21
Nodes (22): global_named(), intern_value(), ir_bitcast(), ir_elem_ptr(), ir_fneg(), ir_fptosi(), ir_fptoui(), ir_get_temp() (+14 more)

### Community 50 - "strlen"
Cohesion: 0.23
Nodes (22): Actor, apply_orders(), main(), make_squad(), Member, Order, plan_orders_into(), recruit() (+14 more)

### Community 51 - "The G2 / G6 benchmark set"
Cohesion: 0.40
Nodes (4): Fidelity, The G2 / G6 benchmark set, What it found, What the variants are

### Community 53 - "g5_tuned.rs"
Cohesion: 0.26
Nodes (19): acquire(), AssetCache, build_assets(), build_buckets(), Entity, evict_unused(), load_material(), load_mesh() (+11 more)

### Community 54 - "g5_idiomatic.rs"
Cohesion: 0.26
Nodes (18): acquire(), AssetCache, build_assets(), Entity, evict_unused(), load_material(), load_mesh(), load_texture() (+10 more)

### Community 55 - "bench.py"
Cohesion: 0.19
Nodes (18): agg(), build_all(), ensure_bumpalo(), main(), measure(), measure_allocs(), parse_output(), pct() (+10 more)

### Community 56 - "World"
Cohesion: 0.27
Nodes (15): Health, main(), make_world(), Physics, Position, Box, Vec, spawn() (+7 more)

### Community 57 - "g3.swift"
Cohesion: 0.13
Nodes (13): Current limitations, Decisions, Generated state is project-local and isolated, Incremental-build extension seam, Module boundaries, Next implementation sequence, Syntax and semantics are separate phases, The compiler executes; UMS orchestrates (+5 more)

### Community 58 - "g4.swift"
Cohesion: 0.21
Nodes (8): str_clone(), strcpy(), compare_names(), current_directory(), executable_directory(), execute_command(), get_directory(), prismio_executable_directory()

### Community 59 - "strncpy"
Cohesion: 0.12
Nodes (25): aif_layout_force(), diag_add_file(), diag_strdup(), ir_clear_local_var_types(), cyc_walk_push(), memcpy(), realloc(), rt_alloc() (+17 more)

### Community 60 - "g4_idiomatic.rs"
Cohesion: 0.30
Nodes (14): Health, main(), make_world(), Physics, Position, Vec, spawn(), Sprite (+6 more)

### Community 61 - "g3_tuned.rs"
Cohesion: 0.35
Nodes (13): Bounds, build_hierarchy(), count_visible(), dfs_order(), identity_transform(), link_child(), main(), make_node() (+5 more)

### Community 62 - "g3_idiomatic.rs"
Cohesion: 0.37
Nodes (12): Bounds, build_hierarchy(), count_visible(), identity_transform(), link_child(), main(), make_node(), Node (+4 more)

### Community 63 - "Building Prismio on macOS (and Linux)"
Cohesion: 0.20
Nodes (9): Build it, Building Prismio on macOS (and Linux), Check you reached a fixed point, Cross-compiling from Windows, Refreshing the seed, Test, package, verify, Troubleshooting, What you need (+1 more)

### Community 64 - "Cross-language results — Prismio vs Rust vs Swift"
Cohesion: 0.12
Nodes (17): 0.1 · Re-measured 2026-08-17, first pass since the `allocs` fix — and the spreads are the finding, 0 · The one-paragraph answer, 1 · The headline table, 2 · Prediction vs measurement, per axis, 2a · "Allocator churn 0.2–0.5×" was wrong about the baseline, not about AIF, 2b · Peak RSS was wrong in our favour, and for the opposite reason to the one assumed, 2c · The tail held, and with the optimiser on it is indistinguishable from Rust's, 3.1 · The optimiser — found here, fixed in this branch (+9 more)

### Community 65 - "g4_tuned.rs"
Cohesion: 0.33
Nodes (11): Health, main(), make_world(), Physics, Position, Vec, spawn(), Sprite (+3 more)

### Community 66 - "The cross-language suite — Prismio vs Rust vs Swift"
Cohesion: 0.25
Nodes (8): 1. Inline struct fields — landed, 4× fewer allocations, one regression, 2. By-value POD returns — designed, deliberately not built, 3. A footprint term in the arena cost model — landed and provably inert, 4. `unique` on a parameter → `noalias` — landed, guarded, win unproven, Handles slipped, and here is the cost that says why, Next, re-ranked on this session's measurements, Session of 2026-08-09 — inline struct fields, and two measured non-results, Three things to carry forward

### Community 67 - "g1_arena.rs"
Cohesion: 0.42
Nodes (10): build_system(), count_alive(), count_beyond(), fade(), integrate(), main(), Particle, Bump (+2 more)

### Community 70 - "Session of 2026-08-08 — the tree did not compile, and the T3 residue was never real"
Cohesion: 0.20
Nodes (10): 0. HEAD did not compile, and that is not in any previous handoff, 1. The 79 T3 sites were a stale reporting default, not a residue, 2. What ownership contexts would buy, measured, 3. The benchmark, and it falsifies a claim the corpus makes about itself, Four things to carry forward, Known gaps, documented rather than fixed, Next, re-ranked on this session's measurements, Not started: ownership contexts (INFERENCE §6–7) (+2 more)

### Community 71 - "aif_str"
Cohesion: 0.09
Nodes (25): aif_arena_at_node(), aif_arena_blockers(), aif_bracket_served(), aif_check_placement_pins(), aif_fn_calls_in_region(), aif_fn_name(), aif_fn_symbol(), aif_nearest_region_name() (+17 more)

### Community 72 - "Code style"
Cohesion: 0.15
Nodes (11): Code style, graphify, Before you change anything, Code style, Invariants that are not obvious from the code, Language and layout, Naming, Performance (+3 more)

### Community 73 - "bootstrap.sh"
Cohesion: 0.36
Nodes (5): die(), green(), bootstrap.sh script, resolve_llvm(), step()

### Community 75 - "Engine"
Cohesion: 0.18
Nodes (8): Engine, Does a value of this type participate in the memory model at all?, Abstract evaluation: the set of allocation sites an expression may         denot, What the extern declaration said, or None to fall through.          A declared c, SPEC 5.2.1's bracketing question, at a call: is what this callee does         to, Where a value assigned to `name` has to stay alive until., vs_sites(), vs_union()

### Community 76 - "package.sh script"
Cohesion: 0.80
Nodes (4): build_archive(), die(), green(), package.sh script

### Community 77 - "Tier 2 — required by specified AIF features"
Cohesion: 0.07
Nodes (28): 10. Per-module optimisation levels **[specified 2026-08-17, not implemented]**, 11. `verify` build mode **[needed]**, 12. Handles instead of raw pointers **[needed, long-horizon]**, 13. Generic containers — `Map<K,V>`, growable `Vec<T>` **[enabling]**, 14. Error handling — tagged unions, `Option` / `Result` **[enabling]**, 15. Concurrency / task model **[needed for `T`]**, 16. Fix superlinear compile time — **DONE, 2026-08-17**, 17. `Int` ↔ `Float` conversion **[minor]** (+20 more)

### Community 84 - "AIF — Workload Declaration, Cost Model, and Layout Search"
Cohesion: 0.07
Nodes (30): 10.1 The cache model has no associativity and no conflict misses, 10.2 `HandleCost` is a placeholder, 10.3 Profiles age, 10.4.1 A fabricated instance count decides the cache tier, and therefore the layout, 10.4 Static frequency estimation is crude, 10.5 One profile, one target, 10 · Known weaknesses, 1 · The key reframing (+22 more)

### Community 85 - "AIF — Design Rationale"
Cohesion: 0.09
Nodes (22): AIF — Design Rationale, Arena placement is a cost decision; `region` is a pin on it, Bake the static region, not the heap, C1, C10, C2, C3, C4 (+14 more)

### Community 87 - "5 · A staged path"
Cohesion: 0.06
Nodes (32): 1 · Headline findings, 2.1 The invariant needs a boundary the spec does not currently draw, 2.2 Structs are affine references, not values, 2 · Frozen items, one by one, 3.1 What isn't behind the seam at all, 3 · The seam, precisely, 4.1 A pass between sema and codegen, 4.2 Scope-based drop (+24 more)

### Community 88 - "1 · AIF core — genuinely ours"
Cohesion: 0.10
Nodes (21): 1 · AIF core — genuinely ours, 2 · AIF's stake in language features it does not own, 3 · Compiler requirements AIF genuinely has, 4 · Measurement, 5 · Not AIF — recorded, then handed over, 6 · Over-built — defer or cut, A3. Realised context counts *(measurement)*, A4. Arena high-water marks *(measurement)* (+13 more)

### Community 89 - "AIF — The FFI Boundary"
Cohesion: 0.10
Nodes (21): 10 · Reporting, 1 · The one place being wrong is unsafe, 2 · C-compatible layout, 3.1 The four cases, 3.2 Copy direction, 3.3 What is never copied, 3 · When a copy is mandatory, 4 · The cost model does the work (+13 more)

### Community 90 - "aif_intern"
Cohesion: 0.06
Nodes (45): aif_enum_new(), aif_extern_contract(), aif_extern_contract_set(), aif_field_has_range(), aif_field_range_bytes(), aif_field_range_hi(), aif_field_range_lo(), aif_fn_lookup() (+37 more)

### Community 91 - "AIF — The T4 Cycle Collector"
Cohesion: 0.11
Nodes (18): 10 · What still needs measurement, 1 · What is actually in scope, 2 · The headline result, 3.1 Why trial deletion and not tracing, 3.2 The procedure, 3 · Algorithm, 4 · The cyclic-edge restriction, 5 · Object header (+10 more)

### Community 92 - "AIF — Measurement and Falsification Plan"
Cohesion: 0.12
Nodes (17): 1 · The methodological point that matters most, 2.1 Definitions, 2.2 The claim under test, 2.3 False sharing from field insensitivity, 2 · Primary metric: tier distribution, 3.1 B1 is a weak headline and should not be the first result, 3.2 Baselines, 3 · Benchmark programs (+9 more)

### Community 93 - "PIR — Prism Semantic IR"
Cohesion: 0.13
Nodes (15): 1 · Why bodies must ship, 2.1 Not LLVM IR, 2 · Content model, 3 · Deterministic emission, 4 · Merging, 5.1 Sealed surfaces SHALL publish ownership contracts, 5 · Sealed functions, 6.1 Format versioning (+7 more)

### Community 94 - "aif_solve"
Cohesion: 0.10
Nodes (45): Bits, Deriv, IntVec, aif_argv_push(), aif_bracket_callee(), aif_bracket_count(), aif_bracket_scope(), aif_bracketable_region_call_sites() (+37 more)

### Community 95 - "AIF — Level 0 Results"
Cohesion: 0.17
Nodes (12): 1 · Headline, 2 · The finding: one decision accounts for the entire residue, 3 · What the game corpus showed that the compiler could not, 3a · Handles appear to eliminate T3 in engine code, 4.1 `retain_in(k)` is missing from FFI.md's contract vocabulary, 4.2 The cycle collector has no program that can exercise it, 4 · Two spec gaps the run found, 5 · Secondary measurements (+4 more)

### Community 96 - "AIF — The Target Workload"
Cohesion: 0.17
Nodes (12): 0.1 · Engine and game remain two workloads, 0 · The actual stack, 1 · The two halves, 2.1 The annotations belong to the engine layer, 2.2 T3 lives in the engine, T0–T2 in the game, 2.3 The engine/game boundary is where whole-program analysis must hold, 2.4 The manifest becomes a contract between teams, 2.5 Optimisation level has to be **per module**, not per build (+4 more)

### Community 97 - "AIF — Adaptive Inference Framework"
Cohesion: 0.17
Nodes (12): 0 · Conformance language, 12 · What this model gives up *(informative)*, 1.1 What the invariant does not cover, 1 · The invariant, 6.1 Purpose, 6.2 Format, 6.3 Diff semantics, 6 · The tier manifest (+4 more)

### Community 98 - "AIF — Cross-Language Comparison Suite"
Cohesion: 0.20
Nodes (10): 1 · The thesis, stated so it can be killed, 2 · Fairness rules, 3 · The suite, 4 · Isolating the memory-model tax, 5 · Where AIF is predicted to lose, 6 · Predicted results, 7 · Reporting, AIF — Cross-Language Comparison Suite (+2 more)

### Community 99 - "AIF — Evaluation as a General-Purpose Memory Model"
Cohesion: 0.20
Nodes (10): 1 · The finding that should drive planning, 2 · What holds up as general-purpose, 3 · Where the spec is over-fitted — the 80/20 budget rule, 4 · Regions generalise better than layout, and are under-emphasised, 5 · The biggest hole: closures, 6 · PIR is a heavier liability for general-purpose than for games, 7 · Honest scorecard, 8 · What I would change (+2 more)

### Community 100 - "AIF — Adaptive Inference Framework"
Cohesion: 0.20
Nodes (10): AIF — Adaptive Inference Framework, Conformance is graded, Contents, Running the prototype, Start here, Status, The model in one screen, Two things to know before extending this (+2 more)

### Community 101 - "8.4 Views — slices and element references"
Cohesion: 0.20
Nodes (10): 8.1 Handles, 8.2 The compiler owns layout, 8.3 The static region, 8.4 Views — slices and element references, 8 · Representation, Cost, stated plainly, Element references are views too — the deep consequence, Invalidation, without a borrow checker (+2 more)

### Community 102 - "aif.py"
Cohesion: 0.16
Nodes (16): base_type(), bracket_masks(), elem_key(), main(), measure_masks(), `List<Token>` -> `List`. Field keys are per nominal type, so a generic     conta, A container's contents, as a field key.      Object-insensitive through base_typ, SPEC 5.2.1: per function, may a caller's `region` bracket a call to it?      The (+8 more)

### Community 103 - "nominal_find"
Cohesion: 0.22
Nodes (10): aif_layout_rank(), aif_layout_split_select(), aif_reset(), candidate_with_hot(), candidates_clear(), forced_hot_for(), forced_mark_applied(), has_sequential_traversal() (+2 more)

### Community 104 - "5 · Annotations"
Cohesion: 0.25
Nodes (8): 5.0.1 Annotations are assertions, not directives *(normative)*, 5.0 Why exactly these four *(normative rationale)*, 5.1 `unique`, 5.2.1.1 Call-site placement, and which regime it uses *(normative)*, 5.2.1 A region only reaches allocations in its own function *(normative limitation)*, 5.2 `region { … }`, 5.3 `workload(…)`, 5 · Annotations

### Community 105 - "AIF — Layout Results (A1)"
Cohesion: 0.25
Nodes (8): 1 · Headline, 2 · The static profile is exact, 3 · The model discriminates, and that is the real result, 4 · Spec defect found: LAYOUT §5.4's total could go negative, 5 · What this does not show, 6 · What to do next, AIF — Layout Results (A1), Reproducing

### Community 106 - "AIF — The Inference Engine"
Cohesion: 0.25
Nodes (8): 10 · Worked example, 1 · Architecture, 3.1 Nodes, 3.2 Edges, 3.3 Node ordering (normative), 3 · The fact graph, 9 · Incrementality, AIF — The Inference Engine

### Community 107 - "4 · Transfer rules"
Cohesion: 0.25
Nodes (8): 4.1 Escape module, 4.2 Aliasing module, 4.3 Thread module, 4.4 Cyclicity module, 4.5 Closure capture, 4.6 Dynamic dispatch, 4.7 Generics and ownership contexts, 4 · Transfer rules

### Community 108 - "5 · The fixed-point algorithm"
Cohesion: 0.25
Nodes (8): 5.1 Iteration strategy (normative), 5.2 The algorithm, 5.3 The give-up condition — and why you cannot simply stop, 5.4 Determinism (normative), 5.5 Termination, 5.6 Minimal cause, 5.7 Optimisation levels, 5 · The fixed-point algorithm

### Community 109 - "7 · Specialisation strategy and dedup"
Cohesion: 0.25
Nodes (8): 7.0.1 Three strategies, 7.0.2 Dedup still applies, 7.0 The ownership-divergence ratio, 7.1 Layer 1 — the relevant-parameter mask *(pre-instantiation, cheapest, does the most work)*, 7.2 Layer 2 — semantic equivalence *(pre-codegen)*, 7.3 Layer 3 — structural dedup *(post-codegen)*, 7.4 Budget-driven collapse, 7 · Specialisation strategy and dedup

### Community 110 - "AIF — Engine/Game Boundary Results (A2)"
Cohesion: 0.29
Nodes (7): 1 · Result, 2 · The boundary is cheap because the API is handle-based, 3 · Most of the sealing loss is recoverable with contracts, 4 · A prototype bug worth recording, 5 · Compiler bug found: `List<Int>` miscompiles, 6 · What this does not show, AIF — Engine/Game Boundary Results (A2)

### Community 111 - "AIF Prototype"
Cohesion: 0.29
Nodes (6): AIF Prototype, Approximations, Running, Two bugs found here, both worth remembering, Two roles, What it implements

### Community 112 - "11 · Known weaknesses"
Cohesion: 0.29
Nodes (7): 11.1 Field sensitivity is object-insensitive, 11.2 The context set is discovered from facts that are still moving, 11.3 Loops are handled by the lattice, not by a loop analysis, 11.4 There is no interprocedural path sensitivity, 11.5 ~~The `⊤` context is a cliff~~ — resolved in 1.2, 11.6 Everything here assumes whole-program PIR, 11 · Known weaknesses

### Community 113 - "2 · Fact domains"
Cohesion: 0.29
Nodes (7): 2.1 `E` — escape, 2.2 `A` — aliasing, 2.3 `T` — thread affinity, 2.4 `C` — cyclicity, 2.5 `L` — lifetime determinacy *(derived)*, 2.6 The product, 2 · Fact domains

### Community 114 - "8 · Annotations as axioms and constraints"
Cohesion: 0.33
Nodes (6): 8.1 Seeding and cutting, 8.2 `unique` — verification is complete, 8.3 `region` — verification is sound, and imprecision costs only performance, 8.4 `pin`, 8.5 Verification under budget, 8 · Annotations as axioms and constraints

### Community 115 - "11 · Conformance boundary"
Cohesion: 0.33
Nodes (6): 11.0 Conformance levels, 11 · Conformance boundary, Annotation governance, Frozen — normative, Open — by descending risk, Resolved in 1.1 — was open in v1.0

### Community 116 - "3 · The tier ladder"
Cohesion: 0.33
Nodes (6): 3 · The tier ladder, T0 — Value / stack, T1 — Region / arena, T2 — Unique owned, T3 — Shared, non-atomic reference counting, T4 — Managed residue

### Community 117 - "Model"
Cohesion: 0.15
Nodes (7): ann_leaf_name(), Model, Scope forest. Each function's body block is a root; join is the LCA,     which e, The type an annotation refers to: `[T]` and `List<T>` hang T off c1,     and the, Tarjan-free SCC via iterative Kosaraju on the type reference graph         (INFE, Scopes, Site

### Community 118 - ".solve"
Cohesion: 0.14
Nodes (10): escape_join(), escape_le(), Records s in this round's delta and returns True, so a rule reads         `chang, INFERENCE 5.3: a truncated ascending iteration is a *pre*-fixed point         an, Least upper bound on Region(s) < Caller < Global., Flatten a value-set expression against the current points-to state., SPEC 8.4. The collections whose lifetime this value set depends on:         its, SPEC 8.4 E-VIEW:  v is a view of c  =>  E(c) ⊒ E(v).          Applied wherever a (+2 more)

### Community 119 - "AIF Evidence"
Cohesion: 0.40
Nodes (5): AIF Evidence, Before quoting any number, Judgement, Measured, Projected, not measured

### Community 120 - "6 · Ownership contexts"
Cohesion: 0.40
Nodes (5): 6.1 What a context is, 6.2 Context ordering, 6.3 Discovery (demand-driven), 6.4 The context cap, 6 · Ownership contexts

### Community 121 - "2 · The objects of the model"
Cohesion: 0.40
Nodes (5): 2.1 Allocation site, 2.2 Ownership context, 2.3 Abstract value, 2.4 What tier is not, 2 · The objects of the model

### Community 122 - "4 · Tier derivation"
Cohesion: 0.40
Nodes (5): 4.1 Inputs, 4.2 The derivation function, 4.3 Monotonicity (normative property), 4.4 Cost model constants *(informative)*, 4 · Tier derivation

### Community 123 - "7 · Two-speed compilation"
Cohesion: 0.33
Nodes (6): 7.1 Requirement, 7.2 Levels, 7.3 `verify` — facts as runtime assertions, 7.4 Layout search is opt-in, 7.5 Levels are per module, not per build, 7 · Two-speed compilation

### Community 124 - "g1_boxed.rs"
Cohesion: 0.49
Nodes (10): build_system(), count_alive(), count_beyond(), fade(), integrate(), main(), Particle, Box (+2 more)

### Community 125 - "AIF Corpus"
Cohesion: 0.50
Nodes (4): AIF Corpus, Building, Gaps to fill, Three things the corpus established

### Community 126 - "6 · The tier manifest"
Cohesion: 0.14
Nodes (17): strncpy(), ir_alloca(), ir_array_alloca(), ir_declare_function_begin(), ir_declare_function_param(), ir_function_begin(), ir_function_end(), ir_function_param() (+9 more)

### Community 127 - "Profile"
Cohesion: 0.22
Nodes (5): Profile, Collect (owner_type, field, is_write) for every member access in a         subtr, Names incremented by a literal inside the loop -- i.e. the induction         var, Extracted entirely from the AST. Every attribute LAYOUT 2.1 marks     'static, e, Traversal

### Community 128 - "namelist_contains"
Cohesion: 0.25
Nodes (11): NameList, ir_declare_named_type(), ir_is_borrowed(), ir_is_global_name(), ir_is_moved(), ir_mark_borrowed(), ir_mark_moved(), ir_named_type_kind() (+3 more)

### Community 129 - "NEXT-SESSION.md"
Cohesion: 0.14
Nodes (12): Carry forward, Not this session, Not this session, Prompt 2 — layout, Prompt 2 (original, for reference), Prompt 2 (residual) — the hot/cold split, and only that, The last-good generation, The one task (+4 more)

### Community 130 - "find_binding"
Cohesion: 0.22
Nodes (9): find_binding(), ir_binding_predates_loop(), ir_get_var_slot(), ir_get_var_type(), ir_has_var_type(), ir_mark_droppable(), ir_mark_mutable(), ir_var_is_global() (+1 more)

### Community 131 - "aif_manifest_diff.py"
Cohesion: 0.36
Nodes (6): explain(), main(), parse(), (header key -> value, symbol -> Record). Unparseable lines are ignored:     the, SPEC 6.3's minimal cause for one regressed record, from the compiler.      The d, Record

### Community 132 - "g1_idiomatic.rs"
Cohesion: 0.47
Nodes (9): build_system(), count_alive(), count_beyond(), fade(), integrate(), main(), Particle, Vec (+1 more)

### Community 133 - "g2_arena.rs"
Cohesion: 0.38
Nodes (9): build_scene(), cull(), DrawCmd, main(), Renderable, Bump, BVec, Vec (+1 more)

### Community 134 - "g7_idiomatic.rs"
Cohesion: 0.40
Nodes (9): build_source(), is_alnum(), is_alpha(), is_digit(), is_operator(), is_space(), main(), String (+1 more)

### Community 135 - "g7_owned.rs"
Cohesion: 0.40
Nodes (9): build_source(), is_alnum(), is_alpha(), is_digit(), is_operator(), is_space(), main(), String (+1 more)

### Community 136 - "g1_tuned.rs"
Cohesion: 0.50
Nodes (8): build_system(), count_alive(), count_beyond(), fade(), integrate(), main(), Particles, Vec

### Community 137 - "g2_boxed.rs"
Cohesion: 0.50
Nodes (8): build_scene(), cull(), DrawCmd, main(), Renderable, Box, Vec, submit()

### Community 138 - "RESULTS — the string/parse axis"
Cohesion: 0.33
Nodes (6): 5.4.1 A proven-false pin is a compile error, 5.4.2 An unproven pin is never an error, 5.4.3 Strictness is opt-in, per value, 5.4.4 The direction limit *(normative)*, 5.4.5 `pin(<region-name>)` — the placement form *(normative)*, 5.4 `pin`

### Community 139 - "g2_idiomatic.rs"
Cohesion: 0.54
Nodes (7): build_scene(), cull(), DrawCmd, main(), Renderable, Vec, submit()

### Community 140 - "g2_tuned.rs"
Cohesion: 0.54
Nodes (7): build_scene(), cull_into(), DrawCmd, main(), Renderable, Vec, submit()

### Community 141 - "Frames"
Cohesion: 0.29
Nodes (4): Frames, report(), Vec, Self

### Community 142 - "Arena placement: what `region` serves, and what stops the rest"
Cohesion: 0.20
Nodes (10): 1 · The headline, 2 · Why an escape-lattice change does not move this, 3 · The measurement that was wrong twice, and why, 4 · `region` measured on g2, 5 · What a region *can* serve, 6 · `list_new_with_capacity`, the one speed result, 7 · What would actually close this, 8 · How much call-site bracketing could reach *(2026-08-16)* (+2 more)

### Community 143 - "Handoff — continuing the Prismio work"
Cohesion: 0.25
Nodes (8): Current state, File roles, Five rules learned the hard way, Handoff — continuing the Prismio work, Session of 2026-08-07 (second) — the corpus reaches zero, Three things to carry forward, What's next, Workflow — do this for every change

### Community 144 - "Session of 2026-08-09 (second) — views: the safety half landed, the speed half was somewhere else"
Cohesion: 0.33
Nodes (6): 1. SPEC 8.4's E-VIEW landed, and it closes a real use-after-free, 2. The speed half: it was never the malloc, 3. The cross-language numbers, and the axis that did not exist, Four things to carry forward, Next, re-ranked on this session's measurements, Session of 2026-08-09 (second) — views: the safety half landed, the speed half was somewhere else

### Community 145 - "Session of 2026-08-08 (measurement) — the first cross-language numbers, and the optimiser was never on"
Cohesion: 0.29
Nodes (7): 1. The number the session exists to produce, 2. The regime question, settled and written into the spec, 3. What the reports say, and where the numbers live, 4. Two defects, one of them mine, and both now have a test that fails without the fix, 5. Why task 4 stopped, and the two things not to re-derive, 6. Fixtures built to discriminate, Session of 2026-08-16 — the repair is measured before it is built, and it is worth building

### Community 146 - "optgap.py"
Cohesion: 0.60
Nodes (4): loop_ms(), main(), Median in-process loop time, from the program's own frame samples., sh()

### Community 147 - "RESULTS — the string/parse axis"
Cohesion: 0.25
Nodes (8): 0 · Why this file exists, 1 · The measurement, 2 · What was wrong: `str_substring` rescans the whole buffer, 3 · The compiler itself, 4 · What did *not* move, and why that is the finding, 5 · What this changes about the ranking, RESULTS — the string/parse axis, The fix, and why it is only half of one

### Community 148 - "g7bench.py"
Cohesion: 0.83
Nodes (3): build(), main(), measure()

### Community 149 - "optlevel.py"
Cohesion: 0.83
Nodes (3): loop_ms(), main(), sh()

### Community 150 - "aif_tier_of"
Cohesion: 0.08
Nodes (48): Nominal, aif_compute_type_acyclic(), aif_cycle_at_node(), aif_elem_owner_at_node(), aif_elem_type_at_node(), aif_field_is_counted(), aif_field_is_cyclic(), aif_field_release() (+40 more)

### Community 151 - "Prismio IDE protocol"
Cohesion: 0.50
Nodes (3): Current boundary, JSON diagnostics, Prismio IDE protocol

### Community 152 - "Session of 2026-08-13 — `workload` lands; two of LAYOUT 6's dimensions are not blocked on what the brief said"
Cohesion: 0.29
Nodes (7): 1. `workload` landed (LAYOUT 3, SPEC 11 item 7's fourth annotation), 2. Two of LAYOUT 6's four remaining dimensions were never blocked on handles, 3. The harness re-run: no movement, which is the correct answer, and one thing it exposed, 4. LAYOUT 8 is behind §7.2, not behind the runner, Four things to carry forward, Next, re-ranked on this session's measurements, Session of 2026-08-13 — `workload` lands; two of LAYOUT 6's dimensions are not blocked on what the brief said

### Community 153 - "arena_chunk_new"
Cohesion: 0.22
Nodes (9): 1. The form, and why it needed no grammar change, 2. What it asserts, stated so a reader can tell what it catches, 3. The ordering is the whole difference from the tier pin, and it is not interchangeable, 4. Sema stopped adjudicating the name, and that is a deletion worth reading, 5. Broken on purpose, and the exact failure, 6. Verification, as numbers, 7. A branch that cannot fire, found while checking that it could, 8. Merge hazards for whoever integrates this (+1 more)

### Community 154 - "LAYOUT 6's candidate space, measured against what this compiler can emit"
Cohesion: 0.12
Nodes (16): 1 · Handles did not land, and two dimensions depend on them, 2.1 · It was built on 2026-08-17, and the corpus does not reproduce the 0.87×, 2.2 · The cost model chose two layouts the measurement rejected, and both reasons are nameable, 2.3 · The compiler self-hosted with a split AST, and then stopped splitting it, 2 · Hot/cold does *not* need handles, and it pays, 3 · Bit-packing is blocked by the specification, not by codegen, 4.1 · Both blockers are gone, and the remaining piece is a search loop, 4 · Empirical validation (LAYOUT §8) is behind §7.2, not behind the runner (+8 more)

### Community 155 - "The cross-language suite — Prismio vs Rust vs Swift"
Cohesion: 0.29
Nodes (7): A note on what this suite found and changed, Fidelity notes, How each axis is measured, Results, The cross-language suite — Prismio vs Rust vs Swift, The four decisions worth arguing with, What is here

### Community 156 - "arena_census.py"
Cohesion: 0.39
Nodes (7): blockers_for(), main(), manifest_symbols(), programs(), `--summary`'s own count of placed calls and served sites.      A second, indepen, (records, brackets), or (None, 0) if the program does not build.      `records`, summary_brackets()

### Community 158 - "Session of 2026-08-16 (second) — call-site placement lands; `region` stops being inert on g2"
Cohesion: 0.22
Nodes (9): 1. There is no new codegen mechanism, and that is the shape of the result, 2. Obligation 3, and why `E` cannot answer it, 3. The list needed the runtime, and a flag would have been wrong, 4. Four mechanisms, each broken on purpose to confirm the check fails, 5. The `--verify` comparison was vacuous the first time, and the fix changes the reading, 6. Timing — re-measured after the merge, and the flat line is still the stronger half, 7. What did not move, which is most of the point, 8. Known gap, recorded rather than papered over (+1 more)

### Community 159 - "Session of 2026-08-16 (layout) — the cost model lands, and it could not have ranked the cut it exists for"
Cohesion: 0.25
Nodes (8): 1. The premise reproduces, and the headline number was worth re-running, 2. Restricted to what codegen can emit, the model picks the measured cut, 3. A linked split is not an indexed split, and the prototype cannot tell them apart, 4. Why the hot/cold split was not started, which is a scope decision and not a discovery, 5. The `allocs` column was measuring the report, and now measures the workload, 6. Two things that cost time and should not cost it twice, Next, ranked, Session of 2026-08-16 (layout) — the cost model lands, and it could not have ranked the cut it exists for

### Community 160 - "Session of 2026-08-08 (measurement) — the first cross-language numbers, and the optimiser was never on"
Cohesion: 0.33
Nodes (6): Four things to carry forward, Next, re-ranked on this session's measurements, Session of 2026-08-08 (measurement) — the first cross-language numbers, and the optimiser was never on, The defect: `prismio build` ran no optimiser, on either stage, The `region` annotation is inert on g2, and that is the sharpest result here, Where Prismio stands, after the fix

### Community 161 - "Prompt 1 is done — what it unblocked"
Cohesion: 0.22
Nodes (9): 1. The transform is four places, and the brief's four pieces all held, 2. Five vetoes, and three of them cost a build or a measurement to find, 3. The measurement refuted the model on two programs, and this time codegen was listening, 4. And the prize did not reproduce — but not because the benchmark was unrepresentative, 5. The self-host was the budgeted risk, and it did not bite, 6. The IR delta, characterised, 7. Two things that cost time and should not cost it twice, Next, ranked (+1 more)

### Community 162 - "str_split"
Cohesion: 0.18
Nodes (11): 1. REQUIREMENTS 16 was four scans in three passes, not one, 2. The IR delta is a slot renumbering, on all 89 programs, and it is worth understanding, 3. INFERENCE §9: priced, then not built, and the price is the finding, 4.1 The same hole was in the build driver's cache, and it was mine, 4.2 The first hard ceiling on program size is gone, 4. The object cache, and the one thing its test cannot reach, 5. REQUIREMENTS 10 is specified as SPEC §7.5, 6. The per-module split is priced, and two of the three numbers are surprises (+3 more)

### Community 164 - "2 · Prediction vs measurement, per axis"
Cohesion: 0.17
Nodes (12): 2026-08-17 (compile time) — the frontend is linear now, and incrementality is not an AIF problem, 2026-08-17 (second) — LAYOUT §8's forced candidate landed; read this before writing another brief, 2026-08-17 — tasks 1 and 2 both landed, in parallel, and were merged, Next, ranked, Next, ranked, Prompts for the next sessions, Task 2 is done — `pin(<region-name>)`, 2026-08-17 (pin session), The measurement that should decide the next few sessions (+4 more)

### Community 166 - "9 · The budget rule"
Cohesion: 0.15
Nodes (15): ArenaChunk, arena_alloc(), arena_alloc_at(), arena_alloc_slot(), arena_chunk_new(), cyc_retain(), list_push(), list_release() (+7 more)

### Community 167 - "Session of 2026-08-17 (second) — §8's forced candidate lands, and the IR differential turns out to have a concurrency hole"
Cohesion: 0.33
Nodes (6): 1. What landed, 2. The bug in it, which is the interesting part, 3. `tools/ir_snapshot.py` reports a false difference under concurrency, 4. The gate, 5. Next, ranked, Session of 2026-08-17 (second) — §8's forced candidate lands, and the IR differential turns out to have a concurrency hole

### Community 168 - "The prompt for the next session"
Cohesion: 0.29
Nodes (7): find_struct(), ir_get_struct_field_count(), ir_get_struct_field_index(), ir_get_struct_field_type(), ir_get_struct_field_type_at(), ir_is_struct_type_name(), StructInfo

### Community 169 - "Prompt 1 is done — what it unblocked"
Cohesion: 0.40
Nodes (5): Carry forward, Next, ranked, Not this session, Prompt 1 is done — what it unblocked, What landed, so it is not re-derived

### Community 170 - "str_split"
Cohesion: 0.38
Nodes (14): G4, Health, Physics, Position, spawn(), Sprite, Double, Int (+6 more)

### Community 171 - "decl_entry"
Cohesion: 0.40
Nodes (5): DeclEntry, decl_entry(), ir_decl_at(), ir_decl_count(), ir_index_decl()

### Community 172 - "ir_slot_diff.py"
Cohesion: 0.83
Nodes (3): main(), normalise(), slot_names()

### Community 173 - "10 · Boundaries"
Cohesion: 0.67
Nodes (3): 10.1 FFI, 10.2 Library distribution, 10 · Boundaries

### Community 174 - "backend_fail"
Cohesion: 0.14
Nodes (15): backend_fail(), const_from_text(), grow_table(), ir_br(), ir_call_arg(), ir_call_begin(), ir_call_end(), ir_cond_br() (+7 more)

### Community 175 - "struct_entry"
Cohesion: 0.21
Nodes (14): LLVMTypeRef, attach_cold(), attach_cold_rc(), ir_alloc_cycle(), ir_alloc_object(), ir_alloc_rc(), ir_alloc_region(), ir_alloc_stack() (+6 more)

### Community 176 - "block_done"
Cohesion: 0.20
Nodes (11): LLVMBasicBlockRef, block_done(), block_for(), ir_br_numbered(), ir_call_indirect_ptr(), ir_cond_br_numbered(), ir_free_cold(), ir_label_numbered() (+3 more)

### Community 177 - "LLVMValueRef"
Cohesion: 0.25
Nodes (9): LLVMValueRef, NamedValue, apply_param_attrs(), ir_declare_function_end(), ir_function_body_start(), ir_load(), ir_store(), lookup_named() (+1 more)

## Ambiguous Edges - Review These
- `Test naming convention (test_<NN>_<description>.psm)` → `fn main() -> Int`  [AMBIGUOUS]
  CONTRIBUTING.md · relation: conceptually_related_to

## Knowledge Gaps
- **684 isolated node(s):** `Darwin`, `Foundation`, `1.1 Pipeline trace: `prismio build file.psm` → executable`, `1.2 How runtime libraries are included: embedded, external, or both?`, `1.3 Every file and function responsible` (+679 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Test naming convention (test_<NN>_<description>.psm)` and `fn main() -> Int`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `strcmp()` connect `lang_runtime.c` to `free`, `g4.swift`, `nominal_find`, `aif_str`, `ir_intern`, `backend_fail`, `struct_entry`, `LLVMValueRef`, `strcmp`, `aif_intern`, `strncpy`, `6 · The tier manifest`?**
  _High betweenness centrality (0.082) - this node is a cross-community bridge._
- **Why does `strlen()` connect `strncpy` to `free`, `aif_intern`, `lang_runtime.c`, `ir_intern`, `backend_fail`, `llvm-api-backend.c`, `g4.swift`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Why does `AIF — Adaptive Inference Framework` connect `AIF — Adaptive Inference Framework` to `8.4 Views — slices and element references`, `5 · Annotations`, `10 · Boundaries`, `11 · Conformance boundary`, `3 · The tier ladder`, `RESULTS-L0-tiers.md`, `2 · The objects of the model`, `4 · Tier derivation`, `7 · Two-speed compilation`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Are the 31 inferred relationships involving `free()` (e.g. with `aif_arena_high_water()` and `aif_layout_cand_bytes()`) actually correct?**
  _`free()` has 31 INFERRED edges - model-reasoned connections that need verification._
- **Are the 25 inferred relationships involving `strlen()` (e.g. with `aif_intern()` and `aif_layout_force()`) actually correct?**
  _`strlen()` has 25 INFERRED edges - model-reasoned connections that need verification._
- **Are the 36 inferred relationships involving `main()` (e.g. with `ir_alloc_object()` and `ir_alloca()`) actually correct?**
  _`main()` has 36 INFERRED edges - model-reasoned connections that need verification._