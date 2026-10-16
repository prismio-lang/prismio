# Research prompt: outperform C on every axis of freestanding code generation

A self-contained brief for a reasoning model that has no access to the Prismio source. Everything it
needs is in this file: the question, the rules, the compiler's design, the measurements, and in the
appendices every workload's source in all three languages, the shared harness, the machine code each
compiler produced, and Prismio's own IR for two workloads. Numbers were measured on 2026-10-16.

The answer will be implemented by an engineer who holds the source and will read it beside this file,
so it must be expressed in terms that survive that hand-off: LLVM IR, AArch64 assembly, pass and option
names, algorithms in pseudocode over the structures described here, and Prismio test programs.

The appendices, in order:
- **A, B, C**: every workload's source in Prismio, C and Rust.
- **D**: the machine code of every program function in each image: C, Prismio with partial unrolling
  off, Prismio as it ships (unrolling at factor 4), and Rust.
- **E**: Prismio's LLVM IR, as handed to the optimiser, for `edit_distance` and `mandelbrot_fixed`.
- **F**: the freestanding failure core, how a bounds check is emitted, the LLVM options and pipeline,
  the shared harness and the linker script.

---

## The question

**Prismio's compiler already makes bare-metal AArch64 programs execute fewer instructions than clang
-O3 on 17 of 20 workloads, and as many on the other 3. But its code is 3.7x larger than C's. Find the
compiler design that beats C on every axis at once, by the largest margin achievable:**

1. dynamic instructions executed,
2. static code size (`.text`, and `.rodata` + `.data` + `.bss`),
3. cycles on real cores, both in-order and out-of-order,
4. stack depth,
5. compile time.

For every workload, derive the lower bound on each axis that this program admits, and treat it as a
bound to approach, not a ceiling. Then design the mechanisms that get there. Where two axes conflict,
show the Pareto frontier and find the mechanisms that move the frontier outward rather than slide
along it. Question the problem itself, including the metric, the harness and the assumption that
speed and size trade against each other.

---

## Fixed: what may not change

**The programs.** Each workload is the same algorithm, statement by statement, in Prismio, C and Rust.
A checksum must agree across all three arms. The program text may not be tuned. Every gain must come
from the compiler, its runtime or its standard library. A transformation must be general and sound,
not special-cased to a benchmark: it must be justifiable on programs outside this suite.

**Prismio's semantics.**
- `Int` is a 32-bit signed integer that **wraps** on overflow. Narrow types exist: `U8`, `U16`, `U32`,
  `I8`, `I16`, `I64`, `U64`, `Usize`.
- **Every array or `Vec` index is bounds-checked** in safe code. An out-of-range index stops the program
  with a message through `prismio_panic_hook`, a weak symbol a kernel may override. A constant index out
  of range is a compile error. A check may be omitted **only where the compiler proves it redundant**.
- **No undefined behaviour in safe code.** Only `import std.raw` (unchecked pointers and casts) and the
  standard library's own internals may make promises the compiler cannot check. The standard library
  may use `__builtin_assume(cond)` (lowers to `llvm.assume`) where an invariant of its own private
  data holds.
- Fixed-size local arrays (`Array<T, N>`) are **zero-initialised** at declaration. C's are not.
- Structs are affine (moved, not copied implicitly); parameters are borrows. Ownership is analysed
  statically (AIF); the freestanding workloads allocate nothing.

**The machine and the measurement.**
- Target `aarch64-unknown-none-elf`, CPU `generic`, **no FP and no SIMD** (`-neon,-fp-armv8`;
  `-mgeneral-regs-only` for C), **strict alignment** (the MMU is off, every access is device memory, an
  unaligned access faults), static relocation, no C library, no allocator, no startup files.
- A shared C harness is compiled once with `-O2 -fno-builtin` and linked into every arm. It holds the
  boot code, timer, serial output, exit, and `memset`/`memcpy`, which move one 8-byte word per
  iteration when source and destination share alignment, and otherwise a byte at a time. Its `.text` is
  9.6 KB in every arm.
- Linking: one linker script, `--gc-sections`, `-nostdlib -static`, lld.
- QEMU `virt`, `-cpu cortex-a57`, `-icount shift=0`: the virtual clock advances 1 ns per guest
  instruction, and the generic timer counts it at 62.5 MHz. One tick is exactly 16 instructions, read
  around each workload. The count is deterministic and identical on every machine, with no cache,
  pipeline or branch-predictor model.
- **Verdicts are absolute**: fewer instructions than the other arm is a win, more is a loss, an equal
  count is level.
- Code size is the `.text` of the linked image, harness included, plus a per-function breakdown from
  the symbol table.

**The other arms.** C: clang (LLVM 23) `-O3 -ffunction-sections -ffreestanding` (which implies
`-fno-builtin`, so C never turns a loop into a `memcpy` call). C's signed overflow is undefined, so
LLVM may assume it away; C does not check indices. Rust: rustc 1.97 `opt-level=3`, fat LTO, one codegen
unit, `panic=abort`; Rust checks indices.

---

## Free: what may change

Anything in the Prismio compiler, its runtime and its standard library, within the semantics above:
- **The frontend's own analyses on the AST, before IR**, as described below. Add, replace or extend any
  of them.
- **The IR it emits** through the LLVM C API, including metadata, attributes, `llvm.assume`,
  `nsw`/`nuw`, `noalias`, loop metadata (`llvm.loop.unroll.*`, `llvm.loop.vectorize.*`), function
  attributes (`cold`, `alwaysinline`, `noinline`, `minsize`, `optsize`), and the choice of loop shapes.
- **The pass pipeline.** Today it is LLVM's `default<O3>`, split in two halves: module simplification,
  including the inliner, on the whole program, then module optimisation per codegen partition. It may be
  replaced, extended with LLVM passes not in the default pipeline (for example the MachineOutliner,
  function merging, loop rerolling, loop fusion, loop distribution), configured through `cl::opt`s, or
  extended with new passes through a C++ bridge into LLVM.
- **Profile data.** The compiler can measure a "workload" profile of a program and feed it back; the
  suite's `workload` test shows a profile changing the layout. Profile-guided decisions are allowed if
  the profile is gathered the way a user would gather it, not tuned to the scoring run.
- **Whole-program facts.** An executable is compiled whole and every function but `main` and `export`s
  is internalised.
- **The runtime's own code** that ends up in an image: the bounds-failure path, the panic hook's weak
  defaults.
- **The standard library's implementation**, behind the same API.

Not free: the harness, the flags of the C and Rust arms, the workload sources, the target CPU and
features, the metric's definition (but say so if the metric is wrong).

---

## Prismio, the language, as far as the workloads use it

```prismio
export fn bench_x(scale: U32) -> U32 { ... }   // C ABI symbol `bench_x`; the image also keeps `bench_x__U32`
let a: Array<U32, 600>                           // fixed array in the frame, zero-filled
let t: Array<U32, 8> = [3, 1, 2, 0, 1, 1, 0, 2]  // literal-initialised
let mut i = 0                                    // Int (i32), wraps on overflow
let x: U32 = 7                                   // unsigned 32-bit, wraps
while (i < 600) { a[i] = (s >> 12) & 3; i = i + 1 }
for i in 0..<64 { ... }                          // half-open; `0..64` includes 64; may count down
for _ in 0..<n { ... }
if (c) { ... } else if (d) { ... } else { ... }
y = x as Int                                     // integer conversion: truncates, extends or reinterprets
a[i]                                             // bounds-checked unless proved: index i32, compared unsigned
fn min(a: Int, b: Int) -> Int { if (a < b) { return a } return b }
```

`&`, `|`, `^`, `<<`, `>>` (logical on unsigned, arithmetic on signed), `%` and `/` (signed or unsigned by
type). Atomics and volatile accesses in the hardware workloads are std.raw functions that lower to
LLVM atomic and volatile loads and stores. A freestanding program cannot import most of std, including
std.math, so the workloads define their own `min`/`max`.

## The Prismio compiler today

Self-hosted, written in Prismio; emits LLVM 23 IR through the C API; whole-program.

Its analyses run on the AST before IR is generated:
- **Range prover** (`ranges`): versions loops. It emits a fast copy whose accesses are proved in range
  under a run-time guard tested once on entry, beside a checked fallback copy. It has a difference-bound
  (DBM) relational tier and recognises guard-safe calls.
- **Interval walk** (`nowrap`): a flow-sensitive interval analysis over integer types up to 32 bits,
  with each type's wrap rule. It does three things:
  - marks `+`/`-` as `nsw` where the exact result fits `Int`;
  - proves array indices in range, and emits no check for them;
  - narrows its facts by comparisons on both branches.

  Its loop handling: it infers loop invariants by probing the body without side effects, widening with
  thresholds (Blanchet et al.), up to 10 rounds and a budget of 400 probes per function. A `for i in
  a..<b` bounds `i`. It recognises a hand-written `min`/`max` by its body.
- **Counted loops**: a counter bounded by the loop's condition and stepped by a literal as the body's
  last statement; it counts iterations.
- **Array contents**: a local array touched only by subscripts keeps a bound on its elements. Each
  stored value is described as a form relative to the family's bound, growth is bounded by counted
  executions, and read aliases through an immutable `let` count.
- **Remainders**: `x % m` by a literal becomes a conditional add or subtract when the facts bound the
  dividend.
- **Flat-list guard**: one `i1` per loop proves every `Vec` in it has the flat representation.

Where a change can go, from the front to the back:

- **Frontend analyses** are written in Prismio and walk the typed AST: statements and expressions
  linked as nodes with children and a `next` chain, each typed by sema. They communicate with codegen
  by marking nodes in per-pass tables. A mark means "this `+` is `nsw`", "this index is in range" or
  "this loop copy is proved". New analyses and new marks are cheap.
- **IR generation** is a recursive walk that emits through a C backend wrapping the LLVM C API: one call
  per instruction, plus helpers for checks, loop versioning and memcpy. It chooses loop shapes,
  attributes, metadata and assumes.
- **The backend** is C and C++ over LLVM 23. It runs the pass pipeline from a pipeline string, sets
  `cl::opt`s once per process, and can run any LLVM pass, or a new one written in C++, at any point.
- **The runtime** is C. The freestanding failure core (`runtime/freestanding/panic.c`, Appendix F) is
  linked into every freestanding image.

Its codegen choices:
- **Bounds failure** is a compare and a branch to a cold `noreturn` call that takes `(index, length)`
  and prints them. Each check site has its own call with its own arguments.
- **Whole-buffer copy loops** are emitted as a `memcpy` call. In the freestanding image that is the
  harness's word loop.
- **Freestanding partial unrolling.** For a freestanding target the backend sets `-unroll-allow-partial
  -unroll-max-count=4`. LLVM's AArch64 cost model otherwise unrolls partially only for CPUs whose
  scheduling model declares a loop buffer, and `generic` declares none, so clang and rustc unroll
  nothing partially here.
- **Branch merging**: `-aarch64-br-merging-cbz-tbnz-bias=8`, so a single bit test stays its own branch.
- **`cold fn` and `inline fn`** are source modifiers.

---

## The data

Instructions executed (scale 1), and code bytes of each workload's function from the symbol table.
Prismio is shown with partial unrolling at factor 4 (the current setting) and with it off.

| workload | Prismio instr | C instr | Rust instr | Prismio bytes (unroll 4) | Prismio bytes (no unroll) | C bytes | Rust bytes |
|---|---:|---:|---:|---:|---:|---:|---:|
| fibonacci | 4,963,584 | 5,281,408 | 4,963,584 | 32 | 32 | 44 | 32 |
| prime_sieve | 5,285,664 | 5,498,528 | 5,628,096 | 936 | 412 | 416 | 416 |
| gcd_lcm | 4,702,688 | 5,063,584 | 5,063,600 | 624 | 96 | 104 | 96 |
| binary_search | 11,036,304 | 11,036,896 | 13,443,536 | 368 | 292 | 260 | 328 |
| quicksort | 9,694,336 | 10,096,384 | 12,959,632 | 316 | 224 | 216 | 236 |
| heapsort | 10,459,760 | 10,702,272 | 14,553,472 | 1352 | 492 | 424 | 636 |
| knapsack | 3,138,688 | 5,122,624 | 7,395,584 | 1360 | 576 | 372 | 428 |
| edit_distance | 4,207,920 | 5,596,832 | 10,102,960 | 1332 | 460 | 412 | 500 |
| matrix_multiply | 6,873,184 | 9,957,632 | 9,994,768 | 2784 | 732 | 388 | 468 |
| crc32 | 5,885,744 | 8,586,144 | 8,622,416 | 664 | 372 | 244 | 304 |
| sha256 | 6,006,112 | 9,546,064 | 8,778,112 | 964 | 600 | 604 | 608 |
| popcount | 9,600,016 | 9,600,016 | 9,600,016 | 124 | 124 | 120 | 124 |
| mandelbrot_fixed | 7,605,904 | 8,989,616 | 8,989,600 | 5952 | 784 | 172 | 172 |
| bytecode_interpreter | 9,650,048 | 9,850,032 | 9,900,032 | 412 | 412 | 272 | 428 |
| pointer_chase | 9,629,904 | 9,632,288 | 16,848,592 | 600 | 312 | 256 | 312 |
| ring_buffer | 3,753,472 | 4,429,312 | 3,753,472 | 204 | 204 | 188 | 208 |
| mem_copy | 8,882,416 | 9,475,232 | 9,475,232 | 1076 | 360 | 360 | 240 |
| atomic_counter | 4,500,016 | 4,500,016 | 4,500,016 | 136 | 136 | 80 | 80 |
| spinlock | 8,800,016 | 8,800,016 | 8,800,016 | 112 | 112 | 112 | 112 |
| volatile_registers | 9,000,256 | 9,000,416 | 9,900,352 | 408 | 388 | 388 | 388 |

**Whole images:**

| | `.text` | code net of harness | `.rodata` | `.data` | `.bss` |
|---|---:|---:|---:|---:|---:|
| Prismio, unroll 4 | 30,608 B | 21,056 B | 1,821 B | 8 B | 176 B |
| C | 15,264 B | 5,712 B | 1,408 B | 0 B | 16 B |
| Rust | 16,036 B | 6,484 B | 2,500 B | 0 B | 16 B |

**Geomean of instructions:** Prismio 0.876x C and 0.789x Rust.

**Unrolling's frontier**, as instruction geomean (relative to no unrolling) against `.text`:

| setting | instructions | `.text` |
|---|---:|---:|
| none | 1.000 | 17.4 KB |
| factor 2 | 0.942 | 21.4 KB |
| factor 4, `-unroll-partial-threshold=60` | 0.928 | 20.0 KB |
| factor 4 (current) | 0.914 | 29.9 KB |
| runtime unrolling, factor 4 | 0.853 | 31.7 KB |

Runtime unrolling made `fibonacci` 31% worse: tail-recursion elimination turns one recursive call into
a loop of a few trips, and every one of its 300,000 entries paid the trip-count prologue.

**Workloads** (each sized to 5-12M instructions at scale 1):
- fibonacci: recursive Fibonacci(27), call and return overhead with no loop.
- prime_sieve: Sieve of Eratosthenes over a 200,000-byte frame array.
- gcd_lcm: Euclid over every pair up to 400, a data-dependent loop of divisions.
- binary_search: 100,000 lookups in a sorted 4,096-entry `U32` table.
- quicksort: recursive Hoare quicksort of 2,048 words, four times.
- heapsort: heapsort of 2,048 words, four times.
- knapsack: 0/1 knapsack, 64 items, capacity 1,500, a branch-free DP update.
- edit_distance: Levenshtein distance of two 600-byte strings, two rolling `Int` rows of 601, the row
  copied with a loop after each row.
- matrix_multiply: 64x64 `U32` matrix multiply.
- crc32: table-driven CRC-32 over 32 KiB, four times.
- sha256: compression of 24 blocks.
- popcount: clear-lowest-bit loop.
- mandelbrot_fixed: 96x96 grid in Q16.16 fixed point, data-dependent escape loop.
- bytecode_interpreter: a four-register machine running an 8-instruction literal program, 400,000
  dispatches.
- pointer_chase: a shuffled 2,048-entry `U32` cycle, 400,000 dependent loads.
- ring_buffer: a 1,024-slot ring with a pseudo-random producer and consumer.
- mem_copy: word-at-a-time copy of 32 KiB between two RAM regions addressed by number.
- atomic_counter: 500,000 sequentially consistent fetch-adds.
- spinlock: 200,000 acquire/increment/release on a CAS lock.
- volatile_registers: 300,000 read-modify-write cycles on a 64-register volatile file.

---

## What is already known

- **edit_distance**:
  - The unrolled row loop is 41 instructions per 4 cells (10.25 a cell). By hand, the work is about 9
    a cell: `ldrb`, `ldr`, `cmp`/`cinc` for the cost, `cmp`/`csel` for the min, `cmp`/`csinc` for the
    min-plus-one, and `str`.
  - The row copy `prev = cur` is a 2,404-byte `memcpy` into the harness's word loop: about 850
    instructions a row, 12% of the total.
  - Array rotation (Ng et al., PACT 2003), which swaps the two rows' roles instead of copying, is legal
    here: nothing reads `cur` before writing it in the next row. It is not built. LLVM's `loop-fusion`
    pass does not fuse the two loops.
- **mandelbrot_fixed**: even rolled, its code is 4.6x C's (784 B against 172 B); unrolled it is 5,952 B.
  Not yet diagnosed.
- **knapsack, heapsort and matrix_multiply** are larger than C even rolled. Suspected causes: the range
  prover's two loop copies, per-site failure calls, and zero-filling.
- **bytecode_interpreter** keeps one check, `reg[a]`. `a` is read from the literal program at position
  `pc*4 + 1`; proving it needs a congruence fact (stride 4) that the interval domain lacks.
- **heapsort**: `root * 2 + 1` in the sift loop's condition needs `nsw` to become C's code. A recipe was
  measured: a guard on `sift`'s parameters, plus `root >= 0` carried through `root = pick`, gives
  10,555,648 instructions without unrolling. It needs `mul nsw` too.
- **The image carries Prismio's whole freestanding failure core** (Appendix F, and the tail of Appendix
  D.2): `prismio_panic`, `prismio_unreachable`, `prismio_assert_failed`, `prismio_overflow_trap`,
  `prismio_step_check`, `prismio_expect`, `array_index_fail`, `list_index_fail`, the `data_view_*`
  failures, allocator stubs and a 300-byte `exit`, some of them twice. Most are unreachable from these
  workloads, yet they survive `--gc-sections`. They are part of the 21 KB against C's 5.7 KB.
- **Every check site has its own call** with two argument moves. Rust's community measured that a
  failure call taking the index ties each check to its iteration and blocks hoisting, and that
  `llvm.trap` unblocked it.
- **Already in place**: invariant-based checks deleted through `llvm.assume` (std's Map: 0.78x of the
  build before checks existed).
- **Rejected after measurement**:
  - marking the failure call `memory(inaccessiblemem)` to help LICM: no effect;
  - runtime unrolling, because of `fibonacci`;
  - `-unroll-threshold` variants: no effect on partial unrolling;
  - LLVM `loop-fusion` on `edit_distance`: no effect.
- **The metric's blind spots**: the count models no cache, no pipeline and no branch predictor. It
  rewards unrolling more than a superscalar core would, and ignores instruction-cache pressure, which
  is what code size costs on a small core.

---

## What to produce

Write for the engineer who will implement it with this file beside the source. For every mechanism,
give:
- **Where it runs**: frontend analysis, IR generation, an LLVM pass (existing, with its exact options,
  or new, with its algorithm), or the runtime.
- **The algorithm**, in pseudocode over the structures named above: a typed AST, per-node marks, LLVM
  IR.
- **The before-and-after code** for at least one workload, as AArch64 assembly or LLVM IR, taken from
  the appendices.
- **The soundness argument**, if it removes a check, adds `nsw`/`nuw`/`assume`, or changes memory
  behaviour.
- **A Prismio test program**: one the mechanism must transform, and one it must leave alone (a shape that
  looks the same but is unsafe), with the expected effect.
- **The predicted change**, per workload, in instructions and bytes.

The deliverables:

1. **Bounds, per workload and per axis.**
   - Instructions: the fewest a correct compiler for these semantics could emit, at three levels:
     - with transformations known in the literature;
     - with superoptimisation of the hot loops;
     - an information-theoretic or dependence-height argument, where one applies.
   - Static bytes: the same three levels.
   - Say what C's undefined overflow and missing checks buy it at each level, and show how Prismio
     recovers or exceeds that without giving up its guarantees.
2. **The frontier.** For each workload and for the suite, the Pareto frontier of instructions against
   bytes that today's mechanisms reach. Then the mechanisms that push it outward: smaller *and* faster
   together, not traded. Candidates to evaluate, not a list to accept:
   - profile- or heat-guided unrolling, with size-optimised cold code;
   - machine outlining and function merging;
   - loop rerolling;
   - shared trap blocks, or `llvm.trap` with the index recovered from debug info;
   - dropping the checked loop copy where proofs cover every access;
   - eliding zero-fill when every element is written before it is read;
   - count-down loops and post-indexed addressing in place of unrolling;
   - array rotation and contraction;
   - congruence and relational abstract domains (octagons, pentagons);
   - equality saturation (e-graphs) for local code;
   - superoptimisation of hot loop bodies;
   - layout and alignment;
   - anything better.
3. **Real silicon.** Predict cycles on an in-order core (Cortex-A53/A55) and an out-of-order one
   (Cortex-A76 or Apple M-class), and on a microcontroller-class core, using whatever models are
   credible. Say where minimising instructions and minimising cycles diverge. Propose the measurement
   that should replace or accompany the instruction count, and how to make it deterministic.
4. **A design.** The analyses, passes, heuristics and pipeline order, with:
   - a soundness argument for every transformation that deletes a check or adds an assumption;
   - the expected gain on each axis per workload;
   - compile-time cost.
5. **A ranked plan.** Steps in the order to build them, each with its predicted effect on instructions,
   `.text` and cycles. Mark which are known techniques and which are new. Name the experiment that would
   falsify each prediction.
6. **What to stop doing.** Any part of the current design that the analysis shows is costing more than
   it buys.

Constraints on the answer:
- Every claim of a gain must say what it is measured in.
- No transformation may be specific to one benchmark.
- Every check deleted must be argued sound.
- Where the best answer requires changing the measurement, a language rule or the fairness rules, say
  so explicitly and separately. Do not assume it.

---

# Appendices

Everything below is generated from the measured build, unedited except that disassembly shows offsets within each function instead of addresses.

## Appendix A: the workloads in Prismio

### prismio/suite.psm
```prismio
// The Prismio arm of the freestanding suite: every workload is an `export fn`
// named `bench_<name>`, which is the symbol the shared harness (../harness)
// calls. `main` exists because every program has one; nothing runs it.

import algorithms
import compute
import memory
import hardware

fn main() -> Int {
    return 0
}
```

### prismio/algorithms.psm
```prismio
// Algorithms over fixed arrays in the frame: no allocation, no library. The same
// programs, statement for statement, as ../c/algorithms.c and ../rust/algorithms.rs.

// `a > b ? a : b`, as the C and Rust arms spell it. A freestanding program has no
// std.math, and LLVM turns these into the same smax and smin.
fn max(a: Int, b: Int) -> Int {
    if (a > b) { return a }
    return b
}

fn min(a: Int, b: Int) -> Int {
    if (a < b) { return a }
    return b
}

fn fib(n: U32) -> U32 {
    if (n < 2) { return n }
    return fib(n - 1) + fib(n - 2)
}

export fn bench_fibonacci(scale: U32) -> U32 {
    let mut total: U32 = 0
    let mut r: U32 = 0
    while (r < scale) {
        total = total + fib(27)
        r = r + 1
    }
    return total
}

export fn bench_prime_sieve(scale: U32) -> U32 {
    let mut total: U32 = 0
    let mut r: U32 = 0
    while (r < scale) {
        let mut flags: Array<U8, 200000>
        let mut count: U32 = 0
        let mut i = 2
        while (i < 200000) {
            if (flags[i] == 0) {
                count = count + 1
                let mut j = i + i
                while (j < 200000) {
                    flags[j] = 1
                    j = j + i
                }
            }
            i = i + 1
        }
        total = total + count
        r = r + 1
    }
    return total
}

fn gcd(a0: U32, b0: U32) -> U32 {
    let mut a = a0
    let mut b = b0
    while (b != 0) {
        let t = a % b
        a = b
        b = t
    }
    return a
}

export fn bench_gcd_lcm(scale: U32) -> U32 {
    let mut total: U32 = 0
    let mut r: U32 = 0
    while (r < scale) {
        let mut a: U32 = 1
        while (a <= 400) {
            let mut b: U32 = 1
            while (b <= 400) {
                total = total + gcd(a, b)
                b = b + 1
            }
            a = a + 1
        }
        r = r + 1
    }
    return total
}

export fn bench_binary_search(scale: U32) -> U32 {
    let mut table: Array<U32, 4096>
    let mut i = 0
    while (i < 4096) {
        table[i] = (i as U32) * 7 + 3
        i = i + 1
    }
    let mut s: U32 = 12345
    let mut found: U32 = 0
    let mut acc: U32 = 0
    let mut q: U32 = 0
    while (q < 100000 * scale) {
        s = s * 1664525 + 1013904223
        let key = s % 30000
        let mut lo: U32 = 0
        let mut hi: U32 = 4096
        while (lo < hi) {
            let mid = (lo + hi) >> 1
            if (table[mid as Int] < key) {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        if (lo < 4096 and table[lo as Int] == key) {
            found = found + 1
            acc = acc + lo
        }
        q = q + 1
    }
    return found + acc * 3
}

fn quick(inout a: [U32], lo: Int, hi: Int) {
    if (lo >= hi) { return }
    let p = a[(lo + hi) >> 1]
    let mut i = lo
    let mut j = hi
    while (i <= j) {
        while (a[i] < p) { i = i + 1 }
        while (a[j] > p) { j = j - 1 }
        if (i <= j) {
            let t = a[i]
            a[i] = a[j]
            a[j] = t
            i = i + 1
            j = j - 1
        }
    }
    quick(a, lo, j)
    quick(a, i, hi)
}

export fn bench_quicksort(scale: U32) -> U32 {
    let mut data: Array<U32, 2048>
    let mut s: U32 = 777
    let mut sum: U32 = 0
    let mut r: U32 = 0
    while (r < 40 * scale) {
        let mut i = 0
        while (i < 2048) {
            s = s * 1664525 + 1013904223
            data[i] = s >> 4
            i = i + 1
        }
        quick(data, 0, 2047)
        i = 0
        while (i < 2048) {
            sum = sum + data[i] * ((i as U32) + 1)
            i = i + 1
        }
        r = r + 1
    }
    return sum
}

fn sift(inout a: [U32], start: Int, end: Int) {
    let mut root = start
    while (root * 2 + 1 <= end) {
        let child = root * 2 + 1
        let mut pick = root
        if (a[pick] < a[child]) { pick = child }
        if (child + 1 <= end and a[pick] < a[child + 1]) { pick = child + 1 }
        if (pick == root) { return }
        let t = a[root]
        a[root] = a[pick]
        a[pick] = t
        root = pick
    }
}

export fn bench_heapsort(scale: U32) -> U32 {
    let mut data: Array<U32, 2048>
    let mut s: U32 = 4242
    let mut sum: U32 = 0
    let mut r: U32 = 0
    while (r < 24 * scale) {
        let mut i = 0
        while (i < 2048) {
            s = s * 1664525 + 1013904223
            data[i] = s >> 4
            i = i + 1
        }
        let mut start = (2048 - 2) / 2
        while (start >= 0) {
            sift(data, start, 2047)
            start = start - 1
        }
        let mut end = 2047
        while (end > 0) {
            let t = data[0]
            data[0] = data[end]
            data[end] = t
            sift(data, 0, end - 1)
            end = end - 1
        }
        i = 0
        while (i < 2048) {
            sum = sum + data[i] * ((i as U32) + 1)
            i = i + 1
        }
        r = r + 1
    }
    return sum
}

export fn bench_knapsack(scale: U32) -> U32 {
    let mut weight: Array<Int, 64>
    let mut value: Array<Int, 64>
    let mut s: U32 = 99
    let mut i = 0
    while (i < 64) {
        s = s * 1664525 + 1013904223
        weight[i] = (((s >> 8) % 37) as Int) + 3
        s = s * 1664525 + 1013904223
        value[i] = (((s >> 8) % 97) as Int) + 1
        i = i + 1
    }
    let mut total: U32 = 0
    let mut r: U32 = 0
    while (r < 6 * scale) {
        let mut best: Array<Int, 1501>
        i = 0
        while (i < 64) {
            let w = weight[i]
            let v = value[i]
            let mut c = 1500
            while (c >= w) {
                best[c] = max(best[c], best[c - w] + v)
                c = c - 1
            }
            i = i + 1
        }
        total = total + (best[1500] as U32)
        r = r + 1
    }
    return total
}

export fn bench_edit_distance(scale: U32) -> U32 {
    let mut a: Array<U8, 600>
    let mut b: Array<U8, 600>
    let mut s: U32 = 31337
    let mut i = 0
    while (i < 600) {
        s = s * 1664525 + 1013904223
        a[i] = ((s >> 12) & 3) as U8
        i = i + 1
    }
    i = 0
    while (i < 600) {
        s = s * 1664525 + 1013904223
        b[i] = ((s >> 12) & 3) as U8
        i = i + 1
    }
    let mut total: U32 = 0
    let mut r: U32 = 0
    while (r < scale) {
        let mut prev: Array<Int, 601>
        let mut cur: Array<Int, 601>
        let mut j = 0
        while (j <= 600) {
            prev[j] = j
            j = j + 1
        }
        i = 1
        while (i <= 600) {
            cur[0] = i
            j = 1
            while (j <= 600) {
                let mut cost = 1
                if (a[i - 1] == b[j - 1]) { cost = 0 }
                cur[j] = min(min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost)
                j = j + 1
            }
            j = 0
            while (j <= 600) {
                prev[j] = cur[j]
                j = j + 1
            }
            i = i + 1
        }
        total = total + (prev[600] as U32)
        r = r + 1
    }
    return total
}

let MATRIX: Usize = 64

export fn bench_matrix_multiply(scale: U32) -> U32 {
    let mut a: Array<U32, MATRIX * MATRIX>
    let mut b: Array<U32, MATRIX * MATRIX>
    let mut c: Array<U32, MATRIX * MATRIX>

    for i in 0..<MATRIX {
        for j in 0..<MATRIX {
            a[i * MATRIX + j] = ((i * 3 + j * 5) % 17) as U32
            b[i * MATRIX + j] = ((i * 7 + j * 2) % 13) as U32
        }
    }
    let mut total: U32 = 0

    for r in 0..<8 * scale as Int {
        for i in 0..<MATRIX {
            for j in 0..<MATRIX {
                let mut sum: U32 = 0
                for k in 0..<MATRIX {
                    sum = sum + a[i * MATRIX + k] * b[k * MATRIX + j]
                }
                c[i * MATRIX + j] = sum
            }
        }
        for i in 0..<MATRIX * MATRIX {
            total = total + c[i]
        }
        a[r % 64] = a[r % 64] + 1
    }
    return total
}
```

### prismio/compute.psm
```prismio
// Integer compute: checksums, hashing, bit work, fixed-point arithmetic and a
// dispatch loop. No floating point, because the target keeps its FP unit off.
// The same programs as ../c/compute.c and ../rust/compute.rs.

export fn bench_crc32(scale: U32) -> U32 {
    let mut table: Array<U32, 256>

    for i in 0..<256 {
        let mut c = i as U32

        for _ in 0..<8 {
            if ((c & 1) != 0) {
                c = 0xEDB88320 ^ (c >> 1)
            } else {
                c = c >> 1
            }
        }
        table[i] = c
    }

    let mut buffer: Array<U8, 32768>
    let mut s: U32 = 2024

    for i in 0..<32768  {
        s = s * 1664525 + 1013904223
        buffer[i] = (s >> 24) as U8
    }

    let mut crc: U32 = 0xFFFFFFFF

    for _ in 0..<32 * scale as Int {
        for i in 0..<32768 {
            crc = table[((crc ^ (buffer[i] as U32)) & 255) as Int] ^ (crc >> 8)
        }
    }
    return crc ^ 0xFFFFFFFF
}

fn rotr(x: U32, n: U32) -> U32 {
    return (x >> n) | (x << (32 - n))
}

export fn bench_sha256(scale: U32) -> U32 {
    let k: Array<U32, 64> = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]
    let mut h: Array<U32, 8> = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
    let mut w: Array<U32, 64>
    let mut s: U32 = 808
    let mut block: U32 = 0
    while (block < 3000 * scale) {
        let mut t = 0
        while (t < 16) {
            s = s * 1664525 + 1013904223
            w[t] = s
            t = t + 1
        }
        t = 16
        while (t < 64) {
            let s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3)
            let s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10)
            w[t] = w[t - 16] + s0 + w[t - 7] + s1
            t = t + 1
        }
        let mut a = h[0]
        let mut b = h[1]
        let mut c = h[2]
        let mut d = h[3]
        let mut e = h[4]
        let mut f = h[5]
        let mut g = h[6]
        let mut hh = h[7]
        t = 0
        while (t < 64) {
            let big1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            let ch = (e & f) ^ ((e ^ 0xFFFFFFFF) & g)
            let t1 = hh + big1 + ch + k[t] + w[t]
            let big0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let t2 = big0 + maj
            hh = g
            g = f
            f = e
            e = d + t1
            d = c
            c = b
            b = a
            a = t1 + t2
            t = t + 1
        }
        h[0] = h[0] + a
        h[1] = h[1] + b
        h[2] = h[2] + c
        h[3] = h[3] + d
        h[4] = h[4] + e
        h[5] = h[5] + f
        h[6] = h[6] + g
        h[7] = h[7] + hh
        block = block + 1
    }
    return h[0] ^ h[1] ^ h[2] ^ h[3] ^ h[4] ^ h[5] ^ h[6] ^ h[7]
}

export fn bench_popcount(scale: U32) -> U32 {
    let mut s: U32 = 55
    let mut bits: U32 = 0
    let mut i: U32 = 0
    while (i < 600000 * scale) {
        s = s * 1664525 + 1013904223
        let mut x = s
        while (x != 0) {
            x = x & (x - 1)
            bits = bits + 1
        }
        i = i + 1
    }
    return bits
}

export fn bench_mandelbrot_fixed(scale: U32) -> U32 {
    let mut total: U32 = 0

    for _ in 0..<6 {
        for py in 0..<96 as I32 {
            for px in 0..<96 as I32 {

                let cr = -131072 + px * 2048
                let ci = -98304 + py * 2048
                let mut zr = 0
                let mut zi = 0
                let mut it: U32 = 0
                while (it < 40) {
                    let zr2 = (((zr as I64) * (zr as I64)) >> 16) as Int
                    let zi2 = (((zi as I64) * (zi as I64)) >> 16) as Int
                    if (zr2 + zi2 > 262144) {
                        break
                    } else {
                        zi = ((((zr as I64) * (zi as I64)) >> 15) as Int) + ci
                        zr = zr2 - zi2 + cr
                        it = it + 1
                    }
                }
                total = total + it
            }
        }
    }
    return total
}

export fn bench_bytecode_interpreter(scale: U32) -> U32 {
    // op, a, b, c
    let program: [U32] = [
        0, 0, 1, 2,
        1, 1, 0, 3,
        2, 2, 1, 1,
        3, 3, 2, 0,
        4, 0, 0, 7,
        5, 1, 3, 0,
        0, 2, 2, 0,
        1, 3, 3, 1
    ]

    let mut reg: [U32] = [1, 2, 3, 4]
    let mut pc: U32 = 0

    for _ in 0..<400000 * scale {
        let base = (pc * 4) as Int
        let op = program[base]
        let a = program[base + 1] as Int
        let b = program[base + 2] as Int
        let c = program[base + 3]
        if (op == 0) {
            reg[a] = reg[b] + reg[c as Int]
        } else if (op == 1) {
            reg[a] = reg[b] ^ reg[c as Int]
        } else if (op == 2) {
            reg[a] = reg[b] * reg[c as Int]
        } else if (op == 3) {
            reg[a] = reg[b] << 1
        } else if (op == 4) {
            reg[a] = reg[b] + c
        } else {
            reg[a] = reg[b]
        }
        if (pc == 7) { pc = 0 } else { pc = pc + 1 }
    }
    return reg[0] ^ reg[1] ^ reg[2] ^ reg[3]
}
```

### prismio/memory.psm
```prismio
// Memory behaviour: dependent loads, a queue, and bulk movement through raw
// addresses. The same programs as ../c/memory.c and ../rust/memory.rs.

import std.mem
import std.raw
export fn bench_pointer_chase(scale: U32) -> U32 {
    let mut order: Array<U32, 2048>
    let mut next: Array<U32, 2048>
    let mut i = 0
    while (i < 2048) {
        order[i] = i as U32
        i = i + 1
    }
    let mut s: U32 = 9001
    i = 2047
    while (i > 0) {
        s = s * 1664525 + 1013904223
        let j = ((s >> 8) % ((i as U32) + 1)) as Int
        let t = order[i]
        order[i] = order[j]
        order[j] = t
        i = i - 1
    }
    let mut k = 0
    while (k < 2048) {
        next[order[k] as Int] = order[(k + 1) % 2048]
        k = k + 1
    }
    let mut at = order[0]
    let mut sum: U32 = 0
    let mut step: U32 = 0
    while (step < 2400000 * scale) {
        at = next[at as Int]
        sum = sum + at
        step = step + 1
    }
    return sum
}

export fn bench_ring_buffer(scale: U32) -> U32 {
    let mut slots: Array<U32, 1024>
    let mut head: U32 = 0
    let mut tail: U32 = 0
    let mut s: U32 = 321
    let mut sum: U32 = 0
    let mut popped: U32 = 0
    let mut i: U32 = 0
    while (i < 300000 * scale) {
        s = s * 1664525 + 1013904223
        if (head - tail < 1024) {
            slots[(head & 1023) as Int] = s
            head = head + 1
        }
        if (((s >> 8) & 1) == 0 and head != tail) {
            sum = sum + slots[(tail & 1023) as Int]
            tail = tail + 1
            popped = popped + 1
        }
        i = i + 1
    }
    return sum ^ popped
}

export fn bench_mem_copy(scale: U32) -> U32 {
    let mut o: Usize = 0
    while (o < 32768) {
        storeU64(0x44000000 + o, ((o as U64) * 0x9E3779B97F4A7C15) ^ 0x5555)
        o = o + 8
    }
    let mut r: U32 = 0
    while (r < 288 * scale) {
        o = 0
        while (o < 32768) {
            let v = loadU64(0x44000000 + o)
            storeU64(0x45000000 + o, v)
            storeU64(0x44000000 + o, v + (r as U64) + 1)
            o = o + 8
        }
        r = r + 1
    }
    let mut sum: U64 = 0
    o = 0
    while (o < 32768) {
        sum = sum + loadU64(0x45000000 + o)
        o = o + 8
    }
    return ((sum & 0xFFFFFFFF) as U32) ^ ((sum >> 32) as U32)
}
```

### prismio/hardware.psm
```prismio
// What only freestanding code does: atomic operations on a raw address, a lock,
// and volatile access to a register file. The same programs as ../c/hardware.c and
// ../rust/hardware.rs, written with the compiler's own builtins.

import std.mem
import std.raw
let WORD: Usize = 0x44100000
let LOCK: Usize= 0x44100010
let COUNTER: Usize = 0x44100020
let REGISTERS: Usize = 0x44200000

export fn bench_atomic_counter(scale: U32) -> U32 {
    volatileStoreU32(WORD, 0)

    for i in 0..<500000 * scale as Int {
        atomicAddU32(WORD, 1 + (i as U32 & 3))

    }
    return atomicLoadU32(WORD)
}

export fn bench_spinlock(scale: U32) -> U32 {
    volatileStoreU32(LOCK, 0)
    volatileStoreU32(COUNTER, 0)
    let mut i: U32 = 0
    while (i < 800000 * scale) {
        while (atomicCompareExchangeU32(LOCK, 0, 1) != 0) {}
        storeU32(COUNTER, loadU32(COUNTER) + 1)
        atomicStoreU32(LOCK, 0)
        i = i + 1
    }
    return loadU32(COUNTER)
}

export fn bench_volatile_registers(scale: U32) -> U32 {
    let mut i: Usize = 0
    while (i < 64) {
        volatileStoreU32(REGISTERS + i * 4, 0)
        i = i + 1
    }
    let mut acc: U32 = 0
    let mut n: U32 = 0
    while (n < 900000 * scale) {
        let slot = ((n * 7) & 63) as Usize
        let v = volatileLoadU32(REGISTERS + slot * 4)
        volatileStoreU32(REGISTERS + slot * 4, v + n)
        acc = acc + v
        n = n + 1
    }
    let mut sum: U32 = 0
    i = 0
    while (i < 64) {
        sum = sum + volatileLoadU32(REGISTERS + i * 4)
        i = i + 1
    }
    return acc ^ sum
}
```

## Appendix B: the workloads in C

### c/common.h
```c
// Types and the one generator every workload uses. The generator is a linear
// congruential step written out where it is used rather than called through a
// pointer, so the three arms express the same arithmetic and not three different
// ways of threading state.
#ifndef BENCH_COMMON_H
#define BENCH_COMMON_H

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long u64;
typedef int i32;
typedef long i64;

#define LCG(s) ((s) = (s) * 1664525u + 1013904223u)

#endif
```

### c/suite.c
```c
// One translation unit for the whole C arm, as the hosted C++ arm has one dispatcher
// over its category files: this includes them so the compiler sees every workload
// at once, the way it sees the Prismio program and the Rust crate.
#include "algorithms.c"
#include "compute.c"
#include "memory.c"
#include "hardware.c"
```

### c/algorithms.c
```c
// Algorithms over fixed arrays in the frame: no allocation, no library.
#include "common.h"

static u32 fib(u32 n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

u32 bench_fibonacci(u32 scale) {
    u32 total = 0;
    for (u32 r = 0; r < scale; r++) total += fib(27);
    return total;
}

#define SIEVE 200000

u32 bench_prime_sieve(u32 scale) {
    u32 total = 0;
    for (u32 r = 0; r < scale; r++) {
        u8 flags[SIEVE] = {0};
        u32 count = 0;
        for (u32 i = 2; i < SIEVE; i++) {
            if (flags[i] == 0) {
                count += 1;
                for (u32 j = i + i; j < SIEVE; j += i) flags[j] = 1;
            }
        }
        total += count;
    }
    return total;
}

static u32 gcd(u32 a, u32 b) {
    while (b != 0) {
        u32 t = a % b;
        a = b;
        b = t;
    }
    return a;
}

u32 bench_gcd_lcm(u32 scale) {
    u32 total = 0;
    for (u32 r = 0; r < scale; r++) {
        for (u32 a = 1; a <= 400; a++) {
            for (u32 b = 1; b <= 400; b++) total += gcd(a, b);
        }
    }
    return total;
}

#define SEARCH 4096

u32 bench_binary_search(u32 scale) {
    u32 table[SEARCH];
    for (u32 i = 0; i < SEARCH; i++) table[i] = i * 7 + 3;
    u32 s = 12345, found = 0, acc = 0;
    for (u32 q = 0; q < 100000 * scale; q++) {
        LCG(s);
        u32 key = s % 30000;
        u32 lo = 0, hi = SEARCH;
        while (lo < hi) {
            u32 mid = (lo + hi) >> 1;
            if (table[mid] < key) lo = mid + 1;
            else hi = mid;
        }
        if (lo < SEARCH && table[lo] == key) {
            found += 1;
            acc += lo;
        }
    }
    return found + acc * 3;
}

#define SORT 2048

static void quick(u32* a, i32 lo, i32 hi) {
    if (lo >= hi) return;
    u32 p = a[(lo + hi) >> 1];
    i32 i = lo, j = hi;
    while (i <= j) {
        while (a[i] < p) i++;
        while (a[j] > p) j--;
        if (i <= j) {
            u32 t = a[i];
            a[i] = a[j];
            a[j] = t;
            i++;
            j--;
        }
    }
    quick(a, lo, j);
    quick(a, i, hi);
}

u32 bench_quicksort(u32 scale) {
    u32 data[SORT];
    u32 s = 777, sum = 0;
    for (u32 r = 0; r < 40 * scale; r++) {
        for (u32 i = 0; i < SORT; i++) { LCG(s); data[i] = s >> 4; }
        quick(data, 0, SORT - 1);
        for (u32 i = 0; i < SORT; i++) sum += data[i] * (i + 1);
    }
    return sum;
}

static void sift(u32* a, i32 start, i32 end) {
    i32 root = start;
    while (root * 2 + 1 <= end) {
        i32 child = root * 2 + 1;
        i32 pick = root;
        if (a[pick] < a[child]) pick = child;
        if (child + 1 <= end && a[pick] < a[child + 1]) pick = child + 1;
        if (pick == root) return;
        u32 t = a[root];
        a[root] = a[pick];
        a[pick] = t;
        root = pick;
    }
}

u32 bench_heapsort(u32 scale) {
    u32 data[SORT];
    u32 s = 4242, sum = 0;
    for (u32 r = 0; r < 24 * scale; r++) {
        for (u32 i = 0; i < SORT; i++) { LCG(s); data[i] = s >> 4; }
        for (i32 start = (SORT - 2) / 2; start >= 0; start--) sift(data, start, SORT - 1);
        for (i32 end = SORT - 1; end > 0; end--) {
            u32 t = data[0];
            data[0] = data[end];
            data[end] = t;
            sift(data, 0, end - 1);
        }
        for (u32 i = 0; i < SORT; i++) sum += data[i] * (i + 1);
    }
    return sum;
}

#define ITEMS 64
#define CAPACITY 1500

static i32 imax(i32 a, i32 b) { return a > b ? a : b; }
static i32 imin(i32 a, i32 b) { return a < b ? a : b; }

u32 bench_knapsack(u32 scale) {
    i32 weight[ITEMS], value[ITEMS];
    u32 s = 99;
    for (u32 i = 0; i < ITEMS; i++) {
        LCG(s); weight[i] = (i32)((s >> 8) % 37) + 3;
        LCG(s); value[i] = (i32)((s >> 8) % 97) + 1;
    }
    u32 total = 0;
    for (u32 r = 0; r < 6 * scale; r++) {
        i32 best[CAPACITY + 1] = {0};
        for (u32 i = 0; i < ITEMS; i++) {
            i32 w = weight[i], v = value[i];
            for (i32 c = CAPACITY; c >= w; c--) best[c] = imax(best[c], best[c - w] + v);
        }
        total += (u32)best[CAPACITY];
    }
    return total;
}

#define STRING 600

u32 bench_edit_distance(u32 scale) {
    u8 a[STRING], b[STRING];
    u32 s = 31337;
    for (u32 i = 0; i < STRING; i++) { LCG(s); a[i] = (u8)((s >> 12) & 3); }
    for (u32 i = 0; i < STRING; i++) { LCG(s); b[i] = (u8)((s >> 12) & 3); }
    u32 total = 0;
    for (u32 r = 0; r < scale; r++) {
        i32 prev[STRING + 1], cur[STRING + 1];
        for (i32 j = 0; j <= STRING; j++) prev[j] = j;
        for (i32 i = 1; i <= STRING; i++) {
            cur[0] = i;
            for (i32 j = 1; j <= STRING; j++) {
                i32 cost = a[i - 1] == b[j - 1] ? 0 : 1;
                cur[j] = imin(imin(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost);
            }
            for (i32 j = 0; j <= STRING; j++) prev[j] = cur[j];
        }
        total += (u32)prev[STRING];
    }
    return total;
}

#define MATRIX 64

u32 bench_matrix_multiply(u32 scale) {
    u32 a[MATRIX * MATRIX], b[MATRIX * MATRIX], c[MATRIX * MATRIX];
    for (u32 i = 0; i < MATRIX; i++) {
        for (u32 j = 0; j < MATRIX; j++) {
            a[i * MATRIX + j] = (i * 3 + j * 5) % 17;
            b[i * MATRIX + j] = (i * 7 + j * 2) % 13;
        }
    }
    u32 total = 0;
    for (u32 r = 0; r < 8 * scale; r++) {
        for (u32 i = 0; i < MATRIX; i++) {
            for (u32 j = 0; j < MATRIX; j++) {
                u32 sum = 0;
                for (u32 k = 0; k < MATRIX; k++) sum += a[i * MATRIX + k] * b[k * MATRIX + j];
                c[i * MATRIX + j] = sum;
            }
        }
        for (u32 i = 0; i < MATRIX * MATRIX; i++) total += c[i];
        a[r % 64] += 1;
    }
    return total;
}
```

### c/compute.c
```c
// Integer compute: checksums, hashing, bit work, fixed-point arithmetic and a
// dispatch loop. No floating point, because the target keeps its FP unit off.
#include "common.h"

u32 bench_crc32(u32 scale) {
    u32 table[256];
    for (u32 i = 0; i < 256; i++) {
        u32 c = i;
        for (u32 k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
        table[i] = c;
    }
    u8 buffer[32768];
    u32 s = 2024;
    for (u32 i = 0; i < 32768; i++) { LCG(s); buffer[i] = (u8)(s >> 24); }
    u32 crc = 0xFFFFFFFFu;
    for (u32 r = 0; r < 32 * scale; r++) {
        for (u32 i = 0; i < 32768; i++) crc = table[(crc ^ buffer[i]) & 255] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFFu;
}

static const u32 K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
};

static inline u32 rotr(u32 x, u32 n) { return (x >> n) | (x << (32 - n)); }

u32 bench_sha256(u32 scale) {
    u32 h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
    u32 w[64];
    u32 s = 808;
    for (u32 block = 0; block < 3000 * scale; block++) {
        for (u32 t = 0; t < 16; t++) { LCG(s); w[t] = s; }
        for (u32 t = 16; t < 64; t++) {
            u32 s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
            u32 s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
            w[t] = w[t - 16] + s0 + w[t - 7] + s1;
        }
        u32 a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
        for (u32 t = 0; t < 64; t++) {
            u32 big1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
            u32 ch = (e & f) ^ ((e ^ 0xFFFFFFFFu) & g);
            u32 t1 = hh + big1 + ch + K[t] + w[t];
            u32 big0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
            u32 maj = (a & b) ^ (a & c) ^ (b & c);
            u32 t2 = big0 + maj;
            hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }
    return h[0] ^ h[1] ^ h[2] ^ h[3] ^ h[4] ^ h[5] ^ h[6] ^ h[7];
}

u32 bench_popcount(u32 scale) {
    u32 s = 55, bits = 0;
    for (u32 i = 0; i < 600000 * scale; i++) {
        LCG(s);
        u32 x = s;
        while (x != 0) {
            x &= x - 1;
            bits += 1;
        }
    }
    return bits;
}

u32 bench_mandelbrot_fixed(u32 scale) {
    u32 total = 0;
    for (u32 r = 0; r < 6 * scale; r++) {
        for (i32 py = 0; py < 96; py++) {
            for (i32 px = 0; px < 96; px++) {
                i32 cr = -131072 + px * 2048;
                i32 ci = -98304 + py * 2048;
                i32 zr = 0, zi = 0;
                u32 it = 0;
                while (it < 40) {
                    i32 zr2 = (i32)(((i64)zr * (i64)zr) >> 16);
                    i32 zi2 = (i32)(((i64)zi * (i64)zi) >> 16);
                    if (zr2 + zi2 > 262144) break;
                    zi = (i32)(((i64)zr * (i64)zi) >> 15) + ci;
                    zr = zr2 - zi2 + cr;
                    it += 1;
                }
                total += it;
            }
        }
    }
    return total;
}

// A register machine: 8 instructions of 4 words each, run in a loop.
u32 bench_bytecode_interpreter(u32 scale) {
    // op, a, b, c
    const u32 program[32] = {
        0, 0, 1, 2,   // r0 = r1 + r2
        1, 1, 0, 3,   // r1 = r0 ^ r3
        2, 2, 1, 1,   // r2 = r1 * r1
        3, 3, 2, 0,   // r3 = r2 << 1
        4, 0, 0, 7,   // r0 = r0 + 7
        5, 1, 3, 0,   // r1 = r3
        0, 2, 2, 0,   // r2 = r2 + r0
        1, 3, 3, 1,   // r3 = r3 ^ r1
    };
    u32 reg[4] = {1, 2, 3, 4};
    u32 pc = 0;
    for (u32 step = 0; step < 400000 * scale; step++) {
        u32 base = pc * 4;
        u32 op = program[base];
        u32 a = program[base + 1], b = program[base + 2], c = program[base + 3];
        if (op == 0) reg[a] = reg[b] + reg[c];
        else if (op == 1) reg[a] = reg[b] ^ reg[c];
        else if (op == 2) reg[a] = reg[b] * reg[c];
        else if (op == 3) reg[a] = reg[b] << 1;
        else if (op == 4) reg[a] = reg[b] + c;
        else reg[a] = reg[b];
        pc = pc == 7 ? 0 : pc + 1;
    }
    return reg[0] ^ reg[1] ^ reg[2] ^ reg[3];
}
```

### c/memory.c
```c
// Memory behaviour: dependent loads, a queue, and bulk movement.
#include "common.h"

#define CHAIN 2048

u32 bench_pointer_chase(u32 scale) {
    u32 order[CHAIN], next[CHAIN];
    for (u32 i = 0; i < CHAIN; i++) order[i] = i;
    u32 s = 9001;
    for (u32 i = CHAIN - 1; i > 0; i--) {
        LCG(s);
        u32 j = (s >> 8) % (i + 1);
        u32 t = order[i];
        order[i] = order[j];
        order[j] = t;
    }
    for (u32 k = 0; k < CHAIN; k++) next[order[k]] = order[(k + 1) % CHAIN];
    u32 at = order[0], sum = 0;
    for (u32 step = 0; step < 2400000 * scale; step++) {
        at = next[at];
        sum += at;
    }
    return sum;
}

#define RING 1024

u32 bench_ring_buffer(u32 scale) {
    u32 slots[RING];
    u32 head = 0, tail = 0, s = 321, sum = 0, popped = 0;
    for (u32 i = 0; i < 300000 * scale; i++) {
        LCG(s);
        if (head - tail < RING) {
            slots[head & (RING - 1)] = s;
            head += 1;
        }
        if (((s >> 8) & 1) == 0 && head != tail) {
            sum += slots[tail & (RING - 1)];
            tail += 1;
            popped += 1;
        }
    }
    return sum ^ popped;
}

#define SRC 0x44000000UL
#define DST 0x45000000UL
#define BLOCK 32768UL

u32 bench_mem_copy(u32 scale) {
    for (u64 o = 0; o < BLOCK; o += 8) *(u64*)(SRC + o) = (o * 0x9E3779B97F4A7C15UL) ^ 0x5555;
    for (u32 r = 0; r < 288 * scale; r++) {
        for (u64 o = 0; o < BLOCK; o += 8) {
            u64 v = *(u64*)(SRC + o);
            *(u64*)(DST + o) = v;
            *(u64*)(SRC + o) = v + r + 1;
        }
    }
    u64 sum = 0;
    for (u64 o = 0; o < BLOCK; o += 8) sum += *(u64*)(DST + o);
    return (u32)sum ^ (u32)(sum >> 32);
}
```

### c/hardware.c
```c
// What only freestanding code does: atomic operations on a raw address, a lock,
// and volatile access to a register file.
#include "common.h"

#define WORD 0x44100000UL
#define LOCK 0x44100010UL
#define COUNTER 0x44100020UL
#define REGISTERS 0x44200000UL

u32 bench_atomic_counter(u32 scale) {
    *(volatile u32*)WORD = 0;
    for (u32 i = 0; i < 500000 * scale; i++) {
        __atomic_fetch_add((u32*)WORD, 1 + (i & 3), __ATOMIC_SEQ_CST);
    }
    return __atomic_load_n((u32*)WORD, __ATOMIC_SEQ_CST);
}

u32 bench_spinlock(u32 scale) {
    *(volatile u32*)LOCK = 0;
    *(volatile u32*)COUNTER = 0;
    for (u32 i = 0; i < 800000 * scale; i++) {
        u32 expected = 0;
        while (!__atomic_compare_exchange_n((u32*)LOCK, &expected, 1, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)) {
            expected = 0;
        }
        *(u32*)COUNTER = *(u32*)COUNTER + 1;
        __atomic_store_n((u32*)LOCK, 0, __ATOMIC_SEQ_CST);
    }
    return *(u32*)COUNTER;
}

u32 bench_volatile_registers(u32 scale) {
    for (u32 i = 0; i < 64; i++) *(volatile u32*)(REGISTERS + i * 4) = 0;
    u32 acc = 0;
    for (u32 i = 0; i < 900000 * scale; i++) {
        u32 slot = (i * 7) & 63;
        u32 v = *(volatile u32*)(REGISTERS + slot * 4);
        *(volatile u32*)(REGISTERS + slot * 4) = v + i;
        acc += v;
    }
    u32 sum = 0;
    for (u32 i = 0; i < 64; i++) sum += *(volatile u32*)(REGISTERS + i * 4);
    return acc ^ sum;
}
```

## Appendix C: the workloads in Rust

### rust/lib.rs
```rust
//! The Rust arm of the freestanding suite: `no_std`, no allocation, one crate
//! exposing `bench_<name>` with the C ABI for the shared harness to call. It is
//! the C arm translated statement by statement; see ../README.md for the rule
//! that the three arms are the same program.
//!
//! Indexing is Rust's own, bounds-checked. That is a difference from the other two
//! arms and it is the language's price for safe indexing, so it stays.

#![no_std]

mod algorithms;
mod compute;
mod hardware;
mod memory;

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

/// The linear congruential step, as the other arms write it.
#[inline(always)]
pub(crate) fn lcg(s: &mut u32) -> u32 {
    *s = s.wrapping_mul(1664525).wrapping_add(1013904223);
    *s
}
```

### rust/algorithms.rs
```rust
use crate::lcg;

fn fib(n: u32) -> u32 {
    if n < 2 {
        return n;
    }
    fib(n - 1).wrapping_add(fib(n - 2))
}

#[no_mangle]
pub extern "C" fn bench_fibonacci(scale: u32) -> u32 {
    let mut total: u32 = 0;
    for _ in 0..scale {
        total = total.wrapping_add(fib(27));
    }
    total
}

const SIEVE: usize = 200000;

#[no_mangle]
pub extern "C" fn bench_prime_sieve(scale: u32) -> u32 {
    let mut total: u32 = 0;
    for _ in 0..scale {
        let mut flags = [0u8; SIEVE];
        let mut count: u32 = 0;
        let mut i = 2;
        while i < SIEVE {
            if flags[i] == 0 {
                count += 1;
                let mut j = i + i;
                while j < SIEVE {
                    flags[j] = 1;
                    j += i;
                }
            }
            i += 1;
        }
        total = total.wrapping_add(count);
    }
    total
}

fn gcd(mut a: u32, mut b: u32) -> u32 {
    while b != 0 {
        let t = a % b;
        a = b;
        b = t;
    }
    a
}

#[no_mangle]
pub extern "C" fn bench_gcd_lcm(scale: u32) -> u32 {
    let mut total: u32 = 0;
    for _ in 0..scale {
        let mut a = 1;
        while a <= 400 {
            let mut b = 1;
            while b <= 400 {
                total = total.wrapping_add(gcd(a, b));
                b += 1;
            }
            a += 1;
        }
    }
    total
}

const SEARCH: usize = 4096;

#[no_mangle]
pub extern "C" fn bench_binary_search(scale: u32) -> u32 {
    let mut table = [0u32; SEARCH];
    for i in 0..SEARCH {
        table[i] = (i as u32) * 7 + 3;
    }
    let mut s: u32 = 12345;
    let mut found: u32 = 0;
    let mut acc: u32 = 0;
    for _ in 0..100000u32.wrapping_mul(scale) {
        lcg(&mut s);
        let key = s % 30000;
        let mut lo: u32 = 0;
        let mut hi: u32 = SEARCH as u32;
        while lo < hi {
            let mid = (lo + hi) >> 1;
            if table[mid as usize] < key {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        if (lo as usize) < SEARCH && table[lo as usize] == key {
            found += 1;
            acc = acc.wrapping_add(lo);
        }
    }
    found.wrapping_add(acc.wrapping_mul(3))
}

const SORT: usize = 2048;

fn quick(a: &mut [u32; SORT], lo: i32, hi: i32) {
    if lo >= hi {
        return;
    }
    let p = a[((lo + hi) >> 1) as usize];
    let mut i = lo;
    let mut j = hi;
    while i <= j {
        while a[i as usize] < p {
            i += 1;
        }
        while a[j as usize] > p {
            j -= 1;
        }
        if i <= j {
            let t = a[i as usize];
            a[i as usize] = a[j as usize];
            a[j as usize] = t;
            i += 1;
            j -= 1;
        }
    }
    quick(a, lo, j);
    quick(a, i, hi);
}

#[no_mangle]
pub extern "C" fn bench_quicksort(scale: u32) -> u32 {
    let mut data = [0u32; SORT];
    let mut s: u32 = 777;
    let mut sum: u32 = 0;
    for _ in 0..40 * scale {
        for i in 0..SORT {
            data[i] = lcg(&mut s) >> 4;
        }
        quick(&mut data, 0, SORT as i32 - 1);
        for i in 0..SORT {
            sum = sum.wrapping_add(data[i].wrapping_mul(i as u32 + 1));
        }
    }
    sum
}

fn sift(a: &mut [u32; SORT], start: i32, end: i32) {
    let mut root = start;
    while root * 2 + 1 <= end {
        let child = root * 2 + 1;
        let mut pick = root;
        if a[pick as usize] < a[child as usize] {
            pick = child;
        }
        if child + 1 <= end && a[pick as usize] < a[(child + 1) as usize] {
            pick = child + 1;
        }
        if pick == root {
            return;
        }
        let t = a[root as usize];
        a[root as usize] = a[pick as usize];
        a[pick as usize] = t;
        root = pick;
    }
}

#[no_mangle]
pub extern "C" fn bench_heapsort(scale: u32) -> u32 {
    let mut data = [0u32; SORT];
    let mut s: u32 = 4242;
    let mut sum: u32 = 0;
    for _ in 0..24 * scale {
        for i in 0..SORT {
            data[i] = lcg(&mut s) >> 4;
        }
        let mut start = (SORT as i32 - 2) / 2;
        while start >= 0 {
            sift(&mut data, start, SORT as i32 - 1);
            start -= 1;
        }
        let mut end = SORT as i32 - 1;
        while end > 0 {
            let t = data[0];
            data[0] = data[end as usize];
            data[end as usize] = t;
            sift(&mut data, 0, end - 1);
            end -= 1;
        }
        for i in 0..SORT {
            sum = sum.wrapping_add(data[i].wrapping_mul(i as u32 + 1));
        }
    }
    sum
}

const ITEMS: usize = 64;
const CAPACITY: usize = 1500;

#[no_mangle]
pub extern "C" fn bench_knapsack(scale: u32) -> u32 {
    let mut weight = [0i32; ITEMS];
    let mut value = [0i32; ITEMS];
    let mut s: u32 = 99;
    for i in 0..ITEMS {
        weight[i] = ((lcg(&mut s) >> 8) % 37) as i32 + 3;
        value[i] = ((lcg(&mut s) >> 8) % 97) as i32 + 1;
    }
    let mut total: u32 = 0;
    for _ in 0..6 * scale {
        let mut best = [0i32; CAPACITY + 1];
        for i in 0..ITEMS {
            let w = weight[i];
            let v = value[i];
            let mut c = CAPACITY as i32;
            while c >= w {
                best[c as usize] = best[c as usize].max(best[(c - w) as usize] + v);
                c -= 1;
            }
        }
        total = total.wrapping_add(best[CAPACITY] as u32);
    }
    total
}

const STRING: usize = 600;

#[no_mangle]
pub extern "C" fn bench_edit_distance(scale: u32) -> u32 {
    let mut a = [0u8; STRING];
    let mut b = [0u8; STRING];
    let mut s: u32 = 31337;
    for i in 0..STRING {
        a[i] = ((lcg(&mut s) >> 12) & 3) as u8;
    }
    for i in 0..STRING {
        b[i] = ((lcg(&mut s) >> 12) & 3) as u8;
    }
    let mut total: u32 = 0;
    for _ in 0..scale {
        let mut prev = [0i32; STRING + 1];
        let mut cur = [0i32; STRING + 1];
        for j in 0..=STRING {
            prev[j] = j as i32;
        }
        for i in 1..=STRING {
            cur[0] = i as i32;
            for j in 1..=STRING {
                let cost = if a[i - 1] == b[j - 1] { 0 } else { 1 };
                cur[j] = (prev[j] + 1).min(cur[j - 1] + 1).min(prev[j - 1] + cost);
            }
            for j in 0..=STRING {
                prev[j] = cur[j];
            }
        }
        total = total.wrapping_add(prev[STRING] as u32);
    }
    total
}

const MATRIX: usize = 64;

#[no_mangle]
pub extern "C" fn bench_matrix_multiply(scale: u32) -> u32 {
    let mut a = [0u32; MATRIX * MATRIX];
    let mut b = [0u32; MATRIX * MATRIX];
    let mut c = [0u32; MATRIX * MATRIX];
    for i in 0..MATRIX {
        for j in 0..MATRIX {
            a[i * MATRIX + j] = ((i * 3 + j * 5) % 17) as u32;
            b[i * MATRIX + j] = ((i * 7 + j * 2) % 13) as u32;
        }
    }
    let mut total: u32 = 0;
    for r in 0..8 * scale {
        for i in 0..MATRIX {
            for j in 0..MATRIX {
                let mut sum: u32 = 0;
                for k in 0..MATRIX {
                    sum = sum.wrapping_add(a[i * MATRIX + k].wrapping_mul(b[k * MATRIX + j]));
                }
                c[i * MATRIX + j] = sum;
            }
        }
        for i in 0..MATRIX * MATRIX {
            total = total.wrapping_add(c[i]);
        }
        a[(r % 64) as usize] += 1;
    }
    total
}
```

### rust/compute.rs
```rust
use crate::lcg;

#[no_mangle]
pub extern "C" fn bench_crc32(scale: u32) -> u32 {
    let mut table = [0u32; 256];
    for i in 0..256u32 {
        let mut c = i;
        for _ in 0..8 {
            c = if (c & 1) != 0 { 0xEDB88320u32 ^ (c >> 1) } else { c >> 1 };
        }
        table[i as usize] = c;
    }
    let mut buffer = [0u8; 32768];
    let mut s: u32 = 2024;
    for i in 0..32768 {
        buffer[i] = (lcg(&mut s) >> 24) as u8;
    }
    let mut crc: u32 = 0xFFFFFFFF;
    for _ in 0..32 * scale {
        for i in 0..32768 {
            crc = table[((crc ^ buffer[i] as u32) & 255) as usize] ^ (crc >> 8);
        }
    }
    crc ^ 0xFFFFFFFF
}

const K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

#[inline(always)]
fn rotr(x: u32, n: u32) -> u32 {
    (x >> n) | (x << (32 - n))
}

#[no_mangle]
pub extern "C" fn bench_sha256(scale: u32) -> u32 {
    let mut h: [u32; 8] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];
    let mut w = [0u32; 64];
    let mut s: u32 = 808;
    for _ in 0..3000 * scale {
        for t in 0..16 {
            w[t] = lcg(&mut s);
        }
        for t in 16..64 {
            let s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
            let s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
            w[t] = w[t - 16].wrapping_add(s0).wrapping_add(w[t - 7]).wrapping_add(s1);
        }
        let (mut a, mut b, mut c, mut d) = (h[0], h[1], h[2], h[3]);
        let (mut e, mut f, mut g, mut hh) = (h[4], h[5], h[6], h[7]);
        for t in 0..64 {
            let big1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
            let ch = (e & f) ^ ((e ^ 0xFFFFFFFF) & g);
            let t1 = hh
                .wrapping_add(big1)
                .wrapping_add(ch)
                .wrapping_add(K[t])
                .wrapping_add(w[t]);
            let big0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
            let maj = (a & b) ^ (a & c) ^ (b & c);
            let t2 = big0.wrapping_add(maj);
            hh = g;
            g = f;
            f = e;
            e = d.wrapping_add(t1);
            d = c;
            c = b;
            b = a;
            a = t1.wrapping_add(t2);
        }
        h[0] = h[0].wrapping_add(a);
        h[1] = h[1].wrapping_add(b);
        h[2] = h[2].wrapping_add(c);
        h[3] = h[3].wrapping_add(d);
        h[4] = h[4].wrapping_add(e);
        h[5] = h[5].wrapping_add(f);
        h[6] = h[6].wrapping_add(g);
        h[7] = h[7].wrapping_add(hh);
    }
    h[0] ^ h[1] ^ h[2] ^ h[3] ^ h[4] ^ h[5] ^ h[6] ^ h[7]
}

#[no_mangle]
pub extern "C" fn bench_popcount(scale: u32) -> u32 {
    let mut s: u32 = 55;
    let mut bits: u32 = 0;
    for _ in 0..600000 * scale {
        let mut x = lcg(&mut s);
        while x != 0 {
            x &= x - 1;
            bits += 1;
        }
    }
    bits
}

#[no_mangle]
pub extern "C" fn bench_mandelbrot_fixed(scale: u32) -> u32 {
    let mut total: u32 = 0;
    for _ in 0..6 * scale {
        for py in 0..96i32 {
            for px in 0..96i32 {
                let cr = -131072 + px * 2048;
                let ci = -98304 + py * 2048;
                let mut zr: i32 = 0;
                let mut zi: i32 = 0;
                let mut it: u32 = 0;
                while it < 40 {
                    let zr2 = ((zr as i64 * zr as i64) >> 16) as i32;
                    let zi2 = ((zi as i64 * zi as i64) >> 16) as i32;
                    if zr2 + zi2 > 262144 {
                        break;
                    }
                    zi = (((zr as i64 * zi as i64) >> 15) as i32) + ci;
                    zr = zr2 - zi2 + cr;
                    it += 1;
                }
                total = total.wrapping_add(it);
            }
        }
    }
    total
}

#[no_mangle]
pub extern "C" fn bench_bytecode_interpreter(scale: u32) -> u32 {
    // op, a, b, c
    const PROGRAM: [u32; 32] = [
        0, 0, 1, 2, //
        1, 1, 0, 3, //
        2, 2, 1, 1, //
        3, 3, 2, 0, //
        4, 0, 0, 7, //
        5, 1, 3, 0, //
        0, 2, 2, 0, //
        1, 3, 3, 1, //
    ];
    let mut reg: [u32; 4] = [1, 2, 3, 4];
    let mut pc: u32 = 0;
    for _ in 0..400000 * scale {
        let base = (pc * 4) as usize;
        let op = PROGRAM[base];
        let a = PROGRAM[base + 1] as usize;
        let b = PROGRAM[base + 2] as usize;
        let c = PROGRAM[base + 3];
        if op == 0 {
            reg[a] = reg[b].wrapping_add(reg[c as usize]);
        } else if op == 1 {
            reg[a] = reg[b] ^ reg[c as usize];
        } else if op == 2 {
            reg[a] = reg[b].wrapping_mul(reg[c as usize]);
        } else if op == 3 {
            reg[a] = reg[b] << 1;
        } else if op == 4 {
            reg[a] = reg[b].wrapping_add(c);
        } else {
            reg[a] = reg[b];
        }
        pc = if pc == 7 { 0 } else { pc + 1 };
    }
    reg[0] ^ reg[1] ^ reg[2] ^ reg[3]
}
```

### rust/memory.rs
```rust
use crate::lcg;

const CHAIN: usize = 2048;

#[no_mangle]
pub extern "C" fn bench_pointer_chase(scale: u32) -> u32 {
    let mut order = [0u32; CHAIN];
    let mut next = [0u32; CHAIN];
    for i in 0..CHAIN {
        order[i] = i as u32;
    }
    let mut s: u32 = 9001;
    let mut i = CHAIN - 1;
    while i > 0 {
        let j = (lcg(&mut s) >> 8) % (i as u32 + 1);
        let t = order[i];
        order[i] = order[j as usize];
        order[j as usize] = t;
        i -= 1;
    }
    for k in 0..CHAIN {
        next[order[k] as usize] = order[(k + 1) % CHAIN];
    }
    let mut at = order[0];
    let mut sum: u32 = 0;
    for _ in 0..2400000 * scale {
        at = next[at as usize];
        sum = sum.wrapping_add(at);
    }
    sum
}

const RING: usize = 1024;

#[no_mangle]
pub extern "C" fn bench_ring_buffer(scale: u32) -> u32 {
    let mut slots = [0u32; RING];
    let mut head: u32 = 0;
    let mut tail: u32 = 0;
    let mut s: u32 = 321;
    let mut sum: u32 = 0;
    let mut popped: u32 = 0;
    for _ in 0..300000 * scale {
        lcg(&mut s);
        if head.wrapping_sub(tail) < RING as u32 {
            slots[(head & (RING as u32 - 1)) as usize] = s;
            head = head.wrapping_add(1);
        }
        if ((s >> 8) & 1) == 0 && head != tail {
            sum = sum.wrapping_add(slots[(tail & (RING as u32 - 1)) as usize]);
            tail = tail.wrapping_add(1);
            popped += 1;
        }
    }
    sum ^ popped
}

const SRC: usize = 0x44000000;
const DST: usize = 0x45000000;
const BLOCK: usize = 32768;

#[no_mangle]
pub extern "C" fn bench_mem_copy(scale: u32) -> u32 {
    unsafe {
        let mut o = 0;
        while o < BLOCK {
            ((SRC + o) as *mut u64).write((o as u64).wrapping_mul(0x9E3779B97F4A7C15) ^ 0x5555);
            o += 8;
        }
        for r in 0..288 * scale {
            let mut o = 0;
            while o < BLOCK {
                let v = ((SRC + o) as *const u64).read();
                ((DST + o) as *mut u64).write(v);
                ((SRC + o) as *mut u64).write(v.wrapping_add(r as u64).wrapping_add(1));
                o += 8;
            }
        }
        let mut sum: u64 = 0;
        let mut o = 0;
        while o < BLOCK {
            sum = sum.wrapping_add(((DST + o) as *const u64).read());
            o += 8;
        }
        (sum as u32) ^ ((sum >> 32) as u32)
    }
}
```

### rust/hardware.rs
```rust
use core::sync::atomic::{AtomicU32, Ordering};

const WORD: usize = 0x44100000;
const LOCK: usize = 0x44100010;
const COUNTER: usize = 0x44100020;
const REGISTERS: usize = 0x44200000;

#[no_mangle]
pub extern "C" fn bench_atomic_counter(scale: u32) -> u32 {
    unsafe {
        (WORD as *mut u32).write_volatile(0);
        let word = &*(WORD as *const AtomicU32);
        for i in 0..500000 * scale {
            word.fetch_add(1 + (i & 3), Ordering::SeqCst);
        }
        word.load(Ordering::SeqCst)
    }
}

#[no_mangle]
pub extern "C" fn bench_spinlock(scale: u32) -> u32 {
    unsafe {
        (LOCK as *mut u32).write_volatile(0);
        (COUNTER as *mut u32).write_volatile(0);
        let lock = &*(LOCK as *const AtomicU32);
        let counter = COUNTER as *mut u32;
        for _ in 0..800000 * scale {
            while lock
                .compare_exchange(0, 1, Ordering::SeqCst, Ordering::SeqCst)
                .is_err()
            {}
            counter.write(counter.read().wrapping_add(1));
            lock.store(0, Ordering::SeqCst);
        }
        counter.read()
    }
}

#[no_mangle]
pub extern "C" fn bench_volatile_registers(scale: u32) -> u32 {
    unsafe {
        for i in 0..64usize {
            ((REGISTERS + i * 4) as *mut u32).write_volatile(0);
        }
        let mut acc: u32 = 0;
        for i in 0..900000 * scale {
            let slot = ((i.wrapping_mul(7)) & 63) as usize;
            let v = ((REGISTERS + slot * 4) as *const u32).read_volatile();
            ((REGISTERS + slot * 4) as *mut u32).write_volatile(v.wrapping_add(i));
            acc = acc.wrapping_add(v);
        }
        let mut sum: u32 = 0;
        for i in 0..64usize {
            sum = sum.wrapping_add(((REGISTERS + i * 4) as *const u32).read_volatile());
        }
        acc ^ sum
    }
}
```

## Appendix D: machine code

Each image's own functions, harness excluded, aliases shown once. A branch target inside a function is `+offset` in bytes.

### D.1 C (clang -O3)

#### `bench_fibonacci` (11 instructions, 44 bytes)
```asm
    0: cbz w0, +40
    4: stp x29, x30, [sp, #-0x20]!
    8: str x19, [sp, #0x10]
   12: mov w19, w0
   16: mov w0, #0x1b
   20: mov x29, sp
   24: bl <fib>
   28: mul w0, w0, w19
   32: ldr x19, [sp, #0x10]
   36: ldp x29, x30, [sp], #0x20
   40: ret
```

#### `fib` (21 instructions, 84 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: mov w19, w0
   12: cmp w0, #0x2
   16: mov x29, sp
   20: b.hs +40
   24: add w0, w19, wzr
   28: ldp x20, x19, [sp, #0x10]
   32: ldp x29, x30, [sp], #0x20
   36: ret
   40: mov w20, wzr
   44: sub w0, w19, #0x1
   48: bl +0
   52: sub w19, w19, #0x2
   56: add w20, w0, w20
   60: cmp w19, #0x1
   64: b.hi +44
   68: add w0, w19, w20
   72: ldp x20, x19, [sp, #0x10]
   76: ldp x29, x30, [sp], #0x20
   80: ret
```

#### `bench_prime_sieve` (104 instructions, 416 bytes)
```asm
    0: stp x29, x30, [sp, #-0x50]!
    4: stp x28, x25, [sp, #0x10]
    8: mov x29, sp
   12: stp x24, x23, [sp, #0x20]
   16: stp x22, x21, [sp, #0x30]
   20: stp x20, x19, [sp, #0x40]
   24: sub sp, sp, #0x30, lsl #12
   28: sub sp, sp, #0xd40
   32: cbz w0, +376
   36: mov w22, #0xd40
   40: mov w24, #0xd3a
   44: mov w19, w0
   48: mov w21, wzr
   52: mov w20, wzr
   56: movk w22, #0x3, lsl #16
   60: mov x23, sp
   64: movk w24, #0x3, lsl #16
   68: mov w25, #0x1
   72: b +92
   76: add w21, w21, #0x1
   80: add w20, w8, w20
   84: cmp w21, w19
   88: b.eq +380
   92: mov w2, #0xd40
   96: mov x0, sp
  100: mov w1, wzr
  104: movk w2, #0x3, lsl #16
  108: bl <memset>
  112: mov x9, xzr
  116: mov x10, xzr
  120: mov x11, xzr
  124: mov w8, wzr
  128: mov w12, #0x6
  132: mov w13, #0x8
  136: mov w14, #0xa
  140: mov w15, #0x2
  144: mov w16, #0x4
  148: b +192
  152: add x15, x15, #0x1
  156: add x16, x16, #0x2
  160: add x11, x11, #0x1
  164: add x10, x10, #0x3
  168: sub x9, x9, #0x3
  172: cmp x15, x22
  176: add x14, x14, #0x5
  180: add x13, x13, #0x4
  184: add x12, x12, #0x3
  188: b.eq +76
  192: add x17, x11, x11, lsl #1
  196: cmp x10, x24
  200: sub x18, x11, x11, lsl #2
  204: csel x0, x10, x24, hi
  208: ldrb w2, [x23, x15]
  212: cmp x17, x24
  216: csel x17, x17, x24, hi
  220: adds x17, x17, x18
  224: cset w18, ne
  228: csetm x1, ne
  232: cbnz w2, +152
  236: lsr x2, x15, #5
  240: add w8, w8, #0x1
  244: cmp x2, #0xc34
  248: b.hi +152
  252: sub x18, x17, x18
  256: cmp x17, #0x0
  260: mov x17, x16
  264: udiv x18, x18, x15
  268: cinc x2, x25, ne
  272: add x18, x2, x18
  276: cmp x18, #0x4
  280: b.lo +356
  284: add x17, x0, x9
  288: and x0, x18, #0xfffffffffffffffc
  292: add x17, x17, x1
  296: udiv x1, x17, x15
  300: madd x17, x0, x15, x16
  304: add x1, x2, x1
  308: mov x2, sp
  312: and x1, x1, #0xfffffffffffffffc
  316: add x3, x2, x13
  320: strb w25, [x2, x16]
  324: subs x1, x1, #0x4
  328: strb w25, [x2, x12]
  332: strb w25, [x3]
  336: strb w25, [x2, x14]
  340: mov x2, x3
  344: b.ne +316
  348: cmp x18, x0
  352: b.eq +152
  356: strb w25, [x23, x17]
  360: add x17, x17, x15
  364: cmp x17, x22
  368: b.lo +356
  372: b +152
  376: mov w20, wzr
  380: mov w0, w20
  384: add sp, sp, #0x30, lsl #12
  388: add sp, sp, #0xd40
  392: ldp x20, x19, [sp, #0x40]
  396: ldp x22, x21, [sp, #0x30]
  400: ldp x24, x23, [sp, #0x20]
  404: ldp x28, x25, [sp, #0x10]
  408: ldp x29, x30, [sp], #0x50
  412: ret
```

#### `bench_gcd_lcm` (26 instructions, 104 bytes)
```asm
    0: cbz w0, +96
    4: mov w9, wzr
    8: mov w8, wzr
   12: mov w10, #0x1
   16: mov w11, #0x1
   20: mov w13, w10
   24: mov w14, w11
   28: mov w12, w14
   32: udiv w14, w13, w14
   36: msub w14, w14, w12, w13
   40: mov w13, w12
   44: cbnz w14, +28
   48: add w11, w11, #0x1
   52: add w8, w12, w8
   56: cmp w11, #0x191
   60: b.ne +20
   64: add w10, w10, #0x1
   68: cmp w10, #0x191
   72: b.ne +16
   76: add w9, w9, #0x1
   80: cmp w9, w0
   84: b.ne +12
   88: mov w0, w8
   92: ret
   96: mov w0, wzr
  100: ret
```

#### `bench_binary_search` (65 instructions, 260 bytes)
```asm
    0: str x29, [sp, #-0x10]!
    4: sub sp, sp, #0x4, lsl #12
    8: mov x9, sp
   12: mov x8, xzr
   16: add x9, x9, #0x8
   20: add w10, w8, #0x3
   24: add w11, w8, #0xa
   28: add w12, w8, #0x11
   32: stp w10, w11, [x9, #-0x8]
   36: add w10, w8, #0x18
   40: add x8, x8, #0x1c
   44: cmp x8, #0x7, lsl #12
   48: stp w12, w10, [x9], #0x10
   52: b.ne +20
   56: mov w8, #0x86a0
   60: movk w8, #0x1, lsl #16
   64: mul w8, w0, w8
   68: cbz w8, +244
   72: mov w13, #0x660d
   76: mov w14, #0xf35f
   80: mov w15, #0xb273
   84: mov w11, wzr
   88: mov w10, wzr
   92: mov w9, wzr
   96: mov w12, #0x3039
  100: movk w13, #0x19, lsl #16
  104: movk w14, #0x3c6e, lsl #16
  108: movk w15, #0x45e7, lsl #16
  112: mov w16, #0x7530
  116: mov x17, sp
  120: b +136
  124: add w11, w11, #0x1
  128: cmp w11, w8
  132: b.eq +224
  136: madd w12, w12, w13, w14
  140: mov w18, wzr
  144: mov w1, #0x1000
  148: umull x0, w12, w15
  152: lsr x0, x0, #45
  156: msub w0, w0, w16, w12
  160: add w2, w1, w18
  164: lsr w2, w2, #1
  168: ldr w3, [x17, w2, uxtw #2]
  172: cmp w3, w0
  176: csinc w18, w18, w2, hs
  180: csel w1, w2, w1, hs
  184: cmp w18, w1
  188: b.lo +160
  192: cmp w18, #0xfff
  196: b.hi +124
  200: ldr w1, [x17, w18, uxtw #2]
  204: cmp w1, w0
  208: b.ne +124
  212: add w9, w9, #0x1
  216: add w10, w18, w10
  220: b +124
  224: add w8, w10, w10, lsl #1
  228: add w0, w8, w9
  232: add sp, sp, #0x4, lsl #12
  236: ldr x29, [sp], #0x10
  240: ret
  244: mov w0, wzr
  248: add sp, sp, #0x4, lsl #12
  252: ldr x29, [sp], #0x10
  256: ret
```

#### `bench_quicksort` (54 instructions, 216 bytes)
```asm
    0: stp x29, x30, [sp, #-0x50]!
    4: stp x28, x25, [sp, #0x10]
    8: mov x29, sp
   12: stp x24, x23, [sp, #0x20]
   16: stp x22, x21, [sp, #0x30]
   20: stp x20, x19, [sp, #0x40]
   24: sub sp, sp, #0x2, lsl #12
   28: add w8, w0, w0, lsl #2
   32: lsl w20, w8, #3
   36: cbz w20, +180
   40: mov w24, #0x660d
   44: mov w25, #0xf35f
   48: mov w21, wzr
   52: mov w19, wzr
   56: mov x22, sp
   60: mov w23, #0x309
   64: movk w24, #0x19, lsl #16
   68: movk w25, #0x3c6e, lsl #16
   72: mov x8, xzr
   76: madd w23, w23, w24, w25
   80: lsr w9, w23, #4
   84: str w9, [x22, x8]
   88: add x8, x8, #0x4
   92: cmp x8, #0x2, lsl #12
   96: b.ne +76
  100: mov x0, sp
  104: mov w1, wzr
  108: mov w2, #0x7ff
  112: bl <quick>
  116: mov w8, wzr
  120: mov x9, #-0x800
  124: add x10, x22, #0x4
  128: ldp w11, w12, [x10, #-0x4]
  132: add w13, w9, #0x801
  136: add w14, w9, #0x802
  140: adds x9, x9, #0x2
  144: add x10, x10, #0x8
  148: madd w19, w11, w13, w19
  152: madd w8, w12, w14, w8
  156: b.ne +128
  160: add w21, w21, #0x1
  164: add w19, w8, w19
  168: cmp w21, w20
  172: b.ne +72
  176: b +184
  180: mov w19, wzr
  184: mov w0, w19
  188: add sp, sp, #0x2, lsl #12
  192: ldp x20, x19, [sp, #0x40]
  196: ldp x22, x21, [sp, #0x30]
  200: ldp x24, x23, [sp, #0x20]
  204: ldp x28, x25, [sp, #0x10]
  208: ldp x29, x30, [sp], #0x50
  212: ret
```

#### `quick` (49 instructions, 196 bytes)
```asm
    0: cmp w1, w2
    4: b.ge +192
    8: stp x29, x30, [sp, #-0x30]!
   12: stp x20, x19, [sp, #0x20]
   16: mov w19, w2
   20: mov x20, x0
   24: str x21, [sp, #0x10]
   28: mov x29, sp
   32: b +56
   36: mov x0, x20
   40: bl +0
   44: cmp w21, w19
   48: mov w1, w21
   52: b.ge +180
   56: add w8, w1, w19
   60: mov w21, w1
   64: mov w2, w19
   68: asr w8, w8, #1
   72: ldr w8, [x20, w8, sxtw #2]
   76: b +100
   80: add x12, x20, x2, lsl #2
   84: stur w11, [x10, #-0x4]
   88: str w9, [x12, #0x4]
   92: cmp w21, w2
   96: b.gt +36
  100: sxtw x21, w21
  104: ldr w9, [x20, x21, lsl #2]
  108: add x21, x21, #0x1
  112: cmp w9, w8
  116: b.lo +104
  120: add x10, x20, x21, lsl #2
  124: sub x12, x21, #0x1
  128: sxtw x2, w2
  132: ldr w11, [x20, x2, lsl #2]
  136: sub x2, x2, #0x1
  140: cmp w11, w8
  144: b.hi +132
  148: add x13, x2, #0x1
  152: cmp x12, x13
  156: b.le +80
  160: sub w21, w21, #0x1
  164: add w2, w2, #0x1
  168: cmp w21, w2
  172: b.le +100
  176: b +36
  180: ldp x20, x19, [sp, #0x20]
  184: ldr x21, [sp, #0x10]
  188: ldp x29, x30, [sp], #0x30
  192: ret
```

#### `bench_heapsort` (106 instructions, 424 bytes)
```asm
    0: add w8, w0, w0, lsl #1
    4: lsl w8, w8, #3
    8: cbz w8, +416
   12: str x29, [sp, #-0x10]!
   16: sub sp, sp, #0x2, lsl #12
   20: mov w12, #0x660d
   24: mov w13, #0xf35f
   28: mov w9, wzr
   32: mov w0, wzr
   36: mov x10, sp
   40: mov w11, #0x1092
   44: movk w12, #0x19, lsl #16
   48: movk w13, #0x3c6e, lsl #16
   52: mov x14, xzr
   56: madd w11, w11, w12, w13
   60: lsr w15, w11, #4
   64: str w15, [x10, x14]
   68: add x14, x14, #0x4
   72: cmp x14, #0x2, lsl #12
   76: b.ne +56
   80: mov w15, #0x3ff
   84: b +96
   88: sub x15, x14, #0x1
   92: cbz x14, +204
   96: mov x14, x15
  100: ldr w15, [x10, x15, lsl #2]
  104: mov x16, x14
  108: mov w17, #0x1
  112: bfi x17, x16, #1, #62
  116: ldr w18, [x10, x17, lsl #2]
  120: cmp w15, w18
  124: b.lo +132
  128: mov x17, x16
  132: cmp x16, #0x3fe
  136: b.hi +164
  140: lsl x18, x16, #1
  144: ldr w1, [x10, x17, lsl #2]
  148: add x18, x18, #0x2
  152: ldr w2, [x10, x18, lsl #2]
  156: cmp w1, w2
  160: b.lo +168
  164: mov x18, x17
  168: cmp x18, x16
  172: b.eq +88
  176: ldr w17, [x10, x18, lsl #2]
  180: cmp x18, #0x400
  184: str w17, [x10, x16, lsl #2]
  188: mov x16, x18
  192: str w15, [x10, x18, lsl #2]
  196: b.lo +108
  200: b +88
  204: mov w14, #0x7ff
  208: b +224
  212: cmp x14, #0x1
  216: mov x14, x16
  220: b.ls +344
  224: ldr w15, [x10, x14, lsl #2]
  228: ldr w17, [sp]
  232: subs x16, x14, #0x1
  236: str w17, [x10, x14, lsl #2]
  240: str w15, [sp]
  244: b.eq +344
  248: mov x1, xzr
  252: mov x17, xzr
  256: orr x2, x1, #0x1
  260: ldr w18, [x10, x2, lsl #2]
  264: cmp w15, w18
  268: add x18, x1, #0x2
  272: csel x1, x2, x17, lo
  276: cmp x16, x18
  280: b.lo +300
  284: ldr w2, [x10, x1, lsl #2]
  288: ldr w3, [x10, x18, lsl #2]
  292: cmp w2, w3
  296: b.lo +304
  300: mov x18, x1
  304: cmp x18, x17
  308: b.eq +212
  312: lsl x1, x18, #1
  316: ldr w2, [x10, x18, lsl #2]
  320: str w2, [x10, x17, lsl #2]
  324: mov x17, x18
  328: cmp x16, x1
  332: str w15, [x10, x18, lsl #2]
  336: b.hi +256
  340: b +212
  344: mov w14, wzr
  348: mov x15, #-0x800
  352: add x16, x10, #0x4
  356: ldp w17, w18, [x16, #-0x4]
  360: add w1, w15, #0x801
  364: add w2, w15, #0x802
  368: adds x15, x15, #0x2
  372: add x16, x16, #0x8
  376: madd w0, w17, w1, w0
  380: madd w14, w18, w2, w14
  384: b.ne +356
  388: add w9, w9, #0x1
  392: add w0, w14, w0
  396: cmp w9, w8
  400: b.ne +52
  404: add sp, sp, #0x2, lsl #12
  408: ldr x29, [sp], #0x10
  412: ret
  416: mov w0, wzr
  420: ret
```

#### `bench_knapsack` (93 instructions, 372 bytes)
```asm
    0: stp x29, x30, [sp, #-0x50]!
    4: str x28, [sp, #0x10]
    8: mov x29, sp
   12: stp x24, x23, [sp, #0x20]
   16: stp x22, x21, [sp, #0x30]
   20: stp x20, x19, [sp, #0x40]
   24: sub sp, sp, #0x1, lsl #12
   28: sub sp, sp, #0x980
   32: mov w9, #0xf35f
   36: mov w10, #0x660d
   40: mov w11, #0x3e46
   44: mov w14, #0xa0fe
   48: add x17, sp, #0x1, lsl #12
   52: mov x8, xzr
   56: movk w9, #0x3c6e, lsl #16
   60: movk w10, #0x19, lsl #16
   64: mov w16, #0x63
   68: movk w11, #0x6eb, lsl #16
   72: mov w12, #0x25
   76: sub x13, x29, #0x100
   80: movk w14, #0x2a3, lsl #16
   84: mov w15, #0x61
   88: add x17, x17, #0x780
   92: madd w18, w16, w10, w9
   96: madd w16, w18, w10, w9
  100: lsr w18, w18, #8
  104: umull x2, w18, w11
  108: lsr w1, w16, #8
  112: umull x3, w1, w14
  116: lsr x2, x2, #32
  120: msub w18, w2, w12, w18
  124: lsr x3, x3, #32
  128: msub w1, w3, w15, w1
  132: add w18, w18, #0x3
  136: str w18, [x13, x8]
  140: add w18, w1, #0x1
  144: str w18, [x17, x8]
  148: add x8, x8, #0x4
  152: cmp x8, #0x100
  156: b.ne +92
  160: add w8, w0, w0, lsl #1
  164: lsl w20, w8, #1
  168: cbz w20, +332
  172: mov w8, #0x1770
  176: add x9, sp, #0xc
  180: add x24, sp, #0x1, lsl #12
  184: mov w21, wzr
  188: mov w19, wzr
  192: add x22, x9, x8
  196: sub x23, x29, #0x100
  200: add x24, x24, #0x780
  204: b +228
  208: ldr w8, [sp, #0x177c]
  212: add w21, w21, #0x1
  216: cmp w21, w20
  220: add w19, w8, w19
  224: b.eq +336
  228: add x0, sp, #0xc
  232: mov w1, wzr
  236: mov w2, #0x1774
  240: bl <memset>
  244: mov x8, xzr
  248: b +264
  252: add x8, x8, #0x1
  256: cmp x8, #0x40
  260: b.eq +208
  264: ldrsw x9, [x23, x8, lsl #2]
  268: cmp w9, #0x5dc
  272: b.gt +252
  276: ldr w10, [x24, x8, lsl #2]
  280: neg x11, x9, lsl #2
  284: mov x12, x22
  288: mov w13, #0x5dd
  292: ldr w14, [x12, x11]
  296: ldr w15, [x12]
  300: sub x13, x13, #0x1
  304: add w14, w14, w10
  308: cmp w15, w14
  312: csel w14, w15, w14, gt
  316: cmp x13, x9
  320: str w14, [x12], #-0x4
  324: b.gt +292
  328: b +252
  332: mov w19, wzr
  336: mov w0, w19
  340: add sp, sp, #0x1, lsl #12
  344: add sp, sp, #0x980
  348: ldp x20, x19, [sp, #0x40]
  352: ldr x28, [sp, #0x10]
  356: ldp x22, x21, [sp, #0x30]
  360: ldp x24, x23, [sp, #0x20]
  364: ldp x29, x30, [sp], #0x50
  368: ret
```

#### `bench_edit_distance` (103 instructions, 412 bytes)
```asm
    0: str x29, [sp, #-0x10]!
    4: sub sp, sp, #0x1, lsl #12
    8: sub sp, sp, #0x780
   12: mov w8, #0xf35f
   16: mov w10, #0x660d
   20: add x13, sp, #0x1, lsl #12
   24: mov x12, xzr
   28: movk w8, #0x3c6e, lsl #16
   32: movk w10, #0x19, lsl #16
   36: add x9, sp, #0x96c
   40: mov w11, #0x7a69
   44: add x13, x13, #0x528
   48: madd w11, w11, w10, w8
   52: ubfx w14, w11, #12, #2
   56: strb w14, [x13, x12]
   60: add x12, x12, #0x1
   64: cmp x12, #0x258
   68: b.ne +48
   72: add x13, sp, #0x1, lsl #12
   76: mov x12, xzr
   80: add x13, x13, #0x2d0
   84: madd w11, w11, w10, w8
   88: ubfx w14, w11, #12, #2
   92: strb w14, [x13, x12]
   96: add x12, x12, #0x1
  100: cmp x12, #0x258
  104: b.ne +84
  108: cbz w0, +388
  112: add x12, sp, #0x96c
  116: add x14, sp, #0x8
  120: add x16, sp, #0x1, lsl #12
  124: add x17, sp, #0x1, lsl #12
  128: mov w10, wzr
  132: mov w8, wzr
  136: add x11, x12, #0x8
  140: add x12, x12, #0x4
  144: add x13, x14, #0x4
  148: add x14, x14, #0x8
  152: mov w15, #0x258
  156: add x16, x16, #0x528
  160: add x17, x17, #0x2d0
  164: mov x18, xzr
  168: mov x1, x11
  172: add w2, w18, #0x1
  176: add w3, w18, #0x2
  180: add w4, w18, #0x3
  184: stp w18, w2, [x1, #-0x8]
  188: add x18, x18, #0x4
  192: cmp x18, #0x258
  196: stp w3, w4, [x1], #0x10
  200: b.ne +172
  204: mov w18, #0x1
  208: str w15, [sp, #0x12cc]
  212: add x2, x16, x18
  216: ldr w3, [x9]
  220: mov x1, xzr
  224: ldurb w2, [x2, #-0x1]
  228: mov w4, w18
  232: str w18, [sp, #0x8]
  236: mov w5, w3
  240: ldr w3, [x12, x1, lsl #2]
  244: ldrb w6, [x17, x1]
  248: cmp w3, w4
  252: csel w4, w3, w4, lt
  256: cmp w2, w6
  260: add w6, w4, #0x1
  264: cinc w5, w5, ne
  268: cmp w6, w5
  272: csinc w4, w5, w4, ge
  276: str w4, [x13, x1, lsl #2]
  280: add x1, x1, #0x1
  284: cmp x1, #0x258
  288: b.ne +236
  292: mov x1, x14
  296: mov x2, x11
  300: mov w3, #0x258
  304: ldp w4, w5, [x1, #-0x8]
  308: subs x3, x3, #0x4
  312: stp w4, w5, [x2, #-0x8]
  316: ldp w4, w6, [x1], #0x10
  320: stp w4, w6, [x2], #0x10
  324: b.ne +304
  328: ldr w1, [sp, #0x968]
  332: add x18, x18, #0x1
  336: cmp x18, #0x259
  340: str w1, [sp, #0x12cc]
  344: b.ne +212
  348: ldr w18, [sp, #0x12cc]
  352: add w10, w10, #0x1
  356: cmp w10, w0
  360: add w8, w18, w8
  364: b.ne +164
  368: mov w0, w8
  372: add sp, sp, #0x1, lsl #12
  376: add sp, sp, #0x780
  380: ldr x29, [sp], #0x10
  384: ret
  388: mov w8, wzr
  392: mov w0, w8
  396: add sp, sp, #0x1, lsl #12
  400: add sp, sp, #0x780
  404: ldr x29, [sp], #0x10
  408: ret
```

#### `bench_matrix_multiply` (97 instructions, 388 bytes)
```asm
    0: stp x29, x19, [sp, #-0x10]!
    4: sub sp, sp, #0xc, lsl #12
    8: mov w13, #0xec4f
   12: mov w15, #0xf0f1
   16: mov w8, wzr
   20: mov w9, wzr
   24: mov x10, xzr
   28: add x11, sp, #0x8, lsl #12
   32: add x12, sp, #0x4, lsl #12
   36: movk w13, #0x4ec4, lsl #16
   40: mov w14, #0xd
   44: movk w15, #0xf0f0, lsl #16
   48: mov x16, xzr
   52: mov w17, w8
   56: mov w18, w9
   60: umull x1, w17, w15
   64: umull x2, w18, w13
   68: lsr x1, x1, #36
   72: lsr x2, x2, #34
   76: add w1, w1, w1, lsl #4
   80: msub w2, w2, w14, w18
   84: add w18, w18, #0x2
   88: sub w1, w17, w1
   92: str w1, [x11, x16]
   96: add w17, w17, #0x5
  100: str w2, [x12, x16]
  104: add x16, x16, #0x4
  108: cmp x16, #0x100
  112: b.ne +60
  116: add x10, x10, #0x1
  120: add w9, w9, #0x7
  124: add w8, w8, #0x3
  128: cmp x10, #0x40
  132: add x11, x11, #0x100
  136: add x12, x12, #0x100
  140: b.ne +48
  144: lsl w8, w0, #3
  148: cbz w8, +372
  152: add x11, sp, #0x4, lsl #12
  156: mov w9, wzr
  160: mov w0, wzr
  164: add x10, sp, #0x8, lsl #12
  168: add x11, x11, #0x100
  172: mov x12, sp
  176: mov x13, xzr
  180: add x14, x10, #0x4
  184: add x16, x12, x13, lsl #8
  188: mov x15, xzr
  192: mov x17, x11
  196: mov w18, wzr
  200: mov w1, wzr
  204: mov w2, #0x40
  208: mov x3, x17
  212: mov x4, x14
  216: ldp w5, w7, [x4, #-0x4]
  220: ldur w6, [x3, #-0x100]
  224: ldr w19, [x3]
  228: subs x2, x2, #0x2
  232: add x4, x4, #0x8
  236: add x3, x3, #0x200
  240: madd w18, w6, w5, w18
  244: madd w1, w19, w7, w1
  248: b.ne +216
  252: add w18, w1, w18
  256: str w18, [x16, x15, lsl #2]
  260: add x15, x15, #0x1
  264: cmp x15, #0x40
  268: add x17, x17, #0x4
  272: b.ne +196
  276: add x13, x13, #0x1
  280: add x14, x14, #0x100
  284: cmp x13, #0x40
  288: b.ne +184
  292: mov w13, wzr
  296: mov w14, #0x1000
  300: add x15, x12, #0x4
  304: ldp w16, w17, [x15, #-0x4]
  308: subs x14, x14, #0x2
  312: add x15, x15, #0x8
  316: add w0, w16, w0
  320: add w13, w17, w13
  324: b.ne +304
  328: and w14, w9, #0x3f
  332: add w9, w9, #0x1
  336: add w0, w13, w0
  340: ldr w15, [x10, w14, uxtw #2]
  344: cmp w9, w8
  348: add w13, w15, #0x1
  352: str w13, [x10, w14, uxtw #2]
  356: b.ne +176
  360: add sp, sp, #0xc, lsl #12
  364: ldp x29, x19, [sp], #0x10
  368: ret
  372: mov w0, wzr
  376: add sp, sp, #0xc, lsl #12
  380: ldp x29, x19, [sp], #0x10
  384: ret
```

#### `bench_crc32` (61 instructions, 244 bytes)
```asm
    0: str x29, [sp, #-0x10]!
    4: sub sp, sp, #0x8, lsl #12
    8: sub sp, sp, #0x400
   12: add x9, sp, #0x8, lsl #12
   16: mov x8, xzr
   20: adrp x10, <bench_matrix_multiply+0xd0>
   24: add x10, x10, #0xd28
   28: add x9, x9, #0x8
   32: ldp w12, w13, [x10, #-0x8]
   36: lsr w11, w8, #8
   40: add x8, x8, #0x4
   44: ldp w14, w15, [x10], #0x10
   48: eor w12, w11, w12
   52: eor w13, w11, w13
   56: cmp x8, #0x100
   60: stp w12, w13, [x9, #-0x8]
   64: eor w12, w11, w14
   68: eor w11, w11, w15
   72: stp w12, w11, [x9], #0x10
   76: b.ne +32
   80: mov w10, #0x660d
   84: mov w11, #0xf35f
   88: mov x8, xzr
   92: mov w9, #0x7e8
   96: movk w10, #0x19, lsl #16
  100: movk w11, #0x3c6e, lsl #16
  104: mov x12, sp
  108: madd w9, w9, w10, w11
  112: lsr w13, w9, #24
  116: strb w13, [x12, x8]
  120: add x8, x8, #0x1
  124: cmp x8, #0x8, lsl #12
  128: b.ne +108
  132: lsl w8, w0, #5
  136: cbz w8, +224
  140: mov w10, wzr
  144: mov w9, #-0x1
  148: mov x11, sp
  152: add x12, sp, #0x8, lsl #12
  156: mov x13, xzr
  160: ldrb w14, [x11, x13]
  164: add x13, x13, #0x1
  168: cmp x13, #0x8, lsl #12
  172: eor w14, w14, w9
  176: and x14, x14, #0xff
  180: ldr w14, [x12, x14, lsl #2]
  184: eor w9, w14, w9, lsr #8
  188: b.ne +160
  192: add w10, w10, #0x1
  196: cmp w10, w8
  200: b.ne +156
  204: mvn w0, w9
  208: add sp, sp, #0x8, lsl #12
  212: add sp, sp, #0x400
  216: ldr x29, [sp], #0x10
  220: ret
  224: mov w0, wzr
  228: add sp, sp, #0x8, lsl #12
  232: add sp, sp, #0x400
  236: ldr x29, [sp], #0x10
  240: ret
```

#### `bench_sha256` (151 instructions, 604 bytes)
```asm
    0: mov w8, #0xbb8
    4: mul w8, w0, w8
    8: cbz w8, +592
   12: sub sp, sp, #0x160
   16: mov w10, #0xf35f
   20: mov w11, #0x660d
   24: mov w14, #0xe667
   28: movk w10, #0x3c6e, lsl #16
   32: mov w15, #0xae85
   36: mov w18, #0xf53a
   40: mov w17, #0x527f
   44: mov w16, #0x688c
   48: mov w1, #0xd9ab
   52: mov w0, #0xcd19
   56: mov w9, wzr
   60: movk w11, #0x19, lsl #16
   64: mov x12, sp
   68: mov w3, #0x328
   72: add w13, w10, #0x13
   76: movk w14, #0x6a09, lsl #16
   80: movk w15, #0xbb67, lsl #16
   84: movk w18, #0xa54f, lsl #16
   88: movk w17, #0x510e, lsl #16
   92: movk w16, #0x9b05, lsl #16
   96: movk w1, #0x1f83, lsl #16
  100: movk w0, #0x5be0, lsl #16
  104: nop
  108: adr x2, <K>
  112: stp x29, x30, [sp, #0x100]
  116: stp x28, x27, [sp, #0x110]
  120: stp x26, x25, [sp, #0x120]
  124: stp x24, x23, [sp, #0x130]
  128: stp x22, x21, [sp, #0x140]
  132: stp x20, x19, [sp, #0x150]
  136: madd w4, w3, w11, w10
  140: mov w6, #0x30
  144: madd w3, w4, w11, w10
  148: stp w4, w3, [sp]
  152: madd w3, w3, w11, w10
  156: madd w5, w3, w11, w10
  160: stp w3, w5, [sp, #0x8]
  164: madd w3, w5, w11, w10
  168: madd w5, w3, w11, w10
  172: stp w3, w5, [sp, #0x10]
  176: madd w3, w5, w11, w10
  180: madd w5, w3, w11, w10
  184: stp w3, w5, [sp, #0x18]
  188: madd w3, w5, w11, w10
  192: madd w5, w3, w11, w10
  196: stp w3, w5, [sp, #0x20]
  200: madd w3, w5, w11, w10
  204: madd w5, w3, w11, w10
  208: stp w3, w5, [sp, #0x28]
  212: madd w3, w5, w11, w10
  216: madd w5, w3, w11, w10
  220: stp w3, w5, [sp, #0x30]
  224: madd w5, w5, w11, w10
  228: madd w3, w5, w11, w10
  232: stp w5, w3, [sp, #0x38]
  236: add x5, x12, #0x40
  240: mov w7, w4
  244: ldur w4, [x5, #-0x3c]
  248: ldur w19, [x5, #-0x8]
  252: ldur w22, [x5, #-0x1c]
  256: subs x6, x6, #0x1
  260: ror w20, w4, #0x7
  264: ror w21, w19, #0x11
  268: add w7, w7, w22
  272: eor w20, w20, w4, ror #18
  276: eor w21, w21, w19, ror #19
  280: eor w20, w20, w4, lsr #3
  284: eor w19, w21, w19, lsr #10
  288: add w7, w20, w7
  292: add w7, w7, w19
  296: str w7, [x5], #0x4
  300: b.ne +240
  304: mov x19, xzr
  308: mov w23, w0
  312: mov w25, w1
  316: mov w26, w16
  320: mov w24, w17
  324: mov w22, w18
  328: mov w28, w13
  332: mov w29, w15
  336: mov w27, w14
  340: mov w6, w24
  344: mov w4, w25
  348: mov w21, w27
  352: mov w5, w26
  356: ror w24, w24, #0x6
  360: and w25, w26, w6
  364: bic w26, w4, w6
  368: ror w27, w27, #0x2
  372: mov w7, w28
  376: orr w25, w26, w25
  380: ldr w26, [x2, x19]
  384: eor w24, w24, w6, ror #11
  388: add w23, w23, w25
  392: eor w25, w27, w21, ror #13
  396: ldr w28, [x12, x19]
  400: add w23, w23, w26
  404: eor w26, w7, w29
  408: eor w24, w24, w6, ror #25
  412: eor w25, w25, w21, ror #22
  416: and w26, w26, w21
  420: and w27, w7, w29
  424: add w23, w23, w28
  428: eor w26, w26, w27
  432: add x19, x19, #0x4
  436: add w23, w23, w24
  440: add w25, w26, w25
  444: mov w20, w29
  448: add w24, w23, w22
  452: add w27, w25, w23
  456: cmp x19, #0x100
  460: mov w23, w4
  464: mov w25, w5
  468: mov w26, w6
  472: mov w22, w7
  476: mov w28, w29
  480: mov w29, w21
  484: b.ne +340
  488: add w9, w9, #0x1
  492: add w14, w27, w14
  496: add w15, w21, w15
  500: add w13, w20, w13
  504: add w18, w7, w18
  508: add w17, w24, w17
  512: cmp w9, w8
  516: add w16, w6, w16
  520: add w1, w5, w1
  524: add w0, w4, w0
  528: b.ne +136
  532: eor w8, w13, w18
  536: eor w9, w15, w14
  540: eor w10, w16, w1
  544: eor w8, w8, w17
  548: ldp x20, x19, [sp, #0x150]
  552: ldp x22, x21, [sp, #0x140]
  556: eor w8, w9, w8
  560: ldp x24, x23, [sp, #0x130]
  564: eor w9, w10, w0
  568: ldp x26, x25, [sp, #0x120]
  572: eor w0, w8, w9
  576: ldp x28, x27, [sp, #0x110]
  580: ldp x29, x30, [sp, #0x100]
  584: add sp, sp, #0x160
  588: ret
  592: mov w0, #0x60eb
  596: movk w0, #0xc627, lsl #16
  600: ret
```

#### `bench_popcount` (30 instructions, 120 bytes)
```asm
    0: mov w8, #0x27c0
    4: movk w8, #0x9, lsl #16
    8: mul w8, w0, w8
   12: cbz w8, +112
   16: mov w10, #0x660d
   20: mov w11, #0xf35f
   24: mov w0, wzr
   28: mov w9, #0x37
   32: movk w10, #0x19, lsl #16
   36: movk w11, #0x3c6e, lsl #16
   40: mov w12, #0x1010101
   44: b +56
   48: subs w8, w8, #0x1
   52: b.eq +116
   56: madd w9, w9, w10, w11
   60: cbz w9, +48
   64: lsr w13, w9, #1
   68: and w13, w13, #0x55555555
   72: sub w13, w9, w13
   76: lsr w14, w13, #2
   80: and w13, w13, #0x33333333
   84: and w14, w14, #0x33333333
   88: add w13, w13, w14
   92: add w13, w13, w13, lsr #4
   96: and w13, w13, #0xf0f0f0f
  100: mul w13, w13, w12
  104: add w0, w0, w13, lsr #24
  108: b +48
  112: mov w0, wzr
  116: ret
```

#### `bench_mandelbrot_fixed` (43 instructions, 172 bytes)
```asm
    0: add w8, w0, w0, lsl #1
    4: mov w0, wzr
    8: lsl w8, w8, #1
   12: cbz w8, +168
   16: mov w9, wzr
   20: b +36
   24: add w9, w9, #0x1
   28: cmp w9, w8
   32: b.eq +168
   36: mov w10, wzr
   40: b +56
   44: add w10, w10, #0x1
   48: cmp w10, #0x60
   52: b.eq +24
   56: lsl w12, w10, #11
   60: mov w11, wzr
   64: sub w12, w12, #0x18, lsl #12
   68: b +88
   72: add w11, w11, #0x1
   76: add w0, w13, w0
   80: cmp w11, #0x60
   84: b.eq +44
   88: lsl w14, w11, #11
   92: mov w13, wzr
   96: mov w16, wzr
  100: mov w15, wzr
  104: sub w14, w14, #0x20, lsl #12
  108: smull x17, w15, w15
  112: smull x1, w16, w16
  116: lsr x18, x17, #16
  120: lsr x17, x1, #16
  124: add w1, w17, w18
  128: cmp w1, #0x40, lsl #12
  132: b.gt +72
  136: smull x15, w16, w15
  140: add w13, w13, #0x1
  144: cmp w13, #0x28
  148: add x16, x12, x15, lsr #15
  152: add w15, w14, w18
  156: sub w15, w15, w17
  160: b.ne +108
  164: b +72
  168: ret
```

#### `bench_bytecode_interpreter` (68 instructions, 272 bytes)
```asm
    0: sub sp, sp, #0x10
    4: mov w9, #0x1a80
    8: mov w8, w0
   12: mov w0, #0x4
   16: movk w9, #0x6, lsl #16
   20: mov w10, #0x3
   24: mul w8, w8, w9
   28: stp w10, w0, [sp, #0x8]
   32: mov w10, #0x2
   36: mov w9, #0x1
   40: stp w9, w10, [sp]
   44: cbz w8, +264
   48: mov w12, #0x1
   52: mov w13, #0x10
   56: mov w10, wzr
   60: adrp x11, <bench_matrix_multiply+0xd0>
   64: add x11, x11, #0xca0
   68: movk w12, #0x100, lsl #16
   72: movk w13, #0x1000, lsl #16
   76: mov x14, sp
   80: b +128
   84: ldr w15, [x14, x15, lsl #2]
   88: ldr w16, [x14, x17, lsl #2]
   92: add w15, w16, w15
   96: mov w16, #0x1
  100: cmp w10, #0x7
  104: bfi w16, w10, #2, #30
  108: csinc w10, wzr, w10, eq
  112: subs w8, w8, #0x1
  116: ldr w16, [x11, w16, uxtw #2]
  120: str w15, [x14, x16, lsl #2]
  124: b.eq +244
  128: mov w15, #0x2
  132: mov w17, #0x3
  136: lsl w16, w10, #2
  140: bfi w15, w10, #2, #30
  144: bfi w17, w10, #2, #30
  148: lsr x18, x12, x16
  152: ldr w15, [x11, w15, uxtw #2]
  156: ldr w17, [x11, w17, uxtw #2]
  160: tbnz w18, #0x0, +84
  164: lsl x18, x9, x16
  168: ldr w15, [x14, x15, lsl #2]
  172: tst x18, x13
  176: b.eq +192
  180: ldr w16, [x14, x17, lsl #2]
  184: eor w15, w16, w15
  188: b +96
  192: cmp w16, #0x10
  196: b.eq +236
  200: cmp w16, #0xc
  204: b.eq +228
  208: cmp w16, #0x8
  212: b.ne +96
  216: ldr w16, [x14, x17, lsl #2]
  220: mul w15, w16, w15
  224: b +96
  228: lsl w15, w15, #1
  232: b +96
  236: add w15, w15, w17
  240: b +96
  244: ldp w8, w9, [sp]
  248: ldp w10, w11, [sp, #0x8]
  252: eor w8, w9, w8
  256: eor w9, w10, w11
  260: eor w0, w8, w9
  264: add sp, sp, #0x10
  268: ret
```

#### `bench_pointer_chase` (64 instructions, 256 bytes)
```asm
    0: str x29, [sp, #-0x10]!
    4: sub sp, sp, #0x4, lsl #12
    8: add x8, sp, #0x2, lsl #12
   12: mov x9, xzr
   16: add x10, x8, #0x8
   20: add w11, w9, #0x1
   24: add w12, w9, #0x2
   28: add w13, w9, #0x3
   32: stp w9, w11, [x10, #-0x8]
   36: add x9, x9, #0x4
   40: cmp x9, #0x800
   44: stp w12, w13, [x10], #0x10
   48: b.ne +20
   52: mov w11, #0x660d
   56: mov w12, #0xf35f
   60: mov w9, #0x2329
   64: mov w10, #0x7ff
   68: movk w11, #0x19, lsl #16
   72: movk w12, #0x3c6e, lsl #16
   76: add x13, sp, #0x2, lsl #12
   80: madd w9, w9, w11, w12
   84: add w15, w10, #0x1
   88: lsr w14, w9, #8
   92: udiv w16, w14, w15
   96: msub w14, w16, w15, w14
  100: ldr w16, [x13, x10, lsl #2]
  104: ldr w15, [x13, w14, uxtw #2]
  108: str w15, [x13, x10, lsl #2]
  112: subs x10, x10, #0x1
  116: str w16, [x13, w14, uxtw #2]
  120: b.ne +80
  124: add x9, sp, #0x2, lsl #12
  128: mov w11, #0x4
  132: mov x12, sp
  136: add x10, x9, #0x8
  140: ldp w13, w14, [x10, #-0x8]
  144: and x15, x11, #0x7fc
  148: add x11, x11, #0x4
  152: cmp x11, #0x804
  156: str w14, [x12, x13, lsl #2]
  160: ldp w13, w16, [x10], #0x10
  164: str w13, [x12, x14, lsl #2]
  168: ldr w14, [x9, x15, lsl #2]
  172: str w16, [x12, x13, lsl #2]
  176: str w14, [x12, x16, lsl #2]
  180: b.ne +140
  184: mov w9, #0x9f00
  188: movk w9, #0x24, lsl #16
  192: mul w9, w0, w9
  196: cbz w9, +240
  200: ldr w8, [x8]
  204: mov w0, wzr
  208: mov x10, sp
  212: ldr w8, [x10, w8, uxtw #2]
  216: subs w9, w9, #0x1
  220: add w0, w8, w0
  224: b.ne +212
  228: add sp, sp, #0x4, lsl #12
  232: ldr x29, [sp], #0x10
  236: ret
  240: mov w0, wzr
  244: add sp, sp, #0x4, lsl #12
  248: ldr x29, [sp], #0x10
  252: ret
```

#### `bench_ring_buffer` (47 instructions, 188 bytes)
```asm
    0: mov w8, #0x93e0
    4: movk w8, #0x4, lsl #16
    8: mul w8, w0, w8
   12: cbz w8, +180
   16: str x29, [sp, #-0x10]!
   20: sub sp, sp, #0x1, lsl #12
   24: mov w14, #0x660d
   28: mov w15, #0xf35f
   32: mov w9, wzr
   36: mov w10, wzr
   40: mov w11, wzr
   44: mov w12, wzr
   48: mov w13, #0x141
   52: movk w14, #0x19, lsl #16
   56: movk w15, #0x3c6e, lsl #16
   60: mov x16, sp
   64: b +76
   68: subs w8, w8, #0x1
   72: b.eq +164
   76: madd w13, w13, w14, w15
   80: sub w17, w12, w11
   84: cmp w17, #0x3ff
   88: b.ls +112
   92: ubfx w17, w13, #8, #1
   96: cmp w12, w11
  100: csinc w17, w17, wzr, ne
  104: tbnz w17, #0x0, +68
  108: b +140
  112: and w17, w12, #0x3ff
  116: add w12, w12, #0x1
  120: str w13, [x16, w17, uxtw #2]
  124: ubfx w17, w13, #8, #1
  128: cmp w12, w11
  132: csinc w17, w17, wzr, ne
  136: tbnz w17, #0x0, +68
  140: and w17, w11, #0x3ff
  144: add w11, w11, #0x1
  148: add w9, w9, #0x1
  152: ldr w17, [x16, w17, uxtw #2]
  156: add w10, w17, w10
  160: b +68
  164: eor w0, w9, w10
  168: add sp, sp, #0x1, lsl #12
  172: ldr x29, [sp], #0x10
  176: ret
  180: mov w0, wzr
  184: ret
```

#### `bench_mem_copy` (90 instructions, 360 bytes)
```asm
    0: mov x10, #0x82a0
    4: mov x11, #0xa1f8
    8: mov x12, #0xc150
   12: mov x13, #0xe0a8
   16: movk x10, #0xe94f, lsl #16
   20: movk x11, #0xeefb, lsl #16
   24: movk x12, #0xf4a7, lsl #16
   28: movk x13, #0xfa53, lsl #16
   32: movk x10, #0x372f, lsl #32
   36: movk x11, #0x6963, lsl #32
   40: movk x12, #0x9b97, lsl #32
   44: movk x13, #0xcdcb, lsl #32
   48: mov w14, #0x8
   52: mov x8, xzr
   56: mov x9, xzr
   60: movk x10, #0xc6ef, lsl #48
   64: movk x11, #0xd533, lsl #48
   68: movk x12, #0xe377, lsl #48
   72: movk x13, #0xf1bb, lsl #48
   76: movk w14, #0x4400, lsl #16
   80: mov w15, #0x5555
   84: mov w16, #0x44000000
   88: eor x17, x9, x15
   92: add x4, x14, #0x8
   96: eor x18, x13, x15
  100: orr x3, x8, x14
  104: str x17, [x8, x16]
  108: orr x17, x8, x4
  112: add x4, x14, #0x10
  116: str x18, [x3]
  120: eor x1, x12, x15
  124: orr x18, x8, x4
  128: add x8, x8, #0x20
  132: eor x2, x11, x15
  136: add x11, x11, x10
  140: cmp x8, #0x8, lsl #12
  144: add x12, x12, x10
  148: add x13, x13, x10
  152: add x9, x9, x10
  156: str x1, [x17]
  160: str x2, [x18]
  164: b.ne +88
  168: add w8, w0, w0, lsl #3
  172: lsl w8, w8, #5
  176: cbz w8, +240
  180: mov x9, xzr
  184: mov w10, #0x44000000
  188: mov w11, #0x45000000
  192: mov x12, xzr
  196: add x9, x9, #0x1
  200: lsr x13, x12, #3
  204: ldr x14, [x12, x10]
  208: str x14, [x12, x11]
  212: cmp x13, #0xfff
  216: add x13, x9, x14
  220: str x13, [x12, x10]
  224: add x12, x12, #0x8
  228: b.lo +200
  232: cmp x9, x8
  236: b.ne +192
  240: mov w13, #0x8
  244: mov x9, xzr
  248: mov x8, xzr
  252: mov x10, xzr
  256: mov x11, xzr
  260: mov x12, xzr
  264: movk w13, #0x4500, lsl #16
  268: mov w14, #0x45000000
  272: add x15, x13, #0x8
  276: add x17, x13, #0x10
  280: orr x16, x9, x13
  284: orr x15, x9, x15
  288: orr x17, x9, x17
  292: ldr x18, [x9, x14]
  296: ldr x16, [x16]
  300: ldr x15, [x15]
  304: ldr x17, [x17]
  308: add x9, x9, #0x20
  312: add x8, x18, x8
  316: cmp x9, #0x8, lsl #12
  320: add x10, x16, x10
  324: add x11, x15, x11
  328: add x12, x17, x12
  332: b.ne +272
  336: add x8, x10, x8
  340: add x8, x11, x8
  344: add x8, x12, x8
  348: lsr x9, x8, #32
  352: eor w0, w9, w8
  356: ret
```

#### `bench_atomic_counter` (20 instructions, 80 bytes)
```asm
    0: mov w8, #0xa120
    4: mov w9, #0x44100000
    8: movk w8, #0x7, lsl #16
   12: str wzr, [x9]
   16: mul w8, w0, w8
   20: cbz w8, +68
   24: mov w9, wzr
   28: mov w10, #0x44100000
   32: and w11, w9, #0x3
   36: add w11, w11, #0x1
   40: ldaxr w12, [x10]
   44: add w12, w12, w11
   48: stlxr w13, w12, [x10]
   52: cbnz w13, +40
   56: add w9, w9, #0x1
   60: cmp w9, w8
   64: b.ne +32
   68: mov w8, #0x44100000
   72: ldar w0, [x8]
   76: ret
```

#### `bench_spinlock` (28 instructions, 112 bytes)
```asm
    0: mov w8, #0x3500
    4: movk w8, #0xc, lsl #16
    8: mul w9, w0, w8
   12: mov w8, #0x10
   16: movk w8, #0x4410, lsl #16
   20: str wzr, [x8]
   24: str wzr, [x8, #0x10]
   28: cbz w9, +104
   32: mov w10, wzr
   36: mov w11, #0x1
   40: ldaxr w12, [x8]
   44: cbnz w12, +88
   48: stlxr w12, w11, [x8]
   52: cbnz w12, +40
   56: ldr w12, [x8, #0x10]
   60: add w10, w10, #0x1
   64: cmp w10, w9
   68: add w12, w12, #0x1
   72: str w12, [x8, #0x10]
   76: stlr wzr, [x8]
   80: b.ne +40
   84: b +96
   88: clrex
   92: b +40
   96: ldr w0, [x8, #0x10]
  100: ret
  104: mov w0, wzr
  108: ret
```

#### `bench_volatile_registers` (97 instructions, 388 bytes)
```asm
    0: mov w9, #0x44200000
    4: mov w8, #0x4
    8: str wzr, [x9]
   12: mov w9, #0xbba0
   16: movk w8, #0x4420, lsl #16
   20: movk w9, #0xd, lsl #16
   24: str wzr, [x8]
   28: mul w9, w0, w9
   32: str wzr, [x8, #0x4]
   36: str wzr, [x8, #0x8]
   40: str wzr, [x8, #0xc]
   44: str wzr, [x8, #0x10]
   48: str wzr, [x8, #0x14]
   52: str wzr, [x8, #0x18]
   56: str wzr, [x8, #0x1c]
   60: str wzr, [x8, #0x20]
   64: str wzr, [x8, #0x24]
   68: str wzr, [x8, #0x28]
   72: str wzr, [x8, #0x2c]
   76: str wzr, [x8, #0x30]
   80: str wzr, [x8, #0x34]
   84: str wzr, [x8, #0x38]
   88: str wzr, [x8, #0x3c]
   92: str wzr, [x8, #0x40]
   96: str wzr, [x8, #0x44]
  100: str wzr, [x8, #0x48]
  104: str wzr, [x8, #0x4c]
  108: str wzr, [x8, #0x50]
  112: str wzr, [x8, #0x54]
  116: str wzr, [x8, #0x58]
  120: str wzr, [x8, #0x5c]
  124: str wzr, [x8, #0x60]
  128: str wzr, [x8, #0x64]
  132: str wzr, [x8, #0x68]
  136: str wzr, [x8, #0x6c]
  140: str wzr, [x8, #0x70]
  144: str wzr, [x8, #0x74]
  148: str wzr, [x8, #0x78]
  152: str wzr, [x8, #0x7c]
  156: str wzr, [x8, #0x80]
  160: str wzr, [x8, #0x84]
  164: str wzr, [x8, #0x88]
  168: str wzr, [x8, #0x8c]
  172: str wzr, [x8, #0x90]
  176: str wzr, [x8, #0x94]
  180: str wzr, [x8, #0x98]
  184: str wzr, [x8, #0x9c]
  188: str wzr, [x8, #0xa0]
  192: str wzr, [x8, #0xa4]
  196: str wzr, [x8, #0xa8]
  200: str wzr, [x8, #0xac]
  204: str wzr, [x8, #0xb0]
  208: str wzr, [x8, #0xb4]
  212: str wzr, [x8, #0xb8]
  216: str wzr, [x8, #0xbc]
  220: str wzr, [x8, #0xc0]
  224: str wzr, [x8, #0xc4]
  228: str wzr, [x8, #0xc8]
  232: str wzr, [x8, #0xcc]
  236: str wzr, [x8, #0xd0]
  240: str wzr, [x8, #0xd4]
  244: str wzr, [x8, #0xd8]
  248: str wzr, [x8, #0xdc]
  252: str wzr, [x8, #0xe0]
  256: str wzr, [x8, #0xe4]
  260: str wzr, [x8, #0xe8]
  264: str wzr, [x8, #0xec]
  268: str wzr, [x8, #0xf0]
  272: str wzr, [x8, #0xf4]
  276: str wzr, [x8, #0xf8]
  280: cbz w9, +344
  284: mov w10, wzr
  288: mov w8, wzr
  292: mov w11, wzr
  296: mov w12, #0x44200000
  300: and w13, w10, #0xfc
  304: add w10, w10, #0x1c
  308: orr x13, x13, x12
  312: ldr w14, [x13]
  316: add w15, w11, w14
  320: add w11, w11, #0x1
  324: add w8, w14, w8
  328: cmp w9, w11
  332: str w15, [x13]
  336: b.ne +300
  340: b +348
  344: mov w8, wzr
  348: mov w9, wzr
  352: mov w10, #0x44200000
  356: mov w11, #0x40
  360: ldr w12, [x10]
  364: subs x11, x11, #0x1
  368: add x10, x10, #0x4
  372: add w9, w12, w9
  376: b.ne +360
  380: eor w0, w9, w8
  384: ret
```

### D.2 Prismio, partial unrolling off

#### `fib__U32` (20 instructions, 80 bytes)
```asm
    0: str x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: mov w19, w0
   12: cmp w0, #0x2
   16: b.hs +36
   20: add w0, w19, wzr
   24: ldp x20, x19, [sp, #0x10]
   28: ldr x30, [sp], #0x20
   32: ret
   36: mov w20, wzr
   40: sub w0, w19, #0x1
   44: bl +0
   48: sub w19, w19, #0x2
   52: add w20, w0, w20
   56: cmp w19, #0x2
   60: b.hs +40
   64: add w0, w19, w20
   68: ldp x20, x19, [sp, #0x10]
   72: ldr x30, [sp], #0x20
   76: ret
```

#### `bench_fibonacci__U32` (8 instructions, 32 bytes)
```asm
    0: cbz w0, +28
    4: stp x30, x19, [sp, #-0x10]!
    8: mov w19, w0
   12: mov w0, #0x1b
   16: bl <fib__U32>
   20: mul w0, w0, w19
   24: ldp x30, x19, [sp], #0x10
   28: ret
```

#### `bench_prime_sieve__U32` (103 instructions, 412 bytes)
```asm
    0: str x29, [sp, #-0x50]!
    4: stp x30, x25, [sp, #0x10]
    8: stp x24, x23, [sp, #0x20]
   12: stp x22, x21, [sp, #0x30]
   16: stp x20, x19, [sp, #0x40]
   20: sub sp, sp, #0x30, lsl #12
   24: sub sp, sp, #0xd40
   28: cbz w0, +372
   32: mov w22, #0xd40
   36: mov w24, #0xd3a
   40: mov w20, w0
   44: mov w19, wzr
   48: mov w21, wzr
   52: movk w22, #0x3, lsl #16
   56: mov x23, sp
   60: movk w24, #0x3, lsl #16
   64: mov w25, #0x1
   68: b +88
   72: add w21, w21, #0x1
   76: add w19, w8, w19
   80: cmp w21, w20
   84: b.eq +376
   88: mov w2, #0xd40
   92: mov x0, sp
   96: mov w1, wzr
  100: movk w2, #0x3, lsl #16
  104: bl <memset>
  108: mov x9, xzr
  112: mov x10, xzr
  116: mov x11, xzr
  120: mov w8, wzr
  124: mov w12, #0x6
  128: mov w13, #0x8
  132: mov w14, #0xa
  136: mov w15, #0x2
  140: mov w16, #0x4
  144: b +188
  148: add x15, x15, #0x1
  152: add x16, x16, #0x2
  156: add x11, x11, #0x1
  160: add x10, x10, #0x3
  164: sub x9, x9, #0x3
  168: cmp x15, x22
  172: add x14, x14, #0x5
  176: add x13, x13, #0x4
  180: add x12, x12, #0x3
  184: b.eq +72
  188: add x17, x11, x11, lsl #1
  192: cmp x10, x24
  196: sub x18, x11, x11, lsl #2
  200: csel x0, x10, x24, hi
  204: ldrb w2, [x23, x15]
  208: cmp x17, x24
  212: csel x17, x17, x24, hi
  216: adds x17, x17, x18
  220: cset w18, ne
  224: csetm x1, ne
  228: cbnz w2, +148
  232: lsr x2, x15, #5
  236: add w8, w8, #0x1
  240: cmp x2, #0xc34
  244: b.hi +148
  248: sub x18, x17, x18
  252: cmp x17, #0x0
  256: mov x17, x16
  260: udiv x18, x18, x15
  264: cinc x2, x25, ne
  268: add x18, x2, x18
  272: cmp x18, #0x4
  276: b.lo +352
  280: add x17, x0, x9
  284: and x0, x18, #0xfffffffffffffffc
  288: add x17, x17, x1
  292: udiv x1, x17, x15
  296: madd x17, x0, x15, x16
  300: add x1, x2, x1
  304: mov x2, sp
  308: and x1, x1, #0xfffffffffffffffc
  312: add x3, x2, x13
  316: strb w25, [x2, x16]
  320: subs x1, x1, #0x4
  324: strb w25, [x2, x12]
  328: strb w25, [x3]
  332: strb w25, [x2, x14]
  336: mov x2, x3
  340: b.ne +312
  344: cmp x18, x0
  348: b.eq +148
  352: strb w25, [x23, x17]
  356: add x17, x17, x15
  360: cmp x17, x22
  364: b.lo +352
  368: b +148
  372: mov w19, wzr
  376: mov w0, w19
  380: add sp, sp, #0x30, lsl #12
  384: add sp, sp, #0xd40
  388: ldp x20, x19, [sp, #0x40]
  392: ldp x22, x21, [sp, #0x30]
  396: ldp x24, x23, [sp, #0x20]
  400: ldp x30, x25, [sp, #0x10]
  404: ldr x29, [sp], #0x50
  408: ret
```

#### `bench_gcd_lcm__U32` (24 instructions, 96 bytes)
```asm
    0: mov w8, wzr
    4: cbz w0, +88
    8: mov w9, wzr
   12: mov w10, #0x1
   16: mov w11, #0x1
   20: mov w13, w10
   24: mov w14, w11
   28: mov w12, w14
   32: udiv w14, w13, w14
   36: msub w14, w14, w12, w13
   40: mov w13, w12
   44: cbnz w14, +28
   48: add w11, w11, #0x1
   52: add w8, w12, w8
   56: cmp w11, #0x191
   60: b.ne +20
   64: add w10, w10, #0x1
   68: cmp w10, #0x191
   72: b.ne +16
   76: add w9, w9, #0x1
   80: cmp w9, w0
   84: b.ne +12
   88: mov w0, w8
   92: ret
```

#### `bench_binary_search__U32` (73 instructions, 292 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x4, lsl #12
   12: mov w19, w0
   16: mov x0, sp
   20: mov w1, wzr
   24: mov w2, #0x4000
   28: mov x20, sp
   32: bl <memset>
   36: mov x8, xzr
   40: add x9, x20, #0x8
   44: add w10, w8, #0x3
   48: add w11, w8, #0xa
   52: add w12, w8, #0x11
   56: stp w10, w11, [x9, #-0x8]
   60: add w10, w8, #0x18
   64: add x8, x8, #0x1c
   68: cmp x8, #0x7, lsl #12
   72: stp w12, w10, [x9], #0x10
   76: b.ne +44
   80: mov w8, #0x86a0
   84: movk w8, #0x1, lsl #16
   88: mul w8, w19, w8
   92: cbz w8, +272
   96: mov w13, #0x660d
  100: mov w14, #0xf35f
  104: mov w15, #0xb273
  108: mov w9, wzr
  112: mov w11, wzr
  116: mov w10, wzr
  120: mov w12, #0x3039
  124: movk w13, #0x19, lsl #16
  128: movk w14, #0x3c6e, lsl #16
  132: movk w15, #0x45e7, lsl #16
  136: mov w16, #0x7530
  140: mov x17, sp
  144: b +160
  148: add w11, w11, #0x1
  152: cmp w11, w8
  156: b.eq +248
  160: madd w12, w12, w13, w14
  164: mov w18, wzr
  168: mov w1, #0x1000
  172: umull x0, w12, w15
  176: lsr x0, x0, #45
  180: msub w0, w0, w16, w12
  184: add w2, w1, w18
  188: lsr w2, w2, #1
  192: ldr w3, [x17, w2, uxtw #2]
  196: cmp w3, w0
  200: csinc w18, w18, w2, hs
  204: csel w1, w2, w1, hs
  208: cmp w18, w1
  212: b.lo +184
  216: cmp w18, #0xfff
  220: b.hi +148
  224: ldr w1, [x17, w18, uxtw #2]
  228: cmp w1, w0
  232: b.ne +148
  236: add w9, w9, #0x1
  240: add w10, w18, w10
  244: b +148
  248: add w8, w10, w10, lsl #1
  252: add w0, w9, w8
  256: add sp, sp, #0x4, lsl #12
  260: ldp x20, x19, [sp, #0x10]
  264: ldp x29, x30, [sp], #0x20
  268: ret
  272: mov w0, wzr
  276: add sp, sp, #0x4, lsl #12
  280: ldp x20, x19, [sp, #0x10]
  284: ldp x29, x30, [sp], #0x20
  288: ret
```

#### `quick__Array_U32_Int_Int` (46 instructions, 184 bytes)
```asm
    0: cmp w1, w2
    4: b.ge +180
    8: stp x30, x21, [sp, #-0x20]!
   12: stp x20, x19, [sp, #0x10]
   16: mov w19, w2
   20: mov x20, x0
   24: b +48
   28: mov x0, x20
   32: bl +0
   36: cmp w21, w19
   40: mov w1, w21
   44: b.ge +172
   48: add w8, w1, w19
   52: mov w21, w1
   56: mov w2, w19
   60: asr w8, w8, #1
   64: ldr w8, [x20, w8, sxtw #2]
   68: b +92
   72: add x12, x20, x2, lsl #2
   76: stur w11, [x10, #-0x4]
   80: str w9, [x12, #0x4]
   84: cmp w21, w2
   88: b.gt +28
   92: sxtw x21, w21
   96: ldr w9, [x20, x21, lsl #2]
  100: add x21, x21, #0x1
  104: cmp w9, w8
  108: b.lo +96
  112: add x10, x20, x21, lsl #2
  116: sub x12, x21, #0x1
  120: sxtw x2, w2
  124: ldr w11, [x20, x2, lsl #2]
  128: sub x2, x2, #0x1
  132: cmp w11, w8
  136: b.hi +124
  140: add x13, x2, #0x1
  144: cmp x12, x13
  148: b.le +72
  152: sub w21, w21, #0x1
  156: add w2, w2, #0x1
  160: cmp w21, w2
  164: b.le +92
  168: b +28
  172: ldp x20, x19, [sp, #0x10]
  176: ldp x30, x21, [sp], #0x20
  180: ret
```

#### `bench_quicksort__U32` (56 instructions, 224 bytes)
```asm
    0: str x29, [sp, #-0x50]!
    4: stp x30, x25, [sp, #0x10]
    8: stp x24, x23, [sp, #0x20]
   12: stp x22, x21, [sp, #0x30]
   16: stp x20, x19, [sp, #0x40]
   20: sub sp, sp, #0x2, lsl #12
   24: mov w19, w0
   28: mov x0, sp
   32: mov w1, wzr
   36: mov w2, #0x2000
   40: mov x20, sp
   44: bl <memset>
   48: add w8, w19, w19, lsl #2
   52: mov w19, wzr
   56: lsl w21, w8, #3
   60: cbz w21, +192
   64: mov w24, #0x660d
   68: mov w25, #0xf35f
   72: mov w22, wzr
   76: mov w23, #0x309
   80: movk w24, #0x19, lsl #16
   84: movk w25, #0x3c6e, lsl #16
   88: mov x8, xzr
   92: madd w23, w23, w24, w25
   96: lsr w9, w23, #4
  100: str w9, [x20, x8]
  104: add x8, x8, #0x4
  108: cmp x8, #0x2, lsl #12
  112: b.ne +92
  116: mov x0, sp
  120: mov w1, wzr
  124: mov w2, #0x7ff
  128: bl <quick__Array_U32_Int_Int>
  132: mov w8, wzr
  136: mov x9, #-0x800
  140: add x10, x20, #0x4
  144: ldp w11, w12, [x10, #-0x4]
  148: add w13, w9, #0x801
  152: add w14, w9, #0x802
  156: adds x9, x9, #0x2
  160: add x10, x10, #0x8
  164: madd w19, w11, w13, w19
  168: madd w8, w12, w14, w8
  172: b.ne +144
  176: add w22, w22, #0x1
  180: add w19, w8, w19
  184: cmp w22, w21
  188: b.ne +88
  192: mov w0, w19
  196: add sp, sp, #0x2, lsl #12
  200: ldp x20, x19, [sp, #0x40]
  204: ldp x22, x21, [sp, #0x30]
  208: ldp x24, x23, [sp, #0x20]
  212: ldp x30, x25, [sp, #0x10]
  216: ldr x29, [sp], #0x50
  220: ret
```

#### `bench_heapsort__U32` (123 instructions, 492 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x2, lsl #12
   12: mov w19, w0
   16: mov x0, sp
   20: mov w1, wzr
   24: mov w2, #0x2000
   28: mov x20, sp
   32: bl <memset>
   36: add w8, w19, w19, lsl #1
   40: mov w0, wzr
   44: lsl w8, w8, #3
   48: cbz w8, +476
   52: mov w11, #0x660d
   56: mov w12, #0xf35f
   60: mov w9, wzr
   64: mov w10, #0x1092
   68: movk w11, #0x19, lsl #16
   72: movk w12, #0x3c6e, lsl #16
   76: mov x13, xzr
   80: madd w10, w10, w11, w12
   84: lsr w14, w10, #4
   88: str w14, [x20, x13]
   92: add x13, x13, #0x4
   96: cmp x13, #0x2, lsl #12
  100: b.ne +80
  104: mov w14, #0x3ff
  108: b +120
  112: sub x14, x13, #0x1
  116: cbz x13, +248
  120: mov x13, x14
  124: ldr w14, [x20, x14, lsl #2]
  128: lsl w17, w13, #1
  132: mov w15, w13
  136: sxtw x17, w17
  140: orr x16, x17, #0x1
  144: ldr w18, [x20, x16, lsl #2]
  148: cmp w14, w18
  152: b.hs +176
  156: cmp w17, #0x7fd
  160: b.le +188
  164: cmp w16, w15
  168: b.ne +216
  172: b +112
  176: mov w16, w15
  180: cmp w17, #0x7fd
  184: b.gt +164
  188: add x17, x17, #0x2
  192: ldr w18, [x20, w16, sxtw #2]
  196: ldr w1, [x20, x17, lsl #2]
  200: cmp w18, w1
  204: csel w16, w17, w16, lo
  208: cmp w16, w15
  212: b.eq +112
  216: lsl w17, w16, #1
  220: ldr w18, [x20, w16, sxtw #2]
  224: str w18, [x20, w15, sxtw #2]
  228: mov w15, w16
  232: cmp w17, #0x7ff
  236: str w14, [x20, w16, sxtw #2]
  240: b.lt +136
  244: b +112
  248: mov w13, #0x7ff
  252: b +264
  256: mov x13, x15
  260: cbz x15, +416
  264: ldr w14, [x20, x13, lsl #2]
  268: ldr w15, [sp]
  272: cmp x13, #0x2
  276: str w15, [x20, x13, lsl #2]
  280: str w14, [sp]
  284: b.lo +416
  288: mov w18, wzr
  292: mov w16, wzr
  296: sub x15, x13, #0x1
  300: sxtw x18, w18
  304: orr x17, x18, #0x1
  308: ldr w1, [x20, x17, lsl #2]
  312: cmp w14, w1
  316: b.hs +344
  320: add x18, x18, #0x2
  324: cmp x13, x18
  328: b.gt +360
  332: cmp w17, w16
  336: b.ne +384
  340: b +256
  344: mov w17, w16
  348: add x18, x18, #0x2
  352: cmp x13, x18
  356: b.le +332
  360: ldr w1, [x20, w17, sxtw #2]
  364: ldr w2, [x20, x18, lsl #2]
  368: cmp w1, w2
  372: csel w17, w18, w17, lo
  376: cmp w17, w16
  380: b.eq +256
  384: lsl w18, w17, #1
  388: ldr w1, [x20, w17, sxtw #2]
  392: str w1, [x20, w16, sxtw #2]
  396: mov w16, w17
  400: cmp x15, w18, sxtw
  404: str w14, [x20, w17, sxtw #2]
  408: b.gt +300
  412: b +256
  416: mov w13, wzr
  420: mov x14, #-0x800
  424: add x15, x20, #0x4
  428: ldp w16, w17, [x15, #-0x4]
  432: add w18, w14, #0x801
  436: add w1, w14, #0x802
  440: adds x14, x14, #0x2
  444: add x15, x15, #0x8
  448: madd w0, w16, w18, w0
  452: madd w13, w17, w1, w13
  456: b.ne +428
  460: add w9, w9, #0x1
  464: add w0, w13, w0
  468: cmp w9, w8
  472: b.ne +76
  476: add sp, sp, #0x2, lsl #12
  480: ldp x20, x19, [sp, #0x10]
  484: ldp x29, x30, [sp], #0x20
  488: ret
```

#### `bench_knapsack__U32` (144 instructions, 576 bytes)
```asm
    0: str x29, [sp, #-0x60]!
    4: stp x30, x27, [sp, #0x10]
    8: stp x26, x25, [sp, #0x20]
   12: stp x24, x23, [sp, #0x30]
   16: stp x22, x21, [sp, #0x40]
   20: stp x20, x19, [sp, #0x50]
   24: sub sp, sp, #0x1, lsl #12
   28: sub sp, sp, #0x980
   32: mov w19, w0
   36: add x0, sp, #0x1, lsl #12
   40: mov w20, #0xf35f
   44: mov w21, #0x660d
   48: add x0, x0, #0x880
   52: mov w1, wzr
   56: mov w2, #0x100
   60: add x22, sp, #0x1, lsl #12
   64: movk w20, #0x3c6e, lsl #16
   68: movk w21, #0x19, lsl #16
   72: add x22, x22, #0x880
   76: bl <memset>
   80: add x0, sp, #0x1, lsl #12
   84: mov w1, wzr
   88: mov w2, #0x100
   92: add x0, x0, #0x780
   96: add x23, sp, #0x1, lsl #12
  100: add x23, x23, #0x780
  104: bl <memset>
  108: mov w9, #0x3e46
  112: mov w11, #0xa0fe
  116: mov x8, xzr
  120: mov w13, #0x63
  124: movk w9, #0x6eb, lsl #16
  128: mov w10, #0x25
  132: movk w11, #0x2a3, lsl #16
  136: mov w12, #0x61
  140: madd w14, w13, w21, w20
  144: madd w13, w14, w21, w20
  148: lsr w14, w14, #8
  152: umull x16, w14, w9
  156: lsr w15, w13, #8
  160: umull x17, w15, w11
  164: lsr x16, x16, #32
  168: msub w14, w16, w10, w14
  172: lsr x17, x17, #32
  176: msub w15, w17, w12, w15
  180: add w14, w14, #0x3
  184: str w14, [x22, x8]
  188: add w14, w15, #0x1
  192: str w14, [x23, x8]
  196: add x8, x8, #0x4
  200: cmp x8, #0x100
  204: b.ne +140
  208: add w8, w19, w19, lsl #1
  212: mov w19, wzr
  216: lsl w20, w8, #1
  220: cbz w20, +532
  224: mov w8, #0x1770
  228: add x22, sp, #0xc
  232: add x23, sp, #0x1, lsl #12
  236: add x25, sp, #0x1, lsl #12
  240: mov w21, wzr
  244: add x23, x23, #0x880
  248: add x24, x22, x8
  252: add x25, x25, #0x780
  256: mov w26, #0x5dd
  260: mov w27, #0x5dc
  264: b +288
  268: ldr w8, [sp, #0x177c]
  272: add w21, w21, #0x1
  276: cmp w21, w20
  280: add w19, w8, w19
  284: b.eq +532
  288: add x0, sp, #0xc
  292: mov w1, wzr
  296: mov w2, #0x1774
  300: bl <memset>
  304: mov x8, xzr
  308: b +324
  312: add x8, x8, #0x1
  316: cmp x8, #0x40
  320: b.eq +268
  324: ldr w9, [x23, x8, lsl #2]
  328: tbnz w9, #0x1f, +572
  332: cmp w9, #0x5dc
  336: b.hi +312
  340: sub x12, x26, x9
  344: ldr w10, [x25, x8, lsl #2]
  348: cmp x12, #0x4
  352: b.hs +364
  356: mov w11, #0x5dc
  360: b +480
  364: and x13, x12, #0xfffffffffffffffc
  368: neg x14, x9, lsl #2
  372: and x15, x12, #0xfffffffffffffffc
  376: sub x11, x27, x13
  380: mov x16, x24
  384: add x17, x16, x14
  388: ldp w2, w1, [x17, #-0x4]
  392: ldp w0, w18, [x16, #-0x4]
  396: ldp w17, w3, [x17, #-0xc]
  400: ldp w5, w4, [x16, #-0xc]
  404: add w1, w1, w10
  408: add w2, w2, w10
  412: cmp w18, w1
  416: add w3, w3, w10
  420: add w17, w17, w10
  424: csel w18, w18, w1, gt
  428: cmp w0, w2
  432: csel w0, w0, w2, gt
  436: cmp w4, w3
  440: stp w0, w18, [x16, #-0x4]
  444: csel w18, w4, w3, gt
  448: cmp w5, w17
  452: csel w17, w5, w17, gt
  456: subs x15, x15, #0x4
  460: stp w17, w18, [x16, #-0xc]
  464: sub x16, x16, #0x10
  468: b.ne +384
  472: cmp x12, x13
  476: b.eq +312
  480: neg x12, x9, lsl #2
  484: add x13, x22, x11, lsl #2
  488: add x11, x11, #0x1
  492: ldr w14, [x13, x12]
  496: ldr w15, [x13]
  500: sub x11, x11, #0x1
  504: add w14, w14, w10
  508: cmp w15, w14
  512: csel w14, w15, w14, gt
  516: cmp x11, x9
  520: str w14, [x13], #-0x4
  524: b.hi +492
  528: b +312
  532: mov w0, w19
  536: add sp, sp, #0x1, lsl #12
  540: add sp, sp, #0x980
  544: ldp x20, x19, [sp, #0x50]
  548: ldp x22, x21, [sp, #0x40]
  552: ldp x24, x23, [sp, #0x30]
  556: ldp x26, x25, [sp, #0x20]
  560: ldp x30, x27, [sp, #0x10]
  564: ldr x29, [sp], #0x60
  568: ret
  572: bl <array_index_fail>
```

#### `bench_edit_distance__U32` (115 instructions, 460 bytes)
```asm
    0: str x29, [sp, #-0x60]!
    4: stp x30, x27, [sp, #0x10]
    8: stp x26, x25, [sp, #0x20]
   12: stp x24, x23, [sp, #0x30]
   16: stp x22, x21, [sp, #0x40]
   20: stp x20, x19, [sp, #0x50]
   24: sub sp, sp, #0x1, lsl #12
   28: sub sp, sp, #0x780
   32: mov w19, w0
   36: add x0, sp, #0x1, lsl #12
   40: mov w20, #0xf35f
   44: mov w22, #0x660d
   48: add x0, x0, #0x528
   52: mov w1, wzr
   56: mov w2, #0x258
   60: add x23, sp, #0x1, lsl #12
   64: movk w20, #0x3c6e, lsl #16
   68: movk w22, #0x19, lsl #16
   72: add x23, x23, #0x528
   76: bl <memset>
   80: add x0, sp, #0x1, lsl #12
   84: mov w1, wzr
   88: mov w2, #0x258
   92: add x0, x0, #0x2d0
   96: add x21, sp, #0x96c
  100: bl <memset>
  104: mov x9, xzr
  108: mov w8, #0x7a69
  112: madd w8, w8, w22, w20
  116: ubfx w10, w8, #12, #2
  120: strb w10, [x23, x9]
  124: add x9, x9, #0x1
  128: cmp x9, #0x258
  132: b.ne +112
  136: add x10, sp, #0x1, lsl #12
  140: mov x9, xzr
  144: add x10, x10, #0x2d0
  148: madd w8, w8, w22, w20
  152: ubfx w11, w8, #12, #2
  156: strb w11, [x10, x9]
  160: add x9, x9, #0x1
  164: cmp x9, #0x258
  168: b.ne +148
  172: mov w20, wzr
  176: cbz w19, +420
  180: add x26, sp, #0x1, lsl #12
  184: mov w22, wzr
  188: add x23, sp, #0x8
  192: add x24, sp, #0x96c
  196: mov w25, #0x258
  200: add x26, x26, #0x528
  204: add x0, sp, #0x96c
  208: mov w1, wzr
  212: mov w2, #0x964
  216: bl <memset>
  220: add x0, x23, #0x4
  224: mov w1, wzr
  228: mov w2, #0x960
  232: bl <memset>
  236: mov x8, xzr
  240: add x9, x24, #0x8
  244: add w10, w8, #0x1
  248: add w11, w8, #0x2
  252: add w12, w8, #0x3
  256: stp w8, w10, [x9, #-0x8]
  260: add x8, x8, #0x4
  264: cmp x8, #0x258
  268: stp w11, w12, [x9], #0x10
  272: b.ne +244
  276: mov w27, #0x1
  280: str w25, [sp, #0x12cc]
  284: add x8, x26, x27
  288: ldr w11, [x21]
  292: add x9, sp, #0x1, lsl #12
  296: ldurb w8, [x8, #-0x1]
  300: add x9, x9, #0x2d0
  304: mov w10, #0x4
  308: mov w12, w27
  312: str w27, [sp, #0x8]
  316: mov w13, w11
  320: ldr w11, [x24, x10]
  324: ldrb w14, [x9], #0x1
  328: cmp w11, w12
  332: csel w12, w11, w12, lt
  336: cmp w8, w14
  340: add w14, w12, #0x1
  344: cinc w13, w13, ne
  348: cmp w14, w13
  352: csinc w12, w13, w12, ge
  356: str w12, [x23, x10]
  360: add x10, x10, #0x4
  364: cmp x10, #0x964
  368: b.ne +316
  372: add x0, sp, #0x96c
  376: add x1, sp, #0x8
  380: mov w2, #0x964
  384: bl <memcpy>
  388: add x27, x27, #0x1
  392: cmp x27, #0x259
  396: b.ne +284
  400: ldr w8, [sp, #0x12cc]
  404: add w22, w22, #0x1
  408: cmp w22, w19
  412: add w20, w8, w20
  416: b.ne +204
  420: mov w0, w20
  424: add sp, sp, #0x1, lsl #12
  428: add sp, sp, #0x780
  432: ldp x20, x19, [sp, #0x50]
  436: ldp x22, x21, [sp, #0x40]
  440: ldp x24, x23, [sp, #0x30]
  444: ldp x26, x25, [sp, #0x20]
  448: ldp x30, x27, [sp, #0x10]
  452: ldr x29, [sp], #0x60
  456: ret
```

#### `bench_matrix_multiply__U32` (183 instructions, 732 bytes)
```asm
    0: stp x29, x30, [sp, #-0x30]!
    4: stp x22, x21, [sp, #0x10]
    8: stp x20, x19, [sp, #0x20]
   12: sub sp, sp, #0xc, lsl #12
   16: mov w19, w0
   20: add x0, sp, #0x8, lsl #12
   24: mov w1, wzr
   28: mov w2, #0x4000
   32: add x21, sp, #0x8, lsl #12
   36: add x20, sp, #0x8, lsl #12
   40: bl <memset>
   44: add x0, sp, #0x4, lsl #12
   48: mov w1, wzr
   52: mov w2, #0x4000
   56: add x22, sp, #0x4, lsl #12
   60: bl <memset>
   64: mov x0, sp
   68: mov w1, wzr
   72: mov w2, #0x4000
   76: bl <memset>
   80: mov w11, #0xec4f
   84: mov w13, #0xf0f1
   88: mov w8, wzr
   92: mov w9, wzr
   96: mov x10, xzr
  100: movk w11, #0x4ec4, lsl #16
  104: mov w12, #0xd
  108: movk w13, #0xf0f0, lsl #16
  112: mov x14, xzr
  116: mov w15, w8
  120: mov w16, w9
  124: umull x17, w15, w13
  128: umull x18, w16, w11
  132: lsr x17, x17, #36
  136: lsr x18, x18, #34
  140: add w17, w17, w17, lsl #4
  144: msub w18, w18, w12, w16
  148: add w16, w16, #0x2
  152: sub w17, w15, w17
  156: str w17, [x21, x14]
  160: add w15, w15, #0x5
  164: str w18, [x22, x14]
  168: add x14, x14, #0x4
  172: cmp x14, #0x100
  176: b.ne +124
  180: add x10, x10, #0x1
  184: add w9, w9, #0x7
  188: add w8, w8, #0x3
  192: cmp x10, #0x40
  196: add x21, x21, #0x100
  200: add x22, x22, #0x100
  204: b.ne +112
  208: lsl w8, w19, #3
  212: tbnz w8, #0x1f, +448
  216: mov w0, wzr
  220: cbz w8, +428
  224: add x11, sp, #0x4, lsl #12
  228: mov w9, wzr
  232: add x10, sp, #0x8, lsl #12
  236: add x11, x11, #0x100
  240: mov x12, sp
  244: mov x13, xzr
  248: add x14, x10, #0x4
  252: add x16, x12, x13, lsl #8
  256: mov x15, xzr
  260: mov x17, x11
  264: mov w18, wzr
  268: mov w1, wzr
  272: mov w2, #0x40
  276: mov x3, x17
  280: mov x4, x14
  284: ldp w5, w7, [x4, #-0x4]
  288: ldur w6, [x3, #-0x100]
  292: ldr w19, [x3]
  296: subs x2, x2, #0x2
  300: add x4, x4, #0x8
  304: add x3, x3, #0x200
  308: madd w18, w6, w5, w18
  312: madd w1, w19, w7, w1
  316: b.ne +284
  320: add w18, w1, w18
  324: str w18, [x16, x15, lsl #2]
  328: add x15, x15, #0x1
  332: cmp x15, #0x40
  336: add x17, x17, #0x4
  340: b.ne +264
  344: add x13, x13, #0x1
  348: add x14, x14, #0x100
  352: cmp x13, #0x40
  356: b.ne +252
  360: mov w13, wzr
  364: mov w14, #0x1000
  368: add x15, x12, #0x4
  372: ldp w16, w17, [x15, #-0x4]
  376: subs x14, x14, #0x2
  380: add x15, x15, #0x8
  384: add w0, w16, w0
  388: add w13, w17, w13
  392: b.ne +372
  396: and w14, w9, #0x3f
  400: add w9, w9, #0x1
  404: add w0, w13, w0
  408: ldr w15, [x10, w14, uxtw #2]
  412: cmp w9, w8
  416: add w13, w15, #0x1
  420: str w13, [x10, w14, uxtw #2]
  424: b.ne +244
  428: add sp, sp, #0xc, lsl #12
  432: ldp x20, x19, [sp, #0x20]
  436: ldp x22, x21, [sp, #0x10]
  440: ldp x29, x30, [sp], #0x30
  444: ret
  448: add x9, sp, #0x8, lsl #12
  452: add x10, sp, #0x4, lsl #12
  456: mov x8, xzr
  460: add x9, x9, #0x4
  464: add x10, x10, #0x100
  468: mov x11, sp
  472: add x13, x11, x8, lsl #8
  476: mov x12, xzr
  480: mov x14, x10
  484: mov w15, wzr
  488: mov w16, wzr
  492: mov x17, x14
  496: mov w18, #0x40
  500: mov x0, x9
  504: ldp w1, w3, [x0, #-0x4]
  508: ldur w2, [x17, #-0x100]
  512: ldr w4, [x17]
  516: subs x18, x18, #0x2
  520: add x0, x0, #0x8
  524: add x17, x17, #0x200
  528: madd w15, w2, w1, w15
  532: madd w16, w4, w3, w16
  536: b.ne +504
  540: add w15, w16, w15
  544: str w15, [x13, x12, lsl #2]
  548: add x12, x12, #0x1
  552: cmp x12, #0x40
  556: add x14, x14, #0x4
  560: b.ne +484
  564: add x8, x8, #0x1
  568: add x9, x9, #0x100
  572: cmp x8, #0x40
  576: b.ne +472
  580: ldr w9, [x20]
  584: add x10, sp, #0x8, lsl #12
  588: add x11, sp, #0x4, lsl #12
  592: add x12, sp, #0x8, lsl #12
  596: mov x8, xzr
  600: add w9, w9, #0x1
  604: str w9, [x12]
  608: add x9, x10, #0x4
  612: add x10, x11, #0x100
  616: mov x11, sp
  620: add x13, x11, x8, lsl #8
  624: mov x12, xzr
  628: mov x14, x10
  632: mov w15, wzr
  636: mov w16, wzr
  640: mov w17, #0x40
  644: mov x18, x14
  648: mov x0, x9
  652: ldp w1, w3, [x0, #-0x4]
  656: ldur w2, [x18, #-0x100]
  660: ldr w4, [x18]
  664: subs x17, x17, #0x2
  668: add x0, x0, #0x8
  672: add x18, x18, #0x200
  676: madd w15, w2, w1, w15
  680: madd w16, w4, w3, w16
  684: b.ne +652
  688: add w15, w16, w15
  692: str w15, [x13, x12, lsl #2]
  696: add x12, x12, #0x1
  700: cmp x12, #0x40
  704: add x14, x14, #0x4
  708: b.ne +632
  712: add x8, x8, #0x1
  716: add x9, x9, #0x100
  720: cmp x8, #0x40
  724: b.ne +620
  728: bl <array_index_fail>
```

#### `bench_crc32__U32` (93 instructions, 372 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x8, lsl #12
   12: sub sp, sp, #0x400
   16: mov w19, w0
   20: add x0, sp, #0x8, lsl #12
   24: mov w1, wzr
   28: mov w2, #0x400
   32: add x20, sp, #0x8, lsl #12
   36: bl <memset>
   40: mov x8, xzr
   44: add x9, x20, #0x8
   48: adrp x10, <harness_main+0x1f7c>
   52: add x10, x10, #0x748
   56: ldp w12, w13, [x10, #-0x8]
   60: lsr w11, w8, #8
   64: add x8, x8, #0x4
   68: ldp w14, w15, [x10], #0x10
   72: eor w12, w11, w12
   76: eor w13, w11, w13
   80: cmp x8, #0x100
   84: stp w12, w13, [x9, #-0x8]
   88: eor w12, w11, w14
   92: eor w11, w11, w15
   96: stp w12, w11, [x9], #0x10
  100: b.ne +56
  104: mov x0, sp
  108: mov w1, wzr
  112: mov w2, #0x8000
  116: mov x20, sp
  120: bl <memset>
  124: mov w10, #0x660d
  128: mov w11, #0xf35f
  132: mov x8, xzr
  136: mov w9, #0x7e8
  140: movk w10, #0x19, lsl #16
  144: movk w11, #0x3c6e, lsl #16
  148: madd w9, w9, w10, w11
  152: lsr w12, w9, #24
  156: strb w12, [x20, x8]
  160: add x8, x8, #0x1
  164: cmp x8, #0x8, lsl #12
  168: b.ne +148
  172: lsl w8, w19, #5
  176: tbnz w8, #0x1f, +272
  180: cbz w8, +344
  184: mov w10, wzr
  188: mov w9, #-0x1
  192: mov x11, sp
  196: add x12, sp, #0x8, lsl #12
  200: mov x13, xzr
  204: ldrb w14, [x11, x13]
  208: add x13, x13, #0x1
  212: cmp x13, #0x8, lsl #12
  216: eor w14, w14, w9
  220: and x14, x14, #0xff
  224: ldr w14, [x12, x14, lsl #2]
  228: eor w9, w14, w9, lsr #8
  232: b.ne +204
  236: add w10, w10, #0x1
  240: cmp w10, w8
  244: b.ne +200
  248: mvn w0, w9
  252: add sp, sp, #0x8, lsl #12
  256: add sp, sp, #0x400
  260: ldp x20, x19, [sp, #0x10]
  264: ldp x29, x30, [sp], #0x20
  268: ret
  272: mov w10, wzr
  276: mov w9, #-0x1
  280: mov x11, sp
  284: add x12, sp, #0x8, lsl #12
  288: mov x13, xzr
  292: ldrb w14, [x11, x13]
  296: add x13, x13, #0x1
  300: cmp x13, #0x8, lsl #12
  304: eor w14, w14, w9
  308: and x14, x14, #0xff
  312: ldr w14, [x12, x14, lsl #2]
  316: eor w9, w14, w9, lsr #8
  320: b.ne +292
  324: sub w13, w10, w8
  328: sub w10, w10, #0x1
  332: cmp w13, #0x1
  336: b.hi +288
  340: b +248
  344: mov w9, #-0x1
  348: mvn w0, w9
  352: add sp, sp, #0x8, lsl #12
  356: add sp, sp, #0x400
  360: ldp x20, x19, [sp, #0x10]
  364: ldp x29, x30, [sp], #0x20
  368: ret
```

#### `bench_sha256__U32` (150 instructions, 600 bytes)
```asm
    0: sub sp, sp, #0x160
    4: stp x20, x19, [sp, #0x150]
    8: mov w8, #0xbb8
   12: mov x20, sp
   16: mul w19, w0, w8
   20: add x0, x20, #0x40
   24: mov w1, wzr
   28: mov w2, #0xc0
   32: stp x29, x30, [sp, #0x100]
   36: stp x28, x27, [sp, #0x110]
   40: stp x26, x25, [sp, #0x120]
   44: stp x24, x23, [sp, #0x130]
   48: stp x22, x21, [sp, #0x140]
   52: bl <memset>
   56: cbz w19, +560
   60: mov w9, #0xf35f
   64: mov w10, #0x660d
   68: mov w12, #0xcd19
   72: movk w9, #0x3c6e, lsl #16
   76: mov w14, #0xd9ab
   80: mov w15, #0x688c
   84: mov w13, #0x527f
   88: mov w18, #0xf53a
   92: mov w17, #0xae85
   96: mov w16, #0xe667
  100: mov w8, wzr
  104: movk w10, #0x19, lsl #16
  108: movk w12, #0x5be0, lsl #16
  112: movk w14, #0x1f83, lsl #16
  116: add w11, w9, #0x13
  120: movk w15, #0x9b05, lsl #16
  124: movk w13, #0x510e, lsl #16
  128: movk w18, #0xa54f, lsl #16
  132: movk w17, #0xbb67, lsl #16
  136: movk w16, #0x6a09, lsl #16
  140: mov w1, #0x328
  144: nop
  148: adr x0, 0x400845c0
  152: madd w1, w1, w10, w9
  156: mov w3, #0x30
  160: madd w2, w1, w10, w9
  164: stp w1, w2, [sp]
  168: madd w1, w2, w10, w9
  172: madd w2, w1, w10, w9
  176: stp w1, w2, [sp, #0x8]
  180: madd w1, w2, w10, w9
  184: madd w2, w1, w10, w9
  188: stp w1, w2, [sp, #0x10]
  192: madd w1, w2, w10, w9
  196: madd w2, w1, w10, w9
  200: stp w1, w2, [sp, #0x18]
  204: madd w1, w2, w10, w9
  208: madd w2, w1, w10, w9
  212: stp w1, w2, [sp, #0x20]
  216: madd w1, w2, w10, w9
  220: madd w2, w1, w10, w9
  224: stp w1, w2, [sp, #0x28]
  228: madd w1, w2, w10, w9
  232: madd w2, w1, w10, w9
  236: stp w1, w2, [sp, #0x30]
  240: madd w2, w2, w10, w9
  244: madd w1, w2, w10, w9
  248: stp w2, w1, [sp, #0x38]
  252: add x2, x20, #0x40
  256: ldp w6, w4, [x2, #-0x40]
  260: ldur w5, [x2, #-0x8]
  264: ldur w22, [x2, #-0x1c]
  268: subs x3, x3, #0x1
  272: ror w7, w4, #0x7
  276: ror w21, w5, #0x11
  280: add w6, w6, w22
  284: eor w7, w7, w4, ror #18
  288: eor w21, w21, w5, ror #19
  292: eor w4, w7, w4, lsr #3
  296: eor w5, w21, w5, lsr #10
  300: add w4, w4, w6
  304: add w4, w4, w5
  308: str w4, [x2], #0x4
  312: b.ne +256
  316: mov x21, xzr
  320: mov w23, w16
  324: mov w7, w17
  328: mov w6, w11
  332: mov w5, w18
  336: mov w22, w13
  340: mov w2, w15
  344: mov w3, w14
  348: mov w4, w12
  352: mov w24, w4
  356: mov w4, w3
  360: mov w3, w2
  364: mov w2, w22
  368: mov w25, w5
  372: mov w5, w6
  376: mov w6, w7
  380: mov w7, w23
  384: ror w22, w22, #0x6
  388: and w23, w2, w3
  392: bic w26, w4, w2
  396: ror w27, w7, #0x2
  400: orr w23, w23, w26
  404: ldr w26, [x0, x21]
  408: eor w22, w22, w2, ror #11
  412: add w23, w23, w24
  416: eor w24, w27, w7, ror #13
  420: ldr w27, [x20, x21]
  424: add w23, w23, w26
  428: eor w26, w6, w5
  432: eor w22, w22, w2, ror #25
  436: eor w24, w24, w7, ror #22
  440: and w26, w7, w26
  444: and w28, w6, w5
  448: add w23, w23, w27
  452: eor w26, w26, w28
  456: add x21, x21, #0x4
  460: add w23, w23, w22
  464: add w24, w24, w26
  468: cmp x21, #0x100
  472: add w22, w23, w25
  476: add w23, w24, w23
  480: b.ne +352
  484: add w8, w8, #0x1
  488: add w16, w23, w16
  492: add w17, w7, w17
  496: add w11, w6, w11
  500: add w18, w5, w18
  504: add w13, w22, w13
  508: cmp w8, w19
  512: add w15, w2, w15
  516: add w14, w3, w14
  520: add w12, w4, w12
  524: b.ne +152
  528: eor w8, w14, w12
  532: eor w8, w8, w15
  536: eor w8, w8, w18
  540: eor w8, w8, w11
  544: eor w8, w8, w17
  548: eor w8, w8, w13
  552: eor w0, w8, w16
  556: b +568
  560: mov w0, #0x60eb
  564: movk w0, #0xc627, lsl #16
  568: ldp x20, x19, [sp, #0x150]
  572: ldp x22, x21, [sp, #0x140]
  576: ldp x24, x23, [sp, #0x130]
  580: ldp x26, x25, [sp, #0x120]
  584: ldp x28, x27, [sp, #0x110]
  588: ldp x29, x30, [sp, #0x100]
  592: add sp, sp, #0x160
  596: ret
```

#### `bench_popcount__U32` (31 instructions, 124 bytes)
```asm
    0: mov w8, #0x27c0
    4: movk w8, #0x9, lsl #16
    8: mul w8, w0, w8
   12: cbz w8, +116
   16: mov w10, #0x660d
   20: mov w11, #0xf35f
   24: mov w0, wzr
   28: mov w9, #0x37
   32: movk w10, #0x19, lsl #16
   36: movk w11, #0x3c6e, lsl #16
   40: mov w12, #0x1010101
   44: b +56
   48: subs w8, w8, #0x1
   52: b.eq +112
   56: madd w9, w9, w10, w11
   60: cbz w9, +48
   64: lsr w13, w9, #1
   68: and w13, w13, #0x55555555
   72: sub w13, w9, w13
   76: lsr w14, w13, #2
   80: and w13, w13, #0x33333333
   84: and w14, w14, #0x33333333
   88: add w13, w13, w14
   92: add w13, w13, w13, lsr #4
   96: and w13, w13, #0xf0f0f0f
  100: mul w13, w13, w12
  104: add w0, w0, w13, lsr #24
  108: b +48
  112: ret
  116: mov w0, wzr
  120: ret
```

#### `bench_mandelbrot_fixed__U32` (196 instructions, 784 bytes)
```asm
    0: mov w8, #0x8000
    4: mov w0, wzr
    8: mov w9, wzr
   12: movk w8, #0xfffe, lsl #16
   16: b +32
   20: add w9, w9, #0x1
   24: cmp w9, #0x60
   28: b.eq +140
   32: add w10, w8, w9, lsl #11
   36: mov w11, wzr
   40: b +60
   44: add w11, w11, #0x1
   48: add w0, w12, w0
   52: cmp w11, #0x60
   56: b.eq +20
   60: lsl w13, w11, #11
   64: mov w12, wzr
   68: mov w15, wzr
   72: mov w14, wzr
   76: sub w13, w13, #0x20, lsl #12
   80: smull x16, w14, w14
   84: smull x18, w15, w15
   88: lsr x17, x16, #16
   92: lsr x16, x18, #16
   96: add w18, w16, w17
  100: cmp w18, #0x40, lsl #12
  104: b.gt +44
  108: smull x14, w15, w14
  112: add w12, w12, #0x1
  116: cmp w12, #0x28
  120: add x15, x10, x14, lsr #15
  124: add w14, w13, w17
  128: sub w14, w14, w16
  132: b.ne +80
  136: b +44
  140: mov w9, wzr
  144: b +160
  148: add w9, w9, #0x1
  152: cmp w9, #0x60
  156: b.eq +268
  160: add w10, w8, w9, lsl #11
  164: mov w11, wzr
  168: b +188
  172: add w11, w11, #0x1
  176: add w0, w12, w0
  180: cmp w11, #0x60
  184: b.eq +148
  188: lsl w13, w11, #11
  192: mov w12, wzr
  196: mov w15, wzr
  200: mov w14, wzr
  204: sub w13, w13, #0x20, lsl #12
  208: smull x16, w14, w14
  212: smull x18, w15, w15
  216: lsr x17, x16, #16
  220: lsr x16, x18, #16
  224: add w18, w16, w17
  228: cmp w18, #0x40, lsl #12
  232: b.gt +172
  236: smull x14, w15, w14
  240: add w12, w12, #0x1
  244: cmp w12, #0x28
  248: add x15, x10, x14, lsr #15
  252: add w14, w13, w17
  256: sub w14, w14, w16
  260: b.ne +208
  264: b +172
  268: mov w9, wzr
  272: b +288
  276: add w9, w9, #0x1
  280: cmp w9, #0x60
  284: b.eq +396
  288: add w10, w8, w9, lsl #11
  292: mov w11, wzr
  296: b +316
  300: add w11, w11, #0x1
  304: add w0, w12, w0
  308: cmp w11, #0x60
  312: b.eq +276
  316: lsl w13, w11, #11
  320: mov w12, wzr
  324: mov w15, wzr
  328: mov w14, wzr
  332: sub w13, w13, #0x20, lsl #12
  336: smull x16, w14, w14
  340: smull x18, w15, w15
  344: lsr x17, x16, #16
  348: lsr x16, x18, #16
  352: add w18, w16, w17
  356: cmp w18, #0x40, lsl #12
  360: b.gt +300
  364: smull x14, w15, w14
  368: add w12, w12, #0x1
  372: cmp w12, #0x28
  376: add x15, x10, x14, lsr #15
  380: add w14, w13, w17
  384: sub w14, w14, w16
  388: b.ne +336
  392: b +300
  396: mov w9, wzr
  400: b +416
  404: add w9, w9, #0x1
  408: cmp w9, #0x60
  412: b.eq +524
  416: add w10, w8, w9, lsl #11
  420: mov w11, wzr
  424: b +444
  428: add w11, w11, #0x1
  432: add w0, w12, w0
  436: cmp w11, #0x60
  440: b.eq +404
  444: lsl w13, w11, #11
  448: mov w12, wzr
  452: mov w15, wzr
  456: mov w14, wzr
  460: sub w13, w13, #0x20, lsl #12
  464: smull x16, w14, w14
  468: smull x18, w15, w15
  472: lsr x17, x16, #16
  476: lsr x16, x18, #16
  480: add w18, w16, w17
  484: cmp w18, #0x40, lsl #12
  488: b.gt +428
  492: smull x14, w15, w14
  496: add w12, w12, #0x1
  500: cmp w12, #0x28
  504: add x15, x10, x14, lsr #15
  508: add w14, w13, w17
  512: sub w14, w14, w16
  516: b.ne +464
  520: b +428
  524: mov w9, wzr
  528: b +544
  532: add w9, w9, #0x1
  536: cmp w9, #0x60
  540: b.eq +652
  544: add w10, w8, w9, lsl #11
  548: mov w11, wzr
  552: b +572
  556: add w11, w11, #0x1
  560: add w0, w12, w0
  564: cmp w11, #0x60
  568: b.eq +532
  572: lsl w13, w11, #11
  576: mov w12, wzr
  580: mov w15, wzr
  584: mov w14, wzr
  588: sub w13, w13, #0x20, lsl #12
  592: smull x16, w14, w14
  596: smull x18, w15, w15
  600: lsr x17, x16, #16
  604: lsr x16, x18, #16
  608: add w18, w16, w17
  612: cmp w18, #0x40, lsl #12
  616: b.gt +556
  620: smull x14, w15, w14
  624: add w12, w12, #0x1
  628: cmp w12, #0x28
  632: add x15, x10, x14, lsr #15
  636: add w14, w13, w17
  640: sub w14, w14, w16
  644: b.ne +592
  648: b +556
  652: mov w9, wzr
  656: b +672
  660: add w9, w9, #0x1
  664: cmp w9, #0x60
  668: b.eq +780
  672: add w10, w8, w9, lsl #11
  676: mov w11, wzr
  680: b +700
  684: add w11, w11, #0x1
  688: add w0, w12, w0
  692: cmp w11, #0x60
  696: b.eq +660
  700: lsl w13, w11, #11
  704: mov w12, wzr
  708: mov w15, wzr
  712: mov w14, wzr
  716: sub w13, w13, #0x20, lsl #12
  720: smull x16, w14, w14
  724: smull x18, w15, w15
  728: lsr x17, x16, #16
  732: lsr x16, x18, #16
  736: add w18, w16, w17
  740: cmp w18, #0x40, lsl #12
  744: b.gt +684
  748: smull x14, w15, w14
  752: add w12, w12, #0x1
  756: cmp w12, #0x28
  760: add x15, x10, x14, lsr #15
  764: add w14, w13, w17
  768: sub w14, w14, w16
  772: b.ne +720
  776: b +684
  780: ret
```

#### `bench_bytecode_interpreter__U32` (103 instructions, 412 bytes)
```asm
    0: mov w8, #0x1a80
    4: mov w9, #0x1
    8: mov w10, #0x2
   12: movk w8, #0x6, lsl #16
   16: mul w8, w0, w8
   20: stp w9, w10, [sp, #-0x10]!
   24: mov w9, #0x3
   28: mov w10, #0x4
   32: stp w9, w10, [sp, #0x8]
   36: tbnz w8, #0x1f, +408
   40: cbz w8, +392
   44: mov w12, #0x1
   48: mov w13, #0x10
   52: mov w9, wzr
   56: adrp x10, <harness_main+0x1f7c>
   60: add x10, x10, #0x6c0
   64: mov w11, #0x1
   68: movk w12, #0x100, lsl #16
   72: movk w13, #0x1000, lsl #16
   76: mov x14, sp
   80: b +112
   84: ldr w16, [x14, x16, lsl #2]
   88: lsl w16, w16, #1
   92: cmp w9, #0x7
   96: str w16, [x14, x15, lsl #2]
  100: csinc w9, wzr, w9, eq
  104: subs w8, w8, #0x1
  108: b.eq +364
  112: lsl w18, w9, #2
  116: add x17, x10, w18, sxtw #2
  120: lsr x0, x12, x18
  124: ldp w15, w16, [x17, #0x4]
  128: ldr w17, [x17, #0xc]
  132: tbz w0, #0x0, +176
  136: cmp w16, #0x4
  140: b.hs +404
  144: cmp w17, #0x4
  148: b.hs +404
  152: cmp w15, #0x4
  156: b.hs +404
  160: ldr w16, [x14, x16, lsl #2]
  164: ldr w17, [x14, x17, lsl #2]
  168: add w16, w17, w16
  172: b +92
  176: lsl x0, x11, x18
  180: tst x0, x13
  184: b.eq +228
  188: cmp w16, #0x4
  192: b.hs +404
  196: cmp w17, #0x4
  200: b.hs +404
  204: cmp w15, #0x4
  208: b.hs +404
  212: ldr w16, [x14, x16, lsl #2]
  216: ldr w17, [x14, x17, lsl #2]
  220: eor w16, w17, w16
  224: b +92
  228: cmp w18, #0x8
  232: b.eq +300
  236: cmp w18, #0xc
  240: b.eq +280
  244: cmp w18, #0x10
  248: b.ne +340
  252: cmp w16, #0x4
  256: b.hs +404
  260: cmp w15, #0x4
  264: b.hs +404
  268: ldr w16, [x14, x16, lsl #2]
  272: add w16, w16, w17
  276: b +92
  280: cmp w16, #0x3
  284: b.hi +404
  288: cmp w15, #0x4
  292: b.lo +84
  296: b +404
  300: cmp w16, #0x3
  304: b.hi +404
  308: cmp w17, #0x4
  312: b.hs +404
  316: cmp w15, #0x4
  320: b.hs +404
  324: ldr w16, [x14, x16, lsl #2]
  328: ldr w17, [x14, x17, lsl #2]
  332: mul w16, w17, w16
  336: b +92
  340: cmp w16, #0x4
  344: b.hs +404
  348: cmp w15, #0x4
  352: b.hs +404
  356: ldr w16, [x14, x16, lsl #2]
  360: b +92
  364: ldp w8, w9, [sp]
  368: ldp w10, w11, [sp, #0x8]
  372: eor w8, w9, w8
  376: eor w9, w10, w11
  380: eor w0, w8, w9
  384: add sp, sp, #0x10
  388: ret
  392: mov w0, #0x4
  396: add sp, sp, #0x10
  400: ret
  404: bl <array_index_fail>
  408: bl <prismio_panic>
```

#### `bench_pointer_chase__U32` (78 instructions, 312 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x4, lsl #12
   12: mov w19, w0
   16: add x0, sp, #0x2, lsl #12
   20: mov w1, wzr
   24: mov w2, #0x2000
   28: add x20, sp, #0x2, lsl #12
   32: bl <memset>
   36: mov x0, sp
   40: mov w1, wzr
   44: mov w2, #0x2000
   48: bl <memset>
   52: mov x8, xzr
   56: add x9, x20, #0x8
   60: add w10, w8, #0x1
   64: add w11, w8, #0x2
   68: add w12, w8, #0x3
   72: stp w8, w10, [x9, #-0x8]
   76: add x8, x8, #0x4
   80: cmp x8, #0x800
   84: stp w11, w12, [x9], #0x10
   88: b.ne +60
   92: mov w10, #0x660d
   96: mov w11, #0xf35f
  100: mov w8, #0x2329
  104: mov w9, #0x7ff
  108: movk w10, #0x19, lsl #16
  112: movk w11, #0x3c6e, lsl #16
  116: add x12, sp, #0x2, lsl #12
  120: madd w8, w8, w10, w11
  124: add w14, w9, #0x1
  128: lsr w13, w8, #8
  132: udiv w15, w13, w14
  136: msub w13, w15, w14, w13
  140: ldr w15, [x12, x9, lsl #2]
  144: ldr w14, [x12, w13, uxtw #2]
  148: str w14, [x12, x9, lsl #2]
  152: subs x9, x9, #0x1
  156: str w15, [x12, w13, uxtw #2]
  160: b.ne +120
  164: ldr w8, [x20]
  168: add x9, sp, #0x2, lsl #12
  172: mov w10, #0x7fc
  176: add x9, x9, #0x8
  180: mov x11, sp
  184: mov w12, w8
  188: ldpsw x13, x14, [x9, #-0x4]
  192: subs x10, x10, #0x4
  196: str w13, [x11, w12, sxtw #2]
  200: ldp w15, w12, [x9, #0x4]
  204: add x9, x9, #0x10
  208: str w14, [x11, x13, lsl #2]
  212: sxtw x15, w15
  216: str w15, [x11, x14, lsl #2]
  220: str w12, [x11, x15, lsl #2]
  224: b.ne +188
  228: mov w10, #0x9f00
  232: ldrsw x11, [x20, #0x1ff4]
  236: mov x9, sp
  240: movk w10, #0x24, lsl #16
  244: str w11, [x9, w12, sxtw #2]
  248: ldrsw x12, [x20, #0x1ff8]
  252: mul w10, w19, w10
  256: str w12, [x9, x11, lsl #2]
  260: ldrsw x11, [x20, #0x1ffc]
  264: mov w0, wzr
  268: str w11, [x9, x12, lsl #2]
  272: str w8, [x9, x11, lsl #2]
  276: cbz w10, +296
  280: ldr w8, [x9, w8, sxtw #2]
  284: subs w10, w10, #0x1
  288: add w0, w8, w0
  292: b.ne +280
  296: add sp, sp, #0x4, lsl #12
  300: ldp x20, x19, [sp, #0x10]
  304: ldp x29, x30, [sp], #0x20
  308: ret
```

#### `bench_ring_buffer__U32` (51 instructions, 204 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x1, lsl #12
   12: mov w19, w0
   16: mov x0, sp
   20: mov w1, wzr
   24: mov w2, #0x1000
   28: mov x20, sp
   32: bl <memset>
   36: mov w8, #0x93e0
   40: movk w8, #0x4, lsl #16
   44: mul w8, w19, w8
   48: cbz w8, +184
   52: mov w14, #0x660d
   56: mov w15, #0xf35f
   60: mov w10, wzr
   64: mov w9, wzr
   68: mov w11, wzr
   72: mov w12, wzr
   76: mov w13, #0x141
   80: movk w14, #0x19, lsl #16
   84: movk w15, #0x3c6e, lsl #16
   88: b +100
   92: subs w8, w8, #0x1
   96: b.eq +164
  100: madd w13, w13, w14, w15
  104: sub w16, w10, w12
  108: cmp w16, #0x400
  112: b.hs +128
  116: and w16, w10, #0x3ff
  120: add w10, w10, #0x1
  124: str w13, [x20, w16, uxtw #2]
  128: tbnz w13, #0x8, +92
  132: cmp w10, w12
  136: b.eq +92
  140: and w16, w12, #0x3ff
  144: add w12, w12, #0x1
  148: add w9, w9, #0x1
  152: ldr w16, [x20, w16, uxtw #2]
  156: add w11, w16, w11
  160: b +92
  164: eor w0, w9, w11
  168: add sp, sp, #0x1, lsl #12
  172: ldp x20, x19, [sp, #0x10]
  176: ldp x29, x30, [sp], #0x20
  180: ret
  184: mov w0, wzr
  188: add sp, sp, #0x1, lsl #12
  192: ldp x20, x19, [sp, #0x10]
  196: ldp x29, x30, [sp], #0x20
  200: ret
```

#### `bench_mem_copy__U32` (90 instructions, 360 bytes)
```asm
    0: mov x10, #0x82a0
    4: mov x11, #0xa1f8
    8: mov x12, #0xc150
   12: mov x13, #0xe0a8
   16: movk x10, #0xe94f, lsl #16
   20: movk x11, #0xeefb, lsl #16
   24: movk x12, #0xf4a7, lsl #16
   28: movk x13, #0xfa53, lsl #16
   32: movk x10, #0x372f, lsl #32
   36: movk x11, #0x6963, lsl #32
   40: movk x12, #0x9b97, lsl #32
   44: movk x13, #0xcdcb, lsl #32
   48: mov w14, #0x8
   52: mov x8, xzr
   56: mov x9, xzr
   60: movk x10, #0xc6ef, lsl #48
   64: movk x11, #0xd533, lsl #48
   68: movk x12, #0xe377, lsl #48
   72: movk x13, #0xf1bb, lsl #48
   76: movk w14, #0x4400, lsl #16
   80: mov w15, #0x5555
   84: mov w16, #0x44000000
   88: add x18, x14, #0x8
   92: add x1, x14, #0x10
   96: orr x17, x8, x14
  100: eor x2, x9, x15
  104: eor x3, x13, x15
  108: orr x18, x8, x18
  112: str x2, [x8, x16]
  116: orr x1, x8, x1
  120: add x8, x8, #0x20
  124: eor x2, x12, x15
  128: str x3, [x17]
  132: eor x17, x11, x15
  136: add x11, x11, x10
  140: cmp x8, #0x8, lsl #12
  144: add x12, x12, x10
  148: add x13, x13, x10
  152: add x9, x9, x10
  156: str x2, [x18]
  160: str x17, [x1]
  164: b.ne +88
  168: add w8, w0, w0, lsl #3
  172: lsl w8, w8, #5
  176: cbz w8, +240
  180: mov x9, xzr
  184: mov w10, #0x44000000
  188: mov w11, #0x45000000
  192: mov x12, xzr
  196: add x9, x9, #0x1
  200: lsr x13, x12, #3
  204: ldr x14, [x12, x10]
  208: str x14, [x12, x11]
  212: cmp x13, #0xfff
  216: add x13, x9, x14
  220: str x13, [x12, x10]
  224: add x12, x12, #0x8
  228: b.lo +200
  232: cmp x9, x8
  236: b.ne +192
  240: mov w13, #0x8
  244: mov x9, xzr
  248: mov x8, xzr
  252: mov x10, xzr
  256: mov x11, xzr
  260: mov x12, xzr
  264: movk w13, #0x4500, lsl #16
  268: mov w14, #0x45000000
  272: add x15, x13, #0x8
  276: add x17, x13, #0x10
  280: orr x16, x9, x13
  284: orr x15, x9, x15
  288: orr x17, x9, x17
  292: ldr x18, [x9, x14]
  296: ldr x16, [x16]
  300: ldr x15, [x15]
  304: ldr x17, [x17]
  308: add x9, x9, #0x20
  312: add x8, x18, x8
  316: cmp x9, #0x8, lsl #12
  320: add x10, x16, x10
  324: add x11, x15, x11
  328: add x12, x17, x12
  332: b.ne +272
  336: add x8, x10, x8
  340: add x8, x11, x8
  344: add x8, x12, x8
  348: lsr x9, x8, #32
  352: eor w0, w9, w8
  356: ret
```

#### `bench_atomic_counter__U32` (34 instructions, 136 bytes)
```asm
    0: mov w8, #0xa120
    4: mov w9, #0x44100000
    8: movk w8, #0x7, lsl #16
   12: str wzr, [x9]
   16: mul w8, w0, w8
   20: tbnz w8, #0x1f, +76
   24: cbz w8, +124
   28: mov w9, wzr
   32: mov w10, #0x44100000
   36: and w11, w9, #0x3
   40: add w11, w11, #0x1
   44: ldaxr w12, [x10]
   48: add w12, w12, w11
   52: stlxr w13, w12, [x10]
   56: cbnz w13, +44
   60: add w9, w9, #0x1
   64: cmp w9, w8
   68: b.ne +36
   72: b +124
   76: mov w9, wzr
   80: mov w10, #0x44100000
   84: and w11, w9, #0x3
   88: add w11, w11, #0x1
   92: ldaxr w12, [x10]
   96: add w12, w12, w11
  100: stlxr w13, w12, [x10]
  104: cbnz w13, +92
  108: sub w11, w9, w8
  112: sub w9, w9, #0x1
  116: cmp w11, #0x1
  120: b.hi +84
  124: mov w8, #0x44100000
  128: ldar w0, [x8]
  132: ret
```

#### `bench_spinlock__U32` (28 instructions, 112 bytes)
```asm
    0: mov w8, #0x3500
    4: movk w8, #0xc, lsl #16
    8: mul w9, w0, w8
   12: mov w8, #0x10
   16: movk w8, #0x4410, lsl #16
   20: str wzr, [x8]
   24: str wzr, [x8, #0x10]
   28: cbz w9, +104
   32: mov w10, wzr
   36: mov w11, #0x1
   40: ldaxr w12, [x8]
   44: cbnz w12, +88
   48: stlxr w12, w11, [x8]
   52: cbnz w12, +40
   56: ldr w12, [x8, #0x10]
   60: add w10, w10, #0x1
   64: cmp w10, w9
   68: add w12, w12, #0x1
   72: str w12, [x8, #0x10]
   76: stlr wzr, [x8]
   80: b.ne +40
   84: b +96
   88: clrex
   92: b +40
   96: ldr w0, [x8, #0x10]
  100: ret
  104: mov w0, wzr
  108: ret
```

#### `bench_volatile_registers__U32` (97 instructions, 388 bytes)
```asm
    0: mov w9, #0x44200000
    4: mov w8, #0x4
    8: str wzr, [x9]
   12: mov w9, #0xbba0
   16: movk w8, #0x4420, lsl #16
   20: movk w9, #0xd, lsl #16
   24: str wzr, [x8]
   28: mul w9, w0, w9
   32: str wzr, [x8, #0x4]
   36: str wzr, [x8, #0x8]
   40: str wzr, [x8, #0xc]
   44: str wzr, [x8, #0x10]
   48: str wzr, [x8, #0x14]
   52: str wzr, [x8, #0x18]
   56: str wzr, [x8, #0x1c]
   60: str wzr, [x8, #0x20]
   64: str wzr, [x8, #0x24]
   68: str wzr, [x8, #0x28]
   72: str wzr, [x8, #0x2c]
   76: str wzr, [x8, #0x30]
   80: str wzr, [x8, #0x34]
   84: str wzr, [x8, #0x38]
   88: str wzr, [x8, #0x3c]
   92: str wzr, [x8, #0x40]
   96: str wzr, [x8, #0x44]
  100: str wzr, [x8, #0x48]
  104: str wzr, [x8, #0x4c]
  108: str wzr, [x8, #0x50]
  112: str wzr, [x8, #0x54]
  116: str wzr, [x8, #0x58]
  120: str wzr, [x8, #0x5c]
  124: str wzr, [x8, #0x60]
  128: str wzr, [x8, #0x64]
  132: str wzr, [x8, #0x68]
  136: str wzr, [x8, #0x6c]
  140: str wzr, [x8, #0x70]
  144: str wzr, [x8, #0x74]
  148: str wzr, [x8, #0x78]
  152: str wzr, [x8, #0x7c]
  156: str wzr, [x8, #0x80]
  160: str wzr, [x8, #0x84]
  164: str wzr, [x8, #0x88]
  168: str wzr, [x8, #0x8c]
  172: str wzr, [x8, #0x90]
  176: str wzr, [x8, #0x94]
  180: str wzr, [x8, #0x98]
  184: str wzr, [x8, #0x9c]
  188: str wzr, [x8, #0xa0]
  192: str wzr, [x8, #0xa4]
  196: str wzr, [x8, #0xa8]
  200: str wzr, [x8, #0xac]
  204: str wzr, [x8, #0xb0]
  208: str wzr, [x8, #0xb4]
  212: str wzr, [x8, #0xb8]
  216: str wzr, [x8, #0xbc]
  220: str wzr, [x8, #0xc0]
  224: str wzr, [x8, #0xc4]
  228: str wzr, [x8, #0xc8]
  232: str wzr, [x8, #0xcc]
  236: str wzr, [x8, #0xd0]
  240: str wzr, [x8, #0xd4]
  244: str wzr, [x8, #0xd8]
  248: str wzr, [x8, #0xdc]
  252: str wzr, [x8, #0xe0]
  256: str wzr, [x8, #0xe4]
  260: str wzr, [x8, #0xe8]
  264: str wzr, [x8, #0xec]
  268: str wzr, [x8, #0xf0]
  272: str wzr, [x8, #0xf4]
  276: str wzr, [x8, #0xf8]
  280: cbz w9, +344
  284: mov w10, wzr
  288: mov w8, wzr
  292: mov w11, wzr
  296: mov w12, #0x44200000
  300: and w13, w10, #0xfc
  304: add w10, w10, #0x1c
  308: orr x13, x13, x12
  312: ldr w14, [x13]
  316: add w15, w11, w14
  320: add w11, w11, #0x1
  324: add w8, w14, w8
  328: cmp w9, w11
  332: str w15, [x13]
  336: b.ne +300
  340: b +348
  344: mov w8, wzr
  348: mov w9, wzr
  352: mov w10, #0x40
  356: mov w11, #0x44200000
  360: ldr w12, [x11]
  364: subs x10, x10, #0x1
  368: add x11, x11, #0x4
  372: add w9, w12, w9
  376: b.ne +360
  380: eor w0, w9, w8
  384: ret
```

#### `main` (2 instructions, 8 bytes)
```asm
    0: mov w0, wzr
    4: ret
```

#### `exit` (75 instructions, 300 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x8, <harness_main+0x1f7c>
    8: mov x29, sp
   12: ldr x8, [x8, #0xce0]
   16: ldrb w9, [x8]
   20: cmp w9, #0x72
   24: b.ne +204
   28: ldrb w9, [x8, #0x1]
   32: cmp w9, #0x75
   36: b.ne +204
   40: ldrb w9, [x8, #0x2]
   44: cmp w9, #0x6e
   48: b.ne +204
   52: ldrb w9, [x8, #0x3]
   56: cmp w9, #0x74
   60: b.ne +204
   64: ldrb w9, [x8, #0x4]
   68: cmp w9, #0x69
   72: b.ne +204
   76: ldrb w9, [x8, #0x5]
   80: cmp w9, #0x6d
   84: b.ne +204
   88: ldrb w9, [x8, #0x6]
   92: cmp w9, #0x65
   96: b.ne +204
  100: ldrb w9, [x8, #0x7]
  104: cmp w9, #0x20
  108: b.ne +204
  112: ldrb w9, [x8, #0x8]
  116: cmp w9, #0x65
  120: b.ne +204
  124: ldrb w9, [x8, #0x9]
  128: cmp w9, #0x72
  132: b.ne +204
  136: ldrb w9, [x8, #0xa]
  140: cmp w9, #0x72
  144: b.ne +204
  148: ldrb w9, [x8, #0xb]
  152: cmp w9, #0x6f
  156: b.ne +204
  160: ldrb w9, [x8, #0xc]
  164: cmp w9, #0x72
  168: b.ne +204
  172: ldrb w9, [x8, #0xd]
  176: cmp w9, #0x3a
  180: b.ne +204
  184: ldrb w9, [x8, #0xe]
  188: cmp w9, #0x20
  192: mov w9, #0xf
  196: csel x9, x9, xzr, eq
  200: b +208
  204: mov x9, xzr
  208: mov x10, xzr
  212: add x8, x8, x9
  216: nop
  220: adr x1, <exit.detail>
  224: ldrb w9, [x8, xzr]
  228: cbz w9, +268
  232: cmp w9, #0xa
  236: b.eq +268
  240: cmp x10, #0x9f
  244: b.eq +268
  248: add x11, x10, #0x1
  252: strb w9, [x1, x10]
  256: mov x10, x11
  260: ldrb w9, [x8, x11]
  264: cbnz w9, +232
  268: adrp x0, <harness_main+0x1f7c>
  272: add x0, x0, #0xb77
  276: adrp x2, <harness_main+0x1f7c>
  280: add x2, x2, #0xbd6
  284: mov w3, wzr
  288: mov w4, wzr
  292: strb wzr, [x1, x10]
  296: bl <prismio_panic_hook>
```

#### `prismio_panic` (9 instructions, 36 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: mov w4, w3
    8: mov w3, w2
   12: mov x2, x1
   16: mov x1, x0
   20: adrp x0, <harness_main+0x1f7c>
   24: add x0, x0, #0xc91
   28: mov x29, sp
   32: bl <prismio_panic_hook>
```

#### `array_index_fail` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1f7c>
    8: add x0, x0, #0xcca
   12: adrp x1, <harness_main+0x1f7c>
   16: add x1, x1, #0xcc4
   20: adrp x2, <harness_main+0x1f7c>
   24: add x2, x2, #0xbd6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `prismio_panic_hook` (1 instructions, 4 bytes)
```asm
    0: b +0
```

#### `prismio_overflow_trap` (9 instructions, 36 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: mov w3, w2
    8: mov x2, x1
   12: mov x1, x0
   16: nop
   20: adr x0, 0x40084c2b
   24: mov w4, wzr
   28: mov x29, sp
   32: bl <prismio_panic_hook>
```

#### `prismio_step_check` (13 instructions, 52 bytes)
```asm
    0: cmp w0, #0x1
    4: b.lt +12
    8: ret
   12: stp x29, x30, [sp, #-0x10]!
   16: mov w3, w2
   20: mov x2, x1
   24: adrp x0, <harness_main+0x1f7c>
   28: add x0, x0, #0xc75
   32: adrp x1, <harness_main+0x1f7c>
   36: add x1, x1, #0xbd6
   40: mov w4, wzr
   44: mov x29, sp
   48: bl <prismio_panic_hook>
```

#### `prismio_panic` (9 instructions, 36 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: mov w4, w3
    8: mov w3, w2
   12: mov x2, x1
   16: mov x1, x0
   20: adrp x0, <harness_main+0x1f7c>
   24: add x0, x0, #0xc91
   28: mov x29, sp
   32: bl <prismio_panic_hook>
```

#### `prismio_unreachable` (9 instructions, 36 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: mov w4, w3
    8: mov w3, w2
   12: mov x2, x1
   16: mov x1, x0
   20: adrp x0, <harness_main+0x1f7c>
   24: add x0, x0, #0xba2
   28: mov x29, sp
   32: bl <prismio_panic_hook>
```

#### `prismio_assert_failed` (11 instructions, 44 bytes)
```asm
    0: cbz x0, +16
    4: ldrb w9, [x0]
    8: mov x8, x0
   12: cbnz w9, +20
   16: mov x8, x1
   20: stp x29, x30, [sp, #-0x10]!
   24: adrp x0, <harness_main+0x1f7c>
   28: add x0, x0, #0xc97
   32: mov x1, x8
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `prismio_expect` (12 instructions, 48 bytes)
```asm
    0: cbz x0, +8
    4: ret
    8: stp x29, x30, [sp, #-0x10]!
   12: adrp x1, <harness_main+0x1f7c>
   16: add x1, x1, #0xbd6
   20: adrp x0, <harness_main+0x1f7c>
   24: add x0, x0, #0xc3c
   28: mov x2, x1
   32: mov w3, wzr
   36: mov w4, wzr
   40: mov x29, sp
   44: bl <prismio_panic_hook>
```

#### `data_view_fail` (10 instructions, 40 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: mov x1, x0
    8: adrp x0, <harness_main+0x1f7c>
   12: add x0, x0, #0xca8
   16: adrp x2, <harness_main+0x1f7c>
   20: add x2, x2, #0xbd6
   24: mov w3, wzr
   28: mov w4, wzr
   32: mov x29, sp
   36: bl <prismio_panic_hook>
```

#### `data_view_access_fail` (9 instructions, 36 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x8, <harness_main+0x1f7c>
    8: add x8, x8, #0xbbb
   12: cmp w0, #0x1
   16: adrp x9, <harness_main+0x1f7c>
   20: add x9, x9, #0xb85
   24: mov x29, sp
   28: csel x0, x9, x8, eq
   32: bl <data_view_fail>
```

#### `array_index_fail` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1f7c>
    8: add x0, x0, #0xcca
   12: adrp x1, <harness_main+0x1f7c>
   16: add x1, x1, #0xcc4
   20: adrp x2, <harness_main+0x1f7c>
   24: add x2, x2, #0xbd6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `list_index_fail` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1f7c>
    8: add x0, x0, #0xcca
   12: adrp x1, <harness_main+0x1f7c>
   16: add x1, x1, #0xc27
   20: adrp x2, <harness_main+0x1f7c>
   24: add x2, x2, #0xbd6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `prismio_alloc` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1f7c>
    8: add x0, x0, #0xc1a
   12: adrp x1, <harness_main+0x1f7c>
   16: add x1, x1, #0xb40
   20: adrp x2, <harness_main+0x1f7c>
   24: add x2, x2, #0xbd6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `prismio_realloc` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1f7c>
    8: add x0, x0, #0xc1a
   12: adrp x1, <harness_main+0x1f7c>
   16: add x1, x1, #0xb40
   20: adrp x2, <harness_main+0x1f7c>
   24: add x2, x2, #0xbd6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `prismio_free` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1f7c>
    8: add x0, x0, #0xc1a
   12: adrp x1, <harness_main+0x1f7c>
   16: add x1, x1, #0xb40
   20: adrp x2, <harness_main+0x1f7c>
   24: add x2, x2, #0xbd6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

### D.3 Prismio, partial unrolling at factor 4 (current)

#### `fib__U32` (20 instructions, 80 bytes)
```asm
    0: str x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: mov w19, w0
   12: cmp w0, #0x2
   16: b.hs +36
   20: add w0, w19, wzr
   24: ldp x20, x19, [sp, #0x10]
   28: ldr x30, [sp], #0x20
   32: ret
   36: mov w20, wzr
   40: sub w0, w19, #0x1
   44: bl +0
   48: sub w19, w19, #0x2
   52: add w20, w0, w20
   56: cmp w19, #0x2
   60: b.hs +40
   64: add w0, w19, w20
   68: ldp x20, x19, [sp, #0x10]
   72: ldr x30, [sp], #0x20
   76: ret
```

#### `bench_fibonacci__U32` (8 instructions, 32 bytes)
```asm
    0: cbz w0, +28
    4: stp x30, x19, [sp, #-0x10]!
    8: mov w19, w0
   12: mov w0, #0x1b
   16: bl <fib__U32>
   20: mul w0, w0, w19
   24: ldp x30, x19, [sp], #0x10
   28: ret
```

#### `bench_prime_sieve__U32` (234 instructions, 936 bytes)
```asm
    0: stp x29, x30, [sp, #-0x60]!
    4: stp x28, x27, [sp, #0x10]
    8: stp x26, x25, [sp, #0x20]
   12: stp x24, x23, [sp, #0x30]
   16: stp x22, x21, [sp, #0x40]
   20: stp x20, x19, [sp, #0x50]
   24: sub sp, sp, #0x30, lsl #12
   28: sub sp, sp, #0xd60
   32: str w0, [sp, #0xc]
   36: cbz w0, +900
   40: mov w22, #0xd40
   44: mov w28, #0x869e
   48: mov w25, #0xd3a
   52: mov w0, wzr
   56: mov w10, wzr
   60: movk w22, #0x3, lsl #16
   64: movk w28, #0x1, lsl #16
   68: add x24, sp, #0x20
   72: movk w25, #0x3, lsl #16
   76: mov w26, #0x1
   80: b +108
   84: ldp w9, w10, [sp, #0xc]
   88: ldr w0, [sp, #0x14]
   92: add w10, w10, #0x1
   96: add w0, w8, w0
  100: cmp w10, w9
  104: b.eq +900
  108: mov w2, #0xd40
  112: stp w10, w0, [sp, #0x10]
  116: add x0, sp, #0x20
  120: mov w1, wzr
  124: movk w2, #0x3, lsl #16
  128: bl <memset>
  132: mov x9, xzr
  136: mov x10, xzr
  140: mov x11, xzr
  144: mov w8, wzr
  148: mov x12, #-0x3
  152: mov x13, #-0x6
  156: mov w14, #0x8
  160: mov w15, #0x10
  164: mov w16, #0x14
  168: mov w17, #0x4
  172: mov w18, #0x6
  176: mov w0, #0xc
  180: mov w1, #0xf
  184: mov w2, #0x3
  188: mov w3, #0x3
  192: mov w4, #0x6
  196: mov w5, #0x8
  200: mov w6, #0xa
  204: mov w7, #0x2
  208: mov w27, #0x4
  212: b +300
  216: add x7, x7, #0x3
  220: add x27, x27, #0x6
  224: add x11, x11, #0x3
  228: add x10, x10, #0x9
  232: sub x9, x9, #0x9
  236: add x6, x6, #0xf
  240: add x5, x5, #0xc
  244: add x4, x4, #0x9
  248: add x3, x3, #0x9
  252: sub x12, x12, #0x9
  256: add x2, x2, #0x3
  260: add x1, x1, #0xf
  264: add x0, x0, #0xc
  268: add x18, x18, #0x6
  272: sub x13, x13, #0x9
  276: add x17, x17, #0x3
  280: cmp x7, x22
  284: add x16, x16, #0xf
  288: add x15, x15, #0xc
  292: add x14, x14, #0x6
  296: b.eq +84
  300: cmp x4, x25
  304: sub x20, x11, x11, lsl #2
  308: ldrb w23, [x24, x7]
  312: csel x19, x4, x25, hi
  316: cmp x3, x25
  320: str x19, [sp, #0x18]
  324: add x19, x11, x11, lsl #1
  328: csel x29, x3, x25, hi
  332: cmp x10, x25
  336: csel x30, x10, x25, hi
  340: cmp x19, x25
  344: csel x19, x19, x25, hi
  348: adds x19, x19, x20
  352: cset w20, ne
  356: csetm x21, ne
  360: cbnz w23, +504
  364: add x23, x28, #0x2
  368: add w8, w8, #0x1
  372: cmp x7, x23
  376: b.hs +504
  380: sub x20, x19, x20
  384: cmp x19, #0x0
  388: udiv x20, x20, x7
  392: cinc x23, x26, ne
  396: add x19, x23, x20
  400: mov x20, x27
  404: cmp x19, #0x4
  408: b.lo +488
  412: add x20, x30, x9
  416: add x20, x20, x21
  420: udiv x30, x20, x7
  424: and x20, x19, #0xfffffffffffffffc
  428: madd x20, x20, x7, x27
  432: add x23, x23, x30
  436: and x30, x23, #0xfffffffffffffffc
  440: add x23, sp, #0x20
  444: add x21, x23, x5
  448: strb w26, [x23, x27]
  452: subs x30, x30, #0x4
  456: strb w26, [x23, x4]
  460: strb w26, [x21]
  464: strb w26, [x23, x6]
  468: mov x23, x21
  472: b.ne +444
  476: and x21, x19, #0xfffffffffffffffc
  480: cmp x19, x21
  484: b.eq +504
  488: strb w26, [x24, x20]
  492: add x20, x20, x7
  496: cmp x20, x22
  500: b.lo +488
  504: add x19, x11, #0x1
  508: add x30, x7, #0x1
  512: add x20, x19, x19, lsl #1
  516: sub x19, x19, x19, lsl #2
  520: ldrb w23, [x24, x30]
  524: cmp x20, x25
  528: csel x20, x20, x25, hi
  532: adds x19, x20, x19
  536: cset w20, ne
  540: csetm x21, ne
  544: cbnz w23, +700
  548: add x23, x28, #0x1
  552: add w8, w8, #0x1
  556: cmp x7, x23
  560: b.hs +700
  564: sub x20, x19, x20
  568: cmp x19, #0x0
  572: udiv x20, x20, x30
  576: cinc x23, x26, ne
  580: add x19, x23, x20
  584: add x20, x27, #0x2
  588: cmp x19, #0x4
  592: b.lo +684
  596: add x29, x29, x12
  600: add x21, x29, x21
  604: udiv x29, x21, x2
  608: and x21, x19, #0xfffffffffffffffc
  612: madd x20, x21, x30, x20
  616: add x23, x23, x29
  620: and x29, x23, #0xfffffffffffffffc
  624: add x23, sp, #0x20
  628: add x21, x23, x10
  632: add x28, x23, x0
  636: strb w26, [x23, x18]
  640: strb w26, [x21, #0x9]
  644: subs x29, x29, #0x4
  648: strb w26, [x28]
  652: strb w26, [x23, x1]
  656: mov x23, x28
  660: b.ne +628
  664: and x21, x19, #0xfffffffffffffffc
  668: mov w28, #0x869e
  672: cmp x19, x21
  676: movk w28, #0x1, lsl #16
  680: b.eq +700
  684: strb w26, [x24, x20]
  688: add x20, x20, x30
  692: cmp x20, x22
  696: b.lo +684
  700: add x19, x11, #0x2
  704: add x29, x7, #0x2
  708: add x20, x19, x19, lsl #1
  712: sub x19, x19, x19, lsl #2
  716: ldrb w23, [x24, x29]
  720: cmp x20, x25
  724: csel x20, x20, x25, hi
  728: adds x19, x20, x19
  732: cset w20, ne
  736: csetm x21, ne
  740: cbnz w23, +216
  744: cmp x7, x28
  748: add w8, w8, #0x1
  752: b.hs +216
  756: sub x20, x19, x20
  760: cmp x19, #0x0
  764: udiv x20, x20, x29
  768: cinc x23, x26, ne
  772: add x19, x23, x20
  776: add x20, x27, #0x4
  780: cmp x19, #0x4
  784: b.lo +880
  788: ldr x28, [sp, #0x18]
  792: add x28, x28, x13
  796: add x21, x28, x21
  800: udiv x28, x21, x17
  804: and x21, x19, #0xfffffffffffffffc
  808: madd x20, x21, x29, x20
  812: add x23, x23, x28
  816: and x28, x23, #0xfffffffffffffffc
  820: add x23, sp, #0x20
  824: add x30, x23, x10
  828: add x21, x23, x15
  832: strb w26, [x23, x14]
  836: strb w26, [x30, #0xc]
  840: subs x28, x28, #0x4
  844: strb w26, [x21]
  848: strb w26, [x23, x16]
  852: mov x23, x21
  856: b.ne +824
  860: and x21, x19, #0xfffffffffffffffc
  864: mov w28, #0x869e
  868: cmp x19, x21
  872: movk w28, #0x1, lsl #16
  876: b.eq +216
  880: strb w26, [x24, x20]
  884: add x20, x20, x29
  888: cmp x20, x22
  892: b.lo +880
  896: b +216
  900: add sp, sp, #0x30, lsl #12
  904: add sp, sp, #0xd60
  908: ldp x20, x19, [sp, #0x50]
  912: ldp x22, x21, [sp, #0x40]
  916: ldp x24, x23, [sp, #0x30]
  920: ldp x26, x25, [sp, #0x20]
  924: ldp x28, x27, [sp, #0x10]
  928: ldp x29, x30, [sp], #0x60
  932: ret
```

#### `bench_gcd_lcm__U32` (156 instructions, 624 bytes)
```asm
    0: mov w8, wzr
    4: cbz w0, +616
    8: mov w9, wzr
   12: mov w10, #0x1
   16: mov w11, #0x1
   20: mov w13, w10
   24: mov w14, w11
   28: mov w12, w14
   32: udiv w14, w13, w14
   36: msub w14, w14, w12, w13
   40: mov w13, w12
   44: cbnz w14, +28
   48: add w8, w12, w8
   52: add w12, w11, #0x1
   56: mov w14, w10
   60: mov w13, w12
   64: udiv w12, w14, w12
   68: msub w12, w12, w13, w14
   72: mov w14, w13
   76: cbnz w12, +60
   80: add w8, w13, w8
   84: add w12, w11, #0x2
   88: mov w14, w10
   92: mov w13, w12
   96: udiv w12, w14, w12
  100: msub w12, w12, w13, w14
  104: mov w14, w13
  108: cbnz w12, +92
  112: add w8, w13, w8
  116: add w13, w11, #0x3
  120: mov w14, w10
  124: mov w12, w13
  128: udiv w13, w14, w13
  132: msub w13, w13, w12, w14
  136: mov w14, w12
  140: cbnz w13, +124
  144: add w11, w11, #0x4
  148: add w8, w12, w8
  152: cmp w11, #0x191
  156: b.ne +20
  160: mov w11, #0x1
  164: add w13, w10, #0x1
  168: mov w14, w11
  172: mov w12, w14
  176: udiv w14, w13, w14
  180: msub w14, w14, w12, w13
  184: mov w13, w12
  188: cbnz w14, +172
  192: add w8, w12, w8
  196: add w12, w11, #0x1
  200: add w14, w10, #0x1
  204: mov w13, w12
  208: udiv w12, w14, w12
  212: msub w12, w12, w13, w14
  216: mov w14, w13
  220: cbnz w12, +204
  224: add w8, w13, w8
  228: add w12, w11, #0x2
  232: add w14, w10, #0x1
  236: mov w13, w12
  240: udiv w12, w14, w12
  244: msub w12, w12, w13, w14
  248: mov w14, w13
  252: cbnz w12, +236
  256: add w8, w13, w8
  260: add w13, w11, #0x3
  264: add w14, w10, #0x1
  268: mov w12, w13
  272: udiv w13, w14, w13
  276: msub w13, w13, w12, w14
  280: mov w14, w12
  284: cbnz w13, +268
  288: add w11, w11, #0x4
  292: add w8, w12, w8
  296: cmp w11, #0x191
  300: b.ne +164
  304: mov w11, #0x1
  308: add w13, w10, #0x2
  312: mov w14, w11
  316: mov w12, w14
  320: udiv w14, w13, w14
  324: msub w14, w14, w12, w13
  328: mov w13, w12
  332: cbnz w14, +316
  336: add w8, w12, w8
  340: add w12, w11, #0x1
  344: add w14, w10, #0x2
  348: mov w13, w12
  352: udiv w12, w14, w12
  356: msub w12, w12, w13, w14
  360: mov w14, w13
  364: cbnz w12, +348
  368: add w8, w13, w8
  372: add w12, w11, #0x2
  376: add w14, w10, #0x2
  380: mov w13, w12
  384: udiv w12, w14, w12
  388: msub w12, w12, w13, w14
  392: mov w14, w13
  396: cbnz w12, +380
  400: add w8, w13, w8
  404: add w13, w11, #0x3
  408: add w14, w10, #0x2
  412: mov w12, w13
  416: udiv w13, w14, w13
  420: msub w13, w13, w12, w14
  424: mov w14, w12
  428: cbnz w13, +412
  432: add w11, w11, #0x4
  436: add w8, w12, w8
  440: cmp w11, #0x191
  444: b.ne +308
  448: mov w11, #0x1
  452: add w13, w10, #0x3
  456: mov w14, w11
  460: mov w12, w14
  464: udiv w14, w13, w14
  468: msub w14, w14, w12, w13
  472: mov w13, w12
  476: cbnz w14, +460
  480: add w8, w12, w8
  484: add w12, w11, #0x1
  488: add w14, w10, #0x3
  492: mov w13, w12
  496: udiv w12, w14, w12
  500: msub w12, w12, w13, w14
  504: mov w14, w13
  508: cbnz w12, +492
  512: add w8, w13, w8
  516: add w12, w11, #0x2
  520: add w14, w10, #0x3
  524: mov w13, w12
  528: udiv w12, w14, w12
  532: msub w12, w12, w13, w14
  536: mov w14, w13
  540: cbnz w12, +524
  544: add w8, w13, w8
  548: add w13, w11, #0x3
  552: add w14, w10, #0x3
  556: mov w12, w13
  560: udiv w13, w14, w13
  564: msub w13, w13, w12, w14
  568: mov w14, w12
  572: cbnz w13, +556
  576: add w11, w11, #0x4
  580: add w8, w12, w8
  584: cmp w11, #0x191
  588: b.ne +452
  592: add w10, w10, #0x4
  596: cmp w10, #0x191
  600: b.ne +16
  604: add w9, w9, #0x1
  608: cmp w9, w0
  612: b.ne +12
  616: mov w0, w8
  620: ret
```

#### `bench_binary_search__U32` (92 instructions, 368 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x4, lsl #12
   12: mov w19, w0
   16: mov x0, sp
   20: mov w1, wzr
   24: mov w2, #0x4000
   28: mov x20, sp
   32: bl <memset>
   36: mov x8, xzr
   40: add x9, x20, #0x20
   44: add w10, w8, #0x3
   48: add w11, w8, #0xa
   52: add w12, w8, #0x65
   56: stp w10, w11, [x9, #-0x20]
   60: add w10, w8, #0x11
   64: add w11, w8, #0x18
   68: stp w10, w11, [x9, #-0x18]
   72: add w10, w8, #0x1f
   76: add w11, w8, #0x26
   80: stp w10, w11, [x9, #-0x10]
   84: add w10, w8, #0x2d
   88: add w11, w8, #0x34
   92: stp w10, w11, [x9, #-0x8]
   96: add w10, w8, #0x3b
  100: add w11, w8, #0x42
  104: stp w10, w11, [x9]
  108: add w10, w8, #0x49
  112: add w11, w8, #0x50
  116: stp w10, w11, [x9, #0x8]
  120: add w10, w8, #0x57
  124: add w11, w8, #0x5e
  128: stp w10, w11, [x9, #0x10]
  132: add w10, w8, #0x6c
  136: add x8, x8, #0x70
  140: cmp x8, #0x7, lsl #12
  144: stp w12, w10, [x9, #0x18]
  148: add x9, x9, #0x40
  152: b.ne +44
  156: mov w8, #0x86a0
  160: movk w8, #0x1, lsl #16
  164: mul w8, w19, w8
  168: cbz w8, +348
  172: mov w13, #0x660d
  176: mov w14, #0xf35f
  180: mov w15, #0xb273
  184: mov w9, wzr
  188: mov w11, wzr
  192: mov w10, wzr
  196: mov w12, #0x3039
  200: movk w13, #0x19, lsl #16
  204: movk w14, #0x3c6e, lsl #16
  208: movk w15, #0x45e7, lsl #16
  212: mov w16, #0x7530
  216: mov x17, sp
  220: b +236
  224: add w11, w11, #0x1
  228: cmp w11, w8
  232: b.eq +324
  236: madd w12, w12, w13, w14
  240: mov w18, wzr
  244: mov w1, #0x1000
  248: umull x0, w12, w15
  252: lsr x0, x0, #45
  256: msub w0, w0, w16, w12
  260: add w2, w1, w18
  264: lsr w2, w2, #1
  268: ldr w3, [x17, w2, uxtw #2]
  272: cmp w3, w0
  276: csinc w18, w18, w2, hs
  280: csel w1, w2, w1, hs
  284: cmp w18, w1
  288: b.lo +260
  292: cmp w18, #0xfff
  296: b.hi +224
  300: ldr w1, [x17, w18, uxtw #2]
  304: cmp w1, w0
  308: b.ne +224
  312: add w9, w9, #0x1
  316: add w10, w18, w10
  320: b +224
  324: add w8, w10, w10, lsl #1
  328: add w0, w9, w8
  332: add sp, sp, #0x4, lsl #12
  336: ldp x20, x19, [sp, #0x10]
  340: ldp x29, x30, [sp], #0x20
  344: ret
  348: mov w0, wzr
  352: add sp, sp, #0x4, lsl #12
  356: ldp x20, x19, [sp, #0x10]
  360: ldp x29, x30, [sp], #0x20
  364: ret
```

#### `quick__Array_U32_Int_Int` (46 instructions, 184 bytes)
```asm
    0: cmp w1, w2
    4: b.ge +180
    8: stp x30, x21, [sp, #-0x20]!
   12: stp x20, x19, [sp, #0x10]
   16: mov w19, w2
   20: mov x20, x0
   24: b +48
   28: mov x0, x20
   32: bl +0
   36: cmp w21, w19
   40: mov w1, w21
   44: b.ge +172
   48: add w8, w1, w19
   52: mov w21, w1
   56: mov w2, w19
   60: asr w8, w8, #1
   64: ldr w8, [x20, w8, sxtw #2]
   68: b +92
   72: add x12, x20, x2, lsl #2
   76: stur w11, [x10, #-0x4]
   80: str w9, [x12, #0x4]
   84: cmp w21, w2
   88: b.gt +28
   92: sxtw x21, w21
   96: ldr w9, [x20, x21, lsl #2]
  100: add x21, x21, #0x1
  104: cmp w9, w8
  108: b.lo +96
  112: add x10, x20, x21, lsl #2
  116: sub x12, x21, #0x1
  120: sxtw x2, w2
  124: ldr w11, [x20, x2, lsl #2]
  128: sub x2, x2, #0x1
  132: cmp w11, w8
  136: b.hi +124
  140: add x13, x2, #0x1
  144: cmp x12, x13
  148: b.le +72
  152: sub w21, w21, #0x1
  156: add w2, w2, #0x1
  160: cmp w21, w2
  164: b.le +92
  168: b +28
  172: ldp x20, x19, [sp, #0x10]
  176: ldp x30, x21, [sp], #0x20
  180: ret
```

#### `bench_quicksort__U32` (79 instructions, 316 bytes)
```asm
    0: str x29, [sp, #-0x50]!
    4: stp x30, x25, [sp, #0x10]
    8: stp x24, x23, [sp, #0x20]
   12: stp x22, x21, [sp, #0x30]
   16: stp x20, x19, [sp, #0x40]
   20: sub sp, sp, #0x2, lsl #12
   24: mov w19, w0
   28: mov x0, sp
   32: mov w1, wzr
   36: mov w2, #0x2000
   40: mov x20, sp
   44: bl <memset>
   48: add w8, w19, w19, lsl #2
   52: mov w19, wzr
   56: lsl w21, w8, #3
   60: cbz w21, +284
   64: mov w23, #0xf35f
   68: mov w24, #0x660d
   72: mov w22, wzr
   76: movk w23, #0x3c6e, lsl #16
   80: movk w24, #0x19, lsl #16
   84: mov w25, #0x309
   88: mov x8, xzr
   92: madd w9, w25, w24, w23
   96: add x12, x20, x8
  100: add x8, x8, #0x10
  104: cmp x8, #0x2, lsl #12
  108: madd w10, w9, w24, w23
  112: lsr w9, w9, #4
  116: madd w11, w10, w24, w23
  120: lsr w10, w10, #4
  124: stp w9, w10, [x12]
  128: madd w25, w11, w24, w23
  132: lsr w11, w11, #4
  136: lsr w9, w25, #4
  140: stp w11, w9, [x12, #0x8]
  144: b.ne +92
  148: mov x0, sp
  152: mov w1, wzr
  156: mov w2, #0x7ff
  160: bl <quick__Array_U32_Int_Int>
  164: mov x8, xzr
  168: mov w10, wzr
  172: add x9, x20, #0x10
  176: ldp w11, w12, [x9, #-0x10]
  180: add w13, w8, #0x2
  184: add w16, w8, #0x4
  188: ldp w14, w15, [x9, #-0x8]
  192: madd w11, w11, w8, w11
  196: madd w10, w12, w13, w10
  200: ldp w13, w12, [x9]
  204: madd w10, w15, w16, w10
  208: add w15, w8, #0x6
  212: add w11, w11, w19
  216: madd w10, w12, w15, w10
  220: add w12, w8, #0x3
  224: add w15, w8, #0x5
  228: madd w11, w14, w12, w11
  232: ldp w12, w14, [x9, #0x8]
  236: madd w11, w13, w15, w11
  240: add w13, w8, #0x7
  244: add x8, x8, #0x8
  248: cmp x8, #0x800
  252: add x9, x9, #0x20
  256: madd w19, w12, w13, w11
  260: madd w10, w14, w8, w10
  264: b.ne +176
  268: add w22, w22, #0x1
  272: add w19, w10, w19
  276: cmp w22, w21
  280: b.ne +88
  284: mov w0, w19
  288: add sp, sp, #0x2, lsl #12
  292: ldp x20, x19, [sp, #0x40]
  296: ldp x22, x21, [sp, #0x30]
  300: ldp x24, x23, [sp, #0x20]
  304: ldp x30, x25, [sp, #0x10]
  308: ldr x29, [sp], #0x50
  312: ret
```

#### `bench_heapsort__U32` (338 instructions, 1352 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x2, lsl #12
   12: mov w19, w0
   16: mov x0, sp
   20: mov w1, wzr
   24: mov w2, #0x2000
   28: mov x20, sp
   32: bl <memset>
   36: add w8, w19, w19, lsl #1
   40: mov w0, wzr
   44: lsl w8, w8, #3
   48: cbz w8, +1336
   52: mov w10, #0xf35f
   56: mov w11, #0x660d
   60: mov w9, wzr
   64: movk w10, #0x3c6e, lsl #16
   68: movk w11, #0x19, lsl #16
   72: mov w12, #0x1092
   76: mov x13, xzr
   80: madd w12, w12, w11, w10
   84: add x17, x20, x13
   88: add x13, x13, #0x10
   92: cmp x13, #0x2, lsl #12
   96: madd w14, w12, w11, w10
  100: lsr w16, w12, #4
  104: madd w15, w14, w11, w10
  108: lsr w14, w14, #4
  112: stp w16, w14, [x17]
  116: madd w12, w15, w11, w10
  120: lsr w15, w15, #4
  124: lsr w14, w12, #4
  128: stp w15, w14, [x17, #0x8]
  132: b.ne +80
  136: mov w13, #0x3ff
  140: b +152
  144: sub x13, x13, #0x4
  148: cbz x14, +640
  152: ldr w14, [x20, x13, lsl #2]
  156: lsl w17, w13, #1
  160: mov w15, w13
  164: sxtw x17, w17
  168: orr x16, x17, #0x1
  172: ldr w18, [x20, x16, lsl #2]
  176: cmp w14, w18
  180: b.hs +204
  184: cmp w17, #0x7fd
  188: b.le +216
  192: cmp w16, w15
  196: b.ne +244
  200: b +272
  204: mov w16, w15
  208: cmp w17, #0x7fd
  212: b.gt +192
  216: add x17, x17, #0x2
  220: ldr w18, [x20, w16, sxtw #2]
  224: ldr w1, [x20, x17, lsl #2]
  228: cmp w18, w1
  232: csel w16, w17, w16, lo
  236: cmp w16, w15
  240: b.eq +272
  244: lsl w17, w16, #1
  248: ldr w18, [x20, w16, sxtw #2]
  252: str w18, [x20, w15, sxtw #2]
  256: mov w15, w16
  260: cmp w17, #0x7ff
  264: str w14, [x20, w16, sxtw #2]
  268: b.lt +164
  272: sub x15, x13, #0x1
  276: ldr w14, [x20, x15, lsl #2]
  280: lsl w17, w15, #1
  284: sxtw x17, w17
  288: orr x16, x17, #0x1
  292: ldr w18, [x20, x16, lsl #2]
  296: cmp w14, w18
  300: b.hs +324
  304: cmp w17, #0x7fd
  308: b.le +336
  312: cmp w16, w15
  316: b.ne +364
  320: b +392
  324: mov w16, w15
  328: cmp w17, #0x7fd
  332: b.gt +312
  336: add x17, x17, #0x2
  340: ldr w18, [x20, w16, sxtw #2]
  344: ldr w1, [x20, x17, lsl #2]
  348: cmp w18, w1
  352: csel w16, w17, w16, lo
  356: cmp w16, w15
  360: b.eq +392
  364: lsl w17, w16, #1
  368: ldr w18, [x20, w16, sxtw #2]
  372: str w18, [x20, w15, sxtw #2]
  376: mov w15, w16
  380: cmp w17, #0x7ff
  384: str w14, [x20, w16, sxtw #2]
  388: b.lt +284
  392: sub x15, x13, #0x2
  396: ldr w14, [x20, x15, lsl #2]
  400: lsl w17, w15, #1
  404: sxtw x17, w17
  408: orr x16, x17, #0x1
  412: ldr w18, [x20, x16, lsl #2]
  416: cmp w14, w18
  420: b.hs +444
  424: cmp w17, #0x7fd
  428: b.le +456
  432: cmp w16, w15
  436: b.ne +484
  440: b +512
  444: mov w16, w15
  448: cmp w17, #0x7fd
  452: b.gt +432
  456: add x17, x17, #0x2
  460: ldr w18, [x20, w16, sxtw #2]
  464: ldr w1, [x20, x17, lsl #2]
  468: cmp w18, w1
  472: csel w16, w17, w16, lo
  476: cmp w16, w15
  480: b.eq +512
  484: lsl w17, w16, #1
  488: ldr w18, [x20, w16, sxtw #2]
  492: str w18, [x20, w15, sxtw #2]
  496: mov w15, w16
  500: cmp w17, #0x7ff
  504: str w14, [x20, w16, sxtw #2]
  508: b.lt +404
  512: sub x16, x13, #0x3
  516: sub x14, x13, #0x3
  520: ldr w15, [x20, x16, lsl #2]
  524: lsl w18, w16, #1
  528: sxtw x18, w18
  532: orr x17, x18, #0x1
  536: ldr w1, [x20, x17, lsl #2]
  540: cmp w15, w1
  544: b.hs +568
  548: cmp w18, #0x7fd
  552: b.le +580
  556: cmp w17, w16
  560: b.ne +608
  564: b +144
  568: mov w17, w16
  572: cmp w18, #0x7fd
  576: b.gt +556
  580: add x18, x18, #0x2
  584: ldr w1, [x20, w17, sxtw #2]
  588: ldr w2, [x20, x18, lsl #2]
  592: cmp w1, w2
  596: csel w17, w18, w17, lo
  600: cmp w17, w16
  604: b.eq +144
  608: lsl w18, w17, #1
  612: ldr w1, [x20, w17, sxtw #2]
  616: str w1, [x20, w16, sxtw #2]
  620: mov w16, w17
  624: cmp w18, #0x7ff
  628: str w15, [x20, w17, sxtw #2]
  632: b.lt +528
  636: b +144
  640: mov w13, #0x7ff
  644: ldr w15, [x20, x13, lsl #2]
  648: ldr w14, [sp]
  652: mov w18, wzr
  656: mov w16, wzr
  660: str w15, [sp]
  664: str w14, [x20, x13, lsl #2]
  668: sub x14, x13, #0x1
  672: sxtw x18, w18
  676: orr x17, x18, #0x1
  680: ldr w1, [x20, x17, lsl #2]
  684: cmp w15, w1
  688: b.hs +716
  692: add x18, x18, #0x2
  696: cmp x13, x18
  700: b.gt +732
  704: cmp w17, w16
  708: b.ne +756
  712: b +784
  716: mov w17, w16
  720: add x18, x18, #0x2
  724: cmp x13, x18
  728: b.le +704
  732: ldr w1, [x20, w17, sxtw #2]
  736: ldr w2, [x20, x18, lsl #2]
  740: cmp w1, w2
  744: csel w17, w18, w17, lo
  748: cmp w17, w16
  752: b.eq +784
  756: lsl w18, w17, #1
  760: ldr w1, [x20, w17, sxtw #2]
  764: str w1, [x20, w16, sxtw #2]
  768: mov w16, w17
  772: cmp x14, w18, sxtw
  776: str w15, [x20, w17, sxtw #2]
  780: b.gt +672
  784: ldr w16, [x20, x14, lsl #2]
  788: ldr w15, [sp]
  792: mov w1, wzr
  796: mov w17, wzr
  800: str w16, [sp]
  804: str w15, [x20, x14, lsl #2]
  808: sub x15, x13, #0x2
  812: sxtw x1, w1
  816: orr x18, x1, #0x1
  820: ldr w2, [x20, x18, lsl #2]
  824: cmp w16, w2
  828: b.hs +856
  832: add x1, x1, #0x2
  836: cmp x14, x1
  840: b.gt +872
  844: cmp w18, w17
  848: b.ne +896
  852: b +924
  856: mov w18, w17
  860: add x1, x1, #0x2
  864: cmp x14, x1
  868: b.le +844
  872: ldr w2, [x20, w18, sxtw #2]
  876: ldr w3, [x20, x1, lsl #2]
  880: cmp w2, w3
  884: csel w18, w1, w18, lo
  888: cmp w18, w17
  892: b.eq +924
  896: lsl w1, w18, #1
  900: ldr w2, [x20, w18, sxtw #2]
  904: str w2, [x20, w17, sxtw #2]
  908: mov w17, w18
  912: cmp x15, w1, sxtw
  916: str w16, [x20, w18, sxtw #2]
  920: b.gt +812
  924: ldr w16, [x20, x15, lsl #2]
  928: ldr w17, [sp]
  932: subs x14, x13, #0x3
  936: str w16, [sp]
  940: str w17, [x20, x15, lsl #2]
  944: b.le +1216
  948: mov w1, wzr
  952: mov w17, wzr
  956: sxtw x1, w1
  960: orr x18, x1, #0x1
  964: ldr w2, [x20, x18, lsl #2]
  968: cmp w16, w2
  972: b.hs +1000
  976: add x1, x1, #0x2
  980: cmp x15, x1
  984: b.gt +1016
  988: cmp w18, w17
  992: b.ne +1040
  996: b +1068
 1000: mov w18, w17
 1004: add x1, x1, #0x2
 1008: cmp x15, x1
 1012: b.le +988
 1016: ldr w2, [x20, w18, sxtw #2]
 1020: ldr w3, [x20, x1, lsl #2]
 1024: cmp w2, w3
 1028: csel w18, w1, w18, lo
 1032: cmp w18, w17
 1036: b.eq +1068
 1040: lsl w1, w18, #1
 1044: ldr w2, [x20, w18, sxtw #2]
 1048: str w2, [x20, w17, sxtw #2]
 1052: mov w17, w18
 1056: cmp x14, w1, sxtw
 1060: str w16, [x20, w18, sxtw #2]
 1064: b.gt +956
 1068: cbz x14, +1216
 1072: ldr w15, [x20, x14, lsl #2]
 1076: mov w18, wzr
 1080: mov w16, wzr
 1084: ldr w17, [sp]
 1088: sub x13, x13, #0x4
 1092: str w15, [sp]
 1096: str w17, [x20, x14, lsl #2]
 1100: sxtw x18, w18
 1104: orr x17, x18, #0x1
 1108: ldr w1, [x20, x17, lsl #2]
 1112: cmp w15, w1
 1116: b.hs +1144
 1120: add x18, x18, #0x2
 1124: cmp x14, x18
 1128: b.gt +1160
 1132: cmp w17, w16
 1136: b.ne +1184
 1140: b +644
 1144: mov w17, w16
 1148: add x18, x18, #0x2
 1152: cmp x14, x18
 1156: b.le +1132
 1160: ldr w1, [x20, w17, sxtw #2]
 1164: ldr w2, [x20, x18, lsl #2]
 1168: cmp w1, w2
 1172: csel w17, w18, w17, lo
 1176: cmp w17, w16
 1180: b.eq +644
 1184: lsl w18, w17, #1
 1188: ldr w1, [x20, w17, sxtw #2]
 1192: str w1, [x20, w16, sxtw #2]
 1196: mov w16, w17
 1200: cmp x13, w18, sxtw
 1204: str w15, [x20, w17, sxtw #2]
 1208: b.gt +1100
 1212: b +644
 1216: mov x13, xzr
 1220: mov w15, wzr
 1224: add x14, x20, #0x10
 1228: ldp w16, w17, [x14, #-0x10]
 1232: add w18, w13, #0x2
 1236: add w3, w13, #0x4
 1240: ldp w1, w2, [x14, #-0x8]
 1244: madd w16, w16, w13, w16
 1248: madd w15, w17, w18, w15
 1252: ldp w18, w17, [x14]
 1256: madd w15, w2, w3, w15
 1260: add w2, w13, #0x6
 1264: add w16, w16, w0
 1268: add w0, w13, #0x5
 1272: madd w15, w17, w2, w15
 1276: add w17, w13, #0x3
 1280: madd w16, w1, w17, w16
 1284: ldp w17, w1, [x14, #0x8]
 1288: madd w16, w18, w0, w16
 1292: add w18, w13, #0x7
 1296: add x13, x13, #0x8
 1300: cmp x13, #0x800
 1304: add x14, x14, #0x20
 1308: madd w0, w17, w18, w16
 1312: madd w15, w1, w13, w15
 1316: b.ne +1228
 1320: add w9, w9, #0x1
 1324: add w0, w15, w0
 1328: cmp w9, w8
 1332: b.ne +76
 1336: add sp, sp, #0x2, lsl #12
 1340: ldp x20, x19, [sp, #0x10]
 1344: ldp x29, x30, [sp], #0x20
 1348: ret
```

#### `bench_knapsack__U32` (340 instructions, 1360 bytes)
```asm
    0: str x29, [sp, #-0x60]!
    4: stp x30, x27, [sp, #0x10]
    8: stp x26, x25, [sp, #0x20]
   12: stp x24, x23, [sp, #0x30]
   16: stp x22, x21, [sp, #0x40]
   20: stp x20, x19, [sp, #0x50]
   24: sub sp, sp, #0x1, lsl #12
   28: sub sp, sp, #0x980
   32: mov w19, w0
   36: add x0, sp, #0x1, lsl #12
   40: mov w20, #0xf35f
   44: mov w21, #0x660d
   48: add x0, x0, #0x880
   52: mov w1, wzr
   56: mov w2, #0x100
   60: add x22, sp, #0x1, lsl #12
   64: movk w20, #0x3c6e, lsl #16
   68: movk w21, #0x19, lsl #16
   72: add x22, x22, #0x880
   76: bl <memset>
   80: add x0, sp, #0x1, lsl #12
   84: mov w1, wzr
   88: mov w2, #0x100
   92: add x0, x0, #0x780
   96: add x23, sp, #0x1, lsl #12
  100: add x23, x23, #0x780
  104: bl <memset>
  108: mov w11, #0x3e46
  112: mov w13, #0xa0fe
  116: add x8, x23, #0x8
  120: add x9, x22, #0x8
  124: mov w15, #0x63
  128: mov w10, #0x40
  132: movk w11, #0x6eb, lsl #16
  136: mov w12, #0x25
  140: movk w13, #0x2a3, lsl #16
  144: mov w14, #0x61
  148: madd w15, w15, w21, w20
  152: subs x10, x10, #0x4
  156: madd w16, w15, w21, w20
  160: lsr w15, w15, #8
  164: umull x0, w15, w11
  168: madd w17, w16, w21, w20
  172: lsr w16, w16, #8
  176: umull x2, w16, w13
  180: lsr x0, x0, #32
  184: madd w18, w17, w21, w20
  188: lsr w17, w17, #8
  192: msub w0, w0, w12, w15
  196: lsr x15, x2, #32
  200: umull x3, w17, w11
  204: madd w1, w18, w21, w20
  208: lsr w18, w18, #8
  212: msub w16, w15, w14, w16
  216: add w0, w0, #0x3
  220: umull x2, w18, w13
  224: lsr x3, x3, #32
  228: madd w4, w1, w21, w20
  232: lsr w1, w1, #8
  236: msub w17, w3, w12, w17
  240: add w16, w16, #0x1
  244: lsr x2, x2, #32
  248: umull x3, w1, w11
  252: madd w5, w4, w21, w20
  256: lsr w4, w4, #8
  260: msub w18, w2, w14, w18
  264: add w17, w17, #0x3
  268: umull x7, w4, w13
  272: lsr x3, x3, #32
  276: stp w0, w17, [x9, #-0x8]
  280: madd w15, w5, w21, w20
  284: lsr w2, w5, #8
  288: msub w17, w3, w12, w1
  292: add w18, w18, #0x1
  296: umull x5, w2, w11
  300: lsr x0, x7, #32
  304: stp w16, w18, [x8, #-0x8]
  308: lsr w6, w15, #8
  312: msub w0, w0, w14, w4
  316: add w17, w17, #0x3
  320: umull x22, w6, w13
  324: lsr x5, x5, #32
  328: msub w1, w5, w12, w2
  332: lsr x2, x22, #32
  336: msub w16, w2, w14, w6
  340: add w18, w1, #0x3
  344: stp w17, w18, [x9], #0x10
  348: add w17, w0, #0x1
  352: add w16, w16, #0x1
  356: stp w17, w16, [x8], #0x10
  360: b.ne +148
  364: add w8, w19, w19, lsl #1
  368: mov w19, wzr
  372: lsl w20, w8, #1
  376: cbz w20, +1316
  380: mov w8, #0x1770
  384: add x22, sp, #0xc
  388: add x23, sp, #0x1, lsl #12
  392: add x25, sp, #0x1, lsl #12
  396: mov w21, wzr
  400: add x23, x23, #0x880
  404: add x24, x22, x8
  408: add x25, x25, #0x780
  412: mov w26, #0x5dd
  416: mov w27, #0x5dc
  420: b +444
  424: ldr w8, [sp, #0x177c]
  428: add w21, w21, #0x1
  432: cmp w21, w20
  436: add w19, w8, w19
  440: b.eq +1316
  444: add x0, sp, #0xc
  448: mov w1, wzr
  452: mov w2, #0x1774
  456: bl <memset>
  460: mov x8, xzr
  464: b +480
  468: add x8, x8, #0x4
  472: cmp x8, #0x40
  476: b.eq +424
  480: ldr w9, [x23, x8, lsl #2]
  484: tbnz w9, #0x1f, +1356
  488: cmp w9, #0x5dc
  492: b.hi +684
  496: sub x12, x26, x9
  500: ldr w10, [x25, x8, lsl #2]
  504: cmp x12, #0x4
  508: b.hs +520
  512: mov w11, #0x5dc
  516: b +636
  520: and x13, x12, #0xfffffffffffffffc
  524: neg x14, x9, lsl #2
  528: and x15, x12, #0xfffffffffffffffc
  532: sub x11, x27, x13
  536: mov x16, x24
  540: add x17, x16, x14
  544: ldp w2, w1, [x17, #-0x4]
  548: ldp w0, w18, [x16, #-0x4]
  552: ldp w17, w3, [x17, #-0xc]
  556: ldp w5, w4, [x16, #-0xc]
  560: add w1, w1, w10
  564: add w2, w2, w10
  568: cmp w18, w1
  572: add w3, w3, w10
  576: add w17, w17, w10
  580: csel w18, w18, w1, gt
  584: cmp w0, w2
  588: csel w0, w0, w2, gt
  592: cmp w4, w3
  596: stp w0, w18, [x16, #-0x4]
  600: csel w18, w4, w3, gt
  604: cmp w5, w17
  608: csel w17, w5, w17, gt
  612: subs x15, x15, #0x4
  616: stp w17, w18, [x16, #-0xc]
  620: sub x16, x16, #0x10
  624: b.ne +540
  628: cmp x12, x13
  632: b.eq +684
  636: neg x12, x9, lsl #2
  640: add x13, x22, x11, lsl #2
  644: add x11, x11, #0x1
  648: ldr w14, [x13, x12]
  652: ldr w15, [x13]
  656: sub x11, x11, #0x1
  660: add w14, w14, w10
  664: cmp w15, w14
  668: csel w14, w15, w14, gt
  672: cmp x11, x9
  676: str w14, [x13], #-0x4
  680: b.hi +648
  684: lsl x9, x8, #2
  688: orr x11, x9, #0x4
  692: ldr w10, [x23, x11]
  696: tbnz w10, #0x1f, +1356
  700: cmp w10, #0x5dc
  704: b.hi +896
  708: sub x13, x26, x10
  712: ldr w11, [x25, x11]
  716: cmp x13, #0x4
  720: b.hs +732
  724: mov w12, #0x5dc
  728: b +848
  732: and x14, x13, #0xfffffffffffffffc
  736: sub x15, x24, x10, lsl #2
  740: mov x16, x24
  744: sub x12, x27, x14
  748: and x17, x13, #0xfffffffffffffffc
  752: ldp w2, w18, [x15, #-0x4]
  756: ldp w1, w0, [x16, #-0x4]
  760: ldp w6, w3, [x15, #-0xc]
  764: add w18, w18, w11
  768: add w2, w2, w11
  772: sub x17, x17, #0x4
  776: ldp w5, w4, [x16, #-0xc]
  780: cmp w0, w18
  784: add w3, w3, w11
  788: add w6, w6, w11
  792: csel w18, w0, w18, gt
  796: cmp w1, w2
  800: sub x15, x15, #0x10
  804: csel w0, w1, w2, gt
  808: cmp w4, w3
  812: stp w0, w18, [x16, #-0x4]
  816: csel w18, w4, w3, gt
  820: cmp w5, w6
  824: csel w0, w5, w6, gt
  828: stp w0, w18, [x16, #-0xc]
  832: sub x16, x16, #0x10
  836: cbnz x17, +752
  840: cmp x13, x14
  844: b.eq +896
  848: neg x13, x10, lsl #2
  852: add x14, x22, x12, lsl #2
  856: add x12, x12, #0x1
  860: ldr w15, [x14, x13]
  864: ldr w16, [x14]
  868: sub x12, x12, #0x1
  872: add w15, w15, w11
  876: cmp w16, w15
  880: csel w15, w16, w15, gt
  884: cmp x12, x10
  888: str w15, [x14], #-0x4
  892: b.hi +860
  896: orr x11, x9, #0x8
  900: ldr w10, [x23, x11]
  904: tbnz w10, #0x1f, +1356
  908: cmp w10, #0x5dc
  912: b.hi +1104
  916: sub x13, x26, x10
  920: ldr w11, [x25, x11]
  924: cmp x13, #0x4
  928: b.hs +940
  932: mov w12, #0x5dc
  936: b +1056
  940: and x14, x13, #0xfffffffffffffffc
  944: sub x15, x24, x10, lsl #2
  948: mov x16, x24
  952: sub x12, x27, x14
  956: and x17, x13, #0xfffffffffffffffc
  960: ldp w2, w18, [x15, #-0x4]
  964: ldp w1, w0, [x16, #-0x4]
  968: ldp w6, w3, [x15, #-0xc]
  972: add w18, w18, w11
  976: add w2, w2, w11
  980: sub x17, x17, #0x4
  984: ldp w5, w4, [x16, #-0xc]
  988: cmp w0, w18
  992: add w3, w3, w11
  996: add w6, w6, w11
 1000: csel w18, w0, w18, gt
 1004: cmp w1, w2
 1008: sub x15, x15, #0x10
 1012: csel w0, w1, w2, gt
 1016: cmp w4, w3
 1020: stp w0, w18, [x16, #-0x4]
 1024: csel w18, w4, w3, gt
 1028: cmp w5, w6
 1032: csel w0, w5, w6, gt
 1036: stp w0, w18, [x16, #-0xc]
 1040: sub x16, x16, #0x10
 1044: cbnz x17, +960
 1048: cmp x13, x14
 1052: b.eq +1104
 1056: neg x13, x10, lsl #2
 1060: add x14, x22, x12, lsl #2
 1064: add x12, x12, #0x1
 1068: ldr w15, [x14, x13]
 1072: ldr w16, [x14]
 1076: sub x12, x12, #0x1
 1080: add w15, w15, w11
 1084: cmp w16, w15
 1088: csel w15, w16, w15, gt
 1092: cmp x12, x10
 1096: str w15, [x14], #-0x4
 1100: b.hi +1068
 1104: orr x10, x9, #0xc
 1108: ldr w9, [x23, x10]
 1112: tbnz w9, #0x1f, +1356
 1116: cmp w9, #0x5dc
 1120: b.hi +468
 1124: sub x12, x26, x9
 1128: ldr w10, [x25, x10]
 1132: cmp x12, #0x4
 1136: b.hs +1148
 1140: mov w11, #0x5dc
 1144: b +1264
 1148: and x13, x12, #0xfffffffffffffffc
 1152: sub x14, x24, x9, lsl #2
 1156: mov x15, x24
 1160: sub x11, x27, x13
 1164: and x16, x12, #0xfffffffffffffffc
 1168: ldp w1, w17, [x14, #-0x4]
 1172: ldp w0, w18, [x15, #-0x4]
 1176: ldp w5, w2, [x14, #-0xc]
 1180: add w17, w17, w10
 1184: add w1, w1, w10
 1188: sub x16, x16, #0x4
 1192: ldp w4, w3, [x15, #-0xc]
 1196: cmp w18, w17
 1200: add w2, w2, w10
 1204: add w5, w5, w10
 1208: csel w17, w18, w17, gt
 1212: cmp w0, w1
 1216: sub x14, x14, #0x10
 1220: csel w18, w0, w1, gt
 1224: cmp w3, w2
 1228: stp w18, w17, [x15, #-0x4]
 1232: csel w17, w3, w2, gt
 1236: cmp w4, w5
 1240: csel w18, w4, w5, gt
 1244: stp w18, w17, [x15, #-0xc]
 1248: sub x15, x15, #0x10
 1252: cbnz x16, +1168
 1256: cmp x12, x13
 1260: b.eq +468
 1264: neg x12, x9, lsl #2
 1268: add x13, x22, x11, lsl #2
 1272: add x11, x11, #0x1
 1276: ldr w14, [x13, x12]
 1280: ldr w15, [x13]
 1284: sub x11, x11, #0x1
 1288: add w14, w14, w10
 1292: cmp w15, w14
 1296: csel w14, w15, w14, gt
 1300: cmp x11, x9
 1304: str w14, [x13], #-0x4
 1308: b.hi +1276
 1312: b +468
 1316: mov w0, w19
 1320: add sp, sp, #0x1, lsl #12
 1324: add sp, sp, #0x980
 1328: ldp x20, x19, [sp, #0x50]
 1332: ldp x22, x21, [sp, #0x40]
 1336: ldp x24, x23, [sp, #0x30]
 1340: ldp x26, x25, [sp, #0x20]
 1344: ldp x30, x27, [sp, #0x10]
 1348: ldr x29, [sp], #0x60
 1352: ret
 1356: bl <array_index_fail>
```

#### `bench_edit_distance__U32` (333 instructions, 1332 bytes)
```asm
    0: stp x29, x30, [sp, #-0x60]!
    4: stp x28, x27, [sp, #0x10]
    8: stp x26, x25, [sp, #0x20]
   12: stp x24, x23, [sp, #0x30]
   16: stp x22, x21, [sp, #0x40]
   20: stp x20, x19, [sp, #0x50]
   24: sub sp, sp, #0x1, lsl #12
   28: sub sp, sp, #0x780
   32: mov w19, w0
   36: add x0, sp, #0x1, lsl #12
   40: mov w20, #0xf35f
   44: mov w21, #0x660d
   48: mov w1, wzr
   52: add x0, x0, #0x528
   56: mov w2, #0x258
   60: add x23, sp, #0x1, lsl #12
   64: movk w20, #0x3c6e, lsl #16
   68: movk w21, #0x19, lsl #16
   72: mov w22, #0x258
   76: add x23, x23, #0x528
   80: bl <memset>
   84: add x0, sp, #0x1, lsl #12
   88: mov w1, wzr
   92: mov w2, #0x258
   96: add x0, x0, #0x2d0
  100: bl <memset>
  104: orr x9, x23, #0x3
  108: mov w8, #0x7a69
  112: madd w8, w8, w21, w20
  116: subs x22, x22, #0x4
  120: madd w10, w8, w21, w20
  124: ubfx w12, w8, #12, #2
  128: sturb w12, [x9, #-0x3]
  132: madd w11, w10, w21, w20
  136: ubfx w10, w10, #12, #2
  140: sturb w10, [x9, #-0x2]
  144: madd w8, w11, w21, w20
  148: ubfx w11, w11, #12, #2
  152: sturb w11, [x9, #-0x1]
  156: ubfx w10, w8, #12, #2
  160: strb w10, [x9], #0x4
  164: b.ne +112
  168: add x9, sp, #0x1, lsl #12
  172: mov w10, #0x258
  176: add x9, x9, #0x2d0
  180: orr x9, x9, #0x3
  184: madd w8, w8, w21, w20
  188: subs x10, x10, #0x4
  192: madd w11, w8, w21, w20
  196: ubfx w13, w8, #12, #2
  200: sturb w13, [x9, #-0x3]
  204: madd w12, w11, w21, w20
  208: ubfx w11, w11, #12, #2
  212: sturb w11, [x9, #-0x2]
  216: madd w8, w12, w21, w20
  220: ubfx w12, w12, #12, #2
  224: sturb w12, [x9, #-0x1]
  228: ubfx w11, w8, #12, #2
  232: strb w11, [x9], #0x4
  236: b.ne +184
  240: mov w20, wzr
  244: cbz w19, +1292
  248: add x8, sp, #0x1, lsl #12
  252: add x23, sp, #0x96c
  256: add x27, sp, #0x1, lsl #12
  260: add x8, x8, #0x2d0
  264: mov w21, wzr
  268: add x22, sp, #0x8
  272: orr x24, x8, #0x3
  276: add x25, x23, #0x10
  280: mov w26, #0x258
  284: add x27, x27, #0x528
  288: add x0, sp, #0x96c
  292: mov w1, wzr
  296: mov w2, #0x964
  300: bl <memset>
  304: add x0, x22, #0x4
  308: mov w1, wzr
  312: mov w2, #0x960
  316: bl <memset>
  320: mov x8, xzr
  324: mov w9, #0xb
  328: add x10, x23, #0x18
  332: sub w11, w9, #0xb
  336: sub w12, w9, #0xa
  340: sub w13, w9, #0x1
  344: stp w11, w12, [x10, #-0x18]
  348: sub w11, w9, #0x9
  352: sub w12, w9, #0x8
  356: stp w11, w12, [x10, #-0x10]
  360: add w11, w8, #0x4
  364: sub w12, w9, #0x6
  368: stp w11, w12, [x10, #-0x8]
  372: sub w11, w9, #0x5
  376: sub w12, w9, #0x4
  380: stp w11, w12, [x10]
  384: add w11, w8, #0x8
  388: sub w12, w9, #0x2
  392: add x8, x8, #0xc
  396: stp w11, w12, [x10, #0x8]
  400: stp w13, w9, [x10, #0x10]
  404: cmp x8, #0x258
  408: add w9, w9, #0xc
  412: add x10, x10, #0x30
  416: b.ne +332
  420: mov w28, #0x1
  424: str w26, [sp, #0x12cc]
  428: add x9, x27, x28
  432: ldr w11, [sp, #0x96c]
  436: mov x8, xzr
  440: ldurb w9, [x9, #-0x1]
  444: mov x10, x24
  448: mov w12, w28
  452: str w28, [sp, #0x8]
  456: add x13, x23, x8
  460: ldurb w15, [x10, #-0x3]
  464: ldp w14, w16, [x13, #0x4]
  468: cmp w14, w12
  472: csel w12, w14, w12, lt
  476: cmp w9, w15
  480: add w15, w12, #0x1
  484: cinc w11, w11, ne
  488: cmp w15, w11
  492: csinc w12, w11, w12, ge
  496: ldurb w11, [x10, #-0x2]
  500: cmp w16, w12
  504: csel w15, w16, w12, lt
  508: cmp w9, w11
  512: add w11, w15, #0x1
  516: cinc w14, w14, ne
  520: cmp w11, w14
  524: ldp w17, w11, [x13, #0xc]
  528: csinc w14, w14, w15, ge
  532: ldurb w15, [x10, #-0x1]
  536: cmp w17, w14
  540: csel w13, w17, w14, lt
  544: cmp w9, w15
  548: add w15, w13, #0x1
  552: cinc w16, w16, ne
  556: cmp w15, w16
  560: ldrb w15, [x10], #0x4
  564: csinc w13, w16, w13, ge
  568: add x16, x22, x8
  572: add x8, x8, #0x10
  576: cmp w11, w13
  580: stp w12, w14, [x16, #0x4]
  584: csel w18, w11, w13, lt
  588: cmp w9, w15
  592: add w15, w18, #0x1
  596: cinc w17, w17, ne
  600: cmp w15, w17
  604: csinc w12, w17, w18, ge
  608: cmp x8, #0x960
  612: stp w13, w12, [x16, #0xc]
  616: b.ne +456
  620: add x0, sp, #0x96c
  624: add x1, sp, #0x8
  628: mov w2, #0x964
  632: bl <memcpy>
  636: ldrb w9, [x27, x28]
  640: ldr w11, [sp, #0x96c]
  644: mov x8, xzr
  648: add w12, w28, #0x1
  652: mov x10, x24
  656: str w12, [sp, #0x8]
  660: add x13, x23, x8
  664: ldurb w15, [x10, #-0x3]
  668: ldp w14, w16, [x13, #0x4]
  672: cmp w14, w12
  676: csel w12, w14, w12, lt
  680: cmp w9, w15
  684: add w15, w12, #0x1
  688: cinc w11, w11, ne
  692: cmp w15, w11
  696: csinc w12, w11, w12, ge
  700: ldurb w11, [x10, #-0x2]
  704: cmp w16, w12
  708: csel w15, w16, w12, lt
  712: cmp w9, w11
  716: add w11, w15, #0x1
  720: cinc w14, w14, ne
  724: cmp w11, w14
  728: ldp w17, w11, [x13, #0xc]
  732: csinc w14, w14, w15, ge
  736: ldurb w15, [x10, #-0x1]
  740: cmp w17, w14
  744: csel w13, w17, w14, lt
  748: cmp w9, w15
  752: add w15, w13, #0x1
  756: cinc w16, w16, ne
  760: cmp w15, w16
  764: ldrb w15, [x10], #0x4
  768: csinc w13, w16, w13, ge
  772: add x16, x22, x8
  776: add x8, x8, #0x10
  780: cmp w11, w13
  784: stp w12, w14, [x16, #0x4]
  788: csel w18, w11, w13, lt
  792: cmp w9, w15
  796: add w15, w18, #0x1
  800: cinc w17, w17, ne
  804: cmp w15, w17
  808: csinc w12, w17, w18, ge
  812: cmp x8, #0x960
  816: stp w13, w12, [x16, #0xc]
  820: b.ne +660
  824: add x0, sp, #0x96c
  828: add x1, sp, #0x8
  832: mov w2, #0x964
  836: bl <memcpy>
  840: add x12, x28, #0x2
  844: ldr w11, [sp, #0x96c]
  848: mov x8, xzr
  852: add x9, x27, x12
  856: mov x10, x24
  860: str w12, [sp, #0x8]
  864: ldurb w9, [x9, #-0x1]
  868: add x13, x23, x8
  872: ldurb w15, [x10, #-0x3]
  876: ldp w14, w16, [x13, #0x4]
  880: cmp w14, w12
  884: csel w12, w14, w12, lt
  888: cmp w9, w15
  892: add w15, w12, #0x1
  896: cinc w11, w11, ne
  900: cmp w15, w11
  904: csinc w12, w11, w12, ge
  908: ldurb w11, [x10, #-0x2]
  912: cmp w16, w12
  916: csel w15, w16, w12, lt
  920: cmp w9, w11
  924: add w11, w15, #0x1
  928: cinc w14, w14, ne
  932: cmp w11, w14
  936: ldp w17, w11, [x13, #0xc]
  940: csinc w14, w14, w15, ge
  944: ldurb w15, [x10, #-0x1]
  948: cmp w17, w14
  952: csel w13, w17, w14, lt
  956: cmp w9, w15
  960: add w15, w13, #0x1
  964: cinc w16, w16, ne
  968: cmp w15, w16
  972: ldrb w15, [x10], #0x4
  976: csinc w13, w16, w13, ge
  980: add x16, x22, x8
  984: add x8, x8, #0x10
  988: cmp w11, w13
  992: stp w12, w14, [x16, #0x4]
  996: csel w18, w11, w13, lt
 1000: cmp w9, w15
 1004: add w15, w18, #0x1
 1008: cinc w17, w17, ne
 1012: cmp w15, w17
 1016: csinc w12, w17, w18, ge
 1020: cmp x8, #0x960
 1024: stp w13, w12, [x16, #0xc]
 1028: b.ne +868
 1032: add x0, sp, #0x96c
 1036: add x1, sp, #0x8
 1040: mov w2, #0x964
 1044: bl <memcpy>
 1048: add x12, x28, #0x3
 1052: ldr w11, [sp, #0x96c]
 1056: mov x8, xzr
 1060: add x9, x27, x12
 1064: mov x10, x24
 1068: str w12, [sp, #0x8]
 1072: ldurb w9, [x9, #-0x1]
 1076: add x13, x25, x8
 1080: ldurb w15, [x10, #-0x3]
 1084: ldp w14, w16, [x13, #-0xc]
 1088: ldur w17, [x13, #-0x4]
 1092: cmp w14, w12
 1096: csel w12, w14, w12, lt
 1100: cmp w9, w15
 1104: add w15, w12, #0x1
 1108: cinc w11, w11, ne
 1112: cmp w15, w11
 1116: csinc w12, w11, w12, ge
 1120: ldurb w11, [x10, #-0x2]
 1124: cmp w16, w12
 1128: csel w15, w16, w12, lt
 1132: cmp w9, w11
 1136: add w11, w15, #0x1
 1140: cinc w14, w14, ne
 1144: cmp w11, w14
 1148: ldurb w11, [x10, #-0x1]
 1152: csinc w14, w14, w15, ge
 1156: cmp w17, w14
 1160: csel w15, w17, w14, lt
 1164: cmp w9, w11
 1168: add w11, w15, #0x1
 1172: cinc w16, w16, ne
 1176: cmp w11, w16
 1180: ldr w11, [x13]
 1184: csinc w13, w16, w15, ge
 1188: ldrb w15, [x10], #0x4
 1192: cmp w11, w13
 1196: add x16, x22, x8
 1200: add x8, x8, #0x10
 1204: csel w18, w11, w13, lt
 1208: cmp w9, w15
 1212: stp w12, w14, [x16, #0x4]
 1216: add w15, w18, #0x1
 1220: cinc w17, w17, ne
 1224: cmp w15, w17
 1228: csinc w12, w17, w18, ge
 1232: cmp x8, #0x960
 1236: stp w13, w12, [x16, #0xc]
 1240: b.ne +1076
 1244: add x0, sp, #0x96c
 1248: add x1, sp, #0x8
 1252: mov w2, #0x964
 1256: bl <memcpy>
 1260: add x28, x28, #0x4
 1264: cmp x28, #0x259
 1268: b.ne +428
 1272: ldr w8, [sp, #0x12cc]
 1276: add w21, w21, #0x1
 1280: cmp w21, w19
 1284: add w20, w8, w20
 1288: b.ne +288
 1292: mov w0, w20
 1296: add sp, sp, #0x1, lsl #12
 1300: add sp, sp, #0x780
 1304: ldp x20, x19, [sp, #0x50]
 1308: ldp x22, x21, [sp, #0x40]
 1312: ldp x24, x23, [sp, #0x30]
 1316: ldp x26, x25, [sp, #0x20]
 1320: ldp x28, x27, [sp, #0x10]
 1324: ldp x29, x30, [sp], #0x60
 1328: ret
```

#### `bench_matrix_multiply__U32` (696 instructions, 2784 bytes)
```asm
    0: stp x29, x30, [sp, #-0x60]!
    4: stp x28, x27, [sp, #0x10]
    8: stp x26, x25, [sp, #0x20]
   12: stp x24, x23, [sp, #0x30]
   16: stp x22, x21, [sp, #0x40]
   20: stp x20, x19, [sp, #0x50]
   24: sub sp, sp, #0xc, lsl #12
   28: sub sp, sp, #0x50
   32: str w0, [sp, #0x8]
   36: add x0, sp, #0x8, lsl #12
   40: add x21, sp, #0x8, lsl #12
   44: add x0, x0, #0x50
   48: mov w1, wzr
   52: mov w2, #0x4000
   56: add x21, x21, #0x50
   60: bl <memset>
   64: add x0, sp, #0x4, lsl #12
   68: mov w1, wzr
   72: mov w2, #0x4000
   76: add x0, x0, #0x50
   80: add x20, sp, #0x4, lsl #12
   84: add x20, x20, #0x50
   88: bl <memset>
   92: add x0, sp, #0x50
   96: mov w1, wzr
  100: mov w2, #0x4000
  104: bl <memset>
  108: add x10, x20, #0x10c
  112: mov w14, #0x12
  116: mov w13, #0x3
  120: str x10, [sp, #0x48]
  124: add x10, x21, #0x10c
  128: mov w22, #0xf0f1
  132: mov w23, #0xec4f
  136: mov w19, wzr
  140: mov w9, wzr
  144: mov x8, xzr
  148: add x11, x20, #0x8
  152: add x12, x21, #0x8
  156: str x10, [sp, #0x40]
  160: mov w15, #0xf
  164: mov w10, #0x6
  168: mov w30, #0xa
  172: mov w18, #0x4
  176: mov w0, #0x2
  180: mov w27, #0x5
  184: stp w13, w14, [sp, #0x38]
  188: mov w4, #0x7
  192: mov w5, #0xd
  196: mov w6, #0xb
  200: mov w7, #0x9
  204: mov w13, #0x8
  208: movk w22, #0xf0f0, lsl #16
  212: movk w23, #0x4ec4, lsl #16
  216: mov w24, #0xd
  220: mov w25, #0xd
  224: str w13, [sp, #0x34]
  228: stp x11, x8, [sp, #0x20]
  232: mov x26, #-0x80
  236: mov w28, w0
  240: mov w29, w18
  244: mov w16, w10
  248: mov w8, w19
  252: mov w20, w9
  256: stp w27, w30, [sp, #0xc]
  260: str x12, [sp, #0x18]
  264: str w15, [sp, #0x14]
  268: str w9, [sp, #0x30]
  272: umull x17, w27, w22
  276: add w27, w27, #0x14
  280: umull x13, w20, w22
  284: umull x2, w30, w22
  288: add w30, w30, #0x14
  292: umull x9, w15, w22
  296: lsr x17, x17, #36
  300: add w15, w15, #0x14
  304: umull x14, w8, w23
  308: lsr x13, x13, #36
  312: add w8, w8, #0x8
  316: umull x1, w28, w23
  320: lsr x2, x2, #36
  324: add w17, w17, w17, lsl #4
  328: umull x3, w16, w23
  332: add w13, w13, w13, lsl #4
  336: lsr x9, x9, #36
  340: umull x21, w29, w23
  344: lsr x14, x14, #34
  348: add w2, w2, w2, lsl #4
  352: lsr x1, x1, #34
  356: sub w17, w20, w17
  360: add w9, w9, w9, lsl #4
  364: lsr x3, x3, #34
  368: sub w13, w20, w13
  372: add w17, w17, #0x5
  376: lsr x21, x21, #34
  380: msub w14, w14, w5, w19
  384: stp w13, w17, [x12, #-0x8]
  388: msub w1, w1, w5, w0
  392: sub w13, w20, w2
  396: sub w9, w20, w9
  400: msub w17, w21, w5, w18
  404: add w13, w13, #0xa
  408: add w9, w9, #0xf
  412: msub w2, w3, w5, w10
  416: add w14, w26, w14
  420: add w20, w20, #0x14
  424: add w1, w26, w1
  428: stp w13, w9, [x12], #0x10
  432: add w13, w26, w17
  436: add w14, w14, #0x80
  440: add w1, w1, #0x80
  444: add w9, w26, w2
  448: add w13, w13, #0x80
  452: adds x26, x26, #0x8
  456: add w9, w9, #0x80
  460: add w16, w16, #0x8
  464: add w29, w29, #0x8
  468: add w28, w28, #0x8
  472: stp w14, w1, [x11, #-0x8]
  476: stp w13, w9, [x11], #0x10
  480: b.ne +272
  484: ldp w27, w15, [sp, #0x34]
  488: ldp x29, x30, [sp, #0x40]
  492: mov x26, #-0x80
  496: ldr w20, [sp, #0x3c]
  500: mov w28, w7
  504: mov w12, w6
  508: mov w11, w24
  512: mov w16, w4
  516: mov w8, w25
  520: umull x13, w15, w22
  524: add w15, w15, #0x14
  528: umull x1, w27, w22
  532: add w27, w27, #0x14
  536: umull x2, w28, w23
  540: add w28, w28, #0x8
  544: umull x14, w16, w23
  548: lsr x13, x13, #36
  552: add w16, w16, #0x8
  556: umull x17, w11, w22
  560: lsr x1, x1, #36
  564: add w11, w11, #0x14
  568: lsr x2, x2, #34
  572: umull x9, w20, w22
  576: add w13, w13, w13, lsl #4
  580: lsr x14, x14, #34
  584: umull x3, w8, w23
  588: add w1, w1, w1, lsl #4
  592: umull x21, w12, w23
  596: lsr x17, x17, #36
  600: sub w13, w20, w13
  604: msub w2, w2, w5, w7
  608: lsr x9, x9, #36
  612: sub w1, w20, w1
  616: msub w14, w14, w5, w4
  620: lsr x3, x3, #34
  624: add w17, w17, w17, lsl #4
  628: lsr x21, x21, #34
  632: sub w13, w13, #0xf
  636: sub w1, w1, #0xa
  640: add w2, w26, w2
  644: add w9, w9, w9, lsl #4
  648: stp w13, w1, [x29, #-0xc]
  652: add w14, w26, w14
  656: msub w13, w21, w5, w6
  660: add w1, w2, #0x80
  664: msub w2, w3, w5, w25
  668: add w14, w14, #0x80
  672: sub w17, w20, w17
  676: stp w14, w1, [x30, #-0xc]
  680: sub w14, w17, #0x5
  684: sub w9, w20, w9
  688: stp w14, w9, [x29, #-0x4]
  692: add w13, w26, w13
  696: add x29, x29, #0x10
  700: add w9, w26, w2
  704: add w13, w13, #0x80
  708: add w20, w20, #0x14
  712: add w9, w9, #0x80
  716: add w8, w8, #0x8
  720: adds x26, x26, #0x8
  724: stp w13, w9, [x30, #-0x4]
  728: add x30, x30, #0x10
  732: add w12, w12, #0x8
  736: b.ne +520
  740: ldp x13, x12, [sp, #0x40]
  744: ldp x11, x8, [sp, #0x20]
  748: ldp w30, w15, [sp, #0x10]
  752: add x14, x12, #0x200
  756: add w19, w19, #0xe
  760: ldr w9, [sp, #0x30]
  764: ldr x12, [sp, #0x18]
  768: add x8, x8, #0x2
  772: add x13, x13, #0x200
  776: ldr w27, [sp, #0xc]
  780: add w15, w15, #0x6
  784: stp x13, x14, [sp, #0x40]
  788: ldr w13, [sp, #0x3c]
  792: add w9, w9, #0x6
  796: add w10, w10, #0xe
  800: add x11, x11, #0x200
  804: add x12, x12, #0x200
  808: add w14, w13, #0x6
  812: ldr w13, [sp, #0x38]
  816: add w30, w30, #0x6
  820: add w18, w18, #0xe
  824: add w0, w0, #0xe
  828: add w27, w27, #0x6
  832: add w13, w13, #0x6
  836: add w25, w25, #0xe
  840: add w4, w4, #0xe
  844: stp w13, w14, [sp, #0x38]
  848: ldr w13, [sp, #0x34]
  852: add w24, w24, #0x6
  856: cmp x8, #0x40
  860: add w6, w6, #0xe
  864: add w7, w7, #0xe
  868: add w13, w13, #0x6
  872: str w13, [sp, #0x34]
  876: b.ne +228
  880: ldr w8, [sp, #0x8]
  884: lsl w8, w8, #3
  888: tbnz w8, #0x1f, +1620
  892: mov w0, wzr
  896: cbz w8, +1584
  900: add x10, sp, #0x8, lsl #12
  904: mov w9, wzr
  908: add x11, sp, #0x50
  912: add x10, x10, #0x50
  916: mov x12, xzr
  920: add x13, x10, #0x10
  924: add x15, x11, x12, lsl #8
  928: add x16, sp, #0x4, lsl #12
  932: mov x14, xzr
  936: add x16, x16, #0x50
  940: mov w4, wzr
  944: mov w2, wzr
  948: mov x17, x13
  952: mov w18, #0x40
  956: mov x1, x16
  960: ldp w5, w6, [x17, #-0x10]
  964: ldr w3, [x1]
  968: ldr w7, [x1, #0x100]
  972: subs x18, x18, #0x8
  976: madd w3, w3, w5, w4
  980: ldr w5, [x1, #0x200]
  984: madd w2, w7, w6, w2
  988: ldr w7, [x1, #0x300]
  992: ldp w4, w6, [x17, #-0x8]
  996: madd w3, w5, w4, w3
 1000: ldr w5, [x1, #0x400]
 1004: madd w2, w7, w6, w2
 1008: ldr w7, [x1, #0x500]
 1012: ldp w4, w6, [x17]
 1016: madd w3, w5, w4, w3
 1020: ldr w5, [x1, #0x600]
 1024: madd w2, w7, w6, w2
 1028: ldr w7, [x1, #0x700]
 1032: add x1, x1, #0x800
 1036: ldp w4, w6, [x17, #0x8]
 1040: add x17, x17, #0x20
 1044: madd w4, w5, w4, w3
 1048: madd w2, w7, w6, w2
 1052: b.ne +960
 1056: add w17, w2, w4
 1060: mov w5, wzr
 1064: mov w3, wzr
 1068: str w17, [x15, x14, lsl #2]
 1072: orr x17, x14, #0x1
 1076: mov x1, x13
 1080: add x2, x16, x18
 1084: add x18, x18, #0x800
 1088: ldp w6, w7, [x1, #-0x10]
 1092: ldr w4, [x2, #0x4]
 1096: ldr w19, [x2, #0x104]
 1100: cmp x18, #0x4, lsl #12
 1104: madd w4, w4, w6, w5
 1108: ldr w6, [x2, #0x204]
 1112: madd w3, w19, w7, w3
 1116: ldr w19, [x2, #0x304]
 1120: ldp w5, w7, [x1, #-0x8]
 1124: madd w4, w6, w5, w4
 1128: ldr w6, [x2, #0x404]
 1132: madd w3, w19, w7, w3
 1136: ldr w19, [x2, #0x504]
 1140: ldp w5, w7, [x1]
 1144: madd w4, w6, w5, w4
 1148: ldr w6, [x2, #0x604]
 1152: ldr w2, [x2, #0x704]
 1156: madd w3, w19, w7, w3
 1160: ldp w5, w7, [x1, #0x8]
 1164: add x1, x1, #0x20
 1168: madd w5, w6, w5, w4
 1172: madd w3, w2, w7, w3
 1176: b.ne +1080
 1180: add w1, w3, w5
 1184: mov x18, xzr
 1188: mov w6, wzr
 1192: mov w4, wzr
 1196: str w1, [x15, x17, lsl #2]
 1200: orr x17, x14, #0x2
 1204: mov x1, x13
 1208: add x2, x16, x18
 1212: add x18, x18, #0x800
 1216: ldp w5, w7, [x1, #-0x10]
 1220: ldr w3, [x2, #0x8]
 1224: ldr w19, [x2, #0x108]
 1228: cmp x18, #0x4, lsl #12
 1232: madd w3, w3, w5, w6
 1236: ldr w6, [x2, #0x208]
 1240: madd w4, w19, w7, w4
 1244: ldr w19, [x2, #0x308]
 1248: ldp w5, w7, [x1, #-0x8]
 1252: madd w3, w6, w5, w3
 1256: ldr w6, [x2, #0x408]
 1260: madd w4, w19, w7, w4
 1264: ldr w19, [x2, #0x508]
 1268: ldp w5, w7, [x1]
 1272: madd w3, w6, w5, w3
 1276: ldr w6, [x2, #0x608]
 1280: ldr w2, [x2, #0x708]
 1284: madd w4, w19, w7, w4
 1288: ldp w5, w7, [x1, #0x8]
 1292: add x1, x1, #0x20
 1296: madd w6, w6, w5, w3
 1300: madd w4, w2, w7, w4
 1304: b.ne +1208
 1308: add w1, w4, w6
 1312: mov x18, xzr
 1316: mov w3, wzr
 1320: mov w2, wzr
 1324: str w1, [x15, x17, lsl #2]
 1328: orr x17, x14, #0x3
 1332: mov x1, x13
 1336: add x4, x16, x18
 1340: add x18, x18, #0x800
 1344: ldp w6, w7, [x1, #-0x10]
 1348: ldr w5, [x4, #0xc]
 1352: ldr w19, [x4, #0x10c]
 1356: cmp x18, #0x4, lsl #12
 1360: madd w3, w5, w6, w3
 1364: ldr w6, [x4, #0x20c]
 1368: madd w2, w19, w7, w2
 1372: ldr w19, [x4, #0x30c]
 1376: ldp w5, w7, [x1, #-0x8]
 1380: madd w3, w6, w5, w3
 1384: ldr w6, [x4, #0x40c]
 1388: madd w2, w19, w7, w2
 1392: ldr w19, [x4, #0x50c]
 1396: ldp w5, w7, [x1]
 1400: madd w3, w6, w5, w3
 1404: ldr w6, [x4, #0x60c]
 1408: ldr w4, [x4, #0x70c]
 1412: madd w2, w19, w7, w2
 1416: ldp w5, w7, [x1, #0x8]
 1420: add x1, x1, #0x20
 1424: madd w3, w6, w5, w3
 1428: madd w2, w4, w7, w2
 1432: b.ne +1336
 1436: add x14, x14, #0x4
 1440: add x16, x16, #0x10
 1444: add w18, w2, w3
 1448: cmp x14, #0x40
 1452: str w18, [x15, x17, lsl #2]
 1456: b.ne +940
 1460: add x12, x12, #0x1
 1464: add x13, x13, #0x100
 1468: cmp x12, #0x40
 1472: b.ne +924
 1476: mov w12, wzr
 1480: add x13, x11, #0x10
 1484: mov w14, #0x1000
 1488: ldp w15, w16, [x13, #-0x10]
 1492: ldp w1, w17, [x13, #-0x4]
 1496: ldur w18, [x13, #-0x8]
 1500: ldr w2, [x13, #0x4]
 1504: subs x14, x14, #0x8
 1508: add w12, w16, w12
 1512: add w15, w15, w0
 1516: add w16, w17, w18
 1520: add w17, w2, w1
 1524: ldp w18, w1, [x13, #0x8]
 1528: add w15, w16, w15
 1532: add w12, w17, w12
 1536: add x13, x13, #0x20
 1540: add w0, w18, w15
 1544: add w12, w1, w12
 1548: b.ne +1488
 1552: and w13, w9, #0x3f
 1556: add w9, w9, #0x1
 1560: add w0, w12, w0
 1564: ldr w14, [x10, w13, uxtw #2]
 1568: cmp w9, w8
 1572: add w12, w14, #0x1
 1576: str w12, [x10, w13, uxtw #2]
 1580: b.ne +916
 1584: add sp, sp, #0xc, lsl #12
 1588: add sp, sp, #0x50
 1592: ldp x20, x19, [sp, #0x50]
 1596: ldp x22, x21, [sp, #0x40]
 1600: ldp x24, x23, [sp, #0x30]
 1604: ldp x26, x25, [sp, #0x20]
 1608: ldp x28, x27, [sp, #0x10]
 1612: ldp x29, x30, [sp], #0x60
 1616: ret
 1620: add x9, sp, #0x8, lsl #12
 1624: mov x8, xzr
 1628: add x10, sp, #0x50
 1632: add x9, x9, #0x50
 1636: add x9, x9, #0x10
 1640: add x12, x10, x8, lsl #8
 1644: add x13, sp, #0x4, lsl #12
 1648: mov x11, xzr
 1652: add x13, x13, #0x50
 1656: mov w0, wzr
 1660: mov w17, wzr
 1664: mov x14, x9
 1668: mov w15, #0x40
 1672: mov x16, x13
 1676: ldp w1, w2, [x14, #-0x10]
 1680: ldr w18, [x16]
 1684: ldr w3, [x16, #0x100]
 1688: subs x15, x15, #0x8
 1692: madd w18, w18, w1, w0
 1696: ldr w1, [x16, #0x200]
 1700: madd w17, w3, w2, w17
 1704: ldr w3, [x16, #0x300]
 1708: ldp w0, w2, [x14, #-0x8]
 1712: madd w18, w1, w0, w18
 1716: ldr w1, [x16, #0x400]
 1720: madd w17, w3, w2, w17
 1724: ldr w3, [x16, #0x500]
 1728: ldp w0, w2, [x14]
 1732: madd w18, w1, w0, w18
 1736: ldr w1, [x16, #0x600]
 1740: madd w17, w3, w2, w17
 1744: ldr w3, [x16, #0x700]
 1748: add x16, x16, #0x800
 1752: ldp w0, w2, [x14, #0x8]
 1756: add x14, x14, #0x20
 1760: madd w0, w1, w0, w18
 1764: madd w17, w3, w2, w17
 1768: b.ne +1676
 1772: add w14, w17, w0
 1776: mov w1, wzr
 1780: mov w18, wzr
 1784: str w14, [x12, x11, lsl #2]
 1788: orr x14, x11, #0x1
 1792: mov x16, x9
 1796: add x17, x13, x15
 1800: add x15, x15, #0x800
 1804: ldp w2, w3, [x16, #-0x10]
 1808: ldr w0, [x17, #0x4]
 1812: ldr w4, [x17, #0x104]
 1816: cmp x15, #0x4, lsl #12
 1820: madd w0, w0, w2, w1
 1824: ldr w2, [x17, #0x204]
 1828: madd w18, w4, w3, w18
 1832: ldr w4, [x17, #0x304]
 1836: ldp w1, w3, [x16, #-0x8]
 1840: madd w0, w2, w1, w0
 1844: ldr w2, [x17, #0x404]
 1848: madd w18, w4, w3, w18
 1852: ldr w4, [x17, #0x504]
 1856: ldp w1, w3, [x16]
 1860: madd w0, w2, w1, w0
 1864: ldr w2, [x17, #0x604]
 1868: ldr w17, [x17, #0x704]
 1872: madd w18, w4, w3, w18
 1876: ldp w1, w3, [x16, #0x8]
 1880: add x16, x16, #0x20
 1884: madd w1, w2, w1, w0
 1888: madd w18, w17, w3, w18
 1892: b.ne +1796
 1896: add w16, w18, w1
 1900: mov x15, xzr
 1904: mov w2, wzr
 1908: mov w0, wzr
 1912: str w16, [x12, x14, lsl #2]
 1916: orr x14, x11, #0x2
 1920: mov x16, x9
 1924: add x17, x13, x15
 1928: add x15, x15, #0x800
 1932: ldp w1, w3, [x16, #-0x10]
 1936: ldr w18, [x17, #0x8]
 1940: ldr w4, [x17, #0x108]
 1944: cmp x15, #0x4, lsl #12
 1948: madd w18, w18, w1, w2
 1952: ldr w2, [x17, #0x208]
 1956: madd w0, w4, w3, w0
 1960: ldr w4, [x17, #0x308]
 1964: ldp w1, w3, [x16, #-0x8]
 1968: madd w18, w2, w1, w18
 1972: ldr w2, [x17, #0x408]
 1976: madd w0, w4, w3, w0
 1980: ldr w4, [x17, #0x508]
 1984: ldp w1, w3, [x16]
 1988: madd w18, w2, w1, w18
 1992: ldr w2, [x17, #0x608]
 1996: ldr w17, [x17, #0x708]
 2000: madd w0, w4, w3, w0
 2004: ldp w1, w3, [x16, #0x8]
 2008: add x16, x16, #0x20
 2012: madd w2, w2, w1, w18
 2016: madd w0, w17, w3, w0
 2020: b.ne +1924
 2024: add w16, w0, w2
 2028: mov x15, xzr
 2032: mov w18, wzr
 2036: mov w17, wzr
 2040: str w16, [x12, x14, lsl #2]
 2044: orr x14, x11, #0x3
 2048: mov x16, x9
 2052: add x0, x13, x15
 2056: add x15, x15, #0x800
 2060: ldp w2, w3, [x16, #-0x10]
 2064: ldr w1, [x0, #0xc]
 2068: ldr w4, [x0, #0x10c]
 2072: cmp x15, #0x4, lsl #12
 2076: madd w18, w1, w2, w18
 2080: ldr w2, [x0, #0x20c]
 2084: madd w17, w4, w3, w17
 2088: ldr w4, [x0, #0x30c]
 2092: ldp w1, w3, [x16, #-0x8]
 2096: madd w18, w2, w1, w18
 2100: ldr w2, [x0, #0x40c]
 2104: madd w17, w4, w3, w17
 2108: ldr w4, [x0, #0x50c]
 2112: ldp w1, w3, [x16]
 2116: madd w18, w2, w1, w18
 2120: ldr w2, [x0, #0x60c]
 2124: ldr w0, [x0, #0x70c]
 2128: madd w17, w4, w3, w17
 2132: ldp w1, w3, [x16, #0x8]
 2136: add x16, x16, #0x20
 2140: madd w18, w2, w1, w18
 2144: madd w17, w0, w3, w17
 2148: b.ne +2052
 2152: add x11, x11, #0x4
 2156: add x13, x13, #0x10
 2160: add w15, w17, w18
 2164: cmp x11, #0x40
 2168: str w15, [x12, x14, lsl #2]
 2172: b.ne +1656
 2176: add x8, x8, #0x1
 2180: add x9, x9, #0x100
 2184: cmp x8, #0x40
 2188: b.ne +1640
 2192: add x11, sp, #0x8, lsl #12
 2196: add x10, sp, #0x8, lsl #12
 2200: mov x8, xzr
 2204: ldr w9, [x11, #0x50]!
 2208: add x10, x10, #0x50
 2212: add w9, w9, #0x1
 2216: str w9, [x11]
 2220: add x9, x10, #0x10
 2224: add x10, sp, #0x50
 2228: add x12, x10, x8, lsl #8
 2232: add x13, sp, #0x4, lsl #12
 2236: mov x11, xzr
 2240: add x13, x13, #0x50
 2244: mov w0, wzr
 2248: mov w17, wzr
 2252: mov x14, x9
 2256: mov w15, #0x40
 2260: mov x16, x13
 2264: ldp w1, w2, [x14, #-0x10]
 2268: ldr w18, [x16]
 2272: ldr w3, [x16, #0x100]
 2276: subs x15, x15, #0x8
 2280: madd w18, w18, w1, w0
 2284: ldr w1, [x16, #0x200]
 2288: madd w17, w3, w2, w17
 2292: ldr w3, [x16, #0x300]
 2296: ldp w0, w2, [x14, #-0x8]
 2300: madd w18, w1, w0, w18
 2304: ldr w1, [x16, #0x400]
 2308: madd w17, w3, w2, w17
 2312: ldr w3, [x16, #0x500]
 2316: ldp w0, w2, [x14]
 2320: madd w18, w1, w0, w18
 2324: ldr w1, [x16, #0x600]
 2328: madd w17, w3, w2, w17
 2332: ldr w3, [x16, #0x700]
 2336: add x16, x16, #0x800
 2340: ldp w0, w2, [x14, #0x8]
 2344: add x14, x14, #0x20
 2348: madd w0, w1, w0, w18
 2352: madd w17, w3, w2, w17
 2356: b.ne +2264
 2360: add w14, w17, w0
 2364: mov w1, wzr
 2368: mov w18, wzr
 2372: str w14, [x12, x11, lsl #2]
 2376: orr x14, x11, #0x1
 2380: mov x16, x9
 2384: add x17, x13, x15
 2388: add x15, x15, #0x800
 2392: ldp w2, w3, [x16, #-0x10]
 2396: ldr w0, [x17, #0x4]
 2400: ldr w4, [x17, #0x104]
 2404: cmp x15, #0x4, lsl #12
 2408: madd w0, w0, w2, w1
 2412: ldr w2, [x17, #0x204]
 2416: madd w18, w4, w3, w18
 2420: ldr w4, [x17, #0x304]
 2424: ldp w1, w3, [x16, #-0x8]
 2428: madd w0, w2, w1, w0
 2432: ldr w2, [x17, #0x404]
 2436: madd w18, w4, w3, w18
 2440: ldr w4, [x17, #0x504]
 2444: ldp w1, w3, [x16]
 2448: madd w0, w2, w1, w0
 2452: ldr w2, [x17, #0x604]
 2456: ldr w17, [x17, #0x704]
 2460: madd w18, w4, w3, w18
 2464: ldp w1, w3, [x16, #0x8]
 2468: add x16, x16, #0x20
 2472: madd w1, w2, w1, w0
 2476: madd w18, w17, w3, w18
 2480: b.ne +2384
 2484: add w16, w18, w1
 2488: mov x15, xzr
 2492: mov w2, wzr
 2496: mov w0, wzr
 2500: str w16, [x12, x14, lsl #2]
 2504: orr x14, x11, #0x2
 2508: mov x16, x9
 2512: add x17, x13, x15
 2516: add x15, x15, #0x800
 2520: ldp w1, w3, [x16, #-0x10]
 2524: ldr w18, [x17, #0x8]
 2528: ldr w4, [x17, #0x108]
 2532: cmp x15, #0x4, lsl #12
 2536: madd w18, w18, w1, w2
 2540: ldr w2, [x17, #0x208]
 2544: madd w0, w4, w3, w0
 2548: ldr w4, [x17, #0x308]
 2552: ldp w1, w3, [x16, #-0x8]
 2556: madd w18, w2, w1, w18
 2560: ldr w2, [x17, #0x408]
 2564: madd w0, w4, w3, w0
 2568: ldr w4, [x17, #0x508]
 2572: ldp w1, w3, [x16]
 2576: madd w18, w2, w1, w18
 2580: ldr w2, [x17, #0x608]
 2584: ldr w17, [x17, #0x708]
 2588: madd w0, w4, w3, w0
 2592: ldp w1, w3, [x16, #0x8]
 2596: add x16, x16, #0x20
 2600: madd w2, w2, w1, w18
 2604: madd w0, w17, w3, w0
 2608: b.ne +2512
 2612: add w16, w0, w2
 2616: mov x15, xzr
 2620: mov w18, wzr
 2624: mov w17, wzr
 2628: str w16, [x12, x14, lsl #2]
 2632: orr x14, x11, #0x3
 2636: mov x16, x9
 2640: add x0, x13, x15
 2644: add x15, x15, #0x800
 2648: ldp w2, w3, [x16, #-0x10]
 2652: ldr w1, [x0, #0xc]
 2656: ldr w4, [x0, #0x10c]
 2660: cmp x15, #0x4, lsl #12
 2664: madd w18, w1, w2, w18
 2668: ldr w2, [x0, #0x20c]
 2672: madd w17, w4, w3, w17
 2676: ldr w4, [x0, #0x30c]
 2680: ldp w1, w3, [x16, #-0x8]
 2684: madd w18, w2, w1, w18
 2688: ldr w2, [x0, #0x40c]
 2692: madd w17, w4, w3, w17
 2696: ldr w4, [x0, #0x50c]
 2700: ldp w1, w3, [x16]
 2704: madd w18, w2, w1, w18
 2708: ldr w2, [x0, #0x60c]
 2712: ldr w0, [x0, #0x70c]
 2716: madd w17, w4, w3, w17
 2720: ldp w1, w3, [x16, #0x8]
 2724: add x16, x16, #0x20
 2728: madd w18, w2, w1, w18
 2732: madd w17, w0, w3, w17
 2736: b.ne +2640
 2740: add x11, x11, #0x4
 2744: add x13, x13, #0x10
 2748: add w15, w17, w18
 2752: cmp x11, #0x40
 2756: str w15, [x12, x14, lsl #2]
 2760: b.ne +2244
 2764: add x8, x8, #0x1
 2768: add x9, x9, #0x100
 2772: cmp x8, #0x40
 2776: b.ne +2228
 2780: bl <array_index_fail>
```

#### `bench_crc32__U32` (166 instructions, 664 bytes)
```asm
    0: str x29, [sp, #-0x40]!
    4: stp x30, x23, [sp, #0x10]
    8: stp x22, x21, [sp, #0x20]
   12: stp x20, x19, [sp, #0x30]
   16: sub sp, sp, #0x8, lsl #12
   20: sub sp, sp, #0x400
   24: mov w19, w0
   28: add x0, sp, #0x8, lsl #12
   32: mov w1, wzr
   36: mov w2, #0x400
   40: add x20, sp, #0x8, lsl #12
   44: bl <memset>
   48: add x8, x20, #0x20
   52: adrp x9, <harness_main+0x1da8>
   56: add x9, x9, #0x930
   60: mov w10, #0xf
   64: sub w11, w10, #0xf
   68: sub w16, w10, #0xb
   72: ldp w12, w13, [x9, #-0x20]
   76: lsr w11, w11, #8
   80: lsr w16, w16, #8
   84: ldp w14, w15, [x9, #-0x18]
   88: eor w12, w11, w12
   92: eor w13, w11, w13
   96: stp w12, w13, [x8, #-0x20]
  100: eor w12, w11, w14
  104: eor w11, w11, w15
  108: ldp w13, w14, [x9, #-0x10]
  112: stp w12, w11, [x8, #-0x18]
  116: ldp w11, w12, [x9, #-0x8]
  120: eor w13, w16, w13
  124: eor w14, w16, w14
  128: stp w13, w14, [x8, #-0x10]
  132: sub w13, w10, #0x7
  136: eor w11, w16, w11
  140: eor w12, w16, w12
  144: lsr w13, w13, #8
  148: ldp w14, w15, [x9]
  152: stp w11, w12, [x8, #-0x8]
  156: sub w16, w10, #0x3
  160: add x10, x10, #0x10
  164: ldp w11, w12, [x9, #0x8]
  168: eor w14, w13, w14
  172: eor w15, w13, w15
  176: cmp x10, #0x10f
  180: stp w14, w15, [x8]
  184: lsr w14, w16, #8
  188: eor w11, w13, w11
  192: eor w12, w13, w12
  196: ldp w15, w13, [x9, #0x10]
  200: stp w11, w12, [x8, #0x8]
  204: eor w11, w14, w15
  208: eor w13, w14, w13
  212: ldp w12, w15, [x9, #0x18]
  216: stp w11, w13, [x8, #0x10]
  220: add x9, x9, #0x40
  224: eor w11, w14, w12
  228: eor w12, w14, w15
  232: stp w11, w12, [x8, #0x18]
  236: add x8, x8, #0x40
  240: b.ne +64
  244: mov w20, #0xf35f
  248: mov w21, #0x660d
  252: mov w1, wzr
  256: mov x0, sp
  260: mov w2, #0x8000
  264: movk w20, #0x3c6e, lsl #16
  268: movk w21, #0x19, lsl #16
  272: mov w22, #0x8000
  276: mov x23, sp
  280: bl <memset>
  284: orr x8, x23, #0x3
  288: mov w9, #0x7e8
  292: madd w9, w9, w21, w20
  296: subs x22, x22, #0x4
  300: madd w10, w9, w21, w20
  304: lsr w12, w9, #24
  308: sturb w12, [x8, #-0x3]
  312: madd w11, w10, w21, w20
  316: lsr w10, w10, #24
  320: sturb w10, [x8, #-0x2]
  324: madd w9, w11, w21, w20
  328: lsr w11, w11, #24
  332: sturb w11, [x8, #-0x1]
  336: lsr w10, w9, #24
  340: strb w10, [x8], #0x4
  344: b.ne +292
  348: lsl w8, w19, #5
  352: tbnz w8, #0x1f, +492
  356: cbz w8, +628
  360: mov x9, sp
  364: mov w10, wzr
  368: add x12, sp, #0x8, lsl #12
  372: orr x11, x9, #0x3
  376: mov w9, #-0x1
  380: mov w13, #0x8000
  384: mov x14, x11
  388: ldurb w15, [x14, #-0x3]
  392: subs x13, x13, #0x4
  396: eor w15, w15, w9
  400: and x15, x15, #0xff
  404: ldr w15, [x12, x15, lsl #2]
  408: eor w9, w15, w9, lsr #8
  412: ldurb w15, [x14, #-0x2]
  416: eor w15, w15, w9
  420: and x15, x15, #0xff
  424: ldr w15, [x12, x15, lsl #2]
  428: eor w9, w15, w9, lsr #8
  432: ldurb w15, [x14, #-0x1]
  436: eor w15, w15, w9
  440: and x15, x15, #0xff
  444: ldr w15, [x12, x15, lsl #2]
  448: eor w9, w15, w9, lsr #8
  452: ldrb w15, [x14], #0x4
  456: eor w15, w15, w9
  460: and x15, x15, #0xff
  464: ldr w15, [x12, x15, lsl #2]
  468: eor w9, w15, w9, lsr #8
  472: b.ne +388
  476: add w10, w10, #0x1
  480: cmp w10, w8
  484: b.ne +380
  488: b +632
  492: mov x9, sp
  496: mov w10, wzr
  500: add x12, sp, #0x8, lsl #12
  504: orr x11, x9, #0x3
  508: mov w9, #-0x1
  512: mov w13, #0x8000
  516: mov x14, x11
  520: ldurb w15, [x14, #-0x3]
  524: subs x13, x13, #0x4
  528: eor w15, w15, w9
  532: and x15, x15, #0xff
  536: ldr w15, [x12, x15, lsl #2]
  540: eor w9, w15, w9, lsr #8
  544: ldurb w15, [x14, #-0x2]
  548: eor w15, w15, w9
  552: and x15, x15, #0xff
  556: ldr w15, [x12, x15, lsl #2]
  560: eor w9, w15, w9, lsr #8
  564: ldurb w15, [x14, #-0x1]
  568: eor w15, w15, w9
  572: and x15, x15, #0xff
  576: ldr w15, [x12, x15, lsl #2]
  580: eor w9, w15, w9, lsr #8
  584: ldrb w15, [x14], #0x4
  588: eor w15, w15, w9
  592: and x15, x15, #0xff
  596: ldr w15, [x12, x15, lsl #2]
  600: eor w9, w15, w9, lsr #8
  604: b.ne +520
  608: sub w13, w10, w8
  612: sub w10, w10, #0x1
  616: cmp w13, #0x1
  620: b.hi +512
  624: b +632
  628: mov w9, #-0x1
  632: mvn w0, w9
  636: add sp, sp, #0x8, lsl #12
  640: add sp, sp, #0x400
  644: ldp x20, x19, [sp, #0x30]
  648: ldp x22, x21, [sp, #0x20]
  652: ldp x30, x23, [sp, #0x10]
  656: ldr x29, [sp], #0x40
  660: ret
```

#### `bench_sha256__U32` (241 instructions, 964 bytes)
```asm
    0: sub sp, sp, #0x170
    4: stp x20, x19, [sp, #0x160]
    8: mov w8, #0xbb8
   12: add x20, sp, #0x10
   16: mul w19, w0, w8
   20: add x0, x20, #0x40
   24: mov w1, wzr
   28: mov w2, #0xc0
   32: stp x29, x30, [sp, #0x110]
   36: stp x28, x27, [sp, #0x120]
   40: stp x26, x25, [sp, #0x130]
   44: stp x24, x23, [sp, #0x140]
   48: stp x22, x21, [sp, #0x150]
   52: bl <memset>
   56: cbz w19, +924
   60: mov w9, #0xf35f
   64: mov w10, #0x660d
   68: add x11, x20, #0x28
   72: movk w9, #0x3c6e, lsl #16
   76: mov w14, #0xcd19
   80: mov w16, #0xd9ab
   84: mov w17, #0x688c
   88: mov w15, #0x527f
   92: mov w1, #0xf53a
   96: mov w0, #0xae85
  100: mov w18, #0xe667
  104: mov w8, wzr
  108: movk w10, #0x19, lsl #16
  112: str x11, [sp, #0x8]
  116: add x13, x20, #0x8
  120: add w11, w9, #0x13
  124: movk w14, #0x5be0, lsl #16
  128: movk w16, #0x1f83, lsl #16
  132: movk w17, #0x9b05, lsl #16
  136: movk w15, #0x510e, lsl #16
  140: movk w1, #0xa54f, lsl #16
  144: movk w0, #0xbb67, lsl #16
  148: movk w18, #0x6a09, lsl #16
  152: mov w3, #0x328
  156: madd w3, w3, w10, w9
  160: madd w4, w3, w10, w9
  164: stp w3, w4, [sp, #0x10]
  168: madd w3, w4, w10, w9
  172: madd w4, w3, w10, w9
  176: stp w3, w4, [sp, #0x18]
  180: madd w3, w4, w10, w9
  184: madd w4, w3, w10, w9
  188: stp w3, w4, [sp, #0x20]
  192: madd w3, w4, w10, w9
  196: madd w4, w3, w10, w9
  200: stp w3, w4, [sp, #0x28]
  204: madd w3, w4, w10, w9
  208: madd w4, w3, w10, w9
  212: stp w3, w4, [sp, #0x30]
  216: madd w3, w4, w10, w9
  220: madd w4, w3, w10, w9
  224: stp w3, w4, [sp, #0x38]
  228: madd w3, w4, w10, w9
  232: madd w4, w3, w10, w9
  236: madd w5, w4, w10, w9
  240: stp w3, w4, [sp, #0x40]
  244: ldr x4, [sp, #0x8]
  248: mov x6, x4
  252: madd w3, w5, w10, w9
  256: stp w5, w3, [sp, #0x48]
  260: mov w5, #0x30
  264: ldp w21, w20, [x4, #-0x28]
  268: ldp w22, w26, [x4, #-0x20]
  272: ldr w7, [x6, #0x10]!
  276: ldr w24, [x4, #0x14]
  280: ldp w23, w29, [x4, #-0x4]
  284: ror w25, w20, #0x7
  288: ror w27, w7, #0x11
  292: ror w28, w22, #0x7
  296: subs x5, x5, #0x4
  300: add w21, w21, w23
  304: ror w23, w24, #0x11
  308: eor w25, w25, w20, ror #18
  312: eor w27, w27, w7, ror #19
  316: eor w28, w28, w22, ror #18
  320: eor w23, w23, w24, ror #19
  324: eor w25, w25, w20, lsr #3
  328: add w20, w20, w29
  332: eor w7, w27, w7, lsr #10
  336: eor w27, w28, w22, lsr #3
  340: ldur w28, [x4, #-0x18]
  344: eor w23, w23, w24, lsr #10
  348: add w21, w25, w21
  352: ror w24, w26, #0x7
  356: add w20, w27, w20
  360: add w7, w21, w7
  364: ror w21, w28, #0x7
  368: add w20, w20, w23
  372: ror w23, w7, #0x11
  376: eor w24, w24, w26, ror #18
  380: ror w25, w20, #0x11
  384: eor w21, w21, w28, ror #18
  388: stp w7, w20, [x4, #0x18]
  392: ldp w30, w27, [x4, #0x4]
  396: eor w23, w23, w7, ror #19
  400: eor w25, w25, w20, ror #19
  404: eor w24, w24, w26, lsr #3
  408: eor w21, w21, w28, lsr #3
  412: add w22, w22, w30
  416: add w26, w26, w27
  420: eor w23, w23, w7, lsr #10
  424: eor w7, w25, w20, lsr #10
  428: add w22, w24, w22
  432: add w21, w21, w26
  436: add w20, w22, w23
  440: add w7, w21, w7
  444: stp w20, w7, [x4, #0x20]
  448: mov x4, x6
  452: b.ne +264
  456: adrp x7, <harness_main+0x1da8>
  460: add x7, x7, #0x798
  464: mov x20, x13
  468: mov w22, #0x40
  472: mov w23, w18
  476: mov w21, w0
  480: mov w26, w11
  484: mov w4, w1
  488: mov w24, w15
  492: mov w6, w17
  496: mov w5, w16
  500: mov w25, w14
  504: and w28, w24, w6
  508: bic w29, w5, w24
  512: ror w27, w24, #0x6
  516: orr w28, w28, w29
  520: ror w2, w23, #0x2
  524: eor w29, w21, w26
  528: add w25, w28, w25
  532: eor w27, w27, w24, ror #11
  536: and w29, w23, w29
  540: ldp w30, w28, [x7, #-0x8]
  544: eor w2, w2, w23, ror #13
  548: eor w27, w27, w24, ror #25
  552: subs x22, x22, #0x4
  556: add w25, w25, w30
  560: eor w2, w2, w23, ror #22
  564: ldp w12, w30, [x20, #-0x8]
  568: add w12, w25, w12
  572: and w25, w21, w26
  576: eor w25, w29, w25
  580: add w12, w12, w27
  584: add w2, w2, w25
  588: add w25, w12, w4
  592: add w4, w2, w12
  596: ror w12, w25, #0x6
  600: and w2, w25, w24
  604: bic w27, w6, w25
  608: ror w29, w4, #0x2
  612: orr w2, w2, w27
  616: eor w12, w12, w25, ror #11
  620: eor w27, w23, w21
  624: add w2, w2, w5
  628: eor w5, w29, w4, ror #13
  632: and w29, w23, w21
  636: add w2, w2, w28
  640: eor w12, w12, w25, ror #25
  644: and w27, w4, w27
  648: add w2, w2, w30
  652: eor w5, w5, w4, ror #22
  656: eor w27, w27, w29
  660: add w12, w2, w12
  664: add w2, w5, w27
  668: add w5, w12, w26
  672: add w26, w2, w12
  676: and w2, w5, w25
  680: bic w28, w24, w5
  684: ror w29, w26, #0x2
  688: orr w2, w2, w28
  692: ror w12, w5, #0x6
  696: ldp w28, w30, [x7], #0x10
  700: add w2, w2, w6
  704: eor w6, w29, w26, ror #13
  708: eor w29, w4, w23
  712: and w29, w26, w29
  716: eor w12, w12, w5, ror #11
  720: add w2, w2, w28
  724: and w28, w4, w23
  728: eor w6, w6, w26, ror #22
  732: eor w28, w29, w28
  736: eor w12, w12, w5, ror #25
  740: ldp w27, w29, [x20], #0x10
  744: add w2, w2, w27
  748: add w12, w2, w12
  752: add w2, w6, w28
  756: and w28, w26, w4
  760: add w6, w12, w21
  764: add w21, w2, w12
  768: and w2, w6, w5
  772: bic w27, w25, w6
  776: ror w12, w6, #0x6
  780: orr w2, w2, w27
  784: ror w27, w21, #0x2
  788: add w2, w2, w24
  792: eor w12, w12, w6, ror #11
  796: eor w24, w27, w21, ror #13
  800: eor w27, w26, w4
  804: add w2, w2, w30
  808: eor w12, w12, w6, ror #25
  812: and w27, w21, w27
  816: add w2, w2, w29
  820: eor w24, w24, w21, ror #22
  824: eor w27, w27, w28
  828: add w12, w2, w12
  832: add w2, w24, w27
  836: add w24, w12, w23
  840: add w23, w2, w12
  844: b.ne +504
  848: add w8, w8, #0x1
  852: add w18, w23, w18
  856: add w0, w21, w0
  860: add w11, w26, w11
  864: add w1, w4, w1
  868: add w15, w24, w15
  872: cmp w8, w19
  876: add w17, w6, w17
  880: add w16, w5, w16
  884: add w14, w25, w14
  888: b.ne +156
  892: eor w8, w16, w14
  896: eor w8, w8, w17
  900: eor w8, w8, w1
  904: eor w8, w8, w11
  908: eor w8, w8, w0
  912: eor w8, w8, w15
  916: eor w0, w8, w18
  920: b +932
  924: mov w0, #0x60eb
  928: movk w0, #0xc627, lsl #16
  932: ldp x20, x19, [sp, #0x160]
  936: ldp x22, x21, [sp, #0x150]
  940: ldp x24, x23, [sp, #0x140]
  944: ldp x26, x25, [sp, #0x130]
  948: ldp x28, x27, [sp, #0x120]
  952: ldp x29, x30, [sp, #0x110]
  956: add sp, sp, #0x170
  960: ret
```

#### `bench_popcount__U32` (31 instructions, 124 bytes)
```asm
    0: mov w8, #0x27c0
    4: movk w8, #0x9, lsl #16
    8: mul w8, w0, w8
   12: cbz w8, +116
   16: mov w10, #0x660d
   20: mov w11, #0xf35f
   24: mov w0, wzr
   28: mov w9, #0x37
   32: movk w10, #0x19, lsl #16
   36: movk w11, #0x3c6e, lsl #16
   40: mov w12, #0x1010101
   44: b +56
   48: subs w8, w8, #0x1
   52: b.eq +112
   56: madd w9, w9, w10, w11
   60: cbz w9, +48
   64: lsr w13, w9, #1
   68: and w13, w13, #0x55555555
   72: sub w13, w9, w13
   76: lsr w14, w13, #2
   80: and w13, w13, #0x33333333
   84: and w14, w14, #0x33333333
   88: add w13, w13, w14
   92: add w13, w13, w13, lsr #4
   96: and w13, w13, #0xf0f0f0f
  100: mul w13, w13, w12
  104: add w0, w0, w13, lsr #24
  108: b +48
  112: ret
  116: mov w0, wzr
  120: ret
```

#### `bench_mandelbrot_fixed__U32` (1488 instructions, 5952 bytes)
```asm
    0: mov w8, #0x8000
    4: mov w9, #0x800
    8: mov w0, wzr
   12: mov w10, wzr
   16: movk w8, #0xfffe, lsl #16
   20: movk w9, #0xfffe, lsl #16
   24: b +40
   28: add w10, w10, #0x1
   32: cmp w10, #0x60
   36: b.eq +1008
   40: add w11, w8, w10, lsl #11
   44: mov w12, wzr
   48: b +72
   52: add w14, w14, #0x1
   56: add w12, w12, #0x4
   60: add w0, w14, w15
   64: cmp w12, #0x60
   68: b.eq +28
   72: lsl w13, w12, #11
   76: mov w14, wzr
   80: mov w16, wzr
   84: mov w15, wzr
   88: sub w13, w13, #0x20, lsl #12
   92: smull x17, w15, w15
   96: smull x1, w16, w16
  100: lsr x18, x17, #16
  104: lsr x17, x1, #16
  108: add w1, w17, w18
  112: cmp w1, #0x40, lsl #12
  116: b.gt +308
  120: smull x15, w16, w15
  124: add w16, w13, w18
  128: sub w16, w16, w17
  132: smull x17, w16, w16
  136: add x15, x11, x15, lsr #15
  140: smull x1, w15, w15
  144: lsr x18, x17, #16
  148: lsr x17, x1, #16
  152: add w1, w17, w18
  156: cmp w1, #0x40, lsl #12
  160: b.gt +288
  164: smull x15, w15, w16
  168: add w16, w13, w18
  172: sub w16, w16, w17
  176: smull x17, w16, w16
  180: add x15, x11, x15, lsr #15
  184: smull x18, w15, w15
  188: lsr x17, x17, #16
  192: lsr x18, x18, #16
  196: add w1, w18, w17
  200: cmp w1, #0x40, lsl #12
  204: b.gt +296
  208: smull x15, w15, w16
  212: add w16, w13, w17
  216: sub w18, w16, w18
  220: add x17, x11, x15, lsr #15
  224: smull x15, w18, w18
  228: smull x1, w17, w17
  232: lsr x16, x15, #16
  236: lsr x15, x1, #16
  240: add w1, w15, w16
  244: cmp w1, #0x40, lsl #12
  248: b.gt +304
  252: smull x17, w17, w18
  256: add w14, w14, #0x4
  260: add w16, w13, w16
  264: cmp w14, #0x28
  268: sub w15, w16, w15
  272: add x17, x11, x17, lsr #15
  276: mov w16, w17
  280: b.ne +92
  284: b +308
  288: add w14, w14, #0x1
  292: b +308
  296: add w14, w14, #0x2
  300: b +308
  304: add w14, w14, #0x3
  308: add w13, w9, w12, lsl #11
  312: mov w15, wzr
  316: mov w17, wzr
  320: mov w16, wzr
  324: add w14, w14, w0
  328: smull x18, w16, w16
  332: smull x1, w17, w17
  336: lsr x0, x18, #16
  340: lsr x18, x1, #16
  344: add w1, w18, w0
  348: cmp w1, #0x40, lsl #12
  352: b.gt +544
  356: smull x16, w17, w16
  360: add w17, w13, w0
  364: sub w17, w17, w18
  368: smull x18, w17, w17
  372: add x16, x11, x16, lsr #15
  376: smull x1, w16, w16
  380: lsr x0, x18, #16
  384: lsr x18, x1, #16
  388: add w1, w18, w0
  392: cmp w1, #0x40, lsl #12
  396: b.gt +524
  400: smull x16, w16, w17
  404: add w17, w13, w0
  408: sub w17, w17, w18
  412: smull x18, w17, w17
  416: add x16, x11, x16, lsr #15
  420: smull x0, w16, w16
  424: lsr x18, x18, #16
  428: lsr x0, x0, #16
  432: add w1, w0, w18
  436: cmp w1, #0x40, lsl #12
  440: b.gt +532
  444: smull x16, w16, w17
  448: add w17, w13, w18
  452: sub w0, w17, w0
  456: add x18, x11, x16, lsr #15
  460: smull x16, w0, w0
  464: smull x1, w18, w18
  468: lsr x17, x16, #16
  472: lsr x16, x1, #16
  476: add w1, w16, w17
  480: cmp w1, #0x40, lsl #12
  484: b.gt +540
  488: smull x18, w18, w0
  492: add w15, w15, #0x4
  496: add w17, w13, w17
  500: cmp w15, #0x28
  504: sub w16, w17, w16
  508: add x18, x11, x18, lsr #15
  512: mov w17, w18
  516: b.ne +328
  520: b +544
  524: add w15, w15, #0x1
  528: b +544
  532: add w15, w15, #0x2
  536: b +544
  540: add w15, w15, #0x3
  544: mov w16, wzr
  548: mov w18, wzr
  552: mov w17, wzr
  556: add w15, w15, w14
  560: add w14, w13, #0x800
  564: smull x0, w17, w17
  568: smull x2, w18, w18
  572: lsr x1, x0, #16
  576: lsr x0, x2, #16
  580: add w2, w0, w1
  584: cmp w2, #0x40, lsl #12
  588: b.gt +780
  592: smull x17, w18, w17
  596: add w18, w14, w1
  600: sub w18, w18, w0
  604: smull x0, w18, w18
  608: add x17, x11, x17, lsr #15
  612: smull x2, w17, w17
  616: lsr x1, x0, #16
  620: lsr x0, x2, #16
  624: add w2, w0, w1
  628: cmp w2, #0x40, lsl #12
  632: b.gt +760
  636: smull x17, w17, w18
  640: add w18, w14, w1
  644: sub w18, w18, w0
  648: smull x0, w18, w18
  652: add x17, x11, x17, lsr #15
  656: smull x1, w17, w17
  660: lsr x0, x0, #16
  664: lsr x1, x1, #16
  668: add w2, w1, w0
  672: cmp w2, #0x40, lsl #12
  676: b.gt +768
  680: smull x17, w17, w18
  684: add w18, w14, w0
  688: sub w1, w18, w1
  692: add x0, x11, x17, lsr #15
  696: smull x17, w1, w1
  700: smull x2, w0, w0
  704: lsr x18, x17, #16
  708: lsr x17, x2, #16
  712: add w2, w17, w18
  716: cmp w2, #0x40, lsl #12
  720: b.gt +776
  724: smull x0, w0, w1
  728: add w16, w16, #0x4
  732: add w18, w14, w18
  736: cmp w16, #0x28
  740: sub w17, w18, w17
  744: add x0, x11, x0, lsr #15
  748: mov w18, w0
  752: b.ne +564
  756: b +780
  760: add w16, w16, #0x1
  764: b +780
  768: add w16, w16, #0x2
  772: b +780
  776: add w16, w16, #0x3
  780: mov w14, wzr
  784: mov w18, wzr
  788: mov w17, wzr
  792: add w15, w16, w15
  796: add w13, w13, #0x1, lsl #12
  800: smull x16, w17, w17
  804: smull x0, w18, w18
  808: lsr x16, x16, #16
  812: lsr x0, x0, #16
  816: add w1, w0, w16
  820: cmp w1, #0x40, lsl #12
  824: b.gt +56
  828: smull x17, w18, w17
  832: add w18, w13, w16
  836: add x16, x11, x17, lsr #15
  840: sub w17, w18, w0
  844: smull x18, w17, w17
  848: smull x1, w16, w16
  852: lsr x0, x18, #16
  856: lsr x18, x1, #16
  860: add w1, w18, w0
  864: cmp w1, #0x40, lsl #12
  868: b.gt +52
  872: smull x16, w16, w17
  876: add w17, w13, w0
  880: sub w17, w17, w18
  884: smull x18, w17, w17
  888: add x16, x11, x16, lsr #15
  892: smull x0, w16, w16
  896: lsr x18, x18, #16
  900: lsr x0, x0, #16
  904: add w1, w0, w18
  908: cmp w1, #0x40, lsl #12
  912: b.gt +992
  916: smull x16, w16, w17
  920: add w17, w13, w18
  924: sub w0, w17, w0
  928: add x18, x11, x16, lsr #15
  932: smull x16, w0, w0
  936: smull x1, w18, w18
  940: lsr x17, x16, #16
  944: lsr x16, x1, #16
  948: add w1, w16, w17
  952: cmp w1, #0x40, lsl #12
  956: b.gt +1000
  960: smull x18, w18, w0
  964: add w14, w14, #0x4
  968: add w17, w13, w17
  972: cmp w14, #0x28
  976: sub w17, w17, w16
  980: add x18, x11, x18, lsr #15
  984: b.ne +800
  988: b +56
  992: add w14, w14, #0x2
  996: b +56
 1000: add w14, w14, #0x3
 1004: b +56
 1008: mov w10, wzr
 1012: b +1028
 1016: add w10, w10, #0x1
 1020: cmp w10, #0x60
 1024: b.eq +1996
 1028: add w11, w8, w10, lsl #11
 1032: mov w12, wzr
 1036: b +1060
 1040: add w14, w14, #0x1
 1044: add w12, w12, #0x4
 1048: add w0, w14, w15
 1052: cmp w12, #0x60
 1056: b.eq +1016
 1060: lsl w13, w12, #11
 1064: mov w14, wzr
 1068: mov w16, wzr
 1072: mov w15, wzr
 1076: sub w13, w13, #0x20, lsl #12
 1080: smull x17, w15, w15
 1084: smull x1, w16, w16
 1088: lsr x18, x17, #16
 1092: lsr x17, x1, #16
 1096: add w1, w17, w18
 1100: cmp w1, #0x40, lsl #12
 1104: b.gt +1296
 1108: smull x15, w16, w15
 1112: add w16, w13, w18
 1116: sub w16, w16, w17
 1120: smull x17, w16, w16
 1124: add x15, x11, x15, lsr #15
 1128: smull x1, w15, w15
 1132: lsr x18, x17, #16
 1136: lsr x17, x1, #16
 1140: add w1, w17, w18
 1144: cmp w1, #0x40, lsl #12
 1148: b.gt +1276
 1152: smull x15, w15, w16
 1156: add w16, w13, w18
 1160: sub w16, w16, w17
 1164: smull x17, w16, w16
 1168: add x15, x11, x15, lsr #15
 1172: smull x18, w15, w15
 1176: lsr x17, x17, #16
 1180: lsr x18, x18, #16
 1184: add w1, w18, w17
 1188: cmp w1, #0x40, lsl #12
 1192: b.gt +1284
 1196: smull x15, w15, w16
 1200: add w16, w13, w17
 1204: sub w18, w16, w18
 1208: add x17, x11, x15, lsr #15
 1212: smull x15, w18, w18
 1216: smull x1, w17, w17
 1220: lsr x16, x15, #16
 1224: lsr x15, x1, #16
 1228: add w1, w15, w16
 1232: cmp w1, #0x40, lsl #12
 1236: b.gt +1292
 1240: smull x17, w17, w18
 1244: add w14, w14, #0x4
 1248: add w16, w13, w16
 1252: cmp w14, #0x28
 1256: sub w15, w16, w15
 1260: add x17, x11, x17, lsr #15
 1264: mov w16, w17
 1268: b.ne +1080
 1272: b +1296
 1276: add w14, w14, #0x1
 1280: b +1296
 1284: add w14, w14, #0x2
 1288: b +1296
 1292: add w14, w14, #0x3
 1296: add w13, w9, w12, lsl #11
 1300: mov w15, wzr
 1304: mov w17, wzr
 1308: mov w16, wzr
 1312: add w14, w14, w0
 1316: smull x18, w16, w16
 1320: smull x1, w17, w17
 1324: lsr x0, x18, #16
 1328: lsr x18, x1, #16
 1332: add w1, w18, w0
 1336: cmp w1, #0x40, lsl #12
 1340: b.gt +1532
 1344: smull x16, w17, w16
 1348: add w17, w13, w0
 1352: sub w17, w17, w18
 1356: smull x18, w17, w17
 1360: add x16, x11, x16, lsr #15
 1364: smull x1, w16, w16
 1368: lsr x0, x18, #16
 1372: lsr x18, x1, #16
 1376: add w1, w18, w0
 1380: cmp w1, #0x40, lsl #12
 1384: b.gt +1512
 1388: smull x16, w16, w17
 1392: add w17, w13, w0
 1396: sub w17, w17, w18
 1400: smull x18, w17, w17
 1404: add x16, x11, x16, lsr #15
 1408: smull x0, w16, w16
 1412: lsr x18, x18, #16
 1416: lsr x0, x0, #16
 1420: add w1, w0, w18
 1424: cmp w1, #0x40, lsl #12
 1428: b.gt +1520
 1432: smull x16, w16, w17
 1436: add w17, w13, w18
 1440: sub w0, w17, w0
 1444: add x18, x11, x16, lsr #15
 1448: smull x16, w0, w0
 1452: smull x1, w18, w18
 1456: lsr x17, x16, #16
 1460: lsr x16, x1, #16
 1464: add w1, w16, w17
 1468: cmp w1, #0x40, lsl #12
 1472: b.gt +1528
 1476: smull x18, w18, w0
 1480: add w15, w15, #0x4
 1484: add w17, w13, w17
 1488: cmp w15, #0x28
 1492: sub w16, w17, w16
 1496: add x18, x11, x18, lsr #15
 1500: mov w17, w18
 1504: b.ne +1316
 1508: b +1532
 1512: add w15, w15, #0x1
 1516: b +1532
 1520: add w15, w15, #0x2
 1524: b +1532
 1528: add w15, w15, #0x3
 1532: mov w16, wzr
 1536: mov w18, wzr
 1540: mov w17, wzr
 1544: add w15, w15, w14
 1548: add w14, w13, #0x800
 1552: smull x0, w17, w17
 1556: smull x2, w18, w18
 1560: lsr x1, x0, #16
 1564: lsr x0, x2, #16
 1568: add w2, w0, w1
 1572: cmp w2, #0x40, lsl #12
 1576: b.gt +1768
 1580: smull x17, w18, w17
 1584: add w18, w14, w1
 1588: sub w18, w18, w0
 1592: smull x0, w18, w18
 1596: add x17, x11, x17, lsr #15
 1600: smull x2, w17, w17
 1604: lsr x1, x0, #16
 1608: lsr x0, x2, #16
 1612: add w2, w0, w1
 1616: cmp w2, #0x40, lsl #12
 1620: b.gt +1748
 1624: smull x17, w17, w18
 1628: add w18, w14, w1
 1632: sub w18, w18, w0
 1636: smull x0, w18, w18
 1640: add x17, x11, x17, lsr #15
 1644: smull x1, w17, w17
 1648: lsr x0, x0, #16
 1652: lsr x1, x1, #16
 1656: add w2, w1, w0
 1660: cmp w2, #0x40, lsl #12
 1664: b.gt +1756
 1668: smull x17, w17, w18
 1672: add w18, w14, w0
 1676: sub w1, w18, w1
 1680: add x0, x11, x17, lsr #15
 1684: smull x17, w1, w1
 1688: smull x2, w0, w0
 1692: lsr x18, x17, #16
 1696: lsr x17, x2, #16
 1700: add w2, w17, w18
 1704: cmp w2, #0x40, lsl #12
 1708: b.gt +1764
 1712: smull x0, w0, w1
 1716: add w16, w16, #0x4
 1720: add w18, w14, w18
 1724: cmp w16, #0x28
 1728: sub w17, w18, w17
 1732: add x0, x11, x0, lsr #15
 1736: mov w18, w0
 1740: b.ne +1552
 1744: b +1768
 1748: add w16, w16, #0x1
 1752: b +1768
 1756: add w16, w16, #0x2
 1760: b +1768
 1764: add w16, w16, #0x3
 1768: mov w14, wzr
 1772: mov w18, wzr
 1776: mov w17, wzr
 1780: add w15, w16, w15
 1784: add w13, w13, #0x1, lsl #12
 1788: smull x16, w17, w17
 1792: smull x0, w18, w18
 1796: lsr x16, x16, #16
 1800: lsr x0, x0, #16
 1804: add w1, w0, w16
 1808: cmp w1, #0x40, lsl #12
 1812: b.gt +1044
 1816: smull x17, w18, w17
 1820: add w18, w13, w16
 1824: add x16, x11, x17, lsr #15
 1828: sub w17, w18, w0
 1832: smull x18, w17, w17
 1836: smull x1, w16, w16
 1840: lsr x0, x18, #16
 1844: lsr x18, x1, #16
 1848: add w1, w18, w0
 1852: cmp w1, #0x40, lsl #12
 1856: b.gt +1040
 1860: smull x16, w16, w17
 1864: add w17, w13, w0
 1868: sub w17, w17, w18
 1872: smull x18, w17, w17
 1876: add x16, x11, x16, lsr #15
 1880: smull x0, w16, w16
 1884: lsr x18, x18, #16
 1888: lsr x0, x0, #16
 1892: add w1, w0, w18
 1896: cmp w1, #0x40, lsl #12
 1900: b.gt +1980
 1904: smull x16, w16, w17
 1908: add w17, w13, w18
 1912: sub w0, w17, w0
 1916: add x18, x11, x16, lsr #15
 1920: smull x16, w0, w0
 1924: smull x1, w18, w18
 1928: lsr x17, x16, #16
 1932: lsr x16, x1, #16
 1936: add w1, w16, w17
 1940: cmp w1, #0x40, lsl #12
 1944: b.gt +1988
 1948: smull x18, w18, w0
 1952: add w14, w14, #0x4
 1956: add w17, w13, w17
 1960: cmp w14, #0x28
 1964: sub w17, w17, w16
 1968: add x18, x11, x18, lsr #15
 1972: b.ne +1788
 1976: b +1044
 1980: add w14, w14, #0x2
 1984: b +1044
 1988: add w14, w14, #0x3
 1992: b +1044
 1996: mov w10, wzr
 2000: b +2016
 2004: add w10, w10, #0x1
 2008: cmp w10, #0x60
 2012: b.eq +2984
 2016: add w11, w8, w10, lsl #11
 2020: mov w12, wzr
 2024: b +2048
 2028: add w14, w14, #0x1
 2032: add w12, w12, #0x4
 2036: add w0, w14, w15
 2040: cmp w12, #0x60
 2044: b.eq +2004
 2048: lsl w13, w12, #11
 2052: mov w14, wzr
 2056: mov w16, wzr
 2060: mov w15, wzr
 2064: sub w13, w13, #0x20, lsl #12
 2068: smull x17, w15, w15
 2072: smull x1, w16, w16
 2076: lsr x18, x17, #16
 2080: lsr x17, x1, #16
 2084: add w1, w17, w18
 2088: cmp w1, #0x40, lsl #12
 2092: b.gt +2284
 2096: smull x15, w16, w15
 2100: add w16, w13, w18
 2104: sub w16, w16, w17
 2108: smull x17, w16, w16
 2112: add x15, x11, x15, lsr #15
 2116: smull x1, w15, w15
 2120: lsr x18, x17, #16
 2124: lsr x17, x1, #16
 2128: add w1, w17, w18
 2132: cmp w1, #0x40, lsl #12
 2136: b.gt +2264
 2140: smull x15, w15, w16
 2144: add w16, w13, w18
 2148: sub w16, w16, w17
 2152: smull x17, w16, w16
 2156: add x15, x11, x15, lsr #15
 2160: smull x18, w15, w15
 2164: lsr x17, x17, #16
 2168: lsr x18, x18, #16
 2172: add w1, w18, w17
 2176: cmp w1, #0x40, lsl #12
 2180: b.gt +2272
 2184: smull x15, w15, w16
 2188: add w16, w13, w17
 2192: sub w18, w16, w18
 2196: add x17, x11, x15, lsr #15
 2200: smull x15, w18, w18
 2204: smull x1, w17, w17
 2208: lsr x16, x15, #16
 2212: lsr x15, x1, #16
 2216: add w1, w15, w16
 2220: cmp w1, #0x40, lsl #12
 2224: b.gt +2280
 2228: smull x17, w17, w18
 2232: add w14, w14, #0x4
 2236: add w16, w13, w16
 2240: cmp w14, #0x28
 2244: sub w15, w16, w15
 2248: add x17, x11, x17, lsr #15
 2252: mov w16, w17
 2256: b.ne +2068
 2260: b +2284
 2264: add w14, w14, #0x1
 2268: b +2284
 2272: add w14, w14, #0x2
 2276: b +2284
 2280: add w14, w14, #0x3
 2284: add w13, w9, w12, lsl #11
 2288: mov w15, wzr
 2292: mov w17, wzr
 2296: mov w16, wzr
 2300: add w14, w14, w0
 2304: smull x18, w16, w16
 2308: smull x1, w17, w17
 2312: lsr x0, x18, #16
 2316: lsr x18, x1, #16
 2320: add w1, w18, w0
 2324: cmp w1, #0x40, lsl #12
 2328: b.gt +2520
 2332: smull x16, w17, w16
 2336: add w17, w13, w0
 2340: sub w17, w17, w18
 2344: smull x18, w17, w17
 2348: add x16, x11, x16, lsr #15
 2352: smull x1, w16, w16
 2356: lsr x0, x18, #16
 2360: lsr x18, x1, #16
 2364: add w1, w18, w0
 2368: cmp w1, #0x40, lsl #12
 2372: b.gt +2500
 2376: smull x16, w16, w17
 2380: add w17, w13, w0
 2384: sub w17, w17, w18
 2388: smull x18, w17, w17
 2392: add x16, x11, x16, lsr #15
 2396: smull x0, w16, w16
 2400: lsr x18, x18, #16
 2404: lsr x0, x0, #16
 2408: add w1, w0, w18
 2412: cmp w1, #0x40, lsl #12
 2416: b.gt +2508
 2420: smull x16, w16, w17
 2424: add w17, w13, w18
 2428: sub w0, w17, w0
 2432: add x18, x11, x16, lsr #15
 2436: smull x16, w0, w0
 2440: smull x1, w18, w18
 2444: lsr x17, x16, #16
 2448: lsr x16, x1, #16
 2452: add w1, w16, w17
 2456: cmp w1, #0x40, lsl #12
 2460: b.gt +2516
 2464: smull x18, w18, w0
 2468: add w15, w15, #0x4
 2472: add w17, w13, w17
 2476: cmp w15, #0x28
 2480: sub w16, w17, w16
 2484: add x18, x11, x18, lsr #15
 2488: mov w17, w18
 2492: b.ne +2304
 2496: b +2520
 2500: add w15, w15, #0x1
 2504: b +2520
 2508: add w15, w15, #0x2
 2512: b +2520
 2516: add w15, w15, #0x3
 2520: mov w16, wzr
 2524: mov w18, wzr
 2528: mov w17, wzr
 2532: add w15, w15, w14
 2536: add w14, w13, #0x800
 2540: smull x0, w17, w17
 2544: smull x2, w18, w18
 2548: lsr x1, x0, #16
 2552: lsr x0, x2, #16
 2556: add w2, w0, w1
 2560: cmp w2, #0x40, lsl #12
 2564: b.gt +2756
 2568: smull x17, w18, w17
 2572: add w18, w14, w1
 2576: sub w18, w18, w0
 2580: smull x0, w18, w18
 2584: add x17, x11, x17, lsr #15
 2588: smull x2, w17, w17
 2592: lsr x1, x0, #16
 2596: lsr x0, x2, #16
 2600: add w2, w0, w1
 2604: cmp w2, #0x40, lsl #12
 2608: b.gt +2736
 2612: smull x17, w17, w18
 2616: add w18, w14, w1
 2620: sub w18, w18, w0
 2624: smull x0, w18, w18
 2628: add x17, x11, x17, lsr #15
 2632: smull x1, w17, w17
 2636: lsr x0, x0, #16
 2640: lsr x1, x1, #16
 2644: add w2, w1, w0
 2648: cmp w2, #0x40, lsl #12
 2652: b.gt +2744
 2656: smull x17, w17, w18
 2660: add w18, w14, w0
 2664: sub w1, w18, w1
 2668: add x0, x11, x17, lsr #15
 2672: smull x17, w1, w1
 2676: smull x2, w0, w0
 2680: lsr x18, x17, #16
 2684: lsr x17, x2, #16
 2688: add w2, w17, w18
 2692: cmp w2, #0x40, lsl #12
 2696: b.gt +2752
 2700: smull x0, w0, w1
 2704: add w16, w16, #0x4
 2708: add w18, w14, w18
 2712: cmp w16, #0x28
 2716: sub w17, w18, w17
 2720: add x0, x11, x0, lsr #15
 2724: mov w18, w0
 2728: b.ne +2540
 2732: b +2756
 2736: add w16, w16, #0x1
 2740: b +2756
 2744: add w16, w16, #0x2
 2748: b +2756
 2752: add w16, w16, #0x3
 2756: mov w14, wzr
 2760: mov w18, wzr
 2764: mov w17, wzr
 2768: add w15, w16, w15
 2772: add w13, w13, #0x1, lsl #12
 2776: smull x16, w17, w17
 2780: smull x0, w18, w18
 2784: lsr x16, x16, #16
 2788: lsr x0, x0, #16
 2792: add w1, w0, w16
 2796: cmp w1, #0x40, lsl #12
 2800: b.gt +2032
 2804: smull x17, w18, w17
 2808: add w18, w13, w16
 2812: add x16, x11, x17, lsr #15
 2816: sub w17, w18, w0
 2820: smull x18, w17, w17
 2824: smull x1, w16, w16
 2828: lsr x0, x18, #16
 2832: lsr x18, x1, #16
 2836: add w1, w18, w0
 2840: cmp w1, #0x40, lsl #12
 2844: b.gt +2028
 2848: smull x16, w16, w17
 2852: add w17, w13, w0
 2856: sub w17, w17, w18
 2860: smull x18, w17, w17
 2864: add x16, x11, x16, lsr #15
 2868: smull x0, w16, w16
 2872: lsr x18, x18, #16
 2876: lsr x0, x0, #16
 2880: add w1, w0, w18
 2884: cmp w1, #0x40, lsl #12
 2888: b.gt +2968
 2892: smull x16, w16, w17
 2896: add w17, w13, w18
 2900: sub w0, w17, w0
 2904: add x18, x11, x16, lsr #15
 2908: smull x16, w0, w0
 2912: smull x1, w18, w18
 2916: lsr x17, x16, #16
 2920: lsr x16, x1, #16
 2924: add w1, w16, w17
 2928: cmp w1, #0x40, lsl #12
 2932: b.gt +2976
 2936: smull x18, w18, w0
 2940: add w14, w14, #0x4
 2944: add w17, w13, w17
 2948: cmp w14, #0x28
 2952: sub w17, w17, w16
 2956: add x18, x11, x18, lsr #15
 2960: b.ne +2776
 2964: b +2032
 2968: add w14, w14, #0x2
 2972: b +2032
 2976: add w14, w14, #0x3
 2980: b +2032
 2984: mov w10, wzr
 2988: b +3004
 2992: add w10, w10, #0x1
 2996: cmp w10, #0x60
 3000: b.eq +3972
 3004: add w11, w8, w10, lsl #11
 3008: mov w12, wzr
 3012: b +3036
 3016: add w14, w14, #0x1
 3020: add w12, w12, #0x4
 3024: add w0, w14, w15
 3028: cmp w12, #0x60
 3032: b.eq +2992
 3036: lsl w13, w12, #11
 3040: mov w14, wzr
 3044: mov w16, wzr
 3048: mov w15, wzr
 3052: sub w13, w13, #0x20, lsl #12
 3056: smull x17, w15, w15
 3060: smull x1, w16, w16
 3064: lsr x18, x17, #16
 3068: lsr x17, x1, #16
 3072: add w1, w17, w18
 3076: cmp w1, #0x40, lsl #12
 3080: b.gt +3272
 3084: smull x15, w16, w15
 3088: add w16, w13, w18
 3092: sub w16, w16, w17
 3096: smull x17, w16, w16
 3100: add x15, x11, x15, lsr #15
 3104: smull x1, w15, w15
 3108: lsr x18, x17, #16
 3112: lsr x17, x1, #16
 3116: add w1, w17, w18
 3120: cmp w1, #0x40, lsl #12
 3124: b.gt +3252
 3128: smull x15, w15, w16
 3132: add w16, w13, w18
 3136: sub w16, w16, w17
 3140: smull x17, w16, w16
 3144: add x15, x11, x15, lsr #15
 3148: smull x18, w15, w15
 3152: lsr x17, x17, #16
 3156: lsr x18, x18, #16
 3160: add w1, w18, w17
 3164: cmp w1, #0x40, lsl #12
 3168: b.gt +3260
 3172: smull x15, w15, w16
 3176: add w16, w13, w17
 3180: sub w18, w16, w18
 3184: add x17, x11, x15, lsr #15
 3188: smull x15, w18, w18
 3192: smull x1, w17, w17
 3196: lsr x16, x15, #16
 3200: lsr x15, x1, #16
 3204: add w1, w15, w16
 3208: cmp w1, #0x40, lsl #12
 3212: b.gt +3268
 3216: smull x17, w17, w18
 3220: add w14, w14, #0x4
 3224: add w16, w13, w16
 3228: cmp w14, #0x28
 3232: sub w15, w16, w15
 3236: add x17, x11, x17, lsr #15
 3240: mov w16, w17
 3244: b.ne +3056
 3248: b +3272
 3252: add w14, w14, #0x1
 3256: b +3272
 3260: add w14, w14, #0x2
 3264: b +3272
 3268: add w14, w14, #0x3
 3272: add w13, w9, w12, lsl #11
 3276: mov w15, wzr
 3280: mov w17, wzr
 3284: mov w16, wzr
 3288: add w14, w14, w0
 3292: smull x18, w16, w16
 3296: smull x1, w17, w17
 3300: lsr x0, x18, #16
 3304: lsr x18, x1, #16
 3308: add w1, w18, w0
 3312: cmp w1, #0x40, lsl #12
 3316: b.gt +3508
 3320: smull x16, w17, w16
 3324: add w17, w13, w0
 3328: sub w17, w17, w18
 3332: smull x18, w17, w17
 3336: add x16, x11, x16, lsr #15
 3340: smull x1, w16, w16
 3344: lsr x0, x18, #16
 3348: lsr x18, x1, #16
 3352: add w1, w18, w0
 3356: cmp w1, #0x40, lsl #12
 3360: b.gt +3488
 3364: smull x16, w16, w17
 3368: add w17, w13, w0
 3372: sub w17, w17, w18
 3376: smull x18, w17, w17
 3380: add x16, x11, x16, lsr #15
 3384: smull x0, w16, w16
 3388: lsr x18, x18, #16
 3392: lsr x0, x0, #16
 3396: add w1, w0, w18
 3400: cmp w1, #0x40, lsl #12
 3404: b.gt +3496
 3408: smull x16, w16, w17
 3412: add w17, w13, w18
 3416: sub w0, w17, w0
 3420: add x18, x11, x16, lsr #15
 3424: smull x16, w0, w0
 3428: smull x1, w18, w18
 3432: lsr x17, x16, #16
 3436: lsr x16, x1, #16
 3440: add w1, w16, w17
 3444: cmp w1, #0x40, lsl #12
 3448: b.gt +3504
 3452: smull x18, w18, w0
 3456: add w15, w15, #0x4
 3460: add w17, w13, w17
 3464: cmp w15, #0x28
 3468: sub w16, w17, w16
 3472: add x18, x11, x18, lsr #15
 3476: mov w17, w18
 3480: b.ne +3292
 3484: b +3508
 3488: add w15, w15, #0x1
 3492: b +3508
 3496: add w15, w15, #0x2
 3500: b +3508
 3504: add w15, w15, #0x3
 3508: mov w16, wzr
 3512: mov w18, wzr
 3516: mov w17, wzr
 3520: add w15, w15, w14
 3524: add w14, w13, #0x800
 3528: smull x0, w17, w17
 3532: smull x2, w18, w18
 3536: lsr x1, x0, #16
 3540: lsr x0, x2, #16
 3544: add w2, w0, w1
 3548: cmp w2, #0x40, lsl #12
 3552: b.gt +3744
 3556: smull x17, w18, w17
 3560: add w18, w14, w1
 3564: sub w18, w18, w0
 3568: smull x0, w18, w18
 3572: add x17, x11, x17, lsr #15
 3576: smull x2, w17, w17
 3580: lsr x1, x0, #16
 3584: lsr x0, x2, #16
 3588: add w2, w0, w1
 3592: cmp w2, #0x40, lsl #12
 3596: b.gt +3724
 3600: smull x17, w17, w18
 3604: add w18, w14, w1
 3608: sub w18, w18, w0
 3612: smull x0, w18, w18
 3616: add x17, x11, x17, lsr #15
 3620: smull x1, w17, w17
 3624: lsr x0, x0, #16
 3628: lsr x1, x1, #16
 3632: add w2, w1, w0
 3636: cmp w2, #0x40, lsl #12
 3640: b.gt +3732
 3644: smull x17, w17, w18
 3648: add w18, w14, w0
 3652: sub w1, w18, w1
 3656: add x0, x11, x17, lsr #15
 3660: smull x17, w1, w1
 3664: smull x2, w0, w0
 3668: lsr x18, x17, #16
 3672: lsr x17, x2, #16
 3676: add w2, w17, w18
 3680: cmp w2, #0x40, lsl #12
 3684: b.gt +3740
 3688: smull x0, w0, w1
 3692: add w16, w16, #0x4
 3696: add w18, w14, w18
 3700: cmp w16, #0x28
 3704: sub w17, w18, w17
 3708: add x0, x11, x0, lsr #15
 3712: mov w18, w0
 3716: b.ne +3528
 3720: b +3744
 3724: add w16, w16, #0x1
 3728: b +3744
 3732: add w16, w16, #0x2
 3736: b +3744
 3740: add w16, w16, #0x3
 3744: mov w14, wzr
 3748: mov w18, wzr
 3752: mov w17, wzr
 3756: add w15, w16, w15
 3760: add w13, w13, #0x1, lsl #12
 3764: smull x16, w17, w17
 3768: smull x0, w18, w18
 3772: lsr x16, x16, #16
 3776: lsr x0, x0, #16
 3780: add w1, w0, w16
 3784: cmp w1, #0x40, lsl #12
 3788: b.gt +3020
 3792: smull x17, w18, w17
 3796: add w18, w13, w16
 3800: add x16, x11, x17, lsr #15
 3804: sub w17, w18, w0
 3808: smull x18, w17, w17
 3812: smull x1, w16, w16
 3816: lsr x0, x18, #16
 3820: lsr x18, x1, #16
 3824: add w1, w18, w0
 3828: cmp w1, #0x40, lsl #12
 3832: b.gt +3016
 3836: smull x16, w16, w17
 3840: add w17, w13, w0
 3844: sub w17, w17, w18
 3848: smull x18, w17, w17
 3852: add x16, x11, x16, lsr #15
 3856: smull x0, w16, w16
 3860: lsr x18, x18, #16
 3864: lsr x0, x0, #16
 3868: add w1, w0, w18
 3872: cmp w1, #0x40, lsl #12
 3876: b.gt +3956
 3880: smull x16, w16, w17
 3884: add w17, w13, w18
 3888: sub w0, w17, w0
 3892: add x18, x11, x16, lsr #15
 3896: smull x16, w0, w0
 3900: smull x1, w18, w18
 3904: lsr x17, x16, #16
 3908: lsr x16, x1, #16
 3912: add w1, w16, w17
 3916: cmp w1, #0x40, lsl #12
 3920: b.gt +3964
 3924: smull x18, w18, w0
 3928: add w14, w14, #0x4
 3932: add w17, w13, w17
 3936: cmp w14, #0x28
 3940: sub w17, w17, w16
 3944: add x18, x11, x18, lsr #15
 3948: b.ne +3764
 3952: b +3020
 3956: add w14, w14, #0x2
 3960: b +3020
 3964: add w14, w14, #0x3
 3968: b +3020
 3972: mov w10, wzr
 3976: b +3992
 3980: add w10, w10, #0x1
 3984: cmp w10, #0x60
 3988: b.eq +4960
 3992: add w11, w8, w10, lsl #11
 3996: mov w12, wzr
 4000: b +4024
 4004: add w14, w14, #0x1
 4008: add w12, w12, #0x4
 4012: add w0, w14, w15
 4016: cmp w12, #0x60
 4020: b.eq +3980
 4024: lsl w13, w12, #11
 4028: mov w14, wzr
 4032: mov w16, wzr
 4036: mov w15, wzr
 4040: sub w13, w13, #0x20, lsl #12
 4044: smull x17, w15, w15
 4048: smull x1, w16, w16
 4052: lsr x18, x17, #16
 4056: lsr x17, x1, #16
 4060: add w1, w17, w18
 4064: cmp w1, #0x40, lsl #12
 4068: b.gt +4260
 4072: smull x15, w16, w15
 4076: add w16, w13, w18
 4080: sub w16, w16, w17
 4084: smull x17, w16, w16
 4088: add x15, x11, x15, lsr #15
 4092: smull x1, w15, w15
 4096: lsr x18, x17, #16
 4100: lsr x17, x1, #16
 4104: add w1, w17, w18
 4108: cmp w1, #0x40, lsl #12
 4112: b.gt +4240
 4116: smull x15, w15, w16
 4120: add w16, w13, w18
 4124: sub w16, w16, w17
 4128: smull x17, w16, w16
 4132: add x15, x11, x15, lsr #15
 4136: smull x18, w15, w15
 4140: lsr x17, x17, #16
 4144: lsr x18, x18, #16
 4148: add w1, w18, w17
 4152: cmp w1, #0x40, lsl #12
 4156: b.gt +4248
 4160: smull x15, w15, w16
 4164: add w16, w13, w17
 4168: sub w18, w16, w18
 4172: add x17, x11, x15, lsr #15
 4176: smull x15, w18, w18
 4180: smull x1, w17, w17
 4184: lsr x16, x15, #16
 4188: lsr x15, x1, #16
 4192: add w1, w15, w16
 4196: cmp w1, #0x40, lsl #12
 4200: b.gt +4256
 4204: smull x17, w17, w18
 4208: add w14, w14, #0x4
 4212: add w16, w13, w16
 4216: cmp w14, #0x28
 4220: sub w15, w16, w15
 4224: add x17, x11, x17, lsr #15
 4228: mov w16, w17
 4232: b.ne +4044
 4236: b +4260
 4240: add w14, w14, #0x1
 4244: b +4260
 4248: add w14, w14, #0x2
 4252: b +4260
 4256: add w14, w14, #0x3
 4260: add w13, w9, w12, lsl #11
 4264: mov w15, wzr
 4268: mov w17, wzr
 4272: mov w16, wzr
 4276: add w14, w14, w0
 4280: smull x18, w16, w16
 4284: smull x1, w17, w17
 4288: lsr x0, x18, #16
 4292: lsr x18, x1, #16
 4296: add w1, w18, w0
 4300: cmp w1, #0x40, lsl #12
 4304: b.gt +4496
 4308: smull x16, w17, w16
 4312: add w17, w13, w0
 4316: sub w17, w17, w18
 4320: smull x18, w17, w17
 4324: add x16, x11, x16, lsr #15
 4328: smull x1, w16, w16
 4332: lsr x0, x18, #16
 4336: lsr x18, x1, #16
 4340: add w1, w18, w0
 4344: cmp w1, #0x40, lsl #12
 4348: b.gt +4476
 4352: smull x16, w16, w17
 4356: add w17, w13, w0
 4360: sub w17, w17, w18
 4364: smull x18, w17, w17
 4368: add x16, x11, x16, lsr #15
 4372: smull x0, w16, w16
 4376: lsr x18, x18, #16
 4380: lsr x0, x0, #16
 4384: add w1, w0, w18
 4388: cmp w1, #0x40, lsl #12
 4392: b.gt +4484
 4396: smull x16, w16, w17
 4400: add w17, w13, w18
 4404: sub w0, w17, w0
 4408: add x18, x11, x16, lsr #15
 4412: smull x16, w0, w0
 4416: smull x1, w18, w18
 4420: lsr x17, x16, #16
 4424: lsr x16, x1, #16
 4428: add w1, w16, w17
 4432: cmp w1, #0x40, lsl #12
 4436: b.gt +4492
 4440: smull x18, w18, w0
 4444: add w15, w15, #0x4
 4448: add w17, w13, w17
 4452: cmp w15, #0x28
 4456: sub w16, w17, w16
 4460: add x18, x11, x18, lsr #15
 4464: mov w17, w18
 4468: b.ne +4280
 4472: b +4496
 4476: add w15, w15, #0x1
 4480: b +4496
 4484: add w15, w15, #0x2
 4488: b +4496
 4492: add w15, w15, #0x3
 4496: mov w16, wzr
 4500: mov w18, wzr
 4504: mov w17, wzr
 4508: add w15, w15, w14
 4512: add w14, w13, #0x800
 4516: smull x0, w17, w17
 4520: smull x2, w18, w18
 4524: lsr x1, x0, #16
 4528: lsr x0, x2, #16
 4532: add w2, w0, w1
 4536: cmp w2, #0x40, lsl #12
 4540: b.gt +4732
 4544: smull x17, w18, w17
 4548: add w18, w14, w1
 4552: sub w18, w18, w0
 4556: smull x0, w18, w18
 4560: add x17, x11, x17, lsr #15
 4564: smull x2, w17, w17
 4568: lsr x1, x0, #16
 4572: lsr x0, x2, #16
 4576: add w2, w0, w1
 4580: cmp w2, #0x40, lsl #12
 4584: b.gt +4712
 4588: smull x17, w17, w18
 4592: add w18, w14, w1
 4596: sub w18, w18, w0
 4600: smull x0, w18, w18
 4604: add x17, x11, x17, lsr #15
 4608: smull x1, w17, w17
 4612: lsr x0, x0, #16
 4616: lsr x1, x1, #16
 4620: add w2, w1, w0
 4624: cmp w2, #0x40, lsl #12
 4628: b.gt +4720
 4632: smull x17, w17, w18
 4636: add w18, w14, w0
 4640: sub w1, w18, w1
 4644: add x0, x11, x17, lsr #15
 4648: smull x17, w1, w1
 4652: smull x2, w0, w0
 4656: lsr x18, x17, #16
 4660: lsr x17, x2, #16
 4664: add w2, w17, w18
 4668: cmp w2, #0x40, lsl #12
 4672: b.gt +4728
 4676: smull x0, w0, w1
 4680: add w16, w16, #0x4
 4684: add w18, w14, w18
 4688: cmp w16, #0x28
 4692: sub w17, w18, w17
 4696: add x0, x11, x0, lsr #15
 4700: mov w18, w0
 4704: b.ne +4516
 4708: b +4732
 4712: add w16, w16, #0x1
 4716: b +4732
 4720: add w16, w16, #0x2
 4724: b +4732
 4728: add w16, w16, #0x3
 4732: mov w14, wzr
 4736: mov w18, wzr
 4740: mov w17, wzr
 4744: add w15, w16, w15
 4748: add w13, w13, #0x1, lsl #12
 4752: smull x16, w17, w17
 4756: smull x0, w18, w18
 4760: lsr x16, x16, #16
 4764: lsr x0, x0, #16
 4768: add w1, w0, w16
 4772: cmp w1, #0x40, lsl #12
 4776: b.gt +4008
 4780: smull x17, w18, w17
 4784: add w18, w13, w16
 4788: add x16, x11, x17, lsr #15
 4792: sub w17, w18, w0
 4796: smull x18, w17, w17
 4800: smull x1, w16, w16
 4804: lsr x0, x18, #16
 4808: lsr x18, x1, #16
 4812: add w1, w18, w0
 4816: cmp w1, #0x40, lsl #12
 4820: b.gt +4004
 4824: smull x16, w16, w17
 4828: add w17, w13, w0
 4832: sub w17, w17, w18
 4836: smull x18, w17, w17
 4840: add x16, x11, x16, lsr #15
 4844: smull x0, w16, w16
 4848: lsr x18, x18, #16
 4852: lsr x0, x0, #16
 4856: add w1, w0, w18
 4860: cmp w1, #0x40, lsl #12
 4864: b.gt +4944
 4868: smull x16, w16, w17
 4872: add w17, w13, w18
 4876: sub w0, w17, w0
 4880: add x18, x11, x16, lsr #15
 4884: smull x16, w0, w0
 4888: smull x1, w18, w18
 4892: lsr x17, x16, #16
 4896: lsr x16, x1, #16
 4900: add w1, w16, w17
 4904: cmp w1, #0x40, lsl #12
 4908: b.gt +4952
 4912: smull x18, w18, w0
 4916: add w14, w14, #0x4
 4920: add w17, w13, w17
 4924: cmp w14, #0x28
 4928: sub w17, w17, w16
 4932: add x18, x11, x18, lsr #15
 4936: b.ne +4752
 4940: b +4008
 4944: add w14, w14, #0x2
 4948: b +4008
 4952: add w14, w14, #0x3
 4956: b +4008
 4960: mov w10, wzr
 4964: b +4980
 4968: add w10, w10, #0x1
 4972: cmp w10, #0x60
 4976: b.eq +5948
 4980: add w11, w8, w10, lsl #11
 4984: mov w12, wzr
 4988: b +5012
 4992: add w14, w14, #0x1
 4996: add w12, w12, #0x4
 5000: add w0, w14, w15
 5004: cmp w12, #0x60
 5008: b.eq +4968
 5012: lsl w13, w12, #11
 5016: mov w14, wzr
 5020: mov w16, wzr
 5024: mov w15, wzr
 5028: sub w13, w13, #0x20, lsl #12
 5032: smull x17, w15, w15
 5036: smull x1, w16, w16
 5040: lsr x18, x17, #16
 5044: lsr x17, x1, #16
 5048: add w1, w17, w18
 5052: cmp w1, #0x40, lsl #12
 5056: b.gt +5248
 5060: smull x15, w16, w15
 5064: add w16, w13, w18
 5068: sub w16, w16, w17
 5072: smull x17, w16, w16
 5076: add x15, x11, x15, lsr #15
 5080: smull x1, w15, w15
 5084: lsr x18, x17, #16
 5088: lsr x17, x1, #16
 5092: add w1, w17, w18
 5096: cmp w1, #0x40, lsl #12
 5100: b.gt +5228
 5104: smull x15, w15, w16
 5108: add w16, w13, w18
 5112: sub w16, w16, w17
 5116: smull x17, w16, w16
 5120: add x15, x11, x15, lsr #15
 5124: smull x18, w15, w15
 5128: lsr x17, x17, #16
 5132: lsr x18, x18, #16
 5136: add w1, w18, w17
 5140: cmp w1, #0x40, lsl #12
 5144: b.gt +5236
 5148: smull x15, w15, w16
 5152: add w16, w13, w17
 5156: sub w18, w16, w18
 5160: add x17, x11, x15, lsr #15
 5164: smull x15, w18, w18
 5168: smull x1, w17, w17
 5172: lsr x16, x15, #16
 5176: lsr x15, x1, #16
 5180: add w1, w15, w16
 5184: cmp w1, #0x40, lsl #12
 5188: b.gt +5244
 5192: smull x17, w17, w18
 5196: add w14, w14, #0x4
 5200: add w16, w13, w16
 5204: cmp w14, #0x28
 5208: sub w15, w16, w15
 5212: add x17, x11, x17, lsr #15
 5216: mov w16, w17
 5220: b.ne +5032
 5224: b +5248
 5228: add w14, w14, #0x1
 5232: b +5248
 5236: add w14, w14, #0x2
 5240: b +5248
 5244: add w14, w14, #0x3
 5248: add w13, w9, w12, lsl #11
 5252: mov w15, wzr
 5256: mov w17, wzr
 5260: mov w16, wzr
 5264: add w14, w14, w0
 5268: smull x18, w16, w16
 5272: smull x1, w17, w17
 5276: lsr x0, x18, #16
 5280: lsr x18, x1, #16
 5284: add w1, w18, w0
 5288: cmp w1, #0x40, lsl #12
 5292: b.gt +5484
 5296: smull x16, w17, w16
 5300: add w17, w13, w0
 5304: sub w17, w17, w18
 5308: smull x18, w17, w17
 5312: add x16, x11, x16, lsr #15
 5316: smull x1, w16, w16
 5320: lsr x0, x18, #16
 5324: lsr x18, x1, #16
 5328: add w1, w18, w0
 5332: cmp w1, #0x40, lsl #12
 5336: b.gt +5464
 5340: smull x16, w16, w17
 5344: add w17, w13, w0
 5348: sub w17, w17, w18
 5352: smull x18, w17, w17
 5356: add x16, x11, x16, lsr #15
 5360: smull x0, w16, w16
 5364: lsr x18, x18, #16
 5368: lsr x0, x0, #16
 5372: add w1, w0, w18
 5376: cmp w1, #0x40, lsl #12
 5380: b.gt +5472
 5384: smull x16, w16, w17
 5388: add w17, w13, w18
 5392: sub w0, w17, w0
 5396: add x18, x11, x16, lsr #15
 5400: smull x16, w0, w0
 5404: smull x1, w18, w18
 5408: lsr x17, x16, #16
 5412: lsr x16, x1, #16
 5416: add w1, w16, w17
 5420: cmp w1, #0x40, lsl #12
 5424: b.gt +5480
 5428: smull x18, w18, w0
 5432: add w15, w15, #0x4
 5436: add w17, w13, w17
 5440: cmp w15, #0x28
 5444: sub w16, w17, w16
 5448: add x18, x11, x18, lsr #15
 5452: mov w17, w18
 5456: b.ne +5268
 5460: b +5484
 5464: add w15, w15, #0x1
 5468: b +5484
 5472: add w15, w15, #0x2
 5476: b +5484
 5480: add w15, w15, #0x3
 5484: mov w16, wzr
 5488: mov w18, wzr
 5492: mov w17, wzr
 5496: add w15, w15, w14
 5500: add w14, w13, #0x800
 5504: smull x0, w17, w17
 5508: smull x2, w18, w18
 5512: lsr x1, x0, #16
 5516: lsr x0, x2, #16
 5520: add w2, w0, w1
 5524: cmp w2, #0x40, lsl #12
 5528: b.gt +5720
 5532: smull x17, w18, w17
 5536: add w18, w14, w1
 5540: sub w18, w18, w0
 5544: smull x0, w18, w18
 5548: add x17, x11, x17, lsr #15
 5552: smull x2, w17, w17
 5556: lsr x1, x0, #16
 5560: lsr x0, x2, #16
 5564: add w2, w0, w1
 5568: cmp w2, #0x40, lsl #12
 5572: b.gt +5700
 5576: smull x17, w17, w18
 5580: add w18, w14, w1
 5584: sub w18, w18, w0
 5588: smull x0, w18, w18
 5592: add x17, x11, x17, lsr #15
 5596: smull x1, w17, w17
 5600: lsr x0, x0, #16
 5604: lsr x1, x1, #16
 5608: add w2, w1, w0
 5612: cmp w2, #0x40, lsl #12
 5616: b.gt +5708
 5620: smull x17, w17, w18
 5624: add w18, w14, w0
 5628: sub w1, w18, w1
 5632: add x0, x11, x17, lsr #15
 5636: smull x17, w1, w1
 5640: smull x2, w0, w0
 5644: lsr x18, x17, #16
 5648: lsr x17, x2, #16
 5652: add w2, w17, w18
 5656: cmp w2, #0x40, lsl #12
 5660: b.gt +5716
 5664: smull x0, w0, w1
 5668: add w16, w16, #0x4
 5672: add w18, w14, w18
 5676: cmp w16, #0x28
 5680: sub w17, w18, w17
 5684: add x0, x11, x0, lsr #15
 5688: mov w18, w0
 5692: b.ne +5504
 5696: b +5720
 5700: add w16, w16, #0x1
 5704: b +5720
 5708: add w16, w16, #0x2
 5712: b +5720
 5716: add w16, w16, #0x3
 5720: mov w14, wzr
 5724: mov w18, wzr
 5728: mov w17, wzr
 5732: add w15, w16, w15
 5736: add w13, w13, #0x1, lsl #12
 5740: smull x16, w17, w17
 5744: smull x0, w18, w18
 5748: lsr x16, x16, #16
 5752: lsr x0, x0, #16
 5756: add w1, w0, w16
 5760: cmp w1, #0x40, lsl #12
 5764: b.gt +4996
 5768: smull x17, w18, w17
 5772: add w18, w13, w16
 5776: add x16, x11, x17, lsr #15
 5780: sub w17, w18, w0
 5784: smull x18, w17, w17
 5788: smull x1, w16, w16
 5792: lsr x0, x18, #16
 5796: lsr x18, x1, #16
 5800: add w1, w18, w0
 5804: cmp w1, #0x40, lsl #12
 5808: b.gt +4992
 5812: smull x16, w16, w17
 5816: add w17, w13, w0
 5820: sub w17, w17, w18
 5824: smull x18, w17, w17
 5828: add x16, x11, x16, lsr #15
 5832: smull x0, w16, w16
 5836: lsr x18, x18, #16
 5840: lsr x0, x0, #16
 5844: add w1, w0, w18
 5848: cmp w1, #0x40, lsl #12
 5852: b.gt +5932
 5856: smull x16, w16, w17
 5860: add w17, w13, w18
 5864: sub w0, w17, w0
 5868: add x18, x11, x16, lsr #15
 5872: smull x16, w0, w0
 5876: smull x1, w18, w18
 5880: lsr x17, x16, #16
 5884: lsr x16, x1, #16
 5888: add w1, w16, w17
 5892: cmp w1, #0x40, lsl #12
 5896: b.gt +5940
 5900: smull x18, w18, w0
 5904: add w14, w14, #0x4
 5908: add w17, w13, w17
 5912: cmp w14, #0x28
 5916: sub w17, w17, w16
 5920: add x18, x11, x18, lsr #15
 5924: b.ne +5740
 5928: b +4996
 5932: add w14, w14, #0x2
 5936: b +4996
 5940: add w14, w14, #0x3
 5944: b +4996
 5948: ret
```

#### `bench_bytecode_interpreter__U32` (103 instructions, 412 bytes)
```asm
    0: mov w8, #0x1a80
    4: mov w9, #0x1
    8: mov w10, #0x2
   12: movk w8, #0x6, lsl #16
   16: mul w8, w0, w8
   20: stp w9, w10, [sp, #-0x10]!
   24: mov w9, #0x3
   28: mov w10, #0x4
   32: stp w9, w10, [sp, #0x8]
   36: tbnz w8, #0x1f, +408
   40: cbz w8, +392
   44: mov w12, #0x1
   48: mov w13, #0x10
   52: mov w9, wzr
   56: adrp x10, <harness_main+0x1da8>
   60: add x10, x10, #0x890
   64: mov w11, #0x1
   68: movk w12, #0x100, lsl #16
   72: movk w13, #0x1000, lsl #16
   76: mov x14, sp
   80: b +112
   84: ldr w16, [x14, x16, lsl #2]
   88: lsl w16, w16, #1
   92: cmp w9, #0x7
   96: str w16, [x14, x15, lsl #2]
  100: csinc w9, wzr, w9, eq
  104: subs w8, w8, #0x1
  108: b.eq +364
  112: lsl w18, w9, #2
  116: add x17, x10, w18, sxtw #2
  120: lsr x0, x12, x18
  124: ldp w15, w16, [x17, #0x4]
  128: ldr w17, [x17, #0xc]
  132: tbz w0, #0x0, +176
  136: cmp w16, #0x4
  140: b.hs +404
  144: cmp w17, #0x4
  148: b.hs +404
  152: cmp w15, #0x4
  156: b.hs +404
  160: ldr w16, [x14, x16, lsl #2]
  164: ldr w17, [x14, x17, lsl #2]
  168: add w16, w17, w16
  172: b +92
  176: lsl x0, x11, x18
  180: tst x0, x13
  184: b.eq +228
  188: cmp w16, #0x4
  192: b.hs +404
  196: cmp w17, #0x4
  200: b.hs +404
  204: cmp w15, #0x4
  208: b.hs +404
  212: ldr w16, [x14, x16, lsl #2]
  216: ldr w17, [x14, x17, lsl #2]
  220: eor w16, w17, w16
  224: b +92
  228: cmp w18, #0x8
  232: b.eq +300
  236: cmp w18, #0xc
  240: b.eq +280
  244: cmp w18, #0x10
  248: b.ne +340
  252: cmp w16, #0x4
  256: b.hs +404
  260: cmp w15, #0x4
  264: b.hs +404
  268: ldr w16, [x14, x16, lsl #2]
  272: add w16, w16, w17
  276: b +92
  280: cmp w16, #0x3
  284: b.hi +404
  288: cmp w15, #0x4
  292: b.lo +84
  296: b +404
  300: cmp w16, #0x3
  304: b.hi +404
  308: cmp w17, #0x4
  312: b.hs +404
  316: cmp w15, #0x4
  320: b.hs +404
  324: ldr w16, [x14, x16, lsl #2]
  328: ldr w17, [x14, x17, lsl #2]
  332: mul w16, w17, w16
  336: b +92
  340: cmp w16, #0x4
  344: b.hs +404
  348: cmp w15, #0x4
  352: b.hs +404
  356: ldr w16, [x14, x16, lsl #2]
  360: b +92
  364: ldp w8, w9, [sp]
  368: ldp w10, w11, [sp, #0x8]
  372: eor w8, w9, w8
  376: eor w9, w10, w11
  380: eor w0, w8, w9
  384: add sp, sp, #0x10
  388: ret
  392: mov w0, #0x4
  396: add sp, sp, #0x10
  400: ret
  404: bl <array_index_fail>
  408: bl <prismio_panic>
```

#### `bench_pointer_chase__U32` (150 instructions, 600 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x4, lsl #12
   12: mov w19, w0
   16: add x0, sp, #0x2, lsl #12
   20: mov w1, wzr
   24: mov w2, #0x2000
   28: add x20, sp, #0x2, lsl #12
   32: bl <memset>
   36: mov x0, sp
   40: mov w1, wzr
   44: mov w2, #0x2000
   48: bl <memset>
   52: mov x8, xzr
   56: add x9, x20, #0x20
   60: mov w10, #0xf
   64: sub w11, w10, #0xf
   68: sub w12, w10, #0xe
   72: sub w13, w10, #0x1
   76: stp w11, w12, [x9, #-0x20]
   80: sub w11, w10, #0xd
   84: sub w12, w10, #0xc
   88: stp w11, w12, [x9, #-0x18]
   92: orr w11, w8, #0x4
   96: sub w12, w10, #0xa
  100: stp w11, w12, [x9, #-0x10]
  104: sub w11, w10, #0x9
  108: sub w12, w10, #0x8
  112: stp w11, w12, [x9, #-0x8]
  116: orr w11, w8, #0x8
  120: sub w12, w10, #0x6
  124: stp w11, w12, [x9]
  128: sub w11, w10, #0x5
  132: sub w12, w10, #0x4
  136: stp w11, w12, [x9, #0x8]
  140: orr w11, w8, #0xc
  144: sub w12, w10, #0x2
  148: add x8, x8, #0x10
  152: stp w11, w12, [x9, #0x10]
  156: stp w13, w10, [x9, #0x18]
  160: cmp x8, #0x800
  164: add w10, w10, #0x10
  168: add x9, x9, #0x40
  172: b.ne +64
  176: mov w8, #0xf35f
  180: mov w9, #0x660d
  184: mov w13, #0x2329
  188: movk w8, #0x3c6e, lsl #16
  192: movk w9, #0x19, lsl #16
  196: mov w10, #0x7ff
  200: mov w11, #0x1ffc
  204: add x12, sp, #0x2, lsl #12
  208: madd w13, w13, w9, w8
  212: add w15, w10, #0x1
  216: sub w1, w10, #0x1
  220: cmp x10, #0x3
  224: lsr w14, w13, #8
  228: madd w13, w13, w9, w8
  232: udiv w16, w14, w15
  236: lsr w17, w13, #8
  240: madd w13, w13, w9, w8
  244: lsr w0, w13, #8
  248: udiv w18, w17, w10
  252: msub w15, w16, w15, w14
  256: add x14, x12, x11
  260: ldr w2, [x12, w15, uxtw #2]
  264: udiv w16, w0, w1
  268: msub w17, w18, w10, w17
  272: ldr w18, [x14]
  276: str w2, [x14]
  280: str w18, [x12, w15, uxtw #2]
  284: ldr w15, [x12, w17, uxtw #2]
  288: ldur w18, [x14, #-0x4]
  292: stur w15, [x14, #-0x4]
  296: str w18, [x12, w17, uxtw #2]
  300: ldur w17, [x14, #-0x8]
  304: msub w16, w16, w1, w0
  308: ldr w15, [x12, w16, uxtw #2]
  312: stur w15, [x14, #-0x8]
  316: str w17, [x12, w16, uxtw #2]
  320: b.eq +372
  324: madd w13, w13, w9, w8
  328: sub w16, w10, #0x2
  332: sub x10, x10, #0x4
  336: sub x11, x11, #0x10
  340: lsr w15, w13, #8
  344: udiv w17, w15, w16
  348: msub w15, w17, w16, w15
  352: ldur w17, [x14, #-0xc]
  356: ldr w16, [x12, w15, uxtw #2]
  360: stur w16, [x14, #-0xc]
  364: str w17, [x12, w15, uxtw #2]
  368: b +208
  372: ldr w8, [x20]
  376: add x9, sp, #0x2, lsl #12
  380: mov w10, #0x7f0
  384: add x9, x9, #0x20
  388: mov x11, sp
  392: mov w12, w8
  396: ldpsw x13, x14, [x9, #-0x1c]
  400: str w13, [x11, w12, sxtw #2]
  404: str w14, [x11, x13, lsl #2]
  408: ldpsw x12, x13, [x9, #-0x14]
  412: str w12, [x11, x14, lsl #2]
  416: str w13, [x11, x12, lsl #2]
  420: ldpsw x12, x14, [x9, #-0xc]
  424: str w12, [x11, x13, lsl #2]
  428: ldursw x13, [x9, #-0x4]
  432: str w14, [x11, x12, lsl #2]
  436: str w13, [x11, x14, lsl #2]
  440: ldpsw x12, x14, [x9]
  444: str w12, [x11, x13, lsl #2]
  448: ldpsw x13, x15, [x9, #0x8]
  452: str w14, [x11, x12, lsl #2]
  456: ldrsw x12, [x9, #0x10]
  460: str w13, [x11, x14, lsl #2]
  464: str w15, [x11, x13, lsl #2]
  468: str w12, [x11, x15, lsl #2]
  472: cbz x10, +516
  476: ldpsw x13, x14, [x9, #0x14]
  480: sub x10, x10, #0x10
  484: str w13, [x11, x12, lsl #2]
  488: str w14, [x11, x13, lsl #2]
  492: ldp w13, w12, [x9, #0x1c]
  496: add x9, x9, #0x40
  500: sxtw x13, w13
  504: str w13, [x11, x14, lsl #2]
  508: str w12, [x11, x13, lsl #2]
  512: b +396
  516: mov w10, #0x9f00
  520: ldrsw x11, [x20, #0x1ff4]
  524: mov x9, sp
  528: movk w10, #0x24, lsl #16
  532: str w11, [x9, x12, lsl #2]
  536: ldrsw x12, [x20, #0x1ff8]
  540: mul w10, w19, w10
  544: str w12, [x9, x11, lsl #2]
  548: ldrsw x11, [x20, #0x1ffc]
  552: mov w0, wzr
  556: str w11, [x9, x12, lsl #2]
  560: str w8, [x9, x11, lsl #2]
  564: cbz w10, +584
  568: ldr w8, [x9, w8, sxtw #2]
  572: subs w10, w10, #0x1
  576: add w0, w8, w0
  580: b.ne +568
  584: add sp, sp, #0x4, lsl #12
  588: ldp x20, x19, [sp, #0x10]
  592: ldp x29, x30, [sp], #0x20
  596: ret
```

#### `bench_ring_buffer__U32` (51 instructions, 204 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x1, lsl #12
   12: mov w19, w0
   16: mov x0, sp
   20: mov w1, wzr
   24: mov w2, #0x1000
   28: mov x20, sp
   32: bl <memset>
   36: mov w8, #0x93e0
   40: movk w8, #0x4, lsl #16
   44: mul w8, w19, w8
   48: cbz w8, +184
   52: mov w14, #0x660d
   56: mov w15, #0xf35f
   60: mov w10, wzr
   64: mov w9, wzr
   68: mov w11, wzr
   72: mov w12, wzr
   76: mov w13, #0x141
   80: movk w14, #0x19, lsl #16
   84: movk w15, #0x3c6e, lsl #16
   88: b +100
   92: subs w8, w8, #0x1
   96: b.eq +164
  100: madd w13, w13, w14, w15
  104: sub w16, w10, w12
  108: cmp w16, #0x400
  112: b.hs +128
  116: and w16, w10, #0x3ff
  120: add w10, w10, #0x1
  124: str w13, [x20, w16, uxtw #2]
  128: tbnz w13, #0x8, +92
  132: cmp w10, w12
  136: b.eq +92
  140: and w16, w12, #0x3ff
  144: add w12, w12, #0x1
  148: add w9, w9, #0x1
  152: ldr w16, [x20, w16, uxtw #2]
  156: add w11, w16, w11
  160: b +92
  164: eor w0, w9, w11
  168: add sp, sp, #0x1, lsl #12
  172: ldp x20, x19, [sp, #0x10]
  176: ldp x29, x30, [sp], #0x20
  180: ret
  184: mov w0, wzr
  188: add sp, sp, #0x1, lsl #12
  192: ldp x20, x19, [sp, #0x10]
  196: ldp x29, x30, [sp], #0x20
  200: ret
```

#### `bench_mem_copy__U32` (269 instructions, 1076 bytes)
```asm
    0: stp x29, x30, [sp, #-0x60]!
    4: stp x22, x21, [sp, #0x40]
    8: mov x13, #0xe0a8
   12: mov x14, #0xc150
   16: stp x20, x19, [sp, #0x50]
   20: mov x15, #0xa1f8
   24: mov x17, #0x82a0
   28: mov x18, #0x6348
   32: mov x1, #0x43f0
   36: mov x2, #0x2498
   40: mov x3, #0x540
   44: mov x4, #0xe5e8
   48: mov x5, #0xc690
   52: mov x6, #0xa738
   56: mov x7, #0x87e0
   60: mov x19, #0x6888
   64: mov x20, #0x4930
   68: mov x21, #0x29d8
   72: mov x22, #0xa80
   76: mov w8, #0x8
   80: movk x13, #0xfa53, lsl #16
   84: movk x14, #0xf4a7, lsl #16
   88: movk x15, #0xeefb, lsl #16
   92: movk x17, #0xe94f, lsl #16
   96: movk x18, #0xe3a3, lsl #16
  100: movk x1, #0xddf7, lsl #16
  104: movk x2, #0xd84b, lsl #16
  108: movk x3, #0xd29f, lsl #16
  112: movk x4, #0xccf2, lsl #16
  116: movk x5, #0xc746, lsl #16
  120: movk x6, #0xc19a, lsl #16
  124: movk x7, #0xbbee, lsl #16
  128: movk x19, #0xb642, lsl #16
  132: movk x20, #0xb096, lsl #16
  136: movk x21, #0xaaea, lsl #16
  140: movk x22, #0xa53e, lsl #16
  144: movk w8, #0x4400, lsl #16
  148: movk x13, #0xcdcb, lsl #32
  152: movk x14, #0x9b97, lsl #32
  156: movk x15, #0x6963, lsl #32
  160: movk x17, #0x372f, lsl #32
  164: movk x18, #0x4fb, lsl #32
  168: movk x1, #0xd2c7, lsl #32
  172: movk x2, #0xa093, lsl #32
  176: movk x3, #0x6e5f, lsl #32
  180: movk x4, #0x3c2b, lsl #32
  184: movk x5, #0x9f7, lsl #32
  188: movk x6, #0xd7c3, lsl #32
  192: movk x7, #0xa58f, lsl #32
  196: movk x19, #0x735b, lsl #32
  200: movk x20, #0x4127, lsl #32
  204: movk x21, #0xef3, lsl #32
  208: movk x22, #0xdcbf, lsl #32
  212: mov x9, xzr
  216: mov x10, xzr
  220: mov w11, #0x60
  224: add x12, x8, #0x58
  228: movk x13, #0xf1bb, lsl #48
  232: movk x14, #0xe377, lsl #48
  236: movk x15, #0xd533, lsl #48
  240: mov w16, #0x5555
  244: movk x17, #0xc6ef, lsl #48
  248: movk x18, #0xb8ab, lsl #48
  252: movk x1, #0xaa66, lsl #48
  256: movk x2, #0x9c22, lsl #48
  260: movk x3, #0x8dde, lsl #48
  264: movk x4, #0x7f9a, lsl #48
  268: movk x5, #0x7156, lsl #48
  272: movk x6, #0x6311, lsl #48
  276: movk x7, #0x54cd, lsl #48
  280: movk x19, #0x4689, lsl #48
  284: movk x20, #0x3845, lsl #48
  288: movk x21, #0x2a01, lsl #48
  292: movk x22, #0x1bbc, lsl #48
  296: stp x28, x27, [sp, #0x10]
  300: stp x26, x25, [sp, #0x20]
  304: stp x24, x23, [sp, #0x30]
  308: add x24, x8, #0x8
  312: add x26, x10, x13
  316: eor x27, x10, x16
  320: add x29, x10, x14
  324: orr x25, x9, x8
  328: add x23, x8, #0x10
  332: orr x28, x9, x24
  336: eor x26, x26, x16
  340: stur x27, [x12, #-0x60]
  344: add x27, x10, x15
  348: eor x29, x29, x16
  352: str x26, [x25]
  356: orr x25, x9, x23
  360: eor x26, x27, x16
  364: str x29, [x28]
  368: add x28, x10, x17
  372: str x26, [x25]
  376: add x25, x9, #0x20
  380: add x29, x10, x18
  384: eor x28, x28, x16
  388: orr x26, x25, x8
  392: add x30, x10, x1
  396: eor x29, x29, x16
  400: stur x28, [x12, #-0x40]
  404: add x28, x10, x2
  408: orr x27, x25, x24
  412: orr x25, x25, x23
  416: eor x30, x30, x16
  420: str x29, [x26]
  424: eor x26, x28, x16
  428: str x30, [x27]
  432: add x27, x9, #0x40
  436: add x29, x10, x4
  440: str x26, [x25]
  444: add x26, x10, x3
  448: orr x25, x27, x8
  452: eor x26, x26, x16
  456: add x30, x10, x5
  460: eor x29, x29, x16
  464: stur x26, [x12, #-0x20]
  468: add x26, x10, x6
  472: orr x28, x27, x24
  476: eor x30, x30, x16
  480: str x29, [x25]
  484: orr x25, x27, x23
  488: eor x26, x26, x16
  492: str x30, [x28]
  496: add x27, x10, x19
  500: str x26, [x25]
  504: add x26, x10, x7
  508: orr x25, x11, x8
  512: eor x26, x26, x16
  516: add x28, x10, x20
  520: eor x27, x27, x16
  524: str x26, [x12], #0x80
  528: add x26, x10, x21
  532: add x9, x9, #0x80
  536: orr x24, x11, x24
  540: orr x23, x11, x23
  544: eor x28, x28, x16
  548: str x27, [x25]
  552: eor x25, x26, x16
  556: cmp x9, #0x8, lsl #12
  560: add x11, x11, #0x80
  564: add x10, x10, x22
  568: str x28, [x24]
  572: str x25, [x23]
  576: b.ne +308
  580: add w9, w0, w0, lsl #3
  584: lsl w10, w9, #5
  588: mov w9, #0x8
  592: movk w9, #0x4500, lsl #16
  596: cbz w10, +748
  600: mov x11, xzr
  604: mov w12, #0x44000000
  608: mov w13, #0x45000000
  612: mov x14, xzr
  616: add x11, x11, #0x1
  620: ldr x15, [x14, x12]
  624: orr x17, x14, x9
  628: lsr x18, x14, #5
  632: str x15, [x14, x13]
  636: add x15, x11, x15
  640: str x15, [x14, x12]
  644: cmp x18, #0x3ff
  648: orr x15, x14, x8
  652: ldr x16, [x15]
  656: str x16, [x17]
  660: add x16, x11, x16
  664: add x17, x8, #0x8
  668: str x16, [x15]
  672: orr x15, x14, x17
  676: add x17, x9, #0x8
  680: ldr x16, [x15]
  684: orr x17, x14, x17
  688: str x16, [x17]
  692: add x16, x11, x16
  696: add x17, x8, #0x10
  700: str x16, [x15]
  704: orr x15, x14, x17
  708: add x17, x9, #0x10
  712: ldr x16, [x15]
  716: orr x17, x14, x17
  720: add x14, x14, #0x20
  724: str x16, [x17]
  728: add x16, x11, x16
  732: str x16, [x15]
  736: b.lo +620
  740: cmp x11, x10
  744: b.ne +612
  748: mov x8, xzr
  752: mov x11, xzr
  756: mov x12, xzr
  760: mov x13, xzr
  764: mov x14, xzr
  768: mov w10, #0x45000000
  772: orr x15, x8, x9
  776: add x16, x9, #0x8
  780: add x17, x9, #0x10
  784: orr x16, x8, x16
  788: ldr x15, [x15]
  792: add x0, x9, #0x18
  796: ldr x16, [x16]
  800: ldr x18, [x8, x10]
  804: orr x17, x8, x17
  808: add x1, x9, #0x20
  812: add x12, x15, x12
  816: orr x15, x8, x0
  820: ldr x17, [x17]
  824: add x13, x16, x13
  828: orr x16, x8, x1
  832: ldr x15, [x15]
  836: add x11, x18, x11
  840: ldr x16, [x16]
  844: add x14, x17, x14
  848: add x17, x9, #0x28
  852: add x18, x9, #0x30
  856: add x11, x15, x11
  860: add x15, x9, #0x48
  864: orr x17, x8, x17
  868: add x12, x16, x12
  872: orr x15, x8, x15
  876: add x16, x9, #0x50
  880: orr x18, x8, x18
  884: ldr x17, [x17]
  888: orr x16, x8, x16
  892: ldr x15, [x15]
  896: ldr x18, [x18]
  900: ldr x16, [x16]
  904: add x0, x9, #0x38
  908: add x1, x9, #0x40
  912: add x15, x15, x17
  916: orr x0, x8, x0
  920: orr x1, x8, x1
  924: add x13, x15, x13
  928: add x15, x16, x18
  932: add x16, x9, #0x60
  936: add x14, x15, x14
  940: add x15, x9, #0x58
  944: ldr x0, [x0]
  948: orr x15, x8, x15
  952: ldr x17, [x1]
  956: orr x16, x8, x16
  960: add x18, x9, #0x68
  964: add x1, x9, #0x70
  968: ldr x15, [x15]
  972: orr x18, x8, x18
  976: orr x1, x8, x1
  980: ldr x16, [x16]
  984: ldr x18, [x18]
  988: ldr x1, [x1]
  992: add x15, x15, x0
  996: add x8, x8, #0x80
 1000: add x11, x15, x11
 1004: add x15, x16, x17
 1008: cmp x8, #0x8, lsl #12
 1012: add x12, x15, x12
 1016: add x13, x18, x13
 1020: add x14, x1, x14
 1024: b.ne +772
 1028: add x8, x12, x11
 1032: ldp x20, x19, [sp, #0x50]
 1036: add x8, x13, x8
 1040: ldp x22, x21, [sp, #0x40]
 1044: add x8, x14, x8
 1048: ldp x24, x23, [sp, #0x30]
 1052: lsr x9, x8, #32
 1056: ldp x26, x25, [sp, #0x20]
 1060: ldp x28, x27, [sp, #0x10]
 1064: eor w0, w9, w8
 1068: ldp x29, x30, [sp], #0x60
 1072: ret
```

#### `bench_atomic_counter__U32` (34 instructions, 136 bytes)
```asm
    0: mov w8, #0xa120
    4: mov w9, #0x44100000
    8: movk w8, #0x7, lsl #16
   12: str wzr, [x9]
   16: mul w8, w0, w8
   20: tbnz w8, #0x1f, +76
   24: cbz w8, +124
   28: mov w9, wzr
   32: mov w10, #0x44100000
   36: and w11, w9, #0x3
   40: add w11, w11, #0x1
   44: ldaxr w12, [x10]
   48: add w12, w12, w11
   52: stlxr w13, w12, [x10]
   56: cbnz w13, +44
   60: add w9, w9, #0x1
   64: cmp w9, w8
   68: b.ne +36
   72: b +124
   76: mov w9, wzr
   80: mov w10, #0x44100000
   84: and w11, w9, #0x3
   88: add w11, w11, #0x1
   92: ldaxr w12, [x10]
   96: add w12, w12, w11
  100: stlxr w13, w12, [x10]
  104: cbnz w13, +92
  108: sub w11, w9, w8
  112: sub w9, w9, #0x1
  116: cmp w11, #0x1
  120: b.hi +84
  124: mov w8, #0x44100000
  128: ldar w0, [x8]
  132: ret
```

#### `bench_spinlock__U32` (28 instructions, 112 bytes)
```asm
    0: mov w8, #0x3500
    4: movk w8, #0xc, lsl #16
    8: mul w9, w0, w8
   12: mov w8, #0x10
   16: movk w8, #0x4410, lsl #16
   20: str wzr, [x8]
   24: str wzr, [x8, #0x10]
   28: cbz w9, +104
   32: mov w10, wzr
   36: mov w11, #0x1
   40: ldaxr w12, [x8]
   44: cbnz w12, +88
   48: stlxr w12, w11, [x8]
   52: cbnz w12, +40
   56: ldr w12, [x8, #0x10]
   60: add w10, w10, #0x1
   64: cmp w10, w9
   68: add w12, w12, #0x1
   72: str w12, [x8, #0x10]
   76: stlr wzr, [x8]
   80: b.ne +40
   84: b +96
   88: clrex
   92: b +40
   96: ldr w0, [x8, #0x10]
  100: ret
  104: mov w0, wzr
  108: ret
```

#### `bench_volatile_registers__U32` (102 instructions, 408 bytes)
```asm
    0: mov w9, #0x44200000
    4: mov w8, #0xc
    8: str wzr, [x9]
   12: mov w9, #0xbba0
   16: movk w8, #0x4420, lsl #16
   20: movk w9, #0xd, lsl #16
   24: stur wzr, [x8, #-0x8]
   28: mul w10, w0, w9
   32: stur wzr, [x8, #-0x4]
   36: str wzr, [x8]
   40: str wzr, [x8, #0x4]
   44: str wzr, [x8, #0x8]
   48: str wzr, [x8, #0xc]
   52: str wzr, [x8, #0x10]
   56: str wzr, [x8, #0x14]
   60: str wzr, [x8, #0x18]
   64: str wzr, [x8, #0x1c]
   68: str wzr, [x8, #0x20]
   72: str wzr, [x8, #0x24]
   76: str wzr, [x8, #0x28]
   80: str wzr, [x8, #0x2c]
   84: str wzr, [x8, #0x30]
   88: str wzr, [x8, #0x34]
   92: str wzr, [x8, #0x38]
   96: str wzr, [x8, #0x3c]
  100: str wzr, [x8, #0x40]
  104: str wzr, [x8, #0x44]
  108: str wzr, [x8, #0x48]
  112: str wzr, [x8, #0x4c]
  116: str wzr, [x8, #0x50]
  120: str wzr, [x8, #0x54]
  124: str wzr, [x8, #0x58]
  128: str wzr, [x8, #0x5c]
  132: str wzr, [x8, #0x60]
  136: str wzr, [x8, #0x64]
  140: str wzr, [x8, #0x68]
  144: str wzr, [x8, #0x6c]
  148: str wzr, [x8, #0x70]
  152: str wzr, [x8, #0x74]
  156: str wzr, [x8, #0x78]
  160: str wzr, [x8, #0x7c]
  164: str wzr, [x8, #0x80]
  168: str wzr, [x8, #0x84]
  172: str wzr, [x8, #0x88]
  176: str wzr, [x8, #0x8c]
  180: str wzr, [x8, #0x90]
  184: str wzr, [x8, #0x94]
  188: str wzr, [x8, #0x98]
  192: str wzr, [x8, #0x9c]
  196: str wzr, [x8, #0xa0]
  200: str wzr, [x8, #0xa4]
  204: str wzr, [x8, #0xa8]
  208: str wzr, [x8, #0xac]
  212: str wzr, [x8, #0xb0]
  216: str wzr, [x8, #0xb4]
  220: str wzr, [x8, #0xb8]
  224: str wzr, [x8, #0xbc]
  228: str wzr, [x8, #0xc0]
  232: str wzr, [x8, #0xc4]
  236: str wzr, [x8, #0xc8]
  240: str wzr, [x8, #0xcc]
  244: str wzr, [x8, #0xd0]
  248: str wzr, [x8, #0xd4]
  252: str wzr, [x8, #0xd8]
  256: str wzr, [x8, #0xdc]
  260: str wzr, [x8, #0xe0]
  264: str wzr, [x8, #0xe4]
  268: str wzr, [x8, #0xe8]
  272: str wzr, [x8, #0xec]
  276: str wzr, [x8, #0xf0]
  280: cbz w10, +344
  284: mov w11, wzr
  288: mov w9, wzr
  292: mov w12, wzr
  296: mov w13, #0x44200000
  300: and w14, w11, #0xfc
  304: add w11, w11, #0x1c
  308: orr x14, x14, x13
  312: ldr w15, [x14]
  316: add w16, w12, w15
  320: add w12, w12, #0x1
  324: add w9, w15, w9
  328: cmp w10, w12
  332: str w16, [x14]
  336: b.ne +300
  340: b +348
  344: mov w9, wzr
  348: mov w11, wzr
  352: mov w10, #0x40
  356: ldur w12, [x8, #-0xc]
  360: ldur w13, [x8, #-0x8]
  364: subs x10, x10, #0x4
  368: ldur w14, [x8, #-0x4]
  372: ldr w15, [x8]
  376: add x8, x8, #0x10
  380: add w11, w12, w11
  384: add w12, w14, w13
  388: add w11, w12, w11
  392: add w11, w15, w11
  396: b.ne +356
  400: eor w0, w11, w9
  404: ret
```

#### `main` (2 instructions, 8 bytes)
```asm
    0: mov w0, wzr
    4: ret
```

#### `exit` (105 instructions, 420 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x8, <harness_main+0x1da8>
    8: mov x29, sp
   12: ldr x8, [x8, #0xeb0]
   16: ldrb w9, [x8]
   20: cmp w9, #0x72
   24: b.ne +204
   28: ldrb w9, [x8, #0x1]
   32: cmp w9, #0x75
   36: b.ne +204
   40: ldrb w9, [x8, #0x2]
   44: cmp w9, #0x6e
   48: b.ne +204
   52: ldrb w9, [x8, #0x3]
   56: cmp w9, #0x74
   60: b.ne +204
   64: ldrb w9, [x8, #0x4]
   68: cmp w9, #0x69
   72: b.ne +204
   76: ldrb w9, [x8, #0x5]
   80: cmp w9, #0x6d
   84: b.ne +204
   88: ldrb w9, [x8, #0x6]
   92: cmp w9, #0x65
   96: b.ne +204
  100: ldrb w9, [x8, #0x7]
  104: cmp w9, #0x20
  108: b.ne +204
  112: ldrb w9, [x8, #0x8]
  116: cmp w9, #0x65
  120: b.ne +204
  124: ldrb w9, [x8, #0x9]
  128: cmp w9, #0x72
  132: b.ne +204
  136: ldrb w9, [x8, #0xa]
  140: cmp w9, #0x72
  144: b.ne +204
  148: ldrb w9, [x8, #0xb]
  152: cmp w9, #0x6f
  156: b.ne +204
  160: ldrb w9, [x8, #0xc]
  164: cmp w9, #0x72
  168: b.ne +204
  172: ldrb w9, [x8, #0xd]
  176: cmp w9, #0x3a
  180: b.ne +204
  184: ldrb w9, [x8, #0xe]
  188: cmp w9, #0x20
  192: mov w9, #0xf
  196: csel x10, x9, xzr, eq
  200: b +208
  204: mov x10, xzr
  208: add x8, x10, x8
  212: mov x9, xzr
  216: adrp x10, <harness_main+0x1da8>
  220: add x10, x10, #0xeb9
  224: add x11, x8, #0x1
  228: mov w8, #0x3
  232: ldurb w12, [x11, #-0x1]
  236: cbz w12, +352
  240: cmp w12, #0xa
  244: b.eq +352
  248: sturb w12, [x10, #-0x1]
  252: mov x12, x11
  256: ldrb w13, [x12], #0x4
  260: cbz w13, +360
  264: cmp w13, #0xa
  268: b.eq +360
  272: strb w13, [x10]
  276: ldrb w13, [x11, #0x1]
  280: cbz w13, +368
  284: cmp w13, #0xa
  288: b.eq +368
  292: strb w13, [x10, #0x1]
  296: ldrb w13, [x11, #0x2]
  300: orr x11, x9, #0x3
  304: cbz w13, +380
  308: cmp w13, #0xa
  312: b.eq +380
  316: cmp x8, #0x9f
  320: b.eq +376
  324: add x9, x9, #0x4
  328: strb w13, [x10, #0x2]
  332: add x8, x8, #0x4
  336: add x10, x10, #0x4
  340: mov x11, x12
  344: ldurb w12, [x12, #-0x1]
  348: cbnz w12, +240
  352: sub x11, x8, #0x3
  356: b +380
  360: sub x11, x8, #0x2
  364: b +380
  368: sub x11, x8, #0x1
  372: b +380
  376: mov x11, x8
  380: nop
  384: adr x1, <exit.detail>
  388: adrp x0, <harness_main+0x1da8>
  392: add x0, x0, #0xd47
  396: adrp x2, <harness_main+0x1da8>
  400: add x2, x2, #0xda6
  404: mov w3, wzr
  408: mov w4, wzr
  412: strb wzr, [x1, x11]
  416: bl <prismio_panic_hook>
```

#### `prismio_panic` (9 instructions, 36 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: mov w4, w3
    8: mov w3, w2
   12: mov x2, x1
   16: mov x1, x0
   20: adrp x0, <harness_main+0x1da8>
   24: add x0, x0, #0xe61
   28: mov x29, sp
   32: bl <prismio_panic_hook>
```

#### `array_index_fail` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1da8>
    8: add x0, x0, #0xe9a
   12: adrp x1, <harness_main+0x1da8>
   16: add x1, x1, #0xe94
   20: adrp x2, <harness_main+0x1da8>
   24: add x2, x2, #0xda6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `prismio_panic_hook` (1 instructions, 4 bytes)
```asm
    0: b +0
```

#### `prismio_overflow_trap` (9 instructions, 36 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: mov w3, w2
    8: mov x2, x1
   12: mov x1, x0
   16: nop
   20: adr x0, 0x40087dfb
   24: mov w4, wzr
   28: mov x29, sp
   32: bl <prismio_panic_hook>
```

#### `prismio_step_check` (13 instructions, 52 bytes)
```asm
    0: cmp w0, #0x1
    4: b.lt +12
    8: ret
   12: stp x29, x30, [sp, #-0x10]!
   16: mov w3, w2
   20: mov x2, x1
   24: adrp x0, <harness_main+0x1da8>
   28: add x0, x0, #0xe45
   32: adrp x1, <harness_main+0x1da8>
   36: add x1, x1, #0xda6
   40: mov w4, wzr
   44: mov x29, sp
   48: bl <prismio_panic_hook>
```

#### `prismio_panic` (9 instructions, 36 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: mov w4, w3
    8: mov w3, w2
   12: mov x2, x1
   16: mov x1, x0
   20: adrp x0, <harness_main+0x1da8>
   24: add x0, x0, #0xe61
   28: mov x29, sp
   32: bl <prismio_panic_hook>
```

#### `prismio_unreachable` (9 instructions, 36 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: mov w4, w3
    8: mov w3, w2
   12: mov x2, x1
   16: mov x1, x0
   20: adrp x0, <harness_main+0x1da8>
   24: add x0, x0, #0xd72
   28: mov x29, sp
   32: bl <prismio_panic_hook>
```

#### `prismio_assert_failed` (11 instructions, 44 bytes)
```asm
    0: cbz x0, +16
    4: ldrb w9, [x0]
    8: mov x8, x0
   12: cbnz w9, +20
   16: mov x8, x1
   20: stp x29, x30, [sp, #-0x10]!
   24: adrp x0, <harness_main+0x1da8>
   28: add x0, x0, #0xe67
   32: mov x1, x8
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `prismio_expect` (12 instructions, 48 bytes)
```asm
    0: cbz x0, +8
    4: ret
    8: stp x29, x30, [sp, #-0x10]!
   12: adrp x1, <harness_main+0x1da8>
   16: add x1, x1, #0xda6
   20: adrp x0, <harness_main+0x1da8>
   24: add x0, x0, #0xe0c
   28: mov x2, x1
   32: mov w3, wzr
   36: mov w4, wzr
   40: mov x29, sp
   44: bl <prismio_panic_hook>
```

#### `data_view_fail` (10 instructions, 40 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: mov x1, x0
    8: adrp x0, <harness_main+0x1da8>
   12: add x0, x0, #0xe78
   16: adrp x2, <harness_main+0x1da8>
   20: add x2, x2, #0xda6
   24: mov w3, wzr
   28: mov w4, wzr
   32: mov x29, sp
   36: bl <prismio_panic_hook>
```

#### `data_view_access_fail` (9 instructions, 36 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x8, <harness_main+0x1da8>
    8: add x8, x8, #0xd8b
   12: cmp w0, #0x1
   16: adrp x9, <harness_main+0x1da8>
   20: add x9, x9, #0xd55
   24: mov x29, sp
   28: csel x0, x9, x8, eq
   32: bl <data_view_fail>
```

#### `array_index_fail` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1da8>
    8: add x0, x0, #0xe9a
   12: adrp x1, <harness_main+0x1da8>
   16: add x1, x1, #0xe94
   20: adrp x2, <harness_main+0x1da8>
   24: add x2, x2, #0xda6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `list_index_fail` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1da8>
    8: add x0, x0, #0xe9a
   12: adrp x1, <harness_main+0x1da8>
   16: add x1, x1, #0xdf7
   20: adrp x2, <harness_main+0x1da8>
   24: add x2, x2, #0xda6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `prismio_alloc` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1da8>
    8: add x0, x0, #0xdea
   12: adrp x1, <harness_main+0x1da8>
   16: add x1, x1, #0xd10
   20: adrp x2, <harness_main+0x1da8>
   24: add x2, x2, #0xda6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `prismio_realloc` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1da8>
    8: add x0, x0, #0xdea
   12: adrp x1, <harness_main+0x1da8>
   16: add x1, x1, #0xd10
   20: adrp x2, <harness_main+0x1da8>
   24: add x2, x2, #0xda6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

#### `prismio_free` (11 instructions, 44 bytes)
```asm
    0: stp x29, x30, [sp, #-0x10]!
    4: adrp x0, <harness_main+0x1da8>
    8: add x0, x0, #0xdea
   12: adrp x1, <harness_main+0x1da8>
   16: add x1, x1, #0xd10
   20: adrp x2, <harness_main+0x1da8>
   24: add x2, x2, #0xda6
   28: mov w3, wzr
   32: mov w4, wzr
   36: mov x29, sp
   40: bl <prismio_panic_hook>
```

### D.4 Rust (opt-level 3, fat LTO)

#### `_RNvNtCs5Av9rWzHob7_3lib10algorithms3fib` (20 instructions, 80 bytes)
```asm
    0: str x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: mov w19, w0
   12: cmp w0, #0x2
   16: b.hs +36
   20: add w0, w19, wzr
   24: ldp x20, x19, [sp, #0x10]
   28: ldr x30, [sp], #0x20
   32: ret
   36: mov w20, wzr
   40: sub w0, w19, #0x1
   44: bl +0
   48: sub w19, w19, #0x2
   52: add w20, w0, w20
   56: cmp w19, #0x1
   60: b.hi +40
   64: add w0, w19, w20
   68: ldp x20, x19, [sp, #0x10]
   72: ldr x30, [sp], #0x20
   76: ret
```

#### `_RNvNtCs5Av9rWzHob7_3lib10algorithms5quick` (69 instructions, 276 bytes)
```asm
    0: stp x30, x21, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: cmp w1, w2
   12: b.ge +228
   16: mov w19, w2
   20: mov x20, x0
   24: b +48
   28: mov x0, x20
   32: bl +0
   36: cmp w21, w19
   40: mov w1, w21
   44: b.ge +228
   48: add w8, w1, w19
   52: asr w9, w8, #1
   56: sbfx x0, x8, #1, #31
   60: cmp w9, #0x7ff
   64: b.hi +268
   68: cmp w1, w19
   72: mov w2, w19
   76: mov w21, w1
   80: b.gt +28
   84: ldr w8, [x20, x0, lsl #2]
   88: mov w10, w1
   92: mov w9, w19
   96: b +116
  100: cmp w21, w2
  104: mov w10, w21
  108: mov w9, w2
  112: b.gt +28
  116: sxtw x0, w10
  120: cmp w10, #0x7ff
  124: b.hi +268
  128: mov x21, x0
  132: ldr w10, [x20, x21, lsl #2]
  136: cmp w10, w8
  140: b.hs +160
  144: add x21, x21, #0x1
  148: cmp w21, #0x800
  152: b.ne +132
  156: b +252
  160: sxtw x2, w9
  164: cmp w9, #0x7ff
  168: b.hi +240
  172: ldr w9, [x20, x2, lsl #2]
  176: cmp w9, w8
  180: b.ls +200
  184: sub x2, x2, #0x1
  188: cmp x2, #0x800
  192: b.lo +172
  196: b +240
  200: cmp x21, x2
  204: b.hi +100
  208: str w9, [x20, x21, lsl #2]
  212: add w21, w21, #0x1
  216: str w10, [x20, x2, lsl #2]
  220: sub w2, w2, #0x1
  224: b +100
  228: ldp x20, x19, [sp, #0x10]
  232: ldp x30, x21, [sp], #0x20
  236: ret
  240: mov x0, x2
  244: mov w1, #0x800
  248: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
  252: mov w8, #0x7ff
  256: sub w8, w8, w0
  260: add x8, x0, x8
  264: add x0, x8, #0x1
  268: mov w1, #0x800
  272: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
```

#### `bench_atomic_counter` (20 instructions, 80 bytes)
```asm
    0: mov w8, #0xa120
    4: mov w9, #0x44100000
    8: movk w8, #0x7, lsl #16
   12: str wzr, [x9]
   16: mul w8, w0, w8
   20: cbz w8, +68
   24: mov w10, wzr
   28: mov w9, #0x44100000
   32: and w11, w10, #0x3
   36: add w10, w10, #0x1
   40: add w11, w11, #0x1
   44: ldaxr w12, [x9]
   48: add w12, w12, w11
   52: stlxr w13, w12, [x9]
   56: cbnz w13, +44
   60: cmp w10, w8
   64: b.ne +32
   68: mov w8, #0x44100000
   72: ldar w0, [x8]
   76: ret
```

#### `bench_binary_search` (82 instructions, 328 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x1, lsl #12
   12: str xzr, [sp]
   16: sub sp, sp, #0x1, lsl #12
   20: str xzr, [sp]
   24: sub sp, sp, #0x1, lsl #12
   28: str xzr, [sp]
   32: sub sp, sp, #0x1, lsl #12
   36: mov w19, w0
   40: mov x0, sp
   44: mov w1, wzr
   48: mov w2, #0x4000
   52: str xzr, [sp]
   56: mov x20, sp
   60: bl <memset>
   64: mov x8, xzr
   68: add x9, x20, #0x4
   72: add w10, w8, #0x3
   76: add w11, w8, #0xa
   80: add x8, x8, #0xe
   84: cmp x8, #0x7, lsl #12
   88: stp w10, w11, [x9, #-0x4]
   92: add x9, x9, #0x8
   96: b.ne +72
  100: mov w8, #0x86a0
  104: movk w8, #0x1, lsl #16
  108: mul w8, w19, w8
  112: cbz w8, +300
  116: mov w13, #0x660d
  120: mov w14, #0xf35f
  124: mov w15, #0xb273
  128: mov w10, wzr
  132: mov w9, wzr
  136: mov w11, wzr
  140: mov w12, #0x3039
  144: movk w13, #0x19, lsl #16
  148: movk w14, #0x3c6e, lsl #16
  152: movk w15, #0x45e7, lsl #16
  156: mov w16, #0x7530
  160: mov x17, sp
  164: b +176
  168: cmp w10, w8
  172: b.eq +276
  176: madd w12, w12, w13, w14
  180: mov w18, wzr
  184: add w10, w10, #0x1
  188: mov w2, #0x1000
  192: umull x0, w12, w15
  196: lsr x0, x0, #45
  200: msub w1, w0, w16, w12
  204: add w3, w18, w2
  208: lsr w0, w3, #1
  212: cmp w3, #0x2, lsl #12
  216: b.hs +320
  220: ldr w3, [x17, x0, lsl #2]
  224: cmp w3, w1
  228: csel w2, w0, w2, hs
  232: csinc w18, w18, w0, hs
  236: cmp w18, w2
  240: b.lo +204
  244: cmp w18, #0x1, lsl #12
  248: b.hs +168
  252: ldr w0, [x17, w18, uxtw #2]
  256: cmp w0, w1
  260: b.ne +168
  264: add w9, w9, #0x1
  268: add w11, w18, w11
  272: b +168
  276: add w8, w11, w11, lsl #1
  280: add w0, w9, w8
  284: add sp, sp, #0x4, lsl #12
  288: ldp x20, x19, [sp, #0x10]
  292: ldp x29, x30, [sp], #0x20
  296: ret
  300: mov w0, wzr
  304: add sp, sp, #0x4, lsl #12
  308: ldp x20, x19, [sp, #0x10]
  312: ldp x29, x30, [sp], #0x20
  316: ret
  320: mov w1, #0x1000
  324: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
```

#### `bench_bytecode_interpreter` (107 instructions, 428 bytes)
```asm
    0: sub sp, sp, #0x20
    4: str x30, [sp, #0x10]
    8: mov w9, #0x1a80
   12: mov w8, #0x1
   16: mov w11, #0x2
   20: movk w9, #0x6, lsl #16
   24: stp w8, w11, [sp]
   28: mov w8, #0x3
   32: mul w10, w0, w9
   36: mov w0, #0x4
   40: stp w8, w0, [sp, #0x8]
   44: cbz w10, +376
   48: mov w11, wzr
   52: nop
   56: adr x12, 0x40083eb0
   60: mov x13, sp
   64: b +100
   68: ldr w8, [x13, x8, lsl #2]
   72: ldr w9, [x13, x9, lsl #2]
   76: add w8, w9, w8
   80: cmp w11, #0x7
   84: str w8, [x13, x0, lsl #2]
   88: csinc w11, wzr, w11, eq
   92: subs w10, w10, #0x1
   96: b.eq +356
  100: lsl w0, w11, #2
  104: cmp w0, #0x1f
  108: b.hi +408
  112: add x9, x12, x0, lsl #2
  116: ldp w14, w0, [x9]
  120: ldp w8, w9, [x9, #0x8]
  124: cmp w14, #0x1
  128: b.le +184
  132: cmp w14, #0x2
  136: b.eq +236
  140: cmp w14, #0x3
  144: b.eq +276
  148: cmp w14, #0x4
  152: b.ne +332
  156: cmp w8, #0x4
  160: b.hs +396
  164: cmp w0, #0x4
  168: b.hs +388
  172: ldr w8, [x13, x8, lsl #2]
  176: add w8, w8, w9
  180: b +80
  184: cbz w14, +304
  188: cmp w14, #0x1
  192: b.ne +332
  196: cmp w8, #0x3
  200: b.hi +396
  204: cmp w9, #0x4
  208: b.hs +416
  212: cmp w0, #0x4
  216: b.hs +388
  220: ldr w8, [x13, x8, lsl #2]
  224: ldr w9, [x13, x9, lsl #2]
  228: eor w8, w9, w8
  232: b +80
  236: cmp w8, #0x3
  240: b.hi +396
  244: cmp w9, #0x4
  248: b.hs +416
  252: cmp w0, #0x4
  256: b.hs +388
  260: ldr w8, [x13, x8, lsl #2]
  264: ldr w9, [x13, x9, lsl #2]
  268: mul w8, w9, w8
  272: b +80
  276: cmp w8, #0x3
  280: b.hi +396
  284: cmp w0, #0x4
  288: b.hs +388
  292: ldr w8, [x13, x8, lsl #2]
  296: lsl w8, w8, #1
  300: b +80
  304: cmp w8, #0x3
  308: b.hi +396
  312: cmp w9, #0x4
  316: b.hs +416
  320: cmp w0, #0x4
  324: b.lo +68
  328: b +388
  332: cmp w8, #0x4
  336: b.hs +396
  340: cmp w0, #0x4
  344: b.hs +388
  348: ldr w8, [x13, x8, lsl #2]
  352: b +80
  356: ldp w8, w9, [sp]
  360: ldp w10, w11, [sp, #0x8]
  364: eor w8, w9, w8
  368: eor w9, w10, w11
  372: eor w0, w8, w9
  376: ldr x30, [sp, #0x10]
  380: add sp, sp, #0x20
  384: ret
  388: mov w1, #0x4
  392: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
  396: mov x0, x8
  400: mov w1, #0x4
  404: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
  408: mov w1, #0x20
  412: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
  416: mov x0, x9
  420: mov w1, #0x4
  424: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
```

#### `bench_crc32` (76 instructions, 304 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub x9, sp, #0x8, lsl #12
   12: sub sp, sp, #0x1, lsl #12
   16: cmp sp, x9
   20: str xzr, [sp]
   24: b.ne +12
   28: sub sp, sp, #0x400
   32: mov w19, w0
   36: mov x0, sp
   40: mov w1, wzr
   44: mov w2, #0x400
   48: mov x20, sp
   52: bl <memset>
   56: mov x8, xzr
   60: add x9, x20, #0x4
   64: adrp x10, 0x40084000
   68: add x10, x10, #0x34
   72: ldp w12, w13, [x10, #-0x4]
   76: lsr w11, w8, #8
   80: add x8, x8, #0x2
   84: add x10, x10, #0x8
   88: cmp x8, #0x100
   92: eor w12, w11, w12
   96: eor w11, w11, w13
  100: stp w12, w11, [x9, #-0x4]
  104: add x9, x9, #0x8
  108: b.ne +72
  112: add x0, sp, #0x400
  116: mov w1, wzr
  120: mov w2, #0x8000
  124: add x20, sp, #0x400
  128: bl <memset>
  132: mov w10, #0x660d
  136: mov w11, #0xf35f
  140: mov x9, xzr
  144: mov w8, #0x7e8
  148: movk w10, #0x19, lsl #16
  152: movk w11, #0x3c6e, lsl #16
  156: madd w8, w8, w10, w11
  160: mov x12, x9
  164: add x9, x9, #0x1
  168: cmp x9, #0x8, lsl #12
  172: lsr w13, w8, #24
  176: strb w13, [x20, x12]
  180: b.ne +156
  184: lsl w8, w19, #5
  188: cbz w8, +280
  192: mov w10, wzr
  196: mov w9, #-0x1
  200: add x11, sp, #0x400
  204: mov x12, sp
  208: mov x13, xzr
  212: ldrb w14, [x11, x13]
  216: add x13, x13, #0x1
  220: cmp x13, #0x8, lsl #12
  224: eor w14, w14, w9
  228: and x14, x14, #0xff
  232: ldr w14, [x12, x14, lsl #2]
  236: eor w9, w14, w9, lsr #8
  240: b.ne +212
  244: add w10, w10, #0x1
  248: cmp w10, w8
  252: b.ne +208
  256: mvn w0, w9
  260: add sp, sp, #0x8, lsl #12
  264: add sp, sp, #0x400
  268: ldp x20, x19, [sp, #0x10]
  272: ldp x29, x30, [sp], #0x20
  276: ret
  280: mov w0, wzr
  284: add sp, sp, #0x8, lsl #12
  288: add sp, sp, #0x400
  292: ldp x20, x19, [sp, #0x10]
  296: ldp x29, x30, [sp], #0x20
  300: ret
```

#### `bench_edit_distance` (125 instructions, 500 bytes)
```asm
    0: str x29, [sp, #-0x50]!
    4: stp x30, x25, [sp, #0x10]
    8: stp x24, x23, [sp, #0x20]
   12: stp x22, x21, [sp, #0x30]
   16: stp x20, x19, [sp, #0x40]
   20: sub sp, sp, #0x1, lsl #12
   24: str xzr, [sp]
   28: sub sp, sp, #0x780
   32: mov w19, w0
   36: mov w20, #0xf35f
   40: mov w21, #0x660d
   44: add x0, sp, #0x8
   48: mov w1, wzr
   52: mov w2, #0x258
   56: str xzr, [sp]
   60: movk w20, #0x3c6e, lsl #16
   64: movk w21, #0x19, lsl #16
   68: add x22, sp, #0x8
   72: bl <memset>
   76: add x0, sp, #0x260
   80: mov w1, wzr
   84: mov w2, #0x258
   88: bl <memset>
   92: mov x9, xzr
   96: mov w8, #0x7a69
  100: madd w8, w8, w21, w20
  104: mov x10, x9
  108: add x9, x9, #0x1
  112: cmp x9, #0x258
  116: ubfx w11, w8, #12, #2
  120: strb w11, [x22, x10]
  124: b.ne +100
  128: mov x9, xzr
  132: add x10, sp, #0x260
  136: madd w8, w8, w21, w20
  140: mov x11, x9
  144: add x9, x9, #0x1
  148: cmp x9, #0x258
  152: ubfx w12, w8, #12, #2
  156: strb w12, [x10, x11]
  160: b.ne +136
  164: mov w20, wzr
  168: cbz w19, +456
  172: mov w21, wzr
  176: add x22, sp, #0xe1c
  180: add x23, sp, #0x4b8
  184: add x24, sp, #0x8
  188: add x25, sp, #0x260
  192: b +212
  196: ldr w8, [sp, #0xe18]
  200: cmp w21, w19
  204: add w20, w8, w20
  208: b.eq +456
  212: add x0, sp, #0x4b8
  216: mov w1, wzr
  220: mov w2, #0x964
  224: bl <memset>
  228: add x0, x22, #0x4
  232: mov w1, wzr
  236: mov w2, #0x960
  240: bl <memset>
  244: mov x8, xzr
  248: cmp x8, #0x258
  252: str w8, [x23, x8, lsl #2]
  256: cinc x9, x8, ne
  260: b.eq +276
  264: cmp x9, #0x259
  268: mov x8, x9
  272: b.lo +248
  276: add w21, w21, #0x1
  280: mov w8, #0x1
  284: cmp x8, #0x258
  288: sub x0, x8, #0x1
  292: str w8, [sp, #0xe1c]
  296: cinc x9, x8, ne
  300: cmp x0, #0x257
  304: b.hi +492
  308: ldrb w10, [x24, x0]
  312: mov w11, #0x1
  316: sub x12, x11, #0x1
  320: ldr w13, [x23, x11, lsl #2]
  324: ldr w14, [x22, x12, lsl #2]
  328: ldrb w15, [x25, x12]
  332: ldr w12, [x23, x12, lsl #2]
  336: add w16, w13, #0x1
  340: add w14, w14, #0x1
  344: cmp w14, w16
  348: csinc w13, w14, w13, lt
  352: cmp w10, w15
  356: cinc w12, w12, ne
  360: cmp w12, w13
  364: csel w13, w12, w13, lt
  368: cmp x11, #0x258
  372: str w13, [x22, x11, lsl #2]
  376: cinc x12, x11, ne
  380: b.eq +396
  384: cmp x12, #0x259
  388: mov x11, x12
  392: b.lo +316
  396: mov x10, xzr
  400: cmp x10, #0x258
  404: ldr w12, [x22, x10, lsl #2]
  408: cinc x11, x10, ne
  412: str w12, [x23, x10, lsl #2]
  416: b.eq +432
  420: cmp x11, #0x258
  424: mov x10, x11
  428: b.ls +400
  432: cmp x8, #0x258
  436: b.eq +196
  440: cmp x9, #0x258
  444: mov x8, x9
  448: b.ls +284
  452: b +196
  456: mov w0, w20
  460: add sp, sp, #0x1, lsl #12
  464: add sp, sp, #0x780
  468: ldp x20, x19, [sp, #0x40]
  472: ldp x22, x21, [sp, #0x30]
  476: ldp x24, x23, [sp, #0x20]
  480: ldp x30, x25, [sp, #0x10]
  484: ldr x29, [sp], #0x50
  488: ret
  492: mov w1, #0x258
  496: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
```

#### `bench_fibonacci` (8 instructions, 32 bytes)
```asm
    0: cbz w0, +28
    4: stp x30, x19, [sp, #-0x10]!
    8: mov w19, w0
   12: mov w0, #0x1b
   16: bl <_RNvNtCs5Av9rWzHob7_3lib10algorithms3fib>
   20: mul w0, w0, w19
   24: ldp x30, x19, [sp], #0x10
   28: ret
```

#### `bench_gcd_lcm` (24 instructions, 96 bytes)
```asm
    0: mov w8, wzr
    4: cbz w0, +88
    8: mov w9, wzr
   12: mov w10, #0x1
   16: mov w11, #0x1
   20: mov w13, w10
   24: mov w14, w11
   28: mov w12, w14
   32: udiv w14, w13, w14
   36: msub w14, w14, w12, w13
   40: mov w13, w12
   44: cbnz w14, +28
   48: add w11, w11, #0x1
   52: add w8, w12, w8
   56: cmp w11, #0x191
   60: b.ne +20
   64: add w10, w10, #0x1
   68: cmp w10, #0x191
   72: b.ne +16
   76: add w9, w9, #0x1
   80: cmp w9, w0
   84: b.ne +12
   88: mov w0, w8
   92: ret
```

#### `bench_heapsort` (159 instructions, 636 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x1, lsl #12
   12: str xzr, [sp]
   16: sub sp, sp, #0x1, lsl #12
   20: mov w19, w0
   24: mov x0, sp
   28: mov w1, wzr
   32: mov w2, #0x2000
   36: str xzr, [sp]
   40: mov x20, sp
   44: bl <memset>
   48: add w8, w19, w19, lsl #1
   52: mov w0, wzr
   56: lsl w12, w8, #3
   60: cbz w12, +572
   64: mov w15, #0x660d
   68: mov w16, #0xf35f
   72: mov w13, wzr
   76: mov w14, #0x1092
   80: movk w15, #0x19, lsl #16
   84: movk w16, #0x3c6e, lsl #16
   88: mov x8, xzr
   92: madd w14, w14, w15, w16
   96: lsr w9, w14, #4
  100: str w9, [x20, x8]
  104: add x8, x8, #0x4
  108: cmp x8, #0x2, lsl #12
  112: b.ne +92
  116: add w13, w13, #0x1
  120: mov w8, #0x3ff
  124: b +136
  128: sub w8, w17, #0x1
  132: cbz w17, +296
  136: mov w17, w8
  140: mov w18, w8
  144: cmp w18, #0x7ff
  148: mov w8, w18
  152: b.hi +600
  156: mov w9, #0x1
  160: cmp w18, #0x400
  164: bfi w9, w18, #1, #31
  168: b.hs +588
  172: ldr w1, [x20, x8, lsl #2]
  176: ldr w10, [x20, x9, lsl #2]
  180: cmp w1, w10
  184: b.lo +192
  188: mov w9, w18
  192: lsl w10, w18, #1
  196: cmp w10, #0x7fd
  200: b.gt +244
  204: cmp w9, #0x7ff
  208: mov w11, w9
  212: b.hi +612
  216: cmp w18, #0x3ff
  220: add w10, w10, #0x2
  224: b.eq +624
  228: ldr w11, [x20, x11, lsl #2]
  232: ldr w2, [x20, x10, lsl #2]
  236: cmp w11, w2
  240: b.lo +248
  244: mov w10, w9
  248: cmp w10, w18
  252: b.eq +128
  256: cmp w10, #0x7ff
  260: mov w9, w10
  264: b.hi +588
  268: ldr w11, [x20, x9, lsl #2]
  272: cmp w10, #0x400
  276: mov w18, w10
  280: str w11, [x20, x8, lsl #2]
  284: str w1, [x20, x9, lsl #2]
  288: b.lo +144
  292: b +128
  296: mov w10, #0x7ff
  300: ldr w11, [x20, x10, lsl #2]
  304: ldr w8, [sp]
  308: subs x17, x10, #0x1
  312: str w8, [x20, x10, lsl #2]
  316: str w11, [sp]
  320: b.ne +356
  324: b +516
  328: mov x10, x17
  332: ldr w11, [x20, x17, lsl #2]
  336: ldr w8, [sp]
  340: subs x17, x17, #0x1
  344: str w8, [x20, x10, lsl #2]
  348: str w11, [sp]
  352: b.eq +516
  356: mov x2, xzr
  360: mov x1, xzr
  364: mov w18, w17
  368: cmp x1, #0x3ff
  372: orr x9, x2, #0x1
  376: b.hi +588
  380: ldr w8, [x20, x9, lsl #2]
  384: cmp w11, w8
  388: b.lo +396
  392: mov x9, x1
  396: add x8, x2, #0x2
  400: cmp x10, x8
  404: b.ls +440
  408: cmp x9, #0x7ff
  412: b.hi +588
  416: cmp x1, #0x3ff
  420: b.eq +600
  424: ldr w2, [x20, x9, lsl #2]
  428: ldr w3, [x20, x8, lsl #2]
  432: cmp w2, w3
  436: b.lo +444
  440: mov x8, x9
  444: cmp x8, x1
  448: b.eq +328
  452: cmp x8, #0x7ff
  456: b.hi +600
  460: lsl x2, x8, #1
  464: ldr w9, [x20, x8, lsl #2]
  468: str w9, [x20, x1, lsl #2]
  472: mov x1, x8
  476: cmp x2, x18
  480: str w11, [x20, x8, lsl #2]
  484: b.lo +368
  488: mov x10, x17
  492: ldr w11, [x20, x17, lsl #2]
  496: ldr w8, [sp]
  500: subs x17, x17, #0x1
  504: str w8, [x20, x10, lsl #2]
  508: str w11, [sp]
  512: b.ne +356
  516: mov w8, wzr
  520: mov x9, #-0x800
  524: add x10, x20, #0x4
  528: ldp w11, w17, [x10, #-0x4]
  532: add w18, w9, #0x801
  536: add w1, w9, #0x802
  540: adds x9, x9, #0x2
  544: add x10, x10, #0x8
  548: madd w0, w11, w18, w0
  552: madd w8, w17, w1, w8
  556: b.ne +528
  560: cmp w13, w12
  564: add w0, w8, w0
  568: b.ne +88
  572: add sp, sp, #0x2, lsl #12
  576: ldp x20, x19, [sp, #0x10]
  580: ldp x29, x30, [sp], #0x20
  584: ret
  588: mov x0, x9
  592: mov w1, #0x800
  596: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
  600: mov x0, x8
  604: mov w1, #0x800
  608: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
  612: mov x0, x11
  616: mov w1, #0x800
  620: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
  624: mov x0, x10
  628: mov w1, #0x800
  632: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
```

#### `bench_knapsack` (107 instructions, 428 bytes)
```asm
    0: stp x29, x30, [sp, #-0x50]!
    4: stp x26, x25, [sp, #0x10]
    8: stp x24, x23, [sp, #0x20]
   12: stp x22, x21, [sp, #0x30]
   16: stp x20, x19, [sp, #0x40]
   20: sub sp, sp, #0x1, lsl #12
   24: str xzr, [sp]
   28: sub sp, sp, #0x980
   32: mov w19, w0
   36: mov w20, #0xf35f
   40: mov w21, #0x660d
   44: add x0, sp, #0xc
   48: mov w1, wzr
   52: mov w2, #0x100
   56: str xzr, [sp]
   60: movk w20, #0x3c6e, lsl #16
   64: movk w21, #0x19, lsl #16
   68: add x22, sp, #0xc
   72: bl <memset>
   76: add x0, sp, #0x10c
   80: mov w1, wzr
   84: mov w2, #0x100
   88: add x23, sp, #0x10c
   92: bl <memset>
   96: mov w9, #0x3e46
  100: mov w11, #0xa0fe
  104: mov x8, xzr
  108: mov w13, #0x63
  112: movk w9, #0x6eb, lsl #16
  116: mov w10, #0x25
  120: movk w11, #0x2a3, lsl #16
  124: mov w12, #0x61
  128: madd w14, w13, w21, w20
  132: madd w13, w14, w21, w20
  136: lsr w14, w14, #8
  140: umull x16, w14, w9
  144: lsr w15, w13, #8
  148: umull x17, w15, w11
  152: lsr x16, x16, #32
  156: msub w14, w16, w10, w14
  160: lsr x17, x17, #32
  164: msub w15, w17, w12, w15
  168: add w14, w14, #0x3
  172: str w14, [x22, x8]
  176: add w14, w15, #0x1
  180: str w14, [x23, x8]
  184: add x8, x8, #0x4
  188: cmp x8, #0x100
  192: b.ne +128
  196: add w8, w19, w19, lsl #1
  200: mov w19, wzr
  204: lsl w20, w8, #1
  208: cbz w20, +384
  212: mov w8, #0x1770
  216: add x22, sp, #0x20c
  220: mov w21, wzr
  224: add x23, x22, x8
  228: add x24, sp, #0xc
  232: add x25, sp, #0x10c
  236: mov w26, #0x5dc
  240: b +260
  244: ldr w8, [sp, #0x197c]
  248: cmp w21, w20
  252: add w19, w8, w19
  256: b.eq +384
  260: add x0, sp, #0x20c
  264: mov w1, wzr
  268: mov w2, #0x1774
  272: add w21, w21, #0x1
  276: bl <memset>
  280: mov x8, xzr
  284: b +300
  288: add x8, x8, #0x1
  292: cmp x8, #0x40
  296: b.eq +244
  300: ldrsw x9, [x24, x8, lsl #2]
  304: cmp w9, #0x5dc
  308: b.gt +288
  312: ldr w10, [x25, x8, lsl #2]
  316: sub w13, w26, w9
  320: mov w11, #0x5dd
  324: mov x12, x23
  328: sxtw x0, w13
  332: cmp w9, #0x5dd
  336: b.hs +420
  340: ldr w13, [x22, x0, lsl #2]
  344: ldr w14, [x12]
  348: sub x11, x11, #0x1
  352: add w13, w13, w10
  356: cmp w13, w14
  360: csel w13, w13, w14, gt
  364: cmp x11, x9
  368: str w13, [x12], #-0x4
  372: sub w13, w0, #0x1
  376: b.hi +328
  380: b +288
  384: mov w0, w19
  388: add sp, sp, #0x1, lsl #12
  392: add sp, sp, #0x980
  396: ldp x20, x19, [sp, #0x40]
  400: ldp x22, x21, [sp, #0x30]
  404: ldp x24, x23, [sp, #0x20]
  408: ldp x26, x25, [sp, #0x10]
  412: ldp x29, x30, [sp], #0x50
  416: ret
  420: mov w1, #0x5dd
  424: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
```

#### `bench_mandelbrot_fixed` (43 instructions, 172 bytes)
```asm
    0: add w8, w0, w0, lsl #1
    4: mov w0, wzr
    8: lsl w8, w8, #1
   12: cbz w8, +168
   16: mov w9, wzr
   20: b +36
   24: add w9, w9, #0x1
   28: cmp w9, w8
   32: b.eq +168
   36: mov w10, wzr
   40: b +56
   44: add w10, w10, #0x1
   48: cmp w10, #0x60
   52: b.eq +24
   56: lsl w11, w10, #11
   60: mov w12, wzr
   64: sub w11, w11, #0x18, lsl #12
   68: b +84
   72: cmp w12, #0x60
   76: add w0, w13, w0
   80: b.eq +44
   84: lsl w14, w12, #11
   88: mov w13, wzr
   92: mov w15, wzr
   96: mov w16, wzr
  100: add w12, w12, #0x1
  104: sub w14, w14, #0x20, lsl #12
  108: smull x17, w15, w15
  112: smull x18, w16, w16
  116: lsr x17, x17, #16
  120: lsr x18, x18, #16
  124: add w1, w17, w18
  128: cmp w1, #0x40, lsl #12
  132: b.gt +72
  136: smull x15, w15, w16
  140: add w13, w13, #0x1
  144: cmp w13, #0x28
  148: add x16, x11, x15, lsr #15
  152: sub w15, w14, w18
  156: add w15, w15, w17
  160: b.ne +108
  164: b +72
  168: ret
```

#### `bench_matrix_multiply` (117 instructions, 468 bytes)
```asm
    0: str x29, [sp, #-0x30]!
    4: stp x30, x21, [sp, #0x10]
    8: stp x20, x19, [sp, #0x20]
   12: sub x9, sp, #0xc, lsl #12
   16: sub sp, sp, #0x1, lsl #12
   20: cmp sp, x9
   24: str xzr, [sp]
   28: b.ne +16
   32: mov w19, w0
   36: mov x0, sp
   40: mov w1, wzr
   44: mov w2, #0x4000
   48: mov x20, sp
   52: bl <memset>
   56: add x0, sp, #0x4, lsl #12
   60: mov w1, wzr
   64: mov w2, #0x4000
   68: add x21, sp, #0x4, lsl #12
   72: bl <memset>
   76: add x0, sp, #0x8, lsl #12
   80: mov w1, wzr
   84: mov w2, #0x4000
   88: bl <memset>
   92: mov x11, #0x4ec5
   96: mov x13, #-0xf0f0f0f0f0f0f10
  100: mov x8, xzr
  104: movk x11, #0xc4ec, lsl #16
  108: mov x9, xzr
  112: mov x10, xzr
  116: movk x11, #0xec4e, lsl #32
  120: mov w12, #0xd
  124: movk x13, #0xf0f1
  128: movk x11, #0x4ec4, lsl #48
  132: mov x14, xzr
  136: mov x15, x8
  140: mov x16, x9
  144: umulh x17, x15, x13
  148: umulh x18, x16, x11
  152: lsr x17, x17, #4
  156: lsr x18, x18, #2
  160: add w17, w17, w17, lsl #4
  164: msub w18, w18, w12, w16
  168: sub w17, w15, w17
  172: str w17, [x20, x14]
  176: add x16, x16, #0x2
  180: add x15, x15, #0x5
  184: str w18, [x21, x14]
  188: add x14, x14, #0x4
  192: cmp x14, #0x100
  196: b.ne +144
  200: add x10, x10, #0x1
  204: add x9, x9, #0x7
  208: add x8, x8, #0x3
  212: cmp x10, #0x40
  216: add x20, x20, #0x100
  220: add x21, x21, #0x100
  224: b.ne +132
  228: lsl w8, w19, #3
  232: mov w0, wzr
  236: cbz w8, +448
  240: add x10, sp, #0x4, lsl #12
  244: mov w12, wzr
  248: mov x9, sp
  252: add x10, x10, #0x100
  256: add x11, sp, #0x8, lsl #12
  260: mov x13, xzr
  264: add x14, x9, #0x4
  268: add x15, x11, x13, lsl #8
  272: mov x16, xzr
  276: mov x17, x10
  280: mov w18, wzr
  284: mov w1, wzr
  288: mov w2, #0x40
  292: mov x3, x17
  296: mov x4, x14
  300: ldp w5, w7, [x4, #-0x4]
  304: ldur w6, [x3, #-0x100]
  308: ldr w19, [x3]
  312: subs x2, x2, #0x2
  316: add x4, x4, #0x8
  320: add x3, x3, #0x200
  324: madd w18, w6, w5, w18
  328: madd w1, w19, w7, w1
  332: b.ne +300
  336: add x2, x16, #0x1
  340: add w18, w1, w18
  344: str w18, [x15, x16, lsl #2]
  348: cmp x2, #0x40
  352: add x17, x17, #0x4
  356: mov x16, x2
  360: b.ne +280
  364: add x13, x13, #0x1
  368: add x14, x14, #0x100
  372: cmp x13, #0x40
  376: b.ne +268
  380: mov w13, wzr
  384: mov w14, #0x1000
  388: add x15, x11, #0x4
  392: ldp w16, w17, [x15, #-0x4]
  396: subs x14, x14, #0x2
  400: add x15, x15, #0x8
  404: add w0, w16, w0
  408: add w13, w17, w13
  412: b.ne +392
  416: and w14, w12, #0x3f
  420: add w12, w12, #0x1
  424: add w0, w13, w0
  428: ldr w15, [x9, w14, uxtw #2]
  432: cmp w12, w8
  436: add w13, w15, #0x1
  440: str w13, [x9, w14, uxtw #2]
  444: b.ne +260
  448: add sp, sp, #0xc, lsl #12
  452: ldp x20, x19, [sp, #0x20]
  456: ldp x30, x21, [sp, #0x10]
  460: ldr x29, [sp], #0x30
  464: ret
```

#### `bench_mem_copy` (60 instructions, 240 bytes)
```asm
    0: mov x10, #0xe0a8
    4: mov x11, #0xc150
    8: mov w12, #0x8
   12: movk x10, #0xfa53, lsl #16
   16: movk x11, #0xf4a7, lsl #16
   20: mov x8, xzr
   24: movk x10, #0xcdcb, lsl #32
   28: movk x11, #0x9b97, lsl #32
   32: mov x9, xzr
   36: movk x10, #0xf1bb, lsl #48
   40: movk x11, #0xe377, lsl #48
   44: movk w12, #0x4400, lsl #16
   48: mov w13, #0x5555
   52: mov w14, #0x44000000
   56: orr x15, x8, x12
   60: eor x16, x9, x13
   64: str x16, [x8, x14]
   68: add x8, x8, #0x10
   72: eor x16, x10, x13
   76: add x10, x10, x11
   80: cmp x8, #0x8, lsl #12
   84: add x9, x9, x11
   88: str x16, [x15]
   92: b.ne +56
   96: add w8, w0, w0, lsl #3
  100: lsl w8, w8, #5
  104: cbz w8, +168
  108: mov x9, xzr
  112: mov w10, #0x44000000
  116: mov w11, #0x45000000
  120: mov x12, xzr
  124: add x9, x9, #0x1
  128: lsr x13, x12, #3
  132: ldr x14, [x12, x10]
  136: str x14, [x12, x11]
  140: cmp x13, #0xfff
  144: add x13, x9, x14
  148: str x13, [x12, x10]
  152: add x12, x12, #0x8
  156: b.lo +128
  160: cmp x9, x8
  164: b.ne +120
  168: mov w11, #0x8
  172: mov x9, xzr
  176: mov x8, xzr
  180: mov x10, xzr
  184: movk w11, #0x4500, lsl #16
  188: mov w12, #0x45000000
  192: orr x13, x9, x11
  196: ldr x14, [x9, x12]
  200: add x9, x9, #0x10
  204: ldr x13, [x13]
  208: cmp x9, #0x8, lsl #12
  212: add x8, x14, x8
  216: add x10, x13, x10
  220: b.ne +192
  224: add x8, x10, x8
  228: lsr x9, x8, #32
  232: eor w0, w9, w8
  236: ret
```

#### `bench_pointer_chase` (78 instructions, 312 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x1, lsl #12
   12: str xzr, [sp]
   16: sub sp, sp, #0x1, lsl #12
   20: str xzr, [sp]
   24: sub sp, sp, #0x1, lsl #12
   28: str xzr, [sp]
   32: sub sp, sp, #0x1, lsl #12
   36: mov w19, w0
   40: mov x0, sp
   44: mov w1, wzr
   48: mov w2, #0x2000
   52: str xzr, [sp]
   56: mov x20, sp
   60: bl <memset>
   64: add x0, sp, #0x2, lsl #12
   68: mov w1, wzr
   72: mov w2, #0x2000
   76: bl <memset>
   80: mov x8, xzr
   84: add x9, x20, x8, lsl #2
   88: add w10, w8, #0x1
   92: stp w8, w10, [x9]
   96: add x8, x8, #0x2
  100: cmp x8, #0x800
  104: b.ne +84
  108: mov w10, #0x660d
  112: mov w11, #0xf35f
  116: mov w8, #0x2329
  120: mov w9, #0x7ff
  124: movk w10, #0x19, lsl #16
  128: movk w11, #0x3c6e, lsl #16
  132: mov x12, sp
  136: madd w8, w8, w10, w11
  140: add w14, w9, #0x1
  144: lsr w13, w8, #8
  148: udiv w15, w13, w14
  152: msub w13, w15, w14, w13
  156: ldr w15, [x12, x9, lsl #2]
  160: ldr w14, [x12, w13, uxtw #2]
  164: str w14, [x12, x9, lsl #2]
  168: subs x9, x9, #0x1
  172: str w15, [x12, w13, uxtw #2]
  176: b.ne +136
  180: mov x8, xzr
  184: mov x9, sp
  188: add x10, sp, #0x2, lsl #12
  192: ldr w0, [x9, x8, lsl #2]
  196: cmp w0, #0x800
  200: b.hs +304
  204: add x8, x8, #0x1
  208: and x11, x8, #0x7ff
  212: cmp x8, #0x800
  216: ldr w11, [x9, x11, lsl #2]
  220: str w11, [x10, x0, lsl #2]
  224: b.ne +192
  228: mov w8, #0x9f00
  232: mov w0, wzr
  236: movk w8, #0x24, lsl #16
  240: mul w9, w19, w8
  244: cbz w9, +284
  248: ldr w8, [sp]
  252: add x10, sp, #0x2, lsl #12
  256: cmp w8, #0x7ff
  260: mov w8, w8
  264: b.hi +300
  268: ldr w8, [x10, x8, lsl #2]
  272: subs w9, w9, #0x1
  276: add w0, w8, w0
  280: b.ne +256
  284: add sp, sp, #0x4, lsl #12
  288: ldp x20, x19, [sp, #0x10]
  292: ldp x29, x30, [sp], #0x20
  296: ret
  300: mov x0, x8
  304: mov w1, #0x800
  308: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check>
```

#### `bench_popcount` (31 instructions, 124 bytes)
```asm
    0: mov w8, #0x27c0
    4: movk w8, #0x9, lsl #16
    8: mul w8, w0, w8
   12: cbz w8, +116
   16: mov w10, #0x660d
   20: mov w11, #0xf35f
   24: mov w0, wzr
   28: mov w9, #0x37
   32: movk w10, #0x19, lsl #16
   36: movk w11, #0x3c6e, lsl #16
   40: mov w12, #0x1010101
   44: b +56
   48: subs w8, w8, #0x1
   52: b.eq +112
   56: madd w9, w9, w10, w11
   60: cbz w9, +48
   64: lsr w13, w9, #1
   68: and w13, w13, #0x55555555
   72: sub w13, w9, w13
   76: lsr w14, w13, #2
   80: and w13, w13, #0x33333333
   84: and w14, w14, #0x33333333
   88: add w13, w13, w14
   92: add w13, w13, w13, lsr #4
   96: and w13, w13, #0xf0f0f0f
  100: mul w13, w13, w12
  104: add w0, w0, w13, lsr #24
  108: b +48
  112: ret
  116: mov w0, wzr
  120: ret
```

#### `bench_prime_sieve` (104 instructions, 416 bytes)
```asm
    0: str x29, [sp, #-0x50]!
    4: stp x30, x25, [sp, #0x10]
    8: stp x24, x23, [sp, #0x20]
   12: stp x22, x21, [sp, #0x30]
   16: stp x20, x19, [sp, #0x40]
   20: sub x9, sp, #0x30, lsl #12
   24: sub sp, sp, #0x1, lsl #12
   28: cmp sp, x9
   32: str xzr, [sp]
   36: b.ne +24
   40: sub sp, sp, #0xd40
   44: str xzr, [sp]
   48: cbz w0, +376
   52: mov w22, #0xd40
   56: mov w24, #0xd3a
   60: mov w20, w0
   64: mov w19, wzr
   68: mov w21, wzr
   72: movk w22, #0x3, lsl #16
   76: mov x23, sp
   80: movk w24, #0x3, lsl #16
   84: mov w25, #0x1
   88: b +108
   92: add w21, w21, #0x1
   96: add w19, w8, w19
  100: cmp w21, w20
  104: b.eq +380
  108: mov w2, #0xd40
  112: mov x0, sp
  116: mov w1, wzr
  120: movk w2, #0x3, lsl #16
  124: bl <memset>
  128: mov x9, xzr
  132: mov x10, xzr
  136: mov x11, xzr
  140: mov w8, wzr
  144: mov w12, #0x4
  148: mov w13, #0x6
  152: mov w14, #0x2
  156: b +192
  160: add x14, x14, #0x1
  164: add x11, x11, #0x1
  168: add x13, x13, #0x3
  172: cmp x14, x22
  176: add x12, x12, #0x2
  180: add x10, x10, #0x3
  184: sub x9, x9, #0x3
  188: b.eq +92
  192: add x16, x11, x11, lsl #1
  196: cmp x10, x24
  200: sub x17, x11, x11, lsl #2
  204: csel x15, x10, x24, hi
  208: ldrb w0, [x23, x14]
  212: cmp x16, x24
  216: csel x16, x16, x24, hi
  220: adds x16, x16, x17
  224: cset w18, ne
  228: csetm x17, ne
  232: cbnz w0, +160
  236: lsr x0, x14, #5
  240: add w8, w8, #0x1
  244: cmp x0, #0xc34
  248: b.hi +160
  252: sub x18, x16, x18
  256: cmp x16, #0x0
  260: udiv x0, x18, x14
  264: cinc x18, x25, ne
  268: add x16, x18, x0
  272: cmp x16, #0x2
  276: b.hs +288
  280: lsl x15, x14, #1
  284: b +356
  288: add x15, x15, x9
  292: add x15, x15, x17
  296: and x17, x16, #0xfffffffffffffffe
  300: udiv x0, x15, x14
  304: add x15, x17, #0x2
  308: mul x15, x14, x15
  312: add x18, x18, x0
  316: mov x0, sp
  320: and x18, x18, #0xfffffffffffffffe
  324: add x1, x0, x12
  328: subs x18, x18, #0x2
  332: strb w25, [x1]
  336: strb w25, [x0, x13]
  340: mov x0, x1
  344: b.ne +324
  348: cmp x16, x17
  352: b.eq +160
  356: strb w25, [x23, x15]
  360: add x15, x15, x14
  364: cmp x15, x22
  368: b.lo +356
  372: b +160
  376: mov w19, wzr
  380: mov w0, w19
  384: add sp, sp, #0x30, lsl #12
  388: add sp, sp, #0xd40
  392: ldp x20, x19, [sp, #0x40]
  396: ldp x22, x21, [sp, #0x30]
  400: ldp x24, x23, [sp, #0x20]
  404: ldp x30, x25, [sp, #0x10]
  408: ldr x29, [sp], #0x50
  412: ret
```

#### `bench_quicksort` (59 instructions, 236 bytes)
```asm
    0: str x29, [sp, #-0x50]!
    4: stp x30, x25, [sp, #0x10]
    8: stp x24, x23, [sp, #0x20]
   12: stp x22, x21, [sp, #0x30]
   16: stp x20, x19, [sp, #0x40]
   20: sub sp, sp, #0x1, lsl #12
   24: str xzr, [sp]
   28: sub sp, sp, #0x1, lsl #12
   32: mov w19, w0
   36: mov x0, sp
   40: mov w1, wzr
   44: mov w2, #0x2000
   48: str xzr, [sp]
   52: mov x20, sp
   56: bl <memset>
   60: add w8, w19, w19, lsl #2
   64: mov w19, wzr
   68: lsl w21, w8, #3
   72: cbz w21, +204
   76: mov w24, #0x660d
   80: mov w25, #0xf35f
   84: mov w22, wzr
   88: mov w23, #0x309
   92: movk w24, #0x19, lsl #16
   96: movk w25, #0x3c6e, lsl #16
  100: mov x8, xzr
  104: madd w23, w23, w24, w25
  108: lsr w9, w23, #4
  112: str w9, [x20, x8]
  116: add x8, x8, #0x4
  120: cmp x8, #0x2, lsl #12
  124: b.ne +104
  128: mov x0, sp
  132: mov w1, wzr
  136: mov w2, #0x7ff
  140: bl <_RNvNtCs5Av9rWzHob7_3lib10algorithms5quick>
  144: mov w8, wzr
  148: mov x9, #-0x800
  152: add x10, x20, #0x4
  156: ldp w11, w12, [x10, #-0x4]
  160: add w13, w9, #0x801
  164: add w14, w9, #0x802
  168: adds x9, x9, #0x2
  172: add x10, x10, #0x8
  176: madd w19, w11, w13, w19
  180: madd w8, w12, w14, w8
  184: b.ne +156
  188: add w22, w22, #0x1
  192: add w19, w8, w19
  196: cmp w22, w21
  200: b.ne +100
  204: mov w0, w19
  208: add sp, sp, #0x2, lsl #12
  212: ldp x20, x19, [sp, #0x40]
  216: ldp x22, x21, [sp, #0x30]
  220: ldp x24, x23, [sp, #0x20]
  224: ldp x30, x25, [sp, #0x10]
  228: ldr x29, [sp], #0x50
  232: ret
```

#### `bench_ring_buffer` (52 instructions, 208 bytes)
```asm
    0: stp x29, x30, [sp, #-0x20]!
    4: stp x20, x19, [sp, #0x10]
    8: sub sp, sp, #0x1, lsl #12
   12: mov w19, w0
   16: mov x0, sp
   20: mov w1, wzr
   24: mov w2, #0x1000
   28: str xzr, [sp]
   32: mov x20, sp
   36: bl <memset>
   40: mov w8, #0x93e0
   44: movk w8, #0x4, lsl #16
   48: mul w8, w19, w8
   52: cbz w8, +188
   56: mov w14, #0x660d
   60: mov w15, #0xf35f
   64: mov w9, wzr
   68: mov w11, wzr
   72: mov w10, wzr
   76: mov w12, wzr
   80: mov w13, #0x141
   84: movk w14, #0x19, lsl #16
   88: movk w15, #0x3c6e, lsl #16
   92: b +104
   96: subs w8, w8, #0x1
  100: b.eq +168
  104: madd w13, w13, w14, w15
  108: sub w16, w9, w11
  112: cmp w16, #0x400
  116: b.hs +132
  120: and w16, w9, #0x3ff
  124: add w9, w9, #0x1
  128: str w13, [x20, w16, uxtw #2]
  132: tbnz w13, #0x8, +96
  136: cmp w9, w11
  140: b.eq +96
  144: and w16, w11, #0x3ff
  148: add w11, w11, #0x1
  152: add w12, w12, #0x1
  156: ldr w16, [x20, w16, uxtw #2]
  160: add w10, w16, w10
  164: b +96
  168: eor w0, w10, w12
  172: add sp, sp, #0x1, lsl #12
  176: ldp x20, x19, [sp, #0x10]
  180: ldp x29, x30, [sp], #0x20
  184: ret
  188: mov w0, wzr
  192: add sp, sp, #0x1, lsl #12
  196: ldp x20, x19, [sp, #0x10]
  200: ldp x29, x30, [sp], #0x20
  204: ret
```

#### `bench_sha256` (152 instructions, 608 bytes)
```asm
    0: sub sp, sp, #0x160
    4: stp x29, x30, [sp, #0x100]
    8: stp x28, x27, [sp, #0x110]
   12: stp x26, x25, [sp, #0x120]
   16: stp x24, x23, [sp, #0x130]
   20: stp x22, x21, [sp, #0x140]
   24: stp x20, x19, [sp, #0x150]
   28: mov x20, sp
   32: mov w19, w0
   36: mov w1, wzr
   40: add x0, x20, #0x40
   44: mov w2, #0xc0
   48: bl <memset>
   52: mov w8, #0xbb8
   56: mul w8, w19, w8
   60: cbz w8, +568
   64: mov w10, #0xf35f
   68: mov w11, #0x660d
   72: mov w13, #0xcd19
   76: movk w10, #0x3c6e, lsl #16
   80: mov w15, #0xd9ab
   84: mov w16, #0x688c
   88: mov w14, #0x527f
   92: mov w0, #0xf53a
   96: mov w18, #0xae85
  100: mov w17, #0xe667
  104: mov w9, wzr
  108: movk w11, #0x19, lsl #16
  112: mov w2, #0x328
  116: movk w13, #0x5be0, lsl #16
  120: add w12, w10, #0x13
  124: movk w15, #0x1f83, lsl #16
  128: movk w16, #0x9b05, lsl #16
  132: movk w14, #0x510e, lsl #16
  136: movk w0, #0xa54f, lsl #16
  140: movk w18, #0xbb67, lsl #16
  144: movk w17, #0x6a09, lsl #16
  148: nop
  152: adr x1, 0x40083f30
  156: madd w3, w2, w11, w10
  160: mov w5, #0x30
  164: madd w2, w3, w11, w10
  168: stp w3, w2, [sp]
  172: madd w2, w2, w11, w10
  176: madd w4, w2, w11, w10
  180: stp w2, w4, [sp, #0x8]
  184: madd w2, w4, w11, w10
  188: madd w4, w2, w11, w10
  192: stp w2, w4, [sp, #0x10]
  196: madd w2, w4, w11, w10
  200: madd w4, w2, w11, w10
  204: stp w2, w4, [sp, #0x18]
  208: madd w2, w4, w11, w10
  212: madd w4, w2, w11, w10
  216: stp w2, w4, [sp, #0x20]
  220: madd w2, w4, w11, w10
  224: madd w4, w2, w11, w10
  228: stp w2, w4, [sp, #0x28]
  232: madd w2, w4, w11, w10
  236: madd w4, w2, w11, w10
  240: stp w2, w4, [sp, #0x30]
  244: madd w4, w4, w11, w10
  248: madd w2, w4, w11, w10
  252: stp w4, w2, [sp, #0x38]
  256: add x4, x20, #0x40
  260: ldur w6, [x4, #-0x8]
  264: mov w7, w3
  268: ldur w3, [x4, #-0x3c]
  272: ldur w22, [x4, #-0x1c]
  276: subs x5, x5, #0x1
  280: ror w19, w6, #0x11
  284: ror w21, w3, #0x7
  288: add w7, w22, w7
  292: eor w19, w19, w6, ror #19
  296: eor w21, w21, w3, ror #18
  300: eor w6, w19, w6, lsr #10
  304: eor w19, w21, w3, lsr #3
  308: add w6, w7, w6
  312: add w6, w6, w19
  316: str w6, [x4], #0x4
  320: b.ne +260
  324: mov x21, xzr
  328: mov w22, w17
  332: mov w19, w18
  336: mov w7, w12
  340: mov w6, w0
  344: mov w23, w14
  348: mov w3, w16
  352: mov w4, w15
  356: mov w5, w13
  360: mov w24, w5
  364: mov w5, w4
  368: mov w4, w3
  372: mov w3, w23
  376: ror w23, w23, #0x6
  380: mov w25, w6
  384: mov w6, w7
  388: mov w7, w19
  392: mov w19, w22
  396: eor w22, w23, w3, ror #11
  400: and w23, w3, w4
  404: bic w26, w5, w3
  408: ror w27, w19, #0x2
  412: orr w23, w23, w26
  416: ldr w26, [x1, x21]
  420: add w23, w23, w24
  424: eor w22, w22, w3, ror #25
  428: and w28, w7, w6
  432: eor w24, w27, w19, ror #13
  436: ldr w27, [x20, x21]
  440: add w23, w23, w26
  444: eor w26, w7, w6
  448: add x21, x21, #0x4
  452: eor w24, w24, w19, ror #22
  456: and w26, w19, w26
  460: add w23, w23, w27
  464: eor w26, w26, w28
  468: add w22, w23, w22
  472: cmp x21, #0x100
  476: add w24, w24, w26
  480: add w23, w22, w25
  484: add w22, w24, w22
  488: b.ne +360
  492: add w9, w9, #0x1
  496: add w17, w22, w17
  500: add w18, w19, w18
  504: add w12, w7, w12
  508: add w0, w6, w0
  512: add w14, w23, w14
  516: cmp w9, w8
  520: add w16, w3, w16
  524: add w15, w4, w15
  528: add w13, w5, w13
  532: b.ne +156
  536: eor w8, w15, w13
  540: eor w8, w8, w16
  544: eor w8, w8, w0
  548: eor w8, w8, w12
  552: eor w8, w8, w18
  556: eor w8, w8, w14
  560: eor w0, w8, w17
  564: b +576
  568: mov w0, #0x60eb
  572: movk w0, #0xc627, lsl #16
  576: ldp x20, x19, [sp, #0x150]
  580: ldp x22, x21, [sp, #0x140]
  584: ldp x24, x23, [sp, #0x130]
  588: ldp x26, x25, [sp, #0x120]
  592: ldp x28, x27, [sp, #0x110]
  596: ldp x29, x30, [sp, #0x100]
  600: add sp, sp, #0x160
  604: ret
```

#### `bench_spinlock` (28 instructions, 112 bytes)
```asm
    0: mov w8, #0x3500
    4: movk w8, #0xc, lsl #16
    8: mul w9, w0, w8
   12: mov w8, #0x10
   16: movk w8, #0x4410, lsl #16
   20: str wzr, [x8]
   24: str wzr, [x8, #0x10]
   28: cbz w9, +104
   32: mov w10, wzr
   36: mov w11, #0x1
   40: ldaxr w12, [x8]
   44: cbnz w12, +88
   48: stlxr w12, w11, [x8]
   52: cbnz w12, +40
   56: ldr w12, [x8, #0x10]
   60: add w10, w10, #0x1
   64: cmp w10, w9
   68: add w12, w12, #0x1
   72: str w12, [x8, #0x10]
   76: stlr wzr, [x8]
   80: b.ne +40
   84: b +96
   88: clrex
   92: b +40
   96: ldr w0, [x8, #0x10]
  100: ret
  104: mov w0, wzr
  108: ret
```

#### `bench_volatile_registers` (97 instructions, 388 bytes)
```asm
    0: mov w9, #0x44200000
    4: mov w8, #0x4
    8: str wzr, [x9]
   12: mov w9, #0xbba0
   16: movk w8, #0x4420, lsl #16
   20: movk w9, #0xd, lsl #16
   24: str wzr, [x8]
   28: mul w9, w0, w9
   32: str wzr, [x8, #0x4]
   36: str wzr, [x8, #0x8]
   40: str wzr, [x8, #0xc]
   44: str wzr, [x8, #0x10]
   48: str wzr, [x8, #0x14]
   52: str wzr, [x8, #0x18]
   56: str wzr, [x8, #0x1c]
   60: str wzr, [x8, #0x20]
   64: str wzr, [x8, #0x24]
   68: str wzr, [x8, #0x28]
   72: str wzr, [x8, #0x2c]
   76: str wzr, [x8, #0x30]
   80: str wzr, [x8, #0x34]
   84: str wzr, [x8, #0x38]
   88: str wzr, [x8, #0x3c]
   92: str wzr, [x8, #0x40]
   96: str wzr, [x8, #0x44]
  100: str wzr, [x8, #0x48]
  104: str wzr, [x8, #0x4c]
  108: str wzr, [x8, #0x50]
  112: str wzr, [x8, #0x54]
  116: str wzr, [x8, #0x58]
  120: str wzr, [x8, #0x5c]
  124: str wzr, [x8, #0x60]
  128: str wzr, [x8, #0x64]
  132: str wzr, [x8, #0x68]
  136: str wzr, [x8, #0x6c]
  140: str wzr, [x8, #0x70]
  144: str wzr, [x8, #0x74]
  148: str wzr, [x8, #0x78]
  152: str wzr, [x8, #0x7c]
  156: str wzr, [x8, #0x80]
  160: str wzr, [x8, #0x84]
  164: str wzr, [x8, #0x88]
  168: str wzr, [x8, #0x8c]
  172: str wzr, [x8, #0x90]
  176: str wzr, [x8, #0x94]
  180: str wzr, [x8, #0x98]
  184: str wzr, [x8, #0x9c]
  188: str wzr, [x8, #0xa0]
  192: str wzr, [x8, #0xa4]
  196: str wzr, [x8, #0xa8]
  200: str wzr, [x8, #0xac]
  204: str wzr, [x8, #0xb0]
  208: str wzr, [x8, #0xb4]
  212: str wzr, [x8, #0xb8]
  216: str wzr, [x8, #0xbc]
  220: str wzr, [x8, #0xc0]
  224: str wzr, [x8, #0xc4]
  228: str wzr, [x8, #0xc8]
  232: str wzr, [x8, #0xcc]
  236: str wzr, [x8, #0xd0]
  240: str wzr, [x8, #0xd4]
  244: str wzr, [x8, #0xd8]
  248: str wzr, [x8, #0xdc]
  252: str wzr, [x8, #0xe0]
  256: str wzr, [x8, #0xe4]
  260: str wzr, [x8, #0xe8]
  264: str wzr, [x8, #0xec]
  268: str wzr, [x8, #0xf0]
  272: str wzr, [x8, #0xf4]
  276: str wzr, [x8, #0xf8]
  280: cbz w9, +348
  284: mov w10, wzr
  288: mov w11, wzr
  292: mov w8, wzr
  296: mov w12, #0x44200000
  300: and w13, w10, #0xfc
  304: mov w14, w11
  308: add w11, w11, #0x1
  312: orr x13, x13, x12
  316: cmp w9, w11
  320: add w10, w10, #0x1c
  324: ldr w15, [x13]
  328: add w14, w14, w15
  332: add w8, w15, w8
  336: str w14, [x13]
  340: b.ne +300
  344: b +352
  348: mov w8, wzr
  352: mov w9, wzr
  356: mov w10, #0x40
  360: mov w11, #0x44200000
  364: ldr w12, [x11], #0x4
  368: subs x10, x10, #0x1
  372: add w9, w12, w9
  376: b.ne +364
  380: eor w0, w9, w8
  384: ret
```

#### `_RNvNtCsfr3MPOfBGpN_4core9panicking9panic_fmt` (1 instructions, 4 bytes)
```asm
    0: b +0
```

#### `_RNvNtCsfr3MPOfBGpN_4core9panicking18panic_bounds_check` (2 instructions, 8 bytes)
```asm
    0: str x30, [sp, #-0x10]!
    4: bl <_RNvNtCsfr3MPOfBGpN_4core9panicking9panic_fmt>
```

## Appendix E: Prismio's IR before optimisation

What the frontend hands LLVM for `edit_distance` and `mandelbrot_fixed`, the module the pipeline starts from. Note the loop versions, the per-site checks and the zero-fill.

```llvm
define i32 @bench_edit_distance__U32(i32 %0) {
entry:
  %scale.95 = alloca i32, align 4
  store i32 %0, ptr %scale.95, align 4
  %a.96 = alloca ptr, align 8
  %1 = alloca [600 x i8], align 4
  store [600 x i8] zeroinitializer, ptr %1, align 1
  %2 = getelementptr inbounds [600 x i8], ptr %1, i32 0, i32 0
  store ptr %2, ptr %a.96, align 8
  %b.97 = alloca ptr, align 8
  %3 = alloca [600 x i8], align 4
  store [600 x i8] zeroinitializer, ptr %3, align 1
  %4 = getelementptr inbounds [600 x i8], ptr %3, i32 0, i32 0
  store ptr %4, ptr %b.97, align 8
  %s.98 = alloca i32, align 4
  store i32 31337, ptr %s.98, align 4
  %i.99 = alloca i32, align 4
  store i32 0, ptr %i.99, align 4
  %5 = load i32, ptr %i.99, align 4
  %6 = sext i32 %5 to i64
  %7 = sub i64 600, %6
  %pushguard.8.100 = alloca i1, align 4
  store i1 true, ptr %pushguard.8.100, align 1
  %rangeguard.10.101 = alloca i1, align 4
  store i1 true, ptr %rangeguard.10.101, align 1
  %8 = load i32, ptr %i.99, align 4
  %9 = sext i32 %8 to i64
  %10 = icmp sge i64 %9, 0
  %11 = and i1 %10, true
  %12 = and i1 %11, true
  %13 = load i1, ptr %rangeguard.10.101, align 1
  %14 = and i1 %13, %12
  store i1 %14, ptr %rangeguard.10.101, align 1
  %15 = load i1, ptr %rangeguard.10.101, align 1
  %16 = and i1 %15, true
  store i1 %16, ptr %rangeguard.10.101, align 1
  %17 = load i1, ptr %rangeguard.10.101, align 1
  %pushguard.9.102 = alloca i1, align 4
  %rangeguard.11.103 = alloca i1, align 4
  %total.104 = alloca i32, align 4
  %r.105 = alloca i32, align 4
  %prev.106 = alloca ptr, align 8
  %18 = alloca [601 x i32], align 4
  %cur.107 = alloca ptr, align 8
  %19 = alloca [601 x i32], align 4
  %j.108 = alloca i32, align 4
  %pushguard.10.109 = alloca i1, align 4
  %rangeguard.12.110 = alloca i1, align 4
  %pushguard.11.111 = alloca i1, align 4
  %rangeguard.13.112 = alloca i1, align 4
  %cost.113 = alloca i32, align 4
  %cost.114 = alloca i32, align 4
  %pushguard.12.115 = alloca i1, align 4
  %rangeguard.14.116 = alloca i1, align 4
  br i1 %17, label %label_149, label %label_150

label_149:                                        ; preds = %label_151, %entry
  %20 = load i32, ptr %i.99, align 4
  %21 = icmp slt i32 %20, 600
  br i1 %21, label %label_151, label %label_147

label_150:                                        ; preds = %label_152, %entry
  %22 = load i32, ptr %i.99, align 4
  %23 = icmp slt i32 %22, 600
  br i1 %23, label %label_152, label %label_147

label_151:                                        ; preds = %label_149
  %24 = load i32, ptr %s.98, align 4
  %25 = mul i32 %24, 1664525
  %26 = add i32 %25, 1013904223
  store i32 %26, ptr %s.98, align 4
  %27 = load ptr, ptr %a.96, align 8
  %28 = load i32, ptr %i.99, align 4
  %29 = load i32, ptr %s.98, align 4
  %30 = lshr i32 %29, 12
  %31 = and i32 %30, 3
  %32 = trunc i32 %31 to i8
  %33 = getelementptr inbounds i8, ptr %27, i32 %28
  store i8 %32, ptr %33, align 1
  %34 = load i32, ptr %i.99, align 4
  %35 = add nsw i32 %34, 1
  store i32 %35, ptr %i.99, align 4
  br label %label_149

label_147:                                        ; preds = %label_150, %label_149
  store i32 0, ptr %i.99, align 4
  %36 = load i32, ptr %i.99, align 4
  %37 = sext i32 %36 to i64
  %38 = sub i64 600, %37
  store i1 true, ptr %pushguard.9.102, align 1
  store i1 true, ptr %rangeguard.11.103, align 1
  %39 = load i32, ptr %i.99, align 4
  %40 = sext i32 %39 to i64
  %41 = icmp sge i64 %40, 0
  %42 = and i1 %41, true
  %43 = and i1 %42, true
  %44 = load i1, ptr %rangeguard.11.103, align 1
  %45 = and i1 %44, %43
  store i1 %45, ptr %rangeguard.11.103, align 1
  %46 = load i1, ptr %rangeguard.11.103, align 1
  %47 = and i1 %46, true
  store i1 %47, ptr %rangeguard.11.103, align 1
  %48 = load i1, ptr %rangeguard.11.103, align 1
  br i1 %48, label %label_155, label %label_156

label_152:                                        ; preds = %label_150
  %49 = load i32, ptr %s.98, align 4
  %50 = mul i32 %49, 1664525
  %51 = add i32 %50, 1013904223
  store i32 %51, ptr %s.98, align 4
  %52 = load ptr, ptr %a.96, align 8
  %53 = load i32, ptr %i.99, align 4
  %54 = load i32, ptr %s.98, align 4
  %55 = lshr i32 %54, 12
  %56 = and i32 %55, 3
  %57 = trunc i32 %56 to i8
  %58 = getelementptr inbounds i8, ptr %52, i32 %53
  store i8 %57, ptr %58, align 1
  %59 = load i32, ptr %i.99, align 4
  %60 = add nsw i32 %59, 1
  store i32 %60, ptr %i.99, align 4
  br label %label_150

label_155:                                        ; preds = %label_157, %label_147
  %61 = load i32, ptr %i.99, align 4
  %62 = icmp slt i32 %61, 600
  br i1 %62, label %label_157, label %label_153

label_156:                                        ; preds = %label_158, %label_147
  %63 = load i32, ptr %i.99, align 4
  %64 = icmp slt i32 %63, 600
  br i1 %64, label %label_158, label %label_153

label_157:                                        ; preds = %label_155
  %65 = load i32, ptr %s.98, align 4
  %66 = mul i32 %65, 1664525
  %67 = add i32 %66, 1013904223
  store i32 %67, ptr %s.98, align 4
  %68 = load ptr, ptr %b.97, align 8
  %69 = load i32, ptr %i.99, align 4
  %70 = load i32, ptr %s.98, align 4
  %71 = lshr i32 %70, 12
  %72 = and i32 %71, 3
  %73 = trunc i32 %72 to i8
  %74 = getelementptr inbounds i8, ptr %68, i32 %69
  store i8 %73, ptr %74, align 1
  %75 = load i32, ptr %i.99, align 4
  %76 = add nsw i32 %75, 1
  store i32 %76, ptr %i.99, align 4
  br label %label_155

label_153:                                        ; preds = %label_156, %label_155
  store i32 0, ptr %total.104, align 4
  store i32 0, ptr %r.105, align 4
  br label %label_160

label_158:                                        ; preds = %label_156
  %77 = load i32, ptr %s.98, align 4
  %78 = mul i32 %77, 1664525
  %79 = add i32 %78, 1013904223
  store i32 %79, ptr %s.98, align 4
  %80 = load ptr, ptr %b.97, align 8
  %81 = load i32, ptr %i.99, align 4
  %82 = load i32, ptr %s.98, align 4
  %83 = lshr i32 %82, 12
  %84 = and i32 %83, 3
  %85 = trunc i32 %84 to i8
  %86 = getelementptr inbounds i8, ptr %80, i32 %81
  store i8 %85, ptr %86, align 1
  %87 = load i32, ptr %i.99, align 4
  %88 = add nsw i32 %87, 1
  store i32 %88, ptr %i.99, align 4
  br label %label_156

label_160:                                        ; preds = %label_168, %label_153
  %89 = load i32, ptr %r.105, align 4
  %90 = load i32, ptr %scale.95, align 4
  %91 = icmp ult i32 %89, %90
  br i1 %91, label %label_161, label %label_159

label_161:                                        ; preds = %label_160
  call void @llvm.memset.p0.i64(ptr align 4 %18, i8 0, i64 2404, i1 false)
  %92 = getelementptr inbounds [601 x i32], ptr %18, i32 0, i32 0
  store ptr %92, ptr %prev.106, align 8
  call void @llvm.memset.p0.i64(ptr align 4 %19, i8 0, i64 2404, i1 false)
  %93 = getelementptr inbounds [601 x i32], ptr %19, i32 0, i32 0
  store ptr %93, ptr %cur.107, align 8
  store i32 0, ptr %j.108, align 4
  %94 = load i32, ptr %j.108, align 4
  %95 = sext i32 %94 to i64
  %96 = sub i64 600, %95
  %97 = add i64 %96, 1
  %98 = mul i64 %97, 1
  store i1 true, ptr %pushguard.10.109, align 1
  store i1 true, ptr %rangeguard.12.110, align 1
  %99 = load i32, ptr %j.108, align 4
  %100 = sext i32 %99 to i64
  %101 = icmp sge i64 %100, 0
  %102 = and i1 %101, true
  %103 = and i1 %102, true
  %104 = load i1, ptr %rangeguard.12.110, align 1
  %105 = and i1 %104, %103
  store i1 %105, ptr %rangeguard.12.110, align 1
  %106 = load i1, ptr %rangeguard.12.110, align 1
  %107 = and i1 %106, true
  store i1 %107, ptr %rangeguard.12.110, align 1
  %108 = load i1, ptr %rangeguard.12.110, align 1
  br i1 %108, label %label_164, label %label_165

label_159:                                        ; preds = %label_160
  %109 = load i32, ptr %total.104, align 4
  ret i32 %109

label_164:                                        ; preds = %label_166, %label_161
  %110 = load i32, ptr %j.108, align 4
  %111 = icmp sle i32 %110, 600
  br i1 %111, label %label_166, label %label_162

label_165:                                        ; preds = %label_167, %label_161
  %112 = load i32, ptr %j.108, align 4
  %113 = icmp sle i32 %112, 600
  br i1 %113, label %label_167, label %label_162

label_166:                                        ; preds = %label_164
  %114 = load ptr, ptr %prev.106, align 8
  %115 = load i32, ptr %j.108, align 4
  %116 = load i32, ptr %j.108, align 4
  %117 = getelementptr inbounds i32, ptr %114, i32 %115
  store i32 %116, ptr %117, align 4, !tbaa !10
  %118 = load i32, ptr %j.108, align 4
  %119 = add nsw i32 %118, 1
  store i32 %119, ptr %j.108, align 4
  br label %label_164

label_162:                                        ; preds = %label_165, %label_164
  store i32 1, ptr %i.99, align 4
  br label %label_169

label_167:                                        ; preds = %label_165
  %120 = load ptr, ptr %prev.106, align 8
  %121 = load i32, ptr %j.108, align 4
  %122 = load i32, ptr %j.108, align 4
  %123 = getelementptr inbounds i32, ptr %120, i32 %121
  store i32 %122, ptr %123, align 4, !tbaa !10
  %124 = load i32, ptr %j.108, align 4
  %125 = add nsw i32 %124, 1
  store i32 %125, ptr %j.108, align 4
  br label %label_165

label_169:                                        ; preds = %label_183, %label_162
  %126 = load i32, ptr %i.99, align 4
  %127 = icmp sle i32 %126, 600
  br i1 %127, label %label_170, label %label_168

label_170:                                        ; preds = %label_169
  %128 = load ptr, ptr %cur.107, align 8
  %129 = load i32, ptr %i.99, align 4
  %130 = getelementptr inbounds i32, ptr %128, i32 0
  store i32 %129, ptr %130, align 4, !tbaa !10
  store i32 1, ptr %j.108, align 4
  %131 = load i32, ptr %j.108, align 4
  %132 = sext i32 %131 to i64
  %133 = sub i64 600, %132
  %134 = add i64 %133, 1
  %135 = mul i64 %134, 1
  store i1 true, ptr %pushguard.11.111, align 1
  store i1 true, ptr %rangeguard.13.112, align 1
  %136 = load i32, ptr %j.108, align 4
  %137 = sext i32 %136 to i64
  %138 = load i32, ptr %i.99, align 4
  %139 = sext i32 %138 to i64
  %140 = sub i64 %139, 1
  %141 = sub i64 %139, 1
  %142 = icmp sge i64 %140, 0
  %143 = icmp slt i64 %141, 600
  %144 = and i1 %142, %143
  %145 = and i1 %144, true
  %146 = load i1, ptr %rangeguard.13.112, align 1
  %147 = and i1 %146, %145
  store i1 %147, ptr %rangeguard.13.112, align 1
  %148 = sub i64 %137, 1
  %149 = icmp sge i64 %148, 0
  %150 = and i1 %149, true
  %151 = and i1 %150, true
  %152 = load i1, ptr %rangeguard.13.112, align 1
  %153 = and i1 %152, %151
  store i1 %153, ptr %rangeguard.13.112, align 1
  %154 = load i1, ptr %rangeguard.13.112, align 1
  %155 = and i1 %154, true
  store i1 %155, ptr %rangeguard.13.112, align 1
  %156 = icmp sge i64 %137, 0
  %157 = and i1 %156, true
  %158 = and i1 %157, true
  %159 = load i1, ptr %rangeguard.13.112, align 1
  %160 = and i1 %159, %158
  store i1 %160, ptr %rangeguard.13.112, align 1
  %161 = sub i64 %137, 1
  %162 = icmp sge i64 %161, 0
  %163 = and i1 %162, true
  %164 = and i1 %163, true
  %165 = load i1, ptr %rangeguard.13.112, align 1
  %166 = and i1 %165, %164
  store i1 %166, ptr %rangeguard.13.112, align 1
  %167 = sub i64 %137, 1
  %168 = icmp sge i64 %167, 0
  %169 = and i1 %168, true
  %170 = and i1 %169, true
  %171 = load i1, ptr %rangeguard.13.112, align 1
  %172 = and i1 %171, %170
  store i1 %172, ptr %rangeguard.13.112, align 1
  %173 = icmp sge i64 %137, 0
  %174 = and i1 %173, true
  %175 = and i1 %174, true
  %176 = load i1, ptr %rangeguard.13.112, align 1
  %177 = and i1 %176, %175
  store i1 %177, ptr %rangeguard.13.112, align 1
  %178 = load i1, ptr %rangeguard.13.112, align 1
  br i1 %178, label %label_173, label %label_174

label_168:                                        ; preds = %label_169
  %179 = load i32, ptr %total.104, align 4
  %180 = load ptr, ptr %prev.106, align 8
  %181 = getelementptr inbounds i32, ptr %180, i32 600
  %182 = load i32, ptr %181, align 4, !tbaa !10
  %183 = add i32 %179, %182
  store i32 %183, ptr %total.104, align 4
  %184 = load i32, ptr %r.105, align 4
  %185 = add i32 %184, 1
  store i32 %185, ptr %r.105, align 4
  br label %label_160

label_173:                                        ; preds = %label_178, %label_170
  %186 = load i32, ptr %j.108, align 4
  %187 = icmp sle i32 %186, 600
  br i1 %187, label %label_175, label %label_171

label_174:                                        ; preds = %label_182, %label_170
  %188 = load i32, ptr %j.108, align 4
  %189 = icmp sle i32 %188, 600
  br i1 %189, label %label_179, label %label_171

label_175:                                        ; preds = %label_173
  store i32 1, ptr %cost.113, align 4
  %190 = load ptr, ptr %a.96, align 8
  %191 = load i32, ptr %i.99, align 4
  %192 = sub nsw i32 %191, 1
  %193 = getelementptr inbounds i8, ptr %190, i32 %192
  %194 = load i8, ptr %193, align 1
  %195 = load ptr, ptr %b.97, align 8
  %196 = load i32, ptr %j.108, align 4
  %197 = sub nsw i32 %196, 1
  %198 = getelementptr inbounds i8, ptr %195, i32 %197
  %199 = load i8, ptr %198, align 1
  %200 = icmp eq i8 %194, %199
  br i1 %200, label %label_176, label %label_178

label_171:                                        ; preds = %label_174, %label_173
  store i32 0, ptr %j.108, align 4
  %201 = load i32, ptr %j.108, align 4
  %202 = sext i32 %201 to i64
  %203 = sub i64 600, %202
  %204 = add i64 %203, 1
  %205 = mul i64 %204, 1
  store i1 true, ptr %pushguard.12.115, align 1
  store i1 true, ptr %rangeguard.14.116, align 1
  %206 = load i32, ptr %j.108, align 4
  %207 = sext i32 %206 to i64
  %208 = icmp sge i64 %207, 0
  %209 = and i1 %208, true
  %210 = and i1 %209, true
  %211 = load i1, ptr %rangeguard.14.116, align 1
  %212 = and i1 %211, %210
  store i1 %212, ptr %rangeguard.14.116, align 1
  %213 = load i1, ptr %rangeguard.14.116, align 1
  %214 = and i1 %213, true
  store i1 %214, ptr %rangeguard.14.116, align 1
  %215 = icmp sge i64 %207, 0
  %216 = and i1 %215, true
  %217 = and i1 %216, true
  %218 = load i1, ptr %rangeguard.14.116, align 1
  %219 = and i1 %218, %217
  store i1 %219, ptr %rangeguard.14.116, align 1
  %220 = load i1, ptr %rangeguard.14.116, align 1
  br i1 %220, label %label_185, label %label_186

label_176:                                        ; preds = %label_175
  store i32 0, ptr %cost.113, align 4
  br label %label_178

label_178:                                        ; preds = %label_176, %label_175
  %221 = load ptr, ptr %cur.107, align 8
  %222 = load i32, ptr %j.108, align 4
  %223 = load ptr, ptr %prev.106, align 8
  %224 = load i32, ptr %j.108, align 4
  %225 = getelementptr inbounds i32, ptr %223, i32 %224
  %226 = load i32, ptr %225, align 4, !tbaa !10
  %227 = add nsw i32 %226, 1
  %228 = load ptr, ptr %cur.107, align 8
  %229 = load i32, ptr %j.108, align 4
  %230 = sub nsw i32 %229, 1
  %231 = getelementptr inbounds i32, ptr %228, i32 %230
  %232 = load i32, ptr %231, align 4, !tbaa !10
  %233 = add nsw i32 %232, 1
  %234 = call i32 @min__Int_Int(i32 %227, i32 %233)
  %235 = load ptr, ptr %prev.106, align 8
  %236 = load i32, ptr %j.108, align 4
  %237 = sub nsw i32 %236, 1
  %238 = getelementptr inbounds i32, ptr %235, i32 %237
  %239 = load i32, ptr %238, align 4, !tbaa !10
  %240 = load i32, ptr %cost.113, align 4
  %241 = add nsw i32 %239, %240
  %242 = call i32 @min__Int_Int(i32 %234, i32 %241)
  %243 = getelementptr inbounds i32, ptr %221, i32 %222
  store i32 %242, ptr %243, align 4, !tbaa !10
  %244 = load i32, ptr %j.108, align 4
  %245 = add nsw i32 %244, 1
  store i32 %245, ptr %j.108, align 4
  br label %label_173

label_179:                                        ; preds = %label_174
  store i32 1, ptr %cost.114, align 4
  %246 = load ptr, ptr %a.96, align 8
  %247 = load i32, ptr %i.99, align 4
  %248 = sub nsw i32 %247, 1
  %249 = getelementptr inbounds i8, ptr %246, i32 %248
  %250 = load i8, ptr %249, align 1
  %251 = load ptr, ptr %b.97, align 8
  %252 = load i32, ptr %j.108, align 4
  %253 = sub nsw i32 %252, 1
  %254 = getelementptr inbounds i8, ptr %251, i32 %253
  %255 = load i8, ptr %254, align 1
  %256 = icmp eq i8 %250, %255
  br i1 %256, label %label_180, label %label_182

label_180:                                        ; preds = %label_179
  store i32 0, ptr %cost.114, align 4
  br label %label_182

label_182:                                        ; preds = %label_180, %label_179
  %257 = load ptr, ptr %cur.107, align 8
  %258 = load i32, ptr %j.108, align 4
  %259 = load ptr, ptr %prev.106, align 8
  %260 = load i32, ptr %j.108, align 4
  %261 = getelementptr inbounds i32, ptr %259, i32 %260
  %262 = load i32, ptr %261, align 4, !tbaa !10
  %263 = add nsw i32 %262, 1
  %264 = load ptr, ptr %cur.107, align 8
  %265 = load i32, ptr %j.108, align 4
  %266 = sub nsw i32 %265, 1
  %267 = getelementptr inbounds i32, ptr %264, i32 %266
  %268 = load i32, ptr %267, align 4, !tbaa !10
  %269 = add nsw i32 %268, 1
  %270 = call i32 @min__Int_Int(i32 %263, i32 %269)
  %271 = load ptr, ptr %prev.106, align 8
  %272 = load i32, ptr %j.108, align 4
  %273 = sub nsw i32 %272, 1
  %274 = getelementptr inbounds i32, ptr %271, i32 %273
  %275 = load i32, ptr %274, align 4, !tbaa !10
  %276 = load i32, ptr %cost.114, align 4
  %277 = add nsw i32 %275, %276
  %278 = call i32 @min__Int_Int(i32 %270, i32 %277)
  %279 = getelementptr inbounds i32, ptr %257, i32 %258
  store i32 %278, ptr %279, align 4, !tbaa !10
  %280 = load i32, ptr %j.108, align 4
  %281 = add nsw i32 %280, 1
  store i32 %281, ptr %j.108, align 4
  br label %label_174

label_185:                                        ; preds = %label_187, %label_171
  %282 = load i32, ptr %j.108, align 4
  %283 = icmp sle i32 %282, 600
  br i1 %283, label %label_187, label %label_183

label_186:                                        ; preds = %label_188, %label_171
  %284 = load i32, ptr %j.108, align 4
  %285 = icmp sle i32 %284, 600
  br i1 %285, label %label_188, label %label_183

label_187:                                        ; preds = %label_185
  %286 = load ptr, ptr %prev.106, align 8
  %287 = load i32, ptr %j.108, align 4
  %288 = load ptr, ptr %cur.107, align 8
  %289 = load i32, ptr %j.108, align 4
  %290 = getelementptr inbounds i32, ptr %288, i32 %289
  %291 = load i32, ptr %290, align 4, !tbaa !10
  %292 = getelementptr inbounds i32, ptr %286, i32 %287
  store i32 %291, ptr %292, align 4, !tbaa !10
  %293 = load i32, ptr %j.108, align 4
  %294 = add nsw i32 %293, 1
  store i32 %294, ptr %j.108, align 4
  br label %label_185

label_183:                                        ; preds = %label_186, %label_185
  %295 = load i32, ptr %i.99, align 4
  %296 = add nsw i32 %295, 1
  store i32 %296, ptr %i.99, align 4
  br label %label_169

label_188:                                        ; preds = %label_186
  %297 = load ptr, ptr %prev.106, align 8
  %298 = load i32, ptr %j.108, align 4
  %299 = load ptr, ptr %cur.107, align 8
  %300 = load i32, ptr %j.108, align 4
  %301 = getelementptr inbounds i32, ptr %299, i32 %300
  %302 = load i32, ptr %301, align 4, !tbaa !10
  %303 = getelementptr inbounds i32, ptr %297, i32 %298
  store i32 %302, ptr %303, align 4, !tbaa !10
  %304 = load i32, ptr %j.108, align 4
  %305 = add nsw i32 %304, 1
  store i32 %305, ptr %j.108, align 4
  br label %label_186
}
define i32 @bench_mandelbrot_fixed__U32(i32 %0) {
entry:
  %scale.394 = alloca i32, align 4
  store i32 %0, ptr %scale.394, align 4
  %total.395 = alloca i32, align 4
  store i32 0, ptr %total.395, align 4
  %_.396 = alloca i32, align 4
  store i32 0, ptr %_.396, align 4
  %py.397 = alloca i32, align 4
  %px.398 = alloca i32, align 4
  %cr.399 = alloca i32, align 4
  %ci.400 = alloca i32, align 4
  %zr.401 = alloca i32, align 4
  %zi.402 = alloca i32, align 4
  %it.403 = alloca i32, align 4
  %zr2.404 = alloca i32, align 4
  %zi2.405 = alloca i32, align 4
  %cr.406 = alloca i32, align 4
  %ci.407 = alloca i32, align 4
  %zr.408 = alloca i32, align 4
  %zi.409 = alloca i32, align 4
  %it.410 = alloca i32, align 4
  %zr2.411 = alloca i32, align 4
  %zi2.412 = alloca i32, align 4
  %px.413 = alloca i32, align 4
  %cr.414 = alloca i32, align 4
  %ci.415 = alloca i32, align 4
  %zr.416 = alloca i32, align 4
  %zi.417 = alloca i32, align 4
  %it.418 = alloca i32, align 4
  %zr2.419 = alloca i32, align 4
  %zi2.420 = alloca i32, align 4
  %cr.421 = alloca i32, align 4
  %ci.422 = alloca i32, align 4
  %zr.423 = alloca i32, align 4
  %zi.424 = alloca i32, align 4
  %it.425 = alloca i32, align 4
  %zr2.426 = alloca i32, align 4
  %zi2.427 = alloca i32, align 4
  br label %label_562

label_562:                                        ; preds = %label_564, %entry
  %1 = load i32, ptr %_.396, align 4
  %2 = icmp slt i32 %1, 6
  br i1 %2, label %label_563, label %label_561

label_563:                                        ; preds = %label_562
  store i32 0, ptr %py.397, align 4
  br i1 true, label %label_566, label %label_567

label_561:                                        ; preds = %label_562
  %3 = load i32, ptr %total.395, align 4
  ret i32 %3

label_566:                                        ; preds = %label_563
  br label %label_594

label_567:                                        ; preds = %label_563
  br label %label_568

label_568:                                        ; preds = %label_567
  %4 = load i32, ptr %py.397, align 4
  %5 = icmp sgt i32 %4, 96
  br i1 %5, label %label_569, label %label_565

label_569:                                        ; preds = %label_571, %label_568
  store i32 0, ptr %px.398, align 4
  br i1 true, label %label_573, label %label_574

label_565:                                        ; preds = %label_594, %label_570, %label_568
  br label %label_564

label_573:                                        ; preds = %label_569
  br label %label_585

label_574:                                        ; preds = %label_569
  br label %label_575

label_575:                                        ; preds = %label_574
  %6 = load i32, ptr %px.398, align 4
  %7 = icmp sgt i32 %6, 96
  br i1 %7, label %label_576, label %label_572

label_576:                                        ; preds = %label_578, %label_575
  %8 = load i32, ptr %px.398, align 4
  %9 = mul i32 %8, 2048
  %10 = add nsw i32 -131072, %9
  store i32 %10, ptr %cr.399, align 4
  %11 = load i32, ptr %py.397, align 4
  %12 = mul i32 %11, 2048
  %13 = add nsw i32 -98304, %12
  store i32 %13, ptr %ci.400, align 4
  store i32 0, ptr %zr.401, align 4
  store i32 0, ptr %zi.402, align 4
  store i32 0, ptr %it.403, align 4
  br label %label_580

label_572:                                        ; preds = %label_585, %label_577, %label_575
  br label %label_570

label_580:                                        ; preds = %label_584, %label_576
  %14 = load i32, ptr %it.403, align 4
  %15 = icmp ult i32 %14, 40
  br i1 %15, label %label_581, label %label_579

label_581:                                        ; preds = %label_580
  %16 = load i32, ptr %zr.401, align 4
  %17 = sext i32 %16 to i64
  %18 = load i32, ptr %zr.401, align 4
  %19 = sext i32 %18 to i64
  %20 = mul i64 %17, %19
  %21 = ashr i64 %20, 16
  %22 = trunc i64 %21 to i32
  store i32 %22, ptr %zr2.404, align 4
  %23 = load i32, ptr %zi.402, align 4
  %24 = sext i32 %23 to i64
  %25 = load i32, ptr %zi.402, align 4
  %26 = sext i32 %25 to i64
  %27 = mul i64 %24, %26
  %28 = ashr i64 %27, 16
  %29 = trunc i64 %28 to i32
  store i32 %29, ptr %zi2.405, align 4
  %30 = load i32, ptr %zr2.404, align 4
  %31 = load i32, ptr %zi2.405, align 4
  %32 = add i32 %30, %31
  %33 = icmp sgt i32 %32, 262144
  br i1 %33, label %label_582, label %label_583

label_579:                                        ; preds = %label_582, %label_580
  %34 = load i32, ptr %total.395, align 4
  %35 = load i32, ptr %it.403, align 4
  %36 = add i32 %34, %35
  store i32 %36, ptr %total.395, align 4
  br label %label_577

label_582:                                        ; preds = %label_581
  br label %label_579

label_583:                                        ; preds = %label_581
  %37 = load i32, ptr %zr.401, align 4
  %38 = sext i32 %37 to i64
  %39 = load i32, ptr %zi.402, align 4
  %40 = sext i32 %39 to i64
  %41 = mul i64 %38, %40
  %42 = ashr i64 %41, 15
  %43 = trunc i64 %42 to i32
  %44 = load i32, ptr %ci.400, align 4
  %45 = add i32 %43, %44
  store i32 %45, ptr %zi.402, align 4
  %46 = load i32, ptr %zr2.404, align 4
  %47 = load i32, ptr %zi2.405, align 4
  %48 = sub i32 %46, %47
  %49 = load i32, ptr %cr.399, align 4
  %50 = add i32 %48, %49
  store i32 %50, ptr %zr.401, align 4
  %51 = load i32, ptr %it.403, align 4
  %52 = add i32 %51, 1
  store i32 %52, ptr %it.403, align 4
  br label %label_584

label_584:                                        ; preds = %label_583
  br label %label_580

label_577:                                        ; preds = %label_579
  %53 = load i32, ptr %px.398, align 4
  %54 = sub i32 %53, 96
  %55 = icmp ugt i32 %54, 1
  br i1 %55, label %label_578, label %label_572

label_578:                                        ; preds = %label_577
  %56 = sub nsw i32 %53, 1
  store i32 %56, ptr %px.398, align 4
  br label %label_576

label_585:                                        ; preds = %label_587, %label_573
  %57 = load i32, ptr %px.398, align 4
  %58 = icmp slt i32 %57, 96
  br i1 %58, label %label_586, label %label_572

label_586:                                        ; preds = %label_585
  %59 = load i32, ptr %px.398, align 4
  %60 = mul i32 %59, 2048
  %61 = add nsw i32 -131072, %60
  store i32 %61, ptr %cr.406, align 4
  %62 = load i32, ptr %py.397, align 4
  %63 = mul i32 %62, 2048
  %64 = add nsw i32 -98304, %63
  store i32 %64, ptr %ci.407, align 4
  store i32 0, ptr %zr.408, align 4
  store i32 0, ptr %zi.409, align 4
  store i32 0, ptr %it.410, align 4
  br label %label_589

label_589:                                        ; preds = %label_593, %label_586
  %65 = load i32, ptr %it.410, align 4
  %66 = icmp ult i32 %65, 40
  br i1 %66, label %label_590, label %label_588

label_590:                                        ; preds = %label_589
  %67 = load i32, ptr %zr.408, align 4
  %68 = sext i32 %67 to i64
  %69 = load i32, ptr %zr.408, align 4
  %70 = sext i32 %69 to i64
  %71 = mul i64 %68, %70
  %72 = ashr i64 %71, 16
  %73 = trunc i64 %72 to i32
  store i32 %73, ptr %zr2.411, align 4
  %74 = load i32, ptr %zi.409, align 4
  %75 = sext i32 %74 to i64
  %76 = load i32, ptr %zi.409, align 4
  %77 = sext i32 %76 to i64
  %78 = mul i64 %75, %77
  %79 = ashr i64 %78, 16
  %80 = trunc i64 %79 to i32
  store i32 %80, ptr %zi2.412, align 4
  %81 = load i32, ptr %zr2.411, align 4
  %82 = load i32, ptr %zi2.412, align 4
  %83 = add i32 %81, %82
  %84 = icmp sgt i32 %83, 262144
  br i1 %84, label %label_591, label %label_592

label_588:                                        ; preds = %label_591, %label_589
  %85 = load i32, ptr %total.395, align 4
  %86 = load i32, ptr %it.410, align 4
  %87 = add i32 %85, %86
  store i32 %87, ptr %total.395, align 4
  br label %label_587

label_591:                                        ; preds = %label_590
  br label %label_588

label_592:                                        ; preds = %label_590
  %88 = load i32, ptr %zr.408, align 4
  %89 = sext i32 %88 to i64
  %90 = load i32, ptr %zi.409, align 4
  %91 = sext i32 %90 to i64
  %92 = mul i64 %89, %91
  %93 = ashr i64 %92, 15
  %94 = trunc i64 %93 to i32
  %95 = load i32, ptr %ci.407, align 4
  %96 = add i32 %94, %95
  store i32 %96, ptr %zi.409, align 4
  %97 = load i32, ptr %zr2.411, align 4
  %98 = load i32, ptr %zi2.412, align 4
  %99 = sub i32 %97, %98
  %100 = load i32, ptr %cr.406, align 4
  %101 = add i32 %99, %100
  store i32 %101, ptr %zr.408, align 4
  %102 = load i32, ptr %it.410, align 4
  %103 = add i32 %102, 1
  store i32 %103, ptr %it.410, align 4
  br label %label_593

label_593:                                        ; preds = %label_592
  br label %label_589

label_587:                                        ; preds = %label_588
  %104 = load i32, ptr %px.398, align 4
  %105 = add nsw i32 %104, 1
  store i32 %105, ptr %px.398, align 4
  br label %label_585

label_570:                                        ; preds = %label_572
  %106 = load i32, ptr %py.397, align 4
  %107 = sub i32 %106, 96
  %108 = icmp ugt i32 %107, 1
  br i1 %108, label %label_571, label %label_565

label_571:                                        ; preds = %label_570
  %109 = sub nsw i32 %106, 1
  store i32 %109, ptr %py.397, align 4
  br label %label_569

label_594:                                        ; preds = %label_596, %label_566
  %110 = load i32, ptr %py.397, align 4
  %111 = icmp slt i32 %110, 96
  br i1 %111, label %label_595, label %label_565

label_595:                                        ; preds = %label_594
  store i32 0, ptr %px.413, align 4
  br i1 true, label %label_598, label %label_599

label_598:                                        ; preds = %label_595
  br label %label_610

label_599:                                        ; preds = %label_595
  br label %label_600

label_600:                                        ; preds = %label_599
  %112 = load i32, ptr %px.413, align 4
  %113 = icmp sgt i32 %112, 96
  br i1 %113, label %label_601, label %label_597

label_601:                                        ; preds = %label_603, %label_600
  %114 = load i32, ptr %px.413, align 4
  %115 = mul i32 %114, 2048
  %116 = add nsw i32 -131072, %115
  store i32 %116, ptr %cr.414, align 4
  %117 = load i32, ptr %py.397, align 4
  %118 = mul i32 %117, 2048
  %119 = add nsw i32 -98304, %118
  store i32 %119, ptr %ci.415, align 4
  store i32 0, ptr %zr.416, align 4
  store i32 0, ptr %zi.417, align 4
  store i32 0, ptr %it.418, align 4
  br label %label_605

label_597:                                        ; preds = %label_610, %label_602, %label_600
  br label %label_596

label_605:                                        ; preds = %label_609, %label_601
  %120 = load i32, ptr %it.418, align 4
  %121 = icmp ult i32 %120, 40
  br i1 %121, label %label_606, label %label_604

label_606:                                        ; preds = %label_605
  %122 = load i32, ptr %zr.416, align 4
  %123 = sext i32 %122 to i64
  %124 = load i32, ptr %zr.416, align 4
  %125 = sext i32 %124 to i64
  %126 = mul i64 %123, %125
  %127 = ashr i64 %126, 16
  %128 = trunc i64 %127 to i32
  store i32 %128, ptr %zr2.419, align 4
  %129 = load i32, ptr %zi.417, align 4
  %130 = sext i32 %129 to i64
  %131 = load i32, ptr %zi.417, align 4
  %132 = sext i32 %131 to i64
  %133 = mul i64 %130, %132
  %134 = ashr i64 %133, 16
  %135 = trunc i64 %134 to i32
  store i32 %135, ptr %zi2.420, align 4
  %136 = load i32, ptr %zr2.419, align 4
  %137 = load i32, ptr %zi2.420, align 4
  %138 = add i32 %136, %137
  %139 = icmp sgt i32 %138, 262144
  br i1 %139, label %label_607, label %label_608

label_604:                                        ; preds = %label_607, %label_605
  %140 = load i32, ptr %total.395, align 4
  %141 = load i32, ptr %it.418, align 4
  %142 = add i32 %140, %141
  store i32 %142, ptr %total.395, align 4
  br label %label_602

label_607:                                        ; preds = %label_606
  br label %label_604

label_608:                                        ; preds = %label_606
  %143 = load i32, ptr %zr.416, align 4
  %144 = sext i32 %143 to i64
  %145 = load i32, ptr %zi.417, align 4
  %146 = sext i32 %145 to i64
  %147 = mul i64 %144, %146
  %148 = ashr i64 %147, 15
  %149 = trunc i64 %148 to i32
  %150 = load i32, ptr %ci.415, align 4
  %151 = add i32 %149, %150
  store i32 %151, ptr %zi.417, align 4
  %152 = load i32, ptr %zr2.419, align 4
  %153 = load i32, ptr %zi2.420, align 4
  %154 = sub i32 %152, %153
  %155 = load i32, ptr %cr.414, align 4
  %156 = add i32 %154, %155
  store i32 %156, ptr %zr.416, align 4
  %157 = load i32, ptr %it.418, align 4
  %158 = add i32 %157, 1
  store i32 %158, ptr %it.418, align 4
  br label %label_609

label_609:                                        ; preds = %label_608
  br label %label_605

label_602:                                        ; preds = %label_604
  %159 = load i32, ptr %px.413, align 4
  %160 = sub i32 %159, 96
  %161 = icmp ugt i32 %160, 1
  br i1 %161, label %label_603, label %label_597

label_603:                                        ; preds = %label_602
  %162 = sub nsw i32 %159, 1
  store i32 %162, ptr %px.413, align 4
  br label %label_601

label_610:                                        ; preds = %label_612, %label_598
  %163 = load i32, ptr %px.413, align 4
  %164 = icmp slt i32 %163, 96
  br i1 %164, label %label_611, label %label_597

label_611:                                        ; preds = %label_610
  %165 = load i32, ptr %px.413, align 4
  %166 = mul i32 %165, 2048
  %167 = add nsw i32 -131072, %166
  store i32 %167, ptr %cr.421, align 4
  %168 = load i32, ptr %py.397, align 4
  %169 = mul i32 %168, 2048
  %170 = add nsw i32 -98304, %169
  store i32 %170, ptr %ci.422, align 4
  store i32 0, ptr %zr.423, align 4
  store i32 0, ptr %zi.424, align 4
  store i32 0, ptr %it.425, align 4
  br label %label_614

label_614:                                        ; preds = %label_618, %label_611
  %171 = load i32, ptr %it.425, align 4
  %172 = icmp ult i32 %171, 40
  br i1 %172, label %label_615, label %label_613

label_615:                                        ; preds = %label_614
  %173 = load i32, ptr %zr.423, align 4
  %174 = sext i32 %173 to i64
  %175 = load i32, ptr %zr.423, align 4
  %176 = sext i32 %175 to i64
  %177 = mul i64 %174, %176
  %178 = ashr i64 %177, 16
  %179 = trunc i64 %178 to i32
  store i32 %179, ptr %zr2.426, align 4
  %180 = load i32, ptr %zi.424, align 4
  %181 = sext i32 %180 to i64
  %182 = load i32, ptr %zi.424, align 4
  %183 = sext i32 %182 to i64
  %184 = mul i64 %181, %183
  %185 = ashr i64 %184, 16
  %186 = trunc i64 %185 to i32
  store i32 %186, ptr %zi2.427, align 4
  %187 = load i32, ptr %zr2.426, align 4
  %188 = load i32, ptr %zi2.427, align 4
  %189 = add i32 %187, %188
  %190 = icmp sgt i32 %189, 262144
  br i1 %190, label %label_616, label %label_617

label_613:                                        ; preds = %label_616, %label_614
  %191 = load i32, ptr %total.395, align 4
  %192 = load i32, ptr %it.425, align 4
  %193 = add i32 %191, %192
  store i32 %193, ptr %total.395, align 4
  br label %label_612

label_616:                                        ; preds = %label_615
  br label %label_613

label_617:                                        ; preds = %label_615
  %194 = load i32, ptr %zr.423, align 4
  %195 = sext i32 %194 to i64
  %196 = load i32, ptr %zi.424, align 4
  %197 = sext i32 %196 to i64
  %198 = mul i64 %195, %197
  %199 = ashr i64 %198, 15
  %200 = trunc i64 %199 to i32
  %201 = load i32, ptr %ci.422, align 4
  %202 = add i32 %200, %201
  store i32 %202, ptr %zi.424, align 4
  %203 = load i32, ptr %zr2.426, align 4
  %204 = load i32, ptr %zi2.427, align 4
  %205 = sub i32 %203, %204
  %206 = load i32, ptr %cr.421, align 4
  %207 = add i32 %205, %206
  store i32 %207, ptr %zr.423, align 4
  %208 = load i32, ptr %it.425, align 4
  %209 = add i32 %208, 1
  store i32 %209, ptr %it.425, align 4
  br label %label_618

label_618:                                        ; preds = %label_617
  br label %label_614

label_612:                                        ; preds = %label_613
  %210 = load i32, ptr %px.413, align 4
  %211 = add nsw i32 %210, 1
  store i32 %211, ptr %px.413, align 4
  br label %label_610

label_596:                                        ; preds = %label_597
  %212 = load i32, ptr %py.397, align 4
  %213 = add nsw i32 %212, 1
  store i32 %213, ptr %py.397, align 4
  br label %label_594

label_564:                                        ; preds = %label_565
  %214 = load i32, ptr %_.396, align 4
  %215 = add nsw i32 %214, 1
  store i32 %215, ptr %_.396, align 4
  br label %label_562
}
```

## Appendix F: the runtime and backend pieces that shape the code

### runtime/freestanding/panic.c (linked into every freestanding image)
```c
// The failure half of the runtime, with no C library under it.
//
// A program built with `--freestanding` does not link the installed runtime,
// because the installed runtime is libc code: its failure paths call `fprintf`
// and `exit`. Generated code still calls the same functions when something
// goes wrong, so a freestanding program has to define them. These are those, each
// reduced to one call: `prismio_panic_hook`, which the program provides.
//
// `--freestanding` adds it to the build. It includes nothing, so it needs no sysroot
// and no headers. **Every function here is weak**, so a program may define any of
// them itself -- a different message, a trap into a debugger -- and the program's
// definition wins without a duplicate-symbol error.
//
// The signatures are the ones in lang_runtime.c and the ones codegen declares
// (`ir_checked_binop` in llvm-api-backend.c for the first). Change one place and
// the other builds a call that passes the wrong arguments, and nothing at link
// time says so.

// Where a freestanding program says it cannot go on: print to a serial port, halt
// the cores, reboot. It must not return. `kind` and `detail` are string literals
// (`detail` may be empty), `file` is the source file and may be empty, and `line`
// and `col` are 1-based; `col` is 0 where the failure site has none.
//
// Weak, with a default that stops the machine and says nothing, so that a program
// which never fails does not have to define it. A kernel should define it.
__attribute__((weak, noreturn)) void
prismio_panic_hook(const char* kind, const char* detail, const char* file,
                   int line, int col) {
    (void)kind; (void)detail; (void)file; (void)line; (void)col;
    for (;;) {}
}

// A checked `+`, `-` or `*` that wrapped (`--overflow-checks`).
__attribute__((weak)) void prismio_overflow_trap(const char* op, const char* file, int line) {
    prismio_panic_hook("integer overflow", op, file, line, 0);
}

// A range `for` whose computed step was zero or negative.
__attribute__((weak)) void prismio_step_check(int step, const char* file, int line) {
    if (step > 0) return;
    prismio_panic_hook("range step must be positive", "", file, line, 0);
}

__attribute__((weak)) void prismio_panic(const char* message, const char* file, int line, int col) {
    prismio_panic_hook("panic", message, file, line, col);
}

__attribute__((weak)) void prismio_unreachable(const char* message, const char* file, int line, int col) {
    prismio_panic_hook("entered unreachable code", message, file, line, col);
}

// `source` is the assertion's source text, used when the program gave no message.
__attribute__((weak)) void prismio_assert_failed(const char* message, const char* source,
                           const char* file, int line, int col) {
    prismio_panic_hook("assertion failed",
                       (message && *message) ? message : source, file, line, col);
}

// The checked unwrap behind `expect(x)`: its argument, or a panic if it is null.
__attribute__((weak)) void* prismio_expect(void* p) {
    if (!p) prismio_panic_hook("expect() called on a `none` value", "", "", 0, 0);
    return p;
}

// A DataView conversion or access that failed (the hosted runtime's are in
// program_support.c, which a freestanding program does not link).
__attribute__((weak, noreturn)) void data_view_fail(const char* message) {
    prismio_panic_hook("invalid DataView conversion", message, "", 0, 0);
}

__attribute__((weak, noreturn)) void data_view_access_fail(int reason) {
    data_view_fail(reason == 1 ? "view is not ready for access" : "element index out of range");
}

// An index out of range (docs/MEMORY_SAFETY_PLAN.md section 2). An array's check is
// inline in any program, which may link no runtime at all, so its failure is here; a
// Vec's is too, for symmetry, though only a program that merged the runtime has a Vec
// and that runtime defines the strong one.
__attribute__((weak, noreturn)) void array_index_fail(int index, int len) {
    (void)index; (void)len;
    prismio_panic_hook("index out of range", "array", "", 0, 0);
}

__attribute__((weak, noreturn)) void list_index_fail(int index, int len) {
    (void)index; (void)len;
    prismio_panic_hook("index out of range", "Vec", "", 0, 0);
}

// The allocator the freestanding runtime and std.mem allocate through. A program
// that uses `Vec`, `String` or std.mem defines all three -- in Prismio with
// `export fn`, or in C -- and the defaults here stop the machine, so one that
// never allocates defines none. None of them may return null: a kernel decides
// what running out of memory means, here, once.
__attribute__((weak)) void* prismio_alloc(unsigned long size) {
    (void)size;
    prismio_panic_hook("no allocator", "define prismio_alloc, prismio_realloc and prismio_free", "", 0, 0);
}

__attribute__((weak)) void* prismio_realloc(void* p, unsigned long size) {
    (void)p; (void)size;
    prismio_panic_hook("no allocator", "define prismio_alloc, prismio_realloc and prismio_free", "", 0, 0);
}

__attribute__((weak)) void prismio_free(void* p) {
    (void)p;
    prismio_panic_hook("no allocator", "define prismio_alloc, prismio_realloc and prismio_free", "", 0, 0);
}
```

### How a bounds check is emitted (runtime/llvm-api-backend.c)
```c
static void bounds_or_fail(LLVMValueRef idx, LLVMValueRef len, const char *fail_name) {
    LLVMTypeRef i32 = LLVMInt32TypeInContext(g_ctx);
    LLVMValueRef in_bounds = LLVMBuildICmp(g_builder, LLVMIntULT, idx, len, "");
    int ok = ir_get_label();
    int fail = ir_get_label();
    LLVMBuildCondBr(g_builder, in_bounds, block_for(ok), block_for(fail));
    LLVMPositionBuilderAtEnd(g_builder, block_for(fail));
    LLVMTypeRef params[2] = {i32, i32};
    LLVMTypeRef fnty = LLVMFunctionType(LLVMVoidTypeInContext(g_ctx), params, 2, 0);
    LLVMValueRef fn = LLVMGetNamedFunction(g_module, fail_name);
    if (!fn) {
        fn = LLVMAddFunction(g_module, fail_name, fnty);
        const char *attrs[3] = {"noreturn", "cold", "nounwind"};
        for (int i = 0; i < 3; i++) {
            unsigned kind = LLVMGetEnumAttributeKindForName(attrs[i], strlen(attrs[i]));
            LLVMAddAttributeAtIndex(fn, LLVMAttributeFunctionIndex,
                                    LLVMCreateEnumAttribute(g_ctx, kind, 0));
        }
    }
    LLVMValueRef args[2] = {idx, len};
    LLVMBuildCall2(g_builder, fnty, fn, args, 2, "");
    LLVMBuildUnreachable(g_builder);
    LLVMPositionBuilderAtEnd(g_builder, block_for(ok));
}

static void list_bounds_or_fail(LLVMValueRef idx, LLVMValueRef len) {
    bounds_or_fail(idx, len, "list_index_fail");
}

// `index` into an array of `length` elements, a constant for an `Array<T, N>`: in range,
// or the program stops (array_index_fail). Codegen calls this only where the loop's range
// proof does not already cover the access.
void ir_array_index_check(const char *index, const char *length) {
    if (block_done()) return;
    bounds_or_fail(resolve_value(index, "i32"), resolve_value(length, "i32"), "array_index_fail");
}

int ir_list_flat_elem(const char *list, const char *index, int stride,
                      const char *guard, int check_bounds) {
    LLVMTypeRef ptrty = LLVMPointerTypeInContext(g_ctx, 0);
    if (block_done()) return intern_value(LLVMConstNull(ptrty));

    LLVMTypeRef i8 = LLVMInt8TypeInContext(g_ctx);
    LLVMTypeRef i32 = LLVMInt32TypeInContext(g_ctx);
    LLVMTypeRef i64 = LLVMInt64TypeInContext(g_ctx);
```

### LLVM options set once per process (runtime/llvm-api-backend.c)
```c
    static char args_copy[1024];
    const char *argv[34] = { "prismio", "-enable-nontrivial-unswitch" };
    int argc = 2;
    const char *extra = getenv("PRISMIO_LLVM_ARGS");
    // LLVM 23's AArch64 backend lowers a branch on two `and`/`or`-ed conditions as
    // one branch on both computed together, unless its cost model says split. With
    // one condition a single bit test it still merged, so `if (bit == 0 and h != t)`
    // cost `ubfx; cmp; csinc; tbnz` on every pass instead of `tbnz` alone half the
    // time; LLVM 22, and so rustc, split it. A bias of 8 (default 6) splits that
    // shape and nothing else in the freestanding suite: ring_buffer 4,429,696 ->
    // 3,753,472 instructions, Rust's count. On the hosted suite 11 of 140 functions
    // change and the timings do not (geomean 0.999, an identical-binary control
    // 1.001), nor does compiling the compiler (+0.1% cycles, inside its spread).
    // An option LLVM sees twice is an error, so PRISMIO_LLVM_ARGS may override it.
    if (!extra || !strstr(extra, "aarch64-br-merging-cbz-tbnz-bias")) {
        argv[argc++] = "-aarch64-br-merging-cbz-tbnz-bias=8";
    }
    // A freestanding target's CPU is usually `generic`, whose scheduling model has no
    // loop buffer, and LLVM's cost model unrolls nothing partially without one -- clang
    // and rustc included. Partial unrolling (a trip count known at compile time), at
    // most 4 copies: the freestanding suite's instruction counts fall to a geomean of
    // 0.914 with no workload worse (edit_distance 5.54M -> 4.20M, matrix_multiply 0.69,
    // sha256 0.70) and .text grows from 17.2 to 29.5 KB. Runtime unrolling went further
    // (0.853) but cost fibonacci 31%: a loop of a few trips pays the trip-count prologue
    // on every entry. A function built for size (-Os, -Oz) keeps LLVM's zero
    // size threshold and is not unrolled.
    if (g_freestanding && (!extra || !strstr(extra, "unroll-allow-partial"))) {
        argv[argc++] = "-unroll-allow-partial";
    }
    if (g_freestanding && (!extra || !strstr(extra, "unroll-max-count"))) {
        argv[argc++] = "-unroll-max-count=4";
    }
    if (extra && *extra) {
        snprintf(args_copy, sizeof(args_copy), "%s", extra);
        for (char *tok = strtok(args_copy, " \t"); tok && argc < 34; tok = strtok(NULL, " \t")) {
            argv[argc++] = tok;
        }
    }
    LLVMParseCommandLineOptions(argc, argv, NULL);
    done = 1;
}

// ---------------------------------------------------------------------------
// Parallel machine-code emission.
//
```

### The optimisation pipeline (runtime/llvm-api-backend.c)
```c
    // PRISMIO_SAVE_IR=<file> writes the module the pipeline is about to run on:
    // the whole program, libraries merged. A measurement switch, for timing
    // `opt` and `llc` stages on exactly what a build compiles.
    const char *save_ir = getenv("PRISMIO_SAVE_IR");
    if (save_ir && *save_ir && LLVMPrintModuleToFile(m, save_ir, &err) != 0) {
        fprintf(stderr, "warning: PRISMIO_SAVE_IR: %s\n", err ? err : "?");
        if (err) { LLVMDisposeMessage(err); err = NULL; }
    }

    // globaldce first, so nothing unreachable from `main` is optimised at all.
    if (internalize) internalize_executable(m);
    if (opt_level >= IR_OPT_SIZE) mark_functions_for_size(m, opt_level == IR_OPT_MIN_SIZE);
    int failed = 0;
    double t_opt = emit_trace_ms();
    // Split only a program that will be partitioned: counted after globaldce,
    // before optimisation, which is the larger of the two counts.
    int split = split_pipeline_enabled(opt_level);
    if (split && internalize) {
        LLVMPassBuilderOptionsRef options = LLVMCreatePassBuilderOptions();
        LLVMErrorRef perr = LLVMRunPasses(m, "globaldce", tm, options);
        LLVMDisposePassBuilderOptions(options);
        if (perr) {
            LLVMConsumeError(perr);
            split = 0;
        }
    }
    if (split) split = codegen_partition_count(m, opt_level) > 1;
    if (!split) {
        // cc1's pipeline tuning at -O2 and above: unrolling and interleaving on,
        // both vectorizers on. SLP is the one PipelineTuningOptions defaults off.
        // -Os and -Oz count as -O2 here, as in clang, except that -Oz leaves the
        // loop vectorizer off (shouldEnableVectorizerAtOLevel).
        char pipeline[48];
        snprintf(pipeline, sizeof(pipeline), "%sdefault<%s>",
                 internalize ? "globaldce," : "", pipeline_level(opt_level));
        LLVMPassBuilderOptionsRef options = LLVMCreatePassBuilderOptions();
        int vectorize = opt_level >= 2;
        LLVMPassBuilderOptionsSetLoopUnrolling(options, vectorize);
        LLVMPassBuilderOptionsSetLoopInterleaving(options, vectorize);
        LLVMPassBuilderOptionsSetLoopVectorization(options, vectorize && opt_level != IR_OPT_MIN_SIZE);
        LLVMPassBuilderOptionsSetSLPVectorization(options, vectorize);
        LLVMErrorRef perr = LLVMRunPasses(m, pipeline, tm, options);
        LLVMDisposePassBuilderOptions(options);
        if (perr) {
            char *msg = LLVMGetErrorMessage(perr);
            fprintf(stderr, "ERROR: the optimisation pipeline failed: %s\n", msg ? msg : "?");
            LLVMDisposeErrorMessage(msg);
            failed = 1;
        }
    }
#ifdef PRISMIO_LLVM_BRIDGE
    else {
        char error[512];
        failed = run_pipeline_half(m, tm, "", opt_level, 1, error, sizeof(error));
        if (failed) fprintf(stderr, "ERROR: the optimisation pipeline failed: %s\n", error);
```

### The shared harness (compiled with -O2 -fno-builtin, linked into every arm)
```c
// The harness every freestanding arm links: boot, timing, output and exit.
//
// It is the same object file for C, Rust and Prismio, built once by one compiler
// with one set of flags, so the only code that differs between arms is the
// benchmarks themselves. Each arm provides `u32 bench_<name>(u32 scale)` for every
// workload in benchmarks.json (the list arrives as workloads.h, which run.py
// writes from that file), and nothing else.
//
// **What is measured.** QEMU runs with `-icount shift=0`, which makes the guest's
// virtual clock advance one nanosecond per instruction executed. The generic timer
// counts that clock at 62.5 MHz, so one tick is exactly 16 instructions, and the
// count is the same on every run on every machine: there is no noise to take a
// median of. `CNTVCT_EL0` is read around each workload and the difference is the
// number of guest instructions it took, to the nearest 16.
//
// It is an instruction count and not a time. It does not model a cache, a
// pipeline or a branch predictor, and a workload whose cost is mostly memory
// stalls costs more on real silicon than its count says. What it does show,
// without noise, is how much code each compiler asked the machine to run.

typedef unsigned char u8;
typedef unsigned int u32;
typedef unsigned long u64;

#include "workloads.h"

#define X(name, scale) extern u32 bench_##name(u32 scale_);
WORKLOADS(X)
#undef X

#define UART0 ((volatile u32*)0x09000000UL)

// QEMU `virt` gives a cleared RAM, so there is no .bss to zero. The stack is
// named by the linker script and is large because the sieve and the matrices
// keep their arrays in the frame.
extern char __stack_top[];

__attribute__((naked, section(".text.boot"))) void _start(void) {
    __asm__ volatile(
        "adrp x0, __stack_top\n"
        "add  x0, x0, :lo12:__stack_top\n"
        "mov  sp, x0\n"
        "bl   harness_main\n"
        "1: wfi\n"
        "b 1b\n");
}

static void put(char c) { *UART0 = (u32)c; }

static void put_str(const char* s) {
    while (*s) put(*s++);
}

static void put_u64(u64 v) {
    char digits[24];
    int n = 0;
    if (v == 0) digits[n++] = '0';
    while (v) { digits[n++] = (char)('0' + v % 10); v /= 10; }
    while (n) put(digits[--n]);
}

static inline u64 ticks(void) {
    u64 v;
    // The barrier keeps the read from moving across the call it brackets.
    __asm__ volatile("isb\nmrs %0, cntvct_el0" : "=r"(v) : : "memory");
    return v;
}

// ARM semihosting SYS_EXIT, which QEMU turns into its own exit status.
static void exit_emulator(int status) {
    static u64 block[2];
    block[0] = 0x20026;
    block[1] = (u64)status;
    register u64 op __asm__("x0") = 0x18;
    register u64 arg __asm__("x1") = (u64)block;
    __asm__ volatile("hlt #0xf000" : : "r"(op), "r"(arg) : "memory");
}

// One line per workload: `bench <name> <ticks> <result>`.
void harness_main(void) {
    put_str("harness ready\n");
#define X(name, scale)                                       \
    {                                                        \
        u64 start = ticks();                                 \
        u32 result = bench_##name(scale * BENCH_SCALE);      \
        u64 stop = ticks();                                  \
        put_str("bench " #name " ");                         \
        put_u64(stop - start);                               \
        put(' ');                                            \
        put_u64(result);                                     \
        put('\n');                                           \
    }
    WORKLOADS(X)
#undef X
    put_str("done\n");
    exit_emulator(0);
}

// The memory functions the compilers emit calls to. Every freestanding program
// has to provide them, and these are shared, so the arms differ in how often they
// are called and not in what they cost. That only holds if they are not the
// bottleneck: a byte loop here made a loop that one compiler turns into a call
// (and another leaves inline) read as a 2x difference in the compilers, so these
// move a word at a time.
//
// Strict alignment is the constraint (the MMU is off, so an unaligned access
// faults): a word is moved only when both pointers sit at the same offset in it,
// after the bytes before the first aligned address. `Int` arrays are only
// 4-aligned, so there is a 4-byte tier under the 8-byte one. `may_alias` because
// the bytes being moved have some other type. -fno-builtin keeps the loops from
// being recognised as memcpy and calling themselves.
typedef u64 __attribute__((may_alias)) word8;
typedef u32 __attribute__((may_alias)) word4;

// 64 bytes a pass, one end-pointer compare for the loop: on a 4-aligned stream that
// is 16 pair loads and stores and three instructions of bookkeeping, about five per
// 16 bytes, and no compare-and-subtract chain carries between passes. COPY8 moves
// eight words; a pass is one of them for 8-byte words and two for 4-byte ones.
#define COPY8(W, d, s, at)                                                 \
    {                                                                      \
        W v0 = ((const W*)(s))[(at) + 0], v1 = ((const W*)(s))[(at) + 1];  \
        W v2 = ((const W*)(s))[(at) + 2], v3 = ((const W*)(s))[(at) + 3];  \
        W v4 = ((const W*)(s))[(at) + 4], v5 = ((const W*)(s))[(at) + 5];  \
        W v6 = ((const W*)(s))[(at) + 6], v7 = ((const W*)(s))[(at) + 7];  \
        ((W*)(d))[(at) + 0] = v0; ((W*)(d))[(at) + 1] = v1;                \
        ((W*)(d))[(at) + 2] = v2; ((W*)(d))[(at) + 3] = v3;                \
        ((W*)(d))[(at) + 4] = v4; ((W*)(d))[(at) + 5] = v5;                \
        ((W*)(d))[(at) + 6] = v6; ((W*)(d))[(at) + 7] = v7;                \
    }

#define COPY_FORWARD(W, d, s, count)                                       \
    {                                                                      \
        while (((u64)(d) & (sizeof(W) - 1)) && (count)) {                  \
            *(d)++ = *(s)++;                                               \
            (count)--;                                                     \
        }                                                                  \
        const u8* stop = (s) + ((count) & ~(unsigned long)63);             \
        (count) &= 63;                                                     \
        while ((s) != stop) {                                              \
            COPY8(W, d, s, 0)                                              \
            if (sizeof(W) == 4) COPY8(W, d, s, 8)                          \
            (d) += 64; (s) += 64;                                          \
        }                                                                  \
        for (; (count) >= sizeof(W); (count) -= sizeof(W)) {               \
            *(W*)(d) = *(const W*)(s);                                     \
            (d) += sizeof(W); (s) += sizeof(W);                            \
        }                                                                  \
    }

void* memset(void* dest, int value, unsigned long count) {
    u8* d = (u8*)dest;
    u8 byte = (u8)value;
    while (((u64)d & 7) && count) { *d++ = byte; count--; }
    u64 word = byte * 0x0101010101010101UL;
    for (; count >= 32; count -= 32, d += 32) {
        ((word8*)d)[0] = word; ((word8*)d)[1] = word;
        ((word8*)d)[2] = word; ((word8*)d)[3] = word;
    }
    for (; count >= 8; count -= 8, d += 8) *(word8*)d = word;
    while (count--) *d++ = byte;
    return dest;
}

void* memcpy(void* dest, const void* src, unsigned long count) {
    u8* d = (u8*)dest;
    const u8* s = (const u8*)src;
    if ((((u64)d ^ (u64)s) & 7) == 0) COPY_FORWARD(word8, d, s, count)
    else if ((((u64)d ^ (u64)s) & 3) == 0) COPY_FORWARD(word4, d, s, count)
    while (count--) *d++ = *s++;
    return dest;
}

void* memmove(void* dest, const void* src, unsigned long count) {
    u8* d = (u8*)dest;
    const u8* s = (const u8*)src;
    if (d < s || d >= s + count) return memcpy(dest, src, count);
    // Overlapping with the destination above the source: copy from the end.
    for (unsigned long i = count; i > 0; i--) d[i - 1] = s[i - 1];
    return dest;
}

int memcmp(const void* a, const void* b, unsigned long count) {
    const u8* x = (const u8*)a;
    const u8* y = (const u8*)b;
    for (unsigned long i = 0; i < count; i++) {
        if (x[i] != y[i]) return (int)x[i] - (int)y[i];
    }
    return 0;
}
```

### Linker script
```ld
/* QEMU `virt`: RAM at 0x40000000, the image where its -kernel loader puts it. The
   stack is 1 MiB, and the scratch regions the hardware workloads use start at
   0x44000000, well clear of both. */
ENTRY(_start)

SECTIONS {
    . = 0x40080000;
    .text   : { *(.text.boot) *(.text .text.*) }
    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data .data.*) }
    .bss    : { *(.bss .bss.*) *(COMMON) }
    . = ALIGN(16);
    . += 0x100000;
    __stack_top = .;
}
```
