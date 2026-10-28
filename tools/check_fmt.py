#!/usr/bin/env python3
"""Check `prismio fmt` against every Prismio source in the repository.

A formatter that changes the program is worse than none, and one that does not settle
(`fmt` of `fmt` differs) fights the editor that runs it on save. Over every `.psm` file
under the repository (and over damaged copies of them, which is what an editor feeds it
while the user types) this holds `fmt` to:

- **it finishes**: exit 0, no crash, no timeout, a result on every input,
- **only whitespace moves**: deleting all whitespace gives the same text before and after,
- **it settles**: formatting the result changes nothing,
- **the program is the same**: a sample of the `tests/` programs is compiled before and
  after, and the IR must be byte for byte the same. The one exception is a formatter that
  moves lines (it splits an `if` that has an `else`): a program quotes its own source
  positions in a few places, and those are compared with the positions masked
  (`mask_positions`) once some file has really moved.

It also reports how many lines it would change in each top-level directory. The repository is
written in the style the formatter encodes, so the share is small; `--max-changed-percent`
fails a run in which the formatter has started to disagree with the code around it.

    python3 tools/check_fmt.py --compiler .prismio/build/debug/p0

The compiler must not be named `prismio` (the launcher forwards a binary with that name to
the project host).
"""
import argparse
import difflib
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIRS = ["src", "std", "lsp", "ums", "tests", "benchmarks", "docs", "tools", "sandbox"]


def run_fmt(compiler, args, data=None, timeout=60):
    env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
    return subprocess.run([compiler, "fmt", *args], input=data, capture_output=True, env=env, timeout=timeout)


def squeeze(text):
    return re.sub(rb"\s+", b"", text)


def check_file(compiler, path):
    """Problems with one file, as strings; and the number of lines the formatter changes."""
    original = path.read_bytes()
    problems = []
    try:
        first = run_fmt(compiler, ["--stdin"], original)
    except subprocess.TimeoutExpired:
        return [f"{path}: fmt did not finish"], 0
    if first.returncode != 0:
        return [f"{path}: fmt exited {first.returncode}: {first.stderr[:200]!r}"], 0
    formatted = first.stdout
    if squeeze(original) != squeeze(formatted):
        problems.append(f"{path}: fmt changed more than whitespace")
    again = run_fmt(compiler, ["--stdin"], formatted)
    if again.stdout != formatted:
        problems.append(f"{path}: fmt does not settle (formatting its own output changes it)")
    before = original.decode("utf-8", "replace").splitlines()
    after = formatted.decode("utf-8", "replace").splitlines()
    matcher = difflib.SequenceMatcher(None, before, after, autojunk=False)
    changed = sum(max(i2 - i1, j2 - j1) for tag, i1, i2, j1, j2 in matcher.get_opcodes() if tag != "equal")
    return problems, changed


def damage(rng, data):
    """A damaged copy of `data`: cut, bytes deleted, or a stray character inserted."""
    if not data:
        return data
    kind = rng.choice(["cut", "delete", "insert"])
    at = rng.randrange(len(data))
    if kind == "cut":
        return data[:at]
    if kind == "delete":
        return data[:at] + data[at + rng.randint(1, 4):]
    return data[:at] + rng.choice([b"{", b"}", b"(", b")", b'"', b"'", b'"""', b"${", b"/*", b"\\", b"<", b">"]) + data[at:]


def check_damaged(compiler, files, count, seed):
    rng = random.Random(seed)
    problems = []
    for _ in range(count):
        path = rng.choice(files)
        data = damage(rng, path.read_bytes())
        try:
            result = run_fmt(compiler, ["--stdin"], data)
        except subprocess.TimeoutExpired:
            problems.append(f"{path}: fmt did not finish on a damaged copy")
            continue
        if result.returncode != 0:
            problems.append(f"{path}: fmt failed on a damaged copy ({result.returncode}): {result.stderr[:120]!r}")
        elif squeeze(data) != squeeze(result.stdout):
            problems.append(f"{path}: fmt changed more than whitespace of a damaged copy")
    return problems


# The places a program quotes its own source positions: a synthesized name carries the line and
# column it came from (`$repeat_132_5`), and a `step` check reports its line. A formatter that moves
# a line moves these and nothing else; any other difference in the IR is a changed program.
POSITIONS = (
    (re.compile(rb"(\$[A-Za-z]+)_\d+_\d+"), rb"\1_L_C"),
    (re.compile(rb"(@prismio_step_check\([^\n]*, i32 )\d+\)"), rb"\1L)"),
)


def mask_positions(ir):
    for pattern, replacement in POSITIONS:
        ir = pattern.sub(replacement, ir)
    return ir


def ir_of(compiler, cwd, relative, out):
    """The IR of `relative`, built from `cwd` so the path the program carries into its IR
    (a panic names its file) is the same for both copies."""
    env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
    result = subprocess.run([compiler, "build", relative, "-o", str(out)], capture_output=True, env=env,
                            cwd=cwd, timeout=300)
    return out.read_bytes() if result.returncode == 0 and out.exists() else None


def check_ir(compiler, count, seed):
    """Compile `count` programs from tests/ as they are and formatted; the IR must not differ."""
    rng = random.Random(seed)
    programs = sorted(p.name for p in (ROOT / "tests").glob("test_*.psm"))
    rng.shuffle(programs)
    problems = []
    compared = 0
    with tempfile.TemporaryDirectory(prefix="prismio-fmt-ir-") as tmp:
        plain_root = Path(tmp) / "plain"
        formatted_root = Path(tmp) / "formatted"
        for root in (plain_root, formatted_root):
            shutil.copytree(ROOT / "tests", root / "tests", ignore=shutil.ignore_patterns("*.py", "__pycache__"))
        moved = False
        for source in (formatted_root / "tests").rglob("*.psm"):
            source.write_bytes(run_fmt(compiler, [str(source)]).stdout)
            original = plain_root / source.relative_to(formatted_root)
            if original.read_bytes().count(b"\n") != source.read_bytes().count(b"\n"):
                moved = True
        for name in programs:
            if compared >= count:
                break
            relative = f"tests/{name}"
            plain = ir_of(compiler, plain_root, relative, Path(tmp) / "plain.ll")
            if plain is None:
                continue
            formatted = ir_of(compiler, formatted_root, relative, Path(tmp) / "formatted.ll")
            compared += 1
            if formatted is None:
                problems.append(f"{relative}: the formatted program no longer builds")
            elif plain != formatted and not (moved and mask_positions(plain) == mask_positions(formatted)):
                problems.append(f"{relative}: formatting changed the generated IR")
    if compared == 0:
        problems.append("no program was compared: the IR check is vacuous")
    return problems, compared


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--damaged", type=int, default=300, help="damaged copies to try (default 300)")
    parser.add_argument("--ir", type=int, default=12, help="programs whose IR is compared (default 12)")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--max-changed-percent", type=float, default=2.0)
    args = parser.parse_args()
    compiler = str(Path(args.compiler).resolve())
    if Path(compiler).name == "prismio":
        print("the compiler must not be named `prismio`", file=sys.stderr)
        return 2

    files = sorted(p for d in SOURCE_DIRS for p in (ROOT / d).rglob("*.psm"))
    if len(files) < 200:
        print(f"only {len(files)} sources found: the check is vacuous", file=sys.stderr)
        return 1

    problems = []
    lines = {}
    changed = {}
    with ThreadPoolExecutor(max_workers=8) as pool:
        for path, (found, count) in zip(files, pool.map(lambda p: check_file(compiler, p), files)):
            problems += found
            top = path.relative_to(ROOT).parts[0]
            lines[top] = lines.get(top, 0) + len(path.read_text(errors="replace").splitlines())
            changed[top] = changed.get(top, 0) + count

    problems += check_damaged(compiler, files, args.damaged, args.seed)
    ir_problems, compared = check_ir(compiler, args.ir, args.seed)
    problems += ir_problems

    total = sum(lines.values())
    share = 100.0 * sum(changed.values()) / max(total, 1)
    for top in sorted(lines):
        print(f"  {top:11} {lines[top]:7} lines, {changed[top]:5} would change ({100.0 * changed[top] / max(lines[top], 1):.1f}%)")
    print(f"{len(files)} files, {args.damaged} damaged copies, {compared} programs compared by IR; "
          f"{share:.2f}% of lines would change")
    if share > args.max_changed_percent:
        problems.append(f"fmt would change {share:.1f}% of the repository's lines (limit {args.max_changed_percent}%)")
    for problem in problems[:40]:
        print(f"FAIL {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
