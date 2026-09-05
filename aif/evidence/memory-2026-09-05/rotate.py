#!/usr/bin/env python3
"""Time prebuilt investigation controls in deterministic rotating order."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("snapshot", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--runs", type=int, default=31)
args = parser.parse_args()
root = args.snapshot.resolve()
paths = {"A": root / "benchmarks/build/prismio-suite",
         "A_repeat": root / "benchmarks/build/prismio-suite",
         "strict_bound": root / "strict-bound-suite",
         "cpp": root / "benchmarks/build/cpp-suite",
         "rust": root / "benchmarks/build/rust-suite"}
fixture = root / "input.txt"
names = list(paths)
rows = {name: [] for name in names}
expected = None
order = []
for run in range(-2, args.runs):
    rotation = names[run % len(names):] + names[:run % len(names)]
    if run % 2:
        rotation.reverse()
    if run >= 0:
        order.append(rotation)
    for name in rotation:
        started = time.perf_counter_ns()
        p = subprocess.run([str(paths[name]), "large_buffer_copy", str(fixture),
                            str(root / "rotate-output.txt")], cwd=root,
                           capture_output=True, text=True, timeout=30)
        wall = time.perf_counter_ns() - started
        if p.returncode:
            raise RuntimeError((name, p.returncode, p.stdout, p.stderr))
        fields = {}
        for line in p.stdout.splitlines():
            if ": " in line:
                key, value = line.split(": ", 1)
                if key in ("result", "elapsed_ns"):
                    fields[key] = int(value)
        if expected is None:
            expected = fields["result"]
        if fields["result"] != expected:
            raise RuntimeError((name, fields, expected))
        if run >= 0:
            rows[name].append({**fields, "wall_ns": wall})
report = {"workload": "large_buffer_copy", "warmups_per_binary": 2,
          "runs": args.runs, "order": order, "samples": rows,
          "binary_sha256": {n: hashlib.sha256(p.read_bytes()).hexdigest()
                            for n, p in paths.items()},
          "summary": {n: {"median_ns": statistics.median(x["elapsed_ns"] for x in rs),
                          "min_ns": min(x["elapsed_ns"] for x in rs),
                          "max_ns": max(x["elapsed_ns"] for x in rs)}
                      for n, rs in rows.items()}}
args.output.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report["summary"], indent=2))
