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
"easier, not faster".* It does not tie — hand-tuned Rust wins by 1.7×–17.6× — but the interesting
answer is narrower than that.

**With an optimiser on, Prismio is ≈1.2×–5.8× idiomatic Rust.** As `prismio build` ships today it is
≈2.9×–9.0×, because it runs no optimiser at all, on either of the two stages where one belongs.
That is a build-configuration defect worth 1.43×–2.97×, not a design result, and the tables below
lead with the optimised configuration for that reason.

What is left after it is fixed splits cleanly. **For the same data representation Prismio is within
1.12×–1.27× of Rust** — that residual is the only number on this page that is a statement about the
compiler's design. Everything else is `List<T>` being a vector of pointers where `Vec<T>` is inline
storage, which costs 1.08× on a wide record and 8.92× where the record is allocated per frame. On the
two programs where allocation dominates, the arena AIF is supposed to place automatically is worth
**9.8×**, and it is still unclaimed.

---

## 1 · The headline table

Loop time — the sum of the program's own per-frame samples, so process startup and the report dump
are excluded. Median of 20 runs, relative to idiomatic Rust.

The tables below are **one run of the suite**, quoted as measured. Repeating the whole suite moves
these ratios by up to ~5% (g3 1.15–1.21, g5 2.56–2.68, g6 4.06–4.19 across two runs), so read the
third significant figure as noise. `xlang/results.json` holds the most recent run and will not match
these cells exactly.

| | g1 particles | g2 frame loop | g3 scene graph | g4 ECS | g5 asset cache | g6 engine+game |
|---|---|---|---|---|---|---|
| **Prismio, optimiser on** | **1.37×** | **5.79×** | **1.15×** | **2.98×** | **2.68×** | **4.19×** |
| Prismio, as shipped today | 2.94× | 8.27× | 3.19× | 8.85× | 7.74× | 9.00× |
| Rust idiomatic | 1.00× | 1.00× | 1.00× | 1.00× | 1.00× | 1.00× |
| Rust arena | 1.00× | 0.89× | — | — | — | 0.82× |
| Rust hand-tuned | 0.26× | 0.56× | 0.67× | 0.93× | 0.15× | 0.72× |
| Swift idiomatic | 1.00× | 1.78× | 1.12× | 3.81× | 2.43× | 2.83× |
| *Rust boxed (diagnostic)* | *1.08×* | *8.92×* | — | *2.67×* | — | — |

Absolute medians, milliseconds:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio, optimiser on | 25.4 | 106.9 | 52.3 | 65.7 | 77.3 | 230.2 |
| Prismio, as shipped | 54.7 | 152.7 | 144.8 | 194.9 | 223.3 | 494.6 |
| Rust idiomatic | 18.6 | 18.5 | 45.3 | 22.0 | 28.9 | 55.0 |
| Rust hand-tuned | 4.7 | 10.3 | 30.6 | 20.5 | 4.4 | 39.4 |
| Swift idiomatic | 18.5 | 33.0 | 50.7 | 83.9 | 70.2 | 155.3 |

**"Optimiser on" is a harness-side reconstruction, not a binary the compiler produces.** It is the
compiler's own emitted IR, unmodified, through `opt -O2`, linked against the same two runtime sources
compiled at `-O2` — the `lang_runtime.c` / `program_support.c` pair that `prismio_toolchain_files[]`
marks for a user build. With the two `-O` flags removed it reproduces `prismio build` to within 1.6%,
which is what says it is faithful. It is labelled `+opt` and never plain "Prismio", because a table
row describing a binary nobody builds is the error this project has recorded twice already.

**All 29 programs print identical checksums**, including the SoA rewrite, the fused-loop rewrite, the
bucketed rewrite and the reset-world rewrite. `bench.py` refuses to time a program whose variants
disagree, so this is asserted on every run rather than checked once.

---

## 2 · Prediction vs measurement, per axis

Predictions from the handoff brief, with BENCHMARKS §4.1 and §4.2 beside them. Measured against the
**optimised** configuration, since that is the one that answers the design question; the shipped
figure is given where the two differ enough to matter.

| Axis | Predicted | Measured (optimiser on) | Verdict |
|---|---|---|---|
| Alloc-heavy vs **idiomatic** Rust | 0.8–1.1× | **5.79×** (g2), **4.19×** (g6) | ✗ wrong by ~5× |
| Alloc-heavy vs **tuned** Rust | 1.0–1.3× | **10.3×** (g2), **5.8×** (g6) | ✗ wrong by ~8× |
| Peak RSS vs idiomatic Rust | 1.0–1.2× | **0.84–1.00×** | ✗ wrong, *in our favour* |
| Allocator churn | 0.2–0.5× | **10.5×–63.7×** more allocations | ✗ wrong by ~100× |
| BENCHMARKS §4.1: AIF vs Rust idiomatic | 0.71× | 1.15–5.79× | ✗ falsified |
| BENCHMARKS §4.2: object graphs, kill > 1.00 | 0.70–0.90 | 1.15–5.79 | ✗ **kill criterion met** |
| BENCHMARKS §4.2: data-parallel bulk, kill > 0.90 | 0.35–0.65 | 1.37 (g1, nearest shape here) | ✗ **kill criterion met** |
| BENCHMARKS §4.2: p99 tail, kill p99/p50 > 3× | ≈ C | **1.25–1.78×** | ✓ **held** |
| BENCHMARKS §4.1: Swift at 1.94× of Rust | 1.94× | 1.00–3.81×, median 2.11× | ✓ held |
| Executable size | not predicted | Prismio **39–40 KB**, Rust 458–476 KB | — |
| Cold compile time | not predicted | Prismio 1.4× rustc, 0.55× swiftc | — |

Every speed row is still falsified with the optimiser on. The magnitudes change; the verdicts do not.
Three rows are worth more than a line each.

### 2a · "Allocator churn 0.2–0.5×" was wrong about the baseline, not about AIF

This is the most inverted prediction and the easiest to learn from. Allocation counts do not move
with optimisation — same program, same semantics — so these are the same in both configurations:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio | 2 214 | 10 201 215 | 5 675 | 7 760 | 2 266 | 15 137 005 |
| Rust idiomatic | 207 | 160 206 | 207 | 247 | 216 | 289 097 |
| ratio | 10.7× | **63.7×** | 27.4× | 31.4× | 10.5× | 52.4× |

The prediction assumed the thing being compared against also allocates once per object. **Nothing
modern does.** `Vec<T>` stores elements inline and amortises N objects into ⌈log₂ N⌉ allocations;
Prismio's `List<T>` is a vector of pointers to individually `malloc`'d records, so it pays N. On g2
that is 10.2 M allocations against 160 K for the same program.

So the number AIF was projected to improve is one the baseline had already deleted by a different and
cruder means, and by a larger factor than AIF proposes to. **The prediction priced a memory model
against a strawman container.**

Rates, for the record: Prismio sustains **95 M allocations/s** on g2 with the optimiser on (10.2 M in
107 ms) and 66 M/s as shipped, with frees matching to within 0.01%. Rust's boxed diagnostic runs the
same profile at 62 M/s. The allocator is not slow; there is simply 64× more work asked of it.

### 2b · Peak RSS was wrong in our favour, and for the opposite reason to the one assumed

Unchanged by optimisation, as expected:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio +opt | 1.7 MB | 2.0 | 2.1 | 2.0 | 1.5 | 2.2 |
| Rust idiomatic | 2.0 MB | 2.2 | 2.0 | 2.2 | 1.8 | 2.6 |
| Swift | 6.3 MB | 6.8 | 6.6 | 6.8 | 6.1 | 7.7 |
| Prismio / Rust | 0.87× | 0.90× | 1.00× | 0.90× | 0.87× | 0.84× |

The 1.0–1.2× prediction assumed arenas over-allocate and that AIF trades footprint for speed. Neither
half happened. Arenas barely fire on this corpus at all, and Prismio is *tighter* than Rust **because**
it does not amortise: a `Vec` that has doubled its way to 1 000 elements holds up to 2× the bytes it
needs, while 1 000 separate `malloc`s hold what they need plus per-block overhead and no slack.
Prismio wins this axis by having the property that loses it every other axis.

Swift's 3.0–3.4× is the Swift runtime's resident footprint, not the programs'. It is a floor, and it
is the same ~4.5 MB on all six.

### 2c · The tail held, and with the optimiser on it is indistinguishable from Rust's

`p99/p50`, the BENCHMARKS §4.2 kill criterion (kill at > 3×):

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio +opt | 1.25 | 1.27 | 1.27 | 1.26 | 1.31 | 1.78 |
| Rust idiomatic | 1.24 | 1.22 | 1.26 | 1.27 | 1.29 | 1.75 |

That is the same distribution shape, to two significant figures, on five of six programs. `p999/p50`:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio +opt | 2.64 | 2.54 | 2.62 | 2.31 | 2.61 | 3.89 |
| Rust idiomatic | 2.85 | 2.92 | 2.74 | 4.77 | 3.96 | 4.85 |

Prismio's p999/p50 is *lower* than idiomatic Rust's on all six. Nothing in the model introduces a
hitch: no collector pause, no reclamation spike, no amortised-growth cliff — and Rust's own relative
tail is worse on g2, because `Vec` growth doubles inside a frame and per-object `malloc` never does.

Read this as a ratio and never as an absolute. Prismio's p99 on g2 is 6.75 µs against Rust's 1.12 µs
— six times worse in the only unit a frame budget is denominated in. The claim that survives is narrow
and it is the right one to keep: **the memory model adds no tail of its own.** What makes Prismio's
tail large is the median it sits on.

---

## 3 · Where the remaining gap comes from

### 3.1 · The optimiser, which is a defect and not a result

Two findings in `runtime/build_driver.c`, neither a memory-model decision:

| | |
|---|---|
| [`build_driver.c:509`](../../runtime/build_driver.c#L509) | `llc <ir> -filetype=obj -o <obj>` — no flags. llc runs the *codegen* pipeline (isel, scheduling, regalloc) but **not** the IR pipeline. `mem2reg`, `SROA`, `GVN`, `LICM`, inlining and vectorisation never touch a user program. |
| [`build_driver.c:638`](../../runtime/build_driver.c#L638) | `clang -Wno-deprecated-declarations -c <runtime.c>` — no `-O`, i.e. **-O0**. That is where `list_get`, `list_push` and the allocator live, called millions of times per run. |

What the first costs is visible in the emitted IR for `integrate`: every local is an `alloca` that is
never promoted, the loop counter round-trips through memory each iteration, and `p` is reloaded from
its stack slot **five times** inside a single `p.px = p.px + p.vx * dt`.

Measured end to end by `bench.py`'s two Prismio rows:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| shipped / +opt | **2.15×** | **1.43×** | **2.77×** | **2.97×** | **2.89×** | **2.15×** |

`optgap.py` splits it into the two flags separately, as a 2×2 with checksums identical in all four
cells of every row: the runtime `-O2` alone is worth more than the program `opt -O2` alone on every
program, which is what you would expect when the hot inner call is in the runtime.

**LTO across the runtime boundary buys nothing.** Tested on g1, g4 and g5 with `-flto` on both sides:
29.6 / 66.4 / 76.3 ms against 25.4 / 65.7 / 77.3 for `+opt`. So the residual is *not* the un-inlined
`list_get` call, which was the obvious hypothesis and is wrong.

The costs of turning it on, both measured: **cold compile time rises ~35%** (134 ms → 181 ms median,
mostly the runtime at `-O2`), and **executable size falls from 56 KB to 39 KB**.

### 3.2 · The representation, which is the real remaining gap

`Vec<Box<T>>` in Rust is Prismio's `List<T>` exactly: a vector of pointers to individually
heap-allocated records. Holding it fixed and letting rustc emit the code separates what the
representation costs from what the compiler costs.

| | representation cost | Prismio +opt | **residual** |
|---|---|---|---|
| g1 — 96-byte record, no per-frame allocation | 1.08× | 1.37× | **1.27×** |
| g4 — 24-byte components, no per-frame allocation | 2.67× | 2.98× | **1.12×** |
| g2 — 32-byte record, ~501 allocations per frame | 8.92× | 5.79× | **0.65×** |

Two things to read off this.

**The residual is 1.12×–1.27×.** With the optimiser on, and holding the data representation constant,
Prismio is within about 20% of rustc. That is the only number here that is a statement about the
compiler's design rather than its build or its containers, and it is small.

**On g2 the residual is below 1.** Prismio at `+opt` is 0.65× of boxed Rust — *faster* than rustc's
own code for the same allocation profile, because Prismio's arena machinery and release paths are
doing real work that `Box`'s malloc/free pair is not. That is the memory model showing up positively,
and it is the only place on this page where it does.

g1's 1.08× does not generalise, and assuming it did would have been an error: a pointer array in front
of a 96-byte record is 8% more traffic; in front of a 24-byte component it is 33% more plus a
dependent load, and it costs 2.67×.

---

## 4 · What the memory model is actually worth, measured

Four of the six corpus programs — **g1, g3, g4, g5 — allocate nothing per frame.** They build a
structure once and then stream over it. An arena has nothing to do in them, which is why `g1_arena` is
written out in full with bumpalo and measures **1.00×**, identical to idiomatic, rather than being
asserted away.

So on two thirds of the corpus the memory model cannot help, and the whole gap there is §3.1 + §3.2 +
the residual. **The corpus is much less allocation-heavy than the T1 story assumes.**

On the two programs that do allocate per frame, the prize is large and it is the arena:

| | Rust boxed (= Prismio's profile) | Rust idiomatic | **Rust arena** |
|---|---|---|---|
| g2 | 8.92× | 1.00× | **0.89×** |
| g6 | — | 1.00× | **0.82×** |

On g2, moving from the boxed profile to a bumpalo arena — same representation, same program, only the
allocation discipline changed — is worth **10.0×**. That is the transformation T1 exists to perform
without being asked, and it remains unclaimed: g2's four allocation sites still land **T2**, against
`g2_frame_loop.psm`'s own header, which says landing anything but T1 means the escape analysis is
wrong. The previous session designed the fix (the `CallerRegion` lattice value plus the
container-disposition change) and correctly declined to build half of it.

**This does not say Prismio would reach 0.89× by adding arenas.** It says g2's allocation term is
worth up to 10× and is currently paid in full. The other terms would remain.

---

## 5 · The axes nobody predicted, where the result is good

**Executable size.** Prismio **39–40 KB** with the optimiser on (56–57 KB as shipped) against Rust's
458–476 KB and Swift's 54–60 KB. Rust statically links its standard library and Swift dynamically
links a runtime that ships with the OS, so the three are not measuring the same thing — but a
self-contained 39 KB binary with no runtime dependency beyond libc is a real property and an 11×
advantage over Rust.

**Cold compile time**, source to linked executable, median of 3 with no prior artifact. Prismio
recompiles its runtime on every build when no `runtime.lib` is installed, and the `+opt` figure
includes that at `-O2`, so the two Prismio columns are comparable to each other:

| | Prismio +opt | Prismio shipped | rustc | swiftc |
|---|---|---|---|---|
| g1 | 177 ms | 134 | 110 | 271 |
| g6 | 187 ms | 140 | 138 | 348 |

Turning the optimiser on costs ~35% compile time and still leaves Prismio at 1.4× rustc and **1.8×
faster than swiftc**. These are 100–300 line programs and this is not a scaling claim — the known
superlinearity in module size is unaddressed and untested here.

---

## 6 · Which assumptions were wrong

1. **"The baseline allocates per object too."** It does not, and this is the single wrong assumption
   behind the churn prediction, the alloc-heavy prediction and most of §4.1. `Vec<T>` had already
   solved the problem AIF is aimed at, by inline storage, more cheaply and more completely. Any claim
   about allocator traffic has to be stated against inline-storage containers or it measures nothing.

2. **"The backend is at parity, so a comparison isolates the memory model."** Every projection in
   BENCHMARKS §4 is stated as though the only difference between Prismio and Rust were the memory
   model. Two optimisation stages did not run, worth 1.43×–2.97×. The internal `--debug` control was
   built specifically to isolate AIF — and it does, which is exactly why it never caught this: both
   sides of that comparison share the same -O0 runtime and the same unoptimised IR. **A control that
   holds everything constant cannot detect what is constantly wrong.**

3. **"Arenas will cost footprint."** Backwards. Prismio uses *less* memory than idiomatic Rust on five
   of six programs, because per-object allocation has no geometric slack. The mechanism the prediction
   feared is not firing, and the mechanism that replaces it happens to win.

4. **"The corpus is allocation-heavy."** Two of six programs allocate per frame. The corpus README
   describes G2 as "the dominant allocation pattern in a real-time renderer" and that is true of G2; it
   is not true of G1, G3, G4 or G5, and the tier work has been ranked as though it were.

5. **"g1's representation cost generalises."** 1.08× on a 96-byte record, 2.67× on 24-byte components.
   Measured in both places on purpose; assuming the first would have attributed g4's gap to the backend
   and sent the next session at the wrong target.

Two things that were **right** and are worth keeping: the tail (p99/p50 within 0.03 of idiomatic Rust
on five of six programs, against a 3× kill criterion), and the residual — with the build fixed and the
representation held constant, this compiler is within 1.12×–1.27× of rustc.

---

## 7 · What this means for the ranking

Not a recommendation to act on this session — the brief forbade compiler changes. This is the handoff
note for whoever picks it up.

1. **Turn the optimiser on.** `opt -O2` on the program IR, `-O2` on the runtime; two string literals
   in `build_driver.c`. Worth 1.43×–2.97×, and it costs ~35% compile time and *saves* 16 KB of binary.
   It changes the compiler's own build, so it needs the full workflow: two generations, fixpoint warm
   and cold, 92/92, seed refresh. Do it first — not because it is the biggest lever, but because until
   it is done every benchmark measures the build pipeline, which is what this one spent most of its
   effort discovering.
2. **Inline element storage for `List<T>`** — the `Vec<T>` representation. Unranked and unstudied until
   now, and after item 1 it is **the whole remaining gap** on four of six programs: worth 1.08×–8.92×
   depending on the record. Bigger than anything currently on the list. It interacts with handles
   (COMPILER-AUDIT finding 6) rather than avoiding them.
3. **Caller-scope `E` plus container disposition** (designed two sessions ago, still not built). Now
   carries a measured prize: **up to 10× on g2**, ~0 on four of six programs. Large, and narrow.
4. Re-run `xlang/bench.py` after each of the above. The ordering of 2 and 3 may invert once 1 lands.

---

## 8 · Threats to validity

- **One machine, one OS, one microarchitecture.** Apple M5. Nothing here is portable evidence.
- **`+opt` is a reconstruction, not the compiler's code path.** It links the same two runtime sources
  a user build links and reproduces `prismio build` to within 1.6% with the flags removed, but a real
  implementation would run the pipeline in-process via LLVM's `PassBuilder` and could differ.
- **Program sizes are small** — 100–300 lines, working sets of 1.5–7.7 MB, all L2-resident. The layout
  results in particular would move on a working set that misses.
- **Idiomatic is a judgement call.** Rust idiomatic is `Vec<T>`; Swift idiomatic is structs in `Array`
  with `final class` for owned aggregates. Both are argued in `xlang/README.md`, and both were chosen
  in the direction *unfavourable* to Prismio, on the grounds that a rigged falsification is worth less
  than none.
- **g4 is the noisiest program in the set.** Its hand-tuned Rust p99 moved from 2.21 µs to 4.94 µs
  between two runs of this suite with no code change. Treat g4's p99/p999 as indicative; its loop
  medians are stable to ~5%.
- **p999 has few samples on g1 and g5** — 6 and 4 per run. g2 (20 000) and g6 (30 000) carry the tail
  argument.
- **g6's frame excludes world construction**, 1 event per 100 frames, which would otherwise land on p99
  and describe the rebuild rather than the frame. It is in wall time and in the allocation totals.
- **Swift's `report()` builds one large String**, outside the timed region but inflating its wall/loop
  difference relative to the others.
