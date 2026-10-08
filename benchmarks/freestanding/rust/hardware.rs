use core::sync::atomic::{AtomicU32, Ordering};

const WORD: usize = 0x44100000;
const LOCK: usize = 0x44100010;
const COUNTER: usize = 0x44100020;
const REGISTERS: usize = 0x44200000;

#[no_mangle]
pub extern "C" fn bench_atomic_counter(scale: u32) -> u32 {
    unsafe {
        (WORD as *mut u32).write_volatile(0);
        let word = &*(WORD as *const AtomicU32);
        for i in 0..500000 * scale {
            word.fetch_add(1 + (i & 3), Ordering::SeqCst);
        }
        word.load(Ordering::SeqCst)
    }
}

#[no_mangle]
pub extern "C" fn bench_spinlock(scale: u32) -> u32 {
    unsafe {
        (LOCK as *mut u32).write_volatile(0);
        (COUNTER as *mut u32).write_volatile(0);
        let lock = &*(LOCK as *const AtomicU32);
        let counter = COUNTER as *mut u32;
        for _ in 0..800000 * scale {
            while lock
                .compare_exchange(0, 1, Ordering::SeqCst, Ordering::SeqCst)
                .is_err()
            {}
            counter.write(counter.read().wrapping_add(1));
            lock.store(0, Ordering::SeqCst);
        }
        counter.read()
    }
}

#[no_mangle]
pub extern "C" fn bench_volatile_registers(scale: u32) -> u32 {
    unsafe {
        for i in 0..64usize {
            ((REGISTERS + i * 4) as *mut u32).write_volatile(0);
        }
        let mut acc: u32 = 0;
        for i in 0..900000 * scale {
            let slot = ((i.wrapping_mul(7)) & 63) as usize;
            let v = ((REGISTERS + slot * 4) as *const u32).read_volatile();
            ((REGISTERS + slot * 4) as *mut u32).write_volatile(v.wrapping_add(i));
            acc = acc.wrapping_add(v);
        }
        let mut sum: u32 = 0;
        for i in 0..64usize {
            sum = sum.wrapping_add(((REGISTERS + i * 4) as *const u32).read_volatile());
        }
        acc ^ sum
    }
}
