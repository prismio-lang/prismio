# AIF Evidence

**What is measured, what is projected, and what would falsify the model.**

Keeping those apart matters: the specification carries figures inherited from revision 1.0 that were
produced from a cost model *before any implementation existed*. They are still marked PROJECTED
because nothing has measured them.

## Measured

| Document | Establishes |
|---|---|
| [RESULTS-L0-tiers.md](RESULTS-L0-tiers.md) | Tier distribution over six programs. **100% T0–T2 with affine collections**; the entire residue traces to one language decision. Also: FFI defaults worth 33 points; handles appear to eliminate T3. |
| [RESULTS-L1-layout.md](RESULTS-L1-layout.md) | The static access profile is **exact**, and the cost model **discriminates** — SoA for sequential traversals, AoS for random, within the same loop nest. Also found a defect where the cost total could go negative. |
| [RESULTS-L2-boundary.md](RESULTS-L2-boundary.md) | Sealing a module costs **25 points**, bounded to values that actually cross, and is mostly recoverable with published contracts. |
| [RESULTS-M4-slices.md](RESULTS-M4-slices.md) | `Slice<T>` implements SPEC 8.4's handle/offset/length view, with checked nested access, explicit overlapping mutation, growth safety, generic use, and E-VIEW lifetime propagation. Existing non-Slice IR stays unchanged. |
| [RESULTS-M4-dataview-a.md](RESULTS-M4-dataview-a.md) | `DataView<T>` names an explicit consuming AoS↔SoA boundary and emits real target-layout-aware columns for flat structs. The standing corpus stays flat; the isolated conversion costs 38.0 ns/row. |
| [RESULTS-M4-dataview-b.md](RESULTS-M4-dataview-b.md) | Checked handle/index element descriptors project real columns without raw interior pointers. The standard corpus stays flat; a selected-column SoA scan is 9.7% faster than its AoS control. |
| [RESULTS-M4-dataview-c.md](RESULTS-M4-dataview-c.md) | Mutable scalar and nested fields survive the consuming SoA→AoS round trip. Natural DataView is 77.9% faster than Prismio AoS and within 8% of hand-tuned Rust; a separately labelled hand-tuned Prismio arm reaches hot-loop parity with tuned Rust. |
| [RESULTS-M4-generic-layout.md](RESULTS-M4-generic-layout.md) | Generic templates become concrete AST clones before layout selection. One six-clone gate proves flat instantiations use inline List operations while pointer-bearing instantiations remain boxed; the no-code-change A/A control is 0.997×. |
| [RESULTS-M5-allocator.md](RESULTS-M5-allocator.md) | Direct mimalloc and rpmalloc move generated, runtime, verifier, and curated allocation seams together. Neither beats system malloc: mimalloc is 1.021× loop / 1.242× RSS; rpmalloc is 1.003× / 1.627×. Both dependencies were rejected. |
| [RESULTS-boxed-replacement.md](RESULTS-boxed-replacement.md) | Compiler-enforced exclusive boxed List replacement reclaims the displaced typed object: 4/4 released instead of 3/4, with observed and inline cases rejected. Suite 169/169; milestone 1.002×. |
| [RESULTS-concurrency.md](RESULTS-concurrency.md) | The corpus gets its concurrent program. Prismio is **0.89× idiomatic Rust** on loop time with 0.13× the allocations, because a proved join keeps the spawn argument on the stack; hand-tuned Rust's thread pool is still 1.45× faster. Found two task-model leaks — the handle leak is fixed, the callee-allocated argument is open. |
| [RESULTS-int-width.md](RESULTS-int-width.md) | `Int` stays signed 32-bit, decided by measurement rather than inheritance. Index width is worth **zero** on both targets and making overflow UB is worth less than zero (1.005–1.014×); 64-bit fields cost **1.330×** in Prismio and 1.76–2.15× in C. |
| [RESULTS-string-migration.md](RESULTS-string-migration.md) | The C string layer is gone: 1,093 call sites in `src/` moved to native `std.string`, twelve C functions deleted. Parse+sema **0.843×**, emitted IR byte-identical on all 94 programs. Found that ownership does not survive a second return. |
| [RESULTS-cold-compile.md](RESULTS-cold-compile.md) | A cold build compiled `lang_runtime.c` twice. Retaining the curated bitcode and lowering the runtime object from it with the backend alone takes cold builds to 0.804–0.818× with cached paths unmoved. Codegen-neutral: linked executables are byte-identical. |

All three are **static** distribution. `D_dynamic` — the share of *executed* allocations, which is
what actually predicts performance — needs an instrumented run and therefore codegen.

## Projected, not measured

[BENCHMARKS.md](BENCHMARKS.md) §4 carries revision 1.0's speed figures as **hypotheses with kill
criteria**. None has been tested. The startup row was withdrawn in 1.2 once the reasoning behind it
turned out to rest on a misdiagnosis.

[COMPARISON.md](COMPARISON.md) is the C++ / Rust / Swift suite: eight programs, fairness rules,
predicted results *and predicted losses*. **Zero ports are written, and correctly so** — today a
Prismio benchmark would measure the old malloc path and say nothing about AIF. It unblocks when
codegen does.

## Judgement

[EVALUATION.md](EVALUATION.md) assesses AIF as a general-purpose memory model against the measured
evidence, and disagrees with the specification in three places. Its central finding:

> **The cheap half of AIF delivered all of the measured tier benefit. The expensive half — contexts,
> monomorphization, layout search, the collector — added nothing to it.**

## Before quoting any number

- Static, not dynamic. One T3 site in a hot loop outweighs a thousand cheap ones.
- The prototype's approximations are conservative, so these are **floors**, not estimates.
- Six programs, none with closures or concurrency, is a narrow base.
- **No runtime performance number exists.** Not one.
