// G4 ECS world -- Rust, hand-tuned.
//
// The four systems are fused into one pass. Every system is elementwise and no
// entity reads another entity, so running physics-then-movement-then-regen-then-
// render for entity i, for each i, computes exactly what running each system
// over all entities in that order computes. Four streaming passes over five
// arrays become one.
//
// The component arrays are also reserved up front, and the inner loop takes
// slices so the bounds checks are hoisted.

#[path = "harness.rs"]
mod harness;

const FRAMES: usize = 10000;
const ENTITIES: usize = 1500;

struct Position { x: f64, y: f64, z: f64 }
struct Velocity { dx: f64, dy: f64, dz: f64 }
struct Physics { mass: f64, drag: f64, restitution: f64 }

struct Sprite {
    texture_id: i64,
    layer: i64,
    tint_r: f64,
    tint_g: f64,
    tint_b: f64,
    alpha: f64,
}

struct Health { current: i64, maximum: i64, regen: f64 }

struct World {
    positions: Vec<Position>,
    velocities: Vec<Velocity>,
    physics: Vec<Physics>,
    sprites: Vec<Sprite>,
    health: Vec<Health>,
    entity_count: usize,
}

fn make_world(cap: usize) -> World {
    World {
        positions: Vec::with_capacity(cap),
        velocities: Vec::with_capacity(cap),
        physics: Vec::with_capacity(cap),
        sprites: Vec::with_capacity(cap),
        health: Vec::with_capacity(cap),
        entity_count: 0,
    }
}

fn spawn(w: &mut World, seed: f64) {
    w.positions.push(Position { x: seed, y: seed, z: 0.0 });
    w.velocities.push(Velocity { dx: 1.0, dy: 0.5, dz: 0.0 });
    w.physics.push(Physics { mass: 1.0, drag: 0.01, restitution: 0.5 });
    w.sprites.push(Sprite {
        texture_id: 1,
        layer: 0,
        tint_r: 1.0,
        tint_g: 1.0,
        tint_b: 1.0,
        alpha: 1.0,
    });
    w.health.push(Health { current: 100, maximum: 100, regen: 0.1 });
    w.entity_count += 1;
}

#[inline]
fn step_fused(w: &mut World, dt: f64) -> i64 {
    let n = w.entity_count;
    let pos = &mut w.positions[..n];
    let vel = &mut w.velocities[..n];
    let phy = &w.physics[..n];
    let spr = &w.sprites[..n];
    let hp = &mut w.health[..n];

    let mut drawn = 0i64;
    for i in 0..n {
        // physics
        let k = 1.0 - phy[i].drag * dt;
        let v = &mut vel[i];
        v.dx *= k;
        v.dy = v.dy * k - 9.81 * dt;
        v.dz *= k;
        let (vdx, vdy, vdz) = (v.dx, v.dy, v.dz);

        // movement
        let p = &mut pos[i];
        p.x += vdx * dt;
        p.y += vdy * dt;
        p.z += vdz * dt;
        let py = p.y;

        // regen
        let h = &mut hp[i];
        if h.current < h.maximum {
            h.current += 1;
        }

        // render
        if spr[i].alpha > 0.0 && py > -100.0 {
            drawn += 1;
        }
    }
    drawn
}

fn main() {
    let mut w = make_world(ENTITIES);
    let mut seed = 0.0;
    for _ in 0..ENTITIES {
        spawn(&mut w, seed);
        seed += 1.0;
    }

    let dt = 0.016;
    let mut frames = harness::Frames::new(FRAMES);
    let mut total_drawn: i64 = 0;

    for frame in 0..FRAMES {
        let t0 = harness::now_ns();
        let drawn = step_fused(&mut w, dt);
        let t1 = harness::now_ns();
        total_drawn += drawn;
        frames.set(frame, t1 - t0);
    }

    harness::report(
        &[
            ("entities", w.entity_count as i64),
            ("draws", total_drawn),
        ],
        &frames,
    );
}
