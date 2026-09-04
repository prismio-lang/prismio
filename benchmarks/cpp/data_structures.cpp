#include "benchmarks.hpp"

#include <unordered_map>
#include <vector>

int hashmap_insert_lookup(int scale) {
    const int n = 50'000 * scale;
    std::unordered_map<int, int> map;
    for (int i = 0; i < n; ++i) map[i] = (i * 31) % 1'000'003;
    int checksum = 0, seed = 23;
    for (int q = 0; q < n * 4; ++q) {
        seed = bench_next_random(seed); const int key = seed % n;
        checksum = (checksum + map.at(key)) % BENCH_MOD;
    }
    return checksum + static_cast<int>(map.size());
}

int vector_growth(int scale) {
    const int n = 1'000'000 * scale; std::vector<int> values; int checksum = 0;
    for (int i = 0; i < n; ++i) { const int value = i % 997; values.push_back(value); checksum = (checksum + value) % BENCH_MOD; }
    return checksum + static_cast<int>(values.size());
}

int vector_iteration(int scale) {
    const int n = 1'000'000 * scale; std::vector<int> values; values.reserve(n);
    for (int i = 0; i < n; ++i) values.push_back(i % 1009);
    int checksum = 0;
    for (int round = 0; round < 8; ++round) for (int value : values) checksum = (checksum + value) % BENCH_MOD;
    return checksum;
}

int key_value_update(int scale) {
    const int n = 20'000 * scale; std::unordered_map<int, int> map;
    for (int i = 0; i < n; ++i) map[i] = i % 101;
    for (int round = 0; round < 20; ++round) for (int i = 0; i < n; ++i) map[i] = map.at(i) + 1;
    int checksum = 0; for (int i = 0; i < n; ++i) checksum = (checksum + map.at(i)) % BENCH_MOD;
    return checksum;
}
