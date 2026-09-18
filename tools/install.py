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
    <prefix>/lib/runtime/  module-level runtime bitcode
    <prefix>/lib/          compiler backend archive, plus runtime.hash
    <prefix>/stdlib/       one compiled .plib artifact per standard module

That is what package.py produces, and both of the compiler's search rules are
built around it: find_in_lib_dir tries `<exe_dir>/../lib`, and standardModulePath
tries `<exe_dir>/../stdlib` (build_driver.c and driver/imports.psm respectively).

This deliberately does **not** reproduce the flat Windows layout the PowerShell
installer used, where prismio.exe sat at the top level beside the LLVM tools
already on PATH. That shape put `<exe_dir>/..` one level too high, so a flat
install could never find its own `stdlib/` -- and the PowerShell installer never
copied one, which is why the gap went unnoticed: it only ever wrote over an
installation that already had the standard library in place.

Runtime bitcode is mandatory. A missing or corrupt module is an incomplete
installation and the compiler asks the user to reinstall instead of silently
building a different runtime from embedded sources.
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
LIB_FILES = ["backend.lib", "backend.a", "runtime.hash"]
RUNTIME_MODULES = ["lang_runtime", "program_support"]

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

    for name in LIB_FILES:
        origin = dist / "lib" / name
        if origin.is_file():
            shutil.copyfile(origin, lib_dir / name)
            print(f"  lib/{name:<14} {(lib_dir / name).stat().st_size:>10} bytes")

    # Windows only: the compiler links LLVM through an import library, and
    # loads the DLL from beside itself. Everywhere else LLVM is inside it.
    dll = source.parent / "LLVM-C.dll"
    if WINDOWS and dll.is_file():
        shutil.copyfile(dll, bin_dir / dll.name)
        print(f"  {dll.name:<14} {(bin_dir / dll.name).stat().st_size:>10} bytes")

    # An install made before LLVM was linked in recorded the build machine's
    # LLVM here, and a compiler that found it would still use that clang.
    stale = prefix / "third_party" / "llvm-paths.json"
    if stale.is_file():
        stale.unlink()

    runtime_source = dist / "lib" / "runtime"
    runtime_dest = lib_dir / "runtime"
    runtime_dest.mkdir(parents=True, exist_ok=True)
    bitcode_modules = sorted(runtime_source.glob("*.bc"))
    required_runtime = {
        f"{name}{variant}.bc"
        for name in RUNTIME_MODULES
        for variant in ("", ".verify")
    }
    present_runtime = {module.name for module in bitcode_modules}
    missing_runtime = sorted(required_runtime - present_runtime)
    if missing_runtime:
        print(f"{RED}incomplete package: missing runtime module(s): "
              f"{', '.join(missing_runtime)}{RESET}", file=sys.stderr)
        return 1
    for module in bitcode_modules:
        shutil.copyfile(module, runtime_dest / module.name)
    print(f"  lib/runtime/   {len(bitcode_modules):>10} bitcode modules")

    # Each importable standard module ships as one PLIB containing its frontend
    # interface/generic templates and its LLVM bitcode implementation.
    modules = sorted((dist / "stdlib").glob("*.plib"))
    if not modules:
        print(f"{RED}incomplete package: no standard-library PLIB modules{RESET}",
              file=sys.stderr)
        return 1
    for stale_source in stdlib_dir.glob("*.psm"):
        stale_source.unlink()
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
