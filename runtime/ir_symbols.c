// ============================================================================
// Compiler symbol tables and ownership bookkeeping.
//
// These are the frontend's own data structures -- what a struct's fields are,
// which names are globals, what type each binding has, which values have been
// moved from or borrowed, and where break/continue jump to. None of it is
// backend state: it describes the program being compiled, not the IR being
// produced.
//
// It used to live in llvm-bridge.c purely because that was the only C file the
// frontend already talked to. That became a problem the moment a second backend
// existed: linking the LLVM C API backend left every one of these undefined,
// even though none of them have anything to do with emitting IR. They are
// shared here so both backends link against the same copy and neither owns it.
//
// Known limits, unchanged from the original implementation and worth fixing
// when this grows a real hash map: names are truncated at 63 characters, and
// every table silently stops recording once full rather than reporting it.
// Mangled overload symbols already exceed 63 characters, so two overloads
// sharing a long prefix would collide in the type table.
// ============================================================================

#include <stdio.h>  // snprintf, for building slot names
#include <string.h>

// ============================================================================
// Loop context stack -- break/continue targets, supports nesting
// ============================================================================

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

void ir_loop_pop(void) {
    if (loop_depth > 0) loop_depth--;
}

int ir_loop_continue_label(void) {
    return loop_depth > 0 ? loop_continue_stack[loop_depth - 1] : -1;
}

int ir_loop_break_label(void) {
    return loop_depth > 0 ? loop_break_stack[loop_depth - 1] : -1;
}

// ============================================================================
// Global variable name registry
// ============================================================================

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

void ir_reset_globals(void) {
    global_name_count = 0;
}

// ============================================================================
// Struct / enum type registry
// ============================================================================

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

void ir_reset_types(void) {
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

// Number of fields registered for a struct, so a backend can build the type
// body without knowing how the frontend stored it.
int ir_get_struct_field_count(const char* struct_name) {
    for (int i = 0; i < struct_info_count; i++) {
        if (strcmp(struct_infos[i].name, struct_name) == 0) return struct_infos[i].field_count;
    }
    return 0;
}

const char* ir_get_struct_field_type_at(const char* struct_name, int index) {
    for (int i = 0; i < struct_info_count; i++) {
        if (strcmp(struct_infos[i].name, struct_name) == 0) {
            if (index < 0 || index >= struct_infos[i].field_count) return "i32";
            return struct_infos[i].field_types[index];
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

// ============================================================================
// Variable type tracking
// ============================================================================

// Bindings, innermost last.
//
// A block pushes a scope on entry and pops it on exit, which simply truncates
// the table back to where it started. Lookup scans backwards, so the innermost
// binding of a name wins and an outer one becomes visible again when the inner
// scope is popped. Before this existed the table was flat and cleared only per
// function, so a `let` inside an `if` stayed visible after the block ended.
//
// Each binding also carries its own slot name -- the identifier codegen uses for
// the alloca. Two `let x` in sibling blocks are two entries with two distinct
// slots, which is what stops them sharing one stack allocation sized by
// whichever appeared first (an i8 slot written with an 8-byte pointer, say).
//
// is_global distinguishes a module-level binding from a local, because codegen
// has to emit @name for one and %slot for the other. Asking a separate registry
// "is this name a global?" was wrong in the presence of shadowing: a local named
// the same as a global had its writes go to the local slot and its reads come
// from the global.

#define MAX_VAR_TYPES 4096
#define MAX_SCOPES 256
#define SLOT_LEN 80

typedef struct {
    char name[64];
    char type[64];
    char slot[SLOT_LEN];
    int is_global;
    int is_mutable;
} VarBinding;

static VarBinding var_bindings[MAX_VAR_TYPES];
static int var_type_count = 0;

static int scope_marks[MAX_SCOPES];
static int scope_depth = 0;

// Monotonic across a whole module, so a slot name is unique no matter how many
// blocks declare the same identifier.
static int slot_serial = 0;

void ir_scope_push(void) {
    if (scope_depth < MAX_SCOPES) {
        scope_marks[scope_depth] = var_type_count;
        scope_depth++;
    }
}

void ir_scope_pop(void) {
    if (scope_depth > 0) {
        scope_depth--;
        var_type_count = scope_marks[scope_depth];
    }
}

// Loop barriers: the binding-table watermark on entry to each loop body.
//
// Move checking is per-name and runs over the AST in source order, so it sees a
// `drop(x)` inside a loop exactly once and concludes the value is consumed once
// -- while at run time the loop executes it repeatedly. That is a double free
// the checker could not see. A binding that predates the innermost loop is one
// the loop did not create, so moving out of it inside the loop is the case that
// actually repeats.
static int loop_barriers[64];
static int loop_barrier_depth = 0;

void ir_loop_barrier_push(void) {
    if (loop_barrier_depth < 64) loop_barriers[loop_barrier_depth++] = var_type_count;
}

void ir_loop_barrier_pop(void) {
    if (loop_barrier_depth > 0) loop_barrier_depth--;
}

static int find_binding(const char* name);

// 1 when `name` is bound outside the innermost enclosing loop.
int ir_binding_predates_loop(const char* name) {
    if (loop_barrier_depth == 0) return 0;
    int i = find_binding(name);
    if (i < 0) return 0;
    return i < loop_barriers[loop_barrier_depth - 1] ? 1 : 0;
}

static int find_binding(const char* name) {
    for (int i = var_type_count - 1; i >= 0; i--) {
        if (strcmp(var_bindings[i].name, name) == 0) return i;
    }
    return -1;
}

static void add_binding(const char* name, const char* type, int is_global) {
    if (var_type_count >= MAX_VAR_TYPES) return;
    VarBinding* b = &var_bindings[var_type_count];

    strncpy(b->name, name, 63);
    b->name[63] = '\0';
    strncpy(b->type, type, 63);
    b->type[63] = '\0';
    b->is_global = is_global;
    b->is_mutable = 0;

    if (is_global) {
        // Globals are addressed by their own name (@name), so no renaming.
        strncpy(b->slot, name, SLOT_LEN - 1);
        b->slot[SLOT_LEN - 1] = '\0';
    } else {
        // '.' cannot appear in a Prismio identifier, so a slot name can never
        // collide with a user variable.
        snprintf(b->slot, SLOT_LEN, "%.60s.%d", name, slot_serial++);
    }

    var_type_count++;
}

// Declares a binding in the current scope. Each call is a distinct binding, so
// re-declaring a name shadows rather than overwrites.
void ir_set_var_type(const char* name, const char* type) {
    add_binding(name, type, 0);
}

void ir_set_global_var_type(const char* name, const char* type) {
    add_binding(name, type, 1);
}

const char* ir_get_var_type(const char* name) {
    int i = find_binding(name);
    return i >= 0 ? var_bindings[i].type : "i64"; // default if unknown
}

// The LLVM-level name for the innermost binding of `name`.
const char* ir_get_var_slot(const char* name) {
    int i = find_binding(name);
    return i >= 0 ? var_bindings[i].slot : name;
}

// Whether the innermost binding of `name` is module-level. Shadowing-aware, so
// a local that happens to share a global's name reports 0.
int ir_var_is_global(const char* name) {
    int i = find_binding(name);
    return i >= 0 ? var_bindings[i].is_global : 0;
}

int ir_has_var_type(const char* name) {
    return find_binding(name) >= 0;
}

// `let mut` marks the binding just declared. Assignment to anything not so
// marked is rejected -- the parser has always recorded `mut`, but nothing read
// it, so explicit mutability was advertised and unenforced.
void ir_mark_mutable(const char* name) {
    int i = find_binding(name);
    if (i >= 0) var_bindings[i].is_mutable = 1;
}

int ir_var_is_mutable(const char* name) {
    int i = find_binding(name);
    return i >= 0 ? var_bindings[i].is_mutable : 1; // unknown names error elsewhere
}

void ir_clear_var_types(void) {
    var_type_count = 0;
    scope_depth = 0;
    slot_serial = 0;
}

// Drops everything a function introduced, keeping module-level bindings and the
// $fn$ return-type keys. Scopes handle blocks; this handles the function
// boundary itself.
void ir_clear_local_var_types(void) {
    int write = 0;
    for (int read = 0; read < var_type_count; read++) {
        if (strncmp(var_bindings[read].name, "$fn$", 4) == 0 || var_bindings[read].is_global) {
            if (write != read) var_bindings[write] = var_bindings[read];
            write++;
        }
    }
    var_type_count = write;
    scope_depth = 0;
}

// ============================================================================
// Move tracking (MVS): names of move-only values that have been moved-from
// ============================================================================

#define MAX_MOVED 1024
static char moved_names[MAX_MOVED][64];
static int moved_count = 0;

void ir_clear_moved(void) {
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

// ============================================================================
// Borrow tracking (MVS): names bound to non-owning (let/inout) parameters
// ============================================================================

#define MAX_BORROWED 1024
static char borrowed_names[MAX_BORROWED][64];
static int borrowed_count = 0;

void ir_clear_borrowed(void) {
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

// ============================================================================
// Return tracking
//
// Set when a block has emitted its terminator, so the caller knows not to emit
// a fall-through branch. break/continue reuse it for the same purpose.
// ============================================================================

static int has_returned = 0;

void ir_set_returned(void) {
    has_returned = 1;
}

int ir_has_returned(void) {
    return has_returned;
}

void ir_clear_returned(void) {
    has_returned = 0;
}
