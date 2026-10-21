# Porting C to Prismio: a working manual

A short guide for turning a C module into Prismio. Every Prismio snippet here was
checked with `prismio check` or run with `prismio run` against the 0.1 compiler.
The worked example is [`aacdec_usac.c`](#8-worked-example-aacdec_usacc).

## 1. Scope the port first

- **Port the pure core, keep the glue in C.** Bit readers, tables, DSP kernels and
  state machines port cleanly. Code that is wired to a host framework (`AVCodecContext`,
  `AVFrame`, `av_log`, `ff_refstruct`) does not. Either keep that glue in C behind a
  reviewed `extern fn` (see [calling C](../../website/apps/docs/content/guides/calling-c.md)),
  or rewrite it at the boundary.
- **Port leaves before callers.** Get the tables and small readers working first,
  then the functions that use them.
- **Expect no bit-exact output for float code.** See [section 4](#4-numbers).

## 2. Type map

| C | Prismio | Notes |
|---|---|---|
| `int` | `Int` | Both are 32-bit |
| `unsigned`, `uint32_t` | `U32` | Overflow wraps, as in C unsigned |
| `int64_t`, `uint64_t` | `I64`, `U64` | Mixing widths needs `as` |
| `uint8_t`, `unsigned char` | `U8` | Bytes |
| `size_t` | `Usize` | Indexes accept any integer type |
| `float` | `Float` | **`Float` is 64-bit. There is no 32-bit float in 0.1** |
| `double` | `Float` | |
| `bool`, `_Bool` | `Bool` | Not an integer. `if (x)` becomes `if x != 0` |
| `char` | `Char` | One byte |
| `struct s` | `struct` | Nominal, move-only |
| `T *p`, written through | `inout p: T` | The caller must hold `let mut` |
| `const T *p`, read only | `p: T` | Borrowed by default |
| `T *buf` with a length | `Vec<T>` (growable), `Array<T, N>` (fixed, inline in a struct), or `[T]` (a parameter, length passed separately) | |
| `buf + k` | `buf[base + k]`, or a sub-view (section 3) | |
| nullable pointer | `T?`, tested with `== none`, read with `??` or `expect` | |
| `void *` | no equivalent. Use an enum or struct | |
| function pointer, or a table of them | a `trait` with one method per entry, passed as `dyn Trait` (a parameter) or as a bound `T: Trait` | Closures cannot be stored in a struct, so a table of closures is not an option |
| `enum` | `enum` (nominal) | Ordinal values need no work. Explicit C values go in an `impl` method, `code()`, with a `match` |
| `AVERROR_*` return codes | `Result<T, E>` with an error `enum` | |
| multiple out-params or returns | a `struct` | No tuples |

## 3. Pointers and state

C pointers are aliases you can keep. Prismio borrows last only for the call, and
nothing can be stored. Translate each pointer by what the callee does with it:

1. **Written through** → `inout`. Example: `unsigned *seed` becomes `inout st: NoiseState`.
2. **Read only** → an ordinary parameter. It is a borrow.
3. **Returned or stored** → return the value, or a copy. Pointers into a struct's storage
   cannot be returned, so return an index instead.
4. **A pointer into an array, `&buf[k]`** → pass the container `inout` and an index.
5. **A sub-block, `coef + off`** → take a view. Slicing needs a `Vec` (or a `Slice`), so
   a `[T]` parameter cannot be sliced. Pass a `Vec` and use `buf[a..<b]`.
6. **A shared context, `AACDecContext *ac`** → one `inout ctx: Ctx`. Do not keep
   sub-pointers between calls; index again.

Struct fields have their own rules:

- A fixed-size field is `Array<T, N>`, stored inline. A `[T]` field is refused.
- A variable-size field is `Vec<T>`.
- Reads and writes go through the field: `ctx.coeffs[i] = v`.
- `s.x += 1` is refused. Write `s.x = s.x + 1`.
- Passing a field as `inout` works: `bump(ctx.history, 1)`.

Ownership is automatic. Delete every `free`, `av_freep`, `av_refstruct_unref` and
`memset(s, 0, sizeof *s)`. For the last one, reset each field, because `s = default`
is refused on an `inout` parameter.

## 4. Numbers

This is the change most likely to cost you.

- **`float` → `Float` is a precision change.** C `float` math is single precision, and
  Prismio's `Float` is double. Outputs will differ in the last bits. Validate float code
  against a tolerance, not by byte comparison.
- **Integer overflow wraps** in Prismio (`value * 69069 + 5` on `U32` is the same as C's
  unsigned arithmetic). Signed overflow is undefined in C but wraps here, which only
  matters if the C code relied on UB.
- **Widths must match.** `Int + I64` is refused. Write `(k - p + 1) as I64`.
- **Float to integer casts saturate** and NaN becomes 0. C leaves that undefined.
- Maths: `x.sqrt()`, `(2.0).pow(e)`, and `max(a, b)` / `min(a, b)` on `Int` from
  `std.math`. `FFMAX`/`FFMIN` on other types become an `if` or a helper.

## 5. Control flow and syntax

| C | Prismio |
|---|---|
| `#define N 2` | `let N: Int = 2` (a constant, valid in `Array<T, N>`) |
| `static const int T[] = {…}` | `let T: [Int] = [...]`. Elements must be literals |
| `((int[]){0, 28})[i]` | a global table, as above |
| `for (i = 0; i < n; i++)` | `for i in 0..<n` |
| `for (i = 0; i <= n; i++)` | `for i in 0..n` |
| `while (cond)` | `while cond` |
| `do { … } while (c)` | `loop { …; if not c { break } }` |
| `while ((t = get_bits(gb, 4)) != T)` | `loop { let t = …; if t == T { break } … }`. No assignment expressions |
| data-dependent or counting-down loops | `while` with explicit `k -= 1` |
| `switch` with fallthrough | `match (x) { … }`. No fallthrough. Repeat the arm or move it into a helper |
| `&&`, `||`, `!` | `and`, `or`, `not` (`&&` and `||` do not parse) |
| `outer: for …` with `break outer` | `outer@ for …` with `break@outer` |
| `static inline` | `fn` (or `inline fn` when measured) |
| `return AVERROR_INVALIDDATA` | `return Result.Err(DecodeError.InvalidData)`, read with `match` |
| `if (!p) return …` | a `T?` parameter, checked with `== none` |
| `av_log(…)` (variadic) | no variadic externs. Return an error, or use `eprintln` |
| `unsigned seed = …; seed * k` | `let mut seed: U32` and the same operators |

Two syntax traps seen while checking this guide:

- `match` takes a parenthesised value: `match (pos) { … }`.
- A literal bound directly to a `Vec` parameter may fail to resolve (`no overload…`).
  Bind it first: `let swb: Vec<Int> = [0, 2, 4]`.

## 6. Errors

C reports failure with a negative code and a side effect. Prismio makes the failure part
of the type:

```prismio
import std.option

enum DecodeError { InvalidData, Unsupported }

fn readWidth(inout gb: BitReader) -> Result<Int, DecodeError> {
    let width = getBits(gb, 3) as Int
    if width == 0 { return Result.Err(DecodeError.InvalidData) }
    return Result.Ok(width)
}

fn caller(inout gb: BitReader) -> Int {
    match (readWidth(gb)) {
        Result.Ok(w) => { return w }
        Result.Err(e) => { return -1 }
    }
}
```

There is no `?` operator. Propagation is a `match` in each caller, so keep one error
`enum` per module to make that short. Use `panic`, `assert` and `unreachable` only for
invariants, not for bad input.

## 7. Porting procedure

1. **List the state.** Which pointers are written, which are read, and which alias.
2. **Translate signatures** using sections 2 and 3.
3. **Set every width** and write each cast.
4. **Replace error codes** with `Result` or `T?`.
5. **Replace macros and tables** with `let` constants and global tables.
6. **Run `prismio check file.psm`** after each function. It is the fast loop.
7. **Test differentially.** Feed the same inputs to the C and the Prismio versions and
   compare, using a tolerance for `Float`.

## 8. Worked example: `aacdec_usac.c`

The file is 2224 lines in FFmpeg's `libavcodec/aac/`. Its bitstream and spectral
functions port directly. Its frame entry point, `ff_aac_usac_decode_frame`, is
host glue, and it depends on `aacdec_tab.h`, `aacdec_lpd.h`, `aacdec_ac.h` and `mps212`.
Port those leaves first.

The Prismio below uses `import std.math` and `std.vec`. The whole file, with a `main`
that runs it, is [`docs/porting/decode_example.psm`](porting/decode_example.psm).

### 8.1 `get_bits` and `get_escaped_value` → a bit reader

C reads the stream through a `GetBitContext *gb` that it mutates. Prismio makes the
mutation explicit with `inout`.

```c
static inline uint32_t get_escaped_value(GetBitContext *gb, int nb1, int nb2, int nb3)
{
    uint32_t val = get_bits(gb, nb1), val2;
    if (val < ((1 << nb1) - 1))
        return val;

    val += val2 = get_bits(gb, nb2);
    if (nb3 && (val2 == ((1 << nb2) - 1)))
        val += get_bits(gb, nb3);

    return val;
}
```

```prismio
struct BitReader {
    data: Vec<U8>,
    pos: Int,
}

// C: get_bits(gb, n) -- reads n bits, MSB first
fn getBits(inout gb: BitReader, n: Int) -> U32 {
    let mut value: U32 = 0
    for _ in 0..<n {
        let byte = gb.data[gb.pos / 8]
        let shift = 7 - (gb.pos % 8)
        let bit = ((byte >> shift as U8) & 1) as U32
        value = (value << 1) | bit
        gb.pos = gb.pos + 1
    }
    return value
}

// C: get_escaped_value(gb, nb1, nb2, nb3)
fn getEscapedValue(inout gb: BitReader, nb1: Int, nb2: Int, nb3: Int) -> U32 {
    let mut value = getBits(gb, nb1)
    if value < ((1 << nb1) - 1) as U32 {
        return value
    }
    let value2 = getBits(gb, nb2)
    value = value + value2
    if nb3 != 0 and value2 == ((1 << nb2) - 1) as U32 {
        value = value + getBits(gb, nb3)
    }
    return value
}
```

Points to notice: `uint32_t` is `U32`, and `1 << nb1` is an `Int`, which is why
the comparison casts it. `gb->` becomes `gb.`, and the `inout` declares the mutation.

### 8.2 `noise_random_sign` and `apply_noise_fill` → state and flat indexing

The C walks `coef` with pointer arithmetic: `cb = coef + swb_offset[sfb]`, then
`cb += 128` per group, and `coef += g_len << 7` per window group. Prismio keeps the
flat `Vec` and computes the index.

```c
static inline float noise_random_sign(unsigned int *seed)
{
    unsigned int new_seed = *seed = ((*seed) * 69069) + 5;
    if (((new_seed) & 0x10000) > 0)
        return -1.f;
    return +1.f;
}

// inside apply_noise_fill
coef = sce->coeffs;
for (int g = 0; g < ics->num_window_groups; g++) {
    unsigned g_len = ics->group_len[g];
    for (int sfb = 0; sfb < ics->max_sfb; sfb++) {
        float *cb = coef + ics->swb_offset[sfb];
        int cb_len = ics->swb_offset[sfb + 1] - ics->swb_offset[sfb];
        int band_quantized_to_zero = 1;
        if (ics->swb_offset[sfb] < band_off)
            continue;
        for (int group = 0; group < (unsigned)g_len; group++, cb += 128) {
            for (int z = 0; z < cb_len; z++) {
                if (cb[z] == 0)
                    cb[z] = noise_random_sign(&sce->ue.noise.seed) * noise_val;
                else
                    band_quantized_to_zero = 0;
            }
        }
        ...
    }
    coef += g_len << 7;
}
```

```prismio
struct NoiseState {
    seed: U32,
}

// C: noise_random_sign(unsigned int *seed)
fn noiseRandomSign(inout st: NoiseState) -> Float {
    st.seed = st.seed * 69069 + 5
    if (st.seed & 0x10000) != 0 { return -1.0 }
    return 1.0
}

struct Sce {
    coeffs: Vec<Float>,
    sfo: Vec<Int>,
    noise: NoiseState,
}

// C: apply_noise_fill. `coef` advances by g_len * 128 per window group, and by
// 128 per group inside it, so the flat index is base + group * 128 + start + z.
fn applyNoiseFill(inout sce: Sce, swbOffset: Vec<Int>, groupLen: Vec<Int>,
                  maxSfb: Int, bandOff: Int, level: Float, noiseOffset: Int) {
    let mut base = 0
    for g in 0..<groupLen.length {
        let gLen = groupLen[g]
        for sfb in 0..<maxSfb {
            let start = swbOffset[sfb]
            if start < bandOff { continue }
            let len = swbOffset[sfb + 1] - start
            let mut quantisedToZero = true
            for group in 0..<gLen {
                for z in 0..<len {
                    let idx = base + group * 128 + start + z
                    if sce.coeffs[idx] == 0.0 {
                        sce.coeffs[idx] = noiseRandomSign(sce.noise) * level
                    } else {
                        quantisedToZero = false
                    }
                }
            }
            if quantisedToZero {
                let at = g * maxSfb + sfb
                sce.sfo[at] = max(sce.sfo[at] + noiseOffset, -200)
            }
        }
        base = base + gLen * 128
    }
}
```

Points to notice: the `unsigned *seed` becomes state in a struct passed `inout`. The
`continue` stays. `coef` is replaced by `base`, which follows the same stride. The
`FFMAX` becomes `max` from `std.math`. The C `noise_val` is passed in as `level`.

### 8.3 `decode_tsd` → widths and while loops

```c
static void decode_tsd(GetBitContext *gb, int *data, int nb_tr_slots, int nb_slots)
{
    int nb_bits = av_log2(nb_slots / (nb_tr_slots + 1));
    int s = get_bits(gb, nb_bits);
    for (int k = 0; k < nb_slots; k++)
        data[k]=0;

    int p = nb_tr_slots + 1;
    for (int k = nb_slots - 1; k >= 0; k--) {
        if (p > k) {
            for (; k >= 0; k--)
                data[k] = 1;
            break;
        }
        int64_t c = k - p + 1;
        for (int h = 2; h <= p && c <= s; h++) {
            c += c*(k-p)/h;
        }
        if (s >= c) {
            s -= c;
            data[k] = 1;
            p--;
            if (!p)
                break;
        }
    }
}
```

```prismio
fn log2Int(v: Int) -> Int {
    let mut n = 0
    let mut x = v
    while x > 1 {
        x = x / 2
        n += 1
    }
    return n
}

// C: decode_tsd -- int64_t arithmetic, nested loops, early break
fn decodeTsd(inout gb: BitReader, nbTrSlots: Int, nbSlots: Int) -> Vec<Int> {
    let mut data: Vec<Int> = []
    for _ in 0..<nbSlots { data.push(0) }
    let nbBits = log2Int(nbSlots / (nbTrSlots + 1))
    let mut s = getBits(gb, nbBits) as I64     // C: int; I64 keeps the comparisons below width-clean
    let mut p = nbTrSlots + 1
    let mut k = nbSlots - 1
    while k >= 0 {
        if p > k {
            while k >= 0 {
                data[k] = 1
                k -= 1
            }
            break
        }
        let mut c: I64 = (k - p + 1) as I64    // C: int64_t
        let mut h = 2
        while h <= p and c <= s {
            c = c + c * ((k - p) as I64) / (h as I64)
            h += 1
        }
        if s >= c {
            s = s - c
            data[k] = 1
            p -= 1
            if p == 0 { break }
        }
        k -= 1
    }
    return data
}
```

Points to notice: C's `for` with a counter that runs downward and early exits becomes a
`while`. The `int64_t` widths are explicit, with `as I64` on each operand. The C
`data[k] = 0` loop is a `push`, because a `Vec` is built from empty.

### 8.4 What stays in C

These parts do not translate as-is, and each needs a decision before porting:

- **`ff_aac_usac_decode_frame`** writes `frame->data[]`, reads `ac->oc[1]` and reports
  through `av_log`. Port the per-element decoding as functions over `inout` state that
  return `Result`. Keep the `AVFrame` writes in the C glue.
- **`if (!che)`** becomes an optional, and **`switch (e->type)`** with a fall-through
  from `ID_USAC_LFE` into `ID_USAC_SCE` becomes a `match` with the two arms written out.
- **`usac_ch_pos_to_av`** is a sparse designated-initialiser table of FFmpeg enum values.
  Prismio has no designated initialisers, so write all 64 entries as integers. Convert to
  FFmpeg values at the boundary.
- **`complex_stereo_get_filter`** returns a `const float *` into a table. Return the table
  index, or copy the fixed-size filter into an `Array<Float, N>` return value.
- **`avpriv_report_missing_feature`** and `AVERROR_PATCHWELCOME` become an error variant
  of `DecodeError`.

### 8.5 Running the example

The file [`docs/porting/decode_example.psm`](porting/decode_example.psm) compiles and runs.
Its `main` prints three values:

```bash
prismio run docs/porting/decode_example.psm
```

```text
10
-16
4
```

`10` is `getEscapedValue` on `1010`, `-16` is the noise fill with both bands quantised to
zero, and `4` is the length returned by `decodeTsd`. These follow from the C logic. They
were not compared with FFmpeg's own output.

## 9. Porting a context struct

A context struct such as `AACDecContext` (`libavcodec/aac/aacdec.h`, line 500) mixes
state, host pointers, function-pointer tables and buffers. Split it before you translate
it. Take the fields one at a time:

| C member kind | Prismio treatment |
|---|---|
| Host back-pointers (`avctx`, `frame`, `class`) | Delete. Pass the values the decoder needs as parameters or return them. |
| Function-pointer tables (`AACDecDSP dsp`, `AACDecProc proc`) | A `trait` with one method per pointer. The context does not hold it: a `dyn Trait` cannot be a struct field, so each decoder function takes `dsp: dyn AacDecDsp` as a parameter. |
| `INTFLOAT_UNION` / `USE_FIXED` / `is_fixed` | Keep the float branch only. Delete the fixed-point half. |
| Pointers that alias the same objects (`che[][]`, `tag_che_map[][]`, `output_element[]`) | One owner (a `Vec`), with the others as indices. |
| Nullable owned pointers (`ChannelElement *che[4][64]`) | `Vec<T?>`, with `none` for unallocated. |
| Anonymous `struct {…}` / `union {…}` members | A named `struct` for each. A union keeps only the arm that is used. |
| Bit-fields (`uint8_t level : 3; uint8_t offset : 5;`) | No bit-field syntax. Store one `U8` and write accessor methods that mask and shift, as `NoiseState` does in `aac/aacdec.psm`. |
| Explicit enum values (`ZERO_BT = 0`, `FIRST_PAIR_BT = 5`) | An `enum` with an `impl` method `code()` that returns the C value through a `match`. Add `fromCode(Int) -> E?` where the bitstream needs the reverse. |
| `const uint16_t *swb_offset` (a pointer into a static table) | An `Int` index into a global table. |
| Arrays of structs (`SingleChannelElement ch[2]`) | `Vec<T>`. `Array<T, N>` cannot hold structs. |
| Arrays of arrays (`int length[8][4]`) | One flat `Array<T, 8 * 4>`, indexed `i * 4 + j`. A struct field cannot be an array of arrays. |
| `default` for a struct with a large array field | Refused when an array is longer than 64. Write a literal that omits the field: an omitted field is zero-filled. |
| `INTFLOAT_ALIGNED_UNION(32, …)` | `Array<Float, N>`. `align(n)` is accepted only on functions. A struct carrying it was refused, so SIMD alignment is not expressible at field level. |
| `av_mallocz`, `av_refstruct_unref`, `free` | Delete. The `Vec` and struct own what they hold. |

Two size effects to plan for:

- **`Float` is 8 bytes, not 4.** C's `float` buffers double in size. One `SingleChannelElement`
  in the file above is about 70 KB of `Float` storage, so check the memory budget again.
- **Large structs are moved, not shared.** Pass them `inout`, and do not copy them with
  `let x = ctx.ch` in a loop.

[`docs/porting/aac_context.psm`](porting/aac_context.psm) is the reduced `AACDecContext`,
with the members the port keeps, and it passes `prismio check`. It runs `main`, which
allocates one channel element and reports the result.

## 10. Checklist before you call a file ported

- [ ] Every pointer is `inout`, a borrow, a returned value, or an index.
- [ ] Every width mismatch has an explicit `as`.
- [ ] Every trait you declared is implemented once in a stub `impl` as well. `prismio check` does not resolve a trait's method signatures until an `impl` uses them, so an unknown type in an unused trait passes silently.
- [ ] Every `float` is `Float`, and float output is checked against a tolerance.
- [ ] Every error code is a `Result` or `T?`, with each caller's `match` written out.
- [ ] Every `#define` and table is a `let` constant or global table of literals.
- [ ] `prismio check` passes, and the differential test matches the C output.
