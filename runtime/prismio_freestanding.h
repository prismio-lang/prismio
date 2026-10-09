#ifndef PRISMIO_FREESTANDING_H
#define PRISMIO_FREESTANDING_H

// What lang_runtime.c uses of the C library, for a program with no C library:
// `--freestanding`, where runtime/freestanding/runtime.c compiles that file with
// PRISMIO_FREESTANDING for the program's own triple and CPU features.
// docs/FREESTANDING_MEMORY.md is the design; this is its section 5, step 2.
//
// Four groups, each with one answer:
//
// - **Allocation** is the program's: `prismio_alloc`, `prismio_realloc` and
//   `prismio_free`, which runtime/freestanding/panic.c declares weak and stops the
//   machine in, so a program that never allocates defines none of them. They never
//   answer NULL; a kernel decides what exhaustion means, once, in its allocator.
// - **Bytes and strings** (`memcpy` ... `strchr`, `qsort`) are runtime/freestanding/
//   libc.c's, weak, so a kernel's own `memcpy` wins.
// - **Diagnostics** have no stream to go to. `fprintf` keeps the format string of
//   the last message and `exit` hands it to `prismio_panic_hook` as the detail, so
//   "runtime error: %d byte(s) at offset %d are out of range" still says what went
//   wrong, without the numbers. Every other stdio call does nothing.
// - **Threads** do not exist: no `spawn`, one core. Locks and thread-locals reduce
//   to nothing (prismio_runtime.h), which is what single-core freestanding means.

#include <stddef.h>
#include <stdint.h>
#include <float.h>

#define NULL_STREAM ((FILE*)0)
typedef struct PrismioFreestandingFile FILE;
#define stderr NULL_STREAM
#define stdout NULL_STREAM

__attribute__((noreturn)) void prismio_panic_hook(const char* kind, const char* detail,
                                                   const char* file, int line, int col);

void* prismio_alloc(size_t size);
void* prismio_realloc(void* p, size_t size);
void prismio_free(void* p);

static inline void* malloc(size_t size) { return prismio_alloc(size); }
static inline void* realloc(void* p, size_t size) { return prismio_realloc(p, size); }
static inline void free(void* p) { if (p) prismio_free(p); }

void* memcpy(void* dst, const void* src, size_t n);
void* memmove(void* dst, const void* src, size_t n);
void* memset(void* dst, int c, size_t n);
int memcmp(const void* a, const void* b, size_t n);
void* memchr(const void* s, int c, size_t n);
size_t strlen(const char* s);
int strcmp(const char* a, const char* b);
char* strcpy(char* dst, const char* src);
char* strncpy(char* dst, const char* src, size_t n);
char* strchr(const char* s, int c);
void qsort(void* base, size_t count, size_t size, int (*compare)(const void*, const void*));

static const char* prismio_freestanding_message = "";

static inline int fprintf(FILE* stream, const char* format, ...) {
    (void)stream;
    prismio_freestanding_message = format;
    return 0;
}
static inline int fputs(const char* s, FILE* stream) { (void)s; (void)stream; return 0; }
static inline int fputc(int c, FILE* stream) { (void)stream; return c; }
static inline int fflush(FILE* stream) { (void)stream; return 0; }
static inline size_t fwrite(const void* p, size_t size, size_t count, FILE* stream) {
    (void)p; (void)size; (void)stream;
    return count;
}
static inline FILE* fopen(const char* path, const char* mode) { (void)path; (void)mode; return NULL_STREAM; }
static inline int fclose(FILE* stream) { (void)stream; return 0; }
static inline int snprintf(char* out, size_t cap, const char* format, ...) {
    (void)format;
    if (cap) out[0] = '\0';
    return 0;
}
static inline int atexit(void (*fn)(void)) { (void)fn; return 0; }
static inline char* getenv(const char* name) { (void)name; return NULL; }

// The message as the hook's `detail`: without the "runtime error: " every format
// starts with, since that is the hook's `kind`, and without the trailing newline.
// Copied, because the format itself is a string literal.
__attribute__((noreturn)) static inline void exit(int status) {
    (void)status;
    static char detail[160];
    const char* m = prismio_freestanding_message;
    const char* prefix = "runtime error: ";
    size_t skip = 0;
    while (prefix[skip] && m[skip] == prefix[skip]) skip++;
    if (prefix[skip]) skip = 0;
    size_t n = 0;
    while (m[skip + n] && m[skip + n] != '\n' && n + 1 < sizeof detail) {
        detail[n] = m[skip + n];
        n++;
    }
    detail[n] = '\0';
    prismio_panic_hook("runtime error", detail, "", 0, 0);
}

static int prismio_freestanding_errno;
#define errno prismio_freestanding_errno

#endif
