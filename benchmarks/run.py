#!/usr/bin/env python3
"""Build, validate, and measure the benchmark suites.

Two suites share this runner. `hosted` is the Prismio/C++/Rust matrix on the host
operating system; `freestanding` is Prismio/C/Rust with no operating system, run
under QEMU and counted in instructions (freestanding/suite.py). Both land in one
results file and one report, in tabs.
"""

import argparse
from datetime import datetime, timezone
import hashlib
from html import escape
import json
import math
import os
import platform
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
import webbrowser

try:
    import resource
except ImportError:     # Windows: no rusage, so no CPU time
    resource = None

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
HOSTED = HERE / "hosted"
FREESTANDING = HERE / "freestanding"
MANIFEST = HOSTED / "benchmarks.json"
BUILD = HERE / "build" / "hosted"
RESULTS = HERE / "results"
TEMPLATES = HERE / "templates"
SUITES = ("hosted", "freestanding")
LANGUAGES = ("prismio", "cpp", "rust")
LANGUAGE_LABELS = {"prismio": "Prismio", "cpp": "C++", "rust": "Rust"}
CPP_SOURCES = tuple(HOSTED / "cpp" / name for name in (
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

# What a verdict may not call a difference: the harness's own jitter. A workload
# that finishes in 600 us is dominated by things no code change moves -- process
# start, which core the scheduler picks, the clock ramping up -- and they show up
# as two timing modes (a fast one and one ~25% slower) rather than as a smooth
# spread. A flat percentage cannot be right for 0.2 ms and 200 ms at once, and a
# median-and-MAD noise estimate reads such a bimodal run as 0% noise, so
# `edit_distance` (560 us or 700 us in *every* language) was called a 1.18x loss.
# The rule below uses two things instead: the arms' own spread, and the best run.
NOISE_FLOOR_NS = 25_000


def spread(samples):
    """Interquartile range over the median: how much of the median is jitter. Two
    timing modes make this large (an IQR sees both), where MAD sees one."""
    values = sorted(samples)
    if len(values) < 2:
        return 0.0
    median = statistics.median(values)
    if median <= 0:
        return 0.0
    if len(values) < 4:
        return (values[-1] - values[0]) / median
    q1, _, q3 = statistics.quantiles(values, n=4, method="inclusive")
    return (q3 - q1) / median


def verdict(prismio, other):
    """`win`, `parity` or `loss` for Prismio's samples against another arm's, with
    the numbers it was decided on.

    A loss (or a win) needs **both** the ratio of medians and the ratio of best runs
    to leave the tolerance. Noise only ever adds time, so the best run is the
    stablest estimate of what the code costs; the median says what a run usually
    costs. Both disagreeing -- equal best runs, different medians -- is the signature
    of timing modes, and is parity.

    The tolerance on medians is the larger of the flat `PARITY`, either arm's own
    spread, and `NOISE_FLOOR_NS` as a fraction of the run. On best runs, which carry
    no spread, only `PARITY` and the floor."""
    med_p, med_o = statistics.median(prismio), statistics.median(other)
    min_p, min_o = min(prismio), min(other)
    ratio = med_p / max(med_o, 1)
    best_ratio = min_p / max(min_o, 1)
    noise = max(spread(prismio), spread(other))
    tol_median = max(PARITY, noise, NOISE_FLOOR_NS / max(med_o, 1))
    tol_best = max(PARITY, NOISE_FLOOR_NS / max(min_o, 1))
    outcome = "parity"
    if ratio >= 1 + tol_median and best_ratio >= 1 + tol_best:
        outcome = "loss"
    elif ratio <= 1 - tol_median and best_ratio <= 1 - tol_best:
        outcome = "win"
    return {"outcome": outcome, "ratio": round(ratio, 4), "best_ratio": round(best_ratio, 4),
            "tolerance": round(tol_median, 4), "noise": round(noise, 4)}


def verdicts(item):
    """Both comparisons for one measured workload, from its recorded samples."""
    prismio = item["languages"]["prismio"]["elapsed_ns_samples"]
    return {other: verdict(prismio, item["languages"][other]["elapsed_ns_samples"])
            for other in ("cpp", "rust")}

# Bumped when a field is added or its meaning changes. 2 added `parity`,
# `environment`, repo-relative paths in `build_commands` and `artifacts`. 3 added
# `verdict` per workload and `noise_model`, so every reader judges a result by the
# rule above rather than by its own percentage.
SCHEMA_VERSION = 3
# The combined results file. 4 holds one report per suite under `suites`; each
# suite's own report keeps the schema it was written with.
RESULTS_SCHEMA_VERSION = 4
HARNESS = "benchmarks/run.py"


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


def format_bytes(bytes_count):
    """A byte count in human-readable units (B, KB, MB, GB)."""
    if bytes_count is None:
        return "—"
    if bytes_count >= 1024 * 1024 * 1024:
        return "{:.2f} GB".format(bytes_count / (1024 * 1024 * 1024))
    if bytes_count >= 1024 * 1024:
        return "{:.2f} MB".format(bytes_count / (1024 * 1024))
    if bytes_count >= 1024:
        return "{:.1f} KB".format(bytes_count / 1024)
    return "{:d} B".format(int(bytes_count))


class RusagePopen(subprocess.Popen):
    """Subprocess Popen that hooks _try_wait with os.wait4 to capture child peak RSS."""

    def __init__(self, *args, **kwargs):
        self.rusage = None
        super().__init__(*args, **kwargs)

    def _try_wait(self, wait_flags):
        if hasattr(os, "wait4"):
            try:
                pid, sts, ru = os.wait4(self.pid, wait_flags)
                if pid != 0:
                    self.rusage = ru
                return (pid, sts)
            except ChildProcessError:
                return (self.pid, 0)
        return super()._try_wait(wait_flags)


def normalize_rss_bytes(ru_maxrss):
    if ru_maxrss is None:
        return 0
    # Darwin (macOS) ru_maxrss is in bytes; Linux and BSDs are in KiB.
    if sys.platform == "darwin":
        return int(ru_maxrss)
    return int(ru_maxrss * 1024)


def ratio_cell(ratio, width=8, outcome=None):
    """Prismio's time over the other arm's: below 1 is Prismio ahead. Padded
    before it is coloured, so escape codes never disturb the columns.

    `outcome` is the noise-aware verdict for this comparison. Without one (memory
    columns, summary geomeans) the flat `PARITY` rule applies."""
    text = "{:.2f}×".format(ratio).rjust(width)
    if outcome is None:
        outcome = "win" if ratio <= 1 - PARITY else "loss" if ratio >= 1 + PARITY else "parity"
    if outcome == "win":
        return STYLE.green + text + STYLE.reset
    if outcome == "parity":
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


def portable_part(part):
    """A path as a reader of the repository would type it. A path inside the
    repository becomes relative to it; one outside (a Homebrew `clang++`) is
    reduced to its file name. The recorded command then neither depends on nor
    reveals where the checkout lives, so the JSON is safe to publish as it is."""
    text = str(part)
    path = Path(text)
    if not path.is_absolute():
        return text
    try:
        return str(path.relative_to(REPO))
    except ValueError:
        return path.name


def portable_command(command):
    return " ".join(portable_part(part) for part in command)


def run_command(command, *, env=None, cwd=None):
    return subprocess.run(command, cwd=cwd or REPO, env=env, capture_output=True, text=True)


def run_timed(command, *, env=None, cwd=None):
    """(result, wall_ns, cpu_ns) of one build.

    CPU time is user plus system over the child and everything it spawned, and it
    is reported beside the wall time because the arms do not use the machine the
    same way: Prismio's backend runs on several threads, clang++ -flto and
    `rustc -C codegen-units=1` on about one. A wall-clock ratio alone credits
    the first with cores the others never asked for.
    """
    before = resource.getrusage(resource.RUSAGE_CHILDREN) if resource else None
    started = time.perf_counter_ns()
    result = run_command(command, env=env, cwd=cwd)
    wall = time.perf_counter_ns() - started
    if not resource:
        return result, wall, 0
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu = ((after.ru_utime - before.ru_utime) + (after.ru_stime - before.ru_stime)) * 1e9
    return result, wall, int(cpu)


def cpp_lto_flags(cxx, env):
    """The LTO flags the C++ arm can actually link with on this machine.

    The Rust arm is built with fat LTO, so the C++ arm gets LTO too. Whether it can is a
    property of the machine's linker, not of the benchmark: on Linux GNU ld reads bitcode
    through LLVMgold.so, which the pinned LLVM does not ship (tools/setup_llvm.py prunes
    every shared library from `lib/`), and the pinned `ld.lld` needs an ICU the host may
    not have. So each candidate is tried on a one-line program, and the first that links
    wins: LTO with lld, LTO with the default linker, then none. Without LTO the C++ arm
    is slower than it would be, never faster, so a fallback cannot flatter Prismio; the
    exact command is recorded in the report either way.
    """
    candidates = [["-flto", "-fuse-ld=lld"], ["-flto"], []] if sys.platform.startswith("linux") \
        else [["-flto"], []]
    with tempfile.TemporaryDirectory() as tmp:
        probe = Path(tmp) / "probe.cpp"
        probe.write_text("int main() { return 0; }\n")
        for flags in candidates:
            tried = subprocess.run([cxx, "-O3", *flags, str(probe), "-o", str(Path(tmp) / "probe")],
                                   capture_output=True, text=True, env=env)
            if tried.returncode == 0:
                if "-flto" not in flags:
                    print("warning: no linker here can do LTO; the C++ arm is built without it", file=sys.stderr)
                return flags
    return []


FRESHNESS_SOURCES = ("src/**/*.psm", "std/*.psm", "runtime/*.c", "runtime/*.h")


def stale_compiler_sources(compiler):
    """Sources newer than `compiler`, when it is the project's own host.

    `prismio bench` measures `.prismio/build/debug/prismio`, which is whatever was
    last promoted there. Edit `src/` or `runtime/` and run the bench without
    rebuilding, and every number describes the compiler from before the edit. The
    check is the modification time of the binary against the sources it is built
    from; it applies only to the project host, because a compiler named by hand is
    the caller's own business.
    """
    path = Path(compiler).resolve()
    host_dir = (REPO / ".prismio" / "build").resolve()
    if host_dir not in path.parents or not path.exists():
        return []
    built = path.stat().st_mtime
    newer = []
    for pattern in FRESHNESS_SOURCES:
        for source in REPO.glob(pattern):
            if source.is_file() and source.stat().st_mtime > built + 1:
                newer.append(source.relative_to(REPO).as_posix())
    return sorted(newer)


def compiler_identity(compiler):
    path = Path(compiler).resolve()
    info = {"path": str(path)}
    try:
        stat = path.stat()
        info["bytes"] = stat.st_size
        info["modified"] = datetime.fromtimestamp(stat.st_mtime, timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    except OSError:
        pass
    return info


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
        for path in sorted(HOSTED.glob(pattern)):
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
        "prismio": [str(Path(args.compiler).resolve()), "build", str(HOSTED / "prismio/suite.psm"), "-o", str(BUILD / "prismio-suite")],
        "cpp": [cxx, "-O3", *cpp_lto_flags(cxx, env), "-std=c++20", "-pthread", *(str(path) for path in CPP_SOURCES),
                "-o", str(BUILD / "cpp-suite")],
        "rust": ["rustc", "-C", "opt-level=3", "-C", "lto=fat", "-C", "codegen-units=1", "--edition=2021", str(HOSTED / "rust/suite.rs"), "-o", str(BUILD / "rust-suite")],
    }
    elapsed = {}
    cpu = {}
    cached = {}
    runs = max(1, args.compile_runs)
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
        # Reused only when asked for (`--reuse-reference-builds`). A build that was
        # timed in an earlier run, possibly under other load or another toolchain
        # state, is not a measurement of this one, and a report that mixes the two
        # compares a fresh Prismio figure with a stale C++ one.
        if key is not None and args.reuse_reference_builds and not args.rebuild and args.compile_runs <= 1:
            previous = read_stamp(stamp)
            if binary.exists() and previous.get("key") == key:
                elapsed[language] = previous.get("compile_ns", 0)
                cpu[language] = previous.get("compile_cpu_ns", 0)
                cached[language] = previous.get("built_at", "an earlier run")
                progress.advance("Cached {}".format(LANGUAGE_LABELS[language]))
                status(progress, "Cached", LANGUAGE_LABELS[language] + " suite",
                       "built earlier ({}) in {} · {}".format(cached[language], format_ns(elapsed[language]),
                                                              format_bytes(binary.stat().st_size)))
                continue

        progress.show("Building " + LANGUAGE_LABELS[language])
        walls, cpus = [], []
        for _ in range(runs):
            result, wall, cpu_ns = run_timed(commands[language], env=env)
            if result.returncode:
                sys.exit("build failed for {}:\n{}\n{}\n{}".format(
                    language, command_text(commands[language]), result.stdout, result.stderr))
            walls.append(wall)
            cpus.append(cpu_ns)
        elapsed[language] = int(statistics.median(walls))
        cpu[language] = int(statistics.median(cpus))
        # Written after the build, so an interrupted or failed one leaves the
        # stamp naming the last binary that actually exists.
        if key is not None:
            stamp.write_text(json.dumps({
                "key": key, "compile_ns": elapsed[language], "compile_cpu_ns": cpu[language],
                "built_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")}))
        progress.advance("Built {}".format(LANGUAGE_LABELS[language]))
        status(progress, "Compiled", LANGUAGE_LABELS[language] + " suite",
               "{} wall · {} cpu · {}".format(format_ns(elapsed[language]), format_ns(cpu[language]),
                                              format_bytes(binary.stat().st_size)))
    return commands, elapsed, cpu, cached


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
    proc = RusagePopen(command, cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    stdout, stderr = proc.communicate()
    wall_ns = time.perf_counter_ns() - started
    if proc.returncode != 0:
        raise RuntimeError("run failed:\n{}\n{}\n{}".format(command_text(command), stdout, stderr))
    fields = parse_output(executable.name, benchmark, stdout)
    fields["wall_ns"] = wall_ns
    fields["peak_rss_bytes"] = normalize_rss_bytes(proc.rusage.ru_maxrss if proc.rusage else None)
    return fields


def table_header(progress, name_width):
    cells = "    {:<{w}}  {:>10}  {:>10}  {:>10}  {:>8}  {:>8}  {:>9}  {:>8}".format(
        "workload", "Prismio", "C++", "Rust", "vs C++", "vs Rust", "RSS (P)", "RSS vs C", w=name_width)
    progress.line()
    progress.line(STYLE.bold + cells + STYLE.reset)


def table_row(progress, measured, name_width):
    """One workload: each arm's median, the fastest in bold, Prismio's ratio
    to each of the others, and peak RSS."""
    times = {language: measured["languages"][language]["elapsed_ns_median"] for language in LANGUAGES}
    rss = {language: measured["languages"][language].get("peak_rss_bytes_median", 0) for language in LANGUAGES}
    fastest = min(times.values())
    cells = []
    for language in LANGUAGES:
        text = format_ns(times[language]).rjust(10)
        cells.append(STYLE.bold + text + STYLE.reset if times[language] == fastest else text)
    judged = verdicts(measured)
    ratios = [ratio_cell(times["prismio"] / max(times[other], 1), outcome=judged[other]["outcome"])
              for other in ("cpp", "rust")]
    p_rss_str = format_bytes(rss["prismio"]).rjust(9)
    rss_ratio = ratio_cell(rss["prismio"] / max(rss["cpp"], 1), width=8) if rss["cpp"] > 0 else "—".rjust(8)
    progress.line("    {:<{w}}  {}  {}  {}  {}".format(
        measured["name"], "  ".join(cells), "  ".join(ratios), p_rss_str, rss_ratio,
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
        outcomes = [verdicts(item)[other]["outcome"] for item in measured]
        faster, slower = outcomes.count("win"), outcomes.count("loss")
        parity = len(outcomes) - faster - slower
        progress.line("  vs {:<5} geomean {}   {}{} faster{} · {} parity · {}{} slower{}".format(
            LANGUAGE_LABELS[other], ratio_cell(geomean(ratios), 0),
            STYLE.green, faster, STYLE.reset, parity, STYLE.red if slower else "", slower, STYLE.reset))
    behind = sorted(((item["languages"]["prismio"]["elapsed_ns_median"]
                      / max(item["languages"]["cpp"]["elapsed_ns_median"], 1), item["name"])
                     for item in measured if verdicts(item)["cpp"]["outcome"] == "loss"), reverse=True)[:5]
    if behind:
        progress.line("  {}slowest vs C++{}  {}".format(
            STYLE.dim, STYLE.reset, ", ".join("{} {}".format(name, ratio_cell(ratio, 0, "loss")) for ratio, name in behind)))
    for item in elimination_benchmarks(report):
        progress.line("  {}elimination{}     {}: {}".format(
            STYLE.dim, STYLE.reset, item["name"], " · ".join(
                "{} {}".format(LANGUAGE_LABELS[language], elimination_cell(
                    item["languages"][language]["elapsed_ns_median"])) for language in LANGUAGES)))

    binary_bytes = report.get("binary_bytes", {})
    if binary_bytes and "prismio" in binary_bytes:
        p_bin = binary_bytes["prismio"]
        c_bin = binary_bytes.get("cpp", 1)
        r_bin = binary_bytes.get("rust", 1)
        progress.line()
        progress.line("{}Binary Size{}   Prismio {} · C++ {} ({}) · Rust {} ({})".format(
            STYLE.bold, STYLE.reset,
            format_bytes(p_bin),
            format_bytes(c_bin), ratio_cell(p_bin / max(c_bin, 1), 0),
            format_bytes(r_bin), ratio_cell(p_bin / max(r_bin, 1), 0)
        ))

    has_rss = any("peak_rss_bytes_median" in item["languages"]["prismio"] for item in measured)
    if has_rss:
        progress.line()
        progress.line("{}Peak RSS{}      Prismio memory vs other runtimes (lower is better)".format(
            STYLE.bold, STYLE.reset))
        for other in ("cpp", "rust"):
            rss_ratios = [
                item["languages"]["prismio"].get("peak_rss_bytes_median", 1)
                / max(item["languages"][other].get("peak_rss_bytes_median", 1), 1)
                for item in measured
                if item["languages"][other].get("peak_rss_bytes_median", 0) > 0
            ]
            if rss_ratios:
                progress.line("  vs {:<5} geomean {}".format(
                    LANGUAGE_LABELS[other], ratio_cell(geomean(rss_ratios), 0)
                ))


def first_line(command, *, env=None):
    """The first line a command prints, or "" when it is missing or fails."""
    try:
        probe = subprocess.run([str(part) for part in command], cwd=REPO, env=env,
                               capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return ""
    lines = ((probe.stdout or "") + (probe.stderr or "")).strip().splitlines()
    return lines[0].strip() if lines else ""


def version_number(text):
    match = re.search(r"\b(\d+\.\d+(?:\.\d+)?)\b", text)
    return match.group(1) if match else None


def collect_environment(args):
    """The machine and toolchains this run measured, so the numbers can be read
    against them. Everything is probed, nothing typed in, and a probe that finds
    nothing leaves its key out rather than guessing."""
    system = platform.system()
    llvm_bin = llvm_bin_from(args)
    env = os.environ.copy()
    if llvm_bin:
        env["PATH"] = str(llvm_bin) + os.pathsep + env.get("PATH", "")
    cxx = str(llvm_bin / "clang++") if llvm_bin and (llvm_bin / "clang++").exists() else "clang++"

    info = {}
    if system == "Darwin":
        info["processor"] = first_line(["sysctl", "-n", "machdep.cpu.brand_string"])
        cores = first_line(["sysctl", "-n", "hw.physicalcpu"])
        memory = first_line(["sysctl", "-n", "hw.memsize"])
        version = first_line(["sw_vers", "-productVersion"])
        build = first_line(["sw_vers", "-buildVersion"])
        info["os"] = "macOS {} ({})".format(version, build) if version else "macOS"
        battery = first_line(["pmset", "-g", "batt"])
        if "AC Power" in battery:
            info["power"] = "AC Power"
        elif "Battery Power" in battery:
            info["power"] = "Battery Power"
    else:
        info["processor"] = platform.processor() or platform.machine()
        cores = str(os.cpu_count() or "")
        memory = ""
        if system == "Linux":
            try:
                for line in Path("/proc/cpuinfo").read_text().splitlines():
                    if line.startswith("model name"):
                        info["processor"] = line.split(":", 1)[1].strip()
                        break
                for line in Path("/proc/meminfo").read_text().splitlines():
                    if line.startswith("MemTotal"):
                        memory = str(int(line.split()[1]) * 1024)
                        break
            except (OSError, ValueError):
                pass
        info["os"] = platform.platform()
    if cores.isdigit():
        info["cores"] = int(cores)
    if memory.isdigit():
        info["memory_bytes"] = int(memory)
    info["target"] = first_line([cxx, "-print-target-triple"], env=env) or "{}-{}".format(
        platform.machine(), system.lower())

    toolchains = {}
    if args.compiler:
        compiler = [str(Path(args.compiler).resolve()), "--version"]
        hosted = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
        try:
            probe = subprocess.run(compiler, cwd=REPO, env=hosted, capture_output=True, text=True, timeout=30)
            lines = (probe.stdout or "").strip().splitlines()
        except (OSError, subprocess.SubprocessError):
            lines = []
        prismio = {}
        for line in lines:
            head, _, rest = line.partition(" ")
            if head == "prismio" and rest:
                prismio["version"] = rest.strip()
            elif head == "llvm" and rest:
                toolchains["llvm"] = rest.strip()
            elif head == "compiler" and rest:
                # The directory the compiler was built into: `debug` or `release`.
                prismio["profile"] = Path(rest.strip()).name
        if prismio:
            toolchains["prismio"] = prismio
    clang = version_number(first_line([cxx, "--version"], env=env))
    if clang:
        toolchains["clang"] = clang
        toolchains.setdefault("llvm", clang)
    rustc = version_number(first_line(["rustc", "--version"], env=env))
    if rustc:
        toolchains["rustc"] = rustc
    info["toolchains"] = toolchains

    commit = first_line(["git", "rev-parse", "--short", "HEAD"])
    if commit:
        dirty = subprocess.run(["git", "status", "--porcelain"], cwd=REPO, capture_output=True, text=True)
        info["source"] = {"commit": commit, "dirty": bool(dirty.stdout.strip())}
    info["harness"] = {"name": HARNESS, "schema_version": SCHEMA_VERSION}
    return {key: value for key, value in info.items() if value not in ("", None)}


def select_benchmarks(manifest, names):
    requested = set(names or [])
    known = {item["name"] for item in manifest["benchmarks"]}
    unknown = sorted(requested - known)
    if unknown:
        sys.exit("unknown benchmark(s): " + ", ".join(unknown))
    return [item for item in manifest["benchmarks"] if not requested or item["name"] in requested]


# A workload whose correct result is that no work is left: the compiler is
# expected to delete it, and what remains to time is the timer and the call.
# `dead_code_elimination` compiles to `return 17` in all three languages, and
# read 0 ns for Prismio against ~0.7 us for C++ and Rust -- overhead, not speed.
# As a ratio that 0 is meaningless, and the HTML report's geomean, which clamps
# a ratio to 1e-9 rather than dropping it, read ~28% low because of it. So an
# elimination workload is reported as kept or eliminated per language and stays
# out of every ratio. A loop that survives costs milliseconds, far past this.
ELIMINATED_NS = 10_000


def is_elimination(item):
    return item.get("measure") == "elimination"


def measured_benchmarks(report):
    return [item for item in report["benchmarks"]
            if item["status"] == "implemented" and not is_elimination(item)]


def elimination_benchmarks(report):
    return [item for item in report["benchmarks"]
            if item["status"] == "implemented" and is_elimination(item)]


def elimination_cell(ns):
    if ns <= ELIMINATED_NS:
        return STYLE.green + "eliminated" + STYLE.reset
    return STYLE.red + "kept " + format_ns(ns) + STYLE.reset


def elimination_row(progress, measured, name_width):
    """An elimination workload: whether each arm deleted the work, never a ratio."""
    cells = ["{} {}".format(LANGUAGE_LABELS[language], elimination_cell(
        measured["languages"][language]["elapsed_ns_median"])) for language in LANGUAGES]
    progress.line("    {:<{w}}  {}".format(measured["name"], " · ".join(cells), w=name_width))


def write_html_report(report, path, raw_data_name):
    embedded = json.dumps(report, separators=(",", ":")).replace("</", "<\/")
    template_html = (TEMPLATES / "report.html").read_text()
    rendered = template_html.replace("__REPORT_DATA__", embedded).replace("__RAW_FILE__", escape(raw_data_name))
    path.write_text(rendered)
    css_src = TEMPLATES / "report.css"
    if css_src.is_file():
        shutil.copy2(css_src, path.parent / "report.css")


def run_hosted(args, only):
    """The hosted matrix: Prismio, C++ and Rust on this operating system. Returns the
    report; writing it is main's job, because the report shares a file with the
    other suite."""
    manifest = json.loads(MANIFEST.read_text())
    selected = select_benchmarks(manifest, only)
    if not args.skip_build and not args.compiler:
        sys.exit("--compiler is required (or set PRISMIO)")

    build_steps = 0 if args.skip_build else len(LANGUAGES)
    workload_steps = sum(1 if item["status"] == "unsupported" else args.runs * len(LANGUAGES)
                         for item in selected)
    progress = Progress(build_steps + workload_steps)
    implemented_count = sum(item["status"] != "unsupported" for item in selected)
    progress.line("{}Hosted benchmarks{}  {} workload{} · {} run{} each · Prismio, C++ and Rust".format(
        STYLE.bold, STYLE.reset, implemented_count, "" if implemented_count == 1 else "s",
        args.runs, "" if args.runs == 1 else "s"))
    progress.line()
    progress.show("Preparing benchmark suite")

    if args.skip_build:
        print("warning: --skip-build: the executables are from an earlier run and no compile time is measured", file=sys.stderr)
    build_commands = None
    compile_ns = None
    compile_cpu_ns = None
    cached_arms = {}
    if not args.skip_build:
        build_commands, compile_ns, compile_cpu_ns, cached_arms = build_all(args, progress)
    executables = {language: BUILD / (language + "-suite") for language in LANGUAGES}
    missing = [str(path) for path in executables.values() if not path.exists()]
    if missing:
        sys.exit("missing built executable(s): " + ", ".join(missing))
    binary_bytes = {language: executables[language].stat().st_size for language in LANGUAGES}

    report = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "runs": args.runs,
        # Repo-relative, so the file carries no path from the machine that wrote it.
        "build_commands": {key: portable_command(value) for key, value in (build_commands or {}).items()},
        # Within this fraction of the other arm a result is parity, not a win or a
        # loss -- the rule the terminal summary uses, recorded so a reader of the
        # JSON applies the same one.
        "parity": PARITY,
        # How `verdict` on each workload was decided, so a reader can say why a
        # difference was or was not called one.
        "noise_model": {
            "parity": PARITY,
            "floor_ns": NOISE_FLOOR_NS,
            "spread": "interquartile range over the median, larger of the two arms",
            "rule": "win/loss needs the ratio of medians and the ratio of best runs both "
                    "outside max(parity, spread, floor/median); otherwise parity",
        },
        "environment": collect_environment(args),
        "compile_ns": compile_ns,
        # User plus system time of the same builds. Wall time alone credits an arm
        # with the cores it used; see run_timed.
        "compile_cpu_ns": compile_cpu_ns,
        # How many builds the figures above are the median of (1 unless
        # `--compile-runs` asked for more).
        "compile_runs": max(1, args.compile_runs),
        "binary_bytes": binary_bytes,
        # Which arms were served from an earlier build, and when it was made. Their
        # `compile_ns` is that build's, not this run's, and saying so is the
        # difference between a stale number and a wrong one. The report shows it.
        "cached_builds": sorted(cached_arms),
        "cached_built_at": cached_arms,
        # Which compiler was measured, and whether anything was left as it was.
        "compiler": compiler_identity(args.compiler) if args.compiler else None,
        "build_skipped": bool(args.skip_build),
        # The threshold below which an elimination workload counts as deleted,
        # so the HTML report judges it by the same number.
        "elimination_ns": ELIMINATED_NS,
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
                    "peak_rss_bytes_median": int(statistics.median(sample.get("peak_rss_bytes", 0) for sample in samples[language])),
                    "peak_rss_bytes_samples": [sample.get("peak_rss_bytes", 0) for sample in samples[language]],
                }
            if not is_elimination(measured):
                measured["verdict"] = verdicts(measured)
            report["benchmarks"].append(measured)
            if is_elimination(measured):
                elimination_row(progress, measured, name_width)
            else:
                table_row(progress, measured, name_width)

    progress.finish()
    print_summary(progress, report, time.monotonic() - progress.started)

    implemented = len(measured_benchmarks(report))
    eliminations = len(elimination_benchmarks(report))
    unsupported = sum(item["status"] == "unsupported" for item in report["benchmarks"])
    sample_text = "1 run" if args.runs == 1 else "{} runs".format(args.runs)
    print()
    print("Completed {} hosted benchmarks and {} elimination check{} ({} unsupported) · {}".format(
        implemented, eliminations, "" if eliminations == 1 else "s", unsupported, sample_text))
    return report


def load_freestanding_suite():
    """benchmarks/freestanding/suite.py, loaded by path: the directory is a suite and
    not a package, and its name should not shadow anything importable."""
    import importlib.util
    if "freestanding_suite" in sys.modules:
        return sys.modules["freestanding_suite"]     # one module, so one Unavailable
    spec = importlib.util.spec_from_file_location("freestanding_suite", FREESTANDING / "suite.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class FreestandingUI:
    """What suite.py needs of this module, handed over rather than imported: its
    progress bar, colours and formatters."""

    def __init__(self, progress):
        self.progress = progress
        self.style = STYLE
        self.show = progress.show
        self.advance = progress.advance
        self.line = progress.line
        self.format_ns = format_ns
        self.format_bytes = format_bytes

    @staticmethod
    def ratio(value, width=8, outcome=None):
        return ratio_cell(value, width, outcome)


def run_freestanding(args, only):
    """The bare-metal suite. Returns the report, or raises its module's Unavailable
    naming the missing prerequisite."""
    suite = load_freestanding_suite()
    if not args.compiler:
        sys.exit("--compiler is required (or set PRISMIO)")
    progress = Progress(suite.step_count(args))
    progress.line("{}Freestanding benchmarks{}  bare-metal AArch64 under QEMU · Prismio, C and Rust · "
                  "guest instructions".format(STYLE.bold, STYLE.reset))
    progress.line()
    progress.show("Preparing freestanding suite")
    try:
        report = suite.run(args, str(Path(args.compiler).resolve()), llvm_bin_from(args),
                           collect_environment(args), FreestandingUI(progress), run_timed,
                           portable_command, only=only)
    finally:
        progress.finish()
    print()
    print("Completed {} freestanding benchmarks · deterministic instruction counts".format(
        len(report["benchmarks"])))
    return report


def existing_suites(path):
    """The reports a results file already holds, so running one suite leaves the
    other as it was. A file from before the suites were split is the hosted report."""
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return {}
    if isinstance(data.get("suites"), dict):
        return dict(data["suites"])
    if "benchmarks" in data:
        return {"hosted": data}
    return {}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--suite", choices=("all",) + SUITES, default="all",
                        help="which suite to run (default: both; the freestanding suite is skipped, "
                             "with a note, when its tools are not installed)")
    parser.add_argument("--compiler", default=os.environ.get("PRISMIO"), help="Prismio compiler executable (or set PRISMIO)")
    parser.add_argument("--llvm-bin", help="LLVM bin directory prepended to PATH for Prismio, C and C++ builds")
    parser.add_argument("--runs", type=int, default=5,
                        help="samples per hosted arm; the freestanding suite is exact and boots each arm "
                             "min(runs, 3) times")
    parser.add_argument("--only", action="append", metavar="NAME", help="run one benchmark; repeat the option for more")
    parser.add_argument("--scale", type=int, default=1, metavar="N",
                        help="multiply every freestanding workload's size by N (default 1)")
    parser.add_argument("--skip-build", action="store_true",
                        help="hosted only: use the executables an earlier run built")
    parser.add_argument("--rebuild", action="store_true",
                        help="rebuild the C++ and Rust arms even when their sources and toolchains are unchanged")
    parser.add_argument("--compile-runs", type=int, default=1, metavar="N",
                        help="build every hosted arm N times and report the median compile time (default 1)")
    parser.add_argument("--reuse-reference-builds", action="store_true",
                        help="reuse the C++ and Rust builds (and the compile times) of an earlier run when "
                             "their sources and toolchains are unchanged; the report says so")
    parser.add_argument("--allow-stale-compiler", action="store_true",
                        help="measure the project compiler even when its sources are newer than it")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--output", type=Path, default=RESULTS / "results.json")
    parser.add_argument("--open", action="store_true", help="open the generated HTML report in the default browser")
    args = parser.parse_args()

    catalogs = {
        "hosted": json.loads(MANIFEST.read_text()),
        "freestanding": json.loads((FREESTANDING / "benchmarks.json").read_text()),
    }
    names = {suite: {item["name"] for item in catalogs[suite]["benchmarks"]} for suite in SUITES}
    wanted = list(SUITES) if args.suite == "all" else [args.suite]
    if args.only:
        unknown = sorted(set(args.only) - names["hosted"] - names["freestanding"])
        if unknown:
            sys.exit("unknown benchmark(s): " + ", ".join(unknown))
    if args.list:
        for suite in wanted:
            for item in catalogs[suite]["benchmarks"]:
                print("{suite:12} {category:16} {status:11} {name}".format(suite=suite, **item))
        return
    if args.runs < 1:
        sys.exit("--runs must be positive")

    if not args.skip_build and args.compiler:
        newer = stale_compiler_sources(args.compiler)
        if newer and not args.allow_stale_compiler:
            sys.exit("the compiler is older than its sources, so these numbers would describe the compiler "
                     "from before your edits.\n  newest: {}{}\n  Rebuild it (`prismio build`) and run the "
                     "bench again, or pass --allow-stale-compiler.".format(
                         ", ".join(newer[:4]), " and {} more".format(len(newer) - 4) if len(newer) > 4 else ""))

    reports = {}
    for suite in wanted:
        only = [name for name in (args.only or []) if name in names[suite]]
        if args.only and not only:
            continue            # every named workload belongs to the other suite
        if suite == "hosted":
            reports[suite] = run_hosted(args, only or None)
        else:
            try:
                reports[suite] = run_freestanding(args, only or None)
            except load_freestanding_suite().Unavailable as missing:
                if args.suite == "freestanding":
                    sys.exit(str(missing))
                print("{}note{}: skipping the freestanding suite: {}".format(STYLE.yellow, STYLE.reset, missing))
    if not reports:
        sys.exit("nothing to run")

    merged = existing_suites(args.output)
    merged.update(reports)
    html_path = args.output.parent / "report.html"
    bundle = {
        "schema_version": RESULTS_SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "suites": {suite: merged[suite] for suite in SUITES if suite in merged},
        "artifacts": {"html_report": portable_part(html_path), "raw_data": portable_part(args.output)},
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(bundle, indent=2) + "\n")
    write_html_report(bundle, html_path, args.output.name)
    print()
    print("{}Report{}   {}".format(STYLE.dim, STYLE.reset, html_path))
    print("{}Data{}     {}".format(STYLE.dim, STYLE.reset, args.output))
    if args.open:
        webbrowser.open(html_path.resolve().as_uri())


if __name__ == "__main__":
    main()
