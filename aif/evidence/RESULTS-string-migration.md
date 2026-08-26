# The C string layer is gone

**Status: GREEN, 2026-08-26.** `std.string` had been native Prismio since the
fat-String work, but almost nothing used it: the compiler, `ums/`, and most of
the test suite still declared `extern fn str_equals` and friends and called into
`lang_runtime.c`. The C functions still existed, which is why deleting nothing
had broken anything and why the port looked finished when it was not.

**1,093 call sites migrated across 65 files. Twelve C functions deleted.**

## 1 · What was actually true before

`std/string.psm` was clean — 55 native functions, three `extern fn` declarations,
all of them real runtime boundaries. Everything *else* was not:

| area | call sites on the C layer |
|---|---:|
| `src/` (the compiler itself) | **1 093** |
| `ums/` | 109 |
| `tests/` | 82 |

`str_equals` alone had 645 call sites in `src/`, all spelled `… == 1`.

The C side had **20** `str_*` functions and nothing had been removed from it —
`git show HEAD:runtime/lang_runtime.c` and the working tree both defined all 20,
byte for byte. That is the whole answer to "how are those still working".

## 2 · What moved

Mechanical, and verified mechanical: 582 of the 645 `str_equals` sites were
`== 1`, 52 were `== 0`, and the rest were declarations or prose. The migration
ran on whole-file text with a code mask, because a line-scoped matcher misses
`str_concat(a,\n  b)` — 98 multi-line calls — and a mask-less one rewrites the
prose in `src/ast/types.psm`, which discusses `str_equals(p, "")` in a comment.

| from | to |
|---|---|
| `str_equals(a, b) == 1` | `strEquals(a, b)` |
| `str_equals(a, b) == 0` | `strEquals(a, b) == false` |
| `str_concat` `str_char_at` `str_substring` `str_from_char` `str_index_of` `str_clone` | direct renames |
| `str_starts_with` `str_ends_with` `str_contains` | Bool-returning renames |
| `str_slice(s, a, b, baseLen)` | `strSubstring(s, a, b)` |
| `str_to_int(x)` | `optionOr(strParseInt(x), 0)` |
| `int_to_str` | `strFromInt` |

**`str_slice` was deleted rather than kept**, and that is a fat-String
consequence worth stating: it existed only because C `str_substring` had to
`strlen` its input to bound the range, making a per-token scan O(n × tokens).
Native `strSubstring` reads `__builtin_string_len`, a field read. The
length-carrying variant has no reason to exist any more.

`str_to_int` was `atoi`, which answers 0 for anything it cannot parse.
`optionOr(strParseInt(x), 0)` preserves that exactly, and says so.

## 3 · Deleted from `lang_runtime.c`

Twelve, after confirming each had no `.psm` call site and no C-internal caller:

`str_char_at` `str_starts_with` `str_ends_with` `str_contains` `str_index_of`
`str_to_int` `str_from_char` `str_compare` `str_replace` `str_trim` `str_split`
`str_split_free` — plus the now-orphaned `StringArray` type. **2 192 → 2 041
lines.**

Their AIF contracts went with them, in `src/aif/contracts.psm` *and*
`aif/prototype/aif.py` together, because `run_oracle_vocabulary_test` asserts the
two tables move as one. A contract for a symbol nothing can link is a rule that
can only fire on a typo.

### 3.1 What stayed, and why each one did

| kept | reason |
|---|---|
| `str_with_capacity` | the allocation/verify seam |
| `str_find_byte`, `str_find_byte_pair` | NEON/SSE2 search accelerators |
| `str_clone` | codegen emits it directly (`generateStringClone`) |
| `str_concat`, `str_substring`, `str_equals`, `int_to_str` | the FFI-contract test surface — 13 AIF/tier fixtures declare them to exercise `extern fn` ownership, which is still a language feature |
| `str_slice` | one benchmark, `g7.psm`, measures it against Rust's slicing |

The last two rows are debts, not designs, and they are recorded as such in TODO.

## 4 · Cost, measured

Codegen is untouched and provably so: **emitted IR is byte-identical on all 94
corpus and test programs** between the pre-migration compiler and this one, and
the compiler reaches a fixed point.

| | C strings | native | ratio |
|---|---:|---:|---:|
| `check src/main.psm` (parse + sema) | 25.01 ms | **21.08 ms** | **0.843×** |
| `build src/main.psm -o .ll` (full frontend) | 388.79 ms | 400.40 ms | 1.030× |
| cold build, g1 / g6 / test_09 | — | — | 0.998× / 1.001× / 1.002× |

**Parse and sema are 16–18% faster** (0.823× and 0.843× on two separate passes)
because native `strEquals` reads both carried lengths before it compares a byte,
where `strcmp` must scan. That is the compiler's hottest string path and it is
where the fat String was supposed to pay.

**Full emit is 3% slower**, and it is reported rather than buried: codegen builds
more Strings than sema compares, and there the native path's extra Prismio call
and its own allocation are not free. Net effect on an actual build is **flat**
(0.998–1.002×), because the frontend is ~4% of a build that is dominated by
clang.

Compiler binary: 1 370 072 → 1 555 496 bytes (+13.5%), the 55 `std.string`
functions now being compiled in rather than called out to.

## 5 · What the migration found

Moving the standard library off C made one previously-invisible limitation the
common case. **Ownership of a callee-allocated value does not survive a second
return.** `aif_owns_call_result_at_node` requires the returned site to have been
allocated in the callee itself:

```c
if (sites[s].fn != c->fn) return AIF_ELEM_NONE;   // aif_support.c
```

The guard is not arbitrary — a pass-through leaves the value owned where it was
created, and freeing it at the caller double-frees. But it also declines the
ordinary case where the intermediate frame *returned* the value and kept no claim
on it, and that is every producer written in Prismio.

It was invisible while `std.string` was C: an `extern fn` carries its `produce`
contract in the declaration, so `str_concat` answered at depth 1 and depth 2 was
never reached. Reproduction in `tests/owned_return_depth2.psm`:

| | allocated | released | leaked |
|---|---:|---:|---:|
| depth 1 — producing call in the callee's own body | 6 | 6 | **0** |
| both, adding one level of depth | 12 | 7 | **5** |

`tests/test_72_reassigned_ownership.psm` is **deliberately left on the C
`str_concat`** for this reason and says so in its header: its subject is the
reassignment machinery, and a migrated copy measures the depth-2 gap instead
(48/35/**13** against 29/27/2). Keeping it where it is preserves the coverage it
was written for.

**The fix is not "drop the guard"** — that frees pass-through returns and
double-frees them. It needs the transitive fact, which is a fixed-point change.
Ranked in TODO.

## 6 · Gates

- fixed point: `build/n3.ll == build/n4.ll`;
- **emitted IR byte-identical on all 94 programs** against the pre-migration compiler;
- suite **172/172**; AIF differential **18/18**;
- source lists agree; `git diff --check` clean;
- `run_oracle_vocabulary_test` caught its own scraper going blind when the
  `== 1` idiom disappeared, which is exactly what it exists to do; it was
  repaired rather than relaxed.
