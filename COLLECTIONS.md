# Collections

The design of Prismio's sequence types, and the order they land in. The decisions
below were settled with the project owner on 2026-09-17; the status column is the
part that moves.

```text
Array<T, N> / [T]            fixed length, contiguous, owned
Vec<T>                       growable, contiguous, owned -- the default vector
Vec<T, N>                    growable, chunked, owned -- N elements per chunk
Vec<T, Chunk>                growable, chunked, owned -- N chosen from sizeof(T)
Slice<T>                     non-owning view of a range
```

---

## 1 · Decisions

### `Vec<T>` replaces `List<T>`

`List<T>` is already the contiguous growable vector: `RtList` holds a single
element block, stores flat elements inline and boxes the rest. `Vec<T>` is that
type under its final name, and **`List` is removed** once nothing spells it, with
a diagnostic that names the replacement. `std.list` becomes `std.vec`, and the
literal lowering target `listOf` becomes `vecOf`.

**The rename is surface-only.** The compiler's internal type key stays
`List<...>`, and `TypeKind.LIST`, `RtList` and the `list_*` runtime entry points
keep their names. Mangled symbols, AIF's type keys and the Python oracle therefore
do not move, which is what lets each step be checked for byte-identical IR.

### `Vec<T>` is used through methods

Approved 2026-09-17 as one list. `v.f(a)` is already `f(v, a)`, so a reading
method is an ordinary generic function in `std.vec`. **A method that stores an
element or hands one out is a sema rewrite to the runtime call instead**: a
parameter is a borrow, so a Prismio wrapper cannot take ownership of what it
pushes, and a generic function returning an element stops the escape analysis
releasing the container.

| Group | Method | How |
|---|---|---|
| Build | `[]`, `[a, b, c]` | literal, lowered to `vecOf` |
| | `let v: Vec<T>` with no initializer | sema gives it `[]` (2026-09-18) |
| | `Vec<T>.withCapacity(n)` | rewrite → `list_new_with_capacity` |
| Size | `length`, `isEmpty`, `isNotEmpty` | library |
| | `capacity` | new runtime entry |
| Read | `v[i]`, `for x in v`, `v[a..b]` | existing |
| | `first`, `last` | rewrite → `v[0]`, `v[v.length - 1]`; bounds-checked |
| | `get(i)` → absent out of range | library, `T: Copy` |
| Search | `contains`, `indexOf`, `lastIndexOf`, `countOf` | library, `T: Eq` |
| | `binarySearch`, `isSorted` | existing |
| Write | `push`, `set`, `swap`, `v[i] = x` | rewrite → `list_push`, `list_set`, `list_swap` |
| | `pop` → absent when empty | new runtime entry + rewrite |
| | `insert`, `removeAt`, `clear`, `truncate`, `reserve` | new runtime entry + rewrite |
| | `extend(other)` | library, `T: Copy` |
| Order | `sort`, `sortBy` | existing |
| | `reverse` | library, through `swap` |
| Derive | `clone` | library, `T: Copy` |
| | `filter`, `mapInto`, `countWhere`, `anyOf`, `allOf` | existing |

The `list_*` functions remain as the runtime layer, as `str_*` do under String;
documentation shows the methods.

### `Array<T, N>` is an array whose length is part of its type

**Revised with the project owner on 2026-09-18.** `Array<T, N>` is the one
spelling that carries a length. `[T]` is shorthand for it when the variable is
initialised with values, and so is `Array<T>`. **There is no `[T; N]`.**

- **With an initializer, `N` comes from it.** `let x: [Int] = [2, 3, 4]` and
  `let x: Array<Int> = [2, 3, 4]` are `Array<Int, 3>`; `Array<Int, 3>` with an
  initializer must match it.
- **Without one, `N` must be written.** `let x: Array<Int, 8>` reserves eight
  slots, each the element type's zero. `let x: [Int]` alone is an error.
- **In a parameter, `N` is taken from each call.** `fn f(xs: [Int])` takes any
  length. Today it is a view of the caller's array; compiling it once per length
  is still step 3.

An array of a known length is a value of known size -- `[N x T]` in LLVM.
`let b = a` and `d = c` copy it, a `-> Array<T, N>` function returns it by
value, and an `Array<T, N>` field stores it in the struct's own body.

### `Vec<T, N>` and `Vec<T, Chunk>` are chunked

Elements live in fixed-capacity chunks that never move once allocated, so growing
never relocates an element. `N` is elements per chunk. `Chunk` asks the compiler
to choose `N` from the element's size:

```text
N = max(1, target_chunk_bytes / sizeof(T))
```

`target_chunk_bytes` starts at 4 KiB and is set by measurement, not by argument.

### `Slice<T>` has two layouts, chosen at compile time

| Base | Layout | A read costs |
|---|---|---|
| `Array`, `Vec<T>`, growth provably absent while the slice is live | `(ptr, len)` | one GEP |
| `Vec<T>`, growth possible while the slice is live | `(handle, offset, len)` | a header load, then a GEP |
| `Vec<T, N>`, `Vec<T, Chunk>` | `(handle, offset, len)` | a chunk lookup |

The compiler picks the layout per slice. A function that takes `Slice<T>` is
compiled once per layout it receives, so no read branches on the layout. Nothing
is tracked at run time and no program is rejected for growing a vector: a slice
whose base might grow simply gets the layout that survives a reallocation.

**Why not rebase raw pointers on reallocation.** The pointer a loop reads through
is in a register, which a rewrite of the slice's memory cannot reach. Rebasing is
sound only if every read reloads the pointer, which is the handle layout's cost
with registration on every copy added to it.

---

## 2 · Order of work

Each step lands with the full loop: two generations to a fixpoint, the suite,
`tools/aif_differential.py`, and byte-identical IR where the step preserves
behaviour. Syntax lands before its first use in `src/` or `std/`, with a seed
refresh between.

| # | Step | Status |
|---|---|---|
| 1a | Sema accepts `Vec<T>` as the spelling of the internal List type; diagnostics say `Vec` | done 2026-09-17; IR byte-identical |
| 1b | Seed refresh; migrate `src/`, `std/` (`std.vec`, `vecOf`), tests, benchmarks, corpus, `ums/`, docs | done 2026-09-17: user and developer docs migrated, both example gates pass; the `aif` report says `Vec` and `--manifest` keeps the key |
| 1c | `List<T>` is an error naming `Vec<T>`; seed refresh | done 2026-09-17 (P3005, neg_156); seed refreshed |
| 1d | The method surface above: library tier, sema rewrites, new runtime entries with AIF contracts in both implementations | done 2026-09-17 with removal always parking (`now` = 0); test_155, neg_157..159. Fixpoint, seed build matching, suite 348/348, differential at its known two, separation and externs clean. `v[i] = x` was not: it type-checked and generated nothing, for every collection, until 2026-09-18 -- sema now rewrites it to `list_set`/`slice_set`, an array of unowned elements stores in place, and the rest are refused (test_156, neg_161) |
| 1e | A removal releases at once where no element view can be live (`vecRemovalReleasesNow` in src/ir/expr.psm), and `pop` moves the element out instead of copying it | removal done 2026-09-18: `semaRemovalVerdict` (fresh local, nothing viewed before, and in a loop no view assigned out of the iteration); test_161 peaks at 208 bytes against 35,102 parked, test_162 must park. **The moving `pop` is deferred past 0.1**: handing an element out needs the caller to own it with the Vec's disposition, which AIF has no rule for -- modelled as a view it leaks, as a fresh value it double-frees a counted element |
| 2 | Integer type arguments (`Array<T, 3>`, `Vec<U8, 4096>`) | `Array<T, N>` done 2026-09-18: a number is a type argument of `Array` only (P3006 elsewhere); normalised into the `[T]` node with the length on `child2`, read only by a local `let` (zero-filled without an initializer). `Vec<T, N>` waits for step 4. test_158, neg_162, neg_163 |
| 3 | `Array<T, N>` as a sized value: inferred `N`, returnable, field storage, per-length instantiation of `[T]` parameters | mostly done 2026-09-18: `TypeInfo.length` carries `N` (inferred from literals and through the sem key); a known-length array of unowned elements copies on `let` and assignment, a `[T]` parameter is a view; every array slot is in the entry block. **Returns** (`-> Array<T, N>`, the `arr:N:K` aggregate; test_163, neg_164) and **fields** (`[N x T]` in the struct body, zeroed or copied by a literal, flat for Vec storage; test_164, neg_165). Where a length may be written is one syntactic pass, `semaCheckArrayLengthPositions`, first in `analyzeModule` and over both chains. **Left, and Coming Soon in both doc apps:** per-length parameters, array fields in generic structs and enum payloads, copying arrays of arrays and of owning elements |
| 4 | `Vec<T, N>` runtime and codegen; `Vec<T, Chunk>`; chunk-size benchmark | **deferred past 0.1** (2026-09-18, owner's call): not started, listed as Coming Soon in both doc apps; `Vec<T, N>` is P3006 until then. Settle fixed-N chunks (std::deque) against geometric segments (Zig's SegmentedList) by measurement before building |
| 5 | `Slice<T>` layouts: raw `(ptr, len)` where growth is provably absent; slices of arrays and chunked vectors | |
