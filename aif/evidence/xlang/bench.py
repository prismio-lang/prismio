#!/usr/bin/env python3
"""Cross-language measurement for the AIF corpus: Prismio vs Rust (and Swift on request).

Swift is off by default -- pass `--with-swift` for the full matrix. See ACTIVE_VARIANTS.

    python3 aif/evidence/xlang/bench.py --compiler build/gen2
    python3 aif/evidence/xlang/bench.py --compiler build/gen2 --only g2 --runs 40

Everything is one command on purpose: build, assert the variants agree, measure,
report. A later session re-runs this and compares JSON.

WHAT IS MEASURED, AND HOW

  frame time p50/p99/p999   In-process. Every program times each sample with
                            clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) -- the same
                            call in all three languages -- and prints one
                            `frame_ns` line per sample after the loop. G5 groups
                            32 renders per sample to lift its few-microsecond
                            kernel above the rebuilt-binary noise floor; its
                            total render count and checksum stay unchanged. This
                            is the lead metric: process wall time hides the tail,
                            and the tail is what a frame budget is made of.

  loop ms                   Sum of the frame samples. The work, without process
                            startup and without the report dump.

  wall ms                   Whole process, harness-side. Includes startup, setup
                            outside the frame loop, and the dump.

  peak RSS                  ru_maxrss from wait4 on the child. Exact, not sampled:
                            a poll loop can miss a spike and a spike is the point.

  allocs / frees            A separate run under allocount.dylib, which interposes
                            malloc/calloc/realloc/free. It counts the *allocator*,
                            so the number means the same thing in every language --
                            Prismio's --verify counters, Rust's alloc hooks and
                            Swift's runtime each count something different.
                            Interposition costs an indirect call per allocation, so
                            these runs are never used for timing. Rates are counts
                            over the median clean loop time.

                            **Counted up to the end of the last timed frame** --
                            startup, setup and the loop, with the frame_ns dump
                            excluded -- bracketed on the clock every one of these
                            programs already reads per frame. It was a process
                            total until 2026-08-16, and once the corpus's reporting
                            loops moved onto the allocating `println` overload
                            (commit 901b494) that made g1 read 26,261 where the
                            workload allocated 2,215: ~4 allocations per print over
                            6,002 prints, with the timing untouched. The column had
                            become a measure of reporting.

                            Setup is deliberately inside the window: it is where a
                            boxed representation costs, and it is most of the
                            2,215-vs-206 gap against Rust on g1. A loop-only window
                            would read ~0 on both sides and say nothing. The
                            process total is still reported, on the "whole process"
                            line under each table and as `process_allocs` /
                            `process_frees` in the JSON.

  exe size                  Stat of the linked binary.

  NOTE  Until 2026-08-08 `prismio build` ran no optimiser on either the program
        IR or the runtime, and this harness carried a second "Prismio +opt" row
        reconstructing what the missing flags were worth (1.4x-3.0x). The flags
        landed in runtime/build_driver.c, the shipped binary now matches that
        reconstruction to within 4%, and the row is gone. optgap.py still builds
        the 2x2 over both flags, as a regression detector.

  cold compile              Median of 3 compiles with no prior output artifact.
                            "Cold" means no incremental cache to reuse; it does not
                            mean a cold OS page cache.

Medians are over --runs runs (default 20, per the brief) and every median is
printed with the spread across those runs, because a median alone cannot be
checked for stability.
"""

import argparse
import json
import os
import shutil
import statistics
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "build")
BUMPALO = os.path.join(HERE, "vendor", "libbumpalo.rlib")

# ru_maxrss is bytes on macOS and kilobytes on Linux.
RSS_SCALE = 1.0 if sys.platform == "darwin" else 1024.0
PRELOAD_VAR = "DYLD_INSERT_LIBRARIES" if sys.platform == "darwin" else "LD_PRELOAD"
DYLIB = "allocount.dylib" if sys.platform == "darwin" else "allocount.so"

PROGRAMS = ["g1", "g2", "g3", "g4", "g5", "g6", "g8_tree_rebuild", "g9"]

# Where a program's Prismio hand-tuned arm lives when it is not `<prog>_tuned.psm`.
#
# g1's expert version **is** the DataView one: a structure-of-arrays view is
# something the language offers, so writing an AoS-only "tuned" arm to make the
# filename pattern come out even would understate Prismio in the one column whose
# job is to say what Prismio can reach. The DV-tuned row stays as well, because
# the representation study is what it was recorded for -- the two rows are the
# same binary and are labelled differently on purpose.
#
# **g9 has no entry and no file, and that absence is a result.** Hand-tuned Rust
# keeps four workers alive across frames and hands them work over channels;
# Prismio has `spawn` and `join` and no way to keep a task alive past its join, so
# the arm is not writable rather than not written. When it becomes writable, the
# 1.45x gap against `g9_tuned.rs` gets re-measured -- see v0.1 FEATURES 4.
PRISMIO_TUNED_ALIAS = {"g1": "g1_dataview_tuned.psm"}

# (variant key, label, language). Order is the report order.
#
# rust-boxed is a diagnostic, not one of the three requested Rust variants: it
# holds Prismio's representation fixed (a vector of pointers to individually
# heap-allocated records) and lets rustc emit the code, which splits a Prismio
# vs Rust gap into "the representation" and "everything else". It exists only
# for g1 and g2, the two programs where that split carries the argument.
VARIANTS = [
    ("prismio",       "Prismio",         "prismio"),
    ("prismio_dataview", "Prismio DataView", "prismio"),
    ("prismio_dataview_tuned", "Prismio DV tuned", "prismio"),
    # v0.1 2.2's fifth arm: the same program written the way a Prismio expert
    # would. Reported next to `rust_tuned` because that is the comparison it
    # exists to make -- "the ceiling in each language", not "Prismio with a
    # different representation", which is what the DataView rows are.
    ("prismio_tuned", "Prismio hand-tuned", "prismio"),
    ("rust_idiomatic", "Rust idiomatic",  "rust"),
    ("rust_arena",    "Rust arena",      "rust"),
    ("rust_tuned",    "Rust hand-tuned", "rust"),
    ("rust_boxed",    "Rust boxed [dx]", "rust"),
    ("swift",         "Swift idiomatic", "swift"),
]

# Swift is **off by default since 2026-08-23**: the development loop compares
# against Rust, and a `swiftc -O -wmo` build of every program is the slowest part
# of a run that is otherwise waiting on Prismio.
#
# Kept rather than deleted, and behind a flag rather than a comment, because the
# Swift columns in the RESULTS-* files are recorded evidence -- `--with-swift`
# reproduces them. A run without it writes no Swift rows at all, so a JSON from
# each is distinguishable by content and not only by the flag that made it.
ACTIVE_VARIANTS = [v for v in VARIANTS if v[2] != "swift"]


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


# ---------------------------------------------------------------- building


def rust_sources():
    d = os.path.join(HERE, "rust")
    found = {}
    for f in os.listdir(d):
        if not f.endswith(".rs") or f in ("harness.rs", "g6_engine.rs"):
            continue
        prog, _, kind = f[:-3].partition("_")
        found[(prog, "rust_" + kind)] = os.path.join(d, f)
    return found


def targets(compiler):
    """Every (program, variant) that has a source, with its build command(s).

    A build is a list of argv lists rather than one, so a variant that needs
    several steps can have its cold compile time cover all of them.
    """
    out = []
    rust = rust_sources()
    for prog in PROGRAMS:
        for key, label, lang in ACTIVE_VARIANTS:
            exe = os.path.join(OUT, f"{prog}_{key}")
            if lang == "prismio":
                suffix = {
                    "prismio": "",
                    "prismio_dataview": "_dataview",
                    "prismio_dataview_tuned": "_dataview_tuned",
                    "prismio_tuned": "_tuned",
                }[key]
                name = f"{prog}{suffix}.psm"
                if key == "prismio_tuned":
                    name = PRISMIO_TUNED_ALIAS.get(prog, name)
                src = os.path.join(HERE, "prismio", name)
                # DataView is a discriminating g1 representation arm, not a claim
                # that every corpus program has been ported. A missing
                # `prismio_tuned` is the honest absence 2.2 asks for: the column
                # says nothing rather than repeating the idiomatic number.
                if not os.path.exists(src):
                    continue
                cmd = [compiler, "build", src, "-o", exe]
            elif lang == "rust":
                src = rust.get((prog, key))
                if src is None:
                    continue
                # `cargo build --release` exactly: opt-level 3, panic=unwind,
                # no LTO. panic=abort would remove landing pads around every
                # allocation and flatter Rust against languages that do not
                # unwind -- which is the wrong direction for a falsification.
                cmd = ["rustc", "-C", "opt-level=3", "--edition", "2021"]
                if key == "rust_arena":
                    cmd += ["--extern", f"bumpalo={BUMPALO}"]
                cmd += [src, "-o", exe]
            else:
                src = os.path.join(HERE, "swift", f"{prog}.swift")
                srcs = [os.path.join(HERE, "swift", "harness.swift")]
                if prog == "g6":
                    srcs.append(os.path.join(HERE, "swift", "g6_engine.swift"))
                srcs.append(src)
                # -wmo is what a release build uses; without it Swift cannot
                # inline across the harness/engine file split.
                cmd = ["swiftc", "-O", "-wmo"] + srcs + ["-o", exe]
            out.append((prog, key, label, lang, exe, [cmd]))
    return out


def ensure_bumpalo():
    """Build bumpalo once into vendor/, if it is not already there.

    An .rlib is specific to a host and a rustc version, so it is not committed.
    Building it here rather than depending on cargo per-program keeps cold
    compile time a measurement of the benchmark program and not of a crate.
    """
    if os.path.exists(BUMPALO):
        return
    vendor = os.path.dirname(BUMPALO)
    os.makedirs(vendor, exist_ok=True)
    scratch = os.path.join(vendor, "_bumpalo_build")
    if not os.path.exists(os.path.join(scratch, "Cargo.toml")):
        os.makedirs(os.path.join(scratch, "src"), exist_ok=True)
        with open(os.path.join(scratch, "Cargo.toml"), "w") as fh:
            fh.write('[package]\nname = "bumpalo_vendor"\nversion = "0.0.0"\n'
                     'edition = "2021"\n\n[dependencies]\n'
                     'bumpalo = { version = "3", features = ["collections"] }\n')
        with open(os.path.join(scratch, "src", "lib.rs"), "w") as fh:
            fh.write("pub use bumpalo;\n")
    print("  vendoring bumpalo (once)...", flush=True)
    r = sh(["cargo", "build", "--release"], cwd=scratch)
    if r.returncode != 0:
        sys.exit("could not build bumpalo -- needs cargo and network:\n" + r.stderr)
    deps = os.path.join(scratch, "target", "release", "deps")
    rlib = next((os.path.join(deps, f) for f in sorted(os.listdir(deps))
                 if f.startswith("libbumpalo-") and f.endswith(".rlib")), None)
    if rlib is None:
        sys.exit(f"bumpalo built but no rlib found in {deps}")
    shutil.copyfile(rlib, BUMPALO)


def build_all(compiler, compile_runs=3):
    os.makedirs(OUT, exist_ok=True)
    ensure_bumpalo()
    dylib = os.path.join(OUT, DYLIB)
    r = sh(["clang", "-O2", "-dynamiclib" if sys.platform == "darwin" else "-shared",
            "-fPIC", os.path.join(HERE, "allocount.c"), "-o", dylib])
    if r.returncode != 0:
        sys.exit("allocount build failed:\n" + r.stderr)

    compile_ms = {}
    for prog, key, label, lang, exe, cmds in targets(compiler):
        samples = []
        for _ in range(compile_runs):
            # Cold = no prior output to reuse. Swift also caches modules beside
            # the binary, so clear that too.
            for stale in (exe, exe + ".swiftmodule", exe + ".dSYM"):
                if os.path.isdir(stale):
                    shutil.rmtree(stale, ignore_errors=True)
                elif os.path.exists(stale):
                    os.remove(stale)
            t = time.perf_counter()
            for cmd in cmds:
                r = sh(cmd, cwd=HERE)
                if r.returncode != 0:
                    sys.exit(f"build failed: {prog} {key}\n{' '.join(cmd)}\n"
                             f"{r.stdout}\n{r.stderr}")
            samples.append((time.perf_counter() - t) * 1000.0)
            if not os.path.exists(exe):
                sys.exit(f"build produced no binary: {prog} {key}")
        compile_ms[(prog, key)] = statistics.median(samples)
        print(f"  built {prog:>3} {label:<16} {compile_ms[(prog, key)]:8.1f} ms", flush=True)
    return compile_ms


# ------------------------------------------------------------------ running


def run_once(exe, stdout_path, preload=None, alloc_out=None):
    """One child. Returns (wall_ms, peak_rss_bytes) and writes stdout to a file.

    posix_spawn + wait4 rather than subprocess, because wait4 hands back the
    child's own rusage. RUSAGE_CHILDREN would be a running maximum over every
    child this process ever had, which is not the same number.
    """
    env = dict(os.environ)
    if preload:
        env[PRELOAD_VAR] = preload
    if alloc_out:
        env["ALLOCOUNT_OUT"] = alloc_out

    actions = [(os.POSIX_SPAWN_OPEN, 1, stdout_path,
                os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)]
    t = time.perf_counter()
    pid = os.posix_spawn(exe, [exe], env, file_actions=actions)
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
    """Nearest-rank percentile on already-sorted xs."""
    k = min(len(xs) - 1, max(0, int(round(p / 100.0 * (len(xs) - 1)))))
    return xs[k]


def measure(exe, runs, tmp):
    """`runs` clean timing runs. Returns per-run statistics, plus the checksums."""
    per_run = []
    checks = None
    for _ in range(runs):
        wall, rss = run_once(exe, tmp)
        c, frames = parse_output(tmp)
        if checks is None:
            checks = c
        elif c != checks:
            sys.exit(f"{exe} is not deterministic: {checks} vs {c}")
        s = sorted(frames)
        per_run.append({
            "wall_ms": wall,
            "rss_mb": rss / (1024.0 * 1024.0),
            "loop_ms": sum(frames) / 1e6,
            "p50_us": pct(s, 50) / 1000.0,
            "p99_us": pct(s, 99) / 1000.0,
            "p999_us": pct(s, 99.9) / 1000.0,
            "frames": len(frames),
        })
    return per_run, checks


# libsystem reads the clock a couple of dozen times during startup, so the window
# opens before main rather than at frame 0. Measured 14-25 over the corpus; 64 is
# the slack that admits that without admitting a bracket in a hot path.
CLOCK_SLACK = 64


def measure_allocs(exe, dylib, tmp, alloc_tmp, frames=None, label=""):
    """Allocator traffic up to the end of the last timed frame, and process-wide.

    The first number is the one the table prints, and the two were the same
    number until the corpus's reporting loops moved onto the allocating
    `println` overload: g1 then read 26,261 process allocations against 2,215 of
    workload, because 6,002 prints cost ~4 each. The timing never included the
    dump, so the process total had stopped describing anything the timing did.

    The window spans startup, setup and the frame loop, and excludes the dump --
    see allocount.c for why that is the right cut rather than the loop alone
    (setup is where a boxed representation pays, and a loop-only window reads ~0
    on both sides for g1). `clock_calls` audits that the bracket is where it is
    claimed to be.
    """
    run_once(exe, tmp, preload=dylib, alloc_out=alloc_tmp)
    counts = {}
    with open(alloc_tmp) as fh:
        for line in fh:
            k, v = line.split()
            counts[k] = int(v)

    total = sum(counts.get(k, 0) for k in ("malloc", "calloc", "realloc"))
    loop = sum(counts.get("loop_" + k, 0) for k in ("malloc", "calloc", "realloc"))

    if "clock_calls" not in counts:
        sys.exit("allocount reported no clock_calls: the dylib predates the "
                 "windowed counters. Rebuild it -- "
                 "rm aif/evidence/xlang/build/allocount.dylib -- or drop "
                 "--skip-build, which rebuilds it every time.")
    if frames is not None:
        lo, hi = 2 * frames, 2 * frames + CLOCK_SLACK
        if not lo <= counts["clock_calls"] <= hi:
            sys.exit(
                f"{label or exe}: the allocation window is not where it should "
                f"be -- {counts['clock_calls']:,} clock reads for {frames:,} "
                f"frames, outside [{lo:,}, {hi:,}]. Either something other than "
                f"the frame loop is reading CLOCK_MONOTONIC_RAW, or this program "
                f"no longer times one frame per iteration. The `allocs` column "
                f"would be measuring a region nobody chose.")

    return loop, counts.get("loop_free", 0), total, counts.get("free", 0), counts


def agg(per_run, key):
    xs = [r[key] for r in per_run]
    return statistics.median(xs), min(xs), max(xs)


# ------------------------------------------------------------------ report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", default=os.path.join(REPO, "build", "gen2"),
                    help="prismio binary to build the .psm ports with")
    ap.add_argument("--runs", type=int, default=20,
                    help="timing runs per binary (the brief asks for >= 20)")
    ap.add_argument("--only", choices=PROGRAMS, action="append")
    ap.add_argument("--skip-build", action="store_true")
    ap.add_argument("--with-swift", action="store_true",
                    help="include the Swift ports (off by default; the dev loop "
                         "compares against Rust, and swiftc dominates a run)")
    ap.add_argument("--json", default=os.path.join(HERE, "results.json"))
    args = ap.parse_args()

    global ACTIVE_VARIANTS
    if args.with_swift:
        ACTIVE_VARIANTS = list(VARIANTS)

    compiler = os.path.abspath(args.compiler)
    if not args.skip_build and not os.path.exists(compiler):
        sys.exit(f"no prismio compiler at {compiler} -- pass --compiler")

    progs = args.only or PROGRAMS
    tmp = os.path.join(OUT, "_stdout.txt")
    alloc_tmp = os.path.join(OUT, "_allocs.txt")
    dylib = os.path.join(OUT, DYLIB)

    if args.skip_build:
        compile_ms = {}
        os.makedirs(OUT, exist_ok=True)
    else:
        print("Building (cold compile time is the median of 3):")
        compile_ms = build_all(compiler)

    results = {}
    for prog in progs:
        built = [(p, k, lab, lang, exe) for p, k, lab, lang, exe, _ in targets(compiler)
                 if p == prog and os.path.exists(exe)]
        if not built:
            continue

        # Assert first, measure second. Variants that compute different things
        # measure nothing, and that has to fail loudly rather than print a table.
        reference = None
        for _, key, label, _, exe in built:
            _, checks = measure(exe, 1, tmp)
            if reference is None:
                reference = (label, checks)
            elif checks != reference[1]:
                sys.exit(f"{prog}: {label} disagrees with {reference[0]}\n"
                         f"  {reference[0]}: {reference[1]}\n  {label}: {checks}")

        print(f"\n{'=' * 108}\n{prog}  --  {'; '.join(reference[1])}"
              f"\n{'=' * 108}")
        print(f"{'variant':<17}{'p50 us':>10}{'p99 us':>10}{'p999 us':>10}"
              f"{'loop ms':>10}{'wall ms':>10}{'RSS MB':>9}"
              f"{'allocs':>12}{'frees':>12}{'exe KB':>9}{'cc ms':>9}")
        print("-" * 108)

        rows = []
        for _, key, label, lang, exe in built:
            per_run, checks = measure(exe, args.runs, tmp)
            allocs, frees, tot_allocs, tot_frees, raw = measure_allocs(
                exe, dylib, tmp, alloc_tmp, per_run[0]["frames"], label)
            loop_med = agg(per_run, "loop_ms")[0]
            row = {
                "variant": key, "label": label, "language": lang,
                "frames": per_run[0]["frames"],
                "p50_us": agg(per_run, "p50_us"),
                "p99_us": agg(per_run, "p99_us"),
                "p999_us": agg(per_run, "p999_us"),
                "loop_ms": agg(per_run, "loop_ms"),
                "wall_ms": agg(per_run, "wall_ms"),
                "rss_mb": agg(per_run, "rss_mb"),
                "allocs": allocs, "frees": frees, "alloc_raw": raw,
                "process_allocs": tot_allocs, "process_frees": tot_frees,
                "allocs_per_s": allocs / (loop_med / 1000.0) if loop_med else 0.0,
                "frees_per_s": frees / (loop_med / 1000.0) if loop_med else 0.0,
                "exe_bytes": os.path.getsize(exe),
                "compile_ms": compile_ms.get((prog, key)),
                "checksums": checks,
                "runs": args.runs,
            }
            rows.append(row)
            cc = f"{row['compile_ms']:8.0f}" if row["compile_ms"] else "       -"
            print(f"{label:<17}{row['p50_us'][0]:10.2f}{row['p99_us'][0]:10.2f}"
                  f"{row['p999_us'][0]:10.2f}{row['loop_ms'][0]:10.1f}"
                  f"{row['wall_ms'][0]:10.1f}{row['rss_mb'][0]:9.1f}"
                  f"{allocs:12,}{frees:12,}{row['exe_bytes'] / 1024:9.0f}{cc}")

        # Relative to idiomatic Rust: the brief's predictions are stated against
        # it, so it is the normalisation point rather than Prismio.
        base = next((r for r in rows if r["variant"] == "rust_idiomatic"), None)
        if base:
            print(f"\n{'rel. to Rust idiomatic':<17}{'p50':>10}{'p99':>10}{'p999':>10}"
                  f"{'loop':>10}{'':>10}{'RSS':>9}{'allocs':>12}{'frees':>12}")
            for r in rows:
                def rel(k):
                    b = base[k][0]
                    return f"{r[k][0] / b:9.2f}x" if b else "        -"
                ra = f"{r['allocs'] / base['allocs']:11.2f}x" if base["allocs"] else "          -"
                rf = f"{r['frees'] / base['frees']:11.2f}x" if base["frees"] else "          -"
                print(f"{r['label']:<17}{rel('p50_us'):>10}{rel('p99_us'):>10}"
                      f"{rel('p999_us'):>10}{rel('loop_ms'):>10}{'':>10}"
                      f"{rel('rss_mb'):>9}{ra:>12}{rf:>12}")

        # The process totals, kept visible rather than dropped. `allocs` above is
        # the timed region; the difference is setup and the frame_ns dump, and a
        # reader comparing against a pre-2026-08-16 table needs to see both to
        # know which number moved.
        print(f"\n{'whole process (allocs/frees)':<17}" + "  ".join(
            f"{r['label']} {r['process_allocs']:,}/{r['process_frees']:,}" for r in rows))
        print(f"\nspread over {args.runs} runs (min-max): " + ", ".join(
            f"{r['label']} loop {r['loop_ms'][1]:.1f}-{r['loop_ms'][2]:.1f}ms" for r in rows))
        print(f"frame samples per run: {rows[0]['frames']:,}"
              f"  (p999 is the top {max(1, rows[0]['frames'] // 1000)} of them)")
        results[prog] = rows

    meta = {
        "platform": sys.platform,
        "runs": args.runs,
        "compiler": compiler,
        "rustc": sh(["rustc", "--version"]).stdout.strip(),
        # Recorded only when Swift actually ran, so a reader cannot mistake a
        # Rust-only run for one where Swift was measured and tied.
        "swiftc": (sh(["swiftc", "--version"]).stdout.strip().splitlines()[0]
                   if args.with_swift else None),
        "clang": sh(["clang", "--version"]).stdout.strip().splitlines()[0],
        "when": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    with open(args.json, "w") as fh:
        json.dump({"meta": meta, "results": results}, fh, indent=2)
    print(f"\nwrote {args.json}")


if __name__ == "__main__":
    main()
