# Subprocess API — progress

**Temporary.** CLAUDE.md says this repository keeps no `TODO.md` or `HANDOFF.md`;
this is one feature's tracker, kept because the work spans sessions, and it is
deleted when the feature lands and `aif/evidence/RESULTS-subprocess-api.md`
replaces it. Do not grow it into general scaffolding.

The feature is specified in KNOWN_ISSUES.md, "Language surface" — read that
first. This file records only *where the work is*.

---

## Status

| Stage | What | State |
|---|---|---|
| S0 | Feasibility settled | **done** |
| S1 | Capability in `runtime/program_support.c` | **done** -- and S4 found the stdin pipe never delivered EOF; fixed |
| S2 | `std/process.psm` surface, and the old API removed | **done** |
| S3 | AIF contracts, both copies | **done** -- one entry each, see below |
| S4 | `tests/test_153_subprocess.psm` | **done** -- found two defects, both fixed (below) |
| S5 | Windows half | **written with S1**; unverifiable locally, see below |
| S6 | Validation loop | **done for B1 + S4**; re-run before the final commit |
| S7 | Docs -- RUNTIME.md, KNOWN_ISSUES, ../website, evidence | RUNTIME.md and KNOWN_ISSUES done; website and evidence next |
| B1 | A struct crossing a PLIB read its fields one slot late | **fixed** -- per-compilation field order |

---

## S0 · What the probes settled

Four facts, each of which changes the design. All were measured against the
project host on 2026-09-12, not assumed.

**`let p = Process()` works** — a free function may carry its struct's name, and
`fn Process() -> Process` resolves at the call while `Process { ... }` still
resolves as a literal. So the user's spelling needs no language change.

**There are no associated functions.** `Process.new()` is *"unknown identifier
`Process`"*. The constructor is the free function above, not a static method.

**A `List<T>` does not cross the FFI boundary.** No `extern fn` in the tree takes
or returns one: `list_modules` hands back a newline-joined `String` and
`std.fs`'s wrapper splits it. Joining argv that way is wrong — an argument may
contain any byte, newline included.

So **argv is pushed one element at a time**, which is the shape
`ir_call_begin()` / `ir_call_arg()` / the call already has in `src/ir/bridge.psm`
for exactly this reason:

```
extern fn proc_spawn_begin(program: String borrow)
extern fn proc_spawn_arg(argument: String borrow)
extern fn proc_spawn_run(stdinMode: Int, stdoutMode: Int, stderrMode: Int,
                         out: SpawnOut) -> Int
```

`borrow` rather than `bytes`, because argv must be NUL-terminated and codegen
already makes that copy for a view — and therefore `proc_spawn_arg` **must copy
into its own storage**, since the boundary's copy dies when the call returns.

**A struct crosses as a pointer the callee writes into.** The precedent is
`clock_gettime(clk: Int, stamp: BenchTimespec)` in `benchmarks/prismio/common.psm`.
`SpawnOut` is therefore the out-parameter, and **every field is `I64`** so that
no padding question can arise between the two declarations:

```
struct SpawnOut {
    handle: I64,      // pid on POSIX, HANDLE on Windows
    stdinFd: I64,
    stdoutFd: I64,
    stderrFd: I64,
    error: I64        // 0, or errno / GetLastError
}
```

`handle` is `I64` and not `Int` because **`Int` is `i32`** and cannot hold a
Windows `HANDLE`.

---

## S1 · POSIX capability

In `runtime/program_support.c` — the half linked into every program, never
`build_driver.c`. No new file, so `tools/check_source_lists.py` needs nothing.

- [x] `proc_spawn_begin` / `proc_spawn_arg` — accumulate `program` and a
      `char**`, each element `strdup`ed. File-local state, reset by `begin`.
      Guard: an `arg` with no `begin` is a no-op, not a crash.
- [x] `proc_spawn_run(in, out, err, SpawnOut*)` — `pipe()` per stream set to
      pipe, `/dev/null` per stream set to discard, nothing per stream inherited;
      then `posix_spawn` with a `posix_spawn_file_actions_t`. Parent closes its
      copy of every child end. Writes `SpawnOut` and returns 0 or -1.
- [x] `proc_wait(handle) -> Int` — `waitpid`, `WEXITSTATUS`; -1 on error.
      Restart on `EINTR`.
- [x] `proc_kill(handle) -> Int` — `SIGKILL`.
- [ ] `proc_exec()` — `execvp` over the accumulated vector; returns only on
      failure.
- [ ] `proc_read(fd, max) -> String produce(free)` and
      `proc_write(fd, s) -> Int`, `proc_close(fd) -> Int`. `proc_read` must
      allocate through `rt_base_alloc` (C_CODE_STYLE's first invariant) and must
      never return a string literal on any path.

Landed as `proc_spawn_begin`, `proc_spawn_arg`, `proc_spawn_run`, `proc_wait`,
`proc_kill`, `proc_exec`, `proc_read_all`, `proc_write`, `proc_close`. The read
is `proc_read_all(fd)` -- everything until EOF -- rather than a bounded read; a
bounded one can be added when something needs it.

**Windows cannot be compiled here.** `clang --target=x86_64-pc-windows-msvc`
stops at `stdio.h`: there is no Windows SDK on this machine. The leg is written
(`CreateProcess`, `CreatePipe` + `SetHandleInformation` so only the child's end
is inheritable, `_open_osfhandle` so descriptors are the one abstraction,
`WaitForSingleObject` + `GetExitCodeProcess`, `TerminateProcess`) and its
argument quoting follows `CommandLineToArgvW`'s backslash rule rather than
`command_quote_arg`'s simpler one -- but **CI is the first thing that will
compile it**, so treat the first Windows leg as the review.

**Modes:** `0 inherit, 1 pipe, 2 discard`. One spelling in three places
(`std/process.psm`, `program_support.c`, and the fixture) — the constant-drift
rule in C_CODE_STYLE. Consider `run_elem_mode_agreement_test`'s shape if this
grows.

## S2 · The Prismio surface

`std/process.psm`. `runCommand` and `quoteArg` are **removed**, not kept beside
the new API — `tests/test_76_std_fs.psm` asserts `quoteArg` today and moves with
them.

```
let p = Process()
p.program = "git"
p.arguments = ["status", "--short"]
p.stdout = StreamMode.Pipe

let child = p.spawn()          // Child, running
let status = p.run()           // spawn + wait, the exit status
p.exec()                       // replaces this process; does not return

child.stdout.readAll()
child.stdin.write("...")
child.wait()
child.kill()
```

`p.arguments = [...]` is f3a6846's list literal, which works for an assignment
and a field initialiser. **A list literal is still not accepted as a call
argument** (KNOWN_ISSUES, Codegen), so nothing in this API may take one
positionally.

## S3 · AIF contracts — done, and smaller than expected

**A parameter table entry was not needed.** Both tables are a *fallback*: an
extern a source declares carries its contract in the AST and the analysis reads
it there, which `aif.py`'s own comment says outright ("these tables never fire").
The builtin entries exist only because a builtin has no declaration to read. So
the ten new externs need nothing, and the one entry each side did need is the
producing return:

- [x] `src/aif/contracts.psm` — `proc_read_all` in `aifFfiProduces`.
- [x] `aif/prototype/aif.py` — `proc_read_all` in `FFI_RETURNS_PRODUCE`.

## B1 · A struct crossing a PLIB -- fixed

**Cause: LAYOUT 7.2 orders fields by access count, and the count is the
compilation's.** `Process`'s three `i32` modes tie on width, so a program that
assigns `p.stdout` put `stdout` ahead of `stdin` while the library compile kept
declaration order. The LLVM bodies were identical; only the name-to-index maps
differed. In the checkout both halves were one compilation, so the swap
cancelled. The lead in the brief (an `extern fn` taking a struct) was not it --
though `SpawnOut` reaching C is the same premise broken a second way.

**Fix:** `aif_layout_fix` -- a `std.*` struct keeps declaration order and is never
split, in the checkout too (`aifLayoutFixStandardLibrary`). Guard: the
`std.process` case in `run_module_artifact_test`, which prints
`'discarded\npiped\nstatus=0 out='` on the pre-fix compiler.

**Also wrong in the old notes:** the comment in `Process.spawn` that the modes had
to be read before `self.arguments` "or `self.stdout` came back as `Inherit`" was
this bug, misattributed. Reading them after works in and out of tree.

## What S4 found

1. **A stdin pipe never delivered EOF.** `posix_spawn` passes every descriptor
   not marked close-on-exec, so the child held its own copy of the write end of
   its stdin. `FD_CLOEXEC` on the parent's end fixes it. The Windows half already
   cleared inheritance there.
2. **A struct field that could hold a string literal was freed as if it owned
   it** -- unsoundness, not specific to this feature. `Process()` stores `""` in
   `program`; any owned value stored there anywhere made the generated release
   free `.rodata`. Fixed by carrying "may be no site" through value sets
   (`aif_vs_mark_untracked`, `key_may_be_untracked`); such a field releases
   nothing. KNOWN_ISSUES, Ownership, has the cost.

## S4 · The fixture -- done

`tests/test_153_subprocess.psm` (150-152 were taken by the time it landed). **The
child is the fixture itself**, run with a mode argument through
`process.args[0]`, so no system command and no working directory is involved.

- [x] `run` returns the child's exit status, and a non-zero one is visible.
- [x] `Pipe` on stdout reads back exactly what the child wrote; stderr too.
- [x] `Discard` produces no output and does not hang -- checked one level down.
- [x] `spawn` + `wait` agree with `run`.
- [x] `kill` on a blocked child returns and `wait` does not hang.
- [x] stdin: write, close, read back.
- [x] `exec` replaces the child (POSIX only), and fails cleanly on a missing program.
- [x] `--verify`: 0 violations; every pipe buffer released. The unreleased
      allocations are `Process.program` (the literal-field fix declines it) and
      the constructor's list displaced by `p.arguments = [...]` (field
      assignment never releases -- KNOWN_ISSUES).

## S5 · Windows

Same file, behind `#ifdef _WIN32`. `CreateProcess`, `CreatePipe` with
`bInheritHandle`, `WaitForSingleObject` + `GetExitCodeProcess`,
`TerminateProcess`. Descriptors come back as `int` through `_open_osfhandle`, so
`Stream` is one type on both platforms.

**There is no true `exec` on Windows.** `_execvp` spawns and exits, which is
observably different — a parent waiting on the original process sees it finish.
Document it rather than hiding it.

## S6 · Validation

Toolchain for the record: fixpoint `125efe1e928003a3476f3ff74581840a` (the brief's
`d196553...` predates de1e910), packaged as `build/dist-glob`.

- [x] `python3 tools/check_source_lists.py`
- [x] two generations to a fixpoint, IR of `src/main.psm` equal
- [x] `python3 tools/run_suite.py --compiler <packaged>` -- 337/337
- [x] `python3 tools/aif_differential.py --compiler <packaged>` -- two lines on
      `src/main.psm`, byte-identical to the pre-change compiler's
- [x] `python3 tools/check_externs.py --dist <packaged>`
- [x] `tools/ir_snapshot.py` before and after -- 14 programs moved by B1 (`Map`
      index swap, `Result<Int, String>` padding), one more by the literal fix
      (`test_67`, which stores a literal `Some`)
- [x] the committed seed still builds the tree to the same fixpoint
- [ ] re-promote `.prismio/build/debug/prismio` -- it refuses to build now that
      `program_support.c` changed ("runtime library is stale")

## S7 · Docs

- [ ] `RUNTIME.md` — the wrapped-symbol table rows for the new externs, and
      `execute_command` / `command_quote_arg` move to "Superseded"
- [ ] `KNOWN_ISSUES.md` — the "Language surface" entry becomes what is *left*
      (environment variables, the current pid, `Stdio` redirection to a file)
- [ ] `../website/apps/docs/content/stdlib/process.md` — the "Subprocesses" and
      "Still missing" sections. **Do not commit that repo**; its example gate is
      `cd ../website/apps/docs && PRISMIO=<packaged> PRISMIO_INTERNAL_HOSTED=1
      node scripts/verify-doc-examples.mjs`
- [ ] `aif/evidence/RESULTS-subprocess-api.md`, and delete this file

---

## Trip hazards paid for already

- A bare `tools/bootstrap.sh` generation is **not** a toolchain. Package it
  (`tools/package.py --compiler <abs path> --out build/distX`) before building
  any program with it, or use the project host.
- A binary named `prismio` inside the repo forwards to the project host unless
  `PRISMIO_INTERNAL_HOSTED=1`.
- A compiler resolves `std/` by walking up from the **entry file**, so an old
  compiler cannot build anything inside the checkout once `std/` has changed.
  Build comparison arms from a scratch directory outside the tree, both from the
  same cwd.
- Runner patterns select file fixtures only; call a programmatic test directly.
- Commit with explicit paths. `sandbox/` is the user's and is never committed.
- After a `runtime/*.c` edit the project host refuses to build ("the installed
  Prismio runtime library is stale"). Bootstrap from a bare generation instead.
- A string of twelve bytes or fewer is inline and allocates nothing, so a leak
  probe built on short literals reads clean whatever it is probing.
