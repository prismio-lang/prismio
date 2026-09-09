mod algorithms;
mod adversarial;
mod common;
mod compute;
mod data_structures;
mod io;
mod memory;

use std::env;
use std::time::Instant;

fn run(name: &str, scale: i32, input: &str, output: &str) -> i32 {
    match name {
        "fibonacci" => algorithms::fibonacci(scale),
        "prime_sieve" => algorithms::prime_sieve(scale),
        "gcd_lcm" => algorithms::gcd_lcm(scale),
        "binary_search" => algorithms::binary_search_work(scale),
        "quicksort" => algorithms::quicksort_work(scale),
        "mergesort" => algorithms::mergesort_work(scale),
        "string_search" => algorithms::string_search(scale),
        "graph_bfs" => algorithms::graph_bfs(scale),
        "knapsack" => algorithms::knapsack(scale),
        "tree_traversal" => algorithms::tree_traversal(scale),
        "hashmap_insert_lookup" => data_structures::hashmap_insert_lookup(scale),
        "vector_growth" => data_structures::vector_growth(scale),
        "vector_iteration" => data_structures::vector_iteration(scale),
        "key_value_update" => data_structures::key_value_update(scale),
        "matrix_multiply" => compute::matrix_multiply(scale),
        "mandelbrot" => compute::mandelbrot(scale),
        "fft" => compute::fft(scale),
        "numerical_integration" => compute::numerical_integration(scale),
        "vector_dot" => compute::vector_dot(scale),
        "convolution" => compute::convolution(scale),
        "monte_carlo" => compute::monte_carlo(scale),
        "polynomial_evaluation" => compute::polynomial_evaluation(scale),
        "ecs_component_update" => compute::ecs_component_update(scale),
        "parallel_reduction" => compute::parallel_reduction(scale),
        "transient_allocation" => memory::transient_allocation(scale),
        "struct_creation" => memory::struct_creation(scale),
        "allocation_mutation" => memory::allocation_mutation(scale),
        "nested_collection" => memory::nested_collection(scale),
        "large_buffer_copy" => memory::large_buffer_copy(scale),
        "recursive_tree_rebuild" => memory::recursive_tree_rebuild(scale),
        "file_read" => io::file_read(input),
        "file_write" => io::file_write(scale, output),
        "line_processing" => io::line_processing(input),
        "tokenization" => io::tokenization(scale),
        "dijkstra_shortest_path" => algorithms::dijkstra_shortest_path(scale),
        "lz4_compress" => algorithms::lz4_compress(scale),
        "s_expression_parse" => algorithms::s_expression_parse(scale),
        "flat_bitset" => data_structures::flat_bitset(scale),
        "trie_search" => data_structures::trie_search(scale),
        "sha256" => compute::sha256(scale),
        "blake3_chunk" => compute::blake3_chunk(scale),
        "raytracer_sphere" => compute::raytracer_sphere(scale),
        "channel_pipeline" => compute::channel_pipeline(scale),
        "base64_codec" => io::base64_codec(scale),
        "csv_parse" => io::csv_parse(scale),
        "pointer_chase" => adversarial::pointer_chase(scale),
        "random_gather" => adversarial::random_gather(scale),
        "branch_mispredict" => adversarial::branch_mispredict(scale),
        "strided_memory" => adversarial::strided_memory(scale),
        "allocation_escape" => adversarial::allocation_escape(scale),
        "function_call_overhead" => adversarial::function_call_overhead(scale),
        "indirect_calls" => adversarial::indirect_calls(scale),
        "dependency_chain" => adversarial::dependency_chain(scale),
        "aos_vs_soa" => adversarial::aos_vs_soa(scale),
        "switch_dispatch" => adversarial::switch_dispatch(scale),
        "memcpy_mix" => adversarial::memcpy_mix(scale),
        "dead_code_elimination" => adversarial::dead_code_elimination(scale),
        "word_frequency" => algorithms::word_frequency(scale),
        "sort_strings" => algorithms::sort_strings(scale),
        "edit_distance" => algorithms::edit_distance(scale),
        "string_join" => memory::string_join(scale),
        "bytecode_interpreter" => compute::bytecode_interpreter(scale),
        _ => -1,
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        println!("usage: suite <benchmark> [input] [output]");
        std::process::exit(2);
    }
    let input = args.get(2).map(String::as_str).unwrap_or("");
    let output = args.get(3).map(String::as_str).unwrap_or("");
    let start = Instant::now();
    let result = run(&args[1], 4, input, output);
    let elapsed = start.elapsed().as_nanos();
    if result < 0 {
        println!("unknown or failed benchmark");
        std::process::exit(2);
    }
    println!("result: {result}\nelapsed_ns: {elapsed}");
}
