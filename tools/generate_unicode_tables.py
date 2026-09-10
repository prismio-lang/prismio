#!/usr/bin/env python3
"""Generate std/unicode_tables.psm from Python's bundled Unicode database.

    python3 tools/generate_unicode_tables.py

**The tables are generated, never edited.** A hand-maintained range list for
East Asian width or combining marks is wrong the day it is written and wronger
every year after; this reads the properties from `unicodedata`, which ships with
CPython and carries a version number the output records.

Each table is a string of fixed-width hex, six digits per bound and twelve per
range, sorted by start. `std/unicode.psm` binary-searches it: no allocation, no
array literal of a thousand elements, and a literal the compiler can put in
.rodata.

The properties, and what each is for:

  wide       East_Asian_Width in {W, F} -- two terminal columns.
  zero       Mn, Me (nonspacing and enclosing marks), Cf (format characters),
             Cc (controls) and the line/paragraph separators -- no columns.
  extend     Mn, Me, Mc -- what continues a grapheme cluster rather than
             starting one. Mc is *spacing*, so it is one column wide and still
             extends: the two tables are not the same set, which is why they are
             generated separately.
"""

import sys
import unicodedata

MAX_SCALAR = 0x110000


def ranges(predicate):
    out = []
    start = None
    for cp in range(MAX_SCALAR):
        if 0xD800 <= cp <= 0xDFFF:  # surrogates are not scalars
            hit = False
        else:
            hit = predicate(cp)
        if hit and start is None:
            start = cp
        elif not hit and start is not None:
            out.append((start, cp - 1))
            start = None
    if start is not None:
        out.append((start, MAX_SCALAR - 1))
    return out


def is_wide(cp):
    return unicodedata.east_asian_width(chr(cp)) in ("W", "F")


def is_zero(cp):
    category = unicodedata.category(chr(cp))
    if category in ("Mn", "Me", "Cf"):
        return True
    if category == "Cc":
        return True
    if category in ("Zl", "Zp"):
        return True
    return False


def is_extend(cp):
    return unicodedata.category(chr(cp)) in ("Mn", "Me", "Mc")


def encode(rs):
    return "".join(f"{lo:06X}{hi:06X}" for lo, hi in rs)


def emit(name, description, rs, out):
    text = encode(rs)
    out.append(f"// {description}")
    out.append(f"// {len(rs)} range(s), {len(text)} bytes.")
    out.append(f"fn {name}() -> String {{")
    # One long literal: the compiler puts it in .rodata and every lookup is an
    # index into it.
    out.append(f'    return "{text}"')
    out.append("}")
    out.append("")


# Hangul composes and decomposes by arithmetic, so it is in no table.
HANGUL_SBASE = 0xAC00
HANGUL_SCOUNT = 11172


def canonical_decomposition(cp):
    """The full canonical decomposition of one scalar, or None."""
    if HANGUL_SBASE <= cp < HANGUL_SBASE + HANGUL_SCOUNT:
        return None
    raw = unicodedata.decomposition(chr(cp))
    if not raw or raw.startswith("<"):
        return None
    # Expanded here rather than in the library: a recursive lookup at run time
    # would repeat work this can do once, and the depth is bounded but not
    # obviously so to a reader.
    out = []
    for part in raw.split():
        part_cp = int(part, 16)
        nested = canonical_decomposition(part_cp)
        out.extend(nested if nested else [part_cp])
    return out


def combining_ranges():
    """(first, last, class) for every run of equal nonzero combining class."""
    out = []
    start = None
    current = 0
    for cp in range(MAX_SCALAR):
        klass = 0 if 0xD800 <= cp <= 0xDFFF else unicodedata.combining(chr(cp))
        if klass != current:
            if start is not None:
                out.append((start, cp - 1, current))
            start = cp if klass else None
            current = klass
    if start is not None:
        out.append((start, MAX_SCALAR - 1, current))
    return out


def compositions():
    """(first, second) -> composed, taken from Python's own normalizer.

    Deriving it this way rather than from a copy of CompositionExclusions.txt is
    the point: a pair composes exactly when NFC says it does, so singletons,
    non-starter decompositions and every script-specific exclusion are already
    accounted for and cannot drift from a list somebody has to maintain.
    """
    out = {}
    for cp in range(MAX_SCALAR):
        if 0xD800 <= cp <= 0xDFFF:
            continue
        raw = unicodedata.decomposition(chr(cp))
        if not raw or raw.startswith("<"):
            continue
        parts = raw.split()
        if len(parts) != 2:
            continue
        a, b = int(parts[0], 16), int(parts[1], 16)
        if unicodedata.normalize("NFC", chr(a) + chr(b)) == chr(cp):
            out[(a, b)] = cp
    return out


def emit_decompositions(out):
    entries = []
    for cp in range(MAX_SCALAR):
        if 0xD800 <= cp <= 0xDFFF:
            continue
        parts = canonical_decomposition(cp)
        if parts:
            entries.append((cp, parts))
    widest = max(len(p) for _, p in entries)
    text = "".join(
        f"{cp:06X}{len(parts):02X}" + "".join(f"{p:06X}" for p in parts)
        + "000000" * (widest - len(parts))
        for cp, parts in entries)
    stride = 8 + 6 * widest
    out.append("// Canonical decomposition, fully expanded: one lookup per scalar rather")
    out.append("// than a recursive walk. Each entry is six hex digits of source, two of")
    out.append(f"// length, then {widest} slots of six -- {stride} per entry, unused slots zero.")
    out.append(f"// {len(entries)} entries, {len(text)} bytes.")
    out.append("fn unicodeDecompositionStride() -> Int {")
    out.append(f"    return {stride}")
    out.append("}")
    out.append("")
    out.append("fn unicodeDecompositionTable() -> String {")
    out.append(f'    return "{text}"')
    out.append("}")
    out.append("")
    return len(entries)


def emit_combining(out):
    rs = combining_ranges()
    text = "".join(f"{lo:06X}{hi:06X}{k:02X}" for lo, hi, k in rs)
    out.append("// Canonical combining class, as runs of equal value: six hex digits of")
    out.append("// first scalar, six of last, two of class. Canonical ordering is a stable")
    out.append("// sort on this, and it is what makes NFD a normal *form* rather than one")
    out.append("// of several spellings of the same decomposition.")
    out.append(f"// {len(rs)} range(s), {len(text)} bytes.")
    out.append("fn unicodeCombiningTable() -> String {")
    out.append(f'    return "{text}"')
    out.append("}")
    out.append("")
    return len(rs)


def emit_compositions(out):
    pairs = compositions()
    keys = sorted(pairs)
    text = "".join(f"{a:06X}{b:06X}{pairs[(a, b)]:06X}" for a, b in keys)
    out.append("// Primary composites: first, second, composed -- eighteen hex digits each,")
    out.append("// sorted by the pair so a lookup is a binary search. Derived from NFC")
    out.append("// itself, so exclusions and singletons are already absent.")
    out.append(f"// {len(keys)} pair(s), {len(text)} bytes.")
    out.append("fn unicodeCompositionTable() -> String {")
    out.append(f'    return "{text}"')
    out.append("}")
    out.append("")
    return len(keys)


def main():
    wide = ranges(is_wide)
    zero = ranges(is_zero)
    extend = ranges(is_extend)

    out = [
        "// Unicode range tables. **Generated -- do not edit.**",
        "//",
        "//     python3 tools/generate_unicode_tables.py",
        "//",
        f"// Unicode {unicodedata.unidata_version}, from the database bundled with the CPython that",
        "// ran the generator. Each range is twelve hex digits: six for the first",
        "// scalar and six for the last, sorted by the first, which is what lets",
        "// std/unicode.psm binary-search a table without decoding it.",
        "//",
        "// Public rather than `internal`: `internal` is package-scoped and a",
        "// standard-library module is its own package, so std.unicode could not see",
        "// these otherwise. The `unicode` prefix is what keeps them out of the way.",
        "",
        "import std.string",
        "",
    ]
    emit("unicodeWideTable",
         "East_Asian_Width W or F: two terminal columns.", wide, out)
    emit("unicodeZeroTable",
         "Nonspacing and enclosing marks, format characters, controls and the",
         zero, out)
    emit("unicodeExtendTable",
         "What continues a grapheme cluster: Mn, Me and Mc. Mc is one column",
         extend, out)
    decomp_count = emit_decompositions(out)
    combining_count = emit_combining(out)
    composition_count = emit_compositions(out)

    text = "\n".join(out)
    with open("std/unicode_tables.psm", "w", encoding="utf-8") as handle:
        handle.write(text)
    print(f"wrote std/unicode_tables.psm "
          f"(wide {len(wide)}, zero {len(zero)}, extend {len(extend)} ranges; "
          f"{decomp_count} decompositions, {combining_count} combining runs, "
          f"{composition_count} composites; Unicode {unicodedata.unidata_version})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
