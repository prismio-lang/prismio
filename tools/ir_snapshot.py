#!/usr/bin/env python3
"""Dump `prismio build` IR for every compilable program, into one directory.

    python3 tools/ir_snapshot.py --compiler build/t3 --out /tmp/base

A behaviour-preserving change must produce byte-identical IR (CODE_STYLE), and
the usual check covers `tests/` and `aif/corpus/`. This also compiles the root
benchmark suite, so a change that moves only performance programs cannot pass
unnoticed.

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



def under_neutral_name(compiler):
    """A copy of `compiler` whose basename is not `prismio`, beside the original.

    A compiler *called* `prismio` is a launcher: run inside a project it hands the
    command to `.prismio/build/debug/<host>` instead of compiling anything itself,
    so a tool pointed at `build/gN/bin/prismio` silently measures whichever host
    that project last built. Two snapshots taken that way agree perfectly and mean
    nothing -- which is the failure this exists to make impossible.

    Copied beside the original rather than into a temporary directory, because
    both the runtime bitcode and the standard library are found relative to the
    executable: `<exe_dir>/../lib` and `<exe_dir>/../stdlib`. A copy anywhere else
    is a compiler with no toolchain.
    """
    import os, shutil
    compiler = os.path.abspath(compiler)
    if os.path.basename(compiler) not in ("prismio", "prismio.exe"):
        return compiler, None
    root, ext = os.path.splitext(compiler)
    neutral = f"{root}-probe-{os.getpid()}{ext}"
    shutil.copy2(compiler, neutral)
    return neutral, neutral


def programs():
    found = []
    for pat in ("tests/*.psm",
                "aif/corpus/*.psm",
                "benchmarks/prismio/*.psm",
                "src/main.psm"):
        found += glob.glob(os.path.join(REPO, pat))
    return sorted(set(found))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    cc, cc_copy = under_neutral_name(args.compiler)
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

    if cc_copy:
        os.remove(cc_copy)

    with open(os.path.join(out, "SKIPPED"), "w") as f:
        f.write("\n".join(skipped) + "\n")
    print(f"{built} programs built, {len(skipped)} skipped -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
