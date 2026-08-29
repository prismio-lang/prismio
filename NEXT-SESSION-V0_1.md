# Next session — v0.1 after the matrix went green

The last brief's four blocked items are closed or decided. What is left is **one
decision that is the project's to take** and **three things recorded rather than
done**, each with the reason it was left.

The last-good compiler is **`build/jit2`**. Gate with it.
Work is on branch **`windows/jit-symbol-visibility`**, and CI is **green on all
three platforms** — the first time that has happened.

`V0_1_FEATURES.md` is current. **Check the tree before planning anyway**: the
previous brief was wrong in four places, including its own §0, and this one will
age the same way.

---

## 0 · What changed, and what to distrust in the old brief

- **The CI matrix is green.** Ubuntu, macOS and Windows, 197/197 (two new tests).
- **`test_76_std_fs` was already fixed** when the last brief called it "the
  cheapest task on this list". It had been confirmed a run earlier.
- **`run --jit` was not "blocked, needs a Windows host".** CI *is* a Windows
  host, and the cause was readable from macOS. See §2.
- **The g7 pair was not "byte-identical".** The code was identical and the
  comments differed — one of them describing behaviour the file no longer had.
- **`../docs` is a git repo**, contrary to the old §7. It has a remote and one
  commit of history.

---

## 1 · The decision — 3.6, and it is the only one

**Does v0.1 ship without a non-owning typed reference?** `V0_1_FEATURES.md` §3.6
now carries three answers with what each costs, and the measurement the decision
needs: `Ptr` appears **745 times across 29 of `src/`'s 33 files, of which 17 are
struct fields**. The 17 are the feature; the other 728 are consequences.

The recommendation there is **A now (ship without it), C as the first v0.2 item
(`Ptr<T>` — typed, still unmanaged, no lifetime rule), B only if the language
commits to a borrow discipline.** A `&T` storable in a field needs lifetimes to
be honest, and one that can dangle is worse than `Ptr`, which at least says out
loud that it is unmanaged.

Nothing is blocked on this. It is written down rather than taken because it is a
call about what the language is.

---

## 2 · The Windows JIT, for whoever reads the commits

Worth knowing because the shape recurs. The failure named **the module's own
functions** — `print__U64`, `println__String` — which reads as a codegen fault
and is not one. They were failing to materialize because a dependency was
missing, and the line that said *which* dependency was being thrown away by a
`[-400:]` tail slice in the harness.

Underneath were two bugs, not one:

1. A COFF executable exports nothing, so ORC's process search found none of the
   runtime linked into `prismio.exe`. `tools/bootstrap.ps1` now builds an export
   table by reading the names out of the objects — 191 symbols.
2. That exposed the second: the module calls `malloc`/`free` directly while the
   runtime it now reached allocates through the compiler's CRT, so Windows died
   with **STATUS_HEAP_CORRUPTION after printing**. `ir_jit_run_main` defines both
   into the JITDylib at this process's own addresses.

**The lesson worth keeping: when a diagnostic is unreadable, fix the diagnostic
first.** Each of the three CI rounds here answered exactly one question because
the message was made to carry the answer.

---

## 3 · Recorded rather than done, with the reason

`TODO.md` carries all three.

- **The UMS leak is not what the old brief said.** "Bind the nested `strConcat`
  intermediates" was tried and moves the ledger by zero. The real shape is eight
  lines and needs no UMS: **a function that returns a reassigned binding loses
  the scope-exit release of its other owned locals.** Thirteen reductions rule
  out the loop, the accumulator alone, returning alone, the shared allocation
  site and data flow. The clause is `aif_frees_at_scope_node`'s `s->E != s->scope`
  (`runtime/aif_support.c:5686`). **Not fixed because the failure on the other
  side of that clause is a double free**, and the values may already have an
  owner — enumerate them first.
- **A compiler self-hosted on Windows has no export table.** `build_driver.c`'s
  link needs what `bootstrap.ps1` now does. Recorded because it is `#ifdef
  _WIN32` code this host cannot compile or run, and CI bootstraps Windows through
  the script, so it would ship unchecked. The entry carries the proven recipe.
- **A resolved path dependency is still not on the import search.** Unchanged,
  and documented as not-part-of-0.1 in `../docs/content/package-manager/`.

---

## 4 · The gate

`V0_1_FEATURES.md` §2 is authoritative. The parts most often skipped:

- **Two generations, then compare the IR.** A build that links may only have
  linked because the old compiler built it.
- **All four CI steps, not just the suite.** Source lists, fixpoint, suite,
  oracle differential, seed. Two commits have now been burned by running one.
- **Run the corpus, do not just build it.**
- **Compare generated code, not timings.** The g7 pair was settled by compiling
  both and finding the IR byte-identical; no benchmark could have told them apart.
- **Assert the thing, not its absence.** `neg_55` first named a function that
  does not exist, so it would have passed with the feature removed. A negative
  test needs a positive one proving the name is otherwise reachable.

---

## 5 · Where things are

| | |
|---|---|
| last-good compiler | `build/jit2` |
| branch | `windows/jit-symbol-visibility`, CI green on all three |
| suite | 197 |
| plan | `V0_1_FEATURES.md`; `TODO.md` for compiler debt |
| docs | sibling repo at `../docs`, **is** a git repo, one commit of history |
| docs check | `cd ../docs && PRISMIO=<compiler> node scripts/verify-doc-examples.mjs` — 145 snippets |
| note | only snippets with a `<!-- prismio-check: -->` marker are compiled |
