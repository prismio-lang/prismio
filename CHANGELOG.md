# Changelog

## Unreleased

### Language

- The host-routing banner is suppressed when the output is a format. Choosing a
  stream was never the fix: on stdout it broke `aif --manifest`, and on stderr it
  broke `--diagnostic-format=json`, whose JSON Lines go there. It now prints for
  ordinary commands and not for either machine-readable one.
- `build.ums` gains `suite`, `lists` and `verify`, and `tests/test_runner.py`
  gains `--compiler`. The suite goes through `tools/run_suite.py`, which tests a
  *copy* of the compiler — the ums, object-cache and cold-build fixtures all
  assert what a build does, and none of them survives being run by the binary
  under test.
- `tools/run_suite.py --compiler` accepts a relative path. It resolved the
  argument only for the banner, which reported it relative to the repository and
  raised `ValueError` there before running anything — so the documented way to
  test a compiler you just built failed on the spelling you would naturally use.
- **The two ownership regression guards are back under `tests/`, and asserted
  rather than merely run.** `pointer_return_temp.psm` and
  `extern_alias_escape.psm` went with `aif/evidence/xlang/` when that tree was
  superseded; `run_corpus_test` had built and run them for an exit status, which
  neither defect changes — the first leaked 100 of 100 while exiting 0, the second
  printed an empty line and exited 0 while double-owning a string.
  `run_aif_verify_test`'s table reads their ledgers now. The corpus sweep is 8
  sources and 7 runnable, down from 33 and 30, and its docstring says so.
- **`PRISMIO_INLINE_ELEMS=0` is diagnosed, and the count that drifted is
  explained.** Four fixtures fail under it, all leaks with no violations and
  unchanged checksums. The fifth entry the list used to carry was never a gate
  failure: `test_62_split_release` reads the same ledger with the gate on and off
  on three compilers, including the one the original count was taken on. The
  remaining four are one shape — the switch is a `getenv` read at run time, while
  the element disposition, the arena placement and whether a site allocates at all
  are compile-time decisions, so one binary is being asked to be correct under two
  placements. See `aif/evidence/RESULTS-inline-elems-gate.md`.
- **`strConcat`, `strCharAt`, `strSlice` and `strCompare` are gone from the
  public API**, which finishes what `strEquals` started: no String operator now
  lowers to a call on a prefixed library function. `+`, `s[i]`, `s[a..b]` and the
  four orderings are rewritten into `concat`, `charAt`, `slice` and `compare` in
  `impl String`, and those five carry the implementations. 797 call sites across
  `src/`, `ums/` and `tests/` moved to the method spelling.

  **Not a builtin, and the recorded reason for that was wrong twice over.** The
  note in `src/aif/contracts.psm` said a producing builtin could not be expressed;
  it can — `aifFfiProduces` answers return contracts and already serves
  `list_new`, `soa` and `aos`. What actually forced the design is the pass-through
  rule: a function whose `return` is another function's allocation gets its caller
  no drop as soon as an argument is itself owned, so a method delegating to a
  `str*` helper leaks both operands. Measured over 1,000 iterations of
  `let t = f("a","b"); let u = f(t,"c")`: delegating reads **2,001 allocated / 1
  released / 2,000 leaked**, owning the body reads **2,001 / 2,001 / 0**. The
  obvious probe — literal arguments only — reads 1,001 / 1,001 / 0 either way and
  says nothing. See `aif/evidence/RESULTS-string-operator-targets.md`.

  Nested spines were flattened rather than transcribed, so `strConcat(strConcat(a,
  b), c)` became `a.concat(b, c)` and not the chained form, which leaks worse than
  the nest did. **297 intermediate allocations the compiler used to leak on itself
  are no longer created.** `concat` gains three- to six-argument overloads for it.
  `run_string_operator_ledger_test` asserts the fixture's `--verify` ledger,
  because every value assertion in it passes against the leaking arrangement.

- **`strEquals` is gone from the public API**; `a == b` and `a.equals(b)` are
  both valid and both correct. `==` no longer lowers to a call to a prefixed
  library function — it lowers to a new `__builtin_string_eq`, backed by the
  runtime's vectorised `strcmp` — which is what freed the name to be removed.
  The implementation moved into `impl String`, where it keeps the portable byte
  loop: the bootstrap seed does not know the builtin, and `std/string.psm` has to
  compile under the seed. 1,073 call sites across `src/`, `std/`, `ums/` and
  `tests/` moved to `.equals()`. A selective `import std.string.strEquals`
  becomes `import std.string.equals`.
- **The trait system is complete**, and `TRAIT_SYSTEM_ROADMAP.md` is retired.
  All 21 milestones shipped; the system is described in `../docs`
  (`content/language/traits.md` and `generics.md`) rather than in a delivery
  tracker. What was deliberately left out moved to `KNOWN_ISSUES.md` under
  "Traits", and the roadmap remains in `git log` for its design rationale.
- `impl Trait` is a type in argument and return position. `fn f(v: impl Show)`
  is the generic parameter nobody wrote — it means `fn f<T: Show>(v: T)` and
  lowers to exactly that, so the caller chooses the type. `fn make() -> impl Show`
  is the other construct that shares the spelling: one concrete type chosen by
  the body, which the caller cannot name. It is resolved at compile time and the
  annotation rewritten, so the call stays statically dispatched and costs
  nothing — it is not a trait object. Several bounds work in both positions
  (`impl Show + Weigh`), and a synthesised parameter may sit beside a written
  one. Every `return` in an opaque-returning function must name the same type;
  two that disagree are an error pointing at both, with a note offering
  `dyn Trait`. Anywhere other than those two positions — a struct field, a
  local — is rejected in the parser.
- `std.io` gains `eprint` and `eprintln`, which write a `String` to stderr. A
  program whose stdout carries a format — `aif --manifest`, JSON diagnostics, a
  pipe into another tool — can now report status without corrupting it. Only
  `String` is overloaded; every other `print` overload exists to render a
  number, and no such caller has appeared for stderr.
- Block comments are `/* ... */`, and they **nest**. The C form cannot comment
  out a region that already contains a comment — the first inner `*/` ends the
  outer one and the rest becomes code again, usually with no syntax error to say
  so — so the lexer counts depth instead. A `//` inside a block comment is not a
  line comment: depth counts delimiters and nothing else, so a closing delimiter
  written in prose still closes the comment. An unclosed `/*` is reported at the
  opening delimiter, because every unterminated comment reaches the end of the
  file and that position identifies nothing.
- Generic parameters accept multiple trait bounds with `+`, such as
  `fn keep<T: Ord + Copy>(value: T) -> T`. Every bound is checked independently
  at instantiation, and diagnostics identify the requirement that failed.
- Trait conformance belongs to the exact `impl Trait for Type` block. An
  unrelated global or inherent method with the same signature can no longer
  satisfy an incomplete impl accidentally. `Map` now states its real
  `K: Key + Copy` requirement instead of relying on cross-impl conformance.
- Concrete trait implementations are coherent: a second `impl Trait for Type`
  is rejected at the later declaration with a note pointing to the first.
- Generic inherent impls are supported with structural targets, including
  `impl<T> Box<T>`, impl-level bounds, complete `Self` substitution, methods
  with additional type parameters, and concrete specializations such as
  `impl Box<Int>`. Unconstrained parameters and bare type-parameter targets are
  rejected. Generic methods sharing a name on different receiver constructors
  retain distinct demand-driven instantiations.
- Generic trait impls such as `impl<T: Bound> Trait for Box<T>` participate in
  bound satisfaction only when their structural target matches and every impl
  bound holds. Conformance is checked against the owning generic method
  templates, and coherence rejects overlapping generic/concrete targets while
  permitting provably disjoint concrete specializations.
- Traits may declare type parameters, as in `trait From<T>`. Structural trait
  applications such as `From<Int>` are supported in impls and bounds; their
  arguments participate in conformance, generic applicability, and coherence.
  Impl parameters may be constrained by the trait side (`impl<T> From<T> for
  String`), and arity mismatches receive declaration-directed diagnostics.

### The String representation

- **`String` is a German string.** The 16-byte `{ptr, i64}` pair now carries a tag
  in bit 31 of its length word, and a tagged pair holds its bytes instead of an
  address: 12 of them, in field 0 and the top half of field 1. This is the Umbra
  layout (CIDR 2020) that Arrow, DuckDB, Velox and Polars call a StringView.

  Sized from what this language actually allocates rather than from what libc++
  chose. Histogramming `length` at `str_with_capacity` across
  `prismio check src/main.psm` — 444,798 string allocations — puts **53.3% at four
  bytes or fewer**, 74.6% at eight and 81.3% at twelve. libc++'s 22 reaches 96.5%
  but costs a 24-byte string, and the traffic past twelve is mostly substrings,
  which the storage classes this layout leaves room for can take to zero rather
  than to inline.

  `strSubstring` and `String.slice` take the short form whenever the result fits,
  through a new `__builtin_string_inline`. On `tokenization` that is **every**
  token: the workload's allocation count falls from 54,033 to 33 — C++, which has
  been the thing to beat there, makes 29 — and the row runs **3.53x faster than
  at the start of this work** (1,036,625 ns to 294,042 ns, median of 31
  alternating runs), of which the recycler was 1.65x and this is 2.14x. Against
  C++ it moves 3.88x → **1.10x**; against Rust 1.08x → **0.31x**.

  Three things carry the change:

  - The tag sits at **bit 31, not 63**, so the whole top half of the length word
    stays data. At 63 the twelfth byte would have to share and the layout would
    reach ~80% instead of 81.3%. It costs one `and` on `__builtin_string_len`.
  - **The representation is resolved once per binding, not once per byte.** Which
    half of the pair holds the bytes costs five instructions to ask, and asking
    per character put all five inside every scan loop — LLVM unswitches a
    one-site loop cleanly, which is why this looked fine in isolation, but
    declines on a loop the size of `benchTokenization`'s. A `let` and a parameter
    now resolve it where they are bound, which dominates every use, and a byte
    read is the GEP and load it always was. Worth 234 us → 161 us on the scan
    alone; `strCountOfChar` vectorises again (`dup.16b`, 64 bytes an iteration).
    Immutable bindings only: a reassignment inside a loop would define the
    replacement in a block that need not dominate a later use.
    `ir_str_byte_at` stays as the fallback for every operand that is not a
    binding, and reads the byte straight out of the pair rather than
    materialising it.
  - **A container slot still owns one word**, so a short string is copied to the
    heap on the way into a list or a slice, through the runtime's new `str_own`.
    Struct fields are unaffected: a String field already embeds the whole pair.

  `--verify` is unchanged and every ledger balances; the seed was refreshed for
  the new builtin, the compiler is at a fixpoint, and the suite is 285/285.

  **One regression, and it is understood.** `string_search` reads **0.90x**. Its
  inner loop calls `str_find_byte_pair`, and every foreign call still materialises
  a `char*` — correctly, but once per call, and LLVM will not hoist the stores out
  of the loop because it must assume the callee writes through the pointer it was
  handed. RUNTIME.md's own contract table says otherwise: `borrow` means "the
  callee reads the argument and does not retain it", which is precisely LLVM's
  `readonly nocapture`. Lowering the contract to those attributes is the fix and
  is not in this change. Of the other 33 workloads, two are faster, 30 are within
  3%, and none is below 0.95x.

  **What is left, measured.** Per 54,000-token pass: Prismio scans in 161 us
  against C++'s 126 us and materialises its tokens in 134 us against 87 us. The
  token half is one `bl _memcpy` per short string — a libc call for a copy of at
  most twelve bytes, which the small-copy ladder musl and Folly both use would
  remove (two overlapping 8-byte loads for 8..12, two 4-byte for 4..7, three
  bytes below that; all in bounds because the source has `count` valid bytes).
  Masking the length to a provable 15 first was tried and did not move the call.

  **And the prefix is still unused.** The top 32 bits of a long string's length
  word are reserved for it and hold nothing. Storing the first four bytes there
  is what the layout is *for* on the comparison side: published microbenchmarks
  put equality at 3-3.5x with the prefix enabled, short-circuiting ~95% of
  comparisons before any dereference. Two equal short strings are already
  bit-identical pairs — the buffer is zeroed before the copy precisely so that
  holds — so `==` between two of them can be two integer compares and no call at
  all.

### Performance

- **The runtime recycles small blocks, and codegen releases through it.**
  `rt_base_alloc`/`rt_free` are functions rather than macros over `malloc`/`free`
  now, and hold freed blocks of up to 128 bytes on eight size-class free lists;
  `g_free_fn` in `runtime/llvm-api-backend.c` names `rt_free` so that a program's
  releases and the runtime's own reach the same pool. **`tokenization` runs
  1.77x faster** — 1,061,708 ns to 600,042 ns, median of 31 alternating runs —
  which moves it from 3.93x of C++ to 2.22x, and from 1.10x of Rust to 0.62x.

  The gap it closes was never in the generated code. With token materialisation
  removed, the same scan runs in 148 us against clang -O3's 149 us; the 54 000
  one-to-eight-byte tokens the workload cuts cost 54 033 mallocs against C++'s
  29, because libc++ holds 22 bytes inline and never reaches the heap. `sample`
  put 67% of the run inside libmalloc's free path and over half of *that* inside
  `mach_absolute_time`, which macOS's allocator calls on every free.

  Three things make it safe rather than clever. Buckets are recovered by asking
  the allocator for the block's usable size, not from a header, so a block from
  `rt_base_alloc` and a block from plain `malloc` stay interchangeable in both
  directions. That query is not cheap — `malloc_size` measures ~14 ns — so the
  held-block cap is tested *before* it, and a shape that gets nothing from the
  pool (build a tree, free all of it at teardown) fills the cap in a few hundred
  frees and skips the query for the rest. And the pool is used only while the
  program is single-threaded: `prismio_task_spawn` publishes
  `prismio_memory_threads_enable()` before the OS can run the new thread, so once
  a second thread exists nothing touches it again.

  `--verify` is unaffected: there the seam is still the two ledger macros, the
  recycler is not compiled at all, and the same program reports the same
  13502/13501 as before.

  **The allocator half stays `malloc` deliberately.** Naming the seam there too
  was tried and reverted: it buys nothing (`struct_creation` and
  `transient_allocation` both 1.00x, because the allocations that benefit are
  made inside the runtime, which already calls `rt_base_alloc` directly) and it
  costs — `malloc` is a name LLVM's TargetLibraryInfo knows, so the call carries
  `noalias` and `allocsize` for free, and `tree_traversal` measured 0.88x with
  the swap against 1.00x without it.

  Across all 34 implemented workloads, alternating against a compiler built from
  the previous commit, no checksum moved. **One regression is real and one
  workload wide:** `tree_traversal` reads 0.946x at both min and p10 over 61
  paired runs. It builds 32 799 nodes and frees all of them at teardown with
  nothing to reuse them, so every free pays the gate's load and branch and enters
  the pool for none of it — about 1 ns per block, which is what the delta divides
  out to. The other readings in that band are noise and were checked rather than
  assumed: `fft` and `graph_bfs` first measured 0.958x and 0.997x, and they make
  38 and 44 allocations in the whole run, so the recycler cannot be what moved
  them; over 61 paired runs `fft` reads 1.003x. Treat +/-4% on a single pass of
  this suite as the floor.

### Developer tooling

- `tools/check_externs.py` asserts that every `extern fn` in `src/`, `std/` and
  `ums/` has a defining symbol in the packaged archives. Six `ir_type_*`
  declarations in `src/ir/bridge.psm` named C functions that did not exist
  anywhere; they are deleted. The check reads `nm` on the built archives rather
  than scanning the C sources, because a regex over `runtime/*.c` reports 40
  undefined names of which 33 are real functions generated by the `BINOP` and
  `CMPOP` macros.
- `build.ums` declares project commands. A `commands` block names commands the
  project owns, each a sequence of steps run in declaration order and stopped at
  the first failure: `build("target")`, `run(subject, args...)`, and
  `shell(...)`. `run` resolves its subject -- a declared target is built and
  executed, a `.py` runs under this host's Python, a `.psm` is compiled into the
  build directory and run -- so a command is portable without the manifest
  branching on the platform. The bare word `args` splices in whatever the user
  typed after the command name, keeping its position among the fixed arguments.
  Built-in commands win: a manifest naming one is rejected when it loads.
- Every repository tool that is not a compiler generation is now Python. The
  `.sh`/`.ps1` pairs for packaging, separation checking, the release gate, the
  release build, the sanitizer smoke suite, and installation collapsed into one
  implementation each, and `tools/install.py` now installs the standard library
  its PowerShell predecessor never copied.
- `src/main.psm` is an entry point again. Import resolution, workload profiling
  and the compile pipeline moved to `src/driver/`, and manifest command handling
  with compiler promotion to `src/project/`, leaving CLI parsing and dispatch
  behind. Emitted code is byte-identical.
- The test runner accepts fixture stems or substrings, including repeatable
  `-k` filters, so one positive or negative test no longer requires a full
  suite run. `--list` prints the available fixtures.
- The compiler repository now has its own `build.ums`; `prismio build` treats
  the compiler as a normal Prismio project and writes the executable below
  `.prismio/build/<profile>/`. Seed bootstrapping remains an explicit toolchain
  operation because it is what creates the first local compiler.
- UMS keeps artifact shape separate from native linkage. Self-hosted Prismio is
  `executable("prismio")` with `component("prismio.backend")`; ordinary targets
  can declare ordered `library`, `search`, `file`, and Mach-O `framework`
  inputs without pretending to be compilers.
- Project metadata now supports optional descriptions, SPDX-shaped licenses,
  project-relative license files, and author lists. UMS array values are a
  reusable flat scalar syntax rather than an authors-only parser special case.
- An optional, first `toolchain { host = "..." }` block selects a project-local
  compiler. Global Prismio reads only that stable prefix, forwards the original
  command when the host is usable, and otherwise processes it as stage 0.
- `prismio aif <source>` now defaults to a source-oriented storage plan with
  numeric allocation IDs; `--why=<ID>` explains one decision and `--manifest`
  preserves the stable tier/symbol form used by compiler tooling and CI.
- `tools/format_sources.py` supplies a conservative repository formatter, and
  `tools/lint.py` checks formatting, Python and shell syntax, Prismio tabs,
  toolchain source-list agreement, and diagnostic-code integrity.
- Compiler errors and warnings now have stable `P####` identifiers in human and
  JSON diagnostics. CI asserts the protocol and rejects duplicate or uncoded
  call sites.
- Linux CI links ownership and concurrency fixtures under AddressSanitizer and
  runs the interleaved milestone benchmark as a regression gate.

### Project commands

`build.ums` is the project manifest, and the CLI now works off it the way
`cargo` works off `Cargo.toml`. A project command is the same command with no
source named: `prismio build` builds the project, `prismio build main.psm`
builds one file.

- **`prismio init [name]`** — scaffolds `build.ums`, `src/main.psm` and a
  `.gitignore` holding `.prismio/`, in this directory or a new one. One command
  rather than Cargo's `new` plus `init`: the only difference between them is
  whether a directory is created first, and the optional argument says that.
  Nothing is written if the manifest already exists. The derived name is checked
  by UMS's own validator rather than a copy of it, so a scaffold cannot be born
  invalid.
- **`prismio run [--release]`** — builds every target, then runs the executable
  one. Refuses when there is no executable target, or more than one.
- **`prismio test [--release]`** — a new `test(...)` target kind. A test is an
  ordinary program that **exits 0 when it passes**; that is the entire protocol,
  because Prismio has no assertion library and a richer contract would be a
  promise the language cannot keep. `prismio build` does not build test targets,
  for the reason `cargo build` does not.
- **`prismio clean [--release]`** — removes this profile's build output, leaving
  the lockfile alone.
- **`--release`** selects the profile; the plan already rooted output at
  `.prismio/build/<profile>/`, but the profile was hardcoded to `debug`.

**An unknown command is now an unknown command.** Any unrecognised first argument
was taken for a source path, so `prismio test` reported `error: cannot read test`
— sending the reader to the filesystem when the answer was the command name.
`prismio foo.psm` still means `prismio build foo.psm`; the shorthand is narrowed
to a path-shaped argument.

**`--version` reports the toolchain**, not just the version: the compiler
directory and the standard library that resolves from here. A compiler developer
has several generations in `build/` and `std` is found by search rather than
configuration, so "what am I compiling against" previously had no answer short of
reading source. `rustc -vV` and `go env` print this for the same reason.

### Fixed

- `import std.*` resolves from any depth. `standardModulePath` searched beside
  the entry file, exactly *one* directory up, and then the toolchain root; under
  the project-local host that root is `.prismio/build`, which carries neither
  `stdlib/` nor `std/`. Every source two or more directories deep therefore
  could not resolve `std.io` — all 32 benchmark corpus programs, reported only
  as "did not build". The search now walks each enclosing directory, bounded by
  a parent that equals its child.
- The host-routing banner (`compiler host: project-local ...`) writes to stderr.
  On stdout it prefixed `aif --manifest` with a human status line and broke that
  format's one guarantee, that its first line is `aif-manifest 1`.
- **A value read out of a parameter is a view of it.** `optionOr(f(), "!")`
  returned `""`: the release for the unbound `Option<String>` temporary was
  emitted between the call and the expression that read its result. `--verify`
  could not see it — both releases were ledger-legal, so the run reported a clean
  `4 allocated, 4 released, 0 leaked, 0 violation(s)` **and** the wrong answer.

  Three fixes, and the first two alone changed nothing: a reference-shaped field
  read now records a view of the object it came from; the AIF walk gained the
  `MATCH_STATEMENT` case it never had, so a payload arm binder is bound to the
  field it reads; and sema types the binder's *node* as well as its name, without
  which the walk could not tell a `String` payload from an `Int` one. Not
  Option-specific — a plain struct field and a concrete payload enum reproduced
  it too.

  The unbound form now leaks rather than dangling, which is the conservative
  direction and what the released 0.1 compiler did. Guard:
  `tests/test_92_field_view_provenance.psm`, which asserts values rather than the
  ledger. See `aif/evidence/RESULTS-field-view-provenance.md`.

### The String surface

`String` gets operators, properties, and a method surface. Every one of them is a
rewrite performed in semantic analysis into the `std.string` call it means, so
overload resolution, the ownership analysis, AIF and codegen meet an ordinary call
and none of them changed. All of it needs `import std.string` — there is still no
prelude.

- **Operators.** `a == b` and `a != b` are content equality; `<`, `<=`, `>`, `>=`
  are the sign of `strCompare`; `a + b` concatenates; `s[i]` is the byte at `i`;
  `s[start..end]` is a half-open slice. `==` on two Strings was previously a hard
  rejection naming `strEquals`.
- **A chain of `+` is one call.** `a + b + c` lowers to `strConcat(a, b, c)`, not
  to nested calls. The nested form leaks its intermediate — 2 allocated, 1
  released, on the released 0.1 compiler as well — so flattening is a correctness
  measure. Up to six parts; past that, `strJoin`.
- **Properties.** `s.length`, `s.isEmpty`, `c.isDigit` — a method call without the
  parentheses. **A property may not allocate**: the rewrite is refused when the
  resolved function returns an owned value, so `s.trim` is an error naming the fix
  while `s.length` is not. A struct field always wins over a property, so no
  existing program changes meaning.
- **`for c in s` and `for x in xs`.** Leaving out the `..` iterates a `String` by
  byte or a `List<T>` by element. The collection is borrowed, not moved. It must be
  a *name*: the loop needs it more than once, and an owned result has to be bound
  anyway. A desugaring over `s[i]`, not an extensible iterator protocol.
- **~35 new methods and functions**, including `slice`, `lines`, `chars`, `bytes`,
  `find`, `get`, `stripPrefix`, `stripSuffix`, `capitalize`, `padCenter`,
  `trimChars`, `insert`, `removeRange`, `equalsIgnoreCase`, `isBlank`, `countIf`,
  `parseFloat`, `parseBool`, `parseIntOr`, `parts.join(sep)`, `impl Char` for the
  `char*` predicates, and `toString` on `Int`, `U64`, `Bool` and `Char`.

The `str*` and `char*` free functions are unchanged and remain supported. The
prefix is not decoration: a method is a free function whose first parameter is the
receiver, so `std.string` now claims 64 unprefixed global names, and a program
defining its own `fn isDigit(c: Char)` alongside it will not compile. Three places
in this tree collided and were renamed. See KNOWN_ISSUES.md.


## 0.1.0

The first release. Prismio is a self-hosted, statically typed, ahead-of-time
compiled language with an inference-driven memory model: you write no `free`, no
lifetimes and no reference counts, and the compiler decides per allocation site
which of six implementation tiers a value needs.

Every code sample in the documentation is compiled by this compiler as part of
the docs build, and the compiler reaches a byte-identical two-generation fixpoint
building itself.

### Language

- Structs, enums with payloads, `Option`/`Result`, optionals (`T?`) with a
  checked `expect`, arrays, `List<T>`, `Slice<T>` views, and `String`
- **Generics** by monomorphisation, with per-specialisation container layout: an
  eligible `List<Flat>` uses inline storage while another instantiation of the
  same template stays boxed
- **Method-call syntax and `impl` blocks** — `x.f(a)` is the call `f(x, a)` after
  the checker's rewrite, so there is no separate method dispatch
- **Traits** with one bound per type parameter, checked statically at the
  instantiation. No trait objects, no vtables
- **Closures**: a struct plus a `call` function resolved by overloading, so no
  function pointer and no indirect call
- **Module namespacing and visibility** — `public`/`private`/`internal`,
  module-qualified calls, and selective imports (`import std.string.strTrim`)
- **Concurrency**: `spawn`/`join`/`Task<R>`, and a blocking typed `Channel<T>`
  whose receive answers `T?`, so a worker loop ends without a sentinel message
- Programmer-directed AoS↔SoA data views

### Memory model

Six tiers, inferred: frame storage, region arenas with automatic placement,
scope-bound ownership, non-atomic reference counting, atomic counting where a
value provably crosses threads, and a cycle collector this corpus omits entirely.
`--verify` checks the inference at run time, `--why` explains one site's tier,
and a differential test runs the whole engine against an independent oracle that
shares no code with it.

### Standard library

Ten importable modules: `std.io`, `std.string`, `std.fs`, `std.process`,
`std.list`, `std.map`, `std.option`, `std.key`, `std.ord`, `std.copy`. `std.io`
is an ordinary import rather than a prelude, so a program that names no I/O
carries none — which is what lets a target with no stdout link at all.

### Toolchain

- macOS, Linux and Windows, with a three-generation bootstrap from a committed,
  target-neutral LLVM IR seed
- Cross-compilation (`--target`, `--sysroot`) with a per-triple runtime archive
- `-g` DWARF describing the layout permutation and hot/cold split truthfully
- A JIT (`--jit`), an object cache, and a curated inlinable runtime module
- UMS package manifest (`build.ums`), lockfile, and local path dependencies

### Performance

Against idiomatic Rust on seven benchmark programs, 25 interleaved runs per arm
with checksum agreement asserted before any timing is read: **0.88×–1.57×**,
ahead on the scene-graph and parallel-bands programs. Written the way an expert
would write it, the same programs run at **0.25×–1.17×** of idiomatic Rust.

### Not in this release

`async`/`await`, an executor, atomics and other synchronization types, and a
specified memory-ordering model. User-written lifetimes, a non-owning typed
pointer (`Ptr<T>` is the first v0.2 pointer item), exceptions, macros, a package
*registry* and version solving, aliased imports, mobile toolchains, and a
formatter, linter or language server.

**WebAssembly is blocked, not in progress.** Prismio emits wasm32 IR, but there
is no C library for `wasm32-unknown-unknown`, so the runtime cannot be built for
it from this repository.

### Known limits

- `Char` is a byte, not a Unicode scalar; there is no string interpolation and no
  iterator protocol
- A heap value is reclaimed where it is bound to a name, so some inline temporary
  shapes still leak; `aif/evidence/` records the ones that are open with the
  measurement that found each
- Diagnostics have source spans and recovery but no stable numeric codes
