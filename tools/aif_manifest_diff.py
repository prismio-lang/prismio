#!/usr/bin/env python3
"""Diff two AIF manifests and gate on tier regressions (SPEC 6.3).

    python tools/aif_manifest_diff.py OLD.manifest NEW.manifest

Exits non-zero when any record's tier rose, which SPEC 6.3 makes the default
gate: "Any tier increase ... SHALL be treated as a regression by the default
gate." A tier is a cost ranking, so rising means the same program now needs more
runtime bookkeeping than it did -- and without something watching, that happens
quietly, one FFI declaration at a time.

6.3 also requires a *minimal cause* per changed record -- the backward walk
through maximal contributors that says which rule fired where -- and ranked
repairs. Both need the derivation retained through tier assignment, which the
solver now does (INFERENCE 5.6). Pass `--compiler` and each regression is
followed by its witness path and its repairs:

    python tools/aif_manifest_diff.py old.manifest new.manifest \
        --compiler build/prismio.exe

The split is deliberate. This script knows *what* changed, because it has both
manifests; only the compiler knows *why*, because only the solver has the
derivation. Without `--compiler` the gate still works and reports the fact of the
regression, which is what CI needs even where no binary is at hand.

Generate the inputs with `prismio aif <source> --manifest`; any two manifests
over the same source are comparable. The unflagged command is intentionally a
human report rather than this line-oriented protocol.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

# The solver's ordinal order, T4a above T4b -- see AIF_T4A in
# runtime/aif_support.c. A tier missing here is a KeyError on the line that
# decides regressions, not a quiet miss, which is the right failure mode.
TIER_ORDER = {"T0": 0, "T1": 1, "T2": 2, "T3": 3, "T4b": 4, "T4a": 5}

# INFERENCE 2.3. A move up this chain at an unchanged tier is still a
# regression: Transferred -> CrossThread turns a non-atomic count into an
# atomic one, and SPEC 11 item 10 is the promise that does not happen on the
# common path. Tier alone cannot see it -- a T1 site has no count to change
# and a T4a site is already at the top -- which is why the manifest carries
# the fact and why this dict exists.
THREAD_ORDER = {"Isolated": 0, "Transferred": 1, "CrossThread": 2}

# `symbol tier placement type layout origin site`, with the site last because a
# path may contain spaces and nothing else may.
# REQUIREMENTS 15 added the `thread` column and the T4a tier, and both had to
# arrive here in the same commit as in the manifest.
#
# T4a missing from the alternation would have made every cross-thread record
# unparseable, and `parse` ignores what it cannot match -- so the gate would
# have gone quiet on exactly the tier it most needs to notice. That is this
# file's own documented failure mode: see the `layout` column's width comment in
# src/aif/report.psm, where a record running into the next column had already
# cost one silent regression.
RECORD = re.compile(
    r"^(\S+)\s+(T0|T1|T2|T3|T4b|T4a)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$")


class Record:
    __slots__ = ("symbol", "tier", "thread", "placement", "type", "layout",
                 "origin", "site")

    def __init__(self, m):
        (self.symbol, self.tier, self.thread, self.placement, self.type,
         self.layout, self.origin, self.site) = (g.strip() for g in m.groups())


def parse(path):
    """(header key -> value, symbol -> Record). Unparseable lines are ignored:
    the header is key/value and the record table is fixed-shape, so anything
    else is a comment or the blank line between them."""
    header, records = {}, {}
    for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        if not line or line.startswith("#"):
            continue
        m = RECORD.match(line)
        if m:
            r = Record(m)
            records[r.symbol] = r
            continue
        kv = re.match(r"^([a-z-]+)\s{2,}(.*)$", line)
        if kv:
            header[kv.group(1)] = kv.group(2).strip()
    return header, records


def explain(compiler, source, symbol, owned=False):
    """SPEC 6.3's minimal cause for one regressed record, from the compiler.

    The derivation lives in the solver and nowhere else, so the differ asks for
    it rather than reconstructing it: this script knows *what* changed and only
    the compiler knows *why*. Absent a compiler the diff still gates, which is
    the half that matters for CI.
    """
    cmd = [compiler, "aif", str(source)]
    if owned:
        cmd.append("--owned-collections")
    cmd.append(f"--why={symbol}")
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    except (OSError, subprocess.SubprocessError) as exc:
        return f"    (could not run {compiler}: {exc})"
    if out.returncode != 0:
        return f"    (no cause available for {symbol})"
    # Drop the first line: it repeats the symbol and tier the caller just printed.
    body = out.stdout.splitlines()[1:]
    return "\n".join("  " + line for line in body).rstrip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old")
    ap.add_argument("new")
    ap.add_argument("--allow-regressions", action="store_true",
                    help="report regressions but exit 0 -- for recording a "
                         "deliberate trade rather than gating on it")
    ap.add_argument("--compiler",
                    help="a prismio binary. Given one, each regression is "
                         "followed by its minimal cause and ranked repairs "
                         "(SPEC 6.3); without one, only the fact that it "
                         "regressed is reported")
    ap.add_argument("--source",
                    help="the source the new manifest was produced from. "
                         "Required with --compiler; defaults to the `source` "
                         "line in the new manifest")
    ap.add_argument("--owned-collections", dest="owned", action="store_true",
                    help="pass --owned-collections when asking for a cause, so "
                         "the explanation matches the manifest it explains")
    args = ap.parse_args()

    old_head, old = parse(args.old)
    new_head, new = parse(args.new)

    if not old or not new:
        print(f"no records parsed from "
              f"{args.old if not old else args.new} -- is it an aif manifest?")
        return 2

    # Comparing manifests of different sources produces a diff where every record
    # is added or removed, which looks alarming and means nothing.
    if old_head.get("source") and old_head.get("source") != new_head.get("source"):
        print(f"warning: different sources ({old_head['source']} vs "
              f"{new_head.get('source')}) -- the diff below compares by symbol\n")

    regressions, improvements = [], []
    for sym, new_rec in sorted(new.items()):
        old_rec = old.get(sym)
        if old_rec is None:
            continue
        delta = TIER_ORDER[new_rec.tier] - TIER_ORDER[old_rec.tier]
        if delta == 0:
            # Same tier, worse thread affinity. The count the binary emits
            # changed even though the ladder did not move.
            delta = (THREAD_ORDER.get(new_rec.thread, 0)
                     - THREAD_ORDER.get(old_rec.thread, 0))
        if delta > 0:
            regressions.append((sym, old_rec, new_rec))
        elif delta < 0:
            improvements.append((sym, old_rec, new_rec))

    added = sorted(set(new) - set(old))
    removed = sorted(set(old) - set(new))

    cause_source = args.source or new_head.get("source")
    for sym, o, n in regressions:
        print(f"{sym}   {o.tier} -> {n.tier}   REGRESSION")
        if o.thread != n.thread:
            print(f"    thread     {o.thread} -> {n.thread}")
        print(f"    placement  {o.placement} -> {n.placement}")
        if o.origin != n.origin:
            print(f"    origin     {o.origin} -> {n.origin}")
        print(f"    at         {n.site}")
        if args.compiler and cause_source:
            print()
            print(explain(args.compiler, cause_source, sym, args.owned))
        print()
    if regressions and (improvements or added or removed):
        print()

    for sym, o, n in improvements:
        if o.tier == n.tier:
            print(f"{sym}   thread {o.thread} -> {n.thread}")
        else:
            print(f"{sym}   {o.tier} -> {n.tier}")

    if added:
        print(f"\n{len(added)} new site(s): " + ", ".join(added[:8])
              + (" ..." if len(added) > 8 else ""))
    if removed:
        print(f"{len(removed)} site(s) gone: " + ", ".join(removed[:8])
              + (" ..." if len(removed) > 8 else ""))

    print(f"\n{len(regressions)} regression(s), {len(improvements)} improvement(s), "
          f"{len(added)} added, {len(removed)} removed "
          f"(of {len(old)} -> {len(new)} records)")

    if regressions and not args.allow_regressions:
        print("\nFAIL: a tier rose. SPEC 6.3 makes that the default gate -- the "
              "same program now needs more runtime bookkeeping than it did.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
