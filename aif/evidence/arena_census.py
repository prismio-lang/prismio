#!/usr/bin/env python3
"""Which allocation sites reach an arena, and what stops the rest.

    python3 aif/evidence/arena_census.py --compiler build/<gen>

Answers, over every compilable program in aif/corpus and aif/evidence, the
question three consecutive sessions answered wrong from the source: **what would
have to change for `region` to serve anything?**

It reads only shipped compiler surface -- the manifest's `placement` column and
`prismio aif --why`'s placement section -- so it cannot drift from what codegen
does, and anyone can re-derive the numbers in RESULTS-arena.md in one command.
The 2026-08-14 session first did this with a getenv-gated fprintf patched into
runtime/aif_support.c, which measured the right thing and left nothing behind.

The column that matters is `no_region`. It is the clause that rejects a site
whose allocation is in a callee, it is on almost every non-served site, and no
change to the escape lattice moves it -- see SPEC 5.2.1.

The second table is what *does* move it: SPEC 5.2.1.1's call-site bracketing,
reported per site by `--why` since 2026-08-16. Read the two together. The first
says what the lexical gate serves today; the second says how much of the
remainder is in a function a caller's region could bracket, and -- separately,
because it is the half that is usually zero -- how much of *that* is actually
called from inside a region.
"""
import argparse
import collections
import glob
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# The blocker phrases `--why` prints, in gate order. Matched on a distinctive
# substring rather than the whole line so rewording the prose does not silently
# zero a column -- if every count comes out 0, that is the thing to check.
BLOCKERS = [
    ("not_t1",       "the tier is not T1"),
    ("no_stack",     "an explicit `drop` frees this value"),
    ("in_container", "a container owns this value"),
    ("is_list",      "a List reallocates its element block"),
    ("no_region",    "in its own function"),
    ("escapes",      "escapes to its caller or to static storage"),
    ("outlives",     "outlives the enclosing region"),
]

# SPEC 5.2.1.1. `no_region` is on every blocked site and says an escape-lattice
# change does not move it; these say what *would*. A site whose function is
# bracketable and whose call sites are inside a region is one call-site placement
# can take -- and that pair is the number, not either half. A function can clear
# every obligation and never be placed because nobody calls it from a region.
#
# Matched on distinctive substrings, like BLOCKERS above: if a whole column comes
# out 0, check that `--why`'s wording still contains these.
BRACKET = [
    ("br_yes",    "yes  -- every obligation holds"),
    ("br_global", "escapes to static storage"),
    ("br_param",  "stores into a container or field it did not allocate"),
    ("br_opaque", "no source and no complete FFI contract"),
    ("br_drop",   "inside the extent frees one of its allocations"),
    ("br_shared", "would serve two placement regimes"),
]


def programs():
    found = sorted(set(
        glob.glob(os.path.join(REPO, "aif", "corpus", "*.psm")) +
        glob.glob(os.path.join(REPO, "aif", "evidence", "xlang", "prismio", "*.psm"))
    ))
    return found


def manifest_symbols(cc, path):
    """(symbol, tier, placement) per record, or None if the program does not build."""
    r = subprocess.run([cc, "aif", path], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    out = []
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3 and "#" in parts[0] and not line.startswith("#"):
            out.append((parts[0], parts[1], parts[2]))
    return out


def blockers_for(cc, path, symbol):
    r = subprocess.run([cc, "aif", path, f"--why={symbol}"],
                       capture_output=True, text=True)
    text = r.stdout
    # Only the placement section; the minimal-cause section above it can mention
    # the same words for a different reason.
    at = text.find("  placement")
    if at < 0:
        return set()
    section = text[at:]
    end = section.find("  repairs")
    if end >= 0:
        section = section[:end]
    found = {name for name, phrase in BLOCKERS if phrase in section}
    found |= {name for name, phrase in BRACKET if phrase in section}
    # Every no_region site gets a bracketing verdict, so seeing the header at
    # least once is what separates "all zero because nothing qualifies" from
    # "all zero because the wording moved and every substring stopped matching".
    # The second is the failure this whole file exists to make impossible, one
    # level up, and a census that cannot tell them apart is a check that cannot
    # fail.
    if "bracketing (SPEC 5.2.1.1)" in section:
        found.add("_saw_bracketing")
    # "N of M call sites lie inside a region", with N > 0. The zero case prints a
    # trailing clause, so matching on the absence of that is enough and does not
    # need the number parsed out.
    m = re.search(r"callers\s+(\d+) of (\d+) call sites", section)
    if m and int(m.group(1)) > 0:
        found.add("in_region")
        if "br_yes" in found:
            found.add("PLACEABLE")
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", default=os.path.join(REPO, "build", "gen2"))
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    cc = os.path.abspath(args.compiler)
    if not os.path.exists(cc):
        sys.exit(f"no prismio compiler at {cc} -- pass --compiler")

    totals = collections.Counter()
    rows = []
    for path in programs():
        records = manifest_symbols(cc, path)
        if records is None:
            continue                      # a module with no main(); g6_engine is one
        counts = collections.Counter()
        for symbol, _tier, placement in records:
            if placement.startswith("region:") and placement != "region:none":
                counts["SERVED"] += 1
                continue
            counts["blocked"] += 1
            for name in blockers_for(cc, path, symbol):
                counts[name] += 1
        rows.append((os.path.relpath(path, REPO), counts))
        totals.update(counts)
        if args.verbose:
            print(f"  {os.path.basename(path):26} {dict(counts)}")

    width = max(len(r[0]) for r in rows) + 2

    def table(cols, title):
        print(f"\n{title}")
        print(f"{'program':{width}}" + "".join(f"{c:>14}" for c in cols))
        for name, counts in rows:
            print(f"{name:{width}}" + "".join(f"{counts.get(c, 0):>14}" for c in cols))
        print(f"{'TOTAL':{width}}" + "".join(f"{totals.get(c, 0):>14}" for c in cols))

    table(["SERVED", "blocked"] + [n for n, _ in BLOCKERS],
          "# what the lexical gate serves, and what stops the rest (SPEC 5.2.1)")
    table(["PLACEABLE", "in_region"] + [n for n, _ in BRACKET],
          "# what call-site bracketing could reach (SPEC 5.2.1.1)")

    served, blocked = totals["SERVED"], totals["blocked"]
    print(f"\n{served} of {served + blocked} sites are arena-served.")
    print(f"{totals['no_region']} of {blocked} blocked sites have no region in their own "
          f"function (SPEC 5.2.1) --")
    print("that clause is what an escape-lattice change does not move.")
    print(f"\n{totals['br_yes']} of those sites are in a function a caller's region MAY bracket,")
    print(f"and {totals['PLACEABLE']} of them are also called from inside one. Both halves are "
          f"needed: a")
    print("function that clears every obligation is never placed if nothing calls it")
    print("from a region, and every corpus program that does not say `region` has 0.")
    print("")
    print("PLACEABLE is an upper bound and not a prediction. It says the *call* may be")
    print("bracketed; whether the site is then served still depends on the per-site")
    print("clauses in the first table -- `in_container` and `is_list` reject a value the")
    print("deallocator would take, and clearing those for a bracketed extent is the")
    print("disposition half (SPEC 5.2.1.1), which is a separate change from bracketing.")

    if totals["no_region"] and not totals["_saw_bracketing"]:
        print("\nERROR: not one `--why` printed a bracketing verdict, on a run with "
              f"{totals['no_region']} sites")
        print("that must each have one. The section's wording has moved and every "
              "BRACKET substring")
        print("above is now matching nothing -- the columns are zero for the wrong reason.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
