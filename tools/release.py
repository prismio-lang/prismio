#!/usr/bin/env python3
"""Build the distributable artifacts for a release, and their checksums.

    python tools/release.py --compiler build/v0.1-rc --version 0.1.0 --out dist/release

One archive per host, named for the triple it was built on, plus a SHA-256
manifest covering it. Run it on each platform; the manifests concatenate, which
is what lets three machines produce one checksum file without any of them
trusting the others.

**It refuses to build from a compiler that is not a fixpoint.** A release
artifact whose compiler does not reproduce its own IR is a compiler caught
mid-migration, and that is the one defect this project has burned commits on.

The archive is `.zip` on Windows and `.tar.gz` elsewhere -- the format each
platform can open without installing anything.
"""
import argparse
import filecmp
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WINDOWS = os.name == "nt"
EXE = ".exe" if WINDOWS else ""


def die(message: str, hint: str = "") -> "NoReturn":
    print(f"error: {message}", file=sys.stderr)
    if hint:
        print(f"       {hint}", file=sys.stderr)
    raise SystemExit(1)


def run(command: list, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run([str(c) for c in command], capture_output=True, text=True,
                          cwd=str(REPO), **kwargs)


def host_triple() -> str:
    machine = platform.machine()
    system = platform.system()
    if system == "Darwin":
        return f"{machine}-apple-darwin"
    if system == "Linux":
        return f"{machine}-unknown-linux-gnu"
    if system == "Windows":
        return f"{machine}-pc-windows-msvc"
    return system.lower()


def reported_version(compiler: Path) -> str:
    """The version the compiler reports is the version that ships. Taking it from
    a flag alone would let an archive be named for a number the binary inside it
    does not say, which is the kind of mismatch nobody checks until a bug
    report."""
    result = run([compiler, "--version"])
    if result.returncode != 0 or not result.stdout.strip():
        die("could not read the compiler's version")
    first = result.stdout.strip().splitlines()[0].split()
    if len(first) < 2:
        die(f"unexpected --version output: {result.stdout.strip().splitlines()[0]}")
    return first[1]


def bootstrap(compiler: Path, out: Path) -> subprocess.CompletedProcess:
    if WINDOWS:
        shell = shutil.which("pwsh") or shutil.which("powershell")
        return run([shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                    REPO / "tools" / "bootstrap.ps1", "-Compiler", compiler, "-Out", out])
    return run(["bash", REPO / "tools" / "bootstrap.sh",
                "--compiler", compiler, "--out", out])


def main() -> int:
    parser = argparse.ArgumentParser(description="Build release artifacts and checksums.")
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--version")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    compiler = Path(args.compiler).resolve()
    if not compiler.is_file():
        die(f"no compiler at {compiler}")

    version = reported_version(compiler)
    if args.version and args.version != version:
        die(f"--version {args.version} but the compiler reports {version}",
            "PRISMIO_VERSION in src/main.psm is the source of truth.")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    out = out.resolve()

    work = Path(tempfile.mkdtemp(prefix="prismio-release-"))
    try:
        print("== fixpoint check")
        if bootstrap(compiler, work / f"gen{EXE}").returncode != 0:
            die("could not build the next generation from this compiler")
        frozen, following = work / "frozen.ll", work / "next.ll"
        if run([compiler, "build", "src/main.psm", "-o", frozen]).returncode != 0:
            die("the frozen compiler could not build src/main.psm")
        if run([work / f"gen{EXE}", "build", "src/main.psm", "-o", following]).returncode != 0:
            die("the next generation could not build src/main.psm")
        if not filecmp.cmp(frozen, following, shallow=False):
            die(f"{compiler} is not a fixpoint -- it does not reproduce its own IR")
        print("   ok -- the frozen compiler reproduces its own IR")

        stem = f"prismio-{version}-{host_triple()}"
        print(f"== packaging {stem}")
        staged = work / stem
        if staged.exists():
            shutil.rmtree(staged)
        packaged = run([sys.executable, "tools/package.py",
                        "--compiler", compiler, "--out", staged])
        if packaged.returncode != 0:
            die("packaging failed:\n" + packaged.stdout + packaged.stderr)
        separated = run([sys.executable, "tools/verify_separation.py", "--dist", staged])
        if separated.returncode != 0:
            die("the packaged toolchain failed its separation checks")
        for extra in ("LICENSE", "CHANGELOG.md"):
            if (REPO / extra).is_file():
                shutil.copyfile(REPO / extra, staged / extra)

        print("== archiving")
        archive_format = "zip" if WINDOWS else "gztar"
        suffix = ".zip" if WINDOWS else ".tar.gz"
        archive = Path(shutil.make_archive(str(out / stem), archive_format,
                                           root_dir=str(work), base_dir=stem))
        if archive.name != stem + suffix:
            archive = archive.rename(out / (stem + suffix))

        print("== checksums")
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        line = f"{digest}  {archive.name}\n"
        checksum = out / (archive.name + ".sha256")
        checksum.write_text(line, encoding="ascii")
        print(line, end="")

        print()
        print(f"artifact: {archive}")
        print(f"checksum: {checksum}")
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
