// G1 particles -- Rust, boxed. DIAGNOSTIC ONLY, not one of the three variants.
//
// `Vec<Box<Particle>>`: a vector of pointers to individually heap-allocated
// particles. That is exactly Prismio's `List<Particle>` representation, and no
// Rust programmer would write it.
//
// It exists to split one number in two. If Prismio is slower than idiomatic
// Rust here, the cause is either the representation (a vector of pointers,
// chased) or the code the backend emits around it. This column holds the
// representation fixed at Prismio's and lets rustc emit the code, so the gap
// between it and g1_idiomatic is the representation's cost and the gap between
// it and Prismio is everything else.

#[path = "harness.rs"]
mod harness;

const FRAMES: usize = 6000;
const COUNT: usize = 2000;

struct Particle {
    px: f64,
    py: f64,
    pz: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    r: f64,
    g: f64,
    b: f64,
    a: f64,
    life: f64,
    size: f64,
}

fn spawn_particle(f: f64) -> Box<Particle> {
    Box::new(Particle {
        px: f,
        py: f,
        pz: 0.0,
        vx: 1.0,
        vy: 2.0,
        vz: 0.0,
        r: 1.0,
        g: 1.0,
        b: 1.0,
        a: 1.0,
        life: 100.0,
        size: 1.0,
    })
}

fn build_system(count: usize) -> Vec<Box<Particle>> {
    let mut ps = Vec::new();
    let mut f = 0.0;
    for _ in 0..count {
        ps.push(spawn_particle(f));
        f += 1.0;
    }
    ps
}

fn integrate(ps: &mut [Box<Particle>], dt: f64) {
    for p in ps.iter_mut() {
        p.px += p.vx * dt;
        p.py += p.vy * dt;
        p.pz += p.vz * dt;
    }
}

fn fade(ps: &mut [Box<Particle>], dt: f64) {
    for p in ps.iter_mut() {
        p.life -= dt;
        p.a = p.life * 0.01;
    }
}

fn count_alive(ps: &[Box<Particle>]) -> i64 {
    let mut alive = 0;
    for p in ps {
        if p.life > 0.0 {
            alive += 1;
        }
    }
    alive
}

fn count_beyond(ps: &[Box<Particle>], limit: f64) -> i64 {
    let mut beyond = 0;
    for p in ps {
        if p.px > limit {
            beyond += 1;
        }
    }
    beyond
}

fn main() {
    let mut ps = build_system(COUNT);
    let dt = 0.016;
    let mut frames = harness::Frames::new(FRAMES);

    for frame in 0..FRAMES {
        let t0 = harness::now_ns();
        integrate(&mut ps, dt);
        fade(&mut ps, dt);
        let t1 = harness::now_ns();
        frames.set(frame, t1 - t0);
    }

    harness::report(
        &[
            ("alive", count_alive(&ps)),
            ("beyond", count_beyond(&ps, 1000.5)),
        ],
        &frames,
    );
}
