# Test orchestration plan

What the test infrastructure becomes: one engine (`tools/testkit/`) that discovers
every check Prismio has, knows what each one reads, runs them on a resource-aware
pool, and skips work only when a fingerprint *proves* the result cannot have
changed. `prismio suite`, `prismio verify` and `prismio gate` become profiles of
it instead of three hand-chained scripts.

Status: **built, 2026-11-28** (all seven steps of §9), uncommitted. §1 is the state before;
§11 records what was built, what was measured, where it differs from the design below and
what is left.

## 1. Where we were (measured 2026-11-28, M-series host, 8 workers)

| Piece | Count | How it runs | Wall time |
|---|---|---|---|
| `tests/test_*.psm` (build, run, exit 0, `// expect-trap:`) | 362 | thread pool | together with the next row: **21.9 s** |
| `tests/neg_*.psm` (rejected, `// expect-error:`) | 365 | thread pool | (in the 21.9 s) |
| programmatic tests in `PROGRAMMATIC_TESTS` | 109 | **one at a time, after the pool** | **406 s** |
| `aif_differential`, `pir_differential`, `check_*`, sanitizer, workloads, bootstrap/fixpoint/seed | ~12 scripts | chained by `build.ums` / `gate.py` | minutes |

`prismio suite` end to end: **428.6 s wall, 836 passed.** The slowest harness tests:
`ums` 181.6 s, `lsp_features` 47.8 s, `no_inference` 38.5 s, `aif_verify` 30.4 s,
`ownership_probes` 15.2 s, `module_artifacts` 14.8 s; the other 103 together ~78 s.

Facts the design is built on, each measured rather than assumed:

1. **The harness tests are the suite's wall time, not the fixtures.** All 727 file
   fixtures finish in 21.9 s in parallel; the 109 programmatic tests then run
   serially for 406 s, 95% of the run. Parallelising them is the largest single
   win and needs no cache at all, and `ums` is 42% of the suite on its own: on
   8 workers the run can drop no lower than its 182 s until `ums` is split into
   its sub-scenarios, after which the critical path is `lsp_features` (48 s).
2. **A fixture costs ~0.4 s, and most of it is not the compiler.** For
   `test_01_variables`: front end to IR 10–40 ms, backend 17 ms, link 29 ms, and
   the **first exec of a freshly linked binary 270 ms** (macOS scans every new
   executable; the second exec is 0 ms). Skipping link+exec when nothing
   downstream changed saves ~75% of a fixture.
3. **Emitted IR is deterministic** (`build f.psm -o f.ll` twice: identical), and
   the `.ll` is the program's own module only (std bitcode is merged later).
4. **Linked executables are not reproducible**: two links of the same fixture
   differ in 49 bytes (`LC_UUID` and the ad-hoc code signature), and a build from
   another directory differs too. So "hash the binary" is not a usable key yet.
5. **Positive fixtures only check the exit status.** Nothing records stdout, so a
   compiler change that alters what a program prints passes silently.
6. **`prismio test` is taken**: it is the project command that runs a manifest's
   test targets. The orchestrator is a compiler-development tool and lives under
   `prismio suite`.
7. **Every `src/` edit changes every test's input.** The compiler is self-hosted
   and linked into one binary; all 836 tests run through it. See §3.

## 2. What changes from the proposal, and why

The proposal's goals all stand: relevance-based selection, fast-first, caching,
parallelism, a full uncached run before release, and never skipping under
uncertainty. Four parts change because of what Prismio is:

| Proposal | Here | Why |
|---|---|---|
| Impact selection from a component graph (lexer → parser → sema → …) | **Output-based impact**: re-derive every test's cheap artifact and skip only what lies downstream of a byte-identical one. The component graph orders work; it never skips it. | A lexer edit and a codegen edit both produce a new `prismio` binary that every test runs through. A path → test map could only skip soundly if it were complete, and nobody can prove that for a compiler. The IR is the compiler's actual answer, and comparing it is exact (§3). |
| Profiles `unit` / `integration` | Dropped. Profiles are `smoke`, `dev`, `full`, `verify`, `gate`, `release` | Prismio has no unit tests: every test is end to end through the driver. "Integration" is what all of them already are. |
| `prismio test --profile X` | `prismio suite [profile]` | `prismio test` is a user-facing project command. |
| "Cache results of unchanged tests" | Two cache levels, and a cached pass never satisfies `gate`/`release` | Level 1 alone (inputs unchanged) almost never hits during compiler work; level 2 (artifact unchanged) is where the savings are. |

Added, because the measurements asked for them: stdout fingerprints as a
second oracle (fact 5), parallel harness tests with resource locks (fact 1),
and a compiler-emitted link fingerprint (fact 4).

## 3. Output-based impact: the core idea

A positive fixture is a pipeline of stages, each a pure function of the stage
before plus a small set of other inputs:

```
source closure ──front end──▶ IR (.ll) ──backend──▶ objects ──link──▶ exe ──run──▶ result
     ▲ K1                       ▲ K2                  ▲ K3                          
```

- **K1, input key** = hash(test file and every file it imports, compiler
  identity, stdlib identity, flags, target, harness version for the test kind).
  If K1 matches a recorded pass, nothing runs. This hits when you edit tests,
  `tools/`, docs or the website: not when you edit the compiler.
- **K2, artifact key** = hash(emitted IR, stdlib `.plib` bytes merged, runtime
  hash (`prismio runtime-hash`), backend identity, link inputs and flags, target,
  run arguments, the expected-trap list). The front end always runs (10–40 ms);
  if K2 matches a recorded pass, backend, link and execution are skipped.
- **K3, link key** (stage 3 of the migration): the compiler itself writes a
  fingerprint of everything it hands the linker (`--emit-link-key=<file>`). Then
  only the link and exec are skipped, and the backend's own identity no longer
  has to be guessed by the tool.

Why this is sound and the component graph is not: K2 is computed from the
compiler's *output*, so a change anywhere in `src/` that alters what a test
compiles to changes K2, wherever in the compiler the change was. A change that
alters nothing (a refactor, a comment, a diagnostic elsewhere) leaves K2 alone,
which is exactly the project's existing rule that a behaviour-preserving change
produces byte-identical output. The suite turns that rule into a speed-up: a
refactor's suite run is "compile everything, run nothing", and every test whose
IR moved is listed as a finding on its own.

**Backend identity** (the one input K2 cannot see in the IR): the LLVM version,
the optimisation pipeline and target options are compiled into the binary. Until
K3 exists, K2 includes the hash of `runtime/build_driver.c`, `runtime/prismio_llvm*`
and the pinned LLVM version; any edit there invalidates every K2. That is the
"never skip when uncertain" rule applied: coarse, but never wrong.

Negative fixtures stop at the front end, so they have only K1, and they always
run when the compiler changed. They cost ~20 ms each; there is nothing to save.

Harness tests have K1 only, built from what they declare they read (§4). Most
of them inspect IR or diagnostics, so they rerun on every compiler change.

## 4. Test metadata

Every test is discovered into one record: `id`, `kind`, `suite`, `tags`,
`inputs`, `resources`, `cache`, `timeout`.

**File fixtures** keep their names and markers. An optional header adds to the
defaults; most fixtures need none:

```
// test: suite=aif tags=ownership,views resources=threads cache=never
```

Defaults: `test_*` → suite `run`, `neg_*` → suite `diagnostics`; tags come
from the filename and from which directories the fixture imports from.

**Harness tests** move out of the 13,644-line `tests/test_runner.py` into
`tests/harness/<suite>.py`, one module per suite, each test declared:

```python
@harness_test(suite="ums", resources={"project_host": EXCLUSIVE, "cpu": 2},
              reads=["ums/**", "tools/toolchain_layout.psm", "build.ums"],
              timeout=300)
def ums_project(ctx): ...
```

`reads` is what goes into K1 beyond the compiler, and it is checked, not
trusted: in `--audit` mode the runner records every file a harness test opens
(`fs_usage` on macOS, `strace -f -e trace=openat` on Linux) and fails if one is
outside the declaration. A declaration that is too small is a cache that serves
stale passes, and this is how the project already treats instruments: assert
non-vacuity rather than assume it.

**Suites** (what kind of check, and so what it costs and needs):

| Suite | Members | Needs |
|---|---|---|
| `diagnostics` | `neg_*`, `cli_usage`, `source_not_utf8`, `identifier_security` | front end only |
| `run` | `test_*` | compile, link, exec |
| `codegen` | the IR-shape tests: `counted_fill_codegen`, `proved_index_nsw`, `struct_path_tbaa`, `byte_loop_vectorise`, … | IR, `llvm-*` tools |
| `aif` | `aif_*`, `ownership_probes`, `aif_differential` | IR + oracle |
| `pir` | `pir_plan`, `pir_differential` | |
| `std` | `std_*`, `prelude`, Unicode conformance | |
| `tooling` | `fmt`, `index`, `check_*`, `lsp*` | `prismio-lsp` |
| `ums` | `ums`, `ums_project`, `ums_after`, `module_artifacts`, `incremental_manifest` | **exclusive** `project_host`, `objcache` |
| `targets` | `target_cross`, `platform_target`, `jit`, `freestanding*`, `kmalloc_heap` | SDKs, `qemu` |
| `perf` | `workloads`, `workload`, benchmark smoke | quiet machine |
| `bootstrap` | gen0→gen2, fixpoint, seed check, `bootstrap_cache_key` | ~GBs, all cores |
| `safety` | `--verify` sweep, sanitizer smoke | Linux for ASan smoke |
| `corpus` | the runnable programs nothing executes today | |

## 5. Caching

Store: `.prismio/test-cache/results.sqlite`, local and untracked, one row per
(test id, key level, key) with outcome, duration, stdout and stderr hashes, the
compiler's `--version` line, and when. Durations feed the scheduler (§6) even
when the cache is off.

Rules:

1. Only passes are cached. A failure always reruns.
2. `cache=never` for anything whose result is not a function of its key:
   tests that time things (`workloads`, `perf`), use threads or tasks in a way
   that can race, read the network, or read machine state (`platform_target`).
   Default for harness tests is `never` until a test declares `reads`.
3. A cached pass is reported as cached, with the key level that matched and the
   run it came from. A summary line never hides how much actually ran.
4. `full`, `gate` and `release` run with the cache **write-only**: they record,
   they never skip. The release gate's statement is "this candidate ran every
   test", and a cache cannot make it.
5. Non-vacuity, checked by the engine's own tests: a canary fixture whose IR is
   changed by a test-only compiler flag must miss K2; an edited fixture must
   miss K1; a runtime edit must miss every K2. A key that cannot tell two inputs
   apart has proved nothing.
6. `prismio suite --no-cache` and `PRISMIO_TEST_CACHE=0` turn it off; `--cache-clear`
   empties it.

**stdout as a second oracle.** Each passing run records the hash of its stdout.
When a fixture passes with a different stdout than last time *under a different
K2*, it is reported as `changed output` (not a failure) with a diff against the
stored text. That catches the class fact 5 describes without writing 362 golden
files; a fixture can opt into a hard check with `// expect-output: file.out`.

## 6. Scheduling

One pool for everything (file fixtures and harness tests together), sized by
**resources**, not by a worker count:

- `cpu` tokens = core count; a fixture takes 1, `bootstrap` takes all, a
  harness test declares its own (most compile `src/`-sized programs: 2–4).
- `mem` budget in MB; `bootstrap` and `--verify` sweeps declare theirs so two of
  them never run at once on a 16 GB machine.
- exclusive locks: `project_host` (the ums fixtures move `.prismio/build` aside),
  `objcache` (cold-build tests assert what recompiles), `qemu`, `quiet`
  (`perf` runs alone, last).

Order inside a profile, in waves:

1. **Smoke wave**: the `smoke` set, plus every test that failed last time, plus
   every fixture whose own file changed. Failure here stops the run unless
   `--keep-going` (fail fast, which is what "fast before slow" is for).
2. **Bulk wave**: everything else, longest-expected-first from recorded
   durations (LPT), which is what minimises wall time once the pool is full. The
   component graph (§7) only reorders within this wave so likely-affected tests
   report early.
3. **Quiet wave**: `perf`, alone.

Each test runs in its own temporary directory (fixtures stop writing `.exe` beside
their source in `tests/`), with `TMPDIR` set inside it, so the one shared state
left is what a resource lock names. `PRISMIO_TEST_JOBS=1` keeps its meaning:
one test at a time, for when a failure might be interference.

Timeouts are per test (default 60 s fixtures, declared for harness tests); a
timeout is a failure that names the test, never a hung suite.

## 7. The component graph (ordering, and harness inputs)

Derived, not written by hand:

- `src/` module imports, from the same `--emit-deps` the fixtures use (§9 step 3),
  run on `src/main.psm`, give the compiler's own module graph; directories map to
  stages (`lexer`, `parse`, `sema`, `aif`, `pir`, `ir`, `driver`).
- Fixture → std modules from the depfile (§9 step 3).
- Harness test → files from its checked `reads`.

Used for: ordering the bulk wave; `prismio suite affected --explain`, which
prints for a diff which tests are expected to move and why; and the report's
"moved IR, grouped by changed component". Never for skipping.

## 8. Profiles

| Profile | Runs | Cache | When | Target |
|---|---|---|---|---|
| `smoke` | ~40 tests: one per suite and per pipeline stage, chosen by coverage of past failures | read/write | every edit, editor hook | ≤ 15 s |
| `dev` (default `prismio suite`) | every fixture and harness test, front end always, the rest behind K1/K2 | read/write | while working | ≤ 45 s for a refactor (nothing moved); ≤ 2 min cold |
| `full` | everything in `dev`, nothing skipped | write-only | before a commit that changes `src/`, `runtime/`, `std/` | ≤ 2 min |
| `verify` | `full` + source lists, externs, `aif_differential`, `pir_differential`, corpus | write-only | before merging a feature | — |
| `gate` | `verify` on a packaged candidate + bootstrap, fixpoint, seed, workloads, cross target, packaging (today's `release_gate.py`) | write-only | before every push (as now) | — |
| `release` | `gate` + `--verify` sweep, sanitizer smoke (Linux), benchmark smoke, doc examples in both `../website` apps, the CI matrix | write-only | release candidates, `RELEASE.md` | — |

`-k`, positional patterns, `--suite`, `--tag` and `--changed` filter any
profile, and a filtered run says that it was filtered on its last line, so a
green `-k` run is never mistaken for the suite.

## 9. Building it: steps, each landable alone

1. **Parallel harness tests.** Split `PROGRAMMATIC_TESTS` into
   `tests/harness/*.py` with `@harness_test` declarations; resource locks;
   one pool with the file fixtures; per-test temp dirs; split `ums` (182 s) and
   `lsp_features` (48 s) into their scenarios, each its own test. No cache.
   Expected: 429 s → about (21.9 + 406) / 8 ≈ 55 s of work per core, bounded
   below by the longest single test left after the split. Check: same pass list, with `PRISMIO_TEST_JOBS=1` and with 8.
2. **Results store and reporting.** Durations, outcomes, stdout hashes;
   `--report=json`, a JUnit file for CI, `changed output`, slowest-ten,
   flaky detection (a fail then pass within one run is reported as flaky and
   never retried silently).
3. **K1.** Needs the source closure: `prismio build --emit-deps=<file>` writes
   every source file and `.plib` the compiler read (a flag, no new syntax, so no
   seed refresh). Then K1 for fixtures and for harness tests with `reads`.
4. **K2.** Split fixture compile into front end (`-o f.ll`) and the rest; hash as
   in §3 with the coarse backend identity. The non-vacuity canaries of §5 land
   in the same commit.
5. **K3 and reproducible links.** `--emit-link-key`, and fixing the 49 bytes of
   fact 4 (deterministic temp object names, so ld64's UUID is stable). Worth
   doing for releases on its own.
6. **Profiles as the only entry.** `build.ums`'s `suite`/`verify`/`gate` call
   `tools/testkit` with a profile; `release_gate.py` and `gate.py` become profile
   definitions; CI runs `prismio suite release` steps.
7. **`--audit` for declared reads**, then turn on `cache=auto` for harness tests
   that pass it.

Steps 1 and 2 need no compiler change and deliver most of the wall-time win;
3–5 are what make `dev` faster than `full`.

## 10. Rejected or deferred

- **Skipping by source path.** §3. Kept only as ordering.
- **Coverage-guided selection** (instrument the compiler, map which functions
  each test executes). Sound only with complete coverage of a self-hosted
  binary, and the IR comparison already gives an exact answer more cheaply.
  Revisit if the front end stops being cheap.
- **A shared/remote cache.** Keys include the compiler's bytes, which differ per
  machine and link; nothing to share until step 5, and a CI cache must never
  satisfy a release anyway.
- **Automatic retries.** A retry hides the race it would have reported.
- **Turning off the macOS first-exec scan.** It is ~270 ms per new binary, but it is
  a system security setting; the cache removes most of the execs instead. Adding
  the terminal to System Settings → Privacy & Security → Developer Tools exempts
  its children, and is the maintainer's call to make on their own machine.

## 11. As built (2026-11-28)

All seven steps of §9 landed together. `tools/testkit/` is the engine, `tests/harness/` the
harness tests, `tests/test_runner.py`, `tools/run_suite.py`, `tools/gate.py` and
`tools/release_gate.py` are thin names for profiles of it, and the compiler has
`--emit-deps=<file>` and `--emit-link-key=<file>`.

### Measured

Same M-series host, 10 cores, 16 GB.

| Run | Wall | Notes |
|---|---|---|
| old runner, 2026-11-28 | 428.6 s | 836 tests passed |
| `full`, default jobs | **198.3 s** | 849/849, nothing skipped |
| `full`, `PRISMIO_TEST_JOBS=1` | 804.5 s | 849/849 |
| `dev`, empty cache | 183.0 s | 849/849 |
| `dev` again, nothing changed | **151.1 s** | 735 cached (K1), 114 executed |
| the same, fixtures only (`--suite run --suite diagnostics`) | **4.4 s** | 686 of 734 cached; the old runner's fixtures took 21.9 s |
| `dev` after a comment-only edit in `src/`, compiler rebuilt | 182 s | the rebuilt compiler was byte-identical, so K1 hit (732 cached): nothing to prove |
| `dev` after a diagnostic's wording changed in `src/sema/`, compiler rebuilt | 232.5 s | compile-only: K2 320/320 positive fixtures, 40.5 s of fixture time against 238 s with only K3 to go on; negatives and harness tests rerun |
| `smoke`, unchanged | 10.6 s | 37 tests, 22 cached |
| `prismio gate` | 343.7 s | green: 867/867 (849 tests, lint, packaging, 16 checks) |

**The targets of §8 are not met** (`dev` ≤ 45 s for a refactor, `full` ≤ 2 min), and fixtures are
no longer why. The harness tests are: the five `ums` host scenarios build the compiler between
once and four times each (about 75 s alone, 85 to 140 s under load), with `no_inference` (45 to
90 s) and `lsp_features_memory` (about 55 s) behind them, and all of them are `cache=never`. The
next step down is to give the `ums` scenarios one shared, prebuilt host.

Output equivalence: `prismio bootstrap` then `src/main.psm` from generation 1 and generation 2 is
byte-identical; the compiler before this change and after it emit identical IR for all 419
programs under `tests/` and `benchmarks/hosted/prismio/` that build (the same 365 are refused)
and for the new `src/main.psm`; `tools/aif_differential.py` agrees on all 19 sources. Both
website apps' example verifiers (368 and 52 snippets) and content audits pass.

### The test set

The 836 tests of the baseline are 727 fixtures (unchanged ids) and 109 harness tests. 107 of
those keep their id. Two were split, and two tests of the engine itself were added, so
`full` runs 849:

| Old id | Now |
|---|---|
| `ums` | `ums_manifest`, `ums_native_link`, `ums_host_bootstrap`, `ums_host_toolchain`, `ums_host_repair`, `ums_host_trust`, `ums_host_fallback` |
| `lsp_features` | `lsp_features_navigation`, `_editing`, `_completion`, `_requests`, `_memory`, `_library_source` |
| (new) | `engine_keys`, `engine_cache_rules` (the canaries of §5, rule 5) |

Apart from the split bodies, every moved function is the old one with outputs redirected from
`tests/` to the test's own directory, except `workload` (deletes only its own temporaries),
`workloads` (reads its list from the engine), `no_inference` (no progress meter) and `fmt`
(reports the checker's standard error).

### Where it differs from the design, and why

1. **The `ums` host scenarios run on a copy of the checkout, not on the project host.** The
   plan gave them the exclusive `project_host` lock. A copy has the same manifest and sources,
   so the routing under test is the same, and the scenarios can run side by side. Nothing in a
   suite run touches `.prismio/build` any more: "never `prismio build` during the suite" and
   "`prismio suite` cannot run the ums host-routing fixture" no longer hold. No test uses the
   `project_host` lock. Editing `src/`, `std/` or `runtime/` during a run is still unsafe.
2. **K2's backend identity is wider than §3's, and K2 can be off.** `runtime/**`,
   `src/driver/**`, `src/main.psm`, `src/ir/bridge.psm`, `src/common/native.psm`,
   `src/common/target.psm` and the pinned LLVM: the Prismio side decides what the backend is
   told, and K2 cannot see that in the IR. The identity is read from the checkout, so it only
   describes a compiler built from it: K2 is off, and the run says why, when the compiler is
   outside the checkout or older than any file of the identity. **What this still assumes**: no
   other `src/` module changes what happens after the IR is written. K3 assumes nothing of the
   kind, and for a fixture that K2 cannot vouch for it still skips the run.
3. **Having K3 did not remove the link.** The key is written by the build that links, so a K3
   hit skips only the execution, which is the 270 ms.
4. **The toolchain copy lives in a stable slot**, `.prismio/test-cache/toolchain-<n>/`, not in
   a temporary directory: emitted IR names standard-library files by path, so a fresh path
   every run would have made K2 and K3 miss forever.
5. **Reproducible links** needed two things: object names without the process id (held by a
   per-output lock under `/tmp/prismio-locks-<uid>/`; a second concurrent build of the same
   output falls back to the old names), and `ZERO_AR_DATE=1` for the linker, since ld64 writes
   each object's modification time into the debug map. On this machine a link without `-g` was
   already reproducible for one output name; the 49 bytes of §1's fact 4 were not reproduced,
   and the 33 that differ with `-g` were. Two *different output names* still differ (the ad-hoc
   signature names the file). Windows is unchanged (`link.exe /Brepro`).
6. **`--audit` is a Python-level record, not `fs_usage`**, which needs root. It hooks `open`,
   directory listing and process creation inside the test's process, adds imported modules,
   and compiles every checkout source named on a compiler command line with `--emit-deps`. A
   command whose reads it cannot see makes the test *opaque*, and an opaque test may not be
   cached. It found two real under-declarations while the declarations were being written. It
   cannot see what a built program or a tool of the checkout opens, which is why those tests
   are not cached.
7. **50 harness tests declare `reads` and are cached** (all pass `--audit`). The other 72 are
   `cache=never`: opaque to the audit, or timing, threads, tool presence or the machine.
8. **Flaky** means: passed on inputs it had failed on before, or mixed outcomes under
   `--repeat N`. Within one ordinary run a test executes once.
9. **`--changed` and `affected` select and explain by path.** Neither is a cache decision.
10. **CI** packages as before and then runs `verify --packaged`, and on Linux the sanitizer
    and benchmark smoke through `release -k`. This adds the extern check, the PIR differential
    and the benchmark corpus to CI.
11. **Defects the work exposed**, fixed: `workload` deleted every `.prismio-*` in `tests/`,
    other builds' temporaries among them; `tools/check_fmt.py` copied `tests/` and failed when a
    temporary vanished mid-copy; and K2 first hashed `lib/toolchain.stamp`, which records the
    compiler's own bytes, so it never matched across a rebuild (`engine_keys` now holds it).
12. **`verify` and `gate` carry one known failure by name.** The PIR differential, new to both,
    disagrees on `test_287_multi_statement_fill`, as the compiler before this change does
    (`docs/KNOWN_ISSUES.md`). `PIR_KNOWN` in `tools/testkit/checks.py` holds it; any other
    disagreement fails, and so does this one going away.
13. **The `corpus` check** is every recorded benchmark workload (73), run for its checksum.
14. **The canary of §5 rule 5 needs no test-only compiler flag.** `engine_keys` builds one
    program with and without `--overflow-checks` and keys both under one run specification.

### Not done, or not verified

- **Linux and Windows are untested.** Everything above ran on macOS arm64. The C of
  `--emit-link-key` and the object-name lock have Windows branches that no compiler has built,
  and `.github/workflows/ci.yml` has been parsed but not run.
- **The `release` profile has not run as a whole.** On this host `benchmark_smoke` and both
  documentation checks pass; the sanitizer smoke needs Linux and the CI matrix is started by
  hand.
- **`--audit` is not run by any profile.** Run it after changing a test that declares `reads`.
- **72 harness tests are uncached**, most of them only because the audit cannot see what a built
  program opens. Running such programs outside the checkout would let many declare `reads`.
- **Old references in comments**: sources and fixtures still say `tests/test_runner.py` where
  they mean a module of `tests/harness/`; the name still resolves, to the shim.
- Three tests that no list ever ran (`run_object_cache_test`, `run_runtime_library_test`, and
  the unused `_target_di_member_bit`) were moved with their neighbours and are still not
  registered.
