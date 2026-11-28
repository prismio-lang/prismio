"""The compiler under test: which one, and the copy the engine runs.

**The engine runs a copy, and the copy is the whole point.** A binary named `prismio` forwards
to build.ums's project host, which silently tests another compiler than the one named; the
process running `prismio suite` is holding the compiler it was built as; and the cache and
cold-build tests assert what a build recompiles, which a compiler already running in this
process tree perturbs. What is copied is the *toolchain*, not the binary: a compiler is a
layout (`bin/`, `lib/runtime/*.bc`, `stdlib/`), and a lone copy builds nothing.

The copy lives in a numbered slot under `.prismio/test-cache/`, not in a fresh temporary
directory. Emitted IR names standard-library files by path, so a copy at a new path every run
changes the IR of every program and no result keyed on it could ever match again. A slot is
held by one run at a time; a second concurrent run takes the next one.
"""
import os
import shutil
import sys
from pathlib import Path

from executable import resolve_executable
from testkit.paths import CACHE_DIR, EXE, REPO, shown

# The project host first, because it is the compiler the working tree just built.
DEFAULT_CANDIDATES = (
    REPO / ".prismio" / "build" / "debug" / f"prismio{EXE}",
    REPO / "dist" / "Prismio" / "bin" / f"prismio{EXE}",
)


class ToolchainError(Exception):
    pass


def find_compiler(explicit=None) -> Path:
    if explicit:
        # Resolved, because tests run the compiler from directories of their own, where a
        # relative path names nothing.
        source = resolve_executable(explicit)
        if not source.is_file():
            raise ToolchainError(f"--compiler is not a file: {source}")
        return source
    override = os.environ.get("PRISMIO")
    if override:
        source = Path(override).resolve()
        if not source.is_file():
            raise ToolchainError(f"$PRISMIO is set but not a file: {override}")
        return source
    source = next((c for c in DEFAULT_CANDIDATES if c.is_file()), None)
    if source is None:
        names = ", ".join(shown(c) for c in DEFAULT_CANDIDATES)
        raise ToolchainError(f"no compiler found. Looked for: {names}\n"
                             "Build one with `prismio build`.")
    return source


def _lock(handle) -> bool:
    try:
        if os.name == "nt":
            import msvcrt
            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except OSError:
        return False


class Copy:
    """A private copy of `source`'s toolchain, held until `close`."""

    def __init__(self, source: Path):
        self.source = Path(source).resolve()
        toolchain = self.source.parent.parent
        missing = [d for d in ("lib", "stdlib") if not (toolchain / d).is_dir()]
        if missing:
            raise ToolchainError(
                f"{shown(self.source)} is not in a toolchain layout; no {', '.join(missing)} "
                "beside it.\nBuild one with `prismio build`, or package one with tools/package.py.")
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        slot = 0
        while True:
            self._handle = open(CACHE_DIR / f"toolchain-{slot}.lock", "a+b")
            if _lock(self._handle):
                break
            self._handle.close()
            slot += 1
        self.root = CACHE_DIR / f"toolchain-{slot}"
        shutil.rmtree(self.root, ignore_errors=True)
        # Named `suite-compiler` and not `prismio`, so that it never forwards to the project
        # host. The UMS tests make their own `prismio` launcher when routing is under test.
        self.compiler = self.root / "bin" / f"suite-compiler{EXE}"
        self.compiler.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(self.source, self.compiler)
        self.compiler.chmod(0o755)
        # The language server is launched from beside the compiler (`prismio lsp`).
        server = self.source.parent / f"prismio-lsp{EXE}"
        if server.is_file():
            shutil.copy2(server, self.compiler.parent / server.name)
        for directory in ("lib", "stdlib", "third_party"):
            if (toolchain / directory).is_dir():
                shutil.copytree(toolchain / directory, self.root / directory)

    def close(self):
        shutil.rmtree(self.root, ignore_errors=True)
        self._handle.close()


if __name__ == "__main__":
    sys.exit("import this module; the entry point is tools/testkit")
