// G4 ECS world -- Rust, boxed. DIAGNOSTIC ONLY, not one of the three variants.
//
// `Vec<Box<Component>>` per component array: Prismio's representation exactly.
// G4 is the worst of the access-bound programs and it allocates nothing per
// frame, so whatever separates Prismio from idiomatic Rust here is not the
// memory model doing work -- it is the shape of a read.
//
// The g1 diagnostic found the representation worth only ~1.09x, but g1's record
// is 96 bytes and G4's components are 24. A pointer array in front of a 24-byte
// object is proportionally far more traffic, so g1's answer must not be assumed
// to carry: this column measures it where it matters.

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
    positions: Vec<Box<Position>>,
    velocities: Vec<Box<Velocity>>,
    physics: Vec<Box<Physics>>,
    sprites: Vec<Box<Sprite>>,
    health: Vec<Box<Health>>,
    entity_count: usize,
}

fn make_world() -> World {
    World {
        positions: Vec::new(),
        velocities: Vec::new(),
        physics: Vec::new(),
        sprites: Vec::new(),
        health: Vec::new(),
        entity_count: 0,
    }
}

fn spawn(w: &mut World, seed: f64) {
    w.positions.push(Box::new(Position { x: seed, y: seed, z: 0.0 }));
    w.velocities.push(Box::new(Velocity { dx: 1.0, dy: 0.5, dz: 0.0 }));
    w.physics.push(Box::new(Physics { mass: 1.0, drag: 0.01, restitution: 0.5 }));
    w.sprites.push(Box::new(Sprite {
        texture_id: 1,
        layer: 0,
        tint_r: 1.0,
        tint_g: 1.0,
        tint_b: 1.0,
        alpha: 1.0,
    }));
    w.health.push(Box::new(Health { current: 100, maximum: 100, regen: 0.1 }));
    w.entity_count += 1;
}

fn system_movement(w: &mut World, dt: f64) {
    let n = w.entity_count;
    for i in 0..n {
        let v = &w.velocities[i];
        let (dx, dy, dz) = (v.dx, v.dy, v.dz);
        let p = &mut w.positions[i];
        p.x += dx * dt;
        p.y += dy * dt;
        p.z += dz * dt;
    }
}

fn system_physics(w: &mut World, dt: f64) {
    let n = w.entity_count;
    for i in 0..n {
        let k = 1.0 - w.physics[i].drag * dt;
        let v = &mut w.velocities[i];
        v.dx *= k;
        v.dy = v.dy * k - 9.81 * dt;
        v.dz *= k;
    }
}

fn system_render(w: &World) -> i64 {
    let n = w.entity_count;
    let mut drawn = 0;
    for i in 0..n {
        let p = &w.positions[i];
        let s = &w.sprites[i];
        if s.alpha > 0.0 && p.y > -100.0 {
            drawn += 1;
        }
    }
    drawn
}

fn system_regen(w: &mut World) {
    let n = w.entity_count;
    for i in 0..n {
        let h = &mut w.health[i];
        if h.current < h.maximum {
            h.current += 1;
        }
    }
}

fn main() {
    let mut w = make_world();
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
        system_physics(&mut w, dt);
        system_movement(&mut w, dt);
        system_regen(&mut w);
        let drawn = system_render(&w);
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
