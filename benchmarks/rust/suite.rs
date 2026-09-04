mod algorithms;
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
