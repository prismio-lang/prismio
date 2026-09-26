# v0.1.0 release checklist

v0.1.0 is published when every box here is ticked. Each line links to where the
work is described. This file only tracks state. How to cut the release is
[RELEASE.md](RELEASE.md), and what is known to be open *after* the release is
[KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md).

Tick a box in the commit that does the work, and say in the commit message what
the evidence is. Last reviewed 2026-09-25.

The planners behind it, each split into "for 0.1" and "later":

| Planner | Covers |
|---|---|
| [docs/STDLIB_SHIP_PLAN.md](docs/STDLIB_SHIP_PLAN.md) | what the standard library needs before shipping |
| [docs/MEMORY_PLAN.md](docs/MEMORY_PLAN.md) | ownership soundness for 0.1; the allocation architecture after it |
| [docs/CHANNELS_PLAN.md](docs/CHANNELS_PLAN.md) | `Channel<T>` and tasks |
| [docs/COLLECTIONS.md](docs/COLLECTIONS.md) | `Vec`, `Array`, `Slice`: design and status |
| [docs/PERFORMANCE_PLAN.md](docs/PERFORMANCE_PLAN.md) | compiler and runtime performance, and how to measure it |
| [docs/FEATURE_BACKLOG.md](docs/FEATURE_BACKLOG.md) | benchmark-driven features (JSON, priority queue) |
| [docs/ARCHITECTURE-DIRECTION.md](docs/ARCHITECTURE-DIRECTION.md) | the longer-range research direction |

## 1 · Standard library

- [x] Exit, panic, assert (STDLIB_SHIP_PLAN item 1)
- [x] Standard input (item 2)
- [x] Environment and process identity (item 3)
- [x] `std.time` (item 4)
- [x] `Option` / `Result` methods (item 5)
- [x] `Map` removal and methods (item 6). 0.1 ships without `m.keys()`:
      it leaks on every call (KNOWN_ISSUES), and `keyAt` reads keys in place.
- [x] Files (item 7), with the file line reader: `readLines`, `tryReadLines`
- [x] Building strings (item 8): `StringBuilder`

## 2 · No known memory corruption

A leak may ship if it is documented. A violation, meaning memory freed that is
not live or a read of a dead frame, may not. Details are in MEMORY_PLAN §1 and
CHANNELS_PLAN §1.

- [x] A recursive enum built from `let`-bound children double-freed. Fixed
      2026-09-25; `recursive_enum_bindings_probe`, `recursive_optional_probe`.
- [x] An unsized array stored through a type argument read a dead frame.
      Refused 2026-09-25; neg_198, neg_199.
- [x] `Channel<Int>` was accepted and lowered with a mismatched ABI. Refused
      2026-09-25; neg_197.
- [x] A task whose thread cannot start ran inline and could deadlock on a
      channel. A panic since 2026-09-25.
- [x] Three ownership shapes that freed memory that was not live, fixed
      2026-09-25 (`aif/evidence/RESULTS-ownership-shapes.md`).

## 3 · Loose ends

- [x] `PRISMIO_INLINE_ELEMS=0` leaked in four tests. Deleted 2026-09-25
      (PERFORMANCE_PLAN §1).
- [ ] KNOWN_ISSUES re-read on the release candidate: every entry still true,
      and every fixed one moved out. (Done once on 2026-09-25; repeat on the RC.)
- [x] `CHANGELOG.md`: "Unreleased" folded into "0.1.0 -- not yet published"
      (2026-09-25). At the tag, replace "not yet published" with the date.
- [ ] `RELEASE.md`'s numbers (suite count, gate results, checksums) re-filled
      from the release candidate's own gate run.
- [ ] Decide what to do with the old `v1.0.0` tag (RELEASE.md §5). Deleting a
      published tag breaks other people's checkouts, so it is the owner's call.

## 4 · Documentation site (`../website`)

- [ ] `apps/docs` documents what landed on 2026-09-25: `std.input`,
      `std.time`, the `std.fs` additions, `Option`/`Result` methods, `Map`
      methods and `m[k]`, closure bounds `F: Fn(A) -> R`, `panic`/`assert`/
      `exit`, `process.env`/`setEnv`/`pid`, `std.math`, `readLines`/
      `tryReadLines`, `StringBuilder`; and the refusals a user can now meet:
      `Channel<Int>`, an array as a type argument. A task that cannot start
      is a panic.
- [ ] `stdlib/io.md` no longer says standard input is unavailable. It points to
      `std.input`.
- [ ] `verify-doc-examples.mjs` passes in `apps/docs` and in `apps/developers`,
      against a packaged toolchain built from the release candidate (CLAUDE.md
      has the command).
- [ ] The release-notes page matches `CHANGELOG.md`.

## 5 · The gate ([RELEASE.md](RELEASE.md) §0 to §4)

- [ ] Every item above is merged to `main`, and the release candidate is
      `main`'s head.
- [ ] The committed seed builds the release candidate (`tools/refresh_seed.sh`
      if it does not).
- [ ] `python tools/release_gate.py --rc <rc>` is green on that exact commit:
      fixpoint, the RC reproduces, seed, suite, differential, corpus,
      `--verify` sweep, JIT, cross target, packaging.
      *Green locally on the branch head, 2026-09-25: 435/435, fixpoint, seed,
      differential, corpus, `--verify` sweep, packaging
      (`aif/evidence/RESULTS-v01-gate-2026-09-25.md`). Repeat on `main`.*
- [ ] The benchmark matrix on the release candidate is recorded in
      `aif/evidence/` and compared with `RESULTS-benchmarks-2026-09-25.md`
      (PERFORMANCE_PLAN §1).
      *Recorded for the branch head in the same file: 0.92x of C++ and of Rust.*
- [ ] CI is green on Windows, Linux and macOS, on the exact commit to be tagged.
      The three local failures of 2026-09-25 are settled: `test_181` was a test
      bug (fixed), and `target_cross`/`module_artifacts` pass once the pinned
      LLVM is first on `PATH`, which CI already does (ci.yml, "Put the
      provisioned LLVM on PATH").
- [ ] `tools/release.py` artifacts and SHA-256 files built on each platform
      from its own gate-green build.
- [ ] A clean-environment smoke test of each artifact, outside the checkout.

## 6 · Publish (needs the owner's explicit go-ahead)

- [ ] Tag `v0.1.0` on the gate-green commit and push the tag.
- [ ] Create the GitHub release with the three archives and their checksums,
      and `CHANGELOG.md`'s 0.1.0 section as the notes.
- [ ] Publish the documentation site from the commit whose examples passed.
