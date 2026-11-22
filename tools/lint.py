#!/usr/bin/env python3
"""Run fast, dependency-free repository lint checks."""

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import format_sources


REPO = Path(__file__).resolve().parent.parent
CODE_CALL_PATTERN = re.compile(
    r"\bdiag_(?:error|warning)(?:_at)?_code\(\s*([^,\n]+)"
)
LEGACY_DIAGNOSTIC_PATTERN = re.compile(r"\bdiag_(?:error|warning)(?:_at)?\(")
CODE_AREAS = {
    "src/main.psm": "1",
    "src/project/": "1",
    "src/driver/": "1",
    "src/fmt/": "1",
    "src/lexer/": "2",
    "src/parse/": "3",
    "src/sema/": "4",
    "src/aif/": "5",
}


# The registry of diagnostic codes, src/common/diag_codes.psm: `public const DIAG_<AREA>_<NAME> = "Pnnnn"`.
REGISTRY_PATH = Path("src/common/diag_codes.psm")
REGISTRY_ENTRY = re.compile(r'^public const (DIAG_[A-Z0-9_]+) = "(P\d{4})"\s*$', re.M)
CODE_LITERAL = re.compile(r'"P\d{4}"')
# The area digit a name's prefix promises, and the digit of the code behind it.
NAME_AREAS = {
    "DIAG_CLI_": "1", "DIAG_PROJECT_": "1", "DIAG_DRIVER_": "1", "DIAG_FMT_": "1",
    "DIAG_LEX_": "2", "DIAG_PARSE_": "3", "DIAG_SEMA_": "4", "DIAG_AIF_": "5", "DIAG_COMMON_": "0",
}
DIAGNOSTIC_REGISTRY_CODES = {}


def check_diagnostic_codes():
    """Hold the diagnostic-code registry to what it promises.

    Every code is written once, in the registry; every name is used by exactly one call site; the
    code behind a name is in the area its prefix and the reporting file say; and no `"Pnnnn"` literal
    is left in src/ outside the registry, so the checks cannot go blind by someone typing one."""
    problems = []
    registry_file = REPO / REGISTRY_PATH
    if not registry_file.exists():
        return [f"diagnostic code registry missing: {REGISTRY_PATH}"]
    registry_text = registry_file.read_text(encoding="utf-8")
    entries = REGISTRY_ENTRY.findall(registry_text)
    if not entries:
        return [f"no diagnostic codes parsed from {REGISTRY_PATH}: the registry check has gone blind"]
    by_name, by_code = {}, {}
    for name, code in entries:
        if name in by_name:
            problems.append(f"duplicate diagnostic name {name} in {REGISTRY_PATH}")
        if code in by_code:
            problems.append(f"duplicate diagnostic code {code}: {by_code[code]} and {name}")
        by_name[name] = code
        by_code[code] = name
        prefix_area = next((area for prefix, area in NAME_AREAS.items() if name.startswith(prefix)), None)
        if prefix_area is None:
            problems.append(f"diagnostic name {name} has no known area prefix ({', '.join(NAME_AREAS)})")
        elif code[1] != prefix_area:
            problems.append(f"diagnostic code {code} is outside {name}'s P{prefix_area}xxx area")
    DIAGNOSTIC_REGISTRY_CODES.update(by_code)

    uses = {name: [] for name in by_name}
    texts = {}
    for path in sorted((REPO / "src").rglob("*.psm")):
        relative = path.relative_to(REPO)
        text = path.read_text(encoding="utf-8")
        texts[relative] = text
        if relative == REGISTRY_PATH:
            continue
        for match in CODE_LITERAL.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            problems.append(f"diagnostic code written as a literal, name it in {REGISTRY_PATH}: {relative}:{line}")
        if relative == Path("src/common/diagnostics.psm"):
            # The reporting functions themselves take the code as a parameter.
            pass
        else:
            for match in LEGACY_DIAGNOSTIC_PATTERN.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                problems.append(f"uncoded diagnostic: {relative}:{line}")
        for name in by_name:
            for hit in re.finditer(r"\b" + name + r"\b", text):
                uses[name].append((relative, text.count("\n", 0, hit.start()) + 1))
        if relative == Path("src/common/diagnostics.psm"):
            continue
        for match in CODE_CALL_PATTERN.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            argument = match.group(1).strip()
            if argument in by_name:
                expected_area = next(
                    (area for prefix, area in CODE_AREAS.items() if relative.as_posix().startswith(prefix)), None)
                if expected_area and by_name[argument][1] != expected_area:
                    problems.append(
                        f"diagnostic {argument} ({by_name[argument]}) is outside {relative}'s P{expected_area}xxx area: {relative}:{line}")
                continue
            # A code forwarded from a value that already carries one (a manifest diagnostic's
            # `found.code`) is not a name to look up.
            if re.fullmatch(r"[a-z_]\w*(?:\.[a-z_]\w*)*", argument):
                continue
            problems.append(f"diagnostic code argument {argument} is not a name in {REGISTRY_PATH}: {relative}:{line}")
    for name, places in sorted(uses.items()):
        if not places:
            problems.append(f"diagnostic {name} ({by_name[name]}) is never used: remove it from {REGISTRY_PATH}")
        elif len(places) > 1 and not name.startswith("DIAG_COMMON_") and name not in SHARED_NAMES:
            where = ", ".join(f"{p}:{l}" for p, l in places)
            problems.append(f"diagnostic {name} ({by_name[name]}) is used at {len(places)} places, one code per place: {where}")
    return problems


# Names that are used at more than one place by design: the checker's own entry points, which every
# semantic diagnostic goes through, and the comparison in the reporting module.
SHARED_NAMES = {"DIAG_SEMA_ERROR", "DIAG_SEMA_WARNING", "DIAG_PARSE_SYNTAX"}


def run_check(command, label):
    result = subprocess.run(command, cwd=REPO, capture_output=True, text=True)
    if result.returncode == 0:
        return []
    details = (result.stdout + result.stderr).strip()
    return [f"{label}:\n{details}" if details else f"{label} failed"]


# The first bytes of a native executable, object or static library. A program the
# compiler builds has no extension on Unix, so `.gitignore`'s `*.exe` and `*.o` miss
# it, and `prismio run x.psm` leaves it beside the source: `git add -A` then commits
# a build product. Six were committed under the retired corpus that way.
NATIVE_MAGIC = (
    b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe",  # Mach-O, fat
    b"\x7fELF", b"MZ", b"!<arch>\n",                                       # ELF, PE, ar
)


def tracked_native_binaries():
    """Tracked files that are executables, objects or static libraries."""
    if shutil.which("git") is None:
        return []
    listed = subprocess.run(["git", "ls-files", "-z"], cwd=REPO, capture_output=True)
    if listed.returncode != 0:
        return []
    found = []
    for name in listed.stdout.decode("utf-8", "replace").split("\0"):
        path = REPO / name
        if not name or not path.is_file():
            continue
        with open(path, "rb") as handle:
            head = handle.read(8)
        if head.startswith(NATIVE_MAGIC):
            found.append(name)
    return found


def main():
    problems = []
    for name in tracked_native_binaries():
        problems.append(f"tracked binary: {name} (git rm --cached it; build output is not source)")
    warnings = []
    source_files = list(format_sources.repository_files())

    # Whitespace is hygiene, not correctness: the compiler reads these files fine.
    # It is reported and never fails the run; `python tools/format_sources.py
    # --write` fixes it.
    for path in format_sources.files_needing_format():
        warnings.append(f"format: {path.relative_to(REPO)}")

    for path in source_files:
        relative = path.relative_to(REPO)
        text = path.read_text(encoding="utf-8")
        if path.suffix == ".py":
            try:
                compile(text, str(relative), "exec")
            except SyntaxError as exc:
                problems.append(f"python syntax: {relative}:{exc.lineno}: {exc.msg}")
        if path.suffix == ".psm" and "\t" in text:
            problems.append(f"tabs are not allowed in Prismio source: {relative}")

    if os.name != "nt" and shutil.which("bash"):
        for path in source_files:
            if path.suffix == ".sh":
                problems.extend(run_check(["bash", "-n", str(path)], f"shell syntax: {path.relative_to(REPO)}"))

    problems.extend(
        run_check(
            [sys.executable, "tools/check_source_lists.py"],
            "toolchain source lists",
        )
    )

    problems.extend(check_diagnostic_codes())
    seen_codes = DIAGNOSTIC_REGISTRY_CODES

    if not seen_codes:
        problems.append("no coded compiler diagnostics found")

    annotate = os.environ.get("GITHUB_ACTIONS") == "true"
    for warning in warnings:
        # GitHub shows a `::warning` line as an annotation on the run.
        print(f"::warning title=Formatting::{warning} (run tools/format_sources.py --write)"
              if annotate else f"warning: {warning} (run tools/format_sources.py --write)")

    if problems:
        print("Lint failed:")
        for problem in problems:
            print(f"  {problem}")
        return 1

    print(f"Lint passed ({len(source_files)} source files, {len(seen_codes)} diagnostic codes).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
