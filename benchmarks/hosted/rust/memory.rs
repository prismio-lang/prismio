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
    let n = 500_000 * scale;
    let source: Vec<i32> = (0..n).map(|i| i%4093).collect(); let mut target = vec![0; n as usize];
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

pub fn string_join(scale: i32) -> i32 {
    let n = 60000 * scale;
    let mut parts: Vec<String> = Vec::with_capacity(n as usize);
    for i in 0..n {
        let mut piece = String::with_capacity(16);
        piece.push_str("field");
        piece.push_str(&(i % 9973).to_string());
        parts.push(piece);
    }

    let joined = parts.join(",");
    let length = joined.len() as i32;
    let bytes = joined.as_bytes();

    let mut checksum = length % BENCH_MOD;
    let mut at = 0;
    while at < length {
        checksum = (checksum + bytes[at as usize] as i32) % BENCH_MOD;
        at += 997;
    }
    checksum
}

// std.mem's three tools, as the same programs in Rust (see memory.psm).
fn put_bytes<const N: usize>(buf: &mut [u8], off: usize, bytes: [u8; N]) {
    buf[off..off + N].copy_from_slice(&bytes);
}

fn get_bytes<const N: usize>(buf: &[u8], off: usize) -> [u8; N] {
    buf[off..off + N].try_into().unwrap()
}

pub fn binary_codec(scale: i32) -> i32 {
    let n = 100_000 * scale;
    let mut buf = vec![0u8; n as usize * 16];
    for i in 0..n {
        let off = (i * 16) as usize;
        put_bytes(&mut buf, off, (((i * 7) % 65536) as u16).to_be_bytes());
        put_bytes(&mut buf, off + 2, ((i * 13) % 100000 - 50000).to_be_bytes());
        put_bytes(&mut buf, off + 6, (((i % 1000) as f64) * 0.5).to_be_bytes());
        put_bytes(&mut buf, off + 14, ((i % 251) as u16).to_le_bytes());
    }
    let mut checksum = 0i32;
    for round in 0..8 {
        for i in 0..n {
            let off = (i * 16) as usize;
            let v = u16::from_be_bytes(get_bytes(&buf, off)) as i32
                + i32::from_be_bytes(get_bytes(&buf, off + 2))
                + f64::from_be_bytes(get_bytes(&buf, off + 6)) as i32
                + u16::from_le_bytes(get_bytes(&buf, off + 14)) as i32
                + round;
            checksum = (checksum + v) % BENCH_MOD;
        }
    }
    checksum
}

pub fn manual_alloc_churn(scale: i32) -> i32 {
    use std::alloc::{alloc, dealloc, Layout};
    let n = 400_000 * scale;
    let mut blocks = [std::ptr::null_mut::<u8>(); 64];
    let mut sizes = [0i32; 64];
    let mut checksum = 0i32;
    unsafe {
        for i in 0..n {
            let slot = (i % 64) as usize;
            let old = blocks[slot];
            if !old.is_null() {
                let first = (old as *const u32).read_unaligned() as i32;
                let second = (old.add(8) as *const u32).read_unaligned() as i32;
                checksum = (checksum + first + second + sizes[slot]) % BENCH_MOD;
                dealloc(old, Layout::from_size_align_unchecked(sizes[slot] as usize, 8));
            }
            let size = 16 + (i * 37) % 241;
            let block = alloc(Layout::from_size_align_unchecked(size as usize, 8));
            if block.is_null() { std::process::abort(); }
            (block as *mut u32).write_unaligned((i % 65521) as u32);
            (block.add(8) as *mut u32).write_unaligned(size as u32);
            blocks[slot] = block;
            sizes[slot] = size;
        }
        for slot in 0..64 {
            let old = blocks[slot];
            if !old.is_null() {
                checksum = (checksum + (old as *const u32).read_unaligned() as i32) % BENCH_MOD;
                dealloc(old, Layout::from_size_align_unchecked(sizes[slot] as usize, 8));
            }
        }
    }
    checksum
}

struct BumpArena { block: Vec<u8>, top: usize }

impl BumpArena {
    fn new(capacity: usize) -> Self { BumpArena { block: vec![0u8; capacity], top: 0 } }

    fn alloc(&mut self, size: usize, align: usize) -> usize {
        let base = self.block.as_mut_ptr() as usize;
        let mask = align - 1;
        let start = ((base + self.top + mask) & !mask) - base;
        if start > self.block.len() || self.block.len() - start < size { std::process::abort(); }
        self.top = start + size;
        base + start
    }
}

pub fn arena_bump(scale: i32) -> i32 {
    let mut arena = BumpArena::new(1 << 20);
    let rounds = 300 * scale;
    let mut checksum = 0i32;
    for r in 0..rounds {
        let mut head: usize = 0;
        for i in 0..20000 {
            let node = arena.alloc(24, 8);
            unsafe {
                (node as *mut u64).write_unaligned(head as u64);
                ((node + 8) as *mut u32).write_unaligned(((i + r) % 1009) as u32);
            }
            head = node;
            if i % 16 == 0 { arena.alloc(5, 1); }
        }
        let mut at = head;
        while at != 0 {
            unsafe {
                checksum = (checksum + ((at + 8) as *const u32).read_unaligned() as i32) % BENCH_MOD;
                at = (at as *const u64).read_unaligned() as usize;
            }
        }
        arena.top = 0;
    }
    checksum
}
