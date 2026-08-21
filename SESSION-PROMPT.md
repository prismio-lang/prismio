# Session prompt — compiler work, with no list

**This file is the one live prompt.** `NEXT-SESSION.md` is the archive of past ones; when this
session is done, fold a summary of it into that file and rewrite this one for the session after.

Everything below is **compiler work only**. The motivation behind it is a cross-platform app
framework built in Prismio, but no task here is framework work — the framework's runtime,
embedders, host imports and packaging are deliberately outside the compiler.

The rule that decides which side anything falls on:

> **If getting it wrong produces a miscompile, it belongs to the compiler.**
> **If getting it wrong produces a link error or a missing feature, it does not.**

**Last-good: `build/S12b`.** Suite 137/137, fixpoint `S12a == S12b`. Bootstrapped
`S10b → S11a → S11b → S12a → S12b`; `S10b` and `E2` remain good behind it. The 2026-08-26 session
landed M1.0 and M1.1 (the curated inlinable module), which is why the compiler moved.

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
   - **M1.1b keeps it opt-in**: the merge shells out to `llvm-extract`/`llvm-link` (Windows risk),
     cold compile time is unmeasured, and `--verify`/object cache/`--target` are covered by
     construction rather than measurement.
   - **M1.3 is untouched** — the hot container ops written in Prismio itself, which is what would
     close the remaining 0.05× on g3.
   Evidence: [`RESULTS-M1-lto.md`](aif/evidence/RESULTS-M1-lto.md).

2. **Automatic arena placement does not fire on the corpus** — 0 of 10,202,214 allocations on g2,
   where the `region` annotation now delivers **2.16×** on that same program. The escape hatch was
   unblocked by the call-site placement work; inference did not follow it. Worth the distance
   between plain g2 at 5.89× idiomatic Rust and `g2_region` at 2.62×. **This is the item that
   decides whether the product claim is "tuned-Rust behaviour from untuned code" or
   "…from code with one annotation".**
3. **Inline element storage for `List<T>`** — ranked second at session 3, still unbuilt, still the
   only change projected to move the corpus band (~1.2–1.3× across the board). The representation
   is 9.23× of the g2 gap and 2.51× of the g4 gap against a **1.24–1.27×** compiler. Needs
   views/slices to be expressible, which is why item 1 outranks it despite a similar prize.
4. **Peak RSS reversed** — 0.84–1.00× → **1.09–1.60×** of idiomatic Rust, +27% to +86% absolute,
   with Rust's figure unmoved. Already excluded by measurement: fixed runtime footprint (ours is
   1.34 MB against Rust's 1.47 MB) and the hot/cold split *on g3 and g6 only* — those two emit no
   split and carry +35% and +86%. g1, g2, g4 and g5 **do** emit splits, so it stays a live
   candidate there. Scales with live set rather than churn. Needs a bisect against a
   session-3-era compiler.
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

**Item 1 is the one to take first** unless the framework question below says otherwise: it is the
largest measured prize, it needs no language change, and both sides are already LLVM IR when they
meet. Item 2 is the one that decides which version of the product claim is true.

**The standing caveat from that session:** the corpus band has not moved in seven sessions
(1.12–5.57× → 1.13–5.89×) across ten landed features. **The features that landed are not the
features this corpus measures.** If the next thing is chosen for reasons other than this corpus —
and that is legitimate — say so explicitly rather than expecting the numbers to move.

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
