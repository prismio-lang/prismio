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

## What to do with this

1. **Hot/cold split.** 0.87× measured, emittable today, no missing mechanism. The T3 interaction is
   the whole risk and it is nameable: give a split type a generated release and route every free
   through it.
2. **Port LAYOUT §5's cost model** from the prototype. It is the precondition for §7.2 as written, for
   §8, and for ranking hot/cold cuts by anything better than "the frequency ranks say so".
3. **Handles.** Costed at 337 + 190 sites in `HANDOFF.md`. Worth 0.35× on g1's shape, and nothing
   else in this document gets near it.
4. **The §2.1/W4 conflict** should be resolved in the specification before anyone writes the packing
   transform, not during.
