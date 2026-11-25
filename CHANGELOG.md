# Changelog

This file records what is changing in **0.3.0**, the release being prepared. It does not carry earlier
releases: those are on the [release notes page](https://docs.prismio.org/releases). The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/) (pre-1.0, so a minor release may still break things).

## [0.3.0] - Unreleased

### Added

- **The standard library can be a tree (step 1 of `docs/STD_LAYOUT_PLAN.md`; nothing is moved yet).** `import std.a.b` is `std/a/b.psm` in a checkout and `stdlib/a/b.plib` once installed. A directory with no file of its name is a package: `import app.net` reads every module in `app/net/`, as `import app.net.*` does (a file and a directory of one name coexist, and the import means the file), and `import app.net.connect` selects a declaration from all of them. A path segment that begins with `_` seals the module to the modules under that segment's parent: `app.net._wire.frame` may be imported from `app.net.*` and from nowhere else (`P1122`, ``is sealed inside `app.net` ``), and the library index never offers a sealed module. A library file may begin with a `module` header (`module prelude freestanding`, `module freestanding(runtime)`) and mark the declarations the language depends on with `lang("id")` before a function, struct, enum or trait, or before a `fn` inside a trait; both are only recorded so far (`P3021`..`P3025` for a misplaced or malformed one), and `module`, `prelude`, `freestanding`, `runtime` and `lang` are contextual words in the token tables, the JetBrains plugin included. `tests/test_396_package_import.psm`, `neg_419`..`neg_423`, and the new `std_layout` check in the suite (a faked checkout, so the library's own layout is what is tested). Behaviour-preserving: the IR of the 415 programs of `tests/` and `benchmarks/hosted/prismio/` that build is byte-identical to the baseline's, the compiler's own is a fixpoint over two generations, the suite is 832/832 and the AIF differential agrees on all 19 sources.
- **`const` holds a `String`.** `const CODE = "text"` is a constant, and so is `const ALIAS = CODE`, in any order; the compiler puts the text where the name is used. A `String` is a constant only as a whole: `const JOINED = BASE.concat("cd")` and `const SAME = "a" == "a"` are errors that say what is allowed, and a `const fn` still takes, builds and returns only integers and `Bool`. Strings stay out of the expression interpreter, where an operand read as an integer would be quietly wrong. (`tests/test_395_const_string.psm`, `neg_417_const_string_expression.psm`, `neg_418_const_string_type_mismatch.psm`)
- **Nested structs.** A struct can declare another inside it: `size: struct { w: Int, h: Int }` as a field's
  type, or `struct Limits { … }` between the fields. The inner struct is hoisted by the parser to an ordinary
  struct named `Outer$$name` (shown as `Outer.name`), stored inline in its owner, so ownership, AIF and codegen
  are untouched (`--verify`: 0 leaked). Reached as `Outer.field` / `Outer.Limits` in a type, a literal
  (`Outer.Limits { … }`) or an `impl`; bare `Limits` among the owner's field types. `{ w: 1, h: 2 }` is a
  struct literal wherever the expected type is a struct. Not yet inside a generic struct.
- **Destructuring `let`.** `let Point { x, y: b, .. } = p` binds fields by name; patterns nest
  (`origin: Point { x, y }`), `mut` makes the bindings assignable, `_` skips a field. Rewritten by the parser
  to `let x = p.x`, so ownership is unchanged (a value that is not a variable is held under a hidden name,
  which also checks the pattern's type). Not in `match` arms or parameters.
- **Tuples.** `(Int, String)`, `(a, b)`, `t.0` (and `t.0.1`), `let (a, b) = t`, two to four elements. A tuple
  is `Tuple2`..`Tuple4` from the new `std.tuple`, a generic struct with fields `_0`, `_1`, …; the parser writes
  the spellings, and a file that writes a tuple imports `std.tuple` itself. `Copy` (so a `Vec<(Int, Int)>`)
  and `Eq` (`==` on a tuple). `==` on any generic struct now finds an `impl<…> Eq for Template<…>`.
- **`if` and `match` as values.** `let sign = if n < 0 { -1 } else { 1 }`, `return match (c) { Color.Red => "red", _ => "?" }`,
  `println(if ok { "yes" } else { "no" })`. Rewritten by the parser to a temporary assigned in each branch, typed from the
  first branch (or from the `let`'s type); a branch is one expression, an `if` needs its `else`, a `match` covers every value.
  Refused where it could not run first: after a call in the same statement, in a loop header, in the right side of
  `and`/`or`/`??`, in an `else if` condition, in a closure's expression body and in a global `let`.
- **The `?` operator.** `let n = parse(s)?` is the `Ok` value of a `Result`, or an early `return Result.Err(e)`; on an optional
  it is the value or an early `return none`. The rest of the block runs inside the success arm, so an owned payload stays
  owned. The function must return a matching `Result` (same error type) or optional; refused where it could not run first
  (after a call in the same statement, loop headers, right of `and`/`or`/`??`, `else if` conditions, closure expression bodies).
- **`match` without the ceremony.** `match s { ... }` needs no parentheses around the value, an arm may be a single statement
  without braces (`Shape.Circle => print("c"),`), and an arm may be empty (`_ =>`). The old spellings still read.
- **`if let`, `while let` and `let ... else`.** A name is an optional's value (`if let h = find(k) { use(h) } else { ... }`,
  `while let v = next() { ... }`, `let h = find(k) else { return }`), and a variant pattern is an enum's payload
  (`if let Shape.Circle(r) = s`, `let Result.Ok(v) = parse(s) else { return -1 }`); `else if let` chains with plain `else if`.
  A variable or a field path is read in place (`if let x = x` shadows), anything else is held once in a hidden variable;
  `while let` is a `loop` that tests again on every pass, so `continue` goes back to the test. `let ... else` nests the rest
  of the block in the success branch (as `?` does), and its `else` must leave the block (`return`, `break`, `continue`,
  `panic`), which sema checks. A name pattern on a value that is not an optional says so (with the variant spelling for an
  enum). `if let mut h = ...` makes the binding assignable; `_` as a pattern, and a type annotation on a `let ... else`,
  are refused. `test_390_let_forms` (`--verify`: 0 leaked, 0 violations); compiler IR unchanged for the 361 programs of
  `tests/` and `benchmarks/hosted/prismio/`.
- **Match guards, range patterns and string patterns.** `Shape.Circle(r) if r > 10 =>`, `x if x < 0 =>`, `_ if cond =>`,
  `1..9 =>` (end included) and `10..<100 =>`, and `"stop" =>` (a `match` on a `String`), in statements and in `match`
  expressions. An arm that tests is an `if` over the value and the arms after it are its `else`; a guard on a variant pattern
  is matched twice (once for the guard, once to run the arm), so the guard runs once and a function whose every arm returns still returns on every path.
  A `match` that has any of these ends in an unguarded `_`; a bare name before `if` is a binding. The value is evaluated once.
  A `match` without them is read as before (the IR of the 361 programs of `tests/` and `benchmarks/hosted/prismio/` is
  unchanged). `test_391_match_tests` (`--verify`: 0 leaked), `neg_408`..`neg_411`.
- **Patterns inside a variant's pattern.** `Outer.Wrap(Inner.A(v)) =>`, `Outer.Two(Inner.A(v), 0) =>`, `Outer.Plain(7) =>`, `_` to
  skip a value, any depth, with a guard that sees every name, in `match` (statements and values), `if let`, `while let` and
  `let ... else`. The pattern is matched to find out and again to run the arm, so a failing inner pattern falls to the next arm and
  nothing runs twice; a `match` that has one ends in an unguarded `_`. `_` in a variant's pattern is no longer an unresolved name in the
  editor index. `test_392_nested_patterns` (`--verify`: 0 leaked), `neg_412`..`neg_415`; the IR of the 361 existing programs is
  unchanged.
- **Editor support for the new syntax.** The semantic index nests a struct written inside another under its owner and finds
  its fields by path (`win.size.w`), indexes a pattern's new name (`y: why`), prints a tuple as `(Int, String)` (in hover,
  hints and the compiler's messages), and completes the structs inside `Window.`. The VS Code grammar and the JetBrains lexer
  needed no change; both have tests for the new spellings.

### Changed

- **Lang items: the compiler asks the library for what it needs by marker (step 2 of `docs/STD_LAYOUT_PLAN.md`).** `std` declarations the language depends on carry `lang("id")` (`Result`, `optionCoalesce`, the tuple types and constructors, `Eq`/`Ord`/`Iterator`/`Copy`/`Key` and their methods, `HashMap`/`HashSet` and the functions `for` and the literals lower to, `vecOf`, `vecFilled`, `intText`, the print family, `show`, `toString`, the `asm`, `offsetOf`, `cString`, `functionAddress` and port wrappers, `AtomicOrder`), `src/common/lang_items.psm` is the list of ids, and the sema, IR, index and driver sites that spelled those names or the modules `std.option`, `std.raw`, `std.string`, `std.tuple`, `std.math` and `std.display` ask for the item instead. A library that calls its equality trait `Same` and its pair type `Pair` is the library (`std_layout` builds one). The parser, which runs before anything is read, writes `$lang.<id>` for `Result`, the tuple types and `show`, and the driver names them after the merge; a tuple's automatic import is the module the library says declares the tuple type; an item the merged library lacks is `P1124`/`P1125` ("this syntax needs `import ...`") and the library index names the module and the declaration for the messages. An `impl` member may carry `lang("id")` as a trait member does. Behaviour-preserving: the IR of the programs of `tests/` and `benchmarks/hosted/prismio/` is byte-identical to the step-0 baseline, gen1 and gen2 emit identical IR, the suite is 832/832 and `prismio gate` passes. One editor change: `Option`, a name nothing declares, is no longer a built-in type to the index.
- **The compiler asks where a file came from, not what its module is called (step 3 of `docs/STD_LAYOUT_PLAN.md`).** The eleven tests of the form "the module name starts with `std.`" and `semaFileIsStandardLibrary`'s 17 callers are two questions with their own functions in `common/source_files.psm`: `fileFromLibraryRoot(file)` (pruning, the AIF layout fix, the range trace, overflow checks, the editor's user files, a library declaration versus the program's) and `fileHasIntrinsics(file)` (`__builtin_*`, raw pointer steps, the internals of `T?`). A file is the library's when the driver read it from the toolchain's library root, or when it is the entry of a build asked to compile a library module (`--module`); a `std/` directory beside a program that is not the library's no longer makes its files the library's. The overflow exemption is the same test (a library module is built without the checks, as the toolchain builds it). Behaviour-preserving: the IR of the programs of `tests/` and `benchmarks/hosted/prismio/` is byte-identical to the step-0 baseline, the compiler's own is a fixpoint over two generations, the suite is 832/832 and `prismio gate` passes.
- **Packaging the library left the compiler (step 4 of `docs/STD_LAYOUT_PLAN.md`).** `prismio build <module.psm> --emit plib --module <name> [--target T]... [--freestanding-target T]... -o x.plib` writes a whole compiled module in one process: the source as its interface, its `module` header and lang items as metadata (PLIB v4), and a code section per target, normal and `--verify`; a freestanding target gets a section only when the header says the module is freestanding (the freestanding modules of `std/` now carry `module freestanding` or `module freestanding(runtime)`). A target may declare `after { run(...) shell(...) }` steps, run once it is built, with the bare word `output` for the file just built (`UMS2117`, `UMS2118`). This checkout's compiler targets run `tools/toolchain_layout.psm`, the one place that says what a toolchain carries (runtime bitcode, freestanding sources, `std/` precompiled, cached by content), and `tools/package.py` runs the same tool; `tools/bootstrap.py` copies `std/` as source into the `stdlib/` beside a bare generation. `std.*` resolves from the `stdlib/` beside the running compiler and nowhere else (a program's own `std/` directory, and the walk up to a checkout, no longer answer for it); a module checked or emitted on its own (`--module`) reads its siblings from its own tree. Removed from the compiler: `compiler_emit_local_toolchain`, `emit_stdlib_plib`, `emit_plib_section`, the runtime module list, `PRISMIO_LIBRARY_MODULE`, the checkout probes and the Python PLIB writer (three C functions the committed seed still calls remain as stubs until the next seed). A `--freestanding` build for a triple the toolchain has no section for compiles the module from the source its PLIB carries. **A change that needs new `std` and `src/` together** (a function added to `std/` and used by the compiler in one step) cannot be built by a project host whose `stdlib/` predates it: `prismio bootstrap --promote` takes it. `--emit plib` and `--internal-file-hash` are new; `P1126`..`P1129` and `P1131`..`P1134`. Also fixed: since step 2 every build merged all 33 library modules, because asking a `.plib` for a lang item registered it as imported (hello world built 13 ms slower than before step 2); and a toolchain built by a project without `SDKROOT` in the environment left the macOS `SDK Version` out of the runtime bitcode (the pre-SDK-27 allocator, about 2x slower allocation). Behaviour-preserving: the IR of the corpus matches the previous compiler's apart from the library's directory, gen1 and gen2 emit identical IR, and the host `.plib` and runtime bitcode are byte-identical to the previous packager's from the same sources (all 33 modules, host and `aarch64-unknown-none-elf`).
- **A module's header says what it needs, and every import checks it (step 5 of `docs/STD_LAYOUT_PLAN.md`).** `module freestanding` links nothing, `module freestanding(runtime)` needs the runtime's allocator, and no header means hosted; a module may import only modules that need no more than it does (`P1130`), whether it is the library's or a program's own. A `--freestanding` program is refused a library module whose header is not freestanding (`P1094`, as before), and the freestanding runtime is linked when one it imports needs it. This replaces the module lists the compiler kept (`freestandingSafeModule`, `freestandingNeedsRuntime`); the `std.core` modules-to-be also carry `prelude`, which nothing reads yet. `std.number_text` is hosted: it was listed as freestanding but imports `std.io`, so a freestanding program could never import it. A `--freestanding` program can now write a tuple (the library index that names the tuple module was switched off for freestanding builds). The editor completes library imports from the `stdlib/` tree, nested modules included and sealed (`_`) ones left out. Behaviour-preserving: corpus IR identical to step 4's, gen1 and gen2 emit identical IR.
- **The standard library is a tree (step 6 of `docs/STD_LAYOUT_PLAN.md`).** `std.option`, `std.tuple`, `std.eq`, `std.ord`, `std.iter`, `std.copy`, `std.default`, `std.key`, `std.vec` and `std.map` are `std.core.*`; `std.raw`, `std.asm`, `std.port`, `std.syscall` and `std.errno` are `std.sys.*` and are never offered as an import fix; `std.json` is `std.encoding.json`; `std.display` and `std.number_text` are `std.fmt.display` and `std.fmt.number` (`import std.fmt` reads both); `std.input` and `std.poll` are `std.io.input` and `std.io.poll`; the Unicode tables and the Float text code are sealed (`std._unicode.case`, `std._unicode.properties`, `std._fmt.float`). **The old paths still resolve for one release, with a warning** (`P1135`, ``std.option` is now `std.core.option``). Two parts of the plan are not done, because each failed its gate: `std.io` stays one file (as a folder, every printing program compiled the input module too and its IR changed), so input is `import std.io.input`; and `std.unicode` stays a public module with its methods (declared on `String`, every String program read the width and grapheme tables: `check` 11.1 to 14.6 ms, hello world's 5.9 to 14.4 ms). `unicodeVersion()` is in `std.unicode`. Helpers `std.string` shares with the other folders (`strClone`, `strFromInt` and kin, `str_with_capacity`) and the Float text functions became `public`, since `internal` now spans one folder. The nested fixtures under `tests/sealed/` were ignored by git and are tracked now; the release gate also builds the tree with the seed-built compiler. Behaviour-preserving: of 367 corpus programs, the 359 that build link to the same instructions before and after (the other 8 build with neither compiler), and their IR is identical apart from the renamed paths.
- **A lazy prelude, behind `--prelude` (step 7 of `docs/STD_LAYOUT_PLAN.md`).** With `prismio build`, `run`, `check` or `aif` given `--prelude`, a name that neither the program nor a module the file imports declares may come from a library module whose header says `prelude` (`std.core.*`): a `Vec`'s `sort`, a vector or map literal, `??`, `Eq` and the other core traits need no import. Only the names a file looks up merge a module, and the file then sees it as if it had written the import. The program's own functions, types and traits win; its own methods do not hide a library method of the same name, since a method answers only for its receiver. `std.io` is not in the prelude. Which modules are the prelude is read from their headers; the compiler names none. **Off by default.** Measured: hello world's IR is identical with and without it; AIF sites and binary sizes of the five baseline programs are unchanged, and build time is within 2% in alternating runs; a program with its `std.core` imports removed links to the same instructions as with them; every corpus program that builds without it builds with it, two of them gaining only unused `declare` lines, and the compiler's own IR is identical. Not covered: a project build (`build.ums` has no setting for it), and a name the program's file already gets from an imported module keeps meaning that one.
- **Five diagnostic codes that two to four different errors shared have their own numbers.** `P3017` (tuple type, tuple value, tuple pattern) keeps the tuple type; the value is now `P3019` and the pattern `P3020`. `P3201` stays the parser's general "expected ..." error; the `_` that comes before other arms is `P3202`, a `match` with a guard, range or string pattern and no `_` is `P3203`, and a `let` with a variant pattern and no `else` is `P3204`. The text of every message is unchanged.
- **A `match` over a fieldless enum must name every variant or end in `_`.** It was legal to name a subset, and the variants left out ran no arm, which is also what happens to a variant added later. It is now `this match does not cover South, West of `Dir`; add the missing arms or a `_` arm`, the error a payload enum already gave. A `match` over an integer is unchanged. To keep the old behaviour write `_ => { }` last. The compiler's own source needed 40 such arms; no program in `tests/` or `benchmarks/` did. (`tests/neg_416_fieldless_enum_match_missing.psm`, `tests/test_394_enum_match_exhaustive.psm`)
- **The `entry` idioms, as methods.** A handle holding the map cannot exist (a parameter is a borrow and may not be kept)
  and a closure cannot name the map it is lent from (a capture is a move or a copy), so the idioms are methods, each one
  lookup: `getOrInsert` and `getOrInsertWith` are `or_insert` and `or_insert_with`; `getOrInsertDefault(key)` is
  `or_default` (a free function over `V: Copy + Default`, so `HashMap` itself gained no bound; the default is stored on a
  miss); `upsert(key, initial, f)` is `and_modify(f).or_insert(initial)` (the counting idiom,
  `counts.upsert(word, 1, |n: Int| n + 1)`); and `modify(key, f)` lends the stored value to `f` in place, so
  `groups.modify(key, |inout v: Vec<Int>| { v.push(x) })` copies nothing where `m[k].push(x)` read a copy, changed it and
  stored it back, copying the `Vec` twice. `modify` is for a `Vec`, a struct, an array or a slice (the types `inout` can
  be); an `Int` or a `String` value uses `update`. `impl<T: Copy> Default for Vec<T>` is new in `std.default`. An
  `inout` parameter of a closure was refused as a change to a `let` (`x.push(1)` inside `|inout x: Vec<Int>|`); it is
  marked now. A Rust-style `m.entry(k).orInsert(v)` spelling is not built: it would be a rewrite to these methods and
  nothing more.
- **`shrinkToFit` on `Vec`, `HashMap` and `HashSet`.** `v.shrinkToFit()` gives back the capacity past the length: a new
  runtime function, `list_shrink_to_fit`, which an empty list answers by letting go of its storage and a small list (whose
  elements share its header's block) or an arena's list by keeping what it has. A map or a set shrinks its columns and its
  probe table to the smallest power of two that keeps the entries at or under half full (never fewer buckets than a new
  one's), which also clears the tombstones; `capacity` reads what is left and the next insert past it grows again
  (`test_map_shrink`, 0 leaked). It is a builtin, so it is in the five name tables, the AIF contract (borrow) and the
  oracle, and the column proof counts it as a store.
- **`Hash` and `Hasher` in `std.key`.** A composite key feeds its fields to a hasher instead of folding them by hand:
  `impl Hash for Point { fn hashInto(self, inout state: Hasher) { state.writeInt(self.x); state.writeInt(self.y) } }`, then
  `impl Key for Point { fn hash(self) -> Int { return hashOf(self) } ... }`. `Hasher` has `writeInt`, `writeWide`,
  `writeBool`, `writeChar` and `writeString`; `Hash` is implemented for the integer types, `Char`, `Bool` and `String`, and a
  field with its own `Hash` is asked with `self.at.hashInto(state)`. It is additive (`Key` is unchanged) and costs nothing: a
  1,000,000-key hashing loop is 6 ms folded by hand and 6 ms through `Hasher`, and a 360,000-key `HashMap` workload is 51 ms
  either way. A single word still hashes as `keyMixInt(word)`, so the identity locality of small ids is untouched. A
  `HashSet` that owns its keys is not built: moving a key in saves about 4 ns an insert, and `get` returning the stored object
  is shared ownership, which the language does not have (`test_hash_hasher`; the numbers are in the developer docs' performance
  decisions).
- **`make().names.length` and `make().name.length` release the struct.** The length of a `Vec` or `String` field of an
  owned temporary struct is read by an early return that skipped the release a call argument gets, so the struct leaked
  wherever it could not be bound ahead of the statement, on the right of `and`/`or` (`test_owned_temporary_scalars`).

- **HashSet grows up.** `for key in set` visits every key (lowered to `count` and std.map's `hashSetKeyAt`, which is
  not API: a set promises no positions, so it has no `keyAt`). New: `get(key) -> K?` and `take(key) -> K?`
  (copies of the stored key, because a `Key + Copy` set cannot hand out the one it keeps; interning waits on the
  ownership work), `toggle(key) -> Bool`, `retain(f)` (survivors keep their order), `reserve(additional)`, and the
  set algebra: `union`, `intersection`, `difference`, `symmetricDifference` (each a new set, operands untouched),
  `isSubsetOf`, `isSupersetOf`, `isDisjoint`. `insertAll`, `removeAll` and `retainAll` take a `HashSet<K>` or a
  `Vec<K>`, and are safe with a set and itself. `length` is `count`, and `capacity` is new, and so is `shrinkToFit` (below). The new `test_set_api` runs under the `--verify` ledger with String keys:
  0 live bytes.

- **A HashMap holds owned values (breaking for struct values).** `HashMap<String, String>`,
  `HashMap<Int, Vec<Int>>` and a map of structs that own a `String` compile and read 0 leaked, 0 violations under
  `--verify` (`tests/test_map_owned.psm`, held to it by the ownership probes). `V` is now bound by `Copy`, as `K` is by
  `Key + Copy`: the map stores `copyOf` of what it is given and every reader (`get`, `getOr`, `m[k]`, `take`,
  `set`'s previous value, `getOrInsert*`, `values()`, `keyAt`, `valueAt`, a `for` loop) answers a copy, so no view of a
  stored value leaves the table, which is what lets the escape analysis keep releasing it (the 2026-08-29 attempt
  returned the stored element and leaked every value). `getOr` copies its `fallback` too: returning the borrowed
  parameter leaked and failed a `--verify` fact. Scalars are unchanged (`copyOf` is the identity): the update loop
  times 39.2 ms (39.1 before) and remove-and-reinsert 45.7 ms (46.7). `impl Copy for Ptr` and
  `impl<T: Copy> Copy for Vec<T>` are new in std.copy. A struct value must write `impl Copy`; without it the error is
  *`Report` does not implement `Copy`*.
- **A displaced or removed element is released at the store, for any private `Vec` field the compiler can prove.** A value
  replaced by `set` or `m[k] = v`, and a key or value removed by `remove`, `take`, `retain` or `clear`, used to be parked
  until the map died, as a removed `String` key always was: 20,000 replacements of one value peaked at 749 KB. The
  checker released a displaced element at once only for a fresh local `Vec`, and a `HashMap`'s two columns on a promise
  `std/map.psm` made and it trusted by name. It is now a proof (`src/ir/columns.psm`): a private `Vec` field of owning
  elements is a *closed column* when the module uses it only as the first argument of a list builtin, every `list_get` of
  it is consumed where it stands (a `copyOf`, a call that answers a scalar or a new value and keeps nothing, a scalar
  read, or a `let` with no store in its scope), and no call a view is live across can store into it (a call graph over
  the module). That covers a `HashMap`'s columns, a `HashSet`'s, and any user struct's: 200,000 replacements of a
  `Vec<String>` field peak at 551 bytes where they parked 8.4 MB (`test_388_closed_columns`; `test_389_open_columns`
  holds the uses that must keep parking: a view read after the store, the column passed on or iterated while stored into,
  a view handed to a function that stores, a `public` field). `PRISMIO_COLUMN_TRACE=1` prints each column's verdict and the
  use that kept it open. The map update and removal loops time the same (18 and 14 ms against 18 and 14, same std) and
  `test_map_owned` compiles to the same machine code. Writing the proof found the promise broken in `std/map.psm`:
  `values()` of a `HashMap<String, Vec<Int>>` pushed each stored `Vec` itself into its result (5 leaks and a failed
  `--verify` fact), and `HashSet`'s `retain`, `insertAll`, `removeAll`, the set algebra and `for key in set` handed views
  to callees that may mutate the set; all take copies now. A column used with `pop`, `removeAt`, `sorted` or another
  `std.vec` function, or whose field is `public`, still parks (KNOWN_ISSUES).
- **Owned temporaries that leaked are released.** A String field compared in place (`make().name == x`, also on the
  right of `or`); a scalar element read off an owned `Vec` on the right of `or` or in a `while` (`ints()[0] < 3`); a
  String, `Vec` field or element read in a statement head (`let n = make().name`, `println(strings()[1])`), which is
  bound ahead of the statement like a hand-written `let`; and a String element compared in place
  (`strings()[0] != x`, also right of `or`). A struct literal written inline as the argument of a Prismio function, whose
  type owns something (`dup(Person { name: word(1), age: 1 })`, `people[k] = Person { ... }`, `[Person { ... }]`), is
  bound ahead of the call: per-type field keys left its owned field with no owner. An enum value, a builtin callee
  (`push` builds the struct in the list's slot) and a pure-scalar struct are left as they were.
- **A map literal with a computed owned key or value is a producer, however many entries it has.** `{ word(1): word(2) }`
  is one `mapEntriesN(k0, v0, ...)` per run of twelve entries, merged by `mapMerge` (std/map.psm), as a Vec literal is one
  `vecOf`, with each argument released after the call and the map owned wherever it lands. It leaked the values in a
  `let`, and the whole table through the old `mapPut` chain in a struct field or a `return`; both read 0 leaked now,
  and so does a literal of thirty (`test_map_long_literal`: 12 of 13 values leaked before). A later run's entry
  replaces an earlier one with the same key, as the chain of `set`s did; the backend nests calls 64 deep, so a literal
  holds 768 computed entries. A literal whose entries are literals, names or scalars is still one `mapFromEntries`.
  `mapPut` and `mapPutAll` are deleted.
- **HashMap's storing API, and the free-function twins are gone (breaking).** `m[key] = value` now inserts or
  replaces (a generic struct's `set` is found the same way `at` always was), so reading and writing are three
  different operations: `m[key]` panics on a missing key, `m[key] = v` stores, `m.get(key)` answers an optional.
  `m.set(key, value)` now answers the **value it replaced** (`V?`, `none` for a new key) in place of a `Bool`; the
  new `m.insert(key, value) -> Bool` stores only a new key and says whether it was new, as `HashSet.insert` does.
  New: `getOrInsert`, `getOrInsertWith` (the factory runs on a miss only), `update`, `take`, `retain` (survivors
  keep their order, one rebuild of the probe table), `reserve(additional)` and `capacity`. `length` is `count`
  and `has` is `contains` on `HashMap` (and `length` is `count` on `HashSet`). `clear` is specified to keep the
  capacity. `mapSet`, `mapGet`, `mapGetOr`, `mapHas`, `mapRemove`, `mapClear`, `mapIndexOf` and `mapUpdate` are
  deleted; `for (k, v) in m` lowers to `count`, `keyAt` and `valueAt`. `mapLen`, `mapKeyAt` and `mapValueAt`
  went with the seed refreshed from this compiler (they were only there because the old seed's loop lowering still
  emitted them). Measured
  against the previous std on the same compiler: the `m.set(k, m.getOr(k, 0) + 1)` loop 39.1 ms (was 41 ms; `set`
  is `inline(always)` because returning the previous value otherwise cost it 20%), remove-and-reinsert 47 ms (was
  50 ms).

- **A float loop reduction may be summed in any order.** A `Float` or `F32` local declared outside a loop that the
  loop only updates as `x += e`, `x -= e`, `x = x + e` or `x = x - e`, with `e` not reading `x`, has those adds
  emitted `reassoc` (the one flag the vectorizer needs to split a sum into SIMD lanes; `nsz`, `nnan` and `ninf`
  are not set, so NaN, infinities and signed zeros are untouched). The `fmuladd` of `sum += a[i] * b[i]` takes it
  too. Anything that reads the accumulator for another purpose keeps sequential order: Kahan summation,
  time-stepping, `sum = sum * 0.5 + x`, a global, a field, a name the loop rebinds. Products are not reductions.
  C++ and Rust both promise sequential order, so the same plain loop stays scalar there. In the hosted suite:
  `numerical_integration` 1.1 ms (0.51× of C++, 0.52× of Rust), the new `float_sum` 2.2 ms (0.20×, 0.21×) and
  `float_dot` 4.2 ms (0.33×, 0.37×); built with `--strict-float` the three land on C++ (1.00×, 0.94×, 0.91×). The
  vectorizer's eight partial sums are as accurate or better than one chain (harmonic sum −52 against −414 ulp). The
  same source gives the same bits on one target; different targets can differ in the last bits, as they already
  did through `contract`. `--strict-float` (and `strictFloat` in a manifest's `profiles` block) keeps every float
  add in source order; `PRISMIO_REDUCTION_TRACE=1` prints each marked site. `src/` and `std/` take no mark.
  Developer docs: [Float loop reductions](https://developers.prismio.org/compiler/float-reductions).

### Fixed

- **Returning a value unwrapped with `expect` freed it first.** `let s = expect(q); return s` released `q` at the
  `return` (the analysis did not see `expect` as handing its argument back), so the caller got freed memory and
  `--verify` reported a release of a pointer that is not live. It was reachable through `?` on an optional followed by
  `return s`. That `return` counts as returning `q` now (`irUnwrapSource`): `q` is kept on that path and released on
  the others (0 leaked where the payload is returned on one path only).
- **A `match` arm after `_` was invalid IR.** `_` matches everything, so the arms after it can never run, and
  codegen put a terminator in the middle of a block. It is an error now ("comes after `_`"), for an integer, enum
  or payload `match`.
- **A program that never spawns a thread no longer carries the allocator's thread-local setup, or its 16 KiB
  page.** Hello had gone from 33,952 bytes to 51,160 when the slab allocator landed; it is 34,120. Two causes in
  `runtime/lang_runtime.c`: `slab_refill` asked `slab_cache() == &slab_tls`, a thread-local's address against a
  global's, which LLVM does not fold; and the "has spawned" flag was `volatile`, so no read of it folded even
  with nothing left to set it. Either kept a `pthread_once`, a thread key and up to five thread-locals alive,
  which is initialised data, which is a page of `__DATA` on macOS. Over the 337 buildable `tests/test_*.psm`:
  19.90 MB to 14.06 MB (mean 59,062 to 41,718 bytes). A program that does spawn is unchanged (the hosted suite,
  259,704 to 259,800). Run time on the 70 hosted workloads: geomean 0.994 against 1.0005 for an identical-binary
  control; hello builds in 37.8 ms, was 39.9. Windows keeps the `volatile` flag (`Interlocked*` wants it).

- **A `HashMap`, a `HashSet` or any generic struct in a field of a struct is released once, by the struct.** `let flat:
  HashMap<Int, Int> = {}; return Holder { table: flat }` crashed on the first read of the result: `flat` was released at the
  scope exit and the returned Holder still pointed at it. A map literal written in the field
  (`Holder { table: { word(1): word(2) } }`) leaked every key and value (10 of 16 allocations, 2 entries or 27); a
  `Box2<String>` field leaked its contents. The cause was one line in the analysis: `aifFieldTypeName` named the
  declared type of every field with type arguments `List`, from when `List` was the only generic type, so no instance
  (`HashMap$Int$Int`) matched it, the field was never a release point, and a value stored into one kept its owner's scope
  release. It names the constructor now, `fieldReleaseOf` matches an instance of it, and the struct's release calls the
  instance's release function. `test_map_in_struct` holds the shapes (bound, inline, long, a `HashSet`, a generic struct,
  nested, read off a temporary) to 0 leaked, 0 violations.

- `prismio fmt` joined `, ..}` in a destructuring pattern into `,..}`.

### Repository

- **Diagnostic codes are named in one registry (`src/common/diag_codes.psm`), and call sites pass the name.** 165 sites in 25 files wrote a `"Pnnnn"` literal and message at the call; now `diag_error_code(DIAG_CLI_CHECK_MISSING_SOURCE, "missing source file")`, with each code a `public const` String there. `tools/lint.py` reads the registry: a name is used at exactly one call site, a code is written once, a code is in the area of the file that reports it (now including `project/`, `driver/` and `fmt/`, which had no area check), no `"Pnnnn"` literal may be left in `src/`, and a registry that parses to nothing fails instead of passing. Messages stay at the call sites. `src/` now needs the compiler to understand `const` of a `String`, so the committed seed has to be refreshed before a bootstrap from it works: `bootstrap/seed.ll` is re-cut and left uncommitted.
- **The compiler's biggest functions are split by family (`docs/SIMPLIFICATION_AUDIT.md`, steps 4-6).** `generateCall` goes from 1,459 to 695 lines and `semaCheckBuiltinCall` from 676 to 18, their builtin chains moved unchanged into per-family functions; `generateStatement`, `semaStatement` and `collectStringsStmt` are `match` on the node kind; and `irFindBorrowedTemporary` returns a struct instead of leaving three globals behind.
- **The compiler's source walks chains and trees through one helper each (`docs/SIMPLIFICATION_AUDIT.md`, step 3).** `chainLength`, `chainAt` and `chainNamed` replace 20 hand-written copies, `astAny` and `astSum` (`ast/nodes.psm`) replace nine identical recursive walkers in `ir/expr.psm`, and the last exact duplicates (`implExists`, `semaMapReset`, three "is this Int in the Vec" helpers) are gone. A sampled self-compile shows none of those walkers in its top frames, so no per-function fact pass was built.
- **187 module-level constants in the compiler's source are `const`, not `let`.** Every one was an external, mutable global; the 15 `String` ones followed once `const` could hold a `String`. The compiler's own IR is byte-identical either way.
- **One owner per fact in the compiler's source (`docs/SIMPLIFICATION_AUDIT.md`, step 2).** Every `compiler_*` extern is declared once, in `common/native.psm` (16 of them were declared in two or three files), the four trait-by-name walks are `declFindTrait`, the diverging-builtin list is `builtinNeverReturns`, and the optional-scalar rows of `index/lowered.psm` are one block per table. No program output changes: all 772 programs in `tests/` and `benchmarks/hosted/prismio/` give the same IR.
- **The editor reports an undeclared `Item`, `Frame` or `Index` as unresolved.** `ixIsBuiltinType` took any two-to-five letter name starting with `I`, `U`, `F` or `B` for a built-in numeric type, so those names were never marked. It now asks `typeIntFromName` and `typeFloatFromName`, which is what sema resolves with.
- **The compiler's own source lost its dead code (`docs/SIMPLIFICATION_AUDIT.md`, step 1).** 43 unreferenced functions, 10 duplicate imports, the `List` copy of every `Vec` row in `index/lowered.psm`, a 16-branch `hexDigit` and `tools/_split_benchmark_modules.py` are gone, and `bitsToVec`/`intsClear` empty a `Vec<Int>` with `clear()` instead of popping one element at a time. Self-compiling `src/main.psm` takes 5.3% less wall and CPU time (1.528 s to 1.448 s median, 21 runs; the A/A control reads 0.1%) and retires 3.8% fewer instructions. The IR of every program in `tests/` and `benchmarks/hosted/prismio/` is byte-identical, so a user program does not change.
- **The language-gaps tests are held to 0 leaked.** `test_390_let_forms`, `test_391_match_tests` and
  `test_392_nested_patterns` are in `ownership_probes` (`tests/test_runner.py`), so a pattern form that stops releasing an
  owned String payload fails the suite instead of passing quietly. `docs/KNOWN_ISSUES.md` records what the work found and did
  not fix: a payload enum built both as a stack literal in an argument and by a function leaks the function's inner payload, and
  why skipping frame sites in the field's release is not sound.
- **`float_sum` and `float_dot` hosted benchmarks** (Prismio, C++, Rust), each 20 passes over 1M doubles, written
  plainly in all three languages. Their values are small multiples of 1/8 and 1/16, so every grouping of the sum is
  exact and the arms agree to the bit whether or not a compiler splits it into SIMD lanes.

### Documentation
