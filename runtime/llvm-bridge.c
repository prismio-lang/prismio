// ============================================
// String-Based LLVM IR Generator for Prismio
// No LLVM dependencies - generates IR as text
// ============================================

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ============================================
// Global State
// ============================================

#define MAX_IR_SIZE 8388608
#define MAX_FUNCTION_BODY_SIZE 2097152
#define MAX_FUNCTION_ALLOCA_SIZE 262144
#define MAX_LABEL_COUNT 10000

static char ir_buffer[MAX_IR_SIZE];
static int ir_position = 0;
static char function_body_buffer[MAX_FUNCTION_BODY_SIZE];
static int function_body_position = 0;
static char function_alloca_buffer[MAX_FUNCTION_ALLOCA_SIZE];
static int function_alloca_position = 0;
static int collecting_function_body = 0;
static int next_temp = 0;
static int next_label = 0;
static FILE* output_file = NULL;

// Type representations (as strings)
static const char* TYPE_VOID = "void";
static const char* TYPE_I1 = "i1";
static const char* TYPE_I8 = "i8";
static const char* TYPE_I32 = "i32";
static const char* TYPE_I64 = "i64";
static const char* TYPE_I8_PTR = "i8*";

// ============================================
// Buffer Management
// ============================================

void ir_reset() {
    ir_position = 0;
    next_temp = 0;
    next_label = 0;
    memset(ir_buffer, 0, MAX_IR_SIZE);
    memset(function_body_buffer, 0, MAX_FUNCTION_BODY_SIZE);
    memset(function_alloca_buffer, 0, MAX_FUNCTION_ALLOCA_SIZE);
    function_body_position = 0;
    function_alloca_position = 0;
    collecting_function_body = 0;
}

static void append_to_buffer(char* buffer, int* position, int max_size, const char* str) {
    int len = strlen(str);
    if (*position + len < max_size) {
        strcpy(buffer + *position, str);
        *position += len;
    }
}

void ir_append(const char* str) {
    if (collecting_function_body) {
        append_to_buffer(function_body_buffer, &function_body_position, MAX_FUNCTION_BODY_SIZE, str);
    } else {
        append_to_buffer(ir_buffer, &ir_position, MAX_IR_SIZE, str);
    }
}

void ir_append_line(const char* str) {
    ir_append(str);
    ir_append("\n");
}

static void ir_append_alloca_line(const char* str) {
    append_to_buffer(function_alloca_buffer, &function_alloca_position, MAX_FUNCTION_ALLOCA_SIZE, str);
    append_to_buffer(function_alloca_buffer, &function_alloca_position, MAX_FUNCTION_ALLOCA_SIZE, "\n");
}

const char* ir_get_buffer() {
    return ir_buffer;
}

int ir_get_temp() {
    return next_temp++;
}

int ir_get_label() {
    return next_label++;
}

// ============================================
// File Operations
// ============================================

void ir_open_file(const char* filename) {
    output_file = fopen(filename, "w");
}

void ir_close_file() {
    if (output_file) {
        fclose(output_file);
        output_file = NULL;
    }
}

void ir_write_to_file() {
    if (output_file) {
        fprintf(output_file, "%s", ir_buffer);
    }
}

void ir_flush() {
    if (output_file) {
        ir_write_to_file();
        fflush(output_file);
    }
}

// ============================================
// Module Management
// ============================================

// Prismio compiles for the host, so the module targets whatever platform this
// bridge was itself compiled for.
//
// No `target datalayout` line is emitted at all. LLVM derives the layout from the
// triple, and a hardcoded string is a liability: it is version-sensitive (the arm64
// macOS layout gained -Fn32 in LLVM 18) and a stale one is not diagnosed, it just
// silently miscompiles. Letting llc supply it cannot drift.
//
// The triple is pinned only on Windows, where msvc and mingw are a real fork and
// the msvc target is the configuration that is actually verified. Everywhere else
// omitting it is strictly better than guessing: llc falls back to its own host
// triple, which on macOS carries the matching darwin version and so avoids the
// "object file was built for newer macOS version" warnings a version-less
// arm64-apple-macosx would produce at link time.
static void ir_emit_target_directives(void) {
#ifdef _WIN32
    ir_append_line("target triple = \"x86_64-pc-windows-msvc\"");
#endif
}

void ir_module_start(const char* module_name) {
    ir_reset();

    // Add module header comments
    ir_append("; ModuleID = '");
    ir_append(module_name);
    ir_append_line("'");
    ir_append_line("source_filename = \"prismio_generated\"");
    ir_emit_target_directives();
    ir_append_line("");
}

void ir_module_start_wasm(const char* module_name) {
    ir_reset();

    ir_append("; ModuleID = '");
    ir_append(module_name);
    ir_append_line("'");
    ir_append_line("source_filename = \"prismio_generated\"");
    ir_append_line("target datalayout = \"e-m:e-p:32:32-i64:64-n32:64-S128\"");
    ir_append_line("target triple = \"wasm32-unknown-unknown\"");
    ir_append_line("");
}

void ir_module_end() {
    // Nothing special needed
}

// ============================================
// Type Helpers
// ============================================

const char* ir_type_void() { return TYPE_VOID; }
const char* ir_type_i1() { return TYPE_I1; }
const char* ir_type_i8() { return TYPE_I8; }
const char* ir_type_i32() { return TYPE_I32; }
const char* ir_type_i64() { return TYPE_I64; }
const char* ir_type_i8_ptr() { return TYPE_I8_PTR; }

// Store pointer type as string (caller must manage memory)
void ir_type_pointer(const char* element_type, char* out_buffer) {
    sprintf(out_buffer, "%s*", element_type);
}

void ir_type_array(const char* element_type, int count, char* out_buffer) {
    sprintf(out_buffer, "[%d x %s]", count, element_type);
}

// ============================================
// ============================================
// State-Machine Builders (Array-free for FFI)
// ============================================

static int sm_param_count = 0;
static char sm_alloca_names[512][64];
static int sm_alloca_count = 0;

void ir_declare_function_begin(const char* name, const char* return_type) {
    ir_append("declare ");
    ir_append(return_type);
    ir_append(" @");
    ir_append(name);
    ir_append("(");
    sm_param_count = 0;
}

void ir_declare_function_param(const char* param_type) {
    if (sm_param_count > 0) ir_append(", ");
    ir_append(param_type);
    sm_param_count++;
}

void ir_declare_function_end() {
    ir_append_line(")");
}

void ir_function_begin(const char* name, const char* return_type) {
    ir_append("define ");
    ir_append(return_type);
    ir_append(" @");
    ir_append(name);
    ir_append("(");
    sm_param_count = 0;
}

void ir_function_param(const char* param_type, const char* param_name) {
    if (sm_param_count > 0) ir_append(", ");
    ir_append(param_type);
    ir_append(" %");
    ir_append(param_name);
    sm_param_count++;
}

void ir_function_body_start() {
    ir_append_line(") {");
    memset(function_body_buffer, 0, MAX_FUNCTION_BODY_SIZE);
    memset(function_alloca_buffer, 0, MAX_FUNCTION_ALLOCA_SIZE);
    function_body_position = 0;
    function_alloca_position = 0;
    collecting_function_body = 1;
    sm_alloca_count = 0;
}

void ir_function_end() {
    collecting_function_body = 0;
    ir_append(function_alloca_buffer);
    ir_append(function_body_buffer);
    ir_append_line("}");
    ir_append_line("");
}

// Call Builder
static char sm_call_buffer[1024];
static int sm_call_arg_count = 0;
static char sm_call_buffer_stack[64][1024];
static int sm_call_arg_count_stack[64];
static int sm_call_stack_depth = 0;

void ir_call_begin() {
    if (sm_call_stack_depth < 64) {
        strcpy(sm_call_buffer_stack[sm_call_stack_depth], sm_call_buffer);
        sm_call_arg_count_stack[sm_call_stack_depth] = sm_call_arg_count;
        sm_call_stack_depth++;
    }
    sm_call_arg_count = 0;
    sm_call_buffer[0] = '\0';
}

void ir_call_arg(const char* arg_type, const char* arg_value) {
    if (sm_call_arg_count > 0) strcat(sm_call_buffer, ", ");
    strcat(sm_call_buffer, arg_type);
    strcat(sm_call_buffer, " ");
    strcat(sm_call_buffer, arg_value);
    sm_call_arg_count++;
}

int ir_call_end(const char* return_type, const char* function_name) {
    char call_args[1024];
    strcpy(call_args, sm_call_buffer);
    if (sm_call_stack_depth > 0) {
        sm_call_stack_depth--;
        strcpy(sm_call_buffer, sm_call_buffer_stack[sm_call_stack_depth]);
        sm_call_arg_count = sm_call_arg_count_stack[sm_call_stack_depth];
    } else {
        sm_call_arg_count = 0;
        sm_call_buffer[0] = '\0';
    }

    if (strcmp(return_type, "void") == 0 || strcmp(return_type, "") == 0) {
        char buf[1024 + 256];
        sprintf(buf, "  call void @%s(%s)", function_name, call_args);
        ir_append_line(buf);
        return -1;
    } else {
        int temp = ir_get_temp();
        char buf[1024 + 256];
        sprintf(buf, "  %%t%d = call %s @%s(%s)", temp, return_type, function_name, call_args);
        ir_append_line(buf);
        return temp;
    }
}


// ============================================
// Basic Blocks
// ============================================

void ir_label(const char* label_name) {
    ir_append(label_name);
    ir_append_line(":");
}

void ir_label_numbered(int label_num) {
    char buffer[64];
    sprintf(buffer, "label_%d:", label_num);
    ir_append_line(buffer);
}

// ============================================
// Memory Instructions
// ============================================

int ir_alloca(const char* type, const char* name) {
    for (int i = 0; i < sm_alloca_count; i++) {
        if (strcmp(sm_alloca_names[i], name) == 0) {
            return -1;
        }
    }

    if (sm_alloca_count < 512) {
        strncpy(sm_alloca_names[sm_alloca_count], name, 63);
        sm_alloca_names[sm_alloca_count][63] = '\0';
        sm_alloca_count++;
    }

    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%%s = alloca %s", name, type);
    if (collecting_function_body) {
        ir_append_alloca_line(buffer);
    } else {
        ir_append_line(buffer);
    }
    return temp;
}

int ir_load(const char* type, const char* ptr_name) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = load %s, ptr %%%s", temp, type, ptr_name);
    ir_append_line(buffer);
    return temp;
}

void ir_store(const char* type, const char* value, const char* ptr_name) {
    char buffer[256];
    sprintf(buffer, "  store %s %s, ptr %%%s", type, value, ptr_name);
    ir_append_line(buffer);
}

int ir_load_global(const char* type, const char* name) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = load %s, ptr @%s", temp, type, name);
    ir_append_line(buffer);
    return temp;
}

void ir_store_global(const char* type, const char* value, const char* name) {
    char buffer[256];
    sprintf(buffer, "  store %s %s, ptr @%s", type, value, name);
    ir_append_line(buffer);
}

// ============================================
// Arithmetic Instructions
// ============================================

int ir_add(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = add %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_sub(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = sub %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_mul(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = mul %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_sdiv(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = sdiv %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_and(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = and %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_or(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = or %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_srem(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = srem %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_udiv(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = udiv %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_urem(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = urem %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_fadd(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = fadd %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_fsub(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = fsub %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_fmul(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = fmul %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_fdiv(const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = fdiv %s %s, %s", temp, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_neg(const char* type, const char* value) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = sub %s 0, %s", temp, type, value);
    ir_append_line(buffer);
    return temp;
}

// ============================================
// Comparison Instructions
// ============================================

int ir_icmp(const char* predicate, const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = icmp %s %s %s, %s", temp, predicate, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_icmp_eq(const char* type, const char* lhs, const char* rhs) {
    return ir_icmp("eq", type, lhs, rhs);
}

int ir_icmp_ne(const char* type, const char* lhs, const char* rhs) {
    return ir_icmp("ne", type, lhs, rhs);
}

int ir_icmp_slt(const char* type, const char* lhs, const char* rhs) {
    return ir_icmp("slt", type, lhs, rhs);
}

int ir_icmp_sle(const char* type, const char* lhs, const char* rhs) {
    return ir_icmp("sle", type, lhs, rhs);
}

int ir_icmp_sgt(const char* type, const char* lhs, const char* rhs) {
    return ir_icmp("sgt", type, lhs, rhs);
}

int ir_icmp_sge(const char* type, const char* lhs, const char* rhs) {
    return ir_icmp("sge", type, lhs, rhs);
}

int ir_icmp_ult(const char* type, const char* lhs, const char* rhs) {
    return ir_icmp("ult", type, lhs, rhs);
}

int ir_icmp_ule(const char* type, const char* lhs, const char* rhs) {
    return ir_icmp("ule", type, lhs, rhs);
}

int ir_icmp_ugt(const char* type, const char* lhs, const char* rhs) {
    return ir_icmp("ugt", type, lhs, rhs);
}

int ir_icmp_uge(const char* type, const char* lhs, const char* rhs) {
    return ir_icmp("uge", type, lhs, rhs);
}

// --- loop context stack: break/continue jump targets (supports nesting) ---
static int loop_continue_stack[64];
static int loop_break_stack[64];
static int loop_depth = 0;

void ir_loop_push(int continue_label, int break_label) {
    if (loop_depth < 64) {
        loop_continue_stack[loop_depth] = continue_label;
        loop_break_stack[loop_depth] = break_label;
        loop_depth++;
    }
}

void ir_loop_pop() {
    if (loop_depth > 0) loop_depth--;
}

int ir_loop_continue_label() {
    return loop_depth > 0 ? loop_continue_stack[loop_depth - 1] : -1;
}

int ir_loop_break_label() {
    return loop_depth > 0 ? loop_break_stack[loop_depth - 1] : -1;
}

int ir_fcmp(const char* predicate, const char* type, const char* lhs, const char* rhs) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = fcmp %s %s %s, %s", temp, predicate, type, lhs, rhs);
    ir_append_line(buffer);
    return temp;
}

int ir_fcmp_oeq(const char* type, const char* lhs, const char* rhs) {
    return ir_fcmp("oeq", type, lhs, rhs);
}

int ir_fcmp_one(const char* type, const char* lhs, const char* rhs) {
    return ir_fcmp("one", type, lhs, rhs);
}

int ir_fcmp_olt(const char* type, const char* lhs, const char* rhs) {
    return ir_fcmp("olt", type, lhs, rhs);
}

int ir_fcmp_ole(const char* type, const char* lhs, const char* rhs) {
    return ir_fcmp("ole", type, lhs, rhs);
}

int ir_fcmp_ogt(const char* type, const char* lhs, const char* rhs) {
    return ir_fcmp("ogt", type, lhs, rhs);
}

int ir_fcmp_oge(const char* type, const char* lhs, const char* rhs) {
    return ir_fcmp("oge", type, lhs, rhs);
}

// ============================================
// Control Flow Instructions
// ============================================

void ir_ret(const char* type, const char* value) {
    char buffer[256];
    sprintf(buffer, "  ret %s %s", type, value);
    ir_append_line(buffer);
}

void ir_ret_void() {
    ir_append_line("  ret void");
}

void ir_br(const char* label) {
    char buffer[256];
    sprintf(buffer, "  br label %%%s", label);
    ir_append_line(buffer);
}

void ir_br_numbered(int label_num) {
    char buffer[256];
    sprintf(buffer, "  br label %%label_%d", label_num);
    ir_append_line(buffer);
}

void ir_cond_br(const char* condition, const char* true_label, const char* false_label) {
    char buffer[256];
    sprintf(buffer, "  br i1 %s, label %%%s, label %%%s", condition, true_label, false_label);
    ir_append_line(buffer);
}

void ir_cond_br_numbered(const char* condition, int true_label, int false_label) {
    char buffer[256];
    sprintf(buffer, "  br i1 %s, label %%label_%d, label %%label_%d",
            condition, true_label, false_label);
    ir_append_line(buffer);
}

// ============================================
// Call Instructions
// ============================================

int ir_call_void(const char* function_name, const char** arg_types,
                 const char** arg_values, int arg_count) {
    char buffer[512];
    sprintf(buffer, "  call void @%s(", function_name);
    ir_append(buffer);

    for (int i = 0; i < arg_count; i++) {
        if (i > 0) ir_append(", ");
        ir_append(arg_types[i]);
        ir_append(" ");
        ir_append(arg_values[i]);
    }

    ir_append_line(")");
    return -1;  // void call has no return value
}

int ir_call(const char* return_type, const char* function_name,
            const char** arg_types, const char** arg_values, int arg_count) {
    int temp = ir_get_temp();
    char buffer[512];
    sprintf(buffer, "  %%t%d = call %s @%s(", temp, return_type, function_name);
    ir_append(buffer);

    for (int i = 0; i < arg_count; i++) {
        if (i > 0) ir_append(", ");
        ir_append(arg_types[i]);
        ir_append(" ");
        ir_append(arg_values[i]);
    }

    ir_append_line(")");
    return temp;
}

// ============================================
// Type Conversion Instructions
// ============================================

int ir_zext(const char* from_type, const char* value, const char* to_type) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = zext %s %s to %s", temp, from_type, value, to_type);
    ir_append_line(buffer);
    return temp;
}

int ir_sext(const char* from_type, const char* value, const char* to_type) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = sext %s %s to %s", temp, from_type, value, to_type);
    ir_append_line(buffer);
    return temp;
}

int ir_trunc(const char* from_type, const char* value, const char* to_type) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = trunc %s %s to %s", temp, from_type, value, to_type);
    ir_append_line(buffer);
    return temp;
}

int ir_bitcast(const char* from_type, const char* value, const char* to_type) {
    int temp = ir_get_temp();
    char buffer[256];
    sprintf(buffer, "  %%t%d = bitcast %s %s to %s", temp, from_type, value, to_type);
    ir_append_line(buffer);
    return temp;
}

// ============================================
// Global Variables
// ============================================

void ir_global_string(const char* name, const char* str_content) {
    int len = strlen(str_content);
    char escaped[2048];
    int out = 0;

    for (int i = 0; str_content[i] != '\0' && out < (int)sizeof(escaped) - 4; i++) {
        unsigned char c = (unsigned char)str_content[i];
        if (c == '\\') {
            escaped[out++] = '\\';
            escaped[out++] = '5';
            escaped[out++] = 'C';
        } else if (c == '"') {
            escaped[out++] = '\\';
            escaped[out++] = '2';
            escaped[out++] = '2';
        } else if (c == '\n') {
            escaped[out++] = '\\';
            escaped[out++] = '0';
            escaped[out++] = 'A';
        } else if (c == '\r') {
            escaped[out++] = '\\';
            escaped[out++] = '0';
            escaped[out++] = 'D';
        } else if (c == '\t') {
            escaped[out++] = '\\';
            escaped[out++] = '0';
            escaped[out++] = '9';
        } else {
            escaped[out++] = c;
        }
    }
    escaped[out] = '\0';

    char buffer[4096];

    sprintf(buffer, "@%s = private unnamed_addr constant [%d x i8] c\"%s\\00\"",
            name, len + 1, escaped);
    ir_append_line(buffer);
}

void ir_global_var(const char* name, const char* type, const char* init_value, int is_const) {
    char buffer[256];
    sprintf(buffer, "@%s = %s global %s %s",
            name,
            is_const ? "constant" : "",
            type,
            init_value);
    ir_append_line(buffer);
}

const char* ir_get_temp_name(int temp_num) {
    char* result = (char*)malloc(64);
    sprintf(result, "%%t%d", temp_num);
    return result;
}

const char* ir_get_label_name(int label_num) {
    char* result = (char*)malloc(64);
    sprintf(result, "label_%d", label_num);
    return result;
}

// ============================================
// High-level Helper Functions
// ============================================

void ir_comment(const char* comment) {
    ir_append("; ");
    ir_append_line(comment);
}

// ============================================
// Global Variable Name Registry
// ============================================

static char global_names[256][64];
static int global_name_count = 0;

void ir_register_global_name(const char* name) {
    if (global_name_count < 256) {
        strncpy(global_names[global_name_count], name, 63);
        global_names[global_name_count][63] = '\0';
        global_name_count++;
    }
}

int ir_is_global_name(const char* name) {
    for (int i = 0; i < global_name_count; i++) {
        if (strcmp(global_names[i], name) == 0) return 1;
    }
    return 0;
}

void ir_reset_globals() {
    global_name_count = 0;
}

// ============================================
// Struct / Enum Type Registry
// ============================================

typedef struct {
    char name[64];
    int field_count;
    char field_names[32][64];
    char field_types[32][64];
} StructInfo;

static StructInfo struct_infos[128];
static int struct_info_count = 0;

typedef struct {
    char enum_name[64];
    char variant_name[64];
    int value;
} EnumVariantInfo;

static EnumVariantInfo enum_variants[512];
static int enum_variant_count = 0;

void ir_reset_types() {
    struct_info_count = 0;
    enum_variant_count = 0;
}

int ir_is_struct_type_name(const char* name) {
    for (int i = 0; i < struct_info_count; i++) {
        if (strcmp(struct_infos[i].name, name) == 0) return 1;
    }
    return 0;
}

void ir_register_struct(const char* name) {
    if (ir_is_struct_type_name(name)) return;
    if (struct_info_count >= 128) return;

    strncpy(struct_infos[struct_info_count].name, name, 63);
    struct_infos[struct_info_count].name[63] = '\0';
    struct_infos[struct_info_count].field_count = 0;
    struct_info_count++;
}

void ir_register_struct_field(const char* struct_name, const char* field_name, const char* field_type) {
    for (int i = 0; i < struct_info_count; i++) {
        if (strcmp(struct_infos[i].name, struct_name) == 0) {
            int idx = struct_infos[i].field_count;
            if (idx >= 32) return;
            strncpy(struct_infos[i].field_names[idx], field_name, 63);
            struct_infos[i].field_names[idx][63] = '\0';
            strncpy(struct_infos[i].field_types[idx], field_type, 63);
            struct_infos[i].field_types[idx][63] = '\0';
            struct_infos[i].field_count++;
            return;
        }
    }
}

int ir_get_struct_field_index(const char* struct_name, const char* field_name) {
    for (int i = 0; i < struct_info_count; i++) {
        if (strcmp(struct_infos[i].name, struct_name) == 0) {
            for (int j = 0; j < struct_infos[i].field_count; j++) {
                if (strcmp(struct_infos[i].field_names[j], field_name) == 0) return j;
            }
        }
    }
    return -1;
}

const char* ir_get_struct_field_type(const char* struct_name, const char* field_name) {
    for (int i = 0; i < struct_info_count; i++) {
        if (strcmp(struct_infos[i].name, struct_name) == 0) {
            for (int j = 0; j < struct_infos[i].field_count; j++) {
                if (strcmp(struct_infos[i].field_names[j], field_name) == 0) return struct_infos[i].field_types[j];
            }
        }
    }
    return "i32";
}

void ir_register_enum_variant(const char* enum_name, const char* variant_name, int value) {
    if (enum_variant_count >= 512) return;
    strncpy(enum_variants[enum_variant_count].enum_name, enum_name, 63);
    enum_variants[enum_variant_count].enum_name[63] = '\0';
    strncpy(enum_variants[enum_variant_count].variant_name, variant_name, 63);
    enum_variants[enum_variant_count].variant_name[63] = '\0';
    enum_variants[enum_variant_count].value = value;
    enum_variant_count++;
}

int ir_get_enum_variant(const char* enum_name, const char* variant_name) {
    for (int i = 0; i < enum_variant_count; i++) {
        if (strcmp(enum_variants[i].enum_name, enum_name) == 0 &&
            strcmp(enum_variants[i].variant_name, variant_name) == 0) {
            return enum_variants[i].value;
        }
    }
    return -1;
}

// Variable Type Tracking (Symbol Table MVP)
#define MAX_VAR_TYPES 4096
static char var_types_names[MAX_VAR_TYPES][64];
static char var_types[MAX_VAR_TYPES][64];
static int var_type_count = 0;

void ir_set_var_type(const char* name, const char* type) {
    if (var_type_count < MAX_VAR_TYPES) {
        strncpy(var_types_names[var_type_count], name, 63);
        var_types_names[var_type_count][63] = '\0';
        strncpy(var_types[var_type_count], type, 63);
        var_types[var_type_count][63] = '\0';
        var_type_count++;
    }
}

const char* ir_get_var_type(const char* name) {
    // Search backwards to support variable shadowing in inner blocks
    for (int i = var_type_count - 1; i >= 0; i--) {
        if (strcmp(var_types_names[i], name) == 0) {
            return var_types[i];
        }
    }
    return "i64"; // Default type if unknown
}

int ir_has_var_type(const char* name) {
    for (int i = var_type_count - 1; i >= 0; i--) {
        if (strcmp(var_types_names[i], name) == 0) {
            return 1;
        }
    }
    return 0;
}

void ir_clear_var_types() {
    var_type_count = 0;
}

void ir_clear_local_var_types() {
    int write = 0;
    for (int read = 0; read < var_type_count; read++) {
        if (strncmp(var_types_names[read], "$fn$", 4) == 0 || ir_is_global_name(var_types_names[read])) {
            if (write != read) {
                strncpy(var_types_names[write], var_types_names[read], 63);
                var_types_names[write][63] = '\0';
                strncpy(var_types[write], var_types[read], 63);
                var_types[write][63] = '\0';
            }
            write++;
        }
    }
    var_type_count = write;
}

// --- move tracking (MVS): names of move-only values that have been moved-from ---
#define MAX_MOVED 1024
static char moved_names[MAX_MOVED][64];
static int moved_count = 0;

void ir_clear_moved() {
    moved_count = 0;
}

int ir_is_moved(const char* name) {
    for (int i = 0; i < moved_count; i++) {
        if (strcmp(moved_names[i], name) == 0) return 1;
    }
    return 0;
}

void ir_mark_moved(const char* name) {
    if (ir_is_moved(name)) return;
    if (moved_count < MAX_MOVED) {
        strncpy(moved_names[moved_count], name, 63);
        moved_names[moved_count][63] = '\0';
        moved_count++;
    }
}

// Moved-from state is tracked per name, but a `let` binds a *fresh* value to that
// name, so whatever was moved out of the previous binding no longer applies. Without
// this, reusing an ordinary name (`let t = ...` twice in one function, in different
// branches) makes every use after the first move a spurious "use of moved value".
void ir_unmark_moved(const char* name) {
    for (int i = 0; i < moved_count; i++) {
        if (strcmp(moved_names[i], name) == 0) {
            for (int j = i; j < moved_count - 1; j++) {
                memcpy(moved_names[j], moved_names[j + 1], sizeof(moved_names[j]));
            }
            moved_count--;
            return;
        }
    }
}

// --- borrow tracking (MVS): names bound to non-owning (let/inout) parameters ---
#define MAX_BORROWED 1024
static char borrowed_names[MAX_BORROWED][64];
static int borrowed_count = 0;

void ir_clear_borrowed() {
    borrowed_count = 0;
}

int ir_is_borrowed(const char* name) {
    for (int i = 0; i < borrowed_count; i++) {
        if (strcmp(borrowed_names[i], name) == 0) return 1;
    }
    return 0;
}

void ir_mark_borrowed(const char* name) {
    if (ir_is_borrowed(name)) return;
    if (borrowed_count < MAX_BORROWED) {
        strncpy(borrowed_names[borrowed_count], name, 63);
        borrowed_names[borrowed_count][63] = '\0';
        borrowed_count++;
    }
}

// Return tracking
static int has_returned = 0;

void ir_set_returned() {
    has_returned = 1;
}

int ir_has_returned() {
    return has_returned;
}

void ir_clear_returned() {
    has_returned = 0;
}

void ir_blank_line() {
    ir_append_line("");
}

// Print current IR buffer to stdout
void ir_print() {
    printf("%s", ir_buffer);
}

// Write IR to file and close
int ir_write_file(const char* filename) {
    ir_open_file(filename);
    if (!output_file) return 1;

    ir_write_to_file();
    ir_close_file();
    return 0;
}

// ============================================
// Example: Generate a simple function
// ============================================

void ir_example_generate_add_function() {
    ir_module_start("example");

    // Function: i32 @add(i32 %a, i32 %b)
    ir_function_begin("add", "i32");
    ir_function_param("i32", "a");
    ir_function_param("i32", "b");
    ir_function_body_start();

    ir_label("entry");

    int result = ir_add("i32", "%a", "%b");

    char ret_value[32];
    sprintf(ret_value, "%%t%d", result);
    ir_ret("i32", ret_value);

    ir_function_end();
}
