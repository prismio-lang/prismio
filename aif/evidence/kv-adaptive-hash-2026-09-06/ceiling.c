// Ceiling study for key_value_update: the same workload under four table
// designs, all in C, all doing TWO lookups per update exactly as the Prismio,
// C++ and Rust arms do.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

#define N (20000 * 4)
#define ROUNDS 20
#define MOD 1000000007

static long long now_ns(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC_RAW, &t);
    return (long long)t.tv_sec * 1000000000LL + t.tv_nsec;
}

// std/key.psm's keyMixInt: MurmurHash3 32-bit finalizer, masked to 31 bits.
static inline int mix(int value) {
    uint32_t h = (uint32_t)value;
    h ^= h >> 16; h *= 2246822507u;
    h ^= h >> 13; h *= 3266489909u;
    h ^= h >> 16;
    return (int)(h & 2147483647u);
}

// ---------------------------------------------------------------- design 1
// std/map.psm exactly: index table of entry indices, dense keys/values in
// insertion order, triangular probing, grow above 1/2 load.
typedef struct { int *slots, *keys, *values; int mask, len, cap; } IndexMap;

static void im_init(IndexMap *m) {
    m->mask = 7; m->len = 0; m->cap = 8;
    m->slots = malloc(8 * sizeof(int));
    for (int i = 0; i < 8; i++) m->slots[i] = -1;
    m->keys = malloc(8 * sizeof(int));
    m->values = malloc(8 * sizeof(int));
}
static int im_probe(IndexMap *m, int key, int find_slot) {
    int at = mix(key) & m->mask, step = 1;
    for (;;) {
        int entry = m->slots[at];
        if (entry < 0) return find_slot ? -at - 2 : -1;
        if (m->keys[entry] == key) return entry;
        at = (at + step) & m->mask; step++;
    }
}
static void im_rehash(IndexMap *m) {
    int old = m->mask + 1, capacity = old * 2;
    m->slots = realloc(m->slots, (size_t)capacity * sizeof(int));
    for (int i = 0; i < capacity; i++) m->slots[i] = -1;
    m->mask = capacity - 1;
    for (int e = 0; e < m->len; e++) {
        int at = mix(m->keys[e]) & m->mask, step = 1;
        while (m->slots[at] >= 0) { at = (at + step) & m->mask; step++; }
        m->slots[at] = e;
    }
}
static int im_set(IndexMap *m, int key, int value) {
    int found = im_probe(m, key, 1);
    if (found >= 0) { m->values[found] = value; return 1; }
    int at = -found - 2;
    if (m->len == m->cap) {
        m->cap *= 2;
        m->keys = realloc(m->keys, (size_t)m->cap * sizeof(int));
        m->values = realloc(m->values, (size_t)m->cap * sizeof(int));
    }
    int index = m->len++;
    m->keys[index] = key; m->values[index] = value;
    m->slots[at] = index;
    if (m->len > (m->mask + 1) / 2) im_rehash(m);
    return 0;
}
static int im_get_or(IndexMap *m, int key, int fallback) {
    int at = im_probe(m, key, 0);
    return at < 0 ? fallback : m->values[at];
}

// ---------------------------------------------------------------- design 2
// The key moves into the slot table: one load answers both "is this it?" and
// "where is the entry?". Dense arrays stay, so insertion order survives.
typedef struct { int key, entry; } Slot;
typedef struct { Slot *slots; int *keys, *values; int mask, len, cap; } KeyedMap;

static void km_init(KeyedMap *m) {
    m->mask = 7; m->len = 0; m->cap = 8;
    m->slots = malloc(8 * sizeof(Slot));
    for (int i = 0; i < 8; i++) m->slots[i].entry = -1;
    m->keys = malloc(8 * sizeof(int));
    m->values = malloc(8 * sizeof(int));
}
static int km_probe(KeyedMap *m, int key, int find_slot) {
    int at = mix(key) & m->mask, step = 1;
    for (;;) {
        Slot s = m->slots[at];
        if (s.entry < 0) return find_slot ? -at - 2 : -1;
        if (s.key == key) return s.entry;
        at = (at + step) & m->mask; step++;
    }
}
static void km_rehash(KeyedMap *m) {
    int old = m->mask + 1, capacity = old * 2;
    m->slots = realloc(m->slots, (size_t)capacity * sizeof(Slot));
    for (int i = 0; i < capacity; i++) m->slots[i].entry = -1;
    m->mask = capacity - 1;
    for (int e = 0; e < m->len; e++) {
        int k = m->keys[e], at = mix(k) & m->mask, step = 1;
        while (m->slots[at].entry >= 0) { at = (at + step) & m->mask; step++; }
        m->slots[at].key = k; m->slots[at].entry = e;
    }
}
static int km_set(KeyedMap *m, int key, int value) {
    int found = km_probe(m, key, 1);
    if (found >= 0) { m->values[found] = value; return 1; }
    int at = -found - 2;
    if (m->len == m->cap) {
        m->cap *= 2;
        m->keys = realloc(m->keys, (size_t)m->cap * sizeof(int));
        m->values = realloc(m->values, (size_t)m->cap * sizeof(int));
    }
    int index = m->len++;
    m->keys[index] = key; m->values[index] = value;
    m->slots[at].key = key; m->slots[at].entry = index;
    if (m->len > (m->mask + 1) / 2) km_rehash(m);
    return 0;
}
static void km78_init(KeyedMap *m) { km_init(m); }
static int km78_set(KeyedMap *m, int key, int value) {
    int found = km_probe(m, key, 1);
    if (found >= 0) { m->values[found] = value; return 1; }
    int at = -found - 2;
    if (m->len == m->cap) {
        m->cap *= 2;
        m->keys = realloc(m->keys, (size_t)m->cap * sizeof(int));
        m->values = realloc(m->values, (size_t)m->cap * sizeof(int));
    }
    int index = m->len++;
    m->keys[index] = key; m->values[index] = value;
    m->slots[at].key = key; m->slots[at].entry = index;
    // 7/8 rather than 1/2: an 8-byte slot is twice the index table's bucket, so
    // the space the lower load factor buys costs twice as much cache.
    if (m->len * 8 > (m->mask + 1) * 7) km_rehash(m);
    return 0;
}

static int km_get_or(KeyedMap *m, int key, int fallback) {
    int at = km_probe(m, key, 0);
    return at < 0 ? fallback : m->values[at];
}

// ---------------------------------------------------------------- design 3
// Key and value both inline in the table, plus a separate insertion-order list
// of bucket positions so mapKeyAt/mapValueAt still work. One load per probe
// answers everything; no dense-array indirection at all on lookup.
typedef struct { int key, value; } Pair;
typedef struct { Pair *slots; unsigned char *live; int *order; int mask, len, cap; } FlatMap;

static void fm_init(FlatMap *m) {
    m->mask = 7; m->len = 0; m->cap = 8;
    m->slots = malloc(8 * sizeof(Pair));
    m->live = calloc(8, 1);
    m->order = malloc(8 * sizeof(int));
}
static int fm_probe(FlatMap *m, int key) {   // bucket, live or free
    int at = mix(key) & m->mask, step = 1;
    for (;;) {
        if (!m->live[at]) return at;
        if (m->slots[at].key == key) return at;
        at = (at + step) & m->mask; step++;
    }
}
static void fm_rehash(FlatMap *m) {
    int old = m->mask + 1, capacity = old * 2;
    Pair *ns = malloc((size_t)capacity * sizeof(Pair));
    unsigned char *nl = calloc((size_t)capacity, 1);
    int nmask = capacity - 1;
    for (int i = 0; i < m->len; i++) {
        Pair p = m->slots[m->order[i]];
        int at = mix(p.key) & nmask, step = 1;
        while (nl[at]) { at = (at + step) & nmask; step++; }
        ns[at] = p; nl[at] = 1; m->order[i] = at;
    }
    free(m->slots); free(m->live);
    m->slots = ns; m->live = nl; m->mask = nmask;
}
static int fm_set(FlatMap *m, int key, int value) {
    int at = fm_probe(m, key);
    if (m->live[at]) { m->slots[at].value = value; return 1; }
    if (m->len == m->cap) { m->cap *= 2; m->order = realloc(m->order, (size_t)m->cap * sizeof(int)); }
    m->slots[at].key = key; m->slots[at].value = value; m->live[at] = 1;
    m->order[m->len++] = at;
    if (m->len > (m->mask + 1) / 2) fm_rehash(m);
    return 0;
}
static int fm_get_or(FlatMap *m, int key, int fallback) {
    int at = fm_probe(m, key);
    return m->live[at] ? m->slots[at].value : fallback;
}

// ---------------------------------------------------------------- design 4
// Swiss table, absl::flat_hash_map's layout: a byte of control metadata per
// slot (0x80 empty, else the top 7 bits of the hash), scanned 16 at a time with
// NEON, and (key, value) inline in the slot array. Insertion order is kept in a
// separate `order` list of bucket positions, which is what Prismio's
// mapKeyAt/mapValueAt contract needs and a plain Swiss table does not have.
#include <arm_neon.h>
#define CTRL_EMPTY 0x80

typedef struct { Pair *slots; unsigned char *ctrl; int *order; int mask, len, cap; } SwissMap;

static void sw_reset(SwissMap *m, int capacity) {
    m->slots = malloc((size_t)capacity * sizeof(Pair));
    m->ctrl = malloc((size_t)capacity + 16);
    memset(m->ctrl, CTRL_EMPTY, (size_t)capacity + 16);
    m->mask = capacity - 1;
}
static void sw_init(SwissMap *m) {
    m->len = 0; m->cap = 16;
    sw_reset(m, 16);
    m->order = malloc(16 * sizeof(int));
}
// The bucket holding `key`, or the first free bucket on its probe sequence.
// `*found` says which.
static int sw_probe(SwissMap *m, int key, int *found) {
    int h = mix(key);
    unsigned char h2 = (unsigned char)(h >> 24) & 0x7f;
    int at = h & m->mask, step = 0;
    uint8x16_t want = vdupq_n_u8(h2);
    uint8x16_t empty = vdupq_n_u8(CTRL_EMPTY);
    for (;;) {
        uint8x16_t g = vld1q_u8(m->ctrl + at);
        uint64_t hit = vget_lane_u64(vreinterpret_u64_u8(
            vshrn_n_u16(vreinterpretq_u16_u8(vceqq_u8(g, want)), 4)), 0);
        while (hit) {
            int lane = __builtin_ctzll(hit) >> 2;
            int slot = (at + lane) & m->mask;
            if (m->slots[slot].key == key) { *found = 1; return slot; }
            hit &= hit - 1;
            hit &= ~(0xfULL << (lane * 4));
        }
        uint64_t free_lanes = vget_lane_u64(vreinterpret_u64_u8(
            vshrn_n_u16(vreinterpretq_u16_u8(vceqq_u8(g, empty)), 4)), 0);
        if (free_lanes) {
            int lane = __builtin_ctzll(free_lanes) >> 2;
            *found = 0;
            return (at + lane) & m->mask;
        }
        step += 16;
        at = (at + step) & m->mask;
    }
}
static void sw_rehash(SwissMap *m) {
    Pair *olds = m->slots; unsigned char *oldc = m->ctrl;
    int *order = m->order, len = m->len;
    sw_reset(m, (m->mask + 1) * 2);
    for (int i = 0; i < len; i++) {
        Pair p = olds[order[i]];
        int found; int at = sw_probe(m, p.key, &found);
        m->slots[at] = p;
        m->ctrl[at] = (unsigned char)((mix(p.key) >> 24) & 0x7f);
        if (at < 16) m->ctrl[at + m->mask + 1] = m->ctrl[at];
        order[i] = at;
    }
    free(olds); free(oldc);
}
static int sw_set(SwissMap *m, int key, int value) {
    int found; int at = sw_probe(m, key, &found);
    if (found) { m->slots[at].value = value; return 1; }
    if (m->len == m->cap) { m->cap *= 2; m->order = realloc(m->order, (size_t)m->cap * sizeof(int)); }
    m->slots[at].key = key; m->slots[at].value = value;
    m->ctrl[at] = (unsigned char)((mix(key) >> 24) & 0x7f);
    // The 16 bytes past the end mirror the first 16, so a group load near the
    // wrap reads the same bytes the masked index would.
    if (at < 16) m->ctrl[at + m->mask + 1] = m->ctrl[at];
    m->order[m->len++] = at;
    if (m->len * 8 > (m->mask + 1) * 7) sw_rehash(m);
    return 0;
}
static int sw_get_or(SwissMap *m, int key, int fallback) {
    int found; int at = sw_probe(m, key, &found);
    return found ? m->slots[at].value : fallback;
}

// ---------------------------------------------------------------- driver
#define RUN(label, TYPE, INIT, SET, GETOR)                                     \
    do {                                                                       \
        TYPE m; INIT(&m);                                                      \
        long long t0 = now_ns();                                               \
        for (int i = 0; i < N; i++) SET(&m, i, i % 101);                        \
        long long t1 = now_ns();                                               \
        for (int r = 0; r < ROUNDS; r++)                                       \
            for (int k = 0; k < N; k++) SET(&m, k, GETOR(&m, k, 0) + 1);        \
        long long t2 = now_ns();                                               \
        int checksum = 0;                                                      \
        for (int q = 0; q < N; q++) checksum = (checksum + GETOR(&m, q, 0)) % MOD; \
        long long t3 = now_ns();                                               \
        printf("%-10s insert %7.3f  update %8.3f  sum %6.3f  total %8.3f  result %d\n", \
               label, (t1-t0)/1e6, (t2-t1)/1e6, (t3-t2)/1e6, (t3-t0)/1e6, checksum); \
    } while (0)

int main(int argc, char **argv) {
    const char *only = argc > 1 ? argv[1] : "index";
    if (!strcmp(only, "index")) RUN("index", IndexMap, im_init, im_set, im_get_or);
    else if (!strcmp(only, "keyed")) RUN("keyed", KeyedMap, km_init, km_set, km_get_or);
    else if (!strcmp(only, "keyed78")) RUN("keyed78", KeyedMap, km78_init, km78_set, km_get_or);
    else if (!strcmp(only, "flat")) RUN("flat", FlatMap, fm_init, fm_set, fm_get_or);
    else if (!strcmp(only, "swiss")) RUN("swiss", SwissMap, sw_init, sw_set, sw_get_or);
    else { fprintf(stderr, "unknown design %s\n", only); return 2; }
    return 0;
}
