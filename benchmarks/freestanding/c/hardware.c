// What only freestanding code does: atomic operations on a raw address, a lock,
// and volatile access to a register file.
#include "common.h"

#define WORD 0x44100000UL
#define LOCK 0x44100010UL
#define COUNTER 0x44100020UL
#define REGISTERS 0x44200000UL

u32 bench_atomic_counter(u32 scale) {
    *(volatile u32*)WORD = 0;
    for (u32 i = 0; i < 500000 * scale; i++) {
        __atomic_fetch_add((u32*)WORD, 1 + (i & 3), __ATOMIC_SEQ_CST);
    }
    return __atomic_load_n((u32*)WORD, __ATOMIC_SEQ_CST);
}

u32 bench_spinlock(u32 scale) {
    *(volatile u32*)LOCK = 0;
    *(volatile u32*)COUNTER = 0;
    for (u32 i = 0; i < 800000 * scale; i++) {
        u32 expected = 0;
        while (!__atomic_compare_exchange_n((u32*)LOCK, &expected, 1, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)) {
            expected = 0;
        }
        *(u32*)COUNTER = *(u32*)COUNTER + 1;
        __atomic_store_n((u32*)LOCK, 0, __ATOMIC_SEQ_CST);
    }
    return *(u32*)COUNTER;
}

u32 bench_volatile_registers(u32 scale) {
    for (u32 i = 0; i < 64; i++) *(volatile u32*)(REGISTERS + i * 4) = 0;
    u32 acc = 0;
    for (u32 i = 0; i < 900000 * scale; i++) {
        u32 slot = (i * 7) & 63;
        u32 v = *(volatile u32*)(REGISTERS + slot * 4);
        *(volatile u32*)(REGISTERS + slot * 4) = v + i;
        acc += v;
    }
    u32 sum = 0;
    for (u32 i = 0; i < 64; i++) sum += *(volatile u32*)(REGISTERS + i * 4);
    return acc ^ sum;
}
