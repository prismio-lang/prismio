#!/usr/bin/env python3
"""Differential test: the in-compiler AIF engine against the Python oracle.

    python tools/aif_differential.py [--compiler build/aif2.exe]

Runs `prismio aif <src> --summary` and `aif/prototype/aif.py <dump>` over the
same sources, under both collection-ownership settings, and compares the tier
distribution and every excluded-site counter.

Why this exists: aif/prototype/aif.py is not throwaway. The two implementations
share no code, so a transfer function that is subtly wrong in one of them shows
up here as a differing count -- and a wrong transfer function otherwise produces
a silently wrong tier rather than a crash, months before anyone notices. AIF's
own README calls this the only reliable defence, and it is only worth anything
while the two are kept in step.

A deliberate divergence between the two is fine and should be recorded at the
site in both files. An accidental one fails this script.
"""
import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROTOTYPE = REPO / "aif" / "prototype" / "aif.py"

# Everything compared. Tier counts are the result; the rest are the exclusions,
# and they are compared too because a site one implementation declines to count
# is exactly the kind of difference that would otherwise hide a real one.
TIERS = ("T0", "T1", "T2", "T3", "T4b")
COUNTERS = ("sites", "opaque-ret", "extern-alloc", "static-ret",
            "literal-strings", "rounds")


def parse_compiler(text):
    out = {}
    m = re.search(r"rounds=(\d+)", text)
    out["rounds"] = int(m.group(1)) if m else -1
    m = re.search(r"^sites\s+(\d+)\s+\(excluded: (\d+)", text, re.M)
    out["sites"] = int(m.group(1)) if m else -1
    out["literal-strings"] = int(m.group(2)) if m else -1
    m = re.search(r"^opaque-ret\s+(\d+)", text, re.M)
    out["opaque-ret"] = int(m.group(1)) if m else -1
    m = re.search(r"^extern-alloc\s+(\d+)", text, re.M)
    out["extern-alloc"] = int(m.group(1)) if m else -1
    m = re.search(r"^static-ret\s+(\d+)", text, re.M)
    out["static-ret"] = int(m.group(1)) if m else -1
    for t in TIERS:
        m = re.search(rf"^\s+{t}\s+(\d+)\s", text, re.M)
        out[t] = int(m.group(1)) if m else -1
    return out


def parse_oracle(text):
    out = {}
    m = re.search(r"rounds=(\d+)", text)
    out["rounds"] = int(m.group(1)) if m else -1
    m = re.search(r"^sites\s+(\d+)\s+\(excluded: (\d+)", text, re.M)
    out["sites"] = int(m.group(1)) if m else -1
    out["literal-strings"] = int(m.group(2)) if m else -1
    m = re.search(r"^opaque-ret\s+(\d+)", text, re.M)
    out["opaque-ret"] = int(m.group(1)) if m else -1
    m = re.search(r"^extern-alloc\s+(\d+)", text, re.M)
    out["extern-alloc"] = int(m.group(1)) if m else -1
    m = re.search(r"^static-ret\s+(\d+)", text, re.M)
    out["static-ret"] = int(m.group(1)) if m else -1
    for t in TIERS:
        m = re.search(rf"^\s+{t}\s+(\d+)\s+\d", text, re.M)
        out[t] = int(m.group(1)) if m else -1
    return out


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, cwd=REPO, **kw)


def compare(compiler, source, owned, dumps):
    # Both implementations default to owned collections as of 2026-08-08, which
    # is what `prismio build` analyses with. The second arm has to *ask* for the
    # pre-Level-4 model now; passing nothing would run the same analysis twice
    # and the pass would agree by construction.
    flags = [] if owned else ["--copyable-collections"]

    # The compiler's Theta_stack is in bytes; the oracle reads a JSON dump with
    # no layout in it and can only count fields. Comparing in fields mode keeps
    # the test aimed at the inference, which is the part that can be silently
    # wrong -- the byte threshold is a documented, deliberate divergence.
    got = run([compiler, "aif", str(source), "--summary", "--theta-fields"] + flags)
    if got.returncode != 0:
        return f"compiler failed on {source}: {got.stderr.strip()[:200]}"

    # The oracle reads a dump from a path, so each source is dumped once and the
    # file kept for the second (owned-collections) pass.
    if source not in dumps:
        d = run([compiler, "dump-ast", str(source)])
        if d.returncode != 0:
            return f"dump-ast failed on {source}: {d.stderr.strip()[:200]}"
        tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False,
                                          encoding="utf-8")
        tmp.write(d.stdout)
        tmp.close()
        dumps[source] = tmp.name

    want = run([sys.executable, str(PROTOTYPE), dumps[source]] + flags)
    if want.returncode != 0:
        return f"oracle failed on {source}: {want.stderr.strip()[:200]}"

    a = parse_compiler(got.stdout)
    b = parse_oracle(want.stdout)

    bad = [k for k in TIERS + COUNTERS if a.get(k) != b.get(k)]
    if bad:
        detail = ", ".join(f"{k}: compiler={a.get(k)} oracle={b.get(k)}" for k in bad)
        return f"{source} (owned={owned}): {detail}"
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", default="build/aif2.exe")
    ap.add_argument("sources", nargs="*")
    args = ap.parse_args()

    # Resolved against the repo, not the caller's directory: the child processes
    # run with cwd=REPO, but Windows resolves the executable itself against the
    # *parent's* cwd, so a relative -Compiler would only work from the root.
    compiler = Path(args.compiler)
    if not compiler.is_absolute():
        compiler = REPO / compiler
    if not compiler.exists():
        print(f"no such compiler: {compiler}")
        return 1
    args.compiler = str(compiler)

    sources = [Path(s) for s in args.sources]
    if not sources:
        sources = [Path("src/main.psm")] + sorted(Path("aif/corpus").glob("*.psm"))
        # No corpus program uses `region`, and a region opens a scope -- so a
        # mismatch in how the two implementations number scopes would be
        # invisible without this, and scope ids are what Region(s) compares.
        sources.append(Path("tests/test_44_aif_region.psm"))
        # Level 4's fixture is the densest source of string and list sites there
        # is, and site_is_move_only is exactly what --owned-collections flips --
        # so this is where the second pass has the most to disagree about.
        sources.append(Path("tests/test_45_aif_affine_collections.psm"))
        # Item 3 put a container's contents behind a field key and made two
        # containers holding one value Shared. Both are edges in the points-to
        # graph rather than tier clauses, so a mismatch shows up as a wrong tier
        # somewhere else entirely -- and no corpus program reads an element back
        # out of one container and pushes it into another.
        sources.append(Path("tests/test_47_aif_containers.psm"))
        sources.append(Path("tests/test_48_aif_shared_elements.psm"))

    dumps = {}
    failures = []
    print(f"AIF differential test -- {args.compiler} vs aif/prototype/aif.py\n")
    for src in sources:
        for owned in (False, True):
            problem = compare(args.compiler, src, owned, dumps)
            tag = "owned" if owned else "as-is"
            if problem:
                failures.append(problem)
                print(f"  DIFFER  {src} [{tag}]")
            else:
                print(f"  agree   {src} [{tag}]")

    print()
    if failures:
        print(f"{len(failures)} disagreement(s):\n")
        for f in failures:
            print(f"  {f}")
        return 1
    print(f"In-compiler engine and oracle agree on all {len(sources)} source(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
