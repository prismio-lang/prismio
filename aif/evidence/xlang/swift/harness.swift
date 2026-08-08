// Shared benchmark harness for the Swift ports.
//
// Compiled into each program's module: `swiftc -O harness.swift g1.swift`.
// The clock is clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW), the same call the
// Prismio and Rust ports make, so the clock source is not one of the things
// that differs between them.

import Darwin
import Foundation

@inline(__always)
func nowNs() -> UInt64 {
    return clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
}

/// Frame-time recorder. Sized to its final length up front so that recording a
/// frame never allocates inside the measured region.
struct Frames {
    var samples: [UInt64]

    init(_ count: Int) {
        samples = [UInt64](repeating: 0, count: count)
    }

    @inline(__always)
    mutating func set(_ i: Int, _ ns: UInt64) {
        samples[i] = ns
    }
}

/// Writes `checksum <name> <value>` lines, then one `frame_ns <v>` line per
/// frame. Assembled into one buffer and written once, so the report costs wall
/// time and not any frame sample.
func report(_ checksums: [(String, Int)], _ frames: Frames) {
    var out = ""
    out.reserveCapacity(frames.samples.count * 16 + 256)
    for (name, value) in checksums {
        out += "checksum \(name) \(value)\n"
    }
    for ns in frames.samples {
        out += "frame_ns \(ns)\n"
    }
    FileHandle.standardOutput.write(out.data(using: .utf8)!)
}
