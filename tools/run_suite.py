#!/usr/bin/env python3
"""Run the compiler suite against a *copy* of the compiler.

`prismio suite` runs this rather than `tests/test_runner.py` directly, and the
copy is the whole point. Three fixtures make the difference:

- the ums fixture deletes and rebuilds `.prismio/build/debug/prismio` to exercise
  host routing, so a runner pointed at that path loses its compiler mid-run;
- it also copies the compiler under test to a temporary launcher and expects it
  to behave as the *global parent* in a stage-0 -> project-local promotion,
  which the binary currently executing the command cannot also be; and
- the object-cache and cold-build fixtures assert what a build recompiles, which
  a compiler already running in this process tree perturbs.

Copying costs a few megabytes once and removes all three interactions. Every
argument is forwarded to the runner, so `prismio suite -k foo --list` works.

    python tools/run_suite.py [--compiler PATH] [runner args...]

`--compiler` defaults to the packaged toolchain, falling back to the project
host. Exits with the runner's status.
"""
import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
# The project host first, and the order matters. It is a standalone binary, so a
# copy of it is a working compiler. `dist/Prismio/bin/prismio` is one file in a
# *layout* -- it finds `../stdlib` beside itself -- so a copy of just that file
# is a compiler that cannot resolve `std.*`, and the ums fixture fails on it.
DEFAULT_CANDIDATES = (
    REPO / ".prismio" / "build" / "debug" / "prismio",
    REPO / "dist" / "Prismio" / "bin" / "prismio",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", help="compiler to copy and test")
    args, forwarded = parser.parse_known_args()

    if args.compiler:
        # Resolved, because the banner below reports the path relative to the
        # repository and a relative --compiler raised ValueError there rather
        # than running anything.
        source = Path(args.compiler).resolve()
        if not source.is_file():
            print(f"run_suite: --compiler is not a file: {source}")
            return 1
    else:
        source = next((c for c in DEFAULT_CANDIDATES if c.is_file()), None)
        if source is None:
            names = ", ".join(str(c.relative_to(REPO)) for c in DEFAULT_CANDIDATES)
            print(f"run_suite: no compiler found. Looked for: {names}")
            print("Build one with `prismio build`, then `prismio dist`.")
            return 1

    with tempfile.TemporaryDirectory(prefix="prismio-suite-") as tmp:
        # Named `prismio` in its own directory: the ums fixture derives the
        # stage-0 launcher's identity from the file name, and a copy called
        # anything else is not the compiler it is pretending to be.
        copy = Path(tmp) / ("prismio.exe" if sys.platform == "win32" else "prismio")
        shutil.copy2(source, copy)
        copy.chmod(0o755)

        try:
            shown = source.relative_to(REPO)
        except ValueError:
            shown = source
        print(f"suite: testing a copy of {shown}")
        result = subprocess.run(
            [sys.executable, str(REPO / "tests" / "test_runner.py"),
             "--compiler", str(copy), *forwarded],
            cwd=str(REPO),
        )
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
