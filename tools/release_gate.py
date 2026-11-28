#!/usr/bin/env python3
"""The release-candidate gate on an already packaged candidate: the `gate` profile.

    python3 tools/release_gate.py --rc build/v0.1-rc/bin/prismio [--old build/<baseline>]

The checks are tools/testkit/checks.py and the profile that orders them is in
tools/testkit/profiles.py; `prismio gate` is the same profile with lint and packaging in
front. `--old` adds a per-function mnemonic diff against a previous compiler.

It does **not** run the performance matrix. That is `benchmarks/run.py`, and the release bar
requires reading a per-function mnemonic diff before believing any timing it prints.
"""
import argparse
import subprocess
import sys
from pathlib import Path

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rc", required=True, help="the packaged candidate compiler")
    parser.add_argument("--old", help="a baseline compiler to diff mnemonics against")
    args = parser.parse_args()
    command = [sys.executable, "-X", "utf8", "-u", str(Path(__file__).resolve().parent / "testkit"),
               "gate", "--packaged", "--compiler", args.rc]
    if args.old:
        command += ["--old", args.old]
    sys.exit(subprocess.call(command))
