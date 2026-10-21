#include "benchmarks.hpp"
#include "bounded_queue.hpp"

#include <cstdint>
#include <thread>
#include <utility>
#include <vector>

// The same four programs as prismio/graph_churn.psm; read the comment there for
// what each is for. A node owns a `std::vector<int>` edge list, which is the
// allocation being measured.

namespace
{
    constexpr int64_t CHURN_MOD = 1'000'000'007;

    struct ChurnNode
    {
        int value;
        int live;
        std::vector<int> edges;
    };

    struct ChurnFrag
    {
        std::vector<ChurnNode> nodes;
        int id;
    };

    int64_t churn_next(int64_t seed) { return (seed * 48271) % 2147483647; }

    int64_t churn_mix(int64_t acc, int value) { return (acc * 31 + value) % CHURN_MOD; }

    ChurnFrag churn_fragment(int index)
    {
        int64_t seed = (static_cast<int64_t>(index) * 7919 + 17) % 2147483646 + 1;
        seed = churn_next(seed);
        const int count = 8 + static_cast<int>(seed % 24);
        std::vector<ChurnNode> nodes;
        nodes.reserve(count);
        for (int i = 0; i < count; ++i)
        {
            seed = churn_next(seed);
            const int degree = 1 + static_cast<int>(seed % 6);
            std::vector<int> edges;
            edges.reserve(degree);
            for (int e = 0; e < degree; ++e)
            {
                seed = churn_next(seed);
                edges.push_back(static_cast<int>(seed % count));
            }
            seed = churn_next(seed);
            nodes.push_back(ChurnNode{static_cast<int>(seed % 1021), 1, std::move(edges)});
        }
        return ChurnFrag{std::move(nodes), index};
    }

    int64_t churn_frag_sum(const ChurnFrag& frag)
    {
        int64_t acc = frag.id;
        for (const ChurnNode& node : frag.nodes)
        {
            acc = churn_mix(acc, node.value);
            for (int edge : node.edges) acc = churn_mix(acc, edge);
        }
        return acc;
    }

    int64_t churn_single(int scale)
    {
        const int n = 8192 * scale;
        const int steps = 240000 * scale;
        const int64_t n64 = n;
        std::vector<ChurnNode> nodes;
        nodes.reserve(n);
        std::vector<int> free_list;
        free_list.reserve(n);
        int64_t seed = 12345;
        for (int i = 0; i < n; ++i)
        {
            std::vector<int> edges;
            edges.reserve(4);
            for (int k = 0; k < 3; ++k)
            {
                seed = churn_next(seed);
                edges.push_back(static_cast<int>(seed % n64));
            }
            nodes.push_back(ChurnNode{i % 1021, 1, std::move(edges)});
        }

        int64_t checksum = 0;
        for (int step = 0; step < steps; ++step)
        {
            seed = churn_next(seed);
            const int u = static_cast<int>(seed % n64);
            seed = churn_next(seed);
            const int v = static_cast<int>(seed % n64);
            seed = churn_next(seed);
            const int op = static_cast<int>(seed % 8);
            if (op < 3)
            {
                if (nodes[u].live == 1 && nodes[v].live == 1)
                {
                    std::vector<int>& edges = nodes[u].edges;
                    if (edges.size() >= 12)
                    {
                        edges[0] = edges.back();
                        edges.pop_back();
                    }
                    edges.push_back(v);
                }
            }
            else if (op < 5)
            {
                std::vector<int>& edges = nodes[u].edges;
                if (nodes[u].live == 1 && !edges.empty())
                {
                    const int at = v % static_cast<int>(edges.size());
                    checksum = churn_mix(checksum, edges[at]);
                    edges[at] = edges.back();
                    edges.pop_back();
                }
            }
            else if (op == 6)
            {
                if (nodes[u].live == 1)
                {
                    const int kept = nodes[u].value;
                    checksum = churn_mix(churn_mix(checksum, kept), static_cast<int>(nodes[u].edges.size()));
                    nodes[u].live = 0;
                    nodes[u].edges = std::vector<int>();
                    free_list.push_back(u);
                }
            }
            else if (op == 7)
            {
                if (!free_list.empty())
                {
                    const int w = free_list.back();
                    free_list.pop_back();
                    std::vector<int> edges;
                    edges.reserve(4);
                    for (int k = 0; k < 3; ++k) edges.push_back((v + k * 7919) % n);
                    nodes[w].value = step % 1021;
                    nodes[w].live = 1;
                    nodes[w].edges = std::move(edges);
                }
            }
        }

        for (const ChurnNode& node : nodes)
        {
            if (node.live == 1)
            {
                checksum = churn_mix(checksum, node.value);
                for (int edge : node.edges)
                    if (nodes[edge].live == 1) checksum = churn_mix(checksum, edge);
            }
        }
        return churn_mix(checksum, static_cast<int>(free_list.size()));
    }

    int64_t churn_alloc(int scale)
    {
        const int window = 192;
        const int steps = 10000 * scale;
        std::vector<ChurnFrag> slots;
        slots.reserve(window);
        for (int i = 0; i < window; ++i) slots.push_back(churn_fragment(i));
        std::vector<ChurnFrag> kept;
        kept.reserve(steps / 50 + 1);
        int64_t seed = 99991;
        int64_t checksum = 0;
        for (int step = 0; step < steps; ++step)
        {
            seed = churn_next(seed);
            const int slot = static_cast<int>(seed % window);
            checksum = (checksum * 31 + churn_frag_sum(slots[slot])) % CHURN_MOD;
            slots[slot] = churn_fragment(window + step);
            if (step % 50 == 0) kept.push_back(churn_fragment(window + steps + step));
        }
        for (const ChurnFrag& frag : slots) checksum = (checksum * 31 + churn_frag_sum(frag)) % CHURN_MOD;
        for (const ChurnFrag& frag : kept) checksum = (checksum * 31 + churn_frag_sum(frag)) % CHURN_MOD;
        return churn_mix(checksum, static_cast<int>(kept.size()));
    }

    int64_t churn_transfer(int scale)
    {
        const int count = 5000 * scale;
        BoundedQueue<ChurnFrag> ch1(16);
        BoundedQueue<ChurnFrag> ch2(16);

        std::thread producer([&]()
        {
            for (int i = 0; i < count; ++i) ch1.send(churn_fragment(i));
            ch1.close();
        });

        int trimmed = 0;
        std::thread trimmer([&]()
        {
            int64_t acc = 0;
            while (true)
            {
                auto taken = ch1.recv();
                if (!taken.has_value()) break;
                ChurnFrag frag = std::move(*taken);
                acc = (acc * 31 + churn_frag_sum(frag)) % CHURN_MOD;
                for (ChurnNode& node : frag.nodes)
                    if (node.value % 3 == 0) node.edges = std::vector<int>();
                ch2.send(std::move(frag));
            }
            ch2.close();
            trimmed = static_cast<int>(acc);
        });

        const int ring = 64;
        std::vector<ChurnFrag> recent;
        recent.reserve(ring);
        for (int i = 0; i < ring; ++i) recent.push_back(ChurnFrag{std::vector<ChurnNode>(), -1});
        int64_t checksum = 0;
        int seen = 0;
        while (true)
        {
            auto taken = ch2.recv();
            if (!taken.has_value()) break;
            ChurnFrag frag = std::move(*taken);
            checksum = (checksum * 31 + churn_frag_sum(frag)) % CHURN_MOD;
            recent[seen % ring] = std::move(frag);
            seen += 1;
        }

        producer.join();
        trimmer.join();

        for (const ChurnFrag& frag : recent) checksum = (checksum * 31 + churn_frag_sum(frag)) % CHURN_MOD;
        checksum = churn_mix(checksum, trimmed);
        return churn_mix(checksum, count + seen);
    }
} // namespace

int graph_churn_single(int scale) { return static_cast<int>(churn_single(scale)); }

int graph_churn_alloc(int scale) { return static_cast<int>(churn_alloc(scale)); }

int graph_churn_transfer(int scale) { return static_cast<int>(churn_transfer(scale)); }

int graph_churn_full(int scale)
{
    const int64_t single = churn_single(scale);
    const int64_t alloc = churn_alloc(scale);
    const int64_t transfer = churn_transfer(scale);
    return static_cast<int>(((single * 31 + alloc) % CHURN_MOD * 31 + transfer) % CHURN_MOD);
}
