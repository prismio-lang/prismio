use std::cmp::Reverse;
use std::collections::BinaryHeap;

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

pub fn dijkstra_shortest_path(scale: i32) -> i32 {
    let v_count = 1000 * scale;
    let e_count = v_count + 5000 * scale;

    let mut head = vec![-1i32; v_count as usize];
    let mut edge_to = vec![0i32; e_count as usize];
    let mut edge_weight = vec![0i32; e_count as usize];
    let mut edge_next = vec![0i32; e_count as usize];

    let mut edge_idx = 0;
    for ri in 0..v_count {
        edge_to[edge_idx as usize] = (ri + 1) % v_count;
        edge_weight[edge_idx as usize] = (ri % 30) + 1;
        edge_next[edge_idx as usize] = head[ri as usize];
        head[ri as usize] = edge_idx;
        edge_idx += 1;
    }

    let mut seed = 47;
    while edge_idx < e_count {
        seed = next_random(seed);
        let u = seed % v_count;
        seed = next_random(seed);
        let v = seed % v_count;
        seed = next_random(seed);
        let w = (seed % 50) + 1;

        edge_to[edge_idx as usize] = v;
        edge_weight[edge_idx as usize] = w;
        edge_next[edge_idx as usize] = head[u as usize];
        head[u as usize] = edge_idx;
        edge_idx += 1;
    }

    const INF: i32 = 1000000000;
    let mut dist = vec![INF; v_count as usize];
    dist[0] = 0;

    let mut pq = BinaryHeap::new();
    pq.push(Reverse((0i32, 0i32))); // (dist, u)

    while let Some(Reverse((d, u))) = pq.pop() {
        if d > dist[u as usize] {
            continue;
        }

        let mut e = head[u as usize];
        while e != -1 {
            let v = edge_to[e as usize];
            let alt = d + edge_weight[e as usize];
            if alt < dist[v as usize] {
                dist[v as usize] = alt;
                pq.push(Reverse((alt, v)));
            }
            e = edge_next[e as usize];
        }
    }

    let mut checksum: i64 = 0;
    for i in 0..v_count {
        let d = dist[i as usize];
        if d < INF {
            let term = (d as i64 * (i as i64 % 100 + 1)) % BENCH_MOD as i64;
            checksum = (checksum + term) % BENCH_MOD as i64;
        }
    }
    checksum as i32
}

pub fn lz4_compress(scale: i32) -> i32 {
    let n = 20000 * scale;
    let mut input = Vec::with_capacity(n as usize);

    let mut seed = 83;
    for i in 0..n {
        seed = next_random(seed);
        if i > 20 && (seed % 4) == 0 {
            let offset = 12 + (seed % 8);
            input.push(input[(i - offset) as usize]);
        } else {
            input.push((32 + (seed % 95)) as u8);
        }
    }

    let mut table = vec![-1i32; 4096];
    let mut pos = 0usize;
    let mut token_count = 0i64;
    let mut literal_len = 0i64;
    let mut checksum: i64 = 0;

    while pos + 4 <= n as usize {
        let b0 = input[pos] as i32;
        let b1 = input[pos + 1] as i32;
        let b2 = input[pos + 2] as i32;
        let b3 = input[pos + 3] as i32;

        let h = (((b0 << 12) ^ (b1 << 8) ^ (b2 << 4) ^ b3) % 4096) as usize;
        let ref_pos = table[h];
        table[h] = pos as i32;

        if ref_pos != -1 && (pos as i32 - ref_pos) < 65535 {
            let rpos = ref_pos as usize;
            if input[rpos] as i32 == b0 && input[rpos + 1] as i32 == b1 &&
               input[rpos + 2] as i32 == b2 && input[rpos + 3] as i32 == b3 {

                let mut match_len = 4usize;
                while pos + match_len < n as usize && input[pos + match_len] == input[rpos + match_len] && match_len < 255 {
                    match_len += 1;
                }

                let offset = (pos as i32 - ref_pos) as i64;
                let term = literal_len * 10007 + match_len as i64 * 31 + offset;
                checksum = (checksum * 31 + term) % BENCH_MOD as i64;
                token_count += 1;
                literal_len = 0;
                pos += match_len;
                continue;
            }
        }

        literal_len += 1;
        pos += 1;
    }

    checksum = (checksum + token_count + literal_len) % BENCH_MOD as i64;
    checksum as i32
}

fn build_one_sexpr(depth: i32, seed: &mut i32) -> String {
    if depth <= 0 {
        *seed = next_random(*seed);
        return ((*seed % 100) + 1).to_string();
    }
    *seed = next_random(*seed);
    let op = match *seed % 3 {
        1 => '-',
        2 => '*',
        _ => '+',
    };
    let left = build_one_sexpr(depth - 1, seed);
    let right = build_one_sexpr(depth - 1, seed);
    format!("({} {} {})", op, left, right)
}

struct SExprAST {
    tag: i32,
    val: i32,
    left: Option<Box<SExprAST>>,
    right: Option<Box<SExprAST>>,
}

fn parse_sexpr_ast(s: &[u8], pos: &mut usize) -> Option<SExprAST> {
    let n = s.len();
    while *pos < n && (s[*pos] == b' ' || s[*pos] == b'\n') {
        *pos += 1;
    }
    if *pos >= n {
        return None;
    }
    if s[*pos] == b'(' {
        *pos += 1;
        while *pos < n && s[*pos] == b' ' {
            *pos += 1;
        }
        let op = s[*pos] as i32;
        *pos += 1;
        let left = parse_sexpr_ast(s, pos);
        let right = parse_sexpr_ast(s, pos);
        while *pos < n && s[*pos] == b' ' {
            *pos += 1;
        }
        if *pos < n && s[*pos] == b')' {
            *pos += 1;
        }
        Some(SExprAST {
            tag: 1,
            val: op,
            left: left.map(Box::new),
            right: right.map(Box::new),
        })
    } else {
        let mut num = 0;
        while *pos < n && s[*pos] >= b'0' && s[*pos] <= b'9' {
            num = num * 10 + (s[*pos] - b'0') as i32;
            *pos += 1;
        }
        Some(SExprAST {
            tag: 0,
            val: num,
            left: None,
            right: None,
        })
    }
}

fn eval_sexpr_ast(e: &SExprAST) -> i32 {
    if e.tag == 0 {
        return e.val;
    }
    let left = eval_sexpr_ast(e.left.as_ref().unwrap()) as i64;
    let right = eval_sexpr_ast(e.right.as_ref().unwrap()) as i64;
    if e.val == '+' as i32 {
        ((left + right) % BENCH_MOD as i64) as i32
    } else if e.val == '-' as i32 {
        ((left - right + BENCH_MOD as i64) % BENCH_MOD as i64) as i32
    } else {
        ((left * right) % BENCH_MOD as i64) as i32
    }
}

pub fn s_expression_parse(scale: i32) -> i32 {
    let count = 400 * scale;
    let mut all_text = String::with_capacity((count * 60) as usize);
    let mut seed = 42;
    for _ in 0..count {
        all_text.push_str(&build_one_sexpr(4, &mut seed));
        all_text.push('\n');
    }

    let bytes = all_text.as_bytes();
    let mut pos = 0;
    let mut checksum: i64 = 0;
    while pos < bytes.len() {
        if let Some(expr) = parse_sexpr_ast(bytes, &mut pos) {
            checksum = (checksum + eval_sexpr_ast(&expr) as i64) % BENCH_MOD as i64;
        }
    }
    checksum as i32
}
