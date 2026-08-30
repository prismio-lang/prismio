# The String surface: operators, properties, iteration

What was added, what it cost, and the two measurements that decided the design.

## What landed

Five operators, properties, collection iteration, and ~35 library additions. Every
operator is a rewrite performed in `semaExpr` into the `std.string` call it means,
so overload resolution, the ownership analysis, AIF and codegen were not touched.

| Feature | Spelling | Lowers to |
|---|---|---|
| equality | `a == b`, `a != b` | `strEquals`, negated |
| ordering | `a < b` and the other three | sign of `strCompare` |
| concatenation | `a + b + c` | **one** `strConcat(a, b, c)` |
| indexing | `s[i]` | `strCharAt` |
| slicing | `s[a..b]` | `strSlice`, half-open |
| property | `s.length`, `c.isDigit` | the one-argument call |
| iteration | `for c in s`, `for x in xs` | the range loop over `s[i]` |

| File | Lines |
|---|---:|
| `std/string.psm` | +632 |
| `src/sema/checker.psm` | +469 |
| `src/sema/types.psm` | +21 |
| `src/common/text.psm` | +21/-19 (rename) |
| `src/parse/stmt.psm` | +10 |
| `src/lexer/scanner.psm` | +4/-4 (rename) |

## Measurement 1 — the `+` chain had to be flattened

The first implementation lowered `+` pairwise, as `strConcat(strConcat(a, b), c)`.

```
let j = "Hello" + ", " + "World"
  pairwise:   2 allocated, 1 released, 1 leaked
  flattened:  1 allocated, 1 released, 0 leaked
```

The leak is not new and not from the operator: the same shape written by hand,
`strConcat(strConcat("Hello", ", "), "World")`, reads `2 allocated, 1 released`
**on the released 0.1 compiler** (`build/v0.1-rc`). RUNTIME.md 3.1 is the rule —
an owned result passed straight into a parameter is a value nothing names.

Lowering pairwise would therefore have made the obvious spelling of the obvious
operation leak once per `+`. Flattening the whole spine into a single call removes
the intermediate rather than leaking it, and copies each byte once instead of
twice. `strConcat` gained 3-, 4-, 5- and 6-part overloads; past six the compiler
refuses and names `strJoin`.

The flattening has to run **before either operand is typed** — typing the left
operand of `a + b + c` rewrites the inner `+` into its call, after which the spine
is no longer visible. That ordering was the actual bug in the first attempt: the
code was correct and sat three lines too low, and the ledger still read 2/1.

## Measurement 2 — a property may not allocate

`s.length` reading as a field is right. `s.trim` reading as a field is a trap: it
allocates, and the language then requires the result to be bound. So the rewrite
is refused when the resolved function's declared return type is move-only:

```
error: property `trim` returns an owned value, so it allocates; call it as a
       method instead
  note: a property must not allocate -- write `()` after the name
```

The return type is read from the declaration rather than by typing the rewritten
call, so the refusal happens before any node is modified — rewriting first and
complaining afterwards reports once per pass of overload resolution over the
enclosing call.

This rule needs no new keyword, which is why it was chosen over a `prop` marker: a
marker could not have been used in `std/string.psm` until the committed seed
understood it, and CODE_STYLE's two-step would have made this a two-release
feature.

## The cost: 64 claimed global names

A method is a free function whose first parameter is the receiver, so
`impl Char { fn isDigit(self) }` declares `isDigit(Char) -> Bool` globally. Three
places in this tree collided immediately:

| Collision | Resolution |
|---|---|
| `src/common/text.psm` `isAlpha`/`isAlnum` | renamed `isIdentStart`/`isIdentPart` — they accept `_`, so they were never the same predicate |
| `std/list.psm` generic `allOf`/`anyOf` | the String methods became `allChars`/`anyChars`; two generic candidates could not be resolved and `test_89_closures` stopped compiling |
| `aif/evidence/xlang/prismio/g7.psm` | renamed `tok*`, bodies untouched so the benchmark is unchanged |

Overloading by parameter type absorbs the rest — `first(Slice<T>)` and
`first(String)` coexist, as do `slice(Lexer, …)` and `slice(String, …)`. A
collision needs the same first-parameter type. An exhaustive scan of all 289 `.psm`
files in the tree found no others. See KNOWN_ISSUES.md.

## Found while building this, not caused by it

An unbound `Option` that owns a String reads back **empty**:
`optionOr(s.stripPrefix("x"), "!")` answers `""`. Releasing the temporary releases
the String while the returned alias into that field is still live.

```
working tree:   4 allocated, 4 released, 0 leaked, 0 violation(s)   -- and prints ""
build/v0.1-rc:  4 allocated, 1 released, 3 leaked                   -- and prints "abc"
```

The released compiler leaked it; the working tree's ownership changes turned that
leak into a silent wrong answer, and `--verify` cannot see it because both releases
are ledger-legal. A balanced ledger is not evidence here. KNOWN_ISSUES.md carries
the reproducer.

Separately, RUNTIME.md 3.2's warning against binding a container's element no
longer reproduces for the loop case: `let p = list_get(parts, i)` over a
`List<String>` reads `5 allocated, 5 released, 0 violation(s)`. That is what makes
`for p in parts` safe to desugar to an element binding, and it is why the
desugaring builds an `INDEX_EXPR` rather than calling `list_get` directly — the
index path carries `ir_unmark_list_exclusive`, the bookkeeping that makes it safe.

## Verification

| Check | Result |
|---|---|
| `tests/test_runner.py` | 156/156, including the new `test_91_string_ergonomics` |
| `test_91` under `--verify` | 28 allocated, 28 released, 0 leaked, 0 violations |
| Two-generation fixpoint | gen2 and gen3 emit byte-identical compiler IR |
| `bootstrap.sh --seed` | builds — a fresh checkout still bootstraps |
| Doc examples (`../docs`) | 157 compiler-checked snippets pass, up from 146 |
| Compiler binary | 1 753 768 → 1 794 216 bytes (+2.3%), no dead-function elimination |

The binary growth is the whole `impl` surface being linked into every program that
imports `std.string`, the compiler included. It is the cost the `impl` block's own
header predicted, and it is why the method set is curated rather than exhaustive.
