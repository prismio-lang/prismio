# Graph Report - prismio  (2026-08-29)

## Corpus Check
- 257 files · ~624,015 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3156 nodes · 5726 edges · 233 communities (219 shown, 14 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 357 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `8bc92458`
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
- find_llvm_paths_ex
- g1_arena.rs
- struct Counter
- struct Res
- g2_cull_probe.c
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
- malloc
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
- g5.swift
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
- v0.1 concurrency — the blocking typed `Channel<T>`, and g9's fifth arm
- Session of 2026-08-09 (second) — views: the safety half landed, the speed half was somewhere else
- five_arm_bench.py
- optgap.py
- RESULTS — the string/parse axis
- g7bench.py
- optlevel.py
- aif_tier_of
- Prismio IDE protocol
- Session of 2026-08-13 — `workload` lands; two of LAYOUT 6's dimensions are not blocked on what the brief said
- aif_verify_alloc
- LAYOUT 6's candidate space, measured against what this compiler can emit
- The cross-language suite — Prismio vs Rust vs Swift
- arena_census.py
- HANDOFF.md
- run_data_view_gate_test
- build_from_toolchain_sources
- Session of 2026-08-08 (measurement) — the first cross-language numbers, and the optimiser was never on
- 0.1.0
- v0.1 release candidate — the complete local gate
- ir_snapshot.py
- Releasing Prismio
- g2r_time.py
- release_gate.sh
- Session of 2026-08-17 (second) — §8's forced candidate lands, and the IR differential turns out to have a concurrency hole
- The prompt for the next session
- Session of 2026-08-08 (measurement) — the first cross-language numbers, and the optimiser was never on
- ir_intern
- ir_slot_diff.py
- 10 · Boundaries
- aif_place_arenas
- struct_entry
- block_done
- release.sh
- g3.swift
- cleanup_files
- run_command
- manifest_records
- 5 · The accepted tradeoffs, reported anyway
- run_check_command_test
- test_runner.py
- 2026-08-19 (payload enums) — `Option`/`Result` are in; exhaustiveness is the hole, and REQUIREMENTS 18 now gates two things
- The hot element accessor was never curated
- call_edge_push
- run_aif_layout_test
- run_aif_struct_field_test
- str_split
- run_aif_stack_slot_test
- add_binding
- aif_verify_alloc
- list_new_cap
- Appendix — M2's closing state, 2026-08-23
- xrealloc
- Session of 2026-08-17 (second) — §8's forced candidate lands, and the IR differential turns out to have a concurrency hole
- prismio_llvm.h
- M2.1a — recursive releases for self-referential types (fork (a))
- g5.swift
- Concepts
- arena_chunk_new
- milestone_bench.py
- find_binding
- struct_entry
- allocount.c
- find_struct
- Prompt 1 is done — what it unblocked
- Prompt 2 (residual) — the hot/cold split, and only that
- run
- run
- run
- run
- run
- run
- format.rs
- README.md
- M4.1 — first-class `Slice<T>`
- Prompt 2 (residual) — the hot/cold split, and only that
- arena_emit_range
- Prompt 1 is done — what it unblocked
- bracket_place
- M4.4 — generic/container layout specialization
- Boxed `List` replacement ownership
- g9_idiomatic.rs
- g9_tuned.rs
- An owned call result consumed directly as an argument now has an owner
- A binding that escapes through a callee's return was freed under its caller
- A payload-free enum variant allocated uninitialised memory
- ir_jit_run_main
- aif_records

## God Nodes (most connected - your core abstractions)
1. `free()` - 77 edges
2. `malloc()` - 60 edges
3. `main()` - 51 edges
4. `run_command()` - 42 edges
5. `intern_value()` - 40 edges
6. `resolve_value()` - 40 edges
7. `main()` - 39 edges
8. `bits_test()` - 36 edges
9. `type_from_key()` - 35 edges
10. `aif_intern()` - 31 edges

## Surprising Connections (you probably didn't know these)
- `diag_reset()` --calls--> `free()`  [INFERRED]
  runtime/diagnostics.c → aif/evidence/xlang/allocount.c
- `ir_reset_fn_return_types()` --calls--> `free()`  [INFERRED]
  runtime/ir_symbols.c → aif/evidence/xlang/allocount.c
- `arena_pop()` --calls--> `free()`  [INFERRED]
  runtime/lang_runtime.c → aif/evidence/xlang/allocount.c
- `chan_free()` --calls--> `free()`  [INFERRED]
  runtime/program_support.c → aif/evidence/xlang/allocount.c
- `prismio_task_release()` --calls--> `free()`  [INFERRED]
  runtime/program_support.c → aif/evidence/xlang/allocount.c

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Negative tests validating move/drop/borrow ownership checking** — tests_neg_03_use_after_move_main, tests_neg_04_use_after_drop_main, tests_neg_05_drop_borrow_main [INFERRED 0.85]
- **Negative tests validating semantic/type checking (type mismatch, integer width, duplicate overload)** — tests_neg_01_type_mismatch_bad_value, tests_neg_02_int_width_main, tests_neg_06_duplicate_overload_same [INFERRED 0.75]
- **Shared fail(message) test-harness helper pattern across feature tests** — tests_test_01_variables_fail, tests_test_02_if_else_fail, tests_test_03_while_loops_fail, tests_test_04_structs_fail, tests_test_05_enums_fail, tests_test_06_recursion_fail, tests_test_07_booleans_fail, tests_test_08_mutability_fail, tests_test_09_strings_fail, tests_test_10_expressions_fail, tests_test_11_returns_fail, tests_test_12_imports_fail, tests_test_13_globals_fail [INFERRED 0.95]
- **Prismio Ownership System (Move/Drop/Borrow) Demonstration** — tests_test_23_move_main, tests_test_24_drop_main, tests_test_25_conventions_main, tests_test_26_borrow_reuse_main [INFERRED 0.85]

## Communities (233 total, 14 thin omitted)

### Community 0 - "malloc"
Cohesion: 0.08
Nodes (40): aif_con_pin_region(), aif_elem_key(), aif_enum_new(), aif_extern_contract(), aif_extern_contract_set(), aif_fn_new(), aif_intern(), aif_key_field() (+32 more)

### Community 1 - "fn compile_source(path, output_file, run_after_build) -> Int"
Cohesion: 0.07
Nodes (30): Contributor Covenant Code of Conduct, Conventional Commits convention, Prismio Project Structure (src/ layout), Claim: no dedicated semantic analysis pass (planned), Test naming convention (test_<NN>_<description>.psm), POST_INSTALL.txt (install success message), Documented Compiler Pipeline (README architecture diagram), Contributor Covenant (README reference) (+22 more)

### Community 2 - "g6_bench.c"
Cohesion: 0.19
Nodes (28): Actor, apply_orders(), arena_alloc(), arena_reserve(), arena_reset(), List, World, list_free_all() (+20 more)

### Community 3 - "ir_symbols.c"
Cohesion: 0.06
Nodes (5): drop_index(), ir_drop_kind(), ir_drop_slot(), ir_drop_type(), ir_reset_fn_return_types()

### Community 4 - "free"
Cohesion: 0.10
Nodes (33): FILE, accept_if_exists(), build_curated_module(), compiler_default_exe_path(), compiler_installed_runtime_hash(), compiler_publish_file(), compiler_runtime_source_hash(), compiler_temp_ir_path() (+25 more)

### Community 5 - "lang_runtime.c"
Cohesion: 0.04
Nodes (7): arena_pop(), print_float(), println(), println_float(), prismio_rt_print_float(), prismio_rt_println(), prismio_rt_println_float()

### Community 7 - "Borrow Checking"
Cohesion: 0.08
Nodes (30): Borrow Checking, Drop Semantics, Move Semantics, Parameter Passing Conventions (borrow/inout/sink), Struct Types, main() function (neg_03_use_after_move), struct Point (neg_03_use_after_move), main() function (neg_04_use_after_drop) (+22 more)

### Community 8 - "Prismio — Compiler Audit"
Cohesion: 0.17
Nodes (14): compile_prismio_file(), _di_located_lines(), _di_located_spans(), _di_scope_file(), expected_errors(), Substrings the diagnostics must contain, from `// expect-error:` lines.      Wit, The DIFile a metadata node belongs to, following `scope:` upwards., Every line a DILocation names *in one source file*.      Pooling every file's lo (+6 more)

### Community 9 - "use_globals() function"
Cohesion: 0.09
Nodes (27): Arithmetic Operators, Global Variables, Mutability (mut bindings), Operator Precedence / Expression Evaluation, Variable Declarations, bump_global(amount) function, fail(message) function (test_01_variables), main() function (test_01_variables) (+19 more)

### Community 10 - "g2_bench_arena.c"
Cohesion: 0.08
Nodes (55): buildSystem(), countAlive(), countBeyond(), fade(), G1, integrate(), Particle, spawnParticle() (+47 more)

### Community 11 - "bench.py"
Cohesion: 0.43
Nodes (7): main(), pct(), PROCESS_MEMORY_COUNTERS, Run the AIF benchmark set and report to BENCHMARKS 3.2's protocol.      python a, One run: wall milliseconds, and peak working set in MB.      The counters stay r, run_once(), suite()

### Community 12 - "ir_intern"
Cohesion: 0.13
Nodes (20): find_struct(), hash_str(), ir_get_enum_variant(), ir_get_enum_variant_count(), ir_get_enum_variant_name_at(), ir_get_enum_variant_value_at(), ir_get_fn_return_type(), ir_get_struct_field_index() (+12 more)

### Community 13 - "setup_llvm.py"
Cohesion: 0.25
Nodes (20): candidate_roots(), detect_version(), download(), extract(), fetch(), find_existing(), inspect(), lib_names() (+12 more)

### Community 14 - "arena_would_serve"
Cohesion: 0.50
Nodes (5): aif_arena_range_first(), aif_arena_range_last(), aif_auto_arena_at_node(), arena_emit_range(), auto_arena_scope_at_node()

### Community 15 - "cyc_hdr"
Cohesion: 0.24
Nodes (13): CycHeader, cyc_alloc(), cyc_collect(), cyc_collect_now(), cyc_collect_white(), cyc_final(), cyc_free_object(), cyc_hdr() (+5 more)

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
Cohesion: 0.05
Nodes (40): LLVMContextRef, apply_param_attrs(), check_llvm_version(), debug_clear_location(), debug_dispose(), ensure_all_targets(), ensure_context(), ensure_target() (+32 more)

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
Cohesion: 0.14
Nodes (20): diag_add_file(), diag_digits(), diag_emit(), diag_emit_json(), diag_emit_json_summary(), diag_error(), diag_error_at(), diag_finish() (+12 more)

### Community 27 - "test_runner.py"
Cohesion: 0.20
Nodes (10): 1 · The finding that should drive planning, 2 · What holds up as general-purpose, 3 · Where the spec is over-fitted — the 80/20 budget rule, 4 · Regions generalise better than layout, and are under-emphasised, 5 · The biggest hole: closures, 6 · PIR is a heavier liability for general-purpose than for games, 7 · Honest scorecard, 8 · What I would change (+2 more)

### Community 28 - "check_source_lists.py"
Cohesion: 0.20
Nodes (22): Exception, compare(), main(), parse_bracketing(), parse_compiler(), parse_oracle(), parse_threads(), run() (+14 more)

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
Cohesion: 0.17
Nodes (11): All-g old/new — `build/tbaa3` → `build/m6-rc`, Commands, Five-arm standing, Gate, Generated code before timings, It is the instruction, not the layout, M6 slice 2 — ordinary struct-path TBAA, and the g2 regression it caused, The decline, and why it is this line and not g2's (+3 more)

### Community 33 - "Prismio — Bootstrap & Runtime-Linking Architecture Audit"
Cohesion: 0.29
Nodes (6): Prismio — state, map, and what is live, The gate, The map — which file answers which question, Two habits worth keeping, What is live, Where it stands

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
Cohesion: 0.28
Nodes (19): acquire(), AssetCache, buildAssets(), Entity, evictUnused(), G5, loadMaterial(), loadMesh() (+11 more)

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
Nodes (37): aif_call_edge(), aif_call_opaque(), aif_check_pins(), aif_con_arg(), aif_con_bind(), aif_con_borrow(), aif_con_escape_caller(), aif_con_escape_global() (+29 more)

### Community 44 - "main"
Cohesion: 0.67
Nodes (3): Generic Collections (List<T>), fail(message), main()

### Community 45 - "Prismio Toolchain Architecture Refactor — Session Handoff"
Cohesion: 0.40
Nodes (5): 1 · The defect, 2 · Why it did not need a fixed point, 3 · Before / after, 4 · What is still declined, Ownership survives a second return

### Community 46 - "add_binding"
Cohesion: 0.17
Nodes (11): 1.1 What was actually quadratic, 1 · The frontend was quadratic in module size, and is now linear, 2.1 AIF's whole fixed point is 18 ms, 2 · The frontend is 4% of a cold build, 3.0 What a small build is now made of, 3.1 The compiler's own self-build, 3 · Cold and incremental, 4 · The toolchain object cache (+3 more)

### Community 48 - "g2_bench.c"
Cohesion: 0.20
Nodes (27): applyOrders(), Actor, EngTransform, EngVelocity, Bool, Double, Int, World (+19 more)

### Community 49 - "strcmp"
Cohesion: 0.17
Nodes (27): data_view_tbaa_tag(), global_named(), intern_value(), ir_bitcast(), ir_data_load_ptr(), ir_data_store_ptr(), ir_elem_ptr(), ir_extract_value() (+19 more)

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
Cohesion: 0.08
Nodes (21): DWORD, LPVOID, PrismioTask, compiler_prepare_output_path(), append_module_name(), chan_free(), directory_exists(), executable_directory() (+13 more)

### Community 59 - "strncpy"
Cohesion: 0.12
Nodes (17): 1 · The methodological point that matters most, 2.1 Definitions, 2.2 The claim under test, 2.3 False sharing from field insensitivity, 2 · Primary metric: tier distribution, 3.1 B1 is a weak headline and should not be the first result, 3.2 Baselines, 3 · Benchmark programs (+9 more)

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
Cohesion: 0.23
Nodes (13): RtList, arena_alloc_at(), data_view_to_list(), list_copy_elem(), list_inline_enabled(), list_inline_grow(), list_push_grow(), list_push_inline() (+5 more)

### Community 65 - "g4_tuned.rs"
Cohesion: 0.33
Nodes (11): Health, main(), make_world(), Physics, Position, Vec, spawn(), Sprite (+3 more)

### Community 66 - "find_llvm_paths_ex"
Cohesion: 0.20
Nodes (9): 0. The two halves, and why neither ships alone, 1. The circularity, cut the same way M3.1 cut it, 2. `g2.psm`, unannotated, 3. The corpus, 4. What the IR diff is, all of it, 5. The guard, which was not one, 6. What did not change, and is worth knowing, M3.2c-ii + M3.2d — an arena that opens and closes between statements (+1 more)

### Community 67 - "g1_arena.rs"
Cohesion: 0.42
Nodes (10): build_system(), count_alive(), count_beyond(), fade(), integrate(), main(), Particle, Bump (+2 more)

### Community 70 - "g2_cull_probe.c"
Cohesion: 0.33
Nodes (6): a_hdr_pair(), a_hdr_scalar(), a_reg_pair(), a_reg_scalar(), slot_header(), slot_reg()

### Community 71 - "aif_str"
Cohesion: 0.14
Nodes (16): aif_check_placement_pins(), aif_elem_type_at_node(), aif_fn_name(), aif_fn_symbol(), aif_nominal_name(), aif_order_symbol(), aif_profile_source(), aif_region_name_at_site() (+8 more)

### Community 72 - "Code style"
Cohesion: 0.05
Nodes (40): A constant shared across the seam has one spelling everywhere, A returned `String` must be freeable on every path, Allocations returned to Prismio go through `rt_base_alloc`, Before you commit, C code style, Comments, `extern fn` names are the ABI, Files and modules (+32 more)

### Community 73 - "bootstrap.sh"
Cohesion: 0.36
Nodes (5): die(), green(), bootstrap.sh script, resolve_llvm(), step()

### Community 75 - "Engine"
Cohesion: 0.20
Nodes (7): Engine, Does this expression contain `join <name>`?          Stops at any statement kind, The statement list under a block child slot, or [] when absent., Some path through this statement leaves the scope without joining.          `in_, Every path through this statement joins., Every path through this chain joins before control leaves it.          The escap, Mark every `let t = spawn ...` in this chain that is joined before the         c

### Community 76 - "package.sh script"
Cohesion: 0.80
Nodes (4): build_archive(), die(), green(), package.sh script

### Community 77 - "Tier 2 — required by specified AIF features"
Cohesion: 0.07
Nodes (28): 10. Per-module optimisation levels **[specified 2026-08-17, not implemented]**, 11. `verify` build mode **[needed]**, 12. Handles instead of raw pointers **[needed, long-horizon]**, 13. Generic containers — `Map<K,V>`, growable `Vec<T>` — **PARTLY DONE, 2026-08-19**, 14. Error handling — tagged unions, `Option` / `Result` — **DONE, 2026-08-19**, 15. Concurrency / task model — **DONE, 2026-08-19**, 16. Fix superlinear compile time — **DONE, 2026-08-17**, 17. `Int` ↔ `Float` conversion **[minor]** (+20 more)

### Community 84 - "AIF — Workload Declaration, Cost Model, and Layout Search"
Cohesion: 0.07
Nodes (30): 10.1 The cache model has no associativity and no conflict misses, 10.2 `HandleCost` is a placeholder, 10.3 Profiles age, 10.4.1 A fabricated instance count decides the cache tier, and therefore the layout, 10.4 Static frequency estimation is crude, 10.5 One profile, one target, 10 · Known weaknesses, 1 · The key reframing (+22 more)

### Community 85 - "AIF — Design Rationale"
Cohesion: 0.09
Nodes (23): AIF — Design Rationale, Arena placement is a cost decision; `region` is a pin on it, Bake the static region, not the heap, C1, C10, C11, C2, C3 (+15 more)

### Community 87 - "5 · A staged path"
Cohesion: 0.06
Nodes (32): 1 · Headline findings, 2.1 The invariant needs a boundary the spec does not currently draw, 2.2 Structs are affine references, not values, 2 · Frozen items, one by one, 3.1 What isn't behind the seam at all, 3 · The seam, precisely, 4.1 A pass between sema and codegen, 4.2 Scope-based drop (+24 more)

### Community 88 - "1 · AIF core — genuinely ours"
Cohesion: 0.10
Nodes (21): 1 · AIF core — genuinely ours, 2 · AIF's stake in language features it does not own, 3 · Compiler requirements AIF genuinely has, 4 · Measurement, 5 · Not AIF — recorded, then handed over, 6 · Over-built — defer or cut, A3. Realised context counts *(measurement)*, A4. Arena high-water marks *(measurement)* (+13 more)

### Community 89 - "AIF — The FFI Boundary"
Cohesion: 0.10
Nodes (21): 10 · Reporting, 1 · The one place being wrong is unsafe, 2 · C-compatible layout, 3.1 The four cases, 3.2 Copy direction, 3.3 What is never copied, 3 · When a copy is mandatory, 4 · The cost model does the work (+13 more)

### Community 90 - "malloc"
Cohesion: 0.11
Nodes (20): arena_alloc(), arena_alloc_slot(), arena_current_slot(), data_view_add_column(), data_view_begin(), data_view_check_index(), data_view_finish(), int_to_str() (+12 more)

### Community 91 - "AIF — The T4 Cycle Collector"
Cohesion: 0.11
Nodes (18): 10 · What still needs measurement, 1 · What is actually in scope, 2 · The headline result, 3.1 Why trial deletion and not tracing, 3.2 The procedure, 3 · Algorithm, 4 · The cyclic-edge restriction, 5 · Object header (+10 more)

### Community 92 - "AIF — Measurement and Falsification Plan"
Cohesion: 0.19
Nodes (20): now_ms(), run_boxed_aos(), run_boxed_split(), run_chunked_inline(), run_chunked_split(), run_inline_aos(), run_inline_split(), run_soa() (+12 more)

### Community 93 - "PIR — Prism Semantic IR"
Cohesion: 0.13
Nodes (15): 1 · Why bodies must ship, 2.1 Not LLVM IR, 2 · Content model, 3 · Deterministic emission, 4 · Merging, 5.1 Sealed surfaces SHALL publish ownership contracts, 5 · Sealed functions, 6.1 Format versioning (+7 more)

### Community 94 - "aif_solve"
Cohesion: 0.15
Nodes (33): Bits, Deriv, IntVec, aif_argv_push(), aif_solve(), aif_widen(), bits_any(), bits_clear() (+25 more)

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
Cohesion: 0.14
Nodes (16): LLVMBasicBlockRef, block_done(), block_for(), ir_add_checked(), ir_br_numbered(), ir_call_indirect_ptr(), ir_checked_binop(), ir_cond_br_numbered() (+8 more)

### Community 100 - "AIF — Adaptive Inference Framework"
Cohesion: 0.20
Nodes (10): AIF — Adaptive Inference Framework, Conformance is graded, Contents, Running the prototype, Start here, Status, The model in one screen, Two things to know before extending this (+2 more)

### Community 101 - "8.4 Views — slices and element references"
Cohesion: 0.20
Nodes (10): 8.1 Handles, 8.2 The compiler owns layout, 8.3 The static region, 8.4 Views — slices and element references, 8 · Representation, Cost, stated plainly, Element references are views too — the deep consequence, Invalidation, without a borrow checker (+2 more)

### Community 102 - "aif.py"
Cohesion: 0.21
Nodes (13): base_type(), bracket_masks(), elem_key(), main(), measure_masks(), SPEC 5.2.1: per function, may a caller's `region` bracket a call to it?      The, `List<Token>` -> `List`. Field keys are per nominal type, so a generic     conta, A container's contents, as a field key.      Object-insensitive through base_typ (+5 more)

### Community 103 - "nominal_find"
Cohesion: 0.13
Nodes (18): Nominal, aif_layout_field(), aif_layout_rank(), aif_layout_split_select(), aif_reset(), candidate_with_hot(), candidates_clear(), forced_hot_for() (+10 more)

### Community 104 - "5 · Annotations"
Cohesion: 0.22
Nodes (9): 5.0.1 Annotations are assertions, not directives *(normative)*, 5.0 Why exactly these four *(normative rationale)*, 5.1 `unique`, 5.2.1.1 Call-site placement, and which regime it uses *(normative)*, 5.2.1.2 Non-lexical extent, and what it does to the obligations *(normative)*, 5.2.1 A region only reaches allocations in its own function *(normative limitation)*, 5.2 `region { … }`, 5.3 `workload(…)` (+1 more)

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
Cohesion: 0.22
Nodes (9): 1 · The measurement that changed the plan, 2 · What it actually costs on real programs, 3 · Implementation, 4 · A parser defect this found, 5 · The gate, 6 · What this does not do, 7 · Also in this change: the benchmark clock, 8 · Sources (+1 more)

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
Cohesion: 0.18
Nodes (6): ann_leaf_name(), Model, The type an annotation refers to: `[T]` and `List<T>` hang T off c1,     and the, Does a value of this type participate in the memory model at all?, Tarjan-free SCC via iterative Kosaraju on the type reference graph         (INFE, Site

### Community 118 - ".solve"
Cohesion: 0.14
Nodes (10): escape_join(), escape_le(), Flatten a value-set expression against the current points-to state., SPEC 8.4. The collections whose lifetime this value set depends on:         its, SPEC 8.4 E-VIEW:  v is a view of c  =>  E(c) ⊒ E(v).          Applied wherever a, Every rule that writes pt or holders reads only pt, so points-to has         a l, Round-synchronous (Jacobi) iteration, per INFERENCE 5.1: every round         rea, Records s in this round's delta and returns True, so a rule reads         `chang (+2 more)

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
Cohesion: 0.15
Nodes (13): 0 · The diagnosis, and the one thing everybody had backwards, 1 · Close the runtime seam — built, with one deployment decision left, 2 · Reuse analysis — useful only where the program has its trigger shape, 3 · Regions: go non-lexical and polymorphic, 4 · Views and slices — bounded views and mutable data views shipped, 5 · The allocator — measured and closed for the current workload, 6 · The ranked plan, 7 · Measured dead ends — do not re-derive these (+5 more)

### Community 127 - "Profile"
Cohesion: 0.22
Nodes (5): Profile, Collect (owner_type, field, is_write) for every member access in a         subtr, Names incremented by a literal inside the loop -- i.e. the induction         var, Extracted entirely from the AST. Every attribute LAYOUT 2.1 marks     'static, e, Traversal

### Community 128 - "namelist_contains"
Cohesion: 0.25
Nodes (11): NameList, ir_declare_named_type(), ir_is_borrowed(), ir_is_global_name(), ir_is_moved(), ir_mark_borrowed(), ir_mark_moved(), ir_named_type_kind() (+3 more)

### Community 129 - "NEXT-SESSION.md"
Cohesion: 0.25
Nodes (7): 1 · What was wrong, 2 · The rule that replaced it, 3 · Measured, 4 · The two failures on the way, both instructive, 5 · Known limits, measured or explicitly not, 6 · Timing, M2.1a — recursive releases for self-referential types (fork (a))

### Community 130 - "g5.swift"
Cohesion: 0.18
Nodes (15): _di_composite(), _di_nodes(), _di_tuple(), _emitted_struct(), _expected_layout(), Every `!N = ...` line of a module, as {N: text}., The members of a metadata tuple `!{!1, !2, ...}`, as ints., The DICompositeType with this name, and its members as     [(field, offset_bits, (+7 more)

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
Cohesion: 0.18
Nodes (10): 1 · The headline, 2 · Why an escape-lattice change does not move this, 3 · The measurement that was wrong twice, and why, 4 · `region` measured on g2, 5 · What a region *can* serve, 6 · `list_new_with_capacity`, the one speed result, 7 · What would actually close this, 8 · How much call-site bracketing could reach *(2026-08-16)* (+2 more)

### Community 143 - "v0.1 concurrency — the blocking typed `Channel<T>`, and g9's fifth arm"
Cohesion: 0.22
Nodes (8): A data race in `--verify` itself, Commands, g9's fifth arm, Gate, The four rules, and where each is enforced, The surface, Three model changes the feature needed, each found by a failing check, v0.1 concurrency — the blocking typed `Channel<T>`, and g9's fifth arm

### Community 144 - "Session of 2026-08-09 (second) — views: the safety half landed, the speed half was somewhere else"
Cohesion: 0.47
Nodes (9): build_scene(), cull_into(), DrawCmd, main(), make_buffer(), Renderable, Box, Vec (+1 more)

### Community 145 - "five_arm_bench.py"
Cohesion: 0.36
Nodes (8): arms_for(), main(), parse_output(), pct(), (key, label, argv-to-build, exe) for each arm that has a source., One child, its own rusage. Same mechanism as bench.py's run_once., run_once(), spread()

### Community 146 - "optgap.py"
Cohesion: 0.60
Nodes (4): loop_ms(), main(), Median in-process loop time, from the program's own frame samples., sh()

### Community 147 - "RESULTS — the string/parse axis"
Cohesion: 0.06
Nodes (32): 0 · Why this file exists, 1 · The measurement, 2 · What was wrong: `str_substring` rescans the whole buffer, 3 · The compiler itself, 4 · What did *not* move, and why that is the finding, 5 · What this changes about the ranking, RESULTS — the string/parse axis, The fix, and why it is only half of one (+24 more)

### Community 148 - "g7bench.py"
Cohesion: 0.83
Nodes (3): build(), main(), measure()

### Community 149 - "optlevel.py"
Cohesion: 0.83
Nodes (3): loop_ms(), main(), sh()

### Community 150 - "aif_tier_of"
Cohesion: 0.09
Nodes (42): aif_arena_at_node(), aif_cycle_at_node(), aif_elem_owner_at_node(), aif_field_is_counted(), aif_field_is_cyclic(), aif_field_release(), aif_fn_lookup(), aif_fn_may_return_param() (+34 more)

### Community 151 - "Prismio IDE protocol"
Cohesion: 0.50
Nodes (3): Current boundary, JSON diagnostics, Prismio IDE protocol

### Community 152 - "Session of 2026-08-13 — `workload` lands; two of LAYOUT 6's dimensions are not blocked on what the brief said"
Cohesion: 0.08
Nodes (26): 0 · The one-paragraph answer, 10 · Reproducing, 1 · The full matrix, 2 · Prediction → session-3 measurement → now, per axis, 3 · The claim, stated the way the numbers support it, 4 · `region` on g2: session 3's sharpest negative result is fixed, 5.1 · The residual — the only design number, and it held, 5.2 · Executable size — still a large win, and it grew (+18 more)

### Community 153 - "aif_verify_alloc"
Cohesion: 0.38
Nodes (7): aif_ledger_enter(), aif_ledger_leave(), aif_live_hash(), aif_verify_alloc(), aif_verify_arm(), aif_verify_release(), arena_push()

### Community 154 - "LAYOUT 6's candidate space, measured against what this compiler can emit"
Cohesion: 0.11
Nodes (17): 1 · Handles did not land, and two dimensions depend on them, 2.1 · It was built on 2026-08-17, and the corpus does not reproduce the 0.87×, 2.2 · The cost model chose two layouts the measurement rejected, and both reasons are nameable, 2.3 · The compiler self-hosted with a split AST, and then stopped splitting it, 2 · Hot/cold does *not* need handles, and it pays, 3 · Bit-packing is blocked by the specification, not by codegen, 4.1 · Both blockers are gone, and the remaining piece is a search loop, 4 · Empirical validation (LAYOUT §8) is behind §7.2, not behind the runner (+9 more)

### Community 155 - "The cross-language suite — Prismio vs Rust vs Swift"
Cohesion: 0.21
Nodes (16): LLVMValueRef, ir_load_ptr(), ir_store_ptr(), ir_struct_load_ptr(), ir_struct_store_ptr(), scalar_tbaa_tag(), struct_field_tbaa_tag(), struct_record_tbaa_tag() (+8 more)

### Community 156 - "arena_census.py"
Cohesion: 0.39
Nodes (7): blockers_for(), main(), manifest_symbols(), programs(), `--summary`'s own count of placed calls and served sites.      A second, indepen, (records, brackets), or (None, 0) if the program does not build.      `records`, summary_brackets()

### Community 157 - "HANDOFF.md"
Cohesion: 0.24
Nodes (13): cyc_retain(), data_view_release(), list_push(), list_release(), list_set(), rc_alloc(), rc_attach_cold(), rc_cold_slot() (+5 more)

### Community 159 - "build_from_toolchain_sources"
Cohesion: 0.21
Nodes (24): build_from_toolchain_sources(), build_trace_enabled(), build_trace_ms(), build_trace_stage(), compile_ir_to_object(), compiler_bootstrap_executable(), compiler_build_executable(), compiler_temp_obj_path() (+16 more)

### Community 160 - "Session of 2026-08-08 (measurement) — the first cross-language numbers, and the optimiser was never on"
Cohesion: 0.15
Nodes (12): 1 · What this closes, 2 · The defect was documented, deliberate, and had stopped being true, 3 · The mechanism, 4 · The two things that cost the most to find, 5 · The fixture, and how it nearly measured nothing, 6 · Timing, 7 · What is left, measured, Appendix — M2's closing state, 2026-08-23 (+4 more)

### Community 161 - "0.1.0"
Cohesion: 0.20
Nodes (9): 0.1.0, Changelog, Known limits, Language, Memory model, Not in this release, Performance, Standard library (+1 more)

### Community 162 - "v0.1 release candidate — the complete local gate"
Cohesion: 0.25
Nodes (7): Five-arm standing, Per-function mnemonic diff, RC against `build/tbaa3`, Sanitizers, Timings, v0.1 release candidate — the complete local gate, What is *not* proved here, What the gate ran

### Community 164 - "Releasing Prismio"
Cohesion: 0.25
Nodes (7): 0 · The commit, 1 · The local gate — done, 2 · The three-platform matrix — **BLOCKED, needs authorisation**, 3 · Artifacts and checksums, 4 · Clean-environment smoke test, 5 · Tag and publish — **needs explicit authorisation**, Releasing Prismio

### Community 166 - "release_gate.sh"
Cohesion: 0.70
Nodes (4): bad(), ok(), release_gate.sh script, step()

### Community 167 - "Session of 2026-08-17 (second) — §8's forced candidate lands, and the IR differential turns out to have a concurrency hole"
Cohesion: 0.22
Nodes (8): 0. What this session was asked to do, and why it did something else, 1. The census, before, 2. The recorded blocker was a circularity, not a missing obligation, 3. A latent soundness hole, found by turning the feature on, 4. What it buys, measured, 5. Where it does not fire, and why each is correct, 6. Gate, M3.1 — automatic call-site placement reaches a callee's allocations

### Community 168 - "The prompt for the next session"
Cohesion: 0.22
Nodes (25): LLVMMetadataRef, diag_file_count(), diag_file_path(), di_basic(), di_cache(), di_cached(), di_data_element_type(), di_enum_type() (+17 more)

### Community 169 - "Session of 2026-08-08 (measurement) — the first cross-language numbers, and the optimiser was never on"
Cohesion: 0.18
Nodes (10): Debugging Prismio programs, Part 1 — `-g`, Part 2 — where the memory went, and why, See also, The manifest — where each site went, `--verify` — did the inference hold?, What `-g` will not tell you, and why, Which tool answers which question (+2 more)

### Community 171 - "ir_intern"
Cohesion: 0.08
Nodes (34): NamedValue, backend_fail(), coerce_for(), const_from_text(), grow_table(), ir_alloca(), ir_array_alloca(), ir_br() (+26 more)

### Community 172 - "ir_slot_diff.py"
Cohesion: 0.83
Nodes (3): main(), normalise(), slot_names()

### Community 173 - "10 · Boundaries"
Cohesion: 0.67
Nodes (3): 10.1 FFI, 10.2 Library distribution, 10 · Boundaries

### Community 174 - "aif_place_arenas"
Cohesion: 0.11
Nodes (27): LLVMTypeRef, ir_get_struct_field_count(), ir_get_struct_field_type_at(), ir_is_struct_type_name(), attach_cold(), attach_cold_rc(), ir_alloc_cycle(), ir_alloc_object() (+19 more)

### Community 175 - "struct_entry"
Cohesion: 0.06
Nodes (32): 0 · The answer, 10.1 · Emptying a function body without a `deleteBody`, 10.2 · Checked against the tool it replaces, 10.3 · It is also cheaper, 10.4 · The corpus, re-measured after the port, 10 · The merge moves in process, and the last blocker goes, 11.1 · Why neither option was the answer, 11.2 · What the corpus actually still called, and the false lead (+24 more)

### Community 176 - "block_done"
Cohesion: 0.33
Nodes (8): build(), copy_project(), main(), A one-line edit that is a real edit: it changes the text, the AST and the     em, Copy the program *and the modules beside it*.      A corpus program may import a, Time one scenario for every compiler, interleaved. Returns label -> best.      E, scenario(), touch()

### Community 179 - "g3.swift"
Cohesion: 0.18
Nodes (8): SPEC 8.4. Mark `v` as denoting views of `container`. Provenance, not a     point, Abstract evaluation: the set of allocation sites an expression may         denot, What the extern declaration said, or None to fall through.          A declared c, SPEC 5.2.1's bracketing question, at a call: is what this callee does         to, vs_ref(), vs_sites(), vs_union(), vs_view_of()

### Community 180 - "cleanup_files"
Cohesion: 0.07
Nodes (27): cleanup_files(), REQUIREMENTS 10, applied to the one module every build shares: the runtime., The T0 path has to be checked in the IR, not only in the output: falling     bac, AIF Level 5, checked in the IR because neither half shows in a value.      The n, SPEC 8.4's E-VIEW, checked in the manifest and in the IR.      Both halves are l, M4.1's discriminating representation, lifetime, and bounds gate., M4.4: generic clones choose storage only after T is concrete., LAYOUT 3 -- `workload`, and the three normative constraints that are     checkab (+19 more)

### Community 181 - "run_command"
Cohesion: 0.08
Nodes (25): main(), The bootstrap scripts cache toolchain objects, and the key has to be content., `prismio run` with a forward-slash -o path.      Every other test goes through `, INFERENCE 9's required check: an incremental result must equal a cold one., Nothing may take ordinal 0 in NodeKind or TypeKind.      A source check, because, SPEC 6.3's witness path, checked for shape rather than for prose.      The inter, The curated runtime merge is the default and really runs on this host.      The, The task handle has an owner, and only where AIF proved it may.      `prismio_ta (+17 more)

### Community 182 - "manifest_records"
Cohesion: 0.17
Nodes (12): aif_thread_records(), manifest_records(), SPEC 5.4 applied to placement -- `pin(<region-name>)` can fail a build.      **T, SPEC 5.4 -- a honoured pin freezes the tier, and only where the mechanism     ex, symbol -> {column name: value} for every record line in a manifest., symbol -> (tier, thread) from a manifest run., INFERENCE 4.3's thread module, one fixture function per rule.      The `T` domai, SPEC 5.2 / 5.2.1 / 5.2.1.1 -- the arena diagnostics, and which regions the     w (+4 more)

### Community 183 - "5 · The accepted tradeoffs, reported anyway"
Cohesion: 0.33
Nodes (6): Correctness and closure gates, Is Prismio DataView hand-tuned?, M4.3c — mutable DataView round trip, Mutable g1 layout gate, side by side with Rust, Standard-corpus regression gate, What changed

### Community 185 - "run_check_command_test"
Cohesion: 0.31
Nodes (8): The analysis-only IDE boundary and its versioned JSON Lines output., run_check_command_test(), main(), manifest(), Everything the compiler may have left behind that a later run could read., The tier records only: the header carries a budget and a round count, and     `-, records(), wipe_state()

### Community 186 - "test_runner.py"
Cohesion: 0.33
Nodes (6): elide_middle(), `prismio bootstrap` builds a compiler, and the compiler it builds is right., `prismio run --jit`: the same program, without clang and without a link.      `r, Keep both ends of a diagnostic rather than one of them.      Truncating to the l, run_bootstrap_command_test(), run_jit_test()

### Community 187 - "2026-08-19 (payload enums) — `Option`/`Result` are in; exhaustiveness is the hole, and REQUIREMENTS 18 now gates two things"
Cohesion: 0.14
Nodes (17): best_ms(), main(), calloc(), clock_gettime(), clock_mark(), count_calloc(), count_clock(), count_free() (+9 more)

### Community 188 - "The hot element accessor was never curated"
Cohesion: 0.33
Nodes (6): 1 · How it was found, 2 · The defect, 3 · The fix, and why only one of the three, 4 · Before / after, 5 · What this opens up, The hot element accessor was never curated

### Community 189 - "call_edge_push"
Cohesion: 0.11
Nodes (17): 1. Every program that printed a number leaked, 2. g6 was not blocked on the obligation the notes said it was, 2a. Regime (a) asked the wrong question, 2b. Shared-body bit on bodies that allocate nothing, 2c. Every `List` in the program shared one element node, 3. The corpus, 4. Four tests changed meaning, and why that is the system working, 5.1 g3's 4095 — and the recorded cause was wrong (+9 more)

### Community 191 - "run_aif_layout_test"
Cohesion: 0.27
Nodes (3): Scope forest. Each function's body block is a root; join is the LCA,     which e, Where a value assigned to `name` has to stay alive until., Scopes

### Community 192 - "run_aif_struct_field_test"
Cohesion: 0.42
Nodes (10): arena_alloc(), arena_reserve(), arena_reset(), build_scene(), List, cull(), list_init(), list_push() (+2 more)

### Community 193 - "str_split"
Cohesion: 0.25
Nodes (8): 1 · What was actually true before, 2 · What moved, 3.1 What stayed, and why each one did, 3 · Deleted from `lang_runtime.c`, 4 · Cost, measured, 5 · What the migration found, 6 · Gates, The C string layer is gone

### Community 194 - "run_aif_stack_slot_test"
Cohesion: 0.22
Nodes (9): RtProfField, RtProfType, rt_prof_hash(), rt_prof_slot(), rt_prof_type_slot(), rt_profile_alloc(), rt_profile_field(), rt_profile_range() (+1 more)

### Community 195 - "add_binding"
Cohesion: 0.64
Nodes (7): build_scene(), List, cull(), list_init(), list_push(), main(), submit()

### Community 199 - "aif_verify_alloc"
Cohesion: 0.40
Nodes (5): Boundary microbenchmark, Correctness and reproducibility, M4.3a — explicit DataView conversion boundary, Standard milestone benchmark, What landed

### Community 200 - "list_new_cap"
Cohesion: 0.29
Nodes (7): 1 · What the literature actually claims, 2 · Index width is free. Measured, on both targets., 3 · Making overflow UB buys nothing. Measured, on real Prismio programs., 4 · Data width costs 1.33×. Measured, in Prismio., 5 · The cost, stated plainly, 6 · Verdict, `Int` width — the decision, and the three measurements that made it

### Community 203 - "Appendix — M2's closing state, 2026-08-23"
Cohesion: 0.10
Nodes (19): 1 · The bar, 2.1 · Correctness first, 2.2 · The five-arm benchmark, 2 · The gate — after **every** task, no exceptions, 3.1 · Method call syntax — **DONE 2026-08-29**, 3.2 · `impl` blocks — **DONE 2026-08-29**, 3.3 · Traits, and bounded generics — **DONE 2026-08-29**, 3.4 · Closures — **DONE 2026-08-29** (+11 more)

### Community 204 - "xrealloc"
Cohesion: 0.16
Nodes (14): DeclEntry, add_binding(), decl_entry(), ir_decl_at(), ir_decl_count(), ir_index_decl(), ir_register_enum_variant(), ir_register_struct() (+6 more)

### Community 206 - "Session of 2026-08-17 (second) — §8's forced candidate lands, and the IR differential turns out to have a concurrency hole"
Cohesion: 0.33
Nodes (6): Correctness and closure gates, M4.3b — DataView element reads, Next gate, Read-only layout gate, Standard-corpus regression gate, What changed

### Community 207 - "prismio_llvm.h"
Cohesion: 0.15
Nodes (12): LLVMOpaqueAttributeRef, LLVMOpaqueBasicBlock, LLVMOpaqueBuilder, LLVMOpaqueContext, LLVMOpaqueError, LLVMOpaqueMetadata, LLVMOpaqueModule, LLVMOpaquePassBuilderOptions (+4 more)

### Community 211 - "M2.1a — recursive releases for self-referential types (fork (a))"
Cohesion: 0.07
Nodes (54): CallEdge, aif_arena_blockers(), aif_arena_high_water(), aif_arena_unsized_sites(), aif_bracket_callee(), aif_bracket_count(), aif_bracket_scope(), aif_bracket_served() (+46 more)

### Community 212 - "g5.swift"
Cohesion: 0.11
Nodes (21): aif_field_access(), aif_field_has_range(), aif_field_range_bytes(), aif_field_range_hi(), aif_field_range_lo(), aif_is_enum(), aif_is_struct(), aif_layout_field_bytes() (+13 more)

### Community 214 - "Concepts"
Cohesion: 0.07
Nodes (27): Before trusting a single-program number, Debt · a compiler self-hosted on Windows has no export table, Debt · a string literal in a curated runtime function breaks the link, Debt · UMS resolution releases nothing it allocates, Defect · `no_stack` answers two different questions, and one of them wrongly, Docs — part of the gate, not a follow-up, Gate, Is the per-site disposition worth building? Not yet, and the check is one command (+19 more)

### Community 215 - "arena_chunk_new"
Cohesion: 0.26
Nodes (18): concat(), concat_run(), concat_text(), format(), format_int(), format_run(), main(), repeat_text() (+10 more)

### Community 216 - "milestone_bench.py"
Cohesion: 0.22
Nodes (13): aggregate(), build_prismio(), ensure_rust_baselines(), main(), measure_abba(), one(), summarize(), build_prismio() (+5 more)

### Community 219 - "find_binding"
Cohesion: 0.14
Nodes (14): find_binding(), ir_binding_owns_slot(), ir_binding_predates_loop(), ir_get_var_slot(), ir_get_var_type(), ir_has_var_type(), ir_is_list_exclusive(), ir_mark_droppable() (+6 more)

### Community 220 - "struct_entry"
Cohesion: 0.22
Nodes (9): Direct mimalloc result, Direct rpmalloc result, Final gate and decision, Initial dynamic-interposition result, M5.1 — allocator evaluation, Method, Question and acceptance rule, Research choice (+1 more)

### Community 222 - "allocount.c"
Cohesion: 0.29
Nodes (7): list_get(), list_get_inline(), list_slice_get(), list_slice_get_inline(), list_slice_index(), list_slice_set(), list_slice_set_inline()

### Community 223 - "find_struct"
Cohesion: 0.57
Nodes (6): build_all(), command(), main(), measure(), print_results(), sample()

### Community 224 - "Prompt 1 is done — what it unblocked"
Cohesion: 0.67
Nodes (3): main(), String, run()

### Community 225 - "Prompt 2 (residual) — the hot/cold split, and only that"
Cohesion: 0.67
Nodes (3): main(), String, run()

### Community 226 - "run"
Cohesion: 0.67
Nodes (3): main(), String, run()

### Community 227 - "run"
Cohesion: 0.67
Nodes (3): main(), String, run()

### Community 228 - "run"
Cohesion: 0.67
Nodes (3): main(), String, run()

### Community 229 - "run"
Cohesion: 0.67
Nodes (3): main(), String, run()

### Community 230 - "run"
Cohesion: 0.67
Nodes (3): main(), String, run()

### Community 231 - "run"
Cohesion: 0.67
Nodes (3): main(), String, run()

### Community 234 - "M4.1 — first-class `Slice<T>`"
Cohesion: 0.40
Nodes (5): Discriminating gates, M4.1 — first-class `Slice<T>`, Ownership result, Surface and representation, Verification and measurement

### Community 235 - "Prompt 2 (residual) — the hot/cold split, and only that"
Cohesion: 0.25
Nodes (8): 1 · What the standing entry actually named, 2.1 One invocation producing both was measured and rejected, 2 · Why the first step only got half of it, 3 · What is left, and why it is left, 4 · Result, 5 · Gates, 6 · Fails open, and the test that stops it failing open quietly, Genuinely-cold compilation

### Community 236 - "arena_emit_range"
Cohesion: 0.29
Nodes (7): 1 · Result, 2 · The boundary is cheap because the API is handle-based, 3 · Most of the sealing loss is recoverable with contracts, 4 · A prototype bug worth recording, 5 · Compiler bug found: `List<Int>` miscompiles, 6 · What this does not show, AIF — Engine/Game Boundary Results (A2)

### Community 237 - "Prompt 1 is done — what it unblocked"
Cohesion: 0.25
Nodes (8): 1 · Why the item existed, 2.1 The mechanism, and it is not a wash, 2 · Where Prismio stands, 3 · What the program found immediately, 4 · Defect 1 — the task handle had no owner. Fixed., 5 · Defect 2 — a callee-allocated argument still leaks, and it is not about spawn. Open., 6 · Gates, The concurrency axis

### Community 238 - "bracket_place"
Cohesion: 0.09
Nodes (23): emitted_layout_for(), M3.2 -- an arena bracketed between statements rather than at the braces.      `g, LAYOUT 5's cost model ranks hot/cold cuts, and ranks them by cost rather     tha, LAYOUT 6's hot/cold split -- the release half, checked by running it.      A spl, The candidate `--layout` marks `emitted` for one type, as a label string.      R, LAYOUT 8's forced candidate -- `--force-layout=<Type>:<hot>`.      §8 selects a, SPEC 5.2.1 -- the per-function bracketing summary reports the obligations,     a, Build and *run* every benchmark corpus program.      These were not executed by (+15 more)

### Community 239 - "M4.4 — generic/container layout specialization"
Cohesion: 0.33
Nodes (6): Answer: Prismio chooses after substitution, Discriminating gate, Exit, M4.4 — generic/container layout specialization, Performance control, Question

### Community 240 - "Boxed `List` replacement ownership"
Cohesion: 0.50
Nodes (4): Boxed `List` replacement ownership, Discriminator, Gates, Why an exclusive operation

### Community 246 - "An owned call result consumed directly as an argument now has an owner"
Cohesion: 0.25
Nodes (8): 1 · The defect, 2 · The fix, and the three conditions on it, 3 · Before / after, 4 · The discriminator, 5 · What this does not reach, An owned call result consumed directly as an argument now has an owner, `spawn` is excluded structurally, and that is required, The retention guard that was asked for does not exist and is not needed

### Community 247 - "A binding that escapes through a callee's return was freed under its caller"
Cohesion: 0.25
Nodes (8): 1 · The defect, 2 · Which escape routes were already guarded, and which was not, 3 · The fix, 4 · Before / after, 5 · What is still open, 6 · Sources, A binding that escapes through a callee's return was freed under its caller, Two things that were measured, not reasoned

### Community 248 - "A payload-free enum variant allocated uninitialised memory"
Cohesion: 0.33
Nodes (6): 1 · What the matrix saw, and what this host did not, 2 · The defect, 3 · The fix, 4 · Before / after, 5 · What to check next, A payload-free enum variant allocated uninitialised memory

### Community 249 - "ir_jit_run_main"
Cohesion: 0.47
Nodes (6): LLVMErrorRef, LLVMOrcLLJITRef, ir_jit_run_main(), jit_failed(), jit_failed_unresolved(), jit_process_symbols_visible()

### Community 250 - "aif_records"
Cohesion: 0.33
Nodes (6): aif_records(), SPEC 5's annotations, read back out of the manifest.      test_46 running clean, symbol -> (tier, was_widened, origin) from a manifest run.      The columns are, INFERENCE 5.3: truncating the ascending iteration yields a *pre*-fixed     point, run_aif_annotation_test(), run_aif_widening_test()

## Ambiguous Edges - Review These
- `Test naming convention (test_<NN>_<description>.psm)` → `fn main() -> Int`  [AMBIGUOUS]
  CONTRIBUTING.md · relation: conceptually_related_to

## Knowledge Gaps
- **830 isolated node(s):** `Darwin`, `Foundation`, `LLVMOpaqueContext`, `LLVMOpaqueModule`, `LLVMOpaqueType` (+825 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Test naming convention (test_<NN>_<description>.psm)` and `fn main() -> Int`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `free()` connect `AIF — Measurement and Falsification Plan` to `g6_bench.c`, `ir_symbols.c`, `free`, `lang_runtime.c`, `cyc_hdr`, `aif_tier_of`, `aif_verify_alloc`, `diagnostics.c`, `build_from_toolchain_sources`, `The prompt for the next session`, `g4.swift`, `2026-08-19 (payload enums) — `Option`/`Result` are in; exhaustiveness is the hole, and REQUIREMENTS 18 now gates two things`, `run_aif_struct_field_test`, `add_binding`, `xrealloc`, `M2.1a — recursive releases for self-referential types (fork (a))`, `arena_chunk_new`, `aif_solve`, `nominal_find`?**
  _High betweenness centrality (0.118) - this node is a cross-community bridge._
- **Why does `di_enum_type()` connect `The prompt for the next session` to `AIF — Measurement and Falsification Plan`, `ir_intern`, `llvm-api-backend.c`?**
  _High betweenness centrality (0.059) - this node is a cross-community bridge._
- **Why does `malloc()` connect `AIF — Measurement and Falsification Plan` to `run_aif_struct_field_test`, `malloc`, `g6_bench.c`, `add_binding`, `free`, `g4.swift`, `The prompt for the next session`, `ir_intern`, `xrealloc`, `cyc_hdr`, `arena_chunk_new`, `aif_verify_alloc`, `diagnostics.c`, `2026-08-19 (payload enums) — `Option`/`Result` are in; exhaustiveness is the hole, and REQUIREMENTS 18 now gates two things`, `build_from_toolchain_sources`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._
- **Are the 73 inferred relationships involving `free()` (e.g. with `arena_reserve()` and `main()`) actually correct?**
  _`free()` has 73 INFERRED edges - model-reasoned connections that need verification._
- **Are the 57 inferred relationships involving `malloc()` (e.g. with `arena_reserve()` and `build_scene()`) actually correct?**
  _`malloc()` has 57 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Darwin`, `Foundation`, `LLVMOpaqueContext` to the rest of the system?**
  _830 weakly-connected nodes found - possible documentation gaps or missing edges._