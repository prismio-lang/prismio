# AIF — Level 0 Results

> ## ⚠ Correction pending review — 2026-08-05
>
> Porting the engine into the compiler put a second implementation on this data, and **the SELF row
> of §1 does not reproduce.** The G1–G5 rows do, exactly. Both implementations agree with each
> other, so this is an error in what was written down, not in either tool.
>
> Reproduce, against the source tree as it stood when this document was written — commit `a4d3b5e`,
> the last one before the engine landed (`git archive a4d3b5e src | tar -x -C /tmp/oldtree`):
>
> ```
> prismio aif /tmp/oldtree/src/main.psm --summary
> prismio aif /tmp/oldtree/src/main.psm --summary --owned-collections
> ```
>
> | SELF, 200 functions | recorded here | measured, both tools |
> |---|---:|---:|
> | today's language, T0–T2 | 75.7% | **24.3%** |
> | affine collections, T0–T2 | 100% | **28.4%** |
>
> **75.7% is the T3 share, not the T0–T2 share** — 24.3% + 75.7% = 100%, and the tool prints them
> on adjacent rows. §3's "reported 75.7% under today's semantics, which looked like a moderate
> result" reads as the same transposition. §5's `borrow` 75.7% vs `retain` 42.8% is the same
> quantity and needs the same check.
>
> **The consequence is larger than the typo.** Affine collections do not take SELF to 100%; they
> move it 4 points. So §2's finding — *the entire T3 residue traces to one language decision* — is
> true of G1–G5 and **false of SELF**, and SELF is the only corpus that is not engine-shaped.
>
> What actually dominates SELF is **undeclared FFI contracts**, not collection affinity. 383 of its
> 552 sites are opaque extern returns, and the compiler's type-punning surface is most of them:
> `ptr_to_node` returns an alias of its argument, but with no contract the analysis must assume the
> return may already be shared and may already outlive the frame, and A-STORE then propagates that
> to everything stored through the resulting node. Declaring `alias` on the four punning externs
> (`ptr_to_node`, `node_to_ptr`, `ptr_to_type`, `type_to_ptr`) and changing nothing else:
>
> | SELF, affine collections | sites | T0–T2 |
> |---|---:|---:|
> | no contracts on the punning externs | 552 | 28.4% |
> | four externs declared `alias` | 243 | **69.5%** |
>
> That is [../implementation/REQUIREMENTS.md](../implementation/REQUIREMENTS.md) item 8 with a
> number on it, and it is a bigger lever on this corpus than item 1. It does not disturb the G1–G5
> results or §2's finding *for engine-shaped code*.
>
> ### Item 8 has since landed — measured, not projected
>
> `extern` declarations now carry FFI §5 contracts, and the four punning externs declare `alias`.
> The compiler's own distribution, measured by both implementations:
>
> | SELF | sites | T0–T2 | opaque returns |
> |---|---:|---:|---:|
> | before contracts | 649 | 27% | 425 |
> | four punning externs declared `alias` | 308 | 58% | 84 |
> | + the verified runtime surface | 302 | **63%** | **45** |
> | …and affine collections | 302 | **85%** | 45 |
>
> **85% clears BENCHMARKS H1's 70% kill criterion with room**, and it takes both changes to get
> there — item 8 alone reaches 63%, item 1 alone reached 31%. The site count halves because an
> aliasing extern no longer manufactures a fresh allocation per call, which was itself a large part
> of the distortion.
>
> Two things the annotation work turned up, both worth having:
>
> - **`ir_get_temp_name` and `ir_get_label_name` `malloc`.** They look exactly like the interned
>   accessors around them and reading the C is the only way to tell. Declaring them `alias` on
>   appearance would have been a wrong contract at the boundary — FFI §1's unsafe-not-slow case —
>   so every contract here was checked against the C rather than inferred from the name.
> - **`alias` cannot express "static despite taking a reference argument".** FFI §5.2 defines
>   `alias` as "borrows from an argument *or* from static storage" and names no index, so the sound
>   reading is the union of the arguments. For `ir_get_var_type(name)`, whose return is a static
>   type key unrelated to `name`, that is conservative but wrong in spirit — those were left
>   undeclared rather than declared misleadingly. An optional `alias(k)` would resolve it and is a
>   change to FFI.md, not to the compiler.
>
> 45 undeclared returns remain, all outside the verified set.
>
> Left as a note rather than an edit: the body below is the record of what was measured on
> 2026-08-01 and the reasoning built on it deserves a deliberate revision, not a patch.

**First measured data. The model's central claim holds, and the entire residue traces to one
language decision.**

Produced by `../prototype/aif.py` over post-sema ASTs dumped by `prismio dump-ast`. No codegen was
changed; the compiler's IR is byte-identical before and after adding the dump command, and the test
suite is 57/57.

Date: 2026-08-01.

**Corpora**

| | Program | Shape |
|---|---|---|
| G1 | `../corpus/g1_particles.psm` | Particle system, 12-field component, narrow update loops |
| G2 | `../corpus/g2_frame_loop.psm` | Per-frame transient draw-command batches |
| G3 | `../corpus/g3_scene_graph.psm` | Index-based transform hierarchy |
| G4 | `../corpus/g4_ecs_world.psm` | ECS world, 5 component arrays, 4 systems |
| G5 | `../corpus/g5_asset_cache.psm` | Engine asset cache — 2000 entities over 20 meshes / 12 materials / 8 textures |
| SELF | `self/src/main.psm` | The Prismio compiler, 13 files, 200 functions |

All five G-programs compile and run under today's compiler.

---

## 1 · Headline

| | today's language | **AIF (affine collections)** |
|---|---:|---:|
| G1 particles | 0.0% | **100%** |
| G2 frame loop | 20.0% | **100%** |
| G3 scene graph | 0.0% | **100%** |
| G4 ECS world | 9.1% | **100%** |
| G5 asset cache | 20.0% | **100%** |
| SELF compiler | 75.7% | **100%** |

*(share of allocation sites at T0–T2 — no runtime bookkeeping of any kind)*

**Zero T3 and zero T4 in every program**, once collections are affine.

BENCHMARKS H1 sets the kill criterion at < 70% and states the claim at ≥ 90%. The claim is met with
room. The approximations are all conservative (§6), so these are floors.

---

## 2 · The finding: one decision accounts for the entire residue

`types.psm` makes **only structs** move-only. Strings, lists and arrays are freely copyable. That
single fact produces every T3 in every program measured, through a two-step chain:

1. A collection reachable from two places is `Shared` (the copy rule fires, because it is copyable).
2. Everything stored in it **inherits that sharing** — A-STORE propagates aliasing through
   reachability.

So one wrong fact at a container poisons every element in it. In an ECS, *everything* lives in a
container, which is why G1/G3/G4 collapse to near-zero under today's semantics.

Make collections affine — which [SPEC.md](../spec/SPEC.md) §11 item 10 already requires, and which
`types.psm`'s own comment anticipates — and the chain never starts. Containers become
`Unique`/`Borrowed`, elements inherit `Borrowed`, and everything lands T2 or better.

> **This is not an optimisation. It is the difference between the model working and not working.**

The current compiler's memory handling is scaffolding, so this is not a criticism of it. It is a
measurement of how much rests on the one property AIF specifies and the scaffolding does not have.

---

## 3 · What the game corpus showed that the compiler could not

Running only SELF would have been misleading in both directions.

- SELF is **string-heavy and struct-light** (5 struct types, 307 string sites). It reported 75.7%
  under today's semantics, which looked like a moderate result and hid the fact that the residue
  was 100% attributable to one cause.
- The G-programs are **container-heavy**, which is what engine code is. They reported 0–20%, which
  looks catastrophic and is equally misleading — it is the same single cause, amplified because
  every value passes through a `List`.

Only running both made the shape legible. Neither corpus alone would have.

---

## 3a · Handles appear to eliminate T3 in engine code

G5 was written for one purpose: to produce a T3 population. It is an asset cache with real sharing
— 2000 entities referencing 20 meshes, 12 materials and 8 textures, roughly 100 references per
asset — plus manual `ref_count` fields, acquire/release, and an eviction pass. Exactly the shape
that reference counting exists for.

**It produced zero T3.**

The reason generalises, and it is worth stating carefully:

> Entities reference assets by **handle** — an index into a uniquely-owned pool — not by pointer.
> The sharing is *semantic* (many entities logically use one mesh) but not *ownership* sharing
> (only the cache owns anything). Handles carry no ownership, so no aliasing fact is ever raised.

This is not a trick to get a good number. It is how engines are written, universally, and for the
same reasons AIF requires handles anyway (SPEC §11 item 5): relocatable, serialisable, stable
across streaming and eviction, cache-friendly.

**Implication:** the expected T3 population in engine and game code may be far smaller than the
model assumes — possibly empty. The tier should stay in the ladder regardless: it costs nothing
when unused, exactly as the cycle collector compiles out when no type is cyclic (CYCLES §2). But
the *design effort* budgeted for T3 and T4 may be misallocated relative to T0/T1/T2.

**The honest limit on this claim:** the non-handle version of G5 — entities holding owning
references to shared assets — **cannot be written in today's Prismio at all** (§4.2). So this shows
that the idiomatic engine pattern does not need T3. It does not show that nothing does. Closures
capturing values, event systems retaining callbacks, and producer/consumer across tasks are all
plausible T3 sources, and none of them is expressible yet either.

---

## 4 · Two spec gaps the run found

### 4.1 `retain_in(k)` is missing from FFI.md's contract vocabulary

[FFI.md](../spec/FFI.md) §5.1 offers `borrow`, `retain`, `consume`, `out`. None fits a container API.

`list_push(list, item)` stores `item` into `list`. It is not `borrow` (the callee keeps it) and it
is not `retain` (which means *escapes globally* — far too coarse, since the element escapes exactly
as far as the container does and no further).

The prototype adds **`retain_in(k)`**: the callee stores this argument into argument `k`, so the
stored value joins that container's escape and aliasing. This is E-STORE/A-STORE applied across a
call boundary.

**This matters more than it looks.** Collections are the most common FFI shape in a systems
language, and without the contract, `list_push` defaults to `borrow` and every element pushed into
a list appears never to escape. That is *optimistic*, i.e. unsound — the first measured example of
FFI §1's warning that a wrong contract is a safety bug rather than a slow program.

**Recommendation:** add `retain_in(param)` to FFI §5.1.

### 4.2 The cycle collector has no program that can exercise it

G3's first draft used the textbook shape — `parent: Node` back-reference plus `children: List<Node>`
— which is a reference cycle by construction and precisely what T4b exists for.

Today's Prismio rejects it twice: there is no null to initialise `parent` with, and
`child.parent = parent` is *"cannot move out of borrowed value"*. **The affine discipline makes the
cycle inexpressible.**

So T4b is currently unreachable in the language — not because programs do not need cycles, but
because the language cannot write one. G3 was rewritten to the index-based hierarchy production
engines actually use, which is acyclic by construction and cache-friendly.

**Consequence:** [CYCLES.md](../spec/CYCLES.md) is specified against a language feature that does not exist.
Its §2 headline — most programs need no collector and the compiler can prove it — held on all five
corpora, but it held trivially. The collector cannot be validated until shared mutable references
exist.

---

## 5 · Secondary measurements

**The FFI default contract is worth 33 points.** FFI §5.4 *argued* for `borrow` over `retain` as the
default for undeclared externs. Measured on SELF: `borrow` 75.7%, `retain` 42.8%. The argument was
right and the margin is much larger than the prose implied.

**String literals are 69% of apparent allocation traffic and are not allocations.** The first run
scored 13.3% because it counted 1,234 string literals as sites. They lower to LLVM globals —
static, immortal, never allocated. Counting them was a modelling error; any implementation will
face the same temptation.

**`3ⁿ` monomorphization blowup did not materialise.** Over 166 functions taking reference
parameters, mean reference-parameter count is **1.48**, so the context space is ~5 per function
before masking. The relevant-parameter mask saves 15%, not the collapse INFERENCE §7.1 claims it
provides — survivability comes from `n` being small, not from the mask.

Two corrections follow: INFERENCE §7.1 oversells the mask, and BENCHMARKS' original H4 criterion
tested the wrong quantity (proportional reduction is meaningless when the base is 1.48; the
absolute body multiplier is what decides code size). Both are corrected.

**Cycles:** zero of five struct types in SELF, and zero in every G-program, lie in a non-trivial SCC
of the type reference graph. `cycles none` — the collector would be compiled out entirely. See §4.2
on why this is weaker evidence than it looks.

---

## 6 · What this does not show

- **Static, not dynamic.** This is `D_static` over abstract values. BENCHMARKS §2.1 requires
  `D_dynamic` — the share of *executed* allocations — and warns they diverge sharply, since one T3
  site in a hot loop outweighs a thousand cheap ones. That needs an instrumented run, which needs
  codegen.
- **The corpus contains no genuinely shared data.** Every G-program is single-ownership: one world,
  one node array, one particle system. Real engines share — materials, textures, mesh data
  referenced by many entities. **The 100% therefore does not test the T3 path at all**, and a
  corpus with shared assets would not reach 100%. This is the most important limitation here.
- **No T1 in the G-programs.** Their allocations escape to the caller (built in one function,
  returned, used in another), so they land T2 rather than T1. Frame-scoped arenas should move G2's
  per-frame batches to T1, but `region` does not exist in the language yet, so this is untested —
  and it is the single biggest remaining upside for a frame-loop workload.
- **No layout, no contexts, no concurrency.** Inference only, `⊤` context throughout, `T` vacuous.
- **Approximations are conservative**: flow-insensitive, object-insensitive fields, struct sizes
  approximated by field count. Each can only raise a tier, never lower it.

---

## 7 · What to do next

1. **Add a shared-asset case to the corpus.** Multiple entities referencing one material or mesh.
   Without it the T3 path is untested and the 100% is over-read. This is the highest-value
   correction to the measurement.
2. **Implement `region` and measure G2.** The frame loop is the canonical T1 case and currently
   lands T2. This is the largest untested upside for the target workload.
3. **Add `retain_in(param)` to FFI §5.1** (§4.1).
4. **Extend the engine to the static access profile** (LAYOUT §2's static half — co-access sets and
   traversal order are statically exact). G1 and G4 were written specifically to make the AoS/SoA
   decision non-trivial; measuring it costs no new language features.
5. **Design shared references**, without which T3, T4 and the entire cycle collector are
   unreachable (§4.2).

## Reproducing

```bash
prismio dump-ast ../corpus/g4_ecs_world.psm > g4.json
python ../prototype/aif.py g4.json                       # today's semantics
python ../prototype/aif.py g4.json --owned-collections   # AIF's semantics
python ../prototype/aif.py self.json --masks             # H4 indicator
python ../prototype/aif.py self.json --ffi retain        # the 42.8% comparison
```
