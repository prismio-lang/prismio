#include "benchmarks.hpp"

#include <chrono>
#include <iostream>

int run(const std::string& name, int scale, const std::string& input, const std::string& output) {
    if (name == "fibonacci") return fibonacci(scale);
    if (name == "prime_sieve") return prime_sieve(scale);
    if (name == "gcd_lcm") return gcd_lcm(scale);
    if (name == "binary_search") return binary_search_work(scale);
    if (name == "quicksort") return quicksort_work(scale);
    if (name == "mergesort") return mergesort_work(scale);
    if (name == "string_search") return string_search(scale);
    if (name == "graph_bfs") return graph_bfs(scale);
    if (name == "knapsack") return knapsack(scale);
    if (name == "tree_traversal") return tree_traversal(scale);
    if (name == "hashmap_insert_lookup") return hashmap_insert_lookup(scale);
    if (name == "vector_growth") return vector_growth(scale);
    if (name == "vector_iteration") return vector_iteration(scale);
    if (name == "key_value_update") return key_value_update(scale);
    if (name == "matrix_multiply") return matrix_multiply(scale);
    if (name == "mandelbrot") return mandelbrot(scale);
    if (name == "fft") return fft(scale);
    if (name == "numerical_integration") return numerical_integration(scale);
    if (name == "vector_dot") return vector_dot(scale);
    if (name == "convolution") return convolution(scale);
    if (name == "monte_carlo") return monte_carlo(scale);
    if (name == "polynomial_evaluation") return polynomial_evaluation(scale);
    if (name == "ecs_component_update") return ecs_component_update(scale);
    if (name == "parallel_reduction") return parallel_reduction(scale);
    if (name == "transient_allocation") return transient_allocation(scale);
    if (name == "struct_creation") return struct_creation(scale);
    if (name == "allocation_mutation") return allocation_mutation(scale);
    if (name == "nested_collection") return nested_collection(scale);
    if (name == "large_buffer_copy") return large_buffer_copy(scale);
    if (name == "recursive_tree_rebuild") return recursive_tree_rebuild(scale);
    if (name == "file_read") return file_read(input);
    if (name == "file_write") return file_write(scale, output);
    if (name == "line_processing") return line_processing(input);
    if (name == "tokenization") return tokenization(scale);
    return -1;
}

int main(int argc, char** argv) {
    if (argc < 2) { std::cout << "usage: suite <benchmark> [input] [output]\n"; return 2; }
    constexpr int scale = 4;
    const std::string input = argc > 2 ? argv[2] : "";
    const std::string output = argc > 3 ? argv[3] : "";
    const auto start = std::chrono::steady_clock::now();
    const int result = run(argv[1], scale, input, output);
    const auto elapsed = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now() - start).count();
    if (result < 0) { std::cout << "unknown or failed benchmark\n"; return 2; }
    std::cout << "result: " << result << "\nelapsed_ns: " << elapsed << '\n';
    return 0;
}
