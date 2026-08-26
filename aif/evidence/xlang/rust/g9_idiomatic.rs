// G9 parallel bands -- Rust, idiomatic.
//
// "What a competent programmer writes first" for a per-frame parallel step with
// no external crates: `std::thread::spawn` per band, `join` at the frame
// boundary. This is the honest peer of Prismio's `spawn`/`join` -- both are one
// OS thread per task, created and torn down every frame.
//
// **The arithmetic is i32, not i64, and that is not a stylistic choice.**
// Prismio's `Int` is 32 bits and wraps (`2147483647 + 1` is `-2147483648`), so an
// i64 port computes a different checksum and the harness rejects it. Every
// operation that can overflow is spelled `wrapping_*` so the port does not
// depend on rustc's overflow-check setting either.

#[path = "harness.rs"]
mod harness;

const FRAMES: usize = 2000;
const STEPS: i32 = 24000;

// Serial by construction: `s` carries across the iteration, so this cannot be
// vectorised or reassociated and the only parallelism is between bands.
fn simulate(seed: i32, steps: i32) -> i32 {
    let mut s = seed;
    let mut acc: i32 = 0;
    let mut i = 0;
    while i < steps {
        s = s.wrapping_mul(1103515245).wrapping_add(12345);
        acc = acc.wrapping_add((s / 65536) & 32767);
        i += 1;
    }
    acc
}

fn main() {
    let mut frames = harness::Frames::new(FRAMES);
    let mut total: i32 = 0;
    let mut last: i32 = 0;

    for frame in 0..FRAMES {
        let f = (frame as i32).wrapping_mul(7919);
        let t0 = harness::now_ns();

        let w0 = std::thread::spawn(move || simulate(f.wrapping_add(1), STEPS));
        let w1 = std::thread::spawn(move || simulate(f.wrapping_add(104730), STEPS));
        let w2 = std::thread::spawn(move || simulate(f.wrapping_add(209459), STEPS));
        let w3 = std::thread::spawn(move || simulate(f.wrapping_add(314188), STEPS));

        let r0 = w0.join().unwrap();
        let r1 = w1.join().unwrap();
        let r2 = w2.join().unwrap();
        let r3 = w3.join().unwrap();

        let t1 = harness::now_ns();

        last = r0.wrapping_add(r1).wrapping_add(r2).wrapping_add(r3);
        total = total.wrapping_add(last);
        frames.set(frame, t1 - t0);
    }

    harness::report(&[("total", total as i64), ("last", last as i64)], &frames);
}
