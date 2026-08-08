# The G2 / G6 benchmark set

First cross-language measurement of AIF, 2026-08-08. Built to BENCHMARKS §3.2's baseline order and
§3.2's protocol (≥30 runs, median and p99, same machine).

```bash
clang -O2             aif/evidence/bench/g2_bench.c       -o aif/evidence/bench/g2_c.exe
clang -O2             aif/evidence/bench/g2_bench_arena.c -o aif/evidence/bench/g2_c_arena.exe
clang -O2             aif/evidence/bench/g6_bench.c       -o aif/evidence/bench/g6_c.exe
clang -O2 -DUSE_ARENA aif/evidence/bench/g6_bench.c       -o aif/evidence/bench/g6_c_arena.exe
clang -O2             aif/evidence/bench/noop.c           -o aif/evidence/bench/noop.exe

prismio build aif/evidence/bench/g2_bench.psm         -o aif/evidence/bench/g2_prismio.exe
prismio build aif/evidence/bench/g2_bench.psm --debug -o aif/evidence/bench/g2_prismio_debug.exe
prismio build aif/evidence/bench/g6_bench.psm         -o aif/evidence/bench/g6_prismio.exe
prismio build aif/evidence/bench/g6_bench.psm --debug -o aif/evidence/bench/g6_prismio_debug.exe

python aif/evidence/bench/bench.py --runs 40
```

All four binaries in each suite print the same checksum, and that is the first assertion — a
benchmark whose variants compute different things measures nothing. G2 prints
`submitted: 10020000 / culled: 9980000`; G6 prints `checksum: 14040000`.

## What the variants are

| | |
|---|---|
| `*_prismio_debug` | BENCHMARKS §3.2 baseline 1, the **required** control. Same compiler, backend, LLVM and source; `--debug` is SPEC 7.1's zero-analysis level, budget 0 rounds, so every site widens to its top tier. The tier assignment is the only variable, which is the only comparison in which AIF is isolated (§1). |
| `*_c` | Baseline 2, the normalisation point. |
| `*_c_arena` | Baseline 3, "the ceiling AIF approaches from below" — identical program and data model, with only the per-frame/per-tick transient batch bump-allocated and reset instead of freed object by object. This is the transformation T1 exists to perform automatically. |
| `*_prismio` | The thing under test. |

Rust, Go, Java and Swift are §3.2 priority 4 ("context only, and only after 1–3 are stable") and are
deliberately absent.

## Fidelity

The C ports translate the data model rather than improving on it: a Prismio struct is a heap object
held by pointer, `list_push(l, T { .. })` allocates one object and stores the pointer, and a `List`
is a doubling pointer vector starting at capacity 4 (`lang_runtime.c`). Flattening the batch into an
array of values would be faster and would be a different program — that is the arena variant's job,
and it earns its win with the allocation discipline alone.

G6's two variants are one source behind `-DUSE_ARENA`, because they must differ in the allocation
discipline and in nothing else; G2's are two files, which is already an invitation to drift.

The `.psm` benchmarks are the corpus programs with the iteration count raised (G2: 120 → 20000
frames; G6: the scenario wrapped in a 300-run loop). Shape, tiers and allocation profile are
unchanged — at corpus size the whole run is ~11 ms and roughly 6 ms of that is process startup.

## What it found

See `HANDOFF.md`, the 2026-08-08 section. In short: the arena baseline is **11× faster than
idiomatic C on G2 and 3.3× on G6**, Prismio at full inference is 1.22× and 1.57×, and G2's four
allocation sites land **T2** — against `g2_frame_loop.psm`'s own header, which says landing anything
but T1 means the escape analysis is wrong.

Read `--debug` with the RSS column, always. It never frees, so it is 8% *faster* than inference on
G2 (392 MB peak) and 13% *slower* on G6 (823 MB peak), where the footprint costs more in page faults
than the frees it skips. Quoting its wall time alone gets the sign of the result wrong.
