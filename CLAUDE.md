## Code style

Read [CODE_STYLE.md](CODE_STYLE.md) before writing `.psm`, and
[C_CODE_STYLE.md](C_CODE_STYLE.md) before writing `runtime/*.c` or `runtime/*.h`.
Follow them.

Two C-side invariants are worth repeating here, because both fail as a *violation*
rather than a leak — corruption, not lost bytes:

- **An allocation returned to Prismio goes through `rt_base_alloc`**, and an
  internal temporary this runtime frees itself does not. The seam is in
  `runtime/prismio_runtime.h`.
- **`produce(free)` versus `alias` is not a guess.** `cli_arg` returns a pointer
  into `argv`; declaring it `produce` hands `argv` to the deallocator.

## Runtime surface

[RUNTIME.md](RUNTIME.md) is the map of what a program can call. Applications use
`std.*`; `extern fn` is for foreign code an application brings itself, not for
reaching into the Prismio runtime. When you add or change a runtime symbol, the
wrapper and its contract in `std/` are part of the change.

The user-facing documentation site is a **sibling repository** at `../docs`, not
in this tree. Its examples are compiler-checked — after a language or library
change, run:

```bash
cd ../docs && PRISMIO=<compiler> node scripts/verify-doc-examples.mjs
```

Two rules from it are load-bearing enough to repeat here, because breaking either one
fails a generation later with nothing pointing at the cause:

- **The committed seed must be able to parse `src/`.** New syntax lands in two steps —
  teach the frontend, refresh the seed, *then* use it in `src/`.
- **A behaviour-preserving change must produce byte-identical compiler output** for
  every program in `tests/` and `aif/corpus/`. Verify with two generations to a
  fixpoint, the full suite, and `tools/aif_differential.py`.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships. **It is generated and untracked** — `graphify update .` builds it from the tree, and a fresh clone will not have one until you do.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## Where the project's state lives

There is no `TODO.md` or `HANDOFF.md`. They were session scaffolding and were
removed at 0.1.0. What replaced them:

- **`KNOWN_ISSUES.md`** — what is open, with enough of each to act on.
- **`aif/evidence/`** — the measurements, one `RESULTS-*.md` per piece of work.
- **`git log`** — the record. Commit messages here carry their own evidence, and
  are usually better than any document summarising them.
- **`CHANGELOG.md`** and **`RELEASE.md`** — what shipped, and how to ship it.
