#!/usr/bin/env python3
"""A/B the compile time of two compilers on one source, with an A/A control.

    python3 tools/compile_ab.py --a build/genA --b build/genB
    python3 tools/compile_ab.py --a old --b new --source benchmarks/hosted/prismio/suite.psm --runs 21
    python3 tools/compile_ab.py --a old --b new --cwd ../head-worktree

Builds `--source` to LLVM IR with each compiler, alternating A, B, B, A, ... so
drift in the machine hits both, after two warm-ups of each. Prints the minimum
and the median of wall time and of CPU time (user + system), and the ratio B/A
for both. **The A/A line is the number to read the ratio against**: the same
binary copied beside itself, run the same way. A ratio inside that spread is not
a result.

Both compilers must be able to build the source, which means a compiler from
before a language change cannot be given a tree that uses it: run both on the
older tree (`--cwd` points at a checkout or worktree of it). When the two emit
identical IR for the source it says so, which is the stronger statement than any
timing.

Name the compilers anything but `prismio`: a file with that name is a launcher
and forwards to the project host, so the numbers would describe a different
binary than the one named. This tool refuses such a name. A compiler that is a
bare generation (`build/genN`) is fine here because it writes IR only; an
executable build needs a packaged toolchain.

What it does not do: binary size (compare `__text` of `clang -O2 -c` on the IR, or
use `prismio bench`, which reports the benchmark suite's `compile_ns`,
`compile_cpu_ns` and `binary_bytes`), or run-time performance.
"""
import argparse
import hashlib
import os
import shutil
import statistics
import subprocess
import sys
import tempfile
import time


def run(command, cwd):
    started = time.perf_counter()
    child = subprocess.Popen(command, cwd=cwd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    _, status, usage = os.wait4(child.pid, 0)
    wall = time.perf_counter() - started
    if os.waitstatus_to_exitcode(status) != 0:
        sys.exit("failed: {}".format(" ".join(command)))
    return wall, usage.ru_utime + usage.ru_stime


def digest(path):
    with open(path, "rb") as handle:
        return hashlib.md5(handle.read()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--a", required=True, help="the baseline compiler")
    parser.add_argument("--b", required=True, help="the compiler under test")
    parser.add_argument("--source", default="src/main.psm", help="what to build (default src/main.psm)")
    parser.add_argument("--cwd", default=".", help="directory to build in (a checkout or worktree)")
    parser.add_argument("--runs", type=int, default=15)
    args = parser.parse_args()

    a, b = os.path.abspath(args.a), os.path.abspath(args.b)
    for path in (a, b):
        if os.path.basename(path) in ("prismio", "prismio.exe"):
            sys.exit("{}: a compiler named `prismio` is a launcher; rename a copy".format(path))
        if not os.path.exists(path):
            sys.exit("no such compiler: " + path)

    work = tempfile.mkdtemp(prefix="compile-ab-")
    try:
        a_copy = os.path.join(work, "a-copy")
        shutil.copy2(a, a_copy)
        arms = {"A": a, "B": b, "A/A": a_copy}
        out = {name: os.path.join(work, name.replace("/", "") + ".ll") for name in arms}

        def command(name):
            return [arms[name], "build", args.source, "-o", out[name]]

        samples = {name: ([], []) for name in arms}
        for pair in (("A", "B"), ("A", "A/A")):
            for _ in range(2):
                for name in pair:
                    run(command(name), args.cwd)
            for i in range(args.runs):
                order = pair if i % 2 == 0 else pair[::-1]
                for name in order:
                    wall, cpu = run(command(name), args.cwd)
                    # The A arm is measured in both pairs; keep its samples apart.
                    key = name if name != "A" else "A" if pair[1] == "B" else "A-control"
                    samples.setdefault(key, ([], []))
                    samples[key][0].append(wall)
                    samples[key][1].append(cpu)

        def stat(values):
            return min(values), statistics.median(values)

        print("source {} in {}, {} runs each".format(args.source, os.path.abspath(args.cwd), args.runs))
        for label, x, y in (("B vs A", "A", "B"), ("A/A control", "A-control", "A/A")):
            wx, cx = samples[x]
            wy, cy = samples[y]
            for kind, vx, vy in (("wall", wx, wy), ("cpu ", cx, cy)):
                (xmin, xmed), (ymin, ymed) = stat(vx), stat(vy)
                print("  {:12} {}  X min {:.3f} med {:.3f} | Y min {:.3f} med {:.3f} | Y/X min {:.3f} med {:.3f}".format(
                    label if kind == "wall" else "", kind, xmin, xmed, ymin, ymed, ymin / xmin, ymed / xmed))
        same = digest(out["A"]) == digest(out["B"])
        print("  IR from A and B: {}".format("byte-identical" if same else "different ({} vs {} bytes)".format(
            os.path.getsize(out["A"]), os.path.getsize(out["B"]))))
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
