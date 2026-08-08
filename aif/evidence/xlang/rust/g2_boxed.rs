// G2 frame loop -- Rust, boxed. DIAGNOSTIC ONLY, not one of the three variants.
//
// `Vec<Box<DrawCmd>>` rebuilt every frame: ~501 individual heap allocations and
// ~501 frees per frame, which is Prismio's allocation profile for this program
// exactly. Idiomatic Rust does ~8 allocations for the same frame.
//
// This is the column that decides what G2's result means. If Prismio is close to
// this and far from g2_idiomatic, the cost is the per-object allocation the
// representation forces, and T1 arenas are the right fix. If Prismio is far from
// this too, the cost is elsewhere and arenas will not close it.

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

fn build_scene(count: usize) -> Vec<Box<Renderable>> {
    let mut scene = Vec::new();
    let mut f = 0.0;
    for i in 0..count {
        scene.push(Box::new(Renderable {
            mesh_id: i as i64,
            material_id: i as i64,
            x: f,
            y: f,
            z: f,
            radius: 1.0,
        }));
        f += 1.0;
    }
    scene
}

fn cull(scene: &[Box<Renderable>], near: f64, far: f64) -> Vec<Box<DrawCmd>> {
    let mut cmds = Vec::new();
    for r in scene {
        if r.z >= near && r.z <= far {
            cmds.push(Box::new(DrawCmd {
                mesh_id: r.mesh_id,
                material_id: r.material_id,
                depth: r.z,
                visible: true,
            }));
        }
    }
    cmds
}

fn submit(cmds: &[Box<DrawCmd>]) -> i64 {
    let mut drawn = 0;
    for c in cmds {
        if c.visible {
            drawn += 1;
        }
    }
    drawn
}

fn main() {
    let scene = build_scene(COUNT);
    let mut frames = harness::Frames::new(FRAMES);
    let mut submitted: i64 = 0;
    let mut culled: i64 = 0;

    for frame in 0..FRAMES {
        let t0 = harness::now_ns();
        let cmds = cull(&scene, 0.0, 500.0);
        let drawn = submit(&cmds);
        drop(cmds);
        let t1 = harness::now_ns();
        submitted += drawn;
        culled += COUNT as i64 - drawn;
        frames.set(frame, t1 - t0);
    }

    harness::report(
        &[("submitted", submitted), ("culled", culled)],
        &frames,
    );
}
