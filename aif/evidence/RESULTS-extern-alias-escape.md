# An `extern` declared `alias` no longer outlives the argument it returns

**Status: GREEN, 2026-08-30.** Compiler `build/alias-gen3`, LLVM 22.1.8 on Apple
Silicon. Fixed point, suite **202/202**, AIF differential **19/19**, `--verify`
sweep **0 leaked / 0 violations** on all **31** corpus programs, release gate
PASSED.

This closes the last item in `KNOWN_ISSUES.md` that was unsoundness rather than
a leak. The reproducer moved from a diagnostic nothing ran into the corpus, which
is why the count is 31 and not 30.

## 1 · The defect

```psm
extern fn prismio_expect(p: String borrow) -> String alias

fn passthru() -> String {
    let t = make()
    let x = prismio_expect(t)
    return x
}
```

`t` was freed at `passthru`'s scope exit and the same pointer was handed to the
caller:

```text
aif-verify: release of a pointer that is not live (0x102b61e00)
aif-verify: 1 allocated, 1 released, 0 leaked, 1 violation(s)
```

`println` printed an empty line, because the string was already gone.

## 2 · What it was not

Two plausible causes were checked and refuted before anything was written, and
both are worth recording because each would have been a real change in the wrong
place.

**It was not a missing union.** `aifFfiAliasOf` answers from a table with one
entry (`expect`), so the obvious reading is that a user-declared `alias` never
gets an argument index. But `src/aif/walk.psm` around line 370 already computes
`aliasedAll` -- the union of every argument's value set -- and returns it for a
declared `alias`, with a comment stating exactly that design. Growing
`aifFfiAliasOf` into a set API would have been redundant work on a correct
mechanism.

**It was not a missing escape.** Three controls locate the fault without reading
any more code:

| shape | before the fix |
|---|---|
| `return t` -- no alias hop | clean |
| alias hop, used locally, never returned | clean |
| alias hop **and** `return x` | **1 violation** |

Neither half is wrong alone. The local-use case proves `x` is not separately
owned, so the union *is* firing; `return t` proves the return transfers
correctly. Only the combination fails.

## 3 · What it was

`t`'s scope drop. `src/ir/stmt.psm` marks a binding droppable from
`aif_owns_call_result_at_node` plus syntactic guards, and the guard for this
shape is `chainEscapesThroughCall` -> `irValueAliasesName`, which exists for
precisely this hazard -- its own comment describes

```text
let t = band(1)
let x = passthru(t)
return x
```

and notes it segfaulted rather than leaked (`tests/test_85_passthrough_escape.psm`).
It asked one question:

```psm
if (aif_fn_may_return_param(e.s2) == 0) { return false }
```

and that predicate answers **no** for an extern, on purpose. So the guard that
was written for this shape declined at the FFI boundary, and `chainReturnsName`
did not cover it either -- the function returns `x`, not `t`.

## 4 · The fix, and the line it must not cross

`irValueAliasesName` now also reads the declared contract:

```psm
if (aif_fn_may_return_param(e.s2) == 0 and irCallReturnsAlias(e) == false) {
    return false
}
```

**A declared `alias` is a stated fact about one function; an unknown symbol is an
abstention about all of them.** That distinction is the whole safety argument,
and it is the one `fn_may_return_param`'s own comment draws. Answering yes for
every unknown extern was measured previously: it declines the drop at every
`print(value)` in `std/io.psm`, because `prismio_rt_print(text)` is declared
`borrow`, and it took three suite fixtures with it by leaking one String per
integer printed. Reading a declaration costs nothing anywhere one was not
written.

The control that shows the line was not crossed is the middle row above: an
alias hop whose result never leaves the frame still drops exactly once, rather
than leaking. `let same = identity(items)` in `test_47_aif_containers` is the
same shape and is why the walk is driven from the `return` rather than from the
argument.

## 5 · Result

| variant | before | after |
|---|---|---|
| `alias`, param `borrow` | 1 violation | **1 / 1 / 0 / 0** |
| `alias`, param unannotated | 1 violation | **1 / 1 / 0 / 0** |
| no `alias` declared | clean | clean |
| `return t`, no hop | clean | clean |
| hop + return, caller uses a temporary | 1 violation | **1 / 1 / 0 / 0** |
| hop, no return | clean | clean |

The program prints `hello world` instead of an empty line.

## 6 · Cost: none, and it is provable rather than measured

```text
per-function mnemonic diff vs build/loopguard-gen3
  g1 0   g2 0   g3 0   g4 0   g5 0   g6 0   g9 0
  g1_dataview_tuned 0   g2_tuned 0   g3_tuned 0   g4_tuned 0
  g5_tuned 0   g6_tuned 0   g9_tuned 0
```

Fourteen programs, natural and hand-tuned, byte-identical. No benchmark declares
an `extern alias` that returns an argument, so the new clause never fires there.
A timing A/B over identical binaries measures the host and nothing else -- the
five-arm run was taken anyway and should be read as exactly that.

## 7 · Coverage

`aif/evidence/xlang/prismio/extern_alias_escape.psm` is now in the corpus root,
so `run_corpus_test` builds and runs it and the release gate's `--verify` sweep
covers it. It could not live there while it still aborted, which is the reason it
spent one session in a directory nothing scanned.

Worth knowing why this survived to 0.1: the only `alias` extern in `std` is
`cli_arg`, which takes an `Int`, has nothing to alias, and takes the
`static-ret` path. The union branch had no corpus coverage at all.
