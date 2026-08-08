#!/usr/bin/env python3
"""How much of Prismio's gap is optimisation that never runs?

    python3 aif/evidence/xlang/optgap.py --compiler build/gen2

Until 2026-08-08 `prismio build` left two separate stages unoptimised, and
neither was a memory model decision. Both now pass -O2; this script still builds
the 2x2 so the flags cannot be removed without the cost showing up
(runtime/build_driver.c):

  1. `compile_ir_to_object` ran `llc <ir> -filetype=obj` with no flags. llc runs
     the *codegen* pipeline -- isel, scheduling, register allocation -- but not
     the IR pipeline. mem2reg, SROA, GVN, LICM, inlining and vectorisation never
     touched a user program, so every local stayed a stack slot and every field
     read was reloaded from memory.

  2. `build_from_toolchain_sources` compiled the runtime with no `-O`, i.e. at
     -O0. That is where `list_get`, `list_push` and the allocator live, and they
     are called millions of times per run.

This script builds a 2x2 over those two stages from the compiler's own emitted
IR, unmodified. Same frontend, same backend, same IR, same runtime source, same
linker -- the only variables are the two optimisation flags. `both` is what
`prismio build` produces today; `-O0 both` is what it produced before.

It changes nothing in the compiler. It exists to split the cross-language gap
into the part the memory model owns and the part it does not.
"""

import argparse
import json
import os
import statistics
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "build", "optgap")
PROGRAMS = ["g1", "g2", "g3", "g4", "g5", "g6"]

# (label, runtime -O level, run opt -O2 on the program IR)
CONFIGS = [
    ("-O0 both",      "-O0", False),
    ("runtime -O2",   "-O2", False),
    ("program opt",   "-O0", True),
    ("both",          "-O2", True),
]


def sh(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"failed: {' '.join(cmd)}\n{r.stdout}\n{r.stderr}")
    return r


def loop_ms(exe, runs, tmp):
    """Median in-process loop time, from the program's own frame samples."""
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
    return statistics.median(samples), min(samples), max(samples), checks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", default=os.path.join(REPO, "build", "gen2"))
    ap.add_argument("--runs", type=int, default=20)
    ap.add_argument("--json", default=os.path.join(HERE, "optgap.json"))
    args = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "_out.txt")
    compiler = os.path.abspath(args.compiler)

    # The runtime half only -- exactly what a normal user build links.
    runtime_objs = {}
    for lvl in ("-O0", "-O2"):
        objs = []
        for c in ("lang_runtime.c", "program_support.c"):
            obj = os.path.join(OUT, f"{c[:-2]}{lvl}.o")
            sh(["clang", lvl, "-Wno-deprecated-declarations", "-c",
                os.path.join(REPO, "runtime", c), "-o", obj])
            objs.append(obj)
        runtime_objs[lvl] = objs

    print(f"{'program':<9}" + "".join(f"{label:>15}" for label, _, _ in CONFIGS)
          + f"{'total':>15}")
    print("-" * (9 + 15 * (len(CONFIGS) + 1)))

    results = {}
    for prog in PROGRAMS:
        ll = os.path.join(OUT, f"{prog}.ll")
        sh([compiler, "build", os.path.join(HERE, "prismio", f"{prog}.psm"), "-o", ll])

        opt_bc = os.path.join(OUT, f"{prog}.opt.bc")
        sh(["opt", "-O2", ll, "-o", opt_bc])

        row, reference = {}, None
        for label, rt_lvl, use_opt in CONFIGS:
            ir = opt_bc if use_opt else ll
            obj = os.path.join(OUT, f"{prog}.{label.replace(' ', '_')}.o")
            exe = os.path.join(OUT, f"{prog}.{label.replace(' ', '_')}")
            sh(["llc", ir, "-filetype=obj", "-o", obj])
            sh(["clang", obj] + runtime_objs[rt_lvl] + ["-o", exe])
            med, lo, hi, checks = loop_ms(exe, args.runs, tmp)
            if reference is None:
                reference = checks
            elif checks != reference:
                sys.exit(f"{prog}: {label} changed the answer\n  {reference}\n  {checks}")
            row[label] = {"ms": med, "min": lo, "max": hi,
                          "exe_bytes": os.path.getsize(exe)}

        base = row["-O0 both"]["ms"]
        results[prog] = {"configs": row, "checksums": reference,
                         "total_speedup": base / row["both"]["ms"]}
        print(f"{prog:<9}" + "".join(f"{row[l]['ms']:13.1f}ms" for l, _, _ in CONFIGS)
              + f"{base / row['both']['ms']:14.2f}x")

    print("\nChecksums are identical across all four columns of every row: these "
          "flags change speed and nothing else.")
    with open(args.json, "w") as fh:
        json.dump({"runs": args.runs, "results": results}, fh, indent=2)
    print(f"wrote {args.json}")


if __name__ == "__main__":
    main()
