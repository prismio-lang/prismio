#!/usr/bin/env python3
"""Compare existing map APIs and single-probe updates in isolated benchmark copies."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
spec = importlib.util.spec_from_file_location(
    "probe_measurement", HERE.parent / "map-probe-2026-09-05/measure.py")
sampling = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sampling)


def run(command, env):
    return subprocess.run(list(map(str, command)), cwd=REPO, env=env,
                          capture_output=True, text=True, check=True, timeout=120).stdout


def replace_once(path, old, new):
    text = path.read_text()
    if text.count(old) != 1:
        raise ValueError(f"expected one occurrence of {old!r} in {path}")
    path.write_text(text.replace(old, new))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=15)
    parser.add_argument("--out", type=Path, default=REPO / "build/map-update-measure")
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
    # Use one snapshot for all arms. Compiler and standard library must not
    # change between builds in the shared compiler-development working tree.
    snapshot = out / "snapshot"
    for source in ("std", "benchmarks/prismio", "benchmarks/cpp", "benchmarks/rust"):
        shutil.copytree(REPO / source, snapshot / source, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns(".prismio-*"))
    executables = {}
    for arm in ("before", "after_legacy", "after_update"):
        directory = out / arm
        shutil.copytree(snapshot / "benchmarks/prismio", directory, dirs_exist_ok=True)
        shutil.copytree(snapshot / "std", directory / "std", dirs_exist_ok=True)
        if arm == "before":
            shutil.copy2(HERE / "map-before.psm", directory / "std/map.psm")
        if arm == "after_update":
            replace_once(directory / "data_structures.psm",
                         "mapSet(map, k, mapGetOr(map, k, 0) + 1)",
                         "mapUpdate(map, k, |value: Int| value + 1)")
        exe = directory / "suite"
        run([compiler, "build", directory / "suite.psm", "-o", exe], env)
        executables[arm] = exe
    for arm in ("cpp_double", "cpp_single"):
        directory = out / arm
        shutil.copytree(snapshot / "benchmarks/cpp", directory, dirs_exist_ok=True)
        if arm == "cpp_single":
            replace_once(directory / "data_structures.cpp",
                         "map[i] = map.at(i) + 1;", "++map.at(i);")
        exe = directory / "suite"
        run(["clang++", "-O3", "-std=c++20", "-pthread",
             *(directory / name for name in ("suite.cpp", "algorithms.cpp", "data_structures.cpp",
                                            "compute.cpp", "memory.cpp", "io.cpp")),
             "-o", exe], env)
        executables[arm] = exe
    rust = out / "rust_single"
    shutil.copytree(snapshot / "benchmarks/rust", rust, dirs_exist_ok=True)
    run(["rustc", "-C", "opt-level=3", "--edition=2021", rust / "suite.rs",
         "-o", rust / "suite"], env)
    executables["rust_single"] = rust / "suite"
    report = {"runs": args.runs, "compiler_sha256": digest(compiler),
              "before_map_sha256": digest(HERE / "map-before.psm"),
              "after_map_sha256": digest(snapshot / "std/map.psm"),
              "key_sha256": digest(snapshot / "std/key.psm"),
              "toolchains": {tool: run([tool, "--version"], env).splitlines()[0]
                             for tool in ("clang++", "rustc")},
              "benchmarks": {}, "checksums": {}}
    with tempfile.TemporaryDirectory(prefix="prismio-update-fixture-") as tmp:
        fixture = Path(tmp) / "input"
        fixture.write_bytes(b"alpha beta gamma delta 0123456789\n" * 8192)
        # No compile or test jobs should run during this section.
        for name in ("key_value_update", "hashmap_insert_lookup"):
            arms = {**executables, "before_repeat": executables["before"]}
            commands = {arm: [exe, name, fixture, Path(tmp) / f"{arm}.out"]
                        for arm, exe in arms.items()}
            result = sampling.measure(commands, env, args.runs)
            report["benchmarks"][name] = result
            print(name, result["median_ns"], flush=True)
        manifest = json.loads((REPO / "benchmarks/benchmarks.json").read_text())
        for item in manifest["benchmarks"]:
            if item["status"] != "implemented":
                continue
            name = item["name"]
            values = {}
            for arm, exe in executables.items():
                output = run([exe, name, fixture, Path(tmp) / f"{arm}.out"], env)
                values[arm] = int(next(line.split(": ", 1)[1] for line in output.splitlines()
                                       if line.startswith("result: ")))
            if len(set(values.values())) != 1:
                raise ValueError(f"checksum mismatch: {name}: {values}")
            report["checksums"][name] = values
    (out / "measurements.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"All {len(report['checksums'])} benchmark checksums match.", flush=True)


if __name__ == "__main__":
    main()
