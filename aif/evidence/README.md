# AIF Evidence

**What is measured, what is projected, and what would falsify the model.**

Keeping those apart matters: the specification carries figures inherited from revision 1.0 that were
produced from a cost model *before any implementation existed*. They are still marked PROJECTED
because nothing has measured them.

## Measured


> **A note on citations to `TODO.md` and `V0_1_FEATURES.md`.** The files below are
> dated records, kept as written. Several cite the working measurement log
> (`TODO.md`) and the v0.1 language plan (`V0_1_FEATURES.md`), both of which were
> removed at the 0.1.0 release — they were session scaffolding, and what survived
> them is here, in `KNOWN_ISSUES.md`, and in `git log`, whose commit messages carry
> their own evidence. A citation to either is a pointer into history, not a broken
> link to something that should exist.

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
| [RESULTS-passthrough-escape.md](RESULTS-passthrough-escape.md) | A binding that escaped through a callee's **return** was freed under its caller — a **use-after-free**, not a leak, and `--verify` reports 0 violations while it segfaults. `aif_fn_may_return_param` is the missing fact; the guard is driven from the `return`, not the argument. IR byte-identical on 127 of 128 programs. |
| [RESULTS-owned-temporary-argument.md](RESULTS-owned-temporary-argument.md) | An owned call result consumed directly as an argument now has an owner: released after the enclosing call returns, because a Prismio parameter is a borrow. **92/52/40 → 92/92/0**, five other fixtures improved, none regressed, **86 programs at 0 violations**. The retention guard this was thought to need does not exist — sema already rejects it. |
| [RESULTS-overflow-checks.md](RESULTS-overflow-checks.md) | `--overflow-checks`, RFC 0560's check-in-debug model, off by default and byte-identical IR when off. **The recorded premise did not survive**: the `llvm.sadd.with.overflow` lowering is *not* cheaper than a sanitizer (both ~5.4x-6.0x) because the branch defeats vectorization -- and on the corpus it is **1.00x-1.12x**, not 4x. Found a parser defect that gave every `BINARY_EXPR` the next line's position. |
| [RESULTS-enum-zero-value.md](RESULTS-enum-zero-value.md) | A payload-free enum variant filled its unused *pointer* slots with `malloc`'d nodes nothing ever wrote to. SIGSEGV on Linux, `STATUS_HEAP_CORRUPTION` on Windows, silent on macOS — reproduced here only under ASan. Also **1.82× on g8_tree_rebuild**, because half its allocations were those fillers. |
| [RESULTS-curate-list-get-inline.md](RESULTS-curate-list-get-inline.md) | The accessor codegen actually emits, `list_get_inline`, was never in the curated set — a real `bl` per element access for a whole milestone. **Corpus median 0.861×**; the standing against idiomatic Rust goes **0.90×–3.09× → 0.92×–1.80×**. Found by disassembly, against a record that blamed representation. |
| [RESULTS-owned-return-depth2.md](RESULTS-owned-return-depth2.md) | Ownership now survives a second return: **12/7/5 → 12/12/0**. Predicted to need a fixed point and did not — returning a value already implies not dropping it, so only the parameter-passthrough hazard needed asking. Freed `test_72` to migrate to native `std.string` at last. |
| [RESULTS-M6-struct-path-tbaa.md](RESULTS-M6-struct-path-tbaa.md) | Ordinary struct fields carry clang-shaped paths from the LLVM record's real target offsets, including reordered and split hot/cold layouts. g4 **0.963×**, g6 **0.993×** — and the shorter code it produced on g2 was **1.68× slower**. Byte-patching the merged 128-bit store into the *old* binary at unchanged addresses reproduced all of it: the merge is a **0.76× win** where the optimiser sees the destination and a **2.74× loss** against `list_push_slot`. Literal initialisers now decline the tag; every other program is unchanged. |
| [RESULTS-v01-release-candidate.md](RESULTS-v01-release-candidate.md) | The complete v0.1 gate, reproducible as `tools/release_gate.sh`: fourteen checks, suite 202/202, differential 19/19, corpus 30/30 run, ASan and TSan clean. Corpus median **1.001×**. **g5 is demonstrated unmeasurable** — an A/A of one binary against itself reads **1.266× REGRESSED** — which retires three sessions of arguing about its clock. |
| [RESULTS-v01-channels.md](RESULTS-v01-channels.md) | v0.1's blocking typed `Channel<T>` — seven builtins, four rules, no executor. g9 gets the hand-tuned arm that was **not writable** before: **1.15× against hand-tuned Rust**, replacing a 1.45× that compared unlike arms. Three model changes it forced, each found by a failing check, and a **data race in `--verify` itself** that made its own counts irreproducible. |
| [RESULTS-loop-unswitch.md](RESULTS-loop-unswitch.md) | LLVM loop versioning moves the flat/boxed List choice out of hot loops without deleting the sound fallback. Corpus median **0.999x**; g4 improves **0.889x**, reproduced at **0.857x** in the five-arm run. Records why the remaining tuned-Rust gaps divide into representation dispatch, program transformations, and runtime algorithms. |
| [RESULTS-flat-list-view.md](RESULTS-flat-list-view.md) | Codegen keeps the element stride it already computed: `list_get` on a flat element type emits its own GEP under an `elem_size == stride` guard whose false arm is `list_get_inline`. g4 **0.852x against the pre-unswitch compiler**, corpus median **0.986x**. Prices the cost honestly — g2/g6 pay +58% compile time and +34% binary — and records why a `select` beat the more faithful branch, and why the A/A floor and mnemonic diff overturned a first run that called this a regression. |
| [RESULTS-flat-list-loop-guard.md](RESULTS-flat-list-loop-guard.md) | One conjunctive guard per loop instead of one test per site, which repairs a **46% regression on hand-tuned g4** that the release gate could not see because it builds only the natural arm. g4 **0.941x**, g6 **0.933x**, tuned g4 restored to 20.486ms and now beating idiomatic Rust. Records the exponential AST walk (90s single-file compile) and why a `List` in the compiler becomes an `rc_alloc`. |
| [RESULTS-g9-channel-topology.md](RESULTS-g9-channel-topology.md) | **Negative result.** The handoff attributes tuned g9's remaining gap to MPMC channels used where SPSC is provable. The topology claim is right and the attribution is not: a bounded-spin probe moved it 0.995x, messages are nine allocations a frame, and the mutex it would remove is uncontended. The 4.7us/frame is unattributed; three candidates are listed. |
| [RESULTS-inline-push-rejected.md](RESULTS-inline-push-rejected.md) | **Rejected.** Emitting the flat push inline removes `bl _list_push_slot` from g2's loop and is 0.97x there — and **1.275x on g6**, whose `plan_orders` builds a fresh short-lived list per call so every push is a growth. Gating on loop depth does not separate the two; the distinguishing fact is pushes-per-list, which is a profile fact. |
| [RESULTS-lazy-list-new.md](RESULTS-lazy-list-new.md) | `list_new` allocates nothing until the first push, matching Rust's `RawVec::NEW`; it used to hand back a pointer block the inline stamp immediately freed and replaced. **Corpus median 1.000x — kept for the waste it removes, not for speed.** Records an A/A floor of 0.816-1.029x on this host and a seven-run median that reported noise as a 3.2% win. |
| [RESULTS-list-header-hoist.md](RESULTS-list-header-hoist.md) | `list_get` loads `data` only on the in-range path, so LICM cannot hoist it and g5's loop reloads three bases per element. Reading it early works and costs more than it saves (g2_tuned 1.021x, g4_tuned 1.029x) — reverted; the single unsigned bounds compare is kept. **g5_tuned's A/A floor is 0.942x**, which is what disqualified three apparent wins. |
| [RESULTS-spawn-owned-argument.md](RESULTS-spawn-owned-argument.md) | `spawn f(g(x))` gave the owned temporary an owner: spilled to a slot and dropped at the scope exit, on the same E-SPAWN-J proof the task handle uses. The discriminator moves **107/27/80 to 107/107/0** with identical checksums. Zero changed functions in all seven benchmark programs, which is why no timing was run. |
| [RESULTS-extern-alias-escape.md](RESULTS-extern-alias-escape.md) | Closes the last unsoundness in KNOWN_ISSUES: an `extern` declared `alias` that returns its argument had the argument freed at the scope exit. Records two refuted causes (the union already existed; the escape already fired) and the three controls that located the real one — a syntactic guard that asked only `aif_fn_may_return_param`, which abstains on externs. **14 of 14 programs byte-identical**, so no timing claim is made. |
| [RESULTS-pointer-return-temporary.md](RESULTS-pointer-return-temporary.md) | The argument-position release was withheld whenever the enclosing call returned a pointer or struct, leaking **100 of 100** where the result provably could not alias the argument. Replaces the return-kind stand-in with `fn_may_return_view_of_param`, the fact it was approximating. 14 of 14 programs byte-identical. |
| [RESULTS-recursive-payload-leak.md](RESULTS-recursive-payload-leak.md) | A self-recursive producer collapsed root and child roles onto one allocation site, so the generated recursive release was never called. Distinct-function depth was clean. The fix moves g8 from 2 to 4,096 releases and isolates the remaining residue as reuse rather than ownership transfer. |
| [RESULTS-scalar-list-storage.md](RESULTS-scalar-list-storage.md) | Scalar list elements use their native width. The first implementation regressed a 20M-read loop 2.31x; resolving flat versus boxed inside `ir_list_flat_scalar_elem` restores vectorisation and takes the discriminator to **0.346x**, with write and sieve controls flat. |
| [RESULTS-M2-reuse-token.md](RESULTS-M2-reuse-token.md) | A proved one-owner `sink` match can feed a same-tag constructor without allocating. g8 reaches **2,049 / 2,049 / 0**, p50 improves **3.66x**, workload allocator calls fall **5.44x**, and a shared-container guard proves the fallback remains semantic. |
| [RESULTS-curate-scalar-write.md](RESULTS-curate-scalar-write.md) | Scalar set and push cross the curated boundary through an outlined cold path. The 20M set loop drops **18.929 ms to 7.721 ms** and sieve drops **6.849 ms to 3.505 ms**, with the read control flat. |
| [RESULTS-recursive-release-depth.md](RESULTS-recursive-release-depth.md) | A generated release loops on its last direct self field. A 500,000-link chain moves from SIGSEGV after output to **500,001 / 500,001 / 0**, while binary trees preserve reverse-order recursion for the non-tail branch. |

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
