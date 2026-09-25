# Standard input, and the arena that could not serve a C allocation

**Status: GREEN, 2026-09-25.** LLVM 23.1.1, x86_64 Linux (Xeon @ 2.10 GHz,
4 cores). Two-generation fixpoint; suite **417/420**, the three failures the
baseline has too (test_181's `cbrt` against this libm, `target_cross` and
`module_artifacts` against the system clang 18); AIF differential agrees on
all 19 default sources; lint, source-list and extern checks clean. The baseline is the compiler at `2ae70c4`, with the
same tree otherwise.

docs/STDLIB_SHIP_PLAN.md item 2: `stdin.lines()`, `stdin.readLine()`,
`stdin.readAll()` in a new module, `std.input`. Measuring it turned up a leak in
AIF's arena placement that is not specific to stdin. The suite turned up a
workload link failure that is not specific to stdin either (§5).

## 1 · The reader

One process-wide buffer in `runtime/program_support.c`. `io_stdin_has_line`
`memchr`s for `\n` in the bytes already read and refills 64 KiB at a time only
when there is no complete line left, compacting first and growing for a longer
line. `io_stdin_take_line` copies the pending line into an `rt_base_alloc`
block. Two calls because the `Iterator` protocol asks `hasNext` and `next`
separately, and an owned String has no null to mean end of input.

`lines()` returns the line bare. `readLine()` wraps it in `Option<String>`, which
is an allocation of its own, so the iterator is the loop spelling.

## 2 · The leak

The first benchmark run had the program doing *less* work running slower: line
count 277 ms, line-and-word count 218 ms. `--verify` on the line count:

```
aif-verify: 6 allocated, 3 released, 3 leaked, 0 violation(s)
aif-arena: 0 object(s), 0 byte(s), 3 region(s) on reporting thread
```

Three lines, three leaks, a region per line that served nothing. The loop body
had an automatic arena, and `Iterator_next__Struct_StdinLines` was bracketed
into it (SPEC 5.2.1.1), so codegen wrapped `io_stdin_take_line` in
`rt_arena_hint_push/pop`. That hint is a counter only `lang_runtime.c`'s static
`rt_alloc` reads. `io_stdin_take_line` allocates with `rt_base_alloc`, as all of
`program_support.c` does. So the block came from the heap, the region freed
nothing, and the site was off the drop list.

Narrowed with four iterator shapes: the leak needed a `next` that does not touch
`self` (a `next` that decremented a counter field was clean, because nothing got
bracketed). The iterable being a call or a binding, and the struct being empty,
made no difference.

Two defects:

1. **The model.** `aifFfiTransfersExisting` marked only `chan_recv` `foreign`, so
   every other `produce` extern counted as arena-servable. That is true only of
   `lang_runtime.c`'s `rt_alloc` callers (`str_concat`, `str_substring`,
   `str_slice`, `str_with_capacity`, `str_clone*`, `str_own`, `int_to_str`,
   `str_from_double*`). It is false for `read_file`, `join_path`, `proc_env_get`,
   `proc_read_all`, every `compiler_*` producer, and any C an application brings.
2. **The bracketed gate.** `site_arena_scope_full` checked `foreign` on the
   lexical path and returned before that check on the bracketed one.
   `bracket_candidate_serves` did not check it either, so the cost model paid for
   arenas with traffic the gate would then refuse.

Fix: the predicate is now `aifFfiArenaCannotServe` (`src/aif/contracts.psm`,
mirrored as `ffi_arena_cannot_serve` in `aif/prototype/aif.py`). It is true
unless the name is on the `rt_alloc` list or is a `__builtin_string_*`. Both
bracket clauses now refuse `foreign`.

| shape (3 lines) | before | after |
|---|---|---|
| `for line in stdin.lines()` | 6 / 3 / 3 leaked, 3 regions | 6 / 6 / 0, 0 regions |
| `let mut it = stdin.lines(); for line in it` | 6 / 3 / 3 | 6 / 6 / 0 |
| user iterator, `next` returns an extern directly | 4 / 1 / 3 | 4 / 4 / 0 |
| `test_19_runtime_split` (`join_path` in `main`) | 3 / 0 / 3 | 3 / 1 / 2 * |

\* The other two are undeclared externs (`executable_directory`,
`command_quote_arg`): opaque by design, never released.

**Blast radius:** 228 programs (`tests/*.psm`, `aif/corpus/*.psm`) built by both
compilers against the same tree. One `.ll` differs: test_19's, which loses one
`arena_push`/`pop` pair and one hint bracket around `join_path`. The oracle's tier
counts move only for a struct-kind extern return, which only `chan_recv` has.

## 3 · Throughput

Input: 3,000,000 lines, 117,958,250 bytes of text, each line 0-14 words drawn
from 16 short ones (seeded). Each program counts lines and line bytes; the `wc` variants also
count space-separated words byte by byte. Median of 11 interleaved runs, stdin
redirected from the file, stdout to `/dev/null`. clang++ 18.1.3 `-O2`,
rustc 1.94.1 `-C opt-level=3`.

| program | median | min |
|---|---:|---:|
| Prismio `for line in stdin.lines()`, count | **133.6 ms** | 125.3 ms |
| C++ `std::getline`, `sync_with_stdio(false)` | 156.4 ms | 150.0 ms |
| Rust `stdin().lock().lines()` | 273.8 ms | 267.3 ms |
| Prismio, count + words | **212.2 ms** | 205.7 ms |
| C++, count + words | 449.7 ms | 426.1 ms |
| Rust `lines()`, count + words | 606.3 ms | 590.3 ms |
| Rust `read_until` into one reused `Vec`, count + words | 461.7 ms | 445.2 ms |
| `cat` | 22.6 ms | 21.3 ms |

The Prismio line count was 276.9 ms before the fix: the arena push/pop per line
cost as much as the reading did.

What the numbers are not: Rust's `lines()` validates UTF-8 and allocates a
`String` per line; the reused-buffer variant shows how much of the gap that is.
Prismio also allocates per line, from the recycling pool (`rt_base_alloc`).
Most of the word-count gap is the byte loop, not input: C++ and Rust each spend
about 300 ms on it and Prismio about 80 ms. That was not investigated further.

## 4 · Reproducing

The generator and the four sources are short enough to keep here.

```python
import random
random.seed(7)
words = ["the","quick","brown","fox","jumps","over","lazy","dog","prismio","compiler",
         "standard","input","line","benchmark","a","of"]
with open("input.txt", "w") as f:
    for i in range(3_000_000):
        f.write(" ".join(random.choice(words) for _ in range(random.randint(0, 14))) + "\n")
```

```prismio
import std.input
import std.io
import std.string

fn main() -> Int {
    let mut lines = 0
    let mut bytes = 0
    for line in stdin.lines() {
        lines = lines + 1
        bytes = bytes + line.length
    }
    println(lines)
    println(bytes)
    return 0
}
```

The word-count variant adds, per line, a loop over `line.byteAt(i)` that counts
a word at each non-space byte after a space. The C++ uses `std::getline` into
one `std::string`; the Rust uses `for line in io::stdin().lock().lines()`.

## 5 · Why `std.input` and not `std.io`, and the workload link

Declaring `stdin` in `std.io` failed two suite checks, and both were right.

- `debug_info`: the `stdin` global was described in every `-g` program that
  printed. `std/io.psm` avoids module-level `let`s on purpose, since a std module's
  globals follow every program that imports it. The module also pulled
  `std.option` into every printing program's analysis.
- `workload`: `error: Linking globals named 'io_stdin_has_line': symbol
  multiply defined`, and the workload fell back to the static profile. The
  sandbox gives every extern the runtime does not provide a body calling
  `rt_workload_stub`, and `program_support.bc` defines the same names. This was
  not new: a workload that imports `std.fs` and calls `fileExists` fails the same
  way on the baseline compiler. `std.io` would have made it every workload.

The first moved stdin into its own module. The second is fixed in the linker:
`yield_to_workload_stubs` (`runtime/llvm-api-backend.c`) marks a runtime
function `available_externally` when the program already has a stub for it, so
the stub wins. The `workload` test now builds a variant calling `fileExists` and
`stdin.lines()` in its `setup`. That variant falls back on the baseline compiler
and profiles on this one.
