unsafe extern "C" {
    fn clock_gettime_nsec_np(clk: i32) -> u64;
}

fn run(hay: &str, needle: &mut String, reps: usize) -> i64 {
    let mut sum = 0i64;
    for k in 0..reps {
        unsafe { needle.as_bytes_mut()[2] = b'c' + (k % 2) as u8; }
        sum += hay.find(needle.as_str()).map_or(-1, |at| at as i64);
    }
    sum
}

fn main() {
    let hay = "jzxe".repeat(10_000);
    let mut needle = "jzce".to_string();
    assert_eq!(-100, run(&hay, &mut needle, 100));
    let start = unsafe { clock_gettime_nsec_np(4) };
    let sum = run(&hay, &mut needle, 20_000);
    let end = unsafe { clock_gettime_nsec_np(4) };
    println!("checksum={sum}");
    println!("elapsed_ns={}", end - start);
}
