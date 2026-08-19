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

**Hot/cold was not built in the 2026-08-16 session**, by an explicit scope decision, and the reason
was cost rather than doubt: a second allocation behind every object touches all five allocator hooks,
the release path, container disposition and `--verify`'s pairing. T3 is where it cracks — `rc_release`
frees one block and cannot name the type, so a split T3 value leaks its cold half. That is a project,
and half of it is worse than none. It was built on **2026-08-17**; §2.1 below.

### 2.1 · It was built on 2026-08-17, and the corpus does not reproduce the 0.87×

The transform and its release path landed. `prismio` now emits a **linked** split: the hot record ends
in a pointer to a separately allocated cold block, `ir_struct_field_ptr` redirects any field index at
or above the cut through it, all five allocator hooks allocate both halves, and every split type gets
a generated `__aif_release_T` that frees the cold block before the base.

Verified by running rather than by reading. `--verify` over the corpus reads **0 violations
everywhere**, and `released` rises by exactly the number of split objects — g1 2 011 → 4 011 for 2 000
Particles, g5 2 064 → 4 092, g4 7 556 → 9 056 — with `leaked` unchanged on every program.
`tests/test_62_split_release.psm` is the fixture, and it is verified discriminating in both directions
(leak: 4 108 released of 8 204 and 4 100 leaked; double free: 4 096 violations).

**And then the measurement refused to reproduce the prize.** Interleaved A/B of `build/mg3` against
the split compiler over `aif/evidence/xlang/prismio/*.psm`, 20 pairs each, on a **contended host** — a
second agent was building compilers on the same machine throughout, so every number here is
provisional:

| program | split emitted | B/A median | B/A minimum |
|---|---|---:|---:|
| g1 | `Particle 8/12` | 0.958, 1.029, 1.034, 1.035 | 0.967, 0.976 |
| g2 / g2_capacity / g2_region | `Renderable 3/6` | 0.999–1.010 | — |
| g3 | none (vetoed, §2.2) | 0.997 | — |
| g4 | `Sprite 2/6` | 1.016 | — |
| g5 | `Mesh 2/6`, `Texture 4/7`, `Entity 3/6` | 0.994 | — |
| g6, g7 | none | 0.978–1.000 | — |

Four interleaved runs of *the same pair* on g1 span **0.958× to 1.061×** on the median, and 0.967× to
0.976× on the minimum. The median says a small loss, the minimum says a small win, and the two
disagree in sign — so the honest reading is that **this host cannot resolve a 10% effect on g1's
port**, not that the split is worth −3% or +3%. Re-take it on a quiet host. Reproduce with:

```
python3 <scratch>/ab_interleaved.py --a build/mg3 --b build/<gen> --repo . --runs 40 --only g1
```

What is *not* noise is that `layout_repr.c` still measures **0.88×** for exactly this cut, and does so
at every size: N = 2 000 × 6 000 frames reads 0.88×, N = 20 000 × 600 reads 0.87×, N = 200 000 × 200
reads 0.89×. So the gap is not a working-set effect, and the corpus program is not a different shape
from the benchmark. The remaining structural difference between the two is that `layout_repr.c`
reaches an element with `ps[i]` and the Prismio port reaches it with `list_get(ps, i)`, an out-of-line
call per element — the same 10% §2's F/C row already charges to generic indexing. **That is the next
thing to measure, and it is a measurement rather than an argument.**

### 2.2 · The cost model chose two layouts the measurement rejected, and both reasons are nameable

Third time on this project that a measurement has refuted the cost model, and unlike the first two it
happened *after* the model was wired to codegen — which is the entire value of wiring it.

* **`g3_scene_graph`'s `Node`, split 4/7 at a modelled 12, ran at 1.110×** — the largest regression in
  the corpus. `Node` has two **inline** `Transform` fields of 48 bytes each, and `aifDeclare` sizes
  every field with `aifTypeBytes`, which answers 8 for a struct-typed field because the struct
  registry is empty during the analysis. The model believed `Node` was 40 bytes; it is 112. A cut
  chosen from a shape that wrong is not a choice.
* **`g4_ecs_world`'s `World`, split 2/6 at a modelled 24, ran at 1.042×.** `World` is a **singleton** —
  one instance, five `List` fields and an `Int`. The model prices every type as if there were
  `AIF_N_ASSUMED = 2^20` of them, and `mu_for` reads a cache tier off `N_ASSUMED · size(hot)`: shaving
  a singleton from 48 bytes to 24 crosses a tier boundary and divides its modelled cost by six.

Both are now vetoes in `aif_layout_split_select`, and both are statements that a model **input is
absent** rather than tuning knobs. With them, g3 returns to 0.997× and g4 to 1.016×. The general
lesson is the one LAYOUT §5.2.1 already states in a different key: a model whose inputs are fabricated
constants ranks confidently and is wrong, and §7.2's `argmin` inherits whatever it returns.

### 2.3 · The compiler self-hosted with a split AST, and then stopped splitting it

Worth recording because it was the budgeted risk and it did not bite. Before the vetoes, 6 of the
compiler's 16 types split — `ASTNode` 3/15, `Token` 2/7, `TypeInfo` 3/5, `UmsProjectModel` 2/6,
`UmsAstStatement` 3/9, `UmsLexer` 4/8. That compiler reached a **warm fixpoint, a cold fixpoint from
the committed seed, cold == warm byte-identical on all 88 programs, and 113/113 on the suite** — a
compiler whose own AST is two blocks per node, building itself to a fixed point.

The sequential-traversal veto then removed every one of them: no type in `src/` is walked in container
order, so none has evidence that a split pays. That is the veto working rather than a capability being
lost, and the fixpoint above is the evidence that the transform is sound on the hardest program in the
tree.

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

### 4.1 · Both blockers are gone, and the remaining piece is a search loop

**2026-08-17 (second).** The paragraph above is superseded and kept for the record. The cost model
landed on 2026-08-16 (§5) and the split became emittable on 2026-08-17 (§2.1), so "the top-`k`
candidates ranked by modelled cost" now names a real set and a real function:

* `aif_layout_cand_at_rank(k)` ranks the enumerated candidates by modelled cost, ties broken on the
  candidate index — which is LAYOUT §9.1's total order, because candidates are generated in
  increasing cut order, so the index *is* the split rank.
* `--force-layout=<Type>:<hot>` emits a named candidate instead of the argmin, on `build` as well as
  `aif`. §8 selects by measuring, so the flag has to be able to produce a binary rather than only a
  manifest describing one.

**A candidate is named by its hot-field count, not by its rank**, because a rank stops meaning the
same layout the moment a cost constant is retuned — and §8's whole output is a *durable* manifest
record. `hot_count` is a property of the layout, and it is what `--layout` already prints, so the
`split 8/12` a reader picks off the table is the cut they can ask for. Forcing the full field count
is "no split", which is a candidate like any other and is how a split type is measured against its
own baseline.

**What the force may and may not override.** The five vetoes in `aif_layout_split_select` divide in
two, and the split is now load-bearing rather than descriptive:

| veto | says | forceable |
|---|---|---|
| 1 inline-embedded type, 2 non-trivial SCC, 3 too few fields | the cold block cannot be reached at all | **no** |
| 4 no sequential traversal, 5 owner of an inline struct field | the model had no basis to choose | **yes** |

Vetoes 1–3 are a wild load or a double free and no measurement makes them safe. Vetoes 4 and 5 exist
because a model *input is absent* — and gathering the missing evidence is exactly what §8 does, so a
forced candidate clears them. Veto 5 needed its own channel
(`aif_layout_no_split_unmodelled`) to be separable from veto 1, which arrives from the same discovery
in `aifLayoutVetoInline` and means something entirely different.

**The release path is correct for cuts the model never chose**, which is the precondition §8 needed
and the reason this was verified by running rather than by reading. `test_62_split_release.psm`'s
`Body` at every forced cut:

| forced cut | emitted | printed | released | leaked | violations |
|---|---|---:|---:|---:|---:|
| `Body:4` | `split 4/12` | 4126 | 8 204 | 4 | 0 |
| `Body:7` (argmin) | `split 7/12` | 4126 | 8 204 | 4 | 0 |
| `Body:12` | `unsplit` | 4126 | 4 108 | 4 | 0 |

Every cut prints the exact integer total, so the cold-field redirection is right at each one; the
4 096-object gap between a forced split and a forced unsplit is one cold block per body, and it is
what separates "the force reached codegen" from "the report agreed with itself".

**Still to build for §8 proper:** the search loop (compile top-`k`, run the declared workload on
each, keep the measured winner), and the manifest record it produces — `origin = measured` plus the
measurement's machine identity, which §8 states as SHALL. Note that §8's "at `max` only" is not
expressible today: `--debug` is the only non-`release` level `build` offers, and `max` was
deliberately never added because it would have been byte-identical to `release`. §8 is the first
thing that would give it content.

---

## 5 · The cost model is ported, and it could not have ranked the cut it was ported for

**2026-08-16.** LAYOUT §5's cost model now exists in the compiler
(`runtime/aif_support.c`, `prismio aif <src> --layout`). It was **reported and not acted on** when it
landed — the ranking printed and codegen emitted the unsplit record for every type, because a split
object is two allocations and the release path was not built. **Acted on as of 2026-08-17** (§2.1);
`--layout`'s last column now says which candidate the binary contains.

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

  **Still true after 2026-08-17, and now it is the top item.** The split is emitted, so §8's
  "compile the top-`k` candidates and run the workload on each" needs only a way to override the
  argmin — `aif_layout_split_select` takes one candidate index today. §2.2 is the argument for
  building it: the model picked two layouts the measurement rejected, and the vetoes that removed
  them were written from two measured regressions rather than from a search.
- **The cut itself** is chosen, printed, and as of 2026-08-17 emitted (§2.1).

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

## 7 · `tools/ir_snapshot.py` reports a false difference when anything else compiles the same tree

**2026-08-17 (second), found while verifying the forced-candidate change and not by looking for it.**
The IR differential is this project's primary behaviour-preserving check — CODE_STYLE makes it the
definition of a safe change — and it has a concurrency hole that produces a **layout** difference,
silently, with no diagnostic.

The symptom was a cold-vs-warm comparison reporting exactly one differing program,
`tests/test_55_workload_profile.ll`, with `%Cell.0`'s fields 2/4/5 permuted across 26 `getelementptr`
lines. Run sequentially the same comparison is byte-identical on all 89. All six compiler generations
involved produce identical `test_55` IR when asked one at a time.

**The mechanism.** Every temp path in `runtime/build_driver.c` is qualified with the pid —
`compiler_temp_ir_path`, `compiler_temp_obj_path`, `compiler_temp_source_dir` all stamp
`PRISMIO_GETPID()` into the name — *except* the three the workload runner uses:

```
compiler_temp_path_for(sourcePath, "workload.ll" | "workload.exe" | "profile.txt")
```

So two concurrent compiles of the *same source* share one `profile.txt`. `runWorkloadProfile` deletes
it up front (deliberately, so a stale profile cannot be read as this build's), then the driver writes
it and the compiler reads it back — and a second process anywhere in that window makes the read return
someone else's file, a partial file, or nothing. A profile that fails to load falls back to the static
estimate and warns (W2); a profile that loads *someone else's content* does neither, and the field
placement order it produces is different.

Reproduced deterministically: racing `prismio aif <src> --layout` against
`prismio build <src>` on `test_55`, 8 rounds, **1 diverged** with the same `%Cell.0` permutation. Six
concurrent builds with identical flags do *not* diverge, which is why this hid — the racing processes
have to be writing different profile content for the corruption to be visible.

**Not fixed here, because the pid omission is deliberate and documented.** The comment above
`compiler_temp_path_for` says the profile is the one build temporary a user may want to keep and check
in beside the manifest (LAYOUT §2.2), and a pid in the name would make it unpredictable. That is a
real constraint and trading against it is a design decision, not a patch. The shape of a fix that
keeps both properties: have the build read the profile from a pid-qualified path it wrote itself, and
publish the predictable copy afterwards — whoever wins that copy has written a complete, valid profile
for the same program, so the predictable artifact survives and the build's own decision stops
depending on another process.

~~**Until it is fixed: run `ir_snapshot.py` alone.**~~

### 7.1 Fixed, 2026-08-17 (compile time)

The shape of the fix above is what was built. All three paths are pid-qualified now
(`compiler_temp_private_path`), so a build writes and reads its own driver IR, its own driver
executable and its own profile; the predictable path LAYOUT §2.2 wants is **published** to
afterwards by `compiler_publish_file`, through a temporary beside it and a rename, so a concurrent
reader of the artifact sees the old file or the new one and never half of one. Nothing reads the
predictable copy. It only has to exist.

Measured with the reproduction above, `test_55`, `aif --layout` racing `build`:

| | rounds | diverged |
|---|---|---|
| before | 30 | **2** |
| after | 90 | **0** |

The private profile is deleted by each of the three consumers of the path `runWorkloadProfile`
returns — it carries this process's pid, so no later build would ever clean it up. Verified by
listing `tests/` afterwards: the two *published* profiles are there and no pid-named file is.

`ir_snapshot.py` can be run concurrently again. The rest of §7 is kept because the mechanism is
worth reading: it is the clearest example in this tree of a check that silently reports a false
difference, and the reason it hid for so long is that the racing writers have to disagree about the
content before the corruption is visible.

---

## What to do with this

1. ~~**Hot/cold split**~~ — done 2026-08-17, §2.1 above. The cut is chosen by the model (§5), emitted
   with a real release path, and now also **forceable** (§4.1). Its headline 0.87× is still
   unresolved on the corpus and wants a quiet host.
2. ~~**Port LAYOUT §5's cost model**~~ — done, §5 above.
3. ~~**§8's forced candidate**~~ — done 2026-08-17 (second), §4.1. What remains of §8 is the search
   loop and the `origin = measured` manifest record.
4. **Handles.** Costed at 337 + 190 sites in `HANDOFF.md`. Worth 0.35× on g1's shape, and nothing
   else in this document gets near it.
5. **The §2.1/W4 conflict** should be resolved in the specification before anyone writes the packing
   transform, not during.
6. **§7's profile race**, whenever the differential's trustworthiness is worth a session.
