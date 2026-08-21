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

// The value and block tables are indexed by a counter that runs for the whole
// module, so their old fixed sizes were a ceiling on *program size* rather than
// on anything a single function could do: a 922 KB source stopped with
// `value table exhausted`, which is the first hard limit anyone has hit here.
// They grow now, the way every table in ir_symbols.c does and for the reason
// stated there. These two names are the initial capacity, not a maximum.
#define INITIAL_VALUES 65536
#define INITIAL_LABELS 16384
// Per *function*, unlike the two above -- ir_function_body_start() resets both
// counts -- so this one is a bound on how many locals or parameters one function
// may have, and 4096 of either is not a program anyone is writing.
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

static LLVMValueRef *g_values;
static int g_value_count;
static int g_value_capacity;

// Blocks are reserved before they are created: the frontend asks for a label
// number, branches to it, and only later says "the block starts here". So a slot
// is handed out immediately and the LLVMBasicBlockRef is materialised on first
// use.
static LLVMBasicBlockRef *g_blocks;
static int g_label_count;
static int g_label_capacity;

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

// Pointer-sized integer for the current target, in LLVM spelling. Set once per
// module from the front end's irPtrIntType(); i64 on every target so far.
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

// Doubling, and the allocation is kept across ir_reset() -- a second module in
// one process is bootstrap, and it needs the same room the first one did.
static void grow_table(void **items, int *capacity, int wanted, size_t item_size,
                       int initial, const char *what) {
    if (wanted < *capacity) return;
    int next = *capacity ? *capacity * 2 : initial;
    while (next <= wanted) next *= 2;
    void *grown = realloc(*items, (size_t)next * item_size);
    if (!grown) backend_fail("out of memory growing", what);
    // New slots are zeroed: block_for() reads a slot to decide whether the block
    // has been materialised, and ir_get_label() only clears the one it hands out.
    memset((char *)grown + (size_t)*capacity * item_size, 0,
           (size_t)(next - *capacity) * item_size);
    *items = grown;
    *capacity = next;
}

static int intern_value(LLVMValueRef v) {
    grow_table((void **)&g_values, &g_value_capacity, g_value_count,
               sizeof(LLVMValueRef), INITIAL_VALUES, "the value table");
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

// LAYOUT 6's hot/cold split lives entirely in this table.
//
// `hot_count` is 0 for every type the search left alone, and otherwise the number
// of fields the hot record keeps. The hot record then carries **one extra
// element**, a pointer at index `hot_count`, and `cold` is the separately
// allocated block it points at. That is LAYOUT 5.2.1's *linked* split: one
// pointer still reaches the whole object, which is exactly why this needs no
// handles and why it is emittable today.
//
// Codegen never learns any of it. The frontend emits fields in the order
// `aif_layout_field` hands it -- hot ones first -- and indexes them from 0, so a
// field index below `hot_count` is a GEP into the hot record and one at or above
// it is a load of the link followed by a GEP into `cold`. `ir_struct_field_ptr`
// is the single choke point for field access, which is what keeps the whole
// transform inside this file instead of in a pass over the IR.
typedef struct {
    char name[NAME_LEN];
    LLVMTypeRef type;
    LLVMTypeRef cold;   // NULL unless split
    int hot_count;      // 0 unless split
} StructType;

static StructType g_structs[256];
static int g_struct_count;

static StructType *struct_entry(const char *name) {
    for (int i = 0; i < g_struct_count; i++) {
        if (strcmp(g_structs[i].name, name) == 0) return &g_structs[i];
    }
    if (g_struct_count >= 256) backend_fail("too many struct types", name);
    // Created opaque; the body is set by ir_struct_type_end().
    LLVMTypeRef ty = LLVMStructCreateNamed(g_ctx, name);
    strncpy(g_structs[g_struct_count].name, name, NAME_LEN - 1);
    g_structs[g_struct_count].name[NAME_LEN - 1] = '\0';
    g_structs[g_struct_count].type = ty;
    g_structs[g_struct_count].cold = NULL;
    g_structs[g_struct_count].hot_count = 0;
    return &g_structs[g_struct_count++];
}

static LLVMTypeRef named_struct(const char *name) { return struct_entry(name)->type; }

static LLVMTypeRef g_struct_fields[64];
static int g_struct_field_count;
static char g_struct_building[NAME_LEN];
static int g_struct_split;

void ir_struct_type_begin(const char *name) {
    strncpy(g_struct_building, name, NAME_LEN - 1);
    g_struct_building[NAME_LEN - 1] = '\0';
    g_struct_field_count = 0;
    // Cleared here as well as in ir_struct_type_end, so a type emitted without a
    // split call cannot inherit the previous type's cut.
    g_struct_split = 0;
}

void ir_struct_type_field(const char *field_type) {
    if (g_struct_field_count >= 64) backend_fail("too many struct fields", g_struct_building);
    g_struct_fields[g_struct_field_count++] = type_from_key(field_type);
}

// How many of the fields just declared stay in the hot record. 0, or a count
// covering the whole field list, means no split. Called between the last
// ir_struct_type_field and ir_struct_type_end.
void ir_struct_type_split(int hot_count) { g_struct_split = hot_count; }

void ir_struct_type_end(void) {
    StructType *s = struct_entry(g_struct_building);
    int hc = g_struct_split;
    g_struct_split = 0;

    if (hc <= 0 || hc >= g_struct_field_count) {
        s->hot_count = 0;
        s->cold = NULL;
        LLVMStructSetBody(s->type, g_struct_fields, (unsigned)g_struct_field_count, 0);
        return;
    }

    char cold_name[NAME_LEN];
    snprintf(cold_name, sizeof(cold_name), "%s.cold", g_struct_building);
    LLVMTypeRef cold = LLVMStructCreateNamed(g_ctx, cold_name);
    LLVMStructSetBody(cold, &g_struct_fields[hc], (unsigned)(g_struct_field_count - hc), 0);

    // The link word is **appended, not prepended**, so field 0 of the hot record
    // is still byte 0 of the object. tests/test_41_punned_slot_bytes.psm reads the
    // first byte of the pointed-to struct and this must not move it.
    LLVMTypeRef hot_fields[65];
    for (int i = 0; i < hc; i++) hot_fields[i] = g_struct_fields[i];
    hot_fields[hc] = LLVMPointerTypeInContext(g_ctx, 0);
    LLVMStructSetBody(s->type, hot_fields, (unsigned)(hc + 1), 0);

    s->hot_count = hc;
    s->cold = cold;
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

// Declared here because the debug section is further down the file and this is
// the one place outside it that has to know debug info exists: a DIBuilder holds
// metadata owned by the module it was created from, so it cannot outlive it.
static void debug_dispose(void);
static void debug_clear_location(void);

void ir_reset(void) {
    debug_dispose();
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

// ============================================================================
// Targets
//
// The compiler's whole notion of a target is three facts -- triple, pointer
// width, data layout -- and every one of them is answered by LLVM from the
// triple rather than by a table in this repo. A table would be a second copy of
// something LLVM already owns, and a wrong row here is a *miscompile*: an
// allocation sized for the wrong pointer, or member offsets four bytes out. The
// frontend reads all three back as one record (see src/ir/target.psm); this is
// the only place they are stored, so the two cannot drift.
//
// The host is resolved lazily, on the first question anyone asks, and is marked
// not-explicit: a build that never passed --target must emit exactly the module
// it emitted before targets existed, which means no triple and no layout stamped
// on it. Only an explicitly named target stamps.
//
// Without real headers (see prismio_llvm.h) nothing here can resolve anything.
// The host then falls back to 64-bit with no triple -- which is what the
// frontend hardcoded before this existed, so that path is unchanged -- and an
// explicit --target fails loudly rather than guessing.
// ============================================================================

static char g_target_triple[256];
static char g_target_layout[1024];
static int  g_target_ptr_bits;
static int  g_target_explicit;
static int  g_target_selected;

#ifdef PRISMIO_TARGETS
static void ensure_all_targets(void) {
    static int done = 0;
    if (done) return;
    LLVMInitializeAllTargetInfos();
    LLVMInitializeAllTargets();
    LLVMInitializeAllTargetMCs();
    done = 1;
}
#endif

// triple == NULL or "" selects the host. Returns 0 if LLVM does not recognise
// the triple, in which case nothing is changed and the caller must stop.
int ir_target_select(const char *triple) {
    int want_host = !triple || !*triple;
#ifdef PRISMIO_TARGETS
    ensure_all_targets();

    char *host = want_host ? LLVMGetDefaultTargetTriple() : NULL;
    const char *use = want_host ? host : triple;

    LLVMTargetRef target = NULL;
    char *err = NULL;
    if (!use || LLVMGetTargetFromTriple(use, &target, &err)) {
        if (err) LLVMDisposeMessage(err);
        if (host) LLVMDisposeMessage(host);
        if (want_host) {
            // The host is unresolvable only on a broken LLVM. Fall back to the
            // width the frontend assumed before targets existed rather than
            // failing a build that never asked for a target in the first place.
            g_target_triple[0] = '\0';
            g_target_layout[0] = '\0';
            g_target_ptr_bits = 64;
            g_target_explicit = 0;
            g_target_selected = 1;
            return 1;
        }
        return 0;
    }

    LLVMTargetMachineRef tm = LLVMCreateTargetMachine(
        target, use, "", "", LLVMCodeGenLevelDefault, LLVMRelocDefault,
        LLVMCodeModelDefault);
    LLVMTargetDataRef td = LLVMCreateTargetDataLayout(tm);
    char *rep = LLVMCopyStringRepOfTargetData(td);

    snprintf(g_target_triple, sizeof(g_target_triple), "%s", use);
    snprintf(g_target_layout, sizeof(g_target_layout), "%s", rep ? rep : "");
    g_target_ptr_bits = (int)LLVMPointerSize(td) * 8;
    g_target_explicit = want_host ? 0 : 1;
    g_target_selected = 1;

    if (rep) LLVMDisposeMessage(rep);
    LLVMDisposeTargetData(td);
    LLVMDisposeTargetMachine(tm);
    if (host) LLVMDisposeMessage(host);
    return 1;
#else
    if (!want_host) return 0;
    g_target_triple[0] = '\0';
    g_target_layout[0] = '\0';
    g_target_ptr_bits = 64;
    g_target_explicit = 0;
    g_target_selected = 1;
    return 1;
#endif
}

static void ensure_target(void) {
    if (!g_target_selected) ir_target_select(NULL);
}

const char *ir_target_triple(void) { ensure_target(); return g_target_triple; }
const char *ir_target_data_layout(void) { ensure_target(); return g_target_layout; }
int ir_target_pointer_bits(void) { ensure_target(); return g_target_ptr_bits; }
int ir_target_is_explicit(void) { ensure_target(); return g_target_explicit; }

// Stamps a named target onto the module being built, which is what makes -g and
// clang agree about it: pin_data_layout() below leaves an existing layout alone,
// so a cross build's member offsets come from the target rather than the host.
void ir_module_set_target(const char *triple, const char *layout) {
    if (!g_module) backend_fail("ir_module_set_target with no module", triple);
    if (triple && *triple) LLVMSetTarget(g_module, triple);
    if (layout && *layout) LLVMSetDataLayout(g_module, layout);
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
    //
    // Still a #ifdef and not a row in the target record above, because this is
    // the *implicit host* case and changing it would change the IR every
    // Windows build emits -- on the one platform none of this was tested on.
    // `--target x86_64-pc-windows-msvc` goes through the record like any other
    // named target; moving the default there is a job for someone with the box.
    LLVMSetTarget(g_module, "x86_64-pc-windows-msvc");
#endif
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
    // Whatever the previous function left set belongs to the previous function's
    // subprogram. Attaching it to an instruction here is not a slightly wrong
    // line, it is a module the verifier rejects -- so it is cleared before the
    // first instruction rather than trusted to be cleared on the way out.
    debug_clear_location();
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
    grow_table((void **)&g_blocks, &g_label_capacity, g_label_count,
               sizeof(LLVMBasicBlockRef), INITIAL_LABELS, "the block table");
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
    // An inline struct field is the only caller, and `aif_layout_split_select`
    // vetoes every type that appears as one -- so this is unreachable rather than
    // guarded. It is spelled out because the failure it prevents is silent:
    // copying a split record copies its *link*, so two objects would share one
    // cold block and the second release would be a double free.
    if (struct_entry(struct_name)->hot_count > 0)
        backend_fail("byte-copy of a split struct", struct_name);
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
    StructType *s = struct_entry(struct_name);
    LLVMTypeRef sty = s->type;

    LLVMValueRef entry_term = LLVMGetBasicBlockTerminator(g_entry_block);
    if (entry_term) {
        LLVMPositionBuilderBefore(g_alloca_builder, entry_term);
    } else {
        LLVMPositionBuilderAtEnd(g_alloca_builder, g_entry_block);
    }

    LLVMValueRef hot = LLVMBuildAlloca(g_alloca_builder, sty, "");
    // A split T0 object is two slots and a link, not two allocations: nothing is
    // reclaimed at either one, so this is the one allocator hook the release path
    // has nothing to say about. Both slots are hoisted to the entry block for the
    // reason above, and the link store goes with them -- it must run before any
    // field access, and every field access is after the entry block by
    // construction.
    if (s->hot_count > 0) {
        LLVMValueRef cold = LLVMBuildAlloca(g_alloca_builder, s->cold, "");
        LLVMValueRef slot = LLVMBuildStructGEP2(g_alloca_builder, sty, hot,
                                                (unsigned)s->hot_count, "");
        LLVMBuildStore(g_alloca_builder, cold, slot);
    }
    return intern_value(hot);
}

// ---------------------------------------------------------------------------
// The second half of a split object.
//
// Allocated through the **same allocator the hot record came from**, and that is
// the whole of the accounting argument. A verify build swaps `g_alloc_fn` and
// `g_free_fn` together, so both halves land in one ledger and a leaked cold block
// reads as a leak rather than as a number nobody compares. An arena build routes
// both to `arena_alloc`, so the region reclaims both in bulk and neither is ever
// handed to a deallocator.
//
// Emitted immediately after the hot allocation and before any field initialiser,
// because a struct literal's first cold field write is the next instruction.
// ---------------------------------------------------------------------------
static void attach_cold(const StructType *s, LLVMValueRef hot, const char *alloc_fn,
                        LLVMTypeRef size_ty) {
    if (!s || s->hot_count <= 0) return;
    LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);

    LLVMValueRef size = LLVMSizeOf(s->cold);
    if (size_ty != LLVMInt64TypeInContext(g_ctx)) {
        size = LLVMBuildTrunc(g_builder, size, size_ty, "");
    }

    LLVMTypeRef alloc_ty = LLVMFunctionType(ptr, &size_ty, 1, 0);
    LLVMValueRef fn = LLVMGetNamedFunction(g_module, alloc_fn);
    if (!fn) fn = LLVMAddFunction(g_module, alloc_fn, alloc_ty);

    LLVMValueRef args[1] = {size};
    LLVMValueRef cold = LLVMBuildCall2(g_builder, alloc_ty, fn, args, 1, "");
    LLVMValueRef slot = LLVMBuildStructGEP2(g_builder, s->type, hot,
                                            (unsigned)s->hot_count, "");
    LLVMBuildStore(g_builder, cold, slot);
}

int ir_alloc_object(const char *struct_name) {
    StructType *s = struct_entry(struct_name);
    LLVMTypeRef sty = s->type;
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
    LLVMValueRef hot = LLVMBuildCall2(g_builder, alloc_ty, alloc_fn, args, 1, "");
    attach_cold(s, hot, g_alloc_fn, size_ty);
    return intern_value(hot);
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
    StructType *s = struct_entry(struct_name);
    LLVMTypeRef sty = s->type;
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
    LLVMValueRef hot = LLVMBuildCall2(g_builder, alloc_ty, alloc_fn, args, 1, "");
    // Both halves from the arena, so the region's pop reclaims both and neither
    // is ever handed to a deallocator -- which is also why an arena-served split
    // site needs nothing at all from the release path.
    attach_cold(s, hot, "arena_alloc", size_ty);
    return intern_value(hot);
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
// **T3 is where a split cracks, and the fix has room already.** `rc_release`
// frees one block and cannot name the type -- a counted value's last holder is a
// container's teardown, which reaches `rc_release(e)` holding a bare pointer. The
// generated release is not on that path, so forcing `aif_type_releases` does not
// reach it either.
//
// The answer is the one `cyc_set_type` already uses: tell the object at
// construction. `RC_HDR` is 16 bytes with 8 in use, so the **byte offset of the
// link word fits in the spare word** -- no function pointer, no per-type table,
// and no extra call beyond the one allocating the cold block. `rc_release` then
// loads the cold pointer at that offset and frees it before the base.
//
// Offset 0 is the sentinel for "not split", and it is a sound one rather than a
// convenient one: field 0 is pinned hot and placed first, so a link word can
// never sit at byte 0 of any hot record.
static void attach_cold_rc(const StructType *s, LLVMValueRef hot, LLVMTypeRef size_ty) {
    if (!s || s->hot_count <= 0) return;
    LLVMTypeRef voidty = LLVMVoidTypeInContext(g_ctx);
    LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);

    unsigned long long off = LLVMOffsetOfElement(LLVMGetModuleDataLayout(g_module),
                                                 s->type, (unsigned)s->hot_count);

    LLVMValueRef size = LLVMSizeOf(s->cold);
    if (size_ty != LLVMInt64TypeInContext(g_ctx)) {
        size = LLVMBuildTrunc(g_builder, size, size_ty, "");
    }

    LLVMTypeRef params[3] = {ptr, size_ty, size_ty};
    LLVMTypeRef fn_ty = LLVMFunctionType(voidty, params, 3, 0);
    LLVMValueRef fn = LLVMGetNamedFunction(g_module, "rc_attach_cold");
    if (!fn) fn = LLVMAddFunction(g_module, "rc_attach_cold", fn_ty);

    LLVMValueRef args[3] = {hot, size, LLVMConstInt(size_ty, off, 0)};
    LLVMBuildCall2(g_builder, fn_ty, fn, args, 3, "");
}

int ir_alloc_rc(const char *struct_name) {
    StructType *s = struct_entry(struct_name);
    LLVMTypeRef sty = s->type;
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
    LLVMValueRef hot = LLVMBuildCall2(g_builder, alloc_ty, alloc_fn, args, 1, "");
    attach_cold_rc(s, hot, size_ty);
    return intern_value(hot);
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

// LAYOUT 6's hot/cold split, the release half.
//
// A split object is two allocations and `ir_free_object` above frees one block
// while knowing nothing about its type -- so this is emitted immediately before
// it, from inside the generated `__aif_release_T`, which is the one place in the
// program where the pointer and the type are both in hand. `aif_type_releases` is
// forced true for every split type precisely so that this is on every path a
// split object can die by.
//
// A no-op for an unsplit type, which is what lets generateReleaseFn call it
// unconditionally: the frontend does not have to know which types were split, and
// therefore cannot get it wrong for one of them.
//
// Ordering is not cosmetic. The cold pointer lives *inside* the hot record, so
// reading it after the base has been freed is a use-after-free -- and in a verify
// build, a read of poisoned bytes handed straight to the deallocator.
void ir_free_cold(const char *struct_name, const char *value) {
    StructType *s = struct_entry(struct_name);
    if (s->hot_count <= 0) return;
    if (block_done()) return;

    LLVMTypeRef voidty = LLVMVoidTypeInContext(g_ctx);
    LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);

    LLVMValueRef obj = resolve_value(value, "ptr");
    LLVMValueRef slot = LLVMBuildStructGEP2(g_builder, s->type, obj,
                                            (unsigned)s->hot_count, "");
    LLVMValueRef cold = LLVMBuildLoad2(g_builder, ptr, slot, "");

    LLVMTypeRef free_ty = LLVMFunctionType(voidty, &ptr, 1, 0);
    LLVMValueRef free_fn = LLVMGetNamedFunction(g_module, g_free_fn);
    if (!free_fn) free_fn = LLVMAddFunction(g_module, g_free_fn, free_ty);

    LLVMValueRef args[1] = {cold};
    LLVMBuildCall2(g_builder, free_ty, free_fn, args, 1, "");
}

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

// AIF T4a. The same release through the atomic entry point.
//
// A distinct symbol chosen at compile time rather than a flag tested at run
// time, which is the point of inferring thread affinity at all: SPEC 11
// item 10 keeps atomics off the common path, and a value proved never to cross
// a thread boundary should not pay even a predictable branch to establish that.
void ir_free_rc_atomic(const char *value) { ir_release_call(value, "rc_release_atomic"); }

// AIF T4b. The fifth allocator hook, and a `fn(size) -> ptr` like the other
// four: the colour and the per-type descriptor go in front of the pointer, so
// the LLVM struct type is untouched and cyc_set_type fills them in afterwards --
// the same shape as list_set_elem_owner, and for the same reason.
int ir_alloc_cycle(const char *struct_name) {
    StructType *s = struct_entry(struct_name);
    // Not a fallback: `aif_layout_split_select` vetoes every type in a non-trivial
    // SCC, and a T4b site's type is in one by the tier's definition, so the two
    // sets are disjoint by construction. This is the assertion that says so out
    // loud -- if the veto is ever loosened, `cyc_free_object` calls the generated
    // release on the payload while the base is `payload - CYC_HDR`, and a split
    // would put a second block behind that asymmetry.
    if (s->hot_count > 0) backend_fail("split type reached the cycle allocator", struct_name);
    LLVMTypeRef sty = s->type;
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
//
// **The single choke point for field access, and therefore the whole of the
// hot/cold redirection.** Codegen indexes fields 0..n-1 in the order
// `aif_layout_field` chose; when the type is split that order is hot fields
// first, so an index at or above `hot_count` is a cold field and is reached by
// loading the link and GEPing into the cold block instead. One dependent load,
// which is exactly what LAYOUT 5.2.1 prices a linked split at.
int ir_struct_field_ptr(const char *struct_name, const char *object, int field_index) {
    StructType *s = struct_entry(struct_name);
    LLVMValueRef obj = resolve_value(object, "ptr");
    if (field_index < 0) backend_fail("negative struct field index", struct_name);

    if (s->hot_count > 0 && field_index >= s->hot_count) {
        LLVMTypeRef ptr = LLVMPointerTypeInContext(g_ctx, 0);
        LLVMValueRef link = LLVMBuildStructGEP2(g_builder, s->type, obj,
                                                (unsigned)s->hot_count, "");
        LLVMValueRef cold = LLVMBuildLoad2(g_builder, ptr, link, "");
        return intern_value(LLVMBuildStructGEP2(g_builder, s->cold, cold,
                                                (unsigned)(field_index - s->hot_count), ""));
    }

    return intern_value(
        LLVMBuildStructGEP2(g_builder, s->type, obj, (unsigned)field_index, ""));
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
// Debug information (DWARF)
//
// `prismio build <src> -g` puts a DICompileUnit, a DISubprogram per source
// function, a line table, and a DILocalVariable per binding into the module.
// clang then emits DWARF from them; no `-g` is passed to clang, because for an
// LLVM IR input the module's own metadata is what drives emission.
//
// Everything here is off unless the frontend calls ir_debug_begin(). A release
// build takes not one branch differently, which is why -g could land without
// moving a byte of anyone's output.
//
// ---------------------------------------------------------------------------
// The rule this section is written around: **never emit a location that is
// wrong.** A debugger that says "no location for x" sends the reader to a print
// statement. A debugger that says "x is at frame offset 12" when x is at 16
// sends the reader after a bug that does not exist. So every entry point below
// has an "I cannot answer that" path, and takes it:
//
//   - an unregistered file id, or a line of 0 (a node the parser synthesised
//     rather than read), emits no location and leaves the previous one standing;
//   - a function whose declaration has no readable span gets no DISubprogram at
//     all, so nothing inside it claims a line;
//   - a local whose alloca this layer cannot name gets no variable entry;
//   - a struct is described only when its exact byte layout is known, and a
//     field the hot/cold split moved out of the record is described where it
//     really is (behind the link pointer) rather than at a made-up offset.
//
// ---------------------------------------------------------------------------
// Three things Prismio makes harder than C does, and what is done about each.
//
// **1. AIF's T0 hoists an allocation into an alloca in the entry block**, and
// one slot serves every iteration of the loop that declares it. The DWARF is
// still true: the variable's storage *is* that slot, and its DILexicalBlock
// bounds it to the block that declares it, exactly as a C loop-body local is
// bounded. What DWARF cannot say -- and what this does not pretend to say -- is
// that a pointer to a T0 object read in iteration 1 names iteration 2's object
// afterwards. That is a property of the promotion, not of the location, and
// docs/DEBUGGING.md is where it is written down.
//
// **2. An arena-placed value has no individual lifetime.** Its slot is a
// pointer, and the pointer is right for as long as the binding is in scope; the
// storage behind it dies with the enclosing region, all at once. Scoping covers
// the binding. It does not cover a pointer copied out of the region, and DWARF
// has no way to express "valid until this other PC" for a heap object. Again
// documented rather than approximated.
//
// **3. A field may not be where the source says it is.** LAYOUT 7.2 permutes
// field order and LAYOUT 6 can move the tail of a record into a separate cold
// block. Member offsets here are therefore never computed from the declaration
// -- they come from LLVMOffsetOfElement over the struct LLVM actually built, so
// a permutation is described rather than papered over, and a split type is
// described as what it is: a hot record with a `__cold` pointer, and a second
// composite behind it.
//
// ---------------------------------------------------------------------------
// Why a -g build pins the module's data layout
//
// A module with no `target datalayout` is laid out by LLVM's *default*
// specification, in which i64 has a 4-byte ABI alignment. `{ i32, i64 }` is 12
// bytes there and 16 on every target this compiler supports, so member offsets
// read from the default would be four bytes out on the first 64-bit field of
// every struct that has one. clang would then lay the object out its own way and
// the DWARF would point into the middle of a field. So -g asks the host target
// machine for its layout and writes it onto the module, which is what clang does
// for a C translation unit and for the same reason. A module that already has a
// layout keeps it -- nothing sets one today, but a cross-target build would.
// ============================================================================

#ifdef PRISMIO_DWARF

// From diagnostics.c. A file id on an AST node indexes that registry; the path
// is what a DIFile needs. diag_file_count() is the difference between "file 7"
// and "there is no file 7" -- without it an out-of-range id renders as
// "<unknown>", which is a filename a debugger would go looking for.
int diag_file_count(void);
const char *diag_file_path(int file);

// From program_support.c, for DW_AT_comp_dir. A source path reaches the
// compiler as the user typed it, so it is usually relative, and a debugger
// resolves a relative DW_AT_name against the compilation directory.
char *current_directory(void);

// From ir_symbols.c. The field *names* of a registered struct, in the order they
// were registered -- which generateStructDecl guarantees is the physical order
// the layout search chose, not the declaration order.
int ir_get_struct_field_count(const char *struct_name);
const char *ir_get_struct_field_name_at(const char *struct_name, int index);
const char *ir_get_struct_field_type_at(const char *struct_name, int index);
int ir_is_struct_type_name(const char *name);

// Same file. `ir_named_type_kind` is how a struct is told from an enum: guessing
// from the name is wrong, because `TokenType` is an enum and does not look like
// one. 1 = struct, 2 = enum, 0 = not a declared type.
int ir_named_type_kind(const char *name);
int ir_get_enum_variant_count(const char *enum_name);
const char *ir_get_enum_variant_name_at(const char *enum_name, int index);
int ir_get_enum_variant_value_at(const char *enum_name, int index);

// DWARF base-type encodings. llvm-c/DebugInfo.h types LLVMDWARFTypeEncoding as a
// bare `unsigned` and defines no constants for it, so these are DWARF 5 table
// 7.11 verbatim rather than something LLVM would check.
#define PRISMIO_DW_ATE_boolean 0x02
#define PRISMIO_DW_ATE_float 0x04
#define PRISMIO_DW_ATE_signed 0x05
#define PRISMIO_DW_ATE_signed_char 0x06
#define PRISMIO_DW_TAG_structure_type 0x13

#define MAX_DI_FILES 256
#define MAX_DI_SCOPES 64
#define MAX_DI_TYPES 512
#define MAX_DI_SCOPE_FILES 128

static LLVMDIBuilderRef g_di;
static LLVMMetadataRef g_di_cu;
static LLVMMetadataRef g_di_files[MAX_DI_FILES];
static LLVMTargetDataRef g_di_layout;
static LLVMMetadataRef g_di_empty_expr;
static char g_di_dir[1024];

// The open scope chain: [0] is the subprogram, the rest are lexical blocks. A
// depth of 0 means no function with debug info is open, and every entry point
// below is a no-op in that state -- which is how a generated function
// (__aif_release_T, an extern stub, the workload driver) ends up with no line
// information rather than with a made-up one.
typedef struct {
    LLVMMetadataRef scope;
    int file; // the frontend file id this scope's DIFile came from
} DIScope;
static DIScope g_di_scopes[MAX_DI_SCOPES];
static int g_di_depth;

// A DILocation carries no file of its own: it inherits the file of its scope.
// So a statement whose file differs from the function around it would be
// attributed to the function's file -- a wrong answer rather than a missing one.
// DILexicalBlockFile is the mechanism for exactly that (it is what `#line`
// lowers to); these are the ones already built.
//
// **Nothing in the tree reaches this today**, and that was checked rather than
// assumed: no program in tests/ or aif/corpus/ emits a DILexicalBlockFile,
// because resolveImports flattens files without moving nodes between them and a
// monomorphised clone keeps its template's file on both the body and the
// function. It is kept because the alternative is not "no code" but "a silently
// wrong file", and the first pass that copies an AST node across a file boundary
// would introduce that without failing anything.
typedef struct {
    LLVMMetadataRef scope;
    int file;
    LLVMMetadataRef derived;
} DIScopeFile;
static DIScopeFile g_di_scope_files[MAX_DI_SCOPE_FILES];
static int g_di_scope_file_count;

typedef struct {
    char key[NAME_LEN];
    LLVMMetadataRef type;
} DITypeEntry;
static DITypeEntry g_di_types[MAX_DI_TYPES];
static int g_di_type_count;

// Where each struct was declared. Kept here rather than derived, because the
// backend's struct table holds a layout and no provenance -- and a composite
// attributed to the wrong file is the same class of wrong answer as a member at
// the wrong offset. A type nobody registered gets no DW_AT_decl_file at all.
typedef struct {
    char name[NAME_LEN];
    int file;
    int line;
} DIStructSite;
static DIStructSite g_di_struct_sites[256];
static int g_di_struct_site_count;

// The same, for enums. A separate table rather than a shared one keyed by kind:
// the two are looked up by different code and a name can only be one of them,
// so sharing would buy nothing and cost a kind check on every lookup.
static DIStructSite g_di_enum_sites[256];
static int g_di_enum_site_count;

// The source-level type name of one field, for the same reason a local has one:
// ir_symbols.c stores the *storage* key, and String, List<T>, [T], `T?` and every
// struct are all `ptr` there. Without this a struct's String field reads as an
// anonymous address instead of printing its characters.
//
// Its own table rather than a fourth argument to ir_register_struct_field: that
// function is called by the committed seed's IR, and changing its arity would
// mean the seed could no longer link.
typedef struct {
    char owner[NAME_LEN];
    char field[NAME_LEN];
    char type[NAME_LEN];
} DIFieldType;
static DIFieldType g_di_field_types[1024];
static int g_di_field_type_count;

static const char *di_field_type_name(const char *owner, const char *field) {
    for (int i = 0; i < g_di_field_type_count; i++) {
        if (strcmp(g_di_field_types[i].owner, owner) == 0
            && strcmp(g_di_field_types[i].field, field) == 0) {
            return g_di_field_types[i].type;
        }
    }
    return NULL;
}

void ir_debug_field_type(const char *owner, const char *field, const char *type_name) {
    if (!g_di || g_di_field_type_count >= 1024) return;
    snprintf(g_di_field_types[g_di_field_type_count].owner, NAME_LEN, "%s", owner);
    snprintf(g_di_field_types[g_di_field_type_count].field, NAME_LEN, "%s", field);
    snprintf(g_di_field_types[g_di_field_type_count].type, NAME_LEN, "%s", type_name);
    g_di_field_type_count++;
}

int ir_debug_enabled(void) { return g_di != NULL; }

void ir_debug_location(int file_id, int line, int col);

// The declared signature, buffered between ir_function_begin and
// ir_function_body_start.
//
// It exists because the LLVM function type is not enough. Everything with an
// address is `ptr` there -- a String, a List, a Point, an opaque extern return --
// so a signature read off it says `void *` five times where the source said five
// different things. The frontend knows which is which and says so here; slot 0
// is the return.
//
// Only used when the count matches what LLVM built. It will not match for main,
// whose real argc/argv are prepended by codegen, and a mismatch means the two
// have gone out of step -- in which case the storage types are still true, just
// coarser, and that is what gets emitted.
static char g_di_sig_key[MAX_PENDING_PARAMS + 1][NAME_LEN];
static char g_di_sig_name[MAX_PENDING_PARAMS + 1][NAME_LEN];
static int g_di_sig_count;

static void sig_push(const char *key, const char *name) {
    if (g_di_sig_count > MAX_PENDING_PARAMS) return;
    snprintf(g_di_sig_key[g_di_sig_count], NAME_LEN, "%s", key ? key : "");
    snprintf(g_di_sig_name[g_di_sig_count], NAME_LEN, "%s", name ? name : "");
    g_di_sig_count++;
}

void ir_debug_signature(const char *ret_key, const char *ret_name) {
    if (!g_di) return;
    g_di_sig_count = 0;
    sig_push(ret_key, ret_name);
}

void ir_debug_signature_param(const char *key, const char *name) {
    if (!g_di || g_di_sig_count == 0) return;
    sig_push(key, name);
}

static LLVMMetadataRef di_file(int file_id) {
    if (!g_di) return NULL;
    if (file_id < 0 || file_id >= MAX_DI_FILES) return NULL;
    if (file_id >= diag_file_count()) return NULL;
    if (g_di_files[file_id]) return g_di_files[file_id];

    const char *path = diag_file_path(file_id);
    g_di_files[file_id] = LLVMDIBuilderCreateFile(g_di, path, strlen(path),
                                                  g_di_dir, strlen(g_di_dir));
    return g_di_files[file_id];
}

// ---------------------------------------------------------------------------
// Types
//
// Two facts are needed per binding and the frontend has one of each: the
// *storage* key it already passes to every builder here ("i32", "ptr",
// "struct:Foo"), which is authoritative about size, and the source-level type
// name sema recorded ("Int", "String", "Point"), which is what the reader typed.
// The key decides the shape; the name only refines a pointer, and only when the
// two agree about there being a pointer.
// ---------------------------------------------------------------------------

static LLVMMetadataRef di_cached(const char *key) {
    for (int i = 0; i < g_di_type_count; i++) {
        if (strcmp(g_di_types[i].key, key) == 0) return g_di_types[i].type;
    }
    return NULL;
}

static LLVMMetadataRef di_cache(const char *key, LLVMMetadataRef type) {
    if (g_di_type_count >= MAX_DI_TYPES) return type;
    strncpy(g_di_types[g_di_type_count].key, key, NAME_LEN - 1);
    g_di_types[g_di_type_count].key[NAME_LEN - 1] = '\0';
    g_di_types[g_di_type_count].type = type;
    g_di_type_count++;
    return type;
}

static LLVMMetadataRef di_basic(const char *name, uint64_t bits, unsigned encoding) {
    LLVMMetadataRef hit = di_cached(name);
    if (hit) return hit;
    return di_cache(name, LLVMDIBuilderCreateBasicType(g_di, name, strlen(name),
                                                       bits, encoding, LLVMDIFlagZero));
}

// An address whose pointee this layer will not claim to know. Not a lie and not
// nothing: the reader still gets the address, which is what a `ptr` is.
static LLVMMetadataRef di_opaque_ptr(void) {
    LLVMMetadataRef hit = di_cached("$ptr");
    if (hit) return hit;
    return di_cache("$ptr", LLVMDIBuilderCreatePointerType(g_di, NULL, 64, 0, 0, "", 0));
}

static LLVMMetadataRef di_struct_type(const char *name);
static LLVMMetadataRef di_enum_type(const char *name);

// `struct:Foo` in a local's slot means a *pointer* to Foo -- storageType()
// collapses it before the alloca is made -- so the pointee is looked up and the
// pointer built around it.
static LLVMMetadataRef di_pointer_to(const char *pointee_key, LLVMMetadataRef pointee) {
    char key[NAME_LEN];
    snprintf(key, sizeof(key), "$p:%s", pointee_key);
    LLVMMetadataRef hit = di_cached(key);
    if (hit) return hit;
    if (!pointee) return di_opaque_ptr();
    return di_cache(key, LLVMDIBuilderCreatePointerType(g_di, pointee, 64, 0, 0, "", 0));
}

// The storage key alone. `name` refines only the pointer case, and only towards
// something this layer can show to be true.
static LLVMMetadataRef di_type_for(const char *key, const char *name) {
    if (!key || !*key) return NULL;
    if (strcmp(key, "void") == 0) return NULL;
    if (strcmp(key, "i1") == 0) return di_basic("Bool", 8, PRISMIO_DW_ATE_boolean);
    if (strcmp(key, "i8") == 0) return di_basic("Char", 8, PRISMIO_DW_ATE_signed_char);
    if (strcmp(key, "i16") == 0) return di_basic("I16", 16, PRISMIO_DW_ATE_signed);
    if (strcmp(key, "i32") == 0) {
        // Every Prismio enum lowers to i32, so the storage key alone cannot tell
        // `NodeKind` from `Int` -- only the source-level name can, and only when
        // the frontend had one to send. With it, `p kind` prints STRUCT_DECL
        // instead of 12, which on a compiler written around NodeKind, TypeKind
        // and TokenType is most of what a debugger is for.
        if (name && *name && ir_named_type_kind(name) == 2) {
            LLVMMetadataRef e = di_enum_type(name);
            if (e) return e;
        }
        return di_basic("Int", 32, PRISMIO_DW_ATE_signed);
    }
    if (strcmp(key, "i64") == 0) return di_basic("I64", 64, PRISMIO_DW_ATE_signed);
    if (strcmp(key, "double") == 0) return di_basic("Float", 64, PRISMIO_DW_ATE_float);

    if (strncmp(key, "struct:", 7) == 0) {
        return di_pointer_to(key + 7, di_struct_type(key + 7));
    }
    if (strcmp(key, "ptrptr") == 0) return di_pointer_to("$ptr", di_opaque_ptr());

    if (strcmp(key, "ptr") == 0) {
        // A Prismio String is a NUL-terminated char* -- str_concat, str_equals
        // and every runtime string function treat it as one -- so saying `char *`
        // is a statement of fact, and it is what makes a debugger print the
        // contents instead of the address.
        if (name && strcmp(name, "String") == 0) {
            // Lowercase `char`, and the case is load-bearing rather than a
            // style choice. lldb auto-prints a `char *` as its characters and
            // prints a `signed char *` as an address, and it decides which by
            // the base type's *name*: with "Char" here, `frame variable s`
            // rendered `(signed char *) 0x1000042fc` and docs/DEBUGGING.md's
            // promise that a String prints its contents was false. Measured
            // both ways on lldb 22.1.8.
            //
            // Only the String pointee. An `i8` binding is Prismio's `Char` and
            // keeps that name below, because it is a Char and not a C char.
            return di_pointer_to("$char", di_basic("char", 8, PRISMIO_DW_ATE_signed_char));
        }
        // A struct-typed binding whose key was already collapsed to `ptr`.
        if (name && *name && ir_is_struct_type_name(name)) {
            return di_pointer_to(name, di_struct_type(name));
        }
        // A List, an Optional, an array, an opaque extern return. Each is an
        // address of something this layer has no layout for.
        return di_opaque_ptr();
    }
    return NULL;
}

// The same mapping driven by what LLVM built rather than by what the frontend
// said. Used for a function's signature, where the storage types are all this
// layer has and all a DWARF consumer needs.
static LLVMMetadataRef di_type_for_llvm(LLVMTypeRef ty) {
    switch (LLVMGetTypeKind(ty)) {
    case LLVMVoidTypeKind: return NULL;
    case LLVMDoubleTypeKind: return di_type_for("double", NULL);
    case LLVMPointerTypeKind: return di_opaque_ptr();
    case LLVMIntegerTypeKind: {
        unsigned w = LLVMGetIntTypeWidth(ty);
        if (w == 1) return di_type_for("i1", NULL);
        if (w <= 8) return di_type_for("i8", NULL);
        if (w <= 16) return di_type_for("i16", NULL);
        if (w <= 32) return di_type_for("i32", NULL);
        return di_type_for("i64", NULL);
    }
    default: return NULL;
    }
}

// The composite for a registered struct, built from the type LLVM really
// created rather than from the declaration.
//
// The field *names* come from ir_symbols.c in registration order, and
// generateStructDecl registers them in the physical order aif_layout_field
// chose -- so index i is the same field in both, and a permuted layout is
// described correctly without this having to know a search ran.
//
// A split type is the case worth reading. The hot record is `hot_count` fields
// plus a link pointer; the rest live in a separate `Foo.cold` allocation. There
// is no offset in the hot record that names a cold field, so none is invented:
// the composite gets its hot members, a `__cold` member for the link, and a
// second composite for what the link points at. `p obj->__cold->field` is a
// longer thing to type than `p obj->field`, and it is the truth.
// DW_TAG_enumeration_type: the name, and every enumerator with its value.
//
// Enums lower to i32 and every variant's value is one, so the size is fixed and
// there is no layout to read -- which is why this needs none of the machinery
// di_struct_type does, and no replaceable placeholder either: an enumerator
// cannot refer back to its own type.
//
// An enum with no registered variants gets no type rather than an empty one. A
// DW_TAG_enumeration_type with no enumerators tells a debugger the value has a
// name it cannot find, which reads worse than plain `Int`.
static LLVMMetadataRef di_enum_type(const char *name) {
    char key[NAME_LEN];
    snprintf(key, sizeof(key), "$e:%s", name);
    LLVMMetadataRef hit = di_cached(key);
    if (hit) return hit;

    int total = ir_get_enum_variant_count(name);
    if (total <= 0) return NULL;
    if (total > 512) total = 512;

    LLVMMetadataRef site_file = NULL;
    unsigned site_line = 0;
    for (int i = 0; i < g_di_enum_site_count; i++) {
        if (strcmp(g_di_enum_sites[i].name, name) != 0) continue;
        site_file = di_file(g_di_enum_sites[i].file);
        if (g_di_enum_sites[i].line > 0) site_line = (unsigned)g_di_enum_sites[i].line;
        break;
    }

    LLVMMetadataRef *values =
        (LLVMMetadataRef *)malloc(sizeof(LLVMMetadataRef) * (size_t)total);
    if (!values) return NULL;
    unsigned count = 0;
    for (int i = 0; i < total; i++) {
        const char *vname = ir_get_enum_variant_name_at(name, i);
        if (!vname || !*vname) continue;
        values[count++] = LLVMDIBuilderCreateEnumerator(
            g_di, vname, strlen(vname),
            (int64_t)ir_get_enum_variant_value_at(name, i), 0);
    }

    LLVMMetadataRef type = NULL;
    if (count > 0) {
        type = LLVMDIBuilderCreateEnumerationType(
            g_di, g_di_cu, name, strlen(name), site_file, site_line,
            32, 32, values, count,
            di_basic("Int", 32, PRISMIO_DW_ATE_signed));
    }
    free(values);
    if (!type) return NULL;
    return di_cache(key, type);
}

static LLVMMetadataRef di_struct_type(const char *name) {
    char key[NAME_LEN];
    snprintf(key, sizeof(key), "$s:%s", name);
    LLVMMetadataRef hit = di_cached(key);
    if (hit) return hit;

    StructType *s = NULL;
    for (int i = 0; i < g_struct_count; i++) {
        if (strcmp(g_structs[i].name, name) == 0) { s = &g_structs[i]; break; }
    }
    if (!s || !g_di_layout || LLVMIsOpaqueStruct(s->type)) return NULL;

    LLVMMetadataRef site_file = NULL;
    unsigned site_line = 0;
    for (int i = 0; i < g_di_struct_site_count; i++) {
        if (strcmp(g_di_struct_sites[i].name, name) != 0) continue;
        site_file = di_file(g_di_struct_sites[i].file);
        if (g_di_struct_sites[i].line > 0) site_line = (unsigned)g_di_struct_sites[i].line;
        break;
    }

    // Cached before the members are built: a struct that contains a pointer to
    // its own type would otherwise recurse forever.
    LLVMMetadataRef placeholder = LLVMDIBuilderCreateReplaceableCompositeType(
        g_di, PRISMIO_DW_TAG_structure_type, name, strlen(name), g_di_cu,
        site_file, site_line, 0, 0, 0, LLVMDIFlagZero, "", 0);
    di_cache(key, placeholder);

    int total = ir_get_struct_field_count(name);
    int hot = s->hot_count > 0 ? s->hot_count : total;

    LLVMMetadataRef members[66];
    unsigned count = 0;
    for (int i = 0; i < hot && i < total && count < 64; i++) {
        const char *fname = ir_get_struct_field_name_at(name, i);
        const char *ftype = ir_get_struct_field_type_at(name, i);
        LLVMMetadataRef fty = di_type_for(ftype, di_field_type_name(name, fname));
        if (!fty) continue;
        LLVMTypeRef llvm_field = LLVMStructGetTypeAtIndex(s->type, (unsigned)i);
        members[count++] = LLVMDIBuilderCreateMemberType(
            g_di, placeholder, fname, strlen(fname), site_file, 0,
            LLVMABISizeOfType(g_di_layout, llvm_field) * 8,
            LLVMABIAlignmentOfType(g_di_layout, llvm_field) * 8,
            LLVMOffsetOfElement(g_di_layout, s->type, (unsigned)i) * 8,
            LLVMDIFlagZero, fty);
    }

    if (s->hot_count > 0 && s->cold && count < 65) {
        char cold_name[NAME_LEN];
        snprintf(cold_name, sizeof(cold_name), "%s.cold", name);
        LLVMMetadataRef cold_members[64];
        unsigned cold_count = 0;
        for (int i = hot; i < total && cold_count < 64; i++) {
            const char *fname = ir_get_struct_field_name_at(name, i);
            const char *ftype = ir_get_struct_field_type_at(name, i);
            LLVMMetadataRef fty = di_type_for(ftype, di_field_type_name(name, fname));
            if (!fty) continue;
            LLVMTypeRef llvm_field = LLVMStructGetTypeAtIndex(s->cold, (unsigned)(i - hot));
            cold_members[cold_count++] = LLVMDIBuilderCreateMemberType(
                g_di, g_di_cu, fname, strlen(fname), site_file, 0,
                LLVMABISizeOfType(g_di_layout, llvm_field) * 8,
                LLVMABIAlignmentOfType(g_di_layout, llvm_field) * 8,
                LLVMOffsetOfElement(g_di_layout, s->cold, (unsigned)(i - hot)) * 8,
                LLVMDIFlagZero, fty);
        }
        LLVMMetadataRef cold_ty = LLVMDIBuilderCreateStructType(
            g_di, g_di_cu, cold_name, strlen(cold_name), site_file, site_line,
            LLVMABISizeOfType(g_di_layout, s->cold) * 8,
            LLVMABIAlignmentOfType(g_di_layout, s->cold) * 8,
            LLVMDIFlagZero, NULL, cold_members, cold_count, 0, NULL, "", 0);

        LLVMTypeRef link = LLVMStructGetTypeAtIndex(s->type, (unsigned)hot);
        members[count++] = LLVMDIBuilderCreateMemberType(
            g_di, placeholder, "__cold", 6, site_file, 0,
            LLVMABISizeOfType(g_di_layout, link) * 8,
            LLVMABIAlignmentOfType(g_di_layout, link) * 8,
            LLVMOffsetOfElement(g_di_layout, s->type, (unsigned)hot) * 8,
            LLVMDIFlagZero, LLVMDIBuilderCreatePointerType(g_di, cold_ty, 64, 0, 0, "", 0));
    }

    LLVMMetadataRef real = LLVMDIBuilderCreateStructType(
        g_di, g_di_cu, name, strlen(name), site_file, site_line,
        LLVMABISizeOfType(g_di_layout, s->type) * 8,
        LLVMABIAlignmentOfType(g_di_layout, s->type) * 8,
        LLVMDIFlagZero, NULL, members, count, 0, NULL, "", 0);
    LLVMMetadataReplaceAllUsesWith(placeholder, real);

    for (int i = 0; i < g_di_type_count; i++) {
        if (strcmp(g_di_types[i].key, key) == 0) g_di_types[i].type = real;
    }
    return real;
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

// Asks the target machine for the layout the object file will be built with, and
// writes it onto the module. See the section header for why a -g build cannot
// use LLVM's default specification.
//
// **A named target has already stamped its own layout** (ir_module_set_target,
// in the "Targets" section above), and the early return below is what makes a
// cross-compiled -g build read member offsets from the *target* rather than from
// this host -- which is precisely the bug this layer exists to prevent. Verified:
// a struct { Int, String, I64 } reports its String member at offset 64 on a
// 64-bit host and at offset 32 for wasm32-unknown-unknown.
//
// The host default is reached only when nothing was named, and only then is
// LLVMGetDefaultTargetTriple() the right question to ask.
static void pin_data_layout(void) {
    const char *existing = LLVMGetDataLayoutStr(g_module);
    if (existing && *existing) {
        g_di_layout = LLVMGetModuleDataLayout(g_module);
        return;
    }

    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();

    char *triple = LLVMGetDefaultTargetTriple();
    LLVMTargetRef target = NULL;
    char *err = NULL;
    if (LLVMGetTargetFromTriple(triple, &target, &err)) {
        // No layout means no member offsets, and the composites are skipped
        // rather than guessed. Line tables and scalar locals are unaffected.
        fprintf(stderr, "warning: -g could not resolve the host target (%s); "
                        "struct layouts will be omitted from the debug info\n",
                err ? err : "?");
        if (err) LLVMDisposeMessage(err);
        LLVMDisposeMessage(triple);
        return;
    }

    LLVMTargetMachineRef tm = LLVMCreateTargetMachine(
        target, triple, "", "", LLVMCodeGenLevelDefault, LLVMRelocDefault,
        LLVMCodeModelDefault);
    LLVMTargetDataRef td = LLVMCreateTargetDataLayout(tm);
    char *rep = LLVMCopyStringRepOfTargetData(td);
    LLVMSetDataLayout(g_module, rep);
    const char *triple_now = LLVMGetTarget(g_module);
    if (!triple_now || !*triple_now) LLVMSetTarget(g_module, triple);
    LLVMDisposeMessage(rep);
    LLVMDisposeTargetMachine(tm);
    LLVMDisposeMessage(triple);

    g_di_layout = LLVMGetModuleDataLayout(g_module);
}

void ir_debug_begin(const char *producer, const char *main_path, int is_optimized) {
    if (!g_module) backend_fail("-g: no module to attach debug info to", NULL);
    if (g_di) return;

    memset(g_di_files, 0, sizeof(g_di_files));
    g_di_type_count = 0;
    g_di_scope_file_count = 0;
    g_di_struct_site_count = 0;
    g_di_enum_site_count = 0;
    g_di_field_type_count = 0;
    g_di_sig_count = 0;
    g_di_depth = 0;

    char *cwd = current_directory();
    snprintf(g_di_dir, sizeof(g_di_dir), "%s", cwd ? cwd : ".");
    if (cwd) free(cwd);

    g_di = LLVMCreateDIBuilder(g_module);
    pin_data_layout();

    LLVMMetadataRef file = LLVMDIBuilderCreateFile(g_di, main_path, strlen(main_path),
                                                   g_di_dir, strlen(g_di_dir));
    // DW_LANG_C99 rather than a Prismio of our own. DWARF's language codes are
    // registered, Prismio has none, and the code is not decoration: lldb and gdb
    // pick an expression parser and a formatter from it. C99 is the one whose
    // value model -- machine integers, NUL-terminated char*, flat structs -- is
    // what a Prismio binary actually contains.
    g_di_cu = LLVMDIBuilderCreateCompileUnit(
        g_di, LLVMDWARFSourceLanguageC99, file, producer, strlen(producer),
        is_optimized ? 1 : 0, "", 0, 0, "", 0, LLVMDWARFEmissionFull, 0, 0, 0, "", 0, "", 0);

    g_di_empty_expr = LLVMDIBuilderCreateExpression(g_di, NULL, 0);

    // "Debug Info Version" is what makes the backend read any of this; without
    // it every !dbg node is dropped on the way to the object. The DWARF version
    // is pinned at 4 rather than left to the target's default so that two hosts
    // produce the same thing, and at 4 rather than 5 because every lldb, gdb and
    // dsymutil in service reads 4. Raise it when something needs a 5-only form.
    LLVMTypeRef i32 = LLVMInt32TypeInContext(g_ctx);
    LLVMAddModuleFlag(g_module, LLVMModuleFlagBehaviorWarning, "Dwarf Version", 13,
                      LLVMValueAsMetadata(LLVMConstInt(i32, 4, 0)));
    LLVMAddModuleFlag(g_module, LLVMModuleFlagBehaviorWarning, "Debug Info Version", 18,
                      LLVMValueAsMetadata(LLVMConstInt(i32, 3, 0)));
}

void ir_debug_end(void) {
    if (!g_di) return;
    LLVMDIBuilderFinalize(g_di);
}

static void debug_dispose(void) {
    if (!g_di) return;
    LLVMDisposeDIBuilder(g_di);
    g_di = NULL;
    g_di_cu = NULL;
    g_di_layout = NULL;
    g_di_depth = 0;
}

static void debug_clear_location(void) {
    if (!g_di) return;
    LLVMSetCurrentDebugLocation2(g_builder, NULL);
    LLVMSetCurrentDebugLocation2(g_alloca_builder, NULL);
}

// ---------------------------------------------------------------------------
// Scopes and locations
// ---------------------------------------------------------------------------

// The scope a location in `file` should hang from. Same file as the enclosing
// scope: the scope itself. A different one: a DILexicalBlockFile over it, so the
// line is attributed to the file it was written in.
static LLVMMetadataRef scope_in_file(int file) {
    LLVMMetadataRef scope = g_di_scopes[g_di_depth - 1].scope;
    if (file == g_di_scopes[g_di_depth - 1].file) return scope;

    LLVMMetadataRef f = di_file(file);
    if (!f) return scope;

    for (int i = 0; i < g_di_scope_file_count; i++) {
        if (g_di_scope_files[i].scope == scope && g_di_scope_files[i].file == file) {
            return g_di_scope_files[i].derived;
        }
    }
    LLVMMetadataRef derived = LLVMDIBuilderCreateLexicalBlockFile(g_di, scope, f, 0);
    if (g_di_scope_file_count < MAX_DI_SCOPE_FILES) {
        g_di_scope_files[g_di_scope_file_count].scope = scope;
        g_di_scope_files[g_di_scope_file_count].file = file;
        g_di_scope_files[g_di_scope_file_count].derived = derived;
        g_di_scope_file_count++;
    }
    return derived;
}

void ir_debug_function_begin(const char *name, const char *linkage_name,
                             int file_id, int line) {
    if (!g_di || !g_function) return;
    g_di_depth = 0;

    LLVMMetadataRef file = di_file(file_id);
    if (!file || line <= 0) return; // no span to point at: no subprogram

    LLVMTypeRef fn_ty = LLVMGlobalGetValueType(g_function);
    LLVMMetadataRef types[MAX_PENDING_PARAMS + 1];
    unsigned n = 0;
    unsigned pc = LLVMCountParamTypes(fn_ty);
    if (pc > MAX_PENDING_PARAMS) pc = MAX_PENDING_PARAMS;

    if (g_di_sig_count == (int)pc + 1) {
        // The declared signature. Preferred because it distinguishes the five
        // different things that are all `ptr` in the LLVM type.
        for (int i = 0; i < g_di_sig_count; i++) {
            types[n++] = di_type_for(g_di_sig_key[i], g_di_sig_name[i]);
        }
    } else {
        // Storage-level, from the function LLVM built. Coarser and still true.
        LLVMTypeRef ret = LLVMGetReturnType(fn_ty);
        types[n++] = LLVMGetTypeKind(ret) == LLVMVoidTypeKind ? NULL : di_type_for_llvm(ret);
        LLVMTypeRef params[MAX_PENDING_PARAMS];
        LLVMGetParamTypes(fn_ty, params);
        for (unsigned i = 0; i < pc; i++) types[n++] = di_type_for_llvm(params[i]);
    }

    // NULL means void, and void is only meaningful at index 0. A parameter this
    // layer could not map would be read as "nothing" in the middle of a
    // signature, so the whole signature is dropped rather than half-stated -- the
    // subprogram, the line table and the locals all survive without it.
    for (unsigned i = 1; i < n; i++) {
        if (!types[i]) { n = 0; break; }
    }

    LLVMMetadataRef sub_ty = LLVMDIBuilderCreateSubroutineType(
        g_di, file, n > 0 ? types : NULL, n, LLVMDIFlagZero);

    LLVMMetadataRef sp = LLVMDIBuilderCreateFunction(
        g_di, file, name, strlen(name), linkage_name, strlen(linkage_name), file,
        (unsigned)line, sub_ty, 0, 1, (unsigned)line, LLVMDIFlagZero, 0);
    LLVMSetSubprogram(g_function, sp);

    g_di_scopes[0].scope = sp;
    g_di_scopes[0].file = file_id;
    g_di_depth = 1;
    ir_debug_location(file_id, line, 1);
}

void ir_debug_function_end(void) {
    if (!g_di) return;
    g_di_depth = 0;
    // Cleared, and this is not tidiness. A stale location outlives the function
    // it belongs to, and the next instruction built would carry a !dbg whose
    // scope is another function's subprogram -- which the verifier rejects, and
    // which would otherwise be a build failure whose cause is three functions
    // back.
    LLVMSetCurrentDebugLocation2(g_builder, NULL);
    LLVMSetCurrentDebugLocation2(g_alloca_builder, NULL);
}

void ir_debug_scope_push(int file_id, int line, int col) {
    if (!g_di || g_di_depth == 0 || g_di_depth >= MAX_DI_SCOPES) return;
    LLVMMetadataRef file = di_file(file_id);
    if (!file) file = LLVMDIScopeGetFile(g_di_scopes[g_di_depth - 1].scope);

    LLVMMetadataRef block = LLVMDIBuilderCreateLexicalBlock(
        g_di, g_di_scopes[g_di_depth - 1].scope, file,
        (unsigned)(line > 0 ? line : 0), (unsigned)(col > 0 ? col : 0));
    g_di_scopes[g_di_depth].scope = block;
    g_di_scopes[g_di_depth].file = file_id;
    g_di_depth++;
}

void ir_debug_scope_pop(void) {
    // Never below the subprogram: generateFunction pops the parameter scope
    // after generateBlock has popped the body's, and one unbalanced pop would
    // leave every later location hanging off nothing.
    if (!g_di || g_di_depth <= 1) return;
    g_di_depth--;
}

void ir_debug_location(int file_id, int line, int col) {
    if (!g_di || g_di_depth == 0) return;
    // A synthesised node -- a desugared `x += 1`, an inserted drop, anything
    // createNode() made without a token -- carries line 0. Claiming line 0 puts
    // the debugger at the top of the file; leaving the previous location
    // standing attributes the instruction to the statement that caused it, which
    // is where it came from.
    if (line <= 0) return;
    if (di_file(file_id) == NULL) return;

    LLVMMetadataRef loc = LLVMDIBuilderCreateDebugLocation(
        g_ctx, (unsigned)line, (unsigned)(col > 0 ? col : 0), scope_in_file(file_id), NULL);
    LLVMSetCurrentDebugLocation2(g_builder, loc);
    LLVMSetCurrentDebugLocation2(g_alloca_builder, loc);
}

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

// `slot` is the alloca's name, the same one ir_alloca() was given and every
// load and store since has resolved through. arg_no is 0 for a local and the
// 1-based parameter position otherwise.
void ir_debug_local(const char *name, const char *slot, const char *type_key,
                    const char *type_name, int file_id, int line, int arg_no) {
    if (!g_di || g_di_depth == 0) return;
    if (line <= 0) return;

    LLVMTypeRef stored = NULL;
    LLVMValueRef storage = lookup_named(g_allocas, g_alloca_count, slot, &stored);
    if (!storage) return; // nothing this layer can name: no entry, no guess

    LLVMMetadataRef file = di_file(file_id);
    if (!file) return;

    LLVMMetadataRef ty = di_type_for(type_key, type_name);
    if (!ty) return;

    LLVMMetadataRef scope = g_di_scopes[g_di_depth - 1].scope;
    LLVMMetadataRef var =
        arg_no > 0
            ? LLVMDIBuilderCreateParameterVariable(g_di, scope, name, strlen(name),
                                                   (unsigned)arg_no, file, (unsigned)line,
                                                   ty, 1, LLVMDIFlagZero)
            : LLVMDIBuilderCreateAutoVariable(g_di, scope, name, strlen(name), file,
                                              (unsigned)line, ty, 1, LLVMDIFlagZero, 0);

    LLVMMetadataRef loc = LLVMDIBuilderCreateDebugLocation(
        g_ctx, (unsigned)line, 0, scope, NULL);
    LLVMBasicBlockRef bb = LLVMGetInsertBlock(g_builder);
    if (!bb) return;
    LLVMDIBuilderInsertDeclareRecordAtEnd(g_di, storage, var, g_di_empty_expr, loc, bb);
}

// A module-level global.
//
// Unlike a local there is no alloca and no insert point: the description hangs
// off the global's own LLVMValueRef as a `!dbg` attachment, and the compile unit
// collects it when the DIBuilder is finalized. So this runs during the module's
// global loop, before any function exists and with no scope stack to read.
//
// Scope is the compile unit rather than a file. `resolveImports` merges every
// module into one unit here, and a Prismio global is visible across that whole
// unit, so LocalToUnit is 0 -- which is also what ir_global_var's linkage says.
void ir_debug_global(const char *name, const char *type_key, const char *type_name,
                     int file_id, int line) {
    if (!g_di) return;
    if (line <= 0) return;

    // Compiler-internal globals (prismio_argc, string literals) never reach this
    // -- only the frontend's VARIABLE_DECL loop calls it -- but a name that does
    // not resolve is still an "I cannot answer that" rather than a guess.
    LLVMValueRef global = LLVMGetNamedGlobal(g_module, name);
    if (!global) return;

    LLVMMetadataRef file = di_file(file_id);
    if (!file) return;

    LLVMMetadataRef ty = di_type_for(type_key, type_name);
    if (!ty) return; // a type this layer has no description for: no entry

    LLVMMetadataRef gve = LLVMDIBuilderCreateGlobalVariableExpression(
        g_di, g_di_cu, name, strlen(name), name, strlen(name), file,
        (unsigned)line, ty, 0, g_di_empty_expr, NULL, 0);
    LLVMGlobalSetMetadata(global, LLVMGetMDKindIDInContext(g_ctx, "dbg", 3), gve);
}

// One enumeration per declared enum, for the same reason ir_debug_struct emits
// one composite per struct: a type a program only passes around is still a type
// `p` should be able to name. The site is recorded first, because di_enum_type
// reads it.
void ir_debug_enum(const char *name, int file_id, int line) {
    if (!g_di) return;
    if (g_di_enum_site_count < 256) {
        strncpy(g_di_enum_sites[g_di_enum_site_count].name, name, NAME_LEN - 1);
        g_di_enum_sites[g_di_enum_site_count].name[NAME_LEN - 1] = '\0';
        g_di_enum_sites[g_di_enum_site_count].file = file_id;
        g_di_enum_sites[g_di_enum_site_count].line = line;
        g_di_enum_site_count++;
    }
    di_enum_type(name);
}

// One composite per struct, emitted after generateStructDecl has registered
// every type. Nothing references them until a variable does, so this exists to
// make a type visible to `p` even in a program that only passes it around.
void ir_debug_struct(const char *name, int file_id, int line) {
    if (!g_di) return;
    if (g_di_struct_site_count < 256) {
        strncpy(g_di_struct_sites[g_di_struct_site_count].name, name, NAME_LEN - 1);
        g_di_struct_sites[g_di_struct_site_count].name[NAME_LEN - 1] = '\0';
        g_di_struct_sites[g_di_struct_site_count].file = file_id;
        g_di_struct_sites[g_di_struct_site_count].line = line;
        g_di_struct_site_count++;
    }
    di_struct_type(name);
}

#else // !PRISMIO_DWARF

int ir_debug_enabled(void) { return 0; }

void ir_debug_begin(const char *producer, const char *main_path, int is_optimized) {
    (void)producer; (void)main_path; (void)is_optimized;
    fprintf(stderr,
            "error: -g is not available in this build of the compiler.\n"
            "  Debug info needs the LLVM DebugInfo C API, which is only compiled in\n"
            "  when the backend is built against real llvm-c headers.\n"
            "  Run: python3 tools/setup_llvm.py\n");
    exit(1);
}

void ir_debug_end(void) {}
void ir_debug_signature(const char *k, const char *n) { (void)k; (void)n; }
void ir_debug_signature_param(const char *k, const char *n) { (void)k; (void)n; }
static void debug_dispose(void) {}
static void debug_clear_location(void) {}
void ir_debug_function_begin(const char *n, const char *l, int f, int line) {
    (void)n; (void)l; (void)f; (void)line;
}
void ir_debug_function_end(void) {}
void ir_debug_scope_push(int f, int l, int c) { (void)f; (void)l; (void)c; }
void ir_debug_scope_pop(void) {}
void ir_debug_location(int f, int l, int c) { (void)f; (void)l; (void)c; }
void ir_debug_local(const char *n, const char *s, const char *k, const char *t,
                    int f, int l, int a) {
    (void)n; (void)s; (void)k; (void)t; (void)f; (void)l; (void)a;
}
void ir_debug_global(const char *n, const char *k, const char *t, int f, int l) {
    (void)n; (void)k; (void)t; (void)f; (void)l;
}
void ir_debug_enum(const char *name, int f, int l) { (void)name; (void)f; (void)l; }
void ir_debug_struct(const char *name, int f, int l) { (void)name; (void)f; (void)l; }
void ir_debug_field_type(const char *o, const char *f, const char *t) {
    (void)o; (void)f; (void)t;
}

#endif // PRISMIO_DWARF

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
