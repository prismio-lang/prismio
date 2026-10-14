#!/usr/bin/env python3
"""The pre-push gate, in one command: what CI checks that can run on this machine.

    prismio gate
    python tools/gate.py --compiler .prismio/build/debug/prismio

Three steps, stopping at the first that fails:

  1. `tools/lint.py`, which CI runs before anything is built.
  2. Packaging the compiler the way RELEASE.md says -- a *packaged* compiler,
     because a bare generation has no `lib/runtime/*.bc` and fails every program
     the suite builds. On macOS the package also carries `x86_64-apple-macos`
     and the SDK sysroot it needs, because the gate's cross-target check builds
     for it and a package without that runtime fails the check for a reason that
     has nothing to do with the change being tested.
  3. `tools/release_gate.py` on that package, with the pinned LLVM first on PATH:
     the system's `clang` and `llvm-nm` cannot read LLVM 23 bitcode, which fails
     the packaged-toolchain check, `module_artifacts` and `target_cross`.

It does not run what only another platform or a CI runner can: Windows, the
Linux-only sanitizer smoke, the benchmark smoke, and the smoke program inlined in
`.github/workflows/ci.yml`. A green run here is the strongest local statement
short of a CI run, not a replacement for one.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

import gate_ui as ui

REPO = Path(__file__).resolve().parent.parent
EXE = ".exe" if os.name == "nt" else ""


def pinned_llvm_bin() -> str:
    paths = REPO / "third_party" / "llvm-paths.json"
    if not paths.is_file():
        return ""
    return json.loads(paths.read_text(encoding="utf-8")).get("bin", "")


def macos_cross_flags() -> list:
    """`--target`/`--sysroot` for the gate's cross-target check, or nothing."""
    if sys.platform != "darwin" or not shutil.which("xcrun"):
        return []
    probe = subprocess.run(["xcrun", "--show-sdk-path"], capture_output=True, text=True)
    sdk = probe.stdout.strip() if probe.returncode == 0 else ""
    if not sdk:
        return []
    return ["--target", "x86_64-apple-macos", "--sysroot", f"x86_64-apple-macos={sdk}"]


def shown(path) -> str:
    try:
        return str(Path(path).resolve().relative_to(REPO))
    except ValueError:
        return str(path)


def summarize_lint(output: str, out: Path) -> tuple:
    """(detail, notes): the pass line condensed, and one note per formatting warning."""
    passed = re.search(r"Lint passed \((\d+) source files, (\d+) diagnostic codes\)", output)
    detail = (f"{passed.group(1)} source files \u00b7 {passed.group(2)} diagnostic codes"
              if passed else "passed")
    unformatted = re.findall(r"^warning: format: (\S+)", output, re.MULTILINE)
    notes = []
    if unformatted:
        notes.append(("warn", f"{len(unformatted)} files need formatting",
                      "run tools/format_sources.py --write"))
        notes += [("list", name, "") for name in unformatted[:6]]
        if len(unformatted) > 6:
            notes.append(("list", f"+{len(unformatted) - 6} more", ""))
    return detail, notes


def summarize_package(output: str, out: Path) -> tuple:
    runtime = len(list((out / "lib" / "runtime").glob("*.bc")))
    stdlib = len(list((out / "stdlib").glob("*.plib")))
    return f"{runtime} runtime bitcode \u00b7 {stdlib} stdlib modules \u2192 {shown(out)}", []


def run_captured(label: str, command: list, env: dict) -> tuple:
    """Run quietly under a spinner and a running clock. -> (status, output, seconds)"""
    ticker = ui.Ticker()
    ticker.begin(label)
    started = time.monotonic()
    try:
        result = subprocess.run([str(c) for c in command], cwd=str(REPO), env=env,
                                capture_output=True, text=True)
    finally:
        ticker.end()
    return result.returncode, result.stdout + result.stderr, time.monotonic() - started


def captured_stage(label: str, command: list, env: dict, summarize, out: Path) -> tuple:
    status, output, elapsed = run_captured(label, command, env)
    if status != 0:
        print(ui.row("fail", label, f"exit {status}", elapsed), flush=True)
        for line in output.strip().splitlines():
            print("      " + ui.style(line, "dim"))
        return status, elapsed
    detail, notes = summarize(output, out)
    print(ui.row("ok", label, detail, elapsed), flush=True)
    for kind, text, hint in notes:
        if kind == "warn":
            print(ui.row("warn", text, hint, None))
        else:
            print("      " + ui.style(text, "dim"))
    return 0, elapsed


def streamed_stage(command: list, env: dict) -> tuple:
    """The release gate prints its own rows and timings; let them through live."""
    started = time.monotonic()
    status = subprocess.run([str(c) for c in command], cwd=str(REPO), env=env).returncode
    return status, time.monotonic() - started


def header(args, out: Path, llvm: str, cross: list) -> None:
    pairs = [("compiler", shown(args.compiler)), ("candidate", shown(out)),
             ("llvm", f"{shown(llvm)} (pinned)" if llvm else "from PATH"),
             ("cross", cross[1] if cross else "none")]
    print(ui.heading("Prismio gate"))
    for key, value in pairs:
        print("  " + ui.style(key.ljust(10), "dim") + value)


def main() -> int:
    parser = argparse.ArgumentParser(description="Lint, package, and run the release gate.")
    parser.add_argument("--compiler", required=True,
                        help="the compiler to package, e.g. .prismio/build/debug/prismio")
    parser.add_argument("--out", default="build/gate-rc",
                        help="where the candidate is packaged (default: build/gate-rc)")
    args = parser.parse_args()

    env = dict(os.environ)
    llvm = pinned_llvm_bin()
    if llvm:
        env["PATH"] = llvm + os.pathsep + env.get("PATH", "")

    out = Path(args.out)
    if not out.is_absolute():
        out = REPO / out
    if out.exists():
        shutil.rmtree(out)

    cross = macos_cross_flags()
    started = time.monotonic()
    header(args, out, llvm, cross)

    # (title, row label, command, summarize-or-None). `None` streams the command's own rows.
    stages = [
        ("Lint", "repository lint", [sys.executable, "tools/lint.py"], summarize_lint),
        ("Package the candidate", "toolchain layout",
         [sys.executable, "tools/package.py", "--compiler", args.compiler, "--out", out, *cross,
          # freestanding_bench links the failure core into a bare-metal build.
          "--freestanding-target", "aarch64-unknown-none-elf"],
         summarize_package),
        ("Release gate", "",
         [sys.executable, "tools/release_gate.py", "--embedded", "--rc",
          out / "bin" / f"prismio{EXE}"], None),
    ]
    done = []
    status = 0
    for index, (title, label, command, summarize) in enumerate(stages, 1):
        print()
        print(ui.banner(index, len(stages), title), flush=True)
        if summarize is None:
            status, elapsed = streamed_stage(command, env)
        else:
            status, elapsed = captured_stage(label, command, env, summarize, out)
        done.append((title, status, elapsed))
        if status != 0:
            break

    print()
    print(ui.rule())
    for title, code, elapsed in done:
        print(ui.row("ok" if code == 0 else "fail", title,
                     "" if code == 0 else "failed", elapsed))
    for title, _, _, _ in stages[len(done):]:
        print(ui.row("skip", title, "not run", None))
    print()
    total = ui.style(f"in {ui.duration(time.monotonic() - started)}", "dim")
    if status == 0:
        print("  " + ui.verdict(True, "safe to push as far as this machine can tell  ") + total)
    else:
        print("  " + ui.verdict(False, f"at: {done[-1][0]}  ") + total)
    return status


if __name__ == "__main__":
    sys.exit(main())
