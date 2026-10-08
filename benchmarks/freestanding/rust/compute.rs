use crate::lcg;

#[no_mangle]
pub extern "C" fn bench_crc32(scale: u32) -> u32 {
    let mut table = [0u32; 256];
    for i in 0..256u32 {
        let mut c = i;
        for _ in 0..8 {
            c = if (c & 1) != 0 { 0xEDB88320u32 ^ (c >> 1) } else { c >> 1 };
        }
        table[i as usize] = c;
    }
    let mut buffer = [0u8; 32768];
    let mut s: u32 = 2024;
    for i in 0..32768 {
        buffer[i] = (lcg(&mut s) >> 24) as u8;
    }
    let mut crc: u32 = 0xFFFFFFFF;
    for _ in 0..32 * scale {
        for i in 0..32768 {
            crc = table[((crc ^ buffer[i] as u32) & 255) as usize] ^ (crc >> 8);
        }
    }
    crc ^ 0xFFFFFFFF
}

const K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

#[inline(always)]
fn rotr(x: u32, n: u32) -> u32 {
    (x >> n) | (x << (32 - n))
}

#[no_mangle]
pub extern "C" fn bench_sha256(scale: u32) -> u32 {
    let mut h: [u32; 8] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];
    let mut w = [0u32; 64];
    let mut s: u32 = 808;
    for _ in 0..3000 * scale {
        for t in 0..16 {
            w[t] = lcg(&mut s);
        }
        for t in 16..64 {
            let s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
            let s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
            w[t] = w[t - 16].wrapping_add(s0).wrapping_add(w[t - 7]).wrapping_add(s1);
        }
        let (mut a, mut b, mut c, mut d) = (h[0], h[1], h[2], h[3]);
        let (mut e, mut f, mut g, mut hh) = (h[4], h[5], h[6], h[7]);
        for t in 0..64 {
            let big1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
            let ch = (e & f) ^ ((e ^ 0xFFFFFFFF) & g);
            let t1 = hh
                .wrapping_add(big1)
                .wrapping_add(ch)
                .wrapping_add(K[t])
                .wrapping_add(w[t]);
            let big0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
            let maj = (a & b) ^ (a & c) ^ (b & c);
            let t2 = big0.wrapping_add(maj);
            hh = g;
            g = f;
            f = e;
            e = d.wrapping_add(t1);
            d = c;
            c = b;
            b = a;
            a = t1.wrapping_add(t2);
        }
        h[0] = h[0].wrapping_add(a);
        h[1] = h[1].wrapping_add(b);
        h[2] = h[2].wrapping_add(c);
        h[3] = h[3].wrapping_add(d);
        h[4] = h[4].wrapping_add(e);
        h[5] = h[5].wrapping_add(f);
        h[6] = h[6].wrapping_add(g);
        h[7] = h[7].wrapping_add(hh);
    }
    h[0] ^ h[1] ^ h[2] ^ h[3] ^ h[4] ^ h[5] ^ h[6] ^ h[7]
}

#[no_mangle]
pub extern "C" fn bench_popcount(scale: u32) -> u32 {
    let mut s: u32 = 55;
    let mut bits: u32 = 0;
    for _ in 0..600000 * scale {
        let mut x = lcg(&mut s);
        while x != 0 {
            x &= x - 1;
            bits += 1;
        }
    }
    bits
}

#[no_mangle]
pub extern "C" fn bench_mandelbrot_fixed(scale: u32) -> u32 {
    let mut total: u32 = 0;
    for _ in 0..6 * scale {
        for py in 0..96i32 {
            for px in 0..96i32 {
                let cr = -131072 + px * 2048;
                let ci = -98304 + py * 2048;
                let mut zr: i32 = 0;
                let mut zi: i32 = 0;
                let mut it: u32 = 0;
                while it < 40 {
                    let zr2 = ((zr as i64 * zr as i64) >> 16) as i32;
                    let zi2 = ((zi as i64 * zi as i64) >> 16) as i32;
                    if zr2 + zi2 > 262144 {
                        break;
                    }
                    zi = (((zr as i64 * zi as i64) >> 15) as i32) + ci;
                    zr = zr2 - zi2 + cr;
                    it += 1;
                }
                total = total.wrapping_add(it);
            }
        }
    }
    total
}

#[no_mangle]
pub extern "C" fn bench_bytecode_interpreter(scale: u32) -> u32 {
    // op, a, b, c
    const PROGRAM: [u32; 32] = [
        0, 0, 1, 2, //
        1, 1, 0, 3, //
        2, 2, 1, 1, //
        3, 3, 2, 0, //
        4, 0, 0, 7, //
        5, 1, 3, 0, //
        0, 2, 2, 0, //
        1, 3, 3, 1, //
    ];
    let mut reg: [u32; 4] = [1, 2, 3, 4];
    let mut pc: u32 = 0;
    for _ in 0..400000 * scale {
        let base = (pc * 4) as usize;
        let op = PROGRAM[base];
        let a = PROGRAM[base + 1] as usize;
        let b = PROGRAM[base + 2] as usize;
        let c = PROGRAM[base + 3];
        if op == 0 {
            reg[a] = reg[b].wrapping_add(reg[c as usize]);
        } else if op == 1 {
            reg[a] = reg[b] ^ reg[c as usize];
        } else if op == 2 {
            reg[a] = reg[b].wrapping_mul(reg[c as usize]);
        } else if op == 3 {
            reg[a] = reg[b] << 1;
        } else if op == 4 {
            reg[a] = reg[b].wrapping_add(c);
        } else {
            reg[a] = reg[b];
        }
        pc = if pc == 7 { 0 } else { pc + 1 };
    }
    reg[0] ^ reg[1] ^ reg[2] ^ reg[3]
}
