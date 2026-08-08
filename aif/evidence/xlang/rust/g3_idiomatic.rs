// G3 scene graph -- Rust, idiomatic.
//
// `Vec<Node>` with parent/child links as indices, which is what the corpus
// program already does -- G3 was written index-based because the affine
// discipline makes a `parent: Node` back-reference inexpressible, and that is
// also how production engines write it. So the Rust translation needs no
// `Rc`/`RefCell` and no `unsafe`: the shape ports directly.
//
// Nothing is allocated per frame. The frame is a recursive transform
// propagation plus a linear visibility scan, so this program measures traversal
// over a retained tree.

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

fn propagate(nodes: &mut Vec<Node>, idx: usize, ox: f64, oy: f64, oz: f64) -> i64 {
    let (wx, wy, wz, first_child) = {
        let n = &mut nodes[idx];
        n.world.px = n.local.px + ox;
        n.world.py = n.local.py + oy;
        n.world.pz = n.local.pz + oz;
        n.dirty = false;
        (n.world.px, n.world.py, n.world.pz, n.first_child)
    };

    let mut visited = 1;
    let mut c = first_child;
    while c >= 0 {
        visited += propagate(nodes, c as usize, wx, wy, wz);
        c = nodes[c as usize].next_sibling;
    }
    visited
}

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
    let mut frames = harness::Frames::new(FRAMES);
    let mut visited = 0;
    let mut visible = 0;

    for frame in 0..FRAMES {
        let t0 = harness::now_ns();
        visited = propagate(&mut nodes, 0, 0.0, 0.0, 0.0);
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
