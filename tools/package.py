#!/usr/bin/env python3
"""Assemble an installed Prismio toolchain.

    python tools/package.py --compiler build/gen2 --out dist/Prismio
    python tools/package.py --compiler build/gen2 --out dist/Prismio \
        --target x86_64-apple-macos --sysroot x86_64-apple-macos=$(xcrun --show-sdk-path)

Produces:

    <out>/bin/prismio[.exe]
    <out>/lib/runtime/*.bc            linked into user IR before optimisation
    <out>/lib/runtime/<triple>/*.bc   the same, for each --target
    <out>/lib/backend.{a,lib}         linked into the compiler only
    <out>/stdlib/*.plib               a code section for the host and each --target
    <out>/bin/LLVM-C.dll              Windows only; elsewhere LLVM is linked in

**No LLVM is needed where the package is installed.** The compiler links the
pinned LLVM statically (tools/setup_llvm.py), optimises and generates code in
process, and hands the finished object to the system's own linker driver. What
the package used to carry instead -- `third_party/llvm-paths.json`, naming the
*build machine's* LLVM for a `clang` it then ran -- is gone.

**A cross build needs both halves for its triple**, and each is looked up by the
triple exactly as the build spells it: `--target x86_64-apple-macos` here and in
`prismio build` must be the same string. A target is packaged by compiling the
runtime for it, which needs that target's C headers -- hence `--sysroot`, which is
where *this* machine keeps them.

The runtime/backend split is enforced here, at the point the artifacts are
built: each runtime translation unit becomes its own LLVM bitcode module, while
the compiler-only C sources form backend.a/backend.lib. A user build merges only
the runtime modules and imported PLIB modules into its LLVM module before the
final optimisation pass; tools/verify_separation.py checks that no compiler
backend symbol reaches a user binary.

One file rather than the .sh/.ps1 pair it replaces: the platform differences are
four lines (archive extension, archiver, executable name, exec bit), and two
implementations of one packaging policy is two things to keep in step.
"""
import argparse
import json
import os
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WINDOWS = os.name == "nt"

GREEN = "" if WINDOWS else "\033[32m"
RED = "" if WINDOWS else "\033[31m"
RESET = "" if WINDOWS else "\033[0m"

# Must match prismio_toolchain_files[] in runtime/build_driver.c.
# tools/check_source_lists.py parses this table and compares it against that one.
RUNTIME_BITCODE = ["lang_runtime.c", "program_support.c"]

LIBRARIES = {
    "backend": [
        "build_driver.c",
        "ir_symbols.c",
        "aif_containers.c",
        "aif_support.c",
        "diagnostics.c",
        "llvm-api-backend.c",
    ],
}


def die(message: str) -> "NoReturn":
    print(f"{RED}FAILED: {message}{RESET}", file=sys.stderr)
    raise SystemExit(1)


def run(label: str, command: list) -> None:
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"{RED}FAILED: {label}{RESET}", file=sys.stderr)
        for line in (result.stdout + result.stderr).splitlines():
            print(f"  {line}", file=sys.stderr)
        raise SystemExit(1)


def find_archiver() -> list:
    """`llvm-lib` writes MSVC-style .lib, `ar` writes GNU-style .a.

    find_toolchain_library() accepts either and prefers the platform-native one,
    so a toolchain packaged on one platform still resolves if it is copied to
    another. llvm-ar is the fallback for a bare LLVM install with no binutils or
    Xcode beside it; both it and ar write the same format.
    """
    if WINDOWS:
        tool = shutil.which("llvm-lib")
        if not tool:
            die("llvm-lib not found on PATH")
        return [tool]
    tool = shutil.which("ar") or shutil.which("llvm-ar")
    if not tool:
        die("neither ar nor llvm-ar found on PATH")
    return [tool, "rcs"]


def build_archive(name: str, sources: list, lib: Path, work: Path, archiver: list) -> None:
    objects = []
    for source in sources:
        obj = work / (Path(source).stem + (".obj" if WINDOWS else ".o"))
        run(f"cc {source}", ["clang", "-Wno-deprecated-declarations",
                             "-c", str(REPO / "runtime" / source), "-o", str(obj)])
        objects.append(str(obj))

    archive = lib / (name + (".lib" if WINDOWS else ".a"))
    if archive.exists():
        archive.unlink()
    if WINDOWS:
        run(f"lib {name}", archiver + [f"/OUT:{archive}"] + objects)
    else:
        run(f"ar {name}", archiver + [str(archive)] + objects)
    print(f"  {archive.name:<12} {archive.stat().st_size:>8} bytes  <- {' + '.join(sources)}")


def llvm_bin() -> str:
    configured = os.environ.get("PRISMIO_LLVM_DIR")
    if configured:
        return str(Path(configured) / "bin")
    try:
        paths = REPO / "third_party" / "llvm-paths.json"
        return json.loads(paths.read_text(encoding="utf-8"))["bin"]
    except (KeyError, ValueError, OSError):
        die("no LLVM toolchain configured (run tools/setup_llvm.py)")


def llvm_clang() -> str:
    """Use the clang from the LLVM distribution the compiler is linked to.

    Bitcode and textual IR are versioned inputs. On macOS, `clang` on PATH is
    commonly Apple Clang while the compiler backend is Homebrew LLVM; mixing
    those makes otherwise valid LLVM attributes fail to parse.
    """
    configured = os.environ.get("PRISMIO_LLVM_DIR")
    if configured:
        candidate = Path(configured) / "bin" / ("clang.exe" if WINDOWS else "clang")
        if candidate.is_file():
            return str(candidate)
    paths = REPO / "third_party" / "llvm-paths.json"
    if paths.is_file():
        try:
            bin_dir = Path(json.loads(paths.read_text(encoding="utf-8"))["bin"])
            candidate = bin_dir / ("clang.exe" if WINDOWS else "clang")
            if candidate.is_file():
                return str(candidate)
        except (KeyError, ValueError, OSError):
            pass
    candidate = shutil.which("clang")
    if not candidate:
        die("clang not found (configure LLVM with tools/setup_llvm.py)")
    return candidate


def target_flags(triple: str, sysroot: str) -> list:
    """The clang flags that name a target, as the build driver spells them."""
    flags = [f"--target={triple}"] if triple else []
    if sysroot:
        flags += ["-isysroot", sysroot]
    return flags


def build_runtime_bitcode(clang: str, source: str, runtime_dir: Path, verify: bool,
                          triple: str = "", sysroot: str = "") -> None:
    stem = Path(source).stem + (".verify" if verify else "")
    output = runtime_dir / f"{stem}.bc"
    # Apple/Homebrew clang configuration files may inject stack-probing
    # attributes intended for immediate native code generation. They are not a
    # portable bitcode contract and can make a later LLVM backend reject the
    # merged module, so the packaged IR leaves stack protection to the final
    # whole-program code-generation invocation.
    command = [clang, *target_flags(triple, sysroot), "-O2", "-fno-stack-check",
               "-fno-stack-protector", "-Wno-deprecated-declarations", "-emit-llvm", "-c"]
    if verify:
        command.append("-DPRISMIO_AIF_VERIFY")
    command.extend([str(REPO / "runtime" / source), "-o", str(output)])
    run(f"bitcode {stem}", command)
    shown = f"runtime/{triple + '/' if triple else ''}{output.name}"
    print(f"  {shown:<30} {output.stat().st_size:>8} bytes  <- {source}")


def build_plib_ir(clang: str, compiler: Path, source: Path, work: Path,
                  module: str, verify: bool, triple: str = "") -> bytes:
    variant = ".verify" if verify else ""
    tag = f".{triple}" if triple else ""
    llvm_ir = work / f"{source.stem}.plib{tag}{variant}.ll"
    bitcode = work / f"{source.stem}.plib{tag}{variant}.bc"
    env = os.environ.copy()
    env["PRISMIO_LIBRARY_MODULE"] = module
    # package.py must use the compiler named by --compiler. From inside a Prismio
    # checkout an ordinary invocation is otherwise forwarded to the project's
    # active hosted compiler, which can silently package a different generation.
    env["PRISMIO_INTERNAL_HOSTED"] = "1"

    command = [str(compiler), "build", str(source)]
    if verify:
        command.append("--verify")
    if triple:
        command.extend(["--target", triple])
    command.extend(["-o", str(llvm_ir)])
    result = subprocess.run(command, capture_output=True, text=True,
                            cwd=str(REPO), env=env)
    if result.returncode != 0:
        die(f"could not compile {module}{variant} for PLIB {triple or 'host'}:\n"
            f"{result.stdout}{result.stderr}")
    run(f"bitcode {module}{variant} {triple or 'host'}",
        [clang, *target_flags(triple, ""), "-emit-llvm", "-c", "-x", "ir",
         str(llvm_ir), "-o", str(bitcode)])
    return bitcode.read_bytes()


def build_plib(clang: str, compiler: Path, source: Path, stdlib: Path, work: Path,
               targets: tuple = ()) -> None:
    """PLIB v3, the layout runtime/build_driver.c reads and, for the host-only
    case, writes byte for byte:

        "PRPLIB3\\n" u32 module_len  u64 interface_len  u32 section_count
        module  interface
        per section: u32 triple_len  u64 code_len  u64 verify_len
                     triple  code  verify

    The host section's triple is empty, which is how a build with no `--target`
    asks for it.
    """
    module = f"std.{source.stem}"

    module_bytes = module.encode("utf-8")
    # The interface payload deliberately retains generic bodies: those must be
    # instantiated for the importing program's concrete types. Original
    # non-generic definitions are suppressed by codegen and come from the normal
    # or verification code of the section for this build's target.
    interface = source.read_bytes()
    sections = b""
    for triple in ["", *targets]:
        code = build_plib_ir(clang, compiler, source, work, module, False, triple)
        verify_code = build_plib_ir(clang, compiler, source, work, module, True, triple)
        name = triple.encode("utf-8")
        sections += struct.pack("<IQQ", len(name), len(code), len(verify_code))
        sections += name + code + verify_code
    header = b"PRPLIB3\n" + struct.pack(
        "<IQI", len(module_bytes), len(interface), 1 + len(targets))
    output = stdlib / f"{source.stem}.plib"
    output.write_bytes(header + module_bytes + interface + sections)
    print(f"  stdlib/{output.name:<22} {output.stat().st_size:>8} bytes")


def runtime_hash(compiler: Path) -> str:
    """Computed by the compiler itself rather than reimplemented here, so the
    packaging step and the freshness check cannot disagree about how the hash is
    derived. Run from the repository, because it hashes the sources on disk."""
    env = os.environ.copy()
    env["PRISMIO_INTERNAL_HOSTED"] = "1"
    result = subprocess.run([str(compiler), "runtime-hash"],
                            capture_output=True, text=True, cwd=str(REPO), env=env)
    value = result.stdout.strip().splitlines()[-1].strip() if result.stdout.strip() else ""
    if result.returncode != 0 or not re.fullmatch(r"[0-9a-f]{16}", value):
        die(f"could not compute runtime hash ({value})")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Assemble an installed Prismio toolchain.")
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--repo")
    parser.add_argument("--target", action="append", default=[],
                        help="also package the runtime and stdlib for this triple")
    parser.add_argument("--sysroot", action="append", default=[], metavar="TRIPLE=PATH",
                        help="where this machine keeps the C headers for a --target")
    args = parser.parse_args()

    sysroots = {}
    for entry in args.sysroot:
        triple, sep, path = entry.partition("=")
        if not sep or triple not in args.target:
            die(f"--sysroot {entry}: expected TRIPLE=PATH naming a --target")
        sysroots[triple] = path
    if len(set(args.target)) != len(args.target):
        die("a --target was given twice")

    global REPO
    if args.repo:
        REPO = Path(args.repo).resolve()

    clang = llvm_clang()

    compiler = Path(args.compiler).resolve()
    if not compiler.is_file():
        die(f"no compiler at {compiler}")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    out = out.resolve()

    bin_dir = out / "bin"
    lib = out / "lib"
    runtime_bc = lib / "runtime"
    stdlib = out / "stdlib"
    work = out / ".objs"
    for directory in (bin_dir, lib, runtime_bc, stdlib, work):
        directory.mkdir(parents=True, exist_ok=True)

    # Repackaging into an existing output must not leave the previous source or
    # monolithic-runtime layout beside the new artifacts.
    for stale in (*stdlib.glob("*.psm"), *stdlib.glob("*.plib"),
                  *runtime_bc.glob("*.bc")):
        stale.unlink()
    for stale in runtime_bc.iterdir():
        if stale.is_dir():
            shutil.rmtree(stale)
    for stale_name in ("runtime.a", "runtime.lib"):
        stale = lib / stale_name
        if stale.exists():
            stale.unlink()

    archiver = find_archiver()
    for name, sources in LIBRARIES.items():
        build_archive(name, sources, lib, work, archiver)
    for source in RUNTIME_BITCODE:
        build_runtime_bitcode(clang, source, runtime_bc, False)
        build_runtime_bitcode(clang, source, runtime_bc, True)
    for triple in args.target:
        (runtime_bc / triple).mkdir()
        for source in RUNTIME_BITCODE:
            for verify in (False, True):
                build_runtime_bitcode(clang, source, runtime_bc / triple, verify,
                                      triple, sysroots.get(triple, ""))

    installed = bin_dir / ("prismio.exe" if WINDOWS else "prismio")
    shutil.copyfile(compiler, installed)
    if not WINDOWS:
        installed.chmod(0o755)

    # An older package wrote the build machine's LLVM location here, and a
    # compiler finding it would still take that machine's clang for granted.
    stale = out / "third_party"
    if stale.is_dir():
        shutil.rmtree(stale)

    # Windows links LLVM-C.lib, an import library, so the DLL travels with the
    # compiler -- the same copy tools/bootstrap.ps1 makes beside every
    # generation.
    if WINDOWS:
        dll = Path(llvm_bin()) / "LLVM-C.dll"
        if not dll.is_file():
            die(f"no LLVM-C.dll at {dll} (run tools/setup_llvm.py)")
        shutil.copyfile(dll, bin_dir / dll.name)

    # Recorded beside the libraries so a later build can tell whether they still
    # match the sources on disk.
    value = runtime_hash(compiler)
    (lib / "runtime.hash").write_text(value, encoding="ascii")
    print(f"  {'runtime.hash':<12} {value}")

    # One compiled artifact per importable standard module. The PLIB carries its
    # frontend interface/generic templates and its non-generic LLVM bitcode, once
    # for the host and once for each --target.
    for module in sorted((REPO / "std").glob("*.psm")):
        build_plib(clang, compiler, module, stdlib, work, args.target)

    shutil.rmtree(work)

    print(f"{GREEN}Packaged toolchain at {out}{RESET}")
    for path in sorted(p for p in out.rglob("*") if p.is_file()):
        print(f"  {path.relative_to(out)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
