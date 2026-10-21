// Interposes libc free/realloc; a slab block reaching either is logged once per caller and
// then *leaked* (free) or copied (realloc) so the run continues and finds the next one.
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <execinfo.h>
#include <unistd.h>
#include <pthread.h>
#define DYLD_INTERPOSE(_r,_e) __attribute__((used)) static struct{const void*r;const void*e;} _ip_##_e __attribute__((section("__DATA,__interpose"))) = {(const void*)(unsigned long)&_r,(const void*)(unsigned long)&_e};
static inline int in_slab(void* p) { return (uintptr_t)p - 0x600000000000ULL < (64ULL << 30); }
static void* seen[256]; static int nseen; static pthread_mutex_t lk = PTHREAD_MUTEX_INITIALIZER;
__attribute__((noinline, disable_tail_calls)) static void note(const char* what, void* p) {
    void* bt[12]; int n = backtrace(bt, 12); void* caller = n > 2 ? bt[2] : 0;   /* bt[0] note, bt[1] my_free/my_realloc, bt[2] the freeing function */
    pthread_mutex_lock(&lk);
    for (int i = 0; i < nseen; i++) if (seen[i] == caller) { pthread_mutex_unlock(&lk); return; }
    if (nseen < 256) seen[nseen++] = caller;
    pthread_mutex_unlock(&lk);
    char** sy = backtrace_symbols(bt + 2, n > 2 ? (n - 2 > 6 ? 6 : n - 2) : 0);
    const char* path = getenv("SHIM_LOG");
    FILE* f = path ? fopen(path, "a") : stderr; if (!f) f = stderr;
    fprintf(f, "SLAB-MISUSE[%s] libc %s of slab block %p:", getprogname(), what, p);
    for (int i = 0; sy && i < (n - 2 > 6 ? 6 : n - 2); i++) { char* s = sy[i]; char* q = strstr(s, "0x"); fprintf(f, " <- %s", q ? q + 19 : s); }
    fprintf(f, "\n"); if (f != stderr) fclose(f);
}
__attribute__((disable_tail_calls)) void my_free(void* p) { if (in_slab(p)) { note("free", p); return; } free(p); }
void* my_realloc(void* p, size_t n) {
    if (in_slab(p)) { note("realloc", p); void* q = malloc(n); if (q) memcpy(q, p, n < 16 ? n : 16); return q; }
    return realloc(p, n);
}
DYLD_INTERPOSE(my_free, free)
DYLD_INTERPOSE(my_realloc, realloc)
