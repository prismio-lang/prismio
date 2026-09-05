# The loop range guard: one precondition per loop, and both checks are gone

**Status: GREEN, 2026-09-05.** Compiler fixpoint `6fdaedc`, LLVM 22.1.8 on Apple
Silicon. Suite **286/286** (new `test_119_loop_range_guard.psm`), lint 405 files,
`prismio lists` agree, AIF differential unchanged from baseline, corpus **0
leaked / 0 violations** on 7/7, seed bootstrap green. Every benchmark checksum
unchanged, and **no benchmark regressed**.

**`knapsack` is 1.05x of C++ and 0.355x of Rust** -- from 3.49x and 1.17x before
this work. It is now twice as fast as Rust on this workload.

## 1 · What was built

`RESULTS-bounds-check-ceiling.md` priced this design and every alternative.
This is that design, in two slices.

`generateLoopRangeGuards` extends the loop's preheader `i1` from a representation
guard to a representation-**and-range** guard. For a `while` loop whose condition
is `V op B`, whose body updates `V` exactly once as its last statement, and every
one of whose guarded accesses indexes `V`, `V + E` or `V - E`, it folds
`0 <= lowest index && highest index < len` into that one `i1`. The true version
then emits the access with **no bounds check** -- `check_bounds` on
`ir_list_flat_scalar_elem` for the read, and the new `ir_list_flat_scalar_set`
for the write.

The false version is untouched, so **`list_get` and `list_set` stay total**.
Nothing here can make an out-of-range access do anything but what it does today;
it can only decide which of two loops runs. That is HotSpot's loop predication
with a versioned slow loop standing in for deoptimisation.

## 2 · What it measured

31 alternating samples, in-process `elapsed_ns`. A is the state before this work
(`flatSetScalarStride` only); B is both slices.

| benchmark | min B/A | p50 B/A |
|---|---:|---:|
| **knapsack** | **0.565** | **0.522** |
| mergesort | 0.927 | 0.919 |
| ecs_component_update | 0.914 | 0.905 |
| allocation_mutation | 0.929 | 0.941 |
| large_buffer_copy | 0.974 | 0.994 |
| tokenization | 0.954 | 0.998 |

**Nothing regressed.** All 34 benchmarks swept, 13 of 53 `bench*` functions
changed, every checksum equal.

Cross-language on knapsack, 21 alternating samples:

| | min ns | p50 ns | before all of this | now |
|---|---:|---:|---:|---:|
| cpp | 136,375 | 144,792 | 3.49x | **1.42x** |
| rust | 388,125 | 419,208 | 1.17x | **0.495x** |

The write slice alone was worth **0.753 min / 0.685 p50** on knapsack, four times
what the C model predicted for it (§4), and it is what removed the read slice's
one regression: `large_buffer_copy` went 1.062x -> 0.974x.

## 3 · The bug that made a correct analysis measure 1.29x slower

The first version widened the range by one step so the update could sit anywhere
in the body. On knapsack that makes the lower bound of `at - weight` equal
`weight - 1 - weight = -1`, so the conjunct `>= 0` is **false at run time,
always**. The guard never fired and the loop paid for versioning it never used:
1.29x slower, with correct output and correct-looking IR.

Requiring the update to be the body's last statement makes the range exact and
the same code measures 0.739x. `test_119` passes under both, because it tests
totality rather than firing. **Only the benchmark distinguishes a guard that
fires from one that cannot.**

## 4 · Two predictions from the C model, and how they held

The ceiling study's ranking was right and its magnitudes were not.

- **It said the `(base,len)` view was worth nothing, three separate ways** --
  1.75x against 1.72x, 1.05x against 1.01x, and 1.10x against 1.10x for the
  header hoist that TBAA would buy on top of the shipped read slice. That held:
  the hoist was not built, and the reload is still there and still free.
- **It said the unchecked write was worth ~6%.** Measured on the real benchmark
  it is worth **25-32%**. The model's write arm shares a loop with reads whose
  addresses are already computed; the real one had a whole guarded call and its
  own header reload to lose.

So: trust the model for *which* lever, not for *how much*.

## 5 · What was rejected

`key_value_update` read 1.042 and `line_processing` 1.022 -- neither is among the
13 changed functions, so both are the layout effect this suite produces on
byte-identical code. **Run the per-symbol mnemonic diff before reading any number
here.** In this sweep it turned "two regressions and several wins" into "no
regressions at all".

## 6 · Where the remaining gap actually is

Attributed, and it is not bounds checks, header loads or TBAA hoisting.

**C++'s inner loop is vectorised and Prismio's is not** -- 22 NEON ops and five
`smax.4s` against zero, four elements per iteration against one. Rust is scalar
too (0 NEON, one `csel`), which is why Prismio already beats it 2:1 despite Rust
being branchless: Rust pays bounds checks Prismio no longer does.

**The cause is a source-shape difference in the benchmark itself.**

```
C++     best[at] = std::max(best[at], best[at - weight] + value);
Rust    best[at] = best[at].max(best[(at - weight)] + value);
Prismio if (candidate > list_get(best, at)) { list_set(best, at, candidate) }
```

C++ and Rust store **unconditionally**; Prismio stores **conditionally**. An
unconditional store vectorises and a conditional one does not -- and not just
here. Modelled on a raw C array, same machine, same data:

| C variant | min ns | NEON |
|---|---:|---:|
| raw array, `if` | 220,000 | 7 |
| raw array, `max` | **188,000** | **22** |
| RtList shape, unchecked, `if` | 229,000 | 7 |
| RtList shape, unchecked, `max` | **187,000** | **22** |
| RtList shape, `max`, base hoisted | 205,000 | 22 |

Two things fall out. **Prismio's codegen is within ~4% of a raw C array for the
same source shape** (229,000 against 220,000). And the RtList shape with `max`
matches the raw C++ arm exactly (187,000 against 188,000) -- so nothing about
the list representation blocks vectorisation. Hoisting the base is *worse*
again, a fourth measurement saying the same thing.

Confirmed on the real compiler: the same knapsack written with an unconditional
store emits **22 NEON ops** and runs at 0.86x of the conditional form.

## 7 · The bug that hid all of this

`ir_list_flat_scalar_set` originally emitted its store **untagged**, while every
other access this backend emits carries a TBAA leaf. An untagged store may alias
anything -- including the `data` pointer loaded out of the header two
instructions earlier -- so LICM could not hoist that load, the base was re-read
every iteration, and cross-iteration dependence analysis was impossible. The
loop stayed scalar with nothing in the assembly to say why.

One `tag_scalar(st, elem_type)` fixed it. It is worth **0.966 min / 0.957 p50**
on the benchmark by itself, and it is what lets the unconditional form vectorise
at all.

**This also corrects an earlier reading in these files.** "TBAA measured at zero"
was true of *hoisting the base* on a loop whose conditional store could not
vectorise regardless. It was not true of the missing tag, which was a plain bug.

## 8 · What is left

- **If-conversion**: turning `if (v > l[i]) { l[i] = v }` into an unconditional
  store of a select is worth ~1.16x and would close most of what remains. It is
  **not obviously sound**: it introduces a write where the program had none,
  which is a data race under `spawn` and dirties a line the loop only read.
  LLVM declines it for exactly this reason. It would need an escape/threading
  obligation, not just the range guard.
- **The benchmark asymmetry is worth raising on its own terms.** The three
  implementations are meant to be the same program and are not.
- **Loops the analysis declines**: `for`/`loop` forms, an update that is not the
  last statement, a non-literal step, a receiver reached through a field, and any
  index not affine in the induction variable.

## 9 · The benchmark was fixed, and what that is worth on its own

The Prismio arm now writes the DP update as the unconditional store the other
two write (`benchmarks/README.md` records the rule). Checksum `12798` unchanged,
all 34 benchmark checksums unchanged.

**Neither half of this is worth anything without the other**, which is the
result that matters:

| | NEON | knapsack min ns |
|---|---:|---:|
| HEAD compiler + conditional benchmark | 0 | ~477,000 |
| HEAD compiler + **matched** benchmark | **0** | 388,084 |
| this compiler + conditional benchmark | **0** | 181,750 |
| this compiler + **matched** benchmark | **22** | **142,500** |

The session-start compiler does not vectorise the matched benchmark at all. The
benchmark fix alone is worth about 0.81x; the compiler work on the matched
benchmark is worth **0.367x**. Only together do they vectorise.

Final: **1.05x of C++, 0.355x of Rust**, from 3.49x and 1.17x.
