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
reported per site by `--why` since 2026-08-16 and **placed** since 2026-08-16
(second session). Read the two together, and read them in that order:

  * `SERVED` in the first table is every site an arena reaches, by either route.
  * `BRACKETED` in the second is how many *calls* were placed, and `br_served`
    how many sites that moved. Those sites are in SERVED and are therefore *not*
    in `blocked`, so they are not in `PLACEABLE` either.
  * `PLACEABLE` is what is still blocked and could be bracketed but is not --
    after the placement pass, that is the residue rather than the opportunity.
    It reads 0 across this corpus, and that is the *success* condition: the two
    sites it counted before are the two that are now served.

A count that lives on two surfaces is checked on both: `--summary` derives
`bracketed` from the call graph and the manifest prints one line per bracket. The
census fails if they disagree, which is what stops a reworded report from taking
a column silently to zero.
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
    """(records, brackets), or (None, 0) if the program does not build.

    `records` is (symbol, tier, placement) per line; `brackets` is how many calls
    SPEC 5.2.1.1 says the manifest has to record, counted off the section it
    requires.
    """
    r = subprocess.run([cc, "aif", path], capture_output=True, text=True)
    if r.returncode != 0:
        return None, 0
    out = []
    brackets = 0
    in_brackets = False
    for line in r.stdout.splitlines():
        if "bracketed calls (SPEC 5.2.1.1 regime (a))" in line:
            in_brackets = True
            continue
        if in_brackets:
            if line.startswith("#   "):
                brackets += 1
                continue
            in_brackets = False
        parts = line.split()
        if len(parts) >= 3 and "#" in parts[0] and not line.startswith("#"):
            out.append((parts[0], parts[1], parts[2]))
    return out, brackets


def summary_brackets(cc, path):
    """`--summary`'s own count of placed calls and served sites.

    A second, independent derivation of the manifest's section above: this one
    walks the call graph, that one prints the recorded decisions. Compared rather
    than trusted, because a single-surface count goes quietly to zero when the
    wording it is matched on moves -- which is the failure this whole file exists
    to make impossible, one level up.
    """
    r = subprocess.run([cc, "aif", path, "--summary"], capture_output=True, text=True)
    m = re.search(r"^bracketed\s+(\d+)\s+call site\(s\) placed; (\d+) site", r.stdout, re.M)
    return (int(m.group(1)), int(m.group(2))) if m else (-1, -1)


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
    disagreed = []
    for path in programs():
        records, manifest_brackets = manifest_symbols(cc, path)
        if records is None:
            continue                      # a module with no main(); g6_engine is one
        counts = collections.Counter()
        placed, br_served = summary_brackets(cc, path)
        if placed != manifest_brackets:
            disagreed.append((os.path.relpath(path, REPO), placed, manifest_brackets))
        counts["BRACKETED"] = placed
        counts["br_served"] = br_served
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
    table(["BRACKETED", "br_served", "PLACEABLE", "in_region"] + [n for n, _ in BRACKET],
          "# what call-site bracketing reached, and what is left (SPEC 5.2.1.1)")

    served, blocked = totals["SERVED"], totals["blocked"]
    print(f"\n{served} of {served + blocked} sites are arena-served, "
          f"{totals['br_served']} of them by a bracketed call.")
    print(f"{totals['no_region']} of {blocked} blocked sites have no region in their own "
          f"function (SPEC 5.2.1) --")
    print("that clause is what an escape-lattice change does not move.")
    print(f"\n{totals['BRACKETED']} call site(s) were bracketed (SPEC 5.2.1.1 regime (a)). "
          f"Both halves are")
    print("needed and the second is the one that is usually zero: a function that clears")
    print("every obligation is never placed if nothing calls it from a region, and every")
    print("corpus program that does not say `region` has none.")
    print("")
    print(f"PLACEABLE is the residue, not the opportunity: {totals['PLACEABLE']} site(s) are "
          f"still blocked")
    print("*and* in a function a region could bracket. A site that was placed is served, so")
    print("it left the blocked column and this one -- which is why 0 here beside a non-zero")
    print("br_served is the success condition and 0 beside 0 is a corpus with no `region`.")

    if totals["no_region"] and not totals["_saw_bracketing"]:
        print("\nERROR: not one `--why` printed a bracketing verdict, on a run with "
              f"{totals['no_region']} sites")
        print("that must each have one. The section's wording has moved and every "
              "BRACKET substring")
        print("above is now matching nothing -- the columns are zero for the wrong reason.")
        return 1
    if disagreed:
        print("\nERROR: `--summary` and the manifest disagree about how many calls were")
        print("bracketed. They are two derivations of one decision -- the call graph and")
        print("the recorded placements -- so a difference is a reporting defect in one of")
        print("them, and a census that read only one would have gone quietly to zero.")
        for name, summary_n, manifest_n in disagreed:
            print(f"  {name}: --summary {summary_n}, manifest {manifest_n}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
