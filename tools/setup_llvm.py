#!/usr/bin/env python3
"""Obtain an LLVM toolchain with the C API headers, and record where it is.

The LLVM C API backend (runtime/llvm-api-backend.c) needs three things:

    include/llvm-c/Core.h    to compile against
    lib/LLVM-C.lib | .so |   to link against
        libLLVM-C.dylib
    bin/                     llc and clang, plus LLVM-C.dll on Windows

Not every LLVM install has all three. The official Windows installer, for one,
ships lib/LLVM-C.lib and bin/LLVM-C.dll but only two of the llvm-c headers, so
"LLVM is installed" is not a usable signal -- this script checks for the actual
files instead of trusting a directory to exist.

Written in Python rather than as a bootstrap.ps1/bootstrap.sh pair on purpose.
Python 3.8+ is already required for the test runner, and the existing paired
shell scripts have to be edited in lockstep with nothing enforcing it. One file
cannot drift against itself.

Usage:
    python tools/setup_llvm.py                 # find or download, then verify
    python tools/setup_llvm.py --check         # report only, change nothing
    python tools/setup_llvm.py --force         # download even if one was found
    python tools/setup_llvm.py --llvm-dir DIR  # adopt an install you already have
    python tools/setup_llvm.py --version 22.1.8
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
THIRD_PARTY = REPO_ROOT / "third_party"
CONFIG_PATH = THIRD_PARTY / "llvm-paths.json"

# A Prismio release targets one LLVM major version, and only that one.
#
# The C API is stable *within* a major version but not across them:
# LLVMBuildGEP was replaced by LLVMBuildGEP2, typed pointers became opaque,
# LLVMArrayType gained LLVMArrayType2. An install that is merely "some LLVM"
# will link and then misbehave, so a mismatched major version is rejected here
# rather than adopted.
#
# Keep REQUIRED_MAJOR in step with PRISMIO_LLVM_EXPECTED_MAJOR in
# runtime/prismio_llvm.h -- the backend re-checks it at runtime via
# LLVMGetVersion(), which is what catches a stray LLVM-C.dll on PATH.
DEFAULT_VERSION = "22.1.8"
REQUIRED_MAJOR = 22

GITHUB_RELEASE_API = "https://api.github.com/repos/llvm/llvm-project/releases/tags/llvmorg-{version}"

# Release asset names are not consistent between LLVM releases (the Linux ones
# carry an Ubuntu version that changes, macOS switched to arm64 naming, and so
# on). Matching on substrings against the actual asset list is durable in a way
# that reconstructing a filename is not.
# Two naming schemes, and both are live in the same release.
#
# LLVM 22 publishes macOS and Linux as `LLVM-<version>-<OS>-<ARCH>.tar.xz` while
# Windows kept the older `clang+llvm-<version>-<triple>.tar.xz`. The old names
# are still listed first-to-match for platforms that have them, because older
# point releases in the pinned major may only carry those.
#
# **This is not hypothetical drift**: on 2026-08-29 the three-platform CI matrix
# failed on macOS and Ubuntu for exactly this -- the release was fetched fine and
# then no pattern matched, because every entry here predated the rename.
#
# Darwin/x86_64 has no asset in 22.1.x at all. Its old pattern is kept so the
# failure names a missing asset rather than a missing platform.
ASSET_PATTERNS = {
    ("Windows", "AMD64"): ["x86_64-pc-windows-msvc"],
    ("Windows", "ARM64"): ["aarch64-pc-windows-msvc", "woa64"],
    ("Darwin", "arm64"): ["macOS-ARM64", "arm64-apple-darwin"],
    ("Darwin", "x86_64"): ["macOS-X64", "x86_64-apple-darwin"],
    ("Linux", "x86_64"): ["Linux-X64", "x86_64-linux-gnu"],
    ("Linux", "aarch64"): ["Linux-ARM64", "aarch64-linux-gnu"],
}


def log(msg: str) -> None:
    print(msg, flush=True)


# ---------------------------------------------------------------------------
# Validating a candidate install
# ---------------------------------------------------------------------------

def lib_names() -> list[str]:
    if sys.platform == "win32":
        return ["LLVM-C.lib"]
    if sys.platform == "darwin":
        return ["libLLVM-C.dylib", "libLLVM.dylib"]
    return ["libLLVM-C.so", "libLLVM.so"]


def detect_version(root: Path) -> str | None:
    """Version of the install at `root`, from llvm-config or clang."""
    suffix = ".exe" if sys.platform == "win32" else ""
    cfg = root / "bin" / ("llvm-config" + suffix)
    if cfg.is_file():
        try:
            out = subprocess.run([str(cfg), "--version"], capture_output=True,
                                 text=True, timeout=20).stdout.strip()
            if out:
                return out
        except (OSError, subprocess.SubprocessError):
            pass

    cc = root / "bin" / ("clang" + suffix)
    if cc.is_file():
        try:
            out = subprocess.run([str(cc), "--version"], capture_output=True,
                                 text=True, timeout=20).stdout
            for tok in out.split():
                if tok and tok[0].isdigit() and "." in tok:
                    return tok
        except (OSError, subprocess.SubprocessError):
            pass
    return None


def major_of(version: str | None) -> int | None:
    if not version:
        return None
    head = version.split(".")[0]
    return int(head) if head.isdigit() else None


def inspect(root: Path, require_major: bool = True) -> dict | None:
    """Return path info if `root` is a usable LLVM install, else None.

    Usable means: the C API header, the link library, *and* the pinned major
    version. Any one of the three missing is a rejection -- an install with the
    library but no headers, or with headers from a different major version,
    fails later in ways that are much harder to diagnose than here.
    """
    if not root or not root.is_dir():
        return None

    header = root / "include" / "llvm-c" / "Core.h"
    if not header.is_file():
        return None

    libdir = root / "lib"
    found_lib = next((libdir / n for n in lib_names() if (libdir / n).is_file()), None)
    if found_lib is None:
        return None

    version = detect_version(root)
    major = major_of(version)
    if require_major and major is not None and major != REQUIRED_MAJOR:
        return None

    return {
        "root": str(root),
        "include": str(root / "include"),
        "lib": str(libdir),
        "bin": str(root / "bin"),
        "link_library": found_lib.name,
        "version": version or "unknown",
        "required_major": REQUIRED_MAJOR,
    }


def candidate_roots() -> list[Path]:
    """Places an LLVM with headers plausibly lives, best guess first."""
    roots: list[Path] = []

    env = os.environ.get("PRISMIO_LLVM_DIR")
    if env:
        roots.append(Path(env))

    roots.append(THIRD_PARTY / "llvm")

    # Whatever llvm-config on PATH claims, if it is telling the truth.
    exe = shutil.which("llvm-config")
    if exe:
        try:
            prefix = subprocess.run(
                [exe, "--prefix"], capture_output=True, text=True, timeout=15
            ).stdout.strip()
            if prefix:
                roots.append(Path(prefix))
        except (OSError, subprocess.SubprocessError):
            pass

    if sys.platform == "win32":
        roots += [Path(r"C:\Program Files\LLVM"), Path(r"C:\Program Files (x86)\LLVM")]
        downloads = Path.home() / "Downloads"
        if downloads.is_dir():
            # A manually downloaded release archive, already extracted.
            roots += sorted(
                (p for p in downloads.glob("clang+llvm-*") if p.is_dir()), reverse=True
            )
    elif sys.platform == "darwin":
        roots += [
            Path("/opt/homebrew/opt/llvm"),
            Path("/usr/local/opt/llvm"),
            Path("/Library/Developer/CommandLineTools/usr"),
        ]
    else:
        roots += [Path("/usr/lib/llvm"), Path("/usr"), Path("/usr/local")]
        roots += sorted(
            (p for p in Path("/usr/lib").glob("llvm-*") if p.is_dir()), reverse=True
        )

    return roots


def find_existing() -> dict | None:
    for root in candidate_roots():
        info = inspect(root)
        if info:
            return info
    return None


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

def select_asset(version: str) -> tuple[str, str]:
    key = (platform.system(), platform.machine())
    patterns = ASSET_PATTERNS.get(key)
    if not patterns:
        raise SystemExit(
            f"No LLVM release asset is known for {key[0]}/{key[1]}.\n"
            f"Install LLVM yourself and re-run with --llvm-dir <path>."
        )

    url = GITHUB_RELEASE_API.format(version=version)
    log(f"Querying {url}")
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "prismio-setup"}

    # Authenticate when a token is available. Unauthenticated calls to the
    # GitHub API are rate-limited *per IP*, and a CI runner shares its IP with
    # everything else on that host -- which is why this returned **403** on
    # ubuntu-latest and macos-latest simultaneously while the same command
    # worked from a laptop. Nothing here needs the token's permissions; it is
    # the rate-limit bucket that changes.
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            release = json.load(resp)
    except urllib.error.HTTPError as e:
        hint = ("Check the version exists, or pass --llvm-dir."
                if e.code != 403 else
                "403 is the unauthenticated rate limit, not a missing release: "
                "set GITHUB_TOKEN, or pass --llvm-dir.")
        raise SystemExit(f"GitHub API returned {e.code} for LLVM {version}. {hint}")
    except urllib.error.URLError as e:
        raise SystemExit(f"Could not reach GitHub: {e.reason}")

    assets = release.get("assets", [])
    for pat in patterns:
        for asset in assets:
            name = asset["name"]
            if pat in name and name.endswith((".tar.xz", ".tar.gz")):
                return name, asset["browser_download_url"]

    available = "\n  ".join(a["name"] for a in assets[:25]) or "(none)"
    raise SystemExit(
        f"No asset matching {patterns} in LLVM {version}. Available:\n  {available}"
    )


def download(url: str, dest: Path) -> None:
    log(f"Downloading {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "prismio-setup"})
    with urllib.request.urlopen(req, timeout=120) as resp, open(dest, "wb") as out:
        total = int(resp.headers.get("Content-Length") or 0)
        read = 0
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            out.write(chunk)
            read += len(chunk)
            if total:
                pct = read * 100 // total
                print(f"\r  {pct:3d}%  {read >> 20} / {total >> 20} MiB", end="", flush=True)
        print()


def extract(archive: Path, into: Path) -> Path:
    log(f"Extracting {archive.name} (this takes a minute -- the archive is large)")
    into.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as tf:
        top = {Path(m.name).parts[0] for m in tf.getmembers() if m.name.strip("./")}
        # Python 3.12+ warns without a filter; 'data' is the safe extraction mode.
        try:
            tf.extractall(into, filter="data")  # type: ignore[call-arg]
        except TypeError:
            tf.extractall(into)
    if len(top) != 1:
        raise SystemExit(f"Unexpected archive layout: {sorted(top)[:5]}")
    return into / top.pop()


def fetch(version: str) -> dict:
    name, url = select_asset(version)
    THIRD_PARTY.mkdir(parents=True, exist_ok=True)
    target = THIRD_PARTY / "llvm"

    if target.exists():
        log(f"Replacing existing {target}")
        shutil.rmtree(target)

    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / name
        download(url, archive)
        extracted = extract(archive, Path(tmp) / "x")
        shutil.move(str(extracted), str(target))

    info = inspect(target)
    if not info:
        raise SystemExit(
            f"Downloaded LLVM to {target} but it has no llvm-c/Core.h or link "
            f"library. This release may not ship the C API for this platform."
        )
    return info


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

PROBE = """
#include <llvm-c/Core.h>
int main(void) {
    LLVMContextRef c = LLVMContextCreate();
    LLVMModuleRef m = LLVMModuleCreateWithNameInContext("probe", c);
    LLVMDisposeModule(m);
    LLVMContextDispose(c);
    return 0;
}
"""


def verify(info: dict) -> bool:
    """Compile and link a probe. Finding the files is not proof they work."""
    cc = shutil.which("clang") or shutil.which("cc") or shutil.which("gcc")
    if not cc:
        log("! No C compiler on PATH, skipping the link check.")
        return True

    linkarg = "-lLLVM-C" if "LLVM-C" in info["link_library"] else "-lLLVM"
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "probe.c"
        src.write_text(PROBE)
        exe = Path(tmp) / ("probe.exe" if sys.platform == "win32" else "probe")
        cmd = [cc, str(src), "-o", str(exe), f"-I{info['include']}",
               f"-L{info['lib']}", linkarg]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            log("! Probe failed to build:")
            log("  " + (r.stderr.strip().splitlines() or ["(no output)"])[0])
            return False
    log("Verified: llvm-c compiles and links.")
    return True


# ---------------------------------------------------------------------------

def write_config(info: dict) -> None:
    THIRD_PARTY.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(json.dumps(info, indent=2) + "\n")
    log(f"Wrote {CONFIG_PATH.relative_to(REPO_ROOT)}")


def report(info: dict) -> None:
    log("")
    log(f"LLVM toolchain (pinned to {REQUIRED_MAJOR}.x)")
    log(f"  version {info['version']}")
    log(f"  root    {info['root']}")
    log(f"  include {info['include']}")
    log(f"  lib     {info['lib']}  ({info['link_library']})")
    log(f"  bin     {info['bin']}")
    log("")
    log("Build the LLVM C API backend with:")
    log(f"  clang -DPRISMIO_LLVM_REAL_HEADERS -I\"{info['include']}\" \\")
    log(f"        -c runtime/llvm-api-backend.c")
    log(f"  link with -L\"{info['lib']}\" -l{info['link_library'].removeprefix('lib').removesuffix('.lib').removesuffix('.so').removesuffix('.dylib')}")
    if sys.platform == "win32":
        log("")
        log(f"LLVM-C.dll must be on PATH at runtime:  {info['bin']}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version", default=DEFAULT_VERSION,
                    help=f"LLVM release to fetch (default {DEFAULT_VERSION})")
    ap.add_argument("--force", action="store_true",
                    help="download even if a usable install was found")
    ap.add_argument("--check", action="store_true",
                    help="report what would be used and exit without changing anything")
    ap.add_argument("--llvm-dir", help="adopt this install instead of searching or downloading")
    args = ap.parse_args()

    if args.llvm_dir:
        root = Path(args.llvm_dir)
        info = inspect(root)
        if not info:
            # Say which of the three requirements failed, rather than a blanket
            # "not usable" that leaves the user guessing.
            log(f"{args.llvm_dir} is not usable for this Prismio.")
            if not (root / "include" / "llvm-c" / "Core.h").is_file():
                log("  missing include/llvm-c/Core.h (the C API headers)")
            elif not any((root / "lib" / n).is_file() for n in lib_names()):
                log(f"  missing a C API link library in lib/ (expected one of {lib_names()})")
            else:
                found = detect_version(root)
                log(f"  version is {found}, but this Prismio requires LLVM {REQUIRED_MAJOR}.x")
                log(f"  the C API is not stable across major versions")
            return 1
        log(f"Adopting {info['root']} (LLVM {info['version']})")
    else:
        info = None if args.force else find_existing()
        if info:
            log(f"Found LLVM {info['version']} at {info['root']}")
        elif args.check:
            log(f"No usable LLVM {REQUIRED_MAJOR}.x found.")
            log("Needs llvm-c/Core.h, a C API link library, and the pinned major version.")
            log("Run without --check to download one.")
            return 1
        else:
            log(f"No usable LLVM {REQUIRED_MAJOR}.x found. Fetching {args.version}.")
            info = fetch(args.version)

    if args.check:
        report(info)
        return 0

    ok = verify(info)
    write_config(info)
    report(info)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
