# AIF research, round 2: the leak audit, two new shapes, and what to build

Written 2026-11-22, after `RESEARCH_P1_RESIDUE.md` and `RESEARCH_P9_LEVERS.md`. It covers prompts 3
and 4 of `RESEARCH_BRIEF.md` (field keys shared by type, views without lifetimes) and ends with
the ranked list that prompt 10 asked for. **Nothing is built.** This is the input for the build
session.

All numbers come from the release host at `5757802`, on macOS. Every probe's source is inline below,
so each one can be rebuilt and kept as a fixture.

## 1 · The leak audit, re-run

All 774 programs in `tests/` were built with `--verify` and run with a 10 s timeout. The
KNOWN_ISSUES table it replaces is from 2026-10-09.

- 371 programs printed a ledger. Together they show **0 violations**, and **828 leaked blocks in
  27 programs**.
- 378 programs did not build. They are negative tests: `P4001`, `P3201` and `P1011` are the
  expected outcomes.
- 25 programs built and printed no ledger. They are `Ptr` and array IR probes.
- Every count the harness pins (`run_aif_verify_test`) matches what was measured, so nothing has
  regressed.

| Leaked | Program | Cause | Fix in §3 |
|---:|---|---|---|
| 300 / 400 | `test_273_match_payload_returned` | a match binder returned while the scrutinee binding is dead | **2** |
| 300 / 320 | `test_321_field_store_parks` | a view live across a field store; pinned by design | not a bug |
| 100 / 101 | `test_58_region_serves` | a value that escapes its `region` falls back to the heap with no release | 8 |
| 59 / 62 | `test_352_global_store_escapes` | a value stored into a module global | **5** |
| 10 | `test_205_return_on_one_path` | `let t = a; return t` | 9 |
| 9 | `test_269_struct_pass_through_escapes` | one of two parameters returned | 9 |
| 6 / 6 | `test_100_reuse_token` | reuse tokens and a collected cycle | |
| 6 | `test_127_enum_null_variant` | recursive enums built by helpers; cause not isolated | |
| 5 | `test_191_option_methods` | `concat` through `T?` methods: the shared library site | 3 and prompt 2 |
| 4 + 4 + 2 | `test_185`, `test_53`, `fixture_slice_escape` | a view that outlives its base's binding | 9 (copy-on-escape) |
| 4 | `test_69_task_results` | a `join` result from a copyable handle | prompt 8 |
| 2 | `test_302_struct_in_two_vecs` | one factory site held in two Vecs | **3** |
| 2 + 1 | `binder_rewrap_probe`, `binder_return_probe` | a binder rewrapped or returned | **2** |
| ≤ 2 each | `fixture_slice_bounds*`, `range_direction_probe` | the process ends on a run-time error on purpose | not leaks |
| 1 each | `option_methods_probe`, `test_171`, `test_290`, `test_357`, `test_384`, `test_44`, `test_67`, `test_319` | small ones; not isolated | |

**What the suite does not show.** Its fixtures are written to sit next to known shapes. The two
probes below were written as ordinary code, and each one leaks more than the whole suite's
largest fixture.

## 2 · Two shapes that ordinary code hits

### 2.1 · One shared element makes a whole factory leak (prompt 3; cause C of prompt 1)

```prismio
import std.string

struct Item { name: String, qty: Int }

fn makeItem(i: Int) -> Item {
    return Item { name: "an-item-name-longer-than-twelve-".concat(i.toString()), qty: i }
}

fn main() -> Int {
    let mut all: Vec<Item> = []
    for i in 0..<200 { all.push(makeItem(i)) }
    let mut total = 0
    for i in 0..<all.length { total = total + all[i].name.length + all[i].qty }
    let mut fav: Vec<Item> = []      // these three lines
    fav.push(all[3])                 // are the only
    total = total + fav.length       // difference
    return total % 256
}
```

| Version | `--verify` |
|---|---|
| without the `fav` lines | 408 allocated, 408 released, **0 leaked** |
| with them | 410 allocated, 210 released, **200 leaked** |

- `fav.push(all[3])` stores an element read, so one `Item` is in two Vecs. That sharing is real.
  `A-CONTAIN` makes the one `makeItem` site T3, and the items are counted and freed.
- `A-STORE` then makes every item's `name` Shared, and a `String` has no header, so every name
  leaks, all 200 of them, not only item 3's.
- It also reaches `concat`'s site. That site is one for the whole program, so every `concat`
  result anywhere becomes `rc:none`.
- Per-site field keys do not help: `prismio aif --theta-fields` gives the same tiers. A static
  analysis cannot single out item 3 either, because it is one site and a run-time index.
- **The fix is mechanism 3** (owned by its counted holder): the item is counted, and its name has
  exactly one holder.

### 2.2 · Taking a field out of a dying local struct (prompt 4)

```prismio
import std.string

struct Bag { label: String, items: Vec<String> }

fn itemsOf(i: Int) -> Vec<String> {
    let mut v: Vec<String> = []
    v.push("an-element-longer-than-twelve-".concat(i.toString()))
    let bag = Bag { label: "a-label-longer-than-twelve-".concat(i.toString()), items: v }
    return bag.items
}

fn keepInto(i: Int, inout keep: Vec<Vec<String>>) {
    let mut v: Vec<String> = []
    v.push("an-element-longer-than-twelve-".concat(i.toString()))
    let bag = Bag { label: "a-label-longer-than-twelve-".concat(i.toString()), items: v }
    keep.push(bag.items)
}

fn main() -> Int {
    let mut total = 0
    let mut keep: Vec<Vec<String>> = []
    for i in 0..<100 {
        let xs = itemsOf(i)
        total = total + xs.length
        keepInto(i, keep)
    }
    return (total + keep.length) % 256
}
```

| Version | `--verify` |
|---|---|
| both functions | 907 allocated, 7 released, **900 leaked** |
| `itemsOf` alone | 501 allocated, 1 released, **500 leaked** |
| `keepInto` alone | 507 allocated, 107 released, **400 leaked** |
| `itemsOf`'s shape with `bag` made by a function (`let bag = makeBag(i)`) | 1000 allocated, 1000 released, 0 leaked |

- In `itemsOf`, `return bag.items` is a view of `bag`, so `E-VIEW` lifts `bag` to Caller. `bag` is
  then T2 on the heap with no release, and its label leaks. The caller receives a view it cannot
  free, so the Vec and its strings leak as well.
- In `keepInto`, the push stores a view, which is `A-CONTAIN` at line 16. Through `A-RETAIN` that
  makes the Vec sites and `concat`'s site Shared.
- The factory form is clean because codegen already handles the alias returned out of a binding
  that a callee allocated (`nodeReturnsAliasBeyondBare`). Frame-built structs and match binders
  miss that path.
- The KNOWN_ISSUES entry "A field value read out and returned or pushed" (Not re-run) is accurate,
  and much worse than it reads: the leak spreads to every `concat` in the program.

**The common cause with `test_273`.** A value taken out of a binding that is **dead right after** is
treated as a view, so the binding can never be released. `return v` from `Result.Ok(v)`,
`return bag.items` and `keep.push(bag.items)` all have this shape.

## 3 · What to build, ranked

Ranked by (measured effect) / (cost). Each entry names its fixture and how it can fail.

| # | Build | Prize, measured | Cost | Fails as |
|---|---|---|---|---|
| 1 | **`ptr_null() -> Ptr alias`**, plus an FFI check warning about an extern that returns `Ptr` with no return contract | 386 phantom sites removed; the compiler's T0–T2 share goes from 46% to 57% (P1 §2.A) | one word, plus a lint | nothing at run time; check the IR fixpoint |
| 2 | **Partial move at last use.** When the binding a field or payload is read from is dead after the statement, and that statement returns the value, pushes it or binds it with an owner, move it out. Load the field, store null into the slot, and let the binding's ordinary drop release the rest. `list_release(NULL)` and `rt_free(NULL)` already return early. | `test_273` 300 → 0, §2.2 900 → 0, `binder_*` 3 → 0 | medium: sema's last-use fact, codegen's move, the engine (no `E-VIEW` lift for a moved field), the oracle | a double free if the slot is not nulled, or if a second view of the binding is live. Guard it with the existing alias guards (`irValueAliasesName`, `chainRetainsAliasOf`). |
| 3 | **Owned by its counted holder** (P1 §4 C1) | §2.1 200 → 0, `test_302` 2 → 0, the compiler's 191 AST strings (blocked there by punning) | medium-high: a disposition in the engine and the oracle | a double free between the holder's release and a scope drop. Fixtures with the holder in two containers. |
| 4 | **Teardown elision when `main` returns** (P9 lever 1) | 0.70× on a 2M-node build-then-exit run | small | none outside `--verify`; keep teardown under `--verify`, `PRISMIO_SLAB=0` and freestanding |
| 5 | **A global slot is one owner** (P1 §4 B1): release a global's displaced value under the closed-column proof, widened to private globals | `test_352` 59 → 0; the compiler's 485 global sites become releasable on reset | medium | a double free when a view of the old value is live; the column proof already covers that case |
| 6 | **MEM-001: the allocation site in the ledger**, as a machine-readable report | an enabler: K for the embedded Vec, the prize of release-at-last-use, copy volumes | small-medium | none |
| 7 | **A 16-byte hot Vec header**, with the cold fields moved to an on-demand record (P9 lever 2, step 1) | `graph_churn` memory, 1.35–1.46× of C++ today | medium: runtime and codegen's list ABI | ABI drift between the curated runtime and codegen |
| 8 | A value that escapes its `region` gets an owner on its heap fallback | `test_58` 100 → 0 | unknown; prompt 7 | |
| 9 | Later: the pass-through guarded release (`test_269`), copy-on-escape for views (`test_185`/`test_53`), the renamed return (`test_205`), the embedded small Vec (P9 lever 2, step 2), compressed references (P9 lever 3), affine task handles (prompt 8) | | | |

**Round 3 adds three items** (`RESEARCH_ROUND3.md` §7). The **extern summary rule** goes right
after 1, and **storage agreement** for bindings and fields goes right after 2: `test_58`'s 100
leaked blocks are that rule, not regions. **`rt_free` that recognises arena memory** comes later,
after allocator stage 4.

**Round 4 adds** (`RESEARCH_ROUND4.md` §5): **item 0, the sanitizer gate**. Today ASan cannot see
the slab, and the gate's link leaves out std. It also adds **copies are owned allocations**, which
goes with the extern rule, and **a count for a genuinely shared `Vec`**, after item 3. Context-
sensitive library sites (F19) are probably unnecessary once items 2, 3 and 5 land.

**Decided 2026-11-22:** the middle IR (`docs/PIR_PLAN.md`) does not start now, so **item 2 is built
on the AST**, with F1 and F14. Its fixtures later become PIR P1's acceptance tests.

**The order for one session.** 0 (the sanitizer gate). Then 1, the extern summary rule, copies are
owned and 4 (all small and independent). Then 2, then storage agreement, then 3. Items 2 and 3
both change the engine and the oracle, so land them one at a time, each with its probe from §2 as a
`--verify` fixture held at 0 leaked, and its values asserted as well. A balanced ledger can hide a
wrong answer (`test_273`'s own header says so).

**What each change must pass** (CLAUDE.md):

- byte-identical output for every program its rule does not touch;
- a two-generation fixpoint, read in the IR;
- `prismio verify`, including `tools/aif_differential.py`;
- the pinned leak counts in `tests/test_runner.py`, lowered in the same commit as the fix;
- each KNOWN_ISSUES entry it closes, deleted in that commit.

None of the items needs new syntax, so none needs a seed cut before use.

## 3a · Missing features each item depends on

These are features that do not exist yet and that a research item cannot be built without. Each
was checked against the tree on 2026-11-22. **Kind** says what building it touches:

- **lang**: language syntax or semantics, so it needs a seed cut before `src/` can use it;
- **compiler**: sema, the engine or codegen;
- **runtime**: `runtime/*.c`;
- **tool**: diagnostics and measurement.

| # | Missing feature | Kind | Blocks | State in the tree |
|---|---|---|---|---|
| F1 | **A liveness query for codegen**: "is binding `x` dead after statement N, on every path?" | compiler | move at last use (item 2) | Partly there. The walk already counts each reference binding's last use per scope (`aif_var_note_use`, `src/aif/walk.psm:112`) and keeps statement cursors (`src/aifcore/extents.psm`), but only arena extents use them. Expose them as one query, and refuse when a view of `x` is live past N. |
| F2 | **Refusing a move out of a counted holder's field** | compiler (sema) | owned by its counted holder (item 3), obligation 4 | Missing. Sema refuses a move out of a borrowed value, not out of a T3 holder's field. Either add the refusal, or have item 3 decline wherever a move is seen. |
| F3 | **A "holder-owned" element and field disposition** in the engine and the oracle | compiler + oracle | item 3 | Missing. Today `fieldReleaseOf` agrees over sites, and a T3 `rc:none` site answers NONE. |
| F4 | **A no-contract rule for void and scalar returns and scalar parameters** | compiler + oracle | the extern summary rule | Missing (`contracts.psm:292` requires a return contract). There is also no lint that warns about an extern returning `Ptr` without one. |
| F5 | **Per-site allocation telemetry** (MEM-001): the site in the ledger, a length histogram at drop, a machine-readable report | tool + runtime | the embedded small Vec's K, the prize of release-at-last-use, copy volumes for shared strings | Partial. `--verify` counts, and gives sizes and a trace per leaked block, but no site identity and no report `benchmarks/run.py` can read. |
| F6 | **Allocator stage 4**: reserve with `PROT_NONE`, commit in steps, hand whole spans out | runtime | `rt_free` that recognises arena memory (round 3 §3), compressed references (P9 lever 3), strict overcommit on Linux | Missing: no `PROT_NONE` or `MADV_` in `lang_runtime.c`. |
| F7 | **Large blocks (> 512 B) and arena chunks inside the slab's reservation** | runtime | compressed references, arena-aware `rt_free` | Missing. Large blocks go to libc, and arena chunks to `malloc` (`arena_chunk_new`). |
| F8 | **Allocator stage 5**: decommit, and spans back to the OS | runtime | long-running programs; the fragmentation case for compaction | Missing. |
| F9 | **`--verify` that sees arena memory and the slab** (ALLOCATOR_PLAN stage 6) | runtime + tool | checking arena-aware `rt_free`; finding slab bugs | Missing. The ledger replaces the seam, so a verify build never runs the slab. |
| F10 | **Read-after-free detection** in the verify build | runtime + tool | trusting any release-moving change (items 2, 3, 5) | Missing. The ledger poisons released storage, but a read of it goes undetected (ARCHITECTURE-DIRECTION §7). Today the only defence is fixtures that assert values. |
| F11 | **Type size available to sema** (REQUIREMENTS 18) | compiler | payload enums as unions (MEM-026), general niches (MEM-018), the embedded small Vec's layout | Partial. AIF computes target sizes (`aifComputeSizes`, `src/aif/layout.psm:286`) after layout, but `src/sema/enums.psm` lays enums out first and says so in its header. |
| F12 | **Non-flat structs stored inline in a Vec** (owning elements in slots) | compiler + runtime | `graph_churn`'s memory (P9 lever 2, step 1); the embedded small Vec | Missing for structs. `Vec<String>` already stores its pairs inline, which is the precedent. |
| F13 | **A compact Vec header** (data, len, cap hot; the rest on demand) | runtime + compiler (list ABI) | P9 lever 2 | Missing. `RtList` is 64 bytes. |
| F14 | **Field-level release with one field excluded**, or release functions that accept a nulled field for every field kind | compiler | move at last use, through slot nulling | Mostly there. `list_release(NULL)` and `rt_free(NULL)` return early. Check String pairs, enum payloads and counted fields. |
| F15 | **Per-target codegen switch for the arena-aware free** | compiler | round 3 §3 on Windows, freestanding, or with a refused reservation | Missing. |
| F16 | **Affine task handles**, or `join` that returns a copy | lang (affine) or compiler (copy) | task-result leaks (`test_69`), prompt 8 | Missing. The handle is copyable. |
| F17 | **Task frames over 3 word-sized arguments** (MEM-016) | runtime + compiler | concurrency workloads with richer task arguments | Missing (`prismio_task_spawn(fn, rkind, nargs, a0, a1, a2)`). |
| F18 | **A view-materialising copy at a scope exit** (copy-on-escape) | compiler | views outliving their base (`test_185`, `test_53`, `fixture_slice_escape`) | Missing. |
| F19 | **Ownership-context specialisation** (INFERENCE §6–7) | compiler | context-sensitive library sites (`concat`, prompt 2); regime (b), if the arena-aware free is not built | Missing. Only the regime-(a) bracketing clauses exist. |
| F20 | **`--theta-fields` (per-site field keys) in codegen** | compiler | measuring object sensitivity on real releases | Missing. It is accepted by `prismio aif` only, and gave the same tiers as without it on §2.1's probe. |
| F21 | **A destructor slot in `dyn Trait` vtables** | lang + compiler | storing or returning trait objects; AIF over them | Missing (KNOWN_ISSUES, Traits). Not needed for any item above. |
| F22 | **A typed AST in the compiler** (`ASTNode?` fields, not `Ptr` puns) | compiler (refactor of `src/`) | item 3 reaching the compiler's own 191 AST strings (`fieldReleaseOf` declines punned fields) | A large refactor, and only the compiler benefits. Ordinary programs get item 3 without it. |
| F23 | **A global Vec initialiser** (`let mut g: Vec<Int> = []` at module level) | lang or compiler | a global-slot owner (item 5) starting from a real empty Vec | Missing (`global ... needs a constant initializer`). A zero-filled global Vec is not an empty one (KNOWN_ISSUES). |

**Dependencies.** Items 1, 4 and the extern rule need none of these (F4 is that rule). Item 2 needs
F1 and F14. Item 3 needs F2 and F3. Item 5 benefits from F23. Round 3 §3 needs F6, F7, F9 and F15.
P9 lever 2 needs F5, F12 and F13, and F11 for its full layout. P9 lever 3 needs F6 and F7. **F10 is
the one to build early**, because every release-moving item is safer with it.

## 4 · Documentation this round found stale

- KNOWN_ISSUES "Struct fields that may hold a string literal are never released": **clean** for a
  plain `String` field (P1 §2.C). Its `Process` reproducer is still to re-run.
- KNOWN_ISSUES "What the test suite still leaks": superseded by §1 (2026-11-22).
- KNOWN_ISSUES "A struct on the frame: three field shapes still leak", first bullet: confirmed and
  measured (§2.2). Its numbers should be updated.
- The brief's §4.1: corrected in place.
