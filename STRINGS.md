# The Prismio String representation

How `String` is laid out, why it is laid out that way, what it cost, and what
was tried and thrown away. Companion to [RUNTIME.md](RUNTIME.md), which is the
map of what a program can call, and to
[MEMORY_ALLOCATION_DEEP_DIVE.md](MEMORY_ALLOCATION_DEEP_DIVE.md), which covers
allocation everywhere else.

Every number here was measured on this repository. The commands that produce
them are in [§11](#11-reproducing-the-measurements).

---

## 1 · Summary

`String` is sixteen bytes — a machine word and a length word — and it holds its
text in one of **three** storage classes, chosen by two bits of the length word:

| class | where the bytes are | owns | costs |
|---|---|---|---|
| **inline** | in the pair itself, up to 12 bytes | nothing | a 12-byte copy |
| **owned** | behind the pointer, NUL-terminated | a heap block | an allocation |
| **view** | behind the pointer, inside a longer buffer | nothing | nothing |

This is the layout the Umbra paper introduced and that Arrow, DuckDB, Velox,
Polars and CedarDB variously call a *German string* or a *StringView*. The one
thing Prismio does differently is the third class: Umbra's `transient` string
asks the programmer to remember that the buffer behind it may die, and Prismio's
view is held alive by the ownership analysis instead. §7 is about that.

On the `tokenization` benchmark — cut 54,000 one-to-eight-byte tokens out of a
204 KB buffer — the effect, measured as one alternating run of 31 samples per
binary on the same machine:

| stage | min ns | p50 ns | × C++ |
|---|---:|---:|---:|
| heap `String` (where this started) | 1,002,959 | 1,063,041 | 4.09× |
| \+ small-block recycler | 542,167 | 579,583 | 2.23× |
| \+ German strings | 274,958 | 294,375 | 1.13× |
| \+ copy ladder, equality, `borrow` | 260,625 | 285,333 | 1.10× |
| **\+ view class** | **210,833** | **218,750** | **0.84×** |
| C++ (`libc++`, SSO) | 230,917 | 260,208 | 1.00× |
| Rust (`String::to_string`) | 864,834 | 969,959 | 3.73× |

**4.86× end to end**, and the row now runs at 0.84× of C++ and 0.23× of Rust.
Allocations, counted by the `--verify` ledger on the same workload at scale 1:
**13,502 → 2**.

---

## 2 · The problem, as measured

The starting point was not a hunch. `tokenization` was the worst row in the
cross-language suite at 3.4× of C++, and the first question was *where*.

Removing the token materialisation and hoisting the input out of the timed
region separates the two halves of the workload:

| | Prismio (then) | C++ |
|---|---:|---:|
| scan 204,000 bytes | 148 µs | 149 µs |
| materialise 54,000 tokens | 777 µs | 97 µs |

**The scanner was already exactly as fast as `clang -O3`.** The generated code
was not the problem: `charIsSpace` inlines to a 64-bit bitmask test, the byte
read is a bare GEP-and-load, and the copy loop auto-vectorises. All of the gap
was in producing the token.

Interposing `malloc` said the same thing more bluntly:

| | malloc calls | bytes |
|---|---:|---:|
| Prismio | 54,033 | 436,452 |
| Rust | 54,037 | 367,722 |
| **C++** | **29** | 226,139 |

C++ was not faster at allocating. It was not allocating. `libc++`'s
`std::string` holds 22 bytes inline, every token in this workload is eight bytes
or fewer, and so `std::string token = ...` never touches the heap. Prismio and
Rust each made one allocation per token.

A profile of the Prismio binary put **67% of the run inside libmalloc's free
path**, and over half of *that* inside `mach_absolute_time` — macOS's allocator
timestamps every free for its quarantine.

Two conclusions followed, and both turned out to be right: the allocator was
worth attacking on its own, and the representation was worth attacking after
that.

---

## 3 · What the field does

| design | size | inline | extra |
|---|---:|---:|---|
| `libc++` SSO | 24 B | 22 | — |
| `fbstring`, `smartstring` | 24 B | 23 | — |
| `compact_str` | 24 B | 24 | exploits UTF-8 to use all 24 |
| `ecow` | 16 B | 15 | O(1) clone |
| **German / Umbra** | **16 B** | **12** | 4-byte prefix, storage classes |
| interning (`rustc`'s `Symbol`) | 4 B | — | O(1) equality, dedup |
| slices (`&str`) | 16 B | — | zero copy *and* zero allocation |

Two things made the German layout the right family rather than plain SSO.

The first is that it is 16 bytes, not 24. `String` was already a `{ptr, i64}`
pair, so nothing that holds one — a local, a parameter, a struct field — grows.

The second is the storage classes. The pointer's spare bits distinguish a string
that owns its bytes from one that merely points at somebody else's, and that
second case is what a tokenizer is made of. Umbra's paper describes it as a
`transient` string and tells you plainly: *if you need to access it later, you
need to copy it to memory that you control.*

The honest counterweight, and the reason the work below is as careful as it is:
DataFusion reported that a straightforward StringView implementation **slowed
down almost every query** before they engineered around it, including a case
where constructing a short string was 10× slower than a long one until they
specialised the path. Every stage here was measured against the stage before it,
and three changes were reverted for measuring flat or worse.

---

## 4 · Sizing it from our own allocations

Choosing 12 inline bytes because Umbra chose 12 would be borrowing someone
else's workload. The question is what *this* language allocates, so the
allocation path was instrumented directly — a histogram of `length` inside
`str_with_capacity` — and the compiler was pointed at its own front end.

**444,798 string allocations in one `prismio check src/main.psm`:**

| length | share | cumulative | covered by |
|---|---:|---:|---|
| ≤ 4 | 53.3% | 53.3% | |
| ≤ 8 | 21.3% | 74.6% | |
| ≤ 12 | 6.7% | **81.3%** | German / this design |
| ≤ 14 | 4.5% | 85.7% | a 16-byte tagged pair with no prefix |
| ≤ 16 | 6.4% | 92.1% | |
| ≤ 22 | 4.4% | **96.5%** | `libc++` SSO, at 24 bytes |
| ≤ 30 | 2.3% | 98.8% | |
| > 30 | 1.2% | 100% | |

**Over half of every string this compiler allocates is four bytes or fewer.**
Any inline scheme at all captures the bulk of the traffic; the argument between
12, 14 and 22 is an argument about the last fifteen points — and the view class
takes most of *those*, because what is left is dominated by substrings.

One trap worth recording. Interposing `malloc` over the same run reports 47.9%
at ≤ 16 and 35.3% at ≤ 64, which would have argued for a much larger inline
buffer. That histogram is wrong for this question: it mixes AST nodes and list
blocks in with strings. Only the `str_with_capacity` histogram is about strings.

---

## 5 · The layout

```
%prismio.str = { ptr, i64 }                       // 16 bytes, unchanged

  field 1, bits  0..30   byte length (max 2 GiB)
  field 1, bit      31   INLINE
  field 1, bits 32..63   INLINE ? data[8..11]
                                : bit 32 = VIEW, bits 33..63 reserved
  field 0                INLINE ? data[0..7]
                                : the data pointer
```

Note that bit 32 is *data* when INLINE is set and the VIEW flag only when it is
clear. The two are never ambiguous because INLINE is checked first, and that
overlap is what invariant 2 in §6 is about.

Three decisions in that block are load-bearing.

**The tag is at bit 31, not bit 63.** At bit 63 it would share a byte with the
twelfth inline character, and the layout would reach ~80% of allocations instead
of 81.3%. Putting it inside the length instead caps strings at 2 GiB rather than
4 and costs one `and` on every `.length()`. That was the better trade.

**The tag is explicit, not `len <= 12`.** German strings use the length itself as
the discriminant, which works when every string is constructed whole. Prismio has
a second producer — `fatFromPtr`, which wraps a `char*` arriving from C — and it
can hand back a *short* string that lives on the heap. Using the length as the
tag would read those as inline and dereference twelve bytes of text as an
address.

**The long form is bit-for-bit what the compiler emitted before.** That is what
made the change landable in pieces: every producer not yet taught to inline kept
producing exactly what it did, and only a pair that says INLINE is read the new
way.

### The four-byte prefix is deliberately absent

German strings put the first four characters of a long string beside its length,
so a comparison can reject most mismatches without dereferencing. Published
microbenchmarks put equality at 3–3.5× with it.

It is not here, and it cannot be, for a structural reason worth stating: **a
prefix has to be computed when a string is complete, and a Prismio long string is
never complete at any single point.** `str_with_capacity` hands back an
*uninitialised* buffer and the caller fills it byte by byte — that is what
`strCopyRangeInto` and every builder in `std/string.psm` do. A database
materialises a value once and can stamp a prefix on the way past; a language that
lets you build a string incrementally has nowhere to put that hook.

What replaced it is stronger for the case that dominates. See §6.

---

## 6 · The invariants

The representation is only as good as the properties that hold everywhere. There
are five, and each one is load-bearing — the failure mode is in the right-hand
column.

| # | invariant | established by | breaks as |
|---|---|---|---|
| 1 | An inline string's bytes past its length are **zero** | `ir_str_inline` zeroes the buffer and writes exactly `[0, n)` | equality answers wrong |
| 2 | INLINE **dominates** VIEW in the tag test | bit 32 is data when bit 31 is set | a free of twelve bytes of text |
| 3 | `count > 12` ⟹ the source is not inline | `strSubstring` tests it one line above | a view offsets a non-pointer |
| 4 | A view is **never** NUL-terminated | it ends inside a longer buffer | reads past the view |
| 5 | `__builtin_string_put_byte` only writes long-form buffers | every caller writes into a fresh `str_with_capacity` | the write lands in a scratch copy and is lost |

**Invariant 1 is what pays for the missing prefix.** If two short strings hold
the same text, and their lengths are equal, and everything past the length is
zero, then the two 16-byte pairs are *bit-identical*. So `==` on two short
strings is two integer compares in registers — no dereference, no call, no length
walk. That is strictly stronger than a four-byte prefix for the case the
histogram says dominates. Measured: **48×** — 193 µs against 9.35 ms for four
million comparisons.

Invariant 1 is also why `ir_str_inline`'s copy ladder is written to cover exactly
`[0, n)` and not one byte more. `[0,8) ∪ [n-8,n)` is contiguous for `n ≤ 12`
because `n-8 ≤ 4`; the same holds for the four-byte case. The zeroed tail
survives.

**Invariant 2 is why one mask does two jobs.** `word & (INLINE|VIEW)` answers
"does the deallocator get anything?" correctly even though bit 32 is a data bit
when INLINE is set — because when INLINE is set the answer is *no* either way.

---

## 7 · Lifetimes: why a view is safe here and advisory in Umbra

A view is a pointer into a buffer somebody else owns. The obvious question is
what stops that buffer dying first. Umbra's answer is documentation. Prismio's is
that the analysis already knew how to say it.

`__builtin_string_view(s, start, count)` is declared to **alias its first
argument** (`aifFfiAliasOf` in `src/aif/contracts.psm`). That is the existing FFI
5.2 `alias` contract — *the return is an existing value reached through an
argument, not a fresh allocation* — and it makes the returned pair carry `s`'s
allocation sites rather than sites of its own. Two things follow without any new
inference:

- **Nothing releases the view.** It has no sites of its own to release.
- **The base stays alive while the view does.** A caller that would have freed
  `s` while a value derived from it is still live is exactly the case
  `aif_fn_may_return_view_of_param` was introduced for, and that fact is computed
  from the same graph.

`strSubstring` returns `__builtin_string_view(...)` on its long path, so
`strSubstring` itself becomes a function that may return a view of its parameter,
and the property propagates to every caller in the compiler and standard library.
The compiler self-hosts on this, the fixpoint is reached, and the suite is
285/285 — which is the practical evidence that the propagation is real.

---

## 8 · What the view class costs

Exactly three places, all consequences of invariant 4.

**Equality compares by length.** `strcmp` has no terminator to stop at, so the
slow path calls `str_equals_n` with the length out of the pair — which the fast
path has already established is equal on both sides.

**`str_own` copies by length.** A container slot is one word and the container
frees what it holds, so a view entering a list is copied out. So is an inline
string, whose bytes live in the caller's frame. Neither can use `str_clone`,
because that walks to a NUL.

**The FFI boundary copies and releases.** A view crossing into C gets a
NUL-terminated copy, made behind a branch so the other two classes pay nothing,
and released as soon as the call returns. This is the same shape Swift uses for
its own small-string form when a `String` reaches a C parameter.

Everything else needed no change. Byte access already reads through field 0,
which a view has; the release already answers "not mine" from the tag.

---

## 9 · Results

### 9.1 The workload the work was aimed at

Per 54,000-token pass, input hoisted out of the timed region:

| | before¹ | now | C++ |
|---|---:|---:|---:|
| scan | 148 µs | 150 µs | 123 µs |
| materialise | 450 µs | **52 µs** | 95 µs |
| total | 598 µs | **202 µs** | 218 µs |

¹ the state the representation work started from — the recycler had already
landed, which is why materialisation reads 450 µs here and 777 µs in §2.

Token materialisation is now **cheaper than C++'s**, which is what the third
storage class buys: `libc++` still copies each token into its inline buffer, and
a view copies nothing at all.

### 9.2 The rest of the suite

Across all 34 implemented workloads, measured against the commit this work
started from, no checksum changed:

- `tokenization` **1.31× faster**
- 31 workloads within 3%
- `fft` at 0.91× and `knapsack` at 0.90×

Those last two do not touch strings, and their machine code is **byte-identical**
in both builds — same instruction sequence, same instruction count, only the
function's address moved to a different 64-byte alignment. Code layout moves a
tight numeric loop by ±10% here, which is worth knowing before believing any
single-workload regression in this suite. The floor for one pass is about ±4%.

### 9.3 Supporting measurements

| what | result |
|---|---|
| short-string equality, 4M compares | 193 µs, against 9.35 ms via `strcmp` — **48×** |
| `malloc_size` (the recycler's bucket query) | ~14.5 ns per call |
| 54,000 small blocks: malloc/free vs pool vs none | 2,225 µs / 168 µs / 176 µs |
| `borrow` → `readonly`, short haystack searched in a loop | min 5.28 ms → 4.84 ms |
| copy ladder vs `memcpy` call | 1.107× on the full row |

---

## 10 · What was tried and rejected

A design document that lists only what worked is a brochure. These were built,
measured, and removed.

**Region/arena placement for the tokenizer.** Prismio already has `region`, and
the natural first move was to bracket the scan in one. It placed **zero** arena
objects — the allocation lands in `str_with_capacity`, an extern with 80 call
sites in that binary, so neither call-site bracketing obligation holds. The AIF
summary reported 100% T2 for the program, which means ownership is *static*, not
that allocation is cheap.

**Pointing codegen's allocator at the runtime seam.** Symmetry argued for
emitting `rt_base_alloc` alongside `rt_free`. It buys nothing — the allocations
that benefit are made inside the runtime, which already calls it — and it costs:
`malloc` is a name LLVM's TargetLibraryInfo knows, so the call carries `noalias`
and `allocsize` for free, and an opaque symbol must be assumed to clobber
everything. `tree_traversal` read **0.88×** with the swap and 1.00× without.

**Curating `rt_free` into the program's own module.** Codegen emits it for every
release, so it looked like the obvious next entry in `PRISMIO_CURATED_OPS`. It
does inline the gate and remove a call per release, and it moved nothing —
`tokenization` 1.67× against 1.72× uncurated, `tree_traversal` 0.953× against
0.960×, both inside the noise. It also required exporting three of
`lang_runtime.c`'s statics. Reverted, with the measurement recorded where the
other two waivers are.

**Caching the canonical pointer per SSA value.** The obvious fix for
re-materialising a short string at every use. It does nothing: each use of a
variable emits its own `load` of the pair, so they are distinct values and every
lookup misses. Placing the cached value at the pair's *definition* to make it
dominate later uses then produced a basic block with no terminator and a compiler
that could not build itself. The working version keys on the **binding** instead
— a `let` or a parameter resolves the representation once where it is bound,
which dominates every use by construction.

**Putting that materialisation behind a branch.** Unconditional stores into the
scratch cannot be lifted out of a byte loop, because the pointer that follows
comes from a `select` that may *be* the scratch, so LICM must assume the load
reads what the stores wrote. A branch fixes the aliasing and reads **328 µs
against 262 µs** — the control flow costs more than the stores it avoids.
Reverted.

**Bounding the copy length to help LLVM.** Masking `count` to four bits before
handing it to `llvm.memcpy`, so a provable bound of 15 might let it expand
inline. The call is still in the disassembly. Removed rather than left in looking
like it did something; the ladder is what removed it.

**`charAt`'s bounds check as the scan gap.** C++ indexes unchecked, so the check
was the obvious suspect for the remaining scan difference. It is free: swapping
`charAt` for the unchecked `byteAt` over the same 204 KB reads 229/214, 229/229
and 194/194 µs, because LLVM proves the index from the loop guard.

---

## 11 · Reproducing the measurements

```bash
prismio bench --only tokenization --runs 9
```

The A/B numbers above are not from a single `bench` run. Building two compilers
and alternating their outputs sample-by-sample is what makes a 4% difference
readable; running one binary and then the other does not, because the machine
drifts more than that.

Allocation counts, at the Prismio level rather than libc's:

```bash
prismio build tests/test_09_strings.psm -o /tmp/probe --verify && /tmp/probe
```

The string-length histogram is not committed — it is a temporary counter inside
`str_with_capacity`. Note that **editing `runtime/*.c` does not affect compiled
programs until the compiler is rebuilt**: the compiler carries a snapshot of the
runtime sources in `embedded_sources.h`, and the object cache will report a hit
on the stale one.

---

## 12 · What is not done

**The scan is still 150 µs against C++'s 123.** That 27 µs is now the whole of
what separates the two halves, and it has survived both obvious explanations
(§10). The three materialisation stores *are* visible in `benchTokenization`'s
inner digit loop; what is not established is that they are what costs.

**Views are only taken above twelve bytes.** Below that the inline form already
copies into registers and carries no lifetime dependency, so the trade is not
obviously worth making. It has not been measured.

**`nocapture` is not applied.** LLVM 22 spells it `captures(none)` and
`LLVMGetEnumAttributeKindForName` returns 0 for the old name, so the attribute is
silently skipped. `readonly`, which is the half that matters for hoisting, maps
fine.

**Nothing uses the reserved bits.** Bits 33–63 of a long string's length word are
free. A prefix cannot go there for the reason in §5, but a hash could.

---

## References

- Neumann & Freitag, [*Umbra: A Disk-Based System with In-Memory Performance*](https://www.vldb.org/cidrdb/papers/2020/p29-neumann-cidr20.pdf), CIDR 2020 — the original layout.
- CedarDB, [*Why German Strings are Everywhere*](https://cedardb.com/blog/german_strings/) and [*A Deep Dive into German Strings*](https://cedardb.com/blog/strings_deep_dive/) — storage classes and the prefix.
- Apache DataFusion, [*Using StringView to Make Queries Faster*](https://datafusion.apache.org/blog/2024/09/13/string-view-german-style-strings-part-1/) — measured wins, and the warning that a naive port is slower.
- Polar Signals, [*Das Problem mit German Strings*](https://www.polarsignals.com/blog/posts/2025/08/26/das-problem-mit-german-strings) — the memory-overhead counterargument.
- [`string-rosetta-rs`](https://github.com/rosetta-rs/string-rosetta-rs) — sizes and inline capacities of the Rust ecosystem's variants.
- [musl](https://git.musl-libc.org/cgit/musl/tree/src/string/aarch64/memcpy.S) and [Folly](https://github.com/facebook/folly/blob/main/folly/memcpy.S) — the overlapping-load small-copy ladder §9.3 measures.
- Raymond Chen, [*An informal comparison of the three major implementations of std::string*](https://devblogs.microsoft.com/oldnewthing/20240510-00/?p=109742) — where `libc++`'s 22 bytes comes from.
