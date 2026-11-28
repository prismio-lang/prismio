## Code style

Read [CODE_STYLE.md](CODE_STYLE.md) before writing `.psm`, and
[C_CODE_STYLE.md](C_CODE_STYLE.md) before writing `runtime/*.c` or `runtime/*.h`.
Follow them.

Two C-side invariants are worth repeating here, because both fail as a *violation*
rather than a leak — corruption, not lost bytes:

- **An allocation returned to Prismio goes through `rt_base_alloc`**, and an
  internal temporary this runtime frees itself does not. The seam is in
  `runtime/prismio_runtime.h`. **The two worlds are one-way**: a slab allocator sits
  behind the seam (docs/ALLOCATOR_PLAN.md), so a seam block is released only by
  `rt_free`/`rt_base_realloc`, never libc `free`/`realloc`; a libc block may reach
  `rt_free`. Runtime sources spell libc's release `tmp_free`/`tmp_realloc` and poison
  the bare names, and the gate for a missed one is `slab_free_shim` (an empty log).
- **`produce(f)` versus `alias` is not a guess, and `f` is read.** A function
  returning a pointer into `argv` (as `cli_arg` did) is `alias`; declaring it
  `produce` hands `argv` to the deallocator. A runtime function that returns a seam
  block is `produce(rt_free)`; `produce(free)` means libc `free` (a `String` result is
  copied in and `free` called at once).

## The seed is tracked but never committed on refresh

`bootstrap/seed.ll` is tracked by git, but a refreshed one is **never staged or committed until the
maintainer says so**: ~20 MB of IR per refresh would bloat the history. `.githooks/pre-commit` refuses a staged seed (`git config core.hooksPath
.githooks` enables it; `PRISMIO_ALLOW_SEED_COMMIT=1` overrides, only on the maintainer's word). Commit by
naming paths, never `git add -A` / `git commit -a`, and leave `bootstrap/` out.

## Runtime surface

[The runtime surface](https://developers.prismio.org/runtime/supported-surface) is the map of what a program can call. Applications use
`std.*`; `extern fn` is for foreign code an application brings itself, not for
reaching into the Prismio runtime. When you add or change a runtime symbol, the
wrapper and its contract in `std/` are part of the change.

The documentation is a **sibling repository**, `../website`, not in this tree:
`apps/docs` for users and `apps/developers` for compiler contributors. Both have
compiler-checked examples — after a language or library change, run in each app
(the compiler must be a packaged toolchain, not a bare `build/gN`):

```bash
cd ../website/apps/docs && PRISMIO_INTERNAL_HOSTED=1 PRISMIO=<toolchain>/bin/prismio node scripts/verify-doc-examples.mjs
```

Two rules from it are load-bearing enough to repeat here, because breaking either one
fails a generation later with nothing pointing at the cause:

- **The committed seed must be able to parse `src/`.** The seed is `bootstrap/seed.ll`. New
  syntax lands in two steps — teach the frontend, cut a seed (`prismio seed`) and
  have the maintainer commit it, *then* use it in `src/`.
- **A behaviour-preserving change must produce byte-identical compiler output** for
  every program in `tests/` and `benchmarks/hosted/prismio/`. Verify with two generations to a
  fixpoint and `prismio verify` (every test, uncached, plus the AIF and PIR differentials).
  `prismio suite` (`dev`) shows the same thing for free: a behaviour-preserving change is one
  whose run is all `cached K2`, and any fixture it *executes* is one whose IR moved.

## Commands

Everything is a project command from `build.ums`, run from the checkout:
`prismio build` (the compiler this checkout runs, `.prismio/build/debug/prismio`),
`prismio suite [profile]` (the test engine, below), `prismio verify` (the `verify` profile:
every test on a package, lists, externs, both differentials, corpus), `prismio gate` (the `gate`
profile: lint, then a packaged candidate through every test and the self-hosting checks;
run it before every push; CI does not run on push, it is started by hand with `gh workflow run ci.yml --ref main`), `prismio release` (the archive and `.sha256` for this
host), `prismio bench`, `prismio bootstrap` (gen0 from `bootstrap/seed.ll`, then gen1 and gen2; `--promote` also installs gen2 as
the local toolchain, `.prismio/build/release/prismio`) and
`prismio seed` (cut `bootstrap/seed.ll` from `build/gen2` and check it bootstraps; left uncommitted). The
`.py` files under `tools/` are what they call; reach for them directly only when a command cannot (a
machine with no `prismio` yet: `python3 tools/bootstrap.py --seed --out build/gen0`).

Four hazards, each of which has cost a session:

- **Never run `prismio build`, or edit `src/`, `std/` or `runtime/`, while a suite runs.**
  The suite tests a copy of the toolchain and the `ums` tests use a copy of the checkout, so
  the host is no longer moved; but fixtures and harness tests still compile the working tree,
  and the cache keys hash it while the run is going.
- **A feature `src/` needs must be installed as the host first.** Teach the compiler,
  build it, cut a seed (`prismio seed`), install that generation as the
  host, *then* use the feature in `src/`. The old host cannot build a tree that needs
  something it lacks.
- **Name a test compiler anything but `prismio`.** It is a launcher that forwards by
  basename; set `PRISMIO_INTERNAL_HOSTED=1`. A fixpoint is read in the IR
  (`gen build src/main.psm -o x.ll`, twice), never in the binary.
- **The LLVM targets are written twice**: `PRISMIO_LLVM_TARGET_LIST` in
  `runtime/prismio_llvm.h` and `TARGET_COMPONENTS` in `tools/setup_llvm.py`
  (AArch64, X86, WebAssembly). `tools/check_source_lists.py` fails if they disagree;
  adding a target is both lists plus `default_target_cpu` and the targets docs page.

## Tests

The test engine is `tools/testkit/` (how to use it: the developer docs' testing overview; design and
measured numbers, removed from the tree: `git show 3df157c:docs/TEST_ORCHESTRATION_PLAN.md`).
`tests/test_runner.py` is a compatibility shim; do not add tests to it.

Pick the profile by what the change is, and say which one ran:

| Profile | Use it | Cache |
|---|---|---|
| `prismio suite smoke` | after each edit (~10 s, 37 tests) | read/write |
| `prismio suite` (`dev`) | while working: every test, skipping only what a key proves unchanged | read/write |
| `prismio suite full` | before committing anything under `src/`, `runtime/`, `std/`, `tools/testkit/`, `tests/` | write-only |
| `prismio verify` | before merging a feature | write-only |
| `prismio gate` | before every push | write-only |
| `prismio suite release` | release candidates, with `RELEASE.md` | write-only |

- **A cached pass is not a run.** Only `full`, `verify`, `gate` and `release` back a claim that
  "the suite passes"; `smoke`, `dev` and any filtered run (`-k`, patterns, `--suite`, `--tag`,
  `--changed`) say so on their last line, and so must your report. `--no-cache` turns it off;
  `prismio suite affected` explains what a diff is expected to move.
- **Skipping is decided by cache keys alone, never by which files changed.** `--changed` widens to
  every test for any edit under `src/`, `runtime/`, `std/`, `lsp/` or the engine. Do not add a
  path-to-test shortcut that skips.
- **A new file fixture** is `tests/test_*.psm` (must exit 0; `// expect-trap: <arg> => <message>`,
  `// expect-output: file.out`) or `tests/neg_*.psm` (`// expect-error:` substrings required). An
  optional `// test: suite=... tags=... resources=... cache=never` header; use `cache=never` for a
  program whose result depends on timing, threads racing or the machine.
- **A new harness test** goes in `tests/harness/<suite>.py` with
  `@harness_test(suite=..., resources=..., reads=..., timeout=...)` from `testkit.api`. It writes
  only under `scratch()`, never into `tests/` or the checkout. It is never cached until it declares
  `reads` (`reads=[]` for none) and passes `prismio suite full --audit`; an undeclared read is a
  stale pass waiting to happen. Shared state is a resource: `{"project_host": EXCLUSIVE}`,
  `objcache`, `qemu`, `quiet` (timing tests), plus `cpu` tokens and a `mem` budget in MB.
- **`PRISMIO_TEST_JOBS=1`** runs one test at a time; reach for it when a failure looks like
  interference. `--repeat N` reports flaky tests; nothing is ever retried silently.
- **Known exception:** `test_287_multi_statement_fill` disagrees under the PIR interpreter
  (pre-existing; `PIR_KNOWN` in `tools/testkit/checks.py`, `docs/KNOWN_ISSUES.md`). Do not add to
  that list without the maintainer's word; remove the entry when it is fixed.
- Results live in `.prismio/test-cache/` (untracked); `--cache-clear` empties it.

## Before a release

The seed is cut after the tag (`prismio seed`), and committed only when the maintainer says so. The full
procedure is `RELEASE.md`.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships. `graphify update .` builds it from the tree. It is **local and untracked** (`.gitignore`): nothing in `graphify-out/` is ever committed.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## Where the project's state lives

There is no `TODO.md` or `HANDOFF.md`. They were session scaffolding and were
removed at 0.1.0. What replaced them:

- **`RELEASE.md`** — how to ship, in order, and what must be green first. What
  else is open is `docs/KNOWN_ISSUES.md`; there is no separate checklist.
- **`docs/*_PLAN.md`** and `docs/COLLECTIONS.md` — the planners, each split into
  what the current release needs and what comes later. Root is not the place
  for a new handoff or spec; a plan goes in `docs/`.
- **`docs/KNOWN_ISSUES.md`** — what is open, with enough of each to act on.
- **`docs/aif/`** — the memory model's specification and design record. Measured decisions
  and rejected experiments are the developer docs' *Performance decisions and rejected
  experiments* page; the raw experiment records (`aif/evidence/`, removed 2026-10-07) are in Git
  history, see `docs/aif/README.md`.
- **`git log`** — the record. Commit messages here carry their own evidence, and
  are usually better than any document summarising them.
- **The docs site's release pages** (`../website/apps/*/content/releases/`) — what
  shipped. There is no `CHANGELOG.md`.
