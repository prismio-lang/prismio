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
  fixpoint, the full suite, and `tools/aif_differential.py`.

## Commands

Everything is a project command from `build.ums`, run from the checkout:
`prismio build` (the compiler this checkout runs, `.prismio/build/debug/prismio`),
`prismio suite` (fast loop), `prismio verify` (suite, source lists, externs, AIF
differential), `prismio gate` (lint, then the release gate on a packaged candidate;
run it before every push; CI does not run on push, it is started by hand with `gh workflow run ci.yml --ref main`), `prismio release` (the archive and `.sha256` for this
host), `prismio bench`, `prismio bootstrap` (gen0 from `bootstrap/seed.ll`, then gen1 and gen2; `--promote` also installs gen2 as
the local toolchain, `.prismio/build/release/prismio`) and
`prismio seed` (cut `bootstrap/seed.ll` from `build/gen2` and check it bootstraps; left uncommitted). The
`.py` files under `tools/` are what they call; reach for them directly only when a command cannot (a
machine with no `prismio` yet: `python3 tools/bootstrap.py --seed --out build/gen0`).

Four hazards, each of which has cost a session:

- **Never run `prismio build`, or edit `src/`, while `tools/run_suite.py` runs.** Its
  ums fixture moves the host aside, and some fixtures compile the working tree.
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
