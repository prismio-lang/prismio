# AIF — The FFI Boundary

Resolves SPEC §11 open item 2: *"FFI marshalling rules. Exactly when the freeze forces a copy."*

SPEC §10.1 fixes the architecture — an FFI boundary is an ownership proof barrier, facts are frozen
before the call and selectively invalidated after. This document fixes the rules: what a
C-compatible layout is, when a copy becomes mandatory, what the boundary does to inferred facts,
and the contract vocabulary an `extern` declaration carries.

**Contents**

1. [The one place being wrong is unsafe](#1--the-one-place-being-wrong-is-unsafe)
2. [C-compatible layout](#2--c-compatible-layout)
3. [When a copy is mandatory](#3--when-a-copy-is-mandatory)
4. [The cost model does the work](#4--the-cost-model-does-the-work)
5. [Contract vocabulary](#5--contract-vocabulary)
6. [Fact invalidation](#6--fact-invalidation)
7. [Representation invariants](#7--representation-invariants)
8. [Callbacks and reentrancy](#8--callbacks-and-reentrancy)
9. [Exporting to C](#9--exporting-to-c)
10. [Reporting](#10--reporting)

---

## 1 · The one place being wrong is unsafe

Everywhere else in AIF, a wrong or missing fact costs performance. SPEC §1 is the whole design.
**The FFI boundary is the exception, and it must be stated before anything else.**

An `extern` declaration's ownership contract (§5) describes what foreign code does with a pointer.
It cannot be verified — the callee is opaque, and no analysis can look inside `libc`. It is a
**trusted assertion**. Declaring that `strlen` does not retain its argument is not a hint the
compiler will check; it is a fact the compiler will rely on when deciding the argument's lifetime.

Get it wrong and you get a dangling pointer, not a slow program.

This is not a defect unique to AIF. Rust's `*const T`, Swift's `withUnsafePointer`, and every C++
interop layer make the same trust assumption at the same place. AIF is not worse than the state of
the art here. But the model claims memory safety by construction everywhere else, so the one place
that claim does not hold has to be named loudly rather than buried.

**Mitigations, all of which are required:**

- Contracts appear in the `extern` declaration, so they are reviewable at the declaration site
  rather than inferred from a call site.
- Every trusted contract is recorded in the manifest (§10), so the total FFI trust surface of a
  program is a countable, reviewable number.
- The default contract (§5.1) is the common case, not the permissive case, and the *dangerous*
  contracts — the ones that transfer or retain — must be written explicitly.

---

## 2 · C-compatible layout

A type's layout is **C-compatible** when a C compiler given the equivalent `struct` declaration
would produce the identical byte image. Precisely, all of:

| # | Condition |
|---|---|
| L1 | Grouping is `AoS`. Not `SoA`, not `AoSoA(w)` |
| L2 | No hot/cold split — all fields in one allocation |
| L3 | Field order is declaration order |
| L4 | Padding and alignment follow the target's C ABI |
| L5 | No bit-packing beyond fields declared as bitfields |
| L6 | Every field's type is itself C-compatible, transitively |
| L7 | No handle indirection — fields hold addresses, not handles |

L1–L3 and L5 are decisions the layout optimizer makes (LAYOUT §6). L7 is a consequence: handles
resolve to addresses at the boundary, and a resolved handle inside a struct field is just a
pointer.

**The compiler always knows whether a type is C-compatible, because it chose the layout.** That is
the fact everything in §3 and §4 rests on, and it is the difference between AIF and a language
where the programmer chose the layout and the compiler has to be told.

---

## 3 · When a copy is mandatory

> **A copy is mandatory exactly when the value's chosen layout is not C-compatible. Otherwise the
> boundary is zero-copy: the handle resolves to an address and the address is passed.**

That is the whole rule. It is decidable at compile time, per call site, with no analysis beyond the
layout decision the compiler already made.

### 3.1 The four cases

| Case | Cost | Notes |
|---|---|---|
| Layout is C-compatible | **Zero** — resolve handle, pass address | The intended common case |
| Layout violates L1/L2 (SoA, AoSoA, split) | **Copy** — materialise an AoS image | Proportional to the value's transitive size |
| Layout violates L5 (packed fields) | **Copy** — unpack | Usually small |
| Value is T0 (stack) or T1 (arena) and C-compatible | **Zero** — the address is already real | Region-allocated data is *more* FFI-friendly, not less |

The last row is worth noting: arena-allocated data crosses the boundary for free, provided the
region outlives the call. That is the normal case, since the call is lexically inside the region.

### 3.2 Copy direction

- **In** — copy before the call. Required whenever the callee reads.
- **Out** — copy back after the call. Required whenever the callee may write **and** the contract
  is not `consume`.
- **Both** — an in-out parameter with a non-C-compatible layout pays twice.

A `borrow`-contracted parameter that the callee only reads (`const` in the C header, where
declared) needs the in-copy only. An implementation SHOULD use `const` in the foreign declaration
to elide the out-copy, and SHOULD warn when a non-C-compatible type is passed non-`const`, since
that is the worst case and is usually unintended.

### 3.3 What is never copied

- Scalars — passed by value, always.
- Opaque foreign handles (`extern type`) — AIF never inspects them and never lays them out.
- Function pointers (§8).

---

## 4 · The cost model does the work

The interesting consequence of §2 is that **avoiding an FFI copy does not require an annotation.**

Add a marshalling term to the layout cost model (LAYOUT §5):

```
MarshalCost(τ, L) = Σ over FFI call sites c passing τ :
                        crossings(c) · copyBytes(τ, L) / LINE · μ_M      if L is not C-compatible
                        0                                                otherwise
```

`crossings(c)` comes from the access profile the same way `iters(t)` does — the workload run counts
FFI calls, and the static profile estimates them from loop depth.

Then a type that crosses the boundary in a hot loop is **automatically** laid out C-compatibly,
because the optimizer sees the copy cost in its objective and the C-compatible candidate wins. A
type that crosses rarely keeps whatever layout its traversals want, and eats the occasional copy.

This changes what `pin` is for at the boundary:

> `pin` is not how you *get* a C-compatible layout. The cost model gets it for you. `pin` is how you
> **guarantee** it — so that a later edit which makes the type more attractive to SoA cannot
> silently reintroduce a copy on a path you care about.

Same shape as everywhere else in the model: inference finds it, the annotation makes it stable, and
the manifest makes a change visible.

---

## 5 · Contract vocabulary

An `extern` declaration carries an ownership contract per reference parameter and on the return.

**These are not a fifth annotation.** SPEC §11 item 7 freezes the annotation set at four, and this
does not break it: a contract is part of an `extern` declaration's *signature*, the same way its
parameter types are. It describes foreign code, not Prismio code; it appears in no Prismio function
body; it cannot be applied to a Prismio value. The governance rules in SPEC §11 do not apply to it
for the same reason they do not apply to `Int`.

### 5.1 Parameter contracts

| Contract | Meaning | Effect on facts |
|---|---|---|
| **`borrow`** *(default)* | Callee may read and write during the call, and does not retain the pointer after returning | `E` rises to `Caller` **for the call's duration only**, then restores. Value is pinned for the call (§8) |
| `retain` | Callee stores the pointer somewhere that outlives the call | `E ⊒ Global`, permanently. `A ⊒ Shared` |
| **`retain_in(k)`** | Callee stores this argument **into argument `k`** — the container case | `E` joins argument `k`'s escape; `A` joins argument `k`'s aliasing. E-STORE / A-STORE across a call boundary |
| `consume` | Callee takes ownership and will free it | Value is moved out. Prismio emits no free. Use-after-move applies normally |
| `out` | Callee writes through the pointer; contents on entry are not read | No in-copy; out-copy only |

### 5.2 Return contracts

| Contract | Meaning |
|---|---|
| **`alias`** *(default)* | Returned pointer borrows from an argument or from static storage. Prismio must not free it |
| `produce(free_fn)` | Returned pointer is owned by the caller and must be released with `free_fn` |

`produce` names the deallocator explicitly because C libraries frequently pair a custom allocator
with a custom free, and calling `free()` on something from `sqlite3_malloc` is a real bug the
declaration can prevent.

### 5.3 Call-site contracts

| Contract | Meaning | Effect |
|---|---|---|
| **(none)** *(default)* | Callee may call back into Prismio and may touch static roots | Invalidate everything reachable from static roots (§6) |
| `nocallback` | Callee never re-enters Prismio | Static roots keep their facts |
| `pure` | No side effects at all | Invalidates nothing. Implies `nocallback` |

### 5.3a Why `retain_in` exists *(added after measurement)*

`list_push(list, item)` stores `item` into `list`. Neither of the other contracts fits: it is not
`borrow` (the callee keeps it), and `retain` means *escapes globally*, which is far too coarse — the
element escapes exactly as far as the container does and not one step further. Marking it `retain`
would sink every element of every collection to T4.

**Collections are the most common FFI shape in a systems language**, so a vocabulary without this
contract is not usable. [RESULTS-L0.md](../evidence/RESULTS-L0-tiers.md) §4.1 found the omission by measurement: with
`list_push` falling back to the `borrow` default, every element pushed into a list appeared never to
escape — *optimistic*, and therefore unsound. It is the first measured instance of §1's warning that
a wrong contract is a safety bug rather than a slow program.

### 5.4 Why `borrow` and `alias` are the defaults

`borrow` is the overwhelmingly common C convention — `strlen`, `memcpy`, `fwrite`, `printf`, and
essentially every read-only API. Defaulting to `retain` would be the conservative choice and would
sink every FFI-touching value to T4, making the boundary unusable and pushing users toward
declaring `borrow` reflexively without thinking — which is worse than defaulting to it.

`alias` is the safe default for returns: assuming the caller must free something it does not own
produces a double-free, whereas assuming it must not produces a leak. **Where the two defaults
differ in risk, each is chosen to make the failure a leak rather than a corruption.**

```prismio
extern fn strlen(s: String borrow) -> Int  pure
extern fn fopen(path: String borrow, mode: String borrow) -> File produce(fclose)  nocallback
extern fn sqlite3_exec(db: Db borrow, sql: String borrow, cb: Callback, ctx: Ptr retain) -> Int
```

---

## 6 · Fact invalidation

SPEC §10.1 requires invalidating only facts the foreign execution may have affected. The contract
vocabulary makes "may have affected" precise rather than conservative.

**Before the call** — for every argument and everything transitively reachable from it, facts are
frozen: no inference propagates through the call edge in either direction.

**After the call:**

| Source | Invalidated |
|---|---|
| `borrow` arguments | Nothing. The freeze was scoped to the call; facts restore |
| `retain` arguments | The argument and its transitive reachable set: `E ⊒ Global`, `A ⊒ Shared` |
| `consume` arguments | The value is moved; no facts survive to invalidate |
| `out` arguments | Contents replaced: field facts for the written type rise to `⊤` |
| Static roots | Raised to `⊤` unless the call site is `nocallback` or `pure` |

Inference then resumes from the affected dependency subgraph (INFERENCE §9's incremental
machinery, applied at a call edge rather than at a source edit). An implementation MAY invalidate
more conservatively; it SHALL NOT invalidate less.

**The `nocallback` row is where most of the value is.** Without it, every FFI call raises every
static root to `⊤`, and a program with FFI in a loop converges to a state where nothing global is
ever cheap. With it, a `pure` math call costs nothing at all.

---

## 7 · Representation invariants

Two decisions about core types, made for interop rather than for performance.

### 7.1 Strings carry a NUL terminator

> **A Prismio `String`'s buffer SHALL be NUL-terminated at `len`.** The terminator is not part of
> the length and is not observable from Prismio.

Costs one byte per string. Buys zero-copy `String → const char*` on every C string call, which is
most of what FFI-heavy code does. Without it, every string crossing the boundary is a copy — the
single most common FFI operation, paying the single most avoidable cost.

A language that intends to interop with C and stores strings without a terminator has made the
wrong trade, and it is not a trade that can be undone later without breaking every consumer.

### 7.2 Arrays cross as pointer + length

An array of `T` crosses as `(T*, size_t)` when `T` is C-compatible and the array's layout is AoS.
Under SoA the copy of §3 applies, and §4's `MarshalCost` will usually have prevented SoA from being
chosen for a type that crosses often.

There is no implicit NUL convention for arrays — C APIs disagree about it, and guessing produces
silent buffer overruns.

---

## 8 · Callbacks and reentrancy

A foreign call that takes a Prismio function pointer can re-enter Prismio while the boundary is
open. Two hazards, both real:

- The callback could free or move a value the foreign code is holding a pointer to.
- The callback observes facts that were frozen for the outer call.

**Rules:**

1. Every `borrow`-contracted argument is **pinned for the duration of the call** — its storage
   cannot be reclaimed, and it cannot be relocated. This is a scoped, compiler-inserted pin, not
   the `pin` annotation.
2. A callback body is analysed in the `⊤` ownership context (INFERENCE §6.3), because its caller is
   foreign and its contexts cannot be discovered.
3. A callback SHALL NOT free or move any value reachable from the enclosing FFI call's arguments.
   This is checkable — the arguments are pinned by rule 1, and dropping a pinned value is a
   compile-time error.
4. Rule 1 does not apply at a `nocallback` call site, where no re-entry is possible.

Rule 3 is the one place an FFI construct produces a hard error rather than a diagnostic-plus-sink,
and that is correct: it is a semantic violation, like use-after-move, not an inference failure
(SPEC §1.1).

---

## 9 · Exporting to C

A Prismio function exported to C:

- Is compiled at the `⊤` ownership context (INFERENCE §6.3 already specifies this for roots
  reachable only via FFI). Its parameters cannot be assumed unique, so it gets no specialisation.
- Has C-compatible layout forced on every parameter and return type. This constraint is fed to the
  layout optimizer as a hard constraint on those types, not as a cost.
- Must declare its return contract, so C callers know who frees what. The exported header the
  compiler generates carries it as a comment.

**Forcing C-compatible layout on an exported type affects that type everywhere in the program**,
because a type has one layout. An implementation SHALL report this in the manifest as
`origin = ffi-forced`, since it is exactly the kind of non-local cost change SPEC §6 exists to
surface — one `export` can pessimise a type used in a hot loop elsewhere.

An implementation SHOULD offer a *wrapper* mode instead, where the exported entry point is a
generated shim that marshals to a C-compatible layout, leaving the internal type free. That trades
a copy at the boundary for layout freedom inside, which is the right default for a type used far
more internally than externally — and the cost model of §4 can choose between them.

---

## 10 · Reporting

The manifest SHALL carry an FFI section:

```
ffi   34 declarations · 12 trusted retain/consume contracts · 3 mandatory copies
  copy   Session      SoA[16] not C-compatible   at db_write@L204  ·  1.2 KB × ~8k crossings
  copy   Matrix       AoSoA(8) not C-compatible  at blas_gemm@L88  ·  copy dominates; consider pin
  trust  retain       sqlite3_exec(ctx)          at store.psm:41
  forced Point        C layout forced by export  at api.psm:12
```

Three things this makes reviewable that no other managed language exposes:

1. **The trust surface** — how many places the program's memory safety rests on an unverifiable
   assertion (§1). A number that should be small and should be watched when it grows.
2. **Which crossings copy, and how much they cost.** A copy that appears after an unrelated edit —
   because the layout optimizer moved a type to SoA — is otherwise invisible.
3. **Which types had their layout forced by an export**, and therefore why an unrelated hot loop
   got slower.
