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
