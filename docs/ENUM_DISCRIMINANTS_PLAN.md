# Enum discriminants, struct variants and `codeset`

The spec: tagged enums with an optional representation type (`enum E: U16`), explicit and implicit
discriminants, struct variants (`Move { x: Int, y: Int }`), unique-discriminant enforcement, and
`codeset` for numeric constants that may alias. Items are in the order to do them.

## Where things live

| Concern | File |
|---|---|
| Parsing `enum`, variants, `: Repr`, `= value`, struct variants, `codeset` | `src/parse/enums.psm` |
| AST shape (fields below) | `src/ast/nodes.psm` |
| Evaluating, assigning and checking discriminants (every diagnostic in the spec's table) | `src/sema/enum_discriminants.psm` |
| `codeset`: declaration, `Status.Ok` as a typed constant | `src/sema/codeset.psm` |
| Payload desugaring to a tagged struct, construction, `match` | `src/sema/enums.psm` (unchanged in role) |
| Registering variant values with the backend | `src/ir/module.psm` (`registerEnumDecl`) |

`enums.psm` asks `enum_discriminants.psm` for a variant's tag; it does not evaluate anything itself.

## AST

`ENUM_DECL`: `child1` variants, `child2` the representation annotation (absent when not written).
`ENUM_VARIANT`: `child1` payload types, `child2` the discriminant expression (absent when not written),
`child3` field names of a struct variant (parallel to `child1`), `i1` = 1 for a struct variant.
After `enumAssignDiscriminants`: `s2` the discriminant as decimal text, `i3` = 1.
`CODESET_DECL` has the same shape, its entries `ENUM_VARIANT`s that may not carry a payload.

The discriminant is **text**, because `Int` is i32 and a `U64` discriminant does not fit a node field.
Arithmetic is `U64` magnitude plus a sign, range-checked by `typeIntLiteralFits`.

## Rules the code must keep

- An enum that writes neither a representation nor a discriminant compiles to **exactly** what it did
  before: ordinals from 0 for fieldless, one-based `$tag` for payload. No existing program changes.
- Implicit numbering continues from the previous variant's value; it never searches for a free one.
- A tagged enum's duplicate is an error naming both variants. A `codeset` may alias.
- No silent wrap: an implicit value past the representation's range is an error at the variant.

## Status

Done: parser, numbering and all diagnostics, `codeset`, storage width (fieldless and payload tags),
struct-variant construction and patterns, docs in both apps, `CHANGELOG.md`. The seed was re-cut and is
left uncommitted.

Open:
- The IntelliJ plugin knows `codeset` since 2026-10-29 (keyword, declaration kind, entries coloured like variants); `: Repr` on an enum and struct variants reach the editor with the toolchain (the language server).
- A `codeset` may leave its representation type out: the smallest integer type that holds every entry is used.
- A *payload* enum is still not a `Map` key without hand-written impls (derived `Copy`/`Eq`/`Key` are
  for fieldless enums, `driver/derived_impls.psm`).
- `aif_verify` fails on `test_273`/`test_269`, as it did before this work (see `NUMERIC_TYPES_PLAN.md`).
