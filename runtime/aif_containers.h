// AIF containers -- the growable bitset, the int vector, and the allocation
// helpers both they and the engine are built on.
//
// **Why this is its own file.** `aif_support.c` says at its top that what it
// holds is "the container layer" and the engine above it. This is that layer,
// and it was the half with the widest reach: `xmalloc` was referenced across
// 6,865 lines of the file it lived in and `bits_test` across 5,766, while
// nothing here knows what a site, a tier or a constraint is.
//
// The layer was *not* contiguous in that file -- the fact encodings sat between
// the allocation helpers and the bitsets -- which is worth knowing before
// splitting anything else out of it: the sections interleave, so a line range is
// not a boundary.
//
// These are no longer `static`, because they are now called from another
// translation unit, which is the condition C_CODE_STYLE.md states for dropping
// it. They stay internal to the AIF pair: nothing else includes this.
//
// SOUNDNESS NOTE, inherited from the engine. Every bitset operation here only
// ever *sets* bits (INFERENCE.md M2). `bits_clear` empties a set its caller owns
// outright; nothing here lowers a fact iteration has already established, which
// is what keeps the solver's fixed point monotone and safe to abandon.
#ifndef PRISMIO_AIF_CONTAINERS_H
#define PRISMIO_AIF_CONTAINERS_H

#include <stddef.h>

// Allocation. Each of these aborts rather than returning NULL: the engine has no
// partial answer to give, and a wrong tier is worse than no binary at all.
void  aif_oom(const char* what);
void* xmalloc(size_t n, const char* what);
void* xcalloc(size_t n, size_t sz, const char* what);
void* xrealloc(void* p, size_t n, const char* what);

typedef unsigned long long Word;
#define WORD_BITS 64

typedef struct {
    Word* w;
    int nwords;
} Bits;

void bits_ensure(Bits* b, int bit, const char* what);

// Inline, because the engine tests bits inside loops nested over functions and
// sites, and a call into another translation unit is one the optimiser can
// neither hoist the word load out of nor fold into its caller's loop.
static inline int bits_test(const Bits* b, int bit) {
    int wi = bit / WORD_BITS;
    if (bit < 0 || wi >= b->nwords) return 0;
    return (int)((b->w[wi] >> (bit % WORD_BITS)) & 1u);
}

// Answers whether the bit was *newly* set, which is how a solver round detects
// that it changed something and another round is needed.
int  bits_set(Bits* b, int bit, const char* what);
void bits_clear(Bits* b);
int  bits_is_empty(const Bits* b);
int  bits_or(Bits* dst, const Bits* src, const char* what);
int  bits_count_at_least_two(const Bits* b);
void bits_free(Bits* b);

typedef struct {
    int* v;
    int len, cap;
} IntVec;

void vec_push(IntVec* iv, int x, const char* what);

// Count trailing zeros of a nonzero word -- the index of its lowest set bit,
// which is how every set enumeration here walks a bitset. Inline and on the
// builtin, because the closure walks call it once per set bit, and out of line
// it had become the top entry in a profile of the compiler compiling itself.
static inline int ctz64(Word x) {
#if defined(__GNUC__) || defined(__clang__)
    return __builtin_ctzll(x);
#else
    int n = 0;
    if (!(x & 0xFFFFFFFFull)) { x >>= 32; n += 32; }
    if (!(x & 0xFFFFull))     { x >>= 16; n += 16; }
    if (!(x & 0xFFull))       { x >>= 8;  n += 8;  }
    if (!(x & 0xFull))        { x >>= 4;  n += 4;  }
    if (!(x & 0x3ull))        { x >>= 2;  n += 2;  }
    if (!(x & 0x1ull))        { n += 1; }
    return n;
#endif
}

void bits_to_vec(const Bits* b, IntVec* out);

#endif
