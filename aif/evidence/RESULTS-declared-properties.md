# Properties are declared: `prop`

**Status: GREEN, 2026-09-25.** Fixpoint `257d4001`, reached from the refreshed
seed over three generations; suite **419/419** (new test_187, neg_191, neg_192);
every other program's IR byte-identical to the compiler before (236 programs:
only the compiler, test_181 with one check removed, and the new fixtures differ);
both doc apps' gates green (237 + 50); IntelliJ plugin compiles and its tests pass.

## The rule before

`s.length` was rewritten to `length(s)` for any one-argument function that did
not allocate, so both `s.length` and `s.length()` were legal, `x.sqrt` read as a
field, and whether a name could be written without parentheses depended on its
body -- a property that started allocating would stop compiling at every use. The
tree had both spellings: 32 `.length()` against ~280 `.length`.

## The rule now

- `prop name(self) -> T { ... }` declares a property, at top level or in an
  `impl`, with a visibility marker like `fn`. `prop` is contextual (directly
  before a name in declaration position), so `let prop = 5` still compiles.
- A property is read only without parentheses and a method only with them:
  `s.length()` is "`length` is a property, not a method", `s.trim` is "`trim` is
  a method, not a property", each with the fix as a note. A plain `length(s)` is
  not checked -- desugarings synthesise calls that way, and a property is a
  function underneath.
- A property must take only its receiver, return a value and not allocate,
  checked at the declaration.
- The collections' compiler-provided properties (`length`, `capacity`, `first`,
  `last`, `isEmpty`, `isNotEmpty`) follow the same rule: `v.length()` is an error.

Mechanics: the parser marks FUNCTION.i1 = 4 (`nodeIsProperty`; codegen clears
that slot before its own use), sema records how a call was spelled on the callee
identifier's `i3` and checks it against the declaration overload resolution
chose (`semaCheckPropertySpelling`).

## Which std functions are properties

Reads that describe a value, not computations or actions: String `length`,
`isEmpty`, `isNotEmpty`, `isBlank`, `first`, `last`, `scalarCount`, `isAscii`,
`isValidUtf8`, `displayWidth`, `graphemeCount`; Char `isDigit`, `isAlpha`,
`isAlnum`, `isSpace`, `isLower`, `isUpper`, `digitValue`, `code`; numbers
`isEven`, `isOdd`, `isPowerOfTwo`, `isNan`, `isInfinite`, `isFinite`; platform
`current`, `architecture`, `environment`, `isLinux`, `isMacOS`, `isWindows`;
process `pid`, args `count`, a stream's `isOpen`. Math operations
(`sqrt()`, `abs()`, `sign()`), conversions and actions stay methods.

## Landing

std uses `prop`, and the seed compiles std, so the seed was refreshed from the
new compiler in the same change (tools/refresh_seed.sh) and verified by a
three-generation bootstrap from it. 71 call sites in tests, benchmarks and the
sandbox, 7 in src/, 5 in test_runner.py's inline programs and 36 in the docs
were respelled; test_148's own `count` became a `prop`.

## Still open

A trait cannot declare a property (KNOWN_ISSUES.md). `o.isSome` on a generic
`Option` still cannot be written as a property, for the older reason that a
generic template is not in the declaration index.
