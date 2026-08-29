// AIF — the inference engine's data structures and fixed point.
// AIF (aif/) is Prismio's memory model. The engine assigns every allocation
// site a tier T0-T4 from four inferred fact domains, and this file holds
// everything iteration needs: the scope forest, the site table, the points-to
// graph, the constraint list, and the solver loop itself.
// WHY THIS IS IN C. The policy lives in src/aif.psm -- which nodes become
// sites, which transfer rule fires where, what an extern's ownership contract
// is, how a tier becomes a manifest line. None of that is here. What is here is
// the container layer: growable bitsets, an interning table, and a hash map
// from key tuples to ids. Prismio has no generics, no maps and no growable
// vectors (aif/implementation/COMPILER-AUDIT.md 4.3 calls this the finding that
// most changes the schedule), so the engine would otherwise be written with
// parallel arrays and integer indices -- in the one component where a silent
// bug yields a wrong-tier binary rather than a crash.
// This is the same split ir_symbols.c already makes for the symbol tables, and
// it is deliberate rather than expedient: the compiler is written in Prismio,
// its containers are written in C.
// SOUNDNESS NOTE. Every fact here only ever *rises* (INFERENCE.md M2). No
// operation in this file lowers E, A or C, which is what makes the iteration
// monotone, terminating, and safe to abandon -- see aif_widen().

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

// Fact encodings
// Escape is a single int so that it fits an array slot and a Prismio `Int`
// alike: the two top elements are negative, and every Region(s) is the scope id
// itself. The ordering Region(s) < Caller < Global is not the integer ordering
// -- escape_join() implements it.

#define AIF_E_GLOBAL (-2)
#define AIF_E_CALLER (-1)

#define AIF_A_UNIQUE   0
#define AIF_A_BORROWED 1
#define AIF_A_SHARED   2

#define AIF_C_ACYCLIC 0
#define AIF_C_MAYBE   1

// INFERENCE 2.3. Thread affinity: Isolated < Transferred < CrossThread.
//
// Vacuous until 2026-08-19 -- the language had no tasks, so every value sat at
// the bottom and SPEC 4.2's two `T` conjuncts were tautologies this file did
// not bother to write down. REQUIREMENTS 15 ended that, and the conjuncts are
// now in derived_tier where the spec puts them.
//
// The middle element is the one the whole design is for. `Transferred` means
// ownership moved between tasks but only one may reach the value at a time, so
// the transfer point is itself a synchronisation edge and a release/acquire
// pair there is sufficient -- the count stays **non-atomic**. Only CrossThread
// forces atomics, and SPEC 11 item 10 exists to keep that column empty.
#define AIF_T_ISOLATED    0
#define AIF_T_TRANSFERRED 1
#define AIF_T_CROSS       2

// Site kinds. Mirrors what src/aif.psm classifies a type as; the solver only
// cares that kind 0 is a struct (the T0 clause and the copy rule both test it).
// LAYOUT 4. Assumed trip count of a loop with no profile, and the one estimator
// both static profiles share -- arena placement's allocs_in(s) and the layout
// search's access counts. One definition, so they cannot drift apart.
#define AIF_LOOP_ITERS      16

#define AIF_K_STRUCT 0
#define AIF_K_STRING 1
#define AIF_K_ARRAY  2
#define AIF_K_LIST   3
#define AIF_K_OPAQUE 4

// Growable bitsets
// Both halves of the solver state are sets of small integers: a points-to node
// holds a set of sites, and a site holds the set of nodes referencing it.
// Bitsets make union and subset one word-loop each, which keeps the round cost
// proportional to the graph rather than to the constraint list.

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

static int bits_is_empty(const Bits* b) {
    for (int i = 0; i < b->nwords; i++) {
        if (b->w[i]) return 0;
    }
    return 1;
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

// Int vectors
// Set membership is a bitset, but the solver's rules need to *enumerate* a set,
// sometimes two of them nested. Materialising a bitset into a plain int array
// keeps that a pair of ordinary loops. The buffers are reused across rounds,
// so this allocates a handful of times for the whole run.

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

// String interning
// Type names, field names and variable names all become integer ids, because
// every key in the points-to graph is a tuple of small integers and comparing
// tuples of ints is what makes the key map cheap. Id 0 is always "".

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

// Scope forest
// Each function body is a root; a block nests inside its parent. The join of
// two Region values is their least common ancestor, which exists because scopes
// nest (INFERENCE 2.1). Scopes in different functions have no common region --
// scope_lca reports -1 and escape_join falls back to Caller.

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
    // REQUIREMENTS 19. A byte cap asserted by `region name pin(N)`, or 0. The
    // span travels with it so a refuted budget can underline the annotation
    // rather than the block.
    long budget;
    int budget_file, budget_line, budget_col;
    // SPEC 5.2's diagnostic. Recorded for every `region`, not only for one that
    // carries a budget, because the warning that matters most fires on the plain
    // form -- a region that serves nothing and says nothing.
    int region_file, region_line, region_col;
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
    s->budget = 0;
    s->budget_file = s->budget_line = s->budget_col = 0;
    s->region_file = s->region_line = s->region_col = 0;
    return scope_count++;
}

void aif_scope_set_region_span(int scope, int file, int line, int col) {
    if (scope < 0 || scope >= scope_count) return;
    scopes[scope].region_file = file;
    scopes[scope].region_line = line;
    scopes[scope].region_col = col;
}

void aif_scope_set_budget(int scope, int bytes, int file, int line, int col) {
    if (scope < 0 || scope >= scope_count) return;
    scopes[scope].budget = bytes;
    scopes[scope].budget_file = file;
    scopes[scope].budget_line = line;
    scopes[scope].budget_col = col;
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

// Nominal types
// Structs carry a field count (the T0/T1 size proxy -- see aif_tier_of) and an
// edge set for the type reference graph. Enums are recorded only so the
// frontend can exclude them: an enum is an i32 and participates in no memory
// model.

typedef struct {
    int name;
    int nfields;
    int bytes;          // 0 until the frontend computes a layout for it
    int is_enum;
    Bits reaches;       // direct edges, then closed transitively
    int acyclic;
    // LAYOUT 7.2. The fields themselves, in declaration order, plus the access
    // profile over them and the permutation the search chose.
    int* field_name;    // interned
    // The field's *declared* type, base-named. Struct-field ownership compares
    // it against what the sites say is in the slot: this compiler puns an
    // ASTNode pointer as `String`, and a release chosen from the sites alone
    // would emit a call to __aif_release_String.
    int* field_type;
    int* field_bytes;   // width, from the frontend -- it knows the lowering
    long long* field_acc;
    int* order;         // order[i] is the declaration index placed i-th
    int field_cap;
    int reordered;
    // LAYOUT 2.1's `range(f)`, which the table marks **dynamic only**. It is the
    // observed value range and no reading of the source supplies it, which is why
    // the bit-packing dimension had nothing to search against until `workload`
    // existed. Zero when no profile was loaded, and the packer declines then --
    // it must, because "no range recorded" and "range is 0..0" are the same bits
    // and only one of them permits narrowing a field to nothing.
    long long* field_lo;
    long long* field_hi;
    int* field_has_range;
    // 1 when the field's storage is the object's own -- a struct value copied in
    // rather than a pointer stored. LAYOUT decides it (`typeAnnIsPod`, the single
    // definition codegen's `fieldTypeFor` also asks) and the analysis has to be
    // told, because an inline field **owns nothing**: the address is interior, so
    // there is no release to emit, and the value that was copied in is still the
    // caller's to free.
    //
    // Recorded 2026-08-28, and it was a disagreement rather than a gap. The
    // analysis reported an inline field as a released field, which suppressed
    // caller-side ownership transfer for everything stored into one; codegen then
    // emitted no release for it, because it is interior storage. Two answers to
    // one question, and every value copied into such a field leaked -- 4095 of
    // g3's 5486 allocations.
    int* field_inline;
    // LAYOUT 6's hot/cold split, once it is emitted rather than reported.
    //
    // `hot_count` is 0 for an unsplit type and otherwise the number of fields the
    // hot record keeps, in the *split* order aif_layout_field hands codegen --
    // hot fields first, in the placement order, then the cold ones. `hot` is the
    // same set by declaration index, which is the space the cost model works in.
    //
    // `no_split` is a veto pushed in before the decision is taken, never after:
    // type_releases_of reads the decision during the solve, and a veto arriving
    // later would leave a type whose release path had been decided one way and
    // whose layout went the other.
    //
    // `no_split_unmodelled` is the *other* kind of veto, and the two are kept
    // apart because LAYOUT 8 may override exactly one of them. `no_split` means
    // the cold block cannot be reached at all (vetoes 1-3): a wild load or a
    // double free, and no measurement makes it safe. `no_split_unmodelled` means
    // the model declined to choose because an input is absent (vetoes 4-5) -- the
    // layout is perfectly sound, there was just no evidence it pays. A forced
    // candidate is evidence being gathered, so it clears the second and never the
    // first.
    int hot_count;
    int no_split;
    int no_split_unmodelled;
    Bits hot;
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
    t->field_name = NULL;
    t->field_type = NULL;
    t->field_bytes = NULL;
    t->field_acc = NULL;
    t->order = NULL;
    t->field_cap = 0;
    t->reordered = 0;
    t->field_lo = NULL;
    t->field_hi = NULL;
    t->field_has_range = NULL;
    t->field_inline = NULL;
    t->hot_count = 0;
    t->no_split = 0;
    t->no_split_unmodelled = 0;
    t->hot.w = NULL;
    t->hot.nwords = 0;
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

void aif_struct_add_field(const char* name, const char* field, const char* type, int bytes) {
    Nominal* t = &nominals[nominal_intern(name, 0)];
    if (t->nfields == t->field_cap) {
        int grow = t->field_cap ? t->field_cap * 2 : 8;
        t->field_name  = (int*)xrealloc(t->field_name,  (size_t)grow * sizeof(int), "AIF fields");
        t->field_type  = (int*)xrealloc(t->field_type,  (size_t)grow * sizeof(int), "AIF field types");
        t->field_bytes = (int*)xrealloc(t->field_bytes, (size_t)grow * sizeof(int), "AIF field widths");
        t->field_acc = (long long*)xrealloc(t->field_acc,
                                           (size_t)grow * sizeof(long long), "AIF field accesses");
        t->order = (int*)xrealloc(t->order, (size_t)grow * sizeof(int), "AIF field order");
        t->field_lo = (long long*)xrealloc(t->field_lo,
                                           (size_t)grow * sizeof(long long), "AIF field range lo");
        t->field_hi = (long long*)xrealloc(t->field_hi,
                                           (size_t)grow * sizeof(long long), "AIF field range hi");
        t->field_has_range = (int*)xrealloc(t->field_has_range,
                                            (size_t)grow * sizeof(int), "AIF field range flag");
        t->field_inline = (int*)xrealloc(t->field_inline,
                                         (size_t)grow * sizeof(int), "AIF field inlineness");
        t->field_cap = grow;
    }
    int i = t->nfields++;
    t->field_name[i] = aif_intern(field);
    t->field_type[i] = aif_intern(type);
    t->field_bytes[i] = bytes;
    t->field_acc[i] = 0;
    t->order[i] = i;
    t->field_lo[i] = 0;
    t->field_hi[i] = 0;
    t->field_has_range[i] = 0;
    t->field_inline[i] = 0;
}

// The layout half of a field, told to the analysis rather than derived by it.
// Separate from aif_struct_add_field because adding an FFI function is one step
// and changing one is two: the committed seed's IR calls the four-argument form.
void aif_struct_field_inline(const char* name, const char* field, int inlined) {
    int id = nominal_find(name);
    if (id < 0) return;
    Nominal* t = &nominals[id];
    int f = aif_intern(field);
    for (int i = 0; i < t->nfields; i++) {
        if (t->field_name[i] == f) { t->field_inline[i] = inlined ? 1 : 0; return; }
    }
}

static int field_is_inline(int type_name, int field_name) {
    int id = nominal_find_id(type_name);
    if (id < 0) return 0;
    Nominal* t = &nominals[id];
    for (int i = 0; i < t->nfields; i++) {
        if (t->field_name[i] == field_name) return t->field_inline[i];
    }
    return 0;
}

// The access profile (LAYOUT 2.1) and layout selection (LAYOUT 7.2)
// LAYOUT 2 wants the profile measured, by running a declared `workload` under
// instrumentation. When no workload is declared this is the static estimate
// LAYOUT 10.4 names as the fallback -- one count per syntactic access, weighted
// by AIF_LOOP_ITERS per enclosing loop, which is exactly how automatic arena
// placement estimates allocs_in(s). Same estimator, same known crudeness, and
// the same property that matters: it is deterministic and needs no profile file.
// When a workload *is* declared, aif_profile_load replaces the estimate with
// measured counts. The two are not merged: a measured count and an estimated one
// are in different units (AIF_LOOP_ITERS^depth against real iterations), and
// adding them would produce a number that is neither. LAYOUT 2's diagram has the
// same shape -- the two paths both produce *a profile*, and the cost model
// consumes one of them.
// **Only one candidate dimension is searched, and the rest is not caution.**
// LAYOUT 6's table lists grouping (AoS/SoA), a hot/cold split, field order,
// bit-packing and handle width. Field order is the only one this compiler can
// *emit*: SoA and a hot/cold split both make one logical object several
// allocations, so a field reference stops being `getelementptr` on a pointer and
// becomes a base plus an index -- which is 1's finding 6, handles, rated as
// touching every layer. Bit-packing needs a mask and a shift at every access.
// Choosing a layout codegen cannot produce would be a manifest that describes a
// binary nobody built.

// ---------------------------------------------------------------------------
// Reading a measured profile back (LAYOUT 2.2)
//
// The format is the one rt_profile_dump writes, and the parser is deliberately
// forgiving: an unknown line is skipped rather than rejected. A profile is an
// *input to codegen only* (W4), so a malformed one can make the layout worse and
// can never make the program wrong -- which means failing the build over it would
// trade a real cost for no correctness, exactly what W2 forbids.
// ---------------------------------------------------------------------------

static int g_profile_source = -1;      // interned "workload:NAME", or -1 for static
static int g_profile_runs = 0;

static void profile_set_field(const char* type, const char* field,
                              long long reads, long long writes,
                              int has_range, long long lo, long long hi) {
    int id = nominal_find(type);
    if (id < 0) return;
    Nominal* t = &nominals[id];
    int f = aif_intern(field);
    for (int i = 0; i < t->nfields; i++) {
        if (t->field_name[i] != f) continue;
        t->field_acc[i] = reads + writes;
        t->field_has_range[i] = has_range;
        t->field_lo[i] = lo;
        t->field_hi[i] = hi;
        return;
    }
}

// Returns 1 on success. A type or field the profile names but this module does
// not declare is dropped rather than diagnosed: a checked-in profile outlives
// edits to the source it was taken against (LAYOUT 10.3), and a renamed field is
// a stale profile, not a broken build.
int aif_profile_load(const char* path) {
    FILE* f = fopen(path, "r");
    if (!f) return 0;

    char line[1024];
    int any = 0;

    // Every field this module declares that the profile does not mention was not
    // touched by the measured region, and its count is therefore a measured
    // *zero* -- not "unknown". Clearing first is what makes that true; without it
    // an untouched field would keep the static estimate and read as hot, which
    // is precisely backwards for the hot/cold cut the counts feed.
    for (int n = 0; n < nominal_count; n++) {
        for (int i = 0; i < nominals[n].nfields; i++) {
            nominals[n].field_acc[i] = 0;
            nominals[n].field_has_range[i] = 0;
        }
    }

    while (fgets(line, (int)sizeof(line), f)) {
        if (line[0] == '#' || line[0] == '\n') continue;

        char kind[32], a[256], b[256];
        if (sscanf(line, "%31s", kind) != 1) continue;

        if (strcmp(kind, "source") == 0) {
            if (sscanf(line, "%31s %255s", kind, a) == 2) g_profile_source = aif_intern(a);
            continue;
        }
        if (strcmp(kind, "runs") == 0) {
            int r = 0;
            if (sscanf(line, "%31s %d", kind, &r) == 2) g_profile_runs = r;
            continue;
        }
        if (strcmp(kind, "field") == 0) {
            long long reads = 0, writes = 0, lo = 0, hi = 0;
            char range[64];
            int got = sscanf(line, "%31s %255s %lld %lld %63s",
                             kind, a, &reads, &writes, range);
            if (got < 4) continue;
            // "Type.field" -- split at the last dot, because a field name cannot
            // contain one and a type name in this language cannot either, but
            // splitting at the first would break if that ever changes.
            char* dot = strrchr(a, '.');
            if (!dot) continue;
            *dot = '\0';
            int has_range = 0;
            if (got == 5 && sscanf(range, "%lld..%lld", &lo, &hi) == 2) has_range = 1;
            profile_set_field(a, dot + 1, reads, writes, has_range, lo, hi);
            any = 1;
            continue;
        }
        if (strcmp(kind, "type") == 0) {
            long long allocs = 0, live = 0;
            if (sscanf(line, "%31s %255s %lld %lld", kind, b, &allocs, &live) == 4) {
                any = 1;
            }
            continue;
        }
    }

    fclose(f);
    return any;
}

// For the manifest. LAYOUT 2.2: "An implementation SHALL ... record in the
// manifest which was used."
const char* aif_profile_source(void) {
    return g_profile_source < 0 ? "static" : aif_str(g_profile_source);
}

int aif_profile_is_measured(void) { return g_profile_source >= 0 ? 1 : 0; }

int aif_field_has_range(const char* type, const char* field) {
    int id = nominal_find(type);
    if (id < 0) return 0;
    Nominal* t = &nominals[id];
    int fn = aif_intern(field);
    for (int i = 0; i < t->nfields; i++) {
        if (t->field_name[i] == fn) return t->field_has_range[i];
    }
    return 0;
}

long long aif_field_range_lo(const char* type, const char* field) {
    int id = nominal_find(type);
    if (id < 0) return 0;
    Nominal* t = &nominals[id];
    int fn = aif_intern(field);
    for (int i = 0; i < t->nfields; i++) {
        if (t->field_name[i] == fn) return t->field_lo[i];
    }
    return 0;
}

long long aif_field_range_hi(const char* type, const char* field) {
    int id = nominal_find(type);
    if (id < 0) return 0;
    Nominal* t = &nominals[id];
    int fn = aif_intern(field);
    for (int i = 0; i < t->nfields; i++) {
        if (t->field_name[i] == fn) return t->field_hi[i];
    }
    return 0;
}

// The narrowest signed width that holds the measured range, in bytes.
//
// In C rather than in the frontend because Prismio's integer literals infer as
// `Int` and the language does not widen across a comparison, so writing
// `lo >= -2147483648` against an I64 is a type error and the workaround is six
// annotated bindings. The arithmetic is the same either way; this is where it
// reads as what it is.
//
// Signed even when the range is non-negative: the field's declared type is
// signed, and a narrowing that changed signedness would change what a comparison
// against it means.
int aif_field_range_bytes(const char* type, const char* field) {
    if (!aif_field_has_range(type, field)) return 8;
    long long lo = aif_field_range_lo(type, field);
    long long hi = aif_field_range_hi(type, field);
    if (lo >= -128LL && hi <= 127LL) return 1;
    if (lo >= -32768LL && hi <= 32767LL) return 2;
    if (lo >= -2147483648LL && hi <= 2147483647LL) return 4;
    return 8;
}

// Defined with the cost model below, which is where the traversal table lives.
static void traversal_note_field(int type_name, int field_index);

void aif_field_access(const char* type, const char* field, int loops) {
    int id = nominal_find(type);
    if (id < 0) return;
    Nominal* t = &nominals[id];
    int f = aif_intern(field);
    long long weight = 1;
    if (loops > 6) loops = 6;       // capped as weight_of caps it, and for the same reason
    for (int i = 0; i < loops; i++) weight *= AIF_LOOP_ITERS;
    for (int i = 0; i < t->nfields; i++) {
        if (t->field_name[i] == f) {
            t->field_acc[i] += weight;
            // LAYOUT 5's cost model needs which fields are touched *together*,
            // not just how often each is touched. Same call site, because a
            // second walk would be a second chance to disagree about what an
            // access is.
            traversal_note_field(t->name, i);
            return;
        }
    }
}

// **The first field never moves, and this is not a tuning choice.**
//
// The compiler puns a struct pointer as `String` and spells "this slot is empty"
// as `str_equals(ptr, "")`, which reads the *first byte of the pointed-to
// struct*. That is why NodeKind and TypeKind both reserve ordinal 0: a live node
// whose first field is zero is byte-for-byte an empty slot, and every
// node_exists in the compiler rests on it (tests/test_41_punned_slot_bytes.psm).
//
// Sorting by width puts an 8-byte pointer at offset 0, and a pointer to "" has a
// zero first byte -- so every live node with an empty `s1` began reading as
// absent. The generation built by the first compiler that did this could not
// parse its own source. SPEC 8.2 grants the compiler layout freedom; this
// implementation's representation of "absent" spends the first field of it, and
// the search has to know that rather than rediscover it.
// **Descending width alone is wrong here, and measurement is what says so.**
//
// LAYOUT 6 derives field order as a sort -- descending frequency, then descending
// alignment -- and a sort is optimal for padding only when placement starts at
// offset 0 with nothing fixed. The pinned first field breaks that: pinning a
// 4-byte `kind` leaves a 4-byte hole that only a narrow field can fill, and a
// width sort puts the widest field next and pays the padding. Measured on the
// corpus, sorting made `Health` 16 bytes -> 24 and `Sprite` 40 -> 48. It made
// nothing smaller.
//
// So placement is greedy over the running offset instead: at each step take the
// widest remaining field that needs *no* padding where the last one ended, and
// only when nothing fits fall back to the widest overall. That fills the pin's
// hole with the narrow field declaration order would have put there, and is at
// least as good as both a sort and source order everywhere on this corpus.
//
// Frequency is the tie-break rather than the primary key, and LAYOUT 6's ordering
// of the two is right for the reason it gives -- frequency decides where a
// hot/cold cut falls. There is no cut here (it needs handles), so frequency has
// nothing structural to decide and only costs padding if it leads.
static int layout_pad(int offset, int width) {
    if (width <= 0) return 0;
    int slack = offset % width;
    return slack == 0 ? 0 : width - slack;
}

void aif_layout_select(void) {
    for (int n = 0; n < nominal_count; n++) {
        Nominal* t = &nominals[n];
        if (t->is_enum || t->nfields < 3) continue;   // nothing to permute past field 0

        // The first field never moves; see above. Everything else is chosen by
        // greedy best-fit from the offset the pinned prefix left.
        int offset = t->field_bytes[0];
        for (int slot = 1; slot < t->nfields; slot++) {
            int best = -1, best_pad = 0;
            for (int c = slot; c < t->nfields; c++) {
                int f = t->order[c];
                int pad = layout_pad(offset, t->field_bytes[f]);
                if (best < 0) { best = c; best_pad = pad; continue; }
                int b = t->order[best];
                // Fits without padding beats anything that does not; then wider;
                // then hotter; then declaration index, so the order is total and
                // the output deterministic (LAYOUT 9).
                int better = 0;
                if ((pad == 0) != (best_pad == 0))            better = (pad == 0);
                else if (t->field_bytes[f] != t->field_bytes[b]) better = t->field_bytes[f] > t->field_bytes[b];
                else if (t->field_acc[f] != t->field_acc[b])     better = t->field_acc[f] > t->field_acc[b];
                else                                             better = f < b;
                if (better) { best = c; best_pad = pad; }
            }
            int chosen = t->order[best];
            t->order[best] = t->order[slot];
            t->order[slot] = chosen;
            offset += best_pad + t->field_bytes[chosen];
        }

        for (int i = 0; i < t->nfields; i++) {
            if (t->order[i] != i) { t->reordered = 1; break; }
        }
    }
}

// LAYOUT 5's cost model, ported from aif/prototype/layout.py
// **What this is for.** LAYOUT 7.2 specifies selection as
// `best := argmin over candidates(tau) of Cost(...)`, and until now this compiler
// had neither half: `aif_layout_select` above runs one greedy placement and never
// scores it, so "the top-k candidates ranked by modelled cost" (LAYOUT 8) named a
// set with one member and a function that did not exist. This is that function.
// It is **reported and not yet acted on**. Nothing below changes a byte of IR:
// `aif_layout_select` still chooses field order exactly as it did, and the
// ranking is surfaced through `prismio aif --layout` so the hot/cold cut can be
// audited before anything emits it. That ordering is deliberate -- a split object
// is two allocations and needs the whole release path (RESULTS-layout 5) before
// any of it may be emitted.
// ---------------------------------------------------------------------------
// Three deliberate divergences from the prototype, each of which changes the
// answer, and each measured rather than argued.
// ---------------------------------------------------------------------------
// **1. Candidates are AoS x splits, not AoS/SoA x splits.** The prototype ranks
// SoA and picks it: on `g1_particles.psm` it returns `SoA 5.37x`. SoA needs
// handles, which do not exist (RESULTS-layout 1), so a compiler that ranked it
// would select a layout it cannot emit -- "a manifest that describes a binary
// nobody built", which is the rule the block above this one already states for
// the search. Restricted to what codegen can produce, the same model on the same
// program returns `AoS+split(8/12) 1.44x`, and that cut is exactly the one
// `aif/evidence/bench/layout_repr.c` variant B measures at **0.87x**. The
// restriction is what makes the model useful here rather than a weaker version of
// the prototype.
// **2. The hot record carries the link word, and the prototype's does not.**
// `record_size(hot)` in layout.py is the hot fields alone, because its split is
// indexed rather than linked. This implementation's cold block hangs off the hot
// record -- that is precisely why hot/cold needs no handles -- so the hot record
// pays 8 bytes for the pointer. Particle's 8/12 cut is 72 bytes here (8 doubles +
// link) against the prototype's 64, and RESULTS-layout's "96 -> 72 bytes" is the
// linked number. Without the link word the model over-values every split, and
// most sharply the ones that barely pay.
// **3. There is no SimdCredit term, which resolves LAYOUT 5.4's defect by
// construction.** layout.py records the defect at `traversal_cost`: 5.4 subtracts
// SimdCredit from a sum of *memory* costs, so an arithmetic saving nets against
// something it has nothing to do with and the total can go negative. The
// prototype clamps with `max(0, ...)`. Here the term cannot arise: the credit is
// gated on `grouping in (SoA, AoSoA)` and this candidate set is AoS-only, so
// there is nothing to subtract and nothing to clamp. The arithmetic term itself
// is layout-invariant -- it is the same for every candidate of a type -- so it
// cannot move an argmin and is not computed. **This does not resolve the
// specification defect**, it only means this port never reaches it; 5.4 still
// needs fixing before any grouping dimension is searched.
// Integer arithmetic throughout, as LAYOUT 9 obligation 2 requires: a parallel
// float reduction can flip a tie, and layout must be reproducible.
// Costs are per element and scaled by 100 (`pi` is already in hundredths), rather
// than the prototype's per-collection absolute figures. N_ASSUMED is a common
// factor of every term, so dividing it out changes no ordering and keeps the
// products inside 64 bits by a wide margin. Only ratios are ever reported.

#define AIF_LINE        64
#define AIF_C1      (32 * 1024)
#define AIF_C2   (1024 * 1024)
#define AIF_C3   (32 * 1024 * 1024)
#define AIF_MU1          4
#define AIF_MU2         12
#define AIF_MU3         40
#define AIF_MUM        250
#define AIF_N_ASSUMED (1 << 20)   // LAYOUT 2.1: length unknown statically -> large
#define AIF_PI_SEQ      15        // hundredths, as in layout.py's PI
#define AIF_PI_RANDOM  100
#define AIF_LAMBDA_NUM   2
#define AIF_LAMBDA_DEN 100

// A loop, and the fields of one type it touches. LAYOUT 2.1's "co-accessed"
// half, which is the structural fact the model needs and a per-field count
// cannot supply: two fields with equal counts touched by *different* loops want
// opposite sides of a cut, and summed counts cannot tell them apart.
typedef struct {
    int type;               // interned nominal name
    int loop_id;
    int depth;
    int sequential;         // 1 sequential, 0 random -- see aif_traversal_elem
    Bits touched;           // by declaration index
} Traversal;

static Traversal* traversals;
static int traversal_count, traversal_cap;
static int g_loop_ids[64];
static int g_loop_depth;
static int g_loop_next_id;

void aif_traversal_begin(void) {
    if (g_loop_depth < 64) g_loop_ids[g_loop_depth] = ++g_loop_next_id;
    g_loop_depth++;
}

void aif_traversal_end(void) {
    if (g_loop_depth > 0) g_loop_depth--;
}

static Traversal* traversal_for(int type) {
    if (g_loop_depth <= 0 || g_loop_depth > 64) return NULL;
    int loop_id = g_loop_ids[g_loop_depth - 1];
    for (int i = 0; i < traversal_count; i++) {
        if (traversals[i].type == type && traversals[i].loop_id == loop_id)
            return &traversals[i];
    }
    if (traversal_count == traversal_cap) {
        traversal_cap = traversal_cap ? traversal_cap * 2 : 64;
        traversals = (Traversal*)xrealloc(traversals,
                                          (size_t)traversal_cap * sizeof(Traversal),
                                          "AIF traversals");
    }
    Traversal* t = &traversals[traversal_count++];
    t->type = type;
    t->loop_id = loop_id;
    t->depth = g_loop_depth;
    // Random until something says otherwise. The prototype's default is the same
    // and for the same reason: a field walked through a chain of member accesses
    // (`n.world.px`) is a pointer chase, and treating an unproven walk as
    // sequential would credit a split with locality nothing established.
    t->sequential = 0;
    t->touched.w = NULL;
    t->touched.nwords = 0;
    return t;
}

// The walk calls this when a loop binds a container element -- `let p =
// list_get(ps, i)`. That is the shape the cost model's `sequential` means: the
// records are visited in container order, so a smaller hot record puts more of
// them per line.
//
// **Weaker than the prototype's rule, and the difference is nameable.**
// layout.py additionally requires the index to be an induction variable of the
// loop, so `list_get(ps, perm[i])` -- a gather -- is random there and sequential
// here. No loop in `tests/`, `aif/corpus/` or `aif/evidence/` indexes a container
// by anything but its own counter, so the two rules agree on every program in
// this tree; the divergence is recorded because the first gather written will
// separate them, and it will do so silently.
void aif_traversal_elem(const char* type, int sequential) {
    int id = nominal_find(type);
    if (id < 0) return;
    Traversal* t = traversal_for(nominals[id].name);
    if (t) t->sequential = sequential ? 1 : 0;
}

static void traversal_note_field(int type_name, int field_index) {
    Traversal* t = traversal_for(type_name);
    if (!t) return;
    bits_set(&t->touched, field_index, "AIF traversal fields");
}

static void traversals_reset(void) {
    for (int i = 0; i < traversal_count; i++) free(traversals[i].touched.w);
    free(traversals);
    traversals = NULL;
    traversal_count = traversal_cap = 0;
    g_loop_depth = 0;
    g_loop_next_id = 0;
}

// Size of a subset of a type's fields, padded, fields placed widest-first --
// layout.py's record_size. `link` adds the 8-byte pointer to the cold block; see
// divergence 2 above.
static int record_size_of(Nominal* t, Bits* subset, int link) {
    int off = 0;
    for (int width = 8; width >= 1; width >>= 1) {
        for (int i = 0; i < t->nfields; i++) {
            if (!bits_test(subset, i)) continue;
            int w = t->field_bytes[i];
            if (w > 8) w = 8;
            if (w != width) continue;
            int a = t->field_bytes[i] < 8 ? t->field_bytes[i] : 8;
            if (a > 0 && off % a) off += a - off % a;
            off += t->field_bytes[i];
        }
    }
    if (link) {
        if (off % 8) off += 8 - off % 8;
        off += 8;
    }
    if (off < 1) off = 1;
    return (off + 7) / 8 * 8;
}

static int min_size_of(Nominal* t) {
    int s = 0;
    for (int i = 0; i < t->nfields; i++) s += t->field_bytes[i];
    return s;
}

static int mu_for(long long footprint) {
    if (footprint <= AIF_C1) return AIF_MU1;
    if (footprint <= AIF_C2) return AIF_MU2;
    if (footprint <= AIF_C3) return AIF_MU3;
    return AIF_MUM;
}

static long long iters_of(int depth) {
    long long it = 1;
    int d = depth < 1 ? 1 : depth;
    if (d > 6) d = 6;
    for (int i = 0; i < d; i++) it *= AIF_LOOP_ITERS;
    return it;
}

// LAYOUT 5's Cost for one candidate: `hot` is the set kept in the primary
// allocation, everything else splits cold. Returns cost per element, x100.
static long long layout_cost(Nominal* t, Bits* hot, int is_split) {
    int hot_size = record_size_of(t, hot, is_split);
    Bits cold;
    cold.w = NULL;
    cold.nwords = 0;
    int cold_size = 0;
    if (is_split) {
        for (int i = 0; i < t->nfields; i++)
            if (!bits_test(hot, i)) bits_set(&cold, i, "AIF cold group");
        cold_size = record_size_of(t, &cold, 0);
    }

    long long total = 0;
    for (int i = 0; i < traversal_count; i++) {
        Traversal* tr = &traversals[i];
        if (tr->type != t->name) continue;

        int hot_touched = 0, cold_touched = 0;
        for (int f = 0; f < t->nfields; f++) {
            if (!bits_test(&tr->touched, f)) continue;
            if (bits_test(hot, f)) hot_touched = 1;
            else                   cold_touched = 1;
        }
        if (!hot_touched && !cold_touched) continue;

        long long iters = iters_of(tr->depth);
        if (!tr->sequential) {
            // A pointer chase pays a line per group it lands in, so a split that
            // both halves are read through costs a second miss. This is the term
            // that stops the model splitting everything.
            int groups = (hot_touched ? 1 : 0) + (cold_touched ? 1 : 0);
            long long bytes_per = (long long)groups * AIF_LINE;
            long long fp = (long long)AIF_N_ASSUMED * (hot_size < 1 ? 1 : hot_size);
            total += iters * bytes_per * mu_for(fp) * AIF_PI_RANDOM / AIF_LINE;
        } else {
            // The hot record is walked in container order.
            long long fp = (long long)AIF_N_ASSUMED * (hot_size < 1 ? 1 : hot_size);
            total += iters * hot_size * mu_for(fp) * AIF_PI_SEQ / AIF_LINE;

            // **A cold touch is a pointer chase, not a longer scan, and this is
            // the one place the port must not follow the prototype.**
            //
            // layout.py adds `record_size(cold)` to the bytes scanned, which is
            // correct for the split it models -- cold[i] sits at a computed
            // offset in a parallel block, so reaching it is more streaming. This
            // implementation's cold block is *linked*: the hot record holds a
            // pointer to it, which is exactly why hot/cold needs no handles
            // (RESULTS-layout 2). Reaching a cold field is therefore a dependent
            // load into a separately malloc'd block -- a miss at random-access
            // probability, not 32 more bytes of sequential scan.
            //
            // **It changes the answer, and the prototype's margin says why it has
            // to.** On g1, layout.py ranks its top two candidates 1188M and
            // 1180M -- 0.7% apart -- and prefers 8/12 by that margin over a cut
            // that pushes five of `integrate`'s six fields cold. Ported
            // faithfully, the link word alone flips it: this compiler scored
            // 2/12 at 73 against 8/12 at 75. Two candidates whose real
            // performance differs enormously were being separated by less than
            // the model's own noise. With the chase priced, 8/12 wins at 75
            // against 314, which agrees with layout_repr.c's measured 0.87x for
            // exactly that cut.
            if (cold_touched) {
                long long cfp = (long long)AIF_N_ASSUMED * (cold_size < 1 ? 1 : cold_size);
                total += iters * AIF_LINE * mu_for(cfp) * AIF_PI_RANDOM / AIF_LINE;
            }
        }
    }

    // LAYOUT 5's footprint penalty: padding the layout added over the packed
    // minimum, weighted by lambda. Scaled x100 to match the traversal term.
    int size = hot_size + cold_size;
    int slack = size - min_size_of(t);
    if (slack > 0) total += (long long)slack * AIF_LAMBDA_NUM * 100 / AIF_LAMBDA_DEN;

    free(cold.w);
    return total;
}

// ---------------------------------------------------------------------------
// The candidate space (LAYOUT 6), and the ranking LAYOUT 8 asks for.
//
// Cuts are taken at strict frequency boundaries down the access-count ranking,
// which is layout.py's `candidates`. **The first boundary is not the answer** --
// on Particle it cuts 2/12 and pushes `integrate`'s own six fields cold, which is
// slower, not faster. Only scoring every cut finds 8/12. That is the argument for
// this file existing rather than a `rank[i] > rank[i+1]` test in the search.
//
// Field 0 of the *chosen order* is pinned hot and never offered to a cut: the
// punned-slot invariant is about the first byte of the object
// (tests/test_41_punned_slot_bytes.psm), and a cut by frequency alone would
// happily put a never-read field there.
// ---------------------------------------------------------------------------

#define AIF_MAX_CANDIDATES 32

typedef struct {
    int hot_count;              // fields in the hot group, including the pinned one
    long long cost;
    Bits hot;
} Candidate;

static Candidate g_cands[AIF_MAX_CANDIDATES];
static int g_cand_count;
static int g_cand_type = -1;
static int g_cand_best;

static void candidates_clear(void) {
    for (int i = 0; i < g_cand_count; i++) free(g_cands[i].hot.w);
    g_cand_count = 0;
    g_cand_type = -1;
    g_cand_best = 0;
}

// Ranks every admissible layout for `type`, cheapest first-scoring wins. Returns
// the number of candidates, 0 when the type is not splittable at all.
int aif_layout_rank(const char* type) {
    candidates_clear();
    int id = nominal_find(type);
    if (id < 0) return 0;
    Nominal* t = &nominals[id];
    if (t->is_enum || t->nfields < 3) return 0;
    g_cand_type = t->name;

    // Candidate 0 is the unsplit record -- the baseline every ratio is against,
    // and a real candidate: if no split beats it, none is taken.
    Bits all;
    all.w = NULL;
    all.nwords = 0;
    for (int i = 0; i < t->nfields; i++) bits_set(&all, i, "AIF layout baseline");
    g_cands[0].hot_count = t->nfields;
    g_cands[0].hot = all;
    g_cands[0].cost = layout_cost(t, &all, 0);
    g_cand_count = 1;

    // Rank the movable fields by access count descending, then by declaration
    // index, so the order is total and the output deterministic (LAYOUT 9).
    int pinned = t->order[0];
    int rank[256], nrank = 0;
    for (int i = 0; i < t->nfields && nrank < 256; i++)
        if (i != pinned) rank[nrank++] = i;
    for (int a = 0; a < nrank; a++) {
        for (int b = a + 1; b < nrank; b++) {
            int x = rank[a], y = rank[b];
            int swap = t->field_acc[y] > t->field_acc[x]
                       || (t->field_acc[y] == t->field_acc[x] && y < x);
            if (swap) { rank[a] = y; rank[b] = x; }
        }
    }

    for (int cut = 1; cut < nrank && g_cand_count < AIF_MAX_CANDIDATES; cut++) {
        if (t->field_acc[rank[cut - 1]] == t->field_acc[rank[cut]]) continue;
        Bits hot;
        hot.w = NULL;
        hot.nwords = 0;
        bits_set(&hot, pinned, "AIF hot group");
        for (int i = 0; i < cut; i++) bits_set(&hot, rank[i], "AIF hot group");
        Candidate* c = &g_cands[g_cand_count++];
        c->hot_count = cut + 1;
        c->hot = hot;
        c->cost = layout_cost(t, &hot, 1);
    }

    g_cand_best = 0;
    for (int i = 1; i < g_cand_count; i++) {
        // Strictly cheaper wins, so a tie keeps the unsplit record: a split costs
        // a second allocation and a second free at run time, and none of that is
        // in the model.
        if (g_cands[i].cost < g_cands[g_cand_best].cost) g_cand_best = i;
    }
    return g_cand_count;
}

int aif_layout_candidates(void)        { return g_cand_count; }
int aif_layout_best(void)              { return g_cand_best; }
int aif_layout_cand_hot(int i)         { return (i >= 0 && i < g_cand_count) ? g_cands[i].hot_count : 0; }

// LAYOUT 8 compiles "the top-k candidates, ranked by modelled cost". `g_cands` is
// in cut order and `g_cand_best` is only the argmin, so the ranking is computed
// here rather than stored: k = 0 is the argmin, k = 1 the next cheapest, and so on.
//
// Ties break on the candidate index, which is LAYOUT 9.1's total order -- the
// candidates are generated in increasing cut order, so the index *is* the split
// rank, and a tie between two equal-cost cuts resolves the same way on every host
// rather than by whichever the scan reached first.
int aif_layout_cand_at_rank(int k) {
    if (k < 0 || k >= g_cand_count) return -1;
    // Selection rather than a sort: g_cands must stay in cut order, because every
    // other accessor here is indexed by it and the report prints it in that order.
    int prev = -1;
    for (int rank = 0; rank <= k; rank++) {
        int pick = -1;
        for (int i = 0; i < g_cand_count; i++) {
            // Skip everything at or before `prev` in the (cost, index) order.
            if (prev >= 0 && (g_cands[i].cost < g_cands[prev].cost ||
                              (g_cands[i].cost == g_cands[prev].cost && i <= prev)))
                continue;
            // `i` ascends, so a strict `<` leaves ties on the lower index.
            if (pick < 0 || g_cands[i].cost < g_cands[pick].cost) pick = i;
        }
        if (pick < 0) return -1;
        prev = pick;
    }
    return prev;
}

// ---------------------------------------------------------------------------
// LAYOUT 8's forced candidate
//
// §8 selects a layout by *measuring* the top-k candidates instead of trusting the
// model's argmin, and §7.2's argmin is the only thing wired to codegen -- so the
// one mechanism §8 needs that does not exist is a way to say "emit this candidate,
// not the cheapest one". This is that, and it is deliberately the whole of it: the
// search loop, the timing and the manifest record are the frontend's business.
//
// **A candidate is named by its hot-field count, not by its rank.** Ranks move
// whenever the cost model changes, so a manifest record or a reproduction command
// naming "the 2nd best candidate" stops meaning the same layout the moment a
// constant is retuned. `hot_count` is a property of the layout itself, and it is
// what `--layout` already prints (`split 8/12`), so the number a human reads off
// the report is the number they can force.
//
// **It lives outside the Nominal table.** aif_reset tears every Nominal down, and
// a declared `workload` runs the whole engine twice in one process (LAYOUT 3.2) --
// so a force stored on the type would apply to the instrumented pass and silently
// not to the real one, which is the pass that ships. Keyed by name string for the
// same reason: the interned ids are per-run too.
//
// **A force that matches nothing is reported, not ignored.** Naming a type that is
// not in the program, or a cut that is not a candidate, is the shape of mistake
// this project has made most -- an instrument that matched nothing and reported
// success. `aif_layout_force_applied` is how the frontend can raise it.
// ---------------------------------------------------------------------------

#define AIF_MAX_FORCED 32

typedef struct {
    char* type;
    int hot_count;
    int applied;
} Forced;

static Forced g_forced[AIF_MAX_FORCED];
static int g_forced_count;

void aif_layout_force(const char* type, int hot_count) {
    if (!type || hot_count < 1) return;
    for (int i = 0; i < g_forced_count; i++) {
        if (strcmp(g_forced[i].type, type) == 0) {
            g_forced[i].hot_count = hot_count;   // last writer wins, so a repeated
            g_forced[i].applied = 0;             // --force-layout is not two forces
            return;
        }
    }
    if (g_forced_count >= AIF_MAX_FORCED) return;
    size_t n = strlen(type) + 1;
    char* copy = (char*)xmalloc(n, "AIF forced layout");
    memcpy(copy, type, n);
    g_forced[g_forced_count].type = copy;
    g_forced[g_forced_count].hot_count = hot_count;
    g_forced[g_forced_count].applied = 0;
    g_forced_count++;
}

// -1 when `type` carries no force, which is the common case and the one the
// selection loop asks about per type.
static int forced_hot_for(const char* type) {
    for (int i = 0; i < g_forced_count; i++)
        if (strcmp(g_forced[i].type, type) == 0) return g_forced[i].hot_count;
    return -1;
}

static void forced_mark_applied(const char* type) {
    for (int i = 0; i < g_forced_count; i++)
        if (strcmp(g_forced[i].type, type) == 0) g_forced[i].applied = 1;
}

int aif_layout_forced_count(void) { return g_forced_count; }

const char* aif_layout_forced_type(int i) {
    return (i >= 0 && i < g_forced_count) ? g_forced[i].type : "";
}

int aif_layout_forced_hot(int i) {
    return (i >= 0 && i < g_forced_count) ? g_forced[i].hot_count : 0;
}

int aif_layout_force_applied(int i) {
    return (i >= 0 && i < g_forced_count) ? g_forced[i].applied : 0;
}

// Costs are reported as a ratio against the unsplit baseline, x100, because the
// absolute figure is in units nobody can act on. 100 means "no better than not
// splitting"; 87 would mean the model expects 0.87x.
int aif_layout_cand_ratio(int i) {
    if (i < 0 || i >= g_cand_count || g_cand_count == 0) return 100;
    long long base = g_cands[0].cost;
    if (base <= 0) return 100;
    return (int)(g_cands[i].cost * 100 / base);
}

// Whether field `f` (declaration index) is hot in candidate `i`. The report needs
// it to name the cold fields, which is the part a reader can act on.
int aif_layout_cand_field_hot(int i, int f) {
    if (i < 0 || i >= g_cand_count) return 1;
    return bits_test(&g_cands[i].hot, f) ? 1 : 0;
}

int aif_layout_cand_bytes(int i, int cold) {
    if (i < 0 || i >= g_cand_count || g_cand_type < 0) return 0;
    int id = nominal_find_id(g_cand_type);
    if (id < 0) return 0;
    Nominal* t = &nominals[id];
    int is_split = g_cands[i].hot_count < t->nfields;
    if (!cold) return record_size_of(t, &g_cands[i].hot, is_split);
    if (!is_split) return 0;
    Bits c;
    c.w = NULL;
    c.nwords = 0;
    for (int f = 0; f < t->nfields; f++)
        if (!bits_test(&g_cands[i].hot, f)) bits_set(&c, f, "AIF cold group");
    int b = record_size_of(t, &c, 0);
    free(c.w);
    return b;
}

// ---------------------------------------------------------------------------
// LAYOUT 6's hot/cold split, taken rather than reported
//
// The ranking above scores every admissible cut; this decides which one codegen
// emits. The split is **linked** (LAYOUT 5.2.1): the hot record ends in a pointer
// to a separately allocated cold block, which is why it needs no handles, and
// which is also why a split object is *two* allocations and every release path
// has to know it.
//
// **Three vetoes, and each is a way the second allocation cannot be reached --
// not a way it would be slow.** The cost model decides the rest.
//
//   1. `no_split`, pushed in by the frontend for any type embedded **inline** in
//      another struct. An inline field is storage inside its owner: nothing calls
//      an allocator for it, so its link word would hold whatever the owner's
//      allocation left there and the first cold read would be a wild load. The
//      predicate is `typeAnnIsPod` + `ir_is_struct_type_name`, asked once in
//      src/aif/layout.psm -- the same pair `fieldTypeFor` asks to decide
//      inline-ness in the first place, so the two cannot drift.
//   2. A type in a **non-trivial SCC**, i.e. a T4b candidate. `cyc_free_object`
//      calls the generated release on the *payload* while the object's base is
//      `payload - CYC_HDR`; forcing a release onto a type that reaches itself
//      would put a second block behind that asymmetry. T4b splits are excluded
//      because the collector's release contract is a separate question, not
//      because they are hard.
//   3. Fewer than three fields, or an enum -- there is no cut past the pinned
//      field 0.
//   4. **A type with no sequential traversal.** This one is a measurement, and it
//      is the third time on this project that a measurement has refuted the cost
//      model. The mechanism RESULTS-layout 2 measured is that a walk *in container
//      order* over smaller hot records streams less and packs closer -- 0.87x on
//      g1's shape. A type nobody walks in container order collects the split's
//      cost, a dependent miss per cold touch, and none of that benefit. The model
//      nevertheless prefers a split for such types, and the reason is nameable:
//      `mu_for` reads a cache tier off `AIF_N_ASSUMED * hot_size`, and
//      AIF_N_ASSUMED is a fabricated 2^20 for every type in the program, so
//      shaving 8 bytes off a *singleton* can cross a tier boundary and divide its
//      modelled cost by six. Measured, interleaved, 20 pairs: g4's `World` -- one
//      instance, six fields, five of them Lists -- was split 2/6 at a modelled 24
//      and ran at 1.04x. LAYOUT 10.4 already records that static frequency
//      estimation is crude; this is the clause that stops it choosing a layout.
//   5. **A type with an inline struct field.** The model does not know how big
//      such a type is. `aifDeclare` sizes every field with `aifTypeBytes`, which
//      answers 8 for a struct-typed field because the struct registry is empty
//      during the analysis -- so `g3_scene_graph`'s `Node`, whose two inline
//      `Transform`s are 48 bytes each, is modelled as 40 bytes and is really 112.
//      A cut chosen from a shape that wrong is not a choice. Measured: Node was
//      split 4/7 at a modelled 12 and ran at 1.11x, the largest regression in the
//      corpus. Sizing inline fields correctly would move Theta_stack and therefore
//      tiers, which is a separate change; declining to choose is not.
//
// Field 0 of the chosen order is pinned hot by `aif_layout_rank` and never
// offered to a cut, because the punned-slot invariant is about the first byte of
// the object (tests/test_41_punned_slot_bytes.psm). The split cannot move it, and
// `str_equals(ptr, "")` still reads what it read.
//
// Runs after `aif_layout_select` and after `aifComputeSizes`, and *before* the
// solve. Before the solve because `type_releases_of` reads the answer; after the
// sizes because the sizes are computed from the unsplit order on purpose -- see
// aif_layout_field_bytes.
// ---------------------------------------------------------------------------

void aif_layout_no_split(const char* type) {
    int id = nominal_find(type);
    if (id >= 0) nominals[id].no_split = 1;
}

// Veto 5's channel, separate from veto 1's because LAYOUT 8 may override this one
// and must never override that one. Both are pushed in by aifLayoutVetoInline from
// the same discovery -- a struct with an inline struct field -- but they say
// different things: the *field's type* cannot be split at all (no allocator hook
// writes its link word), while the *owner* merely cannot be modelled, because
// aifTypeBytes sizes that field as one pointer. The owner's split is sound.
void aif_layout_no_split_unmodelled(const char* type) {
    int id = nominal_find(type);
    if (id >= 0) nominals[id].no_split_unmodelled = 1;
}

// Veto 4's test. `sequential` is set by aif_traversal_elem when a loop binds a
// container element -- `let p = list_get(ps, i)` -- which is exactly the shape
// layout_repr.c measured and the only shape the 0.87x is evidence for.
static int has_sequential_traversal(int id) {
    for (int i = 0; i < traversal_count; i++) {
        if (traversals[i].type == nominals[id].name && traversals[i].sequential)
            return 1;
    }
    return 0;
}

// `forced` says a human named this type's cut, so the two vetoes that exist
// because the *model* had no basis to choose (4 and 5) are not reasons to decline
// -- gathering the missing evidence is what LAYOUT 8 does. The three that say the
// cold block cannot be reached are checked either way, and a force cannot clear
// them: no measurement makes a wild load or a double free acceptable.
static int split_admissible(int id, int forced) {
    Nominal* t = &nominals[id];
    if (t->is_enum || t->nfields < 3) return 0;    // veto 3
    if (t->no_split) return 0;                     // veto 1, and veto 2 via the frontend
    if (bits_test(&t->reaches, id)) return 0;      // veto 2
    if (forced) return 1;
    if (t->no_split_unmodelled) return 0;          // veto 5
    if (!has_sequential_traversal(id)) return 0;   // veto 4
    return 1;
}

// The candidate whose hot group is exactly `hot_count` fields, or -1. Cuts are
// generated one per distinct access-count boundary, so at most one candidate has
// any given hot_count and this is a lookup rather than a search for a best match.
static int candidate_with_hot(int hot_count) {
    for (int i = 0; i < g_cand_count; i++)
        if (g_cands[i].hot_count == hot_count) return i;
    return -1;
}

void aif_layout_split_select(void) {
    for (int n = 0; n < nominal_count; n++) {
        Nominal* t = &nominals[n];
        t->hot_count = 0;
        bits_free(&t->hot);
        t->hot.w = NULL;
        t->hot.nwords = 0;
        int forced = forced_hot_for(aif_str(t->name));
        if (!split_admissible(n, forced >= 0)) continue;
        if (aif_layout_rank(aif_str(t->name)) < 2) continue;

        int pick = g_cand_best;
        if (forced >= 0) {
            // A forced cut still has to *be* a candidate. Anything else would let
            // a typo emit a layout the model never scored and the report never
            // printed -- and `--layout`'s table is where the number came from.
            int match = candidate_with_hot(forced);
            if (match >= 0) {
                forced_mark_applied(aif_str(t->name));
                pick = match;
            } else if (!split_admissible(n, 0)) {
                // **"Did not apply" has to mean nothing changed**, and getting
                // here by `continue` is what it meant for one build of this
                // function: an unmatched force left hot_count at 0, so a mistyped
                // cut did not fall back to the argmin, it turned the split *off*.
                // A search script would then measure the unsplit record, be told
                // by the warning that its force missed, and still have a plausible
                // number filed against a cut nothing emitted.
                //
                // So an unmatched force falls through to the argmin -- except for a
                // type that only became admissible *because* it was forced, where
                // the argmin is a split the vetoes had excluded. Re-asking without
                // the force is what distinguishes the two, and it is the same
                // question this loop already answered a few lines up.
                continue;
            }
        }

        // Candidate 0 is the unsplit record and wins ties, so `pick != 0` already
        // means "strictly cheaper than not splitting" (see aif_layout_rank). A
        // force of the unsplit candidate lands here too, and correctly: it applied,
        // and what it asked for is no split.
        if (pick == 0) continue;
        int hc = g_cands[pick].hot_count;
        if (hc < 1 || hc >= t->nfields) continue;
        for (int f = 0; f < t->nfields; f++) {
            if (bits_test(&g_cands[pick].hot, f))
                bits_set(&t->hot, f, "AIF hot group");
        }
        t->hot_count = hc;
    }
    candidates_clear();
}

// How many fields the hot record keeps, or 0 when the type is not split. Codegen
// reads it once per type and passes it straight to ir_struct_type_split; the
// backend needs no other AIF fact to emit the whole transform.
int aif_layout_hot_count(const char* type) {
    int id = nominal_find(type);
    return id >= 0 ? nominals[id].hot_count : 0;
}

// The declaration index of the field placed i-th in the order codegen emits.
//
// Unsplit that is `order` and nothing else. Split, it is `order` read twice --
// the hot fields in placement order, then the cold ones -- so the emitted index
// space is exactly `[0, hot_count)` hot and `[hot_count, nfields)` cold, and
// ir_struct_field_ptr can decide which side a field is on by comparing one
// integer.
static int split_slot(Nominal* t, int i) {
    if (t->hot_count <= 0) return t->order[i];
    int seen = 0;
    for (int j = 0; j < t->nfields; j++) {
        int f = t->order[j];
        if (!bits_test(&t->hot, f)) continue;
        if (seen == i) return f;
        seen++;
    }
    for (int j = 0; j < t->nfields; j++) {
        int f = t->order[j];
        if (bits_test(&t->hot, f)) continue;
        if (seen == i) return f;
        seen++;
    }
    return t->order[i];
}

// How many traversals the profile recorded for a type. A type with none is one
// the model has nothing to say about, and the report says so rather than printing
// a ratio derived from an empty sum.
int aif_layout_traversals(const char* type) {
    int id = nominal_find(type);
    if (id < 0) return 0;
    int n = 0;
    for (int i = 0; i < traversal_count; i++)
        if (traversals[i].type == nominals[id].name) n++;
    return n;
}

// The i-th field of `type` in the chosen order, or "" when there is none. Codegen
// reads this to emit the struct body, and ir_register_struct_field follows in the
// same loop -- so the name -> index map and the LLVM type stay in lockstep and
// every field access follows without knowing anything about layout.
const char* aif_layout_field(const char* type, int i) {
    int id = nominal_find(type);
    if (id < 0) return "";
    Nominal* t = &nominals[id];
    if (i < 0 || i >= t->nfields) return "";
    return aif_str(t->field_name[split_slot(t, i)]);
}

int aif_layout_reordered(const char* type) {
    int id = nominal_find(type);
    return id >= 0 ? nominals[id].reordered : 0;
}

// The width of the field placed i-th, so the size computation walks the layout
// the search chose rather than the one the source wrote.
//
// **Deliberately `order` and not `split_slot`, and the link word is deliberately
// not counted.** This feeds aifComputeSizes, which feeds Theta_stack, which the
// T0 clause reads -- so anything this returns can move a tier. The split is
// chosen *after* the sizes are computed for exactly that reason: layout selection
// runs before the solve (SPEC 7.2, test_49's note) so that a layout cannot change
// what the analysis concludes, and a split that added 8 bytes per object to the
// stack budget would be layout feeding back into the solve that chose it. The
// cost is that a split T0 object's frame is understated by one pointer per
// object; the alternative is a cycle.
int aif_layout_field_bytes(const char* type, int i) {
    int id = nominal_find(type);
    if (id < 0) return 0;
    Nominal* t = &nominals[id];
    if (i < 0 || i >= t->nfields) return 0;
    return t->field_bytes[t->order[i]];
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

typedef struct {
    int type;       // interned type display name
    int kind;
    int fn;
    int ordinal;    // position among its function's sites, in walk order
    int scope;
    int file, line, col;
    int nfields;
    // M3.2. Position of the statement this site sits in, within its own block,
    // or -1 where the walk did not stamp one. A scope is a lexical *set* of
    // statements and says nothing about their order, so an extent that ends at
    // last use rather than at the closing brace cannot be expressed without
    // this. Recorded ahead of the analysis that reads it, and inert until then.
    int stmt;
    int bytes;          // stamped once, before iteration
    int E, A, C, T;
    int type_acyclic;   // stamped once, before iteration
    int no_stack;       // explicitly dropped -- see AIF_CON_NO_STACK
    // The allocation is the *callee's*: this is a produced extern return, so
    // this frame owns the pointer but there is nothing here to place. Distinct
    // from `no_stack`, which additionally says somebody else performs the free
    // and therefore bars the scope release -- a produced return needs exactly
    // the opposite, T0 refused and the release kept. See AIF_CON_FOREIGN.
    int foreign;
    // Ownership left this frame: an FFI `consume` takes it, and the callee frees
    // it. Distinct from `no_stack`, which both a `drop` and a transfer set --
    // "this cannot live in a stack slot" is true of both, but "somebody else
    // will free it" is only true of a transfer. Conflating them is what made an
    // explicit `drop` anywhere suppress the release of every other binding that
    // shared the site; splitting them is what keeps a *consumed* value from
    // being released here as well as by its consumer.
    int transferred;
    // Stored into a container by a `retain_in` call. The container owns it from
    // that point on, which is what makes a container teardown a release point --
    // and what takes the value's own binding off the drop list.
    int in_container;
    // SPEC 5.1. `unique` asserts A = Unique and cuts the aliasing graph: a rule
    // that would raise A above Unique is suppressed rather than applied.
    int alias_axiom;
    int alias_suppressed;   // the axiom actually stopped a rule; reported
    // SPEC 5.4. The tier a `pin` froze, or -1. Applied after convergence.
    int pin_tier;
    int pin_verdict;        // AIF_PIN_*, decided by aif_check_pins
    // SPEC 5.4 on placement rather than on the tier: the interned name of the
    // `region` a `pin(<region-name>)` asserted must serve this value, or -1.
    // Separate from pin_tier because they are orthogonal claims about one site
    // and a single slot would make `let pin(T2) pin(frame) x` silently drop one
    // of them.
    int pin_region;
    int pin_region_verdict; // AIF_PIN_*, decided by aif_check_placement_pins
} Site;

// SPEC 5.4's four outcomes, plus "there is no pin here".
#define AIF_PIN_NONE     0
#define AIF_PIN_HONOURED 1
#define AIF_PIN_REFUTED  2   // converged facts make it unreachable -- an error
#define AIF_PIN_UNPROVEN 3   // budget ran out -- a warning, and the pin is dropped

static Site* sites;
static int site_count, site_cap;
static int orphan_sites;    // sites with no enclosing function; none today

// The statement the walk is currently inside, in the same style as aif_con_at's
// source position: set by the frontend as it goes, read by whatever gets
// created next. -1 means "not stamped", which is what every site had before
// M3.2 and what any construction the walk reaches by another path still has.
static int g_stmt = -1;

// Per scope, the statement of *that* scope the walk is currently inside. The
// array rather than a single cursor is what makes a nested use answerable: while
// the walk is down inside a nested block, scope_stmt[outer] still names the
// statement of `outer` that contains it, because only `outer`'s own chain ever
// writes it. That is exactly the question an extent has to answer -- "which
// statement of the region does this use pin open" -- and a single cursor would
// have already been overwritten by the inner block.
static int* scope_stmt;
static int scope_stmt_cap;

static void scope_stmt_grow(int scope) {
    if (scope < scope_stmt_cap) return;
    int grow = scope_stmt_cap ? scope_stmt_cap * 2 : 256;
    if (grow <= scope) grow = scope + 1;
    scope_stmt = (int*)xrealloc(scope_stmt, (size_t)grow * sizeof(int), "AIF statement positions");
    for (int i = scope_stmt_cap; i < grow; i++) scope_stmt[i] = -1;
    scope_stmt_cap = grow;
}

void aif_stmt_at(int scope, int index) {
    g_stmt = index < 0 ? -1 : index;
    if (scope < 0) return;
    scope_stmt_grow(scope);
    scope_stmt[scope] = g_stmt;
}

// M3.2b. The last statement, in a key's own declaring scope, at which the key is
// read. The end of a non-lexical extent is the maximum of this over the keys
// holding what the arena serves.
//
// **Monotone by construction, which is why one slot is enough.** Statements are
// walked in source order, so scope_stmt[d] only ever grows while d's chain is
// being walked; taking the max over mentions therefore lands on the last one
// without having to know in advance which mention that is.
static int* key_last_stmt;
static int key_last_stmt_cap;

static void key_last_stmt_grow(int key) {
    if (key < key_last_stmt_cap) return;
    int grow = key_last_stmt_cap ? key_last_stmt_cap * 2 : 1024;
    if (grow <= key) grow = key + 1;
    key_last_stmt = (int*)xrealloc(key_last_stmt, (size_t)grow * sizeof(int), "AIF last use");
    for (int i = key_last_stmt_cap; i < grow; i++) key_last_stmt[i] = -1;
    key_last_stmt_cap = grow;
}



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
    s->stmt = g_stmt;
    s->bytes = 0;
    s->type_acyclic = 1;
    s->no_stack = 0;
    s->foreign = 0;
    s->transferred = 0;
    s->in_container = 0;
    s->alias_axiom = 0;
    s->alias_suppressed = 0;
    s->pin_tier = -1;
    s->pin_verdict = AIF_PIN_NONE;
    s->pin_region = -1;
    s->pin_region_verdict = AIF_PIN_NONE;
    // Bottom, per INFERENCE 5.2 line 2: Region(defscope), Unique, Acyclic,
    // Isolated. T-DEFAULT is this line and nothing else -- "any node has
    // T >= Isolated" is a statement about the bottom element, not a rule that
    // has to fire.
    s->E = scope;
    s->A = AIF_A_UNIQUE;
    s->C = AIF_C_ACYCLIC;
    s->T = AIF_T_ISOLATED;
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

// Points-to keys
// A key names a location that can hold references: a local binding, a struct
// field (field-sensitive, object-insensitive -- INFERENCE 3.1), a return
// position, or a parameter. Identity is the tuple, so the same name in two
// functions is two keys, and `Lexer.source` is one key across every Lexer.

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

// Called at every read of a binding. Declines rather than guesses in the two
// cases where the answer would not mean anything: a name with no declaration on
// record yet (a global, or an assignment the walk reached first -- the same case
// aif_var_scope returns -1 for), and a read that is not underneath its declaring
// scope's statement list at all.
void aif_var_note_use(int fn, const char* name, int scope) {
    (void)scope;
    int key = aif_key_var(fn, name);
    int d = (key < var_scope_cap) ? var_scope[key] : -1;
    if (d < 0 || d >= scope_stmt_cap) return;
    int at = scope_stmt[d];
    if (at < 0) return;
    key_last_stmt_grow(key);
    if (at > key_last_stmt[key]) key_last_stmt[key] = at;
}

int aif_key_last_stmt(int key) {
    return (key < 0 || key >= key_last_stmt_cap) ? -1 : key_last_stmt[key];
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

// Value-set expressions
// The set of sites an expression may denote: part known while walking (a struct
// literal is its own site), part only at the fixed point (an identifier is
// whatever its binding points to). Holding both in one object is what lets the
// AST walk compose expressions uniformly without knowing which it has.
// Items are tagged integers -- an even item is a site, an odd item is a key.

typedef struct {
    int* items;
    int len, cap;
    // SPEC 8.4 view provenance: the collections these values are views *of*,
    // held as value-set ids and resolved with everything else at solve time.
    // Empty for every value set that is not a view, which is nearly all of them.
    int* views;
    int vlen, vcap;
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
    v->views = NULL;
    v->vlen = 0;
    v->vcap = 0;
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

static void vs_push_view(int vs, int cvs) {
    if (vs < 0 || vs >= vs_count || cvs < 0) return;
    ValueSet* v = &vsets[vs];
    for (int i = 0; i < v->vlen; i++) {
        if (v->views[i] == cvs) return;
    }
    if (v->vlen == v->vcap) {
        v->vcap = v->vcap ? v->vcap * 2 : 2;
        v->views = (int*)xrealloc(v->views, (size_t)v->vcap * sizeof(int), "AIF view provenance");
    }
    v->views[v->vlen++] = cvs;
}

// SPEC 8.4. Mark this value set as denoting views of `container_vs`.
//
// Provenance rather than a points-to edge, and the difference is the whole of
// item 3's reconciliation. The element key still says *which values* a read can
// return -- that is what stores through the result need, and merging the
// container into it is the bug that made a receiving container call
// list_release on a struct. Provenance says something the points-to graph
// cannot: *how long the container must live* for the reference to be legal.
void aif_vs_view_of(int vs, int container_vs) { vs_push_view(vs, container_vs); }

int aif_vs_is_empty(int vs) {
    return (vs < 0 || vs >= vs_count) ? 1 : (vsets[vs].len == 0);
}

int aif_vs_union(int a, int b) {
    int out = aif_vs_new();
    if (a >= 0 && a < vs_count) {
        for (int i = 0; i < vsets[a].len; i++) vs_push(out, vsets[a].items[i]);
        for (int i = 0; i < vsets[a].vlen; i++) vs_push_view(out, vsets[a].views[i]);
    }
    if (b >= 0 && b < vs_count) {
        for (int i = 0; i < vsets[b].len; i++) vs_push(out, vsets[b].items[i]);
        for (int i = 0; i < vsets[b].vlen; i++) vs_push_view(out, vsets[b].views[i]);
    }
    return out;
}

// Argument stacks
// Two FFI contracts refer to another argument of the same call: `retain_in(k)`
// says "the callee stores me into argument k", and `alias` says "my return is
// argument k". Both need the call's arguments addressable by index while it is
// being walked -- and calls nest, because an argument can itself be a call.
// Evaluating an argument creates allocation sites, so it must happen exactly
// once; re-walking to find argument k would duplicate every site inside it.
// Hence a stack: the frontend opens a frame, pushes each argument's value set
// as it evaluates it, indexes freely, and closes the frame.

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

// Constraints
// One entry per transfer-rule instance the AST walk discovered. Solving is
// re-applying all of them until nothing rises.

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
#define AIF_CON_TRANSFERRED   24
#define AIF_CON_FOREIGN       25
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
#define AIF_RULE_A_CONTAIN   15

// SPEC 8.4. A view of a collection -- a slice, or a reference to one element.
//
// Appended after the synthetic rules rather than inserted beside the other
// constraints because AIF_RULE_ALLOC's ordinal is spelled again in
// src/aif/model.psm. Renumbering here would rename the derivation root there,
// and the two would disagree without either one failing to build.
#define AIF_CON_VIEW_OF      16

// SPEC 5.4 applied to placement: `pin(<region-name>)`. Appended for the same
// reason AIF_CON_VIEW_OF was -- AIF_RULE_ALLOC's ordinal is written out again in
// src/aif/model.psm, so inserting anything below 16 renames the derivation root
// there and neither side fails to build.
//
// `b` is the interned region name, not a tier. Applied in the same pass as
// AIF_CON_PIN because it is an assertion about the result and not a transfer
// rule; *adjudicated* much later than AIF_CON_PIN, because what it asserts is an
// output of arena placement, which has not run yet.
#define AIF_CON_PIN_REGION   17

// REQUIREMENTS 15, INFERENCE 4.1/4.3. The arguments of one `spawn`.
//
// Appended for the third time for the same reason AIF_CON_VIEW_OF and
// AIF_CON_PIN_REGION were: AIF_RULE_ALLOC's ordinal 14 is written out again in
// src/aif/model.psm, so anything inserted below it renames the derivation root
// there and neither side fails to build.
//
// One constraint per spawn site rather than one per argument. E-SPAWN-J's
// premise -- "joined on every path before scope s exits" -- is a property of
// the *call*, and splitting it per argument would make each one re-derive it.
// `b` carries the enclosing scope so E-SPAWN-J has somewhere to bind to; `c` is
// 1 when the task is joined in that scope and 0 when it is not.
#define AIF_CON_SPAWN        18

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
void aif_con_return(int vs, int fn)              { con_add(AIF_CON_ESCAPE_CALLER, vs, fn, 1); }
void aif_con_escape_global(int vs)              { con_add(AIF_CON_ESCAPE_GLOBAL, vs, 0, 0); }
void aif_con_unique(int vs)                     { con_add(AIF_CON_UNIQUE, vs, 0, 0); }
void aif_con_pin(int vs, int tier)              { con_add(AIF_CON_PIN, vs, tier, 0); }
// INFERENCE 4.3's T-STATIC premise is "the program creates any task", which is
// a whole-program property and therefore not something a per-site rule can ask.
// Recorded as the constraints are built rather than scanned for later, so a
// module with no spawn never pays for the question.
static int program_has_tasks;

int aif_program_has_tasks(void) { return program_has_tasks; }

void aif_con_spawn(int vs, int scope, int joined) {
    program_has_tasks = 1;
    con_add(AIF_CON_SPAWN, vs, scope, joined);
}

void aif_con_pin_region(int vs, const char* name) {
    con_add(AIF_CON_PIN_REGION, vs, aif_intern(name), 0);
}

// SPEC 8.4's E-VIEW is not a constraint. It rides the rules that already bound
// how long a value lives, because that bound is exactly what its collection has
// to satisfy -- see raise_view_owners. AIF_CON_VIEW_OF survives only as the
// rule *name* the derivation prints; aif_vs_view_of is what attaches it.

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
void aif_con_transferred(int vs)                { con_add(AIF_CON_TRANSFERRED, vs, 0, 0); }
void aif_con_foreign(int vs)                    { con_add(AIF_CON_FOREIGN, vs, 0, 0); }

int aif_con_count(void) { return con_count; }

static Bits* pt;            // key id -> set of sites
static Bits* holders;       // site id -> set of keys holding it
// site id -> set of *container sites* holding it. Separate from `holders`, which
// counts keys -- named locations the move checker governs. A container element is
// neither: `list_push` is a call, so nothing about it is a move, and two pushes
// of one value are two owners the language never had to notice.
static Bits* container_of;
// SPEC 8.4. key id -> set of *collection sites* that values bound to this key
// are views of. Provenance has to ride the points-to graph and not the value
// set alone, because a view is nearly always bound to a name before it travels:
//
//     let e = list_get(items, i)      // provenance attaches to this value set
//     return e                        // ...and must still be here
//
// The `return` sees the value set of the identifier `e`, which is a key
// reference with no view of its own. So a key accumulates the provenance of
// everything bound into it, and resolve_views unions the direct provenance with
// every key's. Grown in the points-to phase, which reads no fact -- so this is
// a points-to-shaped relation and it converges with the rest of that phase.
static Bits* key_views;
static int pt_len, holders_len;
static Bits scratch_val, scratch_own, scratch_views;
static IntVec vec_val, vec_own, vec_views;
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

// The derivation DAG (INFERENCE 5.6, SPEC 6.3)
// A manifest diff has to answer *why* a tier moved, and the answer is a witness
// path from a root cause to the record. INFERENCE 5.6 specifies a backward BFS
// through **maximal contributors**: for a fact `f` at node `n` holding value
// `v`, the predecessors whose transfer produced `v`.
// Keeping every predecessor and searching backward is one way to get that. This
// keeps **one edge per site per domain** instead, written the moment a rule
// first raises the fact to the value it ends at -- which is a maximal
// contributor by construction, because a rule that raises is one that set the
// value rather than one that merely failed to contradict it. Walking those edges
// backward is then a chain rather than a search.
// Two honest consequences of that choice:
//   * The path is *a* witness, not provably the *shortest* one. The first rule
//     to reach the final value is recorded, which is the shortest among the
//     rules that fired in that round, but a different constraint order could
//     have produced a shorter chain. INFERENCE 5.1 permits the order to vary,
//     so "shortest" was never stable anyway.
//   * Memory is O(sites), not O(edges). 5.6's requirement is that the DAG be
//     *retained through tier assignment*, and one maximal edge per fact is
//     enough to retain what a diff reads back.

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
static int force_rule = -1; // ...or E-VIEW, which rides other constraints (SPEC 8.4)

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
    // SPEC 8.4. A provenance raise is E-VIEW whichever constraint carried it --
    // the constraint says where the view escaped to, the rule says why the
    // collection had to follow. The file:line stays the constraint's, because
    // "the read that produced the view" is not the useful place to point: the
    // use that let it outlive the scope is.
    d[site].rule  = (force_rule >= 0) ? force_rule
                                      : (live ? cons[cur_con].kind : synth_rule);
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
    container_of = (Bits*)xcalloc((size_t)holders_len, sizeof(Bits), "AIF container holders");
    key_views = (Bits*)xcalloc((size_t)pt_len, sizeof(Bits), "AIF view provenance");
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

// SPEC 8.4. The collections whose lifetime this value set depends on: its own
// provenance, plus that of every key it reads through.
//
// Not recursive past one key hop, and it does not need to be -- a key's set is
// already the union of everything ever bound into it, provenance included, so
// the transitive closure is taken by the points-to fixed point rather than here.
static void resolve_views(int vs, Bits* out) {
    bits_clear(out);
    if (vs < 0 || vs >= vs_count) return;
    ValueSet* v = &vsets[vs];
    for (int i = 0; i < v->vlen; i++) {
        static Bits tmp;                     // reentrancy is not possible: no rule nests this
        resolve(v->views[i], &tmp);
        bits_or(out, &tmp, "AIF view provenance");
    }
    for (int i = 0; i < v->len; i++) {
        int item = v->items[i];
        if (item & 1) {
            int key = item >> 1;
            if (key < pt_len) bits_or(out, &key_views[key], "AIF view provenance");
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

// SPEC 8.4 E-VIEW:  v is a view of c  =>  E(c) ⊒ E(v).
//
// Applied wherever a rule bounds how long the *view* lives, because that bound
// is exactly what the collection has to satisfy. `target` is the escape the
// caller's rule just established for the view; `in_fn` is the function that
// bound is expressed in, or -1 when the target is function-independent.
//
// **The direction is the opposite of every other rule in this solver, and that
// is the whole mechanism.** Everywhere else a value inherits a fact from
// something holding it; here the *collection* is raised to cover the view,
// because a view must not outlive what it views. A view that escapes to the
// caller forces the collection to escape to the caller -- the collection sinks
// a tier and compilation succeeds, where Rust's borrow checker would reject the
// program. That is SPEC 1's invariant applied to views, and it is why `a[i]`
// needs no lifetime annotation here.
//
// **A is deliberately untouched.** SPEC 8.4 permits overlapping mutable views:
// a view is not a second holder, and two views of one collection in one task
// threaten neither property this model claims (no use-after-free, no data
// race). Raising A here would import Rust's no-aliasing property, which AIF
// does not have and does not want.
static int raise_view_owners(int vs, int target, int in_fn) {
    resolve_views(vs, &scratch_views);
    if (bits_is_empty(&scratch_views)) return 0;
    bits_to_vec(&scratch_views, &vec_views);
    int any = 0;
    force_rule = AIF_CON_VIEW_OF;
    for (int i = 0; i < vec_views.len; i++) {
        int c = vec_views.v[i];
        // A Region target is a scope id, and a scope id means something only
        // inside the function that owns it. When the collection was allocated
        // in a *different* function, this rule contributes nothing -- and that
        // is a case analysis, not a shortcut. The view is bound in a scope of
        // `in_fn`, so it dies with that activation, and the collection reached
        // `in_fn` in exactly one of three ways:
        //
        //   - passed down as an argument, in which case it is live across the
        //     call by construction and already outlives the view;
        //   - returned up, in which case E-RETURN has it at Caller already;
        //   - read from static storage, in which case E-STATIC has it Global.
        //
        // In all three the constraint is already implied. Raising to Caller
        // "to be safe" is what demoted g5's `ents` -- a list `main` allocates
        // and `render` reads -- costing it its list_release for nothing.
        //
        // A view that outlives `in_fn` is NOT this case: escaping one is a
        // return, a store or a push, and those arrive here with a Caller,
        // Global or holder-derived target, which is function-independent and
        // passes straight through.
        if (in_fn >= 0 && sites[c].fn != in_fn
            && (target >= 0 || target == AIF_E_CALLER)) continue;
        if (raise_escape(c, target, -1)) { any = 1; moved(c); }
    }
    force_rule = -1;
    return any;
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

// INFERENCE 4.3. No axiom cuts this one: SPEC 5's four annotations say nothing
// about thread affinity, which is why `unique` has no counterpart here and why
// there is no `alias_suppressed` equivalent to record.
//
// Deliberately without a derivation edge. deriv_e and deriv_a exist so a
// manifest diff can walk a witness path back to a root (INFERENCE 5.6), and the
// domain that path walks is chosen by aif_cause_domain_for from the tier. A T4a
// site's interesting fact is *aliasing* -- see the comment there -- so a third
// Deriv array would cost one word per site to answer a question nothing asks.
static int raise_thread(int site, int level) {
    if (sites[site].T >= level) return 0;
    sites[site].T = level;
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

            // SPEC 8.4. View provenance flows with the value, into the key it
            // is bound, passed or stored into. Grown here rather than in the
            // fact loop because it reads only value sets and pt -- so it is a
            // points-to-shaped relation, and the fact phase gets to run over a
            // finished one, exactly as it does for pt itself.
            resolve_views(k->b, &scratch_views);
            if (!bits_is_empty(&scratch_views)) {
                if (bits_or(&key_views[k->a], &scratch_views, "AIF view provenance")) changed = 1;
            }

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

// Container element keys, and the one thing that makes keying them precisely
// sound (INFERENCE 3.1)
// An element read gets back whatever was pushed, through a field key on the
// container's type. Keying that on the *base* type -- `List` -- put every list
// in the program into one set: `list_get(w.actors, i)` came back holding
// `Order`s that only ever went into a different list, and obligation 3 then
// refused to bracket the call that built them, because a function outside the
// extent appeared to hold one. That is g6's whole placement, lost to a type name.
// Keying it on the full type -- `List<Actor>` against `List<Order>` -- separates
// them, and is sound **because a container's static type is the same at every
// mention**: Prismio has no subtyping, and generics are monomorphised into
// concrete types before this walk runs (src/sema/generics.psm), so `List<T>`
// never reaches here. Two spellings for one container would be a read that
// misses its own writes, which is an element that appears to escape nowhere and
// a use-after-free behind it.
// **The exception is a spelling the frontend could not resolve** -- a bare
// `List`, or `List<Invalid>` where inference had nothing to give. Those really
// can name the same container as a resolved spelling elsewhere. So they are
// detected, and a base type with even one of them has all of its element keys
// bound together, which is exactly the behaviour this replaced. Precision where
// the types are known, and the old answer where they are not.

typedef struct { int base, full; } ElemKeyUse;
static ElemKeyUse* elem_uses;
static int elem_use_count, elem_use_cap;

// The container type as the frontend spelled it, up to the first `<`.
static int elem_base_of(const char* ty) {
    const char* lt = strchr(ty, '<');
    if (lt == NULL) return aif_intern(ty);
    char buf[128];
    size_t n = (size_t)(lt - ty);
    if (n >= sizeof buf) n = sizeof buf - 1;
    memcpy(buf, ty, n);
    buf[n] = '\0';
    return aif_intern(buf);
}

static int elem_spelling_resolved(const char* ty) {
    if (strchr(ty, '<') == NULL) return 0;      // a bare base names every instance
    if (strstr(ty, "Invalid") != NULL) return 0;  // inference had nothing to give
    return 1;
}

int aif_elem_key(const char* container_type) {
    if (container_type == NULL) container_type = "";
    if (elem_use_count == elem_use_cap) {
        elem_use_cap = elem_use_cap ? elem_use_cap * 2 : 64;
        elem_uses = (ElemKeyUse*)xrealloc(elem_uses, (size_t)elem_use_cap * sizeof(ElemKeyUse),
                                          "AIF element keys");
    }
    elem_uses[elem_use_count].base = elem_base_of(container_type);
    elem_uses[elem_use_count].full = aif_intern(container_type);
    elem_use_count++;
    return aif_key_field(container_type, "@elem");
}

// Run before the solve, because it adds constraints. Binds both ways, so the
// base key and every precise key of a tainted base hold the same set -- which is
// the pre-2026-08-28 answer, restored for exactly the types that need it.
static void elem_key_reconcile(void) {
    int trace = getenv("AIF_BRACKET_TRACE") != NULL;
    for (int i = 0; i < elem_use_count; i++) {
        if (elem_spelling_resolved(aif_str(elem_uses[i].full))) continue;
        int base = elem_uses[i].base;
        // Loud, because the consequence shows up a long way from the cause: with
        // the base merged, an element read comes back holding every element of
        // every container of that base, and the site it wrongly names is what
        // obligation 3 then refuses to bracket.
        if (trace) {
            fprintf(stderr, "aif: element keys for `%s` merged -- `%s` is not a "
                            "resolved container type\n",
                    aif_str(base), aif_str(elem_uses[i].full));
        }
        for (int j = 0; j < elem_use_count; j++) {
            if (elem_uses[j].base != base) continue;
            int precise = aif_key_field(aif_str(elem_uses[j].full), "@elem");
            int bare = aif_key_field(aif_str(base), "@elem");
            if (precise == bare) continue;
            int a = aif_vs_new();
            aif_vs_key(a, bare);
            aif_con_bind(precise, a);
            int b = aif_vs_new();
            aif_vs_key(b, precise);
            aif_con_bind(bare, b);
        }
    }
}

int aif_solve(int max_rounds) {
    elem_key_reconcile();
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
        if (k->kind != AIF_CON_UNIQUE && k->kind != AIF_CON_PIN
            && k->kind != AIF_CON_PIN_REGION) continue;
        resolve(k->a, &scratch_val);
        bits_to_vec(&scratch_val, &vec_val);
        for (int i = 0; i < vec_val.len; i++) {
            if (k->kind == AIF_CON_UNIQUE) {
                sites[vec_val.v[i]].alias_axiom = 1;
            } else if (k->kind == AIF_CON_PIN_REGION) {
                // First writer wins, unlike the tier pin below, and there is no
                // "stricter reading" to prefer: two region names on one site are
                // two incompatible claims, not two strengths of one claim. The
                // second is left to refute on its own site rather than silently
                // replacing the first.
                if (sites[vec_val.v[i]].pin_region < 0) {
                    sites[vec_val.v[i]].pin_region = k->b;
                }
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
                        // T-REACH: and so is thread affinity. A value reachable
                        // from something a task can see is something that task
                        // can see.
                        if (raise_thread(s, sites[o].T)) changed = moved(s);
                    }
                }
                // E-VIEW: storing a view into a field makes the viewed
                // collection live at least as long as the object holding it.
                for (int j = 0; j < vec_own.len; j++) {
                    if (raise_view_owners(k->b, sites[vec_own.v[j]].E,
                                          sites[vec_own.v[j]].fn)) changed = 1;
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
                // E-VIEW: this binding is how long the view lives, so it is how
                // long the collection has to.
                if (raise_view_owners(k->a, k->b, k->c)) changed = 1;

            } else if (k->kind == AIF_CON_OPAQUE) {
                resolve(k->a, &scratch_val);
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    int s = vec_val.v[i];
                    if (sites[s].E != AIF_E_GLOBAL && raise_escape(s, AIF_E_CALLER, -1)) changed = moved(s);
                    if (raise_alias(s, AIF_A_SHARED, -1)) changed = moved(s);
                }
                // A view handed to something we cannot see could be kept.
                if (raise_view_owners(k->a, AIF_E_CALLER, -1)) changed = 1;

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
                        // T-REACH, through a container rather than a field.
                        if (raise_thread(s, sites[h].T)) changed = moved(s);
                        // Which containers hold it, not merely that one does. The
                        // count is the fact A-CONTAIN reads, and it is the only
                        // thing separating "the container owns this, free it at
                        // teardown" from a double free through the second one.
                        if (bits_set(&container_of[s], h, "AIF container holders")) {
                            changed = moved(s);
                        }
                    }
                    if (!sites[s].in_container && vec_own.len > 0) {
                        sites[s].in_container = 1;
                        changed = moved(s);
                    }
                    if (raise_alias(s, AIF_A_BORROWED, -1)) changed = moved(s);
                }
                // E-VIEW: pushing a view into a container makes the viewed
                // collection live at least as long as that container.
                for (int j = 0; j < vec_own.len; j++) {
                    if (raise_view_owners(k->a, sites[vec_own.v[j]].E,
                                          sites[vec_own.v[j]].fn)) changed = 1;
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
                // E-VIEW, and the case the safety gap was actually about:
                // `return list_get(l, i)` hands the caller a reference into a
                // collection this frame owns. The collection follows it out.
                // A returned view of a collection allocated here must carry it
                // out. A view of a parameter does not extend the caller's
                // collection to *its* caller: it was already live across this
                // activation, and the caller's binding supplies the real bound.
                // `c` distinguishes a source-level return from other
                // escape-to-caller constraints such as FFI consume.
                if (raise_view_owners(k->a, AIF_E_CALLER, k->c ? k->b : -1)) changed = 1;

            } else if (k->kind == AIF_CON_TRANSFERRED) {
                resolve(k->a, &scratch_val);
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    if (!sites[vec_val.v[i]].transferred) {
                        sites[vec_val.v[i]].transferred = 1;
                        changed = moved(vec_val.v[i]);
                    }
                }

            } else if (k->kind == AIF_CON_FOREIGN) {
                resolve(k->a, &scratch_val);
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    if (!sites[vec_val.v[i]].foreign) {
                        sites[vec_val.v[i]].foreign = 1;
                        changed = moved(vec_val.v[i]);
                    }
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

            } else if (k->kind == AIF_CON_SPAWN) {
                // INFERENCE 4.1's E-SPAWN / E-SPAWN-J and 4.3's T-SPAWN-MOVE /
                // T-SPAWN-SHARE, which are the same four arguments seen through
                // two domains.
                resolve(k->a, &scratch_val);
                bits_to_vec(&scratch_val, &vec_val);
                for (int i = 0; i < vec_val.len; i++) {
                    int s = vec_val.v[i];

                    if (k->c) {
                        // E-SPAWN-J. The task is joined on every path before the
                        // scope exits, so the argument has to outlive the join
                        // and nothing more. This is the clause INFERENCE calls
                        // "where structured concurrency pays": it is the whole
                        // difference between concurrent code at T1 and the same
                        // code at T4.
                        if (raise_escape(s, k->b, -1)) changed = moved(s);
                    } else {
                        // E-SPAWN. An unjoined task may outlive every scope in
                        // this function, so the value is reachable from a root
                        // this analysis cannot see the end of.
                        if (sites[s].E != AIF_E_GLOBAL) {
                            sites[s].E = AIF_E_GLOBAL;
                            note_deriv(deriv_e, s, -1, AIF_E_GLOBAL);
                            changed = moved(s);
                        }
                    }

                    // T-SPAWN-MOVE. The argument was moved in -- sema's
                    // semaConsumeOperand guarantees it, and the move checker
                    // enforces it -- so exactly one task can reach it at a time.
                    // Transferred, not CrossThread: this is the case T3's
                    // non-atomic count is sound for.
                    if (raise_thread(s, AIF_T_TRANSFERRED)) changed = moved(s);

                    // T-SPAWN-SHARE is *not* here. It is a per-site rule
                    // below, because the argument is not the only thing a task
                    // can reach -- everything reachable from it is too, and
                    // that is where the sharing actually shows up.
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

            // A-CONTAIN: two containers holding one value is sharing, whatever
            // the type.
            //
            // A-COPY exempts move-only values because a second *binding* is a
            // move, so the earlier one is provably dead. That argument does not
            // reach a container: `list_push(l, x)` is a call, and a call is not a
            // move -- so `store(l1, x); store(l2, x)` puts one value under two
            // owners with nothing in the language to notice. Once a container
            // teardown releases its elements, that is the double free.
            //
            // Making it Shared is not a workaround for the gap; it is the correct
            // reading, and it lands the value on the tier built for exactly this
            // shape. One container owns and frees (T2); two share and count (T3).
            synth_rule = AIF_RULE_A_CONTAIN;
            if (bits_count_at_least_two(&container_of[s])
                && raise_alias(s, AIF_A_SHARED, -1)) {
                changed = moved(s);
            }

            // T-SPAWN-SHARE. Stated as a per-site rule over the two facts
            // rather than as a clause on the spawn, and both halves of that
            // are deliberate.
            //
            // **Why the premise is `A = Shared` and not syntax.** INFERENCE
            // writes it as "y is still live in the parent". Under affine
            // references that is never syntactically true: the move checker
            // rejects any program that names the value twice. But a value can
            // be live in the parent without its *binding* being -- two
            // containers holding one element, one moved into a task and one
            // retained, is the ordinary shape and no binding names it twice.
            // `Shared` is exactly INFERENCE 2.2's "two or more references
            // whose relative lifetimes are not statically ordered", so a
            // Shared value that a task can reach is one nothing proved the
            // parent dropped. This is the same move C-UNIQUE makes one domain
            // over (INFERENCE 4.4): the aliasing module does the work and the
            // derived domain reads its answer.
            //
            // **Why per-site and not on the spawn's arguments.** Testing the
            // arguments alone was the first version and it was unsound. The
            // spawn's argument is the *container*; the shared thing is the
            // element, which reaches Transferred through T-REACH and never
            // appears in any spawn's value set. tests/aif_concurrency_shared.psm
            // is that program, and it derived T3 with a non-atomic count for a
            // value two threads could reach.
            //
            // Read as one sentence: a value that crosses a task boundary at
            // all, and has two references nothing ordered, is cross-thread.
            // `unique` earns its keep twice here -- an axiom holding A at
            // Unique keeps a transferred value off the atomic path.
            if (sites[s].T >= AIF_T_TRANSFERRED && sites[s].A >= AIF_A_SHARED
                && raise_thread(s, AIF_T_CROSS)) {
                changed = moved(s);
            }

            // T-STATIC. A static root in a program with concurrency is
            // assumed reachable from every task.
            //
            // INFERENCE calls this "deliberately blunt" and it is: refining it
            // wants a global reachability analysis whose payoff is small in a
            // language where static mutable roots are rare. What the bluntness
            // buys is the honest answer to "when is T4a actually reachable?" --
            // under isolation, a value cannot be shared by being passed around,
            // so the static root is the residue, and it is the residue *because*
            // the rest of the design closed the other doors.
            if (program_has_tasks && sites[s].E == AIF_E_GLOBAL
                && raise_thread(s, AIF_T_CROSS)) {
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
        // Top of the T lattice too -- but only where a task exists to reach
        // it from. Omitting the raise entirely would make a truncated build
        // *cheaper* than a converged one, an atomic count skipped because the
        // budget ran out, which is the exact unsoundness INFERENCE 5.3
        // introduces widening to prevent.
        //
        // The guard is not a weakening of that. Widening raises a site to top
        // because the analysis ran out of rounds to prove otherwise; "this
        // program contains no spawn" is not something it was trying to prove,
        // it is something the constraint set already said, and no number of
        // further rounds could contradict it. So CrossThread in a task-free
        // module is not conservatism, it is a false statement that costs
        // atomics -- and SPEC 1's invariant is that inference failure degrades
        // performance, which this keeps to the programs that have tasks.
        if (program_has_tasks) sites[s].T = AIF_T_CROSS;
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

// Tier derivation (SPEC 4.2)
// Here rather than in Prismio because the first clause needs defscope(s), and
// the escape encoding that makes that comparison a single integer test is this
// file's private business. The derivation itself is the spec's, clause for
// clause, first match wins.
// Theta_stack is approximated by field count: at this stage the frontend has no
// layout, so a byte threshold is not available. SPEC 4.2 requires the threshold
// be documented by the implementation -- it is emitted in the manifest header.
// T4a was unreachable by construction until 2026-08-19, because the language had
// no tasks and the thread domain was vacuous. REQUIREMENTS 15 built the task
// model and the two `T` conjuncts below are no longer tautologies.
// **The single-threaded path is unchanged, and it is unchanged structurally
// rather than by measurement.** A module with no `spawn` raises no site above
// AIF_T_ISOLATED: T-SPAWN-* fires only on a spawn constraint, T-REACH can only
// propagate a value some rule already raised, and T-STATIC is guarded on
// program_has_tasks. So `T <= AIF_T_TRANSFERRED` holds at every site, both new
// conjuncts are true, and T4a is unreachable -- exactly the shape the clauses
// had before. This is the property the whole design is for, so it is stated
// where the clauses are and not only in a document.

#define AIF_THETA_STACK_FIELDS 8
#define AIF_THETA_STACK_BYTES 256

#define AIF_THETA_MODE_BYTES  0
#define AIF_THETA_MODE_FIELDS 1

#define AIF_T0  0
#define AIF_T1  1
#define AIF_T2  2
#define AIF_T3  3
#define AIF_T4B 4
// SPEC 3 is emphatic that "T4 is one tier, not two", and these are its two
// sub-classes rather than two tiers. They still need distinct ordinals, because
// the manifest names them separately and `pin` adjudicates numerically.
//
// T4a above T4b is a real decision and this is the argument for it. The order
// has to be a linear extension of the fact lattice for aif_check_pins to stay
// sound (SPEC 4.3's monotonicity), and it has to make raising T never *lower*
// the ordinal: from <Transferred, MaybeCyclic> = T4b, raising T to CrossThread
// must not go down. Putting T4a on top satisfies both, and it makes the useful
// pin the honest one -- `pin(T4a)` on a T3 site asks for an atomic count and is
// granted, `pin(T4b)` on a T4a site asks to drop one and is refuted.
#define AIF_T4A 5

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
    // in_container joins no_stack here for the same reason it sits next to it in
    // the drop predicate: the container reclaims its elements, and a frame slot is
    // not something a deallocator can take. Reachable whenever the container and
    // the element share a scope, which keeps E at that scope and every other T0
    // conjunct satisfied.
    // `foreign` joins them for a third reason: T0 says the value lives in this
    // frame's storage, and a produced extern return has no allocation here to
    // move there. Without it a struct handed over by a runtime call could reach
    // T0, and T0 is "no runtime bookkeeping" -- so nothing released it. Only
    // reachable since `chan_recv` became the first extern return of struct kind;
    // every earlier producer returns a String, which is not AIF_K_STRUCT and so
    // was never a T0 candidate.
    if (s->E == s->scope && s->A <= AIF_A_BORROWED
        && s->kind == AIF_K_STRUCT && fits_on_stack(s)
        && !s->no_stack && !s->foreign && !s->in_container) {
        return AIF_T0;
    }
    // Neither the T1 clause nor T0's tests T, and that is SPEC 4.2 read
    // literally rather than an omission. A value whose escape bottoms inside a
    // region did not leave it, and E-SPAWN-J is what keeps a joined task's
    // arguments there -- which is INFERENCE 4.1's "this single distinction
    // determines whether concurrent code lands at T1 or T4", visible here as
    // the absence of a test.
    if (s->E != AIF_E_CALLER && s->E != AIF_E_GLOBAL) return AIF_T1;
    if (s->A <= AIF_A_BORROWED && s->T <= AIF_T_TRANSFERRED) return AIF_T2;
    if (s->T <= AIF_T_TRANSFERRED && s->C == AIF_C_ACYCLIC) return AIF_T3;
    // SPEC 3: "a value meeting both conditions pays both". The sub-class named
    // here is the one that decides the *count*, because that is what codegen
    // reads it for; a T4a site that is also cyclic still reports C =
    // MaybeCyclic through aif_site_cyclic, so collector registration is
    // decided from the fact and not from this name.
    if (s->T == AIF_T_CROSS) return AIF_T4A;
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

// INFERENCE 2.3, read back. Codegen needs it to choose an atomic count, and the
// manifest needs it to say why.
int aif_site_thread(int id) {
    if (id < 0 || id >= site_count) return AIF_T_CROSS;
    return sites[id].T;
}

int aif_site_alias_axiom(int id) {
    if (id < 0 || id >= site_count) return 0;
    return sites[id].alias_axiom;
}

// Minimal cause (INFERENCE 5.6, SPEC 6.3)
// Walk the derivation backward from a site through maximal contributors until a
// root -- an allocation, an axiom, or a rule with no incoming site. The result
// is the witness path SPEC 6.3 prints under "minimal cause", innermost edge
// first, which is the order it reads in: the change, then what made the change
// matter.
// Which domain to walk is decided by the tier, and that mapping is the reason
// the two are kept separately. A T1 -> T2 move is an *escape* question and a
// T2 -> T3 move is an *aliasing* one; showing the E path for a value that lost
// its tier to sharing would be a confident answer to the wrong question.

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
    if (rule == AIF_RULE_A_CONTAIN)     return "A-CONTAIN";
    if (rule == AIF_CON_VIEW_OF)        return "E-VIEW";
    if (rule == AIF_RULE_ALLOC)         return "ALLOC";
    return "?";
}

// Tier lookup by AST node
// Codegen has to ask "what tier is the value this expression allocates?", and
// the answer has to survive the gap between the two passes. The join key is the
// node itself: the AIF pass and codegen walk the same in-memory tree in the same
// process, so the address the parser allocated is a name for the expression that
// costs nothing to carry and cannot collide.
// It replaces a file:line:col key, which could: an array literal and its first
// element start at the same column, and `[str_concat(a,b), ...]` puts a site at
// each. That key had to resolve a collision by keeping the *highest* tier, since
// codegen reads T0 as permission to use a stack slot and rounding down there is
// heap corruption. Nothing rounds now -- one node, one site.

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

// Automatic arena placement (LAYOUT 7.1)
//     ArenaBenefit(s) = allocs_in(s)·(α_T2 − α_T1)
//                     − entries(s)·arenaSetupCost
//                     − λ·(bytes_held(s) − peak_live_bytes(s))
// Every scope is already an implicit region (SPEC 4.1), so the question is not
// which scopes *could* have an arena but which ones are worth the setup. Both
// inputs are supposed to come from an access profile; there is no profiler, so
// they are estimated statically and the estimate is stated rather than hidden:
//   entries(s)     factors out. It multiplies both terms once `allocs_in` is
//                  written as "allocations per entry of s", so the *sign* of the
//                  benefit -- which is the only thing the decision reads -- does
//                  not depend on it. That is why no loop-trip estimate above s
//                  is needed, and it is the reason to write the model this way.
//   allocs_in(s)   per entry: one per site the arena would serve, weighted by
//                  AIF_LOOP_ITERS for each loop between the site and s, since a
//                  site in a loop inside s allocates many times per entry.
//   bytes_held(s)  what the arena accumulates over one entry: the same weighted
//                  sum, in bytes. An arena reclaims nothing until its scope
//                  exits, so this is what it is holding at the end.
//   peak_live(s)   what would be live at once if each value were reclaimed when
//                  it died: one instance per site, unweighted. Two sites in one
//                  loop body are both live, so it is a sum over sites and not a
//                  maximum over them.
// The third term is the footprint one, and it is the only term that can make a
// scope decline an arena on grounds other than speed. Their difference is
// Σ bytes·(weight − 1): exactly the bytes a scope allocates and then abandons
// while holding on to them. A scope that allocates a great deal in a loop and
// keeps almost none of it live now takes individual objects, which is the
// trade LAYOUT 4 defines λ for and which the first two terms alone cannot see --
// they are both counts, so arena-vs-object was decided purely on speed.
// Both new inputs are static estimates, like allocs_in above: bytes come from
// the computed layout and the weight from AIF_LOOP_ITERS. A site whose size is
// not statically known contributes 0 to both, so it moves the decision by
// nothing rather than by a guess -- the same rule the peak-bytes report uses.
// Placement is greedy innermost-first, which needs no separate nesting rule.
// A site can only be served by an arena its escape bottoms at or below, so an
// inner arena takes exactly the values that die earlier -- LAYOUT's condition
// for an inner arena being worth it, satisfied by construction rather than by a
// heuristic. Whatever the inner one cannot take, the next one out sees.
// Ties break by scope id, which is creation order and therefore node order
// (LAYOUT 7.1 last line).

#define AIF_ALPHA_T1        3     // LAYOUT 4: allocation cycles at T1 (bump)
#define AIF_ALPHA_T2        90    //           and at T2 (a general allocator)
#define AIF_ARENA_SETUP    40     // LAYOUT 4: ~one block acquisition plus reset
// LAYOUT 4's λ, cache-pressure cost per wasted live byte. Kept as a ratio
// because the whole model is integer: 0.02 exactly, not a rounded 0.
#define AIF_LAMBDA_NUM      2
#define AIF_LAMBDA_DEN      100

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
    // Nothing was allocated here to route into the arena. The pointer is the
    // callee's heap block; bulk-resetting a region does not reclaim it, so an
    // arena would take the site off the drop list and free nothing in its place.
    if (s->foreign) return 0;
    if (s->kind == AIF_K_LIST) return 0;            // grows past its site; see below
    // The container reclaims it, so codegen will not route it here whatever this
    // model decides -- site_arena_scope declines on the same flag. Counting it as
    // benefit placed arenas whose whole justification was traffic they would never
    // see, which is the automatic-placement form of the inert `region`.
    if (s->in_container) return 0;
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

// SPEC 5.2.1.1, as an *input* to placement rather than a consequence of it: what
// a bracketed call sitting in `cand` would serve, had `cand` an arena. Defined
// with the bracket machinery below, because it asks that machinery's obligations
// rather than a second copy of them, and declared here because aif_place_arenas
// is its only caller.
static long bracket_candidate_serves(int cand, long* held, long* live);

// M3.2c. Defined with the bracket machinery it reads; declared here because the
// trace in aif_place_arenas is the first thing to ask for it.
static int arena_stmt_range(int scope, int* first, int* last);

// M3.2c-ii, the same range asked of a scope that has no arena yet -- declared up
// here for the same reason, and defined next to c-i because the two share the
// half that decides which keys hold what the arena serves.
static int cand_stmt_range(int scope, int* first, int* last);

// M3.2d's choice between the two, which is what codegen emits and therefore what
// the trace has to print.
static int arena_emit_range(int scope, int* first, int* last);

// Placement is the input to bracketing now, so a bracket answer cached before
// placement ran is stale. aif_check_pins asks for one, so this is not
// hypothetical.
static void bracket_invalidate(void);

// 1 once aif_place_arenas has run. Read by bracket_place to decide whether a
// cost-model arena is a region it may bracket into -- see the note above
// enclosing_pinned_region for why the answer used to be "never".
static int arenas_placed;

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
        long held = 0;
        long live = 0;
        for (int k = 0; k < site_count; k++) {
            if (!arena_would_serve(k, s)) continue;
            long w = weight_of(sites[k].scope, s);
            served += w;
            held += (long)sites[k].bytes * w;
            live += (long)sites[k].bytes;
        }
        // The other half of the traffic, and on this corpus it is nearly all of
        // it: 198 of 236 blocked sites are in a callee, where arena_would_serve
        // cannot reach them by construction -- enclosing_region walks a lexical
        // tree rooted per function, so scope_lca across two owners is -1 whatever
        // the escape says. Those sites are asked of the bracket obligations
        // instead, which are a call-graph question and answer across functions.
        //
        // This is the clause that makes an automatic region worth placing on g2:
        // every DrawCmd in the frame loop is allocated inside `cull`, so the
        // lexical sum above is 0 and the scope was never a candidate at all.
        served += bracket_candidate_serves(s, &held, &live);
        if (served == 0) continue;

        long benefit = served * (AIF_ALPHA_T2 - AIF_ALPHA_T1)
                     - (long)AIF_ARENA_SETUP
                     - (AIF_LAMBDA_NUM * (held - live)) / AIF_LAMBDA_DEN;
        if (benefit > 0) scopes[s].arena = 1;
    }

    // From here a cost-model arena is as good a region to bracket into as a
    // written one, and any answer cached while that was false has to go.
    arenas_placed = 1;
    bracket_invalidate();

    // M3.2b's data, on demand. A field nothing reads yet is a field nothing has
    // checked, and "the IR did not change" only proves it is inert -- not that
    // it is right. Sibling of AIF_BRACKET_TRACE, and prints once because
    // aif_place_arenas runs once.
    if (getenv("AIF_STMT_TRACE") != NULL) {
        for (int s = 0; s < scope_count; s++) {
            if (!scopes[s].arena) continue;
            int lo = -1, hi = -1;
            if (arena_stmt_range(s, &lo, &hi)) {
                fprintf(stderr, "aif: arena scope %d extent [%d,%d]%s\n", s, lo, hi,
                        scopes[s].region_name >= 0 ? " (written)" : " (auto)");
            } else {
                fprintf(stderr, "aif: arena scope %d extent whole-block%s\n", s,
                        scopes[s].region_name >= 0 ? " (written)" : " (auto)");
            }
            // What codegen will actually bracket, which is the answer that
            // matters and is not always c-i's -- see arena_emit_range.
            int elo = -1, ehi = -1;
            if (arena_emit_range(s, &elo, &ehi)) {
                fprintf(stderr, "aif: arena scope %d emit [%d,%d]\n", s, elo, ehi);
            } else {
                fprintf(stderr, "aif: arena scope %d emit whole-block\n", s);
            }
        }
        // And the candidate ranges, over every scope the obligation could have
        // asked about. This is the half c-i cannot show: a scope printed here
        // and absent above is one that has no arena *because* of what follows
        // from the range -- which on `g2.psm` is the whole point.
        for (int s = 0; s < scope_count; s++) {
            int lo = -1, hi = -1;
            if (!cand_stmt_range(s, &lo, &hi)) continue;
            fprintf(stderr, "aif: candidate scope %d extent [%d,%d]%s\n", s, lo, hi,
                    scopes[s].arena ? " (placed)" : " (not placed)");
        }
        // Over the buckets rather than key_by_id, which is built further down
        // the file than this runs.
        for (int b = 0; b < AIF_KEY_BUCKETS; b++) {
            for (KeyNode* kn = key_buckets[b]; kn; kn = kn->next) {
                if (kn->kind != AIF_KEY_VAR) continue;
                int last = aif_key_last_stmt(kn->id);
                if (last < 0) continue;
                int d = (kn->id < var_scope_cap) ? var_scope[kn->id] : -1;
                fprintf(stderr, "aif: last-use %s.%s scope %d stmt %d\n",
                        kn->a >= 0 && kn->a < fn_count ? aif_str(fns[kn->a].name) : "?",
                        aif_str(kn->b), d, last);
            }
        }
    }
}

// REQUIREMENTS 19 -- memory budget reporting
// The arena high-water mark, statically estimated. Fixed budgets are a hard
// constraint on console targets, and arenas are what make one tractable: a
// region's peak is the sum of what it serves, and the peak for a program is the
// largest sum along a **root-to-leaf chain** of arena scopes -- not the total,
// which would add sibling regions that are never live at the same time.
// Weighted by AIF_LOOP_ITERS per enclosing loop, the same estimator automatic
// placement uses for allocs_in(s), so the two cannot disagree about how much a
// scope serves.
// **It is an estimate, and the manifest says which part it cannot see.** A
// struct's size is known from its layout; a string's is its length, which is a
// run-time value. Sites whose size is not statically known are counted
// separately rather than guessed at, because a fabricated per-string constant
// would make a budget gate that passes or fails on a number nobody computed.

// SPEC 5.2.1.1's contribution, defined with the placement it comes from.
static long bracket_bytes_of(int scope, int* unsized);

long aif_arena_high_water(void) {
    if (scope_count <= 0) return 0;
    long* own = (long*)xcalloc((size_t)scope_count, sizeof(long), "AIF arena bytes");

    for (int s = 0; s < scope_count; s++) {
        if (!scopes[s].arena) continue;
        long b = 0;
        for (int k = 0; k < site_count; k++) {
            if (!arena_would_serve(k, s)) continue;
            b += (long)sites[k].bytes * weight_of(sites[k].scope, s);
        }
        own[s] = b + bracket_bytes_of(s, NULL);
    }

    long peak = 0;
    for (int s = 0; s < scope_count; s++) {
        if (!scopes[s].arena) continue;
        long chain = 0;
        for (int p = s; p >= 0; p = scopes[p].parent) {
            if (scopes[p].arena) chain += own[p];
        }
        if (chain > peak) peak = chain;
    }

    free(own);
    return peak;
}

// What one region's arena serves, for the `pin(N)` gate. Its own scope only:
// a nested region has its own arena and its own cap.
static long arena_bytes_of(int scope) {
    long b = 0;
    for (int k = 0; k < site_count; k++) {
        if (!arena_would_serve(k, scope)) continue;
        b += (long)sites[k].bytes * weight_of(sites[k].scope, scope);
    }
    // SPEC 5.2.1.1. What a bracketed call routes here is memory this region
    // holds, so a `pin(N)` gate has to see it -- see bracket_bytes_of.
    return b + bracket_bytes_of(scope, NULL);
}

// REQUIREMENTS 19's gate. A refuted budget is an error for the same reason a
// refuted `pin` is (SPEC 5.4.1): it is a false assertion about one's own
// program, not an inference failure, so SPEC 1's invariant is untouched.
//
// Returns the number refuted; the frontend prints them.
int aif_budget_count(void) { return scope_count; }

long aif_scope_budget(int s)     { return (s < 0 || s >= scope_count) ? 0 : scopes[s].budget; }
long aif_scope_served(int s)     { return (s < 0 || s >= scope_count) ? 0 : arena_bytes_of(s); }
const char* aif_scope_region(int s) {
    if (s < 0 || s >= scope_count || scopes[s].region_name < 0) return "";
    return aif_str(scopes[s].region_name);
}
int aif_scope_budget_file(int s) { return (s < 0 || s >= scope_count) ? 0 : scopes[s].budget_file; }
int aif_scope_budget_line(int s) { return (s < 0 || s >= scope_count) ? 0 : scopes[s].budget_line; }
int aif_scope_budget_col(int s)  { return (s < 0 || s >= scope_count) ? 0 : scopes[s].budget_col; }

// Arena-served sites whose size is not statically known -- strings, whose length
// is a run-time value. Reported alongside the estimate so the number above is
// read as covering what it covers.
int aif_arena_unsized_sites(void) {
    int n = 0;
    for (int s = 0; s < scope_count; s++) {
        if (!scopes[s].arena) continue;
        for (int k = 0; k < site_count; k++) {
            if (arena_would_serve(k, s) && sites[k].bytes == 0) n++;
        }
        bracket_bytes_of(s, &n);    // and the bracketed ones it cannot size either
    }
    return n;
}

// The scope of the arena this BLOCK node opens, or -1. A `region` statement is
// excluded: codegen already brackets that one, and bracketing it twice would
// push two arenas and pop only the inner one at an early exit.
//
// M3.2d needs the scope and not just the fact, to ask it for a statement range,
// so the lookup is the shared thing and the predicate below is a reading of it.
static int auto_arena_scope_at_node(const void* node) {
    if (node == NULL) return -1;
    for (int s = 0; s < scope_count; s++) {
        if (scopes[s].node != node) continue;
        if (scopes[s].region_name >= 0) return -1;
        return scopes[s].arena ? s : -1;
    }
    return -1;
}

// 1 when this BLOCK node opens an arena the cost model chose.
int aif_auto_arena_at_node(const void* node) {
    return auto_arena_scope_at_node(node) >= 0 ? 1 : 0;
}

// SPEC 5.2: may this value come from the enclosing region's arena?
//
// **This is the only arena gate.** Codegen (aif_arena_at_node), the manifest's
// placement column (aif_region_name_at_site), the zero-serving diagnostic
// (aif_region_serves), the LAYOUT 7.1 cost model and `--why`'s placement section
// all read this one function. A disagreement between them is a manifest
// describing a build that did not happen -- the defect the `rc`/`rc:none` split
// exists to prevent, one tier down. They were four separate copies of these
// clauses until 2026-08-14, and the copy that had drifted was placing arenas
// that served nothing.
//
// The nesting case is what makes the last clause more than a lexical question:
//
//     region outer { let mut x = ...; region inner { x = Foo{} } use(x) }
//
// `Foo{}` is lexically inside `inner`, but its escape is `outer`'s scope, and
// inner's arena is gone by `use(x)`. lca(outer, inner) is outer, not inner, so
// this correctly declines and the value goes to the heap.
//
// **`blockers` receives EVERY clause that rejected, not the first**, and that is
// the whole reason it is a mask. A short-circuiting answer told a reader of g2
// "the tier is not T1" -- true, and the wrong thing to act on, because
// `in_container` and `no_region` reject the same site immediately afterwards. So
// the tier gets fixed, the binary does not change, and the session ends with a
// design note explaining a gate nobody read to the end. That happened three
// times before this mask existed.

#define AIF_ARENA_B_NOT_T1       1
#define AIF_ARENA_B_NO_STACK     2
#define AIF_ARENA_B_IN_CONTAINER 4
#define AIF_ARENA_B_IS_LIST      8
#define AIF_ARENA_B_NO_REGION   16
#define AIF_ARENA_B_ESCAPES     32
#define AIF_ARENA_B_OUTLIVES    64

// SPEC 5.2.1.1. The region a bracketed call hands this site, or -1. Defined
// after the call graph it reads; declared here because it is the first clause of
// the gate below and must not be a second copy of it.
static int site_bracket_region(int id);

static int site_arena_scope_full(int id, int* blockers) {
    if (id < 0 || id >= site_count) {
        if (blockers) *blockers = AIF_ARENA_B_NOT_T1;
        return -1;
    }
    Site* s = &sites[id];
    int mask = 0;

    // SPEC 5.2.1.1's placement. This site is in a bracketed extent, so its arena
    // is the caller's region and the five clauses below do not apply to it:
    // every one of them asks about an arena in *this* function, and the whole
    // point of bracketing is that there is not one. The obligations that replace
    // them were discharged once, over the entire extent, in bracket_place.
    //
    // What survives is what a *deallocator* would still do to this value, which
    // bracketing does not change:
    //
    //   * T0 storage is the frame. Codegen checks the arena before the tier
    //     (src/ir/expr.psm), so accepting a T0 site here would take a hoisted
    //     alloca and turn it into one bump allocation per loop iteration.
    //   * T3 and T4b carry a count in a prefix header and are released by a
    //     decrement. The last decrement calls the deallocator, and a bump
    //     pointer is not a thing it can take.
    //   * `drop(x)` frees it explicitly, for the same reason as below.
    //
    // T1 and T2 both pass, and T2 passing is the point: SPEC 5.2 makes the tier
    // the derived fact and the placement a codegen decision, so a bracketed site
    // keeps the tier it derived and the manifest reads `T2  region:<name>`.
    // Promoting it to T1 would move the tier distribution, and the oracle does
    // not model placement -- the differential would then fail on a difference
    // that is not an inference difference.
    int br = site_bracket_region(id);
    if (br >= 0) {
        int tier = aif_tier_of(id);
        if (tier != AIF_T1 && tier != AIF_T2) mask |= AIF_ARENA_B_NOT_T1;
        if (s->no_stack) mask |= AIF_ARENA_B_NO_STACK;
        if (blockers) *blockers = mask;
        return mask == 0 ? br : -1;
    }

    if (aif_tier_of(id) != AIF_T1) mask |= AIF_ARENA_B_NOT_T1;  // T0 has the frame
    // The same reason the T0 clause asks: an arena pointer is not a thing a
    // deallocator can take, and `drop(x)` emits one unconditionally -- the
    // source, not the model, decided when that value dies.
    if (s->no_stack) mask |= AIF_ARENA_B_NO_STACK;
    // A produced extern return has no allocation here to serve; see
    // arena_would_serve. Reported under the same blocker because the reason a
    // reader needs is the same one: this site's storage is not this frame's.
    if (s->foreign) mask |= AIF_ARENA_B_NO_STACK;
    // The container frees its elements through the deallocator, and a pointer
    // into the middle of an arena chunk is not one it can take.
    if (s->in_container) mask |= AIF_ARENA_B_IN_CONTAINER;
    // An arena serves values allocated once. A list is not one: list_push
    // reallocates the element block long after this site returned, at whatever
    // arena depth the program happens to be at then -- so the block would be
    // tied to a region the list can outlive, and freeing the old block would
    // hand arena memory to the deallocator.
    if (s->kind == AIF_K_LIST) mask |= AIF_ARENA_B_IS_LIST;

    // **The clause that decides the corpus, and the one three sessions of design
    // notes walked past.** `enclosing_region` walks scopes[].parent, a *lexical*
    // tree rooted per function -- scope_lca returns -1 across owners. So a site
    // in a callee can never find an arena its caller opened, however its escape
    // is spelled. Measured 2026-08-14: of 234 allocation sites in aif/corpus and
    // aif/evidence, 38 are served and 196 are not -- and **all 196 fail here**.
    // Every one of the 38 is a case where the region and the allocation share a
    // function. No value of E moves that number, because E holds a scope id in
    // the site's own function while the arena that would serve a callee's
    // allocation is chosen at run time by arena_depth. SPEC 5.2.1 states it
    // normatively; aif/evidence/arena_census.py re-derives it in one command.
    int r = enclosing_region(s->scope);
    if (r < 0) {
        mask |= AIF_ARENA_B_NO_REGION;
    } else if (s->E < 0) {
        mask |= AIF_ARENA_B_ESCAPES;                // Caller or Global
    } else if (scope_lca(s->E, r) != r) {
        mask |= AIF_ARENA_B_OUTLIVES;
    }

    if (blockers) *blockers = mask;
    return mask == 0 ? r : -1;
}

static int site_arena_scope(int id) {
    return site_arena_scope_full(id, NULL);
}

// SPEC 6.3's witness path, for placement rather than for the tier. `--why`
// answered "what made this T2" and said nothing about where the value lives.
int aif_arena_blockers(int id) {
    int mask = 0;
    site_arena_scope_full(id, &mask);
    return mask;
}

// The region a site would have been served by if the gate had not declined --
// i.e. the nearest enclosing one, ignoring every other clause. "" when there is
// none, which is what AIF_ARENA_B_NO_REGION already says; this exists so the
// OUTLIVES case can name the arena the value escaped past.
const char* aif_nearest_region_name(int id) {
    if (id < 0 || id >= site_count) return "";
    int r = enclosing_region(sites[id].scope);
    if (r < 0) return "";
    return scopes[r].region_name < 0 ? "auto" : aif_str(scopes[r].region_name);
}

int aif_arena_at_node(const void* node) {
    if (node == NULL) return 0;
    for (NodeSite* n = node_buckets[node_hash(node)]; n; n = n->next) {
        if (n->node != node) continue;
        return site_arena_scope(n->site) >= 0 ? 1 : 0;
    }
    return 0;
}

// The region name to report for this site, or "" when it is not arena-placed.
// An arena the cost model chose has no name to report -- it is a scope, not a
// declaration -- so it reports "auto", which is what distinguishes it in the
// manifest from a `region` the programmer pinned.
const char* aif_region_name_at_site(int id) {
    int r = site_arena_scope(id);
    if (r < 0) return "";
    if (scopes[r].region_name < 0) return "auto";
    return aif_str(scopes[r].region_name);
}

// SPEC 5.2's diagnostic. How many allocation sites this scope's arena actually
// serves -- by the codegen gate above, not by the cost model's estimate, because
// the question a programmer is asking is "did my annotation do anything" and only
// the emitted code answers that.
int aif_region_serves(int scope) {
    if (scope < 0 || scope >= scope_count) return 0;
    int n = 0;
    for (int i = 0; i < site_count; i++) {
        if (site_arena_scope(i) == scope) n++;
    }
    return n;
}

// ----------------------------------------------------------------------------
// SPEC 5.4 applied to placement -- `pin(<region-name>)`
//
// SPEC 5.2.1.1 says this of its own regime (a): "(a) is fragile as a language
// guarantee -- adding a second call to a bracketed callee silently removes the
// placement -- which is why an implementation using it SHALL record in the
// manifest which call sites it bracketed, so the loss appears as a diff rather
// than as a slowdown." The manifest does record them. A diff is only read by
// somebody who looks; this is the same fact stated by the *programmer*, so a
// build fails instead.
//
// **It reads aif_region_name_at_site and computes nothing.** That is
// site_arena_scope, the one arena gate every other consumer already reads --
// codegen, the manifest's placement column, the zero-serving warning, the cost
// model and `--why`. Re-deriving "is this bracketed" from the bracket table here
// would be a fifth copy of a predicate this file has already paid for having
// four of, and the copy that drifts is always the one that decides.
//
// It is an assertion, never a directive (SPEC 5.0.1): nothing below writes to
// scopes[].arena or to site_bracket, so a build with these annotations deleted
// emits the same instructions. That is what makes the feature diagnostic-only,
// and what makes "the IR must not move" the test for it.
//
// Ordering: this runs after aif_place_arenas, unlike aif_check_pins which must
// run before it. A tier pin is an *input* to placement (the cost model ranks
// scopes by tier); a placement pin is an assertion about its *output*.
// ----------------------------------------------------------------------------
void aif_check_placement_pins(int converged) {
    for (int i = 0; i < site_count; i++) {
        Site* s = &sites[i];
        if (s->pin_region < 0) continue;

        const char* placed = aif_region_name_at_site(i);
        if (placed[0] != '\0' && strcmp(placed, aif_str(s->pin_region)) == 0) {
            s->pin_region_verdict = AIF_PIN_HONOURED;
        } else if (converged) {
            // SPEC 5.4.1. There is no third branch here and there is one in
            // aif_check_pins: a tier pin *above* the derived tier is honoured
            // because every tier is semantically valid and a more expensive one
            // needs no proof (SPEC 5.4.4). Placement has no such order -- an
            // arena either serves this site or does not -- so the direction
            // limit has nothing to be a limit on, and "served by some other
            // region" is a refutation rather than a weaker honour.
            s->pin_region_verdict = AIF_PIN_REFUTED;
        } else {
            // SPEC 5.4.2, and it is not a formality here. A truncated analysis
            // widens every unproven site to its top tier, which takes the arena
            // away from sites a converged run keeps it for -- so a build that
            // ran out of budget would refute pins a full one honours.
            s->pin_region_verdict = AIF_PIN_UNPROVEN;
        }
    }
}

int aif_site_pin_region_verdict(int id) {
    if (id < 0 || id >= site_count) return AIF_PIN_NONE;
    return sites[id].pin_region_verdict;
}

const char* aif_site_pin_region(int id) {
    if (id < 0 || id >= site_count || sites[id].pin_region < 0) return "";
    return aif_str(sites[id].pin_region);
}

int aif_scope_region_file(int s) { return (s < 0 || s >= scope_count) ? 0 : scopes[s].region_file; }
int aif_scope_region_line(int s) { return (s < 0 || s >= scope_count) ? 0 : scopes[s].region_line; }
int aif_scope_region_col(int s)  { return (s < 0 || s >= scope_count) ? 0 : scopes[s].region_col; }

// 1 when this site's arena was pinned by a `region` statement rather than chosen
// by the cost model. SPEC 6.2's `origin` column distinguishes them: a pin that
// stops being honoured is a gate regression, an inferred placement moving is not.
int aif_site_arena_is_pinned(int id) {
    if (id < 0 || id >= site_count) return 0;
    // SPEC 5.2.1.1. A bracketed site's arena is a `region` in *another* function,
    // which enclosing_region cannot see -- and it is always a pinned one, because
    // bracketing only ever targets a `region` (see bracket_place). Asked of the
    // gate rather than of the lexical tree for that reason, and asked first so
    // the lexical answer below is left exactly as it was for every other site.
    int served = site_arena_scope(id);
    if (served >= 0 && scopes[served].region_name >= 0) return 1;
    int r = enclosing_region(sites[id].scope);
    if (r < 0) return 0;
    return scopes[r].region_name >= 0 ? 1 : 0;
}

// Call-site bracketing: may a caller's region reach a callee's allocations?
// (SPEC 5.2.1's first named repair. Report only -- nothing here places anything.)
// The gate above rejects a site whose `region` is in another function, and the
// census says that is 196 of 196 blocked sites. The repair is not to make the
// site's E name the caller's arena -- it cannot; E is a scope id in the site's
// own function -- but to *bracket the call*, so that the arena serving the
// callee's allocations is chosen at run time by the region stack that is
// already there.
// That is only sound when nothing the callee allocates can outlive the region.
// This computes exactly that question, per function, and answers it as a mask
// rather than a verdict -- the same decision `aif_arena_blockers` records, for
// the same reason: a conjunction reported as its first failure sends a reader
// to the wrong work, and this file has three sessions of evidence for it.
//   GLOBAL       an allocation in the extent escapes to static storage. Nothing
//                bounds its lifetime, so no region can.
//   PARAM_STORE  the extent stores into something it did not allocate. This is
//                the counterexample that kills the naive version:
//                    fn add_to(dest: List<Node>, n: Int) {
//                        list_push(dest, Node { id: n })
//                    }
//                    region R { add_to(long_lived_list, 5) }
//                the Node comes from R's arena and the list outlives R. Caught
//                by asking whether every *owner* the extent stores into was
//                itself allocated inside the extent.
//   OPAQUE       a callee with no visible body. A summary of a body nobody can
//                see is a guess, and the optimistic direction is the one that
//                produces a use-after-free.
//   DROP         `drop(x)` inside the extent. The source, not the model, decided
//                when that value dies, and a bump pointer is not a thing free()
//                can take. Same clause as AIF_ARENA_B_NO_STACK, one level up.
//   SHARED_BODY  the body serves more than one placement regime -- SPEC 5.2.1's
//                regime (a). Codegen's frees are static decisions, so a body
//                reachable both inside and outside a bracket would have to free
//                arena memory on one path or leak heap memory on the other.
//                Not an allocation obligation; reported separately for that
//                reason, and the reason the manifest must say when it fired.
// Obligation 4 -- the summary is a fixpoint over the call graph -- is not a
// blocker but how every clause above is evaluated: recursion and mutual
// recursion mean the transitive callee set is a closure, not a walk. The
// remaining obligation, "the returned value does not outlive R", is a property
// of the *call site* rather than of the function, and `site_arena_scope`'s
// scope_lca test already answers it in the caller.

#define AIF_BR_B_GLOBAL       1
#define AIF_BR_B_PARAM_STORE  2
#define AIF_BR_B_OPAQUE       4
#define AIF_BR_B_DROP         8
#define AIF_BR_B_SHARED_BODY 16
// Regime (a)'s *other* half, split out 2026-08-28. SPEC 5.2.1.1's table gives
// the requirement as "one body, one placement regime" and "exactly one call
// site" as the way to get it -- and the second is a sufficient condition for the
// first, not a necessary one. A body every one of whose call sites is bracketed
// into the **same** region also serves exactly one regime: it only ever runs
// with that arena innermost.
//
// So this bit means "which regime this body serves is not a property of the
// program, and has to be asked of a region" -- `bracket_regime_ok`. It is
// reported separately from SHARED_BODY because the repair is different: a
// SHARED_BODY callee needs specialisation (regime (b)), while this one needs
// only that its callers agree, which they often already do.
#define AIF_BR_B_MULTI_CALL  32

// One entry per call *expression*, so the count of entries naming a callee is
// its static call-site count -- which is what regime (a) asks about. A bitset
// would collapse two calls to one and silently make every callee sole-owned.
typedef struct {
    int caller;
    int callee;
    int scope;      // the caller's scope the call sits in, for "calls in a region"
    // M3.2, and the reason the call edge needs it as much as the site does: the
    // clause that refuses `g2.psm` is "an opaque call is in the region body",
    // asked of the whole block. A non-lexical extent has to ask it of a
    // statement range instead, and `clock_gettime_nsec_np` sits outside the one
    // that matters.
    int stmt;
} CallEdge;

static CallEdge* call_edges;
static int call_edge_count, call_edge_cap;

static CallEdge* call_edge_push(void) {
    if (call_edge_count == call_edge_cap) {
        call_edge_cap = call_edge_cap ? call_edge_cap * 2 : 256;
        call_edges = (CallEdge*)xrealloc(call_edges, (size_t)call_edge_cap * sizeof(CallEdge),
                                         "AIF call graph");
    }
    return &call_edges[call_edge_count++];
}

// Value sets a function stores *into*: the holder of a `retain_in` and the owner
// set of a field store. Resolved after the solve, because until then a value set
// names keys rather than sites.
typedef struct {
    int fn;
    int vs;
} OwnerUse;

static OwnerUse* owner_uses;
static int owner_use_count, owner_use_cap;

// The per-function facts the closure walk reads. Built once, lazily, because
// every one of them needs the converged facts.
static Bits* fn_callees;        // fn -> direct callees, for the closure
static Bits* fn_owner_fns;      // fn -> functions that allocated what it stores into
static char* fn_has_global;
static char* fn_has_drop;
static char* fn_calls_opaque;
// 1 when this function or anything it reaches has an allocation site. See
// bracket_prepare: it is what makes regime (a)'s shared-body clause a question
// about bodies the bracket changes rather than about every body it touches.
static char* fn_allocs_reach;
static int bracket_ready;
// How many functions the arrays above were sized for. Kept because aif_reset
// runs after fn_count has been zeroed by the caller in some orders, and freeing
// a bitset array by a count that is no longer the one it was allocated with is
// how a teardown leaks or double-frees.
static int bracket_fn_cap;
static Bits bracket_closure, bracket_scratch;

void aif_call_edge(int caller, int callee, int scope) {
    if (caller < 0 || callee < 0) return;
    CallEdge* e = call_edge_push();
    e->caller = caller;
    e->callee = callee;
    e->scope = scope;
    e->stmt = g_stmt;
}

// A call this compilation cannot summarise: a sealed function, or an extern
// whose contract table says nothing about it. An extern the table *does* know
// is already modelled -- `retain_in` puts the value under a container,
// `retain` sends it to Global, `consume` marks it no_stack -- so the clauses
// below see it and this does not have to.
//
// Recorded as an edge to callee -1 rather than into a per-function flag array,
// because the walk creates functions as it goes: an array sized at the first
// opaque call would be short by every function declared after it.
void aif_call_opaque(int caller, int scope) {
    if (caller < 0) return;
    CallEdge* e = call_edge_push();
    e->caller = caller;
    e->callee = -1;
    e->scope = scope;
    e->stmt = g_stmt;
}

void aif_note_owner_use(int fn, int vs) {
    if (fn < 0 || vs < 0) return;
    if (owner_use_count == owner_use_cap) {
        owner_use_cap = owner_use_cap ? owner_use_cap * 2 : 256;
        owner_uses = (OwnerUse*)xrealloc(owner_uses, (size_t)owner_use_cap * sizeof(OwnerUse),
                                         "AIF owner uses");
    }
    owner_uses[owner_use_count].fn = fn;
    owner_uses[owner_use_count].vs = vs;
    owner_use_count++;
}

static int bracket_trace;   // AIF_BRACKET_TRACE=1 -- why one site failed obligation 3

static void bracket_prepare(void) {
    if (bracket_ready || fn_count == 0) return;
    bracket_ready = 1;
    // Set here rather than in bracket_place, which is the pass that runs
    // *second*. The candidate pass is the one that decides whether a scope gets
    // an arena at all, and a trace that starts after that decision cannot say
    // why a scope was never a candidate -- which is the question asked of it.
    bracket_trace = getenv("AIF_BRACKET_TRACE") != NULL;

    bracket_fn_cap = fn_count;
    fn_callees   = (Bits*)xcalloc((size_t)fn_count, sizeof(Bits), "AIF call graph");
    fn_owner_fns = (Bits*)xcalloc((size_t)fn_count, sizeof(Bits), "AIF store owners");
    fn_has_global = (char*)xcalloc((size_t)fn_count, 1, "AIF bracket facts");
    fn_has_drop   = (char*)xcalloc((size_t)fn_count, 1, "AIF bracket facts");
    fn_calls_opaque = (char*)xcalloc((size_t)fn_count, 1, "AIF opaque calls");
    fn_allocs_reach = (char*)xcalloc((size_t)fn_count, 1, "AIF bracket facts");

    for (int i = 0; i < call_edge_count; i++) {
        CallEdge* e = &call_edges[i];
        if (e->caller < 0 || e->caller >= fn_count) continue;
        if (e->callee < 0) {
            fn_calls_opaque[e->caller] = 1;
        } else if (e->callee < fn_count) {
            bits_set(&fn_callees[e->caller], e->callee, "AIF call graph");
        }
    }

    // Does this function, or anything it can reach, allocate at all?
    //
    // Regime (a)'s shared-body clause is about a body the bracket would
    // *change*. A function with no allocation anywhere below it compiles
    // identically inside and outside a bracket -- there is no site to route to
    // an arena and none to take off a drop list -- so sharing it with the world
    // outside the extent decides nothing. Transitive rather than local, and that
    // is the whole of the care needed here: a site-free function that calls an
    // allocating one *is* changed, one hop down, and treating it as harmless
    // would compile that callee's sites for an arena and then run them with none.
    //
    // g6 is what this is for. `plan_orders` reaches `world_actor` and
    // `world_transform`, two accessors that do nothing but `list_get`, and
    // `resolve_combat` calls `world_actor` too -- so the extent read as shared
    // on a pair of getters.
    for (int s = 0; s < site_count; s++) {
        int f = sites[s].fn;
        if (f >= 0 && f < fn_count) fn_allocs_reach[f] = 1;
    }
    int spread = 1;
    while (spread) {
        spread = 0;
        for (int g = 0; g < fn_count; g++) {
            if (fn_allocs_reach[g]) continue;
            for (int h = 0; h < fn_count; h++) {
                if (!bits_test(&fn_callees[g], h) || !fn_allocs_reach[h]) continue;
                fn_allocs_reach[g] = 1;
                spread = 1;
                break;
            }
        }
    }

    for (int s = 0; s < site_count; s++) {
        int f = sites[s].fn;
        if (f < 0 || f >= fn_count) continue;
        if (sites[s].E == AIF_E_GLOBAL) fn_has_global[f] = 1;
        if (sites[s].no_stack) fn_has_drop[f] = 1;
    }

    // A store's owners are sites; which *function* allocated them is the fact
    // the closure test needs, and it does not depend on which caller is asking,
    // so it is computed once here rather than per query.
    for (int i = 0; i < owner_use_count; i++) {
        int f = owner_uses[i].fn;
        if (f < 0 || f >= fn_count) continue;
        resolve(owner_uses[i].vs, &bracket_scratch);
        for (int s = 0; s < site_count; s++) {
            if (!bits_test(&bracket_scratch, s)) continue;
            // An orphan site belongs to no function, so no closure can contain
            // it. fn_count is the id reserved for exactly that, and it is one
            // past the end -- so a closure bitset never holds it and the subset
            // test below rejects, which is the sound direction.
            int owner_fn = sites[s].fn;
            bits_set(&fn_owner_fns[f], (owner_fn < 0 || owner_fn >= fn_count) ? fn_count : owner_fn,
                     "AIF store owners");
        }
    }
}

// Every function reachable from `f` through the call graph, `f` included.
// INFERENCE-style worklist rather than a walk, because mutual recursion makes
// the transitive set a least fixed point (obligation 4).
static void bracket_reachable(int f, Bits* out) {
    bits_clear(out);
    bits_set(out, f, "AIF bracket closure");
    int changed = 1;
    while (changed) {
        changed = 0;
        for (int g = 0; g < fn_count; g++) {
            if (!bits_test(out, g)) continue;
            for (int h = 0; h < fn_count; h++) {
                if (!bits_test(&fn_callees[g], h)) continue;
                if (bits_set(out, h, "AIF bracket closure")) changed = 1;
            }
        }
    }
}

static int bits_subset(const Bits* a, const Bits* b) {
    for (int i = 0; i < a->nwords; i++) {
        Word x = a->w[i];
        if (!x) continue;
        Word y = (i < b->nwords) ? b->w[i] : 0;
        if (x & ~y) return 0;
    }
    return 1;
}

int aif_fn_bracket_blockers(int f) {
    if (f < 0 || f >= fn_count) return AIF_BR_B_OPAQUE;
    bracket_prepare();
    bracket_reachable(f, &bracket_closure);

    int mask = 0;
    for (int g = 0; g < fn_count; g++) {
        if (!bits_test(&bracket_closure, g)) continue;
        if (fn_has_global[g])   mask |= AIF_BR_B_GLOBAL;
        if (fn_has_drop[g])     mask |= AIF_BR_B_DROP;
        if (fn_calls_opaque[g]) mask |= AIF_BR_B_OPAQUE;
        if (fns[g].sealed)      mask |= AIF_BR_B_OPAQUE;
        if (!bits_subset(&fn_owner_fns[g], &bracket_closure)) mask |= AIF_BR_B_PARAM_STORE;
    }

    // Regime (a), in two clauses that used to be one bit.
    //
    // **SHARED_BODY** is the region-independent half: everything `f` reaches
    // must be reached only from inside the extent, or that callee's body would
    // have to free arena memory on one path and heap memory on the other. No
    // choice of region fixes it; regime (b) -- specialisation -- is what does.
    //
    // **MULTI_CALL** is the half that depends on where the region is. One call
    // site settles it from the program alone; more than one settles it only if
    // they are all bracketed into the same region, which is a question
    // `bracket_regime_ok` asks and this function cannot. Reported here so
    // `--why` can still say "the body has N call sites", and **excluded from the
    // reject in bracket_edge_ok_at**, which is the whole of the change: g6's
    // `plan_orders` builds a per-tick order list, is called once per squad from
    // the same loop body, and was refused for having two callers that agree.
    int f_calls = 0;
    for (int i = 0; i < call_edge_count; i++) {
        CallEdge* e = &call_edges[i];
        if (e->callee == f) { f_calls++; continue; }
        if (!bits_test(&bracket_closure, e->callee)) continue;
        if (bits_test(&bracket_closure, e->caller)) continue;
        // Reached from outside the extent, and that only matters for a body the
        // bracket would change. See fn_allocs_reach in bracket_prepare.
        if (!fn_allocs_reach[e->callee]) continue;
        mask |= AIF_BR_B_SHARED_BODY;
    }
    if (f_calls != 1) mask |= AIF_BR_B_MULTI_CALL;

    return mask;
}

// The obligations that are the *function's* alone. MULTI_CALL is not one of
// them: a body with two call sites is bracketable or not depending on where they
// are, and the answer belongs to bracket_regime_ok.
static int aif_fn_bracket_hard_blockers(int f) {
    return aif_fn_bracket_blockers(f) & ~AIF_BR_B_MULTI_CALL;
}

// Regime (a)'s other half. Defined with the placement machinery, because it
// reads which scopes got arenas; declared here because the manifest's
// "bracketable call sites" count asks it first.
static int bracket_regime_ok(int r, int caller_fn, int callee);

int aif_fn_call_sites(int f) {
    int n = 0;
    for (int i = 0; i < call_edge_count; i++) {
        if (call_edges[i].callee == f) n++;
    }
    return n;
}

// Of this function's call sites, how many sit inside a region. This is the half
// of the answer the obligations do not carry: a function can clear every one of
// them and still never be placed, because nobody calls it from a region. Telling
// a reader "bracketable" without it is the manifest defect one level up --
// reporting a property that reads as a placement and is not one.
int aif_fn_calls_in_region(int f) {
    int n = 0;
    for (int i = 0; i < call_edge_count; i++) {
        if (call_edges[i].callee != f) continue;
        if (enclosing_region(call_edges[i].scope) >= 0) n++;
    }
    return n;
}

// How many call expressions sit lexically inside a `region` (or inside a scope
// the cost model gave an arena). This is the population call-site placement can
// draw from, and printing it beside the qualifying-function count is what makes
// "N functions qualify" mean something: a thousand safe functions nobody calls
// from a region is still zero placements.
int aif_region_call_sites(void) {
    int n = 0;
    for (int i = 0; i < call_edge_count; i++) {
        if (call_edges[i].callee < 0) continue;   // an opaque call is never bracketed
        if (enclosing_region(call_edges[i].scope) >= 0) n++;
    }
    return n;
}

// Of those, the ones whose callee clears every obligation. This is the number
// task 4 would act on, and it is deliberately printed next to the two counts it
// is derived from: a large qualifying-function count with a zero here means the
// analysis is right and the programs are not shaped the way it assumed.
int aif_bracketable_region_call_sites(void) {
    int n = 0;
    for (int i = 0; i < call_edge_count; i++) {
        if (call_edges[i].callee < 0) continue;
        int r = enclosing_region(call_edges[i].scope);
        if (r < 0) continue;
        // Both halves of regime (a), each asked where it can be answered: the
        // hard obligations of the function, and the call-site half of the region
        // this call actually sits in. Asking only the first would count a callee
        // with two agreeing callers as unbracketable, which is precisely what
        // this number stopped being able to see.
        if (aif_fn_bracket_hard_blockers(call_edges[i].callee) != 0) continue;
        if (!bracket_regime_ok(r, scopes[r].owner, call_edges[i].callee)) continue;
        n++;
    }
    return n;
}

// Call sites whose callee this compilation can see. The opaque ones are not in
// the denominator because they are not in the numerator either -- a call nobody
// can summarise is never a candidate, so counting it would make the ratio read
// worse than the question it answers.
int aif_call_edge_count(void) {
    int n = 0;
    for (int i = 0; i < call_edge_count; i++) {
        if (call_edges[i].callee >= 0) n++;
    }
    return n;
}

// Call-site placement (SPEC 5.2.1.1)
// The section above answers "may a caller's region reach this function". This
// one decides it, per call site, and hands the resulting sites an arena.
// **There is no new codegen mechanism, and that is the shape of the thing.** An
// arena is on a dynamic stack: `region r { ... }` already emits arena_push at
// entry and arena_pop at every exit, so while a bracketed callee runs, its
// caller's arena is the top of that stack. All that was missing was for the
// *analysis* to say a callee's site belongs to it -- after which the two hooks
// that already exist do the work. ir_alloc_region takes a struct literal
// straight to arena_alloc, and ir_arena_hint_begin/end takes a producing runtime
// call (a string, a list) there. Both are keyed on aif_arena_at_node, which is
// this file's gate, so both follow from the clause below and neither needed a
// line of frontend change. An earlier design bracketed the Prismio call itself
// with the hint; that would have routed *every* runtime allocation in the extent
// to the arena, including ones the per-site gate declined.
// Three decisions, none of them re-derivable from the code alone:
// **Only a `region`-pinned arena, never a cost-model-chosen one.** Otherwise
// placement depends on bracketing depends on placement: enclosing_region reads
// scopes[].arena, which aif_place_arenas sets from arena_would_serve, which
// would then have to count bracketed sites as benefit. `region` sets the flag at
// parse time, before placement runs, so restricting to it cuts the loop -- and
// leaves arena_would_serve, the one clause-list copy deliberately *not* behind
// site_arena_scope, correct without change.
// **Obligation 3 is not readable from E.** "The value the call returns does not
// outlive R" is a property of the call site, and E cannot express it:
// AIF_CON_LIVE_IN's transfer sets E = Caller for every site whose fn is not the
// binding function, by construction, because a scope id in one function does not
// order against one in another. The fact wanted is the *caller-side* binding, and
// the points-to graph already holds it -- pt[k] for a VAR key names the function
// and var_scope names the declaring scope. So obligation 3 is asked of the keys
// and of the owner sites, not of E. bracket_site_bounded is that question.
// **Regime (a) is what makes one body serve one regime**, and it is checked by
// aif_fn_bracket_blockers above: the callee has exactly one call site, and every
// function the extent reaches is reached only from inside it. Together with the
// bracketed call being inside the region, that means the extent's bodies run at
// the region's arena depth on every path they can be entered from.

// Key ids are dense and the interning table is a hash, so a reverse index is the
// only way to ask "what kind of location is key k". Rebuilt when key_count moves,
// which after the solve it does not.
static KeyNode** key_by_id;
static int key_by_id_len;

static void key_index_build(void) {
    if (key_by_id && key_by_id_len == key_count) return;
    free(key_by_id);
    key_by_id = key_count > 0
        ? (KeyNode**)xcalloc((size_t)key_count, sizeof(KeyNode*), "AIF key index")
        : NULL;
    for (int b = 0; b < AIF_KEY_BUCKETS; b++) {
        for (KeyNode* n = key_buckets[b]; n; n = n->next) {
            if (n->id >= 0 && n->id < key_count) key_by_id[n->id] = n;
        }
    }
    key_by_id_len = key_count;
}

// Which *objects* hold each site: the owner set of every field store and of every
// `retain_in` call. container_of already records the second, and E-STORE consumes
// the first without keeping it, so this reconstructs both from cons[] after the
// solve. It is the half of obligation 3 the keys cannot answer: a FIELD key is
// object-insensitive (INFERENCE 3.1), so `Wrapper.list` says nothing about which
// Wrapper -- and *which* is exactly the question, because a Wrapper the extent
// allocated dies with the extent and one the caller allocated does not.
static Bits* site_owner_sites;
static int site_owner_len;
static Bits owner_bits_val, owner_bits_own;
static IntVec owner_vec_val, owner_vec_own;

static void site_owners_build(void) {
    if (site_owner_sites || site_count == 0) return;
    site_owner_sites = (Bits*)xcalloc((size_t)site_count, sizeof(Bits), "AIF store owners");
    site_owner_len = site_count;

    for (int i = 0; i < con_count; i++) {
        Constraint* k = &cons[i];
        int vset, oset;
        if (k->kind == AIF_CON_STORE)          { vset = k->b; oset = k->c; }
        else if (k->kind == AIF_CON_RETAIN_IN) { vset = k->a; oset = k->b; }
        else continue;
        resolve(vset, &owner_bits_val);
        resolve(oset, &owner_bits_own);
        bits_to_vec(&owner_bits_val, &owner_vec_val);
        bits_to_vec(&owner_bits_own, &owner_vec_own);
        for (int a = 0; a < owner_vec_val.len; a++) {
            for (int b = 0; b < owner_vec_own.len; b++) {
                bits_set(&site_owner_sites[owner_vec_val.v[a]], owner_vec_own.v[b],
                         "AIF store owners");
            }
        }
    }
}

// The innermost `region` enclosing this scope, or -1. Distinct from
// enclosing_region, which also answers for an arena the cost model chose: only a
// pinned one may be bracketed into, and the reason is the circularity above.
static int enclosing_pinned_region(int scope) {
    for (int s = scope; s >= 0; s = scopes[s].parent) {
        if (scopes[s].arena && scopes[s].region_name >= 0) return s;
    }
    return -1;
}

// Functions that cannot be running unless the region is.
//
// The bracketed extent is one of them, and it is not all of them. `submit(cmds)`
// in g2_region takes the list the bracketed `cull` returned; the walk binds a
// parameter to a local of the same name, so `cmds` lands in a VAR key belonging
// to a function that is in no extent at all. Rejecting that would reject the
// case the whole feature exists for, and accepting it unconditionally would
// accept a function that also runs somewhere the region does not.
//
// So the set is closed the same way regime (a) closes the extent: a function
// joins when **every** call site of it is inside the region -- either from a
// member (which is therefore itself only running inside the region) or from the
// bracketing caller at a scope at or below `r`. A function with no callers at all
// never joins; `main` is the one that matters there.
//
// The bracketing caller is excluded by construction. It is running when the
// region is *not* -- that is what the "at or below r" test on its bindings is
// for -- and admitting it would make every call it makes anywhere read as
// confined.
static void region_confined(int r, int caller_fn, const Bits* extent, Bits* out) {
    bits_clear(out);
    bits_or(out, extent, "AIF region confinement");

    // Tri-state, and `signed char` rather than `char` on purpose: plain `char` is
    // unsigned on some ARM targets, and -1 would read back as 255. The logic
    // survives that by accident -- every promotion is guarded by `== 0` -- and an
    // invariant that holds by accident is one the next edit breaks silently.
    //   0  no call site seen yet     1  every call site so far is inside r
    //  -1  entered from outside; final, and never promoted back
    signed char* ok = (signed char*)xcalloc((size_t)(fn_count ? fn_count : 1), 1,
                                            "AIF region confinement");
    for (int pass = 0; pass <= fn_count; pass++) {
        for (int g = 0; g < fn_count; g++) ok[g] = 0;
        for (int i = 0; i < call_edge_count; i++) {
            CallEdge* e = &call_edges[i];
            if (e->callee < 0 || e->callee >= fn_count) continue;
            if (ok[e->callee] < 0) continue;
            if (bits_test(out, e->caller)) { if (ok[e->callee] == 0) ok[e->callee] = 1; continue; }
            if (e->caller == caller_fn && scope_lca(e->scope, r) == r) {
                if (ok[e->callee] == 0) ok[e->callee] = 1;
                continue;
            }
            ok[e->callee] = -1;     // entered from somewhere the region is not
        }
        int changed = 0;
        for (int g = 0; g < fn_count; g++) {
            if (ok[g] != 1 || g == caller_fn || bits_test(out, g)) continue;
            bits_set(out, g, "AIF region confinement");
            changed = 1;
        }
        if (!changed) break;
    }
    free(ok);
}

// Obligation 3, for one site of a bracketed extent.
//
// Every location that may hold this value has to die no later than `r`. Three
// kinds of location can, and everything else fails:
//
//   * a binding, a parameter or a return in a function confined to the region --
//     those frames are gone before the region exits;
//   * a binding in the bracketing caller declared at or below `r`;
//   * a field or element of an object the extent itself allocated.
//
// A PARAM key is allowed and that is not a hole: the walk binds every parameter
// to a local of the same name, so the same value reaches a VAR key of the same
// function and that is the one this decides on. A RET key of the bracketing
// caller is `return f(...)` straight through the region, and it is the case an
// `E`-based test cannot see at all -- E is already Caller for every site in the
// extent, by construction.
static int bracket_reject(int s, const char* why, int detail) {
    if (bracket_trace) {
        fprintf(stderr, "aif: site %d (%s %s:%d) not bounded: %s %d\n",
                s, aif_str(sites[s].type),
                sites[s].fn >= 0 ? aif_str(fns[sites[s].fn].name) : "?",
                sites[s].line, why, detail);
    }
    return 0;
}

// The same, where `detail` is a function id. Printed by name, because the id is
// an index into a table the reader does not have and "bound in 38" costs a
// session the time it takes to count functions.
static int bracket_reject_fn(int s, const char* why, int fn) {
    if (bracket_trace) {
        fprintf(stderr, "aif: site %d (%s %s:%d) not bounded: %s %s (fn %d)\n",
                s, aif_str(sites[s].type),
                sites[s].fn >= 0 ? aif_str(fns[sites[s].fn].name) : "?",
                sites[s].line, why,
                (fn >= 0 && fn < fn_count) ? aif_str(fns[fn].name) : "?", fn);
    }
    return 0;
}

static int bracket_site_bounded(int s, const Bits* confined, const Bits* extent,
                                int r, int caller_fn) {
    for (int k = 0; k < pt_len; k++) {
        if (!bits_test(&pt[k], s)) continue;
        KeyNode* kn = key_by_id[k];
        if (kn == NULL) return bracket_reject(s, "unknown key", k);
        if (kn->kind == AIF_KEY_PARAM) continue;        // decided at the callee's own VAR key
        if (kn->kind == AIF_KEY_FIELD) continue;        // decided by the owner set below
        if (kn->kind == AIF_KEY_RET) {
            if (kn->a == caller_fn) return bracket_reject(s, "returned past the region", k);
            continue;
        }
        if (kn->kind != AIF_KEY_VAR) return bracket_reject(s, "extern key", k);
        int fn = kn->a;
        if (fn >= 0 && fn < fn_count && bits_test(confined, fn)) continue;
        if (fn != caller_fn) return bracket_reject_fn(s, "bound in", fn);
        int declared = (k < var_scope_cap) ? var_scope[k] : -1;
        if (declared < 0) return bracket_reject(s, "undeclared binding", k);
        if (scope_lca(declared, r) != r) return bracket_reject(s, "binding above r, scope", declared);
    }
    // The owner has to be in the *extent*, not merely confined to the region.
    // An object a confined function allocated may still be returned out of the
    // region -- confinement bounds the activation, not the value -- whereas
    // every extent site is one this same loop is deciding, so requiring the
    // owner to be one of those makes the answer inductive rather than assumed.
    for (int o = 0; o < site_count; o++) {
        if (!bits_test(&site_owner_sites[s], o)) continue;
        int of = sites[o].fn;
        if (of < 0 || of >= fn_count || !bits_test(extent, of)) {
            return bracket_reject(s, "owner site outside the extent", o);
        }
    }
    // **The inverse, and it is a separate obligation rather than the same one
    // read backwards.** Above asks that nothing outside the extent *owns* this
    // value, which is about the value outliving the region. This asks that this
    // value owns nothing from outside, which is about the *teardown*: serving a
    // container from the arena deletes its teardown (aif_frees_at_scope_node
    // declines an arena site), and the teardown is what applies the element
    // disposition. If an element came from outside the extent it is an ordinary
    // heap object with a count, and the decrement that would have reclaimed it
    // goes with the teardown.
    //
    // Measured, on test_48_aif_shared_elements: `temp` in borrow_into_temp is a
    // List<Item> whose one element is borrowed out of `src`, allocated in the
    // caller. Bracketed without this clause it read 22 allocated / 21 released /
    // 1 leaked / 0 violations, and the program still printed PASS -- the leaked
    // Item is one nobody reads again, so the ledger is the only witness.
    //
    // Rejecting the *container* rather than the element is deliberate: the
    // element is not the site whose teardown was deleted, and an extent is
    // served whole or not at all.
    for (int o = 0; o < site_count; o++) {
        if (!bits_test(&site_owner_sites[o], s)) continue;
        int of = sites[o].fn;
        if (of < 0 || of >= fn_count || !bits_test(extent, of)) {
            return bracket_reject(s, "owns a site outside the extent", o);
        }
    }
    return 1;
}

// site -> the region scope a bracketed call hands it, or -1.
static int* site_bracket;
static int bracket_place_ready;
static Bits bracket_place_extent, bracket_place_confined;
// The candidate pass gets its own pair. It runs inside aif_place_arenas, which
// is not on bracket_place's stack, but bracket_bytes_of and aif_bracket_served
// both reuse the buffers above -- and two passes sharing one answer-in-progress
// is the kind of aliasing that shows up as a placement that moved without a
// source change.
static Bits bracket_cand_extent, bracket_cand_confined;
// And M3.2c-ii gets a third. cand_stmt_range is reached from inside
// bracket_edge_ok, which was already called with one of the two pairs above and
// reads its `confined` again after the call returns -- so the range pass cannot
// borrow either without answering a question about the wrong extent.
static Bits bracket_range_extent, bracket_range_confined;

// One entry per bracketed call. SPEC 5.2.1.1 requires the manifest to record
// them, because regime (a) is fragile as a language guarantee -- adding a second
// call to a bracketed callee silently removes the placement -- and a loss that
// appears as a diff is one somebody notices.
typedef struct {
    int callee;     // function id
    int scope;      // the region scope that brackets it
    int call_scope; // the caller scope the call sits in, for the footprint estimate
    // M3.2c. Which statement of the region the call sits at. A bracketed site's
    // own `stmt` is a position in the *callee's* block and says nothing about
    // where the region has to open; the call does.
    int call_stmt;
} Bracket;

static Bracket* brackets;
static int bracket_count, bracket_cap;

// The obligations SPEC 5.2.1.1 puts on one bracketed call, asked of an arbitrary
// region scope `r` instead of the one enclosing_region happens to return.
//
// **It reads no arena flag**, and that is the property the whole of M3.1 rests
// on: aif_place_arenas can ask it about a scope it has not chosen yet, so the
// circularity the note above describes ("placement depends on bracketing depends
// on placement") is cut by making the dependency one-way. Placement asks a
// hypothetical question here, decides, and bracketing then answers the real one
// against the placement that resulted. Every input below is the call graph, the
// points-to graph or scope shape; none of them is scopes[].arena.
//
// `extent` and `confined` belong to the caller because bracket_place needs both
// again afterwards to stamp site_bracket, while the candidate pass needs only the
// extent -- and one shared static would have the two passes overwriting each
// other's answer mid-loop.
// A call this compilation cannot summarise may be handed one of the extent's
// values, and FFI 5.1's `borrow` default is an assumption adequate for assigning
// a tier and **not** adequate for handing a callee arena memory -- SPEC
// 5.2.1.1's last paragraph says so in as many words. It is invisible to every
// other check: an undeclared extern's arguments produce only a borrow edge,
// which raises A and leaves E and the points-to graph alone. So it is asked of
// the call graph instead, over every function that can be running while the
// region is.
//
// AIF_BR_B_OPAQUE already covers the extent. What this adds is the caller's own
// region body, and the confined functions it reaches through calls other than
// the bracketed one.
//
// **M3.2c-ii narrows the second half from the block to a statement range**, and
// that is the whole of what unblocks the benchmarked `g2.psm`: its frame loop
// holds two `clock_gettime_nsec_np` calls, one on either side of the two calls
// that allocate, so an arena that opens after the first and closes before the
// second never has an opaque call running inside it. Nothing is relaxed -- an
// opaque call *inside* the extent still rejects, and so does one this pass
// cannot position. The obligation is asked of a smaller region body because
// codegen is about to emit a smaller region body; M3.2d is the half that makes
// that true, and landing this one without it would put the clock calls inside
// the arena.
static int bracket_opaque_ok(int r, int caller_fn, const Bits* confined) {
    int lo = 0, hi = 0;
    int narrowed = 0, asked = 0;

    for (int j = 0; j < call_edge_count; j++) {
        CallEdge* o = &call_edges[j];
        if (o->callee >= 0) continue;
        // A confined function runs entirely inside the region however narrow the
        // extent is -- there is no statement of `r` to compare it against, and
        // the whole of its body is between the push and the pop.
        if (bits_test(confined, o->caller)) return 0;
        if (o->caller != caller_fn) continue;
        if (scope_lca(o->scope, r) != r) continue;

        // Only now, and once. Deriving the extent costs a pass over the call
        // graph per candidate scope; every region body with no opaque call in it
        // -- which is nearly all of them, and all of this compiler's own -- pays
        // nothing for a narrowing it does not need.
        if (!asked) {
            asked = 1;
            narrowed = cand_stmt_range(r, &lo, &hi);
        }
        if (!narrowed) return 0;
        // `stmt` indexes the block the call sits in, and a nested block numbers
        // its own from 0 -- so a call one level down has no position in `r`'s
        // numbering to compare, and is refused rather than guessed at.
        if (o->scope != r || o->stmt < 0) return 0;
        if (o->stmt >= lo && o->stmt <= hi) return 0;
    }
    return 1;
}

// `ask_opaque` is 0 for exactly one caller: cand_stmt_range, which derives the
// extent the clause above compares against. Asking it there would be asking the
// obligation to depend on the range that depends on the obligation -- the M3.1
// circularity, one level down -- so the range is built from the half of these
// obligations that mentions no statement at all.
static int bracket_edge_ok_at(int r, int caller_fn, const CallEdge* e,
                              Bits* extent, Bits* confined, int ask_opaque) {
    if (aif_fn_bracket_hard_blockers(e->callee) != 0) return 0;

    bracket_reachable(e->callee, extent);
    region_confined(r, caller_fn, extent, confined);

    if (ask_opaque && !bracket_opaque_ok(r, caller_fn, confined)) return 0;

    for (int s = 0; s < site_count; s++) {
        int f = sites[s].fn;
        if (f < 0 || f >= fn_count || !bits_test(extent, f)) continue;
        if (!bracket_site_bounded(s, confined, extent, r, caller_fn)) return 0;
    }
    return 1;
}

static int bracket_edge_ok(int r, int caller_fn, const CallEdge* e,
                           Bits* extent, Bits* confined) {
    return bracket_edge_ok_at(r, caller_fn, e, extent, confined, 1);
}

// Regime (a), asked of a region instead of of the program.
//
// A callee with more than one call site serves one placement regime exactly when
// **every one of those calls runs with `r`'s arena innermost**, because then the
// body is only ever entered in one state. Three things have to hold at each of
// them, and each is a use-after-free or a leak if dropped:
//
//   * the call is in `r`'s own function and lexically inside `r` -- otherwise
//     some activation runs with the arena shut, and the body's `arena_alloc`
//     falls back to the heap for a value nothing will free;
//   * no arena sits between the call and `r`, so `r` really is the innermost --
//     `enclosing_region` would bracket such a call into the nearer one, and two
//     calls in two regions is two regimes;
//   * the call is inside the *emitted* statement range, because M3.2d made
//     "inside the region" a range rather than a block. A call after the extent
//     closes is a call with the arena shut, which is the first bullet again.
//
// **It reads scopes[].arena, which is why it is a filter the callers of
// bracket_edge_ok apply rather than a clause inside it.** The obligations stay
// one-way, as M3.1 left them; this is the same place `bracket_candidate_serves`
// already asks whether a nearer arena claimed the call.
static int bracket_regime_ok(int r, int caller_fn, int callee) {
    int lo = 0, hi = 0;
    int narrowed = cand_stmt_range(r, &lo, &hi);

    int seen = 0;
    for (int i = 0; i < call_edge_count; i++) {
        CallEdge* e = &call_edges[i];
        if (e->callee != callee) continue;
        seen++;
        if (e->caller != caller_fn) return 0;
        if (scope_lca(e->scope, r) != r) return 0;
        for (int p = e->scope; p >= 0 && p != r; p = scopes[p].parent) {
            if (scopes[p].arena) return 0;      // a nearer arena takes this one
        }
        if (narrowed) {
            if (e->scope != r || e->stmt < 0) return 0;
            if (e->stmt < lo || e->stmt > hi) return 0;
        }
    }
    return seen > 0;
}

static void bracket_invalidate(void) {
    free(site_bracket);
    site_bracket = NULL;
    bracket_count = 0;
    bracket_place_ready = 0;
}

static void bracket_place(void) {
    if (bracket_place_ready) return;
    bracket_place_ready = 1;
    if (site_count == 0) return;

    bracket_prepare();
    key_index_build();
    site_owners_build();

    site_bracket = (int*)xcalloc((size_t)site_count, sizeof(int), "AIF call-site placement");
    for (int s = 0; s < site_count; s++) site_bracket[s] = -1;

    for (int i = 0; i < call_edge_count; i++) {
        CallEdge* e = &call_edges[i];
        if (e->callee < 0 || e->callee >= fn_count) continue;
        // Placement has run by now, so an arena the cost model chose is as good a
        // region to bracket into as a written one -- that is M3.1, and the note
        // above enclosing_pinned_region explains why the answer used to be
        // "never". Before placement the only safe answer is still the pinned one:
        // the auto table is empty, and a "no bracket" cached from it would
        // outlive the placement that would have justified one. bracket_invalidate
        // is what stops that cache from surviving; this clause is what stops it
        // from being wrong in the window before it runs.
        int r = arenas_placed ? enclosing_region(e->scope)
                              : enclosing_pinned_region(e->scope);
        if (r < 0) continue;

        // The bracketing caller. It is the region's owner and not e->caller,
        // because those are the same function -- e->scope is a scope of e->caller
        // and enclosing_region walked its own parents -- and naming it this
        // way is what the obligation is actually about.
        int caller_fn = scopes[r].owner;

        // Regime (a), and it has to be asked here rather than inside the
        // obligations because it reads which scopes got arenas. See
        // bracket_regime_ok: one call site settles it, more than one settles it
        // only when they all bracket into this same region.
        if (!bracket_regime_ok(r, caller_fn, e->callee)) continue;

        if (!bracket_edge_ok(r, caller_fn, e,
                             &bracket_place_extent, &bracket_place_confined)) continue;

        if (bracket_count == bracket_cap) {
            bracket_cap = bracket_cap ? bracket_cap * 2 : 16;
            brackets = (Bracket*)xrealloc(brackets, (size_t)bracket_cap * sizeof(Bracket),
                                          "AIF call-site placement");
        }
        brackets[bracket_count].callee = e->callee;
        brackets[bracket_count].scope = r;
        brackets[bracket_count].call_scope = e->scope;
        brackets[bracket_count].call_stmt = e->stmt;
        bracket_count++;

        for (int s = 0; s < site_count; s++) {
            int f = sites[s].fn;
            if (f < 0 || f >= fn_count || !bits_test(&bracket_place_extent, f)) continue;
            // Regime (a) means a function is in at most one extent -- SHARED_BODY
            // rejects a body reachable from outside the one that would be
            // bracketed. Asserted rather than assumed: two answers for one site
            // would be two arenas, and the wrong one is a use-after-free.
            if (site_bracket[s] >= 0 && site_bracket[s] != r) { site_bracket[s] = -1; continue; }
            site_bracket[s] = r;
        }
    }
}

static int site_bracket_region(int id) {
    if (id < 0 || id >= site_count) return -1;
    bracket_place();
    return site_bracket ? site_bracket[id] : -1;
}

int aif_bracket_count(void) { bracket_place(); return bracket_count; }

int aif_bracket_callee(int i) {
    bracket_place();
    return (i < 0 || i >= bracket_count) ? -1 : brackets[i].callee;
}

int aif_bracket_scope(int i) {
    bracket_place();
    return (i < 0 || i >= bracket_count) ? -1 : brackets[i].scope;
}

// How many sites this bracket actually places. A bracket that reaches nothing is
// still recorded -- it is a real placement decision and a later edit can make it
// serve something -- but the manifest has to be able to say so, for the same
// reason `region` warns when it serves nothing.
int aif_bracket_served(int i) {
    bracket_place();
    if (i < 0 || i >= bracket_count) return 0;
    // Per *extent*, not per scope. Two brackets into one region is the ordinary
    // case -- g2_region's `cull` and `submit` are both in `frame_arena` -- and
    // counting by scope would report each of them as serving the other's sites,
    // which is how a manifest starts describing a build that did not happen.
    bracket_reachable(brackets[i].callee, &bracket_place_extent);
    int n = 0;
    for (int s = 0; s < site_count; s++) {
        int f = sites[s].fn;
        if (f < 0 || f >= fn_count || !bits_test(&bracket_place_extent, f)) continue;
        if (site_arena_scope(s) >= 0) n++;
    }
    return n;
}

// 1 when this site is served by a bracketed call rather than by a `region` in its
// own function. `--why` needs the two apart: the second is what the programmer
// wrote and the first is what the compiler decided on their behalf.
int aif_site_is_bracketed(int id) {
    return site_bracket_region(id) >= 0 && site_arena_scope(id) >= 0;
}

// ----------------------------------------------------------------------------
// What a bracketed call adds to its region's footprint (REQUIREMENTS 19)
//
// `arena_would_serve` deliberately does not count these, and must not: it is the
// input to aif_place_arenas, so counting a bracketed site there would make
// placement depend on bracketing depend on placement. But the high-water
// estimate and the `region name pin(N)` gate run *after* placement, and the
// question they ask is different -- not "would an arena here be worth it" but
// "how much will this arena hold". Leaving the bracketed sites out of that
// answer is a budget gate passing on memory the binary really does bump-allocate,
// which is the wrong direction for a fixed-budget target to be wrong in.
//
// The weight is a product of two estimates and neither is new. How many times
// the site runs per entry of its own function is its loop depth there; how many
// times the call runs per entry of the region is the call site's loop depth
// relative to `r`. Both use AIF_LOOP_ITERS, so this cannot disagree with
// allocs_in(s) about what a loop multiplies -- and both are static, like every
// other input to this estimate. `weight_of` cannot be used for the first half:
// loop_depth is counted *within* a function, so a difference taken across two of
// them is not a number.
// ----------------------------------------------------------------------------

static long weight_in_own_fn(int site_scope) {
    if (site_scope < 0 || site_scope >= scope_count) return 1;
    int loops = scopes[site_scope].loop_depth;
    if (loops > 6) loops = 6;               // capped as weight_of caps it
    long w = 1;
    for (int i = 0; i < loops; i++) w *= AIF_LOOP_ITERS;
    return w;
}

// SPEC 5.2.1.1 as an input to LAYOUT 7.1's cost model: what a bracketed call
// sitting in `cand` would serve, had `cand` an arena.
//
// The cross-function mirror of arena_would_serve, and it has to be a separate
// function rather than a clause in that one. arena_would_serve asks
// `is_ancestor_or_self(cand, s->scope)`, and a site in a callee fails it however
// its escape is spelled, because scopes[] is a lexical tree rooted per function.
// No per-site clause can cross that; only the call graph can, which is what the
// bracket obligations are asked of.
//
// **The per-site gate here is the bracketed one, not the lexical one** -- tier in
// {T1,T2} and not explicitly dropped, exactly the two clauses
// site_arena_scope_full applies once it has a bracket region. Applying the
// lexical list instead would count in_container and is_list against these sites,
// and those are precisely the clauses bracketing replaces: a bracketed value is
// reclaimed with the region, so the container that holds it never hands its
// pointer to the deallocator. Keeping this in step with that gate is the whole
// correctness argument, so it reads those two conditions and no others.
//
// Weighting matches bracket_bytes_of and for the reason given above it: loop
// depth is counted within a function, so the site's own depth and the call's
// depth relative to `r` are two separate factors and their product is the count.
static long bracket_candidate_serves(int cand, long* held, long* live) {
    if (cand < 0 || cand >= scope_count || site_count == 0) return 0;
    int caller_fn = scopes[cand].owner;
    if (caller_fn < 0 || caller_fn >= fn_count) return 0;

    bracket_prepare();
    key_index_build();
    site_owners_build();

    long served = 0;
    for (int i = 0; i < call_edge_count; i++) {
        CallEdge* e = &call_edges[i];
        if (e->callee < 0 || e->callee >= fn_count) continue;
        // The call has to sit in this scope and belong to the function that owns
        // it -- the same two facts enclosing_region would establish, asked
        // directly because `cand` has no arena flag set yet for it to find.
        if (e->caller != caller_fn) continue;
        if (scope_lca(e->scope, cand) != cand) continue;
        // Innermost-first, as the lexical loop above: an arena already placed
        // between the call and `cand` brackets it first, and counting its traffic
        // here too would justify `cand` with allocations it will never see. This
        // is the automatic-placement form of the inert `region`.
        int claimed = 0;
        for (int p = e->scope; p >= 0 && p != cand; p = scopes[p].parent) {
            if (scopes[p].arena) { claimed = 1; break; }
        }
        if (claimed) continue;
        // The same regime question bracket_place will ask, asked here so the
        // cost model does not justify an arena with traffic that will then be
        // refused. The two passes must agree or a scope gets an arena nothing
        // brackets into.
        if (!bracket_regime_ok(cand, caller_fn, e->callee)) continue;
        if (!bracket_edge_ok(cand, caller_fn, e,
                             &bracket_cand_extent, &bracket_cand_confined)) continue;

        long callw = weight_of(e->scope, cand);
        for (int k = 0; k < site_count; k++) {
            int f = sites[k].fn;
            if (f < 0 || f >= fn_count || !bits_test(&bracket_cand_extent, f)) continue;
            int tier = aif_tier_of(k);
            if (tier != AIF_T1 && tier != AIF_T2) continue;
            if (sites[k].no_stack) continue;
            long w = weight_in_own_fn(sites[k].scope) * callw;
            served += w;
            if (held) *held += (long)sites[k].bytes * w;
            if (live) *live += (long)sites[k].bytes;
        }
    }
    return served;
}

// M3.2c. The statement range an arena at `scope` actually has to cover: from the
// first statement that puts something in it to the last statement that still
// reads something it holds, over a served set the caller supplies.
//
// `served[k]` is 1 for each site the arena takes and `at[k]` is the statement of
// `scope` at which that site's memory appears, or -1 where nothing positions it.
// Returns 0 when the range cannot be narrowed, and **every uncertainty returns 0
// rather than a guess** -- a range that is too wide is the arena we already
// emit, and a range that is too narrow frees memory the program is still using.
//
// Two callers fill those arrays: c-i from the arena that was placed, c-ii from
// the one a candidate scope would get. What they share is the delicate half --
// which keys count as holding the value, which of them may be skipped, and which
// force "whole block" -- and a second copy of that would be a second answer to
// the question codegen and the obligation check have to agree on.
static int stmt_range_over(int scope, const signed char* served, const int* at,
                           int* first, int* last) {
    int lo = -1, hi = -1;
    int any = 0;

    for (int k = 0; k < site_count; k++) {
        if (!served[k]) continue;
        any = 1;
        if (at[k] < 0) return 0;                // unpositioned: cannot narrow
        if (lo < 0 || at[k] < lo) lo = at[k];
        if (at[k] > hi) hi = at[k];
    }
    if (!any || lo < 0) return 0;

    // The end is the last *use*, not the last allocation, and it is asked of the
    // keys because a value outlives the statement that made it. A key declared
    // in a nested block is declined outright: key_last_stmt is recorded against
    // that block's numbering, and there is no way from here to say which
    // statement of `scope` contains it.
    key_index_build();
    for (int k = 0; k < key_count; k++) {
        KeyNode* kn = key_by_id[k];
        if (kn == NULL || kn->kind != AIF_KEY_VAR) continue;
        int holds = 0;
        for (int s = 0; s < site_count && !holds; s++) {
            if (bits_test(&pt[k], s) && served[s]) holds = 1;
        }
        if (!holds) continue;
        int d = (k < var_scope_cap) ? var_scope[k] : -1;
        if (d < 0) return 0;                    // no declaration on record
        // A key belonging to a *different* function needs no position here. It
        // lives in the bracketed extent, and region_confined already proved every
        // one of those activations is gone before the region exits -- that is the
        // whole content of obligation 3. Asking it for a statement index of this
        // block would be asking the wrong question, and declining on it would
        // decline every bracketed region, which is all of the interesting ones.
        if (scopes[d].owner != scopes[scope].owner) continue;
        if (d != scope) return 0;               // same function, deeper: position unknown
        int lu = aif_key_last_stmt(k);
        if (lu < 0) return 0;                   // no use on record: do not narrow
        if (lu > hi) hi = lu;
    }

    if (hi < lo) return 0;
    if (first) *first = lo;
    if (last) *last = hi;
    return 1;
}

// One buffer pair per builder rather than one shared pair. c-i's fill loop asks
// site_arena_scope, which can run the whole bracket pass, which asks c-ii -- and
// a shared pair would have the inner answer overwrite the outer one halfway
// through building it.
static signed char *placed_served, *cand_served;
static int *placed_at, *cand_at;
static int range_scratch_cap;

static void range_scratch_ensure(void) {
    if (site_count <= range_scratch_cap) return;
    int n = site_count;
    placed_served = (signed char*)xrealloc(placed_served, (size_t)n, "AIF arena extent");
    cand_served   = (signed char*)xrealloc(cand_served,   (size_t)n, "AIF arena extent");
    placed_at = (int*)xrealloc(placed_at, (size_t)n * sizeof(int), "AIF arena extent");
    cand_at   = (int*)xrealloc(cand_at,   (size_t)n * sizeof(int), "AIF arena extent");
    range_scratch_cap = n;
}

// M3.2c-i. The range of an arena that exists.
//
// Positions are taken in `scope`'s own numbering. For a lexically served site
// that is the site's own `stmt`; for a bracketed one it is the *call's*
// statement, because the site's own position is an index into the callee's block
// and says nothing about where this region opens.
static int arena_stmt_range(int scope, int* first, int* last) {
    if (scope < 0 || scope >= scope_count || !scopes[scope].arena) return 0;
    // Before the fill loop, not inside it: site_arena_scope below runs this on
    // its first call, and a bracket pass starting halfway through the fill would
    // reach cand_stmt_range with the arrays half written.
    bracket_place();
    if (site_count == 0) return 0;
    range_scratch_ensure();

    for (int k = 0; k < site_count; k++) {
        placed_served[k] = 0;
        placed_at[k] = -1;
        if (site_arena_scope(k) != scope) continue;
        placed_served[k] = 1;
        if (sites[k].scope == scope) {
            placed_at[k] = sites[k].stmt;       // lexical: the site is a statement here
            continue;
        }
        for (int b = 0; b < bracket_count; b++) {       // bracketed: ask the call
            if (brackets[b].scope != scope) continue;
            if (brackets[b].call_scope != scope) continue;
            bracket_reachable(brackets[b].callee, &bracket_cand_extent);
            if (!bits_test(&bracket_cand_extent, sites[k].fn)) continue;
            if (brackets[b].call_stmt < 0) { placed_at[k] = -1; break; }
            if (placed_at[k] < 0 || brackets[b].call_stmt < placed_at[k]) {
                placed_at[k] = brackets[b].call_stmt;
            }
        }
    }

    return stmt_range_over(scope, placed_served, placed_at, first, last);
}

// M3.2c-ii. The range of an arena that does not exist yet, and may never.
//
// c-i cannot answer for a candidate: it starts from site_arena_scope, which *is*
// the decision. And the obligation check needs the range before deciding -- the
// benchmarked `g2.psm` is rejected on its two opaque calls before any arena is
// placed, so there is nothing for c-i to measure and never will be.
//
// **It is the M3.1 circularity again** (the range depends on which sites are
// served, which depends on acceptance, which depends on the range) and it breaks
// the same way: the served set here is drawn only from the call graph, the
// points-to graph and scope shape. Nothing below reads scopes[].arena.
//
// The set is an over-approximation on purpose, and that is the safety argument
// in one line: it is arena_would_serve and the bracket obligations with every
// clause that reads a placement dropped, so it contains the set c-i will compute
// once the decision is made. A superset can only widen the range or force "whole
// block", never narrow it -- so an opaque call outside *this* range is outside
// the range codegen ends up emitting.
static int cand_range_compute(int scope, int* first, int* last) {
    if (scope < 0 || scope >= scope_count) return 0;
    if (scopes[scope].node == NULL) return 0;   // no block for codegen to bracket
    // SPEC 5.2 brackets a written `region` at its braces and M3.2d does not
    // narrow it, so neither may the obligation that guards it.
    if (scopes[scope].region_name >= 0) return 0;
    int owner = scopes[scope].owner;
    if (owner < 0 || owner >= fn_count) return 0;
    if (site_count == 0) return 0;

    bracket_prepare();
    key_index_build();
    site_owners_build();
    range_scratch_ensure();

    for (int k = 0; k < site_count; k++) { cand_served[k] = 0; cand_at[k] = -1; }

    // What an arena here would serve lexically: arena_would_serve, minus its one
    // clause that reads scopes[].arena -- "a nearer arena claimed it" -- which
    // can only ever take a site away.
    for (int k = 0; k < site_count; k++) {
        Site* s = &sites[k];
        if (s->fn != owner) continue;           // a lexical arena and its site share a function
        if (aif_tier_of(k) != AIF_T1) continue;
        if (s->no_stack || s->in_container) continue;
        if (s->kind == AIF_K_LIST) continue;
        if (s->E < 0) continue;
        if (!is_ancestor_or_self(scope, s->scope)) continue;
        if (scope_lca(s->E, scope) != scope) continue;
        cand_served[k] = 1;
        if (s->scope == scope) cand_at[k] = s->stmt;
        // Otherwise it stays -1 and stmt_range_over declines, which is what c-i
        // does with the same site: a position in a nested block is not a
        // position in this one.
    }

    // And what a bracketed call sitting here would serve. The edge set is the
    // one bracket_place can draw from -- every call in this scope belonging to
    // the function that owns it, which is exactly what enclosing_region would
    // have found -- filtered by the obligations that mention no statement.
    for (int i = 0; i < call_edge_count; i++) {
        CallEdge* e = &call_edges[i];
        if (e->callee < 0 || e->callee >= fn_count) continue;
        if (e->caller != owner) continue;
        if (scope_lca(e->scope, scope) != scope) continue;
        if (!bracket_edge_ok_at(scope, owner, e,
                                &bracket_range_extent, &bracket_range_confined, 0)) continue;

        // Does this edge put anything in the arena at all? A bracket that serves
        // nothing contributes no statement: c-i positions from served sites, and
        // it would have none from this one. Counting it anyway would stretch the
        // range over calls the arena never sees -- and on `g2.psm` that is the
        // difference between an extent of [1,2] and one that swallows a clock.
        int serves = 0;
        for (int k = 0; k < site_count; k++) {
            int f = sites[k].fn;
            if (f < 0 || f >= fn_count || !bits_test(&bracket_range_extent, f)) continue;
            int tier = aif_tier_of(k);
            if (tier != AIF_T1 && tier != AIF_T2) continue;     // the bracketed gate
            if (sites[k].no_stack) continue;
            serves = 1;
            break;
        }
        if (!serves) continue;

        // The call has to be a statement of *this* block. `stmt` indexes the
        // block the call sits in and a nested one numbers its own from 0, so a
        // call one level down cannot be placed in this numbering -- and c-i
        // declines on the same bracket for the same reason.
        if (e->scope != scope || e->stmt < 0) return 0;

        for (int k = 0; k < site_count; k++) {
            int f = sites[k].fn;
            if (f < 0 || f >= fn_count || !bits_test(&bracket_range_extent, f)) continue;
            int tier = aif_tier_of(k);
            if (tier != AIF_T1 && tier != AIF_T2) continue;
            if (sites[k].no_stack) continue;
            cand_served[k] = 1;
            if (cand_at[k] < 0 || e->stmt < cand_at[k]) cand_at[k] = e->stmt;
        }
    }

    return stmt_range_over(scope, cand_served, cand_at, first, last);
}

// Memoised per scope, and safe to memoise because nothing it reads changes after
// the solve converges. It has to be: aif_place_arenas asks the obligation about
// every scope in turn while it is setting arena flags, and bracket_place asks it
// again afterwards. The two passes must get the same answer, or a scope gets an
// arena that nothing brackets into.
static int* cand_range_lo;
static int* cand_range_hi;
static signed char* cand_range_state;   // 0 not asked, 1 narrowed, -1 whole block
static int cand_range_cap;

static int cand_stmt_range(int scope, int* first, int* last) {
    if (scope < 0 || scope >= scope_count) return 0;
    if (scope >= cand_range_cap) {
        int grow = cand_range_cap ? cand_range_cap * 2 : 256;
        if (grow <= scope) grow = scope + 1;
        cand_range_lo = (int*)xrealloc(cand_range_lo, (size_t)grow * sizeof(int),
                                       "AIF candidate extent");
        cand_range_hi = (int*)xrealloc(cand_range_hi, (size_t)grow * sizeof(int),
                                       "AIF candidate extent");
        cand_range_state = (signed char*)xrealloc(cand_range_state, (size_t)grow,
                                                  "AIF candidate extent");
        for (int i = cand_range_cap; i < grow; i++) {
            cand_range_lo[i] = -1;
            cand_range_hi[i] = -1;
            cand_range_state[i] = 0;
        }
        cand_range_cap = grow;
    }
    if (cand_range_state[scope] == 0) {
        int lo = -1, hi = -1;
        int ok = cand_range_compute(scope, &lo, &hi);
        cand_range_state[scope] = ok ? 1 : -1;
        cand_range_lo[scope] = lo;
        cand_range_hi[scope] = hi;
    }
    if (cand_range_state[scope] < 0) return 0;
    if (first) *first = cand_range_lo[scope];
    if (last) *last = cand_range_hi[scope];
    return 1;
}

// M3.2d. The statement range codegen brackets an automatically placed arena
// with, or 0 for "the whole block" -- which is what every arena got before this.
//
// Two ranges bracket the same arena from opposite sides and this picks between
// them. c-i's is the tighter and describes what the arena actually holds; c-ii's
// is the one the opaque-call obligation was checked against, and emitting
// anything wider than it would put an opaque call inside the arena -- the exact
// hazard the obligation exists to catch.
//
// c-i's range lies inside c-ii's by construction: c-ii's served set is a
// superset, so it declines wherever c-i declines and its bounds are no tighter.
// The first branch is therefore the one that fires. The second is what happens
// if that argument is ever wrong, and it is safe rather than clever -- it falls
// back to the range the obligation actually cleared, never to the whole block.
static int arena_emit_range(int scope, int* first, int* last) {
    if (scope < 0 || scope >= scope_count || !scopes[scope].arena) return 0;
    if (scopes[scope].region_name >= 0) return 0;   // `region` brackets its braces

    int clo = 0, chi = 0;
    int narrowed = cand_stmt_range(scope, &clo, &chi);

    int plo = 0, phi = 0;
    if (arena_stmt_range(scope, &plo, &phi)) {
        if (!narrowed || (plo >= clo && phi <= chi)) {
            *first = plo;
            *last = phi;
            return 1;
        }
    }
    if (narrowed) {
        *first = clo;
        *last = chi;
        return 1;
    }
    return 0;
}

// M3.2d's two accessors. -1 from either means "bracket the whole block", which
// is the lexical extent and what codegen did before the range existed. They are
// two calls rather than one out-parameter because the frontend has no way to
// spell one.
int aif_arena_range_first(const void* node) {
    int lo = 0, hi = 0;
    int s = auto_arena_scope_at_node(node);
    if (s < 0 || !arena_emit_range(s, &lo, &hi)) return -1;
    return lo;
}

int aif_arena_range_last(const void* node) {
    int lo = 0, hi = 0;
    int s = auto_arena_scope_at_node(node);
    if (s < 0 || !arena_emit_range(s, &lo, &hi)) return -1;
    return hi;
}

// `unsized` counts sites whose size the frontend never computed -- a string or a
// list, whose length is a run-time value -- rather than guessing at one.
static long bracket_bytes_of(int scope, int* unsized) {
    bracket_place();
    long total = 0;
    for (int i = 0; i < bracket_count; i++) {
        if (brackets[i].scope != scope) continue;
        long callw = weight_of(brackets[i].call_scope, scope);
        bracket_reachable(brackets[i].callee, &bracket_place_extent);
        for (int k = 0; k < site_count; k++) {
            int f = sites[k].fn;
            if (f < 0 || f >= fn_count || !bits_test(&bracket_place_extent, f)) continue;
            if (site_arena_scope(k) != scope) continue;
            if (sites[k].bytes == 0) { if (unsized) (*unsized)++; continue; }
            total += (long)sites[k].bytes * weight_in_own_fn(sites[k].scope) * callw;
        }
    }
    return total;
}

static int site_in_released_field(int s);

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
        //
        // Site-level here is right: this clause is reached only for a value
        // whose E is its own scope, i.e. one allocated in this very function, so
        // the site and the binding are the same thing. The shared-site problem
        // is in elem_disposition_of, not here.
        if (s->no_stack) return 0;
        // A container took ownership, so the container's teardown is the release
        // point and this binding is not one. Reachable only when the two share a
        // scope -- otherwise the container's escape already lifted E past it and
        // the test above declined -- and in that case the element would otherwise
        // be freed here *and* at the teardown, newest binding first.
        if (s->in_container) return 0;
        // The same rule one level out: a struct field the type now releases is
        // this value's release point, so its binding is not. See
        // site_in_released_field for why the E test above does not already cover
        // it.
        if (site_in_released_field(n->site)) return 0;
        return aif_tier_of(n->site) == AIF_T0 ? 0 : 1;   // T0 storage is the frame
    }
    return 0;
}

// AIF Level 4, the reassignment half: may an assignment release what it displaces?
//
// Every clause of aif_frees_at_scope_node above applies unchanged -- an arena
// object is still not individually freeable, a container still owns its elements,
// a released field is still the release point -- except the one that asks whether
// the value is confined to the scope that allocated it. An accumulator is not:
// `let mut out = ""` binds in the caller's scope and allocates in a loop body, so
// E is the binding's scope, and `return out` lifts it to Caller.
//
// Relaxing that clause is sound because the question is different. The scope-exit
// drop asks where a value dies; this asks whether *this* value is still reachable
// once the slot stops naming it. A return does not make it reachable: a return
// exits the function, so the value an assignment displaces is one no return ever
// carried. What would make it reachable is another owner, and the surviving
// clauses are exactly the model's answers to that -- aliasing (site_is_move_only),
// a container (in_container), a struct field (site_in_released_field). Only
// AIF_E_GLOBAL has to be added back: a value stored into a global outlives every
// scope, and nothing above declines it once the confinement test is gone.
//
// This is what 3599 of g7's 5021 allocations were waiting on. The drop list
// refused every reassigned binding -- correctly, since the slot could hold a
// borrow -- and the assignment released nothing, so an accumulator's intermediate
// values had no owner at all. The syntactic half of the condition is in
// src/ir/expr.psm; this is the half only the model can answer.
int aif_releases_on_overwrite_node(const void* node) {
    if (node == NULL) return 0;
    if (aif_arena_at_node(node)) return 0;
    for (NodeSite* n = node_buckets[node_hash(node)]; n; n = n->next) {
        if (n->node != node) continue;
        Site* s = &sites[n->site];
        if (s->E == AIF_E_GLOBAL) return 0;
        if (!site_is_move_only(s)) return 0;
        if (s->kind == AIF_K_ARRAY) return 0;
        if (s->no_stack) return 0;
        if (s->in_container) return 0;
        if (site_in_released_field(n->site)) return 0;
        return aif_tier_of(n->site) == AIF_T0 ? 0 : 1;
    }
    return 0;
}

// Ownership inside containers
// A container teardown is a release point, and the container has to be told what
// its elements are: probing a pointer's header to find out would be reading
// memory in front of a pointer this compilation did not allocate, which is the
// same unsound move that bars refcounting an OPAQUE site.
// So the disposition is decided here, once, and codegen stamps it on the
// container at construction. It is a property of the *container site*, not of the
// element, because that is the only granularity a teardown loop has: one call per
// element, all elements alike.
// Which means a mixed container has no answer. If one element wants a free and
// another wants a decrement, neither is right for both and the honest outcome is
// to reclaim nothing -- today's behaviour, and a leak rather than a wrong free.
// The same goes for anything the deallocator cannot take: an array element is
// frame storage and an opaque one was never ours.

#define AIF_ELEM_NONE   0
#define AIF_ELEM_OBJECT 1   // the deallocator
#define AIF_ELEM_LIST   2   // list_release, which is two allocations
#define AIF_ELEM_RC     3   // Level 5: a decrement, and the last holder frees
#define AIF_ELEM_TYPED  4   // the type's generated release -- struct-field ownership
#define AIF_ELEM_CYCLE  5   // T4b: a decrement, and a non-zero result buffers a candidate
// REQUIREMENTS 15. The two above with an atomic decrement, for T4a. Two
// constants and not one plus a flag: SPEC 3 requires an implementation to
// distinguish the sub-classes and forbids charging collector participation to a
// T4a value that is provably acyclic, which is exactly what separates these.
#define AIF_ELEM_RC_ATOMIC    6
#define AIF_ELEM_CYCLE_ATOMIC 7

// AIF Level 5. Whether this site is allocated with a reference count.
//
// Three exclusions, and each is a different kind of "we did not allocate this":
//
//   * OPAQUE -- the pointer came back from a function this compilation cannot
//     see. There is no header in front of it. This is the exclusion that matters,
//     because it covers all 37 of the compiler's own T3 sites.
//   * STRING and LIST -- allocated inside lang_runtime.c, past the seam, so the
//     site cannot choose its own allocator. The same asymmetry Level 4 hit with
//     the arena; a hint would work here too and is not this level.
//   * ARRAY -- frame storage.
//
// And a positive requirement: the site must be in a container. A count is a count
// of container edges, so a value in none of them would be born at zero, never
// retained, never released, and pay 16 bytes of header for nothing.
static int site_is_rc(const Site* s, int tier) {
    // T4a counts too -- SPEC 3's cost table gives it "atomic count word", which
    // is the same header and the same container edges as T3's, differing only
    // in the instruction that touches it. Which instruction that is, is decided
    // where the decrement is emitted and not here.
    if (tier != AIF_T3 && tier != AIF_T4A) return 0;
    if (s->kind != AIF_K_STRUCT) return 0;
    if (s->no_stack) return 0;              // an explicit drop needs a plain free
    return s->in_container;
}

// AIF T4b. The same shape one tier up, and the exclusions are the same: the
// object must be one this compilation allocated, so there is a header in front
// of it, and it must be in a container, because a container edge is the only
// count this compiler both increments and decrements.
//
// The extra requirement over T3 is structural rather than a policy choice: a
// T4b site is one whose type is *not* acyclic (SPEC 4.2's C = MaybeCyclic), so
// there is an SCC to walk. Without one there are no cyclic children and the
// collector would buffer candidates it can never reclaim.
static int site_is_cyclic(const Site* s, int tier) {
    // SPEC 3: "A value meeting both conditions pays both. An implementation
    // SHALL distinguish the sub-classes; it SHALL NOT charge atomics to a T4b
    // value that is thread-local, nor collector participation to a T4a value
    // that is provably acyclic."
    //
    // Both halves of that last sentence are enforced right here. T4b never
    // reaches the atomic path because site_is_rc's tier test excludes it; and a
    // T4a value that is provably acyclic is turned away by the type_acyclic
    // test below, which is the *same* test that has always excluded acyclic
    // types -- so admitting T4a costs no new rule, only a wider tier test.
    if (tier != AIF_T4B && tier != AIF_T4A) return 0;
    if (s->kind != AIF_K_STRUCT) return 0;
    if (s->no_stack) return 0;
    if (s->type_acyclic) return 0;
    return s->in_container;
}

int aif_site_is_cyclic(int id) {
    if (id < 0 || id >= site_count) return 0;
    return site_is_cyclic(&sites[id], aif_tier_of(id));
}

int aif_cycle_at_node(const void* node) {
    if (node == NULL) return 0;
    for (NodeSite* n = node_buckets[node_hash(node)]; n; n = n->next) {
        if (n->node != node) continue;
        return site_is_cyclic(&sites[n->site], aif_tier_of(n->site));
    }
    return 0;
}

static int type_releases_of(int nominal);

static int elem_disposition_of(int id, int tier) {
    if (id < 0 || id >= site_count) return AIF_ELEM_NONE;
    const Site* s = &sites[id];
    if (s->kind == AIF_K_ARRAY || s->kind == AIF_K_OPAQUE) return AIF_ELEM_NONE;
    // SPEC 5.2.1.1's disposition half. An arena reclaims in bulk when its region
    // exits, so a value it serves is never released individually: handing a
    // pointer into the middle of a chunk to the deallocator is heap corruption,
    // and for a container element it is that once per element.
    //
    // **Disjoint from every clause below today**, because the placement gate
    // rejects `in_container` and `is_list`, so no arena-served site is ever an
    // element or a released field. It is here first, and deliberately: call-site
    // placement removes exactly those two rejections, and a disposition that
    // learned about arenas in the same change as placement would be a
    // use-after-free with nothing to compare it against. Verified inert on
    // landing -- byte-identical IR for every program in tests/, aif/corpus/ and
    // aif/evidence/.
    //
    // One clause rather than one per consumer, and that is the load-bearing part.
    // aif_elem_owner_at_node (a container's element release), field_release_of
    // (a struct's generated release), type_is_reclaimed and
    // aif_owns_call_result_at_node all read this function. The 2026-08-14 session
    // found the arena gate wearing four copies, one of which had drifted and was
    // placing arenas that served nothing; a second copy of *this* clause would be
    // the same defect with a use-after-free behind it instead of a wasted push.
    if (site_arena_scope(id) >= 0) return AIF_ELEM_NONE;
    // SPEC 3, in one place: "A value meeting both conditions pays both. An
    // implementation SHALL distinguish the sub-classes; it SHALL NOT charge
    // atomics to a T4b value that is thread-local, nor collector participation
    // to a T4a value that is provably acyclic."
    //
    // The four outcomes below are that sentence. T4a with an acyclic type gets
    // the atomic count and no collector; T4a whose type lies in an SCC gets
    // both; T4b gets the collector and a *plain* decrement, because a
    // thread-local cycle is still thread-local; T3 gets neither.
    //
    // Checked before the T3 clause rather than folded into it, because
    // site_is_rc now admits T4a as well -- an atomic value must not be able to
    // fall through to the non-atomic disposition on any path.
    if (tier == AIF_T4A) {
        if (site_is_cyclic(s, tier)) return AIF_ELEM_CYCLE_ATOMIC;
        if (site_is_rc(s, tier)) return AIF_ELEM_RC_ATOMIC;
        return AIF_ELEM_NONE;
    }
    if (site_is_rc(s, tier)) return AIF_ELEM_RC;
    if (site_is_cyclic(s, tier)) return AIF_ELEM_CYCLE;
    // T0 is the frame, and a T3 or T4b site the two predicates above declined has
    // no header to decrement.
    if (tier != AIF_T1 && tier != AIF_T2) return AIF_ELEM_NONE;
    // `no_stack` is deliberately not consulted here, and that is a fix rather
    // than an omission. It is a property of the *site* -- "this value cannot
    // live in a stack slot" -- while "has this binding already been freed" is a
    // property of the *binding*. The two coincided only while `std.string` was
    // C: an opaque `extern fn str_concat` gave every call site its own
    // extern-alloc value. Native `std` routes them all through the one
    // `str_with_capacity` inside `strConcat`, so a single site now backs every
    // string binding in the program -- and one `drop(x)` anywhere returned
    // AIF_ELEM_NONE for all of them, cancelling the release of every other
    // binding and leaking each one. TODO.md carries the reproducer.
    //
    // The binding-level question is asked by `chainDropsName` in
    // src/ir/stmt.psm, beside chainAssignsName and chainReturnsName, which is
    // where the other per-binding guards already live and the only place a
    // name is in scope to ask it of.
    //
    // aif_frees_at_scope_node keeps its own site-level test: that one is
    // reached only when E is the site's own scope, where site and binding
    // coincide.
    //
    // A *transfer* is still site-level here and must stay that way. An FFI
    // `consume` -- which is how a List becomes a DataView -- hands the
    // allocation to a callee that frees it, so emitting a release here as well
    // is a use-after-free rather than a leak. Removing this check along with
    // the `drop` one aborted g1_dataview in `list_release` on memory
    // `data_view_finish` had already freed.
    if (s->transferred) return AIF_ELEM_NONE;
    if (s->kind == AIF_K_LIST) return AIF_ELEM_LIST;
    // Struct-field ownership. Handing a struct with owned fields to the plain
    // deallocator frees the object and leaks everything it owns -- which is g3's
    // entire residue: 1365 Nodes, three owned struct fields each, 4095 leaks.
    if (s->kind == AIF_K_STRUCT && type_releases_of(nominal_find_id(s->type))) {
        return AIF_ELEM_TYPED;
    }
    return AIF_ELEM_OBJECT;
}

// Struct-field ownership
// The sibling of container ownership, and deliberately not the same mechanism.
// A container is *told* its element disposition at construction because its
// contents are dynamic -- the runtime is the only thing that knows how many
// elements there are or when the last one arrived. A struct's fields are known
// statically, right here in the nominal registry, so the answer is a **function
// generated per type** with one release per owned field emitted in line.
// Two consequences follow from that difference, and both are the point:
//   * **The disposition is per field, not per type.** A container reclaims
//     nothing when its elements disagree, because a teardown loop makes one call
//     for all of them. A generated function has a separate statement per field,
//     so `World` -- five owned `List`s and an `Int` -- releases the five and
//     steps over the Int. A single answer for the whole type would have to be
//     NONE for all six, which is exactly the leak this closes.
//   * **No runtime word.** The container needs `elem_own` on the object; a struct
//     needs nothing, because the type is what selects the function.
// The fact this reads is not new. A struct literal's field initialiser has been
// a STORE into `key_field(type, field)` since Level 0 -- that is what carries
// E-STORE and A-STORE -- so the sites that may reach a field are exactly
// `pt[key_field(type, field)]`. This adds a query, not a rule.

// Lookup without interning. A query after the solve must not add a key: pt is
// sized to key_count at solve start, so a fresh id would index past it, and a
// table that grows while it is being read is a table nobody can reason about.
static int key_find(int kind, int a, int b) {
    unsigned h = (unsigned)kind * 2654435761u
               ^ (unsigned)a * 40503u
               ^ (unsigned)b * 2246822519u;
    for (KeyNode* n = key_buckets[h & (AIF_KEY_BUCKETS - 1)]; n; n = n->next) {
        if (n->kind == kind && n->a == a && n->b == b) return n->id;
    }
    return -1;
}

// What release `type.field` needs, or NONE.
//
// Agreement over the field's points-to set, for the same reason the container
// case agrees over its elements: one field holds one pointer, but the analysis
// may not be able to say which site produced it, and a field that is a `List` on
// one path and an opaque on another has no single correct release.
// `List<Token>` -> `List`, on interned ids. The frontend's aif_base_type exists
// for the same reason field keys are object-insensitive: `list_new()` types as
// `List<Invalid>` and an annotated field does not, so a raw comparison of the
// two spellings would reject every container field.
static int base_type_id(int name) {
    const char* s = aif_str(name);
    const char* lt = strchr(s, '<');
    if (!lt) return name;
    char buf[128];
    size_t n = (size_t)(lt - s);
    if (n >= sizeof(buf)) n = sizeof(buf) - 1;
    memcpy(buf, s, n);
    buf[n] = '\0';
    return aif_intern(buf);
}

// Whether releasing this field would re-enter the type that owns it.
//
// `struct Node { parent: Node?, children: List<Node> }` is the shape:
// __aif_release_Node(n) releasing n.parent releases *its* parent, and so on
// until the stack gives out -- or, worse, around a cycle and back to an object
// already freed. A statically generated release is for the acyclic part of the
// type graph by construction, and a cycle is what SPEC's T4b collector is for.
//
// **Only reachable once REQUIREMENTS 4 exists.** Before `none` a parent
// back-reference did not typecheck, which is precisely why CYCLES had nothing to
// run against.
static int field_closes_cycle(int owner, int declared_type) {
    if (owner < 0 || declared_type < 0) return 0;
    int fid = nominal_find_id(declared_type);
    if (fid < 0) return 0;
    if (fid == owner) return 1;
    return bits_test(&nominals[fid].reaches, owner);
}

static int field_release_of(int type_name, int field_name, int declared_type) {
    int key = key_find(AIF_KEY_FIELD, type_name, field_name);
    if (key < 0 || key >= pt_len) return AIF_ELEM_NONE;
    // M2.1a. A field that re-enters its owner's type used to decline here, on the
    // grounds that releasing it could run around a cycle and back to a block
    // already freed. **The type graph cannot tell a cycle from a tree** -- `Tree`
    // reaches `Tree` exactly as `Node { parent: Node? }` does, and
    // aif_compute_type_acyclic calls both cyclic -- so declining on it declined
    // every recursive type, and a consumed tree was reclaimed by nothing at all:
    // not by this, and not by the collector either, which wants `in_container`.
    //
    // **The values answer what the type graph cannot, and the language already
    // decided it.** Storing into a field is a *move*: `Node { id: 2, parent: root }`
    // transfers `root`, so a field store leaves exactly one owner. Two references
    // to one value therefore require a container, which is precisely what
    // site_is_cyclic tests -- and such a site's disposition comes back
    // AIF_ELEM_CYCLE or AIF_ELEM_RC from elem_disposition_of below, routing it to
    // the collector rather than to the recursive free.
    //
    // So the disposition loop is the gate: a re-entering field is released only
    // when every site it can hold answers with a *plain ownership* disposition,
    // AIF_ELEM_TYPED or AIF_ELEM_OBJECT. Those are the tree-shaped ones, and
    // releasing them recursively frees each block exactly once.
    //
    // **A counted or collected site still declines, and that is not belt-and-
    // braces.** Cyclic edges belong to the collector -- CYCLES 4 gives them their
    // own traversal, `__aif_cyclic_children_T` -- so a release that also
    // decremented them would be reclaiming an edge twice. Removing this
    // restriction wholesale is what broke `test_52_aif_cycle_collector`: first 8
    // violations, then, once codegen decremented the count instead of free()ing,
    // a crash. The rule is not "recursion is safe", it is "recursion is safe for
    // the edges the collector does not own".
    int closes = field_closes_cycle(nominal_find_id(type_name), declared_type);

    // **An inline field owns nothing.** Its storage is the object's own and the
    // value was copied in, so there is no pointer to release and the address is
    // interior -- handing it to a deallocator would free the middle of this
    // allocation. Codegen has always known this and skipped the field; saying it
    // here as well is not a second copy of the rule but the *end* of one, because
    // this answer is also what `site_in_released_field` reads, and reporting a
    // field as owning what it does not is what stopped the caller from owning it
    // either. See `field_inline`.
    if (field_is_inline(type_name, field_name)) return AIF_ELEM_NONE;

    int agreed = AIF_ELEM_NONE;
    for (int s = 0; s < site_count; s++) {
        if (!bits_test(&pt[key], s)) continue;
        // **The slot has to hold what it says it holds.** This compiler puns an
        // ASTNode pointer as `String` and walks node chains through it, so a
        // `String` field can receive struct sites -- and a release chosen from
        // the sites alone emits `__aif_release_String`, which is not a function.
        // That is not a naming bug to paper over: the language and the analysis
        // genuinely disagree about what is in the slot, and the honest answer is
        // to reclaim nothing. Same discipline as arrays in
        // aif_frees_at_scope_node, which decline by kind for the same reason.
        if (declared_type >= 0 && base_type_id(sites[s].type) != declared_type) {
            return AIF_ELEM_NONE;
        }
        // See `closes` above: recursion into the owner's own type is allowed only
        // for values nothing else can reach.
        int d = elem_disposition_of(s, aif_tier_of(s));
        if (d == AIF_ELEM_NONE) return AIF_ELEM_NONE;
        // See `closes` above: only the edges the collector does not own.
        if (closes && d != AIF_ELEM_TYPED && d != AIF_ELEM_OBJECT) return AIF_ELEM_NONE;
        if (agreed == AIF_ELEM_NONE) agreed = d;
        else if (agreed != d) return AIF_ELEM_NONE;
    }
    return agreed;
}

// The declared type of a struct's i-th field, base-named, or -1.
static int field_declared_type(const Nominal* t, int i) {
    return t->field_type ? t->field_type[i] : -1;
}

// -1 not computed, -2 in progress.
//
// The in-progress marker is what a self-referential type needs. `struct Node {
// child: Node }` would otherwise have to know whether Node releases in order to
// decide whether Node releases.
//
// **It reads as "does" since M2.1a, and that is the whole of fork (a).** It read
// as "does not" before, with the reasoning that a type reaching itself is
// C-MAYBE and therefore the collector's problem. That was true of the *type* and
// false of most values: a tree reaches itself in the type graph and contains no
// cycle, and the collector never ran on one either, because site_is_cyclic wants
// `in_container` and a tree node is not in one. Neither path reclaimed it, so a
// consumed tree leaked entirely -- 24569 of 24585 allocations on
// `g8_tree_rebuild.psm`.
//
// Answering "does" is what makes the recursive field's disposition AIF_ELEM_TYPED
// rather than AIF_ELEM_OBJECT, and that difference is the whole feature: OBJECT
// frees the child block alone and leaks its subtree, TYPED calls
// `__aif_release_T` on it and the recursion reaches the leaves.
//
// The optimism is bounded by field_release_of, not by this marker: the only way
// to reach it is through a field that re-enters the owner's type, and that field
// contributes a disposition only when every site it can hold is AIF_A_UNIQUE. A
// `parent` back-reference is not, so the answer for that shape is still 0 --
// reached through an empty `agreed` rather than through this marker.
//
// **Known limit, and it is unmeasured on purpose:** the generated release
// recurses once per level, so reclaiming a structure of depth d costs d stack
// frames. A balanced tree is fine (d is logarithmic); a list-shaped recursive
// type is not, and deep enough it would trade a leak for a stack overflow.
// There is no measured threshold here because the shape that would hit it cannot
// be reached yet: a deep structure has to be *built* recursively, and ownership
// transfer survives only one hop, so its caller owns nothing and no release runs
// at all. Whichever change lifts that hop makes this reachable and should bring
// its own measurement -- and the fix is to loop on the last self-referential
// field rather than recurse into it.
static int* type_releases;
static int type_releases_cap;

static int type_releases_of(int nominal) {
    if (nominal < 0 || nominal >= nominal_count) return 0;
    if (nominals[nominal].is_enum) return 0;

    // **The release half of the hot/cold split, and it is one clause.**
    //
    // A split object is two allocations. The type-blind deallocator behind
    // ir_free_object frees one block and cannot name the type, so it would leak
    // the cold half of every split object it ever saw. Forcing this true routes
    // every drop, every container element and every owned field of a split type
    // through the generated `__aif_release_T` instead -- which *does* know the
    // type, and which frees the cold block before the base (ir_free_cold).
    //
    // This is the "generated release even when the type owns no fields" the
    // original brief names. It is safe to force because the generated body is the
    // same code either way: it emits one release per field whose disposition is
    // not NONE, and a type that owned nothing before still owns nothing now, so
    // all the forcing adds is the wrapper and the cold free.
    //
    // Not cached, and deliberately ahead of the cache: the cache is keyed on the
    // field walk alone, and a split decision that arrived after a cached 0 would
    // be a leak nothing reports.
    if (nominals[nominal].hot_count > 0) return 1;

    if (nominal >= type_releases_cap) {
        int grow = type_releases_cap ? type_releases_cap * 2 : 64;
        if (grow <= nominal) grow = nominal + 1;
        type_releases = (int*)xrealloc(type_releases, (size_t)grow * sizeof(int),
                                       "AIF type release cache");
        for (int i = type_releases_cap; i < grow; i++) type_releases[i] = -1;
        type_releases_cap = grow;
    }
    if (type_releases[nominal] == -2) return 1;   // see the note above the cache
    if (type_releases[nominal] >= 0) return type_releases[nominal];

    type_releases[nominal] = -2;
    Nominal* t = &nominals[nominal];
    int any = 0;
    for (int i = 0; i < t->nfields && !any; i++) {
        if (field_release_of(t->name, t->field_name[i], field_declared_type(t, i))
            != AIF_ELEM_NONE) any = 1;
    }
    type_releases[nominal] = any;
    return any;
}

int aif_type_releases(const char* name) {
    return type_releases_of(nominal_find(name));
}

// ---------------------------------------------------------------------------
// CYCLES 4 -- the cyclic-edge restriction
//
// Every edge of a value-level reference cycle connects two types in one SCC of
// the type reference graph: an edge x -> y arises from a field of type(x) that
// can hold a type(y), so the types of a value cycle form a directed cycle in the
// type graph and therefore lie in one SCC.
//
// So a collector that traverses only fields whose type is in the owner's SCC
// still finds every cycle -- and never *leaves* the skeleton. A Node with two
// child pointers and six fields of tokens, strings and spans is walked through
// two edges rather than eight, and the collector never descends into the string
// graph hanging off it. Those subgraphs are usually far larger than the cyclic
// skeleton, which is what makes CYCLES 6's work bounds credible.
// ---------------------------------------------------------------------------

static int same_scc(int a, int b) {
    if (a < 0 || b < 0) return 0;
    if (a == b) return bits_test(&nominals[a].reaches, a);   // a non-trivial self-loop
    return bits_test(&nominals[a].reaches, b) && bits_test(&nominals[b].reaches, a);
}

// Whether this type lies in a non-trivial SCC. The transitive closure marks a
// type as reaching itself exactly then, which is also what makes it not acyclic.
int aif_type_in_cycle(const char* name) {
    int id = nominal_find(name);
    if (id < 0 || nominals[id].is_enum) return 0;
    return bits_test(&nominals[id].reaches, id) ? 1 : 0;
}

// Whether this field is a cyclic edge, i.e. one the collector traverses.
int aif_field_is_cyclic(const char* type, const char* field) {
    int owner = nominal_find(type);
    if (owner < 0 || nominals[owner].is_enum) return 0;
    Nominal* t = &nominals[owner];
    int fname = aif_intern(field);
    for (int i = 0; i < t->nfields; i++) {
        if (t->field_name[i] != fname) continue;
        return same_scc(owner, nominal_find_id(field_declared_type(t, i)));
    }
    return 0;
}

// Whether a store into this field must move a reference count.
//
// **Bacon-Rajan requires the count to reflect every reference the traversal
// walks.** Trial deletion subtracts the internal edges and reads what is left as
// "held from outside"; an edge the collector traverses but nobody ever counted
// makes that subtraction remove a reference that was never added, and the
// arithmetic says unreachable for a live object. That is a premature free, and
// it is what the first build of the collector did -- a segfault on the fixture,
// not a leak.
//
// So a cyclic field is counted, and only when every site that can reach it is
// one the collector can take. A field mixing a counted object with an opaque or
// stack one has no correct answer and moves no count, which leaks rather than
// corrupting.
int aif_field_is_counted(const char* type, const char* field) {
    if (!aif_field_is_cyclic(type, field)) return 0;
    int owner = nominal_find(type);
    if (owner < 0) return 0;
    int key = key_find(AIF_KEY_FIELD, nominals[owner].name, aif_intern(field));
    if (key < 0 || key >= pt_len) return 0;

    int any = 0;
    for (int s = 0; s < site_count; s++) {
        if (!bits_test(&pt[key], s)) continue;
        any = 1;
        if (!site_is_cyclic(&sites[s], aif_tier_of(s))) return 0;
    }
    return any;
}

// CYCLES 2's headline result, as a number the manifest can print: how many types
// lie in a non-trivial SCC. Zero means the program cannot leak a cycle and the
// collector is omitted from the binary entirely -- a property checkable from the
// type declarations alone, before any inference runs.
int aif_scc_type_count(void) {
    int n = 0;
    for (int i = 0; i < nominal_count; i++) {
        if (nominals[i].is_enum) continue;
        if (bits_test(&nominals[i].reaches, i)) n++;
    }
    return n;
}

int aif_t4b_site_count(void) {
    int n = 0;
    for (int s = 0; s < site_count; s++) {
        if (aif_tier_of(s) == AIF_T4B) n++;
    }
    return n;
}

int aif_field_release(const char* type, const char* field) {
    int id = nominal_find(type);
    if (id < 0 || nominals[id].is_enum) return AIF_ELEM_NONE;
    Nominal* t = &nominals[id];
    int fname = aif_intern(field);
    for (int i = 0; i < t->nfields; i++) {
        if (t->field_name[i] != fname) continue;
        return field_release_of(t->name, fname, field_declared_type(t, i));
    }
    return AIF_ELEM_NONE;
}

// Whether any released field may hold this site.
//
// This is the double-free rule `in_container` encodes, one level out. A value
// stored into a field the type now releases has the struct's teardown as its
// release point, so its own binding is not one -- otherwise it is freed at the
// scope exit *and* again when the struct goes.
//
// Reachable for the same narrow reason the container case is: normally E-STORE
// has already raised the value's escape to the struct's, and the `E == scope`
// test in aif_frees_at_scope_node declines first. It is only when the struct and
// the field's value share a scope that both tests pass and this one has to say
// no.
//
// Computed once over every (type, field) rather than per site, because the
// answer depends on the type's fields and not on where the site sits.
static Bits in_released_field;
static int in_released_field_done;

// Whether anything actually reclaims a value of this type.
//
// **A field is only a release point if its owner has one**, and that is not
// implied by the owner having a generated release function. A T0 struct lives in
// the frame: nothing frees it, so nothing runs its release, so its fields are
// reclaimed by nobody. Barring the field's own binding there does not move the
// release -- it deletes it.
//
// g5_asset_cache is the case, and it cost a 47 -> 2049 regression to find. Its
// `Scene` is four fields and does not escape `main`, so it takes the T0 clause;
// the `entities` list stored in it was being freed at main's exit, and barring
// that on the strength of `Scene`'s release function leaked all 2000 elements.
static int type_reclaimed_cache_valid;
static int* type_reclaimed;

static int type_is_reclaimed(int nominal) {
    if (nominal < 0 || nominal >= nominal_count) return 0;
    if (!type_reclaimed_cache_valid) {
        type_reclaimed = (int*)xcalloc((size_t)nominal_count, sizeof(int),
                                       "AIF reclaimed types");
        for (int s = 0; s < site_count; s++) {
            if (elem_disposition_of(s, aif_tier_of(s)) == AIF_ELEM_NONE) continue;
            int id = nominal_find_id(base_type_id(sites[s].type));
            if (id >= 0) type_reclaimed[id] = 1;
        }
        type_reclaimed_cache_valid = 1;
    }
    return type_reclaimed[nominal];
}

static void compute_released_fields(void) {
    if (in_released_field_done) return;
    in_released_field_done = 1;
    for (int n = 0; n < nominal_count; n++) {
        if (nominals[n].is_enum) continue;
        if (!type_is_reclaimed(n)) continue;
        Nominal* t = &nominals[n];
        for (int i = 0; i < t->nfields; i++) {
            if (field_release_of(t->name, t->field_name[i], field_declared_type(t, i))
                == AIF_ELEM_NONE) continue;
            int key = key_find(AIF_KEY_FIELD, t->name, t->field_name[i]);
            if (key < 0 || key >= pt_len) continue;
            bits_or(&in_released_field, &pt[key], "AIF released fields");
        }
    }
}

static int site_in_released_field(int s) {
    compute_released_fields();
    return bits_test(&in_released_field, s);
}

// Whether codegen should allocate this node's value through rc_alloc.
//
// Keyed by node like every other codegen query, and it must agree with
// elem_disposition_of exactly: a container told its elements are counted will
// decrement every one of them, so a site that reached that container without a
// header is a write through a pointer into someone else's allocation. They read
// the same predicate for that reason.
int aif_rc_at_node(const void* node) {
    if (node == NULL) return 0;
    for (NodeSite* n = node_buckets[node_hash(node)]; n; n = n->next) {
        if (n->node != node) continue;
        return site_is_rc(&sites[n->site], aif_tier_of(n->site));
    }
    return 0;
}

// What the container allocated at this node should do with its elements.
int aif_elem_owner_at_node(const void* node) {
    if (node == NULL) return AIF_ELEM_NONE;
    int container = -1;
    for (NodeSite* n = node_buckets[node_hash(node)]; n; n = n->next) {
        if (n->node == node) { container = n->site; break; }
    }
    if (container < 0) return AIF_ELEM_NONE;

    int agreed = AIF_ELEM_NONE;
    for (int s = 0; s < site_count; s++) {
        if (!bits_test(&container_of[s], container)) continue;
        int d = elem_disposition_of(s, aif_tier_of(s));
        if (d == AIF_ELEM_NONE) return AIF_ELEM_NONE;
        if (agreed == AIF_ELEM_NONE) agreed = d;
        else if (agreed != d) return AIF_ELEM_NONE;
    }
    return agreed;
}

// The element type of a container whose elements are released by type.
//
// Read from the sites rather than from the container's spelled type, for the
// same reason the element key is object-insensitive: `list_new()` types as
// `List<Invalid>`, so the annotation is not always there to read, and the sites
// that actually reached the container always are. "" when they disagree, which
// aif_elem_owner_at_node has already turned into NONE.
const char* aif_elem_type_at_node(const void* node) {
    if (node == NULL) return "";
    int container = -1;
    for (NodeSite* n = node_buckets[node_hash(node)]; n; n = n->next) {
        if (n->node == node) { container = n->site; break; }
    }
    if (container < 0) return "";

    int agreed = -1;
    for (int s = 0; s < site_count; s++) {
        if (!bits_test(&container_of[s], container)) continue;
        if (agreed < 0) agreed = sites[s].type;
        else if (agreed != sites[s].type) return "";
    }
    return agreed < 0 ? "" : aif_str(agreed);
}

// M4.2. Whether any site of this type carries a reference count or is collected.
//
// **A type question, not a site question, and it has to be.** Inline element
// storage is decided per element *type* at every call site -- the stamp, the
// push, the get and the set all read `ir_struct_is_flat` and have to reach the
// same answer, because a list one site thinks is inline and another does not is
// a body written where a pointer belongs. A container's disposition
// (`aif_elem_owner_at_node`) is visible only at its construction, so it cannot
// be that shared answer; this can.
//
// A counted value keeps its count in a header in front of the object. An inline
// body has no header and no identity of its own, so `rc_retain` on a push and
// `rc_release` on a teardown would both be operating on the middle of an element
// block. test_48 is the fixture: an `Item` shared between two containers is T3,
// and pushing `list_get(a, 0)` into `b` released an interior pointer.
//
// Unknown answers 1 -- refuse inline -- because boxing is always correct and
// inlining a counted type is not.
int aif_type_is_counted(const char* type) {
    if (type == NULL || *type == 0) return 1;
    for (int s = 0; s < site_count; s++) {
        if (sites[s].type < 0) continue;
        const char* name = aif_str(sites[s].type);
        if (name == NULL || strcmp(name, type) != 0) continue;
        int tier = aif_tier_of(s);
        if (tier == AIF_T4A) return 1;
        if (site_is_rc(&sites[s], tier)) return 1;
        if (site_is_cyclic(&sites[s], tier)) return 1;
    }
    return 0;
}

int aif_site_in_container(int id) {
    if (id < 0 || id >= site_count) return 0;
    return sites[id].in_container;
}

// The manifest's half of aif_rc_at_node. SPEC 6.2's placement column has to say
// what was *built*, and "rc" for a T3 site nothing counts would be the manifest
// asserting a mechanism the binary does not contain.
int aif_site_is_rc(int id) {
    if (id < 0 || id >= site_count) return 0;
    return site_is_rc(&sites[id], aif_tier_of(id));
}

// Ownership transfer across a return
// `let cmds = cull(scene, ...)` allocates in the callee and reclaims in the
// caller, and the escape lattice cannot say so: E is per site, a site belongs to
// one function, and Region(s) can only name a scope in that function. So a
// returned value is Caller and stays Caller no matter how briefly the caller
// keeps it. INFERENCE 6's ownership contexts are the specified fix -- instantiate
// the callee per call site so the return lands in the caller's scope -- and that
// is a project, not a clause.
// What is available without it: T2 already means "unique, and the callee kept no
// other holder", which is the whole of what the caller needs to know. The rest is
// asked of the syntax at the binding, the same way node_assigns_name is, because
// the two things that could still go wrong are both visible there.
//   * The callee returned something it did not allocate -- a pass-through of its
//     own argument. Then the caller frees a value it already owns elsewhere.
//     Excluded by requiring every site in the return set to belong to the callee.
//   * The caller returns it onward. Excluded in ir.psm by node_returns_name,
//     which is the guard the escape fact would otherwise have supplied.
// Restricted to a returned **container**, and the restriction is a soundness
// requirement rather than a conservative start. A value set records the sites an
// expression may denote, and a string literal or a static is not a site -- so for
// a function returning `String`, `return "ptr"` contributes nothing and the set
// looks exactly like one that always allocates. Freeing that is a free of
// `.rodata`, which is the defect Level 4 found in `str_substring` arriving by a
// different road. The same goes for a struct-returning function with a sentinel
// path.
// A `List` has no literal form: `list_new` and `list_new_with_capacity` are the
// only ways to make one and both always allocate. So the return set of a
// list-returning function is complete, which is the property this needs and the
// one the other two lack -- and it is a property to check when a third
// constructor is added, not a fact about the count. Recovering the other two
// needs the points-to lattice to carry "may hold something untracked", which is a
// real extension and not this item.
// Returns the deallocator the result needs: 0 none, 2 list.

typedef struct NodeCall {
    struct NodeCall* next;
    const void* node;
    int vs;
    int fn;
} NodeCall;

static NodeCall* call_buckets[AIF_NODE_BUCKETS];
static Bits query_scratch;

void aif_note_call_result(const void* node, int vs, int fn) {
    if (node == NULL || fn < 0) return;
    unsigned b = node_hash(node);
    for (NodeCall* n = call_buckets[b]; n; n = n->next) {
        if (n->node == node) return;
    }
    NodeCall* n = (NodeCall*)xmalloc(sizeof(NodeCall), "AIF call index");
    n->node = node;
    n->vs = vs;
    n->fn = fn;
    n->next = call_buckets[b];
    call_buckets[b] = n;
}

// FFI 5.2's `alias` question, asked of a *Prismio* function: is every value this
// one may return an allocation it made itself?
//
// The answer decides whether a caller may free the result, and it is only a
// question for a type with a **literal form**. A `List` has none and a struct
// has no sentinel, so every way to produce one is a site -- which is the
// completeness argument aif_owns_call_result_at_node rests on. A `String` breaks
// it: `return "0"` hands back static storage, contributes no site, and is
// *invisible* in the returned value set, so a caller that freed it would hand
// .rodata to the deallocator.
//
// So the fact is derived from the returns themselves. Every `return <expr>`
// binds the RET key (src/aif/walk.psm), and a bind whose value set resolves to
// **no site at all** is a path this pass cannot account for: a literal, a
// borrowed parameter, an Int. One such return makes the function partial and its
// result unowned -- which is the conservative direction, a leak rather than a
// free of something the caller never owned.
//
// Read from the constraints rather than recorded separately, because the bind is
// already there and a second record is a second thing to keep in step.
static char* fn_ret_partial;
static int ret_partial_ready;

static int bits_any(const Bits* b) {
    for (int i = 0; i < b->nwords; i++) {
        if (b->w[i]) return 1;
    }
    return 0;
}

static void ret_partial_build(void) {
    if (ret_partial_ready) return;
    ret_partial_ready = 1;
    if (fn_count == 0) return;
    fn_ret_partial = (char*)xcalloc((size_t)fn_count, 1, "AIF return provenance");
    key_index_build();

    // Its own Bits: the only caller resolves into query_scratch immediately
    // after, and one shared buffer would have this pass answering about the
    // wrong value set on the first call.
    static Bits ret_scratch;
    for (int i = 0; i < con_count; i++) {
        if (cons[i].kind != AIF_CON_BIND) continue;
        int key = cons[i].a;
        if (key < 0 || key >= key_count) continue;
        KeyNode* kn = key_by_id[key];
        if (kn == NULL || kn->kind != AIF_KEY_RET) continue;
        int f = kn->a;
        if (f < 0 || f >= fn_count) continue;
        resolve(cons[i].b, &ret_scratch);
        if (bits_any(&ret_scratch)) continue;
        fn_ret_partial[f] = 1;
    }
}

// 1 when some `return` in `f` yields a value with no site behind it, so the
// caller must not take ownership of what `f` hands back.
static int fn_returns_partial(int f) {
    ret_partial_build();
    if (f < 0 || f >= fn_count) return 1;
    return fn_ret_partial ? fn_ret_partial[f] : 1;
}

// Whether `f` may hand one of its own parameters back through its return value.
//
// Swift's parameter convention question, asked in the direction the drop path
// needs it: an `@guaranteed` parameter leaves the caller owning the argument
// across the call, and a parameter passed through to the result does not -- the
// argument outlives the call and the caller's binding is no longer the last
// owner. Perceus asks the same thing as "borrowed vs owned" parameter inference.
//
// The caller's drop path needs it because the escape lattice cannot supply it.
// A value allocated in a callee is already at Caller (SPEC 5's E is per site,
// and a site belongs to the function that allocated it), so E says nothing about
// whether *this* frame still owns it. That is why src/ir/expr.psm carries the
// syntactic `nodeReturnsName` -- and why that guard alone is not enough: it sees
// `return t` and not `return passthru(t)`.
//
// Read off the converged points-to sets rather than recorded separately, for the
// same reason `fn_returns_partial` is: the RET and PARAM edges are already there
// and a second record is a second thing to keep in step.
//
// **Site-granular, and conservative in the same direction `in_container` is.**
// One site serves every call of the allocating function, so two different
// allocations from one `Band { ... }` literal are one bit here. A false positive
// therefore costs a leak and never a free, which is the only asymmetry that
// matters on this path.
//
// **A symbol this pass does not know answers no, not yes**, and the reason is
// that "unknown" here means *extern*, not *unanalysed*. An extern's result is
// the frontend's contract question -- `alias` is the one contract that hands an
// argument back, and aifFfiAliasOf in src/aif/contracts.psm is where it is
// answered -- so widening it here says nothing true and costs a great deal.
// Answering yes was measured: it declines the drop at every `print(value)` in
// std/io.psm, because `prismio_rt_print(text)` is an extern declared `borrow`,
// and it took three suite fixtures with it (split_release, forced_layout,
// aif_verify) by leaking one String per integer printed.
//
// The extern half of this hazard is therefore still open, exactly as wide as it
// was before this predicate existed: `let t = f(); let x = <extern alias>(t);
// return x` frees `t` at the scope exit. It is recorded in TODO.md rather than
// closed here, because closing it is a frontend change and this is not one.
static int fn_may_return_param(int f) {
    if (f < 0) return 0;
    int rk = key_find(AIF_KEY_RET, f, 0);
    if (rk < 0 || rk >= pt_len) return 0;
    if (!bits_any(&pt[rk])) return 0;

    key_index_build();
    for (int k = 0; k < key_count && k < pt_len; k++) {
        KeyNode* kn = key_by_id[k];
        if (kn == NULL || kn->kind != AIF_KEY_PARAM || kn->a != f) continue;
        int n = pt[rk].nwords < pt[k].nwords ? pt[rk].nwords : pt[k].nwords;
        for (int w = 0; w < n; w++) {
            if (pt[rk].w[w] & pt[k].w[w]) return 1;
        }
    }
    return 0;
}

int aif_fn_may_return_param(const char* symbol) {
    return fn_may_return_param(aif_fn_lookup(symbol));
}

int aif_owns_call_result_at_node(const void* node) {
    if (node == NULL) return AIF_ELEM_NONE;
    NodeCall* c = NULL;
    for (NodeCall* n = call_buckets[node_hash(node)]; n; n = n->next) {
        if (n->node == node) { c = n; break; }
    }
    if (c == NULL) return AIF_ELEM_NONE;

    resolve(c->vs, &query_scratch);
    int agreed = AIF_ELEM_NONE;
    int any = 0;
    for (int s = 0; s < site_count; s++) {
        if (!bits_test(&query_scratch, s)) continue;
        any = 1;
        // Allocated below this callee, not handed *to* it.
        //
        // This used to require `sites[s].fn == c->fn` outright, which is one
        // hop: it declined every producer written in Prismio the moment a second
        // frame appeared between the allocation and the binding
        // (tests/owned_return_depth2.psm, 6/6/0 at depth 1 and 12/7/5 at
        // depth 2). It was invisible while `std.string` was C, because an
        // `extern fn` carries its `produce` contract and answers at depth 1.
        //
        // **What made it safe to relax is the pass-through guard, not a new
        // fixed point.** The hazard the old test named is real -- a value handed
        // *in* and handed straight back is owned by the caller's argument, and
        // freeing it here double-frees. That is exactly `fn_may_return_param`,
        // so it is asked directly instead of being approximated by "the site
        // belongs to somebody else".
        //
        // The other half -- "no intermediate frame owns it" -- needs nothing
        // computed, because **returning a value already implies not dropping
        // it**. A frame that binds the value and returns the binding is declined
        // by `nodeReturnsName`; one that returns it through a further call is
        // declined by `nodeEscapesThroughCall` (src/ir/expr.psm). So every frame
        // on the path from the allocation to here has already been refused
        // ownership of it, and this caller is the first that can hold it.
        if (sites[s].fn != c->fn && fn_may_return_param(c->fn)) return AIF_ELEM_NONE;
        if (sites[s].in_container) return AIF_ELEM_NONE;
        // A field the type releases is already this value's release point, so
        // the caller must not become a second one. The same exclusion as
        // in_container above, and reachable the same way: a function that both
        // stores a value into a field and returns that field.
        if (site_in_released_field(s)) return AIF_ELEM_NONE;
        if (aif_tier_of(s) != AIF_T2) return AIF_ELEM_NONE;
        int d = elem_disposition_of(s, AIF_T2);
        // A struct that owns something joins `List` here, and for the same
        // reason the comment above gives: the value set has to be complete.
        // A `List` qualifies because it has no literal form. A struct qualifies
        // because it has no *sentinel* form -- there is no null, so every way to
        // produce one is either a literal (a site in this callee) or a value
        // that came from somewhere else (a site whose fn is not this one, which
        // the test above declines). **REQUIREMENTS 4 must not break that**: an
        // Option-typed return would be the first struct-shaped value that is not
        // a site, and this is the line it would make unsound.
        //
        // **A plain object joins them where the returns are accounted for.**
        // This was restricted to LIST and TYPED because the completeness
        // argument above does not survive a type with a literal form, and a
        // `String` has one -- which was the right call while nothing derived the
        // missing fact. `fn_returns_partial` derives it, so the clause is now the
        // fact rather than the type: a callee with even one `return` this pass
        // cannot place a site behind is declined exactly as before.
        //
        // It is where the remaining leak is. Every integer `print`/`println`
        // goes through `prismio_std_io_signed_integer`, which returns a String
        // the caller had no way to own -- 5 allocations and 5 leaks for a
        // five-digit number, in every program that prints a number.
        if (d != AIF_ELEM_LIST && d != AIF_ELEM_TYPED) {
            if (d != AIF_ELEM_OBJECT) return AIF_ELEM_NONE;
            if (fn_returns_partial(c->fn)) return AIF_ELEM_NONE;
        }
        if (agreed != AIF_ELEM_NONE && agreed != d) return AIF_ELEM_NONE;
        agreed = d;
    }
    return any ? agreed : AIF_ELEM_NONE;
}

// Manifest ordering
// SPEC 6.2 makes the record order normative -- byte-wise ascending by symbol --
// because an unstable order makes every diff useless. The frontend builds each
// record's symbol (it knows what a symbol means) and hands it here to be sorted
// (sorting is a container operation).
// Insertion-order-stable, so equal symbols keep the order they were added in.
// There should be no equal symbols; relying on that rather than asserting it
// would make a future collision reorder the manifest silently.

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

// Reset
// A compiler run analyses one program, but the test harness and any future
// per-module invocation want a clean slate. Interned names are deliberately
// kept: they cost nothing and nothing outside this file holds an id across a
// reset.

void aif_reset(void) {
    g_stmt = -1;
    free(scope_stmt);
    scope_stmt = NULL;
    scope_stmt_cap = 0;
    free(key_last_stmt);
    key_last_stmt = NULL;
    key_last_stmt_cap = 0;
    free(placed_served);
    free(cand_served);
    free(placed_at);
    free(cand_at);
    placed_served = NULL;
    cand_served = NULL;
    placed_at = NULL;
    cand_at = NULL;
    range_scratch_cap = 0;
    free(cand_range_lo);
    free(cand_range_hi);
    free(cand_range_state);
    cand_range_lo = NULL;
    cand_range_hi = NULL;
    cand_range_state = NULL;
    cand_range_cap = 0;
    free(fn_ret_partial);
    fn_ret_partial = NULL;
    ret_partial_ready = 0;
    for (int i = 0; i < pt_len; i++) bits_free(&pt[i]);
    for (int i = 0; i < holders_len; i++) bits_free(&holders[i]);
    for (int i = 0; i < holders_len; i++) bits_free(&container_of[i]);
    if (key_views) { for (int i = 0; i < pt_len; i++) bits_free(&key_views[i]); }
    free(pt);
    free(holders);
    free(container_of);
    free(key_views);
    pt = NULL;
    holders = NULL;
    container_of = NULL;
    key_views = NULL;
    pt_len = 0;
    holders_len = 0;

    // LAYOUT 5's traversal table, for exactly the reason the call graph below is
    // torn down: a declared `workload` runs the engine twice in one process, and
    // traversals that survived would be counted against a second set of loop ids
    // -- doubling every co-access set and, because the loop ids differ, doing it
    // as *extra traversals* rather than as bigger ones. The cost of a candidate
    // would then scale with how many times the engine had run.
    traversals_reset();
    candidates_clear();

    // SPEC 5.2.1.1's call graph. It has to be torn down here like everything
    // else, and the reason is not hypothetical: a declared `workload` runs the
    // whole engine twice in one process (LAYOUT 3.2), so edges that survived a
    // reset would double every call-site count -- and regime (a) turns on
    // exactly that count, so every callee would report two call sites and no
    // function would ever be sole-regime. A wrong answer, silently, on the
    // programs that carry a profile and on no others.
    for (int i = 0; i < bracket_fn_cap; i++) {
        bits_free(&fn_callees[i]);
        bits_free(&fn_owner_fns[i]);
    }
    free(fn_callees);
    free(fn_owner_fns);
    free(fn_has_global);
    free(fn_has_drop);
    free(fn_calls_opaque);
    free(fn_allocs_reach);
    free(elem_uses);
    elem_uses = NULL;
    elem_use_count = 0;
    elem_use_cap = 0;
    fn_callees = NULL;
    fn_owner_fns = NULL;
    fn_has_global = NULL;
    fn_has_drop = NULL;
    fn_calls_opaque = NULL;
    fn_allocs_reach = NULL;
    bracket_fn_cap = 0;
    bracket_ready = 0;
    free(call_edges);
    call_edges = NULL;
    call_edge_count = 0;
    call_edge_cap = 0;
    free(owner_uses);
    owner_uses = NULL;
    owner_use_count = 0;
    owner_use_cap = 0;
    bits_free(&bracket_closure);
    bits_free(&bracket_scratch);

    // SPEC 5.2.1.1's placement, torn down for the same reason the call graph
    // above is: a declared `workload` runs the whole engine twice in one process,
    // and site_bracket indexed by a *previous* run's site ids would hand this
    // run's sites an arena chosen for someone else's program.
    free(site_bracket);
    site_bracket = NULL;
    free(brackets);
    brackets = NULL;
    bracket_count = 0;
    bracket_cap = 0;
    bracket_place_ready = 0;
    bits_free(&bracket_place_extent);
    bits_free(&bracket_place_confined);
    for (int i = 0; i < site_owner_len; i++) bits_free(&site_owner_sites[i]);
    free(site_owner_sites);
    site_owner_sites = NULL;
    site_owner_len = 0;
    bits_free(&owner_bits_val);
    bits_free(&owner_bits_own);
    free(owner_vec_val.v);
    free(owner_vec_own.v);
    owner_vec_val.v = NULL; owner_vec_val.len = 0; owner_vec_val.cap = 0;
    owner_vec_own.v = NULL; owner_vec_own.len = 0; owner_vec_own.cap = 0;
    free(key_by_id);
    key_by_id = NULL;
    key_by_id_len = 0;

    bits_free(&in_released_field);
    in_released_field_done = 0;
    free(type_releases);
    type_releases = NULL;
    type_releases_cap = 0;
    free(type_reclaimed);
    type_reclaimed = NULL;
    type_reclaimed_cache_valid = 0;

    free(deriv_e);
    free(deriv_a);
    deriv_e = NULL;
    deriv_a = NULL;
    cause_len = 0;
    cur_con = -1;
    synth_rule = -1;
    force_rule = -1;

    for (int i = 0; i < vs_count; i++) { free(vsets[i].items); free(vsets[i].views); }
    vs_count = 0;

    for (int i = 0; i < nominal_count; i++) {
        bits_free(&nominals[i].reaches);
        bits_free(&nominals[i].hot);
        free(nominals[i].field_name);
        free(nominals[i].field_type);
        free(nominals[i].field_bytes);
        free(nominals[i].field_acc);
        free(nominals[i].order);
        free(nominals[i].field_lo);
        free(nominals[i].field_hi);
        free(nominals[i].field_has_range);
        free(nominals[i].field_inline);
    }
    nominal_count = 0;

    // Cleared, and the ordering is the reason it is safe to clear. The profile
    // is loaded *into* the nominals table, so it can only be loaded after
    // aifDeclare has repopulated that table -- which is in the second pass,
    // after this reset. Keeping the old value across the reset would leave a
    // manifest claiming `workload:NAME` if the second pass's load then failed.
    g_profile_source = -1;
    g_profile_runs = 0;
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

    for (int i = 0; i < AIF_NODE_BUCKETS; i++) {
        NodeCall* n = call_buckets[i];
        while (n) {
            NodeCall* next = n->next;
            free(n);
            n = next;
        }
        call_buckets[i] = NULL;
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
    bits_free(&query_scratch);
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
