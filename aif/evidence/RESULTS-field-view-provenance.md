# A field read is a view of the object it was read from

A use-after-free that `--verify` reported as a clean ledger, and the two missing
facts behind it.

## The defect

```prismio
fn main() -> Int {
    let bound = maybeName(true)
    println(optionOr(bound, "!"))            // "abc"
    println(optionOr(maybeName(true), "!"))  // ""   <- freed memory
    return 0
}
```

`optionOr` returns the String *inside* the Option it was handed. The emitted IR
put the release between the call and the use of its result:

```llvm
%6 = call %prismio.str @"optionOr$String..."(ptr %5, ...)
call void @"__aif_release_Option$String"(ptr %5)     ; frees the String %6 points at
call void @println__String(%prismio.str %6)          ; reads it
```

| Compiler | Output | Ledger |
|---|---|---|
| `build/v0.1-rc` (released 0.1) | `abc` / `abc` | 4 allocated, 1 released, 3 leaked |
| working tree, before this fix | `abc` / **empty** | 4 allocated, 4 released, 0 leaked, **0 violations** |
| working tree, after | `abc` / `abc` | 4 allocated, 2 released, 2 leaked |

**The middle row is the point.** The ledger balanced and the answer was wrong.
Both releases were legitimate — the Option's own, and the String field's as part
of it — so nothing in the instrument had anything to report. A balanced ledger is
not evidence of correctness; it is evidence that allocation and release counts
agree, which is a different claim.

## Why neither existing fact caught it

Codegen already asks two questions before releasing an argument-position
temporary (`src/ir/expr.psm`): does the callee return one of its parameters
(`aif_fn_may_return_param`), and does it return a *view* of one
(`aif_fn_may_return_view_of_param`). Both answered no, and both were right about
the question they were asked.

- **`fn_may_return_param` compares sites.** The return is `b.text`, whose sites
  are the field's, not the struct's. No intersection, truthful no.
- **`fn_may_return_view_of_param` compares view provenance**, and there was none
  to compare: nothing in the walk recorded a field read as a view.

So the hole was upstream of both predicates, in what the walk records.

## Two missing edges, and a missing type

**1. A reference-shaped field read is a view of its object.**
`src/aif/walk.psm`'s `MEMBER_ACCESS_EXPR` arm returned the field key and dropped
the object entirely. The `INDEX_EXPR` arm one screen above had recorded exactly
this edge for `List` elements since SPEC 8.4 — a reference element is a view, a
scalar element is a copy — so the fix is the same two lines, and the asymmetry
was the bug.

**2. A payload arm binder was bound to nothing at all.** `aifWalk` had no
`MATCH_STATEMENT` case, so `v` in `Option.Some(v) => return v` had no points-to
set and no view. Codegen lowers that binder as a field load out of the scrutinee
(`generatePayloadBinders`); the analysis modelled it as nothing.

**3. Sema typed the binder's name but not its node.** `semaCheckPayloadArm`
called `ir_set_var_type` and never `nodeSetType`, so `aifNodeType(binder)`
answered `""` and `aifIsRef("")` is false. Fixing (2) alone changed nothing for
this reason — the view edge was written but never taken, because the walk could
not tell a `String` payload from an `Int` one. That was worth an hour: the edge
looked correct and was unreachable.

## Scope

The defect was never Option-specific. Three shapes reproduce, and all three are
fixed:

| Shape | Before | After |
|---|---|---|
| `boxText(makeBox())` — plain struct field | `""` | `abc` |
| `holderText(makeHolder(), "!")` — concrete payload enum | `""` | `abc` |
| `optionOr(makeOption(), "!")` — generic `Option<String>` | `""` | `abc` |
| `countValue(makeCount(), 0)` — scalar payload | `7` | `7` |

A scalar payload carries no view and is released normally, which is what keeps
this from withholding releases everywhere.

## What it costs

The unbound form **leaks** now instead of dangling. That is the conservative
direction, it is what the released 0.1 compiler did, and it is the rule
RUNTIME.md 3.1 already states: an owned result passed straight into a parameter is
a value nothing names. Binding it is correct and remains the advice.

Sinking the release past the consuming call — spilling the temporary to a slot and
releasing it at scope end, as the `spawn` argument fix does — would recover the
bytes as well. It is not done here: the result of the call may outlive the scope,
so it needs the same escape proof a bound value gets, and that is a codegen change
rather than a walk change. Correctness first.

## Verification

| Check | Result |
|---|---|
| `tests/test_92_field_view_provenance.psm` | passes on the fixed compiler, **fails on the broken one** |
| `tests/test_runner.py` | 157/157 |
| Two-generation fixpoint | byte-identical compiler IR |
| `bootstrap.sh --seed` | builds |
| Doc examples (`../docs`) | 157 snippets pass |

The regression test asserts **values, not the ledger** — deliberately, because the
ledger is the instrument that failed to notice.
