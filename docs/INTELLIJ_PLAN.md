# IntelliJ plugin: what the compiler has gained that the plugin does not know yet

> **2026-10-26:** the plugin is moving onto the language server (`prismio lsp`, docs/LSP_PLAN.md), after which this
> file stops being a backlog: a language change reaches the editor with the toolchain. Switched over so far:
> diagnostics and the import quick fix (the external annotator, `PrismioCheckTarget` and `UmsValueChecks` are deleted), and
> (2026-10-28) hover, inlay hints, parameter info and completion (`documentation/`'s provider, `hints/`,
> `PrismioParameterInfoHandler` and `completion/` are deleted). Still the plugin's own Java, in the order they are to go, one
> package per commit with the server's feature switched on in `PrismioLspFeatures.SERVED`: `navigation/`, `symbols/`,
> `imports/`, the formatter. Items below that concern those packages need no work once they are gone.

The plugin (`../jetbrains-plugin`) has hand-written lexers and scope scanners, so each language change
needs a matching edit there. `NumericWidthTypesTest` and the corpus test are what catch drift. Items are
in the order to do them; each names the file to change.

## Enum discriminants, representation types, struct variants, `codeset` (compiler 0.2.0)

Compiler side: `docs/ENUM_DISCRIMINANTS_PLAN.md`, `docs/language/enums` in the docs site.

1. **`codeset` is a contextual keyword**, like `type` and `prop`: a declaration only when an identifier
   follows. Highlight it as a keyword in that position and never otherwise.
   - `lang/PrismioWords.java` -- contextual-keyword set
   - `lexer/PrismioLexer.java` -- classification at declaration position
   - `completion/Keywords.java` and `completion/CompletionPosition.java` -- offer it at top level, and
     after `public` / `private` / `internal` (the compiler accepts `public codeset`)
   - `navigation/DeclarationKind.java` -- a `CODESET` kind (structure view, goto, icons), brace depth 0
   - `folding/PrismioFoldingBuilder.java` -- fold its body like `enum`
   - `resources/liveTemplates/Prismio.xml` -- a `codeset` template beside `enum`
2. **`enum E: Repr { ... }`**: a `:` and an integer type between the name (or its generic parameters)
   and `{`. The scope scanner must not read `: U16` as the start of a body, and the annotator should
   resolve `U16` as a type there.
   - `navigation/PrismioScopeResolver.java` (the `enum` branch at the declaration scan)
   - `annotator/PrismioAnnotator.java` (`isInsideDeclarationBody(element, "enum")`: the header is not the body)
3. **Variants with `= expr`**: after the name, the payload, or the `}` of a struct variant. The expression
   is a constant (`1 << 3`, `400 + 18`). Inside an enum or codeset body, a variant name is a declaration,
   not a reference; the number after `=` is an expression.
   - same two files; `completion/` should offer no variant names after `=`
4. **Struct variants**: `Move { x: Int, y: Int }` inside an enum body is a nested brace block. Brace-depth
   tracking in `PrismioScopeResolver`, `DeclarationKind` and `PrismioBlock` (formatter) assumes `{` at
   depth 1 inside an enum is not possible. Each field is a declaration of the variant, not of the enum.
5. **Uses**: `Event.Click { x: 1, y: 2 }` (a struct-literal shape after a qualified name) and the pattern
   `Event.Click { x, y }` (bare names that *bind*). Completion after `Event.Click {` should offer the
   variant's field names; goto on a pattern binder goes to the binder, not the field.
   `symbols/TypeInference.java` and `symbols/SignatureParser.java` read variant payloads positionally today.
6. **`Status.Ok`** for a `codeset` is a value of the representation type, not an enum member: type
   inference gives `U16`, not `Status`. `symbols/TypeDecl.java` needs to know a codeset is not a type, so
   `x: Status` can be flagged (the compiler refuses it).
7. **Formatter**: `PrismioBlock` indentation for `enum E: U8 {`, for entries with `= value`, and for a
   struct variant's inner braces.
8. **Tests**: add the compiler's `tests/test_327_enum_discriminants.psm` and `test_328_codeset.psm` to the
   corpus the lexer test runs, and a `testData` case for each of items 2-5.

## `I32`

`I32` is another spelling of `Int` (the compiler renames it in the parser). It is in the highlighter's
builtin types already; check that hover and inference show the type as `Int` for both and that the two
mix without a mismatch warning (`PrismioWords.BUILTIN_TYPES`, `symbols/TypeRef.java`).

## Variadic parameters and `typelist` (compiler 0.2.0)

Compiler side: `docs/VARIADICS_PLAN.md`, `language/variadics` in the docs site.

1. **`...` token** (`TokenType.ELLIPSIS`, beside `..` and `..<`): a punctuation token in
   `lexer/PrismioLexer.java`, highlighted as an operator. Longest match: `...` before `..<` before `..`.
2. **`typelist Name { A, B }` / `typelist Name (A, B)`**: a contextual keyword like `codeset`, with a body of
   types, traits or other list names; `(id: Int, name: String)` entries carry names. Same files as `codeset`
   (item 1 above) plus `{` vs `(` as the body opener in `PrismioScopeResolver`, `DeclarationKind` and
   `PrismioBlock`.
3. **`...name: T` parameter**, last in the list: `symbols/SignatureParser.java` must read the marker, completion's
   parameter hints should show `name...: T`, and the formatter keeps `...` attached to the name.
4. **`f(...args)` spread** in a call: highlight, and offer only pack names after `...`.
5. **Inside a pack function**: `args.length`, `args.count`, `args[0]` and `for x in args` are not ordinary member
   or index accesses (types differ per element), so inference should answer "unknown" rather than flag them;
   `row.name` completes from the typelist's named entries.
6. **Bounds**: `<Ts: Printable>` names a `typelist`, not a trait; resolve it for goto and do not warn that it is
   not a trait.
7. `print` / `println` now accept several arguments: signature help for `std.display`.
8. A pack's type may be a typelist or a trait directly (`...xs: Printable`, `...xs: Display`), and a pack
   may sit after ordinary parameters and generics; `max` / `min` take three or more integers.
