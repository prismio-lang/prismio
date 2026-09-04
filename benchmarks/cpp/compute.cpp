#include "benchmarks.hpp"

#include <cmath>
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
