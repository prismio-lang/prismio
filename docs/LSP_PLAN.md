# Language server: one engine, thin editors

`prismio lsp` is a Language Server Protocol server shipped inside the toolchain. The two editors Prismio supports, the
IntelliJ plugin (`../jetbrains-plugin`) and the VS Code extension (`../vscode-plugin`), are thin clients of it; no other
editor is supported or planned. **Anything that would otherwise be written twice (Java and TypeScript) belongs to the
compiler or the server.**

What it serves: diagnostics with unsaved buffers, and from the semantic index (`check --emit-index`) hover, definition
(into the library's source too, `prismio library-source`), type definition, references, highlights, outline, workspace
symbols, signature help, inlay hints, semantic tokens, folding, rename and the import quick fix; completion by
placeholder (`check --complete`); formatting through `prismio fmt`; and for `build.ums` its diagnostics and completion.
The contract is `IDE_PROTOCOL.md`; the architecture and the memory rules are the developer docs' *The language server*;
`docs/INTELLIJ_PLAN.md` says what lives in the IntelliJ plugin.

## Measured latency (2026-10-26)

Edit to published diagnostics, 150 ms of it the debounce: 2 lines 162 ms; one 99 KiB function 177 ms; a test
program 167 ms; one module of the compiler (136 files, 85,000 lines) **1,225 ms**. Ordinary programs sit
inside the debounce, so the parse cache and the item summary ("Incrementality") stay unbuilt until a program
that size is the common case.

## Memory (2026-10-26)

`lsp_features`: 130 rounds of hover, outline, tokens, hints, references and completion on a 99 KiB document grow
the server by about 450 KiB (limit 6,000). Two defects were found by bisecting it: a `readLines` loop left by
`return` leaves its descriptor and 64 KiB buffer open (RSS grew 66 KiB a request), and `substring` of the
document in `completionItems` made every request path that held the document leak a copy; `slice` is the same
cut. A manifest is never loaded on a request path (its lexer leaks about 20 KB a call): see KNOWN_ISSUES.

## Open

What is not done or not seen. "Verified" means run for real on this Mac (Apple Silicon, macOS 27).

What a later session must not assume. "Verified" means run for real on this Mac (Apple Silicon, macOS 27) this session.

| Item | State | How to verify or finish it |
|---|---|---|
| **Windows** | The suite passes there (the ARM64 VM) apart from `test_298_ptr_atomics`, a link error for `__atomic_*` that is the under-aligned `Ptr<U64>` atomic of `KNOWN_ISSUES.md`. **Not run:** an editor on Windows, long runs. A path in a spelling other than the two the server canonicalises (8.3 names, a directory in other case) still will not match. | An editor on the VM; then 8.3 names and path case in `overlayKey` (`src/driver/imports.psm`). |
| **IntelliJ in a real IDE** | Used in the `runIde` sandbox (IntelliJ IDEA 2026.2.1): every feature the plugin serves, semantic colours, usage highlighting, folding, the breadcrumb, and hints surviving a half-typed line. **Not seen:** WebStorm, CLion and the other IDEs. | `./gradlew --offline -I init.gradle runIde` with `PRISMIO=<toolchain>/bin/prismio` and an init script that sets the project; the sandbox window needs full-screen computer control to click and type. |
| **VS Code** | Built, with the extension's and `.psm`'s logos, and exercised by 11 end-to-end checks in the installed VS Code, but **not used by hand** and the icons not looked at in a window: the computer-use grant for an editor is click-only. The `.vsix` is **not published** (no listing on the Marketplace or Open VSX; that needs the maintainer's account and token). No grammar for `build.ums`. Windows untested. | Open `../vscode-plugin/test/fixtures/demo` in the Extension Development Host (F5) and use it for a session; publish after that, then change the docs' install line and the extension's README. |
| **Server speed** | 162-177 ms for ordinary programs (150 ms of it the debounce), 1.2 s for the compiler checking itself. No cache built. | Only if a large program becomes ordinary: a parse cache in a long-lived worker, then the body-independent item summary. |
| **Workspaces** | Only `rootUri` is read; several workspace folders, `workspace/didChangeConfiguration` and per-folder settings are not handled. | Read `workspaceFolders`; the importer search's stop directory is the part that depends on it. |
| **Manifest loader** | Leaks about 20 KB a call (`KNOWN_ISSUES.md`); the server never loads a manifest on a request path for that reason (child process; cache per file change). | Fixing the ownership of a `Vec` of structs that hold strings removes the workaround's reason, not its benefit. |

## Invariants (from rust-analyzer) that apply to Prismio

1. **Parsing never fails**: `(tree, errors)`, never `Result`. The editor lives in broken
   code.
2. **The `ide` boundary is plain data** in editor terms (offsets, labels), serializable,
   with no compiler types leaking. Only one module knows JSON and LSP.
3. **The server is stateless per request**: a request carries enough to be answered from
   scratch (a completion resolve re-sends its parameters).
4. **Cancellation**: a new edit invalidates in-flight work; results of stale revisions are
   dropped, never published.
5. **Typing inside a function body must not invalidate facts about other functions.**
6. **Partially available when the build is broken**: keep serving from the last good state.
7. **Transport and analysis are separate processes where isolation pays** (flycheck,
   proc-macro server).

## The split

Rule: **anything that would otherwise be written twice (Java and TypeScript) belongs to the
compiler or the server.** An editor client owns only presentation and platform glue.

| Concern | Owner | Notes |
|---|---|---|
| Lex, parse, sema, diagnostics, codes | Compiler | exists (`check`) |
| Name resolution, types, signatures, docs | Compiler | emitted as the **semantic index** |
| Which program a file belongs to (`build.ums` entries, importers, `--module std.x`) | Compiler/server | today `PrismioCheckTarget.java`; moves to `ums/` |
| Formatter | Compiler (`prismio fmt`) | today a Java `SpacingBuilder`; a CLI and LSP `formatting` need the same one |
| Token tables (keywords, operators, contextual keywords) | Compiler, exported | today hand-copied into `PrismioLexer.java` / `PrismioWords.java`, guarded by a corpus test |
| Hover, definition, references, rename, symbols, highlights, signature help, completion, inlay hints, semantic tokens, code actions, folding | Server, from the index | |
| Document store, debounce, cancellation, scheduling | Server | |
| Instant lexical highlighting, brace matching, typing/enter handlers, comment toggling, live templates | **Editor** | latency-critical, must work before any server answers (intellij-rust does the same: lexer first, semantics overlaid) |
| Run configurations, gutter run, New Project wizard, debugger, toolchain settings, color schemes | **IntelliJ plugin** | VS Code gets `tasks.json`/`launch.json` equivalents from `build.ums` |
| TextMate grammar for VS Code | Generated from the compiler's token tables | one source, no hand copy |

What the IntelliJ plugin can delete once the server covers it: `symbols/`, the semantic half
of `completion/`, `navigation/`'s resolver, the external annotator, `imports/` (code
actions), `documentation/`, `hints/`, the formatter: roughly **7k of its 15.7k lines**.
`ums/` (2.4k) stays until `build.ums` gets the same treatment, which is a second, smaller
instance of this plan (the `ums/` module is already Prismio code).

## Architecture

```
 editor ──LSP/stdio──▶ prismio lsp ─┬─ transport      (framing, JSON-RPC, positions)
                                    ├─ documents      (overlay of unsaved text)
                                    ├─ projects       (file → program, from build.ums)
                                    ├─ scheduler      (debounce, revision, cancel)
                                    ├─ index cache    (last good index per program)
                                    ├─ handlers       (answer from the index)
                                    └─ analysis ──spawn──▶ prismio check --emit-index
                                                           (one program, one process)
```

**Analysis runs in a child process, per program, per revision.** This is the central
decision and it is forced by the compiler as it stands:

- `exit()` calls in the frontend (four reasons remain: the error limit, a `P3299` stop for a parser that fails to
  stop, an internal nesting overflow, and `build`'s stale-runtime check). An `exit` after a flushed diagnostic is
  harmless to a *child* process, and would kill an in-process server. A syntax error no longer ends the run: the parser
  drops the declaration, or inside a body the statement, it cannot read and goes on (`check --partial` then checks the
  rest), so every other error and a partial index survive.
- About 90 module-level mutable globals, and a 256-file registry reset only by
  `diag_reset()`. Re-entering the frontend in one process needs a reset audit that nothing
  guarantees.
- Prismio is not garbage-collected. A daemon that analyses repeatedly must not accumulate.

A child gives crash isolation, a clean cancellation (kill it), no reset problem, and reuses
the boundary `IDE_PROTOCOL.md` already defines. rust-analyzer does the same for flycheck and
proc macros. The cost is process start per edit (a `hello` build is ~36 ms; whole-program
check of the compiler itself: 1.2 s, see "Measured latency").

In-process analysis stays a later optimisation, behind the same interface.

### The semantic index

`prismio check <entry> --emit-index` writes JSON Lines after the diagnostics (a new `kind`;
consumers already ignore unknown kinds):

- `file`: id, path, module name.
- `decl`: id, kind (fn, struct, enum, variant, trait, impl, field, param, let, import, ...),
  name, container id, file, full span, name span, visibility, rendered signature, doc text.
- `ref`: span, target decl id, role (read, write, call, type position).
- `type`: span of each `let`/expression the editor may ask about, rendered type.
- `member`: for each type, its members as visible from a given module (what completion after
  `x.` offers, including uniform-call-syntax functions).
- `unresolved`: spans of names that did not resolve, with the module that exports a
  candidate (the data an "add import" code action needs).

Everything the plugin guesses today (`TypeInference`, `CompilerIntrinsics`, "validated once
per compiler binary by a probe") is a fact sema already computed: `ASTNode` carries
`line`, `col`, `len`, `file` and `typeInfo`. The index is a serialisation of it. No
hardcoded library members anywhere (an existing rule of the plugin, now enforced by
construction).

Completion needs more than the last good index: the buffer at the cursor does not parse.
Follow rust-analyzer: the server inserts a placeholder identifier at the cursor, analyses
that overlay, and asks the child for `--complete <offset>`. Same child, one extra flag.

### Positions

Prismio spans are 1-based line, UTF-8 byte column and byte length. The server offers
`positionEncoding: utf-8` when the client supports it (VS Code can; IntelliJ's client speaks
UTF-16). **The conversion lives in exactly one module of the server**, replacing the
conversion the plugin does today.

### Incrementality

Do not start with a query database. Order by return on effort:

1. **Debounce + cancel + last-good-index** (built). Most perceived latency.
2. **Per-file parse cache** keyed by content hash inside the child *if* it stays alive
   (not built); imports are the only cross-file dependency of a parse.
3. **Body-independent item summary** (rust-analyzer's `ItemTree`): signatures change rarely,
   bodies constantly. Re-check only the edited function's body when the summary is
   unchanged. This is the invariant that makes large programs usable and needs sema to
   expose a per-function entry point (`semaFunction` exists at
   `src/sema/checker.psm`).

Measured 2026-10-25: `prismio check src/main.psm` over the compiler itself (136 files,
84k lines) takes **0.94 s** wall. That is the worst case in the repo, and too slow to run
per keystroke, but fine after a ~300 ms debounce for ordinary programs, which are far
smaller. So step 1 carries it, and the compiler's own source is the case that
motivates step 3.

### Where the server is written

In Prismio, as `lsp/` beside `ums/`, built as **its own program, `prismio-lsp`**, installed
beside `prismio`; `prismio lsp` replaces itself with it. Versioning follows the toolchain,
which is the property the plugin works hard for today ("completion and error checking follow
the version of the compiler you pick"). Both editors only need to spawn one command.

**It is not part of the compiler binary, and that is a measured decision.** The ownership
analysis is whole-program and shares one allocation site per library function. The compiler stores
`substring` and `concat` results in containers throughout its 85,000 lines, so linked into it every
string the server read from a message was treated as escaping and never released: a 99 KiB document
leaked several copies of itself per keystroke, 515 MB at open, 2.2 GB after twenty edits, then the
operating system killed the process. Built alone, the same code releases everything. The `prismio lsp`
command, which is the interface, is unchanged by this.

What the missing pieces turned out to be, and what was built (all in `std/`, all used by the
server, none specific to it):

| Needed | Built |
|---|---|
| exactly N bytes of stdin, for `Content-Length` framing | `std.input.readBytes`, through the line reader's own buffer |
| wait on stdin and a child's pipe, with a timeout | `std.poll.waitReadable` (`poll(2)`; `PeekNamedPipe` on Windows, untested here) |
| read what a child has written so far; ask if it has exited | `Stream.readSome`, `Child.tryWait` |
| JSON | `std.json`: a tape reader, strict RFC 8259, and a writer |
| binary stdio on Windows, own executable path | `useBinaryStdio`, `executablePath` |
| several unsaved buffers per check | `check --overlay` repeated; `--partial` |

Compiler defects found and fixed along the way: storing a variable into an `Int?` stored 0
(`std.json` found it); `check` stopped at the first syntax error; an unresolved operand also
reported "operator requires numeric operands"; a program could read only 256 files, and a module
past that lost its diagnostic locations.

**Rules the server code follows because the ownership analysis requires them** (found by
measuring; the allocation ledger, `--verify`, and its *peak live bytes* are how):

1. A function returning a `String` allocates it on every path. `return ""` makes the whole result
   unowned and leaks the others (`"".clone()`).
2. Do not store a library result (`substring`, `trim`) in a container as it is: push a `.clone()`.
3. Private functions share one namespace across the merged program: prefix them (`uriHexDigit`).
4. **Replace nothing in a `Vec<String>` or a struct field.** A Vec element store, `removeAt` or
   `pop` keeps the displaced value until the Vec dies, and a field store through `self` never
   releases it; a local `let mut` binding does. This is why a document's text lives in a file, and why
   the ledger read clean while memory grew: its exit-time total counts parked values as released.
   Use *peak live bytes*, and watch the process, not only the ledger.
5. Build large strings in two passes over one allocation (`str_with_capacity` plus
   `__builtin_string_put_byte`, `std/` only). Appending with `concat` in a loop is quadratic.

Measured result with those rules: 1,200 edits of a 99 KiB document hold the server at 2.8 to 3.0 MB;
a small document grows 0.27 KB per edit; an edit reaches published diagnostics in 160 ms, of which
150 is the debounce.

## Testing

- **Protocol tests**: recorded LSP sessions (initialize, edit sequences, cancellation) replayed
  against `prismio lsp`, golden output. Typed messages make protocol-only bugs rare; keep
  these few.
- **Index tests** (the important layer): data-driven fixtures, `.psm` plus expected index,
  updatable like the existing suites.
- **Corpus test**: all repo `.psm` files must index with zero dangling refs. This is what
  the plugin's lexer corpus test taught: drift is caught by running everything real.
- **Vacuity guard** on every one of these (`prismio-vacuous-guards`): each test must first assert
  it exercised something (decl count above zero, a diagnostic produced) or it will pass
  against a server that does nothing.
- **Fault injection**: kill the child mid-analysis, send garbage, close stdin; the server must
  stay up.

## Risks and open questions

- **Writing the server in Prismio is a bet.** It dogfoods the language and makes
  distribution trivial, and it also puts a young runtime in a long-running process. The
  child-process boundary limits the damage: the front is thin and replaceable.
- **Platform LSP API feature gaps**: the IntelliJ client's defaults are plain text only for rename, highlights, formatting
  and semantic tokens (`PrismioLspFeatures` overrides each); code lens, call and type hierarchy and selection ranges are
  not offered by the server.
- **Programs that take over ~300 ms to check** (the compiler itself takes 1.2 s) would make the parse cache and the item
  summary worth building; none is the common case.
- **Protocol stability**: the index is internal to the toolchain (server and child ship
  together), so it may change freely. The LSP surface and `IDE_PROTOCOL.md`'s `check`
  JSON are the stable edges; per rust-analyzer's lesson, anything third parties might
  depend on needs an explicit version field before it has users.

