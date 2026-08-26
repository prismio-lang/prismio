# M5.1 — allocator evaluation

**Status: GREEN, allocator change rejected, 2026-08-26.** macOS system malloc
remains Prismio's allocator. Direct mimalloc v3.4.5 has a **1.021×** corpus
median loop ratio and raises peak RSS by a median **24.2%**. Direct rpmalloc
v1.4.5 has no meaningful loop win (**1.003×**) and raises peak RSS by a median
**62.7%**. Neither dependency is retained.

Raw evidence:

- [`results-m5-mimalloc-v3.4.5-interpose.json`](results-m5-mimalloc-v3.4.5-interpose.json)
- [`results-m5-mimalloc-v3.4.5-direct.json`](results-m5-mimalloc-v3.4.5-direct.json)
- [`results-m5-rpmalloc-v1.4.5-direct.json`](results-m5-rpmalloc-v1.4.5-direct.json)
- [`results-m5-allocator-gate.json`](results-m5-allocator-gate.json)
- [`xlang/results-m5-allocator.json`](xlang/results-m5-allocator.json)

## Question and acceptance rule

After automatic arenas and inline flat list elements, g1/g3/g4/g5 still make
10.7–21.3× as many timed-window allocations as idiomatic Rust. M5.1 asked
whether a current small-object allocator could reduce that remaining cost.

The allocator had to be accepted per program, not by hiding losses in a corpus
median. A dependency required a meaningful runtime win without an unjustified
RSS increase. Equal checksums and a clean allocation ledger were mandatory.

## Research choice

[mimalloc's official documentation](https://github.com/microsoft/mimalloc/blob/main3/readme.md)
recommends its explicit `mi_malloc` API for integrated runtimes and identifies
Koka and Lean as its original runtime-system users. The underlying design is
page-local free-list sharding with bounded fast paths
([Leijen, Zorn, and de Moura, APLAS 2019](https://www.microsoft.com/en-us/research/wp-content/uploads/2019/06/mimalloc-tr-v1.pdf)).
That made current mimalloc the first candidate.

When it lost, rpmalloc was the one justified follow-up. Its
[official design documentation](https://github.com/mjansson/rpmalloc)
identifies same-thread allocation/free ownership as an optimal case, which is
the shape of all four single-threaded corpus programs. It also has a direct C
API and one implementation translation unit. Its own current benchmark record
warns that its throughput group trades peak memory for page geometry and
retention
([official benchmark notes](https://github.com/mjansson/rpmalloc/blob/develop/BENCHMARKS.md));
the local result reproduces that tradeoff.

snmalloc was not tested. Its documented differentiators are lock-free remote
deallocation and batching across threads
([official repository](https://github.com/microsoft/snmalloc)); this corpus has
neither cross-thread frees nor allocator concurrency. Testing it here would not
measure the mechanism that distinguishes it. The standing TODO to add a
concurrent corpus program remains the prerequisite for that question.

## Method

The official mimalloc v3.4.5 tag and rpmalloc v1.4.5 release were checked out
under `/private/tmp`, outside the repository. Both were built as non-overriding
static libraries. No preload, malloc-zone replacement, or libc symbol override
was active in either direct experiment.

A temporary build-time seam changed both halves of every owned pairing:

1. generated object allocation/release used `mi_malloc`/`mi_free` or
   `rpmalloc`/`rpfree` through the backend's existing allocator-name seam;
2. `rt_base_alloc`/`rt_free` used the same allocator for strings, lists, RC,
   cycles, DataView storage, and owned program-support returns;
3. the curated inline-runtime module was compiled with the same selection and
   a distinct cache key, so an inlined list body could not bypass the arm;
4. verifier shims kept their ledger metadata on libc but placed the audited
   user allocation on the selected allocator;
5. rpmalloc's direct API was initialized once at program entry.

The first smoke implementation changed only the runtime macros and aborted on
g1. Generated boxed objects still came from `malloc`, while list teardown sent
them to the alternate `rt_free`. That failure is the discriminator proving why
the generated and runtime seams must move together; it was corrected before
any timing was accepted.

Each runtime result is 25 runs in ABBA order after one warm-up per arm. The
system and alternate executables came from the same Prismio source and differed
only in allocator symbol selection and the linked allocator implementation.
The harness checked output before timing. Warm and `PRISMIO_OBJ_CACHE=0`
compile measurements use five ABBA samples per arm. A separate `--verify` build
records whole-process allocation/free counts without using an interposer.

## Initial dynamic-interposition result

The reconnaissance pass interposed the official mimalloc v3.4.5 dylib over one
unchanged executable. It was insufficient to decide M5.1 because it replaced
the whole process and could include override overhead, but it set the prior:

| program | mimalloc/system loop | RSS ratio |
|---|---:|---:|
| g1 | 0.964× | 1.354× |
| g3 | 1.002× | 1.344× |
| g4 | 1.010× | 1.29× |
| g5 | 1.035× | 1.43× |

Corpus loop median: **1.006×**. Direct calls were required before drawing a
conclusion.

## Direct mimalloc result

| program | system loop ms | mimalloc loop ms | loop ratio | wall ratio | RSS ratio | p999 ratio |
|---|---:|---:|---:|---:|---:|---:|
| g1 | 22.338 | 22.082 | **0.989×** | 0.981× | **1.239×** | 0.970× |
| g3 | 49.768 | 50.655 | **1.018×** | 1.009× | **1.244×** | 1.000× |
| g4 | 67.624 | 69.320 | **1.025×** | 1.016× | **1.218×** | 1.021× |
| g5 | 50.756 | 52.944 | **1.043×** | 1.042× | **1.320×** | 1.035× |

Corpus medians: loop **1.021×**, wall **1.012×**, RSS **1.242×**. g1's 1.1%
loop improvement is below the established noise band and is accompanied by a
23.9% RSS increase. The other three programs lose.

Warm compile-time ratio is **1.006×** median and cache-disabled compile-time
ratio is **0.996×** median: no material compile effect. Static linkage adds
188,608–188,624 bytes to g1/g3/g4 and 172,112 bytes to g5.

Verifier counts are identical between system and mimalloc:

| program | allocated | released | leaked | violations |
|---|---:|---:|---:|---:|
| g1 | 10,026 | 10,026 | 0 | 0 |
| g3 | 15,489 | 15,489 | 0 | 0 |
| g4 | 13,076 | 13,076 | 0 | 0 |
| g5 | 8,097 | 8,097 | 0 | 0 |

## Direct rpmalloc result

| program | system loop ms | rpmalloc loop ms | loop ratio | wall ratio | RSS ratio | p999 ratio |
|---|---:|---:|---:|---:|---:|---:|
| g1 | 22.263 | 22.193 | **0.997×** | 0.992× | **1.619×** | 1.052× |
| g3 | 49.653 | 49.592 | **0.999×** | 0.999× | **1.634×** | 1.027× |
| g4 | 67.780 | 68.264 | **1.007×** | 1.006× | **1.602×** | 0.987× |
| g5 | 50.242 | 51.189 | **1.019×** | 1.015× | **1.692×** | 1.016× |

Corpus medians: loop **1.003×**, wall **1.003×**, RSS **1.627×**. No program
has a meaningful runtime win; g4 and g5 lose, while every program pays 60–69%
more peak RSS.

Warm compile-time ratio is **0.995×** median and cache-disabled compile-time
ratio is **0.999×** median. Static linkage adds 52,496 bytes to g1/g3/g4 and
35,984 bytes to g5. Allocation/free counts are the same clean counts in the
mimalloc table.

## Rust standing

The direct harness measured idiomatic and hand-tuned Rust beside both allocator
arms. Mimalloc did not close a language gap: its loop ratios to idiomatic Rust
were g1 **1.189×**, g3 **1.113×**, g4 **3.192×**, and g5 **1.822×**. rpmalloc
read **1.197×**, **1.093×**, **3.139×**, and **1.742×** respectively. The final
unchanged-system cross-language refresh is in
[`xlang/results-m5-allocator.json`](xlang/results-m5-allocator.json).

## Final gate and decision

The temporary allocator hooks were removed after measurement. No allocator
source, library, environment switch, or production code remains. System malloc
is still the only shipped implementation.

The temporary seam compiler reached a two-generation fixed point, passed the
17-source AIF differential, and passed **166/166** tests. Both direct arms had
equal checksums and clean verifier ledgers. With system malloc selected, the
25-run old/new milestone gate was **0.998×** corpus median (range
**0.952–1.061×**), RSS **0.990–1.014×**, identical executable sizes, and equal
checksums: gate passed.

**Decision:** reject mimalloc and rpmalloc for Prismio's current corpus. The
macOS allocator is already strong on these small, single-threaded workloads;
replacement adds footprint without reducing the high allocation count. Future
work should remove or reuse allocations. Revisit an allocator only when a new
maintained workload supplies a different shape—especially concurrency or
cross-thread release—and gives that allocator's mechanism something to act on.
