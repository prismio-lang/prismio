# Changelog

This file records what is changing in **0.3.0**, the release being prepared. It does not carry earlier
releases: those are on the [release notes page](https://docs.prismio.org/releases). The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/) (pre-1.0, so a minor release may still break things).

## [0.3.0] - Unreleased

### Added

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
- `prismio fmt` joined `, ..}` in a destructuring pattern into `,..}`.

### Repository

- **`float_sum` and `float_dot` hosted benchmarks** (Prismio, C++, Rust), each 20 passes over 1M doubles, written
  plainly in all three languages. Their values are small multiples of 1/8 and 1/16, so every grouping of the sum is
  exact and the arms agree to the bit whether or not a compiler splits it into SIMD lanes.

### Documentation
