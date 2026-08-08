/* G2 frame loop -- idiomatic C at -O2. BENCHMARKS 3.2 baseline 2, the
 * normalisation point.
 *
 * A straightforward translation of aif/corpus/g2_frame_loop.psm, matching its
 * data model rather than improving on it: a Prismio struct is a heap object
 * held by pointer, and `list_push(cmds, DrawCmd { .. })` allocates one object
 * and stores the pointer. So each DrawCmd is its own malloc here too, and the
 * list is a doubling pointer vector starting at capacity 4, which is what
 * lang_runtime.c does.
 *
 * Writing the DrawCmds inline in a flat array would be faster and would not be
 * the same program -- it is the hand-tuned variant's job to be faster, and it
 * earns it with an arena rather than by changing the data model.
 *
 * The frees are the part a Prismio author does not write. That is the whole
 * comparison.
 */
#include <stdio.h>
#include <stdlib.h>

#define SCENE_COUNT 1000
#define FRAMES      20000

typedef struct { long mesh_id, material_id; double depth; int visible; } DrawCmd;
typedef struct { long mesh_id, material_id; double x, y, z, radius; } Renderable;

typedef struct { void **v; long len, cap; } List;

static void list_init(List *l) { l->cap = 4; l->len = 0; l->v = malloc(sizeof(void *) * 4); }
static void list_push(List *l, void *p) {
    if (l->len == l->cap) { l->cap *= 2; l->v = realloc(l->v, sizeof(void *) * l->cap); }
    l->v[l->len++] = p;
}

static List *build_scene(long count) {
    List *scene = malloc(sizeof(List));
    list_init(scene);
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
    List *cmds = malloc(sizeof(List));
    list_init(cmds);
    for (long i = 0; i < scene->len; i++) {
        Renderable *r = scene->v[i];
        if (r->z >= near && r->z <= far) {
            DrawCmd *c = malloc(sizeof(DrawCmd));
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

    for (long frame = 0; frame < FRAMES; frame++) {
        List *cmds = cull(scene, 0.0, 500.0);
        long drawn = submit(cmds);
        submitted += drawn;
        culled += (SCENE_COUNT - drawn);
        /* The batch is transient. Prismio's region reclaims it at the closing
         * brace; here it is three explicit steps and every one is a chance to
         * be wrong. */
        for (long i = 0; i < cmds->len; i++) free(cmds->v[i]);
        free(cmds->v);
        free(cmds);
    }

    printf("submitted: %ld\n", submitted);
    printf("culled: %ld\n", culled);
    return 0;
}
