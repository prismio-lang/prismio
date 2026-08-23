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

**Primitives — must be C.** Four, and only four:

| | |
|---|---|
| `str_length` | the byte count |
| `str_byte_at` | read a byte — `String` is opaque and the language has no index syntax |
| `str_with_capacity` | allocate n bytes, behind the verify seam |
| `str_put_byte` | write a byte into what you just allocated |

Read a byte, write a byte, allocate, measure. Nothing else about strings needs C.

`str_equals`, `str_compare`, `str_concat`, `str_substring`, `str_char_at` and
`str_from_char` are also still in C and still used, but that is a **measured
choice, not a boundary**: `str_equals` is the self-hosted compiler's hottest
call, and `str_concat`/`str_substring` are one `memcpy` each against a fill loop.
An earlier version of this document called all of them irreducible. They are not.

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

The ports are checked against the C they replaced. `tests/test_75_std_string.psm`
asks both implementations the same questions — the C originals are still linked —
and compares answers, at the boundaries where a reimplementation drifts: empty
input, no match, whole-string match, overlapping needles.

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
if (str_length(list_get(names, i)) > 0) { … }   // correct
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
| `str_length` `str_char_at` `str_byte_at` | `strLength` `strCharAt` `strByteAt` | `borrow` |
| `str_with_capacity` `str_put_byte` | internal to `std.string` | `produce(free)` / `borrow` |
| `str_equals` `str_compare` | `strEquals` `strCompare` | `borrow` |
| `str_concat` `str_substring` `str_from_char` | `strConcat` `strSubstring` `strFromChar` | `produce(free)` |
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

`str_trim`, `str_replace`, `str_contains`, `str_starts_with`, `str_ends_with`,
`str_index_of`, `str_to_int`, `int_to_str`, `str_clone`, `str_split`,
`str_split_free`. Use `std.string`. `str_split` in particular returned a
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

Measured against **pure C and pure Rust programs** — not Prismio calling C, which
only compares two implementations through the same harness. Same workload, same
machine, results checked identical across all three. Startup (~1.5 ms) subtracted.

| workload | C | Rust | Prismio | vs C | vs Rust |
|---|---|---|---|---|---|
| search, 40 000× over a 40 KB haystack | 0.360s | 0.062s | **0.049s** | **0.14x** | **0.79x** |
| uppercase, 100 000× over 40 KB | 0.069s | 0.112s | 0.132s | 1.91x | 1.18x |
| integer → string, 2 000 000× | 0.083s | 0.037s | **0.038s** | **0.46x** | **1.03x** |

**Search beats both**, because `strIndexOf` skips on the needle's *last* byte
using `strchr` (vectorised) and falls back to a plain scan when the skip stops
paying. C's `strstr` has no such skip; Rust's `str::find` pays two-way setup a
6-byte needle does not earn back.

**Integer formatting is at parity with Rust and 2.2x faster than C's `sprintf`.**
Getting there was not the arithmetic: a two-digit table and a comparison-based
digit count each moved it by under 2%. It was the *second allocation* --
`strFromInt` called `strFromUnsigned` and then `str_concat(digits, "")`, the
concat existing only so the returned value would be this function's own
allocation rather than a pass-through. Writing the sign into the same buffer as
the digits took it from 0.078s to 0.038s.

**The uppercase gap is `strlen`, not vectorisation.** `strToUpper` *is*
vectorised -- clang emits `ldp q/…/add.16b`, 64 bytes per iteration. What it pays
that C does not is a `str_length` per call, because a `String` carries no length.
Measured in C with the same structure: 0.0044s with the length known, 0.0064s
with a `strlen` per call, against Prismio's 0.0050s -- so Prismio is *faster than
the equivalent C* and the residue is the length lookup. This is the one workload
where a fat `{ptr, len}` `String` would pay for itself directly.

Two changes got here from a starting point of 30x slower than the C:

- **Byte access is an intrinsic.** `str_byte_at` and `str_put_byte` lower to a
  GEP plus a load or store rather than a call — user programs do not link with
  LTO, so as ordinary externs they cost a call per byte. Worth 1.85s → 0.56s on
  search alone.
- **Lengths are hoisted out of loops.** `str_length` and `str_char_at` are both
  O(n) — `str_char_at` calls `strlen` to range-check *every* byte read. Leaving
  either in a loop condition is quadratic: 15.08s against 0.48s hoisted.

## 6 · Known limits

**The old recursion ceiling is gone.** `strToUpper`, `strToLower`, `strReverse`,
`strRepeat`, `strPadStart` and `strJoin` used to recurse once per character —
forced, because the loop form leaks: a reassigned binding is never droppable (see
`ir_mark_droppable` in `src/ir/stmt.psm`), so `let mut out = ""` plus `strConcat`
in a loop leaks one allocation per iteration. That cost n allocations, copied
O(n²) bytes, and overflowed the stack at 200 000 characters.

`str_with_capacity` and `str_put_byte` replaced the recursion with a single
allocation the function fills in one pass. Measured on an Apple-silicon host:
5 000 000 characters now succeeds, and a 13-call program dropped from 58
allocations to 29.

**Do not put `str_length` or `str_char_at` in a loop condition.** Both are O(n) —
`str_char_at` calls `strlen` to range-check every byte read. Measured on 200
scans of 40 000 characters: 15.08s with them in the loop against 0.48s hoisted,
where the C `str_index_of` is 0.50s. `str_byte_at` and `str_put_byte` are the
O(1) pair and do no upper-bound check, so use them only where the bound is
already established.

**`str_replace`, `str_clone`, `str_trim` and `str_split` are absent from the
contract tables.** They allocate on every path and appear in neither
`aifFfiProduces` (`src/aif/contracts.psm`) nor `FFI_RETURNS_PRODUCE`
(`aif/prototype/aif.py`). Nothing in `std.*` calls them any more, so no supported
path is affected, but a hand-written `extern fn` for one of them still leaks
unless it carries `produce(free)`. `run_oracle_vocabulary_test` cannot catch this
class: it compares the two tables against each other, and both omit the same four
names. It should also be compared against the C.
