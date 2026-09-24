#!/usr/bin/env python3
"""Provision the pinned LLVM into third_party/llvm, and record how to link it.

**The LLVM a Prismio compiler is built against is part of the checkout, not of
the machine.** This downloads one exact release, checks it against a SHA-256
recorded below, and prepares it under `third_party/llvm`. Nothing already
installed -- Homebrew, apt, `llvm-config` on PATH -- is consulted. That used to
be the default, and it meant every compiler binary loaded Homebrew's
`libLLVM-C.dylib` by an absolute path that a `brew upgrade llvm` repointed
(KNOWN_ISSUES "Toolchain layout", 2026-09-17).

What the backend (runtime/llvm-api-backend.c) needs from it:

    include/llvm-c/Core.h    to compile against
    link.rsp                 to link against -- a response file naming the
                             static archives, so the compiler carries LLVM
                             inside it and loads no LLVM at run time
    bin/clang                to build the runtime bitcode, which has to come
                             from the same LLVM that reads it

**The official macOS and Linux archives ship no shared LLVM library, and their
static archives are ThinLTO bitcode**, not machine code. Linking them directly
needs an LTO linker of exactly this LLVM version: Apple's `ld` reads bitcode
through Xcode's older libLTO and reports thousands of undefined symbols, and
LLVM 23's own `ld64.lld` cannot parse the `.tbd` stubs of the macOS 27 SDK
(`unknown target arm64e.x1-macos`). So setup lowers the members the compiler
uses to native objects once -- about 75 s on ten cores -- and every compiler
link after that is an ordinary link with the system linker. The one foreign
library LLVM was built against, zstd, is built from its pinned source here
too, because the archive names the build machine's `/opt/homebrew/lib/libzstd.a`.

Windows is the exception: its archive ships `LLVM-C.lib` and `LLVM-C.dll`, the
import library is linked, and the bootstrap copies the DLL beside the compiler.

Usage:
    python tools/setup_llvm.py                 # download, verify, prepare (idempotent)
    python tools/setup_llvm.py --check         # report the recorded toolchain, change nothing
    python tools/setup_llvm.py --force         # re-download and re-prepare
    python tools/setup_llvm.py --keep-all      # do not prune tools the build never runs
    python tools/setup_llvm.py --llvm-dir DIR  # adopt an install you already have (not pinned)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
THIRD_PARTY = REPO_ROOT / "third_party"
CONFIG_PATH = THIRD_PARTY / "llvm-paths.json"
LLVM_DIR = THIRD_PARTY / "llvm"
DOWNLOADS = THIRD_PARTY / ".downloads"

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
# LLVMGetVersion().
LLVM_VERSION = "23.1.1"
REQUIRED_MAJOR = 23

RELEASE_URL = "https://github.com/llvm/llvm-project/releases/download/llvmorg-{version}/{name}"

# One archive per platform, by exact name and digest. The digests are the ones
# GitHub publishes for the release assets; a download that does not match is
# deleted, never extracted. Changing LLVM_VERSION means changing every row.
#
# `.tar.xz` rather than the `.tar.zst` beside it: `tarfile` cannot read zstd
# before Python 3.14, and the fallback extractor is `tarfile`.
#
# Darwin/x86_64 has no asset in 23.1.x at all.
ASSETS = {
    ("Darwin", "arm64"): (
        "LLVM-23.1.1-macOS-ARM64.tar.xz",
        "64220f1c99132ef7e580447781b84f96fbba6862a43a8f6522b423052cd67502"),
    ("Linux", "x86_64"): (
        "LLVM-23.1.1-Linux-X64.tar.xz",
        "832aeb58d105de1cabc7b982dd2c65de0610f7377df48ae8fc2dd8e97420a15c"),
    ("Linux", "aarch64"): (
        "LLVM-23.1.1-Linux-ARM64.tar.xz",
        "3fbaaa6a1f147557a4095b9911f8dc2d4c745a11863982f76ee20e248c190a80"),
    ("Windows", "AMD64"): (
        "clang+llvm-23.1.1-x86_64-pc-windows-msvc.tar.xz",
        "c54ac8146b420fe72e11e6fdd56498d6818011ad23267196b6ab37b5ac9264c3"),
    ("Windows", "ARM64"): (
        "clang+llvm-23.1.1-aarch64-pc-windows-msvc.tar.xz",
        "c8cd61f6624accf0d0f9f4519ddcc97745c6a865205bb43f364b6aaf9c50a31e"),
}

# The one library the official build links that the archive does not carry.
ZSTD_VERSION = "1.5.7"
ZSTD_URL = "https://github.com/facebook/zstd/releases/download/v{v}/zstd-{v}.tar.gz"
ZSTD_SHA256 = "eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3"

# What the backend calls into. `all-targets` because `--target` accepts any
# triple LLVM knows and the backend initialises every target it was built with.
COMPONENTS = [
    "all-targets", "core", "analysis", "bitreader", "bitwriter", "irreader",
    "linker", "orcjit", "passes", "target", "transformutils", "ipo",
]

# Bumped whenever what `prepare` produces changes, so an older preparation is
# redone rather than trusted.
PREPARED_FORMAT = 1
PREPARED_MARKER = ".prismio-prepared.json"

# Everything else in bin/ is several gigabytes the build never runs.
KEEP_TOOLS = {
    "clang", "clang++", f"clang-{REQUIRED_MAJOR}", "clang-cl", "llvm-config",
    "llvm-dis", "llvm-nm", "llvm-ar", "llvm-lib", "llvm-link", "llvm-extract",
    "llvm-objdump", "llvm-symbolizer", "llc", "opt", "dsymutil",
    "lld", "ld.lld", "ld64.lld", "lld-link", "wasm-ld",
}


def log(msg: str) -> None:
    print(msg, flush=True)


def exe(name: str) -> str:
    return name + (".exe" if sys.platform == "win32" else "")


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, dest: Path, sha256: str) -> None:
    """Fetch `url` to `dest`, resuming a partial file, and verify it.

    **A stall is a failure, not a wait.** The first attempt at this on a laptop
    stopped 60 MiB short of 1.5 GiB and sat there with the connection open;
    without a read timeout nothing ever returns. Each read waits at most 60 s,
    and a timed-out or dropped transfer resumes from the bytes already on disk.
    """
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_file() and sha256_of(dest) == sha256:
        log(f"Using the verified {dest.name} already downloaded")
        return

    log(f"Downloading {url}")
    for attempt in range(1, 9):
        have = dest.stat().st_size if dest.is_file() else 0
        headers = {"User-Agent": "prismio-setup"}
        if have:
            headers["Range"] = f"bytes={have}-"
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=60) as resp:
                if have and resp.status != 206:
                    have = 0  # the server ignored the range: start over
                total = have + int(resp.headers.get("Content-Length") or 0)
                with open(dest, "ab" if have else "wb") as out:
                    read = have
                    while True:
                        chunk = resp.read(1 << 20)
                        if not chunk:
                            break
                        out.write(chunk)
                        read += len(chunk)
                        if total:
                            print(f"\r  {read * 100 // total:3d}%  {read >> 20} / {total >> 20} MiB",
                                  end="", flush=True)
                print()
            break
        except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as e:
            print()
            if isinstance(e, urllib.error.HTTPError) and e.code == 416:
                break  # nothing left to fetch; the digest decides
            if isinstance(e, urllib.error.HTTPError) and e.code < 500:
                raise SystemExit(f"{url} returned {e.code}")
            log(f"  interrupted ({e}); resuming, attempt {attempt + 1}")
            time.sleep(min(2 * attempt, 10))
    else:
        raise SystemExit(f"Could not download {url}")

    actual = sha256_of(dest)
    if actual != sha256:
        dest.unlink()
        raise SystemExit(f"{dest.name}: SHA-256 {actual}, expected {sha256}. "
                         f"The file was deleted; run setup again.")
    log(f"Verified {dest.name} (sha256 {sha256[:16]}...)")


def extract(archive: Path, into: Path) -> Path:
    """Unpack a single-directory archive into `into`, returning that directory.

    The system `tar` first: Python's lzma is several times slower on a 1.5 GiB
    archive, and both macOS and Windows 10+ ship a bsdtar that reads `.tar.xz`.
    """
    log(f"Extracting {archive.name}")
    if into.exists():
        shutil.rmtree(into)
    into.mkdir(parents=True)
    tar = shutil.which("tar")
    done = False
    if tar:
        done = subprocess.run([tar, "-xf", str(archive), "-C", str(into)]).returncode == 0
    if not done:
        shutil.rmtree(into)
        into.mkdir(parents=True)
        with tarfile.open(archive) as tf:
            try:
                tf.extractall(into, filter="data")  # type: ignore[call-arg]
            except TypeError:
                tf.extractall(into)
    top = [p for p in into.iterdir()]
    if len(top) != 1 or not top[0].is_dir():
        raise SystemExit(f"Unexpected archive layout: {[p.name for p in top][:5]}")
    return top[0]


# ---------------------------------------------------------------------------
# Preparing the static libraries
# ---------------------------------------------------------------------------

def run(cmd: list, **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def llvm_config(root: Path, *args: str) -> str:
    r = run([str(root / "bin" / exe("llvm-config")), *args])
    if r.returncode != 0:
        raise SystemExit(f"llvm-config {' '.join(args)} failed:\n{r.stderr}")
    return r.stdout.strip()


def macos_sdk() -> str:
    r = run(["xcrun", "--show-sdk-path"])
    sdk = r.stdout.strip()
    if r.returncode != 0 or not sdk:
        raise SystemExit("No macOS SDK found. Install the Command Line Tools: xcode-select --install")
    return sdk


def write_clang_config(root: Path) -> None:
    """Point the official clang at the macOS SDK.

    The release clang is built with no default sysroot, so it cannot find
    `<inttypes.h>`. Homebrew solves the same thing with a config file, which
    clang reads from beside its own binary -- one per driver name, so `clang++`
    needs its own. The unversioned `MacOSX.sdk` path `xcrun` prints survives an
    Xcode update.
    """
    line = f"--sysroot={macos_sdk()}\n"
    for driver in ("clang", "clang++"):
        (root / "bin" / f"{driver}.cfg").write_text(line)


def is_bitcode(path: Path) -> bool:
    with open(path, "rb") as f:
        magic = f.read(4)
    # Raw bitcode, and the wrapper Apple's toolchain puts around it.
    return magic in (b"BC\xc0\xde", b"\xde\xc0\x17\x0b")


def lower_archives(root: Path, out: Path, archives: list[Path]) -> list[Path]:
    """Rebuild each archive with native members, lowering any bitcode ones.

    -O2 over ThinLTO pre-link bitcode, which is already optimised per module:
    what is lost is the cross-module inlining a full LTO link would do, and the
    compiler never had that from the Homebrew dylib either.
    """
    clang = str(root / "bin" / exe("clang"))
    ar = str(root / "bin" / exe("llvm-ar"))
    work = out / "objects"
    jobs = []
    plan = []
    for archive in archives:
        d = work / archive.stem
        d.mkdir(parents=True, exist_ok=True)
        members = run([ar, "t", str(archive)]).stdout.split()
        members = [m for m in members if not m.startswith("__.SYMDEF") and m != "SORTED"]
        if len(members) != len(set(members)):
            # `ar x` would overwrite one with the other and lose code silently.
            raise SystemExit(f"{archive.name} has two members with one name")
        r = run([ar, "x", str(archive)], cwd=d)
        if r.returncode != 0:
            raise SystemExit(f"could not unpack {archive.name}: {r.stderr}")
        natives = []
        for m in members:
            src = d / m
            if is_bitcode(src):
                dst = d / (m + ".native.o")
                jobs.append((src, dst))
                natives.append(dst)
            else:
                natives.append(src)
        plan.append((archive, natives))

    log(f"Lowering {len(jobs)} bitcode objects from {len(archives)} archives "
        f"on {os.cpu_count()} threads (once; about a minute)")

    def lower(job):
        src, dst = job
        r = run([clang, "-O2", "-c", "-x", "ir", str(src), "-o", str(dst)])
        return None if r.returncode == 0 else f"{src.name}: {r.stderr[:400]}"

    with ThreadPoolExecutor(os.cpu_count() or 4) as pool:
        failures = [f for f in pool.map(lower, jobs) if f]
    if failures:
        raise SystemExit("Lowering failed:\n  " + "\n  ".join(failures[:5]))

    produced = []
    for archive, natives in plan:
        target = out / archive.name
        if target.exists():
            target.unlink()
        r = run([ar, "rcs", str(target), *map(str, natives)])
        if r.returncode != 0:
            raise SystemExit(f"could not write {target.name}: {r.stderr}")
        produced.append(target)
    shutil.rmtree(work)
    return produced


def build_zstd(root: Path, out: Path) -> Path:
    archive = DOWNLOADS / f"zstd-{ZSTD_VERSION}.tar.gz"
    download(ZSTD_URL.format(v=ZSTD_VERSION), archive, ZSTD_SHA256)
    src = extract(archive, out / "zstd-src")
    clang = str(root / "bin" / exe("clang"))
    objs = []
    sources = [p for sub in ("common", "compress", "decompress")
               for p in sorted((src / "lib" / sub).glob("*.c"))]
    log(f"Building zstd {ZSTD_VERSION} ({len(sources)} files)")

    def compile_one(c: Path):
        o = out / f"zstd-{c.stem}.o"
        # No assembly and no threads: LLVM calls the one-shot API only.
        r = run([clang, "-O2", "-fPIC", "-DZSTD_DISABLE_ASM", "-DZSTD_MULTITHREAD=0",
                 "-c", str(c), "-o", str(o)])
        return o, (None if r.returncode == 0 else f"{c.name}: {r.stderr[:400]}")

    with ThreadPoolExecutor(os.cpu_count() or 4) as pool:
        results = list(pool.map(compile_one, sources))
    bad = [e for _, e in results if e]
    if bad:
        raise SystemExit("zstd failed to build:\n  " + "\n  ".join(bad[:5]))
    objs = [o for o, _ in results]
    lib = out / "libzstd.a"
    if lib.exists():
        lib.unlink()
    r = run([str(root / "bin" / exe("llvm-ar")), "rcs", str(lib), *map(str, objs)])
    if r.returncode != 0:
        raise SystemExit(f"could not archive zstd: {r.stderr}")
    for o in objs:
        o.unlink()
    shutil.rmtree(src.parent)
    return lib


def system_libs(root: Path, prepared: list[Path]) -> list[str]:
    """What the static archives need from the system, spelled for the link.

    llvm-config reports what LLVM's own build machine linked, which is where
    the absolute `/opt/homebrew/lib/libzstd.a` comes from. zstd is replaced by
    the one built above; libxml2 is dropped because nothing the compiler links
    reaches it (measured: the probe links without it). The C++ standard library
    is not in that list at all and has to be added by hand.
    """
    libs = []
    for tok in llvm_config(root, "--system-libs", "--link-static").split():
        if "zstd" in tok or "xml2" in tok:
            continue
        libs.append(tok)
    if sys.platform == "darwin":
        libs.append("-lc++")
    else:
        # Which C++ library the release was built against shows in its mangled
        # names: libc++ puts everything in std::__1.
        nm = str(root / "bin" / exe("llvm-nm"))
        support = next(p for p in prepared if p.name == "libLLVMSupport.a")
        names = run([nm, "--no-demangle", str(support)]).stdout
        libs.append("-lc++" if "St3__1" in names or "NSt3__1" in names else "-lstdc++")
    return libs


def prepare(root: Path, keep_all: bool) -> dict:
    """Turn an extracted release into what the build links. Returns the info."""
    out = root / "lib" / "prismio"
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    if sys.platform == "darwin":
        write_clang_config(root)

    if sys.platform == "win32":
        link_args = [str(root / "lib" / "LLVM-C.lib")]
    else:
        archives = [Path(p) for p in
                    llvm_config(root, "--libfiles", "--link-static", *COMPONENTS).split()]
        prepared = lower_archives(root, out, archives)
        zstd = build_zstd(root, out)
        link_args = [str(p) for p in prepared] + [str(zstd)] + system_libs(root, prepared)

    rsp = out / "link.rsp"
    # One argument per line, quoted: clang and gcc both read `@file` this way,
    # and a checkout path with a space in it must stay one argument. Forward
    # slashes, because clang tokenizes a response file GNU-style on Windows too,
    # where a backslash inside quotes is an escape: CI's first Windows run read
    # `D:\a\prismio\...\LLVM-C.lib` as `D:aprismio...LLVM-C.lib`. Every
    # Windows API takes `/` as a separator, so nothing else needs to know.
    rsp.write_text("".join(f'"{Path(a).as_posix()}"\n' if not a.startswith("-") else f"{a}\n"
                           for a in link_args))

    if not keep_all:
        prune(root)

    return {
        "root": str(root),
        "include": str(root / "include"),
        "lib": str(root / "lib"),
        "bin": str(root / "bin"),
        "link_library": "LLVM-C.lib" if sys.platform == "win32" else "static",
        "link_rsp": str(rsp),
        "version": LLVM_VERSION,
        "required_major": REQUIRED_MAJOR,
    }


def prune(root: Path) -> None:
    """Drop what the build never touches: ~7 GiB of the 8 unpacked on macOS.

    The bitcode archives are gone once lowered, the shared libraries back tools
    that are themselves removed, and bin/ keeps only KEEP_TOOLS. lib/clang (the
    resource headers) and lib/prismio stay.
    """
    before = sum(f.stat().st_size for f in root.rglob("*") if f.is_file() and not f.is_symlink())
    lib = root / "lib"
    if sys.platform != "win32":
        for f in lib.iterdir():
            # libLTO stays: the release clang passes `-lto_library` naming it on
            # every Darwin link, and ld warns when it is gone.
            if f.name.startswith("libLTO."):
                continue
            if f.is_file() and (f.suffix in (".a", ".dylib", ".so") or ".so." in f.name):
                f.unlink()
        for d in ("cmake", "objects-Release"):
            if (lib / d).is_dir():
                shutil.rmtree(lib / d)
    keep = {exe(t) for t in KEEP_TOOLS}
    # A kept symlink needs what it points at: clang -> clang-23.
    for name in list(keep):
        p = root / "bin" / name
        if p.is_symlink():
            keep.add(os.readlink(p))
    for f in (root / "bin").iterdir():
        if f.name.endswith(".cfg") or f.name in keep:
            continue
        if f.suffix == ".dll" and sys.platform == "win32":
            continue  # tools and LLVM-C.dll load these
        if f.is_dir() and not f.is_symlink():
            shutil.rmtree(f)
        else:
            f.unlink()
    after = sum(f.stat().st_size for f in root.rglob("*") if f.is_file() and not f.is_symlink())
    log(f"Pruned {(before - after) >> 20} MiB; {after >> 20} MiB remain")


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

PROBE = """
#include <llvm-c/Core.h>
#include <llvm-c/Target.h>
#include <llvm-c/LLJIT.h>
#include <stdio.h>
int main(void) {
    LLVMInitializeAllTargetInfos();
    LLVMInitializeAllTargets();
    LLVMInitializeAllTargetMCs();
    LLVMOrcLLJITRef jit = NULL;
    LLVMErrorRef err = LLVMOrcCreateLLJIT(&jit, NULL);
    if (err) return 2;
    LLVMOrcDisposeLLJIT(jit);
    unsigned major, minor, patch;
    LLVMGetVersion(&major, &minor, &patch);
    printf("%u.%u.%u\\n", major, minor, patch);
    return 0;
}
"""


def verify(info: dict) -> bool:
    """Compile, link and *run* a probe with exactly the recorded link line.

    Finding the files is not proof they link, and linking is not proof the
    result runs: the version it prints is the one the compiler will report.
    Built with the provisioned clang, which is what the bootstrap uses.
    """
    clang = str(Path(info["bin"]) / exe("clang"))
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "probe.c"
        src.write_text(PROBE)
        out = Path(tmp) / exe("probe")
        r = run([clang, "-O1", str(src), "-o", str(out), f"-I{info['include']}",
                 f"@{info['link_rsp']}"])
        if r.returncode != 0:
            log("! The probe failed to link:")
            for line in (r.stdout + r.stderr).strip().splitlines()[:15]:
                log("  " + line)
            return False
        env = os.environ.copy()
        if sys.platform == "win32":
            env["PATH"] = info["bin"] + os.pathsep + env.get("PATH", "")
        r = run([str(out)], env=env)
        if r.returncode != 0 or not r.stdout.startswith(f"{REQUIRED_MAJOR}."):
            log(f"! The probe ran and reported {r.stdout.strip() or r.returncode}")
            return False
    log(f"Verified: a program linked this way runs and reports LLVM {r.stdout.strip()}.")
    return True


# ---------------------------------------------------------------------------

def write_config(info: dict) -> None:
    THIRD_PARTY.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(json.dumps(info, indent=2) + "\n")
    log(f"Wrote {CONFIG_PATH.relative_to(REPO_ROOT)}")


def report(info: dict) -> None:
    log("")
    log(f"LLVM toolchain (pinned to {LLVM_VERSION})")
    log(f"  version {info['version']}")
    log(f"  root    {info['root']}")
    log(f"  include {info['include']}")
    log(f"  link    {info.get('link_rsp') or info['link_library']}")
    log(f"  bin     {info['bin']}")


def adopt(root: Path) -> dict:
    """An install the user names, used as it is: dynamically linked, unpinned.

    Kept for a platform with no release asset and for bisecting against a
    local LLVM build. It is exactly the global dependency the default removes,
    so it is never chosen without being asked for.
    """
    header = root / "include" / "llvm-c" / "Core.h"
    names = (["LLVM-C.lib"] if sys.platform == "win32" else
             ["libLLVM-C.dylib", "libLLVM.dylib"] if sys.platform == "darwin" else
             ["libLLVM-C.so", "libLLVM.so"])
    found = next((n for n in names if (root / "lib" / n).is_file()), None)
    if not header.is_file() or not found:
        raise SystemExit(f"{root} has no include/llvm-c/Core.h or no {' / '.join(names)}")
    version = run([str(root / "bin" / exe("llvm-config")), "--version"]).stdout.strip()
    if version.split(".")[0] != str(REQUIRED_MAJOR):
        raise SystemExit(f"{root} is LLVM {version or '?'}; this Prismio requires {REQUIRED_MAJOR}.x")
    return {
        "root": str(root), "include": str(root / "include"), "lib": str(root / "lib"),
        "bin": str(root / "bin"), "link_library": found, "version": version,
        "required_major": REQUIRED_MAJOR,
    }


def prepared_marker() -> dict | None:
    try:
        return json.loads((LLVM_DIR / PREPARED_MARKER).read_text())
    except (OSError, ValueError):
        return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--force", action="store_true", help="re-download and re-prepare")
    ap.add_argument("--check", action="store_true",
                    help="report the recorded toolchain and exit without changing anything")
    ap.add_argument("--keep-all", action="store_true",
                    help="keep every tool and library in the release")
    ap.add_argument("--llvm-dir", help="adopt this install instead (dynamic, not pinned)")
    args = ap.parse_args()

    if args.check:
        try:
            info = json.loads(CONFIG_PATH.read_text())
        except (OSError, ValueError):
            log("No LLVM toolchain recorded. Run: python tools/setup_llvm.py")
            return 1
        report(info)
        return 0

    if args.llvm_dir:
        info = adopt(Path(args.llvm_dir).resolve())
        log(f"Adopting {info['root']} (LLVM {info['version']}) -- not the pinned toolchain")
        write_config(info)
        report(info)
        return 0

    key = (platform.system(), platform.machine())
    if key not in ASSETS:
        raise SystemExit(f"LLVM {LLVM_VERSION} publishes no archive for {key[0]}/{key[1]}.\n"
                         f"Build LLVM yourself and pass --llvm-dir <path>.")
    name, sha256 = ASSETS[key]
    wanted = {"format": PREPARED_FORMAT, "asset": name, "sha256": sha256,
              "components": COMPONENTS}

    marker = prepared_marker()
    if not args.force and marker and marker.get("prepared") == wanted:
        info = marker["info"]
        log(f"LLVM {LLVM_VERSION} is already prepared at {LLVM_DIR.relative_to(REPO_ROOT)}")
        # Rewritten every run: it is the one part that depends on this
        # machine's state rather than on the archive, and an Xcode update can
        # move the SDK it names.
        if sys.platform == "darwin":
            write_clang_config(LLVM_DIR)
    else:
        archive = DOWNLOADS / name
        download(RELEASE_URL.format(version=LLVM_VERSION, name=name), archive, sha256)
        staging = THIRD_PARTY / ".llvm-staging"
        root = extract(archive, staging)
        if not (root / "include" / "llvm-c" / "Core.h").is_file():
            raise SystemExit(f"{name} has no include/llvm-c/Core.h")
        # Prepared in its final place: the link line records absolute paths.
        if LLVM_DIR.exists():
            shutil.rmtree(LLVM_DIR)
        shutil.move(str(root), str(LLVM_DIR))
        shutil.rmtree(staging)
        info = prepare(LLVM_DIR, args.keep_all)
        (LLVM_DIR / PREPARED_MARKER).write_text(
            json.dumps({"prepared": wanted, "info": info}, indent=2) + "\n")
        # The archive is only worth keeping until the preparation it fed is done.
        archive.unlink()

    ok = verify(info)
    write_config(info)
    report(info)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
