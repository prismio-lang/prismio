# Memory: what 0.1 needs, and where the architecture goes after

The live plan for ownership, allocation and memory representation. It replaces
`MEMORY_ALLOCATION_DEEP_DIVE.md` (the MEM-001..022 tracker, 2026-09-04) and the
memory half of `MEMORY_OPTIMIZATION_AGENT_SPEC.md` (2026-09-05). Both are in
`git log` (`git show 1e338c0:MEMORY_ALLOCATION_DEEP_DIVE.md`). The performance
levers from the same documents, and the ones that are closed, are in
[PERFORMANCE_PLAN.md](PERFORMANCE_PLAN.md). What is open
today, shape by shape, is in `KNOWN_ISSUES.md` under "Ownership". This file
decides what to do about it.

Status checked against the tree on 2026-09-25.

## 1 · For 0.1: no known way to corrupt memory in a program that compiles

A leak is acceptable in 0.1 if it is documented. A **violation** is not: freeing
something that is not live, reading a dead frame, or getting a wrong answer.
`--verify` separates the two ("leaked" against "violations"), and so does this
list.

- [ ] **A recursive enum built from `let`-bound children double-frees.**
      `let left = build(d - 1); let right = build(d - 1); return Expr.Op(d, left,
      right)` gives `free(): double free detected` without `--verify` and a
      segfault with it. Reproduced on 2026-09-25. The inline spelling,
      `Expr.Op(d, build(d - 1), build(d - 1))`, is now clean: 128/128/0 at depth
      6, where KNOWN_ISSUES still says it leaks. This is the natural way to write
      a tree builder, so it is the first blocker.
- [ ] **An unsized array stored through a type argument points into a dead
      frame.** `Box<[Int]>`, `Option<[Int]>`, `Vec<[Int]>` built from a local
      array and returned (KNOWN_ISSUES, "An unsized array reached through a type
      argument"). A `[T]` field is already refused for exactly this reason. The
      0.1 fix is to refuse the type argument the same way, which is smaller than
      making it sound.
- [ ] **Every violation shape found before the tag is either fixed or refused.**
      A new one found during release testing blocks the tag the same way.
- [x] Three ownership shapes that freed a literal, or freed a payload twice
      (`RESULTS-ownership-shapes.md`, 2026-09-25).
- [x] A C-produced value placed in an arena that could not serve it
      (`RESULTS-std-stdin.md`, 2026-09-25).

The leaks KNOWN_ISSUES lists are not 0.1 blockers. The release notes should say
that leaks exist and name the common shapes: a Map's keys copied into a returned
Vec, a list that hands out an element, and a replaced struct field.

## 2 · Later

### 2.1 · Observability first

**MEM-001, allocation telemetry: partial.** `--verify` prints a count ledger,
allocated, released and peak live bytes, a size histogram, and arena objects.
Not done: allocation-site identity in the ledger, and a machine-readable report
that `benchmarks/run.py` can collect. Every item after this one needs it to
pick a target, which is why it comes first.

**MEM-017, compiler phase time and RSS: open.** Nothing reports per-pass time or
memory. Compile time is still measured by timing a whole build.

### 2.2 · Correctness of the runtime model

**MEM-002, thread-local arena state: done.** The arena and its hint move to
thread-local state once `spawn` is used, and single-threaded programs keep the
process-local fast path (`lang_runtime.c`, "Keep the original process-local
fast path until `spawn` is used"). The cycle collector's candidate state is
still process-global behind a lock.

**MEM-015, RC and cycle hardening: open.** `cyc_mark_grey`, `cyc_scan` and
`cyc_collect_white` still recurse, so a deep cyclic structure can overflow the
C stack. The generated release was made iterative (MEM-029, landed) and the
collector was not. First slice: explicit worklists, with the same policy.

### 2.3 · Middle IR and interprocedural facts

These are what the deep dive called the architectural limit. Prismio lowers the
post-sema AST straight to LLVM, and AIF's facts sit in side tables, so moves,
borrows, lifetime ends and return provenance are gone before anything could
optimise with them.

| ID | Item | State |
|---|---|---|
| MEM-004 | Ownership-aware Memory MIR between sema and LLVM: SSA values with explicit `move`, `borrow`, `end_borrow`, `drop`, region enter and exit, and allocation-site identity | not started. There is no MIR. |
| MEM-005 | Per-function effect summaries: parameter borrow, consume or capture, return fresh or alias, extern contracts | partial. AIF has the pieces as separate queries (`fn_ret_partial`, `fn_may_return_view_of_param`, `aifFfiArenaCannotServe`), not as one summary a caller consumes |
| MEM-007 | Destination passing and reuse beyond same-type constructors | the narrow form shipped (`RESULTS-M2-reuse-token.md`). The general one has not. |
| MEM-008 | `llvm.lifetime.start/end` on stack objects; scalar replacement of identity-free structs | not started. The backend emits no lifetime markers. |
| MEM-009 | Caller-provided result slots for fresh struct returns | not started for structs. Arrays already return by value. |
| MEM-012 | Explicit caller-provided region handles instead of the ambient arena | not started |
| MEM-013 | Arena peak control; capacity inferred for list literals and counted loops | not started |

**The order the deep dive argued for still holds.** Build telemetry (MEM-001),
then effect summaries (MEM-005), designed as the first slice of the MIR rather
than one more AST-only flag, then the MIR itself. A MIR is a large change to
`src/`. It lands behind a flag, one function subset at a time, and must give
byte-identical output for everything it does not yet cover.

### 2.4 · Representation

- **MEM-026, a payload enum is a tagged product, not a union.** Every variant
  gets its own fields. That is forced, because overlapping variants needs the
  size of the widest one, and a type's size is REQUIREMENTS 18, still open.
  `src/sema/enums.psm`'s header says where the overlap goes when 18 lands.
- **MEM-027, every struct is passed by pointer.** Small value structs take a
  stack slot they would not need under a register ABI.
- **MEM-018, niches beyond NPO.** Enum NPO shipped for boxed recursive binary
  enums (`RESULTS-enum-null.md`). A general niche calculator did not.
- **MEM-010's FFI half, a borrowed `{ptr, len}` string view at extern
  boundaries.** The container slot half shipped as German strings.
- **MEM-016, typed task frames.** A task takes at most three arguments of one
  machine word each (`prismio_task_spawn`). Captures beyond that, and a worker
  pool, are CHANNELS_PLAN §9.

### 2.5 · Only if telemetry asks for them

Each of these has an entry condition in the deep dive, and none is met: a
per-thread slab for a dominant size class (MEM-020), an immutable shared buffer
(MEM-021), 32-bit arena-relative pointers (MEM-022), and prefetching. **A
general allocator replacement is measured and rejected**: mimalloc at 1.021x
time and 1.242x RSS, rpmalloc at 1.003x and 1.627x.

## 3 · What the deep dive established that still holds

- **The dominant allocation cost was a representation decision, not
  `malloc`.** Splitting a struct into hot and cold records made it ineligible for
  inline list storage, which meant two allocations per element. That is fixed
  (MEM-003, `aifLayoutVetoListElements`), and the lesson generalises: price the
  container a layout ends up in, not the record in isolation.
- **Region and reuse work pays off.** Tree rebuild beat C++. Generalise it
  without regressing that.
- **LLVM stays the optimiser.** The job is to hand it facts: noalias, lifetime,
  dereferenceable, and a contiguous view. Replacing LLVM is not the job.
