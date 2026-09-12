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
| S1 | POSIX capability in `runtime/program_support.c` | not started |
| S2 | `std/process.psm` surface, and the old API removed | not started |
| S3 | AIF contracts, both copies | not started |
| S4 | `tests/test_150_subprocess.psm` | not started |
| S5 | Windows half | not started |
| S6 | Validation loop | not started |
| S7 | Docs — RUNTIME.md, KNOWN_ISSUES, ../website, evidence | not started |

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

- [ ] `proc_spawn_begin` / `proc_spawn_arg` — accumulate `program` and a
      `char**`, each element `strdup`ed. File-local state, reset by `begin`.
      Guard: an `arg` with no `begin` is a no-op, not a crash.
- [ ] `proc_spawn_run(in, out, err, SpawnOut*)` — `pipe()` per stream set to
      pipe, `/dev/null` per stream set to discard, nothing per stream inherited;
      then `posix_spawn` with a `posix_spawn_file_actions_t`. Parent closes its
      copy of every child end. Writes `SpawnOut` and returns 0 or -1.
- [ ] `proc_wait(handle) -> Int` — `waitpid`, `WEXITSTATUS`; -1 on error.
      Restart on `EINTR`.
- [ ] `proc_kill(handle) -> Int` — `SIGKILL`.
- [ ] `proc_exec()` — `execvp` over the accumulated vector; returns only on
      failure.
- [ ] `proc_read(fd, max) -> String produce(free)` and
      `proc_write(fd, s) -> Int`, `proc_close(fd) -> Int`. `proc_read` must
      allocate through `rt_base_alloc` (C_CODE_STYLE's first invariant) and must
      never return a string literal on any path.

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

## S3 · AIF contracts

Every new extern in **both** tables, or bracketing is lost for the whole calling
function and the oracle diverges silently while the suite stays green:

- [ ] `src/aif/contracts.psm` — `aifCompilerBuiltinContract`'s neighbour for
      externs, and `aifFfiProduces` for `proc_read`.
- [ ] `aif/prototype/aif.py` — `FFI_CONTRACTS`, and `FFI_RETURNS_PRODUCE` for
      `proc_read`.

## S4 · The fixture

`tests/test_150_subprocess.psm`. It must not depend on the working directory —
`test_76`'s header explains why. Candidates that exist everywhere the suite runs:
`/bin/echo` on POSIX, `cmd /c echo` on Windows; gate with `platform.isWindows()`.

- [ ] `run` returns the child's exit status, and a non-zero one is visible.
- [ ] `Pipe` on stdout reads back exactly what the child wrote.
- [ ] `Discard` produces no output and does not hang.
- [ ] `spawn` + `wait` agree with `run`.
- [ ] `kill` on a sleeping child returns and `wait` does not hang.
- [ ] `--verify` ledger: 0 violations, and the pipe path releases what it reads.

## S5 · Windows

Same file, behind `#ifdef _WIN32`. `CreateProcess`, `CreatePipe` with
`bInheritHandle`, `WaitForSingleObject` + `GetExitCodeProcess`,
`TerminateProcess`. Descriptors come back as `int` through `_open_osfhandle`, so
`Stream` is one type on both platforms.

**There is no true `exec` on Windows.** `_execvp` spawns and exits, which is
observably different — a parent waiting on the original process sees it finish.
Document it rather than hiding it.

## S6 · Validation

The full loop, in this order. Nothing here is optional for a runtime change.

- [ ] `python3 tools/check_source_lists.py`
- [ ] two generations to a fixpoint, IR of `src/main.psm` equal
- [ ] `python3 tools/run_suite.py --compiler <packaged>`
- [ ] `python3 tools/aif_differential.py --compiler <packaged>`
- [ ] `python3 tools/check_externs.py --dist <packaged>` — needs the dist, not
      the tree
- [ ] `tools/ir_snapshot.py` before and after; only std.process programs may move
- [ ] the committed seed still builds the tree (probably no refresh: `src/` does
      not import `std.process`)
- [ ] re-promote `.prismio/build/debug/prismio`, or the user's `prismio build`
      fails naming the feature rather than the host

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
