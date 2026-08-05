# Graph Report - self  (2026-08-01)

## Corpus Check
- 36 files · ~66,643 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 962 nodes · 1869 edges · 84 communities (61 shown, 23 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 199 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `985d3616`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- fn sema_annotation_type(module, tn) -> TypeInfo
- fn create_node(kind) -> ASTNode
- fn compile_source(path, output_file, run_after_build) -> Int
- ir_symbols.c
- build_driver.c
- lang_runtime.c
- fn generate_expression(expr) -> String
- Borrow Checking
- Prismio — Compiler Audit
- use_globals() function
- fn generate_statement(stmt)
- fn generate_module(module)
- extern fn ptr_to_node
- setup_llvm.py
- CONTRIBUTING.md
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
- fn resolve_imports(module, base_dir) -> ASTNode
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
- fn main() -> Int
- main() function (test_07_booleans)
- main() function (test_02_if_else)
- main
- fibonacci(n) function
- main() function (test_11_returns)
- Prismio Project Structure (src/ layout)
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
- fn generate_struct_decl(struct_node)
- CLAUDE.md
- bootstrap.sh
- verify_separation.sh
- Documented Compiler Pipeline (README architecture diagram)
- package.sh script
- fn get_expr_type(expr) -> String
- die

## God Nodes (most connected - your core abstractions)
1. `fn generate_expression(expr) -> String` - 55 edges
2. `extern fn ptr_to_node` - 42 edges
3. `main()` - 37 edges
4. `fn generate_statement(stmt)` - 36 edges
5. `malloc()` - 35 edges
6. `fn sema_annotation_type(module, tn) -> TypeInfo` - 33 edges
7. `fn sema_expr(module, expr) -> TypeInfo` - 32 edges
8. `strlen()` - 31 edges
9. `fn generate_module(module)` - 29 edges
10. `type_from_key()` - 27 edges

## Surprising Connections (you probably didn't know these)
- `Claim: no dedicated semantic analysis pass (planned)` --references--> `fn analyze_module(module)`  [AMBIGUOUS]
  CONTRIBUTING.md → src/sema.psm
- `Test naming convention (test_<NN>_<description>.psm)` --conceptually_related_to--> `fn main() -> Int`  [AMBIGUOUS]
  CONTRIBUTING.md → src/main.psm
- `Claim: no semantic analysis pass between parsing and IR gen (planned)` --references--> `fn analyze_module(module)`  [AMBIGUOUS]
  README.MD → src/sema.psm
- `diag_reset()` --calls--> `free()`  [INFERRED]
  runtime/diagnostics.c → runtime/lang_runtime.c
- `Prismio Project Structure (src/ layout)` --references--> `LLVM Bridge FFI declarations (bridge.psm)`  [EXTRACTED]
  CONTRIBUTING.md → src/bridge.psm

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Prismio self-hosted compiler pipeline (lexer -> parser -> import resolver -> sema -> IR generator)** — src_lexer_lex_all_tokens, src_parser_parse_module, src_main_resolve_imports, src_sema_analyze_module, src_ir_generate_module [EXTRACTED 1.00]
- **Move/borrow/drop ownership system (sink/inout params, struct move-only values, drop())** — src_types_type_is_move_only, src_sema_sema_move_operand, src_bridge_ir_mark_moved, src_bridge_ir_is_borrowed, src_ir_generate_expression [INFERRED 0.85]
- **Negative tests validating move/drop/borrow ownership checking** — tests_neg_03_use_after_move_main, tests_neg_04_use_after_drop_main, tests_neg_05_drop_borrow_main [INFERRED 0.85]
- **Negative tests validating semantic/type checking (type mismatch, integer width, duplicate overload)** — tests_neg_01_type_mismatch_bad_value, tests_neg_02_int_width_main, tests_neg_06_duplicate_overload_same [INFERRED 0.75]
- **Shared fail(message) test-harness helper pattern across feature tests** — tests_test_01_variables_fail, tests_test_02_if_else_fail, tests_test_03_while_loops_fail, tests_test_04_structs_fail, tests_test_05_enums_fail, tests_test_06_recursion_fail, tests_test_07_booleans_fail, tests_test_08_mutability_fail, tests_test_09_strings_fail, tests_test_10_expressions_fail, tests_test_11_returns_fail, tests_test_12_imports_fail, tests_test_13_globals_fail [INFERRED 0.95]
- **Prismio Ownership System (Move/Drop/Borrow) Demonstration** — tests_test_23_move_main, tests_test_24_drop_main, tests_test_25_conventions_main, tests_test_26_borrow_reuse_main [INFERRED 0.85]

## Communities (84 total, 23 thin omitted)

### Community 0 - "fn sema_annotation_type(module, tn) -> TypeInfo"
Cohesion: 0.07
Nodes (80): extern fn ir_clear_borrowed, extern fn ir_clear_moved, extern fn ir_has_var_type, extern fn ir_is_borrowed, extern fn ir_is_moved, extern fn ir_mark_borrowed, extern fn ir_mark_moved, extern fn ir_set_var_type (+72 more)

### Community 1 - "fn create_node(kind) -> ASTNode"
Cohesion: 0.28
Nodes (32): fn create_node(kind) -> ASTNode, extern fn node_to_ptr, extern fn ptr_to_token, extern fn exit(code), fn parse_block(p) -> ASTNode, fn parse_declaration(p) -> ASTNode, fn parse_enum_decl(p) -> ASTNode, fn parse_expression(p, precedence) -> ASTNode (+24 more)

### Community 2 - "fn compile_source(path, output_file, run_after_build) -> Int"
Cohesion: 0.16
Nodes (15): extern fn ir_reset, extern fn ir_write_file, fn create_lexer(input) -> Lexer, fn lex_all_tokens(lex) -> Token (returns linked-list head), Lexer struct, extern fn token_to_ptr, fn compile_source(path, output_file, run_after_build) -> Int, extern fn compiler_build_executable (+7 more)

### Community 3 - "ir_symbols.c"
Cohesion: 0.07
Nodes (39): NameList, add_binding(), find_binding(), find_struct(), hash_str(), ir_binding_predates_loop(), ir_declare_named_type(), ir_get_enum_variant() (+31 more)

### Community 4 - "build_driver.c"
Cohesion: 0.18
Nodes (29): FILE, accept_if_exists(), build_from_toolchain_sources(), compile_ir_to_object(), compiler_bootstrap_executable(), compiler_build_executable(), compiler_default_exe_path(), compiler_prepare_output_path() (+21 more)

### Community 5 - "lang_runtime.c"
Cohesion: 0.06
Nodes (23): Array, ir_clear_local_var_types(), array_free(), array_get(), array_len(), array_new(), array_push(), int_to_str() (+15 more)

### Community 6 - "fn generate_expression(expr) -> String"
Cohesion: 0.06
Nodes (35): extern fn ir_and, extern fn ir_call_arg, extern fn ir_call_begin, extern fn ir_call_end, extern fn ir_fadd, extern fn ir_fcmp_oeq, extern fn ir_fcmp_oge, extern fn ir_fcmp_ogt (+27 more)

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
Cohesion: 0.08
Nodes (30): extern fn ir_add, extern fn ir_alloca, extern fn ir_br_numbered, extern fn ir_clear_local_var_types, extern fn ir_clear_returned, extern fn ir_cond_br_numbered, extern fn ir_function_begin, extern fn ir_function_body_start (+22 more)

### Community 11 - "fn generate_module(module)"
Cohesion: 0.11
Nodes (25): Claim: no semantic analysis pass between parsing and IR gen (planned), extern fn ir_blank_line, extern fn ir_clear_var_types, extern fn ir_declare_function_begin, extern fn ir_declare_function_end, extern fn ir_declare_function_param, extern fn ir_global_var, extern fn ir_is_struct_type_name (+17 more)

### Community 12 - "extern fn ptr_to_node"
Cohesion: 0.19
Nodes (16): extern fn ptr_to_node, extern fn ir_global_string, extern fn ir_register_enum_variant, fn collect_strings_block(block), fn collect_strings_expr(expr), fn collect_strings_function(func), fn collect_strings_stmt(stmt), fn count_list_nodes(first_ptr) -> Int (+8 more)

### Community 13 - "setup_llvm.py"
Cohesion: 0.25
Nodes (20): candidate_roots(), detect_version(), download(), extract(), fetch(), find_existing(), inspect(), lib_names() (+12 more)

### Community 14 - "CONTRIBUTING.md"
Cohesion: 0.25
Nodes (7): Contributor Covenant Code of Conduct, Conventional Commits convention, Claim: no dedicated semantic analysis pass (planned), Test naming convention (test_<NN>_<description>.psm), POST_INSTALL.txt (install success message), Contributor Covenant (README reference), Prismio Design Principles

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
Cohesion: 0.07
Nodes (77): LLVMBasicBlockRef, LLVMTypeRef, LLVMValueRef, NamedValue, strcmp(), backend_fail(), block_done(), block_for() (+69 more)

### Community 23 - "Enum Types"
Cohesion: 0.24
Nodes (11): Enum Types, Pattern Matching (match expressions), enum Color, enum ExitCode, fail(message) function (test_05_enums), main() function (test_05_enums), classify(n), enum Color (+3 more)

### Community 24 - "main"
Cohesion: 0.15
Nodes (13): String Runtime (extern str_* FFI functions), fail(message), extern fn int_to_str, main(), extern fn str_char_at, extern fn str_concat, extern fn str_contains, extern fn str_equals (+5 more)

### Community 25 - "fn resolve_imports(module, base_dir) -> ASTNode"
Cohesion: 0.32
Nodes (8): fn append_non_imports(target, source), fn append_statement(module, stmt), fn has_named_top_level(module, stmt) -> Bool, fn is_named_top_level(stmt) -> Bool, fn join_import_path(base_dir, module_name) -> String, extern fn read_file, fn resolve_imports(module, base_dir) -> ASTNode, fn same_top_level_name(a, b) -> Bool

### Community 26 - "diagnostics.c"
Cohesion: 0.18
Nodes (11): diag_digits(), diag_emit(), diag_error(), diag_error_at(), diag_line_length(), diag_line_start(), diag_note_at(), diag_render_span() (+3 more)

### Community 27 - "test_runner.py"
Cohesion: 0.32
Nodes (11): cleanup_files(), compile_prismio_file(), expected_errors(), main(), Substrings the diagnostics must contain, from `// expect-error:` lines. Without…, `prismio run` with a forward-slash -o path. Every other test goes through…, run_cli_test(), run_command() (+3 more)

### Community 28 - "check_source_lists.py"
Cohesion: 0.32
Nodes (15): Exception, bootstrap_ps1_list(), bootstrap_sh_list(), embedded_generator_list(), embedded_switch_order(), Failure, main(), package_ps1_lists() (+7 more)

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
Cohesion: 0.19
Nodes (14): run_command_path(), str_char_at(), str_concat(), str_ends_with(), str_length(), str_replace(), str_substring(), str_trim() (+6 more)

### Community 35 - "main"
Cohesion: 0.47
Nodes (5): Array Types (1D/2D indexing), array_sum(), fail(message), main(), matrix_diagonal()

### Community 36 - "Struct (Custom Data Type) Declarations"
Cohesion: 0.40
Nodes (6): Struct (Custom Data Type) Declarations, struct Parser, struct Token, struct Point, struct Point, struct Item

### Community 37 - "fn main() -> Int"
Cohesion: 0.33
Nodes (5): fn ir_set_target_wasm(enabled), extern fn cli_arg, extern fn cli_arg_count, extern fn compiler_default_exe_path, fn main() -> Int

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

### Community 43 - "Prismio Project Structure (src/ layout)"
Cohesion: 0.40
Nodes (5): Prismio Project Structure (src/ layout), ASTNode struct (flat, string-pointer-punned), NodeKind enum (AST node kinds), fn is_keyword(s) -> Bool, TypeInfo struct

### Community 44 - "main"
Cohesion: 0.67
Nodes (3): Generic Collections (List<T>), fail(message), main()

### Community 45 - "Prismio Toolchain Architecture Refactor — Session Handoff"
Cohesion: 0.15
Nodes (12): Confirmed design decisions (from this session's clarifying questions — do not re-ask these), Kickoff prompt for the new session, Phase 1 — Import memoization + driver.c split (foundational, do this first), Phase 2 — Library packaging + Mode 1 (installed-toolchain discovery), Phase 3 — `prismio bootstrap` command + Mode 2 + hash-based freshness, Phase 4 — Backend boundary cleanup, Phase 5 — Tests, docs, architecture report, Prismio Toolchain Architecture Refactor — Session Handoff (+4 more)

### Community 46 - "malloc"
Cohesion: 0.20
Nodes (12): compiler_installed_runtime_hash(), compiler_runtime_source_hash(), fnv1a_bytes(), diag_add_file(), diag_strdup(), list_new(), list_push(), malloc() (+4 more)

### Community 61 - "program_support.c"
Cohesion: 0.21
Nodes (7): str_clone(), strcpy(), executable_directory(), execute_command(), get_directory(), join_path(), prismio_executable_directory()

### Community 63 - "Building Prismio on macOS (and Linux)"
Cohesion: 0.20
Nodes (9): Build it, Building Prismio on macOS (and Linux), Check you reached a fixed point, Cross-compiling from Windows, Refreshing the seed, Test, package, verify, Troubleshooting, What you need (+1 more)

### Community 70 - "Handoff — continuing the Prismio work"
Cohesion: 0.25
Nodes (7): Current state, File roles, Five rules learned the hard way, Handoff — continuing the Prismio work, Known gaps, documented rather than fixed, What's next, Workflow — do this for every change

### Community 71 - "fn generate_struct_decl(struct_node)"
Cohesion: 0.25
Nodes (8): extern fn ir_append, extern fn ir_append_line, extern fn ir_get_struct_field_index, extern fn ir_register_struct_field, fn generate_struct_decl(struct_node), fn is_struct_type_key(t) -> Bool, fn llvm_type_name(t) -> String, fn storage_type(t) -> String

### Community 73 - "bootstrap.sh"
Cohesion: 0.53
Nodes (4): die(), green(), bootstrap.sh script, step()

### Community 75 - "Documented Compiler Pipeline (README architecture diagram)"
Cohesion: 0.40
Nodes (4): Documented Compiler Pipeline (README architecture diagram), Security policy scope, Responsible vulnerability disclosure process, LLVM Bridge FFI declarations (bridge.psm)

### Community 76 - "package.sh script"
Cohesion: 0.80
Nodes (4): build_archive(), die(), green(), package.sh script

### Community 77 - "fn get_expr_type(expr) -> String"
Cohesion: 0.67
Nodes (4): extern fn ir_get_enum_variant, extern fn ir_get_struct_field_type, extern fn ir_get_var_type, fn get_expr_type(expr) -> String

## Ambiguous Edges - Review These
- `Claim: no dedicated semantic analysis pass (planned)` → `fn analyze_module(module)`  [AMBIGUOUS]
  CONTRIBUTING.md · relation: references
- `Test naming convention (test_<NN>_<description>.psm)` → `fn main() -> Int`  [AMBIGUOUS]
  CONTRIBUTING.md · relation: conceptually_related_to
- `Claim: no semantic analysis pass between parsing and IR gen (planned)` → `fn analyze_module(module)`  [AMBIGUOUS]
  README.MD · relation: references

## Knowledge Gaps
- **248 isolated node(s):** `1.1 Pipeline trace: `prismio build file.psm` → executable`, `1.2 How runtime libraries are included: embedded, external, or both?`, `1.3 Every file and function responsible`, `2.1 What happens when the compiler compiles itself (`prismio build src/main.psm`)?`, `2.2 Duplicate runtime linkage — two separate risks, at two separate layers` (+243 more)
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
- **Why does `extern fn ptr_to_node` connect `extern fn ptr_to_node` to `fn sema_annotation_type(module, tn) -> TypeInfo`, `fn create_node(kind) -> ASTNode`, `fn generate_expression(expr) -> String`, `fn generate_struct_decl(struct_node)`, `fn generate_statement(stmt)`, `fn generate_module(module)`, `fn get_expr_type(expr) -> String`, `fn resolve_imports(module, base_dir) -> ASTNode`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Why does `fn generate_expression(expr) -> String` connect `fn generate_expression(expr) -> String` to `fn sema_annotation_type(module, tn) -> TypeInfo`, `fn generate_struct_decl(struct_node)`, `fn generate_statement(stmt)`, `extern fn ptr_to_node`, `fn get_expr_type(expr) -> String`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Why does `strcmp()` connect `llvm-api-backend.c` to `strlen`, `ir_symbols.c`, `build_driver.c`, `lang_runtime.c`, `malloc`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Are the 36 inferred relationships involving `main()` (e.g. with `ir_alloc_object()` and `ir_alloca()`) actually correct?**
  _`main()` has 36 INFERRED edges - model-reasoned connections that need verification._