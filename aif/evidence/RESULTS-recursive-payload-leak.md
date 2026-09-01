# `g8_tree_rebuild` leaks 12,282 of 12,284, and it is two mechanisms, not one

**Status: FIXED for the general case, 2026-09-01.** §1–6 are the diagnosis, made
against `build/host-routing-locked7`; §7 is what changed and what it moved. Both
mechanisms turned out to be one — a site is per function, not per instance — and
both are closed. g8 itself keeps a residue that is **not** this defect: 8,188
allocations belonging to the `sink` reuse feature the workload was written to
measure, and which its own header says is not landed.

The standing account of this leak, recorded in `runtime/aif_support.c` above the
type-release cache and again in the header of `tests/test_73_recursive_release.psm`,
is **"ownership transfer survives exactly one hop"**. That account is refuted
below: a four-level chain of *distinct* functions transfers ownership through
every hop and reclaims all 16 allocations. The trigger is not depth. It is
self-recursion, and it fires through two independent doors.

## 1 · The baseline

```
$ prismio run aif/evidence/xlang/prismio/g8_tree_rebuild.psm --verify
aif-verify: 12284 allocated, 2 released, 12282 leaked, 0 violation(s)
```

**0 violations.** The ledger's correctness column is clean and stays clean — this
is the balanced-ledger trap in its quiet direction, where nothing is wrong except
that the memory never comes back. A reader checking only the violation count sees
a passing program.

## 2 · What was refuted

Each row is the same `enum Tree { Leaf, Node(Tree, Int, Tree) }` and the same
`sum`. Only the shape of the producer changes.

| # | producer | ledger | |
|---|---|---|---|
| A | `build` self-recursive, depth 3 | 16 / 1 / **15 leaked** | |
| B | `makeTree` inline (test_73's shape) | 8 / 8 / 0 | M2.1a works |
| C | `outer` returns `leafPair(k)` — depth 2 | 4 / 4 / 0 | one hop is not the limit |
| D | `Tree.Node(leafPair(k), k, Tree.Leaf)` | 6 / 6 / 0 | a call result *inside a constructor* is fine |
| E | `lvl3 → lvl2 → lvl1 → lvl0`, four distinct fns | 16 / 16 / 0 | **four hops, all clean** |
| F | the same recursion as E, written self-recursively, depth 1 | 4 / 1 / **3 leaked** | |

C, D and E each cross more than one frame and each reclaims everything. The
one-hop account cannot survive E, which is E's purpose. F is E's algorithm with
the levels collapsed into one self-recursive function, and it leaks.

## 3 · Mechanism 1 — self-recursion collapses the root onto a child site

A site is per *function*, not per *instance*. In

```prismio
fn build(depth: Int, seed: Int) -> Tree {
    if (depth == 0) { return Tree.Leaf }
    return Tree.Node(build(depth - 1, seed * 2), seed, build(depth - 1, seed * 2 + 1))
}
```

the constructor is **one site playing two roles**: the root the caller is meant to
own, and every interior node stored into a `Tree` payload field. Because the
child role stores it into a field the type releases, `site_in_released_field`
answers yes — correctly, that guard is what stops `__aif_release_Tree` and the
caller both freeing an interior node. But `aif_owns_call_result_at_node`
(`runtime/aif_support.c:6771`) reads the same answer for the *root*, and declines
to give the caller ownership of it. The root is never dropped, `__aif_release_Tree`
never runs, and the structure it would have recursed through leaks entire.

The generated release is not missing. Both binaries carry `__aif_release_Tree`;
only the call is absent.

**The controlled test.** G is F with the root construction moved into a one-line
non-recursive wrapper — the identical recursion, the identical allocation count,
the root now at a site of its own:

| | ledger |
|---|---|
| F — root shares the child's site | 4 / 1 / **3 leaked** |
| G — root at a distinct site | 8 / 8 / **0** |

At scale, hoisting `build`'s root alone moves g8 from **2 released to 2,049** —
the whole initial tree, 2,047 nodes, reclaimed. Checksum `tree 528891` unchanged.

This is INFERENCE 6's ownership contexts by another road: the fix is for the
analysis to distinguish the instance the caller receives from the instances the
recursion buries, either by instantiating per call site or by making
`site_in_released_field` a per-instance question rather than a per-site one.

## 4 · Mechanism 2 — one parameter-returning path vetoes the whole return set

Hoisting `mapAdd`'s root as well changes nothing: g8 stays at 2,049 released,
10,235 leaked — exactly the five rebuild passes, 5 × 2,047. Those leak for a
different reason, and it is in the pass-through guard:

```c
if (sites[s].fn != c->fn && fn_may_return_param(c->fn)) return AIF_ELEM_NONE;
```

`fn_may_return_param` is a fact about the **function**, applied to **every site**
in its return set. `passes` returns its parameter on the base path:

```prismio
fn passes(sink t: Tree, n: Int) -> Tree {
    if (n == 0) { return t }
    return passes(mapAdd(t, 1), n - 1)
}
```

so the fact is true, and ownership is refused for every site `passes` may return
— including `mapAdd`'s, which are demonstrably fresh allocations that no
parameter can alias. The hazard the guard exists for is real; its granularity is
not. The per-site information is already at hand one clause earlier.

| | ledger |
|---|---|
| H — `pick` returns a parameter on one path | 4 / 1 / **3 leaked** |
| I — the same, base path rebuilds instead | 4 / 4 / **0** |

**Mechanism 2 cannot be neutralised inside g8**, which is worth recording because
it bounds what a fix can be measured against. Rewriting `passes` so no path
returns `t` is rejected:

```
error[P4001]: use of moved value `t`
  --> g8_neutralised.psm:52:30
```

Move state is tracked per name in source order and is not path-sensitive, so the
two arms of an `if`/`else` each count as a move of `t`. That is the same
limitation the workload's own header cites for why the pass loop is recursion
rather than a `while`.

## 5 · What this changes about the plan

The fix named in the standing notes — teaching the site disposition that a
Prismio call returning an owned `T` is plain — is **not the blocker**.
`aif_owns_call_result_at_node` already accepts `AIF_ELEM_TYPED` and
`AIF_ELEM_OBJECT`, and the manifest already reports all nine of g8's sites as
`T2 / owned`. The tiering is right; the release is refused downstream of it.

Two changes, separable, and the second is much the cheaper:

1. Per-instance ownership for a self-recursive producer (mechanism 1) — 2,047 of
   g8's allocations. This is the project INFERENCE 6 describes.
2. Per-site rather than per-function pass-through exclusion (mechanism 2) —
   10,235 of them. Ask whether *this site* may be the parameter, not whether the
   function has any parameter-returning path.

Both change emitted code, so neither is covered by the byte-identical fixpoint
rule; both need the full suite, `tools/aif_differential.py`, and a fixpoint of
their own.

## 6 · Reproducers

The programs above are minimal and are deliberately **not** in the tree: each
failing half leaks by design, and `aif/evidence/xlang/prismio/` is swept by
`run_corpus_test` and by `--verify`, so landing them now would turn a sweep red
for a defect already recorded here. They are worth adding as fixtures with
asserted ledgers once either mechanism is fixed — F/G and H/I in particular,
because each pair differs by one refactor and nothing else, which is the
discrimination `test_73` says it wants and does not currently have for the
recursive shape.

Both pairs are reproduced here in full so this file stands on its own. Each
block below holds *two* programs: assemble one by taking the prelude, then the
shared helpers, then exactly one `main`. All four were assembled that way
mechanically from this file and reproduce the ledgers quoted. Each shares the
same prelude:

```prismio
import std.io

enum Tree {
    Leaf,
    Node(Tree, Int, Tree)
}

fn sum(t: Tree) -> Int {
    match (t) {
        Tree.Leaf => { return 0 }
        Tree.Node(l, v, r) => { return sum(l) + v + sum(r) }
    }
    return 0
}
```

**Pair 1 — mechanism 1.** F leaks 3 of 4; G reclaims 8 of 8. The recursion is
character-for-character identical; only the root's site differs.

```prismio
fn build(depth: Int, seed: Int) -> Tree {
    if (depth == 0) { return Tree.Leaf }
    return Tree.Node(build(depth - 1, seed), seed, build(depth - 1, seed))
}

// F: the root is the same site as every child.       4 / 1 / 3 leaked
fn main() -> Int {
    let t = build(1, 7)
    println(sum(t))
    return 0
}

// G: the root gets a site of its own.                8 / 8 / 0
fn buildRoot(depth: Int, seed: Int) -> Tree {
    return Tree.Node(build(depth - 1, seed), seed, build(depth - 1, seed))
}
fn main() -> Int {
    let t = buildRoot(2, 7)
    println(sum(t))
    return 0
}
```

**Pair 2 — mechanism 2.** H leaks 3 of 4; I reclaims 4 of 4. The only difference
is whether one path returns a parameter.

```prismio
fn make(k: Int) -> Tree {
    return Tree.Node(Tree.Leaf, k, Tree.Leaf)
}

// H: the base path returns a parameter.              4 / 1 / 3 leaked
fn pick(sink t: Tree, n: Int) -> Tree {
    if (n == 0) { return t }
    return make(n)
}
fn main() -> Int {
    let t = pick(make(1), 0)
    println(sum(t))
    return 0
}

// I: no path returns a parameter.                    4 / 4 / 0
fn pick(n: Int) -> Tree {
    if (n == 0) { return make(0) }
    return make(n)
}
fn main() -> Int {
    let t = pick(0)
    println(sum(t))
    return 0
}
```

## 7 · The fix

Two clauses in `aif_owns_call_result_at_node`, and one new fact.

**Mechanism 1 — `in_recursive_released_field`.** `compute_released_fields` now
accumulates two bitsets beside the union it already built, split by
`field_closes_cycle`. The call-result query declines only for a site that lands
in a released field which does *not* re-enter its owner's type. Where the field
recurses, the field's release and the caller's drop are the same traversal, so
the caller is not a second release point — and `field_release_of` has already
required the tree shape that argument needs. The two scope-exit callers of
`site_in_released_field` are untouched; they ask a different question, about a
value and a container sharing a frame.

**Mechanism 2 — `sink` reaches the analysis.** The pass-through guard read
`fn_may_return_param`, one bit for the whole callee, and applied it to every site
the call might return. Narrowing it per site was not enough on its own: `passes`
feeds `mapAdd`'s output back into its own parameter, so the parameter really does
point at those sites. What separates them is the **contract**: a `sink` parameter
is a move, the caller's binding is dead after the call, and sema enforces it. So
`aif_note_param_consuming` records it from the declaration in `src/aif/walk.psm`,
and `site_may_be_param_of` skips those parameters. A borrow parameter still
declines exactly as before.

### What moved

| | before | after | |
|---|---:|---:|---|
| F — self-recursive root | 4 / 1 / **3 leaked** | 4 / 4 / **0** | |
| G — root at a distinct site | 8 / 8 / 0 | 8 / 8 / 0 | unchanged |
| H — returns a `sink` parameter | 4 / 1 / **3 leaked** | 4 / 4 / **0** | |
| I — returns no parameter | 4 / 4 / 0 | 4 / 4 / 0 | unchanged |
| `g8_tree_rebuild` | 12,284 / **2** / 12,282 | 12,284 / **4,096** / 8,188 | checksum `528891` both |
| `test_74_reinit_assignment` | 255 / 7 / 248 | 255 / **162** / 93 | violations 0 both |

**g8's residue is the reuse feature, not this one.** Written with the pass loop
unrolled — the same algorithm, `passes` expanded into five `mapAdd` calls — it
reads **12,284 / 12,284 / 0**, checksum unchanged. What the recursive form still
leaks is the intermediate consumed by each `sink`, which nothing reclaims because
`mapAdd` does not yet free the block it destructures. That is M2.1's reuse token,
which this workload exists to measure and which its header says is not landed.
`test_74`'s note records the same residue and predicted this fall.

**Gates:** fixpoint identical, suite **206/206**, AIF differential unchanged from
the baseline (the same 2 pre-existing `src/main.psm` disagreements, present on
`build/base-gen1` too). `test_74`'s expected leak count moves 248 → 93 in the
runner, which is more frees at an unchanged allocation count.
