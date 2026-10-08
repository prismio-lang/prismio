"""The freestanding suite: build the C, Rust and Prismio arms for bare-metal AArch64,
run each under QEMU, and report guest instruction counts and image sizes.

Imported by benchmarks/run.py; it has no command line of its own.

**What is measured, and why it is not time.** There is no operating system under these
programs and no clock worth reading on an emulated machine. QEMU runs with
`-icount shift=0`, which makes the guest's virtual clock advance exactly one
nanosecond per instruction executed. The generic timer counts that clock at 62.5 MHz,
so a tick is 16 instructions, and `CNTVCT_EL0` read around a workload (harness.c) is
its instruction count to the nearest 16. The count is the same on every run on every
machine -- calibrated against a loop of known length -- so there are no samples to
take a median of and no noise model to apply. It is an instruction count, not a cost:
it models no cache, pipeline or branch predictor.

**The harness is shared.** harness.c is compiled once, with one compiler and one set
of flags, and linked into all three arms. Each arm provides `bench_<name>` for every
workload in benchmarks.json and nothing else, so the only code that differs between
arms is the benchmarks themselves.
"""

import glob
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import struct
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
BENCH = HERE.parent
REPO = BENCH.parent
MANIFEST = HERE / "benchmarks.json"
BUILD = BENCH / "build" / "freestanding"

LANGUAGES = ("prismio", "c", "rust")
LABELS = {"prismio": "Prismio", "c": "C", "rust": "Rust"}
# Compared with Prismio: the other two.
OTHERS = ("c", "rust")

C_TARGET = "aarch64-unknown-none-elf"
RUST_TARGET = "aarch64-unknown-none-softfloat"

# Instructions per timer tick under `-icount shift=0` on `virt` (62.5 MHz against a
# 1 GHz instruction clock). Calibrated, not assumed: a loop of exactly 10,000,000
# instructions reads 625,000 ticks on every run.
TICK_INSTRUCTIONS = 16

# Within this fraction of the other arm a result is parity. The count is exact, so
# this is not noise: it is the size of a difference that is not worth a verdict,
# since code placement alone moves a count by a fraction of a percent.
PARITY = 0.02

# Flags that make the arms one machine: no FP or SIMD (the entry code leaves the unit
# off), and strict alignment, because with the MMU off every access is to device
# memory and an unaligned one faults. Without it clang merges adjacent loads into a
# wider one and the guest dies at the exception vector.
C_FLAGS = ["--target=" + C_TARGET, "-ffreestanding", "-fno-pic", "-mgeneral-regs-only",
           "-mstrict-align", "-mcpu=generic", "-fno-stack-protector"]
PRISMIO_FEATURES = "-neon,-fp-armv8,+strict-align"


class Unavailable(Exception):
    """A prerequisite is missing; the message says which and how to get it."""


# ---------------------------------------------------------------- tools


def _runs(command, env=None):
    try:
        probe = subprocess.run([str(part) for part in command], capture_output=True, text=True,
                               timeout=60, env=env)
    except (OSError, subprocess.SubprocessError):
        return None
    return probe


def _first_line(command, env=None):
    probe = _runs(command, env)
    if not probe:
        return ""
    lines = ((probe.stdout or "") + (probe.stderr or "")).strip().splitlines()
    return lines[0].strip() if lines else ""


class Tools:
    """What the suite builds and runs with, found once.

    `fuse_ld` is the flag selecting the linker. lld is the default because it links
    an AArch64 ELF from any host. The one in LLVM's release tarball is built against
    another distribution's ICU and does not start on, say, Ubuntu, so a linker that
    will not run is not a linker: on an AArch64 Linux host GNU ld links the same
    images, and `--link-arg -fuse-ld=bfd` selects it.
    """

    def __init__(self, llvm_bin):
        self.missing = []
        self.llvm_bin = Path(llvm_bin) if llvm_bin else None
        self.clang = self._find("clang")
        self.qemu = shutil.which("qemu-system-aarch64")
        self.rustc = shutil.which("rustc")
        self.lld = self._find_lld()
        self.fuse_ld = []
        if self.lld:
            self.fuse_ld = ["-fuse-ld=lld"]
        elif sys.platform.startswith("linux") and platform.machine() in ("aarch64", "arm64") \
                and shutil.which("ld.bfd"):
            self.fuse_ld = ["-fuse-ld=bfd"]

        self.rust_src = None
        if self.rustc:
            sysroot = _first_line([self.rustc, "--print", "sysroot"])
            candidate = Path(sysroot) / "lib" / "rustlib" / "src" / "rust" / "library"
            if (candidate / "core" / "src" / "lib.rs").is_file():
                self.rust_src = candidate

        if not self.clang:
            self.missing.append("clang (an LLVM with the AArch64 target; --llvm-bin)")
        if not self.fuse_ld:
            self.missing.append("a linker that runs: ld.lld (Homebrew `lld`, or LLVM's bin on PATH)")
        if not self.qemu:
            self.missing.append("qemu-system-aarch64")
        if not self.rustc:
            self.missing.append("rustc")
        elif not self.rust_src:
            self.missing.append("the Rust source component (`rustup component add rust-src`), "
                                "from which core is built for the bare-metal target")

    def _find(self, name):
        if self.llvm_bin and (self.llvm_bin / name).exists():
            return str(self.llvm_bin / name)
        return shutil.which(name)

    def _find_lld(self):
        candidates = []
        if self.llvm_bin:
            candidates.append(self.llvm_bin / "ld.lld")
        found = shutil.which("ld.lld")
        if found:
            candidates.append(Path(found))
        candidates += [Path(p) for p in sorted(glob.glob("/opt/homebrew/opt/lld*/bin/ld.lld"))]
        candidates.append(REPO / "third_party" / "llvm" / "bin" / "ld.lld")
        for path in candidates:
            if path.is_file():
                probe = _runs([path, "--version"])
                if probe and probe.returncode == 0:
                    return str(path)
        return None

    def environment(self):
        """PATH carrying the directories of the tools clang looks up by name."""
        env = os.environ.copy()
        extra = []
        if self.llvm_bin:
            extra.append(str(self.llvm_bin))
        if self.lld:
            extra.append(str(Path(self.lld).parent))
        if extra:
            env["PATH"] = os.pathsep.join(extra) + os.pathsep + env.get("PATH", "")
        return env


# ---------------------------------------------------------------- building


def command_text(command):
    return " ".join(str(part) for part in command)


def write_workloads_header(selected, scale):
    """workloads.h: the list the harness dispatches over, from benchmarks.json."""
    BUILD.mkdir(parents=True, exist_ok=True)
    rows = " \\\n".join("    X({}, {})".format(item["name"], int(item.get("scale", 1)))
                        for item in selected)
    (BUILD / "workloads.h").write_text(
        "// Written by benchmarks/run.py from freestanding/benchmarks.json. Do not edit.\n"
        "#define BENCH_SCALE {}\n#define WORKLOADS(X) \\\n{}\n".format(scale, rows))


def ensure_rust_sysroot(tools, env):
    """A sysroot holding `core` and `compiler_builtins` built for the bare-metal
    target, from the `rust-src` component, once per rustc.

    The Rust distribution ships a standard library for the host and not for
    `aarch64-unknown-none-softfloat` unless `rustup target add` has fetched one, and
    `-Zbuild-std` fetches crates from the registry. Compiling the two crates directly
    needs neither a download nor a network, takes a few seconds, and uses the very
    library source the release was built from. `RUSTC_BOOTSTRAP=1` is what lets a
    stable rustc build the library's unstable-feature code; it is set for these two
    compiles and not for the benchmark crate.
    """
    sysroot = BUILD / "rust-sysroot"
    libdir = sysroot / "lib" / "rustlib" / RUST_TARGET / "lib"
    stamp = sysroot / "stamp"
    version = _first_line([tools.rustc, "--version"])
    if stamp.is_file() and stamp.read_text() == version and (libdir / "libcore.rlib").is_file():
        return sysroot
    shutil.rmtree(sysroot, ignore_errors=True)
    libdir.mkdir(parents=True)
    bootstrap = dict(env, RUSTC_BOOTSTRAP="1")
    common = ["--crate-type=rlib", "--target", RUST_TARGET, "-C", "opt-level=3", "-C", "panic=abort",
              "-C", "debuginfo=0", "--cap-lints", "allow", "--out-dir", str(libdir),
              "-Z", "force-unstable-if-unmarked"]
    steps = [
        [tools.rustc, "--edition=2024", "--crate-name=core", *common,
         str(tools.rust_src / "core" / "src" / "lib.rs")],
        [tools.rustc, "--edition=2024", "--crate-name=compiler_builtins", *common,
         "--cfg", 'feature="compiler-builtins"', "--cfg", 'feature="no-f16-f128"',
         "--extern", "core=" + str(libdir / "libcore.rlib"),
         str(tools.rust_src / "compiler-builtins" / "compiler-builtins" / "src" / "lib.rs")],
    ]
    for step in steps:
        done = subprocess.run(step, capture_output=True, text=True, env=bootstrap, cwd=REPO)
        if done.returncode != 0:
            raise Unavailable("could not build Rust core for {} from rust-src:\n{}".format(
                RUST_TARGET, (done.stderr or done.stdout)[-1500:]))
    stamp.write_text(version)
    return sysroot


def build_arms(args, tools, compiler, run_timed, ui):
    """(commands, compile_ns, compile_cpu_ns, elf paths) for the three arms."""
    BUILD.mkdir(parents=True, exist_ok=True)
    env = tools.environment()
    harness_o = BUILD / "harness.o"
    link_script = HERE / "harness" / "link.ld"
    link = [tools.clang, "--target=" + C_TARGET, "-nostdlib", "-static", *tools.fuse_ld,
            "-Wl,--gc-sections", "-Wl,-T," + str(link_script)]

    # The harness first: one object for every arm. -fno-builtin because it defines
    # memset and friends, and a loop in memset recognised as memset is a recursion.
    harness = [tools.clang, *C_FLAGS, "-O2", "-fno-builtin", "-I" + str(BUILD),
               "-c", str(HERE / "harness" / "harness.c"), "-o", str(harness_o)]
    done = subprocess.run(harness, capture_output=True, text=True, env=env, cwd=REPO)
    if done.returncode:
        sys.exit("harness build failed:\n{}\n{}".format(command_text(harness), done.stderr))

    sysroot = ensure_rust_sysroot(tools, env)
    c_object = BUILD / "c-suite.o"
    rust_archive = BUILD / "rust-suite.a"
    elf = {language: BUILD / (language + "-suite.elf") for language in LANGUAGES}
    steps = {
        "c": [
            [tools.clang, *C_FLAGS, "-O3", "-ffunction-sections", "-c",
             str(HERE / "c" / "suite.c"), "-o", str(c_object)],
            [*link, str(harness_o), str(c_object), "-o", str(elf["c"])],
        ],
        "rust": [
            [tools.rustc, "--edition=2021", "--crate-type=staticlib", "--target", RUST_TARGET,
             "--sysroot", str(sysroot), "-C", "opt-level=3", "-C", "lto=fat", "-C", "codegen-units=1",
             "-C", "panic=abort", "-C", "relocation-model=static", "-C", "target-cpu=generic",
             "-o", str(rust_archive), str(HERE / "rust" / "lib.rs")],
            [*link, str(harness_o), str(rust_archive), "-o", str(elf["rust"])],
        ],
        "prismio": [
            [compiler, "build", str(HERE / "prismio" / "suite.psm"), "--target", C_TARGET,
             "--freestanding", "--target-features", PRISMIO_FEATURES,
             "--link-arg", str(harness_o), "--link-arg", "-Wl,--gc-sections",
             "--link-arg", "-T", "--link-arg", str(link_script),
             *[part for flag in tools.fuse_ld for part in ("--link-arg", flag)],
             "-o", str(elf["prismio"])],
        ],
    }
    prismio_env = dict(env, PRISMIO_INTERNAL_HOSTED="1", PRISMIO_CC=tools.clang)
    walls, cpus, commands = {}, {}, {}
    for language in LANGUAGES:
        ui.show("Building " + LABELS[language] + " (freestanding)")
        wall_total = cpu_total = 0
        for command in steps[language]:
            # Prismio builds from outside the checkout. A working directory that holds
            # `runtime/` makes the compiler resolve its runtime from that source tree, the
            # program is no longer closed, and nothing is internalised: the same suite.psm
            # built from the repository root was 512 bytes larger and `heapsort` ran 200,000
            # instructions longer. The other two arms do not care where they build.
            result, wall, cpu = run_timed(command, env=prismio_env if language == "prismio" else env,
                                          cwd=BUILD if language == "prismio" else None)
            if result.returncode:
                sys.exit("build failed for freestanding {}:\n{}\n{}\n{}".format(
                    language, command_text(command), result.stdout, result.stderr))
            wall_total += wall
            cpu_total += cpu
        walls[language], cpus[language] = wall_total, cpu_total
        commands[language] = steps[language]
        ui.advance("Built {} (freestanding)".format(LABELS[language]))
    return commands, walls, cpus, elf, harness_o


# ---------------------------------------------------------------- images


def elf_sections(path):
    """Bytes in the code, read-only data, initialised data and zero-initialised data
    of an ELF64 image or object, and the file's size. Read from the section headers,
    so it needs no `size` tool."""
    data = Path(path).read_bytes()
    if data[:4] != b"\x7fELF" or data[4] != 2:
        raise ValueError("not an ELF64 file: " + str(path))
    shoff, = struct.unpack_from("<Q", data, 0x28)
    shentsize, shnum = struct.unpack_from("<HH", data, 0x3A)
    sizes = {"text": 0, "rodata": 0, "data": 0, "bss": 0}
    for index in range(shnum):
        base = shoff + index * shentsize
        sh_type, sh_flags = struct.unpack_from("<IQ", data, base + 4)
        sh_size, = struct.unpack_from("<Q", data, base + 32)
        if not sh_flags & 2:        # not SHF_ALLOC
            continue
        if sh_type == 8:            # SHT_NOBITS
            sizes["bss"] += sh_size
        elif sh_flags & 4:          # SHF_EXECINSTR
            sizes["text"] += sh_size
        elif sh_flags & 1:          # SHF_WRITE
            sizes["data"] += sh_size
        else:
            sizes["rodata"] += sh_size
    sizes["file"] = len(data)
    return sizes


# ---------------------------------------------------------------- running


BENCH_LINE = re.compile(r"^bench (\S+) (\d+) (\d+)$")


def run_guest(tools, elf, timeout=300):
    """{workload: (ticks, result)} from one boot of an image."""
    command = [tools.qemu, "-M", "virt", "-cpu", "cortex-a57", "-nographic", "-semihosting",
               "-icount", "shift=0,sleep=off", "-kernel", str(elf)]
    try:
        done = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise RuntimeError("{} did not finish in {} s under QEMU".format(Path(elf).name, timeout))
    found = {}
    finished = False
    for line in done.stdout.splitlines():
        line = line.strip()
        if line == "done":
            finished = True
            continue
        match = BENCH_LINE.match(line)
        if match:
            found[match.group(1)] = (int(match.group(2)), int(match.group(3)))
    if done.returncode != 0 or not finished:
        raise RuntimeError("{} stopped before finishing (exit {}); it printed:\n{}".format(
            Path(elf).name, done.returncode, done.stdout[-800:]))
    return found


def verdict(prismio, other):
    ratio = prismio / max(other, 1)
    outcome = "parity"
    if ratio <= 1 - PARITY:
        outcome = "win"
    elif ratio >= 1 + PARITY:
        outcome = "loss"
    return {"outcome": outcome, "ratio": round(ratio, 4), "tolerance": PARITY}


def geomean(values):
    values = [value for value in values if value > 0]
    if not values:
        return 0.0
    return math.exp(sum(math.log(value) for value in values) / len(values))


def format_count(count):
    if count >= 1e9:
        return "{:.2f} G".format(count / 1e9)
    if count >= 1e6:
        return "{:.2f} M".format(count / 1e6)
    if count >= 1e3:
        return "{:.1f} K".format(count / 1e3)
    return "{:d}".format(int(count))


def select(manifest, names):
    requested = set(names or [])
    known = {item["name"] for item in manifest["benchmarks"]}
    unknown = sorted(requested - known)
    if unknown:
        sys.exit("unknown freestanding benchmark(s): " + ", ".join(unknown))
    return [item for item in manifest["benchmarks"] if not requested or item["name"] in requested]


def check_prerequisites(tools):
    if tools.missing:
        raise Unavailable("the freestanding suite needs: " + "; ".join(tools.missing))


def step_count(args):
    """Progress steps this suite adds: three builds and a boot of each arm."""
    return 3 + 3 * max(1, min(args.runs, 3))


def run(args, compiler, llvm_bin, environment, ui, run_timed, portable_command, only=None):
    """Build, run and report the suite. `ui` carries `show`, `advance`, `line`,
    `style` and `ratio`; `environment` is the host and toolchain description the
    hosted suite already collected."""
    tools = Tools(llvm_bin)
    check_prerequisites(tools)
    manifest = json.loads(MANIFEST.read_text())
    selected = select(manifest, only)
    scale = max(1, int(getattr(args, "scale", 1) or 1))
    write_workloads_header(selected, scale)
    runs = max(1, min(args.runs, 3))
    style = ui.style

    commands, compile_ns, compile_cpu_ns, elf, harness_o = build_arms(
        args, tools, compiler, run_timed, ui)
    harness_sizes = elf_sections(harness_o)
    images = {}
    for language in LANGUAGES:
        sizes = elf_sections(elf[language])
        images[language] = {**sizes, "code_net": max(sizes["text"] - harness_sizes["text"], 0)}
        ui.line("{}{:>12}{} {} suite  {}{} wall · {} text · {} image{}".format(
            style.green, "Compiled", style.reset, LABELS[language], style.dim,
            ui.format_ns(compile_ns[language]), ui.format_bytes(sizes["text"]),
            ui.format_bytes(sizes["file"]), style.reset))

    # Boot every arm `runs` times. The count cannot differ between boots of one image;
    # booting again checks that it does not, and costs about a second.
    measured = {language: [] for language in LANGUAGES}
    for run_index in range(runs):
        for language in LANGUAGES:
            ui.show("Booting {} · run {}/{}".format(LABELS[language], run_index + 1, runs))
            measured[language].append(run_guest(tools, elf[language]))
            ui.advance("Booted {} · run {}/{}".format(LABELS[language], run_index + 1, runs))

    name_width = max([len("workload")] + [len(item["name"]) for item in selected])
    ui.line()
    ui.line("{}    {:<{w}}  {:>10}  {:>10}  {:>10}  {:>8}  {:>8}{}".format(
        style.bold, "workload", "Prismio", "C", "Rust", "vs C", "vs Rust", style.reset, w=name_width))
    benchmarks = []
    unstable = []
    category = None
    for item in selected:
        if item["category"] != category:
            category = item["category"]
            ui.line("  {}{}{}".format(style.cyan, category, style.reset))
        record = dict(item)
        record["languages"] = {}
        results = set()
        for language in LANGUAGES:
            samples = [boot[item["name"]] for boot in measured[language]]
            ticks = [sample[0] for sample in samples]
            results.update(sample[1] for sample in samples)
            if len(set(ticks)) != 1:
                unstable.append("{} {}".format(LABELS[language], item["name"]))
            record["languages"][language] = {
                "ticks": int(statistics.median(ticks)),
                "instructions": int(statistics.median(ticks)) * TICK_INSTRUCTIONS,
                "instructions_samples": [t * TICK_INSTRUCTIONS for t in ticks],
            }
        if len(results) != 1:
            raise RuntimeError("checksum mismatch for freestanding {}: {}".format(
                item["name"], ", ".join("{} {}".format(LABELS[language], sorted(
                    {boot[item["name"]][1] for boot in measured[language]})) for language in LANGUAGES)))
        record["result"] = results.pop()
        counts = {language: record["languages"][language]["instructions"] for language in LANGUAGES}
        record["verdict"] = {other: verdict(counts["prismio"], counts[other]) for other in OTHERS}
        benchmarks.append(record)
        cells = []
        best = min(counts.values())
        for language in LANGUAGES:
            text = format_count(counts[language]).rjust(10)
            cells.append(style.bold + text + style.reset if counts[language] == best else text)
        ratios = [ui.ratio(counts["prismio"] / max(counts[other], 1), outcome=record["verdict"][other]["outcome"])
                  for other in OTHERS]
        ui.line("    {:<{w}}  {}  {}".format(item["name"], "  ".join(cells), "  ".join(ratios), w=name_width))

    summary = {}
    ui.line()
    for other in OTHERS:
        ratios = [item["languages"]["prismio"]["instructions"] / max(item["languages"][other]["instructions"], 1)
                  for item in benchmarks]
        outcomes = [item["verdict"][other]["outcome"] for item in benchmarks]
        summary[other] = {"geomean": round(geomean(ratios), 4), "win": outcomes.count("win"),
                          "parity": outcomes.count("parity"), "loss": outcomes.count("loss")}
        ui.line("  vs {:<5} geomean {}   {}{} fewer{} · {} parity · {}{} more{}".format(
            LABELS[other], ui.ratio(summary[other]["geomean"], 0),
            style.green, summary[other]["win"], style.reset, summary[other]["parity"],
            style.red if summary[other]["loss"] else "", summary[other]["loss"], style.reset))
    code = {language: images[language]["text"] for language in LANGUAGES}
    ui.line()
    ui.line("{}Code size{}   Prismio {} · C {} ({}) · Rust {} ({})  {}(.text of the linked image, shared harness included){}".format(
        style.bold, style.reset, ui.format_bytes(code["prismio"]),
        ui.format_bytes(code["c"]), ui.ratio(code["prismio"] / max(code["c"], 1), 0),
        ui.format_bytes(code["rust"]), ui.ratio(code["prismio"] / max(code["rust"], 1), 0),
        style.dim, style.reset))
    if unstable:
        ui.line("{}warning{}: repeated boots disagreed for {}; the count is not deterministic here".format(
            style.yellow, style.reset, ", ".join(unstable)))

    from datetime import datetime, timezone
    host = dict(environment)
    toolchains = dict(host.get("toolchains", {}))
    qemu_version = re.search(r"version (\S+)", _first_line([tools.qemu, "--version"]))
    if qemu_version:
        toolchains["qemu"] = qemu_version.group(1)
    if tools.lld:
        lld_version = re.search(r"(\d+\.\d+\.\d+)", _first_line([tools.lld, "--version"]))
        if lld_version:
            toolchains["lld"] = lld_version.group(1)
    host["toolchains"] = toolchains
    return {
        "suite": "freestanding",
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "metric": "instructions",
        "metric_note": ("Guest instructions executed, from QEMU `-icount shift=0` read through the generic "
                        "timer (1 tick = {} instructions). Exact and repeatable; not a time, and it models "
                        "no cache or pipeline.".format(TICK_INSTRUCTIONS)),
        "tick_instructions": TICK_INSTRUCTIONS,
        "runs": runs,
        "deterministic": not unstable,
        "parity": PARITY,
        "target": C_TARGET,
        "machine": "QEMU virt, cortex-a57, -icount shift=0",
        "scale": scale,
        "languages": list(LANGUAGES),
        "language_labels": LABELS,
        "environment": host,
        "build_commands": {language: [portable_command(step) for step in commands[language]]
                           for language in LANGUAGES},
        "compile_ns": compile_ns,
        "compile_cpu_ns": compile_cpu_ns,
        "images": images,
        "harness_text_bytes": harness_sizes["text"],
        "summary": summary,
        "benchmarks": benchmarks,
    }
