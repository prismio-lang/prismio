// G2 frame loop -- Rust, arena-tuned (bumpalo).
//
// What a Rust programmer writes after a profile shows the per-frame Vec growth.
// One `Bump` outside the loop, `reset()` at the top of each frame, and the
// command batch is a `bumpalo::collections::Vec` inside it. After the first few
// frames the bump has enough chunk to serve the whole batch, so the steady state
// allocates nothing at all -- the pointer bump is the allocation.
//
// This is the transformation AIF's T1 exists to perform without being asked, so
// this column is the target Prismio is aiming at on this program.

#[path = "harness.rs"]
mod harness;

use bumpalo::Bump;
use bumpalo::collections::Vec as BVec;

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

fn cull<'a>(bump: &'a Bump, scene: &[Renderable], near: f64, far: f64) -> BVec<'a, DrawCmd> {
    let mut cmds = BVec::new_in(bump);
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
    let mut bump = Bump::new();

    for frame in 0..FRAMES {
        let t0 = harness::now_ns();
        // Reset keeps the largest chunk and drops the rest, so the batch is
        // served from already-mapped memory from frame 2 onwards.
        bump.reset();
        let drawn = {
            let cmds = cull(&bump, &scene, 0.0, 500.0);
            submit(&cmds)
        };
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
