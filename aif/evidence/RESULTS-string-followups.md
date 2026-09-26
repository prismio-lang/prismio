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
walking up from the *entry file* (`standardModulePath`, and RUNTIME.md (now [the runtime surface](https://developers.prismio.org/runtime/supported-surface))'s table),
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

**Correction (2026-09-12): that guard never ran.** `run_runtime_library_test`
has not been in the suite's list since 9bc7d36, when the runtime stopped being a
`runtime.a`, so assertion 1b was added to a function nothing calls. The probe now
runs in `run_module_artifact_test`, the registered test that packages a
toolchain, beside the same check for `std.platform`.

## `String.compare`, step one: the builtin, unused

`src/` imports `std.string`, so the committed seed compiles `std/string.psm`,
and a builtin used there before the seed knew it would break
`tools/bootstrap.sh --seed` and every CI leg. So the order is CLAUDE.md's:
teach the compiler, refresh the seed, then use it. This step is the first two.

The lowering is `ir_str_compare`. Two inline strings compare as one unsigned
128-bit key, `bswap64(field 0)` above `rev32(word 1)`: the twelve bytes
most-significant first with the length below them, which orders exactly as the
byte loop does because an inline pair is zero past its length ([string
invariant 1](https://developers.prismio.org/compiler/string-representation#representation-invariants)). Every other pair takes `memcmp` over the shorter length and then
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

## `s_expression_parse`'s arms are not the same program

The Prismio arm stores three `Int`s per node in one flat `List<Int>`. The C++
and Rust arms allocate a node per expression (`std::make_unique`, `Box`) and
free every tree -- about 50,000 allocations and frees the Prismio arm never
pays. So the 0.71x of C++ recorded for it is a parse-and-evaluate result, not an
allocation one.

It could not be made the same program, and that is measured, on the compiler at
`727c704` and on this one alike:

| Prismio arm written as | Result |
| --- | --- |
| an enum AST, children bound with `let` and then moved into `Op` | double free (`release of a pointer that is not live`), abort |
| the same enum, children built inside the constructor call | checksum 466763307, the C++ and Rust arms' answer; leaks 14,505 of 65,719 allocations, 0 violations |
| the flat `List<Int>` it is today | checksum 466763307 |

The first crashes and the second measures allocation without the frees the other
arms pay for, so the arm is left as it is and flagged: in benchmarks/README.md
beside the accepted `mergesort` difference, and in KNOWN_ISSUES, which has the
double free as unsoundness. Once that is fixed the arm should build a node per
expression like the other two.

## `Key for String`, a word at a time

`keyHashBytes` was FNV-1a in a Prismio byte loop: a serial multiply on every byte
of every key a map looked up. It is now `str_hash` in the runtime -- eight bytes
per multiply, a tail of one to seven bytes read with two overlapping loads, the
length folded in first, and a finalizer of one multiply between two folds of the
high half. `std.key` declares it `bytes`, so a view is hashed where it lies, and
`markSingleLoopCallsiteFunctions` marks it guard-safe: unmarked, that one runtime
call would take the flat-list guard from every map's probe, `Map<Int, Int>`
included.

**The finalizer was picked by measurement.** The first draft used MurmurHash3's
fmix64. Raw cost is a C harness (`clang -O3`, the minimum of seven, the map
benchmark's own keys); displacement is std.map's table -- a power of two,
triangular probing, at most half full:

| | FNV (before) | fmix64 | one multiply (this) |
| --- | ---: | ---: | ---: |
| raw cost, 3-5 byte words | 1.49 ns | 1.60 ns | 1.14 ns |
| raw cost, 12-byte `sort_strings` keys | 4.47 ns | 1.37 ns | 1.31 ns |
| displacement, 80,000 `sort_strings` keys | 0.208 | 0.212 | 0.214 |
| displacement, 80,000 `id<N>` keys | 0.176 | 0.205 | 0.214 |
| mean displacement, 20,000 random ten-word vocabularies | 0.183 | 0.180 | 0.182 |

**A `Map<String, Int>` both ways.** `count` is 20,800 get-and-set pairs over ten
3-5 byte words, `word_frequency`'s count phase in miniature; `distinct` inserts and
then looks up 80,000 distinct 12-byte keys. Microseconds, the minimum of nine
inside each run, seven runs rotating the arms, checksums equal:

| | count min | median | distinct min | median |
| --- | ---: | ---: | ---: | ---: |
| FNV | 176 | 190 | 3604 | 3657 |
| fmix64 | 220 | 227 | 2726 | 2768 |
| one multiply | 210 | 220 | 2682 | 2733 |
| fmix64, `str_hash` noinline | 239 | 247 | 2805 | 2860 |
| one multiply, `str_hash` noinline | 212 | 219 | 2734 | 2772 |

The committed toolchain against item 3's, seven runs alternating: `count` 1.104
(min) and 1.169 (median), `distinct` 0.746 and 0.749.

**The short-key loss is a call, not the table.** Replayed exactly, FNV displaces
five of the ten words and `str_hash` one -- FNV makes 40 key comparisons a pass
to this one's 30, and is faster anyway. The disassembly says why. FNV's loop
inlined into `mapProbe` whole; `str_hash` inlined makes `mapHashOf` 79
instructions, and `mapProbe` calls it on every lookup. Marked noinline instead,
`str_hash` lets `mapHashOf` inline and the call just moves: the time does not
change. Both versions spill an inline String to a stack scratch to hand the hash
an address. The fix is to lower the hash the way `__builtin_string_compare` is
lowered -- mix an inline pair's two words in registers, 0.58 ns a key in the
harness. **Done on 2026-09-12**, as `__builtin_string_hash`:
`RESULTS-string-hash-builtin.md` has it, and the `count` shape above is 0.55x.

**The benchmark suite.** In the suite binary five functions changed, all on the
`Map<String, Int>` path -- `keyHashBytes`, `Key.hash` for String, `mapProbe`,
`mapHashOf`, `mapPlaceAll` -- and `str_hash` is new. `word_frequency` is the one
benchmark with a String-keyed map. 15 runs alternating, checksums equal; the last
four rows are controls whose code did not change:

| Benchmark | new/old min | new/old median |
| --- | ---: | ---: |
| `word_frequency` | 1.000 | 1.056 |
| `hashmap_insert_lookup` | 0.975 | 1.004 |
| `key_value_update` | 0.987 | 0.990 |
| `string_join` | 1.016 | 1.013 |
| `edit_distance` | 0.973 | 1.002 |

| `word_frequency` | Prismio/C++ min | median | Prismio/Rust min | median |
| --- | ---: | ---: | ---: | ---: |
| before | 0.704 | 0.710 | 0.743 | 0.821 |
| after | 0.706 | 0.700 | 0.740 | 0.764 |

So the suite reads it as neutral, and so does the compiler, which keys its own
maps on Strings: compiling `src/main.psm` to IR, five runs alternating, takes
4.756 s against item 3's 4.746 (min) and 4.779 against 4.757 (median).

| Check | Result |
| --- | --- |
| Fixpoint, `src/main.psm` IR | `e6eeb74e645fd08e3c7d4ed30fe8c742` at gen1 and gen2, the hash the fmix64 draft reached: only runtime C differs between them |
| The compiler's output against its own hash | item 3's compiler, which hashes with FNV, and this one build byte-identical IR from the same tree, so none of it depends on a String's hash |
| IR of 189 programs | 13 differ from item 3's: the 12 that use `std.map` or `std.key`, `src/main.psm` among them, and the new fixture. Byte-identical to the fmix64 draft's |
| `test_146_string_key_hash` | PASS: inline, heap-short, long and non-ASCII keys, the empty key and a 13-byte view find one another, then 2,000 keys of every length from 0 to 20 |
| `--verify` on that fixture | 7310 allocated, 7310 released, 0 leaked, 0 violations |
| `tools/run_suite.py` | 320/320 |
| `tools/aif_differential.py` | agree on 19/19, output identical |
| `tools/check_source_lists.py` | agree |

## Block partitioning in `sort`

`listPartitionRight` is now BlockQuicksort's partition (Edelkamp and Weiss), as
pdqsort's `partition_right_branchless` has it. Up to 64 elements a side are
classified into an offset buffer by an unconditional store and a conditional
increment, and only then are the misplaced ones swapped, in pairs -- so the
comparison feeds an add, not a branch. In the Int instantiation that is 14
conditional increments (`cinc`/`csinc`) where the Hoare scan had 3. `sortBy`
allocates the two 64-entry buffers once; a list under the insertion-sort cutoff
returns before it allocates them. The rest of pdqsort -- pivot choice, the
equal-pivot partition, the partial insertion sort, heapsort -- is unchanged.

It was an experiment first, a copy of std's sort in one program with only the
partition replaced, checked element by element against std's `sort` on random,
sorted, reversed and few-distinct Ints and on the `sort_strings` keys. The port
is checked against the experiment the same way, and agrees.

**It partitions every element type, not only scalars.** It makes the same
comparisons the Hoare scan made, so a slow comparator pays nothing extra, and it
measured faster on every representation. 80,000 elements unless noted, µs, the
minimum of seven inside each run, seven runs alternating, checksums equal:

| Input | Hoare | Block | min ratio | median ratio |
| --- | ---: | ---: | ---: | ---: |
| random Ints | 3675 | 2003 | 0.545 | 0.547 |
| `sort_strings` keys | 4731 | 2637 | 0.557 | 0.559 |
| Ints already sorted | 84 | 86 | 1.024 | 1.000 |
| the same, sorted under a reversed order | 123 | 141 | 1.146 | 1.068 |
| flat `Pt`, by one field | 3876 | 2006 | 0.518 | 0.520 |
| boxed `Named`, by a String field (20,000) | 1760 | 1037 | 0.589 | 0.607 |

C++'s `std::sort` in the same rounds: 998 µs on the Ints and 6053 on the Strings.
So an Int sort in `std` is 2.0x of C++ where it was 3.7x, and a String sort 0.44x.
Reversed input is the one that loses: every element is misplaced there, so the
bookkeeping buys nothing, 18 µs on 80,000.

The suite binary, 15 runs alternating, checksums equal. Only sort code changed in
it; the last three rows are controls:

| Benchmark | new/old min | new/old median |
| --- | ---: | ---: |
| `sort_strings` | 0.639 | 0.653 |
| `word_frequency` (its tally is a ten-element sort, now insertion sort outright) | 0.966 | 0.953 |
| `string_join` | 0.997 | 0.974 |
| `csv_parse` | 1.007 | 1.012 |
| `edit_distance` | 1.001 | 0.815 |

| `sort_strings` | Prismio/C++ min | median | Prismio/Rust min | median |
| --- | ---: | ---: | ---: | ---: |
| before | 0.749 | 0.754 | 0.807 | 0.783 |
| after | 0.494 | 0.488 | 0.526 | 0.510 |

**The port is 15% slower on Ints than the experiment it came from, and the
partition is not why.** In one binary, std's `sort` takes 2015 µs where the
experiment's copy takes 1716 on the same input. The next section is that gap.

| Check | Result |
| --- | --- |
| Fixpoint, `src/main.psm` IR | `79962ed85af2f51daaea7cdd5f8a911d` at gen1 and gen2. `src/` has no `import std.list`, yet std.list's non-generic functions are in its IR, as they are in six other programs -- so the new block-size constant moves the compiler's IR by that one unused function, and this change got the full bootstrap |
| The committed seed | a compiler bootstrapped from it builds this tree to the same `79962ed8...` |
| IR of 189 programs | 7 differ from the previous step's: exactly the 7 that carry std.list |
| `test_142`, `test_144`, `test_145`, `test_89`, `test_141` | PASS, against the previous `std.list` and this one |
| `--verify` | `test_142` 1110 -> 1114 allocated, all released; `test_144` 547/546/1 -> 563/562/1, 0 violations, the 1 the known long String; `test_145` 2/2 |
| `tools/run_suite.py` | 320/320 |
| `tools/aif_differential.py` | agree on 19/19, output identical |
| docs | `stdlib/lists.md` still described the three-way quicksort pdqsort replaced; rewritten in the website repository and left uncommitted there. Its content audit passes on 101 pages, and all 185 compiler-checked examples pass against this toolchain |

## `list_swap`, called directly

The port of the block partition sorted Ints 15% slower than the experiment it
was copied from, in one binary on one input, with the same partition. Built with
the new toolchain, the experiment's source carries both: its "std" arm is the
port. Six variants of the experiment, each binary also carrying std's sort as a
control. µs, the minimum of seven inside each run, five rounds rotating the arms;
every variant agreed element by element with std's sort:

| Variant of the experiment | Ints | Strings |
| --- | ---: | ---: |
| as measured | 1716 | 2690 |
| the partition swaps through a wrapper | 1643 | 2639 |
| the block size is read from a function | 1685 | 2624 |
| both | 1622 | 2588 |
| every helper swaps through a wrapper | 1974 | 2630 |
| the port's partition structure | 1684 | 2645 |
| std's sort, in each binary | 1984-2015 | 2602-2634 |

Only the fifth reproduces the port. std's helpers -- insertion sort, `listSort3`,
heapsort, the left partition -- moved elements through `listSwap`, a one-line
wrapper around `list_swap`, and the wrapper changes the loop it is called from.
`irBodyMovesNoBlock` counts `list_swap` as settled, so the wrapper is proved to
move no block and the flat-list guard looks through it; `irFlatGuardCount` does
not recognise a direct `list_swap`, and declines the loop. Through the wrapper,
insertion sort's inner loop was versioned: 182 lines of IR and 21 blocks against
76 and 9, 216 instructions for Ints against 143. That loop is entered once per
element and runs a few iterations, and a guard is paid per entry -- the
`mapProbe` result again (`RESULTS-map-probe-loop-guard.md`).

So every move calls `list_swap` directly, and the wrapper is gone. Against the
previous commit, measured as in the section above:

| Input | Before | After | min ratio | median ratio |
| --- | ---: | ---: | ---: | ---: |
| random Ints | 2007 | 1696 | 0.845 | 0.833 |
| `sort_strings` keys | 2633 | 2648 | 1.006 | 1.016 |
| Ints already sorted | 86 | 92 | 1.070 | 1.070 |
| the same, sorted under a reversed order | 141 | 157 | 1.113 | 1.142 |
| flat `Pt`, by one field | 2023 | 1773 | 0.876 | 0.875 |
| boxed `Named`, by a String field (20,000) | 1065 | 1053 | 0.989 | 1.021 |

In one binary, std's sort now takes 1693 µs on the Ints to the experiment's 1690.
C++ in the same rounds took 997, so an Int sort in `std` is 1.70x of C++ -- 3.7x
before block partitioning. String and boxed lists have no flat guard either way
and did not move. Sorted and reversed Ints did: those are the loops the guard was
helping, 6 and 16 µs on 80,000.

The suite binary, 15 runs alternating, checksums equal:

| Benchmark | new/old min | new/old median |
| --- | ---: | ---: |
| `sort_strings` | 1.013 | 0.994 |
| `word_frequency` | 0.986 | 1.003 |
| `string_join` | 1.003 | 1.009 |
| `csv_parse` | 0.997 | 1.009 |
| `edit_distance` (code unchanged) | 1.162 | 0.999 |

`sort_strings` stays 0.493x of C++ and 0.516x of Rust.

**The guard is unchanged, deliberately.** Teaching `irFlatGuardCount` to recognise
`list_swap` would be sound -- it moves no block -- and would version these loops
again. What the per-entry law asks for is a trip-count estimate, which is
KNOWN_ISSUES' open policy question about the guard, not something to settle in
`std`.

| Check | Result |
| --- | --- |
| IR of 189 programs | 6 differ from the previous commit's: the std.list carriers except `src/main.psm`, which does not change -- `listSwap` was generic and never emitted there -- so the compiler needed no bootstrap |
| `test_142`, `test_144`, `test_145`, `test_89`, `test_141` | PASS, against the previous `std.list` and this one; the `--verify` ledgers are identical to the previous commit's |
| Against the experiment | agrees element by element on four Int shapes and the `sort_strings` keys |
| `tools/run_suite.py` | 320/320 |
| `tools/aif_differential.py` | agree on 19/19, output identical |
| The comment above `list_swap`'s callers | written after the runs above. It moves `std/list.psm`'s lines, and a closure is named by its line, so the five programs that call `sort` rename theirs (`Closure$336$2` to `Closure$345$2`). Compiled from the committed tree, each is identical to the measured IR once closure line numbers are normalised; `test_144` and `src/main.psm` are byte-identical |
