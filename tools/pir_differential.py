#!/usr/bin/env python3
"""Run every program both ways and compare: compiled, and `build --pir-run`.

    python3 tools/pir_differential.py --compiler <toolchain>/bin/<name>
    python3 tools/pir_differential.py --compiler ... tests/test_01_hello.psm dir/

With no paths it runs `tests/`, `benchmarks/hosted/prismio/`, and any `--extra` directory.
Each program is built and run in a scratch directory outside the checkout, so `std.*` comes
from the compiler's `stdlib/`. The interpreter's standard output and exit status must be
the compiled program's. A program is one of:

    match        the same output and status
    mismatch     different: either the interpreter or the compiled code is wrong
    ineligible   it reached something the interpreter does not model (named)
    timeout      the interpreter did not finish in time
    crash        the interpreter itself failed (`pir internal error`, a signal, a verifier
                 finding, a build that works without `--pir-run` and not with it)
    not built    the compiled build fails (a module without `main`, a diagnostic fixture)
    native timeout

Hazard lines (a view read after its place was written) are collected from every run that
interprets. The compiler must not be named `prismio`, which is a launcher.
"""
import argparse
import collections
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HAZARD = re.compile(r"^pir hazard: view of (.*) pinned at (\S+) read after a write at (\S+) \((\d+) times\)$")


def run(command, cwd, timeout, env):
    """(status, stdout, stderr, seconds), status None when it ran out of time."""
    started = time.monotonic()
    try:
        done = subprocess.run(command, cwd=cwd, env=env, timeout=timeout,
                              stdin=subprocess.DEVNULL, capture_output=True)
    except subprocess.TimeoutExpired as expired:
        return None, expired.stdout or b"", expired.stderr or b"", time.monotonic() - started
    return done.returncode, done.stdout, done.stderr, time.monotonic() - started


def check(program, args, scratch, index):
    env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
    work = scratch / f"{index:04d}-{program.stem}"
    work.mkdir()
    binary = work / program.stem
    result = {"program": str(program), "kind": "", "detail": "", "hazards": []}

    status, _, err, _ = run([args.compiler, "build", str(program), "-o", str(binary),
                             *args.build_flag], work,
                            args.build_timeout, env)
    if status != 0 or not binary.exists():
        result["kind"] = "not built"
        result["detail"] = first_line(err, b"error")
        return result

    # Each run gets an empty directory, since a program may write files.
    native_dir = work / "native"
    native_dir.mkdir()
    status, out, err, seconds = run([str(binary)], native_dir, args.native_timeout, env)
    if status is None:
        result["kind"] = "native timeout"
        return result
    result["native"] = {"status": status, "seconds": round(seconds, 3)}

    pir_dir = work / "pir"
    pir_dir.mkdir()
    pir_status, pir_out, pir_err, pir_seconds = run(
        [args.compiler, "build", str(program), "-o", str(binary), "--pir-run", *args.build_flag],
        pir_dir,
        args.timeout, env)
    result["pir"] = {"status": pir_status, "seconds": round(pir_seconds, 3)}
    for line in pir_err.decode("utf-8", "replace").splitlines():
        found = HAZARD.match(line)
        if found:
            result["hazards"].append({"place": found[1], "pinned": found[2], "read": found[3],
                                      "times": int(found[4])})

    ineligible = re.search(rb"^pir ineligible: (.*)$", pir_err, re.M)
    if pir_status is None:
        result["kind"] = "timeout"
    elif ineligible and pir_status == 125:
        result["kind"] = "ineligible"
        result["detail"] = ineligible[1].decode("utf-8", "replace")
    elif pir_status < 0 or b"pir internal error" in pir_err or b"PIR verification failed" in pir_err:
        result["kind"] = "crash"
        result["detail"] = f"status {pir_status}: " + first_line(pir_err, b"pir ")
    elif pir_status == status and pir_out == out:
        result["kind"] = "match"
    else:
        result["kind"] = "mismatch"
        result["detail"] = f"status {status} compiled, {pir_status} interpreted"
        if pir_out != out:
            result["detail"] += f"; output differs at byte {difference(out, pir_out)}"
        keep = args.keep / program.stem if args.keep else None
        if keep:
            keep.mkdir(parents=True, exist_ok=True)
            (keep / "compiled.out").write_bytes(out)
            (keep / "compiled.err").write_bytes(err)
            (keep / "pir.out").write_bytes(pir_out)
            (keep / "pir.err").write_bytes(pir_err)
    shutil.rmtree(work, ignore_errors=True)
    return result


def first_line(text, containing):
    for line in text.split(b"\n"):
        if containing in line:
            return line.decode("utf-8", "replace")[:240]
    return ""


def difference(a, b):
    for i, (x, y) in enumerate(zip(a, b)):
        if x != y:
            return i
    return min(len(a), len(b))


def reason_class(detail):
    """`extern name`, or a refusal without the function it was first met in."""
    return re.sub(r" in \S+$", "", detail) if detail.startswith("refused ") else detail


def report(corpus, results):
    kinds = collections.Counter(r["kind"] for r in results)
    print(f"\n== {corpus}: {len(results)} programs")
    built = len(results) - kinds["not built"] - kinds["native timeout"]
    eligible = built - kinds["ineligible"]
    print(f"   built {built}, eligible {eligible}, match {kinds['match']}, mismatch {kinds['mismatch']}, "
          f"ineligible {kinds['ineligible']}, interpreter timeout {kinds['timeout']}, crash {kinds['crash']}"
          f" (not built {kinds['not built']}, native timeout {kinds['native timeout']})")
    reasons = collections.Counter(reason_class(r["detail"]) for r in results if r["kind"] == "ineligible")
    for reason, count in reasons.most_common(20):
        print(f"   ineligible {count:4}  {reason}")
    for r in results:
        if r["kind"] in ("mismatch", "crash", "timeout"):
            print(f"   {r['kind']:9} {r['program']}: {r['detail']}")
    hazardous = [r for r in results if r["hazards"]]
    sites = sum(len(r["hazards"]) for r in hazardous)
    print(f"   hazards: {len(hazardous)} programs, {sites} (pin, read) site pairs")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="*", help="programs or directories (default: the two corpora)")
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--extra", action="append", default=[], help="another directory to run (repeatable)")
    parser.add_argument("--timeout", type=float, default=60, help="seconds for an interpreted run")
    parser.add_argument("--native-timeout", type=float, default=30)
    parser.add_argument("--build-timeout", type=float, default=120)
    parser.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 4) // 2))
    parser.add_argument("--json", type=Path, help="write every result here")
    parser.add_argument("--build-flag", action="append", default=[],
                        help="passed to both builds, e.g. --build-flag=--pir=plan")
    parser.add_argument("--keep", type=Path, help="keep both outputs of each mismatch under here")
    args = parser.parse_args()
    args.compiler = str(Path(args.compiler).resolve())
    if Path(args.compiler).name in ("prismio", "prismio.exe"):
        sys.exit("pir_differential: give a compiler not named `prismio` (that name is a launcher)")
    if args.keep:
        args.keep = args.keep.resolve()

    given = args.paths or [str(REPO / "tests"), str(REPO / "benchmarks" / "hosted" / "prismio")]
    corpora = []
    for entry in given + args.extra:
        path = Path(entry).resolve()
        programs = sorted(path.glob("*.psm")) if path.is_dir() else [path]
        corpora.append((entry, programs))

    everything = {}
    with tempfile.TemporaryDirectory(prefix="pir-differential-") as scratch:
        index = 0
        with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
            for corpus, programs in corpora:
                futures = []
                for program in programs:
                    futures.append(pool.submit(check, program, args, Path(scratch), index))
                    index += 1
                everything[corpus] = [f.result() for f in futures]
                report(corpus, everything[corpus])
    if args.json:
        args.json.write_text(json.dumps(everything, indent=1))
    bad = sum(1 for results in everything.values() for r in results if r["kind"] in ("mismatch", "crash"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
