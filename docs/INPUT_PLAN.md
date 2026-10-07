# Reading input: what is awkward and what to change

> **Status, 2026-10-07.** **D is done** and **E's `??` is done**: `Option<T>` is gone and every
> absent-able answer is a `T?` (`readLine`, `prompt`, `tryReadFile`, `process.env`, `stripPrefix`,
> `Vec.get`, `Map.get`, and the rest), `??` evaluates its right side only when it is needed, and the
> reads are plain functions (`readLine()`, `readInt()`, `inputLines()`) and the `stdin` value is
> gone. **Still open:** `let-else` and `if let` (E), the forms that would let a `T?` be read
> without `expect`. The audit below is as it stood on 2026-10-02; read its `Option<T>` as `T?`.

Audited 2026-10-02 against `std/input.psm`, `std/fs.psm`, `std/process.psm`,
`std/string.psm`, `std/option.psm` and the language pages for optionals. Every claim
below was run against the current compiler, not read off the docs.

## 1 · The program that does not build

```prismio
let header = stdin.readLine()
println("Your message:", header)
```

```
error[P4001]: no overload of `println` accepts these argument types
```

`stdin.readLine()` returns `Option<String>`, and `println` accepts only strings,
numbers, `Bool`, `Char` and the scalar `T?` forms. Nothing prints an `Option<T>`: not
`Option<String>`, and not `Option<Int>` either. The message names neither the type it
saw nor the fix, so the program looks right and the compiler looks wrong. What works
today:

| Written | Result |
|---|---|
| `stdin.readLine().unwrapOr("")` | works: a `String` |
| `match (header) { Option.Some(t) => { .. } Option.None => { .. } }` | works, and is what `docs/stdlib/input` shows |
| `println(header)` | error above |
| `let h: String? = ..; println(h)` | the same error: a `String?` cannot be printed either |
| `h.unwrapOr("?")` on a `String?` | `unknown function unwrapOr`: `unwrapOr` exists for a scalar `T?` only |

## 2 · What the audit found

1. **Two optional types, split by accident.** `parse*` return `T?` (`Int?`, `Float?`,
   `Bool?`); everything else that can be absent returns `Option<T>`: `readLine`,
   `tryReadFile`, `tryReadLines`, `metadata`, `Map.get`, `process.env`, `String.find`,
   `.get`, `.stripPrefix`, `.stripSuffix`. A program that reads a number crosses both:
   `Option<String>` from `readLine`, then `Int?` from `parseInt`.
2. **`T?` for a reference type is half built.** The language page says `T?` works for
   `String`, `Vec<T>` and structs as a nullable pointer that allocates nothing, but a
   `String?` cannot be printed and has no `unwrapOr`. That is why the library reached for
   `Option<String>`, which allocates for every value (the input page says so itself and
   recommends `lines()` in a loop).
3. **`Option<T>` had no `Display`.** (`isSome` and `isNone` do exist, as properties.)
4. **The language has none of the usual unwrapping forms.** `optionals.md` lists them
   under "Not in 0.1": `??`, `if let`, narrowing after a comparison, `match` on a `T?`,
   `value?.field`. With those missing, every read of absent-able input is a four-line
   `match` or an `unwrapOr`.
5. **The reading API is three methods and a loop.** `readLine`, `readAll`, `lines`. No
   prompt (`input.md` says "print the prompt, then call `readLine`"), no typed reads, no
   end-of-input test, no way to read everything as lines. The usual script-shaped tasks
   (read a number, read N numbers, read all words) are each a hand-written loop over
   `readLine` plus `parseInt`, with two optionals to unwrap.
6. **The diagnostic does not help.** "no overload of `println` accepts these argument
   types" does not say what the argument types were, and a type with a conversion in
   reach (`Option<String>` has `unwrapOr`) gets no suggestion.
7. **Files are consistent with stdin, which is the good news.** `readFile` returns a
   `String` and aborts on failure; `tryReadFile` is the `Option<String>` form;
   `readLines` / `tryReadLines` mirror `lines()`. Whatever is decided for stdin should
   be applied to these in the same change.

## 3 · What to change, cheapest first

**Status 2026-10-02: A, B and C are done in the working tree (uncommitted); D and E are open.**
The program in section 1 now builds and prints `Your message: First line`. See the
notes under each item.

**A. Make the failure legible (diagnostic only, no API change).** When no overload
fits, print the argument types ("found `Option<String>`") and, for an `Option<T>` or
`T?`, add the note "unwrap it first: `x.unwrapOr(..)` or `expect(x)`". Smallest change,
removes the "compiler bug" reading of section 1. *Done:* `symbols.psm` notes the argument types
and, for an optional, the way to unwrap it; `typeDisplay` now writes a generic instance as the
program did (`Option<P>`, not `Option$Struct_P`), which every other diagnostic gets too.

**B. Let `Option<T>` print.** `impl Display for Option<T: Display>`, writing the value or
`none`, the same text a scalar `T?` already prints (`optionals.md`: "`println` writes the
value or `none`"). The program in section 1 then builds and
prints `Your message: x`, or `Your message: none` at end of input. Costs one impl in
`std/option.psm`; check the AIF site count it adds (`std.io` importing `std.string` once
turned 5 sites into 85). *Done, and wider than asked:* `std.display` now carries a
`print`/`println`/`eprint`/`eprintln` generic over `Display`, plus `Display` for `Option<T>`
and `String?`. So any type with an `impl Display` prints, not only optionals. It is in
`std.display` and not `std.io` so a plain printing program imports nothing new; a hello
world is 50,504 bytes before and after. The impls live there because an implementation
must sit with its trait or its type.

**C. Add the reads people actually write**, on `Stdin`, none of which changes an
existing method:

| Method | Returns | Replaces |
|---|---|---|
| `readLineOr(fallback)` | `String` | `readLine().unwrapOr(fallback)` |
| `prompt(text)` | `Option<String>` (or `String?`, see D) | `print(text)` then `readLine()` |
| `readInt()` / `readFloat()` | `Int?` / `Float?` | `readLine()` + `parseInt()` and two unwraps |
| `readInts()` / `readWords()` | `Vec<Int>` / `Vec<String>` | a `while` over `readLine` and `split` |
| `readLines()` | `Vec<String>` | `for line in lines() { v.push(line) }` |
| `isAtEnd` (property) | `Bool` | the `None` case, tested before reading |

*Done* (all but `readInts`, which has no good answer for a line that is not a number):
`std.input` imports `std.io` and `std.string` for them. Tests: `test_258_stdin_helpers`,
`test_259_display_print`.

**D. One optional type for absent-able values (decision needed).** Finish `T?` for
references (print, `unwrapOr`, `==` with `none` already exists) and move
`readLine`, `tryReadFile`, `env`, `stripPrefix`, `stripSuffix` and the rest to `T?`.
That removes the per-line allocation, makes `readLine` read like `parseInt`, and leaves
`Option<T>` for generic code that needs a type argument. It changes public return
types, so it is a breaking change to a released library: either do it in a 0.2 or add
`T?` spellings beside the old ones and deprecate.

**E. The language forms that remove the boilerplate (the real fix).** In order of how
much each saves:

```prismio
let title = stdin.readLine() ?? "untitled"                    // ??
guard let title = stdin.readLine() else { return 1 }          // let-else
if let title = stdin.readLine() { println("title: " + title) } // if let
```

`??` and `let-else` need one new expression form and one new statement form, each
typed against `T?` and `Option<T>` alike. `let-else` is the one that matters for
programs that must stop on bad input: it replaces the four-line `match` with one line
and keeps the happy path unindented. These are language changes, so the usual two
steps apply (teach the compiler, refresh the seed, then use them in `src/`).

## 4 · Order

A and B first (no API change, same day). C next (additive). Then E (`??`, `let-else`),
which makes D much less urgent. D last and only with a version decision. Each is one
commit, with the A/B in the message: for B and C the number that matters is the AIF site
count and the size of a hello-world that imports `std.input`; for D it is allocations
per line (`--verify` ledger) on a 1M-line read.
