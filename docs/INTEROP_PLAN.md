# Interop with C, C++ and Rust, in both directions

The plan for making Prismio call, and be called by, C, C++ and Rust with no glue code written
by hand. Written 2026-10-10. Nothing in it is built yet. Section 1 is the measured starting
point, section 2 the prior art it draws on, section 3 the design, section 4 the steps in order,
and section 5 what "done" means in numbers.

**The goal, in one line:** a Prismio program uses a C header, a C++ header or a Rust crate the
way it uses `std`, and a C, C++ or Rust program uses a Prismio library the way it uses one of
its own. In every direction:

- no glue written by hand;
- ownership correct by construction;
- no copies where the layouts already agree;
- small foreign functions inlined across the boundary;
- one `prismio build`.

That is the target this plan is measured against. Most languages stop at "C, by hand". Swift
and Carbon reach C++ by embedding Clang. Crubit reaches C++ ↔ Rust inside one monorepo. No
language does all three both ways. Section 2 shows where each design stopped, and why.

---

## 0 · The target, as a user writes it

This is illustrative syntax. Section 3 decision D1 explains why the language itself gains no
new syntax: foreign code arrives as *generated Prismio modules* behind ordinary imports, and
`build.ums` says where it comes from.

```ums
dependencies {
    c("zlib")      { header("zlib.h")                library("z") }
    cpp("geo")     { header("geo/mesh.hpp")          include("vendor/geo/include") source("vendor/geo/mesh.cpp") }
    rust("regex")  { crate = "regex"  version = "1" }
}
targets {
    library("pmath") {
        entry = "src/lib.psm"
        kind = "static"                    // or "shared"
        emit { c = "include/pmath.h"  cpp = "include/pmath.hpp"  rust = "bindings/pmath" }
    }
}
```

```prismio
import c.zlib
import cpp.geo
import rust.regex

fn main() {
    let crc = zlib.crc32(0, data)                      // a C function, contract inferred from the header
    let mesh = geo.Mesh(vertices)                      // a C++ constructor; the destructor runs at scope exit
    let area = mesh.area()                             // a C++ member function, inlined by cross-language LTO
    let re = regex.Regex.new("[a-z]+").unwrap()        // a Rust generic Result, instantiated on demand
    println(re.isMatch("hello") as String)
}
```

From the other side, with no hand-written declaration of Prismio:

```c
#include "pmath.h"            /* generated: functions, repr(C) structs, ownership in attributes and comments */
```
```cpp
#include "pmath.hpp"          // generated: RAII owners, std::string_view, std::span, std::optional
```
```toml
[dependencies]
pmath = { path = "bindings/pmath" }   # generated crate: Drop, lifetimes, &str, Result
```

---

## 1 · Where it stands (2026-10-10)

Read from the tree and the docs, and one probe run (1.2).

### 1.1 What crosses the boundary today

| Area | State | Where |
|---|---|---|
| Calling C, `extern fn` | Works for integers, `Float`, `Bool`, `Char`, `Ptr`, `String` and structs. Contracts: `borrow`, `bytes`, `retain`, `retain_in(k)`, `consume`, `out`, `alias`, `produce(f)` | `src/parse/decl.psm:995`, `src/sema/ownership.psm:415` |
| `String` to C | The pointer half only (`ffiType`); the buffer is NUL-terminated. A view gets a NUL-terminated copy unless the parameter is `bytes` | `src/ir/types.psm:149` |
| Structs to C | **Always by pointer.** `storageType` collapses `struct:T` to `ptr`; nothing passes or returns a struct by value | `src/ir/types.psm:137`, comment at `:162` |
| Struct layout | `repr(C)` and `packed` keep declaration order. An **unmarked struct's fields may be permuted** even when handed to C | `docs/KNOWN_ISSUES.md` (Language surface) |
| Foreign globals, `extern let` | Integers, `Float`, `Char`, `Ptr` only | `src/sema/ownership.psm:400` |
| Exporting, `export fn` | Exists; gives the symbol its source name. Only the freestanding kernels exercise it | `src/ast/fn_attrs.psm`, `src/ir/module.psm:290` |
| Callbacks | None. A closure is a struct plus a monomorphised `call`: no function pointer, no function types | `language/closures.md`, `language/types.md:188` |
| C variadics | Not supported | `guides/calling-c.md` |
| Library output | A `library(...)` target is validated but not emitted | `guides/calling-c.md` |
| Headers for exports | Not generated (FFI.md §9 specifies them) | `docs/aif/spec/FFI.md:300` |
| Header import | None; every `extern fn` is written by hand | `guides/calling-c.md` |
| C++ in `native{}` | User docs say `.cpp` is rejected (`UMS2324`). This tree's own `build.ums` lists `runtime/llvm_bridge.cpp` (uncommitted bridge work), so check the current state before step 7 compiles thunks | `build.ums`, `docs/LLVM_BRIDGE_PLAN.md` |
| Unwinding | None. `panic` ends the process (`prismio_panic`); functions are `nounwind` | `runtime/lang_runtime.c:3194` |
| Width | `Int` is i32. C's `size_t` is `Usize`, never `Int` | memory note; `language/types.md` |

### 1.2 A defect the probe found: small integers reach C unextended

Clang trusts the **caller** to extend `bool`, `char` and `short` arguments to 32 bits. In LLVM
this is `zeroext`/`signext` on the declaration. Prismio declares externs without either. Probe
on macOS arm64 with the 2026-10-08 project host (the source is in the appendix):

```c
int widen(uint8_t x) { return x; }      // clang -O2: `mov w0, w0` -- it never masks
```
```prismio
extern fn widen(x: U8) -> Int
...
let wide = bump(100 + i)                // 301, 304, 307
println(widen(wide as U8) as String)    // printed 301, 304, 307; correct is 45, 48, 51
```

The truncation `as U8` never reaches the register: LLVM passes the whole `w0`. Apple's arm64
ABI requires the caller to extend, and so does x86-64 SysV in practice. That platform is not
measured, but clang marks the same `zeroext`. Standard AAPCS64 (Linux arm64) has the callee
extend, so it is likely safe there. The same rule applies to the **return** of an `export fn`
typed `U8`, `I8`, `U16`, `I16` or `Bool`; that direction is not measured. This is step 0.

### 1.3 The toolchain already has most of the parts

- **LLVM 23.1.1 is vendored**, and the official archive carries Clang's static libraries.
  `tools/setup_llvm.py` currently prunes them.
- **The pinned `clang` is in `third_party/llvm/bin`.** The `native{}` C sources are already
  compiled with it, so C compiled for a Prismio program matches the compiler's LLVM version
  exactly.
- **`clang/CodeGen/CodeGenABITypes.h` is shipped.** This is the public Clang API that asks
  "how does C pass this signature" (`arrangeFreeFunctionCall` and its siblings). Swift uses it
  to lower C calls.
- **`llvm/ABI/` is shipped in 23.** This is the GSoC 2025 ABI lowering library: `TargetInfo`,
  a small type system and `IRTypeMapper`. In 23 it covers **only BPF and x86-64**. AArch64
  aggregates are an open PR (llvm-project #229202, updated 2026-10-06), and the umbrella PR
  #140112 is still `[WIP]`. No Windows x64, no wasm32.
- **The compiler already links LLVM's C++ API** on macOS and Linux (static archives lowered to
  objects), and `docs/LLVM_BRIDGE_PLAN.md` sets the pattern of a small `extern "C"` C++ bridge.
- **Merging library bitcode is already a build stage** (runtime `.bc` and `.plib`), so taking
  foreign bitcode into the same module is an extension, not a new mechanism.

### 1.4 Rust's LLVM is behind ours, which settles who drives LTO

The rustc book's table maps Rust 1.91–1.94 to LLVM 21; the rustc installed here (1.97.1)
reports LLVM 22.1.6. LLVM reads bitcode from older versions and upgrades it, never the reverse.
So **Prismio's LLVM 23 can read rustc's bitcode, and rustc cannot read ours**, and the
cross-language merge has to happen inside `prismio build`. The system linker never sees bitcode.
Apple's `ld` would run LTO through Xcode's `libLTO`, a third LLVM version. The rustc book's own
rule is the same: the LTO driver must be at least as new as the newest compiler that produced
bitcode. Section 3 D9 has the consequences, including the day Rust overtakes us.

---

## 2 · Prior art, and what each one teaches

| System | Approach | What to take | Where it stopped |
|---|---|---|---|
| **Zig** | Own C ABI lowering in the compiler. `translate-c` turns headers into Zig source. In 0.16 it moved from Clang to the Aro C frontend and out of the compiler into a build-system package; `@cImport` is deprecated | Generated **source**, readable and cacheable, behind the build system | C only; no C++ |
| **Swift** | Embeds Clang (ClangImporter). Lowers C calls with Clang's CodeGen. Imports C++ classes and templates, instantiating each template at the concrete types used | Clang as the single ABI and C++ semantics oracle; templates instantiated on demand | Templates cannot be specialised *through* Swift generics; several C++ shapes still unsupported (swift.org status page) |
| **Carbon** | Built around C++ interop: `import Cpp` of headers through embedded Clang | Interop as a language goal from day one | Experimental |
| **Crubit** (Google) | `rs_bindings_from_cc` reads C++ with Clang. `cc_bindings_from_rs` reads Rust with `rustc_driver`. Lifetime annotations carry aliasing | Both directions from one tool; lifetimes in the binding layer | Tied to Google's monorepo build; external contributions closed; non-`extern "C"` functions and `std::string` still limited |
| **cxx / autocxx** | One shared `#[cxx::bridge]` describes both sides; generates C++ and Rust shims | A *shared* type declared once, native on both sides | A safe subset; hand-written bridge (autocxx generates it from headers) |
| **bindgen / cbindgen** | Header to Rust; Rust to header | Mechanical, proven | Raw `unsafe` C level; no ownership |
| **Diplomat** (ICU4X), **UniFFI** | One interface definition (Rust attributes or UDL), many language back ends, ownership-aware | **One interface model, many emitters** (the core of section 3) | Rust is always the implementation language |
| **crABI** (`extern "crabi"`) | Rust's proposed stable ABI beyond C (RFC 3470) | That Rust-to-anything still means the C ABI today | Feature-gated experimental, not stable |
| **abi-cafe** | Generates a signature, builds caller and callee with two toolchains, compares the values each side saw, minimises disagreements. rustc's cranelift and gcc back ends run it in CI | **ABI correctness as a differential test**, not a reading of specs | A tool, not a binding layer |
| **LLVM ABI library** | Moves Clang's ABI classification into LLVM for any frontend | The long-term home for classification | In 23: BPF and x86-64 only |
| **rustc `-C linker-plugin-lto`** | Defers LTO to a linker plugin that reads both languages' bitcode | The version rule (1.4) | Assumes a linker plugin; we merge in-process instead |

What follows from the table:

1. **Nobody writes their own C++ frontend, and nobody should.** Every system that reaches real
   C++ embeds Clang. Mangling, overloads, templates, special members and vtables are Clang's job.
2. **Rust has no ABI but C.** Rust interop is two halves meeting at C, plus a generator on each
   side. The research question is how *much* of a crate the generator can reach without
   annotations.
3. **One interface model with many emitters** (Diplomat, UniFFI, Crubit's IR) is how bindings
   stay consistent across languages.
4. **ABI correctness is tested by differential execution, not review.** abi-cafe exists because
   specs are wrong and compilers disagree.

---

## 3 · Design

### D0. The boundary model

Every importer produces, and every emitter consumes, one description of an interface. Call it
the **boundary model**:

- **Types** with a concrete layout: size, alignment and field offsets, plus whether the layout
  is C-compatible as FFI.md §2 defines it (L1–L7).
- **Functions** with:
  - each parameter's *classification* (direct, coerced to a register type, indirect, byval,
    extended);
  - each parameter's *AIF contract* (`borrow`, `consume`, `produce(f)` …);
  - *lifetime links* (`alias` of which parameter);
  - *unwind behaviour*;
  - the symbol name (mangled where C++ requires it).
- **Ownership operations** per type: destroy, copy and move, each an exported C-ABI function or
  thunk.

| Importers (into the model) | Emitters (out of the model) |
|---|---|
| C headers, through Clang | Prismio modules (`extern` declarations plus safe wrappers) |
| C++ headers, through Clang | `.h` |
| Rust crates (D6) | `.hpp` |
| Prismio itself, for exports | A Rust crate |
| | C++ thunks and Rust shims (compiled to bitcode, then merged) |

The model is serialised next to each generated module, as a sidecar that is versioned and
deterministic. Codegen reads classifications from it, so **the compiler need not link Clang to
compile a call**. Only the bindings tool does (D2).

### D1. No new syntax: a foreign library is a generated Prismio module

`import c.zlib` resolves to a module the bindings tool generated from `build.ums`'s
`dependencies { c("zlib") {...} }`. The language does not grow `extern "C++"` or `extern "Rust"`.

| Why | |
|---|---|
| **The seed rule** (CLAUDE.md) | New syntax is two steps: teach the frontend, cut a seed, *then* use it. Generated modules use syntax the seed already parses. |
| **Readable output** | A user can open what was imported, the way Zig's `translate-c` output can be read. Diagnostics point at generated source with a `// from zlib.h:1234` mapping. |
| **The IDE plugin works unchanged** | It already reads modules from the toolchain. |
| **It shares work** | Path dependencies are not on the import search path yet (`P1081`), and that wiring is the same one foreign modules need. |

The one exception that may need syntax is a function type for callbacks (D8). That goes through
the seed two-step on its own.

### D2. One ABI oracle, Clang, inside a separate bindings tool

C ABI classification is the part every language gets wrong. abi-cafe exists because Rust,
cranelift and gcc disagreed. Three ways to get it:

| Option | For | Against |
|---|---|---|
| Own classifier (Zig, rustc) | No dependency | Five ABIs × the platform quirks (Apple arm64 extends in the caller and puts every variadic argument on the stack; Win64 passes large structs by reference; HFAs; `__int128`), maintained forever |
| `llvm/ABI` | The intended long-term home; frontend-neutral | BPF and x86-64 only in 23; no Win64, wasm32 or Apple quirks yet |
| **Clang CodeGen (`CodeGenABITypes.h`)** | Exactly what C and C++ compilers on the platform do; we already ship it; it covers C++ (`this`, `sret` for non-trivial types, member pointers) | Links Clang (size, setup time) |

**Decision: Clang, in a separate tool** (working name `prismio bind`, a launcher subcommand
backed by its own binary):

- It runs only when a `build.ums` declares a foreign dependency or a library emits headers.
- It caches by header content and flags, the way `native{}` sources are cached.
- The compiler stays Clang-free: it reads classifications from the sidecar (D0).
- **Exports go through the same oracle.** The compiler writes the `.h` for a library first,
  `prismio bind` classifies *that header*, and codegen lowers the exports from the result. So
  the header C users compile against and the ABI Prismio emits are decided by the same Clang.

`llvm/ABI` is tracked as the replacement for the classification half once it covers AArch64,
Win64 and wasm32, which would let the compiler classify `repr(C)` exports without the round
trip.

To decide by measurement in step 1:

- the bindings binary's size with Clang linked;
- setup's lowering time for the Clang archives (`setup_llvm.py` already lowers LLVM's in about
  75 s);
- the cold time to classify a header the size of `<windows.h>`.

### D3. Mapping types

| Prismio | C | C++ | Rust | Copy at the boundary? |
|---|---|---|---|---|
| `I8`…`I64`, `U8`…`U64`, `Isize`, `Usize` | `int8_t`… `size_t` | same | `i8`… `usize` | no |
| `Int` | `int32_t` | `int32_t` | `i32` | no |
| `Float` | `double` | `double` | `f64` | no |
| `Bool` | `bool` | `bool` | `bool` | no (extended, 1.2) |
| `String`, borrowed | `const char*` (NUL) or `(const char*, size_t)` (`bytes`) | `std::string_view` | `&[u8]`; `&str` after a UTF-8 check, or a `PStr` wrapper with `to_str()` | no |
| `String`, owned result | `char*` plus `pmath_string_free` | an owning `pmath::String` that converts to `std::string_view` | `pmath::PString: Deref<Target=[u8]>`, `Drop` | no |
| `[T]`, `Slice<T>` | `(const T*, size_t)` | `std::span<const T>` | `&[T]` | no, when `T` is C-compatible |
| `Vec<T>` | opaque handle plus accessor functions | owning wrapper with `begin`/`end`/`size` | wrapper with `Deref<Target=[T]>` | no |
| `repr(C) struct` | `struct` | `struct` (trivial) | `#[repr(C)] struct` | no; by value per D2 |
| unmarked `struct` | opaque pointer | owning class | owning struct | no; or the *wrapper mode* of FFI.md §9 |
| `T?` (reference) | nullable `T*` | `T*`, or `std::optional` for values | `Option<&T>`, `Option<Box<T>>` | no |
| `Result<T, E>` | tagged struct | `std::expected<T, E>` (C++23), otherwise a generated `Result` | `Result<T, E>` | small |
| `enum` without payload | integer `enum` with an explicit width | `enum class` | `#[repr(iN)] enum` | no |
| `dyn Trait` | `(void* self, const vtable*)` | an abstract class adaptor | a `dyn Trait` adaptor | no; vtables differ (D7) |

Two shapes need a decision of their own:

- **Rust's `&str` must be valid UTF-8**, and Prismio strings are bytes. Checking at the boundary
  is O(n) and breaks the "no copy, no scan" promise. The generated crate hands out `&[u8]` plus
  a checked `to_str()` and an `unsafe to_str_unchecked()`. A future `Utf8String` invariant in
  Prismio would remove the check.
- **`Int` is i32 by decision** (memory note; see `aif/evidence/RESULTS-int-width.md` in history).
  The importer maps C's `int` to `Int`, `long` to `I64` or `I32` by target (LP64 vs Windows
  LLP64), and `size_t` to `Usize`. Never `Int` for `size_t`.

### D4. Ownership is the contract system, inferred instead of written

The AIF contracts are already the right vocabulary. What changes is that importers **infer**
them, and emitters **express** them in each language's idiom:

| Prismio | C annotation the importer reads | C++ | Rust |
|---|---|---|---|
| parameter `borrow` (the default) | `const T*`, `[[clang::noescape]]` | `const T&` | `&T` |
| `inout` | `T*` | `T&` | `&mut T` |
| `sink` / `consume` | `__attribute__((ownership_takes(...)))` | `T&&`, `std::unique_ptr<T>` | `T` by value, `Box<T>` |
| return `produce(f)` | `ownership_returns`, a paired `*_free`/`*_destroy` | `std::unique_ptr<T, Deleter>` or the class itself | owning struct with `Drop` |
| return `alias` of parameter *k* | `[[clang::lifetimebound]]` on *k* | the same | `fn f<'a>(x: &'a T) -> &'a U` |
| `retain` / `retain_in(k)` | `[[clang::lifetime_capture_by(k)]]` | the same | a lifetime bound tying the two |
| `bytes` | `__counted_by(n)`, `__sized_by(n)` | `std::span` | `&[u8]` |
| nullability | `_Nonnull` / `_Nullable` | `gsl::not_null`, references | `&T` vs `Option<&T>` |

Rust carries the most information: a signature's lifetimes **are** alias and retain contracts,
with no annotation at all. C carries the least. For a C function with no annotations the
importer falls back to the conservative defaults FFI.md §5.4 already specifies, and says so in
`--why`. D9 adds the research step: *verifying* a declared or inferred contract against the
foreign function's compiled body.

### D5. Failure crosses as a value, never as unwinding

Prismio has no unwinding and every function is `nounwind`. So each boundary is a no-unwind
boundary:

- **Into Prismio:**
  - Rust shims wrap the call in `catch_unwind` (`extern "C-unwind"` on the Rust side,
    stable since 1.71).
  - C++ thunks wrap it in `try {} catch (...) {}`. Functions marked `noexcept` get no wrapper.
  - The caught failure becomes `Result<T, ForeignError>` if the binding declares the call
    fallible, otherwise an abort whose message names the boundary.
  - Rust's `extern "C"` already aborts on a panic that escapes (since 1.81), so a raw call is
    never undefined behaviour, only an abort.
- **Out of Prismio:** `panic` in a library calls a **host-installable hook**
  (`<lib>_set_panic_hook`). It defaults to today's behaviour, and the hook freestanding already
  has is the precedent. Exports return `Result` as the language's value types D3 lists.

### D6. Rust crates: two tiers

| Tier | Requires | How | Reaches |
|---|---|---|---|
| **A: annotated** | stable Rust | A `prismio-export` proc-macro crate: `#[prismio::export]` on items generates `extern "C"` shims and writes boundary-model JSON at build time (Diplomat's and cxx's model) | What the crate author marks |
| **B: any crate** | nightly `rustdoc --output-format json` (unstable, versioned by `FORMAT_VERSION`), or `RUSTC_BOOTSTRAP=1` on stable | Read the public API, generate a **shim crate** with `extern "C"` wrappers for exactly the items and generic instantiations the Prismio program uses, then `cargo build` it to a staticlib plus bitcode | Most of a crate's public surface; macros and trait-heavy APIs are partial |

Tier B is the research tier. It is what Crubit's `cc_bindings_from_rs` does through
`rustc_driver`. rustdoc JSON is chosen over `rustc_driver` because its format is versioned and
meant for tools; `rustc_driver` changes every nightly.

Generics are instantiated **on demand**:

- A Prismio use of `regex::Regex` or `Vec<Foo>` records the concrete instantiation.
- The shim crate contains one monomorphic wrapper per instantiation.
- A Prismio type used as a Rust generic argument crosses as an opaque handle, with a generated
  `impl` of the required traits whose methods call back into Prismio exports.

### D7. C++: Clang does the language, thunks do the ABI

Through Clang in `prismio bind`:

- **Free functions and overloads:** symbol names come from Clang's `MangleContext`. We never
  write a mangler; Itanium and MSVC both come for free.
- **Trivially copyable and trivially relocatable classes:** by value, with the layout from
  Clang.
- **Non-trivial classes:** constructors, destructor, copy and move become generated C-ABI
  **thunks**, compiled by the pinned clang to bitcode and merged (D9), so LTO inlines them
  away. Prismio sees a struct whose destructor runs at scope exit (`produce`), whose copy is
  `.clone()`, and whose move is `sink`.
- **Methods and operators:** methods are thunks taking `this`. Operators map to Prismio's
  operator traits.
- **Templates:** Clang `Sema` instantiates them at the concrete types the program uses, one
  thunk set per instantiation. This is Swift's model. Templates over *Prismio* types go through
  generated C++ adaptor types (the D6 handle pattern).
- **Virtual classes:** calls go through thunks. **Subclassing in Prismio** (implementing a C++
  interface) generates a C++ subclass whose overrides call Prismio exports. Prismio's `dyn`
  layout (two words, 4-byte relative vtable offsets) is not C++'s, so the two are never punned,
  only adapted.
- **`std::string`, `std::vector`:** borrowed as `std::string_view` and `std::span` at no copy.
  Owned ones cross as opaque handles with thunked accessors. Converting to `String`/`Vec` is an
  explicit copy, because the three standard libraries lay them out differently.

### D8. Callbacks

A closure has no function pointer (1.1). For a foreign parameter of function-pointer type:

- **Call-scoped callbacks** (`qsort`, `sqlite3_exec`'s callback, Rust `&dyn Fn`) take the
  closure through a generic closure bound, as `forEach` does today. The compiler emits a
  **trampoline** `(void* ctx, args...)` that calls the monomorphised `call` on the closure
  struct `ctx` points at. That needs no new type and fits "a closure lives for the call it is
  passed to". FFI.md §8's reentrancy rules apply as written.
- **Retained callbacks** (signal handlers, event loops) need the closure boxed with a
  `produce(free)` owner and a `retain` contract. That needs a function *type* in the language,
  so it is the one place this plan may need syntax, and it goes through the seed two-step.
- **Top-level functions** passed as C function pointers are the cheap case: the symbol itself.

### D9. Cross-language LTO, with Prismio as the driver

- **C and C++ in `native{}`**, and every generated thunk, are compiled by the pinned clang
  **to bitcode**, then merged into the Prismio module before the IR pipeline. Same LLVM
  version, no compatibility question.
- **Rust:** the shim crate (and tier A crates) is built with `-C linker-plugin-lto` /
  `--emit=llvm-bc` and the bitcode is merged. Older bitcode is upgraded on load. Rust's `std`
  stays native code unless it is rebuilt with `-Zbuild-std` (nightly): the shims and the
  user's crates inline, `std` calls do not.
- **Libraries built from Prismio** can ship bitcode alongside the archive (the `.plib`
  precedent), so a C, C++ or Rust consumer using the *same or newer* LLVM can LTO into
  Prismio code. Rust can't today: its LLVM is older.
- **If Rust overtakes us**, the direction flips: rustc's bitcode will no longer load in the
  Prismio compiler. The build must then detect the newer producer version and fall back to
  native objects with a stated warning, never fail silently. Tracking LLVM releases promptly
  (as the LLVM 23 upgrade did) keeps us the newest.
- **Apple clang bitcode** (from Xcode, a fork with its own version numbers) is not accepted as
  input. Foreign C/C++ is compiled by the pinned clang or linked as native objects.

### D10. Libraries and the runtime

A Prismio library inside someone else's process raises questions an executable never did:

- **Initialisation.** Module-level `let`s are constant-initialised globals (sema rejects
  non-constant initialisers), so no constructor is needed. The runtime's thread-local state
  (`prismio_memory_worker`, arenas) must initialise lazily **on a thread Prismio did not
  create**. Verify, don't assume.
- **Two Prismio libraries in one process** each carry a runtime. Runtime symbols must be
  internalised per library, or one shared runtime dylib must be used. And `rt_base_alloc`
  recycles small blocks per runtime, so **a block allocated by library A must be freed by
  library A**. The generated contracts already make every owned value travel with its
  producer's `free` (`produce(pmath_string_free)`). That is a correctness invariant here, not
  style, and the `--verify` ledger must be able to see it.
- **Symbol surface.** Only `export fn` and the generated ownership functions are visible:
  hidden visibility by default, `dllexport` on Windows. The `exportDynamic` and
  `ir_function_export` machinery exists.

---

## 4 · Steps, in order

Each step lists what it unblocks and how it is accepted. Docs land with each step in both doc
apps, and the "Not available yet" tables in `guides/calling-c.md` and `language/ffi.md` shrink
as they do.

### Step 0: make what exists correct

- [ ] `zeroext`/`signext` on `extern fn` parameters and returns, and on `export fn` parameters
      and returns, for `Bool`, `I8`, `U8`, `I16`, `U16` and `Char` (1.2). Probe both directions
      on macOS arm64, Linux x86-64 and Linux arm64.
- [ ] A struct reaching an `extern fn` whose layout is not C-compatible: force C layout, or
      refuse with a diagnostic that says to write `repr(C)`. Resolves the Language-surface
      entry in `KNOWN_ISSUES.md`.
- [ ] The 1.2 probe and its export twin become suite fixtures through `native{}`.

**Accepted when** the probe prints 45, 48, 51 and the fixtures fail on today's compiler.

### Step 1: the ABI oracle and the full C ABI

- [ ] `prismio bind` with Clang linked (D2). `setup_llvm.py` keeps and lowers the Clang
      archives it needs. Measure the size and time D2 lists.
- [ ] Sidecar classification format (D0); codegen reads it for externs and exports.
- [ ] Structs by value both ways, unions, fixed arrays in structs, explicit-width enums,
      `long`/`size_t` by target, bitfields (read and write through generated accessors).
- [ ] Calls to variadic functions (`printf`): default argument promotions, plus Apple arm64's
      all-variadics-on-the-stack rule, both from the oracle.
- [ ] An **ABI differential harness**: generate signatures, build caller and callee across
      {Prismio, clang} × {caller, callee}, compare. This is abi-cafe's method, and abi-cafe
      itself if a Prismio backend for it is practical.

**Accepted when** the differential harness is green on macOS arm64, Linux x86-64, Linux arm64
and Windows x64, run on each host.

### Step 2: libraries and exports to C

- [ ] Emit `library(...)` targets as static and shared, with hidden visibility, `export fn`
      only, and `dllexport` on Windows.
- [ ] Runtime-in-a-library: lazy thread-local init, per-library internalised runtime, the
      panic hook (D5, D10).
- [ ] Generate `.h` with layouts, contracts as Clang attributes (`lifetimebound`,
      `ownership_returns`, nullability), and a comment per function stating who frees what
      (FFI.md §9).
- [ ] Layout forced by an export is reported as `origin = ffi-forced` (FFI.md §9). Wrapper mode
      is the default for types used mainly inside the library.

**Accepted when:**

- a C program, a C++ program and a Rust program (all hand-written against the `.h`) call a
  Prismio library;
- `--verify` balances;
- two Prismio libraries linked into one C program each free their own objects;
- an export is called from a thread created by C.

### Step 3: import C headers

- [ ] The `c(...)` dependency, plus a `prismio bind` C importer that writes a Prismio module
      and its sidecar. Covers functions, structs, enums, integer and string macros, and globals
      (`extern let`).
- [ ] Contracts inferred from annotations (D4). With no annotation, the FFI.md defaults,
      recorded for `--why`.
- [ ] **`static inline` functions in headers** get a generated `.c` wrapper compiled by the
      pinned clang to bitcode. LTO inlines it back, so the wrapper costs nothing.
- [ ] Function-pointer parameters with call-scoped trampolines (D8, first half).
- [ ] Wire generated modules, and path dependencies with them, into the import search (the
      `P1081` gap).

**Accepted when** zlib, sqlite3 and libcurl are imported with no hand-written declaration and
their own examples are ported and run, with `--verify` clean.

### Step 4: Prismio → Rust

- [ ] Emit a `-sys` crate (raw `extern "C"`, `#[repr(C)]`) and a safe crate: `Drop` for
      `produce`, lifetimes from `alias`/`retain`, `&[u8]` with checked `to_str`, `Result`,
      slices.
- [ ] A `prismio-build` helper crate for `build.rs`: runs `prismio build` on the library and
      emits `cargo:rustc-link-*`.

**Accepted when** `cargo test` passes in a generated example with no hand-written `unsafe`, and
`--verify` (through an env switch) balances.

### Step 5: Rust → Prismio

- [ ] Tier A: the `prismio-export` proc macro and its JSON (D6).
- [ ] Tier B: rustdoc JSON reader, on-demand shim crate, generics instantiated per use, Rust
      lifetimes to contracts, `catch_unwind` shims (D5).
- [ ] The Rust shim's bitcode is merged (D9).

**Accepted when:**

- `regex`, `serde_json` (through a typed façade) and `blake3` are used from Prismio with no
  hand-written code;
- a hot loop calling a small Rust function runs at parity with the same loop written in Rust
  (inlining observed in the IR).

### Step 6: Prismio → C++

- [ ] Emit `.hpp`: namespaces from modules; classes from structs and `impl` blocks; move-only
      RAII owners; `std::string_view`/`std::span`/`std::optional`/`std::expected`. Every
      function is an inline call into the C ABI, so the header adds no runtime code. C++17
      baseline; C++23 types behind feature tests.

**Accepted when** a C++ example uses the library idiomatically, with no `extern "C"` written by
hand, and compiles warning-free under `-Wall -Wextra` on clang, gcc and MSVC.

### Step 7: C++ → Prismio

- [ ] The C++ importer in `prismio bind` (D7): free functions and overloads by Clang mangling;
      trivial classes by value; non-trivial classes through bitcode thunks; methods and
      operators; on-demand template instantiation; virtual calls; exceptions caught in thunks.
- [ ] Subclassing a C++ interface from Prismio.
- [ ] `std::string`/`std::vector` borrowed with no copy, and owned through handles.

**Accepted when:**

- a real header-heavy library (candidates: `fmt`, a mesh library, `simdjson`) is used from
  Prismio with no shim written by hand;
- thunks vanish after LTO (no call to a thunk symbol left in the optimised IR);
- the differential harness (step 1) is extended to C++ classes passed by value.

### Step 8: research frontier

1. **Contract verification from foreign bodies.** After the bitcode merge, LLVM's
   `FunctionAttrs` infers `captures(none)`, `memory(...)`, `nofree`, `nosync` and `nocallback`
   for C, C++ and Rust functions. Check each declared or inferred contract against them:
   - `borrow` declared, but the pointer is captured → error;
   - `consume` declared, but the function is `nofree` and does not capture → warning;
   - `pure`/`nocallback` call-site contracts (FFI.md §5.3, not parsed today) inferred instead
     of written.

   This turns the FFI from "trusted" into "checked whenever bitcode is available", which no
   language in section 2 does.
2. **Layout negotiation.** FFI.md §9's forced-C-layout vs wrapper-mode choice, made by the
   layout cost model from access counts on each side of the boundary.
3. **Shared types.** A `repr(C)` struct declared once, native in all four languages (cxx's
   shared structs, generalised).
4. **Cross-language debugging.** Thunks marked artificial in DWARF so a debugger steps from
   Prismio straight into C++ or Rust source.
5. **More emitters from the same model:** the WebAssembly component model's WIT is the obvious
   one, once the wasm32 target has a runtime (`KNOWN_ISSUES.md`, Platform).

---

## 5 · What "fluid" means, in numbers

| Direction | Glue written by hand | Ownership | Copies when layouts agree | Inlining across | Test that proves it |
|---|---|---|---|---|---|
| Prismio → C | none (step 3) | inferred, `--verify` clean | none | yes (same LLVM) | ported zlib/sqlite examples |
| C → Prismio | none (step 2) | attributes in `.h` | none | with LLVM ≥ 23 | C consumer plus two-library test |
| Prismio → C++ | none (step 7) | RAII mapped to `produce` | none for borrows | yes (thunks vanish) | header-heavy library port |
| C++ → Prismio | none (step 6) | RAII owners | none for borrows | with LLVM ≥ 23 | idiomatic C++ example, 3 compilers |
| Prismio → Rust | none (step 5) | lifetimes → contracts | none for borrows | yes (Prismio drives LTO) | regex/blake3 parity loop |
| Rust → Prismio | none (step 4) | `Drop`, lifetimes | none for borrows | not while rustc's LLVM < ours | `cargo test`, no hand-written `unsafe` |

Underneath every row:

- the step 1 ABI differential harness, green on all four hosts;
- byte-identical generated bindings for identical inputs, the same rule as the compiler fixpoint.

---

## 6 · Constraints from this repository

- **Seed and host:** the plan avoids new syntax. A function type (D8, retained callbacks) is
  the exception and goes teach → seed → pin → use. A feature `src/` needs is installed as the
  host first.
- **Performance decides trade-offs** (the project goal). Every mapping in D3 is zero-copy
  where the layouts agree, and every thunk exists only until LTO removes it.
- **Linking stays with the platform toolchain** (`cc`, `link.exe`). LLD is not required by
  anything here, because the bitcode is merged before the linker runs.
- **Runtime surface:** a new runtime symbol (the panic hook, string free) comes with its `std/`
  wrapper and contract (CLAUDE.md).
- **Windows** is accepted only from a Windows host run. The VM replay exists
  (memory note: Windows VM CI replay).

## 7 · Open decisions

1. **Clang in a separate `prismio bind` binary or linked into the compiler** (D2). The plan
   assumes separate; step 1's measurements decide.
2. **Rust tier B needs nightly rustdoc JSON or `RUSTC_BOOTSTRAP`.** Is that acceptable for a
   research tier, with tier A as the stable path?
3. **The C++ baseline for generated headers.** C++17 with C++23 types behind feature tests is
   proposed.
4. **The order of steps 4–7.** Rust first is proposed because its ABI story is simpler (all C)
   and its benchmark arms already exist. C++ first would serve projects wrapping existing
   engines.

---

## Appendix: the 1.2 probe

Built out of tree with `.prismio/build/debug/prismio build` on macOS arm64, 2026-10-10.

`c/a.c`:

```c
#include <stdint.h>
#include <stdbool.h>
int widen(uint8_t x){ return x; }
int pick(bool b){ return b ? 7 : 3; }
```

`src/main.psm`:

```prismio
import std.io
import std.string

extern fn widen(x: U8) -> Int
extern fn pick(b: Bool) -> Int

fn bump(n: Int) -> Int { return n * 3 + 1 }

fn main() {
    let mut i = 0
    while (i < 3) {
        let wide = bump(100 + i)
        println(widen(wide as U8) as String)
        println(pick((wide & 256) != 0) as String)
        i = i + 1
    }
}
```

`build.ums` declares one `executable("abi")` with `native { source("c/a.c") }`. Output:
`301 7 304 7 307 7`. `widen` should print 45, 48, 51. `pick` is right here: an `icmp` result is
materialised as 0 or 1 and so happens to be extended. A `Bool` loaded from memory is the
untested case.

## References

- LLVM ABI lowering library: [RFC](https://discourse.llvm.org/t/rfc-an-abi-lowering-library-for-llvm/84495), [GSoC 2025 report](https://blog.llvm.org/posts/2025-08-25-abi-library/), [PR #140112](https://github.com/llvm/llvm-project/pull/140112), [PR #229202 (AArch64 aggregates)](https://github.com/llvm/llvm-project/pull/229202)
- Rust: [linker-plugin LTO and its version table](https://doc.rust-lang.org/rustc/linker-plugin-lto.html), [crABI RFC 3470](https://github.com/rust-lang/rfcs/pull/3470), [rustdoc JSON RFC 2963](https://rust-lang.github.io/rfcs/2963-rustdoc-json.html) and [tracking issue #76578](https://github.com/rust-lang/rust/issues/76578)
- [Crubit](https://github.com/google/crubit), [cxx](https://cxx.rs), [autocxx](https://github.com/google/autocxx), [Diplomat](https://github.com/rust-diplomat/diplomat), [UniFFI](https://github.com/mozilla/uniffi-rs)
- [Swift C++ interop status](https://swift.org/documentation/cxx-interop/status/), [Carbon interoperability design](https://github.com/carbon-language/carbon-lang/tree/trunk/docs/design/interoperability)
- Zig: [`@cImport` removal issue #20630](https://github.com/ziglang/zig/issues/20630), [translate-c package](https://codeberg.org/ziglang/translate-c)
- [abi-cafe](https://github.com/Gankra/abi-cafe)
- [Apple: Writing ARM64 code for Apple platforms](https://developer.apple.com/documentation/xcode/writing-arm64-code-for-apple-platforms) (caller-side extension, variadics on the stack)
