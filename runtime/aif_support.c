// ============================================================================
// AIF — the inference engine's data structures and fixed point.
//
// AIF (aif/) is Prismio's memory model. The engine assigns every allocation
// site a tier T0-T4 from four inferred fact domains, and this file holds
// everything iteration needs: the scope forest, the site table, the points-to
// graph, the constraint list, and the solver loop itself.
//
// WHY THIS IS IN C. The policy lives in src/aif.psm -- which nodes become
// sites, which transfer rule fires where, what an extern's ownership contract
// is, how a tier becomes a manifest line. None of that is here. What is here is
// the container layer: growable bitsets, an interning table, and a hash map
// from key tuples to ids. Prismio has no generics, no maps and no growable
// vectors (aif/implementation/COMPILER-AUDIT.md 4.3 calls this the finding that
// most changes the schedule), so the engine would otherwise be written with
// parallel arrays and integer indices -- in the one component where a silent
// bug yields a wrong-tier binary rather than a crash.
//
// This is the same split ir_symbols.c already makes for the symbol tables, and
// it is deliberate rather than expedient: the compiler is written in Prismio,
// its containers are written in C.
//
// SOUNDNESS NOTE. Every fact here only ever *rises* (INFERENCE.md M2). No
// operation in this file lowers E, A or C, which is what makes the iteration
// monotone, terminating, and safe to abandon -- see aif_widen().
// ============================================================================

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static void aif_oom(const char* what) {
    fprintf(stderr, "internal error: out of memory growing %s\n", what);
    fflush(stderr);
    exit(1);
}

static void* xmalloc(size_t n, const char* what) {
    void* p = malloc(n);
    if (!p) aif_oom(what);
    return p;
}

static void* xcalloc(size_t n, size_t sz, const char* what) {
    void* p = calloc(n ? n : 1, sz);
    if (!p) aif_oom(what);
    return p;
}

static void* xrealloc(void* p, size_t n, const char* what) {
    void* q = realloc(p, n);
    if (!q) aif_oom(what);
    return q;
}

// ============================================================================
// Fact encodings
//
// Escape is a single int so that it fits an array slot and a Prismio `Int`
// alike: the two top elements are negative, and every Region(s) is the scope id
// itself. The ordering Region(s) < Caller < Global is not the integer ordering
// -- escape_join() implements it.
// ============================================================================

#define AIF_E_GLOBAL (-2)
#define AIF_E_CALLER (-1)

#define AIF_A_UNIQUE   0
#define AIF_A_BORROWED 1
#define AIF_A_SHARED   2

#define AIF_C_ACYCLIC 0
#define AIF_C_MAYBE   1

// Site kinds. Mirrors what src/aif.psm classifies a type as; the solver only
// cares that kind 0 is a struct (the T0 clause and the copy rule both test it).
#define AIF_K_STRUCT 0
#define AIF_K_STRING 1
#define AIF_K_ARRAY  2
#define AIF_K_LIST   3
#define AIF_K_OPAQUE 4

// ============================================================================
// Growable bitsets
//
// Both halves of the solver state are sets of small integers: a points-to node
// holds a set of sites, and a site holds the set of nodes referencing it.
// Bitsets make union and subset one word-loop each, which keeps the round cost
// proportional to the graph rather than to the constraint list.
// ============================================================================

typedef unsigned long long Word;
#define WORD_BITS 64

typedef struct {
    Word* w;
    int nwords;
} Bits;

static void bits_ensure(Bits* b, int bit, const char* what) {
    int need = bit / WORD_BITS + 1;
    if (need <= b->nwords) return;
    int grow = b->nwords ? b->nwords * 2 : 8;
    if (grow < need) grow = need;
    b->w = (Word*)xrealloc(b->w, (size_t)grow * sizeof(Word), what);
    memset(b->w + b->nwords, 0, (size_t)(grow - b->nwords) * sizeof(Word));
    b->nwords = grow;
}

static int bits_test(const Bits* b, int bit) {
    int wi = bit / WORD_BITS;
    if (bit < 0 || wi >= b->nwords) return 0;
    return (int)((b->w[wi] >> (bit % WORD_BITS)) & 1u);
}

// Returns 1 only when the bit was absent. The solver's `changed` flag is the
// disjunction of every such return, so an update that adds nothing must report
// nothing -- otherwise the loop never terminates.
static int bits_set(Bits* b, int bit, const char* what) {
    bits_ensure(b, bit, what);
    int wi = bit / WORD_BITS;
    Word m = (Word)1 << (bit % WORD_BITS);
    if (b->w[wi] & m) return 0;
    b->w[wi] |= m;
    return 1;
}

static void bits_clear(Bits* b) {
    if (b->nwords) memset(b->w, 0, (size_t)b->nwords * sizeof(Word));
}

// dst |= src, reporting whether dst grew.
static int bits_or(Bits* dst, const Bits* src, const char* what) {
    int changed = 0;
    for (int i = 0; i < src->nwords; i++) {
        if (!src->w[i]) continue;
        bits_ensure(dst, i * WORD_BITS, what);
        Word before = dst->w[i];
        Word after = before | src->w[i];
        if (after != before) {
            dst->w[i] = after;
            changed = 1;
        }
    }
    return changed;
}

static int bits_count_at_least_two(const Bits* b) {
    int seen = 0;
    for (int i = 0; i < b->nwords; i++) {
        Word x = b->w[i];
        while (x) {
            x &= x - 1;
            if (++seen >= 2) return 1;
        }
    }
    return 0;
}

static void bits_free(Bits* b) {
    free(b->w);
    b->w = NULL;
    b->nwords = 0;
}

// ============================================================================
// Int vectors
//
// Set membership is a bitset, but the solver's rules need to *enumerate* a set,
// sometimes two of them nested. Materialising a bitset into a plain int array
// keeps that a pair of ordinary loops. The buffers are reused across rounds,
// so this allocates a handful of times for the whole run.
// ============================================================================

typedef struct {
    int* v;
    int len, cap;
} IntVec;

static void vec_push(IntVec* iv, int x, const char* what) {
    if (iv->len == iv->cap) {
        iv->cap = iv->cap ? iv->cap * 2 : 64;
        iv->v = (int*)xrealloc(iv->v, (size_t)iv->cap * sizeof(int), what);
    }
    iv->v[iv->len++] = x;
}

// Portable count-trailing-zeros. A branchless intrinsic exists on every
// compiler that matters and on none of them by the same name, and this runs
// once per set bit rather than once per word, so a six-step binary search costs
// nothing measurable next to the round it sits inside.
static int ctz64(Word x) {
    int n = 0;
    if (!(x & 0xFFFFFFFFull)) { x >>= 32; n += 32; }
    if (!(x & 0xFFFFull))     { x >>= 16; n += 16; }
    if (!(x & 0xFFull))       { x >>= 8;  n += 8;  }
    if (!(x & 0xFull))        { x >>= 4;  n += 4;  }
    if (!(x & 0x3ull))        { x >>= 2;  n += 2;  }
    if (!(x & 0x1ull))        { n += 1; }
    return n;
}

static void bits_to_vec(const Bits* b, IntVec* out) {
    out->len = 0;
    for (int wi = 0; wi < b->nwords; wi++) {
        for (Word x = b->w[wi]; x; x &= x - 1) {
            vec_push(out, wi * WORD_BITS + ctz64(x), "AIF bit enumeration");
        }
    }
}

// ============================================================================
// String interning
//
// Type names, field names and variable names all become integer ids, because
// every key in the points-to graph is a tuple of small integers and comparing
// tuples of ints is what makes the key map cheap. Id 0 is always "".
// ============================================================================

#define AIF_INTERN_BUCKETS 8192

typedef struct InternNode {
    struct InternNode* next;
    unsigned hash;
    int id;
    char text[1];   // over-allocated to hold the whole name
} InternNode;

static InternNode* intern_buckets[AIF_INTERN_BUCKETS];
static const char** intern_by_id;
static int intern_count, intern_cap;

static unsigned hash_str(const char* s) {
    unsigned h = 2166136261u;   // FNV-1a
    while (*s) {
        h ^= (unsigned char)*s++;
        h *= 16777619u;
    }
    return h;
}

int aif_intern(const char* s) {
    if (!s) s = "";
    unsigned h = hash_str(s);
    unsigned bucket = h & (AIF_INTERN_BUCKETS - 1);

    for (InternNode* n = intern_buckets[bucket]; n; n = n->next) {
        if (n->hash == h && strcmp(n->text, s) == 0) return n->id;
    }

    size_t len = strlen(s);
    InternNode* n = (InternNode*)xmalloc(sizeof(InternNode) + len, "AIF interned names");
    memcpy(n->text, s, len + 1);
    n->hash = h;
    n->next = intern_buckets[bucket];
    intern_buckets[bucket] = n;

    if (intern_count == intern_cap) {
        intern_cap = intern_cap ? intern_cap * 2 : 256;
        intern_by_id = (const char**)xrealloc(intern_by_id,
            (size_t)intern_cap * sizeof(char*), "AIF name index");
    }
    n->id = intern_count;
    intern_by_id[intern_count++] = n->text;
    return n->id;
}

const char* aif_str(int id) {
    if (id < 0 || id >= intern_count) return "";
    return intern_by_id[id];
}

// ============================================================================
// Scope forest
//
// Each function body is a root; a block nests inside its parent. The join of
// two Region values is their least common ancestor, which exists because scopes
// nest (INFERENCE 2.1). Scopes in different functions have no common region --
// scope_lca reports -1 and escape_join falls back to Caller.
// ============================================================================

typedef struct {
    int parent;
    int depth;
    int owner;      // function id
    // SPEC 5.2. -1 unless a `region` statement opened this scope, in which case
    // it is the interned name -- which is what the manifest's `region:<name>`
    // placement reports, and how codegen knows an arena is live here.
    int region_name;
    // LAYOUT 7.1. Set by aif_place_arenas when the cost model chooses this scope,
    // or unconditionally when `region` pinned it. Codegen reads it through the
    // block node to know where to bracket arena_push/arena_pop.
    int arena;
    // How many loops enclose this scope, within its function. The weight a site
    // contributes to its arena's benefit is one allocation per entry of the
    // arena, times the trip count of every loop between them.
    int loop_depth;
    const void* node;   // the BLOCK this scope came from, for the codegen lookup
} Scope;

static Scope* scopes;
static int scope_count, scope_cap;

int aif_scope_new(int parent, int owner) {
    if (scope_count == scope_cap) {
        scope_cap = scope_cap ? scope_cap * 2 : 256;
        scopes = (Scope*)xrealloc(scopes, (size_t)scope_cap * sizeof(Scope), "AIF scopes");
    }
    Scope* s = &scopes[scope_count];
    s->parent = parent;
    s->owner = owner;
    s->depth = (parent < 0) ? 0 : scopes[parent].depth + 1;
    s->region_name = -1;
    s->arena = 0;
    s->loop_depth = 0;
    s->node = NULL;
    return scope_count++;
}

void aif_scope_set_region(int scope, const char* name) {
    if (scope < 0 || scope >= scope_count) return;
    scopes[scope].region_name = aif_intern(name);
    // SPEC 5.2: `region` is a pin on the placement decision, not an input to it.
    // The cost model never sees this scope -- it is guaranteed an arena whether
    // or not the model would have chosen one, and the manifest records that.
    scopes[scope].arena = 1;
}

void aif_scope_set_loop_depth(int scope, int depth) {
    if (scope < 0 || scope >= scope_count) return;
    scopes[scope].loop_depth = depth < 0 ? 0 : depth;
}

void aif_scope_note_node(int scope, const void* node) {
    if (scope < 0 || scope >= scope_count) return;
    scopes[scope].node = node;
}

int aif_scope_count(void) { return scope_count; }

static int scope_lca(int a, int b) {
    if (a < 0 || b < 0 || a >= scope_count || b >= scope_count) return -1;
    if (scopes[a].owner != scopes[b].owner) return -1;
    while (scopes[a].depth > scopes[b].depth) a = scopes[a].parent;
    while (scopes[b].depth > scopes[a].depth) b = scopes[b].parent;
    while (a != b) {
        a = scopes[a].parent;
        b = scopes[b].parent;
        if (a < 0 || b < 0) return -1;
    }
    return a;
}

// Least upper bound on Region(s) < Caller < Global.
static int escape_join(int x, int y) {
    if (x == AIF_E_GLOBAL || y == AIF_E_GLOBAL) return AIF_E_GLOBAL;
    if (x == AIF_E_CALLER || y == AIF_E_CALLER) return AIF_E_CALLER;
    int m = scope_lca(x, y);
    return (m < 0) ? AIF_E_CALLER : m;
}

// ============================================================================
// Functions
// ============================================================================

typedef struct {
    int symbol;     // interned mangled symbol -- the identity
    int name;       // interned plain name
    int file;
    int sealed;     // no visible body: analysed like an FFI call (PIR 5)
    int nsites;     // running count, so each site gets a stable ordinal
} Fn;

static Fn* fns;
static int fn_count, fn_cap;

// Interned symbol id -> function id, -1 where the string is not a function
// symbol. Sparse and grown on demand, which beats a second hash table.
static int* fn_by_symbol;
static int fn_by_symbol_cap;

static void fn_index_put(int symbol, int fid) {
    if (symbol >= fn_by_symbol_cap) {
        int grow = fn_by_symbol_cap ? fn_by_symbol_cap * 2 : 1024;
        if (grow <= symbol) grow = symbol + 1;
        fn_by_symbol = (int*)xrealloc(fn_by_symbol, (size_t)grow * sizeof(int),
                                      "AIF function index");
        for (int i = fn_by_symbol_cap; i < grow; i++) fn_by_symbol[i] = -1;
        fn_by_symbol_cap = grow;
    }
    fn_by_symbol[symbol] = fid;
}

int aif_fn_new(const char* symbol, const char* name, int file) {
    int sym = aif_intern(symbol);
    if (sym < fn_by_symbol_cap && fn_by_symbol[sym] >= 0) return fn_by_symbol[sym];

    if (fn_count == fn_cap) {
        fn_cap = fn_cap ? fn_cap * 2 : 256;
        fns = (Fn*)xrealloc(fns, (size_t)fn_cap * sizeof(Fn), "AIF functions");
    }
    Fn* f = &fns[fn_count];
    f->symbol = sym;
    f->name = aif_intern(name);
    f->file = file;
    f->sealed = 0;
    f->nsites = 0;
    fn_index_put(sym, fn_count);
    return fn_count++;
}

int aif_fn_lookup(const char* symbol) {
    int sym = aif_intern(symbol);
    if (sym >= fn_by_symbol_cap) return -1;
    return fn_by_symbol[sym];
}

int aif_fn_count(void) { return fn_count; }
const char* aif_fn_symbol(int f) { return (f < 0 || f >= fn_count) ? "" : aif_str(fns[f].symbol); }
const char* aif_fn_name(int f)   { return (f < 0 || f >= fn_count) ? "" : aif_str(fns[f].name); }
int aif_fn_file(int f)           { return (f < 0 || f >= fn_count) ? 0 : fns[f].file; }
void aif_fn_seal(int f)          { if (f >= 0 && f < fn_count) fns[f].sealed = 1; }
int aif_fn_is_sealed(int f)      { return (f < 0 || f >= fn_count) ? 0 : fns[f].sealed; }

// ============================================================================
// Nominal types
//
// Structs carry a field count (the T0/T1 size proxy -- see aif_tier_of) and an
// edge set for the type reference graph. Enums are recorded only so the
// frontend can exclude them: an enum is an i32 and participates in no memory
// model.
// ============================================================================

typedef struct {
    int name;
    int nfields;
    int bytes;          // 0 until the frontend computes a layout for it
    int is_enum;
    Bits reaches;       // direct edges, then closed transitively
    int acyclic;
} Nominal;

static Nominal* nominals;
static int nominal_count, nominal_cap;
static int* nominal_by_name;
static int nominal_by_name_cap;

static void nominal_index_put(int name, int id) {
    if (name >= nominal_by_name_cap) {
        int grow = nominal_by_name_cap ? nominal_by_name_cap * 2 : 1024;
        if (grow <= name) grow = name + 1;
        nominal_by_name = (int*)xrealloc(nominal_by_name, (size_t)grow * sizeof(int),
                                         "AIF type index");
        for (int i = nominal_by_name_cap; i < grow; i++) nominal_by_name[i] = -1;
        nominal_by_name_cap = grow;
    }
    nominal_by_name[name] = id;
}

static int nominal_find_id(int name) {
    if (name < 0 || name >= nominal_by_name_cap) return -1;
    return nominal_by_name[name];
}

static int nominal_find(const char* name) {
    return nominal_find_id(aif_intern(name));
}

static int nominal_intern(const char* name, int is_enum) {
    int existing = nominal_find(name);
    if (existing >= 0) return existing;

    if (nominal_count == nominal_cap) {
        nominal_cap = nominal_cap ? nominal_cap * 2 : 64;
        nominals = (Nominal*)xrealloc(nominals, (size_t)nominal_cap * sizeof(Nominal),
                                      "AIF nominal types");
    }
    Nominal* t = &nominals[nominal_count];
    t->name = aif_intern(name);
    t->nfields = 0;
    t->bytes = 0;
    t->is_enum = is_enum;
    t->reaches.w = NULL;
    t->reaches.nwords = 0;
    t->acyclic = 1;
    nominal_index_put(t->name, nominal_count);
    return nominal_count++;
}

void aif_struct_new(const char* name) { nominal_intern(name, 0); }
void aif_enum_new(const char* name)   { nominal_intern(name, 1); }

int aif_is_struct(const char* name) {
    int id = nominal_find(name);
    return (id >= 0 && !nominals[id].is_enum) ? 1 : 0;
}

int aif_is_enum(const char* name) {
    int id = nominal_find(name);
    return (id >= 0 && nominals[id].is_enum) ? 1 : 0;
}

int aif_struct_nfields(const char* name) {
    int id = nominal_find(name);
    return (id >= 0) ? nominals[id].nfields : 0;
}

void aif_struct_add_field(const char* name) {
    nominals[nominal_intern(name, 0)].nfields++;
}

// The frontend computes this from the field types once every type is known.
// It is here rather than derived here because AIF-1's layout *is* declaration
// order (SPEC 8.2 gives the compiler layout freedom; AIF-1 does not use it), and
// the frontend is what knows what a field's type lowers to.
void aif_struct_set_size(const char* name, int bytes) {
    nominals[nominal_intern(name, 0)].bytes = bytes;
}

int aif_struct_size(const char* name) {
    int id = nominal_find(name);
    return (id >= 0) ? nominals[id].bytes : 0;
}

// One edge of the type reference graph (INFERENCE 4.4 stage 1). The frontend
// walks each field's type annotation and reports every nominal type it can
// reach, so `List<Node>` and `[Node]` both produce an edge to Node -- the
// element is reachable from the container whatever the container is.
void aif_type_edge(const char* from, const char* to) {
    int a = nominal_find(from);
    int b = nominal_find(to);
    if (a < 0 || b < 0) return;
    bits_set(&nominals[a].reaches, b, "AIF type graph");
}

// Transitive closure, then: a type is cyclic when it reaches itself, or reaches
// anything that reaches itself. Acyclic is the complement.
//
// Closure rather than Tarjan because the graph has one node per nominal type --
// tens, not thousands -- so an O(n^3/64) fixpoint is free and has no recursion
// depth to get wrong.
void aif_compute_type_acyclic(void) {
    int changed = 1;
    while (changed) {
        changed = 0;
        for (int t = 0; t < nominal_count; t++) {
            for (int u = 0; u < nominal_count; u++) {
                if (!bits_test(&nominals[t].reaches, u)) continue;
                if (bits_or(&nominals[t].reaches, &nominals[u].reaches, "AIF type graph")) {
                    changed = 1;
                }
            }
        }
    }

    for (int t = 0; t < nominal_count; t++) {
        int cyclic = bits_test(&nominals[t].reaches, t);
        for (int u = 0; !cyclic && u < nominal_count; u++) {
            if (bits_test(&nominals[t].reaches, u) && bits_test(&nominals[u].reaches, u)) {
                cyclic = 1;
            }
        }
        nominals[t].acyclic = !cyclic;
    }
}

// Unknown types report acyclic. They are scalars and externs' opaque returns --
// none of which can hold a reference back into the program, so there is nothing
// for them to be part of a cycle with.
static int type_acyclic_id(int name) {
    int id = nominal_find_id(name);
    return (id < 0) ? 1 : nominals[id].acyclic;
}

int aif_type_acyclic(const char* name) { return type_acyclic_id(aif_intern(name)); }

int aif_nominal_count(void) { return nominal_count; }
const char* aif_nominal_name(int i) { return (i < 0 || i >= nominal_count) ? "" : aif_str(nominals[i].name); }
int aif_nominal_is_struct(int i)    { return (i < 0 || i >= nominal_count) ? 0 : !nominals[i].is_enum; }
int aif_nominal_acyclic(int i)      { return (i < 0 || i >= nominal_count) ? 1 : nominals[i].acyclic; }

// ============================================================================
// Allocation sites
// ============================================================================

typedef struct {
    int type;       // interned type display name
    int kind;
    int fn;
    int ordinal;    // position among its function's sites, in walk order
    int scope;
    int file, line, col;
    int nfields;
    int bytes;          // stamped once, before iteration
    int E, A, C;
    int type_acyclic;   // stamped once, before iteration
    int no_stack;       // explicitly dropped -- see AIF_CON_NO_STACK
    // SPEC 5.1. `unique` asserts A = Unique and cuts the aliasing graph: a rule
    // that would raise A above Unique is suppressed rather than applied.
    int alias_axiom;
    int alias_suppressed;   // the axiom actually stopped a rule; reported
    // SPEC 5.4. The tier a `pin` froze, or -1. Applied after convergence.
    int pin_tier;
    int pin_verdict;        // AIF_PIN_*, decided by aif_check_pins
} Site;

// SPEC 5.4's four outcomes, plus "there is no pin here".
#define AIF_PIN_NONE     0
#define AIF_PIN_HONOURED 1
#define AIF_PIN_REFUTED  2   // converged facts make it unreachable -- an error
#define AIF_PIN_UNPROVEN 3   // budget ran out -- a warning, and the pin is dropped

static Site* sites;
static int site_count, site_cap;
static int orphan_sites;    // sites with no enclosing function; none today

int aif_site_new(const char* type, int kind, int fn, int scope,
                 int file, int line, int col, int nfields) {
    if (site_count == site_cap) {
        site_cap = site_cap ? site_cap * 2 : 1024;
        sites = (Site*)xrealloc(sites, (size_t)site_cap * sizeof(Site), "AIF sites");
    }
    Site* s = &sites[site_count];
    s->type = aif_intern(type);
    s->kind = kind;
    s->fn = fn;
    // The manifest is diffed, so a record's name must not move when an
    // unrelated line elsewhere in the file does. Numbering within the declaring
    // function gives that: an edit is visible on the function it changed and
    // nowhere else.
    s->ordinal = (fn >= 0 && fn < fn_count) ? fns[fn].nsites++ : orphan_sites++;
    s->scope = scope;
    s->file = file;
    s->line = line;
    s->col = col;
    s->nfields = nfields;
    s->bytes = 0;
    s->type_acyclic = 1;
    s->no_stack = 0;
    s->alias_axiom = 0;
    s->alias_suppressed = 0;
    s->pin_tier = -1;
    s->pin_verdict = AIF_PIN_NONE;
    // Bottom, per INFERENCE 5.2 line 2: Region(defscope), Unique, Acyclic.
    s->E = scope;
    s->A = AIF_A_UNIQUE;
    s->C = AIF_C_ACYCLIC;
    return site_count++;
}

int aif_site_count(void) { return site_count; }

const char* aif_site_type(int id) { return (id < 0 || id >= site_count) ? "" : aif_str(sites[id].type); }
int aif_site_kind(int id)    { return (id < 0 || id >= site_count) ? AIF_K_OPAQUE : sites[id].kind; }
int aif_site_fn(int id)      { return (id < 0 || id >= site_count) ? -1 : sites[id].fn; }
int aif_site_scope(int id)   { return (id < 0 || id >= site_count) ? -1 : sites[id].scope; }
int aif_site_file(int id)    { return (id < 0 || id >= site_count) ? 0 : sites[id].file; }
int aif_site_line(int id)    { return (id < 0 || id >= site_count) ? 0 : sites[id].line; }
int aif_site_col(int id)     { return (id < 0 || id >= site_count) ? 0 : sites[id].col; }
int aif_site_nfields(int id) { return (id < 0 || id >= site_count) ? 0 : sites[id].nfields; }
int aif_site_ordinal(int id) { return (id < 0 || id >= site_count) ? 0 : sites[id].ordinal; }
int aif_site_escape(int id)  { return (id < 0 || id >= site_count) ? AIF_E_GLOBAL : sites[id].E; }
int aif_site_alias(int id)   { return (id < 0 || id >= site_count) ? AIF_A_SHARED : sites[id].A; }
int aif_site_cyc(int id)     { return (id < 0 || id >= site_count) ? AIF_C_MAYBE : sites[id].C; }

// ============================================================================
// Points-to keys
//
// A key names a location that can hold references: a local binding, a struct
// field (field-sensitive, object-insensitive -- INFERENCE 3.1), a return
// position, or a parameter. Identity is the tuple, so the same name in two
// functions is two keys, and `Lexer.source` is one key across every Lexer.
// ============================================================================

#define AIF_KEY_VAR    0
#define AIF_KEY_FIELD  1
#define AIF_KEY_RET    2
#define AIF_KEY_PARAM  3
#define AIF_KEY_EXTERN 4

#define AIF_KEY_BUCKETS 16384

typedef struct KeyNode {
    struct KeyNode* next;
    int kind, a, b;
    int id;
} KeyNode;

static KeyNode* key_buckets[AIF_KEY_BUCKETS];
static int key_count;

static int key_intern(int kind, int a, int b) {
    unsigned h = (unsigned)kind * 2654435761u
               ^ (unsigned)a * 40503u
               ^ (unsigned)b * 2246822519u;
    unsigned bucket = h & (AIF_KEY_BUCKETS - 1);
    for (KeyNode* n = key_buckets[bucket]; n; n = n->next) {
        if (n->kind == kind && n->a == a && n->b == b) return n->id;
    }
    KeyNode* n = (KeyNode*)xmalloc(sizeof(KeyNode), "AIF points-to keys");
    n->kind = kind;
    n->a = a;
    n->b = b;
    n->id = key_count++;
    n->next = key_buckets[bucket];
    key_buckets[bucket] = n;
    return n->id;
}

int aif_key_var(int fn, const char* name)            { return key_intern(AIF_KEY_VAR, fn, aif_intern(name)); }

// ---------------------------------------------------------------------------
// Declaring scopes
//
// E-BIND needs the scope a *variable* was declared in, not the scope the
// assignment sits in. Without it a value created inside a loop and assigned to a
// binding declared outside keeps the loop body's escape -- which reads as "dies
// at the end of this iteration" and is false, because the outer binding still
// refers to it on the next one.
//
// At Level 0 that was invisible: every tier is semantically valid and nothing
// allocated differently. It stops being invisible the moment T0 emits one
// hoisted alloca per site and every iteration writes the same slot.
//
// Shadowing joins outward. Two declarations of one name in sibling blocks join
// to their least common ancestor, which is at least as long-lived as either, so
// the answer is conservative rather than dependent on which the walk saw last.
// ---------------------------------------------------------------------------

static int* var_scope;
static int var_scope_cap;

static void var_scope_grow(int key) {
    if (key < var_scope_cap) return;
    int grow = var_scope_cap ? var_scope_cap * 2 : 1024;
    if (grow <= key) grow = key + 1;
    var_scope = (int*)xrealloc(var_scope, (size_t)grow * sizeof(int), "AIF declaring scopes");
    for (int i = var_scope_cap; i < grow; i++) var_scope[i] = -1;
    var_scope_cap = grow;
}

void aif_var_note_scope(int fn, const char* name, int scope) {
    int key = aif_key_var(fn, name);
    var_scope_grow(key);
    if (var_scope[key] < 0) {
        var_scope[key] = scope;
        return;
    }
    int m = scope_lca(var_scope[key], scope);
    if (m >= 0) var_scope[key] = m;
}

// -1 when the name has no declaration on record -- a global, or an assignment
// the walk reached before the declaration. The caller falls back to the
// assignment's own scope, which is what this function replaced.
int aif_var_scope(int fn, const char* name) {
    int key = aif_key_var(fn, name);
    return (key < var_scope_cap) ? var_scope[key] : -1;
}
int aif_key_field(const char* type, const char* fld) { return key_intern(AIF_KEY_FIELD, aif_intern(type), aif_intern(fld)); }
int aif_key_ret(int fn)                              { return key_intern(AIF_KEY_RET, fn, 0); }
int aif_key_param(int fn, int index)                 { return key_intern(AIF_KEY_PARAM, fn, index); }
int aif_key_count(void)                              { return key_count; }

// ---------------------------------------------------------------------------
// Declared FFI contracts
//
// What an `extern` declaration says about ownership (FFI 5), keyed by the
// callee's name and a parameter index. Index -1 holds the return contract and
// -2 marks the name as declared at all.
//
// Keyed through the same tuple map as everything else, so a contract lookup at a
// call site is one hash rather than a scan over declarations.
// ---------------------------------------------------------------------------

static int* extern_contract;    // key id -> interned contract text, -1 unset
static int extern_contract_cap;

static void extern_contract_grow(int key) {
    if (key < extern_contract_cap) return;
    int grow = extern_contract_cap ? extern_contract_cap * 2 : 1024;
    if (grow <= key) grow = key + 1;
    extern_contract = (int*)xrealloc(extern_contract, (size_t)grow * sizeof(int),
                                     "AIF extern contracts");
    for (int i = extern_contract_cap; i < grow; i++) extern_contract[i] = -1;
    extern_contract_cap = grow;
}

void aif_extern_contract_set(const char* fn, int index, const char* contract) {
    int key = key_intern(AIF_KEY_EXTERN, aif_intern(fn), index);
    extern_contract_grow(key);
    extern_contract[key] = aif_intern(contract);
}

// "" when nothing was declared, which the frontend reads as "fall through to the
// default" rather than as a contract in its own right.
const char* aif_extern_contract(const char* fn, int index) {
    int key = key_intern(AIF_KEY_EXTERN, aif_intern(fn), index);
    if (key >= extern_contract_cap || extern_contract[key] < 0) return "";
    return aif_str(extern_contract[key]);
}

// ============================================================================
// Value-set expressions
//
// The set of sites an expression may denote: part known while walking (a struct
// literal is its own site), part only at the fixed point (an identifier is
// whatever its binding points to). Holding both in one object is what lets the
// AST walk compose expressions uniformly without knowing which it has.
//
// Items are tagged integers -- an even item is a site, an odd item is a key.
// ============================================================================

typedef struct {
    int* items;
    int len, cap;
} ValueSet;

static ValueSet* vsets;
static int vs_count, vs_cap;

int aif_vs_new(void) {
    if (vs_count == vs_cap) {
        vs_cap = vs_cap ? vs_cap * 2 : 1024;
        vsets = (ValueSet*)xrealloc(vsets, (size_t)vs_cap * sizeof(ValueSet), "AIF value sets");
    }
    ValueSet* v = &vsets[vs_count];
    v->items = NULL;
    v->len = 0;
    v->cap = 0;
    return vs_count++;
}

static void vs_push(int vs, int item) {
    if (vs < 0 || vs >= vs_count) return;
    ValueSet* v = &vsets[vs];
    for (int i = 0; i < v->len; i++) {
        if (v->items[i] == item) return;
    }
    if (v->len == v->cap) {
        v->cap = v->cap ? v->cap * 2 : 4;
        v->items = (int*)xrealloc(v->items, (size_t)v->cap * sizeof(int), "AIF value set");
    }
    v->items[v->len++] = item;
}

void aif_vs_site(int vs, int site) { vs_push(vs, site * 2); }
void aif_vs_key(int vs, int key)   { vs_push(vs, key * 2 + 1); }

int aif_vs_is_empty(int vs) {
    return (vs < 0 || vs >= vs_count) ? 1 : (vsets[vs].len == 0);
}

int aif_vs_union(int a, int b) {
    int out = aif_vs_new();
    if (a >= 0 && a < vs_count) {
        for (int i = 0; i < vsets[a].len; i++) vs_push(out, vsets[a].items[i]);
    }
    if (b >= 0 && b < vs_count) {
        for (int i = 0; i < vsets[b].len; i++) vs_push(out, vsets[b].items[i]);
    }
    return out;
}

// ============================================================================
// Argument stacks
//
// Two FFI contracts refer to another argument of the same call: `retain_in(k)`
// says "the callee stores me into argument k", and `alias` says "my return is
// argument k". Both need the call's arguments addressable by index while it is
// being walked -- and calls nest, because an argument can itself be a call.
//
// Evaluating an argument creates allocation sites, so it must happen exactly
// once; re-walking to find argument k would duplicate every site inside it.
// Hence a stack: the frontend opens a frame, pushes each argument's value set
// as it evaluates it, indexes freely, and closes the frame.
// ============================================================================

static IntVec argv;

int aif_argv_begin(void) { return argv.len; }

void aif_argv_push(int vs) { vec_push(&argv, vs, "AIF call arguments"); }

int aif_argv_count(int base) { return argv.len - base; }

// Out of range yields -1, which every consumer reads as the empty value set --
// a contract naming an argument the call does not have contributes nothing.
int aif_argv_get(int base, int i) {
    int at = base + i;
    if (i < 0 || at >= argv.len) return -1;
    return argv.v[at];
}

void aif_argv_end(int base) { argv.len = base; }

// ============================================================================
// Constraints
//
// One entry per transfer-rule instance the AST walk discovered. Solving is
// re-applying all of them until nothing rises.
// ============================================================================

#define AIF_CON_BIND          0
#define AIF_CON_ARG           1
#define AIF_CON_STORE         2
#define AIF_CON_LIVE_IN       3
#define AIF_CON_OPAQUE        4
#define AIF_CON_RETAIN_IN     5
#define AIF_CON_BORROW        6
#define AIF_CON_ESCAPE_CALLER 7
#define AIF_CON_ESCAPE_GLOBAL 8
#define AIF_CON_NO_STACK      9
// SPEC 5's annotations. Neither is a transfer rule: both are applied once,
// between the points-to fixed point and the fact loop, because an axiom that
// arrives mid-iteration would only cut what had not already been raised.
#define AIF_CON_UNIQUE       10
#define AIF_CON_PIN          11
// Not constraints: the two rules that read a site's own state rather than an
// incoming edge. They still need names, because a witness path that ends at one
// has to say so rather than reporting "no cause".
#define AIF_RULE_A_ESCAPE    12
#define AIF_RULE_A_COPY      13
#define AIF_RULE_ALLOC       14   // the root: this is where the value is made

typedef struct {
    int kind, a, b, c;
    // Where in the source this constraint came from. Carried so a manifest diff
    // can name the store or the call that moved a fact (SPEC 6.3's example puts
    // a file:line on every edge of the witness path), not just which rule fired.
    int file, line, col;
} Constraint;

static Constraint* cons;
static int con_count, con_cap;
static int con_file, con_line, con_col;

static void con_add(int kind, int a, int b, int c) {
    if (con_count == con_cap) {
        con_cap = con_cap ? con_cap * 2 : 4096;
        cons = (Constraint*)xrealloc(cons, (size_t)con_cap * sizeof(Constraint), "AIF constraints");
    }
    cons[con_count].file = con_file;
    cons[con_count].line = con_line;
    cons[con_count].col = con_col;
    Constraint* k = &cons[con_count++];
    k->kind = kind;
    k->a = a;
    k->b = b;
    k->c = c;
}

void aif_con_bind(int key, int vs)              { con_add(AIF_CON_BIND, key, vs, 0); }
void aif_con_arg(int key, int vs)               { con_add(AIF_CON_ARG, key, vs, 0); }
void aif_con_store(int key, int vs, int owners) { con_add(AIF_CON_STORE, key, vs, owners); }
void aif_con_live_in(int vs, int scope, int fn) { con_add(AIF_CON_LIVE_IN, vs, scope, fn); }
void aif_con_opaque(int vs)                     { con_add(AIF_CON_OPAQUE, vs, 0, 0); }
void aif_con_retain_in(int vs, int holder)      { con_add(AIF_CON_RETAIN_IN, vs, holder, 0); }
void aif_con_borrow(int vs)                     { con_add(AIF_CON_BORROW, vs, 0, 0); }
void aif_con_escape_caller(int vs)              { con_add(AIF_CON_ESCAPE_CALLER, vs, 0, 0); }
void aif_con_escape_global(int vs)              { con_add(AIF_CON_ESCAPE_GLOBAL, vs, 0, 0); }
void aif_con_unique(int vs)                     { con_add(AIF_CON_UNIQUE, vs, 0, 0); }
void aif_con_pin(int vs, int tier)              { con_add(AIF_CON_PIN, vs, tier, 0); }

// `drop(x)` lowers to a free, and a stack slot is not a thing that can be freed.
// A T0 value has no allocation to release -- its storage *is* the frame -- so
// promoting a value the source explicitly drops turns a working program into
// heap corruption.
//
// This is not a fact about the value and deliberately does not touch E, A or C:
// an explicit drop says nothing about lifetime or aliasing, and distorting a
// fact domain to carry a codegen constraint would make the manifest lie about
// why. It suppresses the T0 clause and nothing else, so the value lands T1/T2 --
// heap-allocated, with something to free.
//
// The better answer is for `drop` on a T0 value to emit nothing at all, which
// needs codegen to resolve the tier of a *binding* at the drop site rather than
// the tier of an allocation at its literal. That wants COMPILER-AUDIT 4.1's node
// ids. Until then this is the sound direction to be wrong in.
void aif_con_no_stack(int vs)                   { con_add(AIF_CON_NO_STACK, vs, 0, 0); }

int aif_con_count(void) { return con_count; }

// ============================================================================
// The fixed point
// ============================================================================

static Bits* pt;            // key id -> set of sites
static Bits* holders;       // site id -> set of keys holding it
static int pt_len, holders_len;
static Bits scratch_val, scratch_own;
static IntVec vec_val, vec_own;
static int solve_rounds;
static int pt_rounds;       // of solve_rounds, how many the points-to phase used

// Delta, in INFERENCE 5.3's sense: what moved in the round that just ran. On a
// truncated run that is the frontier the widening has to start from, so it is
// reset at the top of every round and only the last one's survives.
static Bits delta;          // sites whose facts moved
static int  delta_pt;       // did any points-to or holders set grow?
static Bits widened;        // sites aif_widen raised, for the manifest

// Whether collections are affine, i.e. whether the copy rule applies to them.
// Today's Prismio makes only structs move-only (types.psm); AIF specifies
// affine references for every heap value (SPEC 11 item 10). The difference is
// 100% of the measured T3 residue, so it is a switch rather than an assumption.
static int owned_collections;

void aif_set_owned_collections(int on) { owned_collections = on ? 1 : 0; }

// A move-only value can be held by several bindings over its lifetime without
// ever being aliased -- the move checker guarantees the earlier binding is dead
// -- so multiple holders means sequential ownership, not sharing. A copyable
// one has no such guarantee.
static int site_is_move_only(const Site* s) {
    if (s->kind == AIF_K_STRUCT) return 1;
    if (!owned_collections) return 0;
    return s->kind == AIF_K_STRING || s->kind == AIF_K_ARRAY || s->kind == AIF_K_LIST;
}

// ============================================================================
// The derivation DAG (INFERENCE 5.6, SPEC 6.3)
//
// A manifest diff has to answer *why* a tier moved, and the answer is a witness
// path from a root cause to the record. INFERENCE 5.6 specifies a backward BFS
// through **maximal contributors**: for a fact `f` at node `n` holding value
// `v`, the predecessors whose transfer produced `v`.
//
// Keeping every predecessor and searching backward is one way to get that. This
// keeps **one edge per site per domain** instead, written the moment a rule
// first raises the fact to the value it ends at -- which is a maximal
// contributor by construction, because a rule that raises is one that set the
// value rather than one that merely failed to contradict it. Walking those edges
// backward is then a chain rather than a search.
//
// Two honest consequences of that choice:
//
//   * The path is *a* witness, not provably the *shortest* one. The first rule
//     to reach the final value is recorded, which is the shortest among the
//     rules that fired in that round, but a different constraint order could
//     have produced a shorter chain. INFERENCE 5.1 permits the order to vary,
//     so "shortest" was never stable anyway.
//   * Memory is O(sites), not O(edges). 5.6's requirement is that the DAG be
//     *retained through tier assignment*, and one maximal edge per fact is
//     enough to retain what a diff reads back.
// ============================================================================

typedef struct {
    int rule;   // the AIF_CON_* that fired, or -1 for "never raised"
    int from;   // the site the value came from, or -1 for an axiom or a root
    int value;  // what it was raised to
    int file, line, col;
} Deriv;

static Deriv* deriv_e;      // why each site's E is what it is
static Deriv* deriv_a;      // and its A
static int cur_con = -1;    // the constraint being applied, for attribution
static int synth_rule = -1; // ...or the rule, when there is no constraint

// Where the constraint currently being *built* came from. Constraints are added
// during the walk, one node at a time, so a sticky position costs nothing and
// keeps ten aif_con_* signatures unchanged.
void aif_con_at(int file, int line, int col) {
    con_file = file;
    con_line = line;
    con_col = col;
}

static void note_deriv(Deriv* d, int site, int from, int value) {
    if (!d) return;
    int live = (cur_con >= 0 && cur_con < con_count);
    d[site].rule  = live ? cons[cur_con].kind : synth_rule;
    d[site].from  = from;
    d[site].value = value;
    d[site].file  = live ? cons[cur_con].file : sites[site].file;
    d[site].line  = live ? cons[cur_con].line : sites[site].line;
    d[site].col   = live ? cons[cur_con].col  : sites[site].col;
}


static void solver_alloc(void) {
    pt_len = key_count;
    holders_len = site_count;
    pt = (Bits*)xcalloc((size_t)pt_len, sizeof(Bits), "AIF points-to");
    holders = (Bits*)xcalloc((size_t)holders_len, sizeof(Bits), "AIF holders");
    // INFERENCE 5.6 requires the derivation be retained through tier assignment.
    deriv_e = (Deriv*)xcalloc((size_t)site_count, sizeof(Deriv), "AIF derivation (E)");
    deriv_a = (Deriv*)xcalloc((size_t)site_count, sizeof(Deriv), "AIF derivation (A)");
    for (int s = 0; s < site_count; s++) {
        // A site nothing ever raised is at its own allocation, which is the root
        // every witness path terminates at.
        deriv_e[s].rule = AIF_RULE_ALLOC;
        deriv_a[s].rule = AIF_RULE_ALLOC;
        deriv_e[s].from = -1;
        deriv_a[s].from = -1;
        // The bottom values, so a fact nothing ever raised still reports what it
        // is rather than whatever calloc left behind.
        deriv_e[s].value = sites[s].E;
        deriv_a[s].value = sites[s].A;
        deriv_e[s].file = deriv_a[s].file = sites[s].file;
        deriv_e[s].line = deriv_a[s].line = sites[s].line;
        deriv_e[s].col  = deriv_a[s].col  = sites[s].col;
    }
    for (int s = 0; s < site_count; s++) {
        sites[s].type_acyclic = type_acyclic_id(sites[s].type);
        int t = nominal_find_id(sites[s].type);
        sites[s].bytes = (t >= 0) ? nominals[t].bytes : 0;
    }
}

// Flatten a value-set expression against the current points-to state.
static void resolve(int vs, Bits* out) {
    bits_clear(out);
    if (vs < 0 || vs >= vs_count) return;
    ValueSet* v = &vsets[vs];
    for (int i = 0; i < v->len; i++) {
        int item = v->items[i];
        if (item & 1) {
            int key = item >> 1;
            if (key < pt_len) bits_or(out, &pt[key], "AIF resolve");
        } else {
            bits_set(out, item >> 1, "AIF resolve");
        }
    }
}

// Records the site in this round's delta and returns 1, so a rule reads
// `if (raise_alias(s, X)) changed = moved(s);`.
static int moved(int site) {
    bits_set(&delta, site, "AIF delta");
    return 1;
}

static int raise_escape(int site, int target, int from) {
    int j = escape_join(sites[site].E, target);
    if (j == sites[site].E) return 0;
    sites[site].E = j;
    note_deriv(deriv_e, site, from, j);
    return 1;
}

static int raise_alias(int site, int level, int from) {
    if (sites[site].A >= level) return 0;
    // SPEC 5.1: `unique` is an axiom, so the solver takes A = Unique as given
    // and does not propagate aliasing into the annotated binding. This is the
    // cut, and it is the whole mechanism -- an axiom that a rule could overrule
    // is not one.
    //
    // What makes it sound here rather than merely asserted is the language: a
    // second *owning* reference within the declaring scope is already a
    // compile error under affine collections, because taking one is a move and
    // using the original afterwards is `use of moved value`. So the local
    // verification SPEC 5.1 asks for is discharged by the move checker, and
    // what remains is the interprocedural half -- exactly what an axiom is for.
    // The suppression is recorded so the manifest can say which values rest on
    // the assertion.
    if (sites[site].alias_axiom && level > AIF_A_UNIQUE) {
        sites[site].alias_suppressed = 1;
        return 0;
    }
    sites[site].A = level;
    note_deriv(deriv_a, site, from, level);
    return 1;
}

// Iteration runs to full convergence, so by Kleene's theorem the result is the
// least fixed point regardless of the order constraints are applied in
// (INFERENCE 5.1 permits asynchronous iteration on exactly that condition).
// Order-independence is what licenses updating in place rather than
// double-buffering -- and it is why this engine's manifest must equal the
// Python oracle's, which applies the same constraints the same way.
//
// Returns 1 on convergence, 0 when the round budget ran out. A 0 return is NOT
// safe to assign tiers from: see aif_widen.
// Every rule that writes pt or holders reads only pt -- no fact feeds back into
// the points-to relation -- so its least fixed point is independent of the facts
// and reaching it first changes no answer. What it changes is the frontier:
// solved together, points-to is still growing when a budget bites, and a set
// that may still gain members this pass cannot name makes every site a possible
// successor. Separated, the fact phase always truncates over a final graph.
static int solve_points_to(int max_rounds) {
    for (int r = 0; r < max_rounds; r++) {
        solve_rounds++;
        int changed = 0;

        for (int ci = 0; ci < con_count; ci++) {
            Constraint* k = &cons[ci];
            if (k->kind != AIF_CON_BIND && k->kind != AIF_CON_ARG
                && k->kind != AIF_CON_STORE) {
                continue;
            }

            resolve(k->b, &scratch_val);
            if (bits_or(&pt[k->a], &scratch_val, "AIF points-to")) changed = 1;

            // Passing a value as an argument does not make the parameter a
            // holder of it, so ARG records none.
            if (k->kind == AIF_CON_ARG) continue;
            bits_to_vec(&scratch_val, &vec_val);
            for (int i = 0; i < vec_val.len; i++) {
                if (bits_set(&holders[vec_val.v[i]], k->a, "AIF holders")) changed = 1;
            }
        }

        if (!changed) return 1;
    }
    return 0;
}

int aif_solve(int max_rounds) {
    solver_alloc();
    solve_rounds = 0;

    if (!solve_points_to(max_rounds)) {
        delta_pt = 1;
        pt_rounds = solve_rounds;
        return 0;
    }
    pt_rounds = solve_rounds;

    // SPEC 5: annotations enter here, after points-to and before the facts.
    //
    // After, because a value set may name a variable rather than a site, and
    // resolving one needs the points-to relation. Before, because both are
    // statements about the *result*: an axiom applied mid-iteration would only
    // cut the rules that had not fired yet, which would make the answer depend
    // on constraint order -- and INFERENCE 5.1 lets the order vary.
    for (int ci = 0; ci < con_count; ci++) {
        Constraint* k = &cons[ci];
        if (k->kind != AIF_CON_UNIQUE && k->kind != AIF_CON_PIN) continue;
        resolve(k->a, &scratch_val);
        bits_to_vec(&scratch_val, &vec_val);
        for (int i = 0; i < vec_val.len; i++) {
            if (k->kind == AIF_CON_UNIQUE) {
                sites[vec_val.v[i]].alias_axiom = 1;
            } else if (k->b > sites[vec_val.v[i]].pin_tier) {
                // Two pins on one site is a program that annotated the same
                // allocation twice; the stricter reading is the more expensive
                // tier, which is the one that cannot be unsound.
                sites[vec_val.v[i]].pin_tier = k->b;
            }
        }
    }

    // Nothing has been proved about any site yet, so if the budget leaves no
    // round for the facts the frontier is the whole graph. Overwritten by the
    // first round that runs.
    for (int s = 0; s < site_count; s++) bits_set(&delta, s, "AIF delta");

    for (int r = solve_rounds; r < max_rounds; r++) {
        solve_rounds = r + 1;
        int changed = 0;
        bits_clear(&delta);
        delta_pt = 0;

        for (int ci = 0; ci < con_count; ci++) {
            Constraint* k = &cons[ci];
            cur_con = ci;

            if (k->kind == AIF_CON_BIND) {
                resolve(k->b, &scratch_val);
                if (bits_or(&pt[k->a], &scratch_val, "AIF points-to")) changed = delta_pt = 1;
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    if (bits_set(&holders[vec_val.v[i]], k->a, "AIF holders")) changed = delta_pt = 1;
                }

            } else if (k->kind == AIF_CON_ARG) {
                resolve(k->b, &scratch_val);
                if (bits_or(&pt[k->a], &scratch_val, "AIF points-to")) changed = delta_pt = 1;
                bits_to_vec(&scratch_val, &vec_val);
                // A-CALL: passing a value hands out a borrow of it.
                for (int i = 0; i < vec_val.len; i++) {
                    if (raise_alias(vec_val.v[i], AIF_A_BORROWED, -1)) changed = moved(vec_val.v[i]);
                }

            } else if (k->kind == AIF_CON_STORE) {
                resolve(k->b, &scratch_val);
                resolve(k->c, &scratch_own);
                if (bits_or(&pt[k->a], &scratch_val, "AIF points-to")) changed = delta_pt = 1;
                bits_to_vec(&scratch_val, &vec_val);
                bits_to_vec(&scratch_own, &vec_own);
                for (int i = 0; i < vec_val.len; i++) {
                    int s = vec_val.v[i];
                    if (bits_set(&holders[s], k->a, "AIF holders")) changed = delta_pt = 1;
                    for (int j = 0; j < vec_own.len; j++) {
                        int o = vec_own.v[j];
                        // E-STORE: reachable from the container, so it lives at
                        // least as long as the container does.
                        if (raise_escape(s, sites[o].E, o)) changed = moved(s);
                        // A-STORE: sharing is inherited through reachability.
                        if (raise_alias(s, sites[o].A, o)) changed = moved(s);
                    }
                }

            } else if (k->kind == AIF_CON_LIVE_IN) {
                resolve(k->a, &scratch_val);
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    int s = vec_val.v[i];
                    // Cross-function flow does not extend a lifetime: only a
                    // binding in the site's own function says anything about
                    // which of that function's scopes the value outlives.
                    int target = (sites[s].fn == k->c) ? k->b : AIF_E_CALLER;
                    if (raise_escape(s, target, -1)) changed = moved(s);
                }

            } else if (k->kind == AIF_CON_OPAQUE) {
                resolve(k->a, &scratch_val);
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    int s = vec_val.v[i];
                    if (sites[s].E != AIF_E_GLOBAL && raise_escape(s, AIF_E_CALLER, -1)) changed = moved(s);
                    if (raise_alias(s, AIF_A_SHARED, -1)) changed = moved(s);
                }

            } else if (k->kind == AIF_CON_RETAIN_IN) {
                // E-STORE / A-STORE against a container reached through a call
                // rather than through a field assignment (FFI `retain_in`).
                resolve(k->a, &scratch_val);
                resolve(k->b, &scratch_own);
                bits_to_vec(&scratch_val, &vec_val);
                bits_to_vec(&scratch_own, &vec_own);
                for (int i = 0; i < vec_val.len; i++) {
                    int s = vec_val.v[i];
                    for (int j = 0; j < vec_own.len; j++) {
                        int h = vec_own.v[j];
                        if (raise_escape(s, sites[h].E, h)) changed = moved(s);
                        if (raise_alias(s, sites[h].A, h)) changed = moved(s);
                    }
                    if (raise_alias(s, AIF_A_BORROWED, -1)) changed = moved(s);
                }

            } else if (k->kind == AIF_CON_BORROW) {
                // Raises A to Borrowed for the call's duration and nothing
                // else. Escape is untouched: a callee that does not retain
                // cannot extend a lifetime (FFI 6, `borrow` row).
                resolve(k->a, &scratch_val);
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    if (raise_alias(vec_val.v[i], AIF_A_BORROWED, -1)) changed = moved(vec_val.v[i]);
                }

            } else if (k->kind == AIF_CON_ESCAPE_CALLER) {
                resolve(k->a, &scratch_val);
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    if (raise_escape(vec_val.v[i], AIF_E_CALLER, -1)) changed = moved(vec_val.v[i]);
                }

            } else if (k->kind == AIF_CON_NO_STACK) {
                resolve(k->a, &scratch_val);
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    if (!sites[vec_val.v[i]].no_stack) {
                        sites[vec_val.v[i]].no_stack = 1;
                        changed = moved(vec_val.v[i]);
                    }
                }

            } else if (k->kind == AIF_CON_ESCAPE_GLOBAL) {
                resolve(k->a, &scratch_val);
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    int s = vec_val.v[i];
                    if (sites[s].E != AIF_E_GLOBAL) {
                        sites[s].E = AIF_E_GLOBAL;
                        note_deriv(deriv_e, s, -1, AIF_E_GLOBAL);
                        changed = moved(s);
                    }
                }
            }
        }

        // Rules that read a site's own state rather than an incoming edge. They
        // have no constraint to attribute to, so the derivation names the rule
        // directly -- cur_con of -1 makes note_deriv fall back to synth_rule.
        cur_con = -1;
        for (int s = 0; s < site_count; s++) {
            // A-ESCAPE: anything globally reachable is reachable more than once.
            synth_rule = AIF_RULE_A_ESCAPE;
            if (sites[s].E == AIF_E_GLOBAL && raise_alias(s, AIF_A_SHARED, -1)) changed = moved(s);

            // A-COPY: only a copyable value can be genuinely multiply held.
            synth_rule = AIF_RULE_A_COPY;
            if (!site_is_move_only(&sites[s])
                && bits_count_at_least_two(&holders[s])
                && raise_alias(s, AIF_A_SHARED, -1)) {
                changed = moved(s);
            }

            // C-UNIQUE / C-TYPE (INFERENCE 4.4 stage 2).
            int acyclic = (sites[s].A == AIF_A_UNIQUE) || sites[s].type_acyclic;
            int want = acyclic ? AIF_C_ACYCLIC : AIF_C_MAYBE;
            if (want > sites[s].C) {
                sites[s].C = want;
                changed = moved(s);
            }
        }

        if (!changed) return 1;
    }
    return 0;
}

int aif_rounds(void) { return solve_rounds; }
int aif_pt_rounds(void) { return pt_rounds; }

// INFERENCE 5.3: a truncated ascending iteration is a *pre*-fixed point, so its
// facts are too optimistic -- assigning tiers from one would hand a value T2
// where the unexplored rounds would have proved it Shared. That is a
// use-after-free, not a slowdown, so truncation must be followed by widening to
// a post-fixed point.
//
// U := delta union transitive_succs(delta). If a site's facts change in round
// r+1, some input of it changed in round r, so chaining back puts everything
// still in motion inside the closure of the last round's delta -- and raising
// exactly that set to top yields a post-fixed point.
//
// Fact flow between sites runs owner -> value and only through STORE and
// RETAIN_IN; every other rule raises a site from a constant, and the per-site
// rules are self-edges. Those two edges are read out of the points-to state,
// which takes no input from the facts -- so once points-to has settled the
// successor graph is final and the frontier is exact. While points-to is still
// growing it is not: a later round can put a site into a set this pass cannot
// name, so there the whole graph is the only sound answer.
static void widen_sites(const Bits* u) {
    for (int s = 0; s < site_count; s++) {
        if (u && !bits_test(u, s)) continue;
        sites[s].E = AIF_E_GLOBAL;
        sites[s].A = AIF_A_SHARED;
        sites[s].C = AIF_C_MAYBE;
        bits_set(&widened, s, "AIF widened");
    }
}

void aif_widen(void) {
    if (site_count <= 0) return;

    if (delta_pt) {
        widen_sites(NULL);
        return;
    }

    Bits* succ = (Bits*)xcalloc((size_t)site_count, sizeof(Bits), "AIF widen succ");
    for (int ci = 0; ci < con_count; ci++) {
        Constraint* k = &cons[ci];
        int vs_val, vs_own;
        if (k->kind == AIF_CON_STORE)           { vs_val = k->b; vs_own = k->c; }
        else if (k->kind == AIF_CON_RETAIN_IN)  { vs_val = k->a; vs_own = k->b; }
        else continue;

        resolve(vs_val, &scratch_val);
        resolve(vs_own, &scratch_own);
        bits_to_vec(&scratch_own, &vec_own);
        for (int j = 0; j < vec_own.len; j++) {
            bits_or(&succ[vec_own.v[j]], &scratch_val, "AIF widen succ");
        }
    }

    Bits u;
    memset(&u, 0, sizeof(u));
    bits_or(&u, &delta, "AIF widen frontier");

    IntVec work;
    memset(&work, 0, sizeof(work));
    bits_to_vec(&delta, &vec_val);
    for (int i = 0; i < vec_val.len; i++) vec_push(&work, vec_val.v[i], "AIF widen work");

    while (work.len > 0) {
        int s = work.v[--work.len];
        bits_to_vec(&succ[s], &vec_own);
        for (int i = 0; i < vec_own.len; i++) {
            if (bits_set(&u, vec_own.v[i], "AIF widen frontier")) {
                vec_push(&work, vec_own.v[i], "AIF widen work");
            }
        }
    }

    widen_sites(&u);

    free(work.v);
    bits_free(&u);
    for (int s = 0; s < site_count; s++) bits_free(&succ[s]);
    free(succ);
}

// Whether this site's facts were raised by the widening rather than inferred.
// SPEC 6.2 marks exactly those records budget-exhausted; the rest of a truncated
// build carries facts that converged and are as good as any other build's.
int aif_site_widened(int id) {
    if (id < 0 || id >= site_count) return 0;
    return bits_test(&widened, id);
}

// ============================================================================
// Tier derivation (SPEC 4.2)
//
// Here rather than in Prismio because the first clause needs defscope(s), and
// the escape encoding that makes that comparison a single integer test is this
// file's private business. The derivation itself is the spec's, clause for
// clause, first match wins.
//
// Theta_stack is approximated by field count: at this stage the frontend has no
// layout, so a byte threshold is not available. SPEC 4.2 requires the threshold
// be documented by the implementation -- it is emitted in the manifest header.
//
// T4a is unreachable by construction: the language has no tasks, so the thread
// affinity domain is vacuous and every value is Isolated.
// ============================================================================

#define AIF_THETA_STACK_FIELDS 8
#define AIF_THETA_STACK_BYTES 256

#define AIF_THETA_MODE_BYTES  0
#define AIF_THETA_MODE_FIELDS 1

#define AIF_T0  0
#define AIF_T1  1
#define AIF_T2  2
#define AIF_T3  3
#define AIF_T4B 4

// Which Theta_stack to apply. Bytes is the real threshold and the default;
// fields is the prototype's approximation (its A5), kept switchable because the
// oracle reads a JSON dump with no layout in it and cannot compute the other.
// A comparison against the oracle therefore runs in fields mode -- otherwise the
// two would differ on the T0/T1 split alone and the differential test would stop
// saying anything about the part that matters, which is the inference.
static int theta_mode = AIF_THETA_MODE_BYTES;

void aif_set_theta_mode(int mode) {
    theta_mode = (mode == AIF_THETA_MODE_FIELDS) ? AIF_THETA_MODE_FIELDS
                                                 : AIF_THETA_MODE_BYTES;
}

int aif_theta_mode(void) { return theta_mode; }

int aif_theta_stack(void) {
    return (theta_mode == AIF_THETA_MODE_FIELDS) ? AIF_THETA_STACK_FIELDS
                                                 : AIF_THETA_STACK_BYTES;
}

// SPEC 4.2 requires the size be *statically known* as well as under the
// threshold. A struct whose size the frontend never computed is not known, and
// unknown must not read as small.
static int fits_on_stack(const Site* s) {
    if (theta_mode == AIF_THETA_MODE_FIELDS) {
        return s->nfields <= AIF_THETA_STACK_FIELDS;
    }
    return s->bytes > 0 && s->bytes <= AIF_THETA_STACK_BYTES;
}

// The cheapest tier the converged facts permit. This is where SPEC 3's ladder
// becomes a decision, and the clauses are ordered so the first match wins.
static int derived_tier(const Site* s) {
    if (s->E == s->scope && s->A <= AIF_A_BORROWED
        && s->kind == AIF_K_STRUCT && fits_on_stack(s) && !s->no_stack) {
        return AIF_T0;
    }
    if (s->E != AIF_E_CALLER && s->E != AIF_E_GLOBAL) return AIF_T1;
    if (s->A <= AIF_A_BORROWED) return AIF_T2;
    if (s->C == AIF_C_ACYCLIC) return AIF_T3;
    return AIF_T4B;
}

int aif_tier_of(int id) {
    if (id < 0 || id >= site_count) return AIF_T4B;
    Site* s = &sites[id];
    // SPEC 5.4: a honoured pin freezes the tier, and everything downstream --
    // codegen, the drop predicate, the arena test -- has to read the frozen one
    // or they would disagree with the manifest about what was built.
    if (s->pin_verdict == AIF_PIN_HONOURED) return s->pin_tier;
    return derived_tier(s);
}

// SPEC 5.4, after convergence. The pin derives nothing and seeds nothing; it
// constrains the output, so this runs once the facts are final.
//
// SPEC's pseudocode has four branches and the middle one -- "the facts permit
// the pinned tier but the solver did not reach it" -- is **vacuous here**, and
// saying why matters more than the code. derived_tier returns the cheapest tier
// its clauses admit, and the clauses read the facts directly; there is no search
// that could settle above its own optimum. An implementation whose tier
// assignment was a separate optimisation would need that branch. This one cannot
// enter it, so a pin below the derived tier is refuted rather than rescued.
void aif_check_pins(int converged) {
    for (int i = 0; i < site_count; i++) {
        Site* s = &sites[i];
        if (s->pin_tier < 0) continue;

        int derived = derived_tier(s);
        if (s->pin_tier >= derived) {
            s->pin_verdict = AIF_PIN_HONOURED;
        } else if (converged) {
            s->pin_verdict = AIF_PIN_REFUTED;
        } else {
            // SPEC 5.4.2: unproven is not disproven. Failing here would punish
            // the programmer for the budget, which SPEC 1 forbids. The tier is
            // kept so the warning can name what was asked for; only the verdict
            // decides whether aif_tier_of uses it, and this one does not.
            s->pin_verdict = AIF_PIN_UNPROVEN;
        }
    }
}

int aif_site_pin_verdict(int id) {
    if (id < 0 || id >= site_count) return AIF_PIN_NONE;
    return sites[id].pin_verdict;
}

int aif_site_pin_tier(int id) {
    if (id < 0 || id >= site_count) return -1;
    return sites[id].pin_tier;
}

// The tier the facts would have given, so a refuted pin's diagnostic can say
// what the analysis actually proved instead of just refusing.
int aif_site_derived_tier(int id) {
    if (id < 0 || id >= site_count) return AIF_T4B;
    return derived_tier(&sites[id]);
}

int aif_site_alias_axiom(int id) {
    if (id < 0 || id >= site_count) return 0;
    return sites[id].alias_axiom;
}

// ============================================================================
// Minimal cause (INFERENCE 5.6, SPEC 6.3)
//
// Walk the derivation backward from a site through maximal contributors until a
// root -- an allocation, an axiom, or a rule with no incoming site. The result
// is the witness path SPEC 6.3 prints under "minimal cause", innermost edge
// first, which is the order it reads in: the change, then what made the change
// matter.
//
// Which domain to walk is decided by the tier, and that mapping is the reason
// the two are kept separately. A T1 -> T2 move is an *escape* question and a
// T2 -> T3 move is an *aliasing* one; showing the E path for a value that lost
// its tier to sharing would be a confident answer to the wrong question.
// ============================================================================

#define AIF_CAUSE_MAX 32

static int cause_site[AIF_CAUSE_MAX];
static int cause_rule[AIF_CAUSE_MAX];
static int cause_value[AIF_CAUSE_MAX];
static int cause_file[AIF_CAUSE_MAX];
static int cause_line[AIF_CAUSE_MAX];
static int cause_col[AIF_CAUSE_MAX];
static int cause_len;
static int cause_domain;    // 0 = escape, 1 = aliasing

// Which fact cost this site its tier, and therefore which derivation explains
// it.
//
// The order matters and is the reverse of the tier clauses'. A site is asked
// about because its tier is worse than someone wanted, so the interesting fact
// is the *last* one that was binding, not the first. Aliasing is checked before
// escape because A > Borrowed is what separates T3 from T2: a T3 record whose E
// is also Caller would otherwise be explained by the escape that only got it as
// far as T2, which is a confident answer to the wrong question.
//
// T4b is cyclicity, which is derived from A and the type graph rather than
// propagated, so it reports the aliasing path too -- that is where its own
// witness would start.
int aif_cause_domain_for(int id) {
    if (id < 0 || id >= site_count) return 0;
    Site* s = &sites[id];
    if (s->A > AIF_A_BORROWED) return 1;                          // aliasing
    return 0;                                                     // escape
}

// Builds the path and returns its length. The caller reads it back edge by edge;
// one buffer is enough because a diff explains one record at a time.
int aif_cause_build(int id, int domain) {
    cause_len = 0;
    cause_domain = domain;
    if (id < 0 || id >= site_count || !deriv_e || !deriv_a) return 0;

    Deriv* d = domain == 1 ? deriv_a : deriv_e;
    int cur = id;
    for (int hops = 0; hops < AIF_CAUSE_MAX; hops++) {
        cause_site[cause_len]  = cur;
        cause_rule[cause_len]  = d[cur].rule;
        cause_value[cause_len] = d[cur].value;
        cause_file[cause_len]  = d[cur].file;
        cause_line[cause_len]  = d[cur].line;
        cause_col[cause_len]   = d[cur].col;
        cause_len++;

        int next = d[cur].from;
        if (next < 0 || next >= site_count) break;   // a root: nothing fed it
        // The derivation is a DAG by construction -- a fact only ever rises, so
        // an edge always points at a site that reached its value earlier -- but
        // a cap costs nothing and turns a bug here into a truncated explanation
        // rather than a hang.
        int seen = 0;
        for (int i = 0; i < cause_len; i++) {
            if (cause_site[i] == next) { seen = 1; break; }
        }
        if (seen) break;
        cur = next;
    }
    return cause_len;
}

int aif_cause_len(void)          { return cause_len; }
int aif_cause_site(int i)        { return (i < 0 || i >= cause_len) ? -1 : cause_site[i]; }
int aif_cause_rule(int i)        { return (i < 0 || i >= cause_len) ? -1 : cause_rule[i]; }
int aif_cause_value(int i)       { return (i < 0 || i >= cause_len) ? -1 : cause_value[i]; }
int aif_cause_file(int i)        { return (i < 0 || i >= cause_len) ? 0 : cause_file[i]; }
int aif_cause_line(int i)        { return (i < 0 || i >= cause_len) ? 0 : cause_line[i]; }
int aif_cause_col(int i)         { return (i < 0 || i >= cause_len) ? 0 : cause_col[i]; }

// The E value an edge raised to, spelled the way the manifest spells a scope.
// Region ids are per-function and meaningless outside one, so a scope reports as
// its depth rather than its id -- what a reader needs is "an enclosing scope",
// not which array slot it occupies.
const char* aif_escape_name(int value) {
    if (value == AIF_E_CALLER) return "Caller";
    if (value == AIF_E_GLOBAL) return "Global";
    return "Region";
}

const char* aif_alias_name(int value) {
    if (value <= AIF_A_UNIQUE) return "Unique";
    if (value <= AIF_A_BORROWED) return "Borrowed";
    return "Shared";
}

// SPEC 6.3 prints the rule that fired on each edge, because that is what makes
// a repair derivable: breaking the edge restores the tier, and the rule says
// what breaking it would mean.
const char* aif_rule_name(int rule) {
    if (rule == AIF_CON_BIND)           return "E-BIND";
    if (rule == AIF_CON_ARG)            return "A-CALL";
    if (rule == AIF_CON_STORE)          return "A-STORE";
    if (rule == AIF_CON_LIVE_IN)        return "E-BIND";
    if (rule == AIF_CON_OPAQUE)         return "E-OPAQUE";
    if (rule == AIF_CON_RETAIN_IN)      return "A-RETAIN";
    if (rule == AIF_CON_BORROW)         return "A-CALL";
    if (rule == AIF_CON_ESCAPE_CALLER)  return "E-RETURN";
    if (rule == AIF_CON_ESCAPE_GLOBAL)  return "E-STATIC";
    if (rule == AIF_RULE_A_ESCAPE)      return "A-ESCAPE";
    if (rule == AIF_RULE_A_COPY)        return "A-COPY";
    if (rule == AIF_RULE_ALLOC)         return "ALLOC";
    return "?";
}

// ============================================================================
// Tier lookup by AST node
//
// Codegen has to ask "what tier is the value this expression allocates?", and
// the answer has to survive the gap between the two passes. The join key is the
// node itself: the AIF pass and codegen walk the same in-memory tree in the same
// process, so the address the parser allocated is a name for the expression that
// costs nothing to carry and cannot collide.
//
// It replaces a file:line:col key, which could: an array literal and its first
// element start at the same column, and `[str_concat(a,b), ...]` puts a site at
// each. That key had to resolve a collision by keeping the *highest* tier, since
// codegen reads T0 as permission to use a stack slot and rounding down there is
// heap corruption. Nothing rounds now -- one node, one site.
// ============================================================================

#define AIF_NODE_BUCKETS 8192

typedef struct NodeSite {
    struct NodeSite* next;
    const void* node;
    int site;
} NodeSite;

static NodeSite* node_buckets[AIF_NODE_BUCKETS];

static unsigned node_hash(const void* p) {
    uintptr_t v = (uintptr_t)p;
    v ^= v >> 33;
    v *= 0xff51afd7ed558ccdull;
    v ^= v >> 29;
    return (unsigned)v & (AIF_NODE_BUCKETS - 1);
}

// One site per allocating expression, so a node that already has one is a bug
// in the walk rather than a collision to resolve. Recording the first keeps that
// deterministic if it ever happens.
void aif_site_note_node(int site, const void* node) {
    if (site < 0 || site >= site_count || node == NULL) return;
    unsigned b = node_hash(node);
    for (NodeSite* n = node_buckets[b]; n; n = n->next) {
        if (n->node == node) return;
    }
    NodeSite* n = (NodeSite*)xmalloc(sizeof(NodeSite), "AIF node index");
    n->node = node;
    n->site = site;
    n->next = node_buckets[b];
    node_buckets[b] = n;
}

// -1 when no site was inferred for this node. Codegen must read that as "no
// information" and allocate the way it always did -- which is what makes SPEC
// 7.1's zero-analysis build behaviourally identical rather than merely intended
// to be.
int aif_tier_at_node(const void* node) {
    if (node == NULL) return -1;
    for (NodeSite* n = node_buckets[node_hash(node)]; n; n = n->next) {
        if (n->node == node) return aif_tier_of(n->site);
    }
    return -1;
}

// Level 2's question: may the value this node allocates be freed when the scope
// that allocated it exits?
//
// Two things have to hold, and the analysis supplies only one of them.
//
// The escape must bottom at that scope -- the same test the T0 clause opens
// with, and the reason the declaring-scope fix in the escape module had to be
// right. The tier alone does not answer it: T1 says "some region", which may be
// an enclosing scope if the value was also bound further out, and freeing at the
// inner exit would then be a use-after-free rather than a leak.
//
// The *language* must also guarantee a single owner, which is what
// site_is_move_only reports. Without it there is nothing to stop a second
// binding holding the same value, and a free at one binding's scope exit is a
// double free through the other. Today that admits structs only; it widens on
// its own when SPEC 11 item 10's affine collections land, which is what makes
// this the change Level 4 pays off rather than Level 2.
// The innermost scope at or above this one that has an arena, or -1.
//
// "Has an arena" is a `region` statement (which pins one) or a scope the cost
// model chose (LAYOUT 7.1). Both are the same thing to every question below:
// what matters is where the bump allocator that would serve this site lives.
static int enclosing_region(int scope) {
    for (int s = scope; s >= 0; s = scopes[s].parent) {
        if (scopes[s].arena) return s;
    }
    return -1;
}

// ============================================================================
// Automatic arena placement (LAYOUT 7.1)
//
//     ArenaBenefit(s) = allocs_in(s)·(α_T2 − α_T1) − entries(s)·arenaSetupCost
//
// Every scope is already an implicit region (SPEC 4.1), so the question is not
// which scopes *could* have an arena but which ones are worth the setup. Both
// inputs are supposed to come from an access profile; there is no profiler, so
// they are estimated statically and the estimate is stated rather than hidden:
//
//   entries(s)     factors out. It multiplies both terms once `allocs_in` is
//                  written as "allocations per entry of s", so the *sign* of the
//                  benefit -- which is the only thing the decision reads -- does
//                  not depend on it. That is why no loop-trip estimate above s
//                  is needed, and it is the reason to write the model this way.
//   allocs_in(s)   per entry: one per site the arena would serve, weighted by
//                  AIF_LOOP_ITERS for each loop between the site and s, since a
//                  site in a loop inside s allocates many times per entry.
//
// Placement is greedy innermost-first, which needs no separate nesting rule.
// A site can only be served by an arena its escape bottoms at or below, so an
// inner arena takes exactly the values that die earlier -- LAYOUT's condition
// for an inner arena being worth it, satisfied by construction rather than by a
// heuristic. Whatever the inner one cannot take, the next one out sees.
//
// Ties break by scope id, which is creation order and therefore node order
// (LAYOUT 7.1 last line).
// ============================================================================

#define AIF_ALPHA_T1        3     // LAYOUT 4: allocation cycles at T1 (bump)
#define AIF_ALPHA_T2        90    //           and at T2 (a general allocator)
#define AIF_ARENA_SETUP    40     // LAYOUT 4: ~one block acquisition plus reset
#define AIF_LOOP_ITERS      16    // assumed trip count of a loop with no profile

// Loops between `inner` and its ancestor `outer`, or 0 if unrelated.
static int loops_between(int inner, int outer) {
    if (inner < 0 || outer < 0) return 0;
    int d = scopes[inner].loop_depth - scopes[outer].loop_depth;
    return d > 0 ? d : 0;
}

static long weight_of(int site_scope, int arena_scope) {
    long w = 1;
    int loops = loops_between(site_scope, arena_scope);
    // Capped so a deeply nested site cannot overflow the benefit; anything past
    // the cap is already far above the threshold and the exact value is noise.
    if (loops > 6) loops = 6;
    for (int i = 0; i < loops; i++) w *= AIF_LOOP_ITERS;
    return w;
}

static int is_ancestor_or_self(int anc, int s) {
    for (int p = s; p >= 0; p = scopes[p].parent) {
        if (p == anc) return 1;
    }
    return 0;
}

// Would an arena at `cand` serve this site, given the arenas chosen so far?
static int arena_would_serve(int site_id, int cand) {
    Site* s = &sites[site_id];
    if (aif_tier_of(site_id) != AIF_T1) return 0;   // T0 has the frame already
    if (s->no_stack) return 0;                      // an explicit drop frees it
    if (s->kind == AIF_K_LIST) return 0;            // grows past its site; see below
    if (s->E < 0) return 0;                         // Caller or Global
    if (!is_ancestor_or_self(cand, s->scope)) return 0;
    if (scope_lca(s->E, cand) != cand) return 0;    // outlives the arena
    // A nearer arena already claimed it. Innermost-first placement means any
    // scope strictly between the site and `cand` that has one gets it first.
    for (int p = s->scope; p >= 0 && p != cand; p = scopes[p].parent) {
        if (scopes[p].arena) return 0;
    }
    return 1;
}

// Chosen after the fixed point, because every input is a converged fact.
void aif_place_arenas(void) {
    // Innermost-first: a higher scope id is a scope created later, and the walk
    // creates a parent before its children, so descending id visits every child
    // before its parent.
    for (int s = scope_count - 1; s >= 0; s--) {
        if (scopes[s].arena) continue;              // pinned by `region`
        if (scopes[s].node == NULL) continue;       // no block for codegen to bracket

        // Inside a `region`, the region decides. SPEC 5.2 makes `region` a pin on
        // this decision, and a pin that the cost model can undercut by placing a
        // tighter arena two lines in is not one -- the named region would serve
        // nothing and the manifest would stop being able to say which block owns
        // a value. A programmer who wants per-iteration reclamation inside a
        // region writes a nested `region`, which test_44's breaks_out does.
        //
        // Only *explicit* ancestors count, and the traversal is what makes that
        // true for free: innermost-first means an ancestor's flag is set here
        // only if `region` set it, never if this pass did.
        int pinned_above = 0;
        for (int p = scopes[s].parent; p >= 0; p = scopes[p].parent) {
            if (scopes[p].arena) { pinned_above = 1; break; }
        }
        if (pinned_above) continue;

        long served = 0;
        for (int k = 0; k < site_count; k++) {
            if (arena_would_serve(k, s)) served += weight_of(sites[k].scope, s);
        }
        if (served == 0) continue;

        long benefit = served * (AIF_ALPHA_T2 - AIF_ALPHA_T1) - (long)AIF_ARENA_SETUP;
        if (benefit > 0) scopes[s].arena = 1;
    }
}

// 1 when this BLOCK node opens an arena the cost model chose. A `region`
// statement is excluded: codegen already brackets that one, and bracketing it
// twice would push two arenas and pop only the inner one at an early exit.
int aif_auto_arena_at_node(const void* node) {
    if (node == NULL) return 0;
    for (int s = 0; s < scope_count; s++) {
        if (scopes[s].node != node) continue;
        if (scopes[s].region_name >= 0) return 0;
        return scopes[s].arena;
    }
    return 0;
}

// SPEC 5.2: may this value come from the enclosing region's arena?
//
// Only if it dies no later than that region does. The escape is a scope, and
// the arena is released when its own scope exits, so the test is "is the region
// an ancestor-or-self of the escape scope" -- lca(E, r) == r.
//
// The nesting case is the one that makes this more than a lexical question:
//
//     region outer { let mut x = ...; region inner { x = Foo{} } use(x) }
//
// `Foo{}` is lexically inside `inner`, but its escape is `outer`'s scope, and
// inner's arena is gone by `use(x)`. lca(outer, inner) is outer, not inner, so
// this correctly declines and the value goes to the heap.
int aif_arena_at_node(const void* node) {
    if (node == NULL) return 0;
    for (NodeSite* n = node_buckets[node_hash(node)]; n; n = n->next) {
        if (n->node != node) continue;
        Site* s = &sites[n->site];
        if (aif_tier_of(n->site) != AIF_T1) return 0;   // T0 has the frame already
        // The same reason the T0 clause asks: an arena pointer is not a thing a
        // deallocator can take, and `drop(x)` emits one unconditionally -- the
        // source, not the model, decided when that value dies. Latent while
        // arenas only appeared where a `region` was written; automatic placement
        // (LAYOUT 7.1) puts one around almost every explicit drop.
        if (s->no_stack) return 0;
        // An arena serves values allocated once. A list is not one: list_push
        // reallocates the element block long after this site returned, at
        // whatever arena depth the program happens to be at then -- so the block
        // would be tied to a region the list can outlive, and freeing the old
        // block would hand arena memory to the deallocator. Lists stay on the
        // heap and are reclaimed by list_release at their binding's scope exit,
        // which is also what keeps the Level 2 drop path exercised.
        if (s->kind == AIF_K_LIST) return 0;
        int r = enclosing_region(s->scope);
        if (r < 0) return 0;
        if (s->E < 0) return 0;                         // Caller or Global
        return scope_lca(s->E, r) == r ? 1 : 0;
    }
    return 0;
}

// The region name to report for this site, or "" when it is not arena-placed.
// An arena the cost model chose has no name to report -- it is a scope, not a
// declaration -- so it reports "auto", which is what distinguishes it in the
// manifest from a `region` the programmer pinned.
const char* aif_region_name_at_site(int id) {
    if (id < 0 || id >= site_count) return "";
    if (aif_tier_of(id) != AIF_T1) return "";
    if (sites[id].no_stack) return "";
    if (sites[id].kind == AIF_K_LIST) return "";
    int r = enclosing_region(sites[id].scope);
    if (r < 0 || sites[id].E < 0) return "";
    if (scope_lca(sites[id].E, r) != r) return "";
    if (scopes[r].region_name < 0) return "auto";
    return aif_str(scopes[r].region_name);
}

// 1 when this site's arena was pinned by a `region` statement rather than chosen
// by the cost model. SPEC 6.2's `origin` column distinguishes them: a pin that
// stops being honoured is a gate regression, an inferred placement moving is not.
int aif_site_arena_is_pinned(int id) {
    if (id < 0 || id >= site_count) return 0;
    int r = enclosing_region(sites[id].scope);
    if (r < 0) return 0;
    return scopes[r].region_name >= 0 ? 1 : 0;
}

int aif_frees_at_scope_node(const void* node) {
    if (node == NULL) return 0;
    // An arena releases in bulk when its region exits. Freeing one of its
    // objects individually would hand a pointer into the middle of a chunk to
    // the deallocator -- so a value the arena serves is never on a drop list.
    if (aif_arena_at_node(node)) return 0;
    for (NodeSite* n = node_buckets[node_hash(node)]; n; n = n->next) {
        if (n->node != node) continue;
        Site* s = &sites[n->site];
        if (s->E != s->scope) return 0;
        if (!site_is_move_only(s)) return 0;
        // An array literal lowers to ir_array_alloca -- frame storage, like T0
        // below, so there is nothing here for a deallocator to take. This is the
        // one place the language and site_is_move_only disagree: affine
        // collections make arrays move-only in the model (and in the oracle), and
        // types.psm deliberately does not, because an affine value with no
        // allocation behind it buys the aliasing rule and costs a `drop(arr)`
        // that frees a stack pointer.
        if (s->kind == AIF_K_ARRAY) return 0;
        // An explicit `drop` already frees it; a scope drop as well is a double
        // free. Same flag that bars T0, and for the same reason -- it records
        // that the source, not the model, decides when this value dies.
        if (s->no_stack) return 0;
        return aif_tier_of(n->site) == AIF_T0 ? 0 : 1;   // T0 storage is the frame
    }
    return 0;
}

// ============================================================================
// Manifest ordering
//
// SPEC 6.2 makes the record order normative -- byte-wise ascending by symbol --
// because an unstable order makes every diff useless. The frontend builds each
// record's symbol (it knows what a symbol means) and hands it here to be sorted
// (sorting is a container operation).
//
// Insertion-order-stable, so equal symbols keep the order they were added in.
// There should be no equal symbols; relying on that rather than asserting it
// would make a future collision reorder the manifest silently.
// ============================================================================

typedef struct {
    int symbol;     // interned
    int site;
    int seq;
} Record;

static Record* records;
static int record_count, record_cap;

void aif_order_add(const char* symbol, int site) {
    if (record_count == record_cap) {
        record_cap = record_cap ? record_cap * 2 : 1024;
        records = (Record*)xrealloc(records, (size_t)record_cap * sizeof(Record),
                                    "AIF manifest records");
    }
    Record* r = &records[record_count];
    r->symbol = aif_intern(symbol);
    r->site = site;
    r->seq = record_count;
    record_count++;
}

static int record_cmp(const void* a, const void* b) {
    const Record* x = (const Record*)a;
    const Record* y = (const Record*)b;
    int c = strcmp(aif_str(x->symbol), aif_str(y->symbol));
    if (c != 0) return c;
    return x->seq - y->seq;
}

void aif_order_sort(void) {
    if (record_count > 1) qsort(records, (size_t)record_count, sizeof(Record), record_cmp);
}

int aif_order_count(void) { return record_count; }
const char* aif_order_symbol(int i) { return (i < 0 || i >= record_count) ? "" : aif_str(records[i].symbol); }
int aif_order_site(int i) { return (i < 0 || i >= record_count) ? -1 : records[i].site; }

// ============================================================================
// Reset
//
// A compiler run analyses one program, but the test harness and any future
// per-module invocation want a clean slate. Interned names are deliberately
// kept: they cost nothing and nothing outside this file holds an id across a
// reset.
// ============================================================================

void aif_reset(void) {
    for (int i = 0; i < pt_len; i++) bits_free(&pt[i]);
    for (int i = 0; i < holders_len; i++) bits_free(&holders[i]);
    free(pt);
    free(holders);
    pt = NULL;
    holders = NULL;
    pt_len = 0;
    holders_len = 0;

    free(deriv_e);
    free(deriv_a);
    deriv_e = NULL;
    deriv_a = NULL;
    cause_len = 0;
    cur_con = -1;
    synth_rule = -1;

    for (int i = 0; i < vs_count; i++) free(vsets[i].items);
    vs_count = 0;

    for (int i = 0; i < nominal_count; i++) bits_free(&nominals[i].reaches);
    nominal_count = 0;
    for (int i = 0; i < nominal_by_name_cap; i++) nominal_by_name[i] = -1;

    for (int i = 0; i < fn_by_symbol_cap; i++) fn_by_symbol[i] = -1;
    fn_count = 0;

    free(var_scope);
    var_scope = NULL;
    var_scope_cap = 0;

    free(extern_contract);
    extern_contract = NULL;
    extern_contract_cap = 0;

    for (int i = 0; i < AIF_NODE_BUCKETS; i++) {
        NodeSite* n = node_buckets[i];
        while (n) {
            NodeSite* next = n->next;
            free(n);
            n = next;
        }
        node_buckets[i] = NULL;
    }

    site_count = 0;
    scope_count = 0;
    con_count = 0;
    record_count = 0;
    orphan_sites = 0;
    solve_rounds = 0;
    owned_collections = 0;

    bits_free(&scratch_val);
    bits_free(&scratch_own);
    free(vec_val.v);
    free(vec_own.v);
    free(argv.v);
    vec_val.v = NULL; vec_val.len = 0; vec_val.cap = 0;
    vec_own.v = NULL; vec_own.len = 0; vec_own.cap = 0;
    argv.v = NULL; argv.len = 0; argv.cap = 0;

    for (int i = 0; i < AIF_KEY_BUCKETS; i++) {
        KeyNode* n = key_buckets[i];
        while (n) {
            KeyNode* next = n->next;
            free(n);
            n = next;
        }
        key_buckets[i] = NULL;
    }
    key_count = 0;
}
