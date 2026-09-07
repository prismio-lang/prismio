#!/usr/bin/env python3
"""Build, validate, and measure the Prismio/C++/Rust benchmark matrix."""

import argparse
from datetime import datetime, timezone
from html import escape
import json
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
import webbrowser

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
MANIFEST = HERE / "benchmarks.json"
BUILD = HERE / "build"
RESULTS = HERE / "results"
TEMPLATES = HERE / "templates"
LANGUAGES = ("prismio", "cpp", "rust")
LANGUAGE_LABELS = {"prismio": "Prismio", "cpp": "C++", "rust": "Rust"}
CPP_SOURCES = tuple(HERE / "cpp" / name for name in (
    "suite.cpp",
    "algorithms.cpp",
    "data_structures.cpp",
    "compute.cpp",
    "memory.cpp",
    "io.cpp",
    "adversarial.cpp",
))


class Progress:
    def __init__(self, total):
        self.total = max(total, 1)
        self.current = 0
        self.interactive = sys.stdout.isatty()
        self.width = 0

    def show(self, label):
        if not self.interactive:
            return
        columns = 24
        filled = min(columns, int(columns * self.current / self.total))
        bar = "█" * filled + "░" * (columns - filled)
        line = "  [{}] {:3d}%  {}".format(bar, int(100 * self.current / self.total), label)
        self.width = max(self.width, len(line))
        sys.stdout.write("\r" + line.ljust(self.width))
        sys.stdout.flush()

    def advance(self, label):
        self.current += 1
        self.show(label)

    def finish(self):
        if self.interactive:
            sys.stdout.write("\r" + (" " * self.width) + "\r")
            sys.stdout.flush()


def command_text(command):
    return " ".join(str(part) for part in command)


def run_command(command, *, env=None):
    return subprocess.run(command, cwd=REPO, env=env, capture_output=True, text=True)


def llvm_bin_from(args):
    if args.llvm_bin:
        return Path(args.llvm_bin).resolve()
    homebrew = Path("/opt/homebrew/opt/llvm/bin")
    return homebrew if homebrew.is_dir() else None


def build_all(args, progress):
    BUILD.mkdir(parents=True, exist_ok=True)
    llvm_bin = llvm_bin_from(args)
    env = os.environ.copy()
    if llvm_bin:
        env["PATH"] = str(llvm_bin) + os.pathsep + env.get("PATH", "")
    cxx = str(llvm_bin / "clang++") if llvm_bin and (llvm_bin / "clang++").exists() else "clang++"
    commands = {
        "prismio": [str(Path(args.compiler).resolve()), "build", str(HERE / "prismio/suite.psm"), "-o", str(BUILD / "prismio-suite")],
        "cpp": [cxx, "-O3", "-std=c++20", "-pthread", *(str(path) for path in CPP_SOURCES),
                "-o", str(BUILD / "cpp-suite")],
        "rust": ["rustc", "-C", "opt-level=3", "--edition=2021", str(HERE / "rust/suite.rs"), "-o", str(BUILD / "rust-suite")],
    }
    elapsed = {}
    for language in LANGUAGES:
        progress.show("Building " + LANGUAGE_LABELS[language])
        started = time.perf_counter_ns()
        result = run_command(commands[language], env=env)
        elapsed[language] = time.perf_counter_ns() - started
        if result.returncode:
            sys.exit("build failed for {}:\n{}\n{}\n{}".format(
                language, command_text(commands[language]), result.stdout, result.stderr))
        progress.advance("Built {}".format(LANGUAGE_LABELS[language]))
    return commands, elapsed


def parse_output(language, benchmark, output):
    fields = {}
    for line in output.splitlines():
        if ": " in line:
            key, value = line.split(": ", 1)
            if key in ("result", "elapsed_ns"):
                fields[key] = int(value)
    if set(fields) != {"result", "elapsed_ns"}:
        raise RuntimeError("{} {} emitted invalid output:\n{}".format(language, benchmark, output))
    return fields


def make_fixture(directory):
    path = directory / "input.txt"
    part = b"alpha beta gamma delta 0123456789\n"
    with path.open("wb") as output:
        for _ in range(8192):
            output.write(part)
    return path


def execute(executable, benchmark, input_path, output_path):
    command = [str(executable), benchmark, str(input_path), str(output_path)]
    started = time.perf_counter_ns()
    result = run_command(command)
    wall_ns = time.perf_counter_ns() - started
    if result.returncode:
        raise RuntimeError("run failed:\n{}\n{}\n{}".format(command_text(command), result.stdout, result.stderr))
    fields = parse_output(executable.name, benchmark, result.stdout)
    fields["wall_ns"] = wall_ns
    return fields


def select_benchmarks(manifest, names):
    requested = set(names or [])
    known = {item["name"] for item in manifest["benchmarks"]}
    unknown = sorted(requested - known)
    if unknown:
        sys.exit("unknown benchmark(s): " + ", ".join(unknown))
    return [item for item in manifest["benchmarks"] if not requested or item["name"] in requested]


def measured_benchmarks(report):
    return [item for item in report["benchmarks"] if item["status"] == "implemented"]


def write_html_report(report, path, raw_data_name):
    embedded = json.dumps(report, separators=(",", ":")).replace("</", "<\/")
    template_html = (TEMPLATES / "report.html").read_text()
    rendered = template_html.replace("__REPORT_DATA__", embedded).replace("__RAW_FILE__", escape(raw_data_name))
    path.write_text(rendered)
    css_src = TEMPLATES / "report.css"
    if css_src.is_file():
        shutil.copy2(css_src, path.parent / "report.css")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", default=os.environ.get("PRISMIO"), help="Prismio compiler executable (or set PRISMIO)")
    parser.add_argument("--llvm-bin", help="LLVM bin directory prepended to PATH for Prismio and C++ builds")
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--only", action="append", metavar="NAME", help="run one benchmark; repeat the option for more")
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--output", type=Path, default=RESULTS / "results.json")
    parser.add_argument("--open", action="store_true", help="open the generated HTML report in the default browser")
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text())
    selected = select_benchmarks(manifest, args.only)
    if args.list:
        for item in selected:
            print("{category:16} {status:11} {name}".format(**item))
        return
    if args.runs < 1:
        sys.exit("--runs must be positive")
    if not args.skip_build and not args.compiler:
        sys.exit("--compiler is required (or set PRISMIO)")

    build_steps = 0 if args.skip_build else len(LANGUAGES)
    workload_steps = sum(1 if item["status"] == "unsupported" else args.runs * len(LANGUAGES)
                         for item in selected)
    artifact_steps = 2
    progress = Progress(build_steps + workload_steps + artifact_steps)
    progress.show("Preparing benchmark suite")

    build_commands = None
    compile_ns = None
    if not args.skip_build:
        build_commands, compile_ns = build_all(args, progress)
    executables = {language: BUILD / (language + "-suite") for language in LANGUAGES}
    missing = [str(path) for path in executables.values() if not path.exists()]
    if missing:
        sys.exit("missing built executable(s): " + ", ".join(missing))

    report = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "runs": args.runs,
        "build_commands": {key: command_text(value) for key, value in (build_commands or {}).items()},
        "compile_ns": compile_ns,
        "benchmarks": [],
    }
    with tempfile.TemporaryDirectory(prefix="prismio-bench-") as temp_name:
        temp = Path(temp_name)
        fixture = make_fixture(temp)
        for item in selected:
            if item["status"] == "unsupported":
                report["benchmarks"].append(dict(item))
                progress.advance("Skipped {} (unsupported)".format(item["name"]))
                continue
            samples = {language: [] for language in LANGUAGES}
            expected = None
            for run_index in range(args.runs):
                for language in LANGUAGES:
                    progress.show("{} · run {}/{} · {}".format(
                        item["name"], run_index + 1, args.runs, LANGUAGE_LABELS[language]))
                    output_path = temp / "{}-{}-{}.txt".format(item["name"], language, run_index)
                    fields = execute(executables[language], item["name"], fixture, output_path)
                    if expected is None:
                        expected = fields["result"]
                    elif fields["result"] != expected:
                        raise RuntimeError("checksum mismatch for {}: expected {}, {} returned {}".format(
                            item["name"], expected, language, fields["result"]))
                    samples[language].append(fields)
                    progress.advance("{} · run {}/{} · {}".format(
                        item["name"], run_index + 1, args.runs, LANGUAGE_LABELS[language]))
            measured = dict(item)
            measured["result"] = expected
            measured["languages"] = {}
            for language in LANGUAGES:
                measured["languages"][language] = {
                    "elapsed_ns_median": int(statistics.median(sample["elapsed_ns"] for sample in samples[language])),
                    "wall_ns_median": int(statistics.median(sample["wall_ns"] for sample in samples[language])),
                    "elapsed_ns_samples": [sample["elapsed_ns"] for sample in samples[language]],
                }
            report["benchmarks"].append(measured)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    html_path = args.output.parent / "report.html"
    report["artifacts"] = {
        "html_report": str(html_path),
        "raw_data": str(args.output),
    }
    progress.show("Writing JSON results")
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    progress.advance("Wrote JSON results")
    progress.show("Rendering HTML report")
    write_html_report(report, html_path, args.output.name)
    progress.advance("Complete")
    progress.finish()

    implemented = len(measured_benchmarks(report))
    unsupported = sum(item["status"] == "unsupported" for item in report["benchmarks"])
    sample_text = "1 run" if args.runs == 1 else "{} runs".format(args.runs)
    print("Completed {} benchmarks ({} unsupported) · {}".format(
        implemented, unsupported, sample_text))
    print("Report   " + str(html_path))
    print("Data     " + str(args.output))
    if args.open:
        webbrowser.open(html_path.resolve().as_uri())


if __name__ == "__main__":
    main()
