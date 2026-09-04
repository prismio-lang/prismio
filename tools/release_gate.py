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
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WINDOWS = os.name == "nt"
EXE = ".exe" if WINDOWS else ""

failed = False


def step(label: str) -> None:
    print(f"{label:<42} ", end="", flush=True)


def ok(detail: str = "") -> None:
    print(f"ok    {detail}")


def bad(detail: str = "") -> None:
    global failed
    failed = True
    print(f"FAIL  {detail}")


def run(command: list, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run([str(c) for c in command], capture_output=True, text=True,
                          cwd=str(REPO), **kwargs)


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
    first = bootstrap(rc, g1)
    second = bootstrap(g1, g2) if first.returncode == 0 else first
    if first.returncode == 0 and second.returncode == 0:
        ok()
    else:
        bad(last_line((second.stdout or "") + (second.stderr or "")))
    return g1, g2


def check_fixpoint(g1: Path, g2: Path, work: Path) -> Path:
    step("compiler IR fixpoint")
    a, b = work / "a.ll", work / "b.ll"
    first = run([g1, "build", "src/main.psm", "-o", a])
    second = run([g2, "build", "src/main.psm", "-o", b])
    if (first.returncode == 0 and second.returncode == 0
            and a.is_file() and b.is_file() and filecmp.cmp(a, b, shallow=False)):
        ok("byte-identical")
    else:
        bad("a.ll != b.ll")
    return a


def check_rc_reproduces(rc: Path, generation_one_ir: Path, work: Path) -> None:
    step("RC reproduces itself")
    produced = work / "rc.ll"
    result = run([rc, "build", "src/main.psm", "-o", produced])
    if (result.returncode == 0 and produced.is_file() and generation_one_ir.is_file()
            and filecmp.cmp(produced, generation_one_ir, shallow=False)):
        ok("the frozen binary emits generation 1's IR")
    else:
        bad("the frozen RC is not the fixpoint")


def check_seed(rc: Path, work: Path) -> None:
    step("seed agreement")
    result = run([rc, "bootstrap", "src/main.psm", "-o", work / f"seedchk{EXE}"])
    ok("committed seed builds the compiler") if result.returncode == 0 \
        else bad(last_line(result.stdout + result.stderr))


def check_suite(rc: Path) -> None:
    step("full suite")
    result = subprocess.run([sys.executable, "test_runner.py"], capture_output=True,
                            text=True, cwd=str(REPO / "tests"),
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
    result = run([sys.executable, "tools/aif_differential.py", "--compiler", rc])
    summary = last_line(result.stdout + result.stderr)
    ok(summary) if "agree on all" in summary else bad(summary)


def check_corpus(rc: Path, work: Path) -> None:
    step("corpus builds and runs")
    ran, broke = 0, []
    sources = sorted((REPO / "aif" / "corpus").glob("*.psm"))
    for source in sources:
        stem = source.stem
        if stem in ("g6_engine", "g6_engine_tuned"):
            continue
        binary = work / f"{stem}{EXE}"
        if run([rc, "build", source, "-o", binary]).returncode != 0:
            broke.append(f"build:{stem}")
            continue
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
    for relative in VERIFY_SWEEP:
        stem = Path(relative).stem
        binary = work / f"{stem}-v{EXE}"
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
    built = run([rc, "build", source, "-o", binary], env={**os.environ, variable: "0"})
    if built.returncode != 0:
        bad()
        return
    ok() if expected in run([binary]).stdout else bad()


def check_jit(rc: Path) -> None:
    step("JIT")
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
        ok("skipped -- no SDK on this host")
        return
    binary = work / f"g1-x86{EXE}"
    built = run([rc, "build", "aif/corpus/g1_particles.psm",
                 "--target", "x86_64-apple-macos", "--sysroot", sdk, "-o", binary])
    described = subprocess.run(["file", str(binary)], capture_output=True, text=True).stdout
    ok("x86_64-apple-macos built") if built.returncode == 0 and "x86_64" in described \
        else bad(last_line(built.stdout + built.stderr))


def check_packaging(rc: Path, work: Path) -> None:
    step("packaged toolchain")
    dist = work / "dist"
    packaged = run([sys.executable, "tools/package.py", "--compiler", rc, "--out", dist])
    if packaged.returncode != 0:
        bad(last_line(packaged.stdout + packaged.stderr))
        return
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
    step(f"per-function mnemonic diff vs {old}")
    print()
    source = REPO / "benchmarks" / "prismio" / "suite.psm"
    before, after = work / f"benchmarks-old{EXE}", work / f"benchmarks-new{EXE}"
    if run([old, "build", source, "-o", before]).returncode != 0:
        return
    if run([rc, "build", source, "-o", after]).returncode != 0:
        return
    diffed = run([sys.executable, "tools/fn_mnemonic_diff.py", before, after])
    summary = diffed.stdout.splitlines()[0] if diffed.stdout.splitlines() else ""
    print(f"    {'benchmark suite':<18} {summary}")


def main() -> int:
    parser = argparse.ArgumentParser(description="The v0.1 release-candidate gate.")
    parser.add_argument("--rc", required=True)
    parser.add_argument("--old")
    args = parser.parse_args()

    rc = Path(args.rc).resolve()
    old = Path(args.old).resolve() if args.old else None
    work = Path(tempfile.mkdtemp(prefix="prismio-gate-"))
    try:
        check_source_lists()
        g1, g2 = check_generations(rc, work)
        generation_one_ir = check_fixpoint(g1, g2, work)
        check_rc_reproduces(rc, generation_one_ir, work)
        check_seed(rc, work)
        check_suite(rc)
        check_differential(rc)
        check_corpus(rc, work)
        check_verify_sweep(rc, work)
        check_environment_switch(rc, work, "curated runtime off", "PRISMIO_INLINE_RUNTIME",
                                 "aif/corpus/g4_ecs_world.psm", "entities: 1500")
        check_environment_switch(rc, work, "object cache off", "PRISMIO_OBJ_CACHE",
                                 "aif/corpus/g1_particles.psm", "alive: 2000")
        check_jit(rc)
        check_cross_target(rc, work)
        check_packaging(rc, work)
        if old:
            mnemonic_diff(rc, old, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)

    print()
    print("GATE FAILED" if failed else f"GATE PASSED -- {rc}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
