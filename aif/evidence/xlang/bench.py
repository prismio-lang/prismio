#!/usr/bin/env python3
"""Cross-language measurement for the AIF corpus: Prismio vs Rust vs Swift.

    python3 aif/evidence/xlang/bench.py --compiler build/gen2
    python3 aif/evidence/xlang/bench.py --compiler build/gen2 --only g2 --runs 40

Everything is one command on purpose: build, assert the variants agree, measure,
report. A later session re-runs this and compares JSON.

WHAT IS MEASURED, AND HOW

  frame time p50/p99/p999   In-process. Every program times each frame with
                            clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) -- the same
                            call in all three languages -- and prints one
                            `frame_ns` line per frame after the loop. This is the
                            lead metric: process wall time hides the tail, and the
                            tail is what a frame budget is made of.

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

  exe size                  Stat of the linked binary.

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

PROGRAMS = ["g1", "g2", "g3", "g4", "g5", "g6"]

# (variant key, label, language). Order is the report order.
#
# rust-boxed is a diagnostic, not one of the three requested Rust variants: it
# holds Prismio's representation fixed (a vector of pointers to individually
# heap-allocated records) and lets rustc emit the code, which splits a Prismio
# vs Rust gap into "the representation" and "everything else". It exists only
# for g1 and g2, the two programs where that split carries the argument.
VARIANTS = [
    ("prismio_opt",   "Prismio +opt",    "prismio_opt"),
    ("prismio",       "Prismio shipped", "prismio"),
    ("rust_idiomatic", "Rust idiomatic",  "rust"),
    ("rust_arena",    "Rust arena",      "rust"),
    ("rust_tuned",    "Rust hand-tuned", "rust"),
    ("rust_boxed",    "Rust boxed [dx]", "rust"),
    ("swift",         "Swift idiomatic", "swift"),
]


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


def runtime_objects(opt):
    """The two runtime sources a user build links, per prismio_toolchain_files[].

    `opt` is the -O level. `prismio build` passes none, i.e. -O0
    (build_driver.c:638); the +opt variant passes -O2.
    """
    objs = []
    for c in ("lang_runtime.c", "program_support.c"):
        objs.append(os.path.join(OUT, f"{c[:-2]}{opt}.o"))
    return objs


def targets(compiler):
    """Every (program, variant) that has a source, with its build command(s).

    A build is a list of argv lists, because the +opt variant is four steps
    rather than one and its cold compile time has to cover all of them.
    """
    out = []
    rust = rust_sources()
    for prog in PROGRAMS:
        for key, label, lang in VARIANTS:
            exe = os.path.join(OUT, f"{prog}_{key}")
            if lang == "prismio":
                src = os.path.join(HERE, "prismio", f"{prog}.psm")
                cmd = [compiler, "build", src, "-o", exe]
            elif lang == "prismio_opt":
                # What `prismio build` would produce if build_driver.c ran an
                # optimiser: the compiler's own IR, unmodified, through the LLVM
                # middle-end, linked against a runtime compiled at -O2.
                #
                # A harness-side reconstruction, not the compiler's code path --
                # so it is labelled "+opt" and never plain "Prismio". It
                # reproduces `prismio build` to within 1.6% when the two -O
                # flags are removed, which is what says it is faithful.
                src = os.path.join(HERE, "prismio", f"{prog}.psm")
                ll = os.path.join(OUT, f"{prog}.opt.ll")
                bc = os.path.join(OUT, f"{prog}.opt.bc")
                obj = os.path.join(OUT, f"{prog}.opt.o")
                # The runtime is recompiled here, per program, because that is
                # what `prismio build` does when no runtime.lib is installed
                # (build_from_toolchain_sources). Reusing prebuilt objects would
                # make this variant's cold compile time incomparable to the
                # shipped one -- and at -O2 the runtime is the expensive part,
                # so the omission flatters exactly the number in question.
                rt = []
                steps = [[compiler, "build", src, "-o", ll],
                         ["opt", "-O2", ll, "-o", bc],
                         ["llc", bc, "-filetype=obj", "-o", obj]]
                for c in ("lang_runtime.c", "program_support.c"):
                    o = os.path.join(OUT, f"{prog}.{c[:-2]}.O2.o")
                    steps.append(["clang", "-O2", "-Wno-deprecated-declarations",
                                  "-c", os.path.join(REPO, "runtime", c), "-o", o])
                    rt.append(o)
                steps.append(["clang", obj] + rt + ["-o", exe])
                out.append((prog, key, label, lang, exe, steps))
                continue
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

    # The runtime half, at both -O levels. Compiled once and outside the timed
    # region: `prismio build` links a runtime it has already built, so folding
    # its compile time into every program's would be counting it six times.
    for lvl in ("-O0", "-O2"):
        for c, obj in zip(("lang_runtime.c", "program_support.c"), runtime_objects(lvl)):
            r = sh(["clang", lvl, "-Wno-deprecated-declarations", "-c",
                    os.path.join(REPO, "runtime", c), "-o", obj])
            if r.returncode != 0:
                sys.exit(f"runtime build failed ({c} {lvl}):\n{r.stderr}")

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


def measure_allocs(exe, dylib, tmp, alloc_tmp):
    run_once(exe, tmp, preload=dylib, alloc_out=alloc_tmp)
    counts = {}
    with open(alloc_tmp) as fh:
        for line in fh:
            k, v = line.split()
            counts[k] = int(v)
    allocs = counts.get("malloc", 0) + counts.get("calloc", 0) + counts.get("realloc", 0)
    return allocs, counts.get("free", 0), counts


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
    ap.add_argument("--json", default=os.path.join(HERE, "results.json"))
    args = ap.parse_args()

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
            allocs, frees, raw = measure_allocs(exe, dylib, tmp, alloc_tmp)
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
        "swiftc": sh(["swiftc", "--version"]).stdout.strip().splitlines()[0],
        "clang": sh(["clang", "--version"]).stdout.strip().splitlines()[0],
        "when": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    with open(args.json, "w") as fh:
        json.dump({"meta": meta, "results": results}, fh, indent=2)
    print(f"\nwrote {args.json}")


if __name__ == "__main__":
    main()
