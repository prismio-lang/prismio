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

**A struct on the frame now owns what its fields were given; four field shapes
still leak.** AIF places a struct that does not outlive its function in a stack
slot (T0), and nothing released such a struct's fields. `Bag { items: [] }` leaked
the Vec outright, and `tests/test_167_frame_struct_fields.psm` leaked 22 of 28.
Fixed on 2026-09-23 (`src/ir/expr.psm` `spillOwnedFieldTemporary`, `src/ir/stmt.psm`
`frameStructOwnsFields`):

- an owned temporary in a frame struct's literal, or assigned to its field in the
  block that declared it, gets a hidden binding on the drop list — asked the same
  questions, in the same order, a `let` of it would be;
- where some object of the type is reclaimed (`aif_type_is_reclaimed`), AIF makes
  the field its values' only release point, so the frame struct's drop runs a
  fields-only release, `__aif_release_fields_T`, emitted for those types alone.

What is still open, all leaks and none a violation:

- **Reassigning a field whose type is reclaimed, or in a nested block or loop.**
  `bag.items = [...]` on a heap struct leaks the displaced Vec. Releasing it at the
  assignment is not sound yet: `let old = bag.items` is a *view*, and so is a
  value a call returns out of `bag`, so the displaced value may still be read. It
  needs the removal verdict's "no view can be live" proof (COLLECTIONS 1e), not a
  syntactic one. Reproducer: `let mut b = make(); b.items = ["y"]` with `make`
  returning a `Bag`.
- **A field value read out and returned or pushed.** `return bag.items`, or
  `keep.push(bag.items)`, leaks the struct and the list, identically with a named
  binding in the field. The value escapes through a field read, and nothing in
  the frame owns it after.
- **One function's use of a field changes every function's.** Field keys are
  per type, not per object, so `let before = bag.items` anywhere raises the
  escape of every value any `Bag` holds in `items`, and each function's
  temporaries there lose their owner.
- **One `concat` stored into a released field** makes that site — which backs
  every `concat` in the program — the field's, so every other `concat` result,
  even a plain `let`, is owned by nobody. The same holds for any library
  allocation site shared by many calls.

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

**A struct field that could hold a string literal was freed as if it owned it.
This was unsoundness, and it is fixed at the cost of a leak.**
`fn blank() -> Named { return Named { name: "" } }` plus
`n.name = word.concat("!")` anywhere else aborted at the release with "pointer
being freed was not allocated": a literal is not a site, so the field's
points-to set held only the owned one, `field_release_of` agreed on OBJECT, and
`__aif_release_Named` freed `.rodata`. `std.process` has exactly that shape --
`Process()` defaults `program` to `""` -- so any program that also stored an
owned program name crashed dropping a `Process`. The same held for a literal
reaching the field through a parameter, and for a module-level `let` read into
one.

A value set now carries "may also be no site" (`aif_vs_mark_untracked`, from a
string literal, an `alias` extern's static return, or a global read), a key
inherits it through every BIND, STORE and ARG (`key_may_be_untracked`), and a
field that may hold one releases nothing. It moved IR for one test program and
for two release functions in the compiler (`UmsLexer`, `UmsParser`, whose
`source` and `path` are parameters some caller passes a literal).

The cost is what the declined release would have reclaimed. `Process.program`
never frees an owned name, and neither does any field a program ever stores a
literal into. Promoting the literal at the store instead would reclaim it, and
is not sound across a PLIB: `Process()` is in `process.plib`'s bitcode, compiled
before any program decided the field is released. Each `Process` given an owned
program name leaks that one string.

**Assigning a struct field does not release the value it replaces.**
`p.arguments = ["x"]` on a `Process()` leaks the empty list the constructor put
there, one allocation per assignment. A variable assignment releases the
displaced value (`generateDisplacedRelease`, promoting a literal first); the
member-access branch of the same function stores and stops, except for a
counted field. `test_153_subprocess` under `--verify` reads 0 violations with
this and the leak above as its only unreleased allocations.

**UMS resolution releases nothing it allocates.** Not unsoundness — `violations`
is 0 either side — but a real regression in allocation hygiene. The recorded fix
moves the ledger by zero; the real shape is about eight lines, and the clause to
widen can double-free, so it needs the owners enumerated first.

**Replacing a boxed element leaks the box it displaces.** For a struct that owns
something -- a `String` field -- each slot of a `Vec` holds a pointer, and boxed
`list_set` stores the new one without releasing the old, as its own comment says
it will. `v[i] = x`, `v.set(i, x)` and `list_set` are one store:
`struct Named { label: String }` reads `5 allocated, 4 released, 1 leaked,
0 violation(s)` for a single `owners.set(0, …)`, on the compiler before the
index store (2026-09-18) and after it. A counted element displaced from a Vec of
a recursive enum leaks the same way.

**A Vec holding a counted and an uncounted element of one type leaks the
uncounted one.** Teardown releases every element one way. `list_push(ys, mk())`
beside `list_push(ys, Tag { … })`, where `mk`'s site is counted and the literal's
is not, reads `8 allocated, 6 released, 2 leaked, 0 violation(s)` -- before and
after 2026-09-18.

**Storing an element read of a flat struct boxes and counts the whole type.**
Since 2026-09-18 an element read stored into a container is a second holder (see
below), and for a struct of scalars that is more than it needs: a List would
store it inline and copy it. What stops it staying inline is the inline store
itself -- `list_push_inline` releases its source through `list_release_source`,
which refuses only an address in the destination's own block, so a view into
*another* list was freed as an allocation. On `c5fff0b`, `ys.push(xs[0])` for
`struct Pt { x: Int, y: Int }` read `release of a pointer that is not live` and
the program printed 452 for 152. The shape that pays is a flat element moved
within its own list, `test_145_list_set_within_list`, which was sound inline and
is now boxed; no benchmark or corpus program moved. The fix is an inline store
that copies from a view without releasing it -- a new runtime entry codegen
chooses when the value is an element read -- after which the solver can exempt
flat types from both rules below.

**Fixed 2026-09-18: an element read stored into a container was freed twice.**
`list_push(ys, list_get(xs, 0))`, `list_set(xs, i, list_get(xs, j))`, the insert
and slice forms, and `v[i] = v[j]` -- for a struct or enum literal built in the
same function, every one read `release of a pointer that is not live`. Three
defects, found in order:

- `derived_tier` answered T1 for any site whose escape stayed in scope, without
  reading A. SPEC 4.2's "region membership dominates aliasing" rests on an arena
  reset freeing nothing individually, and a container element is never
  arena-served -- the container frees it -- so a site A-CONTAIN had made Shared
  was freed once per holder. `--why` said "A rose to Shared <- A-CONTAIN" over a
  T1 site. It now falls through to T3 (T4b for a recursive type). A value built
  in a helper had been counted all along, because a returned value lands at
  Caller -- which is why the same probe written with `mk()` read clean.
- A-CONTAIN counts containers, not slots, so a move within one list never reached
  it. An element read (a view, SPEC 8.4) stored into a container is now a second
  holder; a String is exempt, because storing a view copies it.
- Once a local value could be T4b, `cyc_release` freed a buffered candidate root
  whose count reached zero, and the next collection freed it again. It now defers
  that free to the collection, as Bacon-Rajan's Release does.

Guard: `test_157_shared_container_elements` in `run_aif_verify_test`, which fails
on `c5fff0b` with a wrong answer and a violation. `test_100_reuse_token` and
`test_129_enum_null_ownership` move for the same reason -- their shared elements
are counted now.

The inline case of the same shape is fixed. A flat struct lives in the list's
block, so `list_get` answers an interior address, and `list_set_inline` released
the address it had copied from: `sortBy` on flat structs aborted in `free`, and
so did that one-line copy on a `List<Pt>`. `list_release_source` now refuses an
address inside the list's own block, and `std.list` moves every element with
`list_swap`, which exchanges two slots with no ownership effect -- reading two
elements and writing both back through `list_set` had also duplicated one and
lost the other. Guards: `test_144_sort_inline_elements` and
`test_145_list_set_within_list`, both in `run_aif_verify_test`.

The sorts used to hide the boxed case. Their read-then-`list_set` looked like
sharing, and in `test_144`'s shape the previous compiler reference-counted a
`List<Pt>`'s boxes (`rc_alloc`) because of it; with the sorts swapping, those are
plain allocations again.

**Building a recursive enum from `let`-bound children double-frees. This is
unsoundness.** `let left = build(d - 1); let right = build(d - 1); return
Expr.Op(op, left, right)` releases a node twice -- `release of a pointer that is
not live`, then an abort -- on the compiler at `727c704` and today alike. The
same tree built with the children inside the constructor call, `Expr.Op(op,
build(d - 1), build(d - 1))`, computes the right answer and leaks instead: an
s-expression parser written that way reads `65719 allocated, 51214 released,
14505 leaked, 0 violation(s)`. `BenchTree` uses the inline form, which is why
`tree_traversal` never met the first. Between them they are why
`s_expression_parse`'s Prismio arm still stores its nodes in a flat `List<Int>`
where the C++ and Rust arms allocate one per expression -- see
benchmarks/README.md.

**A list that hands out an element is not released, so its owned Strings leak.**
The escape analysis stops releasing a container it has seen return an element
(`list_get`, indexing, a slice), and every owned long String inside goes with
it. Storing `List<String>` elements as pairs shrank this without fixing it: on
`test_141`'s shapes the ledger went from 112 leaked to 8, because a String of
twelve bytes or fewer no longer allocates at all, and the 8 are the long ones.
`test_142`'s 1,000 long strings leak the same way.

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

**A list literal is not accepted as a call argument.** `[a, b, c]` becomes
`listOf(a, b, c)` where a `List<T>` is written -- an annotation, a struct field,
the left of an assignment -- and `f(["a"])` is rejected with *"no overload of `f`
accepts these argument types"*. Bind it first:

```
let args: List<String> = ["status", "--short"]
run(args)
```

The rewrite itself is not the problem; resolving the *generic* it produces is.
Two placements were built and measured against `takes(["x"])`, and both left
`listOf` unresolved so that codegen emitted a call to the template's own name as
though it were foreign -- a link failure, `_listOf` undefined:

- **Admitted during matching, built in the argument loop** (T15's split, where a
  concrete value is admitted where a `dyn` is wanted and wrapped once the
  overload is chosen). `monoResolveGenericCall` runs at the top of the call arm
  and the argument's rewrite happens after it; a second `semaExpr` over the
  rewritten node does not help.
- **Built during matching**, so the rewrite and the resolution happen in the same
  place the working `takes(listOf("x"))` does. The node still typed as
  `[String]` afterwards, so no overload matched.

The same rewrite resolves perfectly well from `semaCheckValue` for a declaration
and for an assignment, and an explicitly written `takes(listOf("x", "y"))`
resolves in argument position. So the difference is state, not placement or
types: whoever picks this up should start by finding which of
`monoSolveTypeParam` and `monoTemplateAcceptsCall` declines, with the outer
call's resolution in flight. `tests/test_149_list_literal` covers the three
contexts that work.

**A string literal in a curated runtime function breaks the link.**
`ir_curate_module` copies a function body into the user's module as
`available_externally` and does **not** copy the private string constants it
references, so adding a `fprintf(stderr, "...")` to a curated function makes every
program fail with `Undefined symbols: "_.str.16"`. It reproduces with a compiler
built *before* the edit, because `build_driver.c` compiles `runtime/*.c` from the
working tree — which costs a confusing hour. Either copy referenced constants
during curation, or refuse to curate a function that references one.

**`list_push_slot` is not curated, and it is the seam under M6's one declined
case.** Until it is curated, a struct literal pushed into a container cannot take
a struct-path TBAA tag: the widened store the tag enables is a 0.76x win where the
optimiser can see the destination and a 2.74x loss against this call. See
`aif/evidence/RESULTS-M6-struct-path-tbaa.md` and
`aif/evidence/bench/g2_cull_probe.c`.

**The closure blocker is gone; the reason it is still not curated is
performance.** `list_push_slot_boxed` now carries `rt_alloc`'s three `static`s,
so the set stays closed with `list_push_slot` in it — one line in
`PRISMIO_CURATED_OPS` turns it on. Measured 2026-09-05, that line inlines the
fast path into every push site and reproduces the regression
`RESULTS-inline-push-rejected.md` recorded: `world_spawn` 37 -> 115 and `recruit`
57 -> 160 instructions in g6, against 0.984x on `struct_creation`. **Do not flip
it without the pushes-per-list profile that evidence file asks for.** The static
proxy for that profile does not work either: g2's `cull` and g6's `plan_orders`
both build with `list_new()`, so gating on `list_new_with_capacity` separates
neither. See `aif/evidence/RESULTS-loop-range-monotonicity.md` §10.

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

**A short String key paid a call on every map lookup. Fixed** by
`__builtin_string_hash`, which mixes an inline pair's two words where they sit
and reaches `str_hash` only for a key past twelve bytes, a view, or a short
string on the heap. `word_frequency` is 0.72x of what it was and 0.61x of C++;
the ten-word table the entry was about is 0.55x. The record is
`aif/evidence/RESULTS-string-hash-builtin.md`.

What is left of it is a constraint rather than a defect, and it is worth knowing
before touching either half: **the two halves are one hash and must answer
identically**, because a five-byte view and a five-byte inline string are the
same key and only one of them reaches the runtime. So `str_hash`'s twelve-byte
path is not "the loop, unrolled" — it assembles the same two zero-padded words
the pair holds and runs the same arithmetic. `tests/test_147` pins it at every
length across the boundary, and drifting the runtime's cutoff by one fails it.

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

## Toolchain layout

**LLVM is pinned in the checkout and linked into the compiler; a package needs
none.** Fixed 2026-09-18. Before, every compiler binary loaded Homebrew's
`libLLVM-C.dylib` by the path of the unversioned keg, which `brew upgrade llvm`
repointed and so broke every existing binary at once, and a package recorded the
build machine's Cellar path for the `clang` its builds shelled out to.

- `tools/setup_llvm.py` downloads LLVM 23.1.1 by exact asset name, checks a pinned
  SHA-256, and prepares it in `third_party/llvm`. It consults no installed LLVM;
  `--llvm-dir` still adopts one, dynamically, when asked.
- **The official macOS/Linux archives carry static archives only, and those are
  ThinLTO bitcode.** Apple's `ld` reads bitcode through Xcode's older libLTO
  (thousands of undefined symbols), and LLVM 23's `ld64.lld` cannot parse the
  macOS 27 SDK's `.tbd` stubs (`unknown target arm64e.x1-macos`). Setup lowers
  the ~2,800 members the compiler uses to native objects once (75 s on ten
  cores) and builds zstd 1.5.7 from pinned source, because LLVM's archives name
  the build machine's `/opt/homebrew/lib/libzstd.a`. A compiler then links in
  4 s with the system linker, is 134 MB, loads only libSystem, libz and libc++,
  and starts in 5.2 ms against the dylib build's 10.7.
- `prismio build` optimises and generates code in process
  (`ir_emit_object`), reproducing what `clang -O3 -c x.ll` did: the benchmark
  suite, a `-g` build and an `x86_64-apple-macos` cross build are byte-identical
  either way (`PRISMIO_CODEGEN=clang` restores the old route for comparing).
  Only the link leaves the process, through the system's driver.

What is left:

- **Linking still needs the platform's C toolchain**: `cc` on macOS and Linux,
  `clang` on PATH on Windows (`PRISMIO_CC` overrides). It is where the C
  library and the SDK come from, so shipping a linker would not remove it --
  and on macOS it could not: LLD 23 cannot read the current SDK at all. Zig
  avoids this by shipping libc stubs; nothing here does.
- **Windows was changed and not run.** Its archive ships `LLVM-C.lib`/`.dll`
  rather than bitcode, so it stays dynamic, with the DLL copied beside
  `prismio.exe` by the bootstrap, the package and the installer. The Linux path
  (libstdc++ detection, lowering) was likewise written against the macOS run.
  CI is the first run of both.
- Darwin/x86_64 has no 23.1.x archive; setup refuses it and names `--llvm-dir`.

**A struct crossing a `.plib` read its fields one slot late, and the cause was
field order chosen per compilation.** Fixed; what it leaves is below. A program
built against a packaged `stdlib/process.plib` sent every `Process` mode to the
wrong stream -- a discarded child printed, a piped one was not redirected -- and
read a `Child`'s `stdout` descriptor out of its `stdin` slot, with no diagnostic.

LAYOUT 7.2's search (`aif_layout_select`) orders fields by padding, then width,
then **access count**, and the count is the program's. `Process` has three `i32`
modes, so the width keys tie: a program that assigns `p.stdout` put `stdout`
ahead of `stdin`, while the library compile that built the PLIB saw equal counts
and kept declaration order. The two LLVM bodies printed identically --
`{ str, ptr, i32, i32, i32 }` both -- and only the name-to-index maps differed,
which is why it looked like an index shift and not an offset. Inside the
checkout the same swap happened in one compilation and cancelled out. The five
probe shapes that did not reproduce it all tied nowhere, or were read only by
code in the same compilation.

A struct declared in a `std.*` module now keeps declaration order and is never
split (`aif_layout_fix`, pushed by `aifLayoutFixStandardLibrary`), in the checkout
as well as installed, so the suite exercises the layout users get. It moved IR
for 14 of 197 programs: `Map`'s `values`/`slots` stopped swapping (two pointers
in one 32-byte header), and `Result<Int, String>` grew from 24 to 32 bytes
because `Result` declares `Err` first. `run_module_artifact_test` builds a
`std.process` program against the installed stdlib and fails on the old
compiler with exactly the symptom above.

What is still open:

- **A program's own struct handed to C that reads its fields can be permuted.**
  `ptr_to_node` and `proc_spawn_run` are both "an `extern fn` taking a struct",
  and only the second reads a field; nothing in a declaration says which. A
  three-field struct with two fields of equal width is enough. `SpawnOut` is
  safe only because it is a `std` type.
- **Other per-compilation decisions about a `std` type are made twice.** Which
  fields a type releases, and whether a boxed enum is null-tagged, are each
  decided by the library compile and again by the program. `Option<String>`
  returned by `stripPrefix` and matched in a program that also reserves null
  for it answered correctly out of tree; that is one probe, not an argument.

**A compiler is a layout, not a file.** Since the runtime shipped as installed
bitcode (`lib/runtime/*.bc`) with no toolchain-source fallback, a compiler
resolves it beside the executable or one directory up, and a miss is a hard
error naming the module. `std.*` hides the problem for in-repo sources —
`standardModulePath` walks up from the *entry source*, so a checkout answers it —
which is why the failure looks selective.

`prismio build` now leaves the rest of the toolchain beside the host it builds
(`.prismio/build/lib/runtime/*.bc`, `.prismio/build/stdlib/*.plib`), so the
project host is a complete compiler again and `tools/run_suite.py` copies the
layout rather than the binary. **A bare `tools/bootstrap.sh` generation in
`build/` is still not one**: it builds the compiler and nothing else. Point
`tests/test_runner.py --compiler` at the project host or a packaged `dist`, or
package the generation first.

**Almost nothing in `tests/` reads a `.plib`.** `std.*` resolves by walking up
from the *entry file* (RUNTIME.md), so every fixture under `tests/` compiles
`std/` from source and a defect on the installed path is invisible to the suite.
`sort()` failed to link from every installed stdlib for that reason, with the
suite green: the `call` of the closure `sort` hands `sortBy` was filtered out as
a concrete stdlib function whose body the PLIB supplies, and no PLIB had it. It
is fixed, and `run_module_artifact_test` builds `sort` against the toolchain it
packages. **That check was first added to `run_runtime_library_test`, which has
not been registered since 9bc7d36 -- its `runtime.a` premise is gone -- so for a
day it guarded nothing.** `std.platform` and a `std.process` struct are checked in
`run_module_artifact_test` the same way, and `run_ums_test` builds a program
outside the checkout. Everything else a user reaches only through a `.plib` is
still untested.

**A cross build took the host's standard library, and now takes its own.** A
`.plib` carried one code section, built for the host, and every build merged it
whatever `--target` said: an arm64 Mac building for `x86_64-apple-macos` linked
arm64 bitcode for every non-generic `std` function, LLVM warned that the triples
and data layouts differed and adopted the arm64 triple for the merged module, and
the build succeeded. PLIB v3 carries a section per packaged target, selected at
merge time; a target with runtime bitcode but no section is refused as an
incomplete installation. `run_module_artifact_test` packages
`x86_64-apple-macos` where an SDK exists and checks the section, a warning-free
cross build, and the refusal. A mutation that always picks the host section
fails it.

What is left:

- **Nothing packages a cross target by default.** `tools/package.py --target
  <triple> --sysroot <triple>=<path>` does, and needs that target's C headers
  to compile the runtime. `tools/release.py` builds one archive per host with
  no `--target`, so a released toolchain still cross-builds nothing -- as it
  did before, but now with a message rather than a mixed module.
- **A triple is matched by its spelling.** `x86_64-apple-macos` and
  `x86_64-apple-macosx` name one target and are two sections, for the PLIB as
  for `lib/runtime/<triple>/`.
- `shouldEmitFunctionFromSource` still compiles every `__builtin_target_*`
  function into the program. It is no longer the only guard; it keeps a
  foreign-triple `.ll`, which merges nothing, answering for its target.

## Platform

**The Windows console write is verified by its IR, not by running it.**
`__builtin_console_write` emits `call i32 @_write(i32, ptr readonly, i32)` for
`x86_64-pc-windows-msvc` and the POSIX `i64 @write` everywhere else, which is
checked by cross-compiling from any host. That the *linked* program then prints
is not checked here and cannot be from a macOS host; the Windows CI runner is
what proves it.

Two behaviours differ on Windows and are chosen rather than overlooked. Descriptor
1 is in the CRT's **text mode**, so a `\n` reaches the console as `\r\n` — the same
translation `printf` did before `std.io` went to the descriptor directly, and the
reason a Windows program's stdout is not byte-identical to a POSIX one. And there
is **no SIGPIPE**: a POSIX program whose reader has gone away dies of the signal
as `cat` does, while on Windows the write returns an error and the retry loop
stops, leaving the program to carry on. Neither is a defect to fix without
deciding what `print` should mean on a platform whose console is not a byte pipe.

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

**Two kinds of array are shared by a second binding rather than copied.** An
array of a known length whose elements own nothing is a value since 2026-09-18
(`typeArrayCopies`): `let b = a` and `d = c` copy it. An array of arrays is not
-- the rows are separate frame slots a byte copy would not reach -- so `let g =
grid; g[0][0] = 5` changes `grid`. An array of owning elements is not either,
because a byte copy would put each element under two owners; its elements
cannot be stored through an index, so that sharing is not observable. Both need
an element-wise copy. And a `[T]` parameter is a view by design, not a gap.

**`pop` and `removeAt` copy the element out, so they need `T: Copy`.** A moving
version needs the caller to become the element's owner with the disposition the
Vec would have used -- a free, a typed release, or a count -- and AIF has no
rule for ownership leaving a container: modelled as a view the element leaks,
as a fresh value a counted element is freed twice. Deferred past 0.1
(COLLECTIONS 1e). They are library functions, so a Vec they are called on is
also "lent" and its later removals park.

**A removal releases at once only for a Vec no one else's allocation site
touches.** Element keys are per container *type*, so one `Vec<String>` whose
element is handed out anywhere in the program makes every Vec of those strings a
non-owner, releasing nothing either way; test_161 keeps its Vec alone in its
file for that reason.

**An array parameter has no length of its own.** Arrays return by value
(`-> Array<T, N>`) and are stored in struct fields, but a length is not accepted
on a parameter: a `[T]` parameter is a view that compiles once for every length
rather than once per length (COLLECTIONS step 3). A generic struct and an enum
payload cannot hold an array yet.

**An unsized array reached through a type argument still points into a frame.**
A `[T]` struct field is refused, because it held the address of a local array
and a returned struct read the dead frame. The same value can still be stored
through a type argument -- `Box<[Int]>` with a field `T`, `Option<[Int]>`,
`Vec<[Int]>` -- and nothing checks that the array outlives the container.
Measured with each built from a local in a function that returns it: the
`Box<[Int]>` read 1 where 2 was stored, the `Option<[Int]>` matched `None`, and
the Vec read correctly only because nothing had reused the frame yet.

**A resolved path dependency is not on the import search.** Vendor source below
the entry root. Deliberately not part of 0.1.

**`wrapping_*` / `checked_*` / `saturating_*` intent forms** do not exist.
`--overflow-checks` is the debug-mode check; the intent forms are a separate
feature.

**`Char` is a byte, not a Unicode scalar**, and that is a decision rather than a
gap: it is what makes a scan one comparison per byte. What was a gap was having
no second reading — `std.string` now carries `scalarCount`, `scalars`,
`scalarAt`, `scalarWidthAt`, `isCharBoundary`, `scalarSubstring`, `isValidUtf8`
and `strFromScalar`, and `reverse` and the three `pad` functions moved to
characters because counting bytes there produced invalid UTF-8 and misaligned
columns. What remains: `toUpper`/`toLower`/`capitalize` are ASCII-only (full case
mapping needs Unicode tables, and can change a string's length — `ß` uppercases
to `SS`), and there are no grapheme clusters, no normalization, and no
display-width function, so a padded column of CJK still does not line up.

**There is no string interpolation and no iterator protocol.**

**`std.process` starts a program with an argument vector, and that is all it
does.** `Process` / `Child` / `Stream` landed with the capability in
`runtime/program_support.c` (RUNTIME.md has the surface); `runCommand` and
`quoteArg` are gone. What is left:

- **No environment, working directory or pid.** A child inherits all three, and
  a program cannot read its own pid or an environment variable.
- **A stream is inherited, piped or discarded -- never a file.** Redirecting a
  child's stdout to a path needs a fourth mode on both sides of the wire
  protocol (`0` inherit, `1` pipe, `2` discard, in `std/process.psm` and
  `program_support.c`).
- **The Windows half has never been compiled.** There is no Windows SDK on the
  machine it was written on, so the first Windows CI leg is its review.
  `exec` there is `_execvp`, which starts a new process and ends this one, so a
  parent waiting on the original does not get the replacement's status --
  `test_153_subprocess` skips that one assertion on Windows. Descriptors are CRT
  `int`s from `_open_osfhandle`, opened in text mode.
- **One spawn under construction at a time.** The argument vector crosses one
  element at a time into file-local C state, the `ir_call_begin` shape, so two
  threads spawning at once interleave into one vector.
- **A list literal needs `import std.list`.** `p.arguments = ["a"]` in a file
  that imports only `std.process` fails with "`listOf$String` is declared in
  `std.list`, which this file does not import" -- the spelling this API was
  designed around, rejected for an import the program never named.
- **Nothing reaps an unwaited `Child`.** A `Child` dropped without `wait` is a
  zombie on POSIX and an open handle on Windows.
- The ownership cost is in "Ownership": `Process.program` never frees an owned
  name, and assigning `p.arguments` leaks the constructor's empty list.

**A function that returns a view of its argument declines the caller's drop of
that argument, and the fact does not survive one level of indirection.**
`strSubstring(owned, 1, 4)` is clean; a `strScalarSubstring` that computed its
bounds by calling another function and then returned `strSubstring(s, a, b)` read
**1 allocated / 0 released**, because the caller's drop of `owned` was declined
and the view that declined it took nothing. `strStripPrefix(owned, "X")` in
`std.string` still has this shape and leaks one allocation.

The rule that avoids it is the one in the header of `std/string.psm`: a producer
allocates its own result. `strScalarSubstring` and `strTruncateToWidth` copy for
this reason, at one allocation each. What is not established is why the
inference reaches `strTrim` -- which loops and then returns a view -- and not a
function that passes its parameter to another one on the way.

**A producing call nested directly inside another leaks the inner result.**
`strToUpper(strToUpper(x))` reads 3 allocated / 2 released, and so does the same
shape over `strTrim` or `strClone`; `concat` is special-cased in codegen's
argument-release gate and does not. Bind the intermediate, which RUNTIME.md 3.1
asks for anyway.

## The AIF oracle

**`tools/aif_differential.py` reports one disagreement on `src/main.psm`, and the
compiler is the one that is right.** T1 282 vs 281, T3 384 vs 385: a single site,
`ownedTypes` at `src/ir/expr.psm:556`, which the in-compiler engine tiers T1 and
the Python oracle tiers T3. The run prints a second line, for the `owned=True`
pass -- T1 282 vs 281, T2 171 vs 172 -- which is also T1 one site too high on the
compiler's side and has not been traced to a site. Both lines were byte-identical
before and after the struct-layout and literal-field changes.

It is a local `List<String>`. It is created with `list_new()`, pushed into, and
passed once to `generateOwnedTemporaryReleases` — which takes it as a parameter,
and a parameter is a borrow. It is never returned and never stored. T1 is what
that lifetime is.

The oracle's own answer is the evidence against the oracle. `ownedVals`,
`ownedKinds` and `ownedTypes` are declared on three consecutive lines, pushed to
in the same `if`, and passed to the same call. The oracle tiers the first two T1
and only the third T3.

**What moved, and when.** Splitting `generateExpression`'s sixteen kind arms into
their own functions (2026-09-16) made the compiler *more* precise here: before the
split it agreed with the oracle at T3, after it says T1. The oracle's numbers did
not move at all — T1 281, T3 385, before and after. A per-arm return provenance
is a narrower thing to union than one 1,783-line body, which is the whole reason
the site got a better answer.

**Why this is filed rather than fixed.** The gap is the prototype's, in
`aif/prototype/aif.py`, and closing it means finding which transfer function
keeps A=Shared on a container whose only escape is a borrowed parameter. Until
then the differential fails on `src/main.psm` and passes on the other 18 sources,
so run it and read the one line rather than the exit status.

**A struct pushed into a Vec in a loop disagrees the same way, outside the 19
sources.** Under `--copyable-collections` the oracle tiers it T3 (A=Shared) and
the compiler T1, with one more oracle round; `test_164_array_fields` shows it,
and so does the same shape with scalar fields on 9f45814, so array fields did
not introduce it. Neither file is a default source of the differential.

What rules out the other reading — that the compiler now frees something still
live: the suite is green including `aif_verify`, whose ledger balances a real
run rather than an analysis; the compiler self-hosts to a byte-identical
two-generation fixpoint; and `tools/ir_snapshot.py` reports byte-identical IR for
all 196 programs across the change, so nothing about what the compiler emits for
a *program* moved with it.

## Measurement, if you are benchmarking this

**The historical g5 benchmark was not measurable at its original granularity.**
An A/A calibration reported `1.266x REGRESSED`, so the maintained root suite
does not carry that compound workload forward. Its useful axes are isolated as
`hashmap_insert_lookup`, `key_value_update`, and `nested_collection` under
`benchmarks/`; use their cross-language checksums and repeated medians instead
of interpreting an old g5 result.

**The AIF oracle differential still disagrees on six cases.** The compiler and
Python oracle disagree for `src/main.psm`, `test_45_aif_affine_collections`, and
`aif_concurrency`, each in as-is and owned modes. The original compiler and the
2026-09-06 optimization candidate produce identical differential results; see
`aif/evidence/critical-gaps-2026-09-06/differential-{baseline,final}.log`.

The suite-routing defect is fixed: `tools/run_suite.py` used to name its copy
`prismio`, silently redirecting to the older project host and making the suite
appear green for an untested candidate. Its copy is now `suite-compiler`; the
UMS fixture makes its own `prismio` launcher for routing checks. A named candidate
passes 303/303 through the corrected runner. The oracle disagreement remains a
separate, pre-existing issue.

**Phase-time a memory benchmark one shot per process.** Every `benchmarks/` entry
runs once per process, and looping the same workload inside one process measures
a different program: `benchLargeBufferCopy`'s fill settles to 0.55 ms warm and is
2.2 ms one shot, because `rt_base_alloc` recycles the block and the pages stay
faulted in. The difference inverts the cross-language comparison — a warm C++ arm
reads a *slower* fill than Prismio's, purely because `std::vector`'s allocator
returns the block to the OS between iterations.
See `aif/evidence/RESULTS-scoped-alias-metadata.md`.

**`bytecode_interpreter` moves 19% when an unrelated function changes size.**
Lowering `match` to a `switch` shrank one function in the suite binary,
`benchSwitchCase`, by 16 instructions, and `tools/fn_mnemonic_diff.py` finds no
other function changed among 635 -- yet `bytecode_interpreter` read 19.2 -> 22.9 ms,
reproducibly, over two alternating 15-run A/Bs. Its function is byte-identical and
64 bytes lower in the binary, so the same offset within a cache line: what moved is
its placement relative to everything else, which is what the branch predictor and
the instruction TLB see. `fft` and `knapsack` showed the same effect on 2026-09-04.
Check mnemonics with `fn_mnemonic_diff.py` before believing any single-workload
regression.

Aligning code wholesale does not buy it back; it moves the lottery. Over the full
suite, against default codegen: `-align-all-functions=5` (32-byte functions)
reads a geometric mean of 1.065x, and `=6` (64-byte) 1.024x. At 64 bytes
`bytecode_interpreter` improves to 0.85x while `edit_distance` regresses to
1.24x. Branch-target alignment (`-align-all-nofallthru-blocks`) and loop
alignment (`-align-loops`) trade the same way: every setting that fixed one
workload broke another. **Codegen stays at LLVM's defaults** until an
alignment can be aimed at a loop that is known to be hot, rather than applied to
every function. `PRISMIO_LLVM_ARGS` exists for that experiment: it appends LLVM's
own options to the compiler's codegen, as rustc's `-C llvm-args` does --
`PRISMIO_LLVM_ARGS="-align-loops=64" prismio build ...`. It is a measurement
switch, not a supported mode, and an option LLVM does not recognise ends the
process.

**lz4's input fill is ~30% slower than an instruction-identical C loop, and the
reason is not in the loop.** One shot per process, a standalone copy spends 312 us
of 404 in the fill (`seed` recurrence plus one push per byte); a C loop with the same
instructions runs it in 237 us. Versioning push loops on the capacity guard made
Prismio's loop C++'s exactly (length in a register, base hoisted) and changed
nothing, so it was reverted. Ruled out: the clock ramp (a 50 ms pre-spin moves
neither arm), first-touch paging (a second fill in the same process is no faster),
and the allocation (4 us). The main loop's bounds checks are not it either: a C
model with and without them runs in the same time.
See `aif/evidence/RESULTS-relational-tier.md`.
