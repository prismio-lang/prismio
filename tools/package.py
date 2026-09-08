#!/usr/bin/env python3
"""Assemble an installed Prismio toolchain.

    python tools/package.py --compiler build/gen2 --out dist/Prismio

Produces:

    <out>/bin/prismio[.exe]
    <out>/lib/runtime/*.bc       linked into user IR before optimisation
    <out>/lib/backend.{a,lib}    linked into the compiler only
    <out>/stdlib/
    <out>/third_party/llvm-paths.json

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


def build_runtime_bitcode(clang: str, source: str, runtime_dir: Path, verify: bool) -> None:
    stem = Path(source).stem + (".verify" if verify else "")
    output = runtime_dir / f"{stem}.bc"
    # Apple/Homebrew clang configuration files may inject stack-probing
    # attributes intended for immediate native code generation. They are not a
    # portable bitcode contract and can make a later LLVM backend reject the
    # merged module, so the packaged IR leaves stack protection to the final
    # whole-program code-generation invocation.
    command = [clang, "-O2", "-fno-stack-check", "-fno-stack-protector",
               "-Wno-deprecated-declarations", "-emit-llvm", "-c"]
    if verify:
        command.append("-DPRISMIO_AIF_VERIFY")
    command.extend([str(REPO / "runtime" / source), "-o", str(output)])
    run(f"bitcode {stem}", command)
    print(f"  runtime/{output.name:<22} {output.stat().st_size:>8} bytes  <- {source}")


def build_plib_ir(clang: str, compiler: Path, source: Path, work: Path,
                  module: str, verify: bool) -> bytes:
    variant = ".verify" if verify else ""
    llvm_ir = work / f"{source.stem}.plib{variant}.ll"
    bitcode = work / f"{source.stem}.plib{variant}.bc"
    env = os.environ.copy()
    env["PRISMIO_LIBRARY_MODULE"] = module
    # package.py must use the compiler named by --compiler. From inside a Prismio
    # checkout an ordinary invocation is otherwise forwarded to the project's
    # active hosted compiler, which can silently package a different generation.
    env["PRISMIO_INTERNAL_HOSTED"] = "1"

    command = [str(compiler), "build", str(source)]
    if verify:
        command.append("--verify")
    command.extend(["-o", str(llvm_ir)])
    result = subprocess.run(command, capture_output=True, text=True,
                            cwd=str(REPO), env=env)
    if result.returncode != 0:
        die(f"could not compile {module}{variant} for PLIB:\n"
            f"{result.stdout}{result.stderr}")
    run(f"bitcode {module}{variant}",
        [clang, "-emit-llvm", "-c", "-x", "ir", str(llvm_ir), "-o", str(bitcode)])
    return bitcode.read_bytes()


def build_plib(clang: str, compiler: Path, source: Path, stdlib: Path, work: Path) -> None:
    module = f"std.{source.stem}"

    module_bytes = module.encode("utf-8")
    # PLIB v2's interface payload deliberately retains generic bodies: those
    # must be instantiated for the importing program's concrete types. Original
    # non-generic definitions are suppressed by codegen and come from the normal
    # or verification code section selected for this build.
    interface = source.read_bytes()
    code = build_plib_ir(clang, compiler, source, work, module, False)
    verify_code = build_plib_ir(clang, compiler, source, work, module, True)
    header = b"PRPLIB2\n" + struct.pack(
        "<IQQQ", len(module_bytes), len(interface), len(code), len(verify_code))
    output = stdlib / f"{source.stem}.plib"
    output.write_bytes(header + module_bytes + interface + code + verify_code)
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
    args = parser.parse_args()

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
    third_party = out / "third_party"
    work = out / ".objs"
    for directory in (bin_dir, lib, runtime_bc, stdlib, third_party, work):
        directory.mkdir(parents=True, exist_ok=True)

    # Repackaging into an existing output must not leave the previous source or
    # monolithic-runtime layout beside the new artifacts.
    for stale in (*stdlib.glob("*.psm"), *stdlib.glob("*.plib"),
                  *runtime_bc.glob("*.bc")):
        stale.unlink()
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

    installed = bin_dir / ("prismio.exe" if WINDOWS else "prismio")
    shutil.copyfile(compiler, installed)
    if not WINDOWS:
        installed.chmod(0o755)

    # Textual LLVM IR must be consumed by a clang from the same LLVM release
    # that produced it. Preserve setup_llvm.py's validated toolchain location
    # beside the packaged compiler; PRISMIO_LLVM_DIR remains the portable
    # override when the package moves to a machine with a different install.
    llvm_paths = REPO / "third_party" / "llvm-paths.json"
    if llvm_paths.is_file():
        shutil.copyfile(llvm_paths, third_party / llvm_paths.name)

    # Recorded beside the libraries so a later build can tell whether they still
    # match the sources on disk.
    value = runtime_hash(compiler)
    (lib / "runtime.hash").write_text(value, encoding="ascii")
    print(f"  {'runtime.hash':<12} {value}")

    # One compiled artifact per importable standard module. The PLIB carries its
    # frontend interface/generic templates and its non-generic LLVM bitcode.
    for module in sorted((REPO / "std").glob("*.psm")):
        build_plib(clang, compiler, module, stdlib, work)

    shutil.rmtree(work)

    print(f"{GREEN}Packaged toolchain at {out}{RESET}")
    for path in sorted(p for p in out.rglob("*") if p.is_file()):
        print(f"  {path.relative_to(out)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
