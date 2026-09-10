# Currently Unsupported by Prismio

These records describe benchmark requirements that cannot currently be met
faithfully with Prismio's supported language and standard-library surface. A
custom substitute is intentionally not supplied.

```text
benchmark: linked_list

status: unsupported

missing_features:
  - standard LinkedList / deque data structure and operations

reason:
  The benchmark is intended to compare production linked-list allocation and
  traversal APIs. A hand-built enum or index list would be a substitute data
  structure rather than the same standard capability used by C++ and Rust.

cpp_status: available
rust_status: available
prismio_status: unsupported
```

```text
benchmark: binary_search_tree

status: unsupported

missing_features:
  - ordered tree set/map data structure with insertion and lookup

reason:
  Prismio has recursive enums, but no standard ordered tree container. Writing
  a benchmark-only tree would replace the missing library facility and would
  not be equivalent to C++ std::set or Rust BTreeSet.

cpp_status: available
rust_status: available
prismio_status: unsupported
```

```text
benchmark: priority_queue

status: unsupported

missing_features:
  - binary heap / priority queue data structure and push/pop API

reason:
  Prismio's standard library provides List and Map but no heap. Implementing a
  private heap in the benchmark would conceal the missing standard structure.

cpp_status: available
rust_status: available
prismio_status: unsupported
```

```text
benchmark: mixed_map_removal

status: unsupported

missing_features:
  - Map key removal API
  - hash-table tombstone or backward-shift deletion support

reason:
  std.map is an open-addressed hash table with insertion, overwrite, lookup,
  and iteration, but explicitly has no mapRemove operation or deletion slots.

cpp_status: available
rust_status: available
prismio_status: unsupported
```

```text
benchmark: json_parse

status: unsupported

missing_features:
  - JSON parser API
  - JSON value/object/array representation

reason:
  Prismio has string scanning and Map/List primitives but no supported JSON
  parser or JSON value model. A benchmark-local parser would be a workaround.

cpp_status: available
rust_status: available
prismio_status: unsupported
```

```text
benchmark: json_serialize

status: unsupported

missing_features:
  - JSON serialization API
  - JSON string escaping API
  - JSON value/object/array representation

reason:
  Prismio has general string construction but no JSON serializer, escaping
  routine, or standard JSON data model. Ad-hoc formatting would not faithfully
  measure the same library capability.

cpp_status: available
rust_status: available
prismio_status: unsupported
```

```text
benchmark: regex_matching

status: unsupported

missing_features:
  - standard regular expression engine and syntax
  - NFA/DFA automaton compiler and matcher

reason:
  Prismio provides substring and byte-level scanning, but lacks a regular
  expression library or compiled automaton runtime in stdlib.

cpp_status: available (std::regex / re2)
rust_status: available (regex crate / standard regex benchmarks)
prismio_status: unsupported
```

```text
benchmark: lock_free_queue

status: unsupported

missing_features:
  - user-space atomic types (AtomicBool, AtomicInt, AtomicPtr)
  - atomic compare-and-swap (CAS) and fetch-and-add operations
  - memory orderings (acquire, release, sequentially consistent)

reason:
  Prismio uses atomic primitives internally inside the runtime for thread state,
  but does not expose user-facing atomic types or CAS instructions in the
  language surface.

cpp_status: available (std::atomic)
rust_status: available (std::sync::atomic)
prismio_status: unsupported
```

```text
benchmark: async_event_loop

status: unsupported

missing_features:
  - async/await syntax and state-machine generator
  - non-blocking I/O event reactor (epoll, kqueue, io_uring)
  - cooperative green-thread / task scheduler

reason:
  Prismio concurrency relies on 1:1 OS threads (spawn/join) and blocking
  channels. There is no asynchronous runtime or non-blocking I/O multiplexer.

cpp_status: available (epoll / asio / coroutines)
rust_status: available (tokio / mio)
prismio_status: unsupported
```

```text
benchmark: mutex_contention

status: unsupported

missing_features:
  - user-space Mutex<T> and RwLock<T> synchronization primitives
  - condition variables (Condvar) in stdlib

reason:
  Prismio's thread synchronization model is exclusively channel-based. Mutual
  exclusion locks are not exposed in std for user data protection.

cpp_status: available (std::mutex, std::shared_mutex)
rust_status: available (std::sync::Mutex, std::sync::RwLock)
prismio_status: unsupported
```

```text
benchmark: work_stealing_pool

status: unsupported

missing_features:
  - thread-pool runtime with work-stealing deques
  - fine-grained fork-join parallel iteration (parallel for)

reason:
  Prismio spawn allocates a fresh OS thread per invocation. Fine-grained task
  parallelism requires a persistent work-stealing thread pool runtime (e.g.
  Rayon or OpenMP).

cpp_status: available (tbb / OpenMP)
rust_status: available (rayon)
prismio_status: unsupported
```

```text
benchmark: simd_vector_ops

status: unsupported

missing_features:
  - explicit portable SIMD vector types (e.g. f32x8, i32x4)
  - explicit vector intrinsics (AVX2, AVX-512, ARM NEON) in language grammar

reason:
  Prismio relies entirely on LLVM auto-vectorization passes. There are no
  syntactic vector types or explicit SIMD intrinsics in the language.

cpp_status: available (compiler vectors / intrinsics / std::experimental::simd)
rust_status: available (std::simd / core::arch)
prismio_status: unsupported
```

```text
benchmark: custom_allocator_churn

status: unsupported

missing_features:
  - custom allocator interface / trait for collections
  - user-space arena or bump allocator parameters for List and Map

reason:
  Prismio's AIF (Adaptive Inference Framework) determines allocation tiers
  at compile time. Users cannot supply custom allocators or region handles into
  standard containers.

cpp_status: available (pmr::polymorphic_allocator / custom allocators)
rust_status: available (allocator_api / bumpalo)
prismio_status: unsupported
```

```text
benchmark: tcp_echo_server

status: unsupported

missing_features:
  - network socket standard library (std.net)
  - POSIX / Winsock socket wrappers (bind, listen, accept, send, recv)

reason:
  Prismio stdlib provides file and process I/O, but has no networking or
  TCP/UDP socket subsystem.

cpp_status: available
rust_status: available
prismio_status: unsupported
```

```text
benchmark: mmap_file_io

status: unsupported

missing_features:
  - memory-mapped file I/O abstraction in std.fs
  - virtual memory mapping and page-level control (mmap / munmap)

reason:
  File operations are limited to buffered/string readFile and writeFile; zero-copy
  memory mapping is not implemented.

cpp_status: available (mmap / Boost.Iostreams)
rust_status: available (memmap2)
prismio_status: unsupported
```

```text
benchmark: generic_serialization

status: unsupported

missing_features:
  - compile-time reflection / type metadata inspection
  - procedural macros or derive code-generation attributes

reason:
  Prismio does not possess a compile-time macro or reflection engine required
  to derive zero-overhead binary/text codecs (like Serde or Protobuf).

cpp_status: available (compile-time reflection / templates / Protobuf)
rust_status: available (serde / bincode)
prismio_status: unsupported
```

## Deduplicated capabilities

- LinkedList / deque — used by: `linked_list`
- Ordered tree set/map — used by: `binary_search_tree`
- Binary heap / priority queue — used by: `priority_queue`
- Map deletion — used by: `mixed_map_removal`
- User-space atomics & memory barriers — used by: `lock_free_queue`
- Mutual exclusion locks in std — used by: `mutex_contention`
- Persistent work-stealing thread pool — used by: `work_stealing_pool`
- Async runtime & non-blocking I/O loop — used by: `async_event_loop`
- Network socket subsystem (std.net) — used by: `tcp_echo_server`
- Memory-mapped file I/O — used by: `mmap_file_io`
- Regular expression engine & compiler — used by: `regex_matching`
- JSON data model, escaping, and parser/serializer — used by: `json_parse`, `json_serialize`
- Compile-time derive / reflection — used by: `generic_serialization`
- Explicit SIMD vector types & intrinsics — used by: `simd_vector_ops`
- Pluggable custom container allocators — used by: `custom_allocator_churn`

## Potential future benchmarks unlocked

- LRU caches, sliding windows, and work-stealing deque workloads
- Ordered range queries, B-Tree scans, and interval trees
- Dijkstra / A* pathfinding using standard priority queues
- Churn-heavy hash maps, cache eviction, and set difference
- High-throughput non-blocking HTTP / TCP microservices
- Lock-free MPMC ring buffers and concurrent skip-lists
- Heavy concurrent worker thread pools with task stealing
- Fast multi-gigabyte/sec zero-copy log processing via mmap
- High-throughput regex search and lexical analysis benchmarks
- Protobuf, MessagePack, and JSON serialization/deserialization pipelines
- Hand-tuned SIMD image processing, matrix kernels, and tokenizers

