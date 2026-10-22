# Variadic parameters and `TypeList` (proposal -- not built)

**Status: built (2026-10-22).** Decisions taken: the word is `typelist`; `{ }` is an unordered set and `( )` an ordered
sequence that repeats; no repetition suffixes; packs are consecutive; trait entries and spread are in; `print`
separates with a space (Python, JS and Go do); named entries are in (`row.name`); no minimum count. What was built,
and what is left, is `website/apps/developers/content/compiler/variadics-and-packs.md`. Left: a pack in a closure,
keyword arguments, a minimum count, and the `std` families beyond `concat`/`print` (`min`/`max`, `assert`).
The text below is the design as proposed.

## The problem

Two library families are written as one overload per arity or per type:

- `String.concat` is five overloads, for 2 to 6 pieces (`std/string.psm`); past six it does not exist, and
  interpolation joins six at a time and then joins the groups (`parse/expr.psm`).
- `print` / `println` are about 30 overloads, one per type, each taking one value (`std/io.psm`); `print(a, b)`
  does not exist.

A program also cannot write a function that takes **any number of arguments, each of a type it allows**.

## `TypeList`: a named list of types, unordered or ordered

A `TypeList` says which types a variadic parameter accepts, and **the user chooses whether order matters**
by the delimiter they declare it with: braces are an unordered **set**, parentheses an ordered **sequence**.

```prismio
typelist Scalars { Int, I64, Float, Bool }      // a set: any of these, in any order
typelist Printable { Display }                  // a set with a trait: every type implementing it
typelist Row (Int, String, Bool)                // a sequence: an Int, then a String, then a Bool
typelist Named (id: Int, name: String)          // a sequence with names for its positions
```

| Form | A pack bounded by it accepts |
|---|---|
| `{ A, B, C }` set | any number of arguments, each one of `A`, `B`, `C`, in any order |
| `( A, B, C )` sequence | the sequence `A, B, C`, **in that order, repeated any number of times** (zero included) |

That is the whole rule. A variadic parameter is variable in length by definition, so a set varies in how
many arguments it takes and a sequence varies in how many times its group repeats. Exactly one group needs
no variadic at all; it is an ordinary parameter list.

An entry is a type, a trait (any type implementing it fits), or another list: a set inside a set is a
union, and a set inside a sequence means "any of these at this position" (`(Int, Printable, Bool)`).
`typelist` is a contextual keyword, like `codeset`. A `TypeList` exists only at compile time: it is not a
type and not a value, so it cannot collide with a future tuple type.

It is a bound on a generic parameter, in the position a trait bound has, and the parameter is deduced from
the call:

```prismio
fn rows<Ts: Row>(...args: Ts) { ... }           // Int, String, Bool, in that order, n times
fn show<Ts: Printable>(...args: Ts) { ... }     // any number of printable arguments
```

A set also bounds a single, non-variadic parameter: `fn g<T: Scalars>(x: T)`.

Errors name the list and the rule broken:

- set: ``argument 3 has type `Ptr`, which is not in `Printable` ``
- sequence: ``argument 5 must be `Int` (the arguments repeat `Int, String, Bool`), found `Bool` ``
- count: ```rows` takes arguments in groups of 3 (`Int, String, Bool`); 4 were given``

## A pack: `...args: Ts`

A parameter marked `...` takes the arguments the list allows:

```prismio
public fn println<Ts: Printable>(...args: Ts) {
    for arg in args { print(arg.show()) }
    println()
}
```

### Two packs: `fn f<Ts: PTs, Us: KTs>(...pts: Ts, ...kts: Us)`

A function may have more than one pack. **The packs' arguments are consecutive, in declaration order:**
all of `pts`, then all of `kts`. Where the first ends is found by its list: a sequence ends at the
first argument that does not continue its repetition, and a set at the first argument that is not in it, which is why two set packs must not
overlap (an error at the declaration when two types coincide, and at the call when one argument fits both
through a trait entry). Keyword arguments (`f(x, name: v)`) are a different feature, since the language
has no named arguments; this does not block adding them.

### Reading the arguments in the body

Everything is resolved at compile time, because the number and types are known at each call:

| Written | Means |
|---|---|
| `args.length` | the number of arguments in this pack |
| `args[k]` | the k-th argument, typed as itself (`k` a literal) |
| `for arg in args { ... }` | a **set**: the body unrolled once per argument; `arg` has its own type |
| `for row in args { ... }` | a **sequence**: the body unrolled once per group; `row[k]` is the k-th entry of that group, and `row.name` for a named entry |
| `args.count` | a sequence: the number of groups |
| `f(...args)` | pass the pack on as separate arguments (spread) |

`for` over a pack is not a runtime loop. It is N copies of the body, which is what lets `arg.show()`
resolve to a different `Display` impl in each. An ordinary `for` over an `Array` is unchanged.

### The homogeneous shorthand

When every argument is one concrete type, no list or generic parameter is needed:

```prismio
public fn concat(self, ...parts: String) -> String { ... }     // parts: Array<String, N>
```

The annotation is the type of **each argument**, not of the collection (the opposite of TypeScript's
`...args: string[]`). Because the elements are alike this one gets a real `Array<String, N>`.

## Rules

1. A fixed-arity overload that matches beats a variadic one, so every existing `print(value: Int)` keeps
   winning for one argument, and nothing already written is re-resolved or slower.
2. Each distinct list of argument types is its own instantiation, mangled with the types, as a generic is
   per type argument. No tuple, array or length exists at run time (except `parts: Array<String, N>`).
3. Trait and `impl` methods may be variadic (`concat` is a method). Closures may not, in the first cut.
4. `extern fn` may not be variadic: C varargs stay refused.

## How it is built

The project's own pattern: **put the feature in the AST, not in five passes** (`sema/enums.psm`,
`sema/generics.psm`). Sema rewrites a variadic function into an ordinary one per call shape, so AIF,
ownership and codegen never see a pack.

| Step | Where |
|---|---|
| `...` token (longest match beside `..` and `..<`) | `lexer/scanner.psm` |
| `typelist Name { ... }` / `( ... )` declaration | `parse/typelists.psm` (new), beside `parse/enums.psm` |
| `...name: T` as a parameter | `parse/decl.psm` |
| `TYPELIST_DECL` node; a pack flag on `FUNCTION_PARAMETER` (`i2` is free) | `ast/nodes.psm` |
| A `TypeList` as a bound: membership test per type, trait entries through `monoImplements`, nested lists flattened | `sema/typelists.psm` (new) |
| Call binding: walk the surplus arguments pack by pack, matching each against its list (membership for a set, position within the repeating group for a sequence); check overlap | `sema/symbols.psm`, `sema/checker.psm` |
| Instantiate: copy the function, replace `...args: Ts` by `args$0: T0, args$1: T1, ...` | `sema/generics.psm` |
| Rewrite in the copy: `length`, `args[k]`, `for` unrolled, `...args` spread | `sema/packs.psm` (new) |
| `f(...xs)` at a call site | same file, before overload resolution |

`T: Scalars` on a single (non-pack) generic parameter falls out of the same membership test and costs
nothing extra. After the rewrite the function is plain, with N parameters.

## What it replaces

- `concat`'s five overloads become one. The short-string fast path (`total <= 12`, one hand-written
  `__builtin_string_concat_inlineN` per arity today) becomes a loop into a stack buffer. **I would measure
  it against the current overloads before deleting any**, and keep the two-piece one fixed.
- Interpolation emits one `concat`; the six-at-a-time grouping in `parse/expr.psm` goes.
- `print` / `println` gain the variadic form **beside** the per-type overloads (rule 1), which stay as the
  one-argument fast path. `std.display` exports `Printable`.
- Later, each with a measurement: `min` / `max` of several values, `assert` messages.

## Decisions I need

Settled: the word is `typelist`; `{ }` is an unordered set and `( )` an ordered sequence; there are no
repetition suffixes (a sequence repeats, a set takes any count).

1. **Packs are consecutive, in declaration order** (the rule above), rather than routed by type with
   interleaving. I recommend consecutive: it is what ordered lists need, and it reports a misplaced
   argument precisely.
2. **A trait as a list entry** (`typelist Printable { Display }`) in the first cut. `print` needs it.
3. **Separator for `print`.** `println(a, b, c)` writes `abc` (like `concat` and interpolation), or `a b c`
   (Python). I recommend none.
4. **Spread** (`f(...args)`) in the first cut. I recommend yes: forwarding is the first thing anyone writes
   with a pack.
5. **Named entries** in a sequence (`(id: Int, name: String)`): first cut or later?
6. **A minimum count** ("at least one"): without a suffix there is no spelling for it. Leave it out, or a
   later `where Ts.length > 0` once `where` can speak about packs?

## Risks

- **Compile time and code size**: one instantiation per distinct type list used. `print` forwards to the
  existing overloads, so each instantiation is a few calls that inline.
- **Diagnostics**: an error inside an unrolled body points at the pack function, not the call, so each
  instantiation's error carries a note naming the call's argument types, as generics' do.
- **Performance** is unchanged for existing code by rule 1; for `concat` it is the thing to measure.
- **Seed**: neither `src/` nor `std/` (which `src/` imports) can use the syntax until a seed and host that
  parse it are installed. Two steps, as CODE_STYLE.md's "Self-hosting comes first" requires: teach the
  frontend and the rewrite; cut the seed and promote the host; then convert `std`.

## Order of work

1. Lexer, parser, AST: `...`, `typelist`, the pack flag; `P3xxx` diagnostics for a misplaced pack (not last,
   in `extern`) and a malformed list.
2. `sema/typelists.psm` and `sema/packs.psm`: membership, routing, overlap, instantiation, the rewrites.
   Tests: a list with types, a trait and a nested list; an argument outside the list; two packs, routed and
   misplaced; `println` of mixed types; `length` / `args[k]`; forwarding; zero arguments.
3. Cut the seed, promote the host.
4. Convert `concat`, then `print` / `println`, then interpolation, measuring each.
5. Docs in both apps; `docs/INTELLIJ_PLAN.md` gains `typelist` and the parameter form.
