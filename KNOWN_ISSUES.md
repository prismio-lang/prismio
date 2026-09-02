# Known issues

What is open in Prismio 0.1.0, with enough of each to act on. None of these is
unsoundness unless it says so; every one was found by a measurement or a test
rather than by reading, and the measurement is in `aif/evidence/`.

Detail for any of these — the reproducer, what was tried, what was refuted — is
in `git log`, which is where this project keeps its record. Commit messages carry
their own evidence.

## Ownership

**A value read out of a parameter is a view of it, and the caller no longer frees
the argument before reading the result.** `optionOr(s.stripPrefix("x"), "!")`
answered `""`: the release for the unbound `Option<String>` temporary was emitted
immediately after the call and before the expression that read its result.

`--verify` could not see it. Both releases were ledger-legal, so the run reported
a clean `4 allocated, 4 released, 0 leaked, 0 violation(s)` **and** the wrong
answer — the balanced-ledger trap, in its sharpest form.

Two facts were missing, and either alone left the hole open:

- A reference-shaped **field read** recorded no view of the object it came from,
  so a function returning `b.text` looked unrelated to `b`. `fn_may_return_param`
  compares sites and a field's sites are not the struct's, so it answered a
  truthful no to a question that was not the one being asked — the same shape the
  `fn_may_return_view_of_param` fact was introduced for, one graph over.
- A payload **arm binder** was bound to nothing at all: `src/aif/walk.psm` had no
  `MATCH_STATEMENT` case, so `v` in `Option.Some(v) => return v` carried neither
  the scrutinee's sites nor a view of them. Sema compounded it by typing the
  binder's *name* but not its *node*, so the walk could not tell a reference
  payload from a scalar one.

All three are fixed: the field read and the arm binder now record a view of what
they were read from, and `src/sema/enums.psm` types the binder node.
`Option<Int>` is unaffected — a scalar payload is a copy and carries no view.

The unbound form now **leaks** rather than dangling, which is the conservative
direction and what the released 0.1 compiler did. Binding is still correct and
still the rule (RUNTIME.md 3.1). Guard:
`tests/test_92_field_view_provenance.psm`, which asserts values rather than the
ledger, because the ledger is what failed to notice.

**A `spawn`ed call's owned temporary argument is released at the scope exit,
when the join is proved.** `spawn f(g(x))` used to leak what `g` produced. The
temporary is now spilled to a slot and marked droppable, gated on the same
E-SPAWN-J proof (`i1`) the task handle uses — so the release lands where the
thread has demonstrably finished, not after `prismio_task_spawn` returns where
the task may still be reading. **A spawn not proved joined still leaks**, which
is the conservative direction. See `aif/evidence/RESULTS-spawn-owned-argument.md`.

**The argument-position release no longer turns on the return's kind.** It was
withheld for every pointer or struct result, which leaked 100 of 100 allocations
where the result provably could not alias the argument. The kind test was
standing in for the case the points-to fact misses — a callee returning a *view*
of a parameter, which carries provenance rather than sites — and that case now
has its own fact, `aif_fn_may_return_view_of_param`. Guard:
`aif/evidence/xlang/prismio/pointer_return_temp.psm`. See
`aif/evidence/RESULTS-pointer-return-temporary.md`.

**An escape through an `extern` declared `alias` was unsoundness, and is
fixed.** A foreign function declared `alias` that returns its argument was not
covered by the pass-through guard, which reached Prismio callees only:
`let t = make(); let x = <extern alias>(t); return x` freed `t` at the scope exit
and handed the caller the same pointer. `irValueAliasesName` in `src/ir/expr.psm`
now reads the **declared** return contract as well as asking
`aif_fn_may_return_param` — a written `alias` is a stated fact about one
function, where an unknown symbol is an abstention about all of them, which is
why the neighbouring predicate must still answer no for the latter.
`aif/evidence/xlang/prismio/extern_alias_escape.psm` is the regression guard and
is run by `run_corpus_test` and the `--verify` sweep. See
`aif/evidence/RESULTS-extern-alias-escape.md`.

**A self-recursive producer leaked everything it built, and it is fixed.** A
site is per function, not per instance, so a self-recursive constructor was one
site serving both the root the caller should own and every interior node stored
into a payload field. The child role made `site_in_released_field` answer yes --
rightly; it is what stops a double free -- and `aif_owns_call_result_at_node`
read that same answer for the root and refused the caller the only drop that
would have reclaimed anything. `__aif_release_Tree` was generated and never
called.

The recorded account, that ownership transfer survives only one hop, was wrong:
a four-level chain of *distinct* functions reclaims all 16 of its allocations.
Depth was never the trigger.

Two clauses closed it. A released field that re-enters its owner's type no
longer excludes the caller, because there the field's release and the caller's
drop are the same traversal. And a `sink` parameter -- a move the caller cannot
undo -- no longer counts as a pass-through, which is what `passes(sink t, n)`
needed. `g8_tree_rebuild` goes **2 released to 4,096**;
`test_74_reinit_assignment` **248 leaked to 93**; violations 0 throughout,
checksums unchanged. See `aif/evidence/RESULTS-recursive-payload-leak.md`.

**The remaining reuse-token leak is fixed.** g8 kept 8,188 leaks because
`mapAdd` consumed a tree through a `sink` and nothing reclaimed the block it
destructured. M2.1b now pairs a proved one-owner, consuming match arm with its
direct same-tag constructor and writes the replacement into the dead block.
The shared/mixed path still allocates; `test_100_reuse_token` observes the old
and new values through two live containers and guards that fallback.

The g8 ledger is now **2,049 / 2,049 / 0**, down from 12,284 / 4,096 / 8,188,
with checksum 528891 unchanged. Its 20-run p50 is **51.94 us instead of 189.92
us** (3.66x faster), and allocator calls inside the measured window fall
12,539 to 2,304. `test_74_reinit_assignment` also reaches **69 / 69 / 0**.
See `aif/evidence/RESULTS-M2-reuse-token.md`.

**The generated recursive release no longer consumes one frame per list
element.** M2.1a made this path reachable: a 500,000-link `Chain` built
iteratively printed its success line and then exited 139 during its scope drop.
The release now loops on its last direct self field while retaining ordinary
recursion for earlier self fields. The same discriminator exits normally at
**500,001 / 500,001 / 0**, 0 violations. Multiple-self-field types retain a
stack bound through their non-tail branches; removing that requires an explicit
worklist. See `aif/evidence/RESULTS-recursive-release-depth.md`.

**UMS resolution releases nothing it allocates.** Not unsoundness — `violations`
is 0 either side — but a real regression in allocation hygiene. The recorded fix
moves the ledger by zero; the real shape is about eight lines, and the clause to
widen can double-free, so it needs the owners enumerated first.

## Naming

**`std.string` claims 64 unprefixed global names, and a program that defines one
of them no longer compiles.** A method is a free function whose first parameter is
the receiver, so `impl Char { fn isDigit(self) }` declares `isDigit(Char) -> Bool`
globally. A program with its own `fn isDigit(c: Char) -> Bool` is a *duplicate
definition*, not an overload.

This is not hypothetical: adding the surface broke three places in this tree at
once — `src/common/text.psm` (renamed to `isIdentStart` / `isIdentPart`, whose
predicates accept `_` and so were never the same function), `std/list.psm`'s
generic `allOf` / `anyOf` (the String methods became `allChars` / `anyChars`,
because two generic candidates could not be resolved and `test_89_closures`
stopped compiling), and `aif/evidence/xlang/prismio/g7.psm` (renamed to `tok*`).

Overloading by parameter type absorbs most of the pressure — `first(Slice<T>)` and
`first(String)` coexist, as do `slice(Lexer, ...)` and `slice(String, ...)` — so
the collision needs the *same* first-parameter type. The real fix is module
namespacing (v0.1 3.5), after which these become `string.isDigit`. Until then the
`str*` and `char*` prefixed functions remain the collision-free spelling, and both
are supported.

A weaker alternative worth considering: let a user definition shadow a
standard-library method of the same signature rather than collide with it. Nothing
in `std` calls the unprefixed names — the methods delegate to the prefixed
bodies — so shadowing would be safe, but it is a language semantics change and has
not been made.

**Scalar-element lists are inline now, and the read regression is closed.**
`inlineElemSizeOfList` used to answer 0 for any element type that was not a
struct, so `List<Bool>` and `List<Int>` spent a pointer slot each -- not
declined, unreached. They are stored under their own width now: `List<Bool>` at
4,000,000 elements goes **64.0 MB to 9.2 MB**, `List<Int>` to 32.7 MB, and a
sieve to 2,000,000 is **1.25x faster**.

The first version made a pure read loop **2.31x slower** (2.14 ms to 4.94 ms
over 20M `list_get`): inline scalars left `isStaticBoxedListGet`, whose lowering
inlined and vectorised the access, for a curated call that did not vectorise.
`ir_list_flat_scalar_elem` now resolves the representation inside the backend
intrinsic. Its flat arm is constant-stride address arithmetic plus a typed load;
its boxed arm still calls `list_get_inline_scalar` and converts the i64 bit
carrier to the same result type before the join. On the retained discriminator,
the regressed compiler is 5.62 ms median and the intrinsic is **1.94 ms** over
20M reads (**0.346x**); the emitted arm64 body is a 16-lane NEON reduction.
The original 20M-write loop stayed flat at 1.002x because scalar set remained
behind a runtime call. The scalar write pair is curated now: set takes
18.929 ms to **7.721 ms** (0.408x), while the read control stays flat at 0.962x;
the mixed sieve improves 6.849 ms to **3.505 ms** (0.512x). Push stamping,
fallback and growth live behind an exported cold helper, so the established-list
path inlines without exposing allocator statics. See
`aif/evidence/RESULTS-scalar-list-storage.md`,
`aif/evidence/RESULTS-curate-scalar-write.md`, and the three
`aif/evidence/bench/scalar_list_*.psm` programs.

## Codegen

**A string literal in a curated runtime function breaks the link.**
`ir_curate_module` copies a function body into the user's module as
`available_externally` and does **not** copy the private string constants it
references, so adding a `fprintf(stderr, "...")` to a curated function makes every
program fail with `Undefined symbols: "_.str.16"`. It reproduces with a compiler
built *before* the edit, because `build_driver.c` compiles `runtime/*.c` from the
working tree — which costs a confusing hour. Either copy referenced constants
during curation, or refuse to curate a function that references one.

**`list_push_slot` is not curated, and it is the seam under M6's one declined
case.** It reaches three `static`s, which is the rule `list_push_grow` was
outlined to satisfy for `list_push`. Until it is curated, a struct literal pushed
into a container cannot take a struct-path TBAA tag: the widened store the tag
enables is a 0.76x win where the optimiser can see the destination and a 2.74x
loss against this call. See `aif/evidence/RESULTS-M6-struct-path-tbaa.md` and
`aif/evidence/bench/g2_cull_probe.c`.

**The flat-list guard is per loop, and its code-size cost is a policy question.** `list_get` on a
flat element type now emits its own address arithmetic with the stride as an
immediate, guarded by `elem_size == stride` against a `list_get_inline`
fallback — g4 is 14.8% faster than the pre-unswitch compiler and the movement
loop has no per-iteration representation test. Every flat receiver in a loop is ANDed into one
guard in the preheader, so LLVM versions the loop twice however many lists it
walks, and the lowering declines any loop containing another call. g4 is
**0.941x** and g6 **0.933x**. The cost is unchanged and was **not** removed by
the gating, which is worth recording as refuted: g2's and g6's hot loops qualify,
so they are duplicated and still pay **+58% compile time and +34% binary** — now
for 4.2% and 6.7%. Whether that trade is worth taking is a policy decision; a
minimum-flat-sites threshold would decline the loops whose duplication does not
pay and has not been tried. **The `-mllvm -enable-nontrivial-unswitch` flag
cannot be removed**, and that is measured rather than assumed: without it LLVM
computes the conjunction into a value and never clones the loop, so the body
reloads `len` and `data` per iteration and bounds-checks every element. The flag
costs g4 16.5 KiB and buys the vectorised body. `list_set` is still untouched. Type-based alias information alone was priced at 1.73x on the ECS
loop; scoped alias metadata was priced at 1.40x and rejected before the
versioning result. `!invariant.load` on the `List` header is still **unsound**
because `list_push` rewrites it. See `aif/evidence/RESULTS-flat-list-view.md`
and `aif/evidence/RESULTS-loop-unswitch.md`.

**Five tests fail under `PRISMIO_INLINE_ELEMS=0`.** The boxed fallback is
correct — checksums agree with it set — but the suite reports 197/202 rather
than 202/202: an allocation ledger that releases 0 of 1784, a forced-split
object count, DataView conversion invariants, generic layout specialization, and
a `--verify` fact. They reproduce identically on `build/unswitch-gen4`, so they
predate the flat-list view and are about the opt-out path rather than about it.

## Platform

**A compiler self-hosted on Windows has no export table.** Incurred by the fix
that made the CI matrix green, and written down rather than done because it
cannot be verified from a macOS host.

**`--target` and `test_76_std_fs` on Windows** are not reproducible off a Windows
runner and are open there.

**WebAssembly is blocked, not in progress.** Prismio emits wasm32 IR, but there is
no C library for `wasm32-unknown-unknown`, so the runtime cannot be built for it
from this repository. A cross build with no shipped runtime archive says so and
names the file it looked for.

## Language surface

**A resolved path dependency is not on the import search.** Vendor source below
the entry root. Deliberately not part of 0.1.

**`wrapping_*` / `checked_*` / `saturating_*` intent forms** do not exist.
`--overflow-checks` is the debug-mode check; the intent forms are a separate
feature.

**`Char` is a byte, not a Unicode scalar.** There is no string interpolation and
no iterator protocol.

## Measurement, if you are benchmarking this

**g5 is not measurable at this granularity.** An A/A calibration — `build/tbaa3`
against *itself* — reports `1.266x REGRESSED`. Every g5 number this project has
recorded sits inside that spread. Run
`python3 tools/milestone_bench.py --calibrate --only g5 --skip-baselines` before
reading any A/B of it, and diff the functions with `tools/fn_mnemonic_diff.py`
before believing any harness on any program.
