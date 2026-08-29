/* g2_cull_probe -- why merging g2's three struct-field copies into one 128-bit
 * store costs 1.68x, and what has to be true for it to cost anything at all.
 *
 * M6 slice 2 gave ordinary struct fields a struct path, which let LLVM prove
 * that storing `DrawCmd.mesh_id` cannot alias loading `Renderable.material_id`
 * and merge `cull`'s three field copies into `ldp d0,d1 / stp d0,d1`. That is
 * four instructions shorter and 1.68x slower.
 *
 * Every arm here walks the same boxed scene and writes the same 17 bytes per hit
 * into the same warm, pre-grown element block. They differ in exactly two ways:
 * how the slot pointer is obtained, and whether the 16 bytes go as one store or
 * two. The answer is in the first pair against the other two -- the widened
 * store is only expensive when the slot came from an out-of-line call that
 * reads and writes the same `RtList` header on its next iteration.
 *
 *   clang -O2 -o g2_cull_probe aif/evidence/bench/g2_cull_probe.c && ./g2_cull_probe
 *
 * Measured on macOS arm64 (Apple silicon), 2026-08-29:
 *
 *   slot from header  scalar      18.74 ms
 *   slot from header  ldp/stp     50.93 ms      2.74x
 *   slot from global  scalar      10.37 ms
 *   slot from global  ldp/stp      9.55 ms      0.92x
 *   slot inline       scalar      10.41 ms
 *   slot inline       ldp/stp      7.84 ms      0.76x
 *
 * So the metadata is right and the merge is right; the seam under them is not.
 * `list_push_slot` is not in PRISMIO_CURATED_OPS -- it reaches three statics, the
 * same rule `list_push_grow` was outlined to satisfy -- so it stays a `bl`, and
 * every struct literal pushed into a container pays this. Curating it is the
 * fix, and it is v0.2 work. Until then codegen declines the path tag on struct
 * *literal initialisers* only; see the comment in src/ir/expr.psm. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct { void** data; int len, cap, elem_own, _pad;
                 void (*elem_release)(void*); int arena, elem_size; } RtList;
typedef struct { int mesh_id, material_id; double z, y, x, radius; } Renderable;
#define SCENE 1000
#define FRAMES 20000
static Renderable **scene;
static RtList *L;

/* the real thing: reads data/len/cap/elem_size from the header, writes len */
__attribute__((noinline)) static void *slot_header(void *lp, int es) {
    RtList *l = lp;
    void *s = (unsigned char *)l->data + (size_t)l->len * (size_t)l->elem_size;
    l->len++; (void)es; return s;
}
/* same call cost, but touches no memory the loop also stores to */
static unsigned char *cursor;
__attribute__((noinline)) static void *slot_reg(void *lp, int es) {
    (void)lp; (void)es; unsigned char *s = cursor; cursor = s + 24; return s;
}

#define SCAN(GET, COPY)                                                       \
    L->len = 0; cursor = (unsigned char *)L->data;                            \
    for (long i = 0; i < SCENE; i++) {                                        \
        const unsigned char *s = (const unsigned char *)scene[i];             \
        double z; memcpy(&z, s + 8, 8);                                       \
        if (!(z >= 0.0 && z <= 500.0)) continue;                              \
        unsigned char *d = GET;                                               \
        COPY d[16] = 1;                                                       \
    }                                                                         \
    return L->len;

#define SCALAR __asm__ volatile("ldr w8,[%0]\n\tstr w8,[%1]\n\tldr w8,[%0,#4]\n\t" \
      "str w8,[%1,#4]\n\tldr d0,[%0,#8]\n\tstr d0,[%1,#8]" :: "r"(s),"r"(d) : "x8","d0","memory");
#define PAIR   __asm__ volatile("ldp d0,d1,[%0]\n\tstp d0,d1,[%1]" \
      :: "r"(s),"r"(d) : "d0","d1","memory");

static long a_hdr_scalar(void) { SCAN(slot_header(L,24), SCALAR) }
static long a_hdr_pair  (void) { SCAN(slot_header(L,24), PAIR)   }
static long a_reg_scalar(void) { SCAN(slot_reg(L,24),    SCALAR) }
static long a_reg_pair  (void) { SCAN(slot_reg(L,24),    PAIR)   }
static long a_inl_scalar(void) { SCAN(({unsigned char*t=cursor;cursor=t+24;t;}), SCALAR) }
static long a_inl_pair  (void) { SCAN(({unsigned char*t=cursor;cursor=t+24;t;}), PAIR)   }

static double best_ms(long (*f)(void)) {
    double best = 1e18;
    for (int r = 0; r < 5; r++) {
        struct timespec a, b; clock_gettime(CLOCK_MONOTONIC_RAW, &a);
        volatile long acc = 0; for (int k = 0; k < FRAMES; k++) acc += f();
        clock_gettime(CLOCK_MONOTONIC_RAW, &b);
        double ms = (b.tv_sec-a.tv_sec)*1e3 + (b.tv_nsec-a.tv_nsec)/1e6;
        if (ms < best) best = ms;
    }
    return best;
}
int main(void) {
    scene = malloc(SCENE * sizeof *scene);
    for (int i = 0; i < SCENE; i++) {
        Renderable *r = malloc(sizeof *r);
        r->mesh_id = i; r->material_id = i; r->z = i; r->y = i; r->x = i; r->radius = 1;
        scene[i] = r;
    }
    L = calloc(1, sizeof *L); L->elem_size = 24; L->cap = SCENE + 8;
    L->data = malloc((size_t)L->cap * 24); memset(L->data, 0, (size_t)L->cap * 24);
    struct { const char *n; long (*f)(void); } arms[] = {
        {"slot from header  scalar", a_hdr_scalar}, {"slot from header  ldp/stp", a_hdr_pair},
        {"slot from global  scalar", a_reg_scalar}, {"slot from global  ldp/stp", a_reg_pair},
        {"slot inline       scalar", a_inl_scalar}, {"slot inline       ldp/stp", a_inl_pair},
    };
    for (unsigned i = 0; i < sizeof arms/sizeof *arms; i++) {
        double ms = best_ms(arms[i].f);
        printf("%-26s %8.2f ms%s\n", arms[i].n, ms,
               (i & 1) ? "" : "");
        if (i & 1) printf("%-26s   pair/scalar %.3fx\n", "", ms / best_ms(arms[i-1].f));
    }
    return 0;
}
