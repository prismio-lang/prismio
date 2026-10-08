use std::collections::HashMap;

use crate::common::{next_random, BENCH_MOD};

pub fn hashmap_insert_lookup(scale: i32) -> i32 {
    let n = 50_000 * scale; let mut map = HashMap::new();
    for i in 0..n { map.insert(i, (i * 31) % 1_000_003); }
    let mut checksum = 0; let mut seed = 23;
    for _ in 0..n * 4 { seed = next_random(seed); checksum = (checksum + map[&(seed % n)]) % BENCH_MOD; }
    checksum + map.len() as i32
}

pub fn vector_growth(scale: i32) -> i32 {
    let n = 1_000_000 * scale; let mut values = Vec::new(); let mut checksum = 0;
    for i in 0..n { let value = i % 997; values.push(value); checksum = (checksum + value) % BENCH_MOD; }
    checksum + values.len() as i32
}

pub fn vector_iteration(scale: i32) -> i32 {
    let n = 1_000_000 * scale; let values: Vec<i32> = (0..n).map(|i| i % 1009).collect(); let mut checksum = 0;
    for _ in 0..8 { for value in &values { checksum = (checksum + *value) % BENCH_MOD; } }
    checksum
}

pub fn key_value_update(scale: i32) -> i32 {
    let n = 20_000 * scale; let mut map = HashMap::new();
    for i in 0..n { map.insert(i, i % 101); }
    for _ in 0..20 { for i in 0..n { *map.get_mut(&i).unwrap() += 1; } }
    let mut checksum = 0; for i in 0..n { checksum = (checksum + map[&i]) % BENCH_MOD; }
    checksum
}

// A third of the keys removed and reinserted each round, so every lookup after
// the first round probes past removed buckets.
pub fn mixed_map_removal(scale: i32) -> i32 {
    let n = 20_000 * scale; let mut map = HashMap::new();
    for i in 0..n { map.insert(i, i % 101); }
    let mut checksum = 0;
    for round in 0..10 {
        for i in 0..n { if (i + round) % 3 == 0 && map.remove(&i).is_some() { checksum = (checksum + 1) % BENCH_MOD; } }
        for i in 0..n { if (i + round) % 3 == 0 { map.insert(i, (i + round) % 101); } }
    }
    for i in 0..n { checksum = (checksum + map[&i]) % BENCH_MOD; }
    checksum
}

pub fn flat_bitset(scale: i32) -> i32 {
    let n = 50000 * scale;
    let words = ((n + 63) / 64) as usize;

    let mut a = vec![0u64; words];
    let mut b = vec![0u64; words];
    let mut c = vec![0u64; words];

    let mut seed = 77;
    for i in 0..n {
        seed = next_random(seed);
        let w_idx = (i / 64) as usize;
        let b_idx = i % 64;
        if seed % 3 == 0 {
            a[w_idx] |= 1u64 << b_idx;
        }
        seed = next_random(seed);
        if seed % 5 == 0 {
            b[w_idx] |= 1u64 << b_idx;
        }
    }

    const MAGIC: u64 = 0x0137F0268594B374u64;
    for _ in 0..10 {
        for w in 0..words {
            let aw = a[w];
            let bw = b[w];
            let cw = (aw & bw) | ((!aw) & (bw ^ MAGIC));
            c[w] = cw;
            a[w] = aw ^ cw;
            b[w] = bw.rotate_left(1);
        }
    }

    let mut count_a: i64 = 0;
    let mut count_b: i64 = 0;
    let mut count_c: i64 = 0;

    for w in 0..words {
        count_a += a[w].count_ones() as i64;
        count_b += b[w].count_ones() as i64;
        count_c += c[w].count_ones() as i64;
    }

    let checksum = (count_a * 10007 + count_b * 31 + count_c) % BENCH_MOD as i64;
    checksum as i32
}

pub fn trie_search(scale: i32) -> i32 {
    let num_keys = 8000 * scale;
    let num_queries = 15000 * scale;

    let mut c0 = vec![-1i32];
    let mut c1 = vec![-1i32];
    let mut c2 = vec![-1i32];
    let mut c3 = vec![-1i32];
    let mut counts = vec![0i32];

    let mut seed = 53;
    for _ in 0..num_keys {
        seed = next_random(seed);
        let len = 6 + (seed % 10);
        let mut curr = 0usize;
        for _ in 0..len {
            seed = next_random(seed);
            let branch = seed % 4;
            let next_node = match branch {
                0 => {
                    if c0[curr] == -1 {
                        let new_idx = c0.len() as i32;
                        c0.push(-1); c1.push(-1); c2.push(-1); c3.push(-1); counts.push(0);
                        c0[curr] = new_idx;
                    }
                    c0[curr]
                }
                1 => {
                    if c1[curr] == -1 {
                        let new_idx = c0.len() as i32;
                        c0.push(-1); c1.push(-1); c2.push(-1); c3.push(-1); counts.push(0);
                        c1[curr] = new_idx;
                    }
                    c1[curr]
                }
                2 => {
                    if c2[curr] == -1 {
                        let new_idx = c0.len() as i32;
                        c0.push(-1); c1.push(-1); c2.push(-1); c3.push(-1); counts.push(0);
                        c2[curr] = new_idx;
                    }
                    c2[curr]
                }
                _ => {
                    if c3[curr] == -1 {
                        let new_idx = c0.len() as i32;
                        c0.push(-1); c1.push(-1); c2.push(-1); c3.push(-1); counts.push(0);
                        c3[curr] = new_idx;
                    }
                    c3[curr]
                }
            };
            curr = next_node as usize;
        }
        counts[curr] += 1;
    }

    let mut checksum = 0i64;
    let mut q_seed = 101;
    for _ in 0..num_queries {
        q_seed = next_random(q_seed);
        let q_len = 3 + (q_seed % 8);
        let mut curr = 0usize;
        let mut found = true;
        for _ in 0..q_len {
            q_seed = next_random(q_seed);
            let branch = q_seed % 4;
            let next_node = match branch {
                0 => c0[curr],
                1 => c1[curr],
                2 => c2[curr],
                _ => c3[curr],
            };
            if next_node == -1 {
                found = false;
                break;
            }
            curr = next_node as usize;
        }
        if found {
            checksum = (checksum + curr as i64 * 31 + counts[curr] as i64 + 1) % BENCH_MOD as i64;
        }
    }

    checksum as i32
}
