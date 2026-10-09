# Known issues

What is open in the tree being prepared as 0.2.0. **Only open items are here.** An item
leaves this file in the commit that fixes it; the commit message carries the evidence
(`git log` is this project's record). Anything described as a decision is one the project
has made on purpose.

Nothing below is unsoundness unless it says so. **Audited 2026-10-09** against the project
host (`.prismio/build/debug/prismio`, built 2026-10-08; the three commits after it touch the
AArch64 backend, a benchmark arm and docs, none of the analysis):

- Every runnable program in `../tests` was built with `--verify` and run: 281 programs, 274 of
  them print a ledger, **0 violations**, and 20 still leak (463 blocks, 300 of them the deliberately
  pinned `test_273`; see [Ownership](#ownership-leaks)). That is after the fixes made later the same day,
  below: the audit itself read 25 programs and 192 blocks. The other seven print nothing and two harness fixtures
  (`aif_tiers`, `aif_concurrency`) need arguments the suite gives them.
- Each reproducer below was run on that date and its numbers are the ones it printed. An entry
  that says **Not re-run** was not: its figures are from the date it names, or from the file
  this one replaced, and it should be re-run before anyone builds on it.
- Examples are valid Prismio and, unless an entry says otherwise, are the programs that were
  measured.

| Area | What is in it |
|---|---|
| [Ownership: leaks](#ownership-leaks) | What the suite still leaks, by cause, and the shapes that reproduce each |
| [The AIF analysis and its oracle](#the-aif-analysis-and-its-oracle) | Where the engine and the Python oracle disagree |
| [Codegen and performance](#codegen-and-performance) | Missed placements, a rejected literal form, curation and linkage limits |
| [Freestanding and the Linux kernel](#freestanding-and-the-linux-kernel) | The one benchmark row behind C, and where the kernel work is tracked |
| [Language surface](#language-surface) | What the language does not do yet, and decisions worth knowing |
| [Traits](#traits) | What the trait system deliberately leaves out |
| [Concurrency](#concurrency) | Task and channel limits |
| [Toolchain, packaging and tests](#toolchain-packaging-and-tests) | The `ums` fixture, linking, `.plib` coverage, cross builds |
| [Platform](#platform) | Windows, WebAssembly and the VM-tested archives |
| [Measuring this compiler](#measuring-this-compiler) | Guidance that has prevented wrong conclusions |

The dated experiment records that source comments and some entries cite as
`aif/evidence/RESULTS-<name>.md` were removed on 2026-10-07. Every one cited here is in Git
history at `c9f71ef`: `git show c9f71ef:aif/evidence/RESULTS-<name>.md`
([`aif/README.md`](aif/README.md) has the listing command).

---

## Ownership: leaks

Every item in this section is a **leak, never a double free**: the conservative direction
when the analysis cannot prove a release. `--verify` reports `allocated / released /
leaked / violations`; `PRISMIO_VERIFY_TRACE=1` prints where each leaked block was
allocated (`aif_trace_print` in `../runtime/lang_runtime.c`; symbolise with `atos -o
<exe> -l 0x100000000`, or build with `--verify -g`). **Probe with strings longer than
twelve bytes**: a shorter one is stored inline, never reaches the ledger, and reads clean.

```
prismio build tests/test_205_return_on_one_path.psm --verify -o /tmp/t && /tmp/t
```

A program that starts itself (`test_153`, `test_183`, `test_188`, `test_258`, `test_259`)
prints one ledger per process; the table counts the parent's, which prints last. Those five
read clean now.

### What the test suite still leaks

Counts from `--verify` on 2026-10-09, after the day's fixes: **463 leaked blocks in 20 programs, 0 violations** (163 in 19 programs, plus the 300 pinned in `test_273`).

| Program | Leaked | Cause |
|---|---|---|
| `test_58_region_serves` | 100 | Values that escape their `region` fall back to the heap and are not released (pinned). |
| `test_205_return_on_one_path` | 10 | `let t = a; return t` returns `a` under another name, and an inner `let a = a` binds the name twice; both keep the old refusal. |
| `test_269_struct_pass_through_escapes` | 9 | A function that returns *one of* its parameters, with the result returned, pushed, carried round a loop or assigned outward: the argument that is not returned has no owner ([below](#the-argument-a-pass-through-function-does-not-return-is-leaked)). |
| `test_273_match_payload_returned` | 300 | **Pinned on purpose** (300 of 400): a `match` arm that returns the payload it bound keeps the `Result` alive, because a match binder is a view of the scrutinee. Declining the drop is what stops the use-after-free this fixture was written for; the leak is the price. A copy of the payload at the `return` would close it. |
| `test_127_enum_null_variant` | 6 | Blocks are allocated in `makeTree`, `add` and `makeNested` (recursive enums built by helpers). Once recorded as a `strClone` holder/site conflation when it leaked 1; the cause is **not isolated** at 6. |
| `test_100_reuse_token` | 6 | Nothing in `main` is released (reuse tokens and a collected cycle). |
| `test_191_option_methods` | 5 | `concat` results through the `T?` and `Result` methods (the `Process()` list it also leaked is released now). |
| `test_185_view_outlives_binding`, `test_53_aif_views` | 4 each | A view that outlives its base's binding keeps the base unreleased. |
| `test_69_task_results` | 4 | A task's String result (`str_own` on the task side) and its struct. |
| `test_254_array_and_slice_methods` | 2 | A temporary `Vec` from a copying method on the right of an `or` (`... or a.toVec().sorted()[0] != 1`): [never given a binding there](#a-temporary-on-the-right-of-andor-is-never-given-a-binding). |
| `fixture_slice_escape` | 2 | A `Slice` returned from the function that owns its `Vec`: the view outliving its base. |
| `binder_rewrap_probe` | 2 | `let h = parse(t); return errOf(h)` keeps `h`. |
| `fixture_slice_bounds`, `range_direction_probe` | 2 each | **Not leaks in a program that runs to the end**: both end the process on a run-time error on purpose (a slice out of range; a zero `step`), so no scope-exit drop runs. |
| `test_67_option_result` | 1 | One String allocated in `main`; not isolated. |
| `binder_return_probe`, `option_methods_probe` | 1 each | A literal stored into a `String?` keeps what any other `String?` holds from being released; the probes store literals on purpose. |
| `test_171_default_values` | 1 | `Outer.inner` holds heap `Inner`s and, elsewhere, a stack `Inner` in a stack `Outer`; the field's release cannot serve both, so it declines. |
| `test_44_aif_region` | 1 | A pinned single leak, explained in `run_aif_verify_test`. |

**Fixes these need**, by cause:

- *View outliving its base* (185, 53, `fixture_slice_escape`): **copy-on-escape**,
  materialising the view when it leaves the base's scope. The current behaviour is the safe
  direction and is pinned in `run_aif_verify_test`.
- *Renamed return* (205): binding-level move tracking in codegen's drop list.
- *Holder-aware fields* (171, and the `strClone` shape of 127): the engine decides a field's
  release per type, not per holder, so one type used two ways declines.
- *One of two parameters returned* (269): a release guarded by pointer equality with the
  result, in the scope-exit drop and in the overwrite release.
- *A displaced field value, beyond the first assignment to a fresh local*: see [below](#assigning-a-struct-field-releases-the-value-it-replaces-only-for-a-fresh-local).
- *A temporary in the right operand of `and`/`or`*: the right side runs only sometimes, so a
  binding hoisted ahead of the statement would run always; it needs a release on that path only.
- *Locals keyed by (function, name)*: see [Concurrency](#concurrency).

### The argument a pass-through function does not return is leaked

```
struct Point { x: Int, y: Int }

fn pick(a: Point, b: Point) -> Point {
    if (a.x > b.x) { return a }
    return b
}

fn main() -> Int {
    let mut best = Point { x: 0, y: 0 }
    for i in 1..<5 {
        let cand = Point { x: i, y: i }
        best = pick(best, cand)
    }
    return best.x
}
```

`--verify` reads 5 allocated, 0 released. Bound in the scope that made the arguments
(`let r = pick(a, b)`) the call is clean (2 allocated, 2 released), and so is a result held in
a struct field: both arguments are released where they were made, and `r` is an alias
(`../tests/test_268_struct_pass_through.psm`). When the result *outlives* that scope (returned,
pushed into a `Vec`, assigned to an outer variable, carried round a loop) the arguments' escape
is lifted past it, which is right for the one that comes back and a leak for the other. Which
one that is is a run-time fact, so the fix is not a better fact but a guarded release: free each
argument, and the value an assignment displaces, unless it equals the result. It touches the
engine, the codegen drop list and `tools/aif_oracle/aif.py`, and it must come with a
`--verify` fixture, because the failure direction is a double free.
`../tests/test_269_struct_pass_through_escapes.psm` pins the current count.

### A temporary on the right of `and`/`or` is never given a binding

```
let v: Vec<Int> = [3, 1, 2, 5, 4]
if (v.toVec().length != 5 or v.sorted()[0] != 1) { println("x") }   // the sorted() Vec leaks
```

`irHoistBorrowedTemporaries` binds an owned temporary ahead of its statement, and only where
that reorders nothing; the right operand of `and`/`or` runs only sometimes, so a binding hoisted
out of it would run always, and the finder stops there (`irFindBorrowedTemporary`). The same
expression as the *left* operand, or alone in the condition, is bound and released. `test_254`
is this; closing it means a release on the path that evaluated the operand, not a hoist.

*Fixed 2026-10-09, recorded here because it explains the shape:* `v.sorted()[0]` in an `if`
condition (sema turns every `Vec` index into `list_get`, which the finder did not treat as a
scalar read off a temporary) and `match (parse(text)) { ... }` (the scrutinee itself was the
owned temporary) both leaked; `../tests/test_272_temporary_hoists.psm` pins them.

### A frame array frees none of its elements

```
let a = "a string long enough for the heap"
let arr = [a.concat("!"), a.concat("?")]   // 3 allocated, 1 released, 2 leaked
```

Both strings leak, and `[a.concat("!"), "lit"]` leaks the one. Nothing tears down an array
literal's owned elements at scope exit, and releasing all of them would be wrong the other way:
`[name, "lit"]` holds a binding freed on its own and a literal that was never allocated. A
release has to know, per slot, whether the element was an owned temporary. Map literals were
first lowered through two of these arrays, which is why a literal holding a computed String
key is built by one `mapPut` per such key (`../src/sema/maps.psm`).

### A pass-through result in a struct field is never released

```
fn through(m: Map<String, Int>) -> Map<String, Int> {
    m.set("a-key-longer-than-twelve-bytes", 4)
    return m
}
let inv = Inventory { counts: through(mapNew<String, Int>()) }   // 8 allocated, 0 released
let m = through(mapNew<String, Int>())                           // 8 allocated, 8 released
```

Bound to a `let`, the same call is clean, and a map literal with only plain keys
(`mapFromEntries`) is clean in both places. One holding a computed owned key goes through
`mapPut` and inherits both leaks: `return { p.concat("-long-suffix"): 1 }` reads 9 allocated, 8
released, and the same literal held in a struct field reads 9 allocated, 0 released.

### Assigning a struct field releases the value it replaces only for a fresh local

```
let p = Process()
p.program = process.args[0]
p.arguments = ["x"]            // 4 allocated, 4 released
```

Fixed 2026-10-09 for the common shape, and the reason `test_153`, `test_183`, `test_188`,
`test_258` and `test_259` read clean. An assignment releases the list it displaces when
`irMarkDisplacedFieldStores` (`../src/ir/expr.psm`) can see that nothing else holds it:

- the receiver is declared in the same block by a struct literal or by a call whose result
  this scope owns, and is not a parameter, a global or a name for something else;
- nothing between the declaration and the assignment mentions it, except a store to a
  *different* field of it whose value does not mention it (`p.program = ...` first is fine);
- the right-hand side does not mention it, so it cannot be the value being released;
- the type is reclaimed and releases its fields, and this field is released as a list
  (`fieldStoreReleasesDisplaced` in `../src/ir/stmt.psm`). A type nobody reclaims keeps its
  field values' owners, so freeing one there would be a second free.

**Still leaks**, each declined on purpose:

- the receiver is a parameter, a global, or an alias, or was declared in an outer block or
  before a loop (`for i in 0..<5 { b.items = [i] }` reads 13 allocated, 3 released);
- a second assignment to the same field (the first is a mention of the receiver), or any read
  of the field first: `let old = b.items` is a *view*, and so is a value a call returns out of
  `b`, so the displaced value may still be read;
- a field that is a String, a struct, an array, a counted field, or a list the type does not
  release.

Closing those needs the removal verdict's "no view can be live" proof (`COLLECTIONS.md` 1e), not
a syntactic one. The heap-struct variant (`b.items = [3]` on a `Bag` that is later pushed into
a `Vec`) reads 7 allocated, 7 released now.

### A struct on the frame: three field shapes still leak

**Not re-run.** A struct that does not outlive its function sits in a stack slot (T0) and
releases what its fields were given. Still open:

- **A field value read out and returned or pushed.** `return bag.items` or
  `keep.push(bag.items)` leaks the struct and the list: the value escapes through a field
  read and nothing in the frame owns it afterwards.
- **One function's use of a field changes every function's.** Field keys are per type, not per
  object, so `let before = bag.items` anywhere raises the escape of every value any `Bag` holds
  in `items`, and each function's temporaries there lose their owner.
- **A `let mut s = "lit"` that is not an owning accumulator** (so the literal is not cloned),
  later given both an owned value and an unowned one that is not itself a literal source, and
  returned. See `key_may_return_untracked` in `../runtime/aif_support.c`.

### Library producers share one allocation site

**Not re-run.** A site is per function, not per instance, so every `concat` in a program is one
site and its ownership is decided by the whole program. `StringBuilder` storing `concat`
results in its Vec field once made every `concat` result passed straight as an argument go
unreleased in any program that imported `std.fs` and `std.string` (`test_184` leaked 2,165 of
4,073). It copies through a helper of its own now and `concat_argument_probe.psm` pins that
shape, **but the sensitivity remains**: a program that stores `concat` results in a container
field of its own can change what is released elsewhere. `toUpper` and `toLower` are written out
as two bodies for the same reason (one shared `strCaseConverted` leaked 30 more strings in
`test_205`). **The fix is context-sensitive sites for library producers** (`MEMORY_PLAN.md`
§2.3); the same fix would split `vecOf`'s sites (see [Codegen](#codegen-and-performance)).

### Struct fields that may hold a string literal are never released

**Not re-run.** `Process()` defaults `program` to `""`, and a field a program ever stores a
literal into must not be freed (that was unsoundness, fixed at the cost of a leak). So
`Process.program` never frees an owned name, nor does any such field. Promoting the literal at
the store would reclaim it, but is not sound across a `.plib`: `Process()` is in
`process.plib`'s bitcode, compiled before any program decided the field is released. Each
`Process` given an owned program name leaks that one string.

### A container that may be handed a string literal releases none of its elements

**Not re-run.** `keep.push(optionOr(x, "fallback"))` may push the literal itself, and a
teardown would free `.rodata`; `container_may_hold_untracked` declines the element release,
which leaks the owned ones. A literal written at the push is copied in and does not count, nor
does a String view. Copying at the push whenever the pushed value may be untracked would close
it.

### Two shapes of passing a result straight on still leak

- **A temporary whose callee returns a view of it, evaluated after another call in the same
  statement.**

  ```
  total = total + b.length + same(make(i)).length   // over 100 iterations: 100 allocated, 0 released
  ```

  `irHoistBorrowedTemporaries` gives such a temporary a binding only where that reorders
  nothing, and `b.length` is a call evaluated first. A purity fact about the earlier call would
  let it move; nothing computes one.
- **A view of a binding kept past its block.** *(Not re-run beyond the two tests.)*
  `keep.push(optionOr(o, d))` and `outer = optionOr(o, d)` keep the binding alive, which leaks
  it where it used to be freed under the view. Copying the view into the keeper at that point
  would make it clean (`../tests/test_185_view_outlives_binding.psm`, `test_186`).

### A function that returns a view of its argument: the fact does not survive indirection

**Not re-run.** `strSubstring(owned, 1, 4)` is clean, but a function that computed its bounds
through another call and then returned `strSubstring(s, a, b)` read 1 allocated / 0 released,
because the caller's drop of `owned` was declined and the view that declined it took nothing.
The rule that avoids it is the one in the header of `../std/string.psm` (a producer allocates
its own result); `strScalarSubstring` and `strTruncateToWidth` copy for this reason. **Not
established:** why the inference reaches `strTrim`, which loops and then returns a view, and not
a function that passes its parameter to another one on the way.

### A Vec that owns its elements: three places a displaced element still leaks

**Not re-run.**

- A *counted* element displaced under CYCLE (the count, not the list, decides).
- Every list the analysis declines to give an owner: a literal bound to a name before the push
  (`let s = "..."; v.push(s)` on two lines, which may still be `.rodata`), or an element read
  stored back into a list (`v[0] = v[0]`, a second holder). Making these owned needs the analysis
  to prove the copy, not the runtime to guess it.
- **A Vec holding a counted and an uncounted element of one type leaks the uncounted one.**
  `list_push(ys, mk())` beside `list_push(ys, Tag { ... })`, where `mk`'s site is counted and the
  literal's is not, reads 8 allocated / 6 released / 2 leaked (2026-09-18). Teardown releases
  every element one way.

### The Vec/Map ownership model gives up on a shared container type

**Not re-run.** Element keys are per container *type*, so one `Vec<String>` whose element is
handed out anywhere in the program makes every `Vec` of those strings a non-owner that releases
nothing either way. A removal therefore releases at once only for a Vec no other allocation site
touches (`test_161` keeps its Vec alone in its file for that reason).

### UMS resolution releases nothing it allocates

**Not re-run** (a `--verify` build of the whole compiler does not link outside the project
build, so the ledger could not be read on 2026-10-09). Not unsoundness (`violations` was 0 on
either side when it was measured) but a regression in allocation hygiene. An earlier fix moved
the ledger by zero; the real shape is about eight lines, and the clause to widen can
double-free, so it needs the owners enumerated first.

### Recursive release is iterative along one self field only

**Not re-run** (`test_73_recursive_release_depth` runs clean under `--verify`, which is the
500,001-link case). The generated release of a recursive type loops on its last direct self
field and recurses on the others, so a `Chain` frees without growing the stack, but a type with
several self fields keeps a stack bound through its non-tail branches. Removing it needs an
explicit worklist (`RESULTS-recursive-release-depth.md`).

---

## The AIF analysis and its oracle

`../tools/aif_oracle/aif.py` is the oracle: an independent implementation that
`../tools/aif_differential.py` compares with the in-compiler engine. **They agree on all 17
default sources (re-run 2026-10-09)**, in both collection models: `[owned]`, the default, and
`[as-is]`, the pre-Level-4 `--copyable-collections` model that stays as the second arm. Two
sources outside that set disagree:

### `benchmarks/hosted/prismio/suite.psm`, in the default (owned) model

The six benchmark modules agree between the engine and the oracle in both models, but
`suite.psm`, which imports all of them, does not in the owned one (it agrees as-is): the
compiler reports **T2=138, T3=0**, the oracle **T2=136, T3=2** (162/0 against 160/2 when this was
found on 2026-10-07; the modules have changed since, the disagreement has not). Two sites tier
differently once the modules are analysed together, which points at a cross-module fact (a
shared producer, or an import-order effect) rather than a tier clause; `--why` on the two
differing sites is where to start. It is therefore not a default source.

### A struct pushed into a Vec in a loop (`test_164_array_fields`)

Recorded on 2026-10-07 as the oracle tiering it T3 (A=Shared) against the compiler's T1. **That
has narrowed**: on 2026-10-09 every tier count agrees and the only difference is the fixpoint,
**one more oracle round (compiler 7, oracle 8)**, in *both* models. It is not a default source.
A round is not a tier, but it is the same shape of disagreement (an extra propagation step in the
oracle) and worth a look the next time either file is touched.

---

## Codegen and performance

### A `Vec` literal heap-allocates and costs 4.3x the same literal left as an array

Measured 2026-10-07: a function called 20,000,000 times that builds
`let v: Vec<Int> = [i, i + 1, i + 2, i + 3]` and sums it takes 247 ms, and 57 ms with
`let v = [i, i + 1, i + 2, i + 3]` (12.4 ns against 2.9 ns a call). **The ratio was not
reproduced on 2026-10-09**: in a re-made loop the array form folded away entirely and the `Vec`
form ran in 0.19 s, so treat 4.3x as indicative. The mechanism is unchanged: an unannotated literal is an
`Array<T, N>` in a frame slot; one written where a `Vec<T>` is wanted lowers to `vecOf(...)`: a
header block, an element block and two frees. The element block is sized exactly (four elements
247 -> 197 ms, eight 363 -> 232 ms); the rest is the two allocations. `prismio aif` reports *no
allocation sites* for the user's code, because the sites are inside `vecOf` and shared by every
caller.

Three fixes were considered and none was built:

- **Retype a read-only literal as an array** (an immutable binding that is only indexed, iterated
  or asked for `.length` is an `Array<T, N>` for free). Sound for the type system, but it **changes
  what an out-of-range read does**: `v[7]` on a three-element `Vec` reads `0` (re-checked
  2026-10-09), while on an array it reads adjacent memory, because the language does not yet
  promise a bounds-check trap for an array index (see *Array indexing is unchecked* below). A
  program with a latent off-by-one would silently change behaviour, so this waits for either array
  bounds checks or a range proof for the index (`../src/ir/ranges.psm` already proves some).
  `isEmpty` and `isNotEmpty` are also `Vec`-only, so they would block the rewrite.
- **A frame-resident list** (header and elements in the caller's frame, no release) for a
  literal that never grows. Sema's rule that only a `let mut` or `inout` binding can change a
  Vec is not enough: a move into a `let mut` followed by `push` would grow a list whose header
  is on the stack. It needs a "frame list" flag that growth and release respect, or a use scan
  proving no by-value use of the binding.
- **Cloning `vecOf` per call site**, so each literal is its own AIF site and the caller's
  region or frame can serve it. Regime (a) of SPEC 5.2.1 declines them today ("the body has
  more than one call site").

Nothing in the tree needs it: `src/`, `std/` and `benchmarks/hosted/prismio` contain no
`let x: Vec<T> = [literal]` with elements (checked 2026-10-09), and `tests/` has 59 such lines
(fixtures for the literal itself). Start from `../tests/test_263_vec_literal_capacity.psm` if a
program turns up that does.

### A list literal is not accepted as a call argument

`[a, b, c]` becomes `vecOf(a, b, c)` where a `Vec<T>` is written (an annotation, a struct field,
the left of an assignment), and

```
fn takes(a: Vec<String>) -> Int { return a.length }
fn main() -> Int { return takes(["a", "b"]) }
```

is rejected with *"no overload of `takes` accepts these argument types"* (`P4001`, re-checked
2026-10-09). Bind it first: `let args: Vec<String> = ["status", "--short"]; run(args)` on two
lines.

The rewrite is not the problem; resolving the *generic* it produces is. Two placements were
built and measured, and both left `vecOf` unresolved, so codegen emitted a call to the
template's own name as though it were foreign (a link failure, `_vecOf` undefined):

- *Admitted during matching, built in the argument loop.* `monoResolveGenericCall` runs at the
  top of the call arm and the argument's rewrite happens after it; a second `semaExpr` does not
  help.
- *Built during matching*, in the place the working `takes(vecOf("x"))` resolves. The node still
  typed as `[String]` afterwards, so no overload matched.

The same rewrite resolves from `semaCheckValue` for a declaration and an assignment, and an
explicit `takes(vecOf("x", "y"))` resolves in argument position, so the difference is state, not
placement. Start by finding which of `monoSolveTypeParam` and `monoTemplateAcceptsCall` declines
with the outer call's resolution in flight. `../tests/test_149_list_literal` covers the three
contexts that work.

### A byte loop over a `let mut` String tests the inline tag per byte

**Not re-run.** `s.byteAt(i)` reaches `__builtin_string_byte_at` through `strByteAt`, which is
loop-free and so does not resolve its parameter; the caller's binding is never resolved either,
because only parameters and immutable `let`s are. Each read is `ir_str_byte_at`'s branch on the
tag, which LLVM does not unswitch out of a large loop. It is predicted and cheap, but
`csv_parse` pays 3% against the older scratch-store form, and forcing unswitching does not
recover it. The fix is to resolve a String binding at the caller (re-resolving a `let mut` at
each assignment) and let `byteAt`/`charAt` on a resolved binding use the pointer
(`RESULTS-unicode-18.md` §12).

### A string literal in a curated runtime function breaks the link

`ir_curate_module` copies a function body into the user's module as `available_externally` and
turns every global it does not copy into an initializer-less external declaration (read in
`../runtime/llvm-api-backend.c`, 2026-10-09), so adding a `fprintf(stderr, "...")` to a curated
function makes every program fail with `Undefined symbols: "_.str.16"`. The guard is
`run_curated_closure_test` in `../tests/test_runner.py`, which asserts that nothing curated
references one, so the suite finds it. **What is not guarded is the confusion**: it reproduces with a compiler
built *before* the edit, because `build_driver.c` compiles `runtime/*.c` from the working tree,
which costs a confusing hour. Either copy referenced constants during curation or refuse to
curate a function that references one. *The link failure itself was not re-run.*

### `list_push_slot` is not curated, and the reason is performance

Until it is, a struct literal pushed into a container cannot take a struct-path TBAA tag: the
widened store the tag enables is a 0.76x win where the optimiser can see the destination and a
2.74x loss against this call (`RESULTS-M6-struct-path-tbaa.md`). `list_push_slot` is still absent
from `PRISMIO_CURATED_OPS` (`../runtime/build_driver.c`, checked 2026-10-09); the closure blocker is
gone (`list_push_slot_boxed` carries `rt_alloc`'s statics), and one line there would turn it on,
but that inlines the fast path into every push site and reproduces the regression
`RESULTS-inline-push-rejected.md` recorded (`world_spawn` 37 -> 115 instructions in g6). **Do not
flip it without the pushes-per-list profile that file asks for**; the static proxy does not work
either, since g2's `cull` and g6's `plan_orders` both build with `list_new()`.

### The flat-list loop guard's code-size cost is a policy question

**Not re-run.** `list_get` on a flat element type emits its own address arithmetic guarded by
`elem_size == stride`; every flat receiver in a loop is ANDed into one preheader guard, so LLVM
versions the loop twice however many lists it walks, and any loop containing another call is
declined. g4 is 0.941x and g6 0.933x, at **+58% compile time and +34% binary** for the loops
that qualify (g2, g6: for 4.2% and 6.7%). A minimum-flat-sites threshold would decline the loops
whose duplication does not pay and has not been tried. `-mllvm -enable-nontrivial-unswitch`
cannot be removed (without it LLVM never clones the loop). `list_set` is still untouched, and
`!invariant.load` on the `List` header is **unsound** because `list_push` rewrites it
(`RESULTS-flat-list-view.md`, `RESULTS-loop-unswitch.md`).

### Storing an element read of a flat struct boxes and counts the whole type

**Not re-run.** An element read stored into a container is a second holder, and for a struct of
scalars that is more than it needs: a `Vec` would store it inline and copy. What stops that is
the inline store itself: `list_push_inline` releases its source through `list_release_source`,
which refuses only an address in the destination's own block, so a view into *another* list
would be freed as an allocation. The shape that pays is a flat element moved within its own
list (`test_145_list_set_within_list`), sound inline once and boxed now; no benchmark or corpus
program moved. The fix is an inline store that copies from a view without releasing it (a new
runtime entry codegen chooses for an element read), after which the solver can exempt flat types
from both rules.

### Three workloads read slower under internal linkage

**Not re-run.** indirect_calls 1.08x of the external-linkage build (IPSCCP proves an argument's
range, LLVM narrows `% 1009` to 16 bits, and AArch64's 16-bit constant division is the longer
sequence), graph_bfs 1.06x (branch arrangement), flat_bitset 1.03-1.10x run to run (its fallback
never executes; likely layout). The suite as a whole is 0.978x. Not fixed.

### `lz4`'s input fill is ~30% slower than an instruction-identical C loop

**Not re-run.** One shot per process, a standalone copy spends 312 us of 404 in the fill (a
`seed` recurrence plus one push per byte); a C loop with the same instructions runs it in 237 us.
Versioning push loops on the capacity guard made Prismio's loop C++'s exactly and changed
nothing. Ruled out: the clock ramp, first-touch paging, the allocation (4 us) and the main
loop's bounds checks. The reason is **not found** (`RESULTS-relational-tier.md`).

---

## Freestanding and the Linux kernel

The features a kernel module needs that Prismio does not have yet are listed, by name, in
[`LINUX_PLAN.md`](LINUX_PLAN.md); measurements are in
[`LINUX_BENCHMARKS.md`](LINUX_BENCHMARKS.md) and the language side is
[`FREESTANDING_PLAN.md`](FREESTANDING_PLAN.md). Not repeated here.

### `heapsort` is the one freestanding row behind C, by 1.9%

Re-read from the benchmark results of 2026-10-09: `heapsort` runs 10,907,440 instructions against
C's 10,702,272 (1.019x), inside the suite's +-2% parity band, and the suite is 5 wins, 15 parity and
0 losses against C (geomean 0.947); every other row is level with C or ahead. It is the overflow
difference again: `root * 2 + 1` in `sift`'s loop condition needs `nsw` to become C's code, and `root =
pick` is no counter, so neither the access facts, the counted loops nor the guards reach it. The
recipe is measured: a guard `start >= 0 and end >= -1` on `sift`'s parameters, plus `root >= 0`
carried through `root = pick` (`pick` was accessed), makes the multiply and the add `nsw`, and the
row reads 10,555,648 (0.986x). That needs `mul nsw` as well (`BINOP(ir_mul_nsw, LLVMBuildNSWMul)` and
a bridge extern). Emit it as the frontend's two loop copies: a function-level emulation measured
+0.7% from pass ordering. It is fragile: with only the access facts off (`PRISMIO_NOWRAP=0`) the row
reads 11,108,928, because an inlining decision near its threshold flips.

---

## Language surface

**`mut` does not reach through a struct.** A Vec's, array's or Slice's contents change only
through a `let mut` binding or an `inout` parameter (`semaCheckMutablePlace`), but a struct field
is assignable through any binding, so `bag.items.push(x)` needs no `mut` on `bag` (a program that
does exactly that compiles, 2026-10-09). That is the struct-by-reference rule `variables.md`
states; tightening it is a language decision.

**A program's own function shadows a library method with the same signature, at the program's
call sites only.** This replaces a longer note that said such a program did not compile:
`fn concat(a: String, b: String)`, `fn isDigit(c: Char)`, `fn equals`, `fn compare`, `fn slice`
and `fn strLength` all build now (2026-10-09), `"a" + "b"` and `for c in s` still work beside
them, and the library's own calls (`trim`, `toUpper`, `split`, `replace`, ...) are unaffected. The
consequence to know: `"abc".charAt(1)` calls the program's `charAt(String, Int)` when it defines
one. `tests/test_252_names_beside_std_generics.psm` pins the generic half.

**`T.default()` for a generic *type* argument.** A qualifier that is a type parameter becomes the
concrete type in a generic body, and `Box<Int>` becomes a call to the `Box.default` template with
`Int` as its argument, but only for a function the generic type's own `impl<T> Box<T>` declares.
An instantiation's mangled name (`Box$Int`) is never looked up as a qualifier. Reproduced
2026-10-09 with `impl<T: Default> Default for Box<T>` and
`fn make<T: Default>() -> T { return T.default() }` called as `let c: Box<Int> = make()`:
*unknown function `default`*. (A generic function's type argument **is** inferred from the
expected return type now, so `make()` with an annotation resolves; this is the only part left.)

**Two kinds of array are shared by a second binding rather than copied.** An array of arrays is
not copied by `let g = grid` (the rows are separate frame slots a byte copy would not reach), so
`g[0][0] = 5` changes `grid` (re-checked 2026-10-09: it printed `5`); an array of owning elements
is not either, because a byte copy would put each element under two owners (its elements cannot
be stored through an index, so that sharing is not observable). Both need an element-wise copy.
A `[T]` parameter is a view by design.

**`pop` and `removeAt` copy the element out, so they need `T: Copy`** (`pop` answers a `T?`;
`../std/vec.psm`). A moving version needs the caller to become the element's owner with the
disposition the Vec would have used, and AIF has no rule for ownership leaving a container:
modelled as a view the element leaks, as a fresh value a counted element is freed twice. They
are library functions, so a Vec they are called on is also "lent" and its later removals park
(`COLLECTIONS.md` 1e).

**An array parameter has no length of its own.** A `[T]` parameter is a view that compiles once
for every length rather than once per length (`COLLECTIONS.md` step 3). A generic struct and an
enum payload cannot hold an array yet. (`Vec<T, N>` and `Slice<T>`'s two layouts are steps 4 and
5, not started.)

**Array indexing is unchecked.** `a[i]` on an `Array<T, N>` or `[T]` is not bounds-checked in any
profile, and the docs say so (`arrays-and-lists`: *the language does not yet promise a portable
bounds-check trap for every array index*). An index past either end reads (or, on a `let mut`
array, writes) the neighbouring stack slot; a negative one does the same below the array. A
three-element array read at index 5 printed `0` and did not trap (2026-10-09). The same read on a
`Vec` returns `0`, and a `Slice` is bounds-checked, so the three do not agree. Checking costs the
loops the benchmarks measure (`PERFORMANCE_PLAN.md`: `quicksort`'s partition loop is already
bounds-check bound), so the fix is a range proof that elides the check where it can, not a
blanket one.

**A resolved path dependency is not on the import search.** Vendor source below the entry root. A
build that declares a dependency says so (`P1081`).

**`wrapping_*` / `checked_*` / `saturating_*` intent forms do not exist** (`a.wrapping_add(1)` is
*unknown function*, 2026-10-09). `--overflow-checks` is the debug-mode check and the debug
profile turns it on. Until the intent forms exist, the check never applies inside the standard
library (`diag_file_module(...).startsWith("std.")` in `../src/ir/expr.psm`), which relies on
wrapping (`keyMixWide` multiplies a U64 on purpose), and a user program that wraps on purpose
has no way to say so.

**`Char` is a byte, not a Unicode scalar.** That is a decision: it makes a scan one comparison
per byte, and `std.string` carries `scalarCount`, `scalars`, `scalarAt` and the rest as the second
reading; `std.unicode` has graphemes, NFC/NFD and width at Unicode 18.0.0; case mapping is the
Standard's default full mapping. What remains is **language-specific casing** (Turkish and Azeri
`i`, Lithuanian accented `i`), because a `String` does not know its language, and that the names
still say "char" for a byte (`chars()`, `charAt`, `Char`) beside `scalars()` and `graphemes()`.

**A diagnostic's carets assume one column per character.** *Not re-run.* They count characters,
not bytes, but an East Asian wide character or an emoji takes two terminal columns and one caret,
because the width tables are in `std.unicode`, not `runtime/diagnostics.c`. JSON diagnostics are
unaffected (their columns are bytes; `../IDE_PROTOCOL.md`).

**A trait cannot declare a property.** *Not re-run.* `prop` is accepted at top level and in an
`impl`, but a trait's signatures are `fn` only, so an `impl Trait for T` cannot satisfy a method
by a property or the reverse. Calling a property as a plain function, `length(s)`, is allowed on
purpose (`semaCheckPropertySpelling` checks only `x.f()` and `x.f`).

**A function that always fails is not known to diverge.** `panic`, `unreachable` and `exit` end a
block for sema (`semaCallNeverReturns`), but

```
fn fail(m: String) {
    eprintln(m)
    exit(1)
}
fn f(x: Int) -> Int {
    if (x > 0) { return x }
    fail("neg")
}
```

is *"function `f` must return Int on every path, but control can reach its closing brace"*
(2026-10-09), so a caller still needs a `return` after calling it. Inferring it from the body
would not work across a `.plib`, where the body is not parsed; a `Never` return type is the
planned fix.

**A list literal needs `import std.vec`.** `p.arguments = ["a"]` in a file that imports only
`std.process` fails with "`vecOf$String` is declared in `std.vec`, which this file does not
import" (2026-10-09).

**`std.process` starts a program with an argument vector, and that is all.** It has no
`runCommand` (replaced by the vector), and `kill` and `wait` exist. Still open:

- A child has no working directory or environment of its own; it inherits this process's
  (`process.setEnv` before `spawn` passes a variable).
- A stream is inherited, piped or discarded, never a file. A file needs a fourth mode on both
  sides of the wire protocol (`0` inherit, `1` pipe, `2` discard, in `../std/process.psm` and
  `program_support.c`).
- One spawn can be under construction at a time: the argument vector crosses one element at a time
  into file-local C state, so two threads spawning at once interleave into one vector.
- Nothing reaps an unwaited `Child`: a zombie on POSIX, an open handle on Windows (the comment above
  `Child` in `../std/process.psm` says so).
- On Windows `exec` is `_execvp`, which starts a new process and ends this one, so a parent
  waiting on the original does not get the replacement's status (`test_153_subprocess` skips that
  assertion there). Descriptors are CRT `int`s from `_open_osfhandle`, in text mode. *Not re-run
  (no Windows host).*
- Ownership: see [Assigning a struct field](#assigning-a-struct-field-releases-the-value-it-replaces-only-for-a-fresh-local)
  and [Struct fields that may hold a string literal](#struct-fields-that-may-hold-a-string-literal-are-never-released).

**An unsized array cannot be a type argument.** `Box<[Int]>`, `Result<[Int], String>` and `Vec<[Int]>` are
refused (`monoArgsHoldArray`; neg_198, neg_199) because the array would point into a frame that may be
gone. A generic function's own `T` may still be an array (`id<T>(x: T) -> T` returns the view), which
`test_163` relies on.

---

## Traits

All 21 trait milestones are implemented and documented in `../docs` (`content/language/traits.md`,
`generics.md`). What follows was deliberately left out. **Not re-run**: these are design
statements, and the only one with a mechanical check, `Eq`, was confirmed.

**Trait objects are borrowed-only.** Storing or returning a `dyn Trait` needs a destructor slot in
every vtable, an indirect call on release, and AIF learning a type whose release it cannot see. The
representation (a fat pointer with relative 4-byte vtable offsets) was chosen so this is an
addition, not a change.

**An unqualified call still resolves through the global overload set.** Methods no longer collide
and have a qualified spelling, but the unqualified form does not resolve through in-scope traits.

**`dyn Trait<Item = Int>` is refused.** Object safety rejects any trait with an associated type.
Pinning it at the use site costs nothing at run time and would make `Iterator` object-safe; the
equality-constraint machinery already exists.

**There is no `Drop`-shaped trait.** It interacts with AIF's release placement and needs its own
design pass.

**`Eq` covers the builtins only.** `../std/eq.psm` has no instance for `Map` or `Vec` (checked
2026-10-09).

**An `impl Trait` return type must be apparent in the `return`**: a struct literal, or a call to a
function whose return type is written out. The pass that resolves it runs before any body is
checked, so it has no inferred types to read.

**`impl Trait` opacity is not enforced against the caller.** The concrete type is resolved and the
annotation rewritten, so `let p: Point = makePoint()` still type-checks. Dispatch is static and
correct; the abstraction barrier is what is missing, and closing it means keeping the return type
distinct through checking rather than rewriting it.

---

## Concurrency

The plan for channels and tasks is `CHANNELS_PLAN.md`.

**A received value leaks when its name was also sent from.** AIF keys a local by function and name
(`aif_key_var`), so `let v = ...; c.send(v)` and a later `for v in c` in the same function share
one value set; the received value takes the send's escape and is never released.

```
let c = Channel<Note>(4)
let v = Note { text: "a text long enough for the heap ".concat("x") }
c.send(v)
c.close()
for v in c { println(v.text.length) }     // 3 allocated, 1 released, 2 leaked
c.free()
```

Renaming the loop variable (`for w in c`) reads 3 allocated, 3 released. A leak, not a double
free. The fix is per-declaration binding keys, in the engine and the oracle together; it is the
same name-keying that makes `test_205`'s inner `let a = a` keep its refusal.

**A `spawn` not proved joined leaks its owned temporary arguments.** *Not re-run.* The temporary
is released at the scope exit only when the join is proved (the E-SPAWN-J proof the task handle
uses); otherwise it leaks, which is the conservative direction
(`RESULTS-spawn-owned-argument.md`).

**Nothing checks the destruction order, and a send on a closed channel does not hand the value
back.** A `send` on a closed channel answers `false` and releases the message
(`../tests/test_235_channel_owned_messages.psm`); handing it back to the sender is not done.
`chan_share` returns the same pointer and `chan_free` assumes no one is blocked on the channel:
close, join every task that was given a share, then free ([channel rule
4](https://developers.prismio.org/runtime/tasks-and-channels#the-four-channel-rules)). Handing an
undelivered message back and counted endpoints are `CHANNELS_PLAN.md` Phases 0 and 1.

---

## Toolchain, packaging and tests

**`prismio suite` cannot run the ums host-routing fixture.** That fixture deletes and re-promotes
the project host to exercise stage-0 -> project-local promotion, and the `prismio` process running
the command is using that file. `python3 tools/run_suite.py` tests a *copy* of the compiler, which
fixed the other three fixtures with the same shape, and is the release gate; this one needs the
outer process not to be the compiler at all (`build.ums` carries the same note above its `suite`
command).

**Linking needs the platform's C toolchain**: `cc` on macOS and Linux, MSVC's `link.exe` with the
Windows SDK on Windows (`PRISMIO_CC` overrides both). It is where the C library and the SDK come
from, so shipping a linker would not remove it. **Embedding LLD was tried and stopped
(2026-09-24)**: it would drop `cc` and nothing else a user installs, on Linux it still needs the C
library package and gcc's `crtbegin.o`, and it cannot read the macOS 27 SDK (every stub lists
`arm64e.x1-macos`, which TextAPI 23 rejects; a whole-SDK rewrite of 6,837 stubs was the price). LLD
earns its place alongside shipped libc/SDK stubs, as in Zig, and not before. Darwin/x86_64 has no
LLVM 23.1.x archive; setup refuses it and names `--llvm-dir`.

**A program's own struct handed to C that reads its fields can be permuted.** LAYOUT 7.2 orders a
struct's fields by padding, width, then the program's access count; `std` structs keep declaration
order, but a program's own does not, and `ptr_to_node` and `proc_spawn_run` are both "an `extern fn`
taking a struct" where only the second reads a field, which nothing in a declaration says. A
three-field struct with two fields of equal width is enough. `SpawnOut` is safe only because it is a
`std` type. **Marking the struct `repr(C)` or `packed` keeps declaration order**; an unmarked one is
still the compiler's to order.

**Other per-compilation decisions about a `std` type are made twice.** Which fields a type releases,
and whether a boxed enum is null-tagged, are each decided by the library compile and again by the
program. A `String?` returned by `stripPrefix` and read in a program that also reserves
null for it answered correctly out of tree; that is one probe, not an argument.

**A bare `tools/bootstrap.sh` generation in `../build` is not a complete compiler.** A compiler is a
layout (`bin/`, `lib/runtime/*.bc`, `stdlib/*.plib`), not a file, and a generation builds the
compiler and nothing else. `prismio build` leaves the full toolchain beside the project host;
point `tests/test_runner.py --compiler` at that, or at a packaged `dist`, or package the generation
first.

**Almost nothing in `../tests` reads a `.plib`.** `std.*` resolves by walking up from the *entry
file* ([search order](https://developers.prismio.org/runtime/supported-surface#standard-module-search-order)),
so every fixture under `../tests` compiles `../std` from source and a defect on the installed path
is invisible to the suite (`sort()` failed to link from every installed stdlib that way, with the
suite green). `run_module_artifact_test` builds `sort`, `std.platform` and a `std.process` struct
against the packaged toolchain and `run_ums_test` builds a program outside the checkout; everything
else a user reaches only through a `.plib` is untested. **The same holds for A/B work**: from inside
the checkout the compiler reads `std/` from source, so a std change is visible to the *old*
compiler too; build probes out of tree.

**Nothing packages a cross target by default.** `tools/package.py --target <triple> --sysroot
<triple>=<path>` does and needs that target's C headers; `../tools/release.py` builds one archive
per host with no `--target` (its options are `--compiler`/`--build-with`, `--version`, `--out`), so
a released toolchain cross-builds nothing (with a message, not a mixed module). A triple is
matched by its spelling (`x86_64-apple-macos` and `x86_64-apple-macosx` are two sections), and
`shouldEmitFunctionFromSource` still compiles every `__builtin_target_*` function into the program.

---

## Platform

**Windows differs on purpose in two behaviours.** Descriptor 1 is in the CRT's **text mode**, so a
`\n` reaches the console as `\r\n` and a Windows program's stdout is not byte-identical to a POSIX
one; and there is **no SIGPIPE**, so a write to a closed pipe returns an error and the retry loop
stops where a POSIX program dies of the signal. Neither is a defect to fix without deciding what
`print` should mean on a platform whose console is not a byte pipe.

**A compiler self-hosted on Windows has no export table.** Written down rather than done because it
cannot be verified from a macOS host.

**`--target` and `test_76_std_fs` on Windows** are not reproducible off a Windows runner and are
open there.

**WebAssembly is blocked, not in progress.** Prismio emits wasm32 IR, but there is no C library for
`wasm32-unknown-unknown`, so the runtime cannot be built for it from this repository. A cross build
with no shipped runtime archive stops and names the file it looked for, but **the message blames the
installation**: `prismio build hello.psm --target wasm32-unknown-unknown` prints *"Prismio
installation is incomplete or corrupted. Missing runtime module:
lib/runtime/wasm32-unknown-unknown/lang_runtime.bc. Reinstall Prismio and try again"* (2026-10-09),
and reinstalling cannot help. The same "blocked" sentence is on the docs site
(`../../website/apps/docs/content/roadmap.md`, a sibling repository), so the two move together.

**The Windows ARM64 and Linux ARM64 archives are built and tested on virtual machines**, not CI, so
they have had less use than macOS arm64, Linux x64 and Windows x64.

---

## Measuring this compiler

Guidance rather than defects: each of these has produced a wrong conclusion at least once.

**Check mnemonics before believing a single-workload move.** `bytecode_interpreter` moved 19%
(19.2 -> 22.9 ms, reproducibly) when an unrelated function changed size, with its own function
byte-identical and 64 bytes lower in the binary: what moved is its placement, which is what the
branch predictor and instruction TLB see. `fft` and `knapsack` showed the same on 2026-09-04, and on
2026-10-07 four workloads moved 7-10% (`switch_dispatch`, `gcd_lcm`, `tokenization` slower,
`aos_vs_soa` faster) while none of their functions' IR had changed. Run
`../tools/fn_mnemonic_diff.py`, and compare against a second run of the *same* compiler: its
run-to-run noise is 1.1% median and 4.8% at the 90th percentile.

**Codegen stays at LLVM's defaults.** Aligning code wholesale moves the lottery: over the full suite
`-align-all-functions=5` reads 1.065x and `=6` 1.024x, and at 64 bytes `bytecode_interpreter`
improves to 0.85x while `edit_distance` regresses to 1.24x; branch-target and loop alignment trade
the same way. `PRISMIO_LLVM_ARGS` (appends LLVM options to codegen, like rustc's `-C llvm-args`) is a
measurement switch, not a supported mode, and an option LLVM does not recognise ends the process.

**Phase-time a memory benchmark one shot per process.** Every `../benchmarks` entry runs once per
process; looping the same workload inside one makes a different program (`benchLargeBufferCopy`'s
fill settles to 0.55 ms warm and is 2.2 ms one shot, because `rt_base_alloc` recycles the block and
the pages stay faulted in), and the difference inverts the cross-language comparison. The same trap
caught the `Vec`-literal reproduction above: a loop the optimiser can fold measures nothing.

**The historical g5 benchmark was not measurable at its original granularity** (an A/A calibration
reported 1.266x). Its useful axes are `hashmap_insert_lookup`, `key_value_update` and
`nested_collection` under `../benchmarks/hosted`; use their checksums and repeated medians.

**A green check can be vacuous, and a proxy is not the property.** A fixture can pass while placing no
arena at all, so assert that the thing is present before asserting that it is correct; and a check that
counts a symbol measures a stand-in, so when the stand-in and the property disagree it is usually the
check that is stale. The same holds for a whole-program ledger: `test_259` once read 1 leaked block and
meant nothing, because the program failed its own assertion first.

**A balanced `--verify` ledger proves less than it looks.** Two releases can both be ledger-legal and
the answer still wrong (`optionOr(s.stripPrefix("x"), "!")` once read `4 allocated, 4 released` and
returned `""`). Assert values as well (`../tests/test_92_field_view_provenance.psm`). **`--verify` also cannot see a
use-after-free**: its allocator does not reuse a freed block at once, so a String read after its
release still reads its old bytes and the ledger stays balanced. `test_273_match_payload_returned`
is the case (`let r = parse(t); match (r) { Result.Ok(v) => { return v } ... }` printed eight NUL
bytes in an ordinary build and passed under `--verify`); it asserts the values, and the suite runs
it both ways.

**Two halves of the string hash must answer identically.** A five-byte view and a five-byte inline
string are the same key and only one reaches the runtime, so `str_hash`'s twelve-byte path assembles
the same two zero-padded words the pair holds and runs the same arithmetic as
`__builtin_string_hash`. `tests/test_147` pins it at every length across the boundary; drifting the
runtime's cutoff by one fails it.

**A new fast/slow split needs `cold` or `PRISMIO_NOINLINE`.** Since 2026-09-28 a closed executable
internalises every function but `main`, and LLVM inlines an internal function's only call whatever
its size, so a slow half kept apart by size alone is folded back into its fast half, which then grows
too large to inline into the caller's loop (key_value_update 1.28x, quicksort 1.13x until marked).
**Nothing diagnoses a missing marker; the benchmark suite does**
(`RESULTS-binary-size-and-compile-time.md`).

**`s_expression_parse`'s Prismio arm** stores its nodes in a flat `Vec<Int>` where the C++ and Rust
arms allocate one per expression (`../benchmarks/README.md`). It could now be written the other way.
