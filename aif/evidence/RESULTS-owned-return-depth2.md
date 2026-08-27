# Ownership survives a second return

**Status: GREEN, 2026-08-29.** Compiler `build/d2-2`. Suite **175/175**, fixed
point, AIF differential **18/18**, **87 programs under `--verify` with 0
violations**, and every program whose codegen changed **clean under
AddressSanitizer**.

The discriminator moves **12 allocated / 7 released / 5 leaked** to
**12 / 12 / 0**, with both halves still printing the same answers.

---

## 1 · The defect

`aif_owns_call_result_at_node` required the returned site to have been allocated
in the callee itself:

```c
if (sites[s].fn != c->fn) return AIF_ELEM_NONE;
```

That is one hop. It declined every producer written in Prismio the moment a
second frame appeared between the allocation and the binding —
`tests/owned_return_depth2.psm` is **6/6/0** at depth 1 and **12/7/5** at depth
2, differing by exactly one level of call depth. It stayed invisible while
`std.string` was C, because an `extern fn` carries its `produce` contract and
answers at depth 1.

## 2 · Why it did not need a fixed point

`TODO.md` and `SESSION-PROMPT.md` both said this needed *"the transitive fact —
the site escaped to Caller through every intermediate frame and no intermediate
frame owns it — which is a fixed-point change, not a predicate change."*

**It is a predicate change.** The two halves come apart:

- *"No intermediate frame owns it"* needs **nothing computed**, because
  **returning a value already implies not dropping it**. A frame that binds the
  value and returns the binding is declined by `nodeReturnsName`; one that
  returns it through a further call is declined by `nodeEscapesThroughCall`. So
  every frame on the path has already been refused ownership, and the caller is
  the first that can hold it. *That second guard is the pass-through fix landed
  earlier the same day* — this item was blocked on it and the dependency was not
  visible until it existed.

- *"The site escaped through every intermediate frame"* is an approximation of
  the real hazard, which the old comment states exactly: **a value handed *in*
  and handed straight back is owned by the caller's argument**, and freeing it
  here double-frees. That is `fn_may_return_param`, so it is now asked directly:

```c
if (sites[s].fn != c->fn && fn_may_return_param(c->fn)) return AIF_ELEM_NONE;
```

The site test survives as the fast path; the escape hatch is the parameter
question the guard was standing in for.

## 3 · Before / after

| | allocated | released | leaked |
|---|---:|---:|---:|
| `owned_return_depth2` before | 12 | 7 | **5** |
| `owned_return_depth2` after | 12 | **12** | **0** |

Two fixtures improved as a consequence, both recorded in `expected_leaks`:

- **`test_47_aif_containers` 2 → 0.** Its own note said the 2 was
  `forwards()`'s list handle and element block, and that *"two hops needs
  INFERENCE 6's contexts"*. It did not need contexts.
- **`test_72_reassigned_ownership` migrated to native `std.string`**, which is
  what it had been waiting for. Its header recorded that a migrated copy would
  measure **48 / 35 / 13** — the depth-2 gap rather than the reassignment
  machinery it was written for. It now measures **48 / 46 / 2**: the same 2
  leaks the C version had, so the migration finally measures its own subject.
  That file has carried an explicit "deliberately not migrated" note since
  2026-08; the note is replaced, not left standing beside the change.

| gate | result |
|---|---|
| fixpoint (`d2-1` vs `d2-2`) | identical |
| suite | **175/175** |
| AIF differential | **18/18** |
| `--verify` sweep | 87 programs, **0 violations** |
| **AddressSanitizer**, all 6 changed programs | **clean** |
| `check_source_lists` / `git diff --check` | agree / clean |
| corpus, 25 runs | median **0.993×**, range 0.973–1.093× |

**ASan was run and not just `--verify`**, because this widens ownership and a
read-after-free balances the ledger — the lesson from
[`RESULTS-enum-zero-value.md`](RESULTS-enum-zero-value.md) earlier the same day,
where `--verify` reported `0 violation(s)` on a program that segfaulted on two
platforms.

## 4 · What is still declined

The guard is a *disjunction*, so nothing that was safe became unsafe: a callee
that may hand a parameter back is declined exactly as before, and
`in_container`, `site_in_released_field` and the tier test are untouched. What
changed is only the case where the value provably originated below the callee.
