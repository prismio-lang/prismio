# Next session — the blocked parts of v0.1

Everything small is done. What is left is four things that are *blocked or big*,
not unwritten, plus one decision.

The last-good compiler is **`build/final2`**. Gate with it.
Work is on branch **`v0.1/modules-visibility-and-package-manifest`**, six commits,
pushed. `main` does not have any of it yet.

`V0_1_FEATURES.md` is current and carries the evidence for every claim below.
**Read it before planning** — three of this session's findings contradicted the
previous brief, so check the tree rather than the notes.

---

## 0 · Nothing is outstanding from last session

No debt, no half-finished task. The suite is **195/195**, the two-generation
fixpoint is identical, the committed seed builds a compiler whose generation
matches that fixpoint, and 141 doc snippets pass.

Two things worth knowing before you touch anything:

- **The corpus is in CI now** (`run_corpus_test`), and it is not decoration. It
  builds *and runs* 30 programs. A use-after-free passed 193 tests this session and
  surfaced only because a benchmark happened to be run; the same check now names
  four affected programs. If you change the AIF solver, ownership, or codegen,
  this is the check that will catch you.
- **`released` and `violations` are the trustworthy `--verify` columns.**
  `allocated`/`leaked` moved by 27x this session with no behaviour change, because
  native `std` is visible to the ledger where the C externs were not.

---

## 1 · Selective imports — the one that is half-designed

`import std.string.strTrim` is a syntax error today ("no such file
`std/string/strTrim.psm`"). It is two parts and only one is small.

**Part 1, small.** When the full path is not a file, drop the last segment and
retry; if *that* is a file, the last segment is a selected name. `mergeNamedModule`
in `src/main.psm` is where the fallback goes. Kotlin resolves the same ambiguity
the same way, at resolution time rather than in the grammar.

**Part 2, the real work.** Actually filtering what enters scope. It needs a
per-importing-file record of which names were selected from which module,
consulted during overload resolution — which is exactly the registry this
architecture has avoided ("no module registry to build, fill, reset, or keep in
step with the merge", `src/sema/symbols.psm`).

**Do not ship Part 1 alone.** Without Part 2 the syntax parses and then imports the
whole module anyway, which is a lie in the language rather than a limitation.

The natural place for Part 2 is beside the visibility check in
`semaFindFunctionOverload` — it already filters candidates by declaring file, and
this filters them by importing file. That symmetry is the design.

---

## 2 · 3.6, first-class pointers — blocked on a missing feature

**Not a 757-site rename.** Verified on the tree, not reasoned about:

- a recursive struct field already compiles: `struct Node { next: Node? }`
- a typed linked list already works end to end
- but a typed field **owns** what it holds, so two references to one node is
  `error: use of moved value`

The AST is a shared graph — a node is reachable from `child1`, `next`, the decl
index and `irFunctionBody` at once. `Ptr` is how it opts *out* of affine ownership,
not an accident of style. Forcing `ASTNode?` through would make the AST an owned
graph and double-free it.

What 3.6 needs is a **non-owning typed reference** — a `&T` that can be stored in a
field. That is language design, and it is larger than the rest of v0.1 together.
Decide whether v0.1 ships without it before anyone starts.

---

## 3 · Windows — one fix unverified, one blocked

Ubuntu and macOS are green. Windows is red at the test suite.

- **`test_76_std_fs` — fixed, unverified.** It was a wrong assertion, not a wrong
  `join_path`: the literal `joinPath("/a/b", "c.psm")` comes back `\a\b\c.psm`
  there, because `join_path` normalises separators to the host's. It now builds its
  directory with `joinPath` and asserts the round trip. Passes on macOS. **One CI
  run confirms or refutes it** — that is the cheapest task on this list.
- **`run --jit` — blocked, needs a Windows host.** The JIT cannot resolve
  `prismio_argv`, which is a *runtime C* symbol rather than a generated one, so it
  is not seeing the runtime at all; the `print__*` / `prismioStdIo*` failures follow
  from that rather than being separate. ORC symbol resolution cannot be developed
  or verified from macOS.

---

## 4 · A decision, not a task

**`g7_substring.psm` is now byte-identical to `g7.psm`.** Both called C — one
`str_slice`, the other `str_substring` — and the pair existed only to price those
two against each other. On the native `strSubstring` they are one program. Keep one
and delete the other, or give `g7_substring` a new reason to exist. Left undecided
deliberately so the change is visible in review rather than as a deletion.

---

## 5 · Debt, recorded rather than urgent

`TODO.md` carries both.

- **UMS resolution releases nothing it allocates.** 639 → 637 released while
  allocations doubled, 0 violations. Not unsoundness; the compiler is short-lived.
  It matters if a future `prismio add` or watch mode calls it in a loop. The fix is
  binding the nested `strConcat` intermediates.
- **A resolved path dependency is not on the import search.** 3.7 resolves and
  records dependencies; making one importable is the next slice and is documented
  as not-part-of-0.1 in `../docs/content/package-manager/index.md`.

---

## 6 · The gate

`V0_1_FEATURES.md` §2 is authoritative. The parts most often skipped, and why:

- **Two generations, then compare the IR.** A build that links may only have linked
  because the old compiler built it.
- **The seed, whenever `src/` or `std/` gains syntax.** Teach the frontend,
  `tools/refresh_seed.sh --compiler <c>`, *then* use it. This session needed the
  three-step dance twice.
- **Run the corpus, do not just build it.** The DataView failure was at run time.
- **ASan on every program whose IR changed.** `--verify` balances on a
  read-after-free and reports `0 violation(s)` while the program aborts.
- **Compare generated code, not timings.** g5 read 1.261x and 0.692x in one session
  on byte-identical binaries. If you want to know whether something got slower,
  diff `__TEXT,__text` first; the timing only means something once the code differs.

---

## 7 · Where things are

| | |
|---|---|
| last-good compiler | `build/final2` |
| branch | `v0.1/modules-visibility-and-package-manifest` (pushed, 6 commits) |
| suite | 195 |
| plan | `V0_1_FEATURES.md`; `TODO.md` for compiler debt |
| docs | sibling repo at `../docs`, **not** in this tree, and **not a git repo** |
| docs check | `cd ../docs && PRISMIO=<compiler> node scripts/verify-doc-examples.mjs` — 141 snippets |
| standing vs idiomatic Rust | 0.92x–1.80x, unmoved all session |
