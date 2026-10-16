use crate::common::BENCH_MOD;

fn adversarial_next(seed: i64) -> i64 {
    (seed * 48271) % 2147483647
}

struct AdversarialObject {
    a: i32,
    b: i32,
    c: i32,
    d: i32,
}

struct LayoutParticle {
    x: i32,
    y: i32,
    z: i32,
    velocity: i32,
    mass: i32,
}

fn make_adversarial_object(value: i32) -> AdversarialObject {
    AdversarialObject { a: value, b: value + 1, c: value + 2, d: value + 3 }
}

fn consume_adversarial_object(value: AdversarialObject) -> i32 {
    (value.a * 3 + value.b * 5 + value.c * 7 + value.d * 11) % 1009
}

fn tiny_add(a: i32, b: i32) -> i32 { a + b }
fn indirect_add(value: i32) -> i32 { value + 3 }
fn indirect_mul(value: i32) -> i32 { value * 3 + 1 }
fn indirect_xor(value: i32) -> i32 { value ^ 341 }
fn indirect_mix(value: i32) -> i32 { (value * 17 + 23) % 1009 }

fn indirect_dispatch(operation: i32, value: i32) -> i32 {
    if operation == 0 { return indirect_add(value); }
    if operation == 1 { return indirect_mul(value); }
    if operation == 2 { return indirect_xor(value); }
    indirect_mix(value)
}

fn switch_case(operation: i32, value: i32) -> i32 {
    match operation {
        0 => (value + 19) % 1009,
        1 => (value + 92) % 1009,
        2 => (value + 165) % 1009,
        3 => (value + 238) % 1009,
        4 => (value + 311) % 1009,
        5 => (value + 384) % 1009,
        6 => (value + 457) % 1009,
        7 => (value + 530) % 1009,
        8 => (value + 603) % 1009,
        9 => (value + 676) % 1009,
        10 => (value + 749) % 1009,
        11 => (value + 822) % 1009,
        12 => (value + 895) % 1009,
        13 => (value + 968) % 1009,
        14 => (value + 32) % 1009,
        15 => (value + 105) % 1009,
        16 => (value + 178) % 1009,
        17 => (value + 251) % 1009,
        18 => (value + 324) % 1009,
        19 => (value + 397) % 1009,
        20 => (value + 470) % 1009,
        21 => (value + 543) % 1009,
        22 => (value + 616) % 1009,
        23 => (value + 689) % 1009,
        24 => (value + 762) % 1009,
        25 => (value + 835) % 1009,
        26 => (value + 908) % 1009,
        27 => (value + 981) % 1009,
        28 => (value + 45) % 1009,
        29 => (value + 118) % 1009,
        30 => (value + 191) % 1009,
        31 => (value + 264) % 1009,
        32 => (value + 337) % 1009,
        33 => (value + 410) % 1009,
        34 => (value + 483) % 1009,
        35 => (value + 556) % 1009,
        36 => (value + 629) % 1009,
        37 => (value + 702) % 1009,
        38 => (value + 775) % 1009,
        39 => (value + 848) % 1009,
        40 => (value + 921) % 1009,
        41 => (value + 994) % 1009,
        42 => (value + 58) % 1009,
        43 => (value + 131) % 1009,
        44 => (value + 204) % 1009,
        45 => (value + 277) % 1009,
        46 => (value + 350) % 1009,
        47 => (value + 423) % 1009,
        48 => (value + 496) % 1009,
        49 => (value + 569) % 1009,
        50 => (value + 642) % 1009,
        51 => (value + 715) % 1009,
        52 => (value + 788) % 1009,
        53 => (value + 861) % 1009,
        54 => (value + 934) % 1009,
        55 => (value + 1007) % 1009,
        56 => (value + 71) % 1009,
        57 => (value + 144) % 1009,
        58 => (value + 217) % 1009,
        59 => (value + 290) % 1009,
        60 => (value + 363) % 1009,
        61 => (value + 436) % 1009,
        62 => (value + 509) % 1009,
        63 => (value + 582) % 1009,
        64 => (value + 655) % 1009,
        65 => (value + 728) % 1009,
        66 => (value + 801) % 1009,
        67 => (value + 874) % 1009,
        68 => (value + 947) % 1009,
        69 => (value + 11) % 1009,
        70 => (value + 84) % 1009,
        71 => (value + 157) % 1009,
        72 => (value + 230) % 1009,
        73 => (value + 303) % 1009,
        74 => (value + 376) % 1009,
        75 => (value + 449) % 1009,
        76 => (value + 522) % 1009,
        77 => (value + 595) % 1009,
        78 => (value + 668) % 1009,
        79 => (value + 741) % 1009,
        80 => (value + 814) % 1009,
        81 => (value + 887) % 1009,
        82 => (value + 960) % 1009,
        83 => (value + 24) % 1009,
        84 => (value + 97) % 1009,
        85 => (value + 170) % 1009,
        86 => (value + 243) % 1009,
        87 => (value + 316) % 1009,
        88 => (value + 389) % 1009,
        89 => (value + 462) % 1009,
        90 => (value + 535) % 1009,
        91 => (value + 608) % 1009,
        92 => (value + 681) % 1009,
        93 => (value + 754) % 1009,
        94 => (value + 827) % 1009,
        95 => (value + 900) % 1009,
        96 => (value + 973) % 1009,
        97 => (value + 37) % 1009,
        98 => (value + 110) % 1009,
        99 => (value + 183) % 1009,
        100 => (value + 256) % 1009,
        101 => (value + 329) % 1009,
        102 => (value + 402) % 1009,
        103 => (value + 475) % 1009,
        104 => (value + 548) % 1009,
        105 => (value + 621) % 1009,
        106 => (value + 694) % 1009,
        107 => (value + 767) % 1009,
        108 => (value + 840) % 1009,
        109 => (value + 913) % 1009,
        110 => (value + 986) % 1009,
        111 => (value + 50) % 1009,
        112 => (value + 123) % 1009,
        113 => (value + 196) % 1009,
        114 => (value + 269) % 1009,
        115 => (value + 342) % 1009,
        116 => (value + 415) % 1009,
        117 => (value + 488) % 1009,
        118 => (value + 561) % 1009,
        119 => (value + 634) % 1009,
        120 => (value + 707) % 1009,
        121 => (value + 780) % 1009,
        122 => (value + 853) % 1009,
        123 => (value + 926) % 1009,
        124 => (value + 999) % 1009,
        125 => (value + 63) % 1009,
        126 => (value + 136) % 1009,
        127 => (value + 209) % 1009,
        128 => (value + 282) % 1009,
        129 => (value + 355) % 1009,
        130 => (value + 428) % 1009,
        131 => (value + 501) % 1009,
        132 => (value + 574) % 1009,
        133 => (value + 647) % 1009,
        134 => (value + 720) % 1009,
        135 => (value + 793) % 1009,
        136 => (value + 866) % 1009,
        137 => (value + 939) % 1009,
        138 => (value + 3) % 1009,
        139 => (value + 76) % 1009,
        140 => (value + 149) % 1009,
        141 => (value + 222) % 1009,
        142 => (value + 295) % 1009,
        143 => (value + 368) % 1009,
        144 => (value + 441) % 1009,
        145 => (value + 514) % 1009,
        146 => (value + 587) % 1009,
        147 => (value + 660) % 1009,
        148 => (value + 733) % 1009,
        149 => (value + 806) % 1009,
        150 => (value + 879) % 1009,
        151 => (value + 952) % 1009,
        152 => (value + 16) % 1009,
        153 => (value + 89) % 1009,
        154 => (value + 162) % 1009,
        155 => (value + 235) % 1009,
        156 => (value + 308) % 1009,
        157 => (value + 381) % 1009,
        158 => (value + 454) % 1009,
        159 => (value + 527) % 1009,
        160 => (value + 600) % 1009,
        161 => (value + 673) % 1009,
        162 => (value + 746) % 1009,
        163 => (value + 819) % 1009,
        164 => (value + 892) % 1009,
        165 => (value + 965) % 1009,
        166 => (value + 29) % 1009,
        167 => (value + 102) % 1009,
        168 => (value + 175) % 1009,
        169 => (value + 248) % 1009,
        170 => (value + 321) % 1009,
        171 => (value + 394) % 1009,
        172 => (value + 467) % 1009,
        173 => (value + 540) % 1009,
        174 => (value + 613) % 1009,
        175 => (value + 686) % 1009,
        176 => (value + 759) % 1009,
        177 => (value + 832) % 1009,
        178 => (value + 905) % 1009,
        179 => (value + 978) % 1009,
        180 => (value + 42) % 1009,
        181 => (value + 115) % 1009,
        182 => (value + 188) % 1009,
        183 => (value + 261) % 1009,
        184 => (value + 334) % 1009,
        185 => (value + 407) % 1009,
        186 => (value + 480) % 1009,
        187 => (value + 553) % 1009,
        188 => (value + 626) % 1009,
        189 => (value + 699) % 1009,
        190 => (value + 772) % 1009,
        191 => (value + 845) % 1009,
        192 => (value + 918) % 1009,
        193 => (value + 991) % 1009,
        194 => (value + 55) % 1009,
        195 => (value + 128) % 1009,
        196 => (value + 201) % 1009,
        197 => (value + 274) % 1009,
        198 => (value + 347) % 1009,
        199 => (value + 420) % 1009,
        200 => (value + 493) % 1009,
        201 => (value + 566) % 1009,
        202 => (value + 639) % 1009,
        203 => (value + 712) % 1009,
        204 => (value + 785) % 1009,
        205 => (value + 858) % 1009,
        206 => (value + 931) % 1009,
        207 => (value + 1004) % 1009,
        208 => (value + 68) % 1009,
        209 => (value + 141) % 1009,
        210 => (value + 214) % 1009,
        211 => (value + 287) % 1009,
        212 => (value + 360) % 1009,
        213 => (value + 433) % 1009,
        214 => (value + 506) % 1009,
        215 => (value + 579) % 1009,
        216 => (value + 652) % 1009,
        217 => (value + 725) % 1009,
        218 => (value + 798) % 1009,
        219 => (value + 871) % 1009,
        220 => (value + 944) % 1009,
        221 => (value + 8) % 1009,
        222 => (value + 81) % 1009,
        223 => (value + 154) % 1009,
        224 => (value + 227) % 1009,
        225 => (value + 300) % 1009,
        226 => (value + 373) % 1009,
        227 => (value + 446) % 1009,
        228 => (value + 519) % 1009,
        229 => (value + 592) % 1009,
        230 => (value + 665) % 1009,
        231 => (value + 738) % 1009,
        232 => (value + 811) % 1009,
        233 => (value + 884) % 1009,
        234 => (value + 957) % 1009,
        235 => (value + 21) % 1009,
        236 => (value + 94) % 1009,
        237 => (value + 167) % 1009,
        238 => (value + 240) % 1009,
        239 => (value + 313) % 1009,
        240 => (value + 386) % 1009,
        241 => (value + 459) % 1009,
        242 => (value + 532) % 1009,
        243 => (value + 605) % 1009,
        244 => (value + 678) % 1009,
        245 => (value + 751) % 1009,
        246 => (value + 824) % 1009,
        247 => (value + 897) % 1009,
        248 => (value + 970) % 1009,
        249 => (value + 34) % 1009,
        250 => (value + 107) % 1009,
        251 => (value + 180) % 1009,
        252 => (value + 253) % 1009,
        253 => (value + 326) % 1009,
        254 => (value + 399) % 1009,
        255 => (value + 472) % 1009,
        _ => 0,
    }
}

fn dead_kernel(value: i32) -> i32 {
    let mut x = (value * 17 + 3) % 1009;
    x = (x * x + 11) % 1009;
    x = (x * 37 + 19) % 1009;
    x = (x * x + value % 97) % 1009;
    x
}

pub fn pointer_chase(scale: i32) -> i32 {
    let n = (131072 * scale) as usize;
    let mut nodes = vec![0i32; n];
    let values: Vec<i32> = (0..n).map(|i| (i as i32 * 37 + 11) % 251).collect();
    let mut permutation: Vec<i32> = (0..n as i32).collect();

    let mut seed = 1i64;
    for at in (1..n).rev() {
        seed = adversarial_next(seed);
        let other = (seed % (at as i64 + 1)) as usize;
        permutation.swap(at, other);
    }
    for link in 0..n {
        nodes[permutation[link] as usize] = permutation[(link + 1) % n];
    }

    let mut index = permutation[0] as usize;
    let mut sum = 0;
    for _ in 0..n * 8 {
        index = nodes[index] as usize;
        sum = (sum + values[index]) % BENCH_MOD;
    }
    sum
}

pub fn random_gather(scale: i32) -> i32 {
    let n = (262144 * scale) as usize;
    let values: Vec<i32> = (0..n).map(|i| (i as i32 * 53 + 17) % 4093).collect();
    let mut indices = Vec::with_capacity(n);
    let mut seed = 7i64;
    for _ in 0..n {
        seed = adversarial_next(seed);
        indices.push((seed % n as i64) as usize);
    }

    let mut sum = 0;
    for _ in 0..8 {
        for &index in &indices {
            sum = (sum + values[index]) % BENCH_MOD;
        }
    }
    sum
}

pub fn branch_mispredict(scale: i32) -> i32 {
    let n = (500000 * scale) as usize;
    let mut conditions = Vec::with_capacity(n);
    let mut a = Vec::with_capacity(n);
    let mut b = Vec::with_capacity(n);
    let mut seed = 19i64;
    for i in 0..n {
        seed = adversarial_next(seed);
        conditions.push((seed % 2 == 0) as u8);
        a.push((i as i32 * 13 + 5) % 997);
        b.push((i as i32 * 29 + 3) % 991);
    }

    let mut sum = 0;
    for _ in 0..6 {
        for k in 0..n {
            if conditions[k] != 0 {
                sum = (sum + a[k]) % BENCH_MOD;
            } else {
                sum = (sum + b[k]) % BENCH_MOD;
            }
        }
    }
    sum
}

pub fn strided_memory(scale: i32) -> i32 {
    let n = (1048576 * scale) as usize;
    let data: Vec<i32> = (0..n).map(|i| (i as i32 * 17 + 23) % 1009).collect();
    let strides = [1usize, 2, 4, 8, 16, 32, 64, 128];

    let mut sum = 0;
    for stride in strides {
        let rounds = stride.min(16);
        for round in 0..rounds {
            let mut at = round % stride;
            while at < n {
                sum = (sum + data[at]) % BENCH_MOD;
                at += stride;
            }
        }
    }
    sum
}

pub fn allocation_escape(scale: i32) -> i32 {
    let n = 1000000 * scale;
    let mut sum = 0;
    for i in 0..n {
        let value = make_adversarial_object(i % 1000);
        sum = (sum + consume_adversarial_object(value)) % BENCH_MOD;
    }
    sum
}

pub fn function_call_overhead(scale: i32) -> i32 {
    let n = 5000000 * scale;
    let mut state = 0;
    for i in 0..n {
        state = tiny_add(state, i % 97);
        if state >= BENCH_MOD { state -= BENCH_MOD; }
    }
    state
}

pub fn indirect_calls(scale: i32) -> i32 {
    let n = (262144 * scale) as usize;
    let mut operations = Vec::with_capacity(n);
    let mut seed = 37i64;
    for _ in 0..n {
        seed = adversarial_next(seed);
        operations.push((seed % 4) as i32);
    }

    let mut sum = 0;
    for _ in 0..8 {
        for k in 0..n {
            sum = (sum + indirect_dispatch(operations[k], k as i32 % 1000)) % BENCH_MOD;
        }
    }
    sum
}

pub fn dependency_chain(scale: i32) -> i32 {
    let n = 5000000 * scale;
    let mut state = 123456789u32;
    for _ in 0..n {
        state = state.wrapping_mul(1664525).wrapping_add(1013904223);
    }
    (state & 2147483647) as i32
}

pub fn aos_vs_soa(scale: i32) -> i32 {
    let n = (100000 * scale) as usize;
    const ROUNDS: usize = 20;
    let mut particles = Vec::with_capacity(n);
    for i in 0..n {
        let i = i as i32;
        particles.push(LayoutParticle {
            x: i % 1009,
            y: i % 509,
            z: i % 257,
            velocity: i % 17 + 1,
            mass: i % 31 + 1,
        });
    }

    for _ in 0..ROUNDS {
        for particle in &mut particles {
            particle.x += particle.velocity;
            particle.y += particle.mass;
            particle.z += particle.velocity + particle.mass;
        }
    }

    let mut aos = 0;
    for particle in &particles {
        aos = (aos + particle.x + particle.y + particle.z) % BENCH_MOD;
    }

    let mut x = Vec::with_capacity(n);
    let mut y = Vec::with_capacity(n);
    let mut z = Vec::with_capacity(n);
    let mut velocity = Vec::with_capacity(n);
    let mut mass = Vec::with_capacity(n);
    for i in 0..n {
        let i = i as i32;
        x.push(i % 1009);
        y.push(i % 509);
        z.push(i % 257);
        velocity.push(i % 17 + 1);
        mass.push(i % 31 + 1);
    }

    for _ in 0..ROUNDS {
        for i in 0..n {
            x[i] += velocity[i];
            y[i] += mass[i];
            z[i] += velocity[i] + mass[i];
        }
    }

    let mut soa = 0;
    for i in 0..n {
        soa = (soa + x[i] + y[i] + z[i]) % BENCH_MOD;
    }
    if aos == soa { aos } else { -1 }
}

pub fn switch_dispatch(scale: i32) -> i32 {
    let n = (250000 * scale) as usize;
    let mut sequential = Vec::with_capacity(n);
    let mut randomized = Vec::with_capacity(n);
    let mut biased = Vec::with_capacity(n);
    let mut seed = 97i64;
    for i in 0..n {
        sequential.push(i as i32 % 256);
        seed = adversarial_next(seed);
        randomized.push((seed % 256) as i32);
        biased.push(if seed % 20 == 0 { (seed % 256) as i32 } else { 7 });
    }

    let mut sum = 0;
    for _ in 0..3 {
        for k in 0..n {
            sum = (sum + switch_case(sequential[k], k as i32 % 1009)) % BENCH_MOD;
            sum = (sum + switch_case(randomized[k], k as i32 % 1009)) % BENCH_MOD;
            sum = (sum + switch_case(biased[k], k as i32 % 1009)) % BENCH_MOD;
        }
    }
    sum
}

pub fn memcpy_mix(scale: i32) -> i32 {
    let sizes = [2usize, 4, 8, 16, 64, 1024, 16384];
    let mut checksum = 0;
    for count in sizes {
        let mut source: Vec<i32> = (0..count).map(|i| (i as i32 * 31 + count as i32) % 4093).collect();
        let mut target = vec![0i32; count];
        let repeats = (65536 / count) * scale as usize;
        for repeat in 0..repeats {
            for k in 0..count { target[k] = source[k]; }
            target[repeat % count] += 1;
            for k in 0..count { source[k] = target[k]; }
            source[(repeat * 3) % count] += 1;
        }
        for i in 0..count {
            checksum = (checksum + source[i] + target[i]) % BENCH_MOD;
        }
    }
    checksum
}

pub fn dead_code_elimination(scale: i32) -> i32 {
    let n = 5000000 * scale;
    for i in 0..n { let _dead = dead_kernel(i); }
    17
}

// Same program as prismio/adversarial.psm's register_pressure_torture.
pub fn register_pressure_torture(scale: i32) -> i32 {
    let mut s0: u32 = 40503;
    let mut s1: u32 = 81006;
    let mut s2: u32 = 121509;
    let mut s3: u32 = 162012;
    let mut s4: u32 = 202515;
    let mut s5: u32 = 243018;
    let mut s6: u32 = 283521;
    let mut s7: u32 = 324024;
    let mut s8: u32 = 364527;
    let mut s9: u32 = 405030;
    let mut s10: u32 = 445533;
    let mut s11: u32 = 486036;
    let mut s12: u32 = 526539;
    let mut s13: u32 = 567042;
    let mut s14: u32 = 607545;
    let mut s15: u32 = 648048;
    let mut s16: u32 = 688551;
    let mut s17: u32 = 729054;
    let mut s18: u32 = 769557;
    let mut s19: u32 = 810060;
    let mut s20: u32 = 850563;
    let mut s21: u32 = 891066;
    let mut s22: u32 = 931569;
    let mut s23: u32 = 972072;
    let mut s24: u32 = 1012575;
    let mut s25: u32 = 1053078;
    let mut s26: u32 = 1093581;
    let mut s27: u32 = 1134084;
    let mut s28: u32 = 1174587;
    let mut s29: u32 = 1215090;
    let mut s30: u32 = 1255593;
    let mut s31: u32 = 1296096;
    let mut s32: u32 = 1336599;
    let mut s33: u32 = 1377102;
    let mut s34: u32 = 1417605;
    let mut s35: u32 = 1458108;
    let mut s36: u32 = 1498611;
    let mut s37: u32 = 1539114;
    let mut s38: u32 = 1579617;
    let mut s39: u32 = 1620120;
    let rounds = 100000 * scale;
    for r in 0..rounds {
        s0 = s0.wrapping_add(s39 ^ (s19 >> 3)).wrapping_add(1);
        s0 ^= s7 << 5;
        s1 = s1.wrapping_add(s0 ^ (s20 >> 3)).wrapping_add(3);
        s1 ^= s8 << 5;
        s2 = s2.wrapping_add(s1 ^ (s21 >> 3)).wrapping_add(5);
        s2 ^= s9 << 5;
        s3 = s3.wrapping_add(s2 ^ (s22 >> 3)).wrapping_add(7);
        s3 ^= s10 << 5;
        s4 = s4.wrapping_add(s3 ^ (s23 >> 3)).wrapping_add(9);
        s4 ^= s11 << 5;
        s5 = s5.wrapping_add(s4 ^ (s24 >> 3)).wrapping_add(11);
        s5 ^= s12 << 5;
        s6 = s6.wrapping_add(s5 ^ (s25 >> 3)).wrapping_add(13);
        s6 ^= s13 << 5;
        s7 = s7.wrapping_add(s6 ^ (s26 >> 3)).wrapping_add(15);
        s7 ^= s14 << 5;
        s8 = s8.wrapping_add(s7 ^ (s27 >> 3)).wrapping_add(17);
        s8 ^= s15 << 5;
        s9 = s9.wrapping_add(s8 ^ (s28 >> 3)).wrapping_add(19);
        s9 ^= s16 << 5;
        s10 = s10.wrapping_add(s9 ^ (s29 >> 3)).wrapping_add(21);
        s10 ^= s17 << 5;
        s11 = s11.wrapping_add(s10 ^ (s30 >> 3)).wrapping_add(23);
        s11 ^= s18 << 5;
        s12 = s12.wrapping_add(s11 ^ (s31 >> 3)).wrapping_add(25);
        s12 ^= s19 << 5;
        s13 = s13.wrapping_add(s12 ^ (s32 >> 3)).wrapping_add(27);
        s13 ^= s20 << 5;
        s14 = s14.wrapping_add(s13 ^ (s33 >> 3)).wrapping_add(29);
        s14 ^= s21 << 5;
        s15 = s15.wrapping_add(s14 ^ (s34 >> 3)).wrapping_add(31);
        s15 ^= s22 << 5;
        s16 = s16.wrapping_add(s15 ^ (s35 >> 3)).wrapping_add(33);
        s16 ^= s23 << 5;
        s17 = s17.wrapping_add(s16 ^ (s36 >> 3)).wrapping_add(35);
        s17 ^= s24 << 5;
        s18 = s18.wrapping_add(s17 ^ (s37 >> 3)).wrapping_add(37);
        s18 ^= s25 << 5;
        s19 = s19.wrapping_add(s18 ^ (s38 >> 3)).wrapping_add(39);
        s19 ^= s26 << 5;
        s20 = s20.wrapping_add(s19 ^ (s39 >> 3)).wrapping_add(41);
        s20 ^= s27 << 5;
        s21 = s21.wrapping_add(s20 ^ (s0 >> 3)).wrapping_add(43);
        s21 ^= s28 << 5;
        s22 = s22.wrapping_add(s21 ^ (s1 >> 3)).wrapping_add(45);
        s22 ^= s29 << 5;
        s23 = s23.wrapping_add(s22 ^ (s2 >> 3)).wrapping_add(47);
        s23 ^= s30 << 5;
        s24 = s24.wrapping_add(s23 ^ (s3 >> 3)).wrapping_add(49);
        s24 ^= s31 << 5;
        s25 = s25.wrapping_add(s24 ^ (s4 >> 3)).wrapping_add(51);
        s25 ^= s32 << 5;
        s26 = s26.wrapping_add(s25 ^ (s5 >> 3)).wrapping_add(53);
        s26 ^= s33 << 5;
        s27 = s27.wrapping_add(s26 ^ (s6 >> 3)).wrapping_add(55);
        s27 ^= s34 << 5;
        s28 = s28.wrapping_add(s27 ^ (s7 >> 3)).wrapping_add(57);
        s28 ^= s35 << 5;
        s29 = s29.wrapping_add(s28 ^ (s8 >> 3)).wrapping_add(59);
        s29 ^= s36 << 5;
        s30 = s30.wrapping_add(s29 ^ (s9 >> 3)).wrapping_add(61);
        s30 ^= s37 << 5;
        s31 = s31.wrapping_add(s30 ^ (s10 >> 3)).wrapping_add(63);
        s31 ^= s38 << 5;
        s32 = s32.wrapping_add(s31 ^ (s11 >> 3)).wrapping_add(65);
        s32 ^= s39 << 5;
        s33 = s33.wrapping_add(s32 ^ (s12 >> 3)).wrapping_add(67);
        s33 ^= s0 << 5;
        s34 = s34.wrapping_add(s33 ^ (s13 >> 3)).wrapping_add(69);
        s34 ^= s1 << 5;
        s35 = s35.wrapping_add(s34 ^ (s14 >> 3)).wrapping_add(71);
        s35 ^= s2 << 5;
        s36 = s36.wrapping_add(s35 ^ (s15 >> 3)).wrapping_add(73);
        s36 ^= s3 << 5;
        s37 = s37.wrapping_add(s36 ^ (s16 >> 3)).wrapping_add(75);
        s37 ^= s4 << 5;
        s38 = s38.wrapping_add(s37 ^ (s17 >> 3)).wrapping_add(77);
        s38 ^= s5 << 5;
        s39 = s39.wrapping_add(s38 ^ (s18 >> 3)).wrapping_add(79);
        s39 ^= s6 << 5;
        s0 = s0.wrapping_add(r as u32);
    }
    let mut checksum: i64 = 0;
    checksum = (checksum * 31 + (s0 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s1 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s2 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s3 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s4 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s5 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s6 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s7 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s8 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s9 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s10 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s11 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s12 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s13 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s14 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s15 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s16 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s17 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s18 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s19 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s20 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s21 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s22 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s23 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s24 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s25 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s26 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s27 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s28 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s29 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s30 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s31 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s32 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s33 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s34 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s35 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s36 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s37 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s38 & 2147483647) as i64) % 1000000007;
    checksum = (checksum * 31 + (s39 & 2147483647) as i64) % 1000000007;
    checksum as i32
}
