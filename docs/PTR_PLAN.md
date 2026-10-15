# `Ptr<T>`: a typed pointer

Status 2026-10-15: **stages 1-5 built** (the type and its conversions; reads through a pointer, `load()`,
the scalar projection, parameter attributes; writes through `Ptr<mut T>`; the address methods and the
`std.raw` constructors; volatile access and atomics with orderings). Stage 6 is open. Source: the "Transparent Capability Pointer"
proposal, corrected against this tree, plus the additions in §4. It closes the last open box of
`FREESTANDING_PLAN.md` step 3 ("a typed pointer, if the name-only convention proves too weak").

## 1. What exists today

| Piece | State | Where |
|---|---|---|
| `Ptr` (no argument) | an opaque, non-affine word: `TypeKind.PTR`, name `"Ptr"`, IR `ptr`. Foreign handles, `extern` signatures | `src/ast/types.psm:102` |
| `Future<R>`, `Channel<T>` | **PTR-kinded and named** (`name.startsWith("Channel<")`, pointee in `child`) so every PTR arm in sema, AIF and codegen keeps working. The template for `Ptr<T>` | `src/ast/types.psm:300-355`, `src/sema/types.psm:140-180` |
| `T?` on a pointer | already a nullable pointer, one register, no tag (`typeCanBeOptional` accepts PTR) | `src/ast/types.psm:370` |
| Address builtins | `addressOf(Ptr) -> Usize`, `pointerAt(Usize) -> Ptr`, plain/volatile/atomic loads and stores **by width on a `Usize`** | `std/raw.psm`, `std/mem.psm` |
| Method lowering on a built-in type | sema rewrites `c.send(x)` into builtins per call site | `src/sema/channel.psm` (189 lines) |
| `__builtin_*` | refused outside `std/`; sema may still write them into user code | `semaRefuseRuntimeCalls` |
| Packed / `repr(C)` structs | declaration order, C padding or none | `FREESTANDING_PLAN.md` step 4 |

## 2. Corrections to the proposal

| Proposal says | This language | Decision |
|---|---|---|
| `Int` is 8 bytes (`align 8`, `i64`) | **`Int` is i32** (`aif/evidence/RESULTS-int-width.md`). `Ptr<Int>.offset(1)` is 4 bytes | Use the real widths everywhere; `Int64` spells `I64` |
| snake_case: `byte_offset`, `is_aligned`, `read_volatile`, `as_slice` | CamelCase | `byteOffset`, `isAligned`, `readVolatile`, `asSlice` |
| `p.addr()` | reads are `prop`s, computations are methods; `x.sqrt()` is an error | `p.addr` is a **prop**, `p.isAligned(8)` a method |
| `p.cast::<U>()` | no turbofish in the grammar | `Ptr<U>.cast(p)`, a static on the target type |
| `if let Some(hdr) = bar` | no `if let`, no `Option`, and **no flow narrowing**: `if (bar != none)` does not change `bar`'s type | `let hdr = expect(bar)` or `bar ?? fallback`; the example in §3 is written that way |
| `Result<(), E>`, `log_info("{}")`, `fn` in `extern fn ... -> Ptr<Header>?` | not this language's spelling | examples rewritten in §3 |
| `while (...) { cpu_relax() }`, `uart.write_volatile_field(data, b)` | `write_volatile_field` is not definable | a volatile pointer's field write is volatile (§4.1) |
| `rw.counter += 1` | **compound assignment needs a plain variable on the left** (`P3302`: the desugaring names the target twice), for every field, not only through a pointer | write `rw.counter = rw.counter + 1`; widening the rule is a language change, not this plan's |
| "Kernel-grade safety" | `Ptr<T>` is still unchecked for liveness and bounds | stated plainly in §6; the `std.raw` import is the `unsafe` marker (§4.9) |
| Bare `Ptr` unmentioned | **`Ptr` stays as a spelling, not a separate design**: it is the pointer whose pointee is opaque and zero-sized. No field access, `load`, `store` or `offset`; no `dereferenceable`; non-affine; FFI unchanged. **`Ptr<mut T>` → `Ptr` is implicit; a read-only `Ptr<T>` is not**, because foreign code handed an opaque `Ptr` may write through it and the `readonly` parameter attribute would then be a lie (built, stage 2). The reverse is `Ptr<T>.cast(handle)`. One family, one set of rules, no new `TypeKind` | decided 2026-10-15 |

## 3. Surface

```
struct Header { magic: U32, payloadLength: U32, flags: U16 }

fn verify(p: Ptr<Header>) -> Bool {
    if (p.magic != 0x5052534D) { return false }   // load i32, ptr %p, align 4
    return p.payloadLength > 0
}

fn bump(counter: Ptr<mut Int>) { counter.store(counter + 1) }

fn update(ro: Ptr<Node>, rw: Ptr<mut Node>) {
    rw.value = 42
    rw.count += 1                     // ro.value = 1  -> error: `ro` is read-only
    let view: Ptr<Node> = rw          // mut -> const is implicit
}

extern fn pciBar(index: Int) -> Ptr<Header>?

fn init() -> Bool {
    let bar = pciBar(0)
    if (bar != none) { return expect(bar).magic == 0x5052534D }   // `expect` unwraps; there is no narrowing
    return false
}
```

**Projection rule (the one place the proposal was loose).** A `Ptr<T>` is read *through* in exactly
three places: (1) member access and indexing of a struct pointee; (2) an operand of arithmetic,
bitwise, comparison or logical operators whose other side is not a pointer, when `T` is a scalar;
(3) a position that annotates a scalar `T`. Everywhere else it is a pointer: `let q = p`, `f(p)`,
`return p`. Consequences, each a deliberate refusal:

- `p == q` with two pointers is an error that names `p.sameAs(q)` and `p.addr == q.addr`. C's
  silent identity compare and a value compare that reads the same are both traps.
- `let h: Header = p` is an error (it would copy a struct); `p.load()` says so.
- A pointer is not printable. `p.load()` or `p.addr` says what is meant.
- Whole-pointee writes are `p.store(v)`, never `p = v` (that rebinds).

**Pointee restriction (stage 1).** Plain data only: scalars, `Bool`, `Char`, `Ptr`, enums without
payloads, and structs of those (`repr(C)` or not). Storing a `String` or `Vec` through a pointer would
move an owner into memory nothing tracks, so `store` and field writes of owned types are refused; reading
an owned field gives a borrow, as any field read does.

## 4. Beyond Rust, C and C++

Each line is a gap in all three.

1. **Capabilities live in the type, and compose.** `Ptr<T>`, `Ptr<mut T>`, `Ptr<volatile T>`,
   `Ptr<mut volatile T>`. Every access through a volatile pointer is volatile, including field reads and
   `+=`, so a driver cannot forget one. C has the qualifier but no non-null; Rust has per-call
   `read_volatile` only. `readVolatile` and `writeVolatile` stay for the one-off.
2. **Non-null by construction, `T?` for the rest, zero cost.** C has no such thing; Rust's `NonNull`
   is a library wrapper with `.as_ptr()` ceremony.
3. **Optimiser facts from the type.** Parameters get `noundef nonnull align(A) dereferenceable(sizeof T)`
   and `readonly` when const. Rust gets this only for references, never for raw pointers; C/C++ for none
   without hand-written attributes. A `Ptr<T>?` parameter gets `noundef` only.
4. **Alignment-honest field access.** A field of a packed struct is read with the field's own alignment,
   so a `Ptr<Packed>` is legal and `p.flags` is an `align 1` load. Rust refuses the reference (E0793) and
   C warns; both need a copy-out dance.
5. **Address is data, pointer is a capability.** `p.addr` is a `Usize`. The only ways back are
   `Ptr<T>.at(address)` (returns `T?`: none for 0 *or* misaligned) and `Ptr<T>.atUnchecked(address)`.
   Strict provenance without an opt-in lint.
6. **Checked casts.** `Ptr<U>.cast(p)` is unchecked; `Ptr<U>.castAligned(p)` answers `U?`, none when the
   address cannot hold a `U`.
7. **Arithmetic you cannot confuse.** `p + 1` is always the value. Address motion is methods:
   `offset(n)` (`getelementptr inbounds`), `wrappingOffset(n)` (no `inbounds`: the form a ring buffer
   needs), `byteOffset(n)`, `offsetFrom(q)` (element distance), and
   **`advance(n, limit: q) -> Ptr<T>?`**, which answers none rather than step past `limit`. A bounded
   iteration loop with no UB window, which none of the three has.
8. **Atomics on the pointer, with orderings.** `p.atomicLoad(order)`, `store`, `exchange`,
   `compareExchange`, `fetchAdd`..., `order` one of `relaxed`, `acquire`, `release`, `acqRel`, `seqCst`.
   This also closes `FREESTANDING_PLAN.md`'s open "weaker orderings" box. C has `_Atomic` as a type
   transform, C++ `std::atomic_ref`, Rust only `AtomicPtr` and `from_ptr`.
9. **The unsafe marker is the import.** The type, loads, stores and the address methods are always
   available; the constructors from a number (`at`, `atUnchecked`) and `cast` are `std.raw`'s, behind the
   explicit-import gate that already exists. A file with no `import std.raw` cannot conjure a pointer. No
   new keyword, no `unsafe { }` ceremony around every read.
10. **`asSlice(count) -> Slice<T>`** forms the checked view, so the unchecked world ends at one call and
    the rest of the program indexes with bounds checks. (Stage 6: depends on AIF borrow rules for a
    `Slice` with no owner.)

Rejected: a `restrict`/`noalias` qualifier (AIF already proves uniqueness for owned values; add it when
a benchmark asks), pointer-to-local (`&x`; lifetime rules unwritten, which is the reason `FREESTANDING_PLAN`
refused a typed pointer in the first place), fat pointers by default (a `Slice` is the fat pointer).

## 5. Where it lands

Follow `Channel<T>`: PTR-kinded, `name` = `Ptr<T>` / `Ptr<mut T>`, pointee in `child`, flags in the key.

| Stage | Work | Files |
|---|---|---|
| 1 | Parse `mut` and `volatile` in a type-argument list. `typePtrTo(pointee, mut, volatile)`, `typeIsTypedPtr`, `typePointee`; annotation arm; implicit `Ptr<mut T>` → `Ptr<T>` → `Ptr`; `T?`; `!= none` narrowing; refuse owned pointees | `src/parse/decl.psm:672,845`, `src/ast/types.psm`, `src/sema/types.psm`, `src/sema/checker.psm` |
| 2 | Reads: member access, operators, `load()`; field GEP with the field's alignment; parameter attributes | new `src/sema/pointer.psm` (as `channel.psm`), `src/ir/expr.psm`, `runtime/llvm-api-backend.c`, `src/ir/bridge.psm` |
| 3 | Writes: field `=`/`op=` through `Ptr<mut>`, `store`, the refusal diagnostics | `semaAssignment`, `pointer.psm` |
| 4 | **Built.** Address methods, `at`/`atUnchecked`/`cast`/`castAligned`, `advance`; `inbounds` | `pointer.psm`, `mem_builtins.psm`, `llvm-api-backend.c` (`ir_ptr_op`) |
| 5 | **Built.** Volatile in the type; atomics with orderings | builtins table, `std/raw.psm`, `llvm-api-backend.c` (`ir_ptr_atomic`, `ir_ptr_load_volatile`) |
| 6 | `asSlice`; `std.mem` typed `alloc`; `Buffer.pointer`; docs in **both** apps; CHANGELOG 0.2.0 | `std/mem.psm`, `../website/apps/{docs,developers}` |

**What stages 1 and 2 settled** (each differs from, or adds to, what the table above says):

- **One builtin, `__builtin_ptr_load(p)`**, typed from its argument and emitted as `load T, ptr %p` through
  the scalar path an array element takes (TBAA tag, Bool as its byte). `__builtin_mem_load_*` through a
  `Usize` was rejected: the `inttoptr` throws away the provenance the type exists to keep.
- **A struct field read through a pointer is `getelementptr inbounds` plus a load at the field's own
  alignment**, by the existing member-access path; a field that is itself a struct (inline storage) is a
  `Ptr<Inner>` with the parent's capabilities, so `p.header.magic` reads through two.
- **Read positions built:** a struct member, an operand of a binary or unary operator beside a non-pointer,
  `let n: Int = p`, `return p` from an `-> Int`, and a call argument for a scalar parameter. Indexing
  (`p[i]`) is not: it needs `offset` (stage 4).
- **Refused, with a message:** two pointers under one operator, a struct as an operand, a scalar's
  field, an unknown method, a read through `volatile` (a plain load there would be silently wrong until
  stage 5), and any write (stage 3).
- **Parameters** `Ptr<T>` get `noundef nonnull align(A) dereferenceable(S)` from the data layout (packed
  structs included), plus `readonly` unless `mut`; `volatile` omits `dereferenceable`. A `Ptr<T>?` gets none.
- **Overloads:** the pointee and capabilities are in the symbol (`f__Ptr_Struct_A`, `f__PtrMut_Struct_B`),
  and an exactly-typed pointer argument outranks one that needs `mut` dropped.
- **`typeEquals` is strict for typed pointers** (it used to be PTR's unconditional `true`); the one-way
  conversions live in `typePtrConverts`, consulted from `semaTypesMatch`.

**What stage 5 settled:**

- **Volatile is the type's, not the call's.** Every access through a `Ptr<volatile T>` is volatile: `load`, `store`,
  an operand, a field read, a field write, and a struct field of a volatile struct (`regs.uart` is a
  `Ptr<mut volatile Uart>`). The two refusals stage 2 and 3 carried until this stage are gone. `readVolatile()` and
  `writeVolatile(v)` stay as the one-off on a pointer that is not volatile.
- **Volatile pointers are not promised readable.** A `Ptr<volatile T>` parameter gets `noundef nonnull align` but not
  `dereferenceable`, since a device register is not memory a load may be hoisted past. `readonly` is kept for one that
  is not `mut`.
- **Atomics are methods named like the address functions** (`atomicLoad`, `atomicAdd`, `atomicCompareExchange`,
  ...), with the ordering last, written as a variant of `AtomicOrder` -- an enum declared in `std/raw.psm`, so they need
  `import std.raw`. The ordering is read off the node by name and never generated: it is a property of the instruction.
  Refused: a non-integer pointee, a write through a read-only pointer, a load that releases, a store that acquires, an
  ordering that is not a written variant. A compare-exchange takes its failure ordering from the success one without its
  release half, as C++ derives it, and answers the value it found.
- **The IR is asserted, not just run.** `typed_pointer_ir` (tests/test_runner.py over `tests/ptr_access_ir_probe.psm`)
  checks each access is the instruction its type or method says, because neither volatility nor an ordering shows in
  program output.
- **Enums take no visibility marker yet**, so `AtomicOrder` is a plain `enum`.

**What stage 4 settled:**

- **One backend entry, `ir_ptr_op`, and one table (`ptrOpKind`)** for every address operation, instead of a
  builtin per method. The pointee's own key gives the stride and alignment: `offset` is one
  `getelementptr inbounds`, `offsetFrom` is `sub` + `sdiv exact`, `advance` is branchless (a `select` on a
  null, so the poison of an out-of-range `inbounds` is never used), `at` and `castAligned` fold the null and
  alignment tests into one `select`. `p.addr` is a property reusing `__builtin_ptr_addr`, which now accepts a
  typed pointer of any capability (reading where it points writes nothing).
- **`advance(n, limit)` is positional**, not `limit: q`: the language has no named arguments. It answers `none`
  rather than pass `limit` in the direction of travel; one past `limit` is the end and is allowed. `isAligned(a)`
  takes a power of two, as the mask form is the fast one.
- **Constructors need `import std.raw`**, checked in sema (`ir_file_imports_module`): a file that has not imported it
  cannot make a pointer from a number or cast one. That is the whole of the `unsafe` marker. `Ptr<T>.at` and
  `castAligned` answer `Ptr<T>?`; `atUnchecked` and `cast` trust the caller.
- **`cast` cannot add `mut` to a read-only pointer** (an opaque `Ptr` can become `mut`): the function that took it
  was promised it would not be written through, and the compiler told LLVM `readonly`.
- **The parser had a gap from stage 1:** `Ptr<mut Int>.at(...)` did not parse in expression position because the
  type-argument scan (`looksLikeTypeArgs`) did not admit `mut`. It does now; `mut` cannot begin an expression, so a
  `<` before it is never a comparison.

**What stage 3 settled:**

- **Writes:** `p.field = v` is an ordinary assignment whose target is a field of the pointee, lowered by the
  existing field-store path with the struct taken from the pointer (`memberObjectStructName`), so it is
  `getelementptr inbounds` and a store at the field's width and alignment. A scalar pointee is written with
  `p.store(v)`, lowered to `__builtin_ptr_store` -> `store T, ptr %p`. Both need `Ptr<mut T>`.
- **Refused, each with the way out:** a read-only pointer (names the `Ptr<mut T>` to take), a volatile one
  (one message for every access until stage 5), a struct-typed field (`p.header = q` would copy bytes through a
  pointer under the spelling of a rebinding: write its fields), `p.store(struct)`, a wrong-typed value, and
  `p = 5`, which would replace the pointer (says `p.store(5)`).
- **A pointer field takes a pointer** (`packet.next = packet`; `mut` is dropped on the way in), and absent
  memory reads as `none`: calloc'd zeroes are a `Ptr<T>?` that is `none`.

**Every new `__builtin_*` is five edits and a seed refresh** (`builtins.psm`, `aif/contracts.psm`,
`aif/prototype/aif.py`, `ir/expr.psm`, `ir/bridge.psm`; see the memory note on adding a builtin), and
an undescribed callee blocks AIF bracketing for its whole caller. Prefer emitting LLVM `load`/`store`/GEP
directly from `ir/expr.psm` over a builtin per width. After each stage: `prismio suite`, two generations to a
fixpoint read in the IR, `tools/aif_differential.py`, then `graphify update .`. No stage may put syntax in
`src/` before the host that parses it is installed.

## 6. Honest limits

`Ptr<T>` removes null, accidental mutation, accidental stride arithmetic and a missing `volatile`. It does
not remove use after free, a pointer past its allocation, or an `at` pointer that points at nothing.
`dereferenceable(sizeof T)` makes a lying `cast` worse than in C (the optimiser may speculate the load),
which is why `cast` is `std.raw`'s and `castAligned` exists. An MMIO pointer must be `volatile`; a plain
`Ptr` over a device register is the programmer's bug, as a non-`volatile` `T*` is in C.

## 7. Open

- Does `Ptr<T>.at(address)` as a static on a built-in type resolve like `Buffer.new`, or does sema need an arm?
  Find out in stage 1; the fallback is a `std.raw` function `pointerTo(Ptr<T> type witness)`, which is worse.
- Signed-integer pointee comparisons through the projection rule reuse the existing literal typing
  (`prismio-literal-typing-model`); check `p > 0` with `Ptr<U32>` before stage 2 is called done.
- Pointee alignment when `T` is a `repr(C)` struct with a packed field: the attribute is the struct's, not the field's.
