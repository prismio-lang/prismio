#!/usr/bin/env python3
"""Build, validate, and measure the Prismio/C++/Rust benchmark matrix."""

import argparse
from datetime import datetime, timezone
import hashlib
from html import escape
import json
import math
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

# What a cached arm is keyed on. Wider than the compiled set on purpose: a header
# is not on the command line and changing one changes the binary, and `rustc` is
# handed one file that declares the rest as modules.
CACHED_INPUTS = {
    "cpp": ("cpp/*.cpp", "cpp/*.hpp"),
    "rust": ("rust/*.rs",),
}


# Within this much of the other arm a result is parity, not a win or a loss:
# the suite's run-to-run floor, measured alternating identical binaries, is
# about 4% (aif/evidence, and code layout alone moves numeric kernels that far).
PARITY = 0.04


def color_enabled(stream):
    """The compiler's rule (runtime/diagnostics.c): NO_COLOR and TERM=dumb win,
    FORCE_COLOR/CLICOLOR_FORCE override a pipe, otherwise ask the terminal."""
    def flag(name):
        value = os.environ.get(name, "")
        return value not in ("", "0")
    if flag("NO_COLOR"):
        return False
    if flag("FORCE_COLOR") or flag("CLICOLOR_FORCE"):
        return True
    if os.environ.get("TERM") == "dumb":
        return False
    return stream.isatty()


class Style:
    """SGR roles, empty strings when stdout is not showing colour, so every
    format string can carry its styling and still print plain text to a log."""

    def __init__(self, enabled):
        if enabled and os.name == "nt":
            os.system("")   # switches a Windows console into VT processing
        codes = {
            "reset": "0", "bold": "1", "dim": "2",
            "red": "1;31", "green": "1;32", "yellow": "1;33", "blue": "1;34", "cyan": "1;36",
        }
        for name, code in codes.items():
            setattr(self, name, "\033[{}m".format(code) if enabled else "")


STYLE = Style(color_enabled(sys.stdout))


def format_ns(ns):
    """A duration in the unit that keeps three significant digits readable."""
    if ns >= 1e9:
        return "{:.2f} s".format(ns / 1e9)
    if ns >= 1e6:
        return "{:.1f} ms".format(ns / 1e6)
    if ns >= 1e3:
        return "{:.1f} µs".format(ns / 1e3)
    return "{:d} ns".format(int(ns))


def format_seconds(seconds):
    seconds = int(round(seconds))
    if seconds < 60:
        return "{}s".format(seconds)
    return "{}m{:02d}s".format(seconds // 60, seconds % 60)


def ratio_cell(ratio, width=8):
    """Prismio's time over the other arm's: below 1 is Prismio ahead. Padded
    before it is coloured, so escape codes never disturb the columns."""
    text = "{:.2f}×".format(ratio).rjust(width)
    if ratio <= 1 - PARITY:
        return STYLE.green + text + STYLE.reset
    if ratio < 1 + PARITY:
        return text
    if ratio < 1.25:
        return STYLE.yellow + text + STYLE.reset
    return STYLE.red + text + STYLE.reset


class Progress:
    """A bar rewritten in place on a terminal, with lines printed above it.

    Everything the run reports goes through `line`, which clears the bar, prints,
    and redraws it -- so a result row never lands on the end of the bar. Piped,
    there is no bar and `line` is a plain print.
    """

    def __init__(self, total):
        self.total = max(total, 1)
        self.current = 0
        self.interactive = sys.stdout.isatty()
        self.width = 0
        self.label = ""
        self.started = time.monotonic()

    def _clear(self):
        if self.interactive and self.width:
            sys.stdout.write("\r" + (" " * self.width) + "\r")

    def show(self, label):
        self.label = label
        if not self.interactive:
            return
        columns = 28
        fraction = self.current / self.total
        filled = min(columns, int(columns * fraction))
        bar = STYLE.cyan + "━" * filled + STYLE.reset + STYLE.dim + "━" * (columns - filled) + STYLE.reset
        eta = ""
        elapsed = time.monotonic() - self.started
        if self.current and fraction < 1:
            eta = "  ETA " + format_seconds(elapsed / self.current * (self.total - self.current))
        plain = "  {} {:3d}%{}  {}".format("━" * columns, int(100 * fraction), eta, label)
        line = "  {} {:3d}%{}{}  {}".format(bar, int(100 * fraction), STYLE.dim, eta + STYLE.reset, label)
        self._clear()
        self.width = max(self.width, len(plain))
        sys.stdout.write("\r" + line)
        sys.stdout.flush()

    def advance(self, label):
        self.current += 1
        self.show(label)

    def line(self, text=""):
        self._clear()
        sys.stdout.write(text + "\n")
        if self.interactive and self.label:
            self.show(self.label)
        sys.stdout.flush()

    def finish(self):
        """Removes the bar for good: lines printed after this -- the summary --
        must not bring it back."""
        self._clear()
        self.width = 0
        self.label = ""
        sys.stdout.flush()


def status(progress, verb, text, detail=""):
    """A cargo-shaped status line: the verb right-aligned in bold green."""
    tail = "  " + STYLE.dim + detail + STYLE.reset if detail else ""
    progress.line("{}{:>12}{} {}{}".format(STYLE.green, verb, STYLE.reset, text, tail))


def command_text(command):
    return " ".join(str(part) for part in command)


def run_command(command, *, env=None):
    return subprocess.run(command, cwd=REPO, env=env, capture_output=True, text=True)


def llvm_bin_from(args):
    if args.llvm_bin:
        return Path(args.llvm_bin).resolve()
    homebrew = Path("/opt/homebrew/opt/llvm/bin")
    return homebrew if homebrew.is_dir() else None


def toolchain_version(command, env):
    """What the arm's compiler calls itself, so an upgrade invalidates the cache.

    A `--version` costs milliseconds against a full -O3 rebuild, and without it a
    Homebrew LLVM bump would be measured against a binary the previous one built.
    """
    probe = subprocess.run([command[0], "--version"], cwd=REPO, env=env,
                           capture_output=True, text=True)
    return (probe.stdout or "") + (probe.stderr or "")


def build_key(language, command, env):
    """Everything that decides the bytes of an arm's binary."""
    digest = hashlib.sha256()
    digest.update(command_text(command).encode("utf-8"))
    digest.update(b"\0")
    digest.update(toolchain_version(command, env).encode("utf-8"))
    for pattern in CACHED_INPUTS[language]:
        for path in sorted(HERE.glob(pattern)):
            digest.update(path.name.encode("utf-8"))
            digest.update(b"\0")
            digest.update(path.read_bytes())
    return digest.hexdigest()


def read_stamp(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def build_all(args, progress):
    BUILD.mkdir(parents=True, exist_ok=True)
    llvm_bin = llvm_bin_from(args)
    env = os.environ.copy()
    if llvm_bin:
        env["PATH"] = str(llvm_bin) + os.pathsep + env.get("PATH", "")
    # `--compiler` names the arm being measured, and a compiler whose file is
    # called `prismio` is a launcher: run from the repository it discovers
    # `build.ums` and forwards to `toolchain.host`, so the numbers would come
    # from a different binary than the one named. Nothing in the output would
    # say so -- the checksums agree, because both compilers are correct.
    env["PRISMIO_INTERNAL_HOSTED"] = "1"
    cxx = str(llvm_bin / "clang++") if llvm_bin and (llvm_bin / "clang++").exists() else "clang++"
    commands = {
        "prismio": [str(Path(args.compiler).resolve()), "build", str(HERE / "prismio/suite.psm"), "-o", str(BUILD / "prismio-suite")],
        "cpp": [cxx, "-O3", "-std=c++20", "-pthread", *(str(path) for path in CPP_SOURCES),
                "-o", str(BUILD / "cpp-suite")],
        "rust": ["rustc", "-C", "opt-level=3", "--edition=2021", str(HERE / "rust/suite.rs"), "-o", str(BUILD / "rust-suite")],
    }
    elapsed = {}
    cached = []
    for language in LANGUAGES:
        binary = BUILD / (language + "-suite")
        stamp = BUILD / (language + "-suite.stamp")
        # **The Prismio arm is never cached.** It is the arm under development:
        # its sources are `benchmarks/prismio/`, but its *compiler* is the working
        # tree, and a rebuilt compiler with unchanged sources is exactly the case
        # this measures. The other two are fixed reference points whose toolchains
        # change on their own schedule, so a rebuild of those is pure waiting --
        # 3.5 s of clang++ -O3 and 1.5 s of rustc per run of the matrix.
        # The key is computed even under `--rebuild`, so that run leaves the
        # stamp describing what it actually built. Skipping it would make the
        # *next* run rebuild too, against a stamp naming an older binary.
        key = build_key(language, commands[language], env) if language in CACHED_INPUTS else None
        if key is not None and not args.rebuild:
            previous = read_stamp(stamp)
            if binary.exists() and previous.get("key") == key:
                elapsed[language] = previous.get("compile_ns", 0)
                cached.append(language)
                progress.advance("Cached {}".format(LANGUAGE_LABELS[language]))
                status(progress, "Cached", LANGUAGE_LABELS[language] + " suite",
                       "built earlier in " + format_ns(elapsed[language]))
                continue

        progress.show("Building " + LANGUAGE_LABELS[language])
        started = time.perf_counter_ns()
        result = run_command(commands[language], env=env)
        elapsed[language] = time.perf_counter_ns() - started
        if result.returncode:
            sys.exit("build failed for {}:\n{}\n{}\n{}".format(
                language, command_text(commands[language]), result.stdout, result.stderr))
        # Written after the build, so an interrupted or failed one leaves the
        # stamp naming the last binary that actually exists.
        if key is not None:
            stamp.write_text(json.dumps({"key": key, "compile_ns": elapsed[language]}))
        progress.advance("Built {}".format(LANGUAGE_LABELS[language]))
        status(progress, "Compiled", LANGUAGE_LABELS[language] + " suite", format_ns(elapsed[language]))
    return commands, elapsed, cached


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


def table_header(progress, name_width):
    cells = "    {:<{w}}  {:>10}  {:>10}  {:>10}  {:>8}  {:>8}".format(
        "workload", "Prismio", "C++", "Rust", "vs C++", "vs Rust", w=name_width)
    progress.line()
    progress.line(STYLE.bold + cells + STYLE.reset)


def table_row(progress, measured, name_width):
    """One workload: each arm's median, the fastest in bold, and Prismio's ratio
    to each of the others."""
    times = {language: measured["languages"][language]["elapsed_ns_median"] for language in LANGUAGES}
    fastest = min(times.values())
    cells = []
    for language in LANGUAGES:
        text = format_ns(times[language]).rjust(10)
        cells.append(STYLE.bold + text + STYLE.reset if times[language] == fastest else text)
    ratios = [ratio_cell(times["prismio"] / max(times[other], 1)) for other in ("cpp", "rust")]
    progress.line("    {:<{w}}  {}  {}".format(measured["name"], "  ".join(cells), "  ".join(ratios),
                                             w=name_width))


def geomean(values):
    values = [value for value in values if value > 0]
    if not values:
        return 0.0
    return math.exp(sum(math.log(value) for value in values) / len(values))


def print_summary(progress, report, elapsed_seconds):
    measured = measured_benchmarks(report)
    if not measured:
        return
    progress.line()
    progress.line("{}Summary{}  {} workloads, {} runs each, {}".format(
        STYLE.bold, STYLE.reset, len(measured), report["runs"], format_seconds(elapsed_seconds)))
    for other in ("cpp", "rust"):
        ratios = [item["languages"]["prismio"]["elapsed_ns_median"]
                  / max(item["languages"][other]["elapsed_ns_median"], 1) for item in measured]
        faster = sum(ratio <= 1 - PARITY for ratio in ratios)
        slower = sum(ratio >= 1 + PARITY for ratio in ratios)
        parity = len(ratios) - faster - slower
        progress.line("  vs {:<5} geomean {}   {}{} faster{} · {} parity · {}{} slower{}".format(
            LANGUAGE_LABELS[other], ratio_cell(geomean(ratios), 0),
            STYLE.green, faster, STYLE.reset, parity, STYLE.red if slower else "", slower, STYLE.reset))
    behind = sorted(((item["languages"]["prismio"]["elapsed_ns_median"]
                      / max(item["languages"]["cpp"]["elapsed_ns_median"], 1), item["name"])
                     for item in measured), reverse=True)
    behind = [(ratio, name) for ratio, name in behind if ratio >= 1 + PARITY][:5]
    if behind:
        progress.line("  {}slowest vs C++{}  {}".format(
            STYLE.dim, STYLE.reset, ", ".join("{} {}".format(name, ratio_cell(ratio, 0)) for ratio, name in behind)))


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
    parser.add_argument("--rebuild", action="store_true",
                        help="rebuild the C++ and Rust arms even when their sources and toolchains are unchanged")
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
    implemented_count = sum(item["status"] != "unsupported" for item in selected)
    progress.line("{}Prismio benchmarks{}  {} workload{} · {} run{} each · Prismio, C++ and Rust".format(
        STYLE.bold, STYLE.reset, implemented_count, "" if implemented_count == 1 else "s",
        args.runs, "" if args.runs == 1 else "s"))
    progress.line()
    progress.show("Preparing benchmark suite")

    build_commands = None
    compile_ns = None
    cached_arms = []
    if not args.skip_build:
        build_commands, compile_ns, cached_arms = build_all(args, progress)
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
        # Which arms were served from the previous build. Their `compile_ns` is
        # that build's, not this run's, and saying so is the difference between a
        # stale number and a wrong one.
        "cached_builds": cached_arms,
        "benchmarks": [],
    }
    name_width = max([len("workload")] + [len(item["name"]) for item in selected])
    table_header(progress, name_width)
    category = None
    with tempfile.TemporaryDirectory(prefix="prismio-bench-") as temp_name:
        temp = Path(temp_name)
        fixture = make_fixture(temp)
        for item in selected:
            if item.get("category") != category:
                category = item.get("category")
                progress.line("  {}{}{}".format(STYLE.cyan, category, STYLE.reset))
            if item["status"] == "unsupported":
                report["benchmarks"].append(dict(item))
                progress.advance("Skipped {} (unsupported)".format(item["name"]))
                progress.line("    {:<{w}}  {}unsupported{}".format(item["name"], STYLE.dim, STYLE.reset,
                                                                  w=name_width))
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
            table_row(progress, measured, name_width)

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
    print_summary(progress, report, time.monotonic() - progress.started)

    implemented = len(measured_benchmarks(report))
    unsupported = sum(item["status"] == "unsupported" for item in report["benchmarks"])
    sample_text = "1 run" if args.runs == 1 else "{} runs".format(args.runs)
    print()
    print("Completed {} benchmarks ({} unsupported) · {}".format(
        implemented, unsupported, sample_text))
    print("{}Report{}   {}".format(STYLE.dim, STYLE.reset, html_path))
    print("{}Data{}     {}".format(STYLE.dim, STYLE.reset, args.output))
    if args.open:
        webbrowser.open(html_path.resolve().as_uri())


if __name__ == "__main__":
    main()
