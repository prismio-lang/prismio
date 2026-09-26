# Results: `__builtin_string_hash` (2026-09-12)

The item `RESULTS-string-followups.md` left in KNOWN_ISSUES under Codegen: a
short String key paid a runtime call on every map lookup, because `str_hash`
inlined makes `mapHashOf` too large for `mapProbe` to inline. Same machine and
toolchains as that file: an Apple M-series Mac, LLVM 22.1.8, `clang -O3`.

The baseline is HEAD (`0b23fb3`) packaged as a toolchain. Both arms of every
measurement below are built from the same directory outside the checkout, so
neither picks up the tree's `std/` in place of its own packaged stdlib.

The harnesses are in `string-hash-2026-09-12/`.

## What the change is

`keyHashBytes` was `str_hash(s, len)` and is now `__builtin_string_hash(s)`. For
a key of twelve bytes or fewer held in an inline pair, the backend mixes the two
words the pair already holds and calls nothing:

```
lo = field 0                       // bytes 0..7, zero past the length
hi = word 1 with the INLINE tag cleared   // bytes 8..11 above, the length below
p  = (lo ^ K1) * (hi ^ K2)         // 64x64 -> 128
h  = lo64(p) ^ hi64(p) ^ (hi >> 32)
       & 0x7FFFFFFF
```

Sixteen instructions and no call (`ir_str_hash`, runtime/llvm-api-backend.c).
Everything else — a key past twelve bytes, a view, a short string on the heap —
reaches `str_hash`, which now answers the twelve-byte case with the *same*
arithmetic on the same two words, assembled zero-padded from the bytes.

**That agreement is the whole correctness requirement, and it is not a
refactoring nicety.** A five-byte view and a five-byte inline string are the same
key; one is hashed in registers and the other in the runtime, and a map that
placed one and looks up the other finds nothing if the two numbers differ. It is
also why `str_hash`'s short path pads with zeros rather than using the
overlapping loads its long path uses: an inline pair is zero past its length
([string invariant 1](https://developers.prismio.org/compiler/string-representation#representation-invariants)), and only zeros reproduce it.

## Choosing the mix

Nine candidates in a C harness against the two key shapes that matter. Cost is
`cost.c` — the arms rotate inside one process and each keeps its own minimum of
25, because `shorthash.c`'s own cost columns run each arm to completion in turn
and drift by up to 2x between passes; they are not quoted here and the file says
so. Displacement is `shorthash.c`, on std.map's table: a power of two,
triangular probing, at most half full.

| | ns/key, 3-5 B | ns/key, 5-12 B | disp, 80k `sort_strings` | disp, 80k `id<N>` | mean disp, 20,000 random ten-word vocabularies |
| --- | ---: | ---: | ---: | ---: | ---: |
| `str_hash` (before) | 1.406 | 1.985 | 0.214 | 0.214 | 0.1820 |
| two rounds + the old finalizer | 0.629 | 0.584 | 0.209 | 0.209 | 0.1792 |
| one round + the old finalizer | 0.614 | 0.566 | 0.206 | 0.207 | 0.1810 |
| **mum, bytes 8..11 folded down (this)** | **0.597** | **0.548** | **0.211** | **0.173** | **0.1805** |

So the shipped mix is 0.42x and 0.28x of `str_hash` raw, and displaces no more
than it did on any of the three key sets — less on consecutive `id<N>` keys.

**The fold is load-bearing and was nearly left out.** Plain `mum` — the product's
two halves xored, and nothing else — is the fastest candidate measured and is
*wrong*: a mum whose operand is zero answers zero whatever the other operand
holds, and `lo` is the key's own first eight bytes against a constant. Over 4,096
twelve-byte keys sharing K1's eight bytes and differing only past them:

| | distinct answers |
| --- | ---: |
| `str_hash` (before) | 4,096 |
| mum | 1 |
| mum, `lo + hi` folded back | 1 |
| mum, `hi` folded back | 1 |
| **mum, `hi >> 32` folded back (this)** | **4,096** |

The two failing fold-backs are the trap worth recording: they *look* like they
fix it and do not, because the four bytes that distinguish those keys live above
bit 32 and `& 0x7FFFFFFF` keeps the low half. Only bringing them down works. The
second operand cannot be zeroed at all — `hi`'s low half is a length of at most
twelve and K2's is `0x6659FD93` — so one fold is the whole defence.

## What it buys

`maphash.psm` in `string-hash-2026-09-12/`, keys built before the clock starts:
`count` is 20,800 get-and-set pairs over ten 3-5 byte words, `word_frequency`'s
count phase in miniature and the row the call was costing; `distinct` inserts
80,000 `sort_strings`-shaped keys and looks all of them up. Microseconds, the
minimum of nine inside each run, seven runs alternating the two binaries,
checksums equal:

| | count min | median | distinct min | median |
| --- | ---: | ---: | ---: | ---: |
| before | 241 | 255 | 3258 | 3349 |
| after | 135 | 138 | 2223 | 2245 |
| ratio | 0.560 | 0.541 | 0.682 | 0.670 |

The FNV byte loop this whole line of work started from measured 176 µs on the
`count` shape in the previous results file's harness. The short-key regression
that entry recorded is gone, and the long-key win is larger than it was.

The benchmark suite, 15 runs alternating, checksums equal. `word_frequency` is
the one benchmark with a String-keyed map; the rest are controls:

| Benchmark | new/old min | new/old median |
| --- | ---: | ---: |
| `word_frequency` | 0.716 | 0.724 |
| `hashmap_insert_lookup` | 0.984 | 0.997 |
| `key_value_update` | 0.991 | 0.998 |
| `string_join` | 0.969 | 1.005 |
| `csv_parse` | 1.000 | 0.986 |
| `edit_distance` | 0.998 | 0.997 |
| `sort_strings` | 0.999 | 0.994 |

And against the other languages, each arm timed in the same 15 alternating
rounds, checksums equal:

| `word_frequency` | Prismio/C++ min | median | Prismio/Rust min | median |
| --- | ---: | ---: | ---: | ---: |
| before | 0.872 | 0.906 | 0.943 | 0.990 |
| after | 0.608 | 0.628 | 0.657 | 0.687 |

## The fixture, and that it is not vacuous

`test_147_string_hash_lowering` checks the number rather than a lookup, because
a map cannot show *why* it missed. Three parts: the two halves agree at every
length from 0 to 16 in both storage classes; 64 twelve-byte keys that zero the
register path's product still answer differently; and the map finds what it
stored.

Both failure modes were reproduced against a compiler built with the defect:

| Control | Result |
| --- | --- |
| the `hi >> 32` fold removed from **both** halves | FAIL: *bytes 8..11 do not reach the answer when the product is zero*. Part 1 passes and part 2's heap check passes -- the two halves stay in agreement, which is what a shared-definition bug looks like |
| the runtime's twelve-byte cutoff drifted to eleven | FAIL: *length 12: the pair and the runtime disagree* |

## Checks

| Check | Result |
| --- | --- |
| Fixpoint, `src/main.psm` IR | `2398b0710df23f16665cc38cd442123f` at gen1 and gen2, for step one and again for step two |
| IR of 192 programs (`tests/`, `aif/corpus/`, `benchmarks/prismio/`, `src/main.psm`) | 13 differ: exactly the 13 that build and carry `std.key` or `std.map`. The fourteenth importer is `neg_49_map_float_key`, which is not supposed to build. `src/main.psm` is not among them -- `src/` does not import `std.key` |
| `tools/run_suite.py` | 323/323 |
| `tools/aif_differential.py` | in-compiler engine and oracle agree on all 19 |
| `tools/check_source_lists.py` | agree |
| `tools/check_externs.py` | every `extern fn` has a definition (593 declared) |
| `test_146` and `test_147` under `--verify` | 7310/7310/0 and 263/263/0, 0 violations. `test_146`'s ledger is unchanged from the one the previous step recorded |

**The seed was not refreshed, and that is deliberate.** CLAUDE.md's two-step rule
exists because a builtin used in a `std/` module that `src/` imports is compiled
by whatever builds the compiler, the committed seed included. `src/` imports
`std.display`, `std.io`, `std.option` and `std.string` — not `std.key` — so a
seed-built compiler never sees `keyHashBytes`. The precedent is 40aa65b, which
added `__builtin_target_*` for `std.platform` and left the seed alone. Verified
rather than argued:

```
tools/bootstrap.sh --seed --out build/seed0     # the committed seed
tools/bootstrap.sh --compiler build/seed0 --out build/seed1
tools/bootstrap.sh --compiler build/seed1 --out build/seed2
```

`seed1` and `seed2` both build `src/main.psm` to `2398b071...`, the same IR the
working generations reach, and a toolchain packaged from `seed2` compiles and
runs `test_147`. Step one — the builtin taught to the compiler and used nowhere
— was still landed and validated separately, because that is the half that keeps
the seed able to parse the tree.

## Left open

`keyHashBytes`'s emitted body still carries one dead materialisation of the
argument as a `const char*` — the scratch alloca, three stores and a select that
`str_data_ptr` emits — because the argument is generated before `ir_str_hash`
reads the pair. It is dead code on a non-escaping alloca and LLVM removes it, and
the previous body carried two of them, so this is a reduction rather than a
regression. Whoever wants it gone should look at where `generateExpression`
coerces a String argument, not at the builtin.
