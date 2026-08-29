# Known issues

What is open in Prismio 0.1.0, with enough of each to act on. None of these is
unsoundness unless it says so; every one was found by a measurement or a test
rather than by reading, and the measurement is in `aif/evidence/`.

Detail for any of these — the reproducer, what was tried, what was refuted — is
in `git log`, which is where this project keeps its record. Commit messages carry
their own evidence.

## Ownership

**A `spawn`ed call's owned temporary argument has no owner.** `spawn f(g(x))`
where `g` produces an owned value: the argument-position release that covers the
ordinary call is not emitted through `spawn`, so the temporary leaks. Writing the
argument at the spawn site avoids it, which is what `aif/corpus/g9_bands.psm`
does and says.

**The argument-position release is withheld when the enclosing call returns a
pointer.** Conservative on purpose — the callee may return the argument — but it
is withheld more often than that case requires.

**An escape through an `extern` declared `alias` is still open.** The
pass-through fix covers Prismio callees; a foreign function declared `alias` that
returns its argument is not yet covered by the same fact.

**UMS resolution releases nothing it allocates.** Not unsoundness — `violations`
is 0 either side — but a real regression in allocation hygiene. The recorded fix
moves the ledger by zero; the real shape is about eight lines, and the clause to
widen can double-free, so it needs the owners enumerated first.

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

**The corpus does not vectorize**, and the remaining lever is `noalias` derived
from the ownership analysis. Type-based alias information alone was priced at
1.73x on the ECS loop; scoped alias metadata was priced at 1.40x and rejected —
it does not vectorize, so it is not worth building on. `!invariant.load` on the
`List` header would hoist it and would be **unsound**: the header is rewritten by
`list_push`.

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
