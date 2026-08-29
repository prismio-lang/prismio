#!/usr/bin/env python3
"""G7 -- the string/parse axis, which bench.py does not have.

    python3 aif/evidence/xlang/g7bench.py --compiler build/gen4 --runs 10

g1-g6 are object-graph and numeric workloads: every cross-language number this
project has recorded comes from a program that barely touches a string.
BENCHMARKS 3.2 lists this one as B2 and it was never built.

Five programs, one workload, identical checksums. The point is the
decomposition, not any single row -- each pair isolates one cost:

    Rust idiomatic     &str slice          the floor: no copy, no length scan
    Rust owned         copy per token      prices the copy, in ONE language
    Prismio str_slice  length carried      what this compiler does today
    Prismio substring  length rescanned    what it did before; prices the strlen
    Prismio scan only  no slice at all     the backend, with slicing removed

Holding the representation fixed inside one language is the method
g1_boxed.rs / g2_boxed.rs / g4_boxed.rs established: it prices a representation
choice without the backend gap mixed into it.
"""
import argparse
import json
import pathlib
import statistics
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent.parent

PROGRAMS = [
    ("Rust idiomatic    &str slice, no copy", "rust", "g7_idiomatic.rs"),
    ("Rust owned        copy per token", "rust", "g7_owned.rs"),
    # One Prismio arm, not two. The second was g7_substring.psm, and it compiled
    # to byte-identical IR once both were on the native `strSubstring` -- see the
    # header of g7.psm for why the distinction it priced stopped existing.
    ("Prismio           strSubstring", "prismio", "g7.psm"),
]


def build(compiler, out_dir, kind, name):
    src = HERE / kind / name
    exe = out_dir / (src.stem + ("_rs" if kind == "rust" else "_psm"))
    if kind == "rust":
        cmd = ["rustc", "-C", "opt-level=3", "--edition", "2021",
               "-o", str(exe), str(src)]
    else:
        cmd = [str(compiler), "build", str(src), "-o", str(exe)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"building {src.name} failed:\n{r.stdout}\n{r.stderr}")
    return exe


def measure(exe, runs):
    samples, checks = [], None
    for _ in range(runs):
        out = subprocess.run([str(exe)], capture_output=True, text=True).stdout
        c = {}
        for line in out.splitlines():
            if line.startswith("frame_ns "):
                samples.append(int(line.split()[1]))
            elif line.startswith("checksum "):
                p = line.split()
                c[p[1]] = int(p[2])
        if checks is None:
            checks = c
        elif checks != c:
            sys.exit(f"{exe.name}: checksums varied between runs -- "
                     "the workload is not deterministic")
    return samples, checks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", default=str(REPO / "build" / "gen4"))
    ap.add_argument("--runs", type=int, default=10)
    ap.add_argument("--json", help="write the raw table here")
    args = ap.parse_args()

    out_dir = HERE / "build"
    out_dir.mkdir(exist_ok=True)

    rows, agreed = [], None
    for label, kind, name in PROGRAMS:
        exe = build(args.compiler, out_dir, kind, name)
        samples, checks = measure(exe, args.runs)
        # Checksums are the correctness gate: a port that tokenized differently
        # would be timing a different program, and the numbers would be
        # meaningless rather than merely wrong.
        if agreed is None:
            agreed = checks
        elif checks != agreed:
            sys.exit(f"CHECKSUM MISMATCH on {label}: {checks} != {agreed}")
        rows.append((label,
                     statistics.median(samples) / 1e6,
                     sorted(samples)[int(len(samples) * 0.99)] / 1e6))

    base = rows[0][1]
    print(f"\ng7 tokenizer -- {agreed['bytes']} bytes, "
          f"{args.runs} runs x 200 iterations, samples pooled\n")
    print(f"{'':<40}{'median':>10}{'p99':>10}{'rel':>10}")
    for label, med, p99 in rows:
        print(f"{label:<40}{med:>9.3f}m{p99:>9.3f}m{med / base:>9.2f}x")
    print(f"\nchecksums agree across all ports: {agreed}")

    if args.json:
        pathlib.Path(args.json).write_text(json.dumps(
            {"checksums": agreed,
             "rows": [{"label": r[0], "median_ms": r[1], "p99_ms": r[2]}
                      for r in rows]}, indent=2))


if __name__ == "__main__":
    main()
