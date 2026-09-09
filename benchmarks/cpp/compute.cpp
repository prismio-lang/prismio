#include "benchmarks.hpp"

#include <cmath>
#include <cstdint>
#include <condition_variable>
#include <mutex>
#include <optional>
#include <queue>
#include <thread>
#include <vector>

struct Particle { double x, y, vx, vy; int life; };

int matrix_multiply(int scale) {
    const int n = 32 * scale, count = n * n;
    std::vector<int> a(count), b(count), c(count, 0);
    for (int i = 0; i < count; ++i) { a[i] = (i * 17) % 101; b[i] = (i * 29) % 103; }
    for (int row = 0; row < n; ++row) for (int col = 0; col < n; ++col) {
        int sum = 0;
        for (int k = 0; k < n; ++k) sum = (sum + a[row * n + k] * b[k * n + col]) % BENCH_MOD;
        c[row * n + col] = sum;
    }
    int checksum = 0; for (int value : c) checksum = (checksum + value) % BENCH_MOD;
    return checksum;
}

int mandelbrot(int scale) {
    const int side = 96 * scale; int inside = 0;
    for (int py = 0; py < side; ++py) {
        const double cy = static_cast<double>(py) * 2.0 / side - 1.0;
        for (int px = 0; px < side; ++px) {
            const double cx = static_cast<double>(px) * 3.0 / side - 2.0;
            double x = 0.0, y = 0.0; int iter = 0;
            while (x * x + y * y <= 4.0 && iter < 60) {
                const double next_x = x * x - y * y + cx;
                y = 2.0 * x * y + cy; x = next_x; ++iter;
            }
            if (iter == 60) ++inside;
        }
    }
    return inside;
}

void fft_transform(std::vector<double>& real, std::vector<double>& imag) {
    const int n = static_cast<int>(real.size()); int j = 0;
    for (int i = 1; i < n; ++i) {
        int bit = n / 2; while (j >= bit) { j -= bit; bit /= 2; } j += bit;
        if (i < j) { std::swap(real[i], real[j]); std::swap(imag[i], imag[j]); }
    }
    for (int length = 2; length <= n; length *= 2) {
        const double angle = -6.283185307179586 / length;
        const double step_real = std::cos(angle), step_imag = std::sin(angle); const int half = length / 2;
        for (int block = 0; block < n; block += length) {
            double weight_real = 1.0, weight_imag = 0.0;
            for (int offset = 0; offset < half; ++offset) {
                const int left = block + offset, right = left + half;
                const double value_real = real[right] * weight_real - imag[right] * weight_imag;
                const double value_imag = real[right] * weight_imag + imag[right] * weight_real;
                const double left_real = real[left], left_imag = imag[left];
                real[left] = left_real + value_real; imag[left] = left_imag + value_imag;
                real[right] = left_real - value_real; imag[right] = left_imag - value_imag;
                const double next_real = weight_real * step_real - weight_imag * step_imag;
                weight_imag = weight_real * step_imag + weight_imag * step_real; weight_real = next_real;
            }
        }
    }
}

int fft(int scale) {
    const int n = scale == 12 ? 16384 : 1024 * scale, rounds = 20 * scale;
    std::vector<double> real(n), imag(n); int checksum = 0;
    for (int round = 0; round < rounds; ++round) {
        std::fill(real.begin(), real.end(), 1.0); std::fill(imag.begin(), imag.end(), 0.0);
        fft_transform(real, imag); checksum += static_cast<int>(real[0]);
    }
    return checksum;
}

int numerical_integration(int scale) {
    const int steps = 1'000'000 * scale; const double width = 1.0 / steps; double sum = 0.0;
    for (int i = 0; i < steps; ++i) { const double x = (i + 0.5) * width; sum += 4.0 / (1.0 + x * x); }
    return static_cast<int>(sum * width * 100'000'000.0);
}

int vector_dot(int scale) {
    const int n = 1'000'000 * scale; std::vector<int> a, b; a.reserve(n); b.reserve(n);
    for (int i = 0; i < n; ++i) { a.push_back(i % 101); b.push_back((i * 3) % 103); }
    int sum = 0; for (int i = 0; i < n; ++i) sum = (sum + a[i] * b[i]) % BENCH_MOD;
    return sum;
}

int convolution(int scale) {
    const int n = 300'000 * scale; std::vector<int> input(n), output(n, 0);
    for (int i = 0; i < n; ++i) input[i] = i % 251;
    for (int at = 3; at + 3 < n; ++at)
        output[at] = input[at - 3] + 2 * input[at - 2] + 3 * input[at - 1] + 4 * input[at]
                   + 3 * input[at + 1] + 2 * input[at + 2] + input[at + 3];
    int checksum = 0; for (int value : output) checksum = (checksum + value) % BENCH_MOD;
    return checksum;
}

int monte_carlo(int scale) {
    const int samples = 2'000'000 * scale; int seed = 31, inside = 0;
    for (int i = 0; i < samples; ++i) {
        seed = bench_next_random(seed); const int x = seed % 10'000;
        seed = bench_next_random(seed); const int y = seed % 10'000;
        if (x * x + y * y <= 100'000'000) ++inside;
    }
    return inside;
}

int polynomial_evaluation(int scale) {
    const int evaluations = 2'000'000 * scale; int checksum = 0;
    for (int i = 0; i < evaluations; ++i) {
        const int x = i % 97; int value = 3;
        for (int coefficient : {5, 7, 11, 13, 17}) value = (value * x + coefficient) % 1'000'003;
        checksum = (checksum + value) % BENCH_MOD;
    }
    return checksum;
}

int ecs_component_update(int scale) {
    const int n = 50'000 * scale, rounds = 20; std::vector<Particle> particles; particles.reserve(n);
    for (int i = 0; i < n; ++i) particles.push_back({double(i % 1000), double(i % 500), double(i % 7 + 1), double(i % 11 + 1), 100});
    for (int round = 0; round < rounds; ++round) for (auto& p : particles) {
        p.x += p.vx * 0.016; p.y += p.vy * 0.016; --p.life;
    }
    int checksum = 0; for (const auto& p : particles) checksum = (checksum + int(p.x) + int(p.y) + p.life) % BENCH_MOD;
    return checksum;
}

int band_sum(int seed, int steps) {
    int sum = 0;
    for (int i = 0; i < steps; ++i) { seed = bench_next_random(seed); sum = (sum + seed) % BENCH_MOD; }
    return sum;
}

int parallel_reduction(int scale) {
    const int steps = 500'000 * scale; int results[4]{};
    std::thread workers[4]; const int seeds[4] = {1, 101, 1001, 10001};
    for (int i = 0; i < 4; ++i) workers[i] = std::thread([&, i] { results[i] = band_sum(seeds[i], steps); });
    for (auto& worker : workers) worker.join();
    return (((results[0] + results[1]) % BENCH_MOD) + ((results[2] + results[3]) % BENCH_MOD)) % BENCH_MOD;
}

static inline uint32_t rot_r32(uint32_t x, int n) {
    return (x >> n) | (x << (32 - n));
}

int sha256(int scale) {
    static const uint32_t K[64] = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    };

    uint32_t h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
    uint32_t h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

    const int total_blocks = 200 * scale;
    int seed = 42;
    uint32_t w[64];

    for (int b = 0; b < total_blocks; ++b) {
        for (int i = 0; i < 16; ++i) {
            seed = bench_next_random(seed);
            uint32_t v1 = static_cast<uint32_t>(seed);
            seed = bench_next_random(seed);
            uint32_t v2 = static_cast<uint32_t>(seed);
            w[i] = (v1 << 16) | v2;
        }

        for (int t = 16; t < 64; ++t) {
            uint32_t s0 = rot_r32(w[t - 15], 7) ^ rot_r32(w[t - 15], 18) ^ (w[t - 15] >> 3);
            uint32_t s1 = rot_r32(w[t - 2], 17) ^ rot_r32(w[t - 2], 19) ^ (w[t - 2] >> 10);
            w[t] = w[t - 16] + s0 + w[t - 7] + s1;
        }

        uint32_t a = h0, b_val = h1, c = h2, d = h3;
        uint32_t e = h4, f = h5, g = h6, h = h7;

        for (int step = 0; step < 64; ++step) {
            uint32_t s1 = rot_r32(e, 6) ^ rot_r32(e, 11) ^ rot_r32(e, 25);
            uint32_t ch = (e & f) ^ ((~e) & g);
            uint32_t temp1 = h + s1 + ch + K[step] + w[step];
            uint32_t s0 = rot_r32(a, 2) ^ rot_r32(a, 13) ^ rot_r32(a, 22);
            uint32_t maj = (a & b_val) ^ (a & c) ^ (b_val & c);
            uint32_t temp2 = s0 + maj;

            h = g; g = f; f = e; e = d + temp1;
            d = c; c = b_val; b_val = a; a = temp1 + temp2;
        }

        h0 += a; h1 += b_val; h2 += c; h3 += d;
        h4 += e; h5 += f; h6 += g; h7 += h;
    }

    return static_cast<int>((h0 ^ h1 ^ h2 ^ h3 ^ h4 ^ h5 ^ h6 ^ h7) & 0x7fffffff);
}

int blake3_chunk(int scale) {
    const int total_chunks = 300 * scale;
    int seed = 99;

    const uint32_t IV[8] = {
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
        0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19
    };
    const uint8_t MSG_PERM[16] = {
        2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8
    };

    uint32_t total_checksum = 0;
    uint32_t m[16], v[16], next_m[16];

    auto g_step = [](uint32_t& a, uint32_t& b, uint32_t& c, uint32_t& d, uint32_t mx, uint32_t my) {
        a = a + b + mx; d = rot_r32(d ^ a, 16);
        c = c + d;      b = rot_r32(b ^ c, 12);
        a = a + b + my; d = rot_r32(d ^ a, 8);
        c = c + d;      b = rot_r32(b ^ c, 7);
    };

    for (int chunk = 0; chunk < total_chunks; ++chunk) {
        for (int i = 0; i < 16; ++i) {
            seed = bench_next_random(seed);
            uint32_t v1 = static_cast<uint32_t>(seed);
            seed = bench_next_random(seed);
            uint32_t v2 = static_cast<uint32_t>(seed);
            m[i] = (v1 << 16) | v2;
        }

        for (int i = 0; i < 8; ++i) v[i] = IV[i];
        v[8] = IV[0]; v[9] = IV[1]; v[10] = IV[2]; v[11] = IV[3];
        v[12] = static_cast<uint32_t>(chunk);
        v[13] = 0;
        v[14] = 1024;
        v[15] = 0;

        for (int round = 0; round < 7; ++round) {
            g_step(v[0], v[4], v[8],  v[12], m[0], m[1]);
            g_step(v[1], v[5], v[9],  v[13], m[2], m[3]);
            g_step(v[2], v[6], v[10], v[14], m[4], m[5]);
            g_step(v[3], v[7], v[11], v[15], m[6], m[7]);

            g_step(v[0], v[5], v[10], v[15], m[8],  m[9]);
            g_step(v[1], v[6], v[11], v[12], m[10], m[11]);
            g_step(v[2], v[7], v[8],  v[13], m[12], m[13]);
            g_step(v[3], v[4], v[9],  v[14], m[14], m[15]);

            for (int i = 0; i < 16; ++i) next_m[i] = m[MSG_PERM[i]];
            for (int i = 0; i < 16; ++i) m[i] = next_m[i];
        }

        uint32_t chunk_hash = 0;
        for (int i = 0; i < 8; ++i) chunk_hash ^= (v[i] ^ v[i + 8]);
        total_checksum = (total_checksum * 31 + chunk_hash) & 0x7fffffff;
    }

    return static_cast<int>(total_checksum);
}

struct BenchSphere {
    double x, y, z, r;
    int cr, cg, cb;
};

int raytracer_sphere(int scale) {
    const int width = 50 * scale;
    const int height = 50 * scale;

    const BenchSphere spheres[4] = {
        {0.0, 0.0, 3.0, 1.0, 255, 30, 30},
        {2.0, 1.0, 4.0, 1.0, 30, 255, 30},
        {-2.0, 1.0, 4.0, 1.0, 30, 30, 255},
        {0.0, -1001.0, 0.0, 1000.0, 200, 200, 200}
    };

    const double light_x = -10.0, light_y = 20.0, light_z = -10.0;
    const double cam_x = 0.0, cam_y = 0.0, cam_z = -5.0;

    long long checksum = 0;

    for (int py = 0; py < height; ++py) {
        double screen_y = -((py + 0.5) / height * 2.0 - 1.0);
        for (int px = 0; px < width; ++px) {
            double screen_x = (px + 0.5) / width * 2.0 - 1.0;
            double dir_x = screen_x, dir_y = screen_y, dir_z = 2.0;
            double inv_len = 1.0 / std::sqrt(dir_x * dir_x + dir_y * dir_y + dir_z * dir_z);
            dir_x *= inv_len; dir_y *= inv_len; dir_z *= inv_len;

            double closest_t = 1e30;
            int hit_idx = -1;
            for (int s = 0; s < 4; ++s) {
                double oc_x = cam_x - spheres[s].x;
                double oc_y = cam_y - spheres[s].y;
                double oc_z = cam_z - spheres[s].z;
                double b = oc_x * dir_x + oc_y * dir_y + oc_z * dir_z;
                double c = (oc_x * oc_x + oc_y * oc_y + oc_z * oc_z) - spheres[s].r * spheres[s].r;
                double disc = b * b - c;
                if (disc > 0.0) {
                    double t = -b - std::sqrt(disc);
                    if (t > 0.001 && t < closest_t) {
                        closest_t = t;
                        hit_idx = s;
                    }
                }
            }

            if (hit_idx >= 0) {
                double hx = cam_x + closest_t * dir_x;
                double hy = cam_y + closest_t * dir_y;
                double hz = cam_z + closest_t * dir_z;

                double nx = (hx - spheres[hit_idx].x) / spheres[hit_idx].r;
                double ny = (hy - spheres[hit_idx].y) / spheres[hit_idx].r;
                double nz = (hz - spheres[hit_idx].z) / spheres[hit_idx].r;

                double lx = light_x - hx, ly = light_y - hy, lz = light_z - hz;
                double ldist = std::sqrt(lx * lx + ly * ly + lz * lz);
                lx /= ldist; ly /= ldist; lz /= ldist;

                double sh_ox = hx + nx * 0.001, sh_oy = hy + ny * 0.001, sh_oz = hz + nz * 0.001;
                bool in_shadow = false;
                for (int s = 0; s < 4; ++s) {
                    double oc_x = sh_ox - spheres[s].x;
                    double oc_y = sh_oy - spheres[s].y;
                    double oc_z = sh_oz - spheres[s].z;
                    double b = oc_x * lx + oc_y * ly + oc_z * lz;
                    double c = (oc_x * oc_x + oc_y * oc_y + oc_z * oc_z) - spheres[s].r * spheres[s].r;
                    double disc = b * b - c;
                    if (disc > 0.0) {
                        double t = -b - std::sqrt(disc);
                        if (t > 0.001 && t < ldist) {
                            in_shadow = true;
                            break;
                        }
                    }
                }

                double dot = nx * lx + ny * ly + nz * lz;
                if (dot < 0.0) dot = 0.0;
                double intensity = 0.15 + (in_shadow ? 0.0 : dot * 0.85);
                int r = static_cast<int>(spheres[hit_idx].cr * intensity);
                int g = static_cast<int>(spheres[hit_idx].cg * intensity);
                int b_col = static_cast<int>(spheres[hit_idx].cb * intensity);
                if (r > 255) r = 255;
                if (g > 255) g = 255;
                if (b_col > 255) b_col = 255;
                long long pix_val = static_cast<long long>(r) * 65537 + static_cast<long long>(g) * 257 + b_col;
                checksum = (checksum * 31 + pix_val) % BENCH_MOD;
            } else {
                checksum = (checksum * 31 + 17) % BENCH_MOD;
            }
        }
    }
    return static_cast<int>(checksum);
}

template <typename T>
class BoundedQueue {
public:
    explicit BoundedQueue(size_t cap) : cap_(cap), closed_(false) {}

    void send(T val) {
        std::unique_lock<std::mutex> lock(mu_);
        not_full_.wait(lock, [this] { return queue_.size() < cap_ || closed_; });
        if (closed_) return;
        queue_.push(std::move(val));
        not_empty_.notify_one();
    }

    std::optional<T> recv() {
        std::unique_lock<std::mutex> lock(mu_);
        not_empty_.wait(lock, [this] { return !queue_.empty() || closed_; });
        if (queue_.empty()) return std::nullopt;
        T val = std::move(queue_.front());
        queue_.pop();
        not_full_.notify_one();
        return val;
    }

    void close() {
        std::unique_lock<std::mutex> lock(mu_);
        closed_ = true;
        not_full_.notify_all();
        not_empty_.notify_all();
    }

private:
    size_t cap_;
    bool closed_;
    std::mutex mu_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;
    std::queue<T> queue_;
};

int channel_pipeline(int scale) {
    int count = 5000 * scale;
    BoundedQueue<int> ch1(64);
    BoundedQueue<int> ch2(64);

    std::thread w1([&]() {
        for (int i = 0; i < count; ++i) {
            int x = (i * 25173 + 13849) % 65521;
            ch1.send(x);
        }
        ch1.close();
    });

    std::thread w2([&]() {
        while (true) {
            auto taken = ch1.recv();
            if (!taken.has_value()) break;
            int x = *taken;
            long long y = ((long long)x * 17 + 31) % BENCH_MOD;
            ch2.send(static_cast<int>(y));
        }
        ch2.close();
    });

    long long checksum = 0;
    while (true) {
        auto taken = ch2.recv();
        if (!taken.has_value()) break;
        int y = *taken;
        checksum = (checksum * 31 + y) % BENCH_MOD;
    }

    w1.join();
    w2.join();

    return static_cast<int>(checksum);
}

int bytecode_interpreter(int scale) {
    const int program = 4096;
    std::vector<int> ops, args;
    ops.reserve(program);
    args.reserve(program);
    int seed = 11;
    for (int p = 0; p < program; ++p) {
        seed = bench_next_random(seed);
        ops.push_back(seed % 6);
        args.push_back((seed % 251) + 1);
    }

    std::vector<int> stack(64, 0);
    int accumulator = 0, top = 0;
    const int rounds = 900 * scale;
    for (int r = 0; r < rounds; ++r) {
        for (int pc = 0; pc < program; ++pc) {
            const int op = ops[pc], argument = args[pc];
            if (op == 0) {
                if (top < 63) { stack[top] = argument; top = top + 1; }
            } else if (op == 1) {
                if (top > 1) {
                    const int b = stack[top - 1], a = stack[top - 2];
                    stack[top - 2] = (a + b) % 46337;
                    top = top - 1;
                }
            } else if (op == 2) {
                if (top > 1) {
                    const int b = stack[top - 1], a = stack[top - 2];
                    stack[top - 2] = (a * b) % 46337;
                    top = top - 1;
                }
            } else if (op == 3) {
                if (top > 0) { top = top - 1; accumulator = (accumulator + stack[top]) % BENCH_MOD; }
            } else if (op == 4) {
                if (top > 0) { stack[top - 1] = (stack[top - 1] ^ argument) % 46337; }
            } else {
                if (top > 0 && stack[top - 1] % 2 == 0) pc = pc + 1;
            }
        }
    }
    return (accumulator + top) % BENCH_MOD;
}
