# Collections

The design of Prismio's sequence types, and the order they land in. The decisions
below were settled with the project owner on 2026-09-17; the status column is the
part that moves.

```text
[T] / [T; N] / Array<T, N>   fixed length, contiguous, owned
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

### `[T]` is an array whose length is part of its type

`[T]` and `Array<T>` are `Array<T, N>` with `N` inferred; `[T; N]` and
`Array<T, N>` write it.

- **With an initializer, `N` comes from it.** `let x: [Int] = [2, 3, 4]` is
  `Array<Int, 3>`.
- **Without one, `N` must be written.** `let x: [Int; 8]` reserves eight slots
  to fill later.
- **In a parameter, `N` is taken from each call.** `fn f(xs: [Int])` is generic
  over the length and is compiled once per length it is called with.

An array is a value of known size -- `[N x T]` in LLVM -- so, unlike today's
`[T]`, it can be returned and stored in a field.

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
| 1e | A removal releases at once where no element view can be live (`vecRemovalReleasesNow` in src/ir/expr.psm), and `pop` moves the element out instead of copying it | |
| 2 | Integer type arguments (`Array<T, 3>`, `Vec<U8, 4096>`), `[T; N]` | |
| 3 | `Array<T, N>` as a sized value: inferred `N`, returnable, field storage, per-length instantiation of `[T]` parameters | |
| 4 | `Vec<T, N>` runtime and codegen; `Vec<T, Chunk>`; chunk-size benchmark | |
| 5 | `Slice<T>` layouts: raw `(ptr, len)` where growth is provably absent; slices of arrays and chunked vectors | |
