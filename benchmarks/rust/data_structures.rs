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
