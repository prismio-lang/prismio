#!/usr/bin/env python3
"""Run ownership and concurrency programs under AddressSanitizer.

    python3 tools/sanitizer_smoke.py --compiler build/gen2
    python3 tools/sanitizer_smoke.py --compiler build/gen2 probes/ one.psm

Each program is built to IR by the compiler under test with `std.*` compiled from this
checkout's source (tools/source_toolchain.py), so the IR holds every Prismio function
it runs. Every function in it is marked `sanitize_address` -- clang instruments only
functions that say so, and an IR input says nothing on its own -- and it is linked by
clang against the runtime *sources* with -fsanitize=address, which also leaves the slab
allocator out of the runtime. The packaged archives are compiled without the sanitizer,
so linking them would report nothing.

Without paths it runs the fixtures below and `tests/harness/aif.py`'s ownership probes,
each of which must exit 0. A path (a file, or a directory of `.psm` files) adds programs
that are only checked for a sanitizer report or a signal. `--build-flag` passes a flag to every
build (`--build-flag=--pir=plan`).

LeakSanitizer is asked for on Linux, and only of the fixtures that are held leak-free.
"""
import argparse
import concurrent.futures
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from executable import resolve_executable
from source_toolchain import source_toolchain

REPO = Path(__file__).resolve().parent.parent
WINDOWS = os.name == "nt"

sys.path.insert(0, str(REPO / "tests"))
from harness.aif import OWNERSHIP_PROBES  # noqa: E402

# Recursive release and channels must also be leak-free. The provenance fixture
# intentionally retains unbound temporaries (documented in the fixture), so its
# ASan run targets the use-after-free class that originally motivated this gate.
# The push guard fixture builds every list with exactly the room its loop needs
# or one element less. It checks `length <= capacity` itself, since an arena
# chunk hides an overrun from ASan; a list on the heap overruns visibly here.
FIXTURES = [
    ("test_73_recursive_release.psm", True),
    ("test_92_field_view_provenance.psm", False),
    ("test_96_channels.psm", True),
    ("test_216_for_push_guard.psm", True),
]


def llvm_tool(name: str) -> str:
    """`name` from the LLVM the compiler is built with, else from PATH."""
    root = os.environ.get("PRISMIO_LLVM_DIR")
    roots = [Path(root)] if root else [REPO / "third_party" / "llvm"]
    for candidate in roots:
        tool = candidate / "bin" / (name + (".exe" if WINDOWS else ""))
        if tool.is_file():
            return str(tool)
    return shutil.which(name) or ""


def run_program(tools, work: Path, index: int, source: Path, must_succeed: bool,
                detect_leaks: bool, flags: list) -> str:
    """The failure report for one program, or "" when it passed."""
    scratch = work / f"{index:04d}-{source.stem}"
    scratch.mkdir()
    ir = scratch / "program.ll"
    instrumented = scratch / "program.asan.ll"
    executable = scratch / (f"{source.stem}.exe" if WINDOWS else source.stem)
    environment = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")

    link = [tools["clang"], "-O1", "-g", "-fno-omit-frame-pointer", "-fsanitize=address",
            "-Wno-deprecated-declarations", "-Wno-override-module"]
    if not WINDOWS:
        link.append("-pthread")
    link += [str(instrumented),
             str(REPO / "runtime" / "lang_runtime.c"),
             str(REPO / "runtime" / "program_support.c"),
             "-I" + str(REPO / "runtime"), "-o", str(executable)]
    if sys.platform.startswith("linux"):
        link.append("-lm")

    steps = (
        [str(tools["compiler"]), "build", str(source), "-o", str(ir), *flags],
        [tools["opt"], "-S", "-passes=forceattrs", "-force-attribute=sanitize_address",
         str(ir), "-o", str(instrumented)],
        link,
    )
    for step in steps:
        done = subprocess.run(step, cwd=scratch, env=environment, capture_output=True,
                              text=True, errors="replace")
        if done.returncode != 0:
            return f"did not build:\n{done.stdout}{done.stderr}"

    leaks = detect_leaks and sys.platform.startswith("linux")
    environment["ASAN_OPTIONS"] = (
        f"detect_leaks={1 if leaks else 0}:halt_on_error=1:abort_on_error=1")
    try:
        ran = subprocess.run([str(executable)], cwd=scratch, env=environment,
                             stdin=subprocess.DEVNULL, capture_output=True, text=True,
                             errors="replace", timeout=300)
    except subprocess.TimeoutExpired:
        return "did not finish in 300 s"
    reported = "Sanitizer:" in ran.stderr
    if reported or ran.returncode < 0 or (must_succeed and ran.returncode != 0):
        head = ran.stderr.split("Shadow bytes", 1)[0]
        return f"exit {ran.returncode}\n{head}"
    return ""


def main() -> int:
    parser = argparse.ArgumentParser(description="AddressSanitizer smoke suite.")
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 1)
    parser.add_argument("--paths-only", action="store_true",
                        help="run only the given paths, not the built-in programs")
    parser.add_argument("--build-flag", action="append", default=[],
                        help="passed to every `build`, e.g. --build-flag=--pir=plan")
    parser.add_argument("paths", nargs="*", type=Path)
    args = parser.parse_args()

    compiler = resolve_executable(args.compiler)
    if not compiler.is_file():
        print(f"compiler is not executable: {compiler}", file=sys.stderr)
        return 1
    tools = {"clang": llvm_tool("clang"), "opt": llvm_tool("opt")}
    missing = [name for name, found in tools.items() if not found]
    if missing:
        print(f"not found in the pinned LLVM or on PATH: {', '.join(missing)}", file=sys.stderr)
        return 1

    # (source, must exit 0, check leaks)
    programs = []
    if not args.paths_only:
        programs = [(REPO / "tests" / name, True, leaks) for name, leaks in FIXTURES]
        listed = {name for name, _ in FIXTURES}
        programs += [(REPO / "tests" / name, True, False)
                     for name, _, _ in OWNERSHIP_PROBES if name not in listed]
    for path in args.paths:
        found = sorted(path.glob("*.psm")) if path.is_dir() else [path]
        programs += [(source.resolve(), False, False) for source in found]

    failures = []
    with tempfile.TemporaryDirectory(prefix="prismio-asan-") as tmp:
        work = Path(tmp).resolve()
        tools["compiler"] = source_toolchain(compiler, REPO, work / "toolchain")

        def one(item):
            index, (source, must_succeed, detect_leaks) = item
            return source, run_program(tools, work, index, source, must_succeed, detect_leaks,
                                       args.build_flag)

        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            for source, report in pool.map(one, enumerate(programs)):
                print(f"{source.name:<48} {'FAILED' if report else 'ok'}", flush=True)
                if report:
                    failures.append((source, report))

    for source, report in failures:
        print(f"\n--- {source}", file=sys.stderr)
        for line in report.splitlines()[:40]:
            print(f"  {line}", file=sys.stderr)
    print(f"{len(programs)} program(s), {len(failures)} failed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
