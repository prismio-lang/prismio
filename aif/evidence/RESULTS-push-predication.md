# E1: the push check belongs in the preheader, and the profile it was said to need does not exist

**Status: GREEN, 2026-09-05.** Two-generation byte-identical fixpoint, suite
**295/295** (new `test_126_push_predication.psm`), release gate 13 of 14 with the
one failure unchanged from baseline, all 34 checksums byte-identical, `--verify`
0 leaked / 0 violations on every corpus program.

**This refutes `RESULTS-inline-push-rejected.md`'s conclusion.** That file
measured the same fast path at **1.275x on g6** and concluded that separating the
programs it helps from the ones it hurts "needs a profile — pushes-per-list — a
profile fact, not a type fact". It does not. It needs the check moved.

## 1 · The distinction that was missing

The rejected version emitted `elem_size == S && len < cap` **at each push site**,
with `list_push_slot` on the slow arm. g6's `plan_orders` builds a fresh
short-lived list per squad per frame, so almost every push grows: the check was
paid every iteration and essentially never won.

E1 proves the same facts **once, for the whole loop**, in the preheader:

```
elem_size(recv) == S  &&  cap(recv) - len(recv) >= trip_count * pushes_per_iteration
```

If that holds, every push in the body is a store and a length bump with **no test
of any kind** — strictly less work than the rejected form, which still branched
per push. If it does not hold, the ordinary loop runs unchanged and the whole cost
is one comparison per loop *entry*.

A list from `list_new()` has capacity 0 and fails the conjunct. **The runtime
guard is the profile**, evaluated in the place the offline one was being asked
for. This is HotSpot's loop predication aimed at the capacity check instead of the
range check, and it is the fourth time that shape has paid in this compiler.

## 2 · The g6 test, which is the whole point

`tools/fn_mnemonic_diff.py` on `aif/corpus/g6_game.psm`:

| function | rejected version | **E1** |
|---|---:|---:|
| `world_spawn` | 37 -> **115** | **unchanged** |
| `recruit` | 57 -> **160** | **unchanged** |
| `plan_orders` | 78 -> 104 | 78 -> 135 |

`world_spawn` and `recruit` make straight-line pushes outside any loop, so no loop
guard exists to emit and they are not touched at all — the code growth that
doubled them is gone. `plan_orders` pushes in a loop, so it is versioned; its list
has capacity 0, so it takes the ordinary arm.

**g6_game measures 0.985 min / 1.005 p50**, against 1.275x for the rejected
version. 25 alternating runs; all seven corpus programs inside the noise band and
every output identical.

## 3 · The benchmark sweep

15 alternating samples. 19 of 457 functions changed.

| benchmark | min B/A | p50 B/A |
|---|---:|---:|
| prime_sieve | **0.943** | 0.937 |
| knapsack | **0.945** | 0.923 |
| fft | 0.976 | 0.996 |
| struct_creation | 0.993 | 1.001 |
| large_buffer_copy | 1.007 | 0.997 |

Worst reading is `tree_traversal` at 1.027, and `_benchTreeTraversal__Int` is not
among the changed functions.

## 4 · Why the two targets did not move, which is the finding worth keeping

E1 was built because `large_buffer_copy`'s fill loop is **4.2x C++** and
`struct_creation` had a real `bl _list_push_slot` in its hot loop. Both are now
checkless — the emitted loop is

```
ldr    x9, [x19]            ; data, hoisted to the preheader
...
ldrsw  x17, [x19, #0x8]     ; len
smaddl x0, w17, w13, x9     ; slot = data + len*40
add    w17, w17, #0x1
str    w17, [x19, #0x8]     ; len++
stp    d0, d3, [x0]         ; the element, in place
```

— and neither benchmark moved. Phase-timed, the fill loop is **0.994**.

**So the 4.2x is not call overhead, and it is not the capacity check.** Two
reasons, and both are now attributable:

- `list_push_inline_scalar` is already in `PRISMIO_CURATED_OPS`, so the *scalar*
  push already inlined to a check and a store. E1 removes 2-3 instructions from a
  loop that is storing to 8 MB.
- Both loops are **memory-bandwidth bound**, and C++'s arm is not doing the same
  work: `std::vector<int> source(n), target(n, 0)` bulk-constructs and then fills
  with a vectorised store loop.

**The reason Prismio's fill cannot vectorise is `len`.** It is loaded and stored
in the list header on every iteration, and LLVM will not promote it to a register
because it is an `i32` under TBAA leaf `"int"` — the same leaf as the element
stores of a `List<Int>`. Header and element may-alias, so the recurrence stays in
memory and the loop stays scalar.

That is the same collision Task 0.2 found in `ir_list_flat_elem`, and TBAA cannot
fix it: in C, `l->len` and `((int*)data)[k]` are both `int` lvalues and *do* alias
by the language's own rules. **The fact codegen has and C does not is that the
header and the element block are two separate allocations**, which is what
`!alias.scope` / `!noalias` exists to express. See E5 in
`MEMORY_OPTIMIZATION_AGENT_SPEC.md` §0.4.

E1 is the precondition for that: with the capacity proved, `len` is a pure
induction variable and the only thing keeping it in memory is the aliasing answer.

## 5 · What the guard promises, and what it does not

`pushes_per_iteration` is counted syntactically and is an **upper bound**: a
`continue`, a `break` or a push under an `if` performs fewer, never more. A nested
loop breaks that, and is refused outright. Any call the analysis does not
recognise is refused for the reason the representation guard refuses one — it
could push to the same receiver and spend the capacity being promised. A receiver
rebound in the body is refused, because the length and capacity are read once.
`test_126_push_predication.psm` is one arm per clause.
