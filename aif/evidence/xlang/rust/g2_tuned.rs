// G2 frame loop -- Rust, hand-tuned.
//
// "Whatever it takes": one command buffer, allocated once, cleared and refilled
// every frame. In steady state the program performs zero allocations and zero
// frees, which is the floor -- an arena still bumps a pointer and still has to
// reset.
//
// The cost is that `cull` no longer returns its result, so the buffer's lifetime
// is now the caller's problem. That is the ergonomic price the memory model
// exists to avoid paying, and it is the reason this variant is worth measuring
// separately from the arena one.

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

#[inline]
fn cull_into(cmds: &mut Vec<DrawCmd>, scene: &[Renderable], near: f64, far: f64) {
    cmds.clear();
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
}

#[inline]
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
    let mut cmds: Vec<DrawCmd> = Vec::with_capacity(COUNT);

    for frame in 0..FRAMES {
        let t0 = harness::now_ns();
        cull_into(&mut cmds, &scene, 0.0, 500.0);
        let drawn = submit(&cmds);
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
