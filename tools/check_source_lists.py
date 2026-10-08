#!/usr/bin/env python3
"""Check that every hand-maintained list of toolchain sources agrees.

Two sets of C files are written down in several places, and each place is
someone's source of truth:

- **The compiler's sources** -- every `runtime/*.c` -- are the `native` sources
  of the `prismio` target in `build.ums`, which is how `prismio build` makes a
  compiler, and `RUNTIME_SOURCES` in both bootstrap scripts, which is how a
  compiler is made from the seed with no compiler at all.
- **The runtime's sources** -- the part linked into every compiled program --
  are `prismio_toolchain_files[]` in build_driver.c (what `runtime-hash`
  hashes) and `RUNTIME_BITCODE` in tools/package.py (what is packaged).

The LLVM backends are listed twice: `PRISMIO_LLVM_TARGET_LIST` in
prismio_llvm.h (what the compiler initialises) and `TARGET_COMPONENTS` in
tools/setup_llvm.py (what it links). One without the other fails the link or
ships dead weight.

The standard-library modules a freestanding program may import are written twice:
`freestandingSafeModule` in src/driver/imports.psm (what the compiler admits) and
`FREESTANDING_STD` in tools/package.py (what is packaged for a bare-metal triple).

One value rides along because it is written down twice the same way: the macOS
a program is built for, `PRISMIO_MACOS_FLOOR` in llvm-api-backend.c and
`MACOS_FLOOR` in tools/package.py, which builds the runtime bitcode for it.

Adding a file to runtime/ should fail loudly here until every list knows about
it, which is cheaper than discovering it on someone else's machine.

    python tools/check_source_lists.py

Exits non-zero on any disagreement. Run from anywhere; paths are resolved
relative to this script.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RUNTIME = REPO / "runtime"
TOOLS = REPO / "tools"

# Not part of the toolchain: a standalone harness compiled by hand, never linked
# into the compiler or into a user program.
IGNORED_SOURCES = {"test_llvm_backend.c"}


class Failure(Exception):
    pass


def read(path: Path) -> str:
    if not path.exists():
        raise Failure(f"missing file: {path.relative_to(REPO)}")
    return path.read_text(encoding="utf-8", errors="replace")


def runtime_table():
    """prismio_toolchain_files[] in build_driver.c: the runtime's files, headers
    included. Returns the `.c` entries."""
    text = read(RUNTIME / "build_driver.c")
    m = re.search(
        r"static const PrismioToolchainFile prismio_toolchain_files\[\]\s*=\s*\{(.*?)\n\};",
        text,
        re.S,
    )
    if not m:
        raise Failure("could not find prismio_toolchain_files[] in build_driver.c")
    entries = re.findall(r'\{\s*"([^"]+)"\s*\}', m.group(1))
    if not entries:
        raise Failure("prismio_toolchain_files[] parsed as empty")
    return [name for name in entries if name.endswith(".c")]


def manifest_native_sources():
    """The `source(...)` arguments of build.ums, in order, as runtime/ file names.

    Read with a pattern rather than the UMS parser, for the reason every reader
    here is a pattern: this runs before any compiler exists."""
    text = read(REPO / "build.ums")
    names = []
    for call in re.findall(r"\bsource\(([^)]*)\)", text):
        for value in re.findall(r'"([^"]+)"', call):
            if not value.startswith("runtime/"):
                raise Failure(f"build.ums names a native source outside runtime/: {value}")
            names.append(value[len("runtime/"):])
    if not names:
        raise Failure("build.ums declares no native sources")
    return names


def bootstrap_ps1_list():
    text = read(TOOLS / "bootstrap.ps1")
    m = re.search(r"\$runtimeSources\s*=\s*@\((.*?)\)", text, re.S)
    if not m:
        raise Failure("could not find $runtimeSources in bootstrap.ps1")
    return re.findall(r"'([^']+)'", m.group(1))


def bootstrap_sh_list():
    text = read(TOOLS / "bootstrap.sh")
    m = re.search(r'RUNTIME_SOURCES="([^"]*)"', text)
    if not m:
        raise Failure("could not find RUNTIME_SOURCES in bootstrap.sh")
    return m.group(1).split()


def package_runtime_bitcode():
    text = read(TOOLS / "package.py")
    m = re.search(r"^RUNTIME_BITCODE\s*=\s*\[(.*?)\]", text, re.S | re.M)
    if not m:
        raise Failure("could not find RUNTIME_BITCODE in package.py")
    return re.findall(r'"([^"]+)"', m.group(1))


def macos_floors():
    """The macOS a program targets, as the backend and package.py each say it."""
    c = re.search(r'^#define PRISMIO_MACOS_FLOOR "([^"]+)"',
                  read(RUNTIME / "llvm-api-backend.c"), re.M)
    py = re.search(r'^MACOS_FLOOR = "([^"]+)"', read(TOOLS / "package.py"), re.M)
    if not c or not py:
        raise Failure("could not find PRISMIO_MACOS_FLOOR / MACOS_FLOOR")
    return c.group(1), py.group(1)


def llvm_targets():
    """(initialised by the backend, linked by setup_llvm.py), lower-cased."""
    h = re.search(r"#define PRISMIO_LLVM_TARGET_LIST\(X\)(.*)", read(RUNTIME / "prismio_llvm.h"))
    py = re.search(r"^TARGET_COMPONENTS = \[(.*?)\]", read(TOOLS / "setup_llvm.py"), re.M | re.S)
    if not h or not py:
        raise Failure("could not find PRISMIO_LLVM_TARGET_LIST / TARGET_COMPONENTS")
    return (sorted(x.lower() for x in re.findall(r"X\((\w+)\)", h.group(1))),
            sorted(re.findall(r'"(\w+)"', py.group(1))))


def freestanding_std():
    """(the modules the compiler lets a freestanding program import, the modules
    package.py gives a bare-metal section), without the `std.` prefix."""
    c = re.search(r"private fn freestandingSafeModule\(name: String\) -> Bool \{(.*?)\n\}",
                  read(REPO / "src" / "driver" / "imports.psm"), re.S)
    py = re.search(r"^FREESTANDING_STD = \((.*?)\)", read(TOOLS / "package.py"), re.M)
    if not c or not py:
        raise Failure("could not find freestandingSafeModule / FREESTANDING_STD")
    return (sorted(re.findall(r'"std\.(\w+)"', c.group(1))),
            sorted(re.findall(r'"(\w+)"', py.group(1))))


def main() -> int:
    problems = []

    def compare(label, actual, expected):
        if list(actual) != list(expected):
            problems.append(
                f"{label}\n     has: {' '.join(actual) or '(nothing)'}"
                f"\n  expect: {' '.join(expected)}"
            )

    try:
        compiler = manifest_native_sources()
        runtime = runtime_table()

        # Every .c in runtime/ is a compiler source. A file nobody compiles is
        # dead weight at best and a silently-missing feature at worst.
        on_disk = sorted(
            p.name for p in RUNTIME.glob("*.c") if p.name not in IGNORED_SOURCES
        )
        compare("runtime/*.c on disk vs build.ums native sources", on_disk, sorted(compiler))
        compare("tools/bootstrap.ps1 $runtimeSources", bootstrap_ps1_list(), compiler)
        compare("tools/bootstrap.sh RUNTIME_SOURCES", bootstrap_sh_list(), compiler)

        compare("tools/package.py RUNTIME_BITCODE", package_runtime_bitcode(), runtime)
        c_floor, py_floor = macos_floors()
        compare("tools/package.py MACOS_FLOOR vs PRISMIO_MACOS_FLOOR", [py_floor], [c_floor])
        initialised, linked = llvm_targets()
        compare("tools/setup_llvm.py TARGET_COMPONENTS vs PRISMIO_LLVM_TARGET_LIST", linked, initialised)
        allowed, packaged = freestanding_std()
        compare("tools/package.py FREESTANDING_STD vs freestandingSafeModule", packaged, allowed)
        missing = [name for name in runtime if name not in compiler]
        if missing:
            problems.append("runtime sources the compiler does not compile: " + " ".join(missing))
    except Failure as exc:
        print(f"FAILED: {exc}")
        return 1

    if problems:
        print("Toolchain source lists disagree:\n")
        for p in problems:
            print(f"  {p}\n")
        print("Fix every list above, then re-run this check.")
        return 1

    print(f"Toolchain source lists agree ({len(compiler)} compiler sources, "
          f"{len(runtime)} in the runtime).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
