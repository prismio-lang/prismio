#!/usr/bin/env python3
"""Build and compare Prismio, C, Rust std, and Rust memchr strings."""

import argparse
import statistics
import subprocess
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
BUILD = HERE / "build"
BENCHES = [
    "search_rare",
    "search_dense",
    "search_long",
    "uppercase",
    "format",
    "concat",
]
SEARCHES = {"search_rare", "search_dense", "search_long"}


def command(args, cwd=None):
    result = subprocess.run(
        [str(arg) for arg in args],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.exit(
            f"command failed ({result.returncode}): {' '.join(map(str, args))}\n"
            f"{result.stdout}{result.stderr}"
        )
    return result.stdout


def build_all(compiler):
    BUILD.mkdir(parents=True, exist_ok=True)
    prismio = {}
    for bench in BENCHES:
        source = HERE / "prismio" / f"{bench}.psm"
        output = BUILD / f"{bench}_prismio"
        command([compiler, "build", source, "-o", output])
        prismio[bench] = [str(output)]

    c_binary = BUILD / "strings_c"
    command(["clang", "-O2", HERE / "c" / "strings.c", "-o", c_binary])

    rust_std = {}
    for bench in BENCHES:
        source = HERE / "rust" / "std" / f"{bench}.rs"
        output = BUILD / f"{bench}_rust_std"
        command(["rustc", "-O", source, "-o", output])
        rust_std[bench] = [str(output)]

    manifest = HERE / "rust" / "Cargo.toml"
    command(
        [
            "cargo",
            "build",
            "--release",
            "--bins",
            "--locked",
            "--manifest-path",
            manifest,
        ]
    )
    rust_release = HERE / "rust" / "target" / "release"

    variants = {}
    for bench in BENCHES:
        rows = [
            ("Prismio", prismio[bench]),
            ("C", [str(c_binary), bench]),
            ("Rust std", rust_std[bench]),
        ]
        if bench in SEARCHES:
            rows.append(("Rust memchr", [str(rust_release / bench)]))
        variants[bench] = rows
    return variants


def sample(args):
    output = command(args)
    fields = dict(
        line.split("=", 1) for line in output.splitlines() if "=" in line
    )
    try:
        return int(fields["checksum"]), int(fields["elapsed_ns"])
    except (KeyError, ValueError):
        sys.exit(f"invalid benchmark output from {' '.join(args)}:\n{output}")


def measure(variants, runs):
    results = {}
    for bench, rows in variants.items():
        checksums = {}
        elapsed = {label: [] for label, _ in rows}
        for _, args in rows:
            sample(args)
        for run in range(runs):
            order = rows if run % 2 == 0 else list(reversed(rows))
            for label, args in order:
                checksum, elapsed_ns = sample(args)
                checksums.setdefault(label, checksum)
                if checksums[label] != checksum:
                    sys.exit(f"{bench}/{label} produced a non-deterministic checksum")
                elapsed[label].append(elapsed_ns)
        if len(set(checksums.values())) != 1:
            sys.exit(f"{bench} checksums disagree: {checksums}")
        results[bench] = elapsed
    return results


def print_results(results, runs):
    print(f"best / median of {runs} interleaved runs, milliseconds")
    print()
    print(f"{'benchmark':<15} {'implementation':<12} {'best':>10} {'median':>10} {'vs best':>10}")
    print("-" * 62)
    for bench in BENCHES:
        rows = results[bench]
        fastest = min(min(samples) for samples in rows.values())
        for row, (label, samples) in enumerate(rows.items()):
            name = bench if row == 0 else ""
            best = min(samples) / 1_000_000
            median = statistics.median(samples) / 1_000_000
            relative = min(samples) / fastest
            print(
                f"{name:<15} {label:<12} {best:10.3f} {median:10.3f} {relative:9.2f}x"
            )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--runs", type=int, default=5)
    args = parser.parse_args()
    if args.runs < 1:
        parser.error("--runs must be positive")
    variants = build_all(Path(args.compiler).resolve())
    results = measure(variants, args.runs)
    print_results(results, args.runs)


if __name__ == "__main__":
    main()
