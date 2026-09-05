// Models benchKnapsack's DP loop at five levels of the same design, on the real
// RtList layout, to price each candidate before building it in the compiler.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    void** data; int len; int cap; int elem_own;
    void (*elem_release)(void*);
    int arena; int elem_size;
} RtList;

static long long now_ns(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return (long long)t.tv_sec * 1000000000LL + t.tv_nsec;
}

// V0: what Prismio emitted BEFORE the flat-set change -- elem_size test per access.
__attribute__((noinline))
static int v0(RtList* l, int items, int capacity) {
    for (int i = 1; i <= items; i++) {
        int w = (i*37)%97+1, v = (i*53)%211+1;
        for (int at = capacity; at >= w; at--) {
            int a, b;
            { int idx = at-w;
              if ((unsigned)idx >= (unsigned)l->len) a = 0;
              else if (l->elem_size != 4) a = (int)(long long)(long)l->data[idx];
              else a = *(int*)((unsigned char*)l->data + (size_t)idx*4); }
            { if ((unsigned)at >= (unsigned)l->len) b = 0;
              else if (l->elem_size != 4) b = (int)(long long)(long)l->data[at];
              else b = *(int*)((unsigned char*)l->data + (size_t)at*4); }
            int cand = a + v;
            if (cand > b) {
                if (l->elem_size == 4 && at >= 0 && at < l->len)
                    *(int*)((unsigned char*)l->data + (size_t)at*4) = cand;
            }
        }
    }
    return *(int*)((unsigned char*)l->data + (size_t)capacity*4);
}

// V1: AFTER the flat-set change -- elem_size proved once in the preheader,
// bounds check + conditional data load still per access.
__attribute__((noinline))
static int v1(RtList* l, int items, int capacity) {
    for (int i = 1; i <= items; i++) {
        int w = (i*37)%97+1, v = (i*53)%211+1;
        if (l->elem_size != 4) return -1;              // the loop guard
        for (int at = capacity; at >= w; at--) {
            int a = 0, b = 0; int idx = at-w;
            if ((unsigned)idx < (unsigned)l->len) a = *(int*)((unsigned char*)l->data + (size_t)idx*4);
            if ((unsigned)at  < (unsigned)l->len) b = *(int*)((unsigned char*)l->data + (size_t)at*4);
            int cand = a + v;
            if (cand > b && at < l->len) *(int*)((unsigned char*)l->data + (size_t)at*4) = cand;
        }
    }
    return *(int*)((unsigned char*)l->data + (size_t)capacity*4);
}

// V2: bounds checks gone, header still re-read each access (unconditional now).
__attribute__((noinline))
static int v2(RtList* l, int items, int capacity) {
    for (int i = 1; i <= items; i++) {
        int w = (i*37)%97+1, v = (i*53)%211+1;
        if (l->elem_size != 4) return -1;
        for (int at = capacity; at >= w; at--) {
            int a = *(int*)((unsigned char*)l->data + (size_t)(at-w)*4);
            int b = *(int*)((unsigned char*)l->data + (size_t)at*4);
            int cand = a + v;
            if (cand > b) *(int*)((unsigned char*)l->data + (size_t)at*4) = cand;
        }
    }
    return *(int*)((unsigned char*)l->data + (size_t)capacity*4);
}

// V3: the view -- (base,len) materialised into SSA once per loop. Bounds checks KEPT.
__attribute__((noinline))
static int v3(RtList* l, int items, int capacity) {
    for (int i = 1; i <= items; i++) {
        int w = (i*37)%97+1, v = (i*53)%211+1;
        if (l->elem_size != 4) return -1;
        int* base = (int*)l->data; int len = l->len;   // hoisted once
        for (int at = capacity; at >= w; at--) {
            int a = 0, b = 0; int idx = at-w;
            if ((unsigned)idx < (unsigned)len) a = base[idx];
            if ((unsigned)at  < (unsigned)len) b = base[at];
            int cand = a + v;
            if (cand > b && at < len) base[at] = cand;
        }
    }
    return ((int*)l->data)[capacity];
}

// V4: the C++ arm -- raw array, no checks, no header.
__attribute__((noinline))
static int v4(int* best, int items, int capacity) {
    for (int i = 1; i <= items; i++) {
        int w = (i*37)%97+1, v = (i*53)%211+1;
        for (int at = capacity; at >= w; at--) {
            int cand = best[at-w] + v;
            if (cand > best[at]) best[at] = cand;
        }
    }
    return best[capacity];
}


// V5: the realistic target -- ONE range precondition per loop, checked in the
// preheader ("every index this loop will form is in bounds"), then no per-access
// check. This is what IRCE/loop-predication produce, and what codegen could emit
// itself from the loop bounds. Header still read per access.
__attribute__((noinline))
static int v5(RtList* l, int items, int capacity) {
    for (int i = 1; i <= items; i++) {
        int w = (i*37)%97+1, v = (i*53)%211+1;
        if (l->elem_size != 4) return -1;
        if (capacity >= l->len || capacity - w < 0) return -1;   // one precondition
        for (int at = capacity; at >= w; at--) {
            int a = *(int*)((unsigned char*)l->data + (size_t)(at-w)*4);
            int b = *(int*)((unsigned char*)l->data + (size_t)at*4);
            int cand = a + v;
            if (cand > b) *(int*)((unsigned char*)l->data + (size_t)at*4) = cand;
        }
    }
    return *(int*)((unsigned char*)l->data + (size_t)capacity*4);
}

// V6: precondition AND the view -- does hoisting (base,len) still help once the
// checks are gone?
__attribute__((noinline))
static int v6(RtList* l, int items, int capacity) {
    for (int i = 1; i <= items; i++) {
        int w = (i*37)%97+1, v = (i*53)%211+1;
        if (l->elem_size != 4) return -1;
        if (capacity >= l->len || capacity - w < 0) return -1;
        int* base = (int*)l->data;
        for (int at = capacity; at >= w; at--) {
            int cand = base[at-w] + v;
            if (cand > base[at]) base[at] = cand;
        }
    }
    return ((int*)l->data)[capacity];
}


// V7: NO range analysis. Keep a per-iteration check, but make it *exit* to a cold
// continuation instead of producing 0. The check then dominates the body, so the
// loads are unconditional and LICM can hoist the base -- the same unlock as V5,
// without needing to know the index range. Semantics are preserved by finishing
// the remaining iterations on the slow path from the current index.
__attribute__((noinline, cold))
static int knap_slow_tail(RtList* l, int at, int w, int v) {
    for (; at >= w; at--) {
        int a = 0, b = 0; int idx = at-w;
        if ((unsigned)idx < (unsigned)l->len) a = *(int*)((unsigned char*)l->data + (size_t)idx*4);
        if ((unsigned)at  < (unsigned)l->len) b = *(int*)((unsigned char*)l->data + (size_t)at*4);
        int cand = a + v;
        if (cand > b && at < l->len) *(int*)((unsigned char*)l->data + (size_t)at*4) = cand;
    }
    return 0;
}
__attribute__((noinline))
static int v7(RtList* l, int items, int capacity) {
    for (int i = 1; i <= items; i++) {
        int w = (i*37)%97+1, v = (i*53)%211+1;
        if (l->elem_size != 4) return -1;
        int at = capacity;
        for (; at >= w; at--) {
            int idx = at-w;
            if ((unsigned)idx >= (unsigned)l->len) { knap_slow_tail(l, at, w, v); break; }
            if ((unsigned)at  >= (unsigned)l->len) { knap_slow_tail(l, at, w, v); break; }
            int a = *(int*)((unsigned char*)l->data + (size_t)idx*4);
            int b = *(int*)((unsigned char*)l->data + (size_t)at*4);
            int cand = a + v;
            if (cand > b) *(int*)((unsigned char*)l->data + (size_t)at*4) = cand;
        }
    }
    return *(int*)((unsigned char*)l->data + (size_t)capacity*4);
}

int main(int argc, char** argv) {
    int scale = 4, items = 180, capacity = 800*scale;
    int reps = argc > 1 ? atoi(argv[1]) : 15;
    int n = capacity + 1;
    int* raw = calloc(n, sizeof(int));
    RtList l; memset(&l, 0, sizeof l);
    l.data = (void**)raw; l.len = n; l.cap = n; l.elem_size = 4;

    struct { const char* name; int kind; } vs[] = {
        {"V0 pre-change (test/access)", 0}, {"V1 current (guarded)", 1},
        {"V2 no bounds checks", 2}, {"V3 view (base,len) hoisted", 3},
        {"V4 raw array (C++ arm)", 4},
        {"V5 one range precondition", 5}, {"V6 precondition + view", 6},
        {"V7 exiting check, no range analysis", 7}};
    long long best_ns[8]; int chk[8];
    for (int k = 0; k < 8; k++) best_ns[k] = 1LL<<62;
    for (int r = 0; r < reps; r++) {
        for (int k = 0; k < 8; k++) {
            memset(raw, 0, (size_t)n*sizeof(int));
            long long t0 = now_ns();
            int c = (k==0)?v0(&l,items,capacity):(k==1)?v1(&l,items,capacity):
                    (k==2)?v2(&l,items,capacity):(k==3)?v3(&l,items,capacity):
                    (k==4)?v4(raw,items,capacity):(k==5)?v5(&l,items,capacity):
                    (k==6)?v6(&l,items,capacity):v7(&l,items,capacity);
            long long dt = now_ns()-t0;
            if (dt < best_ns[k]) best_ns[k] = dt;
            chk[k] = c;
        }
    }
    printf("%-32s %12s %8s  %s\n", "variant", "min ns", "vs V4", "checksum");
    for (int k = 0; k < 8; k++)
        printf("%-32s %12lld %7.2fx  %d\n", vs[k].name, best_ns[k],
               (double)best_ns[k]/(double)best_ns[4], chk[k]);
    free(raw);
    return 0;
}
