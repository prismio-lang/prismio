#!/usr/bin/env python3
"""Assemble an installed Prismio toolchain.

    python tools/package.py --compiler build/gen2 --out dist/Prismio

Produces:

    <out>/bin/prismio[.exe]
    <out>/lib/runtime.{a,lib}    linked into every compiled program
    <out>/lib/backend.{a,lib}    linked into the compiler only
    <out>/stdlib/

The runtime/backend split is enforced here, at the point the libraries are
built: runtime gets lang_runtime.c + program_support.c, backend gets everything
else. Because a compiled program links only the runtime archive (see
find_runtime_library and link_against_runtime_library in build_driver.c), no
ir_* backend symbol can reach a user binary -- tools/verify_separation.py checks
that against the produced artifacts.

One file rather than the .sh/.ps1 pair it replaces: the platform differences are
four lines (archive extension, archiver, executable name, exec bit), and two
implementations of one packaging policy is two things to keep in step.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WINDOWS = os.name == "nt"

GREEN = "" if WINDOWS else "\033[32m"
RED = "" if WINDOWS else "\033[31m"
RESET = "" if WINDOWS else "\033[0m"

# Must match prismio_toolchain_files[] in runtime/build_driver.c.
# tools/check_source_lists.py parses this table and compares it against that one.
LIBRARIES = {
    "runtime": ["lang_runtime.c", "program_support.c"],
    "backend": [
        "build_driver.c",
        "ir_symbols.c",
        "aif_containers.c",
        "aif_support.c",
        "diagnostics.c",
        "llvm-api-backend.c",
    ],
}


def die(message: str) -> "NoReturn":
    print(f"{RED}FAILED: {message}{RESET}", file=sys.stderr)
    raise SystemExit(1)


def run(label: str, command: list) -> None:
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"{RED}FAILED: {label}{RESET}", file=sys.stderr)
        for line in (result.stdout + result.stderr).splitlines():
            print(f"  {line}", file=sys.stderr)
        raise SystemExit(1)


def find_archiver() -> list:
    """`llvm-lib` writes MSVC-style .lib, `ar` writes GNU-style .a.

    find_toolchain_library() accepts either and prefers the platform-native one,
    so a toolchain packaged on one platform still resolves if it is copied to
    another. llvm-ar is the fallback for a bare LLVM install with no binutils or
    Xcode beside it; both it and ar write the same format.
    """
    if WINDOWS:
        tool = shutil.which("llvm-lib")
        if not tool:
            die("llvm-lib not found on PATH")
        return [tool]
    tool = shutil.which("ar") or shutil.which("llvm-ar")
    if not tool:
        die("neither ar nor llvm-ar found on PATH")
    return [tool, "rcs"]


def build_archive(name: str, sources: list, lib: Path, work: Path, archiver: list) -> None:
    objects = []
    for source in sources:
        obj = work / (Path(source).stem + (".obj" if WINDOWS else ".o"))
        run(f"cc {source}", ["clang", "-Wno-deprecated-declarations",
                             "-c", str(REPO / "runtime" / source), "-o", str(obj)])
        objects.append(str(obj))

    archive = lib / (name + (".lib" if WINDOWS else ".a"))
    if archive.exists():
        archive.unlink()
    if WINDOWS:
        run(f"lib {name}", archiver + [f"/OUT:{archive}"] + objects)
    else:
        run(f"ar {name}", archiver + [str(archive)] + objects)
    print(f"  {archive.name:<12} {archive.stat().st_size:>8} bytes  <- {' + '.join(sources)}")


def runtime_hash(compiler: Path) -> str:
    """Computed by the compiler itself rather than reimplemented here, so the
    packaging step and the freshness check cannot disagree about how the hash is
    derived. Run from the repository, because it hashes the sources on disk."""
    result = subprocess.run([str(compiler), "runtime-hash"],
                            capture_output=True, text=True, cwd=str(REPO))
    value = result.stdout.strip().splitlines()[-1].strip() if result.stdout.strip() else ""
    if result.returncode != 0 or not re.fullmatch(r"[0-9a-f]{16}", value):
        die(f"could not compute runtime hash ({value})")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Assemble an installed Prismio toolchain.")
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--repo")
    args = parser.parse_args()

    global REPO
    if args.repo:
        REPO = Path(args.repo).resolve()

    if not shutil.which("clang"):
        die("clang not found on PATH")

    compiler = Path(args.compiler).resolve()
    if not compiler.is_file():
        die(f"no compiler at {compiler}")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    out = out.resolve()

    bin_dir, lib, stdlib, work = out / "bin", out / "lib", out / "stdlib", out / ".objs"
    for directory in (bin_dir, lib, stdlib, work):
        directory.mkdir(parents=True, exist_ok=True)

    archiver = find_archiver()
    for name, sources in LIBRARIES.items():
        build_archive(name, sources, lib, work, archiver)

    installed = bin_dir / ("prismio.exe" if WINDOWS else "prismio")
    shutil.copyfile(compiler, installed)
    if not WINDOWS:
        installed.chmod(0o755)
    shutil.rmtree(work)

    # Recorded beside the libraries so a later build can tell whether they still
    # match the sources on disk.
    value = runtime_hash(compiler)
    (lib / "runtime.hash").write_text(value, encoding="ascii")
    print(f"  {'runtime.hash':<12} {value}")

    # The self-hosted standard library ships as source and is loaded by the
    # compiler. The installed directory is named `stdlib` independently of the
    # repository's concise source root `std`.
    for module in sorted((REPO / "std").glob("*.psm")):
        shutil.copyfile(module, stdlib / module.name)

    print(f"{GREEN}Packaged toolchain at {out}{RESET}")
    for path in sorted(p for p in out.rglob("*") if p.is_file()):
        print(f"  {path.relative_to(out)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
