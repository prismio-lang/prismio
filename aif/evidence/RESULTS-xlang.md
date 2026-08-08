# Cross-language results — Prismio vs Rust vs Swift

**2026-08-08. Internal calibration. Not for publication.**

Apple M5, 10 cores, 16 GB. macOS 25.5. LLVM 22.1.8, rustc 1.97.1, Swift 6.3.3. Prismio `build/gen2`
(fixpoint holds, 92/92). 20 runs per binary, medians with spread; frame percentiles from 4 000 –
30 000 in-process samples per run. Method, and the arguments for every choice in it, in
[`xlang/README.md`](xlang/README.md).

Reproduce:

```bash
python3 aif/evidence/xlang/bench.py --compiler build/gen2 --runs 20
```

---

## 0 · The one-paragraph answer

The session was called to falsify cheaply: *if tuned Rust ties us everywhere, the claim becomes
"easier, not faster".* Tuned Rust does not tie. **It wins by 4.8×–52×, and idiomatic Rust wins by
3.0×–8.9×.** Every projection in BENCHMARKS §4 that bears on speed is falsified, most of them by
an order of magnitude. But the gap decomposes into three factors and **only one of them belongs to
the memory model** — the largest single factor is that `prismio build` runs no optimiser, on either
of the two stages where one belongs. The honest status is not "slower". It is **"nobody has measured
the memory model yet, including us"**, and the numbers below are mostly a measurement of a build
pipeline.

---

## 1 · The headline table

Loop time — the sum of the program's own per-frame samples, so process startup and the report dump
are excluded. Median of 20 runs, relative to idiomatic Rust.

| | g1 particles | g2 frame loop | g3 scene graph | g4 ECS | g5 asset cache | g6 engine+game |
|---|---|---|---|---|---|---|
| **Prismio** | **2.97×** | **8.32×** | **3.24×** | **8.88×** | **7.73×** | **8.85×** |
| Rust idiomatic | 1.00× | 1.00× | 1.00× | 1.00× | 1.00× | 1.00× |
| Rust arena | 1.00× | 0.90× | — | — | — | 0.81× |
| Rust hand-tuned | 0.26× | 0.56× | 0.68× | 0.82× | 0.15× | 0.71× |
| Swift idiomatic | 1.00× | 1.77× | 1.11× | 3.84× | 2.42× | 2.87× |
| *Rust boxed (diagnostic)* | *1.09×* | *8.84×* | — | *2.51×* | — | — |

Absolute medians, milliseconds:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio | 55.4 | 154.3 | 147.6 | 193.6 | 227.1 | 494.2 |
| Rust idiomatic | 18.6 | 18.5 | 45.5 | 21.8 | 29.4 | 55.8 |
| Rust hand-tuned | 4.8 | 10.4 | 30.8 | 17.9 | 4.4 | 39.8 |
| Swift idiomatic | 18.5 | 32.8 | 50.8 | 83.7 | 71.1 | 160.3 |

Run-to-run spread is tight enough that none of this is noise: Prismio's widest is g5 at
220.9–253.0 ms around a 227.1 median, and most are within ±3%.

**All 29 programs print identical checksums**, including the SoA rewrite, the fused-loop rewrite,
the bucketed rewrite and the reset-world rewrite. `bench.py` refuses to time a program whose
variants disagree, so this is asserted on every run rather than checked once.

---

## 2 · Prediction vs measurement, per axis

Predictions from the handoff brief, with BENCHMARKS §4.1 and §4.2 beside them where they differ.

| Axis | Predicted | Measured | Verdict |
|---|---|---|---|
| Alloc-heavy vs **idiomatic** Rust | 0.8–1.1× | **8.32×** (g2), **8.85×** (g6) | ✗ wrong by ~8× |
| Alloc-heavy vs **tuned** Rust | 1.0–1.3× | **14.8×** (g2), **12.4×** (g6) | ✗ wrong by ~11× |
| Peak RSS vs idiomatic Rust | 1.0–1.2× | **0.84–1.01×** | ✗ wrong, *in our favour* |
| Allocator churn | 0.2–0.5× | **10.5×–63.7×** more allocations | ✗ wrong by ~100× |
| BENCHMARKS §4.1: AIF vs Rust idiomatic | 0.71× | 2.97–8.88× | ✗ falsified |
| BENCHMARKS §4.2: object graphs, kill > 1.00 | 0.70–0.90 | 2.97–8.88 | ✗ **kill criterion met** |
| BENCHMARKS §4.2: data-parallel bulk, kill > 0.90 | 0.35–0.65 | 2.97 (g1, the nearest shape here) | ✗ **kill criterion met** |
| BENCHMARKS §4.2: p99 tail, kill p99/p50 > 3× | ≈ C | **1.29–1.88×** | ✓ **held** |
| BENCHMARKS §4.1: Swift at 1.94× of Rust | 1.94× | 1.00–3.84×, median 2.09× | ✓ held |
| Executable size | not predicted | Prismio **56 KB**, Rust 458–476 KB | — |
| Cold compile time | not predicted | Prismio ≈ rustc, **2.5× faster than swiftc** | — |

Three of these are worth more than a row each.

### 2a · "Allocator churn 0.2–0.5×" was wrong about the baseline, not about AIF

This is the most inverted prediction and the easiest to learn from. Measured allocation counts:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio | 2 214 | 10 201 215 | 5 675 | 7 760 | 2 266 | 15 137 005 |
| Rust idiomatic | 207 | 160 206 | 207 | 247 | 216 | 289 097 |
| ratio | 10.7× | **63.7×** | 27.4× | 31.4× | 10.5× | 52.4× |

The prediction assumed the thing being compared against also allocates once per object. **Nothing
modern does.** `Vec<T>` stores elements inline and amortises N objects into ⌈log₂ N⌉ allocations;
Prismio's `List<T>` is a vector of pointers to individually `malloc`'d records, so it pays N. On g2
that is 10.2 M allocations against 160 K for the same program.

So the number AIF was projected to improve — allocator traffic — is a number the baseline had
already deleted by a different means, and by a larger factor than AIF proposes to. **The prediction
priced a memory model against a strawman container.**

Rates, for the record: Prismio sustains **66 M allocations/s** on g2 (10.2 M in 154 ms) and 30.6 M/s
on g6, with frees matching to within 0.01%. Rust's boxed diagnostic runs the same profile at 62 M/s.
The allocator itself is not slow; there is simply 64× more work asked of it.

### 2b · Peak RSS was wrong in our favour, and for the opposite reason to the one assumed

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio | 1.7 MB | 2.0 | 2.1 | 2.0 | 1.6 | 2.2 |
| Rust idiomatic | 2.0 MB | 2.2 | 2.0 | 2.2 | 1.8 | 2.6 |
| Swift | 6.3 MB | 6.8 | 6.6 | 6.8 | 6.1 | 7.8 |
| Prismio / Rust | 0.87× | 0.89× | 1.01× | 0.91× | 0.88× | 0.84× |

The 1.0–1.2× prediction assumed arenas over-allocate and that AIF therefore trades a little footprint
for speed. Neither half happened. Arenas barely fire on this corpus at all, and Prismio is *tighter*
than Rust **because** it does not amortise: a `Vec` that has doubled its way to 1 000 elements holds
up to 2× the bytes it needs, while 1 000 separate `malloc`s of a 96-byte record hold 1 000 × 96 plus
per-block overhead and no slack. Prismio wins this axis by having the property that loses it every
other axis.

Swift's 3.0–3.4× is the Swift runtime's resident footprint, not the programs'. It is a floor, and it
is the same ~4.5 MB on all six.

### 2c · The tail held, and this is the only prediction that survived

`p99/p50`, the BENCHMARKS §4.2 kill criterion (kill at > 3×):

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio | 1.49 | 1.37 | 1.38 | 1.31 | 1.29 | 1.88 |
| Rust idiomatic | 1.24 | 1.22 | 1.26 | 1.25 | 1.80 | 1.81 |

And `p999/p50`:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio | 2.99 | 3.17 | 2.60 | 2.54 | 2.44 | 3.97 |
| Rust idiomatic | 3.29 | 6.29 | 3.52 | 4.05 | 3.86 | 6.40 |

**Prismio's distribution is the same shape as Rust's, shifted.** Its p999/p50 is *lower* than
idiomatic Rust's on all six programs. Nothing in the model introduces a hitch: no collector pause, no
reclamation spike, no amortised-growth cliff. Rust's *relative* tail on g2 is worse than Prismio's,
because `Vec` growth doubles inside a frame and Prismio's per-object `malloc` never does.

Read this as a ratio and never as an absolute. Prismio's p99 on g2 is 10.40 µs against Rust's
1.12 µs — nine times worse in the only unit a frame budget is denominated in. The claim that survives
is narrow and it is the right one to keep: **the memory model adds no tail of its own.** Everything
that makes Prismio's tail large is the median it sits on, which is §3's subject.

---

## 3 · Where the gap actually comes from

This is the output of the session. The gap is a product of three factors, and they are separable.

### 3.1 · `prismio build` runs no optimiser. On either stage.

Two findings in `runtime/build_driver.c`, neither of them a memory-model decision:

| | |
|---|---|
| [`build_driver.c:509`](../../runtime/build_driver.c#L509) | `llc <ir> -filetype=obj -o <obj>` — no flags. llc runs the *codegen* pipeline (isel, scheduling, regalloc) but **not** the IR pipeline. `mem2reg`, `SROA`, `GVN`, `LICM`, inlining and vectorisation never touch a user program. |
| [`build_driver.c:638`](../../runtime/build_driver.c#L638) | `clang -Wno-deprecated-declarations -c <runtime.c>` — no `-O`, i.e. **-O0**. That is where `list_get`, `list_push` and the allocator live, called millions of times per run. |

What the first one costs is visible in the emitted IR for `integrate`. Every local is an `alloca`
that is never promoted; the loop counter round-trips through memory each iteration; `p` is reloaded
from its stack slot **five times** inside a single `p.px = p.px + p.vx * dt`.

Measured with `optgap.py`, which takes the compiler's own IR unmodified and links it four ways —
same frontend, same backend, same runtime source, same linker, two flags as the only variables:

| program | shipped | runtime `-O2` | program `opt -O2` | both | both/shipped |
|---|---|---|---|---|---|
| g1 | 56.0 ms | 33.6 | 39.6 | 25.4 | **2.21×** |
| g2 | 155.0 ms | 124.5 | 125.9 | 107.0 | **1.45×** |
| g3 | 148.8 ms | 93.5 | 100.0 | 52.6 | **2.83×** |
| g4 | 194.9 ms | 101.5 | 136.7 | 67.1 | **2.90×** |
| g5 | 224.6 ms | 117.6 | 121.5 | 77.5 | **2.90×** |
| g6 | 486.4 ms | 298.8 | 370.5 | 224.5 | **2.17×** |

Checksums are identical across all four columns of every row. The `shipped` column reproduces
`bench.py`'s Prismio numbers to within 1.6%, which is what says the matrix is measuring the real
thing rather than a reconstruction that drifted.

With both flags on, Prismio against idiomatic Rust becomes:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| shipped | 2.97× | 8.32× | 3.24× | 8.88× | 7.73× | 8.85× |
| **both flags** | **1.37×** | **5.78×** | **1.16×** | **3.08×** | **2.64×** | **4.02×** |

g3 at 1.16× and g1 at 1.37× are inside — or within reach of — the brief's predicted 0.8–1.1× band,
from a build-configuration change that touches no design.

**LTO across the runtime boundary buys nothing.** Tested on g1, g4 and g5 with `-flto` on both the
program IR and the runtime: 29.6 / 66.4 / 76.3 ms against 25.4 / 67.1 / 77.5 for `both`. So the
residual is *not* the un-inlined `list_get` call, which was the obvious hypothesis and is wrong.

### 3.2 · The representation costs between 1.09× and 8.84×, and it depends on the record

`Vec<Box<T>>` in Rust is Prismio's `List<T>` exactly: a vector of pointers to individually
heap-allocated records. Holding it fixed and letting rustc emit the code isolates what the
representation costs from what the compiler costs.

| | representation cost (boxed / idiomatic Rust) |
|---|---|
| g1 — 96-byte record, no per-frame allocation | **1.09×** |
| g4 — 24-byte components, no per-frame allocation | **2.51×** |
| g2 — 32-byte record, ~501 allocations per frame | **8.84×** |

g1's 1.09× does not generalise and it would have been wrong to assume it did. A pointer array in
front of a 96-byte record is 8% more traffic; in front of a 24-byte component it is 33% more, plus a
dependent load, and it costs 2.51×. Where the record is *allocated per frame* rather than merely
read, it costs 8.84×.

### 3.3 · Putting the three together

Multiplicatively, against idiomatic Rust:

| | representation | missing optimiser | residual | product | measured |
|---|---|---|---|---|---|
| g1 | 1.09× | 2.21× | 1.23× | 2.96× | **2.97×** |
| g4 | 2.51× | 2.90× | 1.22× | 8.88× | **8.88×** |

The residual is ~1.2× in both, and that residual is the only part of the gap that is a statement
about Prismio's design rather than its build. **On g2 the shipped Prismio binary is already 0.94× of
boxed Rust** — faster than rustc's own code for the same allocation profile — which is worth
noticing before concluding anything about the backend.

---

## 4 · What the memory model is actually worth, measured

Four of the six corpus programs — **g1, g3, g4, g5 — allocate nothing per frame.** They build a
structure once and then stream over it. An arena has nothing to do in them, which is why `g1_arena`
is written out in full with bumpalo and measures **1.00×**, identical to idiomatic, rather than
being asserted away.

So on two thirds of the corpus the memory model cannot help, and the whole gap is §3.1 + §3.2 + the
residual. That is worth saying plainly: **the corpus is much less allocation-heavy than the T1 story
assumes.**

On the two programs that do allocate per frame, the prize is large and it is the arena:

| | Rust boxed (= Prismio's profile) | Rust idiomatic | **Rust arena** |
|---|---|---|---|
| g2 | 8.84× | 1.00× | **0.90×** |
| g6 | — | 1.00× | **0.81×** |

On g2, moving from the boxed profile to a bumpalo arena — same representation, same program, only
the allocation discipline changed — is worth **9.8×**. That is the transformation T1 exists to
perform without being asked, and it remains unclaimed: g2's four allocation sites still land **T2**,
against `g2_frame_loop.psm`'s own header, which says landing anything but T1 means the escape
analysis is wrong. The previous session designed the fix (the `CallerRegion` lattice value plus the
container-disposition change) and correctly declined to build half of it.

**This measurement does not say Prismio would reach 0.90× by adding arenas.** It says the allocation
term on g2 is worth up to 9.8× and is currently paid in full. The other terms would remain.

---

## 5 · The axes nobody predicted, where the result is good

**Executable size.** Prismio 56–57 KB across all six programs; Rust 458–476 KB; Swift 54–60 KB.
Rust statically links its standard library and Swift dynamically links a runtime that ships with the
OS, so the three are not measuring the same thing — but a self-contained 56 KB binary with no
runtime dependency beyond libc is a real property and an 8× advantage over Rust.

**Cold compile time**, source to linked executable, median of 3 with no prior artifact:

| | Prismio | rustc | swiftc |
|---|---|---|---|
| g1 | 135 ms | 107 | 272 |
| g6 | 140 ms | 139 | 348 |

Roughly at parity with rustc and about **2.5× faster than swiftc**. These are 100–300 line programs
and this is not a scaling claim — the known superlinearity in module size is unaddressed and
untested here. Note also that Prismio's number will *rise* if §3.1 is fixed, because running the
optimiser costs compile time. That trade should be made with the numbers in hand.

---

## 6 · Which assumptions were wrong

The brief asked for this specifically: where reality disagrees, name the assumption.

1. **"The baseline allocates per object too."** It does not, and this is the single wrong assumption
   behind the churn prediction, the alloc-heavy prediction and most of §4.1. `Vec<T>` had already
   solved the problem AIF is aimed at, by a different and cruder means, and by a larger factor. Any
   claim about allocator traffic has to be stated against inline-storage containers or it is
   measuring nothing.

2. **"The backend is at parity, so a comparison isolates the memory model."** Every projection in
   BENCHMARKS §4 is stated as though the only difference between Prismio and Rust were the memory
   model. Two optimisation stages do not run, worth 1.45–2.90×, and that dwarfs the model's own
   effect on four of six programs. **We have been measuring a build pipeline and calling it a memory
   model.** The internal `--debug` control was specifically designed to isolate AIF — and it does,
   which is why it never caught this: both sides of that comparison have the same missing optimiser.

3. **"Arenas will cost footprint."** Backwards. Prismio uses *less* memory than idiomatic Rust on
   five of six programs, because per-object allocation has no geometric slack. The mechanism the
   prediction feared is not firing, and the mechanism that replaces it happens to win.

4. **"The corpus is allocation-heavy."** Two of six programs allocate per frame. The corpus README
   describes G2 as "the dominant allocation pattern in a real-time renderer" and that is true of G2;
   it is not true of G1, G3, G4 or G5, and the tier work has been ranked as though it were.

5. **"g1's representation cost generalises."** It does not — 1.09× on a 96-byte record, 2.51× on
   24-byte components. Measured in both places on purpose, because assuming the first would have
   attributed g4's gap to the backend and sent the next session in the wrong direction.

One thing that was **right** and is worth keeping: the tail. p99/p50 between 1.29 and 1.88, against
a 3× kill criterion, with p999/p50 lower than idiomatic Rust's on five of six programs.

---

## 7 · What this means for the ranking

Not a recommendation to act on this session — the brief forbade compiler changes, and this is the
handoff note for whoever picks it up.

1. **Turn the optimiser on.** `opt -O2` on the program IR and `-O2` on the runtime. Worth 1.45–2.90×
   for two flags, no design risk, and it is the prerequisite for every other measurement on this
   page being meaningful. Until it is done, **every future benchmark is measuring the wrong thing**,
   which is exactly what this one turned out to be doing. Expect it to cost compile time and to
   need the fixpoint and the full suite re-verified, since it changes the compiler's own build too.
2. **Then re-run this suite**, because the ranking below can only be trusted against an optimised
   baseline.
3. **The `CallerRegion` lattice + container disposition** (designed last session, still not built)
   is now measured: up to **9.8× on g2**, ~0 on four of six programs. That is a large prize on a
   narrow target, and the target is the one the corpus was written to represent.
4. **Inline element storage for `List<T>`** — the `Vec<T>` representation — is unranked and unstudied
   and is worth 1.09×–8.84× depending on the record. It is probably a bigger lever than anything on
   the current list, and it interacts with handles (COMPILER-AUDIT finding 6) rather than avoiding
   them.

---

## 8 · Threats to validity

- **One machine, one OS, one microarchitecture.** Apple M5. Nothing here is portable evidence.
- **Program sizes are small** — 100–300 lines, working sets of 1.6–7.8 MB, all L2-resident. The
  layout results in particular would move on a working set that misses.
- **The `-O2` matrix in §3.1 links only `lang_runtime.c` and `program_support.c`.** That is what a
  normal user build links, and the `shipped` column reproduces `prismio build` to within 1%, but it
  is a reconstruction rather than the compiler's own code path.
- **Idiomatic is a judgement call.** Rust idiomatic is `Vec<T>`; Swift idiomatic is structs in
  `Array` with `final class` for owned aggregates. Both choices are argued in `xlang/README.md` and
  both were made in the direction that is *unfavourable* to Prismio, on the grounds that a rigged
  falsification is worth less than none.
- **g6's frame excludes world construction**, which is 1 event per 100 frames and would otherwise
  land on p99 and describe the rebuild rather than the frame. It is included in wall time and in the
  allocation totals.
- **p999 has few samples on g1 and g5** — 6 and 4 per run respectively. Treat p999 as indicative
  there and p99 as the tail metric; g2 (20 000) and g6 (30 000) carry the tail argument.
- **Swift's `report()` builds one large String**, which is outside the timed region but inflates its
  wall/loop difference relative to the others.
