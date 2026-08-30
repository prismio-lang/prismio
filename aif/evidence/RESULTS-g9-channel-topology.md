# The remaining tuned-g9 gap is not the channel topology

**Status: NEGATIVE RESULT, 2026-08-30.** Compiler `build/ums-gen3`, LLVM 22.1.8
on Apple Silicon. No compiler or runtime change is proposed. This exists so the
next session does not build an SPSC ring on a premise that does not hold.

## What the handoff expected

`PERFORMANCE_HANDOFF.md` Gap 4 lists "General MPMC channel used for statically
SPSC endpoints" at P1, with the rationale that it "explains most remaining tuned
g9 gap", and a first slice that specialises g9's job channels to a bounded SPSC
ring.

The topology claim itself is **correct**. In `g9_tuned.psm`, `j0`..`j3` are each
created by `chan_new(2)`, `chan_share`d exactly once into one `spawn worker(...)`,
and sent to only from `main` — one producer, one consumer, and the property is
syntactically checkable. `results` is `chan_share`d four times and is genuinely
MPSC.

What does not hold is that this explains the gap.

## The measurement

`frames = 2000`, `steps = 24000`, four persistent workers.

| arm | per frame |
|---|---:|
| Prismio tuned | 40.7 us |
| Rust tuned | 36.0 us |
| **gap** | **4.7 us** |

The serial dependency chain in `simulate` is 24000 iterations of a multiply,
shift, mask and two adds — roughly 27 us on this host — so both languages are
spending most of a frame on arithmetic, and the gap is the machinery around it.

## Two hypotheses, both refuted

**Condvar wake-up latency.** Every frame costs at least eight futex round-trips
on the critical path: four workers wake to take a job, `main` wakes four times to
take a result. A bounded spin before blocking is the standard fix, and it is much
cheaper to test than a topology analysis. Added to both `chan_send` and
`chan_recv` (2000 iterations, acquire loads paired with release stores on `len`):

```text
g9_tuned  mutex-only 0.0404 ms/frame   with-spin 0.0402 ms/frame   0.995x
```

Nothing. In hindsight the reason is visible in the numbers above: `main`'s
receive blocks for about 27 us waiting for arithmetic, which no spin length
worth having will cover, and a worker's next job is usually already queued
because the channel holds two.

**Heap-object messages.** `--verify` counts **18013 allocations over 2000
frames** — nine per frame, which is four `Band`, four `Tally` and one. A
malloc/free pair costs on the order of 50-100 ns here, so eight pairs is under
1 us of the 4.7 us.

## Why the proposed slice cannot close it either

An SPSC ring replaces an **uncontended** mutex on this workload — four separate
job channels, one producer and one consumer each, so there is nothing to contend
for. An uncontended `pthread_mutex` lock/unlock pair is tens of nanoseconds; at
eight channel operations per frame the whole mutex cost is a few hundred
nanoseconds. That is the ceiling on what the specialisation can win, and it is
roughly a tenth of the gap.

The arithmetic is not the problem either: Prismio's `simulate` is unrolled four
ways by LLVM and is the same shape as Rust's.

## What this leaves

The 4.7 us is unattributed, and saying so is the point of this file. Candidates
not yet tested, in the order worth trying:

1. **The `results` channel.** It is the one genuinely contended endpoint — four
   producers, one consumer, capacity 8 — and it is the one the handoff's first
   slice explicitly leaves alone.
2. **Thread scheduling and migration.** Four workers plus `main` on a host whose
   core types differ; Rust's tuned arm may be landing its threads differently.
3. **The per-frame `clock_gettime_nsec_np` pair**, which is inside the measured
   region in both languages but not necessarily the same cost in both.

Until one of those is measured, **Gap 4 should not be treated as a P1
performance item.** The endpoint classification may still be worth having for
other reasons — `Channel<Int>` is rejected today because channels use optional
references for closure signalling, and that is a real language limitation — but
it should be justified as a feature, not as this gap's fix.
