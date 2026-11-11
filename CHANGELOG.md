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

### Changed

### Fixed

### Repository

### Documentation
