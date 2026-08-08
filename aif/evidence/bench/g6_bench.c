/* G6 engine + gameplay -- C at -O2. BENCHMARKS 3.2 baselines 2 and 3.
 *
 * Build both from this one file, because the two baselines must differ in the
 * allocation discipline and in nothing else; g2 has them as two files and that
 * is already a standing invitation to drift.
 *
 *     clang -O2              g6_bench.c -o g6_c.exe
 *     clang -O2 -DUSE_ARENA  g6_bench.c -o g6_c_arena.exe
 *
 * A faithful translation of aif/corpus/g6_game.psm + g6_engine.psm: a Prismio
 * struct is a heap object held by pointer, `list_push(l, T { .. })` allocates
 * one object and stores the pointer, and a List is a doubling pointer vector
 * starting at capacity 4 (lang_runtime.c). Nothing is flattened into an array
 * that Prismio does not flatten.
 *
 * What USE_ARENA changes: the per-tick Order batch -- the transient the
 * gameplay module rebuilds every tick and discards -- comes from a bump arena
 * reset at the end of the tick instead of being freed object by object. The
 * engine's retained storage (Actor, Transform, Velocity, the World) stays on
 * the heap in both, because it genuinely outlives the tick.
 *
 * That is exactly the split AIF's T1 is supposed to find without being told.
 */
#include <stdio.h>
#include <stdlib.h>

#define SQUAD_SIZE 400
#define TICKS      100
#define RUNS       300

/* --- lists ---------------------------------------------------------------- */
typedef struct { void **v; long len, cap; } List;

static List *list_new(void) {
    List *l = malloc(sizeof(List));
    l->cap = 4; l->len = 0; l->v = malloc(sizeof(void *) * 4);
    return l;
}
static void list_push(List *l, void *p) {
    if (l->len == l->cap) { l->cap *= 2; l->v = realloc(l->v, sizeof(void *) * l->cap); }
    l->v[l->len++] = p;
}
static void list_free_all(List *l) {
    for (long i = 0; i < l->len; i++) free(l->v[i]);
    free(l->v); free(l);
}

/* --- arena, used for the per-tick Order batch only ------------------------ */
#ifdef USE_ARENA
static char *arena_base;
static size_t arena_used, arena_cap;
static void arena_reserve(size_t n) {
    if (arena_cap >= n) return;
    free(arena_base); arena_cap = n * 2; arena_base = malloc(arena_cap);
}
static void *arena_alloc(size_t n) {
    n = (n + 15) & ~(size_t)15;
    void *p = arena_base + arena_used;
    arena_used += n;
    return p;
}
static void arena_reset(void) { arena_used = 0; }
#endif

/* --- engine --------------------------------------------------------------- */
typedef struct { double x, y, z, yaw; } Transform;
typedef struct { double dx, dy, dz; } Velocity;
typedef struct { long transform, velocity, health, max_health, team; int alive; } Actor;
typedef struct { List *actors, *transforms, *velocities; long tick, spawned, killed; } World;

static World *world_create(void) {
    World *w = malloc(sizeof(World));
    w->actors = list_new(); w->transforms = list_new(); w->velocities = list_new();
    w->tick = 0; w->spawned = 0; w->killed = 0;
    return w;
}
static void world_destroy(World *w) {
    list_free_all(w->actors); list_free_all(w->transforms); list_free_all(w->velocities);
    free(w);
}
static long world_spawn(World *w, double x, double y, long team) {
    long handle = w->actors->len;
    Transform *t = malloc(sizeof(Transform));
    t->x = x; t->y = y; t->z = 0.0; t->yaw = 0.0;
    list_push(w->transforms, t);
    Velocity *v = malloc(sizeof(Velocity));
    v->dx = 0.0; v->dy = 0.0; v->dz = 0.0;
    list_push(w->velocities, v);
    Actor *a = malloc(sizeof(Actor));
    a->transform = handle; a->velocity = handle;
    a->health = 100; a->max_health = 100; a->team = team; a->alive = 1;
    list_push(w->actors, a);
    w->spawned++;
    return handle;
}
static Transform *world_transform(World *w, long h) { return w->transforms->v[h]; }
static Actor *world_actor(World *w, long h) { return w->actors->v[h]; }
static void world_set_velocity(World *w, long h, double dx, double dy) {
    Velocity *v = w->velocities->v[h];
    v->dx = dx; v->dy = dy;
}
static int world_damage(World *w, long h, long amount) {
    Actor *a = w->actors->v[h];
    if (!a->alive) return 0;
    a->health -= amount;
    if (a->health <= 0) { a->health = 0; a->alive = 0; w->killed++; return 1; }
    return 0;
}
static void world_step(World *w, double dt) {
    for (long i = 0; i < w->actors->len; i++) {
        Actor *a = w->actors->v[i];
        if (a->alive) {
            Transform *t = w->transforms->v[a->transform];
            Velocity *v = w->velocities->v[a->velocity];
            t->x += v->dx * dt; t->y += v->dy * dt; t->z += v->dz * dt;
        }
    }
    w->tick++;
}
static long world_count_alive(World *w) {
    long alive = 0;
    for (long i = 0; i < w->actors->len; i++)
        if (((Actor *)w->actors->v[i])->alive) alive++;
    return alive;
}

/* --- gameplay ------------------------------------------------------------- */
typedef struct { long actor, role, kills; } Member;
typedef struct { List *members; long team, morale; double rally_x, rally_y; } Squad;
typedef struct { long target; double dx, dy; long priority; } Order;

static Squad *make_squad(long team, double rx, double ry) {
    Squad *s = malloc(sizeof(Squad));
    s->members = list_new(); s->team = team; s->morale = 100;
    s->rally_x = rx; s->rally_y = ry;
    return s;
}
static void squad_destroy(Squad *s) { list_free_all(s->members); free(s); }

static void recruit(World *w, Squad *s, long count) {
    double f = 0.0;
    for (long i = 0; i < count; i++) {
        long h = world_spawn(w, s->rally_x + f, s->rally_y + f, s->team);
        Member *m = malloc(sizeof(Member));
        m->actor = h; m->role = 0; m->kills = 0;
        list_push(s->members, m);
        f += 2.0;
    }
}

static List *plan_orders(World *w, Squad *s) {
#ifdef USE_ARENA
    List *orders = arena_alloc(sizeof(List));
    orders->cap = s->members->len + 1; orders->len = 0;
    orders->v = arena_alloc(sizeof(void *) * orders->cap);
#else
    List *orders = list_new();
#endif
    for (long i = 0; i < s->members->len; i++) {
        Member *mem = s->members->v[i];
        long h = mem->actor;
        Actor *a = world_actor(w, h);
        if (a->alive) {
            Transform *t = world_transform(w, h);
            double dx = s->rally_x - t->x;
            double dy = s->rally_y - t->y;
            long pri = (a->health < 50) ? 3 : 1;
#ifdef USE_ARENA
            Order *o = arena_alloc(sizeof(Order));
#else
            Order *o = malloc(sizeof(Order));
#endif
            o->target = h; o->dx = dx; o->dy = dy; o->priority = pri;
            list_push(orders, o);
        }
    }
    return orders;
}

static long apply_orders(World *w, List *orders, double speed) {
    long applied = 0;
    for (long i = 0; i < orders->len; i++) {
        Order *o = orders->v[i];
        world_set_velocity(w, o->target, o->dx * speed, o->dy * speed);
        applied++;
    }
    return applied;
}

static long resolve_combat(World *w, Squad *a, Squad *b) {
    long na = a->members->len, nb = b->members->len, kills = 0;
    for (long i = 0; i < na && i < nb; i++) {
        Member *am = a->members->v[i];
        Member *bm = b->members->v[i];
        Actor *att = world_actor(w, am->actor);
        if (att->alive && world_damage(w, bm->actor, 7)) { am->kills++; kills++; }
    }
    if (kills > 0) b->morale -= kills;
    return kills;
}

static long scenario(void) {
    World *w = world_create();
    Squad *red = make_squad(0, 0.0, 0.0);
    Squad *blue = make_squad(1, 100.0, 100.0);
    recruit(w, red, SQUAD_SIZE);
    recruit(w, blue, SQUAD_SIZE);

    double dt = 0.016;
    long total_orders = 0, total_kills = 0;

    for (long tick = 0; tick < TICKS; tick++) {
        List *red_orders = plan_orders(w, red);
        List *blue_orders = plan_orders(w, blue);
        total_orders += apply_orders(w, red_orders, 1.0);
        total_orders += apply_orders(w, blue_orders, 1.0);

        world_step(w, dt);
        total_kills += resolve_combat(w, red, blue);
#ifdef USE_ARENA
        arena_reset();                     /* the whole tick's batch, at once */
#else
        list_free_all(red_orders);
        list_free_all(blue_orders);
#endif
    }

    long alive = world_count_alive(w);
    squad_destroy(red); squad_destroy(blue); world_destroy(w);
    return alive + total_orders + total_kills;
}

int main(void) {
#ifdef USE_ARENA
    /* Two order lists per tick, each at most one Order per squad member. */
    arena_reserve(2 * (sizeof(List) + sizeof(void *) * (SQUAD_SIZE + 1)
                       + sizeof(Order) * (SQUAD_SIZE + 1)) + 4096);
#endif
    long acc = 0;
    for (long run = 0; run < RUNS; run++) acc += scenario();
    printf("checksum: %ld\n", acc);
    return 0;
}
