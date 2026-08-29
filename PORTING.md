# Building Prismio on macOS (and Linux)

Prismio is self-hosted: the compiler is written in Prismio. That means building it
on a new platform has a chicken-and-egg problem — you need a `prismio` binary to
compile `src/main.psm`, and macOS has none.

The way out is `bootstrap/prismio-seed.ll`: committed LLVM IR for the compiler,
generated on a machine that already had one. `llc` turns it into a native object
for whatever host it runs on, and from there the compiler builds itself.

## What you need

| Tool | Where it comes from | Notes |
|---|---|---|
| `clang` | Xcode Command Line Tools (`xcode-select --install`) | Also supplies the macOS SDK, `ar`, and `nm` |
| `llc` | `brew install llvm` | Apple's toolchain ships no `llc` |
| `python3` | Preinstalled | Only for the test runner |

Homebrew's LLVM is keg-only, so put it on `PATH` — **appended, not prepended**:

```sh
export PATH="$PATH:$(brew --prefix llvm)/bin"
```

The order matters. Prismio shells out to bare `clang` for compiling and linking,
and you want that to resolve to Apple's `/usr/bin/clang`, which knows where the
macOS SDK is. Homebrew's `clang` often does not without an explicit `-isysroot`.
Appending gives you Apple `clang` plus Homebrew `llc`, which is the combination
that works. Mixing LLVM versions across the two is fine — Mach-O is stable, and
the generated IR uses opaque pointers, supported since LLVM 15.

## Build it

```sh
git clone <repo> && cd prismio
chmod +x tools/*.sh

# gen0: from the committed seed IR — the only step that needs the seed.
tools/bootstrap.sh --seed --out build/gen0

# gen1 and gen2: each compiler builds the next from src/main.psm.
tools/bootstrap.sh --compiler build/gen0 --out build/gen1
tools/bootstrap.sh --compiler build/gen1 --out build/gen2
```

### Check you reached a fixed point

`gen1` and `gen2` were built by different binaries, so if they emit byte-identical
IR for the same source, the compiler is reproducing itself exactly and the port is
sound:

```sh
build/gen1 build src/main.psm -o /tmp/a.ll
build/gen2 build src/main.psm -o /tmp/b.ll
cmp /tmp/a.ll /tmp/b.ll && echo "fixed point reached"
```

### Test, package, verify

```sh
PRISMIO=build/gen2 python3 tests/test_runner.py     # expect 202/202, never fewer

tools/package.sh --compiler build/gen2 --out dist/Prismio
tools/verify_separation.sh --dist dist/Prismio      # expect 11/11
```

`package.sh` produces the installed layout the compiler discovers at runtime,
relative to its own location — no environment variables, no hardcoded prefixes:

```
dist/Prismio/bin/prismio
dist/Prismio/lib/runtime.a     linked into every compiled program
dist/Prismio/lib/backend.a     linked into the compiler only
dist/Prismio/lib/runtime.hash  content hash of the runtime sources
dist/Prismio/stdlib/
```

Install by putting `dist/Prismio/bin` on `PATH`. Keep `bin/` and `lib/` siblings;
that relationship is how `prismio` finds its libraries.

## Why this works: the IR is target-neutral

The seed carries **no** `target triple` and **no** `target datalayout` line, so
`llc` targets its own host. That is only safe because nothing in the generated IR
is target-dependent:

- every function signature uses `i1`, `i8`, `i32`, `ptr` or `void`;
- no struct is passed or returned by value — the five named struct types are only
  ever reached through pointers, so no platform ABI question ever arises;
- no `byval`, `sret` or `inreg` attributes;
- no target intrinsics and no attribute groups.

Omitting the datalayout rather than hardcoding one is deliberate. A hardcoded
layout string is version-sensitive — the arm64 macOS layout gained `-Fn32` in
LLVM 18 — and a stale one is not diagnosed, it just silently miscompiles. Letting
`llc` derive the layout from the target cannot drift.

Once `gen0` is running, it no longer needs the seed's neutrality: `ir_module_start`
in `runtime/llvm-api-backend.c` emits a triple only when the backend was itself compiled
on Windows, so a macOS-built compiler also emits triple-less IR and `llc` keeps
resolving to the host.

## Refreshing the seed

The seed only needs regenerating when a language or codegen change would stop the
current one from compiling the current sources. A stale seed is harmless as long
as the compiler it produces can still build the tree.

```sh
tools/refresh_seed.sh --compiler build/gen2
```

It refuses a compiler that is not deterministic, so a mid-migration state cannot
be frozen into the seed. The Windows equivalent is `tools\refresh_seed.ps1`; both
strip the target directives and write the same header, so either platform can be
the one that regenerates it.

## Cross-compiling from Windows

You cannot produce a macOS binary from Windows with this toolchain — linking Mach-O
needs the macOS SDK. What you *can* do is hand a Mac the seed and let it do the
rest, which is exactly what the flow above is.

## Troubleshooting

**`llc: command not found`** — Homebrew LLVM is not on `PATH`. See above.

**`ld: library not found for -lSystem`** — `clang` resolved to Homebrew's rather
than Apple's. Confirm with `command -v clang`; it should be `/usr/bin/clang`.
Append Homebrew's LLVM to `PATH` instead of prepending it.

**`'stdio.h' file not found`** — Command Line Tools are missing or stale. Run
`xcode-select --install`, then `xcode-select -p` to confirm a valid path.

**`tools/bootstrap.sh: bad interpreter`** — the scripts were checked out with CRLF
endings. `.gitattributes` pins `*.sh` and the seed to LF, so this should not
happen; if it does, re-checkout with `git config core.autocrlf input`.

**Tests pass but `prismio build` fails outside the repo** — you are running the
uninstalled `build/gen2` rather than a packaged toolchain. Only the packaged
layout has `lib/` beside `bin/`; without it the compiler falls back to searching
for `runtime/` sources on disk.
