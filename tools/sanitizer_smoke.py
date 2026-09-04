#!/usr/bin/env python3
"""Compile representative ownership and concurrency fixtures with AddressSanitizer.

    python tools/sanitizer_smoke.py --compiler build/gen2

Each fixture is built to IR by the compiler under test, then linked by clang
against the runtime *sources* with -fsanitize=address -- the packaged archives
are compiled without the sanitizer, so linking them would report nothing.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WINDOWS = os.name == "nt"

# Recursive release and channels must also be leak-free. The provenance fixture
# intentionally retains unbound temporaries (documented in the fixture), so its
# ASan run targets the use-after-free class that originally motivated this gate.
FIXTURES = [
    ("test_73_recursive_release.psm", True),
    ("test_92_field_view_provenance.psm", False),
    ("test_96_channels.psm", True),
]


def run_fixture(compiler: Path, work: Path, source_name: str, detect_leaks: bool) -> None:
    stem = Path(source_name).stem
    ir = work / f"{stem}.ll"
    executable = work / (f"{stem}.exe" if WINDOWS else stem)

    print(f"{source_name:<42} ", end="", flush=True)
    subprocess.run([str(compiler), "build", str(REPO / "tests" / source_name), "-o", str(ir)],
                   check=True, capture_output=True, text=True)

    link = ["clang", "-O1", "-g", "-fno-omit-frame-pointer", "-fsanitize=address",
            "-Wno-deprecated-declarations", "-Wno-override-module"]
    if not WINDOWS:
        link.append("-pthread")
    link += [str(ir),
             str(REPO / "runtime" / "lang_runtime.c"),
             str(REPO / "runtime" / "program_support.c"),
             "-I" + str(REPO / "runtime"), "-o", str(executable)]
    subprocess.run(link, check=True, capture_output=True, text=True)

    environment = dict(os.environ)
    environment["ASAN_OPTIONS"] = (
        f"detect_leaks={1 if detect_leaks else 0}:halt_on_error=1:abort_on_error=1")
    subprocess.run([str(executable)], check=True, capture_output=True, text=True,
                   env=environment)
    print("ok")


def main() -> int:
    parser = argparse.ArgumentParser(description="AddressSanitizer smoke suite.")
    parser.add_argument("--compiler", required=True)
    args = parser.parse_args()

    compiler = Path(args.compiler).resolve()
    if not compiler.is_file():
        print(f"compiler is not executable: {compiler}", file=sys.stderr)
        return 1
    if not shutil.which("clang"):
        print("clang not found on PATH", file=sys.stderr)
        return 1

    work = Path(tempfile.mkdtemp(prefix="prismio-asan-"))
    try:
        for source_name, detect_leaks in FIXTURES:
            try:
                run_fixture(compiler, work, source_name, detect_leaks)
            except subprocess.CalledProcessError as failure:
                print("FAILED")
                output = (failure.stdout or "") + (failure.stderr or "")
                for line in output.splitlines():
                    print(f"  {line}", file=sys.stderr)
                return 1
    finally:
        shutil.rmtree(work, ignore_errors=True)

    print("AddressSanitizer smoke suite passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
