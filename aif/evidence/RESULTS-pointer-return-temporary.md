# The argument-position release no longer turns on the return's kind

**Status: GREEN, 2026-08-30.** Compiler `build/ptrret-gen3`, LLVM 22.1.8 on
Apple Silicon. Fixed point, suite **202/202**, AIF differential **19/19**,
`--verify` sweep **0 leaked / 0 violations** on all 31 corpus programs, release
gate PASSED.

The discriminator moves **100 allocated / 0 released / 100 leaked** to
**100 / 100 / 0**.

## 1 · The defect

`RESULTS-owned-temporary-argument.md` gave an owned call result consumed directly
as an argument an owner, under three conditions. The third was the enclosing
call's **return kind**:

```psm
let resultCarriesPointer = strEquals(retType, "ptr")
    or strStartsWith(retType, "struct:")
```

Any pointer-or-struct result withheld the release. That is sound and far too
wide. `aif/evidence/xlang/prismio/pointer_return_temp.psm`:

```psm
fn wrap(s: String) -> Box { return Box { n: strLength(s) } }
...
let b = wrap(make())
```

`wrap` returns a freshly allocated `Box`, keeps nothing, and cannot hand back the
`String` — different allocation, different type. The temporary leaked, once per
iteration.

## 2 · Why the wide test was there

It was not arbitrary, and removing it without a replacement would have been a
use-after-free. The comment on the predicate says what it covers: a callee
returning a **view** of a parameter carries provenance rather than the
parameter's sites (SPEC 8.4), so `fn_may_return_param` — which intersects
points-to sets — is silent about it. It answers a truthful "no" to a question
that is not quite the one being asked, and the return's kind was standing in for
the difference.

`tests/test_85_passthrough_escape.psm` and `tests/test_47_aif_containers.psm` are
the shapes that depend on it.

## 3 · The fix

Give the missed case its own fact rather than approximating it.
`fn_may_return_view_of_param` in `runtime/aif_support.c` asks the same question
one graph over: `key_views[rk]` holds the sites the return is a view *of*, and a
PARAM key's points-to set holds what that parameter denotes. An intersection is a
return that may view an argument.

```psm
let releaseTemps = isForeign == false
    and aif_fn_may_return_param(callName) == 0
    and aif_fn_may_return_view_of_param(callName) == 0
```

It is built exactly like `fn_may_return_param`, off the converged facts rather
than recorded separately, for the reason that one gives: the RET and PARAM edges
are already there and a second record is a second thing to keep in step.

## 4 · Result, and the cases that must not move

| program | before | after |
|---|---|---|
| `pointer_return_temp.psm` | 100 / **0 / 100** | **100 / 100 / 0** |
| `test_85_passthrough_escape` | 14 / 14 / 0 | 14 / 14 / 0 |
| `test_47_aif_containers` | 88 / 88 / 0 | 88 / 88 / 0 |
| `extern_alias_escape` | 1 / 1 / 0 | 1 / 1 / 0 |

The last three are the point. **Widening a release is how a leak becomes a double
free**, so the check that matters is `violations`, not `released` — and the
`--verify` sweep reports 0 across all 31 corpus programs.

## 5 · Cost: none, provably

```text
per-function mnemonic diff vs build/alias-gen3
  g1 0  g2 0  g3 0  g4 0  g5 0  g6 0  g9 0
  g1_dataview_tuned 0  g2_tuned 0  g3_tuned 0  g4_tuned 0
  g5_tuned 0  g6_tuned 0  g9_tuned 0
```

Fourteen programs byte-identical. No benchmark passes an owned temporary to a
pointer-returning callee, so the clause never fires there. A timing A/B over
identical binaries measures the host; one was run and should be read as that.

## 6 · Still open in this area

UMS resolution's allocation hygiene is the last of the four P0 ownership items.
Its record warns that the noted fix moves the ledger by zero and that the clause
to widen can double-free, so it needs the existing owners enumerated first.
