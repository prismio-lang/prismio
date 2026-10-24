# A small-block allocator for Prismio

Written 2026-10-21; **stages 0-3 built 2026-10-24** (status after the staged-rollout table): the slab is the
default on 64-bit POSIX, codegen allocates through `rt_base_alloc`, and `produce(f)` reads `f`. The sections up to
"Staged rollout" are the design record as measured on the prototype; where they name `PRISMIO_ALLOC_MODE`,
`PRISMIO_PROTO_ALLOC` or the recycler, those are gone from the tree (Git history has them). The question came out of `docs/GRAPH_CHURN_FINDINGS.md`: after the ownership fixes the
four `graph_churn_*` arms are 1.24x-1.48x of C++, a `sample` profile puts about half of `graph_churn_alloc` in
libsystem_malloc (`_xzm_free_main`, `_xzm_xzone_malloc_tiny`), and the arm makes 1.68M allocations to C++'s ~0.8M.

## Recommendation

**Build option (a): an address-range slab with per-thread caches, and send codegen's object allocation through
`rt_base_alloc`.** The prototype takes the four graph arms from 1.24x-1.48x of C++ to 0.83x-1.01x, the full hosted
suite shows no regression it can be blamed for, 642 of the 644 compiler tests pass with it on (one fails without it
too, the other reads `@malloc` in IR), and the compiler compiles itself under it to byte-identical IR. The sections
after the prototype turn it into a production architecture (research, layers, migration by case, staged rollout, test
plan); the prototype is its measured core.

It is not free. It changes the invariant `C_CODE_STYLE.md` states ("a block from `rt_base_alloc` and a block from
plain `malloc` are interchangeable in both directions"): **one direction stops holding.** A slab block handed to
libc `free` is corruption. The prototype found **42 call sites that do exactly that today** (all in the compiler's
own native driver, none in a program's runtime), so stage 0 of the rollout is a prerequisite, and the rest of the invariant
list is further down. Option (b) gets about 60% of the single-threaded gain and none of the cross-thread one; (c) leaves
the gap.

| | graph_churn_single | graph_churn_alloc | graph_churn_transfer | graph_churn_full |
| --- | ---: | ---: | ---: | ---: |
| today (c) | 22.6 ms, 1.29x C++ | 49.8 ms, 1.46x | 36.3 ms, 1.29x | 107.1 ms, 1.36x |
| (b) lift the cap, codegen via `rt_base_alloc` | 19.4 ms, 1.10x | 34.2 ms, 1.00x | 36.2 ms, 1.29x | 88.9 ms, 1.13x |
| (b), ceiling: size header, no `malloc_size` | 17.7 ms, 1.01x | 28.5 ms, 0.83x | 35.5 ms, 1.26x | 81.9 ms, 1.04x |
| **(a) slab** | **17.4 ms, 0.99x** | **28.4 ms, 0.83x** | **28.5 ms, 1.01x** | **76.6 ms, 0.97x** |
| C++ / Rust | 17.6 / 17.2 | 34.1 / 33.0 | 28.2 / 23.7 | 78.8 / 74.0 |

Apple silicon, median of 15 (b rows: 9), interleaved, the prototype's harness (below). Ratios are against the C++ median in the
final 15-run row. The (b) ceiling row is *unsound by construction* (a header in front of every block breaks the
interchangeability the design exists to keep); it is the best a sized free could do, not a proposal.

The slab beats C++ and Rust by 17% on `graph_churn_alloc` because both use the system allocator and the slab does
not: a free is a range compare and a push on a thread-local list. That is also why the lead is wider on workloads
that allocate and free without the system allocator's help (`manual_alloc_churn`, std.mem's `alloc`/`free`:
20.3 ms to 4.7 ms; `s_expression_parse` 0.68x; `csv_parse` 0.86x).

## What exists, and why it does not get there

`runtime/lang_runtime.c` has a small-block recycler for sizes up to 128 bytes: eight free lists, a total cap of
512 held blocks, switched off once any thread exists, classifying a freed block with `malloc_size` (~14 ns), and
compiled out of `--verify` builds. Codegen does not allocate through it at all: `g_alloc_fn` is libc `malloc`
(`runtime/llvm-api-backend.c`), while every release goes through `rt_free`. So the recycler only ever sees strings
and Vecs made inside the runtime, and the nodes that make up most of the graph arms never reuse a block.

Measuring each piece separately, on the same compiler:

- **Routing object allocation through the recycler, unchanged** (`p0`): 22.4 / 35.4 / 36.3 / 109.8 ms. `graph_churn_alloc`
  gets the whole of that 29% from reuse; the other three arms get nothing (the cap is 512 and every thread turns it off).
- **Lifting the cap** (`b1`, still `malloc_size` on every free): 19.4 / 34.6 / 36.2 / 88.9 ms.
- **Removing `malloc_size`** (`b3`, a header): 17.7 / 28.5 / 35.5 / 81.9 ms. So the query is about 6 ms of the 34 in
  `graph_churn_alloc`, and a sized free would be the way to remove it without a header -- but only the codegen
  object-release sites know a size; `rt_free(p)` from a list, a string or std.mem does not, so the unsized path would
  stay. It still does nothing for `graph_churn_transfer`, which frees on a different thread than it allocated.
- **The slab**: 17.2 / 28.1 / 28.3 / 76.0 ms, transfer included.

## Option (a): the design

*Where the code is:* `runtime/lang_runtime.c`, the block headed `PROTOTYPE allocators`, selected by
`-DPRISMIO_ALLOC_MODE=2` (`1` and `3` are the (b) experiments, `0` is today's recycler and the default).

- **One region per size class.** 32 classes (16, 32, ... 512 bytes) at 2 GiB each: a 64 GiB `mmap` reserved once, with
  no commit step (`MAP_NORESERVE`), asked for at `0x600000000000` as a hint. A block's class is
  `(address - base) >> 31`, so `rt_free` is `off = p - base; if (off < span) push onto class off>>31 else free(p)`:
  no header, no side table, no `malloc_size`. A class that fills its 2 GiB, a request over 512 bytes, or a refused
  reservation (`RLIMIT_AS`, strict overcommit) falls back to `malloc`, which is sound because the range check sends
  that block to `free` later.
- **The first block of each class starts at a different offset** (`class * 1088` bytes). Without it, `key_value_update`
  ran 7% slower than with `malloc` on identical code: the hot first blocks of different classes shared their low
  address bits. Measured: 1.071x with all regions aligned, 0.992x staggered. Treat the aliasing as a design input.
- **Caches.** The main thread keeps a process-local cache (a plain global, as the arena hint does, because a
  `_Thread_local` read on Darwin is a `tlv_get_addr` call -- `lang_runtime.c` already says it cost 3x on arena
  access); worker threads (`prismio_memory_worker`) use a `_Thread_local` one. Per class: a free list and a count. An
  allocation pops; a free pushes; when the count reaches 128 *and a thread exists*, the newest 64 blocks go to the
  class's shared list as one batch, and an empty cache takes a batch back. Before any thread exists nothing spills,
  so a single-threaded program never takes a lock.
- **Fresh memory** is cut lazily: an empty cache that finds no batch takes an 8 KiB window from the region and
  carves one block per allocation, so nothing is linked or touched ahead of use.
- **Shared lists** are one spinlock per class (`sched_yield` on contention), holding chains of 64 blocks plus a
  loose list for what an exiting thread leaves. A cross-thread free is just a push on the freeing thread's cache;
  the block migrates through the shared list. `graph_churn_transfer` (three threads, one allocates, another frees) runs
  at 28.5 ms against 36.3.
- **Thread exit.** `prismio_memory_thread_cleanup` (already called by every task) returns the cache to the shared lists;
  a `pthread_key` destructor is the backstop.
- **`rt_base_realloc`** keeps a block in place when it fits its class, otherwise allocates, copies and frees; a
  non-slab pointer goes to `realloc` as before.
- `PRISMIO_SLAB=0` in the environment turns the slab off at run time (every block comes from `malloc`): the
  escape hatch for a sanitizer or valgrind, which cannot see slab blocks.
- **Cost of the entry points.** `rt_base_alloc` and `rt_free` stay out of line. Letting the fast paths inline
  (`-DPRISMIO_SLAB_INLINE`) measured the same to within noise on all four arms.

*The compiler half* (`runtime/llvm-api-backend.c`): `PRISMIO_PROTO_ALLOC=rt_base_alloc` makes `ir_alloc_object` call the
seam instead of `malloc`. The comment above `g_alloc_fn` records why that was reverted once: `tree_traversal` read 0.88x
because an opaque `rt_base_alloc` clobbers everything. The prototype's answer is to say at **each call site** what LLVM
knows about `malloc` by name: `noalias` on the result, `allockind("alloc,uninitialized")`, `allocsize(0)`,
`alloc-family="malloc"` (the family `rt_free` already carries), `memory(inaccessiblemem: readwrite)`, `nounwind`,
`willreturn`. They go on the call because the runtime's definition replaces a declaration's attributes at link time.
The control, `PRISMIO_PROTO_NOATTR=1`, is what the seam costs without them: `arena_bump` 77 -> 117 ms (1.52x; the
`Arena` struct stops being promoted to registers once the allocation is opaque), and 77 ms again with them. This is
the part of the change that must not be dropped when it is made real.

## What the slab breaks, and what keeps each case sound

`C_CODE_STYLE.md`'s invariant is *symmetric* today. After the slab it is one-way: **a foreign block may reach
`rt_free`; a slab block may reach nothing but `rt_free` and `rt_base_realloc`.**

| Case | Today | With the slab | What has to change |
| --- | --- | --- | --- |
| **Plain `free()` / `realloc()` of a slab block** by this runtime's own C | works (it is a malloc block) | **corrupts or aborts.** 42 sites found | Replace with `rt_free` / `rt_base_realloc`. They are in 17 functions of `runtime/build_driver.c` (`compiler_build_executable` x11, `compile_native_source` x5, `emit_plib_section` x4, `native_clang_command` x3, `driver_link_command` x3, `compiler_emit_local_toolchain` x3, `emit_runtime_bitcode` x2, and one each in `target_clang_flags`, `run_quiet_build_command`, `merge_libraries_into_program`, `find_toolchain_entry`, `find_in_lib_dir`, `compiler_temp_path`, `compiler_run_workload`, `compiler_publish_file`, `compiler_is_current_executable`, `append_quoted_argument`) and in `ir_debug_begin` (`llvm-api-backend.c`): each frees a string that `program_support.c`'s `join_path`, `get_directory`, `current_directory` or `prismio_executable_directory` returned from `rt_base_alloc`. A slab-built compiler without this change aborts on its first build (`exit 134`). None is in the code a user program links. `rt_free` accepts both kinds, so the edit is sound with or without the slab. |
| **Plain `free()` of a slab block by foreign code** (user C, a `native{}` unit, a C library) | works | corrupts | (1) `std.mem.alloc` addresses are documented as "a block from `alloc`", freed by `mem.free`; add that a `free()` from C is not allowed, or give `mem` a `allocLibc`. (2) The `consume` contract (foreign code takes ownership) has **no in-tree use** but is the same hazard: when it is used, codegen should hand the foreign function a libc copy (`malloc` + `memcpy` + `rt_free` of the original). (3) An exported `prismio_free` for embedders (`docs/INTEROP_PLAN.md`). |
| **C-allocated memory arriving at `rt_free`** | works (`free`) | works: the range compare misses and `free(p)` runs | Nothing, and a test that releases a `strdup`'d `produce(free)` result keeps it so. Verified with an `extern fn strdup ... produce(free)` probe: the release is `call @rt_free`. |
| **`produce(free)` externs** (19 in `std/`) | all release through `rt_free`; the name `free` is not read | unchanged: the 19 return `rt_base_alloc` strings (slab) and release through `rt_free` | The audit of `program_support.c` (every one of its 32 `free()` calls frees a `malloc`/`getcwd`/`realpath` temporary) and the shim runs found none that returns a slab block to libc. **Hazard to record**: `INTEROP_PLAN.md` plans `produce(pmath_string_free)`, a *named* foreign deallocator; it must never be applied to a slab block. |
| **Arenas** | arena blocks never reach `rt_free` | unchanged: a pointer outside the slab range goes to `free`, as it would today | None. |
| **`--verify`** | the ledger replaces `rt_base_alloc`/`rt_free`; the recycler is compiled out | the slab is compiled out the same way | The ledger **never exercises the slab**, so `prismio verify` and the AIF differential cannot find a slab bug. Mitigations: `slab_stress.c` (below), and later a ledger layered over the slab as backing store. |
| **macOS** | measured | measured (every number in this file) | `MAP_NORESERVE` and a 64 GiB reservation work; 4 KiB-aliasing needs the stagger. |
| **Linux** | not run | not run. Expect: `MAP_NORESERVE` honoured except under `vm.overcommit_memory=2` or a small `RLIMIT_AS` (then `slab_state = -1`, all `malloc`, still sound); no `tlv` cost, so the process-local cache could be dropped | Needs a run on a Linux host, and the recycler comment's note on glibc's `16n+8` classes goes with the recycler. |
| **Windows** | recycler via `_msize` | **not built.** `#if` guards fall back to today's recycler | `VirtualAlloc(MEM_RESERVE)` plus commit per 1 MiB, `SRWLOCK` for the class lists, `FlsAlloc` for the exit backstop (the explicit `prismio_memory_thread_cleanup` call already covers tasks). |
| **wasm, freestanding** | `rt_base_alloc` is the program's `prismio_alloc` | the slab is compiled out (`PRISMIO_FREESTANDING`) | None. Freestanding codegen already allocates through the seam (`compile.psm:470`), so the call-site attributes help it too. |
| **Threads Prismio did not create** | single-threaded doctrine | a foreign thread running Prismio code reads `prismio_memory_worker == 0` and shares the main thread's cache: a data race | Same rule the arena hint has. An embedder must call `prismio_memory_thread_enter` on its threads. State it in `INTEROP_PLAN.md` where it already lists thread-local initialisation. |
| **Memory returned to the OS** | libc decides | never: a class's pages stay with that class. Measured on macOS, `fillAndFree` of 2M x 32, 48, 80-byte blocks: 321.7 MB peak (slab) against 323.9 MB (libmalloc), because xzone segregates by size as well | On Linux/glibc, which coalesces, this is a regression for programs that change size class. A `madvise(MADV_FREE)` pass over wholly free windows is the follow-up; not built. |
| **Sanitizers, valgrind** | see every block | cannot see slab blocks | `PRISMIO_SLAB=0`. |

Four rules in `CLAUDE.md` and `C_CODE_STYLE.md` change with it and have to be re-worded, not just remembered:
"`rt_base_alloc` and `malloc` are interchangeable" becomes the one-way rule above; "an internal temporary that this
runtime frees itself must stay on plain `malloc`/`free`" stays and gains its mirror, "a block returned from
`rt_base_alloc` is freed only by `rt_free`"; the allocator-seam paragraph that explains why codegen allocates with
libc `malloc` is superseded by the call-site attributes; and the recycler comment in `lang_runtime.c` is deleted with
the recycler.

## Toward a production allocator

The prototype above is the core fast path of a design, not the design. This section is what the allocator should be
when it ships, with the research it rests on. Claims about other allocators are from the sources listed at the end;
none of them was run here (no mimalloc, jemalloc or tcmalloc is installed on the test machine, and fetching and
building them was out of scope), so the comparisons that matter are the ones against libmalloc, in this file's own tables.

### What the state of the art agrees on

- **Fast path is a thread-local pop and push, with no atomic and no lock.** tcmalloc keeps per-CPU caches
  and uses restartable sequences on Linux so a push or pop is a single committing store [1][2]; snmalloc advertises
  two branches on `malloc`'s fast path [3]; Go's `mcache` is per-P and allocation from it takes no lock [4]. The
  prototype's fast path is the same shape and measures **2.1-3.8 ns per alloc+free pair against 10-14 ns for libmalloc**
  on this machine (`benchmarks/allocator_proto/slab_micro.c`; 48 and 256 bytes, LIFO and 64/4096-deep batches).
- **A size class owns whole pages, and a pointer finds its class without a header.** Go and tcmalloc keep a page map
  from address to span [2][4]; rpmalloc and mimalloc align spans so the span header is a mask away [5][6]. The
  prototype's region-per-class is the degenerate case; the 64 KiB-span-plus-class-table variant (`SLAB_SPANS`) costs
  the same within noise (below) and is the layout that can give a page back.
- **The cross-thread free is the hard case, and designs split on how to do it.** Hoard showed that returning a freed
  block to the thread that allocated it, or to a bounded global heap, bounds the memory blow-up of producer/consumer
  programs [7]. mimalloc shards the free list per page, with a separate atomic list for frees from other threads, so a
  remote free is one CAS and the owner reclaims it lazily [6]. rpmalloc does the same per page and states the benefit as
  producer/consumer workloads and earlier release of empty pages [5]. snmalloc batches remote frees into messages to the
  owner so that thousands cost one atomic [3]. tcmalloc moves batches through a mutex-protected transfer cache [2], and
  a Zig pull request for `SmpAllocator` adds per-slab deferred free lists so a consumer thread's frees do not squat its
  own state (I could not confirm it shipped in a release) [8]. The prototype is the tcmalloc/Zig-early shape (a batch through a per-class spinlock). It measures at parity
  with C++ on `graph_churn_transfer` and 2.3x lower in ns per pair than libmalloc in the two-thread micro-benchmark (72
  against 163 ns, queue overhead included); mimalloc's own results report tcmalloc becoming ~10x slower on one benchmark once objects migrate
  between threads [6], which is the cliff to design away from.
- **Memory goes back to the OS lazily, by span, and with an option to keep it.** mimalloc purges an empty page after a
  delay (`MIMALLOC_PURGE_DELAY`, 1000 ms in v3) [6]; jemalloc decays dirty pages to "muzzy" (`MADV_FREE`) and then
  to clean (`MADV_DONTNEED`) on a timer, optionally from background threads [9]; Go returns spans with no live objects
  to its page heap [4]; tcmalloc's page heap releases fully free runs [2]. The OS interface matters: Linux
  `MADV_DONTNEED` drops RSS at once and zero-fills on the next touch, `MADV_FREE` (Linux 4.5) lets the kernel take the
  page later and the RSS stays up until it does [10]; on macOS `MADV_FREE` leaves pages in RSS until pressure, and
  `MADV_FREE_REUSABLE` plus `MADV_FREE_REUSE` is the pairing Go uses to keep accounting honest [11]; on Windows the
  reserve/commit split is explicit, reserved address space costs no storage and `MEM_COMMIT` charges it [12].
- **Size classes are about 60-80, with a bounded waste.** tcmalloc maps requests onto 60-80 classes [2]; Go uses about 70
  up to 32 KiB [4]; rpmalloc steps 16 bytes in its small range and widens to a fixed overhead ratio above it [5].
- **Thread exit hands the cache back.** tcmalloc returns a thread cache to the middle end when the thread exits [2];
  rpmalloc releases the thread heap for reuse, automatically where a thread destructor exists [5]; mimalloc has
  `mi_thread_done` and abandons a heap whose blocks other threads still hold, to be reclaimed later [13]. jemalloc's
  changelog records post-`fork` fixes: re-initialising tcache lists and extent-growth mutexes in the child so that a
  lock held across `fork` does not deadlock it [9].
- **Arenas are a separate, first-class mode.** bumpalo is a chunked bump pointer: allocation is a capacity check and
  an increment, nothing is freed individually, `Drop` does not run for its contents, and a reset releases everything
  [14]. mimalloc's `mi_heap_destroy` frees every block of a heap at once, and jemalloc says an arena can serve as a pool
  destroyed in one operation [13][15].

### Proposed architecture

Three layers, so each platform changes only the lowest and the freestanding build can reuse the other two.

1. **Page provider** (`os_*`, one file per OS). `reserve(bytes)`, `commit(addr, n)`, `decommit(addr, n)`, `release`.
   POSIX: `mmap(PROT_NONE)` to reserve, `mprotect` to commit in 1 MiB steps (so `vm.overcommit_memory=2` and
   `RLIMIT_AS` are never asked for more than they will give: `PROT_NONE` is not charged), `madvise(MADV_DONTNEED)` on
   Linux and `MADV_FREE_REUSABLE`/`MADV_FREE_REUSE` on macOS to give pages back. Windows: `VirtualAlloc(MEM_RESERVE)`,
   `MEM_COMMIT`, `MEM_DECOMMIT` [12]. Freestanding and wasm: the program's own `prismio_alloc` or `memory.grow`
   (which never shrinks), single-threaded, no locks. One 64 GiB reservation, as measured; refusal falls back to libc.
2. **Span heap.** 64 KiB spans (the measured `SLAB_SPANS` shape; mimalloc and rpmalloc use the same size [5][6]) in
   the reservation, an address-indexed side table (1 MB for 64 GiB) giving each span's class, and, for the production
   version, per-span free count so a wholly free span can be re-classed or decommitted. Runs of spans serve objects
   over the small limit (Go: 32 KiB [4]) and hold arena chunks and big `Vec` buffers, so the allocator is one system
   with one source of pages. Size classes: 16-byte steps to 128, then four per doubling to 32 KiB (about 60), at
   most 12.5% internal waste above 128; the prototype's 32 uniform classes to 512 cover the sizes the benchmarks
   allocate (a measurement of the compiler's own string allocations found 53% were four bytes or fewer, and fused small `Vec`s run up to 336 bytes).
3. **Caches.** Per thread, a LIFO list and count per class (what the prototype measures). The central structure moves
   from "chains of blocks per class" to **spans with free lists**, as Go's `mcentral` and tcmalloc's central free list
   do [2][4]: a spill walks the returned blocks, finds each one's span from the table, and pushes it on that span's
   list, which is what makes the span count and therefore reclamation possible. The cost is a per-block lookup on the
   spill path only, which a single-threaded program never takes; this is the one structural change from the prototype,
   and it is not measured. The alternative that removes the central lock altogether is mimalloc's per-page sharding
   (local list plus an atomic remote list per page) [5][6]; it puts a counter update on every free but gives remote
   free as one CAS and thread exit as "abandon the page". Decision for stage 5 below, by measurement: keep batches unless
   the transfer arms or a consumer-heavy benchmark show the lock.

Properties to keep from the prototype: the main thread uses a process-local cache and workers a `_Thread_local` one
(Darwin's `tlv_get_addr` is a call; `lang_runtime.c` records 3x on arena access); the region base is a global so the
range test costs one load (a constant base via `MAP_FIXED_NOREPLACE` is an option where it exists); class regions or
spans are offset from each other so hot first blocks do not alias.

### Where the allocator sits among Prismio's tiers

- **T0 (frame) and `Array` storage** never reach it. **T1 (`region`/arena)** is the bump allocator already in
  `lang_runtime.c` (`ArenaChunk`, 8 KiB minimum chunks taken with libc `malloc`). It stays a bump allocator; the change
  is that chunks come from the span heap's page runs and go back to it on `arena_pop`, so a freed region is reusable
  by the small-object classes and can be decommitted. Arena blocks must still never reach `rt_free` (today an
  arena pointer there is a libc `free` of the middle of a chunk; with the range test it is a `free` of a non-slab
  pointer, the same bug, but `PRISMIO_VERIFY` could be made to catch it by tagging chunk spans).
- **T2 (owned heap with release points)** is the slab's main customer: struct boxes, fused `Vec`s, strings.
- **T3 (`rc_alloc`) and the cycle collector (`cyc_alloc`)** allocate `size + 16` with a prefix header and release the
  base pointer with `rt_free` (`lang_runtime.c`, `RC_HDR`/`CYC_HDR`): sound under the slab unchanged, because they free
  the pointer they were given, not the payload.
- **What the analysis could add later** (not in scope): the object-release sites know the type's size, so a
  `rt_free_sized(p, n)` could skip the span-table load; the thread-affinity facts the AIF already tracks could
  prove a value never crosses threads and select the cache-local free without the spill check. Both are second-order
  next to the 3-4 ns the fast path already costs.

### Changing the invariant: migration by case

The old invariant ("any block is a malloc block") is replaced by an explicit two-world rule: **blocks from the seam
(`rt_base_alloc`, codegen objects) are freed only by `rt_free`/`rt_base_realloc`; everything else is libc's, and `rt_free`
accepts both (the range test).** What moves:

| Thing | Migration |
| --- | --- |
| **`produce(free)` externs** | Today the named function is ignored and every release is `rt_free` (verified on the IR). Make the name mean something, in this order: (1) retag the 19 `std/` externs, which all return seam blocks, as `produce(rt_free)` (the grammar already takes any identifier; no seed step); (2) make codegen emit the named function, so `produce(free)` is libc's `free`, `produce(rt_free)` the seam's, and a foreign library's `produce(pmath_string_free)` its own, which is what `INTEROP_PLAN.md` already assumes; (3) a foreign pointer then never reaches `rt_free`, and the range test is only a backstop. |
| **Plain `free()` in `program_support.c`** | All 32 free libc temporaries (audited). Make it mechanical: in runtime sources poison bare `free`/`realloc` (`#pragma GCC poison`) and spell the two worlds `tmp_free` (libc) and `rt_free` (seam); the compiler then refuses a bare `free` and no shim is needed for the runtime's own code. The 42 sites in `build_driver.c` and `ir_debug_begin` become `rt_free` first. |
| **C-allocated memory arriving at `rt_free`** | Supported permanently by the range test (a handful of cycles): needed by embedders, JIT output and `strdup`-style externs even after step (2) above. |
| **`--verify`** | The ledger stays a name swap, but its storage should come from the span heap (poison on free, then quarantine the block rather than recycle it, with a mode that recycles to stress reuse), so verify runs exercise the same size classes, spans and thread caches the release build uses. Today it bypasses all of it. |
| **Arenas** | See the tier section; chunks from the page runs, never to `rt_free`. |
| **Freestanding, wasm** | Layers 2 and 3 compiled over the program's page provider, single-threaded (no TLS, no atomics, `memory.grow` as the provider). Until then they keep `prismio_alloc` behind the seam, which codegen already uses (`compile.psm:470`). |
| **Windows** | Port layer 1 (`VirtualAlloc`/`SRWLOCK`/`FlsAlloc`, or the thread-cleanup call that exists); keep the old recycler under `#if _WIN32` until it lands. |
| **Linux** | Layer 1 with `PROT_NONE` reservation; `LD_PRELOAD` shim in CI; musl and glibc both. |
| **macOS** | Measured. `MADV_FREE_REUSABLE`/`REUSE` for returned spans. |
| **`fork`** | The runtime starts processes with `posix_spawn` and `execvp` and never forks itself, so the minimal rule is a `pthread_atfork` child handler that re-initialises the class locks and drops the caches of threads that no longer exist, as jemalloc's fixes do [9]. Test it with a `fork` that allocates in the child. |
| **Threads Prismio did not create** | A documented entry rule (`prismio_memory_thread_enter`), plus a `pthread_key` destructor that registers a cache lazily on a worker's first slow path (already in the prototype). |
| **Foreign code freeing Prismio memory** | The `consume` contract hands foreign code a libc copy; `mem.alloc` addresses are freed with `mem.free` only; an exported `prismio_free`. |

### Hardening and diagnostics (optional, priced)

mimalloc's secure mode (guard pages, randomised order, encoded free lists, double-free checks) costs about 10% on its
suite [6]; the equivalent here is a build flag, off by default, with the cheap piece (a double-free check on the
spill path, which already walks the blocks) on in `--verify`. `PRISMIO_SLAB=0` stays as the escape hatch for
sanitisers, and a stats call (blocks, spans, committed, returned) belongs in the first public version because every
allocator in the sources above grew one.

## How it was checked

- **Benchmarks**: `benchmarks/allocator_proto/ab.py` builds the hosted suite once per configuration and interleaves
  the runs (`/usr/bin/time -l` for CPU and peak RSS). All 60 non-file benchmarks, 9 runs: of the 51 that run longer
  than a millisecond, geometric mean slab/base 0.938 (the first sweep, before the stagger below). The allocation-bound
  ones are the faster ones: the four graph arms, `manual_alloc_churn` 0.23x, `s_expression_parse` 0.68x, `csv_parse` 0.86x,
  `string_join` 0.96x; the other 39 are within 2.5% of base. Outliers: `gcd_lcm` 0.91x with no allocation in it, and
  `function_call_overhead` / `trie_search` at +11% / +4% medians that are equal on the minimum and in a 21-run repeat --
  a bimodal layout effect (a code-alignment shift moves `bytecode_interpreter` by 19% with identical code); `key_value_update` at +7% was real and is
  the stagger below. Checksums agree
  across slab, base, C++ and Rust on every benchmark. RSS is within 0% to 9% of base except `graph_churn_transfer`
  (2.4 -> 2.9 MB: three thread caches, 128 blocks per class).
- **Random lifetimes**, 6M `mem.alloc`/`mem.free` of 16-520 bytes into a table of 262,144 live slots (nothing frees in
  LIFO order, under 2% of requests are over the slab's 512 bytes): 0.44 s against 0.07 s, peak 82.5 MB against 79.0 MB.
- **Compiler test suite** (`tools/run_suite.py --compiler <scratch toolchain>`, `PRISMIO_PROTO_ALLOC=rt_base_alloc`
  exported): 642 of 644. Baseline with the unchanged runtime: 643 of 644, the one failure being `aif_verify`. The slab adds one:
  `channel_copies` greps the IR for `@malloc(` (line 5550 of `tests/test_runner.py`; the regex at 5500 already lists
  `rt_base_alloc`) and now sees `@rt_base_alloc(`. `aif_verify` fails identically with and without the slab (`test_273` leaks 200 where 300 is expected and `test_269` leaks 0 where 9 is; the working tree's uncommitted
  ownership changes moved them).
- **The compiler under the slab**: `tools/bootstrap.py` with `PRISMIO_ALLOC_MODE` defaulted to 2 builds a compiler whose
  runtime and Prismio code both use it. Compiling `src/main.psm` with it gives IR **byte-identical** to the baseline's
  -- but only with `benchmarks/allocator_proto/slab_free_shim.c` loaded, because without it the compiler aborts on
  the 42 `free` calls above. The shim (`DYLD_INSERT_LIBRARIES`, or `LD_PRELOAD` after porting) interposes `free`
  and `realloc`, logs once per caller when either meets a slab address, and carries on; the whole suite under it
  found only those sites, and nothing from any compiled test program. (Its `realloc` stub truncates the copy, so it is a
  detector, not something to run a real workload under: an early log of the suite showed a spurious `ums` failure from it.)
- **Concurrency**: `slab_stress.c` compiles the allocator verbatim (`extract_slab.py`) into a harness with 4 to 8 threads,
  random sizes, realloc, hand-off of live blocks between threads, three rounds of thread creation and exit, and
  pattern checks on every block. Clean under ASan and TSan; the carved total stays at 2.5-5 MB, so blocks migrate and
  are reused rather than leaking.
- **Fast-path cost** (`slab_micro.c`, one TU so the path inlines; ns per alloc+free pair, system / region-per-class /
  64 KiB spans with a class table): LIFO 48 B 13.9 / 3.8 / 2.1; LIFO 256 B 13.5 / 2.5 / 1.9; 64-deep batch 10.2 / 2.1 /
  2.3; 4096-deep batch 10.5 / 2.4 / 2.8; producer-to-consumer on two threads 163 / 72 / 69. In the real suite
  (15 runs) the span layout matches the region layout on the four graph arms (17.4 / 28.6 / 28.3 / 77.2 ms against
  17.4 / 28.7 / 28.7 / 76.3), `key_value_update` and `s_expression_parse`, and is 10% ahead on `manual_alloc_churn`
  (4.2 against 4.7 ms). So the layout that can return memory costs nothing measurable.
- **Not run**: Linux, Windows, 32-bit, `--verify` over the slab, a long soak, any program that holds more than 2 GiB
  in one size class.

## Staged rollout

Each stage ends with the compiler suite green (643 of 644 today, the one failure being the unrelated `aif_verify`
expectation), `prismio verify`, and `prismio gate`; a stage that is not byte-identical in compiler output says so and is
checked by the benchmark suite instead. No stage needs a seed refresh: none adds syntax.

| Stage | Change | Gate beyond the suite |
| --- | --- | --- |
| **0** | Replace the 42 plain `free` calls with `rt_free`; poison bare `free`/`realloc` in runtime sources behind `tmp_free`/`tmp_realloc`; make `channel_copies` accept either allocator name. Slab still off. Byte-identical compiler output. | `slab_free_shim` log empty on macOS (and Linux once ported); `check_source_lists`. |
| **1** | Retag the 19 `std/` externs `produce(rt_free)`; make codegen emit the named deallocator. `produce(free)` becomes libc's. Output identical for every program the corpus has. | `tests/` gains a `strdup` and a named-foreign-deallocator case; docs site contract page. |
| **2** | Codegen allocates through `rt_base_alloc` by default on hosted targets with the call-site attributes (`tag_alloc_callsite`); runtime still the old recycler. Output changes (`@malloc` -> `@rt_base_alloc`). | Full hosted benchmark sweep, `arena_bump` and `tree_traversal` specifically (the two the old comment feared for); compare against this file's tables. |
| **3** | Promote the prototype slab to the default for 64-bit POSIX behind `PRISMIO_SLAB`, delete the recycler and its `malloc_size` query. Region-per-class or spans: take the spans, since they cost nothing measurable. | Sweep as stage 2; `slab_stress` under ASan and TSan in the gate; suite with the slab on **and** `PRISMIO_SLAB=0` (outputs must be identical). |
| **4** | Layer 1 behind an interface (`os_reserve/commit/decommit`), `PROT_NONE` reserve, 1 MiB commit steps; Linux build and run (the first one). | A Linux CI leg; strict-overcommit and `RLIMIT_AS` runs must fall back, not fail. |
| **5** | Span free counts and the central span lists; decommit of wholly free spans after a delay; size classes to 32 KiB; arena chunks from page runs. Decide batch lists against per-page sharding by measurement. | Fragmentation tests below; RSS after phase change within 1.2x of libmalloc on Linux; no regression on stage 3's numbers. |
| **6** | `--verify` ledger over the span heap (quarantine mode and recycle mode); `fork`, thread-registration and thread-exit handlers. | AIF differential and `prismio verify` with the slab underneath; the `fork` and thread-churn tests. |
| **7** | Windows port (layer 1, `SRWLOCK`, thread cleanup); freestanding/wasm over their page providers. | The existing Windows VM replay; the freestanding QEMU suite (`icount` benchmarks must not regress). |
| **8** | Optional: sized frees, hardening flag, stats API, `MADV_FREE` tuning. | Each on its own measurement. |

**Stage 0 status (done 2026-10-21, uncommitted).** 84 call sites now release through `rt_free` (66 found by reading each `free`
argument back to its producer, which covers the 42 the shim saw at run time and the paths the suite does not take; 18
more that an instrumented run showed the reading had missed. The producers: `command_quote_arg`, `join_path`, `get_directory`, `read_file`, `prismio_executable_directory`,
`object_cache_dir`, `link_cache_path`, `native_object_entry`, `build_curated_module`, `absolute_directory`, and
`current_directory` in `ir_debug_begin`). `build_driver.c` and `program_support.c` spell every libc release
`tmp_free`/`tmp_realloc` (defined in `prismio_runtime.h`) and poison bare `free`/`realloc` after their includes; the
other runtime files (`lang_runtime.c`, `ir_symbols.c`, `aif_support.c`, `diagnostics.c`) are not converted yet because
others have uncommitted edits in them. `channel_copies` accepts `call noalias ptr @rt_base_alloc`. Checked: the compiler
built from the tree emits IR for `src/main.psm` byte-identical to before; the suite is 643 of 644 (`aif_verify`
only, as before); and a compiler built with the slab as its default and `PRISMIO_PROTO_ALLOC=rt_base_alloc` now
compiles `src/main.psm` to the same IR **without** the shim, then passes 643 of 644 under `slab_free_shim` with an
**empty log** (it logged 1,069 events before). The sweep that found the second 42 used a temporary `tmp_free` that
logged any slab address by `file:line`; it is not in the tree. A mechanical reading of arguments missed 18 of the 84
(a result passed through a ternary, an out-parameter, an array element), so the shim run remains the gate, not the
grep.

**Stage 0 finished, and stages 1-3 (2026-10-24).**

- *Stage 0.* The other runtime sources (`lang_runtime.c`, `ir_symbols.c`, `aif_support.c`, `diagnostics.c`,
  `aif_containers.c`, `llvm-api-backend.c`) spell libc's release `tmp_free`/`tmp_realloc` and poison the bare names
  (`llvm_bridge.cpp` has no `free` call; the backend keeps libc `free`'s address for the JIT as `libc_free_fn`, taken
  before the poison). Every one of their 200-odd sites frees a libc temporary. Five compiler externs returned plain
  `malloc` blocks to Prismio (`ir_get_temp_name`, `ir_get_label_name`, `compiler_default_exe_path`,
  `compiler_runtime_source_hash`, `compiler_installed_runtime_hash`); they use `rt_base_alloc` now.
  `compiler_temp_path` stays on `malloc` (15 C callers `tmp_free` it; its Prismio wrappers release through
  `rt_free`, which accepts it). The gate: a compiler built with the slab as default and objects through the seam
  compiled `src/main.psm` to IR byte-identical to HEAD's, and passed the suite (692 of 693, `aif_verify` only)
  under the shim with an **empty log**. The shim gained a positive control, `SHIM_REQUIRE_SLAB=1`, which logs
  `SLAB-NOT-MAPPED` for a process that exits without the slab range reserved: an empty log means nothing
  otherwise, and the control showed the range mapped in the compiler, in test programs and through Homebrew
  Python's children. No `LD_PRELOAD` port: there was no Linux host to test it on.
- *Stage 1.* `produce(rt_free)` on the 18 `std/` and 16 `src/` externs and `tests/owned_return_depth2.psm`;
  codegen honours any other name for a `String` by copying in at the call and calling it on the original
  (`fatAdopted`, `src/ir/expr.psm`; `ir_string_adopt` in the backend). Honouring `f` at the eventual release instead
  would mean a deallocator carried through every move, container and return. A struct or `Vec` result with a
  foreign `f` is refused (P4112); `Ptr` and scalars are never released. Output byte-identical for all 358
  programs in `tests/` and `benchmarks/hosted/` that compile, and for the 299 that do not; the stage 0 and stage
  1 compilers emit identical IR for the stage 1 `src/main.psm`. Tests: `test_350`, `neg_351`,
  `run_produce_deallocator_test`.
- *Stage 2.* `g_alloc_fn` defaults to `rt_base_alloc` and `compile.psm` sets the pair explicitly outside
  `--verify`; `PRISMIO_PROTO_ALLOC` is gone, `tag_alloc_callsite` stays, and `PRISMIO_PROTO_NOATTR` is kept as
  the measurement control. Sweep (70 benchmarks, 9 runs, recycler behind both): geometric mean 0.991,
  `graph_churn_alloc` 0.721x, `arena_bump` 0.999x, `tree_traversal` equal on the minimum. The attributes had one
  casualty: they were also on the ledger's `aif_verify_alloc`, so LLVM deleted allocations a `--verify` build
  must count (`test_269` read 4 allocated / 0 leaked for 13 / 9). They are on `rt_base_alloc` only now.
- *Stage 3.* The span layout is the only one; modes 1 and 3, the region layout, `PRISMIO_SLAB_INLINE` and the
  POSIX recycler with its `malloc_size` query are deleted. Windows keeps the `_msize` recycler (the migration
  table's rule); 32-bit and freestanding use libc. Compiler output byte-identical to stage 2 (the runtime is the
  only change). Suite 695 of 696 with the slab, 695 of 696 with `PRISMIO_SLAB=0` (the same `aif_verify`
  failure, fixed afterwards), shim log empty; `slab_stress` clean under ASan (8 threads) and TSan (4). Sweep
  against stage 2, same run: geometric mean 0.947; graph arms 17.4 / 28.4 / 28.2 / 76.1 ms, 1.01x / 0.83x /
  1.03x / 0.96x of C++ (the expected 17.4 / 28.4 / 28.5 / 76.6); against `PRISMIO_SLAB=0` on the same binary,
  0.926.

Stages 0-2 are worth doing without 3: they remove a latent bug class and the `malloc`/`rt_free` asymmetry, and stage 2
with the recycler's cap lifted is the (b) result (`graph_churn_alloc` 49.8 to 34.2 ms).

## Test and benchmark plan

- **Correctness.** (1) The suite, three ways: slab off (today), slab on, `PRISMIO_SLAB=0`; outputs identical. (2)
  `slab_stress.c` grown into a property test: random sizes 1-40000, `realloc` chains, hand-off between threads in rings,
  threads created and destroyed in waves, and a block-content check on every free; ASan, TSan, UBSan; 10^9 operations in
  a nightly leg. (3) The shim on the whole suite and on the compiler's self-build (gate condition: empty log). (4)
  `--verify` over the span heap. (5) A `fork` child that allocates and frees; a thread that exits holding a full cache;
  an embedder-created thread. (6) Exhaustion: a class that fills its region, a refused reservation, `ulimit -v`.
- **Performance.** (1) The hosted sweep with `ab.py`: median of 9-15 interleaved runs, CPU and peak RSS, checksums; the
  four `graph_churn_*` arms, `manual_alloc_churn`, `arena_bump`, `tree_traversal`, `tokenization`, `key_value_update`
  as the named tripwires. (2) Fast-path micro-benchmarks (`slab_micro.c`) per platform, alloc and free separately and
  as pairs, same-thread and remote. (3) A cache-hostile pattern (the random-lifetime test: 0.44 s to 0.07 s) and the
  producer/consumer blow-up test Hoard defined [7]: producers allocate, consumers free, RSS must plateau. (4) The
  freestanding `icount` suite for stage 7. (5) Reference arms against a mimalloc and a jemalloc linked into the C++
  arm, to separate "better than libmalloc" from "better than the best": not done here, and the claim in this file is only
  the former.
- **Memory.** A size-class phase-change test (fill one class, free all, fill another; the prototype's measured 321.7 MB
  against libmalloc's 323.9 on macOS, which stage 5 must cut on Linux), an idle-after-peak RSS trace over 60 s with the
  decommit delay on and off, and a 24-hour soak with a mixed workload for slow growth.
- **Regression guard.** The `ab.py` configurations for the superseded variants stay in the tree until stage 5 lands, so a
  slowdown can be bisected between layout, attributes and caches.

## Reproducing

```bash
python3 benchmarks/allocator_proto/mk_toolchains.py /tmp/alloc          # tc0 (as shipped), tc5 (no stagger)
cp benchmarks/build/hosted/cpp-suite  /tmp/alloc/suite-cpp               # optional reference arms
cp benchmarks/build/hosted/rust-suite /tmp/alloc/suite-rust
ALLOC_SCRATCH=/tmp/alloc python3 benchmarks/allocator_proto/ab.py \
    --configs base,off,cpp,rust --bench graph_churn_alloc,graph_churn_transfer --runs 9 --build
```

`ab.py` writes nothing under `benchmarks/results/`. Configurations: `base` (the slab), `off` (`PRISMIO_SLAB=0`),
`noattr` (`PRISMIO_PROTO_NOATTR`), `s5` (no stagger); any other name runs a `suite-<name>` already in the scratch
directory, which is how a toolchain from before a change is compared. The harness must run from outside the checkout, or `runtime.hash` has to match the
sources, which `mk_toolchains.py` arranges. The shim and the stress harness:

```bash
clang -dynamiclib -o /tmp/alloc/freeshim.dylib benchmarks/allocator_proto/slab_free_shim.c
SHIM_LOG=/tmp/alloc/shim.log DYLD_INSERT_LIBRARIES=/tmp/alloc/freeshim.dylib <program>      # /opt/homebrew python for the suite: /usr/bin/python3 strips DYLD_*
python3 benchmarks/allocator_proto/extract_slab.py && clang -O2 -fsanitize=thread -o /tmp/alloc/stress benchmarks/allocator_proto/slab_stress.c && /tmp/alloc/stress 4 50000
```

The prototype's changes, for review: `runtime/lang_runtime.c` (the `PROTOTYPE allocators` block, and one call in
`prismio_memory_thread_cleanup`), `runtime/llvm-api-backend.c` (`effective_alloc_fn`, `tag_alloc_callsite`, and
`rt_base_alloc` added to `tag_alloc_fn`). Both are inert by default: the project compiler built with them emits IR
byte-identical to the one built without.

## Sources

1. TCMalloc, restartable sequences: <https://google.github.io/tcmalloc/rseq.html>
2. TCMalloc design (size classes, per-CPU and per-thread caches, transfer cache, central free list, spans and pagemap, page heap): <https://google.github.io/tcmalloc/design.html>
3. snmalloc (message-passing remote deallocation, two-branch fast path, separated metadata): <https://github.com/microsoft/snmalloc>
4. Go runtime allocator (`malloc.go` header: size classes, mcache/mcentral/mheap, spans, arenas): <https://go.dev/src/runtime/malloc.go>
5. rpmalloc (size classes, aligned spans, per-page atomic remote free list, decommit, thread finalisation): <https://github.com/mjansson/rpmalloc>
6. mimalloc README, and Leijen, Zorn, de Moura, "Mimalloc: Free List Sharding in Action", MSR-TR-2019-18: <https://github.com/microsoft/mimalloc>, <https://www.microsoft.com/en-us/research/publication/mimalloc-free-list-sharding-in-action>
7. Berger, McKinley, Blumofe, Wilson, "Hoard: A Scalable Memory Allocator for Multithreaded Applications", ASPLOS 2000: <https://people.cs.umass.edu/~emery/pubs/berger-asplos2000.pdf>
8. Zig `SmpAllocator` (thread-slot freelists, 256K slabs; deferred per-slab free lists PR): <https://zff.dev/ziglang/zig/pulls/36294>
9. jemalloc ChangeLog (extents, dirty/muzzy decay, background purging threads, post-fork fixes), via a mirror: <https://android.googlesource.com/platform/external/jemalloc_new/+/refs/heads/android12-dev/ChangeLog>
10. `madvise(2)`, `MADV_FREE` and `MADV_DONTNEED`: <https://man7.org/linux/man-pages/man2/madvise.2.html>
11. macOS `MADV_FREE` and RSS accounting, `MADV_FREE_REUSABLE`/`REUSE` in Go's runtime: <https://jemalloc.net/mailman/jemalloc-discuss/2011-October/000036.html>, <https://lab.nexedi.cn/kirr/go/-/commit/abf8e355a8fe4b77009cb55f6bef11f74e6ade03>
12. `VirtualAlloc` (`MEM_RESERVE`, `MEM_COMMIT`, `MEM_RESET`): <https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualalloc>
13. mimalloc API documentation (`mi_thread_done`, arenas, `mi_heap_destroy`, huge pages): <https://github.com/microsoft/mimalloc/blob/main/doc/mimalloc-doc.h>
14. bumpalo: <https://docs.rs/bumpalo/latest/bumpalo/>
15. jemalloc background (arenas as pools destroyed in one operation, decay-based purging): <https://github.com/jemalloc/jemalloc/wiki/Background>

Pages that returned nothing usable (a binary PDF of the mimalloc report, a 404 for the snmalloc paper) were not relied on;
every statement about another allocator above is from the pages listed, and where a page was silent (snmalloc's size
classes and owner lookup, jemalloc's size-class table, tcmalloc's release policy) this file does not say.
