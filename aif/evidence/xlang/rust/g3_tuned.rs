// G3 scene graph -- Rust, hand-tuned.
//
// The tree is built once and never changes shape, so the depth-first visit order
// is a constant. It is computed once into `order`, and each frame becomes a flat
// pass over that order: a node's parent always precedes it, so reading the
// parent's already-updated world transform is exactly what the recursion did.
//
// This removes the recursion, the sibling-chain pointer walk, and the per-node
// call overhead, and turns a pointer-order traversal into a sequential one. It
// is the same arithmetic in the same order on the same values.

#[path = "harness.rs"]
mod harness;

const FRAMES: usize = 10000;
const BREADTH: i64 = 4;
const DEPTH: i64 = 5;

#[derive(Clone, Copy)]
struct Transform {
    px: f64,
    py: f64,
    pz: f64,
    sx: f64,
    sy: f64,
    sz: f64,
}

#[derive(Clone, Copy)]
struct Bounds {
    min_x: f64,
    min_y: f64,
    min_z: f64,
    max_x: f64,
    max_y: f64,
    max_z: f64,
}

struct Node {
    local: Transform,
    world: Transform,
    bounds: Bounds,
    parent: i64,
    first_child: i64,
    next_sibling: i64,
    dirty: bool,
}

fn identity_transform() -> Transform {
    Transform { px: 0.0, py: 0.0, pz: 0.0, sx: 1.0, sy: 1.0, sz: 1.0 }
}

fn unit_bounds() -> Bounds {
    Bounds {
        min_x: 0.0, min_y: 0.0, min_z: 0.0,
        max_x: 1.0, max_y: 1.0, max_z: 1.0,
    }
}

fn make_node(parent: i64, ox: f64) -> Node {
    let mut t = identity_transform();
    t.px = ox;
    Node {
        local: t,
        world: identity_transform(),
        bounds: unit_bounds(),
        parent,
        first_child: -1,
        next_sibling: -1,
        dirty: true,
    }
}

fn link_child(nodes: &mut [Node], parent_idx: i64, child_idx: i64) {
    if nodes[parent_idx as usize].first_child < 0 {
        nodes[parent_idx as usize].first_child = child_idx;
    } else {
        let mut sib = nodes[parent_idx as usize].first_child;
        loop {
            if nodes[sib as usize].next_sibling < 0 {
                nodes[sib as usize].next_sibling = child_idx;
                break;
            }
            sib = nodes[sib as usize].next_sibling;
        }
    }
}

fn build_hierarchy(breadth: i64, depth: i64) -> Vec<Node> {
    let mut nodes: Vec<Node> = Vec::new();
    nodes.push(make_node(-1, 0.0));

    let mut level = 0;
    let mut level_start: i64 = 0;
    let mut level_count: i64 = 1;

    while level < depth {
        let next_start = nodes.len() as i64;
        let mut parent_off = 0;
        while parent_off < level_count {
            let parent_idx = level_start + parent_off;
            let mut b = 0;
            let mut ox = 0.0;
            while b < breadth {
                let child_idx = nodes.len() as i64;
                nodes.push(make_node(parent_idx, ox));
                link_child(&mut nodes, parent_idx, child_idx);
                ox += 1.0;
                b += 1;
            }
            parent_off += 1;
        }
        level_start = next_start;
        level_count = nodes.len() as i64 - next_start;
        level += 1;
    }
    nodes
}

/// Depth-first visit order, computed once. Same order the recursion visits in.
fn dfs_order(nodes: &[Node]) -> Vec<u32> {
    let mut order = Vec::with_capacity(nodes.len());
    let mut stack = vec![0i64];
    while let Some(idx) = stack.pop() {
        order.push(idx as u32);
        // Children pushed in reverse so they pop in sibling-chain order.
        let mut kids = Vec::new();
        let mut c = nodes[idx as usize].first_child;
        while c >= 0 {
            kids.push(c);
            c = nodes[c as usize].next_sibling;
        }
        while let Some(k) = kids.pop() {
            stack.push(k);
        }
    }
    order
}

#[inline]
fn propagate_flat(nodes: &mut [Node], order: &[u32]) -> i64 {
    for &i in order {
        let i = i as usize;
        let p = nodes[i].parent;
        let (ox, oy, oz) = if p < 0 {
            (0.0, 0.0, 0.0)
        } else {
            let w = nodes[p as usize].world;
            (w.px, w.py, w.pz)
        };
        let n = &mut nodes[i];
        n.world.px = n.local.px + ox;
        n.world.py = n.local.py + oy;
        n.world.pz = n.local.pz + oz;
        n.dirty = false;
    }
    order.len() as i64
}

#[inline]
fn count_visible(nodes: &[Node], limit: f64) -> i64 {
    let mut visible = 0;
    for n in nodes {
        if n.world.px < limit && n.world.py < limit && n.world.pz < limit {
            visible += 1;
        }
    }
    visible
}

fn main() {
    let mut nodes = build_hierarchy(BREADTH, DEPTH);
    let order = dfs_order(&nodes);
    let mut frames = harness::Frames::new(FRAMES);
    let mut visited = 0;
    let mut visible = 0;

    for frame in 0..FRAMES {
        let t0 = harness::now_ns();
        visited = propagate_flat(&mut nodes, &order);
        visible = count_visible(&nodes, 1000.0);
        let t1 = harness::now_ns();
        frames.set(frame, t1 - t0);
    }

    harness::report(
        &[
            ("nodes", nodes.len() as i64),
            ("visited", visited),
            ("visible", visible),
        ],
        &frames,
    );
}
