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
"easier, not faster".* It does not tie — hand-tuned Rust wins by 1.7×–17.9× — but the interesting
answer is narrower than that.

**Prismio is 1.12×–5.57× idiomatic Rust.** It was 2.9×–9.0× when the session started, because
`prismio build` ran no optimiser on either the program IR or the runtime; **that is fixed and shipped
in this branch**, worth 1.43×–2.91× (§3.1).

What is left splits cleanly. **For the same data representation Prismio is within 1.20×–1.30× of
Rust** — that residual is the only figure here that is a statement about the compiler's design.
Everything else is `List<T>` being a vector of pointers where `Vec<T>` is inline storage, which costs
1.09× on a wide record and 8.88× where the record is allocated per frame. On the two programs where
allocation dominates, the arena AIF is supposed to place automatically is worth **9.9×**, and it is
still unclaimed. §9 works through what the unbuilt features are worth from these numbers.

---

## 1 · The headline table

Loop time — the sum of the program's own per-frame samples, so process startup and the report dump
are excluded. Median of 20 runs, relative to idiomatic Rust.

Repeating the whole suite moves these ratios by up to ~5%, so read the third significant figure as
noise. `xlang/results.json` holds the most recent run.

| | g1 particles | g2 frame loop | g3 scene graph | g4 ECS | g5 asset cache | g6 engine+game |
|---|---|---|---|---|---|---|
| **Prismio** | **1.42×** | **5.57×** | **1.12×** | **3.09×** | **2.66×** | **4.22×** |
| Rust idiomatic | 1.00× | 1.00× | 1.00× | 1.00× | 1.00× | 1.00× |
| Rust arena | 1.00× | 0.90× | — | — | — | 0.82× |
| Rust hand-tuned | 0.26× | 0.56× | 0.67× | 0.82× | 0.15× | 0.71× |
| Swift idiomatic | 0.99× | 1.78× | 1.11× | 3.88× | 2.38× | 2.81× |
| *Rust boxed (diagnostic)* | *1.09×* | *8.88×* | — | *2.58×* | — | — |
| **residual** (Prismio ÷ boxed) | **1.30×** | *0.63×* | — | **1.20×** | — | — |

Absolute medians, milliseconds:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio | 26.3 | 103.4 | 51.4 | 67.6 | 78.6 | 233.3 |
| Rust idiomatic | 18.5 | 18.6 | 45.8 | 21.9 | 29.5 | 55.3 |
| Rust hand-tuned | 4.7 | 10.3 | 30.8 | 17.9 | 4.4 | 39.5 |
| Swift idiomatic | 18.3 | 33.0 | 50.9 | 84.7 | 70.3 | 155.5 |

**All 29 programs print identical checksums**, including the SoA rewrite, the fused-loop rewrite, the
bucketed rewrite and the reset-world rewrite. `bench.py` refuses to time a program whose variants
disagree, so this is asserted on every run rather than checked once.

---

## 2 · Prediction vs measurement, per axis

Predictions from the handoff brief, with BENCHMARKS §4.1 and §4.2 beside them. Measured against the
compiler as it stands at the end of this session, i.e. with the optimiser fix of §3.1 in.

| Axis | Predicted | Measured | Verdict |
|---|---|---|---|
| Alloc-heavy vs **idiomatic** Rust | 0.8–1.1× | **5.57×** (g2), **4.22×** (g6) | ✗ wrong by ~5× |
| Alloc-heavy vs **tuned** Rust | 1.0–1.3× | **10.0×** (g2), **5.9×** (g6) | ✗ wrong by ~8× |
| Peak RSS vs idiomatic Rust | 1.0–1.2× | **0.84–1.00×** | ✗ wrong, *in our favour* |
| Allocator churn | 0.2–0.5× | **10.5×–63.7×** more allocations | ✗ wrong by ~100× |
| BENCHMARKS §4.1: AIF vs Rust idiomatic | 0.71× | 1.12–5.57× | ✗ falsified |
| BENCHMARKS §4.2: object graphs, kill > 1.00 | 0.70–0.90 | 1.12–5.57 | ✗ **kill criterion met** |
| BENCHMARKS §4.2: data-parallel bulk, kill > 0.90 | 0.35–0.65 | 1.42 (g1, nearest shape here) | ✗ **kill criterion met** |
| BENCHMARKS §4.2: p99 tail, kill p99/p50 > 3× | ≈ C | **1.22–1.75×** | ✓ **held** |
| BENCHMARKS §4.1: Swift at 1.94× of Rust | 1.94× | 0.99–3.88×, median 2.08× | ✓ held |
| Executable size | not predicted | Prismio **39–40 KB**, Rust 457–475 KB | — |
| Cold compile time | not predicted | Prismio 1.5× rustc, 0.61× swiftc | — |

Every speed row is falsified. The optimiser fix moved the magnitudes by 1.4×–2.9×; it moved no
verdict. Three rows are worth more than a line each.

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

Rates, for the record: Prismio sustains **99 M allocations/s** on g2 (10.2 M in 103 ms), with frees matching to within 0.01%. Rust's boxed diagnostic runs the
same profile at 62 M/s. The allocator is not slow; there is simply 64× more work asked of it.

### 2b · Peak RSS was wrong in our favour, and for the opposite reason to the one assumed

Unchanged by optimisation, as expected:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio | 1.7 MB | 2.0 | 2.0 | 2.0 | 1.5 | 2.2 |
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
| Prismio | 1.22 | 1.27 | 1.28 | 1.29 | 1.54 | 1.75 |
| Rust idiomatic | 1.26 | 1.22 | 1.28 | 1.25 | 1.54 | 1.76 |

That is the same distribution shape, to two significant figures, on five of six programs. `p999/p50`:

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| Prismio | 2.64 | 2.82 | 3.89 | 3.81 | 3.03 | 3.92 |
| Rust idiomatic | 3.05 | 5.97 | 4.44 | 4.39 | 3.93 | 5.99 |

Prismio's p999/p50 is *lower* than idiomatic Rust's on all six. Nothing in the model introduces a
hitch: no collector pause, no reclamation spike, no amortised-growth cliff — and Rust's own relative
tail is worse on g2, because `Vec` growth doubles inside a frame and per-object `malloc` never does.

Read this as a ratio and never as an absolute. Prismio's p99 on g2 is 6.50 µs against Rust's 1.12 µs
— six times worse in the only unit a frame budget is denominated in. The claim that survives is narrow
and it is the right one to keep: **the memory model adds no tail of its own.** What makes Prismio's
tail large is the median it sits on.

---

## 3 · Where the remaining gap comes from

### 3.1 · The optimiser — found here, fixed in this branch

Two findings in `runtime/build_driver.c`, neither a memory-model decision:

| | |
|---|---|
| `compile_ir_to_object` | ran `llc <ir> -filetype=obj` with **no flags**. llc runs the *codegen* pipeline (isel, scheduling, regalloc) but **not** the IR pipeline, so `mem2reg`, `SROA`, `GVN`, `LICM`, inlining and vectorisation never touched a user program. |
| `build_from_toolchain_sources` | compiled the runtime with **no `-O`**, i.e. -O0. That is where `list_get`, `list_push` and the allocator live, called millions of times per run. |

What the first cost was visible in the emitted IR for `integrate`: every local an `alloca` that is
never promoted, the loop counter round-tripping through memory each iteration, and `p` reloaded from
its stack slot **five times** inside a single `p.px = p.px + p.vx * dt`.

Both now pass `-O2`, and `compile_ir_to_object` uses `clang -O2 -c` rather than `llc` — clang runs
both pipelines in one process, was already required for the link, and takes `.ll` directly, which
drops llc from the user-build path. `tools/bootstrap.sh` and `.ps1` were changed the same way, so the
compiler is built optimised too.

`optgap.py` still builds the 2×2 over the two flags, now as a regression detector. Checksums are
identical in all four cells of every row:

| program | -O0 both | runtime -O2 | program opt | both | total |
|---|---|---|---|---|---|
| g1 | 54.2 ms | 33.8 | 39.7 | 25.5 | **2.13×** |
| g2 | 153.5 ms | 125.7 | 127.1 | 107.5 | **1.43×** |
| g3 | 148.3 ms | 93.1 | 99.3 | 52.3 | **2.84×** |
| g4 | 194.1 ms | 103.4 | 137.3 | 66.7 | **2.91×** |
| g5 | 222.0 ms | 117.4 | 120.6 | 77.3 | **2.87×** |
| g6 | 486.3 ms | 299.8 | 372.1 | 229.4 | **2.12×** |

The runtime flag is worth more than the program flag on every program, which is what you would expect
when the hot inner call is in the runtime.

**`-O3` was measured and rejected.** Across the corpus it lands between 0.98× and 1.03× of `-O2` —
noise — at the same compile time (`optlevel.py`). `-flto` is speed-neutral too and worth ~15% of
binary size, but needs linker plugin support that is not portable enough to be a default. `-Os` is
1.0–1.04×, i.e. also free, and not worth the risk of a size/speed regression appearing later.

**LTO across the runtime boundary buys nothing** on speed. Tested on g1, g4 and g5: within 2% of
`-O2`. So the residual is *not* the un-inlined `list_get` call, which was the obvious hypothesis and
is wrong.

**What it cost.** Cold compile time rose from ~140 ms to ~190 ms per program (+35%), executables fell
from 56 KB to 39 KB (−30%), and the **compiler's own frontend got 22% faster** (103 → 80 ms to emit
IR for `src/main.psm`) because it is now built at `-O2` itself. Fixpoint holds warm and cold,
cold == warm, 92/92, and the emitted IR is byte-identical to the pre-change compiler's — which is the
right outcome for a change that is a build flag and not codegen.

### 3.2 · The representation, which is the real remaining gap

`Vec<Box<T>>` in Rust is Prismio's `List<T>` exactly: a vector of pointers to individually
heap-allocated records. Holding it fixed and letting rustc emit the code separates what the
representation costs from what the compiler costs.

| | representation cost | Prismio | **residual** |
|---|---|---|---|
| g1 — 96-byte record, no per-frame allocation | 1.09× | 1.42× | **1.30×** |
| g4 — 24-byte components, no per-frame allocation | 2.58× | 3.09× | **1.20×** |
| g2 — 32-byte record, ~501 allocations per frame | 8.88× | 5.57× | **0.63×** |

Two things to read off this.

**The residual is 1.20×–1.30×.** Holding the data representation constant, Prismio is within about a
quarter of rustc. That is the only number here that is a statement about the compiler's design rather
than its build or its containers, and it is small.

**On g2 the residual is below 1.** Prismio is 0.63× of boxed Rust — *faster* than rustc's own code for
the same allocation profile, because AIF's arena machinery and release paths are doing real work that
`Box`'s malloc/free pair is not. That is the memory model showing up positively, and it is the only
place on this page where it does.

g1's 1.09× does not generalise, and assuming it did would have been an error: a pointer array in front
of a 96-byte record is 8% more traffic; in front of a 24-byte component it is 33% more plus a
dependent load, and it costs 2.58×.

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
| g2 | 8.88× | 1.00× | **0.90×** |
| g6 | — | 1.00× | **0.82×** |

On g2, moving from the boxed profile to a bumpalo arena — same representation, same program, only the
allocation discipline changed — is worth **9.9×**. That is the transformation T1 exists to perform
without being asked, and it remains unclaimed: g2's four allocation sites still land **T2**, against
`g2_frame_loop.psm`'s own header, which says landing anything but T1 means the escape analysis is
wrong. The previous session designed the fix (the `CallerRegion` lattice value plus the
container-disposition change) and correctly declined to build half of it.

**This does not say Prismio would reach 0.89× by adding arenas.** It says g2's allocation term is
worth up to 9.9× and is currently paid in full. The other terms would remain.

---

## 5 · The axes nobody predicted, where the result is good

**Executable size.** Prismio **39–40 KB** against Rust's 457–475 KB and Swift's 53–60 KB. Rust
statically links its standard library and Swift dynamically links a runtime that ships with the OS,
so the three are not measuring the same thing — but a self-contained 39 KB binary with no runtime
dependency beyond libc is a real property and an 11× advantage over Rust.

**Cold compile time**, source to linked executable, median of 3 with no prior artifact. Prismio
recompiles its runtime on every build when no `runtime.lib` is installed, so its figure includes that:

| | Prismio | rustc | swiftc |
|---|---|---|---|
| g1 | 183 ms | 107 | 269 |
| g6 | 203 ms | 145 | 351 |

1.5× rustc and **1.6× faster than swiftc**. These are 100–300 line programs and this is not a scaling
claim — the known superlinearity in module size is unaddressed and untested here.

---

## 6 · Which assumptions were wrong

1. **"The baseline allocates per object too."** It does not, and this is the single wrong assumption
   behind the churn prediction, the alloc-heavy prediction and most of §4.1. `Vec<T>` had already
   solved the problem AIF is aimed at, by inline storage, more cheaply and more completely. Any claim
   about allocator traffic has to be stated against inline-storage containers or it measures nothing.

2. **"The backend is at parity, so a comparison isolates the memory model."** Every projection in
   BENCHMARKS §4 is stated as though the only difference between Prismio and Rust were the memory
   model. Two optimisation stages did not run, worth 1.43×–2.91×. The internal `--debug` control was
   built specifically to isolate AIF — and it does, which is exactly why it never caught this: both
   sides of that comparison share the same -O0 runtime and the same unoptimised IR. **A control that
   holds everything constant cannot detect what is constantly wrong.**

3. **"Arenas will cost footprint."** Backwards. Prismio uses *less* memory than idiomatic Rust on five
   of six programs, because per-object allocation has no geometric slack. The mechanism the prediction
   feared is not firing, and the mechanism that replaces it happens to win.

4. **"The corpus is allocation-heavy."** Two of six programs allocate per frame. The corpus README
   describes G2 as "the dominant allocation pattern in a real-time renderer" and that is true of G2; it
   is not true of G1, G3, G4 or G5, and the tier work has been ranked as though it were.

5. **"g1's representation cost generalises."** 1.09× on a 96-byte record, 2.58× on 24-byte components.
   Measured in both places on purpose; assuming the first would have attributed g4's gap to the backend
   and sent the next session at the wrong target.

Two things that were **right** and are worth keeping: the tail (p99/p50 within 0.04 of idiomatic Rust
on five of six programs, against a 3× kill criterion), and the residual — with the build fixed and the
representation held constant, this compiler is within 1.20×–1.30× of rustc.

---

## 7 · What this means for the ranking

1. ~~**Turn the optimiser on.**~~ **Done in this branch.** `clang -O2 -c` for the program IR, `-O2`
   for the runtime, in `build_driver.c` and both bootstrap scripts. Worth 1.43×–2.91×; costs ~35%
   compile time; saves 30% of binary size; made the compiler's own frontend 22% faster. Fixpoint warm
   and cold, cold == warm, 92/92, emitted IR byte-identical.
2. **Inline element storage for `List<T>`** — the `Vec<T>` representation, which needs views/slices to
   be expressible. Unranked and unstudied until this session, and now **the whole remaining gap on
   four of six programs**: worth 1.09×–8.88× depending on the record, and the projection in §9 puts
   Prismio at ~1.2–1.3× of idiomatic Rust across the board once it lands. Bigger than anything
   previously on the list, and a prerequisite for the layout work below.
3. **Caller-scope `E` plus container disposition** (designed two sessions ago, still not built).
   Measured prize: **up to 9.9× on g2**, ~0 on four of six programs. Large, and narrow. Note it
   partly overlaps item 2 — inline storage removes most of g2's allocations by itself.
4. **Layout search / SoA.** The largest measured headroom anywhere in this suite (§9), and still
   blocked behind handles.
5. Re-run `xlang/bench.py` after each. The ordering of 3 and 4 may invert once 2 lands.

---

## 8 · Threats to validity

- **One machine, one OS, one microarchitecture.** Apple M5. Nothing here is portable evidence.
- **`prismio build` shells out to `clang` for both the IR and the runtime.** A production compiler
  would run the pipeline in-process via LLVM's `PassBuilder`; the flags would be the same but the
  process-spawn cost in the compile-time column would not.
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

---

## 9 · Can this beat Rust? A projection from these numbers

Asked directly, so answered directly. Everything below is extrapolation from the measurements above
and is labelled as such — it is not a result.

**Three different questions hide inside "beat Rust".**

**(a) Beat idiomatic Rust on general code — parity is the realistic target, not a win.**

The residual says that with the representation held constant this compiler is 1.20×–1.30× of rustc.
So inline `List<T>` storage (item 2) closes the container gap and lands Prismio at roughly the
residual — **~1.2–1.3× of idiomatic Rust**, everywhere. Automatic arenas then take the
allocation-heavy programs a little further: Rust's own arena variant is 0.90× (g2) and 0.82× (g6) of
idiomatic, so Prismio with automatic placement projects to ≈1.25 × 0.86 ≈ **1.05–1.10×**. That is
parity, reached by two large projects. Closing the last 20% is backend work — inlining heuristics,
alias information, better `getelementptr` folding — with no single lever behind it.

**(b) Beat idiomatic Rust where layout dominates — yes, plausibly by ~3×, and this is the only
measured path to a large win.**

`g1_tuned.rs` is *pure structure-of-arrays* — no arena, no algorithmic change, just one `Vec` per
field — and it runs at **0.26×** of idiomatic Rust. `integrate` touches 6 of 12 fields and `fade`
touches 2, so AoS streams 96 bytes to read 48 and then 16. Rust programmers overwhelmingly do not
write SoA by hand; AIF's LAYOUT.md says the compiler should choose it without being asked. If it
did, and the residual held, g1 projects to 1.30 × 0.26 ≈ **0.34× of idiomatic Rust**.

That is the number that would make the product claim true, and it is the one BENCHMARKS H2 already
predicted ("layout search deserves ~80% of the budget because a cache miss costs ~100× a refcount
op"). g1's 0.26× is the first measurement in this project that supports H2.

Three caveats, all load-bearing:

- **It is blocked behind handles.** SoA makes one logical object several allocations, so a field
  reference stops being `getelementptr` on a pointer — COMPILER-AUDIT §1 finding 6. Costed last
  session: 337 `ptr_to_node` call sites, 190 punned `str_equals(x, "")` tests, 235 externs naming a
  raw pointer. A rewrite of how the compiler represents its own AST.
- **g1 is the best case in the corpus, not the average.** g4 is *already* SoA by data model, so
  layout search buys it nothing; its hand-tuned 0.82× is loop fusion, not layout. The corpus has one
  strong SoA candidate out of six.
- **The compiler has to beat the programmer at choosing, not just at typing.** A wrong SoA choice on
  a program that iterates whole records is a regression, and LAYOUT §7.2's access profile is
  statically estimated — `workload` (measured frequencies) is deliberately unbuilt.

**(c) Beat hand-tuned Rust — the annotations are the right answer, and today they do not work.**

The language is not inference-only: `region`, `unique`, `pin` and `drop` exist so a programmer can
tune a hot scope by hand while the rest of the program stays untouched. That is the correct answer to
hand-tuned Rust — a one-word annotation against a rewrite — and it means the ceiling is set by what
the language can *express*, not by what the analysis can *prove*.

So it was measured. `prismio/g2_region.psm` is `g2.psm` with `region frame_arena { … }` around the
frame body and nothing else changed. G2 is the right test: its corpus header says *"This is the T1
case in its purest form… If these allocations do not land T1, the escape analysis is wrong"*, and
they land T2. A programmer reading that manifest would reach for exactly this annotation.

| | plain | `+ region` |
|---|---|---|
| loop time | 101.3 ms | **175.5 ms (1.73×)** |
| allocations served by the arena | — | **0 of 10 201 215** |
| regions entered | — | 20 000 |
| tier/disposition of the four sites | T2 owned | **T2 owned — byte-identical manifest** |

**The annotation is not unimplemented — it is inert.** The region is created and destroyed 20 000
times, and serves nothing. The cause is the one already recorded in HANDOFF: `aif_arena_at_node`
rejects a site on `in_container` *before* it ever looks at escape, and g2's `DrawCmd` reaches
`list_push`, whose `retain_in(0)` sets `in_container`. The exclusion is correct in itself — a
container tears its elements down through the deallocator, and an interior arena pointer is not
something `free` can take — but it fires regardless of what the programmer asked for.

The 1.73× is the second half of the result. 74 ms over 10.2 M allocations is ≈7 ns each, which points
at a per-allocation arena check that is paid and then declined, rather than at the 20 000 region
push/pops (those would have to cost 3.7 µs each). That mechanism is inferred from the arithmetic, not
proven; it is worth confirming before anyone optimises it.

**This is the finding that most changes the plan.** The two-tier story — auto inference for most code,
annotations for the hot path — has a hole exactly where the corpus says it matters most: the escape
hatch is blocked by the same gate that blocks inference, so a programmer cannot tune their way out
either. And unlike the inference gap, this one is *visible to users*: they write the annotation, the
manifest tells them nothing changed, and the program gets slower.

Fixing it is the `CallerRegion` + container-disposition item (ranking §7 item 3), which was already
the plan — but it should now be understood as unblocking **both** tiers, not just inference. Until it
lands, `region` should probably warn when it serves zero allocations rather than silently costing
1.73×.

What annotations will *not* reach, even fixed: `g5_tuned.rs` at 0.15× is mostly an algorithmic change
— bucketing entities by material so each frame visits 2 000 instead of 24 000 — and `g6_tuned.rs`
reuses the world across scenarios, which is a statement about what the program means. Those stay with
the programmer in any language.

**On the three features named in the question specifically:**

| | measured basis | projection |
|---|---|---|
| **Views & slices** | the enabler for inline `List<T>`; representation costs 1.09×–8.88× today | the highest-value item in the project — parity with idiomatic Rust |
| **`@` annotations** | `region` on g2: 0 allocations served, 1.73× slower, manifest unchanged | the escape hatch is inert on the corpus's canonical case; unblocking it is the same work as unblocking inference |
| **Full layout search + `workload`** | `g1_tuned` = 0.26×, pure SoA | the only path to *beating* Rust, ~3× where layout dominates; blocked behind handles |
| **Concurrency + T-domains** | **nothing** — the corpus is single-threaded, six programs, zero threads | no evidence in either direction, and it is the axis where Rust's claim is strongest |

The concurrency row deserves emphasis rather than a shrug. There is no benchmark here that touches
it, so any claim about it today would be exactly the kind of unmeasured projection that §2 spent a
page falsifying. If it matters to the product, the corpus needs a concurrent program before the
feature gets a ranking.

**The claim the numbers actually support** is not "faster than Rust". It is **"tuned-Rust behaviour
from untuned code, with an annotation when that is not enough"**: the arena that `g2_arena.rs` gets
from bumpalo plus explicit lifetimes, and the layout that `g1_tuned.rs` gets from hand-written SoA,
obtained from source that looks like `aif/corpus/`. Against *idiomatic* Rust that is worth 0.26×–0.90×
on the programs where it applies and nothing on the rest.

Both halves of that claim are currently unclaimed, and they are blocked on the same two items. The
inference half needs `CallerRegion` + container disposition; **the annotation half needs the identical
change**, which is what §9(c) measured. That is good news for sequencing — one project unblocks both
tiers — and it means the two-tier design has not actually been tested yet on any program where it
would matter.
