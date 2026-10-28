#!/usr/bin/env python3
"""Build the distributable artifacts for a release, and their checksums.

    python tools/release.py --build-with .prismio/build/debug/prismio --out dist/release
    python tools/release.py --compiler build/v0.1-rc --version 0.1.0 --out dist/release

**`--build-with` ships this checkout, not a binary that happens to be lying
around.** It runs `<compiler> build --release`, and what it ships is that
build's `.prismio/build/release/prismio`, compiled from the tree as it is now.
`prismio release` does this. Shipping the project host directly, as it used to,
packaged whatever the last `prismio build` left: an edit that does not change
the compiler's own IR -- a runtime fix, a link flag -- passed the fixpoint check
and shipped the old binary. The runtime bitcode and the standard library never
had that problem: tools/package.py rebuilds both from source every time.

`--compiler` ships the binary it names, as it is: a frozen release candidate
that has been through the gate (RELEASE.md §1).

One archive per host, named for the OS and architecture it was built on
(`prismio-0.1.0-macos-arm64.tar.gz`), plus a SHA-256 manifest covering it. Run
it on each platform; the manifests concatenate, which is what lets three
machines produce one checksum file without any of them trusting the others.

**It refuses to build from a compiler that is not a fixpoint.** A release
artifact whose compiler does not reproduce its own IR is a compiler caught
mid-migration, and that is the one defect this project has burned commits on.

**It reads the oldest system the artifact runs on off the binaries**, because
nothing else notices: the 0.1.0 macOS archive said `minos 27.0`, the build
machine's version, and would not start on macOS 26 (2026-10-02). See
`check_floor` for what each platform is held to.

The archive is `.zip` on Windows and `.tar.gz` elsewhere -- the format each
platform can open without installing anything.
"""
import argparse
import filecmp
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import gate_ui as ui
from executable import resolve_executable

REPO = Path(__file__).resolve().parent.parent
WINDOWS = os.name == "nt"
EXE = ".exe" if WINDOWS else ""


class ReleaseError(Exception):
    """A release step that cannot go on. Raised, not printed, so whatever is on the
    screen (a spinner, a half-drawn row) is cleared before the message is shown."""

    def __init__(self, message: str, hint: str = ""):
        super().__init__(message)
        self.hint = hint


def die(message: str, hint: str = "") -> "NoReturn":
    raise ReleaseError(message, hint)


def run(command: list, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run([str(c) for c in command], capture_output=True, text=True,
                          cwd=str(REPO), **kwargs)


def host_platform() -> str:
    """`macos-arm64`, `linux-x64`, `windows-x64`: the OS and architecture as a
    person names them, the way LLVM, Node and Go name their downloads, not as a
    target triple. install.sh looks for exactly these spellings (OS_NAME and
    ARCH_NAME), and the website's download list sorts assets by the OS word."""
    system = {"Darwin": "macos", "Linux": "linux", "Windows": "windows"}.get(
        platform.system(), platform.system().lower())
    machine = platform.machine().lower()
    arch = {"x86_64": "x64", "amd64": "x64", "arm64": "arm64", "aarch64": "arm64"}.get(
        machine, machine)
    return f"{system}-{arch}"


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


def llvm_objdump() -> Path:
    info = json.loads((REPO / "third_party" / "llvm-paths.json").read_text())
    return Path(info["bin"]) / f"llvm-objdump{EXE}"


def macos_minos(binary: Path) -> str:
    r = run([llvm_objdump(), "--macho", "--private-headers", binary])
    for line in r.stdout.splitlines():
        words = line.split()
        if len(words) == 2 and words[0] == "minos":
            return words[1]
    die(f"{binary.name} states no minimum macOS (no LC_BUILD_VERSION)")


def version_key(text: str) -> tuple:
    return tuple(int(part) for part in text.split("."))


def check_floor(staged: Path, work: Path) -> tuple:
    """Hold the artifact to the oldest system it claims, and print what that is.

    A program is built with the packaged compiler, from a directory outside the
    checkout and without MACOSX_DEPLOYMENT_TARGET, the way a user builds one.

    - **macOS** fails unless the compiler states the LLVM floor setup_llvm.py
      recorded and the program states package.py's MACOS_FLOOR. Both used to be
      the build machine's macOS.
    - **Windows** fails when anything imports the Visual C++ runtime DLLs
      (VCRUNTIME*, MSVCP*): they are not on a fresh Windows, and the UCRT is.
    - **Linux** reports the newest glibc symbol version and the shared libraries
      needed, and fails on nothing yet: glibc binds each symbol to the build
      machine's version, so the floor is whichever distribution built the
      archive. Build it on the oldest one the release supports.

    Returns `(detail, notes)` for the stage row: the one-line finding, and one
    dim line per binary.
    """
    compiler = staged / "bin" / f"prismio{EXE}"
    source = work / "floor.psm"
    source.write_text("import std.io\n\nfn main() -> Int {\n    println(\"floor\")\n"
                      "    return 0\n}\n")
    program = work / f"floor{EXE}"
    env = os.environ.copy()
    env.pop("MACOSX_DEPLOYMENT_TARGET", None)
    built = subprocess.run([str(compiler), "build", str(source), "-o", str(program)],
                           capture_output=True, text=True, cwd=str(work), env=env)
    if built.returncode != 0:
        die("the packaged compiler could not build a program:\n" + built.stdout + built.stderr)
    if "different target triples" in built.stdout + built.stderr:
        die("the runtime bitcode and the program disagree on the target triple:\n"
            + built.stdout + built.stderr)
    ran = subprocess.run([str(program)], capture_output=True, text=True)
    if ran.returncode != 0 or ran.stdout.strip() != "floor":
        die(f"the program the packaged compiler built did not run ({ran.returncode})")

    if sys.platform == "darwin":
        sys.path.insert(0, str(REPO / "tools"))
        from package import MACOS_FLOOR
        info = json.loads((REPO / "third_party" / "llvm-paths.json").read_text())
        wanted = info.get("macos_min") or die(
            "third_party/llvm-paths.json records no macos_min",
            "re-run python3 tools/setup_llvm.py")
        for binary, floor in ((compiler, wanted), (program, MACOS_FLOOR)):
            stated = macos_minos(binary)
            if version_key(stated) > version_key(floor):
                die(f"{binary.name} needs macOS {stated}, but the release supports {floor}",
                    "was it built before setup_llvm.py recorded macos_min? "
                    "re-run setup_llvm.py, then `prismio build`")
        return (f"compiler macOS {macos_minos(compiler)}+ \u00b7 its programs {macos_minos(program)}+", [])
    elif WINDOWS:
        needed = {}
        server = staged / "bin" / f"prismio-lsp{EXE}"
        for binary in [compiler, program, server, *sorted((staged / "bin").glob("*.dll"))]:
            r = run([llvm_objdump(), "--private-headers", binary])
            names = re.findall(r"DLL Name: (\S+)", r.stdout)
            needed[binary.name] = names
            redist = [n for n in names if re.match(r"(?i)(vcruntime|msvcp)", n)]
            if redist:
                die(f"{binary.name} imports {', '.join(redist)}, the Visual C++ runtime, "
                    "which a fresh Windows does not have",
                    "link the static CRT (/MT), or ship those DLLs beside it")
        return ("nothing needs the Visual C++ redistributable",
                [("list", f"{name}: {', '.join(names)}", "") for name, names in needed.items()])
    else:
        notes, floor = [], "?"
        for binary in (compiler, program):
            r = run([llvm_objdump(), "-T", "-p", binary])
            versions = set(re.findall(r"GLIBC_([0-9.]+)", r.stdout))
            libraries = re.findall(r"NEEDED\s+(\S+)", r.stdout)
            newest = max(versions, key=version_key) if versions else "?"
            if binary is compiler:
                floor = newest
            notes.append(("list", f"{binary.name}: glibc {newest}+; needs {', '.join(libraries)}", ""))
        return (f"needs glibc {floor}+ (the build machine sets the floor)", notes)


def build_release_compiler(host: Path) -> Path:
    """`host build --release` in this checkout; the compiler it produced.

    The release profile, so the build writes `.prismio/build/release/` and never
    touches the debug-profile host that `prismio release` itself is running.
    """
    compiler = REPO / ".prismio" / "build" / "release" / f"prismio{EXE}"
    # A host that is the very binary this build replaces cannot overwrite itself while it runs: it
    # stages the new compiler as `<host>.next` and the launcher renames it over the host after the
    # build process exits (src/project/host.psm). Reading `prismio` right after the build therefore
    # reads the compiler that did the building, whatever the checkout now says -- the release shipped
    # the previous bootstrap, without a formatter rule the tree had, for exactly that reason. So a
    # stale candidate is cleared first, and the fresh one, when there is one, is what ships.
    staged = Path(str(compiler) + ".next")
    staged.unlink(missing_ok=True)
    built = run([host, "build", "--release"])
    if built.returncode != 0:
        die("`build --release` failed:\n" + (built.stdout + built.stderr).strip(),
            "if src/ uses something this host cannot compile, run `prismio build` first")
    if staged.is_file():
        return staged
    if not compiler.is_file():
        die(f"`build --release` produced no {compiler.relative_to(REPO)}")
    return compiler


def bootstrap(compiler: Path, out: Path) -> subprocess.CompletedProcess:
    return run([sys.executable, REPO / "tools" / "bootstrap.py",
                "--compiler", compiler, "--out", out])


def shown(path) -> str:
    try:
        return str(Path(path).resolve().relative_to(REPO))
    except ValueError:
        return str(path)


def megabytes(path: Path) -> str:
    return f"{path.stat().st_size / (1 << 20):.1f} MB"


class Stages:
    """The numbered stages of a release, each one row on the shared gate display."""

    def __init__(self, total: int):
        self.total, self.index = total, 0
        self.ticker = ui.Ticker()
        self.done = []          # (title, ok, seconds)

    def run(self, title: str, label: str, work) -> object:
        """Run `work(ticker) -> (detail, notes, value)` under a spinner; show its row."""
        self.index += 1
        print()
        print(ui.banner(self.index, self.total, title), flush=True)
        self.ticker.begin(label)
        started = time.monotonic()
        try:
            detail, notes, value = work(self.ticker)
        except ReleaseError as failure:
            elapsed = time.monotonic() - started
            self.ticker.end()
            print(ui.row("fail", label, "failed", elapsed), flush=True)
            for line in str(failure).strip().splitlines():
                print("      " + ui.style(line, "dim"))
            if failure.hint:
                print("      " + ui.style("hint: " + failure.hint, "yellow"))
            self.done.append((title, False, elapsed))
            raise
        elapsed = time.monotonic() - started
        self.ticker.end()
        print(ui.row("ok", label, detail, elapsed), flush=True)
        for kind, text, extra in notes:
            if kind == "row":
                print(ui.row("ok", text, extra, None), flush=True)
            else:
                print("      " + ui.style(text, "dim"))
        self.done.append((title, True, elapsed))
        return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Build release artifacts and checksums.")
    chosen = parser.add_mutually_exclusive_group(required=True)
    chosen.add_argument("--compiler", help="ship this compiler binary as it is")
    chosen.add_argument("--build-with", metavar="COMPILER",
                        help="build the compiler to ship from this checkout with COMPILER")
    parser.add_argument("--version")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    started = time.monotonic()
    stages = Stages(5 if args.build_with else 4)
    work = None
    try:
        # Before anything is built: a checkout prepared before setup_llvm.py recorded
        # macos_min has LLVM lowered for this machine's macOS, so building links it
        # with a warning per object, and check_floor refuses the result anyway.
        if sys.platform == "darwin":
            paths = REPO / "third_party" / "llvm-paths.json"
            if not paths.is_file() or not json.loads(paths.read_text()).get("macos_min"):
                die("the pinned LLVM was prepared before it recorded the macOS it needs",
                    "run `python3 tools/setup_llvm.py` (re-downloads and re-lowers LLVM once), "
                    "then `prismio build`")

        given = resolve_executable(args.build_with or args.compiler)
        if not given.is_file():
            die(f"no compiler at {given}")

        # Every compiler below is named `prismio` and runs inside this project, and
        # a `prismio` there forwards to build.ums's toolchain.host -- the fixpoint
        # check would test the debug host, not the compiler being shipped. Hosted
        # means "you are the compiler; do the work yourself", as package.py says too.
        os.environ["PRISMIO_INTERNAL_HOSTED"] = "1"

        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        out = out.resolve()

        print(ui.heading("Prismio release"))
        header = [("host", host_platform()),
                  ("compiler", f"{shown(given)}" + (" (builds the release profile)" if args.build_with
                                                    else " (shipped as it is)")),
                  ("output", shown(out))]
        for key, value in header:
            print("  " + ui.style(key.ljust(10), "dim") + value)

        compiler = given
        if args.build_with:
            def build(_ticker):
                built = build_release_compiler(given)
                return f"{shown(built)} \u00b7 {megabytes(built)}", [], built
            compiler = stages.run("Build the compiler to ship", "release profile", build)

        version = reported_version(compiler)
        if args.version and args.version != version:
            die(f"--version {args.version} but the compiler reports {version}",
                "PRISMIO_VERSION in src/main.psm is the source of truth.")

        work = Path(tempfile.mkdtemp(prefix="prismio-release-"))

        def fixpoint(ticker):
            ticker.note("building the next generation")
            if bootstrap(compiler, work / f"gen{EXE}").returncode != 0:
                die("could not build the next generation from this compiler")
            frozen, following = work / "frozen.ll", work / "next.ll"
            ticker.note("emitting IR \u00b7 frozen compiler")
            if run([compiler, "build", "src/main.psm", "-o", frozen]).returncode != 0:
                die("the frozen compiler could not build src/main.psm")
            ticker.note("emitting IR \u00b7 next generation")
            if run([work / f"gen{EXE}", "build", "src/main.psm", "-o", following]).returncode != 0:
                die("the next generation could not build src/main.psm")
            if not filecmp.cmp(frozen, following, shallow=False):
                die(f"{compiler} is not a fixpoint -- it does not reproduce its own IR")
            return "the compiler reproduces its own IR", [], None
        stages.run("Check the fixpoint", "fixpoint", fixpoint)

        stem = f"prismio-{version}-{host_platform()}"
        staged = work / stem

        def package(ticker):
            if staged.exists():
                shutil.rmtree(staged)
            ticker.note("packaging")
            packaged = run([sys.executable, "tools/package.py",
                            "--compiler", compiler, "--out", staged])
            if packaged.returncode != 0:
                die("packaging failed:\n" + packaged.stdout + packaged.stderr)
            ticker.note("separation checks")
            separated = run([sys.executable, "tools/verify_separation.py", "--dist", staged])
            if separated.returncode != 0:
                die("the packaged toolchain failed its separation checks:\n"
                    + (separated.stdout + separated.stderr))
            runtime = len(list((staged / "lib" / "runtime").glob("*.bc")))
            stdlib = len(list((staged / "stdlib").glob("*.plib")))
            return (f"{runtime} runtime bitcode \u00b7 {stdlib} stdlib modules \u00b7 separation ok",
                    [], None)
        stages.run(f"Package {stem}", "toolchain layout", package)

        def floor(ticker):
            ticker.note("building a program with the packaged compiler")
            detail, notes = check_floor(staged, work)
            for extra in ("LICENSE", "CHANGELOG.md"):
                if (REPO / extra).is_file():
                    shutil.copyfile(REPO / extra, staged / extra)
            return detail, notes, None
        stages.run("The oldest system it runs on", "floor", floor)

        def archive_it(ticker):
            ticker.note("archiving")
            archive_format = "zip" if WINDOWS else "gztar"
            suffix = ".zip" if WINDOWS else ".tar.gz"
            archive = Path(shutil.make_archive(str(out / stem), archive_format,
                                               root_dir=str(work), base_dir=stem))
            if archive.name != stem + suffix:
                archive = archive.rename(out / (stem + suffix))
            ticker.note("checksum")
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            checksum = out / (archive.name + ".sha256")
            # Bytes, not write_text: on Windows text mode writes CRLF, and `sha256sum -c` then looks
            # for a file whose name ends in a carriage return.
            checksum.write_bytes(f"{digest}  {archive.name}\n".encode("ascii"))
            return (f"{archive.name} \u00b7 {megabytes(archive)}",
                    [("row", "sha256", digest[:24] + "\u2026")], (archive, checksum, digest))
        archive, checksum, digest = stages.run("Archive and checksum", "archive", archive_it)
    except ReleaseError as failure:
        print()
        print(ui.rule())
        for title, passed, seconds in stages.done:
            print(ui.row("ok" if passed else "fail", title, "" if passed else "failed", seconds,
                         label_width=max(len(t) for t, _, _ in stages.done)))
        if not stages.done or stages.done[-1][1]:
            # Failed before any stage ran (arguments, environment): nothing was shown yet.
            print("  " + ui.style(str(failure), "red"))
            if failure.hint:
                print("  " + ui.style("hint: " + failure.hint, "yellow"))
        print()
        print("  " + ui.verdict(False, (f"at: {stages.done[-1][0]}  " if stages.done and not stages.done[-1][1] else ""))
              + ui.style(f"in {ui.duration(time.monotonic() - started)}", "dim"))
        return 1
    finally:
        if work is not None:
            shutil.rmtree(work, ignore_errors=True)

    print()
    print(ui.rule())
    for title, passed, seconds in stages.done:
        print(ui.row("ok" if passed else "fail", title, "", seconds,
                     label_width=max(len(t) for t, _, _ in stages.done)))
    print()
    print("  " + ui.verdict(True, f"prismio {version} for {host_platform()}  ")
          + ui.style(f"in {ui.duration(time.monotonic() - started)}", "dim"))
    print()
    print("  " + ui.style("artifact ".ljust(10), "dim") + str(archive))
    print("  " + ui.style("checksum ".ljust(10), "dim") + str(checksum))
    print("  " + ui.style("sha256   ".ljust(10), "dim") + f"{digest}  {archive.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
