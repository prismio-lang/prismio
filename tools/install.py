#!/usr/bin/env python3
"""Install a packaged Prismio toolchain over an existing installation.

    python tools/install.py --dist dist/Prismio
    python tools/install.py --dist dist/Prismio --prefix /opt/prismio

Needs write access to the prefix, which usually means an elevated shell on
Windows and `sudo` elsewhere. The check below is for writability rather than for
administrator or root, because that is the thing that actually decides whether
this can work -- a user-owned prefix needs neither.

**Layout**, and it is the same on every platform:

    <prefix>/bin/prismio[.exe]
    <prefix>/lib/          runtime and backend archives, plus runtime.hash
    <prefix>/stdlib/       the standard library, shipped as source

That is what package.py produces, and both of the compiler's search rules are
built around it: find_in_lib_dir tries `<exe_dir>/../lib`, and standardModulePath
tries `<exe_dir>/../stdlib` (build_driver.c and driver/imports.psm respectively).

This deliberately does **not** reproduce the flat Windows layout the PowerShell
installer used, where prismio.exe sat at the top level beside the LLVM tools
already on PATH. That shape put `<exe_dir>/..` one level too high, so a flat
install could never find its own `stdlib/` -- and the PowerShell installer never
copied one, which is why the gap went unnoticed: it only ever wrote over an
installation that already had the standard library in place.

Without `lib/` the compiler still works: it falls back to compiling the runtime
from sources embedded in the binary. That fallback is silent, which is exactly
why this verifies afterwards that the install can build and run a program.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

WINDOWS = os.name == "nt"
GREEN = "" if WINDOWS else "\033[32m"
RED = "" if WINDOWS else "\033[31m"
YELLOW = "" if WINDOWS else "\033[33m"
RESET = "" if WINDOWS else "\033[0m"

DEFAULT_PREFIX = r"C:\Program Files\Prismio" if WINDOWS else "/usr/local"
EXE = "prismio.exe" if WINDOWS else "prismio"
ARCHIVES = ["runtime.lib", "backend.lib", "runtime.a", "backend.a", "runtime.hash"]

PROBE = """import std.io

fn main() -> Int {
    println("ok")
    return 0
}
"""


def writable(directory: Path) -> bool:
    """Whether this process could create the install. Walks up to the nearest
    existing ancestor, because the prefix itself may not exist yet."""
    probe = directory
    while not probe.exists() and probe != probe.parent:
        probe = probe.parent
    return os.access(probe, os.W_OK)


def main() -> int:
    parser = argparse.ArgumentParser(description="Install a packaged Prismio toolchain.")
    parser.add_argument("--dist", required=True)
    parser.add_argument("--prefix", default=DEFAULT_PREFIX)
    args = parser.parse_args()

    dist = Path(args.dist)
    if not dist.is_dir():
        print(f"{RED}no such directory: {dist}{RESET}", file=sys.stderr)
        return 1
    dist = dist.resolve()

    source = dist / "bin" / EXE
    if not source.is_file():
        print(f"{RED}no {EXE} in {dist / 'bin'}{RESET}", file=sys.stderr)
        return 1

    prefix = Path(args.prefix)
    if not writable(prefix):
        print(f"{YELLOW}{prefix} is not writable by this process.{RESET}")
        hint = "a terminal started with 'Run as administrator'" if WINDOWS else "sudo"
        print(f"{YELLOW}Re-run under {hint}, or pass --prefix to a directory you own.{RESET}")
        return 1

    bin_dir = prefix / "bin"
    lib_dir = prefix / "lib"
    stdlib_dir = prefix / "stdlib"
    for directory in (bin_dir, lib_dir, stdlib_dir):
        directory.mkdir(parents=True, exist_ok=True)

    # Keep the outgoing binary so a bad install can be undone.
    installed = bin_dir / EXE
    backup = bin_dir / (EXE + ".bak")
    if installed.is_file() and not backup.exists():
        shutil.copyfile(installed, backup)
        print(f"  backed up previous {EXE} -> {backup.name}")

    shutil.copyfile(source, installed)
    if not WINDOWS:
        installed.chmod(0o755)
    print(f"  {EXE:<14} {installed.stat().st_size:>10} bytes")

    for name in ARCHIVES:
        origin = dist / "lib" / name
        if origin.is_file():
            shutil.copyfile(origin, lib_dir / name)
            print(f"  lib/{name:<14} {(lib_dir / name).stat().st_size:>10} bytes")

    # The standard library ships as source and is read at compile time, so an
    # install without it compiles nothing that imports `std.*` -- which is every
    # program that prints.
    modules = sorted((dist / "stdlib").glob("*.psm"))
    for module in modules:
        shutil.copyfile(module, stdlib_dir / module.name)
    print(f"  stdlib/        {len(modules):>10} modules")

    # Verified from a directory with no repository nearby, so nothing resolves by
    # accident.
    print("\nVerifying...")
    work = Path(tempfile.mkdtemp(prefix="prismio-install-"))
    try:
        probe_source = work / "probe.psm"
        # std.io is an ordinary import rather than a prelude as of 2026-08-21.
        # Without the import this probe does not compile, and the installer
        # reports a good install as a broken compiler.
        probe_source.write_text(PROBE, encoding="utf-8")
        probe_exe = work / ("probe.exe" if WINDOWS else "probe")

        built = subprocess.run([str(installed), "build", str(probe_source), "-o", str(probe_exe)],
                               capture_output=True, text=True, cwd=str(work))
        if built.returncode != 0:
            print(f"  {RED}[FAIL] installed compiler cannot build a program{RESET}")
            for line in (built.stdout + built.stderr).splitlines():
                print(f"    {line}", file=sys.stderr)
            return 1

        ran = subprocess.run([str(probe_exe)], capture_output=True, text=True)
        if ran.stdout.strip() != "ok":
            print(f"  {RED}[FAIL] compiled program did not run{RESET}")
            return 1
        print(f"  {GREEN}[PASS] compiles and runs a program{RESET}")
    finally:
        shutil.rmtree(work, ignore_errors=True)

    # The hash the compiler computes from sources must match what was recorded
    # when the libraries were built. A mismatch means lib/ is stale relative to
    # the runtime sources -- the staleness this layout exists to make visible.
    recorded = lib_dir / "runtime.hash"
    if recorded.is_file():
        print(f"  [INFO] installed runtime.hash = {recorded.read_text().strip()}")

    print(f"\n{GREEN}Installed to {prefix}{RESET}")
    if backup.exists():
        print(f"Revert with: cp {backup} {installed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
