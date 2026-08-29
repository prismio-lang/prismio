# Prismio — state, map, and what is live

One file. Nine others said versions of this and disagreed with each other; they are
in git history if you need them, and `git log` is better than all of them because
every commit message here carries its own evidence.

**Release candidate: `build/v0.1-rc`.** 202/202 locally, two-generation fixpoint.
**Last compiler observed green on all three platforms: `build/tbaa3`.** CI has
not run on the RC — that is task 6, and it is the last thing between here and a
publishable v0.1. `main` is the only branch.

---

## Where it stands

| | |
|---|---|
| self-hosting | yes, two generations to a byte-identical fixpoint |
| suite | **202** locally, plus a corpus check that *runs* 30 of 33 programs |
| platforms | macOS, Ubuntu, Windows — last **committed** matrix green; the RC is unproven |
| RC vs idiomatic Rust | **0.72x–1.59x** over the seven corpus programs |
| docs | sibling git repo at `../docs`, 145 compiler-checked snippets |

Standing against idiomatic Rust, 25 runs per arm, checksums equal:

| | g1 | g2 | g3 | g4 | g5 | g6 | g9 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Prismio | 1.09x | 1.51x | **0.98x** | 1.55x | 1.28x | 1.59x | **0.90x** |
| Prismio hand-tuned | 0.25x | 0.68x | 0.78x | 0.96x | 0.28x | 1.22x | **0.72x** |

M6 slice 2 ships for field reads and assignments and is **declined for struct
literal initialisers**, which is where its whole g2 regression was: the merge it
enabled is a 0.76x win when the optimiser can see the destination and a 2.74x
loss against `list_push_slot`. g4 keeps 0.963x and g6 0.993x; g2 is back to
mnemonic-identical. `aif/evidence/RESULTS-M6-struct-path-tbaa.md`.

v0.1 concurrency is a blocking typed `Channel<T>` — seven builtins, no executor,
no `async`. g9 has a hand-tuned arm for the first time and it is **1.15x**
tuned-against-tuned, replacing a 1.45x that compared unlike arms.
`aif/evidence/RESULTS-v01-channels.md`.

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

**Six tasks stood between here and a publishable v0.1. Five are closed, and the
sixth is down to one keystroke somebody has to authorise.**

`git push origin main` starts the three-platform matrix on the RC commit.
Nothing is tagged until all three are observed green on it, and the tag plus
`gh release create` are a second decision after that. `RELEASE.md` is the whole
procedure with the checksums this host produced. Do not create a seventh feature
task.

Everything else task 6 asked for is done: CI now packages, verifies the
runtime/backend separation, and smoke-tests the *installed* toolchain outside the
checkout on all three platforms; `tools/release.sh` builds the artifact and its
SHA-256 and refuses a compiler that is not a fixpoint; and a clean checkout of
the RC commit bootstraps to byte-identical compiler IR, so the tag will reproduce
the RC rather than sit beside it.

**The v0.1 pointer decision is closed.** `V0_1_FEATURES.md` §3.6 selects A: v0.1
ships without a non-owning typed reference. C (`Ptr<T>`: typed, still unmanaged)
is the first v0.2 pointer item; B (`&T` in stored fields) waits for a borrow
discipline. The measured reason remains there: `Ptr` appears 745 times across 29
of `src/`'s 33 files, but only 17 struct fields are the missing feature.

**Concurrency is landed, not planned.** `Channel<T>` is seven compiler builtins
typed the way `Task<R>` is; `chan_recv` answers `T?`, which is what ends a worker
loop without a sentinel. `async`/`await`, futures and an executor are v0.2+ work:
they improve composition and suspension, and g9's worker-pool protocol did not
need them.

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
