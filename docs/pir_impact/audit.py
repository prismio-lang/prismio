#!/usr/bin/env python3
"""PIR impact audit: the --verify leak ledger over tests/ and the PIR probes.

Builds every program with `--verify`, runs it, and records what its ledger says.
The numbers feed docs/PIR_PLAN.md §20.4–20.5. Run from the compiler checkout:

    python3 docs/pir_impact/audit.py --compiler .prismio/build/release/prismio --out <file>.json

Builds happen in a scratch directory outside the checkout, so std comes from the
compiler's stdlib/ and not from source (prismio-out-of-tree-build-cwd).
"""
import argparse, concurrent.futures as cf, json, os, re, subprocess, sys, tempfile, pathlib

LEDGER = re.compile(r"aif-verify: (\d+) allocated, (\d+) released, (\d+) leaked, (\d+) violation")


def one(compiler, src, scratch):
    name = src.stem
    work = pathlib.Path(tempfile.mkdtemp(prefix=name + "-", dir=scratch))
    exe = work / name
    env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
    rec = {"program": str(src), "status": None}
    try:
        b = subprocess.run([compiler, "build", str(src), "--verify", "-o", str(exe)],
                           cwd=work, env=env, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        rec["status"] = "build-timeout"
        return rec
    if b.returncode != 0 or not exe.exists():
        rec["status"] = "no-build"
        return rec
    try:
        r = subprocess.run([str(exe)], cwd=work, capture_output=True, text=True, timeout=10)
    except subprocess.TimeoutExpired:
        rec["status"] = "run-timeout"
        return rec
    m = LEDGER.search(r.stdout + r.stderr)
    if not m:
        rec["status"] = "no-ledger"
        return rec
    a, rel, leak, viol = map(int, m.groups())
    rec.update(status="ledger", allocated=a, released=rel, leaked=leak, violations=viol,
               exit=r.returncode)
    return rec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--only", nargs="*", help="programs to run instead of tests/ + probes")
    args = ap.parse_args()
    root = pathlib.Path.cwd()
    compiler = str(pathlib.Path(args.compiler).resolve())
    if args.only:
        srcs = [pathlib.Path(p).resolve() for p in args.only]
    else:
        srcs = sorted((root / "tests").glob("*.psm")) + sorted((root / "docs/pir_impact/probes").glob("*.psm"))
    scratch = tempfile.mkdtemp(prefix="pir-impact-")
    with cf.ThreadPoolExecutor(args.jobs) as ex:
        recs = list(ex.map(lambda s: one(compiler, s, scratch), srcs))
    led = [r for r in recs if r["status"] == "ledger"]
    leaking = [r for r in led if r["leaked"] > 0]
    summary = {
        "programs": len(recs),
        "with_ledger": len(led),
        "statuses": {s: sum(1 for r in recs if r["status"] == s) for s in sorted({r["status"] for r in recs})},
        "leaked_blocks": sum(r["leaked"] for r in led),
        "leaking_programs": len(leaking),
        "violations": sum(r["violations"] for r in led),
        "violating_programs": sum(1 for r in led if r["violations"] > 0),
    }
    pathlib.Path(args.out).write_text(json.dumps({"summary": summary, "programs": recs}, indent=1))
    print(json.dumps(summary, indent=1))
    for r in sorted(leaking, key=lambda r: -r["leaked"])[:40]:
        print(f'{r["leaked"]:>6} / {r["allocated"]:<6} {pathlib.Path(r["program"]).name}')


if __name__ == "__main__":
    sys.exit(main())
