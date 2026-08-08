#!/usr/bin/env python3
"""Which -O level should `prismio build` use?

    python3 aif/evidence/xlang/optlevel.py --compiler build/gen2

Two stages take a level independently: the program's IR (middle-end + codegen)
and the runtime C sources. This sweeps both and reports loop time, executable
size and the compile time each costs, so the choice written into
runtime/build_driver.c is a measurement rather than a default.

`clang -Ox -c <ir>` is used for the IR rather than `opt -Ox | llc`, because clang
runs both pipelines in one process, clang is already a hard dependency for the
link step, and it drops llc from the user-build path entirely.
"""

import argparse
import json
import os
import statistics
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "build", "optlevel")
PROGRAMS = ["g1", "g2", "g3", "g4", "g5", "g6"]

# (label, program IR level, runtime level)
CONFIGS = [
    ("O0/O0 (shipped)", "-O0", "-O0"),
    ("O2/O2",           "-O2", "-O2"),
    ("O3/O3",           "-O3", "-O3"),
    ("O3/O3 lto",       "-O3", "-O3"),   # -flto added for this row only
    ("Os/Os",           "-Os", "-Os"),
]
LTO_ROW = "O3/O3 lto"


def sh(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"failed: {' '.join(cmd)}\n{r.stdout}\n{r.stderr}")
    return r


def loop_ms(exe, runs, tmp):
    samples, checks = [], None
    for _ in range(runs):
        with open(tmp, "w") as fh:
            subprocess.run([exe], stdout=fh, check=True)
        total, c = 0, []
        with open(tmp) as fh:
            for line in fh:
                if line.startswith("frame_ns "):
                    total += int(line[9:])
                elif line.startswith("checksum "):
                    c.append(line.strip())
        if checks is None:
            checks = c
        elif c != checks:
            sys.exit(f"{exe} is not deterministic")
        samples.append(total / 1e6)
    return statistics.median(samples), checks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", default=os.path.join(REPO, "build", "gen2"))
    ap.add_argument("--runs", type=int, default=15)
    ap.add_argument("--json", default=os.path.join(HERE, "optlevel.json"))
    args = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "_out.txt")
    compiler = os.path.abspath(args.compiler)

    print(f"{'program':<9}" + "".join(f"{lbl:>17}" for lbl, _, _ in CONFIGS))
    print("-" * (9 + 17 * len(CONFIGS)))

    results, sizes, ctimes = {}, {}, {}
    for prog in PROGRAMS:
        ll = os.path.join(OUT, f"{prog}.ll")
        sh([compiler, "build", os.path.join(HERE, "prismio", f"{prog}.psm"), "-o", ll])

        row, reference = {}, None
        for label, ir_lvl, rt_lvl in CONFIGS:
            lto = ["-flto"] if label == LTO_ROW else []
            tag = label.replace("/", "_").replace(" ", "_")
            obj = os.path.join(OUT, f"{prog}.{tag}.o")
            exe = os.path.join(OUT, f"{prog}.{tag}")

            t = time.perf_counter()
            sh(["clang", ir_lvl] + lto + ["-c", ll, "-o", obj])
            rt = []
            for c in ("lang_runtime.c", "program_support.c"):
                o = os.path.join(OUT, f"{prog}.{tag}.{c[:-2]}.o")
                sh(["clang", rt_lvl] + lto + ["-Wno-deprecated-declarations", "-c",
                    os.path.join(REPO, "runtime", c), "-o", o])
                rt.append(o)
            sh(["clang"] + lto + ([ir_lvl] if lto else []) + [obj] + rt + ["-o", exe])
            compile_ms = (time.perf_counter() - t) * 1000.0

            med, checks = loop_ms(exe, args.runs, tmp)
            if reference is None:
                reference = checks
            elif checks != reference:
                sys.exit(f"{prog}: {label} changed the answer\n  {reference}\n  {checks}")
            row[label] = {"ms": med, "exe_bytes": os.path.getsize(exe),
                          "compile_ms": compile_ms}

        results[prog] = row
        sizes[prog] = {l: row[l]["exe_bytes"] for l, _, _ in CONFIGS}
        ctimes[prog] = {l: row[l]["compile_ms"] for l, _, _ in CONFIGS}
        print(f"{prog:<9}" + "".join(f"{row[l]['ms']:15.1f}ms" for l, _, _ in CONFIGS))

    base = CONFIGS[1][0]  # O2/O2
    print(f"\nrelative to {base}:")
    print(f"{'program':<9}" + "".join(f"{lbl:>17}" for lbl, _, _ in CONFIGS))
    for prog in PROGRAMS:
        r = results[prog]
        print(f"{prog:<9}" + "".join(
            f"{r[l]['ms'] / r[base]['ms']:16.3f}x" for l, _, _ in CONFIGS))

    print(f"\nexecutable size, KB:")
    print(f"{'program':<9}" + "".join(f"{lbl:>17}" for lbl, _, _ in CONFIGS))
    for prog in PROGRAMS:
        print(f"{prog:<9}" + "".join(
            f"{sizes[prog][l] / 1024:16.0f} " for l, _, _ in CONFIGS))

    print(f"\nIR->obj + runtime compile + link, ms (median of 1, indicative):")
    print(f"{'program':<9}" + "".join(f"{lbl:>17}" for lbl, _, _ in CONFIGS))
    for prog in PROGRAMS:
        print(f"{prog:<9}" + "".join(
            f"{ctimes[prog][l]:16.0f} " for l, _, _ in CONFIGS))

    with open(args.json, "w") as fh:
        json.dump({"runs": args.runs, "results": results}, fh, indent=2)
    print(f"\nwrote {args.json}")


if __name__ == "__main__":
    main()
