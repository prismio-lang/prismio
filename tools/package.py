#!/usr/bin/env python3
"""Assemble an installed Prismio toolchain.

    python tools/package.py --compiler build/gen2 --out dist/Prismio
    python tools/package.py --compiler build/gen2 --out dist/Prismio \
        --target x86_64-apple-macos --sysroot x86_64-apple-macos=$(xcrun --show-sdk-path)

Produces:

    <out>/bin/prismio[.exe]
    <out>/lib/runtime/*.bc            linked into user IR before optimisation
    <out>/lib/runtime/<triple>/*.bc   the same, for each --target
    <out>/stdlib/*.plib               a code section for the host and each --target
    <out>/bin/LLVM-C.dll              Windows only; elsewhere LLVM is linked in

**No LLVM is needed where the package is installed.** The compiler links the
pinned LLVM statically (tools/setup_llvm.py), optimises and generates code in
process, and hands the finished object to the system's own linker driver. What
the package used to carry instead -- `third_party/llvm-paths.json`, naming the
*build machine's* LLVM for a `clang` it then ran -- is gone.

**A cross build needs both halves for its triple**, and each is looked up by the
triple exactly as the build spells it: `--target x86_64-apple-macos` here and in
`prismio build` must be the same string. A target is packaged by compiling the
runtime for it, which needs that target's C headers -- hence `--sysroot`, which is
where *this* machine keeps them.

What a toolchain carries beside the compiler -- runtime bitcode, freestanding
sources, compiled standard modules -- is tools/toolchain_layout.psm's, which this
runs; this script adds the compiler, the LLVM DLL and the language server. The
runtime/backend split holds there: each runtime translation unit is its own LLVM
bitcode module, and the compiler's own C -- its backend -- ships inside the
compiler binary and nowhere else. It used to ship a second time as lib/backend.a, which nothing a
user does can link; the compiler is built from its checkout's build.ums, which
names those sources. A user build merges only the runtime modules and imported
PLIB modules into its LLVM module before the final optimisation pass;
tools/verify_separation.py checks that no compiler backend symbol reaches a user
binary.

One file rather than the .sh/.ps1 pair it replaces: the platform differences are
four lines (archive extension, archiver, executable name, exec bit), and two
implementations of one packaging policy is two things to keep in step.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from executable import resolve_executable

REPO = Path(__file__).resolve().parent.parent
WINDOWS = os.name == "nt"

GREEN = "" if WINDOWS else "\033[32m"
RED = "" if WINDOWS else "\033[31m"
RESET = "" if WINDOWS else "\033[0m"

# Must match PRISMIO_MACOS_FLOOR in runtime/llvm-api-backend.c, which is the
# macOS a program is built for. The runtime bitcode and every .plib carry it as
# well: clang would otherwise compile them for its SDK's version, the merged
# program would need the build machine's macOS, and the merge would warn about
# two target triples. tools/check_source_lists.py compares the two.
MACOS_FLOOR = "11.0"

def die(message: str) -> "NoReturn":
    print(f"{RED}FAILED: {message}{RESET}", file=sys.stderr)
    raise SystemExit(1)


def llvm_bin() -> str:
    configured = os.environ.get("PRISMIO_LLVM_DIR")
    if configured:
        return str(Path(configured) / "bin")
    try:
        paths = REPO / "third_party" / "llvm-paths.json"
        return json.loads(paths.read_text(encoding="utf-8"))["bin"]
    except (KeyError, ValueError, OSError):
        die("no LLVM toolchain configured (run tools/setup_llvm.py)")


def hosted_env() -> dict:
    """package.py must use the compiler it names. From inside a Prismio checkout an ordinary
    invocation of a binary called `prismio` is otherwise forwarded to the project's hosted
    compiler, which can silently package a different generation."""
    return dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")


def lay_out_toolchain(compiler: Path, installed: Path, out: Path, args) -> None:
    """Runtime bitcode, freestanding sources and compiled standard modules, by the tool that
    says what a toolchain carries (tools/toolchain_layout.psm). `compiler` builds the tool --
    the checkout's own `toolchain-layout` target, which compiles the runtime from source, so it
    needs no installed runtime -- and `installed` compiles what goes into the package."""
    env = hosted_env()
    built = subprocess.run([str(compiler), "build", "toolchain-layout"], cwd=str(REPO), env=env,
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
    if built.returncode != 0:
        die("could not build tools/toolchain_layout.psm:\n" + (built.stdout + built.stderr)[-3000:])
    tool = REPO / ".prismio" / "build" / "debug" / ("toolchain-layout.exe" if WINDOWS else "toolchain-layout")
    command = [str(tool), "--compiler", str(installed), "--out", str(out)]
    for triple in args.target:
        command += ["--target", triple]
    for entry in args.sysroot:
        command += ["--sysroot", entry]
    for triple in args.freestanding_target:
        command += ["--freestanding-target", triple]
    # Everything is rebuilt: a package is never assembled from another run's cache.
    result = subprocess.run(command, cwd=str(REPO), env=dict(env, PRISMIO_TOOLCHAIN_CACHE="0"),
                            capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        die("could not lay out the toolchain:\n" + (result.stdout + result.stderr)[-3000:])
    # The tool's own cache record belongs to a build directory, not to a package.
    (out / "lib" / "toolchain.stamp").unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Assemble an installed Prismio toolchain.")
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--repo")
    parser.add_argument("--target", action="append", default=[],
                        help="also package the runtime and stdlib for this triple")
    parser.add_argument("--sysroot", action="append", default=[], metavar="TRIPLE=PATH",
                        help="where this machine keeps the C headers for a --target")
    parser.add_argument("--freestanding-target", action="append", default=[], metavar="TRIPLE",
                        help="package the freestanding subset of the stdlib, and the failure "
                             "core, for this bare-metal triple; needs no sysroot")
    args = parser.parse_args()

    # Set, not defaulted: the package is used by programs built without the
    # variable, so a value in the packager's shell must not reach the bitcode.
    # The layout tool, its clang and the compiler that builds the .plib code all
    # read it, for the host and for a `--target` naming macOS without a version.
    if sys.platform == "darwin":
        os.environ["MACOSX_DEPLOYMENT_TARGET"] = MACOS_FLOOR

    for entry in args.sysroot:
        triple, sep, _ = entry.partition("=")
        if not sep or triple not in args.target:
            die(f"--sysroot {entry}: expected TRIPLE=PATH naming a --target")
    if len(set(args.target)) != len(args.target):
        die("a --target was given twice")
    if set(args.target) & set(args.freestanding_target):
        die("a triple cannot be both a --target and a --freestanding-target")

    global REPO
    if args.repo:
        REPO = Path(args.repo).resolve()

    compiler = resolve_executable(args.compiler)
    if not compiler.is_file():
        die(f"no compiler at {compiler}")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    out = out.resolve()

    bin_dir = out / "bin"
    lib = out / "lib"
    stdlib = out / "stdlib"
    # Repackaging into an existing output must not leave the previous layout beside the new one.
    for directory in (lib, stdlib):
        shutil.rmtree(directory, ignore_errors=True)
    bin_dir.mkdir(parents=True, exist_ok=True)

    installed = bin_dir / ("prismio.exe" if WINDOWS else "prismio")
    shutil.copyfile(compiler, installed)
    if not WINDOWS:
        installed.chmod(0o755)

    # An older package wrote the build machine's LLVM location here, and a
    # compiler finding it would still take that machine's clang for granted.
    stale = out / "third_party"
    if stale.is_dir():
        shutil.rmtree(stale)

    # Windows links LLVM-C.lib, an import library, so the DLL travels with the
    # compiler -- the same copy tools/bootstrap.py makes beside every
    # generation.
    if WINDOWS:
        dll = Path(llvm_bin()) / "LLVM-C.dll"
        if not dll.is_file():
            die(f"no LLVM-C.dll at {dll} (run tools/setup_llvm.py)")
        shutil.copyfile(dll, bin_dir / dll.name)

    lay_out_toolchain(compiler, installed, out, args)

    # The language server is a program of its own (lsp/main.psm), built with the compiler it
    # ships beside. After the libraries and standard modules, which building any program reads.
    build_language_server(installed, bin_dir)

    print(f"{GREEN}Packaged toolchain at {out}{RESET}")
    for path in sorted(p for p in out.rglob("*") if p.is_file()):
        print(f"  {path.relative_to(out)}")
    return 0


def build_language_server(compiler, bin_dir):
    """Compile lsp/main.psm to bin/prismio-lsp with the packaged compiler.

    PRISMIO_INTERNAL_HOSTED keeps a binary named `prismio` from handing the build to the
    checkout's project host, which would build it with a different compiler than the one
    being shipped.
    """
    target = bin_dir / ("prismio-lsp.exe" if WINDOWS else "prismio-lsp")
    result = subprocess.run([str(compiler), "build", str(REPO / "lsp" / "main.psm"), "-o", str(target)],
                            env=hosted_env(), capture_output=True, text=True)
    if result.returncode != 0:
        die("could not build the language server (lsp/main.psm):\n" + result.stderr[-2000:])
    print(f"  {'prismio-lsp':<12} {target.stat().st_size} bytes  <- lsp/main.psm")


if __name__ == "__main__":
    sys.exit(main())
