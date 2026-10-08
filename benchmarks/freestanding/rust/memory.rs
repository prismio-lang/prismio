use crate::lcg;

const CHAIN: usize = 2048;

#[no_mangle]
pub extern "C" fn bench_pointer_chase(scale: u32) -> u32 {
    let mut order = [0u32; CHAIN];
    let mut next = [0u32; CHAIN];
    for i in 0..CHAIN {
        order[i] = i as u32;
    }
    let mut s: u32 = 9001;
    let mut i = CHAIN - 1;
    while i > 0 {
        let j = (lcg(&mut s) >> 8) % (i as u32 + 1);
        let t = order[i];
        order[i] = order[j as usize];
        order[j as usize] = t;
        i -= 1;
    }
    for k in 0..CHAIN {
        next[order[k] as usize] = order[(k + 1) % CHAIN];
    }
    let mut at = order[0];
    let mut sum: u32 = 0;
    for _ in 0..2400000 * scale {
        at = next[at as usize];
        sum = sum.wrapping_add(at);
    }
    sum
}

const RING: usize = 1024;

#[no_mangle]
pub extern "C" fn bench_ring_buffer(scale: u32) -> u32 {
    let mut slots = [0u32; RING];
    let mut head: u32 = 0;
    let mut tail: u32 = 0;
    let mut s: u32 = 321;
    let mut sum: u32 = 0;
    let mut popped: u32 = 0;
    for _ in 0..300000 * scale {
        lcg(&mut s);
        if head.wrapping_sub(tail) < RING as u32 {
            slots[(head & (RING as u32 - 1)) as usize] = s;
            head = head.wrapping_add(1);
        }
        if ((s >> 8) & 1) == 0 && head != tail {
            sum = sum.wrapping_add(slots[(tail & (RING as u32 - 1)) as usize]);
            tail = tail.wrapping_add(1);
            popped += 1;
        }
    }
    sum ^ popped
}

const SRC: usize = 0x44000000;
const DST: usize = 0x45000000;
const BLOCK: usize = 32768;

#[no_mangle]
pub extern "C" fn bench_mem_copy(scale: u32) -> u32 {
    unsafe {
        let mut o = 0;
        while o < BLOCK {
            ((SRC + o) as *mut u64).write((o as u64).wrapping_mul(0x9E3779B97F4A7C15) ^ 0x5555);
            o += 8;
        }
        for r in 0..288 * scale {
            let mut o = 0;
            while o < BLOCK {
                let v = ((SRC + o) as *const u64).read();
                ((DST + o) as *mut u64).write(v);
                ((SRC + o) as *mut u64).write(v.wrapping_add(r as u64).wrapping_add(1));
                o += 8;
            }
        }
        let mut sum: u64 = 0;
        let mut o = 0;
        while o < BLOCK {
            sum = sum.wrapping_add(((DST + o) as *const u64).read());
            o += 8;
        }
        (sum as u32) ^ ((sum >> 32) as u32)
    }
}
