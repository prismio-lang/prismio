#!/usr/bin/env python3
"""Dump `prismio build` IR for every compilable program, into one directory.

    python3 tools/ir_snapshot.py --compiler build/t3 --out /tmp/base

A behaviour-preserving change must produce byte-identical IR (CODE_STYLE), and
the usual check covers `tests/` and `aif/corpus/` -- `aif/evidence/` is not in
either. This walks all three, so a change that moves only the measurement
programs cannot pass unnoticed.

Programs that do not build (a module with no `main`, or a `neg_*` fixture that is
supposed to fail) are recorded in `SKIPPED` rather than dropped, so a program
that *stops* building shows up as a diff instead of as a smaller directory.
"""
import argparse
import glob
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def programs():
    found = []
    for pat in ("tests/*.psm",
                "aif/corpus/*.psm",
                "aif/evidence/xlang/prismio/*.psm",
                "src/main.psm"):
        found += glob.glob(os.path.join(REPO, pat))
    return sorted(set(found))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    cc = os.path.abspath(args.compiler)
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)

    skipped = []
    built = 0
    for path in programs():
        rel = os.path.relpath(path, REPO)
        name = rel.replace("/", "__").replace(".psm", ".ll")
        dest = os.path.join(out, name)
        r = subprocess.run([cc, "build", path, "-o", dest],
                           capture_output=True, text=True, cwd=REPO)
        if r.returncode != 0 or not os.path.exists(dest):
            if os.path.exists(dest):
                os.remove(dest)
            skipped.append(rel)
            continue
        built += 1

    with open(os.path.join(out, "SKIPPED"), "w") as f:
        f.write("\n".join(skipped) + "\n")
    print(f"{built} programs built, {len(skipped)} skipped -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
