# The IntelliJ plugin

The plugin (`../jetbrains-plugin`, `prismio-lang/jetbrains-plugin`) is a client of `prismio lsp` (`docs/LSP_PLAN.md`).
It used to be a second implementation of the language, and this file was the backlog of what that implementation had not
caught up with. As of 2026-10-29 it is not: **a language change reaches the editor with the toolchain**, and the plugin is
~8,000 lines of Java where it was 15,700.

## What lives where

| Concern | Where |
|---|---|
| Errors, hover, completion, hints, parameter info, definitions (library included), usages, rename, highlights, outline, Go to Symbol, the import quick fix, Reformat Code | The server, from the compiler: `PrismioLspFeatures.SERVED` lists them |
| Colours, brackets, comment toggling, folding, live templates, typing and Enter indentation | The plugin, because they must answer before a server can: `lexer/`, `formatter/` (an indenter: spacing is `prismio fmt`'s), `handler/`, `folding/`, `highlighter/` |
| Run configurations, gutter run, New Project, the debugger's line breakpoints, `build.ums` colours | The plugin (`execution/`, `wizard/`, `debugger/`, `ums/`) |

Deleted, each after a differential held the server to it (the tests are in the plugin's Git history): `documentation/`'s
provider, `hints/`, parameter info and `completion/` (1,219 hover names, 320 hints, 1,910 call positions, 35 completion
tests); `navigation/` (3,961 resolved names: the server agreed on 3,941, and the other 20 were the plugin's mistakes);
`symbols/` and `imports/`; the spacing rules of the formatter (19 of 217 files that `prismio fmt` had formatted).

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

- Semantic tokens are not switched on in the IDE (`semanticTokens` is not in `SERVED`): colours of names are still the
  lexer's and the annotator's. The server's tokens are exact where the lexer guesses (`STDLIB_TYPES` is the one word
  table `dump-tokens` cannot check), and the cost is a flash of lexer colours before the first answer.
- Code lens, call hierarchy, type hierarchy, selection ranges: the server does not offer them.
- Seen in a real IDE (`runIde`, 2026-10-28): the server starting and stopping with the setting, diagnostics and the import
  fix. The rest of what is above is held by tests and, 2026-10-29, by a session at `runIde` noted in `docs/LSP_PLAN.md`.
