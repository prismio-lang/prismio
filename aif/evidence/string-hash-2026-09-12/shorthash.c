// What a short String key costs to hash, and what the answer buys on std.map's
// table. Candidates for `__builtin_string_hash`'s inline path: the mix must be a
// function of the inline pair's two words alone, so the C side can reproduce it
// for a view or a short heap string.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

static long long now_ns(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC_RAW, &t);
    return (long long)t.tv_sec * 1000000000LL + t.tv_nsec;
}

// ---------------------------------------------------------------- the baseline

// runtime/lang_runtime.c as committed.
static int str_hash_current(const char *s, int length) {
    if (!s || length < 0) length = 0;
    const unsigned char *p = (const unsigned char *)s;
    uint64_t h = 0x9E3779B97F4A7C15ULL ^ (uint64_t)(uint32_t)length;
    int i = 0;
    for (; i + 8 <= length; i += 8) {
        uint64_t w; memcpy(&w, p + i, 8);
        h = (h ^ w) * 0xBF58476D1CE4E5B9ULL;
    }
    int rest = length - i;
    if (rest > 0) {
        uint64_t w;
        if (rest >= 4) {
            uint32_t head, tail;
            memcpy(&head, p + i, 4);
            memcpy(&tail, p + length - 4, 4);
            w = (uint64_t)head | ((uint64_t)tail << 32);
        } else {
            w = (uint64_t)p[i] | ((uint64_t)p[i + rest / 2] << 8)
                | ((uint64_t)p[length - 1] << 16);
        }
        h = (h ^ w) * 0xBF58476D1CE4E5B9ULL;
    }
    h ^= h >> 32;
    h *= 0xD6E8FEB86659FD93ULL;
    h ^= h >> 32;
    return (int)(h & 0x7FFFFFFF);
}

// ------------------------------------------------------------- the candidates
//
// Each takes the inline pair as the backend has it: `lo` is field 0 (bytes 0..7,
// zero past the length), `hi` is field 1 with the INLINE tag cleared -- bytes
// 8..11 in the top half and the length in the bottom.

#define K1 0xBF58476D1CE4E5B9ULL
#define K2 0xD6E8FEB86659FD93ULL
#define SEED 0x9E3779B97F4A7C15ULL

// A: the committed shape, two rounds and the same finalizer.
static inline int mix_a(uint64_t lo, uint64_t hi) {
    uint64_t h = SEED ^ (uint32_t)hi;      // the length, as str_hash folds it
    h = (h ^ lo) * K1;
    h = (h ^ (hi >> 32)) * K1;
    h ^= h >> 32; h *= K2; h ^= h >> 32;
    return (int)(h & 0x7FFFFFFF);
}

// B: wyhash's `mum` -- one 64x64->128 multiply, the halves folded together.
static inline int mix_b(uint64_t lo, uint64_t hi) {
    unsigned __int128 p = (unsigned __int128)(lo ^ K1) * (uint64_t)(hi ^ K2);
    uint64_t h = (uint64_t)p ^ (uint64_t)(p >> 64);
    return (int)(h & 0x7FFFFFFF);
}

// C: mum, then one fold of the high half down -- the low bits are what a bucket
// mask reads, and a multiply mixes only upward.
static inline int mix_c(uint64_t lo, uint64_t hi) {
    unsigned __int128 p = (unsigned __int128)(lo ^ K1) * (uint64_t)(hi ^ K2);
    uint64_t h = (uint64_t)p ^ (uint64_t)(p >> 64);
    h ^= h >> 32;
    return (int)(h & 0x7FFFFFFF);
}

// D: two independent multiplies, added, then folded. No 128-bit product.
static inline int mix_d(uint64_t lo, uint64_t hi) {
    uint64_t h = (lo ^ K1) * K1 + (hi ^ K2) * K2;
    h ^= h >> 32; h *= K2; h ^= h >> 32;
    return (int)(h & 0x7FFFFFFF);
}

// E: one round over the xor of the two words, the committed finalizer.
static inline int mix_e(uint64_t lo, uint64_t hi) {
    uint64_t h = ((SEED ^ lo) ^ (hi * K1)) * K1;
    h ^= h >> 32; h *= K2; h ^= h >> 32;
    return (int)(h & 0x7FFFFFFF);
}

// F: mum, with both operands folded back in. `lo ^ K1 == 0` makes B's product
// zero for every key sharing those eight bytes, whatever the rest holds; one
// add and one xor make the answer depend on the operands directly.
static inline int mix_f(uint64_t lo, uint64_t hi) {
    unsigned __int128 p = (unsigned __int128)(lo ^ K1) * (uint64_t)(hi ^ K2);
    uint64_t h = (uint64_t)p ^ (uint64_t)(p >> 64) ^ (lo + hi);
    return (int)(h & 0x7FFFFFFF);
}

// G: the same, one xor rather than an add and an xor.
static inline int mix_g(uint64_t lo, uint64_t hi) {
    unsigned __int128 p = (unsigned __int128)(lo ^ K1) * (uint64_t)(hi ^ K2);
    uint64_t h = (uint64_t)p ^ (uint64_t)(p >> 64) ^ hi;
    return (int)(h & 0x7FFFFFFF);
}

// H: mum with both high halves folded down. `& 0x7FFFFFFF` reads the low 31
// bits, so a fold-back that leaves bytes 8..11 above bit 32 does not rescue the
// degenerate case it was added for.
static inline int mix_h(uint64_t lo, uint64_t hi) {
    unsigned __int128 p = (unsigned __int128)(lo ^ K1) * (uint64_t)(hi ^ K2);
    uint64_t h = (uint64_t)p ^ (uint64_t)(p >> 64) ^ (lo >> 32) ^ (hi >> 32) ^ hi;
    return (int)(h & 0x7FFFFFFF);
}

// I: mum with bytes 8..11 folded down, and nothing else. The second operand can
// never be zero -- `hi`'s low half is the length, at most 12, and K2's is
// 0x6659FD93 -- so the one degenerate case is `lo == K1`, and the fold answers
// exactly it: the bytes that distinguish those keys live above bit 32, which
// `& 0x7FFFFFFF` would otherwise discard.
static inline int mix_i(uint64_t lo, uint64_t hi) {
    unsigned __int128 p = (unsigned __int128)(lo ^ K1) * (uint64_t)(hi ^ K2);
    uint64_t h = (uint64_t)p ^ (uint64_t)(p >> 64) ^ (hi >> 32);
    return (int)(h & 0x7FFFFFFF);
}

enum { MIX_A, MIX_B, MIX_C, MIX_D, MIX_E, MIX_F, MIX_G, MIX_H, MIX_I, MIX_COUNT };
static const char *mix_name[MIX_COUNT] = {"A two-round", "B mum", "C mum+fold",
                                          "D two-mul", "E one-round",
                                          "F mum+both", "G mum+hi", "H mum+folds",
                                          "I mum+b8"};

static inline int mix_by(int which, uint64_t lo, uint64_t hi) {
    switch (which) {
        case MIX_A: return mix_a(lo, hi);
        case MIX_B: return mix_b(lo, hi);
        case MIX_C: return mix_c(lo, hi);
        case MIX_D: return mix_d(lo, hi);
        case MIX_E: return mix_e(lo, hi);
        case MIX_F: return mix_f(lo, hi);
        case MIX_G: return mix_g(lo, hi);
        case MIX_H: return mix_h(lo, hi);
        default:    return mix_i(lo, hi);
    }
}

// The two words a short string's bytes make, whether or not it is inline. This
// is what runtime/lang_runtime.c has to do for a view or a short heap string;
// for an inline pair the backend already holds both in registers.
static void short_words(const char *s, int length, uint64_t *lo, uint64_t *hi) {
    unsigned char buf[12] = {0};
    memcpy(buf, s, (size_t)length);
    uint64_t a; uint32_t b;
    memcpy(&a, buf, 8);
    memcpy(&b, buf + 8, 4);
    *lo = a;
    *hi = ((uint64_t)b << 32) | (uint32_t)length;
}

static int short_hash(int which, const char *s, int length) {
    uint64_t lo, hi; short_words(s, length, &lo, &hi);
    return mix_by(which, lo, hi);
}

// ------------------------------------------------------------------- the keys

static int bench_next_random(int seed) { return (seed * 25173 + 13849) % 65521; }

typedef struct { char text[16]; int len; } Key;

// `sort_strings`' keys, which is also what the map benchmark inserts: 5 to 12
// bytes.
static int keys_sort_strings(Key *out, int n) {
    int seed = 7;
    for (int i = 0; i < n; ++i) {
        seed = bench_next_random(seed);
        out[i].len = snprintf(out[i].text, sizeof out[i].text, "key%d-%d",
                              seed % 65521, i % 977);
        if (out[i].len > 12) out[i].len = 12;
    }
    return n;
}

static int keys_ids(Key *out, int n) {
    for (int i = 0; i < n; ++i)
        out[i].len = snprintf(out[i].text, sizeof out[i].text, "id%d", i);
    return n;
}

static const char *vocabulary[10] = {"the", "quick", "brown", "fox", "jumps",
                                     "over", "lazy", "dog", "while", "naps"};

// --------------------------------------------------------------- displacement
//
// std.map's table: a power of two, at most half full, triangular probing.

static double displacement(int which, int use_current, const Key *keys, int n) {
    int capacity = 16;
    while (n > capacity / 2) capacity *= 2;
    int mask = capacity - 1;
    int *slots = malloc((size_t)capacity * sizeof(int));
    for (int i = 0; i < capacity; ++i) slots[i] = -1;
    long long probes = 0;
    int placed = 0;
    for (int i = 0; i < n; ++i) {
        int h = use_current ? str_hash_current(keys[i].text, keys[i].len)
                            : short_hash(which, keys[i].text, keys[i].len);
        int at = h & mask, step = 1;
        while (slots[at] >= 0) { at = (at + step) & mask; step++; probes++; }
        slots[at] = i;
        placed++;
    }
    free(slots);
    return (double)probes / (double)placed;
}

// ---------------------------------------------------------------------- timing

static volatile int sink;

static double cost_ns(int which, int use_current, const Key *keys, int n, int rounds) {
    // The register path: the two words already in hand, as the builtin has them.
    uint64_t *lo = malloc((size_t)n * 8), *hi = malloc((size_t)n * 8);
    for (int i = 0; i < n; ++i) short_words(keys[i].text, keys[i].len, &lo[i], &hi[i]);
    double best = 1e30;
    for (int r = 0; r < rounds; ++r) {
        long long t0 = now_ns();
        int acc = 0;
        if (use_current) {
            for (int i = 0; i < n; ++i) acc += str_hash_current(keys[i].text, keys[i].len);
        } else {
            for (int i = 0; i < n; ++i) acc += mix_by(which, lo[i], hi[i]);
        }
        long long t1 = now_ns();
        sink = acc;
        double per = (double)(t1 - t0) / (double)n;
        if (per < best) best = per;
    }
    free(lo); free(hi);
    return best;
}

int main(void) {
    // 1. The C path and the register path must agree, for every length a short
    //    string can have. This is the whole correctness requirement: a 5-byte
    //    view and a 5-byte inline string are equal keys.
    srand(12345);
    for (int which = 0; which < MIX_COUNT; ++which) {
        for (int len = 0; len <= 12; ++len) {
            for (int trial = 0; trial < 2000; ++trial) {
                char raw[13];
                for (int i = 0; i < len; ++i) raw[i] = (char)(1 + rand() % 255);
                uint64_t lo, hi; short_words(raw, len, &lo, &hi);
                if (mix_by(which, lo, hi) != short_hash(which, raw, len)) {
                    printf("MISMATCH %s len %d\n", mix_name[which], len);
                    return 1;
                }
            }
        }
    }
    printf("agree: the register path and the byte path answer alike, 0..12 bytes\n\n");

    const int N = 80000;
    Key *ss = malloc((size_t)N * sizeof(Key));
    Key *ids = malloc((size_t)N * sizeof(Key));
    keys_sort_strings(ss, N);
    keys_ids(ids, N);

    Key words[10];
    for (int i = 0; i < 10; ++i) {
        words[i].len = (int)strlen(vocabulary[i]);
        memcpy(words[i].text, vocabulary[i], (size_t)words[i].len + 1);
    }

    printf("%-12s %10s %10s %10s %10s %10s\n", "mix",
           "ns/key 3-5", "ns/key 5-12", "disp ss", "disp id", "disp vocab");

    for (int which = -1; which < MIX_COUNT; ++which) {
        int use_current = (which < 0);
        int w = use_current ? 0 : which;
        double c_short = cost_ns(w, use_current, words, 10, 0), c_long;
        // ten words is too few to time; replay them.
        {
            int reps = 200000;
            Key *many = malloc((size_t)reps * sizeof(Key));
            for (int i = 0; i < reps; ++i) many[i] = words[i % 10];
            c_short = cost_ns(w, use_current, many, reps, 9);
            free(many);
        }
        c_long = cost_ns(w, use_current, ss, N, 9);
        printf("%-12s %10.3f %10.3f %10.3f %10.3f %10.3f\n",
               use_current ? "current" : mix_name[w],
               c_short, c_long,
               displacement(w, use_current, ss, N),
               displacement(w, use_current, ids, N),
               displacement(w, use_current, words, 10));
    }

    // 1b. The degenerate family. A mum whose operand can be zeroed collapses
    //     every key sharing those eight bytes; count the distinct answers.
    printf("\ndistinct hashes over 4,096 keys whose first eight bytes are K1's\n");
    for (int which = -1; which < MIX_COUNT; ++which) {
        int use_current = (which < 0);
        int w = use_current ? 0 : which;
        int *seen = calloc(4096, sizeof(int));
        int distinct = 0;
        for (int i = 0; i < 4096; ++i) {
            char raw[13];
            uint64_t k1 = K1;
            memcpy(raw, &k1, 8);
            raw[8] = (char)(i & 0xFF); raw[9] = (char)((i >> 8) & 0xFF);
            raw[10] = 'x'; raw[11] = 'y';
            int h = use_current ? str_hash_current(raw, 12) : short_hash(w, raw, 12);
            int j = 0;
            for (; j < distinct; ++j) if (seen[j] == h) break;
            if (j == distinct) seen[distinct++] = h;
        }
        printf("  %-12s %d\n", use_current ? "current" : mix_name[w], distinct);
        free(seen);
    }

    // 2. Mean displacement over random ten-word vocabularies, the shape the
    //    committed evidence uses for the short-key case.
    printf("\nmean displacement, 20,000 random ten-word vocabularies\n");
    for (int which = -1; which < MIX_COUNT; ++which) {
        int use_current = (which < 0);
        int w = use_current ? 0 : which;
        srand(99);
        double total = 0;
        for (int v = 0; v < 20000; ++v) {
            Key vocab[10];
            for (int i = 0; i < 10; ++i) {
                vocab[i].len = 3 + rand() % 3;
                for (int b = 0; b < vocab[i].len; ++b)
                    vocab[i].text[b] = (char)('a' + rand() % 26);
                vocab[i].text[vocab[i].len] = 0;
            }
            total += displacement(w, use_current, vocab, 10);
        }
        printf("  %-12s %.4f\n", use_current ? "current" : mix_name[w], total / 20000.0);
    }
    return 0;
}
