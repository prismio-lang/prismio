// AIF containers. See aif_containers.h for what this layer is and why it is
// separate from the engine built on it.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "aif_containers.h"

void aif_oom(const char* what) {
    fprintf(stderr, "internal error: out of memory growing %s\n", what);
    fflush(stderr);
    exit(1);
}

void* xmalloc(size_t n, const char* what) {
    void* p = malloc(n);
    if (!p) aif_oom(what);
    return p;
}

void* xcalloc(size_t n, size_t sz, const char* what) {
    void* p = calloc(n ? n : 1, sz);
    if (!p) aif_oom(what);
    return p;
}

void* xrealloc(void* p, size_t n, const char* what) {
    void* q = realloc(p, n);
    if (!q) aif_oom(what);
    return q;
}

// Growable bitsets
// Both halves of the solver state are sets of small integers: a points-to node
// holds a set of sites, and a site holds the set of nodes referencing it.
// Bitsets make union and subset one word-loop each, which keeps the round cost
// proportional to the graph rather than to the constraint list.



void bits_ensure(Bits* b, int bit, const char* what) {
    int need = bit / WORD_BITS + 1;
    if (need <= b->nwords) return;
    int grow = b->nwords ? b->nwords * 2 : 8;
    if (grow < need) grow = need;
    b->w = (Word*)xrealloc(b->w, (size_t)grow * sizeof(Word), what);
    memset(b->w + b->nwords, 0, (size_t)(grow - b->nwords) * sizeof(Word));
    b->nwords = grow;
}

int bits_test(const Bits* b, int bit) {
    int wi = bit / WORD_BITS;
    if (bit < 0 || wi >= b->nwords) return 0;
    return (int)((b->w[wi] >> (bit % WORD_BITS)) & 1u);
}

// Returns 1 only when the bit was absent. The solver's `changed` flag is the
// disjunction of every such return, so an update that adds nothing must report
// nothing -- otherwise the loop never terminates.
int bits_set(Bits* b, int bit, const char* what) {
    bits_ensure(b, bit, what);
    int wi = bit / WORD_BITS;
    Word m = (Word)1 << (bit % WORD_BITS);
    if (b->w[wi] & m) return 0;
    b->w[wi] |= m;
    return 1;
}

void bits_clear(Bits* b) {
    if (b->nwords) memset(b->w, 0, (size_t)b->nwords * sizeof(Word));
}

int bits_is_empty(const Bits* b) {
    for (int i = 0; i < b->nwords; i++) {
        if (b->w[i]) return 0;
    }
    return 1;
}

// dst |= src, reporting whether dst grew.
int bits_or(Bits* dst, const Bits* src, const char* what) {
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

int bits_count_at_least_two(const Bits* b) {
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

void bits_free(Bits* b) {
    free(b->w);
    b->w = NULL;
    b->nwords = 0;
}

// Int vectors
// Set membership is a bitset, but the solver's rules need to *enumerate* a set,
// sometimes two of them nested. Materialising a bitset into a plain int array
// keeps that a pair of ordinary loops. The buffers are reused across rounds,
// so this allocates a handful of times for the whole run.


void vec_push(IntVec* iv, int x, const char* what) {
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
int ctz64(Word x) {
    int n = 0;
    if (!(x & 0xFFFFFFFFull)) { x >>= 32; n += 32; }
    if (!(x & 0xFFFFull))     { x >>= 16; n += 16; }
    if (!(x & 0xFFull))       { x >>= 8;  n += 8;  }
    if (!(x & 0xFull))        { x >>= 4;  n += 4;  }
    if (!(x & 0x3ull))        { x >>= 2;  n += 2;  }
    if (!(x & 0x1ull))        { n += 1; }
    return n;
}

void bits_to_vec(const Bits* b, IntVec* out) {
    out->len = 0;
    for (int wi = 0; wi < b->nwords; wi++) {
        for (Word x = b->w[wi]; x; x &= x - 1) {
            vec_push(out, wi * WORD_BITS + ctz64(x), "AIF bit enumeration");
        }
    }
}
