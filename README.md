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
<a href="https://prismio.org/changelog">Changelog</a> ·
<a href="https://github.com/prismio-lang/prismio/issues">Known issues</a> ·
<a href="CONTRIBUTING.md">Contributing</a>
</p>

---

Prismio compiles to native code through LLVM. Its compiler is written in Prismio and
builds itself to a byte-identical fixpoint.

What sets it apart is the memory model. You write ordinary code, and for every
allocation site the compiler proves the cheapest management strategy that is safe
for it: the stack, a bulk-freed region, a single owner with a deterministic free, or
a reference count. It shows you each decision, and it can check them against a
real run.

> **Status: pre-release.** 0.1.0 is being prepared ([release checklist](RELEASE_CHECKLIST.md)).
> The language and standard library can still change in incompatible ways before 1.0.
> Build it from source today; installers come with the 0.1.0 release.

## A first look

```prismio
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

fn main() -> Int {
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
    return 0
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
  Stack                   3
  Arena                   2
  Scoped heap             1
  Unique heap             119
  Shared heap             0
  Cycle-managed heap      0
...
ID   location                 type            storage          reason
1    shapes.psm:21:19         [Shape]         scoped heap      scope-bound; no arena selected
2    shapes.psm:21:25         Shape           stack            small value does not escape
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
| T0 | stack or register | none |
| T1 | region: bump-allocated, freed in bulk | a pointer bump |
| T2 | single owner, moved, freed deterministically | one allocation and one free |
| T3 | shared, non-atomic reference count | a count update when sharing survives analysis |
| T4 | atomic reference count, or cycle collection | the only real overhead, and rare |

The rule is that what the analysis cannot prove costs performance, never
correctness; a shape that breaks it is a bug, found by `--verify` and fixed as one.
`prismio aif --why=<ID>` explains any decision, `--manifest` prints a stable form for CI to diff,
and `--verify` builds a program whose run checks the inference held. The
specification and the evidence behind it are in [`aif/`](aif/README.md).

The model is still being tightened. Some shapes leak rather than release, and
each is listed with a reproducer in [KNOWN_ISSUES.md](KNOWN_ISSUES.md) under
"Ownership".

## Performance

On the maintained suite of 63 workloads, each written the same way in Prismio, C++
and Rust, Prismio's geometric-mean time is **0.92× of C++ (clang -O2) and 0.92× of
Rust (-C opt-level=3)**, with peak memory level with both. That was measured
2026-09-25 on x86_64 Linux, 7 runs each
([results](aif/evidence/RESULTS-v01-gate-2026-09-25.md)). It is slower on some
workloads, `edit_distance` and `base64_codec` among them, and
[docs/PERFORMANCE_PLAN.md](docs/PERFORMANCE_PLAN.md) lists where and why. The suite,
and the rules that keep its three versions of each workload the same program, are
in [`benchmarks/`](benchmarks/README.md).

## Language at a glance

- `let` and `let mut`; structs, enums with payloads, and `match` over them.
- Generics with trait bounds, `impl` blocks, traits with associated types,
  borrowed `dyn Trait`, and closures with `Fn(A) -> R` bounds.
- `Option` and `Result` with the usual combinators; `Vec<T>`, fixed-length
  `Array<T, N>`, `Map<K, V>`; `for ... in` over any type that implements `Iterator`.
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

Requirements: a C toolchain (Xcode Command Line Tools, `build-essential`, or Visual
Studio's C++ tools) and Python 3.8 or later. LLVM is pinned and downloaded by the
setup script; nothing on the system is used.

```bash
git clone https://github.com/prismio-lang/prismio.git
cd prismio
python3 tools/setup_llvm.py                              # LLVM 23.1.1 into third_party/llvm
tools/bootstrap.sh --seed --out build/gen0               # first compiler, from the committed seed
tools/bootstrap.sh --compiler build/gen0 --out build/gen1
python3 tools/package.py --compiler build/gen1 --out build/dist
export PATH="$PWD/build/dist/bin:$PATH"
```

`bootstrap/prismio-seed.ll` is committed LLVM IR for an earlier compiler. It is how
a machine with no Prismio builds its first one. On Windows the script is
`tools/bootstrap.ps1 -Seed bootstrap/prismio-seed.ll -Out build/gen0`, then
`-Compiler build/gen0 -Out build/gen1`.

Then start a project:

```console
$ prismio init hello && cd hello
$ prismio run
Hello, Prismio!
```

Or compile a single file with `prismio run file.psm` or `prismio build file.psm`.
`prismio --help` lists every command, including `check` for editors (JSON
diagnostics, [IDE_PROTOCOL.md](IDE_PROTOCOL.md)) and `-g` for DWARF debug info
([docs/DEBUGGING.md](docs/DEBUGGING.md)).

**Platforms.** CI builds and tests on Linux, macOS and Windows. Development happens
on macOS (arm64) and Linux (x86_64), so Windows is the least exercised: a compiler
self-hosted there has no export table, and some Windows-only paths are verified by
CI alone. WebAssembly IR can be emitted but has no runtime yet. See
[Platform](KNOWN_ISSUES.md#platform).

## Repository layout

| Path | Contents |
|---|---|
| [`src/`](src/) | The compiler, in Prismio: lexer, parser, semantic analysis, allocation inference (`aif/`), IR generation |
| [`std/`](std/) | The standard library |
| [`runtime/`](runtime/) | The C runtime, and the LLVM C API backend the compiler calls through `src/ir/bridge.psm` |
| [`ums/`](ums/README.md) | UMS, the build manifest and its resolver |
| [`aif/`](aif/README.md) | The memory model: specification, reference oracle and measured evidence |
| [`tests/`](tests/) | The compiler suite, `tests/test_runner.py` |
| [`benchmarks/`](benchmarks/README.md) | Prismio, C++ and Rust versions of each workload |
| [`bootstrap/`](bootstrap/) | The committed seed |
| [`tools/`](tools/) | Bootstrap, packaging, release gate, lint, LLVM setup |
| [`docs/`](docs/) | Plans and design notes for contributors |

## Project documents

|                                                                    | |
|--------------------------------------------------------------------|---|
| [CHANGELOG.md](CHANGELOG.md)                                       | What changed, release by release |
| [KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)                            | What is open, with enough of each to act on |
| [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)                       | What is left before 0.1.0 |
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
