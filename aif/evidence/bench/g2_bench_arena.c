/* G2 frame loop -- hand-tuned C at -O2. BENCHMARKS 3.2 baseline 3, "the ceiling
 * AIF approaches from below".
 *
 * Identical program and identical data model to g2_bench.c. The one change is
 * the allocation strategy for the per-frame batch: a bump arena, reset at the
 * end of each frame instead of freed object by object.
 *
 * This is exactly the transformation AIF's T1 is supposed to perform without
 * being asked -- the frame body is a scope, nothing allocated in it escapes,
 * so the whole batch can come from a region that dies with the block. If
 * Prismio at full inference lands near this line and its `--debug` control
 * lands near g2_bench.c, the model is doing what it claims.
 *
 * The arena is deliberately naive (one chunk, grown once, never shrunk),
 * because the point is the allocation discipline and not an allocator.
 */
#include <stdio.h>
#include <stdlib.h>

#define SCENE_COUNT 1000
#define FRAMES      20000

typedef struct { long mesh_id, material_id; double depth; int visible; } DrawCmd;
typedef struct { long mesh_id, material_id; double x, y, z, radius; } Renderable;

typedef struct { void **v; long len, cap; } List;

/* --- the arena ------------------------------------------------------------ */
static char *arena_base;
static size_t arena_used, arena_cap;

static void arena_reserve(size_t n) {
    if (arena_cap >= n) return;
    free(arena_base);
    arena_cap = n * 2;
    arena_base = malloc(arena_cap);
}
static void *arena_alloc(size_t n) {
    n = (n + 15) & ~(size_t)15;                 /* keep 16-byte alignment */
    void *p = arena_base + arena_used;
    arena_used += n;
    return p;
}
static void arena_reset(void) { arena_used = 0; }

/* --- the program ---------------------------------------------------------- */
static void list_init(List *l, void **storage, long cap) { l->v = storage; l->len = 0; l->cap = cap; }
static void list_push(List *l, void *p) { l->v[l->len++] = p; }

static List *build_scene(long count) {
    /* The scene outlives every frame, so it stays on the heap in both variants. */
    List *scene = malloc(sizeof(List));
    scene->cap = count; scene->len = 0; scene->v = malloc(sizeof(void *) * count);
    double f = 0.0;
    for (long i = 0; i < count; i++) {
        Renderable *r = malloc(sizeof(Renderable));
        r->mesh_id = i; r->material_id = i;
        r->x = f; r->y = f; r->z = f; r->radius = 1.0;
        list_push(scene, r);
        f += 1.0;
    }
    return scene;
}

static List *cull(List *scene, double near, double far) {
    List *cmds = arena_alloc(sizeof(List));
    list_init(cmds, arena_alloc(sizeof(void *) * scene->len), scene->len);
    for (long i = 0; i < scene->len; i++) {
        Renderable *r = scene->v[i];
        if (r->z >= near && r->z <= far) {
            DrawCmd *c = arena_alloc(sizeof(DrawCmd));
            c->mesh_id = r->mesh_id; c->material_id = r->material_id;
            c->depth = r->z; c->visible = 1;
            list_push(cmds, c);
        }
    }
    return cmds;
}

static long submit(List *cmds) {
    long drawn = 0;
    for (long i = 0; i < cmds->len; i++) {
        DrawCmd *c = cmds->v[i];
        if (c->visible) drawn++;
    }
    return drawn;
}

int main(void) {
    List *scene = build_scene(SCENE_COUNT);
    long submitted = 0, culled = 0;

    /* Enough for one frame: the list header, the pointer block, and one DrawCmd
     * per scene entry. Sized once because the frame body is the same each time. */
    arena_reserve(sizeof(List) + sizeof(void *) * SCENE_COUNT
                  + sizeof(DrawCmd) * SCENE_COUNT + 64 * SCENE_COUNT);

    for (long frame = 0; frame < FRAMES; frame++) {
        List *cmds = cull(scene, 0.0, 500.0);
        long drawn = submit(cmds);
        submitted += drawn;
        culled += (SCENE_COUNT - drawn);
        arena_reset();                          /* the whole batch, at once */
    }

    printf("submitted: %ld\n", submitted);
    printf("culled: %ld\n", culled);
    return 0;
}
