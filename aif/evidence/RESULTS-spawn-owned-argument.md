# A `spawn`ed call's owned temporary argument now has an owner

**Status: GREEN, 2026-08-30.** Compiler `build/own-gen3`, LLVM 22.1.8 on Apple
Silicon. Fixed point, suite **202/202**, AIF differential **19/19**, `--verify`
sweep **0 leaked / 0 violations** on all 30 corpus programs, release gate PASSED.

The discriminator moves **107 allocated / 27 released / 80 leaked** to
**107 / 107 / 0**, with both halves printing `checksum total 1394996972` and
`checksum last 1571892104`.

This is the read end of `RESULTS-owned-temporary-argument.md`, which gave an
owned call result consumed directly as an argument an owner at an *ordinary*
call. `spawn` was excluded there, deliberately and with a comment saying why, and
the exclusion was never closed.

## 1 · The defect

`spawn f(g(x))` where `g` produces an owned value. The ordinary call path
collects owned-temporary arguments and releases them after the call returns;
`SPAWN_EXPR` lowers through its own path in `src/ir/expr.psm`, emits its
arguments itself, and never reaches that code. Nothing else asked, so nothing
dropped.

`aif/evidence/xlang/prismio/g9_helper_leak.psm` is the shape, and it is `g9.psm`
with the band built by a helper instead of at the spawn site:

| | allocated | released | leaked |
|---|---:|---:|---:|
| `spawn simulate(Band { ... })` (g9.psm) | 27 | 27 | **0** |
| `spawn simulate(band(...))` | 107 | 27 | **80** |

Four per frame, one per spawn, at 20 frames.

## 2 · Why the ordinary release point is wrong here

The comment that excluded `spawn` is correct and worth keeping: a spawned task
may still be running when `prismio_task_spawn` returns, so releasing the argument
after the call is freeing memory the callee is reading. That is a
use-after-free, which is a worse category than the leak it would close.

## 3 · The release point, and its licence

**Scope exit, on the same proof the task handle already uses.** REQUIREMENTS 15
gave the task handle an owner and put its release at the scope exit rather than
at the join, gated on the spawn node's `i1` — set only when INFERENCE 4.1's
E-SPAWN-J proved the task is joined on every path before the scope exits. At that
exit the thread has finished, so the handle is dead. The argument is dead for
exactly the same reason, at exactly the same point.

So the argument is spilled into a stack slot and marked droppable, and the
existing drop list does the rest:

```text
ir_set_var_type(name, declType)     // the binding assigns the slot its serial
let slot = ir_get_var_slot(name)
ir_alloca(store, slot)
ir_store(store, argVal, slot)
ir_mark_droppable(name, kind)       // irOwnedTemporaryKind, the same predicate
```

Spilling rather than releasing in place is what makes a loop work: the drop list
is keyed on bindings, and a binding in a loop body is dropped once per iteration
— which is what g9's four spawns per frame need. A single release at the spawn
site would have covered one of eighty.

A spawn **not** proved joined keeps leaking. That is the conservative direction
and it is the same one `IR_DROP_TASK` takes, for the same failure.

`irArgumentIsOwnedTemporary` is the trigger and the guard both, unchanged from
the ordinary-call use: a callee that retains the value has raised `in_container`
or `site_in_released_field` on the site, and the predicate declines on both. So
`spawn f(list_push(l, g(x)))`-shaped retention still gets no release here.

## 4 · What it costs the benchmark set: nothing

```text
per-function mnemonic diff vs build/flat-gen3
    g1  changed=0    g2  changed=0    g3  changed=0    g4  changed=0
    g5  changed=0    g6  changed=0    g9  changed=0
```

Zero changed functions in all seven. No timing was run and none would mean
anything: the transformation fires only where an owned temporary is handed to a
`spawn`, and every benchmark builds its spawn arguments at the spawn site —
which is what `g9_bands.psm`'s own comment says it does on purpose. This is a
correctness fix with no measurable surface, and saying so from the mnemonic diff
is cheaper and stronger than saying it from a flat A/B.

## 5 · Two stale claims found on the way

`g9_helper_leak.psm`'s header comment asserted that `prismio_task_release`
"exists in the runtime and **is never called by codegen**". It is called, from
`src/ir/stmt.psm:613`, and `tests/test_84_task_release.psm` covers it —
REQUIREMENTS 15 closed that separately and the comment was not updated. The file
also describes the leak this change removes. Both are corrected; the file is kept
because the 27-vs-107 allocation difference between it and `g9.psm` is still a
measurement, even now that neither leaks.

## 6 · Reproducing

```sh
bash tools/bootstrap.sh --compiler build/flat-gen3 --out build/own-gen1
bash tools/bootstrap.sh --compiler build/own-gen1 --out build/own-gen2 --keep
bash tools/bootstrap.sh --compiler build/own-gen2 --out build/own-gen3 --keep
cmp build/.bootstrap-own-gen2/compiler.ll build/.bootstrap-own-gen3/compiler.ll
PRISMIO=$PWD/build/own-gen3 python3 tests/test_runner.py
python3 tools/aif_differential.py --compiler build/own-gen3
python tools/release_gate.py --rc build/own-gen3 --old build/flat-gen3
./build/own-gen3 build aif/evidence/xlang/prismio/g9_helper_leak.psm -o /tmp/leak --verify && /tmp/leak
```

## 7 · Still open in this area

The other three P0 ownership items are untouched: the argument-position release
withheld whenever the enclosing call returns a pointer, an escape through an
`extern` declared `alias`, and UMS resolution's allocation hygiene. See
`KNOWN_ISSUES.md`.
