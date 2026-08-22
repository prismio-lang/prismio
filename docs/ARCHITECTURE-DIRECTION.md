# Architecture direction — what to build next, and what the literature already settled

Written 2026-08-25, immediately after the final benchmark
([`aif/evidence/RESULTS-final.md`](../aif/evidence/RESULTS-final.md)). Every prize quoted here is
**measured on this host** unless it says *projected*; every design is attributed to the paper it
comes from. The scope test in [`aif/implementation/ROADMAP.md`](../aif/implementation/ROADMAP.md)
still applies — most of §1 below is **not** AIF's work, and is filed here rather than there for
that reason.

---

## 0 · The diagnosis, and the one thing everybody had backwards

Seven sessions of memory-model work did not move the corpus standing (1.12–5.57× → 1.13–5.89× of
idiomatic Rust). The final benchmark decomposed the gap, and the decomposition is not what the
roadmap assumed.

> **The eighth moved it, 2026-08-28** — automatic arena placement finally reaching the two programs
> shaped for it. g2 goes **5.77× → ~2.6×** and g6 **4.31× → 2.58×**; the other four are flat, so the
> band is roughly **1.09×–3.23×** on the driver's own numbers. The decomposition below is still the
> right one and the ranking below still holds — what changed is that the *arena* row is now spent.
> `RESULTS-final.md`'s matrix has not been re-run and is stale for g2, g6 and every RSS figure;
> TODO's first standing item is that run.

| component | measured | what it means |
|---|---:|---|
| Compiler codegen (residual vs `rust_boxed`) | **1.24–1.27×** | Fine. Normal compiler territory. Not the problem. |
| **Runtime call seam** | **1.07–1.87×** | Largest single lever. No language change needed. |
| Allocation volume | **20.2–63.7×** Rust | The real memory-model gap. |
| Boxed representation, *allocation removed* | **0.86×** | **Free.** See below. |
| Boxed representation, *as shipped* | 9.23× (g2), 2.51× (g4) | Almost entirely the allocations it forces. |

**The thing that was backwards.** The project has treated `List<T>`-is-a-vector-of-pointers as an
*indirection* problem — pointer chasing, cache misses — and ranked inline storage as the fix.
`rust/g2_tunedboxed.rs` tested that directly: Rust with Prismio's exact boxed layout,
pre-filled and mutated in place, runs at **0.86× of inline `Vec<T>`** — slightly *faster*. Chasing
a pointer to a 24-byte record costs nothing measurable.

So the representation is expensive **because of the allocations it forces, not the indirection it
adds.** That single correction re-ranks the roadmap, because there are two ways to remove
allocations and the project has only been pursuing the expensive one:

- **(a) Change the representation** — inline storage, which needs views, slices and a language
  change. Ranked #2 since session 3. Still unbuilt.
- **(b) Stop allocating** — reuse in place, non-lexical regions, a better allocator. Cheaper to
  build, and *industrialised in two production languages already* (Lean 4, Koka).

Everything below is ordered by measured prize over cost, with (b) ahead of (a).

---

## 1 · Close the runtime seam — the compilation architecture

**Measured prize: 1.07×–1.87×.** Takes g3 to **0.94× of idiomatic Rust** — the first Prismio
program ever to beat it. No language change. This is the first thing to build.

### The problem

Every container access (`list_get`, `list_set`, `list_len`, `list_push`) is a `bl` into the
separately-compiled C runtime. `cull_into` compiles to 53 instructions containing two
`bl _list_get` per iteration. The post-`-O2` IR is otherwise clean — allocas promoted, phis, tight
loop. **The codegen was never the problem; the seam was.**

`-flto` does **not** fix it (measured 1.00×). Merging program IR and runtime IR with `llvm-link`
and optimising as one module does (1.87× on hand-tuned g2, 0 calls remaining).

**Why `-flto` fails — established 2026-08-26, and it is not a cost decision.** The LTO inliner
refuses outright: `cost=never: conflicting attributes`. The backend emits program functions
carrying **no function attributes at all**, while clang stamps `target-cpu` and 33
`target-features` on every runtime function, so `areInlineCompatible` fails before the call is
priced. The `llvm-link` route only ever worked because `clang -O2` on the merged module fills its
own defaults into the attribute-less functions. Matching by hand needs clang's *exact* string — a
superset fails, a newer CPU fails, and `LLVMGetHostCPUName()` answers a different chip than clang
picks. **Built instead as a curated `available_externally` module** (§1's Swift `@inlinable` row),
which needs neither `-flto` nor attribute stamping and is cheaper to compile than either.
Driver-measured corpus median **0.864×**. Full detail:
[`aif/evidence/RESULTS-M1-lto.md`](../aif/evidence/RESULTS-M1-lto.md).

### What the literature says to build

Four languages solved this and they converge on the same shape: **the standard library must reach
the optimiser in a form it can inline, not as an opaque object file.**

| system | mechanism | lesson for Prismio |
|---|---|---|
| **Rust** | Generic std → monomorphised *in the caller's crate*; MIR serialised in the rlib for generic and `#[inline]` fns; `rustc_mir_transform::cross_crate_inline` runs **before** LLVM | Inline at *your own* IR level, before the backend. This is why `Vec` indexing disappears. |
| **Swift** | [SE-0193](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0193-cross-module-inlining-and-specialization.md) `@inlinable` exports the function *body* into the module interface; CMO serialises into `.swiftmodule` | An explicit, curated opt-in list beats "optimise everything". |
| **MLton** | Whole-program compilation: defunctorisation, monomorphisation, inlining, unboxing, argument flattening over one first-order IR ([Weeks 2006](http://www.mlton.org/References.attachments/060916-mlton.pdf)) | The maximal version. Prismio is already self-hosting, so this is closer than it looks. |
| **ThinLTO** | [Johnson, Amini & Li, CGO 2017](https://llvm.org/devmtg/2016-11/Slides/Amini-Johnson-ThinLTO.pdf) — summary-based whole-program analysis, import only what is needed | The answer to "won't merging everything wreck compile time?" It doesn't have to. |

### The recommendation, in order of cost

1. **Curated always-inline bitcode module (do this first).** Ship the ~8 hot container/allocation
   operations as an LLVM bitcode module beside the runtime archive; `llvm-link` it into the program
   module before `-O2`. This is Swift's `@inlinable` idea at IR level. It is small, reversible, and
   captures most of the measured 1.87×.
2. **Write the hot container ops in Prismio itself.** They then land in the same module as the user
   program with no linking step at all — the MLton answer, and the one that compounds with
   generics/monomorphisation already in the tree.
3. **Only if 1–2 prove insufficient:** ThinLTO-style summaries, so the merge scales past a
   300-line program.

**Do not** pursue `-flto` — measured 1.00×, and re-confirming the standing "LTO is speed-neutral"
note. Establishing *why* the linker declines an inline that the same pipeline performs on a merged
module is one cheap experiment worth doing first, since it may reduce item 1 to a flag.

**Costs to establish before committing:** compile time (the object cache already regressed 19–28%
on the genuinely-cold path), binary size, and whether `--verify`, `-g` and the object cache survive
the merge.

---

## 2 · Reuse analysis — the answer to 20–63× allocation

**Projected prize: large, on the two programs where allocation dominates (g2, g6).**
Directly attacks the one axis that has never moved.

AIF is a *classifier*: it assigns tiers (T0–T4) and reports 100% T0–T2 on g6. That is a good
classification and it still allocates 15.1 M times where Rust allocates 289 K. **Classification
without reuse does not reduce allocation count.** The literature closed this gap years ago.

- **[Counting Immutable Beans](https://link.springer.com/chapter/10.1007/978-3-030-79876-5_37)**
  (Ullrich & de Moura, IFL 2019) — the origin of reuse analysis, built for Lean 4. Pairs a
  destructured value with a constructor of the same size in the same branch and *reuses the block*
  instead of free-then-malloc.
- **[Perceus: Garbage Free Reference Counting with Reuse](https://xnning.github.io/papers/perceus.pdf)**
  (Reinking, Xie, de Moura & Leijen, PLDI 2021) — the full treatment: precise RC, reuse, reuse
  *specialisation* (in-place field updates), and borrow inference to cancel RC ops. Enables **FBIP**
  (functional-but-in-place). **Read this one first.**
- **[Reference Counting with Frame-Limited Reuse](https://www.microsoft.com/en-us/research/wp-content/uploads/2021/11/flreuse-tr.pdf)**
  (Lorenzen & Leijen, MSR-TR 2021) — bounds how long reuse tokens are held, which is the fix for
  the space-safety objection to naive reuse.
- **[Optimizing Reference Counting with Borrowing](https://antonlorenzen.de/papers/master_thesis_perceus_borrowing.pdf)**
  (Lorenzen) — borrow inference in depth. **Note the recorded caveat:** Ullrich & de Moura's
  automatic borrow inference was judged *not safe for space*, and Koka deliberately does not do it
  automatically. Read this before assuming inference can be fully automatic.

**Why this fits Prismio specifically.** `g2`'s `DrawCmd` pattern — allocate per frame, fill, cull,
discard — is textbook FBIP shape. `g2_tuned.psm` already hand-writes the reuse (pre-fill once,
mutate in place) and gets **0.25× of plain g2**. Reuse analysis is the compiler doing that
automatically. The measured ceiling for the hand-written version is already in the tree.

---

## 3 · Regions: go non-lexical and polymorphic

**Measured prize: 2.16× on g2, already proven by the annotation.** The mechanism works; the
inference does not reach it.

Two recorded blockers, and the literature names both:

**(a) "The arena is lexical and allocation is not"** (HANDOFF, 2026-08-14).

- **[Spegion: Implicit and Non-Lexical Regions with Sized Allocations](https://arxiv.org/pdf/2506.02182)**
  (2025) — the current state of the art on exactly this. Regions end at *last use* rather than at
  scope close, computed by flow-sensitive dataflow, plus *sized* allocations so fragmentation is
  statically analysable. This is the closest paper in the literature to Prismio's open problem.

**(b) Automatic placement never fires because `in_container` rejects before escape is examined**,
so a caller's region cannot reach a callee's allocations.

- **Tofte–Talpin region inference** and the honest post-mortem,
  **[A Retrospective on Region-Based Memory Management](https://link.springer.com/article/10.1023/B:LISP.0000029446.78563.a4)**
  (HOSC 2004). *Region polymorphism* — region parameters on functions — is precisely the mechanism
  for "the caller's region reaches the callee's allocations", i.e. Prismio's `CallerRegion` item.
  **Read the retrospective before the original**: it documents where region inference fails and why
  ML Kit needed a GC fallback, which is the failure mode Prismio should design against.
- **[Region-based memory management for Mercury programs](https://arxiv.org/pdf/1203.1392)** — a
  worked implementation in a non-functional language, closer to Prismio's setting than ML Kit.
- **[ASAP: As Static As Possible memory management](https://www.cl.cam.ac.uk/techreports/UCAM-CL-TR-908.pdf)**
  (Proust, Cambridge TR-908, 2017) — the tradition AIF's tier ladder already sits in. Worth
  re-reading now as a *check on the current design* rather than as new input.
- **[Reference Capabilities for Flexible Memory Management](https://arxiv.org/pdf/2309.02983)**
  (Verona) — regions as a first-class ownership concept with a per-region strategy and a "window of
  mutability". The most ambitious framing, and the right one to read if regions ever become
  user-visible beyond an annotation.

---

## 4 · Views and slices — one feature, two unlocks

Still ranked #2 since session 3, still unbuilt — but the justification changes given §0.

Inline `List<T>` storage is worth having, **not** because it removes indirection (measured free)
but because it removes allocations. If §2 removes those allocations another way, the urgency drops.
What does *not* drop is that **views/slices are the prerequisite for the layout work**, which is
the only measured path to a large win (`g1_tuned.rs` pure SoA = **0.26×** of idiomatic Rust).

- **[Compiler Support for Semi-manual AoS-to-SoA Conversions with Data Views](https://link.springer.com/chapter/10.1007/978-3-031-85697-6_20)**
  (PPAM 2024) and its extended version
  **[arXiv:2502.16517](https://arxiv.org/html/2502.16517v1)** (2025) — *the* paper for Prismio's
  layout story. Attribute-guided AoS↔SoA with **data views**, implemented in Clang. Crucially it
  is **semi-manual**: the programmer names the layout, the compiler does the conversion. That is
  a far more defensible position than the fully-automatic search LAYOUT.md currently specifies, and
  it matches the measured reality that Prismio's cost model already picked two layouts the
  measurement rejected.
- **[Optimizing Memory Access Patterns through Automatic Data Layout Transformation](https://dl.acm.org/doi/10.1145/3680256.3722203)**
  (ICPE 2025) — the automatic counterpart, with cache/vectorisation/false-sharing effects measured.
- For the representation itself: **[OCaml unboxed types](https://oxcaml.org/documentation/unboxed-types/01-intro/)**
  (flat layouts, unboxed products flattened into the enclosing block) and
  **[Java Valhalla JEP 401](https://openjdk.org/projects/valhalla/value-objects)** value-class heap
  flattening. Both are live, industrial designs for exactly "make the container store values
  inline". Valhalla's hard-won lesson is worth stealing directly: **polymorphic variables cannot be
  flattened** — which tells you where Prismio's generics and its container representation will
  collide.
- **[Unboxing using Specialisation](https://www.researchgate.net/publication/2442838_Unboxing_using_Specialisation)**
  and **[Flattening tuples in an SSA intermediate representation](https://www.researchgate.net/publication/220606911_Flattening_tuples_in_an_SSA_intermediate_representation)**
  (MLton) — the mechanics, in a whole-program compiler that already did it.

---

## 5 · The allocator — cheap, mechanical, and it also touches the RSS regression

If the allocations cannot all be removed, make each one cheaper.

- **[Mimalloc: Free List Sharding in Action](https://www.microsoft.com/en-us/research/wp-content/uploads/2019/06/mimalloc-tr-v1.pdf)**
  (Leijen, Zorn & de Moura, APLAS 2019). Page-local sharded free lists, a very short fast path, and
  **it was built specifically as the backend for reference-counted runtimes** — Koka and Lean. That
  is the same workload shape Prismio has: high allocation count, small objects, predictable sizes.

One reason this is well-timed: Prismio allocates 20–63× more than Rust, so allocator cost is
weighted 20–63× more heavily here than in the baseline.

**The second reason is gone, and the correction is worth more than the entry was.** This section
used to cite the peak RSS regression — 0.84–1.00× → 1.09–1.60× of idiomatic Rust — as "an
allocator-adjacent symptom that is still unexplained". It was **leaks**. Removing two of them on
2026-08-28 dropped peak RSS to **0.49×–0.82×** of the previous compiler across the whole corpus,
and both were a *missing owner* rather than a missing free. The entry described the signature
correctly for eight sessions — "scales with live set rather than churn" — and nobody read that
sentence as the definition of a leak. mimalloc is still worth evaluating on allocation *cost*; it
was never going to fix the footprint.

---

## 6 · The ranked plan

| # | Item | Prize | Cost | Language change? | Source |
|---|---|---|---|---|---|
| 1 | **Close the runtime seam** | **1.07–1.87×** measured | low | **no** | ThinLTO / Swift `@inlinable` / MLton |
| 2 | **Reuse analysis** | attacks 20–63× alloc | medium | no | Perceus / Immutable Beans |
| 3 | **Non-lexical + polymorphic regions** | 2.16× measured on g2 | medium | no (annotation exists) | Spegion / Tofte–Talpin |
| 4 | **Views & slices** → inline storage + data views | 0.26× projected (SoA) | high | **yes** | PPAM 2024 / OCaml / Valhalla |
| 5 | **mimalloc** | alloc cost + RSS | low | no | APLAS 2019 |

**Take 1 first.** It is the only item that is measured, large, and free of language design.
**Take 2 before 4** — it attacks the same allocation cost for less than a language change, and
§0 shows the representation's indirection cost is zero.

---

## 7 · Measured dead ends — do not re-derive these

- **`-flto`.** 1.00×. Confirms the standing note. Not the route to §1 — and the *reason* is now
  known: `cost=never: conflicting attributes`, because the backend emits no target attributes and
  clang stamps them on the runtime. Making it work needs clang's exact `target-cpu` +
  `target-features` string (a superset fails; a newer CPU fails; the host-CPU API answers wrong),
  and even then it is slower to compile and no faster to run than the curated module. Do not
  re-derive this.
- **Stamping target attributes to enable `-flto`.** Measured 1.87× — the same as the curated
  module — at 1.21× compile time against 1.18×, with a per-target CPU string to get exactly right
  and a linker-plugin dependency. Strictly dominated. It survives only as the explanation above.
- **Merging the *whole* runtime.** 1.88× compile time for less speed than curating 8 functions.
- **Chasing the residual.** 1.24–1.27× is ordinary codegen distance from rustc and has been stable
  for seven sessions. There is no single lever behind it.
- **Assuming boxed layout costs indirection.** Measured **0.86×** — free. It costs *allocations*.
- **Fully automatic layout search before views exist.** The cost model already ranked two layouts
  the measurement rejected, and the vetoes that removed them were written from measured regressions
  rather than from a search. The PPAM "semi-manual + data views" framing is the defensible one.
- **Assuming automatic borrow inference is safe.** Koka deliberately does not do it; the space-safety
  objection is documented.

---

## 8 · Reading order

If only three, in this order:

1. **[Perceus](https://xnning.github.io/papers/perceus.pdf)** (PLDI 2021) — reframes the memory
   model from *classify* to *reuse*, which is the axis that has never moved.
2. **[Spegion](https://arxiv.org/pdf/2506.02182)** (2025) — named blocker, current state of the art.
3. **[ThinLTO](https://llvm.org/devmtg/2016-11/Slides/Amini-Johnson-ThinLTO.pdf)** (CGO 2017) — how
   to close the seam without paying whole-program compile times.

Then **[the region retrospective](https://link.springer.com/article/10.1023/B:LISP.0000029446.78563.a4)**
for what goes wrong, and **[PPAM 2024 data views](https://arxiv.org/html/2502.16517v1)** before any
further layout work.
