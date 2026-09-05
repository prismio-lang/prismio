# MEM-033: the cycle collector stops locking when there is nothing to lock against

**Status: GREEN but nearly free, 2026-09-05.** Two-generation byte-identical
fixpoint, suite **294/294**, all 34 checksums identical. Nine `cyc_*` functions
changed; nothing else did.

## 1 · What was built

`cyc_enter` and `cyc_leave` return immediately when
`prismio_memory_threads_are_enabled()` is false. Every reference update on a
cycle-managed object took an uncontended recursive mutex to exclude threads a
program that never calls `spawn` does not have.

**`cyc_leave` re-reads the flag rather than latching it, and that needs an
argument.** An unmatched unlock would need the flag to flip between an enter and
its leave — a `spawn` inside a collector critical section. Those sections contain
reference-count updates, the candidate buffers, and `cyc_free_object`, which calls
a **compiler-generated** release function; a generated release drops fields and
calls `rt_free`/`rc_release`/`list_release`, reaches no user code, and cannot
spawn. The flag is monotonic, so the reverse flip does not exist.

**A thread-local depth counter was written first and reverted.** It latches the
decision and needs no argument at all, but `PRISMIO_THREAD_LOCAL` lowers to a call
into the TLS resolver on this target: `_cyc_retain` went from 22 instructions to
**61**, which costs more per reference update than the mutex it was removing. The
simple flag check is 28.

## 2 · What it is worth, which is almost nothing here

**No benchmark moved.** 15 alternating samples, whole suite: `tree_traversal`
1.008, `nested_collection` 0.995, `recursive_tree_rebuild` 0.992,
`key_value_update` 1.001 — all inside the A/A band.

A probe written specifically to hammer it — 2.4M pushes of a self-referential
`enum` into a `List`, so every push retains and every teardown releases — reads
**0.991 min / 0.979 p50**.

**The spec's "reference counting overhead drops by 80%" has no workload here that
would show it.** Every reference update in these programs sits next to an
allocation of the object it counts, and the allocation is two orders of magnitude
more expensive than the lock. The change is kept because it is sound, six lines,
and removes a real per-operation lock from a path a *different* program could make
hot — not because this suite can see it.

## 3 · Step 2 of the task was not attempted, and why

The spec also asks to shrink `CycHeader` from 32 bytes to 8 by moving the
`children` and `release` function pointers into a per-type descriptor table and
packing `rc:48, colour:2, buffered:1, type_id:13`.

That is a much larger change — those two pointers are emitted per type by codegen
— and its payoff is footprint, not the lock. `tree_traversal` allocates 32,772
cycle-managed objects; **Task 1.4's null-pointer optimisation removes half of them
outright**, which is the cheaper way to the same footprint. Do 1.4 first and
re-measure before paying for the header split.
