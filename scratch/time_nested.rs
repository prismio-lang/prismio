use std::time::Instant;

const BENCH_MOD: i32 = 1000000007;

fn main() {
    let scale = 4;
    let t0 = Instant::now();
    let count = 200 * scale; 
    let mut buckets = Vec::with_capacity(count as usize);
    for b in 0..count { 
        let mut values = Vec::with_capacity(1000); 
        for i in 0..1000 { 
            values.push((b + i) % 1021); 
        } 
        buckets.push(values); 
    }
    let t1 = Instant::now();
    let mut checksum = 0; 
    for bucket in &buckets { 
        for &value in bucket { 
            checksum = (checksum + value) % BENCH_MOD; 
        } 
    } 
    let t2 = Instant::now();
    drop(buckets);
    let t3 = Instant::now();

    println!("Rust Creation:  {} ns", (t1 - t0).as_nanos());
    println!("Rust Traversal: {} ns", (t2 - t1).as_nanos());
    println!("Rust Drop:      {} ns", (t3 - t2).as_nanos());
    println!("Rust Total:     {} ns", (t3 - t0).as_nanos());
    println!("Checksum:       {}", checksum);
}
