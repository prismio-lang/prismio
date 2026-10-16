# What `graph_churn_*` and `register_pressure_torture` found

Written 2026-10-16. Five benchmarks were added (`benchmarks/hosted/*/graph_churn.*` and
`register_pressure_torture` in `adversarial.*`). Writing the Prismio arm of the first four
turned up one compiler bug that is fixed, four that are not, and a measurable gap. This file
is the record: each entry has a reproducer small enough to paste, what it costs, and where
the fix lives. `docs/KNOWN_ISSUES.md` points here for these.

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

| Benchmark | Prismio | C++ | Rust | vs C++ | vs Rust | RSS Prismio | RSS vs C++ |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `graph_churn_single` | 38.5 ms | 18.0 ms | 17.6 ms | 2.14x | 2.19x | 30.0 MB | 8.1x |
| `graph_churn_alloc` | 64.0 ms | 33.6 ms | 33.2 ms | 1.90x | 1.93x | 89.6 MB | 32.0x |
| `graph_churn_transfer` | 66.5 ms | 27.0 ms | 23.8 ms | 2.47x | 2.79x | 58.1 MB | 30.3x |
| `graph_churn_full` | 157.9 ms | 79.5 ms | 74.0 ms | 1.99x | 2.13x | 96.0 MB | 19.3x |
| `register_pressure_torture` | 14.9 ms | 15.0 ms | 14.9 ms | 1.00x | 1.00x | 1.7 MB | 1.05x |

Read three things from it.

1. **Allocation-heavy graph code is about 2x C++ and Rust, and the cause is measured below**
   (the displaced element is parked, not freed). Peak memory is 8x to 32x, which is the same
   cause seen from the other side.
2. **`register_pressure_torture` is at parity, and that is a tripwire, not a victory.** All
   three arms go through LLVM, so register allocation is shared; a regression would mean the
   IR Prismio emits changed shape. Its first version had independent updates, every compiler
   vectorised it, and all three tied at 6.7 ms while doing more work than a scalar core can:
   a tie at a speed that cannot be scalar is a benchmark measuring nothing. The serial
   dependence between consecutive lines is what fixed it, and the comment in
   `adversarial.psm` says so.
3. **The ledger is balanced on all four graph benchmarks** (`--verify`: 0 leaked, 0
   violations; `graph_churn_full` 5,013,971 allocated, 5,013,971 released), after the fix
   below. Before it, `graph_churn_alloc` released 10 of 2,521,048 blocks.

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
twice shape, on a type of its own, must report **0 violations** (its 4 leaked blocks are by
design). The adversarial probes (element read pushed into two Vecs; moved into a third) read
the same as before the change: 0 violations, same leaks. Full suite 614/614.

## Open: same-named bindings share one analysis key

**Symptom.** A `let` in a loop and a *later* `for` binder of the same name in the same function
are one variable to the ownership analysis. The `for` binder is a view of an element; so the
earlier `let`'s store is read as a view store, which taints every site of that type.

```
for step in 0..<500 { let n = mk(step)  slots[step % 4] = n }
for n in other { t = t + n.value }        // 1528 allocated, 512 released, 1016 leaked
// rename the binder to `o`:              // 1528 allocated, 1528 released, 0 leaked
```

In `graph_churn_transfer` the binder was `frag` in both places, and it cost the whole program
its releases. The benchmark now names the second one `old`; **the arm is the same program in
all three languages, but the spelling was chosen to avoid this.**

**Cause.** Variable keys are `(function, name)` (`aif_key_var`, `runtime/aif_support.c`);
`aif_var_note_scope` joins two declarations of one name outward to their common ancestor.
`KNOWN_ISSUES.md` already records a case of it (`for v in c` over a channel) and says the fix
is per-declaration binding keys, in the engine and the oracle together.

**Why it is not fixed.** It changes how every local is identified in both the C engine and the
Prismio oracle (`src/aif/walk.psm`), and a wrong change reads as a double free. It is the
largest single item on this list and the one most worth doing.

## Open: assigning a struct field does not release the value it replaces

```
let mut n = N { value: 1, edges: mkv(0) }
for step in 0..<1000 { n.edges = mkv(step) }
// 2002 allocated, 2 released, 2000 leaked
```

Also through an index (`nodes[u].edges = ...`: 2026 allocated, 26 released). Known and
documented (`KNOWN_ISSUES.md`, *Assigning a struct field releases the value it replaces only
for a fresh local*): the release is only emitted when the receiver is a fresh local and
nothing between its declaration and the store mentions it. Closing the rest needs the removal
verdict's "no view can be live" proof (`COLLECTIONS.md` 1e), not a syntactic one.

**The benchmark avoids it** by replacing the whole node (`nodes[u] = ChurnNode { ... }`) in all
three arms, which is the same allocation and the same free in C++ and Rust. Written the way
the C++ and Rust programmers would write it first (`nodes[u].edges = Vec::new()`), the first
Prismio arm leaked 542,258 of 634,698 blocks.

## Fixed for a local Vec (2026-10-17): an overwritten element was parked until its Vec died

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
element can be live (`src/ir/overwrites.psm`; the CHANGELOG has the proof's four conditions). Peak memory on the
four benchmarks fell to 1.2x to 1.4x of C++ and time to 1.55x to 1.93x. Still parked: a store through a field
(`frag.nodes[i] = ...` in `churnTrim`), whose Vec is not a local of the function. The remaining time gap is
mostly representation: C++ and Rust keep each `ChurnNode` inline in the vector, and Prismio boxes a struct that
owns a `Vec`, so every node is a heap object of its own and every `nodes[u].field` a pointer chase.

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

## Open: the move checker does not see exclusive branches

```
let n = mk(i)
if (ring.length < 2) { ring.push(n) } else { ring[i % 2] = n }
// error[P4001]: use of moved value `n`   (on the else arm)
```

`continue` after the push is not seen either. Both arms are exclusive, so this is a false
positive: the program is correct and rejected. The ring in `graph_churn_transfer` is prefilled
with empty fragments so that every receive is a replacement and there is no branch; C++ and
Rust do the same so the arms agree. A flow-sensitive moved-state at joins (`src/sema/flow.psm`
already does definite-return that way) is what is missing. This one is cheap and is a
usability bug, not a performance one.

## Not bugs, but the next reader will trip on them

- `&&` and `||` are `and` and `or`.
- `Vec.pop()` requires `T: Copy`; an owned element cannot be popped (the moving `pop` is
  deferred in `COLLECTIONS.md` 1e).
- `.prismio/build/debug/prismio` is a launcher that forwards to `.prismio/build/release` unless
  `PRISMIO_INTERNAL_HOSTED=1` is set, so a freshly built compiler is not the one that runs
  until it is. The first leak measurements in this work used the old compiler for that
  reason; every number above is with the variable set.
- `benchmarks/run.py` refuses a compiler older than `std/` or `src/` and needs
  `--allow-stale-compiler`; `--rebuild` is needed after a compiler change, because a cached
  arm is keyed on its sources, not on the compiler that built it.

## Where each fix lives

| Item | File | Size | Risk |
| --- | --- | --- | --- |
| Per-declaration binding keys | `runtime/aif_support.c` (`aif_key_var`, scopes), `src/aif/walk.psm` | large | double free if the oracle and engine disagree; needs a seed-compatible two-step |
| Field store releases the displaced value | `src/ir/expr.psm` (`irMarkDisplacedFieldStores`), `src/ir/stmt.psm` | medium | the "no view can be live" proof |
| Indexed overwrite releases at once | done for a local Vec, `src/ir/overwrites.psm`; a field's Vec still parks | -- | -- |
| Move out of an element view | sema's move check, or a copy | small | refusing changes which programs compile |
| Exclusive branches in the move checker | `src/sema/flow.psm` | small | none for soundness (it only accepts more) |
