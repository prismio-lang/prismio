# Next session — finishing v0.1

`V0_1_FEATURES.md` is the plan and it is current: every landed item carries a
**DONE 2026-08-29** marker with what actually happened, including two places
where the plan's own prediction turned out wrong. Read it before planning.

The last-good compiler is **`build/ns4`**. Gate with it, not with an older one.

---

## 0 · Debt from the last session, do this first

**The five-arm benchmark was not run for `977fab6` (module namespacing).** The
session was stopped before it. Nothing else is outstanding on that commit.

```bash
python3 tools/milestone_bench.py --old build/cl3 --new build/ns4 \
    --runs 25 --label "modules" --json aif/evidence/results-modules.json
python3 aif/evidence/xlang/bench.py --compiler build/ns4 --runs 25 \
    --json aif/evidence/xlang/results-modules.json
```

**The IR-identity check cannot be run for that commit and will not tell you
anything.** `build/cl3` cannot build any program that imports `std`, because
`std/` now uses `priv`. That is expected, not a regression — do not spend time
on it.

**Expect `g5` to read 1.14–1.28x "REGRESSED" and ignore it.** It is a harness
artifact, proven three ways in `630dc17`: g5's emitted IR *and its machine code*
are byte-identical across the two arms (50 differing bytes — the `LC_UUID` and
the embedded output path), and **swapping the arms keeps the penalty on whichever
binary sits in the "new" slot**. Fixing `milestone_bench.py`'s positional bias is
a real task nobody has taken; until then, do not chase g5.

---

## 1 · What is left in `V0_1_FEATURES.md`

### 3.5 — the half that is blocked on a decision, not on work

Qualified calls and `priv fn` landed. The `str*` rename did **not**, and the
plan's premise for it is wrong: `import m` still brings every name in
*unqualified*, so renaming `strTrim` to `trim` would claim `trim`, `length`,
`split`, `contains` and thirty more in the global namespace of every importing
program — worse than the prefix, not better.

**The decision to make is whether `import m` should stop meaning "and bring
everything into scope".** Options, none of them free:

- `import m` becomes qualified-only and `import m.*` brings names in. `import
  ir.*` already means "every module in that package", so the spelling collides.
- A second form (`use m`) for qualified-only. More surface.
- Leave it, and keep the prefix for v0.1. Defensible; say so in the roadmap.

Do not start the 848-call-site rename before this is settled.

`priv` on a type or a global is currently rejected, deliberately — the check
lives in overload resolution, so accepting the marker elsewhere would promise
something the compiler does not do. Extending it to `priv struct` means a check in
`semaAnnotationInner` comparing `tn.file` against the declaration's.

### 3.6 — first-class pointers

The parser gaps are closed. What is left is **722 `ptr_to_node` /
`node_to_ptr` / `ptr_to_token` / `ptr_to_type` call sites** in `src/`.

Of `V1_GAP_ANALYSIS.md`'s six "central finding" rows, four are already resolved
and the notes had not said so — verified by counting on 2026-08-29, not by
reading. `str_equals(a, b) == 1` is at **0** occurrences; a self-forward-declaring
`extern fn` is at **0** of 488 distinct externs; the `while (flag)` idiom is down
to **one** site (`src/main.psm:162`). What is live is the pointer punning and the
hand-built linked lists, which are the same row twice.

### 3.7 — package manager

Untouched. `ums/` exists and `prismio build` with no source discovers `build.ums`,
so this extends something. Deliberately last and deliberately small: a manifest, a
lockfile, a local path dependency, a registry-shaped fetch with no registry behind
it. **The structure is the deliverable; the network is not.**

### 4 — the corpus has not moved with the language

This is a standing instruction that has been half-honoured. The **fifth benchmark
arm** is done for six of seven programs (g9 is absent and its reason is recorded
in `bench.py`). What has *not* happened is the other half: **no corpus or test
program has been rewritten to use `impl`, traits, closures or `sort`.** A corpus
frozen in the language of 2026-08 stops being a measurement of what a real Prismio
program looks like the moment the language moves.

Any such rewrite must keep the program's **checksums identical** — that is what
makes it a rewrite and not a different benchmark — and be reported old-vs-new.

### 5 — what "done" means

Still open: **the three-platform CI matrix observed green.** As of the last
recorded run: macOS green, Ubuntu green, Windows 172/175. Nobody has looked since
the suite grew from 175 to 190, so the Windows number is stale in both directions.

---

## 2 · The gate, unchanged, after every task

`V0_1_FEATURES.md` §2 is authoritative. The parts most often skipped:

- **Two generations, then compare the IR.** A build that links may only have
  linked because the old compiler built it.
- **The seed, whenever `src/` or `std/` gains syntax.** New syntax lands in two
  steps: teach the frontend, `tools/refresh_seed.sh`, *then* use it. Prove it with
  `bootstrap.sh --seed` → build a generation with that compiler → its IR must
  match the fixpoint. This has caught nothing yet only because it has been done
  every time.
- **ASan on every program whose IR changed.** `--verify` balances on a
  read-after-free and reports `0 violation(s)` while the program segfaults.
- **`--verify` compared against a baseline, not read on its own.** Build a
  worktree at the pre-change commit and sweep it; 22 of the tree's programs
  already leak, so an absolute number tells you nothing.

---

## 3 · Things that will bite you, learned the hard way

**`sink` is not an ownership transfer, and sema accepts the double free.**
`fn keep(out: List<String>, sink s: String) { list_push(out, s) }` compiles;
`--verify` says "release of a pointer that is not live" and ASan aborts in
`list_release`. Use `std/copy.psm`'s `Copy { fn copyOf(self) -> Self }` for a
container that keeps what it is given. **This is a live compiler defect** — sema
should reject it — and it is not on TODO.md yet.

**A generic container can own its keys but not its values.** `Map<String, Int>`
is clean; bounding `V: Copy` so `Map<String, String>` compiles works, computes
right answers, and leaks every value the map holds — because `mapGetOr`, `mapGet`
and `mapValueAt` all return from the values list and the analysis stops releasing
a container it has seen escape. Measured and reverted; see `std/map.psm`'s header.

**Chained method calls leak their intermediates.** `a.toUpper().reverse()` leaks
the intermediate — TODO.md's "argument-position release is withheld when the
enclosing call returns a pointer". Chaining is the idiom `impl` blocks exist for,
so that open item is now on the main road. Fixture-writing rule: bind the
intermediate, so a *future* leak in a fixture means something.

**`test_52_aif_cycle_collector` is a heap-use-after-free.** ASan aborts in
`cyc_collect_white` (`runtime/lang_runtime.c:1031`), and it is byte-identical at
the pre-session baseline, so it is old. The cause is visible in the code:
`cyc_collect_white` frees `x` and *then* recurses into its children, so a cycle
that reaches `x` again reads its freed header. Bacon–Rajan frees **after** the
recursion; the children are already copied into `kids` before the free, so
reordering is a two-line change. Nobody has made it.

**A closure's type name contains `$`.** The call rewrite keys on that rather than
on "no function of this name exists" — because `std/string.psm` declares
`compare`, so a sort whose comparator parameter was named `compare` had its call
quietly resolved to the String overload. If you add a rewrite like it, key on the
type.

**Diagnostics cascade, and the error cap hides the abort line.** A violated bound
reported 25 times, hit the cap, and the cap exits without `diag_finish`'s
"aborting due to N previous error(s)" — so a negative test failed as *"compiler
failed without reporting a diagnostic"*, which is a rejection indistinguishable
from a crash. Fixed for bounds three ways (report each pair once, stop
instantiating, stop blaming a member access for an Invalid it did not cause). **The
cap itself still swallows the abort line**; any new cascading diagnostic will hit
the same trap.

---

## 4 · Where things are

| | |
|---|---|
| last-good compiler | `build/ns4` |
| plan | `V0_1_FEATURES.md` (language surface), `TODO.md` (compiler improvement) |
| docs | sibling repo at `../docs`, **not** in this tree |
| docs check | `cd ../docs && PRISMIO=<compiler> node scripts/verify-doc-examples.mjs` — 138 snippets |
| suite | 190 |
| new std modules | `std/ord.psm`, `std/key.psm`, `std/copy.psm`, `std/list.psm` |
| standing vs idiomatic Rust | 0.92x–1.81x; hand-tuned Prismio 0.25x–1.42x |
