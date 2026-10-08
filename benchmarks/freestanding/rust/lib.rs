//! The Rust arm of the freestanding suite: `no_std`, no allocation, one crate
//! exposing `bench_<name>` with the C ABI for the shared harness to call. It is
//! the C arm translated statement by statement; see ../README.md for the rule
//! that the three arms are the same program.
//!
//! Indexing is Rust's own, bounds-checked. That is a difference from the other two
//! arms and it is the language's price for safe indexing, so it stays.

#![no_std]

mod algorithms;
mod compute;
mod hardware;
mod memory;

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

/// The linear congruential step, as the other arms write it.
#[inline(always)]
pub(crate) fn lcg(s: &mut u32) -> u32 {
    *s = s.wrapping_mul(1664525).wrapping_add(1013904223);
    *s
}
