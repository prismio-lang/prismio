# Session prompt — compiler work, with no list

**This file is the one live prompt.** `NEXT-SESSION.md` is the archive of past ones; when this
session is done, fold a summary of it into that file and rewrite this one for the session after.

Everything below is **compiler work only**. The motivation behind it is a cross-platform app
framework built in Prismio, but no task here is framework work — the framework's runtime,
embedders, host imports and packaging are deliberately outside the compiler.

The rule that decides which side anything falls on:

> **If getting it wrong produces a miscompile, it belongs to the compiler.**
> **If getting it wrong produces a link error or a missing feature, it does not.**

**Last-good: `build/S27b`.** Suite **140/140**, fixpoint `a27.ll == b27.ll`, differential 17/17,
and a fresh seed build matches it. Bootstrapped `S10b → … → S25b → S26b → S27b`; `S26b`, `S25b`,
`S24b`, `S22b`, `S20b`, `S19b`, `S18b`, `S15b`, `S10b` and `E2` remain good behind it. S16/S17 are
the M3.1 session's intermediate generations and are **not** last-good — each leaked on a fixture.

**M3 is finished, its exit gate is green, and the corpus is clean.** The 2026-08-28 session ran in
three passes and everything it opened it also closed. What matters going in:

- **Automatic arena placement reaches both programs it was supposed to.** Plain `g2.psm` —
  no annotation, no source change — **10 285 886 → 82 052 allocations, 0.469×**, frame p99
  12 042 → 2 917 ns. `g6_game.psm` — **50 470 → 3265, 0.599×, 4.31× → 2.58× of idiomatic Rust**.
  The mechanisms: a **non-lexical extent** (the arena opens at the first statement that fills it,
  so a harness's clock calls fall outside it), regime (a) widened from "one call site" to "all call
  sites in one region", and the `@elem` points-to node keyed on the container's full type.
  [`RESULTS-M3-nonlexical.md`](aif/evidence/RESULTS-M3-nonlexical.md),
  [`RESULTS-M3-leaks-and-regime.md`](aif/evidence/RESULTS-M3-leaks-and-regime.md).
- **All seven benchmark programs have a completely clean `--verify` ledger** —
  `allocated == released`, 0 leaked, 0 violations. Two leaks did it, and **both were a missing
  *owner*, not a missing free**: a `String` returned across a call had none, and an inline struct
  field was reported as owning a value it only holds a copy of.
- **Peak RSS fell 0.49×–0.82× across the corpus** as a consequence — g1 1.78, g2 1.94, g3 2.08,
  g4 2.05, g5 1.63, g6 2.23 MB. That is the standing "peak RSS reversed" candidate, and **the cause
  was the leaks**; see M5.2 in TODO for the one measurement still owed.

Corpus median 1.003× on the final gate, **GATE PASSED**.

**Run the test suite alone.** Two concurrent runs corrupt each other: `no_inference` writes the
fixed paths `tests/ni_release.exe` / `tests/ni_debug.exe`, and the toolchain object cache is
shared. A "136/137 flake" and a "132/137 regression" last session were both overlap, and neither
reproduced in isolation.

---

## Read this before looking for something to do

**The candidate list is no longer empty — 2026-08-25 refilled it by measuring.** It *was* empty
after 2026-08-24 took the last five in order. The final cross-language benchmark
([`aif/evidence/RESULTS-final.md`](aif/evidence/RESULTS-final.md), and the HANDOFF entry of the
same date) then produced five items, ranked here by measured prize:

1. ~~**Close the runtime call seam.**~~ **Largely done, 2026-08-26.** M1.0 established why
   `-flto` declines (the backend emits no target attributes; `cost=never: conflicting attributes`)
   and M1.1 shipped the curated `available_externally` module behind
   `PRISMIO_INLINE_RUNTIME=1`. Driver-measured: **corpus median 0.864×**, g5 2.69× → **1.29×** of
   idiomatic Rust, RSS and exe size unmoved, suite 137/137, gate passed.
   **What is left, and why it is still ranked:**
   - **The exit gate is not met.** g3 reads **1.05×** of idiomatic Rust, not < 1.00×. The 0.94×
     that motivated this item came from a hand-built baseline that put g3 at 1.01× before the
     change; the driver puts it at 1.12×. The *worth* reproduced; the baseline did not. **Treat
     "the first Prismio program to beat idiomatic Rust" as unsupported until re-measured.**
   - **M1.1b is done.** The merge is in process (`LLVMLinkModules2` + a three-pass body delete),
     byte-identical to `llvm-extract`'s output, builds with only `clang` on PATH, and the warm
     compile-time cost fell to ~5%. `--verify`, `--target` and the object cache are exercised.
     **The default is still off**, because the portability claim is a macOS PATH test rather than
     a green CI on three platforms — that run is what should gate flipping it.
   - **M1.3 is untouched** — the hot container ops written in Prismio itself, which is what would
     close the remaining 0.05× on g3.
   Evidence: [`RESULTS-M1-lto.md`](aif/evidence/RESULTS-M1-lto.md).

2. ~~**Automatic arena placement does not fire on the corpus.**~~ **DONE, 2026-08-28.** M3.1 made
   placement reach a callee's allocations; M3.2c-ii + M3.2d made the extent a statement range
   rather than a block, which is what the benchmarked `g2.psm` needed — its harness calls
   `clock_gettime_nsec_np` on either side of the work, and an arena that opens after the first and
   closes before the second never has an opaque call inside it. **10 285 886 → 82 052
   allocations, 0.469×, 0 violations, `g2.psm` unedited.** Corpus-wide brackets 2 → 6 → **12**.
   Evidence: [`RESULTS-M3-callerregion.md`](aif/evidence/RESULTS-M3-callerregion.md) and
   [`RESULTS-M3-nonlexical.md`](aif/evidence/RESULTS-M3-nonlexical.md).
   **g6 followed on 2026-08-28** — 50 470 → 3265 allocations, 0.599×. **The note this file used to
   carry about it was wrong**: it said obligation 2 (`br_param=4`), and `--why` says `plan_orders`
   clears every allocation obligation and was refused on its call-site count. `br-param` is about
   `recruit`, whose `Member`s genuinely outlive the tick, and declining those is correct.
   - **Do not edit `g2.psm`.** Still true, and still for the same reason: it is the baseline every
     prior g2 number was measured on, and `milestone_bench` checks its checksums before it times
     anything.
   - **Nothing in the corpus is a plausible-and-absent arena any more**, and every ledger is
     clean. Placement is done as an item; the next allocation work is representation (item 3).

2b. **M2 (reuse analysis) is not the next item, and its premise is wrong as written.** Reuse
   tokens pair a dead value with a same-size constructor *in the same branch*; `match` appears in
   **no corpus program at all** — not g1–g6 and not g7 — so there is nothing to pair anywhere in
   the corpus. (An earlier note here said "g7 only"; that was a grep hitting the *word* in a
   comment.) M2's exit gate asked for a ≥10× allocation drop on g2 and g6 — **M3 delivered 125× on
   g2 and 15× on g6**, by a different mechanism, which is why a gate has to name the mechanism as
   well as the number. **Both halves of M2's gate are now met by something that is not M2.**
   Restate it against g7 before starting, or drop the milestone. Detail in
   [`TODO.md`](TODO.md) § M2.
3. **Inline element storage for `List<T>`** — ranked second at session 3, still unbuilt, still the
   only change projected to move the corpus band (~1.2–1.3× across the board). The representation
   is 9.23× of the g2 gap and 2.51× of the g4 gap against a **1.24–1.27×** compiler. Needs
   views/slices to be expressible, which is why item 1 outranks it despite a similar prize.
4. ~~**Peak RSS reversed.**~~ **Cause found, 2026-08-28, and it was the leaks.** The entry read
   0.84–1.00× → 1.09–1.60× of idiomatic Rust with Rust unmoved, and had already excluded the fixed
   runtime footprint and the hot/cold split. It never said "leak", and it should have: a leak
   scales with **live set rather than churn**, which is the signature this entry recorded verbatim.
   Removing the two of them dropped peak RSS to **0.49×–0.82×** of the previous compiler across the
   whole corpus. **What is left is one measurement**: re-run `RESULTS-final.md`'s own harness so the
   ×-against-Rust figure can be restated. `milestone_bench` is old-vs-new and cannot answer it.
   No bisect is needed and no session-3-era compiler has to be built.
5. **Genuinely-cold compile regressed 19–28%** — 183 → 235 ms (g1), 203 → 241 ms (g6) with
   `PRISMIO_OBJ_CACHE=0`. Hidden in the default path, where the object cache reaches 0.71–0.85× of
   rustc. Affects first builds and uncached CI only.

**The plan, as a checklist with a runnable gate:** [`TODO.md`](TODO.md) — five milestones, each
with its papers, its concepts, its tasks and an exit gate that includes
`tools/milestone_bench.py` (old vs new vs Rust, interleaved) **and a docs-update checklist covering
both this repo and the public site at `../docs/content`.**

**Architecture direction and the supporting literature:**
[`docs/ARCHITECTURE-DIRECTION.md`](docs/ARCHITECTURE-DIRECTION.md) — written 2026-08-25, it ranks
these items against what Perceus, Spegion, ThinLTO, Tofte–Talpin, MLton and the PPAM data-views
work already settled, and records the measured dead ends (`-flto`, chasing the residual, and the
assumption that boxed layout costs indirection — it costs **allocations**, measured 0.86× free).
**One correction in it re-ranks this list:** inline `List<T>` storage is worth having because it
removes *allocations*, not indirection, so reuse analysis (Perceus-style) attacks the same cost
without a language change and should be weighed ahead of it.

---

## What to do next, in the order I would do it

**[`TODO.md`](TODO.md) is the plan and this is the prompt.** Every task below is a checkbox there —
the links say which — and nothing is here that is not. When you finish one, tick it *there* and
re-rank *here*.

Items 2 and 4 are done, and 1, 3 and 5 are what remain. Three of the four things below are cheap and
one is the big one; the order is by *what makes the next number trustworthy*, not by prize.

**A. Re-measure, before building anything.** — [`TODO.md`](TODO.md) § Standing items, first entry.
Three separate figures in this repo are now stale in the same direction and nobody can quote the
compiler's standing honestly until they are refreshed:

- `RESULTS-final.md`'s cross-language matrix is stale for **g2 and g6** (both moved this session)
  and for **peak RSS everywhere** (item 4's cause turned out to be the leaks). Its harness is the
  only thing that produces the ×-against-Rust RSS figure — `milestone_bench` is old-vs-new and
  cannot.
- The **band** quoted throughout as 1.13×–5.89× is roughly **1.09×–3.23×** on the driver's own
  numbers now. Do not propagate either until the harness has run.
- **This is half a session at most**, it needs no design, and every ranking below depends on it.

**B. Flip `PRISMIO_INLINE_RUNTIME` on, or decide not to** — [`TODO.md`](TODO.md) § Standing items,
second entry; item 1's remainder here. M1.1b works,
byte-identical to `llvm-extract`, ~5% warm compile cost, corpus median **0.864×** measured. It is
off for one reason: the portability claim rests on a macOS PATH test rather than a green CI on
three platforms. **That run is the whole task.** Largest measured prize on the list per unit of
work, and it needs no language change.

**C. Restate or retire M2** — [`TODO.md`](TODO.md) § M2 and its exit gate; item 2b here. That
gate — a ≥10× allocation drop on g2 and g6 — is
**met on both, by M3**, and reuse tokens still have nothing to fire on: `match` appears in no
corpus program at all. Either re-target the milestone at g7 with a gate it can actually move, or
close it and say why. Half an hour of honesty that stops a future session building the wrong thing.

**D. Then item 3 — inline element storage for `List<T>`** — [`TODO.md`](TODO.md) § M4, checkbox
M4.2 (and M4.1 before it). The only remaining
change projected to move the whole band, and the expensive one. Read the correction in
`ARCHITECTURE-DIRECTION.md` first: boxed layout costs **allocations**, not indirection (measured
0.86× free), so the prize is the allocations M3's arenas did *not* remove. Needs views/slices to be
expressible, which is the language design this milestone actually is.

**What not to spend a session on:**

- **`test_47`'s 6 and `test_45`'s 2.** Understood, deferred, reasons recorded above. Six
  allocations in a fixture against a use-after-free in the compiler is not a trade worth taking.
- **A bisect for the RSS regression.** There is nothing left to bisect; see item 4.
- **More timing runs on a program in the ±5% band.** Attribute instead — diff the two `.ll` files
  by function. It took a minute to prove g1 and g4 had byte-identical loop code, after two
  benchmark runs had failed to settle it.

---


**Nothing that session opened is still open.** The three items it left were closed in a third
pass — g3 fixed, `test_47` deferred with a reason, g4 attributed to measurement — and the details
are in [`RESULTS-M3-leaks-and-regime.md`](aif/evidence/RESULTS-M3-leaks-and-regime.md) §5.

**What is genuinely open, and it is small:**

- **`test_47` leaks 6**: a value returned **two** hops. Deferred, and the reason is now the useful
  part: the obvious relaxation leans on `site_in_released_field`, which has a **known hole** this
  compiler exercises — `src/` puns an `ASTNode` pointer as `String`, so those fields are not
  reported as released, and a widened rule would hand AST nodes to the deallocator. It needs
  INFERENCE 6's contexts, not another clause.
- **`test_45` leaks 2**, both documented in `run_aif_verify_test`: a binding reborrowed into a
  callee's local name, and a field a reassignment guard deliberately protects.
- **M5.2 owes one measurement**, not an investigation — re-run `RESULTS-final.md`'s harness so the
  RSS figure against Rust can be restated.

**The standing caveat, and what 2026-08-28 did to it:** the corpus band had not moved in seven
sessions (1.12–5.57× → 1.13–5.89×) across ten landed features, because *the features that landed
were not the features this corpus measures.* This session was the first that was — g2 goes
**5.77× → 2.6×** and g6 **4.31× → 2.58×** of idiomatic Rust, and peak RSS fell everywhere — so the
band is roughly **1.09×–3.23×** on the driver's own numbers and
[`RESULTS-final.md`](aif/evidence/RESULTS-final.md)'s matrix is stale for g2, g6 and all six RSS
figures. **Task A above is what makes it quotable again.** The caveat itself still stands for the
rest: four of six programs are flat, and if the next thing is chosen for reasons other than this
corpus — which is legitimate — say so rather than expecting the numbers to move.

**Nothing *after* that list is a queue.** The two sections below it are (1) what is genuinely
blocked and on whom, and (2) what was considered and deliberately declined, with the reasoning, so
it is not rediscovered.

If you decline all five items above — which is a legitimate call, per the caveat — the honest
alternatives in rough order of value are:

1. **Ask what the framework needs next.** Every remaining gap in this compiler is a language gap —
   methods, closures, slices, an error-handling story past `Option`/`Result` — and which one
   matters is a question about what is being built, not about the compiler.
2. **Take a real program and compile it.** Every defect found in the last two sessions came from
   *running* something nobody had run — a packaging script, an installer probe, a spec-required
   check — not from reading code. `tools/` is now clean; the next unexercised surface is whatever a
   framework does that `tests/` does not.
3. **Pick from "deliberately not in this list" and re-argue it.** Those entries are decisions, not
   facts, and two of them (PDB/CodeView, `--verify` instrumenting reads) would change if the target
   audience changed.

---

## How to work this

**One task at a time. Do not start task N+1 until task N is green.**

If a task turns out to be wrong, stop and say so rather than pushing through.

### The standing gate

Written once here; every task is "done" only when all of it is green.

```bash
# snapshot BEFORE you start, with the last-good compiler
python3 tools/ir_snapshot.py --compiler build/<last-good> --out /tmp/base

bash tools/bootstrap.sh --compiler build/<last-good> --out build/N1
bash tools/bootstrap.sh --compiler build/N1 --out build/N2
# N1 and N2 must emit byte-identical IR for src/main.psm

cd tests && PRISMIO=../build/N2 python3 test_runner.py     # 136/136 or more
python3 tools/aif_differential.py --compiler build/N2      # 17 sources agree
python3 tools/ir_snapshot.py --compiler build/N2 --out /tmp/after && diff -rq /tmp/base /tmp/after
bash tools/bootstrap.sh --seed --out build/Ns0
bash tools/bootstrap.sh --compiler build/Ns0 --out build/Ns1
# Ns1's src/main.ll must match N2's
```

The snapshot must be identical except `src/main.ll`, plus any fixture a task deliberately extends.
Five sessions running have held to that, so a diff anywhere else is a real finding.

After any change to `runtime/*.c`: `python3 runtime/generate_embedded_sources.py` **and**
`python3 tools/check_source_lists.py`.

**Adding an FFI function is one step; removing one is two.** The committed seed's IR calls the C it
was built against, so deleting a C function that `bootstrap/prismio-seed.ll` still names breaks a
fresh checkout, and only CI's first step catches it. Stop calling it from `src/`, refresh the seed,
*then* delete the C. Adding is safe in one step — the seed never calls what it does not know.

**A new string literal in `src/` renumbers the whole string table.** It shows up as a several
hundred line `src/main.ll` diff that is entirely `@.str.sNNNN` shifting by one. Read the first few
hunks before assuming a change was bigger than it was.

**Break every new assertion before believing it.** Five sessions of house standard, and it has
caught a test that passed against a broken compiler at least twice. The cheap form is a mutated
copy of the file under test in the scratchpad; the honest form is a mutated *compiler*, which costs
one bootstrap and is what the 2026-08-24 session used for all five of its tasks.
**2026-08-28 found the failure this is for**: `test_71_nonlexical_extent.psm` had been passing
while placing **no arena at all**, so all five of its assertions measured a program the feature
never touched. Before trusting an arena fixture, read `AIF_STMT_TRACE=1` and count the extents.

**When a recorded blocker names an obligation, check it with `--why` before planning around it.**
Wrong three sessions running: g6's was "obligation 2" and was really the call-site count; g3's was
"a container teardown that frees the object and not its fields" and was really the value copied
*into* an inline field. `--summary` counts a *program*; `--why=<symbol>` answers for the site you
actually care about and lists every failing clause rather than the first.

**Every leak this project has found was a missing *owner*, not a missing free** — and in each case
the analysis and codegen each had a defensible answer that together lost the value. Look for the
disagreement, not the gap.

**`build/` accumulates.** Keep the last-good and delete the rest; nothing in it is an input to
anything.

---

## Blocked, and on whom

### wasm32 past IR

All 78 fixtures produce verifying wasm32 IR, `run_runtime_library_test` proves the compiler would
find and link `runtime-wasm32-unknown-unknown.a` under exactly that name, and nothing links.

Two things are missing and **neither can be produced from this repo**:

- **`wasm-ld`** (`brew install lld`), which is a host setup step rather than compiler work.
- **`runtime-wasm32-unknown-unknown.a`**, which cannot be built here at all:
  `wasm32-unknown-unknown` has **no C library**, so the runtime sources stop at
  `#include <stdio.h>`. What `print` resolves to on the web is an embedder's decision. Measured
  rather than assumed, and the compiler now says so in the diagnostic, naming the archive it
  looked for and where it looked.

**The compiler side is finished.** Do not reopen this as a compiler task; it is a request to
whoever owns the embedder.

---

## Deliberately not in this list

- **Hot reload / live patching.** Not a compiler feature at the level that matters: swapping
  behaviour at a component boundary through a registry is a framework design and needs no compiler
  support. True function-level patching would need incremental compilation plus indirection at
  every swappable call site — a cost paid in release too.
- **Incremental / separate compilation.** A whole-program rebuild of an app the size of this
  compiler is **83 ms frontend + 116 ms LLVM at `-O0` ≈ 200 ms**, and `run --jit` now takes the
  clang compile and the link out of the loop entirely — 10–20 ms against 220–530 ms for a small
  program. Revisit only when something real is measured to be too slow.
- **PDB / CodeView.** `-g` emits DWARF. An MSVC-targeted build wants CodeView and nothing here
  emits it. `--target x86_64-pc-windows-msvc` works as far as the IR, so this is reachable — it is
  declined for want of an audience, not for difficulty.
- **`--verify` that instruments reads.** Today it catches a double free and a leak; a
  use-after-free is only made *loud*, by poisoning released memory with `0xDD`. SPEC 7.3's table
  and the header over the shims in `runtime/lang_runtime.c` say what each remaining row needs.
- **`List<T>` / `T?` / arrays as real DWARF types.** Opaque pointers under `-g` today. Each needs a
  layout this layer does not have.
- **A bare enum variant's type.** `Colour.RED` is an `Int` to sema, so `let c = Colour.RED` is
  described as an `Int`. Making it a `Colour` is a semantic change — assignability, comparisons,
  `as`, match patterns — and is not a debug-info task. See HANDOFF 2026-08-22 §3.
- **`-Woverride-module`.** Settled 2026-08-24 and not worth reopening. clang's driver always
  compiles for the SDK's deployment target while a module carries at most LLVM's default triple,
  and clang warns identically against a module with **no triple at all** — so nothing written on
  the module could ever have silenced it. Suppressed, and the check it could in principle have made
  is now an assertion in `run_target_test` that our data layout equals clang's.
- **`aifTypeBytes`'s remaining literals.** `Float` is 8 and an enum is 4 because `Float` lowers to
  `double` and an enum falls through to `i32`, on every target LLVM emits for. Routing them through
  the target would advertise a variation that does not exist. The comment above them says so.

## Read before starting

- `CODE_STYLE.md` — especially the two-step rule.
- HANDOFF's 2026-08-24 entry — all five candidates, and the pattern in how the prompt was wrong
  about three of them: **the real defect was one or two lines from where it pointed.**
- HANDOFF's 2026-08-23 entry — the packaged runtime seam, and why a successful build proves
  nothing about it.
- HANDOFF's 2026-08-22 entry — `-g`'s last four holes, and the two assertions that passed while
  broken.
- `docs/DEBUGGING.md` — what `-g` says, and what it deliberately does not.
