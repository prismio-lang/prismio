# Session prompt — Prismio, open ownership work

Continue the Prismio compiler improvement plan. Work the open items in
`TODO.md` in the order below until they are done.

This is Prismio v0.1. Backward compatibility does not matter. Remove obsolete
code, replace old implementations, change internal APIs, and simplify
architecture when that produces a cleaner or faster compiler. Preserve unrelated
working-tree changes. **Do not commit or push without explicit authorization.**

Read these completely before planning:

- `TODO.md`, `SESSION-PROMPT.md`, `NEXT_SESSION.md`, `HANDOFF.md`
- `docs/ARCHITECTURE-DIRECTION.md`
- `aif/evidence/RESULTS-string-migration.md` and `RESULTS-int-width.md`
- `CODE_STYLE.md` before writing `.psm`; `C_CODE_STYLE.md` before `runtime/*.c`

**Verify the tree before trusting any of it.** These briefs have been wrong in
both directions. `git status --porcelain | grep -v graphify-out` first.

---

## Current verified state

Compiler `build/nostr-4`. Suite **172/172**, fixed point, AIF differential
**18/18**, docs build and audit pass, `git diff --check` clean. The full CI job
replays green locally including a from-seed bootstrap. Nothing is committed.

Standing over the seven-program corpus, 25 runs, checksums enforced:
**0.90×–3.09× of idiomatic Rust, median 1.58×**, peak RSS 0.83×–1.01×. `g9` is
the only program below 1.00×.

---

## Research requirement — applies to every item below

For every architecture, algorithm, memory-management, optimization or
code-generation decision:

- **Search the internet first.** Prefer current primary sources: research papers,
  official compiler documentation, official repositories, design notes, RFCs.
- Examine what Rust/LLVM, Swift, Go, Koka/Lean and MLIR do here, and approaches
  that can outperform them. **Rust is a baseline, not a ceiling.**
- Select the approach with the strongest technical and *measured* justification,
  and say which source it came from.
- **Do not claim Prismio beats Rust unless a controlled side-by-side benchmark
  proves it.** When Prismio loses, inspect emitted LLVM IR and machine code and
  attribute the gap to a concrete cause — representation, allocation, bounds
  checks, aliasing, vectorization, inlining, I/O or startup.
- Optimize general compiler behaviour, not the benchmark source. Separately
  labelled hand-tuned arms are allowed for finding the attainable ceiling.

---

## The work, in order

### 1. An owned call result used directly as an argument has no owner

`tests/owned_temporary_argument.psm` is the discriminator and differs from a
clean program by one `let`:

| | allocated | released | leaked |
|---|---:|---:|---:|
| `let b0 = band(...)` then `simulate(b0)` | 27 | 27 | **0** |
| `simulate(band(...))` | 107 | 27 | **80** |

`aif_owns_call_result_at_node` answers the ownership question and codegen asks it
at a **binding** (`VARIABLE_DECL` and assignment, `src/ir/stmt.psm`). A temporary
is never bound, so nothing asks and nothing drops. An automatic region usually
hides this by reclaiming in bulk; `prismio aif <src> --why=<symbol>` names the
exact moment it cannot.

**The guard this needs.** Releasing every owned temporary is a use-after-free
wherever the callee retains it — `list_push` is the obvious case and its FFI
contract already answers `RETAIN_IN_BASE`. A **Prismio** callee needs the same
question answered from the escape facts before any drop is emitted.

Research first: how do Rust (MIR drop elaboration / `NeedsDrop`), Swift (SIL
ownership, `@guaranteed` vs `@owned` parameter conventions) and Koka/Lean
(Perceus reference counting, "borrowed vs owned" parameter inference) decide
whether a callee consumes or borrows a parameter? Perceus in particular solves
exactly this and the paper reports the drop placement rules.

### 2. Ownership of a callee-allocated value does not survive a second return

`tests/owned_return_depth2.psm`: depth 1 is **6/6/0**, one more level of call
depth gives **12/7/5**. The line is in `runtime/aif_support.c`:

```c
if (sites[s].fn != c->fn) return AIF_ELEM_NONE;
```

The guard is not arbitrary — a pass-through leaves the value owned where it was
created and freeing it at the caller double-frees. But it also declines the
ordinary case where the intermediate frame *returned* the value and kept no claim
on it, which is every producer written in Prismio. It was invisible while
`std.string` was C, because an `extern fn` carries its `produce` contract and
answered at depth 1.

**It needs the transitive fact** — the site escaped to Caller through every
intermediate frame and no intermediate frame owns it — which is a fixed-point
change, not a predicate change.

`tests/test_72_reassigned_ownership.psm` is deliberately still on the C
`str_concat` because of this, and its header says so. When this is fixed, migrate
that file and check the ledger returns to 29/27/2.

### 3. Debug-mode integer overflow checking

`Int` is 32-bit and wraps silently. That decision was re-derived from measurement
on 2026-08-26 and **stands** — do not reopen it without new evidence; read
`RESULTS-int-width.md` first, which kills the two obvious counter-arguments with
numbers.

What is owed is the diagnostic. Rust's model — check in debug, wrap in release,
with explicit `wrapping_*`/`checked_*`/`saturating_*` for intent — is the
reference. Priced here with clang's signed-overflow sanitizer at **4.1–4.4×**, so
it can only ever be a debug mode; a native `llvm.sadd.with.overflow` lowering
should be cheaper and that is the thing to measure.

### 4. `__builtin_string_len` truncates, and the benchmark clock lies

`%prismio.str` carries its length in **i64** and the builtin returns `Int`, so
every read emits `trunc i64 … to i32`. The representation is wider than every
path that reads it, which is incoherent under either width choice. Decide and
make it coherent.

Separately, every benchmark source declares
`extern fn clock_gettime_nsec_np(clk: Int) -> Int` against a function returning
`uint64_t`. It works only because the code takes a difference and frames are
short. A frame over ~2.1 s would produce garbage.

### 5. Give the AIF fixtures a purpose-built foreign surface

`str_concat`, `str_substring`, `str_equals`, `int_to_str` and `str_slice` survive
in `lang_runtime.c` **only** because 13 AIF/tier fixtures and one benchmark
declare them to exercise `extern fn` ownership. The runtime should not carry dead
code to keep a test alive. Note the fixtures have hardcoded manifest expectations
in `tests/test_runner.py` that must move with them.

### 6. Remote CI gate — needs authorization, not work

`PRISMIO_INLINE_RUNTIME`'s default cannot be marked done until the three-platform
matrix runs. Three discriminating checks wait on it. **Ask for commit/push
authorization; do not push without it.** If it is refused, say so plainly and
leave the parent item unchecked.

---

## Required gate after every completed task

Show the user the before/after immediately after each task. Do not batch to the
end.

```bash
bash tools/bootstrap.sh --compiler build/<lastgood> --out build/<next>
bash tools/bootstrap.sh --compiler build/<next>     --out build/<next2>
./build/<next> build src/main.psm -o build/a.ll
./build/<next2> build src/main.psm -o build/b.ll
cmp build/a.ll build/b.ll                      # fixpoint

PRISMIO=$PWD/build/<next2> python3 tests/test_runner.py          # 172/172 or higher
python3 tools/aif_differential.py --compiler build/<next2>       # 18/18
python3 tools/check_source_lists.py
git diff --check
```

```bash
python3 tools/milestone_bench.py --old build/<lastgood> --new build/<next2> \
    --runs 25 --label "<task>" --json aif/evidence/results-<task>.json

python3 aif/evidence/xlang/bench.py --compiler build/<next2> --runs 25 \
    --json aif/evidence/xlang/results-<task>.json
```

Plus, for anything touching allocation: build with `--verify` and read the
ledger. **`violations` first, then `released` against `allocated`** — `allocated`
and `leaked` are noisy run to run; `violations` is the number that means
corruption.

Save raw JSON and write an `aif/evidence/RESULTS-*.md`.

**Never run the suite and benchmarks concurrently.** They share fixed paths and
caches, and contention turns into misleading `aif exited -9` cascades.

---

## Traps this codebase actually has

- **Refresh the seed when the runtime surface changes.** `bootstrap/prismio-seed.ll`
  is prebuilt IR; deleting a C function it calls makes a fresh checkout fail to
  *link*, not to parse, and CI bootstraps from the seed on all three platforms.
  `tools/refresh_seed.sh --compiler build/<good>`, then verify with
  `tools/bootstrap.sh --seed --out build/seedcheck`.
- **Editing `runtime/*.c` does nothing until** `python3 runtime/generate_embedded_sources.py`
  runs and the compiler is bootstrapped again.
- **Ask the compiler, don't reason from a note.** `prismio aif <src> --why=<symbol>`
  gives the minimal cause, the placement decision, and the ranked repairs. It has
  been right where recorded blockers were wrong.
- **`PRISMIO_BUILD_TRACE=1`** prints one wall-clock line per build stage. Start a
  compile-time question there, not with a whole-build ratio.
- **A fixture can pass while proving nothing.** Every new discriminating test must
  be *observed failing* when the thing it guards is removed or broken.
- **Enumerate existing owners before adding any free.** A previous attempt
  collided with three, and a green suite proved nothing.
- **`Int` is 32-bit and wraps.** A cross-language port must compute in `i32` with
  `wrapping_*` or the checksums disagree — that is how g9's Rust ports were found
  wrong.
- **A shared constant has one spelling everywhere**, and a test compares the
  tables. `src/aif/contracts.psm` and `aif/prototype/aif.py` must move together;
  `run_oracle_vocabulary_test` enforces it.

---

## Documentation gate

After every completed milestone, update: `TODO.md`, `NEXT_SESSION.md`,
`SESSION-PROMPT.md`, `HANDOFF.md`, `docs/ARCHITECTURE-DIRECTION.md`,
`aif/evidence/README.md`, a new or updated `RESULTS-*.md`, and the public docs in
the **sibling repo** `../docs/content/`. Then:

```bash
cd ../docs && PRISMIO=<compiler> node scripts/verify-doc-examples.mjs
cd ../docs && node scripts/audit-content.mjs && npm run build
graphify update .
```

---

## Working style

- Continue autonomously; do not stop at a finding when a safe implementation step
  remains. But **do not rush a change to the drop path** — a leak is recoverable,
  a double free is not. If the safe version does not fit, say so and hand over a
  precise diagnosis instead of a risky patch.
- Add the discriminating test **before** trusting an optimization.
- Keep failed experiments as clearly labelled evidence when they teach something.
- Prefer deleting obsolete v0.1 code over maintaining compatibility layers.
- After each task report: what changed, why, tests, before/after, Rust
  comparison, allocation/RSS/compile-time changes, and what comes next.
- If a previous session's claim turns out to be wrong, **correct the record in
  place** rather than leaving two accounts in the tree.
