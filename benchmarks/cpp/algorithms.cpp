#include "benchmarks.hpp"

#include <algorithm>
#include <cstdint>
#include <queue>
#include <string>
#include <unordered_map>
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

int dijkstra_shortest_path(int scale) {
    const int v_count = 1000 * scale;
    const int e_count = v_count + 5000 * scale;

    std::vector<int> head(v_count, -1);
    std::vector<int> edge_to(e_count, 0);
    std::vector<int> edge_weight(e_count, 0);
    std::vector<int> edge_next(e_count, 0);

    int edge_idx = 0;
    for (int ri = 0; ri < v_count; ++ri) {
        edge_to[edge_idx] = (ri + 1) % v_count;
        edge_weight[edge_idx] = (ri % 30) + 1;
        edge_next[edge_idx] = head[ri];
        head[ri] = edge_idx++;
    }

    int seed = 47;
    while (edge_idx < e_count) {
        seed = bench_next_random(seed);
        int u = seed % v_count;
        seed = bench_next_random(seed);
        int v = seed % v_count;
        seed = bench_next_random(seed);
        int w = (seed % 50) + 1;

        edge_to[edge_idx] = v;
        edge_weight[edge_idx] = w;
        edge_next[edge_idx] = head[u];
        head[u] = edge_idx++;
    }

    const int inf = 1000000000;
    std::vector<int> dist(v_count, inf);
    dist[0] = 0;

    using PII = std::pair<int, int>;
    std::priority_queue<PII, std::vector<PII>, std::greater<PII>> pq;
    pq.push({0, 0});

    while (!pq.empty()) {
        auto [d, u] = pq.top();
        pq.pop();

        if (d > dist[u]) continue;

        for (int e = head[u]; e != -1; e = edge_next[e]) {
            int v = edge_to[e];
            int alt = d + edge_weight[e];
            if (alt < dist[v]) {
                dist[v] = alt;
                pq.push({alt, v});
            }
        }
    }

    long long checksum = 0;
    for (int i = 0; i < v_count; ++i) {
        if (dist[i] < inf) {
            long long term = (static_cast<long long>(dist[i]) * (i % 100 + 1)) % BENCH_MOD;
            checksum = (checksum + term) % BENCH_MOD;
        }
    }
    return static_cast<int>(checksum);
}

int lz4_compress(int scale) {
    const int n = 20000 * scale;
    std::vector<uint8_t> input(n);

    int seed = 83;
    for (int i = 0; i < n; ++i) {
        seed = bench_next_random(seed);
        if (i > 20 && (seed % 4) == 0) {
            int offset = 12 + (seed % 8);
            input[i] = input[i - offset];
        } else {
            input[i] = static_cast<uint8_t>(32 + (seed % 95));
        }
    }

    std::vector<int> table(4096, -1);
    int pos = 0;
    int token_count = 0;
    int literal_len = 0;
    long long checksum = 0;

    while (pos + 4 <= n) {
        uint8_t b0 = input[pos];
        uint8_t b1 = input[pos + 1];
        uint8_t b2 = input[pos + 2];
        uint8_t b3 = input[pos + 3];

        int h = ((b0 << 12) ^ (b1 << 8) ^ (b2 << 4) ^ b3) % 4096;
        int ref_pos = table[h];
        table[h] = pos;

        if (ref_pos != -1 && (pos - ref_pos) < 65535 &&
            input[ref_pos] == b0 && input[ref_pos + 1] == b1 &&
            input[ref_pos + 2] == b2 && input[ref_pos + 3] == b3) {

            int match_len = 4;
            while (pos + match_len < n && input[pos + match_len] == input[ref_pos + match_len] && match_len < 255) {
                match_len++;
            }

            int offset = pos - ref_pos;
            long long term = static_cast<long long>(literal_len) * 10007 + match_len * 31 + offset;
            checksum = (checksum * 31 + term) % BENCH_MOD;
            token_count++;
            literal_len = 0;
            pos += match_len;
        } else {
            literal_len++;
            pos++;
        }
    }

    checksum = (checksum + token_count + literal_len) % BENCH_MOD;
    return static_cast<int>(checksum);
}

static std::string build_one_sexpr(int depth, int& seed) {
    if (depth <= 0) {
        seed = bench_next_random(seed);
        return std::to_string((seed % 100) + 1);
    }
    seed = bench_next_random(seed);
    char op = "+-*"[seed % 3];
    return "(" + std::string(1, op) + " " + build_one_sexpr(depth - 1, seed) + " " + build_one_sexpr(depth - 1, seed) + ")";
}

struct SExprASTNode {
    int tag; // 0 = num, 1 = op
    int val;
    std::unique_ptr<SExprASTNode> left;
    std::unique_ptr<SExprASTNode> right;
};

static std::unique_ptr<SExprASTNode> parse_sexpr_ast(const std::string& s, int& pos) {
    while (pos < (int)s.size() && (s[pos] == ' ' || s[pos] == '\n')) pos++;
    if (pos >= (int)s.size()) return nullptr;
    if (s[pos] == '(') {
        pos++;
        while (pos < (int)s.size() && s[pos] == ' ') pos++;
        char op = s[pos++];
        auto left = parse_sexpr_ast(s, pos);
        auto right = parse_sexpr_ast(s, pos);
        while (pos < (int)s.size() && s[pos] == ' ') pos++;
        if (pos < (int)s.size() && s[pos] == ')') pos++;
        auto node = std::make_unique<SExprASTNode>();
        node->tag = 1;
        node->val = op;
        node->left = std::move(left);
        node->right = std::move(right);
        return node;
    } else {
        int num = 0;
        while (pos < (int)s.size() && s[pos] >= '0' && s[pos] <= '9') {
            num = num * 10 + (s[pos++] - '0');
        }
        auto node = std::make_unique<SExprASTNode>();
        node->tag = 0;
        node->val = num;
        return node;
    }
}

static int eval_sexpr_ast(const SExprASTNode* e) {
    if (!e) return 0;
    if (e->tag == 0) return e->val;
    long long left = eval_sexpr_ast(e->left.get());
    long long right = eval_sexpr_ast(e->right.get());
    if (e->val == '+') return (left + right) % BENCH_MOD;
    if (e->val == '-') return (left - right + BENCH_MOD) % BENCH_MOD;
    return (left * right) % BENCH_MOD;
}

int s_expression_parse(int scale) {
    const int count = 400 * scale;
    std::string all_text;
    all_text.reserve(count * 60);
    int seed = 42;
    for (int i = 0; i < count; ++i) {
        all_text += build_one_sexpr(4, seed) + "\n";
    }

    int pos = 0;
    long long checksum = 0;
    while (pos < (int)all_text.size()) {
        auto expr = parse_sexpr_ast(all_text, pos);
        if (expr) {
            checksum = (checksum + eval_sexpr_ast(expr.get())) % BENCH_MOD;
        }
    }
    return static_cast<int>(checksum);
}

int word_frequency(int scale) {
    std::string text;
    const std::string sentence = "the quick brown fox jumps over the lazy dog while the fox naps ";
    text.reserve(sentence.size() * 400 * scale);
    for (int r = 0; r < 400 * scale; ++r) text += sentence;

    std::vector<std::string> words;
    for (std::size_t at = 0; at < text.size();) {
        while (at < text.size() && text[at] == ' ') ++at;
        const std::size_t start = at;
        while (at < text.size() && text[at] != ' ') ++at;
        if (at > start) words.emplace_back(text, start, at - start);
    }

    std::unordered_map<std::string, int> counts;
    for (const std::string& word : words) counts[word] = counts[word] + 1;

    const std::vector<std::string> vocabulary = {"the", "quick", "brown", "fox", "jumps",
                                                 "over", "lazy", "dog", "while", "naps"};
    std::vector<int> tally;
    tally.reserve(vocabulary.size());
    for (const std::string& word : vocabulary) {
        const auto found = counts.find(word);
        tally.push_back(found == counts.end() ? 0 : found->second);
    }

    std::sort(tally.begin(), tally.end());

    int checksum = static_cast<int>(counts.size());
    for (std::size_t t = 0; t < tally.size(); ++t)
        checksum = (checksum + static_cast<int>(t + 1) * tally[t]) % BENCH_MOD;
    return checksum;
}

int sort_strings(int scale) {
    const int n = 20000 * scale;
    std::vector<std::string> items;
    items.reserve(n);
    int seed = 7;
    for (int i = 0; i < n; ++i) {
        seed = bench_next_random(seed);
        std::string entry;
        entry.reserve(16);
        entry += "key";
        entry += std::to_string(seed % 65521);
        entry += "-";
        entry += std::to_string(i % 977);
        items.push_back(std::move(entry));
    }

    std::sort(items.begin(), items.end());

    int checksum = 0;
    for (int k = 0; k < n; ++k)
        checksum = (checksum + (k + 1) * static_cast<int>(static_cast<unsigned char>(items[k][3]))) % BENCH_MOD;
    return checksum;
}

int edit_distance(int scale) {
    std::string left, right;
    const std::string a = "kitten_sitting_flitting_knitting_", b = "sitting_kitten_blitting_knotting_";
    for (int r = 0; r < 6 * scale; ++r) { left += a; right += b; }
    const int rows = static_cast<int>(left.size()), columns = static_cast<int>(right.size());
    const int stride = columns + 1;

    std::vector<int> table(2 * stride, 0);
    for (int j = 0; j <= columns; ++j) table[j] = j;

    for (int i = 1; i <= rows; ++i) {
        const int current = (i % 2) * stride, previous = ((i - 1) % 2) * stride;
        table[current] = i;
        const char left_char = left[i - 1];
        for (int c = 1; c <= columns; ++c) {
            const int cost = 1 - (left_char == right[c - 1]);
            const int deletion = table[previous + c] + 1;
            const int insertion = table[current + c - 1] + 1;
            const int substitution = table[previous + c - 1] + cost;
            table[current + c] = std::min(std::min(deletion, insertion), substitution);
        }
    }
    return table[(rows % 2) * stride + columns];
}
