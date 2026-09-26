#!/usr/bin/env python3
"""Generate Prismio's Unicode tables from the Unicode Character Database.

    python3 tools/generate_unicode_tables.py            # write the tables
    python3 tools/generate_unicode_tables.py --check    # fail if they drifted
    python3 tools/generate_unicode_tables.py --ucd-dir <dir>   # offline

**The version is pinned here, not taken from the machine.** The tables used to
come from Python's `unicodedata`, which is whatever the interpreter was built
with -- Unicode 13.0.0 on the CPython that last ran this, three versions behind,
and that database answered East_Asian_Width `F` for every *unassigned* code
point, so `scalarWidth` said 2 for all of them. Which Unicode a Prismio release
implements is a decision the repository makes once, below, and every output
file records it.

The sources are the official Unicode data files for UNICODE_VERSION -- the UCD
and the UTS #39 security data -- fetched from unicode.org into an ignored cache
(build/unicode/<version>/) and refused unless their SHA-256 matches the pin in
UCD_FILES. Moving to a new Unicode version is
one reviewed diff: the version, the pins, and the regenerated tables.

**The tables are generated, never edited.** Each is a sorted array of scalar
ranges searched by binary search -- a RangeTable, not a map from code point to
property -- written as ordinary array literals so a reviewer can read a diff of
one. Every table has a consumer; a property Unicode defines and nothing in
Prismio asks about is not emitted.

**Except case mapping, because a benchmark asked.** A search per scalar made
`toUpper` on Cyrillic, Greek and accented Latin 5.4x Rust's, so the case tables
are a two-stage table of deltas, ICU's code point trie in miniature: two reads
and no search, 101 KB of source where the four RangeTables were 222 KB. Still
array literals, still readable: a block of 32 scalars' deltas per row.

  std/unicode_tables.psm            std.unicode: display width, grapheme
                                    clusters (UAX #29), normalization (UAX #15)
  std/unicode_case.psm              std.string: toUpper, toLower, capitalize,
                                    equalsIgnoreCase (Unicode 3.13 default case
                                    conversion and full case folding)
  src/lexer/identifier_tables.psm   the lexer: identifiers (UAX #31) and their
                                    security checks (UTS #39)

The UCD's own conformance files (GraphemeBreakTest.txt, NormalizationTest.txt)
are pinned too; tools/unicode_conformance.py runs std.unicode against them.
"""

import argparse
import hashlib
import os
import sys
import urllib.request

UNICODE_VERSION = "18.0.0"
UNICODE_URL = f"https://www.unicode.org/Public/{UNICODE_VERSION}/"

# Path under UNICODE_URL -> SHA-256 of the 18.0.0 release file. The UTS #39
# data sits beside the UCD, in security/, since Unicode 17.
UCD_FILES = {
    "ucd/UnicodeData.txt":
        "0736451de439ae7baf1425136617da495e09ee5afbe6e394374db7009ea08950",
    "ucd/EastAsianWidth.txt":
        "a0cf29eacd00cfcaec4381c6b7c281685f18dbb4e7ff82b4076ccb342ca839aa",
    "ucd/DerivedCoreProperties.txt":
        "09c928886a178fcafd93c29e4bd59073a058e5a100b716d425cb563ab50f68c9",
    "ucd/DerivedNormalizationProps.txt":
        "98ac7f67d985fe781e317f6182e885e94cabb0c314769e6dd73e48b226931ccd",
    "ucd/auxiliary/GraphemeBreakProperty.txt":
        "0839dcb79e4ac639ecd538b1abf7c9d22e3f9dd265b7e182d33627aa4d75b45a",
    "ucd/emoji/emoji-data.txt":
        "80d00f8e616a0ef27fd6b8de3b758c06383b5d917e2977709578e68baf733bf1",
    "ucd/SpecialCasing.txt":
        "8538dea57c184f1ef3783885ea79677b10f6efa06423717157e63712f14d1ad2",
    "ucd/CaseFolding.txt":
        "a004797658a457bec4dc11683e39f69249ea3b595b752dbea6721c4c9f587b0d",
    "security/IdentifierStatus.txt":
        "5863c7d99ca18f213c41c7318aa5528bebfb6d32ec0f1d5944e37192c119aebd",
    "security/confusables.txt":
        "6ed3ee967c9dfdf6677d563c9985182fbc50a2efb7d6059cd57b2e2ce18f5b92",
    # Conformance data, read by tools/unicode_conformance.py rather than here.
    "ucd/auxiliary/GraphemeBreakTest.txt":
        "b0cf047ee94485bbdc846de2b902f5f8a815f6b674f9d04223cddadd91c9df31",
    "ucd/NormalizationTest.txt":
        "25a50d816764b04abfb4a646d3eb2b2a803284c3873d9a06757b94fe4513dde3",
}

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_UCD_DIR = os.path.join(REPO, "build", "unicode", UNICODE_VERSION)
STD_OUT = "std/unicode_tables.psm"
CASE_OUT = "std/unicode_case.psm"
LEXER_OUT = "src/lexer/identifier_tables.psm"

MAX_SCALAR = 0x10FFFF
SURROGATES = range(0xD800, 0xE000)

# Hangul syllables are LV or LVT by arithmetic and decompose by arithmetic, so
# std.unicode computes them and no table carries them. `hangul_rule_holds`
# checks the data still agrees before the tables leave them out.
HANGUL_S_BASE = 0xAC00
HANGUL_S_COUNT = 11172
HANGUL_T_COUNT = 28

# Grapheme_Cluster_Break, Extended_Pictographic and Indic_Conjunct_Break packed
# into one value per range: GCB + 16 * ExtPict + 32 * InCB. One lookup answers
# all three questions UAX #29 asks of a scalar. The numbering is emitted as
# functions in std/unicode_tables.psm, so std/unicode.psm cannot disagree.
GCB_VALUES = ["Other", "CR", "LF", "Control", "Extend", "ZWJ",
              "Regional_Indicator", "Prepend", "SpacingMark",
              "L", "V", "T", "LV", "LVT"]
INCB_VALUES = ["None", "Linker", "Consonant", "Extend"]
PICTOGRAPHIC_BIT = 16
INCB_SHIFT = 32

SOFT_HYPHEN = 0x00AD


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 16), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch_ucd(ucd_dir, offline):
    """Every pinned file present in ucd_dir and matching its hash, or exit."""
    for rel, expected in UCD_FILES.items():
        path = os.path.join(ucd_dir, rel)
        if not os.path.exists(path):
            if offline:
                sys.exit(f"error: {path} is missing (and --ucd-dir means no download)")
            os.makedirs(os.path.dirname(path), exist_ok=True)
            print(f"fetching {UNICODE_URL}{rel}", file=sys.stderr)
            with urllib.request.urlopen(UNICODE_URL + rel) as response:
                data = response.read()
            with open(path + ".part", "wb") as handle:
                handle.write(data)
            os.replace(path + ".part", path)
        actual = sha256_of(path)
        if actual != expected:
            sys.exit(f"error: {path} has SHA-256 {actual}, but Unicode "
                     f"{UNICODE_VERSION} pins {expected}. Delete it to refetch, "
                     "or update the pin in a reviewed change.")


def data_lines(path):
    """(code point range, fields) for each data line of a UCD property file."""
    with open(path, encoding="utf-8-sig") as handle:
        for line in handle:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            fields = [f.strip() for f in line.split(";")]
            first, _, last = fields[0].partition("..")
            lo = int(first, 16)
            hi = int(last, 16) if last else lo
            yield range(lo, hi + 1), fields[1:]


def property_set(path, name, value=None):
    """The scalars whose property `name` (or `name; value`) is listed in path."""
    out = set()
    for cps, fields in data_lines(path):
        if fields[0] != name:
            continue
        if value is not None and (len(fields) < 2 or fields[1] != value):
            continue
        out.update(cps)
    return out


def property_map(path, values):
    """scalar -> value for a file whose second field is the value itself."""
    out = {}
    for cps, fields in data_lines(path):
        if fields[0] in values:
            for cp in cps:
                out[cp] = fields[0]
    return out


def scalars(field):
    return [int(part, 16) for part in field.split()]


def special_casing(path):
    """scalar -> (lower, title, upper) for SpecialCasing's unconditional lines.

    A line with a condition is either language-specific (Turkish, Lithuanian),
    which a locale-independent library does not apply, or Final_Sigma, which
    std/string.psm applies itself because it depends on the context. The one
    Final_Sigma line is checked rather than trusted, since the code hardcodes it.
    """
    out = {}
    final_sigma = False
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            fields = [f.strip() for f in line.split(";")]
            cp = int(fields[0], 16)
            if len(fields) > 4 and fields[4]:
                if fields[4] == "Final_Sigma":
                    final_sigma = (cp, scalars(fields[1])) == (0x03A3, [0x03C2])
                continue
            out[cp] = (scalars(fields[1]), scalars(fields[2]), scalars(fields[3]))
    if not final_sigma:
        sys.exit("error: SpecialCasing no longer maps Final_Sigma as U+03A3 -> U+03C2, "
                 "which std/string.psm assumes")
    return out


def case_folding(path):
    """scalar -> full case folding: status F where there is one, else C."""
    common, full = {}, {}
    for cps, fields in data_lines(path):
        status, mapping = fields[0], scalars(fields[1])
        for cp in cps:
            if status == "C":
                common[cp] = mapping
            elif status == "F":
                full[cp] = mapping
    common.update(full)
    return common


def confusables(path):
    """scalar -> its prototype, a sequence of one or more scalars."""
    out = {}
    for cps, fields in data_lines(path):
        for cp in cps:
            out[cp] = scalars(fields[0])
    return out


class UnicodeData:
    """The columns of UnicodeData.txt this needs, with First/Last ranges expanded."""

    def __init__(self, path):
        self.category = {}
        self.combining = {}
        self.decomposition = {}
        # Simple case mappings, columns 12-14. An empty titlecase column means
        # the titlecase mapping is the uppercase one (UAX #44).
        self.upper = {}
        self.lower = {}
        self.title = {}
        pending_first = None
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                fields = line.rstrip("\n").split(";")
                cp = int(fields[0], 16)
                name, category, ccc, decomp = fields[1], fields[2], int(fields[3]), fields[5]
                if name.endswith(", First>"):
                    pending_first = cp
                    continue
                cps = [cp]
                if name.endswith(", Last>"):
                    cps = range(pending_first, cp + 1)
                    pending_first = None
                for each in cps:
                    self.category[each] = category
                    if ccc:
                        self.combining[each] = ccc
                if decomp:
                    self.decomposition[cp] = decomp
                if fields[12]:
                    self.upper[cp] = int(fields[12], 16)
                if fields[13]:
                    self.lower[cp] = int(fields[13], 16)
                if fields[14]:
                    self.title[cp] = int(fields[14], 16)
                elif fields[12]:
                    self.title[cp] = int(fields[12], 16)

    def canonical_mapping(self, cp):
        """The one-step canonical mapping, or None for none or a compatibility one."""
        raw = self.decomposition.get(cp)
        if not raw or raw.startswith("<"):
            return None
        return [int(part, 16) for part in raw.split()]

    def full_canonical(self, cp):
        """The full canonical decomposition, expanded here rather than at run time."""
        mapping = self.canonical_mapping(cp)
        if mapping is None:
            return None
        out = []
        for part in mapping:
            out.extend(self.full_canonical(part) or [part])
        return out


def ranges_of(predicate):
    """Sorted, maximal, non-overlapping (first, last) runs where predicate holds."""
    out = []
    start = None
    for cp in range(MAX_SCALAR + 2):
        hit = cp <= MAX_SCALAR and cp not in SURROGATES and predicate(cp)
        if hit and start is None:
            start = cp
        elif not hit and start is not None:
            out.append((start, cp - 1))
            start = None
    return out


def valued_ranges_of(value_of):
    """(first, last, value) runs of equal nonzero value."""
    out = []
    start = None
    current = 0
    for cp in range(MAX_SCALAR + 2):
        value = 0 if cp > MAX_SCALAR or cp in SURROGATES else value_of(cp)
        if value != current:
            if current:
                out.append((start, cp - 1, current))
            start = cp
            current = value
    return out


def is_hangul_syllable(cp):
    return HANGUL_S_BASE <= cp < HANGUL_S_BASE + HANGUL_S_COUNT


def hangul_rule_holds(gcb, udata):
    for cp in range(HANGUL_S_BASE, HANGUL_S_BASE + HANGUL_S_COUNT):
        expected = "LV" if (cp - HANGUL_S_BASE) % HANGUL_T_COUNT == 0 else "LVT"
        if gcb.get(cp) != expected or cp in udata.decomposition:
            return False
    listed = {cp for cp, v in gcb.items() if v in ("LV", "LVT")}
    return all(is_hangul_syllable(cp) for cp in listed)


class Sources:
    def __init__(self, ucd_dir):
        path = lambda rel: os.path.join(ucd_dir, "ucd", rel)
        self.udata = UnicodeData(path("UnicodeData.txt"))
        self.wide = property_set(path("EastAsianWidth.txt"), "W") | \
            property_set(path("EastAsianWidth.txt"), "F")
        derived = path("DerivedCoreProperties.txt")
        self.cased = property_set(derived, "Cased")
        self.case_ignorable = property_set(derived, "Case_Ignorable")
        self.default_ignorable = property_set(derived, "Default_Ignorable_Code_Point")
        self.special_casing = special_casing(path("SpecialCasing.txt"))
        self.case_folding = case_folding(path("CaseFolding.txt"))
        security = lambda rel: os.path.join(ucd_dir, "security", rel)
        self.identifier_allowed = property_set(security("IdentifierStatus.txt"), "Allowed")
        self.confusables = confusables(security("confusables.txt"))
        self.xid_start = property_set(derived, "XID_Start")
        self.xid_continue = property_set(derived, "XID_Continue")
        self.incb = {}
        for value in INCB_VALUES[1:]:
            for cp in property_set(derived, "InCB", value):
                self.incb[cp] = value
        self.gcb = property_map(path("auxiliary/GraphemeBreakProperty.txt"), GCB_VALUES)
        self.pictographic = property_set(path("emoji/emoji-data.txt"), "Extended_Pictographic")
        self.composition_excluded = property_set(
            path("DerivedNormalizationProps.txt"), "Full_Composition_Exclusion")


# -- What each table holds ----------------------------------------------------

def zero_width(src):
    """Scalars that occupy no terminal column.

    Nonspacing and enclosing marks, format characters, controls and the line and
    paragraph separators -- except SOFT HYPHEN, which is Cf but which terminals
    draw, so every wcwidth gives it one column. And the medial vowels and final
    consonants of conjoining Hangul (Grapheme_Cluster_Break V and T): the leading
    consonant is East Asian Wide and the syllable occupies its two columns.
    """
    zero_categories = {"Mn", "Me", "Cf", "Cc", "Zl", "Zp"}

    def hit(cp):
        if cp == SOFT_HYPHEN:
            return False
        if src.udata.category.get(cp, "Cn") in zero_categories:
            return True
        return src.gcb.get(cp) in ("V", "T")
    return ranges_of(hit)


def grapheme_value(src, cp):
    if is_hangul_syllable(cp):
        return 0
    value = GCB_VALUES.index(src.gcb.get(cp, "Other"))
    if cp in src.pictographic:
        value += PICTOGRAPHIC_BIT
    value += INCB_SHIFT * INCB_VALUES.index(src.incb.get(cp, "None"))
    return value


def decompositions(src):
    out = []
    for cp in sorted(src.udata.decomposition):
        if is_hangul_syllable(cp):
            continue
        parts = src.udata.full_canonical(cp)
        if parts:
            out.append((cp, parts))
    return out


def compositions(src):
    """(first, second, composed): the primary composites of UAX #15.

    A two-scalar canonical mapping composes back unless the scalar is
    Full_Composition_Exclusion, which already covers the script-specific
    exclusions, the singletons and the non-starter decompositions.
    """
    out = []
    for cp in src.udata.decomposition:
        mapping = src.udata.canonical_mapping(cp)
        if mapping and len(mapping) == 2 and cp not in src.composition_excluded:
            out.append((mapping[0], mapping[1], cp))
    return sorted(out)


# -- Emission -----------------------------------------------------------------

def hex_scalar(cp):
    return f"0x{cp:05X}"


def array_rows(rows, per_line=1, indent="        "):
    """One row per line, so a diff of a table is a diff of ranges."""
    lines = []
    for i in range(0, len(rows), per_line):
        chunk = rows[i:i + per_line]
        lines.append(indent + ", ".join(", ".join(cells) for cells in chunk) + ",")
    # The final comma goes: a literal ends at its last element.
    lines[-1] = lines[-1][:-1]
    return "\n".join(lines)


def emit_search(out, name):
    out.append(f"""// The index of the row of `table` whose [first, last] holds `scalar`, or -1.
//
// A RangeTable: rows of `stride` Ints, the first two a scalar range, sorted and
// disjoint, so membership is a binary search -- about ten probes for a table of
// a thousand ranges.
private fn {name}(table: [Int], rows: Int, stride: Int, scalar: Int) -> Int {{
    let mut low = 0
    let mut high = rows - 1
    while (low <= high) {{
        let mid = (low + high) / 2
        let at = mid * stride
        if (scalar < table[at]) {{
            high = mid - 1
        }} else if (scalar > table[at + 1]) {{
            low = mid + 1
        }} else {{
            return mid
        }}
    }}
    return 0 - 1
}}
""")


def emit_predicate(out, name, doc, ranges, search):
    out.append(f"// {doc}")
    out.append(f"// {len(ranges)} ranges.")
    out.append(f"public fn {name}(scalar: Int) -> Bool {{")
    out.append("    let table = [")
    out.append(array_rows([(hex_scalar(lo), hex_scalar(hi)) for lo, hi in ranges]))
    out.append("    ]")
    out.append(f"    return {search}(table, {len(ranges)}, 2, scalar) >= 0")
    out.append("}")
    out.append("")


def emit_valued(out, name, doc, runs, search):
    out.append(f"// {doc}")
    out.append(f"// {len(runs)} ranges; 0 for a scalar in none of them.")
    out.append(f"public fn {name}(scalar: Int) -> Int {{")
    out.append("    let table = [")
    out.append(array_rows([(hex_scalar(lo), hex_scalar(hi), str(v)) for lo, hi, v in runs]))
    out.append("    ]")
    out.append(f"    let row = {search}(table, {len(runs)}, 3, scalar)")
    out.append("    if (row < 0) { return 0 }")
    out.append("    return table[row * 3 + 2]")
    out.append("}")
    out.append("")


def emit_decompositions(out, entries):
    widest = max(len(parts) for _, parts in entries)
    stride = 2 + widest
    rows = []
    for cp, parts in entries:
        cells = [hex_scalar(cp), str(len(parts))] + [hex_scalar(p) for p in parts]
        cells += ["0"] * (widest - len(parts))
        rows.append(cells)
    out.append(f"""// The full canonical decomposition of `scalar`, appended to `out`; false, and
// nothing appended, when it has none. Hangul syllables are not here: they
// decompose by arithmetic in std/unicode.psm.
//
// Expanded once, by the generator, rather than recursively at run time. Each row
// is the scalar, the number of parts, then {widest} part slots, unused ones 0.
// {len(entries)} entries.
public fn unicodeDecompose(scalar: Int, inout out: Vec<Int>) -> Bool {{
    let table = [""")
    out.append(array_rows(rows))
    out.append(f"""    ]
    let mut low = 0
    let mut high = {len(entries)} - 1
    while (low <= high) {{
        let mid = (low + high) / 2
        let at = mid * {stride}
        if (scalar < table[at]) {{
            high = mid - 1
        }} else if (scalar > table[at]) {{
            low = mid + 1
        }} else {{
            let count = table[at + 1]
            let mut part = 0
            while (part < count) {{
                out.push(table[at + 2 + part])
                part = part + 1
            }}
            return true
        }}
    }}
    return false
}}
""")


def emit_compositions(out, triples):
    out.append(f"""// The primary composite of `first` followed by `second`, or -1.
//
// Rows of first, second, composed, sorted by the pair. Derived from the
// two-scalar canonical mappings less Full_Composition_Exclusion, which is what
// UAX #15 defines a primary composite to be. Hangul composes by arithmetic in
// std/unicode.psm. {len(triples)} pairs.
public fn unicodeComposePair(first: Int, second: Int) -> Int {{
    let table = [""")
    out.append(array_rows([(hex_scalar(a), hex_scalar(b), hex_scalar(c)) for a, b, c in triples]))
    out.append(f"""    ]
    let mut low = 0
    let mut high = {len(triples)} - 1
    while (low <= high) {{
        let mid = (low + high) / 2
        let at = mid * 3
        let a = table[at]
        let b = table[at + 1]
        if (first < a or (first == a and second < b)) {{
            high = mid - 1
        }} else if (first > a or second > b) {{
            low = mid + 1
        }} else {{
            return table[at + 2]
        }}
    }}
    return 0 - 1
}}
""")


def emit_grapheme_constants(out):
    out.append("// The packing of unicodeGraphemeProperty: Grapheme_Cluster_Break in the low")
    out.append(f"// four bits, Extended_Pictographic as {PICTOGRAPHIC_BIT}, Indic_Conjunct_Break times "
               f"{INCB_SHIFT}.")
    out.append("// Named here, by the generator that chose them, so std.unicode reads the")
    out.append("// same numbers the table was written with.")
    for i, name in enumerate(GCB_VALUES):
        fn = "unicodeGcb" + name.replace("_", "")
        out.append(f"public fn {fn}() -> Int {{ return {i} }}")
    out.append(f"public fn unicodeGraphemePictographicBit() -> Int {{ return {PICTOGRAPHIC_BIT} }}")
    out.append(f"public fn unicodeGraphemeIncbShift() -> Int {{ return {INCB_SHIFT} }}")
    for i, name in enumerate(INCB_VALUES):
        out.append(f"public fn unicodeIncb{name}() -> Int {{ return {i} }}")
    out.append("")


def header(purpose, sources, generator_hash, ucd_dir):
    lines = [
        f"// {purpose}",
        "//",
        "// GENERATED FILE -- DO NOT EDIT. Regenerate with",
        "//",
        "//     python3 tools/generate_unicode_tables.py",
        "//",
        f"// Unicode version: {UNICODE_VERSION}",
        f"// Source:          {UNICODE_URL}",
    ]
    for rel in sources:
        lines.append(f"//   {rel:<36} sha256 {sha256_of(os.path.join(ucd_dir, rel))}")
    lines += [
        f"// Generator:       tools/generate_unicode_tables.py sha256 {generator_hash}",
        "//",
    ]
    return lines


def std_tables(src, generator_hash, ucd_dir):
    if not hangul_rule_holds(src.gcb, src.udata):
        sys.exit("error: Hangul syllables no longer follow the LV/LVT arithmetic; "
                 "std/unicode.psm computes them and the tables leave them out")

    wide = ranges_of(lambda cp: cp in src.wide)
    zero = zero_width(src)
    grapheme = valued_ranges_of(lambda cp: grapheme_value(src, cp))
    combining = valued_ranges_of(lambda cp: src.udata.combining.get(cp, 0))
    decomps = decompositions(src)
    comps = compositions(src)

    out = header(
        "Unicode property tables for std.unicode.",
        ["ucd/UnicodeData.txt", "ucd/EastAsianWidth.txt", "ucd/DerivedCoreProperties.txt",
         "ucd/DerivedNormalizationProps.txt", "ucd/auxiliary/GraphemeBreakProperty.txt",
         "ucd/emoji/emoji-data.txt"],
        generator_hash, ucd_dir)
    out += [
        "// Each table is a RangeTable: an array literal of sorted, disjoint scalar",
        "// ranges, binary-searched. Compiled, it is one constant in .rodata that the",
        "// search indexes directly -- no decoding and no allocation per lookup.",
        "//",
        "// Public rather than `internal`: `internal` is package-scoped and a",
        "// standard-library module is its own package, so std.unicode could not see",
        "// these otherwise. The `unicode` prefix is what keeps them out of the way.",
        "",
        "import std.string",
        "",
        f"public fn unicodeVersion() -> String {{ return \"{UNICODE_VERSION}\" }}",
        "",
    ]
    emit_search(out, "unicodeRangeRow")
    emit_predicate(out, "unicodeIsWide",
                   "East_Asian_Width W or F: two terminal columns.", wide, "unicodeRangeRow")
    emit_predicate(out, "unicodeIsZeroWidth",
                   "No terminal column: Mn, Me, Cf but U+00AD, Cc, Zl, Zp, and Hangul V and T.",
                   zero, "unicodeRangeRow")
    emit_grapheme_constants(out)
    emit_valued(out, "unicodeGraphemeProperty",
                "Grapheme_Cluster_Break, Extended_Pictographic and Indic_Conjunct_Break,\n"
                "// packed as above. Hangul syllables (LV, LVT) are computed, not listed.",
                grapheme, "unicodeRangeRow")
    emit_valued(out, "unicodeCombiningClass",
                "Canonical_Combining_Class, as runs of equal nonzero value.",
                combining, "unicodeRangeRow")
    emit_decompositions(out, decomps)
    emit_compositions(out, comps)
    summary = (f"wide {len(wide)}, zero {len(zero)}, grapheme {len(grapheme)}, "
               f"combining {len(combining)} ranges; {len(decomps)} decompositions, "
               f"{len(comps)} composites")
    return "\n".join(out).rstrip("\n") + "\n", summary


CASE_KINDS = ("lower", "title", "upper")


def full_case_mapping(src, cp, kind):
    """Unicode 3.13's full, unconditional, locale-independent mapping of cp."""
    which = CASE_KINDS.index(kind)
    special = src.special_casing.get(cp)
    if special:
        return special[which]
    simple = (src.udata.lower, src.udata.title, src.udata.upper)[which].get(cp)
    return [simple] if simple is not None else [cp]


CASE_WIDTH = 3
# string.psm's kinds, in its order: strCaseLower() is column 0, and so on.
CASE_COLUMNS = ("lower", "title", "upper", "fold")
CASE_BLOCK = 32
# A column value no delta can be: the mapping is more than one scalar, and the
# exception rows hold it. Deltas are within +/-0x10FFFF.
CASE_MULTIPLE = 1 << 30


def case_column(src, cp, column):
    if column == "fold":
        return src.case_folding.get(cp, [cp])
    return full_case_mapping(src, cp, column)


def case_tables(src, generator_hash, ucd_dir):
    out = header(
        "Unicode case mapping and case folding tables for std.string.",
        ["ucd/UnicodeData.txt", "ucd/SpecialCasing.txt", "ucd/CaseFolding.txt",
         "ucd/DerivedCoreProperties.txt"],
        generator_hash, ucd_dir)

    mapped = {}
    last = 0
    for cp in range(MAX_SCALAR + 1):
        if cp in SURROGATES:
            continue
        row = [case_column(src, cp, column) for column in CASE_COLUMNS]
        if any(target != [cp] for target in row):
            mapped[cp] = row
            last = cp
    limit = (last // CASE_BLOCK + 1) * CASE_BLOCK

    def cell(cp, i):
        target = mapped.get(cp, [[cp]] * len(CASE_COLUMNS))[i]
        return target[0] - cp if len(target) == 1 else CASE_MULTIPLE

    blocks = {}
    index = []
    for base in range(0, limit, CASE_BLOCK):
        key = tuple(cell(cp, i) for cp in range(base, base + CASE_BLOCK)
                    for i in range(len(CASE_COLUMNS)))
        if key not in blocks:
            blocks[key] = len(blocks)
        index.append(blocks[key] * CASE_BLOCK)

    exceptions = []
    for cp in sorted(mapped):
        for i, target in enumerate(mapped[cp]):
            if len(target) == 1:
                continue
            if len(target) > CASE_WIDTH:
                sys.exit(f"error: U+{cp:04X} maps to {len(target)} scalars; the case "
                         f"tables hold {CASE_WIDTH}")
            exceptions.append((cp * len(CASE_COLUMNS) + i, target))

    columns = len(CASE_COLUMNS)
    out += [
        "// A separate module from std/unicode_tables.psm because std.string imports it:",
        "// every program that uses a String would otherwise carry the grapheme and",
        "// normalization tables too. It imports nothing.",
        "//",
        "// **A two-stage table, not a RangeTable**, and a benchmark asked for it: a",
        "// binary search per scalar per part, in two passes, made `toUpper` on",
        "// Cyrillic, Greek and accented Latin 5.4x Rust's. ICU's code point tries",
        "// are the model (two array reads and no search): the scalar's block of",
        f"// {CASE_BLOCK} is found in `index`, and its row in `data` holds one Int per kind --",
        "// the delta to the mapped scalar, 0 for a scalar that maps to itself. Blocks",
        "// with the same contents are stored once. A mapping of more than one scalar",
        "// (SpecialCasing's `ß` -> `SS`) reads as unicodeCaseMultiple() there, and",
        "// its scalars are in the exception rows.",
        "//",
        "// Conditional mappings are not here: Final_Sigma depends on the text around",
        "// it and std/string.psm applies it, and the Turkish and Lithuanian ones depend",
        "// on a language this library is not told.",
        "",
        "// A column value that is not a delta: see the exception rows.",
        f"public fn unicodeCaseMultiple() -> Int {{ return {CASE_MULTIPLE} }}",
        "",
        f"// {len(mapped)} scalars map to another in some kind; {len(index)} blocks of "
        f"{CASE_BLOCK},",
        f"// {len(blocks)} of them distinct. Past U+{limit - 1:04X} every scalar maps to itself.",
        "// `kind` is 0 lower, 1 title, 2 upper, 3 fold.",
        "public fn unicodeCaseDelta(kind: Int, scalar: Int) -> Int {",
        f"    if (scalar < 0 or scalar >= {hex_scalar(limit)}) {{ return 0 }}",
        "    let index = [",
        array_rows([(str(v),) for v in index], per_line=16),
        "    ]",
        "    let data = [",
        array_rows([tuple(str(v) for v in key[i:i + columns])
                    for key in blocks for i in range(0, len(key), columns)], per_line=4),
        "    ]",
        f"    return data[(index[scalar / {CASE_BLOCK}] + scalar % {CASE_BLOCK}) * {columns} + kind]",
        "}",
        "",
        f"// The part-th scalar of a mapping longer than one: rows of the key",
        f"// `scalar * {columns} + kind` and {CASE_WIDTH} parts, unused parts 0. -1 past the end.",
        f"// {len(exceptions)} rows.",
        "private fn unicodeCaseException(kind: Int, scalar: Int, part: Int) -> Int {",
        "    let table = [",
        array_rows([[str(key)] + [hex_scalar(t) for t in target]
                    + ["0"] * (CASE_WIDTH - len(target)) for key, target in exceptions]),
        "    ]",
        f"    let key = scalar * {columns} + kind",
        "    let mut low = 0",
        f"    let mut high = {len(exceptions)} - 1",
        "    while (low <= high) {",
        "        let mid = (low + high) / 2",
        f"        let at = mid * {CASE_WIDTH + 1}",
        "        if (key < table[at]) {",
        "            high = mid - 1",
        "        } else if (key > table[at]) {",
        "            low = mid + 1",
        "        } else {",
        f"            if (part >= {CASE_WIDTH}) {{ return 0 - 1 }}",
        "            let value = table[at + 1 + part]",
        "            if (value == 0) { return 0 - 1 }",
        "            return value",
        "        }",
        "    }",
        "    return 0 - 1",
        "}",
        "",
        "// The part-th scalar `scalar` maps to in `kind`, or -1 past the end of it.",
        "private fn unicodeCaseMapped(kind: Int, scalar: Int, part: Int) -> Int {",
        "    let delta = unicodeCaseDelta(kind, scalar)",
        "    if (delta == unicodeCaseMultiple()) { return unicodeCaseException(kind, scalar, part) }",
        "    if (part == 0) { return scalar + delta }",
        "    return 0 - 1",
        "}",
        "",
    ]
    for i, column in enumerate(CASE_COLUMNS):
        name = "unicodeCaseFold" if column == "fold" else "unicode" + column.capitalize() + "case"
        doc = ("Full case folding: CaseFolding.txt statuses C and F." if column == "fold"
               else f"Full {column}case mapping, SpecialCasing over UnicodeData.")
        out += [f"// {doc}",
                f"public fn {name}(scalar: Int, part: Int) -> Int {{ return unicodeCaseMapped({i}, scalar, part) }}",
                ""]
    counts = [f"{len(mapped)} mapped scalars, {len(blocks)} distinct blocks, "
              f"{len(exceptions)} exceptions"]

    emit_search(out, "unicodeCaseRangeRow")
    emit_predicate(out, "unicodeIsCased", "Cased: what Final_Sigma looks for on either side.",
                   ranges_of(lambda cp: cp in src.cased), "unicodeCaseRangeRow")
    emit_predicate(out, "unicodeIsCaseIgnorable",
                   "Case_Ignorable: what Final_Sigma looks past.",
                   ranges_of(lambda cp: cp in src.case_ignorable), "unicodeCaseRangeRow")
    return "\n".join(out).rstrip("\n") + "\n", "; ".join(counts)


def emit_confusables(out, table):
    rows = []
    targets = []
    offset = 0
    for cp in sorted(table):
        prototype = table[cp]
        rows.append((hex_scalar(cp), str(offset), str(len(prototype))))
        targets.append(tuple(hex_scalar(t) for t in prototype))
        offset += len(prototype)
    # Read back exactly as confusablePrototype reads it: an offset that counted
    # rows instead of scalars once shifted every prototype after the first long one.
    flat = [cell for row in targets for cell in row]
    for (source, start, length), cp in zip(rows, sorted(table)):
        expected = [hex_scalar(t) for t in table[cp]]
        if flat[int(start):int(start) + int(length)] != expected:
            sys.exit(f"error: confusables row {source} does not read back its prototype")
    out.append(f"""// The part-th scalar of `scalar`'s UTS #39 prototype, or -1 past its end. A
// scalar with no entry is its own prototype. Rows are the scalar, an offset into
// `targets` and a length, since a prototype runs to 18 scalars. {len(rows)} entries.
public fn confusablePrototype(scalar: Int, part: Int) -> Int {{
    let rows = [""")
    out.append(array_rows(rows))
    out.append("    ]")
    out.append("    let targets = [")
    out.append(array_rows(targets))
    out.append(f"""    ]
    let mut low = 0
    let mut high = {len(rows)} - 1
    while (low <= high) {{
        let mid = (low + high) / 2
        let at = mid * 3
        if (scalar < rows[at]) {{
            high = mid - 1
        }} else if (scalar > rows[at]) {{
            low = mid + 1
        }} else {{
            if (part >= rows[at + 2]) {{ return 0 - 1 }}
            return targets[rows[at + 1] + part]
        }}
    }}
    if (part == 0) {{ return scalar }}
    return 0 - 1
}}
""")


def lexer_tables(src, generator_hash, ucd_dir):
    start = ranges_of(lambda cp: cp in src.xid_start)
    cont = ranges_of(lambda cp: cp in src.xid_continue)
    allowed = ranges_of(lambda cp: cp in src.identifier_allowed)
    ignorable = ranges_of(lambda cp: cp in src.default_ignorable)
    out = header(
        "Identifier character tables for the lexer (UAX #31, UTS #39).",
        ["ucd/DerivedCoreProperties.txt", "security/IdentifierStatus.txt",
         "security/confusables.txt"], generator_hash, ucd_dir)
    out += [
        "// XID_Start and XID_Continue: the closure-under-NFKC forms of ID_Start and",
        "// ID_Continue that UAX #31 recommends for identifiers. Prismio's profile of",
        "// them -- `_` as a start, NFC, ASCII keywords -- is in src/lexer/scanner.psm,",
        "// and what it does with the UTS #39 tables in src/lexer/identifier_security.psm.",
        "",
    ]
    emit_search(out, "identifierRangeRow")
    emit_predicate(out, "isXidStart", "XID_Start.", start, "identifierRangeRow")
    emit_predicate(out, "isXidContinue", "XID_Continue.", cont, "identifierRangeRow")
    emit_predicate(out, "isIdentifierAllowed",
                   "UTS #39 Identifier_Status=Allowed: the General Security Profile.",
                   allowed, "identifierRangeRow")
    emit_predicate(out, "isDefaultIgnorable",
                   "Default_Ignorable_Code_Point: dropped from a UTS #39 skeleton.",
                   ignorable, "identifierRangeRow")
    emit_confusables(out, src.confusables)
    summary = (f"XID_Start {len(start)}, XID_Continue {len(cont)}, Allowed {len(allowed)}, "
               f"Default_Ignorable {len(ignorable)} ranges; {len(src.confusables)} confusables")
    return "\n".join(out).rstrip("\n") + "\n", summary


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--ucd-dir", help="a directory already holding the pinned "
                        f"UCD {UNICODE_VERSION} files; nothing is downloaded")
    parser.add_argument("--check", action="store_true",
                        help="compare against the committed tables instead of writing")
    args = parser.parse_args()

    ucd_dir = os.path.abspath(args.ucd_dir) if args.ucd_dir else DEFAULT_UCD_DIR
    fetch_ucd(ucd_dir, offline=bool(args.ucd_dir))
    generator_hash = sha256_of(os.path.abspath(__file__))
    src = Sources(ucd_dir)

    outputs = [(STD_OUT, std_tables(src, generator_hash, ucd_dir)),
               (CASE_OUT, case_tables(src, generator_hash, ucd_dir)),
               (LEXER_OUT, lexer_tables(src, generator_hash, ucd_dir))]
    stale = []
    for rel, (text, summary) in outputs:
        path = os.path.join(REPO, rel)
        if args.check:
            with open(path, encoding="utf-8") as handle:
                if handle.read() != text:
                    stale.append(rel)
            continue
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        print(f"wrote {rel} ({summary}; Unicode {UNICODE_VERSION})")
    if stale:
        print("stale, regenerate with tools/generate_unicode_tables.py: " + ", ".join(stale))
        return 1
    if args.check:
        print(f"Unicode tables match UCD {UNICODE_VERSION}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
