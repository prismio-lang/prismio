# Trait System Roadmap

Last updated: 2026-09-02

This file is the durable cross-session record for bringing Prismio traits and
`impl` blocks from the v0.1 static-conformance subset toward a production-grade
system. Update the status table, acceptance evidence, and next-session section
whenever a milestone moves.

Status values: `todo`, `in progress`, `done`, `blocked`.

## Current model

Prismio currently supports trait signatures, `Self`, `impl Trait for Type`, and
multiple `+`-joined bounds on a generic type parameter. Generic code is
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
can unify. Trait identities themselves are still plain names until T06.

## Ordered milestones

| ID | Feature | Status | Depends on | Acceptance bar |
|---|---|---|---|---|
| T01 | Multiple bounds (`T: A + B`) | done | — | Parser preserves every bound; instantiation checks every bound; diagnostics identify the failing bound; positive and negative fixtures pass. |
| T02 | Impl-owned conformance | done | T01 | Only methods declared by the matching `impl Trait for Type` satisfy that trait; unrelated inherent/global methods do not. Migrate `Key + Copy` so cross-impl accidental conformance is unnecessary. |
| T03 | Coherence and duplicate-impl rejection | done | T02 | Reject two applicable implementations of the same trait for the same concrete type with source-directed diagnostics. |
| T04 | Generic inherent impls | done | T02, T03 | Accept `impl<T> Box<T>`; instantiate methods consistently with generic functions/types; reject unconstrained type parameters. |
| T05 | Generic trait impls | done | T04 | Accept `impl<T: Bound> Trait for Box<T>` and select it only when its bounds hold. |
| T06 | Generic traits and trait arguments | todo | T05 | Accept declarations such as `trait From<T>` and implementations such as `impl From<Int> for String`; include trait arguments in identity/coherence. |
| T07 | Default trait methods | todo | T02, T04 | Trait methods may have bodies; an impl may omit them or override them; defaults are type-substituted and emitted once per concrete use. |
| T08 | `where` clauses | todo | T01, T04 | Express equivalent bounds outside parameter lists on functions, types, and impls with consistent diagnostics. |
| T09 | Supertraits | todo | T01, T02 | `trait Child: Parent` requires `Parent`; inherited requirements are checked transitively without cycles. |
| T10 | Associated constants | todo | T02, T04 | Declare, implement, type-check, and resolve trait-owned constants without entering the global value namespace. |
| T11 | Associated types | todo | T06, T09 | Support `type Item`, equality constraints, and projection (`T::Item`) in signatures and generic bodies. |
| T12 | Trait method namespaces and qualified calls | todo | T02, T06 | Resolve methods through the receiver and in-scope traits; support an unambiguous qualified spelling; stop treating every method name as an unrestricted global. |
| T13 | Blanket implementations | todo | T05, T06, T12 | Support implementations over type parameters with overlap/coherence checks and deterministic selection. |
| T14 | Operator traits | todo | T06, T11, T12 | Route supported operators through standard traits while retaining useful diagnostics and predictable code generation. |
| T15 | Trait objects and dynamic dispatch | todo | T02, T06, T11, T12 | Define object safety, `dyn Trait` representation, vtable emission, ownership rules, coercions, and dynamic call lowering. |
| T16 | `impl Trait` opaque/existential types | todo | T06, T11, T15 | Support argument and return-position opaque trait types with a precise ownership and ABI model. |
| T17 | Production hardening | todo | T01–T16 as applicable | Compile-fail coverage, import/visibility tests, two-generation bootstrap fixpoint, full suite, AIF differential, docs verification, and performance/code-size measurements. |

Advanced Rust facilities such as auto traits, negative impls, specialization,
generic associated types, and unsafe traits are intentionally deferred until the
core milestones above demonstrate a concrete Prismio use case.

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

## Next session

1. Read this file and inspect `git diff` before editing.
2. Begin T06 by giving TRAIT_DECL and the impl header structural trait parameter
   and argument nodes; do not put `From<Int>` into `IMPL_DECL.s2` as text.
3. Include trait arguments in bound identity, conformance substitution, generic
   applicability, and coherence before enabling `trait From<T>` in compiler
   sources.
4. Add ambiguity and arity diagnostics for missing, extra, and unresolved trait
   arguments, plus cross-module fixtures.
5. Re-run the full native suite when the unrelated LLVM attribute work is
   compatible with the installed Clang.
