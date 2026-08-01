#!/usr/bin/env python3
"""Check that every hand-maintained list of runtime sources agrees.

The set of C files that make up the toolchain is written down in six places --
the toolchain table and the embedded-source switch in build_driver.c, the
embedding generator, both bootstrap scripts and both packaging scripts. Nothing
made them agree, and they had already drifted: generate_embedded_sources.ps1
still listed llvm-bridge.c, deleted several changes earlier, and had never
learned about ir_symbols.c or llvm-api-backend.c. Running it would have written
an embedded_sources.h that compiled and then failed at link time, or worse,
shipped a compiler carrying a runtime that no longer existed.

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


def toolchain_table():
    """The authoritative list: prismio_toolchain_files[] in build_driver.c.

    Returns (all_files, compiled_files, backend_only, runtime_lib)."""
    text = read(RUNTIME / "build_driver.c")
    m = re.search(
        r"static const PrismioToolchainFile prismio_toolchain_files\[\]\s*=\s*\{(.*?)\n\};",
        text,
        re.S,
    )
    if not m:
        raise Failure("could not find prismio_toolchain_files[] in build_driver.c")

    entries = re.findall(
        r'\{\s*"([^"]+)"\s*,\s*(\d)\s*,\s*(?:"[^"]*"|NULL)\s*,\s*(\d)\s*\}', m.group(1)
    )
    if not entries:
        raise Failure("prismio_toolchain_files[] parsed as empty")

    all_files = [name for name, _, _ in entries]
    compiled = [name for name, comp, _ in entries if comp == "1"]
    runtime_lib = [name for name, comp, rt in entries if comp == "1" and rt == "1"]
    backend = [name for name, comp, rt in entries if comp == "1" and rt == "0"]
    return all_files, compiled, backend, runtime_lib


def embedded_switch_order():
    """The case order in prismio_embedded_text(); must match the table's order."""
    text = read(RUNTIME / "build_driver.c")
    m = re.search(r"static const char\* prismio_embedded_text\(int index\)\s*\{(.*?)\n\}", text, re.S)
    if not m:
        raise Failure("could not find prismio_embedded_text() in build_driver.c")

    cases = re.findall(r"case\s+(\d+):\s*return\s+(\w+);", m.group(1))
    return [sym for _, sym in sorted(cases, key=lambda c: int(c[0]))]


def embedded_generator_list():
    text = read(RUNTIME / "generate_embedded_sources.py")
    m = re.search(r"EMBEDDED_FILES\s*=\s*\[(.*?)\]", text, re.S)
    if not m:
        raise Failure("could not find EMBEDDED_FILES in generate_embedded_sources.py")
    return re.findall(r'\("([^"]+)",\s*"([^"]+)"\)', m.group(1))


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


def package_ps1_lists():
    text = read(TOOLS / "package.ps1")
    m = re.search(r"\$libraries\s*=\s*@\((.*?)\n\)", text, re.S)
    if not m:
        raise Failure("could not find $libraries in package.ps1")
    out = {}
    for name, sources in re.findall(
        r"Name\s*=\s*'(\w+)';\s*Sources\s*=\s*@\((.*?)\)", m.group(1), re.S
    ):
        out[name] = re.findall(r"'([^']+)'", sources)
    return out


def package_sh_lists():
    text = read(TOOLS / "package.sh")
    out = {}
    for name, sources in re.findall(r"^build_archive\s+(\w+)\s+(.*)$", text, re.M):
        out[name] = sources.split()
    if not out:
        raise Failure("could not find build_archive calls in package.sh")
    return out


def symbol_for(filename: str) -> str:
    return "prismio_embedded_" + re.sub(r"[^A-Za-z0-9]", "_", filename)


def main() -> int:
    problems = []

    try:
        all_files, compiled, backend, runtime_lib = toolchain_table()
    except Failure as exc:
        print(f"FAILED: {exc}")
        return 1

    def compare(label, actual, expected):
        if list(actual) != list(expected):
            problems.append(
                f"{label}\n     has: {' '.join(actual) or '(nothing)'}"
                f"\n  expect: {' '.join(expected)}"
            )

    try:
        # Every .c in runtime/ must appear in the table. A file nobody compiles is
        # dead weight at best and a silently-missing feature at worst.
        on_disk = sorted(
            p.name for p in RUNTIME.glob("*.c") if p.name not in IGNORED_SOURCES
        )
        compare("runtime/*.c on disk vs prismio_toolchain_files[]", on_disk, sorted(compiled))

        compare(
            "build_driver.c prismio_embedded_text() switch",
            embedded_switch_order(),
            [symbol_for(f) for f in all_files],
        )

        gen = embedded_generator_list()
        compare(
            "generate_embedded_sources.py EMBEDDED_FILES (files)",
            [f for f, _ in gen],
            all_files,
        )
        compare(
            "generate_embedded_sources.py EMBEDDED_FILES (symbols)",
            [s for _, s in gen],
            [symbol_for(f) for f in all_files],
        )

        compare("tools/bootstrap.ps1 $runtimeSources", bootstrap_ps1_list(), compiled)
        compare("tools/bootstrap.sh RUNTIME_SOURCES", bootstrap_sh_list(), compiled)

        ps1 = package_ps1_lists()
        sh = package_sh_lists()
        for name, expected in (("runtime", runtime_lib), ("backend", backend)):
            compare(f"tools/package.ps1 {name} library", ps1.get(name, []), expected)
            compare(f"tools/package.sh {name} archive", sh.get(name, []), expected)

    except Failure as exc:
        print(f"FAILED: {exc}")
        return 1

    if problems:
        print("Toolchain source lists disagree:\n")
        for p in problems:
            print(f"  {p}\n")
        print("Fix every list above, then re-run runtime/generate_embedded_sources.py.")
        return 1

    print(f"Toolchain source lists agree ({len(compiled)} compiled sources, "
          f"{len(runtime_lib)} in runtime, {len(backend)} in backend).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
