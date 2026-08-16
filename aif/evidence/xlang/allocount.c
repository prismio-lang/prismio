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
//
// **The window, and why the process total is the wrong number.**
//
// bench.py times only the frame loop but used to report the allocator traffic of
// the whole *process*, and the two stopped describing the same region the moment
// the corpus's reporting loops moved onto the allocating `println` overload
// (commit 901b494): g1's column went 2,214 -> 26,326, which is 4.02 allocations
// per print over 6,002 prints, with the timing untouched. The column was then
// reporting overhead wearing a workload's name.
//
// The fix is to stop counting the dump. Every program in this set -- Prismio,
// Rust and Swift alike -- brackets each frame with CLOCK_MONOTONIC_RAW, because
// that is how it emits the `frame_ns` lines bench.py parses, and every one of
// them dumps those lines *after* the last frame. So interposing the clock gives
// the boundary for free, in every language, with no edit to any program:
//
//   first clock read  -> latch the window open
//   every clock read  -> latch, so the last one closes it
//   window            = last - first
//
// **What the window actually spans, stated exactly.** Not the frame loop alone.
// libsystem reads the clock a couple of dozen times during process startup, so
// the first read is before `main`, and the window is therefore *everything up to
// the end of the last timed frame*: process init, setup, and the loop -- with the
// report dump excluded. That is the right cut and not a concession to the
// startup calls. Setup is where a boxed representation actually pays: g1's window
// is 2,215 allocations against Rust's 206, and almost all of Prismio's are
// build_system's 2,000 individually malloc'd particles. A loop-only window would
// read ~0 against ~0 and erase the one difference the column exists to show. The
// dump is overhead of *reporting* the measurement and belongs to neither.
//
// It also reproduces the number this column carried before 901b494 (2,214 on g1)
// and matches g2's independently documented 10,201,215 allocations, which is the
// check that the window is where it is claimed to be.
//
// `clock_calls` is emitted so the harness can audit that: these programs read the
// clock exactly twice per frame, so anything outside [2*frames, 2*frames+64] means
// the bracket is not where it looks -- a runtime calling the same symbol in a hot
// path, or a program that stopped timing per frame. A window derived from an
// interposed symbol would otherwise fail silently, which is the failure mode this
// project keeps finding.

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <time.h>

static unsigned long n_malloc, n_calloc, n_realloc, n_free;
static unsigned long w0_malloc, w0_calloc, w0_realloc, w0_free;
static unsigned long w1_malloc, w1_calloc, w1_realloc, w1_free;
static unsigned long n_clock;

static void clock_mark(void) {
    if (n_clock == 0) {
        w0_malloc = n_malloc; w0_calloc = n_calloc;
        w0_realloc = n_realloc; w0_free = n_free;
    }
    n_clock++;
    w1_malloc = n_malloc; w1_calloc = n_calloc;
    w1_realloc = n_realloc; w1_free = n_free;
}

// Written without stdio so the report cannot itself allocate.
static void emit(void) {
    const char *path = getenv("ALLOCOUNT_OUT");
    char buf[512];
    int n = snprintf(buf, sizeof buf,
                     "malloc %lu\ncalloc %lu\nrealloc %lu\nfree %lu\n"
                     "loop_malloc %lu\nloop_calloc %lu\nloop_realloc %lu\n"
                     "loop_free %lu\nclock_calls %lu\n",
                     n_malloc, n_calloc, n_realloc, n_free,
                     w1_malloc - w0_malloc, w1_calloc - w0_calloc,
                     w1_realloc - w0_realloc, w1_free - w0_free, n_clock);
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

// The window bracket. All three languages' harnesses bottom out here on macOS:
// Prismio declares it as an `extern fn`, Rust's harness::now_ns and Swift's
// nowNs both call it directly.
extern uint64_t clock_gettime_nsec_np(clockid_t);
static uint64_t count_clock(clockid_t c) {
    clock_mark();
    return clock_gettime_nsec_np(c);
}
INTERPOSE(count_clock, clock_gettime_nsec_np)

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

// The window bracket. `clock_gettime_nsec_np` is Darwin-only; on Linux the
// harnesses reach the clock through clock_gettime, so that is the symbol to
// bracket on. Same contract: first call opens the window, last call closes it.
int clock_gettime(clockid_t c, struct timespec *ts) {
    static int (*real_clock_gettime)(clockid_t, struct timespec *);
    if (!real_clock_gettime)
        real_clock_gettime = dlsym(RTLD_NEXT, "clock_gettime");
    clock_mark();
    return real_clock_gettime(c, ts);
}

#endif
