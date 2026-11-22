# The standard library's layout: folders, sealed modules, tiers, and generated code

> **Implementation status, 2026-11-22: steps 0, 1, 2 and 3 of section 6 are built and committed** (the alias table and the
> lazy prelude lookup moved from step 1 to steps 6 and 7, because neither needs the seed; `lang(...)` also marks `impl`
> members; a trait takes no visibility marker, so the examples read `lang("eq") trait Eq`). Steps 4-8 are not started.
>
> **Original status: design only. Nothing below was built.** Written from a survey of
> `std/`, `src/driver/imports.psm`, `src/symbols/{declarations,library}.psm`,
> `runtime/build_driver.c`, `src/project/host.psm`, `ums/`, `tools/package.py` and the two
> generators, and from how Go, Rust, Swift, Zig, Odin and Java arrange theirs (sources at
> the end). **Final, 2026-11-22:** every open question is settled in section 7, and
> section 8 is an assessment of the whole decision, including where it is weakest.
>
> The layout decisions (D1–D8) say what `std` looks like. D9–D11 say how it is built
> and what the compiler knows about it. `std` is part of the language: a 0.3 compiler
> ships with the 0.3 `std` and resolves `std.*` from it, and no project ever builds it.
> But the compiler binary has no `std`-specific build logic. It offers general features
> (build, run, emit a precompiled module), and **this checkout's `build.ums` and `tools/`
> decide how `std` is packaged into the toolchain**, the way `gate` and `release` are
> declared there and not built into the compiler.

## 1 · What is wrong today

`std/` is 33 files in one directory, 20,479 lines, and every one of them is a public,
importable module. The problems, each checked against the tree:

1. **A folder in `std/` cannot be imported.** `resolveImportPath` turns `std.a.b` into
   the leaf `a.b.psm` (`moduleName.substring(4, …).concat(".psm")`), and
   `standardModulePath` looks for `std/a.b.psm`. `src/` has had nested modules
   (`ir.expr`, `import parse.*`) all along; `std/` has not. `tools/package.py` packages
   `std/*.psm` non-recursively, and installs them flat as `stdlib/<stem>.plib`.

2. **Implementation detail is public API.** `std.unicode_tables` (27 public
   declarations, 179 KB of generated data), `std.unicode_case` (8 public, 101 KB) and
   `std.float_text` are importable by any program, and show up in the library index that
   suggests imports. Nothing can be private to the library except by being `internal`,
   and `internal` only works because the whole of `std` is one package: `packageId` is
   the module path minus its last segment, so `std.map` and `std.string` are both in the
   package `std`. As soon as `std` has folders, `internal` stops spanning it.

3. **Two modules for one domain.** `std.io` is output (`print`, `println`, `eprint`,
   `eprintln`); `std.input` is standard input. `std.poll` waits on descriptors, which is
   also I/O. In every library this design was compared against, `io` covers both
   directions (Rust's `std::io` holds `stdin()` beside `stdout()`; Zig's `std.Io` holds
   `Reader` beside `Writer`).

4. **Seven one-trait modules a program imports by hand.** `std.eq`, `std.ord`,
   `std.copy`, `std.default`, `std.key`, `std.iter`, `std.display`: 19 to 81 lines each.
   The compiler already depends on several of them (`==` routes to `Eq`, `for` to
   `Iterator`, `T?` to `std.option`, a tuple to `std.tuple`), and `std.tuple` is already
   imported automatically by the parser (`parse/parser.psm:96`). That is a one-module
   prelude nobody designed.

5. **Facts about modules are hard-coded by name, in four places:**
   `freestandingSafeModule` and `freestandingNeedsRuntime` (`driver/imports.psm:557`),
   the freestanding list in `tools/package.py` (with a check that the two agree), and
   the "never suggest this" list in `symbols/library.psm:89` (`std.raw`, `std.asm`,
   `std.port`, `std.syscall`). Adding a module means editing three of them; moving one
   means finding all four.

6. **Generated code sits beside hand-written code with nothing to tell them apart** but a
   header comment. `std/unicode_case.psm`, `std/unicode_tables.psm` and `std/syscall.psm`
   are generated; so is `src/lexer/identifier_tables.psm` (403 KB). `gen_syscalls.py
   --check` runs in `check_source_lists.py`; `generate_unicode_tables.py --check` exists
   and runs nowhere.

## 1b · How `std` is built today, and what the compiler knows about it

**`std` is built three separate times, by three separate implementations, and two of
them are compiled into the compiler binary.** `build.ums` declares `gate`, `release` and
`bench` as this project's commands, so the compiler knows nothing of them. Packaging
`std` gets no such treatment: the compiler itself carries the knowledge of which
directory is `std`, which files to make into PLIBs, and when to do it:

| Builder | Where | What it does |
|---|---|---|
| From source, inside every program | `standardModulePath`, `driver/imports.psm:671` | Inside a checkout, every program compiles `std/*.psm` from source. A "checkout" is detected by probing for `runtime/lang_runtime.c` (`isPrismioCheckout`, :650), walking up to 64 parent directories. The bootstrap (seed → gen0 → gen1 → gen2) builds `std` this way. |
| The project-local toolchain | `compiler_emit_local_toolchain`, `runtime/build_driver.c:4380`, called by `src/project/host.psm:96` after building the target named by `toolchain.host` | Finds `std` by probing for `std/string.psm`, lists `std/*.psm` flat, and for each module runs **itself** as a subprocess (`prismio build std/x.psm -o x.ll` with the environment variable `PRISMIO_LIBRARY_MODULE=std.x`). Then it runs `clang -emit-llvm`, writes PLIB v3 by hand, and keeps its own stamp cache. It also builds the runtime bitcode from a hard-coded module list (`prismio_runtime_modules`, :560). |
| The release package | `tools/package.py` | The same pipeline again, in Python: its own PLIB writer ("the same bytes", held equal by a byte-for-byte test), its own freestanding list, and a flat glob. |

The compiler then knows `std` by name in about thirty places:

| What it knows | Where |
|---|---|
| Where `std` is | the `std.` prefix in `resolveImportPath`; `standardModulePath`; the `lang_runtime.c` probe |
| That a file *is* `std`, by its module name starting with `std.` | access to `__builtin_*`, raw pointer steps and option internals (`semaFileIsStandardLibrary`, `sema/symbols.psm:142`, 17 uses); the overflow-check exemption (`ir/expr.psm:4668`); pruning (`driver/prune.psm:68`); fixing AIF layouts (`aif/layout.psm:313`); the range trace (`ir/ranges.psm:287`); whether a file belongs to the user in the LSP (`index/command.psm:39`, `index/complete.psm:201`) |
| Lists of module names | freestanding (×2, `imports.psm:557`); "never suggest" (`symbols/library.psm:89`); `package.py` |
| The names of `std` declarations | `optionCoalesce` (`??`), `strConcat` (`+`), `intText`, `tuple2`, `mapNew`, `copyOf`; the traits `Eq`, `Ord`, `Iterator`, `Copy`, `Key` and their methods `eq`, `cmp`, `hasNext`, `next`; `Result`; `HashMap` (`sema/checker.psm`, `sema/maps.psm`, `driver/derived_impls.psm`, `parse/tuples.psm`, …) |
| The names of `std` modules | `"std.raw"` (`sema/pointer.psm`), `"std.option"` (`sema/checker.psm:1400`), `"std.tuple"` (`parse/parser.psm`) |
| How to build a library module | the `PRISMIO_LIBRARY_MODULE` environment variable |

Every row is a place that has to change when `std` changes, and the move in D5 would
touch most of them. D9–D11 remove them, and they come before the move (section 6),
so the move itself touches no compiler source.

## 2 · The principles

These decide the cases this document does not list.

- **A module's path is its location, everywhere.** `std/` resolves by the same rule as
  `src/`, so nothing in the resolver is specific to the library except where it looks
  first.
- **A top-level name is a domain, not a file.** `std.io` is I/O, both directions. A
  folder exists when a domain has more than one module, not before.
- **Two separate questions:** who can *reach* a module (decided by where it is), and who
  can *see* a name in it (decided by `public` / `internal` / `private`). Today the second
  does both jobs.
- **A fact about a module is written in the module.** A list kept elsewhere drifts from
  it.
- **Nothing a program does not name costs it anything.** This is why `std` has no
  prelude today ("a program that names no I/O carries none", `resolveImports`). Every
  change here has to keep it, and is measured against it (section 6, step 0).
- **Generated output is committed and checked, never produced during a build.**
- **The compiler binary offers general features; this project composes them.** `build` and
  `run` are universal and belong in the compiler. "Package `std/` into `stdlib/`" is this
  project's work, like `gate` is, and belongs in `build.ums` and `tools/`.
- **`std` ships with the compiler and is locked to its version.** The one `std` rule the
  compiler keeps is a language rule: `std.*` resolves from the library the running toolchain
  carries.
- **The compiler names no `std` module and no `std` declaration.** What the language
  needs from the library, it finds by a marker on the declaration.

## 3 · The decisions

### D1 · `std` is a tree, resolved like `src/`

- `import std.a.b` resolves to `std/a/b.psm`. In a checkout this is read from source; in
  an installed toolchain it is `stdlib/a/b.plib`, so `stdlib/` mirrors the source tree
  instead of flattening it (`package.py` globs `std/**/*.psm` and keeps the relative
  path). This also retires the trap in the *Install flattens std* note: a logical name is
  derived from a path again, because the two match.
- **A directory is a package.** `import std.io` resolves to `std/io.psm` if that file
  exists. If it does not and `std/io/` does, it means every module in the directory,
  exactly as `import parse.*` does now (`mergePackageImport`, which already records an
  import of each module so their `public` names are visible). `import std.io.poll` still
  names one module.
- A file and a directory with one name (`std/io.psm` and `std/io/`) can coexist: the
  file is the module `std.io` and the directory holds `std.io.*`, but `import std.io`
  then means the file alone. Rust 2018 has the same rule for `foo.rs` and `foo/`.

This gives `std.io` a folder without a new language feature. Re-exports (`public
import`, LANGUAGE_GAPS C7) would let a file act as a curated facade over its folder. That
is useful later, but nothing here needs it.

### D2 · Sealed modules: a `_` segment limits who can import the module

A module whose path has a segment beginning with `_` can be imported only by modules
under that segment's parent:

```text
std/_unicode/case.psm     std._unicode.case     importable from std.* only
std/_fmt/float.psm        std._fmt.float        importable from std.* only
app/net/_wire/frame.psm   app.net._wire.frame   importable from app.net.* only
```

- This is Go's `internal/` rule, which has worked since Go 1.4. The Go team chose to
  base it on where the source is, not on comparing import paths, for the same reason as
  here: the location is what the reader sees. The rule is checked once, at the import,
  with a diagnostic that names the boundary ("`std._unicode.case` is sealed inside
  `std`").
- **A `_` prefix and not a directory named `internal`**, because `internal` is a reserved
  word (`lexer/vocabulary.psm:17`) and could not be a path segment, and because the
  underscore is visible at every import site. `_` already reads as "not yours" in
  Prismio (`t._0`) and in Python.
- **Inside a sealed module, `public` means public to the library**: the name is visible
  to anyone who can reach the module, and only the library can. This replaces the use of
  `internal` that spans all of `std` today. `internal` keeps its meaning (the directory),
  and now means a narrower thing in a tree, which is what it says.
- The library index (`symbols/library.psm`), the LSP's completion, `prismio doc` and the
  docs site skip sealed modules. A user's own project gets the same rule for free.

Java's `module-info` export lists and Swift's `@_spi` were the other options. Both keep
the access list somewhere other than the module path, and section 2 rejects that.

### D3 · A lazy prelude of what the language itself depends on (decided)

The prelude is `std.core.*`: the modules that the language's syntax already reaches for.

| Module | Why it is the language's |
|---|---|
| `std.core.option` | `T?`, `??`, `Result` |
| `std.core.tuple` | `(a, b)`; already auto-imported today |
| `std.core.eq`, `std.core.ord` | `==`, `<` and the rest route to them |
| `std.core.iter` | `for x in it` desugars to it |
| `std.core.copy`, `std.core.default`, `std.core.key` | the bounds a `Vec` and a `HashMap` need |
| `std.core.vec`, `std.core.map` | `[1, 2]` and `{ k: v }` literals are syntax |

**Lazy:** a prelude module is merged only when a name it declares is looked up and found
nowhere else. That is, when the program's own declarations and its explicit imports
have no match. The index this needs already exists: `libraryModulesDeclaring` answers "which
library modules declare `name`" so that the unknown-name diagnostic can suggest an
import. The prelude does what that diagnostic suggests, for this set of modules
only. A program's own `sort` or `Eq` shadows the prelude's, as in Rust. `hello world`
names none of them and merges none of them, so its IR must stay byte-identical. That is
the gate (section 6).

**The compiler does not know this list.** Each prelude module says so in its header
(`module prelude freestanding`, the same header as D4). `--emit plib` copies that flag
and the module's public names into the PLIB header (D9). The prelude is then "the
toolchain library's modules that declare themselves prelude": a language rule, with
no names in it. The auto-import of `std.tuple` in `parse/parser.psm` and the
`std.option` check in `sema/checker.psm:1400` both go.

`std.io` is **not** in the prelude: a target with no stdout must link without it, and
the existing reason for "no prelude" is about I/O. Every `std.core` module is
freestanding-safe; `std.core.tuple` is missing from today's freestanding list and has to
be checked.

### D4 · Tiers are declared in the module and checked

Every module states what it needs, as its first item:

```prismio
module freestanding            // links nothing: option, iter, raw, asm, port, syscall, errno
module freestanding(runtime)   // needs lang_runtime.c's allocator: string, vec, map, mem, ...
                               // no line: hosted (libc and an OS), the safe default
```

- The compiler **checks the claim**: a `freestanding` module importing a hosted one is an
  error when `std` is compiled, so the claim cannot drift from the imports the way the
  lists can.
- This replaces `freestandingSafeModule`, `freestandingNeedsRuntime` and the list in
  `package.py`. `--emit plib` records each module's tier in its PLIB header (D9), and
  the compiler reads it from there when it checks a `--freestanding` import.
- The "never suggest" list becomes a location: everything under `std.sys` (D5) is a
  decision to reach into the machine, and the index skips it.

The header is one line: `module` followed by its flags (`prelude`, `freestanding`, `freestanding(runtime)`). The parser change is new
syntax, so it lands in two steps with a seed in between (section 6).

Rust instead splits along tiers into three crates, `core`, `alloc` and `std`, and Odin
into three collections, `base:`, `core:` and `vendor:`. That makes the user learn which
root `Option` lives in. Prismio's tier is a per-module fact that the compiler enforces,
and its names are by domain.

### D5 · The module map

```text
std/
  io/                      std.io      print, println, eprint, eprintln, readLine, readInt,
    output.psm                         inputLines, tokens, readBytes, ...
    input.psm              (was std.input)
    poll.psm               std.io.poll (was std.poll)
  string.psm               std.string  plus the Unicode-aware String/Char methods (D6)
  fmt/                     std.fmt
    display.psm            Display     (was std.display)
    number.psm             text for Int<N>, F16/BF16/F128 (was std.number_text)
  core/                    the prelude, D3
    option tuple eq ord iter copy default key vec map
  collections/             VecDeque, sets, heaps as they arrive (docs/COLLECTIONS.md)
  encoding/
    json.psm               std.encoding.json (was std.json)
  sys/                     reaching into the machine: never suggested, never in the prelude
    raw.psm asm.psm port.psm syscall.psm errno.psm
  fs.psm  process.psm  time.psm  term.psm  math.psm  mem.psm  platform.psm
  _unicode/                sealed
    case.psm               GENERATED (was std.unicode_case)
    properties.psm         GENERATED (was std.unicode_tables)
    text.psm               width, graphemes, normalization (was std.unicode's algorithms)
  _fmt/                    sealed
    float.psm              (was std.float_text)
```

Old name to new name:

| Today | Becomes | Note |
|---|---|---|
| `std.io`, `std.input` | `std.io` | one domain; `std.input` an alias for one release |
| `std.poll` | `std.io.poll` | |
| `std.unicode` | methods in `std.string` | D6 |
| `std.unicode_case`, `std.unicode_tables` | `std._unicode.*` | sealed |
| `std.float_text` | `std._fmt.float` | sealed; 0 public declarations today |
| `std.number_text`, `std.display` | `std.fmt` | the compiler's print rewrite targets `std.fmt` |
| `std.option` … `std.vec`, `std.map` | `std.core.*` | prelude; importing explicitly still works |
| `std.json` | `std.encoding.json` | renamed now, before 1.0 |
| `std.raw`, `asm`, `port`, `syscall`, `errno` | `std.sys.*` | |
| `fs`, `process`, `time`, `term`, `math`, `mem`, `platform` | unchanged | |

- **Old names are aliases for one release.** `import std.input` resolves to `std.io` and
  warns that it is now `std.io`. The table is in the resolver, is temporary, and is
  deleted in the release after. The churn is mostly in `src/`, `tests/` and the docs:
  `std.option` is named in 113 files of the tree and 27 doc pages, `std.raw` in 62 and
  13, `std.input` in 10 and 16, `std.unicode` in 7 and 8.
- `std.io` already has 501 files and keeps its name. Its folder is new.
- Sema's hard-coded `"std.raw"` (`sema/pointer.psm:206`) and the `std.asm` / `std.port`
  lowering checks have already become lang items or library checks (D10, D11) by the time
  the files move, so the move changes no compiler source.

### D6 · Unicode is the library's machinery, and String's methods

The user-facing question ("how wide is this in a terminal, what are its graphemes,
normalize it") is a question about a `String` or a `Char`, and is answered by a method
on it: `s.displayWidth`, `s.graphemes()`, `s.normalize(Normalization.NFC)`,
`c.displayWidth` (was `scalarWidth`). The algorithms (`std/_unicode/text.psm`) and the
tables are sealed. `std.unicode` as a module a program imports goes away.

- **Why not move it out of `std`, as Rust did with grapheme segmentation.** Rust's stated
  reasons were the size of the tables and that a toolchain pinned an old Unicode. Size
  is not a cost here: dead-code pruning drops tables nothing calls, and an installed
  toolchain links precompiled `.plib`s. `String.toUpper` needs the case tables in any
  case, and Rust keeps those in `core` too (`core/src/unicode/unicode_data.rs`). The
  version argument becomes real once Prismio has a package registry. Normalization is
  the candidate to move out then.
- **Measured, not assumed:** a program that uses `String` but no width or grapheme method
  must not grow, in binary size or in build time. That is gated in section 6. `std.string` already
  imports `std.unicode_case` today, so this is the baseline, not a regression to explain.

### D7 · Generated code: committed, sealed, checked, compiled with everything else

What happens to a generated table, from start to finish:

| When | What | Who |
|---|---|---|
| A Unicode release (yearly), or new SDK headers | `python3 tools/generate_unicode_tables.py`, `tools/gen_syscalls.py`; the UCD is cached in `build/unicode/<version>`, pinned by SHA-256 | a developer |
| The same change | the output is **committed** with the generator change | the maintainer |
| Every `prismio verify` | `--check` regenerates and fails on any difference: syscalls already, Unicode **newly wired in**, from the pinned cache | the gate |
| A build in a checkout | compiled from source like any other `std` module | the compiler |
| `prismio release` | compiled once into its `.plib`; a user's build links it and prunes what it does not call | the packager |

- **Why committed, and not generated into a temporary directory when a build runs.** The
  bootstrap compiles `src/`, which imports `std.string`, which needs the case tables. A
  build-time generator puts Python, a download from unicode.org (or ~7 MB of vendored
  UCD text, more than the 280 KB of output) and the Windows Python story on the path of
  every bootstrap, and the seed rule "the committed seed must be able to parse `src/`"
  then depends on a network. Committed output is hermetic, pinned and reviewable: a
  Unicode upgrade is a diff a reviewer can read. Rust (`unicode_data.rs`, "do not edit
  manually"), Go (`unicode/tables.go`, "Code generated … DO NOT EDIT") and Swift (tables
  from `utils/gen-unicode-data`) all commit theirs.
- **Marked as generated, in three ways:** the existing header ("GENERATED by
  tools/… -- edit the generator"); `.gitattributes` `linguist-generated=true` on each
  file, which collapses it in review but keeps the diff; and `prismio fmt`, lint and
  graphify skipping a file with that header.
- Sealed (D2), so the tables are never API: renaming a table function is not a breaking
  change.
- `src/lexer/identifier_tables.psm` stays in `src/`. It is the compiler's, not the
  library's, and follows the same rules.
- **Later, measured first:** the tables are data written as Prismio source, so every
  in-checkout build parses 280 KB of them. If that cost shows up in the build-time
  breakdown, the answer is a binary blob the compiler embeds, not build-time generation.

### D8 · Visibility after this, in one table

| Written | Who sees the name |
|---|---|
| `private` | the file |
| `internal` | the directory (package) |
| `public` | anyone who can reach the module |
| … in a module under a `_` segment | that segment's parent tree, and no one else |

### D9 · General features in the compiler; `std`'s packaging in `build.ums`

**What the compiler binary does.** These are general features, each one usable by any
project:

| Feature | What it is | Replaces |
|---|---|---|
| **The toolchain's library root, and nothing else** | `import std.x` resolves from the `stdlib/` beside the running compiler (`<toolchain root>/stdlib/x.plib`), so a 0.3 compiler always gets the 0.3 `std`. A `stdlib/` may hold `.psm` source instead of `.plib`, and then the module is compiled with the program: the bootstrap's bare generations have no PLIBs yet. There is **no setting that points elsewhere**: `toolchain` keeps exactly one key, `host`, and a project that wants a different `std` uses a different host. | the walk up 64 parent directories, `isPrismioCheckout` (the `lang_runtime.c` probe), and the two-branch lookup in `standardModulePath` |
| **Precompile one module** | `prismio build std/io/input.psm --emit plib --module std.io.input [--target T]… -o input.plib`, beside the `-o x.ll` it already has. One process writes the whole PLIB: the interface, and the normal and `--verify` code section for each triple. (If several target machines in one process prove awkward in the LLVM bridge, the same flag takes one `--target` and `--into x.plib` appends its section; the format already has a section table.) The module header's tier and prelude flag (D3, D4) and its lang items (D10) go into the header. | `emit_stdlib_plib` and `emit_plib_section` (a compiler spawning itself and then `clang -x ir`), the `PRISMIO_LIBRARY_MODULE` environment variable, and the Python PLIB writer in `package.py` |
| **Read a library root** | the prelude index, the lang-item index and the suggestion index read the PLIB headers under `stdlib/`, or scan the source when `stdlib/` holds source. No separate manifest file. | `libraryScan`'s source-only scan |
| **Run steps after a target builds** | a general UMS `after { run(…) }` block on a target: code signing, copying assets, or, here, building the rest of a toolchain | `host.psm` calling `compiler_emit_local_toolchain` whenever the built target is `toolchain.host` |

**What this project does, in `build.ums` and `tools/`, not in the compiler binary:**

```text
executable("prismio") {
    entry = "src/main.psm"
    ...
    // The rest of the toolchain beside the host: runtime bitcode and std's PLIBs, built with
    // the compiler that was just produced. Ours, not the compiler's: no other project has a
    // std/ to package.
    after {
        run("tools/toolchain_layout.psm", "--compiler", ".prismio/build/debug/prismio",
            "--out", ".prismio/build")
    }
}
```

- **One tool, `tools/toolchain_layout.psm`, owns "what the toolchain carries".** It is a
  Prismio program, and UMS already builds and runs a `.psm` named by `run(...)`
  (`runUmsScriptStep`), so `prismio build` keeps needing no Python, as it does today when the
  C does this work. It walks
  `std/` (the tree, D1), skips nothing but non-modules, and runs `--emit plib` for each
  module. It compiles the runtime C to bitcode with the pinned clang and copies the
  freestanding failure core. Its incremental cache is keyed on (source, compiler hash):
  the stamp logic moves out of `build_driver.c` into the tool, with the same rule, that a
  new compiler rebuilds every PLIB.
- **`package.py` and `release.py` call the same tool**, adding `--target` and
  `--freestanding-target`, then archive the result. A module gets freestanding sections
  because its PLIB header says it is freestanding (D4), not because a list names it.
- **Deleted from the compiler binary:** `compiler_emit_local_toolchain`,
  `emit_stdlib_plib`, `emit_plib_section`, `prismio_runtime_modules`, the `std/string.psm`
  probe, the `lang_runtime.c` probe, `PRISMIO_LIBRARY_MODULE`, and `host.psm`'s call into
  them. **Deleted from `tools/`:** the second PLIB writer and `FREESTANDING_STD`.
- **How this checkout gets its working-tree `std` without an option:** the host is the
  compiler this checkout builds, and its `after {}` step leaves `.prismio/build/stdlib/`
  rebuilt from `std/`. Every program the host compiles therefore gets the working tree's `std`,
  through the same rule an installed toolchain follows. `tools/bootstrap.py` copies `std/` as
  source into `build/stdlib/` beside the bare generations it makes. That is the tool's
  business, not the compiler's.
- **The cost, stated:** a `std/` edit reaches programs in this checkout at the next
  `prismio build`, not at once, as it does today through the parent-directory walk. The cache
  rebuilds only the edited module's PLIB, so the step takes seconds. `check --module std.x`
  (the LSP's check of a `std` file) resolves the entry's sibling modules from the entry's own
  tree, a general rule for checking any library module on its own, so editing `std` in an
  editor does not wait for a build.
- **Precompiled PLIBs stay.** Zig compiles its standard library from source with every
  program and relies on lazy declaration analysis. Prismio's AIF analysis is
  whole-program, and the *std.io's std.string import* note measured how much merging one
  more module costs it. Linking precompiled code sections keeps that cost out of every
  user build.

Swift is the closest precedent. Its standard library is compiled by the Swift project's own
CMake (`-parse-stdlib -module-name Swift`) and shipped in the toolchain, and `swiftc` has no
step that knows how to build it.

### D10 · Lang items: the compiler finds what it needs from the library by marker

The language needs about a dozen things from the library: `==` needs `Eq`, `for` needs
`Iterator`, `??` needs `optionCoalesce`, `+` on Strings needs `strConcat`, a map literal
needs `mapNew`, and so on. Today the compiler names each one, along with its module.
Instead, the declaration says what it is:

```prismio
lang("eq") public trait Eq { fn eq(self, other: Self) -> Bool }
lang("iterator") public trait Iterator { ... }
lang("option_coalesce") public fn optionCoalesce<T>(value: T?, fallback: T) -> T { ... }
lang("string_concat") internal fn strConcat(a: String, b: String) -> String { ... }
```

- The ids are one enum in one compiler file (`src/common/lang_items.psm`). Each compiler
  use asks for the declaration that carries its id, never for a name or module.
- **Lazy**, as Rust's lang items are: the compiler resolves an id only when the program
  needs it, through the id → module index read from the library root's PLIB headers
  (D9), so it merges only that module. A missing item is a diagnostic about the library ("the standard library
  declares no `lang(eq)`; `==` on a struct needs it"), not a confused name lookup.
- The marker takes the place where `fn` attributes already go (`export`, `inline`,
  `cold`, …), so it is new syntax and lands in two steps with a seed in between.
- With D3 and D10 together, the compiler never spells a `std` module path or declaration
  name. Moving `Eq` from `std/eq.psm` to `std/core/eq.psm` (D5) changes nothing in `src/`.
- Rust's `#[lang = "..."]` works this way, and so does Swift's stdlib, built with
  `-parse-stdlib -module-name Swift`, whose `Builtin` module only the stdlib can see.

### D11 · Privileges belong to the library, not to the prefix `std.`

Every `startsWith("std.")` in section 1b asks one of three questions. Each gets a real
answer:

| Question | Today | After |
|---|---|---|
| May this file use `__builtin_*`, raw pointer steps, option internals? | the module name starts with `std.` | the file was resolved from the toolchain's library root, the `stdlib/` beside the running compiler. No other file can have it, and no manifest key grants it. This is Swift's `-parse-stdlib`, which only the stdlib's own build passes. |
| Did this declaration come from the toolchain library, not the user's program? (pruning, AIF layout, range trace, the LSP's user files) | the module name starts with `std.` | the merge records the root each file was resolved from. `fileFromLibraryRoot(file)` answers that. |
| Should overflow checks apply? | exempt by name, because `std` is written against wrapping arithmetic | `std`'s own profile (`overflowChecks = false`). The real fix is a `wrapping` spelling, so that `keyMixWide` says it wraps on purpose. |

The eleven name tests and `semaFileIsStandardLibrary`'s 17 callers go through these
two functions and a profile setting. The `"std.raw"` import checks in `sema/pointer.psm` become a lang item
or a check of the library's manifest.

## 4 · What the compiler and tools change

| Where | Change |
|---|---|
| `driver/imports.psm` `resolveImportPath`, `standardModulePath` | nested leaves (`std/a/b.psm`, `stdlib/a/b.plib`); a directory as a package; the alias table; the sealed check |
| `driver/imports.psm` `freestandingSafeModule`, `freestandingNeedsRuntime` | deleted; tiers come from the module header |
| `parse/` | the `module …` tier header; the tuple auto-import goes, because the prelude covers it |
| `sema/symbols.psm` unknown-name path | consult the prelude index before reporting; merge the module it names |
| `symbols/library.psm` | skip `_` segments and `std.sys`; the name list at :89 goes |
| `tools/toolchain_layout.psm` (new) | the one place that knows what a toolchain carries: walks `std/`, runs `--emit plib`, builds runtime bitcode, keeps the cache (D9) |
| `tools/package.py`, `tools/release.py`, `tools/bootstrap.py` | call `toolchain_layout.psm` (bootstrap: copy `std/` as source beside the bare generations); no PLIB writer and no module list of their own |
| `build.ums` | an `after { run("tools/toolchain_layout.psm", …) }` block on `executable("prismio")`; `toolchain` unchanged, `host` only |
| `ums/` and `src/project/` | the general `after {}` target block; `host.psm` stops building a toolchain |
| `runtime/build_driver.c`, driver | `--emit plib --module` writes a whole PLIB in one process; `compiler_emit_local_toolchain`, `emit_stdlib_plib`, `emit_plib_section`, `prismio_runtime_modules` and `PRISMIO_LIBRARY_MODULE` are deleted |
| `src/common/lang_items.psm` (new), `parse/` modifiers | the `lang("…")` marker; every name the compiler spells today goes through it (D10) |
| `sema/symbols.psm`, `ir/expr.psm`, `driver/prune.psm`, `aif/layout.psm`, `ir/ranges.psm`, `index/` | `startsWith("std.")` becomes `fileHasIntrinsics` / `fileFromLibraryRoot` (D11) |
| `tools/check_source_lists.py` | runs `generate_unicode_tables.py --check` |
| `.gitattributes` | `linguist-generated` for the four generated files |
| LSP, JetBrains and VS Code plugins | completion and go-to-definition read a tree; sealed modules hidden |
| `../website/apps/docs/content/stdlib/` | `input.md` folds into `io.md`, `unicode.md` into `strings.md`, `display.md` and `number-text.md` into `fmt.md`; redirects from the old pages |

## 5 · Rejected

- **Generating Unicode tables at build time into a temporary file.** See D7: it puts
  Python and a network on the bootstrap path, for no gain over a `--check`.
- **Three import roots by tier (Rust's `core`/`alloc`/`std`, Odin's `base:`/`core:`).**
  Users would learn tiers in order to find `Option`. A declared, checked tier gives the
  freestanding guarantee without it.
- **A `std` key in `toolchain`, or a `--std` flag.** `std` belongs to the compiler that
  runs it, and `host` already says which compiler that is. A second key could disagree with
  the first.
- **An export list per library (Java's `module-info`).** A second file to keep in step
  with the first, and the import site does not show it.
- **An eager prelude.** It would break "nothing named, nothing merged" for every program.
  Only a lazy one is proposed.
- **Merging `std.input` into `std/io.psm` as one file.** It would merge `vec`, `option`
  and `iter` into every printing program. The *std.io's std.string import* note measured
  what one import costs AIF (5 allocation sites became 85). A directory package (D1) has
  the same problem, so the step-0 measurement decides between the two. If a
  package import costs a printing program, `std.io` becomes a file whose input half is
  behind a lazy re-export (C7) instead.

- **Tidying the special cases instead of removing them**: one Python list instead of
  three, one `isStandardLibrary()` instead of eleven prefix tests. It would still leave a
  compiler binary that knows how to package its own library, and that breaks whenever `std` moves.
- **The compiler spawning itself per module, with an environment variable choosing what
  it emits.** That is today's library build, in both C and Python. A general `--emit plib`
  flag, called from this project's script, replaces both.
- **Making `std` a library project that a program's build compiles** (`std/build.ums` with a
  `library("std")` target). `std` is part of the language and ships built, locked to the
  compiler's version. No user build ever compiles it, so it needs no project of its own; it
  needs a packaging step, and that step belongs to this repository.
- **Compiling `std` from source with every program, as Zig does.** See D9: AIF is
  whole-program, so precompiled code sections are what keep the cost of each import out of
  every build.

## 6 · Order of work

Each step leaves `prismio verify` and `prismio gate` green, and each one that should not change
behaviour is held to byte-identical IR for `tests/` and `benchmarks/hosted/prismio/` over two
generations. **Every compiler change is installed as the host before anything uses it**, because
`src/` imports `std.*` (the *host chicken-and-egg* hazard in CLAUDE.md). The steps run in this order
so that the compiler stops naming `std` (steps 2–4) **before** `std` moves (step 6), and the move
then touches no compiler source.

0. **Measure the baseline** on five programs (hello world; a String program with no
   Unicode method; one with `toUpper`; a `Vec`/`HashMap` program; a freestanding one): IR,
   AIF site count, binary size, build time. Also keep today's `stdlib/*.plib` from
   `package.py` for the host. These are the gates for steps 4, 6 and 7.
1. **New syntax and resolution, nothing moved and nothing using them yet:** the
   `lang("…")` marker, the `module` tier header, nested `std` paths, directory-as-package,
   `_` sealing, the alias table, and the prelude lookup behind a flag. Tests for each,
   including a sealed import refused from outside and allowed from inside. Build, promote
   the host, cut a seed (`prismio seed`), and **the maintainer commits it**. One seed covers
   all of step 1.
2. **Lang items (D10):** mark the `std` declarations, then switch the compiler's uses over
   one at a time (`optionCoalesce`, `strConcat`, the traits, `mapNew`, `tuple2`, …). Each
   switch should produce byte-identical IR.
3. **Library privileges (D11):** record the root each merged file was resolved from.
   Replace every `startsWith("std.")` with `fileHasIntrinsics` / `fileFromLibraryRoot`. Move
   the overflow exemption into a profile setting. Byte-identical IR.
4. **Packaging leaves the compiler (D9):** add `--emit plib --module` and the UMS
   `after {}` block. Write `tools/toolchain_layout.psm`, point `build.ums`, `package.py`,
   `release.py` and `bootstrap.py` at it, and reduce `std` resolution to the one rule.
   Then delete `compiler_emit_local_toolchain` and the rest of the list in D9. **Gate:**
   the host `.plib`s are byte-identical to step 0's, and `prismio build` in this checkout
   still leaves a complete toolchain under `.prismio/build`.
5. **Tiers (D4):** add the header to every `std` module, check it, and delete the lists
   that are left.
6. **Move the files** (D5) with `git mv` (history follows), and rewrite imports across `src/`,
   `lsp/`, `ums/`, `tests/` and `benchmarks/`. No compiler logic changes. **Gate:** the
   two-generation fixpoint and the full suite. IR is identical to step 0's, except where a
   module path is part of a symbol name. Check those differences with a mnemonic diff and
   confirm they are renames only.
7. **Turn the prelude on** (D3). **Gate:** hello world's IR byte-identical to step 0, and the
   other four within noise on size and build time. The explicit `import std.option` lines
   and the others in `src/` can then go.
8. **Docs**, in both apps, with `verify-doc-examples.mjs` run in each against a packaged
   toolchain; the release page; the aliases scheduled for deletion. The developer docs get a
   page on how `std` is built (D9) and the lang-item table (D10).

## 7 · Decisions, final

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | A prelude? | **Yes, lazy** (D3) | the maintainer's call; the language already depends on these modules, and `std.tuple` was already implicit |
| 2 | How a module is sealed | **a `_` path segment** (D2) | `internal` is a reserved word; the underscore is visible at every import site; Go's location rule is proven |
| 3 | `std.json` | **`std.encoding.json` now** | renames are cheapest before 1.0, and this is the release that renames |
| 4 | The module header's spelling | **`module` followed by flags, as the first item:** `module prelude freestanding`, `module freestanding(runtime)`; no header means hosted | one line carries every fact about a module (D3, D4); it reads like the `fn` modifiers already in the language |
| 5 | Rename `Key` to `Hash` | **No** | `Key` is hashing and equality together, a contract `Hash` would misname; unrelated to layout |
| 6 | The toolchain layout step | **a general `after {}` block on a target** (D9) | a plain `prismio build` must leave a host that can build more than itself, which is what `host.psm` guarantees today; a separate command would lose that |
| 7 | The layout tool's language | **Prismio, `tools/toolchain_layout.psm`** | `prismio build` needs no Python today, because C does this work; a Python tool would add Python to every build of the compiler |
| 8 | A `std` setting in `toolchain` | **None. `toolchain` has `host` and nothing else** (D9) | `std` belongs to the compiler that runs; a different `std` means a different host |
| 9 | User code with intrinsics | **Never** (D11) | `__builtin_*` are compiler internals with no stability promise |
| 10 | Language additions this needs | **`lang("…")` markers, the `module` header line, `--emit plib`, and the UMS `after {}` block** | each lands in two steps, with a seed in between where it is syntax (section 6, step 1) |

## 8 · An honest assessment

**What is clearly right and should happen even if nothing else does:** D9, D10 and D11, the
three that take `std` out of the compiler binary. Today the compiler packages its own library
in C, spawns itself with an environment variable, tests `startsWith("std.")` in eleven places
and spells the names of `std` declarations in sema. Each of these makes a `std` change into a
compiler change, and the duplicate builders have already needed a byte-for-byte test to keep
two PLIB writers honest. Lang items and root-based privileges are the established answer
(Rust, Swift). They are behaviour-preserving, provable by byte-identical IR, and they pay
off on their own.

**Right, at a moderate price:** the tree (D1), sealing (D2), declared tiers (D4) and
committed generated code (D7). Each is small, each removes a list or a leak of internals, and
none changes what a program does.

**Where I am least sure, in order:**

1. **The lazy prelude (D3) is the riskiest piece of compiler work here.** It sits in name
   resolution, which every diagnostic, the LSP's completion and go-to-definition all depend
   on. A name that resolves "only if nothing else matched" is easy to get subtly wrong:
   overloads split across a user module and a prelude module, a method found through UFCS on
   a prelude type, an unknown-name error that now merges a module before failing. The gain is
   real but modest: fewer import lines, and an end to the half-prelude the parser already has
   for tuples. It is worth doing only behind the hello-world byte-identical gate, and it is
   the step to postpone if step 7 fights back.
2. **Merging `std.input` into `std.io` has a measured hazard.** One import into `std.io` once
   took AIF from 5 allocation sites to 85 for every printing program. If the directory
   package costs printing programs anything, `std.io` has to become a file with a lazy
   re-export (C7), and that is a language feature this plan avoids needing.
3. **The rename (D5) is the most expendable part.** It touches roughly 300 files in this
   tree and about 150 doc pages, and gives users nothing at run time. I would still do it,
   once, before 1.0, because every later release makes it dearer. But if time is short,
   ship D9–D11 and the sealing of the Unicode and float modules, and leave the
   public names where they are.
4. **Removing every `std` setting has a real cost for whoever works on `std`.** An edit to
   `std/` reaches programs at the next `prismio build`, not at once. The per-module cache
   keeps that to seconds, and `check --module` keeps the editor current. I think a single,
   undeclared, impossible-to-misconfigure rule is worth that step, but it is a step the
   current setup does not have.
5. **`--emit plib` writing every triple in one process is unproven.** The fallback (one
   triple per call, appending a section) is in D9, but it should be tried first, not
   assumed.
6. **Keeping Unicode width, graphemes and normalization in `std` (D6) commits the project to
   a yearly table regeneration and to API it must keep.** That is acceptable because the
   terminal styling and the LSP use them, but normalization is the first thing to move into
   a package once Prismio has a registry.

**What I would not do:** add any of the three escape hatches this design was tempted by. A
`std` path setting, a manifest key that grants intrinsics, and a per-library export list
would each reopen the drift between declared and actual behaviour that this plan exists to
close.

**Order if only part of it lands:** D10 and D11 first (pure cleanup, byte-identical), then D9
(packaging leaves the compiler), then D2 with D7 (seal the internals), then D1 with D5 (the
move), and the prelude last.

## Sources

- Go, `internal/` packages: [golang/go#16622](https://golang.org/issue/16622) (location,
  not import paths), [overview](https://dev.to/stefanalfbo/internal-packages-in-go-2h9),
  [go.mod-configurable proposal #59205](https://golang.org/issue/59205)
- Go, committed Unicode tables: [src/unicode/tables.go](https://go.dev/src/unicode/tables.go),
  [x/text generator](https://go.googlesource.com/text/+/master/internal/export/unicode/gen.go)
- Rust, committed generated tables and the `core` layering:
  [core/unicode/unicode_data.rs](https://doc.rust-lang.org/src/core/unicode/unicode_data.rs.html),
  [core/unicode/mod.rs](https://doc.rust-lang.org/nightly/src/core/unicode/mod.rs.html),
  [unicode-table-generator](https://rust.googlesource.com/rust/+/cd28decba9593f01e87dff024e28c096df550d73/src/tools/unicode-table-generator/src/main.rs)
- Rust, graphemes outside std: [internals thread](https://internals.rust-lang.org/t/support-for-grapheme-clusters-in-std/7339),
  [where did str.graphemes() go](https://users.rust-lang.org/t/where-did-str-graphemes-go/7817)
- Rust `std::io` holds stdin beside stdout: [std::io::Stdin](https://doc.rust-lang.org/std/io/struct.Stdin.html)
- Swift, native Unicode data and SPI: [UnicodeScalarProperties.swift](https://sources.debian.org/src/swiftlang/6.0.3-2/swift/stdlib/public/core/UnicodeScalarProperties.swift),
  [UnicodeSPI.swift](https://sources.debian.org/src/swiftlang/6.0.3-2/swift/stdlib/public/core/UnicodeSPI.swift),
  [Swift's approach to SPI](https://www.nutrient.io/blog/swifts-approach-to-spi/)
- Zig's `std.Io` Reader/Writer: [Zig 0.15.1 I/O overhaul](https://dev.to/bkataru/zig-0151-io-overhaul-understanding-the-new-readerwriter-interfaces-30oe)
- Odin's collections: [pkg.odin-lang.org](https://pkg.odin-lang.org/),
  [what are packages and collections](https://forum.odin-lang.org/t/what-are-packages-and-collections/434)
- Rust lang items: [rustc-dev-guide](https://rustc-dev-guide.rust-lang.org/lang-items.html),
  [unstable book](https://doc.rust-lang.org/unstable-book/language-features/lang-items.html)
- Swift builds its stdlib with `-parse-stdlib`: [SwiftSource.cmake](https://fuchsia.googlesource.com/third_party/swift/+/f2cf0510d6e25911e9babada46e0025862bd00cd/stdlib/cmake/modules/SwiftSource.cmake),
  [implicit Builtin import test](https://sources.debian.org/src/swiftlang/6.0.3-2/swift/test/Frontend/implicit-builtins-import.swift),
  [forum: import compiler builtins](https://forums.swift.org/t/import-compiler-builtins/27869)
- Zig's lazy declaration analysis: [Module.zig](https://git.adamlamers.com/PublicArchive/zig/src/commit/3114115348e789ae4bab8844c7ebd0067185f1c4/src/Module.zig)
- Java qualified exports: [dev.java](https://dev.java/learn/modules/qualified-exports-opens/),
  [strong encapsulation](https://dev.java/learn/modules/strong-encapsulation/)
