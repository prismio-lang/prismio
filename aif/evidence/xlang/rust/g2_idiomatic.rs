// G2 frame loop -- Rust, idiomatic.
//
// `cull` returns a fresh `Vec<DrawCmd>` every frame and it is dropped at the end
// of the frame. That is the natural Rust translation and it is also the honest
// one: the allocation pattern the program describes is one growing vector per
// frame, not ~501 individual objects.
//
// The per-frame allocation count is therefore ~8 (Vec growth doublings from 4 to
// 512), against Prismio's ~502. That difference is the finding, not a fairness
// problem: it is what `Vec<T>` means.

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
    let mut scene = Vec::new();
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

fn cull(scene: &[Renderable], near: f64, far: f64) -> Vec<DrawCmd> {
    let mut cmds = Vec::new();
    for r in scene {
        if r.z >= near && r.z <= far {
            cmds.push(DrawCmd {
                mesh_id: r.mesh_id,
                material_id: r.material_id,
                depth: r.z,
                visible: true,
            });
        }
    }
    cmds
}

fn submit(cmds: &[DrawCmd]) -> i64 {
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
