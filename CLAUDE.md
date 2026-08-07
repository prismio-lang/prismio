## Code style

Read [CODE_STYLE.md](CODE_STYLE.md) before writing code in this repository, and follow it.

Two rules from it are load-bearing enough to repeat here, because breaking either one
fails a generation later with nothing pointing at the cause:

- **The committed seed must be able to parse `src/`.** New syntax lands in two steps —
  teach the frontend, refresh the seed, *then* use it in `src/`.
- **A behaviour-preserving change must produce byte-identical compiler output** for
  every program in `tests/` and `aif/corpus/`. Verify with two generations to a
  fixpoint, the full suite, and `tools/aif_differential.py`.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
