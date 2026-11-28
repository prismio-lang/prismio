# Research prompt 1: the `rc:none` residue

Written 2026-11-22. This answers prompt 1 of `RESEARCH_BRIEF.md`: why 1,067 of the compiler's 2,004
allocation sites are T3, why 1,052 of them carry no count, and what would reclaim them. Nothing is
built. Every number was measured on the release host at `5757802`.

## 0 · The answer in four lines

- The residue has **exactly three root causes**, and **none of them is a value with two owners**.
  One is a measurement artifact, one is global tables, and one is a contagion through a single
  allocation site.
- **Idiomatic Prismio has no residue.** The language server (590 functions, 244 sites) is 100%
  T0–T2 with 0 T3. The compiler's residue comes from its own style: an AST linked through untyped
  `Ptr` fields, and engine state kept in module-level `Vec`s.
- **Today it costs nothing at run time.** Everything in it lives until the process exits: the
  global tables, the AST and the null pointers. The language server runs analysis in a child process
  (`lsp/analysis.psm:90`).
- **Counting is the wrong tool.** A count in a header or in the slab's side table would add count
  traffic to about 680 sites that each have exactly one owner. The fix is to give the residue an
  owner, not a count.

## 1 · Method

`prismio aif src/main.psm --why=<symbol>` was run for all 1,067 T3 sites, in parallel. That's
about 1 s per site, and 1,067 of 1,067 were explained. Each explanation's minimal cause was
tallied by the rule at its root, and the cause chains were followed into the source.

A counterfactual ran on a scratch copy of the tree, with `ptr_null()` given an `alias` return
contract. The engine reads an `alias` with nothing to alias as static storage, not an allocation.

**A limit of the method:** `--why` names one sufficient cause, not every cause. In the
counterfactual, a String whose cause had been `E-OPAQUE` showed the next layer, `A-CONTAIN` at
`src/parse/arm_tests.psm:412`. A site can need more than one fix, so the counts below give each
site's first fix, not its last.

## 2 · The three causes

| Cause | Sites | Root rule | Where |
|---|---:|---|---|
| **A. Null pointers counted as allocations** | 386 `Ptr` | `E-OPAQUE` | `ptr_null()`, an extern with no return contract. 193 of them come from the five `ptr_null()` field initialisers in `createNode` (`src/ast/nodes.psm:415`). |
| **B. Global tables** | 451 lists, 34 structs | `A-ESCAPE` | `fnCallees = []` and its kind: module-level `Vec` state in `src/aifcore/`, `src/symbols/` and `src/index/`. The 5-site groups at `std/map.psm:157-165` are a `HashMap`'s own columns, held in a global. |
| **C. Contagion from one AST site** | 191 Strings, 4 structs | `E-OPAQUE`, then `A-CONTAIN` under it | `createNode` is the **one** `ASTNode` site in the compiler (T3, counted). It is held both in the tree and in scratch lists (`subs.push(a)` in `arm_tests.psm:412`), which is genuine sharing. `A-STORE` then makes every String stored into any node Shared. |

### A. A measurement artifact

`ptr_null()` returns 0 (`runtime/lang_runtime.c:1439`). With no contract on it, each call is an
"opaque return of unknown provenance": a T3 site with `rc:none`. The counterfactual, with a single
word changed (`-> Ptr alias`):

| | sites | T3 | T0–T2 | opaque returns |
|---|---:|---:|---:|---:|
| today | 2,004 | 1,067 (53%) | 46% | 387 |
| with `ptr_null() -> Ptr alias` | 1,618 | 681 (42%) | **57%** | 1 |

No real allocation changed tier. The comment above the externs in `nodes.psm` already records the
same mistake for `ptr_to_node`, where it was once most of the compiler's T3 population. Its
neighbour `ptr_null` kept it. **Consequence:** the SPEC H1 criterion (≥ 70% T0–T2), read on the
compiler, fails partly on phantoms. The manifest should not count an extern returning `Ptr` with no
contract as an allocation site, or the FFI check should warn about it.

### B. A global is treated as two owners

`A-ESCAPE` (`src/aifcore/solver.psm:686`) states that "anything globally reachable is reachable
more than once". For a module-private `let mut tbl: Vec<Int>` that its own code uses only through
list builtins, that is false: the global slot is the one holder. The rule's cost:

- In a batch program the cost is nothing, because the tables live until exit.
- In a long-running program, each **reassignment** (`fnCallees = []` when the engine resets) leaks
  the table it replaces, because a T3 value with `rc:none` has no release on overwrite. So does any
  `HashMap` or cache that a server keeps in a global and replaces.

### C. One site, and sharing passed down by A-STORE

The chain behind a typical String (`std.process:149`, `Args.at`):
`A-STORE src/parse/decl.psm:496` (`traitRef.s1 = name.value`) <- the `ASTNode` site is Shared. That
is true: AST nodes are held both by the tree and by side lists. Everything stored into a field of
that site then inherits Shared through `A-STORE` (`solver.psm:462`: "sharing is inherited through
reachability"). Strings and lists have no header, so they come out `rc:none`, and the counted node's
own release does not free them.

Two more things block a node's String fields, and both are specific to the compiler:

- `fieldReleaseOf` declines a `String` field that receives struct sites. "This compiler puns an
  ASTNode pointer as `String`" (`src/aifcore/dispositions.psm`).
- Nodes link through `Ptr` fields (`child1`, `next`), so no reference-count edge runs along the tree.

**Checked and ruled out:** a `""` default does not block a field's release.
`vsMayBeUntracked` counts only *hazards* (static storage from `alias` externs, and globals). A
String literal carries the borrowed tag, and every release of a pair skips that tag
(`constraints.psm:26`, `lang_runtime.c:3374`). Probe: a struct whose String field is given `""`
on half the paths and an owned string on the others read **150 allocated / 150 released /
0 leaked**. The KNOWN_ISSUES entry "Struct fields that may hold a string literal are never
released" (marked Not re-run) therefore looks stale for String fields. Its own `Process`
reproducer still has to be re-run before the entry is removed.

## 3 · Does this generalise beyond the compiler?

The shapes generalise, even though the compiler is their only big instance:

- **C is the important one.** Every program has factory functions (`make()`, `new()`, a parser's
  `node()`), and each is one site for every value it makes. A single genuine share anywhere, such as
  one node in two containers, makes every owned field of every value from that factory Shared, and
  for strings and lists that means never freed. The language server avoids it only because it
  happens not to share a value made by a factory.
- **B appears in any program with global caches, registries or interners** that it replaces or
  clears while running.
- **A appears in any program that ports C idioms:** externs returning `Ptr` without a contract.

## 4 · Mechanisms, judged against the data

The brief's options for reclaiming shared strings, lists and opaque pointers, ranked:

| Mechanism | Verdict | Why |
|---|---|---|
| **A1. A contract on identity and null externs**, plus an FFI check that warns about an extern returning `Ptr` with no return contract | **do first** | One word in `nodes.psm`. Removes 386 phantom sites and corrects the H1 metric. No run-time effect. |
| **C1. Owned by the counted holder**: a value whose only claim to sharing is `A-STORE` inheritance from a counted holder, and which is never itself held by a second container or moved out, is owned by that holder and released by the holder's typed release when its count reaches zero | **the main engine change** | It is the Perceus and Swift model: an object's fields belong to the object. In Prismio a field store is a move (`dispositions.psm` M2.1a says so), so a field value has one holder. It would cover the 191 Strings in a program that doesn't pun. Section 5 gives the soundness argument. |
| **B1. A global slot is one owner**: replace `A-ESCAPE ⇒ Shared` with the global as a holder; release a global's displaced value on reassignment under the closed-column proof (`src/ir/columns.psm`), widened from private fields to private globals | **for long-running programs** | It fixes the reassignment leak. With teardown elision at exit (prompt 9, lever 1), the tables cost nothing at exit either. |
| C2. Context-sensitive constructor sites (split `createNode` by caller) | complement | Prompt 2 territory. It would separate the shared `arm_tests` nodes from the others, but not cure inheritance in general. |
| A count in the slab's per-span side table; headers on every seam block; refcounted String and Vec buffers | **don't** | They pay count traffic on about 680 sites that have one owner. The one genuinely shared site (`ASTNode`) is counted already. |
| Copy-on-share | not needed | None of the 680 has a second holder to copy for. |
| Making opaque C returns T2 through contracts | done as A1 | The only opaque returns in the compiler are the nulls. |

## 5 · Is C1 sound?

The obligations C1 has to discharge:

1. **One holder.** The value's sites reach the holder's field only through stores, which are moves.
   They are in no container (`containerOf` empty or the holder alone) and are not stored as a view
   (`siteViewStored == 0`). Then the only path to the value is through the holder.
2. **The holder's release is the value's release.** The holder is counted (`rc`), so its typed
   release (`__aif_release_T`, which `generatedFieldRelease` builds field by field) runs exactly once,
   when the count reaches zero. The field's disposition must agree over its points-to set, as
   `fieldReleaseOf` already requires.
3. **Views.** `let s = node.s1` is a view of the node, and the node must outlive it. That is the
   rule views already follow (`E-VIEW`, `raiseViewOwners`). A view that outlives the binding it came
   through is the "view outliving base" cluster (brief §5 C). C1 introduces no new risk there, but
   inherits the old one.
4. **Moves out of a shared holder.** These must stay impossible. Sema already refuses moving out of
   a borrowed value; it has to refuse a move out of a T3 holder's field as well, or C1 must decline
   when it sees one.
5. **The oracle.** `tools/aif_oracle/aif.py` has to get the same rule. Its failure direction is a
   double free (the holder's release plus a scope drop of the same value), so it needs `--verify`
   fixtures in which the holder is shared: one node in two containers, with String fields.

The smallest experiment that would settle it: implement C1 behind a flag in the engine and the
oracle; run a fixture of a factory-made struct with an owned String field, held by two `Vec`s and
then dropped; and look for `0 leaked, 0 violations` and an `rc` disposition on the String field in
the manifest. Then run `prismio verify` with the flag on.

## 6 · Corrections to the brief

- §4.1 read the compiler's residue as "a real 4,000-function program is mostly residue". It is
  mostly the compiler's own style, plus 386 phantoms. The language server, idiomatic and
  long-running, has none.
- For lever 1 in `RESEARCH_P9_LEVERS.md`: the compiler's residue lives until exit, so teardown
  elision and the residue meet. A batch program would pay for neither.
