# Scalar list writes cross the curated boundary

**Status: LANDED, 2026-09-02.** `list_set_inline_scalar` and
`list_push_inline_scalar` were the two scalar-element operations codegen emitted
but the curated runtime module did not carry. The accessors were correct, but a
hot scalar write loop retained a real call per element.

## Boundary

The first obstacle was closure. `list_push_inline_scalar` reached inline-list
growth, which in turn reaches the runtime's arena and allocator internals. A
curated body is copied into the program module; leaving a reference to a
translation-unit-local symbol there creates an undefined symbol at final link.

The split mirrors boxed `list_push_grow`:

- `list_inline_grow(void*)` has external linkage and retains the arena-aware
  allocation and copy;
- `list_push_inline_scalar_slow` owns lazy stamping, representation fallback,
  and growth; and
- `list_push_inline_scalar` contains only the established-list fast path and one
  call to that exported slow boundary.

`scalar_store` is small enough that clang folds it into both curated bodies.
`list_set_elem_inline` and the boxed fallback functions already have external
linkage. The result passes the closure check at **15 curated operations**.

The emitted-operation gate was widened as part of the change. Scalar calls are
selected after `inlineOpName` returns its generic list operation, so the old
test saw only the three struct spellings and could not notice this omission.
It now includes the two scalar refinements: five emitted operations, three
curated scalar/read operations, and the two struct write operations still
waived by their earlier negative measurement.

## Code shape

On the retained 20M-write discriminator, the old `main` contains direct calls
to both `_list_push_inline_scalar` and `_list_set_inline_scalar`. The new `main`
contains neither. The set loop is constant-stride address arithmetic plus a
four-byte store on the flat arm; its representation-mismatch arm still calls
boxed `list_set`. Push keeps a call only to
`_list_push_inline_scalar_slow`, reached for the initial stamp and subsequent
growths rather than for every established-list push.

## Measurement

Fifteen interleaved runs after one discarded warm pair, on Apple arm64 with
LLVM 22.1.8. The before compiler already includes scalar storage, the flat-read
intrinsic, and M2.1b reuse; the only intended variable is scalar-write curation.

| discriminator | before | after | after / before |
|---|---:|---:|---:|
| 20M `list_get` | 2.041 ms | 1.963 ms | 0.962x |
| 20M `list_set` | 18.929 ms | **7.721 ms** | **0.408x** |
| sieve to 2,000,000 | 6.849 ms | **3.505 ms** | **0.512x** |

The complete spreads were 1.691–3.424 / 1.755–3.058 ms for read,
18.786–20.598 / 7.597–7.838 ms for write, and 6.627–15.237 /
3.403–5.817 ms for sieve. Checksums remain `-6279`, `-182`, and 148,933 primes.

This measurement also distinguishes the two halves of the outline. Exporting
growth made set inline, but push was still too large and sieve read 0.739x.
Moving stamping, fallback and growth behind the slow boundary removed the push
call and took sieve to 0.512x.

## Gates

- compiler IR fixpoint: `scalar-write-gen4` and `scalar-write-gen5` are
  byte-identical, SHA-256
  `539654f0ba842a3306262c8b01956b68dff78b016227a3ab043554812e573108`;
- AIF differential: **19 / 19** sources agree in both modes;
- full current-tree suite: **224 / 225**; all 175 file fixtures pass and the
  sole failure is the already-reproduced dirty report/UMS `rc_alloc` baseline;
- curated closure and emitted-operation gates pass;
- scalar fixture under both `PRISMIO_INLINE_RUNTIME=0` and
  `PRISMIO_INLINE_ELEMS=0`: **12 / 12 / 0**, 0 violations;
- source lists agree and `git diff --check` is clean.
