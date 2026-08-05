# PIR — Prism Semantic IR

> ## Scope note — most of this is compiler work, not memory model
>
> **PIR is the compiler's own IR and package-distribution format.** It exists because LLVM IR is
> version-locked and unsuitable for shipping packages — the same reason Swift has `.swiftinterface`
> and Rust ships crate metadata. Its encoding, versioning, section layout, content hashing, merge
> and deduplication rules are **toolchain engineering** and belong to the compiler, not to AIF.
> Every language needs a distribution format regardless of how it manages memory.
>
> **AIF's stake is four requirements it places on whatever that format turns out to be:**
>
> 1. **Bodies, not summaries** (§1) — ownership contexts are discovered at call sites, so a
>    consumer may need a specialisation the author never compiled.
> 2. **FFI contracts must survive distribution** (§2) — they are trusted ownership facts; if they
>    do not ship, every consumer re-trusts blindly.
> 3. **Target-neutral** (§4) — the *consuming* compiler chooses layout, because AIF says the
>    compiler owns layout.
> 4. **Sealed functions are internal FFI boundaries and SHALL publish contracts** (§5, §5.1) —
>    measured at 25 points of tier distribution in [RESULTS-L2.md](../evidence/RESULTS-L2-boundary.md).
>
> Those four are normative for AIF. **Everything else below is reference material for whoever
> builds the format** — retained because the design work is done and worth keeping, not because a
> memory model gets to mandate it. Sections 2–4, 6 and 8–9 are compiler-track: see
> [COMPILER-TODO.md](../implementation/REQUIREMENTS.md) 21.

SPEC §10.2 fixes PIR as the canonical distributable form of a Prismio library and states what it
must preserve. This document covers the content model, the merge rules, the stability guarantee,
and the ecosystem consequences — including the two that are genuinely uncomfortable.

**Contents**

1. [Why bodies must ship](#1--why-bodies-must-ship)
2. [Content model](#2--content-model)
3. [Deterministic emission](#3--deterministic-emission)
4. [Merging](#4--merging)
5. [Sealed functions](#5--sealed-functions)
6. [Versioning and stability](#6--versioning-and-stability)
7. [Semantic stability — the supply-chain problem](#7--semantic-stability--the-supply-chain-problem)
8. [What this costs the ecosystem](#8--what-this-costs-the-ecosystem)
9. [Dynamic linking, for those who need it](#9--dynamic-linking-for-those-who-need-it)

---

## 1 · Why bodies must ship

The obvious design is to ship *summaries* — each function's inferred parameter and return facts —
and keep bodies private. It does not work, and the reason is worth stating because it forecloses
every lighter-weight alternative.

Ownership monomorphization (SPEC §11 item 4) compiles a function once per ownership context, and
contexts are **discovered from call sites** (INFERENCE §6.3). A library author cannot enumerate the
contexts their consumers will produce: a function published today may be called tomorrow with a
`Unique` argument nobody anticipated, and the specialisation for that context has to be generated
*by the consuming compiler*.

Summaries cannot support that. A summary tells you what the facts were under the contexts the
author compiled; it cannot produce a body for a context they did not.

> **PIR therefore carries full function bodies. Shipping a Prismio library means shipping something
> functionally equivalent to source.**

This is a real consequence and it should not be soft-pedalled. Rust has the same property for
generic functions; AIF has it for *everything*, because every reference-taking function is
effectively generic over ownership. §5 gives the escape hatch for code that genuinely cannot ship
this way, and §8 states the cost honestly.

---

## 2 · Content model

PIR is a container of sections. Encoding is implementation-defined for v1 (§6); the content model
below is normative.

| Section | Contents | Required for |
|---|---|---|
| `header` | Format version, compiler identity, target neutrality flag, content hash | Compatibility checking |
| `types` | All type definitions, field types and order, the **type reference graph** | Cyclicity (INFERENCE §4.4), layout, C-compatibility (FFI §2) |
| `functions` | Full typed bodies in a typed SSA form, with parameter modes unresolved | Context-sensitive re-analysis (§1) |
| `annotations` | Every `unique`, `region`, `pin` site, bound to the node it annotates | Axiom seeding (INFERENCE §8) |
| `externs` | Every `extern` declaration with its full FFI contract | FFI §5 — contracts must survive distribution or the consumer re-trusts blindly |
| `workloads` | Declared workloads and any checked-in access profile | LAYOUT §2 — a library's own traffic is information the consumer cannot recover |
| `summaries` | Precomputed per-context facts, as a **cache only** | Speed. Discardable without changing results |
| `manifest` | The library's tiers and layouts when compiled standalone | §7 — the baseline a consumer diffs against |
| `spans` | Source positions and file identities | Diagnostics that name library code |
| `sealed` | Object code for sealed functions (§5) | Proprietary distribution |

Three of these are not obvious and are worth defending:

- **`summaries` is a cache, not content.** Deleting it SHALL change nothing but compile time. If a
  summary could change a result, it would be a second source of truth that can disagree with the
  bodies — and INFERENCE §9 already requires incremental results to match cold ones.
- **`externs` must carry FFI contracts.** A contract is a trusted assertion about memory safety
  (FFI §1). If it did not survive distribution, every consumer would re-declare it from the C
  header and the trust surface would multiply silently.
- **`workloads` travels with the library.** A library author knows their own traffic; a consumer
  compiling the library into their program does not. Without this the library's layouts are chosen
  from the consumer's profile alone, which sees library-internal loops but not the shapes the
  author knows are representative.

### 2.1 Not LLVM IR

PIR is not, and cannot be, LLVM IR. Lowering to LLVM discards exactly what AIF needs: ownership
structure, the type reference graph, annotation sites, and the distinction between a move and a
copy. SPEC §10.2's permission to *additionally* emit LLVM IR or object files stands, and those
artifacts remain non-canonical and reduce optimisation opportunity — including, per §5, all the way
down to none.

---

## 3 · Deterministic emission

> **PIR emission SHALL be deterministic: identical source, compiler version and settings SHALL
> produce byte-identical PIR.**

Three things depend on this, and none of them is optional:

1. **Reproducible builds.** A non-deterministic distributable makes every downstream artifact
   non-reproducible.
2. **Content-hash keying.** §4's diamond deduplication and INFERENCE §9's summary cache both key on
   content hashes. Non-deterministic emission makes identical inputs look different and silently
   defeats both.
3. **Diffability.** A library update whose PIR changes in ways unrelated to the source change is
   unreviewable.

The requirements are the familiar ones and each has been violated by a real toolchain: sorted
iteration over every map, no embedded timestamps, no absolute paths (record source paths relative
to a declared root), no hash-seed-dependent ordering, and a fixed integer encoding — no
platform-width or endianness dependence.

Every section SHALL be independently content-hashed, so a consumer can tell *which* section changed
between two versions of a library. `types` changing is a much bigger event than `spans` changing.

---

## 4 · Merging

The consuming compiler merges application PIR with all dependency PIR before inference begins
(SPEC §10.2). Rules:

**Diamond dependencies.** The same library at the same version reached by two paths is deduplicated
by content hash. Identical hash means one copy; differing hash at the same declared version is an
**error**, not a warning — it means someone's artifact is not what it claims to be.

**Multiple versions of the same library.** Permitted. Types from different versions are **distinct
types** and do not unify, exactly as in Rust. Both versions are merged, both are analysed, and both
contribute to code size. The consumer's manifest reports the duplication, because it is a cost the
consumer should see rather than discover in their binary size.

**Name collisions across libraries.** Resolved by library identity. PIR symbols are qualified by
`(library id, version, module path, name)`; the flat namespace never exists at merge time.

**Target neutrality.** PIR SHALL be target-neutral: no target-dependent layout, no resolved
pointer widths, no baked cache-model constants. Layout is chosen by the *consuming* compiler for
the *consumer's* target. A library that hard-codes a layout has pre-empted a decision that is not
hers to make — the whole point of SPEC §8.2 is that the compiler owns layout, and the compiler that
owns it is the one producing the binary.

The `manifest` section (§2) is the exception, and it is advisory: it records the layouts the
library got when compiled standalone, for §7's diffing, and is never binding.

---

## 5 · Sealed functions

For code that cannot ship in body form — proprietary algorithms, licensed third-party code — an
implementation SHALL support **sealing**.

A sealed function is compiled by its author at the `⊤` ownership context only, and ships as object
code plus a signature. The consumer cannot re-specialise it, cannot inline it, and cannot see it.

**Sealed functions are internal FFI boundaries**, and the framing is exact rather than analogical:

| | FFI (FFI.md) | Sealed |
|---|---|---|
| Callee body visible? | No | No |
| Ownership contract | Declared, trusted (FFI §5) | Declared, trusted |
| Parameter facts | Per contract | Per contract |
| Context | `⊤` | `⊤` |
| Layout at the boundary | C-compatible or copy | C-compatible or copy |
| Fact invalidation | FFI §6 | FFI §6, identically |

So sealing costs precisely what an FFI call costs, plus the loss of specialisation and inlining —
and it reuses the machinery rather than adding any. A library that seals everything is a C library
with better diagnostics, and its consumers should expect C-library performance from it.

An implementation SHALL report sealed dependencies in the manifest. A consumer whose hot path runs
through a sealed function should know why they cannot make it faster.

### 5.1 Sealed surfaces SHALL publish ownership contracts

*(Added after measurement — [RESULTS-L2.md](../evidence/RESULTS-L2-boundary.md) §3.)*

A sealed function's parameters and returns SHALL carry the [FFI.md](FFI.md) §5 contract vocabulary:
`borrow` / `retain` / `retain_in(k)` / `consume` on parameters, `alias` / `produce(free_fn)` on
returns.

Without them every undeclared return has unknown provenance and must be treated as already shared
and already outliving the caller — which is what turned a 100% tier distribution into 75% when the
G6 engine was sealed. **Declaring the contracts recovers most of that loss without exposing a
single body**, because the facts the consumer needs are the contracts, not the code.

This is the same requirement a C library carries, for the same reason, and it is what makes §5's
"sealed functions are internal FFI boundaries" a working rule rather than an analogy.

---

## 6 · Versioning and stability

### 6.1 Format versioning

`header` carries `major.minor`.

- A compiler **SHALL** read PIR with the same `major` and any `minor` ≤ its own.
- A compiler **SHALL** reject a higher `major` with a diagnostic naming the required compiler
  version — never with a parse error, and never by attempting a best-effort read.
- Unknown sections at the same `major` SHALL be preserved on re-emission and ignored otherwise.
  This is what makes `minor` additions non-breaking.
- A `major` bump requires re-publishing libraries. An implementation SHOULD support the previous
  `major` for at least one release cycle, and SHOULD ship a mechanical upgrader.

### 6.2 What is *not* guaranteed

There is no ABI. PIR is not a binary interface and does not pretend to be one. Consequences in §8.

Nor is there a guarantee that a given PIR produces the same *machine code* across compiler
versions. Layout search, dedup thresholds and cost-model constants all evolve, and SPEC §9.1
explicitly permits it. What is guaranteed is behavioural equivalence and a *diffable record* of the
change (§7).

---

## 7 · Semantic stability — the supply-chain problem

The uncomfortable one, and it is a genuinely new failure mode rather than a restatement.

Because AIF analyses whole programs, **a library update can change the tier and layout of the
consumer's own values**, in code the consumer did not touch. A new `retain` in a library's internals
can raise a consumer type's escape fact to `Global` and move it from T1 to T4a — a large,
non-local, entirely invisible regression that no version number expresses.

This is SPEC §5's cost-predictability weakness, propagated across a dependency edge, where it is
worse: the consumer cannot see the edit that caused it.

**The answer is the mechanism that already exists.** The consumer's manifest diffs on every build
(SPEC §6.3), and a tier regression fails the build gate. So the failure mode is loud rather than
silent:

```
− Session.buffer   T1  region:handle_request  SoA[16]  region
+ Session.buffer   T4a rc-atomic              AoS      inferred
  cause: E rose Region(handle_request) → Global
  at:    metrics-lib 2.4.0 → 2.5.0, Collector.register now retains its argument
```

Two obligations follow, and both are normative:

1. **A manifest diff SHALL attribute a cause to a dependency version change when it can.** The
   dependency's `manifest` section (§2) is what makes this possible: the consumer compares the
   library's standalone tiers across versions and attributes the delta.
2. **A library SHOULD publish its own manifest.** Then a library *author* can see they are about to
   regress every downstream consumer — before publishing, not after. No package ecosystem currently
   offers this, and AIF gets it as a by-product of an artifact it already emits.

This does not eliminate the problem. It converts an invisible, unattributable regression into a
failing build with a named cause, which is the same trade SPEC §11 makes for local edits.

---

## 8 · What this costs the ecosystem

Stated plainly, because these are decisions made on day one that constrain everything after.

- **No dynamic linking.** Whole-program monomorphization and system-wide shared libraries are
  incompatible. §9 is the mitigation and it is not free.
- **No security-patch-in-place.** A vulnerability in a widely used library requires **recompiling
  every dependent binary**, not replacing one `.so`. §8.1 makes this mechanical and cheap; it does
  not make it go away.
- **Binary size multiplies.** Every program embeds its own specialised copy of everything it uses.
  Combined with ownership monomorphization (SPEC §12), size is AIF's weakest practical axis by a
  distance.
- **Source-equivalent distribution.** §1. Proprietary libraries must seal (§5) and accept
  C-library performance, or ship their logic.
- **Compile time is the consumer's problem.** The consumer compiles the whole dependency tree's
  bodies, every release build. Library authors' compile time becomes their users' compile time.

Rust and LTO set partial precedent for the first, third and fifth. Nothing sets precedent for the
second, which is why it gets §8.1 rather than a shrug.

### 8.1 Self-rebuilding binaries

*(New in 1.2 — [CHANGES-1.2.md](../implementation/RATIONALE.md) C10.)* Three parts, which together convert a
**coordination problem into a compute problem**. Those differ in kind, and the distinction is the
whole point.

**Part 1 — the binary carries what it needs to rebuild itself.** A release artifact embeds the PIR
closure of its dependencies, its manifest, and a compiler version pin.

```bash
aif rebuild --replace libssl@3.2.0=3.2.1 ./myserver
```

No source access, no build environment, no dependency resolution. The objection to "rebuild the
world" is almost never the compilation — it is that rebuilding requires reassembling a build
environment that may no longer exist, for software whose maintainers may no longer exist. A
self-contained artifact dissolves that objection.

**Part 2 — the rebuild is fast, because the manifest already made the expensive decisions.** A
security rebuild does not need to redo layout search or re-derive tiers. It needs the *same*
decisions applied to patched code, and the manifest records them (§2). The rebuild reads the
manifest instead of re-searching: minutes, not hours. This is the third distinct problem the
manifest has solved.

An implementation SHALL support `rebuild` reading a manifest as authoritative, and SHALL report any
record it could not honour because the patch invalidated it — those, and only those, need
re-deriving.

**Part 3 — the consumer chooses the boundary, not just the library.** §9's C-ABI shim is
consumer-selectable: *"link openssl dynamically even though it did not ask to be."* Whole-program
optimisation everywhere else, a patchable boundary exactly where the threat model wants one.

**What remains true.** It is still a rebuild. Binaries are still redistributed, a running process
still cannot be patched, and a distribution still recompiles rather than replaces. This is a real
answer and not a complete one, which is why SPEC §11 keeps it open — demoted, not deleted.

**Cost.** Binary size grows by the embedded PIR. An implementation SHALL support stripping it, at
the cost of losing self-rebuild — the right trade for an embedded target, the wrong one for a
server.

---

## 9 · Dynamic linking, for those who need it

An implementation SHALL support emitting a **C-ABI shim library** alongside PIR: a stable-ABI
shared object exposing a chosen set of entry points through the FFI boundary.

The shim is an ordinary FFI export (FFI §9): C-compatible layout at the boundary, `⊤` context, a
copy where the internal layout is not C-compatible, no cross-boundary inference.

So a Prismio library *can* be dynamically linked and *can* be patched in place — as a C library,
paying C-library costs, and losing every AIF optimisation across that boundary. That is the honest
trade rather than a workaround: dynamic linking's benefit is a stable interface, and a stable
interface is precisely what whole-program specialisation trades away.

Choosing it per boundary rather than globally is what makes it tolerable: a program can link the
one library that needs patching dynamically and keep whole-program optimisation everywhere else.
