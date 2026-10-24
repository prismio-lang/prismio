#!/usr/bin/env python3
"""A/B driver: build the hosted suite once per config, run benchmarks interleaved.

    ALLOC_SCRATCH=/tmp/x python3 benchmarks/allocator_proto/ab.py --configs base,off,cpp --bench graph_churn_alloc --build

`cpp` and `rust` configs run suite-cpp / suite-rust copied into the scratch directory by hand
(benchmarks/build/hosted/*-suite). Never writes benchmarks/results.


Each run goes through /usr/bin/time -l so peak RSS and CPU time are per child.
"""
import os, sys, subprocess, json, statistics, time, argparse, re
from pathlib import Path
HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
S = Path(os.environ.get("ALLOC_SCRATCH", HERE / "scratch")).resolve()   # holds tc0/tc5 (mk_toolchains.py) and the suite-* executables
S.mkdir(parents=True, exist_ok=True)
SUITE = REPO / "benchmarks/hosted/prismio/suite.psm"
CONFIGS = {
  "base":  ("tc0", {}),                              # the slab, as it ships
  "off":   ("tc0", {"PRISMIO_SLAB": "0"}),           # the same binary, every block from libc
  "noattr":("tc0", {"PRISMIO_PROTO_NOATTR": "1"}),   # codegen without the call-site attributes
  "s5":    ("tc5", {}),                              # SLAB_STAGGER=0
  "cpp":   (None, {}),
  "rust":  (None, {}),
}
# Any other name runs a `suite-<name>` already in the scratch directory, built by hand --
# a toolchain from before a change, say -- with no environment of its own.
ap = argparse.ArgumentParser()
ap.add_argument("--configs", default="base,off")
ap.add_argument("--bench", required=True)
ap.add_argument("--runs", type=int, default=9)
ap.add_argument("--build", action="store_true")
ap.add_argument("--out")
a = ap.parse_args()
cfgs = a.configs.split(",")
benches = a.bench.split(",")
env0 = os.environ.copy(); env0["PRISMIO_INTERNAL_HOSTED"] = "1"
for c in cfgs:
    tc, extra = CONFIGS.get(c, (None, {}))
    exe = S / f"suite-{c}"
    if tc is None: continue
    if a.build or not exe.exists():
        env = dict(env0, **extra)
        t = time.time()
        r = subprocess.run([str(S/tc/"bin/pgen"), "build", str(SUITE), "-o", str(exe)], env=env, capture_output=True, text=True, cwd=S)
        if r.returncode: print("BUILD FAIL", c, r.stdout[-800:], r.stderr[-800:]); sys.exit(1)
        print(f"built {c} in {time.time()-t:.1f}s", file=sys.stderr)
res = {}
for b in benches:
    samples = {c: [] for c in cfgs}
    cpus = {c: [] for c in cfgs}; rss = {c: [] for c in cfgs}; chk = {}
    fails = {c: 0 for c in cfgs}
    for i in range(a.runs):
        order = cfgs if i % 2 == 0 else cfgs[::-1]
        for c in order:
            exe = S / f"suite-{c}"
            env = dict(env0, **CONFIGS.get(c, (None, {}))[1])
            r = subprocess.run(["/usr/bin/time", "-l", str(exe), b, "/dev/null", "/dev/null"], env=env, capture_output=True, text=True)
            if r.returncode:
                fails[c] += 1
                if fails[c] == 1: print("RUN FAIL", c, b, r.returncode, r.stdout[-200:], r.stderr[-300:])
                continue
            out = dict(l.split(": ") for l in r.stdout.strip().splitlines() if ": " in l)
            samples[c].append(int(out["elapsed_ns"]) / 1e6)
            chk[c] = out["result"]
            m = re.search(r"([\d.]+)\s+user\s+([\d.]+)\s+sys", r.stderr) or re.search(r"([\d.]+)\s+real\s+([\d.]+)\s+user\s+([\d.]+)\s+sys", r.stderr)
            u = re.search(r"([\d.]+) user", r.stderr); sy = re.search(r"([\d.]+) sys", r.stderr)
            cpus[c].append((float(u.group(1)) + float(sy.group(1))) * 1000 if u and sy else float('nan'))
            rr = re.search(r"(\d+)\s+maximum resident set size", r.stderr)
            rss[c].append(int(rr.group(1)) / 1e6 if rr else float('nan'))
    ref = [c for c in cfgs if samples[c]]
    if not ref: print(b, "ALL FAILED"); continue
    base = statistics.median(samples[ref[0]])
    print(f"{b}")
    res[b] = {}
    for c in cfgs:
        if not samples[c]:
            print(f"  {c:5s} FAILED"); continue
        m = statistics.median(samples[c]); mn = min(samples[c])
        ratio = m/base if base else float('nan')
        print(f"  {c:5s} med {m:8.2f} ms  min {mn:8.2f}  cpu {statistics.median(cpus[c]):8.1f} ms  rss {statistics.median(rss[c]):6.1f} MB  ratio {ratio:5.3f}  chk {chk.get(c)}")
        res[b][c] = {"median_ms": m, "min_ms": mn, "samples": samples[c], "cpu_ms": statistics.median(cpus[c]), "rss_mb": statistics.median(rss[c]), "checksum": chk.get(c)}
if a.out: json.dump(res, open(a.out, "w"), indent=1)
