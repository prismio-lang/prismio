# `key_value_update`: one probe in `mapSet`, and a loop guard that is a net loss

Measured 2026-09-05, on top of `RESULTS-scoped-alias-metadata.md` (E5). Continues
`RESULTS-map-probing-wide-hash.md` and `RESULTS-map-update.md`, whose triangular
probing, half occupancy, wide integer hashing and single-probe `mapUpdate` are in
every arm here and are not re-attributed.

`key_value_update` was the worst ratio in the matrix at **1.985x of C++**. This
pass takes it to **1.88x** — `10.942 -> 10.511 ms`, ratio **0.961** — with a
four-line change to `std/map.psm`, and refutes the compiler-side lever that
looked twice as promising.

## Where the time is

Phase-timed at the benchmark's scale (`scale = 4`, n = 80,000), one shot per
process, both languages, `kvphase.psm` / `kv.cpp`:

| Phase | Prismio | C++ | ratio |
|---|---:|---:|---:|
| insert (80,000 `mapSet`) | 1.98 ms | 1.29 ms | 1.53x |
| **update (1,600,000 iterations)** | **11.6 ms** | **4.5 ms** | **2.6x** |
| checksum (80,000 `mapGetOr`) | 0.41 ms | 0.20 ms | 2.0x |

The update loop is **82%** of the benchmark. 1.6M iterations at 11.6 ms is
7.25 ns each, against C++'s 2.8 ns. Both arms write two lookups —
`mapSet(map, k, mapGetOr(map, k, 0) + 1)` against `map[i] = map.at(i) + 1` — so
the comparison is of two probes against two probes.

Disassembling `_mapProbe$Int$Int` gives the per-probe cost exactly: **9 loads and
5 branches**, of which **two loads are the data**. The other seven are the
container headers — `slots.elem_size`, `slots.data`, `m.keys`, `keys.len`,
`keys.elem_size`, `keys.data` — re-read inside the loop because they sit under
the bounds-check branch, where LICM may not speculate them.

## What was built: `mapSet` stops asking a question the probe answered

`mapProbe(m, key, findSlot: true)` returned the bucket position whether the key
was there or not, so `mapSet` re-read `slots[at]` to find out which — a load, a
bounds check and a representation test for an answer the probe had already
computed and discarded.

Both modes now answer a **hit** with the dense entry index. They differ only in
what a miss is: `findSlot` reports its empty bucket as `-bucket - 2`, a lookup
reports `-1`. A bucket is in `[0, mask]`, so `-bucket - 2` is at most `-2` and
cannot collide with an entry index or with the lookup miss. The `if (findSlot)`
inside the probe's hit path disappears with it, so the probe gets simpler as well
as the caller.

One compiler, two standard libraries — the only difference between the arms is
`std/map.psm`. The mnemonic diff over the whole benchmark suite is two functions:
`mapSet` 179 -> 159 instructions, `mapProbe` 60 -> 64.

| Benchmark | before ms | after ms | ratio | noise |
|---|---:|---:|---:|---:|
| **key_value_update** | 10.942 | **10.511** | **0.961** | 0.998 |
| hashmap_insert_lookup | 6.915 | 6.854 | 0.991 | 0.993 |
| graph_bfs | 0.731 | 0.724 | 0.989 | 0.989 |
| tokenization | 0.144 | 0.145 | 1.005 | 1.017 |

31 samples after 6 warmups, rotating order, one process per sample. The `noise`
arm is a second run of the same before-binary.

## What was refuted: the flat guard for `loop` and `for`

The obvious lever was the other seven loads. `generateLoopFlatGuard` proves
`elem_size == stride` once in a loop's preheader and hands one `i1` to every
access in the body, and it was wired to `while` only — `loop` and `for` got no
guard at all. `mapProbe`'s probe is a `loop`, so every `list_get(m.slots, at)`
re-read `slots.elem_size` and re-tested it against 4.

**It was built and it works.** Two obstacles had to come out first:

1. `irFlatGuardCount` refuses any call it cannot account for, and `mapProbe`
   calls `hash` and `eq`. Verdicts are marked by **source name**, so one unsafe
   overload poisons the name — and `hash` for String reaches
   `__builtin_string_byte_at` while `eq` for String reaches
   `__builtin_string_eq`, neither of which was seeded guard-safe although
   `__builtin_string_len` was. **Every `Map<Int, Int>` probe in the language paid
   a per-access representation test because `Map<String, V>` exists.**
2. The guard had to be emitted in the `loop` and `for` preheaders.

With both, the probe loop body drops from 9 loads and 5 branches to **5 loads and
4 branches**, and `m.keys`/`m.slots` are hoisted into one `ldp` at entry.

And both map benchmarks got **slower**:

| Benchmark | before ms | after ms | ratio | noise |
|---|---:|---:|---:|---:|
| key_value_update | 10.843 | 11.020 | 1.016 | 1.007 |
| **hashmap_insert_lookup** | 6.936 | **7.318** | **1.055** | 1.000 |

`RESULTS-affine-index-rejected.md` said why in advance: **the guard is paid per
loop entry and repaid per iteration.** `mapProbe` is called 3.2 million times and
its loop almost always runs **once** — a first-probe hit — so the entry cost is
paid 3.2 million times and the per-iteration saving is collected 3.2 million
times at one iteration each. LLVM then versions the loop on the invariant `i1`,
and `mapProbe` goes from 60 to 164 instructions for a body that runs once.

**The new part is that the loop form is the tell.** `while (i < n)` carries a
trip count and is the shape of a traversal; `loop` in this language is the shape
of a search — probe, scan, parse — which exits early by construction. There is
nothing static to distinguish a `loop` that iterates 1,000 times from one that
iterates once, and the measurement says the common one iterates once. The guard
stays on `while`.

The two changes were measured **separately**, which is what attributes the
regression. Seeding the two string builtins alone changes five functions
(`strChars`, `strBytes`, `chars`, `bytes`, `mapRehash`) and measures at noise
everywhere: key_value_update 1.008 (noise 1.005), hashmap_insert_lookup 0.994,
string_search 1.000, tokenization 0.993, line_processing 1.011 (noise 1.031),
file_read 1.002, file_write 0.989. **That half is kept**, not for speed — it
buys none — but because treating `__builtin_string_len` as known-safe and
`__builtin_string_byte_at` as unknown is an inconsistency rather than a policy,
and the trap it sets is invisible: adding one `Map<String, V>` to a program
silently removes the guard from every other map in it.

## Verification

- Compiler at a **three-generation byte-identical IR fixpoint**,
  `build/kv/b1.ll` = `b2.ll` = `b3.ll`, MD5 `119c6d4f5e69c207971ec998e452fe9f`.
- Full suite **300/300**.
- **All 34 benchmark checksums identical** between the two libraries, and the
  **allocation count of every benchmark is unchanged** — this pass adds and
  removes no allocation. `lib-verification.json`.
- `--verify` on all 34 in both library arms: **0 violations**, 2 leaked per run
  (MEM-038).
- `test_65_map`, `test_map_probe` and `test_map_update` pass under `--verify` at
  19/19, 1817/1817 and 328/328 allocated/released, zero leaked, zero violations.
- `tools/fn_mnemonic_diff.py` run on every arm before any timing was believed.

## What is left, and where it is

The remaining 1.88x is **not** the representation test — that lever is priced
above at a net loss. It is two things, in this order:

1. **The probe is a dependent load chain.** `slots[at]` gives an entry index and
   `keys[entry]` gives the key to compare: two loads that cannot issue together,
   on a 320 KB index table that does not fit L1. C++'s `unordered_map` compares
   the key in the node it already reached. Storing the key — or a one-byte `h2`
   tag — beside the slot index collapses the chain to one load. That is §5's
   Task 2.1 SwissTable direction, and this measurement is the argument for it.
2. **The representation test cannot be constant-folded** because
   `PRISMIO_INLINE_ELEMS` is a **runtime** `getenv`, so no list is statically
   known to be stamped. Making that a compile-time decision would turn every
   `elem_size == stride` in the language into a constant and delete the test from
   every access, with no guard and no versioning — which is the shape of fix the
   per-entry law does not punish. It is a change to a documented knob and was not
   attempted here.

Not attempted, and deliberately: **the hash.** `keyMixInt` is Murmur3's 32-bit
finalizer, eight instructions, computed twice per update iteration; C++'s
`hash<int>` is the identity and costs nothing. Replacing it would close part of
the gap by making the table worse on exactly the key distributions
`std/key.psm`'s header says it was chosen for, and the benchmark's keys — dense
and consecutive — are the case an identity hash flatters most.

## Reproduce

```bash
tools/bootstrap.sh --compiler <previous> --out build/kv/b1
tools/bootstrap.sh --compiler build/kv/b1 --out build/kv/b2
cp build/kv/b2 .prismio/build/debug/prismio && python3 tools/run_suite.py
# library A/B: one compiler, two std trees
build/kv/b2 build build/kvlib/before-src/benchmarks/prismio/suite.psm -o build/kvlib/before-suite
build/kv/b2 build build/kvlib/after-src/benchmarks/prismio/suite.psm  -o build/kvlib/after-suite
```

`kv-loop-guard-2026-09-05/` holds the three focused A/B logs (loop guard,
builtins alone, `mapSet`), the two verification ledgers, the mnemonic diffs and
the library baseline `map-before.psm`.
