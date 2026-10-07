#!/usr/bin/env python3
"""Fetch the bootstrap seed: LLVM IR for the compiler, published with a release.

A machine with no prismio binary cannot compile `src/main.psm`, and the seed is
the smallest artifact that breaks that cycle. It is **not tracked in git** (17 MB
of generated IR per refresh made every clone pay for every seed ever cut). It is
a release asset, `prismio-seed-<version>.ll`, and `bootstrap/seed.json` pins
which one this tree builds from, by version and SHA-256:

    {"version": "0.1.0", "sha256": "..."}

The download is checked against that hash, so a seed is never trusted for being
at the right URL. The result is cached in `bootstrap/`, which git ignores.

Usage:
    python tools/fetch_seed.py            # fetch if missing or wrong; print the path
    python tools/fetch_seed.py --check    # print the path of a verified seed, never download
    python tools/fetch_seed.py --pin FILE [--version V]
                                          # record FILE as the seed for V (default: the
                                          # compiler's PRISMIO_VERSION); used by refresh_seed

Only the path goes to stdout, so `SEED="$(python3 tools/fetch_seed.py)"` works;
progress goes to stderr.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import re
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
BOOTSTRAP = REPO / "bootstrap"
PIN = BOOTSTRAP / "seed.json"

RELEASES = "https://github.com/prismio-lang/prismio/releases/download"

sys.path.insert(0, str(TOOLS))
import setup_llvm  # noqa: E402  (download() resumes, retries, and has the Windows TLS fallback)


def seed_name(version: str) -> str:
    return f"prismio-seed-{version}.ll"


def read_pin() -> dict:
    try:
        pin = json.loads(PIN.read_text(encoding="utf-8"))
        return {"version": str(pin["version"]), "sha256": str(pin["sha256"]).lower()}
    except (OSError, ValueError, KeyError) as e:
        raise SystemExit(f"fetch_seed: cannot read {PIN.relative_to(REPO)}: {e}")


def source_version() -> str:
    text = (REPO / "src" / "main.psm").read_text(encoding="utf-8")
    m = re.search(r'^let PRISMIO_VERSION = "([^"]+)"', text, re.M)
    if not m:
        raise SystemExit("fetch_seed: PRISMIO_VERSION not found in src/main.psm")
    return m.group(1)


def verified(path: Path, sha256: str) -> bool:
    return path.is_file() and setup_llvm.sha256_of(path) == sha256


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="never download")
    ap.add_argument("--pin", metavar="FILE", help="record FILE as the pinned seed")
    ap.add_argument("--version", help="with --pin: the version the seed is published under")
    args = ap.parse_args()

    if args.pin:
        file = Path(args.pin).resolve()
        if not file.is_file():
            raise SystemExit(f"fetch_seed: {file} is not a file")
        version = args.version or source_version()
        sha = setup_llvm.sha256_of(file)
        PIN.parent.mkdir(parents=True, exist_ok=True)
        PIN.write_text(json.dumps({"version": version, "sha256": sha}, indent=2) + "\n",
                       encoding="utf-8")
        print(f"pinned {seed_name(version)} sha256 {sha}", file=sys.stderr)
        print(f"upload it:  gh release upload v{version} {file}", file=sys.stderr)
        return 0

    pin = read_pin()
    dest = BOOTSTRAP / seed_name(pin["version"])
    if verified(dest, pin["sha256"]):
        print(dest)
        return 0
    if args.check:
        raise SystemExit(f"fetch_seed: no verified seed at {dest.relative_to(REPO)}; "
                         f"run python tools/fetch_seed.py")

    # 17 MB is not worth resuming, and a leftover that fails the pin would be
    # resumed from as if it were the front of the right file.
    dest.unlink(missing_ok=True)
    url = f"{RELEASES}/v{pin['version']}/{seed_name(pin['version'])}"
    with contextlib.redirect_stdout(sys.stderr):
        setup_llvm.download(url, dest, pin["sha256"])
    print(dest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
