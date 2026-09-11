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
