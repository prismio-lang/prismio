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

// A third of the keys removed and reinserted each round, so every lookup after
// the first round probes past removed buckets.
int mixed_map_removal(int scale) {
    const int n = 20'000 * scale; std::unordered_map<int, int> map;
    for (int i = 0; i < n; ++i) map[i] = i % 101;
    int checksum = 0;
    for (int round = 0; round < 10; ++round) {
        for (int i = 0; i < n; ++i) if ((i + round) % 3 == 0 && map.erase(i) == 1) checksum = (checksum + 1) % BENCH_MOD;
        for (int i = 0; i < n; ++i) if ((i + round) % 3 == 0) map[i] = (i + round) % 101;
    }
    for (int i = 0; i < n; ++i) checksum = (checksum + map.at(i)) % BENCH_MOD;
    return checksum;
}

int flat_bitset(int scale) {
    const int n = 50000 * scale;
    const int words = (n + 63) / 64;

    std::vector<uint64_t> a(words, 0);
    std::vector<uint64_t> b(words, 0);
    std::vector<uint64_t> c(words, 0);

    int seed = 77;
    for (int i = 0; i < n; ++i) {
        seed = bench_next_random(seed);
        int w_idx = i / 64;
        int b_idx = i % 64;
        if (seed % 3 == 0) a[w_idx] |= (1ULL << b_idx);
        seed = bench_next_random(seed);
        if (seed % 5 == 0) b[w_idx] |= (1ULL << b_idx);
    }

    const uint64_t magic = 0x0137F0268594B374ULL;
    for (int round = 0; round < 10; ++round) {
        for (int w = 0; w < words; ++w) {
            uint64_t aw = a[w];
            uint64_t bw = b[w];
            uint64_t cw = (aw & bw) | ((~aw) & (bw ^ magic));
            c[w] = cw;
            a[w] = aw ^ cw;
            b[w] = (bw << 1) | (bw >> 63);
        }
    }

    long long count_a = 0, count_b = 0, count_c = 0;
    for (int w = 0; w < words; ++w) {
        count_a += __builtin_popcountll(a[w]);
        count_b += __builtin_popcountll(b[w]);
        count_c += __builtin_popcountll(c[w]);
    }

    long long checksum = (count_a * 10007 + count_b * 31 + count_c) % BENCH_MOD;
    return static_cast<int>(checksum);
}

int trie_search(int scale) {
    const int num_keys = 8000 * scale;
    const int num_queries = 15000 * scale;

    std::vector<int> c0, c1, c2, c3, counts;
    c0.push_back(-1); c1.push_back(-1); c2.push_back(-1); c3.push_back(-1); counts.push_back(0);

    int seed = 53;
    for (int k = 0; k < num_keys; ++k) {
        seed = bench_next_random(seed);
        int len = 6 + (seed % 10);
        int curr = 0;
        for (int i = 0; i < len; ++i) {
            seed = bench_next_random(seed);
            int branch = seed % 4;
            int next_node = -1;
            if (branch == 0) {
                if (c0[curr] == -1) {
                    int new_idx = static_cast<int>(c0.size());
                    c0.push_back(-1); c1.push_back(-1); c2.push_back(-1); c3.push_back(-1); counts.push_back(0);
                    c0[curr] = new_idx;
                }
                next_node = c0[curr];
            } else if (branch == 1) {
                if (c1[curr] == -1) {
                    int new_idx = static_cast<int>(c0.size());
                    c0.push_back(-1); c1.push_back(-1); c2.push_back(-1); c3.push_back(-1); counts.push_back(0);
                    c1[curr] = new_idx;
                }
                next_node = c1[curr];
            } else if (branch == 2) {
                if (c2[curr] == -1) {
                    int new_idx = static_cast<int>(c0.size());
                    c0.push_back(-1); c1.push_back(-1); c2.push_back(-1); c3.push_back(-1); counts.push_back(0);
                    c2[curr] = new_idx;
                }
                next_node = c2[curr];
            } else {
                if (c3[curr] == -1) {
                    int new_idx = static_cast<int>(c0.size());
                    c0.push_back(-1); c1.push_back(-1); c2.push_back(-1); c3.push_back(-1); counts.push_back(0);
                    c3[curr] = new_idx;
                }
                next_node = c3[curr];
            }
            curr = next_node;
        }
        counts[curr]++;
    }

    int checksum = 0;
    int q_seed = 101;
    for (int q = 0; q < num_queries; ++q) {
        q_seed = bench_next_random(q_seed);
        int q_len = 3 + (q_seed % 8);
        int curr = 0;
        bool found = true;
        for (int qi = 0; qi < q_len; ++qi) {
            q_seed = bench_next_random(q_seed);
            int branch = q_seed % 4;
            int next_node = -1;
            if (branch == 0) next_node = c0[curr];
            else if (branch == 1) next_node = c1[curr];
            else if (branch == 2) next_node = c2[curr];
            else next_node = c3[curr];

            if (next_node == -1) {
                found = false;
                break;
            }
            curr = next_node;
        }
        if (found) {
            checksum = (checksum + curr * 31 + counts[curr] + 1) % BENCH_MOD;
        }
    }

    return checksum;
}
