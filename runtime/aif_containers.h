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
int  bits_test(const Bits* b, int bit);
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
int  ctz64(Word x);
void bits_to_vec(const Bits* b, IntVec* out);

#endif
