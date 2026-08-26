# Genuinely-cold compilation

**Status: GREEN, 2026-08-26.** A cold build no longer compiles `lang_runtime.c`
twice. The curated module's `-O2` intermediate is now bitcode, it is retained for
the rest of the build, and the runtime object is lowered from it with the target
backend alone. Cold and `PRISMIO_OBJ_CACHE=0` builds drop to **0.804–0.818×** of
the previous compiler, and the standing inline-runtime cold penalty falls from
**1.359×/1.334×** to **1.103×/1.091×** on g1/g6.

The change is provably codegen-neutral: emitted IR is byte-identical on all six
corpus programs and on `src/main.psm`, and the **linked executables are
byte-identical** — which is stricter than this host's own floor, since two builds
by the *same* compiler differ by one byte of embedded output path.

Raw results:

- [`results-cold-compile.json`](results-cold-compile.json) — the A/B
- [`results-cold-compile-gate.json`](results-cold-compile-gate.json) — the 25-run gate
- [`xlang/results-cold-compile.json`](xlang/results-cold-compile.json)

## 1 · What the standing entry actually named

TODO recorded "genuinely-cold compile regressed 19–28%" as a whole-build ratio.
A whole-build ratio names no stage, so every candidate fix would have been a
guess checked by re-timing the whole build. `PRISMIO_BUILD_TRACE=1` now prints
one line per stage, and the first trace answered it.

Minimum of 3 cold runs of g1, `PRISMIO_OBJ_CACHE=0`, milliseconds:

| stage | inline runtime OFF | ON, before this change | ON, after |
|---|---:|---:|---:|
| curated: runtime IR | — | 88.5 | 88.9 |
| curated: extract | — | 2.3 | **1.5** |
| curated: merge | — | 0.8 | 0.8 |
| program `-O2` (merged) | 43.8 | 47.4 | 48.0 |
| runtime object | 123.7 | 82.2 | **56.3** |
| `program_support` | 46.3 | 46.5 | 45.9 |
| link | 44.5 | 45.2 | 45.4 |
| **traced total** | **258.3** | **312.9** | **286.8** |

The "before" column is this session's first step — retaining the curated
intermediate so the runtime object is lowered from it rather than recompiled from
C. It was already in the working tree and is measured here for the first time.

The regression was never the extract or the merge. Those are **2.3 ms**. It was
that a cold inline-runtime build ran the C frontend and the `-O2` middle end over
`lang_runtime.c` **twice**: once to produce the module the curated ops are cut
from, and once to produce the object the program links against.

## 2 · Why the first step only got half of it

Reusing the intermediate removed the second C frontend run but left the second
`-O2` middle-end run, because `clang -O2 -x ir -c` re-runs the whole optimisation
pipeline on IR that is already optimised. `-Xclang -disable-llvm-passes` runs the
target backend at the same codegen level and nothing else.

Standalone, minimum of 3, on `lang_runtime.c`:

| command | ms | object |
|---|---:|---|
| `clang -O2 -c` (what OFF does) | 120 | — |
| `clang -O2 -S -emit-llvm` (textual) | 80 | |
| `clang -O2 -emit-llvm -c` (bitcode) | 80 | |
| textual IR → object, full `-O2` | 80 | differs from `-O2 -c` |
| textual IR → object, backend only | 50 | **differs** from `-O2 -c` |
| bitcode → object, backend only | 50 | **byte-identical** to `-O2 -c` |

**That last row is why the intermediate is bitcode and not `.ll`.** The split is
not justified by its timing, it is justified by producing the same object; the
textual round trip does not, and a 30 ms saving is not worth a runtime object
that differs from the one every other path produces for reasons nobody has read.

`LLVMParseIRInContext` takes bitcode as readily as text, so the curator needed no
change — and got 0.8 ms faster for not parsing 245 KB of text.

### 2.1 One invocation producing both was measured and rejected

`--save-temps` emits the object *and* the optimised bitcode from a single clang
run, which would remove the extra process entirely. It costs **200 ms** against
this split's 145 ms, because it also writes a 1.06 MB preprocessed `.i` and a
177 KB `.s` nobody asked for. Rejected on measurement.

## 3 · What is left, and why it is left

The runtime object now costs 88.9 + 56.3 = **145.2 ms** across two clang
processes against **123.7 ms** in one. The residual ~21 ms is one clang process
spawn plus writing and re-reading 69 KB of bitcode. Closing it means lowering the
module in-process through the LLVM C API the compiler already links, which would
trade a measured byte-identity guarantee for ~10 ms. Not taken.

## 4 · Result

Interleaved, minimum of 7, new = this change, base = `build/m5-exclusive-3`:

| program | cold | incremental | no-change | no-cache |
|---|---:|---:|---:|---:|
| g1_particles | **0.804×** | 0.993× | 0.984× | **0.811×** |
| g6_game | **0.818×** | 1.001× | 1.000× | **0.812×** |
| test_09_strings | **0.812×** | 0.996× | 1.002× | **0.807×** |

The cached paths are unmoved, which is the point: the object cache already hid
this cost, and a fix that bought cold time back by spending warm time would have
regressed the only column a person at a keyboard feels.

The standing inline-runtime penalty, same binary with the feature toggled:

| | g1 cold | g6 cold |
|---|---:|---:|
| before | 1.359× | 1.334× |
| after retaining the intermediate | 1.206× | 1.188× |
| after bitcode + backend-only | **1.103×** | **1.091×** |

## 5 · Gates

- emitted IR byte-identical on all six corpus programs and `src/main.psm`;
- linked executables byte-identical on g1 and g4 — the same-compiler control
  differs by one byte, so this is below this host's reproducibility floor;
- fixed point: `build/cbc_a.ll == build/cbc_b.ll`;
- suite **170/170** — one new test, below; AIF differential **17/17** in both modes;
- source lists agree; `git diff --check` clean;
- 25-run milestone: corpus median **1.000×**, range 0.995–1.080×, gate passed —
  an A/A in all but name, since the executables are the same bytes;
- 25-run cross-language refresh in
  [`xlang/results-cold-compile.json`](xlang/results-cold-compile.json).

## 6 · Fails open, and the test that stops it failing open quietly

A clang that rejects `-Xclang -disable-llvm-passes` falls back to compiling
`lang_runtime.c` from source rather than failing the build, matching the rest of
this optimisation. That is the right product behaviour and it is exactly why a
value test cannot gate it: the fallback produces the same program, only slower.

`run_runtime_object_from_ir_test` requires the `lang_runtime (from IR)` stage on
the cold default path and requires its **absence** under
`PRISMIO_INLINE_RUNTIME=0`, which builds no curated module and so has nothing to
retain. Both arms are needed — one alone would pass against a trace that printed
the marker unconditionally.

**It was checked against a clang that actually refuses the flag**, not against
its own absence. A shim on `PATH` forwarding to the real clang but exiting 1 on
`-disable-llvm-passes` makes the fallback engage: the build still succeeds, g1
still prints `alive: 2000`, the trace reports `lang_runtime` instead of
`lang_runtime (from IR)`, and the test fails. Passing because the optimisation
ran and failing because it did not are both observed, so the assertion is not
vacuous.

The three-platform CI matrix is what would observe this on Windows and Linux, and
that gate is still blocked on push authorisation.
