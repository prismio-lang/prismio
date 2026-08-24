unsafe extern "C" {
    fn clock_gettime_nsec_np(clk: i32) -> u64;
}

fn run(a: &mut String, b: &str, reps: usize) -> i64 {
    let mut sum = 0i64;
    let len = a.len();
    for k in 0..reps {
        let at = k % len;
        unsafe { a.as_bytes_mut()[at] = b'a' + (k % 26) as u8; }
        let joined = [a.as_str(), b].concat();
        sum += joined.as_bytes()[at] as i64;
        sum += joined.as_bytes()[len + at] as i64;
    }
    sum
}

fn main() {
    let mut a = "abcdefghij".repeat(2_000);
    let b = "klmnopqrst".repeat(2_000);
    assert!(run(&mut a, &b, 2_000) >= 0);
    let start = unsafe { clock_gettime_nsec_np(4) };
    let sum = run(&mut a, &b, 400_000);
    let end = unsafe { clock_gettime_nsec_np(4) };
    println!("checksum={sum}");
    println!("elapsed_ns={}", end - start);
}
