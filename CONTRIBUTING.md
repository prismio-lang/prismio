# Contributing to Prismio

This guide covers building the compiler from a change, testing it, and what a
change needs before review. It assumes you have read the [README](README.md).

- [How the compiler is built](#how-the-compiler-is-built)
- [Setting up](#setting-up)
- [The edit loop](#the-edit-loop)
- [Testing](#testing)
- [Rules that break the build a generation later](#rules-that-break-the-build-a-generation-later)
- [Where things live](#where-things-live)
- [Commits and pull requests](#commits-and-pull-requests)
- [Troubleshooting](#troubleshooting)

## How the compiler is built

The compiler is written in Prismio, so building one always needs an existing
compiler. There are three ways to get one:

1. **The seed.** `bootstrap/prismio-seed.ll` is committed LLVM IR for a compiler
   built from an earlier tree. `tools/bootstrap.sh --seed` compiles it with the
   pinned clang. It is how a machine with no Prismio starts, and how you recover
   when your compiler is too old to read the current sources.
2. **A named generation.** `tools/bootstrap.sh --compiler build/genN --out
   build/genN+1` builds the tree with a compiler you name. Use it for anything
   where the exact compiler matters: fixpoint checks, bisecting, the release gate.
3. **The project host.** With an installed `prismio`, running `prismio build` at
   the repository root builds the compiler into `.prismio/build/debug/prismio`,
   and later runs forward to that host. It is the fastest loop, and it only works
   while the host can parse the tree ([Troubleshooting](#troubleshooting)).

The compiler lowers to LLVM IR through the LLVM C API, in process. The backend is
C (`runtime/llvm-api-backend.c`), reached only through the `extern fn`
declarations in `src/ir/bridge.psm`. The runtime programs link against is also C
(`runtime/lang_runtime.c`, `runtime/program_support.c`). Most changes are
Prismio under `src/` and `std/`, but a change to the runtime surface is C as well.

## Setting up

| Requirement | Notes |
|---|---|
| A C toolchain | The system linker and C library: Xcode Command Line Tools, `build-essential`, or Visual Studio's C++ tools |
| Python 3.8+ | Setup, the test runner, and the tools under `tools/` |
| LLVM 23.1.1 | Pinned. `python3 tools/setup_llvm.py` downloads it into `third_party/llvm` and checks its SHA-256. Nothing on the system is used; `--llvm-dir <path>` adopts a local build on a platform with no release archive |

```bash
python3 tools/setup_llvm.py
tools/bootstrap.sh --seed --out build/gen0
tools/bootstrap.sh --compiler build/gen0 --out build/gen1
```

Put `third_party/llvm/bin` first on `PATH` for testing. The build itself never
reads `PATH` for LLVM, but a few tests and tools call `clang` or `llvm-nm` by
name, and a system LLVM older than 23 cannot read this LLVM's bitcode:

```bash
export PATH="$PWD/third_party/llvm/bin:$PATH"
```

## The edit loop

After a change under `src/`, `std/` or `runtime/`:

```bash
tools/bootstrap.sh --compiler build/gen1 --out build/gen2     # your change, built by the old compiler
tools/bootstrap.sh --compiler build/gen2 --out build/gen3     # your change, built by itself

mkdir -p /tmp/fx/a /tmp/fx/b
build/gen2 build src/main.psm -o /tmp/fx/a/prismio.ll
build/gen3 build src/main.psm -o /tmp/fx/b/prismio.ll
cmp /tmp/fx/a/prismio.ll /tmp/fx/b/prismio.ll                 # must be identical

python3 tools/package.py --compiler build/gen3 --out build/dist
PRISMIO=$PWD/build/dist/bin/prismio python3 tests/test_runner.py
```

**Two generations before you believe it.** The first generation was built by the
old compiler. The second is the first one your change built. If their IR
differs, the change is wrong even when every test passes. Build both to the same
file name in different directories, because the output path is embedded in the IR.

**Test a packaged compiler, not a bare generation.** `tools/package.py` lays out
`bin/`, `lib/runtime/*.bc` and `stdlib/`. A bare `build/genN` has no runtime
bitcode beside it, so almost every test fails.

A generation takes seconds once the C objects are cached. `build/genN --version`
prints the compiler's directory and the standard library it resolves.

## Testing

```bash
PRISMIO=$PWD/build/dist/bin/prismio python3 tests/test_runner.py                  # everything
PRISMIO=$PWD/build/dist/bin/prismio python3 tests/test_runner.py test_193_map_methods
python3 tests/test_runner.py --list
```

`$PRISMIO` (or `--compiler`) wins over `PATH`. Set it every time, because
otherwise the runner uses whatever `prismio` is installed. A filtered run skips
the suite's integration checks, so finish with an unfiltered one.
`PRISMIO_TEST_JOBS=1` runs one test at a time, for a failure that looks like
interference.

**Kinds of test in `tests/`:**

| File | What passes |
|---|---|
| `test_<N>_<what>.psm` | builds, runs, exits 0. Print `PASS: ...` and return non-zero on any failure |
| `neg_<N>_<what>.psm` | fails to compile, with every `// expect-error: <text>` line found in the diagnostics |
| `*_probe.psm` | run by a named check in `test_runner.py`, usually under `--verify`, to pin one ownership shape |

Use the next free number. A test should cover one behaviour and say in its header
comment what it checks and why. For anything that allocates, check the ledger:
`prismio run file.psm --verify` ends with `N allocated, N released, 0 leaked, 0
violation(s)`. A **violation** is memory corruption and always a bug. A **leak** is
a bug too, and if it is accepted it goes in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

**Before asking for review**, also run:

```bash
python3 tools/lint.py
python3 tools/format_sources.py --check
python3 tools/aif_differential.py --compiler build/gen3
python3 tools/check_source_lists.py
```

`tools/release_gate.py --rc build/dist/bin/prismio` runs every check at once:
generations, fixpoint, seed, suite, differential, corpus, `--verify` sweep, JIT,
packaging. [RELEASE.md](RELEASE.md) §1 says how.

## Rules that break the build a generation later

Breaking either of these fails a later build with nothing pointing at the cause:

- **The committed seed must be able to parse `src/` and `std/`.** New syntax lands
  in two commits. First teach the frontend without using the syntax. Then
  refresh the seed (`tools/refresh_seed.sh --compiler build/genN`). Only after that
  use the syntax.
- **A change meant to preserve behaviour must produce byte-identical IR** for every
  program in `tests/` and `aif/corpus/`. Compare the IR from the compiler before
  and after, not just the test results.

And two that fail as memory corruption rather than a leak (C_CODE_STYLE.md has more):

- An allocation returned to Prismio goes through `rt_base_alloc`. A temporary the
  runtime frees itself does not.
- An `extern fn` returning memory it allocated is `produce(free)`. One returning a
  pointer into something it does not own is `alias`. Declaring the second as the
  first hands foreign memory to the deallocator.

## Where things live

| Path | What |
|---|---|
| `src/lexer`, `src/parse` | Tokens and the parser |
| `src/sema` | Type checking, generics (`generics.psm`), ownership, control flow |
| `src/aif` | Allocation inference: the model, the walk, layout, reports |
| `src/ir` | Lowering to LLVM IR; `bridge.psm` declares the backend |
| `src/driver`, `src/project`, `src/main.psm` | Import resolution, the build pipeline, manifests, the CLI |
| `std/` | The standard library, one module per file (`std/map.psm` is `import std.map`) |
| `runtime/` | The C runtime, the AIF solver (`aif_support.c`), the LLVM backend, the build driver |
| `aif/prototype/aif.py` | The reference oracle the differential compares against |
| `ums/` | The build manifest language and its resolver |

A module's import path is its location under `src/` (or `std/`): `src/ir/expr.psm`
is `import ir.expr`.

**Style.** Read [CODE_STYLE.md](CODE_STYLE.md) before writing `.psm` and
[C_CODE_STYLE.md](C_CODE_STYLE.md) before writing C. When you change what a program
can call, the `std/` wrapper and its entry in [RUNTIME.md](RUNTIME.md) are part of
the same change.

**Planning** lives in `docs/`: [STDLIB_SHIP_PLAN.md](docs/STDLIB_SHIP_PLAN.md),
[MEMORY_PLAN.md](docs/MEMORY_PLAN.md), [PERFORMANCE_PLAN.md](docs/PERFORMANCE_PLAN.md),
[COLLECTIONS.md](docs/COLLECTIONS.md), [CHANNELS_PLAN.md](docs/CHANNELS_PLAN.md).
Each is split into what the current release needs and what comes later. Open
defects are in [KNOWN_ISSUES.md](KNOWN_ISSUES.md), and measurements in
`aif/evidence/RESULTS-*.md`.

## Commits and pull requests

**A commit message carries its own evidence.** The subject line says what changed
in plain words, as in `std.map: removal, clear, and methods on Map` or `Fix three
ownership shapes that freed memory that was not live`. The body says why, what was
measured, and how it was checked: the fixpoint, the suite result, the
differential, and before/after numbers for a performance change. `git log` is this
project's record, so write for the person bisecting a year from now.

Keep a change to one concern. A pull request against `main` should include:

- tests for the behaviour it adds or fixes, with ownership probes under
  `--verify` where it allocates;
- a two-generation fixpoint, a passing suite, and an agreeing differential,
  stated in the description;
- updates in the same change to `CHANGELOG.md` (anything user-visible),
  `RUNTIME.md` (the runtime or std surface) and `KNOWN_ISSUES.md` (anything found
  and not fixed);
- an `aif/evidence/RESULTS-*.md` file for a performance claim, with the commands
  and the machine.

A failing test is never fixed by skipping it. If the failure is an environment
difference, say which, and show it passing where the environment is right.

User documentation is in a separate repository, `prismio-lang/website`. A
language or library change needs a docs change there, checked with its
`verify-doc-examples.mjs` against a packaged toolchain.

## Troubleshooting

**`prismio build` fails to parse something in `std/` or `src/` after a pull.** Your
project host at `.prismio/build/debug/prismio` is older than syntax the tree now
uses. Rebuild it from the seed:

```bash
tools/bootstrap.sh --seed --out build/gen0
tools/bootstrap.sh --compiler build/gen0 --out build/gen1
python3 tools/package.py --compiler build/gen1 --out build/dist
rm -rf .prismio/build/debug
build/dist/bin/prismio build
```

**"Missing runtime module: lib/runtime/program_support.bc".** You ran a bare
`build/genN` where a packaged compiler is needed. Package it with
`tools/package.py`.

**A program built in the tree says the runtime sources have changed.** A packaged
toolchain refuses to build in-tree programs once `runtime/` differs from what it
was packaged with. Re-package, or build outside the checkout.

**`verify_separation`, `module_artifacts` or `target_cross` fail locally.** The
system `llvm-nm` or `clang` is older than LLVM 23. Put `third_party/llvm/bin` first
on `PATH`.

## Code of conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
Report unacceptable behaviour privately to the maintainers.
