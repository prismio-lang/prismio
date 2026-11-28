"""The checks that are not tests of one program: what `verify`, `gate` and `release` add.

Each is a function of a `Check` context that returns (ok, detail) -- ok is None for "skipped,
and why". `gate`'s are everything tools/release_gate.py checked, in the order a failure is
cheapest to diagnose: correctness before performance, generated code before timings.
"""
import filecmp
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from source_toolchain import source_toolchain
from testkit import process
from testkit.api import EXCLUSIVE
from testkit.model import Test
from testkit.paths import EXE, REPO, TOOLS
from testkit.workloads import GATE_WORKLOADS, SUITE, printed_result, recorded_results

ANSI = re.compile(r"\x1b\[[0-9;]*m")


class Check:
    """What one check works with. `state` is shared by the checks of a run."""

    def __init__(self, context, test):
        self.context = context
        self.test = test
        self.compiler = context.compiler          # the copy under test
        self.candidate = context.candidate        # the toolchain root it was copied from
        self.work = context.directory(test)
        self.state = context.state
        self.log = []

    def run(self, command, *, cwd=None, env=None, timeout=None) -> process.Finished:
        merged = self.context.environment(self.test)
        merged.update(env or {})
        found = process.run(command, cwd=str(cwd or REPO), env=merged,
                            timeout=timeout or self.test.timeout)
        if found.returncode != 0:
            self.log.append(f"$ {' '.join(str(c) for c in command)}\n"
                            f"{ANSI.sub('', found.text)[-4000:]}")
        return found

    def python(self, script, *arguments, **options) -> process.Finished:
        return self.run([sys.executable, TOOLS / script, *arguments], **options)


def last_line(text: str) -> str:
    lines = [line for line in ANSI.sub("", text).splitlines() if line.strip()]
    return lines[-1].strip() if lines else ""


def from_exit(found, passed="") -> tuple:
    return (True, passed) if found.returncode == 0 else (False, last_line(found.text))


# ----- the checkout -------------------------------------------------------------------

def lint(check):
    found = check.python("lint.py")
    if found.returncode != 0:
        return False, last_line(found.text)
    passed = re.search(r"Lint passed \((\d+) source files, (\d+) diagnostic codes\)", found.text)
    detail = (f"{passed.group(1)} source files, {passed.group(2)} diagnostic codes"
              if passed else "passed")
    unformatted = re.findall(r"^warning: format: (\S+)", found.text, re.MULTILINE)
    if unformatted:
        detail += (f"; {len(unformatted)} files need formatting "
                   "(tools/format_sources.py --write)")
    return True, detail


def source_lists(check):
    return from_exit(check.python("check_source_lists.py"))


def externs(check):
    if os.name == "nt":
        return None, "check_externs.py needs macOS or Linux"
    return from_exit(check.python("check_externs.py", "--dist", check.candidate))


# ----- the memory analysis and PIR ----------------------------------------------------

def aif_differential(check):
    found = check.python("aif_differential.py", "--compiler", check.compiler)
    summary = last_line(found.text)
    return "agree on all" in summary and found.returncode == 0, summary


# Programs the interpreter is known to get wrong (docs/KNOWN_ISSUES.md). The check fails on any
# other, and on one of these starting to agree, so that the list cannot outlive its reasons.
PIR_KNOWN = ("tests/test_287_multi_statement_fill.psm",)


def pir_differential(check):
    results = check.work / "pir.json"
    found = check.python("pir_differential.py", "--compiler", check.compiler,
                         "--jobs", str(check.test.cpu), "--json", results)
    if not results.is_file():
        return False, last_line(found.text) or "the differential wrote no result"
    compared = [r for programs in json.loads(results.read_text(encoding="utf-8")).values()
                for r in programs]
    wrong = sorted(Path(r["program"]).resolve().relative_to(REPO.resolve()).as_posix()
                   for r in compared if r["kind"] in ("mismatch", "crash"))
    new = [name for name in wrong if name not in PIR_KNOWN]
    fixed = [name for name in PIR_KNOWN if name not in wrong]
    if new:
        return False, "the interpreter disagrees on " + ", ".join(new)
    if fixed:
        return False, f"now agrees, so take it off PIR_KNOWN: {', '.join(fixed)}"
    matched = sum(r["kind"] == "match" for r in compared)
    return True, f"{matched} programs agree; {len(wrong)} known disagreement(s)"


# ----- the benchmark programs ---------------------------------------------------------

def _build_suite(check, name, *flags, env=None):
    binary = check.work / f"{name}{EXE}"
    built = check.run([check.compiler, "build", SUITE, *flags, "-o", binary], env=env)
    return (binary if built.returncode == 0 else None), built


def _run_workloads(check, binary, names, fixture="") -> list:
    expected = recorded_results()
    wrong = []
    for name in names:
        output = check.work / f"{name}.txt" if fixture else ""
        done = check.run([binary, name, fixture, output], timeout=120)
        printed = printed_result(done.stdout)
        if done.returncode != 0 or printed != str(expected.get(name)):
            wrong.append(f"{name}[{printed} != {expected.get(name)}]")
    return wrong


def workloads(check):
    binary, built = _build_suite(check, "suite")
    if binary is None:
        return False, "the benchmark suite does not build"
    wrong = _run_workloads(check, binary, GATE_WORKLOADS)
    return (False, " ".join(wrong)) if wrong else (True, f"{len(GATE_WORKLOADS)} workloads")


def corpus(check):
    """Every recorded workload, run: the programs nothing else executes."""
    binary, built = _build_suite(check, "corpus")
    if binary is None:
        return False, "the benchmark suite does not build"
    names = [n for n, result in recorded_results().items() if result is not None]
    # The file workloads read and write what benchmarks/run.py gives them.
    spec = importlib.util.spec_from_file_location("bench_run", REPO / "benchmarks" / "run.py")
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    fixture = runner.make_fixture(check.work)
    wrong = _run_workloads(check, binary, names, fixture)
    return (False, " ".join(wrong)) if wrong else (True, f"{len(names)} programs")


# Programs that are not benchmark workloads but exercise the paths they cannot: the channel
# runtime and a generic annotation.
VERIFY_SWEEP = ("tests/test_96_channels.psm", "tests/test_97_generic_annotation.psm")


def verify_sweep(check):
    leaky = []

    def ledger(command) -> str:
        reported = [line for line in check.run(command, timeout=300).stderr.splitlines()
                    if "aif-verify:" in line]
        return reported[-1] if reported else ""

    def clean(line) -> bool:
        return line.endswith("0 leaked, 0 violation(s)")

    for relative in VERIFY_SWEEP:
        stem = Path(relative).stem
        binary = check.work / f"{stem}-v{EXE}"
        if check.run([check.compiler, "build", relative, "--verify", "-o", binary]).returncode:
            leaky.append(f"build:{stem}")
            continue
        line = ledger([binary])
        if not clean(line):
            leaky.append(f"{stem}[{line}]")
    suite, _ = _build_suite(check, "suite-v", "--verify")
    if suite is None:
        leaky.append("build:suite")
    else:
        for name in GATE_WORKLOADS:
            line = ledger([suite, name, "", ""])
            if not clean(line):
                leaky.append(f"{name}[{line}]")
    if leaky:
        return False, " ".join(leaky)
    return True, "0 leaked / 0 violations on every program"


def _switched_off(check, variable, workload):
    binary, _ = _build_suite(check, workload, env={variable: "0"})
    if binary is None:
        return False, f"the suite does not build with {variable}=0"
    wrong = _run_workloads(check, binary, [workload])
    return (False, " ".join(wrong)) if wrong else (True, f"{variable}=0")


def curated_runtime_off(check):
    return _switched_off(check, "PRISMIO_INLINE_RUNTIME", "ecs_component_update")


def object_cache_off(check):
    return _switched_off(check, "PRISMIO_OBJ_CACHE", "aos_vs_soa")


def jit(check):
    found = check.run([check.compiler, "run", "tests/test_96_channels.psm", "--jit"])
    return "PASS: channels" in found.text, "test_96_channels"


def macos_sdk() -> str:
    if not shutil.which("xcrun"):
        return ""
    probe = subprocess.run(["xcrun", "--show-sdk-path"], capture_output=True, text=True)
    return probe.stdout.strip() if probe.returncode == 0 else ""


def cross_target(check):
    # The sysroot is not optional: without an SDK for the target there is no C library, so the
    # runtime cannot be compiled for it and `stdio.h` is not found.
    sdk = macos_sdk()
    if not sdk:
        return None, "no SDK on this host"
    binary = check.work / f"suite-x86{EXE}"
    built = check.run([check.compiler, "build", SUITE, "--target", "x86_64-apple-macos",
                       "--sysroot", sdk, "-o", binary])
    described = subprocess.run(["file", str(binary)], capture_output=True, text=True).stdout
    if built.returncode == 0 and "x86_64" in described:
        return True, "x86_64-apple-macos built"
    return False, last_line(built.text)


def packaged_toolchain(check):
    dist = check.work / "dist"
    packaged = check.python("package.py", "--compiler", check.compiler, "--out", dist)
    if packaged.returncode != 0:
        return False, last_line(packaged.text)
    separated = check.python("verify_separation.py", "--dist", dist)
    if separated.returncode != 0:
        return False, last_line(separated.text)
    smoke = check.python("smoke_package.py", "--dist", dist)
    if smoke.returncode != 0:
        return False, last_line(smoke.text)
    return True, last_line(separated.stdout)


# ----- self-hosting -------------------------------------------------------------------

def _bootstrap(check, compiler, out):
    """tools/bootstrap.py hand-links a generation, which must not go through any existing
    binary's idea of the toolchain."""
    return check.python("bootstrap.py", "--compiler", compiler, "--out", out)


def generations(check):
    # One directory for the generations, their comparison and the candidate's reproduction:
    # emitted IR names the standard library's files, so all three must read them from one place.
    work = check.state["selfhost"] = check.work
    g1, g2 = work / f"g1{EXE}", work / f"g2{EXE}"
    first = _bootstrap(check, check.compiler, g1)
    if first.returncode != 0:
        return False, last_line(first.text)
    second = _bootstrap(check, g1, g2)
    check.state["g1"], check.state["g2"] = g1, g2
    return from_exit(second, "two generations")


def fixpoint(check):
    work = check.state["selfhost"]
    a, b = work / "a.ll", work / "b.ll"
    first = check.run([check.state["g1"], "build", "src/main.psm", "-o", a])
    second = check.run([check.state["g2"], "build", "src/main.psm", "-o", b])
    if (first.returncode == 0 and second.returncode == 0 and a.is_file() and b.is_file()
            and filecmp.cmp(a, b, shallow=False)):
        check.state["ir"] = a
        return True, "byte-identical"
    return False, "generation 1 and generation 2 emit different IR"


def reproduces(check):
    work = check.state["selfhost"]
    produced = work / "rc.ll"
    # As a generation emits it: with this tree's std/ as source, not the candidate's compiled
    # modules, and from the directory the generations read it from -- failure messages name it.
    emitter = source_toolchain(check.compiler, REPO, work)
    found = check.run([emitter, "build", "src/main.psm", "-o", produced])
    ir = check.state.get("ir")
    if (found.returncode == 0 and produced.is_file() and ir and ir.is_file()
            and filecmp.cmp(produced, ir, shallow=False)):
        return True, "the frozen binary emits generation 1's IR"
    return False, "the candidate is not the fixpoint"


def seed(check):
    """bootstrap/seed.ll still builds a compiler from this tree -- the path a machine with no
    Prismio takes -- and that compiler builds the tree: one that only links is no use on a new
    machine."""
    seeded = check.work / f"seedchk{EXE}"
    found = check.python("bootstrap.py", "--seed", "--out", seeded)
    if found.returncode == 0:
        found = _bootstrap(check, seeded, check.work / "seedgen" / f"g1{EXE}")
    return from_exit(found, "the committed seed builds the compiler, which builds this tree")


def mnemonic_diff(check):
    # Mnemonics, not `.ll` text: alias metadata changes the IR of nearly every program without
    # changing one instruction.
    old = check.context.options.old
    before, after = check.work / f"benchmarks-old{EXE}", check.work / f"benchmarks-new{EXE}"
    if check.run([Path(old).resolve(), "build", SUITE, "-o", before]).returncode != 0:
        return False, f"the baseline ({old}) cannot build the benchmark suite"
    if check.run([check.compiler, "build", SUITE, "-o", after]).returncode != 0:
        return False, "the candidate cannot build the benchmark suite"
    diffed = check.python("fn_mnemonic_diff.py", before, after)
    lines = diffed.stdout.splitlines()
    return True, f"benchmark suite: {lines[0]}" if lines else "benchmark suite"


# ----- the release ---------------------------------------------------------------------

def sanitizer_smoke(check):
    if not sys.platform.startswith("linux"):
        return None, "AddressSanitizer smoke runs on Linux"
    return from_exit(check.python("sanitizer_smoke.py", "--compiler", check.compiler))


def benchmark_smoke(check):
    found = check.run([sys.executable, REPO / "benchmarks" / "run.py", "--suite", "hosted",
                       "--compiler", check.compiler, "--runs", "1",
                       "--output", check.work / "benchmark-smoke.json"])
    return from_exit(found, "every supported workload's checksum")


def _doc_examples(app):
    def run(check):
        root = REPO.parent / "website" / "apps" / app
        if not (root / "scripts" / "verify-doc-examples.mjs").is_file():
            return None, f"no ../website/apps/{app} beside this checkout"
        if not shutil.which("node"):
            return None, "node is not installed"
        found = check.run(["node", "scripts/verify-doc-examples.mjs"], cwd=root,
                          env={"PRISMIO_INTERNAL_HOSTED": "1",
                               "PRISMIO": str(check.candidate / "bin" / f"prismio{EXE}")})
        return from_exit(found, last_line(found.text))
    return run


def ci_matrix(check):
    return None, ("started by hand once the commit is pushed: "
                  "`gh workflow run ci.yml --ref main` (RELEASE.md)")


def _check(name, run, *, suite, cpu=2, mem=800, after=(), timeout=900, locks=()):
    resources = {"cpu": cpu, "mem": mem}
    resources.update({lock: EXCLUSIVE for lock in locks})
    return Test(id=name, kind="check", suite=suite, run=run, resources=resources,
                after=tuple(after), cache=False, timeout=timeout)


def catalogue() -> dict:
    """Every check by name. A profile names the ones it runs."""
    return {c.id: c for c in (
        _check("lint", lint, suite="tooling", cpu=1),
        _check("source_lists", source_lists, suite="tooling", cpu=1),
        _check("externs", externs, suite="tooling", cpu=1),
        _check("aif_differential", aif_differential, suite="aif", cpu=4, mem=2000),
        _check("pir_differential", pir_differential, suite="pir", cpu=4, mem=2000,
               timeout=1800),
        _check("corpus", corpus, suite="corpus", cpu=2),
        _check("generations", generations, suite="bootstrap", cpu="all", mem=6000,
               timeout=1800),
        _check("fixpoint", fixpoint, suite="bootstrap", after=["generations"], mem=3000),
        _check("candidate_reproduces", reproduces, suite="bootstrap", after=["fixpoint"],
               mem=2000),
        _check("seed", seed, suite="bootstrap", cpu="all", mem=6000, timeout=1800),
        _check("gate_workloads", workloads, suite="perf"),
        _check("verify_sweep", verify_sweep, suite="safety", mem=2000),
        _check("curated_runtime_off", curated_runtime_off, suite="safety"),
        _check("object_cache_off", object_cache_off, suite="safety"),
        _check("jit_run", jit, suite="targets"),
        _check("cross_target", cross_target, suite="targets"),
        _check("packaged_toolchain", packaged_toolchain, suite="tooling", cpu=3, mem=1500),
        _check("mnemonic_diff", mnemonic_diff, suite="codegen"),
        _check("sanitizer_smoke", sanitizer_smoke, suite="safety", cpu=4, mem=3000),
        _check("benchmark_smoke", benchmark_smoke, suite="perf", cpu="all", mem=4000,
               timeout=1800, locks=["quiet"]),
        _check("docs_examples", _doc_examples("docs"), suite="tooling", timeout=1800),
        _check("developer_docs_examples", _doc_examples("developers"), suite="tooling",
               timeout=1800),
        _check("ci_matrix", ci_matrix, suite="tooling", cpu=1),
    )}


def run_check(test, context):
    from testkit.model import FAIL, PASS, SKIP, Result
    check = Check(context, test)
    ok, detail = test.run(check)
    outcome = SKIP if ok is None else PASS if ok else FAIL
    output = ""
    if outcome == FAIL:
        output = "".join(f"    {line}\n" for line in
                         [detail, *"\n".join(check.log).splitlines()[-60:]])
    return Result(test, outcome, detail=detail or "", output=output)
