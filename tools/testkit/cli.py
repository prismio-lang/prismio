"""`prismio suite [profile] [patterns] [options]`."""
import argparse
import dataclasses
import json
import os
import shutil
import signal
import sys
import time
import uuid
from pathlib import Path

from testkit import checks, discovery, impact, report
from testkit.audit import Audit
from testkit.cache import Fingerprint, digest
from testkit.context import Context
from testkit.fixtures import run_fixture
from testkit.harness import run_harness
from testkit.model import (BULK_WAVE, CACHED, FAIL, PASS, QUIET_WAVE, SKIP, SMOKE_WAVE, Result,
                           Test)
from testkit.paths import CACHE_DIR, EXE, REPO, TESTS, TOOLS, shown
from testkit.profiles import PROFILES, SMOKE
from testkit.scheduler import Pool, total_cpus
from testkit.store import Store
from testkit.toolchain import Copy, ToolchainError, find_compiler

# What a test is expected to take before it has ever run, in seconds.
EXPECTED = {"run": 0.6, "reject": 0.1, "harness": 15.0, "check": 60.0}


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="prismio suite",
        description="Run Prismio's tests. Profiles: " + ", ".join(PROFILES) +
        " (default dev); `affected` explains what a diff is expected to move.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="\n".join(f"  {p.name:8s} {p.summary}" for p in PROFILES.values()))
    p.add_argument("words", nargs="*", metavar="[profile] [pattern]",
                   help="a profile, then test names or substrings of them")
    p.add_argument("-k", "--filter", action="append", default=[], help="a name or substring")
    p.add_argument("--suite", action="append", default=[])
    p.add_argument("--tag", action="append", default=[])
    p.add_argument("--changed", action="store_true",
                   help="only tests the uncommitted diff can affect")
    p.add_argument("--keep-going", action="store_true",
                   help="run everything even if the smoke wave fails")
    p.add_argument("--list", action="store_true", help="name the selected tests and stop")
    p.add_argument("--explain", action="store_true", help="the same as `affected`")
    p.add_argument("--compiler", help="compiler to copy and test (default: the project host)")
    p.add_argument("--out", help="where verify/gate/release package the candidate")
    p.add_argument("--packaged", action="store_true",
                   help="--compiler is already a packaged candidate: package nothing")
    p.add_argument("--old", help="gate: a baseline compiler to diff mnemonics against")
    p.add_argument("--no-cache", action="store_true", help="neither use nor record results")
    p.add_argument("--cache-clear", action="store_true", help="forget every recorded pass")
    p.add_argument("--report", metavar="json[:FILE]", help="also write a JSON report")
    p.add_argument("--junit", metavar="FILE", help="also write JUnit XML")
    p.add_argument("--audit", action="store_true",
                   help="record what harness tests read and fail on undeclared reads")
    p.add_argument("--repeat", type=int, default=1, metavar="N",
                   help="run each test N times; mixed outcomes are reported as flaky")
    p.add_argument("--interactive", action="store_true", default=None)
    p.add_argument("--no-interactive", dest="interactive", action="store_false")
    return p


def select(tests, patterns, suites, tags) -> list:
    """By exact name first, then case-insensitive substring; then suite and tag."""
    if patterns:
        chosen = []
        for pattern in patterns:
            key = Path(pattern).stem.lower() if pattern.endswith(".psm") else pattern.lower()
            exact = [t for t in tests if t.id.lower() == key]
            chosen += [t for t in exact or [t for t in tests if key in t.id.lower()]
                       if t not in chosen]
        tests = [t for t in tests if t in chosen]
    if suites:
        tests = [t for t in tests if t.suite in suites]
    if tags:
        tests = [t for t in tests if t.tags & set(tags)]
    return tests


def pinned_llvm_path():
    paths = REPO / "third_party" / "llvm-paths.json"
    if paths.is_file():
        found = json.loads(paths.read_text(encoding="utf-8")).get("bin", "")
        if found:
            os.environ["PATH"] = found + os.pathsep + os.environ.get("PATH", "")


def cross_flags() -> list:
    """`--target`/`--sysroot` for the gate's cross-target check, or nothing."""
    sdk = checks.macos_sdk() if sys.platform == "darwin" else ""
    if not sdk:
        return []
    return ["--target", "x86_64-apple-macos", "--sysroot", f"x86_64-apple-macos={sdk}"]


class Run:
    def __init__(self, args, profile, words):
        self.args = args
        self.profile = profile
        self.patterns = words + args.filter
        self.filtered = bool(self.patterns or args.suite or args.tag or args.changed)
        self.caching = not args.no_cache and os.environ.get("PRISMIO_TEST_CACHE") != "0"
        self.results = []
        self.run_id = time.strftime("%Y%m%d-%H%M%S-") + uuid.uuid4().hex[:4]
        self.store = Store()
        if args.cache_clear:
            self.store.clear()

    # ----- preparing a candidate -------------------------------------------------------

    def prepare(self):
        """lint and packaging, in order; the path of the compiler under test, or None."""
        args, profile = self.args, self.profile
        source = find_compiler(args.compiler)
        packaging = "package" in profile.prepare and not args.packaged
        if "lint" in profile.prepare and not self.filtered:
            if not self.step("lint", [sys.executable, TOOLS / "lint.py"]):
                return None
        if not packaging:
            return source
        out = Path(args.out or profile.package_to)
        out = out if out.is_absolute() else REPO / out
        command = [sys.executable, TOOLS / "package.py", "--compiler", source, "--out", out]
        if "cross_target" in profile.checks:
            shutil.rmtree(out, ignore_errors=True)
            command += cross_flags()
        # The freestanding tests link the failure core into a bare-metal build.
        command += ["--freestanding-target", "aarch64-unknown-none-elf"]
        if not self.step("package", command):
            return None
        return out / "bin" / f"prismio{EXE}"

    def step(self, name, command) -> bool:
        from testkit import process
        test = Test(id=name, kind="check", suite="tooling")
        started = time.monotonic()
        print(f"  {name} ...", flush=True)
        found = process.run(command, timeout=1800, cwd=str(REPO))
        ok = found.returncode == 0
        detail = checks.last_line(found.text)
        result = Result(test, PASS if ok else FAIL, seconds=time.monotonic() - started,
                        detail=detail, output="" if ok else found.text)
        self.results.append(result)
        print(f"  {'ok  ' if ok else 'FAIL'} {result.seconds:7.2f}s  {name}  {detail}", flush=True)
        if name == "lint":
            for line in found.text.splitlines():
                if line.startswith("warning: format:"):
                    print(f"        {line}")
        if not ok:
            print(found.text)
        return ok

    # ----- one test ------------------------------------------------------------------

    def execute(self, test, cpu) -> Result:
        context = self.context
        context.granted[test.id] = cpu
        runner = {"harness": run_harness, "check": checks.run_check}.get(test.kind, run_fixture)
        outcomes = []
        for attempt in range(max(1, self.args.repeat)):
            started = time.monotonic()
            result = runner(test, context)
            result.seconds = time.monotonic() - started
            outcomes.append(result)
            if attempt + 1 < self.args.repeat:
                shutil.rmtree(context.work / test.id, ignore_errors=True)
        failed = [r for r in outcomes if r.outcome == FAIL]
        result = failed[0] if failed else outcomes[-1]
        result.flaky = bool(failed) and len(failed) != len(outcomes)
        return result

    def inputs(self, test) -> str:
        fingerprint = self.context.fingerprint
        if test.kind == "check":
            return ""
        path = test.path or REPO / "tests" / "harness" / f"{test.suite}.py"
        return digest(fingerprint.toolchain, test.id, fingerprint.files.hash(path))

    def finished(self, result: Result):
        test = result.test
        if result.outcome != SKIP:
            inputs = self.inputs(test)
            if result.outcome == PASS and self.store.failed_with_inputs(test.id, inputs):
                result.flaky = True
            outcome = "cached" if result.outcome == CACHED else result.outcome
            self.store.record_history(test.id, self.run_id, outcome, result.seconds, inputs,
                                      result.keys.get("K3", ""), result.stdout_hash,
                                      result.stdout)
        if self.caching and not self.args.audit:
            if result.outcome == FAIL:
                self.store.forget(test.id)
            elif result.outcome in (PASS, CACHED) and test.cache:
                for level, key in result.keys.items():
                    self.store.record_pass(
                        test.id, level, key, seconds=result.seconds,
                        stdout_hash=result.stdout_hash, stderr_hash=result.stderr_hash,
                        deps=result.deps if level == "K1" else (),
                        compiler=self.context.fingerprint.version, run=self.run_id)
        self.store.commit()
        self.results.append(result)
        self.progress.finished(result)

    # ----- the run -------------------------------------------------------------------

    def waves(self, tests, changed):
        failed_before = self.store.failed_last_time()
        durations = self.store.durations()

        def deps(test):
            rows = self.store.rows(test.id, "K1")
            return rows[0]["deps"] if rows else ()

        moved = {}
        for test in tests:
            moved[test.id] = impact.reasons(test, changed, deps(test))
        first = set(SMOKE) | failed_before | {
            t.id for t in tests if t.path is not None and "its file changed" in moved[t.id]}

        def expected(test):
            return durations.get(test.id, EXPECTED[test.kind])

        def priority(test):
            # Longest first fills the pool best; among the short ones, what the diff names
            # reports first.
            seconds = expected(test)
            if seconds >= 5:
                return (0, -seconds, test.order)
            return (1 if moved[test.id] else 2, -seconds, test.order)

        waves = {SMOKE_WAVE: [], BULK_WAVE: [], QUIET_WAVE: []}
        for test in tests:
            if "quiet" in test.resources:
                waves[QUIET_WAVE].append(test)
            elif test.kind != "check" and test.id in first:
                waves[SMOKE_WAVE].append(test)
            else:
                waves[BULK_WAVE].append(test)
        return [(wave, sorted(members, key=priority)) for wave, members in sorted(waves.items())
                if members]

    def choose(self, every, changed):
        """The tests and checks of this run."""
        profile = self.profile
        tests = every
        if profile.only:
            names = {t.id for t in every}
            missing = [n for n in profile.only if n not in names]
            if missing:
                raise ToolchainError(f"the smoke set names tests that do not exist: {missing}")
            wanted = set(profile.only) | self.store.failed_last_time() | {
                c.split("/")[-1][:-4] for c in changed
                if c.startswith("tests/") and c.endswith(".psm") and c.count("/") == 1}
            tests = [t for t in every if t.id in wanted]
        catalogue = checks.catalogue()
        wanted_checks = [n for n in profile.checks]
        if self.args.old and profile.name in ("gate", "release"):
            wanted_checks.append("mnemonic_diff")
        tests = tests + [dataclasses.replace(catalogue[n], order=10000 + i)
                         for i, n in enumerate(wanted_checks)]
        if self.args.audit:
            tests = [t for t in tests if t.kind == "harness"]
        tests = select(tests, self.patterns, self.args.suite, self.args.tag)
        if self.args.changed:
            wide = [c for c in changed if c.startswith(impact.EVERYTHING)]
            if wide:
                print(f"--changed: {wide[0]} can affect every test; nothing is left out")
            else:
                def deps(test):
                    rows = self.store.rows(test.id, "K1")
                    return rows[0]["deps"] if rows else ()
                tests = [t for t in tests if impact.reasons(t, changed, deps(t))]
        return tests

    def main(self) -> int:
        args, profile = self.args, self.profile
        every = discovery.discover()
        changed = impact.changed_files()
        if args.explain:
            def deps(test):
                rows = self.store.rows(test.id, "K1")
                return rows[0]["deps"] if rows else ()
            chosen = select(every, self.patterns, args.suite, args.tag)
            print("\n".join(impact.explain(changed, chosen, deps)))
            return 0
        tests = self.choose(every, changed)
        if not tests:
            if self.args.changed:
                print("nothing the diff can affect")
                return 0
            print(f"[FAIL] no test matched: {', '.join(self.patterns + args.suite + args.tag)}\n"
                  "Use --list to see the names.")
            return 2
        if args.list:
            for test in tests:
                print(test.id)
            return 0

        if profile.pinned_llvm:
            pinned_llvm_path()
        started = time.monotonic()
        write_only = not profile.read_cache
        copy = context = None
        not_run = []
        listing = set(os.listdir(TESTS))
        try:
            compiler = self.prepare()
            if compiler is not None:
                copy = Copy(compiler)
                print(f"suite: profile {profile.name}, testing a copy of {shown(compiler)}")
                fingerprint = Fingerprint(copy)
                if fingerprint.backend is None and profile.read_cache and self.caching:
                    print(f"suite: K2 is off: {fingerprint.backend_refusal}")
                read = (profile.read_cache and self.caching and not args.audit
                        and args.repeat <= 1)
                context = self.context = Context(
                    options=args, copy=copy, candidate=Path(compiler).parent.parent,
                    fingerprint=fingerprint, store=self.store, read_cache=read,
                    run_id=self.run_id,
                    audit=Audit(copy.compiler) if args.audit else None)
                self.progress = report.Progress(len(tests), args.interactive)
                pool = Pool(self.execute, self.finished, self.progress.started)
                print(f"suite: {len(tests)} test(s) on {pool.cpus} cpu(s), at most {pool.jobs} "
                      f"at once\n", flush=True)
                try:
                    not_run = pool.run(self.waves(tests, changed),
                                       fail_fast=not args.keep_going)
                finally:
                    self.progress.stop()
                if args.audit:
                    print(f"audit: {shown(context.audit.write())}")
        except KeyboardInterrupt:
            print("\nsuite: interrupted")
            return 130
        finally:
            if context:
                context.close()
            if copy:
                copy.close()
            self.store.commit()

        wall = time.monotonic() - started
        if not self.caching or args.audit:
            mode = "off"
        elif write_only or args.repeat > 1:
            mode = "write-only"
        else:
            mode = "read/write"
        data = report.summary(self.results, wall, profile=profile.name,
                              compiler=str(args.compiler or "default"),
                              filtered=self.filtered, not_run=not_run, cache=mode)
        report.print_summary(data, self.results)
        if args.report:
            kind, _, target = args.report.partition(":")
            path = Path(target) if target else CACHE_DIR / "report.json"
            report.write_json(data, path)
            print(f"report: {shown(path)}")
        if args.junit:
            report.write_junit(self.results, Path(args.junit), wall)
            print(f"junit: {args.junit}")
        littered = sorted(set(os.listdir(TESTS)) - listing - {"__pycache__"})
        # `.prismio-*` is the compiler's own litter: a workload's published profile (LAYOUT
        # 2.2), and the temporaries of a build that was meant to fail.
        for name in [n for n in littered if n.startswith(".prismio-")]:
            (TESTS / name).unlink(missing_ok=True)
            littered.remove(name)
        if littered:
            print(f"warning: the run left files in tests/: {', '.join(littered[:10])}")
        if self.filtered:
            print(f"FILTERED run of profile {profile.name}: this is not the whole suite")
        return 1 if data["failed"] or data["not_run"] else 0


def main(argv) -> int:
    arguments = parser()
    # `--report=json` and friends interleave freely with patterns.
    args = arguments.parse_intermixed_args(argv)
    if args.report and args.report.partition(":")[0] != "json":
        arguments.error("--report takes json or json:<file>")
    words = list(args.words)
    name = "dev"
    if words and words[0] in PROFILES:
        name = words.pop(0)
    elif words and words[0] == "affected":
        words.pop(0)
        args.explain = True

    def interrupted(number, frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, interrupted)
    if args.old:
        args.old = str(Path(args.old).resolve())
    try:
        return Run(args, PROFILES[name], words).main()
    except ToolchainError as error:
        print(f"suite: {error}")
        return 1
