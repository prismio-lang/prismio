# MEM-035: the stencil's offsets were never the problem — its condition was

**Status: GREEN, 2026-09-05.** Two-generation byte-identical fixpoint, suite
**292/292** (new `test_125_stencil_range_guard.psm`), all 34 checksums
byte-identical.

**`convolution` is 0.707x min / 0.706x p50 — a 1.42x speedup — and it is the only
function in the suite whose code changed.**

## 1 · What the spec said, and what was actually there

§5 Task 1.7 asks to "generalize the loop range guard induction scanner: collect
all constant offsets `[k_min, k_max]` on induction variable `at`" and emit a
compound guard.

**That scanner already existed and already did this.** `irIndexOffsetSign` takes
`iv`, `iv + E` and `iv - E`, `irEmitRangeGuards` folds one
`0 <= lo + off && hi + off < len` per access into the loop's single `i1`, and
`irRangeMatchAll` declines the loop unless every access matches. A seven-point
stencil would have been served in full.

What declined `benchConvolution` was one line in `generateLoopRangeGuards`:

```prismio
let ivNode = ptr_to_node(cond.child1)
if (ivNode.kind != NodeKind.IDENTIFIER_EXPR) { return false }
```

The benchmark's loop is `while (at + 3 < n)` — the condition is written so that
the *widest* read is the one bounded. `at + 3` is a `BINARY_EXPR`, so the whole
loop was refused before any offset was looked at.

## 2 · The fix

`at + K < n` is `at < n - K`. The shift moves to the bound in i64 and everything
below is unchanged.

**A non-negative literal, and only going up.** Then the condition's own `at + K`
cannot wrap either: every admitted `at` is at most `n - K - 1`, so `at + K <= n - 1`
and `n` came from an i32. A symbolic or negative shift would need its own runtime
conjunct for that, and no shape in the corpus asks for one.

## 3 · Measured

| | before | after |
|---|---:|---:|
| NEON ops in `benchConvolution` | **0** | **9** |
| instructions | 415 | 391 |
| min ns | 6,119,375 | **4,324,667** |

`tools/fn_mnemonic_diff.py`: **one changed function**, `_benchConvolution__Int`.
Everything else in the sweep is within the A/A band except `tokenization` at
1.102, which is not among the changed functions and is the layout artifact this
suite has produced three times now.

## 4 · A measurement that had to be thrown away first

The first sweep read `hashmap_insert_lookup` 1.136 and `key_value_update` 0.910,
and the mnemonic diff showed six `Map` functions changed — from a compiler edit
that touches neither.

**`std/map.psm` was being rewritten by another session while the two binaries were
being built**, so the A arm and the B arm had different standard libraries. The
tell was `ONLY OLD: mapSlotOf` / `ONLY NEW: mapProbe` in the diff: a *renamed*
function, which no codegen change can produce. Rebuilding both arms back to back
and checking `md5 std/map.psm` before and after left exactly one changed function
and the numbers in §3.

**Check the standard library's hash on both sides of an A/B in a shared worktree.**
The compiler resolves `./std` at build time, so the arms are only comparable if it
did not move between them.
