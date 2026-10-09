#include "benchmarks.hpp"

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace
{
    struct MemoryParticle
    {
        double x, y, vx, vy;
        int life;
    };

    std::unique_ptr<BenchTree> build_memory_tree(int depth, int seed)
    {
        if (depth == 0) return {};
        auto tree = std::make_unique<BenchTree>();
        tree->value = seed;
        tree->left = build_memory_tree(depth - 1, (seed * 3 + 1) % 1009);
        tree->right = build_memory_tree(depth - 1, (seed * 5 + 7) % 1009);
        return tree;
    }

    int memory_tree_sum(const BenchTree* tree)
    {
        if (!tree) return 0;
        return (tree->value + memory_tree_sum(tree->left.get()) + memory_tree_sum(tree->right.get())) % BENCH_MOD;
    }
} // namespace

int transient_allocation(int scale)
{
    const int rounds = 200 * scale;
    int checksum = 0;
    for (int r = 0; r < rounds; ++r)
    {
        std::vector<int> values;
        for (int i = 0; i < 4000; ++i) values.push_back((i + r) % 997);
        checksum = (checksum + values[r % 4000]) % BENCH_MOD;
    }
    return checksum;
}

int struct_creation(int scale)
{
    const int n = 250'000 * scale;
    std::vector<MemoryParticle> particles;
    particles.reserve(n);
    for (int i = 0; i < n; ++i) particles.push_back({double(i), double(i % 31), 1.0, 2.0, i % 100});
    int checksum = 0;
    for (const auto& p : particles) checksum = (checksum + int(p.x) + p.life) % BENCH_MOD;
    return checksum;
}

int allocation_mutation(int scale)
{
    const int n = 100'000 * scale;
    std::vector<MemoryParticle> particles(n, {0.0, 0.0, 1.0, 2.0, 50});
    for (int round = 0; round < 20; ++round)
        for (auto& p : particles)
        {
            p.x += p.vx;
            p.y += p.vy;
            --p.life;
        }
    int checksum = 0;
    for (const auto& p : particles) checksum = (checksum + int(p.x) + int(p.y) + p.life) % BENCH_MOD;
    return checksum;
}

int nested_collection(int scale)
{
    const int count = 200 * scale;
    std::vector<std::vector<int>> buckets;
    buckets.reserve(count);
    for (int b = 0; b < count; ++b)
    {
        std::vector<int> values;
        values.reserve(1000);
        for (int i = 0; i < 1000; ++i) values.push_back((b + i) % 1021);
        buckets.push_back(std::move(values));
    }
    int checksum = 0;
    for (const auto& bucket : buckets) for (int value : bucket) checksum = (checksum + value) % BENCH_MOD;
    return checksum;
}

int large_buffer_copy(int scale)
{
    const int n = 500'000 * scale;
    std::vector<int> source(n), target(n, 0);
    for (int i = 0; i < n; ++i) source[i] = i % 4093;
    for (int round = 0; round < 8; ++round)
        for (int i = 0; i < n; ++i) target[i] = source[i];
    int checksum = 0;
    for (int value : target) checksum = (checksum + value) % BENCH_MOD;
    return checksum;
}

std::unique_ptr<BenchTree> tree_add(std::unique_ptr<BenchTree> tree, int amount)
{
    if (!tree) return {};
    tree->value += amount;
    tree->left = tree_add(std::move(tree->left), amount);
    tree->right = tree_add(std::move(tree->right), amount);
    return tree;
}

int recursive_tree_rebuild(int scale)
{
    auto tree = build_memory_tree(12 + scale / 4, 1);
    for (int pass = 0; pass < 4 * scale; ++pass) tree = tree_add(std::move(tree), 1);
    return memory_tree_sum(tree.get());
}

int string_join(int scale)
{
    const int n = 60000 * scale;
    std::vector<std::string> parts;
    parts.reserve(n);
    for (int i = 0; i < n; ++i)
    {
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
    for (std::size_t i = 0; i < parts.size(); ++i)
    {
        if (i > 0) joined += ',';
        joined += parts[i];
    }
    const int length = static_cast<int>(joined.size());

    int checksum = length % BENCH_MOD;
    for (int at = 0; at < length; at += 997)
        checksum = (checksum + static_cast<int>(static_cast<unsigned char>(joined[at]))) % BENCH_MOD;
    return checksum;
}

// std.mem's three tools, as the same programs in C++ (see memory.psm).
namespace
{
    template <class T> void put_bytes(std::vector<unsigned char>& buf, int off, T value)
    {
        std::memcpy(buf.data() + off, &value, sizeof value);
    }

    template <class T> T get_bytes(const std::vector<unsigned char>& buf, int off)
    {
        T value;
        std::memcpy(&value, buf.data() + off, sizeof value);
        return value;
    }

    double float_from_bits(uint64_t bits)
    {
        double d;
        std::memcpy(&d, &bits, 8);
        return d;
    }

    uint64_t bits_from_float(double d)
    {
        uint64_t bits;
        std::memcpy(&bits, &d, 8);
        return bits;
    }

    struct BumpArena
    {
        std::vector<unsigned char> block;
        size_t top = 0;

        explicit BumpArena(size_t capacity) : block(capacity, 0) {}

        uintptr_t alloc(size_t size, size_t align)
        {
            uintptr_t base = reinterpret_cast<uintptr_t>(block.data());
            uintptr_t mask = align - 1;
            uintptr_t start = ((base + top + mask) & ~mask) - base;
            if (start > block.size() || block.size() - start < size) std::abort();
            top = start + size;
            return base + start;
        }
    };
} // namespace

int binary_codec(int scale)
{
    const int n = 100'000 * scale;
    std::vector<unsigned char> buf(static_cast<size_t>(n) * 16, 0);
    for (int i = 0; i < n; ++i) {
        const int off = i * 16;
        put_bytes<uint16_t>(buf, off, __builtin_bswap16(static_cast<uint16_t>((i * 7) % 65536)));
        put_bytes<uint32_t>(buf, off + 2, __builtin_bswap32(static_cast<uint32_t>((i * 13) % 100000 - 50000)));
        put_bytes<uint64_t>(buf, off + 6, __builtin_bswap64(bits_from_float(static_cast<double>(i % 1000) * 0.5)));
        put_bytes<uint16_t>(buf, off + 14, static_cast<uint16_t>(i % 251));
    }
    int checksum = 0;
    for (int round = 0; round < 8; ++round) {
        for (int i = 0; i < n; ++i) {
            const int off = i * 16;
            const int v = static_cast<int>(__builtin_bswap16(get_bytes<uint16_t>(buf, off)))
                + static_cast<int>(__builtin_bswap32(get_bytes<uint32_t>(buf, off + 2)))
                + static_cast<int>(float_from_bits(__builtin_bswap64(get_bytes<uint64_t>(buf, off + 6))))
                + static_cast<int>(get_bytes<uint16_t>(buf, off + 14)) + round;
            checksum = (checksum + v) % BENCH_MOD;
        }
    }
    return checksum;
}

int manual_alloc_churn(int scale)
{
    const int n = 400'000 * scale;
    uintptr_t blocks[64] = {};
    int sizes[64] = {};
    int checksum = 0;
    for (int i = 0; i < n; ++i) {
        const int slot = i % 64;
        const uintptr_t old = blocks[slot];
        if (old != 0) {
            uint32_t first, second;
            std::memcpy(&first, reinterpret_cast<void*>(old), 4);
            std::memcpy(&second, reinterpret_cast<void*>(old + 8), 4);
            checksum = (checksum + static_cast<int>(first) + static_cast<int>(second) + sizes[slot]) % BENCH_MOD;
            std::free(reinterpret_cast<void*>(old));
        }
        const int size = 16 + (i * 37) % 241;
        void* block = std::malloc(static_cast<size_t>(size));
        if (!block) std::abort();
        const uint32_t first = static_cast<uint32_t>(i % 65521), second = static_cast<uint32_t>(size);
        std::memcpy(block, &first, 4);
        std::memcpy(static_cast<unsigned char*>(block) + 8, &second, 4);
        blocks[slot] = reinterpret_cast<uintptr_t>(block);
        sizes[slot] = size;
    }
    for (int slot = 0; slot < 64; ++slot) {
        const uintptr_t old = blocks[slot];
        if (old != 0) {
            uint32_t first;
            std::memcpy(&first, reinterpret_cast<void*>(old), 4);
            checksum = (checksum + static_cast<int>(first)) % BENCH_MOD;
            std::free(reinterpret_cast<void*>(old));
        }
    }
    return checksum;
}

int arena_bump(int scale)
{
    BumpArena arena(1 << 20);
    const int rounds = 300 * scale;
    int checksum = 0;
    for (int r = 0; r < rounds; ++r) {
        uintptr_t head = 0;
        for (int i = 0; i < 20000; ++i) {
            const uintptr_t node = arena.alloc(24, 8);
            const uint64_t next = head;
            const uint32_t value = static_cast<uint32_t>((i + r) % 1009);
            std::memcpy(reinterpret_cast<void*>(node), &next, 8);
            std::memcpy(reinterpret_cast<void*>(node + 8), &value, 4);
            head = node;
            if (i % 16 == 0) arena.alloc(5, 1);
        }
        uintptr_t at = head;
        while (at != 0) {
            uint32_t value;
            std::memcpy(&value, reinterpret_cast<void*>(at + 8), 4);
            checksum = (checksum + static_cast<int>(value)) % BENCH_MOD;
            uint64_t next;
            std::memcpy(&next, reinterpret_cast<void*>(at), 8);
            at = static_cast<uintptr_t>(next);
        }
        arena.top = 0;
    }
    return checksum;
}
