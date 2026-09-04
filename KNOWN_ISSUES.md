# Known issues

What is open in Prismio 0.1.0, with enough of each to act on. None of these is
unsoundness unless it says so; every one was found by a measurement or a test
rather than by reading, and the measurement is in `aif/evidence/`.

Detail for any of these — the reproducer, what was tried, what was refuted — is
in `git log`, which is where this project keeps its record. Commit messages carry
their own evidence.

**Paths under `aif/evidence/xlang/` no longer exist.** That tree was superseded
by `benchmarks/` and `prismio bench` on 2026-09-03 and removed; the sources are
recoverable from Git history. The two files in it that were *regression guards*
rather than benchmarks are back under `tests/` and are stronger there than they
were: `run_corpus_test` built and ran them for an exit status, and neither defect
changes one — `pointer_return_temp` leaked 100 of 100 while exiting 0, and
`extern_alias_escape` printed an empty line and exited 0 while double-owning a
string. `run_aif_verify_test`'s table now reads their ledgers instead.

The other 25 were benchmark programs and their coverage is genuinely thinner: the
corpus sweep is 8 sources and 7 runnable, down from 33 and 30.

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
`tests/pointer_return_temp.psm`, asserted at 0 leaked by
`run_aif_verify_test`. See `aif/evidence/RESULTS-pointer-return-temporary.md`.

**An escape through an `extern` declared `alias` was unsoundness, and is
fixed.** A foreign function declared `alias` that returns its argument was not
covered by the pass-through guard, which reached Prismio callees only:
`let t = make(); let x = <extern alias>(t); return x` freed `t` at the scope exit
and handed the caller the same pointer. `irValueAliasesName` in `src/ir/expr.psm`
now reads the **declared** return contract as well as asking
`aif_fn_may_return_param` — a written `alias` is a stated fact about one
function, where an unknown symbol is an abstention about all of them, which is
why the neighbouring predicate must still answer no for the latter.
`tests/extern_alias_escape.psm` is the regression guard, and the number to read
on it is `violations` rather than `leaked`: the defect was one allocation with two
owners. `run_aif_verify_test` fails on any violation. See
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

**A function cannot state that its return is its own allocation, and the
workaround is to write the body twice.** `f(a, b) { return g(a, b) }` gets its
caller no drop as soon as an argument is itself owned. A site is per function, so
`f`'s return points at `g`'s one site, and passing a previous `f` result back in
puts that same site in `f`'s parameter set; `fn_may_return_param` intersects the
two, answers yes, and both operands leak.

Measured over 1,000 iterations of `let t = f("a","b"); let u = f(t,"c")`, on the
0.1 compiler: delegating reads **2,001 allocated / 1 released / 2,000 leaked**,
and a version of `f` that allocates in its own body reads **2,001 / 2,001 / 0**.
Free function or method makes no difference; builtin or native makes no
difference. **The obvious probe does not see it** — with only literal arguments
there is nothing in the parameter set to intersect, and both forms read
1,001 / 1,001 / 0.

This is why `std/string.psm` writes `strToUpper` and `strToLower` out twice, and
why the five String operator targets carry their bodies rather than delegating
(`aif/evidence/RESULTS-string-operator-targets.md`). `produce` says exactly this
at the FFI boundary and has no native spelling. Closing it is either a return
contract on `fn` — frontend syntax, so a seed refresh — or narrowing
`fn_may_return_param` from a points-to intersection to a flow question: does any
`return` derive from a parameter. The second is better and more dangerous, since
this predicate is what stops a caller freeing a value it does not own, so a wrong
narrowing is a double free rather than a leak.

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
standard-library method of the same signature rather than collide with it. It is a
language semantics change and has not been made, and it is **no longer free**: it
used to be safe because nothing in `std` called the unprefixed names, and five of
them now carry the implementation rather than delegating.

**Five of these names cannot be given up, and that is new.** `equals`, `concat`,
`slice`, `charAt` and `compare` are what the String operators lower to, so a
program that defines `fn concat(a: String, b: String) -> String` collides with the
target of its own `+`. The prefixed spelling is not an escape any more — those
five have no `str*` twin left. Namespacing is what fixes this too, and until then
they are the smallest set of reserved unprefixed names the operator surface can
have.

**`strLength` is the sixth lowering target and is still a prefixed public name.**
`for c in s` rewrites to a range loop over `strLength(s)`, so it is a compiler
contract exactly as the other five were. It is left deliberately rather than
overlooked: nothing forces it out, because `strLength` is not being removed and
`s.length` already reads as a property. Moving it is the same one-word change in
`semaForEachDesugar` plus a probe rename, whenever the prefix goes.

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

**Four tests fail under `PRISMIO_INLINE_ELEMS=0`, and the switch is the defect
rather than the boxed path.** The suite reports 281/285: `test_49_aif_struct_fields`,
`test_53_aif_views`, `test_80_data_view_conversion` and `test_82_generic_layout`.
All four are **leaks with 0 violations**, and every leaked block is one element
width — 4 bytes for `Item { value: Int }`, 16 for a two-field flat struct, 24 for
a DataView row. Checksums agree throughout, so the boxed path computes the right
answers.

**The attribution the previous version of this entry asked for is done, and the
fifth was never a gate failure.** `test_62_split_release`'s ledger is identical
with the gate on and off — 8205/8205 at a forced cut of 4, 4109/4109 at 12 — on
today's compiler, on `build/aif-scalar-final`, *and* on `build/unswitch-gen4`,
which is the compiler the original count was taken on. It is not exempt by
declining inline storage either: it is stamped `list_set_elem_inline`, and it
survives because codegen also emits `list_set_elem_owner`, so both
representations are covered. The count went five to four because the list was
recounted, not because anything changed.

**Why the other four cannot be fixed by adding the missing disposition.**
`list_inline_enabled()` is a `getenv`, read at run time; everything it
invalidates — the element disposition, the arena placement, whether the site
allocates at all — was decided at compile time. `test_49` allocates **3** blocks
with the representation on and **78** with it off, from one binary, and its two
lists that get no disposition are exactly the two the manifest places
`region:auto`. Closing the gate means making the opt-out compile-time, or
deleting it and keeping the `elem_size == stride` guard, which is the fallback
that answers a fact about the program rather than about the environment. See
`aif/evidence/RESULTS-inline-elems-gate.md`.

**What is not established, and it is the next thing to settle.** That the missing
`list_set_elem_owner` is *the* cause is inferred, not proven, and one measurement
argues against the obvious fix. `aif --summary` on `test_49` reports **2 call
sites bracketed, 9 sites now arena-served** — the arenas are live — and the `Item`
site itself is `region:auto`. So under boxing those blocks *should* be
arena-allocated and reclaimed in bulk, and they are not. Three candidates, in the
order they are cheapest to test:

1. the arena is never entered at run time on that path;
2. it is, but `rt_alloc`'s arena hint is not set where the boxed push allocates;
3. it is, and `--verify`'s ledger accounts for arena blocks in a way that reports
   them as leaked.

**Adding the disposition would not settle it either way**, because `list_release`
returns on `l->arena` before it reaches the element loop — so for the two lists
that lack a disposition, the loop that would use it never runs. Whoever picks
this up should answer the three above before writing any codegen.

## Traits

All 21 trait milestones are implemented and documented in `../docs`
(`content/language/traits.md` and `generics.md`). What follows is what was
deliberately left out, migrated here when `TRAIT_SYSTEM_ROADMAP.md` was retired
on 2026-09-03 — the roadmap was session scaffolding and the docs are now the
description of the system.

**Trait objects are borrowed-only.** Storing or returning a `dyn Trait` needs a
destructor slot in every vtable, an indirect call on release, and AIF learning a
type whose release it cannot see. The representation — a fat pointer with
relative 4-byte vtable offsets — was chosen so this is an addition rather than a
change.

**An unqualified call still resolves through the global overload set.** Methods
no longer collide and have a qualified spelling, but the unqualified form does
not resolve through in-scope traits.

**`dyn Trait<Item = Int>` is refused.** Object safety rejects any trait with an
associated type. Pinning it at the use site costs nothing at run time and would
make `Iterator` object-safe; the equality-constraint machinery already exists.

**There is no `Drop`-shaped trait.** Deliberately left out of the standard
vocabulary: it interacts with AIF's release placement and needs its own design
pass rather than an entry in a trait list.

**`Eq` covers the builtins only.** `std/eq.psm` has no instance for `Map` or
`List`.

**An `impl Trait` return type must be apparent in the `return`** — a struct
literal, or a call to a function whose return type is written out. The pass that
resolves it runs before any body is checked, which it must, so it has no
inferred types to read.

**`impl Trait` opacity is not enforced against the caller.** The concrete type is
resolved and the annotation rewritten, so `let p: Point = makePoint()` still
type-checks. Dispatch is static and correct; the abstraction barrier is what is
missing, and closing it means keeping the return type distinct through checking
rather than rewriting it.

**Compile time is +4.3% against the T06 baseline**, residual and diffuse. Three
optimizations were tried and are recorded in `git log` with the hypotheses that
were wrong; profile before attempting a fourth.

**`prismio suite` cannot run the ums host-routing fixture.** That fixture
deletes `.prismio/build/debug/prismio` and re-promotes it to exercise stage-0 ->
project-local promotion, and the `prismio` process running the command is using
that file. It reports 282/283; `python3 tools/run_suite.py` reports 283/283 and
is the release gate. `run_suite.py` already tests a *copy* of the compiler,
which is what fixed the other three fixtures with the same shape (object cache,
cold build, `--target`); this one needs the outer process not to be the compiler
at all.

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

**The historical g5 benchmark was not measurable at its original granularity.**
An A/A calibration reported `1.266x REGRESSED`, so the maintained root suite
does not carry that compound workload forward. Its useful axes are isolated as
`hashmap_insert_lookup`, `key_value_update`, and `nested_collection` under
`benchmarks/`; use their cross-language checksums and repeated medians instead
of interpreting an old g5 result.
