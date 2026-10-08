pub const BENCH_MOD: i32 = 1_000_000_007;

pub fn next_random(seed: i32) -> i32 { (seed * 25173 + 13849) % 65521 }

pub struct BenchTree {
    pub value: i32,
    pub left: Option<Box<BenchTree>>,
    pub right: Option<Box<BenchTree>>,
}
