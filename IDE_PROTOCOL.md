# Prismio IDE protocol

The compiler exposes a file-based analysis boundary for editors and build tools:

```text
prismio check <source.psm> [--diagnostic-format=json] [--partial]
                           [--overlay <file.psm> <text-file>] [--module <name>]
```

`check` runs the same lexer, parser, import resolver and semantic analysis as
`build`. It stops before allocation inference, LLVM IR generation and native
linking. It never creates or changes an output artifact.

The process exits `0` when analysis succeeds and non-zero when the source cannot
be read or the frontend reports an error. Warnings do not change the exit status.

## JSON diagnostics

`--diagnostic-format=json` writes one JSON object per line to stderr. JSON Lines
allows an IDE to display diagnostics as they arrive without waiting for the
compiler process to close an enclosing array.

Located and unlocated messages use this schema:

```json
{"kind":"diagnostic","schemaVersion":1,"severity":"error","code":"P4001","file":"src/main.psm","line":12,"column":5,"length":4,"message":"unknown name `item`"}
```

- `severity` is `error`, `warning`, or `note`. A `note` explains the diagnostic
  immediately before it, usually with no location of its own; show it with that
  diagnostic, not as a finding of its own.
- `code` is the stable `P####` compiler diagnostic identifier for errors and
  warnings. It is `null` for a secondary `note`. Consumers should key fixes and
  suppressions on this field rather than on message prose.
- `file` is the registered source path, or `null` for a command/toolchain error.
- `line` and `column` are 1-based. They are `0` when the message has no source
  location.
- `length` is the source span width in UTF-8 bytes. It is `0` for an unlocated
  message.
- `message` contains no terminal formatting or source snippet.

The final line is a summary:

```json
{"kind":"summary","schemaVersion":1,"errors":0,"warnings":0}
```

Consumers must ignore unknown fields and dispatch on `kind` and
`schemaVersion`. A plugin mapping spans into an editor's UTF-16 document model
must convert Prismio's UTF-8 byte columns and lengths before constructing text
ranges.

Human-readable diagnostics carry the same identifier, for example
`error[P4001]: initializer for count: expected Int, found Bool`. Codes are not
renumbered when wording changes; new sites receive new codes in their compiler
area (`P1xxx` CLI/toolchain, `P2xxx` lexer, `P3xxx` parser, `P4xxx` semantic
analysis, and `P5xxx` allocation inference).

## Checking one file of a program

A module is not a program, and checking it as one is wrong in two ways. Its
imports resolve against the directory of the program's entry, not its own:
`import lexer.token` in `src/parse/stmt.psm` is `src/lexer/token.psm`. And the
modules of a program share the names the merge gives the whole program, so a
module may use a type it never imports. Checked alone, such a file reports
errors it does not have.

So an editor checks the program the file belongs to, with its text overlaid:

```text
prismio check src/main.psm --diagnostic-format=json --overlay src/parse/stmt.psm /tmp/buffer.psm
```

- Wherever the program reads `src/parse/stmt.psm` -- as the entry, or through an
  import, including an import cycle -- it reads `/tmp/buffer.psm` instead. The
  file keeps its path: diagnostics name `src/parse/stmt.psm`, and a cycle back
  to it finds it already merged.
- Diagnostics from every file of the program are reported. An editor shows the
  ones whose `file` is the file being edited; errors elsewhere may have stopped
  the analysis before it reached this file's.
- A program that never reads the overlaid file reports warning `P1075` and says
  nothing about it. Try another program; the file alone is the last resort.
- Put `--diagnostic-format=json` first: a compiler that rejects a later
  argument (one from before `--overlay`, with `P1026`) then already speaks JSON.

A module with no program at hand -- a standard-library module the program does
not import -- is checked alone under the name its importers use:
`prismio check std/map.psm --module std.map`. The name is what gives the file
its package's access to that package's internals.

Which program a file belongs to is the editor's to find. The IntelliJ plugin
tries, in order: the file itself when it declares `main`; `--module std.<leaf>`
for a module of a standard library; each `entry` in the nearest `build.ums`; a
program in the file's directory or an ancestor that imports it by the module
name it has from there; and the file alone.

## Checking a file that does not parse

A file open in an editor is syntactically broken most of the time it is being edited. Every
lexical, syntax and import error in the program is reported in one run: the parser gives up on
the one declaration it cannot read and resumes at the next that begins a line, a stray character
or bad escape does not end the scan, and an import that cannot be read is skipped.

By default type checking then does not run, as before: a program with a declaration missing
produces cascades, not information. `--partial` runs it anyway, over the declarations that did
parse:

```text
prismio check src/main.psm --diagnostic-format=json --partial
```

- A type error in a function that parsed is reported beside the syntax error in another.
- An `unknown ...` error (`P4001`) is held back when it names an identifier that appeared in
  text the parser dropped, and **all** of them are held back once an import could not be read
  (any name may have come from it). Held back, never wrong: a real typo is shown again as soon
  as the text parses or the import resolves. These are the only diagnostics `--partial`
  suppresses.
- The exit status and the summary line mean what they always did.

Without the flag the output is exactly what it was. `build` never type checks a program that
failed to parse.

## The language server

`prismio lsp` speaks the Language Server Protocol 3.17 over standard input and output. It is
the boundary an editor should use: it checks the right program for the open file, with every
unsaved buffer, and keeps up with typing. The one-shot `check` above is what it runs.

```text
prismio lsp          # started by the editor, no arguments
```

**What it provides (version 1):** `textDocumentSync` (open, close, full-text change, save) and
`textDocument/publishDiagnostics`. Hover, definition, completion and the rest are not offered yet;
the server answers any request it does not implement with `-32601`, and ignores notifications it
does not know. Capabilities are only advertised for what works.

**Diagnostics.** After the client has been quiet for 150 ms the server checks the program the
changed file belongs to (the file itself if it declares `main`, else the nearest `build.ums` entry
whose directory holds it, else the file alone; a standard-library module in a checkout is checked
alone under its module name) with `--partial`, and every open document's text overlaid. Results
are published per file, with the document `version` it was computed for, `source: "prismio"`, the
`P####` code as `code`, severity error or warning, and a compiler note appended to its
diagnostic's message on a line of its own. A file that had diagnostics and no longer does gets an
empty list. A check that is killed or crashes publishes nothing and is reported with
`window/logMessage`: the last answer stays. An edit while a check runs kills it and starts over.

**Positions.** `initialize` negotiates `positionEncoding`: `utf-8` when the client offers it,
else `utf-16`. The conversion from the compiler's byte columns happens in one place
(`lsp/positions.psm`).

**Process.** The server is a program of its own, `prismio-lsp`, installed beside `prismio`;
`prismio lsp` replaces itself with it, so a client needs no other path. `PRISMIO_LSP_CHECK` names
a different executable to run the checks (tests, or an editor that wants another build to do the
checking). Exit status follows the protocol: 0 after `shutdown` and `exit`, 1 otherwise. It keeps
no document text in memory (each open document's text lives in a scratch file, which is also the
overlay the compiler reads), so its memory stays flat however long it runs and however large the
file; `tests/test_runner.py` (`lsp`) holds it to that.

**Writing a client.** The test client `tests/lsp_client.py` is a complete example of the wire
format. A client needs: spawn `prismio lsp`, `initialize` / `initialized`, `didOpen` for each open
`.psm` file, `didChange` with the whole text (`contentChanges[-1].text`), `didClose`, and
`shutdown` / `exit`. `build.ums` is not analysed yet: opening it produces no diagnostics.

## Current boundary

Each `check` invocation is one process over files: unsaved text arrives through
`--overlay`, any number of files per run. Symbol queries, completion and hover are not
part of it; they are the language server's to answer (docs/LSP_PLAN.md, Phase 2).
