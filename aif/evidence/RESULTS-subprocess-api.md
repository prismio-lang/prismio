# Results: the subprocess API (2026-09-12 to 2026-09-16)

`std.process` could run a shell command and answer a `Bool`. It now starts a
program with an argument vector, connects each of its three streams to this
process, the null device or nothing, and hands back a `Child` to wait on, kill,
read and write. `runCommand` and `quoteArg` are gone. KNOWN_ISSUES, "Language
surface", lists what is still missing; RUNTIME.md (now [the runtime surface](https://developers.prismio.org/runtime/supported-surface)) has the C surface.

```prismio
let p = Process()
p.program = "git"
p.arguments = ["status", "--short"]
p.stdout = StreamMode.Pipe
let child = p.spawn()
let output = child.stdout.readAll()
let status = child.wait()
```

Machine: an Apple M-series Mac, LLVM 22.1.8. The final toolchain is a
two-generation bootstrap at `src/main.psm` IR
`125efe1e928003a3476f3ff74581840a`, packaged with `tools/package.py` and then
promoted as the project host.

Commits: `cc001d7` (capability and surface), `2018c44` (struct layout across a
PLIB), `67c8e48` (fixture, stdin EOF, literal fields), and the one that added
this file.

## What the design had to work around

Four facts, each measured against the compiler before any code was written:

- **`let p = Process()` needs no language change.** A free function may carry
  its struct's name; `Process { ... }` still resolves as a literal. There are no
  associated functions, so `Process.new()` is not an option.
- **A `List<T>` does not cross the FFI boundary**, and joining argv with a
  separator is wrong because an argument may contain any byte. The vector is
  pushed one element at a time -- `proc_spawn_begin`, `proc_spawn_arg` per
  argument, `proc_spawn_run` -- the shape `ir_call_begin` already has, with the
  same limit: one spawn under construction per process. `proc_spawn_arg` copies,
  because the boundary's NUL-terminated copy dies when the call returns.
- **A struct crosses as a pointer the callee writes into** (the
  `clock_gettime(clk, stamp)` precedent), so `SpawnOut` is the out-parameter and
  every field is `I64`, leaving no padding to disagree about.
- **`Int` is `i32`**, so a handle -- a pid, or a Windows `HANDLE` -- is `I64`.

The AIF contracts needed one entry per side (`proc_read_all` produces), not one
per extern: a declared `extern fn` carries its contract in the AST, and the
tables are the fallback for builtins.

## A struct crossing a `.plib` read its fields one slot late

**Symptom.** Built inside the checkout the reproducer
(`aif/evidence/subprocess-2026-09-12/plib-field-shift.psm`) printed
`out=[piped\n]`. Built from a directory with no `std/` above it, against the
packaged `stdlib/process.plib`, the discarded child's output reached the
terminal and `out=[]`: the mode assigned to `stdout` arrived in the C function as
`stdin`'s, and `child.stdout.descriptor` held the `stdin` descriptor.

**Five shapes that did not reproduce it** were tried first, against a probe
struct in `std/platform.psm`: three plain `Int` fields; a `String` before three
enums; the same plus a `List<String>`; a constructor with the struct's name; and
the fields named `stdin`/`stdout`/`stderr`.

**What did.** The program's IR stored `p.stdout` through
`getelementptr %Process, ..., i32 2` -- `stdin`'s slot -- and the in-tree IR did
the same, while `std.process`'s own `spawn` in the in-tree build read `stdin` at
3 and `stdout` at 2. The names were swapped, consistently, within one
compilation. `generateStructDecl` registers fields in the order
`aif_layout_field` returns, and LAYOUT 7.2's search (`aif_layout_select`) ranks
by padding, then width, then **access count**. `Process`'s three modes are all
`i32`, so the count decides; the program writes `p.stdout`, the library compile
that built the PLIB saw equal counts. Extracted with `llvm-dis`, the PLIB's
`%Process` and the program's were both `{ %prismio.str, ptr, i32, i32, i32 }`.

The lead in the tracker -- an `extern fn` taking a struct -- was not the cause,
but it is the same premise broken a second way: the generator's comment said
permuting is safe "only because C sees a Prismio struct as an opaque `void*`",
and `proc_spawn_run` writes `SpawnOut`'s fields.

**Fix.** `aif_layout_fix` marks a type whose layout is an ABI: declaration order,
and a split veto a `--force-layout` cannot clear. `aifLayoutFixStandardLibrary`
pushes it for every struct declared in a `std.*` module -- in the checkout too,
so that the suite tests the layout installed programs get.

| | Before | After |
| --- | --- | --- |
| reproducer, out of tree | `out=[]`, child output on the terminal | `out=[piped\n]` |
| `run_module_artifact_test`'s new `std.process` case | prints `'discarded\npiped\nstatus=0 out='` | passes |
| `src/main.psm` IR | | fixpoint `1282050454fc9b4c212e919c693c6db7`; only local numbering moved |
| IR of 197 programs | | 14 move: `Map`'s `values`/`slots` stop swapping; `Result<Int, String>` 24 -> 32 bytes |

`Result` declares `Err` first, which is why its declaration order pads. Both
`Map` slots are pointers inside one 32-byte header.

## Two defects the fixture found

`tests/test_153_subprocess.psm` spawns *itself* with a mode argument, so it
needs no system command: `echo`, `cat` and `cmd /c` are not the same program on
every host, and `cmd` re-parses the quotes the Windows spawn writes.

**A stdin pipe never delivered EOF.** The `cat` mode hung, and the parent with
it. `posix_spawn` passes every descriptor not marked close-on-exec, so the child
held its own copy of the write end of its stdin; `stdin.close()` in the parent
changed nothing. `FD_CLOEXEC` on the parent's end fixes it, and also stops the
end leaking into later children. The Windows half already cleared inheritance.

**The generated release freed a string literal.** With the hang fixed, the
fixture printed its PASS line and aborted in `__aif_release_Process`: "pointer
being freed was not allocated". The field was `program`, which `Process()`
defaults to `""`. Six probes with a user struct located it:

| probe | shape | before |
| --- | --- | --- |
| a | literal in a constructor function, owned value assigned elsewhere | abort |
| b | literal and owned in `main`, both stack structs | clean -- nothing is released |
| c | owned first, literal assigned after | clean |
| d | literal in a constructor function, owned in `main` | abort |
| e | literal reaching the field through a parameter | abort |
| f | literal moved out of the field and dropped | abort (the struct's release, not the local's) |
| g | a module-level `let` stored into the field | abort |

A literal is not a site, so the field's points-to set held only the owned one,
`field_release_of` agreed on OBJECT, and the release freed whatever the object
held. `runtime/aif_support.c` already said, of return values, that closing this
"needs the points-to lattice to carry 'may hold something untracked'".

That is the fix, as a flag rather than a lattice element: a value set may be
marked untracked (a string literal, an `alias` extern's static return, a read of
a module-level `let` the function never declared), a key inherits it through
every BIND, STORE and ARG constraint (`key_may_be_untracked`, a monotone closure
like `fn_ret_partial`), and `field_release_of` answers NONE for such a field.
All seven probes run clean.

Promoting the literal at the store would reclaim more, and is not sound across a
PLIB: `Process()` lives in `process.plib`'s bitcode, compiled before any program
decides whether the field is released.

## Validation of the final tree

| Check | Result |
| --- | --- |
| two generations, `src/main.psm` IR | `125efe1e928003a3476f3ff74581840a` at both |
| committed seed -> gen0 -> gen1 | same fixpoint; no seed refresh needed |
| compiler releases changed by the literal fix | `UmsLexer` and `UmsParser` stop freeing one field each -- parameters some caller passes a literal |
| `tools/ir_snapshot.py`, 198 programs | beyond B1's 14, only `test_67_option_result` (a literal `Some`) and `src/main.psm` |
| `tools/run_suite.py` | 337/337 |
| `tools/aif_differential.py` | two lines on `src/main.psm`, byte-identical to the pre-change compiler |
| `tools/check_externs.py`, `tools/check_source_lists.py` | clean |
| `test_153` under `--verify` | 0 violations; every pipe buffer released |
| docs example gate (`../website/apps/docs`) | 195 snippets pass; content audit 102 pages |

`test_153`'s `--verify` ledger is not balanced, and both remainders are
recorded in KNOWN_ISSUES rather than fixed here: `Process.program` never frees
an owned name (the declined field), and `p.arguments = [...]` leaks the
constructor's empty list, because a field assignment never releases the value it
replaces.

## Not verified

**The Windows half has never been compiled.** There is no Windows SDK on this
machine -- `clang --target=x86_64-pc-windows-msvc` stops at `stdio.h`. It is
written (`CreateProcess`, `CreatePipe` with only the child's end inheritable,
`_open_osfhandle`, `WaitForSingleObject` + `GetExitCodeProcess`,
`TerminateProcess`, and `CommandLineToArgvW`-compatible quoting), and the first
Windows CI leg is its review.
