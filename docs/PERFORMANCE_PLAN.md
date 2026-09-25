# Performance: what is open, and how to measure it

The live list of compiler and runtime performance work. It replaces four root
documents that had become handoff records: `PERFORMANCE_HANDOFF.md` (the ten
structural gaps, 2026-08-30), `G5_TUNED_VS_RUST_HANDOFF.md` (2026-08-30),
`MEMORY_OPTIMIZATION_AGENT_SPEC.md` (the MEM-023..040 task board, 2026-09-05) and
the performance half of `MEMORY_ALLOCATION_DEEP_DIVE.md`. They are in `git log`,
and `git show 1e338c0:PERFORMANCE_HANDOFF.md` recovers any of them. The
allocation architecture half is [MEMORY_PLAN.md](MEMORY_PLAN.md).

Every status below was checked against the tree on 2026-09-25, not copied from
the documents it replaces. The benchmarks those documents were written around
(g1 to g9, `five_arm_bench.py`, `milestone_bench.py`) were retired with
`aif/evidence/xlang/` on 2026-09-03. The maintained suite is `benchmarks/`,
run with `python3 benchmarks/run.py`.

## 1 · For 0.1

**Nothing on the performance side blocks 0.1.** Two things belong to the
release anyway:

- [ ] Run `benchmarks/run.py` on the release-candidate compiler and record the
      table in `aif/evidence/`, so the release notes quote a measured position
      and not an older one. The 2026-09-25 run (§2) is the baseline to compare it
      with.
- [x] `PRISMIO_INLINE_ELEMS=0` is deleted (2026-09-25). It was read at run time,
      but the element disposition it changed was fixed at compile time, so four
      tests leaked under it. The `elem_size == stride` guard stays.

## 2 · Current position

Measured 2026-09-25 on x86_64 Linux: `aif/evidence/RESULTS-benchmarks-2026-09-25.md`.
Geometric mean **0.90x of C++ and 0.90x of Rust**, with peak RSS level with
both. The largest gaps on the 2026-09-05 board (`fft`, `mergesort`,
`prime_sieve`, `mandelbrot`, `binary_search`, `graph_bfs`, `convolution`) are
now at or under parity.

**Slowest against C++ now:**

| Workload | vs C++ | vs Rust | First question |
|---|---:|---:|---|
| `edit_distance` | 2.18x | 1.00x | Rust matches us and C++ does not. Is the C++ arm a different program? Diff the three arms before touching the compiler. |
| `base64_codec` | 1.62x | 1.59x | byte-at-a-time table lookups: look at the loop against the C++ loop |
| `quicksort` | 1.38x | 1.28x | the partition loop's bounds checks and swaps |
| `lz4_compress` | 1.28x | 1.23x | match search over bytes |
| `string_search` | 1.27x | 0.75x | as for `edit_distance`: a gap against one reference only |
| `key_value_update` | 1.25x | 0.39x | §3.1: inlining across the map's calls |
| `large_buffer_copy` | 1.14x | 1.02x | the fill phase is page-fault bound (E4) |

Against Rust, `memcpy_mix` (2.01x) and `vector_growth` (1.41x) are the only
other large ratios. Both are at parity with C++.

## 3 · Later

Ordered by what the evidence supports, not by size. Each entry names what would
settle it.

### 3.1 · Compiler levers

| Lever | State | What is known | Settles it |
|---|---|---|---|
| **LLVM instrumentation PGO** (was gap 3, G5's P1) | not started | Unswitching is global and pays code size where the clone does not help (`RESULTS-loop-unswitch.md`). G5's loss was an uninlined render kernel that Rust's `#[inline]` fixed. Keep the LLVM profile separate from AIF's layout profile, since the two have different invalidation rules. | instrument, run the declared workload, merge, rebuild; cache key covers compiler, target, source hash and workload; off by default |
| **Inlining across a Map's calls, and a Map in a frame** | not started | Measured in C: 2.6x from inlining across the map's call boundaries, and 1.74x from SROA when the map lives in a frame (`RESULTS-adaptive-map-hash.md` §2). Internalising every function except `main` was measured, made `key_value_update` worse, and was reverted. | needs hotness (the row above) or a language-level inline contract |
| **Conservative loop fusion** (was gap 5) | not started | Tuned programs win by fusing passes, which layout cannot do. | fuse one adjacent pair: same bounds and step, no exits, no opaque calls, and a dependence proof. Identical checksums and fewer loops in the machine code. |
| **Bufferization / loop-scoped reuse** (gap 5, MEM-039, E3) | not started | Transient loops allocate and free without reusing the buffer. `list_clear`-style reset exists as a library call. The compiler never hoists one. | E3's token form: reuse proved by last-use, not by hoisting the buffer |
| **Region sub-blocks around opaque calls** (was gap 7) | partial | Non-lexical extents shipped (`RESULTS-M3-nonlexical.md`). Caller and callee region polymorphism has not, and an opaque extern in a loop still blocks the whole loop's region. | a probe with a temporary on both sides of an opaque call; only the safe sub-block becomes a region |
| **Joint layout search** (G5's P4) | not started | Layout picks a struct split separately from its container and access path. Forcing structs unsplit was measured and regressed (1.03x to 1.15x). Do not veto splitting globally. | a candidate that is a packed, loop-specific hot view |
| **Packed indirect DataView** (gap 9, G5's P5) | investigation only | `RESULTS-M4-dataview-{a,b,c}.md`. Unconstrained cost models mispredicted, and explicit DataView conversion was the explainable win. | an explicit `soa`/view contract with diagnostics that suggest one |
| **Factored recursive layout** (gap 8) | ownership half done | `RESULTS-recursive-payload-leak.md`, `-recursive-release-depth.md` and enum NPO (`RESULTS-enum-null.md`). The layout itself is untouched. | a recursive traversal/update benchmark first; opt-in or profile-chosen |
| **String copies through `llvm.memcpy`** (MEM-036) | open | `strCopyRangeInto` is still a byte loop. | the byte loop replaced where the ranges cannot overlap, measured on `string_search` and the string benchmarks |
| **Host tuning** (MEM-037) | open | `build_driver.c` passes no `-mcpu`/`-march=native` and no `-fno-math-errno`. `std.math`'s intrinsics already avoid errno for the Float functions. | opt-in only: a default build must run on any machine of its triple |
| **`!invariant.load` on vtables and DataView columns** (MEM-040) | open | `tag_invariant_load` is applied to a list's element size only. On the list *header* it would be unsound, because the header changes (KNOWN_ISSUES). | vtable slots first, which are immutable by construction |
| **Map as a SIMD group table** (MEM-014) | open | Probing and hashing are done (`RESULTS-map-probing-wide-hash.md`, `-map-update.md`, `-adaptive-map-hash.md`), and so is removal (2026-09-25). A group-probe table is what remains. | beats the current map on all four map benchmarks, with no peak-memory regression beyond what is recorded |
| **Channel specialization** (was gap 4, MEM-016) | see [CHANNELS_PLAN.md](CHANNELS_PLAN.md) | Topology-specialised SPSC was a **negative result** (`RESULTS-g9-channel-topology.md`). What costs is boxing each message. | the typed in-place channel, CHANNELS_PLAN Phase 1 |

### 3.2 · Platform, not performance

These were listed as "other product gaps" in the performance handoff. They are
tracked in KNOWN_ISSUES under "Platform" and "Toolchain layout": no export table
for a compiler self-hosted on Windows, no wasm32 runtime archive, and resolved
path dependencies missing from the import search. Its other two entries are
stale. String interpolation shipped (test_136), and so did the iterator protocol
(`std.iter`, `for x in` over a user type).

## 4 · Closed, with evidence

So nobody re-derives these. The evidence file is the record.

| Item | Result | Evidence |
|---|---|---|
| Owner facts at calls, `spawn` and FFI (gap 1) | closed | `RESULTS-spawn-owned-argument.md`, `-extern-alias-escape`, `-passthrough-escape`, `-owned-temporary-argument`, `-pointer-return-temporary`, `-owned-return-depth2` |
| Flat-list view per loop (gap 2) | closed; the run-time switch is deleted | `RESULTS-flat-list-view.md`, `-flat-list-loop-guard`, `-scalar-list-storage`, `-inline-elems-gate` |
| Functional-update reuse (gap 6) | closed | `RESULTS-M2-reuse-token.md` |
| Curated runtime closure (gap 10) | closed | `RESULTS-curate-scalar-write.md` |
| Loop range guard wrap, TBAA audit (MEM-023, 024) | done | `RESULTS-loop-range-monotonicity.md` |
| Container-aware layout veto (MEM-003) | done | `aifLayoutVetoListElements`, `src/aif/layout.psm` |
| Whole-buffer copy (MEM-006) | done | `RESULTS-whole-buffer-copy.md` |
| Enum null-pointer optimisation (MEM-031) | done for boxed recursive binary enums | `RESULTS-enum-null.md` |
| Short strings inline (MEM-032, MEM-010's slot half) | done: German strings ship | RUNTIME.md, `STRINGS.md` |
| Single-threaded cycle-lock bypass (MEM-033) | done, worth ~0 | `RESULTS-cyc-lock-bypass.md` |
| Stencil range guards (MEM-035) | done: convolution 0.707x | `RESULTS-stencil-condition.md` |
| Push predication (E1), scoped alias metadata (E5) | done | `RESULTS-push-predication.md`, `-scoped-alias-metadata.md` |
| Map probing, update, hash, removal (MEM-034) | done | `RESULTS-map-probing-wide-hash.md`, `-map-update.md`, `-map-probe-loop-guard.md`, `-adaptive-map-hash.md` |
| Iterative recursive release (MEM-029) | landed | `RESULTS-recursive-release-depth.md` |
| Delegating `return g(a, b)` leak (MEM-028) | fixed: 101/101/0 | re-measured 2026-09-25 |
| Benchmark CLI leaks (MEM-038) | fixed: fibonacci 5/5/0 under `--verify` | re-measured 2026-09-25 |

**Refuted. Do not rebuild these without new evidence.**

- Curating `list_push_slot` (MEM-011) works and is a net loss
  (`RESULTS-inline-push-rejected.md`). Push predication later got what it was
  after.
- AIF-discharged store speculation (E2). Its acceptance test already passes: the
  1.16x belonged to a benchmark arm that wrote a different program.
- Channel endpoint topology (gap 4). `RESULTS-g9-channel-topology.md`.
- Forcing structs unsplit so lists can inline them. Measured 1.03x to 1.15x
  slower.
- Speculatively loading every list header in the C runtime. It helped one loop
  and regressed others.
- Internalising every function except `main`. Binaries got smaller and
  `key_value_update` got slower.
- A flat guard on `loop`/`for` to save the probe loads. It is a net loss,
  because the guard is paid on every loop entry and a probe iterates once.

`docs/ARCHITECTURE-DIRECTION.md` §7 has the older dead ends.

## 5 · How this work is done

These rules came out of the replaced handoffs. Each one exists because breaking
it cost a session.

**Read before you measure.** Read what Prismio does (the runtime function, the
lowering, and the AIF fact: ask `aif --summary`, `--layout`, `--why`). Read what
Rust or C++ does for the same program, with the two loop bodies side by side.
Look for the mechanism in the literature. *Then* form one hypothesis with a
mechanism, and test that. A probe confirms a mechanism you can already name.

**Tuned against tuned is the ceiling.** When both arms have the best algorithm,
what is left is the compiler. A change that helps a natural arm and leaves the
tuned one behind has not moved the ceiling. Never edit a natural arm to claim a
compiler win. And the three arms of a benchmark must be the same program, not
just give the same checksum (`benchmarks/README.md`).

**A changed IR is not a result.** Look at the machine code
(`tools/fn_mnemonic_diff.py`), then run a balanced A/B. Phase-time a benchmark
before choosing a lever (E4): `large_buffer_copy`'s fill phase is page-fault
bound, which no instruction-level change can reach.

**Correctness before timing.** A speedup does not prove ownership. The verifier,
the differential, sanitizers and a negative test do. Reject a corpus median
regression beyond 1.03x unless the win is large and was accepted explicitly.

**Traps that give a confident wrong answer:**

1. **The suite tests `$PRISMIO`, and otherwise whatever `prismio` is on PATH.**
   Always set `PRISMIO=<your build>`. The build must be a packaged toolchain
   (`tools/package.py`), not a bare generation.
2. **In-tree programs resolve `std` from the repository, not the package.** So
   a change to `std/` is tested by the tree it sits in, and a before/after
   comparison of std needs two trees, not two packages.
3. **The fixpoint check needs the same output basename.** Two generations
   written to different `-o` paths differ in the embedded path. Build both to
   the same name in different directories, then `cmp` the IR.
4. **Editing `runtime/` during a suite run** changes the runtime-source hash
   partway through the run. Use a worktree for the baseline.
5. **One timing is not a result.** The old g5 showed an A/A difference of
   1.27x. Use repeated medians, interleave the arms, and keep the machine's
   thermal and toolchain state fixed.
6. **Inlining is fragile.** A few extra instructions in `mapProbe` stopped
   `mapSet` being inlined (key_value_update 10.7 to 14.8 ms, 2026-09-25). When
   a library change moves a benchmark, check what inlined before believing the
   algorithm moved it.

**The loop for any change to `src/`:** two generations to a byte-identical
fixpoint, the suite, `tools/aif_differential.py`, byte-identical IR for every
program in `tests/` and `aif/corpus/` if the change is meant to preserve
behaviour, and then the benchmark. Record commands, compiler, LLVM version,
medians and checksums in a new `aif/evidence/RESULTS-*.md`.
