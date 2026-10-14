# Visibility, numeric fluency and what is left

The state after the 2026-10-14 session, and the order for the next one. Everything below
is in the working tree and **uncommitted**; `prismio verify` passes on it (566 tests, source
lists, externs, AIF differential), two compiler generations emit identical IR for `src/`, and
both doc apps' snippets compile (296 + 50). What shipped is in the CHANGELOG's 0.2.0 section.

## Where things stand

| Piece | State |
|---|---|
| Conditions without parentheses, `is`/`is not`/`not`, nested `fn`, closure block bodies | done, tested, documented |
| `__builtin_*` refused outside `std/`; `std.raw`, `std.port`, `std.asm` | done |
| Visibility on global `let`s, structs (default `internal`) and fields (default `private`) | done; the tree was migrated |
| Definite assignment: `let x: T` without a value, reads proven by `sema/assign.psm` | done, tested, documented |
| Constant array lengths and integer globals, ranges and indexing over any integer type | done; `bench_matrix_multiply` at C parity |
| Lazy library merge (LLVM bridge) | done, 1.6 ms, benchmark-neutral |
| Seed | **cut and verified, not published** (below) |
| Enum visibility, IntelliJ plugin, `Vec.length`, Windows static LLVM | open |

## Next session, in order

### 1. Publish a seed that parses `src/` (needs the user's go-ahead)

`src/` uses visibility markers, so the pinned 0.1.0 seed cannot parse it and `prismio gate` /
CI (which bootstrap from the pinned seed) fail. A seed was cut with `tools/refresh_seed.sh`
(18.6 MB) and a compiler built from only that file reproduces the IR of `src/main.psm`. It predates
the definite-assignment pass (`sema/assign.psm`), so **cut it again** before publishing. `bootstrap/seed.json` holds the new
pin **in the working tree, uncommitted**, and `bootstrap/prismio-seed-0.1.0.ll` is the new file
(the old cached seed was overwritten; `fetch_seed.py` re-downloads it when the pin is restored).

The catch: the pin scheme derives the URL from the version
(`v{version}/prismio-seed-{version}.ll`), and `PRISMIO_VERSION` is still `0.1.0`, so uploading
replaces the asset that every older commit pins by SHA. Do not use `--clobber`.

Proposed: let `seed.json` carry an optional `asset` name.

- `tools/fetch_seed.py`: use `pin.get("asset", seed_name(version))` for the URL and the cache name.
- `tools/refresh_seed.sh` and `.ps1`: take `--asset <name>` and write it into the pin.
- Cut it as `prismio-seed-0.1.0-r2.ll`, `gh release upload v0.1.0 <file>` (no clobber), commit the
  pin, and run `tools/bootstrap.sh --seed --out build/seedcheck` from a clean `bootstrap/` cache.
- Add a test for the override beside the existing seed tests, and update RELEASE.md's seed section.

### 2. Visibility markers on enums

Same three levels, same enforcement points as structs.

- Parser: `visibilityIsEnforced` accepts `enum`; `parseEnumDecl` stamps the default on
  `ENUM_DECL.i2`. Decide the default with the user (struct is `internal`; Rust is private).
- Sema: check where a type name resolves to an enum (`semaAnnotationInner`, the `semaHasEnum`
  branch), at a variant construction `Shape.Dot`, and at a `match` arm that names a variant.
  Variants take the enum's visibility. A payload enum is desugared into a struct whose nodes are
  built with `createNode` (so `i2` is 0, public); keep the check on the *enum* node, before the
  desugar, or the marker is lost.
- Migration: reuse the method from this session. Compile every entry point with `check
  --diagnostic-format=json`, read the diagnostics, widen each declaration to the level its uses
  need (`internal` within a package, `public` across). The script is not kept; rebuild it (about
  150 lines: index declarations by name, map each use to a declaring file and package, edit
  the declaration line). Raise `DIAG_ERROR_LIMIT` in `runtime/diagnostics.c` for the run and
  restore it.
- **Two-step rule again**: `src/` will use the new markers, so build a host that understands them
  first (see the next-session prompt) and cut another seed. Plan the seed publication (step 1)
  *after* this, so one seed covers both.
- Tests: a positive and four negative cases like `tests/visibility/shapes*.psm`; remove the P3001
  example from `website/apps/docs/content/errors/visibility-violation.md`, which uses a
  `private enum` as its "modifier not accepted" example, and the `modules.md` / `structs.md` /
  CHANGELOG sentences that say enums take no marker.

### 3. The IntelliJ plugin (`../intellij-plugin`)

Hand-written lexers and a signature parser, with `PrismioLexerCorpusTest` as the drift detector.
Update in this order, running `./gradlew test` after each:

1. `lang/PrismioWords.java` and `completion/Keywords.java`: add `is` and `not` (reserved words).
   `PrismioLexer.java` classifies by that list, so highlighting follows.
2. `symbols/SignatureParser.java`:
   - visibility words before `struct` (`public struct`, `repr(C)`/`packed` after the marker) and
     before a **field** (`public x: Int`, only when a name follows, so a field called `public`
     still parses);
   - a `fn` inside a function body: the parser skips bodies by brace matching, so nested
     functions are invisible to it. Decide whether outline/navigation should list them as
     `outer$inner` or not at all;
   - `pub`-style markers before a global `let` (already accepted for `fn`).
3. Parsing (`parser/`) and the formatter: a condition with no parentheses (`if x == 3 {`), `is not`
   as a two-word operator, closure `|x: Int| { ... }` with a block body, array lengths that are
   expressions (`Array<U32, N * N>`; a `>>` inside type arguments closes two lists).
4. Completion and inspections: `__builtin_*` is now an error outside std, so drop it from
   completion; add `std.raw`, `std.port` and `std.asm` to the import suggestions and `asm`,
   `asmRead`, `asmWrite`, `addressOf`, `pointerAt`, `volatile…`, `atomic…`, `fence` as std members.
   `symbols/CompilerIntrinsics.java` builds probe programs from source: re-run it, since a struct
   in a probe is now `internal` and its fields `private`.
5. Corpus: point `PrismioLexerCorpusTest` at the compiler tree as it now is (`src/`, `std/`,
   `tests/`), including `tests/test_278..284`, which exercise every new construct.

### 4. `Vec.length` and the integer types (after the plugin, per the user)

Ranges and indexes accept any integer type, but `length` answers `Int`, so
`let n: Usize = v.length` needs `as`. Options, to be measured before one is chosen:

- **Give `length` the type of the context** (a conversion where a `Usize` is expected, none
  elsewhere): smallest blast radius, no loop proof changes. Needs a rule for "expected type is a
  wider integer and the value is a non-negative `Int`".
- **Make `length` a `Usize`**: honest, matches Rust, but `Int` is 32-bit by decision
  (`RESULTS-int-width.md` in the history), every `0..<v.length` loop becomes a typed range, and the
  counter proofs in `ir/` assume `Int`. Measure the hosted benchmarks and the freestanding suite
  before and after.
- **Widen `Int` to `Usize` implicitly where lossless** and nowhere else.

Whichever is chosen, `String.length`, `Slice`, `DataView` and `Buffer.length` follow the same rule.

### 5. Smaller items

- `prismio verify` packages `dist/` without a freestanding failure core. Either package with
  `--freestanding-target aarch64-unknown-none-elf` or keep benchmark code failure-free (the
  elision in `sema/ranges.psm` covers constant ranges).
- Windows static LLVM (`docs/LLVM_BRIDGE_PLAN.md`, step 2): only when a Windows machine is at hand.

## Hazards learned

- Importing a module does not make the methods of the modules *it* imports visible; the explicit
  import gate applies to methods. Moving a function between std modules breaks its users.
- A new compiler source or new syntax used in `src/` needs the host first. Copying a binary over
  `.prismio/build/release/prismio` is refused (P1077); build it with `PRISMIO_INTERNAL_HOSTED=1
  <compiler> build --release` so it is stamped.
- The pure freestanding kernels must not import `std.mem` (it pulls in the C runtime and changes
  how a panic prints).
- `__builtin_*` checks must stay syntactic and run before sema rewrites, because sema writes
  builtins into user files itself.
- The 25-error cap in `diagnostics.c` hides most of a migration; raise it for the run only.
- A freestanding build in `verify` has no failure core: a reference to `prismio_panic` cannot link.
