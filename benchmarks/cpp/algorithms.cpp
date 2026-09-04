#include "benchmarks.hpp"

#include <algorithm>
#include <cstdint>
#include <vector>

int gcd_value(int a, int b) {
    while (b != 0) { const int t = a % b; a = b; b = t; }
    return a;
}

int fibonacci(int scale) {
    const int limit = 1'000'000 * scale;
    int a = 1, b = 1, checksum = 0;
    for (int i = 0; i < limit; ++i) {
        const int c = (a + b) % 1'000'003;
        a = b; b = c; checksum = (checksum + c) % BENCH_MOD;
    }
    return checksum;
}

int prime_sieve(int scale) {
    const int n = 100'000 * scale;
    std::vector<std::uint8_t> prime(static_cast<std::size_t>(n + 1), 1);
    prime[0] = prime[1] = 0;
    for (int p = 2; p * p <= n; ++p) {
        if (!prime[p]) continue;
        for (int multiple = p * p; multiple <= n; multiple += p) prime[multiple] = 0;
    }
    int count = 0, sum = 0;
    for (int i = 2; i <= n; ++i) if (prime[i]) { ++count; sum = (sum + i) % BENCH_MOD; }
    return (sum + count) % BENCH_MOD;
}

int gcd_lcm(int scale) {
    const int limit = 300'000 * scale;
    int checksum = 0;
    for (int i = 1; i <= limit; ++i) {
        const int a = i % 30'000 + 1;
        const int b = (i * 17) % 30'000 + 1;
        const int g = gcd_value(a, b);
        const int l = (a / g) * b;
        checksum = (checksum + g + l) % BENCH_MOD;
    }
    return checksum;
}

int binary_search_work(int scale) {
    const int n = 100'000 * scale, queries = 500'000 * scale;
    std::vector<int> values; values.reserve(n);
    for (int i = 0; i < n; ++i) values.push_back(i * 2);
    int found = 0, seed = 7;
    for (int q = 0; q < queries; ++q) {
        seed = bench_next_random(seed);
        const int needle = seed % (n * 2);
        int low = 0, high = n - 1; bool hit = false;
        while (low <= high) {
            const int mid = low + (high - low) / 2;
            const int value = values[mid];
            if (value == needle) { hit = true; low = high + 1; }
            else if (value < needle) low = mid + 1;
            else high = mid - 1;
        }
        if (hit) ++found;
    }
    return found;
}

void quick_range(std::vector<int>& values, int low, int high) {
    if (low >= high) return;
    const int pivot = values[low + (high - low) / 2];
    int i = low, j = high;
    while (i <= j) {
        while (values[i] < pivot) ++i;
        while (values[j] > pivot) --j;
        if (i <= j) { std::swap(values[i], values[j]); ++i; --j; }
    }
    if (low < j) quick_range(values, low, j);
    if (i < high) quick_range(values, i, high);
}

std::vector<int> random_values(int n) {
    std::vector<int> values; values.reserve(n);
    int seed = 19;
    for (int i = 0; i < n; ++i) { seed = bench_next_random(seed); values.push_back(seed); }
    return values;
}

int sorted_checksum(const std::vector<int>& values) {
    int checksum = 0;
    for (std::size_t i = 0; i < values.size(); i += 97) checksum = (checksum + values[i]) % BENCH_MOD;
    return checksum + values.back();
}

int quicksort_work(int scale) {
    auto values = random_values(25'000 * scale);
    quick_range(values, 0, static_cast<int>(values.size()) - 1);
    return sorted_checksum(values);
}

void merge_range(std::vector<int>& values, std::vector<int>& scratch, int low, int high) {
    if (high - low <= 1) return;
    const int mid = low + (high - low) / 2;
    merge_range(values, scratch, low, mid);
    merge_range(values, scratch, mid, high);
    int left = low, right = mid, out = low;
    while (left < mid && right < high) {
        scratch[out++] = values[left] <= values[right] ? values[left++] : values[right++];
    }
    while (left < mid) scratch[out++] = values[left++];
    while (right < high) scratch[out++] = values[right++];
    for (int i = low; i < high; ++i) values[i] = scratch[i];
}

int mergesort_work(int scale) {
    auto values = random_values(25'000 * scale);
    std::vector<int> scratch(values.size());
    merge_range(values, scratch, 0, static_cast<int>(values.size()));
    return sorted_checksum(values);
}

int string_search(int scale) {
    std::string text;
    const std::string part = "alpha beta gamma delta needle omega ";
    text.reserve(part.size() * 2'000 * scale);
    for (int i = 0; i < 2'000 * scale; ++i) text += part;
    std::size_t from = 0; int count = 0, positions = 0;
    while (true) {
        const auto at = text.find("needle", from);
        if (at == std::string::npos) break;
        ++count; positions = (positions + static_cast<int>(at)) % BENCH_MOD; from = at + 6;
    }
    return positions + count;
}

int graph_bfs(int scale) {
    const int width = 120 * scale, total = width * width;
    std::vector<std::uint8_t> seen(total, 0);
    std::vector<int> queue; queue.reserve(total); queue.push_back(0); seen[0] = 1;
    std::size_t head = 0; int checksum = 0;
    auto visit = [&](int next) { if (!seen[next]) { seen[next] = 1; queue.push_back(next); } };
    while (head < queue.size()) {
        const int node = queue[head++]; checksum = (checksum + node) % BENCH_MOD;
        const int x = node % width, y = node / width;
        if (x > 0) visit(node - 1);
        if (x + 1 < width) visit(node + 1);
        if (y > 0) visit(node - width);
        if (y + 1 < width) visit(node + width);
    }
    return checksum + static_cast<int>(head);
}

int knapsack(int scale) {
    const int capacity = 800 * scale, items = 180;
    std::vector<int> best(capacity + 1, 0);
    for (int i = 1; i <= items; ++i) {
        const int weight = (i * 37) % 97 + 1, value = (i * 53) % 211 + 1;
        for (int at = capacity; at >= weight; --at)
            best[at] = std::max(best[at], best[at - weight] + value);
    }
    return best[capacity];
}

std::unique_ptr<BenchTree> build_tree(int depth, int seed) {
    if (depth == 0) return {};
    return std::make_unique<BenchTree>(BenchTree{seed, build_tree(depth - 1, seed * 2),
                                      build_tree(depth - 1, seed * 2 + 1)});
}

int tree_sum(const BenchTree* tree) {
    if (!tree) return 0;
    return ((tree_sum(tree->left.get()) + tree->value) % BENCH_MOD + tree_sum(tree->right.get())) % BENCH_MOD;
}

int tree_traversal(int scale) {
    auto tree = build_tree(13 + scale / 4, 1);
    int checksum = 0;
    for (int i = 0; i < 8 * scale; ++i) checksum = (checksum + tree_sum(tree.get())) % BENCH_MOD;
    return checksum;
}
