"""The three cache keys (the design record, sections 3 and 5; see tools/testkit/__init__.py).

    K1  the inputs     the source closure, the compiler and its library, the machine
    K2  the artifact   the emitted IR, the libraries merged into it, the backend
    K3  the link       the compiler's own hash of everything it handed the linker

A key says "nothing this result depends on has changed", so whatever cannot be established is
put into the key coarsely or disables the level -- never left out.
"""
import hashlib
import json
import os
import platform
import shutil
import subprocess
import threading
from pathlib import Path

from testkit.api import matches
from testkit.paths import REPO

# The compiler's backend, which K2 cannot see in the IR it hashes: the C that merges, optimises
# and links, and the Prismio that tells it how. Hashed from this checkout.
BACKEND_FILES = (
    "runtime/**", "src/driver/**", "src/main.psm", "src/ir/bridge.psm",
    "src/common/native.psm", "src/common/target.psm", "third_party/llvm-paths.json",
)

# The engine's own files that decide what "passed" means for a kind of test.
ENGINE_FILES = {
    "fixture": ("tools/testkit/fixtures.py", "tools/testkit/discovery.py",
                "tools/testkit/cache.py"),
    "harness": ("tools/testkit/harness.py", "tools/testkit/child.py", "tools/testkit/cache.py",
                "tests/harness/common.py"),
}

# Variables that change what a build or a run does.
ENVIRONMENT = ("SDKROOT", "DEVELOPER_DIR", "MACOSX_DEPLOYMENT_TARGET", "CC", "LIB", "INCLUDE")


def digest(*parts) -> str:
    hasher = hashlib.sha256()
    for part in parts:
        data = part if isinstance(part, bytes) else json.dumps(part, sort_keys=True).encode()
        hasher.update(str(len(data)).encode() + b":" + data)
    return hasher.hexdigest()


class Files:
    """Content hashes, remembered for as long as a file's size and modification time hold."""

    def __init__(self):
        self.seen = {}
        self.lock = threading.Lock()

    def hash(self, path) -> str:
        try:
            status = os.stat(path)
        except OSError:
            return "missing"
        identity = (str(path), status.st_size, status.st_mtime_ns)
        with self.lock:
            found = self.seen.get(identity)
        if found:
            return found
        hasher = hashlib.sha256()
        try:
            with open(path, "rb") as handle:
                for block in iter(lambda: handle.read(1 << 20), b""):
                    hasher.update(block)
        except OSError:
            return "missing"
        found = hasher.hexdigest()
        with self.lock:
            self.seen[identity] = found
        return found

    def tree(self, root, patterns=("**",)) -> list:
        """[(path relative to `root`, hash)] of every file a pattern covers, sorted."""
        root = Path(root)
        found = []
        for base, names in _walk(root, patterns):
            for name in names:
                path = Path(base) / name
                relative = path.relative_to(root).as_posix()
                if matches(relative, patterns):
                    found.append((relative, self.hash(path)))
        return sorted(found)


SKIPPED_DIRECTORIES = {".git", "__pycache__", "node_modules", ".prismio", "build", "dist",
                       "graphify-out", "third_party"}


def _walk(root: Path, patterns):
    # Walk only under each pattern's fixed prefix.
    starts = set()
    for pattern in patterns:
        fixed = []
        for part in pattern.split("/"):
            if any(c in part for c in "*?["):
                break
            fixed.append(part)
        starts.add(root.joinpath(*fixed))
    visited = set()
    for start in starts:
        if start.is_file():
            if str(start) not in visited:
                visited.add(str(start))
                yield start.parent, [start.name]
            continue
        for base, directories, names in os.walk(start):
            directories[:] = [d for d in directories if d not in SKIPPED_DIRECTORIES]
            fresh = [n for n in names if os.path.join(base, n) not in visited
                     and not n.startswith(".prismio-")]
            visited.update(os.path.join(base, n) for n in fresh)
            yield base, fresh


def _tool_output(command) -> str:
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout + result.stderr


def machine_identity(files: Files) -> list:
    """The operating system, the linker and the environment a build and a run see."""
    environment = {name: os.environ.get(name, "") for name in ENVIRONMENT}
    environment.update({name: value for name, value in os.environ.items()
                        if name.startswith("PRISMIO") and not name.startswith("PRISMIO_TEST_")
                        and name != "PRISMIO"})
    linker = []
    driver = os.environ.get("PRISMIO_CC") or shutil.which("cc") or shutil.which("clang") or ""
    if driver:
        linker.append(_tool_output([driver, "--version"]))
    if shutil.which("xcrun"):
        sdk = _tool_output(["xcrun", "--show-sdk-path"]).strip()
        linker.append(sdk)
        linker.append(files.hash(Path(sdk) / "SDKSettings.json") if sdk else "")
    return [platform.platform(), platform.machine(), environment, linker]


def library_identity(files: Files, library) -> str:
    """The compiled libraries a link merges. Not the toolchain's `.stamp` files: they record
    which compiler built each entry, so they change with every rebuild of the compiler, and K2
    would never match across one."""
    return digest([entry for entry in files.tree(library) if not entry[0].endswith(".stamp")])


class Fingerprint:
    """What every key of one run shares: the compiler under test and the machine."""

    def __init__(self, copy, root: Path = REPO):
        self.files = Files()
        self.root = Path(root)
        self.copy = copy
        self.machine = machine_identity(self.files)
        # The toolchain copy, by content and by name inside it -- not by where it is.
        self.toolchain = digest([item for part in ("bin", "lib", "stdlib")
                                 for item in ((part,), *self.files.tree(copy.root / part))])
        self.libraries = library_identity(self.files, copy.root / "lib")
        version = _tool_output([str(copy.compiler), "--version"])
        self.version = " ".join(line.strip() for line in version.splitlines() if line.strip())
        self.llvm = next((line for line in version.splitlines() if line.startswith("llvm")), "")
        self.runtime_hash = _tool_output([str(copy.compiler), "runtime-hash"]).strip()
        self.engine = {kind: digest([self.files.hash(self.root / f) for f in names])
                       for kind, names in ENGINE_FILES.items()}
        self.backend, self.backend_refusal = self._backend(copy.source)

    def _backend(self, source: Path):
        """The backend identity, or why K2 cannot be trusted for this compiler.

        The identity is read from the checkout, so it only describes a compiler that was built
        from it: one inside the checkout and newer than every file the identity covers.
        """
        try:
            source.resolve().relative_to(self.root.resolve())
        except ValueError:
            return None, "the compiler was not built in this checkout"
        listed = self.files.tree(self.root, BACKEND_FILES)
        listed.append(("third_party/llvm-paths.json",
                       self.files.hash(self.root / "third_party" / "llvm-paths.json")))
        built = source.stat().st_mtime_ns
        for relative, _ in listed:
            path = self.root / relative
            if path.is_file() and path.stat().st_mtime_ns > built:
                return None, f"{relative} is newer than the compiler; rebuild it"
        return digest(listed), ""

    # ----- dependencies --------------------------------------------------------------

    def depfile(self, path) -> list:
        """The lines `--emit-deps` wrote, deduplicated. Empty if there is no file."""
        try:
            lines = Path(path).read_text(encoding="utf-8").splitlines()
        except OSError:
            return []
        seen = []
        for line in lines:
            kind, _, target = line.partition(" ")
            if not target:
                continue
            absolute = Path(target) if os.path.isabs(target) else self.root / target
            entry = f"{kind} {self._relative(absolute)}"
            if entry not in seen:
                seen.append(entry)
        return sorted(seen)

    def _relative(self, path: Path) -> str:
        """A dependency spelled so that it means the same in any run: `$toolchain/...` for the
        copy, repository-relative inside the checkout, absolute elsewhere."""
        for prefix, root in (("$toolchain/", self.copy.root), ("", self.root)):
            try:
                return prefix + Path(os.path.normpath(path)).relative_to(root).as_posix()
            except ValueError:
                continue
        return str(path)

    def _resolve(self, spelled: str) -> Path:
        if spelled.startswith("$toolchain/"):
            return self.copy.root / spelled[len("$toolchain/"):]
        return self.root / spelled

    def dependency_state(self, deps) -> list:
        """Each dependency with the answer it gives now."""
        state = []
        for entry in deps:
            kind, _, spelled = entry.partition(" ")
            path = self._resolve(spelled)
            if kind in ("source", "plib"):
                value = self.files.hash(path)
            elif kind == "dir":
                try:
                    value = sorted(n for n in os.listdir(path) if n.endswith((".psm", ".plib")))
                except OSError:
                    value = None
            else:
                value = path.exists()
            state.append([entry, value])
        return state

    # ----- keys ----------------------------------------------------------------------

    def k1(self, deps, spec) -> str:
        return digest("K1", self.engine["fixture"], self.toolchain, self.machine, spec,
                      self.dependency_state(deps))

    def k2(self, ir_path, deps, spec):
        """None when this compiler's backend cannot be identified."""
        if self.backend is None:
            return None
        libraries = [item for item in self.dependency_state(deps) if item[0].startswith("plib ")]
        return digest("K2", self.engine["fixture"], self.files.hash(ir_path), libraries,
                      self.libraries, self.runtime_hash, self.backend, self.llvm, self.machine,
                      spec)

    def k3(self, link_key: str, spec) -> str:
        return digest("K3", self.engine["fixture"], link_key, self.machine, spec)

    def harness(self, test) -> str:
        """K1 of a harness test: the compiler, the machine, and the files it declares."""
        module = self.root / "tests" / "harness" / f"{test.suite}.py"
        files = [p for p in test.reads if not p.endswith("/")]
        listings = self.dependency_state([f"dir {p[:-1]}" for p in test.reads if p.endswith("/")])
        return digest("H1", self.engine["harness"], self.files.hash(module), self.toolchain,
                      self.llvm, self.machine, test.id,
                      self.files.tree(self.root, files) if files else [], listings)
