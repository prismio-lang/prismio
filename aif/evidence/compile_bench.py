#!/usr/bin/env python3
"""Cold, incremental and no-change build times, for one or two compilers.

    python3 aif/evidence/compile_bench.py --compiler build/<gen> [--baseline build/<old>]

Four scenarios per program, because they are four different questions and the
answers differ by an order of magnitude:

  cold        empty object cache, nothing reusable.  What CI pays.
  incremental one line edited, warm cache.  The edit-rebuild loop, and the only
              column that describes what a person waiting at a keyboard feels.
  no-change   rebuild with nothing edited.  The ceiling on what any cache can buy.
  no-cache    PRISMIO_OBJ_CACHE=0.  The behaviour before the cache existed, so the
              improvement is measured against a real baseline rather than a memory.

Minimum of N runs, not mean: the noise on a shared host is one-sided. Every
scenario gets a fresh copy of the source, so an edit from one never leaks into
another, and the object cache lives in a temporary directory that is removed
afterwards -- a benchmark that warms the host's real cache would report its own
previous run.
"""

import argparse, os, shutil, subprocess, sys, tempfile, time

def build(compiler, source, out, cache, env_extra=None):
    env = dict(os.environ)
    env["PRISMIO_OBJ_CACHE_DIR"] = cache
    env.update(env_extra or {})
    t0 = time.perf_counter()
    p = subprocess.run([compiler, "build", source, "-o", out],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    dt = time.perf_counter() - t0
    if p.returncode != 0:
        raise SystemExit("FAILED: %s build %s" % (compiler, source))
    return dt

def touch(path, n):
    """A one-line edit that is a real edit: it changes the text, the AST and the
    emitted IR, so nothing downstream can shortcut it."""
    text = open(path, encoding="utf-8").read()
    marker = "\n// benchmark edit "
    if marker in text:
        text = text[:text.index(marker)]
    open(path, "w", encoding="utf-8").write(text + "%s%d\n" % (marker, n))

def scenario(compiler, source, runs, mode):
    best = None
    with tempfile.TemporaryDirectory(prefix="prismio-bench-") as wd:
        work = os.path.join(wd, os.path.basename(source))
        shutil.copy2(source, work)
        out = os.path.join(wd, "out.exe")
        cache = os.path.join(wd, "cache")
        env = {"PRISMIO_OBJ_CACHE": "0"} if mode == "no-cache" else None

        for i in range(runs):
            if mode == "cold":
                shutil.rmtree(cache, ignore_errors=True)
            elif mode in ("incremental", "no-cache"):
                if i == 0:
                    build(compiler, work, out, cache, env)  # warm, untimed
                touch(work, i)
            elif mode == "no-change" and i == 0:
                build(compiler, work, out, cache, env)      # warm, untimed
            dt = build(compiler, work, out, cache, env)
            best = dt if best is None else min(best, dt)
    return best

MODES = ["cold", "incremental", "no-change", "no-cache"]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", required=True)
    ap.add_argument("--baseline", help="a second compiler to compare against")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("programs", nargs="*", help="defaults to a small, a medium and a large one")
    args = ap.parse_args()

    programs = args.programs or [
        "tests/test_09_strings.psm",
        "aif/corpus/g1_particles.psm",
    ]
    for p in programs:
        if not os.path.exists(p):
            raise SystemExit("no such program: %s" % p)

    compilers = [("new", os.path.abspath(args.compiler))]
    if args.baseline:
        compilers.append(("base", os.path.abspath(args.baseline)))

    width = max(len(os.path.basename(p)) for p in programs) + 2
    print("%-*s %-6s %s" % (width, "program", "which", "  ".join("%11s" % m for m in MODES)))
    for p in programs:
        for label, exe in compilers:
            row = [scenario(exe, p, args.runs, m) for m in MODES]
            print("%-*s %-6s %s" % (width, os.path.basename(p), label,
                                    "  ".join("%11.3f" % v for v in row)))
        # The claim the cache exists to support, stated as a ratio rather than
        # left to the reader: an edit-rebuild against the pre-cache behaviour.
        new = scenario(compilers[0][1], p, args.runs, "incremental")
        old = scenario(compilers[0][1], p, args.runs, "no-cache")
        print("%-*s %-6s incremental is %.2fx the uncached rebuild" % (width, "", "", new / old))
    return 0

if __name__ == "__main__":
    sys.exit(main())
