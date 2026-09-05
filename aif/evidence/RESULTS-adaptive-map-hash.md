# `key_value_update`: the hash was the cost, and four other things were not

Measured 2026-09-05/06, on top of `RESULTS-map-probe-loop-guard.md`. The task was
to close the worst ratio in the matrix — `key_value_update` at 1.88x of C++ and
1.21x of Rust — and if possible to beat both.

**It is the hash.** Everything else that looked like the answer was measured and
was not: not the table design, not the bounds checks, not the representation
test, not the linkage, not the inliner. The change is four lines of
`std/key.psm` plus an escape hatch in `std/map.psm`, and it is worth **1.87x**
on the workload.

## 1 · The design was already at the C ceiling

Four table designs, written in C on the identical workload — 80,000 keys, 20
update rounds of two lookups each — all using `std/key.psm`'s hash. Medians of
25 samples, one shot per process (`ceiling.c`):

| design | insert | update | sum | total |
|---|---:|---:|---:|---:|
| **index** — what `std/map.psm` is: index table, dense insertion-order arrays | 0.983 | 3.422 | 0.278 | **4.695** |
| **keyed** — the key moved into the slot beside the entry index | 1.176 | 3.245 | 0.255 | 4.686 |
| **swiss** — absl's layout: 1-byte control groups scanned with NEON, `(key, value)` inline, 7/8 load | 0.686 | 4.550 | 0.193 | 5.434 |
| **flat** — `(key, value)` inline with a separate liveness byte | 1.075 | 6.662 | 0.269 | 8.019 |

**The Swiss table loses, and the reason is the thing this map already does.**
A probe reads one scattered bucket either way; what the index design adds is
`keys[entry]` and `values[entry]`, and those are indexed by *insertion order*,
so a workload that walks its keys in the order it inserted them reads them
**sequentially**. Swiss gives that up to put the value in the bucket. `flat`
loses worse because a separate control array makes the scattered access two
cache lines instead of one.

So: no redesign. The remaining alternatives are priced here and none of them is
worth building.

## 2 · Four things that are not the cost

**The container tax is zero.** A probe compiler that forces the representation
test (`elem_size == stride`) constant-true *and* drops every `list_get`/
`list_set` bounds check — 9 loads and 5 branches per probe down to 5 and 3 —
moves the update phase from **7.220 ms to 7.386**. Nothing. Both were the
obvious suspects and both are free; do not spend a session on them.

**Inlining is worth 2.6x in C and cannot be collected here.** With
`__attribute__((noinline))` on the map's three functions the C arm goes 3.573 ->
9.269 ms, and Prismio's 7.220 sits between C's two intermediate shapes. Prismio
emits all 287 functions of a program with **external linkage** in a
whole-program single module, which disables the inliner's last-call-site
discount, IPSCCP, dead-argument elimination and argument promotion. Internalising
everything but `main` was implemented: binaries drop 215 KB -> 131 KB, `mapProbe`
and `mapGetOr` start inlining — and the update phase gets **worse, 7.25 ->
8.84 ms**, because half-inlining duplicates the probe without letting anything
combine the two. Forcing `mapSet` inline as well (`alwaysinline`, and separately
`-mllvm -inline-threshold=1200`) made it worse again. **Reverted; the compiler
in this pass is byte-identical to the one before it.** The linkage change is
worth revisiting with a measurement across the whole suite, and it is not free.

**Half the C advantage is that C's map is a stack value.** `IndexMap m;` is an
alloca, so SROA promotes `m.slots`, `m.keys`, `m.values` and `m.mask` to
registers. `malloc`ing the same struct costs C **3.256 -> 5.660 ms** on the
update phase. Prismio's `Map` is a heap object and has no way not to be. That
1.74x is a language-level question — value structs, or escape analysis placing a
non-escaping struct in a frame — not a library one.

**The probe count was never the problem.** At 1/2 load a good hash costs 1.21
probes per lookup, which is what *random* placement costs. There is nothing to
recover there.

## 3 · What it is: a scrambling hash throws away locality

Same C program, same design, one line different — MurmurHash3's 32-bit finalizer
against the identity:

| | insert | update | sum | total |
|---|---:|---:|---:|---:|
| heap map, murmur3 | 0.973 | 5.625 | 0.279 | 6.877 |
| heap map, identity | 0.331 | 0.957 | 0.181 | **1.469** |

**4.7x.** The benchmark's keys are `0..79,999` — consecutively allocated, as
interned ids, counters and indices are. An avalanche mix scatters them across a
1 MB index table, so every probe is an L2 access on a dependent load chain that
cannot be prefetched. The identity leaves them in bucket order, and the hardware
prefetcher does the rest.

`std/key.psm`'s header said the opposite: "consecutive small ids with an identity
hash are one long probe chain." That is true of **linear** probing and false of
this table — triangular offsets over a power-of-two mask place consecutive ids in
consecutive buckets, one probe each.

## 4 · The fold, and why it is not just the identity

The identity is not shippable. Measured probes per lookup, six key families,
80,000 entries (`hashquality.c`, full output in `hash-quality.txt`):

| keys | murmur3 | `h ^ (h>>16)` | identity |
|---|---:|---:|---:|
| `i` — dense | 1.21 | **1.00** | 1.00 |
| `i * 64` — aligned records | 1.21 | **1.18** | 10.27 |
| `i * 65536` — differ only above the mask | 1.37 | **1.00** | 14076 |
| `i * 2654435761` — already scrambled | 1.21 | 1.18 | 1.00 |
| `i * 131072` | 1.39 | **1.00** | — |
| **`i * 65537`** | **1.46** | **7078** | — |

`h ^ (h >>> 16)` is `java.util.HashMap`'s `spread()`, the default hash of the
most widely deployed hash map in production since 2014. It is the **identity for
every key below 2^16**, so it keeps the locality; it folds the high half into the
low half, so it survives every family the identity fails; and on the five
families that are not built against it, it is **never the worse of the two on
probe count** and is 1.2x–3.0x faster in time.

The sixth family is the one built against it. `i * 65537` puts the same bits in
both halves, folding them cancels, every key lands in bucket 0, and the table
degrades to 7,078 probes per lookup — 13 seconds where murmur3 takes 25 ms. That
is not a corner case to accept in a standard library: `i * 65537` is what a
struct hash that xors two equal 16-bit fields produces.

## 5 · So the table checks its own hash

`mapRehash` now measures the probe displacement it spends re-placing every entry
into the doubled table, and switches that map to `keyStrengthen` — the full
MurmurHash3 finalizer, applied on top of whatever `hash` returned — when the
average exceeds three. Placing into a table just doubled costs about 0.2 when the
hashes spread, so three is not bad luck at any size; a false positive costs that
map its locality and nothing else, which is why the threshold does not need to be
delicate. The pathological family reaches three by the **ninth entry**, so the
wasted work before the switch is thirty-six probe steps.

Two things this buys beyond the benchmark:

- **A user's weak `impl Key` is now defended too.** A strong `keyMixInt` only
  ever protected the types written in `std/key.psm`; `hash() -> 0` is a legal
  implementation of the trait and the table used to have no answer to it.
- The trait's contract is unchanged and is the honest one: *equal keys hash
  equal*. Quality is the table's business, which is where it can be measured.

`keyMixInt` also drops from 11 instructions to 3.

Measured on the phase fixture, one shot per process, 21 samples:

| arm | insert | update | sum | total |
|---|---:|---:|---:|---:|
| murmur3 (before) | 1.400 | 7.249 | 0.334 | 8.983 |
| fold only, no escape hatch | 0.726 | 3.648 | 0.183 | 4.556 |
| **fold + adaptive (shipped)** | 0.860 | 3.763 | 0.183 | **4.806** |
| *C, heap map, murmur3 — the old design's ceiling* | 0.975 | 5.757 | 0.285 | 7.017 |

The escape hatch costs 5.5%. The result is **1.87x**, and it is faster than the
C implementation of the design it replaces.

Five key families end to end, 40,000 entries each, µs (`pathology.psm`):

| keys | murmur3 (before) | fold + adaptive |
|---|---:|---:|
| dense | 2540 | **1843** |
| `i * 64` | 2111 | 2403 |
| `i * 65536` | 1969 | **1336** |
| `i * 65537` | 2021 | 2177 |
| `i * 131072` | 1405 | **763** |

Faster on three, within 15% on the two that trip the switch, and no cliff
anywhere. Every sum agrees between the two versions.

## 6 · The result

Interleaved, 25 samples after 6 warmups, one process per sample, rotating order.
One compiler, two standard libraries — the only difference between the arms is
`std/key.psm` and `std/map.psm`.

| benchmark | before | after | vs C++ | vs Rust |
|---|---:|---:|---:|---:|
| **key_value_update** | 10.495 ms | **4.948 ms** | 1.866x -> **0.880x** | 1.221x -> **0.576x** |
| **hashmap_insert_lookup** | 6.959 ms | **4.484 ms** | 1.020x -> **0.657x** | 0.882x -> **0.568x** |

C++ 5.623 / 6.823 ms (`clang++ -O3 -std=c++20`), Rust 8.596 / 7.889 ms
(`rustc -C opt-level=3 --edition=2021`), measured in the same interleaving.
`key_value_update` was the worst ratio in the matrix; it is now 14% faster than
C++ and 1.74x faster than Rust, and it beats §2's forecast of 5.40–5.80 ms and
0.96x–1.03x of C++.

The other 32 benchmarks over the same sweep are flat: every ratio is within its
own noise arm except `gcd_lcm` at 1.125 against a 1.035 noise reading, and
`_benchGcdLcm__Int` is **mnemonic-identical** between the two binaries — it is
the layout sensitivity `RESULTS`-history has recorded on this exact benchmark
before. The mnemonic diff over the whole suite is 13 changed functions and 4 new
ones, all of them in `std.map` and `std.key`.

## 7 · Verification

- **No compiler change.** `build/kvhash/h1.ll` = `h2.ll` = `h3.ll` = the
  pre-existing `119c6d4f5e69c207971ec998e452fe9f`: three bootstrap generations
  with the new library emit byte-identical IR, because the compiler does not
  instantiate `Map` (its two `std.map` mentions are comments).
- Full suite **301/301**, including the new `test_131_map_adaptive_hash`.
- **All 34 benchmark checksums identical** between the two libraries, and the
  **allocation count of every benchmark is unchanged**. Peak live bytes move by
  exactly one byte on all 34, including the ones that never touch a `Map`.
- `--verify` on all 34 in both arms: **0 violations**, 2 leaked per run
  (MEM-038).
- `test_65_map`, `test_88_map_keys`, `test_map_probe`, `test_map_update`,
  `test_key_wide` and `test_131` all pass under `--verify` with zero leaked and
  zero violations.
- No corpus program uses `Map`.

`test_131_map_adaptive_hash` asserts the switch rather than timing it. A key type
whose `eq` counts its own calls measures the table's total probe displacement
directly — `eq(existing, key)` runs once per occupied bucket walked — and the
test bounds it at 5 comparisons per operation. With the switch it is 2.4; with
`mapRehash`'s condition disabled it is 750 and the test **fails** rather than
merely running slowly.

## 8 · For the next agent

- **Do not redesign the table.** §1 prices Swiss, key-in-slot and inline-pair
  against the current design on the real workload. The insertion-order dense
  arrays are an advantage, not a legacy.
- **Do not chase the bounds check or the representation test.** §2, measured at
  zero with both removed.
- **The two open levers are language-level**, and §2 and §3 price them: a `Map`
  that lives in a frame rather than the heap is worth 1.74x in C, and inlining
  across the map's call boundaries is worth 2.6x in C. Prismio can collect
  neither today — the first needs value structs or escape analysis that places a
  non-escaping struct in a frame, the second needs the inliner to see a whole
  program, which external linkage currently prevents. Internalising is
  implemented and measured in §2; it is not a free win.
- The escape hatch is per-map and one-way. If a `Map` ever gains `mapRemove`,
  tombstones change the displacement measurement and the threshold has to be
  rechecked.

## Reproduce

```bash
# the C ceiling and the hash-quality tables
clang -O3 -std=c11 aif/evidence/kv-adaptive-hash-2026-09-06/ceiling.c -o /tmp/ceiling
clang -O3 -std=c11 aif/evidence/kv-adaptive-hash-2026-09-06/hashquality.c -o /tmp/hq
for p in 0 1 2 3 4 5; do /tmp/hq $p; done

# the library A/B: one compiler, two std trees
python3 build/kvhash/verify_and_time.py verify
python3 build/kvhash/verify_and_time.py time
```

`kv-adaptive-hash-2026-09-06/` holds both C programs, the hash-quality output,
the verification ledger, the timings, the cross-language medians, the mnemonic
diff and the two library baselines.
