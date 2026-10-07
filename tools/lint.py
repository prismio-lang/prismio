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
    "src/lexer/": "2",
    "src/parse/": "3",
    "src/sema/": "4",
    "src/aif/": "5",
}


def run_check(command, label):
    result = subprocess.run(command, cwd=REPO, capture_output=True, text=True)
    if result.returncode == 0:
        return []
    details = (result.stdout + result.stderr).strip()
    return [f"{label}:\n{details}" if details else f"{label} failed"]


# The first bytes of a native executable, object or static library. A program the
# compiler builds has no extension on Unix, so `.gitignore`'s `*.exe` and `*.o` miss
# it, and `prismio run x.psm` leaves it beside the source: `git add -A` then commits
# a build product. Six were committed under aif/corpus/ that way.
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

    seen_codes = {}
    for path in sorted((REPO / "src").rglob("*.psm")):
        relative = path.relative_to(REPO)
        text = path.read_text(encoding="utf-8")
        if relative == Path("src/common/diagnostics.psm"):
            continue
        for match in LEGACY_DIAGNOSTIC_PATTERN.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            problems.append(f"uncoded diagnostic: {relative}:{line}")
        for match in CODE_CALL_PATTERN.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            argument = match.group(1).strip()
            if not re.fullmatch(r'"P\d{4}"', argument):
                problems.append(
                    f"invalid diagnostic code argument {argument}: {relative}:{line}"
                )
                continue
            code = argument[1:-1]
            relative_text = relative.as_posix()
            expected_area = next(
                (area for prefix, area in CODE_AREAS.items() if relative_text.startswith(prefix)),
                None,
            )
            if expected_area and code[1] != expected_area:
                problems.append(
                    f"diagnostic code {code} is outside {relative}'s P{expected_area}xxx area"
                )
            if code in seen_codes:
                problems.append(
                    f"duplicate diagnostic code {code}: {seen_codes[code]} and {relative}:{line}"
                )
            else:
                seen_codes[code] = f"{relative}:{line}"

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
