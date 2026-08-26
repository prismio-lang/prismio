# The concurrency axis

**Status: GREEN, 2026-08-26.** The corpus has a concurrent program. It is the
first Prismio program in this project to beat idiomatic Rust in a controlled
side-by-side measurement, and it found two leaks in the task model on its first
run — one of which is now fixed.

Raw results:

- [`xlang/results-g9-concurrency.json`](xlang/results-g9-concurrency.json) — before the task fix
- [`xlang/results-g9-taskrelease.json`](xlang/results-g9-taskrelease.json) — after
- [`results-g9-corpus-gate.json`](results-g9-corpus-gate.json) — the 7-program corpus gate
- [`results-task-release.json`](results-task-release.json) — the task-release milestone gate

## 1 · Why the item existed

TODO's standing entry: *"It is six single-threaded programs; concurrency is
unmeasured and it is the axis where Rust's claim is strongest. Any concurrency
ranking needs a concurrent program in the corpus first."*

`g9_bands` is that program. A per-frame parallel reduction — partition the step,
run the partitions, join at the frame boundary — because that is the only shape
Prismio's model admits without argument: tasks are isolated, so a band shares
nothing with its siblings and the join is the single edge between them.

Two ports, and the distinction between them is the result:

| arm | what it is |
|---|---|
| `g9_idiomatic.rs` | `std::thread::spawn` + `join` per frame. The honest peer — one OS thread per task, created and destroyed every frame, exactly as Prismio's `spawn` is |
| `g9_tuned.rs` | four workers started once, fed over `mpsc` channels. What a tuned Rust program actually does, and what says how much of the gap is the thread rather than the code |

`aif_differential.py` globs `aif/corpus/*.psm`, so the corpus now covers `spawn`
in the differential too — 17 sources became **18**, and the new one agrees.

## 2 · Where Prismio stands

25 runs, checksums enforced across all arms (`total 1856014121; last 1579165008`),
after the task-handle fix in §4:

| variant | p50 µs | p99 µs | p999 µs | loop ms | RSS MB | allocs | exe KB |
|---|---:|---:|---:|---:|---:|---:|---:|
| Prismio | **50.71** | **76.08** | **93.29** | **102.9** | **1.5** | **8,201** | **78** |
| Rust idiomatic | 56.25 | 84.12 | 102.29 | 115.2 | 1.8 | 62,839 | 505 |
| Rust hand-tuned | 34.79 | 49.79 | 60.62 | 71.0 | 1.8 | 785 | 550 |

Relative to idiomatic Rust: **p50 0.90×, p99 0.90×, p999 0.91×, loop 0.89×,
RSS 0.83×, allocations 0.13×.**

The independent `milestone_bench` harness measured the same program in the same
session at **0.92×** of idiomatic Rust. Two harnesses, two 25-run passes, one
direction: **0.89–0.92×.** The A/A floor for this program is **1.001×**, which is
tighter than g1's known 1.098× layout sensitivity, so the margin is not the host.

**Hand-tuned Rust is 1.45× faster than Prismio** and that is the honest headline
of this file as much as the paragraph above it. A thread pool does not pay
`pthread_create` per frame and Prismio has no way to express one — there is no
pool, and `spawn` is one thread per task. Closing that is a language question,
not a codegen one.

### 2.1 The mechanism, and it is not a wash

Prismio makes **0.13×** the allocations of idiomatic Rust. `std::thread::spawn`
requires a `'static` closure and therefore boxes what it captures, every frame,
per thread. Prismio proves the join happens before the scope exits
(INFERENCE 4.1's E-SPAWN-J), so the spawn argument stays in the parent frame:
the manifest reads **T0 / stack / Transferred** for all four bands and the spawn
allocates nothing for them at all.

That is structured concurrency being worth something measurable rather than being
a slogan, and it is the first place in this project where an AIF fact converts
directly into beating Rust rather than into catching up with it.

## 3 · What the program found immediately

Its first `--verify` run reported **80 leaked of 107**. Two distinct defects, and
neither had a reproduction before this program existed, because **no corpus
program spawned anything** and no test spawned in a loop.

## 4 · Defect 1 — the task handle had no owner. Fixed.

`prismio_task_release` has existed in `program_support.c` since tasks did, and
**codegen never emitted it.** Every `spawn` leaked one handle for the life of the
process. Nothing caught it: the handle is plain `calloc` — correctly, since
C_CODE_STYLE requires exactly that of a temporary the runtime frees itself — so
`--verify` never sees it. `allocount` does, and read **8,201 allocations against
23 frees**.

**Released at the scope exit, not at the join.** A handle is copyable and nothing
stops a program joining twice; the runtime guards the second *wait* but could not
guard a read of freed memory. A scope exit runs once however many joins there
were, and after all of them.

The premise is AIF's rather than a new one: the drop is emitted only where
E-SPAWN-J already proved the task is joined on every path before the scope exits,
so the thread has finished and nothing will write the handle again. Anything not
proved keeps the old behaviour and still leaks — the conservative direction,
because freeing a handle a live task still writes its result into is the failure
this must not have.

| | before | after |
|---|---:|---:|
| allocations / frees | 8,201 / **23** | 8,201 / **8,019** |
| peak RSS | 2.1 MB | **1.5 MB** |
| RSS vs idiomatic Rust | 1.17× | **0.83×** |
| loop time | 1.000× | **1.002×** (flat) |

`run_task_release_test` asserts three facts on the emitted IR, and all three are
needed — the first alone would pass against a compiler that released *every*
handle, which is a use-after-free on the other two:

- `many_frames` — proved joined, never copied → one release per spawn;
- `copied_handle` — `let u = t` aliases the handle → **no** release;
- `join_inside_a_loop` — a `while` may run zero times, so the join is not proved
  → **no** release.

It was run against the pre-fix compiler and fails there
(`many_frames__Void emitted 0 release(s), expected 2`), so it is not vacuous.

## 5 · Defect 2 — a callee-allocated argument still leaks, and it is not about spawn. Open.

**This section originally read "a callee-allocated *spawn* argument".** That was
wrong, and the correction is worth more than the original claim: the same program
with the `spawn`/`join` removed and the calls made directly leaks **identically —
107 allocated, 27 released, 80 leaked, either way.** `spawn` was simply the first
thing that happened to be looking at it.

What actually decides it is one `let`. `aif_owns_call_result_at_node` is asked at
a **binding**; a result consumed straight as an argument is never bound, so
nothing asks and nothing drops:

| | allocated | released | leaked |
|---|---:|---:|---:|
| `let b0 = band(...)` then `simulate(b0)` | 27 | 27 | **0** |
| `simulate(band(...))` | 107 | 27 | **80** |

An automatic region normally hides the whole question by reclaiming the value in
bulk. `prismio aif --why` says exactly when it cannot, and names the repair:

```
    bracketing -- may a caller's region reach this function?
      callers  0 of 4 call sites lie inside a region -- so no arena would serve it either way
    repairs, cheapest first
      1. have the caller allocate and pass it in     restores T1, no runtime cost
```

That repair is precisely the difference between `g9_bands.psm` and
`g9_helper_leak.psm`. The compiler diagnosed this correctly the whole time; what
was missing was somebody asking it.

Reproductions: `tests/owned_temporary_argument.psm` (the discriminator, one `let`
apart) and `aif/evidence/xlang/prismio/g9_helper_leak.psm`.

Not fixed, and deliberately not papered over.

The value is built **in a callee** and returned, so `aif_con_return` puts its
escape at Caller and it lands **T2 / owned**. `g9_bands.psm` avoids it by building
the band at the spawn site — its ledger is **1 allocated, 1 released, 0 leaked,
0 violations** — and the source says so, because the difference between the two
forms is not visible in the code and is worth 80 allocations.

`tests/test_69_task_results.psm` leaks **4 of 4** for a related but distinct
reason: there the spawn's join is genuinely not provable (inside an `if`
condition, or reached through a copied handle), so E-SPAWN-J never fires and the
argument is heap-placed rather than T0/stack. That one *is* about spawn.

**The fix needs a guard, not just a drop.** Releasing every owned temporary
argument is a use-after-free wherever the callee retains it — `list_push` is the
obvious case, and its FFI contract already answers `RETAIN_IN_BASE`. A Prismio
callee needs the same question answered from the escape facts before any drop is
emitted. Recorded in TODO.

## 6 · Gates

- fixed point: `build/tr_a.ll == build/tr_b.ll`;
- suite **172/172** — two new checks, §4's and the fixture it asserts on;
- AIF differential **18/18** in both modes, the new source being `g9_bands.psm`;
- source lists agree; `git diff --check` clean;
- corpus gate with 7 programs: median **1.000×**, range 0.993–1.084×, passed;
- task-release gate: median **1.001×**, range 0.977–1.089×, passed, with g9 RSS
  at **0.708×** and its loop flat at 1.002×;
- g9 A/A calibration: **1.001×**;
- all corpus checksums agree across every variant.
