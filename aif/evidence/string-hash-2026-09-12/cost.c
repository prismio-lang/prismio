// Raw cost per key, arms rotated inside one process so drift cannot bias one of
// them. The minimum of every sample an arm gets.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

static long long now_ns(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC_RAW, &t);
    return (long long)t.tv_sec * 1000000000LL + t.tv_nsec;
}

#define K1 0xBF58476D1CE4E5B9ULL
#define K2 0xD6E8FEB86659FD93ULL
#define SEED 0x9E3779B97F4A7C15ULL

static int str_hash_current(const char *s, int length) {
    if (!s || length < 0) length = 0;
    const unsigned char *p = (const unsigned char *)s;
    uint64_t h = SEED ^ (uint64_t)(uint32_t)length;
    int i = 0;
    for (; i + 8 <= length; i += 8) {
        uint64_t w; memcpy(&w, p + i, 8);
        h = (h ^ w) * K1;
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
        h = (h ^ w) * K1;
    }
    h ^= h >> 32; h *= K2; h ^= h >> 32;
    return (int)(h & 0x7FFFFFFF);
}

static inline int mix_d(uint64_t lo, uint64_t hi) {
    uint64_t h = (lo ^ K1) * K1 + (hi ^ K2) * K2;
    h ^= h >> 32; h *= K2; h ^= h >> 32;
    return (int)(h & 0x7FFFFFFF);
}
static inline int mix_e(uint64_t lo, uint64_t hi) {
    uint64_t h = ((SEED ^ lo) ^ (hi * K1)) * K1;
    h ^= h >> 32; h *= K2; h ^= h >> 32;
    return (int)(h & 0x7FFFFFFF);
}
static inline int mix_h(uint64_t lo, uint64_t hi) {
    unsigned __int128 p = (unsigned __int128)(lo ^ K1) * (uint64_t)(hi ^ K2);
    uint64_t h = (uint64_t)p ^ (uint64_t)(p >> 64) ^ (lo >> 32) ^ (hi >> 32) ^ hi;
    return (int)(h & 0x7FFFFFFF);
}
static inline int mix_i(uint64_t lo, uint64_t hi) {
    unsigned __int128 p = (unsigned __int128)(lo ^ K1) * (uint64_t)(hi ^ K2);
    uint64_t h = (uint64_t)p ^ (uint64_t)(p >> 64) ^ (hi >> 32);
    return (int)(h & 0x7FFFFFFF);
}

enum { ARM_CURRENT, ARM_D, ARM_E, ARM_H, ARM_I, ARMS };
static const char *arm_name[ARMS] = {"current (str_hash)", "D two-mul",
                                     "E one-round", "H mum+folds", "I mum+b8"};

static volatile int sink;
static int bench_next_random(int seed) { return (seed * 25173 + 13849) % 65521; }

typedef struct { char text[16]; int len; uint64_t lo, hi; } Key;

static void words_of(Key *k) {
    unsigned char buf[12] = {0};
    memcpy(buf, k->text, (size_t)k->len);
    uint64_t a; uint32_t b;
    memcpy(&a, buf, 8); memcpy(&b, buf + 8, 4);
    k->lo = a;
    k->hi = ((uint64_t)b << 32) | (uint32_t)k->len;
}

static double run_arm(int arm, const Key *keys, int n) {
    long long t0 = now_ns();
    int acc = 0;
    switch (arm) {
        case ARM_CURRENT:
            for (int i = 0; i < n; ++i) acc += str_hash_current(keys[i].text, keys[i].len);
            break;
        case ARM_D: for (int i = 0; i < n; ++i) acc += mix_d(keys[i].lo, keys[i].hi); break;
        case ARM_E: for (int i = 0; i < n; ++i) acc += mix_e(keys[i].lo, keys[i].hi); break;
        case ARM_H: for (int i = 0; i < n; ++i) acc += mix_h(keys[i].lo, keys[i].hi); break;
        default:    for (int i = 0; i < n; ++i) acc += mix_i(keys[i].lo, keys[i].hi); break;
    }
    long long t1 = now_ns();
    sink = acc;
    return (double)(t1 - t0) / (double)n;
}

static void measure(const char *label, Key *keys, int n) {
    double best[ARMS];
    for (int a = 0; a < ARMS; ++a) best[a] = 1e30;
    for (int round = 0; round < 25; ++round)
        for (int a = 0; a < ARMS; ++a) {
            double per = run_arm(a, keys, n);
            if (per < best[a]) best[a] = per;
        }
    printf("%s, %d keys, ns per key (min of 25)\n", label, n);
    for (int a = 0; a < ARMS; ++a)
        printf("  %-20s %6.3f   %.3fx\n", arm_name[a], best[a], best[a] / best[ARM_CURRENT]);
    printf("\n");
}

int main(void) {
    const char *vocabulary[10] = {"the", "quick", "brown", "fox", "jumps",
                                  "over", "lazy", "dog", "while", "naps"};
    int reps = 200000;
    Key *words = malloc((size_t)reps * sizeof(Key));
    for (int i = 0; i < reps; ++i) {
        const char *w = vocabulary[i % 10];
        words[i].len = (int)strlen(w);
        memcpy(words[i].text, w, (size_t)words[i].len + 1);
        words_of(&words[i]);
    }

    int n = 80000;
    Key *ss = malloc((size_t)n * sizeof(Key));
    int seed = 7;
    for (int i = 0; i < n; ++i) {
        seed = bench_next_random(seed);
        ss[i].len = snprintf(ss[i].text, sizeof ss[i].text, "key%d-%d", seed % 65521, i % 977);
        if (ss[i].len > 12) ss[i].len = 12;
        words_of(&ss[i]);
    }

    measure("3-5 byte words", words, reps);
    measure("5-12 byte sort_strings keys", ss, n);
    return 0;
}
