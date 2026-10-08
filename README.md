<p align="center">
  <img src="https://www.prismio.org/icons/prismio-banner.png" width="140" alt="Prismio"/>
</p>

---

<p align="center">
A compiled, statically typed language where the compiler decides how memory is managed.<br/>
No garbage collector, no <code>free</code>, no lifetime annotations.
</p>

<p align="center">
<a href="https://prismio.org">Website</a> ·
<a href="https://docs.prismio.org/">Documentation</a> ·
<a href="https://docs.prismio.org/releases">Release notes</a> ·
<a href="https://github.com/prismio-lang/prismio/issues">Known issues</a> ·
<a href="CONTRIBUTING.md">Contributing</a>
</p>

---

[//]: # (No edit are allowed above this line)

Prismio compiles to native code through LLVM. Its compiler is written in Prismio and
builds itself to a byte-identical fixpoint.

What sets it apart is the memory model. You write ordinary code, and for every
allocation site the compiler proves the cheapest management strategy that is safe
for it: the stack, a bulk-freed region, a single owner with a deterministic free, or
a reference count. It shows you each decision, and it can check them against a
real run.

> **Status: 0.1.0, the first release.** Read the
> [release notes](https://docs.prismio.org/releases/0.1.0). The language and standard
> library can still change in incompatible ways before 1.0.

## Install

macOS and Linux:

```bash
curl -fsSL https://prismio.org/install.sh | sh
```

Windows: download the archive for your machine from the
[latest release](https://github.com/prismio-lang/prismio/releases/latest), unpack it, and
put its `bin` directory on `PATH`. Archives are named `prismio-<version>-<os>-<arch>`
(`macos-arm64`, `linux-x64`, `linux-arm64`, `windows-x64`, `windows-arm64`) and come with a `.sha256`; they are not signed. CI builds and tests macOS arm64, Linux x64 and Windows x64; the two ARM64 archives are built and tested on virtual machines.

The compiler carries its own LLVM, but it links programs with the system's linker, so you
also need the platform's C tools: the Xcode Command Line Tools on macOS
(`xcode-select --install`), `cc` and the C library headers on Linux (`build-essential` on
Debian and Ubuntu), or Visual Studio Build Tools with the **Desktop development with
C++** workload on Windows. Then:

```console
$ prismio --version
prismio 0.1.0
llvm 23.1.1
compiler /home/you/.prismio/bin
stdlib /home/you/.prismio/stdlib
```

## A first look

```rust
import std.display
import std.io
import std.map
import std.string
import std.vec

enum Shape {
    Circle(Float)
    Rect(Float, Float)
}

fn area(s: Shape) -> Float {
    match (s) {
        Shape.Circle(r) => { return 3.14159 * r * r }
        Shape.Rect(w, h) => { return w * h }
    }
}

fn main() {
    let shapes = [Shape.Circle(1.0), Shape.Rect(2.0, 3.0), Shape.Circle(0.5)]

    let mut total = 0.0
    for s in shapes {
        total = total + area(s)
    }
    println("total area: ${total}")

    let mut counts = mapNew<String, Int>()
    for word in "a b a c b a".split(' ') {
        counts.set(word, counts.getOr(word, 0) + 1)
    }
    println("a appears ${counts.getOr("a", 0)} times")
}
```

```console
$ prismio run shapes.psm
Built shapes
total area: 9.9269875
a appears 3 times
```

The program allocates and frees memory, but no line of it says so. Ask the compiler what
it decided:

```console
$ prismio aif shapes.psm
Storage plan
  Stack                   9
  Arena                   2
  Scoped heap             0
  Unique heap             88
  Shared heap             0
  Cycle-managed heap      0
...
ID   location                 type            storage          reason
1    shapes.psm:20:19         [Shape]         stack            fixed-length array; lives in the frame
2    shapes.psm:20:25         Shape           stack            small value does not escape
```

Then run it with the inference checked against every allocation and release:

```console
$ prismio run shapes.psm --verify
...
aif-verify: 13 allocated, 13 released, 0 leaked, 0 violation(s)
```

## The memory model

Each allocation site is assigned the cheapest tier the compiler can prove safe:

| Tier | Strategy | Runtime cost |
|---|---|---|
| T0 | stack or register (a fixed-length array is T0 too) | none |
| T1 | region: bump-allocated, freed in bulk | a pointer bump |
| T2 | single owner, moved, freed deterministically | one allocation and one free |
| T3 | shared, non-atomic reference count | a count update when sharing survives analysis |
| T4 | atomic reference count, or cycle collection | the only real overhead, and rare |

The rule is that what the analysis cannot prove costs performance, never
correctness; a shape that breaks it is a bug, found by `--verify` and fixed as one.
`prismio aif --why=<ID>` explains any decision, `--manifest` prints a stable form for CI to diff,
and `--verify` builds a program whose run checks the inference held. The
specification and the design record are in [`docs/aif/`](docs/aif/README.md).

The model is still being tightened. Some shapes leak rather than release, and
each is listed with a reproducer in
[KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md#ownership-leaks) under "Ownership: leaks".

## Performance

On the maintained suite of 62 workloads, each written the same way in Prismio, C++
and Rust, Prismio's geometric-mean time is **0.85× of C++ (`clang++ -O3 -flto`) and
0.83× of Rust (`-C opt-level=3 -C lto=fat`)**; peak memory is level with C++ and about 5%
below Rust. Measured on 2026-10-06 on an Apple M5 (arm64, macOS), 5 runs each
([report](benchmarks/results/report.html), [raw data](benchmarks/results/results.json)).

Against C++ it is faster on 24 workloads, level on 33 (inside the suite's noise rule)
and slower on 5: `prime_sieve`, `vector_growth`, `flat_bitset`, `large_buffer_copy` and
`memcpy_mix`. Against Rust it is faster on 24, level on 32 and slower on 6:
`vector_growth`, `vector_dot`, `convolution`, `channel_pipeline`, `large_buffer_copy` and
`indirect_calls`. Fifteen more workloads are listed in the suite but
not implemented yet, and are not counted. These are one machine's numbers, not a
promise about yours: [docs/PERFORMANCE_PLAN.md](docs/PERFORMANCE_PLAN.md) lists where
Prismio is slower and why, and the suite, with the rules that keep its three versions
of each workload the same program, is in [`benchmarks/`](benchmarks/README.md).
`prismio bench` re-runs it.

## Language at a glance

- `let` and `let mut`; structs, enums with payloads, and `match` over them.
- Generics with trait bounds, `impl` blocks, traits with associated types,
  borrowed `dyn Trait`, and closures with `Fn(A) -> R` bounds.
- Optionals (`T?`, `none`, `??`, `unwrapOr`, `expect`) and `Result` with the usual
  combinators; `Vec<T>`, fixed-length `Array<T, N>`, `Map<K, V>`; `for ... in` over any
  type that implements `Iterator`.
- String interpolation (`"${value}"`); `panic`, `assert` and `exit`.
- Tasks (`spawn`, `join`) and typed channels.
- C interop through `extern fn`, with ownership stated at the boundary:
  `produce(free)`, `borrow` and `alias`.
- Projects described in a `build.ums` manifest; `prismio init`, `build`, `run` and `test`.

The standard library covers I/O and standard input, files and directories,
processes and the environment, time, math, strings, and collections.
[The runtime surface](https://developers.prismio.org/runtime/supported-surface) maps what a program can call.
[Documentation](https://docs.prismio.org/) is the language reference.

## Building from source

To work on the compiler, or to run a platform the release does not ship for, build it
yourself. Requirements: Python 3.9 or later, which is the one thing you install yourself, and a
C toolchain (Xcode Command Line Tools, `build-essential`, or Visual Studio's C++
tools). `tools/setup.py` checks the toolchain by compiling and linking a program with
it, says exactly what is missing, and can install it (`--install-system-deps`, which
asks first). LLVM is pinned and downloaded by the same script; nothing on the system
is used.

```bash
git clone https://github.com/prismio-lang/prismio.git
cd prismio
python3 tools/setup.py                                   # check this machine, then LLVM 23.1.1 into third_party/llvm
tools/bootstrap.sh --seed --out build/gen0               # first compiler, from the release seed (fetched)
tools/bootstrap.sh --compiler build/gen0 --out build/gen1
python3 tools/package.py --compiler build/gen1 --out build/dist
export PATH="$PWD/build/dist/bin:$PATH"
```

The seed is LLVM IR for an earlier compiler, and it is how a machine with no Prismio
builds its first one. It is not in the repository: it is the `prismio-seed-<version>.ll`
asset of a [release](https://github.com/prismio-lang/prismio/releases), pinned by
version and SHA-256 in `bootstrap/seed.json`. The first `--seed` bootstrap runs
`tools/fetch_seed.py`, which downloads it into `bootstrap/`, checks the hash and reuses
the file after that. On Windows the script is `tools/bootstrap.ps1 -Out build/gen0`, then
`-Compiler build/gen0 -Out build/gen1`.

Once a compiler exists, the checkout is itself a Prismio project: `prismio build --release`
builds the project's own compiler (run it first, and again after pulling changes to `src/`), `prismio build` the one under test, `prismio suite` and `prismio verify` test it, and `prismio gate` is the
check to run before a push ([CONTRIBUTING.md](CONTRIBUTING.md)).

With the compiler installed or built, start a project:

```bash
$ prismio init hello && cd hello
$ prismio run
Built /home/you/hello/.prismio/build/debug/hello
Hello, Prismio!
```

Or compile a single file with `prismio run file.psm` or `prismio build file.psm`.
`prismio --help` lists every command, including `check` for editors (JSON
diagnostics, [IDE_PROTOCOL.md](IDE_PROTOCOL.md)) and `-g` for DWARF debug info
([docs/DEBUGGING.md](docs/DEBUGGING.md)).

**Platforms.** CI builds and tests Linux (x64), Windows (x64) and macOS (arm64).
Development happens on macOS (arm64) and Linux, so Windows is the least exercised: a compiler
self-hosted there has no export table, and some Windows-only paths are verified by
CI alone. The compiler runs on macOS 14 or later, and the programs it builds on macOS 11
or later. The compiler links three LLVM backends, so `--target` accepts AArch64, X86 and
WebAssembly triples; WebAssembly IR can be emitted but has no runtime yet. See
[Platform](docs/KNOWN_ISSUES.md#platform) and
[targets](https://docs.prismio.org/compiler/targets).

## Repository layout

| Path | Contents |
|---|---|
| [`src/`](src/) | The compiler, in Prismio: lexer, parser, semantic analysis, allocation inference (`aif/`), IR generation |
| [`std/`](std/) | The standard library |
| [`runtime/`](runtime/) | The C runtime, and the LLVM C API backend the compiler calls through `src/ir/bridge.psm` |
| [`ums/`](ums/README.md) | UMS, the build manifest and its resolver |
| [`docs/aif/`](docs/aif/README.md) | The memory model's specification and design record |
| [`tests/`](tests/) | The compiler suite, `tests/test_runner.py` |
| [`benchmarks/`](benchmarks/README.md) | Prismio, C++ and Rust versions of each workload |
| [`bootstrap/`](bootstrap/) | The pin for the release seed (`seed.json`); the seed itself is fetched here |
| [`tools/`](tools/) | Bootstrap, packaging, release gate, lint, LLVM setup, and the AIF oracle (`aif_oracle/`) |
| [`docs/`](docs/) | Plans and design notes for contributors |

## Project documents

|                                                                    | |
|--------------------------------------------------------------------|---|
| [Release notes](https://docs.prismio.org/releases)                 | What changed, release by release |
| [KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)                            | What is open, with enough of each to act on |
| [RELEASE.md](RELEASE.md)                                           | How a release is cut, and what must be green first |
| [docs/](docs/)                                                     | Plans for the standard library, memory, performance, collections and channels |
| [Runtime surface](https://developers.prismio.org/runtime/supported-surface), [String representation](https://developers.prismio.org/compiler/string-representation) | The runtime surface, and how `String` is represented |
| [CODE_STYLE.md](CODE_STYLE.md), [C_CODE_STYLE.md](C_CODE_STYLE.md) | How the compiler and runtime are written |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for building, testing, and what a change
needs before review. Most compiler work is Prismio under `src/`; the runtime and
the LLVM backend are C under `runtime/`.

Report security issues privately, as [SECURITY.md](SECURITY.md) describes.

---

## License

Apache License 2.0. See [LICENSE](LICENSE).
