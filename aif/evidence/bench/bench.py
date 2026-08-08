"""Run the AIF benchmark set and report to BENCHMARKS 3.2's protocol.

    python aif/evidence/bench/bench.py [--runs 40] [--only g2|g6]

Baselines, in the order 3.2 gives them:

    1. Prismio --debug   the internal control, and the required one. Same
                         compiler, same backend, same LLVM, same source, budget
                         0 rounds -- so every site sits at its top tier and the
                         tier assignment is the only variable (BENCHMARKS 1).
    2. C -O2 idiomatic   the normalisation point. Everything is relative to it.
    3. C -O2 arena       the ceiling AIF approaches from below: the same program
                         with the transformation T1 is supposed to make without
                         being asked.
    and Prismio at full inference, the thing under test.

Median and p99 over N runs rather than mean, per 3.2 -- a process-level timing
distribution has a tail and the mean hides it.

Peak working set is reported beside the time because the control is not a
like-for-like on memory: `--debug` never frees, so its wall time is flattered by
work it does not do. A time column alone would read as "inference costs 6%"
rather than "inference costs 6% and returns 112x the footprint".
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import os
import statistics
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))

SUITES = {
    "g2": ("G2 frame loop -- 1000 renderables x 20000 frames", [
        ("C -O2 idiomatic",     "g2_c.exe"),
        ("C -O2 arena",         "g2_c_arena.exe"),
        ("Prismio (inference)", "g2_prismio.exe"),
        ("Prismio --debug",     "g2_prismio_debug.exe"),
    ]),
    "g6": ("G6 engine+gameplay -- 800 actors x 100 ticks x 300 runs", [
        ("C -O2 idiomatic",     "g6_c.exe"),
        ("C -O2 arena",         "g6_c_arena.exe"),
        ("Prismio (inference)", "g6_prismio.exe"),
        ("Prismio --debug",     "g6_prismio_debug.exe"),
    ]),
}


class PROCESS_MEMORY_COUNTERS(ctypes.Structure):
    _fields_ = [("cb", wt.DWORD), ("PageFaultCount", wt.DWORD),
                ("PeakWorkingSetSize", ctypes.c_size_t),
                ("WorkingSetSize", ctypes.c_size_t),
                ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                ("PagefileUsage", ctypes.c_size_t),
                ("PeakPagefileUsage", ctypes.c_size_t)]


def run_once(path):
    """One run: wall milliseconds, and peak working set in MB.

    The counters stay readable on the handle after the child exits, which is why
    the peak is taken here rather than by sampling -- a poll loop misses a spike
    between samples, and the whole point of the control is a spike.
    """
    t = time.perf_counter()
    p = subprocess.Popen([path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    p.wait()
    ms = (time.perf_counter() - t) * 1000.0
    if p.returncode != 0:
        sys.exit(f"{path} exited {p.returncode}")
    peak = 0
    try:
        c = PROCESS_MEMORY_COUNTERS()
        c.cb = ctypes.sizeof(c)
        if ctypes.windll.psapi.GetProcessMemoryInfo(int(p._handle), ctypes.byref(c), c.cb):
            peak = c.PeakWorkingSetSize
    except Exception:
        pass
    return ms, peak / (1024.0 * 1024.0)


def pct(xs, p):
    xs = sorted(xs)
    k = min(len(xs) - 1, int(round((p / 100.0) * (len(xs) - 1))))
    return xs[k]


def suite(name, runs):
    title, binaries = SUITES[name]
    missing = [b for _, b in binaries if not os.path.exists(os.path.join(HERE, b))]
    if missing:
        print(f"\n{title}\n  skipped, not built: {', '.join(missing)}")
        return
    print(f"\n{title} -- {runs} runs each\n")
    rows = []
    for label, exe in binaries:
        samples = [run_once(os.path.join(HERE, exe)) for _ in range(runs)]
        ts = [s[0] for s in samples]
        rows.append((label, statistics.median(ts), pct(ts, 99), min(ts),
                     max(s[1] for s in samples)))
    base = [m for lbl, m, _, _, _ in rows if lbl == "C -O2 idiomatic"][0]
    print(f"{'baseline':<22} {'median':>10} {'p99':>10} {'min':>10} {'rel':>7} {'peak RSS':>11}")
    print("-" * 76)
    for label, med, p99, mn, rss in rows:
        print(f"{label:<22} {med:9.1f}ms {p99:9.1f}ms {mn:9.1f}ms {med/base:6.2f}x {rss:8.1f} MB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=40)
    ap.add_argument("--only", choices=sorted(SUITES))
    args = ap.parse_args()

    noop = os.path.join(HERE, "noop.exe")
    if os.path.exists(noop):
        s = statistics.median([run_once(noop)[0] for _ in range(args.runs)])
        print(f"process startup, measured separately: {s:.1f} ms median")

    for name in ([args.only] if args.only else sorted(SUITES)):
        suite(name, args.runs)


if __name__ == "__main__":
    main()
