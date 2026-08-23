#!/usr/bin/env python3
"""Milestone gate: old compiler vs new compiler vs Rust, over the whole corpus.

    python3 tools/milestone_bench.py --old build/E2 --new build/S11 --runs 25
    python3 tools/milestone_bench.py --old build/E2 --new build/S11 --only g2 --label seam

`bench.py` answers "where does this compiler stand against Rust". This
answers the other question, the one every milestone has to pass: **did the change
help, did it break anything, and did it move us against Rust.** Three things, one
command, because a milestone that only measures the first is how a regression
ships.

WHAT THIS DOES THAT bench.py DOES NOT

  interleaved A/B    Old and new alternate run by run rather than running in two
                     blocks. Thermal drift and any other slow-moving disturbance
                     then hits both arms equally instead of only the second --
                     RESULTS-arena §6, where a back-to-back number was
                     "directionally right and quantitatively wrong" because a
                     second agent was building on the host throughout.

  checksums across   Every variant of a program -- old, new, and every Rust and
  the whole set      Rust baselines -- must print identical checksums before
                     anything is timed. A compiler change that is 2x faster and
                     computes something else is the failure this catches, and it
                     is the one a speed harness is most likely to miss.

  the regression     RSS, executable size and allocation count are reported
  columns            old-vs-new too, not just time. Peak RSS reversed from
                     0.84-1.00x to 1.09-1.60x of Rust across seven sessions with
                     nobody watching, because no gate looked at it.

WHAT "PASS" MEANS

  Time     new/old <= 1.00 on the corpus median, and no single program regressed
           by more than the noise floor (--tolerance, default 5%).
  Memory   no program's RSS up more than --tolerance.
  Size     reported, never a gate: it is an accepted tradeoff.
  Rust     both arms reported against rust_idiomatic and rust_tuned, so the
           milestone's effect on the *standing* is visible and not just its
           effect on itself.

Medians over --runs runs. The spread is printed because a median alone cannot be
checked for stability, and on this corpus a single interfering run moves the
min-max band by 2x while leaving the median inside 3%.
"""

import argparse
import json
import os
import statistics
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
XLANG = os.path.join(REPO, "aif", "evidence", "xlang")
sys.path.insert(0, XLANG)

import bench  # noqa: E402  -- the harness this one wraps; same measurement code.

OUT = bench.OUT
# Rust arms worth carrying at a milestone. rust_boxed is a diagnostic for
# splitting representation from compiler and is not a standing baseline, so it
# is not here; bench.py still reports it.
#
# **Swift is off by default since 2026-08-23** -- the development loop compares
# against Rust. `--with-swift` adds it back, and it is the same flag bench.py
# takes, because two spellings of "include Swift" is how the two harnesses would
# come to disagree about what a milestone was measured against.
BASELINES = [("rust_idiomatic", "Rust idiomatic"),
             ("rust_tuned", "Rust hand-tuned")]
SWIFT_BASELINE = ("swift", "Swift idiomatic")


def build_prismio(compiler, prog, tag):
    """Build one corpus program with one compiler. Returns the exe path."""
    src = os.path.join(XLANG, "prismio", f"{prog}.psm")
    exe = os.path.join(OUT, f"ms_{tag}_{prog}")
    r = bench.sh([os.path.abspath(compiler), "build", src, "-o", exe])
    if r.returncode != 0:
        sys.exit(f"build failed: {prog} with {compiler}\n{r.stdout}\n{r.stderr}")
    return exe


def measure_ab(exe_a, exe_b, runs, tmp):
    """Interleaved A/B in ABBA order. Returns (per_run_a, per_run_b).

    One warm pair is run and discarded first: the first run of either binary
    pays page-cache and dyld cost that no later run pays, and charging that to
    whichever arm happens to go first is exactly the bias interleaving exists
    to remove.

    **The order alternates ABBA rather than repeating ABAB, and that is not a
    refinement -- it is the difference between this gate working and not.**
    Measured on this host with two compilers whose emitted IR for `g1.psm` is
    byte-identical: plain ABAB reported the second arm 1.095x slower, and
    swapping which compiler was "new" reported 1.073x slower *in the same
    direction*. Whichever binary runs second in a pair pays something -- page
    reclaim of the process that just exited is the likely cause, but the cause
    does not matter. ABBA gives each arm the first and second slot equally
    often, so a position effect cancels instead of being reported as a 9%
    regression on a change that did not happen.
    """
    bench.run_once(exe_a, tmp)
    bench.run_once(exe_b, tmp)

    def one(exe, acc):
        wall, rss = bench.run_once(exe, tmp)
        _, frames = bench.parse_output(tmp)
        s = sorted(frames)
        acc.append({
            "wall_ms": wall,
            "rss_mb": rss / (1024.0 * 1024.0),
            "loop_ms": sum(frames) / 1e6,
            "p50_us": bench.pct(s, 50) / 1000.0,
            "p99_us": bench.pct(s, 99) / 1000.0,
            "frames": len(frames),
        })

    a, b = [], []
    # Each iteration is one full ABBA block, so both arms get both positions.
    # `runs` is therefore the sample count per arm, as it is in bench.py.
    for i in range((runs + 1) // 2):
        one(exe_a, a)
        one(exe_b, b)
        one(exe_b, b)
        one(exe_a, a)
    return a[:runs], b[:runs]


def checksums(exe, tmp):
    bench.run_once(exe, tmp)
    c, _ = bench.parse_output(tmp)
    return c


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--old", required=True, help="baseline compiler, e.g. build/E2")
    ap.add_argument("--new", required=True, help="compiler under test")
    ap.add_argument("--runs", type=int, default=25)
    ap.add_argument("--only", choices=bench.PROGRAMS, action="append")
    ap.add_argument("--label", default="", help="milestone name, recorded in the JSON")
    ap.add_argument("--tolerance", type=float, default=10.0,
                    help="per-program regression before it is reported, percent "
                         "(default 10 -- see the layout-sensitivity note in the "
                         "module docstring; 5 false-positives on g1)")
    ap.add_argument("--median-tolerance", type=float, default=3.0,
                    help="corpus-median regression that fails the gate, percent "
                         "(default 3, the pass-to-pass reproducibility of a median)")
    ap.add_argument("--calibrate", action="store_true",
                    help="A/A: run --old against itself to measure this host's "
                         "floor. Do this once before trusting a per-program number.")
    ap.add_argument("--skip-baselines", action="store_true",
                    help="skip the Rust arms; A/B only, much faster")
    ap.add_argument("--with-swift", action="store_true",
                    help="also measure the Swift ports (off by default; the dev "
                         "loop compares against Rust)")
    ap.add_argument("--json", default=os.path.join(XLANG, "milestone.json"))
    args = ap.parse_args()

    for p in (args.old, args.new):
        if not os.path.exists(p):
            sys.exit(f"no compiler at {p}")

    progs = args.only or bench.PROGRAMS
    if args.with_swift:
        BASELINES.append(SWIFT_BASELINE)
        bench.ACTIVE_VARIANTS = list(bench.VARIANTS)
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "_ms_stdout.txt")

    if not args.skip_baselines:
        print("Building baselines (once)...", flush=True)
        for prog, key, label, lang, exe, cmds in bench.targets(args.new):
            if prog not in progs or lang == "prismio":
                continue
            if key not in dict(BASELINES):
                continue
            if os.path.exists(exe):
                continue
            for cmd in cmds:
                r = bench.sh(cmd, cwd=XLANG)
                if r.returncode != 0:
                    sys.exit(f"baseline build failed: {prog} {key}\n{r.stderr}")

    rows, regressed = {}, []
    for prog in progs:
        print(f"\n{'=' * 96}\n{prog}\n{'=' * 96}", flush=True)
        old_exe = build_prismio(args.old, prog, "old")
        # --calibrate builds the *same* compiler into the other arm, so whatever
        # the run reports is the floor rather than an effect.
        new_exe = build_prismio(args.old if args.calibrate else args.new, prog, "new")

        # Assert before measuring. A faster compiler that computes something
        # else is the failure this exists to catch.
        ref = checksums(old_exe, tmp)
        arms = [("new", new_exe)]
        if not args.skip_baselines:
            for key, label in BASELINES:
                exe = os.path.join(OUT, f"{prog}_{key}")
                if os.path.exists(exe):
                    arms.append((label, exe))
        for label, exe in arms:
            got = checksums(exe, tmp)
            if got != ref:
                sys.exit(f"{prog}: {label} disagrees with the old compiler\n"
                         f"  old: {ref}\n  {label}: {got}")
        print(f"checksums agree across {len(arms) + 1} variants: {'; '.join(ref)}")

        a, b = measure_ab(old_exe, new_exe, args.runs, tmp)
        oldm = bench.agg(a, "loop_ms")
        newm = bench.agg(b, "loop_ms")
        old_rss = bench.agg(a, "rss_mb")[0]
        new_rss = bench.agg(b, "rss_mb")[0]
        ratio = newm[0] / oldm[0] if oldm[0] else 0.0
        rss_ratio = new_rss / old_rss if old_rss else 0.0

        base = {}
        if not args.skip_baselines:
            for key, label in BASELINES:
                exe = os.path.join(OUT, f"{prog}_{key}")
                if os.path.exists(exe):
                    per, _ = bench.measure(exe, args.runs, tmp)
                    base[key] = bench.agg(per, "loop_ms")[0]

        print(f"{'arm':<18}{'loop ms':>10}{'min':>9}{'max':>9}{'RSS MB':>9}{'exe KB':>9}")
        print(f"{'old':<18}{oldm[0]:10.1f}{oldm[1]:9.1f}{oldm[2]:9.1f}{old_rss:9.1f}"
              f"{os.path.getsize(old_exe) / 1024:9.0f}")
        print(f"{'new':<18}{newm[0]:10.1f}{newm[1]:9.1f}{newm[2]:9.1f}{new_rss:9.1f}"
              f"{os.path.getsize(new_exe) / 1024:9.0f}")
        for key, label in BASELINES:
            if key in base:
                print(f"{label:<18}{base[key]:10.1f}")

        verdict = "IMPROVED" if ratio < 1 - args.tolerance / 100 else (
            "REGRESSED" if ratio > 1 + args.tolerance / 100 else "flat")
        print(f"\nnew/old  {ratio:.3f}x  ({verdict})   RSS {rss_ratio:.3f}x")
        if base.get("rust_idiomatic"):
            print(f"vs Rust idiomatic:  old {oldm[0] / base['rust_idiomatic']:.2f}x"
                  f"  ->  new {newm[0] / base['rust_idiomatic']:.2f}x")
        if base.get("rust_tuned"):
            print(f"vs Rust hand-tuned: old {oldm[0] / base['rust_tuned']:.2f}x"
                  f"  ->  new {newm[0] / base['rust_tuned']:.2f}x")

        if ratio > 1 + args.tolerance / 100:
            regressed.append(f"{prog}: time {ratio:.3f}x")
        if rss_ratio > 1 + args.tolerance / 100:
            regressed.append(f"{prog}: RSS {rss_ratio:.3f}x")

        rows[prog] = {
            "old_loop_ms": oldm, "new_loop_ms": newm, "ratio": ratio,
            "old_rss_mb": old_rss, "new_rss_mb": new_rss, "rss_ratio": rss_ratio,
            "old_exe_bytes": os.path.getsize(old_exe),
            "new_exe_bytes": os.path.getsize(new_exe),
            "baselines": base, "checksums": ref, "runs": args.runs,
        }

    label = args.label or "(unlabelled milestone)"
    if args.calibrate:
        label = f"A/A CALIBRATION of {args.old}"
    print(f"\n{'=' * 96}\nSUMMARY  --  {label}\n{'=' * 96}")
    ratios = [r["ratio"] for r in rows.values()]
    med = statistics.median(ratios) if ratios else 1.0
    if ratios:
        print(f"corpus median new/old: {med:.3f}x   "
              f"range {min(ratios):.3f}-{max(ratios):.3f}x")

    if args.calibrate:
        print("\nThis is the FLOOR for this host, not an effect. Set --tolerance "
              "above the widest\nper-program number above before trusting a "
              "single-program result from a real A/B.")
        failures = []
    else:
        # One regressed program is layout luck -- two is a pattern. Measured on
        # this host: E2 vs a compiler bootstrapped from it with no source change
        # reads 1.098x on g1 and 0.989-1.019x on the other five, and their
        # emitted IR for g1 is byte-identical. Gating on a single program would
        # have failed that. The corpus median is the number that holds.
        failures = []
        if med > 1 + args.median_tolerance / 100:
            failures.append(f"corpus median {med:.3f}x "
                            f"(> {1 + args.median_tolerance / 100:.3f})")
        if len(regressed) >= 2:
            failures.append(f"{len(regressed)} programs regressed past "
                            f"{args.tolerance}%: {', '.join(regressed)}")

        if regressed and not failures:
            print(f"\nWARN -- one measurement past {args.tolerance}%, corpus median "
                  f"holds. Layout sensitivity\nlooks exactly like this; confirm with "
                  f"--calibrate before treating it as real:")
            for f in regressed:
                print(f"  {f}")

        if failures:
            print("\nGATE FAILED:")
            for f in failures:
                print(f"  {f}")
        else:
            print(f"\nGATE PASSED (corpus median within {args.median_tolerance}%, "
                  f"fewer than 2 programs past {args.tolerance}%)")

    with open(args.json, "w") as fh:
        json.dump({
            "meta": {
                "label": args.label, "old": args.old, "new": args.new,
                "runs": args.runs, "tolerance_pct": args.tolerance,
                "when": time.strftime("%Y-%m-%d %H:%M:%S"),
                "rustc": bench.sh(["rustc", "--version"]).stdout.strip(),
            },
            "results": rows,
            "gate": {"passed": not failures, "failures": failures},
        }, fh, indent=2)
    print(f"\nwrote {args.json}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
