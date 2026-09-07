#pragma once

#include <memory>
#include <string>

inline constexpr int BENCH_MOD = 1'000'000'007;

inline int bench_next_random(int seed) { return (seed * 25173 + 13849) % 65521; }

struct BenchTree {
    int value;
    std::unique_ptr<BenchTree> left;
    std::unique_ptr<BenchTree> right;
};

int fibonacci(int scale);
int prime_sieve(int scale);
int gcd_lcm(int scale);
int binary_search_work(int scale);
int quicksort_work(int scale);
int mergesort_work(int scale);
int string_search(int scale);
int graph_bfs(int scale);
int knapsack(int scale);
int tree_traversal(int scale);

int hashmap_insert_lookup(int scale);
int vector_growth(int scale);
int vector_iteration(int scale);
int key_value_update(int scale);

int matrix_multiply(int scale);
int mandelbrot(int scale);
int fft(int scale);
int numerical_integration(int scale);
int vector_dot(int scale);
int convolution(int scale);
int monte_carlo(int scale);
int polynomial_evaluation(int scale);
int ecs_component_update(int scale);
int parallel_reduction(int scale);

int transient_allocation(int scale);
int struct_creation(int scale);
int allocation_mutation(int scale);
int nested_collection(int scale);
int large_buffer_copy(int scale);
int recursive_tree_rebuild(int scale);

int file_read(const std::string& path);
int file_write(int scale, const std::string& path);
int line_processing(const std::string& path);
int tokenization(int scale);
int base64_codec(int scale);
int csv_parse(int scale);

int dijkstra_shortest_path(int scale);
int lz4_compress(int scale);
int s_expression_parse(int scale);

int flat_bitset(int scale);
int trie_search(int scale);

int sha256(int scale);
int blake3_chunk(int scale);
int raytracer_sphere(int scale);
int channel_pipeline(int scale);

int pointer_chase(int scale);
int random_gather(int scale);
int branch_mispredict(int scale);
int strided_memory(int scale);
int allocation_escape(int scale);
int function_call_overhead(int scale);
int indirect_calls(int scale);
int dependency_chain(int scale);
int aos_vs_soa(int scale);
int switch_dispatch(int scale);
int memcpy_mix(int scale);
int dead_code_elimination(int scale);
