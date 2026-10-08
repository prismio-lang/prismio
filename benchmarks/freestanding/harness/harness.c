// The harness every freestanding arm links: boot, timing, output and exit.
//
// It is the same object file for C, Rust and Prismio, built once by one compiler
// with one set of flags, so the only code that differs between arms is the
// benchmarks themselves. Each arm provides `u32 bench_<name>(u32 scale)` for every
// workload in benchmarks.json (the list arrives as workloads.h, which run.py
// writes from that file), and nothing else.
//
// **What is measured.** QEMU runs with `-icount shift=0`, which makes the guest's
// virtual clock advance one nanosecond per instruction executed. The generic timer
// counts that clock at 62.5 MHz, so one tick is exactly 16 instructions, and the
// count is the same on every run on every machine: there is no noise to take a
// median of. `CNTVCT_EL0` is read around each workload and the difference is the
// number of guest instructions it took, to the nearest 16.
//
// It is an instruction count and not a time. It does not model a cache, a
// pipeline or a branch predictor, and a workload whose cost is mostly memory
// stalls costs more on real silicon than its count says. What it does show,
// without noise, is how much code each compiler asked the machine to run.

typedef unsigned char u8;
typedef unsigned int u32;
typedef unsigned long u64;

#include "workloads.h"

#define X(name, scale) extern u32 bench_##name(u32 scale_);
WORKLOADS(X)
#undef X

#define UART0 ((volatile u32*)0x09000000UL)

// QEMU `virt` gives a cleared RAM, so there is no .bss to zero. The stack is
// named by the linker script and is large because the sieve and the matrices
// keep their arrays in the frame.
extern char __stack_top[];

__attribute__((naked, section(".text.boot"))) void _start(void) {
    __asm__ volatile(
        "adrp x0, __stack_top\n"
        "add  x0, x0, :lo12:__stack_top\n"
        "mov  sp, x0\n"
        "bl   harness_main\n"
        "1: wfi\n"
        "b 1b\n");
}

static void put(char c) { *UART0 = (u32)c; }

static void put_str(const char* s) {
    while (*s) put(*s++);
}

static void put_u64(u64 v) {
    char digits[24];
    int n = 0;
    if (v == 0) digits[n++] = '0';
    while (v) { digits[n++] = (char)('0' + v % 10); v /= 10; }
    while (n) put(digits[--n]);
}

static inline u64 ticks(void) {
    u64 v;
    // The barrier keeps the read from moving across the call it brackets.
    __asm__ volatile("isb\nmrs %0, cntvct_el0" : "=r"(v) : : "memory");
    return v;
}

// ARM semihosting SYS_EXIT, which QEMU turns into its own exit status.
static void exit_emulator(int status) {
    static u64 block[2];
    block[0] = 0x20026;
    block[1] = (u64)status;
    register u64 op __asm__("x0") = 0x18;
    register u64 arg __asm__("x1") = (u64)block;
    __asm__ volatile("hlt #0xf000" : : "r"(op), "r"(arg) : "memory");
}

// One line per workload: `bench <name> <ticks> <result>`.
void harness_main(void) {
    put_str("harness ready\n");
#define X(name, scale)                                       \
    {                                                        \
        u64 start = ticks();                                 \
        u32 result = bench_##name(scale * BENCH_SCALE);      \
        u64 stop = ticks();                                  \
        put_str("bench " #name " ");                         \
        put_u64(stop - start);                               \
        put(' ');                                            \
        put_u64(result);                                     \
        put('\n');                                           \
    }
    WORKLOADS(X)
#undef X
    put_str("done\n");
    exit_emulator(0);
}

// The memory functions the compilers emit calls to. Every freestanding program
// has to provide them, and these are shared, so the arms differ in how often they
// are called and not in what they cost. That only holds if they are not the
// bottleneck: a byte loop here made a loop that one compiler turns into a call
// (and another leaves inline) read as a 2x difference in the compilers, so these
// move a word at a time.
//
// Strict alignment is the constraint (the MMU is off, so an unaligned access
// faults): a word is moved only when both pointers sit at the same offset in it,
// after the bytes before the first aligned address. `Int` arrays are only
// 4-aligned, so there is a 4-byte tier under the 8-byte one. `may_alias` because
// the bytes being moved have some other type. -fno-builtin keeps the loops from
// being recognised as memcpy and calling themselves.
typedef u64 __attribute__((may_alias)) word8;
typedef u32 __attribute__((may_alias)) word4;

// 64 bytes a pass, one end-pointer compare for the loop: on a 4-aligned stream that
// is 16 pair loads and stores and three instructions of bookkeeping, about five per
// 16 bytes, and no compare-and-subtract chain carries between passes. COPY8 moves
// eight words; a pass is one of them for 8-byte words and two for 4-byte ones.
#define COPY8(W, d, s, at)                                                 \
    {                                                                      \
        W v0 = ((const W*)(s))[(at) + 0], v1 = ((const W*)(s))[(at) + 1];  \
        W v2 = ((const W*)(s))[(at) + 2], v3 = ((const W*)(s))[(at) + 3];  \
        W v4 = ((const W*)(s))[(at) + 4], v5 = ((const W*)(s))[(at) + 5];  \
        W v6 = ((const W*)(s))[(at) + 6], v7 = ((const W*)(s))[(at) + 7];  \
        ((W*)(d))[(at) + 0] = v0; ((W*)(d))[(at) + 1] = v1;                \
        ((W*)(d))[(at) + 2] = v2; ((W*)(d))[(at) + 3] = v3;                \
        ((W*)(d))[(at) + 4] = v4; ((W*)(d))[(at) + 5] = v5;                \
        ((W*)(d))[(at) + 6] = v6; ((W*)(d))[(at) + 7] = v7;                \
    }

#define COPY_FORWARD(W, d, s, count)                                       \
    {                                                                      \
        while (((u64)(d) & (sizeof(W) - 1)) && (count)) {                  \
            *(d)++ = *(s)++;                                               \
            (count)--;                                                     \
        }                                                                  \
        const u8* stop = (s) + ((count) & ~(unsigned long)63);             \
        (count) &= 63;                                                     \
        while ((s) != stop) {                                              \
            COPY8(W, d, s, 0)                                              \
            if (sizeof(W) == 4) COPY8(W, d, s, 8)                          \
            (d) += 64; (s) += 64;                                          \
        }                                                                  \
        for (; (count) >= sizeof(W); (count) -= sizeof(W)) {               \
            *(W*)(d) = *(const W*)(s);                                     \
            (d) += sizeof(W); (s) += sizeof(W);                            \
        }                                                                  \
    }

void* memset(void* dest, int value, unsigned long count) {
    u8* d = (u8*)dest;
    u8 byte = (u8)value;
    while (((u64)d & 7) && count) { *d++ = byte; count--; }
    u64 word = byte * 0x0101010101010101UL;
    for (; count >= 32; count -= 32, d += 32) {
        ((word8*)d)[0] = word; ((word8*)d)[1] = word;
        ((word8*)d)[2] = word; ((word8*)d)[3] = word;
    }
    for (; count >= 8; count -= 8, d += 8) *(word8*)d = word;
    while (count--) *d++ = byte;
    return dest;
}

void* memcpy(void* dest, const void* src, unsigned long count) {
    u8* d = (u8*)dest;
    const u8* s = (const u8*)src;
    if ((((u64)d ^ (u64)s) & 7) == 0) COPY_FORWARD(word8, d, s, count)
    else if ((((u64)d ^ (u64)s) & 3) == 0) COPY_FORWARD(word4, d, s, count)
    while (count--) *d++ = *s++;
    return dest;
}

void* memmove(void* dest, const void* src, unsigned long count) {
    u8* d = (u8*)dest;
    const u8* s = (const u8*)src;
    if (d < s || d >= s + count) return memcpy(dest, src, count);
    // Overlapping with the destination above the source: copy from the end.
    for (unsigned long i = count; i > 0; i--) d[i - 1] = s[i - 1];
    return dest;
}

int memcmp(const void* a, const void* b, unsigned long count) {
    const u8* x = (const u8*)a;
    const u8* y = (const u8*)b;
    for (unsigned long i = 0; i < count; i++) {
        if (x[i] != y[i]) return (int)x[i] - (int)y[i];
    }
    return 0;
}
