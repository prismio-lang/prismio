# An owned call result consumed directly as an argument now has an owner

**Status: GREEN, 2026-08-29.** Compiler `build/ot-2`. Suite **173/173**, fixed
point, AIF differential **18/18**, `check_source_lists` agree, `git diff --check`
clean. **86 programs run under `--verify`: 0 violations.**

The discriminator moves **92 allocated / 52 released / 40 leaked** to
**92 / 92 / 0**, with both halves still printing 3010520.

This depends on [`RESULTS-passthrough-escape.md`](RESULTS-passthrough-escape.md)
and was not safe before it: that fix supplies `aif_fn_may_return_param`, which is
one of the three conditions below, and it closed a use-after-free on the binding
path that this work would otherwise have widened to temporaries.

---

## 1 · The defect

`aif_owns_call_result_at_node` answers "does this frame own what the call
returned" wherever it is asked, and codegen only asked it at a **binding** —
`VARIABLE_DECL` and assignment, in `src/ir/stmt.psm`. A result consumed directly
as an argument is never bound, so nothing asked and nothing dropped.

`tests/owned_temporary_argument.psm` runs the same loop twice and differs by one
`let`:

| | allocated | released | leaked |
|---|---:|---:|---:|
| `let b0 = band(...)` then `simulate(b0)` | 27 | 27 | **0** |
| `simulate(band(...))` | 107 | 27 | **80** |

An automatic region usually hides this by reclaiming in bulk. The fixture's
samples list and clock calls are not decoration: they are what makes call-site
bracketing decline, and `prismio aif --why` says so outright — *"0 of 4 call
sites lie inside a region, so no arena would serve it either way."*

## 2 · The fix, and the three conditions on it

The release is emitted **after the enclosing call returns**, never before it.
That placement is the parameter convention: a Prismio parameter is a borrow —
Swift's `@guaranteed`, where the caller keeps the value alive across the call and
releases after — so the caller is the last owner and this is its release point.

Three conditions gate it, and each one is a hazard that was reachable rather
than a precaution:

1. **A known Prismio callee.** An extern's result is described by its FFI
   contract, and `alias` hands an argument back. `aif_fn_may_return_param`
   answers *no* for a symbol it does not know; treating that abstention as a
   fact is how the first attempt at the sibling fix cost three fixtures.
2. **The callee does not return one of its parameters.** Otherwise the result
   aliases the temporary and freeing it here is a use-after-free *inside the
   expression that still reads it* — the same defect as
   `tests/test_85_passthrough_escape.psm`, one scope earlier.
3. **The result carries no pointer.** A scalar cannot alias the argument at all.
   This closes the case condition 2 can miss: a callee returning a **view** of a
   parameter carries provenance rather than the parameter's sites (SPEC 8.4), so
   the set intersection is silent about it.

### The retention guard that was asked for does not exist and is not needed

`TODO.md` said a Prismio callee needs the `RETAIN_IN_BASE` question answered from
the escape facts before any drop is emitted. Probed rather than assumed, and the
answer is different in both directions:

- **A callee cannot retain a by-value parameter into a container.** Sema rejects
  `list_push(dst, b)` on a parameter with *"cannot move out of borrowed value"*.
  Parameters are borrows; the guard is the type system's.
- **A callee `h.items = l` into a field is allowed**, and it is guarded already:
  the store raises `site_in_released_field`, on which
  `aif_owns_call_result_at_node` declines. Verified — `let t = mk(); stash(h, t)`
  releases 3 of 5 with **0 violations**, so `t` is correctly not double-freed.
- `list_push(l, band(...))`, the obvious double-free shape, gets no release here:
  `retain_in` raises `in_container` and the predicate declines.

### `spawn` is excluded structurally, and that is required

`aif/evidence/xlang/prismio/g9_helper_leak.psm` is `spawn simulate(band(...))`.
A spawned task may still be running, so releasing its argument when `spawn`
returns is a use-after-free. It needs no clause: `SPAWN_EXPR` lowers through its
own path in `generateExpression`, emits its own arguments, and never reaches the
generic call path this changes. That program's IR is byte-identical and it still
leaks — correctly, and it is the shape a join-time release would have to serve.

## 3 · Before / after

**Ledger, every program in `tests/`, `aif/corpus/` and the xlang corpus.**
Six changed, none regressed, and every move is `released` up:

| program | before (a/r/leak) | after (a/r/leak) |
|---|---|---|
| `owned_temporary_argument` | 92 / 52 / **40** | 92 / 92 / **0** |
| `test_65_map` | 13 / 10 / **3** | 13 / 13 / **0** |
| `test_55_workload_profile` | 57 / 56 / **1** | 57 / 57 / **0** |
| `test_67_option_result` | 5 / 0 / **5** | 5 / 3 / **2** |
| `test_17_string_runtime` | 4 / 0 / **4** | 4 / 3 / **1** |
| `debug_info` | 4 / 1 / **3** | 4 / 3 / **1** |

`released` and `violations` are the numbers compared, because `allocated` and
`leaked` are noisy run to run. **86 programs, 0 violations** — the check that
matters for a change that adds frees where there were none.

| gate | result |
|---|---|
| fixpoint (`ot-1` vs `ot-2`) | identical |
| suite | **173/173** |
| AIF differential | **18/18** |
| `check_source_lists.py` / `git diff --check` | agree / clean |
| emitted IR | 9 of 128 programs changed; **none of g1–g9** |
| `--verify` sweep | 86 programs, **0 violations** |

**Corpus, 25 runs, checksums enforced:** median **0.999×**, range 0.953–1.003×.
Flat, and provably so — none of the seven benchmark programs' IR moved.

**Compile time**, the real risk here because the argument loop now allocates
three lists per call node: `src/main.psm` best-of-9 is **421 ms (nostr-4) → 420
ms (pt-6) → 417 ms (ot-2)**. Flat.

**Standing against idiomatic Rust, 25 runs:** g9 **0.90×** loop (RSS 0.83×,
allocations 0.13×), g3 1.05×, g1 1.15×, g5 1.60×, g2 1.74×, g6 2.74×, g4 3.07×.
Unmoved, as it must be with identical IR.
`aif/evidence/xlang/results-owned-temporary-argument.json`.

## 4 · The discriminator

`tests/owned_temporary_argument.psm` keeps its name — it is asserted through
`expected_leaks` in `tests/test_runner.py` rather than by exit status, because
what has to be checked is the ledger. **Observed failing** against `build/pt-6`:

```
owned_temporary_argument: 40 leaked, expected 0
```

and passing against `build/ot-2`. Its header has been corrected in place rather
than left describing the defect as live.

## 5 · What this does not reach

- **`spawn`**, above. A join-time release is the shape that would serve it, and
  `g9_helper_leak.psm` is the fixture waiting for it.
- **A pointer-carrying return.** Condition 3 is a blunt instrument: `strConcat(a,
  band(...))` gets no release even though `strConcat` demonstrably does not hand
  back its parameter. Sharpening it means teaching `aif_fn_may_return_param`
  about view provenance, not relaxing the condition.
- **An extern enclosing call**, condition 1 — the same extern gap recorded
  against the sibling fix.
