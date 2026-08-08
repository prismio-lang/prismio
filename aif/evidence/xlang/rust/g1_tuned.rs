// G1 particles -- Rust, hand-tuned.
//
// Structure-of-arrays. G1 exists to be the layout discriminator: `integrate`
// touches 6 of 12 fields and `fade` touches 2, so an AoS record streams 96 bytes
// per particle to read 48 and then 16. One Vec per field streams exactly what is
// read, and the loops vectorise.
//
// This is the layout AIF's LAYOUT.md says the compiler should pick without being
// asked, and which today's compiler cannot emit (SoA makes one logical object
// several allocations -- COMPILER-AUDIT 1 finding 6). So this column is the
// prize, not the baseline.

#[path = "harness.rs"]
mod harness;

const FRAMES: usize = 6000;
const COUNT: usize = 2000;

struct Particles {
    px: Vec<f64>,
    py: Vec<f64>,
    pz: Vec<f64>,
    vx: Vec<f64>,
    vy: Vec<f64>,
    vz: Vec<f64>,
    r: Vec<f64>,
    g: Vec<f64>,
    b: Vec<f64>,
    a: Vec<f64>,
    life: Vec<f64>,
    size: Vec<f64>,
}

fn build_system(count: usize) -> Particles {
    let mut ps = Particles {
        px: Vec::with_capacity(count),
        py: Vec::with_capacity(count),
        pz: Vec::with_capacity(count),
        vx: Vec::with_capacity(count),
        vy: Vec::with_capacity(count),
        vz: Vec::with_capacity(count),
        r: Vec::with_capacity(count),
        g: Vec::with_capacity(count),
        b: Vec::with_capacity(count),
        a: Vec::with_capacity(count),
        life: Vec::with_capacity(count),
        size: Vec::with_capacity(count),
    };
    let mut f = 0.0;
    for _ in 0..count {
        ps.px.push(f);
        ps.py.push(f);
        ps.pz.push(0.0);
        ps.vx.push(1.0);
        ps.vy.push(2.0);
        ps.vz.push(0.0);
        ps.r.push(1.0);
        ps.g.push(1.0);
        ps.b.push(1.0);
        ps.a.push(1.0);
        ps.life.push(100.0);
        ps.size.push(1.0);
        f += 1.0;
    }
    ps
}

// Three independent streaming updates. Each `zip` gives the optimiser two slices
// it knows are distinct and equally long, so the bounds checks fall out.
fn integrate(ps: &mut Particles, dt: f64) {
    for (p, v) in ps.px.iter_mut().zip(ps.vx.iter()) {
        *p += *v * dt;
    }
    for (p, v) in ps.py.iter_mut().zip(ps.vy.iter()) {
        *p += *v * dt;
    }
    for (p, v) in ps.pz.iter_mut().zip(ps.vz.iter()) {
        *p += *v * dt;
    }
}

fn fade(ps: &mut Particles, dt: f64) {
    for (l, a) in ps.life.iter_mut().zip(ps.a.iter_mut()) {
        *l -= dt;
        *a = *l * 0.01;
    }
}

fn count_alive(ps: &Particles) -> i64 {
    ps.life.iter().filter(|l| **l > 0.0).count() as i64
}

fn count_beyond(ps: &Particles, limit: f64) -> i64 {
    ps.px.iter().filter(|p| **p > limit).count() as i64
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
