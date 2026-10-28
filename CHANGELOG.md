# Changelog

This file records what is changing in **0.2.0**, the release being prepared. It does not carry earlier
releases: those are on the [release notes page](https://docs.prismio.org/releases). The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/) (pre-1.0, so a minor release may still break things).

## [0.2.0] - Unreleased

### Added

- **The compiler's version is `project.version` in build.ums, read through `import build`.** `PRISMIO_VERSION` in
  `src/main.psm` is gone; `--version`, the AST and AIF dumps, the debug-info producer string, `prismio init`'s `prismio =` line
  and the `prismio = "X"` requirement check read `BUILD_VERSION`, so a release is bumped in one place. The compiler therefore
  reports `0.2.0` (the manifest's version) where it had reported a separately kept `0.1.0`; the test runner and
  `tools/release.py` take the number from the manifest and the compiler rather than repeating it. Using `import build` in
  `src/` is the first thing the committed seed cannot parse: `bootstrap/seed.ll` was refreshed (`prismio seed`, a fixpoint of
  IR between two generations) and is left uncommitted as always, so a bootstrap from the *committed* seed fails until that
  refresh is committed.

- **`const` and `enum` in `build.ums`, and `import build` to read the manifest from code.** `const VERSION = "${MAJOR}.2.0"`
  names a value (a string, integer, boolean or flat array) for use wherever a value is written -- an assignment, a call
  argument, an array item -- and `${NAME}` inside a string interpolates one (`$$` is a literal `$`). `enum Channel { STABLE =
  "stable", BETA }` fixes a set, and `Channel.BETA` is a variant's value or its name; a variant that is not declared is an
  error. A declaration is resolved against those above it, a use sees all of them, and `toolchain` takes literals only
  because the installed compiler reads it before any of this exists (`umsResolveConstants`, `UMS1201`-`UMS1209`). Both are
  gone before lowering, so no later phase changed. `import build` gives a program `BUILD_NAME`, `BUILD_VERSION`,
  `BUILD_VERSION_MAJOR`/`MINOR`/`PATCH`, `BUILD_PRISMIO`, `BUILD_DESCRIPTION`, `BUILD_LICENSE`, `BUILD_LICENSE_FILE` and
  `buildAuthors()`, or `import build.BUILD_VERSION` for one: `build` is a reserved import root whose source the compiler
  writes in memory from the manifest above the entry file (`mergeBuildModule`), so nothing is generated on disk and it cannot
  be stale (`P1117` for a project module of that name, `P1118` for no usable manifest). The values are globals and not
  `build.version` because a module name does not reach a global and a property may not return a `String`. `ums/test_ums.psm`
  has the resolver's cases and its mistakes, `test_364` and `test_365` read this checkout's own manifest.

- **A `codeset` needs no written type: it gets the smallest integer type that holds all its entries.** `codeset Status { Ok = 200,
  NotFound = 404 }` is a `U16` codeset: `U8` when every entry is 0 to 255, then `U16`, `U32`, `U64`, and `I8`, `I16`, `Int`, `I64`
  when any entry is negative. It is chosen from the numbered values (`discInferredName`, so `400 + 18` and implicit entries count),
  recorded on the declaration as if it had been written, and from there every constant, cast and range check is the same. A written
  type is kept and still checked (`codeset Tight: U8 { B = 300 }` is still an error). It used to be an error to leave it out
  ("a codeset needs a representation type"); `tests/test_360`, `neg_361`-`neg_363` replace `neg_324`.

- **`prismio fmt` takes folders, and any number of them.** `prismio fmt --check src std lsp` and `prismio fmt --write src
  tests/test_1.psm` name files and folders together; a folder stands for every `.psm` file under it, searched recursively in
  name order, with hidden folders (`.git`, `.prismio`) inside it skipped (one named on the command line is searched) and a
  trailing slash normalised (`fmtCollect`). A folder used to be read as an empty file, which formats to itself, so
  `prismio fmt src --check` exited 0 without looking at anything; in CI that passed whatever the code looked like. The `fmt`
  fixture holds folders, files mixed with folders, hidden folders, other extensions and an empty folder. The CLI page said a
  flag-less `fmt` prints nothing; it prints the formatted text, and says so now, with `--stdin`, which it had left out.

- **`prismio fmt` writes an `if` that has an `else` over several lines.** The branches of `if (a) { b() } else { c() }`,
  and of an `else if` chain, each begin a line of their own with `} else {` kept together (`fmtBranchBreaks`, the one place
  the formatter splits a line; it still never joins one). An `if` with no `else` stays as written, an empty branch stays
  `{ }`, and a chain that is half typed (`else` with nothing after it) is left exactly as it is. `tools/check_fmt.py` keeps
  its "the program is the same" rule byte for byte, and compares with source positions masked (`$repeat_132_5`, the line a
  `step` check reports) only once some file has really moved. The language server's formatting is this command, so the
  JetBrains plugin's Reformat Code now follows it. 9 ms for a 6,000-line file over the server.

- **`std.io` is four variadic functions, and `std.display` is no longer needed to print.** `print`, `println`,
  `eprint` and `eprintln` take any number of values of any builtin type or the optional of one (`String?`, `Int?`,
  …), written once over a `typelist` instead of as about 100 overloads (`std/io.psm` 674 lines → 412). A
  `println(n)` is still the one formatter and the one `write` it was: the same output, and 0.26 s user against
  0.26-0.27 s for three million lines, 1.01 s against 1.01-1.02 s for a mixed four-value line. `std.display` is
  for a type of your own (`impl Display`) and for `${}`; a call with only builtin values never reaches it.
  `println()` and `eprintln()` stay fixed overloads.

- **Functions of one name that each have a pack are overloads.** A call goes to the pack whose typelist accepts
  every argument; the pack of concrete types wins over a trait-bounded one, then the first declared, and a fixed
  overload beats any. When none fits the error is the first pack's, as before. It is what lets `std.io`'s
  `println` and `std.display`'s share a name. `sema/packs.psm` (`packChooseTemplate`), `tests/test_358`, `neg_360`.

- **A `typelist` entry can be optional.** `typelist Maybe { Int?, String? }` lists `Int?` as a type of its own,
  distinct from `Int`: a set accepts either or both, a sequence takes one at its position, `for` and `f(...args)`
  work as for any entry, and `Int` and `Int?` in one list are not a duplicate. A trait or a list written with a
  `?` (`Display?`) is an error at the declaration. Before, the `?` was dropped and `{ Int, Int? }` was refused as
  listing `Int` twice. `sema/typelists.psm` only; `tests/test_357` and `neg_357`-`neg_359`. It is what lets `std.io`
  take every printable scalar and its optional in one pack.

- **`prismio lsp`: a language server.** LSP 3.17 over standard input and output: document synchronisation and
  `publishDiagnostics`, computed by the compiler itself. After the client is quiet for 150 ms it runs `prismio
  check --partial` over the program the edited file belongs to (the file if it declares `main`, else the nearest
  `build.ums` entry, a standard-library module under its module name) with **every open document's unsaved text
  overlaid**, publishes per file with the document version and the `P####` code, clears files that became clean, and
  keeps the last answer if a check is killed or crashes. An edit while a check runs kills it. One thread: it waits on
  the client and the running check together (`std.poll`), so cancellation is a `kill`. Columns are UTF-8 when the
  client offers it, else UTF-16, converted in one place. It is a program of its own, **`prismio-lsp`**, beside
  `prismio` (`build.ums` target `prismio-lsp`, built by `tools/package.py`, copied by `tools/run_suite.py`);
  `prismio lsp` replaces itself with it (`P1099` if it is missing). Not part of the compiler binary on purpose:
  linked into it, the whole-program ownership analysis never released the strings the server read, and a 99 KiB
  document leaked several copies of itself per keystroke (515 MB at open, 2.2 GB after twenty edits). Built alone it
  holds 1,200 edits of a 99 KiB document at 2.8-3.0 MB. Document text is kept in a file per document, not in memory
  (a `Vec` element store parks what it displaces). `check --overlay` now takes any number of buffers. `lsp/`,
  `IDE_PROTOCOL.md` ("The language server"), `docs/LSP_PLAN.md`; the `lsp` fixture in `tests/test_runner.py` (negotiation,
  positions in both encodings, unsaved buffers, partial analysis, a burst of 40 edits, a killed check, invalid input,
  memory) with the Python client `tests/lsp_client.py`. Diagnostics only so far; hover, definition and completion
  need the semantic index (Phase 2 of the plan). `std.fs.executablePath()` and `std.process.useBinaryStdio()` came with it.

- **The semantic index: `check <entry> --emit-index <file>`.** JSON Lines after the run: every declaration (kind, name
  span, whole extent, signature as written, comment above, type, owner, receiver), every use of a name resolved to its
  declaration (calls by sema's symbol, fields, variants, locals with their scopes, closures' captures, generics' templates),
  the parameter each argument fills, and `unresolved` for a name that is nothing (`src/index/`). Indexing the compiler itself
  (85,000 lines, 21,000 declarations, 114,000 references) costs 0.1 s over a plain check. `--complete <file> <line> <col>` adds
  what could be written at a placeholder (members after a dot, names in scope, a module's contents, a Vec's builtins).
  A missing-import error now carries `fix.addImport`. `--partial` no longer stops at 25 errors. Held to the text by
  `tools/check_index.py` (353 programs, std modules and the compiler: no dangling reference, every name under a span is the
  name it points at, nothing unresolved) and by the `index` fixture; 4,848 damaged programs still get a whole index.

- **The language server answers hover, definition, type definition, references, highlights, outline, workspace symbols,
  signature help, inlay hints, semantic tokens, folding, rename, the add-import quick fix, completion and formatting**
  (`lsp/features.psm`, `tokens.psm`, `edits.psm`, `completion.psm`, `formatting.psm`). Requests read the last good index of the
  program from a file, wait for a pending check, and can be cancelled. Fixture `lsp_features`.

- **The semantic index knows what an editor kept its own tables for.** What the compiler lowers instead of declaring (a `Vec`'s
  `push` and `length`, a `Channel`'s `send`, a scalar option's `unwrapOr`, a typed pointer's `load`, its address methods and
  atomics) is written with its signature and a sentence, as the reference at the member's name (`"builtin":"member"`, `sig`,
  `doc`) and as a completion's `detail` (`src/index/lowered.psm`, which the `index` fixture holds to what `sema/vec.psm`
  lowers). A used library function is written with all its overloads. `Type.f(` resolves to `f`; a nested function
  (`outer$inner`) is declared and its calls resolve; the types in a payload enum's variants are references; a trait-object call
  and its `dyn` argument are walked; `println(a, b)`, which sema splits into one statement per value, still has a reference at
  the written name. Signature help lists every overload, reads each label's parameters from its text (a library function's
  too), counts the receiver as `self` only for a value (not for `Type.f(` or `module.f(`), and no longer loses its place
  when the caret is inside a string argument that holds a parenthesis. Hover on a lowered member shows its signature.
  The IntelliJ plugin's own signature, hover and type-hint code was held to this: 1,910 call positions, 1,219 hover
  names and 320 hints of the checkout's tests compared before it was deleted.

- **The language server completes the whole library, `import` lines, types, `Type.` and the compiler's own builtins.** Every
  library module is imported in the completion's scratch copy, so every name is visible to the compiler, and a name from a
  module the document does not import is offered with the edit that adds the import (sorted among the document's). `import
  std.`, `import {a, b} from dir`, `from dir import {...}` and `import std.string.` complete modules, directories and what a
  module declares; `let v: |` completes types; `Int.` its constants, `StringBuilder.` its associated functions (not its
  methods), `Result<Int, String>.` its variants, a typed pointer its pointee's fields or `load`/`store`, an optional the
  `T?` functions, `__builtin_mem_*`/`asm`/`port` the freestanding builtins (read from `common/mem_builtins.psm`'s own
  predicates). Nothing is offered in a string, a comment or where a name is being declared, and a syntax error on another
  line of the function no longer takes the completion with it (docs/KNOWN_ISSUES.md, *Editor tooling*, says what still
  does). `dump-tokens`' contextual keywords (`export`, `async`, `prop`) are offered with the rest. The IntelliJ plugin's
  thirty-five completion tests are the acceptance: all of them hold of the server.

- **Go to definition reaches the library, and an `import` its module.** A definition in a compiled module (`xs.contains(` into
  `vec.psm`) is a position in the source the `.plib` carries, so the server shows that source. Reading it was the defect: a
  `.plib` starts with NUL bytes and `readFile` stops at the first one (nine bytes of a 71 KB file), so the server found "no
  source" for every library declaration and every `import std.x`. **`prismio library-source <file.plib> <module>`** prints
  the interface (`P1119` for the wrong arguments, `P1120` when the file or the module name is wrong); the server runs it once
  per module and writes the text into its scratch directory. The plugin's navigation tests are the acceptance: seven of
  seven hold of the server. One of them taught the opposite of the plugin: a function of the same name and parameter types
  in the file and in an import is `P4001`, not "the current file wins", and one of other parameter types is an overload.

- **The language server serves `build.ums`, and a workspace.** `prismio check build.ums` checks a manifest with the
  diagnostics of any other check (`--overlay <manifest> <file>` for unsaved text); the server runs it in a child, because
  the manifest loader keeps what it lexes (about 20 KB a call on this repository's own manifest) and a server lives for
  hours. A manifest document gets its `UMS####` diagnostics and completion by scope (blocks, keys, fixed values, from a
  table `lsp_manifest` holds to what the lowering accepts). Which program a file belongs to is read from each manifest once
  per change of the file, and a module with no manifest is checked through a program that imports it (the search the IntelliJ
  annotator did, now every client's). `lsp_manifest`, `lsp_workspace` (two programs in one root; a closed module changed on
  disk and reported with `workspace/didChangeWatchedFiles`). Latency: 162-177 ms for ordinary programs (150 ms of it the
  debounce), 1.2 s for the compiler checking itself; no cache is built because nothing else is slow.

- **`prismio fmt`: the formatter, in the compiler.** `prismio fmt <file>...` prints formatted source; `--write`
  rewrites files that would change, `--check` writes nothing and exits 1 if any would (the CI form), `--stdin` formats
  piped text (an editor's unsaved buffer), `--range <from>:<to>` formats only the tokens that begin on those lines.
  The rules are the IntelliJ plugin's `SpacingBuilder`, moved out of Java so an editor, the server and CI share one
  formatter (`src/fmt/`): only whitespace changes (the output has the input's tokens by construction), line breaks are
  the author's, indentation is counted in braces with continuation lines kept where the author put them, a closure's
  bars hug its parameters, type-argument lists are told from comparisons by scanning to the matching `>`, and CRLF stays
  CRLF. It never fails and reads text the compiler would refuse, which is what lets an editor format a file mid-edit.
  Held to the repository by `tools/check_fmt.py` (run by the `fmt` fixture): every one of the 875 `.psm` files formats
  without error, with only whitespace moved, and settles; 300 damaged copies do the same; the IR of the formatted `tests/`
  programs is byte-identical; and the formatter would change 0.16% of the repository's lines.

- **`prismio dump-tokens`: the lexical vocabulary as JSON.** Keywords, word operators, contextual keywords with the
  position that gives each meaning, the integer, float and other type names, every operator the scanner can make (with
  its token kind) and the separators, read from the compiler's own tables (`lexer/token.psm`, `lexer/vocabulary.psm`,
  the scanner's `isOperator` / `isTwoCharOperator` / `isSeparator`) so a tool never keeps a copy. The `token_tables`
  fixture fails when the parser compares an identifier with a word the table lacks (it found nine the IntelliJ
  plugin's hand-copied list had no entry for) and when the plugin's `PrismioWords.java` disagrees.

- **Error recovery inside an `impl` or `trait`.** A syntax error in one method drops that method, not the block: the
  members around it are still read, so the editor keeps completion and diagnostics for code that is well formed.
  Parsing resumes at the next `fn`, `prop`, `let`, `type` or modifier that starts a line at the member's indentation
  or at brace depth zero from where it began (`tests/neg_356_member_recovery.psm`; the fuzz gate stays at zero
  failures). Under `check --partial`, a trait impl is not blamed for the method it lost.

- **A program can serve a client and supervise a child on one thread.** `std.poll.waitReadable` waits on one, two or
  many descriptors with a timeout and answers which has something to read (`poll_clear` / `poll_add` / `poll_wait` in
  `runtime/program_support.c`; `poll(2)` on POSIX, a 1 ms `PeekNamedPipe` loop for pipes on Windows). Descriptor 0 counts
  bytes the line reader has already taken from the pipe as ready, which the kernel alone would not say. With it:
  `Stream.readSome(max)` reads what a child has written without waiting for it to finish, `Child.tryWait()` answers
  the exit status or `none` without blocking (`proc_try_wait`, `PRISMIO_STILL_RUNNING` = -2), and `std.input` gains
  `readBytes(count)` (exactly `count` bytes through the same buffer as `readLine`, for length-prefixed protocols) and
  `waitForInput(ms)`. `tests/test_353_poll_and_framing.psm`; it passed 25 of 25 runs idle and 15 of 15 under CPU load.
  The Windows halves are not built or run here.

- **`std.json`.** `parseJson(text)` reads a document into a tape of parallel columns (a value is an `Int`, its place on
  the tape), strictly per RFC 8259, with the offset of the first error and a nesting limit of 256; `member`, `element`,
  `path("a.b.c")`, `text`, `int`, `float`, `bool`, `raw` (a value as written, so a JSON-RPC id comes back unchanged),
  `keys`, `children`. `JsonWriter` builds a document and does the commas and colons; `jsonQuote` escapes one string.
  `tests/test_354_json.psm`.

- **`std.mem.stringFromCString(pointer)` and `std.term.isTerminal(fd)`.** The first copies the NUL-terminated text a C
  function left at a `Ptr` into a `String` the caller owns (over the new `__builtin_cstring`, which `std/` alone may
  call); the second is `isatty` and nothing more, where `colorEnabled()` also reads `NO_COLOR` and `FORCE_COLOR`
  (`prismio_rt_is_terminal` in `runtime/program_support.c`).

- **Variadic parameters and `typelist`.** `fn println<Ts: Printable>(...args: Ts)` takes any number of
  arguments, and a `typelist` says which types they may have: braces for an unordered set
  (`typelist Scalars { Int, Float, Bool }`, `typelist Printable { Display }`), parentheses for an ordered
  sequence that repeats (`typelist Row (Int, String, Bool)`). The function is instantiated per call shape:
  `for arg in args` is unrolled, `args.length`, `args[k]` and `row[k]` / `row.name` are constants, and
  `f(...args)` forwards, so there is no array or length at run time. A function may have several packs
  (consecutive, in order), and `...parts: String` is the one-type form. A fixed overload always beats a
  variadic one. `print`, `println`, `eprint` and `eprintln` now take any number of printable arguments,
  space separated (`import std.display`; one argument still calls the per-type overload), `concat` takes
  seven parts or more, and string interpolation is one `concat` however many parts it has. Before the
  standard-library conversion the whole corpus compiled to the IR it did before; after it, the suite passes. `tests/test_330`, `test_331`, `neg_329`-`neg_335`;
  `parse/typelists.psm`, `sema/typelists.psm`, `sema/packs.psm`, `docs/VARIADICS_PLAN.md`. Not yet: keyword
  arguments (a proposal is in `docs/VARIADICS_PLAN.md`).
  Packs also work beside ordinary type parameters (`<T: Display, Ts: Printable>(first: T, ...rest: Ts)`),
  a typelist or a trait can be a pack's type directly (`fn say(...xs: Printable)`), `max` and `min` take
  three or more integers, a call is limited to 128 variadic arguments (a pack function that calls itself
  with more never ends otherwise), typelists are checked where they are written and obey visibility, and
  the compiler reports an error identical in code, place and message once however many copies of a generic
  or variadic function it was found in (`tests/test_332`, `test_333`, `neg_336`-`neg_344`).

- **Enum discriminants, representation types, struct variants and `codeset`.**
  `enum HttpStatus: U16 { Ok = 200, NotFound = 404 }` gives an enum a representation and
  numbers. A fieldless enum is stored as that integer (`Packet { status, level }` is
  `{ i16, i8 }` in memory), `as Int` converts through it, a payload enum's tag takes it (so
  the first variant may be `0`), and `n as E?` tests the set of numbers, gaps included.
  Numbering continues from the previous variant and neither wraps nor skips to a free value.
  Refused with a diagnostic: a duplicate number in an enum (naming both variants), a number
  outside the type, one that is not a compile-time integer, an implicit number past the end,
  a representation that is not an integer. `Event.Click { x: 1, y: 2 }` and the pattern
  `Event.Click { x, y }` build and match a struct variant `Click { x: Int, y: Int }`.
  `codeset Status: U16 { Ok = 200, Success = 200 }` is a set of named integers that may
  alias; `Status.Ok` is a `U16`. An enum that states neither a representation nor a number
  compiles exactly as before (304 of the 309 programs in `tests/` and
  `benchmarks/hosted/prismio/` were compared byte for byte; the other five use syntax the
  older host cannot parse). `tests/test_327`, `test_328`, `neg_318`-`neg_328`; the
  modules are `parse/enums.psm`, `sema/enum_discriminants.psm`, `sema/codeset.psm` and
  `sema/enum_struct_variants.psm` (`docs/ENUM_DISCRIMINANTS_PLAN.md`). The runtime's
  enum registry is 64-bit (`ir_register_enum_variant`, `ir_enum_has_variant`) and the seed
  was re-cut for it. Struct variants work on generic enums too (`Shape<Int>.Rect { w: 5, h: 6 }`).
  A fieldless enum that appears as a type argument gets `Copy`, `Eq` and `Key` without writing
  them (`driver/derived_impls.psm`), so `Map<Level, V>` works; an `impl` the program writes wins.
  `I32` is shown beside `Int` in the enum docs (the two have always been one type).

- **Integers of any width, and five float types.** `Int<N>` and `UInt<N>` are an integer of
  exactly `N` bits for any `N` from 1 to 8,388,608 (LLVM's limit): `Int<24>`, `UInt<5>`,
  `Int<128>`, `UInt<4096>`. A width that has a name is that name -- `Int<8>` is `I8`, `Int<32>`
  is `Int`, `UInt<64>` is `U64` -- so the spellings mix without a cast; any other width is its own
  type, lowered to `iN`. Arithmetic wraps at the width, `--overflow-checks` traps at it, a literal
  is range-checked against it (a 128-bit literal is valid for an `Int<128>`), a float converts to
  it by saturating, and `x as Int<24>?` answers `none` when `x` does not fit. The floats are
  `F16`, `F32`, `F64` (`Float` under another name), `F128` and `BF16`; a float literal takes the
  float type its context gives it, a cast between them rounds, and `F<24>` and `Float<32>` are
  errors, since a float has no free width. `print`, `println`, `toString`, `as String` and `"${x}"` work for
  every one: up to 64 bits an integer converts to `I64` or `U64`, a wider one goes through
  `std.number_text` (`import std.number_text`), and the floats other than `Float` print the
  fewest digits that read back *in their own type*, so an `F32` written `0.1` prints `0.1`.
  `tests/test_324`-`test_326` and `neg_314`-`neg_317` hold it; `ast/int_width.psm` and
  `ast/float_width.psm` own the names, `ir/numeric.psm` the conversions.

  Known limits (`docs/KNOWN_ISSUES.md`): an `Int<N>` of an unnamed width and the four new floats
  implement none of the standard traits yet (`Eq`, `Ord`, `Copy`, `Default`, `Display`, `Key`), so
  they cannot be `Map` keys or `sort`ed through the trait-bounded APIs; a `Vec` cannot hold a
  number wider than 64 bits; `std.math` is `Float`'s; and `F128` needs a library of soft-float
  routines that Windows builds do not link.
- **Mixed-width shift amounts.** `x >> n` with a `U64` and an `Int` failed module verification (an
  `lshr i64` by an `i32`); the amount is now resized to the shifted value's type.
- **Five benchmarks:** `graph_churn_single`, `graph_churn_alloc`, `graph_churn_transfer` and `graph_churn_full`
  (graph mutation, allocation and lifetime pressure, cross-thread transfer and reclamation, and all three), and
  `register_pressure_torture` (forty live values in a dependent chain). Prismio is 1.2x to 1.5x of C++ on the
  four graph ones (1.9x to 2.5x when they were added) at 1.1x to 1.5x of its peak memory (8x to 32x), at parity
  on the last; `docs/GRAPH_CHURN_FINDINGS.md` has the table and the issues they found. The channel queue C++ and
  the benchmark share moved to `cpp/bounded_queue.hpp`.

- **`async fn`, `Future<T>` and `await`.** Calling an `async fn` does not run it: the call is a
  `Future<T>`, a task that has not started, and the body runs where it is awaited. `await f(x)` is
  the call itself, with no handle and no allocation; a held future is one small allocation, and a
  future that is built and never awaited does no work. It works on methods, on generic functions
  and on recursion, a `Vec<Future<Int>>` can be collected and awaited in a loop, `async fn main`
  is allowed, and a function that is not `async` runs a future with `join`. `Future<T>` is the
  type `Task<T>` already was (both spellings are accepted); `spawn` now takes an `async fn` and a
  scalar argument or result of any width, through a thunk that converts each to and from the
  runtime's word, so `async fn half(x: Float) -> Float` needs nothing in the runtime.
- **`scope { }` and `spawn { }`.** A scope cannot be left until every task started inside it has
  finished, on every way out: the closing brace, `return`, `break` and `continue`, nested scopes
  included. `spawn { ... }` starts a task whose body is the block and is only allowed inside a
  scope; it captures what it reads from the enclosing function by value, up to three, moving
  anything that owns something, and answers with the block's last expression. `spawn fut` starts
  a future built earlier. A spawn used as a statement is waited for by the scope with no handle
  to keep. 4,200 tasks in a loop leave no leak (`leaks`). Eight new negative fixtures
  (`neg_271`-`neg_278`) hold the diagnostics. See `docs/ASYNC_PLAN.md`.

  Known limits: an `await` of a task running on another thread blocks its thread (a task is
  still an operating-system thread), a task or held future takes three arguments, and a struct or
  String that came back through a handle is not freed by the awaiter (`docs/KNOWN_ISSUES.md`).
- **`spawn` of a function defined below it.** The target's address is taken before its
  definition exists, which failed with `address of unknown function`; the spawn now declares it
  first. This also affected the `spawn f(x)` form before, and every lifted block needs it.
- **A condition needs no parentheses.** `if x == 3 { }`, `while n < 10 { }` and
  `if o == none { }` read as written, and `if (x == 3) { }` is the parenthesised
  expression it always was. A struct literal in a bare condition has to be
  parenthesised (`if (Point { x: 1 }).x == 1`), as it is in a `for` header, because
  the `{` after a condition is the body.
- **`is`, `is not` and `not`** are the words for `==`, `!=` and `!`, read into the
  same nodes as the symbols. `not` binds like `!`: `not x == y` negates `x` alone.
  All three are reserved words now. They are operators between two operands, as in Python
  (`x is 3`, `x is not none`), so a `(` touching the word is refused: `x is(3)` read as a
  call and parsed only because `(3)` is a parenthesised operand. `x is (a + b)`, with a
  space, is a grouped operand and stays valid (`P3010`, `neg_293`, `test_293`).
- **`Ptr<T>`, the type (stage 1 of `docs/PTR_PLAN.md`).** A typed pointer: non-null, one machine
  word, `Ptr<T>?` for an absent one at no cost. `Ptr<mut T>` may write and `Ptr<volatile T>` makes
  every access volatile, in either order; `Ptr<mut T>` becomes `Ptr<T>`, and becomes the opaque
  `Ptr` (still the spelling for a foreign handle) -- a read-only `Ptr<T>` does not, because foreign
  code may write through an opaque one, and neither does a volatile one, whose accesses must stay
  volatile -- and nothing converts the other way. What it points at
  must own nothing: numbers, `Bool`, `Char`, enums, pointers and structs of those, so
  `Ptr<String>` and a pointer to a struct holding a `Vec` are refused. A struct may hold a
  `Ptr<Node>?` (`test_291`, `neg_291`, `neg_292`).
- **Reading through a `Ptr<T>` (stage 2).** `p.magic` reads a field of a struct pointee where it lies
  (a `getelementptr inbounds` and a load at the field's alignment), and a field that is itself a
  struct is a pointer to it, so `packet.header.magic` reads through two. A pointer to a scalar is
  read where a value is wanted: `p + 5`, `-p`, `p is 40`, `let n: Int = p`, `return p`, and as an
  argument to an `Int` parameter; `p.load()` says it outright. A pointer stays a pointer anywhere
  else, so `let q = p` copies the pointer. Two pointers under one operator, a struct as an
  operand and a read through `volatile` are refused with the method or stage that handles each.
  The reads lower to one builtin, `__builtin_ptr_load`, emitted as a typed `load` with no type-based
  alias tag (a `cast` makes two types the same bytes), and a `Ptr<T>` parameter carries `noundef
  nonnull align(A)` from the data layout, plus `readonly` unless it is `mut`: `Ptr<Header>` over
  `{ i32, i32, i16 }` is `align 4`. It is not `dereferenceable`, because a pointer may be one past
  its allocation. Overloads on the pointee type or the
  capability are distinct functions, and the exactly-typed one wins (`test_292`, `test_294`,
  `neg_294`). Volatile access is stage 5.
- **Writing through a `Ptr<mut T>` (stage 3).** `p.field = v` stores into a field of the pointee (a store at the
  field's own width and alignment), `packet.header.magic = v` through two, and `p.store(v)` writes a scalar
  pointee (`__builtin_ptr_store`). A pointer field takes a pointer: `node.next = other`. Refused with the way
  out: a write through a read-only `Ptr<T>` (take a `Ptr<mut T>`), a struct-typed field (`p.header = q`; write
  its fields), `p.store` of a struct, and `p = 5`, which would replace the pointer rather than write the value.
  `p.field += 1` is still refused, as it is for any field (compound assignment needs a plain variable): write
  `p.field = p.field + 1`. Access through a `volatile` pointer, read or write, is refused until it has its own
  access (`test_295`, `neg_295`).
- **Where a `Ptr<T>` points, stepping it, and making one (stage 4).** `p.addr` is a `Usize` property. Motion is
  by method, so `p + 1` stays the value and a pointer cannot be stepped by accident: `p.offset(n)` (one
  `getelementptr inbounds`, in elements, so a 12-byte struct steps 12), `p.byteOffset(n)`,
  `p.wrappingOffset(n)` (no `inbounds`, for a ring), `p.offsetFrom(q)` (elements, exact), `p.isAligned(a)`,
  `p.sameAs(q)` (where they point, which `==` between two pointers refuses to guess), and
  `p.advance(n, limit)`, which answers `none` rather than pass `limit` in the direction of travel and
  compiles to a branchless select (a plain GEP and an ordinary division, so a `limit` from another
  block or not a whole number of elements away is still answered). The constructors are `std.raw`'s and need `import std.raw`, which is the
  whole of the unsafe marker: `Ptr<T>.at(address)` and `.castAligned(p)` answer `Ptr<T>?` (none for 0 or an
  address the pointee cannot sit at), `.atUnchecked(address)` and `.cast(p)` trust the caller, a
  read-only pointer cannot be cast to a `mut` one, and a volatile one only to a volatile one. A `Ptr<T>?` is unwrapped with `expect`; there is no flow
  narrowing. `Ptr<mut T>.at(...)` also parses now, which the type-argument scan in expressions had missed
  (`test_296`, `neg_296`, `neg_297`).
- **Volatile and atomic access through a `Ptr<T>` (stage 5).** Every access through a `Ptr<volatile T>` is volatile:
  `p.load()`, `p.store(v)`, a scalar operand, a field read or write, and a struct inside it, so a driver cannot write
  one register access the optimiser may drop or hoist; a `Ptr<volatile T>` parameter is not promised readable, so it
  gets no `dereferenceable`. `p.readVolatile()` and `p.writeVolatile(v)` are the one-off form. The atomics are
  `p.atomicLoad(order)`, `atomicStore`, `atomicSwap`, `atomicAdd`, `atomicSub`, `atomicAnd`, `atomicOr`,
  `atomicXor` and `atomicCompareExchange`, with the ordering written at the call as a variant of the new
  `AtomicOrder` in `std.raw` (`Relaxed`, `Acquire`, `Release`, `AcqRel`, `SeqCst`), which also closes the weaker-orderings
  gap `docs/FREESTANDING_PLAN.md` listed. The pointee is an integer, a write needs `Ptr<mut T>`, a load cannot release and
  a store cannot acquire, and a compare-exchange derives its failure ordering from the success one. A new `typed_pointer_ir`
  harness test checks the emitted `load volatile`, `store atomic ... release`, `atomicrmw ... acq_rel` and `cmpxchg` and the
  parameter attributes, since none of it shows in a program's output (`test_297`, `test_298`, `neg_298`).
- **Typed blocks and a Buffer's pointer (stage 6).** `std.mem` gains `allocOf<T>(count)`, `allocZeroedOf<T>(count)`,
  `reallocOf(block, count)` and `free(block)` for a `Ptr<mut T>`, the element size read off the type, and `Buffer.pointer`, a
  `Ptr<mut U8>?` that is `none` for an empty Buffer (`test_300`). Generic functions over a typed pointer now work: the
  instantiation names a pointer type it can write down again, `T` is solved from a `Ptr<T>` parameter, and a `Ptr<mut T>` fits a
  generic `Ptr<T>` (`test_301`). **`asSlice` is not built:** a `Slice` is a handle to a list header, so a pointer and a count have nothing
  to be a view of; it needs a second view representation (`docs/PTR_PLAN.md`).
- **What a `Ptr<T>` lets the optimiser assume, audited.** Four were wrong and are fixed (`test_303`, `neg_305`, and new
  `typed_pointer_ir` cases). A store through a `Ptr<mut Float>` was moved past a load through the `Ptr<U64>` cast from the
  same block at -O3, and a field store through one struct past a load through another laid out alike: pointer accesses
  carried type-based alias tags, and now carry none (managed values keep theirs). `dereferenceable` on a `Ptr<T>`
  parameter made passing a one-past-the-end pointer, such as `advance`'s `limit`, undefined; it is gone. `advance`'s room
  was an `sdiv exact`, poison for a `limit` that is not a whole number of elements away. And `volatile` could be dropped by
  converting to the opaque `Ptr` or by `cast`; both are refused. Three suspected problems were checked and were already
  right: `Ptr<volatile U32>.at(...)` parses, `p > 0` on a `Ptr<U32>` is unsigned, and `if p` on a `Ptr<Bool>` is refused.
- **Stepping a pointer is `std.raw`'s, and `cast` cannot make one stricter** (`docs/MEMORY_SAFETY_PLAN.md` §1). `offset`,
  `byteOffset` and `wrappingOffset` need `import std.raw`, as the constructors do: a pointer has no length, so one stepped
  out of its block is not caught, and a byte step leaves a misaligned `Ptr<Int>`. `advance(n, limit)` stays safe. `cast`
  to a pointee needing more alignment than the source promises (`Ptr<U8>` to `Ptr<U64>`) is refused and names
  `castAligned`, which checks, and the new `castUnchecked`, which is the caller's word (`neg_306`, `neg_307`). A struct
  with an inline `Array<U8, N>` field is now a valid pointee.
- **Nested functions.** A `fn` written in a function body is a private function that
  captures nothing, visible in the block that declares it, callable before its
  declaration and recursively; two functions may each have a `helper`, and a method
  may have one. The parser lifts it out as `outer$inner`.
- **A closure may have a block body**, `|x: Int| { let y = x + 1  y * 2 }`, and the
  block's last expression is its value. A function body still answers only through
  `return`, and its error now says so.
- **Visibility on global `let`s, structs, fields and enums**, with the levels a function has:
  `public` (everywhere), `internal` (the package), `private` (the file). A struct and an
  enum are `internal` unless marked and a field `private`, so `public struct Point { public x:
  Int, y: Int }` is a public type with one public field; a struct literal needs every
  field visible. An unmarked global stays open to every file. An enum is checked where
  its name is written (an annotation, `Mode<Int>` included), where a variant is built
  and where a `match` arm names one; a variant takes its enum's level, payload and
  generic enums included. A marker on a `trait` or an `impl` is refused by name (P3001).
  The enums that cross a package are `public`: `TokenType`, `NodeKind`, `TypeKind`, the
  `ums` ones, and in `std` `Result`, `Platform`, `Architecture`, `Environment`,
  `StreamMode` and `AtomicOrder`.
- **An array's length is a constant expression**, `Array<U32, N * N>`, over numbers and
  non-`mut` globals, and an integer global may be initialised by one:
  `let CELLS: Usize = N * N`.
- **Ranges and indexing across integer types.** `for i in 0..<MATRIX` over a `Usize`
  (or `U32`, `I64`, `U8` ...) counts in that type, and a `Vec`, array or `String` is
  indexed by any integer: a value no `Int` holds is out of range rather than wrapped
  into it. The loop is the `Int` one over a count (`sema/ranges.psm`), so every proof
  about loops still applies; a range with more than 2^31-1 values stops with an error
  when entered. `bench_matrix_multiply` written this way is 9.96 M instructions, the
  same as the C arm.
- **`std.raw`, `std.port` and `std.asm`**, the clean surface for what freestanding code
  used to reach with `__builtin_*`: address and pointer conversion, volatile and
  unaligned access, atomics on 8- to 64-bit words, a fence, `swapBytes`, and a Float's
  bits (`x.bits`, `Float.fromBits`) in `std.raw`; `portInU8` and friends in `std.port`; `asm`, `asmRead` and `asmWrite` in
  `std.asm`, which the compiler lowers where the text is written because the text has to
  be a literal. All three are freestanding-safe and call nothing in the C runtime.
- **Float text is Prismio** (`std/float_text.psm`): `toString`, `toString(places)`,
  `parseFloat`, `as String` and `as Float?` no longer call `snprintf` and `strtod`, so
  a `--freestanding` program can format and parse a Float (`kernel_float_aarch64.psm`
  boots under QEMU and does). A `Decimal` of up to 800 digits shifts and rounds the
  exact expansion of a double, so rounding is correct by construction; a Clinger fast
  path (one multiplication or division by an exact power of ten) takes the ordinary
  cases. Output is digit-for-digit what the C functions gave: 1.1 million bit patterns
  for `toString`, 200,000 for `toString(places)` and 300,000 texts for `parseFloat`
  (`tests/test_276_float_text.psm` keeps a table of the edge rows). One difference:
  `"nan(a-b)"` is `none` (C99 allows letters, digits and `_` between the brackets; macOS's
  `strtod` took anything), and `toString(places)` of NaN or an infinity is `nan`, `inf`
  or `-inf` on every platform where it used to follow the C library. `toString` of
  a Float is 2.7× faster than the C search on short values and 6× on 15-digit ones
  (0.25 µs against 0.67 µs and 0.16 against 1.0), `toString(places)` 1.75× slower
  (0.1 µs), `parseFloat` equal to C up to 19 digits and 7× slower past them (0.15 µs).
  Whole-suite A/B against the previous compiler: hosted Prismio geomean 0.996 over 65
  workloads, binaries the same size, 20 freestanding workloads with identical
  instruction counts, compiling the 66 programs 7% slower (837 ms to 910 ms) because
  `std.string` now carries 35 more functions. `print(Float)` and its siblings format
  through the same code, so the console and `toString` cannot disagree; what that
  costs a program that never prints a Float is what the unreachable-function pruning
  below removes. `std.float_text` is importable freestanding.
- **`a ?? b`, none-coalescing.** `a` when it has a value and `b` when it is `none`,
  for any `T?`; `b` is a `T` (the result is a `T`) or another `T?` (the result stays
  one, so `a ?? b ?? 0` tries each in turn). The right side is evaluated only when it
  is needed, so `line ?? fail("no input")` runs `fail` only for `none`. It binds
  tighter than a comparison and looser than `|` and `+`, and associates to the right.
  It is the call `optionCoalesce(a, b)` in `std.option`, so a program using it
  imports `std.option`.
- **`from <directory> import {a, b}`** is `import {a, b} from <directory>` with the
  directory first, and `from <directory> import *` is `import * from <directory>`.
  Both orders can sit in one file.
- **`main` needs neither `-> Int` nor `return 0`.** `fn main() { ... }` exits with
  status 0: reaching its closing brace is `return 0`, and so is a bare `return`. Writing
  `-> Int` says the status is the program's, so that `main` is held to the rule of
  every `-> Int` function: each path must return a number, and falling off the end or a
  bare `return` is an error ("function `main` must return Int on every path"). A `main`
  that declares any other return type is refused.
- `std.input`: every read is a plain function, so there is no `stdin` to name first:
  `readLine()`, `readLineOr(fallback)`, `prompt(text)`, `readInt()`, `readFloat()`,
  `readLines()`, `readWords()`, `readAll()`, `atEndOfInput()` and `inputLines()` for a
  `for` loop.
- **Removed: the `stdin` value** (`stdin.readLine()`, `stdin.lines()`, `stdin.isAtEnd`,
  and the rest of its methods). Each is the plain function of the same name now:
  `stdin.lines()` is `inputLines()` and `stdin.isAtEnd` is `atEndOfInput()`.
- `std.option`: `unwrapOr`, `expect(o, message)`, `okOr`, `map` and `andThen` on any
  `T?`, as ordinary generics over it (`o.unwrapOr(x)` and `unwrapOr(o, x)` are one
  call).
- `std.fs`: `createSymbolicLink(target, linkPath)` → `Bool`, `readLink(path)` →
  `String?` (none when the path is not a link) and `realPath(path)` →
  `String?` (none when the path does not resolve). On Windows
  `readLink` always answers none.
- `std.process`: `process.allEnv()` returns every environment variable as
  `NAME=value` lines.
- Runtime groundwork in `program_support.c` for the host name, group ids, user
  and login names and disk usage (`statvfs`). No `std` wrapper exposes these yet.

- **Freestanding programs: a Prismio program with no operating system under it.**
  `prismio build app.psm --target <triple> --freestanding` links no installed runtime, no C
  library, no startup files and no `-lm`/`-lpthread`; the image is static, linked by lld.
  A kernel boots under QEMU on AArch64 (`virt`) and 32-bit x86 from this repository's
  tests, with the entry point, serial output, exit and panic hook written in Prismio.
  The rest of the build is flags: `--native <file>` (a C or assembly source, such as a boot
  stub), `--native-flag`, `--link-arg` (`-T kernel.ld`), `--target-features` (`-neon,-fp-armv8`;
  `-sse,-sse2,-mmx,+soft-float`), `--code-model <small|kernel|medium|large>` and
  `--no-red-zone`. A `build.ums` target declares the same with `freestanding = true`,
  `triple`, `features`, `codeModel`, `noRedZone`, and `script("kernel.ld")` and `arg("...")`
  in `link { }`. See `docs/FREESTANDING_PLAN.md` and the guide *Freestanding programs*.
  - A freestanding program may import `std.option`, `std.platform` and `std.iter` and no
    other `std` module (`P1094`): the rest are compiled against the C library.
  - `--freestanding` adds `runtime/freestanding/panic.c`, which defines the six functions
    generated code calls on a failure (a checked overflow, `panic`, `unreachable`, a failed
    `assert`, a bad range step, `expect` on `none`) and forwards each to one function the
    program supplies, `prismio_panic_hook(kind, detail, file, line, col)`. Every function in
    it is weak, so a program may replace any of them.
  - `tools/package.py --freestanding-target <triple>` packages the allowed `std` modules and
    the failure core for a bare-metal triple; no sysroot is needed.
- **Memory, atomics, assembly and port I/O as builtins**, for code that talks to hardware.
  An address is a `Usize`, not a `Ptr`, and the width is in the name:
  `__builtin_mem_{load,store,vload,vstore}_{u8,u16,u32,u64}` (plain and volatile),
  `__builtin_mem_{aload,astore,aswap,aadd,asub,aand,aor,axor,acas}_*` (atomic,
  sequentially consistent), `__builtin_mem_fence()`, `__builtin_asm(text)`,
  `__builtin_asm_read(text) -> U64`, `__builtin_asm_write(text, value)` (the text must be a
  string literal; `$0` is the operand), `__builtin_ptr_addr` and `__builtin_addr_ptr` (the one
  door between `Ptr` and a number), and on x86 `__builtin_port_{in,out}_{u8,u16,u32}`.
- **Declaration modifiers.** Before `fn`: `export` (the function is also reachable under its
  source name, the symbol an assembler stub or a linker script writes), `naked` (no prologue
  or epilogue; the body is `__builtin_asm`), `section("...")` and `align(n)`. Before
  `struct`: `repr(C)` (fields in the order written, C's padding) and `packed` (and no
  padding); an unmarked struct is still ordered by the compiler. A packed struct's fields are read
  and written at one byte -- they were read at their type's alignment, which an odd offset makes
  undefined -- and so a field of one is a number, `Bool`, `Char`, enum, pointer, packed struct or
  byte array: an inner struct, a wider array or a `T?` would be read through at its own alignment,
  and is refused (`neg_305`). All are contextual words, so
  a variable may still be called `export`.
- New diagnostics `P1090`–`P1096` (the command-line flags, and `P1094` for a refused `std`
  import) and `UMS2116` (an unknown `codeModel`).

- **Benchmarks are two suites, `hosted` and `freestanding`, in one tabbed report.** The existing
  Prismio/C++/Rust matrix moved to `benchmarks/hosted/`. The new `benchmarks/freestanding/` runs Prismio,
  C and Rust with no operating system: 20 integer workloads (algorithms, compute, memory, and a
  hardware category of atomics and volatile access on raw addresses) built for bare-metal AArch64 and run
  under QEMU with `-icount shift=0`, which makes the guest's timer count instructions. The result is an
  exact, repeatable instruction count per workload, plus `.text` size, not a time, so there is no noise
  model. One harness object (boot, timer, serial, exit) links into all three arms, and the runner stops if
  their checksums disagree. The Rust arm needs no `rustup target add`: `core` is built from `rust-src`.
  `prismio bench` runs both (`--suite hosted|freestanding`, `--scale N`); `results/results.json` is schema
  4, one report per suite, and the HTML report and the website's benchmarks page gain Hosted and
  Freestanding tabs. First numbers against C: 14 of 20 at parity, 3 fewer instructions and 3 more; against
  Rust, 9 fewer, 9 at parity and 2 more. The first run read `edit_distance` at 2.0x C, and that was the
  harness: Prismio's row copy became a call to a byte-loop `memcpy` that C's `-ffreestanding` build never
  made. The shared `memcpy`, `memmove` and `memset` now move a word at a time (aligned, so they are safe
  with the MMU off), and the row reads 1.05x. The three rows still behind C are one cause: C's signed overflow is undefined and Prismio's wraps, so LLVM can rewrite C's arithmetic and widen its loop indices. With the C arm built `-fwrapv`, Prismio is 4 fewer, 16 level and none more across the 20. All three are recovered since, without `-fwrapv`; see *Changed*.
- **`std.mem`: buffers and manual memory.** Three tools, in one import:
  - **`Buffer`**, a run of bytes with a length that is freed like any `Vec`. `Buffer(n)`
    (zeroed), `Buffer.withCapacity(n)`, `Buffer.fromString(s)`; `b[i]` and `b[i] = x`;
    typed reads and writes at any byte offset, little- and big-endian, for `U8`/`I8`
    through `U64`/`I64` and `Float` (`readU32BE`, `writeI16LE`, `readFloatLE`, ...);
    `fill`, `copyFrom` (overlap-safe), `slice`, `resize`, `push`, `append`, `clear`,
    `indexOf`, `toString`, `==`, and `b.address` for the builtins or C. Every access is
    bounds-checked, and a bad one exits with the offset and the length. The byte
    accessors are curated into the program, so a `readU32LE` in a loop compiles to one
    unaligned load per iteration with the check lifted out (AArch64: two `ldr`s per
    unrolled pair, no branch).
  - **`alloc`, `allocZeroed`, `realloc` and `free`** on `Usize` addresses, with `copy`,
    `fill`, `compare`, and `a.loadU8()` ... `a.storeU64(v)` over the `__builtin_mem_*`
    loads and stores. An allocation never returns 0; running out of memory exits with
    a message. The blocks go through the runtime's allocator seam, so a `--verify` build
    reports a block never freed as **leaked** and one freed twice as a **violation**.
  - **`Arena(capacity)`**, a bump allocator: `alloc(size, align)` answers an aligned
    address, `reset()` takes everything back at once, and `used`, `remaining` and
    `capacity` report on it. An allocation that does not fit, or an alignment that is
    not a power of two, panics.
  `tests/test_274_std_mem.psm` covers the surface and is held to 0 leaked and 0
  violations under `--verify` (55 allocated, 55 released); `std_mem_failures` checks
  each failure message and the two ledger answers. `sizeOf<T>()` is not part of it:
  a type's size is not exposed yet.
- **Benchmarks for `std.mem`**, in the hosted memory category, each the same program in
  Prismio, C++ and Rust: `binary_codec` (Buffer's typed big- and little-endian reads
  and writes), `manual_alloc_churn` (`alloc`/`free` against `malloc`/`free` and
  `std::alloc`) and `arena_bump` (a linked list built in an `Arena` and reset, against
  a hand-written bump arena). First numbers against C++: 1.03×, 0.98× and 1.00×.
  `arena_bump` read 1.61× until `Arena.alloc`'s failure messages moved into `cold`
  functions and the block's address and length were read once at construction;
  built in place, the messages stopped `alloc` inlining and gave it a 240-byte frame.
- **A heap in `--freestanding` programs: `Vec`, `String`, `Map` and `std.mem` in a kernel.** The
  program defines `prismio_alloc`, `prismio_realloc` and `prismio_free` (in Prismio with `export fn`, or
  in C), and the build compiles `lang_runtime.c` for the program's own triple and CPU features with
  `PRISMIO_FREESTANDING`: no C library, `runtime/freestanding/libc.c`'s weak `memcpy` family and `qsort`,
  runtime errors through `prismio_panic_hook`, no locks. Only a program that imports a module over `Vec`
  or `String` gets it; one that imports none links what it did before. Every `std` module but `io`,
  `display`, `input`, `fs`, `process`, `time`, `term` and `math` is now importable (was `option`,
  `platform`, `iter`). A freestanding program is internalised like a closed hosted one, since its C
  reaches Prismio only through `main` and `export`; the freestanding benchmarks did not move (0.95× C).
  `kernel_mem_aarch64.psm` boots under QEMU with a bump allocator
  written in Prismio, and a Buffer read out of range reaches the panic hook. FREESTANDING_PLAN step 6.
- **`__builtin_swap_bytes`, `__builtin_float_bits` and `__builtin_float_from_bits`**:
  byte order reversed at any integer width (one `rev`/`bswap`), and a Float and its
  64 bits reinterpreted either way. **`__builtin_mem_uload_*`/`ustore_*`**: loads and
  stores at any alignment, of memory the compiler may treat as byte storage only.
  They carry a type-based alias tag of their own, so a store through one does not
  force LLVM to reload a list's length or data pointer. `std.mem`'s typed Buffer
  accesses are built from them: `binary_codec` went 1.03× → 1.00× C++, with every
  bounds check gone from both of its loops.
- **`x[i] = v` on a struct calls its `set`**, as `x[i]` already called its `at`. A struct
  with an `at` and no `set` keeps the error, which now says to write
  `fn set(inout self, index, value)`. A generic struct's `set` is not reached yet, so a
  `Map` is still assigned with `m.set(k, v)`.

- **`-Os` and `-Oz`.** Size levels for `prismio build`: every function is marked `optsize`
  (`-Oz` also `minsize`, which turns on AArch64's machine outliner) and runs LLVM's O2 pipeline,
  since LLVM 23 has no Os pipeline of its own; `-Oz` also leaves the loop vectorizer off, as
  clang does. On the hosted benchmark program `__text` goes from 181,320 bytes to 115,368 at
  `-Os` and 81,532 at `-Oz` (the file from 242 KB to 177 KB and 152 KB). Not a default: the
  outliner alone cost 4.1% geomean time on the hosted benchmarks (`sort_strings` 43%).

### Changed

- **The frontend no longer ends the run at the first lexical, syntax or import error.** A syntax error the parser could
  not recover from locally (`Parser.fatal`, 38 call sites), a lexer error (`Lexer.fatal`, 24) and an unresolvable
  import (5) each called `exit(1)`. Now each reports and carries on: the parser gives up on the declaration it is in
  (`dead` state: it parks on the end-of-file token, so every loop ends and every `expect` is silent) and
  `parseModule` resumes at the next declaration that begins a line (`recover` in `parse/decl.psm`; a declaration
  keyword at brace depth zero, or in column 1 so a `{` left open does not swallow the rest). The lexer skips a
  stray character, ends a string at its line, and replaces a bad escape with `?`, so the token stream stays well
  formed and adds no errors of its own. An import that cannot be read is skipped and the imports after it are still
  resolved. A file with three broken declarations now says so, in one run, across the whole program; type checking
  still does not run once an error exists, as before. A parser that does not stop after a failure (a loop missing
  its `break`) ends the run with `P3299` after 100,000 failures instead of hanging. The `exit` calls left in the frontend
  are the 25-error limit, `P3299`, an internal nesting overflow, and the stale-runtime check in `build`. No change for a
  valid program: IR is byte-identical for the 351 valid programs in `tests/`, the 9 hosted benchmark programs and
  `src/main.psm` itself; of the 300 negative tests that existed, 299 print the same diagnostics under `check`, `neg_209` also reports its
  second bidirectional control, and `neg_150` / `neg_262` needed two cascade fixes (a closing quote left on the line
  after an unterminated string is not reported again; recovery never resumes in the middle of a `from … import`).
  `tests/neg_353`-`neg_355`; `tools/check_truncation.py` damages every program in `tests/`, `std/` and `src/` (cut,
  deleted bytes, stray brackets and quotes; standalone and through `--overlay`) and fails on a crash, a hang, a missing
  summary line or a silent non-zero exit: 9,468 variants, none. This is Phase 0 of `docs/LSP_PLAN.md`.

- **`prismio check --partial` type checks what parsed.** Without the flag a syntax error still ends the analysis. With it,
  the declarations that parsed are checked, so a type error in one function is reported beside the syntax error in
  another. An `unknown ...` error that only exists because the parser dropped text that mentions the name is held back,
  and so is every one once an import could not be read (`diag_hides` in `common/diagnostics.psm`); nothing else is
  suppressed. `IDE_PROTOCOL.md` has the contract. `tools/check_truncation.py --partial` fuzzes it and counts the variants
  that type-checked past a syntax error (1,900 of 15,780, none failed); `check_partial` in `tests/test_runner.py`.

- **A program may read 4,096 source files, up from 256, and says so past that.** The registry returned -1 beyond its
  limit and the import resolver parsed the module anyway, with every token carrying file -1 and every diagnostic
  losing its location. Now `P1098` names the first module that was not read. The compiler's own program reads about
  140 files. `source_file_limit` in `tests/test_runner.py`.

- **`runtime/aif_support.c` and `runtime/aif_containers.c` are Prismio** (9,248 lines of C gone). The AIF engine is the
  `src/aifcore` package, 18 modules of about 8,100 lines: `bits` (the bitset arena), `structure`, `nominals`, `keys`,
  `sites`, `constraints`, `solver`, `tiers`, `arenas`, `call_graph`, `brackets`, `extents`, `dispositions`,
  `ownership`, `call_results`, `layout_search`, `constants` and `reset`. The public `aif_*` names are unchanged and the
  `extern fn aif_*` declarations in `src/aif/model.psm` and `src/ir/context.psm` are gone; callers import the module
  they use. Tables are columns of `Vec<Int>` and every set is a handle into one `Vec<U64>` arena. IR for `src/main.psm`
  is byte-identical under the C engine and this one, as is IR for all 318 programs in `tests/` and
  `benchmarks/hosted/prismio/` (and the diagnostics of the 300 `neg_*` tests); the suite passes 698/698 and the IR
  reaches a fixpoint in two generations. Measured against the compiler before the port, interleaved on one machine,
  median of eleven: `check src/main.psm` 0.845 -> 0.836 s, `aif src/main.psm` 1.20 -> 1.38 s, IR for `src/main.psm`
  1.80 -> 1.88 s (+4.5%), binary +352 KB (62,054,544 -> 62,406,688), `__text` +359 KB. Written in Prismio the engine
  paid 20% on IR emission at first, and the cause was in the build, not the engine: the compiler links the runtime as
  a separate object, so every `Vec` read outside a proven loop was a call to `list_get_inline_scalar` (5,170 call sites
  in the binary). See the next entry. `tools/aif_differential.py` still reports the two `src/main.psm` disagreements
  recorded in `docs/KNOWN_ISSUES.md`; the C engine gives the same counts on this tree. The committed `bootstrap/seed.ll`
  no longer bootstraps this tree (it declares `aif_*` extern): cut one with `prismio seed` and commit it first.
- **A target with `runtime = "none"` and its own `lang_runtime.c` is built with the runtime's list and string accessors
  inlinable.** `compiler_build_executable` merges the curated module (the same `available_externally` bodies a
  program gets) into such a target's IR before the final compile, and `ir_link_modules` strips the packaging machine's
  `target-cpu`/`target-features` from it first: left on, the inliner answered "conflicting attributes" for every call
  and the merge changed nothing. This path had no caller since programs started merging the full runtime bitcode. Calls
  to `list_get_inline_scalar` in the compiler binary: 5,170 -> 69; IR emission for `src/main.psm` 2.17 -> 1.88 s, `aif`
  1.63 -> 1.38 s. The merge costs 0.36 s of the compiler's own build. Programs and the IR of every program are unchanged.
- **`runtime/ir_symbols.c` is Prismio** (1,819 lines of C gone, 122 functions). The compiler's symbol tables are
  `src/symbols/`: `names.psm` interns every name to an id, so a lookup compares integers as the C compared
  pointers; `bindings.psm` holds scopes, bindings, drop lists, loops and moved/borrowed sets, `type_registry.psm`
  structs, enums and return types, `declarations.psm` the declaration index and import visibility, and
  `facts.psm` the loop analyses' marks. Names and call sites are unchanged (`ir_*`); the eleven struct and enum
  queries the backend makes are `export fn ..._cstr`. IR for all 318 programs in `tests/` and
  `benchmarks/hosted/prismio/` is byte-identical to the C tables' (the one exception is `test_352`, which needs the
  AIF fix), the diagnostics of all 300 `neg_*` tests are identical, and the suite passes 698/698. Measured against
  the compiler before either port, interleaved on one machine: `check src/main.psm` 0.700 -> 0.680 s, IR for
  `src/main.psm` 1.470 -> 1.410 s, a full self-build 6.64 -> 6.52 s, `__text` 40,071,220 -> 40,066,100 bytes, the
  linked binary +19 KB (60,065,144 -> 60,083,832 stripped), `.bss` -87 KB. The committed seed does not bootstrap this
  tree either (see below); recut it.
- **`runtime/diagnostics.c` is Prismio** (872 lines of C gone). The file registry is `src/common/source_files.psm`,
  rendering and error accounting are `src/common/diagnostics.psm`, and colour, the progress line, result lines and
  help text are `src/common/terminal.psm`; `compiler_prune_enabled` became `pruneEnabled` in `src/driver/prune.psm`.
  The five symbols C still calls are `export fn`s: `diag_file_count`, `diag_progress_clear`, and the renamed
  `diag_file_path_cstr`, `diag_file_module_cstr` and `diag_progress_cstr`. A `String` of twelve bytes or fewer has no
  pointer to give, so the registry hands C a NUL-terminated copy it owns. Diagnostics output is identical to the
  C renderer's across all 300 `neg_*` tests (plain, JSON, `FORCE_COLOR`, `NO_COLOR`), help text included; the suite
  passes 696/696 and the IR reaches a fixpoint in two generations. **The committed `bootstrap/seed.ll` no longer
  bootstraps this tree** (it declares the `diag_*` functions `extern` and the runtime no longer defines them): cut a
  seed with `prismio seed` and commit it first. The legacy `diag_error`/`diag_warning` entry points had no caller
  and were not ported. `NO_COLOR=0` is now read as unset, as the compiler's own detection always did, where
  `std.term` treats any non-empty `NO_COLOR` as set.

- **A slab allocator behind `rt_base_alloc`, and codegen allocates through it** (`docs/ALLOCATOR_PLAN.md`,
  stages 0-3). On 64-bit macOS and Linux the seam is a 64 GiB reservation carved into 64 KiB spans, each
  owned by one of 32 size classes (16 to 512 bytes), with a process-local cache for the main thread, a
  thread-local one per worker, and batches of 64 moving through a per-class shared list once a thread
  exists. A release is a range compare, a table load and a push; the old recycler's `malloc_size` query,
  512-block cap and single-thread switch are gone. Every heap object codegen allocates now calls
  `rt_base_alloc` (it called libc `malloc`), with malloc's attributes said at each call site
  (`noalias`, `allockind`, `allocsize`, `alloc-family`, inaccessible memory): without them `arena_bump`
  measured 1.52x, with them 1.000x. Median of 9 interleaved runs on Apple silicon, each pair from one
  sweep. Objects through the seam, recycler still behind it: `graph_churn_alloc` 52.2 -> 37.6 ms, everything
  else within 3% (geometric mean 0.991). Then the slab: `graph_churn_single` 22.3 -> 17.4 ms,
  `graph_churn_alloc` 35.1 -> 28.4, `graph_churn_transfer` 36.3 -> 28.2, `graph_churn_full` 109.6 -> 76.1
  (1.01x / 0.83x / 1.03x / 0.96x of C++ in that sweep, from 1.02x-1.38x before it), `manual_alloc_churn` 19.9 -> 4.2 (0.21x of C++), `tree_traversal` 0.29 -> 0.15,
  `s_expression_parse` 1.48 -> 1.15, `csv_parse` 1.08 -> 0.93; geometric mean 0.947 over the 51
  benchmarks longer than 1 ms, every checksum unchanged. `edit_distance` reads 1.2x on the median and is
  bimodal (0.58 or 0.71 ms per run, slab on or off alike, equal minimum): code layout, not the allocator. `PRISMIO_SLAB=0`
  in the environment turns it off at run time (for sanitizers and valgrind). Windows keeps the recycler,
  and 32-bit and freestanding targets use libc's allocator; Linux has not been run (KNOWN_ISSUES, The
  allocator). Output changes for every program that allocates an object (`@malloc` -> `@rt_base_alloc`);
  the compiler's own IR is otherwise unchanged by the runtime half.
- **The two allocators are interchangeable one way only.** A seam block is released by `rt_free` and
  resized by `rt_base_realloc`, never by libc; a libc block may still reach `rt_free`. The runtime's own C
  spells libc's release `tmp_free`/`tmp_realloc` and poisons bare `free`/`realloc` in every source, which
  turned up 84 releases of seam blocks with libc `free` in `build_driver.c` and the backend (all in the
  compiler's own driver, none in a program's runtime) and five compiler externs that returned plain
  `malloc` blocks to Prismio (`ir_get_temp_name` among them; now `rt_base_alloc`). A compiler built with
  the slab compiles itself to identical IR and passes the suite under `slab_free_shim` with an empty log.
- **`produce(f)` reads `f`.** The name was ignored and every release was `rt_free`. Now `produce(rt_free)`
  is the seam's own block, released like any other, and every `std/` and `src/` extern says so (36 of
  them, all `produce(free)` before); any other deallocator on a `String` result copies the bytes into a
  seam block at the call and calls `f` on the original there and then, so `produce(free)` on `strdup` is
  libc `free` and a library's `produce(lib_string_free)` is its own. A `Ptr` or scalar result is never
  released by Prismio; a struct or `Vec` result with a foreign deallocator is refused (P4112). Output is
  identical for every program in `tests/` and `benchmarks/hosted/`. `tests/test_350`, `neg_351`,
  `tests/produce_deallocators/` (`run_produce_deallocator_test`: before, the library got 0 of its 3 blocks
  back and `--verify` reported 5 violations).

- **A program built by a checkout's compiler is stamped with the real SDK.** The pinned LLVM `clang` that links
  a program from a checkout was given no sysroot, found no SDK to read, and stamped the executable
  `sdk 11.0` (the deployment floor) where Apple's `cc` stamps `sdk 27.0`; macOS gives a binary that claims
  an old SDK the older `malloc`. From identical machine code, `tree_traversal` read 1.8x, `manual_alloc_churn`
  2.1x and `s_expression_parse` 1.5x of the same program built by a packaged compiler. The link now passes
  `-isysroot $(xcrun --show-sdk-path)` (`SDKROOT` wins; a host build only), the project's runtime bitcode is
  compiled for the same deployment version as the packaged one (`SDK Version` module flag included, and the
  version is in its cache key), and `bootstrap.py --promote` no longer lets the pinned LLVM's own floor (14.0)
  leak into the promoted generation's build. A project-built compiler now times within noise of a packaged one.
- **`Map`'s columns are private, and the two Map benchmarks the bounds checks slowed are faster than
  before them.** `entryKeys` and `entryValues` are `private` (no program, test or benchmark read them;
  the compiler's own map literals and `default` read their types through `semaCompilerFieldType`, which
  skips the visibility check a program's field read gets -- `neg_312_map_columns_private`). `mapProbe` is
  `private inline fn`, and four `__builtin_assume`s state the two invariants the file keeps (a bucket is
  inside `slots`; an entry index read out of `slots` is inside both columns), so the `Vec` checks fold.
  Interleaved A/B against the build before any check, 66 hosted workloads, 15 runs, checksums identical,
  both arms packaged toolchains: `key_value_update` 0.79x (was 1.13x with the checks), `hashmap_insert_lookup`
  0.89x, `word_frequency` 0.88x, `mixed_map_removal` 0.94x (was 1.10x); the geomean over all 65 workloads
  with a measurable time is 0.984, and no workload is more than 6% slower. 

- **Freestanding code is faster and 39% smaller: Prismio's own passes in LLVM's pipeline.** Two passes in
  `runtime/llvm_bridge.cpp`, which LLVM-C cannot express, run at the pipeline's extension points
  (`PassBuilder::registerVectorizer{Start,End}EPCallback`, one bit each of `policies`). On the 20 freestanding
  workloads: instructions 0.876x of C to **0.793x** (19 fewer, 1 more), 0.789x of Rust to 0.714x, and `.text`
  29.5 KB to **18.0 KB** (C 14.9 KB, Rust 15.7 KB). The benchmark functions alone are 19.4 KB to 8.3 KB.
  - **`HotLoopUnroll`** replaces `-unroll-allow-partial -unroll-max-count=4` for the whole module. That setting
    unrolled set-up loops too, and loops LoopVectorize had already interleaved four ways unrolled four more
    (sixteen copies of a fill that runs once). The pass picks loops itself, after LoopVectorize: a hot one (its
    nest's estimated iterations at least an eighth of the function's hottest), innermost first, by a factor
    that divides its trip count and keeps factor x size within 150 instructions. It also unrolls at run time
    an outermost loop whose count comes from the input (`K * scale`), which LLVM never does on a `generic` CPU:
    `pointer_chase` 0.63x of C, `atomic_counter` 0.53x, `popcount` 0.86x. It skips a nested loop with a long
    bound and any loop of a recursive function, whose few trips per entry pay the remainder (`prime_sieve` was
    1.08x and `fibonacci` 1.23x before those rules). `PRISMIO_UNROLL_POLICY=0`, `PRISMIO_UNROLL_BUDGET` and
    `PRISMIO_UNROLL_COUNT` measure it. Windows has no bridge and keeps the module-wide setting.
  - **`CoveredFillElimination`** deletes the zero-fill of a frame array that a loop nest then writes whole
    before anything reads it, proved through SCEV: the store's address steps tile the array exactly, every
    loop in the nest has a constant trip count and exits only at its latch, and every other use of the array
    is dominated by the nest's exit. LLVM's DSE cannot see a loop's stores as covering a `memset`. 18 memsets
    in the freestanding suite became 6 (C has 2, both in its source). On every target, at every optimising
    level. `test_313_covered_fill` holds nine shapes that must keep the fill and one that loses it;
    `PRISMIO_COVERED_FILLS=0` turns it off and `PRISMIO_POLICY_TRACE=1` prints every decision.
  - A program a policy applies to runs the bridge's whole pipeline (`default<O3>` with the passes added) even
    when it is too small to partition.
- **`v[k] = x` releases the element it displaces at once where no view of it can be live**
  (`src/ir/overwrites.psm`, runtime `list_set_now` / `list_set_str_now`). It used to park every displaced
  owned element until the Vec died, because `let n = v[k]` is a view and might still be read. Now, before codegen,
  each store is proved or not: `v` is a local made fresh and never reassigned; no value that may hold a view of an
  element is assigned, returned, captured or passed to an argument AIF says the callee keeps
  (`aif_call_arg_retained`, which covers user functions through AIF's flow and builtins through their
  contracts); the new value mentions none; and no binding that may hold one is live at the store. On graph_churn
  (Apple silicon, 9 runs, against 2026-10-16's tracked run): peak memory 30.0 to **5.6 MB**, 89.6 to **4.0 MB**,
  58.1 to **2.4 MB** and 96.0 to **6.5 MB** (8x to 32x C++'s down to 1.2x to 1.4x), and time 2.14x to **1.93x**,
  1.90x to **1.55x**, 2.47x to **1.79x** and 1.99x to **1.68x** of C++ (single, alloc, transfer, full).
  `test_317_overwrite_release` holds three stores that release and five that must park (a view read after the
  store, the loop's own binder, a view kept outside the loop, the new element built from the old, a Vec handed in);
  `test_318_overwrite_peak` bounds the peak at 4 KB (528 bytes, against 176,449 parked); the `overwrite_release`
  harness test reads each function's setter. A store into a field's Vec (`frag.nodes[i] = ...`) follows the
  same proof now, with the root a local struct (below).
- **A small `Vec` is one allocation instead of two.** Its 64-byte header and its first block of elements were
  separate `malloc`s; `list_new_cap` (`runtime/lang_runtime.c`) now makes them one block when the capacity is known
  and the elements take at most 256 bytes on the heap (`RtList.fused`), and the first growth moves the elements to a
  block of their own. On graph_churn, where every node owns a `Vec<Int>`: blocks allocated 33% to 42% fewer, and time
  1.67x / 1.53x / 1.84x / 1.63x to **1.28x / 1.48x / 1.24x / 1.36x** of C++ (single, alloc, transfer, full), peak
  RSS 1.1x to 1.5x of C++ (a fused header is padded to 16 bytes). Leak counts that count blocks halve (`test_302`,
  `test_321`). `test_323_fused_list`.
- **A field store releases the value it displaces wherever no view of it can be live.** `r.f = x`,
  `v[i].f = x` and `r.v[i].f = x` used to release only the first store to a fresh local, so a loop that kept
  replacing a node's edge list leaked every list it replaced (`n.edges = mkv(step)` over 1,000 steps: 2,002
  allocated, 2 released). `src/ir/overwrites.psm` runs the same proof as a `v[k] = x` overwrite with the root of
  the path as the container: a local made by a struct literal, an owning call, `expect` of a received value or a
  fresh Vec; no view of it leaves the function's bindings; the new value mentions none; none is live at the
  store. The root itself being moved on (sent, returned, pushed) does not count, which is what lets a stage that
  edits a fragment and forwards it release. Now 2,002 released, peak 536 bytes. `graph_churn.*` is written with
  plain field assignment in all three languages and balances (0 leaked, 0 violations on all four arms).
  `test_320_field_store_release` and `test_321_field_store_parks`.
- **A small pure tree-recursive function is inlined into itself once** (`SelfRecursionUnfold`,
  `runtime/llvm_bridge.cpp`, at the early-simplification extension point, before TailCallElim). Unfolded,
  `fib(n - 1) + fib(n - 2)` is four calls of which two have the same argument, and a call that reads no memory
  is merged with its twin once FunctionAttrs has marked it: three calls a level instead of four, a growth rate
  of 1.466 per level instead of 1.618. `fibonacci` 4.96M to **0.35M** instructions, 0.940x to **0.066x** of C,
  for 28 bytes; its leaf path is also the 3-instruction minimum now, where it saved three registers before.
  Only for a body of at most 40 instructions with two or three self-calls and no other memory access or call;
  from -O2, not -Os/-Oz, on every target. LLVM's inliner never inlines a function into itself (GCC's does).
  `test_316_self_recursion_unfold` checks four such functions against loops; `PRISMIO_SELF_UNFOLD=0` turns it
  off. A second level, with EarlyCSE, GVN and SimplifyCFG between, left four calls and was slower.
- **A private function's parameters take their range from its calls, and an index its record layout.**
  Two facts the interval walk (`src/ir/nowrap.psm`) did not have, which put Prismio ahead of C on all 20
  freestanding workloads (geomean 0.791x to **0.782x**; 0.714x of Rust to 0.705x; with the unfolding above,
  **0.685x** of C and **0.617x** of Rust):
  - **Call-site parameter ranges** (`src/ir/param_ranges.psm`). Before any function is generated, as AIF reads
    the whole module, the walk runs over every caller and records each argument's interval at every call to a
    private function; the join is where that function's own walk starts, and LLVM is told as a `range`
    attribute (`ir_function_param_range`). Nothing is claimed unless every call is seen: an exported, public,
    generic, `async` or method function gets none, and so does one whose name is used as a value or spawned
    anywhere in the module, or one with any call the walk did not record. `heapsort` 1.003x to **0.966x** of
    C: told `sift`'s `start` is in [0, 1023], LLVM proves the sift loop's indices non-negative and indexes with
    a free zero-extension instead of `sxtw`, which C gets from signed overflow being undefined and IPSCCP alone
    does not find (it widens a loop counter to the full range). The walk also divides now (`(2048 - 2) / 2`
    was an unknown), and a call in an `if` condition is recorded once.
  - **Congruences** (`src/ir/strides.psm`). An immutable `let` keeps what it is modulo a stride
    (`base = (pc * 4) as Int` is 0 mod 4), and an immutable literal array its elements, so `program[base + 1]`
    is bounded by the elements one past a multiple of 4 rather than by all of them: `bytecode_interpreter`'s
    `reg[a]` and `reg[b]` lose their checks, 0.980x to **0.777x** of C. The interval and congruence domains'
    reduced product (Granger 1989).
  - `test_314_param_ranges` and `test_315_index_strides` with the `param_ranges` and `index_strides` harness
    tests that read the IR. `test_179`'s three must-stay-plain functions are `public` now: main's one call to
    `shiftedBackTwo` passes 2, which proves the op that test keeps unmarked.
- **The freestanding failure core is collected by the linker.** Native sources of a `--freestanding` build
  compile with `-ffunction-sections -fdata-sections -fno-asynchronous-unwind-tables`, so the link's
  `--gc-sections` drops the `panic.c` functions a program never calls (552 bytes of fourteen functions, of
  which the suite calls one) and their strings, and no `.eh_frame` is emitted (`.rodata` 2,069 to 1,792 bytes).
- **Four freestanding Prismio arms were not the C program.** `mandelbrot_fixed` ignored `scale` (a constant
  `0..<6` that LLVM unrolled six ways, 5,952 bytes), and `matrix_multiply`, `crc32` and `atomic_counter`
  counted with a signed `Int` range, which may count down and so carries a second loop copy, where C counts
  in `u32`. All four count in `U32` now. `PRISMIO_BENCH_C_FLAGS` adds flags to the C arm; `-funroll-loops`
  changes nothing on `generic` (the image is byte-identical), so the C arm with Prismio's old unrolling is
  `-mllvm -unroll-allow-partial -mllvm -unroll-max-count=4`.
- **An index out of range stops the program, on a `Vec` and on an `Array<T, N>`**
  (`docs/MEMORY_SAFETY_PLAN.md` §2). A `Vec` read used to answer the element type's zero, a write
  did nothing and `swap` was a no-op; an array read or wrote the neighbouring stack. Now each prints
  `runtime error: index 6 is out of range for a Vec of length 1` (or `for an array of length N`)
  and exits, as `remove`, `insert` and a `Slice` already did; in a freestanding program the failure
  reaches `prismio_panic_hook`. A constant array index out of range is a compile error. The check is
  a compare and a branch to a cold call that never returns, skipped where a loop's range proof
  or the interval walk (below) covers the access; codegen's inline flat-list paths, which answered 0 themselves, trap too. A
  `[T]` view is not checked yet: it gets its length in the next step. Twenty fixtures that checked
  the old zero now check the trap, through a new harness form, `// expect-trap: <argument> =>
  <message>`, that runs the program once per case.
- **Function markers: `inline`, `inline(always)`, `inline(never)`, `noinline`, `hot`, `noreturn`.** Written
  directly before `fn` (after a visibility marker), at top level or in an `impl` block, in any order, with
  `cold`, `export`, `naked`, `section`, `align` and `async`; contextual, so a variable or function may still be
  named after any of them. `inline fn` is a hint (`inlinehint`, Rust's `#[inline]`); `inline(always) fn`
  forces it (`alwaysinline`, `#[inline(always)]`; ignored by a `-g` build); `inline(never) fn` and `noinline fn`
  are two spellings of `noinline`, the second being the one the compiler's own sources use; `hot fn` is LLVM's
  `hot`; `noreturn fn` is LLVM's `noreturn`, and is held to it: a `return`, or a path to the closing brace, is
  an error (`P4001`), while a call to one ends the path for definite-return and definite-assignment, so a
  function whose last branch calls it needs no `return`. Markers that contradict each other (`cold` with `hot`
  or `inline`, `inline` with `noinline`, `naked` with `inline`, a word twice) are `P3201` where they are written.
  **`inline fn` used to mean `alwaysinline`; that is now `inline(always)`.** Fixtures `test_312_inline_fn`,
  `test_334_fn_attributes`, `neg_310_inline_cold`, `neg_345`-`neg_347`, the `inline_fn` and `fn_attributes`
  harness tests (read the IR).
- **`const fn` and `const`.** `const fn area(w: Int, h: Int) -> Int { return w * h }` is an ordinary function that
  a constant may also call; `const CELLS = area(8, 8)` (top level, with a visibility marker, or in a function)
  is a declaration whose value the compiler works out and replaces by the literal it came to. The evaluator
  (`src/sema/const_eval.psm`) is a tree-walking interpreter over the parser's own AST, run first in sema: integers
  of every width and `Bool`; `let`/`let mut`/assignment; `if`, `match`, `while`, `loop`, `for` over a range (`step`,
  counting down), `repeat`, labelled `break`/`continue`, `return`; recursion; global constants. Arithmetic is exact
  and every value meeting a declared type must fit it (`as` truncates), so a constant equals what the function
  computes at run time or is refused; a step budget and a depth limit turn an endless loop into an error. A
  constant call is also an array's length (`Array<Int, area(2, 3)>`). Strings, floats, structs, generics and
  methods are refused by name for now. `const` is contextual (`const hot = 3` is a constant called `hot`).
  Fixtures `test_335_const_eval`, `neg_348_const_cannot_evaluate`, `neg_349_const_declaration`.
- **One grammar for function modifiers.** `src/parse/modifiers.psm` replaces four parsers (`cold`, `async`,
  the `export`/`naked`/`section`/`align`/`inline` run, and the `impl` block's own marker loop); a method now takes
  every marker a free function does except the symbol ones (`export`, `naked`, `section`, `align`, refused with
  a message). `src/ast/fn_attrs.psm` names every bit and every question (`nodeIsHot`, `nodeIsNoreturn`, ...), `cold`
  moved off `FUNCTION.i1` into it, and `src/ir/fn_attributes.psm` is the one table from markers to LLVM
  attributes, through a single `ir_function_attribute(name)` in `llvm-api-backend.c`.
  The IntelliJ plugin and the TextMate grammar read the new words; the docs have an *Inlining*, *Hot functions*,
  *Functions that do not return* and *Constant functions* section on the functions page, a *Constants* section on
  variables, and the grammar page lists the modifier grammar. `bootstrap/seed.ll` is re-cut: `std/map.psm` uses
  `inline(always)`, which the previous seed could not parse.
- **`__builtin_assume(cond)`, std only.** A fact std's own data keeps, handed to LLVM (`llvm.assume`):
  unchecked and undefined when false, so a program cannot call it (`neg_311_assume_outside_std`). It is
  how the Map's `Vec` indices stay proved without a bounds check (below). AIF contract `borrow`;
  guard-safe in the flat-loop matcher; in the AIF oracle.
- **An array index the compiler proves in range has no check** (`src/ir/nowrap.psm`,
  `src/ir/contents.psm`). The interval walk that marks `nsw` now proves indices too, in every
  function that subscripts a fixed array, not only those with a loop, and knows more:
  - `U32`, `U16`, `U8`, `I16` and `I8` locals, each with its own type's wrap rule, beside `Int`;
    `*`, `>>` and `&` by a literal, an unsigned `%` by a literal or a bounded divisor, and `as`
    between integers when the value fits.
  - A comparison narrows its locals on both branches: `a < b` puts `a` below `b`'s largest value
    and `b` above `a`'s smallest, and its negation holds in the `else` and after a loop that has no
    `break`. `!=` trims an interval whose edge it names.
  - A variable the loop assigns keeps a fact when one is inductive: a guess from the facts at entry
    is widened by what a side-effect-free walk of the body leaves at its end, jumping to the next
    literal the loop compares it with, until it stops moving (widening with thresholds, Blanchet
    et al., PLDI 2003). A `continue` anywhere in the body turns it off, and a `break` keeps it out
    of the facts after the loop. Binary search's `lo` and `hi` are the case.
  - `for i in a..<b` bounds `i` in its body, in either direction.
  - A local array of any of those integer types keeps a bound on its elements; an array whose type
    cannot hold its family's bound fails alone. A value read through an immutable `let` bound once
    (`let t = order[i]; ... order[j] = t`) counts as a read of the array.
  - A program's own `min` or `max` is recognised by its body, not its name.

  Freestanding, in instructions: `binary_search` 13,438,400 to 11,036,304 (C 11,036,304),
  `pointer_chase` 14,448,592 to 9,629,904 (C 9,629,904) and `bytecode_interpreter` 10,400,032 to
  9,650,048 (C 9,850,032), the three rows the checks above had cost. `test_311_proved_indices`
  checks five proved shapes and twelve that look provable and are not -- an off-by-one `<=`, a
  `U32` below zero, an exit the end of the body does not see, a large `U32` cast, a mask one too
  wide, a store nothing bounds, a `let` bound twice -- each of which still stops at its index;
  `proved_indices` reads the IR for which keep a check. Hosted: 66 workloads in an interleaved A/B
  against the build before, no change outside noise, every checksum identical.
- **A freestanding build unrolls loops** (`ensure_codegen_initialized`, `runtime/llvm-api-backend.c`).
  LLVM's AArch64 cost model unrolls nothing partially for a CPU without a loop buffer, which
  `generic` is, for clang and rustc as for Prismio. A freestanding target now gets partial
  unrolling, a trip count known at compile time, at most 4 copies. Measured on the suite: a
  geomean of 0.914 of the build before, no workload worse; `edit_distance` 5,540,624 to 4,207,920,
  `matrix_multiply` 0.69, `sha256` 0.70, `crc32` 0.69. `.text` grows from 17.2 to 29.9 KB; `-Os` and
  `-Oz` keep LLVM's zero threshold for size and do not unroll. Runtime unrolling went further
  (0.853) but cost `fibonacci` 31%, whose tail-recursion loop pays the trip-count prologue on each
  of 300,000 short entries. *Superseded on 2026-10-16 by `HotLoopUnroll` (above): the module-wide setting
  remains only where there is no C++ bridge (Windows).*
- **Freestanding benchmark verdicts are absolute** (`benchmarks/freestanding/suite.py`). The count
  is exact, so fewer instructions than the other arm is a win, more is a loss, and only an equal
  count is level; the hosted suite keeps its noise-aware tolerance. The +-2% band had called
  `edit_distance`'s 5% and `heapsort`'s 2% parity. Ratios print to three places. The suite now reads
  17 fewer, 3 level and 0 more against C (geomean 0.876), and 15, 5 and 0 against Rust (0.789);
  under the absolute rule it read 7, 3 and 10 against C when this work began.
- **The second half of the IR pipeline runs in the codegen partitions, in parallel.** `default<O3>`
  is now run in two halves through the C++ bridge (`prismio_llvm_run_default_half`, built exactly as
  `buildPerModuleDefaultPipeline` builds it): the module simplification pipeline -- the inliner and
  everything it drives -- on the whole program, then the module optimisation pipeline (loop
  rotation, vectorisation, unrolling and their cleanups, one function at a time) inside each
  partition, on its thread. Every inlining decision is still made on the whole program. On the
  compiler's own build the pipeline plus machine code takes 3.63 s (was 4.30 s), on the hosted
  benchmark program 552 ms (was 662). It is not byte-identical to one `default<O3>` -- analyses the
  first half leaves cached cannot cross into another thread -- so it was measured: 47 hosted
  workloads at ten times their size, geomean 0.995 against 1.000 for an identical-binary control,
  every result equal. A program too small to partition keeps the single pipeline and its exact
  output. `PRISMIO_SPLIT_PIPELINE=0` turns it off; Windows, with no bridge yet, runs it whole.
- **Machine code is emitted in parallel for `-g` and `-O0` builds too, and every partition reads
  only its own functions.** A `-g` build used to emit on one thread, on the belief that the
  debug map wanted one object; each partition now carries the compile unit and the subprograms
  of what it emits, as an LTO-partitioned link does (`dwarfdump --verify` clean, breakpoints,
  locals and globals in lldb identical to a one-partition build). Each partition also used to
  parse the whole module and delete seven-eighths of it; it now loads the bitcode lazily and
  materialises only its own bodies (`prismio_llvm_drop_body` in the bridge drops the rest
  unread). On the compiler's own build, machine code takes 216 ms at `-g` (was 512) and 608 ms
  in release (was 754), with byte-identical output. Windows, which has no bridge yet, parses
  whole as before.
- **macOS programs bind through chained fixups, and a small one is 16 KB smaller.** At the
  deployment floor ld64 used lazy binding, whose `__la_symbol_ptr`, `__stub_helper` and
  `__dyld_private` gave `__DATA` file contents and so a whole 16 KiB page. Linked with
  `-fixup_chains`, hello is 33,952 bytes (was 50,504; C's is 33,424) and its `__DATA` is
  zero-fill only. A program whose `__DATA` has initialised data of its own keeps the page.
- **A build big enough for parallel codegen links through `ld` directly too.** The cached
  `ld` line (2026-10-10) took only a program with one object, so every build split into
  codegen partitions went back through the `cc` driver: the hosted benchmark program linked
  in 29.9 ms, now 16.9 ms, as hello does. The cached line names the first object once and
  the build puts the other partitions back after it, in the order the driver had them, so the
  executable is byte-identical to the driver's.
- **A local may be declared without a value, and every read the compiler cannot prove
  follows an assignment is an error** (`sema/assign.psm`): ``` `r` may be used before it
  is assigned ```. Branches join, a path that returns, breaks, continues or panics
  contributes nothing, a `match` must cover every variant or have a `_`, and a loop that
  may run no times assigns nothing as far as the code after it can tell. An immutable
  `let` declared this way takes one assignment (a second, or one a loop could repeat, is
  an error); assigning a field of an unassigned struct is a read of it. `let x: T =
  default` still asks for the type's default, and an array, a `Vec` and a `Map` keep
  their empty or zeroed start.
- **`__builtin_*` is the standard library's.** A program that writes one is refused,
  with the wrapper to write instead (`s.length`, `min(a, b)`, `portOutU8(port, v)`,
  `volatileLoadU32(address)`, `asm("nop")`). The compiler's own `src/`, `ums/`, the
  tests, the benchmarks and the sandbox moved to the wrappers. `nowrap` proofs treat
  `std.math`'s `min` and `max` as the builtins they wrap.
- **Structs are `internal` and their fields `private` unless marked.** The tree was
  migrated by compiling every entry point and widening each declaration to the level
  its uses need: `internal` within a package and `public` across them. The standard
  library's structs a program names (`Buffer`, `Arena`, `Duration`, `Instant`,
  `Args`, `Child`, ...) are `public`. **`src/` now uses the new syntax, so the pinned
  seed can no longer parse it.** A seed was cut from this tree and a compiler built from
  only that seed reproduces its own IR; publishing it and committing the pin is open
  (`docs/KNOWN_ISSUES.md`), and until then a clean checkout cannot bootstrap.
- **The runtime and library bitcode is merged lazily on macOS and Linux.** Every library module
  is read with `LLVMGetBitcodeModuleInContext2` (prototypes only), the set of definitions the
  program reaches is computed across all of them, and `Linker::LinkOnlyNeeded` links just that
  set, where every function was parsed and linked and most were then pruned. The one thing
  LLVM-C cannot say is in `runtime/llvm_bridge.cpp` (`prismio_llvm_materialize`,
  `prismio_llvm_link_only_needed`), a new compiler source; Windows links `LLVM-C.dll`, which
  has no C++ API, and keeps the whole-module merge until it links LLVM statically
  (`docs/LLVM_BRIDGE_PLAN.md`). A hello-world build is 36.1 -> 34.5 ms (median of 40); the
  library read alone is 1.1 ms cold against 3-4 for a whole parse. The program is the same
  in everything but order: the merged module has the same functions and globals, and 135 of the
  136 test programs whose binary changed have the identical symbol set and size (the other is
  16 bytes smaller). IRMover lays functions out in discovery order, which ran through bodies
  that are no longer read. The hosted benchmark suite, whole against lazy, is a geomean of
  1.0007 across 66 arms; two runs of the *same* compiler are 1.0154, with 7 arms beyond their
  own noise tolerance against 2, so the layout change is inside run-to-run noise.

- **A macOS program links by running `ld` directly**, not `system()` -> `/bin/sh` -> `cc` ->
  `ld`. The driver is asked once with `-###`, and its `ld` line is kept in
  `$TMPDIR/prismio-link-cache` with the object and output as markers, keyed on the driver
  line and `DEVELOPER_DIR`/`SDKROOT`/`MACOSX_DEPLOYMENT_TARGET`. Every absolute path the line
  names (the linker, the SDK, `libclang_rt.osx.a`) and `/var/db/xcode_select_link` are
  recorded by identity, so an Xcode update or `xcode-select --switch` sends the next build
  back to the driver; an `ld` that fails falls back to the driver and drops the entry. Only
  for a program with no native objects, link arguments or exports. Building one line that
  prints: 46.3 ms to 36.0; all 254 `tests/test_*.psm` programs build byte-identical
  binaries, in 26.1 s against 28.9. `PRISMIO_LINK_CACHE=0` links through the driver.
- **Standard-library functions a program cannot call are dropped after type checking**
  (`src/driver/prune.psm`), so the ownership analysis and IR generation never see them.
  Reachability is read off the calls sema resolved, closures and function values included,
  and a trait object keeps every method of the impl it was built from; a program's own
  functions are always kept, so no diagnostic depends on it. Printing one line: ownership
  analysis 0.61 ms to 0.09, IR generation 0.95 to 0.24. `PRISMIO_PRUNE=0` turns it off.
  **It is not output-neutral, deliberately:** a dead function used to decide how a live one
  compiled. `region_confined` counted dead callers, so the `eprintln` overloads a program
  never called made `std.io`'s `write` look reachable from outside a region and let the cost
  model bracket an arena around a `println` -- an opaque call the obligation exists to
  refuse. `test_62_split_release` and `forced_layout` leaned on that and now do their work
  outside the printing function. `prismio aif` lists the imported sites the program can
  reach, not every one in the modules it imports.
- **Flat-guard verdicts are per function, not per name.** A call is judged by the function
  sema resolved it to (`CALL_EXPR.s2`), falling back to its source name only when it has
  none. By name, one unsafe overload poisoned every call spelled the same: `Buffer.eq`
  reaching an extern took the guard from every `Map` probe in a program importing
  `std.mem`, and one closure that pushes took it from every closure call. The benchmark
  binary is now identical with pruning on and off. Against `65de043` (C Float printers, no
  pruning, name verdicts), with both compilers bootstrapped two generations and the suites
  interleaved, 3 x 15 runs: hosted geomean 0.998 over 66 workloads, five functions with
  different instructions (the two `listSortRange` instantiations gain their guards,
  sort_strings 5.9% faster), the binary the same 242,128 bytes, the suite compiled in
  842 ms against 862. `gcd_lcm` (+12%) and `edit_distance` (-15%) are identical
  instructions at another address.
- **Tight integer loops get the no-wrap facts C gets from undefined overflow.** `Int` still
  wraps. Four analyses now tell LLVM where it provably cannot:
  - A loop over an `Array<T, N>` with no list guard is versioned on the facts that keep its
    accesses in range (`arrays` in `src/ir/ranges.psm`). Innermost loops only, and only when the
    proof marks arithmetic.
  - An unchecked access to a fixed array or a `[T]` view leaves its index in `[0, Int.MAX - 1]`,
    which marks the `+` and `-` it bounds `nsw` (`src/ir/nowrap.psm`).
  - A counted `while` (`i < e` or `i <= e` and the like as a conjunct, and a last statement that
    steps `i` by a literal) bounds its counter in the body and counts its iterations
    (`src/ir/counters.psm`).
  - A local `Array<Int, N>` that nothing but a subscript names keeps a bound on its elements
    (`src/ir/contents.psm`): each store's value is described relative to the elements it reads, and
    the counted loops bound how far stores can raise them in one lifetime of the array.

  Freestanding, in instructions: `quicksort` 11,304,368 to 9,991,296 (C 10,096,384); `knapsack`
  5,690,512 to 3,139,600 (C 5,122,624), because its guard holds `w >= 0`, a fact C's undefined
  overflow never supplied; and `edit_distance` 5,900,624 to 5,540,624 (C 5,596,832), because its
  rows stay in `[0, 360600]`, so `min(a + 1, b + 1)` becomes `min(a, b) + 1`. `sha256` moved
  9,018,112 to 8,634,112, from code shape rather than a proof. Against C the suite reads 4 fewer,
  16 level and none more, geomean 0.95x (it was 3, 14 and 3, 0.99x). The hosted suite's 140
  functions are instruction-identical against a baseline without the change. The compiler's own
  IR gains 41 `nsw` (369 to 410), and emitting it costs 0.9% more instructions. `PRISMIO_NOWRAP=0`
  turns the marks from the last three off, as `PRISMIO_RANGE_PROOFS=0` does the proofs', to
  separate what each buys. Because the compiler relies on it, an out-of-range index into a fixed
  array or a `[T]` view is now specified as undefined behaviour.

- **A sieve runs as a segmented sieve, from the plain source** (`src/ir/tiling.psm`,
  developer docs: Stride tiling and square bounds). A nest that stores one value at a stride -- `while (..) {
  if (v[p]) { let mut m = ..  while (m <= n) { v[m] = false  m = m + p } }  p = p + 1 }` --
  gets a copy that runs the outer loop with each inner loop cut at a 64 KB window (32 KB off
  Apple silicon), then sweeps every later window across all the recorded iterations. Stores
  of one value commute, so only the guard's reads could tell, and those all land in the first
  window; any iteration the copy cannot match exactly hands over to a plain copy of the loop.
  Two windows or more, a flat list, every store in range; nothing else in `src/`, `tests/` or
  the benchmarks matches. Whole sieve on an M5: 1.18 ms to 0.70 ms at n = 10^6, 13.8 to 7.3 ms
  at 10^7, 339 to 80 ms at 10^8 -- the hand-tiled C's 0.71, 7.6 and 84. Hosted `prime_sieve`
  482 to 420 µs, against C++'s 454 and Rust's 622. Packing `Vec<Bool>` to bits was measured
  and rejected: 0.21x-1.06x, tiled or not.
- **`x * x <= n` bounds `x`** (`emitSquareBound`, `src/ir/ranges.psm`). The square is `Int`
  arithmetic, so the range guard folds a start within 46340 and `isqrt(n) + step <= 46340`,
  and then `x <= isqrt(n)` in the body. A sieve's outer loop proves `prime[p]` (it was checked)
  and its `p = p + 1` becomes `nsw`, the fact LLVM needed to count the inner `m += p` loop and
  interleave its stores: 8-15% on a sieve whose `n` is read at run time. The hosted benchmark's
  `n` is a constant LLVM had already propagated; there this alone measured 1.5% slower with the
  hot loop instruction-identical, which is layout.
- **On AArch64, a branch on two conditions splits again when one is a single bit test.** LLVM 23's
  AArch64 backend gained a cost model that computes `a and b` together and branches once, and it
  merged even where one condition is a lone `tbnz`: `ring_buffer`'s
  `if (((s >> 8) & 1) == 0 and head != tail)` cost `ubfx; cmp; csinc; tbnz` on every iteration,
  where LLVM 22, and so rustc, emit `tbnz` and stop half the time. The compiler now passes
  `-aarch64-br-merging-cbz-tbnz-bias=8` (LLVM's default is 6), which splits that shape. Freestanding,
  `ring_buffer` runs 4,429,696 to 3,753,472 instructions (C 4,429,312, Rust 3,753,472), no other row
  moves, and the suite reads 5 fewer, 15 level and none more against C (geomean 0.95x) and 9, 11 and
  none against Rust (0.85x). Hosted, 11 of 140 functions change and the timings do not: geomean 0.999
  over 52 workloads, against 1.001 for an identical-binary control in the same interleaved runs.
  Compiling the compiler moves by +0.1% in cycles, inside its spread. `PRISMIO_LLVM_ARGS` overrides
  the option.

- **`Option<T>` is gone; `T?` is the optional.** Two spellings of "a `T` or nothing"
  were one more thing to learn and to convert between, and `T?` already did the same
  work for numbers, `Bool`, `Char`, fieldless enums, `String`, `Vec`, structs and `Ptr`.
  Every function that answered an `Option` answers a `T?` now: `Vec.get`, `pop`,
  `min`, `max`, `find`, `removeFirst` (and the array and slice forms), `Map.get` and
  `mapGet`, `String.get`, `find`, `stripPrefix` and `stripSuffix`, `process.env`,
  `readLine` and `prompt`, `tryReadFile`, `tryReadLines`, `readLink`, `realPath`,
  `metadata`, and `Result.ok()` and `err()`. A number's `T?` is a value that
  allocates nothing; a reference's is a pointer. To migrate: `Option.Some(x)` is `x`
  and `Option.None` is `none`; `optionOr(o, d)` and `o.unwrapOr(d)` are `o ?? d` or
  `o.unwrapOr(d)`; `o.isSome` and `o.isNone` are `o != none` and `o == none`;
  `optionIsSome(o)`, `optionIsNone(o)` are gone with `Option`; and `match` on an
  `Option` becomes a test against `none` and `expect(o)`. A `T?` parameter now takes
  its `T` from an optional argument only, so `a.map(f)` on a value that is not an
  optional never reaches `std.option`'s `map`.
- `println` of an optional shows the value or `none`, as before; a `String?`, an
  `Int?` and the other scalars need `import std.display`, as before.
- **AIF reports an array as a frame slot.** An array literal and an `Array<T, N>`
  were always an `alloca`, but the analysis tiered them as heap blocks (78 of the
  1,025 allocation sites in the tests, corpus and benchmarks) or, in a bracketed
  call, as `arena:auto`. They are T0 now and `prismio aif` says *stack, fixed-length
  array; lives in the frame*. The wrong tier also made the analysis count the array as
  served by the caller's arena, so a call to a function that only built an array was
  wrapped in an `arena_push`/`arena_pop` pair that served nothing: 520 such brackets
  (1,365 pops) leave the IR of the tests, corpus and benchmarks, and the arena
  counters read 183 fewer regions entered with the same 19,528 objects and
  6,863,136 bytes served. SPEC 4.2 and the Python oracle carry the same rule, and the
  engine and oracle agree on all 17 differential sources. The README's `prismio aif`
  example is regenerated.
- **A `Vec` literal allocates exactly its length.** `vecOf` started from an empty list
  and grew it 0 → 4 → 8; each overload now starts from `list_new_with_capacity(n)`.
  A function building a four-element literal runs in 0.80× of the time and an
  eight-element one in 0.64× (`Vec` capacity of `[7]`, `[1, 2, 3]` and `[1, …, 8]`
  was 4, 4, 8 and is 1, 3, 8).
- **A copy loop is one `memcpy`, and a repeated one is deleted.** `for i in a..<n
  { dst[i] = src[i] }` on two flat `Vec`s now becomes a single block transfer under
  a length guard, as the `while` spelling already did. The transfer is a `memcpy`
  skipped when both names are one list, and it tells LLVM the two blocks are
  separate allocations, so a copy nothing reads before the next identical one is
  deleted — which is what C++ and Rust do with `std::vector` and `Vec`.
  `large_buffer_copy` (eight identical rounds) goes from 1.16× of C++ and 1.17× of
  Rust to 1.00× and 1.02× (6.5 → 5.6 ms, three interleaved pairs).
- **A counted fill reserves its final size whatever else the body does.** `for i in
  0..<n { let v = i % 997  xs.push(v)  sum = sum + v }` used to reserve nothing,
  because the reservation required the push to be the loop's only statement, and
  the empty list then failed the capacity guard: every push was an out-of-line
  call. Any push that is a statement of the body (not in an `if`) now counts, in a
  body with no `break`, `continue` or `return`, and the reservation is one exact
  `list_reserve` rather than a doubling loop from 4. `vector_growth` goes from
  11.34 to 9.63 ms (0.85×; 1.06× of C++ to 0.90×) with peak RSS 34.7 → 17.1 MB, and
  `transient_allocation` from 0.593 to 0.395 ms (0.67×); minima of 15 interleaved
  pairs, checksums equal, 15 other changed benchmarks within ±1%.
- **A heap `Vec` grows by `realloc`.** `list_inline_grow` and `list_push_grow` allocated
  a block twice the size, copied and freed the old one; a list with no arena now asks
  the allocator to extend its block, which it can do in place or, for a large block,
  by remapping pages. A list from an arena, or grown while an arena hint is active,
  keeps the old path. `word_frequency` runs in 0.90× (31 interleaved pairs); the other
  hosted benchmarks are within noise, most of their fills being reserved up front by
  the change above.
- **A remainder by a literal is a conditional step when its dividend allows.** A
  local that a loop assigns only remainders by a literal keeps that remainder's range
  at the loop's head, and a `%` whose dividend then lies in (-2m, 2m) becomes compares
  and selects instead of a multiply-by-magic-constant `srem` (`src/ir/residues.psm`).
  `checksum = (checksum + value) % 1000000007` is the case: `vector_growth` goes from
  9.67 to 4.06 ms (0.42×), and in the suite from 1.06× of C++ to 0.46× (0.50× of
  Rust) with the reservation above; `polynomial_evaluation` 0.91×,
  `recursive_tree_rebuild` 0.97×; minima of 21 interleaved pairs, checksums equal.
  A dividend whose range is not bounded, or does not fit `Int`, keeps the `srem`.
- Compiling the compiler's own source is about 3% faster (0.677 s → 0.658 s, median of
  seven interleaved runs).
- The bootstrap seed is `bootstrap/seed.ll`, tracked by git, and `tools/bootstrap.py` reads it for
  `--seed`: no release asset, no SHA-256 pin (`bootstrap/seed.json`) and no downloader
  (`tools/fetch_seed.py`). `tools/refresh_seed.py` writes it. A refreshed seed is never staged or
  committed until the maintainer says so -- at ~20 MB, a commit per refresh would bloat the history --
  and `.githooks/pre-commit` refuses it (`PRISMIO_ALLOW_SEED_COMMIT=1` overrides;
  `git config core.hooksPath .githooks` enables it). The CI step that required the committed seed
  to match `src/` is gone: a seed is the compiler as of a release, not of the working tree.
  `tools/bootstrap.py` and `tools/refresh_seed.py` replace the `.sh`/`.ps1` pairs (one script on every
  platform), and two project commands wrap them: `prismio bootstrap` builds gen0 from the seed, then gen1 and gen2,
  and `prismio seed` cuts `bootstrap/seed.ll` from `build/gen2` and checks it bootstraps. `--promote` (on the script, or `prismio bootstrap --promote`) then installs the last generation as the checkout's local toolchain by running its own `build --release` and `build`, which writes the trust stamp a copied binary would lack.
  `bootstrap` is no longer a reserved verb: the stub that answered `prismio bootstrap` with "has been removed"
  (P1034) is gone and the name is free for a project command, so a `build.ums` that declares one needs a
  compiler from this tree (an older install rejects it with P1062).
- The project host in `build.ums` and `sandbox/build.ums` is the release build
  (`.prismio/build/release/prismio`, built by `prismio build --release`), and the
  `release` and `bench` commands use it. `verify`, `gate` and `package` still name the
  debug build.
- README: the "Changelog" link points to the release notes, the archive list names
  all five platforms with which are tested in CI and which on virtual machines, and
  the performance figures are those of the 2026-10-06 run: 0.85× of C++ and 0.83× of
  Rust by geometric mean over 62 workloads (0.87× and 0.84× before). The benchmark
  suite shows **no net change from the compiler work above** (1.006× against a 1.010×
  drift between two runs of the same compiler); four workloads moved 7–10% with none
  of their functions' IR changed, which is code layout.

### Fixed

- **`prismio release` shipped the previous host, not this checkout's compiler.** When the host is the binary `build --release`
  replaces, it stages the new compiler as `prismio.next` and the launcher renames it over the host after the build process
  exits, so `tools/release.py` read `prismio` right after the build and packaged the compiler that had done the building. With
  an unchanged tree that is the same binary, so it went unseen; after a source change the archive had the last bootstrap's
  compiler (no formatter rule it had just gained). It clears a stale `prismio.next` first and ships the fresh one.

- **`import std.io.println` of a pack failed: `unknown function println$pack$Int`.** An instance made from a generic or a
  pack is named for its template and its types, and the selective-import check looked that whole name up in the set the file
  named. It reads what comes before the first `$` now (`tests/test_359`).

- **An `extern fn print(s: String)` beside `import std.io` linked `_print`.** Resolution retires an `extern` once a `fn` of the
  name is defined, and a pack was not counted as a definition, so a program that re-declared `print` or `println` as an extern
  (several tests do) bound to a libc symbol that does not exist. A pack counts, and `monoConcreteOverloadFits` applies the same
  rule, so the extern no longer stops a pack from being tried.

- **The language server hinted `args:` on every value of a variadic call.** A pack parameter gets no inlay hint now, and the
  `lsp` fixture no longer reads the shared temporary directory, so a language server running in an editor (or a killed one's
  leftovers) cannot fail it.

- **The first project build in a fresh `TMPDIR` aborted.** `merge_curated_into_program` released the results of `command_quote_arg`
  (`rt_base_alloc` blocks) with libc `free`, which aborts on a slab block ("pointer being freed was not allocated", exit -6)
  whenever the curated-module cache entry had to be built; a warm cache skipped the path, so it passed on every machine that had
  built anything and failed in the suite's fresh TMPDIR (`ums`: "stage 0 did not build the first project host") and would have in
  CI. The three `tmp_free` calls are `rt_free`; the `ums` fixture's first build always runs with a fresh `TMPDIR`, which fails on
  the compiler before the fix and passes after; `slab_free_shim` reports nothing over cold builds of both targets.

- **The language server leaked 66 KiB a request, and the ledger could not see it.** A `for line in readLines(path)` left by
  `return` or `break` keeps its descriptor and 64 KiB buffer until exit (`std.fs` says so: call `close`); every index lookup in
  `lsp/index.psm` returned from inside one. And `completionItems` cut the document with `substring`, which made every request
  path that held the document leak a copy (hover too, which never completes). `lsp_features` now holds 130 rounds of six
  requests on a 99 KiB document to 6,000 KiB of growth and measures about 450; it read 70 MiB. The server also removes its
  index files on exit. Method and rules: the developer docs' *The language server*.

- **Assigning a variable to an `Int?` stored 0.** `found = i` into a scalar optional passed the type check and stored the
  bare value where a `{ present, value }` pair belongs, so a loop that remembers its last match read back as 0 or as
  `none`; only a literal (`found = 5`) was wrapped. `semaAssignment` now sends every value stored into a scalar
  optional through `semaCheckValue`, the path `let` and `return` already used. Found by `std.json`'s `member`. IR for the
  351 existing test programs differs only by the new extern declarations in `std.process` / `std.input`.
  `tests/test_355_optional_assignment.psm`.

- **An unresolved operand is reported once.** `foo(1) + bar(2)` said `unknown function` twice and then `operator `+`
  requires numeric operands`, blaming the arithmetic for a name that did not resolve. An operand whose type is already
  invalid no longer adds the operator error (`semaBinaryExpr`).

- **A struct stored into a module-level `let` was placed on the storing function's frame.**
  The escape analysis read a global as a name it had never seen declared, and a store through it
  as a store into nothing, so `entries.push(Entry { .. })` from a helper, `last = entry` after a
  local read of `entry`, and `held.entry = entry` left the struct on the function's frame (`prismio
  aif`: `stack  small value does not escape`) or released it at the end of the scope. The global
  then read a frame or a block the next call reused: garbage, or a crash. A store into a global, into
  a field or element of one, or a push into a container reached through one now escapes globally
  (`aifRootedInGlobal` in `src/aif/walk.psm`, mirrored in the oracle). **A `String` or a `Ptr` is
  left alone**: their sites are shared across the program (every `concat` and `clone` result comes
  from one site in std, every AST node from `ASTNode`'s), so escaping one stored value would stop
  all of them being released -- the compiler's own `irCoalesceSpills = irCoalesceSpills.concat(..)`
  took 145 functions' releases with it in the first version of this fix -- and no wrong store of
  either was found. The IR of every program in `tests/` and `benchmarks/hosted/prismio/` is byte-identical,
  and of `src/` it differs in one function: the `Instant.now()` that `phaseTime` reads is no longer
  released after `since`, because the same site is stored into `phaseStart`
  (`tests/test_352_global_store_escapes.psm`, asserted by `--verify` and by `prismio aif`).

- **`--verify` had stopped counting allocations LLVM could delete.** The call-site attributes that tell
  LLVM what `malloc` means were also put on the ledger's `aif_verify_alloc`, which licenses LLVM to remove
  an allocation it can see does not escape -- one that is never freed included. `test_269` read 4
  allocated / 0 leaked where the program makes 13 and leaks 9, `test_273` 300 / 200 for 400 / 300, and
  `aif_verify` failed for it. The attributes are now on `rt_base_alloc` only.

- **`edit_distance` had lost its element bound** to its own `min`. The bound on what its rows hold
  (`src/ir/contents.psm`) asked whether `min` was std.math's, and a freestanding program cannot
  import std.math, so the benchmark's `fn min` never qualified: 5,900,624 instructions where the
  freestanding README recorded 5,540,624. The callee is now judged by its body.

- **`??` in a file that had not imported `std.option` failed with an internal-looking error.** A file
  that reached the module only through another import (`std.process` and `std.string` both import it)
  passed the check and then failed as "module `std.option` declares no `optionCoalesce$Int`"; it now
  says "`??` needs `import std.option`", as a file with no route to it already did (`neg_308`).
- **A fresh struct stored in two `Vec`s of one type no longer stops the first from releasing.** Overwriting an
  element of one `Vec<F>` leaked the displaced `F` and all it owned once a second `Vec<F>` was pushed a result
  of the same function: the A-CONTAIN rule read two containers holding one allocation *site* as one value
  held twice and sent it to the counted tier, which a struct that owns a `Vec` cannot use. The exemption
  `test_255` made for `String` now covers every move-only site, still excluding an element read that was
  pushed. `graph_churn_alloc` went from 10 released of 2,521,048 to all of them. `test_302`; suite 614/614.

- **Two bindings of one name no longer share one analysis key.** AIF keyed a local by function and name, so
  `let n = mk(step)` in a loop and a later `for n in other` were one variable; the `for` binder is a view, the
  `let` stored an owner, and the join read the owner's store as a view store and sent every site of the type to
  the counted tier (1,528 allocated, 512 released). The walk now resolves a read or a store to the innermost
  visible declaration of its name, as the source does (`aif_env_*` in `runtime/aif_support.c`, the walk in
  `src/aif/walk.psm`, the oracle in `tools/aif_oracle/aif.py`); a function that never repeats a name builds the
  keys it always did. The same shape with a channel (`let v = ...; c.send(v)`, then `for v in c`) is fixed with
  it. `src/ir/overwrites.psm` had the same flaw in its proof and now tells declarations apart too: without that,
  renaming the benchmark's binder back to `frag` parked a ring of fragments (38 MB peak against 0.19 MB).
  `test_322_binding_keys`.
- **The move checker no longer rejects exclusive branches.** `if (c) { v.push(n) } else { v[i] = n }` was
  `use of moved value` on the else arm, and a `continue` after a push hid the move from nothing: moved-from state
  was one set in source order. Each arm of an `if` / `else if` and of a `match` now starts from the state the
  branches opened with, an arm that cannot fall through hands none of its moves on, and the state after is the
  union of the rest. It accepts more programs and no fewer. `test_319_exclusive_branch_moves`, `neg_313`.
- **`-O0`..`-O3` did not set how the program was optimised.** The program's object step was
  fixed at O3 (O0 with `-g`); the flag only ran a second `default<O<n>>` over the frontend's
  module before it. So `-O0` was a fully optimised build and `-O3` optimised twice: the hosted
  benchmark program built in 0.86 s with no flag, 0.89 s at `-O0` and 1.15 s at `-O3`. The flag
  now sets the object step's level (and the machine-code level, as clang maps it): `-O0` 0.30 s,
  `-O1` 0.58 s, `-O2` 0.81 s, `-O3` 0.86 s, all 66 workloads agreeing. With no flag nothing
  changes. `-g -O2` is an optimised build with DWARF. `-o x.ll -O<n>` still writes optimised IR,
  and `run --jit -O<n>` now optimises the merged module rather than the program alone.
- **A trait-object call in a loop could reallocate the Vec the loop read through its
  flat guard.** The guard analyses judged calls by `CALL_EXPR`, and a `dyn` call is a
  `DYN_CALL`, so it fell through as an ordinary expression: an impl that pushed to the list
  left the guarded copy reading the freed element block (`walk` in
  `tests/test_277_guard_dyn_call.psm` summed 27 for 28). `DYN_CALL`, `SPAWN_EXPR` and
  `JOIN_EXPR` now decline the loop in all three analyses.
- **`let big: Array<Int, N>` compiled in time linear in N with a large constant** (1.6 s
  at a million elements, 21 s at ten million, over two minutes at forty million). LLVM
  scalarises a first-class `store [N x T] zeroinitializer` before recovering the memset;
  an aggregate of 1,024 bytes or more is now one `llvm.memset` (forty million Ints:
  0.06 s). Smaller arrays keep the store and their IR.
- **A function returning `Array<T, N>` took superlinear compile time** (0.65 s at 8,000
  Ints, 2.2 s at 16,000, 21 s at 32,000; a struct holding one ran for over 27 minutes).
  An array of 4 KiB or more now returns through a hidden `ptr sret` parameter that the
  caller points at a frame slot of its own (32,000 Ints: 0.09 s; 400,000: 0.07 s).
  Behaviour is unchanged.
- **A struct handed to a function that returns one of its parameters was never
  released** when the call's result was bound or stored in a struct field
  (`let r = pick(a, b)`; 0 of 4 blocks released, now 4 of 4). The callee's `return`
  lifted the argument's escape to the caller, and the scope-exit drop read that as the
  value leaving the scope. A lift that came only from a return in another function no
  longer declines the drop (`aif_frees_unless_returned_node`); returning or storing the
  binding itself still does. `test_51_optional_refs` no longer leaks its one block.
  Where the result outlives the scope that made the arguments (returned, pushed, carried
  round a loop, assigned outward) the argument that is not returned is still leaked, and
  `docs/KNOWN_ISSUES.md` says what releasing it needs.
- **A `match` arm that returned the payload it bound returned freed memory** when the
  scrutinee was bound first: `let r = parse(t); match (r) { Result.Ok(v) => { return v } }`
  printed eight NUL bytes where the text started (`--verify` does not show it, since its
  allocator does not reuse a freed block at once). The drop guards followed `let`s and
  assignments but not match binders, so `return v` was not seen to return `r`'s allocation
  and `r` was dropped at the scope exit. A binder now counts as an alias of its scrutinee,
  and a scalar identifier never does. The `Result` is kept alive on that path, which is a
  leak and not a free: `test_273_match_payload_returned` pins 300 of 400 blocks and asserts
  the values.
- **An owned temporary read by index in a condition, or matched on, leaked.**
  `if (v.sorted()[0] != 1)` (a `Vec` index is `list_get`, which the temporary-hoisting pass
  did not treat as a scalar read) and `match (parse(text)) { ... }` (the scrutinee was
  itself the temporary) now get a binding like the `let` the program could have written
  (`test_251` 4 of 45 blocks leaked, now 0). A temporary on the right of `and`/`or` is
  still not hoisted.
- **`p.arguments = [...]` on a fresh `Process()` leaked the list the constructor made**, one
  56-byte block per spawn. An assignment now releases the list it displaces when the
  receiver is a local declared in the same block, nothing has touched it since (a store to
  another field does not count), the right-hand side does not mention it, and the type is
  reclaimed and releases that field as a list. `test_153`, `test_183`, `test_188`,
  `test_258` and `test_259` read clean (33 blocks); a parameter, a loop, a second assignment
  or any earlier read keeps the old behaviour. Across `tests/` under `--verify`: 192 leaked
  blocks in 25 programs before, 163 in 19 after (plus the 300 pinned above), 0 violations.
- `test_259_display_print` no longer fails its own stderr check under `--verify`, where the
  child's ledger lands in the stderr it compares.
- `expect(<owned temporary>)` is hoisted so the temporary is released, and the hidden
  slots of `a ?? b` are zeroed before the enclosing branch, so a slot stored on one path
  is no longer released as garbage.
- The benchmark results are refreshed (release-profile compiler, five runs).
- **A line that starts with `(` or `[` was read as a call or an index of the line
  before.** Statements have no terminator, so `a.storeU32(7)` followed by
  `(a + 4).storeU32(7)` parsed as one expression and failed with an "unknown
  function" error naming a function with no name. Such a line now starts a new statement; a `.` still
  continues a method chain across lines, and a call's arguments still wrap. No program
  in `tests/`, `benchmarks/` or `src/` relied on the old reading: their IR is
  byte-identical (`tests/test_275_line_start_paren.psm`).

### Repository

- **`prismio verify` and `prismio gate` package the freestanding failure core.** Neither passed
  `--freestanding-target`, so the candidate they tested had no `lib/runtime/freestanding`, and any
  freestanding benchmark with a failure path (`prismio_panic`) failed to link in `freestanding_bench`,
  while the project's own toolchain, which has the core, built it. Both now package
  `aarch64-unknown-none-elf`. `prismio release` still does not.
- **`aif/` is gone.** The oracle (`aif/prototype`) is now `tools/aif_oracle/`, the specification and
  implementation notes are `docs/aif/`, and the 276-file evidence tree and the `g1`-`g9` corpus programs
  are removed (they stay in Git history). The release gate, the differential, the `workloads` check in the
  suite and `ir_snapshot` use the benchmark programs instead, and the gate now compares each workload's
  printed checksum with the one recorded in `benchmarks/results/results.json`.
- Build products are never tracked: six corpus executables were untracked, and `tools/lint.py` fails on
  any tracked executable, object or static library.
- `tests/test_runner.py`'s `ums` check follows the host profile `build.ums` names, and `install.sh` and
  `std/input.psm` end with a newline.

- `tests/freestanding/` holds the kernels and fixtures behind the `freestanding` test, which boots
  eleven of them under QEMU (AArch64 `virt` and 32-bit x86) and skips, saying so, without `ld.lld` or
  `qemu-system-*`; `runtime/freestanding/` holds the failure core, outside `runtime/*.c` so
  `tools/check_source_lists.py` does not count it as a compiler source. That check now also compares
  `freestandingSafeModule` in `src/driver/imports.psm` with `FREESTANDING_STD` in `tools/package.py`.

### Documentation

- *Freestanding programs* (guide) and *Low-level programming* (language) describe the above, with the
  flags in the CLI and manifest references; the developer docs record how the backend, the parser and the
  packager implement it.
- The developer docs gain *Performance decisions and rejected experiments*, drawn from the removed evidence
  (allocator choice, the `Int` width, layout representations, loop-guard and map-hash designs, channel
  results); the language docs say why `Int` is 32-bit and when to use `I64`; and the FFI contracts page
  records what an opaque module boundary costs the analysis.
- The developer docs gain *Wrapping integers and tight loops*: what the freestanding gap to C was made
  of, what was built, every alternative measured (among them undefined overflow, `freeze` semantics,
  `mustprogress` and `llvm.assume`), and the prior art. *Loop guards* describes both analyses, and
  the specification's *Bounds and storage* states the undefined behaviour above.
- `docs/KNOWN_ISSUES.md` is restructured: open items only, grouped by area, with the
  `--verify` leak table re-measured (272 programs, 0 violations, 171 leaked blocks in
  21 programs). What was fixed lives in `git log`.
- The language docs gain *Memory and buffers* (`std.mem`, with runnable examples for
  each tool); *Methods* describes `at` and `set`; *Lexical structure* states the
  line-start rule; *Low-level programming* points at `std.mem` for allocation. The
  developer docs' *supported surface* lists the `mem_*` runtime symbols and records
  that `borrow` becomes `readonly` on `String` arguments only, which `std.mem`'s writers
  depend on.

[0.2.0]: https://github.com/prismio-lang/prismio/compare/v0.1.0...HEAD
