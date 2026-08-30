#!/usr/bin/env python3
"""Apply Prismio's deliberately conservative repository text format.

The language does not yet have a syntax-aware formatter. This tool supplies the
safe common denominator for source files: LF line endings, no trailing spaces,
and exactly one final newline. It never rewrites generated embedded sources.
"""

import argparse
import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
FORMATTED_SUFFIXES = {
    ".c", ".h", ".ps1", ".psm", ".py", ".sh", ".ums", ".yaml", ".yml"
}
EXCLUDED_PREFIXES = ("build/", "dist/", "graphify-out/")
EXCLUDED_FILES = {"runtime/embedded_sources.h"}


def repository_files():
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=REPO,
        check=True,
        capture_output=True,
    )
    for raw in result.stdout.split(b"\0"):
        if not raw:
            continue
        relative = raw.decode("utf-8")
        if relative in EXCLUDED_FILES or relative.startswith(EXCLUDED_PREFIXES):
            continue
        path = REPO / relative
        if path.is_file() and path.suffix.lower() in FORMATTED_SUFFIXES:
            yield path


def formatted_text(text):
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = normalized.split("\n")
    while lines and lines[-1] == "":
        lines.pop()
    return "\n".join(line.rstrip(" \t") for line in lines) + "\n"


def files_needing_format():
    changed = []
    for path in repository_files():
        original = path.read_text(encoding="utf-8")
        if formatted_text(original) != original:
            changed.append(path)
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="check only (the default)")
    mode.add_argument("--write", action="store_true", help="rewrite files in place")
    args = parser.parse_args()

    changed = files_needing_format()
    if args.write:
        for path in changed:
            original = path.read_text(encoding="utf-8")
            with path.open("w", encoding="utf-8", newline="\n") as handle:
                handle.write(formatted_text(original))
            print(f"formatted {path.relative_to(REPO)}")
        print(f"Formatted {len(changed)} file(s).")
        return 0

    if changed:
        print("Files need formatting:")
        for path in changed:
            print(f"  {path.relative_to(REPO)}")
        print("Run `python3 tools/format_sources.py --write`.")
        return 1

    print("Source formatting is clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
