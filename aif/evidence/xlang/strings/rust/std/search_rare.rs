unsafe extern "C" {
    fn clock_gettime_nsec_np(clk: i32) -> u64;
}

fn run(hay: &mut String, needle: &mut String, reps: usize) -> i64 {
    let mut sum = 0i64;
    let len = hay.len();
    for k in 0..reps {
        unsafe {
            hay.as_bytes_mut()[k % len] = b'a' + (k % 10) as u8;
            needle.as_bytes_mut()[0] = b'b' + (k % 5) as u8;
        }
        sum += hay.find(needle.as_str()).map_or(-1, |at| at as i64);
    }
    sum
}

fn main() {
    let mut hay = "abcdefghij".repeat(4_000);
    let mut needle = "ajia".to_string();
    assert!(run(&mut hay, &mut needle, 1_000) <= 0);
    let start = unsafe { clock_gettime_nsec_np(4) };
    let sum = run(&mut hay, &mut needle, 200_000);
    let end = unsafe { clock_gettime_nsec_np(4) };
    println!("checksum={sum}");
    println!("elapsed_ns={}", end - start);
}
