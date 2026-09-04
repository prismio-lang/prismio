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

## Deduplicated capabilities

- LinkedList / deque — used by: `linked_list`
- Ordered tree set/map — used by: `binary_search_tree`
- Binary heap / priority queue — used by: `priority_queue`
- Map deletion — used by: `mixed_map_removal`
- JSON data model and parsing — used by: `json_parse`
- JSON data model, escaping, and serialization — used by: `json_serialize`

## Potential future benchmarks unlocked

- LRU cache and work-stealing deque workloads
- Ordered range queries and tree-map iteration
- Dijkstra/A* using the standard priority queue
- Churn-heavy hash maps and set difference
- JSON DOM traversal, parsing, and serialization pipelines
