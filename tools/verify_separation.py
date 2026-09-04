#!/usr/bin/env python3
"""Verify the runtime/backend boundary against real artifacts.

    python tools/verify_separation.py --dist dist/Prismio

**Called by `run_runtime_library_test`**, against the toolchain that test
packages, so a break in here fails the suite. It did not used to be called by
anything, and spent two days unable to compile its own probe.

The rule being checked: the LLVM backend is a compiler-only component. A program
compiled by Prismio links the runtime archive and nothing else, so no backend
symbol may appear in a user binary -- while the compiler itself must contain the
backend.

Two independent checks, because they can fail separately:

  1. Archive symbol tables (nm) -- proves the libraries were built from the right
     translation units in the first place.
  2. A byte signature in the produced executable -- proves the *link step* only
     pulled in the runtime. A linked binary's symbol table says nothing about
     which static-archive members were folded in, so nm cannot answer this one;
     instead look for IR-emitter strings that exist only in llvm-api-backend.c.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

WINDOWS = os.name == "nt"
GREEN = "" if WINDOWS else "\033[32m"
RED = "" if WINDOWS else "\033[31m"
RESET = "" if WINDOWS else "\033[0m"

PROBE = """import std.io

fn main() -> Int {
    println("ok")
    return 0
}
"""

# Strings only llvm-api-backend.c contributes. Searched as raw bytes rather than
# through strings(1): that tool lives in binutils, is not guaranteed to be
# installed, and when it is missing the pipeline yields no matches -- which reads
# as a clean binary and turns this whole section into a check that always passes.
BACKEND_SIGNATURES = [
    b"internal backend error: ",
    b"generated module failed verification",
    b"optimization pipeline failed",
]

failures = 0


def check(label: str, ok: bool, detail: str = "") -> None:
    global failures
    tag = f"{GREEN}[PASS]{RESET}" if ok else f"{RED}[FAIL]{RESET}"
    if not ok:
        failures += 1
    print(f"  {tag} {label}" + (f" -- {detail}" if detail else ""))


def find_library(dist: Path, stem: str):
    for extension in ("a", "lib"):
        candidate = dist / "lib" / f"{stem}.{extension}"
        if candidate.is_file():
            return candidate
    return None


def defined_symbols(nm: str, archive: Path) -> str:
    result = subprocess.run([nm, "--defined-only", str(archive)],
                            capture_output=True, text=True)
    return result.stdout


def count_occurrences(path: Path, needle: bytes) -> int:
    try:
        return path.read_bytes().count(needle)
    except OSError:
        return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify the runtime/backend boundary.")
    parser.add_argument("--dist", required=True)
    args = parser.parse_args()

    dist = Path(args.dist)
    if not dist.is_dir():
        print(f"error: no such directory: {dist}", file=sys.stderr)
        return 1
    # Absolute, because the probe build below runs from a scratch directory and a
    # relative --dist stops resolving the moment we leave this one.
    dist = dist.resolve()

    nm = shutil.which("llvm-nm") or shutil.which("nm")
    if not nm:
        print("error: neither llvm-nm nor nm found on PATH", file=sys.stderr)
        return 1

    print("Archive contents")
    runtime_lib = find_library(dist, "runtime")
    backend_lib = find_library(dist, "backend")
    check("runtime library exists", runtime_lib is not None,
          runtime_lib.name if runtime_lib else "none")
    check("backend library exists", backend_lib is not None,
          backend_lib.name if backend_lib else "none")

    if runtime_lib and backend_lib:
        runtime_symbols = defined_symbols(nm, runtime_lib)
        backend_symbols = defined_symbols(nm, backend_lib)

        # Mach-O nm prefixes C symbols with an underscore; match both flavours.
        ir_defined = re.compile(r"^\S* +[TtDdSsBb] +_?ir_[a-z]", re.M)
        in_runtime = len(ir_defined.findall(runtime_symbols))
        in_backend = len(ir_defined.findall(backend_symbols))
        check("runtime library defines no ir_* backend symbols", in_runtime == 0,
              f"found {in_runtime}")
        check("backend library defines the ir_* backend symbols", in_backend > 0,
              f"found {in_backend}")

        check("runtime library provides cli_arg_count",
              "cli_arg_count" in runtime_symbols)
        check("backend library provides compiler_build_executable",
              "compiler_build_executable" in backend_symbols)
        check("runtime library does NOT provide compiler_build_executable",
              "compiler_build_executable" not in runtime_symbols)

    print("\nCompiled user program")
    compiler = dist / "bin" / ("prismio.exe" if WINDOWS else "prismio")
    probe_dir = Path(tempfile.mkdtemp())
    try:
        source = probe_dir / "probe.psm"
        # std.io is an ordinary import rather than a prelude as of 2026-08-21, and
        # a probe without it does not compile -- which took every check below down
        # with it, because they are all guarded on the executable existing.
        source.write_text(PROBE, encoding="utf-8")
        executable = probe_dir / ("probe.exe" if WINDOWS else "probe")

        # Built from a directory with no runtime/ anywhere nearby, so a
        # source-based build could only succeed via sources embedded in the
        # binary -- which the signature check below would then catch.
        built = subprocess.run([str(compiler), "build", str(source), "-o", str(executable)],
                               capture_output=True, text=True, cwd=str(probe_dir))
        check("installed toolchain compiles a program", built.returncode == 0,
              " ".join((built.stdout + built.stderr).split()))

        if executable.is_file():
            ran = subprocess.run([str(executable)], capture_output=True, text=True)
            check("compiled program runs", ran.stdout.strip() == "ok")

            hits = []
            for signature in BACKEND_SIGNATURES:
                found = count_occurrences(executable, signature)
                if found:
                    hits.append(f"{signature.decode()} x{found}")
            check("no LLVM backend code in the user binary", not hits,
                  " ".join(hits) if hits else "clean")

            # Sanity: the same signatures must be present in the compiler,
            # otherwise the check above passes trivially for the wrong reason.
            in_compiler = count_occurrences(compiler, BACKEND_SIGNATURES[0])
            check("the compiler itself does contain the backend", in_compiler > 0,
                  f"backend signature x{in_compiler}")
    finally:
        shutil.rmtree(probe_dir, ignore_errors=True)

    print("")
    if failures:
        print(f"{RED}{failures} check(s) FAILED{RESET}")
        return 1
    print(f"{GREEN}All separation checks passed{RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
