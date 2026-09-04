#include "benchmarks.hpp"

#include <fstream>

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
