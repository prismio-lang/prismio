// G2 frame loop -- Rust, hand-tuned THE WAY PRISMIO IS FORCED TO.
//
// Diagnostic, not a variant. g2_tuned.rs uses `Vec<DrawCmd>` (inline storage)
// and refills it with clear()+push(). Prismio's `List<T>` holds *pointers*, so
// the equivalent tuning there is g2_tuned.psm's: pre-fill a buffer of
// individually heap-allocated records once, then mutate them in place.
//
// This file is that same tuning, in Rust: Vec<Box<DrawCmd>>, pre-filled once,
// mutated in place, zero allocation in steady state -- identical to
// g2_tuned.psm field for field and loop for loop.
//
// If this lands near Prismio's number, the remaining gap between the two
// hand-tuned variants is the *representation* and not the compiler.

#[path = "harness.rs"]
mod harness;

const FRAMES: usize = 20000;
const COUNT: usize = 1000;

struct DrawCmd {
    mesh_id: i64,
    material_id: i64,
    depth: f64,
    visible: bool,
}

struct Renderable {
    mesh_id: i64,
    material_id: i64,
    x: f64,
    y: f64,
    z: f64,
    radius: f64,
}

fn build_scene(count: usize) -> Vec<Renderable> {
    let mut scene = Vec::with_capacity(count);
    let mut f = 0.0;
    for i in 0..count {
        scene.push(Renderable {
            mesh_id: i as i64,
            material_id: i as i64,
            x: f,
            y: f,
            z: f,
            radius: 1.0,
        });
        f += 1.0;
    }
    scene
}

// The buffer, allocated once -- one Box per element, exactly as Prismio's
// make_buffer() does. Capacity is the worst case.
fn make_buffer(count: usize) -> Vec<Box<DrawCmd>> {
    let mut cmds = Vec::with_capacity(count);
    for _ in 0..count {
        cmds.push(Box::new(DrawCmd {
            mesh_id: 0,
            material_id: 0,
            depth: 0.0,
            visible: false,
        }));
    }
    cmds
}

// Mutates in place and answers how many entries are live. Allocates nothing.
#[inline]
fn cull_into(cmds: &mut [Box<DrawCmd>], scene: &[Renderable], near: f64, far: f64) -> usize {
    let mut live = 0;
    for r in scene {
        if r.z >= near && r.z <= far {
            let c = &mut cmds[live];
            c.mesh_id = r.mesh_id;
            c.material_id = r.material_id;
            c.depth = r.z;
            c.visible = true;
            live += 1;
        }
    }
    live
}

#[inline]
fn submit(cmds: &[Box<DrawCmd>], live: usize) -> i64 {
    let mut drawn = 0;
    for i in 0..live {
        if cmds[i].visible {
            drawn += 1;
        }
    }
    drawn
}

fn main() {
    let scene = build_scene(COUNT);
    let mut cmds = make_buffer(COUNT);
    let mut frames = harness::Frames::new(FRAMES);
    let mut submitted: i64 = 0;
    let mut culled: i64 = 0;

    for frame in 0..FRAMES {
        let t0 = harness::now_ns();
        let live = cull_into(&mut cmds, &scene, 0.0, 500.0);
        let drawn = submit(&cmds, live);
        let t1 = harness::now_ns();
        submitted += drawn;
        culled += COUNT as i64 - drawn;
        frames.set(frame, t1 - t0);
    }

    harness::report(&[("submitted", submitted), ("culled", culled)], &frames);
}
