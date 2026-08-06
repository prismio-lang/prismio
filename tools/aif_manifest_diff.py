#!/usr/bin/env python3
"""Diff two AIF manifests and gate on tier regressions (SPEC 6.3).

    python tools/aif_manifest_diff.py OLD.manifest NEW.manifest

Exits non-zero when any record's tier rose, which SPEC 6.3 makes the default
gate: "Any tier increase ... SHALL be treated as a regression by the default
gate." A tier is a cost ranking, so rising means the same program now needs more
runtime bookkeeping than it did -- and without something watching, that happens
quietly, one FFI declaration at a time.

**This is the half of 6.3 that does not need the derivation DAG.** The section
also requires a *minimal cause* per changed record -- the backward walk through
maximal contributors that says which rule fired where -- and ranked repairs.
Both need the derivation retained through tier assignment, which the solver in
runtime/aif_support.c does not do: it keeps the current value of each fact, not
what produced it. Adding that is the real cost 6.3 names, and it is not here.
What is here tells you *that* a record regressed and by how much, which is what a
gate needs; understanding *why* still means reading the two manifests.

Generate the inputs with `prismio aif <source>`; any two manifests over the same
source are comparable.
"""
import argparse
import re
import sys
from pathlib import Path

TIER_ORDER = {"T0": 0, "T1": 1, "T2": 2, "T3": 3, "T4b": 4}

# `symbol tier placement type layout origin site`, with the site last because a
# path may contain spaces and nothing else may.
RECORD = re.compile(
    r"^(\S+)\s+(T0|T1|T2|T3|T4b)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$")


class Record:
    __slots__ = ("symbol", "tier", "placement", "type", "layout", "origin", "site")

    def __init__(self, m):
        (self.symbol, self.tier, self.placement, self.type,
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old")
    ap.add_argument("new")
    ap.add_argument("--allow-regressions", action="store_true",
                    help="report regressions but exit 0 -- for recording a "
                         "deliberate trade rather than gating on it")
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
        if delta > 0:
            regressions.append((sym, old_rec, new_rec))
        elif delta < 0:
            improvements.append((sym, old_rec, new_rec))

    added = sorted(set(new) - set(old))
    removed = sorted(set(old) - set(new))

    for sym, o, n in regressions:
        print(f"{sym}   {o.tier} -> {n.tier}   REGRESSION")
        print(f"    placement  {o.placement} -> {n.placement}")
        if o.origin != n.origin:
            print(f"    origin     {o.origin} -> {n.origin}")
        print(f"    at         {n.site}")
    if regressions and (improvements or added or removed):
        print()

    for sym, o, n in improvements:
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
