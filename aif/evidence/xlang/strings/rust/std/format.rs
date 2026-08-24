unsafe extern "C" {
    fn clock_gettime_nsec_np(clk: i32) -> u64;
}

fn run(reps: usize) -> i64 {
    let mut sum = 0i64;
    for k in 0..reps {
        let text = (k as i32).wrapping_mul(1_103_515_245).to_string();
        sum += text.as_bytes()[0] as i64 + text.len() as i64;
    }
    sum
}

fn main() {
    assert!(run(2_000) >= 0);
    let start = unsafe { clock_gettime_nsec_np(4) };
    let sum = run(2_000_000);
    let end = unsafe { clock_gettime_nsec_np(4) };
    println!("checksum={sum}");
    println!("elapsed_ns={}", end - start);
}
