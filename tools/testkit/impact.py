"""What a diff touches: for `--changed`, `affected` and the order of the bulk wave.

Used to order and to explain. Skipping is decided by cache keys alone: every `src/` edit
changes the one compiler binary every test runs through, and no map from paths to tests can be
shown complete.
"""
import re
import subprocess

from testkit.api import matches
from testkit.paths import REPO

# A change under one of these can change what any test does.
EVERYTHING = ("src/", "runtime/", "std/", "lsp/", "build.ums", "third_party/",
              "tools/testkit/", "tests/harness/common.py")

# The compiler stage a `src/` directory belongs to -> the suites that watch that stage most
# closely, which therefore report first.
STAGE_SUITES = {
    "lexer": ("diagnostics",), "parse": ("diagnostics",), "sema": ("diagnostics",),
    "symbols": ("diagnostics", "tooling"), "aif": ("aif",), "aifcore": ("aif",),
    "pir": ("pir",), "ir": ("codegen",), "driver": ("targets", "diagnostics"),
    "project": ("ums",), "fmt": ("tooling",), "index": ("tooling",), "common": (), "ast": (),
}


def changed_files() -> list:
    """Paths that differ from HEAD, untracked files included."""
    found = set()
    for command in (["git", "diff", "--name-only", "HEAD"],
                    ["git", "ls-files", "--others", "--exclude-standard"]):
        result = subprocess.run(command, cwd=str(REPO), capture_output=True, text=True)
        if result.returncode == 0:
            found.update(line for line in result.stdout.splitlines() if line)
    return sorted(found)


def source_imports() -> dict:
    """The compiler's module graph, from its own sources: file -> the files it imports."""
    modules = {p.relative_to(REPO / "src").with_suffix("").as_posix().replace("/", "."): p
               for p in (REPO / "src").rglob("*.psm")}
    graph = {}
    for name, path in modules.items():
        text = path.read_text(encoding="utf-8", errors="replace")
        wanted = re.findall(r"^import\s+([\w.]+?)(\.\*)?\s*$", text, re.M)
        for names, parent in re.findall(r"^from\s+([\w.]+)\s+import\s+\{([^}]*)\}", text, re.M):
            wanted += [(f"{names}.{leaf.strip()}", "") for leaf in parent.split(",")]
        for names, parent in re.findall(r"^from\s+([\w.]+)\s+import\s+\{([^}]*)\}", text, re.M):
            wanted.append((names, ""))
        found = set()
        for module, star in wanted:
            if star:
                found |= {m for m in modules if m.startswith(module + ".")}
            elif module in modules:
                found.add(module)
        graph[path.relative_to(REPO).as_posix()] = sorted(
            modules[m].relative_to(REPO).as_posix() for m in found)
    return graph


def stage(path: str) -> str:
    parts = path.split("/")
    return parts[1] if parts[0] == "src" and len(parts) > 2 else ""


def reasons(test, changed: list, recorded_deps) -> list:
    """Why `test` is expected to move under `changed`; empty when nothing it names changed."""
    found = []
    if test.path is not None:
        relative = test.path.relative_to(REPO).as_posix()
        if relative in changed:
            found.append("its file changed")
        for entry in recorded_deps:
            kind, _, target = entry.partition(" ")
            if kind == "source" and target in changed and target != relative:
                found.append(f"imports {target}")
            # A standard module is read compiled, from the toolchain.
            if kind == "plib" and target.startswith("$toolchain/stdlib/"):
                source = "std/" + target[len("$toolchain/stdlib/"):-len(".plib")] + ".psm"
                if source in changed:
                    found.append(f"uses {source}")
    if test.kind == "harness":
        module = f"tests/harness/{test.suite}.py"
        if module in changed:
            found.append(f"{module} changed")
        hit = [c for c in changed if test.reads and matches(c, test.reads)]
        if hit:
            found.append(f"reads {hit[0]}")
    stages = {stage(c) for c in changed} - {""}
    for name in sorted(stages):
        if test.suite in STAGE_SUITES.get(name, ()):
            found.append(f"the `{test.suite}` suite watches the changed `{name}` stage")
    return found


def explain(changed: list, tests: list, deps_of) -> list:
    """The text of `prismio suite affected`."""
    lines = [f"{len(changed)} changed file(s)"]
    graph = source_imports()
    for path in changed:
        if path.startswith("src/"):
            users = sorted({stage(f) or "main" for f, imports in graph.items() if path in imports})
            lines.append(f"  {path}  [stage {stage(path) or 'main'}; imported by "
                         f"{', '.join(users) or 'nothing'}]")
        else:
            lines.append(f"  {path}")
    wide = [c for c in changed if c.startswith(EVERYTHING)]
    if wide:
        lines.append(f"every test can move: {wide[0]}"
                     + (f" and {len(wide) - 1} more" if len(wide) > 1 else "")
                     + " change what all of them run through. Expected first:")
    named = [(t, reasons(t, changed, deps_of(t))) for t in tests]
    named = [(t, why) for t, why in named if why]
    for test, why in named:
        lines.append(f"  {test.id:48s} {'; '.join(why[:3])}")
    lines.append(f"{len(named)} test(s) named by the change, of {len(tests)}")
    return lines
