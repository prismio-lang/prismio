#!/usr/bin/env python3
"""One-time mechanical split of benchmark dispatchers into category modules."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def between(text, start, end):
    return text[text.index(start):text.index(end)].rstrip() + "\n"


def write(path, text):
    path.write_text(text.rstrip() + "\n")


cpp_dir = ROOT / "benchmarks/cpp"
cpp = (cpp_dir / "suite.cpp").read_text()
cpp_header = r'''#pragma once

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
'''
write(cpp_dir / "benchmarks.hpp", cpp_header)

cpp_sections = {
    "algorithms.cpp": between(cpp, "int gcd_value", "int hashmap_insert_lookup"),
    "data_structures.cpp": between(cpp, "int hashmap_insert_lookup", "int matrix_multiply"),
    "compute.cpp": between(cpp, "int matrix_multiply", "int transient_allocation"),
    "memory.cpp": between(cpp, "int transient_allocation", "std::string read_file"),
    "io.cpp": between(cpp, "std::string read_file", "int run("),
}
cpp_prefixes = {
    "algorithms.cpp": '#include "benchmarks.hpp"\n\n#include <algorithm>\n#include <cstdint>\n#include <vector>\n\n',
    "data_structures.cpp": '#include "benchmarks.hpp"\n\n#include <unordered_map>\n#include <vector>\n\n',
    "compute.cpp": '#include "benchmarks.hpp"\n\n#include <cmath>\n#include <thread>\n#include <vector>\n\nstruct Particle { double x, y, vx, vy; int life; };\n\n',
    "memory.cpp": '#include "benchmarks.hpp"\n\n#include <vector>\n\n',
    "io.cpp": '#include "benchmarks.hpp"\n\n#include <fstream>\n\n',
}
for filename, section in cpp_sections.items():
    section = section.replace("MOD", "BENCH_MOD").replace("next_random", "bench_next_random").replace("Tree", "BenchTree")
    write(cpp_dir / filename, cpp_prefixes[filename] + section)

cpp_run = between(cpp, "int run(", "}  // namespace")
cpp_main = cpp[cpp.index("int main("):].strip()
write(cpp_dir / "suite.cpp", '#include "benchmarks.hpp"\n\n#include <chrono>\n#include <iostream>\n\n' + cpp_run + "\n" + cpp_main)


rust_dir = ROOT / "benchmarks/rust"
rust = (rust_dir / "suite.rs").read_text()
rust_common = r'''pub const BENCH_MOD: i32 = 1_000_000_007;

pub fn next_random(seed: i32) -> i32 { (seed * 25173 + 13849) % 65521 }

pub struct BenchTree {
    pub value: i32,
    pub left: Option<Box<BenchTree>>,
    pub right: Option<Box<BenchTree>>,
}
'''
write(rust_dir / "common.rs", rust_common)

rust_sections = {
    "algorithms.rs": between(rust, "fn gcd_value", "fn hashmap_insert_lookup"),
    "data_structures.rs": between(rust, "fn hashmap_insert_lookup", "fn matrix_multiply"),
    "compute.rs": between(rust, "fn matrix_multiply", "fn transient_allocation"),
    "memory.rs": between(rust, "fn transient_allocation", "fn byte_sum"),
    "io.rs": between(rust, "fn byte_sum", "fn run("),
}
rust_prefixes = {
    "algorithms.rs": "use crate::common::{next_random, BenchTree, BENCH_MOD};\n\n",
    "data_structures.rs": "use std::collections::HashMap;\n\nuse crate::common::{next_random, BENCH_MOD};\n\n",
    "compute.rs": "use std::thread;\n\nuse crate::common::{next_random, BENCH_MOD};\n\nstruct Particle { x: f64, y: f64, vx: f64, vy: f64, life: i32 }\n\n",
    "memory.rs": "use crate::common::{BenchTree, BENCH_MOD};\n\n",
    "io.rs": "use std::fs;\n\nuse crate::common::BENCH_MOD;\n\n",
}
rust_exports = {
    "algorithms.rs": ["fibonacci", "prime_sieve", "gcd_lcm", "binary_search_work", "quicksort_work", "mergesort_work", "string_search", "graph_bfs", "knapsack", "tree_traversal"],
    "data_structures.rs": ["hashmap_insert_lookup", "vector_growth", "vector_iteration", "key_value_update"],
    "compute.rs": ["matrix_multiply", "mandelbrot", "fft", "numerical_integration", "vector_dot", "convolution", "monte_carlo", "polynomial_evaluation", "ecs_component_update", "parallel_reduction"],
    "memory.rs": ["transient_allocation", "struct_creation", "allocation_mutation", "nested_collection", "large_buffer_copy", "recursive_tree_rebuild"],
    "io.rs": ["file_read", "file_write", "line_processing", "tokenization"],
}
for filename, section in rust_sections.items():
    section = section.replace("MOD", "BENCH_MOD").replace("Tree", "BenchTree")
    for function in rust_exports[filename]:
        section = section.replace("fn " + function + "(", "pub fn " + function + "(", 1)
    write(rust_dir / filename, rust_prefixes[filename] + section)

rust_suite = r'''mod algorithms;
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
'''
write(rust_dir / "suite.rs", rust_suite)


prismio_dir = ROOT / "benchmarks/prismio"
prismio = (prismio_dir / "suite.psm").read_text()
prismio_common = r'''import std.string

extern fn clock_gettime(clk: Int, stamp: BenchTimespec) -> Int
extern fn prismio_rt_print(text: String borrow)
extern fn prismio_rt_println(text: String borrow)

fn benchPrint(text: String) { prismio_rt_print(text) }
fn benchPrintln(text: String) { prismio_rt_println(text) }
fn benchPrintln(value: Int) { prismio_rt_println(strFromInt(value)) }

struct BenchTimespec {
    seconds: I64,
    nanoseconds: I64
}

fn benchNow() -> I64 {
    let stamp = BenchTimespec { seconds: 0, nanoseconds: 0 }
    clock_gettime(4, stamp)
    return stamp.seconds * 1000000000 + stamp.nanoseconds
}

struct BenchBucket {
    values: List<Int>
}

struct BenchBand {
    seed: Int,
    steps: Int
}

enum BenchTree {
    Empty,
    Node(BenchTree, Int, BenchTree)
}

fn benchRandom(seed: Int) -> Int {
    return (seed * 25173 + 13849) % 65521
}
'''
write(prismio_dir / "common.psm", prismio_common)

prismio_sections = {
    "algorithms.psm": between(prismio, "fn benchGcd", "fn benchHashMap"),
    "data_structures.psm": between(prismio, "fn benchHashMap", "fn benchMatrixMultiply"),
    "compute.psm": between(prismio, "fn benchMatrixMultiply", "fn benchTransientAllocation"),
    "memory.psm": between(prismio, "fn benchTransientAllocation", "fn benchByteSum"),
    "io.psm": between(prismio, "fn benchByteSum", "fn benchRun("),
}
prismio_prefixes = {
    "algorithms.psm": "import common\nimport std.string\n\n",
    "data_structures.psm": "import common\nimport std.map\n\n",
    "compute.psm": "import common\n\nextern fn cos(value: Float) -> Float\nextern fn sin(value: Float) -> Float\n\nstruct BenchParticle {\n    x: Float,\n    y: Float,\n    vx: Float,\n    vy: Float,\n    life: Int\n}\n\n",
    "memory.psm": "import common\n\n",
    "io.psm": "import common\nimport std.fs\nimport std.string\n\n",
}
for filename, section in prismio_sections.items():
    write(prismio_dir / filename, prismio_prefixes[filename] + section)

prismio_dispatch = between(prismio, "fn benchRun(", "fn main()")
prismio_dispatch = prismio_dispatch.replace('strEquals(name, "', 'name.equals("')
prismio_suite = """import algorithms
import common
import compute
import data_structures
import io
import memory
import std.process
import std.string

""" + prismio_dispatch + "\n" + prismio[prismio.index("fn main()"):].strip() + "\n"
write(prismio_dir / "suite.psm", prismio_suite)
