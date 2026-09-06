#include <iostream>
#include <vector>
#include <chrono>

int main() {
    int scale = 4;
    auto t0 = std::chrono::high_resolution_clock::now();
    const int count = 200 * scale; 
    std::vector<std::vector<int>> buckets; 
    buckets.reserve(count);
    for (int b = 0; b < count; ++b) {
        std::vector<int> values; values.reserve(1000);
        for (int i = 0; i < 1000; ++i) values.push_back((b + i) % 1021);
        buckets.push_back(std::move(values));
    }
    auto t1 = std::chrono::high_resolution_clock::now();
    int checksum = 0; 
    for (const auto& bucket : buckets) 
        for (int value : bucket) 
            checksum = (checksum + value) % 1000000007;
    auto t2 = std::chrono::high_resolution_clock::now();

    std::cout << "C++ Creation time: " << std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count() << " ns\n";
    std::cout << "C++ Traversal time: " << std::chrono::duration_cast<std::chrono::nanoseconds>(t2 - t1).count() << " ns\n";
    std::cout << "C++ Total time: " << std::chrono::duration_cast<std::chrono::nanoseconds>(t2 - t0).count() << " ns\n";
    std::cout << "Checksum: " << checksum << "\n";
    return 0;
}
