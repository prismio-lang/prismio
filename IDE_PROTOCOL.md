# Prismio IDE protocol

The compiler exposes a file-based analysis boundary for editors and build tools:

```text
prismio check <source.psm> [--diagnostic-format=json]
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
{"kind":"diagnostic","schemaVersion":1,"severity":"error","file":"src/main.psm","line":12,"column":5,"length":4,"message":"unknown name `item`"}
```

- `severity` is `error`, `warning`, or `note`.
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

## Current boundary

Version 1 reads files from disk. An editor should save changed Prismio files
before invoking it. Unsaved-buffer transport, cancellation messages, symbol
queries, completion and long-lived workspace state are intentionally outside
this first protocol version; those require a daemon or language-server protocol
rather than additional flags on a one-shot compiler process.
