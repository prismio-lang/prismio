"""Running a harness test: one process each, behind its input key.

A process of its own is what lets tests run side by side: each has its own environment,
temporary directory and output, a deadline that can take it down, and (in `--audit`) a record
of what it opened.
"""
import hashlib
import json
import sys

from testkit import process
from testkit.model import CACHED, FAIL, PASS, Result
from testkit.paths import TOOLS


def run_harness(test, context) -> Result:
    store = context.store
    key = None
    if test.cache and not context.options.audit:
        key = context.fingerprint.harness(test)
        if context.read_cache:
            row = store.hit(test.id, "K1", key)
            if row:
                return Result(test, CACHED, level="K1", keys={"K1": key},
                              stdout_hash=row["stdout_hash"], detail=f"K1 from run {row['run']}")
    directory = context.directory(test)
    env = context.environment(test)
    env.update(PRISMIO_TEST_COMPILER=str(context.compiler),
               PRISMIO_TEST_SCRATCH=str(directory),
               PRISMIO_TEST_CPUS=str(context.granted_cpus(test)),
               PYTHONDONTWRITEBYTECODE="1")
    command = [sys.executable, "-X", "utf8", "-u", TOOLS / "testkit" / "child.py",
               test.suite, test.id]
    audit_file = directory / "audit.json"
    if context.options.audit:
        command.append(f"--audit={audit_file}")
    ran = process.run(command, timeout=test.timeout, cwd=str(context.root), env=env, grace=60)
    keys = {"K1": key} if key else {}
    if ran.timed_out:
        return Result(test, FAIL, keys=keys,
                      output=f"    timed out after {test.timeout}s\n{_indent(ran.text)}")
    if ran.returncode != 0:
        return Result(test, FAIL, keys=keys, output=_indent(ran.text))
    if context.options.audit:
        record = json.loads(audit_file.read_text(encoding="utf-8"))
        problem = context.audit.add(test, record)
        if problem:
            return Result(test, FAIL, output=f"    {problem}\n", detail="undeclared reads")
    return Result(test, PASS, keys=keys,
                  stdout_hash=hashlib.sha256(ran.stdout.encode("utf-8", "replace")).hexdigest())


def _indent(text: str) -> str:
    return "".join(f"    {line}\n" for line in text.splitlines()[-200:])
