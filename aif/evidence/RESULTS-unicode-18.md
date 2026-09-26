# Unicode 18.0.0 from the UCD, UAX #31 identifiers, and constant array literals

**Status: DONE, 2026-09-26; round 2 (sections 7-12) DONE 2026-09-27.** Compilers `build/uc1`..`uc4` (uc3 = uc4 at the IR),
LLVM 23 on Apple Silicon. Baseline: `std/unicode*.psm` at `0064491`, built by
the same compiler, so the two arms differ only in the library.

## 1 · The tables came from the interpreter, and the interpreter was wrong

`tools/generate_unicode_tables.py` read `unicodedata`: Unicode **13.0.0** on the
CPython 3.9.6 that ran it, three versions behind and chosen by nobody. That
database answers East_Asian_Width `F` for **every unassigned code point**
(`east_asian_width('͸') == 'F'`), so the "wide" table was 692 ranges and
`scalarWidth` said 2 for 947,799 scalars. The UCD's EastAsianWidth.txt gives 126
ranges.

| `scalarWidth` over all 1,112,064 scalars | 0 | 1 | 2 |
|---|---|---|---|
| before (CPython 13.0.0) | 2,080 | 162,185 | **947,799** |
| after (UCD 18.0.0) | 2,576 | 925,629 | 183,859 |

The generator now pins `UNICODE_VERSION = "18.0.0"` and the SHA-256 of each UCD
file, fetches them into `build/unicode/18.0.0/`, refuses a hash mismatch, and never
imports `unicodedata`. Every output states the version, each source with its
hash, and the generator's hash. `--check` fails on drift.

## 2 · Conformance, against the UCD's own tests

`tools/unicode_conformance.py` runs `tools/unicode_conformance.psm` over
GraphemeBreakTest-18.0.0 and NormalizationTest-18.0.0 (NFC and NFD; NFKC/NFKD
are not implemented and not checked).

| | before | after |
|---|---|---|
| GraphemeBreakTest lines | 700 / 853 | **853 / 853** |
| NormalizationTest lines (NFC, NFD) | 19,493 / 20,171 | **20,171 / 20,171** |
| Part 1 invariants (scalars unchanged by both) | 1,094,910 | 1,094,910 |

The grapheme segmenter was "a documented subset of UAX #29"; it is now GB1-GB999.
The 678 normalization failures were characters with decompositions added since
Unicode 13.

**GB9c changed in 18.0.** Written to Unicode 15.1's rule (`Consonant
[Extend Linker]* Linker [Extend Linker]* × Consonant`), ten lines failed; 18.0's
is `ConjunctLinker ConjunctExtender* × LinkingConsonant` (GraphemeBreakTest.html,
rule 9.3). The data files were unchanged in shape. This is what the conformance
tool is for: nothing in the property files announces a rule change.

## 3 · Representation: readable, after one codegen fix

The requirement was a readable RangeTable first, and a packed encoding only if a
benchmark asked for one. The existing tables were packed -- six hex digits per
bound in a string literal -- with no recorded measurement.

Same XID_Continue data (821 ranges), both representations in one binary, 2.86M
lookups per trial, interleaved, 7 trials, identical checksums:

| representation | ms / trial |
|---|---|
| hex digits in a string (the old encoding) | 67 |
| `[Int]` array literal, compiler before this change | 160 |
| `[Int]` array literal, this change | **16** |

The readable form lost at first because **a local array literal was 1,642
`store`s per call**: `generateArrayLiteral` stored each element into the frame.
Now an array literal of numeric literals larger than 64 bytes is emitted as a
private `unnamed_addr constant` and one `memcpy` (`ir_array_literal_*` in
runtime/llvm-api-backend.c) -- clang's rule for `const int t[] = {...}` in a
function (`shouldSplitConstantStore`, CGDecl.cpp). LLVM removes the copy when the
frame array is only read and indexes the constant. No packed encoding was
introduced: the benchmark says the readable form is the fast one.

## 4 · std.unicode, before and after

320 KB of mixed text (Latin with accents, Japanese, Greek, Devanagari, emoji,
flags), 5 trials, medians; the arms compute different answers where the old one
was wrong, so the checksums differ by design.

| workload | before | after | |
|---|---|---|---|
| `displayWidth` x20 | 148 ms | 100 ms | 1.48x |
| `graphemeCount` x20 | 80 ms | 52 ms | 1.54x |
| `normalizeNfc` x5 | 62 ms | 23 ms | 2.70x |
| `scalarWidth` over every scalar | 73 ms | 9.5 ms | 7.7x |

`displayWidth` is now per grapheme cluster: an emoji sequence is two columns (a
ZWJ family was six, a skin tone four), `©` + VS16 is two, conjoining Hangul
vowels and finals are zero, SOFT HYPHEN is one.

## 5 · Identifiers: UAX #31

ASCII keeps its fast path. Past ASCII the lexer decodes a scalar and tests
`XID_Start` / `XID_Continue` from `src/lexer/identifier_tables.psm` (702 / 821
ranges). Prismio's profile: `_` starts a name; U+200C/U+200D are excluded
although Unicode 15.1 made them XID_Continue; names are NFC (`é` two ways is one
symbol); keywords are ASCII. Rejections name the code point, and a non-UTF-8
byte is reported by value. Columns remain UTF-8 bytes (IDE_PROTOCOL.md).

Tests: test_200 (Cyrillic struct, CJK function and parameters, Greek, Arabic-
Indic digit, NFC equivalence), neg_201 (ZWJ), neg_202 (mark first),
`source_not_utf8` in test_runner.py (the file cannot live in tests/: lint and
the formatter read it as UTF-8).

## 6 · Verification

- Fixpoint: uc3 and uc4 emit byte-identical `compiler.ll`; from the committed
  seed, seed -> ucs0 -> ucs1 -> ucs2 matches uc4.
- `--verify` on test_137 and test_200: 0 leaked, 0 violations.
- Suite (`run_suite.py --compiler build/uc3-pkg/bin/prismio`): 438/439; the
  one failure was `source_not_utf8` decoding the diagnostic as UTF-8 -- the
  harness, fixed, and passing when run alone. `aif_differential.py`: engine and
  oracle agree on all 19 sources.
- IR: `ir_snapshot.py` over tests/ and aif/corpus/ against the pre-change
  compiler differs in exactly three programs -- `src/main.psm`, test_137 (it
  imports std.unicode) and the new test_200. No existing program had a numeric
  literal array past 64 bytes; blake3's 16-element `MSG_PERM` is exactly 64 and
  keeps its stores, as in clang.
- Docs: both website apps' example gates pass (239 and 50 snippets).

# Round 2: case, Trojan Source, UTS #39 -- and what measuring them found

**Status: DONE, 2026-09-27.** Compilers `build/h1`..`h3` (fixpoint at the IR,
and equal to `build/hs1`/`hs2` from the committed seed), LLVM 23 on Apple
Silicon. Baselines: `build/v3` (round 2 as it was left) and the packaged
compiler at `0064491` (`oldpkg`), both measured from the same directory as the
new arm so each reads its own packaged `stdlib/`.

## 7 · The ASCII regression was the caller's loop, not `toUpper`'s

Round 2 left `toUpper` on 1 MB of ASCII at 18 ms against 1 ms, attributed to
the ASCII loop no longer vectorising behind `strIsAscii`. Disassembled, the loop
*was* vectorised -- the same 64-byte NEON body as before. Timed alone,
`toUpper` was 1.25 ms against 0.85 ms. The benchmark's 18 ms was its own
`checksum` loop, `sum += s.byteAt(i)`, which ran scalar in both builds (18.8 ms)
and vectorised only in the old one, where the small `strToUpper` inlined into
`main` and told LLVM what the string was.

Why the byte loop was scalar: a String parameter's data pointer was resolved in
every function's entry block -- three stores to a scratch slot. `strByteAt` is a
one-line function; inlined into the caller's loop, its entry block landed in
the loop between `lifetime.start`/`lifetime.end`, which LICM does not hoist
stores past, and the load went through a `select` that could point at them. The
IR before the vectoriser shows it directly.

Fix: resolve only in a function that contains a loop (`irFunctionHasLoop`,
src/ir/module.psm and stmt.psm). A loop-free function reads each byte once per
call either way; the per-access read (`ir_str_byte_at`) is store-free.

| 50 × 1 MB | before | after |
|---|---|---|
| `sum += s.byteAt(i)` over a String parameter | 18.8 ms | **0.58 ms** (32×) |
| casebench `toUpper`/`toLower` + checksum | 18 / 18 ms | **1 / 1 ms** (old: 1 / 1) |

`run_byte_loop_vectorise_test` pins it: `sumBytes` resolves its parameter,
`firstByte` (no loop) does not, and LLVM's own IR after `loop-vectorize` has a
`vector.body`. The round-2 compiler fails both halves.

What remained of `toUpper`'s own cost was reading ASCII twice (check, then map).
One pass that maps and ORs the bytes together vectorises as one loop:
**1.02 ms** against the old ASCII-only 0.85 ms -- four `orr`s per 64 bytes is
what knowing the answer costs. `equalsIgnoreCase` compared a byte at a time
with an exit per byte; 64-byte blocks with no exit inside one took it from 28 ms
to **2 ms**.

## 8 · A binding returned on one path leaked on the others

The fused `toUpper` returns `out` on the ASCII path and `mapped` on the other,
and `--verify` read 400 leaked: `out` was never released on the path that
returned `mapped`. Not the new code's fault -- the committed compiler leaks the
same shape in user code:

```
fn pick(seed: String, flag: Bool) -> String {
    let a = seed.repeat(3)
    if (flag) { return a }
    return seed.repeat(2)          // `a`: 50 of 155 leaked on 0064491
}
```

Two causes, one per kind of allocation. A callee's allocation (`repeat`) was
refused by `nodeReturnsName`: a binding any `return` named was off the drop list
for every path. A frame's own allocation (`str_with_capacity`) was refused by the
escape fact: the return lifts `E` to Caller for every path.

Fix: `generateReturn` skips the drop of the binding a bare `return name` returns,
and every other exit releases it. For a frame's own allocation the engine keeps
`E_held` -- `E` by every rule except the direct E-RETURN of a bare return in the
site's own function, and except a return or a binding in another function (a
value made here reaches another frame only after this one returned it, or during
a call it made; containers, fields, globals and tasks raise `E_held` by their
own rules) -- and `ret_key`, the binding that return named.
`aif_frees_unless_returned_node` is `aif_frees_at_scope_node` with `E_held` for
`E` and `ret_key` required to be this binding's. `E` is untouched, so no tier
moves and the oracle agrees.

Two shapes keep the old refusal, a leak rather than a double free:
`let t = a; return t` (`ret_key` is `t`'s) and a name bound twice. The second is
not hypothetical -- `let a = a; return a` in an inner block made the outer `a`
and the inner one a single engine key, and the first build of this read
**release of a pointer that is not live**. Binding keys are per name, so the
codegen side requires the name to be bound once.

| | 0064491 | now |
|---|---|---|
| six return shapes (shapes.psm), 587 allocations | 282 leaked | 25 (the alias shape, by design), 0 violations |
| test_205_return_on_one_path | 77 leaked | **10** (aliased + rebound, by design) |
| leak4: toUpper/toLower/capitalize/equalsIgnoreCase, ASCII and not | -- | 2,812 / 2,812 / 0 |

Adversarial shapes -- `Some(a)` on one path, `a` through an identity call,
local struct and Vec returns -- read 0 violations; the language itself rejects
the rest (a value pushed or captured on one path cannot be returned on another:
use of moved value).

## 9 · Case mapping: a search per scalar was 5.4× Rust

Non-ASCII case mapping had never been timed. Over 828 KB of Cyrillic, Greek and
accented Latin it was 16 ms for `toUpper` against Rust's `to_uppercase` 3.1 ms:
a binary search over ~1,500 rows per scalar per part, in two passes -- about
four searches per character.

What the literature says, and what was taken from it:

- ICU's code point tries: a two-stage table, "two array reads and no search",
  measured 5.6-6× over search for property lookup. Taken: `unicodeCaseDelta`,
  `index[scalar / 32]` then a row of four deltas (lower, title, upper, fold);
  103 distinct blocks, 258 exception rows for multi-scalar mappings.
  101 KB of source against the four RangeTables' 222 KB.
- Rust's `core::unicode`: ASCII fast path plus binary search per char -- the
  design being beaten.
- Lemire and Muła (simdutf): process in blocks and take a fast path when a block
  is uniform. Taken twice: the ASCII pass, and `equalsIgnoreCase`'s 64-byte
  blocks.

Plus one design of our own, the second tier: most letters map to a letter of
the same UTF-8 width, so map in one pass while that holds, and from the first
scalar that changes width (`ı` -> `I`) measure and map only the rest.
`equalsIgnoreCase` past ASCII walks both strings folding a scalar at a time
instead of building two `Vec<Int>`s (test_204: 144 allocations -> 81).

| 828 KB mixed text | before | after | Rust |
|---|---|---|---|
| `toUpper` | 16.1 ms | **1.9 ms** | 3.2 ms |
| `toLower` | 16.7 ms | **1.7 ms** | 2.6 ms |
| `equalsIgnoreCase` | 14.2 ms | **2.1 ms** | -- (no full folding in std) |
| `toUpper`, `ı` last | 16.0 ms | 1.9 ms | 3.2 ms |
| `toUpper`, `ı` first (whole string exact) | -- | 4.0 ms | 3.2 ms |

Exactness, two differentials against the round-2 row tables and `string.psm`:
every mapping of every scalar in all four kinds (1,112,064 scalars, 6,243
non-identity lines) identical; and 4,315 cased scalars in 107 strings, with Σ
final and not, through `toUpper`/`toLower`/`capitalize`/`equalsIgnoreCase`,
byte-identical output.

`toUpper` and `toLower` stay two bodies. One shared `strCaseConverted` leaked
30 more strings in test_205: a site is decided for the whole program, and one
test pushing results of each into a Vec was enough (KNOWN_ISSUES). The old
reason given for two bodies -- a delegating return leaks -- is stale: 1,000
delegating calls with an owned argument read 2,001 / 2,001 / 0 on `0064491`.

## 10 · Trojan Source and UTS #39, tested

P2002 is refused on all four scan paths: `neg_208` string, `neg_209` line
comment, `neg_210` nested block comment, `neg_211` triple-quoted string.
`test_212` is the other half: `\u{202E}` escaped is accepted and is three bytes,
and an em dash, arrow and ellipsis -- the same 0xE2 lead byte -- pass in strings
and comments. `run_identifier_security_test` builds and runs a program with a
P2003 (`ſum`) and a P2004 (`pаypal`/`paypal`) and checks the exit status, the
rendered text, and the JSON stream's code, severity, line and column; an
ASCII-only control reports nothing.

The rendered P2002 snippet echoed the raw override, so the terminal applied it
and the error about Trojan Source displayed Trojan Source. `diag_print_line`
prints a bidi control as U+FFFD, as rustc does. Carets now count characters
rather than bytes (an `é` before the span shifted it a column).

## 11 · A `break` in a nested loop is that loop's

Writing `strFoldedEquals` as a `loop` with inner `while`s that `break` was
rejected: "must return Bool on every path". `semaBlockHasBreak` counted every
break in a nested loop as leaving the outer one -- conservative before labels.
Now a break leaves the analysed loop if it is unlabelled and not inside a nested
loop, or labelled and not naming a nested loop (`break@outer` from inside still
counts: neg_207). test_206 is the accepted half. A consequence to know: a
`return` after such a loop, which the old rule required, is now unreachable code.
Nothing in src/, std/, tests/ or the docs had one. std code must still satisfy
the seed's rule, so `strFoldedEquals` exits its loop with a real `break`.

## 12 · Verification, round 2

- Fixpoint: h1 = h2 = h3 at `compiler.ll` (f32d7263…); seed -> hs0 -> hs1 -> hs2
  identical.
- Suite (`run_suite.py --compiler build/h2-pkg/bin/pc`, renamed): **450 / 450**.
- AIF differential: engine and oracle agree on all 19 sources, both ownership settings.
- IR snapshot, same tree, attributed one change at a time: `uc3` -> `v3` (round
  2's compiler) changes **0** programs; `v3` -> `bl1` (the loop gate alone)
  changes 249 -- almost every program pulls `std.io`'s loop-free printing
  functions into its IR, and those lose their dead entry-block resolution;
  `bl1` -> `h2` changes 142, and every one is a new release: `strToUpper` /
  `strToLower` (141 / 140 programs, the abandoned fast-path buffer), test_205's
  four shapes, and three functions of the compiler itself --
  `standardModulePath` (+7 releases), `generateOwnedFieldRelease` and
  `runWorkloadProfile` (+1 each), which leaked on their non-returning paths.
  Skip lists differ exactly by neg_208..211 (now refused) and test_206 (now
  accepted).
- `lint.py`, `format_sources.py --check`, `check_source_lists.py`,
  `generate_unicode_tables.py --check`: clean.
- Conformance: GraphemeBreakTest 853 / 853, NormalizationTest 20,171 / 20,171, Part 1 invariants 1,094,910 unchanged.
- `--verify`: test_137 57 / 57 / 0, test_200 and test_206 and test_212 allocate nothing, test_204 81 / 81 / 0, test_205 192 / 182 / 10 (by design); 0 violations in all.
- Benchmark suite, v3 against h2: BENCH_RESULT.
- Docs: example gates 244 (docs) and 50 (developers) snippets; both content audits pass.
