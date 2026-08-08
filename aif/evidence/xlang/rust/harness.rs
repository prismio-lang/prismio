// Shared benchmark harness for the Rust ports.
//
// Pulled in with `#[path = "harness.rs"] mod harness;` so every program stays a
// single rustc invocation, the same shape as `prismio build <one file>`.
//
// The clock is libc's clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) rather than
// std::time::Instant, because the Prismio and Swift ports call exactly that and
// the clock source must not be one of the things that differs between them.

#![allow(dead_code)]

use std::io::Write;

extern "C" {
    fn clock_gettime_nsec_np(clock_id: u32) -> u64;
}

pub const CLOCK_MONOTONIC_RAW: u32 = 4;

#[inline(always)]
pub fn now_ns() -> u64 {
    unsafe { clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) }
}

/// Frame-time recorder. The sample buffer is allocated to its final length up
/// front so that recording a frame never allocates inside the measured region.
pub struct Frames {
    samples: Vec<u64>,
}

impl Frames {
    pub fn new(frames: usize) -> Self {
        Frames { samples: vec![0u64; frames] }
    }

    #[inline(always)]
    pub fn set(&mut self, i: usize, ns: u64) {
        self.samples[i] = ns;
    }
}

/// Writes the agreed report: `checksum <name> <value>` lines first, then one
/// `frame_ns <v>` line per frame. Buffered, and after the measured region, so
/// the cost lands in wall time and not in any frame sample.
pub fn report(checksums: &[(&str, i64)], frames: &Frames) {
    let stdout = std::io::stdout();
    let mut out = std::io::BufWriter::with_capacity(1 << 20, stdout.lock());
    for (name, value) in checksums {
        writeln!(out, "checksum {} {}", name, value).unwrap();
    }
    for ns in &frames.samples {
        writeln!(out, "frame_ns {}", ns).unwrap();
    }
    out.flush().unwrap();
}
