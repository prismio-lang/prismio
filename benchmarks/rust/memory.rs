use crate::common::{BenchTree, BENCH_MOD};

#[derive(Clone)]
struct MemoryParticle { x: f64, y: f64, vx: f64, vy: f64, life: i32 }

fn build_memory_tree(depth: i32, seed: i32) -> Option<Box<BenchTree>> {
    if depth == 0 { return None; }
    Some(Box::new(BenchTree {
        value: seed,
        left: build_memory_tree(depth - 1, (seed * 3 + 1) % 1009),
        right: build_memory_tree(depth - 1, (seed * 5 + 7) % 1009),
    }))
}

fn memory_tree_sum(tree: Option<&BenchTree>) -> i32 {
    match tree {
        None => 0,
        Some(node) => (node.value + memory_tree_sum(node.left.as_deref()) + memory_tree_sum(node.right.as_deref())) % BENCH_MOD,
    }
}

pub fn transient_allocation(scale: i32) -> i32 {
    let mut checksum = 0;
    for r in 0..200*scale { let mut values = Vec::new(); for i in 0..4000 { values.push((i+r)%997); } checksum = (checksum + values[(r%4000) as usize]) % BENCH_MOD; }
    checksum
}

pub fn struct_creation(scale: i32) -> i32 {
    let n = 250_000 * scale; let mut particles = Vec::with_capacity(n as usize);
    for i in 0..n { particles.push(MemoryParticle{x:i as f64,y:(i%31) as f64,vx:1.0,vy:2.0,life:i%100}); }
    particles.into_iter().fold(0, |sum,p| (sum + p.x as i32 + p.life) % BENCH_MOD)
}

pub fn allocation_mutation(scale: i32) -> i32 {
    let n = 100_000 * scale; let mut particles = vec![MemoryParticle{x:0.0,y:0.0,vx:1.0,vy:2.0,life:50}; n as usize];
    for _ in 0..20 { for p in &mut particles { p.x += p.vx; p.y += p.vy; p.life -= 1; } }
    particles.into_iter().fold(0, |sum,p| (sum + p.x as i32 + p.y as i32 + p.life) % BENCH_MOD)
}

pub fn nested_collection(scale: i32) -> i32 {
    let count = 200 * scale; let mut buckets = Vec::with_capacity(count as usize);
    for b in 0..count { let mut values = Vec::with_capacity(1000); for i in 0..1000 { values.push((b+i)%1021); } buckets.push(values); }
    let mut checksum = 0; for bucket in buckets { for value in bucket { checksum = (checksum + value) % BENCH_MOD; } } checksum
}

pub fn large_buffer_copy(scale: i32) -> i32 {
    let n = 500_000 * scale; let source: Vec<i32> = (0..n).map(|i| i%4093).collect(); let mut target = vec![0; n as usize];
    for _ in 0..8 { for i in 0..n as usize { target[i] = source[i]; } }
    target.into_iter().fold(0, |sum,value| (sum+value)%BENCH_MOD)
}

fn tree_add(mut tree: Option<Box<BenchTree>>, amount: i32) -> Option<Box<BenchTree>> {
    if let Some(node) = tree.as_mut() { node.value += amount; node.left = tree_add(node.left.take(), amount); node.right = tree_add(node.right.take(), amount); }
    tree
}

pub fn recursive_tree_rebuild(scale: i32) -> i32 {
    let mut tree = build_memory_tree(12 + scale/4, 1); for _ in 0..4*scale { tree = tree_add(tree, 1); } memory_tree_sum(tree.as_deref())
}
