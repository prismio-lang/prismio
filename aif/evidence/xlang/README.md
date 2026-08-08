# The cross-language suite — Prismio vs Rust vs Swift

First measurement of the corpus against languages people would actually choose instead of it.
BENCHMARKS §3.2 files Rust and Swift under priority 4, "context only, and only after 1–3 are
stable". 1–3 are stable, and the question this suite exists to answer is the one that decides
whether there is a performance claim at all: **if tuned Rust ties us everywhere, the claim becomes
"easier, not faster"** — still real, but a different product.

One command:

```bash
python3 aif/evidence/xlang/bench.py --compiler build/gen4 --runs 20
```

It builds everything, asserts every variant of a program prints identical checksums, measures, and
writes `results.json`. `--only g2` restricts to one program; `--skip-build` reuses `build/`.

## What is here

| | |
|---|---|
| `prismio/g1..g6.psm` | the corpus programs, workload functions **verbatim**, with a timing `main()` |
| `rust/g*_idiomatic.rs` | `Vec<T>` with values inline — what a competent Rust programmer writes first |
| `rust/g*_arena.rs` | bumpalo 3.20.3 — what they write after a profile (g1, g2, g6) |
| `rust/g*_tuned.rs` | whatever it takes: SoA, fused loops, reused buffers, bucketing |
| `rust/g*_boxed.rs` | **diagnostic, not a variant** — Prismio's representation, rustc's codegen (g1, g2, g4) |
| `swift/g*.swift` | one idiomatic variant: structs in Arrays, `final class` for owned aggregates |
| `allocount.c` | malloc/free counter, loaded by interposition into any language's binary |
| `vendor/libbumpalo.rlib` | built on first run by `bench.py`; not committed, since an .rlib is host- and rustc-specific |

29 programs. Every one of them prints the same checksums as the Prismio original, and `bench.py`
refuses to measure a program whose variants disagree.

## A note on what this suite found and changed

When it was first run, `prismio build` ran **no optimiser**: `compile_ir_to_object` invoked `llc` with
no flags, so the LLVM *IR* pipeline never touched a user program, and the runtime was compiled with no
`-O` at all. The harness carried a second `Prismio +opt` row reconstructing what the missing flags
were worth — 1.43×–2.91× across the corpus.

Both flags landed in `runtime/build_driver.c` and in both bootstrap scripts, the shipped binary then
matched the reconstruction to within 4%, and the extra row was removed. `optgap.py` still builds the
2×2 over the two flags so that removing them shows up as a measurable regression, and `optlevel.py`
holds the evidence for `-O2` over `-O3`/`-Os`/LTO (all within noise on speed).

One methodological trap from that work, worth keeping: the reconstruction initially reused prebuilt
runtime objects, which made the optimised build look *faster* to compile than the unoptimised one.
`prismio build` recompiles the runtime per program when no `runtime.lib` is installed, so the
reconstruction had to as well. It costs ~35%, not −40%.

## The four decisions worth arguing with

**Idiomatic Rust is `Vec<T>`, not `Vec<Box<T>>`.** Prismio's `List<Particle>` is a vector of
pointers to individually heap-allocated particles; the matching Rust is `Vec<Box<Particle>>`. Nobody
writes that. Transcribing Prismio's representation into Rust and calling it idiomatic would rig the
comparison in our favour, and a rigged falsification test is worth less than none.

**So the representation is measured separately.** `g1_boxed.rs` and `g2_boxed.rs` hold Prismio's
representation fixed and let rustc emit the code. The distance from `idiomatic` to `boxed` is what
the representation costs; the distance from `boxed` to Prismio is everything else. Without that
column a Prismio/Rust gap has no attribution, and attribution is the output of the exercise.

**The arena variant only exists where there is something transient to arena.** Four of the six
corpus programs — g1, g3, g4, g5 — allocate **nothing per frame**: they build a structure once and
then stream over it. An arena has nothing to do there, and g1's arena variant is written out in full
and measured precisely so that this is a result rather than an assertion. g2 and g6 are the two
programs with real per-frame allocation.

**Release settings, not favourable ones.** `rustc -C opt-level=3` with the default unwinding panic
strategy, i.e. `cargo build --release` exactly. `panic=abort` would delete the landing pads around
every allocation and flatter Rust against languages that do not unwind — the wrong direction when
the point is to try to falsify our own claim. Swift gets `-O -wmo`, which is what a release build
uses.

## How each axis is measured

**Frame time p50 / p99 / p999 — the lead metric.** In-process. Every program calls
`clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)` around each frame — literally the same libc entry point
in all three languages, so the clock is not one of the things that differs — buffers the samples in
storage allocated before the loop, and prints them after it. Process wall time cannot see a tail,
and the tail is what a frame budget is made of.

**allocs / frees.** A separate run under `allocount.dylib`, which interposes `malloc`, `calloc`,
`realloc` and `free`. It counts the *allocator*, which is the only way the number means the same
thing in four languages: Prismio's `--verify` counters, Rust's allocator hooks and Swift's runtime
each count a different event, but nothing reaches memory without going through malloc. Rust's
default global allocator on macOS is the system one and Swift's `swift_slowAlloc` bottoms out in
malloc, so all of them land in the counter.

Interposition costs an indirect call per allocation, so **these runs are never used for timing**.
Counts are deterministic; rates use the median clean loop time as the denominator.

There is a floor of roughly 30 mallocs and 160 callocs per process from dyld and the C runtime
before `main`. It is noise against the counts here and is not subtracted, because subtracting a
measured constant from one language's column and not another's is how comparisons go wrong.

**Peak RSS.** `ru_maxrss` from `wait4` on the child. Exact rather than sampled — a poll loop can
miss a spike, and a spike is the point.

**loop ms vs wall ms.** `loop` is the sum of the frame samples: the work. `wall` is the whole
process including startup, setup outside the frame loop, and the report dump. Both are printed
because they answer different questions and because quoting one as the other is how the `--debug`
result got misread last session.

**Cold compile time.** Median of 3 compiles with no prior output artifact. Source to linked
executable, which is what `prismio build`, `rustc` and `swiftc` each do in one command. "Cold" means
no incremental cache to reuse; it does not mean a cold OS page cache.

## Fidelity notes

The Prismio ports change **only `main()`**. Every workload function is byte-identical to
`aif/corpus/`. The timing harness adds one `List<Int>` sample buffer, grown to its final length
before the measured loop so that recording a frame allocates nothing — and `prismio aif` confirms
the perturbation is exactly that one site: the tier, disposition and layout of every original
allocation site is unchanged from the corpus program.

`clock_gettime_nsec_np` is declared with `extern fn` in the `.psm` files rather than added to the
runtime. Nothing in the benchmark set needs a builtin, and keeping the clock out of the runtime means
the ports do not depend on a runtime version.

Frame counts are raised from corpus size (where a whole run is ~11 ms, most of it process startup)
to something that gives the tail enough samples: g1 6 000, g2 20 000, g3 10 000, g4 10 000, g5
4 000, g6 30 000. g6's frame is one *tick*; its world is rebuilt every 100 ticks and that rebuild is
counted in wall time and in the allocation totals but deliberately kept out of the frame samples,
where 1 event per 100 frames would land on p99 and describe the rebuild rather than the frame.

## Results

`RESULTS-xlang.md` in `aif/evidence/`, with what was predicted beside what was measured.
