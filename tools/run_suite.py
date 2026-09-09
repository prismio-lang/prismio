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

What is copied is the *toolchain*, not the binary: the compiler, the runtime
bitcode beside it and the compiled standard modules, in the layout it resolves
them from. A few megabytes once, and it removes all three interactions. Every
argument is forwarded to the runner, so `prismio suite -k foo --list` works.

    python tools/run_suite.py [--compiler PATH] [runner args...]

`--compiler` defaults to the project host, falling back to the packaged
toolchain. Exits with the runner's status.
"""
import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
# The project host first, because it is the compiler the working tree just built.
DEFAULT_CANDIDATES = (
    REPO / ".prismio" / "build" / "debug" / "prismio",
    REPO / "dist" / "Prismio" / "bin" / "prismio",
)


def shown_root(path: Path):
    try:
        return path.relative_to(REPO)
    except ValueError:
        return path


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
        # **A compiler is a layout, not a file.** It finds runtime bitcode at
        # `<exe>/../lib/runtime` and compiled standard modules at
        # `<exe>/../stdlib`, so a lone copy of one builds nothing at all -- it
        # reports "Missing runtime module" for a toolchain the developer never
        # installed. Both candidates above sit in such a layout: `dist/Prismio`
        # is one because packaging made it, and `.prismio/build` is one because
        # `prismio build` now leaves the runtime and standard library beside the
        # host it built. So the copy reproduces the shape rather than the file.
        #
        # Named `suite-compiler` and not `prismio`, because a binary called
        # `prismio` redirects to build.ums's project host -- which silently
        # tested an older compiler than `--compiler` named. The UMS fixture makes
        # its own `prismio` launcher when it is specifically testing routing.
        prefix = Path(tmp)
        copy = prefix / "bin" / ("suite-compiler.exe" if sys.platform == "win32" else "suite-compiler")
        copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, copy)
        copy.chmod(0o755)

        toolchain = source.parent.parent
        missing = [str(d) for d in ("lib", "stdlib")
                   if not (toolchain / d).is_dir()]
        if missing:
            print(f"run_suite: {shown_root(source)} is not in a toolchain layout; "
                  f"no {', '.join(missing)} beside it.")
            print("Build one with `prismio build`, or package one with `prismio dist`.")
            return 1
        for directory in ("lib", "stdlib", "third_party"):
            if (toolchain / directory).is_dir():
                shutil.copytree(toolchain / directory, prefix / directory)

        print(f"suite: testing a copy of {shown_root(source)}")
        result = subprocess.run(
            [sys.executable, "-u", str(REPO / "tests" / "test_runner.py"),
             "--compiler", str(copy), *forwarded],
            cwd=str(REPO),
        )
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
