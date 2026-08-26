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

With `--baseline`, the two compilers are measured *inside the same run loop* with
the order alternating per run. Compile-time differences worth chasing are ~10%,
which is the size a host drifts over the tens of seconds a sequential A-then-B
pass takes; interleaving is the same discipline milestone_bench applies to run
time, for the same reason.
"""

import argparse, contextlib, json, os, shutil, subprocess, sys, tempfile, time

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

def copy_project(source, wd):
    """Copy the program *and the modules beside it*.

    A corpus program may import a sibling (`g6_game` imports `g6_engine`), so
    copying only the named file produces a project that cannot resolve its own
    imports -- which failed as a build error and silently removed the larger of
    the two programs the cold-compile regression was recorded against."""
    src_dir = os.path.dirname(os.path.abspath(source))
    for name in os.listdir(src_dir):
        if name.endswith(".psm"):
            shutil.copy2(os.path.join(src_dir, name), os.path.join(wd, name))
    return os.path.join(wd, os.path.basename(source))

def scenario(compilers, source, runs, mode):
    """Time one scenario for every compiler, interleaved. Returns label -> best.

    Each arm gets its own workspace and its own object cache: the cache keys on
    runtime content, and `cold` empties the directory outright."""
    base_env = {"PRISMIO_OBJ_CACHE": "0"} if mode == "no-cache" else {}
    best = {label: None for label, _, _ in compilers}
    with contextlib.ExitStack() as stack:
        arms = []
        for label, exe, extra in compilers:
            wd = stack.enter_context(tempfile.TemporaryDirectory(prefix="prismio-bench-"))
            arms.append((label, exe, copy_project(source, wd),
                         os.path.join(wd, "out.exe"), os.path.join(wd, "cache"),
                         dict(base_env, **extra)))

        for i in range(runs):
            for label, exe, work, out, cache, env in (arms if i % 2 == 0 else arms[::-1]):
                if mode == "cold":
                    shutil.rmtree(cache, ignore_errors=True)
                elif mode in ("incremental", "no-cache"):
                    if i == 0:
                        build(exe, work, out, cache, env)   # warm, untimed
                    touch(work, i)
                elif mode == "no-change" and i == 0:
                    build(exe, work, out, cache, env)       # warm, untimed
                dt = build(exe, work, out, cache, env)
                if best[label] is None or dt < best[label]:
                    best[label] = dt
    return best

MODES = ["cold", "incremental", "no-change", "no-cache"]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", required=True)
    ap.add_argument("--baseline", help="a second compiler to compare against")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--label", default="", help="recorded in the JSON")
    ap.add_argument("--json", help="write the raw table here")
    ap.add_argument("--baseline-env", action="append", default=[], metavar="K=V",
                    help="extra environment for the baseline arm only. Passing the same "
                         "binary to --compiler and --baseline then measures a feature "
                         "toggle interleaved against itself, with no codegen difference "
                         "between the arms to explain a result away.")
    ap.add_argument("programs", nargs="*", help="defaults to a small, a medium and a large one")
    args = ap.parse_args()

    programs = args.programs or [
        "tests/test_09_strings.psm",
        "aif/corpus/g1_particles.psm",
    ]
    for p in programs:
        if not os.path.exists(p):
            raise SystemExit("no such program: %s" % p)

    compilers = [("new", os.path.abspath(args.compiler), {})]
    if args.baseline:
        compilers.append(("base", os.path.abspath(args.baseline),
                          dict(kv.split("=", 1) for kv in args.baseline_env)))

    record = {"label": args.label, "runs": args.runs,
              "compiler": args.compiler, "baseline": args.baseline,
              "baseline_env": args.baseline_env,
              "modes": MODES, "programs": {}}

    width = max(len(os.path.basename(p)) for p in programs) + 2
    print("%-*s %-6s %s" % (width, "program", "which", "  ".join("%11s" % m for m in MODES)))
    for p in programs:
        rows = {label: [] for label, _, _ in compilers}
        for m in MODES:
            got = scenario(compilers, p, args.runs, m)
            for label in rows:
                rows[label].append(got[label])
        for label, _, _ in compilers:
            print("%-*s %-6s %s" % (width, os.path.basename(p), label,
                                    "  ".join("%11.3f" % v for v in rows[label])))
        entry = {label: dict(zip(MODES, rows[label])) for label in rows}
        if len(compilers) > 1:
            ratio = [n / b for n, b in zip(rows["new"], rows["base"])]
            print("%-*s %-6s %s" % (width, "", "new/base",
                                    "  ".join("%10.3fx" % v for v in ratio)))
            entry["ratio"] = dict(zip(MODES, ratio))
        record["programs"][os.path.basename(p)] = entry

        # The claim the cache exists to support, stated as a ratio rather than
        # left to the reader: an edit-rebuild against the pre-cache behaviour.
        inc, nocache = rows["new"][MODES.index("incremental")], rows["new"][MODES.index("no-cache")]
        print("%-*s %-6s incremental is %.2fx the uncached rebuild" % (width, "", "", inc / nocache))

    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(record, f, indent=2)
        print("wrote %s" % args.json)
    return 0

if __name__ == "__main__":
    sys.exit(main())
