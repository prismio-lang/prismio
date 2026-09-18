#include "benchmarks.hpp"

#include <cstdint>
#include <fstream>
#include <vector>

std::string read_file(const std::string& path) {
    std::ifstream input(path, std::ios::binary);
    return {std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>()};
}

int byte_sum(const std::string& text) {
    int checksum = 0; for (unsigned char byte : text) checksum = (checksum + byte) % BENCH_MOD;
    return checksum + static_cast<int>(text.size());
}

int file_read(const std::string& path) { return byte_sum(read_file(path)); }

int file_write(int scale, const std::string& path) {
    std::string content; const std::string part = "0123456789abcdef\n";
    content.reserve(part.size() * 4096 * scale);
    for (int i = 0; i < 4096 * scale; ++i) content += part;
    std::ofstream output(path, std::ios::binary | std::ios::trunc); output.write(content.data(), static_cast<std::streamsize>(content.size()));
    return output ? byte_sum(content) : -1;
}

int line_processing(const std::string& path) {
    const std::string text = read_file(path); std::vector<std::string> owned_lines; std::size_t start = 0;
    for (std::size_t i = 0; i < text.size(); ++i) if (text[i] == '\n') {
        std::size_t end = i; if (end > start && text[end - 1] == '\r') --end;
        owned_lines.emplace_back(text, start, end - start); start = i + 1;
    }
    if (start < text.size()) {
        std::size_t end = text.size(); if (text[end - 1] == '\r') --end;
        owned_lines.emplace_back(text, start, end - start);
    }
    int checksum = 0;
    for (const auto& line : owned_lines) {
        int as = 0; for (char value : line) if (value == 'a') ++as;
        checksum = (checksum + static_cast<int>(line.size()) * 31 + as) % BENCH_MOD;
    }
    return checksum + static_cast<int>(owned_lines.size());
}

bool alpha(unsigned char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
bool digit(unsigned char c) { return c >= '0' && c <= '9'; }
bool space(unsigned char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; }

int tokenization(int scale) {
    std::string text; const std::string part = "let value_17 = alpha + beta * 17;\n";
    text.reserve(part.size() * 1500 * scale); for (int i = 0; i < 1500 * scale; ++i) text += part;
    std::size_t position = 0; int tokens = 0, checksum = 0;
    while (position < text.size()) {
        const unsigned char c = text[position];
        if (space(c)) { ++position; continue; }
        const std::size_t start = position;
        if (alpha(c) || c == '_') { ++position; while (position < text.size() && (alpha(text[position]) || digit(text[position]) || text[position] == '_')) ++position; }
        else if (digit(c)) { ++position; while (position < text.size() && digit(text[position])) ++position; }
        else ++position;
        const std::string token = text.substr(start, position - start);
        ++tokens; checksum = (checksum + static_cast<int>(token.size()) * tokens) % BENCH_MOD;
    }
    return checksum + tokens;
}

int base64_codec(int scale) {
    const int n = 30000 * scale;
    std::vector<uint8_t> input(n);
    int seed = 17;
    for (int i = 0; i < n; ++i) {
        seed = bench_next_random(seed);
        input[i] = static_cast<uint8_t>(seed % 256);
    }

    static const char B64_CHARS[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string encoded;
    encoded.resize((n / 3) * 4);

    size_t j = 0;
    for (size_t i = 0; i < n; i += 3) {
        uint32_t b0 = input[i];
        uint32_t b1 = input[i + 1];
        uint32_t b2 = input[i + 2];

        encoded[j++] = B64_CHARS[b0 >> 2];
        encoded[j++] = B64_CHARS[((b0 & 3) << 4) | (b1 >> 4)];
        encoded[j++] = B64_CHARS[((b1 & 15) << 2) | (b2 >> 6)];
        encoded[j++] = B64_CHARS[b2 & 63];
    }

    uint8_t inv[256] = {};
    for (int i = 0; i < 64; ++i) inv[static_cast<uint8_t>(B64_CHARS[i])] = static_cast<uint8_t>(i);

    std::vector<uint8_t> decoded(n);
    size_t di = 0;
    for (size_t i = 0; i < encoded.size(); i += 4) {
        uint8_t c0 = inv[static_cast<uint8_t>(encoded[i])];
        uint8_t c1 = inv[static_cast<uint8_t>(encoded[i + 1])];
        uint8_t c2 = inv[static_cast<uint8_t>(encoded[i + 2])];
        uint8_t c3 = inv[static_cast<uint8_t>(encoded[i + 3])];

        decoded[di++] = static_cast<uint8_t>((c0 << 2) | (c1 >> 4));
        decoded[di++] = static_cast<uint8_t>(((c1 & 15) << 4) | (c2 >> 2));
        decoded[di++] = static_cast<uint8_t>(((c2 & 3) << 6) | c3);
    }

    long long checksum = 0;
    for (uint8_t b : decoded) checksum = (checksum * 31 + b) % BENCH_MOD;
    return static_cast<int>((checksum + encoded.size()) % BENCH_MOD);
}

int csv_parse(int scale) {
    const int rows = 2500 * scale;
    std::string csv_data;
    csv_data.reserve(rows * 60);

    int seed = 61;
    for (int r = 0; r < rows; ++r) {
        seed = bench_next_random(seed);
        int id = 1000 + (seed % 9000);
        seed = bench_next_random(seed);
        int amount = seed % 10000;
        seed = bench_next_random(seed);
        int score = seed % 100;

        std::string name_str;
        if (r % 3 == 0) {
            name_str = "\"User \"\"Super\"\" " + std::to_string(r % 100) + "\",";
        } else {
            name_str = "User_" + std::to_string(r % 500) + ",";
        }

        std::string status_str = (r % 2 == 0) ? "active" : "pending";
        std::string line = std::to_string(id) + "," + name_str + std::to_string(amount) + "," + status_str + "," + std::to_string(score) + "\n";
        csv_data += line;
    }

    long long sum_id = 0, sum_len = 0, sum_amount = 0, sum_status = 0, sum_score = 0;
    int col = 0;
    int field_int = 0;
    int field_len = 0;
    bool in_quote = false;

    for (size_t pos = 0; pos < csv_data.size(); ++pos) {
        char b = csv_data[pos];
        if (b == '"') {
            if (in_quote && pos + 1 < csv_data.size() && csv_data[pos + 1] == '"') {
                field_len++;
                pos++;
            } else {
                in_quote = !in_quote;
            }
        } else if (!in_quote && (b == ',' || b == '\n')) {
            if (col == 0) sum_id = (sum_id + field_int) % BENCH_MOD;
            else if (col == 1) sum_len = (sum_len + field_len) % BENCH_MOD;
            else if (col == 2) sum_amount = (sum_amount + field_int) % BENCH_MOD;
            else if (col == 3) sum_status = (sum_status + field_len) % BENCH_MOD;
            else if (col == 4) sum_score = (sum_score + field_int) % BENCH_MOD;

            field_int = 0;
            field_len = 0;
            col = (b == ',') ? col + 1 : 0;
        } else {
            if (b >= '0' && b <= '9') {
                field_int = field_int * 10 + (b - '0');
            }
            field_len++;
        }
    }

    long long checksum = (sum_id * 10007 + sum_len * 31 + sum_amount * 17 + sum_status * 13 + sum_score) % BENCH_MOD;
    return static_cast<int>(checksum);
}
