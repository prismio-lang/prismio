# Code intelligence for agents and people: what to use, what to build

**Status (2026-10-26): undecided, with a bake-off to run first.** Nothing here is built. This file records the reasoning so a later
session does not repeat it, and says what would settle it.

## The problem

Graphify gives agents a knowledge graph of this repository (`graphify query` / `path` / `explain`), and it has three costs:

1. **Prismio is not understood.** `.psm` support is an open upstream pull request; until it merges, shipping it means shipping a fork.
   Its call edges are name-based heuristics, and it returned unrelated nodes for C function bodies (`compiler_build_executable`).
2. **The output does not belong in git.** `graph.json` and `graph.html` are single large generated files that rewrite on every update, so
   the rule is "never commit a refreshed graph" (CLAUDE.md, `.githooks/pre-commit`). The one part worth keeping, the AI-derived
   semantic extraction of docs, papers and images, is expensive to regenerate and is lost with the rest.
3. **Scale is unproven.** One graph file loaded whole is a poor shape for the 30-million-line Linux tree the kernel work uses
   (unmeasured; this is a hypothesis to test, not a finding).

The compiler already knows the exact answer for `.psm`: `check --emit-index` (IDE_PROTOCOL.md) gives declarations, references, types,
signatures and doc comments, held to the source by `tools/check_index.py` over 353 programs.

## The design that follows from that

**Split by what it costs to regenerate, and commit only the expensive part.**

| Layer | From | Committed | On a fresh clone |
|---|---|---|---|
| Facts: symbols, calls, references, types | deterministic extractors (the compiler's index; tree-sitter elsewhere) | no, gitignored | rebuilt locally, free |
| Semantics: summaries, doc-to-code links, "why" | an AI pass (optional, incremental) | yes, small shards | read; stale where the source hash differs |
| Notes: findings written by people and agents | human / agent | yes, append-only | read; flagged stale when their anchor changed |
| Views and caches | computed | no | regenerated |

Rules that make the committed layer safe:

- Every semantic record stores the **content hash of its source**, the model and the date, and is rewritten only when that hash changes
  (AI output is not deterministic; regenerating on a whim would make every diff noise).
- Anchors are stable (symbol path plus signature hash), not line numbers, so a refactor does not orphan notes.
- Inferred records are labelled; a query can ask for verified facts only.
- The AI pass is opt-in, runs only on changed sources, and the tool is fully useful with it off. The session's own agent can do the pass,
  so no separate API key is needed.
- A per-path "never send to a model, never commit the result" list for sensitive files.

**Scale (a gate, not a hope).** Facts live in an embedded database (SQLite, or LMDB for pure lookups), sharded per file and keyed by
content hash; an update re-extracts only changed files; every answer is size-bounded with a handle to page; whole-graph algorithms are
batch jobs, never on the query path. Gate: index the Linux tree in the VM, then answer ten fixed questions in under a second after an
incremental change. Cross-file resolution (macros, config conditionals, generated code) is the hard part; edges tree-sitter cannot
resolve are labelled approximate rather than presented as exact.

**The agent interface** is task-shaped, not graph primitives: `find`, `explain` (signature, doc, notes and callers in one bounded
answer), `impact` (what breaks if this changes), `trace`, `where_used`, `diff_since`. One core behind an MCP server, a CLI and the
"ask first" hook. Every answer carries provenance (exact or inferred, file and line, current for the working tree) and a stable handle
for the next page or query. Agents can `note` a finding anchored to a symbol.

## What to run before building anything: a bake-off

Candidates, all found from third-party listings only (verify each at its repository; none was run):

- Graphify (current): tree-sitter for code, an LLM backend for docs and images; output `graph.json` / `graph.html`.
- `colbymchenry/codegraph`: tree-sitter, local SQLite with FTS5, MCP, incremental sync, MIT; claims about 19 languages.
- `codegraph-ai/codegraph` (also `codegraph-vscode`, `codegraph-rules-for-agents`): a Rust language server plus MCP, about 38 languages by
  tree-sitter, 42 tools, a "persistent memory" layer, VS Code and JetBrains plugins, Apache-2.0. Overlaps with `prismio-lsp`: two servers
  for one language would be a conflict.
- Others with the same shape: `optave/ops-codegraph-tool`, `Jakedismo/codegraph-rust`, `polycodegraph`, `codebase-memory-mcp`.

Run each in a scratch directory (never in this checkout) on: the compiler repo (`src/*.psm`, `runtime/*.c`, `tools/*.py`) and the Linux
tree in the VM. Same ten questions each (callers of a runtime function, what breaks if a signature changes, where a diagnostic code is
produced, ...). Record: accuracy against the compiler index where it applies, full index time, incremental update time, answer size
in tokens, what it does with `.psm`, whether it accepts an external backend or only a tree-sitter grammar, what its "memory" actually is
on disk (diffable text or an opaque database), and whether its language server would collide with `prismio-lsp`.

## Decision rule

- A candidate handles C and Python well, scales, and **accepts an external backend**: adopt it; write only the `.psm` backend from our index
  and a small separate tool for the committed layers above.
- None accepts a backend, or none scales, or the memory is opaque: build our own, with the shared architecture (SQLite or LMDB,
  tree-sitter, MCP, incremental) and the layer split above, starting with the Prismio backend and the diff-size test, then the Linux scale
  gate, then the agent interface, then notes, then a read-only web viewer. Tree-sitter backends: C and Python first.
- Either way: keep the upstream Graphify `.psm` pull request open and depend on nothing from it.

## Open decisions (needs the maintainer)

- Name, language of the core (Rust or Go for a single binary; TypeScript for the viewer) and repository location, if we build.
- Prismio first and generalise later (recommended), or general from day one.
- Whether the AI pass is in v1 or follows once the shard and provenance format is proven (recommended: after).
