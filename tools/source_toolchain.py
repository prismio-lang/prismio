"""A compiler that reads this checkout's `std/` as source.

`std.*` resolves from the `stdlib/` beside the running compiler, so a packaged or
project compiler reads its compiled modules, and the IR it writes holds only
declarations for them: their code is merged when a program is linked. The
compiler's own IR -- a generation, the seed, a fixpoint check -- has to hold every
definition it runs, compiled against this tree's `std`. So the compiler is run from
a toolchain of its own whose `stdlib/` is the tree's source.
"""
import os
import shutil
from pathlib import Path

WINDOWS = os.name == "nt"


def copy_library_source(repo: Path, library: Path) -> None:
    """`std/`, its folders kept, as the source library `library`. Replaces a source
    library already there and refuses one that holds compiled modules."""
    if library.is_dir() and any(library.rglob("*.plib")):
        raise SystemExit(f"{library} holds compiled modules (a packaged toolchain); "
                         "build the generation elsewhere")
    shutil.rmtree(library, ignore_errors=True)
    shutil.copytree(repo / "std", library, ignore=lambda root, names: [
        n for n in names if not n.endswith(".psm") and not (Path(root) / n).is_dir()])


def source_toolchain(compiler: Path, repo: Path, work: Path) -> Path:
    """A copy of `compiler` under `work` that resolves `std.*` from `repo`'s source.

    Named so that it is never the project launcher, which would hand the command to
    the project host instead."""
    bin_dir = work / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    copy = bin_dir / ("source-compiler.exe" if WINDOWS else "source-compiler")
    shutil.copy2(compiler, copy)
    if WINDOWS:
        dll = compiler.parent / "LLVM-C.dll"
        if dll.is_file():
            shutil.copy2(dll, bin_dir / dll.name)
    copy_library_source(repo, work / "stdlib")
    return copy
