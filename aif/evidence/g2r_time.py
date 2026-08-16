#!/usr/bin/env python3
"""Interleaved A/B timing for g2_region: pre-placement vs post-placement.

Interleaved, not back to back (RESULTS-arena §6): thermal drift and any other
slow-moving disturbance hits both arms equally when they alternate, and hits
only the second arm when they do not.
"""
import statistics
import subprocess
import sys
import time


def run_once(exe):
    t0 = time.perf_counter()
    subprocess.run([exe], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    return (time.perf_counter() - t0) * 1000.0


def main():
    pre, post, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
    # one warm pair, discarded: first run pays page-cache and dyld cost
    run_once(pre)
    run_once(post)
    a, b = [], []
    for _ in range(n):
        a.append(run_once(pre))
        b.append(run_once(post))
    ma, mb = statistics.median(a), statistics.median(b)
    print(f"pairs         {n} (interleaved, 1 warm pair discarded)")
    print(f"pre  (t3)     median {ma:8.1f} ms   min {min(a):8.1f}   max {max(a):8.1f}")
    print(f"post (mg3)    median {mb:8.1f} ms   min {min(b):8.1f}   max {max(b):8.1f}")
    print(f"ratio         {mb / ma:.3f}x   ({ma / mb:.2f}x faster)")


if __name__ == "__main__":
    main()
