use std::sync::mpsc::sync_channel;
use std::thread;

use crate::common::{next_random, BENCH_MOD};

struct Particle { x: f64, y: f64, vx: f64, vy: f64, life: i32 }

pub fn matrix_multiply(scale: i32) -> i32 {
    let n = 32 * scale; let count = n * n; let mut a = Vec::with_capacity(count as usize); let mut b = Vec::with_capacity(count as usize);
    for i in 0..count { a.push((i * 17) % 101); b.push((i * 29) % 103); }
    let mut c = vec![0; count as usize];
    for row in 0..n { for col in 0..n { let mut sum = 0; for k in 0..n { sum = (sum + a[(row*n+k) as usize] * b[(k*n+col) as usize]) % BENCH_MOD; } c[(row*n+col) as usize] = sum; } }
    c.into_iter().fold(0, |sum, value| (sum + value) % BENCH_MOD)
}

pub fn mandelbrot(scale: i32) -> i32 {
    let side = 96 * scale; let mut inside = 0;
    for py in 0..side { let cy = py as f64 * 2.0 / side as f64 - 1.0; for px in 0..side {
        let cx = px as f64 * 3.0 / side as f64 - 2.0; let mut x = 0.0; let mut y = 0.0; let mut iter = 0;
        while x*x + y*y <= 4.0 && iter < 60 { let next_x = x*x - y*y + cx; y = 2.0*x*y + cy; x = next_x; iter += 1; }
        if iter == 60 { inside += 1; }
    }}
    inside
}

fn fft_transform(real:&mut [f64],imag:&mut [f64]){
    let n=real.len();let mut j=0;
    for i in 1..n{let mut bit=n/2;while j>=bit{j-=bit;bit/=2;}j+=bit;if i<j{real.swap(i,j);imag.swap(i,j);}}
    let mut length=2;while length<=n{let angle=-6.283185307179586/(length as f64);let step_real=angle.cos();let step_imag=angle.sin();let half=length/2;
        for block in (0..n).step_by(length){let mut weight_real=1.0;let mut weight_imag=0.0;for offset in 0..half{let left=block+offset;let right=left+half;
            let value_real=real[right]*weight_real-imag[right]*weight_imag;let value_imag=real[right]*weight_imag+imag[right]*weight_real;let left_real=real[left];let left_imag=imag[left];
            real[left]=left_real+value_real;imag[left]=left_imag+value_imag;real[right]=left_real-value_real;imag[right]=left_imag-value_imag;
            let next_real=weight_real*step_real-weight_imag*step_imag;weight_imag=weight_real*step_imag+weight_imag*step_real;weight_real=next_real;}}
        length*=2;
    }
}

pub fn fft(scale:i32)->i32{
    let n=if scale==12{16384}else{(1024*scale) as usize};let rounds=20*scale;let mut real=vec![0.0;n];let mut imag=vec![0.0;n];let mut checksum=0;
    for _ in 0..rounds{real.fill(1.0);imag.fill(0.0);fft_transform(&mut real,&mut imag);checksum+=real[0] as i32;}checksum
}

pub fn numerical_integration(scale: i32) -> i32 {
    let steps = 1_000_000 * scale; let width = 1.0 / steps as f64; let mut sum = 0.0;
    for i in 0..steps { let x = (i as f64 + 0.5) * width; sum += 4.0 / (1.0 + x*x); }
    (sum * width * 100_000_000.0) as i32
}

pub fn vector_dot(scale: i32) -> i32 {
    let n = 1_000_000 * scale; let a: Vec<i32> = (0..n).map(|i| i % 101).collect(); let b: Vec<i32> = (0..n).map(|i| (i*3) % 103).collect();
    let mut sum = 0; for i in 0..n as usize { sum = (sum + a[i] * b[i]) % BENCH_MOD; } sum
}

pub fn convolution(scale: i32) -> i32 {
    let n = 300_000 * scale; let input: Vec<i32> = (0..n).map(|i| i % 251).collect(); let mut output = vec![0; n as usize];
    for at in 3..n-3 { output[at as usize] = input[(at-3) as usize] + 2*input[(at-2) as usize] + 3*input[(at-1) as usize] + 4*input[at as usize] + 3*input[(at+1) as usize] + 2*input[(at+2) as usize] + input[(at+3) as usize]; }
    output.into_iter().fold(0, |sum, value| (sum + value) % BENCH_MOD)
}

pub fn monte_carlo(scale: i32) -> i32 {
    let mut seed = 31; let mut inside = 0;
    for _ in 0..2_000_000*scale { seed = next_random(seed); let x = seed % 10_000; seed = next_random(seed); let y = seed % 10_000; if x*x + y*y <= 100_000_000 { inside += 1; } }
    inside
}

pub fn polynomial_evaluation(scale: i32) -> i32 {
    let mut checksum = 0;
    for i in 0..2_000_000*scale { let x = i % 97; let mut value = 3; for coefficient in [5,7,11,13,17] { value = (value*x + coefficient) % 1_000_003; } checksum = (checksum + value) % BENCH_MOD; }
    checksum
}

pub fn ecs_component_update(scale: i32) -> i32 {
    let n = 50_000 * scale; let mut particles = Vec::with_capacity(n as usize);
    for i in 0..n { particles.push(Particle { x:(i%1000) as f64, y:(i%500) as f64, vx:(i%7+1) as f64, vy:(i%11+1) as f64, life:100 }); }
    for _ in 0..20 { for p in &mut particles { p.x += p.vx*0.016; p.y += p.vy*0.016; p.life -= 1; } }
    particles.into_iter().fold(0, |sum,p| (sum + p.x as i32 + p.y as i32 + p.life) % BENCH_MOD)
}

fn band_sum(mut seed: i32, steps: i32) -> i32 {
    let mut sum = 0; for _ in 0..steps { seed = next_random(seed); sum = (sum + seed) % BENCH_MOD; } sum
}

pub fn parallel_reduction(scale: i32) -> i32 {
    let steps = 500_000 * scale; let mut workers = Vec::new();
    for seed in [1,101,1001,10001] { workers.push(thread::spawn(move || band_sum(seed, steps))); }
    let results: Vec<i32> = workers.into_iter().map(|worker| worker.join().unwrap()).collect();
    (((results[0] + results[1]) % BENCH_MOD) + ((results[2] + results[3]) % BENCH_MOD)) % BENCH_MOD
}

pub fn sha256(scale: i32) -> i32 {
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

    let mut h0: u32 = 0x6a09e667; let mut h1: u32 = 0xbb67ae85;
    let mut h2: u32 = 0x3c6ef372; let mut h3: u32 = 0xa54ff53a;
    let mut h4: u32 = 0x510e527f; let mut h5: u32 = 0x9b05688c;
    let mut h6: u32 = 0x1f83d9ab; let mut h7: u32 = 0x5be0cd19;

    let total_blocks = 200 * scale;
    let mut seed = 42;
    let mut w = [0u32; 64];

    for _ in 0..total_blocks {
        for i in 0..16 {
            seed = next_random(seed);
            let v1 = seed as u32;
            seed = next_random(seed);
            let v2 = seed as u32;
            w[i] = (v1 << 16) | v2;
        }

        for t in 16..64 {
            let s0 = w[t - 15].rotate_right(7) ^ w[t - 15].rotate_right(18) ^ (w[t - 15] >> 3);
            let s1 = w[t - 2].rotate_right(17) ^ w[t - 2].rotate_right(19) ^ (w[t - 2] >> 10);
            w[t] = w[t - 16].wrapping_add(s0).wrapping_add(w[t - 7]).wrapping_add(s1);
        }

        let mut a = h0; let mut b_val = h1; let mut c = h2; let mut d = h3;
        let mut e = h4; let mut f = h5; let mut g = h6; let mut h = h7;

        for step in 0..64 {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let ch = (e & f) ^ ((!e) & g);
            let temp1 = h.wrapping_add(s1).wrapping_add(ch).wrapping_add(K[step]).wrapping_add(w[step]);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let maj = (a & b_val) ^ (a & c) ^ (b_val & c);
            let temp2 = s0.wrapping_add(maj);

            h = g; g = f; f = e; e = d.wrapping_add(temp1);
            d = c; c = b_val; b_val = a; a = temp1.wrapping_add(temp2);
        }

        h0 = h0.wrapping_add(a); h1 = h1.wrapping_add(b_val);
        h2 = h2.wrapping_add(c); h3 = h3.wrapping_add(d);
        h4 = h4.wrapping_add(e); h5 = h5.wrapping_add(f);
        h6 = h6.wrapping_add(g); h7 = h7.wrapping_add(h);
    }

    ((h0 ^ h1 ^ h2 ^ h3 ^ h4 ^ h5 ^ h6 ^ h7) & 0x7fffffff) as i32
}

pub fn blake3_chunk(scale: i32) -> i32 {
    const IV: [u32; 8] = [
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
        0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
    ];
    const MSG_PERM: [usize; 16] = [
        2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8,
    ];

    let total_chunks = 300 * scale;
    let mut seed = 99;
    let mut total_checksum: u32 = 0;

    let mut m = [0u32; 16];
    let mut v = [0u32; 16];
    let mut next_m = [0u32; 16];

    let g_step = |v: &mut [u32; 16], a: usize, b: usize, c: usize, d: usize, mx: u32, my: u32| {
        v[a] = v[a].wrapping_add(v[b]).wrapping_add(mx);
        v[d] = (v[d] ^ v[a]).rotate_right(16);
        v[c] = v[c].wrapping_add(v[d]);
        v[b] = (v[b] ^ v[c]).rotate_right(12);
        v[a] = v[a].wrapping_add(v[b]).wrapping_add(my);
        v[d] = (v[d] ^ v[a]).rotate_right(8);
        v[c] = v[c].wrapping_add(v[d]);
        v[b] = (v[b] ^ v[c]).rotate_right(7);
    };

    for chunk in 0..total_chunks {
        for i in 0..16 {
            seed = next_random(seed);
            let v1 = seed as u32;
            seed = next_random(seed);
            let v2 = seed as u32;
            m[i] = (v1 << 16) | v2;
        }

        v[0..8].copy_from_slice(&IV);
        v[8..12].copy_from_slice(&IV[0..4]);
        v[12] = chunk as u32;
        v[13] = 0;
        v[14] = 1024;
        v[15] = 0;

        for _ in 0..7 {
            g_step(&mut v, 0, 4, 8,  12, m[0], m[1]);
            g_step(&mut v, 1, 5, 9,  13, m[2], m[3]);
            g_step(&mut v, 2, 6, 10, 14, m[4], m[5]);
            g_step(&mut v, 3, 7, 11, 15, m[6], m[7]);

            g_step(&mut v, 0, 5, 10, 15, m[8],  m[9]);
            g_step(&mut v, 1, 6, 11, 12, m[10], m[11]);
            g_step(&mut v, 2, 7, 8,  13, m[12], m[13]);
            g_step(&mut v, 3, 4, 9,  14, m[14], m[15]);

            for i in 0..16 { next_m[i] = m[MSG_PERM[i]]; }
            m.copy_from_slice(&next_m);
        }

        let mut chunk_hash = 0u32;
        for i in 0..8 { chunk_hash ^= v[i] ^ v[i + 8]; }
        total_checksum = (total_checksum.wrapping_mul(31).wrapping_add(chunk_hash)) & 0x7fffffff;
    }

    total_checksum as i32
}

struct BenchSphere {
    x: f64, y: f64, z: f64, r: f64,
    cr: i32, cg: i32, cb: i32,
}

pub fn raytracer_sphere(scale: i32) -> i32 {
    let width = 50 * scale;
    let height = 50 * scale;

    let spheres = [
        BenchSphere { x: 0.0, y: 0.0, z: 3.0, r: 1.0, cr: 255, cg: 30, cb: 30 },
        BenchSphere { x: 2.0, y: 1.0, z: 4.0, r: 1.0, cr: 30, cg: 255, cb: 30 },
        BenchSphere { x: -2.0, y: 1.0, z: 4.0, r: 1.0, cr: 30, cg: 30, cb: 255 },
        BenchSphere { x: 0.0, y: -1001.0, z: 0.0, r: 1000.0, cr: 200, cg: 200, cb: 200 },
    ];

    let light_x = -10.0;
    let light_y = 20.0;
    let light_z = -10.0;

    let cam_x = 0.0;
    let cam_y = 0.0;
    let cam_z = -5.0;

    let mut checksum: i64 = 0;

    for py in 0..height {
        let screen_y = -(((py as f64 + 0.5) / height as f64) * 2.0 - 1.0);
        for px in 0..width {
            let screen_x = ((px as f64 + 0.5) / width as f64) * 2.0 - 1.0;
            let mut dir_x = screen_x;
            let mut dir_y = screen_y;
            let mut dir_z = 2.0;
            let inv_len = 1.0 / (dir_x * dir_x + dir_y * dir_y + dir_z * dir_z).sqrt();
            dir_x *= inv_len;
            dir_y *= inv_len;
            dir_z *= inv_len;

            let mut closest_t = 1e30;
            let mut hit_idx = -1;
            for (s, sph) in spheres.iter().enumerate() {
                let oc_x = cam_x - sph.x;
                let oc_y = cam_y - sph.y;
                let oc_z = cam_z - sph.z;
                let b = oc_x * dir_x + oc_y * dir_y + oc_z * dir_z;
                let c = (oc_x * oc_x + oc_y * oc_y + oc_z * oc_z) - sph.r * sph.r;
                let disc = b * b - c;
                if disc > 0.0 {
                    let t = -b - disc.sqrt();
                    if t > 0.001 && t < closest_t {
                        closest_t = t;
                        hit_idx = s as i32;
                    }
                }
            }

            if hit_idx >= 0 {
                let sph = &spheres[hit_idx as usize];
                let hx = cam_x + closest_t * dir_x;
                let hy = cam_y + closest_t * dir_y;
                let hz = cam_z + closest_t * dir_z;

                let nx = (hx - sph.x) / sph.r;
                let ny = (hy - sph.y) / sph.r;
                let nz = (hz - sph.z) / sph.r;

                let mut lx = light_x - hx;
                let mut ly = light_y - hy;
                let mut lz = light_z - hz;
                let ldist = (lx * lx + ly * ly + lz * lz).sqrt();
                lx /= ldist;
                ly /= ldist;
                lz /= ldist;

                let sh_ox = hx + nx * 0.001;
                let sh_oy = hy + ny * 0.001;
                let sh_oz = hz + nz * 0.001;
                let mut in_shadow = false;
                for sph in spheres.iter() {
                    let oc_x = sh_ox - sph.x;
                    let oc_y = sh_oy - sph.y;
                    let oc_z = sh_oz - sph.z;
                    let b = oc_x * lx + oc_y * ly + oc_z * lz;
                    let c = (oc_x * oc_x + oc_y * oc_y + oc_z * oc_z) - sph.r * sph.r;
                    let disc = b * b - c;
                    if disc > 0.0 {
                        let t = -b - disc.sqrt();
                        if t > 0.001 && t < ldist {
                            in_shadow = true;
                            break;
                        }
                    }
                }

                let mut dot = nx * lx + ny * ly + nz * lz;
                if dot < 0.0 { dot = 0.0; }
                let diff = if in_shadow { 0.0 } else { dot * 0.85 };
                let intensity = 0.15 + diff;

                let mut r = (sph.cr as f64 * intensity) as i32;
                let mut g = (sph.cg as f64 * intensity) as i32;
                let mut b_col = (sph.cb as f64 * intensity) as i32;
                if r > 255 { r = 255; }
                if g > 255 { g = 255; }
                if b_col > 255 { b_col = 255; }

                let pix_val = (r as i64) * 65537 + (g as i64) * 257 + (b_col as i64);
                checksum = (checksum * 31 + pix_val) % BENCH_MOD as i64;
            } else {
                checksum = (checksum * 31 + 17) % BENCH_MOD as i64;
            }
        }
    }
    checksum as i32
}

pub fn channel_pipeline(scale: i32) -> i32 {
    let count = 5000 * scale;
    let (tx1, rx1) = sync_channel(64);
    let (tx2, rx2) = sync_channel(64);

    let w1 = thread::spawn(move || {
        for i in 0..count {
            let x = ((i as i64 * 25173 + 13849) % 65521) as i32;
            let _ = tx1.send(x);
        }
    });

    let w2 = thread::spawn(move || {
        while let Ok(x) = rx1.recv() {
            let y = ((x as i64 * 17 + 31) % BENCH_MOD as i64) as i32;
            let _ = tx2.send(y);
        }
    });

    let mut checksum: i64 = 0;
    while let Ok(y) = rx2.recv() {
        checksum = (checksum * 31 + y as i64) % BENCH_MOD as i64;
    }

    let _ = w1.join();
    let _ = w2.join();

    checksum as i32
}

pub fn bytecode_interpreter(scale: i32) -> i32 {
    let program = 4096;
    let mut ops: Vec<i32> = Vec::with_capacity(program);
    let mut args: Vec<i32> = Vec::with_capacity(program);
    let mut seed = 11;
    for _ in 0..program {
        seed = next_random(seed);
        ops.push(seed % 6);
        args.push((seed % 251) + 1);
    }

    let mut stack: Vec<i32> = vec![0; 64];
    let mut accumulator = 0;
    let mut top: i32 = 0;
    let rounds = 900 * scale;
    for _ in 0..rounds {
        let mut pc = 0;
        while pc < program as i32 {
            let op = ops[pc as usize];
            let argument = args[pc as usize];
            if op == 0 {
                if top < 63 { stack[top as usize] = argument; top += 1; }
            } else if op == 1 {
                if top > 1 {
                    let b = stack[(top - 1) as usize];
                    let a = stack[(top - 2) as usize];
                    stack[(top - 2) as usize] = (a + b) % 46337;
                    top -= 1;
                }
            } else if op == 2 {
                if top > 1 {
                    let b = stack[(top - 1) as usize];
                    let a = stack[(top - 2) as usize];
                    stack[(top - 2) as usize] = (a * b) % 46337;
                    top -= 1;
                }
            } else if op == 3 {
                if top > 0 { top -= 1; accumulator = (accumulator + stack[top as usize]) % BENCH_MOD; }
            } else if op == 4 {
                if top > 0 { stack[(top - 1) as usize] = (stack[(top - 1) as usize] ^ argument) % 46337; }
            } else if top > 0 && stack[(top - 1) as usize] % 2 == 0 {
                pc += 1;
            }
            pc += 1;
        }
    }
    (accumulator + top) % BENCH_MOD
}
