# Map probing and full-width key hashing

Follow-up: `RESULTS-map-update.md` records direct entry lookup and the new
single-probe `mapUpdate` API. The measurements below remain this first pass's
record; the later report uses this implementation as its baseline.

Measured 2026-09-05 on Apple Silicon, macOS 26.6.2, Homebrew LLVM 22.1.8,
Rust 1.97.1. This is a partial implementation of Stage 2.1 (MEM-034/MEM-014),
plus a previously unlisted wide-integer hashing defect. No Stage 1 compiler or
runtime sources were edited by this work.

## Changes that shipped

`std/map.psm` retains its dense keys/values arrays, four-byte bucket indices,
insertion-order iteration, generic `Key + Copy` support, and existing API.

- Probe using triangular offsets: increments of 1, 2, 3, ... visit all buckets
  in a power-of-two table and reduce primary clustering.
- Grow above half occupancy. Only the bucket index becomes sparser; owned keys
  and values are not duplicated. The threshold comparison also avoids the old
  `count * 4` arithmetic overflow.
- During rehash, search for an empty bucket without comparing already-unique
  keys. The rehash routine drops from 147 to 119 machine instructions.

`std/key.psm` previously discarded the high 32 bits before hashing `I64`, `U64`
and `Usize`. Keys of the form `(i << 32) | 17` consequently all hashed alike.
They now pass through the unsigned MurmurHash3 64-bit finalizer before narrowing
to the existing nonnegative `Int` hash result. All input bits participate;
negative signed keys retain their bit pattern. `Int`, `U32`, String and user
hash implementations are unchanged. Hash outputs for wide integers do change.

## Maintained benchmark results

The benchmark sources and compiler are identical between arms; only the two
standard-library files differ. Eleven measured samples follow two warmups,
with rotating/reversed execution order. A second baseline arm executes the
same binary to calibrate A/A noise. C++ uses `-O3 -std=c++20`, Rust uses
`-C opt-level=3 --edition=2021`; native CPU flags were not added to any arm.

| Workload | Before ms | After ms | Speedup | C++ ms | Rust ms |
|---|---:|---:|---:|---:|---:|
| key_value_update | 18.302 | 11.757 | **1.56x** | 5.665 | 8.716 |
| hashmap_insert_lookup | 9.398 | 7.326 | **1.28x** | 6.912 | 7.938 |

The second baseline differs by -0.70% and +0.53%, respectively. Insert/lookup
is now 7.7% faster than Rust and 6.0% slower than C++ in this run. Updates remain
2.08x C++ and 1.35x Rust: this does not establish a generally faster language.

All **34 workload checksums agree across baseline, candidate, C++ and Rust**.
The mnemonic diff changes only nine map/key-related functions and introduces
the wide mixer. Other workload timings still move with placement and noise:
for example, tokenization reads +8.9% in this sweep without a changed mnemonic
sequence. Do not claim improvements or a blanket absence of timing regressions
for unrelated workloads from this change.

## Memory cost

The verification ledger prices the throughput tradeoff directly:

| Workload | Before peak live bytes | After peak live bytes | Change |
|---|---:|---:|---:|
| key_value_update | 1,835,344 | 2,621,776 | +42.8% |
| hashmap_insert_lookup | 5,243,221 | 5,243,221 | unchanged |

Updates finish with twice as many bucket indices and incur one additional
growth allocation (57 -> 58 total ledger allocations, including CLI storage).
Insert/lookup finishes with the same power-of-two capacity; its benefit comes
from shorter probes during growth and the cheaper rehash path.

## Supplemental workloads

`map-probe-2026-09-05/probe.psm` measures aligned integer keys, long String keys,
and keys differing only in their high word, with both hits and misses. It does
not replace any maintained benchmark or compare against another language.

| Workload / entries | Before ms | Map changes only ms | Full change ms |
|---|---:|---:|---:|
| High-word U64 / 1,024 | 1.867 | 1.693 | 0.039 |
| High-word U64 / 4,096 | 26.300 | 24.952 | 0.121 |
| High-word U64 / 8,192 | 105.171 | 99.404 | 0.241 |

The last row is **437x faster**, specifically on the old hash's degenerate input
family. Keeping the old hash with the new map separates the hash fix from the
container improvement. It is not a 437x claim about normal maps. The supplemental
aligned-Int cases cover 128 through 131,072 entries, and String cases cover 128,
2,048 and 8,192; complete samples are retained in the JSON, including small
measurements whose absolute times are especially noise-sensitive.

## Rejected experiments and research

A cached 32-bit hash packed with an entry index in an eight-byte bucket sped up
updates by about 7-8%, but slowed insert/lookup by about 12-14%. Adding triangular
probes did not remove that regression. Returning a packed `(bucket, entry)` from
the probe to avoid reloading the bucket also failed to improve both workloads.
Neither experiment remains in production.

The accepted design combines established techniques; it is not claimed as a new
hash-table algorithm. The relevant primary references are
[LLVM 18's DenseMap implementation](https://github.com/llvm/llvm-project/blob/release/18.x/llvm/include/llvm/ADT/DenseMap.h)
for triangular probing and
[Austin Appleby's MurmurHash3 implementation](https://github.com/aappleby/smhasher/blob/master/src/MurmurHash3.cpp)
for full-width mixing. The metadata experiments were informed by
[Abseil's Swiss-table design](https://abseil.io/about/design/swisstables) and
[unordered_dense's indexed bucket layout](https://github.com/martinus/unordered_dense/blob/main/include/ankerl/unordered_dense.h).
Prismio's insertion-order contract rules out blindly replacing the current
table with ordinary flat Swiss-table storage. A future SIMD index can preserve
dense insertion-order entries, but must first beat this baseline on both time
and memory; no SIMD implementation is claimed here.

## Validation and reproduction

- Full compiler suite: **294/294**, including the concurrently added Stage 1
  stencil test. Tested with a named generation, without promoting over the
  other agent's project host.
- Two-generation compiler IR fixpoint: byte-identical SHA-256
  `b219a201386d367e3944f86249905f31ff0a5c24aefcdab4a6bc45c38a317f12`.
- `test_map_probe.psm`: negative constant-hash collision chains, wraparound,
  repeated growth, overwrites, insertion order, missing keys, Options, and
  owned long String keys. Under `--verify`: 1,817 allocated / 1,817 released,
  **0 leaked / 0 violations**.
- `test_key_wide.psm`: signed/unsigned/pointer-width keys, high-word bucket
  distribution, negative values and integer extremes. Under `--verify`:
  123 allocated / 123 released, **0 leaked / 0 violations**. Compiling the same
  fixture against the original library exits 3 at the clustering assertion.
- All 34 benchmark verification runs: **zero violations** and unchanged
  checksums. Both arms retain exactly **two pre-existing CLI leaks (MEM-038)**;
  these are not claimed fixed. No release-gate rerun was performed for this
  standard-library-only change; the full test suite and fixpoint were run directly.

```bash
PATH=/opt/homebrew/opt/llvm/bin:$PATH \
  python3 tests/test_runner.py --compiler build/map-opt/gen2
python3 aif/evidence/map-probe-2026-09-05/measure.py \
  --compiler build/map-opt/gen2 --runs 11
PATH=/opt/homebrew/opt/llvm/bin:$PATH \
  python3 tools/fn_mnemonic_diff.py \
  build/map-opt-measure/baseline/suite build/map-opt-measure/candidate/suite
```

The measurement tool snapshots source inputs, builds separate std trees, and
records compiler/source hashes. Its original map/key baseline is commit
`43107cff86c140fbf130c27211379d775d25c727`; those two files were byte-identical to
the working tree when this task started. Full samples, ledger measurements,
and the mnemonic diff are in `map-probe-2026-09-05/`.

## Remaining critical gaps

1. Updates still perform `mapGetOr` followed by `mapSet`, each probing the key.
   Rust's benchmark uses a single `get_mut`; C++ spells two accesses but uses a
   different integer hash and table layout. A generic single-probe update/entry
   API is the next concrete library experiment. Compare equivalent access
   patterns before attributing the whole remaining gap to compiler codegen.
2. A group-probed index preserving insertion order is still open. Full-width
   hashing must precede fingerprint/SIMD experiments: metadata cannot repair a
   hash that discarded the distinguishing bits.
3. Tree traversal and FFT are the next large non-map gaps in this sweep. Enum
   representation and loop lowering overlap the other agent's Stage 1 work.
   Their changes are deliberately not mixed into these map measurements.
