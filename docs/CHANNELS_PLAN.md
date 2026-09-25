# Channels: what 0.1 needs, and the production design after it

The plan for `Channel<T>` and the task runtime under it. It is the text of
`CHANNEL_PIPELINE_PRODUCTION_PLAN.docx` (2026-09-09, status "Proposed"), which
was in both the root and `docs/`. It is converted here so it can be diffed and
reviewed like everything else, and re-audited against the tree on 2026-09-25.
The `.docx` is in `git log` (`1e338c0`).

What a program can call today is RUNTIME.md §4.1: `chan_new`, `chan_send`,
`chan_recv`, `chan_share`, `chan_close`, `chan_len`, `chan_free`, over a
`Channel<T>` type the compiler builds in.

## 1 · For 0.1

The design below is too big for 0.1, and nothing in it is needed for the
channel 0.1 already has to be correct. What is needed:

- [x] **Refuse `Channel<Int>` and every other non-reference element type, as
      RUNTIME.md already says it does.** It is accepted today. `chan_send(c, 5)`
      is emitted as `call i32 @chan_send(ptr, i32 5)` against a C function that
      takes `void*`, and `chan_recv`'s `ptr` goes straight to `println__Int`. It
      printed the right number on x86-64 by luck, because the upper half of the
      register happened to be zero (probe, 2026-09-25). The comment on
      `typeChannel` (`src/ast/types.psm`) says sema refuses it. Nothing does.
      Add the refusal, with a negative test, and point the message at a
      one-field struct.
- [x] **A task that cannot start must not run inline.** `prismio_task_spawn`
      runs the task on the calling thread when `pthread_create` fails. Its
      comment argues that this is observationally equivalent because a task
      shares nothing with its parent. A channel breaks that argument: a
      producer run inline blocks on a full channel whose consumer has not been
      spawned yet, and the program deadlocks. Fail loudly instead: a panic with
      the reason, exit 101, as `panic` does.
- [x] **Say precisely what a send after close does.** `chan_send` returns 0 and
      the message is neither delivered nor freed. That is a leak, and RUNTIME.md
      calls it "dropped". Correct the doc for 0.1. Returning the value is Phase 0
      below.
- [x] Destruction order (close, join every sharer, free) is documented in
      RUNTIME.md rule 4 and followed by every program in the corpus. The
      runtime cannot check it. Phase 1's endpoint counts are the fix, and they
      are not a 0.1 item.

## 2 · Where it stands

**The plan's case, 2026-09-09, on Apple Silicon.** `channel_pipeline` moved
40,000 integers through a bounded pipeline, and the medians of 15 runs were
Prismio 4.79 ms, C++ 2.90 ms and Rust 2.17 ms. A controlled C++ probe put the
difference on the representation: about 2.64 ms with the payload in the ring,
about 5.3 ms with a heap message per send. Prismio boxes each message, because a
channel carries only pointer-shaped values, which was 40,003 allocations and
releases per run.

**Re-measured 2026-09-25 on x86_64 Linux, 4 cores:** Prismio 135.2 ms, C++
151.6 ms, Rust 122.2 ms (`RESULTS-benchmarks-2026-09-25.md`). At this
benchmark's current scale and on this machine, the handoff between threads
dominates and Prismio is not behind. The box per message is still there, and
it is still the reason for Phase 1. But Phase 1 is now justified by the ABI
(§1's first item) and by allocation counts, not by a benchmark gap. Re-measure
on the machine the original number came from before quoting a speedup.

The runtime (`runtime/program_support.c`) is a mutex and two condition
variables over a `void*` ring, with `%` to wrap. Task start is one OS thread per
`spawn`, with at most three word-sized arguments.

Topology specialisation, meaning an SPSC ring when one producer and one
consumer are proved, was tried and is a **negative result**
(`aif/evidence/RESULTS-g9-channel-topology.md`). The cost is the box, not the
lock.

### Correctness findings from the plan, re-checked

| Pri | Finding | 2026-09-25 |
|---|---|---|
| P0 | `Channel<Int>` passes checking and produces bad IR | **still open**, worse than written: it builds and runs, with an ABI mismatch. 0.1 item. |
| P0 | Send after close consumes the value and neither returns nor frees it | **still open.** A leak, documented for 0.1 |
| P0 | A failed `pthread_create` runs the task inline, so a bounded producer can deadlock | **still open.** 0.1 item |
| P0 | `chan_share` returns the same pointer, and `chan_free` assumes no waiters | **still open, by contract** (RUNTIME.md rule 4). Phase 1 |
| P1 | Allocation failure looks like an empty or closed receive; capacity 0 is clamped to 1 | still open. Phase 1 and 2 |
| P1 | Threaded runs bypass the small-object recycler | not re-checked. Moot once messages stop being boxed |

## 3 · Design

**A typed, bounded MPMC channel with the payload in the ring.** A mutex
protects a ring of in-place slots. A value moves from the sender's storage into
a waiting receiver, or into a slot and out again. There is no heap box per
message. The lock stays: it is simple enough to prove, and lock-free
queues are a later optimisation, adopted only if profiles show contention.

```text
Sender<T> -> move from source -> waiting receiver, or typed ring slot -> move into destination -> Receiver<T>
```

| Component | Responsibility | Storage | Failure |
|---|---|---|---|
| Channel core | capacity, ring, close state, waiter queues, endpoint counts | one allocation plus the payload buffer | construction reports out-of-memory; close wakes everyone |
| Type descriptor | size, alignment, move in, move out, drop in place | one static descriptor per concrete `T`, emitted by the compiler | an invalid descriptor is an invariant violation |
| `Sender<T>` | holds the core; counts toward sender close | small handle | the last sender's close disconnects receivers once the buffer drains |
| `Receiver<T>` | holds the core; counts toward receiver close | small handle | the last receiver's close fails later sends with the value |
| Parker | park and wake a waiter | per platform, later per scheduler | timeout and cancellation remove the waiter |

**Runtime ABI:**

```text
PrismioTypeDescriptor { size, alignment, move_into, move_out, drop_in_place }
prismio_channel_new(capacity, descriptor) -> ChannelCore or an init error
prismio_channel_send_move(sender, source) -> SendStatus
prismio_channel_recv_move(receiver, destination) -> RecvStatus
```

A receive returns a status and writes to a destination the caller supplies,
instead of returning a nullable pointer. That is what lets one ABI carry
scalars, references and zero-sized types without mistaking a valid null for a
closed channel.

### Message lifecycle

1. A sender checks close and disconnect under the lock.
2. A receiver already waiting gets the value directly, and the ring is
   bypassed.
3. Otherwise, if there is room, the value moves into the tail slot, the tail
   advances (masked for a power-of-two capacity, a conditional increment
   otherwise, never `%`), and one receiver is woken.
4. When the channel is full, a blocking send waits. A try-send returns `Full`
   with the value untouched. A timed or cancelled send gets its value back.
5. A receive takes a buffered value first, then a waiting sender's value. With
   no senders left and nothing buffered, it answers `Disconnected`.
6. The last sender's close lets the buffer drain, then disconnects. The last
   receiver's close fails every blocked and later send with its original
   value.

A user-supplied drop never runs under the channel's lock. An abandoned value is
moved out, the lock is released, and then the value is dropped.

### Public API, by phase

| Capability | Surface | Contract | Phase |
|---|---|---|---|
| Create | `Channel<T>.bounded(capacity)` | capacity > 0; allocation failure is an error | 1 |
| Blocking send | `sender.send(value)` | `Ok`, or `SendError<T>` holding the value | 1 |
| Blocking receive | `receiver.recv()` | `Ok(T)` or `Disconnected` | 1 |
| Rendezvous | `Channel<T>.rendezvous()` | capacity 0: a send completes only when paired with a receive | 2 |
| Non-blocking | `trySend`, `tryRecv` | `Full`, `Empty` and `Disconnected` are distinct | 2 |
| Timed, cancellable | `sendUntil`, `recvUntil` | no lost value, no orphaned waiter | 2 |
| One-shot | a single stored result | a task's result or completion | 2 |
| Select | receive and send arms | exactly one arm commits | 3 |
| Reservation | `reserve` and a permit | a slot is reserved before the value is produced | 3 |
| Batch | `sendMany`, `recvMany` | partial outcomes are explicit | 4 |

**Sharing rules the language has to settle first.** A value that crosses a task
must be sendable, meaning the compiler refuses one that is not. An endpoint
used from two tasks must be safe for that. And the language decides whether a
mutable reference is moved, copied or refused. The channel cannot repair an
unsound aliasing rule after the fact.

## 4 · Phases

| Phase | Deliverable | Exit criterion |
|---|---|---|
| 0 · Contract | written semantics (ownership, close, endpoint clones, error types, blocking); `Channel<Int>` refused or lowered properly; spawn failure explicit; send after close returns the value; teardown tests with live waiters | the compiler's tests pass; a leak probe on send after close passes; every failure has a result type |
| 1 · Typed bounded channel | type descriptors, an aligned in-place ring, `Sender`/`Receiver` with counted endpoints, direct handoff, a wrap without division | the primitive pipeline makes no allocation per message; `channel_pipeline` near the inline C++ control; the state machine's tests pass |
| 2 · Complete blocking API | rendezvous, try, timeouts, cancellation, one-shot, per-platform parkers (futex, `WaitOnAddress`, `os_sync_wait_on_address`) | no lost value or orphaned waiter under stress; deterministic timeouts in tests |
| 3 · Runtime integration | structured task scopes, a bounded worker pool, park and unpark through the scheduler, select, permits | a blocked channel does not pin a worker; select commits exactly one arm |
| 4 · Specialisation | SPSC and MPSC fast paths, batches, an atomic MPMC ring (Vyukov; SCQ/wCQ), broadcast, watch, unbounded with a memory policy | each justified by a benchmark and a correctness case. Remember the SPSC negative result |

The **0.1 items in §1 are the part of Phase 0 that a program can hit today.**
The rest of Phase 0 starts after 0.1.

**The task runtime.** Today it is one OS thread per `spawn`. In transition, a
worker pool that compensates for blocked workers, and never runs a failed spawn
inline. The target is a work-stealing scheduler with structured scopes, where
tasks park through the Parker and a scope owns its tasks, their cancellation,
their joins and their endpoint shutdown.

## 5 · Alternatives considered and set aside

- **A better allocator under the pointer channel.** It fixes neither the
  primitive ABI nor ownership, and the cost is the box, not the allocator.
- **Boxing the C++ and Rust arms' values.** That hides the cost instead of
  removing it.
- **Lock-free MPMC first.** Harder to verify, and it leaves the close and
  ownership defects where they are.
- **Unbounded first.** No backpressure, and a memory failure mode with no
  policy.
- **A bigger capacity.** The 40,000 boxes and the `%` stay.
- **A concurrent recycler.** It needs a proven reclamation model first.

## 6 · Acceptance, before calling channels production-ready

- **Language:** every payload form follows one ABI and one type rule.
- **Ownership:** exactly-once drop, proved by a counted test type across
  success, failed send, shutdown, timeout, cancellation and destruction.
- **Concurrency:** close, timeout, cancellation, clone and teardown pass under
  stress and ThreadSanitizer. Model-check the lock-based state machine
  (loom-style) before any lock-free work.
- **Performance:** no heap allocation per message for a primitive payload, and
  no division in the ring's hot path. The benchmark contract covers SPSC, MPSC
  and MPMC; capacities 0, 1, 8, 64 and 1024; small and non-trivial payloads;
  p50, p95 and p99 latency; and scaling to every core.
- **Behaviour:** bounded, rendezvous, try, timed and disconnected are distinct
  and documented.

## 7 · Decisions still needed

- Are payloads movable by default, or must the element type declare that it
  can be sent?
- What are the cancellation token and deadline model? They shape the parker,
  select and scopes.
- Which Apple deployment targets are supported? That decides whether
  `os_sync_wait_on_address` can be the default parker.
- May a receiver be cloned? If so, document how work is distributed. If not,
  enforce it in the types.
- What performance gate is committed? The inline control was about 2.64 ms on
  the machine that measured it, and the gate needs a tolerance.

## References

Go's `runtime/chan.go` and `select.go`, and the Go memory model; Rust's
`std::sync::mpsc`; crossbeam-channel; Tokio's bounded mpsc, permits and
runtime; Vyukov's bounded MPMC queue; the SCQ paper; Linux futex2 and
`futex_waitv`; Windows `WaitOnAddress`/`WakeByAddressSingle`; Apple's
`os_sync_wait_on_address`; loom; ThreadSanitizer; Java structured concurrency.
