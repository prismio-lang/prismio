#!/usr/bin/env python3
"""The complete v0.1 release-candidate gate, in one command.

    python tools/release_gate.py --rc build/v0.1-rc
    python tools/release_gate.py --rc build/v0.1-rc --old build/<baseline>

`--old` is optional and adds one thing: a per-function mnemonic diff against a
previous compiler. Every *gating* check runs without it.

Every check the release bar names, in the order a failure is cheapest to
diagnose: correctness before performance, and generated code before timings. It
prints one line per check and exits non-zero if any failed, because a gate that
continues past a red step is a gate somebody reads the end of.

It does **not** run the performance matrix. That is `benchmarks/run.py`, and the
release bar requires reading a per-function mnemonic diff before believing any
timing it prints -- which is a human step, not a step this can assert.
"""
import argparse
import filecmp
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import gate_ui as ui
from aif_differential import under_neutral_name

REPO = Path(__file__).resolve().parent.parent
WINDOWS = os.name == "nt"
EXE = ".exe" if WINDOWS else ""

failed = False
results = []   # (label, kind, detail) for every finished check
expected = 0   # how many checks this run will make; set once the plan is known
ticker = ui.Ticker()
_current = None


def step(label: str) -> None:
    global _current
    _current = (label, time.monotonic())
    ticker.begin(label, f"[{len(results) + 1}/{expected}]" if expected else "")


def progress(text: str) -> None:
    """Say where the running check has got to; shown beside it on a terminal."""
    ticker.note(text)


def _finish(kind: str, detail: str) -> None:
    label, started = _current
    elapsed = time.monotonic() - started
    ticker.end()
    results.append((label, kind, detail))
    print(ui.row(kind, label, detail, elapsed), flush=True)


def ok(detail: str = "") -> None:
    _finish("ok", detail)


def skip(detail: str = "") -> None:
    _finish("skip", detail)


def bad(detail: str = "") -> None:
    global failed
    failed = True
    _finish("fail", detail or "failed")


def run(command: list, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run([str(c) for c in command], capture_output=True, text=True,
                          cwd=str(REPO), **kwargs)


ANSI = re.compile(r"\x1b\[[0-9;]*m")


def run_streaming(command: list, on_line, **kwargs) -> subprocess.CompletedProcess:
    """`run`, but each line of output reaches `on_line` as it is printed, so a long
    check can say how far along it is. Output is merged and returned in full."""
    env = {**kwargs.pop("env", os.environ), "PYTHONUNBUFFERED": "1"}
    process = subprocess.Popen([str(c) for c in command], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, cwd=kwargs.pop("cwd", str(REPO)),
                               env=env)
    lines = []
    for line in process.stdout:
        lines.append(line)
        on_line(ANSI.sub("", line).rstrip())
    process.wait()
    return subprocess.CompletedProcess(process.args, process.returncode, "".join(lines), "")


def last_line(text: str) -> str:
    lines = [line for line in text.splitlines() if line.strip()]
    return lines[-1] if lines else ""


def bootstrap(compiler: Path, out: Path) -> subprocess.CompletedProcess:
    """tools/bootstrap.sh and its PowerShell twin are the one pair that stays a
    shell script: they hand-link a compiler generation, which is the step that
    must not go through any existing binary's idea of the toolchain."""
    if WINDOWS:
        shell = shutil.which("pwsh") or shutil.which("powershell")
        return run([shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                    REPO / "tools" / "bootstrap.ps1", "-Compiler", compiler, "-Out", out])
    return run(["bash", REPO / "tools" / "bootstrap.sh",
                "--compiler", compiler, "--out", out])


def check_source_lists() -> None:
    step("source lists agree")
    result = run([sys.executable, "tools/check_source_lists.py"])
    ok() if result.returncode == 0 else bad(last_line(result.stdout + result.stderr))


def check_generations(rc: Path, work: Path) -> "tuple":
    step("two-generation bootstrap")
    g1, g2 = work / f"g1{EXE}", work / f"g2{EXE}"
    progress("generation 1/2")
    first = bootstrap(rc, g1)
    if first.returncode == 0:
        progress("generation 2/2")
    second = bootstrap(g1, g2) if first.returncode == 0 else first
    if first.returncode == 0 and second.returncode == 0:
        ok()
    else:
        bad(last_line((second.stdout or "") + (second.stderr or "")))
    return g1, g2


def check_fixpoint(g1: Path, g2: Path, work: Path) -> Path:
    step("compiler IR fixpoint")
    a, b = work / "a.ll", work / "b.ll"
    progress("emit IR \u00b7 generation 1/2")
    first = run([g1, "build", "src/main.psm", "-o", a])
    progress("emit IR \u00b7 generation 2/2")
    second = run([g2, "build", "src/main.psm", "-o", b])
    progress("comparing")
    if (first.returncode == 0 and second.returncode == 0
            and a.is_file() and b.is_file() and filecmp.cmp(a, b, shallow=False)):
        ok("byte-identical")
    else:
        bad("a.ll != b.ll")
    return a


def check_rc_reproduces(rc: Path, generation_one_ir: Path, work: Path) -> None:
    step("RC reproduces itself")
    produced = work / "rc.ll"
    progress("emit IR \u00b7 candidate")
    result = run([rc, "build", "src/main.psm", "-o", produced])
    if (result.returncode == 0 and produced.is_file() and generation_one_ir.is_file()
            and filecmp.cmp(produced, generation_one_ir, shallow=False)):
        ok("the frozen binary emits generation 1's IR")
    else:
        bad("the frozen RC is not the fixpoint")


def check_seed(rc: Path, work: Path) -> None:
    """The committed seed still builds a compiler from this tree -- the path a
    machine with no Prismio at all takes, and the one CLAUDE.md's two-step rule
    for new syntax protects. It used to run `rc bootstrap`, which asked the RC
    rather than the seed, and that command is gone."""
    step("seed agreement")
    progress("building from the seed")
    if WINDOWS:
        shell = shutil.which("pwsh") or shutil.which("powershell")
        result = run([shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                      REPO / "tools" / "bootstrap.ps1", "-Seed", REPO / "bootstrap" / "prismio-seed-0.1.0.ll",
                      "-Out", work / f"seedchk{EXE}"])
    else:
        result = run(["bash", REPO / "tools" / "bootstrap.sh", "--seed",
                      "--out", work / f"seedchk{EXE}"])
    ok("committed seed builds the compiler") if result.returncode == 0 \
        else bad(last_line(result.stdout + result.stderr))


def check_suite(rc: Path) -> None:
    step("full suite")
    counted = {"failed": 0}

    def on_line(line: str) -> None:
        # The runner prints `  [ 123/512] ( 24%) ok   0.12s  name` as each test lands.
        landed = re.match(r"\s*\[\s*(\d+)/(\d+)\]\s+\(\s*\d+%\)\s+(ok|FAIL)\s+\S+\s+(.*)", line)
        if landed:
            done, total, outcome, name = landed.groups()
            counted["failed"] += outcome == "FAIL"
            tail = f" \u00b7 {counted['failed']} failed" if counted["failed"] else ""
            progress(f"{done}/{total} tests{tail} \u00b7 {name}")
        elif "Running file fixtures" in line:
            progress("starting the fixtures")

    progress("collecting tests")
    result = run_streaming([sys.executable, "test_runner.py"], on_line, cwd=str(REPO / "tests"),
                           env={**os.environ, "PRISMIO": str(rc)})
    output = result.stdout + result.stderr
    passed = re.search(r"Passed: (\d+)", output)
    failures = re.search(r"Failed: (\d+)", output)
    if passed and failures and failures.group(1) == "0":
        ok(f"{passed.group(1)}/{passed.group(1)}")
    else:
        bad(f"{passed.group(1) if passed else '?'} passed, "
            f"{failures.group(1) if failures else '?'} failed")


def check_differential(rc: Path) -> None:
    step("AIF oracle differential")
    compared = {"n": 0}

    def on_line(line: str) -> None:
        line = line.strip()
        if line.startswith(("agree", "DIFFER")):
            compared["n"] += 1
            progress(f"{compared['n']} comparisons \u00b7 {line.split()[1]}")

    progress("starting")
    result = run_streaming([sys.executable, "tools/aif_differential.py", "--compiler", rc], on_line)
    summary = last_line(result.stdout + result.stderr)
    ok(summary) if "agree on all" in summary else bad(summary)


def check_corpus(rc: Path, work: Path) -> None:
    step("corpus builds and runs")
    ran, broke = 0, []
    sources = [source for source in sorted((REPO / "aif" / "corpus").glob("*.psm"))
               if source.stem not in ("g6_engine", "g6_engine_tuned")]
    for number, source in enumerate(sources, 1):
        stem = source.stem
        binary = work / f"{stem}{EXE}"
        progress(f"{number}/{len(sources)} \u00b7 building {stem}")
        if run([rc, "build", source, "-o", binary]).returncode != 0:
            broke.append(f"build:{stem}")
            continue
        progress(f"{number}/{len(sources)} \u00b7 running {stem}")
        if run([binary]).returncode != 0:
            broke.append(f"run:{stem}")
            continue
        ran += 1
    ok(f"{ran} programs") if not broke else bad(" ".join(broke))


VERIFY_SWEEP = [
    "aif/corpus/g1_particles.psm", "aif/corpus/g3_scene_graph.psm",
    "aif/corpus/g4_ecs_world.psm", "aif/corpus/g5_asset_cache.psm",
    "aif/corpus/g6_game.psm", "aif/corpus/g9_bands.psm",
    "tests/test_96_channels.psm", "tests/test_97_generic_annotation.psm",
]


def check_verify_sweep(rc: Path, work: Path) -> None:
    step("--verify sweep")
    leaky = []
    for number, relative in enumerate(VERIFY_SWEEP, 1):
        stem = Path(relative).stem
        binary = work / f"{stem}-v{EXE}"
        progress(f"{number}/{len(VERIFY_SWEEP)} \u00b7 {stem}")
        if run([rc, "build", relative, "--verify", "-o", binary]).returncode != 0:
            leaky.append(f"build:{stem}")
            continue
        reported = [line for line in run([binary]).stderr.splitlines() if "aif-verify:" in line]
        line = reported[-1] if reported else ""
        if not line.endswith("0 leaked, 0 violation(s)"):
            leaky.append(f"{stem}[{line}]")
    ok("0 leaked / 0 violations on every program") if not leaky else bad(" ".join(leaky))


def check_environment_switch(rc: Path, work: Path, label: str, variable: str,
                             source: str, expected: str) -> None:
    step(label)
    binary = work / (label.replace(" ", "-") + EXE)
    progress(f"building with {variable}=0")
    built = run([rc, "build", source, "-o", binary], env={**os.environ, variable: "0"})
    if built.returncode != 0:
        bad()
        return
    progress("running it")
    ok() if expected in run([binary]).stdout else bad()


def check_jit(rc: Path) -> None:
    step("JIT")
    progress("test_96_channels")
    result = run([rc, "run", "tests/test_96_channels.psm", "--jit"])
    ok() if "PASS: channels" in (result.stdout + result.stderr) else bad()


def check_cross_target(rc: Path, work: Path) -> None:
    step("cross-target")
    # The sysroot is not optional and the diagnostic says so: without an SDK for
    # the target there is no C library, so the runtime cannot be compiled from
    # source for it and `stdio.h` is not found. Omitting it read as a compiler
    # failure.
    sdk = ""
    if shutil.which("xcrun"):
        probe = subprocess.run(["xcrun", "--show-sdk-path"], capture_output=True, text=True)
        sdk = probe.stdout.strip() if probe.returncode == 0 else ""
    if not sdk:
        skip("no SDK on this host")
        return
    binary = work / f"g1-x86{EXE}"
    progress("building g1_particles")
    built = run([rc, "build", "aif/corpus/g1_particles.psm",
                 "--target", "x86_64-apple-macos", "--sysroot", sdk, "-o", binary])
    described = subprocess.run(["file", str(binary)], capture_output=True, text=True).stdout
    ok("x86_64-apple-macos built") if built.returncode == 0 and "x86_64" in described \
        else bad(last_line(built.stdout + built.stderr))


def check_packaging(rc: Path, work: Path) -> None:
    step("packaged toolchain")
    dist = work / "dist"
    progress("packaging")
    packaged = run([sys.executable, "tools/package.py", "--compiler", rc, "--out", dist])
    if packaged.returncode != 0:
        bad(last_line(packaged.stdout + packaged.stderr))
        return
    progress("verifying separation")
    separated = run([sys.executable, "tools/verify_separation.py", "--dist", dist])
    ok(last_line(separated.stdout)) if separated.returncode == 0 \
        else bad(last_line(separated.stdout + separated.stderr))


# **The hand-tuned arms are diffed too, and that is not padding.** This list
# covered only the natural programs until 2026-08-30, and a container change that
# improved every one of them regressed hand-tuned g4 by 46% -- 20.5ms to 30.1ms,
# slower than the natural program -- while this gate printed green. The tuned
# sources fuse loops and reuse buffers, so they exercise shapes the natural ones
# do not have. See aif/evidence/RESULTS-flat-list-loop-guard.md.
def mnemonic_diff(rc: Path, old: Path, work: Path) -> None:
    # Mnemonics, not `.ll` text. Alias metadata changes the IR of nearly every
    # program without changing one instruction, so a textual diff here reports 21
    # "moved" programs and says nothing about any of them. This is the diff the
    # release bar actually asks to read before a timing is believed.
    step("mnemonic diff vs " + old.name)
    source = REPO / "benchmarks" / "prismio" / "suite.psm"
    before, after = work / f"benchmarks-old{EXE}", work / f"benchmarks-new{EXE}"
    progress("building suite \u00b7 baseline")
    if run([old, "build", source, "-o", before]).returncode != 0:
        bad(f"the baseline ({old}) cannot build the benchmark suite")
        return
    progress("building suite \u00b7 candidate")
    if run([rc, "build", source, "-o", after]).returncode != 0:
        bad("the candidate cannot build the benchmark suite")
        return
    progress("diffing")
    diffed = run([sys.executable, "tools/fn_mnemonic_diff.py", before, after])
    lines = diffed.stdout.splitlines()
    ok(f"benchmark suite: {lines[0]}" if lines else "benchmark suite")


def report(started: float, embedded: bool, candidate: Path) -> None:
    elapsed = time.monotonic() - started
    failures = [r for r in results if r[1] == "fail"]
    if failures:
        print()
        print("  " + ui.heading("Failures"))
        for label, _, detail in failures:
            print(f"    {ui.glyph('fail')} {ui.style(label, 'bold')}")
            for line in (detail or "failed").splitlines():
                print(f"        {ui.style(line, 'red')}")
    skipped = sum(1 for r in results if r[1] == "skip")
    tally = f"{len(results)} checks \u00b7 {len(results) - len(failures) - skipped} passed"
    if skipped:
        tally += f" \u00b7 {skipped} skipped"
    if failures:
        tally += f" \u00b7 {len(failures)} failed"
    if not ui.FANCY:
        tally = tally.replace("\u00b7", "|")
    print()
    print(ui.rule())
    print(f"  {tally}   {ui.style(ui.duration(elapsed), 'dim')}")
    if not embedded:
        print()
        print("  " + ui.verdict(not failed, str(candidate)))


def main() -> int:
    parser = argparse.ArgumentParser(description="The v0.1 release-candidate gate.")
    parser.add_argument("--rc", required=True)
    parser.add_argument("--old")
    parser.add_argument("--embedded", action="store_true",
                        help="run under tools/gate.py, which prints the heading and the verdict")
    args = parser.parse_args()

    candidate = Path(args.rc).resolve()
    # The RC as packaged is `bin/prismio`, and a compiler of that name run inside
    # the checkout forwards to the project host: every step measured that host,
    # and passed only while it happened to be built from the same tree. The
    # cross-target build is what showed it -- the host's toolchain has no
    # x86_64 runtime. A copy under another name beside it keeps the layout.
    neutral, copy = under_neutral_name(str(candidate))
    rc = Path(neutral)
    old = Path(args.old).resolve() if args.old else None
    work = Path(tempfile.mkdtemp(prefix="prismio-gate-"))
    started = time.monotonic()
    if not args.embedded:
        print(ui.heading("Release gate") + "  " + ui.style(str(candidate), "dim"))
        print()
    state = {}

    def generations() -> None:
        state["g1"], state["g2"] = check_generations(rc, work)

    def fixpoint() -> None:
        state["ir"] = check_fixpoint(state["g1"], state["g2"], work)

    plan = [
        check_source_lists,
        generations,
        fixpoint,
        lambda: check_rc_reproduces(rc, state["ir"], work),
        lambda: check_seed(rc, work),
        lambda: check_suite(rc),
        lambda: check_differential(rc),
        lambda: check_corpus(rc, work),
        lambda: check_verify_sweep(rc, work),
        lambda: check_environment_switch(rc, work, "curated runtime off", "PRISMIO_INLINE_RUNTIME",
                                         "aif/corpus/g4_ecs_world.psm", "entities: 1500"),
        lambda: check_environment_switch(rc, work, "object cache off", "PRISMIO_OBJ_CACHE",
                                         "aif/corpus/g1_particles.psm", "alive: 2000"),
        lambda: check_jit(rc),
        lambda: check_cross_target(rc, work),
        lambda: check_packaging(rc, work),
    ]
    if old:
        plan.append(lambda: mnemonic_diff(rc, old, work))
    global expected
    expected = len(plan)
    try:
        for check in plan:
            check()
    finally:
        shutil.rmtree(work, ignore_errors=True)
        if copy:
            os.remove(copy)

    report(started, args.embedded, candidate)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
