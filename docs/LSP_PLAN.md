# Language server: one engine, thin editors

`prismio lsp` is a Language Server Protocol server shipped inside the toolchain. The
IntelliJ plugin and the Phase 3 VS Code extension both become thin clients of it.

This plan fixes **where each piece of language knowledge lives**, what the compiler must
change before a server can exist, and the order to build it in.

**Status (2026-10-25): Phase 0 and Phase 1 are built.** `prismio lsp` serves diagnostics for
open files with unsaved buffers, debounced and cancelled, on one thread (`lsp/`); the contract a
client needs is in `IDE_PROTOCOL.md` ("The language server"). Not built: the semantic index and
every feature that needs it (Phase 2), `prismio fmt`, exported token tables, and both editors'
use of the server (the IntelliJ migration and the VS Code extension are separate work, picked
up from the section "Handing over to the clients" at the end).

## Why now

The IntelliJ plugin (`../intellij-plugin`, ~15.7k lines of Java) re-implements the
language: `symbols/` (3.5k lines: `TypeInference`, `SignatureParser`, `StdlibIndex`,
`CompilerIntrinsics`), `navigation/` (1.4k: a scope resolver), `completion/` (1.3k), a
formatter (0.7k) and two hand-written lexers. Every compiler feature then needs a second
implementation, and `docs/INTELLIJ_PLAN.md` is the backlog of what the plugin has not
caught up with. A VS Code extension on the same model would be a *third* implementation
(TypeScript). Two implementations that must agree is already a recurring cost; three is
not sustainable for one maintainer.

## What the reference projects teach

| Project | What it is | What to take | What not to take |
|---|---|---|---|
| **rust-analyzer** | The compiler-side engine, behind LSP | The layering and its invariants (below) | Salsa. A query database is a rewrite of the compiler's data flow; see "Incrementality" |
| **Kotlin LSP** (`Kotlin/kotlin-lsp`) | JetBrains' own answer to "VS Code needs Kotlin support": the IntelliJ engine behind LSP, a thin VS Code extension (`vscode-extension-core`, `vscode-language-kotlin`) | The conclusion: one engine, many editors | Reusing IntelliJ as the engine. Prismio has its own compiler, which is the better engine |
| **intellij-rust** | A native PSI plugin that re-implements Rust's frontend in Kotlin | Its *IDE glue*: project-model service, toolchain discovery, run configurations, lexer-first highlighting, modification-tracker caching | Its architecture. It is **deprecated** (README); JetBrains replaced it with a proprietary plugin. It is the model the Prismio plugin is already on, and the one this plan leaves |
| **LSP4IJ** (`redhat-developer/lsp4ij`) | LSP client for IntelliJ | A checklist of client features (completion, hover, semantic tokens, inlay hints, code lens, call hierarchy, rename, formatting, folding...) | - |

The request was to copy the Rust and Kotlin *plugins'* architecture. The part worth
copying is rust-analyzer's engine and Kotlin's decision to expose one engine over LSP.
intellij-rust's own architecture is "put the compiler in the plugin", and that is
what creates the duplication above.

### rust-analyzer invariants that apply to Prismio

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

- `exit()` calls in the frontend (25 before Phase 0; four reasons remain, see Phase 0). An
  `exit` after a flushed diagnostic is harmless to a *child* process, and would kill an
  in-process server. What Phase 0 removed for the child model is the information lost:
  one syntax error used to end the run, so every other error and any partial index went
  with it.
- About 90 module-level mutable globals, and a 256-file registry reset only by
  `diag_reset()`. Re-entering the frontend in one process needs a reset audit that nothing
  guarantees.
- Prismio is not garbage-collected. A daemon that analyses repeatedly must not accumulate.

A child gives crash isolation, a clean cancellation (kill it), no reset problem, and reuses
the boundary `IDE_PROTOCOL.md` already defines. rust-analyzer does the same for flycheck and
proc macros. The cost is process start per edit (a `hello` build is ~36 ms; whole-program
check of the compiler itself must be measured in Phase 1).

In-process analysis stays a later optimisation (Phase 5), behind the same interface.

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

1. **Debounce + cancel + last-good-index** (Phase 1). Most perceived latency.
2. **Per-file parse cache** keyed by content hash inside the child *if* it stays alive
   (Phase 5); imports are the only cross-file dependency of a parse.
3. **Body-independent item summary** (rust-analyzer's `ItemTree`): signatures change rarely,
   bodies constantly. Re-check only the edited function's body when the summary is
   unchanged. This is the invariant that makes large programs usable and needs sema to
   expose a per-function entry point (`semaFunction` exists at
   `src/sema/checker.psm`).

Measured 2026-10-25: `prismio check src/main.psm` over the compiler itself (136 files,
84k lines) takes **0.94 s** wall. That is the worst case in the repo, and too slow to run
per keystroke, but fine after a ~300 ms debounce for ordinary programs, which are far
smaller. So step 1 carries Phases 1-2, and the compiler's own source is the case that
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

## Compiler prerequisites (Phase 0)

These come first and are independently valuable (`prismio check` itself is better for them):

1. **No `exit()` on bad input in the frontend. Done 2026-10-25.** `Parser.fatal` reports and
   puts the parser in a dead state (parked on end of file); `parseModule` drops that
   declaration and resumes at the next one that begins a line. The lexer skips what it cannot
   read and keeps the token stream well formed; an unreadable import is skipped. Sema still
   does not run once an error exists (unless asked to, item 2), which is what keeps a malformed AST away from it by default. Left
   on purpose: the 25-error limit, a `P3299` stop for a parser that fails to stop (a missing
   `break`), an internal nesting overflow, and `build`'s stale-runtime check. The fuzz gate
   is `tools/check_truncation.py`; directed tests are `tests/neg_353`-`neg_355`. What it
   does *not* give yet: recovery inside a declaration (a broken method drops its whole
   `impl`), and a partial index, which needs item 2.
2. **Type checking over a broken program. Done 2026-10-25** as `check --partial`
   (IDE_PROTOCOL.md). Sema already reports every error rather than stopping, so it keeps a
   `typeInfo` on every node it could type; what stopped it was the driver, which gave up after
   any parse error. With the flag it runs over the declarations that parsed, and holds back
   only the `unknown ...` errors the dropped text could have caused. Found on the way and
   fixed: an unresolved operand also produced "operator requires numeric operands". Not done:
   the semantic index itself (`--emit-index`, Phase 2), which is what makes use of this.
3. **File registry not capped at 256. Done 2026-10-25**: 4,096, and `P1098` names the module
   it stopped at (a module past the old cap was parsed with file -1 and lost its locations).
4. **Token tables exported**: `prismio dump-tokens` (or generated into the plugin build),
   from `src/lexer/token.psm`, `src/ast/types.psm`, `src/parse/decl.psm`.
5. **`prismio fmt`**: move the formatter rules out of Java. The plugin's own findings (187 of
   271 files changed wrongly before its fixes; the token-preservation test cannot see spacing
   bugs) say the rules deserve a real home with a text-diff corpus test.

## Phases

Each phase ends with something a user can see and a gate that can fail.

**Phase 0: frontend that survives. Done 2026-10-25** (items 1-3; 4 and 5 below are Phase 1-2 inputs). Gate: damaged
copies of every `.psm` in the repo (cut, bytes deleted, stray brackets) make `check` end with
a summary line and never crash or hang (`tools/check_truncation.py`; 9,468 variants, none
failed, and with the loop exits removed it fails 90 of 5,884, so the net does catch
what it is for); byte-identical output for valid programs (351 programs in `tests/`, the
hosted benchmarks, and `src/main.psm` itself).

**Phase 1: server skeleton + diagnostics. Done 2026-10-25** (two items left: the IntelliJ
setting that switches its annotator to the server's diagnostics, which is client work, and the
Windows halves of the poll primitive, untested here). `std.input` byte read, `std/json.psm`,
`lsp/` with transport, document store, scheduler, child analysis, `publishDiagnostics`,
`$/cancelRequest`, `initialize` negotiation including position encoding. Gate: a scripted
LSP client (fixture with recorded request/response streams, rust-analyzer's "heavy test"
shape) passes; IntelliJ replaces its external annotator with the server's diagnostics
behind a setting.

**Phase 2: the index and the read-only features.** `--emit-index`; `documentSymbol`,
`workspace/symbol`, `definition`, `typeDefinition`, `references`, `documentHighlight`,
`hover` (type + docs), `signatureHelp`, `inlayHint` (let types, parameter names),
`semanticTokens`, `foldingRange`, `codeAction` (add import from `unresolved`). Gate: the
corpus test, reborn: every `.psm` of a checkout yields an index in which every `ref` has a
target in some `decl`, plus a differential test against the plugin's current resolver
while both exist.

**Phase 2b: completion** (placeholder-identifier mode), then `rename` (a reference set
plus conflict check), `prepareRename`.

**Phase 3: VS Code.** `vscode-languageclient`, a generated TextMate grammar, `build.ums`
tasks and a debug configuration. Anything that needs more than ~300 lines of TypeScript
signals logic that belongs in the server. Same server, no new language knowledge.

**Phase 4: IntelliJ migration.** Use the platform LSP API (available to all IntelliJ-based
IDEs from 2025.3 per JetBrains' announcement; not in Android Studio or open-source builds),
declared as an optional dependency so the plugin still loads elsewhere; LSP4IJ is the fallback
if a feature the platform API lacks is needed (spike this first, it decides). Delete the
duplicated Java as each feature reaches parity, one package per commit, with the
differential test as the gate.

**Phase 5: speed.** Only if measurement asks: a long-lived analysis worker with a parse
cache, then the body-independent item summary.

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
- **Platform LSP API feature gaps** (inlay hints, semantic tokens, code lens support differs
  by version): decided by a Phase 4 spike, not now.
- **Programs that take over ~300 ms to check** (the compiler itself takes 0.94 s) push
  Phase 5 forward; re-measure in Phase 1 with the server's real debounce.
- **`build.ums` has the same structure** (own language, plugin-side lexer, validator in Java).
  The server should speak both languages; plan it once Phase 2 shows the shape.
- **Protocol stability**: the index is internal to the toolchain (server and child ship
  together), so it may change freely. The LSP surface and `IDE_PROTOCOL.md`'s `check`
  JSON are the stable edges; per rust-analyzer's lesson, anything third parties might
  depend on needs an explicit version field before it has users.

## Handing over to the clients

The compiler side of Phase 1 is complete and committed. What a client session can rely on:

- **`prismio lsp`** over stdio, LSP 3.17, full-text sync, diagnostics only. The contract is
  `IDE_PROTOCOL.md`; `tests/lsp_client.py` is a working client in 130 lines, and the `lsp` fixture in
  `tests/test_runner.py` shows every behaviour it has (negotiation, positions, unsaved buffers,
  bursts, a crashed check, invalid input, memory).
- **IntelliJ.** Spawn `prismio lsp` through the platform LSP API (all IDEs since 2025.3, not Android
  Studio; spike LSP4IJ if a feature is missing). Keep its lexer-based highlighting, run configurations,
  wizard and settings. Then delete, in this order and one package per commit, with the old external
  annotator's output as the differential: `annotator/PrismioExternalAnnotator`, `PrismioCheckTarget`
  (the server decides the program now). The semantic features (`symbols/`, completion, navigation,
  imports, documentation, hints, formatter) wait for Phase 2's index; do not delete them yet.
- **VS Code (Phase 3).** `vscode-languageclient` starting `prismio lsp`; a TextMate grammar (the
  token tables are not exported yet, Phase 0 item 4, so generate it from the plugin's
  `lexer/PrismioLexer.java` and `lang/PrismioWords.java` for now and replace it when they are);
  tasks from `build.ums`. Anything over about 300 lines of TypeScript is logic that belongs in the server.
- **Do not hardcode the server path**: `prismio lsp` is the interface, it finds its own server, and
  `PRISMIO_LSP_CHECK` is only for tests.

Next for the compiler: Phase 2, the semantic index (`check --emit-index`) and the read-only
features on top of it, then `prismio fmt` and the exported token tables. The first concrete step is
the index schema in "The semantic index" above; the `--partial` mode is what lets it exist for
a file that is mid-edit.
