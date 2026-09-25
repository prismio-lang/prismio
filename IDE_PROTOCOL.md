# Prismio IDE protocol

The compiler exposes a file-based analysis boundary for editors and build tools:

```text
prismio check <source.psm> [--diagnostic-format=json]
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

## Current boundary

Each invocation is one process over files: unsaved text arrives through
`--overlay`, one file per run. Cancellation messages, symbol queries, completion
and long-lived workspace state are outside this protocol version; those require
a daemon or language-server protocol rather than more flags on a one-shot
compiler process.
