# Three ownership shapes that freed memory that was not live

**Status: GREEN, 2026-09-25.** LLVM 23.1.1, x86_64 Linux. Two-generation
fixpoint; the compiler's own IR is **byte-identical** to the compiler before the
change; suite **423/426**, the three failures the baseline has too; AIF differential agrees on all 19 default sources.

Found while adding Option's `expect`, `okOr`, `ok` and `err`
(docs/STDLIB_SHIP_PLAN.md item 5). Each shape reproduced on `2ae70c4`, the tree
before any of this session's work, and each was a violation under `--verify` and
a `free(): invalid pointer` abort without it.

## 1 · The shapes

`findLiteral(k)` returns `Option<String>.Some("a literal ...")` for one key and
`None` otherwise.

| shape | before | after |
|---|---|---|
| `fn wrap(o, d) -> String { return optionOr(o, d) }` on `findLiteral("other")`, `"fallback"` | 1 / 1 / 0, **1 violation** | 1 / 1 / 0, 0 |
| `fn payloadOr(o) -> String { match (o) { Some(v) => { return v } None => { return "".concat("") } } }` on `findLiteral("name")` | 1 / 1 / 0, **1 violation** | 1 / 1 / 0, 0 |
| `fn errOf(r) -> Option<String> { match (r) { ... Err(e) => { return Option<String>.Some(e) } } }` | 3 / 3 / 0, **1 violation** | 3 / 3 / 0, 0 |
| `let owned = parse(t); return errOf(owned)`, then print the payload | prints freed memory | prints it, 2 leaked |

## 2 · Why

**The first two are one question asked too narrowly.** A caller may free a call's
result only if every `return` in the callee is accounted for by a site
(`aif_owns_call_result_at_node`). `fn_returns_partial` marked a callee
unaccountable when a return resolved to **no site at all**. But a value set can
resolve to some sites *and* be a literal. The payload field of `Option<String>`
is one key for the whole program, and std's `Some(substring)` stores an owned
String into it (site 53, `strStripPrefix`). So `return v`, and `return
optionOr(o, d)`, resolved to site 53 and looked owned. Traced by printing the
query: `callee=wrap partial=0 site 53 fn=strStripPrefix`.

`key_may_be_untracked` already follows literals through binds, stores and
arguments. Asking it of each return picked out exactly `wrap` and `payloadOr` in
this program, and nothing in std that was not already partial. One refinement was
needed: a literal bound straight into a local does not count
(`key_may_return_untracked`). Codegen clones it wherever the local is also given
owned values, and without the refinement `let mut out = ""; out = out + x;
return out` became partial. test_140 then leaked 6 of 1,054.

**The third is two owners of one payload.** `Some(e)` stores a view of the
Result's payload into the Option's payload field. Both fields' releases agreed
they were the release point and both freed it. Now:

- `field_release_of` declines a field whose view provenance includes an enum's
  site. An enum's release always frees its payload, so the enum stays the owner.
- `fn_may_return_view_of_param` also answers yes when an object the function
  returns holds such a view in a field, at any depth. The caller then keeps the
  argument alive while the result may use it, which is the fourth row: a leak
  where there was a read of freed memory.

**Only an enum, and that was measured.** Declining for any view, struct or not,
changed the compiler's own IR. The `UmsParser.tokens` release went (it holds
`umsLex`'s `lexer.tokens`, a view of a struct), and so did `parseSource`'s lexer
and parser, reached through every punned `Ptr` field of every ASTNode. A struct
whose field value is read out is not released with that field (KNOWN_ISSUES, "a
field value read out and returned leaks"), so there the holder really is the only
owner. Restricted to enums, the compiler's IR is byte-identical. A payload enum
is a tagged struct by the time the analysis sees it, so "enum" means `is_enum`
*or* a `$tag` field.

## 3 · What moved

Of 231 programs in `tests/` and `aif/corpus/`, two emit different IR; both have
identical stdout and ledgers.

- test_148: `Letters.at` returns `"abcdef".slice(index, index + 1)`. `slice` can
  return its receiver, here a literal, so `at` is now partial and its result is
  not freed. That is the first shape, latent: a one-byte slice is inline and its
  release was a no-op.
- test_78: renumbering only.

## 4 · Pinned

`tests/forwarding_literal_probe.psm`, `binder_return_probe.psm` and
`binder_rewrap_probe.psm`, one shape per program, because the analysis is
whole-program and a shape can be masked by what else a file stores (test_191
showed 0 violations with the bad spelling). Together with
`option_methods_probe.psm` they are the suite's `ownership_probes` check. It
fails on the previous compiler, with a violation for each of the first two and
freed memory for the third, and passes on this one.

Still open, and no wider than before: a `let mut s = "lit"` that is not an owning
accumulator, given both an owned value and an unowned non-literal one, and
returned.
