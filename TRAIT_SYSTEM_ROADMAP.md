# Trait System Roadmap

Last updated: 2026-09-02

This file is the durable cross-session record for bringing Prismio traits and
`impl` blocks from the v0.1 static-conformance subset toward a production-grade
system. Update the status table, acceptance evidence, and next-session section
whenever a milestone moves.

Status values: `todo`, `in progress`, `done`, `blocked`.

## Current model

Prismio currently supports trait signatures, `Self`, `impl Trait for Type`,
multiple `+`-joined bounds on a generic type parameter, the same bounds written
in a `where` clause, default method bodies, supertraits, and trait-owned
constants and types with projection and equality constraints. Generic code is
monomorphised before semantic checking; every trait bound is checked at
instantiation and calls are then found through ordinary global overload
resolution. Traits do not currently own method dispatch or emit runtime metadata.

An `impl` block's methods are detached and inserted into the module as global
functions for calls. Separate impl-local method records retain their origin, so
conformance checks only methods written in the exact `impl Trait for Type` block.
Duplicate concrete impls are rejected with a source-directed diagnostic.
Generic inherent impls carry a structural target annotation and lower each
method into an ordinary generic function template. Generic trait impls and their
own bounds use the same structural matching, and coherence rejects targets that
can unify. Trait applications are structural: a trait may declare type parameters, and
`From<Int>` and `From<Bool>` are distinct identities for bounds, conformance,
generic applicability, and coherence.

## Ordered milestones

| ID | Feature | Status | Depends on | Acceptance bar |
|---|---|---|---|---|
| T01 | Multiple bounds (`T: A + B`) | done | — | Parser preserves every bound; instantiation checks every bound; diagnostics identify the failing bound; positive and negative fixtures pass. |
| T02 | Impl-owned conformance | done | T01 | Only methods declared by the matching `impl Trait for Type` satisfy that trait; unrelated inherent/global methods do not. Migrate `Key + Copy` so cross-impl accidental conformance is unnecessary. |
| T03 | Coherence and duplicate-impl rejection | done | T02 | Reject two applicable implementations of the same trait for the same concrete type with source-directed diagnostics. |
| T04 | Generic inherent impls | done | T02, T03 | Accept `impl<T> Box<T>`; instantiate methods consistently with generic functions/types; reject unconstrained type parameters. |
| T05 | Generic trait impls | done | T04 | Accept `impl<T: Bound> Trait for Box<T>` and select it only when its bounds hold. |
| T06 | Generic traits and trait arguments | done | T05 | Accept declarations such as `trait From<T>` and implementations such as `impl From<Int> for String`; include trait arguments in identity/coherence. |
| T07 | Default trait methods | done | T02, T04 | Trait methods may have bodies; an impl may omit them or override them; defaults are type-substituted and emitted once per concrete use. |
| T08 | `where` clauses | done | T01, T04 | Express equivalent bounds outside parameter lists on functions, types, and impls with consistent diagnostics. |
| T09 | Supertraits | done | T01, T02 | `trait Child: Parent` requires `Parent`; inherited requirements are checked transitively without cycles. |
| T10 | Associated constants | done | T02, T04 | Declare, implement, type-check, and resolve trait-owned constants without entering the global value namespace. |
| T11 | Associated types | done | T06, T09 | Support `type Item`, equality constraints, and projection (`T::Item`) in signatures and generic bodies. |
| T12 | Trait method namespaces and qualified calls | done | T02, T06 | Resolve methods through the receiver and in-scope traits; support an unambiguous qualified spelling; stop treating every method name as an unrestricted global. |
| T13 | Blanket implementations | done | T05, T06, T12 | Support implementations over type parameters with overlap/coherence checks and deterministic selection. |
| T14 | Operator traits | done | T06, T11, T12 | Route supported operators through standard traits while retaining useful diagnostics and predictable code generation. |
| T15 | Trait objects and dynamic dispatch | done | T02, T06, T11, T12 | Define object safety, `dyn Trait` representation, vtable emission, ownership rules, coercions, and dynamic call lowering. |
| T16 | `impl Trait` opaque/existential types | todo | T06, T11, T15 | Support argument and return-position opaque trait types with a precise ownership and ABI model. |
| T17 | Production hardening | done | T01–T16 as applicable | Compile-fail coverage, import/visibility tests, two-generation bootstrap fixpoint, full suite, AIF differential, docs verification, and performance/code-size measurements. |
| T18 | Ownership in the trait contract | done | T02, T07 | A trait signature's `produce`/`sink`/`alias` annotations are part of conformance: an impl whose method disagrees is rejected, and a bound guarantees the annotation to generic code. |
| T19 | Orphan rule and cross-module coherence | done | T03, T05, T06 | An impl is legal only where it owns the trait or the target. Coherence holds across modules and packages, not only within one compilation. |
| T20 | Standard trait vocabulary | done | T07, T11, T12, T14 | `Iterator`, `Display`, comparison and `Drop`-shaped traits exist in `std` with the ownership model above, and `for` iterates anything implementing the protocol. |
| T21 | Trait resolution termination | done | T05, T13 | Instantiation and bound solving have a depth bound and cycle detection with a diagnostic naming the cycle, instead of diverging. |

Advanced Rust facilities such as auto traits, negative impls, specialization,
generic associated types, and unsafe traits are intentionally deferred until the
core milestones above demonstrate a concrete Prismio use case.

## Coverage review (2026-09-02)

T01-T17 were reviewed against what a production trait system has to answer. The
type-system axis was complete; four requirements were missing and one was
ordered wrongly. T18-T21 above are those four. Each was checked against the tree
rather than assumed.

**T18 -- ownership is not part of the contract, and this is the important one.**
A trait declaring `fn consume(sink self)` is today satisfied by an impl
declaring plain `fn consume(self)`; the annotations are parsed and then ignored
by conformance. Prismio's identity is explicit ownership and AIF, so a trait
that cannot state an ownership obligation is a hole exactly where this language
differs from the ones the milestone list was modelled on. T15 and T16 mention
ownership, but only for trait objects and opaque types -- the ordinary case has
no milestone. Generic code also cannot rely on an annotation it cannot demand.

**T19 -- there is no orphan rule.** `grep -i orphan` finds nothing in `src/`,
this file, or the docs. T03 and T05 enforce coherence within one compilation,
and nothing prevents two modules from implementing one trait for one type. UMS
already exists as a package manager, so this stops being theoretical as soon as
packages ship impls -- and an orphan rule added later breaks code that was legal
when it was written. It is cheaper now than at any later point.

**T20 -- no standard vocabulary.** T14 routes operators through traits, but
nothing declares `Iterator`, `Display`, a comparison family, or a destructor
shape. A trait system is judged on its vocabulary as much as its machinery, and
the vocabulary is what forces the ownership questions in T18 to be answered
concretely.

**T21 -- nothing bounds resolution.** `Box<Box<Box<Int>>>` instantiates through
`impl<T: Deep> Deep for Box<T>` correctly, and no depth bound or cycle detection
stands behind it. A cyclic impl should name the cycle rather than diverge.

### Ordering correction

**T12 is ordered too late.** Every impl method is detached into the *global*
function namespace -- `test_102` calls `from(value)` and `tag(value, true)` as
free functions, which is the current model working as designed. Every milestone
that adds impls widens that namespace, so the collision surface grows while the
fix waits at position twelve. T12 should come before T13 and T14, both of which
add many impls, and T20 depends on it in practice: a vocabulary of traits with
short method names (`next`, `show`) is exactly what a global namespace cannot
hold. Move it ahead of T13 unless something in T11 forces the other order.

The deferral list below is unchanged and remains correct.

## Milestone T01 — multiple bounds

Planned representation: retain the existing compact parameter encoding and
store `T: A + B` as `T:A+B`. This deliberately limits T01 to syntax and bound
checking; replacing the textual generic-parameter representation belongs with
generic impls, where structural matching becomes necessary.

Files in scope:

- `src/parse/decl.psm`
- `src/sema/generics.psm`
- `tests/test_98_multiple_trait_bounds.psm`
- `tests/neg_57_second_bound_not_satisfied.psm`
- `tests/neg_58_second_bound_not_trait.psm`
- `../docs/content/language/traits.md`

Acceptance evidence:

- [x] New compiler bootstrapped through two generations.
- [x] Positive multiple-bound fixture compiles and runs under the JIT.
- [x] Missing second implementation is rejected at the instantiation.
- [x] Non-trait second bound is rejected at the instantiation.
- [x] Existing trait fixture compiles and runs under the JIT.
- [x] All 98 positive fixtures pass semantic checking; all 60 negative fixtures pass.
- [x] Generation fixpoint is byte-identical.
- [x] All 158 compiler-checked documentation snippets verify.
- [x] AIF differential agrees on all 19 sources in both modes.
- [ ] Full native test runner passes. Blocked by the pre-existing
      `target_mem0`/`target_mem1` LLVM attribute incompatibility described below.

## Working-tree and verification note

The worktree already contained unrelated changes when this roadmap was created,
including compiler driver, IR, runtime, AIF, UMS, and test-runner changes. Do not
discard or rewrite them. On 2026-09-01 the existing positive trait fixture could
be semantically compiled, but native linking failed because the current runtime
emitted LLVM memory attributes containing `target_mem0`/`target_mem1`, which the
installed Clang rejected. Negative trait fixtures still ran successfully. Treat
that as a pre-existing verification constraint, not a trait-system failure.

Resolved on 2026-09-02: the native runner links again under LLVM 22.1.8, and
the full suite now runs. The unchecked native-runner box on T01-T05 was that
constraint, not a defect in any of those milestones.

## Milestone T02 — impl-owned conformance

Implementation:

- `IMPL_METHOD` records retain each method's name and unique source span under
  its owning `IMPL_DECL` while the callable function remains top-level.
- Conformance resolves those recorded declarations and no longer accepts an
  unrelated free function, inherent method, or another trait's method.
- `Key` now contains only `hash` and `eq`; `Map` declares `K: Key + Copy` and
  imports `std.copy` directly.

Acceptance evidence:

- [x] `neg_60_unrelated_method_not_conformance` proves a global method cannot
      satisfy an impl accidentally.
- [x] Existing missing-method diagnostics remain green.
- [x] `test_87_traits`, `test_88_map_keys`, and
      `test_98_multiple_trait_bounds` compile and run under the JIT.
- [x] All 98 positive fixtures pass semantic checking; all 61 negative fixtures pass.
- [x] Two generations bootstrap and emit byte-identical compiler IR.
- [x] All 158 compiler-checked documentation snippets verify.
- [x] AIF differential agrees on all 19 sources in both modes.
- [x] Repository lint and source-format checks pass.
- [ ] Full native test runner passes. Blocked by the pre-existing LLVM attribute
      incompatibility recorded above.

## Milestone T03 — concrete coherence

Implementation:

- Semantic checking finds the first concrete impl with the same trait and type.
- A later match is rejected as a duplicate and receives a source note pointing
  to the first declaration.
- The check is intentionally exact rather than an overlap algorithm; generic
  impl applicability belongs to T05.

Acceptance evidence:

- [x] `neg_61_duplicate_trait_impl` verifies the primary diagnostic and the
      source-directed first-impl note.
- [x] `test_99_trait_coherence` proves distinct traits for one type and one
      trait for distinct types remain legal and callable.
- [x] Trait, map, multiple-bound, and coherence fixtures compile and run under
      the JIT.
- [x] All 99 positive fixtures pass semantic checking; all 62 negative fixtures pass.
- [x] Two generations bootstrap and emit byte-identical compiler IR.
- [ ] Full native test runner passes. Blocked by the pre-existing LLVM attribute
      incompatibility recorded above.

## Milestone T04 — generic inherent impls

Implementation:

- `IMPL_HEADER` owns the impl's generic parameter list and structural target
  `TYPE_ANNOTATION`; `IMPL_DECL.s1/s2` remain base-name lookup accelerators and
  do not encode `Box<T>` with delimiters.
- Bare `self` and every `Self` annotation deep-copy the complete target tree, so
  substituting one method cannot mutate the header or another method.
- Impl parameters and method-local parameters become one ordinary function
  template. Existing structural inference, bound checking, substitution, and
  demand-driven emission instantiate its methods without a second dispatch or
  monomorphisation path.
- Template selection now checks the receiver constructor (`Box<T>` does not
  solve against `Cell<Int>`), and instantiation reuse includes template source
  identity. Same-named generic methods on different types therefore remain
  distinct overloads.
- Unconstrained impl parameters, blanket inherent `impl<T> T`, and a method
  parameter shadowing an impl parameter are rejected. `impl Box<Int>` is a
  supported concrete specialization.

Acceptance evidence:

- [x] `test_100_generic_inherent_impl` covers inferred Int and Bool instances,
      complete `Self`, an additional method parameter, an impl-level bound,
      concrete specialization, free-call syntax, and the same method name on
      two generic receiver constructors.
- [x] `neg_62_unconstrained_generic_impl`,
      `neg_63_impl_for_type_parameter`, and
      `neg_64_duplicate_impl_method_parameter` cover the new declaration
      invariants. `neg_44_impl_generic` now preserves T05's generic-trait-impl
      boundary.
- [x] All 100 positive fixtures pass semantic checking; all 65 negative
      fixtures pass with the fixed-point compiler.
- [x] Generic impl, coherence, and multiple-bound fixtures compile and run
      under the JIT.
- [x] Two stable generations emit byte-identical compiler IR
      (`traits-generic-impl-fx4.ll` and `traits-generic-impl-fx5.ll`). An earlier
      generation differed because the compiler itself had not yet been rebuilt
      by the corrected generic-template selection logic.
- [x] All 158 compiler-checked documentation snippets verify.
- [x] AIF differential agrees on all 19 sources in both modes.
- [x] T04 files pass whitespace/diff checks. Repository-wide lint remains
      blocked by unrelated pre-existing formatting changes in `src/main.psm`
      and `ums/ums.psm`.
- [ ] Full native test runner passes. Blocked by the pre-existing LLVM attribute
      incompatibility recorded above.

## Milestone T05 — generic trait impls

Implementation:

- The parser accepts `impl<T: Bound> Trait for Box<T>` and concrete generic
  specializations such as `impl Trait for Box<Int>` using the T04 structural
  header. Bare `impl<T> Trait for T` remains reserved for T13 blanket impls.
- Trait-bound lookup solves impl parameters from the concrete target, substitutes
  the entire target to validate fixed and repeated arguments, and checks every
  impl-level bound without diagnosing a merely inapplicable candidate.
- Generic conformance finds the exact method templates retained by the owning
  impl's source records. `Self` is compared with the full target tree, and a
  method-local type parameter cannot satisfy a non-generic trait requirement.
- Coherence structurally unifies targets, treats bounds conservatively under an
  open world, detects generic/concrete overlap, and permits disjoint concrete
  specializations. Repeated variables contribute concrete constraints, so
  `Pair<T, T>` is disjoint from `Pair<Int, Bool>`.
- Generic call selection validates the fully substituted parameter signature,
  not only whether every type variable can be solved. This lets an inapplicable
  generic method fall through to a matching concrete overload.

Acceptance evidence:

- [x] `test_101_generic_trait_impl` covers bounded applicability through a
      generic function bound, direct method dispatch, same-named methods on two
      generic constructors, complete `Self`, concrete specializations, and
      repeated-parameter coherence.
- [x] `neg_65_generic_trait_impl_bound` proves a matching target is inapplicable
      when its own bound fails.
- [x] `neg_66_overlapping_generic_trait_impl` reports generic/concrete overlap
      with a note at the first declaration.
- [x] `neg_67_generic_trait_conformance` and
      `neg_69_generic_trait_method_parameter` prove conformance is structural
      and owned by the exact generic impl.
- [x] `neg_68_blanket_trait_impl` preserves the T13 boundary, while
      `neg_44_impl_generic` now preserves T06's generic-trait-argument boundary.
- [x] All 101 positive fixtures pass semantic checking; all 70 negative
      fixtures pass with the fixed-point compiler.
- [x] Generic trait impl, generic inherent impl, coherence, and multiple-bound
      fixtures compile and run under the JIT.
- [x] Two stable generations emit byte-identical compiler IR
      (`traits-generic-trait-fx3.ll` and `traits-generic-trait-fx4.ll`).
- [x] All 159 compiler-checked documentation snippets verify.
- [x] AIF differential agrees on all 19 sources in both modes.
- [ ] Full native test runner passes. Blocked by the pre-existing LLVM attribute
      incompatibility recorded above.

## Milestone T06 — generic traits and trait arguments

Implementation:

- `TRAIT_DECL` carries its own type-parameter list, and the impl header's trait
  reference owns a structural chain of trait-argument `TYPE_ANNOTATION` nodes.
  `From<Int>` is never spelled as text in `IMPL_DECL.s2`; nested arguments such
  as `Wraps<List<Int>>` are ordinary annotation trees, so `>>` recovery and
  recursive identity fall out of the existing parser.
- Conformance checks argument arity against the declaration before it checks
  methods, so a missing or extra argument is reported against the trait rather
  than as a cascade of absent methods. Each argument must then be either an impl
  parameter or a valid type.
- Trait arguments participate in bound identity, conformance substitution,
  generic applicability, and coherence. `semaAnnotationsAgree` substitutes a
  trait parameter from the argument chain by index, so a trait parameter and a
  target parameter are resolved through one mechanism.
- A bound names an application, not a trait: `U: From<Int>` and `U: ScaleBy<Bool>`
  select different impls for the same target type.

Acceptance evidence:

- [x] `test_102_generic_trait_arguments` covers a generic impl solved from a
      trait argument, two applications of one trait on one target, nested
      arguments, and repeated-variable coherence in which `Tagged<T> for
      Carrier<T>` stays disjoint from `Tagged<Int> for Carrier<Bool>`. It
      imports `tests/trait_args/source.psm`, so trait declarations resolve
      across modules.
- [x] `neg_70`–`neg_76` cover missing and extra trait arguments, a missing
      argument in a bound, a bound whose argument does not match, conformance
      owned by the exact application, overlapping applications, and an unknown
      argument type.
- [x] All 107 positive fixtures and 77 negative fixtures pass with the
      fixed-point compiler.
- [x] Two generations bootstrap and emit byte-identical compiler IR
      (`build/t06-fx1.ll` and `build/t06-fx2.ll`, 4,138,121 bytes).
- [x] All 160 compiler-checked documentation snippets verify.
- [x] AIF differential agrees on all 19 sources in both modes.
- [x] Full native test runner reaches 233 of 234. The one failure is `aif_rc`
      and is not a trait defect; see the note below.

## Milestone T06 verification note — `aif_rc`

`aif_rc` asserts that `src/main.psm` emits zero calls to `rc_alloc`. That was a
proxy for the property it documents: an OPAQUE site must never be refcounted,
because the pointer came back from a function this compilation cannot see and
there is no header in front of it. The proxy held while every T3 site in the
compiler was an opaque extern return.

The compiler now contains two T3 sites that are its own allocations:

- `parseValue__Struct_UmsParser#0`, `UmsAstValue`, `ums/parser/parser.psm:69:28`
- `umsLinkInput__...#0`, `UmsLinkInput`, `ums/targets/target.psm:64:25`

`--why` reports both as `shared heap (RC)`, `multiple owners in one thread`, with
an `A-CONTAIN` cause. Both allocate `sizeof(struct)` for a Prismio-owned value,
so refcounting them is correct and the manifest and codegen agree.

Bisected with a worktree at `cb00d4b`: pre-commit sources emit 0, current
sources emit 2, and the T05 and T06 compilers agree on the current sources. The
sources changed, not trait codegen. The test needs to check the documented
property — no refcount on an OPAQUE origin — instead of a zero count.

## Milestone T07 — default trait methods

Implementation:

- A trait signature may carry a body. `FUNCTION.child2` present is the only
  difference between a method an `impl` must supply and one it inherits, and it
  is what both conformance and the expansion read.
- `monoExpandDefaultMethods` splices an inherited body into the module as an
  ordinary top-level function, the same lowering the parser applies to an
  `impl` block's own methods. Nothing downstream learns that defaults exist.
- The expansion runs after the merge and **before `monoCollectTemplates`**. A
  default may be inherited from a trait in another module, and a default on a
  generic impl has to be collected as a template like any other; expanding after
  collection would leave it permanently uninstantiated.
- `Self` is substituted before the trait's arguments, because the target may be
  written in terms of those arguments. Both use the existing
  `monoSubstituteChain`, with `Self` passed as a one-name parameter list.
- An override is detected through the impl's own `IMPL_METHOD` records, not the
  module chain: a function of that name almost certainly exists for some other
  type, and only this block's own method counts.

Acceptance evidence:

- [x] `test_103_default_trait_methods` covers an inherited default, an override,
      a default reached through a bound, `Self` in a default's return type, a
      default on a generic impl instantiated at two receivers, and a trait
      argument substituted into a default's signature.
- [x] `neg_77_missing_method_with_defaults` proves a trait mixing defaulted and
      required methods still reports the required one.
- [x] `neg_78_default_body_unknown_call` reports the error at the body as
      written in the trait, which is where the reader has to fix it.

## Milestone T08 — `where` clauses

Implementation:

- `where` is a keyword; clauses are accepted on functions, structs, `impl`
  blocks, and traits.
- A clause appends to the parameter's existing `TRAIT_REF` chain rather than
  replacing it, so `<T: Show>` and `where T: Weigh` compose to the union on one
  parameter. Bound checking learns nothing new: it reads `genericInfo` as before,
  which is what keeps this a notation rather than a second mechanism.
- Naming a parameter the declaration does not have is refused at the parser.
  Sema reads bounds through `genericInfo`, so an unmatched clause would be
  dropped silently and the constraint would never be checked.
- One rename was required: `src/aif/report.psm` held a local named `where`.

Acceptance evidence:

- [x] `test_104_where_clauses` covers a clause on a function, two parameters
      with one clause each, `+` inside a clause, the union with a bound already
      in the list, and clauses on an `impl` and a struct.
- [x] `neg_79_where_unknown_parameter`, `neg_80_where_bound_not_satisfied` and
      `neg_81_where_bound_not_trait` show the diagnostics match the
      parameter-list spelling.

## Milestone T09 — supertraits

Implementation:

- `trait Child: Parent + Other` stores supertraits as a `TRAIT_REF` chain on
  `TRAIT_DECL.child2`, not a name list: a supertrait may be an application, and
  comparing those is the same structural question a bound asks.
- A supertrait is an obligation on the *implementing type*, not an inheritance
  of methods. Each type writes its own `impl` of the parent; conformance checks
  the obligation transitively so one `impl` is told about every link at once.
- Cycles are diagnosed against the trait declaration, once, rather than at each
  implementing type. Both walks carry a depth bound so a cyclic declaration
  cannot recurse forever before the cycle is reported.

Acceptance evidence:

- [x] `test_105_supertraits` covers two supertraits joined with `+`, a
      three-link chain, and a parent's method reached through a bound on the
      child.
- [x] `neg_82_missing_supertrait`, `neg_83_supertrait_cycle` and
      `neg_84_transitive_supertrait` cover the obligation, the cycle, and the
      transitive case.

## Milestone T10 — associated constants

Implementation:

- `let NAME: Type` in a trait states the obligation; `let NAME: Type = value` in
  an `impl` discharges it. **No new keyword.** `let` is already how the language
  names an immutable value, including at module level (`let PRISMIO_VERSION`),
  and an associated constant is that idea owned by a trait rather than a module.
- `ASSOC_CONST` is appended to `NodeKind` so the committed seed's existing
  ordinals do not move. Trait constants hang off `TRAIT_DECL.child3`, an impl's
  off `IMPL_HEADER.child3`.
- **A use is replaced by the value, not resolved to a symbol.** `Type.NAME` is
  rewritten in place at the use site with a copy of the implementing type's
  value expression. That is what satisfies the milestone's bar: nothing is
  emitted, so there is no global for a same-named constant on another type to
  collide with. The use site's span is deliberately kept.
- Resolution is tried after the enum-variant paths, so a variant always wins and
  no existing program changes meaning.
- The value's type is checked against the declaration at the `impl` that wrote
  it, not at the use.

Acceptance evidence:

- [x] `test_106_associated_constants` covers Int and String constants, the same
      constant names on two types, and a constant used in an ordinary
      expression.
- [x] `neg_87_associated_constant_not_global` is the milestone's real bar: the
      bare name reports `unknown identifier`, proving the constant never enters
      the global value namespace.
- [x] `neg_85`, `neg_86` and `neg_88` cover a missing constant, a value of the
      wrong type, and a value written in the trait instead of the impl.

## Milestone T11 — associated types

Implementation:

- `type Item` in a trait names the obligation; `type Item = Int` in an `impl`
  chooses it. **`type` is contextual, not reserved.** It is an ordinary
  identifier in 179 places in this tree — `extern fn ir_alloca(type: String, …)`
  among them — so reserving it would have been a rename across the compiler to
  buy a word that is special in exactly two positions. The same reasoning the
  AIF annotations already use.
- `ASSOC_TYPE` and `ASSOC_TYPE_REF` are appended to `NodeKind` so the committed
  seed's ordinals do not move. Associated types share the member chain with
  associated constants and are told apart by kind.
- A projection `T.Item` is its own node, not a name containing a dot. Encoding
  structure as text is what the trait-argument work had to undo once already.
- `monoResolveProjections` rewrites a projection in place into an ordinary
  TYPE_ANNOTATION once its base is concrete, at each point where a template
  becomes a declaration — instantiation of a function, of a struct, the
  call-matching path, and default-method expansion. Nothing after
  monomorphisation has to know projections exist.
- A projection contributes nothing to *solving* a type parameter: `value: T.Item`
  cannot determine `T`, so `monoMatchParam` skips it and leaves the solution to a
  parameter that can.
- Equality constraints (`Container<Item = Int>`) parse through a trait-ref
  specific argument parser, because `parseTypeArgList` is shared with type
  annotations and generic struct literals. Positional arguments stay on `child1`
  so arity checking is untouched; constraints go on `child2`.
- An implementation that does not name a constrained member fails the bound
  rather than passing it vacuously.

Acceptance evidence:

- [x] `test_107_associated_types` covers projection in return and parameter
      position, two implementations choosing different types, an associated type
      on a generic impl, and both directions of an equality constraint.
- [x] `neg_89`, `neg_90`, `neg_91` and `neg_92` cover a missing associated type,
      a choice written in the trait, a projection through an undeclared member,
      and an equality constraint the implementation does not meet.
- [x] All 255 fixtures pass — the full native runner is green with no
      exclusions.
- [x] All 171 compiler-checked documentation snippets verify.

**One bug was introduced and caught by the suite.** Restructuring the member
conformance loop to dispatch on kind left one branch without advancing the
cursor, so a *missing* member looped forever emitting the same diagnostic — a
hang, not an error. The suite reported it as "compiler failed without reporting
a diagnostic", which is what that failure looks like from outside. The loop now
advances once, unconditionally, at the end of the body: there is no branch left
that can forget. Worth recording because the shape, not the fix, is the lesson.

## Milestone T12 — trait method namespaces and qualified calls

The milestone the coverage review argued should come early. It did, and the
argument held: T10 and T11 each needed a qualified spelling to keep a name out
of a namespace, while methods had none.

Implementation:

- **A trait method's symbol names its trait.** `semaFunctionSymbol` prefixes the
  mangled symbol with the owning trait, so `Loud::speak(Dog)` and
  `Soft::speak(Dog)` are two symbols rather than one. Before this, the second was
  rejected as a *duplicate definition* — the global method namespace charging for
  something the program never asked for. Inherent methods and free functions are
  unchanged.
- The owning trait is found by source position against the `IMPL_METHOD`
  records, the identity the checker already uses. No new node field was needed.
- `Loud.speak(dog)` parks the trait on the call's `s1`, the same mechanism a
  module-qualified call already used, and overload resolution reads it as a
  filter on the owning trait rather than on the declaring file. A qualifier
  *restricts* rather than prefers: naming a trait that does not declare the
  method is an error, not a fallback.
- An ambiguous unqualified call names the spellings that would resolve it, and
  the "declares no" diagnostic says *trait* rather than *module* when the
  qualifier is one.

Not in this milestone: methods are still spliced into the module chain as
ordinary functions, and an unqualified call still resolves through the global
overload set. What changed is that the namespace no longer *collides* — two
traits can coexist and the ambiguity is nameable. Restricting method visibility
to in-scope traits is the remaining half and belongs with T13's coherence work.

Acceptance evidence:

- [x] `test_108_trait_method_namespaces` covers two traits declaring one method
      for one type, a qualified call to each, an unqualified call where only one
      candidate exists, and a qualified call through a bound.
- [x] `neg_93_ambiguous_trait_method` proves the unqualified call is refused and
      the note names both spellings.
- [x] `neg_94_wrong_trait_qualifier` proves a qualifier restricts rather than
      prefers.
- [x] All 258 fixtures pass; the full native runner is green.

## Milestone T18 — ownership in the trait contract

Added by the coverage review, and taken early because it needed no new syntax:
conformance already compared signatures and simply did not compare the
convention.

Implementation:

- `semaCheckMethodConventions` compares each parameter's convention
  (`FUNCTION_PARAMETER.s2`) between the trait's signature and the implementation.
- Checked separately from signature matching and reported per parameter, so the
  message names the convention that differs rather than reporting "no such
  method" for a method the reader can plainly see.
- `semaHasConformingMethod` was split so the matching candidate is returned
  rather than a bool, which is what lets the conventions be checked on the method
  that was actually selected.

Acceptance evidence:

- [x] `test_109_trait_ownership` covers a trait each for `sink`, `inout` and a
      borrow, all honoured, called through the T12 qualified spelling.
- [x] `neg_95` and `neg_96` prove each convention cannot be quietly weakened to
      a borrow.
- [x] The reproduction recorded as G-002 in `aif/AIF_GAPS.md` is now rejected.

**The milestone is complete, contrary to what was first recorded here.** An
earlier note claimed return-position `produce`/`alias` were an unchecked half.
They are not: `parseFfiContract` runs only for extern parameters and extern
returns, so an ordinary function or trait method cannot carry a contract at all
and there is nothing for conformance to compare. Contracts describe an FFI
boundary; inside Prismio a return transfers uniformly. See G-003 in
`aif/AIF_GAPS.md`, recorded as `invalid` with the evidence.

## Milestone T21 — trait resolution termination

Added by the coverage review. The hole was real and worse than recorded: a
generic that instantiates itself with a strictly larger type made the compiler
**hang with no diagnostic at all**, indefinitely. Measured before the fix by
killing it at 60 seconds.

Implementation:

- **There is no call stack to bound.** Instantiation is demand-driven and appends
  to the chain `analyzeModule` is still walking, so the recursion is not on the
  stack — what grows is the type. That is what is bounded.
- The first measure written was wrong and the probe proved it: an
  already-instantiated generic arrives as a *mangled name*, not a tree, so
  `Box$Box$Int` is one annotation with no children and a tree-depth measure
  reported 1 forever. The nesting lives in the name, so the mangling separator is
  what counts it.
- Bounded in both instantiation paths, function and struct, at 32 — far past
  anything written by hand, and reached in 32 steps by a runaway.
- The offending type is 30 levels of mangled name by the time the bound fires, so
  the diagnostic elides the repeated tail; printing all of it buried the sentence
  that explains the problem.

Acceptance evidence:

- [x] `neg_97_nonterminating_instantiation` compiles to a diagnostic in about a
      second, where the same program previously hung indefinitely.
- [x] Legitimate nesting is unaffected: `Box<Box<Box<Int>>>` through a bounded
      generic impl still compiles and runs.
- [x] All 262 fixtures pass.

## Milestone T19 — orphan rule

Added by the coverage review, where the argument was that it gets more expensive
every day it waits. That was immediately confirmed: enforcing it broke an
existing fixture on the first run.

Implementation:

- An `impl Trait for Type` is legal where the module declares the trait or the
  type. Both foreign is what makes coherence unenforceable: two packages can each
  write it, neither can see the other, and the conflict surfaces only when some
  third program imports both.
- Per module, because the module is the unit a file declares in and the coarsest
  unit the compiler can attribute a declaration to. A built-in type is owned by
  nobody, so implementing a trait for `Int` requires owning the trait — which is
  exactly what `std/copy.psm` does, and why the standard library needed no change.
- Inherent implementations are not orphans; they name only a type.
- **Templates had to be searched as well as declarations.** A generic type leaves
  the declaration chain in `monoCollectTemplates` before sema runs, so a module
  declaring `Carrier<T>` and implementing a foreign trait for it looked like an
  orphan until the template chain was searched too.

`test_102_generic_trait_arguments` was a genuine orphan: it implemented traits
from `trait_args.source` for the built-in `String`. It now targets a local type,
which preserves what the fixture is actually for — a *foreign trait* applied to
*our* type, across a module boundary — and satisfies the rule.

Acceptance evidence:

- [x] `test_110_orphan_rule` covers all four legal shapes: foreign trait with our
      type, our trait with a foreign type, both ours, and our *generic* type.
- [x] `neg_98_orphan_impl` proves a foreign trait for a foreign type is refused.
- [x] All 262 fixtures pass, `std/` unchanged.

## Milestone T13 — blanket implementations

Smaller than expected, because T05's structural coherence had already been built
to handle it. What was missing was permission.

Implementation:

- The parser's blanket refusal is gone. An inherent `impl T` is still refused —
  it has no trait to give the methods a home and would put a method on every type
  at once — but a *trait* impl over a bare parameter is a blanket implementation
  and the trait names it.
- Coherence needed no change. `semaImplTargetsMayOverlap` already unified impl
  parameters structurally, so a bare parameter unifies with anything and a
  blanket implementation is reported as overlapping any concrete one for the same
  trait. Which of the two a call should select is not decidable without
  specialization, which stays deferred, so the pair is refused rather than
  ordered.
- Selection needed no change either: `monoImplApplies` solves the impl's
  parameter from the concrete target and checks its bounds, so
  `impl<T: Show> Pretty for T` covers exactly the types that are `Show`.
- The orphan rule from T19 applies unchanged: a blanket implementation names the
  trait, so the module writing it must own that trait.

Acceptance evidence:

- [x] `test_111_blanket_impls` covers a blanket implementation reached directly
      and through a bound, at two receiver types.
- [x] A type outside the blanket's bounds is still rejected for the bound
      (`Rock does not implement Pretty`) rather than silently covered.
- [x] `neg_68_blanket_trait_impl`, which previously guarded the unimplemented
      boundary, now covers the real constraint: a blanket and a concrete
      implementation of one trait overlap and are refused.
- [x] All 265 fixtures pass.

## Milestone T14 — operator traits

Implementation:

- A comparison operator whose operands are structs of the same type routes
  through `Ord`: `a < b` is rewritten to `cmp(a, b) < 0`, and so is every other
  comparison. **One lowering serves all six.** The operator keeps its meaning,
  codegen sees an ordinary call against an integer, and there are not six special
  cases to keep consistent — which is what the milestone's "predictable code
  generation" asks for.
- The rewritten call carries `Ord` as its qualifier, so T12's filter selects that
  trait's `cmp` rather than any function that happens to be named it.
- **Structs only, and only where `Ord` is implemented.** A primitive comparison
  is a machine instruction and stays one. Comparing structs was previously an
  error, so no program that compiled before changes meaning — the feature is
  purely additive.
- Where `Ord` is absent the original diagnostic stands, with a note naming what
  would give the operator a meaning.

**Equality goes through the ordering, deliberately.** `std` declares `Ord` and no
separate `Eq`, and adding one here would have created two ways to say the same
thing before there is a use for the distinction. A type that is equatable but not
orderable is the case that would justify splitting them; when one appears, `Eq`
belongs with T20's vocabulary, and the routing above is one branch away from
supporting it.

Acceptance evidence:

- [x] `test_112_operator_traits` covers all six operators on a struct, both
      outcomes of each, and confirms primitive comparison is unaffected.
- [x] `neg_99_compare_without_ord` proves a struct without `Ord` is still
      refused, now with a note naming the fix.
- [x] All 267 fixtures pass.

## Milestone T15 — trait objects and dynamic dispatch

The representation was chosen against one criterion set by the project owner:
**maximum runtime performance**, with ease of use breaking ties. Recorded here in
full so it is not re-derived, and because the reasoning is what makes it
reviewable.

### Decision 1 — a fat pointer, not a header word

`dyn Trait` is a pair: data pointer plus vtable pointer.

The alternative is C++'s: put the vtable pointer inside the object. That taxes
**every instance of every type**, whether or not it is ever used dynamically. In
Prismio nearly all code is monomorphised static dispatch, so a header word would
charge the whole program for a feature most of it never uses. A fat pointer keeps
the cost exactly at the `dyn` use sites, which is the property Rust cites for the
same choice.

It is also the faster dispatch. A header design must load the vtable pointer out
of the object before it can load the method; with a fat pointer the vtable
pointer is already in a register, so dispatch is one load rather than two.

The cost is two words per `dyn` value instead of one. That is paid only where a
trait object is actually used.

### Decision 2 — relative vtables, 4-byte offsets

Store each entry as a signed 32-bit offset from the vtable rather than an
absolute pointer. This is the Fuchsia/Rust `relative vtables` work, and the wins
are measured rather than theoretical: roughly half the vtable size, so more
entries per cache line and fewer misses during dispatch; vtables move to
read-only data with no dynamic relocations, which also removes startup relocation
work and copy-on-write page cloning.

The known wrinkle is the size field — a 64-bit size would force 8-byte alignment
and undo the saving. Bit-pack size and alignment, and cap object size at 4 GB.

### Decision 3 — borrowed `dyn` first, owned later

`dyn Trait` starts as a parameter type only: not stored in a struct, not put in a
`List`, not returned.

This is the fastest and the smallest first step, and the two coincide. An owned
`dyn` needs a destructor slot in every vtable and an **indirect call on every
release**, and AIF has to learn a type whose release it cannot see. Borrowed
`dyn` needs none of that: no drop slot, no indirect release, no AIF change at
all. It still covers the common case — passing any `Show` to a function.

The fat-pointer layout above is chosen so owned `dyn` is an addition (a drop slot
plus AIF work), not a rewrite.

### Decision 4 — object safety: strict on what cannot work, permissive where it is free

Refuse what genuinely cannot have one vtable: a method mentioning `Self` outside
the receiver, and a generic method. Both would need a different function per
implementing type, which is what a vtable slot cannot express.

**Allow associated types when the use site pins them** — `dyn Iterator<Item =
Int>` is accepted, bare `dyn Iterator` is not. This costs nothing at runtime,
because the vtable is per-implementation either way, and it is the difference
between `Iterator` being usable as an object or not. T11's equality constraints
are already the mechanism.

### Implementation

Built in the order the dependencies forced, backend first, because the frontend
half could not be tested without it.

**Backend (`runtime/llvm-api-backend.c`).** There was no typed indirect call —
the only one was `ir_call_indirect_ptr`, hardcoded to `fn(ptr) -> void` for the
collector's visitor. Added `ir_call_end_indirect`, which closes a call opened by
`ir_call_begin` with a loaded callee instead of a name, building the function
type from the arguments already pushed. Added `ir_vtable_declare/begin/entry/end`
and `ir_ptr_slot`.

**Vtables are declared before functions and defined after them.** A body takes a
table's address while it is being generated, and the entries are only knowable
once the functions they name exist. The length is knowable up front — it is the
trait's method count — so the declaration carries the final type and the
definition supplies only the initialiser.

`ir_ptr_slot` reads the Nth pointer of a pointer array, and serves both halves of
dispatch because both are that shape: a vtable is an array of function pointers,
and an object is an array of two.

**A trait object is a struct.** `dyn Show` parses to the name `dyn$Show` — `$`
cannot occur in a source identifier — and sema synthesises a two-field struct for
it. Prismio already passes structs by pointer, so parameters, arguments and
codegen's layout table all carry one with no special case. The register-passing
refinement the design describes would be an ABI change and was not made; the
property that mattered is kept, which is that **no vtable pointer goes into any
value of any type**.

**Object safety** rejects a method mentioning `Self` away from the receiver, and
a trait with an associated type. The generic-method rule is written and currently
unreachable: a trait cannot declare a generic method at all, so the parser
refuses one first. It becomes live if that changes.

**An object is a borrow, and that is enforced rather than incidental.** `dyn T`
is legal as a parameter and nowhere else. This was found by testing rather than
assumed: returning one and binding one were rejected only by accident — coercion
happens at call arguments, so both failed as type mismatches — and **a struct
field holding one was accepted outright**, which would have left a pointer into a
dead frame. `semaCheckDynPositions` now refuses all four positions with a
diagnostic naming the trait as written.

Four defects surfaced and were fixed, two of them visible only in the packaged
toolchain build:

- A sema type key was handed to the backend where an IR storage key was needed
  (`unknown type key (Int)`).
- Vtables were emitted after the functions that referenced them.
- `LLVMConstArray2` is not declared in `runtime/prismio_llvm.h`, the hand-written
  subset the packaged toolchain compiles against. An undeclared function there
  returns `int`, which is a pointer-conversion error rather than a link failure.
- `typeDisplay` printed the internal `dyn$Show` in diagnostics, showing the reader
  a type they cannot spell.

Acceptance evidence:

- [x] `test_116_trait_objects` covers dispatch to two implementations, a method
      with arguments beyond the receiver, two traits over the same types, and an
      object forwarded to another function that also takes one.
- [x] `neg_101`, `neg_102` cover object safety; `neg_103`, `neg_104` cover the
      borrow rule at a field and a return; `neg_105` covers `dyn` on a non-trait.
- [x] All 277 fixtures pass; 171 documentation snippets verify.

**Not in this milestone.** Owned objects — storing one in a field, returning one,
putting one in a `List`. That needs a destructor slot in every vtable and an
indirect call on every release, and AIF has to learn a type whose release it
cannot see. The representation above was chosen so this is an addition rather
than a rewrite.

## Milestone T20 — standard trait vocabulary

Scope chosen by the project owner: `Eq`, `Display`, and `Iterator` with `for`
integration. A `Drop`-shaped trait was considered and deliberately left out — it
interacts with AIF's release placement and needs its own design pass.

### `std/eq.psm`

`Eq` is split from `Ord` because equality is the weaker requirement: a colour or
a set is equatable with no meaningful order, and before the split `==` on such a
type meant inventing a `cmp` that means nothing.

**`==` prefers `Eq` and falls back to `Ord`.** Splitting without the fallback
would have taken `==` away from every type that had it through `Ord` alone — a
feature removal dressed as a refinement. `cmp(a, b) == 0` is what equality means
for an ordered type, so one `impl Ord` still gives all six operators.

### `std/display.psm`

`Display` gives a type its text. `std.io` carries one `print` overload per
builtin and a user type could never join that set; `show` moves the decision to
the type, once. It returns a `String` rather than writing to a stream because a
caller wants the text as often as it wants it printed.

### `std/iter.psm`

`Iterator` is `hasNext` + `next`, not `next() -> Option<Item>`. **The
conventional shape would put an allocation in the innermost part of every loop**
— payload enums are not tagged unions yet, so `Option<Item>` costs a value per
element. This pair answers the same two questions with none.

`next` takes `inout self`, so an iterator must be a `mut` binding. That is not
checked here: T18 made conventions part of the contract, so it falls out.

`for x in it` desugars to `while (hasNext(it)) { let x = next(it) … }`. **A
`while`, not the range loop the other two collections desugar to** — the protocol
exists so a stream with no known length can be iterated, and a range needs an
end. `Countdown` in the fixture has no backing collection at all.

Three defects surfaced and were fixed:

- Projections were resolved only during instantiation, so `impl Iterator for
  Countdown` writing `-> Self.Item` — never instantiated — left `Item` unresolved.
  Now resolved module-wide before checking.
- Conformance compared the trait's unresolved `Self.Item` against the
  implementation's concrete choice. The signature's projection is now resolved
  against each impl before comparing, on a copy: the trait's node is shared by
  every implementation, so resolving in place would fix the first one's choice
  for all of them.
- The desugar rewrote the statement into a `while`, and the caller carried on
  reading it as a range. It now re-enters as the statement it became.

Acceptance evidence:

- [x] `test_113_std_eq_and_display` covers an equatable-but-unordered type, an
      ordered type reaching all six operators through the `Ord` fallback, and
      `Display` on a user type and three builtins through a bound.
- [x] `test_114_iterator` covers `for` over two implementations with different
      `Item` types, one of them a stream with no backing collection, and confirms
      String iteration is unchanged.
- [x] `neg_100_for_over_non_iterator` names the three things that would fix it.
- [x] All 270 fixtures pass; 170 documentation snippets verify.
- [x] `RUNTIME.md` lists the three new modules, per CLAUDE.md's rule that the
      `std/` surface is part of the change.

## Milestone T17 — production hardening

Covers T01-T14 and T18-T21. T15 and T16 are not implemented, so nothing here
claims to harden them.

### Compile-fail coverage

100 negative fixtures, every milestone represented. Each asserts a specific
diagnostic string rather than merely that compilation failed, so a check that
starts reporting the wrong error fails rather than passing quietly.

### Import and visibility

`test_115_trait_imports` takes the whole trait surface across a module boundary:
methods, a default, an associated constant, an associated type, the trait as a
bound, and a *local* implementation of an imported trait.

The interesting case is a default method that calls a helper marked `private` in
the declaring module, inherited by an implementation in the importing module. It
works, and the reason is the span: the expansion keeps the trait's, so the
synthesised method has the declaring module's scope. Visibility follows the code
as written rather than where it was inherited.

A trait cannot itself carry `private` or `internal`. That is consistent with the
language — those markers apply to functions and methods, not to types — and is
recorded here rather than treated as a gap.

### Measurements

Emitted code, `src/main.psm`, T06 baseline versus now:

| | binary | emitted IR |
|---|---|---|
| T06 baseline | 1,971,688 | 4,336,621 |
| now | 2,027,240 | 4,336,743 |

**The emitted IR grew by 122 bytes, 0.003%.** That is the number that matters: a
program using none of these features pays essentially nothing for them. The
compiler binary is 2.8% larger, which is the frontend code itself.

Compile time for `src/main.psm`, median of seven runs: **1.124s → 1.172s, +4.3%**.

That figure was 8.7% before three optimizations, and the honest account is that
two of the three hypotheses were wrong:

- **Right.** The symbol was recomputed at every call site although
  `semaCacheFunctionSymbols` had already cached it on the node — and since T12
  that computation walks impls. Reading the cache: ~1%.
- **Right, smaller than expected.** `monoResolveProjections` was a full recursive
  walk of every declaration on every compile. Guarded by a shallow scan for any
  declared associated type: ~3%.
- **Wrong.** `semaOwningTrait` walking the whole declaration chain per function
  looked quadratic and worth fifteen million steps. Replacing it with an index
  built once bought ~0.4%. The index is kept because it is the better shape, not
  because it was the cost.

The residual is diffuse — more passes, a larger binary, more instruction cache
pressure — and was not chased further. Subprocess timing on this project is
known to mislead (see the benchmark methodology notes), so the claim here is
deliberately modest: same-order compile time, unchanged emitted code.

### Verification matrix

- [x] 271 of 271 native fixtures, no exclusions.
- [x] Two generations byte-identical.
- [x] AIF differential agrees on all 19 sources in both modes.
- [x] Documentation snippets verify.
- [x] The committed seed still builds `src/`.

## Joint verification

- [x] **The full native runner is green: 277 of 277, with no exclusions.** The
      long-standing `aif_rc` failure was diagnosed and fixed; it was a stale
      proxy inside the check, not a compiler defect. See `aif/AIF_GAPS.md`
      G-001, which records the reproduction and the negative control.
- [x] Two generations bootstrap and emit byte-identical compiler IR
      (`build/t15-fx1.ll` and `build/t15-fx2.ll`, 4,448,611 bytes).
- [x] AIF differential agrees on all 19 sources in both modes.
- [x] All 165 compiler-checked documentation snippets verify.
- [x] The committed seed still builds `src/`, so the two-step syntax rule holds:
      nothing in `src/` yet uses the syntax added in T06–T20. (`std/eq.psm`,
      `std/display.psm` and `std/iter.psm` use only syntax the seed knows.)
- [x] `../docs` gained sections for defaults, `where`, supertraits, and
      associated constants, associated types, and five stale claims were corrected: "Default
      method bodies in a trait" and "associated constants" under *Not in 0.1*,
      "There are no `where` clauses yet" in `generics.md`, and "There are no
      methods, associated functions, constructors, or `impl` blocks" in
      `structs.md`, which was wrong on three of its four counts, and
      "Associated types" under *Not in 0.1*.

## Next session

**20 of 21 milestones are done.** 277/277 fixtures with no exclusions,
byte-identical two-generation fixpoint, AIF differential agrees on all 19
sources, 171 documentation snippets, and the committed seed still builds `src/`.

### The one milestone left

**T16 — `impl Trait` opaque/existential types.** T15's representation decisions
are made and written up above, which is what T16 was waiting on.

Argument position is the easy half and is close to sugar: `fn f(v: impl Show)`
means `fn f<T: Show>(v: T)`, and the machinery for that is T01's. Do it first —
it is a parser rewrite plus a name for the synthesised parameter.

Return position is the real work: `fn make() -> impl Show` returns one concrete
type the caller cannot name, which needs an opaque type that unifies with exactly
one implementation per function, and a rule for what happens when two `return`
statements in one body pick different types. It is *not* a trait object and must
not be lowered as one — the whole point is that it stays statically dispatched.

### Then, the standing refactor of `runtime/*.c`

Already scoped in `C_CODE_STYLE.md` under "The standing refactor", in its own
priority order. Note the constraint from CLAUDE.md: this is behaviour-preserving,
so it **must produce byte-identical compiler output**, verified with two
generations to a fixpoint, the full suite, and `tools/aif_differential.py`. The
baseline to hold is `build/t15-fx2.ll`, 4,448,611 bytes.

1. Split `aif_support.c` (7,257 lines) along the six responsibilities its own
   banner comments already mark, into `runtime/aif/`.
2. Delete the 54 bare banners across `runtime/`.
3. Hoist the `rt_base_alloc` seam — `lang_runtime.c` defines its own copy of the
   macros ahead of its includes.
4. Split `llvm-api-backend.c` (now ~4,300 lines) into IR construction and
   target/layout query, which do not call each other.

### Smaller items, in rough order of value

- **Owned trait objects.** T15 ships borrowed-only. Storing or returning one
  needs a destructor slot in every vtable, an indirect call on release, and AIF
  learning a type whose release it cannot see. The representation was chosen so
  this is an addition.
- **The unqualified-call namespace.** T12 stopped methods colliding and gave them
  a qualified spelling, but an unqualified call still resolves through the global
  overload set rather than through in-scope traits.
- **`dyn Trait<Item = Int>`.** Object safety currently refuses any trait with an
  associated type. Pinning it at the use site is free at run time and would make
  `Iterator` object-safe; T11's equality constraints are the mechanism.
- **A `Drop`-shaped trait.** Considered for T20 and deliberately left out — it
  interacts with AIF's release placement and needs its own design pass.
- **`Eq` for `Map` and `List`.** `std/eq.psm` covers the builtins only.
- **Compile time.** +4.3% against the T06 baseline, residual and diffuse. Three
  optimizations are recorded in T17 along with which hypotheses were wrong;
  profile before attempting a fourth.

`../docs` is a sibling repository, current as of T15 and **uncommitted**. Commit
it there, and re-run `node scripts/verify-doc-examples.mjs` after any language
change. New memory or ownership holes go in `aif/AIF_GAPS.md` with a
reproduction rather than a description.

## Deferred, and why

The seed is not refreshed and does not need to be yet. `src/` and `std/` use
none of the syntax added in T06-T10, so the committed seed still parses `src/`.
That step comes due only when the compiler's own sources start spelling
`trait From<T>`, a default body, a `where` clause, a supertrait, or an
associated constant -- and it must land as its own commit before any such use,
per CLAUDE.md.
