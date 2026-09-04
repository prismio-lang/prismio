use crate::common::{next_random, BenchTree, BENCH_MOD};

fn gcd_value(mut a: i32, mut b: i32) -> i32 {
    while b != 0 { let t = a % b; a = b; b = t; }
    a
}

pub fn fibonacci(scale: i32) -> i32 {
    let mut a = 1; let mut b = 1; let mut checksum = 0;
    for _ in 0..1_000_000 * scale {
        let c = (a + b) % 1_000_003;
        a = b; b = c; checksum = (checksum + c) % BENCH_MOD;
    }
    checksum
}

pub fn prime_sieve(scale: i32) -> i32 {
    let n = 100_000 * scale;
    let mut prime = vec![true; (n + 1) as usize]; prime[0] = false; prime[1] = false;
    let mut p = 2;
    while p * p <= n {
        if prime[p as usize] { let mut multiple = p * p; while multiple <= n { prime[multiple as usize] = false; multiple += p; } }
        p += 1;
    }
    let mut count = 0; let mut sum = 0;
    for i in 2..=n { if prime[i as usize] { count += 1; sum = (sum + i) % BENCH_MOD; } }
    (sum + count) % BENCH_MOD
}

pub fn gcd_lcm(scale: i32) -> i32 {
    let mut checksum = 0;
    for i in 1..=300_000 * scale {
        let a = i % 30_000 + 1; let b = (i * 17) % 30_000 + 1;
        let g = gcd_value(a, b); let l = (a / g) * b;
        checksum = (checksum + g + l) % BENCH_MOD;
    }
    checksum
}

pub fn binary_search_work(scale: i32) -> i32 {
    let n = 100_000 * scale; let queries = 500_000 * scale;
    let values: Vec<i32> = (0..n).map(|i| i * 2).collect();
    let mut found = 0; let mut seed = 7;
    for _ in 0..queries {
        seed = next_random(seed); let needle = seed % (n * 2);
        let mut low = 0; let mut high = n - 1; let mut hit = false;
        while low <= high {
            let mid = low + (high - low) / 2; let value = values[mid as usize];
            if value == needle { hit = true; low = high + 1; }
            else if value < needle { low = mid + 1; } else { high = mid - 1; }
        }
        if hit { found += 1; }
    }
    found
}

fn quick_range(values: &mut [i32], low: i32, high: i32) {
    if low >= high { return; }
    let pivot = values[(low + (high - low) / 2) as usize]; let mut i = low; let mut j = high;
    while i <= j {
        while values[i as usize] < pivot { i += 1; }
        while values[j as usize] > pivot { j -= 1; }
        if i <= j { values.swap(i as usize, j as usize); i += 1; j -= 1; }
    }
    if low < j { quick_range(values, low, j); }
    if i < high { quick_range(values, i, high); }
}

fn random_values(n: i32) -> Vec<i32> {
    let mut values = Vec::with_capacity(n as usize); let mut seed = 19;
    for _ in 0..n { seed = next_random(seed); values.push(seed); }
    values
}

fn sorted_checksum(values: &[i32]) -> i32 {
    let mut checksum = 0; let mut i = 0;
    while i < values.len() { checksum = (checksum + values[i]) % BENCH_MOD; i += 97; }
    checksum + values[values.len() - 1]
}

pub fn quicksort_work(scale: i32) -> i32 {
    let mut values = random_values(25_000 * scale); let high = values.len() as i32 - 1;
    quick_range(&mut values, 0, high); sorted_checksum(&values)
}

fn merge_range(values: &mut [i32], scratch: &mut [i32], low: usize, high: usize) {
    if high - low <= 1 { return; }
    let mid = low + (high - low) / 2;
    merge_range(values, scratch, low, mid); merge_range(values, scratch, mid, high);
    let mut left = low; let mut right = mid; let mut out = low;
    while left < mid && right < high {
        if values[left] <= values[right] { scratch[out] = values[left]; left += 1; }
        else { scratch[out] = values[right]; right += 1; }
        out += 1;
    }
    while left < mid { scratch[out] = values[left]; left += 1; out += 1; }
    while right < high { scratch[out] = values[right]; right += 1; out += 1; }
    values[low..high].copy_from_slice(&scratch[low..high]);
}

pub fn mergesort_work(scale: i32) -> i32 {
    let mut values = random_values(25_000 * scale); let mut scratch = vec![0; values.len()]; let len = values.len();
    merge_range(&mut values, &mut scratch, 0, len); sorted_checksum(&values)
}

pub fn string_search(scale: i32) -> i32 {
    let text = "alpha beta gamma delta needle omega ".repeat((2_000 * scale) as usize);
    let mut from = 0; let mut count = 0; let mut positions = 0;
    while let Some(relative) = text[from..].find("needle") {
        let at = from + relative; count += 1; positions = (positions + at as i32) % BENCH_MOD; from = at + 6;
    }
    positions + count
}

pub fn graph_bfs(scale: i32) -> i32 {
    let width = 120 * scale; let total = width * width;
    let mut seen = vec![false; total as usize]; let mut queue = Vec::with_capacity(total as usize);
    queue.push(0); seen[0] = true; let mut head = 0; let mut checksum = 0;
    while head < queue.len() {
        let node = queue[head]; head += 1; checksum = (checksum + node) % BENCH_MOD;
        let x = node % width; let y = node / width;
        let mut visit = |next: i32| { if !seen[next as usize] { seen[next as usize] = true; queue.push(next); } };
        if x > 0 { visit(node - 1); }
        if x + 1 < width { visit(node + 1); }
        if y > 0 { visit(node - width); }
        if y + 1 < width { visit(node + width); }
    }
    checksum + head as i32
}

pub fn knapsack(scale: i32) -> i32 {
    let capacity = 800 * scale; let mut best = vec![0; (capacity + 1) as usize];
    for i in 1..=180 {
        let weight = (i * 37) % 97 + 1; let value = (i * 53) % 211 + 1;
        for at in (weight..=capacity).rev() {
            best[at as usize] = best[at as usize].max(best[(at - weight) as usize] + value);
        }
    }
    best[capacity as usize]
}

fn build_tree(depth: i32, seed: i32) -> Option<Box<BenchTree>> {
    if depth == 0 { return None; }
    Some(Box::new(BenchTree { value: seed, left: build_tree(depth - 1, seed * 2), right: build_tree(depth - 1, seed * 2 + 1) }))
}

fn tree_sum(tree: Option<&BenchTree>) -> i32 {
    match tree {
        None => 0,
        Some(node) => ((tree_sum(node.left.as_deref()) + node.value) % BENCH_MOD + tree_sum(node.right.as_deref())) % BENCH_MOD,
    }
}

pub fn tree_traversal(scale: i32) -> i32 {
    let tree = build_tree(13 + scale / 4, 1); let mut checksum = 0;
    for _ in 0..8 * scale { checksum = (checksum + tree_sum(tree.as_deref())) % BENCH_MOD; }
    checksum
}
