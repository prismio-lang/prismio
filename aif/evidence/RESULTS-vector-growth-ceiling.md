# `vector_growth`: 93% of it is one modulo chain, and the redundant load is not redundant

Measured 2026-09-06. Asked whether `vector_growth` can be improved. **Materially,
no** — and both halves of that answer are worth having, because the obvious fix
is a 2.7x regression.

Prismio 10.785 ms, C++ 10.726, Rust 9.876 — 1.006x of C++ and 1.092x of Rust,
interleaved, 21 samples, one process per sample.

## 1 · The benchmark is a serial modulo chain, not a container benchmark

The loop is `list_push(values, i % 997)` plus
`checksum = (checksum + value) % 1000000007`, four million times. Written in C
and ablated (`vg/ceiling.c`), medians of 21 one-shot processes:

| variant | C | Prismio |
|---|---:|---:|
| full | 9.836 | 10.805 |
| **`modonly` — the two modulos, no push at all** | **9.174** | **9.128** |
| `nosum` — drop the checksum modulo | 2.776 | 4.533 |
| `pushonly` — no arithmetic at all | 1.593 | 3.241 |
| `reserve` — capacity up front, no growth | 9.766 | 9.754 |

**The checksum modulo alone is 93% of the benchmark**, and Prismio's is *exactly*
C's — 9.128 against 9.174. `checksum = (checksum + value) % 1000000007` is a
loop-carried dependency through `smull; asr; add; msub`, about eleven cycles of
pure latency per iteration, and all three languages emit the identical five
instructions. Rust's disassembly is instruction-for-instruction the same.

Growth costs C 0.07 ms and is not the subject either, despite the name.

So the whole addressable gap is the push: 1.68 ms in Prismio against C's 0.66 ms,
which is 1.0 ms — and the measured gap to Rust is 0.91 ms. That is the entire
opportunity, and it is capped at about 9%.

**Two levers priced at zero on the way past.** An unsigned accumulator is
*slower*, not faster — 14.630 against 10.053, because the magic sequence for an
unsigned divisor near 2^30 needs a 33-bit constant and an extra fixup, where the
signed one does not. And a probe compiler with the representation test forced
true and every bounds check dropped moves the benchmark 10.760 -> 10.785. Zero,
for the second workload running.

## 2 · The reload that looks redundant is load-bearing

`list_push_inline_scalar` and four siblings in `runtime/lang_runtime.c` write
`l->len = l->len + 1` *after* storing the element. `l->len` is an `int` and so is
an element of a `List<Int>`, so clang must assume the store may have changed the
length and **reloads it** — visible in the benchmark's disassembly as
`ldr w8, [x19, #8]` immediately after `str w20, [x9, x8, lsl #2]`.

Reading the length into a local first removes that load. The generated loop is
then strictly one instruction shorter, and:

| shape | `pushonly` | `full` | `nosum` |
|---|---:|---:|---:|
| `l->len = l->len + 1` after the store (**as it is**) | **3.341** | 11.385 | **4.840** |
| length hoisted into a local | 9.171 | 11.287 | 9.486 |
| hoisted, and the bump moved before the store | 9.139 | 11.447 | 9.382 |

**2.7x slower for one fewer instruction**, reproducibly, with no overlap between
the distributions (`pushonly` min 3.366 / max 4.230 against min 9.391).

The cause is store-to-load forwarding. The `len` bump stores **four** bytes at
offset 8. With the reload present, the value on the critical path comes from a
matching four-byte `ldr` at offset 8, which forwards cleanly from the previous
iteration's store. Remove it and the critical path runs through the
`ldp w8, w9, [x19, #8]` that loads `len` and `cap` **as a pair** — an eight-byte
load partially overlapping a four-byte store, which cannot forward and must wait
for the store to reach L1. Moving the bump ahead of the element store does not
help; the overlap is between iterations, not within one.

**Reverted.** The compiler is back at the pre-existing fixpoint
`119c6d4f5e69c207971ec998e452fe9f`.

## 3 · What would actually collect the 9%

Separate `len` and `cap` in `RtList` so clang cannot pair them. With two
single-word loads, `len` forwards cleanly *and* the reload can go — the two fixes
only conflict because the fields are adjacent. That is a header layout change:
`RtList` in `runtime/lang_runtime.c`, `rt_list_header_type()` and the
`RT_LIST_FIELD_*` offsets in `runtime/llvm-api-backend.c`, and
`run_list_header_agreement_test` in `tests/test_runner.py`, which exists to catch
exactly this drift. It is worth about 1 ms on `vector_growth` — 10.79 -> ~9.8,
which would put it under both C++ and Rust — and the same load is in every
unguarded push in the language, so `struct_creation`, `allocation_mutation`,
`transient_allocation` and `nested_collection` should be measured with it too.

Do not attempt it without re-reading §2 first. The redundant-looking load is the
thing keeping the recurrence on the forwarding path, and removing it *alone* is
a 2.7x regression.
