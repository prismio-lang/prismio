#!/usr/bin/env python3
"""The balanced five-arm rotation: old Prismio, new Prismio, Prismio hand-tuned,
Rust idiomatic, Rust hand-tuned -- for every corpus program, in one JSON.

    python3 tools/five_arm_bench.py --old build/tbaa3 --new build/rc \
        --runs 25 --label "M6 slice 2" --json aif/evidence/xlang/results-m6.json

V0_1_FEATURES.md 2.2 asks for a five-arm measurement after every task, and until
now each one was produced by a scratch script that was not kept -- so
`results-m6-slice2-final-all-five-arm.json` records a "balanced base orders x
cyclic rotations" schedule that nothing in the tree can reproduce. This is that
schedule, written down.

WHAT "BALANCED" MEANS, AND WHY IT IS NOT INTERLEAVING

`milestone_bench.py` alternates two arms, which controls for drift over a run but
not for position: with five arms, the one that runs first is always measured on a
colder machine than the one that runs last. Here each round runs all five arms in
a rotation of the base order, and the base order itself is rotated between
rounds, so over `runs` rounds every arm occupies every position an equal number
of times. Position bias is then in the noise of all five arms rather than in one.

It does not control binary layout, and nothing here can -- see the g5 note in
HANDOFF.md. A per-function mnemonic diff is what settles a single-program result,
before any number below is interpreted.

Checksums are asserted equal across all five arms before any timing is reported:
an arm that computes something else is not a faster arm.
"""

import argparse
import json
import os
import statistics
import subprocess
import sys
import tempfile
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XLANG = os.path.join(REPO, "aif", "evidence", "xlang")
OUT = os.path.join(XLANG, "build")
PROGRAMS = ["g1", "g2", "g3", "g4", "g5", "g6", "g9"]
# g1's expert arm is the DataView rewrite; bench.py carries the same alias.
PRISMIO_TUNED_ALIAS = {"g1": "g1_dataview_tuned.psm"}
RSS_SCALE = 1 if sys.platform == "darwin" else 1024


def arms_for(prog, old, new):
    """(key, label, argv-to-build, exe) for each arm that has a source."""
    out = []
    for key, label, compiler in (("old_prismio", "Prismio (old)", old),
                                 ("new_prismio", "Prismio (new)", new)):
        src = os.path.join(XLANG, "prismio", f"{prog}.psm")
        exe = os.path.join(OUT, f"{prog}_5arm_{key}")
        out.append((key, label, [compiler, "build", src, "-o", exe], exe))

    tuned = os.path.join(XLANG, "prismio",
                         PRISMIO_TUNED_ALIAS.get(prog, f"{prog}_tuned.psm"))
    if os.path.exists(tuned):
        exe = os.path.join(OUT, f"{prog}_5arm_prismio_tuned")
        out.append(("prismio_tuned", "Prismio hand-tuned",
                    [new, "build", tuned, "-o", exe], exe))

    for key, label, stem in (("rust_idiomatic", "Rust idiomatic", "idiomatic"),
                             ("rust_tuned", "Rust hand-tuned", "tuned")):
        src = os.path.join(XLANG, "rust", f"{prog}_{stem}.rs")
        if not os.path.exists(src):
            continue
        exe = os.path.join(OUT, f"{prog}_5arm_{key}")
        out.append((key, label,
                    ["rustc", "-C", "opt-level=3", "--edition", "2021", src,
                     "-o", exe], exe))
    return out


def run_once(exe, stdout_path):
    """One child, its own rusage. Same mechanism as bench.py's run_once."""
    actions = [(os.POSIX_SPAWN_OPEN, 1, stdout_path,
                os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)]
    t = time.perf_counter()
    pid = os.posix_spawn(exe, [exe], dict(os.environ), file_actions=actions)
    _, status, ru = os.wait4(pid, 0)
    wall = (time.perf_counter() - t) * 1000.0
    if status != 0:
        sys.exit(f"{exe} exited with status {status}")
    return wall, ru.ru_maxrss * RSS_SCALE


def parse_output(path):
    checks, frames = [], []
    with open(path) as fh:
        for line in fh:
            if line.startswith("frame_ns "):
                frames.append(int(line[9:]))
            elif line.startswith("checksum "):
                checks.append(line.strip())
    return checks, frames


def pct(xs, p):
    k = min(len(xs) - 1, max(0, int(round(p / 100.0 * (len(xs) - 1)))))
    return xs[k]


def spread(xs):
    s = sorted(xs)
    return [statistics.median(s), s[0], s[-1]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--old", required=True)
    ap.add_argument("--new", required=True)
    ap.add_argument("--runs", type=int, default=25)
    ap.add_argument("--only", choices=PROGRAMS)
    ap.add_argument("--label", default="five-arm")
    ap.add_argument("--json")
    args = ap.parse_args()

    old = os.path.abspath(args.old)
    new = os.path.abspath(args.new)
    os.makedirs(OUT, exist_ok=True)
    programs = [args.only] if args.only else PROGRAMS
    results = {}

    for prog in programs:
        arms = arms_for(prog, old, new)
        print(f"\n=== {prog} -- {len(arms)} arms ===", flush=True)
        for key, label, cmd, exe in arms:
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"build failed: {prog} {key}\n{' '.join(cmd)}\n"
                         f"{r.stdout}{r.stderr}")

        samples = {key: [] for key, _, _, _ in arms}
        checks = {}
        with tempfile.TemporaryDirectory(prefix="five-arm-") as tmp:
            out = os.path.join(tmp, "stdout")
            for run in range(args.runs):
                order = arms[run % len(arms):] + arms[:run % len(arms)]
                for key, _, _, exe in order:
                    wall, rss = run_once(exe, out)
                    c, frames = parse_output(out)
                    checks.setdefault(key, c)
                    if checks[key] != c:
                        sys.exit(f"{prog} {key} is not deterministic")
                    s = sorted(frames)
                    samples[key].append({
                        "loop_ms": sum(frames) / 1e6,
                        "wall_ms": wall,
                        "rss_mb": rss / (1024.0 * 1024.0),
                        "p50_us": pct(s, 50) / 1000.0,
                        "p99_us": pct(s, 99) / 1000.0,
                    })

        distinct = {tuple(c) for c in checks.values()}
        if len(distinct) != 1:
            sys.exit(f"{prog}: arms disagree on checksums: {checks}")

        arm_json = {}
        for key, label, _, _ in arms:
            runs = samples[key]
            arm_json[key] = {
                "label": label,
                **{f: spread([r[f] for r in runs])
                   for f in ("loop_ms", "wall_ms", "rss_mb", "p50_us", "p99_us")},
            }
        results[prog] = {"checksums": list(distinct)[0], "arms": arm_json}

        base = arm_json["rust_idiomatic"]["loop_ms"][0] if "rust_idiomatic" in arm_json else None
        print(f"{'arm':22s} {'loop ms':>9s} {'min':>9s} {'max':>9s} {'/rust':>7s}")
        for key, label, _, _ in arms:
            m, lo, hi = arm_json[key]["loop_ms"]
            rel = f"{m / base:.2f}x" if base else "--"
            print(f"{label:22s} {m:9.3f} {lo:9.3f} {hi:9.3f} {rel:>7s}")

    doc = {
        "meta": {
            "label": args.label,
            "old": os.path.relpath(old, REPO),
            "new": os.path.relpath(new, REPO),
            "runs_per_arm": args.runs,
            "schedule": "cyclic rotation of the arm order, one rotation per run",
            "when": time.strftime("%Y-%m-%d %H:%M:%S"),
        },
        "results": results,
    }
    if args.json:
        with open(args.json, "w") as fh:
            json.dump(doc, fh, indent=1)
        print(f"\nwrote {args.json}")


if __name__ == "__main__":
    main()
