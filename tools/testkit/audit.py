"""`--audit`: what a harness test actually read, against what it declared.

A declaration that is too small is a cache that serves stale passes, so it is checked rather
than trusted. The plan named `fs_usage` (macOS) and `strace` (Linux); `fs_usage` needs root,
so what is built is a Python-level record, from inside the test's own process:

  * every file and directory the test opens or lists, through `sys.addaudithook`;
  * every command it starts. A compiler command on a source inside the checkout has that
    source's whole import closure added, by compiling it again with `--emit-deps`. A command
    whose reads cannot be seen this way -- a Python script of the checkout, a program the test
    built and runs on files of the checkout -- makes the test `opaque`: it must not be cached.

What this cannot see is a compiler command that reaches the checkout through something other
than a source on its command line (a manifest it discovers from its working directory). Those
tests run the compiler inside the checkout and are marked opaque for it.
"""
import json
import os
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

from testkit.api import matches
from testkit.paths import CACHE_DIR, REPO

# Not inputs of a test: build products, the engine and the test's own code (both in every key),
# and the toolchain under test (in every key as the compiler identity).
IGNORED = (".git/", ".prismio/", "build/", "dist/", "third_party/", "graphify-out/",
           "tests/harness/", "tools/testkit/")


def _inside(path) -> str:
    """A repository-relative spelling of an input, or "" when it is not one."""
    try:
        relative = Path(os.path.abspath(path)).relative_to(REPO).as_posix()
    except (ValueError, TypeError, OSError):
        return ""
    if relative == "." or any((relative + "/").startswith(p) for p in IGNORED):
        return ""
    if "__pycache__" in relative or "/.prismio" in relative or relative.startswith(".prismio-") \
            or "/.prismio-" in relative:
        return ""
    return relative


class Recorder:
    """Lives in the test's process."""

    def __init__(self):
        self.reads = set()
        self.commands = []
        self.local = threading.local()

    def install(self):
        sys.addaudithook(self._hook)

    def _hook(self, event, arguments):
        if event == "open":
            path, mode, flags = (list(arguments) + [None, None])[:3]
            writing = (isinstance(mode, str) and any(c in mode for c in "wxa")) or \
                (mode is None and isinstance(flags, int) and flags & (os.O_WRONLY | os.O_CREAT))
            if not writing and isinstance(path, (str, bytes, os.PathLike)):
                found = _inside(os.fsdecode(path))
                if found and os.path.isfile(os.fsdecode(path)):
                    self.reads.add(found)
        elif event in ("os.listdir", "os.scandir"):
            # The import system lists each `sys.path` directory to find modules, and again
            # whenever it changes: not something the test asked.
            if "importlib" in sys._getframe(1).f_code.co_filename:
                return
            path = arguments[0] if arguments else None
            if isinstance(path, (str, bytes, os.PathLike)):
                found = _inside(os.fsdecode(path))
                if found:
                    self.reads.add(found + "/")
        elif event == "subprocess.Popen":
            executable, command, cwd = (list(arguments) + [None, None, None])[:3]
            if isinstance(command, (list, tuple)):
                self.commands.append({"argv": [os.fsdecode(c) for c in command],
                                      "cwd": os.fsdecode(cwd) if cwd else os.getcwd()})

    def write(self, path):
        # A module already compiled is loaded from `__pycache__` without its source ever being
        # opened, so what was imported from the checkout is asked of the interpreter.
        for module in list(sys.modules.values()):
            found = _inside(getattr(module, "__file__", None) or "")
            if found and found.endswith(".py"):
                self.reads.add(found)
        Path(path).write_text(json.dumps({"reads": sorted(self.reads),
                                          "commands": self.commands}), encoding="utf-8")


class Audit:
    """Lives in the engine: judges each test's record and writes the report."""

    def __init__(self, compiler: Path):
        self.compiler = Path(compiler)
        self.report = {}
        self.lock = threading.Lock()
        self.closures = {}

    def _closure(self, source: Path, cwd: str) -> set:
        """The checkout files a compile of `source` reads."""
        key = str(source)
        with self.lock:
            if key in self.closures:
                return self.closures[key]
        found = set()
        with tempfile.TemporaryDirectory(prefix="prismio-audit-") as temp:
            deps = Path(temp) / "deps"
            subprocess.run([str(self.compiler), "build", str(source), "-o",
                            str(Path(temp) / "audit.ll"), f"--emit-deps={deps}"],
                           cwd=cwd, capture_output=True, timeout=600,
                           env=dict(os.environ, PRISMIO_INTERNAL_HOSTED="1"))
            if deps.is_file():
                for line in deps.read_text(encoding="utf-8").splitlines():
                    kind, _, target = line.partition(" ")
                    if kind in ("source", "dir"):
                        path = target if os.path.isabs(target) else os.path.join(cwd, target)
                        relative = _inside(path)
                        if relative:
                            found.add(relative + ("/" if kind == "dir" else ""))
        with self.lock:
            self.closures[key] = found
        return found

    def judge(self, record: dict):
        reads = set(record["reads"])
        opaque = []
        for command in record["commands"]:
            argv, cwd = command["argv"], command["cwd"]
            program = Path(argv[0]).name
            inside_cwd = _inside(cwd) != "" or Path(cwd).resolve() == REPO
            named = []
            for word in argv[1:]:
                path = Path(word) if os.path.isabs(word) else Path(cwd) / word
                if path.is_file() and _inside(path):
                    named.append(path)
                    reads.add(_inside(path))
                elif os.path.isabs(word) and path.is_dir() and _inside(path):
                    reads.add(_inside(path) + "/")
            compiler = program.startswith(("suite-compiler", "prismio"))
            if compiler:
                for path in named:
                    if path.suffix == ".psm":
                        reads |= self._closure(path, cwd)
                subcommand = argv[1] if len(argv) > 1 else ""
                if inside_cwd and not named and subcommand in ("build", "run", "test", "clean",
                                                               "check"):
                    opaque.append(f"{subcommand} of a project inside the checkout")
            elif program.startswith("python"):
                if any(path.suffix == ".py" for path in named):
                    opaque.append("runs " + ", ".join(_inside(p) for p in named
                                                      if p.suffix == ".py"))
            elif inside_cwd and not program.startswith(("clang", "llvm", "ld", "lld", "opt",
                                                        "nm", "ar", "file", "xcrun", "cc",
                                                        "dsymutil", "otool", "dwarfdump",
                                                        "ps", "git")):
                opaque.append(f"runs {program} inside the checkout")
        return reads, sorted(set(opaque))

    def add(self, test, record: dict) -> str:
        """Record `test`; the failure to report, or "" ."""
        reads, opaque = self.judge(record)
        undeclared = sorted(r for r in reads if test.cache and not matches(r, test.reads))
        with self.lock:
            self.report[test.id] = {"suite": test.suite, "reads": sorted(reads),
                                    "declared": list(test.reads), "undeclared": undeclared,
                                    "opaque": opaque, "cached": test.cache}
        if undeclared:
            return "undeclared reads: " + ", ".join(undeclared[:20])
        if test.cache and opaque:
            return "cached, but its reads cannot be seen: " + "; ".join(opaque[:5])
        return ""

    def write(self) -> Path:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        path = CACHE_DIR / "audit.json"
        path.write_text(json.dumps(self.report, indent=1, sort_keys=True), encoding="utf-8")
        return path
