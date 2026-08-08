// allocount -- a malloc/free counter that works on any language's binary.
//
// Loaded with DYLD_INSERT_LIBRARIES (macOS) or LD_PRELOAD (Linux), it counts the
// process's actual allocator traffic and writes the totals to the file named by
// $ALLOCOUNT_OUT at exit.
//
// It counts the *allocator*, not the language. That is the whole reason it
// exists: "allocations/sec" compared across Prismio, C, Rust and Swift means
// nothing if each number comes from a different language's own bookkeeping.
// Prismio's --verify counters, Rust's alloc hooks and Swift's runtime all count
// slightly different events. malloc does not care who called it.
//
// Rust's default global allocator on macOS is the system one, and Swift's
// swift_slowAlloc bottoms out in malloc, so all four land here.
//
// Counters are plain non-atomic longs: every benchmark in this set is
// single-threaded, and making them atomic would put a lock-prefixed RMW in the
// hot path of the thing being measured.

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>

static unsigned long n_malloc, n_calloc, n_realloc, n_free;

// Written without stdio so the report cannot itself allocate.
static void emit(void) {
    const char *path = getenv("ALLOCOUNT_OUT");
    char buf[256];
    int n = snprintf(buf, sizeof buf,
                     "malloc %lu\ncalloc %lu\nrealloc %lu\nfree %lu\n",
                     n_malloc, n_calloc, n_realloc, n_free);
    if (n <= 0) return;
    int fd = 2;
    if (path && *path) {
        fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) return;
    }
    ssize_t ignored = write(fd, buf, (size_t)n);
    (void)ignored;
    if (fd != 2) close(fd);
}

__attribute__((constructor)) static void setup(void) { atexit(emit); }

#ifdef __APPLE__

// dyld interposition: a __DATA,__interpose section of {replacement, original}
// pairs. Unlike symbol preloading this leaves the real malloc reachable by name,
// so the counter can call through without recursing.
#define INTERPOSE(repl, orig) \
    __attribute__((used, section("__DATA,__interpose"))) \
    static const struct { const void *r; const void *o; } _interpose_##orig = \
        { (const void *)(unsigned long)&repl, (const void *)(unsigned long)&orig };

static void *count_malloc(size_t s)            { n_malloc++;  return malloc(s); }
static void *count_calloc(size_t n, size_t s)  { n_calloc++;  return calloc(n, s); }
static void *count_realloc(void *p, size_t s)  { n_realloc++; return realloc(p, s); }
static void  count_free(void *p)               { if (p) n_free++; free(p); }

INTERPOSE(count_malloc,  malloc)
INTERPOSE(count_calloc,  calloc)
INTERPOSE(count_realloc, realloc)
INTERPOSE(count_free,    free)

#else

// Linux: LD_PRELOAD plus dlsym(RTLD_NEXT). calloc is the awkward one -- dlsym
// itself may call it before `real_calloc` is resolved -- so it is served from a
// static buffer until then.
#define _GNU_SOURCE
#include <dlfcn.h>

static void *(*real_malloc)(size_t);
static void *(*real_calloc)(size_t, size_t);
static void *(*real_realloc)(void *, size_t);
static void (*real_free)(void *);

static char boot[65536];
static size_t boot_used;

static void resolve(void) {
    static int done;
    if (done) return;
    done = 1;
    real_malloc  = dlsym(RTLD_NEXT, "malloc");
    real_calloc  = dlsym(RTLD_NEXT, "calloc");
    real_realloc = dlsym(RTLD_NEXT, "realloc");
    real_free    = dlsym(RTLD_NEXT, "free");
}

static int from_boot(void *p) {
    return (char *)p >= boot && (char *)p < boot + sizeof boot;
}

void *malloc(size_t s) {
    resolve();
    n_malloc++;
    return real_malloc(s);
}

void *calloc(size_t n, size_t s) {
    if (!real_calloc) {
        size_t need = (n * s + 15) & ~(size_t)15;
        if (boot_used + need > sizeof boot) return NULL;
        void *p = boot + boot_used;
        boot_used += need;
        memset(p, 0, n * s);
        return p;
    }
    n_calloc++;
    return real_calloc(n, s);
}

void *realloc(void *p, size_t s) {
    resolve();
    n_realloc++;
    return real_realloc(p, s);
}

void free(void *p) {
    resolve();
    if (from_boot(p)) return;
    if (p) n_free++;
    real_free(p);
}

#endif
