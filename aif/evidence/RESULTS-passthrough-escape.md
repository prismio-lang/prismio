# A binding that escapes through a callee's return was freed under its caller

**Status: GREEN, 2026-08-29.** This is not a leak. It is a **use-after-free**
that the tree did not record, found while trying to widen the same drop path for
TODO's *"an owned call result passed straight into another call has no owner"*.
It segfaults, and `--verify` reports `0 violation(s)` while it does.

Fixed compiler `build/pt-6`. Suite **173/173**, fixed point, AIF differential
**18/18**, `check_source_lists` agree, `git diff --check` clean. Emitted IR is
**byte-identical on 127 of 128** programs in `tests/`, `aif/corpus/` and
`aif/evidence/xlang/prismio/` — the 128th is the new discriminator.

---

## 1 · The defect

`aif_owns_call_result_at_node` says the caller owns what a known callee
allocated and handed over, and `src/ir/stmt.psm` turns that into a scope-exit
drop. The escape lattice cannot supply the guard: a value allocated in a callee
is already at `Caller`, so `return` raises nothing and E stays silent. That is
why `src/ir/expr.psm` carries a *syntactic* guard, `nodeReturnsName`, instead.

`nodeReturnsName` sees `return t`. It does not see the same allocation leaving
through somebody else's return:

```prismio
fn passthru(b: Band) -> Band { return b }

fn escaping() -> Band {
    let t = band(1)          // owned call result -> droppable
    let x = passthru(t)      // x aliases t's allocation
    return x                 // the allocation outlives this frame
}
```

The drop still fires at `escaping`'s scope exit, so the caller reads freed
memory. Measured against `build/nostr-4`:

| | inside `escaping` | in `main` | ledger |
|---|---:|---:|---|
| `band(1).seed`, correct value 7919 | 7919 | **0**, then **6** | `3 allocated, 3 released, 0 leaked, 0 violation(s)` |

With an allocation placed between the return and the read, so the freed block is
actually reused, it is not a wrong number but a **SIGSEGV** (exit 139). That is
`tests/test_85_passthrough_escape.psm`, which is a discriminator rather than a
description: it was **observed crashing** against `build/nostr-4` before the fix
existed.

**Why `--verify` is silent.** The ledger pairs allocations with releases. Here
every allocation is released exactly once — the release is simply in the wrong
frame. A read after free is not a double free, so `violations` stays 0. This is
worth carrying forward: `violations` is the number that means corruption, but it
does not mean *all* corruption.

## 2 · Which escape routes were already guarded, and which was not

Established by probe rather than by reading, because the recorded notes did not
distinguish them:

| route out of the frame | guarded before? | by what |
|---|---|---|
| `return t` | yes | `nodeReturnsName` (syntactic) |
| into a container — `list_push(l, t)` | yes | `retain_in` raises `in_container` on the site |
| into a released field | yes | `site_in_released_field` |
| a callee **retains** a by-value parameter | yes | sema: *"cannot move out of borrowed value"* |
| **through a callee's return value** | **no** | — this defect |

The fourth row is worth stating because it removes a guard this work was told to
build. TODO says a Prismio callee needs the `RETAIN_IN_BASE` question answered
from the escape facts before any drop is emitted. It does not: the language
already refuses it. Parameters are borrows, and moving one into a container is a
compile error, so the retention half of the guard is the type system's and not
the analysis's.

## 3 · The fix

Two pieces, and the second one is where the precision is.

**`aif_fn_may_return_param(symbol)`** in `runtime/aif_support.c` — whether a
function may hand one of its own parameters back through its return value. Read
off the converged points-to sets (`pt[RET(f)] ∩ pt[PARAM(f, i)]`) rather than
recorded separately, for the same reason `fn_returns_partial` is: the edges are
already there and a second record is a second thing to keep in step.

This is Swift's parameter-convention question asked in the direction the drop
path needs it — an `@guaranteed` parameter leaves the caller owning the argument
across the call, a parameter passed through to the result does not — and
Perceus's "borrowed vs owned" parameter inference. Sources in §6.

**`nodeEscapesThroughCall`** in `src/ir/expr.psm`, beside `nodeReturnsName`, and
**driven from the `return` rather than from the argument.** The cheaper question
— "is `t` ever passed to a callee that may hand a parameter back" — is the wrong
one, and the suite said so: it declines `let same = identity(items)` in
`test_47_aif_containers`, where the alias never leaves the frame and `items` is
this scope's to drop. Asking instead which values *reach a `return`* keeps that
drop and still refuses the one above.

### Two things that were measured, not reasoned

**An unknown symbol answers *no*, not yes.** "Unknown" here means *extern*, not
*unanalysed*: an extern's result is the frontend's contract question, and
`alias` is the one contract that hands an argument back. Answering yes was
built and measured — it declines the drop at every `print(value)` in
`std/io.psm`, because `prismio_rt_print(text)` is an extern declared `borrow`,
and it took three suite fixtures with it (`split_release`, `forced_layout`,
`aif_verify`) by leaking one String per integer printed. **170/173.**

**Site granularity is inherited, not introduced.** One site serves every call of
the allocating function, so two allocations from one `Band { ... }` literal are
one bit. A false positive therefore costs a leak and never a free — the same
asymmetry `in_container` already runs on.

## 4 · Before / after

```
tests/test_85_passthrough_escape.psm
  build/nostr-4   exit 139 (SIGSEGV)
  build/pt-6      PASS: passthrough escape        exit 0
```

Under `--verify` the new compiler reports `14 allocated, 12 released, 2 leaked,
0 violation(s)`. **The two leaks are the fix working**: the values genuinely
outlive the frame, and the caller cannot own them because ownership does not
survive a second return — which is TODO's next open item, and the reason this
number is 2 rather than 0.

| gate | result |
|---|---|
| fixpoint (`pt-5` vs `pt-6` on `src/main.psm`) | identical |
| suite | **173/173** |
| AIF differential | **18/18** |
| `check_source_lists.py` | agree |
| `git diff --check` | clean |
| emitted IR, 128 programs | **127 byte-identical**; only the new discriminator moved |
| executable size, 7 corpus programs | **byte-identical, all seven** |

**Corpus, 25 runs, checksums enforced:** median `new/old` **1.000×**, range
0.792–1.072× — noise, and provably so: the IR is the same bytes. RSS
0.992–1.027×.

**Compile time**, the only thing that *could* have moved, because the guard adds
two AST walks per candidate binding: `src/main.psm` best-of-7 is **418 ms → 417
ms**. Flat.

**Standing against idiomatic Rust is unmoved**, as it must be with identical IR:
g9 **0.91–0.92×** (RSS 0.83×, allocations 0.13×), g6 2.73×, g4 widest.
`aif/evidence/xlang/results-passthrough-escape.json`.

## 5 · What is still open

**The extern half of this hazard is exactly as wide as it was.**
`let t = f(); let x = <extern declared alias>(t); return x` still frees `t` at
the scope exit. Closing it is a frontend change — `aifFfiAliasOf` in
`src/aif/contracts.psm` is where the answer lives, and it is a hardcoded table
whose only entry is `expect`. Recorded in `TODO.md`, not closed here, and the
comment on `aif_fn_may_return_param` says so at the seam rather than only here.

**This is a prerequisite, not the item it was found under.** TODO's *"an owned
call result passed straight into another call has no owner"* asks for the same
drop to be emitted for a value that is never bound. Doing that before this fix
would have widened a path whose guard was already incomplete, and the failure
would have been a temporary freed *immediately* after the call rather than at
the scope exit — sooner, and inside the expression that still reads it.

## 6 · Sources

- [Perceus: Garbage Free Reference Counting with Reuse](https://xnning.github.io/papers/perceus.pdf) — borrow inference, and the rule that a drop is generated as soon as possible after a binding.
- [Optimizing Reference Counting with Borrowing](https://antonlorenzen.de/papers/master_thesis_perceus_borrowing.pdf) — the borrowed-environment formulation.
- [swift/docs/SIL/Ownership.md](https://github.com/swiftlang/swift/blob/main/docs/SIL/Ownership.md) and [SIL.md](https://github.com/swiftlang/swift/blob/main/docs/SIL/SIL.md) — `@owned` transfers the value to the recipient at +1; `@guaranteed` leaves the caller responsible for its lifetime across the call. Prismio's convention is the latter, which is why the release belongs at the caller and not in the callee.
