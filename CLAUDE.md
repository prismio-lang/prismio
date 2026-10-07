## Code style

Read [CODE_STYLE.md](CODE_STYLE.md) before writing `.psm`, and
[C_CODE_STYLE.md](C_CODE_STYLE.md) before writing `runtime/*.c` or `runtime/*.h`.
Follow them.

Two C-side invariants are worth repeating here, because both fail as a *violation*
rather than a leak — corruption, not lost bytes:

- **An allocation returned to Prismio goes through `rt_base_alloc`**, and an
  internal temporary this runtime frees itself does not. The seam is in
  `runtime/prismio_runtime.h`.
- **`produce(free)` versus `alias` is not a guess.** A function returning a
  pointer into `argv` (as `cli_arg` did) is `alias`; declaring it `produce` hands
  `argv` to the deallocator.

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

- **The committed seed must be able to parse `src/`.** New syntax lands in two steps —
  teach the frontend, refresh the seed, *then* use it in `src/`.
- **A behaviour-preserving change must produce byte-identical compiler output** for
  every program in `tests/` and `benchmarks/prismio/`. Verify with two generations to a
  fixpoint, the full suite, and `tools/aif_differential.py`.

## Commands

Everything is a project command from `build.ums`, run from the checkout:
`prismio build` (the compiler this checkout runs, `.prismio/build/debug/prismio`),
`prismio suite` (fast loop), `prismio verify` (suite, source lists, externs, AIF
differential), `prismio gate` (lint, then the release gate on a packaged candidate;
run it before every push; CI does not run on push, it is started by hand with `gh workflow run ci.yml --ref main`), `prismio release` (the archive and `.sha256` for this
host), `prismio bench`. The `.py` and `.sh` files under `tools/` are what they call;
reach for them directly only when a command cannot (bootstrapping, the seed).

Four hazards, each of which has cost a session:

- **Never run `prismio build`, or edit `src/`, while `tools/run_suite.py` runs.** Its
  ums fixture moves the host aside, and some fixtures compile the working tree.
- **A feature `src/` needs must be installed as the host first.** Teach the compiler,
  build it, refresh the seed (`tools/refresh_seed.sh`), install that generation as the
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

The seed and `graphify-out/` are refreshed *before* the gate, in the commit that gets
tested: `prismio build` twice, `tools/refresh_seed.sh --compiler
.prismio/build/debug/prismio`, `graphify update .`. CI only checks that the seed can
still parse `src/`, so a stale one passes. The full procedure is `RELEASE.md`.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships. `graphify update .` builds it from the tree. Only `graph.json`, `GRAPH_REPORT.md`, `manifest.json` and `graph.html` are tracked; the cache, `cost.json` and the `.graphify_*` sidecars stay local (see `.gitignore`). Commit the three with the change that moved them, not on their own.

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
