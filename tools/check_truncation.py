#!/usr/bin/env python3
"""Check that `prismio check` survives broken input.

An editor sends the compiler a file that does not parse for most of the time it is
open, so the frontend has to end every run with diagnostics and a summary line, never
with a crash, a hang, an internal error, or a silent non-zero exit. This takes real
programs and damages them, then holds `check` to that:

- **truncation** at a random byte offset (a file cut off mid-typing),
- **deletion** of a few bytes (a closing brace or quote lost),
- **insertion** of a stray bracket, quote, interpolation opener or backslash.

Two shapes, because an editor does both:

- a file checked on its own (`tests/`, `std/`), and
- one module of a larger program checked through the program with `--overlay`
  (`src/`), which is how the IDE protocol checks a file (IDE_PROTOCOL.md).

A variant passes when `check`

- exits 0 or 1 (a signal, 2, or a timeout is a crash or a hang),
- printed a `summary` JSON line (the "I am done" signal a client waits for),
- exits 1 only if it reported at least one error (a silent failure is the worst
  kind: the editor shows nothing wrong), and
- printed no `internal error`.

The count of variants that produced at least one error is asserted too: a mutator
that stops damaging anything would pass every check above, so a run in which fewer
than a third of the variants were rejected fails as vacuous.

    python3 tools/check_truncation.py --compiler .prismio/build/debug/p0
    python3 tools/check_truncation.py --compiler .prismio/build/debug/p0 --partial

`--partial` is the harder run: type checking then goes on over a program the parser could
only partly read, which is the shape an editor's index is built from.

The compiler must not be named `prismio` (the launcher forwards a binary with that
name to the project host), and it needs its toolchain layout beside it. `--seed`
makes a failure reproducible; each failing variant is written under `--out` with
the command that reproduces it.
"""
import argparse
import json
import os
import random
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

INSERTIONS = ["{", "}", "(", ")", "[", "]", '"', "'", '"""', "${", "\\", "`", "@", "é", "\xff"]


def mutate(rng, data):
    """One damaged copy of `data` (bytes), and a label for the report."""
    if not data:
        return data, "empty"
    kind = rng.choice(["truncate", "truncate", "delete", "insert"])
    at = rng.randrange(len(data))
    if kind == "truncate":
        return data[:at], f"truncate@{at}"
    if kind == "delete":
        width = rng.randint(1, 8)
        return data[:at] + data[at + width:], f"delete@{at}+{width}"
    piece = rng.choice(INSERTIONS)
    piece = piece.encode("latin-1") if piece == "\xff" else piece.encode("utf-8")
    return data[:at] + piece + data[at:], f"insert@{at}:{piece!r}"


def run(compiler, args, cwd, timeout):
    env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
    try:
        done = subprocess.run([compiler, "check", *args], cwd=cwd, env=env, timeout=timeout,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.TimeoutExpired:
        return None, "", "timeout"
    return done.returncode, done.stderr.decode("utf-8", "replace"), ""


def judge(code, stderr, failure):
    """Why a run failed, or "" when it held to the contract. Also the error count, and
    whether type checking reported something besides syntax errors (it ran past them)."""
    if failure:
        return failure, 0, False
    if code not in (0, 1):
        return f"exit status {code}", 0, False
    if "internal error" in stderr:
        return "internal error", 0, False
    summary = None
    errors = 0
    areas = set()
    for line in stderr.splitlines():
        if not line.startswith("{"):
            continue
        try:
            record = json.loads(line)
        except ValueError:
            return "unparseable JSON line", 0, False
        if record.get("kind") == "summary":
            summary = record
        if record.get("kind") == "diagnostic" and record.get("severity") == "error":
            errors += 1
            areas.add(str(record.get("code", ""))[:2])
    past = "P4" in areas and bool(areas & {"P1", "P2", "P3"})
    if summary is None:
        return "no summary line", errors, past
    if code == 1 and errors == 0:
        return "exit 1 with no error reported", errors, past
    return "", errors, past


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("--compiler", required=True, help="compiler under test (not named prismio)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--per-file", type=int, default=6, help="variants of each standalone file")
    ap.add_argument("--per-module", type=int, default=6, help="variants of each src/ module")
    ap.add_argument("--timeout", type=float, default=60.0)
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--partial", action="store_true",
                    help="check with --partial, so type checking runs over what parsed")
    ap.add_argument("--limit", type=int, default=0, help="only the first N files of each set (a smoke run)")
    ap.add_argument("--out", default="", help="where failing variants are written")
    opts = ap.parse_args()

    compiler = str(Path(opts.compiler).resolve())
    rng = random.Random(opts.seed)
    out = Path(opts.out) if opts.out else Path(tempfile.mkdtemp(prefix="truncation-"))
    out.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="truncation-work-"))

    standalone = sorted(list((ROOT / "tests").glob("*.psm")) + list((ROOT / "std").glob("*.psm")))
    modules = sorted(p for p in (ROOT / "src").rglob("*.psm") if p.name != "main.psm")
    if opts.limit:
        standalone, modules = standalone[:opts.limit], modules[:opts.limit]

    extra = ["--partial"] if opts.partial else []
    jobs = []  # (label, file, args, cwd)
    for index, source in enumerate(standalone):
        data = source.read_bytes()
        for n in range(opts.per_file):
            damaged, how = mutate(rng, data)
            path = work / f"s{index}_{n}_{source.name}"
            path.write_bytes(damaged)
            jobs.append((f"{source.relative_to(ROOT)} {how}", path,
                         [str(path), "--diagnostic-format=json", *extra], str(ROOT)))
    entry = ROOT / "src" / "main.psm"
    for index, source in enumerate(modules):
        data = source.read_bytes()
        for n in range(opts.per_module):
            damaged, how = mutate(rng, data)
            path = work / f"m{index}_{n}.psm"
            path.write_bytes(damaged)
            jobs.append((f"{source.relative_to(ROOT)} {how}", path,
                         [str(entry), "--diagnostic-format=json", *extra, "--overlay", str(source), str(path)],
                         str(ROOT)))

    def one(job):
        label, path, args, cwd = job
        code, stderr, failure = run(compiler, args, cwd, opts.timeout)
        why, errors, past = judge(code, stderr, failure)
        return label, path, args, why, errors, past

    failures = []
    rejected = 0
    ran_past = 0
    with ThreadPoolExecutor(max_workers=opts.jobs) as pool:
        for label, path, args, why, errors, past in pool.map(one, jobs):
            if errors > 0:
                rejected += 1
            if past:
                ran_past += 1
            if why:
                keep = out / path.name
                keep.write_bytes(path.read_bytes())
                failures.append((label, why, keep, args))

    total = len(jobs)
    print(f"{total} variants ({len(standalone)} standalone files, {len(modules)} overlaid modules), "
          f"{rejected} rejected with an error, {ran_past} type-checked past a syntax error, "
          f"{len(failures)} failed")
    for label, why, keep, args in failures[:40]:
        print(f"FAIL {label}: {why}")
        print(f"     kept {keep}")
    if total == 0 or rejected * 3 < total:
        print("VACUOUS: fewer than a third of the variants were rejected, so the mutator is not "
              "damaging anything and the result proves nothing")
        return 2
    if opts.partial and ran_past == 0:
        print("VACUOUS: --partial never type-checked past a syntax error, so it exercised nothing new")
        return 2
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
