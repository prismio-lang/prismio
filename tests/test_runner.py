#!/usr/bin/env python3
"""A compatibility name for the test engine, tools/testkit.

    PRISMIO=build/gen2 python3 tests/test_runner.py [patterns] [options]

Runs every test (the `full` profile: nothing is skipped), choosing the compiler as this
runner always did: `--compiler`, then `$PRISMIO`, then `prismio` on PATH. With neither set,
`prismio suite` is the better command: it tests the compiler this checkout built.

The harness tests that lived here are in tests/harness/, one module per suite.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

if __name__ == "__main__":
    arguments = sys.argv[1:]
    named = any(a == "--compiler" or a.startswith("--compiler=") for a in arguments)
    if not named and not os.environ.get("PRISMIO") and "--list" not in arguments:
        found = shutil.which("prismio")
        if not found:
            print("prismio not found in PATH. Install Prismio, add it to PATH, or set $PRISMIO.")
            sys.exit(1)
        arguments = ["--compiler", found, *arguments]
    engine = Path(__file__).resolve().parent.parent / "tools" / "testkit"
    sys.exit(subprocess.call([sys.executable, "-X", "utf8", "-u", str(engine), "full",
                              *arguments]))
