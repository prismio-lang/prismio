// What each LAYOUT 6 grouping candidate is worth *on this runtime's
// representation*, measured rather than modelled.
//
// The question this answers. LAYOUT 6 lists five candidate dimensions and the
// compiler searches one (field order). Of the other four, SoA and handle width
// need handles; a hot/cold split does not -- the split object is still reached
// through one pointer, because the cold block hangs off the hot record. So
// hot/cold is *emittable today*, and the only question is whether it pays.
//
// The reason to doubt it is the representation. LAYOUT 5's cost model computes
//
//     footprint = N * resident
//
// which assumes the N records are contiguous: shrinking `resident` is then worth
// something because it packs more records per cache line. Prismio's `List<T>` is
// a vector of *pointers* to individually malloc'd records (RESULTS-xlang 8.1),
// so a traversal takes a miss per record no matter how small the record is, and
// the modelled benefit may not exist. That is a claim about the machine model,
// and this file is the experiment that settles it.
//
// Shape is g1_particles.psm's, which the corpus header calls "the layout
// discriminator": a 12-float record, `integrate` touching 6 fields and `fade`
// touching 2.
//
//   A  boxed AoS      -- pointer vector, one malloc per record.   TODAY.
//   B  boxed hot/cold -- as A, cold 6 fields in a second block.   EMITTABLE NOW.
//   C  inline AoS     -- one contiguous array of records.         needs inline List<T>.
//   D  inline hot/cold-- contiguous hot array + cold blocks.      needs both.
//   E  SoA            -- 12 contiguous arrays.                    needs handles.
//
// B/A is what building hot/cold today would buy. E/A is the prize the handoff
// attributes to SoA. E/C separates "SoA" from "contiguity", which is the
// confound that matters: g1_tuned.rs is *pure* SoA at 0.26x of idiomatic Rust
// and is contiguous as well, so the 0.26x is not attributable to SoA alone.
//
//   clang -O2 aif/evidence/bench/layout_repr.c -o build/layout_repr && ./build/layout_repr

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N      200000
#define FRAMES 200
#define REPS   7

static double now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

static int cmp_double(const void* a, const void* b) {
    double x = *(const double*)a, y = *(const double*)b;
    return (x > y) - (x < y);
}

// ---------------------------------------------------------------------------
// A -- boxed AoS. What the compiler emits today.
// ---------------------------------------------------------------------------

typedef struct {
    double px, py, pz, vx, vy, vz;
    double r, g, b, a, life, size;
} Particle;

static double run_boxed_aos(void) {
    Particle** ps = (Particle**)malloc(N * sizeof(Particle*));
    for (int i = 0; i < N; i++) {
        Particle* p = (Particle*)malloc(sizeof(Particle));
        p->px = i; p->py = i; p->pz = 0; p->vx = 1; p->vy = 2; p->vz = 0;
        p->r = 1; p->g = 1; p->b = 1; p->a = 1; p->life = 100; p->size = 1;
        ps[i] = p;
    }
    double t0 = now_ms();
    for (int f = 0; f < FRAMES; f++) {
        for (int i = 0; i < N; i++) {                 // integrate: 6 of 12
            Particle* p = ps[i];
            p->px += p->vx * 0.016; p->py += p->vy * 0.016; p->pz += p->vz * 0.016;
        }
        for (int i = 0; i < N; i++) {                 // fade: 2 of 12
            Particle* p = ps[i];
            p->a = p->a * 0.999; p->life = p->life - 0.016;
        }
    }
    double t1 = now_ms();
    double sink = 0;
    for (int i = 0; i < N; i++) sink += ps[i]->px + ps[i]->a;
    for (int i = 0; i < N; i++) free(ps[i]);
    free(ps);
    if (sink == 12345.6789) printf("");            // keep the loops
    return t1 - t0;
}

// ---------------------------------------------------------------------------
// B -- boxed hot/cold. Emittable today: one pointer still reaches the object,
// the cold block hangs off the hot record. This is the candidate under test.
// ---------------------------------------------------------------------------

typedef struct { double r, g, b, size; } PCold;
typedef struct {
    double px, py, pz, vx, vy, vz;                 // integrate's 6
    double a, life;                                 // fade's 2
    PCold* cold;                                    // the rest
} PHot;

static double run_boxed_split(void) {
    PHot** ps = (PHot**)malloc(N * sizeof(PHot*));
    for (int i = 0; i < N; i++) {
        PHot* p = (PHot*)malloc(sizeof(PHot));
        PCold* c = (PCold*)malloc(sizeof(PCold));
        p->px = i; p->py = i; p->pz = 0; p->vx = 1; p->vy = 2; p->vz = 0;
        p->a = 1; p->life = 100;
        c->r = 1; c->g = 1; c->b = 1; c->size = 1;
        p->cold = c;
        ps[i] = p;
    }
    double t0 = now_ms();
    for (int f = 0; f < FRAMES; f++) {
        for (int i = 0; i < N; i++) {
            PHot* p = ps[i];
            p->px += p->vx * 0.016; p->py += p->vy * 0.016; p->pz += p->vz * 0.016;
        }
        for (int i = 0; i < N; i++) {
            PHot* p = ps[i];
            p->a = p->a * 0.999; p->life = p->life - 0.016;
        }
    }
    double t1 = now_ms();
    double sink = 0;
    for (int i = 0; i < N; i++) sink += ps[i]->px + ps[i]->a;
    for (int i = 0; i < N; i++) { free(ps[i]->cold); free(ps[i]); }
    free(ps);
    if (sink == 12345.6789) printf("");
    return t1 - t0;
}

// ---------------------------------------------------------------------------
// C -- inline AoS. What inline element storage for List<T> would buy, with no
// layout change at all. RESULTS-xlang 9 item 1.
// ---------------------------------------------------------------------------

static double run_inline_aos(void) {
    Particle* ps = (Particle*)malloc(N * sizeof(Particle));
    for (int i = 0; i < N; i++) {
        ps[i].px = i; ps[i].py = i; ps[i].pz = 0;
        ps[i].vx = 1; ps[i].vy = 2; ps[i].vz = 0;
        ps[i].r = 1; ps[i].g = 1; ps[i].b = 1;
        ps[i].a = 1; ps[i].life = 100; ps[i].size = 1;
    }
    double t0 = now_ms();
    for (int f = 0; f < FRAMES; f++) {
        for (int i = 0; i < N; i++) {
            ps[i].px += ps[i].vx * 0.016; ps[i].py += ps[i].vy * 0.016;
            ps[i].pz += ps[i].vz * 0.016;
        }
        for (int i = 0; i < N; i++) {
            ps[i].a = ps[i].a * 0.999; ps[i].life = ps[i].life - 0.016;
        }
    }
    double t1 = now_ms();
    double sink = 0;
    for (int i = 0; i < N; i++) sink += ps[i].px + ps[i].a;
    free(ps);
    if (sink == 12345.6789) printf("");
    return t1 - t0;
}

// ---------------------------------------------------------------------------
// D -- inline hot/cold. Contiguous hot array, cold in a second contiguous
// array. This is where the split's modelled benefit is supposed to live.
// ---------------------------------------------------------------------------

typedef struct {
    double px, py, pz, vx, vy, vz;
    double a, life;
} PHotInline;

static double run_inline_split(void) {
    PHotInline* hot = (PHotInline*)malloc(N * sizeof(PHotInline));
    PCold* cold = (PCold*)malloc(N * sizeof(PCold));
    for (int i = 0; i < N; i++) {
        hot[i].px = i; hot[i].py = i; hot[i].pz = 0;
        hot[i].vx = 1; hot[i].vy = 2; hot[i].vz = 0;
        hot[i].a = 1; hot[i].life = 100;
        cold[i].r = 1; cold[i].g = 1; cold[i].b = 1; cold[i].size = 1;
    }
    double t0 = now_ms();
    for (int f = 0; f < FRAMES; f++) {
        for (int i = 0; i < N; i++) {
            hot[i].px += hot[i].vx * 0.016; hot[i].py += hot[i].vy * 0.016;
            hot[i].pz += hot[i].vz * 0.016;
        }
        for (int i = 0; i < N; i++) {
            hot[i].a = hot[i].a * 0.999; hot[i].life = hot[i].life - 0.016;
        }
    }
    double t1 = now_ms();
    double sink = 0;
    for (int i = 0; i < N; i++) sink += hot[i].px + hot[i].a;
    free(hot); free(cold);
    if (sink == 12345.6789) printf("");
    return t1 - t0;
}

// ---------------------------------------------------------------------------
// E -- SoA. What handles would buy. Twelve contiguous arrays; a traversal
// streams exactly the fields it touches.
// ---------------------------------------------------------------------------

static double run_soa(void) {
    double* px = (double*)malloc(N * sizeof(double));
    double* py = (double*)malloc(N * sizeof(double));
    double* pz = (double*)malloc(N * sizeof(double));
    double* vx = (double*)malloc(N * sizeof(double));
    double* vy = (double*)malloc(N * sizeof(double));
    double* vz = (double*)malloc(N * sizeof(double));
    double* r  = (double*)malloc(N * sizeof(double));
    double* g  = (double*)malloc(N * sizeof(double));
    double* b  = (double*)malloc(N * sizeof(double));
    double* a  = (double*)malloc(N * sizeof(double));
    double* li = (double*)malloc(N * sizeof(double));
    double* sz = (double*)malloc(N * sizeof(double));
    for (int i = 0; i < N; i++) {
        px[i] = i; py[i] = i; pz[i] = 0; vx[i] = 1; vy[i] = 2; vz[i] = 0;
        r[i] = 1; g[i] = 1; b[i] = 1; a[i] = 1; li[i] = 100; sz[i] = 1;
    }
    double t0 = now_ms();
    for (int f = 0; f < FRAMES; f++) {
        for (int i = 0; i < N; i++) {
            px[i] += vx[i] * 0.016; py[i] += vy[i] * 0.016; pz[i] += vz[i] * 0.016;
        }
        for (int i = 0; i < N; i++) {
            a[i] = a[i] * 0.999; li[i] = li[i] - 0.016;
        }
    }
    double t1 = now_ms();
    double sink = 0;
    for (int i = 0; i < N; i++) sink += px[i] + a[i];
    free(px); free(py); free(pz); free(vx); free(vy); free(vz);
    free(r); free(g); free(b); free(a); free(li); free(sz);
    if (sink == 12345.6789) printf("");
    return t1 - t0;
}


// ---------------------------------------------------------------------------
// F -- chunked inline AoS. Contiguous storage WITH stable element addresses.
//
// This is the variant that decides whether inline `List<T>` needs the views
// project or not, and it is here because the whole cost of inline storage is
// invalidation: a contiguous block reallocs on push, which moves every element,
// so a reference into it dies. That is why the inline-List item is written as
// "needs views/slices to be expressible" -- a view has to become (container,
// index) so it re-resolves, which needs by-value multi-word returns, which ends
// at an AIF site migrating across a call boundary.
//
// A chunked block sidesteps all of it. Elements live in fixed-size chunks that
// are never moved; growth appends a chunk. So an interior pointer stays valid
// across a push, exactly as it does today with one malloc per record, and
// `list_get` can keep returning a raw pointer.
//
// The cost is the index: `chunks[i >> K][i & MASK]` is a load and two ALU ops
// where a flat block is one GEP. This measures whether that is worth paying.
// Indexed generically on purpose -- that is what a `list_get(l, i)` call
// compiles to. Walking chunk-by-chunk would be faster still and is the
// optimisation available afterwards, not the thing under test.
// ---------------------------------------------------------------------------

#define CHUNK_SHIFT 10
#define CHUNK_LEN   (1 << CHUNK_SHIFT)
#define CHUNK_MASK  (CHUNK_LEN - 1)

static double run_chunked_inline(void) {
    int nchunks = (N + CHUNK_LEN - 1) / CHUNK_LEN;
    Particle** chunks = (Particle**)malloc(nchunks * sizeof(Particle*));
    for (int c = 0; c < nchunks; c++)
        chunks[c] = (Particle*)malloc(CHUNK_LEN * sizeof(Particle));
    for (int i = 0; i < N; i++) {
        Particle* p = &chunks[i >> CHUNK_SHIFT][i & CHUNK_MASK];
        p->px = i; p->py = i; p->pz = 0; p->vx = 1; p->vy = 2; p->vz = 0;
        p->r = 1; p->g = 1; p->b = 1; p->a = 1; p->life = 100; p->size = 1;
    }
    double t0 = now_ms();
    for (int f = 0; f < FRAMES; f++) {
        for (int i = 0; i < N; i++) {
            Particle* p = &chunks[i >> CHUNK_SHIFT][i & CHUNK_MASK];
            p->px += p->vx * 0.016; p->py += p->vy * 0.016; p->pz += p->vz * 0.016;
        }
        for (int i = 0; i < N; i++) {
            Particle* p = &chunks[i >> CHUNK_SHIFT][i & CHUNK_MASK];
            p->a = p->a * 0.999; p->life = p->life - 0.016;
        }
    }
    double t1 = now_ms();
    double sink = 0;
    for (int i = 0; i < N; i++) {
        Particle* p = &chunks[i >> CHUNK_SHIFT][i & CHUNK_MASK];
        sink += p->px + p->a;
    }
    for (int c = 0; c < nchunks; c++) free(chunks[c]);
    free(chunks);
    if (sink == 12345.6789) printf("");
    return t1 - t0;
}

// G -- chunked inline, hot/cold. Both dimensions at once, still with stable
// addresses. The combination the compiler could reach without handles.
static double run_chunked_split(void) {
    int nchunks = (N + CHUNK_LEN - 1) / CHUNK_LEN;
    PHotInline** hot = (PHotInline**)malloc(nchunks * sizeof(PHotInline*));
    PCold** cold = (PCold**)malloc(nchunks * sizeof(PCold*));
    for (int c = 0; c < nchunks; c++) {
        hot[c] = (PHotInline*)malloc(CHUNK_LEN * sizeof(PHotInline));
        cold[c] = (PCold*)malloc(CHUNK_LEN * sizeof(PCold));
    }
    for (int i = 0; i < N; i++) {
        PHotInline* h = &hot[i >> CHUNK_SHIFT][i & CHUNK_MASK];
        PCold* cd = &cold[i >> CHUNK_SHIFT][i & CHUNK_MASK];
        h->px = i; h->py = i; h->pz = 0; h->vx = 1; h->vy = 2; h->vz = 0;
        h->a = 1; h->life = 100;
        cd->r = 1; cd->g = 1; cd->b = 1; cd->size = 1;
    }
    double t0 = now_ms();
    for (int f = 0; f < FRAMES; f++) {
        for (int i = 0; i < N; i++) {
            PHotInline* h = &hot[i >> CHUNK_SHIFT][i & CHUNK_MASK];
            h->px += h->vx * 0.016; h->py += h->vy * 0.016; h->pz += h->vz * 0.016;
        }
        for (int i = 0; i < N; i++) {
            PHotInline* h = &hot[i >> CHUNK_SHIFT][i & CHUNK_MASK];
            h->a = h->a * 0.999; h->life = h->life - 0.016;
        }
    }
    double t1 = now_ms();
    double sink = 0;
    for (int i = 0; i < N; i++) {
        PHotInline* h = &hot[i >> CHUNK_SHIFT][i & CHUNK_MASK];
        sink += h->px + h->a;
    }
    for (int c = 0; c < nchunks; c++) { free(hot[c]); free(cold[c]); }
    free(hot); free(cold);
    if (sink == 12345.6789) printf("");
    return t1 - t0;
}

// ---------------------------------------------------------------------------

typedef double (*Variant)(void);

int main(void) {
    struct { const char* name; Variant fn; const char* needs; } vs[] = {
        { "A  boxed AoS      (today)",          run_boxed_aos,    "-"              },
        { "B  boxed hot/cold (emittable now)",  run_boxed_split,  "-"              },
        { "C  inline AoS",                      run_inline_aos,   "inline List<T>" },
        { "D  inline hot/cold",                 run_inline_split, "inline List<T>" },
        { "E  SoA",                             run_soa,          "handles"        },
        { "F  chunked inline AoS",              run_chunked_inline, "capacity only" },
        { "G  chunked inline hot/cold",         run_chunked_split,  "capacity only" },
    };
    int nv = (int)(sizeof(vs) / sizeof(vs[0]));

    double med[8];
    for (int v = 0; v < nv; v++) {
        double runs[REPS];
        for (int r = 0; r < REPS; r++) runs[r] = vs[v].fn();
        qsort(runs, REPS, sizeof(double), cmp_double);
        med[v] = runs[REPS / 2];
    }

    printf("g1_particles shape: %d records x 12 doubles, %d frames, "
           "integrate touches 6/12, fade touches 2/12\n", N, FRAMES);
    printf("median of %d runs\n\n", REPS);
    printf("%-36s %10s %8s  %s\n", "variant", "median ms", "rel A", "needs");
    for (int v = 0; v < nv; v++) {
        printf("%-36s %10.1f %7.2fx  %s\n",
               vs[v].name, med[v], med[v] / med[0], vs[v].needs);
    }
    printf("\nB/A = what a hot/cold split buys on today's representation\n");
    printf("F/A = inline storage WITHOUT the views project (addresses stay stable)\n");
    printf("F/C = what chunking costs against a flat block\n");
    printf("D/C = what the same split buys once records are contiguous\n");
    printf("E/C = SoA's contribution with contiguity held constant\n");
    return 0;
}
