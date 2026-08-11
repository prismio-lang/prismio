# RESULTS — the string/parse axis

*2026-08-09. Apparatus: [`xlang/g7bench.py`](xlang/g7bench.py), sources in
[`xlang/prismio/g7.psm`](xlang/prismio/g7.psm) and [`xlang/rust/`](xlang/rust/).
Reproduce with:*

```bash
python3 aif/evidence/xlang/g7bench.py --compiler build/gen4 --runs 20
```

---

## 0 · Why this file exists

**There was no string/parse measurement.** g1–g6 are object-graph and numeric
workloads, so every cross-language number in [RESULTS-xlang.md](RESULTS-xlang.md)
comes from a program that barely touches a string. BENCHMARKS §3.2 lists this
one as **B2**, "lex + parse a large generated source, string-heavy", and marks it
buildable — it was never built.

That matters more than a missing row. The compiler is itself a string-heavy
program, and the shape of its hot loop — scan a buffer, cut each token's text out
of it — was the one shape nothing measured.

The workload is deliberately `src/lexer/scanner.psm`'s: 21 282 bytes of generated
source, 2 801 tokens, one slice per token, the text compared against a keyword and
length-summed. Every port asserts `checksum tokens 427914`, so a port that
tokenized differently could not be timed against the others.

---

## 1 · The measurement

20 runs × 200 iterations, samples pooled, medians.

| | median | p99 | rel |
|---|---:|---:|---:|
| Rust idiomatic — `&src[a..b]`, no copy | **0.019 ms** | 0.039 | **1.00×** |
| Rust owned — copy per token | 0.103 ms | 0.191 | 5.49× |
| **Prismio — `str_slice`** (today) | **0.074 ms** | 0.140 | **3.92×** |
| Prismio — `str_substring` (before this session) | 1.833 ms | 2.090 | **97.31×** |
| Prismio — scan only, slicing removed entirely | 0.031 ms | 0.055 | 1.78× |

Three things fall out of it, and the third is the one to act on.

**Prismio was 97× idiomatic Rust on string-heavy code.** Not 1.2×, not 5×. This
axis was never measured, and it was by an order of magnitude the worst result
this project has recorded.

**With the representation held constant, this compiler beats rustc.** Prismio at
3.92× against Rust-doing-the-same-copy at 5.49× is **0.71×** — the same shape as
g2's 0.63× in RESULTS-xlang §8. The backend is not the problem on this workload,
and the scan-only row says so independently: **1.78×**.

**So the entire remaining gap is the copy.** 3.92× against 1.78× for the same
scan with slicing deleted. That is the number the representation work is worth,
and it is measured rather than projected.

---

## 2 · What was wrong: `str_substring` rescans the whole buffer

A `String` here is a NUL-terminated `char*`. `str_substring(s, start, length)`
has no way to bound `start` or clamp `length` except `strlen(s)` — a scan of the
entire source, **once per token**.

Scaling, tokenizing the same generated source at four sizes:

| lines | bytes | `str_substring` | `str_slice` | ratio |
|---:|---:|---:|---:|---:|
| 100 | 5 317 | 0.314 ms | 0.033 ms | 9.6× |
| 200 | 10 636 | 0.996 ms | 0.056 ms | 17.8× |
| 400 | 21 282 | 2.276 ms | 0.106 ms | 21.5× |
| 800 | 42 598 | 7.050 ms | 0.185 ms | 38.2× |

Doubling the input multiplied `str_substring` time by **~2.9×** and `str_slice`
time by **~1.8×**. The superlinear term is the `strlen`, and it is gone.

Isolated the other way: the identical scan with the slice call removed runs in
0.031 ms at 400 lines against 1.815 ms with it. **`str_substring` was 98% of the
tokenizer.**

### The fix, and why it is only half of one

`str_slice(s, start, length, base_len)` takes the length the caller already has.
Five call sites in `src/lexer/scanner.psm`, one runtime function.

**This is the same defect `str_char_at` had, and the same fix.** `createLexer`
already measures the input once into `Lexer.length`, and the comment there says
why: a per-character `strlen` made scanning quadratic. That fix landed on the
character reads in a previous session and **never reached the slices**, which is
where the tokens are actually cut. Half of a fix had been in the tree, with a
comment explaining the principle, for as long as the other half was missing.

`str_slice` is `(base, offset, length)` reduced to what today's `String` can
carry, and it stops there: it still allocates and copies, because its *result*
must be a NUL-terminated buffer. Deleting that needs the value to **be**
(base, offset, length) — SPEC §8.4's view — which is the representation half and
is not built. §1's table prices it at 2.2×.

---

## 3 · The compiler itself

Same input, two compilers differing only in the lexer. `src/main.psm` flattens
all 385 KB of `src/` through imports, and `-o *.ll` stops before clang, so this
is frontend time.

| | |
|---|---|
| before (`str_substring`) | 78.0 ms |
| **after (`str_slice`)** | **62.1 ms** |

**−20%**, from one runtime function. RESULTS-xlang recorded the frontend at
103 → 80 ms when `-O2` was turned on; this takes it to 62.

The known gap "compile time is superlinear in module size" attributes the
remaining superlinearity to sema scanning the module per identifier. One of the
two terms was lexing, and it was this.

---

## 4 · What did *not* move, and why that is the finding

**The manifest is byte-identical.** 367 sites, 266 T1 / 101 T2, 264 arena-served,
before and after. Not one allocation site disappeared.

The brief for this work asked how many of the compiler's arena-served T1 string
sites views would delete. Measured, the answer is **none of the ones that matter,
because they are not T1**:

| | |
|---|---|
| T1 String sites, arena-served (`region:auto`) | 264 |
| the lexer's five per-token slice sites | **all T2 `owned`** — malloc |

A T1 site is already served from a bump arena and costs almost nothing. The
per-token slices escape into the `Token`, so they are T2, and every one is a
`malloc`. **Views target the T2 population, not the T1 one.** A count of T1 sites
disappearing would have been the wrong measurement of the right thing.

*(The figure of 209 T1 string sites in circulation is stale — it is 266, of which
264 are arena-served.)*

**And `str_trim` has no callers.** One mention in `src/main.psm`, inside a
comment. Making it non-allocating buys nothing measurable and was not done.

---

## 5 · What this changes about the ranking

RESULTS-xlang §9 ranked inline `List<T>` storage first, worth 1.09×–8.88×
depending on the record, and listed views as its enabler. That is still true.

What is new is that **views have a large prize of their own, on an axis that was
never measured**: 3.92× → ~1.8× on string-heavy code, which is the difference
between "within a factor of 4 of Rust" and "at the backend's floor". For a
compiler, an interpreter, a parser or any text-processing program — the shape
SPEC §9 already identifies as most non-numeric code — that is the whole gap.

The blocker is unchanged and is worth stating exactly, because it is the same one
that stopped by-value POD returns last session: a view is three words, and this
language has **no by-value struct return**. `str_slice` needed none, which is why
it landed in an afternoon; a view needs the value to live in the caller's storage,
and the designed-not-built chain for that ends at "the call expression must become
an AIF allocation site in the caller", with a use-after-free failure mode.

**Views and by-value POD returns are the same project.** Neither is worth
starting without the other, and together they are now the highest-value item on
the list by a margin that this file, rather than a projection, establishes.
