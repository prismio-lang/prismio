#include "benchmarks.hpp"

#include <string>
#include <vector>

namespace {
struct MemoryParticle { double x, y, vx, vy; int life; };

std::unique_ptr<BenchTree> build_memory_tree(int depth, int seed) {
    if (depth == 0) return {};
    auto tree = std::make_unique<BenchTree>();
    tree->value = seed;
    tree->left = build_memory_tree(depth - 1, (seed * 3 + 1) % 1009);
    tree->right = build_memory_tree(depth - 1, (seed * 5 + 7) % 1009);
    return tree;
}

int memory_tree_sum(const BenchTree* tree) {
    if (!tree) return 0;
    return (tree->value + memory_tree_sum(tree->left.get()) + memory_tree_sum(tree->right.get())) % BENCH_MOD;
}
}  // namespace

int transient_allocation(int scale) {
    const int rounds = 200 * scale; int checksum = 0;
    for (int r = 0; r < rounds; ++r) {
        std::vector<int> values;
        for (int i = 0; i < 4000; ++i) values.push_back((i + r) % 997);
        checksum = (checksum + values[r % 4000]) % BENCH_MOD;
    }
    return checksum;
}

int struct_creation(int scale) {
    const int n = 250'000 * scale; std::vector<MemoryParticle> particles; particles.reserve(n);
    for (int i = 0; i < n; ++i) particles.push_back({double(i), double(i % 31), 1.0, 2.0, i % 100});
    int checksum = 0; for (const auto& p : particles) checksum = (checksum + int(p.x) + p.life) % BENCH_MOD;
    return checksum;
}

int allocation_mutation(int scale) {
    const int n = 100'000 * scale; std::vector<MemoryParticle> particles(n, {0.0, 0.0, 1.0, 2.0, 50});
    for (int round = 0; round < 20; ++round) for (auto& p : particles) { p.x += p.vx; p.y += p.vy; --p.life; }
    int checksum = 0; for (const auto& p : particles) checksum = (checksum + int(p.x) + int(p.y) + p.life) % BENCH_MOD;
    return checksum;
}

int nested_collection(int scale) {
    const int count = 200 * scale; std::vector<std::vector<int>> buckets; buckets.reserve(count);
    for (int b = 0; b < count; ++b) {
        std::vector<int> values; values.reserve(1000);
        for (int i = 0; i < 1000; ++i) values.push_back((b + i) % 1021);
        buckets.push_back(std::move(values));
    }
    int checksum = 0; for (const auto& bucket : buckets) for (int value : bucket) checksum = (checksum + value) % BENCH_MOD;
    return checksum;
}

int large_buffer_copy(int scale) {
    const int n = 500'000 * scale; std::vector<int> source(n), target(n, 0);
    for (int i = 0; i < n; ++i) source[i] = i % 4093;
    for (int round = 0; round < 8; ++round)
        for (int i = 0; i < n; ++i) target[i] = source[i];
    int checksum = 0; for (int value : target) checksum = (checksum + value) % BENCH_MOD;
    return checksum;
}

std::unique_ptr<BenchTree> tree_add(std::unique_ptr<BenchTree> tree, int amount) {
    if (!tree) return {};
    tree->value += amount;
    tree->left = tree_add(std::move(tree->left), amount);
    tree->right = tree_add(std::move(tree->right), amount);
    return tree;
}

int recursive_tree_rebuild(int scale) {
    auto tree = build_memory_tree(12 + scale / 4, 1);
    for (int pass = 0; pass < 4 * scale; ++pass) tree = tree_add(std::move(tree), 1);
    return memory_tree_sum(tree.get());
}

int string_join(int scale) {
    const int n = 60000 * scale;
    std::vector<std::string> parts;
    parts.reserve(n);
    for (int i = 0; i < n; ++i) {
        std::string piece;
        piece.reserve(16);
        piece += "field";
        piece += std::to_string(i % 9973);
        parts.push_back(std::move(piece));
    }

    // What Rust's `Vec<String>::join` and Prismio's `join` do internally, and
    // what C++ has no standard call for: size the result, then copy once.
    std::size_t total = parts.empty() ? 0 : parts.size() - 1;
    for (const std::string& piece : parts) total += piece.size();
    std::string joined;
    joined.reserve(total);
    for (std::size_t i = 0; i < parts.size(); ++i) {
        if (i > 0) joined += ',';
        joined += parts[i];
    }
    const int length = static_cast<int>(joined.size());

    int checksum = length % BENCH_MOD;
    for (int at = 0; at < length; at += 997)
        checksum = (checksum + static_cast<int>(static_cast<unsigned char>(joined[at]))) % BENCH_MOD;
    return checksum;
}
