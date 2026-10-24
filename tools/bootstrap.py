#!/usr/bin/env python3
"""Build a prismio compiler generation on macOS, Linux or Windows.

    python3 tools/bootstrap.py --seed --out build/gen0            # first ever build on a host
    python3 tools/bootstrap.py --compiler build/gen0 --out build/gen1
    python3 tools/bootstrap.py --compiler build/gen1 --out build/gen2 --promote

The one script for every platform (it replaces the bootstrap.sh / bootstrap.ps1 pair).
It does the link by hand, so every runtime and backend source is compiled fresh from the
working tree: a normal user build consumes installed bitcode and deliberately cannot build
a compiler backend, so bootstrap remains the explicit source-based path. It is Python
rather than a Prismio command because it is the step that must not go through any
existing binary's idea of the toolchain.

--seed starts from the seed: LLVM IR for the compiler, committed as bootstrap/seed.ll. A
host with no prismio binary cannot compile src/main.psm to get one, and that is the only
way out of the cycle. Bare --seed uses bootstrap/seed.ll; pass a path to use a different
one. The seed carries no target triple, so clang targets whatever host it runs on.

Requires the LLVM that `python3 tools/setup_llvm.py` provisions into third_party/llvm: its
clang is the one new enough to read the seed's LLVM IR, and its static archives are what
the compiler links. Nothing is taken from PATH unless PRISMIO_LLVM_DIR names an install
explicitly.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

from executable import resolve_executable

REPO = Path(__file__).resolve().parent.parent
# What the caller's shell said, before resolve_llvm exports the pinned LLVM's own floor (14.0) for
# the compiles and link of the compiler itself. A promoted generation's `build` must not see that
# one: it would build the project's runtime for macOS 14 instead of the floor programs target.
CALLER_DEPLOYMENT_TARGET = os.environ.get("MACOSX_DEPLOYMENT_TARGET")
WINDOWS = os.name == "nt"
EXE = ".exe" if WINDOWS else ""
OBJ = ".obj" if WINDOWS else ".o"

GREEN = "" if WINDOWS else "\033[32m"
RED = "" if WINDOWS else "\033[31m"
GREY = "" if WINDOWS else "\033[90m"
RESET = "" if WINDOWS else "\033[0m"

# Must match the native sources of the prismio target in build.ums; checked by
# tools/check_source_lists.py.
RUNTIME_SOURCES = [
    "lang_runtime.c", "program_support.c", "build_driver.c",
    "llvm-api-backend.c", "llvm_bridge.cpp",
]

COMPILE_FLAGS = "-O2 -DPRISMIO_LLVM_REAL_HEADERS -DPRISMIO_BOOTSTRAP_COMPAT"


def step(label: str) -> None:
    print(f"{GREY}[{label}]{RESET}", flush=True)


def die(message: str, detail: str = "") -> "None":
    print(f"{RED}FAILED: {message}{RESET}", file=sys.stderr)
    if detail:
        for line in detail.rstrip().splitlines():
            print(f"  {line}", file=sys.stderr)
    sys.exit(1)


def run(label: str, command: list) -> None:
    """Runs one tool; its exit code decides, and its output is shown only on failure
    (clang writes warnings on purpose: the module's target triple is overridden)."""
    result = subprocess.run([str(c) for c in command], capture_output=True, text=True,
                            encoding="utf-8", errors="replace")
    if result.returncode != 0:
        die(label, (result.stdout or "") + (result.stderr or ""))


# ---------------------------------------------------------------------------
# Toolchain object cache
#
# Recompiling the runtime and backend sources that did not change is about half of a
# self-build, and the loop it sits in is the one this project runs most. The build
# driver caches the same objects for user builds; this is the same idea for the path
# that builds the compiler, with the same PRISMIO_OBJ_CACHE knobs.
#
# **The key is content, and it has to be, because this is the one path whose contract
# is that an edit to runtime/*.c reaches the next generation.** A stale entry here
# poisons a compiler generation rather than a test binary. So:
#
#   * every runtime/*.h goes into every entry -- a header changes what a .c compiles to
#     without changing a byte of it. Over-invalidating all entries for a header edit is
#     the safe side to be wrong on;
#   * the compile flags go in, including the LLVM include path, because
#     -DPRISMIO_LLVM_REAL_HEADERS makes the backend's object depend on which LLVM's
#     headers it saw.
#
# Not covered, exactly as in build_driver.c: an in-place upgrade of clang.
# PRISMIO_OBJ_CACHE=0 is the escape.
# ---------------------------------------------------------------------------

class Llvm:
    def __init__(self, include, lib, bin_dir, rsp, link_name):
        self.include, self.lib, self.bin = include, lib, bin_dir
        self.rsp, self.link_name = rsp, link_name
        self.clang = Path(bin_dir) / f"clang{EXE}"


def resolve_llvm(repo: Path) -> Llvm:
    """The LLVM this build compiles and links against.

    The backend is built on the LLVM C API, so this needs LLVM's headers and its C API
    link library. tools/setup_llvm.py finds or fetches one and records it in
    third_party/llvm-paths.json; PRISMIO_LLVM_DIR overrides that. The link library's
    *name* is not a constant: Homebrew and the Windows package ship libLLVM-C.dylib /
    LLVM-C.lib while apt.llvm.org's llvm-N-dev ships libLLVM.so and no LLVM-C at all, so
    setup_llvm.py records which one it validated and this reads it. `rsp` is the pinned
    toolchain's response file: the static archives and the system libraries they need, so
    the compiler loads no LLVM at run time. An install named by PRISMIO_LLVM_DIR has none
    and is linked as a shared library."""
    root = os.environ.get("PRISMIO_LLVM_DIR")
    if root:
        return Llvm(Path(root) / "include", Path(root) / "lib", Path(root) / "bin", "", "LLVM-C")
    config = repo / "third_party" / "llvm-paths.json"
    if not config.is_file():
        die("no LLVM toolchain configured -- run: python3 tools/setup_llvm.py")
    paths = json.loads(config.read_text(encoding="utf-8"))
    # The macOS the pinned LLVM was built for, which every object linked with it is
    # compiled for too -- clang reads the variable for compiles and the link alike. Left
    # to clang, the version is this machine's SDK, and the compiler would not start on an
    # older macOS.
    if paths.get("macos_min"):
        os.environ["MACOSX_DEPLOYMENT_TARGET"] = paths["macos_min"]
    # libLLVM-C.dylib -> LLVM-C, libLLVM.so -> LLVM, LLVM-C.lib -> LLVM-C: drop a leading
    # `lib`, then everything from the first dot.
    name = re.sub(r"^lib", "", paths.get("link_library") or "libLLVM-C").split(".")[0]
    return Llvm(paths["include"], paths["lib"], paths["bin"], paths.get("link_rsp", ""), name)


def cache_dir() -> Path:
    override = os.environ.get("PRISMIO_OBJ_CACHE_DIR")
    return Path(override) if override else Path(tempfile.gettempdir()) / "prismio-objcache"


_header_key = None


def cache_entry(repo: Path, source: str, include) -> "Path | None":
    """The cache path for one source, or None when the cache is off or cannot be keyed."""
    global _header_key
    if os.environ.get("PRISMIO_OBJ_CACHE") == "0":
        return None
    path = repo / "runtime" / source
    if not path.is_file():
        return None
    if _header_key is None:  # hashed once for the whole run, not once per source
        digest = hashlib.sha256()
        for header in sorted((repo / "runtime").glob("*.h"), key=lambda p: p.name):
            digest.update(f"|{header.name}|".encode())
            digest.update(header.read_bytes())
        _header_key = digest.hexdigest()
    digest = hashlib.sha256()
    digest.update(f"bootstrap|{source}|{COMPILE_FLAGS} -I{include}|{_header_key}|"
                  f"{os.environ.get('MACOSX_DEPLOYMENT_TARGET', '')}|".encode())
    digest.update(path.read_bytes())
    try:
        cache_dir().mkdir(parents=True, exist_ok=True)
    except OSError:
        return None
    return cache_dir() / f"bootstrap-{Path(source).stem}-{digest.hexdigest()}{OBJ}"


def install_in_cache(obj: Path, entry: Path) -> bool:
    """Installed by a rename inside the cache directory, so it is atomic and two
    concurrent bootstraps cannot link a half-written object. A failed install is not a
    failed build -- link the local copy and pay again."""
    tmp = entry.parent / f".tmp-{os.getpid()}-{entry.name}"
    try:
        shutil.copyfile(obj, tmp)
        os.replace(tmp, entry)
        return True
    except OSError:
        try:
            tmp.unlink()
        except OSError:
            pass
        return False


def symbols_unique(ll: Path) -> int:
    """Duplicate symbols mean import resolution merged a module more than once. clang
    would reject them anyway, but name them explicitly so the cause is obvious."""
    pattern = re.compile(r"^(?:define|declare)[^@]*@([A-Za-z0-9_.$]+)\(")
    counts = Counter()
    with open(ll, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            found = pattern.match(line)
            if found:
                counts[found.group(1)] += 1
    dupes = [(name, n) for name, n in counts.items() if n > 1]
    if dupes:
        print(f"{RED}DUPLICATE SYMBOLS IN IR ({len(dupes)}):{RESET}", file=sys.stderr)
        for name, n in sorted(dupes, key=lambda d: -d[1])[:20]:
            print(f"  {name} x{n}", file=sys.stderr)
        sys.exit(1)
    return len(counts)


def windows_exports(llvm: Llvm, objs: list) -> list:
    """The export table is this platform's `-rdynamic`, and `run --jit` is what needs it.
    ORC resolves a jitted module's externals through the running process, and a COFF
    executable exports nothing unless it is linked with an export table. **Read out of the
    objects rather than written down**: a list kept here would be a second copy of the
    runtime's surface. Only the two files that go into every compiled program are asked
    (the C_CODE_STYLE.md split), because a jitted user program cannot call the backend."""
    nm = Path(llvm.bin) / "llvm-nm.exe"
    runtime_objs = [o for o in objs if re.search(r"(lang_runtime|program_support)", Path(o).name)]
    if not nm.is_file() or not runtime_objs:
        # Not fatal: everything except `run --jit` works without it.
        print("[exports] llvm-nm not found -- run --jit will not resolve the runtime")
        return []
    listed = subprocess.run([str(nm), "--defined-only", "--extern-only", "--format=posix",
                             *[str(o) for o in runtime_objs]],
                            capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    # Matched on `<name> <type> ...` rather than split on whitespace: with more than one
    # object nm interleaves `<file>:` header lines. Only defined text and data types are
    # taken; a weak or comdat symbol is skipped rather than exported.
    names = sorted({m.group(1) for line in listed.splitlines()
                    if (m := re.match(r"^(\S+)\s+[TDBR]\s", line)) and not re.match(r"^[.$]", m.group(1))})
    print(f"{GREY}[exports] {len(names)} runtime symbol(s) into the export table{RESET}")
    return [f"-Wl,/EXPORT:{n}" for n in names]


def main() -> None:
    parser = argparse.ArgumentParser(description="Build a prismio compiler generation.")
    parser.add_argument("--compiler", help="a working prismio to emit the compiler's IR with")
    parser.add_argument("--seed", nargs="?", const="", default=None, metavar="IR",
                        help="start from the seed (default bootstrap/seed.ll) instead")
    parser.add_argument("--out", help="where to write the compiler")
    parser.add_argument("--repo", default=str(REPO))
    parser.add_argument("--keep", action="store_true", help="keep the intermediate files")
    parser.add_argument("--promote", action="store_true",
                        help="make this generation the checkout's local toolchain: run its own "
                             "`build --release` (installs .prismio/build/release/prismio, the project "
                             "host) and `build` (the debug compiler) from the repository root")
    parser.add_argument("--print-cache-key", metavar="SOURCE",
                        help="print the object cache's key for one runtime source, and nothing else "
                             "(lets a test assert the key moves when the inputs do, without a bootstrap)")
    args = parser.parse_args()
    repo = Path(args.repo).resolve()

    if args.print_cache_key:
        entry = cache_entry(repo, args.print_cache_key, resolve_llvm(repo).include)
        if entry is None:
            print("no key: the cache is disabled or the source does not exist", file=sys.stderr)
            sys.exit(1)
        print(entry.name)
        return
    if not args.out:
        parser.error("--out is required")
    if not args.compiler and args.seed is None:
        parser.error("one of --compiler or --seed is required")

    # A manifest command spells a generation once for every platform, without `.exe`.
    out = Path(args.out)
    if WINDOWS and out.suffix.lower() != ".exe":
        out = out.with_name(out.name + ".exe")
    out = out.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    work = out.parent / f".bootstrap-{out.name}"
    work.mkdir(parents=True, exist_ok=True)
    try:
        build(repo, args, out, work)
    finally:
        if not args.keep:
            shutil.rmtree(work, ignore_errors=True)
    if args.promote:
        promote(repo, out)


def promote(repo: Path, generation: Path) -> None:
    """Installs `generation` as this checkout's local toolchain.

    **By running its own `build --release`, not by copying the binary.** The project host
    is trusted by a stamp beside it (prismio.trusted) and is paired with the `lib/` and
    `stdlib/` built next to it, so a copied executable is refused as untrusted; asking the
    generation to build the project makes it write all of them and promote itself. `build`
    after it refreshes the debug compiler (`.prismio/build/debug/prismio`) that
    `prismio build`, `suite` and `verify` run. Needs the tree to be one this generation can
    build, which a generation bootstrapped from it is."""
    env = dict(os.environ)
    env.pop("MACOSX_DEPLOYMENT_TARGET", None)
    if CALLER_DEPLOYMENT_TARGET is not None:
        env["MACOSX_DEPLOYMENT_TARGET"] = CALLER_DEPLOYMENT_TARGET
    for what, argv in (("build --release", ["build", "--release"]), ("build", ["build"])):
        step(f"promote: {what}")
        result = subprocess.run([str(generation), *argv], cwd=repo, env=env, capture_output=True,
                                text=True, encoding="utf-8", errors="replace")
        if result.returncode != 0:
            die(f"promote: {what}", (result.stdout or "") + (result.stderr or ""))
    host = repo / ".prismio" / "build" / "release" / f"prismio{EXE}"
    print(f"{GREEN}Promoted {generation.name} to {host}{RESET}")


def build(repo: Path, args, out: Path, work: Path) -> None:
    ll = work / "compiler.ll"

    # 1. Obtain IR for the compiler, either from the seed or from a working frontend.
    if args.compiler:
        step("psm -> ll")
        run("psm -> ll", [resolve_executable(args.compiler), "build", repo / "src" / "main.psm", "-o", ll])
        if not ll.is_file():
            die("no IR produced")
    else:
        step("seed -> ll")
        seed = Path(args.seed) if args.seed else repo / "bootstrap" / "seed.ll"
        if not seed.is_file():
            die(f"seed not found: {seed}")
        shutil.copyfile(seed, ll)
    print(f"{GREEN}IR: {symbols_unique(ll)} symbols, all unique{RESET}")

    # 2. Backend: IR -> object. No target triple in the seed means the host default.
    #
    # clang rather than llc, and -O2, for the same reason compile_ir_to_object uses them:
    # llc runs the codegen pipeline but not the IR pipeline, so a compiler built with it
    # has every local in a stack slot. Worth 1.4x-3.0x on user programs, and the compiler
    # is a user program too.
    step("ll -> obj")
    llvm = resolve_llvm(repo)
    if not llvm.clang.is_file():
        die(f"no clang at {llvm.clang} -- run: python3 tools/setup_llvm.py")
    program_obj = work / f"program{OBJ}"
    run("ll -> obj", [llvm.clang, "-O2", "-c", ll, "-o", program_obj])

    # 3. Runtime and backend C sources, compiled fresh from the working tree -- except
    # where the cache already holds the object this source and these headers compile to.
    # The misses are compiled in parallel: they are independent translation units writing
    # distinct objects, so the only thing this changes is how long it takes. The cache key
    # is computed before the compile and carried, not recomputed after: a source edited
    # *during* the build would otherwise key the object compiled from the old text under
    # the new text's name -- a poisoned entry every later build would hit.
    objs = {c: None for c in RUNTIME_SOURCES}
    misses = []
    for c in RUNTIME_SOURCES:
        entry = cache_entry(repo, c, llvm.include)
        if entry is not None and entry.is_file():
            step(f"cc {c} (cached)")
            objs[c] = entry
        else:
            step(f"cc {c}")
            misses.append((c, entry, work / f"{Path(c).stem}{OBJ}"))

    def compile_one(job):
        c, _, obj = job
        run(f"cc {c}", [llvm.clang, *COMPILE_FLAGS.split(), "-Wno-deprecated-declarations",
                        f"-I{llvm.include}", f"-I{repo / 'runtime'}",
                        "-c", repo / "runtime" / c, "-o", obj])

    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
        list(pool.map(compile_one, misses))  # a failed compile raises SystemExit via die()

    # Installed after every job finished: one that has not has not written its object yet,
    # and copying it would cache a truncated file.
    for c, entry, obj in misses:
        objs[c] = entry if entry is not None and install_in_cache(obj, entry) else obj

    # 4. Link, including LLVM's C API.
    step("link")
    ordered = [program_obj] + [objs[c] for c in RUNTIME_SOURCES]
    llvm_args = [f"@{llvm.rsp}"] if llvm.rsp else [f"-L{llvm.lib}", f"-l{llvm.link_name}"]
    if WINDOWS:
        # 16 MiB of stack, not Windows' default 1: the compiler recurses deeply, and a
        # seed-built one overflowed (0xC00000FD) on its first real input, silently. The
        # same value link_program_msvc passes for everything `prismio build` links.
        extra = windows_exports(llvm, ordered) + ["-Wl,/STACK:16777216"]
    else:
        # -rdynamic puts this executable's own symbols in its dynamic symbol table:
        # `--jit` resolves the jitted module's externals with a `dlsym` on the running
        # process, so the runtime symbols the module calls have to be findable there. On
        # Mach-O they are by default; on ELF they are not.
        extra = ["-rdynamic"]
    run("link", [llvm.clang, *ordered, "-o", out, *extra, *llvm_args] if not WINDOWS
        else [llvm.clang, *ordered, "-o", out, *llvm_args, *extra])

    # On Windows the compiler needs LLVM-C.dll beside it at runtime; copying beats asking
    # every user to put the LLVM bin directory on PATH.
    dll = Path(llvm.bin) / "LLVM-C.dll"
    if WINDOWS and dll.is_file():
        shutil.copyfile(dll, out.parent / dll.name)

    print(f"{GREEN}Built {out} ({out.stat().st_size} bytes){RESET}")


if __name__ == "__main__":
    main()
