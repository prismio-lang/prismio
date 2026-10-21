# What `graph_churn_*` and `register_pressure_torture` found

Written 2026-10-16, updated 2026-10-21. Five benchmarks were added (`benchmarks/hosted/*/graph_churn.*` and
`register_pressure_torture` in `adversarial.*`). Writing the Prismio arm of the first four turned up
seven compiler problems. Five are fixed (the sections headed *Fixed* below, each with a reproducer small enough
to paste, its cause and its guard); two are open. This file is the record, and `docs/KNOWN_ISSUES.md` points here
for the two that are open.

## The benchmarks

| Benchmark | What it is | Why it exists |
| --- | --- | --- |
| `graph_churn_single` | A slab of 32,768 nodes, each owning a `Vec<Int>` edge list. 960,000 steps add and remove edges, kill nodes (edge list freed) and revive them (edge list allocated). One thread. | Graph mutation and reclamation with lifetimes the data decides. |
| `graph_churn_alloc` | 40,000 fragments (8 to 31 nodes, every node its own edge list) built, summed and dropped through a 192-slot window; every 50th is kept to the end. One thread. | Allocation and lifetime pressure with no concurrency in the way. |
| `graph_churn_transfer` | 20,000 fragments built on one thread, trimmed (edge lists freed) on a second, received and freed by a third, through two bounded channels of 16. | Cross-thread transfer and reclamation: memory freed by a thread that did not allocate it. |
| `graph_churn_full` | The three above, one checksum. | The sum is not the parts if the parts interact; it should be close to them, and is. |
| `register_pressure_torture` | Forty live `U32` values in one loop, each update reading the value written on the line before. | Register allocation, spill code and the scheduling of a long dependent chain. |

All three arms of each are generated from one description and differ only in spelling. The
checksums agree across Prismio, C++ and Rust (the harness fails otherwise).

### Results (Apple silicon, 9 runs, median, `--rebuild`, compiler built from this tree)

Time against C++ and peak RSS against C++, for the arms as the three languages write them. *10-16* is the
first run, before any of the fixes below; *10-17* is after `v[k] = x` released a displaced element of a local
Vec (CHANGELOG); *10-21* is after field stores, stores through a field's Vec, per-declaration binding keys and
the field-assignment spelling of the arms (`nodes[u].edges = ...`, in all three languages); **now** is after a
small Vec's header and first element block became one allocation (below).

| Benchmark | Prismio now | C++ | Rust | vs C++ 10-16 | 10-17 | 10-21 | **now** | vs Rust now | RSS Prismio 10-16 | **now** | RSS vs C++ 10-16 | **now** |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `graph_churn_single` | 23.1 ms | 18.0 ms | 17.4 ms | 2.14x | 1.93x | 1.67x | **1.28x** | 1.33x | 30.0 MB | **5.6 MB** | 8.1x | **1.53x** |
| `graph_churn_alloc` | 52.8 ms | 35.7 ms | 33.4 ms | 1.90x | 1.55x | 1.53x | **1.48x** | 1.58x | 89.6 MB | **4.0 MB** | 32.0x | **1.41x** |
| `graph_churn_transfer` | 36.2 ms | 29.3 ms | 24.1 ms | 2.47x | 1.79x | 1.84x | **1.24x** | 1.50x | 58.1 MB | **2.2 MB** | 30.3x | **1.14x** |
| `graph_churn_full` | 111.2 ms | 81.5 ms | 76.1 ms | 1.99x | 1.68x | 1.63x | **1.36x** | 1.46x | 96.0 MB | **7.0 MB** | 19.3x | **1.47x** |
| `register_pressure_torture` | 14.9 ms | 15.0 ms | 14.9 ms | 1.00x | | | 1.00x | 1.00x | 1.7 MB | 1.7 MB | 1.05x | 1.05x |

`--verify` on all four graph arms (`graph_churn_*` built from `suite.psm`): 0 leaked, 0 violations, and the
peak live bytes are what the program needs rather than what it ever allocated.

| Arm | blocks allocated = released, 10-16 | now | peak live, 10-16 (parked) | peak live, now |
| --- | ---: | ---: | ---: | ---: |
| `graph_churn_single` | 873,059 | 363,569 | 22.5 MB | 4.03 MB |
| `graph_churn_alloc` | 2,521,048 | 1,680,702 | 78.1 MB | 2.07 MB |
| `graph_churn_transfer` | 1,619,876 | 950,018 | 47.5 MB | 0.18 MB |
| `graph_churn_full` | 5,013,971 | 2,994,277 | 148.1 MB | 4.03 MB |

(`graph_churn_single` allocates fewer blocks than it did because a node killed or revived now replaces its edge
list instead of building a whole new node, and every block count dropped again when a small Vec's header and
elements became one block. The peak live bytes rose by about 12% for that: a fused header is padded to 16 bytes.)

Read three things from it.

1. **Memory is closed and the time gap is 1.2x to 1.5x.** Peak memory is 1.1x to 1.5x of C++ where it was 8x to 32x,
   and the time gap fell from 1.9x-2.5x to 1.24x-1.48x. What is left is allocation count and cost. A sample of
   `graph_churn_alloc` puts about half its time in libc's `malloc` and `free`, and it makes 1.68M allocations to C++'s
   ~0.8M, because C++ and Rust keep each `ChurnNode` inline in the vector and own one buffer per node, while
   Prismio boxes a struct that owns a `Vec`: the node, then the `Vec` (header and elements together, since the fusion)
   -- two blocks per node where it was three, and a pointer chase on every `nodes[u].field`. Two things would close
   the rest, and neither is built: storing a struct that owns a Vec inline in the element Vec (per-element release
   hooks on overwrite, removal and teardown, and a shell-free push), and a small-block allocator of the runtime's
   own (the recycler in `lang_runtime.c` is capped at 512 blocks, off once a program spawns, and asks the system
   allocator for each block's size on every free; codegen allocates objects with libc `malloc` directly).
   The second is a cross-cutting change to the "any block is a malloc block" invariant `C_CODE_STYLE.md` states, and
   needs its own design.
2. **`register_pressure_torture` is at parity, and that is a tripwire, not a victory.** All
   three arms go through LLVM, so register allocation is shared; a regression would mean the
   IR Prismio emits changed shape. Its first version had independent updates, every compiler
   vectorised it, and all three tied at 6.7 ms while doing more work than a scalar core can:
   a tie at a speed that cannot be scalar is a benchmark measuring nothing. The serial
   dependence between consecutive lines is what fixed it, and the comment in
   `adversarial.psm` says so.
3. **The ledger is balanced on all four graph benchmarks** with the arms written the way a C++ or Rust
   programmer writes them first: field assignment, and one name for both the receive loop's `frag` and the final
   `for frag in recent`. Before the fixes below, `graph_churn_alloc` released 10 of 2,521,048 blocks and the
   first Prismio arm of `graph_churn_single` leaked 542,258 of 634,698.

## Done: a small Vec is one allocation

A `Vec` was two blocks, the header (`RtList`, 64 bytes) and its element block, and a program that builds a small
`Vec` per node pays two `malloc`s, two `free`s and two cache lines for each. `list_new_cap`
(`runtime/lang_runtime.c`) now makes them one block when the capacity is known, the elements take at most 256 bytes,
and the list is a heap list (no arena): `data` points just past the header (`RtList.fused`). The first growth,
`reserve`, or an inline-stamp copies the elements to a block of their own and clears the flag, and every site that
frees or resizes `data` goes through `list_free_data` / checks `fused`, so nothing frees an interior pointer. A
`Vec` made with no capacity, or a large one, is two blocks as before.

Effect on the four arms: blocks allocated down 33% to 42%, time from 1.53x-1.84x to 1.24x-1.48x of C++, and every
leak count that counts blocks halves (`test_302` 4 to 2, `test_321` 600 to 300: a leaked list is one block now).
`test_323_fused_list`: growth by push, by `reserve`, past the 256-byte limit at construction, boxed, inline and
`String` elements, a `Vec` field replaced in a loop, truncate-and-refill; 0 leaked, 0 violations.

The header is padded to 16 bytes inside a fused block, so a program with many tiny Vecs holds up to 12% more peak
bytes (`graph_churn_single`: 3.55 MB to 4.03 MB) and 1.2x to 1.5x of C++'s RSS where it had 1.19x to 1.49x.

## Fixed: a fresh struct in two Vecs of one type stopped the first from releasing

**Symptom.** Overwriting an element of one `Vec<F>` leaked the displaced `F` and everything it
owned, as soon as any second `Vec<F>` was pushed a result of the same function.

```
struct N { value: Int, edges: Vec<Int> }
struct F { nodes: Vec<N>, id: Int }
fn mk(i: Int) -> F { /* builds three N, each with its own Vec<Int> */ }

let mut slots: Vec<F> = ...        // filled with mk(i)
let mut kept:  Vec<F> = ...
for step in 0..<1000 {
    slots[step % 4] = mk(step)
    if (step % 50 == 0) { kept.push(mk(step)) }
}
// before: 12294 allocated, 1030 released, 11264 leaked
// after:  12294 allocated, 12294 released, 0 leaked
```

**Cause.** A-CONTAIN (`runtime/aif_support.c`, the pass that counts which containers hold a
site) reads "two containers hold one site" as "one value, two holders" and raises the site to
Shared. A site is a *function's* allocation, not one value, so two containers each holding a
result of `mk` look like one value held twice. Shared sends a struct that owns a `Vec` to the
counted tier, which cannot release it, so nothing in either container was released.
`test_255` fixed exactly this for `String` and wrote down why it is sound: storing one
binding twice is "use of moved value" in sema, and a parameter is a borrow that cannot be
retained, so two holders of a freshly made value are two values.

**Fix.** The exemption `test_255` made for `String` now covers every move-only site
(`site_is_move_only`: structs, and Vec, array and String under owned collections), still
excluding a site whose value was stored as an element read (`view_stored`), which is the one
shape that really is one value in several containers. One line, in the A-CONTAIN rule.

**Guard.** `tests/test_302_struct_in_two_vecs.psm`, listed in `tests/test_runner.py`
(`run_aif_verify_test`): the two-Vec shape above must leak 0, and the element-read-pushed-
twice shape, on a type of its own, must report **0 violations** (its 2 leaked blocks, 4 before a small Vec became one block, are by
design). The adversarial probes (element read pushed into two Vecs; moved into a third) read
the same as before the change: 0 violations, same leaks. Full suite 614/614.

## Fixed: same-named bindings shared one analysis key

**Symptom.** A `let` in a loop and a *later* `for` binder of the same name in the same function were one variable
to the ownership analysis. The `for` binder is a view of an element; so the earlier `let`'s store was read as a
view store, which taints every site of that type.

```
for step in 0..<500 { let n = mk(step)  slots[step % 4] = n }
for n in other { t = t + n.value }        // before: 1528 allocated, 512 released, 1016 leaked
                                          // after:  1528 allocated, 1528 released, 0 leaked
```

In `graph_churn_transfer` the binder was `frag` in both places, and it cost the whole program its releases; the
benchmark had spelled the second one `old` to avoid it. It is `frag` again. The same shape with a channel
(`let v = ...; c.send(v)` and a later `for v in c`) was a separate `KNOWN_ISSUES` entry and is fixed by the same change.

**Cause.** Variable keys were `(function, name)` (`aif_key_var`, `runtime/aif_support.c`), and
`aif_var_note_scope` joined two declarations of one name outward to their common ancestor.

**Fix.** The walk (`src/aif/walk.psm`) brackets every block, function and match arm with
`aif_env_enter` / `aif_env_leave`, and the engine keeps the bindings in scope: a read or a store resolves to the
innermost visible declaration of its name, as the source does. The first declaration of a name in a function keeps the
plain `(function, name)` key, so a function that never repeats a name builds the keys it always did and the by-name
lookup codegen makes (`aif_frees_unless_returned_node`) still lands on it; later ones are `name#1`, `name#2`. The
declaration is made after its initialiser is walked, so `let s = s.trim()` reads the binding it shadows. The Python
oracle (`tools/aif_oracle/aif.py`) mirrors it, and `tools/aif_differential.py` agrees on every program it compared before
(the `src/main.psm` row differed by one site before this change too). No new syntax, so no seed step.

**The second analysis with the same flaw.** `src/ir/overwrites.psm` (the "no view can be live" proof) also
identified bindings by name, so after the rename above `recent[seen % ring] = frag` was refused -- the receive loop's
`frag` looked like the later `for frag in recent`, a holder of a view -- and the ring's elements parked again: peak 38 MB
instead of 0.19 MB, 65 ms instead of 53. It now resolves every mention to a declaration as it walks and works on sets
of declarations, so the two are told apart there too.

**Guard.** `test_322_binding_keys` (sequential loops with the owner first and the binder first, sibling blocks with
one name, an inner shadow, `let n = f(n)`): 0 leaked, 0 violations, and the peak is bounded.

**Not changed.** The frontend's syntactic guards keep refusing a name bound more than once
(`chainBindingCount`, `test_205`'s inner `let a = a`). They were written because the engine's key was per name, and can
be lifted now; a refusal only leaks, so that is a separate step.

## Fixed: assigning a struct field did not release the value it replaced

```
let mut n = N { value: 1, edges: mkv(0) }
for step in 0..<1000 { n.edges = mkv(step) }
// before: 2002 allocated, 2 released, 2000 leaked
// after:  2002 allocated, 2002 released, 0 leaked, peak 536 bytes
```

Also through an index (`nodes[u].edges = ...`: 2026 allocated, 26 released, before) and a field's own Vec
(`frag.nodes[i].edges = ...`, `frag.nodes[i] = ...`). The release used to be emitted only when the receiver was a
fresh local and nothing between its declaration and the store mentioned it.

**Fix.** `overwriteFieldStoreProved` is the removal verdict's "no view can be live" proof (the one a `v[k] = x`
overwrite uses) with the root of the target's path as the container: a local made by a struct literal, by a call
that returns an owner, by `expect` of a received value (`chan_recv`), or by a fresh `Vec`; no view of it leaves the
function's bindings; the new value mentions none of them; none is live at the store. One difference from the Vec
case: the root being *moved* (sent, pushed, returned) is not a view of the displaced value leaving, so it does not
count against the store -- without that `churnTrim`, which sends the fragment it just edited, never qualified.
`generateAssignment` (`src/ir/stmt.psm`) releases the displaced list when this or the older syntactic rule
(`irMarkDisplacedFieldStores`) says so and the type releases the field as a list. The `list_set` half of the same
change lets `frag.nodes[i] = ...` release now through a field's Vec.

**Guard.** `test_320_field_store_release` (six shapes that release, peak 512 bytes against 720,360 leaked) and
`test_321_field_store_parks` (a view read after the store, a view carried into the next iteration, the new value built
from the old: all keep the old value, 0 violations). Probed as the double-free class: an element read pushed into two
containers then field-stored (0 violations, unchanged leaks), a root moved after the stores, a store in one branch
read in the other.

## Fixed: an overwritten element was parked until its Vec died

```
let mut slots: Vec<N> = ...        // 4 elements
for step in 0..<2000 { slots[step % 4] = mk(step) }
// 6014 allocated, 6014 released, 0 leaked, peak live 160,408 bytes = everything
```

The ledger balances, but only at scope exit: every displaced element is held until the Vec is
torn down. `list_set` (`runtime/lang_runtime.c`) parks the old element under every uncounted
ownership mode, because a view of it might still be live; `list_set_exclusive`, which frees at
once, is admitted only for a local Vec that is never indexed, sliced or handed to a call.
`graph_churn_alloc` indexes its window, so it never qualifies.

**This is the gap in the table.** 8x to 32x the peak memory of C++ is the parked elements;
the 1.9x to 2.5x time is allocating into a heap that never reuses a block, so every allocation
is a fresh cache line. It is the same proof as the previous entry, from the element side.
`vecRemovalReleasesNow` (`src/ir/expr.psm`) already does it for removals (`test_161` peaks at
208 bytes against 35,102 parked); an indexed overwrite is the same question with a different
verb, and is the next obvious customer of `semaRemovalVerdict`.

**Since 2026-10-17** a store into a local Vec releases the displaced element at once wherever no view of an
element can be live (`src/ir/overwrites.psm`; the CHANGELOG has the proof's four conditions), and since
2026-10-21 the same for a store through a field's Vec (`frag.nodes[i] = ...`, the root a local struct that may be
moved on afterwards). Peak memory on the four benchmarks is 1.2x to 1.5x of C++ and time 1.5x to 1.8x. The
remaining time gap is representation: C++ and Rust keep each `ChurnNode` inline in the vector, and Prismio
boxes a struct that owns a `Vec`, so every node is a heap object of its own and every `nodes[u].field` a
pointer chase.

## Fixed: the move checker rejected exclusive branches

```
let n = mk(i)
if (ring.length < 2) { ring.push(n) } else { ring[i % 2] = n }
// was: error[P4001]: use of moved value `n`   (on the else arm)
```

Moved-from state was one set filled in source order, so the `then` arm's move was visible in the `else` arm and after a
`continue`. Each arm of an `if` / `else if` and of a `match` now starts from the state the branches opened with, an arm
that cannot fall through (`return`, `break`, `continue`, `panic`) hands none of its moves to the code after, and
the state after is the union of the arms that can (`ir_moved_branches_*`, `runtime/ir_symbols.c`; `semaIfStatement` and
the match statements). It only accepts more programs. `test_319_exclusive_branch_moves` holds the shapes that now
compile; `neg_313_moved_in_one_branch` holds the one that must not (a move on a path that reaches the use). The ring in
`graph_churn_transfer` is still prefilled with empty fragments so that all three arms agree.

## Open: moving a field out of an element view releases it twice

Found writing `test_317`; the same with or without the change above.

```
let old = slots[k]                                       // a view of the element
slots[k] = Node { value: old.value + 1, edges: old.edges }
// --verify: 54 allocated, 54 released, 80 violation(s)  -- a double release
```

`old.edges` is moved out of a borrowed view into the new element, so the parked old element and the new one
both own the edge list. In other shapes the same move leaks instead (`let a = Node { edges: old.edges }`: 2
leaked). Sema should refuse a move out of a view, as it refuses `list_push(dst, b)` on a parameter ("cannot
move out of borrowed value"), or copy it; which one is a language decision.

## Open: assigning a view to an owning local leaks the value it replaced

```
let mut last = make(-1)
for step in 0..<40 { last = slots[step % 4] }            // 3 leaked: make(-1)'s blocks
```

## Not bugs, but the next reader will trip on them

- `&&` and `||` are `and` and `or`.
- `Vec.pop()` requires `T: Copy`; an owned element cannot be popped (the moving `pop` is
  deferred in `COLLECTIONS.md` 1e).
- `.prismio/build/debug/prismio` is a launcher that forwards to `.prismio/build/release` unless
  `PRISMIO_INTERNAL_HOSTED=1` is set, so a freshly built compiler is not the one that runs
  until it is. The first leak measurements in this work used the old compiler for that
  reason; every number above is with the variable set.
- A partial benchmark run (`--only`) writes `benchmarks/results/results.json` like a full one, and the suite's
  `workloads` test reads the checksums it holds, so it fails with "expected None" afterwards. Give a partial run
  `--output <scratch file>`.
- `benchmarks/run.py` refuses a compiler older than `std/` or `src/` and needs
  `--allow-stale-compiler`; `--rebuild` is needed after a compiler change, because a cached
  arm is keyed on its sources, not on the compiler that built it.

## Where each fix lives

| Item | File | State |
| --- | --- | --- |
| Per-declaration binding keys | `runtime/aif_support.c` (`aif_env_*`, `aif_var_note_scope`), `src/aif/walk.psm`, `tools/aif_oracle/aif.py` | done 2026-10-21 |
| Field store releases the displaced value | `src/ir/overwrites.psm` (`overwriteFieldStoreProved`), `src/ir/stmt.psm` (`fieldStoreReleasesDisplaced`) | done 2026-10-21 |
| Indexed overwrite releases at once | `src/ir/overwrites.psm`: a local Vec 2026-10-17, a field's Vec 2026-10-21 | done |
| Exclusive branches in the move checker | `src/sema/checker.psm`, `src/sema/flow.psm`, `runtime/ir_symbols.c` | done 2026-10-21 |
| Move out of an element view | sema's move check, or a copy | open: refusing changes which programs compile |
| View assigned to an owning local | codegen's assignment release | open |
| Small Vec header and elements in one block | `runtime/lang_runtime.c` (`list_new_cap`, `list_free_data`) | done 2026-10-21 |
| Structs that own a Vec stored inline in a Vec | layout (`src/ir/types.psm`, `contents.psm`), per-element release in the runtime | not started |
| A small-block allocator of the runtime's own | `runtime/lang_runtime.c` (`rt_base_alloc`, `rt_free`), `g_alloc_fn` in `llvm-api-backend.c` | not started: needs a design (the interchangeability invariant, threads) |
