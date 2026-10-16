use std::sync::mpsc::sync_channel;
use std::thread;

// The same four programs as prismio/graph_churn.psm; read the comment there for
// what each is for. A node owns a `Vec<i32>` edge list, which is the allocation
// being measured.

const CHURN_MOD: i64 = 1_000_000_007;

struct ChurnNode {
    value: i32,
    live: i32,
    edges: Vec<i32>,
}

struct ChurnFrag {
    nodes: Vec<ChurnNode>,
    id: i32,
}

fn churn_next(seed: i64) -> i64 {
    (seed * 48271) % 2147483647
}

fn churn_mix(acc: i64, value: i32) -> i64 {
    (acc * 31 + value as i64) % CHURN_MOD
}

fn churn_fragment(index: i32) -> ChurnFrag {
    let mut seed = (index as i64 * 7919 + 17) % 2147483646 + 1;
    seed = churn_next(seed);
    let count = 8 + (seed % 24) as i32;
    let mut nodes = Vec::with_capacity(count as usize);
    for _ in 0..count {
        seed = churn_next(seed);
        let degree = 1 + (seed % 6) as i32;
        let mut edges = Vec::with_capacity(degree as usize);
        for _ in 0..degree {
            seed = churn_next(seed);
            edges.push((seed % count as i64) as i32);
        }
        seed = churn_next(seed);
        nodes.push(ChurnNode { value: (seed % 1021) as i32, live: 1, edges });
    }
    ChurnFrag { nodes, id: index }
}

fn churn_frag_sum(frag: &ChurnFrag) -> i64 {
    let mut acc = frag.id as i64;
    for node in &frag.nodes {
        acc = churn_mix(acc, node.value);
        for &edge in &node.edges {
            acc = churn_mix(acc, edge);
        }
    }
    acc
}

fn churn_single(scale: i32) -> i64 {
    let n = 8192 * scale;
    let steps = 240000 * scale;
    let n64 = n as i64;
    let mut nodes: Vec<ChurnNode> = Vec::with_capacity(n as usize);
    let mut free: Vec<i32> = Vec::with_capacity(n as usize);
    let mut seed: i64 = 12345;
    for i in 0..n {
        let mut edges = Vec::with_capacity(4);
        for _ in 0..3 {
            seed = churn_next(seed);
            edges.push((seed % n64) as i32);
        }
        nodes.push(ChurnNode { value: i % 1021, live: 1, edges });
    }

    let mut checksum: i64 = 0;
    for step in 0..steps {
        seed = churn_next(seed);
        let u = (seed % n64) as usize;
        seed = churn_next(seed);
        let v = (seed % n64) as i32;
        seed = churn_next(seed);
        let op = (seed % 8) as i32;
        if op < 3 {
            if nodes[u].live == 1 && nodes[v as usize].live == 1 {
                let edges = &mut nodes[u].edges;
                if edges.len() >= 12 {
                    edges.swap_remove(0);
                }
                edges.push(v);
            }
        } else if op < 5 {
            if nodes[u].live == 1 && !nodes[u].edges.is_empty() {
                let edges = &mut nodes[u].edges;
                let at = v as usize % edges.len();
                checksum = churn_mix(checksum, edges[at]);
                edges.swap_remove(at);
            }
        } else if op == 6 {
            if nodes[u].live == 1 {
                let kept = nodes[u].value;
                checksum = churn_mix(churn_mix(checksum, kept), nodes[u].edges.len() as i32);
                nodes[u] = ChurnNode { value: kept, live: 0, edges: Vec::new() };
                free.push(u as i32);
            }
        } else if op == 7 {
            if let Some(w) = free.pop() {
                let mut edges = Vec::with_capacity(4);
                for k in 0..3 {
                    edges.push((v + k * 7919) % n);
                }
                nodes[w as usize] = ChurnNode { value: step % 1021, live: 1, edges };
            }
        }
    }

    for node in &nodes {
        if node.live == 1 {
            checksum = churn_mix(checksum, node.value);
            for &edge in &node.edges {
                if nodes[edge as usize].live == 1 {
                    checksum = churn_mix(checksum, edge);
                }
            }
        }
    }
    churn_mix(checksum, free.len() as i32)
}

fn churn_alloc(scale: i32) -> i64 {
    let window = 192;
    let steps = 10000 * scale;
    let mut slots: Vec<ChurnFrag> = Vec::with_capacity(window as usize);
    for i in 0..window {
        slots.push(churn_fragment(i));
    }
    let mut kept: Vec<ChurnFrag> = Vec::with_capacity((steps / 50 + 1) as usize);
    let mut seed: i64 = 99991;
    let mut checksum: i64 = 0;
    for step in 0..steps {
        seed = churn_next(seed);
        let slot = (seed % window as i64) as usize;
        checksum = (checksum * 31 + churn_frag_sum(&slots[slot])) % CHURN_MOD;
        slots[slot] = churn_fragment(window + step);
        if step % 50 == 0 {
            kept.push(churn_fragment(window + steps + step));
        }
    }
    for frag in &slots {
        checksum = (checksum * 31 + churn_frag_sum(frag)) % CHURN_MOD;
    }
    for frag in &kept {
        checksum = (checksum * 31 + churn_frag_sum(frag)) % CHURN_MOD;
    }
    churn_mix(checksum, kept.len() as i32)
}

fn churn_transfer(scale: i32) -> i64 {
    let count = 5000 * scale;
    let (tx1, rx1) = sync_channel::<ChurnFrag>(16);
    let (tx2, rx2) = sync_channel::<ChurnFrag>(16);

    let producer = thread::spawn(move || {
        for i in 0..count {
            let _ = tx1.send(churn_fragment(i));
        }
    });

    let trimmer = thread::spawn(move || {
        let mut acc: i64 = 0;
        while let Ok(mut frag) = rx1.recv() {
            acc = (acc * 31 + churn_frag_sum(&frag)) % CHURN_MOD;
            for node in frag.nodes.iter_mut() {
                if node.value % 3 == 0 {
                    *node = ChurnNode { value: node.value, live: 1, edges: Vec::new() };
                }
            }
            let _ = tx2.send(frag);
        }
        acc as i32
    });

    let ring: usize = 64;
    let mut recent: Vec<ChurnFrag> = Vec::with_capacity(ring);
    for _ in 0..ring {
        recent.push(ChurnFrag { nodes: Vec::new(), id: -1 });
    }
    let mut checksum: i64 = 0;
    let mut seen: i32 = 0;
    while let Ok(frag) = rx2.recv() {
        checksum = (checksum * 31 + churn_frag_sum(&frag)) % CHURN_MOD;
        recent[seen as usize % ring] = frag;
        seen += 1;
    }

    let _ = producer.join();
    let trimmed = trimmer.join().unwrap();

    for frag in &recent {
        checksum = (checksum * 31 + churn_frag_sum(frag)) % CHURN_MOD;
    }
    checksum = churn_mix(checksum, trimmed);
    churn_mix(checksum, count + seen)
}

pub fn graph_churn_single(scale: i32) -> i32 {
    churn_single(scale) as i32
}

pub fn graph_churn_alloc(scale: i32) -> i32 {
    churn_alloc(scale) as i32
}

pub fn graph_churn_transfer(scale: i32) -> i32 {
    churn_transfer(scale) as i32
}

pub fn graph_churn_full(scale: i32) -> i32 {
    let single = churn_single(scale);
    let alloc = churn_alloc(scale);
    let transfer = churn_transfer(scale);
    (((single * 31 + alloc) % CHURN_MOD * 31 + transfer) % CHURN_MOD) as i32
}
