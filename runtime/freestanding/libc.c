// The C library functions a freestanding program needs and has no library for.
//
// LLVM lowers a struct copy, a zero-filled array and a Vec's growth to `memcpy`,
// `memmove` and `memset` whatever the source says, and the freestanding runtime
// (runtime/freestanding/runtime.c) calls the rest. So every freestanding build
// links these, beside the failure core in panic.c. **Every one is weak**: a kernel
// that already has a `memcpy` -- tuned, or the one its C half links -- keeps it.
//
// The byte functions move a machine word at a time once both sides are aligned,
// because a byte loop measured `edit_distance` at 2.0x C in the freestanding
// benchmarks (benchmarks/freestanding). Aligned accesses only, so they are safe
// with the MMU off, where an unaligned access faults on AArch64.
//
// `no_builtin` on each: clang recognises a copy loop and would compile `memcpy`'s
// own body to a call to `memcpy`.

#include <stddef.h>
#include <stdint.h>

#define WORD sizeof(uintptr_t)

static int both_aligned(const void* a, const void* b) {
    return (((uintptr_t)a | (uintptr_t)b) & (WORD - 1)) == 0;
}

__attribute__((weak, no_builtin)) void* memcpy(void* dst, const void* src, size_t n) {
    unsigned char* d = (unsigned char*)dst;
    const unsigned char* s = (const unsigned char*)src;
    if (both_aligned(d, s)) {
        for (; n >= WORD; n -= WORD, d += WORD, s += WORD) {
            *(uintptr_t*)d = *(const uintptr_t*)s;
        }
    }
    while (n--) *d++ = *s++;
    return dst;
}

__attribute__((weak, no_builtin)) void* memmove(void* dst, const void* src, size_t n) {
    unsigned char* d = (unsigned char*)dst;
    const unsigned char* s = (const unsigned char*)src;
    if (d == s || n == 0) return dst;
    if (d < s || d >= s + n) return memcpy(dst, src, n);
    d += n;
    s += n;
    if (both_aligned(d, s)) {
        for (; n >= WORD; n -= WORD) {
            d -= WORD;
            s -= WORD;
            *(uintptr_t*)d = *(const uintptr_t*)s;
        }
    }
    while (n--) *--d = *--s;
    return dst;
}

__attribute__((weak, no_builtin)) void* memset(void* dst, int c, size_t n) {
    unsigned char* d = (unsigned char*)dst;
    unsigned char byte = (unsigned char)c;
    if (((uintptr_t)d & (WORD - 1)) == 0) {
        uintptr_t word = (uintptr_t)0x0101010101010101ull * byte;
        for (; n >= WORD; n -= WORD, d += WORD) *(uintptr_t*)d = word;
    }
    while (n--) *d++ = byte;
    return dst;
}

__attribute__((weak, no_builtin)) int memcmp(const void* a, const void* b, size_t n) {
    const unsigned char* x = (const unsigned char*)a;
    const unsigned char* y = (const unsigned char*)b;
    for (; n; n--, x++, y++) {
        if (*x != *y) return *x < *y ? -1 : 1;
    }
    return 0;
}

__attribute__((weak, no_builtin)) void* memchr(const void* s, int c, size_t n) {
    const unsigned char* p = (const unsigned char*)s;
    for (; n; n--, p++) {
        if (*p == (unsigned char)c) return (void*)p;
    }
    return NULL;
}

__attribute__((weak, no_builtin)) size_t strlen(const char* s) {
    const char* p = s;
    while (*p) p++;
    return (size_t)(p - s);
}

__attribute__((weak, no_builtin)) int strcmp(const char* a, const char* b) {
    while (*a && *a == *b) { a++; b++; }
    return (unsigned char)*a - (unsigned char)*b;
}

__attribute__((weak, no_builtin)) char* strcpy(char* dst, const char* src) {
    char* d = dst;
    while ((*d++ = *src++)) {}
    return dst;
}

__attribute__((weak, no_builtin)) char* strncpy(char* dst, const char* src, size_t n) {
    size_t i = 0;
    for (; i < n && src[i]; i++) dst[i] = src[i];
    for (; i < n; i++) dst[i] = '\0';
    return dst;
}

__attribute__((weak, no_builtin)) char* strchr(const char* s, int c) {
    for (;; s++) {
        if (*s == (char)c) return (char*)s;
        if (!*s) return NULL;
    }
}

// Heapsort: no recursion and no allocation, which is what a kernel stack and a
// kernel heap can afford, and O(n log n) in the worst case. `sort` reaches it for
// an element type the compiler does not sort inline.
static void swap_bytes(unsigned char* a, unsigned char* b, size_t size) {
    for (size_t i = 0; i < size; i++) {
        unsigned char t = a[i];
        a[i] = b[i];
        b[i] = t;
    }
}

static void sift_down(unsigned char* base, size_t root, size_t count, size_t size,
                      int (*compare)(const void*, const void*)) {
    for (;;) {
        size_t child = 2 * root + 1;
        if (child >= count) return;
        if (child + 1 < count && compare(base + child * size, base + (child + 1) * size) < 0) child++;
        if (compare(base + root * size, base + child * size) >= 0) return;
        swap_bytes(base + root * size, base + child * size, size);
        root = child;
    }
}

__attribute__((weak)) void qsort(void* base, size_t count, size_t size,
                                 int (*compare)(const void*, const void*)) {
    unsigned char* b = (unsigned char*)base;
    if (count < 2) return;
    for (size_t i = count / 2; i-- > 0;) sift_down(b, i, count, size, compare);
    for (size_t end = count - 1; end > 0; end--) {
        swap_bytes(b, b + end * size, size);
        sift_down(b, 0, end, size, compare);
    }
}
