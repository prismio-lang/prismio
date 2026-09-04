# `PRISMIO_INLINE_ELEMS=0` fails four fixtures, and the fifth was never one

**Status: DIAGNOSED, not fixed, 2026-09-04.** Compiler `build/strm-g4`, LLVM
22.1.8 on Apple Silicon. `PRISMIO_INLINE_ELEMS=0 python3 tools/run_suite.py`
reports **281/285**: four failures, **0 violations anywhere**, every one a leak.

This is gap 2's own acceptance criterion in `PERFORMANCE_HANDOFF.md`. The count
is four, as `KNOWN_ISSUES.md` says. What follows is the attribution that entry
asked for, and it changes what the gate means.

## 1 · The four, by fixture

| fixture | inline on | boxed | leaked block sizes |
|---|---|---|---|
| `test_49_aif_struct_fields` | 3 / 3 / 0 | 78 / 9 / **69** | 4 bytes |
| `test_53_aif_views` | 10 / 6 / 4 | 17 / 10 / **7** | 3 x 4 bytes, plus the 4 it already leaks |
| `test_80_data_view_conversion` | 11 / 11 / 0 | 14 / 12 / **2** | 24 bytes |
| `test_82_generic_layout` | 7 / 7 / 0 | 7 / 6 / **1** | 16 bytes |

Every leaked block is one **element width**: 4 bytes for `Item { value: Int }`,
16 for `Flat { x: Int, weight: Float }`, 24 for the DataView row. This is not four
defects. It is one shape seen four times.

## 2 · The fifth was not fixed; it was never a gate failure

`KNOWN_ISSUES.md` recorded five and then four, with the forced-split object count
dropping off and no explanation — "nothing in the interval targeted it".

Nothing needed to. `test_62_split_release`'s ledger **does not depend on the
gate**, and did not on the compiler the original note named:

| compiler | forced cut 4 | forced cut 12 |
|---|---|---|
| `build/strm-g4` (today) | 8205 released, on and off | 4109 released, on and off |
| `build/aif-scalar-final` | 8205 / 8205 | 4109 / 4109 |
| `build/unswitch-gen4` | 8205 / 8205 | 4109 / 4109 |

`gap = released(4) - released(12) = 4096` in every cell, which is what
`run_forced_split_test` asserts. No assertion over that ledger can be
gate-dependent.

**And the fixture is not exempt because it declines inline storage** — that was
the obvious guess and it is wrong. At a forced cut of 12 the emitted IR carries
`call void @list_set_elem_inline(ptr %1, i32 72)`; the list *is* stamped. It
survives the gate because codegen emits `list_set_elem_owner(ptr %1, i32 1)`
**as well**, from `aif_elem_owner_at_node`, independently of the stamp. With the
stamp taken, `list_release` returns on `l->elem_size` and the disposition is
never read; with the stamp refused, the same list frees its elements through
`AIF_ELEM_OBJECT`. Both representations are covered because the two facts were
recorded separately.

So the count moved from five to four because the list was recounted, not because
the tree changed. That is worth stating plainly: the entry drifted, the drift was
noticed, and the thing it pointed at had never been true.

## 3 · What the four have that test_62 does not

`test_49` has three `list_new` sites, all three stamped `list_set_elem_inline`,
and **only one of them also gets `list_set_elem_owner`**:

```text
  951:  %1 = call ptr @list_new()
  953:  call void @list_set_elem_inline(ptr %1, i32 4)      <- no disposition
 1062:  %1 = call ptr @list_new()
 1064:  call void @list_set_elem_inline(ptr %1, i32 4)      <- no disposition
 1152:  %1 = call ptr @list_new()
 1153:  call void @list_set_elem_owner(ptr %1, i32 1)
 1154:  call void @list_set_elem_inline(ptr %1, i32 4)
```

The manifest says which is which, and the correspondence is exact:

```text
  make_inventory__Int#0                        region:auto   List<Item>
  make_crate_inventory__Int#0                  region:auto   List<Item>
  stack_owner_does_not_bar_its_field__Int#0    region:none   List<Item>
```

**The two with no disposition are the two the arena serves.** That is correct
under the inline representation and correct for the arena: an arena reclaims in
bulk, the elements live in the list's own block, and there is nothing per-element
to own. `list_release` returns early on `l->arena` for exactly this reason.

## 4 · Why this cannot be fixed by adding the missing disposition

The gate is read by `list_inline_enabled()` — `getenv` — **at run time**. Every
decision it invalidates was made at **compile time**: the element disposition,
the arena placement, and whether the site allocates at all. `test_49` allocates
**3** blocks with the representation on and **78** with it off, from the same
binary. The compiler placed those sites against a representation the runtime then
declined.

So "the tests also pass with `PRISMIO_INLINE_ELEMS=0`" is not a bug list. It is
asking one binary to be correct under two placements, and no per-call fallback can
deliver that, because the fallback is downstream of the choice. Two routes are
honest:

- **Make it a compile-time flag.** Codegen, `aif_elem_owner_at_node` and the
  placement all read one answer, and the boxed configuration is internally
  consistent. The opt-out then costs a second build, which is what an opt-out
  over a representation decision actually is.
- **Delete it.** The `elem_size == stride` guard in `runtime/llvm-api-backend.c`
  stays and is the *real* fallback — it fires on a representation disagreement
  between two lists of one type, which is a fact about the program rather than an
  environment variable. What the env var adds beyond that is the ability to put
  the compiler and the runtime into states that disagree.

Either closes the gate. Neither is a bug fix, and the four fixtures are evidence
about the switch rather than about the boxed path: **checksums agree in all four**
and there are no violations, so the boxed path computes the right answers.

## 4a · What is inferred rather than measured

Sections 1-3 are measurements. That the missing `list_set_elem_owner` is *the*
cause is not: it is the best-supported reading of the correspondence in section 3,
and one measurement argues against the obvious fix.

`aif --summary` on `test_49` reports **2 call sites bracketed, 9 sites now
arena-served**, and the manifest places the `Item` site itself at `region:auto`.
Under boxing those blocks should therefore be arena-allocated and reclaimed in
bulk when the region exits. They leak instead. Three candidates:

1. the arena is never entered at run time on that path;
2. it is, but `rt_alloc`'s arena hint is not set where the boxed push allocates;
3. it is, and the `--verify` ledger accounts for arena blocks in a way that
   reports them as leaked.

**Emitting the disposition unconditionally would not discriminate between these**,
because `list_release` returns on `l->arena` before the element loop, so on the
two lists that lack one the loop never runs. Answer the three first.

## 5 · Reproducing

```bash
PRISMIO_INLINE_ELEMS=0 python3 tools/run_suite.py --compiler build/strm-g4
prismio build tests/test_49_aif_struct_fields.psm --verify -o /tmp/t49
PRISMIO_INLINE_ELEMS=1 /tmp/t49    # 3 allocated, 3 released
PRISMIO_INLINE_ELEMS=0 /tmp/t49    # 78 allocated, 9 released, 69 leaked
```
