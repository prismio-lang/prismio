# LAYOUT 6's candidate space, measured against what this compiler can emit

**2026-08-13.** LAYOUT §6 lists five candidate dimensions. The compiler searches one. This document
is the measurement of what the other four are worth *here* — on this runtime's representation,
rather than on the contiguous-array machine LAYOUT §5's cost model assumes.

Two of the four turn out to be blocked on a missing mechanism, one on a conflict between two
clauses of the specification, and one is emittable today and pays 0.87×.

---

## 1 · Handles did not land, and two dimensions depend on them

The brief for this session, and the brief for the session before it, both opened by stating that
handles landed "in session 2". They did not. Checked directly:

| | |
|---|---|
| `ptr_to_node` in `runtime/lang_runtime.c` | `void* ptr_to_node(void* ptr) { return ptr; }` |
| handle table anywhere in `src/` or `runtime/` | none |
| `grep -rin handle src/` | 13 hits, all comments |

`HANDOFF.md`'s 2026-08-09 section already records this correction against the previous brief. It is
now recorded twice, so it is worth stating the general form: **the cost of handles is 337 dereference
sites and 190 punned empty-slot tests, and no session has paid it.** Nothing in this document is a
reason to; two of them are a reason to price it.

- **SoA** needs it. A reference to one element of an SoA group is `(base, index)`, not an address.
  Every `ptr`-typed value holding a struct would have to widen, which is exactly what handles are.
- **Handle width** (32-bit when `live(τ) < 2³²`) is vacuous without them. There is no handle to
  narrow. It is not deferred; it does not exist as a decision.

## 2 · Hot/cold does *not* need handles, and it pays

This was the assumption worth checking, because a hot/cold split reads like SoA and is not. The cold
block hangs off the hot record, so **one pointer still reaches the object** and a field access stays
a load away from a GEP. It is emittable today.

Whether it *pays* is a different question, and the reason to doubt it is the representation.
LAYOUT §5 computes `footprint = N · resident`, which assumes the N records are contiguous — shrinking
`resident` is then worth something because more records fit per line. Prismio's `List<T>` is a vector
of *pointers* to individually `malloc`'d records, so a traversal takes a miss per record no matter how
small the record is.

`aif/evidence/bench/layout_repr.c`, g1_particles' shape (200 000 records × 12 doubles, 200 frames,
`integrate` touching 6 of 12 fields and `fade` touching 2), median of 7:

| variant | median | rel A | needs |
|---|---:|---:|---|
| **A** boxed AoS — what the compiler emits today | 77.3 ms | 1.00× | — |
| **B** boxed hot/cold | **71.1 ms** | **0.92×** | nothing |
| **C** inline AoS | 66.8 ms | 0.86× | inline `List<T>` + views |
| **D** inline hot/cold | **51.2 ms** | **0.66×** | inline `List<T>` + views |
| **E** SoA | **27.4 ms** | **0.35×** | handles |
| **F** chunked inline AoS | 73.5 ms | 0.95× | capacity/growth policy only |
| **G** chunked inline hot/cold | 55.6 ms | 0.72× | capacity/growth policy only |

Read four things off it.

- **The doubt was wrong: B/A is 0.87×.** A hot/cold split pays 13% *on the boxed representation*,
  with no other change. The hot record goes 96 → 72 bytes, and the allocator packs smaller blocks
  closer together, so the traversal's working set shrinks even though every record is still a
  separate `malloc`. The prediction that it would be neutral was an argument from the cost model's
  contiguity assumption, and the experiment refutes it.
- **D/C is 0.76×**, so the same split is worth *more* once records are contiguous — which is the
  cost model's reasoning being right about the direction and wrong about the magnitude available
  today.
- **E/C is 0.41×.** With contiguity held constant, SoA is still worth 2.5×. This separates two things
  the corpus has been conflating: `g1_tuned.rs` runs at 0.26× of idiomatic Rust and is *both* SoA and
  contiguous, and this says the SoA half is the larger of the two.
- **E is the prize and it is behind handles.** 0.35× is the only measured path to beating rustc on
  this shape, and it is the same conclusion RESULTS-xlang §9 reached from a different direction.

**F and G answer a question that was never asked, and the answer is a qualified no.** The whole cost
of inline storage is *invalidation*: a contiguous block reallocs on push, which moves every element,
so a reference into it dies — which is why the inline-`List<T>` item is written as "needs
views/slices to be expressible". Chunked storage sidesteps that entirely: elements live in
fixed-size chunks that are never moved, growth appends a chunk, and an interior pointer survives a
push exactly as it does today. No views project, no by-value multi-word returns, no AIF site
migrating across a call boundary.

It costs the index — `chunks[i >> 10][i & 1023]` is a load and two ALU ops where a flat block is one
GEP — and **that costs ~10% against flat storage** (F/C = 1.10×, G/D = 1.09×). On plain AoS that eats
two thirds of the benefit: 0.86× flat becomes 0.95× chunked, which is *worse than the boxed hot/cold
split that needs nothing new at all*. So chunking is not worth doing on its own.

Combined with a hot/cold split it survives: **0.72× chunked against 0.66× flat**. That is the real
choice — six points of the win, traded against the entire views project. Measured with generic
indexing on purpose, because `list_get(l, i)` is a call per element; a sequential traversal that
walked chunk by chunk would recover most of the 10%, and is the optimisation available afterwards
rather than the thing under test.

**Hot/cold was not built this session**, by an explicit scope decision, and the reason is cost rather
than doubt: a second allocation behind every object touches all five allocator hooks, the release
path, container disposition and `--verify`'s pairing. T3 is where it cracks — `rc_release` frees one
block and cannot name the type, so a split T3 value leaks its cold half. That is a project, and half
of it is worse than none.

## 3 · Bit-packing is blocked by the specification, not by codegen

LAYOUT §2.1 marks `range(f)` **dynamic only** and says it "enables bit-packing". `workload` now
supplies it. The transform is still not implementable as specified, and the reason is that two
clauses of LAYOUT contradict each other:

> **§2.1** `range(f)` — observed value range, for integer fields — dynamic only, enables bit-packing.
>
> **§3.2 W4** The profile is an input to codegen only. Two builds with different profiles SHALL
> produce behaviourally identical programs.

An observed range is not a bound. If a workload only ever stores `0..40` in an `Int` field, narrowing
it to `i8` is authorised by §2.1 — and the next input that stores 300 reads back 44 in the packed
build and 300 in the unpacked one. That is a behavioural difference between two builds differing only
in their profile, which is precisely what W4 forbids. SPEC §1 forbids it independently: this is a
miscompile, not a lost optimisation.

**What it would be worth, so the conflict can be priced.** Upper bound over `src/`, `aif/corpus/` and
`tests/` — 48 structs, assuming every non-pinned `Int` field narrows to one byte and the narrowing is
free and legal:

| | |
|---|---|
| total struct bytes, in the layout the compiler chooses | 1368 |
| total if every `Int` narrowed to `i8` | 1240 |
| **upper bound on the saving** | **128 bytes, 9.4%** |
| structs that would shrink at all | 12 of 48 |

The largest are `ASTNode` 88 → 72, `Lexer` 32 → 16, `Mesh` 32 → 16, `Texture` 28 → 12. For scale, the
field-order search that *is* implemented shrank exactly one struct across the whole corpus, so 9.4%
is not a rounding error — it is several times the dimension already in the tree.

**Resolving it needs one of two things, and neither is an implementation decision.** Either a value
analysis that *proves* the bound, or a programmer annotation that asserts it — and a fifth annotation
is a governance change, because SPEC §11 item 7 fixes the count at four. So the compiler emits the
measurement and the saving it would buy, as advice, at the foot of the manifest:

```
# measured field ranges narrower than their declared type. Advice only:
#   an observed range is not a bound, and narrowing on one would break W4.
# type.field                    declared  observed range        fits in
# Cell.hits                     4 bytes   0..40                 1 bytes
# Cell.scratch                  4 bytes   0..869                2 bytes
```

This is deliberately not the packing dimension implemented. It is its input, made visible so that a
measurement the compiler now takes is not thrown away — and so the next person to look at §6's
packing row starts from a number rather than from the row.

## 4 · Empirical validation (LAYOUT §8) is behind §7.2, not behind the runner

§8 reads as though it needs only a way to compile and run a workload at build time. That now exists —
it is what `workload` is. It is still not implementable, and the blocker is upstream:

> §8: "after §7 converges, compile the top-`k` candidates (default `k = 3`, ranked by modelled cost)"

**There is no modelled cost in this compiler, and no candidate enumeration.** §7.2 specifies
`best := argmin over candidates(τ) of Cost(...)`; `aif_layout_select` is a greedy best-fit placement
that produces exactly *one* layout per type and never scores it. LAYOUT §5's cost model exists only in
`aif/prototype/layout.py`. So "the top-`k` candidates" names a set with one member and "ranked by
modelled cost" names a function that was never ported.

§8 therefore depends on the same machinery §1 and §2 above would have built. The half of it that is
genuinely new — a build-time instrumented compile-link-run, under a timeout, in a sandbox — is done,
and is reusable verbatim when the cost model lands.

---

## 5 · The cost model is ported, and it could not have ranked the cut it was ported for

**2026-08-16.** LAYOUT §5's cost model now exists in the compiler
(`runtime/aif_support.c`, `prismio aif <src> --layout`). It is **reported and not acted on**: the
ranking prints, and codegen still emits the unsplit record for every type, because §2 above is
still true — a split object is two allocations and the release path is not built.

Porting it surfaced two things that reading it would not have.

### 5.1 Restricted to what codegen can emit, the model picks the measured cut

On `g1_particles.psm` the prototype ranks **SoA** and returns `5.37×`. SoA needs handles, so a
compiler that ranked it would select a layout it cannot produce. Restricted to the candidates
codegen could emit — AoS × the split cuts — the same model on the same program returns
`AoS+split(8/12)`, and that is exactly the cut `bench/layout_repr.c` variant B measures at **0.87×**.

So the candidate restriction is not a weakening. It is what makes the model *useful here*, and it is
the same rule the search already stated for itself: choosing a layout codegen cannot produce is a
manifest describing a binary nobody built.

The model overstates: it predicts 0.75× where the bench measures 0.87×. It **ranks** correctly and
**scales** wrongly, which is the honest summary of a contiguity-calibrated model on a boxed runtime.

### 5.2 A linked split is not an indexed split, and the prototype cannot tell them apart

This is the finding, and it is a specification defect rather than a porting detail — now written up
as [LAYOUT §5.2.1](../spec/LAYOUT.md).

`layout.py` prices a traversal that touches cold fields as `size(hot) + size(cold)` bytes scanned:
correct for a split where the cold half sits at a computed offset in a parallel block. **This
implementation's split is linked** — the hot record points at a separately malloc'd cold block, which
is precisely why hot/cold needs no handles. Reaching a cold field is therefore a *dependent miss*,
not a longer scan, and the hot record additionally pays 8 bytes for the link.

Ported faithfully, that flips the answer on the very program the port exists for:

| candidate | hot B | cold B | prototype pricing | linked pricing |
|---|---:|---:|---:|---:|
| unsplit | 96 | 0 | 100 | 100 |
| split 2/12 | 24 | 80 | **73** ← chosen | 300 |
| split 4/12 | 40 | 64 | 86 | 337 |
| split 8/12 | 72 | 32 | 75 | **75** ← chosen |

The 2/12 cut puts five of `integrate`'s six fields behind the cold pointer. It is not a close call in
reality and it wins by two points on the prototype's own arithmetic.

**And the prototype is not safe either — it is lucky.** Its own top two candidates on this program
score **1188M and 1180M**, 0.7% apart, and the one it prefers is the good one by that margin. Add the
link word this implementation actually pays and the margin inverts. A model separating its best two
candidates by less than its calibration error is not selecting a layout; §7.2's `argmin` just
inherits whatever falls out.

With the chase priced, the good cut wins 75 against 300 — a margin the model can carry.

### 5.3 What this does and does not unblock

- **§7.2 as written** now has a cost function and a candidate enumeration. `--layout` prints the
  whole ranked set, so a cut is auditable before anything emits it.
- **§8's empirical validation** is still blocked, and now on one thing rather than two: it needs a
  way to *force* a candidate layout so the modelled ranking can be checked against measured runs.
  That is part of the split transform, so §8 follows item 1 and nothing else.
- **The cut itself** is chosen and printed. Emitting it is item 1, unchanged.

`tests/test_61_layout_cost_model.psm` is the regression, and it is built to discriminate against the
rule someone will reach for instead of a cost model: its first frequency boundary is 2/13, scoring
413, and the model picks 9/13 at 76. Verified failing on a compiler with the prototype's pricing.

---

## 6 · The `allocs` column was biased against Prismio, and only against Prismio

**2026-08-16.** `aif/evidence/xlang/bench.py` timed the frame loop and counted allocations for the
whole *process*. Once commit `901b494` moved the corpus's reporting loops onto the allocating
`println` overload, the two stopped describing the same code. The fix brackets the counted window on
the clock every one of these programs already reads per frame — see `allocount.c`; no program in any
of the three languages changed.

The correction is not uniform noise. Measured across the whole corpus:

| binary | allocs (window) | allocs (process) | inflation |
|---|---:|---:|---:|
| g1_prismio | 2,215 | 26,226 | **11.8×** |
| g1_rust_boxed | 2,206 | 2,209 | 1.0× |
| g1_rust_idiomatic | 206 | 209 | 1.0× |
| g1_swift | 963 | 972 | 1.0× |
| g3_prismio | 5,676 | 47,298 | **8.3×** |
| g4_prismio | 7,761 | 48,465 | **6.2×** |
| g5_prismio | 2,267 | 22,281 | **9.8×** |
| every Rust and Swift port | — | — | 1.0× |

**The bias is systematic and one-sided.** Prismio's `println` allocates ~4 times per call; Rust's and
Swift's do not. So the column inflated Prismio by 6–12× on four of the seven programs and left every
comparison language untouched — in a harness whose entire purpose is the cross-language comparison.

What it cost, concretely: g1's real allocation counts are **2,215 for Prismio against 2,206 for
`g1_rust_boxed`** — the same number, which is the correct answer, because both box every particle.
The old column read 26,226 against 2,209 and made that look like a 11.9× deficit. A reader pricing
inline element storage off that figure was reading print overhead.

g2 and g6 read 1.0× because their genuine workload traffic (10.2 M and 15.1 M allocations) dwarfs the
~80–126 K the dump adds. That is why the defect survived: it is invisible on exactly the two programs
the arena and capacity work has been aimed at.

Two independent checks that the window is where it is claimed: it reproduces the pre-`901b494` figure
(2,214) and it reproduces g2's separately documented 10,201,215. `clock_calls` audits the bracket on
every run and every program lands inside `[2·frames, 2·frames+64]`.

---

## What to do with this

1. **Hot/cold split.** 0.87× measured, emittable today, no missing mechanism, and the cut is now
   *chosen* rather than guessed (§5). The T3 interaction is the whole risk and it is nameable: give
   a split type a generated release and route every free through it. **Not started this session** —
   see HANDOFF for the release-path design and why a half-built split is worse than none.
2. ~~**Port LAYOUT §5's cost model**~~ — done, §5 above.
3. **Handles.** Costed at 337 + 190 sites in `HANDOFF.md`. Worth 0.35× on g1's shape, and nothing
   else in this document gets near it.
4. **The §2.1/W4 conflict** should be resolved in the specification before anyone writes the packing
   transform, not during.
