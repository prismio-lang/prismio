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
// Every table was previously a fixed array of char[64] that truncated names at
// 63 characters and silently stopped recording once full. Both were latent
// silent-wrong-answer bugs rather than theoretical ones: mangled overload
// symbols in this compiler's own source already reach 77 characters, so two
// overloads sharing a long prefix would have been recorded as the same symbol
// and one would have been given the other's return type -- with no diagnostic,
// at any point. Names are now interned at full length and every table grows,
// so neither failure mode exists.
// ============================================================================

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// The compiler cannot continue meaningfully past an allocation failure, and
// pretending otherwise is how the old silent truncation happened. Say what
// broke and stop.
static void symbols_oom(const char* what) {
    fprintf(stderr, "internal error: out of memory growing %s\n", what);
    fflush(stderr);
    exit(1);
}

static void* xmalloc(size_t n, const char* what) {
    void* p = malloc(n);
    if (!p) symbols_oom(what);
    return p;
}

static void* xrealloc(void* p, size_t n, const char* what) {
    void* q = realloc(p, n);
    if (!q) symbols_oom(what);
    return q;
}

// ============================================================================
// Name interning
//
// Every name the tables hold is stored once, at full length, and referred to by
// a canonical pointer. Two benefits: nothing is ever truncated, and a lookup
// compares pointers instead of running strcmp against every entry -- which
// matters because find_binding() is called once per identifier in the program
// and scans backwards over the whole binding table.
//
// Interned strings live for the life of the process. There is nothing to free:
// a compiler run ends when compilation does.
// ============================================================================

#define INTERN_BUCKETS 4096

typedef struct InternNode {
    struct InternNode* next;
    unsigned hash;
    char text[1]; // over-allocated to hold the whole name
} InternNode;

static InternNode* intern_buckets[INTERN_BUCKETS];

static unsigned hash_str(const char* s) {
    // FNV-1a. Cheap, and good enough for identifiers.
    unsigned h = 2166136261u;
    while (*s) {
        h ^= (unsigned char)*s++;
        h *= 16777619u;
    }
    return h;
}

const char* ir_intern(const char* name) {
    if (!name) name = "";

    unsigned h = hash_str(name);
    unsigned bucket = h & (INTERN_BUCKETS - 1);

    for (InternNode* n = intern_buckets[bucket]; n; n = n->next) {
        if (n->hash == h && strcmp(n->text, name) == 0) return n->text;
    }

    size_t len = strlen(name);
    InternNode* n = (InternNode*)xmalloc(sizeof(InternNode) + len, "the name table");
    n->hash = h;
    memcpy(n->text, name, len + 1);
    n->next = intern_buckets[bucket];
    intern_buckets[bucket] = n;
    return n->text;
}

// ============================================================================
// Loop context stack -- break/continue targets, supports nesting
// ============================================================================

#define MAX_LOOP_DEPTH 256

static int loop_continue_stack[MAX_LOOP_DEPTH];
static int loop_break_stack[MAX_LOOP_DEPTH];
static int loop_depth = 0;

void ir_loop_push(int continue_label, int break_label) {
    if (loop_depth >= MAX_LOOP_DEPTH) {
        fprintf(stderr, "internal error: loops nested more than %d deep\n", MAX_LOOP_DEPTH);
        exit(1);
    }
    loop_continue_stack[loop_depth] = continue_label;
    loop_break_stack[loop_depth] = break_label;
    loop_depth++;
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
// A growable list of interned names, shared by the several tables that are
// exactly that (globals, moved-from values, borrowed values).
// ============================================================================

typedef struct {
    const char** items;
    int count;
    int capacity;
    const char* what; // named in the message if growing it fails
} NameList;

static void namelist_add(NameList* list, const char* name) {
    if (list->count == list->capacity) {
        int next = list->capacity ? list->capacity * 2 : 64;
        list->items = (const char**)xrealloc(list->items, (size_t)next * sizeof(char*), list->what);
        list->capacity = next;
    }
    list->items[list->count++] = ir_intern(name);
}

static int namelist_contains(const NameList* list, const char* name) {
    const char* interned = ir_intern(name);
    for (int i = 0; i < list->count; i++) {
        if (list->items[i] == interned) return 1;
    }
    return 0;
}

// ============================================================================
// Global variable name registry
// ============================================================================

static NameList global_names = { NULL, 0, 0, "the global name table" };

void ir_register_global_name(const char* name) {
    if (namelist_contains(&global_names, name)) return;
    namelist_add(&global_names, name);
}

int ir_is_global_name(const char* name) {
    return namelist_contains(&global_names, name);
}

void ir_reset_globals(void) {
    global_names.count = 0;
}

// ============================================================================
// Named type registry -- "is this identifier a struct, an enum, or neither?"
//
// Separate from the struct registry below, which holds field layouts and is
// populated by codegen. This one is filled by sema before checking begins and
// answers only the question a type annotation asks.
//
// It exists for speed. sema_annotation_type() used to answer by walking the
// whole module looking for a matching declaration, once per annotation -- and
// annotations are read for every parameter of every function, inside a loop over
// every function. On a 1600-function module that was the difference between
// quadratic and cubic.
// ============================================================================

static NameList struct_type_names = { NULL, 0, 0, "the struct name table" };
static NameList enum_type_names = { NULL, 0, 0, "the enum name table" };

// kind: 1 = struct, 2 = enum.
void ir_declare_named_type(const char* name, int kind) {
    NameList* list = (kind == 1) ? &struct_type_names : &enum_type_names;
    if (namelist_contains(list, name)) return;
    namelist_add(list, name);
}

// 1 = struct, 2 = enum, 0 = not a declared type.
int ir_named_type_kind(const char* name) {
    if (namelist_contains(&struct_type_names, name)) return 1;
    if (namelist_contains(&enum_type_names, name)) return 2;
    return 0;
}

void ir_reset_named_types(void) {
    struct_type_names.count = 0;
    enum_type_names.count = 0;
}

// ============================================================================
// Top-level declaration index -- "which declarations carry this name?"
//
// REQUIREMENTS 16. Every pass that wanted a declaration by name used to walk the
// module's statement list looking for it, and overload resolution does that once
// per call site: a module with D declarations and C calls paid D*C. It is the
// dominant cost on a large module and it is quadratic, so it does not show on
// the corpus and does show on anything the size of a real program.
//
// Filled once per module by index_module_declarations() (src/ast/types.psm),
// which every pass that reads the index calls first. It is a cache of exactly
// what a walk of the module would have found, in exactly the order the walk
// would have found it -- source order matters to two readers: the
// duplicate-definition diagnostic points at the *first* declaration carrying a
// symbol, and overload resolution reports the first match.
//
// The nodes are AST pointers, which the frontend puns as String. They are
// stored as opaque addresses and never compared as text -- strcmp on one would
// compare the bytes of the node.
// ============================================================================

#define DECL_INDEX_BUCKETS 1024

typedef struct DeclEntry {
    struct DeclEntry* next;
    const char* name; // interned
    const char** nodes;
    int count;
    int capacity;
} DeclEntry;

static DeclEntry* decl_buckets[DECL_INDEX_BUCKETS];

static DeclEntry* decl_entry(const char* name, int create) {
    const char* interned = ir_intern(name);
    unsigned bucket = hash_str(interned) & (DECL_INDEX_BUCKETS - 1);

    for (DeclEntry* e = decl_buckets[bucket]; e; e = e->next) {
        if (e->name == interned) return e;
    }
    if (!create) return NULL;

    DeclEntry* e = (DeclEntry*)xmalloc(sizeof(DeclEntry), "the declaration index");
    e->name = interned;
    e->nodes = NULL;
    e->count = 0;
    e->capacity = 0;
    e->next = decl_buckets[bucket];
    decl_buckets[bucket] = e;
    return e;
}

// Empties the index without freeing it. A second module is compiled in the same
// process during bootstrap, and reusing the node arrays is both simpler and
// correct -- the same reason ir_reset_types() keeps its field arrays.
void ir_reset_decl_index(void) {
    for (int b = 0; b < DECL_INDEX_BUCKETS; b++) {
        for (DeclEntry* e = decl_buckets[b]; e; e = e->next) e->count = 0;
    }
}

void ir_index_decl(const char* name, const char* node) {
    DeclEntry* e = decl_entry(name, 1);
    if (e->count == e->capacity) {
        int next = e->capacity ? e->capacity * 2 : 4;
        e->nodes = (const char**)xrealloc((void*)e->nodes, (size_t)next * sizeof(char*),
                                          "a declaration index entry");
        e->capacity = next;
    }
    e->nodes[e->count++] = node;
}

int ir_decl_count(const char* name) {
    DeclEntry* e = decl_entry(name, 0);
    return e ? e->count : 0;
}

// "" rather than NULL for an out-of-range index: the frontend spells "no node"
// as the empty string, and nodeExists() tests exactly that.
const char* ir_decl_at(const char* name, int index) {
    DeclEntry* e = decl_entry(name, 0);
    if (!e || index < 0 || index >= e->count) return "";
    return e->nodes[index];
}

// ============================================================================
// Function return types, by mangled symbol
//
// This was a binding in the table below, under a "$fn$" key that could not
// collide with a variable name. That made every one of them permanent -- they
// survive ir_clear_local_var_types() by design -- so find_binding(), which
// scans the table backwards, walked past one entry per function in the module
// for every identifier in every function body *and* for every call expression
// in codegen. Same shape as the walk above: quadratic, invisible on a small
// program.
//
// A table of its own also retires the "$fn$" prefix and the str_concat that
// built one per call site. There is no shared namespace left to disambiguate.
// ============================================================================

#define FN_RETURN_BUCKETS 1024

typedef struct FnReturn {
    struct FnReturn* next;
    const char* symbol; // interned
    const char* type;   // interned
} FnReturn;

static FnReturn* fn_return_buckets[FN_RETURN_BUCKETS];

void ir_set_fn_return_type(const char* symbol, const char* type) {
    const char* interned = ir_intern(symbol);
    unsigned bucket = hash_str(interned) & (FN_RETURN_BUCKETS - 1);

    for (FnReturn* r = fn_return_buckets[bucket]; r; r = r->next) {
        if (r->symbol == interned) {
            // Last writer wins, which is what a shadowing binding did.
            r->type = ir_intern(type);
            return;
        }
    }

    FnReturn* r = (FnReturn*)xmalloc(sizeof(FnReturn), "the function return-type table");
    r->symbol = interned;
    r->type = ir_intern(type);
    r->next = fn_return_buckets[bucket];
    fn_return_buckets[bucket] = r;
}

// "i64" for an unknown symbol, which is what ir_get_var_type() answered for a
// "$fn$" key that was never set. Same default, deliberately: a different one
// would change the IR emitted for a call the frontend failed to predeclare.
const char* ir_get_fn_return_type(const char* symbol) {
    const char* interned = ir_intern(symbol);
    unsigned bucket = hash_str(interned) & (FN_RETURN_BUCKETS - 1);

    for (FnReturn* r = fn_return_buckets[bucket]; r; r = r->next) {
        if (r->symbol == interned) return r->type;
    }
    return "i64";
}

// Frees, where ir_reset_decl_index() keeps its entries. The difference is that
// this table is read with two different vocabularies: sema stores its own type
// keys and codegen stores LLVM storage types. An entry left behind by sema and
// not overwritten by codegen -- an extern that a profile build stubs rather than
// declares -- would be read as a storage type. Emptying it is what kept the two
// apart when both lived in the binding table.
void ir_reset_fn_return_types(void) {
    for (int b = 0; b < FN_RETURN_BUCKETS; b++) {
        FnReturn* r = fn_return_buckets[b];
        while (r) {
            FnReturn* next = r->next;
            free(r);
            r = next;
        }
        fn_return_buckets[b] = NULL;
    }
}

// ============================================================================
// Struct / enum type registry
// ============================================================================

typedef struct {
    const char* name;
    const char* type;
} FieldInfo;

typedef struct {
    const char* name;
    FieldInfo* fields;
    int field_count;
    int field_capacity;
} StructInfo;

static StructInfo* struct_infos = NULL;
static int struct_info_count = 0;
static int struct_info_capacity = 0;

typedef struct {
    const char* enum_name;
    const char* variant_name;
    int value;
} EnumVariantInfo;

static EnumVariantInfo* enum_variants = NULL;
static int enum_variant_count = 0;
static int enum_variant_capacity = 0;

void ir_reset_types(void) {
    // The field arrays are kept, not freed: a reset is followed by another
    // module being compiled in the same process only during bootstrap, and
    // reusing the allocations is both simpler and correct.
    for (int i = 0; i < struct_info_count; i++) struct_infos[i].field_count = 0;
    struct_info_count = 0;
    enum_variant_count = 0;
}

static StructInfo* find_struct(const char* name) {
    const char* interned = ir_intern(name);
    for (int i = 0; i < struct_info_count; i++) {
        if (struct_infos[i].name == interned) return &struct_infos[i];
    }
    return NULL;
}

int ir_is_struct_type_name(const char* name) {
    return find_struct(name) != NULL;
}

void ir_register_struct(const char* name) {
    if (find_struct(name)) return;

    if (struct_info_count == struct_info_capacity) {
        int next = struct_info_capacity ? struct_info_capacity * 2 : 32;
        struct_infos = (StructInfo*)xrealloc(struct_infos, (size_t)next * sizeof(StructInfo),
                                             "the struct table");
        for (int i = struct_info_capacity; i < next; i++) {
            struct_infos[i].fields = NULL;
            struct_infos[i].field_count = 0;
            struct_infos[i].field_capacity = 0;
        }
        struct_info_capacity = next;
    }

    struct_infos[struct_info_count].name = ir_intern(name);
    struct_infos[struct_info_count].field_count = 0;
    struct_info_count++;
}

void ir_register_struct_field(const char* struct_name, const char* field_name, const char* field_type) {
    StructInfo* s = find_struct(struct_name);
    if (!s) return;

    if (s->field_count == s->field_capacity) {
        int next = s->field_capacity ? s->field_capacity * 2 : 16;
        s->fields = (FieldInfo*)xrealloc(s->fields, (size_t)next * sizeof(FieldInfo),
                                         "a struct's field table");
        s->field_capacity = next;
    }

    s->fields[s->field_count].name = ir_intern(field_name);
    s->fields[s->field_count].type = ir_intern(field_type);
    s->field_count++;
}

int ir_get_struct_field_index(const char* struct_name, const char* field_name) {
    StructInfo* s = find_struct(struct_name);
    if (!s) return -1;
    const char* interned = ir_intern(field_name);
    for (int j = 0; j < s->field_count; j++) {
        if (s->fields[j].name == interned) return j;
    }
    return -1;
}

const char* ir_get_struct_field_type(const char* struct_name, const char* field_name) {
    StructInfo* s = find_struct(struct_name);
    if (s) {
        const char* interned = ir_intern(field_name);
        for (int j = 0; j < s->field_count; j++) {
            if (s->fields[j].name == interned) return s->fields[j].type;
        }
    }
    return "i32";
}

// Number of fields registered for a struct, so a backend can build the type
// body without knowing how the frontend stored it.
int ir_get_struct_field_count(const char* struct_name) {
    StructInfo* s = find_struct(struct_name);
    return s ? s->field_count : 0;
}

const char* ir_get_struct_field_type_at(const char* struct_name, int index) {
    StructInfo* s = find_struct(struct_name);
    if (!s || index < 0 || index >= s->field_count) return "i32";
    return s->fields[index].type;
}

// The field's *source* name at a physical index. The sibling above answers what
// occupies slot i; this answers what the programmer called it, which is the half
// DWARF needs and the only place the two orders have to be reconciled.
// generateStructDecl registers in the order aif_layout_field chose, so index i
// here and element i of the LLVM struct are the same field by construction.
// Empty rather than a placeholder for an unknown index: a made-up field name in
// a debugger is worse than a gap.
const char* ir_get_struct_field_name_at(const char* struct_name, int index) {
    StructInfo* s = find_struct(struct_name);
    if (!s || index < 0 || index >= s->field_count) return "";
    return s->fields[index].name;
}

void ir_register_enum_variant(const char* enum_name, const char* variant_name, int value) {
    if (enum_variant_count == enum_variant_capacity) {
        int next = enum_variant_capacity ? enum_variant_capacity * 2 : 128;
        enum_variants = (EnumVariantInfo*)xrealloc(enum_variants,
                                                   (size_t)next * sizeof(EnumVariantInfo),
                                                   "the enum variant table");
        enum_variant_capacity = next;
    }

    enum_variants[enum_variant_count].enum_name = ir_intern(enum_name);
    enum_variants[enum_variant_count].variant_name = ir_intern(variant_name);
    enum_variants[enum_variant_count].value = value;
    enum_variant_count++;
}

// The variants of one enum, by position. The table is flat -- every variant of
// every enum in one array -- so "index i of this enum" means the i-th entry
// whose enum_name matches, not the i-th entry.
//
// The pair exists for DWARF: DW_TAG_enumeration_type needs every enumerator, and
// ir_get_enum_variant answers the other direction (name -> value), which cannot
// enumerate. Interned names make the comparison a pointer compare.
int ir_get_enum_variant_count(const char* enum_name) {
    const char* e = ir_intern(enum_name);
    int n = 0;
    for (int i = 0; i < enum_variant_count; i++) {
        if (enum_variants[i].enum_name == e) n++;
    }
    return n;
}

// Empty name and a zero value for an index that is not there, matching
// ir_get_struct_field_name_at: a made-up enumerator in a debugger is worse than
// a gap, and the caller checks the name.
const char* ir_get_enum_variant_name_at(const char* enum_name, int index) {
    const char* e = ir_intern(enum_name);
    int n = 0;
    for (int i = 0; i < enum_variant_count; i++) {
        if (enum_variants[i].enum_name != e) continue;
        if (n == index) return enum_variants[i].variant_name;
        n++;
    }
    return "";
}

int ir_get_enum_variant_value_at(const char* enum_name, int index) {
    const char* e = ir_intern(enum_name);
    int n = 0;
    for (int i = 0; i < enum_variant_count; i++) {
        if (enum_variants[i].enum_name != e) continue;
        if (n == index) return enum_variants[i].value;
        n++;
    }
    return 0;
}

int ir_get_enum_variant(const char* enum_name, const char* variant_name) {
    const char* e = ir_intern(enum_name);
    const char* v = ir_intern(variant_name);
    for (int i = 0; i < enum_variant_count; i++) {
        if (enum_variants[i].enum_name == e && enum_variants[i].variant_name == v) {
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

#define MAX_SCOPES 1024

typedef struct {
    const char* name;
    const char* type;
    const char* slot;
    int is_global;
    int is_mutable;
    // AIF Level 2: this binding's initialiser allocated a value whose escape
    // bottoms at the scope holding the binding, so the scope's exits are where
    // it is freed. Set by codegen from the tier; nothing here decides policy.
    int is_droppable;
    // AIF Level 4: which deallocator reclaims it. A list owns a second block --
    // its element array -- so a plain free on the handle leaks that block, and
    // the storage type cannot tell you: a list and a string are both `ptr`.
    int drop_kind;
} VarBinding;

static VarBinding* var_bindings = NULL;
static int var_type_count = 0;
static int var_type_capacity = 0;

static int scope_marks[MAX_SCOPES];
static int scope_depth = 0;

// Monotonic across a whole module, so a slot name is unique no matter how many
// blocks declare the same identifier.
static int slot_serial = 0;

void ir_scope_push(void) {
    if (scope_depth >= MAX_SCOPES) {
        fprintf(stderr, "internal error: blocks nested more than %d deep\n", MAX_SCOPES);
        exit(1);
    }
    scope_marks[scope_depth] = var_type_count;
    scope_depth++;
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
static int loop_barriers[MAX_LOOP_DEPTH];
static int loop_barrier_depth = 0;

void ir_loop_barrier_push(void) {
    if (loop_barrier_depth < MAX_LOOP_DEPTH) loop_barriers[loop_barrier_depth++] = var_type_count;
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

// ============================================================================
// Scope drop lists (AIF Level 2)
//
// A drop list is not a separate structure: the binding table is already a flat
// array with a watermark per scope, so "what dies when this scope exits" is the
// droppable bindings above that watermark. The same read with a different floor
// answers it for a `return` (the whole function) and for `break`/`continue` (the
// loop barrier), which is why those two watermarks already existing matters.
//
// Enumeration is reverse construction order, which SPEC's RAII requires: a value
// may hold a reference to one constructed before it, never after.
//
// Whether a binding was *moved* is deliberately not consulted, here or by the
// caller: move state belongs to sema and is cleared per function before codegen
// starts. What would have needed it is carried by the facts instead -- see
// generate_scope_drops.
// ============================================================================

void ir_mark_droppable(const char* name, int kind) {
    int i = find_binding(name);
    if (i >= 0) {
        var_bindings[i].is_droppable = 1;
        var_bindings[i].drop_kind = kind;
    }
}

int ir_scope_drop_floor(void) {
    return scope_depth > 0 ? scope_marks[scope_depth - 1] : 0;
}

// Its own stack rather than loop_barriers above: that one is sema's, pushed
// while move checking runs, and codegen is a separate walk. Sharing it would
// have made break/continue read a watermark of 0 and drop the whole function.
static int drop_barriers[MAX_LOOP_DEPTH];
static int barrier_regions[MAX_LOOP_DEPTH];
static int drop_barrier_depth = 0;

// How many `region` blocks are open. A return has to close all of them and a
// break/continue those the loop did not open, for the same reason each has to
// run the drops: an arena still on the stack at function exit is never released.
static int region_depth = 0;

void ir_region_enter(void) { region_depth++; }
void ir_region_exit(void)  { if (region_depth > 0) region_depth--; }
int  ir_region_depth(void) { return region_depth; }

int ir_loop_region_depth(void) {
    return drop_barrier_depth > 0 ? barrier_regions[drop_barrier_depth - 1] : 0;
}

void ir_drop_barrier_push(void) {
    if (drop_barrier_depth < MAX_LOOP_DEPTH) {
        barrier_regions[drop_barrier_depth] = region_depth;
        drop_barriers[drop_barrier_depth++] = var_type_count;
    }
}

void ir_drop_barrier_pop(void) {
    if (drop_barrier_depth > 0) drop_barrier_depth--;
}

int ir_loop_drop_floor(void) {
    return drop_barrier_depth > 0 ? drop_barriers[drop_barrier_depth - 1] : 0;
}

int ir_drop_count(int floor) {
    if (floor < 0) floor = 0;
    int n = 0;
    for (int i = floor; i < var_type_count; i++) {
        if (var_bindings[i].is_droppable) n++;
    }
    return n;
}

// The i-th droppable binding at or above `floor`, counting from the most
// recently constructed.
static int drop_index(int floor, int i) {
    if (floor < 0) floor = 0;
    int n = 0;
    for (int k = var_type_count - 1; k >= floor; k--) {
        if (!var_bindings[k].is_droppable) continue;
        if (n == i) return k;
        n++;
    }
    return -1;
}

const char* ir_drop_slot(int floor, int i) {
    int k = drop_index(floor, i);
    return k >= 0 ? var_bindings[k].slot : "";
}

const char* ir_drop_type(int floor, int i) {
    int k = drop_index(floor, i);
    return k >= 0 ? var_bindings[k].type : "";
}

int ir_drop_kind(int floor, int i) {
    int k = drop_index(floor, i);
    return k >= 0 ? var_bindings[k].drop_kind : 0;
}

static int find_binding(const char* name) {
    const char* interned = ir_intern(name);
    for (int i = var_type_count - 1; i >= 0; i--) {
        if (var_bindings[i].name == interned) return i;
    }
    return -1;
}

static void add_binding(const char* name, const char* type, int is_global) {
    if (var_type_count == var_type_capacity) {
        int next = var_type_capacity ? var_type_capacity * 2 : 256;
        var_bindings = (VarBinding*)xrealloc(var_bindings, (size_t)next * sizeof(VarBinding),
                                             "the binding table");
        var_type_capacity = next;
    }

    VarBinding* b = &var_bindings[var_type_count];
    b->name = ir_intern(name);
    b->type = ir_intern(type);
    b->is_global = is_global;
    b->is_mutable = 0;
    b->is_droppable = 0;
    b->drop_kind = 0;

    if (is_global) {
        // Globals are addressed by their own name (@name), so no renaming.
        b->slot = b->name;
    } else {
        // '.' cannot appear in a Prismio identifier, so a slot name can never
        // collide with a user variable. Built at full length: truncating here
        // was how two long distinct names ended up sharing one stack slot.
        size_t len = strlen(b->name) + 24;
        char* slot = (char*)xmalloc(len, "a slot name");
        snprintf(slot, len, "%s.%d", b->name, slot_serial++);
        b->slot = ir_intern(slot);
        free(slot);
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

static NameList moved_names = { NULL, 0, 0, "the moved-value table" };

void ir_clear_moved(void) {
    moved_names.count = 0;
}

int ir_is_moved(const char* name) {
    return namelist_contains(&moved_names, name);
}

void ir_mark_moved(const char* name) {
    if (ir_is_moved(name)) return;
    namelist_add(&moved_names, name);
}

// Moved-from state is tracked per name, but a `let` binds a *fresh* value to that
// name, so whatever was moved out of the previous binding no longer applies. Without
// this, reusing an ordinary name (`let t = ...` twice in one function, in different
// branches) makes every use after the first move a spurious "use of moved value".
void ir_unmark_moved(const char* name) {
    const char* interned = ir_intern(name);
    for (int i = 0; i < moved_names.count; i++) {
        if (moved_names.items[i] == interned) {
            for (int j = i; j < moved_names.count - 1; j++) {
                moved_names.items[j] = moved_names.items[j + 1];
            }
            moved_names.count--;
            return;
        }
    }
}

// ============================================================================
// Borrow tracking (MVS): names bound to non-owning (let/inout) parameters
// ============================================================================

static NameList borrowed_names = { NULL, 0, 0, "the borrowed-value table" };

void ir_clear_borrowed(void) {
    borrowed_names.count = 0;
}

int ir_is_borrowed(const char* name) {
    return namelist_contains(&borrowed_names, name);
}

void ir_mark_borrowed(const char* name) {
    if (ir_is_borrowed(name)) return;
    namelist_add(&borrowed_names, name);
}

// Same reason ir_unmark_moved exists. A `let` binds a fresh value, and AIF Level
// 4 made borrowing something a `let` can do -- `let p = node.child1` reborrows
// the field -- so a name that reborrowed once and owns the next time must not
// keep the first answer.
void ir_unmark_borrowed(const char* name) {
    const char* interned = ir_intern(name);
    for (int i = 0; i < borrowed_names.count; i++) {
        if (borrowed_names.items[i] == interned) {
            for (int j = i; j < borrowed_names.count - 1; j++) {
                borrowed_names.items[j] = borrowed_names.items[j + 1];
            }
            borrowed_names.count--;
            return;
        }
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
