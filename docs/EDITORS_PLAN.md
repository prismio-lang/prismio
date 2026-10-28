# Editors beyond VS Code and IntelliJ: Neovim, Emacs, Helix, Zed

Decided 2026-10-29. `prismio lsp` already serves every editor that speaks LSP (`docs/LSP_PLAN.md`), so none of these
needs language knowledge of its own. What each needs is a way to start the server, a filetype, and colour before the
server has answered. The one piece of real work is a **tree-sitter grammar**, which three of the four use.

## Rules

- **The compiler is still the language.** An editor package holds launch configuration and a grammar, never a table of
  library names, never an opinion about types. A feature missing in an editor is missing in the server.
- **One grammar, one set of queries, many editors.** Neovim, Helix and Zed read tree-sitter queries in slightly different
  dialects (capture names differ); keep one `highlights.scm` with the standard capture names and translate in each editor's
  package, never fork the grammar.
- **A grammar is a fourth description of the language** (after the compiler, the IntelliJ lexer and the TextMate grammar),
  so it has a gate: every program in `tests/` and `benchmarks/hosted/prismio/` parses without an `ERROR` or `MISSING`
  node, every `neg_*.psm` that is only a *semantic* error does too, and a token the compiler's `dump-tokens` lists that the
  grammar cannot produce fails. Without that gate it drifts, which is why it waited until syntax settled enough.
- **No repository is created or published without the maintainer saying so for that repository.** The plan names them;
  creating a public repo or opening a PR in someone else's (nvim-treesitter, Helix, zed-industries/extensions, MELPA) is the
  maintainer's call each time.

## What to build, in order

| # | Deliverable | Where | Estimate | Done when |
|---|---|---|---|---|
| 0 | **Server prerequisites.** Document `PRISMIO_INTERNAL_HOSTED=1` for any client (a project's own host can otherwise take the server over: the VS Code extension and the IntelliJ plugin both set it); read `workspaceFolders`, handle `workspace/didChangeConfiguration`; confirm the semantic-token legend and UTF-8 negotiation against Neovim 0.11, Helix and Zed. | `lsp/server.psm`, `docs/IDE_PROTOCOL.md`, editors docs page | 1 day | the `lsp_workspace` fixture has a two-folder case; the docs page says to set the variable |
| 1 | **`tree-sitter-prismio`**: `grammar.js`, `queries/{highlights,indents,folds,locals,injections,textobjects}.scm`, a `test/corpus`, `bindings`. External scanner only if needed (a `step` after a range; `>>` closing two generics; `if (...) {` with no semicolons; struct-variant patterns `E.V { a, b }`; `...name: T`; `Ptr<mut volatile T>`; contextual words such as `prop`, `async`, `scope`, `const`, `repr(C)`). | new repo `prismio-lang/tree-sitter-prismio` | 3 to 6 days | the gate above passes over the checkout, `tree-sitter test` passes, a script `tools/check_tree_sitter.py` in the compiler repo runs it when the CLI is installed |
| 2 | **Neovim.** `vim.lsp.config('prismio', {...})` + filetype + the parser registered for nvim-treesitter (a `User TSUpdate` autocmd with `install_info`, which needs no upstream PR), semantic tokens on, inlay hints toggle, format on save through `vim.lsp.buf.format`. A small repo only if the snippet outgrows the docs page. | docs page; optional `prismio-lang/nvim-prismio` | 1 day | opening `test/fixtures/demo` in Neovim 0.11 shows diagnostics, hover, completion, rename, references, code action (import) and tree-sitter colours |
| 3 | **Emacs.** `prismio-ts-mode` (tree-sitter, Emacs 29+) and `prismio-mode` (font-lock from the same tables as the TextMate grammar, for Emacs without tree-sitter), an `eglot-server-programs` entry that starts `prismio lsp` with the environment variable, indentation = the server's formatting (`eglot-format`). | `prismio-lang/prismio-mode` | 1 day | same demo project in Emacs 30 with eglot |
| 4 | **Helix.** A `languages.toml` block (language, `file-types`, `roots = ["build.ums"]`, language server with `PRISMIO_INTERNAL_HOSTED`, grammar `source = { git, rev }`), highlight/indent/textobject queries translated from step 1's. Helix has no TextMate fallback, so it waits on step 1. | docs page; optional PR to Helix | 0.5 day | demo project in Helix |
| 5 | **Zed.** A Rust-to-WASM extension: `extension.toml`, `languages/prismio/{config.toml,highlights.scm,brackets.scm,indents.scm,outline.scm}`, and an `impl zed::Extension` whose `language_server_command` finds `prismio` (setting, then `PATH`, then `~/.prismio/bin`) and starts `lsp` with the environment variable. | new repo `prismio-lang/zed-prismio` | 1 to 2 days | installed as a dev extension, demo project in Zed |
| 6 | **Docs and logs.** The editors guide gets one section per editor with the exact config; the developers' `tooling/` gets a page on the grammar (what its gate holds, how to regenerate), the plan's table is updated, CHANGELOGs. | `../website/apps/{docs,developers}` | 1 day | `verify-doc-examples.mjs` and `audit-content.mjs` pass in both apps |

Estimates are judgement, not measurement: about 9 to 13 days in all, of which the grammar is half. Steps 2 to 5 can be done
in any order once step 1 exists; Emacs and Neovim also work without the grammar (a generated Vim syntax file, font-lock) and
may be done first as a fallback, but the end state is the grammar everywhere.

## Risks

- **The grammar drifts.** Each syntax change in the compiler (a new contextual keyword, a new declaration form) must be
  followed by a grammar change and a corpus run; `check_tree_sitter.py` in the compiler's gate is what makes that cost
  visible. If the gate is not wired into `prismio gate`, the grammar is wrong within a month.
- **Zed and Helix differ on queries** (capture names, injection syntax). Budget a translation step rather than assuming
  step 1's queries drop in.
- **Semantic tokens** are the exact colours; tree-sitter is the instant ones. Neovim and Zed apply both, so check that the
  two palettes do not fight (the legend's token types map to standard groups).
- **Windows** is not covered by any of these (the server has run the fixtures there, no editor has).

## Not doing

Sublime (the LSP package pointing at `prismio lsp` is one docs sentence), Kate, Vim without LSP, JetBrains Fleet.
