"""Running a file fixture, stage by stage, behind the cache keys.

    positive:  K1? -> front end to IR -> K2? -> build and link -> K3? -> run
    negative:  K1? -> build, which must be rejected for the stated reason
"""
import difflib
import hashlib
import os
import re

from testkit import process
from testkit.discovery import expected_traps, markers
from testkit.model import CACHED, FAIL, PASS, Result
from testkit.paths import EXE


def _hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", "replace")).hexdigest()


class Fixture:
    def __init__(self, test, context):
        self.test = test
        self.context = context
        self.tmp = context.directory(test)
        self.text = test.path.read_text(encoding="utf-8", errors="replace")
        self.relative = test.path.relative_to(context.root).as_posix()
        self.expected_output = None
        wanted = markers(self.text, "// expect-output:")
        if wanted:
            self.expected_output = test.path.parent / wanted[0]
        self.deps = []
        self.keys = {}

    # What a key carries beyond the files: everything that changes the verdict of a run.
    def spec(self) -> list:
        expected = None
        if self.expected_output is not None:
            expected = self.context.fingerprint.files.hash(self.expected_output)
        return [self.test.kind, self.relative, expected_traps(self.text),
                markers(self.text, "// expect-error:"), expected]

    def compile(self, output, *flags) -> process.Finished:
        depfile = self.tmp / "deps.txt"
        found = process.run(
            [self.context.compiler, "build", self.relative, "-o", output,
             f"--emit-deps={depfile}", *flags],
            timeout=self.test.timeout, cwd=str(self.context.root), env=self.context.environment(self.test))
        self.deps = self.context.fingerprint.depfile(depfile)
        return found

    def failed(self, reason: str, *shown) -> Result:
        output = "".join(f"    {line}\n" for line in [reason, *shown] if line)
        return Result(self.test, FAIL, output=output, keys=self.keys, deps=tuple(self.deps))

    def cached(self, level: str, row, extra=()) -> Result:
        return Result(self.test, CACHED, level=level, keys=self.keys,
                      stdout_hash=row["stdout_hash"], deps=tuple(self.deps),
                      detail=f"{level} from run {row['run']}")

    def input_hit(self):
        """K1, checked against each closure this test has passed with."""
        fingerprint = self.context.fingerprint
        for row in self.context.store.rows(self.test.id, "K1"):
            if fingerprint.k1(row["deps"], self.spec()) == row["key"]:
                self.deps = row["deps"]
                self.keys["K1"] = row["key"]
                return self.cached("K1", row)
        return None

    def lookup(self, level: str):
        key = self.keys.get(level)
        if key is None or not self.context.read_cache or not self.test.cache:
            return None
        row = self.context.store.hit(self.test.id, level, key)
        return None if row is None else self.cached(level, row)

    def record_inputs(self):
        if self.test.cache and self.deps:
            self.keys["K1"] = self.context.fingerprint.k1(self.deps, self.spec())

    # ----- negative ------------------------------------------------------------------

    def reject(self) -> Result:
        result = self.compile(self.tmp / f"{self.test.id}{EXE}")
        if result.timed_out:
            return self.failed(f"timed out after {self.test.timeout}s")
        output = f"{result.stdout}\n{result.stderr}"
        streams = (result.stdout.strip(), result.stderr.strip())
        if result.returncode == 0:
            return self.failed("Negative test compiled successfully; it should have been rejected",
                               *streams)
        # "aborting due to N previous error(s)" is printed only by diag_finish(), so it tells a
        # program the compiler deliberately rejected from one that crashed it.
        if "aborting due to" not in output:
            return self.failed("Compiler failed without reporting a diagnostic (crash or "
                               "toolchain error, not a rejection)", *streams)
        # Without the markers a negative test passes as long as *something* went wrong, so one
        # written for one bug keeps passing when an unrelated error starts firing first.
        missing = [want for want in markers(self.text, "// expect-error:") if want not in output]
        if missing:
            return self.failed(f"Rejected, but not for the expected reason. Missing: {missing}",
                               *streams)
        self.record_inputs()
        diagnostics = "\n".join(l for l in output.splitlines()
                                if re.match(r"error(?:\[P\d{4}\])?:", l))
        return Result(self.test, PASS, keys=self.keys, deps=tuple(self.deps),
                      stdout_hash=_hash(diagnostics))

    # ----- positive ------------------------------------------------------------------

    def run(self) -> Result:
        spec = self.spec()
        fingerprint = self.context.fingerprint
        executable = self.tmp / f"{self.test.id}{EXE}"

        if self.test.cache and fingerprint.backend is not None:
            ir = self.tmp / f"{self.test.id}.ll"
            front = self.compile(ir)
            if front.returncode != 0 or not ir.exists():
                return self.failed(self._compile_failure(front), front.stdout, front.stderr)
            self.keys["K2"] = fingerprint.k2(ir, self.deps, spec)
            hit = self.lookup("K2")
            if hit:
                self.record_inputs()
                return hit

        link_key = self.tmp / "link.key"
        built = self.compile(executable, f"--emit-link-key={link_key}")
        if built.returncode != 0 or not executable.exists():
            return self.failed(self._compile_failure(built), built.stdout, built.stderr)
        if self.test.cache and link_key.exists():
            self.keys["K3"] = fingerprint.k3(link_key.read_text().strip(), spec)
            hit = self.lookup("K3")
            if hit:
                self.record_inputs()
                return hit

        ran = self._execute(executable)
        if ran.timed_out:
            return self.failed(f"the program ran past {self.test.timeout}s", ran.stdout)
        if ran.returncode != 0:
            return self.failed(f"program exited with code {ran.returncode}",
                               ran.stdout.strip(), ran.stderr.strip())
        for argument, message in expected_traps(self.text):
            trapped = self._execute(executable, argument)
            if trapped.returncode == 0:
                return self.failed(f"case `{argument}` ran to the end; it should have stopped "
                                   f"with: {message}")
            if message not in trapped.stderr:
                return self.failed(f"case `{argument}` stopped, but not with: {message}",
                                   f"stderr: {trapped.stderr.strip()}")
        if self.expected_output is not None:
            try:
                expected = self.expected_output.read_text(encoding="utf-8")
            except OSError as error:
                return self.failed(f"cannot read the expected output: {error}")
            if ran.stdout != expected:
                return self.failed(f"stdout differs from {self.expected_output.name}",
                                   *_diff(expected, ran.stdout))
        self.record_inputs()
        result = Result(self.test, PASS, keys=self.keys, deps=tuple(self.deps),
                        stdout=ran.stdout, stdout_hash=_hash(ran.stdout),
                        stderr_hash=_hash(ran.stderr))
        result.changed_output = self._changed_output(result)
        return result

    def _execute(self, executable, *arguments) -> process.Finished:
        return process.run([executable, *arguments], timeout=self.test.timeout,
                           cwd=str(self.context.root), env=self.context.environment(self.test))

    def _compile_failure(self, result) -> str:
        if result.timed_out:
            return f"compilation ran past {self.test.timeout}s"
        return "Compilation failed" if result.returncode else "the compiler produced no output file"

    def _changed_output(self, result) -> str:
        """Different stdout from the last pass, under a different artifact: not a failure,
        and not something an exit status would ever report."""
        before = self.context.store.last_pass(self.test.id)
        if before is None or not before["stdout_hash"] or before["stdout_hash"] == result.stdout_hash:
            return ""
        artifact = self.keys.get("K3") or ""
        if artifact and before["artifact"] == artifact:
            return ""
        return "\n".join(_diff(before["stdout"], result.stdout))


def _diff(before: str, after: str, limit=30) -> list:
    lines = list(difflib.unified_diff(before.splitlines(), after.splitlines(),
                                      "before", "after", lineterm="", n=1))
    return lines[:limit] + (["..."] if len(lines) > limit else [])


def run_fixture(test, context) -> Result:
    fixture = Fixture(test, context)
    if context.read_cache and test.cache:
        hit = fixture.input_hit()
        if hit:
            return hit
    return fixture.reject() if test.kind == "reject" else fixture.run()
