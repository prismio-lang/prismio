# Results: the string-performance follow-ups (2026-09-11)

The four items `RESULTS-string-containers-and-search.md` left open: the String
compare, `sort()` from a packaged `.plib`, `sortBy` on flat structs, and three
smaller wins. Same machine and toolchains as that file: an Apple M-series Mac,
LLVM 22.1.8, `clang++ -O3 -std=c++20`, `rustc -C opt-level=3`.

Every compiler compared here is a two-generation bootstrap that reached an IR
fixpoint. The baseline is HEAD (`727c704`) bootstrapped from the project host:
`src/main.psm` IR `0cc967a8e478d5ff85acca0832fbdb5a` at gen1 and gen2.

## `sort()` from a packaged `.plib`

**The recorded cause was wrong.** KNOWN_ISSUES put it down to the standard
library resolving `./std` relative to the current directory. It resolves by
walking up from the *entry file* (`standardModulePath`, and RUNTIME.md's table),
and that only decides whether a build reaches the defect. The defect is in
emission.

`shouldEmitFunctionFromSource` (`src/ir/module.psm`) skips a non-generic
function whose module is a registered PLIB, because the PLIB's bitcode supplies
it. An instantiation escapes that test by carrying its template's `genericInfo`.
The closure `sort` hands `sortBy` is lowered to a `call` function *while the
program checks its instantiation of `sort`*, and `semaLowerClosure` gave that
function a null `genericInfo` and the span of `std/list.psm` -- so it read as
one of `std.list`'s concrete definitions, was skipped, and no PLIB had it,
because its name carries the program's type arguments.

The fix: the `call` inherits the `genericInfo` of the instantiation it was
lowered in (`closureEnclosingGenerics`, set by `semaFunction`). Nothing else
tests `genericInfo` on a live function -- the parser's two tests are on
templates -- so the field means exactly "part of an instantiation the program
emits".

The resolution order was not changed. Searching the entry's enclosing
directories first is what makes the compiler's bootstrap build against its own
tree, and RUNTIME.md documents it as deliberate. What was wrong was two
descriptions of it: `standardModulePath`'s comment said a local `std/` could not
shadow the shipped one, which is the opposite of the code, and RUNTIME.md's rule
2 said one level up where the code walks every enclosing directory.

| | Baseline (HEAD) | Fixed |
| --- | --- | --- |
| `sort` on `List<Int>` and `List<String>`, built outside the checkout with the packaged toolchain | link fails: `_call__Struct_Closure$132$1_Int_Int` undefined | links, prints `sorted` |
| IR of 185 programs (`tests/`, `aif/corpus/`, `benchmarks/prismio/`, `src/main.psm`) | | byte-identical to baseline |
| `stdlib/*.plib` and `lib/runtime/*.bc` in the packaged toolchain | | 16/16 and 4/4 byte-identical |
| Fixpoint, `src/main.psm` IR | | `251bd9c4d55dd47f94ab02dda1d20f5d` at gen1 and gen2 |
| `tools/run_suite.py` | | 316/316 |
| `tools/aif_differential.py` | agree on 19/19 | agree on 19/19, output identical |

In-tree IR cannot move: an in-tree program never reads a PLIB, so
`compiler_plib_module_registered` answers no and the changed test is never
reached. That is also why no fixture caught this. The guard is
`run_runtime_library_test`'s new assertion 1b, which builds the same probe
against the toolchain it packages; against the baseline's toolchain it fails.

## `String.compare`, step one: the builtin, unused

`src/` imports `std.string`, so the committed seed compiles `std/string.psm`,
and a builtin used there before the seed knew it would break
`tools/bootstrap.sh --seed` and every CI leg. So the order is CLAUDE.md's:
teach the compiler, refresh the seed, then use it. This step is the first two.

The lowering is `ir_str_compare`. Two inline strings compare as one unsigned
128-bit key, `bswap64(field 0)` above `rev32(word 1)`: the twelve bytes
most-significant first with the length below them, which orders exactly as the
byte loop does because an inline pair is zero past its length (STRINGS.md
invariant 1). Every other pair takes `memcmp` over the shorter length and then
the lengths. The answer is -1, 0 or 1, spelled `(a > b) - (a < b)` so a caller
testing only the sign folds it to one compare.

| Check | Result |
| --- | --- |
| IR of every other program (184) | byte-identical to the previous step; only `src/main.psm` and the new fixture differ |
| Fixpoint, `src/main.psm` IR | `8a4beba851e7ffaef8f05dfef80906c3` at gen1 and gen2 |
| Seed | refreshed from gen2; a compiler bootstrapped from it builds `src/main.psm` to the same `8a4beba8...` |
| `test_143_string_compare` | PASS: the builtin and `.compare()` agree with a byte loop in both argument orders over 28 strings -- inline, short on the heap, long -- and three views |
| `--verify` on that fixture | 15 allocated, 14 released, 1 leaked, 0 violations -- the identical ledger the previous compiler gives with the builtin replaced by a `.compare()` shim, so the one leak (the views' base) predates this |
| `tools/run_suite.py` | 317/317 |
| `tools/aif_differential.py` | agree on 19/19, output identical |

## `String.compare`, step two: `std` uses it

`String.compare` is now `__builtin_string_compare(self, other)`. Its callers are
`cmp` for String and through it every String sort. The compiler calls neither,
but `std.string` is emitted into every program that imports it, so the IR of 86
programs moved by exactly that one body. In the suite binary, 10 of 537
functions changed: `compare`, `Ord.cmp`, the closure's `call`, and the seven
String instantiations of the sort.

The compare, per call beyond reading the two elements: 1.6M random pairs of the
`sort_strings` keys, the minimum of nine inside each run, five runs alternating
the three binaries. The sort: std `sort` against `std::sort` on 80,000 elements,
the minimum of seven inside each run, five runs alternating.

| | Byte loop | Builtin | C++ |
| --- | ---: | ---: | ---: |
| compare, per call | 3.26-3.31 ns | 1.13-1.18 ns | 1.44-1.63 ns |
| sort, 80,000 `sort_strings` keys | 10.33 ms | 5.09 ms | 5.86 ms |
| sort, 80,000 random `Int`s (no String code; a control) | 3.36 ms | 3.30 ms | 0.97 ms |

So the compare is now under libc++'s, and a String sort in `std` is 0.87x of
`std::sort` where it was 1.76x.

The suite binary before and after, 15 alternating runs, checksums equal. The
last four rows are controls whose code the mnemonic diff shows unchanged:

| Benchmark | new/old min | new/old median |
| --- | ---: | ---: |
| `sort_strings` | 0.563 | 0.563 |
| `word_frequency` | 1.013 | 1.015 |
| `string_join` | 0.983 | 0.998 |
| `edit_distance` | 0.972 | 0.986 |
| `lz4_compress` | 1.012 | 1.004 |

`sort_strings` against the other languages, each pairing its own 15 alternating
runs of the suite binaries, checksums equal. The "before" column reproduces the
1.45x and 1.53x the previous results file recorded:

| | Prismio/C++ min | median | Prismio/Rust min | median |
| --- | ---: | ---: | ---: | ---: |
| before | 1.438 | 1.466 | 1.537 | 1.529 |
| after | 0.827 | 0.780 | 0.854 | 0.845 |

| Check | Result |
| --- | --- |
| Fixpoint, `src/main.psm` IR | `5731660d24e13baa08a3d4fa3f9afce8` at gen1 and gen2 |
| The seed committed in step one | a compiler bootstrapped from it builds this tree -- `std/string.psm` calling the builtin -- to the same `5731660d...`, which is what landing the builtin first was for |
| `test_143_string_compare` | PASS; `--verify` 15/14/1, 0 violations, unchanged |
| `tools/run_suite.py` | 317/317 |
| `tools/aif_differential.py` | agree on 19/19, output identical |

## `sortBy` on flat structs, and `list_set` within one flat list

Two defects on one path, both from the same fact: a flat struct is stored
inline, so `list_get` answers an address inside the list's own block.

- `listSwap` read two elements and wrote both back through `list_set`. For an
  inline element the first write overwrote the bytes the second read's address
  still named, so a "swap" duplicated one element and lost the other.
- `list_set_inline` then released the address it had copied from
  (`list_release_source`), which for a flat struct is interior to the list's
  block. `sortBy` on 200 `struct Pt { x: Int, y: Int }` aborted in `free` -- and
  so did `list_set(xs, 0, list_get(xs, 2))` on a `List<Pt>`, with no sort
  anywhere in the program. Sema accepts that line, so the unsoundness was not
  the sort's alone.

The fixes:

- **`list_swap(xs, i, j)`**, a list builtin in the family of `list_get` and
  `list_set`, lowered to a runtime call that exchanges two slots -- a pointer for
  a boxed list, `elem_size` bytes for an inline one -- with no ownership effect.
  Every element move in `std/list.psm` goes through it. It is declared only in a
  module that calls it, as the Slice family is: declared unconditionally it
  changed the IR of all 187 programs in the snapshot by one line each.
- **`list_release_source` refuses an address inside the list's own block.**
  Nothing was allocated for such a source, so there is nothing to release.

| Check | Before (step two's compiler) | After |
| --- | --- | --- |
| `sortBy` on 500 `Pt` (8 bytes), `Wide` (20), `Small` (4) and `Named` (boxed), checked for order and for each id exactly once | aborts, exit 133 | PASS |
| `test_145`: `list_set(copies, 0, list_get(copies, 2))` on an inline `List<Pt>` | aborts, exit 133 | PASS; `--verify` 2/2/0 |
| `test_144` under `--verify` | -- | 547 allocated, 546 released, 1 leaked, 0 violations. The 1 is the long String in a list that hands out an element (KNOWN_ISSUES); both fixtures are now in `run_aif_verify_test`, which fails on any violation |
| IR of every program that does not sort (180) | | byte-identical to step two |
| Fixpoint, `src/main.psm` IR | | `b2dee888333a6f23ce87dc14381ae4d9` at gen1 and gen2 |
| `tools/aif_differential.py` | | agree on 19/19, output identical |
| `tools/run_suite.py` | | 319/319 |

**A list's representation is decided for the whole program, and a fixture can
defeat itself.** The first `test_144` also held the `list_set`-within-a-list
check, and in that program both `List<Pt>` lists came out boxed, so its `Pt`
sort tested nothing about interior addresses; the previous compiler had even
reference-counted those boxes (`rc_alloc`), because the sort's own
read-then-`list_set` looked like sharing. Split into two fixtures, `test_144`'s
`Pt` list is `list_new_inline(8)` again and `test_145` is inline too -- checked
in the IR, not assumed.

**Found on the way, not fixed here:** `list_set(xs, i, list_get(xs, j))` on a
*boxed* list -- a struct holding a String -- is a double free that sema accepts:
`6 allocated, 5 released, 1 leaked, 1 violation(s)`, identically on step two's
compiler and this one. Both slots end up naming one real allocation, so no check
in the release path can tell them apart. It is in KNOWN_ISSUES with the
reproducer.

**The cost, measured.** Five runs alternating the three binaries, the minimum
of seven inside each:

| | Step two | This | C++ |
| --- | ---: | ---: | ---: |
| sort, 80,000 `sort_strings` keys | 5.21 ms | 4.63 ms | 5.93 ms |
| sort, 80,000 random `Int`s | 3.32 ms | 3.62 ms | 0.98 ms |

The String sort gains 11%, because a pair now moves as one 16-byte exchange
rather than two reads and two `list_set_str` calls, and the `Int` sort loses 9%.
Three things were tried against the `Int` loss and none recovered it:

- **Curating `list_swap`.** Measured equal -- 3.41 against 3.42 ms on Ints, 4.91
  against 4.91 on Strings -- because it was never a call to begin with: the
  runtime's bitcode is merged into each program before optimisation, so the
  partition inlines `list_swap` whether it is curated or not, 344 instructions
  with no call against 284 with four. It is not curated.
- **Fixed-width exchanges** for 4, 8 and 16 bytes instead of the byte loop:
  3.57 ms, no better.
- **A value swap for `Int` alone.** Correct for any scalar -- a scalar's
  `list_get` answers the value, not an address -- but generic code cannot
  select it: overload resolution picked `which<T>(List<T>)` over a concrete
  `which(List<Int>)` even for a direct call on a `List<Int>`.

Typed stores for the exchange, to give LLVM alias information the byte copy
does not, were not tried: over memory the rest of the program reads as a
`double` or a `void*`, a `uint64_t` store breaks strict aliasing once inlined.

The suite binary, 15 alternating runs, checksums equal:

| Benchmark | new/old min | new/old median |
| --- | ---: | ---: |
| `sort_strings` | 0.910 | 0.917 |
| `word_frequency` (its tally is a ten-element `Int` sort) | 1.046 | 1.011 |
| `string_join` | 0.962 | 0.996 |
| `csv_parse` | 0.987 | 0.979 |
| `edit_distance` (control) | 1.016 | 1.000 |
