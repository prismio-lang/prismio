# Feature backlog

This is the short, implementation-facing backlog for Prismio's next standard
library capabilities. It is intentionally not named `TODO.md`: the project keeps
long-lived, actionable work in `docs/`, while `KNOWN_ISSUES.md` records observed
defects and `aif/evidence/` records measurements.

All three items below currently appear as unsupported workloads in
[`benchmarks/benchmarks.json`](../benchmarks/benchmarks.json) and
[`benchmarks/UNSUPPORTED.md`](../benchmarks/UNSUPPORTED.md). Do not change either
record to `implemented` until its benchmark runs in all three implementations,
has a cross-language checksum, and passes the normal suite.

## Delivery order

1. **`mixed_map_removal`** — close the credibility gap in `std.map`.
2. **`json_parse` and `json_serialize`** — one shared JSON DOM and API surface.
3. **`priority_queue`** — a reusable binary heap rather than a benchmark-local
   implementation.

The map item comes first because JSON object storage and many ordinary command
line programs benefit from a complete associative container. JSON comes next
because its parser and serializer must agree on one owned recursive model.
The heap is independent and may be implemented in parallel once the public API
is agreed.

## 1. `mixed_map_removal` — P0 — done 2026-09-25

**Landed.** `mapRemove` and `m.remove(k)`: tombstones in the probe table, the
dense entry swap-removed (`list_swap`, then `list_truncate`, which releases the
key), and an in-place rebuild once a quarter of the table is tombstones.
Positions stay insertion order until the first removal; after one, the last
entry takes the removed one's position (IndexMap's `swap_remove`). A `longest`
field bounds every probe, so a miss or a reinsertion stops after the furthest
any entry sits from home rather than walking to an empty bucket. test_193 covers
the checklist below, `Map<String, Int>` 2,671/2,671 under `--verify`. The
benchmark runs in all three arms: 10.9 ms against C++ 12.8 ms and Rust 16.7 ms.
The original checklist follows for the record.

**Goal.** Add key removal to [`std/map.psm`](../std/map.psm) without changing the
language syntax or the compiler's type system. A successful delete must make
the key absent, reduce `mapLen`, preserve correct probe chains, and leave the
map usable through growth, rehash, iteration, and reinsertion.

### API to settle before implementation

```psm
fn mapRemove<K: Key + Copy, V>(m: Map<K, V>, key: K) -> Bool
```

`true` means a live key was removed; `false` means it was already absent. Keep
`mapGet` for retrieving values: a first version should not promise to return a
removed `V`, because the current map deliberately supports only non-owned value
storage.

### Checklist

- [ ] Specify the post-removal iteration contract. The existing contract says
  `mapKeyAt` and `mapValueAt` are insertion ordered; preserve that contract or
  deliberately version/document a replacement before writing the code.
- [ ] Choose and document the slot strategy: tombstones plus periodic rebuild,
  or backward-shift deletion. The probe must distinguish an empty slot from a
  deleted slot until all affected entries have been repaired/rehashed.
- [ ] Account for the map's *second* representation: `keys` and `values` are
  dense parallel `List`s while `slots` holds indices into them. Repairing only
  `slots` is insufficient; deletion must also keep dense entry indexes,
  `mapLen`, and iteration consistent.
- [ ] Decide how a deleted dense entry is reclaimed. `List` exposes append,
  read, and overwrite, but no public truncation/pop operation. A purely
  stdlib implementation can retain dead storage and reuse/rebuild it, but that
  choice must be measured on churn. If physical compaction is needed, add the
  smallest ownership-safe List removal/truncation primitive and its compiler
  builtin plumbing; this is a runtime/front-end surface change, not a claim of
  “zero compiler changes.”
- [ ] Preserve the existing `Key + Copy` key ownership rule. In particular,
  String keys are cloned on insertion and `list_set` deliberately does not
  generally release an overwritten object slot; do not turn removal or
  compaction into a key leak or a double release.
- [ ] Rehash after deletion when tombstone density or displacement crosses a
  documented threshold. Reuse `mapPlaceAll` only after it has been made aware
  of live entries.
- [ ] Add focused tests: absent delete; first/middle/last insertion-order
  delete; collision-chain delete; delete then lookup after the gap; delete then
  reinsert; delete across grow/rehash; `Map<String, Int>` under `--verify`; and
  adversarial hashes using the existing adaptive-hash fixture style.
- [ ] Implement the Prismio, C++, and Rust `mixed_map_removal` benchmark cases,
  register their checksums, then mark the catalog and unsupported record
  implemented.

**Done when:** no lookup terminates early after a deletion, `mapLen` and the
iteration API expose exactly the live entries, ownership verification is clean,
and the benchmark is runnable through `prismio bench`.

## 2. `json_parse` and `json_serialize` — P1

**Goal.** Ship one native `std.json` module that parses and serializes RFC 8259
JSON. It must use Prismio strings and collections directly; no benchmark-local
or opaque C parser/formatter.

### Model and public surface to settle

Start with a recursive value model and explicit parse errors:

```psm
enum JsonValue {
    Null,
    Bool(Bool),
    Number(Float),
    String(String),
    Array(List<JsonValue>),
    Object(List<JsonMember>)
}

struct JsonMember { key: String, value: JsonValue }
struct JsonError { offset: Int, message: String }

fn jsonParse(source: String) -> Result<JsonValue, JsonError>
fn jsonSerialize(value: JsonValue) -> String
```

Use an ordered `List<JsonMember>` for the initial object representation. The
current `Map<K, V>` cannot safely hold an owned `JsonValue` as `V`, as documented
in `std/map.psm`; making JSON objects depend on that unsupported ownership mode
would make a superficially working parser leak. Add an object lookup helper only
if a measured caller needs it, and define duplicate-key behavior explicitly
(recommended: preserve input order and let the last member win for lookup).

### Checklist

- [ ] Add `std/json.psm`, importing only the modules it actually needs
  (`std.string`, `std.option`, and collection support). Add `std.json` to the
  standard-module table in `RUNTIME.md`.
- [ ] Implement a byte-indexed recursive-descent parser with a single cursor.
  Accept JSON whitespace only; reject trailing non-whitespace after one value.
- [ ] Parse all six value forms: null, booleans, strings, arrays, objects, and
  numbers. Return `JsonError` with the byte offset rather than aborting.
- [ ] Implement string escapes: quotation mark, reverse solidus, slash,
  backspace, form feed, newline, carriage return, tab, and `\\uXXXX`.
  Decide and test the v0.1 Unicode policy before coding surrogate pairs: Prismio
  `Char` is a byte and Strings are UTF-8 byte strings.
- [ ] Validate JSON-number grammar separately from conversion. `strParseFloat`
  currently has no exponent support and intentionally accepts a broader
  spelling than JSON in some respects, so either extend it with tests or keep a
  JSON-specific conversion path. Reject non-finite values on parse and never
  serialize them.
- [ ] Serialize every variant recursively with minimal valid punctuation and
  correct string escaping. Preserve array and object member order; do not sort
  objects as a hidden side effect.
- [ ] Add parser conformance tests for nesting, whitespace, empty containers,
  malformed separators, bad/truncated escapes, duplicate keys, trailing input,
  number boundaries, and byte offsets. Add serializer tests for every control
  character and parse/serialize/parse semantic round trips.
- [ ] Run recursive ownership cases under `--verify`, especially nested arrays,
  nested objects, errors after partially built containers, and long strings.
- [ ] Add the comparable `json_parse` and `json_serialize` workloads to Prismio,
  C++, and Rust benchmark modules; register checksums and update the catalog
  only after both pass.

**Done when:** every emitted document is valid JSON, valid supported input
round-trips semantically, malformed input produces a bounded diagnostic instead
of a crash, and both benchmark entries run through the suite.

## 3. `priority_queue` — P2

**Goal.** Provide a standard binary heap for scheduling and graph algorithms,
implemented over `List<T>` rather than duplicated inside a benchmark.

### Initial API

```psm
struct PriorityQueue<T: Ord + Copy> { items: List<T>, length: Int }

fn priorityQueueNew<T: Ord + Copy>() -> PriorityQueue<T>
fn priorityQueueLen<T: Ord + Copy>(q: PriorityQueue<T>) -> Int
fn priorityQueueIsEmpty<T: Ord + Copy>(q: PriorityQueue<T>) -> Bool
fn priorityQueuePush<T: Ord + Copy>(q: PriorityQueue<T>, value: T)
fn priorityQueuePeek<T: Ord + Copy>(q: PriorityQueue<T>) -> Option<T>
fn priorityQueuePop<T: Ord + Copy>(q: PriorityQueue<T>) -> Option<T>
fn priorityQueueHeapify<T: Ord + Copy>(items: List<T>) -> PriorityQueue<T>
```

The initial container is a **min-heap**. The `Copy` bound is deliberate: the
current List read API returns a borrowed value, so arbitrary owned payloads
cannot be returned from `peek` or `pop` without a separate ownership design.
`length` permits pop/push reuse without needing a List shrink primitive; it is
the logical heap length, while the backing List may retain unused tail slots.

### Checklist

- [ ] Add `std/priority_queue.psm` and document `import std.priority_queue` in
  `RUNTIME.md`.
- [ ] Implement index helpers (`parent`, `left`, `right`), sift-up on push, and
  sift-down on pop. Every List access must be bounded by logical `length`.
- [ ] Implement bottom-up `heapify` in O(n), not repeated O(n log n) pushes.
- [ ] Define empty behavior through `Option<T>`; neither `peek` nor `pop`
  should use a sentinel.
- [ ] Decide whether the passed list is consumed by `heapify` (recommended) or
  copied; document it and test post-call ownership/use rules.
- [ ] Add tests for empty/singleton queues, duplicates, negative values,
  monotonic pop order, interleaved pushes/pops with tail-slot reuse, heapify,
  and randomized reference comparison. Include `--verify` coverage.
- [ ] Implement and register the three-language `priority_queue` benchmark,
  then remove its unsupported entry.

**Done when:** pop order is nondecreasing, all operations retain O(log n) worst
case except O(1) peek/length and O(n) heapify, and the benchmark runs without a
private heap implementation.

## Shared release gate

For each completed item:

- [ ] Run its focused tests and the normal suite using the candidate compiler.
- [ ] Run ownership verification for recursive/owned cases where applicable.
- [ ] Update `RUNTIME.md`, `benchmarks/benchmarks.json`,
  `benchmarks/UNSUPPORTED.md`, and `benchmarks/README.md` in the same change.
- [ ] Record measured benchmark evidence under `aif/evidence/` if the change
  affects a claimed performance result.
