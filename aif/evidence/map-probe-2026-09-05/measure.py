#!/usr/bin/env python3
"""Reproduce map A/B measurements without replacing the working std library.

Use an explicitly named compiler (not the global forwarding launcher). Outputs
go under build/map-opt-measure; the maintained bench report is left intact.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
BASELINE = "43107cff86c140fbf130c27211379d775d25c727"


def run(command, env, timeout=120):
    return subprocess.run(list(map(str, command)), cwd=REPO, env=env,
                          capture_output=True, text=True, check=True,
                          timeout=timeout).stdout


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def measure(commands, env, runs):
    samples = {arm: [] for arm in commands}
    checksums = set()
    arms = list(commands)
    for iteration in range(runs + 2):
        order = arms[iteration % len(arms):] + arms[:iteration % len(arms)]
        if iteration % 2:
            order.reverse()
        for arm in order:
            output = run(commands[arm], env, timeout=30)
            fields = dict(line.split(": ", 1) for line in output.splitlines()
                          if line.startswith(("result: ", "elapsed_ns: ")))
            checksums.add(int(fields["result"]))
            elapsed = int(fields["elapsed_ns"])
            if elapsed < 0:
                raise ValueError("elapsed_ns overflow")
            if iteration >= 2:
                samples[arm].append(elapsed)
    if len(checksums) != 1:
        raise ValueError(f"checksum mismatch: {checksums}")
    return {"checksum": checksums.pop(), "samples_ns": samples,
            "median_ns": {arm: statistics.median(values)
                          for arm, values in samples.items()}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=11)
    parser.add_argument("--out", type=Path, default=REPO / "build/map-opt-measure")
    args = parser.parse_args()
    if args.runs < 1:
        parser.error("--runs must be positive")
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    compiler = out / "compiler"
    shutil.copy2(args.compiler.resolve(), compiler)
    env = os.environ.copy()
    llvm = Path("/opt/homebrew/opt/llvm/bin")
    if llvm.is_dir():
        env["PATH"] = str(llvm) + os.pathsep + env.get("PATH", "")
    report = {"baseline_ref": BASELINE, "platform": platform.platform(),
              "compiler_sha256": digest(compiler), "runs": args.runs,
              "source_sha256": {}, "benchmarks": {}, "supplemental": {}}
    snapshot = out / "source_snapshot"
    shutil.copytree(REPO / "std", snapshot / "std", dirs_exist_ok=True)
    shutil.copytree(REPO / "benchmarks/prismio", snapshot / "prismio", dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns(".prismio-*"))
    # Both arms use identical benchmark sources and identical compiler/runtime.
    # Only map.psm/key.psm differ. Snapshot the rest of std as well so concurrent
    # library edits cannot silently change an arm during its build.
    for arm in ("baseline", "candidate", "map_only"):
        directory = out / arm
        directory.mkdir(exist_ok=True)
        shutil.copytree(snapshot / "prismio", directory, dirs_exist_ok=True)
        shutil.copy2(HERE / "probe.psm", directory / "probe.psm")
        shutil.copytree(snapshot / "std", directory / "std", dirs_exist_ok=True)
        for name in ("map.psm", "key.psm"):
            if arm == "baseline" or (arm == "map_only" and name == "key.psm"):
                content = run(["git", "show", f"{BASELINE}:std/{name}"], env)
            else:
                content = (snapshot / "std" / name).read_text()
            path = directory / "std" / name
            path.write_text(content)
            report["source_sha256"][f"{arm}/{name}"] = digest(path)
        for source in ("suite", "probe"):
            if arm == "map_only" and source == "suite":
                continue
            run([compiler, "build", directory / f"{source}.psm", "-o",
                 directory / source], env)
    cpp = REPO / "benchmarks/cpp"
    run(["clang++", "-O3", "-std=c++20", "-pthread",
         *(cpp / name for name in ("suite.cpp", "algorithms.cpp", "data_structures.cpp",
                                  "compute.cpp", "memory.cpp", "io.cpp")),
         "-o", out / "cpp-suite"], env)
    run(["rustc", "-C", "opt-level=3", "--edition=2021",
         REPO / "benchmarks/rust/suite.rs", "-o", out / "rust-suite"], env)
    report["toolchains"] = {tool: run([tool, "--version"], env).splitlines()[0]
                            for tool in ("clang++", "rustc")}
    # No compilation or other test jobs during the timed portion.
    with tempfile.TemporaryDirectory(prefix="prismio-map-input-") as tmp:
        fixture = Path(tmp) / "input.txt"
        fixture.write_bytes(b"alpha beta gamma delta 0123456789\n" * 8192)
        manifest = json.loads((REPO / "benchmarks/benchmarks.json").read_text())
        for item in manifest["benchmarks"]:
            if item["status"] != "implemented":
                continue
            name = item["name"]
            executables = {"baseline": out / "baseline/suite",
                           "baseline_repeat": out / "baseline/suite",
                           "candidate": out / "candidate/suite",
                           "cpp": out / "cpp-suite", "rust": out / "rust-suite"}
            commands = {arm: [exe, name, fixture, Path(tmp) / f"{arm}.out"]
                        for arm, exe in executables.items()}
            result = measure(commands, env, args.runs)
            report["benchmarks"][name] = result
            print(name, result["median_ns"], flush=True)
        for mode, sizes in (("int", (128, 2048, 8192, 32768, 131072)),
                            ("string", (128, 2048, 8192)),
                            ("wide", (1024, 4096, 8192))):
            for n in sizes:
                arms = ("baseline", "map_only", "candidate") if mode == "wide" else ("baseline", "candidate")
                commands = {arm: [out / arm / "probe", mode, n] for arm in arms}
                result = measure(commands, env, args.runs)
                report["supplemental"][f"{mode}/{n}"] = result
                print(mode, n, result["median_ns"], flush=True)
    (out / "measurements.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
