# M4.4 — generic/container layout specialization

**Status: GREEN, 2026-08-25.** Suite **166/166**. The focused verifier reports
**8 allocated / 8 released / 0 leaked / 0 violations**. The 25-run A/A corpus
control is **0.997×** median new/old (range **0.978–1.099×**), so M4.4 changes
no generated-code performance by design.

Raw benchmark: [`results-m4-generic-layout.json`](results-m4-generic-layout.json).

## Question

M4.2 chooses inline or boxed `List<T>` operations from `T`'s layout. M4.4 asks
whether an unresolved type parameter can reach that choice and make one generic
body interpret the same container as two incompatible representations.

That is the collision documented by Project Valhalla: erased generic code does
not have the specialized representation needed to flatten a value into generic
storage. OpenJDK's [Valhalla project](https://openjdk.org/projects/valhalla/)
describes runtime specialization as a separate capability, and its
[object-model design note](https://cr.openjdk.org/~briangoetz/valhalla/sov/02-object-model.html)
explains why erased `ArrayList<Point>` cannot receive the flattening available
to a specialized representation.

## Answer: Prismio chooses after substitution

Prismio does not emit one runtime-polymorphic generic body:

1. `monoCollectTemplates` removes generic declarations from the module chain
   before sema.
2. A call solves each type parameter, copies the template, substitutes concrete
   types through the copy, and appends a demand-created clone.
3. Sema checks that concrete clone. Codegen never sees the template or an
   unresolved `T`.
4. `inlineElemSizeOfList` reads the list expression's static element type. It
   returns a size only for a concrete, flat, non-counted struct; an invalid or
   non-struct element returns zero and therefore selects the boxed family.

This is AST-level monomorphisation followed by layout selection. It is the safe
ordering: specialize first, then flatten. It also keeps representation choice
out of the runtime hot path.

## Discriminating gate

[`tests/test_82_generic_layout.psm`](../../tests/test_82_generic_layout.psm)
instantiates the same `singleton<T>`, `genericGet<T>` and `genericSet<T>`
templates for two incompatible concrete layouts:

| concrete `T` | property | required lowering |
|---|---|---|
| `Flat { x: Int, weight: Float }` | 16-byte flat, non-counted value | `list_push_inline`, `list_get_inline`, `list_set_inline` |
| `Named { label: String, value: Int }` | pointer-bearing / non-flat | `list_push`, `list_get`, `list_set`; no `_inline` call |

`run_generic_layout_specialization_test` extracts the six exact mangled clone
bodies and checks those calls independently. The runtime half executes both
construction/read representations plus the flat write and requires the clean
verifier ledger. A compiler that decides from the template, always boxes, or
always flattens fails the gate.

The boxed set clone is demanded by a concrete wrapper and inspected in IR, but
is not executed in this fixture. That is deliberate separation of concerns:
boxed `OBJECT` replacement currently does not reclaim the overwritten object,
because Prismio does not yet prove that every element borrow has ended. Freeing
unconditionally would exchange a leak for a use-after-free. This pre-existing
borrow-liveness limitation is recorded in `TODO.md`; it is not evidence against
the generic representation choice.

## Performance control

M4.4 adds a test and documentation, not compiler/runtime code. Both benchmark
arms are therefore `build/m4-dataview-c-12`; `--calibrate` labels the result as
the host floor rather than an optimization effect.

| program | old ms | new ms | new/old | idiomatic Rust ms | tuned Rust ms |
|---|---:|---:|---:|---:|---:|
| g1 | 22.278 | 24.494 | 1.099× | 18.651 | 4.728 |
| g2 | 33.001 | 32.287 | 0.978× | 18.358 | 10.361 |
| g3 | 49.874 | 49.729 | 0.997× | 45.496 | 30.772 |
| g4 | 68.072 | 67.753 | 0.995× | 21.697 | 17.822 |
| g5 | 50.028 | 49.906 | 0.998× | 29.432 | 4.381 |
| g6 | 150.994 | 150.780 | 0.999× | 56.291 | 39.877 |

**Corpus median: 0.997×.** Five programs are within 2.2%; g1's 9.9% A/A swing
is measurement/layout noise from byte-identical compiler arms, not a task
regression. Checksums agree across all four variants and executable sizes are
identical. The performance result for this milestone is **no change**, as the
architecture proof requires.

## Exit

- positive and negative suite: **166/166**;
- exact concrete-inline vs concrete-boxed clone gate: green;
- verifier: **8 / 8 / 0 / 0**;
- A/A corpus control: **0.997×**, gate passed;
- generated compiler/runtime code: unchanged.

M4 is complete. The next sequential milestone is M5.1, evaluating mimalloc on
the four workloads whose allocation counts still exceed Rust.
