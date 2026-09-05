# Single-probe updates and direct entry lookup

Measured 2026-09-05. This follows `RESULTS-map-probing-wide-hash.md`; its baseline
already includes triangular probing, half occupancy, and full-width integer
hashing. Stage 1 compiler/runtime changes are shared by every arm and are not
attributed to this standard-library change.

## New API

```prismio
mapUpdate(counts, key, |value: Int| value + 1)
```

`mapUpdate(m, key, callback)` updates an **existing** value. It performs one key
lookup, calls the callback once with the old value, and stores its return value.
It returns true on a hit. On a miss it returns false, does not call the callback,
and does not insert a key. The update itself does not change insertion order.
This is not an upsert API, and it retains Map's existing limitations on owned
value types.

The callback is statically specialized: closures and objects with a `call`
method work. The implementation uses `update.call(...)`; shorthand `update(...)`
only recognized compiler-generated closures, which the explicit method call
avoids. There is no per-update heap allocation in the measured workload.

## Existing callers also benefit

`mapIndexOf` used to call `mapSlotOf`, then load the bucket again to recover the
entry index. That repeated both a load and the total-list bounds check.

A shared private `mapProbe` now returns either the bucket position (insertion)
or the entry index (lookup). Its callers pass a constant mode. The key hashing,
collision sequence, occupancy policy, memory layout, and public lookup semantics
are unchanged. This avoids duplicating the probe loop or packing two return
values into an integer, an earlier experiment that did not pay off.

The generated `mapGetOr<Int, Int>` drops from 94 to 75 instructions;
`mapIndexOf<Int, Int>` drops from 72 to 61. Smaller helpers also change inlining
in the benchmark callers. The mnemonic diff changes only map-related bodies.

## Controlled measurements

Fifteen measured samples per arm after two warmups, with rotating/reversed
execution order. All sources are copied into isolated trees before building;
the compiler binary and its hash are fixed. The saved `map-before.psm` is the
accepted library at the beginning of this continuation, not the original Git
version before the preceding optimization pass.

The maintained benchmark sources are **unchanged**. Only the isolated
`after_update` copy changes its update statement to use the new API. The
workload remains 80,000 entries, 20 update rounds, and checksum 5,599,628.

| Prismio arm | Update ms | Insert/lookup ms |
|---|---:|---:|
| Before this pass, existing API | 11.315 | 7.311 |
| After this pass, existing API | 10.993 | 7.002 |
| After this pass, `mapUpdate` | 7.222 | 6.956 |

Existing callers gain **2.8%** on updates and **4.2%** on insert/lookup. Adopting
`mapUpdate` makes the update workload **1.57x faster than before this pass**,
or **1.52x faster than the improved two-lookup expression**. The second baseline
arm differs by -0.31% and +0.20%, respectively.

The insert/lookup code is identical in the two after arms; their 0.6% difference
is not attributed to the unused update API.

### Compare equal access counts

The original C++ update expression uses two accesses, while Rust already uses
one `get_mut`. An isolated C++ arm was also changed to `++map.at(i)` so every
single-lookup arm updates existing keys through one lookup. All entries exist;
these workloads do not compare the APIs' different missing-key behavior.

| Update implementation | Median ms |
|---|---:|
| C++ original two-access expression | 5.550 |
| C++ single-access expression | **3.061** |
| Rust existing `get_mut` | 8.549 |
| Prismio `mapUpdate` | 7.222 |

Prismio is **15.5% faster than Rust in this run**, but still **2.36x slower than
the equivalent single-lookup C++ arm**. Comparing only against the original
C++ expression would understate the remaining gap. No generally faster-language
claim follows from this result. Flags remain C++ `-O3 -std=c++20`, Rust
`-C opt-level=3 --edition=2021`, and Prismio's normal release build; no native
CPU flag was added. Toolchain versions and source/compiler hashes are in JSON.

## Memory and correctness

- Full suite: **296/296**, including the new `test_map_update.psm`.
- Two-generation compiler IR fixpoint: byte-identical SHA-256
  `76fb572c59a0294ac28c645f162daeac0110401ecb3512bc80dbc5a018c3a1c6`.
- All **34 benchmark checksums agree across all six arms**, including the
  isolated API substitutions in Prismio and C++.
- All 34 verification runs in each Prismio arm report **zero violations** and
  the same two pre-existing benchmark-process leaks tracked as MEM-038.
- The update workload has **58 allocations and 2,621,782 peak live bytes in
  every Prismio arm**. This pass adds no allocation count or peak-memory cost.
  The wider index introduced by the preceding pass remains in place.
- The new regression test reports **328 allocated / 328 released / zero leaks
  / zero violations**. It covers empty and missing keys, negative constant-hash
  collisions through repeated growth, insertion order, Bool and I64 values,
  captured scalars, owned String captures, equal-content String keys, and
  custom callable objects. Observable scalar counters assert exactly one hash
  and one callback on a hit, and no callback on a miss.

The full release gate was not rerun for this library-only change; the full
compiler suite and fixpoint were run directly with named compiler generations.
The project host was not replaced.

## An existing ownership defect exposed by the tests

The first observable counters used `List<Int>` fields inside a custom key.
That query key leaked its counter list. A reduced program using only the old
`mapSet` and `mapGetOr` APIs reproduces it with both library versions:

```
14 allocated, 12 released, 2 leaked, 0 violations
56 live bytes
```

`owned-key-existing-leak.psm` and both before/after logs preserve that evidence.
It is separate from the benchmark-process leaks and is not fixed by this pass.
The production regression uses scalar counters to test call counts, while
retaining leak-checked owned String keys and callback captures. The reproducer
should inform subsequent ownership analysis; these results do not establish
leak freedom for every heap-containing user key type.

## Reproduce

```bash
python3 aif/evidence/map-update-2026-09-05/measure.py \
  --compiler build/map-update/compiler --runs 15
PATH=/opt/homebrew/opt/llvm/bin:$PATH \
  python3 tests/test_runner.py --compiler build/map-update/compiler
PATH=/opt/homebrew/opt/llvm/bin:$PATH \
  build/map-update/compiler build tests/test_map_update.psm --verify \
  -o build/map-update/check-update
build/map-update/check-update
```

Raw timing samples, checksums, verification ledgers, generated-code summaries,
and the library baseline are in `map-update-2026-09-05/`.

The next performance question is the remaining **one-lookup** gap: probe/load
overhead and table layout, measured against the 3.06 ms C++ arm. A general
entry/upsert API remains distinct work; `mapUpdate` intentionally handles only
existing entries.
