# Prismio — state, map, and what is live

One file. Nine others said versions of this and disagreed with each other; they are
in git history if you need them, and `git log` is better than all of them because
every commit message here carries its own evidence.

**Last-good compiler: `build/tbaa3`.** Gate with it.
**CI is green on all three platforms**, 197/197. `main` is the only branch.

---

## Where it stands

| | |
|---|---|
| self-hosting | yes, two generations to a byte-identical fixpoint |
| suite | 197, plus a corpus check that *runs* 30 programs |
| platforms | macOS, Ubuntu, Windows — all green |
| standing vs idiomatic Rust | **0.83x–1.62x** over the seven corpus programs |
| docs | sibling git repo at `../docs`, 145 compiler-checked snippets |

The standing moved on 2026-08-30: g4 1.80x → 1.58x and g6 1.79x → 1.62x, from
giving the IR alias metadata it had never carried. See `TODO.md` M6.

---

## The map — which file answers which question

| question | file |
|---|---|
| how do I work in this repo | `CLAUDE.md` |
| how do I write `.psm` | `CODE_STYLE.md` |
| how do I write `runtime/*.c` | `C_CODE_STYLE.md` |
| what can a program call | `RUNTIME.md` |
| what is the language plan for v0.1 | `V0_1_FEATURES.md` |
| what compiler work is measured and open | `TODO.md` |
| what workarounds does the compiler still use on itself | `V1_GAP_ANALYSIS.md` |
| how do I build it | `PORTING.md`, `CONTRIBUTING.md` |
| what did we do and why | `git log` — the messages are the record |

---

## What is live

**One decision, and it is the project's to take.** `V0_1_FEATURES.md` §3.6: does
v0.1 ship without a non-owning typed reference? Three answers are costed there,
with the measurement the decision needs — `Ptr` appears 745 times across 29 of
`src/`'s 33 files, and **17 of those are struct fields**. The 17 are the feature;
the other 728 are consequences. Recommended A now, C (`Ptr<T>`: typed, still
unmanaged) as the first v0.2 item, B only on a borrow discipline. Nothing is
blocked on it.

**One milestone with numbers.** `TODO.md` M6. Slice 1 landed ~10% on g1/g4/g6.
Slices 2–4 are ranked there by prize over risk, and **two constraints in that
entry are established rather than assumed** — one of them kills the obvious next
step, so read them before starting.

**Three debts, each with the reason it was left.** All in `TODO.md`: the UMS
leak (the recorded fix moves the ledger by zero; the real shape is eight lines
and the clause to widen can double-free), a string literal in a curated runtime
function breaking the link, and a resolved path dependency still not being on the
import search — the last is documented as not-part-of-0.1.

---

## The gate

`V0_1_FEATURES.md` §2 is authoritative. The parts that get skipped, and what
skipping each one cost:

- **Two generations, then compare the IR.** A build that links may only have
  linked because the old compiler built it.
- **All four CI steps, not just the suite.** Source lists, fixpoint, suite,
  oracle differential, seed. Two commits have been burned by running one.
- **Run the corpus, do not just build it.** A use-after-free passed 193 tests.
- **Compare generated code, not timings.** Both benchmark harnesses have reported
  a g5 regression that was not real; a per-function mnemonic diff settles it in
  seconds, and interleaving does not control binary layout.
- **Assert the thing, not its absence.** A negative test written this month named
  a function that does not exist, so it would have passed with the feature
  removed. A negative test needs a positive one proving the name is reachable.
- **Probe an invariant before relying on it.** `RtList`'s comment says the element
  type is a static fact at every call site. It is not, and one abort probe over
  the suite found the program that proves it.

---

## Two habits worth keeping

**When a diagnostic is unreadable, fix the diagnostic first.** The Windows JIT sat
recorded as "blocked, needs a Windows host" while the message naming its cause was
being thrown away by a `[-400:]` slice in the test harness. Three CI rounds then
answered one question each.

**Check the tree before believing a brief — including this one.** The document
this replaced was wrong in four places, including its own summary of what was
outstanding. This one will age the same way.
