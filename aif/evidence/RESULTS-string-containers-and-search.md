# Results: the string-benchmark gap (2026-09-11)

`prismio bench` had five string workloads at 1.3x-2.1x of C++. This records what
each one was paying for, what changed, and what is still open. Every number is on
an Apple M-series Mac with LLVM 22.1.8, against `clang++ -O3 -std=c++20` and
`rustc -C opt-level=3`, with checksums equal across the arms compared.

## Method

Three instruments, because the harness number alone pointed at the wrong cause
twice.

- **Interposed libc counts.** A `DYLD_INSERT_LIBRARIES` shim counting `malloc`,
  `free`, `strlen`, `memcpy` and `memcmp` per process. It found the root cause of
  three benchmarks in one run: calls that should not exist.
- **Phase timing.** Each workload rewritten with `clock_gettime` between its
  phases, in Prismio and C++, minimum of nine alternating runs. It showed which
  half of each benchmark held the gap -- and that `string_search`'s `repeat`,
  the first suspect, was already 0.32x of C++.
- **Alternating A/B of the suite binary** (15 runs, the input fixture
  `benchmarks/run.py` generates), with the baseline binary saved before the first
  runtime edit: once `runtime/*.c` changes, an older packaged compiler refuses to
  build in-tree.

## Root causes

| Benchmark | Was | Cause |
| --- | ---: | --- |
| `sort_strings` | 2.11x | 5,748,630 `strlen` and 80,029 `malloc`: a `List<String>` slot was one word, so every short string was boxed on the way in and re-measured on every read. Then the sort itself. |
| `string_join` | 1.72x | 2,612,792 `strlen`: `strJoin` called `list_get` once per *byte*; and 240,030 `malloc` from the slot boxing. |
| `word_frequency` | 1.57x | 85,011 `strlen` (slot reads in the map probe), 20,876 `malloc` (one per split word), 47,992 `memcmp` (map keys were heap copies, so equality never took the inline fast path). |
| `s_expression_parse` | 1.88x | `allText = allText + expr + "\n"` took the immutable concat and re-copied the accumulator every iteration: a quadratic build phase, 3.00 ms against C++'s 0.93 ms. Its parse half was already 0.5x of C++. |
| `string_search` | 1.40x | Not the scan: 32M searches in steady state run at 1.1x of C++, before and after. The one-shot gap was per-call setup -- six out-of-line rank calls per `indexOf` -- and a runtime crossing per candidate. |

## Changes

1. `s = s + a + b ...` appends in place: `str_append_reuse_many`, one call, every
   aliased suffix rebased. `s_expression_parse` **0.374x**.
2. A short-needle search is one runtime call, `str_find_needle`.
   `string_search` **0.728x**.
3. `strJoin` reads each part once. `string_join` **0.733x** before (4).
4. `List<String>` stores the 16-byte pair: `list_str_data`, `list_str_word`,
   `list_push_str`, `list_set_str`, and `AIF_ELEM_STRING` for teardown. After it,
   190 `strlen` and about 30 `malloc` on both list benchmarks.
5. The split functions keep a part of twelve bytes or fewer inline.
6. `strClone` keeps twelve bytes or fewer inline, so map keys stored through
   `copyOf` compare as two integers. `word_frequency` with (5) and (6): 20,876
   `malloc` to 57, and 47,992 `memcmp` to 0.
7. `sort` is pdqsort.

Phase timings after (4), minimum of nine:

| Phase | Before | After | C++ |
| --- | ---: | ---: | ---: |
| `sort_strings` build | 1.83 ms | 1.06 ms | 1.69 ms |
| `string_join` build | 3.86 ms | 1.69 ms | 2.62 ms |
| `string_join` join | 2.86 ms | 0.60 ms | 1.10 ms |
| `s_expression_parse` build | 3.00 ms | 0.80 ms | 0.93 ms |

`std` sort on 80,000 elements, minimum of five:

| Input | Three-way quicksort | pdqsort | C++ `std::sort` |
| --- | ---: | ---: | ---: |
| random `Int` | 4.09 ms | 3.39 ms | 1.04 ms |
| sorted `Int` | 16.56 ms | 0.086 ms | |
| reversed `Int` | 12.24 ms | 0.141 ms | |
| 16 distinct `Int`s | 0.82 ms | 0.81 ms | |
| random `String` | 10.83 ms | 10.31 ms | 6.16 ms |

## The suite, before and after

Alternating A/B of the suite binary before this work against the final one, 15
runs each, checksums equal. The last four rows are controls: a per-function
mnemonic diff of the two binaries shows their code did not change (30 of 504
functions did, all of them string, list, map or sort code), so they measure
layout and noise.

| Benchmark | new/base min | new/base median |
| --- | ---: | ---: |
| `string_join` | 0.333 | 0.339 |
| `s_expression_parse` | 0.385 | 0.378 |
| `word_frequency` | 0.464 | 0.450 |
| `sort_strings` | 0.700 | 0.701 |
| `string_search` | 0.731 | 0.710 |
| `line_processing` | 0.960 | 0.972 |
| `tokenization` | 0.984 | 0.952 |
| `csv_parse` | 0.996 | 0.998 |
| `edit_distance` (unchanged) | 1.001 | 0.977 |
| `lz4_compress` (unchanged) | 1.024 | 1.027 |
| `dijkstra_shortest_path` (unchanged) | 0.989 | 0.995 |
| `channel_pipeline` (unchanged) | 0.940 | 0.951 |

Against the other languages, from the full `benchmarks/run.py` pass (medians of
five) compared with the one recorded before the work:

| Benchmark | Prismio/C++ before | after | Prismio/Rust before | after |
| --- | ---: | ---: | ---: | ---: |
| `sort_strings` | 2.03 | 1.45 | 2.45 | 1.53 |
| `s_expression_parse` | 1.99 | 0.71 | 1.25 | 0.46 |
| `string_join` | 1.62 | 0.63 | 0.97 | 0.29 |
| `word_frequency` | 1.53 | 0.70 | 1.65 | 0.74 |
| `string_search` | 1.31 | 0.96 | 0.76 | 0.57 |

Across all 62 workloads the median is 0.999x of C++ and 0.995x of Rust. The
cross-day pass read `edit_distance` at 1.17x of itself; the alternating A/B above
reads it at 1.00, and its code is byte-identical -- the reason to trust the
alternating measurement over two separate runs.

## Bugs found on the way

Fixed: a String literal stored into a container was freed at teardown (an
untagged `.rodata` pair; 2 violations for three `list_push`es of literals); a
struct's String field freed its text when the string was short (the generated
release loaded field 0 alone, and released 0x30, 0x31, 0x32). Open, in
KNOWN_ISSUES.md: `sortBy` on a flat-struct list frees an interior pointer;
`sort()` does not link from a packaged `.plib`; a list that hands out its
elements is never released.

## Still open

- **The String compare is 2x C++'s.** 1.6M random-pair compares over the
  `sort_strings` keys cost 3.15 ns each in Prismio beyond reading the pair, and
  1.56 ns in C++. That is about half of the random-String sort's remaining gap.
  Two inline strings order like their zero-padded pairs, so a builtin can compare
  them as two byte-swapped integers; it needs the two-step seed landing.
- **Random-input sort on `Int`s** has no libc call left in it; the rest is branch
  mispredictions, which libc++ removes with branchless (BlockQuicksort)
  partitioning for arithmetic types.
- **The String hash** is FNV with a serial multiply per byte. A word-at-a-time
  hash would cut `word_frequency`'s count phase further.
