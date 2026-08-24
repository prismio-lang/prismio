unsafe extern "C" {
    fn clock_gettime_nsec_np(clk: i32) -> u64;
}

fn run(base: &mut String, reps: usize) -> i64 {
    let mut sum = 0i64;
    let len = base.len();
    for k in 0..reps {
        let at = k % len;
        unsafe { base.as_bytes_mut()[at] = b'a' + (k % 26) as u8; }
        let upper = base.to_ascii_uppercase();
        sum += upper.as_bytes()[at] as i64;
    }
    sum
}

fn main() {
    let mut base = "abcdefghij".repeat(4_000);
    assert!(run(&mut base, 2_000) >= 0);
    let start = unsafe { clock_gettime_nsec_np(4) };
    let sum = run(&mut base, 400_000);
    let end = unsafe { clock_gettime_nsec_np(4) };
    println!("checksum={sum}");
    println!("elapsed_ns={}", end - start);
}
