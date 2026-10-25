#!/usr/bin/env python3
"""Check `prismio check <entry> --emit-index` against real programs.

The index is only worth anything if what it says is true, and what it says is a position and a
name, which can be checked against the text. For every program given (by default the compilable
programs of `tests/`, the hosted benchmarks, the compiler itself and the language server) this
runs the compiler and holds the index to:

- **it exercised something**: declarations in the user's files, and references (a program that
  indexes nothing would pass every check below),
- **no dangling reference**: every `to` is the id of a declaration the index also wrote,
- **a reference is where it says**: the text at its span is the name of what it points to (a call
  `p.sum()` points at `sum`, a field at the field), so a click lands on what the user sees,
- **a declaration is where it says**: the text at its name span is its name,
- **nothing is unresolved**: the programs compile, so every name in them means something, and
  `unresolved` records are the walker's gaps,
- **ranges are sane**: a declaration's extent contains its name.

    python3 tools/check_index.py --compiler .prismio/build/debug/p0 [program.psm ...]

The compiler must not be named `prismio` (the launcher forwards a binary with that name to the
project host).
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run_index(compiler, entry, out, extra=()):
    env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
    result = subprocess.run([compiler, "check", str(entry), "--emit-index", str(out), *extra],
                            capture_output=True, env=env, timeout=600, cwd=ROOT)
    return result


def span_text(lines_cache, path, line, col, length):
    if path not in lines_cache:
        lines_cache[path] = Path(path).read_bytes().split(b"\n")
    lines = lines_cache[path]
    if line < 1 or line > len(lines):
        return None
    return lines[line - 1][col - 1:col - 1 + length].decode("utf-8", "replace")


def check_index(compiler, entry, tmp, strict_unresolved=True, extra=()):
    """The problems with one program's index, and how many declarations and references it had."""
    out = Path(tmp) / (entry.name + ".idx")
    result = run_index(compiler, entry, out, extra)
    if result.returncode != 0:
        return [f"{entry}: check failed ({result.returncode}): {result.stderr.decode(errors='replace')[:200]}"], 0, 0
    if not out.exists():
        return [f"{entry}: no index written"], 0, 0
    files, decls, refs, unresolved, stats = {}, {}, [], [], None
    for text in out.read_text().splitlines():
        record = json.loads(text)
        kind = record["k"]
        if kind == "file":
            files[record["id"]] = record
        elif kind == "decl":
            decls[record["id"]] = record
        elif kind == "ref":
            refs.append(record)
        elif kind == "unresolved":
            unresolved.append(record)
        elif kind == "stats":
            stats = record
    problems = []
    user_decls = [d for d in decls.values() if d["user"]]
    if not user_decls or not refs:
        problems.append(f"{entry}: the index is empty ({len(user_decls)} declarations, {len(refs)} references)")
    if stats is None:
        problems.append(f"{entry}: no stats line, the index was cut short")
    cache = {}
    for ref in refs:
        path = files[ref["f"]]["path"]
        text = span_text(cache, path, ref["l"], ref["c"], ref["n"])
        if ref["to"] >= 0:
            target = decls.get(ref["to"])
            if target is None:
                problems.append(f"{entry}:{ref['l']}:{ref['c']}: reference to declaration {ref['to']}, which was not written")
                continue
            if text != target["name"] and not (target["kind"] == "import"):
                problems.append(f"{path}:{ref['l']}:{ref['c']}: `{text}` points at `{target['name']}` ({target['kind']})")
        elif text is None or not text:
            problems.append(f"{path}:{ref['l']}:{ref['c']}: a reference with no text under it")
    for decl in decls.values():
        path = files[decl["f"]]["path"]
        if decl["kind"] == "impl" or decl["kind"] == "import":
            continue
        text = span_text(cache, path, decl["l"], decl["c"], decl["n"])
        if text != decl["name"]:
            problems.append(f"{path}:{decl['l']}:{decl['c']}: declaration `{decl['name']}` has `{text}` under its name")
        starts = (decl["sl"], decl["sc"])
        ends = (decl["el"], decl["ec"])
        name = (decl["l"], decl["c"])
        if not (starts <= name <= ends):
            problems.append(f"{path}:{decl['l']}:{decl['c']}: `{decl['name']}`'s extent {starts}-{ends} does not contain its name")
    if strict_unresolved:
        for record in unresolved[:10]:
            path = files[record["f"]]["path"]
            problems.append(f"{path}:{record['l']}:{record['c']}: `{record['name']}` ({record['what']}) is unresolved")
        if len(unresolved) > 10:
            problems.append(f"{entry}: ... and {len(unresolved) - 10} more unresolved")
    return problems, len(user_decls), len(refs)


def default_jobs(include_compiler):
    """(entry, extra arguments) for every program worth indexing: the compilable programs of
    tests/, the hosted benchmarks, the language server, each standard-library module under its
    module name, and the compiler itself (the biggest program there is)."""
    jobs = []
    for pattern in ("tests/test_*.psm", "benchmarks/hosted/prismio/*.psm"):
        jobs += [(p, ()) for p in sorted(ROOT.glob(pattern))]
    jobs.append((ROOT / "lsp" / "main.psm", ()))
    for module in sorted((ROOT / "std").glob("*.psm")):
        jobs.append((module, ("--module", "std." + module.stem)))
    if include_compiler:
        jobs.append((ROOT / "src" / "main.psm", ()))
    return jobs


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--allow-unresolved", action="store_true")
    parser.add_argument("--no-compiler", action="store_true", help="leave out src/main.psm")
    parser.add_argument("programs", nargs="*")
    args = parser.parse_args()
    compiler = str(Path(args.compiler).resolve())
    if Path(compiler).name == "prismio":
        print("the compiler must not be named `prismio`", file=sys.stderr)
        return 2
    programs = [(Path(p).resolve(), ()) for p in args.programs] or default_jobs(not args.no_compiler)
    problems, total_decls, total_refs, indexed = [], 0, 0, 0
    with tempfile.TemporaryDirectory(prefix="prismio-index-") as tmp:
        def one(job):
            program, extra = job
            sub = Path(tmp) / (program.parent.name + "_" + program.stem)
            sub.mkdir(exist_ok=True)
            return check_index(compiler, program, sub, strict_unresolved=not args.allow_unresolved, extra=extra)
        with ThreadPoolExecutor(max_workers=8) as pool:
            for found, decls, refs in pool.map(one, programs):
                problems += found
                if decls:
                    indexed += 1
                total_decls += decls
                total_refs += refs
    print(f"{len(programs)} programs, {indexed} indexed, {total_decls} declarations, {total_refs} references")
    for problem in problems[:60]:
        print("FAIL", problem)
    if len(problems) > 60:
        print(f"... and {len(problems) - 60} more")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
