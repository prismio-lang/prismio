# M4.1 — first-class `Slice<T>`

**2026-08-25.** This is the implementation and gate record for TODO M4.1. It does not claim M4.3:
the compiler still stores records as AoS/inline AoS and does not emit SoA columns.

## Surface and representation

`list[start..end]` produces `Slice<T>`; the same expression on a Slice composes its offset. The
descriptor is exactly SPEC 8.4's `{ List handle, i32 offset, i32 length }`. It is a copyable view,
owns no element storage, and never keeps an interior buffer address. `slice_len`, indexed reads,
and explicit `slice_set` resolve the list handle at every access. Construction and access validate
the range, so growing/reallocating a list cannot strand a view and a bad range fails loudly.

Overlapping mutable Slices are permitted. `tests/test_79_slices.psm` covers scalar, String and
inline-struct elements; nested slices; two overlapping writers; list growth after view creation;
generic Slice parameters and returns; and a Slice stored in a struct. Direct `List<Slice<T>>` is
rejected because the descriptor is three words and the boxed list slot is one pointer. Extern Slice
parameters and returns are rejected until the compiler has an explicit marshalling copy.

## Ownership result

The AIF walk records a view provenance edge and no allocation site. E-VIEW raises the underlying
collection to at least the view's escape. Returning a Slice initially exposed an old precision bug:
the generic caller-escape constraint raised a *borrowed parameter collection* to T2. A distinct
return constraint now raises a collection owned by the returning function while leaving a
parameter bounded by the caller's actual binding. `test_79_slices.psm --verify` is clean at
9 allocated / 9 released / 0 leaked / 0 violations.

## Discriminating gates

- `fixture_slice_bounds.psm` must fail with the range diagnostic.
- `fixture_slice_escape.psm` returns a view of a local list and runs safely; its collection is not
  released in the callee.
- `neg_32` rejects slicing an array, `neg_33` rejects a mismatched write, and `neg_34` rejects an
  undefined FFI ABI.
- `slice_gate` inspects the emitted aggregate and helper calls, checks growth and values, and reads
  the escaping function's IR to prove it does not release the viewed list.
- Slice runtime declarations are emitted only in a module that uses Slice. The IR snapshot has 107
  existing programs byte-identical and two differing only in LLVM's identified-type suffix; the
  compiler plus the three new Slice fixtures are the only substantive additions.

## Verification and measurement

- fixed point: `build/m4-slice-8` and `build/m4-slice-9` emit identical `src/main.psm` IR;
- suite: **155/155**;
- independent AIF differential: **17/17** sources agree in both modes;
- committed-seed cold start agrees with the warm compiler;
- runtime/backend source lists agree and `git diff --check` is clean;
- public docs: 97-page content/link audit, 118 compiler-checked snippets, ESLint, and the
  105-page Webpack production build are green;
- `graphify update .` rebuilt the repository graph (3,205 nodes / 5,587 edges);
- M4.1 milestone corpus gate: checksums agree, RSS holds, corpus median **1.001×**, gate passed;
- cross-language 25-run refresh recorded in `xlang/results-m4-slices.json`.

The first timing pass showed g5 at 1.211× while its minimum was faster. A/A calibration on the same
host spanned 0.946×–1.095×, and the emitted g5 IR then proved the point more sharply: before the
conditional-declaration cleanup its only difference was five unused declarations; afterwards the
whole file is byte-identical to the old compiler's. No Slice operation exists in the corpus, so the
honest result is **no existing-program runtime effect**. M4.3, not M4.1, owns the SoA performance
exit gate.
