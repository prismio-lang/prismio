#!/usr/bin/env python3
"""Check that every hand-maintained list of toolchain sources agrees.

Two sets of C files are written down in several places, and each place is
someone's source of truth:

- **The compiler's sources** -- every `runtime/*.c`, and `runtime/*.cpp` for the LLVM
  bridge -- are the `native` sources
  of the `prismio` target in `build.ums`, which is how `prismio build` makes a
  compiler, and `RUNTIME_SOURCES` in both bootstrap scripts, which is how a
  compiler is made from the seed with no compiler at all.
- **The runtime's sources** -- the part linked into every compiled program --
  are `prismio_toolchain_files[]` in build_driver.c (what `runtime-hash`
  hashes) and `RUNTIME_MODULES` in tools/toolchain_layout.psm (what a toolchain
  carries).

The LLVM backends are listed twice: `PRISMIO_LLVM_TARGET_LIST` in
prismio_llvm.h (what the compiler initialises) and `TARGET_COMPONENTS` in
tools/setup_llvm.py (what it links). One without the other fails the link or
ships dead weight.

The standard-library modules a freestanding program may import are written twice:
`freestandingSafeModule` in src/driver/imports.psm (what the compiler admits) and
the `module freestanding` headers in std/ (what gets a bare-metal section).

One value rides along because it is written down three times the same way: the macOS
a program is built for, `PRISMIO_MACOS_FLOOR` in llvm-api-backend.c and
`MACOS_FLOOR` in tools/package.py and tools/toolchain_layout.psm, which build for it.

The generated tables in std/ and src/lexer/ are checked against their generators
wherever the inputs are on this machine (the headers, the pinned UCD cache); nothing
is downloaded here.

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
    """The `source(...)` arguments of the compiler's target in build.ums, in order, as runtime/ file names.

    Read with a pattern rather than the UMS parser, for the reason every reader
    here is a pattern: this runs before any compiler exists."""
    text = read(REPO / "build.ums")
    # Only the compiler's target. The language server carries two of the same files and is not
    # the compiler: bootstrap builds the compiler alone.
    start = text.find('executable("prismio")')
    if start < 0:
        raise Failure('build.ums has no executable("prismio") target')
    text = text[start:]
    names = []
    for call in re.findall(r"\bsource\(([^)]*)\)", text):
        for value in re.findall(r'"([^"]+)"', call):
            if not value.startswith("runtime/"):
                raise Failure(f"build.ums names a native source outside runtime/: {value}")
            names.append(value[len("runtime/"):])
    if not names:
        raise Failure("build.ums declares no native sources")
    return names


def bootstrap_list():
    text = read(TOOLS / "bootstrap.py")
    m = re.search(r"^RUNTIME_SOURCES\s*=\s*\[(.*?)\]", text, re.S | re.M)
    if not m:
        raise Failure("could not find RUNTIME_SOURCES in bootstrap.py")
    return re.findall(r'"([^"]+)"', m.group(1))


def layout_runtime_modules():
    text = read(TOOLS / "toolchain_layout.psm")
    m = re.search(r'^let RUNTIME_MODULES = "([^"]+)"', text, re.M)
    if not m:
        raise Failure("could not find RUNTIME_MODULES in toolchain_layout.psm")
    return [name + ".c" for name in m.group(1).split()]


def macos_floors():
    """The macOS a program targets, as the backend, package.py and the layout tool each say it."""
    c = re.search(r'^#define PRISMIO_MACOS_FLOOR "([^"]+)"',
                  read(RUNTIME / "llvm-api-backend.c"), re.M)
    py = re.search(r'^MACOS_FLOOR = "([^"]+)"', read(TOOLS / "package.py"), re.M)
    tool = re.search(r'^let MACOS_FLOOR = "([^"]+)"', read(TOOLS / "toolchain_layout.psm"), re.M)
    if not c or not py or not tool:
        raise Failure("could not find PRISMIO_MACOS_FLOOR / MACOS_FLOOR")
    return c.group(1), [py.group(1), tool.group(1)]


def llvm_targets():
    """(initialised by the backend, linked by setup_llvm.py), lower-cased."""
    h = re.search(r"#define PRISMIO_LLVM_TARGET_LIST\(X\)(.*)", read(RUNTIME / "prismio_llvm.h"))
    py = re.search(r"^TARGET_COMPONENTS = \[(.*?)\]", read(TOOLS / "setup_llvm.py"), re.M | re.S)
    if not h or not py:
        raise Failure("could not find PRISMIO_LLVM_TARGET_LIST / TARGET_COMPONENTS")
    return (sorted(x.lower() for x in re.findall(r"X\((\w+)\)", h.group(1))),
            sorted(re.findall(r'"(\w+)"', py.group(1))))


def freestanding_std():
    """(the modules the compiler lets a freestanding program import, the modules whose header
    says freestanding), without the `std.` prefix."""
    c = re.search(r"private fn freestandingSafeModule\(name: String\) -> Bool \{(.*?)\n\}",
                  read(REPO / "src" / "driver" / "imports.psm"), re.S)
    if not c:
        raise Failure("could not find freestandingSafeModule")
    declared = []
    for path in (REPO / "std").rglob("*.psm"):
        if re.search(r"^module (prelude )?freestanding", read(path), re.M):
            declared.append(path.stem)
    return sorted(re.findall(r'"std\.(\w+)"', c.group(1))), sorted(declared)


def unicode_table_problems():
    """The Unicode tables are generated from the pinned UCD (tools/generate_unicode_tables.py).
    Checked where that cache already is; this never downloads it."""
    import subprocess
    version = re.search(r'^UNICODE_VERSION = "([^"]+)"', read(TOOLS / "generate_unicode_tables.py"), re.M)
    cache = REPO / "build" / "unicode" / (version.group(1) if version else "")
    if not version or not cache.is_dir():
        return []
    result = subprocess.run([sys.executable, str(TOOLS / "generate_unicode_tables.py"), "--check",
                             "--ucd-dir", str(cache)], capture_output=True, text=True)
    if result.returncode == 0:
        return []
    return ["Unicode tables vs tools/generate_unicode_tables.py\n     "
            + (result.stderr or result.stdout).strip()]


def syscall_table_problems():
    """std/syscall.psm is generated from the kernels' headers (tools/gen_syscalls.py). Checked
    only where those headers are installed: a machine with no NDK or macOS SDK skips it."""
    import subprocess
    result = subprocess.run([sys.executable, str(TOOLS / "gen_syscalls.py"), "--check"],
                            capture_output=True, text=True)
    if result.returncode == 0:
        return []
    message = (result.stderr or result.stdout).strip()
    if message.startswith("gen_syscalls: no "):
        return []
    return ["std/syscall.psm vs tools/gen_syscalls.py\n     " + message]


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
            p.name for p in [*RUNTIME.glob("*.c"), *RUNTIME.glob("*.cpp")]
            if p.name not in IGNORED_SOURCES
        )
        compare("runtime/*.c on disk vs build.ums native sources", on_disk, sorted(compiler))
        compare("tools/bootstrap.py RUNTIME_SOURCES", bootstrap_list(), compiler)

        compare("tools/toolchain_layout.psm RUNTIME_MODULES", layout_runtime_modules(), runtime)
        c_floor, other_floors = macos_floors()
        compare("MACOS_FLOOR (package.py, toolchain_layout.psm) vs PRISMIO_MACOS_FLOOR", other_floors,
                [c_floor, c_floor])
        initialised, linked = llvm_targets()
        compare("tools/setup_llvm.py TARGET_COMPONENTS vs PRISMIO_LLVM_TARGET_LIST", linked, initialised)
        allowed, packaged = freestanding_std()
        compare("std/ `module freestanding` headers vs freestandingSafeModule", packaged, allowed)
        missing = [name for name in runtime if name not in compiler]
        if missing:
            problems.append("runtime sources the compiler does not compile: " + " ".join(missing))
        problems.extend(syscall_table_problems())
        problems.extend(unicode_table_problems())
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
