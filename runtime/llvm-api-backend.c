// ============================================================================
// Prismio backend built on the real LLVM C API.
//
// This is the replacement for llvm-bridge.c, which assembled LLVM IR as text in
// fixed-size buffers. Both implement the same ir_* surface declared in
// src/bridge.psm, so exactly one is linked into the compiler and the frontend
// does not know which. Select this one with:
//
//     clang -DPRISMIO_BACKEND_LLVM_API ...   (and link LLVM-C)
//
// Why this exists at all, beyond tidiness: the text emitter could only be
// checked by llc's parser after the fact, so a malformed instruction surfaced as
// a parse error pointing at generated IR rather than at the code that built it.
// Here LLVMVerifyModule runs before anything is written, the IRBuilder refuses
// to construct type-incorrect instructions in the first place, and constants are
// folded as they are built. It is also the prerequisite for a custom memory
// model: allocation is a policy hook here (see "memory model" below) instead of
// a hardcoded `call ptr @malloc` spelled out in the frontend.
//
// ---------------------------------------------------------------------------
// How values cross the FFI
//
// Prismio has no pointer type, so the frontend passes everything as String. The
// compiler already relies on this for AST nodes (ptr_to_node/node_to_ptr). Here
// a value is a *handle string*, and every function that accepts a value resolves
// it through resolve_value():
//
//     "$$v12"      -> g_values[12], an LLVMValueRef produced by an earlier call
//     "%p_argc"    -> a parameter of the function being built, looked up by name
//     "%x"         -> a named alloca in the current function
//     anything else -> a literal constant, parsed according to the type argument
//
// The literal case is what lets the existing frontend keep passing "0", "42",
// "true" and "null" straight through without being rewritten first. '$' cannot
// appear in a Prismio identifier, so a handle can never collide with user text.
//
// ---------------------------------------------------------------------------
// Status: this is the only backend. llvm-bridge.c has been deleted.
//
// The compiler self-hosts on this backend to a fixed point and passes the full
// test suite. src/ir.psm no longer emits any IR text -- struct literals, member
// access, array literals, indexing, string literals and struct type definitions
// all go through the typed builders below.
//
// ir_append() is kept as a loud failure rather than removed. Nothing calls it,
// and nothing should: it is the guard that stops raw text creeping back in,
// where it would silently produce a module with instructions missing.
// ============================================================================

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "prismio_llvm.h"

// ============================================================================
// Module state
// ============================================================================

#define MAX_VALUES 65536
#define MAX_LABELS 16384
#define MAX_NAMED 4096
#define MAX_CALL_DEPTH 64
#define MAX_CALL_ARGS 64
#define MAX_PENDING_PARAMS 64
#define NAME_LEN 128

static LLVMContextRef g_ctx;
static LLVMModuleRef g_module;
static LLVMBuilderRef g_builder;
// Second builder, used only for allocas. They must land in the entry block no
// matter where codegen currently is, or a `let` inside a loop body would grow
// the stack on every iteration.
static LLVMBuilderRef g_alloca_builder;
static LLVMBasicBlockRef g_entry_block;
static int g_initialized;

static LLVMValueRef g_values[MAX_VALUES];
static int g_value_count;

// Blocks are reserved before they are created: the frontend asks for a label
// number, branches to it, and only later says "the block starts here". So a slot
// is handed out immediately and the LLVMBasicBlockRef is materialised on first
// use.
static LLVMBasicBlockRef g_blocks[MAX_LABELS];
static int g_label_count;

typedef struct {
    char name[NAME_LEN];
    LLVMValueRef value;
    LLVMTypeRef type; // allocated type, for load/GEP
} NamedValue;

static NamedValue g_allocas[MAX_NAMED];
static int g_alloca_count;
static NamedValue g_params[MAX_PENDING_PARAMS];
static int g_param_count;

// Function currently being built.
static LLVMValueRef g_function;
static char g_pending_fn_name[NAME_LEN];
static LLVMTypeRef g_pending_ret;
static LLVMTypeRef g_pending_params[MAX_PENDING_PARAMS];
static char g_pending_param_names[MAX_PENDING_PARAMS][NAME_LEN];
static int g_pending_param_count;
static int g_declaring; // 1 while building a `declare`, 0 for a definition

// Call being assembled.
typedef struct {
    LLVMValueRef args[MAX_CALL_ARGS];
    int count;
} CallFrame;
static CallFrame g_calls[MAX_CALL_DEPTH];
static int g_call_depth;

static int g_has_returned;

// ============================================================================
// Memory model policy
//
// Object allocation is deliberately indirect. The frontend asks for "an object
// of this struct type" and this layer decides what that means, so swapping
// malloc for an arena, a refcounting allocator, or anything else is a change
// here and not a change to codegen. Defaults keep today's behaviour exactly.
// ============================================================================

static char g_alloc_fn[NAME_LEN] = "malloc";
static char g_free_fn[NAME_LEN] = "free";

// Pointer-sized integer for the current target: i64 natively, i32 on wasm32.
// Determines the width of the size argument passed to the allocator.
static char g_ptr_int[16] = "i64";

void ir_set_pointer_int_type(const char *t) {
    if (t && *t) {
        strncpy(g_ptr_int, t, sizeof(g_ptr_int) - 1);
        g_ptr_int[sizeof(g_ptr_int) - 1] = '\0';
    }
}

void ir_set_alloc_function(const char *name) {
    if (name && *name) {
        strncpy(g_alloc_fn, name, NAME_LEN - 1);
        g_alloc_fn[NAME_LEN - 1] = '\0';
    }
}

void ir_set_free_function(const char *name) {
    if (name && *name) {
        strncpy(g_free_fn, name, NAME_LEN - 1);
        g_free_fn[NAME_LEN - 1] = '\0';
    }
}

const char *ir_get_alloc_function(void) { return g_alloc_fn; }
const char *ir_get_free_function(void) { return g_free_fn; }

// The LLVM actually loaded, for `prismio --version`. Reported rather than
// hardcoded so a version mismatch is visible without having to trigger it.
const char *ir_llvm_version(void) {
    static char buf[32];
    unsigned major = 0, minor = 0, patch = 0;
    LLVMGetVersion(&major, &minor, &patch);
    snprintf(buf, sizeof(buf), "%u.%u.%u", major, minor, patch);
    return buf;
}

// ============================================================================
// Diagnostics
// ============================================================================

static void backend_fail(const char *what, const char *detail) {
    fprintf(stderr, "internal backend error: %s", what);
    if (detail) fprintf(stderr, " (%s)", detail);
    fprintf(stderr, "\n");
    exit(1);
}

// ============================================================================
// Value table
// ============================================================================

static int intern_value(LLVMValueRef v) {
    if (g_value_count >= MAX_VALUES) backend_fail("value table exhausted", NULL);
    g_values[g_value_count] = v;
    return g_value_count++;
}

const char *ir_get_temp_name(int id) {
    char *out = (char *)malloc(32);
    snprintf(out, 32, "$$v%d", id);
    return out;
}

const char *ir_get_label_name(int id) {
    char *out = (char *)malloc(32);
    snprintf(out, 32, "label_%d", id);
    return out;
}

// Reserves a slot without an instruction behind it yet.
int ir_get_temp(void) { return intern_value(NULL); }

// ============================================================================
// Types
// ============================================================================

static LLVMTypeRef named_struct(const char *name);

// Maps the frontend's type keys ("i32", "double", "ptr", "struct:Foo") onto
// LLVM types. Unknown keys are a hard error rather than a silent i32, which is
// what the text backend defaulted to.
static LLVMTypeRef type_from_key(const char *t) {
    if (!t || !*t) return LLVMVoidTypeInContext(g_ctx);
    if (strcmp(t, "void") == 0) return LLVMVoidTypeInContext(g_ctx);
    if (strcmp(t, "i1") == 0) return LLVMInt1TypeInContext(g_ctx);
    if (strcmp(t, "i8") == 0) return LLVMInt8TypeInContext(g_ctx);
    if (strcmp(t, "i16") == 0) return LLVMInt16TypeInContext(g_ctx);
    if (strcmp(t, "i32") == 0) return LLVMInt32TypeInContext(g_ctx);
    if (strcmp(t, "i64") == 0) return LLVMInt64TypeInContext(g_ctx);
    if (strcmp(t, "double") == 0) return LLVMDoubleTypeInContext(g_ctx);
    if (strcmp(t, "ptr") == 0 || strcmp(t, "ptrptr") == 0)
        return LLVMPointerTypeInContext(g_ctx, 0);
    if (strncmp(t, "struct:", 7) == 0) return named_struct(t + 7);
    if (t[0] == '%') return named_struct(t + 1);
    backend_fail("unknown type key", t);
    return NULL;
}

// --- named struct types -----------------------------------------------------

typedef struct {
    char name[NAME_LEN];
    LLVMTypeRef type;
} StructType;

static StructType g_structs[256];
static int g_struct_count;

static LLVMTypeRef named_struct(const char *name) {
    for (int i = 0; i < g_struct_count; i++) {
        if (strcmp(g_structs[i].name, name) == 0) return g_structs[i].type;
    }
    if (g_struct_count >= 256) backend_fail("too many struct types", name);
    // Created opaque; the body is set by ir_struct_type_end().
    LLVMTypeRef ty = LLVMStructCreateNamed(g_ctx, name);
    strncpy(g_structs[g_struct_count].name, name, NAME_LEN - 1);
    g_structs[g_struct_count].name[NAME_LEN - 1] = '\0';
    g_structs[g_struct_count].type = ty;
    g_struct_count++;
    return ty;
}

static LLVMTypeRef g_struct_fields[64];
static int g_struct_field_count;
static char g_struct_building[NAME_LEN];

void ir_struct_type_begin(const char *name) {
    strncpy(g_struct_building, name, NAME_LEN - 1);
    g_struct_building[NAME_LEN - 1] = '\0';
    g_struct_field_count = 0;
}

void ir_struct_type_field(const char *field_type) {
    if (g_struct_field_count >= 64) backend_fail("too many struct fields", g_struct_building);
    g_struct_fields[g_struct_field_count++] = type_from_key(field_type);
}

void ir_struct_type_end(void) {
    LLVMTypeRef ty = named_struct(g_struct_building);
    LLVMStructSetBody(ty, g_struct_fields, (unsigned)g_struct_field_count, 0);
}

// ============================================================================
// Value resolution
// ============================================================================

static LLVMValueRef lookup_named(NamedValue *table, int count, const char *name,
                                 LLVMTypeRef *out_type) {
    for (int i = 0; i < count; i++) {
        if (strcmp(table[i].name, name) == 0) {
            if (out_type) *out_type = table[i].type;
            return table[i].value;
        }
    }
    return NULL;
}

static LLVMValueRef const_from_text(const char *s, LLVMTypeRef ty) {
    if (!ty) backend_fail("constant with no type", s);
    if (ty == LLVMDoubleTypeInContext(g_ctx)) return LLVMConstReal(ty, atof(s));
    if (ty == LLVMPointerTypeInContext(g_ctx, 0)) {
        if (strcmp(s, "null") == 0 || strcmp(s, "0") == 0) return LLVMConstPointerNull(ty);
        backend_fail("non-null pointer constant", s);
    }
    if (strcmp(s, "true") == 0) return LLVMConstInt(ty, 1, 0);
    if (strcmp(s, "false") == 0) return LLVMConstInt(ty, 0, 0);
    return LLVMConstInt(ty, (unsigned long long)strtoll(s, NULL, 10), 1);
}

// The single place that turns a frontend string into an LLVMValueRef.
static LLVMValueRef resolve_value(const char *s, const char *type_key) {
    if (!s) backend_fail("null value", NULL);

    if (s[0] == '$' && s[1] == '$' && s[2] == 'v') {
        int idx = atoi(s + 3);
        if (idx < 0 || idx >= g_value_count) backend_fail("value handle out of range", s);
        LLVMValueRef v = g_values[idx];
        if (!v) backend_fail("value handle refers to an unset slot", s);
        return v;
    }

    if (s[0] == '%') {
        const char *name = s + 1;
        LLVMValueRef v = lookup_named(g_params, g_param_count, name, NULL);
        if (v) return v;
        v = lookup_named(g_allocas, g_alloca_count, name, NULL);
        if (v) return v;
        backend_fail("unknown local name", s);
    }

    return const_from_text(s, type_from_key(type_key));
}

// ============================================================================
// Module lifecycle
// ============================================================================

static void reset_state(void) {
    g_value_count = 0;
    g_label_count = 0;
    g_alloca_count = 0;
    g_param_count = 0;
    g_struct_count = 0;
    g_call_depth = 0;
    g_has_returned = 0;
    g_function = NULL;
    g_pending_param_count = 0;
}

void ir_reset(void) {
    if (g_module) {
        LLVMDisposeModule(g_module);
        g_module = NULL;
    }
    reset_state();
}

// Refuses to run against an LLVM whose major version is not the pinned one.
//
// Checked here rather than only at build time because the dangerous mismatch is
// between the headers this was compiled against and the LLVM-C library actually
// loaded: that links cleanly and then misbehaves in ways that look like compiler
// bugs. On Windows in particular, any LLVM-C.dll earlier on PATH wins.
static void check_llvm_version(void) {
    unsigned major = 0, minor = 0, patch = 0;
    LLVMGetVersion(&major, &minor, &patch);
    if ((int)major != PRISMIO_LLVM_EXPECTED_MAJOR) {
        fprintf(stderr,
                "error: this Prismio was built for LLVM %d, but LLVM %u.%u.%u is loaded.\n"
                "  The LLVM C API is only stable within a major version.\n"
                "  Run: python tools/setup_llvm.py\n",
                PRISMIO_LLVM_EXPECTED_MAJOR, major, minor, patch);
        exit(1);
    }
}

static void ensure_context(void) {
    if (g_initialized) return;
    check_llvm_version();
    g_ctx = LLVMContextCreate();
    g_builder = LLVMCreateBuilderInContext(g_ctx);
    g_alloca_builder = LLVMCreateBuilderInContext(g_ctx);
    g_initialized = 1;
}

void ir_module_start(const char *module_name) {
    ensure_context();
    reset_state();
    g_module = LLVMModuleCreateWithNameInContext(module_name, g_ctx);
    LLVMSetSourceFileName(g_module, "prismio_generated", strlen("prismio_generated"));
#ifdef _WIN32
    // Pinned only on Windows, where msvc and mingw are a real fork and msvc is
    // the configuration that is actually verified. Elsewhere LLVM's own host
    // triple is a better answer than a guess. Matches the text backend.
    LLVMSetTarget(g_module, "x86_64-pc-windows-msvc");
#endif
}

void ir_module_start_wasm(const char *module_name) {
    ensure_context();
    reset_state();
    g_module = LLVMModuleCreateWithNameInContext(module_name, g_ctx);
    LLVMSetSourceFileName(g_module, "prismio_generated", strlen("prismio_generated"));
    LLVMSetTarget(g_module, "wasm32-unknown-unknown");
    LLVMSetDataLayout(g_module, "e-m:e-p:32:32-i64:64-n32:64-S128");
}

void ir_module_end(void) { /* nothing to flush -- the module is already built */ }

// ============================================================================
// Functions
// ============================================================================

static int g_pending_param_noalias[MAX_PENDING_PARAMS];

void ir_function_begin(const char *name, const char *ret_type) {
    strncpy(g_pending_fn_name, name, NAME_LEN - 1);
    g_pending_fn_name[NAME_LEN - 1] = '\0';
    g_pending_ret = type_from_key(ret_type);
    g_pending_param_count = 0;
    memset(g_pending_param_noalias, 0, sizeof(g_pending_param_noalias));
    g_declaring = 0;
}

void ir_declare_function_begin(const char *name, const char *ret_type) {
    ir_function_begin(name, ret_type);
    g_declaring = 1;
}

void ir_function_param(const char *param_type, const char *param_name) {
    if (g_pending_param_count >= MAX_PENDING_PARAMS)
        backend_fail("too many parameters", g_pending_fn_name);
    g_pending_params[g_pending_param_count] = type_from_key(param_type);
    strncpy(g_pending_param_names[g_pending_param_count], param_name ? param_name : "",
            NAME_LEN - 1);
    g_pending_param_names[g_pending_param_count][NAME_LEN - 1] = '\0';
    g_pending_param_count++;
}

void ir_declare_function_param(const char *param_type) {
    ir_function_param(param_type, "");
}

// SPEC 5.1's `unique`, which already means "exactly one reference exists, and it
// owns". `noalias` is that fact spelled for LLVM, so this is a lowering of an
// existing annotation rather than a new one -- SPEC 11 item 7's four stay four.
//
// It is an axiom, not a proof: the solver takes A = Unique as given and the
// affine discipline discharges the local half, but nothing checks that a caller
// passes distinct pointers. semaCheckUniqueArgs rejects the reachable half of
// that -- the same name given to two `unique` parameters of one call.
void ir_function_param_unique(const char *param_type, const char *param_name) {
    int i = g_pending_param_count;
    ir_function_param(param_type, param_name);
    if (i < MAX_PENDING_PARAMS) g_pending_param_noalias[i] = 1;
}

static void apply_param_attrs(LLVMValueRef fn) {
    unsigned kind = LLVMGetEnumAttributeKindForName("noalias", 7);
    if (!kind) return;
    for (int i = 0; i < g_pending_param_count; i++) {
        if (!g_pending_param_noalias[i]) continue;
        LLVMAddAttributeAtIndex(fn, (unsigned)(i + 1),
                                LLVMCreateEnumAttribute(g_ctx, kind, 0));
    }
}

static LLVMValueRef materialize_function(void) {
    LLVMTypeRef fnty = LLVMFunctionType(g_pending_ret, g_pending_params,
                                        (unsigned)g_pending_param_count, 0);
    LLVMValueRef existing = LLVMGetNamedFunction(g_module, g_pending_fn_name);
    if (existing) return existing; // a forward `declare` already created it
    return LLVMAddFunction(g_module, g_pending_fn_name, fnty);
}

void ir_declare_function_end(void) { materialize_function(); }

void ir_function_body_start(void) {
    g_function = materialize_function();
    apply_param_attrs(g_function);
    g_alloca_count = 0;
    g_param_count = 0;
    g_has_returned = 0;

    g_entry_block = LLVMAppendBasicBlockInContext(g_ctx, g_function, "entry");
    LLVMPositionBuilderAtEnd(g_builder, g_entry_block);

    for (int i = 0; i < g_pending_param_count; i++) {
        if (!g_pending_param_names[i][0]) continue;
        strncpy(g_params[g_param_count].name, g_pending_param_names[i], NAME_LEN - 1);
        g_params[g_param_count].name[NAME_LEN - 1] = '\0';
        g_params[g_param_count].value = LLVMGetParam(g_function, (unsigned)i);
        g_params[g_param_count].type = g_pending_params[i];
        g_param_count++;
    }
}

void ir_function_end(void) {
    // A function whose last block has no terminator is invalid. The frontend is
    // responsible for the return, but guard anyway so the verifier reports
    // something more useful than a malformed block.
    LLVMBasicBlockRef bb = LLVMGetInsertBlock(g_builder);
    if (bb && !LLVMGetBasicBlockTerminator(bb)) LLVMBuildUnreachable(g_builder);
    g_function = NULL;
}

// ============================================================================
// Basic blocks
// ============================================================================

int ir_get_label(void) {
    if (g_label_count >= MAX_LABELS) backend_fail("too many labels", NULL);
    g_blocks[g_label_count] = NULL;
    return g_label_count++;
}

static LLVMBasicBlockRef block_for(int id) {
    if (id < 0 || id >= g_label_count) backend_fail("label out of range", NULL);
    if (!g_blocks[id]) {
        char name[32];
        snprintf(name, sizeof(name), "label_%d", id);
        g_blocks[id] = LLVMAppendBasicBlockInContext(g_ctx, g_function, name);
    }
    return g_blocks[id];
}

// True when the block being written already ends in a terminator, meaning any
// further instruction would be unreachable. The text backend happily wrote past
// this point and produced invalid IR; here the write is dropped instead, so a
// stray statement after `return` cannot corrupt the module.
static int block_done(void) {
    LLVMBasicBlockRef bb = LLVMGetInsertBlock(g_builder);
    return !bb || LLVMGetBasicBlockTerminator(bb) != NULL;
}

void ir_label_numbered(int id) { LLVMPositionBuilderAtEnd(g_builder, block_for(id)); }

void ir_label(const char *name) { (void)name; /* numbered labels only */ }

void ir_br_numbered(int target) {
    if (block_done()) return;
    LLVMBuildBr(g_builder, block_for(target));
}

void ir_cond_br_numbered(const char *cond, int t, int f) {
    if (block_done()) return;
    LLVMBuildCondBr(g_builder, resolve_value(cond, "i1"), block_for(t), block_for(f));
}

void ir_br(const char *label) { (void)label; backend_fail("named branches are not supported", label); }
void ir_cond_br(const char *c, const char *t, const char *f) {
    (void)c; (void)t; (void)f;
    backend_fail("named branches are not supported", NULL);
}

void ir_ret(const char *type, const char *value) {
    if (block_done()) return;
    LLVMBuildRet(g_builder, resolve_value(value, type));
}

void ir_ret_void(void) {
    if (block_done()) return;
    LLVMBuildRetVoid(g_builder);
}

// ============================================================================
// Memory
// ============================================================================

int ir_alloca(const char *type, const char *name) {
    for (int i = 0; i < g_alloca_count; i++) {
        if (strcmp(g_allocas[i].name, name) == 0) return -1; // already allocated
    }
    if (g_alloca_count >= MAX_NAMED) backend_fail("too many locals", name);

    LLVMTypeRef ty = type_from_key(type);

    // Always emitted in the entry block, wherever codegen currently is. The
    // frontend now creates each local at its declaration, which for a `let`
    // inside a loop body would otherwise allocate again on every iteration.
    // Inserted before the entry block's terminator once it has one, so the
    // alloca cannot end up after a branch.
    LLVMValueRef entry_term = LLVMGetBasicBlockTerminator(g_entry_block);
    if (entry_term) {
        LLVMPositionBuilderBefore(g_alloca_builder, entry_term);
    } else {
        LLVMPositionBuilderAtEnd(g_alloca_builder, g_entry_block);
    }
    LLVMValueRef slot = LLVMBuildAlloca(g_alloca_builder, ty, name);

    strncpy(g_allocas[g_alloca_count].name, name, NAME_LEN - 1);
    g_allocas[g_alloca_count].name[NAME_LEN - 1] = '\0';
    g_allocas[g_alloca_count].value = slot;
    g_allocas[g_alloca_count].type = ty;
    g_alloca_count++;
    return intern_value(slot);
}

int ir_load(const char *type, const char *ptr_name) {
    LLVMTypeRef ty = NULL;
    LLVMValueRef ptr = lookup_named(g_allocas, g_alloca_count, ptr_name, &ty);
    if (!ptr) {
        ptr = lookup_named(g_params, g_param_count, ptr_name, &ty);
    }
    if (!ptr) backend_fail("load from unknown local", ptr_name);
    return intern_value(LLVMBuildLoad2(g_builder, type_from_key(type), ptr, ""));
}

void ir_store(const char *type, const char *value, const char *ptr_name) {
    LLVMValueRef ptr = lookup_named(g_allocas, g_alloca_count, ptr_name, NULL);
    if (!ptr) ptr = lookup_named(g_params, g_param_count, ptr_name, NULL);
    if (!ptr) backend_fail("store to unknown local", ptr_name);
    if (block_done()) return;
    LLVMBuildStore(g_builder, resolve_value(value, type), ptr);
}

// Load/store through a pointer *value* rather than a named local. Struct fields
// and array elements are addresses produced by a GEP, so they have no name to
// look up -- the text backend reached them by emitting `store ... ptr %tN`
// directly, which is one of the things ir_append was being used for.
int ir_load_ptr(const char *type, const char *ptr_value) {
    return intern_value(
        LLVMBuildLoad2(g_builder, type_from_key(type), resolve_value(ptr_value, "ptr"), ""));
}

void ir_store_ptr(const char *type, const char *value, const char *ptr_value) {
    if (block_done()) return;
    LLVMBuildStore(g_builder, resolve_value(value, type), resolve_value(ptr_value, "ptr"));
}

// An inline struct field is storage, not a slot holding an address, so writing
// one copies bytes. The counterpart of ir_store_ptr for a field whose registered
// type is `struct:T` rather than `ptr`.
//
// The alignment is read back from the module's data layout rather than assumed,
// because it is the number LLVM placed the field at -- see the note on
// LLVMBuildMemCpy in prismio_llvm.h for the case that makes 8 wrong.
void ir_copy_struct(const char *struct_name, const char *dest, const char *src) {
    if (block_done()) return;
    LLVMTypeRef sty = named_struct(struct_name);
    unsigned align = LLVMABIAlignmentOfType(LLVMGetModuleDataLayout(g_module), sty);
    LLVMBuildMemCpy(g_builder,
                    resolve_value(dest, "ptr"), align,
                    resolve_value(src, "ptr"), align,
                    LLVMSizeOf(sty));
}

static LLVMValueRef global_named(const char *name, LLVMTypeRef ty) {
    LLVMValueRef g = LLVMGetNamedGlobal(g_module, name);
    if (!g) {
        g = LLVMAddGlobal(g_module, ty, name);
        LLVMSetInitializer(g, LLVMConstNull(ty));
    }
    return g;
}

int ir_load_global(const char *type, const char *name) {
    LLVMTypeRef ty = type_from_key(type);
    return intern_value(LLVMBuildLoad2(g_builder, ty, global_named(name, ty), ""));
}

void ir_store_global(const char *type, const char *value, const char *name) {
    if (block_done()) return;
    LLVMTypeRef ty = type_from_key(type);
    LLVMBuildStore(g_builder, resolve_value(value, type), global_named(name, ty));
}

// ============================================================================
// Object allocation -- the memory-model seam
// ============================================================================

// Allocates one object of a struct type through the configured allocator.
// Replaces the hand-written getelementptr-null / ptrtoint / call malloc text
// the frontend used to emit, and is the single place a different memory model
// needs to change.
// AIF T0: the value does not outlive the activation record that creates it, so
// it needs a stack slot and no allocation call at all (SPEC 3, T0 row).
//
// Hoisted to the entry block, like every other alloca here, because a literal
// inside a loop would otherwise allocate a fresh slot per iteration and grow the
// frame without bound. That means **one slot per site, reused by every
// iteration** -- which is only correct because T0 requires the value's escape to
// bottom at its own defining scope, i.e. nothing from one iteration is still
// reachable in the next. The escape module has to be right about that; when it
// was not, this was a miscompile rather than a slowdown (see aif_var_scope in
// aif_support.c).
//
// Unnamed and never deduplicated, unlike ir_alloca: two struct literals of the
// same type in one function are two values and need two slots.
int ir_alloc_stack(const char *struct_name) {
    LLVMTypeRef sty = named_struct(struct_name);

    LLVMValueRef entry_term = LLVMGetBasicBlockTerminator(g_entry_block);
    if (entry_term) {
        LLVMPositionBuilderBefore(g_alloca_builder, entry_term);
    } else {
        LLVMPositionBuilderAtEnd(g_alloca_builder, g_entry_block);
    }

    return intern_value(LLVMBuildAlloca(g_alloca_builder, sty, ""));
}

int ir_alloc_object(const char *struct_name) {
    LLVMTypeRef sty = named_struct(struct_name);
    LLVMTypeRef size_ty = type_from_key(g_ptr_int);
    LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);

    // LLVMSizeOf yields an i64; narrow it when the target's size argument is
    // smaller, so the call matches the allocator's declared signature.
    LLVMValueRef size = LLVMSizeOf(sty);
    if (size_ty != LLVMInt64TypeInContext(g_ctx)) {
        size = LLVMBuildTrunc(g_builder, size, size_ty, "");
    }

    LLVMTypeRef alloc_ty = LLVMFunctionType(ptr, &size_ty, 1, 0);
    LLVMValueRef alloc_fn = LLVMGetNamedFunction(g_module, g_alloc_fn);
    if (!alloc_fn) alloc_fn = LLVMAddFunction(g_module, g_alloc_fn, alloc_ty);

    LLVMValueRef args[1] = {size};
    return intern_value(LLVMBuildCall2(g_builder, alloc_ty, alloc_fn, args, 1, ""));
}

// The third hook COMPILER-AUDIT 3 asked for. It expected `fn(arena, size) -> ptr`
// with the handle threaded from the enclosing region; the arena is dynamically
// scoped instead (see runtime/lang_runtime.c), so the signature stays
// `fn(size) -> ptr` and no frontend plumbing is needed to reach it.
//
// Unlike ir_alloc_object this does not read g_alloc_fn: a region allocation is a
// different obligation, not a different allocator, and routing it through the
// name swap would mean a verify build tried to account for memory the arena
// releases in bulk.
int ir_alloc_region(const char *struct_name) {
    LLVMTypeRef sty = named_struct(struct_name);
    LLVMTypeRef size_ty = type_from_key(g_ptr_int);
    LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);

    LLVMValueRef size = LLVMSizeOf(sty);
    if (size_ty != LLVMInt64TypeInContext(g_ctx)) {
        size = LLVMBuildTrunc(g_builder, size, size_ty, "");
    }

    LLVMTypeRef alloc_ty = LLVMFunctionType(ptr, &size_ty, 1, 0);
    LLVMValueRef alloc_fn = LLVMGetNamedFunction(g_module, "arena_alloc");
    if (!alloc_fn) alloc_fn = LLVMAddFunction(g_module, "arena_alloc", alloc_ty);

    LLVMValueRef args[1] = {size};
    return intern_value(LLVMBuildCall2(g_builder, alloc_ty, alloc_fn, args, 1, ""));
}

// AIF Level 5, and the fourth hook. COMPILER-AUDIT 3 rated T3 only "partly"
// expressible through the seam because a count word changes struct layout, which
// named_struct and every ir_struct_field_ptr index would have to account for. A
// *prefix* header avoids that entirely -- the count sits in front of the pointer,
// the LLVM struct type is untouched, and what is left really is just a name.
//
// Like ir_alloc_region, this does not read g_alloc_fn. rc_alloc reaches the verify
// shim through the runtime's own rt_base_alloc, so both ends of the pairing swap
// together when the runtime is compiled -- the same arrangement Level 4 needed for
// strings, and for the same reason.
int ir_alloc_rc(const char *struct_name) {
    LLVMTypeRef sty = named_struct(struct_name);
    LLVMTypeRef size_ty = type_from_key(g_ptr_int);
    LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);

    LLVMValueRef size = LLVMSizeOf(sty);
    if (size_ty != LLVMInt64TypeInContext(g_ctx)) {
        size = LLVMBuildTrunc(g_builder, size, size_ty, "");
    }

    LLVMTypeRef alloc_ty = LLVMFunctionType(ptr, &size_ty, 1, 0);
    LLVMValueRef alloc_fn = LLVMGetNamedFunction(g_module, "rc_alloc");
    if (!alloc_fn) alloc_fn = LLVMAddFunction(g_module, "rc_alloc", alloc_ty);

    LLVMValueRef args[1] = {size};
    return intern_value(LLVMBuildCall2(g_builder, alloc_ty, alloc_fn, args, 1, ""));
}

// Region entry and exit. Emitted at every exit from the block, like the drops --
// a `return` out of a region that did not pop would leave the arena live for the
// rest of the program.
static void ir_arena_call(const char *name) {
    if (block_done()) return;
    LLVMTypeRef voidty = LLVMVoidTypeInContext(g_ctx);
    LLVMTypeRef fn_ty = LLVMFunctionType(voidty, NULL, 0, 0);
    LLVMValueRef fn = LLVMGetNamedFunction(g_module, name);
    if (!fn) fn = LLVMAddFunction(g_module, name, fn_ty);
    LLVMBuildCall2(g_builder, fn_ty, fn, NULL, 0, "");
}

void ir_region_begin(void) { ir_arena_call("arena_push"); }
void ir_region_end(void)   { ir_arena_call("arena_pop"); }

// AIF Level 4. A string or a list is allocated inside the runtime, not through
// ir_alloc_region, so the site cannot pick the arena for itself. Bracketing the
// producing call says "the allocation this one makes belongs to the region", and
// the runtime bumps rather than calling malloc. Emitted around the call only;
// the arguments are already evaluated by then.
void ir_arena_hint_begin(void) { ir_arena_call("rt_arena_hint_push"); }
void ir_arena_hint_end(void)   { ir_arena_call("rt_arena_hint_pop"); }

static void ir_release_call(const char *value, const char *fn_name) {
    if (block_done()) return;
    LLVMTypeRef voidty = LLVMVoidTypeInContext(g_ctx);
    LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);

    LLVMTypeRef free_ty = LLVMFunctionType(voidty, &ptr, 1, 0);
    LLVMValueRef free_fn = LLVMGetNamedFunction(g_module, fn_name);
    if (!free_fn) free_fn = LLVMAddFunction(g_module, fn_name, free_ty);

    LLVMValueRef args[1] = {resolve_value(value, "ptr")};
    LLVMBuildCall2(g_builder, free_ty, free_fn, args, 1, "");
}

void ir_free_object(const char *value) { ir_release_call(value, g_free_fn); }

// AIF Level 4. A list is a handle plus an element block, so the one-pointer
// deallocator the seam names cannot reclaim it. `list_release` is the runtime's
// own -- it frees both through the same allocator the list came from, which is
// what keeps a verify build's accounting balanced.
void ir_free_list(const char *value) { ir_release_call(value, "list_release"); }

// Struct-field ownership. A struct that owns its fields is reclaimed by a
// function generated for its type, so the callee is named by the caller rather
// than fixed. It is still behind the seam: what that generated function frees,
// it frees through ir_free_object and its siblings.
void ir_free_typed(const char *value, const char *fn_name) { ir_release_call(value, fn_name); }

// AIF Level 5. The decrement half, for a counted value held in a struct field.
void ir_free_rc(const char *value) { ir_release_call(value, "rc_release"); }

// AIF T4b. The fifth allocator hook, and a `fn(size) -> ptr` like the other
// four: the colour and the per-type descriptor go in front of the pointer, so
// the LLVM struct type is untouched and cyc_set_type fills them in afterwards --
// the same shape as list_set_elem_owner, and for the same reason.
int ir_alloc_cycle(const char *struct_name) {
    LLVMTypeRef sty = named_struct(struct_name);
    LLVMTypeRef size_ty = type_from_key(g_ptr_int);
    LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);

    LLVMValueRef size = LLVMSizeOf(sty);
    if (size_ty != LLVMInt64TypeInContext(g_ctx)) {
        size = LLVMBuildTrunc(g_builder, size, size_ty, "");
    }

    LLVMTypeRef alloc_ty = LLVMFunctionType(ptr, &size_ty, 1, 0);
    LLVMValueRef alloc_fn = LLVMGetNamedFunction(g_module, "cyc_alloc");
    if (!alloc_fn) alloc_fn = LLVMAddFunction(g_module, "cyc_alloc", alloc_ty);

    LLVMValueRef args[1] = {size};
    return intern_value(LLVMBuildCall2(g_builder, alloc_ty, alloc_fn, args, 1, ""));
}

// An indirect call to a `fn(ptr) -> void` through a function pointer.
//
// The collector's visitor is a value rather than a name: the children function
// is generated per type, and the visitor differs per traversal phase, so the
// callee cannot be baked into the call.
void ir_call_indirect_ptr(const char *fn_value, const char *arg) {
    if (block_done()) return;
    LLVMTypeRef voidty = LLVMVoidTypeInContext(g_ctx);
    LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);
    LLVMTypeRef fn_ty = LLVMFunctionType(voidty, &ptr, 1, 0);
    LLVMValueRef args[1] = {resolve_value(arg, "ptr")};
    LLVMBuildCall2(g_builder, fn_ty, resolve_value(fn_value, "ptr"), args, 1, "");
}

// The address of a named function, as a value.
//
// Needed because a container of structs-with-owned-fields cannot be told its
// disposition with an int: the release differs per element *type*, and the
// runtime has no way to name a type. So it is told the function instead, which
// is the same "the container is told, it cannot ask" rule the int modes follow.
int ir_func_addr(const char *name) {
    LLVMValueRef fn = LLVMGetNamedFunction(g_module, name);
    if (!fn) backend_fail("address of unknown function", name);
    return intern_value(fn);
}

// Field address within a struct object. Replaces emitted getelementptr text.
int ir_struct_field_ptr(const char *struct_name, const char *object, int field_index) {
    LLVMTypeRef sty = named_struct(struct_name);
    LLVMValueRef obj = resolve_value(object, "ptr");
    if (field_index < 0) backend_fail("negative struct field index", struct_name);
    return intern_value(
        LLVMBuildStructGEP2(g_builder, sty, obj, (unsigned)field_index, ""));
}

// Address of element `index` in a flat array of `elem_type`.
int ir_elem_ptr(const char *elem_type, const char *base, const char *index) {
    LLVMTypeRef ety = type_from_key(elem_type);
    LLVMValueRef idx[1] = {resolve_value(index, "i32")};
    return intern_value(
        LLVMBuildInBoundsGEP2(g_builder, ety, resolve_value(base, "ptr"), idx, 1, ""));
}

// Stack array of `count` elements, yielding a pointer to the first element.
int ir_array_alloca(const char *elem_type, int count) {
    LLVMTypeRef ety = type_from_key(elem_type);
    LLVMTypeRef arr = LLVMArrayType2(ety, (uint64_t)count);
    LLVMValueRef slot = LLVMBuildAlloca(g_builder, arr, "");
    LLVMTypeRef i32 = LLVMInt32TypeInContext(g_ctx);
    LLVMValueRef idx[2] = {LLVMConstInt(i32, 0, 0), LLVMConstInt(i32, 0, 0)};
    return intern_value(LLVMBuildInBoundsGEP2(g_builder, arr, slot, idx, 2, ""));
}

// ============================================================================
// Arithmetic, comparison, conversion
// ============================================================================

#define BINOP(fn_name, builder_call)                                                   \
    int fn_name(const char *type, const char *lhs, const char *rhs) {                  \
        LLVMValueRef l = resolve_value(lhs, type);                                     \
        LLVMValueRef r = resolve_value(rhs, type);                                     \
        return intern_value(builder_call(g_builder, l, r, ""));                        \
    }

BINOP(ir_add, LLVMBuildAdd)
BINOP(ir_sub, LLVMBuildSub)
BINOP(ir_mul, LLVMBuildMul)
BINOP(ir_sdiv, LLVMBuildSDiv)
BINOP(ir_udiv, LLVMBuildUDiv)
BINOP(ir_srem, LLVMBuildSRem)
BINOP(ir_urem, LLVMBuildURem)
BINOP(ir_fadd, LLVMBuildFAdd)
BINOP(ir_fsub, LLVMBuildFSub)
BINOP(ir_fmul, LLVMBuildFMul)
BINOP(ir_fdiv, LLVMBuildFDiv)
BINOP(ir_and, LLVMBuildAnd)
BINOP(ir_or, LLVMBuildOr)
BINOP(ir_xor, LLVMBuildXor)
BINOP(ir_shl, LLVMBuildShl)
BINOP(ir_lshr, LLVMBuildLShr)
BINOP(ir_ashr, LLVMBuildAShr)

int ir_neg(const char *type, const char *value) {
    return intern_value(LLVMBuildNeg(g_builder, resolve_value(value, type), ""));
}

int ir_fneg(const char *type, const char *value) {
    return intern_value(LLVMBuildFNeg(g_builder, resolve_value(value, type), ""));
}

int ir_not(const char *type, const char *value) {
    return intern_value(LLVMBuildNot(g_builder, resolve_value(value, type), ""));
}

#define ICMP(fn_name, pred)                                                            \
    int fn_name(const char *type, const char *lhs, const char *rhs) {                  \
        LLVMValueRef l = resolve_value(lhs, type);                                     \
        LLVMValueRef r = resolve_value(rhs, type);                                     \
        return intern_value(LLVMBuildICmp(g_builder, pred, l, r, ""));                 \
    }

ICMP(ir_icmp_eq, LLVMIntEQ)
ICMP(ir_icmp_ne, LLVMIntNE)
ICMP(ir_icmp_slt, LLVMIntSLT)
ICMP(ir_icmp_sle, LLVMIntSLE)
ICMP(ir_icmp_sgt, LLVMIntSGT)
ICMP(ir_icmp_sge, LLVMIntSGE)
ICMP(ir_icmp_ult, LLVMIntULT)
ICMP(ir_icmp_ule, LLVMIntULE)
ICMP(ir_icmp_ugt, LLVMIntUGT)
ICMP(ir_icmp_uge, LLVMIntUGE)

#define FCMP(fn_name, pred)                                                            \
    int fn_name(const char *type, const char *lhs, const char *rhs) {                  \
        LLVMValueRef l = resolve_value(lhs, type);                                     \
        LLVMValueRef r = resolve_value(rhs, type);                                     \
        return intern_value(LLVMBuildFCmp(g_builder, pred, l, r, ""));                 \
    }

FCMP(ir_fcmp_oeq, LLVMRealOEQ)
FCMP(ir_fcmp_one, LLVMRealONE)
FCMP(ir_fcmp_olt, LLVMRealOLT)
FCMP(ir_fcmp_ole, LLVMRealOLE)
FCMP(ir_fcmp_ogt, LLVMRealOGT)
FCMP(ir_fcmp_oge, LLVMRealOGE)

int ir_zext(const char *from_type, const char *value, const char *to_type) {
    return intern_value(LLVMBuildZExt(g_builder, resolve_value(value, from_type),
                                      type_from_key(to_type), ""));
}

int ir_sext(const char *from_type, const char *value, const char *to_type) {
    return intern_value(LLVMBuildSExt(g_builder, resolve_value(value, from_type),
                                      type_from_key(to_type), ""));
}

int ir_trunc(const char *from_type, const char *value, const char *to_type) {
    return intern_value(LLVMBuildTrunc(g_builder, resolve_value(value, from_type),
                                       type_from_key(to_type), ""));
}

// REQUIREMENTS 20. A `List<T>` stores pointer-sized slots, so a scalar element
// rides in one rather than being boxed. Boxing would cost an allocation per
// element *and* give the container something to own, which is the opposite of
// what a scalar element is: nothing allocates, so there is no site and nothing
// to release.
int ir_int_to_ptr(const char *from_type, const char *value) {
    LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);
    return intern_value(LLVMBuildIntToPtr(g_builder, resolve_value(value, from_type),
                                          ptr, ""));
}

int ir_ptr_to_int(const char *value, const char *to_type) {
    return intern_value(LLVMBuildPtrToInt(g_builder, resolve_value(value, "ptr"),
                                          type_from_key(to_type), ""));
}

// The float half of the same round trip: a double is 64 bits of payload, not a
// number to convert, so this reinterprets rather than rounding.
int ir_bitcast(const char *from_type, const char *value, const char *to_type) {
    return intern_value(LLVMBuildBitCast(g_builder, resolve_value(value, from_type),
                                         type_from_key(to_type), ""));
}

// Integer <-> floating point. Needed by `as`; the signed and unsigned forms are
// distinct instructions, so the frontend picks based on the source/target type.
int ir_sitofp(const char *from_type, const char *value, const char *to_type) {
    return intern_value(LLVMBuildSIToFP(g_builder, resolve_value(value, from_type),
                                        type_from_key(to_type), ""));
}

int ir_uitofp(const char *from_type, const char *value, const char *to_type) {
    return intern_value(LLVMBuildUIToFP(g_builder, resolve_value(value, from_type),
                                        type_from_key(to_type), ""));
}

int ir_fptosi(const char *from_type, const char *value, const char *to_type) {
    return intern_value(LLVMBuildFPToSI(g_builder, resolve_value(value, from_type),
                                        type_from_key(to_type), ""));
}

int ir_fptoui(const char *from_type, const char *value, const char *to_type) {
    return intern_value(LLVMBuildFPToUI(g_builder, resolve_value(value, from_type),
                                        type_from_key(to_type), ""));
}

// ============================================================================
// Calls
// ============================================================================

void ir_call_begin(void) {
    if (g_call_depth >= MAX_CALL_DEPTH) backend_fail("call nesting too deep", NULL);
    g_calls[g_call_depth].count = 0;
    g_call_depth++;
}

void ir_call_arg(const char *arg_type, const char *arg_value) {
    if (g_call_depth <= 0) backend_fail("call argument outside a call", arg_value);
    CallFrame *f = &g_calls[g_call_depth - 1];
    if (f->count >= MAX_CALL_ARGS) backend_fail("too many call arguments", NULL);
    f->args[f->count++] = resolve_value(arg_value, arg_type);
}

int ir_call_end(const char *ret_type, const char *func_name) {
    if (g_call_depth <= 0) backend_fail("call end without begin", func_name);
    CallFrame *f = &g_calls[--g_call_depth];

    int is_void = (!ret_type || !*ret_type || strcmp(ret_type, "void") == 0);

    LLVMValueRef fn = LLVMGetNamedFunction(g_module, func_name);
    if (!fn) {
        // Forward reference. Functions are emitted in a second pass, so a call
        // can precede its definition, and generate_module deliberately skips
        // the `declare` for any function the module also defines -- that is the
        // forward-declaration idiom the compiler's own sources rely on
        // (parser.psm, sema.psm and ir.psm all `extern fn` something they then
        // define). The text backend never noticed because it wrote the call as
        // text and left resolution to the assembler.
        //
        // Synthesise the declaration from the call site. The frontend has
        // already type-checked the call, so the argument types are the
        // definition's parameter types, and materialize_function() reuses this
        // same LLVMValueRef when the definition is finally built.
        LLVMTypeRef param_types[MAX_CALL_ARGS];
        for (int i = 0; i < f->count; i++) param_types[i] = LLVMTypeOf(f->args[i]);
        LLVMTypeRef rty = is_void ? LLVMVoidTypeInContext(g_ctx) : type_from_key(ret_type);
        LLVMTypeRef synth = LLVMFunctionType(rty, param_types, (unsigned)f->count, 0);
        fn = LLVMAddFunction(g_module, func_name, synth);
    }

    LLVMTypeRef fnty = LLVMGlobalGetValueType(fn);
    LLVMValueRef call = LLVMBuildCall2(g_builder, fnty, fn, f->args, (unsigned)f->count, "");

    return is_void ? -1 : intern_value(call);
}

// ============================================================================
// Globals and string constants
// ============================================================================

void ir_global_var(const char *name, const char *type, const char *init_value,
                   int is_const) {
    LLVMTypeRef ty = type_from_key(type);
    LLVMValueRef g = LLVMGetNamedGlobal(g_module, name);
    if (!g) g = LLVMAddGlobal(g_module, ty, name);

    // An initializer naming another global (a string constant) arrives as "@name".
    if (init_value && init_value[0] == '@') {
        LLVMValueRef target = LLVMGetNamedGlobal(g_module, init_value + 1);
        if (!target) backend_fail("global initializer names an unknown global", init_value);
        LLVMSetInitializer(g, target);
    } else if (init_value && *init_value) {
        LLVMSetInitializer(g, const_from_text(init_value, ty));
    } else {
        LLVMSetInitializer(g, LLVMConstNull(ty));
    }
    if (is_const) LLVMSetGlobalConstant(g, 1);
}

void ir_global_string(const char *name, const char *content) {
    unsigned len = (unsigned)strlen(content);
    LLVMValueRef str = LLVMConstStringInContext(g_ctx, content, len, 0); // NUL-terminated
    LLVMTypeRef arr = LLVMArrayType2(LLVMInt8TypeInContext(g_ctx), (uint64_t)len + 1);
    LLVMValueRef g = LLVMAddGlobal(g_module, arr, name);
    LLVMSetInitializer(g, str);
    LLVMSetLinkage(g, LLVMPrivateLinkage);
    LLVMSetGlobalConstant(g, 1);
    LLVMSetUnnamedAddr(g, 1);
}

// LAYOUT 2. A constant C string created on demand, for the type and field names
// the profile instrumentation passes to rt_profile_field.
//
// Every other string in a generated module is named by the collect_strings
// pre-pass, which walks the AST and gives each *source* literal a global. These
// strings are not in the source -- they are the names of the things being
// measured -- so there is nothing for that pre-pass to find, and adding a second
// pre-pass for them would mean two walks that have to agree on a name.
//
// Interned by content, so a type touched at four hundred sites has one global.
// The name is derived from the content rather than from a counter for the reason
// every other generated name here is: a counter makes the IR depend on emission
// order, and two builds of one program have to produce byte-identical output.
int ir_const_cstring(const char *text) {
    // FNV-1a of the content. A collision would alias two distinct names onto one
    // global and mislabel a counter, so the name carries the length as well --
    // two strings colliding in both are not something this compiler will meet.
    unsigned h = 2166136261u;
    for (const char *p = text; *p; p++) { h ^= (unsigned char)*p; h *= 16777619u; }

    char name[64];
    snprintf(name, sizeof(name), ".aifprof.%08x.%u", h, (unsigned)strlen(text));

    LLVMValueRef g = LLVMGetNamedGlobal(g_module, name);
    if (!g) {
        ir_global_string(name, text);
        g = LLVMGetNamedGlobal(g_module, name);
        if (!g) backend_fail("could not create profile string", text);
    }
    return intern_value(g);
}

// Pointer to the first byte of a previously created string global.
int ir_string_ptr(const char *global_name) {
    LLVMValueRef g = LLVMGetNamedGlobal(g_module, global_name);
    if (!g) backend_fail("unknown string global", global_name);
    // With opaque pointers the global's address already is the pointer we want.
    return intern_value(g);
}

// Return tracking, the struct/enum/global registries, var types and move/borrow
// state all live in ir_symbols.c -- they are compiler bookkeeping shared by both
// backends, not emission state.

// ============================================================================
// Raw text: deliberately unsupported
// ============================================================================

// The text backend let the frontend splice arbitrary IR text into the output,
// which is how struct literals, GEPs and array indexing were emitted. There is
// no way to honour that here, and quietly ignoring it would produce a module
// missing whole instructions. Fail loudly instead: every remaining caller is a
// site that still needs migrating to a typed builder above.
void ir_append(const char *text) {
    backend_fail("ir_append() has no meaning in the LLVM API backend; "
                 "migrate this call site to a typed builder",
                 text);
}

void ir_append_line(const char *text) { ir_append(text); }

void ir_comment(const char *text) { (void)text; /* comments have no IR representation */ }
void ir_blank_line(void) { /* formatting only */ }

// ============================================================================
// Output
// ============================================================================

// Verifies before writing. This is the check the text backend never had: a
// malformed module is reported here, against the code that built it, instead of
// surfacing later as an llc parse error pointing at generated text.
// -O level, 0 by default -- unoptimized, which is what shipped before this
// existed: no pass pipeline was ever run over the generated module.
static int g_opt_level = 0;

void ir_set_opt_level(int level) {
    if (level < 0) level = 0;
    if (level > 3) level = 3;
    g_opt_level = level;
}

// Runs LLVM's standard pipeline over the module before it is written.
//
// The frontend emits a load/store through a stack slot for every binding, so
// even -O1 (which includes mem2reg/SROA) is a large improvement over the raw
// output. No TargetMachine is passed: these are the target-independent passes,
// and llc still does target-specific work afterwards.
static int run_optimization(void) {
    if (g_opt_level == 0) return 0;

    char pipeline[32];
    snprintf(pipeline, sizeof(pipeline), "default<O%d>", g_opt_level);

    LLVMPassBuilderOptionsRef options = LLVMCreatePassBuilderOptions();
    LLVMErrorRef err = LLVMRunPasses(g_module, pipeline, NULL, options);
    LLVMDisposePassBuilderOptions(options);

    if (err) {
        char *msg = LLVMGetErrorMessage(err);
        fprintf(stderr, "error: optimization pipeline failed: %s\n", msg ? msg : "?");
        return 1;
    }
    return 0;
}

int ir_write_file(const char *filename) {
    char *err = NULL;

    // Verify first: optimizing an already-invalid module produces far worse
    // diagnostics than reporting the original problem.
    if (LLVMVerifyModule(g_module, LLVMReturnStatusAction, &err)) {
        fprintf(stderr, "error: generated module failed verification\n");
        if (err) fprintf(stderr, "%s\n", err);
        if (err) LLVMDisposeMessage(err);
        return 1;
    }
    if (err) { LLVMDisposeMessage(err); err = NULL; }

    if (run_optimization() != 0) return 1;
    if (LLVMVerifyModule(g_module, LLVMReturnStatusAction, &err)) {
        fprintf(stderr, "error: generated module failed verification\n");
        if (err) fprintf(stderr, "%s\n", err);
        if (err) LLVMDisposeMessage(err);
        return 1;
    }
    if (err) LLVMDisposeMessage(err);

    char *werr = NULL;
    if (LLVMPrintModuleToFile(g_module, filename, &werr)) {
        fprintf(stderr, "error: could not write %s: %s\n", filename, werr ? werr : "?");
        if (werr) LLVMDisposeMessage(werr);
        return 1;
    }
    return 0;
}

void ir_print(void) {
    char *s = LLVMPrintModuleToString(g_module);
    if (s) {
        printf("%s", s);
        LLVMDisposeMessage(s);
    }
}
