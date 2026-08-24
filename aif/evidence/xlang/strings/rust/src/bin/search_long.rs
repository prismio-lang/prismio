use memchr::memmem;

unsafe extern "C" {
    fn clock_gettime_nsec_np(clk: i32) -> u64;
}

fn run(hay: &str, needle: &mut String, reps: usize) -> i64 {
    let mut sum = 0i64;
    for k in 0..reps {
        unsafe {
            needle.as_bytes_mut()[33] = b'x' + (k % 2) as u8;
        }
        sum += memmem::find(hay.as_bytes(), needle.as_bytes()).map_or(-1, |at| at as i64);
    }
    sum
}

fn main() {
    let hay = "abcdefghij".repeat(4_000);
    let mut needle = "abcdefghij".repeat(4);
    assert_eq!(-100, run(&hay, &mut needle, 100));
    let start = unsafe { clock_gettime_nsec_np(4) };
    let sum = run(&hay, &mut needle, 100_000);
    let end = unsafe { clock_gettime_nsec_np(4) };
    println!("checksum={sum}");
    println!("elapsed_ns={}", end - start);
}
