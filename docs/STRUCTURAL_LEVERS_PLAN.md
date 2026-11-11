# Structural levers — what Prismio can do that C++ and Rust cannot

**Status:** audit, 2026-11-11. One lever built (float loop reductions, 0.3.0; developer docs: *Float loop reductions*);
the others ranked, each with what would settle it. Nothing here is built unless it says so.

## 0 · The test

A lever counts only if **C++'s or Rust's language definition forbids it**, not merely their
compilers. Most optimisation work is LLVM's, and C++, Rust and Prismio share it: scalar
simplification, control flow, scheduling, register allocation. On those, parity is the ceiling,
and the hosted suite is already at median parity. A large win over C++ and Rust needs a rule
they committed to and Prismio did not:

| What they committed to | Consequence | What Prismio is free to do |
|---|---|---|
| Sequential IEEE order for `+=` | a float accumulator cannot be vectorized without global fast-math | define a loop reduction as unordered |
| Layout is observable (`sizeof`, `&v[i]`, `offsetof`, transmute, FFI) | the compiler cannot change a type's representation | choose widths, packing and references per allocation |
| The container type *is* the implementation | `HashMap` is a hash table even when keys are 0..n | choose a representation from whole-program use |
| Open world (dylibs, separate crates, external callers) | a `dyn` call may reach an unknown implementor | devirtualize against every implementor the program has |
| Ahead-of-time only | no specialization on run-time values | compile hot kernels with LLVM in process (`run --jit`) |

## 1 · Ranked levers

| # | Lever | Prismio today | Evidence | Settles it |
|---|---|---|---|---|
| 1 | **Unordered float reductions** | **built** for 0.3.0: `reassoc` on a loop reduction's adds (`src/ir/reductions.psm`) | `float_sum` 0.20×, `float_dot` 0.33×, `numerical_integration` 0.51× of C++; `--strict-float` lands on C++ | done; the developer docs' *Float loop reductions* page holds the record |
| 2 | **Compiler-chosen element width** — store a `Vec<Int>` as `U8`/`U16` when every store into it is proved in range | users may write `Vec<U8>`; the compiler never narrows. `ir/contents.psm` already bounds a local array's elements from the stores it sees, and the runtime list already carries `elem_size` | **measured** (§1.1): kernels 0.22–0.59× with a 32-bit consumer, but 1.25× *slower* in cache with a 64-bit one; `convolution` 0.90×, `vector_dot` 0.87× | **closed (§1.1):** the compiler's own 62 `Vec<Int>` allocations have 1 narrowable (a flag array); benchmark hits are synthetic `i % K` inputs |
| 3 | **Compressed references inside compiler-placed arenas** — 32-bit offsets for nodes in an automatic arena | arenas are placed automatically (AIF); references are 64-bit pointers | ARCHITECTURE-DIRECTION §0: indirection measured free (0.86×), allocations are the cost, so expect memory wins more than speed | peak RSS and time on `tree_traversal`, `recursive_tree_rebuild`, `graph_churn` with hand-compressed nodes |
| 4 | **Container representation selection** — dense `Int`-keyed `HashMap` → direct table; small `HashSet<Int>` → bitset; `Vec<Bool>` → bits | `HashMap`/`HashSet` are one std implementation (`std/map.psm`); `Bool` elements are bytes | **counted** (§1.2): in the compiler, Int-keyed map functions take 1 of ~671 samples of a real compile; the dense-keyed ones are keyed by interned name ids | **closed (§1.2):** the only dense-key maps that matter are the hash-map benchmarks themselves, keyed `0..n` |
| 5 | **Closed-world devirtualization** — every `dyn Trait` call becomes a direct call or a switch over the program's implementors, then inlines | `dyn Trait` parameters exist (borrowed only, KNOWN_ISSUES); no devirtualization pass | none; no benchmark uses `dyn` | write the benchmark first (a shape list), then emit `!type` metadata and run LLVM's WholeProgramDevirt, which needs exactly the closed world Prismio has |
| 6 | **Profile-guided builds as a profile, not a procedure** | not started (PERFORMANCE_PLAN §3.1, "LLVM instrumentation PGO") | C++ and Rust have PGO but as manual multi-step tooling; `build.ums` can declare the workload | product lever rather than structural; PERFORMANCE_PLAN owns it |
| 7 | **Run-time specialization** — in-process LLVM compiles a hot kernel for constants only known at run time | `prismio run --jit` exists for whole programs | none | investigation only; it pays in interpreters and query kernels, and costs binary size |

### 1.1 · Lever 2, measured (2026-11-11)

The prize is the same values stored in a `Vec<Int>`, `Vec<U16>` and `Vec<U8>`, written in Prismio
and built with the installed 0.2.0 compiler. That is what a compiler that proved every store in
[0, 250] could choose. Apple Silicon, medians of 9–21 interleaved runs under load. An
identical-arguments control read 0.99–1.02× throughout.

| Kernel | Data as `Int` | U16 | U8 |
|---|---|---:|---:|
| scan, `Int` accumulator | 256 KB (in cache) | 0.59× | **0.35×** |
| | 4 MB | 0.52× | **0.32×** |
| | 64 MB (DRAM) | 0.46× | **0.22×** |
| scan, `I64` accumulator | 256 KB | **1.26×** | **1.25×** |
| | 4 MB | 1.22× | 1.21× |
| | 64 MB | 0.82× | 0.82× |
| random gather | 256 KB, 4 MB | 1.00× | 1.00× |
| | 64 MB | 0.74× | **0.44×** |
| `convolution` (suite, input U8, output U16) | 4.8 MB | — | **0.90×** |
| `vector_dot` (suite, both inputs U8) | 32 MB | — | **0.87×** |

Every arm printed the same checksum. What the numbers say:

- **It is a compute lever as much as a memory one.** Narrow elements fill four times the SIMD lanes,
  so a scan wins even in cache when its consumer is 32-bit (0.35×).
- **The consumer's width decides the sign.** Widening each byte to 64 bits costs more than the bytes
  save: 1.25× slower in cache. U8 and U16 cost the same there, so the cost is the widening, not the
  data. Narrowing needs a cost model, or a rule: narrow only where every read feeds an
  operation of 32 bits or less.
- **Gathers win only past the cache.** At 64 MB, a U8 table (16 MB) stays in the SoC's caches
  where the `Int` table (64 MB) cannot.
- **Real programs dilute it.** Both suite benchmarks spend most of their time in a serial
  `% 1000000007` chain, which narrowing does not touch. They are at parity with C++ today, so
  0.87–0.90× would put them about 10% ahead of idiomatic C++, whose `std::vector<int>` cannot
  change width.

What building it takes, and why it is hard:

1. **The proof:** every store into the allocation, in the whole program, is in range.
   `ir/contents.psm` has the per-function half. A `Vec` that reaches a `Slice`, a DataView,
   `std.raw`, FFI or `spawn` is vetoed.
2. **The representation already exists.** The runtime list carries `elem_size`
   (`runtime/lang_runtime.c`), and `Bool` elements are already bytes. Codegen widens at each read
   and narrows at each store.
3. **The hard part is functions.** Every function a narrowed `Vec<Int>` is passed to (`sort`,
   `contains`, a user helper) reads it as `Int`. Each needs a clone per representation, the way
   M4.4 specializes `List<T>` before flattening. Specializing on type alone is not enough, because
   two `Vec<Int>` values can now have different layouts.

**The count (2026-11-11) says stop.** A scan of every local `Vec<Int>`/`Array<Int, N>` allocation
classified each by its stored expressions: a literal, `x % K`, `x & K`, `x % K + c`, a cast of one
of those, or a copy from an already-narrow Vec. Each hit was then read by hand, because the regex
misses nested-index self-updates and `push` inside a one-line `if`.

| Population | Allocations | Narrowable on reading | What they hold |
|---|---:|---:|---|
| Compiler `src/` (the largest real Prismio program) | 62 | **1** | `fmt/layout.psm` `pipes`: a 0/1/2 flag per token, in the formatter. The rest are counters, offsets, indices and ids that grow with the input. |
| `std/`, `lsp/` | 19 | **0** | offsets and lengths |
| Hosted benchmarks | 57 | about 24 | almost all **synthetic inputs**, filled with `i % K` or `seed % K` because that is how a benchmark makes data |
| Tests | 234 | many | small literals in feature tests; not workloads |

The lever pays where a program's own data is small, and a real program's data comes from its input,
where no static proof reaches. In the one real program here it finds a single flag array. Building
it would mostly reward how benchmarks generate data. **Not designed; closed unless a workload with
proved-small data appears.** The cheaper, honest form is a hint: when a range proof bounds every store into a
`Vec<Int>`, suggest `Vec<U8>`/`Vec<U16>` and let the programmer choose. The measured gains above
are the evidence such a hint would quote. It is not structural, because C++ and Rust programmers
can choose a narrow type too.

### 1.2 · Lever 4, counted (2026-11-11)

The same population test as §1.1, on maps:

- **Compiler `src/`**, the program with the maps: 8 Int-keyed maps, 11 keyed by `Usize` (AST node
  addresses, sparse by nature) and 2 by `U64` (hashes). Six of the Int-keyed ones are keyed by
  `irNameId(...)`, and `irNameId` hands out ids sequentially from 0 (`src/symbols/names.psm`), so
  those keys are dense. A table indexed by id would replace them. That is a refactor a
  programmer can make, not one only a compiler can.
- **Do they cost anything?** The installed compiler building the hosted suite (1.07 s), sampled
  from process start at 1 ms: **4 of ~671 main-thread samples** are inside map or set functions,
  and **1** is in an Int-keyed one. The map that is hot is name interning, keyed by `String`, which
  no table replaces. LLVM's pipeline is about 75% of the run.
- **`std/`, `lsp/`:** generic `HashMap<K, V>` code, with no dense-key use of their own.
- **Hosted benchmarks:** all three `HashMap<Int, Int>`s (`hashmap_insert_lookup`,
  `key_value_update`, `mixed_map_removal`) use keys `0..n`. A compiler that chose a plain table
  there would beat C++ and Rust by an order of magnitude, by measuring something other than what
  those benchmarks exist to measure. It would be gaming the suite, not a gain.
- **`Vec<Bool>` as bits:** not structural, since C++ has `std::vector<bool>`. Bool elements are
  bytes on purpose (vectorization and `memset`; see the Bool-elements decision).

**Closed.** Real programs' dense-key maps are a refactor away and cost about 0.15% of a compile;
the benchmark ones would be gaming.

**Do not re-derive** — measured and closed:
- **Alias regions / per-allocation scopes**, measured 2026-11-11. Per-field scopes produced
  identical code (struct-path TBAA already separates fields). Per-Vec scopes removed runtime
  overlap checks but changed no loop's vectorization and no instruction count.
- **Allocator swaps, `-flto`, merging the whole runtime, fully automatic SoA search:**
  ARCHITECTURE-DIRECTION §7.
- **Forcing structs unsplit:** PERFORMANCE_PLAN §4.

## 2 · The ten categories, item by item

**Have** = built here. **LLVM** = done by the shared pipeline, the same in C++ and Rust.
**Gap** = missing and an ordinary lever, not a structural one. **Lever** = §1.

### 1 · Data representation and physical layout
- Field ordering and padding: **Have.** AIF layout sums widths in descending order before
  emission (`src/aif/layout.psm`, "LAYOUT 7.2").
- Enum discriminants and niches: **Have, partly.** Null-pointer optimisation for boxed recursive
  binary enums (MEM-031); scalar `T?` uses carrier ints. A general niche search is a **Gap**.
- Bit packing: **Lever 4** (`Vec<Bool>` as bits). Bool elements are bytes, on purpose: `store i1`
  blocked memset and vectorization.
- Integer-width minimization: **Lever 2**.
- Pointer compression: **Lever 3**.
- AoS vs SoA: **Have,** programmer-directed (`soa`, DataView; ARCHITECTURE-DIRECTION §4).
  Automatic search is a measured dead end.
- Hot/cold field splitting: **Have** (AIF layout split). A joint layout search is open
  (PERFORMANCE_PLAN §3.1).
- Cache-line and page placement, global data ordering: **Gap,** unmeasured.

### 2 · Memory access and allocation
- Escape analysis, stack vs heap, allocation elimination, arenas and regions, lifetime
  shortening: **Have** (AIF tiers, automatic arenas, non-lexical extents, inline list
  elements). This is where Prismio is already ahead of idiomatic Rust.
- Allocation reuse: **Gap,** dormant (no corpus trigger, ARCHITECTURE-DIRECTION §2).
- Bufferization / loop-scoped buffer reuse: **Gap,** not started (PERFORMANCE_PLAN §3.1).
- SROA, load/store forwarding, DSE, LICM, memcpy elimination: **LLVM.** Prismio feeds them facts
  (`separate_storage` memcpy, header/element alias scopes, `!invariant.load` on element size).
- Cache-aware allocation: allocator work is closed (§1).

### 3 · Stack frames and calling conventions
- Frame structs, slot reuse, spills, prologue/epilogue, frame-pointer elimination, tail calls:
  **LLVM.** Every function but `main` is internalized (`internalize_executable`, when no native
  sources, linked objects or `exportDynamic` can call in), so LLVM is free to change the calling
  convention of internal functions, as it would be for C++ or Rust under LTO.
- Self-recursion unfolding: **Have** (bridge policy).
- Hidden return pointer: used for arrays above a size threshold (`array_return_via_pointer`).
- No structural lever here: whole-program internalization gives Prismio by default what LTO
  gives C++ and Rust.

### 4 · Scalar and arithmetic
- Integer ranges and overflow facts: **Have** (`ranges.psm`, `relations.psm` DBM, `nowrap.psm`,
  `counters.psm`, `param_ranges.psm`).
- Modulo replacement: **Have** (`residues.psm`).
- Float contraction: **Have** (emission-time `fmuladd`, clang's rule).
- Float reassociation: **Lever 1.**
- Folding, CSE, strength reduction, extension elimination: **LLVM.**

### 5 · Control flow
- **LLVM,** plus the AArch64 branch-merging bias (`-aarch64-br-merging-cbz-tbnz-bias=8`) and cold
  functions. Basic-block placement from profiles waits on lever 6.

### 6 · Loops
- Bounds-check elimination by proof: **Have.** This is the lever over Rust, which keeps
  its checks.
- Flat guards, stride tiling, covered-fill elimination, hot-loop unroll, stencil guards: **Have.**
- Vectorization of float reductions: **Lever 1.**
- Loop fusion: **Gap,** not started (PERFORMANCE_PLAN §3.1).
- Interchange, prefetching: **LLVM**, or not done.

### 7 · Whole program
- Whole-program by default: internalize, dead-code pruning by symbol, monomorphized generics
  (specialization before flattening), interprocedural ranges: **Have.**
- Devirtualization: **Lever 5.**
- Inlining across a Map's calls: **Gap,** measured 2.6× in C (PERFORMANCE_PLAN §3.1).

### 8 · CPU and machine code
- **LLVM.** Default CPU is `apple-m1` on Apple arm64 and `x86-64` elsewhere
  (`default_target_cpu`). Host tuning (`-mcpu=native`) is opt-in by design (MEM-037).

### 9 · Binary and executable layout
- Dead stripping (`-dead_strip`, per-function sections with `--gc-sections`), cold functions,
  parallel codegen: **Have.**
- Function ordering, hot/cold code splitting by profile, identical code folding: **Gap,** waits
  on lever 6. Layout sensitivity is real here: a 64-byte shift once moved
  `bytecode_interpreter` 19% with identical code.

### 10 · Profile-guided and adaptive
- PGO: **Lever 6,** not started.
- JIT specialization: **Lever 7.**
- Workload-specific data layout: AIF keeps a layout profile separate from LLVM's (PERFORMANCE_PLAN
  §3.1).

## 3 · Order

1. Float reductions: built for 0.3.0.
2. Levers 2 (element width) and 4 (representation selection): counted and closed (§1.1, §1.2).
   In both, the hits were benchmark data, not real programs' data. Apply the same population
   test to any layout lever before building it.
3. Lever 5: write the benchmark first. No current program pays for dispatch.
4. Levers 3, 6 and 7: after those, or when a workload asks for them.
