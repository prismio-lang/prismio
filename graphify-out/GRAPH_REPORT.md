# Graph Report - self  (2026-08-06)

## Corpus Check
- 61 files · ~157,713 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1647 nodes · 2880 edges · 128 communities (105 shown, 23 thin omitted)
- Extraction: 92% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 213 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2e2dc025`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- fn sema_expr(module, expr) -> TypeInfo
- fn create_node(kind) -> ASTNode
- xmalloc
- ir_symbols.c
- build_driver.c
- lang_runtime.c
- fn generate_expression(expr) -> String
- Borrow Checking
- Prismio — Compiler Audit
- use_globals() function
- fn generate_statement(stmt)
- extern fn ptr_to_node
- extern fn str_equals
- setup_llvm.py
- fn sema_annotation_type(module, tn) -> TypeInfo
- fn lexer_next_token(lex) -> Token
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
- strlen
- main
- Struct (Custom Data Type) Declarations
- aif_arena_at_node
- main() function (test_07_booleans)
- main() function (test_02_if_else)
- main
- fibonacci(n) function
- main() function (test_11_returns)
- aif_support.c
- main
- Prismio Toolchain Architecture Refactor — Session Handoff
- malloc
- extern fn ir_br
- extern fn ir_comment
- extern fn ir_cond_br
- extern fn ir_get_label_name
- extern fn ir_label
- extern fn ir_neg
- extern fn ir_print
- extern fn ir_type_i1
- extern fn ir_type_i32
- extern fn ir_type_i64
- extern fn ir_type_i8
- extern fn ir_type_i8_ptr
- extern fn ir_type_void
- program_support.c
- Parser struct (current: Token ptr)
- Building Prismio on macOS (and Linux)
- TypeKind enum
- extern fn str_contains
- extern fn str_index_of
- extern fn str_to_int
- struct Counter
- struct Res
- Handoff — continuing the Prismio work
- aif_str
- CLAUDE.md
- bootstrap.sh
- verify_separation.sh
- Engine
- package.sh script
- Tier 2 — required by specified AIF features
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
- vs_push
- AIF Corpus
- 6 · The tier manifest
- Profile

## God Nodes (most connected - your core abstractions)
1. `fn generate_expression(expr) -> String` - 55 edges
2. `extern fn ptr_to_node` - 42 edges
3. `malloc()` - 39 edges
4. `main()` - 37 edges
5. `fn generate_statement(stmt)` - 36 edges
6. `fn sema_annotation_type(module, tn) -> TypeInfo` - 33 edges
7. `strlen()` - 32 edges
8. `fn sema_expr(module, expr) -> TypeInfo` - 32 edges
9. `fn generate_module(module)` - 29 edges
10. `type_from_key()` - 28 edges

## Surprising Connections (you probably didn't know these)
- `Claim: no dedicated semantic analysis pass (planned)` --references--> `fn analyze_module(module)`  [AMBIGUOUS]
  CONTRIBUTING.md → src/sema.psm
- `Claim: no semantic analysis pass between parsing and IR gen (planned)` --references--> `fn analyze_module(module)`  [AMBIGUOUS]
  README.MD → src/sema.psm
- `Test naming convention (test_<NN>_<description>.psm)` --conceptually_related_to--> `fn main() -> Int`  [AMBIGUOUS]
  CONTRIBUTING.md → src/main.psm
- `diag_reset()` --calls--> `free()`  [INFERRED]
  runtime/diagnostics.c → runtime/lang_runtime.c
- `Prismio Project Structure (src/ layout)` --references--> `fn generate_module(module)`  [EXTRACTED]
  CONTRIBUTING.md → src/ir.psm

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Prismio self-hosted compiler pipeline (lexer -> parser -> import resolver -> sema -> IR generator)** — src_lexer_lex_all_tokens, src_parser_parse_module, src_main_resolve_imports, src_sema_analyze_module, src_ir_generate_module [EXTRACTED 1.00]
- **Move/borrow/drop ownership system (sink/inout params, struct move-only values, drop())** — src_types_type_is_move_only, src_sema_sema_move_operand, src_bridge_ir_mark_moved, src_bridge_ir_is_borrowed, src_ir_generate_expression [INFERRED 0.85]
- **Negative tests validating move/drop/borrow ownership checking** — tests_neg_03_use_after_move_main, tests_neg_04_use_after_drop_main, tests_neg_05_drop_borrow_main [INFERRED 0.85]
- **Negative tests validating semantic/type checking (type mismatch, integer width, duplicate overload)** — tests_neg_01_type_mismatch_bad_value, tests_neg_02_int_width_main, tests_neg_06_duplicate_overload_same [INFERRED 0.75]
- **Shared fail(message) test-harness helper pattern across feature tests** — tests_test_01_variables_fail, tests_test_02_if_else_fail, tests_test_03_while_loops_fail, tests_test_04_structs_fail, tests_test_05_enums_fail, tests_test_06_recursion_fail, tests_test_07_booleans_fail, tests_test_08_mutability_fail, tests_test_09_strings_fail, tests_test_10_expressions_fail, tests_test_11_returns_fail, tests_test_12_imports_fail, tests_test_13_globals_fail [INFERRED 0.95]
- **Prismio Ownership System (Move/Drop/Borrow) Demonstration** — tests_test_23_move_main, tests_test_24_drop_main, tests_test_25_conventions_main, tests_test_26_borrow_reuse_main [INFERRED 0.85]

## Communities (128 total, 23 thin omitted)

### Community 0 - "fn sema_expr(module, expr) -> TypeInfo"
Cohesion: 0.13
Nodes (32): extern fn ir_clear_borrowed, extern fn ir_clear_local_var_types, extern fn ir_clear_moved, extern fn ir_has_var_type, extern fn ir_is_borrowed, extern fn ir_is_moved, extern fn ir_mark_borrowed, extern fn ir_mark_moved (+24 more)

### Community 1 - "fn create_node(kind) -> ASTNode"
Cohesion: 0.07
Nodes (73): Contributor Covenant Code of Conduct, Conventional Commits convention, Prismio Project Structure (src/ layout), Claim: no dedicated semantic analysis pass (planned), Test naming convention (test_<NN>_<description>.psm), POST_INSTALL.txt (install success message), Documented Compiler Pipeline (README architecture diagram), Contributor Covenant (README reference) (+65 more)

### Community 2 - "xmalloc"
Cohesion: 0.29
Nodes (8): aif_oom(), aif_site_note_node(), aif_type_acyclic(), nominal_find_id(), solver_alloc(), type_acyclic_id(), xcalloc(), xmalloc()

### Community 3 - "ir_symbols.c"
Cohesion: 0.05
Nodes (43): NameList, add_binding(), drop_index(), find_binding(), find_struct(), hash_str(), ir_binding_predates_loop(), ir_declare_named_type() (+35 more)

### Community 4 - "build_driver.c"
Cohesion: 0.18
Nodes (29): FILE, accept_if_exists(), build_from_toolchain_sources(), compile_ir_to_object(), compiler_bootstrap_executable(), compiler_build_executable(), compiler_prepare_output_path(), compiler_run_executable() (+21 more)

### Community 5 - "lang_runtime.c"
Cohesion: 0.05
Nodes (24): Array, ir_clear_local_var_types(), aif_live_hash(), aif_verify_alloc(), aif_verify_release(), arena_pop(), array_free(), array_get() (+16 more)

### Community 6 - "fn generate_expression(expr) -> String"
Cohesion: 0.06
Nodes (39): extern fn ir_and, extern fn ir_call_arg, extern fn ir_call_begin, extern fn ir_call_end, extern fn ir_fadd, extern fn ir_fcmp_oeq, extern fn ir_fcmp_oge, extern fn ir_fcmp_ogt (+31 more)

### Community 7 - "Borrow Checking"
Cohesion: 0.08
Nodes (30): Borrow Checking, Drop Semantics, Move Semantics, Parameter Passing Conventions (borrow/inout/sink), Struct Types, main() function (neg_03_use_after_move), struct Point (neg_03_use_after_move), main() function (neg_04_use_after_drop) (+22 more)

### Community 8 - "Prismio — Compiler Audit"
Cohesion: 0.07
Nodes (26): 0. Headline, 1.10 MEDIUM — `%` is rejected on every sized integer type — **FIXED**, 1.11 MEDIUM — Global initializers are dropped unless they're literals — **FIXED**, 1.12 LOW — `print_bool` is declared `i32` and called with `i1` — **FIXED**, 1.1 CRITICAL — String literals inside `for` / `loop` / `match` bodies are never emitted — **FIXED**, 1.2 CRITICAL — `and` / `or` do not short-circuit — **FIXED**, 1.3 CRITICAL — No mutability enforcement whatsoever, 1.4 CRITICAL — No block scoping; locals shadowing globals read the global (+18 more)

### Community 9 - "use_globals() function"
Cohesion: 0.09
Nodes (27): Arithmetic Operators, Global Variables, Mutability (mut bindings), Operator Precedence / Expression Evaluation, Variable Declarations, bump_global(amount) function, fail(message) function (test_01_variables), main() function (test_01_variables) (+19 more)

### Community 10 - "fn generate_statement(stmt)"
Cohesion: 0.07
Nodes (37): extern fn ir_add, extern fn ir_alloca, extern fn ir_append, extern fn ir_append_line, extern fn ir_br_numbered, extern fn ir_clear_returned, extern fn ir_cond_br_numbered, extern fn ir_function_begin (+29 more)

### Community 11 - "extern fn ptr_to_node"
Cohesion: 0.09
Nodes (39): extern fn ptr_to_node, extern fn ir_blank_line, extern fn ir_clear_var_types, extern fn ir_declare_function_begin, extern fn ir_declare_function_end, extern fn ir_declare_function_param, extern fn ir_global_string, extern fn ir_global_var (+31 more)

### Community 12 - "extern fn str_equals"
Cohesion: 0.16
Nodes (22): fn fn_key(name) -> String, fn ir_ptr_int_type() -> String, fn map_type(t) -> String, fn struct_type_key(name) -> String, fn sema_find_function(module, name) -> ASTNode, fn sema_fn_key(name) -> String, fn sema_function_symbol(module, fn_node) -> String, fn sema_function_symbol_count(module, symbol) -> Int (+14 more)

### Community 13 - "setup_llvm.py"
Cohesion: 0.25
Nodes (20): candidate_roots(), detect_version(), download(), extract(), fetch(), find_existing(), inspect(), lib_names() (+12 more)

### Community 14 - "fn sema_annotation_type(module, tn) -> TypeInfo"
Cohesion: 0.17
Nodes (32): fn struct_type_name(t) -> String, fn sema_annotation_type(module, tn) -> TypeInfo, fn sema_builtin_call_type(name, arg_ptr) -> TypeInfo, fn type_array, fn type_bool() -> TypeInfo, fn type_char() -> TypeInfo, fn type_enum, fn type_float() -> TypeInfo (+24 more)

### Community 15 - "fn lexer_next_token(lex) -> Token"
Cohesion: 0.18
Nodes (15): fn is_boolean(s) -> Bool, fn lexer_advance(lex), fn lexer_current(lex) -> Char, fn lexer_next_token(lex) -> Token, fn lexer_peek(lex, offset) -> Char, fn lexer_skip_whitespace(lex), fn char_code(c) -> Int, extern fn int_to_str (+7 more)

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
Cohesion: 0.06
Nodes (82): LLVMBasicBlockRef, LLVMTypeRef, LLVMValueRef, NamedValue, strcmp(), backend_fail(), block_done(), block_for() (+74 more)

### Community 23 - "Enum Types"
Cohesion: 0.24
Nodes (11): Enum Types, Pattern Matching (match expressions), enum Color, enum ExitCode, fail(message) function (test_05_enums), main() function (test_05_enums), classify(n), enum Color (+3 more)

### Community 24 - "main"
Cohesion: 0.15
Nodes (13): String Runtime (extern str_* FFI functions), fail(message), extern fn int_to_str, main(), extern fn str_char_at, extern fn str_concat, extern fn str_contains, extern fn str_equals (+5 more)

### Community 25 - "layout.py"
Cohesion: 0.26
Nodes (13): candidates(), field_align(), field_width(), Layout, main(), min_size(), mu_for(), grouping in {AoS, SoA, AoSoA(w)}; `hot` is the field subset kept in the primary… (+5 more)

### Community 26 - "diagnostics.c"
Cohesion: 0.18
Nodes (11): diag_digits(), diag_emit(), diag_error(), diag_error_at(), diag_line_length(), diag_line_start(), diag_note_at(), diag_render_span() (+3 more)

### Community 27 - "test_runner.py"
Cohesion: 0.15
Nodes (25): aif_records(), cleanup_files(), compile_prismio_file(), expected_errors(), main(), Substrings the diagnostics must contain, from `// expect-error:` lines. Without…, `prismio run` with a forward-slash -o path. Every other test goes through…, Nothing may take ordinal 0 in NodeKind or TypeKind. A source check, because the… (+17 more)

### Community 28 - "check_source_lists.py"
Cohesion: 0.21
Nodes (20): Exception, compare(), main(), parse_compiler(), parse_oracle(), run(), bootstrap_ps1_list(), bootstrap_sh_list() (+12 more)

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

### Community 34 - "strlen"
Cohesion: 0.16
Nodes (18): compiler_default_exe_path(), path_without_extension(), run_command_path(), str_char_at(), str_clone(), str_concat(), str_ends_with(), str_length() (+10 more)

### Community 35 - "main"
Cohesion: 0.47
Nodes (5): Array Types (1D/2D indexing), array_sum(), fail(message), main(), matrix_diagonal()

### Community 36 - "Struct (Custom Data Type) Declarations"
Cohesion: 0.40
Nodes (6): Struct (Custom Data Type) Declarations, struct Parser, struct Token, struct Point, struct Point, struct Item

### Community 37 - "aif_arena_at_node"
Cohesion: 0.24
Nodes (12): aif_arena_at_node(), aif_frees_at_scope_node(), aif_region_name_at_site(), aif_tier_at_node(), aif_tier_of(), enclosing_region(), escape_join(), fits_on_stack() (+4 more)

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
Cohesion: 0.05
Nodes (11): aif_con_arg(), aif_con_bind(), aif_con_borrow(), aif_con_escape_caller(), aif_con_escape_global(), aif_con_live_in(), aif_con_no_stack(), aif_con_opaque() (+3 more)

### Community 44 - "main"
Cohesion: 0.67
Nodes (3): Generic Collections (List<T>), fail(message), main()

### Community 45 - "Prismio Toolchain Architecture Refactor — Session Handoff"
Cohesion: 0.15
Nodes (12): Confirmed design decisions (from this session's clarifying questions — do not re-ask these), Kickoff prompt for the new session, Phase 1 — Import memoization + driver.c split (foundational, do this first), Phase 2 — Library packaging + Mode 1 (installed-toolchain discovery), Phase 3 — `prismio bootstrap` command + Mode 2 + hash-based freshness, Phase 4 — Backend boundary cleanup, Phase 5 — Tests, docs, architecture report, Prismio Toolchain Architecture Refactor — Session Handoff (+4 more)

### Community 46 - "malloc"
Cohesion: 0.14
Nodes (16): ArenaChunk, compiler_installed_runtime_hash(), diag_add_file(), diag_strdup(), arena_alloc(), arena_chunk_new(), list_new(), list_push() (+8 more)

### Community 61 - "program_support.c"
Cohesion: 0.24
Nodes (5): executable_directory(), execute_command(), get_directory(), join_path(), prismio_executable_directory()

### Community 63 - "Building Prismio on macOS (and Linux)"
Cohesion: 0.20
Nodes (9): Build it, Building Prismio on macOS (and Linux), Check you reached a fixed point, Cross-compiling from Windows, Refreshing the seed, Test, package, verify, Troubleshooting, What you need (+1 more)

### Community 70 - "Handoff — continuing the Prismio work"
Cohesion: 0.25
Nodes (7): Current state, File roles, Five rules learned the hard way, Handoff — continuing the Prismio work, Known gaps, documented rather than fixed, What's next, Workflow — do this for every change

### Community 71 - "aif_str"
Cohesion: 0.29
Nodes (7): aif_fn_name(), aif_fn_symbol(), aif_nominal_name(), aif_order_symbol(), aif_site_type(), aif_str(), record_cmp()

### Community 73 - "bootstrap.sh"
Cohesion: 0.53
Nodes (4): die(), green(), bootstrap.sh script, step()

### Community 75 - "Engine"
Cohesion: 0.19
Nodes (7): Engine, Does a value of this type participate in the memory model at all?, Abstract evaluation: the set of allocation sites an expression may denote.…, What the extern declaration said, or None to fall through. A declared contract…, Where a value assigned to `name` has to stay alive until., vs_sites(), vs_union()

### Community 76 - "package.sh script"
Cohesion: 0.80
Nodes (4): build_archive(), die(), green(), package.sh script

### Community 77 - "Tier 2 — required by specified AIF features"
Cohesion: 0.07
Nodes (28): 10. Per-module optimisation levels **[needed]**, 11. `verify` build mode **[needed]**, 12. Handles instead of raw pointers **[needed, long-horizon]**, 13. Generic containers — `Map<K,V>`, growable `Vec<T>` **[enabling]**, 14. Error handling — tagged unions, `Option` / `Result` **[enabling]**, 15. Concurrency / task model **[needed for `T`]**, 16. Fix superlinear compile time **[enabling]**, 17. `Int` ↔ `Float` conversion **[minor]** (+20 more)

### Community 84 - "AIF — Workload Declaration, Cost Model, and Layout Search"
Cohesion: 0.07
Nodes (28): 10.1 The cache model has no associativity and no conflict misses, 10.2 `HandleCost` is a placeholder, 10.3 Profiles age, 10.4 Static frequency estimation is crude, 10.5 One profile, one target, 10 · Known weaknesses, 1 · The key reframing, 2.1 Contents (+20 more)

### Community 85 - "AIF — Design Rationale"
Cohesion: 0.09
Nodes (22): AIF — Design Rationale, Arena placement is a cost decision; `region` is a pin on it, Bake the static region, not the heap, C1, C10, C2, C3, C4 (+14 more)

### Community 87 - "5 · A staged path"
Cohesion: 0.09
Nodes (23): 1 · Headline findings, 2.1 The invariant needs a boundary the spec does not currently draw, 2.2 Structs are affine references, not values, 2 · Frozen items, one by one, 3.1 What isn't behind the seam at all, 3 · The seam, precisely, 4.1 A pass between sema and codegen, 4.2 Scope-based drop (+15 more)

### Community 88 - "1 · AIF core — genuinely ours"
Cohesion: 0.10
Nodes (21): 1 · AIF core — genuinely ours, 2 · AIF's stake in language features it does not own, 3 · Compiler requirements AIF genuinely has, 4 · Measurement, 5 · Not AIF — recorded, then handed over, 6 · Over-built — defer or cut, A3. Realised context counts *(measurement)*, A4. Arena high-water marks *(measurement)* (+13 more)

### Community 89 - "AIF — The FFI Boundary"
Cohesion: 0.10
Nodes (21): 10 · Reporting, 1 · The one place being wrong is unsafe, 2 · C-compatible layout, 3.1 The four cases, 3.2 Copy direction, 3.3 What is never copied, 3 · When a copy is mandatory, 4 · The cost model does the work (+13 more)

### Community 90 - "aif_intern"
Cohesion: 0.11
Nodes (27): aif_enum_new(), aif_extern_contract(), aif_extern_contract_set(), aif_fn_lookup(), aif_fn_new(), aif_intern(), aif_key_field(), aif_key_param() (+19 more)

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
Cohesion: 0.17
Nodes (24): Bits, IntVec, aif_argv_push(), aif_compute_type_acyclic(), aif_reset(), aif_site_widened(), aif_solve(), aif_widen() (+16 more)

### Community 95 - "AIF — Level 0 Results"
Cohesion: 0.17
Nodes (12): 1 · Headline, 2 · The finding: one decision accounts for the entire residue, 3 · What the game corpus showed that the compiler could not, 3a · Handles appear to eliminate T3 in engine code, 4.1 `retain_in(k)` is missing from FFI.md's contract vocabulary, 4.2 The cycle collector has no program that can exercise it, 4 · Two spec gaps the run found, 5 · Secondary measurements (+4 more)

### Community 96 - "AIF — The Target Workload"
Cohesion: 0.17
Nodes (12): 0.1 · Engine and game remain two workloads, 0 · The actual stack, 1 · The two halves, 2.1 The annotations belong to the engine layer, 2.2 T3 lives in the engine, T0–T2 in the game, 2.3 The engine/game boundary is where whole-program analysis must hold, 2.4 The manifest becomes a contract between teams, 2.5 Optimisation level has to be **per module**, not per build (+4 more)

### Community 97 - "AIF — Adaptive Inference Framework"
Cohesion: 0.18
Nodes (11): 0 · Conformance language, 10.1 FFI, 10.2 Library distribution, 10 · Boundaries, 12 · What this model gives up *(informative)*, 1.1 What the invariant does not cover, 1 · The invariant, 9.1 Layout search (+3 more)

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
Cohesion: 0.20
Nodes (11): escape_join(), escape_le(), main(), measure_masks(), Scope forest. Each function's body block is a root; join is the LCA, which…, Least upper bound on Region(s) < Caller < Global., H4 leading indicator: how many of a function's reference parameters can…, report() (+3 more)

### Community 103 - "nominal_find"
Cohesion: 0.33
Nodes (6): aif_is_enum(), aif_is_struct(), aif_struct_nfields(), aif_struct_size(), aif_type_edge(), nominal_find()

### Community 104 - "5 · Annotations"
Cohesion: 0.22
Nodes (9): 5.0 Why exactly these four *(normative rationale)*, 5.1 `unique`, 5.2 `region { … }`, 5.3 `workload(…)`, 5.4.1 A proven-false pin is a compile error, 5.4.2 An unproven pin is never an error, 5.4.3 Strictness is opt-in, per value, 5.4 `pin` (+1 more)

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
Cohesion: 0.17
Nodes (6): ann_leaf_name(), Model, The type an annotation refers to: `[T]` and `List<T>` hang T off c1, and their…, Tarjan-free SCC via iterative Kosaraju on the type reference graph (INFERENCE…, Site, Traversal

### Community 118 - ".solve"
Cohesion: 0.20
Nodes (5): Flatten a value-set expression against the current points-to state., Every rule that writes pt or holders reads only pt, so points-to has a least…, Round-synchronous (Jacobi) iteration, per INFERENCE 5.1: every round reads the…, Records s in this round's delta and returns True, so a rule reads `changed =…, INFERENCE 5.3: a truncated ascending iteration is a *pre*-fixed point and is…

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
Cohesion: 0.40
Nodes (5): 7.1 Requirement, 7.2 Levels, 7.3 `verify` — facts as runtime assertions, 7.4 Layout search is opt-in, 7 · Two-speed compilation

### Community 124 - "vs_push"
Cohesion: 0.40
Nodes (5): aif_vs_key(), aif_vs_new(), aif_vs_site(), aif_vs_union(), vs_push()

### Community 125 - "AIF Corpus"
Cohesion: 0.50
Nodes (4): AIF Corpus, Building, Gaps to fill, Three things the corpus established

### Community 126 - "6 · The tier manifest"
Cohesion: 0.50
Nodes (4): 6.1 Purpose, 6.2 Format, 6.3 Diff semantics, 6 · The tier manifest

### Community 127 - "Profile"
Cohesion: 0.31
Nodes (4): Profile, Collect (owner_type, field, is_write) for every member access in a subtree.…, Names incremented by a literal inside the loop -- i.e. the induction variables.…, Extracted entirely from the AST. Every attribute LAYOUT 2.1 marks 'static,…

## Ambiguous Edges - Review These
- `Claim: no dedicated semantic analysis pass (planned)` → `fn analyze_module(module)`  [AMBIGUOUS]
  CONTRIBUTING.md · relation: references
- `Test naming convention (test_<NN>_<description>.psm)` → `fn main() -> Int`  [AMBIGUOUS]
  CONTRIBUTING.md · relation: conceptually_related_to
- `Claim: no semantic analysis pass between parsing and IR gen (planned)` → `fn analyze_module(module)`  [AMBIGUOUS]
  README.MD · relation: references

## Knowledge Gaps
- **558 isolated node(s):** `1.1 Pipeline trace: `prismio build file.psm` → executable`, `1.2 How runtime libraries are included: embedded, external, or both?`, `1.3 Every file and function responsible`, `2.1 What happens when the compiler compiles itself (`prismio build src/main.psm`)?`, `2.2 Duplicate runtime linkage — two separate risks, at two separate layers` (+553 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **23 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Claim: no dedicated semantic analysis pass (planned)` and `fn analyze_module(module)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Test naming convention (test_<NN>_<description>.psm)` and `fn main() -> Int`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Claim: no semantic analysis pass between parsing and IR gen (planned)` and `fn analyze_module(module)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `strcmp()` connect `llvm-api-backend.c` to `strlen`, `ir_symbols.c`, `build_driver.c`, `lang_runtime.c`, `aif_str`, `malloc`, `aif_intern`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **Why does `AIF — Adaptive Inference Framework` connect `AIF — Adaptive Inference Framework` to `8.4 Views — slices and element references`, `5 · Annotations`, `11 · Conformance boundary`, `3 · The tier ladder`, `RESULTS-L0-tiers.md`, `2 · The objects of the model`, `4 · Tier derivation`, `7 · Two-speed compilation`, `6 · The tier manifest`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Why does `aif_intern()` connect `aif_intern` to `xmalloc`, `strlen`, `lang_runtime.c`, `nominal_find`, `aif_support.c`, `llvm-api-backend.c`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Are the 22 inferred relationships involving `malloc()` (e.g. with `xmalloc()` and `build_from_toolchain_sources()`) actually correct?**
  _`malloc()` has 22 INFERRED edges - model-reasoned connections that need verification._