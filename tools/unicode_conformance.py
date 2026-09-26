#!/usr/bin/env python3
"""Run std.unicode against the UCD's conformance tests, at the pinned version.

    python3 tools/unicode_conformance.py --compiler <packaged prismio>

Builds tools/unicode_conformance.psm and runs it over GraphemeBreakTest.txt and
NormalizationTest.txt, fetched and hash-checked exactly as the table generator
fetches its sources. Exit status 0 means every line of both files passed.

The suite's tests/test_137_unicode.psm asserts a handful of cases by hand; this
is the whole of what the standard publishes, which is what `std.unicode
implements UAX #29 and UAX #15` has to mean.
"""

import argparse
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_unicode_tables as ucd  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--compiler", default="prismio",
                        help="a packaged toolchain's prismio (default: the one on PATH)")
    parser.add_argument("--ucd-dir", help="a directory already holding the pinned files")
    args = parser.parse_args()

    ucd_dir = os.path.abspath(args.ucd_dir) if args.ucd_dir else ucd.DEFAULT_UCD_DIR
    ucd.fetch_ucd(ucd_dir, offline=bool(args.ucd_dir))

    harness = os.path.join(ucd.REPO, "tools", "unicode_conformance.psm")
    with tempfile.TemporaryDirectory(prefix="prismio-unicode-") as temp_dir:
        exe = os.path.join(temp_dir, "conformance.exe" if os.name == "nt" else "conformance")
        built = subprocess.run([args.compiler, "build", harness, "-o", exe],
                               capture_output=True, text=True)
        if built.returncode != 0:
            sys.stderr.write(built.stdout + built.stderr)
            return built.returncode or 1
        ran = subprocess.run([exe,
                              os.path.join(ucd_dir, "ucd", "auxiliary", "GraphemeBreakTest.txt"),
                              os.path.join(ucd_dir, "ucd", "NormalizationTest.txt")])
        return ran.returncode


if __name__ == "__main__":
    sys.exit(main())
