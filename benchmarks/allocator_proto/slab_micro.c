// ns per operation: the slab's fast paths against the system allocator, one thread and a
// producer/consumer pair. Built with and without -DUSE_SYSTEM to compare.
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>
#define PRISMIO_NOINLINE __attribute__((noinline))
#define PRISMIO_THREAD_LOCAL _Thread_local
static volatile long prismio_memory_threads_enabled;
static PRISMIO_THREAD_LOCAL int prismio_memory_worker;
static int prismio_memory_threads_are_enabled(void) { return __atomic_load_n(&prismio_memory_threads_enabled, __ATOMIC_ACQUIRE) != 0; }
// What lang_runtime.c provides above the body: its includes, and the two libc spellings.
#include <sys/mman.h>
#include <sched.h>
#define tmp_free(p) free(p)
#define tmp_realloc(p, n) realloc((p), (n))
#include "slab_body.inc"
#ifdef USE_SYSTEM
#define A(n) malloc(n)
#define F(p) free(p)
#else
#define A(n) rt_base_alloc(n)
#define F(p) rt_free(p)
#endif
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e9 + t.tv_nsec; }
#define N 20000000L
static void* sink;
static double lifo(size_t size) {      // alloc, touch, free: the best case for any free list
    double t = now();
    for (long i = 0; i < N; i++) { char* p = A(size); p[0] = (char)i; sink = p; F(p); }
    return (now() - t) / N;
}
static double batch(size_t size, int k) {   // alloc k then free k, in order: 2 ops per block
    void** v = malloc(sizeof(void*) * k);
    double t = now();
    for (long i = 0; i < N / k; i++) { for (int j = 0; j < k; j++) { v[j] = A(size); *(char*)v[j] = 1; } for (int j = 0; j < k; j++) F(v[j]); }
    double r = (now() - t) / N; free(v); return r;
}
#define Q 4096
static void* q[Q]; static long head, tail; static volatile int done;
static void* prod(void* a) { prismio_memory_worker = 1; (void)a;
    for (long i = 0; i < N / 4; i++) { void* p = A(48); *(long*)p = i;
        long h; while ((h = __atomic_load_n(&head, __ATOMIC_RELAXED)) - __atomic_load_n(&tail, __ATOMIC_ACQUIRE) >= Q) ;
        q[h % Q] = p; __atomic_store_n(&head, h + 1, __ATOMIC_RELEASE); }
    done = 1; prismio_slab_thread_flush(); return 0; }
static void* cons(void* a) { prismio_memory_worker = 1; (void)a; long n = 0;
    for (;;) { long t = __atomic_load_n(&tail, __ATOMIC_RELAXED);
        if (t == __atomic_load_n(&head, __ATOMIC_ACQUIRE)) { if (done && t == head) break; continue; }
        F(q[t % Q]); __atomic_store_n(&tail, t + 1, __ATOMIC_RELEASE); n++; }
    prismio_slab_thread_flush(); return 0; }
static double xthread(void) {
    pthread_t a, b; double t = now();
    pthread_create(&a, 0, prod, 0); pthread_create(&b, 0, cons, 0); pthread_join(a, 0); pthread_join(b, 0);
    return (now() - t) / (N / 4);
}
int main(void) {
    printf("lifo 48B      %6.2f ns/pair\n", lifo(48));
    printf("lifo 256B     %6.2f ns/pair\n", lifo(256));
    printf("batch64 48B   %6.2f ns/pair\n", batch(48, 64));
    printf("batch4096 48B %6.2f ns/pair\n", batch(48, 4096));
    __atomic_store_n(&prismio_memory_threads_enabled, 1, __ATOMIC_RELEASE);
    printf("prod->cons    %6.2f ns/pair (two threads, 48B, queue 4096)\n", xthread());
    return 0;
}
