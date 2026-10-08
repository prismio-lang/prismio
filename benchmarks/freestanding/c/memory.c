// Memory behaviour: dependent loads, a queue, and bulk movement.
#include "common.h"

#define CHAIN 2048

u32 bench_pointer_chase(u32 scale) {
    u32 order[CHAIN], next[CHAIN];
    for (u32 i = 0; i < CHAIN; i++) order[i] = i;
    u32 s = 9001;
    for (u32 i = CHAIN - 1; i > 0; i--) {
        LCG(s);
        u32 j = (s >> 8) % (i + 1);
        u32 t = order[i];
        order[i] = order[j];
        order[j] = t;
    }
    for (u32 k = 0; k < CHAIN; k++) next[order[k]] = order[(k + 1) % CHAIN];
    u32 at = order[0], sum = 0;
    for (u32 step = 0; step < 2400000 * scale; step++) {
        at = next[at];
        sum += at;
    }
    return sum;
}

#define RING 1024

u32 bench_ring_buffer(u32 scale) {
    u32 slots[RING];
    u32 head = 0, tail = 0, s = 321, sum = 0, popped = 0;
    for (u32 i = 0; i < 300000 * scale; i++) {
        LCG(s);
        if (head - tail < RING) {
            slots[head & (RING - 1)] = s;
            head += 1;
        }
        if (((s >> 8) & 1) == 0 && head != tail) {
            sum += slots[tail & (RING - 1)];
            tail += 1;
            popped += 1;
        }
    }
    return sum ^ popped;
}

#define SRC 0x44000000UL
#define DST 0x45000000UL
#define BLOCK 32768UL

u32 bench_mem_copy(u32 scale) {
    for (u64 o = 0; o < BLOCK; o += 8) *(u64*)(SRC + o) = (o * 0x9E3779B97F4A7C15UL) ^ 0x5555;
    for (u32 r = 0; r < 288 * scale; r++) {
        for (u64 o = 0; o < BLOCK; o += 8) {
            u64 v = *(u64*)(SRC + o);
            *(u64*)(DST + o) = v;
            *(u64*)(SRC + o) = v + r + 1;
        }
    }
    u64 sum = 0;
    for (u64 o = 0; o < BLOCK; o += 8) sum += *(u64*)(DST + o);
    return (u32)sum ^ (u32)(sum >> 32);
}
