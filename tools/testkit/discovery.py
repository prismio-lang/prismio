"""Every test the checkout has: file fixtures by name, harness tests by registration."""
import importlib
import re
import sys

from testkit.api import EXCLUSIVE, REGISTRY
from testkit.model import Test
from testkit.paths import TESTS

HARNESS_SUITES = ("diagnostics", "codegen", "aif", "pir", "std", "tooling", "ums", "targets",
                  "perf", "bootstrap", "engine")

# What makes a program's behaviour a function of more than its source and its compiler: threads,
# the clock, the file system, system calls, the environment, standard input.
MACHINE_STATE = re.compile(
    r"\bspawn\b|\bchannel\s*[<(]|\bChannel\b|std\.task|std\.time|std\.fs|std\.sys|std\.net"
    r"|std\.io\.input|\bcurrentDirectory\b|\benvironment\b|\bgetEnv\b|\brunCommand\b")

HEADER = re.compile(r"^//\s*test:\s*(.*)$", re.M)


def fixture_files():
    return sorted(TESTS.glob("test_*.psm")) + sorted(TESTS.glob("neg_*.psm"))


def markers(text: str, name: str) -> list:
    return [line.split(name, 1)[1].strip() for line in text.splitlines() if name in line]


def expected_traps(text: str) -> list:
    """`// expect-trap: <argument> => <message>` lines, as (argument, message) pairs.

    A program stops at its first run-time error, so a fixture that checks several of them is
    run once per case: with no argument it runs the arms that must succeed, and given a case's
    argument it must stop, with a non-zero exit and the message on stderr.
    """
    wanted = []
    for line in markers(text, "// expect-trap:"):
        argument, _, message = line.partition("=>")
        wanted.append((argument.strip(), message.strip()))
    return wanted


def _header(text: str) -> dict:
    values = {}
    for found in HEADER.finditer(text):
        for pair in found.group(1).split():
            key, _, value = pair.partition("=")
            values[key] = value
    return values


def _tags(stem: str, text: str) -> set:
    tags = {word for word in stem.split("_")[1:] if not word.isdigit()}
    for module in re.findall(r"^(?:import|from)\s+(?:\{[^}]*\}\s+from\s+)?([\w.]+)", text, re.M):
        parts = module.split(".")
        # The directory the module lives in: `std.collections.vec` is "collections".
        tags.add(parts[1] if len(parts) > 1 else parts[0])
    return tags


def fixture(path, order: int) -> Test:
    text = path.read_text(encoding="utf-8", errors="replace")
    reject = path.name.startswith("neg_")
    test = Test(id=path.stem, kind="reject" if reject else "run",
                suite="diagnostics" if reject else "run", path=path, order=order,
                tags=_tags(path.stem, text), timeout=60)
    header = _header(text)
    test.suite = header.get("suite", test.suite)
    test.tags |= {t for t in header.get("tags", "").split(",") if t}
    for resource in filter(None, header.get("resources", "").split(",")):
        name, _, amount = resource.partition(":")
        if name == "threads":
            test.resources["cpu"] = int(amount or 2)
        elif name in ("cpu", "mem"):
            test.resources[name] = int(amount)
        else:
            test.resources[name] = EXCLUSIVE
    test.timeout = int(header.get("timeout", test.timeout))
    if header.get("cache") == "never" or (not reject and MACHINE_STATE.search(text)):
        test.cache = False
    return test


def harness_tests() -> list:
    """Import every suite module; each `@harness_test` registers itself."""
    if str(TESTS) not in sys.path:
        sys.path.insert(0, str(TESTS))
    for suite in HARNESS_SUITES:
        importlib.import_module(f"harness.{suite}")
    tests = []
    for order, (name, entry) in enumerate(REGISTRY.items()):
        tests.append(Test(id=name, kind="harness", suite=entry["suite"],
                          tags=set(entry["tags"]), resources=entry["resources"],
                          cache=entry["cache"], reads=entry["reads"], timeout=entry["timeout"],
                          order=order))
    return tests


def discover() -> list:
    tests = [fixture(path, order) for order, path in enumerate(fixture_files())]
    harness = harness_tests()
    seen = {t.id for t in tests}
    for test in harness:
        if test.id in seen:
            raise ValueError(f"a harness test and a fixture are both named {test.id!r}")
    return tests + harness
