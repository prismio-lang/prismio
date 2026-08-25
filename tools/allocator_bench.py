#!/usr/bin/env python3
"""M5.1 allocator experiment: system malloc vs an interposed allocator.

The same Prismio executable is run in both arms. Only the child environment
differs, so this measures allocator choice without admitting compiler/codegen
drift. Runs are interleaved in ABBA order for the same reason as
milestone_bench.py: each arm occupies the first and second process slot equally.
"""

import argparse
import json
import os
import statistics
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
XLANG = os.path.join(REPO, "aif", "evidence", "xlang")
sys.path.insert(0, XLANG)

import bench  # noqa: E402


DEFAULT_PROGRAMS = ["g1", "g3", "g4", "g5"]


def aggregate(samples, key):
    values = [sample[key] for sample in samples]
    return [statistics.median(values), min(values), max(values)]


def build_prismio(compiler, program):
    source = os.path.join(XLANG, "prismio", f"{program}.psm")
    output = os.path.join(bench.OUT, f"allocator_{program}")
    result = bench.sh([compiler, "build", source, "-o", output], cwd=XLANG)
    if result.returncode != 0:
        sys.exit(f"build failed for {program}:\n{result.stdout}\n{result.stderr}")
    return output


def ensure_rust_baselines(compiler, programs):
    wanted = {"rust_idiomatic", "rust_tuned"}
    outputs = {}
    for program, key, _, language, output, commands in bench.targets(compiler):
        if program not in programs or language != "rust" or key not in wanted:
            continue
        if not os.path.exists(output):
            for command in commands:
                result = bench.sh(command, cwd=XLANG)
                if result.returncode != 0:
                    sys.exit(f"Rust build failed for {program} {key}:\n{result.stderr}")
        outputs[(program, key)] = output
    return outputs


def one(executable, stdout_path, preload, expected_checksums):
    wall_ms, rss_bytes = bench.run_once(executable, stdout_path, preload=preload)
    checksums, frames = bench.parse_output(stdout_path)
    if checksums != expected_checksums:
        sys.exit(f"checksum drift under {preload or 'system allocator'}: "
                 f"{checksums} != {expected_checksums}")
    ordered = sorted(frames)
    return {
        "p50_us": bench.pct(ordered, 50) / 1000.0,
        "p99_us": bench.pct(ordered, 99) / 1000.0,
        "p999_us": bench.pct(ordered, 99.9) / 1000.0,
        "loop_ms": sum(frames) / 1e6,
        "wall_ms": wall_ms,
        "rss_mb": rss_bytes / (1024.0 * 1024.0),
        "frames": len(frames),
    }


def measure_abba(executable, allocator, runs, stdout_path, checksums):
    # Discard one warm run of each arm before assigning positions.
    one(executable, stdout_path, None, checksums)
    one(executable, stdout_path, allocator, checksums)

    system, alternate = [], []
    for _ in range((runs + 1) // 2):
        system.append(one(executable, stdout_path, None, checksums))
        alternate.append(one(executable, stdout_path, allocator, checksums))
        alternate.append(one(executable, stdout_path, allocator, checksums))
        system.append(one(executable, stdout_path, None, checksums))
    return system[:runs], alternate[:runs]


def summarize(samples):
    return {key: aggregate(samples, key)
            for key in ("p50_us", "p99_us", "p999_us", "loop_ms",
                        "wall_ms", "rss_mb")}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--allocator-lib", required=True,
                        help="shared allocator library to interpose in the child")
    parser.add_argument("--allocator-name", default="mimalloc")
    parser.add_argument("--allocator-version", default="unknown")
    parser.add_argument("--runs", type=int, default=25)
    parser.add_argument("--only", choices=bench.PROGRAMS, action="append")
    parser.add_argument("--skip-rust", action="store_true")
    parser.add_argument("--json", default=os.path.join(
        REPO, "aif", "evidence", "results-m5-allocator.json"))
    args = parser.parse_args()

    compiler = os.path.abspath(args.compiler)
    allocator = os.path.abspath(args.allocator_lib)
    if not os.path.isfile(compiler):
        sys.exit(f"compiler does not exist: {compiler}")
    if not os.path.isfile(allocator):
        sys.exit(f"allocator library does not exist: {allocator}")
    if os.environ.get(bench.PRELOAD_VAR):
        sys.exit(f"clear {bench.PRELOAD_VAR} before running; the system arm must be clean")

    programs = args.only or DEFAULT_PROGRAMS
    os.makedirs(bench.OUT, exist_ok=True)
    stdout_path = os.path.join(bench.OUT, "_allocator_stdout.txt")
    rust = {} if args.skip_rust else ensure_rust_baselines(compiler, programs)
    results = {}

    for program in programs:
        print(f"\n{'=' * 104}\n{program}\n{'=' * 104}", flush=True)
        executable = build_prismio(compiler, program)
        bench.run_once(executable, stdout_path)
        checksums, _ = bench.parse_output(stdout_path)
        system_runs, allocator_runs = measure_abba(
            executable, allocator, args.runs, stdout_path, checksums)
        system = summarize(system_runs)
        alternate = summarize(allocator_runs)

        rust_rows = {}
        for key in ("rust_idiomatic", "rust_tuned"):
            rust_exe = rust.get((program, key))
            if rust_exe:
                samples, rust_checksums = bench.measure(rust_exe, args.runs, stdout_path)
                if rust_checksums != checksums:
                    sys.exit(f"{program} {key} checksum drift: "
                             f"{rust_checksums} != {checksums}")
                rust_rows[key] = summarize(samples)

        ratio = alternate["loop_ms"][0] / system["loop_ms"][0]
        rss_ratio = alternate["rss_mb"][0] / system["rss_mb"][0]
        print(f"{'arm':<22}{'p50 us':>10}{'p99 us':>10}{'loop ms':>11}"
              f"{'wall ms':>11}{'RSS MB':>10}{'loop ratio':>13}")
        print(f"{'system malloc':<22}{system['p50_us'][0]:10.3f}"
              f"{system['p99_us'][0]:10.3f}{system['loop_ms'][0]:11.3f}"
              f"{system['wall_ms'][0]:11.3f}{system['rss_mb'][0]:10.3f}{'1.000x':>13}")
        print(f"{args.allocator_name:<22}{alternate['p50_us'][0]:10.3f}"
              f"{alternate['p99_us'][0]:10.3f}{alternate['loop_ms'][0]:11.3f}"
              f"{alternate['wall_ms'][0]:11.3f}{alternate['rss_mb'][0]:10.3f}"
              f"{ratio:12.3f}x")
        for key, label in (("rust_idiomatic", "Rust idiomatic"),
                           ("rust_tuned", "Rust hand-tuned")):
            row = rust_rows.get(key)
            if row:
                rust_ratio = alternate["loop_ms"][0] / row["loop_ms"][0]
                print(f"{label:<22}{row['p50_us'][0]:10.3f}{row['p99_us'][0]:10.3f}"
                      f"{row['loop_ms'][0]:11.3f}{row['wall_ms'][0]:11.3f}"
                      f"{row['rss_mb'][0]:10.3f}{rust_ratio:12.3f}x")
        print(f"effect: loop {ratio:.3f}x, RSS {rss_ratio:.3f}x; "
              f"system spread {system['loop_ms'][1]:.3f}–{system['loop_ms'][2]:.3f} ms, "
              f"{args.allocator_name} spread "
              f"{alternate['loop_ms'][1]:.3f}–{alternate['loop_ms'][2]:.3f} ms")

        results[program] = {
            "checksums": checksums,
            "frames": system_runs[0]["frames"],
            "system": system,
            "allocator": alternate,
            "loop_ratio": ratio,
            "rss_ratio": rss_ratio,
            "rust": rust_rows,
            "executable_bytes": os.path.getsize(executable),
        }

    ratios = [row["loop_ratio"] for row in results.values()]
    print(f"\nmedian allocator/system loop ratio: {statistics.median(ratios):.3f}x "
          f"(range {min(ratios):.3f}–{max(ratios):.3f}x)")
    with open(args.json, "w", encoding="utf-8") as output:
        json.dump({
            "meta": {
                "compiler": compiler,
                "allocator": args.allocator_name,
                "allocator_version": args.allocator_version,
                "allocator_library": allocator,
                "runs": args.runs,
                "platform": sys.platform,
                "when": time.strftime("%Y-%m-%d %H:%M:%S"),
            },
            "results": results,
        }, output, indent=2)
    print(f"wrote {args.json}")


if __name__ == "__main__":
    main()
