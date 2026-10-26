# Prismio IDE protocol

The compiler exposes a file-based analysis boundary for editors and build tools:

```text
prismio check <source.psm|build.ums> [--diagnostic-format=json] [--partial]
                           [--overlay <file> <text-file>]... [--module <name>]
                           [--emit-index <file> [--complete <file.psm> <line> <column>]]
prismio fmt <source.psm>... [--check] [--write] [--range <from>:<to>]
prismio dump-tokens
prismio lsp
```

An editor should use `prismio lsp` (below), which runs the rest. The commands are documented
here because the server is made of them, and because a client that cannot speak LSP can use them directly.

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

Which program a file belongs to is the client's to find, or the server's (it does this for every
client, in `lsp/projects.psm`). The order: the file itself when it declares `main`; `--module
std.<leaf>` for a module of a standard library in a checkout; the `entry` of the nearest
`build.ums` target whose directory holds the file; a program found from the file's directory
upward (to the manifest's directory, or the workspace folder when there is none) that imports it by
the module name it has from there, the first by name; and the file alone.

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

**What it provides.** `textDocumentSync` (open, close, full-text change, save) and
`textDocument/publishDiagnostics`; hover (signature, documentation, type), definition, type
definition, references, document highlights, document and workspace symbols, signature help (with the
active parameter), inlay hints (the type of a `let` that does not write one, parameter names at call
sites), semantic tokens, folding ranges, `prepareRename` and `rename` (refused with a reason for a
keyword, a clash with a name already declared, or something that is not a name), code actions (the
"add import" quick fix, from the diagnostic's `data.addImport`), completion (members after a `.`, the
names in scope, the language's keywords), and `textDocument/formatting` and `rangeFormatting`
(`prismio fmt`). Capabilities are advertised only for what works; any other request answers `-32601`,
and notifications it does not know are ignored. `workspace/didChangeWatchedFiles` (`**/*.psm`,
`**/*.ums`, registered by the server after `initialized`) rechecks every open document, which is how
an edit made on disk reaches a document that imports the changed file.

**Requests wait for their analysis.** A feature reads the index of the program as of the text the
document now has. A request that arrives while a check is pending or running is kept until it ends
and then answered, and `$/cancelRequest` answers a waiting request with `-32800`. The answer to a
request is never about text older than the request.

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
`shutdown` / `exit`. A manifest (`build.ums`, language id `ums`) is a document like any other: its diagnostics
(`UMS####` codes) are `prismio check build.ums` over its current text, and completion offers the
blocks, keys and fixed values the manifest language accepts at the cursor.

## The semantic index

`check --emit-index <file>` writes JSON Lines about the program that was checked, after the run has
finished (a run that is killed leaves nothing a reader would take). Consumers must ignore unknown
kinds and fields; the index is internal to a toolchain (the server and the compiler ship together)
and may change with it, so it carries no version and is not a wire contract for third parties. What a
reader may rely on:

```json
{"k":"file","id":0,"path":"prog.psm","module":"","user":true}
{"k":"decl","id":0,"kind":"fn","name":"add","container":-1,"f":0,"l":1,"c":4,"n":3,"sl":1,"sc":1,"el":1,"ec":47,"user":true,"vis":"private","sig":"fn add(a: Int, b: Int) -> Int","ty":"Int","recv":"Int"}
{"k":"ref","f":0,"l":1,"c":40,"n":1,"to":1,"role":"read","ty":"Int"}
{"k":"arg","f":0,"l":2,"c":31,"p":"a","i":0}
{"k":"stats","decls":4,"resolved":3,"builtin":4,"unresolved":0}
```

- `file`: an id, the path as the compiler registered it, and whether it is the user's (`user`) or the
  library's.
- `decl`: every declaration (`fn`, `method`, `prop`, `struct`, `enum`, `variant`, `trait`, `field`,
  `param`, `let`, `import`, ...). `l`/`c`/`n` are the **name's** line, column and length; `sl`..`ec` the
  whole declaration. `sig` is the rendered signature, `ty` the type, `doc` the comment above it.
  `container` is the id of what holds it, or -1.
- `ref`: a use of a name. `to` is the declaration's id, -1 for a name the compiler provides
  (`builtin` says which kind), -2 when the use **is** a declaration's own name. `role` is `read`,
  `write`, `call`, `type` or `fieldwrite`, and `ty` the type of what it names.
- `arg`: a call's argument position, `p` the parameter's name and `i` its index.
- `unresolved`: a name that did not resolve (`name`, and `what` it was used as). The module that
  exports a candidate is not here: it is the `fix.addImport` of the note after the diagnostic, which
  is what the "add import" quick fix reads.
- `completion`: with `--complete`, what could be written at the placeholder (see below).
- Positions are 1-based lines and UTF-8 byte columns, as everywhere in the protocol. `stats` is last,
  and its absence means the run did not finish.

### Completion

The buffer at the cursor rarely parses, so a client does what rust-analyzer does: write a placeholder
identifier (`ixcursor__`) where the word being typed starts, check that buffer, and ask where the
placeholder is:

```text
prismio check src/main.psm --partial --overlay src/main.psm /tmp/buffer.psm \
    --emit-index /tmp/out.idx --complete src/main.psm 12 9
```

The `completion` records (`label`, `kind`, `detail`, `doc`, `rank`) are the members of the type before a
`.`, the names in scope, or the contents of a module; no list of library names is kept anywhere else.
The language's own keywords are not in the index: they come from `prismio dump-tokens`.

## Token tables

`prismio dump-tokens` prints the compiler's token tables as one JSON object (`schemaVersion` 1): the
keywords, word operators, literals, contextual keywords (with the context each is a keyword in), the
built-in types, the operators with their kinds, and the separators. Editors generate their lexers and
grammars from it (the VS Code extension's TextMate grammar is generated, and a test fails if it goes
stale) instead of copying the lists.

## Formatting

`prismio fmt <file>...` prints nothing and exits 0 when every file is formatted. `--check` exits 1 and
prints `would reformat <file>` for each that is not; `--write` rewrites them; `--range <from>:<to>`
(1-based lines) formats only those lines. Only whitespace moves; formatting a formatted file changes
nothing; the program's IR is the same before and after. `tools/check_fmt.py` holds it to all three over
every `.psm` in the repository and over damaged copies of them.

## Current boundary

Each `check` invocation is one process over files: unsaved text arrives through `--overlay`, any
number of files per run. The language server (docs/LSP_PLAN.md) keeps no analysis between runs and no
document text in memory, which is why its memory stays flat; the compiler runs per edit, in a child
process, and the cost of that is measured in the plan (an ordinary program is inside the 150 ms
debounce; the compiler checking itself takes 1.2 s).
