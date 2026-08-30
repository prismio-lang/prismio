# Inlining the flat push: rejected, and why the obvious gate does not save it

**Status: REJECTED, 2026-08-30.** The change is reverted. `list_new`'s lazy
allocation, developed alongside it, is kept and measured separately.

## The finding that motivated it

Reading Prismio's `cull` next to Rust's, in `g2`:

```text
Rust      one function, `Vec::push` inlined, no call in the loop
Prismio   bl _list_push_slot in the loop body, once per element
```

`list_push_slot` cannot be curated into the caller — it reaches three `static`s
through `rt_alloc`, which `KNOWN_ISSUES.md` has recorded since M6 — so the
inliner never sees it. About 500 calls a frame over 20000 frames.

The common case needs no allocator: when the list is stamped at this stride and
has room, a push is an address computation and a length store. So codegen emitted
that, keeping `list_push_slot` on the slow arm for the lazy stamp, growth, the
arena and the boxed representation:

```text
cmp    w9, #0x18          ; elem_size == 24
ccmp   w8, w10, #0x0, eq  ; len < cap
b.ge   <slow>
ldr    x9, [x20]
smaddl x0, w8, w23, x9    ; slot = data + len*24
add    w8, w8, #0x1
str    w8, [x20, #0x8]
```

That is Rust's shape, and the call left the hot loop.

## Why it was rejected

Five-arm, 25 runs:

| program | new/old |
|---|---:|
| g2 | 0.971x |
| g4 | 0.975x |
| **g6** | **1.275x** |

A 27% regression on g6 against a 3% gain on g2. The corpus median stayed near
1.00x, which is exactly why the median is not the whole gate.

**Neither the release gate nor `milestone_bench.py` would have caught this as a
cost** — the gate passed. The five-arm did.

## Where it went wrong, and the gate that did not work

`tools/fn_mnemonic_diff.py` on g6:

```text
CHANGED: _world_spawn   37 -> 74 insns
CHANGED: _plan_orders   75 -> 89 insns
```

`world_spawn` makes **three straight-line pushes** into three lists and doubled
in size. The obvious inference is that the fast path is worth it in a loop and
not in straight-line code, so the emission was gated on loop depth.

**That gate restored `world_spawn` to 38 instructions and did not recover the
program: g6 stayed at 1.16x.** The cost is in `plan_orders`, whose push *is* in
a loop:

```psm
fn plan_orders(self, s: Squad) -> List<Order> {
    let mut orders: List<Order> = list_new()
    ...
    while (i < n) { ... list_push(orders, Order { ... }) ... }
}
```

It builds a **fresh, short-lived list per squad per frame**. Almost every push is
a growth, so the check is paid on every iteration and essentially never wins. g2's
`cull` pushes ~500 elements into one list, so after the first few growths every
push takes the fast arm.

The two are indistinguishable statically: both are `list_push` of a struct
literal, in a loop, into a list the function just created. What separates them is
the *expected number of pushes per list*, which is a profile fact, not a type
fact.

## What would make it viable

- **A profile.** LAYOUT 2 already runs declared workloads and feeds measured
  counts into layout selection. Pushes-per-list is the same kind of fact, and
  the same mechanism could carry it. This is the honest form of the fix.
- **Or a capacity hint at the site**, so the list is sized once and the fast arm
  is the common case by construction. That is a source change, and belongs in the
  tuned arm rather than the compiler.
- **Not** a static heuristic on loop depth. That was tried; it is recorded above
  as refuted.

## What was kept

`list_new` now allocates nothing until the first push, matching Rust's
`RawVec::NEW`. It used to hand back a four-pointer block that
`list_set_elem_inline` immediately freed and replaced at body width, so every
inline list paid a malloc and a free of pure waste. That change is independent of
this one and is measured on its own; `run_forced_layout_test`'s expected gap went
from `bodies - 1` to `bodies` because the `-1` *was* that wasted allocation.
