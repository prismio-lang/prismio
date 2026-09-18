# Changelog

## Unreleased

### Added

- **`Array<T, N>`: an array whose length is written.** `let m: Array<U32, 16>`
  is sixteen zeroed slots, zeroed where the `let` runs (so again on every
  iteration of a loop body), and needs an element type with a zero. `[T]` and
  `Array<T>` are the same type with the length taken from an initializer, so
  they need one; `Array<T, N>` with an initializer must match it. There is no
  `[T; N]`. A number is accepted as a type argument only by `Array` (`P3006`
  otherwise, including `Vec<T, N>` until chunked vectors exist), and a length
  only on a local `let`, a return type or a struct field -- a parameter takes
  `[T]`. The length is part of the type, which makes an array of a
  known length a value: `let b = a` and `d = c` copy the elements (`memcpy`),
  equal lengths required, while a `[T]` parameter stays a view of the caller's
  array. tests/test_158, neg_162, neg_163.
- **Arrays return by value: `-> Array<T, N>`.** A local or a literal of that
  length is loaded out of the returning frame as an `[N x T]` aggregate and
  stored into a frame slot of the caller's, so `let b = f()` is a copy and
  `f()[i]` and `g(f())` work without a binding. The elements must own nothing,
  the length must match, and a `[T]` parameter's unknown length is refused.
  `-> [T]` is unchanged: only a parameter's view may leave through it. Which
  functions return by value is read off the declaration everywhere -- a generic
  `-> T` bound to an array still returns the pointer it was given.
  tests/test_163, neg_164.
- **Arrays as struct fields: `struct Packet { data: Array<U8, 16> }`.** The
  field is `[N x T]` in the struct's own body. A literal that leaves it out
  zero-fills it and one that names it copies the elements in, length checked
  as an assignment's is; `s.data[i]` reads and writes the struct's bytes;
  `let d = s.data` and `s.data = other` copy; `s.data` passed to a `[T]`
  parameter is a view. A struct of plain fields and array fields is flat, so it
  nests inline in another struct and a `Vec` stores it inline -- one block, not
  a box per element -- and DWARF describes the field as an array. Refused
  (neg_165): elements that own something, a generic struct's array field, any
  array in an enum payload, `soa` of a struct holding one, and a `[T]` field
  with no length. That last one compiled before and was unsound: the field
  pointed into the frame of whichever function built the struct, and a struct
  returned from there read a dead frame. tests/test_164.
- **A scalar element read from an array is a copy to AIF, as a `Vec` element
  read already was.** It used to carry the array's own value set, and an array
  field's is a view of its struct: `sum = sum + t.cells[3]` in a loop sent all
  100,000 structs to the function's arena. And an array literal no longer
  justifies an automatic arena -- it is always a frame slot -- so a loop that
  declares an array stops pushing and popping an empty region per iteration.
- **A Vec removal releases at once when no view of an element can be live.**
  `clear`, `truncate` and `removeAt` on a Vec created in the same function,
  whose elements nothing has read, sliced or lent before the removal -- and, in
  a loop, no view is assigned out of the iteration -- free what they remove
  instead of parking it until the Vec is released. A clear-and-refill loop of
  400 iterations peaks at 208 live bytes instead of 35,102. tests/test_161,
  test_162.
- **`I32` is `Int`.** The parser renames it, so the two are one type and mix
  without a cast; the signed widths now read `I8`, `I16`, `I32`, `I64`.
  tests/test_160.
- **`let items: Vec<Item>` is an empty Vec.** A `Vec` binding with no
  initializer is given `= []` by sema, so its IR is identical to writing it.
  `Vec<T>?` is unaffected. tests/test_159.
- **`x[i] = v` stores.** It type-checked for every collection and generated
  nothing. A `Vec` or `Slice` becomes `list_set` / `slice_set`; an array of
  elements that own nothing stores in place; an array of owning elements, a
  String, a DataView element and a struct's `at` are refused. Assignment now
  lets an integer literal adopt the target's type, as a `let` does
  (`w = 4294967296` into an `I64`). tests/test_156, neg_161.

- **LLVM 23.** The pinned line is 23.1.1 (`PRISMIO_LLVM_EXPECTED_MAJOR`,
  `tools/setup_llvm.py`, the CI matrix). The seed and every program's IR are
  unchanged apart from LLVM's own printing -- `f0x` float literals, and `nosync`
  on the `memory(argmem)` intrinsics -- across all 201 snapshot programs. A
  compiler built for 22 refuses to run on 23, so re-bootstrap from the seed.
  `PRISMIO_HOST_ABI` is `3`, so a launcher rebuilds a project host built for 22
  instead of forwarding to it. Benchmarks: median 0.999x of 22 across the 62
  programs; see `aif/evidence/RESULTS-llvm-23.md`.
- **`List<T>` is `Vec<T>`, and it has methods.** The growable vector is spelled
  `Vec<T>`; writing `List<` is `P3005`, naming the replacement. `std.list` is
  `std.vec`, and the literal `[a, b, c]` lowers to `vecOf`. The rename is
  surface-only -- the type key, `RtList`, the `list_*` entry points, mangled
  symbols and AIF's keys keep the old name, so every program's IR is unchanged
  by it -- and diagnostics and the `aif` report say `Vec`, while `--manifest`
  keeps the `List<...>` key. The methods, per COLLECTIONS.md:
  `push`, `set`, `swap`, `insert`, `reserve`, `truncate`, `clear` and the
  properties `length`, `capacity`, `first`, `last`, `isEmpty`, `isNotEmpty` are
  sema rewrites onto the runtime (no import); `Vec<T>.withCapacity(n)`, `get`,
  `contains`, `indexOf`, `lastIndexOf`, `countOf`, `extend`, `reverse`, `clone`,
  `pop` and `removeAt` are `std.vec` functions. New runtime entries:
  `list_capacity`, `list_reserve`, `list_truncate`, `list_remove_at` and the
  `list_insert` family, with AIF contracts in the compiler and the oracle. An
  `insert` or `removeAt` index out of range is a runtime error.
- **A removed element is released with its Vec.** `pop`, `removeAt`, `truncate`
  and `clear` park an element that owns memory and `list_release` frees it, so a
  removal cannot free what a view taken earlier (`let first = v[0]`) still reads.
  A Vec that keeps removing `String`s holds their memory until it is released;
  releasing at the removal where no view can be live is the next step.
- **`extern let` -- a global variable foreign code defines.** `extern let
  optind: Int` names the storage and every read loads it; `extern let mut` also
  allows assignment. The type is required and an initializer is refused (`P3004`),
  and only a type nobody owns may name foreign storage -- an integer, `Float`,
  `Char` or `Ptr` (`P4111`; `Bool` is refused because a C `bool` is a byte).
  `public`/`internal`/`private` work as on `extern fn`, with the same private
  default. `mut` belongs to each declaration, so one module may read a symbol
  another assigns, and declarations of one symbol must agree on its type. A
  `workload` sees a foreign global as a private zero, as it sees a foreign
  function as a stub.
- **`std.process` reads the arguments without C.** `process.args` names the
  runtime's `prismio_argc`/`prismio_argv` with a private `extern let` and reads
  a slot with the new `__builtin_cstring_at`; `cli_arg_count` and `cli_arg` are
  removed from `runtime/program_support.c`. Behaviour is unchanged, including the
  copy `process.args[i]` returns. The bootstrap seed is refreshed, because
  `std/` now uses the syntax and the old seed called the removed functions.

- **String interpolation.** `"total: ${count} items"`, with any expression inside
  `${...}` and `\$` for a literal one. A lexer mode and a parser rewrite: by the
  time sema sees one it is a `concat` over `show(...)` of each value, so a user
  type interpolates as soon as it implements `Display`. Parts past the largest
  `concat` overload are joined in groups rather than chained, which keeps a long
  interpolation linear in its own length.
- **`0xFF`, `0o755`, `0b1010`.** Hex, octal and binary integer literals. A leading
  zero is *not* octal -- `010` is ten -- because C's rule is the one defect every
  language designed since has declined to repeat.
- **`std.unicode`**: `strDisplayWidth` and `scalarWidth` (terminal columns, East
  Asian Width), `strGraphemeCount` / `strGraphemes` / `strGraphemeWidthAt`
  (what a person calls a character -- a flag, a ZWJ family and a skin-toned emoji
  are each one), `strTruncateToWidth`, `strPadStartDisplay` / `strPadEndDisplay`,
  and `strNormalizeNfc` / `strNormalizeNfd` / `strEqualsNormalized`.
  The range tables are generated from the Unicode database by
  `tools/generate_unicode_tables.py` (Unicode 13.0.0) rather than hand-written,
  and the normalizer is checked against CPython's over 800 comparisons.
  A separate module because it carries 100 KB of tables that a program laying out
  no columns should not build.
- **A program may define a name the standard library defines.** `fn isDigit(c:
  Char) -> Bool` beside `std.string`'s was a *duplicate definition*, because a
  method is a free function whose first parameter is the receiver. Such a symbol
  is now qualified by its module and overload resolution prefers the caller's own
  world, so the program gets its definition and `std.string` keeps calling its
  own. The five operator lowerings -- `concat`, `slice`, `charAt`, `compare`,
  `equals`, and `strLength` for `for ... in` -- are bound to `std.string`
  explicitly, so shadowing one of those names cannot change what `+` means.

- **`strFromFloat`** -- the shortest decimal text that reads back as the same
  double. `Float` was the one type a program could print and parse but never
  convert, so a float could not be joined, written to a file, or built into a
  message. `print(f)`, `Display for Float` and `Float.toString()` all go through
  the same formatter, so none of them can disagree; `strFromFloatFixed(v, n)` is
  the presentation form for a column.
- **UTF-8 as a second reading of a String.** `strIsAscii`, `strIsValidUtf8`,
  `strScalarCount`, `strScalars`, `strScalarAt`, `strScalarWidthAt`,
  `strIsCharBoundary`, `strFromScalar` and `strScalarSubstring`, with methods to
  match. `length`, `charAt` and `substring` stay byte-indexed -- that is what
  makes a scan one comparison per byte -- and these are what user text needs.
- **Range-checked integer parsing.** `strParseI64`, `strParseU64` and the
  `*Radix` forms of all three, each answering `None` rather than a wrapped
  number.
- **Radix formatting**: `strFromIntRadix`, `strFromU64Radix`, `strHex`,
  `strOctal`, `strBinary`, and `toString(radix)` / `toHex()` methods.
- **Scientific notation in float literals.** `6.022e23` and `1e9` did not lex at
  all, which also meant `strFromFloat`'s own output for a large or small value
  could not be typed back into a program.

- **`print` and `println` take several values**, separated by a space:
  `println("x", 1, true)`. A statement rewrite in sema rather than a variadic or
  an overload set -- the call is split into the single-argument calls that
  already existed, so nothing new is imported and nothing new allocates. The
  alternative, a `Display`-bounded generic, would make `std.io` import
  `std.string` and take a hello-world from 5 potential allocation sites to 85.
  A declaration of your own with that arity is called rather than split.
- **`separator(", ")` as the last argument** chooses what goes between them.
  A marker the rewrite consumes, not a function, because a parameter is a name
  and a type and there is nowhere in the grammar for `sep = ", "` to go. It takes
  a literal or a name: the separator is written once per gap, and an owned String
  from a call would be a value nothing names. A program that declares a
  `separator` of its own keeps it.
- `println()` and `eprintln()` with no arguments write the line break on its own.
- **`eprint` and `eprintln` take every type their stdout twins do.** `String` and
  `Int` were the whole of the stderr set; several values in one call is what made
  that a hole rather than a gap, because `eprintln("count: ", n)` splits into an
  `eprint` of the text and an `eprintln` of the value. `prismio_rt_eprint_float`
  and `prismio_rt_eprintln_float` join the runtime pair for `%g`.
- **Starting another program: `Process`, `Child` and `Stream` in `std.process`.**
  `p.program` and `p.arguments` go to the child as an argument vector with no
  shell in between; each of its three streams is inherited, piped or discarded;
  `spawn` returns a `Child` to `wait`, `kill`, read and write, `run` is spawn and
  wait, and `exec` replaces the process. `runCommand` and `quoteArg`, which
  handed a string to `system`, are removed. Environment, working directory and
  redirection to a file are not there yet, and the Windows half has not been
  compiled on Windows -- KNOWN_ISSUES has both.
- **A packaged toolchain can carry the standard library for more than one
  target.** `tools/package.py --target <triple> --sysroot <triple>=<path>` adds
  `lib/runtime/<triple>/` and a code section for that triple to every
  `stdlib/*.plib` (PLIB v3). A cross build takes the section for its own target
  and refuses to build when there is none, where it used to merge the host's
  bitcode with a linker warning nobody read.

### Fixed

- **Storing an element read into a container freed it twice.**
  `list_push(ys, list_get(xs, 0))`, `list_set(xs, i, list_get(xs, j))` and
  `v[i] = v[j]` double-freed any struct or enum literal, and the flat-struct form
  computed a wrong answer. The tier ladder now counts a container element that
  is Shared instead of placing it at T1, a stored view counts as a second
  holder, and the cycle collector defers a buffered root's free to the
  collection (Bacon-Rajan). tests/test_157.
- **Array copies aliased.** `let b = a; b[0] = 9` changed `a` once index stores
  existed; an array of a known length now copies.
- **An array literal in a loop grew the stack.** Its slot was built where
  codegen was, so ten million iterations exited 139 at `-O0`. Every array slot
  is now in the entry block, which is also where SROA can promote it.
- **`let a: [Int]` with no initializer compiled** to an uninitialised pointer;
  it is now an error that suggests `Array<Int, N>`. `let items: Vec<Int>` did
  the same, and the first `push` crashed; it is now an empty Vec.

- **`let v = []` crashed the backend instead of being refused.** An empty
  literal with nothing to take a type from typed as `[Invalid]`, which counted
  as a valid array: codegen emitted `alloca [0 x void]` (a verifier error under
  LLVM 22, a crash under 23), and a call reported that no overload -- or for a
  generic, no function -- existed. It is now `cannot infer the element type of
  an empty literal`, with a note showing both spellings, once per literal.
  Annotations, struct fields and return types still type `[]` as before.
- **A call that failed to resolve typed as Void**, so its real error came with a
  second one -- `expected Int, found Void`, or `expected Vec<String>, found
  Void` after a missing `import std.vec`. It is Invalid now, and resolution no
  longer reports a call whose argument already failed; indexing and slicing an
  invalid value are quiet too. `neg_160` holds all six shapes to six errors.
- **A float add, subtract or multiply of two constants crashed the compiler on
  LLVM 23.** Such an operation folds to a constant, and `contract` was set on
  it through `LLVMSetFastMathFlags`, which assumes an instruction. LLVM 22 wrote
  the bit into the constant and carried on; the flag is now set on instructions
  only, which changes no IR on either version. `0.0 - 2.5` in
  `test_33_unary_operators` and `0.0 - 100.0` in `g4_ecs_world` were the cases.
- **A standard-library struct read its fields one slot late when it came from a
  `.plib`.** A program that set `p.stdout` sent the mode to `stdin`: the layout
  search ordered tied fields by the program's own access counts, and the library
  had been laid out from its own. A `std` struct now keeps declaration order,
  in a checkout too.
- **A struct field that ever held a String literal could free it.** A literal in
  a constructor function, an owned value stored into the same field anywhere
  else, and the generated release handed `.rodata` to the deallocator. Such a
  field now releases nothing -- a leak where there was an abort.
- **A child's stdin pipe never reached end of file**, because the child
  inherited the parent's write end of it; a child reading all its input hung, and
  so did the parent reading its output.

- **A String literal stored into a container was freed at teardown.**
  `list_push(names, "ab")` stored the literal's pair as it was -- an untagged
  pointer into read-only data, even for two bytes -- so the list's release
  handed `.rodata` to the deallocator: 2 violations and an abort for three
  pushes. A literal element is now copied into an inline or owned value first,
  as an assignment already did.
- **A struct's String field freed its text when the string was short.** The
  generated `__aif_release_T` loaded a String field as a bare pointer, which for
  an inline string is its first eight characters, and freed that: a list of
  `struct { name: String, ... }` with short names aborted at teardown releasing
  0x30, 0x31 and 0x32 -- the bytes of "0", "1" and "2". The field is released as
  the whole pair now, so the tag is read.

- **`a.concat(b) == "x"` leaked the temporary.** An ordinary call releases an
  owned argument that nothing binds; `==` lowers to a builtin, which skipped that
  path -- so the operator leaked where the `.equals()` method it is a spelling of
  did not. 1 allocated, 0 released, in a shape string interpolation makes easy to
  write.

- **`strReverse` reversed bytes.** On any string with a multi-byte character in
  it that produces invalid UTF-8 -- not a different string, a broken one. It
  moves scalars now, so the bytes of a character stay in order while the
  characters go the other way.
- **`strPadStart`, `strPadEnd` and `strPadCenter` counted bytes**, so a column
  containing one accented name was a character short. A width is characters.
- **`strParseInt` had no overflow check.** `"99999999999"` came back as a `Some`
  holding a wrapped number -- a parse reporting success and producing a value the
  text does not say.
- **`strParseFloat` was wrong three ways**: a 32-bit mantissa under an
  eighteen-digit guard, so a long number wrapped; a division per decimal place,
  which lands near the nearest double rather than on it; and no exponent case, so
  it could not read back what `strFromFloat` writes. It is `strtod` now, and
  stricter than C: the whole string must be a number, so `"1.5kg"` and `" 1.5"`
  are `None`.
- **An integer literal that does not fit its type is a diagnostic.** It used to
  wrap in silence: `let small: U8 = 999` stored 231, `let n = 4294967296` stored
  0, and `4294967296 as U64` -- a *widening* cast -- produced 0 because the
  literal wrapped as an i32 first. A literal now takes the type it is cast to
  when it fits in one, and `as` keeps truncating when it does not, because that
  is what the explicit narrowing operator is for (`300 as U8` is 44).
- **A `U64` literal above `I64`'s maximum reached LLVM as `I64_MAX`.**
  `const_from_text` parsed every integer constant with `strtoll`, which saturates
  there, so `let n: U64 = 18446744073709551615` was silently 9223372036854775807.

- **Console output links on Windows.** `std/io.psm` declared
  `extern fn write`, which is a POSIX name: the Windows CRT spells it `_write`
  and exports no `write`, so every program that printed left an undefined symbol
  for the linker. The call is `__builtin_console_write` now, and the backend
  picks the symbol and both word widths from the *target triple* -- the same
  mechanism the errno accessor already used, so a cross build asks its target
  rather than its host. `--target x86_64-pc-windows-msvc` emits
  `call i32 @_write(i32, ptr readonly, i32)`; POSIX targets emit the `i64` `write`
  they did before, byte for byte. The `bytes` contract survives the move, so a
  view of the remainder is still not copied on every iteration of the retry loop.
  `write` also leaves `tools/check_externs.py`'s libc allowlist, which closes that
  hole: a builtin carries no declaration to allow.

- **A module-level `let` is private to its LLVM module.** Every module that
  imports one emits its own *definition* of it rather than a reference, which is
  invisible while a program is one module and fatal the moment it is two: a
  program built outside the checkout takes `std.io` from `stdlib/io.plib` *and*
  emits its own copy, and the link failed with `Linking globals named 'STDOUT':
  symbol multiply defined!`. Internal linkage states what was already true. This
  was reachable from any standard-library module with a module-level `let`;
  `std/io.psm` was the first to have one.
- **A stubbed `extern` in a workload driver is declared with its FFI types.**
  `generateExternStub` built the stand-in definition with `storageType` while
  `declareExternFunction` declares the real one with `ffiType`, so a `String`
  parameter became the 16-byte pair in the stub and the pointer half at the call.
  Module verification rejected it — `Call parameter type does not match function
  signature` — and every workload silently fell back to the static profile. It
  was unreachable until an `extern` the runtime does not provide took a `String`.
- `std/io.psm` no longer keeps the two descriptors in module-level `let`s. A
  standard-library module's globals follow every program that imports it, into
  its debug info among other places; two private functions carry the numbers
  instead.
- **`DIGlobalVariable`'s `LocalToUnit` is read off the global's linkage.** It was
  a literal `0` with a comment saying that is what `ir_global_var`'s linkage says
  too — and the two drifted the moment module-level globals became internal,
  leaving debug info that described an internal global as externally visible.
  Asking the value removes the second place the fact was written down.
- **The AIF oracle reported one allocation site for a program that has none.**
  `max(1, ...)` guards the tier percentages against a division by zero and had
  been folded into the reported count itself, so `fn main() -> Int { return 0 }`
  read `sites: compiler=0 oracle=1` in `tools/aif_differential.py`. The guard is
  now only the divisor.
- **The AIF oracle did not know `__builtin_string_view` returns an alias of its
  first argument.** `aifFfiAliasOf` has said so since the view storage class
  landed; `FFI_RETURNS_ALIAS_OF` in `aif/prototype/aif.py` still listed only
  `expect`, so every view read as an opaque extern return — a fresh site, one
  more `extern-alloc` and one more `opaque-ret` than the compiler. This is the
  drift the differential exists to catch, and it was catching it.
- **Four more names the oracle did not know were described.**
  `__builtin_string_eq` was the one that mattered: `==` on two Strings lowers to
  it, so every caller of `equals` — most of `std.string` — appeared to call
  something undescribed, and bracketing was blocked for all of them.
  `list_set_exclusive`, `slice_len` and `slice_set` were the same omission
  without the reach. With these, every `bracketable` / `sole-regime` /
  `br-opaque` counter agrees.

- **The oracle keyed a container's elements on the base type, not the
  instantiation.** The compiler stopped doing that on 2026-08-28 —
  `aif_elem_key` keys on the full spelling (`List<Actor>` apart from
  `List<Order>`) and `elem_key_reconcile` merges a base's keys only where a
  spelling is unresolved (a bare `List`, or `List<Invalid>`). The oracle still
  merged unconditionally, so **every `List` in the program shared one element
  set**: `pt[('field','Token','value')]` held 113 sites of 8 unrelated types, an
  element read came back holding all of them, and A-STORE then inherited Shared
  from an opaque `Ptr` into every `Ums*` struct that had never been near one.
  That was 23 sites reading T3 in the oracle and T2 in the compiler, all of them
  in `ums/`. `elem_key` and the reconcile pass are now mirrored.

  **`tools/aif_differential.py` passes: the two engines agree on all 19
  sources.** They had not agreed on any.
- The three `__builtin_errno*` builtins are described in both AIF
  implementations rather than left unknown. An undescribed callee blocks
  bracketing for its whole caller, and these take no arguments, retain nothing
  and place nothing.

### Language

- **`bytes`, an extern parameter contract about marshalling rather than
  ownership.** A String view has no terminator of its own -- it ends where its
  length says, inside a buffer that continues -- so every other contract hands
  the callee a NUL-terminated *copy* of one. `bytes` says the callee was given
  the count separately and never reads a terminator, so the String's own pointer
  crosses and no copy is made. Ownership is `borrow` exactly, and AIF is given no
  fourth state. Sema rejects it on a non-String parameter (`P4110`).

  It is what makes a retry loop over `write` expressible: the loop advances by
  taking a view of what is left, and under `borrow` that view was copied in full
  on every iteration -- a `malloc` and a `memcpy` of the remainder, per pass. A
  4 MB write measured 14.3 MB peak RSS before and 10.0 MB after, which is the one
  extra copy disappearing.

  **A view bound to a local escapes; one built into the call does not.**
  `__builtin_string_view` aliases its argument's storage on purpose, so
  `let rest = view(text, …)` raises `text`'s escape to Caller and declines every
  caller's drop of what it passed in. Writing the view straight into the call
  argument keeps it Local. This cost a leak in seven suite fixtures before
  `aif --why` named the binding.
- **`__builtin_errno`, with `__builtin_errno_intr` and `__builtin_errno_again`.**
  `errno` is not a symbol on any modern platform: it is a dereference of a
  per-thread location whose accessor libc names itself. Codegen picks that name
  from the *target* triple -- `__error`, `__errno_location`, `_errno` -- and
  emits the call inline, so the program links libc's entry point directly and the
  runtime gains nothing. The two constants are folded for the target, because
  they are C macros with nowhere else to be read from: `EINTR` is 4 everywhere
  this compiler targets, `EAGAIN` is 35 on Darwin and the BSDs and 11 elsewhere.
- **`print` writes the whole string.** `write` returns how many bytes it took,
  and fewer than asked for is an ordinary outcome, not an error: on a descriptor
  someone set `O_NONBLOCK` on -- a property of the open file description, so it is
  inherited across fork/exec and shared by every dup of it -- a 4 MB print
  delivered **65,536 bytes and exited 0**. `prismioStdIoWriteAll` now resumes
  from where it stopped and reissues on `EINTR`, which means nothing was written.

  A descriptor that refuses outright ends the loop rather than spinning: these are
  `write_all` semantics, not `poll`, and `O_NONBLOCK` still needs a poll this
  compiler cannot yet express. A broken pipe never reaches the loop at all --
  nothing ignores SIGPIPE, so the process dies of the signal exactly as `cat`
  does, which is what a filter should do.

  A String of twelve bytes or fewer is the inline form, whose bytes live in the
  pair rather than behind the pointer, so there is nothing to offset and
  `__builtin_string_view` does not apply. That path reissues the whole buffer on
  `EINTR` and does not resume, which is sound because a buffer that small is
  below `PIPE_BUF` on every descriptor type.
- **Console output is Prismio source over `write`, not a C shim.** Every
  `print`, `println`, `eprint` and `eprintln` overload except the two `Float`
  ones now formats in `std/io.psm` and writes to the descriptor itself;
  `prismio_rt_print`, `prismio_rt_println`, `prismio_rt_eprint` and
  `prismio_rt_eprintln` are no longer declared. `%g` has no source-level
  formatter yet, so `Float` stays on `printf`, which is safe to mix only because
  those two flush stdout before returning.

  A `println` of a formatted value is one `write`: the newline is written into
  the same allocation as the digits, so nothing is paid for it. `println(String)`
  is the one overload that has to copy, because its argument is borrowed — and
  the copy is still the cheap half. Against the `printf` path it replaces, over
  300k lines to `/dev/null`: `println(Int)` 0.92x, `println(String)` 0.93x for a
  43-byte line and 0.58x for a 92 KB one. Splitting the line into two `write`s
  instead of copying was measured at 1.80x and rejected.

  `write` is declared with libc's real signature — `Int` is `i32`, so the count
  and the result are `I64`. Declaring the count `Int` compiles and appears to
  work, because writing a 32-bit register zero-extends on both x86-64 and
  AArch64, but neither ABI promises the caller left the upper half clean.
  `tools/check_externs.py` allows `write` by name; it is the only libc symbol
  a Prismio program reaches without a wrapper.

  Formatting stays local to `std/io.psm` rather than calling `std.string`, which
  is not only about link size: an `import std.string` there puts that module's
  allocation sites into the AIF analysis of *every* program that prints. A
  program whose whole body is `import std.io` / `fn main() -> Int { return 0 }`
  reports 5 potential allocation sites; with the import it reported 85, and the
  arena counts in `test_44_aif_region` moved with it.

  The C behind it is gone rather than kept: `prismio_rt_print`,
  `prismio_rt_println`, `prismio_rt_eprint`, `prismio_rt_eprintln` and the
  `print`/`println`/`print_int`/`println_int`/`print_bool`/`println_bool`/
  `print_char`/`println_char` family they wrapped. A program that declared one by
  hand now fails to link naming it; `benchmarks/prismio/common.psm`, which prints
  without importing `std.io` on purpose, declares `write` instead.
- **A jitted module's runtime is checked for identity, not just for
  visibility.** `--jit` resolves the runtime a module calls by searching this
  process, which works or does not depending on how the host was linked, so one
  symbol is looked up up front to tell a missing export table apart from a
  codegen fault. That lookup only asked whether *something* answered. It now
  asks whether what answered is the copy this process itself calls, by comparing
  the address — because a name that resolves into another loaded module is
  found, reports visible, and then corrupts the heap, which is the failure the
  explicit `malloc`/`free` definitions already guard against from the other side
  and which had no diagnostic at all. There is a second note for that case.

  The canary is `str_with_capacity` rather than a console symbol: it is the seam
  every String producer allocates through, so it cannot quietly become dead the
  way `prismio_rt_println` did the moment `std/io.psm` stopped calling it.
- **A String view crossing into C is copied onto the stack, not the heap.** A
  view ends where its length says rather than at a NUL, so handing its pointer
  to a C function needs a terminated copy. That copy was a `malloc`, a `memcpy`
  and a `free`, every time.

  Measured on this compiler compiling itself: **73,735 views per build, 1.3 MB
  copied, 17.6 bytes on average** — 52.7% are 16 bytes or shorter and 99.4% are
  32 or shorter. Nearly all of them are AST names on their way into the symbol
  table, which are views into the source buffer by construction. A 64-byte
  entry-block scratch takes all but 170 of them: **73,735 heap copies became
  170**, and 1.3 MB became 13.5 KB.

  **It is not faster**, and the number is recorded so it is not re-derived: the
  front end reads 0.998x min / 1.001x p50 over 9 interleaved runs, because 73.5k
  allocations is about 0.09% of a 4.1 s compile. What it buys is allocator
  pressure, not wall clock. Nothing else moved with it — the non-view path is
  bit-identical, the benchmark binary is the same size, and 3 of its 98 `bench*`
  symbols changed, all three of them printing helpers outside the timed regions.

  Safe because no callee may retain the pointer: the heap path frees its copy
  the moment the call returns, so anything holding one was already broken.
  `alias` externs never reach this path.
- **The launcher asks a project host which generation it is, and rebuilds it
  when the answer is wrong.** Removing a runtime symbol codegen used to emit
  does not fail where it is removed: it fails in the *previous* compiler, which
  is still emitting the call and now links a runtime without the definition.
  Dropping `list_set_elem_inline` for the immutable list-layout constructor did
  exactly that, and `prismio build` in this repository stopped being able to
  build its own replacement — an `Undefined symbols for architecture arm64` list
  naming `strChars`, `generateExpression` and six other *generated* functions,
  with nothing in it pointing at the compiler that emitted them.

  `PRISMIO_HOST_ABI` (`runtime/prismio_runtime.h`) versions the pairing, and
  the hidden `prismio --internal-host-abi <token>` reports it. A host that
  disagrees exits 1; one that predates the command rejects the argument and also
  exits 1, which is why nothing had to be back-ported for this to work on the
  generation it was introduced to catch. On disagreement the launcher rebuilds
  *only* the `toolchain.host` target with itself, re-asks, and then forwards the
  original command (`P1064`, `P1065`, `P1066`). `clean` is exempt — the launcher
  deletes that host immediately afterwards.

  The compatibility export survives one generation, under
  `PRISMIO_BOOTSTRAP_COMPAT`, in compilers built from repository sources.
  Packaged runtime bitcode does not contain it, so no user program observes
  anything but the constructor ABI.
- **Building a `toolchain.host` builds the toolchain, not just the compiler.**
  A compiler is a layout, not a file: it resolves runtime bitcode at
  `<exe>/../lib/runtime` and compiled standard modules at `<exe>/../stdlib`.
  Since the runtime became installed bitcode with no source fallback, the
  project host could build *itself* — bootstrap compiles `runtime/*.c` from the
  checkout — and could not build one user program. Every benchmark, corpus
  program and fixture pointed at it failed with `Missing runtime module`, naming
  an installation the developer had never installed.

  `prismio build` now writes `.prismio/build/lib/runtime/*.bc` and
  `.prismio/build/stdlib/*.plib` beside the host it promoted, in the shape an
  install has, so nothing in the resolver had to learn a new layout — and a
  `std/` or `runtime/` edit reaches the next program the project builds, which
  is the reason to pin a host at all. Measured at 1.9 s on a host build of about
  20 s, and the artifacts are byte-identical to `tools/package.py`'s for the same
  compiler; `run_ums_test` imports the packaging code and compares bytes, because
  two producers of one format is a drift neither side can see.

  `tools/run_suite.py` copies that layout rather than the binary.
  `benchmarks/run.py` also pins `PRISMIO_INTERNAL_HOSTED`: a `--compiler` whose
  file is named `prismio` was being forwarded to `toolchain.host`, so the numbers
  came from a binary other than the one named, and checksums cannot catch that —
  both compilers are correct.
- **That build is incremental: an artifact whose inputs did not move is not
  built again.** The emission above ran in full on every `prismio build` of a
  project host — four clang invocations for the runtime and, per standard
  library module, two compiler runs and two more clang runs — to reproduce, byte
  for byte, the files already on disk. Measured here at 1.50 s of an 8.24 s
  self-build; an unchanged rebuild now spends 0.23 s and the whole build takes
  6.90 s.

  `.prismio/build/lib/toolchain.stamp` records what each artifact was built
  from, one `<name> <key>` line each. The runtime key is the hash
  `lib/runtime.hash` already records — so a reuse and the `P1004` staleness
  guard cannot disagree about whether the bitcode matches `runtime/` — plus the
  clang that compiles it, by path, size and mtime. That last part is size and
  mtime rather than content deliberately: clang is a binary this build did not
  produce, hashing it every time would cost more than the four compiles the key
  guards, and an in-place LLVM upgrade is precisely the gap the object cache's
  own comment records as one nothing notices.

  A PLIB's key is its `std/*.psm` source and *the compiler's own bytes*, because
  the emission is literally `<compiler> build std/<module>.psm`: the binary is
  the dependency, and it is the one key that covers a changed codegen, a changed
  `--verify` lowering and a changed PLIB container format at once. So a
  `runtime/*.c` edit rebuilds four `.bc` files and no PLIB, a `std/list.psm`
  edit rebuilds one PLIB and no bitcode, and a `src/` edit rebuilds every PLIB.
  A link that is not byte-reproducible costs hits and nothing else.

  Existence is checked separately from the key: a deleted `.plib` is not a stale
  one, and its inputs have not moved. `PRISMIO_TOOLCHAIN_CACHE=0` bypasses the
  lookup and still writes the stamp, so one bypassed build does not cost the
  next one its hits; `PRISMIO_TOOLCHAIN_CACHE_TRACE=1` prints one
  `[toolchain reused|rebuilt] <name>` line per artifact, which is what
  `run_ums_test` asserts against — "the build was faster" is not an observation
  a test can make on a shared host, and an mtime cannot tell a file that was not
  rewritten from one rewritten with the same bytes.
- **The launcher says which toolchain it used.** `Using local toolchain: <path>`
  when it forwards to `toolchain.host`, `Using global toolchain: <path>` when it
  cannot and handles the command itself — replacing `compiler host: project-local`
  / `compiler host: stage-0`, which only ever appeared on the forwarding side. A
  manifest that declares a host has asked for a specific compiler, and silently
  substituting the global one when that compiler is missing, unrunnable or too
  old is how a project ends up built by something it did not choose. A manifest
  with no `toolchain` block has made no such choice and is told nothing.
- `std.io` gains `eprint(Int)`. Status lines count things, and the compiler
  reports how many standard-library modules it rebuilt.
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

### The view storage class

- **A substring longer than the pair can hold is now a view, not a copy.** Umbra's
  third storage class: the pair holds a pointer into the string it was cut from
  and a length, with no allocation, no copy and nothing to release.
  `strSubstring` and `String.slice` take it whenever `count > 12`, which is
  exactly when the alternative was a `str_with_capacity` and a byte loop.

  **The lifetime is proved, not promised.** Umbra's advice for a transient string
  is "copy it if you need it later"; here `__builtin_string_view` is declared an
  alias of its first argument (`aifFfiAliasOf`), so the result carries the base's
  sites and the ownership analysis already keeps the base alive for as long as
  the view is — the same fact `aif_fn_may_return_view_of_param` was introduced
  for. Nothing new had to be inferred.

  Three places pay for it, and only three. A view has no terminator of its own —
  it ends where its length says, inside a buffer that continues — so equality
  compares by length (`str_equals_n`) rather than by `strcmp`; `str_own` copies
  one entering a container, by length rather than with `str_clone`; and a view
  crossing into C gets a NUL-terminated copy that is released as soon as the call
  returns. Everything else is unchanged: byte access already reads through field
  0, and the release already answers "not mine" from the tag.

  **`tokenization` runs 1.30x faster again** and now sits at **0.81x of C++** and
  0.23x of Rust — 218,042 ns against C++'s 269,375, median of 31 alternating
  runs. Most of that is not the tokens themselves, which are all twelve bytes or
  fewer and were already inline: it is that `strSubstring` no longer contains an
  allocation on any path, so it inlines whole into its caller and the release
  disappears with it.

  Across all 34 workloads: one 1.31x faster, 31 within 3%, and `fft` and
  `knapsack` at 0.91x and 0.90x — both verified as pure code layout, with
  byte-identical instruction sequences in both builds and only their addresses
  moved. Suite 285/285 with the compiler self-hosting on views, fixpoint reached,
  `--verify` clean.

  One bug worth recording: the temporary release was emitted as a literal
  `rt_free`, which links in a release build and fails under `--verify` with
  "Undefined symbols: _rt_free", because the runtime compiles `rt_free` as a
  macro there. It goes through `g_free_fn` now — the seam exists so that both
  halves of a pairing swap together, and a temporary release is a release like
  any other.

### String performance, third pass

- **`s = s + a + b` appends in place.** A two-part `s = s + x` already reused an
  owned accumulator's buffer; a longer `+` chain took the immutable concat and
  copied the whole accumulator on every iteration. `str_append_reuse_many` grows
  the base once for the chain's total and appends every suffix, rebasing any that
  points into the old buffer -- `s = s + x + s` has to read its second `s` from
  where the first append left it, which is why a chain is one call and not one
  per suffix. `s_expression_parse` builds 96 KB in 1,600 such appends: its build
  phase went from 3.00 ms to 0.80 ms (C++ `+=`: 0.93 ms), and the benchmark is
  **2.6x faster** (0.374x, median of 15 alternating runs).

- **A short-needle search is one runtime call.** `strIndexOfFrom` picked its two
  rare needle bytes in Prismio through an out-of-line rank function -- six calls
  for a six-byte needle -- and crossed into the runtime once per candidate.
  `str_find_needle` does the selection, the packed-pair scan and a `memcmp`
  verify in C, and answers "continue with Two-Way from here" when candidates turn
  dense, so the worst case stays linear. With the crossing gone the density
  window is memchr's 50 candidates rather than 4. `string_search` **0.73x**
  (median of 15).

- **`strJoin` reads each part once.** Its copy loop called `list_get` per byte,
  and a String read out of a container slot was measured with `strlen`: 2.6
  million calls joining 240,000 parts. `string_join`'s join phase went from
  2.83 ms to 0.95 ms (C++: 1.06 ms), and the benchmark is **0.73x**.

- **A `List<String>` stores the 16-byte pair itself.** A slot was one word: every
  short String was copied to the heap on the way in (`str_own`) and every read
  measured its length back with `strlen`. Interposed on the suite, `sort_strings`
  made 5,748,630 `strlen` calls and 80,029 mallocs for 80,000 elements of at most
  twelve bytes; it now makes 190 and 29, and `string_join` went from 2,612,792 and
  240,030 to 190 and 30 -- what libc++'s small strings in a `vector<string>` save
  C++. A typed `List<String>` is born with `elem_size == 16`; reads and writes go
  through curated runtime calls that take and answer the pair as two halves,
  because a 16-byte struct return is a hidden pointer on Windows x64. Teardown
  frees an owned long form and skips an inline one (`AIF_ELEM_STRING`, codegen's
  refinement of OBJECT). A list born with no element type still reaches code
  typed `List<String>`, so every entry point keeps the old path for it. Phases,
  minimum of nine alternating runs: `sort_strings` build 1.83 -> 1.06 ms (C++
  1.69), `string_join` build 3.86 -> 1.69 ms (C++ 2.62) and join 2.86 ->
  0.60 ms (C++ 1.10). Leaks shrank with it, because short strings no longer
  allocate: 112 leaked -> 8 on `test_141`'s shapes.

- **`strSplit`, `strSplitOn`, `strSplitWhitespace` and `strLines` keep a part of
  twelve bytes or fewer in the pair** instead of allocating it, which now costs
  nothing to store in the list they return.

- **`strClone` keeps twelve bytes or fewer in the pair too.** A `Map<String, V>`
  stores its keys through it (`copyOf`), and a heap copy of a short key never
  matched the inline key it was looked up with bit for bit, so every successful
  probe fell through to `memcmp`. With the split change, `word_frequency` went
  from 20,876 mallocs and 47,992 `memcmp` calls to 57 and 0.

- **`sort` is pattern-defeating quicksort.** The three-way quicksort it replaces
  was pathological on ordered input: 80,000 already-sorted Ints took 16.6 ms and
  reversed ones 12.2 ms, against 4.1 ms random. pdqsort's partial insertion sort
  after a partition that moved nothing makes both near-linear -- **0.086 ms and
  0.141 ms** -- and random input is 0.83x. Duplicates keep the property the
  three-way partition was chosen for: a pivot equal to the element before its range
  takes the equal-to-the-left partition, so an all-equal list is linear.
  Unbalanced partitions are counted and fall back to heapsort after log2(n), so
  the worst case is O(n log n), and both scans are bounded, so an ordering that is
  not a strict weak order leaves an unsorted permutation rather than a read past
  the end. The pivot stays in its slot for the whole scan, which is what keeps it
  valid for an inline element.

- **Together, against the suite binary before this pass** (15 alternating runs,
  checksums equal): `string_join` **0.34x**, `s_expression_parse` **0.38x**,
  `word_frequency` **0.45x**, `sort_strings` **0.70x**, `string_search` **0.71x**.
  Against C++ in a full `benchmarks/run.py` pass they moved from 1.62x, 1.99x,
  1.53x, 2.03x and 1.31x to **0.63x, 0.71x, 0.70x, 1.45x and 0.96x**. A
  per-function mnemonic diff of the two suite binaries shows 30 of 504 functions
  changed, every one of them string, list, map or sort code; the benchmarks whose
  code did not change stayed inside the suite's layout floor.

### String performance, second pass

- **The small-copy ladder replaces `memcpy` in the short-string constructor.**
  `ir_str_inline` was calling libc for a copy of at most twelve bytes, once per
  short string. It now uses the shape musl and Folly both use below their vector
  thresholds: read the first word and the last word and store both, overlapping
  in the middle. Three cases (8..12 as two i64, 4..7 as two i32, 1..3 as three
  bytes), every load inside the source range by construction, and the union of
  what each writes is exactly `[0, n)` so the zeroed tail survives — which the
  equality fast path below depends on. **1.107x on `tokenization`**, verified
  against a byte-by-byte reference at every length and offset (403 slices).

- **String equality answers from the pair.** Two short strings are equal exactly
  when their sixteen bytes match, so `==` is two integer compares with no
  dereference and no call; unequal lengths are rejected from the pair too, and
  `str_equals` is reached only when the lengths agree and at least one side is
  long. Measured at **48x** on a short-string comparison loop — 193 us against
  9.35 ms for four million compares. `String.equals` is one line now instead of a
  byte loop: the note saying it could not use the builtin because the seed did
  not know `__builtin_string_eq` stopped being true when the seed was refreshed.

  **The four-byte prefix German strings carry is deliberately absent.** A prefix
  has to be computed when a string is complete, and a Prismio long string never
  is at any single point — `str_with_capacity` hands back an uninitialised buffer
  and the caller fills it. A database materialises a value once and can stamp a
  prefix on the way; a language that lets you build one incrementally has nowhere
  to put that hook.

- **`borrow` lowers to LLVM `readonly`.** RUNTIME.md's contract table has always
  defined it as "the callee reads the argument and does not retain it", and that
  is what LLVM spells `readonly nocapture`; without saying so, a foreign call is
  assumed to write through every pointer it is handed. Measured on the shape it
  targets — a short haystack searched in a loop, where the materialisation is
  loop-invariant and only the assumed writes pin it — at **min 5.28 ms to
  4.84 ms**. It does not show on the suite, because `string_search`'s haystack is
  long and already resolved once at the parameter. (`nocapture` is spelled
  `captures(none)` in LLVM 22 and does not map through the C API's enum lookup;
  `readonly` is the half that matters here.)

- **Together: `tokenization` is 1.078x faster again, and now runs ahead of C++**
  — 274,042 ns against 278,375, median of 31 alternating runs, from 1.06x at the
  start of this pass. Against Rust it is 0.28x. Per 54,000-token pass with the
  text hoisted, the token half is now 103 us against C++'s 91 us; the scan is
  160 us against 129 us, and that 30 us is now 71% of everything still separating
  the two.

  **Two scan-gap hypotheses were tested and both are wrong.** Putting the
  short-string materialisation behind a branch, so the long form reaches its load
  with no store on its path, measured **328 us against 262 us** — the control flow
  costs more than the stores it avoids, and it is reverted. And `charAt`'s bounds
  check, which C++ does not pay, is free: swapping it for the unchecked `byteAt`
  over the same 204 KB reads 229/214, 229/229, 194/194 us, because LLVM proves
  the index from the loop guard.

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
