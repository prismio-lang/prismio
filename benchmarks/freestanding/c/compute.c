// Integer compute: checksums, hashing, bit work, fixed-point arithmetic and a
// dispatch loop. No floating point, because the target keeps its FP unit off.
#include "common.h"

u32 bench_crc32(u32 scale) {
    u32 table[256];
    for (u32 i = 0; i < 256; i++) {
        u32 c = i;
        for (u32 k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
        table[i] = c;
    }
    u8 buffer[32768];
    u32 s = 2024;
    for (u32 i = 0; i < 32768; i++) { LCG(s); buffer[i] = (u8)(s >> 24); }
    u32 crc = 0xFFFFFFFFu;
    for (u32 r = 0; r < 32 * scale; r++) {
        for (u32 i = 0; i < 32768; i++) crc = table[(crc ^ buffer[i]) & 255] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFFu;
}

static const u32 K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
};

static inline u32 rotr(u32 x, u32 n) { return (x >> n) | (x << (32 - n)); }

u32 bench_sha256(u32 scale) {
    u32 h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
    u32 w[64];
    u32 s = 808;
    for (u32 block = 0; block < 3000 * scale; block++) {
        for (u32 t = 0; t < 16; t++) { LCG(s); w[t] = s; }
        for (u32 t = 16; t < 64; t++) {
            u32 s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
            u32 s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
            w[t] = w[t - 16] + s0 + w[t - 7] + s1;
        }
        u32 a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
        for (u32 t = 0; t < 64; t++) {
            u32 big1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
            u32 ch = (e & f) ^ ((e ^ 0xFFFFFFFFu) & g);
            u32 t1 = hh + big1 + ch + K[t] + w[t];
            u32 big0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
            u32 maj = (a & b) ^ (a & c) ^ (b & c);
            u32 t2 = big0 + maj;
            hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }
    return h[0] ^ h[1] ^ h[2] ^ h[3] ^ h[4] ^ h[5] ^ h[6] ^ h[7];
}

u32 bench_popcount(u32 scale) {
    u32 s = 55, bits = 0;
    for (u32 i = 0; i < 600000 * scale; i++) {
        LCG(s);
        u32 x = s;
        while (x != 0) {
            x &= x - 1;
            bits += 1;
        }
    }
    return bits;
}

u32 bench_mandelbrot_fixed(u32 scale) {
    u32 total = 0;
    for (u32 r = 0; r < 6 * scale; r++) {
        for (i32 py = 0; py < 96; py++) {
            for (i32 px = 0; px < 96; px++) {
                i32 cr = -131072 + px * 2048;
                i32 ci = -98304 + py * 2048;
                i32 zr = 0, zi = 0;
                u32 it = 0;
                while (it < 40) {
                    i32 zr2 = (i32)(((i64)zr * (i64)zr) >> 16);
                    i32 zi2 = (i32)(((i64)zi * (i64)zi) >> 16);
                    if (zr2 + zi2 > 262144) break;
                    zi = (i32)(((i64)zr * (i64)zi) >> 15) + ci;
                    zr = zr2 - zi2 + cr;
                    it += 1;
                }
                total += it;
            }
        }
    }
    return total;
}

// A register machine: 8 instructions of 4 words each, run in a loop.
u32 bench_bytecode_interpreter(u32 scale) {
    // op, a, b, c
    const u32 program[32] = {
        0, 0, 1, 2,   // r0 = r1 + r2
        1, 1, 0, 3,   // r1 = r0 ^ r3
        2, 2, 1, 1,   // r2 = r1 * r1
        3, 3, 2, 0,   // r3 = r2 << 1
        4, 0, 0, 7,   // r0 = r0 + 7
        5, 1, 3, 0,   // r1 = r3
        0, 2, 2, 0,   // r2 = r2 + r0
        1, 3, 3, 1,   // r3 = r3 ^ r1
    };
    u32 reg[4] = {1, 2, 3, 4};
    u32 pc = 0;
    for (u32 step = 0; step < 400000 * scale; step++) {
        u32 base = pc * 4;
        u32 op = program[base];
        u32 a = program[base + 1], b = program[base + 2], c = program[base + 3];
        if (op == 0) reg[a] = reg[b] + reg[c];
        else if (op == 1) reg[a] = reg[b] ^ reg[c];
        else if (op == 2) reg[a] = reg[b] * reg[c];
        else if (op == 3) reg[a] = reg[b] << 1;
        else if (op == 4) reg[a] = reg[b] + c;
        else reg[a] = reg[b];
        pc = pc == 7 ? 0 : pc + 1;
    }
    return reg[0] ^ reg[1] ^ reg[2] ^ reg[3];
}
