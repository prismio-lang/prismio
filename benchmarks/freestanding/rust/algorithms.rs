use crate::lcg;

fn fib(n: u32) -> u32 {
    if n < 2 {
        return n;
    }
    fib(n - 1).wrapping_add(fib(n - 2))
}

#[no_mangle]
pub extern "C" fn bench_fibonacci(scale: u32) -> u32 {
    let mut total: u32 = 0;
    for _ in 0..scale {
        total = total.wrapping_add(fib(27));
    }
    total
}

const SIEVE: usize = 200000;

#[no_mangle]
pub extern "C" fn bench_prime_sieve(scale: u32) -> u32 {
    let mut total: u32 = 0;
    for _ in 0..scale {
        let mut flags = [0u8; SIEVE];
        let mut count: u32 = 0;
        let mut i = 2;
        while i < SIEVE {
            if flags[i] == 0 {
                count += 1;
                let mut j = i + i;
                while j < SIEVE {
                    flags[j] = 1;
                    j += i;
                }
            }
            i += 1;
        }
        total = total.wrapping_add(count);
    }
    total
}

fn gcd(mut a: u32, mut b: u32) -> u32 {
    while b != 0 {
        let t = a % b;
        a = b;
        b = t;
    }
    a
}

#[no_mangle]
pub extern "C" fn bench_gcd_lcm(scale: u32) -> u32 {
    let mut total: u32 = 0;
    for _ in 0..scale {
        let mut a = 1;
        while a <= 400 {
            let mut b = 1;
            while b <= 400 {
                total = total.wrapping_add(gcd(a, b));
                b += 1;
            }
            a += 1;
        }
    }
    total
}

const SEARCH: usize = 4096;

#[no_mangle]
pub extern "C" fn bench_binary_search(scale: u32) -> u32 {
    let mut table = [0u32; SEARCH];
    for i in 0..SEARCH {
        table[i] = (i as u32) * 7 + 3;
    }
    let mut s: u32 = 12345;
    let mut found: u32 = 0;
    let mut acc: u32 = 0;
    for _ in 0..100000u32.wrapping_mul(scale) {
        lcg(&mut s);
        let key = s % 30000;
        let mut lo: u32 = 0;
        let mut hi: u32 = SEARCH as u32;
        while lo < hi {
            let mid = (lo + hi) >> 1;
            if table[mid as usize] < key {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        if (lo as usize) < SEARCH && table[lo as usize] == key {
            found += 1;
            acc = acc.wrapping_add(lo);
        }
    }
    found.wrapping_add(acc.wrapping_mul(3))
}

const SORT: usize = 2048;

fn quick(a: &mut [u32; SORT], lo: i32, hi: i32) {
    if lo >= hi {
        return;
    }
    let p = a[((lo + hi) >> 1) as usize];
    let mut i = lo;
    let mut j = hi;
    while i <= j {
        while a[i as usize] < p {
            i += 1;
        }
        while a[j as usize] > p {
            j -= 1;
        }
        if i <= j {
            let t = a[i as usize];
            a[i as usize] = a[j as usize];
            a[j as usize] = t;
            i += 1;
            j -= 1;
        }
    }
    quick(a, lo, j);
    quick(a, i, hi);
}

#[no_mangle]
pub extern "C" fn bench_quicksort(scale: u32) -> u32 {
    let mut data = [0u32; SORT];
    let mut s: u32 = 777;
    let mut sum: u32 = 0;
    for _ in 0..40 * scale {
        for i in 0..SORT {
            data[i] = lcg(&mut s) >> 4;
        }
        quick(&mut data, 0, SORT as i32 - 1);
        for i in 0..SORT {
            sum = sum.wrapping_add(data[i].wrapping_mul(i as u32 + 1));
        }
    }
    sum
}

fn sift(a: &mut [u32; SORT], start: i32, end: i32) {
    let mut root = start;
    while root * 2 + 1 <= end {
        let child = root * 2 + 1;
        let mut pick = root;
        if a[pick as usize] < a[child as usize] {
            pick = child;
        }
        if child + 1 <= end && a[pick as usize] < a[(child + 1) as usize] {
            pick = child + 1;
        }
        if pick == root {
            return;
        }
        let t = a[root as usize];
        a[root as usize] = a[pick as usize];
        a[pick as usize] = t;
        root = pick;
    }
}

#[no_mangle]
pub extern "C" fn bench_heapsort(scale: u32) -> u32 {
    let mut data = [0u32; SORT];
    let mut s: u32 = 4242;
    let mut sum: u32 = 0;
    for _ in 0..24 * scale {
        for i in 0..SORT {
            data[i] = lcg(&mut s) >> 4;
        }
        let mut start = (SORT as i32 - 2) / 2;
        while start >= 0 {
            sift(&mut data, start, SORT as i32 - 1);
            start -= 1;
        }
        let mut end = SORT as i32 - 1;
        while end > 0 {
            let t = data[0];
            data[0] = data[end as usize];
            data[end as usize] = t;
            sift(&mut data, 0, end - 1);
            end -= 1;
        }
        for i in 0..SORT {
            sum = sum.wrapping_add(data[i].wrapping_mul(i as u32 + 1));
        }
    }
    sum
}

const ITEMS: usize = 64;
const CAPACITY: usize = 1500;

#[no_mangle]
pub extern "C" fn bench_knapsack(scale: u32) -> u32 {
    let mut weight = [0i32; ITEMS];
    let mut value = [0i32; ITEMS];
    let mut s: u32 = 99;
    for i in 0..ITEMS {
        weight[i] = ((lcg(&mut s) >> 8) % 37) as i32 + 3;
        value[i] = ((lcg(&mut s) >> 8) % 97) as i32 + 1;
    }
    let mut total: u32 = 0;
    for _ in 0..6 * scale {
        let mut best = [0i32; CAPACITY + 1];
        for i in 0..ITEMS {
            let w = weight[i];
            let v = value[i];
            let mut c = CAPACITY as i32;
            while c >= w {
                best[c as usize] = best[c as usize].max(best[(c - w) as usize] + v);
                c -= 1;
            }
        }
        total = total.wrapping_add(best[CAPACITY] as u32);
    }
    total
}

const STRING: usize = 600;

#[no_mangle]
pub extern "C" fn bench_edit_distance(scale: u32) -> u32 {
    let mut a = [0u8; STRING];
    let mut b = [0u8; STRING];
    let mut s: u32 = 31337;
    for i in 0..STRING {
        a[i] = ((lcg(&mut s) >> 12) & 3) as u8;
    }
    for i in 0..STRING {
        b[i] = ((lcg(&mut s) >> 12) & 3) as u8;
    }
    let mut total: u32 = 0;
    for _ in 0..scale {
        let mut prev = [0i32; STRING + 1];
        let mut cur = [0i32; STRING + 1];
        for j in 0..=STRING {
            prev[j] = j as i32;
        }
        for i in 1..=STRING {
            cur[0] = i as i32;
            for j in 1..=STRING {
                let cost = if a[i - 1] == b[j - 1] { 0 } else { 1 };
                cur[j] = (prev[j] + 1).min(cur[j - 1] + 1).min(prev[j - 1] + cost);
            }
            for j in 0..=STRING {
                prev[j] = cur[j];
            }
        }
        total = total.wrapping_add(prev[STRING] as u32);
    }
    total
}

const MATRIX: usize = 64;

#[no_mangle]
pub extern "C" fn bench_matrix_multiply(scale: u32) -> u32 {
    let mut a = [0u32; MATRIX * MATRIX];
    let mut b = [0u32; MATRIX * MATRIX];
    let mut c = [0u32; MATRIX * MATRIX];
    for i in 0..MATRIX {
        for j in 0..MATRIX {
            a[i * MATRIX + j] = ((i * 3 + j * 5) % 17) as u32;
            b[i * MATRIX + j] = ((i * 7 + j * 2) % 13) as u32;
        }
    }
    let mut total: u32 = 0;
    for r in 0..8 * scale {
        for i in 0..MATRIX {
            for j in 0..MATRIX {
                let mut sum: u32 = 0;
                for k in 0..MATRIX {
                    sum = sum.wrapping_add(a[i * MATRIX + k].wrapping_mul(b[k * MATRIX + j]));
                }
                c[i * MATRIX + j] = sum;
            }
        }
        for i in 0..MATRIX * MATRIX {
            total = total.wrapping_add(c[i]);
        }
        a[(r % 64) as usize] += 1;
    }
    total
}
