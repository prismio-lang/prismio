# AIF — Roadmap

*What is left, in priority order. Every item states AIF's stake; §5 lists what is **not** AIF's
work despite having come up during design.*

Every item states **AIF's stake** explicitly. Items with no AIF stake are in §5 and are not AIF
work, however useful they may be.

**The scope test, applied to everything below:** *would this exist in a language with a completely
different memory model?* If yes, it is not AIF's — it may still be necessary, but it belongs to the
compiler or the language, and AIF does not get to mandate it.

AIF's job is narrow: **when values die, and how they are arranged.** Everything it says about
anything else is a requirement placed *on* a language feature, not a demand that the feature exist.

**Next:** C1 (affine collections) — the only remaining item with measured impact. The first two are cheap to think about and could force structural change;
the third unlocks more than any further specification.

---

## 1 · AIF core — genuinely ours

### ~~B13. Un-freeze the 80/20 budget rule~~ ✅ **done** — SPEC §9 now derives the split from measured traversal opportunity
SPEC §9 freezes layout-over-lifetime as normative. Measured wrong for graph-shaped code: the
compiler has **zero** traversals and 1.00× layout benefit ([RESULTS-L1](../evidence/RESULTS-L1-layout.md)). Make the
split derived from measured opportunity — the static profile already reports traversal count before
anything is spent. *This is the one place the specification is confidently wrong.*

### ~~B14. Specify closure capture~~ ✅ **done** — INFERENCE §4.5. Capture is a store into the closure record; no new lattice needed. Escaping closures are *the* origin of T3
INFERENCE §4 has no transfer rule for capture. AIF's stake is total: a capture creates a reference
whose lifetime is decoupled from its scope, which is the canonical way a value becomes shared.
**AIF does not require the language to have closures — it must say what the facts do when it does.**
Until this exists, the T3 population is not merely unmeasured, it is unmeasurable.

### A5. Flow-sensitive aliasing *(measurement)*
The second-largest cause of residue after collections: a value owned by two variables *sequentially*
reads as shared. Pure analysis precision — squarely ours, and improves every number the prototype
produces.

### A4. Arena high-water marks *(measurement)*
Peak arena occupancy per region. AIF's stake: arenas are T1, so their size is a memory-model output.
Enforcement — build gates, console budgets — is not ours.

### ~~B6. Correct INFERENCE §7.1~~ ✅ **done**
It oversells the relevant-parameter mask. Measured: the mask saves 15%; survivability comes from
mean `n` being 1.48.

### B8. Revisit the T3/T4 design budget
Six programs produced zero T3 — but that is because the language has no closures
([EVALUATION.md](../evidence/EVALUATION.md) §5), not because sharing is rare. Reassess after B14.

### A3. Realised context counts *(measurement)*
BENCHMARKS H4 has only the `3ⁿ` worst case. **Low priority** — contexts contributed zero to every
measured tier number.

---

## 2 · AIF's stake in language features it does not own

Each is a *language* decision. AIF's job is to specify what happens to facts — not to design the
feature, and not to demand it.

### ~~B10. Slices and views~~ ✅ **resolved** — SPEC §8.4
The feared outcome did not happen: views need **no new machinery**. Lifetime comes from escape
propagation (a view's escape raises the *collection's*, so a long-lived slice sinks the collection a
tier instead of erroring); invalidation is impossible because a view holds the collection's identity,
not its buffer address; overlapping mutable views are permitted, because AIF's safety property is
no-UAF/no-race rather than no-aliasing — an ergonomic gain over Rust.

Deepest consequence recorded: **under SoA an element has no address**, so an element reference is
`(handle, index)`, not a pointer. Layout freedom and raw interior pointers are mutually exclusive.

### ~~B9. Dynamic dispatch~~ ✅ **resolved** — INFERENCE §4.6. Target set is *bounded and known* under whole-program analysis, so it joins over real implementors rather than assuming the worst as FFI must
A virtual call has N callees, so INFERENCE §6.3's call-site context discovery has no single target
and must join over every implementor — sinking facts exactly like an opaque FFI call, but *inside*
the language. AIF's stake: what facts survive a virtual call. Not: whether the language has
interfaces.

### ~~B11. Drop under error propagation~~ ✅ **resolved** — SPEC §11 item 11. Drops on every exit path; AIF recommends `Result`-style because unwinding makes every call site a scope exit
SPEC §11 item 11 requires deterministic destruction at every scope exit. Whether that includes
*unwinding* depends on an unmade language decision. AIF's stake: state the requirement conditionally
for both — with exceptions, drops need landing pads and every call becomes a potential exit; with
`Result`, it is ordinary control flow.

### B4. What sharing means
Shared references are a language feature; **what sharing implies for ownership is AIF's.** Gates T3,
T4 and the collector.

### ~~B12. Generics × ownership contexts~~ ✅ **resolved** — INFERENCE §4.7. The policy-parameter strategy collapses the product to a sum
Monomorphisation per type, times contexts per parameter mode, is multiplicative. AIF's stake: the
interaction. Not: whether the language has generics.

### B5. Thread-affinity rules given a task model
AIF's stake is the `T` domain and the E-SPAWN/E-SPAWN-J rule. **Designing a task model is not AIF's
job** — specify the rules that apply once one exists.

---

## 3 · Compiler requirements AIF genuinely has

In [COMPILER-TODO.md](REQUIREMENTS.md). The ones AIF cannot work without:

| | Why AIF needs it |
|---|---|
| **Affine collections** | 100% of measured residue. Without it the model does not work. |
| **`region`** | AIF's own annotation; T1 is unreachable without it. |
| **Three allocation hooks** | The current single hook cannot express T0 or T1. |
| **Scope-based drop** | SPEC §11 item 11 has no substrate otherwise. |
| **FFI ownership contracts** | Measured 33-point swing; wrong defaults are *unsound*. |
| **The four annotations** | AIF's own surface. |
| **`verify` mode** | How the safety claim is checked at all. |
| **Handles** | SPEC §11 item 5; enabling condition for layout. |
| **Tier known before codegen** | Codegen must know the tier to emit the allocation. |
| **Struct size introspection** | `Θ_stack` needs real sizes. |

---

## 4 · Measurement

- **A6.** Freeze the oracle harness — manifest diffing, so the in-compiler port can be
  differentially tested against the prototype.
- **B7.** Reweight COMPARISON per TARGET §3.
- **Blocked on codegen:** dynamic tier distribution, any runtime number, any cross-language
  comparison, layout *validation* as opposed to selection. COMPARISON.md is a plan that unblocks
  when codegen does; **zero ports are written, correctly so** — today they would measure the old
  malloc path and say nothing about AIF.

---

## 5 · Not AIF — recorded, then handed over

These came up while working and were mistakenly filed as AIF work. Each fails the scope test: it
would exist in a language with a completely different memory model.

| | Owner | Note |
|---|---|---|
| PIR format, versioning, merge, dedup | Compiler | Rescoped; AIF keeps four requirements ([PIR.md](../spec/PIR.md) scope note) |
| Per-module optimisation levels, artifact caching | Build system | AIF's only stake: the invariant makes mixing levels *sound* |
| Hot reload | Compiler / runtime | AIF's only stake: specialisation is hostile to it |
| Generic containers `Map`/`Vec` | Language | Was justified as "so the engine is writable" — tooling convenience |
| `Option` / `Result`, error handling | Language | Overlaps B11, but the feature is not ours |
| Closures *as a feature* | Language | AIF specifies capture (B14); it does not demand closures exist |
| Optional / nullable fields | Language | Found via G3; nothing to do with memory |
| Superlinear compile time | Compiler | Performance, not model |
| `Int` ↔ `Float` conversion | Language | Hit writing a benchmark |
| `List<Int>` miscompile | Compiler bug | Found via G6 |

**Kept because they are real and someone should fix them — but they are not AIF's list, and AIF's
priorities should not be read off them.**

---

## 6 · Over-built — defer or cut

Recorded so the specification's size is a decision rather than an accident.

| Item | Status | Argument |
|---|---|---|
| Ownership contexts + monomorphization | **Defer** | Contributed **zero** to every measured tier number |
| [CYCLES.md](../spec/CYCLES.md) | **Defer** | Inexpressible in the language; zero population in six programs |
| Static region / baked init | **Defer** | Speculative; benefit is program-dependent |
| Empirical layout validation | **Defer** | Compiling and running k candidates at build time |
| `workload` annotation | **Question it** | Static profile is *exact* for structure; weakest of the four |
| AoSoA(4/8/16) | ✅ **cut** | Removed from LAYOUT §6 and the optimiser |
| T4a/T4b sub-classes | **Dormant** | T4a needs concurrency |

---

## Done

- Specification 1.2; SPEC §11's open list is measurement and policy only
- Inference prototype + layout optimiser, both converging
- `prismio dump-ast` — additive, IR byte-identical, suite 57/57
- Six-program corpus, all compiling and running
- **Measured:** 100% T0–T2 with affine collections; the entire residue is one language decision
- **Measured:** layout selection discriminates AoS vs SoA correctly from static data alone
- **Measured:** sealing costs 25 points, bounded to boundary-crossing values, mostly
  contract-recoverable
- **Measured:** FFI default contract worth 33 points
- **Found and fixed:** `retain_in(k)` missing; LAYOUT §5.4 could go negative; PIR misfiled as
  memory-model work
