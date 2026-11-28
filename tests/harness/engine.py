"""The test engine's own tests: each cache key must tell two different inputs apart
(the design record, section 5, rule 5; see tools/testkit/__init__.py). A key that cannot has proved nothing."""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

from harness.common import *


class _Toolchain:
    """The compiler under test in the shape the engine's fingerprint expects."""

    def __init__(self, compiler: Path):
        self.compiler = Path(compiler)
        self.source = self.compiler
        self.root = self.compiler.parent.parent


@harness_test("engine_keys", suite="engine", resources={"cpu": 2})
def run_engine_keys_test():
    """K1, K2 and K3 over a canary program: unchanged inputs give the same key, and an edit
    to anything a key covers gives another."""
    print(f"\n{BLUE}--- Running engine_keys ---{RESET}")
    from testkit.cache import Fingerprint, library_identity

    problems = []

    def expect(condition, message):
        if not condition:
            problems.append(message)

    fingerprint = Fingerprint(_Toolchain(PRISMIO_EXE))
    work = scratch() / "canary"
    work.mkdir()
    program = work / "canary.psm"
    module = work / "canary_lib.psm"
    text = ("import std.io\nimport canary_lib\n\n"
            "fn main() -> Int {\n    println(canary(20) + 1)\n    return 0\n}\n")
    library = "public fn canary(a: Int) -> Int {\n    return a + a\n}\n"
    program.write_text(text, encoding="utf-8")
    module.write_text(library, encoding="utf-8")
    spec = ["canary"]

    def build(output, *flags):
        depfile = work / "deps"
        found = run_command([str(PRISMIO_EXE), "build", str(program), "-o", str(work / output),
                             f"--emit-deps={depfile}", *flags])
        if found.returncode != 0:
            raise RuntimeError(found.stdout + found.stderr)
        return fingerprint.depfile(depfile)

    deps = build("a.ll")
    expect(any(d.startswith("source ") and d.endswith("canary_lib.psm") for d in deps),
           f"--emit-deps does not name the imported module: {deps}")
    expect(any(d.startswith("plib $toolchain/stdlib/") for d in deps),
           f"--emit-deps does not name a compiled library module: {deps}")
    expect(any(d.startswith("absent ") for d in deps),
           f"--emit-deps does not name a file that was looked for and not found: {deps}")

    # ----- K1
    base = fingerprint.k1(deps, spec)
    expect(fingerprint.k1(deps, spec) == base, "K1 differs on unchanged inputs")
    program.write_text(text + "// edited\n", encoding="utf-8")
    expect(fingerprint.k1(deps, spec) != base, "K1 missed an edit to the test file")
    program.write_text(text, encoding="utf-8")
    module.write_text(library + "// edited\n", encoding="utf-8")
    expect(fingerprint.k1(deps, spec) != base, "K1 missed an edit to an imported module")
    module.write_text(library, encoding="utf-8")
    expect(fingerprint.k1(deps, spec) == base, "K1 did not return once the edits were undone")
    absent = next(fingerprint._resolve(d.split(" ", 1)[1]) for d in deps
                  if d.startswith("absent ") and str(work.name) in d)
    absent.parent.mkdir(parents=True, exist_ok=True)
    absent.write_text("", encoding="utf-8")
    expect(fingerprint.k1(deps, spec) != base,
           f"K1 missed a file appearing where the resolver had looked: {absent}")
    absent.unlink()
    expect(fingerprint.k1(deps, ["other"]) != base, "K1 ignores the run specification")

    # ----- K2: the same sources and the same key flags, two different IRs.
    fingerprint.backend = fingerprint.backend or "canary-backend"
    first = fingerprint.k2(work / "a.ll", deps, spec)
    build("b.ll")
    expect(fingerprint.k2(work / "b.ll", deps, spec) == first, "K2 differs on identical IR")
    module.write_text("// a comment only\n" + library, encoding="utf-8")
    build("c.ll")
    expect(fingerprint.k2(work / "c.ll", deps, spec) != None, "K2 is missing")  # noqa: E711
    module.write_text(library, encoding="utf-8")
    build("checked.ll", "--overflow-checks")
    expect(fingerprint.k2(work / "checked.ll", deps, spec) != first,
           "K2 missed a change in the emitted IR")
    saved = fingerprint.backend
    fingerprint.backend = saved + "x"
    expect(fingerprint.k2(work / "a.ll", deps, spec) != first, "K2 ignores the backend")
    fingerprint.backend = None
    expect(fingerprint.k2(work / "a.ll", deps, spec) is None,
           "K2 was computed for a backend that cannot be identified")
    fingerprint.backend = saved

    # ----- the backend identity: a runtime edit changes it, a stale compiler refuses it.
    checkout = work / "checkout"
    (checkout / "runtime").mkdir(parents=True)
    runtime = checkout / "runtime" / "canary.c"
    runtime.write_text("int canary;\n", encoding="utf-8")
    compiler = checkout / "build" / "compiler"
    compiler.parent.mkdir()
    compiler.write_bytes(b"compiler")

    def identity():
        later = time.time() + 5
        os.utime(compiler, (later, later))
        probe = Fingerprint.__new__(Fingerprint)
        probe.root, probe.files = checkout, fingerprint.files
        return probe, probe._backend(compiler)[0]

    probe, before = identity()
    runtime.write_text("int canary = 1;\n", encoding="utf-8")
    probe, after = identity()
    expect(before and after and before != after, "a runtime edit left the backend identity alone")
    os.utime(runtime, (time.time() + 60, time.time() + 60))
    expect(probe._backend(compiler)[0] is None,
           "a runtime file newer than the compiler did not disable K2")
    expect(probe._backend(Path(PRISMIO_EXE.anchor) / "elsewhere")[0] is None,
           "a compiler outside the checkout did not disable K2")

    # ----- what K2 must *not* see: a rebuild of the compiler that changes no library.
    compiled = work / "lib"
    (compiled / "runtime").mkdir(parents=True)
    (compiled / "runtime" / "x.bc").write_bytes(b"bitcode")
    (compiled / "toolchain.stamp").write_text("compiler 1\n", encoding="utf-8")
    built = library_identity(fingerprint.files, compiled)
    (compiled / "toolchain.stamp").write_text("compiler 2, rebuilt\n", encoding="utf-8")
    expect(library_identity(fingerprint.files, compiled) == built,
           "K2's library identity changes with the compiler's own stamp")
    (compiled / "runtime" / "x.bc").write_bytes(b"other bitcode")
    expect(library_identity(fingerprint.files, compiled) != built,
           "K2's library identity missed a changed runtime module")

    # ----- K3 and reproducible links
    def link(directory):
        out = work / directory / "canary"
        out.parent.mkdir(exist_ok=True)
        key = work / directory / "key"
        found = run_command([str(PRISMIO_EXE), "build", str(program), "-o", str(out),
                             f"--emit-link-key={key}"])
        if found.returncode != 0:
            raise RuntimeError(found.stdout + found.stderr)
        return key.read_text().strip(), out.read_bytes()

    key_a, bytes_a = link("one")
    key_b, bytes_b = link("two")
    expect(key_a == key_b, "the link key differs between two identical builds")
    if sys.platform != "win32":
        expect(bytes_a == bytes_b, "two identical links produced different executables")
    expect(fingerprint.k3(key_a, spec) == fingerprint.k3(key_b, spec), "K3 differs")
    module.write_text(library.replace("a + a", "a * 3"), encoding="utf-8")
    key_c, _ = link("three")
    expect(key_c != key_a and fingerprint.k3(key_c, spec) != fingerprint.k3(key_a, spec),
           "K3 missed a change to what is linked")
    expect(fingerprint.k3(key_a, ["other"]) != fingerprint.k3(key_a, spec),
           "K3 ignores the run specification")

    if problems:
        print(f"{RED}[FAIL] engine_keys{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] each cache key tells different inputs apart{RESET}")
    return True


@harness_test("engine_cache_rules", suite="engine", resources={"cpu": 2})
def run_engine_cache_rules_test():
    """The rules, through the engine itself, with a results store of its own: a second `dev`
    run is cached and says so, `full` never uses a pass, `--no-cache` records none, a failure
    forgets the passes, and a filtered run says it was filtered."""
    print(f"\n{BLUE}--- Running engine_cache_rules ---{RESET}")
    from testkit.store import Store

    problems = []
    cache = scratch() / "cache"
    env = dict(os.environ, PRISMIO_TEST_CACHE_DIR=str(cache))
    env.pop("PRISMIO_TEST_CACHE", None)
    report = scratch() / "report.json"

    def engine(*words):
        found = subprocess.run(
            [sys.executable, str(PROJECT_ROOT / "tools" / "testkit"), *words, "--compiler",
             str(PRISMIO_EXE), "-k", "test_01_variables", "-k", "neg_01_type_mismatch",
             "--no-interactive", f"--report=json:{report}"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", env=env,
            cwd=str(PROJECT_ROOT))
        data = json.loads(report.read_text()) if report.is_file() else {}
        report.unlink(missing_ok=True)
        if found.returncode != 0:
            problems.append(f"{words}: exit {found.returncode}: {found.stdout[-2000:]}")
        return found, data

    def expect(condition, message):
        if not condition:
            problems.append(message)

    _, cold = engine("dev")
    expect(cold.get("cached") == 0 and cold.get("executed") == 2, f"a cold run: {cold}")
    warm_run, warm = engine("dev")
    expect(warm.get("cached") == 2 and warm.get("cached_by_level") == {"K1": 2},
           f"an unchanged second run is not cached at K1: {warm.get('cached_by_level')}")
    expect("FILTERED run" in warm_run.stdout, "a filtered run does not say so")
    _, full = engine("full")
    expect(full.get("cached") == 0 and full.get("executed") == 2, f"`full` used the cache: {full}")
    _, off = engine("dev", "--no-cache")
    expect(off.get("cached") == 0, f"--no-cache used the cache: {off}")
    store = Store(cache / "results.sqlite")
    store.forget("test_01_variables")
    store.forget("neg_01_type_mismatch")
    expect(not store.rows("test_01_variables", "K1"), "a failure's `forget` left a pass behind")
    store.close()
    _, forgotten = engine("dev")
    expect(forgotten.get("cached") == 0, f"a forgotten pass was used: {forgotten}")

    if problems:
        print(f"{RED}[FAIL] engine_cache_rules{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] only passes are cached, and only `dev` and `smoke` use them{RESET}")
    return True
