# M2.1a — recursive releases for self-referential types (fork (a))

**2026-08-23.** `build/S31b` → `build/S35b`. Suite **142/142**, fixpoint `a35.ll == b35.ll`,
differential 17/17, corpus median **1.006×** (0.939–1.031×), RSS flat. **GATE PASSED.**

Fork (a) of the two recorded in TODO § "M2.1's ground". The other was driving reuse off the RC/T4b
path; it was not taken.

---

## 1 · What was wrong

A self-referential type was reclaimed by **nothing**. `enum Tree { Leaf, Node(Tree, Int, Tree) }`
lowers to a tagged struct whose payload fields hold `Tree`, and:

- `field_closes_cycle` vetoed every field that re-enters its owner's type, so `aif_type_releases`
  answered 0 and **`__aif_release_Tree` was never generated at all**;
- the collector, which that veto defers to, wants `in_container`, and a tree node is not in one.

Both halves declined and the value fell between them. On the fixture below that is 100 of 106
allocations.

**The type graph cannot tell a tree from a cycle.** `Tree` reaches `Tree` exactly as
`Node { parent: Node? }` does, and `aif_compute_type_acyclic` calls both cyclic — so a veto keyed
on it declines every recursive type there is.

## 2 · The rule that replaced it

A field that re-enters its owner's type is released when **every site it can hold answers with a
plain ownership disposition** — `AIF_ELEM_TYPED` or `AIF_ELEM_OBJECT`. Those are the tree-shaped
ones, and releasing them recursively frees each block exactly once.

Two supporting facts, both the language's rather than this analysis's:

- **Field stores are moves.** `Node { id: 2, parent: root }` transfers `root`
  (`test_51_optional_refs` says so in its own comment), so a field store leaves exactly one owner.
  Single ownership is structural.
- **A counted or collected site still declines**, and that is the load-bearing half. Cyclic edges
  belong to the collector — CYCLES 4 gives them their own traversal, `__aif_cyclic_children_T` — so
  a release that also touched them reclaims an edge twice.

The in-progress marker in `type_releases_of` now reads as **"does release"** rather than "does
not". That is what makes the recursive field's disposition `AIF_ELEM_TYPED` instead of
`AIF_ELEM_OBJECT`, and the difference is the whole feature: `OBJECT` frees the child block alone
and leaks its subtree, `TYPED` calls `__aif_release_T` and the recursion reaches the leaves.

The emitted function, from `g8_tree_rebuild.psm`:

```llvm
define void @__aif_release_Tree(ptr %0) {
  ...
  %2 = getelementptr inbounds nuw %Tree, ptr %0, i32 0, i32 3
  %3 = load ptr, ptr %2
  call void @__aif_release_Tree(ptr %3)     ; right subtree
  %4 = getelementptr inbounds nuw %Tree, ptr %0, i32 0, i32 2
  %5 = load ptr, ptr %4
  call void @__aif_release_Tree(ptr %5)     ; left subtree
  call void @free(ptr %0)
}
```

Reverse field order, as everywhere else a scope unwinds, and the object last.

## 3 · Measured

`tests/test_73_recursive_release.psm`, discriminating by compiler:

| | allocated | released | leaked | violations |
|---|---|---|---|---|
| `S31b` (before) | 106 | 6 | **100** | 0 |
| `S35b` (after) | 106 | 106 | **0** | 0 |

**The allocation count is identical**, which is the point: the feature reclaims, it does not
allocate less. A change that "fixed" this by allocating fewer nodes would move the first number and
would not be this.

The seven corpus programs are unchanged and still clean — `allocated == released`, 0 leaked, 0
violations on all of them.

## 4 · The two failures on the way, both instructive

**Removing the veto wholesale broke `test_52_aif_cycle_collector`: 8 violations.** A genuinely
cyclic type got the recursive release instead of the collector. The first repair was wrong too —
`AIF_ELEM_CYCLE` had **no branch** in `generateReleaseFn` and was falling into the plain
`ir_free_object`, so a collected object was being freed a second time. It had been unreachable
because a cyclic disposition can only arise on a field that re-enters its owner's type, and the
veto blocked every one of those. Giving it the branch it needed (`ir_free_rc`, pairing with
`AIF_ELEM_CYCLE_ATOMIC` exactly as the atomic case already did) turned 8 violations into a **crash**
— because the release should not touch those edges at all.

The rule is therefore not "recursion is safe". It is **"recursion is safe for the edges the
collector does not own"**, and the disposition test is what says which. `test_52` is the guard for
that half and `test_73` for this one.

## 5 · Known limits, measured or explicitly not

**`g8_tree_rebuild.psm` is unchanged at 24570 leaked**, and it is worth being exact about why,
because it is the program this milestone exists for. Two separate gaps, neither of them this one:

- **`mapAdd` moves its payloads out.** `match` binds `l` and `r` and hands them to the recursive
  calls, so a *deep* release of the consumed node would free subtrees that were moved away. The
  compiler correctly declines. What that shape needs is a **shallow** free of the destructured
  block — which is exactly what M2.1b's reuse token replaces with a write.
- **Ownership transfer survives one hop.** A recursively-built tree returns sites belonging to its
  own recursive calls, so the caller owns nothing and no drop runs. This is INFERENCE 6's contexts,
  the same gap `test_47_aif_containers` records as its 6.

So M2.1a is **half of the drop**: it reclaims a self-referential structure that someone owns, and
the g8 shape does not yet have an owner.

**A tree inside an owning struct was written into the fixture twice and removed both times**, and it
is the sharpest thing found here. With the tree from a call it leaks 15 — a field initialised from a
call is a hop the model does not follow. With the tree built inline it is worse: the whole fixture
goes to **100 leaked on both compilers**, because `field_release_of` requires every site in a
field's points-to set to agree on one disposition, and struct-owned nodes disagree with
binding-owned ones. **One case can take a fixture's coverage to nothing without failing** — the same
trap `test_72` fell into with arenas, in a different disguise.

**Stack depth is a real limit and is deliberately unmeasured.** The release recurses once per level,
so a list-shaped recursive type deep enough would trade a leak for a stack overflow. There is no
threshold here because the shape cannot be reached yet: a deep structure has to be *built*
recursively, and the one-hop limit above means no release runs on it at all. Whichever change lifts
that hop makes this reachable and should bring its own measurement; the fix is to loop on the last
self-referential field rather than recurse into it.

## 6 · Timing

Corpus median **1.006×**, range 0.939–1.031×, no program past 10%. Checksums identical across every
variant before timing, which `milestone_bench` asserts.

Swift was dropped from both harnesses this session (`--with-swift` restores it), so the standing
table below is Rust-only.

Standing against Rust, re-measured on `S35b` (`results-m2.json`, 25 runs):

| | g1 | g2 | g3 | g4 | g5 | g6 |
|---|---|---|---|---|---|---|
| loop ms | 25.1 | 48.2 | 49.5 | 69.2 | 77.7 | 147.7 |
| × idiomatic Rust | 1.36 | 2.63 | 1.09 | 3.21 | 2.63 | 2.66 |
| × hand-tuned Rust | 5.39 | 4.55 | 1.62 | 3.89 | 17.94 | 3.74 |

Band **1.09×–3.21×** of idiomatic Rust, unchanged by this milestone — which is expected, since it
changes what is freed and not what is allocated.
