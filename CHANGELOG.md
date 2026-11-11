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

### Changed

### Fixed

### Repository

### Documentation
