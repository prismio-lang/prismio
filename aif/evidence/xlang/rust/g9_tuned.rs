// G9 parallel bands -- Rust, hand-tuned.
//
// The idiomatic arm creates and destroys four OS threads every frame, which is
// what `std::thread::spawn` costs and what Prismio's `spawn` costs. A tuned Rust
// program does not do that: it starts its workers once and hands them work over
// channels, so the per-frame cost is two channel round trips instead of four
// `pthread_create`/`pthread_join` pairs.
//
// This arm is what says how much of the Prismio-vs-Rust gap on this program is
// the thread and how much is the code. It is deliberately *not* the peer of
// Prismio's `spawn` -- `g9_idiomatic.rs` is -- and it is not rayon either,
// because the harness builds every port with plain `rustc` and no crates.
//
// i32 with `wrapping_*` throughout, for the reason g9_idiomatic.rs gives.

#[path = "harness.rs"]
mod harness;

use std::sync::mpsc;

const FRAMES: usize = 2000;
const STEPS: i32 = 24000;
const WORKERS: usize = 4;

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

    // Workers outlive every frame. Results come back on one shared channel
    // because the four are summed -- their order carries no information, and a
    // per-worker channel would only add a receive to the frame's critical path.
    let (result_tx, result_rx) = mpsc::channel::<i32>();
    let mut job_tx = Vec::with_capacity(WORKERS);
    for _ in 0..WORKERS {
        let (tx, rx) = mpsc::channel::<(i32, i32)>();
        let out = result_tx.clone();
        std::thread::spawn(move || {
            while let Ok((seed, steps)) = rx.recv() {
                if out.send(simulate(seed, steps)).is_err() {
                    return;
                }
            }
        });
        job_tx.push(tx);
    }
    // The original sender would otherwise keep the result channel open forever.
    drop(result_tx);

    let offsets = [1i32, 104730, 209459, 314188];
    let mut total: i32 = 0;
    let mut last: i32 = 0;

    for frame in 0..FRAMES {
        let f = (frame as i32).wrapping_mul(7919);
        let t0 = harness::now_ns();

        for w in 0..WORKERS {
            job_tx[w].send((f.wrapping_add(offsets[w]), STEPS)).unwrap();
        }
        let mut sum: i32 = 0;
        for _ in 0..WORKERS {
            sum = sum.wrapping_add(result_rx.recv().unwrap());
        }

        let t1 = harness::now_ns();

        last = sum;
        total = total.wrapping_add(last);
        frames.set(frame, t1 - t0);
    }

    harness::report(&[("total", total as i64), ("last", last as i64)], &frames);
}
