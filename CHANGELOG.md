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
- **Editor support for the new syntax.** The semantic index nests a struct written inside another under its owner and finds
  its fields by path (`win.size.w`), indexes a pattern's new name (`y: why`), prints a tuple as `(Int, String)` (in hover,
  hints and the compiler's messages), and completes the structs inside `Window.`. The VS Code grammar and the JetBrains lexer
  needed no change; both have tests for the new spellings.

### Changed

### Fixed

- `prismio fmt` joined `, ..}` in a destructuring pattern into `,..}`.

### Repository

### Documentation
