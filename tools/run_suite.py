#!/usr/bin/env python3
"""Run the compiler tests against a *copy* of the compiler: `prismio suite`.

    python3 tools/run_suite.py [profile] [patterns] [--compiler PATH] [options]

The engine is tools/testkit (the design record, see tools/testkit/__init__.py); this name stays because
scripts, CI and the documentation call it. Every argument is forwarded, so
`prismio suite -k foo --list` works, and the profile defaults to `dev`. The compiler defaults
to the project host, falling back to the packaged toolchain, and what is tested is always a
copy of its toolchain (testkit/toolchain.py says why). Exits with the run's status.
"""
import subprocess
import sys
from pathlib import Path

if __name__ == "__main__":
    engine = Path(__file__).resolve().parent / "testkit"
    sys.exit(subprocess.call([sys.executable, "-X", "utf8", "-u", str(engine), *sys.argv[1:]]))
