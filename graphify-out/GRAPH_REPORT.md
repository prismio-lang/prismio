# Graph Report - self  (2026-07-30)

## Corpus Check
- 14 files · ~22,142 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 801 nodes · 1607 edges · 70 communities (46 shown, 24 thin omitted)
- Extraction: 90% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 152 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e37af168`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Type System & Semantic Analysis
- AST & Parser Core
- Compiler Driver & Project Docs
- LLVM Bridge: Ownership State (C)
- LLVM IR Codegen Primitives (C)
- Runtime Array Operations (C)
- IR Bridge FFI Declarations
- Ownership: Move/Borrow/Drop Semantics
- Compiler Driver CLI (C)
- Variables & Expressions Tests
- IR Bridge: Codegen Emission FFI
- IR Bridge: Function Declaration FFI
- Runtime Path & String Helpers (C)
- LLVM IR Call Emission (C)
- IR Bridge: Function Prologue FFI
- Lexer & String Utilities
- Loop Constructs Tests
- UMS Build Tool CLI
- Function Overloading Tests
- Module Imports & Multi-Arg Calls
- Driver/Runtime OS Split
- Runtime Path Resolution (C)
- String Comparison Runtime (C)
- Enums & Pattern Matching Tests
- String Runtime FFI
- IR: Globals & Enum Variants
- IR: Struct/Enum Type Queries
- Python Test Runner
- UMS Config Parsing Helpers
- String Operations Tests
- Compiler Pipeline Simulation Test
- Integer Width Type Checking
- Runtime List & File I/O (C)
- LLVM Float Comparison Ops (C)
- UMS Build Command Assembly
- Array Types Test
- Struct Declarations
- IR Type Mapping Helpers
- Boolean Logic Test
- Conditionals Test
- Float Arithmetic Test
- Recursion Test
- Return Statements Test
- LLVM Output File I/O (C)
- Generic Collections Test
- Embedded Sources Generator Script
- IR: Branch Instruction FFI
- IR: Comment Instruction FFI
- IR: Conditional Branch FFI
- IR: Label Name Accessor FFI
- IR: Label Instruction FFI
- IR: Negation Instruction FFI
- IR: Print Instruction FFI
- IR: i1 Type Constant FFI
- IR: i32 Type Constant FFI
- IR: i64 Type Constant FFI
- IR: i8 Type Constant FFI
- IR: i8 Pointer Type FFI
- IR: Void Type Constant FFI
- Parser Struct (Duplicate Copy)
- Parser Struct Definition
- Hello World Smoke Test
- TypeKind Enum
- String Contains FFI
- String Index-Of FFI
- String-to-Int FFI
- Counter Struct (Conventions Test)
- Res Struct (Borrow Reuse Test)
- CLAUDE.md

## God Nodes (most connected - your core abstractions)
1. `fn generate_expression(expr) -> String` - 55 edges
2. `ir_append_line()` - 47 edges
3. `extern fn ptr_to_node` - 46 edges
4. `fn generate_statement(stmt)` - 36 edges
5. `fn sema_annotation_type(module, tn) -> TypeInfo` - 33 edges
6. `fn create_node(kind) -> ASTNode` - 32 edges
7. `fn sema_expr(module, expr) -> TypeInfo` - 32 edges
8. `malloc()` - 29 edges
9. `fn generate_module(module)` - 29 edges
10. `extern fn str_equals` - 28 edges

## Surprising Connections (you probably didn't know these)
- `Test naming convention (test_<NN>_<description>.psm)` --conceptually_related_to--> `fn main() -> Int`  [AMBIGUOUS]
  CONTRIBUTING.md → src/main.psm
- `compile(input_size)` --semantically_similar_to--> `run_build(content)`  [INFERRED] [semantically similar]
  tests/test_15_compiler_sim.psm → ums/main.psm
- `Claim: no dedicated semantic analysis pass (planned)` --references--> `fn analyze_module(module)`  [AMBIGUOUS]
  CONTRIBUTING.md → src/sema.psm
- `Claim: no semantic analysis pass between parsing and IR gen (planned)` --references--> `fn analyze_module(module)`  [AMBIGUOUS]
  README.MD → src/sema.psm
- `ir_get_label_name()` --calls--> `malloc()`  [INFERRED]
  runtime/llvm-bridge.c → runtime/lang_runtime.c

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Duplicate/superseded parser split (parser.psm vs parser_decls.psm + parser_expr.psm)** — src_parser_parser, src_parser_decls_parser, src_parser_expr_parse_module [INFERRED 0.75]
- **Prismio self-hosted compiler pipeline (lexer -> parser -> import resolver -> sema -> IR generator)** — src_lexer_lex_all_tokens, src_parser_parse_module, src_main_resolve_imports, src_sema_analyze_module, src_ir_generate_module [EXTRACTED 1.00]
- **Move/borrow/drop ownership system (sink/inout params, struct move-only values, drop())** — src_types_type_is_move_only, src_sema_sema_move_operand, src_bridge_ir_mark_moved, src_bridge_ir_is_borrowed, src_ir_generate_expression [INFERRED 0.85]
- **Negative tests validating move/drop/borrow ownership checking** — tests_neg_03_use_after_move_main, tests_neg_04_use_after_drop_main, tests_neg_05_drop_borrow_main [INFERRED 0.85]
- **Negative tests validating semantic/type checking (type mismatch, integer width, duplicate overload)** — tests_neg_01_type_mismatch_bad_value, tests_neg_02_int_width_main, tests_neg_06_duplicate_overload_same [INFERRED 0.75]
- **Shared fail(message) test-harness helper pattern across feature tests** — tests_test_01_variables_fail, tests_test_02_if_else_fail, tests_test_03_while_loops_fail, tests_test_04_structs_fail, tests_test_05_enums_fail, tests_test_06_recursion_fail, tests_test_07_booleans_fail, tests_test_08_mutability_fail, tests_test_09_strings_fail, tests_test_10_expressions_fail, tests_test_11_returns_fail, tests_test_12_imports_fail, tests_test_13_globals_fail [INFERRED 0.95]
- **Shared str_length FFI Declaration Across Files** — tests_test_17_string_runtime_str_length, tests_test_19_runtime_split_str_length, ums_main_str_length [INFERRED 0.95]
- **Shared str_equals FFI Declaration Across Files** — tests_test_17_string_runtime_str_equals, tests_test_29_overloads_str_equals, ums_main_str_equals [INFERRED 0.95]
- **Prismio Ownership System (Move/Drop/Borrow) Demonstration** — tests_test_23_move_main, tests_test_24_drop_main, tests_test_25_conventions_main, tests_test_26_borrow_reuse_main [INFERRED 0.85]

## Communities (70 total, 24 thin omitted)

### Community 0 - "Type System & Semantic Analysis"
Cohesion: 0.06
Nodes (88): extern fn ir_clear_borrowed, extern fn ir_clear_local_var_types, extern fn ir_clear_moved, extern fn ir_has_var_type, extern fn ir_is_borrowed, extern fn ir_is_moved, extern fn ir_mark_borrowed, extern fn ir_mark_moved (+80 more)

### Community 1 - "AST & Parser Core"
Cohesion: 0.14
Nodes (56): fn create_node(kind) -> ASTNode, extern fn node_to_ptr, extern fn ptr_to_token, fn parse_declaration(p) -> ASTNode, fn parse_enum_decl(p) -> ASTNode, fn parse_extern_fn_decl(p) -> ASTNode, fn parse_function_decl(p) -> ASTNode  [lacks sink/inout param conventions], fn parse_import_statement(p) -> ASTNode (+48 more)

### Community 2 - "Compiler Driver & Project Docs"
Cohesion: 0.15
Nodes (16): extern fn ir_reset, extern fn ir_write_file, fn create_lexer(input) -> Lexer, fn lex_all_tokens(lex) -> Token (returns linked-list head), Lexer struct, extern fn token_to_ptr, fn compile_source(path, output_file, run_after_build) -> Int, extern fn compiler_build_executable (+8 more)

### Community 3 - "LLVM Bridge: Ownership State (C)"
Cohesion: 0.06
Nodes (15): ir_br(), ir_call_arg(), ir_call_begin(), ir_close_file(), ir_cond_br(), ir_flush(), ir_get_label_name(), ir_get_temp_name() (+7 more)

### Community 4 - "LLVM IR Codegen Primitives (C)"
Cohesion: 0.10
Nodes (32): ir_and(), ir_append_line(), ir_bitcast(), ir_blank_line(), ir_br_numbered(), ir_call(), ir_call_end(), ir_cond_br_numbered() (+24 more)

### Community 5 - "Runtime Array Operations (C)"
Cohesion: 0.05
Nodes (66): Array, FILE, command_quote_arg(), compiler_build_executable(), compiler_default_exe_path(), compiler_executable_directory(), compiler_prepare_output_path(), compiler_run_executable() (+58 more)

### Community 6 - "IR Bridge FFI Declarations"
Cohesion: 0.06
Nodes (38): extern fn ir_and, extern fn ir_call_arg, extern fn ir_call_begin, extern fn ir_call_end, extern fn ir_fadd, extern fn ir_fcmp_oeq, extern fn ir_fcmp_oge, extern fn ir_fcmp_ogt (+30 more)

### Community 7 - "Ownership: Move/Borrow/Drop Semantics"
Cohesion: 0.08
Nodes (30): Borrow Checking, Drop Semantics, Move Semantics, Parameter Passing Conventions (borrow/inout/sink), Struct Types, main() function (neg_03_use_after_move), struct Point (neg_03_use_after_move), main() function (neg_04_use_after_drop) (+22 more)

### Community 8 - "Compiler Driver CLI (C)"
Cohesion: 0.18
Nodes (11): ir_icmp(), ir_icmp_eq(), ir_icmp_ne(), ir_icmp_sge(), ir_icmp_sgt(), ir_icmp_sle(), ir_icmp_slt(), ir_icmp_uge() (+3 more)

### Community 9 - "Variables & Expressions Tests"
Cohesion: 0.09
Nodes (27): Arithmetic Operators, Global Variables, Mutability (mut bindings), Operator Precedence / Expression Evaluation, Variable Declarations, bump_global(amount) function, fail(message) function (test_01_variables), main() function (test_01_variables) (+19 more)

### Community 10 - "IR Bridge: Codegen Emission FFI"
Cohesion: 0.10
Nodes (23): extern fn ir_add, extern fn ir_append, extern fn ir_append_line, extern fn ir_br_numbered, extern fn ir_cond_br_numbered, extern fn ir_get_label, extern fn ir_get_struct_field_index, extern fn ir_get_temp_name (+15 more)

### Community 11 - "IR Bridge: Function Declaration FFI"
Cohesion: 0.13
Nodes (21): extern fn ir_blank_line, extern fn ir_declare_function_begin, extern fn ir_declare_function_end, extern fn ir_declare_function_param, extern fn ir_global_var, extern fn ir_is_struct_type_name, extern fn ir_module_end, extern fn ir_module_start (+13 more)

### Community 12 - "Runtime Path & String Helpers (C)"
Cohesion: 0.27
Nodes (11): extern fn ptr_to_node, extern fn ir_global_string, extern fn ir_register_enum_variant, fn collect_strings_block(block), fn collect_strings_expr(expr), fn collect_strings_function(func), fn collect_strings_stmt(stmt), fn count_list_nodes(first_ptr) -> Int (+3 more)

### Community 13 - "LLVM IR Call Emission (C)"
Cohesion: 0.17
Nodes (16): ir_add(), ir_append(), ir_call_void(), ir_comment(), ir_declare_function_begin(), ir_declare_function_param(), ir_example_generate_add_function(), ir_function_begin() (+8 more)

### Community 14 - "IR Bridge: Function Prologue FFI"
Cohesion: 0.18
Nodes (11): Contributor Covenant Code of Conduct, Conventional Commits convention, Claim: no dedicated semantic analysis pass (planned), Test naming convention (test_<NN>_<description>.psm), POST_INSTALL.txt (install success message), Contributor Covenant (README reference), Prismio Design Principles, Claim: no semantic analysis pass between parsing and IR gen (planned) (+3 more)

### Community 15 - "Lexer & String Utilities"
Cohesion: 0.18
Nodes (15): fn is_boolean(s) -> Bool, fn lexer_advance(lex), fn lexer_current(lex) -> Char, fn lexer_next_token(lex) -> Token, fn lexer_peek(lex, offset) -> Char, fn lexer_skip_whitespace(lex), fn char_code(c) -> Int, extern fn int_to_str (+7 more)

### Community 16 - "Loop Constructs Tests"
Cohesion: 0.21
Nodes (13): While Loops, Range-Based For Loops (a..b), factorial(n) function, fail(message) function (test_03_while_loops), main() function (test_03_while_loops), sum_to_n(n) function, count_to(limit), fail(message) (+5 more)

### Community 17 - "UMS Build Tool CLI"
Cohesion: 0.27
Nodes (11): Build Tooling / Task Runner (ums), extern fn cli_arg, extern fn cli_arg_count, executable_command(content), extern fn execute_command, load_config(), main(), extern fn read_file (+3 more)

### Community 18 - "Function Overloading Tests"
Cohesion: 0.27
Nodes (12): Function Overloading, main() function (neg_06_duplicate_overload), same(value: Int) function, first declaration (neg_06_duplicate_overload), same(other: Int) function, duplicate declaration (neg_06_duplicate_overload), choose(value: Float), choose(value: Int), choose(value: String), combine(left: Int, right: Int) (+4 more)

### Community 19 - "Module Imports & Multi-Arg Calls"
Cohesion: 0.23
Nodes (12): Module Imports, Multi-Argument Function Calls, fail(message) function (test_12_imports), main() function (test_12_imports), add3(a,b,c), add4(a,b,c,d), add5(a,b,c,d,e), fail(message) (+4 more)

### Community 20 - "Driver/Runtime OS Split"
Cohesion: 0.20
Nodes (12): Driver/Runtime Split (OS-level extern functions), extern fn executable_directory, fail(message), extern fn file_exists, extern fn join_path, main(), extern fn str_length, default_prismio_path() (+4 more)

### Community 21 - "Runtime Path Resolution (C)"
Cohesion: 0.83
Nodes (3): add_c_string(), escape_c_string(), main()

### Community 22 - "String Comparison Runtime (C)"
Cohesion: 0.11
Nodes (19): str_compare(), str_equals(), strcmp(), append_to_buffer(), ir_alloca(), ir_append_alloca_line(), ir_get_enum_variant(), ir_get_struct_field_index() (+11 more)

### Community 23 - "Enums & Pattern Matching Tests"
Cohesion: 0.24
Nodes (11): Enum Types, Pattern Matching (match expressions), enum Color, enum ExitCode, fail(message) function (test_05_enums), main() function (test_05_enums), classify(n), enum Color (+3 more)

### Community 24 - "String Runtime FFI"
Cohesion: 0.18
Nodes (11): String Runtime (extern str_* FFI functions), fail(message), extern fn int_to_str, main(), extern fn str_char_at, extern fn str_contains, extern fn str_equals, extern fn str_length (+3 more)

### Community 25 - "IR: Globals & Enum Variants"
Cohesion: 0.32
Nodes (8): fn append_non_imports(target, source), fn append_statement(module, stmt), fn has_named_top_level(module, stmt) -> Bool, fn is_named_top_level(stmt) -> Bool, fn join_import_path(base_dir, module_name) -> String, extern fn read_file, fn resolve_imports(module, base_dir) -> ASTNode, fn same_top_level_name(a, b) -> Bool

### Community 26 - "IR: Struct/Enum Type Queries"
Cohesion: 0.18
Nodes (14): extern fn ir_alloca, extern fn ir_clear_returned, extern fn ir_function_begin, extern fn ir_function_body_start, extern fn ir_function_end, extern fn ir_function_param, extern fn ir_has_returned, extern fn ir_ret (+6 more)

### Community 27 - "Python Test Runner"
Cohesion: 0.47
Nodes (7): cleanup_files(), compile_prismio_file(), main(), run_command(), run_negative_test(), run_program(), run_test()

### Community 28 - "UMS Config Parsing Helpers"
Cohesion: 0.29
Nodes (8): extern fn str_index_of, extern fn str_substring, find_char_from(text,target,start), read_call_value(content,name,fallback), run_args(content), extern fn str_index_of, extern fn str_length, extern fn str_substring

### Community 29 - "String Operations Tests"
Cohesion: 0.48
Nodes (7): FFI / Extern Function Declarations, String Operations, fail(message) function (test_09_strings), main() function (test_09_strings), extern fn str_concat(s1, s2), extern fn str_equals(s1, s2), extern fn str_length(s)

### Community 30 - "Compiler Pipeline Simulation Test"
Cohesion: 0.33
Nodes (7): Function Composition / Pipeline Simulation, compile(input_size), create_token(t,v,l), fail(message), main(), parse(token_count), tokenize(input)

### Community 31 - "Integer Width Type Checking"
Cohesion: 0.33
Nodes (7): Fixed-Width Integer Typing, Static Type Checking, bad_value() function (neg_01_type_mismatch), main() function (neg_01_type_mismatch), main() function (neg_02_int_width), fail(message), main()

### Community 32 - "Runtime List & File I/O (C)"
Cohesion: 0.25
Nodes (7): How this was produced, Prismio — Compiler Status, Runtime embedding (the part you asked about), Test coverage snapshot, Verified build pipeline, What's built, What's left / known issues

### Community 33 - "LLVM Float Comparison Ops (C)"
Cohesion: 0.29
Nodes (7): ir_fcmp(), ir_fcmp_oeq(), ir_fcmp_oge(), ir_fcmp_ogt(), ir_fcmp_ole(), ir_fcmp_olt(), ir_fcmp_one()

### Community 34 - "UMS Build Command Assembly"
Cohesion: 0.29
Nodes (7): extern fn str_concat, extern fn command_quote_arg, build_command(content), extern fn command_quote_arg, output_path(content), source_path(content), extern fn str_concat

### Community 35 - "Array Types Test"
Cohesion: 0.47
Nodes (5): Array Types (1D/2D indexing), array_sum(), fail(message), main(), matrix_diagonal()

### Community 36 - "Struct Declarations"
Cohesion: 0.40
Nodes (6): Struct (Custom Data Type) Declarations, struct Parser, struct Token, struct Point, struct Point, struct Item

### Community 37 - "IR Type Mapping Helpers"
Cohesion: 0.33
Nodes (5): fn ir_set_target_wasm(enabled), extern fn cli_arg, extern fn cli_arg_count, extern fn compiler_default_exe_path, fn main() -> Int

### Community 38 - "Boolean Logic Test"
Cohesion: 0.50
Nodes (5): Boolean Logic, fail(message) function (test_07_booleans), is_between(n) function, main() function (test_07_booleans), test_equal(a, b) function

### Community 39 - "Conditionals Test"
Cohesion: 0.50
Nodes (5): If/Else Conditionals, fail(message) function (test_02_if_else), main() function (test_02_if_else), max(a, b) function, test_nested_if(x) function

### Community 40 - "Float Arithmetic Test"
Cohesion: 0.60
Nodes (5): Float Arithmetic & Comparisons (f64), blended(offset), comparisons(value), fail(message), main()

### Community 41 - "Recursion Test"
Cohesion: 0.70
Nodes (5): Recursion, fail(message) function (test_06_recursion), fibonacci(n) function, gcd(a, b) function, main() function (test_06_recursion)

### Community 42 - "Return Statements Test"
Cohesion: 0.50
Nodes (5): Return Statements / Early Return, classify_number(n) function, early_return(x) function, fail(message) function (test_11_returns), main() function (test_11_returns)

### Community 43 - "LLVM Output File I/O (C)"
Cohesion: 0.20
Nodes (9): Prismio Project Structure (src/ layout), Documented Compiler Pipeline (README architecture diagram), Security policy scope, Responsible vulnerability disclosure process, ASTNode struct (flat, string-pointer-punned), NodeKind enum (AST node kinds), LLVM Bridge FFI declarations (bridge.psm), fn is_keyword(s) -> Bool (+1 more)

### Community 44 - "Generic Collections Test"
Cohesion: 0.67
Nodes (3): Generic Collections (List<T>), fail(message), main()

## Ambiguous Edges - Review These
- `Claim: no dedicated semantic analysis pass (planned)` → `fn analyze_module(module)`  [AMBIGUOUS]
  CONTRIBUTING.md · relation: references
- `Test naming convention (test_<NN>_<description>.psm)` → `fn main() -> Int`  [AMBIGUOUS]
  CONTRIBUTING.md · relation: conceptually_related_to
- `Claim: no semantic analysis pass between parsing and IR gen (planned)` → `fn analyze_module(module)`  [AMBIGUOUS]
  README.MD · relation: references

## Knowledge Gaps
- **180 isolated node(s):** `graphify`, `Runtime embedding (the part you asked about)`, `What's built`, `What's left / known issues`, `Test coverage snapshot` (+175 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **24 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Claim: no dedicated semantic analysis pass (planned)` and `fn analyze_module(module)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Test naming convention (test_<NN>_<description>.psm)` and `fn main() -> Int`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Claim: no semantic analysis pass between parsing and IR gen (planned)` and `fn analyze_module(module)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `extern fn ptr_to_node` connect `Runtime Path & String Helpers (C)` to `Type System & Semantic Analysis`, `AST & Parser Core`, `IR Bridge FFI Declarations`, `IR Bridge: Codegen Emission FFI`, `IR Bridge: Function Declaration FFI`, `IR Bridge: Function Prologue FFI`, `IR: Globals & Enum Variants`, `IR: Struct/Enum Type Queries`?**
  _High betweenness centrality (0.054) - this node is a cross-community bridge._
- **Why does `fn generate_expression(expr) -> String` connect `IR Bridge FFI Declarations` to `Type System & Semantic Analysis`, `IR Bridge: Codegen Emission FFI`, `IR Bridge: Function Declaration FFI`, `Runtime Path & String Helpers (C)`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Why does `extern fn str_equals` connect `Type System & Semantic Analysis` to `AST & Parser Core`, `IR Type Mapping Helpers`, `IR Bridge FFI Declarations`, `IR Bridge: Codegen Emission FFI`, `LLVM Output File I/O (C)`, `IR Bridge: Function Declaration FFI`, `Lexer & String Utilities`, `IR: Globals & Enum Variants`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **What connects `graphify`, `Runtime embedding (the part you asked about)`, `What's built` to the rest of the system?**
  _180 weakly-connected nodes found - possible documentation gaps or missing edges._