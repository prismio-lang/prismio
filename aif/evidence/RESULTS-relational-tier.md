# The relational tier, byte-sized Bool elements, and three gaps read from disassembly

Status: measured on the working tree of 2026-09-23, committed 2026-09-24, on top of the
loop range proofs in `RESULTS-loop-range-proofs.md`. Measurements are in-process
`elapsed_ns` from `benchmarks/build/*-suite`, arms alternating, minimum reported
with the median, checksums equal. The base is the verified range-proof tree
(bootstrapped twice from the 0416128 host, suite 375/375, AIF differential equal
to the 0416128 compiler's apart from the compiler path).

## What changed

- **`src/ir/dbm.psm` (new)**: a difference-bound matrix -- `x_i - x_j <= c` for every
  pair of n variables, closed by Floyd-Warshall -- with assignment `x := y + c`,
  incremental assumption, join, widening and inclusion.
- **`src/ir/relations.psm` (new)**: the loop analysis over it, run from `rangeFinish`
  after the delta tier's emission, `while` loops only.
  - Variables: a zero; the `Int` locals the body assigns, each with a frozen start;
    body `let`s, tracked only while in scope; invariant locals and stable
    `list_len`s as anchors, which the preheader can evaluate.
  - Transfers: `x := y + c`, `x := c`, the midpoints `y + (z - y) / c` and
    `(y + z) / 2` (x in [y, z] where the state implies y <= z), assumptions from the
    condition's conjuncts, `if` branches (negated for the else) and `and`/`or`
    operands, joins at merges. A nested loop forgets what it assigns; a `continue`
    naming this loop from inside it reaches the back edge in that state.
  - Fixpoint: joins for two rounds, then widening, closure after each, and an
    explicit inclusion test for inductiveness (twelve rounds or give up).
  - Soundness: an operation is *interpreted* only where its variable is bounded on
    both sides by anchors, so every interpreted `+`/`-` has a range over preheader
    values; that range is folded into the guard (inside `Int`) and the node is
    marked, so the proved copy emits it `nsw`. An unbounded one is uninterpreted
    and forgets its target, which is stricter than failing the loop. Decisions
    depend on the state and never on the walk mode, so the emission walk is the
    verifying walk with IR attached.
  - Accesses the delta tier left are proved from the index term's anchor bounds.
    `ir_range_proof_marked` (new, `runtime/ir_symbols.c`) reads a node's mark
    whatever `PRISMIO_RANGE_PROOFS` says, which is how the tier skips the delta
    tier's accesses.
- **Bool list elements are bytes** (`runtime/llvm-api-backend.c`,
  `element_memory_type`): the flat push, get and set store `zext i1 -> i8` and load
  `icmp ne i8 %b, 0`, the way clang handles a `bool`.

## Numbers (scale 4)

| benchmark | base | now | C++ |
|---|---:|---:|---:|
| binary_search | 88.2 ms | **69.9** | 71.6 |
| prime_sieve | 0.548 | **0.494** | 0.502 |

binary_search's proved copy has `nsw` on all five operations (`high - low`, the
midpoint's add, `high + 1`, `mid + 1`, `mid - 1`) and no check on `values[mid]`, as
the C model predicted (nsw + check 75 ms, wrapping without check 126). The guard is
`high0 - low0 <= INT_MAX`, `high0 + 1 <= INT_MAX`, `low0 - 1 >= INT_MIN`,
`low0 >= 0`, `high0 < len`.

Full 62-benchmark A/B of the final tree against base (9 alternating rounds, min/median
ratios): binary_search 0.791/0.790, prime_sieve 0.897/0.896, no result mismatches.
Eight functions differ from base by mnemonics: those two, quicksort and base64
(noise-level, 1.018/1.000 and 1.001/1.000), and fibonacci, gcd_lcm, graph_bfs and
branch_mispredict, which differ only by alignment `nop`s or register choice. The one
other reading outside noise, tokenization at 1.04-1.05 over 21 rounds, is placement:
its functions are mnemonic-identical and `_benchTokenization__Int` moved 512 bytes.

## Findings worth keeping

- **`store i1` is not a byte store to LLVM.** A `Vec<Bool>` fill ran as merged
  4-byte stores (unrolled, not vectorised, no memset) because the vectoriser
  scalarises `i1` and LoopIdiomRecognize cannot read `i1 true` as a byte pattern.
  `nsw` on the push's length bump -- the first theory -- changed zero functions and
  was dropped.
- **AArch64's Apple runtime-unroll heuristic keys on `br (icmp ...)` fed by a loop
  load.** A Bool read as `trunc i8 to i1` is not an icmp, so prime_sieve's counting
  loop stayed rolled while C++'s byte test unrolled by eight. Found by feeding
  clang's IR for the C++ loop through the same `opt -O3 -mcpu=apple-m1`: it
  unrolled, Prismio's did not, and the diff was the branch's shape.
- **lz4's checks cost nothing; its gap is not in the main loop.** A C model of all
  three variants (every access checked as Prismio does, the six provable ones
  unchecked, none checked) ran in the same time. Phase timing of a standalone copy
  put 312 us of 404 in the *input fill*. Versioning push loops on the capacity guard
  made that loop instruction-for-instruction C++'s (length in a register, base
  hoisted) and measured no change -- 312 vs 316 us -- so it was reverted. An
  instruction-identical C loop runs the fill in 237 us; the remaining difference is
  not in the loop's code, not the clock ramp (a 50 ms pre-spin changes neither), not
  first-touch paging (a second fill in-process is no faster), and not the allocation
  (4 us). Unresolved.
- **quicksort's scan loops**: C++ is five instructions per element, Prismio seven --
  the bounds check and a `data` reload LLVM cannot speculate out of the in-bounds
  arm. Hoisting the condition receiver's header measured zero last session; the
  check itself needs an existential invariant (a sentinel lies ahead), which no
  difference domain expresses.
- **Store speculation has no target left in this suite.** flat_bitset already runs
  at 0.86x of C++ and knapsack at parity since its arms were matched.

## Tests

- `tests/test_169_loop_range_proofs.psm`: bisection through `low + (high - low) / 2`
  and through `(low + high) / 2`, each run in range, past either end, and with a
  span or bound that wraps; a midpoint of unordered bounds; a nested loop that moves
  `high`. Expected values come from a Python model of the semantics (32-bit wrap,
  out-of-range read 0). The two bisections are `// range: 1/1` (0/1 before).
- `tests/test_132_counted_fill.psm` + `counted_fill_codegen`: a `Vec<Bool>` fill,
  masked sets and a count, run inline and boxed; the IR must store Bool elements as
  `i8` and read them with `icmp ne i8`. The check fails on the previous compiler.

The split of the domain into `dbm.psm` was verified behaviour-preserving: fixpoint
across two generations, and byte-identical IR against an exact pre-split compiler
for all 187 programs in `tests/test_*.psm` and `aif/corpus/`.
