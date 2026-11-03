# The IntelliJ plugin

The plugin (`../jetbrains-plugin`, `prismio-lang/jetbrains-plugin`) is a client of `prismio lsp` (`docs/LSP_PLAN.md`).
**A language change reaches the editor with the toolchain**: the plugin implements none of the language.

## What lives where

| Concern | Where |
|---|---|
| Errors, hover, completion, hints, parameter info, definitions (library included), usages, rename, highlights, outline, Go to Symbol, the import quick fix, Reformat Code | The server, from the compiler: `PrismioLspFeatures.SERVED` lists them |
| Colours, brackets, comment toggling, folding, live templates, typing and Enter indentation | The plugin, because they must answer before a server can: `lexer/`, `formatter/` (an indenter: spacing is `prismio fmt`'s), `handler/`, `folding/`, `highlighter/` |
| Run configurations, gutter run, New Project, the debugger's line breakpoints, `build.ums` colours | The plugin (`execution/`, `wizard/`, `debugger/`, `ums/`) |

## What a language change costs the plugin now

1. **A new word, type or operator:** `prismio dump-tokens` has it; `PrismioTokenTablesTest` fails until
   `lang/PrismioWords.java` and the lexer agree. (It found `...`, which lexed as a range and a dot, the day it was written.)
   `PrismioLexerCorpusTest` and the compiler's `tests/` catch a construct the lexer misreads.
2. **Anything else** (a declaration form, a type, a call shape): nothing, provided the compiler's index
   (`src/index/`, held to 359 programs by `tools/check_index.py`) names it. If the editor misses a name, the fix is a
   reference in the walker, not a table in Java.
3. **`build.ums`:** `ums/UmsWords.java` and `UmsLexer.java` follow `ums/model/lowering.psm` and `ums/parser/lexer.psm`
   (the colours; the manifest's diagnostics and completion are the compiler's, `lsp_manifest`).

## Open

- The lexer keeps its word tables, `STDLIB_TYPES` included, because they colour before the server has answered and wherever
  it cannot (no compiler found, a file outside any program); the server's semantic tokens replace them once they arrive.
  `STDLIB_TYPES` is the one table `dump-tokens` cannot check, and only a first guess.
- Code lens, call hierarchy, type hierarchy, selection ranges: the server does not offer them.
- Not seen in a real IDE: WebStorm, CLion and the other JetBrains IDEs.
