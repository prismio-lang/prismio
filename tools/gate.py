#!/usr/bin/env python3
"""The pre-push gate, in one command: the `gate` profile of the test engine.

    prismio gate
    python3 tools/gate.py --compiler .prismio/build/debug/prismio

Lint, then the compiler packaged the way RELEASE.md says (a bare generation has no
`lib/runtime/*.bc`; on macOS the package also carries `x86_64-apple-macos` and its SDK
sysroot, which the cross-target check builds for), then every test and every self-hosting
check against that package, with the pinned LLVM first on PATH. Nothing is taken from the
cache. tools/testkit/profiles.py names the checks.

It does not run what only another platform or a CI runner can: Windows, the Linux-only
sanitizer smoke, the benchmark smoke, and the smoke program inlined in
`.github/workflows/ci.yml`. A green run here is the strongest local statement short of a CI
run, not a replacement for one.
"""
import subprocess
import sys
from pathlib import Path

if __name__ == "__main__":
    engine = Path(__file__).resolve().parent / "testkit"
    sys.exit(subprocess.call([sys.executable, "-X", "utf8", "-u", str(engine), "gate",
                              *sys.argv[1:]]))
