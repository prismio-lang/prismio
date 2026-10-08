#include "benchmarks.hpp"

#include <algorithm>
#include <cstdint>
#include <vector>

namespace {

std::int64_t adversarial_next(std::int64_t seed) {
    return (seed * 48271) % 2147483647;
}

struct AdversarialObject {
    int a;
    int b;
    int c;
    int d;
};

struct LayoutParticle {
    int x;
    int y;
    int z;
    int velocity;
    int mass;
};

AdversarialObject make_adversarial_object(int value) {
    return {value, value + 1, value + 2, value + 3};
}

int consume_adversarial_object(AdversarialObject value) {
    return (value.a * 3 + value.b * 5 + value.c * 7 + value.d * 11) % 1009;
}

int tiny_add(int a, int b) { return a + b; }
int indirect_add(int value) { return value + 3; }
int indirect_mul(int value) { return value * 3 + 1; }
int indirect_xor(int value) { return value ^ 341; }
int indirect_mix(int value) { return (value * 17 + 23) % 1009; }

int indirect_dispatch(int operation, int value) {
    if (operation == 0) return indirect_add(value);
    if (operation == 1) return indirect_mul(value);
    if (operation == 2) return indirect_xor(value);
    return indirect_mix(value);
}

int switch_case(int operation, int value) {
    switch (operation) {
        case 0: return (value + 19) % 1009;
        case 1: return (value + 92) % 1009;
        case 2: return (value + 165) % 1009;
        case 3: return (value + 238) % 1009;
        case 4: return (value + 311) % 1009;
        case 5: return (value + 384) % 1009;
        case 6: return (value + 457) % 1009;
        case 7: return (value + 530) % 1009;
        case 8: return (value + 603) % 1009;
        case 9: return (value + 676) % 1009;
        case 10: return (value + 749) % 1009;
        case 11: return (value + 822) % 1009;
        case 12: return (value + 895) % 1009;
        case 13: return (value + 968) % 1009;
        case 14: return (value + 32) % 1009;
        case 15: return (value + 105) % 1009;
        case 16: return (value + 178) % 1009;
        case 17: return (value + 251) % 1009;
        case 18: return (value + 324) % 1009;
        case 19: return (value + 397) % 1009;
        case 20: return (value + 470) % 1009;
        case 21: return (value + 543) % 1009;
        case 22: return (value + 616) % 1009;
        case 23: return (value + 689) % 1009;
        case 24: return (value + 762) % 1009;
        case 25: return (value + 835) % 1009;
        case 26: return (value + 908) % 1009;
        case 27: return (value + 981) % 1009;
        case 28: return (value + 45) % 1009;
        case 29: return (value + 118) % 1009;
        case 30: return (value + 191) % 1009;
        case 31: return (value + 264) % 1009;
        case 32: return (value + 337) % 1009;
        case 33: return (value + 410) % 1009;
        case 34: return (value + 483) % 1009;
        case 35: return (value + 556) % 1009;
        case 36: return (value + 629) % 1009;
        case 37: return (value + 702) % 1009;
        case 38: return (value + 775) % 1009;
        case 39: return (value + 848) % 1009;
        case 40: return (value + 921) % 1009;
        case 41: return (value + 994) % 1009;
        case 42: return (value + 58) % 1009;
        case 43: return (value + 131) % 1009;
        case 44: return (value + 204) % 1009;
        case 45: return (value + 277) % 1009;
        case 46: return (value + 350) % 1009;
        case 47: return (value + 423) % 1009;
        case 48: return (value + 496) % 1009;
        case 49: return (value + 569) % 1009;
        case 50: return (value + 642) % 1009;
        case 51: return (value + 715) % 1009;
        case 52: return (value + 788) % 1009;
        case 53: return (value + 861) % 1009;
        case 54: return (value + 934) % 1009;
        case 55: return (value + 1007) % 1009;
        case 56: return (value + 71) % 1009;
        case 57: return (value + 144) % 1009;
        case 58: return (value + 217) % 1009;
        case 59: return (value + 290) % 1009;
        case 60: return (value + 363) % 1009;
        case 61: return (value + 436) % 1009;
        case 62: return (value + 509) % 1009;
        case 63: return (value + 582) % 1009;
        case 64: return (value + 655) % 1009;
        case 65: return (value + 728) % 1009;
        case 66: return (value + 801) % 1009;
        case 67: return (value + 874) % 1009;
        case 68: return (value + 947) % 1009;
        case 69: return (value + 11) % 1009;
        case 70: return (value + 84) % 1009;
        case 71: return (value + 157) % 1009;
        case 72: return (value + 230) % 1009;
        case 73: return (value + 303) % 1009;
        case 74: return (value + 376) % 1009;
        case 75: return (value + 449) % 1009;
        case 76: return (value + 522) % 1009;
        case 77: return (value + 595) % 1009;
        case 78: return (value + 668) % 1009;
        case 79: return (value + 741) % 1009;
        case 80: return (value + 814) % 1009;
        case 81: return (value + 887) % 1009;
        case 82: return (value + 960) % 1009;
        case 83: return (value + 24) % 1009;
        case 84: return (value + 97) % 1009;
        case 85: return (value + 170) % 1009;
        case 86: return (value + 243) % 1009;
        case 87: return (value + 316) % 1009;
        case 88: return (value + 389) % 1009;
        case 89: return (value + 462) % 1009;
        case 90: return (value + 535) % 1009;
        case 91: return (value + 608) % 1009;
        case 92: return (value + 681) % 1009;
        case 93: return (value + 754) % 1009;
        case 94: return (value + 827) % 1009;
        case 95: return (value + 900) % 1009;
        case 96: return (value + 973) % 1009;
        case 97: return (value + 37) % 1009;
        case 98: return (value + 110) % 1009;
        case 99: return (value + 183) % 1009;
        case 100: return (value + 256) % 1009;
        case 101: return (value + 329) % 1009;
        case 102: return (value + 402) % 1009;
        case 103: return (value + 475) % 1009;
        case 104: return (value + 548) % 1009;
        case 105: return (value + 621) % 1009;
        case 106: return (value + 694) % 1009;
        case 107: return (value + 767) % 1009;
        case 108: return (value + 840) % 1009;
        case 109: return (value + 913) % 1009;
        case 110: return (value + 986) % 1009;
        case 111: return (value + 50) % 1009;
        case 112: return (value + 123) % 1009;
        case 113: return (value + 196) % 1009;
        case 114: return (value + 269) % 1009;
        case 115: return (value + 342) % 1009;
        case 116: return (value + 415) % 1009;
        case 117: return (value + 488) % 1009;
        case 118: return (value + 561) % 1009;
        case 119: return (value + 634) % 1009;
        case 120: return (value + 707) % 1009;
        case 121: return (value + 780) % 1009;
        case 122: return (value + 853) % 1009;
        case 123: return (value + 926) % 1009;
        case 124: return (value + 999) % 1009;
        case 125: return (value + 63) % 1009;
        case 126: return (value + 136) % 1009;
        case 127: return (value + 209) % 1009;
        case 128: return (value + 282) % 1009;
        case 129: return (value + 355) % 1009;
        case 130: return (value + 428) % 1009;
        case 131: return (value + 501) % 1009;
        case 132: return (value + 574) % 1009;
        case 133: return (value + 647) % 1009;
        case 134: return (value + 720) % 1009;
        case 135: return (value + 793) % 1009;
        case 136: return (value + 866) % 1009;
        case 137: return (value + 939) % 1009;
        case 138: return (value + 3) % 1009;
        case 139: return (value + 76) % 1009;
        case 140: return (value + 149) % 1009;
        case 141: return (value + 222) % 1009;
        case 142: return (value + 295) % 1009;
        case 143: return (value + 368) % 1009;
        case 144: return (value + 441) % 1009;
        case 145: return (value + 514) % 1009;
        case 146: return (value + 587) % 1009;
        case 147: return (value + 660) % 1009;
        case 148: return (value + 733) % 1009;
        case 149: return (value + 806) % 1009;
        case 150: return (value + 879) % 1009;
        case 151: return (value + 952) % 1009;
        case 152: return (value + 16) % 1009;
        case 153: return (value + 89) % 1009;
        case 154: return (value + 162) % 1009;
        case 155: return (value + 235) % 1009;
        case 156: return (value + 308) % 1009;
        case 157: return (value + 381) % 1009;
        case 158: return (value + 454) % 1009;
        case 159: return (value + 527) % 1009;
        case 160: return (value + 600) % 1009;
        case 161: return (value + 673) % 1009;
        case 162: return (value + 746) % 1009;
        case 163: return (value + 819) % 1009;
        case 164: return (value + 892) % 1009;
        case 165: return (value + 965) % 1009;
        case 166: return (value + 29) % 1009;
        case 167: return (value + 102) % 1009;
        case 168: return (value + 175) % 1009;
        case 169: return (value + 248) % 1009;
        case 170: return (value + 321) % 1009;
        case 171: return (value + 394) % 1009;
        case 172: return (value + 467) % 1009;
        case 173: return (value + 540) % 1009;
        case 174: return (value + 613) % 1009;
        case 175: return (value + 686) % 1009;
        case 176: return (value + 759) % 1009;
        case 177: return (value + 832) % 1009;
        case 178: return (value + 905) % 1009;
        case 179: return (value + 978) % 1009;
        case 180: return (value + 42) % 1009;
        case 181: return (value + 115) % 1009;
        case 182: return (value + 188) % 1009;
        case 183: return (value + 261) % 1009;
        case 184: return (value + 334) % 1009;
        case 185: return (value + 407) % 1009;
        case 186: return (value + 480) % 1009;
        case 187: return (value + 553) % 1009;
        case 188: return (value + 626) % 1009;
        case 189: return (value + 699) % 1009;
        case 190: return (value + 772) % 1009;
        case 191: return (value + 845) % 1009;
        case 192: return (value + 918) % 1009;
        case 193: return (value + 991) % 1009;
        case 194: return (value + 55) % 1009;
        case 195: return (value + 128) % 1009;
        case 196: return (value + 201) % 1009;
        case 197: return (value + 274) % 1009;
        case 198: return (value + 347) % 1009;
        case 199: return (value + 420) % 1009;
        case 200: return (value + 493) % 1009;
        case 201: return (value + 566) % 1009;
        case 202: return (value + 639) % 1009;
        case 203: return (value + 712) % 1009;
        case 204: return (value + 785) % 1009;
        case 205: return (value + 858) % 1009;
        case 206: return (value + 931) % 1009;
        case 207: return (value + 1004) % 1009;
        case 208: return (value + 68) % 1009;
        case 209: return (value + 141) % 1009;
        case 210: return (value + 214) % 1009;
        case 211: return (value + 287) % 1009;
        case 212: return (value + 360) % 1009;
        case 213: return (value + 433) % 1009;
        case 214: return (value + 506) % 1009;
        case 215: return (value + 579) % 1009;
        case 216: return (value + 652) % 1009;
        case 217: return (value + 725) % 1009;
        case 218: return (value + 798) % 1009;
        case 219: return (value + 871) % 1009;
        case 220: return (value + 944) % 1009;
        case 221: return (value + 8) % 1009;
        case 222: return (value + 81) % 1009;
        case 223: return (value + 154) % 1009;
        case 224: return (value + 227) % 1009;
        case 225: return (value + 300) % 1009;
        case 226: return (value + 373) % 1009;
        case 227: return (value + 446) % 1009;
        case 228: return (value + 519) % 1009;
        case 229: return (value + 592) % 1009;
        case 230: return (value + 665) % 1009;
        case 231: return (value + 738) % 1009;
        case 232: return (value + 811) % 1009;
        case 233: return (value + 884) % 1009;
        case 234: return (value + 957) % 1009;
        case 235: return (value + 21) % 1009;
        case 236: return (value + 94) % 1009;
        case 237: return (value + 167) % 1009;
        case 238: return (value + 240) % 1009;
        case 239: return (value + 313) % 1009;
        case 240: return (value + 386) % 1009;
        case 241: return (value + 459) % 1009;
        case 242: return (value + 532) % 1009;
        case 243: return (value + 605) % 1009;
        case 244: return (value + 678) % 1009;
        case 245: return (value + 751) % 1009;
        case 246: return (value + 824) % 1009;
        case 247: return (value + 897) % 1009;
        case 248: return (value + 970) % 1009;
        case 249: return (value + 34) % 1009;
        case 250: return (value + 107) % 1009;
        case 251: return (value + 180) % 1009;
        case 252: return (value + 253) % 1009;
        case 253: return (value + 326) % 1009;
        case 254: return (value + 399) % 1009;
        case 255: return (value + 472) % 1009;
        default: return 0;
    }
}

int dead_kernel(int value) {
    int x = (value * 17 + 3) % 1009;
    x = (x * x + 11) % 1009;
    x = (x * 37 + 19) % 1009;
    x = (x * x + value % 97) % 1009;
    return x;
}

} // namespace

int pointer_chase(int scale) {
    const int n = 131072 * scale;
    std::vector<int> nodes(n);
    std::vector<int> values(n);
    std::vector<int> permutation(n);
    for (int i = 0; i < n; ++i) {
        values[i] = (i * 37 + 11) % 251;
        permutation[i] = i;
    }

    std::int64_t seed = 1;
    for (int at = n - 1; at > 0; --at) {
        seed = adversarial_next(seed);
        const int other = static_cast<int>(seed % (at + 1));
        std::swap(permutation[at], permutation[other]);
    }
    for (int link = 0; link < n; ++link) {
        nodes[permutation[link]] = permutation[(link + 1) % n];
    }

    int index = permutation[0];
    int sum = 0;
    for (int step = 0; step < n * 8; ++step) {
        index = nodes[index];
        sum = (sum + values[index]) % BENCH_MOD;
    }
    return sum;
}

int random_gather(int scale) {
    const int n = 262144 * scale;
    std::vector<int> values(n);
    std::vector<int> indices(n);
    std::int64_t seed = 7;
    for (int i = 0; i < n; ++i) {
        values[i] = (i * 53 + 17) % 4093;
        seed = adversarial_next(seed);
        indices[i] = static_cast<int>(seed % n);
    }

    int sum = 0;
    for (int round = 0; round < 8; ++round) {
        for (int k = 0; k < n; ++k) {
            sum = (sum + values[indices[k]]) % BENCH_MOD;
        }
    }
    return sum;
}

int branch_mispredict(int scale) {
    const int n = 500000 * scale;
    std::vector<std::uint8_t> conditions(n);
    std::vector<int> a(n);
    std::vector<int> b(n);
    std::int64_t seed = 19;
    for (int i = 0; i < n; ++i) {
        seed = adversarial_next(seed);
        conditions[i] = static_cast<std::uint8_t>(seed % 2 == 0);
        a[i] = (i * 13 + 5) % 997;
        b[i] = (i * 29 + 3) % 991;
    }

    int sum = 0;
    for (int round = 0; round < 6; ++round) {
        for (int k = 0; k < n; ++k) {
            if (conditions[k]) {
                sum = (sum + a[k]) % BENCH_MOD;
            } else {
                sum = (sum + b[k]) % BENCH_MOD;
            }
        }
    }
    return sum;
}

int strided_memory(int scale) {
    const int n = 1048576 * scale;
    std::vector<int> data(n);
    for (int i = 0; i < n; ++i) data[i] = (i * 17 + 23) % 1009;
    const int strides[] = {1, 2, 4, 8, 16, 32, 64, 128};

    int sum = 0;
    for (int stride : strides) {
        const int rounds = std::min(stride, 16);
        for (int round = 0; round < rounds; ++round) {
            for (int at = round % stride; at < n; at += stride) {
                sum = (sum + data[at]) % BENCH_MOD;
            }
        }
    }
    return sum;
}

int allocation_escape(int scale) {
    const int n = 1000000 * scale;
    int sum = 0;
    for (int i = 0; i < n; ++i) {
        const auto value = make_adversarial_object(i % 1000);
        sum = (sum + consume_adversarial_object(value)) % BENCH_MOD;
    }
    return sum;
}

int function_call_overhead(int scale) {
    const int n = 5000000 * scale;
    int state = 0;
    for (int i = 0; i < n; ++i) {
        state = tiny_add(state, i % 97);
        if (state >= BENCH_MOD) state -= BENCH_MOD;
    }
    return state;
}

int indirect_calls(int scale) {
    const int n = 262144 * scale;
    std::vector<int> operations(n);
    std::int64_t seed = 37;
    for (int i = 0; i < n; ++i) {
        seed = adversarial_next(seed);
        operations[i] = static_cast<int>(seed % 4);
    }

    int sum = 0;
    for (int round = 0; round < 8; ++round) {
        for (int k = 0; k < n; ++k) {
            sum = (sum + indirect_dispatch(operations[k], k % 1000)) % BENCH_MOD;
        }
    }
    return sum;
}

int dependency_chain(int scale) {
    const int n = 5000000 * scale;
    std::uint32_t state = 123456789u;
    for (int i = 0; i < n; ++i) {
        state = state * 1664525u + 1013904223u;
    }
    return static_cast<int>(state & 2147483647u);
}

int aos_vs_soa(int scale) {
    const int n = 100000 * scale;
    constexpr int rounds = 20;
    std::vector<LayoutParticle> particles;
    particles.reserve(n);
    for (int i = 0; i < n; ++i) {
        particles.push_back({i % 1009, i % 509, i % 257, i % 17 + 1, i % 31 + 1});
    }

    for (int round = 0; round < rounds; ++round) {
        for (auto& particle : particles) {
            particle.x += particle.velocity;
            particle.y += particle.mass;
            particle.z += particle.velocity + particle.mass;
        }
    }

    int aos = 0;
    for (const auto& particle : particles) {
        aos = (aos + particle.x + particle.y + particle.z) % BENCH_MOD;
    }

    std::vector<int> x;
    std::vector<int> y;
    std::vector<int> z;
    std::vector<int> velocity;
    std::vector<int> mass;
    x.reserve(n);
    y.reserve(n);
    z.reserve(n);
    velocity.reserve(n);
    mass.reserve(n);
    for (int i = 0; i < n; ++i) {
        x.push_back(i % 1009);
        y.push_back(i % 509);
        z.push_back(i % 257);
        velocity.push_back(i % 17 + 1);
        mass.push_back(i % 31 + 1);
    }

    for (int round = 0; round < rounds; ++round) {
        for (int i = 0; i < n; ++i) {
            x[i] += velocity[i];
            y[i] += mass[i];
            z[i] += velocity[i] + mass[i];
        }
    }

    int soa = 0;
    for (int i = 0; i < n; ++i) soa = (soa + x[i] + y[i] + z[i]) % BENCH_MOD;
    return aos == soa ? aos : -1;
}

int switch_dispatch(int scale) {
    const int n = 250000 * scale;
    std::vector<int> sequential(n);
    std::vector<int> randomized(n);
    std::vector<int> biased(n);
    std::int64_t seed = 97;
    for (int i = 0; i < n; ++i) {
        sequential[i] = i % 256;
        seed = adversarial_next(seed);
        randomized[i] = static_cast<int>(seed % 256);
        biased[i] = seed % 20 == 0 ? static_cast<int>(seed % 256) : 7;
    }

    int sum = 0;
    for (int round = 0; round < 3; ++round) {
        for (int k = 0; k < n; ++k) {
            sum = (sum + switch_case(sequential[k], k % 1009)) % BENCH_MOD;
            sum = (sum + switch_case(randomized[k], k % 1009)) % BENCH_MOD;
            sum = (sum + switch_case(biased[k], k % 1009)) % BENCH_MOD;
        }
    }
    return sum;
}

int memcpy_mix(int scale) {
    const int sizes[] = {2, 4, 8, 16, 64, 1024, 16384};
    int checksum = 0;
    for (int count : sizes) {
        std::vector<int> source(count);
        std::vector<int> target(count);
        for (int i = 0; i < count; ++i) source[i] = (i * 31 + count) % 4093;

        const int repeats = (65536 / count) * scale;
        for (int repeat = 0; repeat < repeats; ++repeat) {
            for (int k = 0; k < count; ++k) target[k] = source[k];
            ++target[repeat % count];
            for (int k = 0; k < count; ++k) source[k] = target[k];
            ++source[(repeat * 3) % count];
        }

        for (int i = 0; i < count; ++i) {
            checksum = (checksum + source[i] + target[i]) % BENCH_MOD;
        }
    }
    return checksum;
}

int dead_code_elimination(int scale) {
    const int n = 5000000 * scale;
    for (int i = 0; i < n; ++i) {
        const int dead = dead_kernel(i);
        (void)dead;
    }
    return 17;
}
