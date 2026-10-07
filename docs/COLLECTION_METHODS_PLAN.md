# Collection methods

The methods `Vec<T>`, `Array<T, N>` and `Slice<T>` answer, what 0.1 ships, and what
waits for 0.2. [COLLECTIONS.md](COLLECTIONS.md) decides the *types*; this file is
the method surface on top of them, from an audit on 2026-10-01 (92 one-line
programs, one method each, in the spelling Rust, Swift and Kotlin use).

**State, 2026-10-01.** The method work for 0.1 is built and verified: gate green on
`build/cv-rc5` (IR fixpoint byte-identical, suite 501/501, differential 19/19,
`--verify` 0 leaked), and both docs apps are updated and their examples compile
(272 in `apps/docs`, 50 in `apps/developers`). **Nothing is committed.** What is
left is in §1.

## 1 · Left for 0.1

| # | Item | Notes |
|---|---|---|
| 1 | ~~Decide `any`/`all`~~ | Decided 2026-10-01: renamed `anyOf`/`allOf` to `any`/`all`, no aliases. Nothing had shipped, so it cost no compatibility. The String methods stay `anyChars`/`allChars` (`std/string.psm` explains the overload clash) |
| 2 | ~~Decide `removeLast`~~ | Decided 2026-10-01: not added. `pop` is the one spelling |
| 3 | ~~The general array diagnostic~~ | Done 2026-10-01. A Vec's method asked of an array (`x.push(4)`, `x.removeAt(0)`, `y.isEmpty`, `y.capacity`) says `no overload of ... accepts these argument types` and then names the receiver (`` `x` is an `Array<Int, 3>`, a fixed-length array, and `push` is a `Vec` method ``) and the spelling that grows (`let x: Vec<Int> = [...]`; for a `[T]` parameter, take a `Vec<T>`). `tests/neg_254`. Three routes reach it: a name the compiler builds for a Vec (`semaVecLowersMethod`), a property, and a std function that takes a Vec first, generic or not (`monoHasVecTemplate`: the decl index does not hold generics, so those used to read `unknown function`). It fires only when the name is a Vec's, so a program's own `push(n: Int)` is not blamed on arrays |
| 4 | **Re-run the gate on the commit, then commit** | `RELEASE.md` §0: the gate must be green on the exact commit that is tagged. Commit the compiler repo without `benchmarks/`, `sandbox/` and `src/lexer/scanner.psm`, and the website pages as their own commit. Do not push without the owner's go-ahead |

## 2 · What 0.1 ships

Every function is in `std/vec.psm` (`import std.vec`) unless noted. A method that
stores an element or hands one out would be a sema rewrite instead of a function, as
`push` and `first` are (COLLECTIONS.md §1); none of these needed that.

| | `Vec<T>` | `Array<T, N>` | `Slice<T>` |
|---|---|---|---|
| Size, ends | `length`, `isEmpty`, `isNotEmpty`, `capacity`, `first`, `last`, `get(i)` | `length`, `first`, `last` (compile-time `N`, `a[0]`, `a[N - 1]`) | `length` |
| Search | `contains`, `indexOf`, `lastIndexOf`, `countOf` (`T: Eq`); `binarySearch`, `isSorted` (`T: Ord`); `startsWith`, `endsWith` | the first six | the first six |
| Reads | `min`, `max`, `find`, `indexWhere`, `any`, `all`, `countWhere`, `forEach`, `fold` | the same | the same |
| Change in place | `push`, `set`, `insert`, `pop`, `removeAt`, `removeFirst`, `swapRemove`, `truncate`, `clear`, `reserve`, `extend`, `retain`, `dedup`, `fill`, `reverse`, `swap`, `sort`, `sortBy` | `sort`, `sortBy`, `reverse`, `swap`, `fill` | the same, through to the Vec it views |
| Copy out | `clone`, `filter`, `sorted`, `reversed`, `take`, `skip`, `concat`, `mapInto`, `toVec` | `toVec` | `toVec` |

- **`min`/`max`/`find`/`removeFirst`** answer a `T?` (`none` when empty), as
  `pop` and `get` do. `fold(initial, f)` takes its result type from `initial`, an
  argument, which is why it can return a value and `map` cannot (§5, item 4).
- **`skip`, not `drop`.** `drop` is the compiler's own release builtin, and a
  function cannot take that name.
- **`retain` and `dedup` need no `Copy`.** They swap the kept elements forward and
  truncate the rest, so nothing is copied and the truncation releases what is
  dropped. Measured clean on `Vec<String>`.
- **A bare integer literal is the element's width:** `ids.contains(2)` on a
  `Vec<I64>` needs no `as I64`, and `contains(300)` on a `Vec<U8>` is still
  rejected. `Vec<Float>.contains(2)` stays an error, as `f(2)` for a `Float`
  parameter is.
- **Searches work for every element type with `Eq`:** the scalars, `String`, the
  scalar optionals, and an enum or struct that writes `impl Eq`. Tested on arrays of
  `Int`, `Float`, `String`, `Char`, `Bool`, `I64`, `U8`, `I8`, an enum and a struct.

## 3 · How

**Vec:** library functions over `Vec<T>`, as before.

**Slice:** the same bodies over `Slice<T>`, using `items.length` and `items[i]`. A
slice carries its length, so the compiler does nothing for it.

**Array:** an array's length is in its *type* (`TypeInfo.length`) and a `[T]`
parameter does not know its own, so each array function takes the length beside the
array: `min(items: [T], count: Int)`. At a call on an array whose length the
compiler can see, `src/sema/array.psm` supplies it, so `a.min()` becomes
`min(a, N)`, `a.length` becomes the literal `N`, and `a.first` / `a.last` become
`a[0]` / `a[N - 1]`. The owner of a `[T]` parameter calls the long form by hand,
`min(xs, n)`; `xs.min()` and `xs.length` there are errors that say the length is not
known and point at it. The hook is `semaArrayLower`, called from the method-call and
property paths in `src/sema/checker.psm` next to Vec's lowering.

**Three compiler bugs found writing this, all older than it, all fixed with a test:**

- **A literal needle against a sized element** failed to resolve. `monoTemplateAcceptsCall`
  solved `T` from the Vec as `I64` and then compared the parameter with the literal's
  first-guess type `Int`. `monoLiteralFits` gives a generic call the rule a concrete
  one already had (`semaArgMatchesType`). `tests/test_250`, `neg_252`.
- **A program's own name beside a std generic** failed. Declaring `filter`, `find`,
  `take` or `min`, as a free function or a method, while importing `std.vec` gave
  `unknown type 'T'` pointing into the library, though nothing called the generic.
  `semaShadowsStandardLibrary` computed the signature of every same-named std
  function, and a generic has none until it is instantiated; it now skips generics
  (`nodeIsNull(decl.genericInfo)`). Present in the shipped RC for `filter`.
  `tests/test_252`.
- **A closure that answers nothing** failed: `|x: Int| println(x)` gave
  `unknown type 'Void'`. The lowered `call` took its return annotation from the body's
  type and `Void` is not a type a function can name; it is now a `call` with no return
  type and a statement body. Without it `forEach` could be given only a closure that
  returned a value. A callable *bound* still needs a result (`F: Fn(Int) -> R`);
  an unconstrained `F`, as `forEach` uses, takes either. `tests/test_253`.

## 4 · Limits in 0.1

- **Copying a `Vec<String>` is clean.** `take`, `skip`, `concat`, `reversed`, `sorted`, `toVec`, `clone`,
  `filter` and `extend` leaked every copy until 2026-10-01 (273 of 464 in
  `test_255`): all callers share the one allocation in `strClone`, two containers
  holding its results read as one value held twice, and a String cannot be
  counted. A fresh String site is now exempt from that rule
  (`runtime/aif_support.c`, A-CONTAIN; 273 -> 0, 0 violations), and a String that is
  a view of another collection (`c.push(s[0])`) is copied at the push, so it stays
  clean beside the clones (`test_256`; KNOWN_ISSUES.md). A scalar element type was
  always clean.
- **An array's in-place changes** need a `let mut` array, and store only elements
  nothing owns (numbers, `Bool`, `Char`, enums without payloads): `reverse` on an
  `Array<String, N>` is refused at the store, as `a[i] = x` is. The reads work for
  every element type.
- **An array has no `isEmpty`**, because its length is at least one.
- **`sort` on an array or slice** copies into a Vec, sorts, and copies back: one
  allocation, and `Vec.sort`'s order and instability.
- **An enum or struct needs `impl Eq` for any search.** `Color.Red == Color.Green`
  compiles but `[Color.Red].contains(Color.Red)` does not without the impl. A
  `Vec<T>` *literal* of a user type fails with `T does not implement Copy`
  (`vecOf<T: Copy>`), so such a Vec is built with `push`.

## 5 · For 0.2: needs design first

Each entry says what the design question is.

| # | Item | The question |
|---|---|---|
| 1 | **One overload set for all three receivers** | Arrays and slices carry their own copy of each function, about 25 near-identical bodies, because Prismio has no trait over "something indexable". Removing the duplication needs one, and that is a language decision. Until then still missing on arrays and slices: `sum`, `extend` from an array, `startsWith`/`endsWith`, the copying forms (`sorted`, `reversed`, `take`, `skip`, `concat`; call `toVec()` first), `isEmpty` on a slice, slicing an array |
| 2 | **Implicit array/slice to `Vec`** | `let r: Vec<Int> = a` and `v[0..<2]` into a Vec are type errors. `toVec()` is the explicit copy; whether an implicit one should exist is the question |
| 3 | **A numeric trait**, for `sum`, `average`, `product` | The traits are `Copy`, `Display`, `Eq`, `Default`, `Iterator`, `Key`, `Ord`. `min`/`max` need only `Ord`; `sum` needs `+` and a zero. An `Add`/`Num` trait, or per-width overloads like `std.math` |
| 4 | **`map` returning a `Vec<U>`**, and `flatMap`, `flatten`, `zip`, `partition` | A type parameter is solved from argument types only, so `U` cannot come from a closure's return type (why `mapInto` takes its destination). Needs inference from a closure's body, or tuples and a way to name `U` |
| 5 | **Printing a collection**: `println(v)`, `v.toString()` | `Display` has no `Vec` impl and `println` has one overload per builtin type. Needs `impl<T: Display> Display for Vec<T>` and a format (`[1, 2, 3]`). The one a new user meets first |
| 6 | **Deriving `Eq` (and `Ord`)**, and `Eq` for fieldless enums | The compiler has no impl synthesis, and a generic body calls `Eq.eq(a, b)`, which needs an `eq` function to exist. `==` on a struct is refused outright. Opt-in derive, automatic conformance, or leave it. Also decides `Vec<Vec<Int>>.contains` and `Vec<Option<Int>>.contains`, which fail on `Copy` today. Until then: `impl Eq for Color { fn eq(self, other: Self) -> Bool { return self == other } }` |
| 7 | **`v + w`**, and `sortDescending` | An operator overload mechanism for non-numeric types; `sortBy` covers the sort |
| 8 | **`windows`, `chunks`, `enumerate`, `rotateLeft`, `removeRange`, `insertAll`, `lowerBound`, `unique`, `repeated`** | Mostly lazy-iterator work (`v.iter().…` is on the doc apps' *Coming Soon* list), or a plain addition once item 1 is settled |
| 9 | **Inconsistent "absent" results** | `indexOf` answers `-1`; String's `find` and `Vec.get` answer a `T?`. Changing `indexOf` breaks a documented method, so it is a 0.2 question or never |
| 10 | **A moving `pop` and `removeAt`** | So a non-`Copy` element can be taken out. COLLECTIONS.md step 1e. `removeFirst` and `swapRemove` are `T: Copy` until it lands |

Planned elsewhere and not repeated: `Vec<T, N>`, `VecDeque`, sets, priority queues,
comprehensions (COLLECTIONS.md and the doc apps' *Not available yet*).

## 6 · Verification

**Tests**, all in `tests/`: `test_249_array_methods`, `test_250_literal_needle`,
`test_251_collection_methods`, `test_252_names_beside_std_generics`,
`test_253_void_closure`, `test_254_array_and_slice_methods`,
`neg_251_array_length_unknown`, `neg_252_literal_needle_range`,
`neg_253_array_mutation_needs_mut`, `neg_254_array_has_no_vec_method`.

**The probe.** One program per method, so a failure cannot hide another, each a line
`group|label|statements` over this header, run through `prismio check` from a
compiler **not named `prismio`** (inside the checkout that name is the launcher and
checks against the project host):

```prismio
import std.io
import std.vec
import std.option
import std.string
fn main() -> Int {
    let mut v: Vec<Int> = [3, 1, 2]
    let w: Vec<Int> = [9, 8]
    let mut a: Array<Int, 3> = [3, 1, 2]
    let mut s: Vec<String> = ["b", "a"]
    let mut f: Vec<Float> = [1.5, 2.5]
    // <statements>
    return 0
}
```

The first run was 92 probes with 16 passing. Every array and slice probe for §2's
table passes now; what still fails is §4 and §5 on purpose. The probe is not a
fixture yet. Turning it into one under `tests/` would keep §2 from regressing.

**Leaks** are measured with `prismio build f.psm --verify` (the flag follows the
file), in three shapes for anything that returns a value: bound, with an owned
argument, and nested.
