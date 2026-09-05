#include <chrono>
#include <cstdio>
#include <vector>
static long long now_ns() {
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}
int large_buffer_copy(int scale) {
    const int n = 500'000 * scale;
    long long t0 = now_ns();
    std::vector<int> source; source.reserve(n);
    std::vector<int> target; target.reserve(n);
    for (int i = 0; i < n; ++i) { source.push_back(i % 4093); target.push_back(0); }
    long long t1 = now_ns();
    for (int round = 0; round < 8; ++round)
        for (int k = 0; k < n; ++k) target[k] = source[k];
    long long t2 = now_ns();
    int checksum = 0;
    for (int q = 0; q < n; ++q) checksum = (checksum + target[q]) % 1000000007;
    long long t3 = now_ns();
    printf("fill_ns: %lld copy_ns: %lld sum_ns: %lld\n", t1-t0, t2-t1, t3-t2);
    return checksum;
}
int main() {
    int r = 0;
    for (int it = 0; it < 1; ++it) r = large_buffer_copy(4);
    printf("result: %d\n", r);
}
