# The runtime surface

What a Prismio program can call, where it lives, and who owns what it returns.

This document exists because the answer used to be "read `runtime/lang_runtime.c`".
That was not a usable answer: the C states a signature and says nothing about
ownership, and ownership is the half that decides whether a call leaks, is safe,
or corrupts memory. The rule now is:

> **Applications call `std.*`. `extern fn` is for foreign code an application
> brings itself, not for reaching into the Prismio runtime.**

Every runtime symbol an application has business calling is wrapped in a standard
module, and the wrapper is where the FFI contract is written down once.

---

## 1 · Why some of this is C and some is not

Three categories, and the boundary is not "what was easiest".

**Representation operations — compiler builtins, not externs.** Three, and only
three:

| | |
|---|---|
| `__builtin_string_len` | read the carried byte count |
| `__builtin_string_byte_at` | read one already-bounded byte |
| `__builtin_string_put_byte` | write one already-bounded byte |

These have call-shaped source syntax but are not functions. The compiler owns
their types and borrowing effects and lowers them to `extractvalue`, GEP/load,
or GEP/store. They emit no LLVM declaration and require no linked symbol.

Allocation is a different category. `str_with_capacity` remains a real runtime
call so verification and arena placement still observe it; codegen pairs its
returned pointer with the length the caller supplied.

This follows the boundary used by production compilers: compiler operations get
a reserved builtin/intrinsic identity, while ordinary stable APIs wrap them.
[Clang exposes reserved `__builtin_*` operations][clang-builtins], and
[Rust keeps compiler intrinsics internal][rust-intrinsics] behind stable library
interfaces. [LLVM recommends synthesising existing IR when possible][llvm-ext]
rather than extending LLVM. Here all three operations already are ordinary LLVM
instructions, so a custom LLVM intrinsic would add machinery without adding
semantics.

[clang-builtins]: https://clang.llvm.org/docs/LanguageExtensions.html#builtin-functions
[rust-intrinsics]: https://doc.rust-lang.org/unstable-book/language-features/intrinsics.html
[llvm-ext]: https://llvm.org/docs/ExtendingLLVM.html

The declaration-to-builtin change is performance-neutral by construction and by
measurement. Nine interleaved runs of the preserved pre-change binaries against
fresh builtin binaries produced these medians:

| workload | before | builtin | change |
|---|---:|---:|---:|
| rare-pair search | 148.557 ms | 148.447 ms | -0.07% |
| dense-pair search | 47.826 ms | 47.663 ms | -0.34% |
| long-needle search | 750.131 ms | 751.280 ms | +0.15% |
| uppercase | 271.737 ms | 271.900 ms | +0.06% |
| integer format | 38.177 ms | 37.792 ms | -1.01% |
| concatenate | 206.069 ms | 208.256 ms | +1.06% |

The signs are mixed and the spread is ordinary run noise. More decisively, the
Mach-O `__TEXT` disassembly is byte-for-byte identical for all six old/new
pairs. Removing fake declarations changed compiler semantics and IR hygiene, not
the generated instructions.

`str_equals`, `str_compare`, `str_concat`, `str_substring`, `str_char_at` and
`str_from_char` still have C compatibility symbols, but `std.string` no longer
declares or calls them. Their supported implementations are ordinary Prismio
byte loops. The emitted IR for a program importing the module contains neither
calls nor declarations for those six names.

Search has two optional accelerators. `str_find_byte` delegates a one-byte scan
to libc. `str_find_byte_pair` compares two predictive needle bytes at 32
candidate starts per iteration using NEON or SSE2, with a scalar fallback. The
substring algorithm is still Prismio: pair selection, full verification,
Crochemore-Perrin Two-Way, and the dynamic effectiveness guard all live in
`std/string.psm`. The C primitive supplies only the vector operation the
language cannot express yet.

**Capabilities — must be C.** Opening a file, reading a directory, spawning a
process, asking the OS for the working directory. The language has no syscall
layer and will not grow one for these.

**Everything else — should be Prismio, and now is.** `str_trim`, `str_replace`,
`str_contains`, `str_starts_with`, `str_ends_with`, `str_index_of`, `str_to_int`,
`str_split` were C functions that only ever composed the primitives. Nothing in
them needed the C ABI. Being in C had two costs that are worth naming, because
they are the argument for the port:

- **They were outside the ownership analysis.** A C function is opaque. The
  analysis cannot see that `str_trim` allocates on every path, so the fact had to
  be asserted in a table (`src/aif/contracts.psm`), and for `str_replace`,
  `str_trim`, `str_clone` and `str_split` it never was — those four allocate and
  are in neither the compiler's `aifFfiProduces` nor the oracle's
  `FFI_RETURNS_PRODUCE`. A caller declaring one of them by hand got an opaque
  return, no owner, and a leak per call.
- **They were outside the docs**, for the same reason: there was no Prismio
  declaration to document.

`tests/test_75_std_string.psm` is a native conformance test. It writes boundary
expectations directly and compares optimized substring search with a small,
independent O(n*m) Prismio reference. It has no foreign string declarations, so
the test cannot pass by silently falling back to an older C implementation. Its
success path is also ledger-clean: 562 allocations, 562 releases, no leaks or
violations.

---

## 2 · The standard modules

| Module | Import | Covers |
|---|---|---|
| `std/io.psm` | `import std.io` | `print` / `println` overloads |
| `std/string.psm` | `import std.string` | strings, characters, parsing |
| `std/fs.psm` | `import std.fs` | files, paths, directory listing |
| `std/process.psm` | `import std.process` | arguments, subprocesses |
| `std/map.psm` | `import std.map` | `Map<K, V>` |
| `std/option.psm` | `import std.option` | `Option<T>`, `Result<T, E>` |

**There is no prelude.** `std.io` is an ordinary import: a program that prints
nothing carries no I/O, which is what lets a target with no stdout link at all.
See the comment above `resolveImports` in `src/main.psm`.

`std.*` resolves against the compiler's own library rather than relative to the
importing program, so a local `std/` directory cannot shadow these. A checkout
resolves to `std/`; an installed toolchain resolves to `stdlib/`.

---

## 3 · Ownership, and the three ways to get it wrong

Everything in this section is enforced by `--verify`, which pairs each allocation
with its release at run time. Build with `--verify` and run the binary; the
ledger line is `N allocated, N released, N leaked, N violation(s)`.

**Read `violations` first.** A violation is a release of something that was never
live — a double free or a free of memory the program does not own. A leak is
memory never released. Leaks cost bytes; violations corrupt.

### 3.1 Bind what you are given

```prismio
println(strTrim(text))            // leaks
let trimmed = strTrim(text)       // does not
println(trimmed)
```

An owned result passed straight into a parameter is a value nothing names, and
nothing names it is nothing frees it. Measured on a 13-call program: 70 allocated
/ 57 released unbound, 58 / 58 bound.

The same applies to containers: `strJoin(strSplit(s, ','), "-")` leaks the
temporary list, and binding it does not.

### 3.2 Do not bind a container's element

```prismio
let name = list_get(names, i)     // a second owner of the list's string
if (strLength(list_get(names, i)) > 0) { … }   // correct
```

Binding an element makes the analysis treat it as separately owned, and both the
binding and the list release it. Measured in `std/fs.psm` while it was written
this way: three `release of a pointer that is not live` violations — a double
free, not a leak.

### 3.3 If you must write `extern fn`, write the contract

For foreign code of your own. An extern with no contract has unknown provenance,
which the analysis widens to Shared, and the result gets no owner.

| Contract | Means |
|---|---|
| `borrow` | the callee reads the argument and does not retain it |
| `consume` | the callee takes ownership of the argument |
| `retain_in:k` | the callee stores the argument into argument *k*'s container |
| `produce(free)` | the return is a fresh allocation the caller must release |
| `alias` | the return is an existing value, **not** a fresh allocation |

`produce` versus `alias` is the distinction that bites. `cli_arg` returns a
pointer into `argv`; declaring it `produce(free)` hands `argv` to the
deallocator. `src/main.psm` declares it `alias`, which is correct, and
`std/process.psm` wraps it so no application has to know.

---

## 4 · What is still C, and why

Linked into every program: `runtime/lang_runtime.c` and
`runtime/program_support.c`. Everything else in `runtime/` is compiler-only.

### Wrapped, and the wrapper is the supported API

| C symbol | Prismio | Contract |
|---|---|---|
| `str_with_capacity` | internal allocation seam for `std.string` | `produce(free)` |
| `str_find_byte` `str_find_byte_pair` | internal bounded search accelerators | `borrow` |
| `read_file` `get_directory` `join_path` | `readFile` `directoryOf` `joinPath` | `produce(free)` |
| `current_directory` `executable_directory` | `currentDirectory` `executableDirectory` | `produce(free)` |
| `list_modules` | `listModules` → `List<String>` | `produce(free)` |
| `command_quote_arg` | `quoteArg` | `produce(free)` |
| `file_exists` `delete_file` `execute_command` | `fileExists` `deleteFile` `runCommand` | → `Bool` |
| `cli_arg_count` `cli_arg` | `argCount` `arg` `argBorrowed` `argAt` `args` | `alias` |

The `Int` returns are normalised because the raw conventions disagree with each
other: `file_exists` returns 1 for yes, while `delete_file` and `execute_command`
return **0** for success. Two adjacent functions in one file where 0 means
opposite things belongs behind a wrapper.

### Superseded — still linked, no longer the supported way

`str_char_at`, `str_equals`, `str_compare`, `str_concat`, `str_substring`,
`str_from_char`, `str_trim`, `str_replace`, `str_contains`, `str_starts_with`,
`str_ends_with`, `str_index_of`, `str_to_int`, `int_to_str`, `str_clone`,
`str_split`, `str_split_free`. Use `std.string`. `str_split` in particular returned a
`StringArray*` — a struct with no Prismio type, whose two allocations had to be
released by calling `str_split_free`, which the ownership analysis knew nothing
about. `strSplit` returns a `List<String>`, which is an owned container the
analysis already understands.

### Not user-facing

Emitted by codegen, not called from source: `rc_*`, `cyc_*`, `arena_*`,
`list_set_elem_*`, `list_push_inline` and the other inline-element entry points,
`rt_profile_*`, `aif_verify_*`, `heap_reset`, `prismio_expect`.

Compiler-internal, for the self-hosted frontend only: `ptr_to_node`,
`node_to_ptr`, `ptr_to_token`, `token_to_ptr`, `ptr_to_type`, `type_to_ptr`, and
everything in `ir_symbols.c`, `aif_support.c`, `diagnostics.c`,
`build_driver.c`, `llvm-api-backend.c`.

### Not yet wrapped

`chan_new`, `chan_send`, `chan_recv`, `chan_close`, `chan_share`, `chan_len`,
`chan_free`, and the `prismio_task_*` family. Tasks are reached through the
`spawn` / `join` keywords rather than through these symbols; channels have no
module yet and no ownership contract written down. Until they do, they are
`extern fn` at your own risk.

---

## 5 · Where the performance actually is

Measured 2026-08-24 against **pure C and pure Rust programs** — not Prismio
calling C. Each program times its own loop, mutates an input to defeat hoisting,
and the harness rejects variants whose checksums disagree. Reproduce from
`aif/evidence/xlang/strings`. The table reports best of three interleaved runs.

| workload | C | Rust std | Rust `memchr` 2.8.3 | Prismio |
|---|---:|---:|---:|---:|
| search, selective 4-byte miss | 2.979s | 1.854s | 0.149s | **0.148s** |
| search, dense false candidates | 0.410s | 0.053s | 0.107s | **0.048s** |
| search, selective 40-byte miss | 2.837s | 2.143s | 0.808s | **0.740s** |
| uppercase | 0.270s | 0.399s | — | **0.269s** |
| integer → string | 0.042s | 0.039s | — | **0.038s** |
| concatenate 20 KB + 20 KB | **0.200s** | **0.200s** | — | 0.201s |

**Search is a hybrid, because no one algorithm wins every distribution.**
Needles of 2–32 bytes use two predictive bytes as a packed-pair SIMD filter.
Dense false candidates switch after four attempts to a native Two-Way loop;
long needles use the same pair scan as a prefilter around Two-Way and assess it
in 50-skip windows, disabling it below eight skipped bytes on average. The
short window reflects the cost of returning every candidate across the ABI.
The vector loop checks 32 starts at a time and uses a narrowed NEON movemask
rather than extracting 16 lanes. This is why all three cases are at parity with
or slightly ahead of the best Rust arm while retaining Two-Way's linear bound.

**Integer formatting is at parity with Rust and 2.2x faster than C's `sprintf`.**
Getting there was not the arithmetic: a two-digit table and a comparison-based
digit count each moved it by under 2%. It was the *second allocation* --
`strFromInt` called `strFromUnsigned` and then `str_concat(digits, "")`, the
concat existing only so the returned value would be this function's own
allocation rather than a pass-through. Writing the sign into the same buffer as
the digits took it from 0.078s to 0.038s.

**Uppercase now ties C.** `strToUpper` was already vectorised -- clang emits
`ldp q/…/add.16b`, 64 bytes per iteration. Making `String` a `{ptr, len}` pair
and lowering `__builtin_string_len` as a field read removed the repeated
`strlen`, taking the measured workload from 0.520s to 0.271s.

**Native concat reuses both lengths.** The corrected cross-language benchmark
reads one byte from each input half of the result and puts all three languages
within 4%. An older checksum observed only the first half, so C and Rust could
delete the second copy and their apparent lead was not a concatenation result.
Within Prismio, the legacy C compatibility function is still slower because it
re-measures both inputs; native `strConcat` allocates once and fills from lengths
already carried by the values.

Two changes got here from a starting point of 30x slower than the C:

- **Byte access is a compiler builtin.** `__builtin_string_byte_at` and
  `__builtin_string_put_byte` lower to a GEP plus a load or store rather than a
  call — user programs do not link with LTO, so the old ordinary externs cost a
  call per byte. Worth 1.85s → 0.56s on search alone.
- **Checked character access is native too.** `strCharAt` tests the carried
  length and performs the same byte load as `strByteAt`, so both are O(1).
  Inner loops still use the unchecked form after establishing one shared bound.

## 6 · Known limits

**The old recursion ceiling is gone.** `strToUpper`, `strToLower`, `strReverse`,
`strRepeat`, `strPadStart` and `strJoin` used to recurse once per character —
forced, because the loop form leaks: a reassigned binding is never droppable (see
`ir_mark_droppable` in `src/ir/stmt.psm`), so `let mut out = ""` plus `strConcat`
in a loop leaks one allocation per iteration. That cost n allocations, copied
O(n²) bytes, and overflowed the stack at 200 000 characters.

`str_with_capacity` and the write builtin replaced the recursion with a single
allocation the function fills in one pass. Measured on an Apple-silicon host:
5 000 000 characters now succeeds, and a 13-call program dropped from 58
allocations to 29.

**Use the unchecked builtins only with an established bound.** `strLength`,
`strCharAt` and `strByteAt` are O(1) now. The first two are safe; the internal
byte read/write builtins deliberately omit an upper-bound check, so native
builders use them only inside loops bounded by a carried String length.

**`str_replace`, `str_clone`, `str_trim` and `str_split` are absent from the
contract tables.** They allocate on every path and appear in neither
`aifFfiProduces` (`src/aif/contracts.psm`) nor `FFI_RETURNS_PRODUCE`
(`aif/prototype/aif.py`). Nothing in `std.*` calls them any more, so no supported
path is affected, but a hand-written `extern fn` for one of them still leaks
unless it carries `produce(free)`. `run_oracle_vocabulary_test` cannot catch this
class: it compares the two tables against each other, and both omit the same four
names. It should also be compared against the C.
