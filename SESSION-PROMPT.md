# Session prompt — compiler work, in order

**This file is the one live prompt.** `NEXT-SESSION.md` is the archive of past ones; when this
session is done, fold a summary of it into that file and rewrite this one for the session after.

Everything below is **compiler work only**. The motivation behind it is a cross-platform app
framework built in Prismio, but no task here is framework work — the framework's runtime,
embedders, host imports and packaging are deliberately outside the compiler.

The rule that decides which side anything falls on:

> **If getting it wrong produces a miscompile, it belongs to the compiler.**
> **If getting it wrong produces a link error or a missing feature, it does not.**

**Last-good: `build/N2`.** Suite 134/134, fixpoint `N1 == N2`, cold seed chain `Ns1 == N2`, IR
snapshot unchanged except `src/main.ll`.

**The packaged-runtime seam now has a test.** `run_runtime_library_test` packages a toolchain into
a temporary directory and asserts what gets linked, not that a build works. Read HANDOFF's
2026-08-23 entry before touching that layer — in particular the reason a build succeeding proves
nothing there, and the note that the archive's triple is the one **as typed**, not LLVM's
normalisation of it.

---

## How to work this

**One task at a time, in order. Do not start task N+1 until task N is green.**

If a task turns out to be wrong, stop and say so rather than pushing through.

### The standing gate

Written once here; every task is "done" only when all of it is green.

```bash
# snapshot BEFORE you start, with the last-good compiler
python3 tools/ir_snapshot.py --compiler build/<last-good> --out /tmp/base

bash tools/bootstrap.sh --compiler build/<last-good> --out build/N1
bash tools/bootstrap.sh --compiler build/N1 --out build/N2
# N1 and N2 must emit byte-identical IR for src/main.psm

cd tests && PRISMIO=../build/N2 python3 test_runner.py     # 134/134 or more
python3 tools/aif_differential.py --compiler build/N2      # 17 sources agree
python3 tools/ir_snapshot.py --compiler build/N2 --out /tmp/after && diff -rq /tmp/base /tmp/after
bash tools/bootstrap.sh --seed --out build/Ns0
bash tools/bootstrap.sh --compiler build/Ns0 --out build/Ns1
# Ns1's src/main.ll must match N2's
```

The snapshot must be identical except `src/main.ll`, plus any fixture a task deliberately extends.
Four sessions running have held to that, so a diff anywhere else is a real finding.

After any change to `runtime/*.c`: `python3 runtime/generate_embedded_sources.py` **and**
`python3 tools/check_source_lists.py`.

**Adding an FFI function is one step; removing one is two.** The committed seed's IR calls the C it
was built against, so deleting a C function that `bootstrap/prismio-seed.ll` still names breaks a
fresh checkout, and only CI's first step catches it. Stop calling it from `src/`, refresh the seed,
*then* delete the C. Adding is safe in one step — the seed never calls what it does not know.

**A new string literal in `src/` renumbers the whole string table.** It shows up as a several
hundred line `src/main.ll` diff that is entirely `@.str.sNNNN` shifting by one. Read the first few
hunks before assuming a change was bigger than it was.

**`build/` accumulates.** Keep the last-good and delete the rest; nothing in it is an input to
anything.

---

## Candidates, in the order they look worth doing

Nothing here is assigned. Each is a real finding with the evidence attached; pick by what the work
actually needs — the last session picked A over the standing optional task and that was right.

### A. `tools/verify_separation.sh` passes and nothing runs it

Now that its probe compiles again, the script is a working 11-check proof that no backend symbol
reaches a user binary — and neither CI nor the suite calls it. It went 2 days broken without
anyone noticing, and it will go broken again for the same reason.

Two shapes: call it from CI's packaging step, or fold its two checks that the suite cannot already
make (archive symbol tables, and the byte-signature scan of a linked binary) into
`run_runtime_library_test`, which already packages a toolchain. The second costs no new CI wiring
and puts the assertion where the packaging is already happening. **This is small and it is the
cheapest thing on this list.**

### B. Finish wasm32 past IR

All 78 fixtures produce verifying wasm32 IR and nothing links: no `wasm-ld` on the box, and no
runtime — deliberately, since host imports are an embedder's decision. Needs
`runtime-wasm32-unknown-unknown.a` from whoever owns the embedder, plus `brew install lld`. The
compiler side is done, and `run_runtime_library_test` now proves the archive would be found and
linked once it exists — under exactly that name.

### C. `aif/layout.psm` hardcodes 4 bytes for an enum and 8 for a Float

Correct on every target so far and not pointer-width, so they were left alone — but they are the
same *class* of thing as the `Isize` bug, which was a table that disagreed with the target.

### D. Assignment statements are stamped with the token after `=`

Right line, wrong column, so a diagnostic underlines one token to the right. Found next to the
expression-statement bug fixed on 2026-08-22 and left alone because nothing observed is wrong.
`parserNodeFrom` already exists; this is the same two-line shape.

### E. `-Woverride-module` on every macOS build

clang normalises `x86_64-apple-macos` to `x86_64-apple-macosx26.0.0` and warns that the module
disagrees. It warns on host builds with no triple at all, so this predates cross-compilation.
Fixing it means either stamping the normalised triple (which still will not match, because clang
folds the SDK version in from the sysroot) or suppressing a warning that occasionally tells the
truth. Neither is obviously right.

**One new thing is now known about it:** the archive lookup keys on the triple *as typed*, so
"just stamp the normalised triple" would also change which `runtime-<triple>.a` a cross build looks
for. The two are coupled; whoever takes E has to decide both.

### F. `prismio run --jit`

**Optional, and it has been optional for four sessions.** Do it if nothing above matters more.

**Confirmed feasible with no new dependency:** `llvm-c/LLJIT.h`, `Orc.h` and `OrcEE.h` are in the
LLVM-C this compiler already links.

`run` pays a full clang compile plus link every time. You already have the `LLVMModuleRef` — hand
it to `LLVMOrcCreateLLJIT`, resolve runtime symbols, look up `main`, call it.

**The reason it is optional should be recorded rather than rediscovered:** the original argument for
JIT was debug-mode execution for an app framework. iOS is out of scope, and web needs no JIT — a
whole-program rebuild of an app the size of this compiler is **83 ms frontend + 116 ms LLVM at
`-O0` ≈ 200 ms**, fast enough to reload without incremental compilation. Desktop developer
convenience, not infrastructure.

Keep it behind `--jit` and off by default, so codegen is untouched and this adds an execution path
rather than an emission path.

**Traps:** register runtime symbols explicitly with the JIT rather than relying on the host
process's dynamic symbols. `prismio_argc`/`prismio_argv` are globals that generated code fills from
`main`'s parameters, so a JIT `main` must set them the same way. And `--jit` with `--target` is a
contradiction — refuse it rather than silently running host code.

---

## Deliberately not in this list

- **Hot reload / live patching.** Not a compiler feature at the level that matters: swapping
  behaviour at a component boundary through a registry is a framework design and needs no compiler
  support. True function-level patching would need incremental compilation plus indirection at
  every swappable call site — a cost paid in release too — and the measurement above says it is not
  needed.
- **Incremental / separate compilation.** Same measurement. 200 ms whole-program at `-O0` for a
  compiler-sized app. Revisit only when something real is measured to be too slow.
- **PDB / CodeView.** `-g` emits DWARF. An MSVC-targeted build wants CodeView and nothing here
  emits it. `--target x86_64-pc-windows-msvc` works as far as the IR, so this is reachable in a way
  it was not before.
- **`--verify` that instruments reads.** Today it catches a double free and a leak; a
  use-after-free is only made *loud*, by poisoning released memory with `0xDD`. SPEC 7.3's table
  and the header over the shims in `runtime/lang_runtime.c` say what each remaining row needs.
- **`List<T>` / `T?` / arrays as real DWARF types.** Opaque pointers under `-g` today. Each needs a
  layout this layer does not have.
- **A bare enum variant's type.** `Colour.RED` is an `Int` to sema, so `let c = Colour.RED` is
  described as an `Int`. Making it a `Colour` is a semantic change — assignability, comparisons,
  `as`, match patterns — and is not a debug-info task. See HANDOFF 2026-08-22 §3.

## Suspected stale, worth re-checking before planning around it

`HANDOFF.md`'s "Known gaps" says compile time is superlinear, ~290 ms for the 155 KB compiler. The
frontend measured **83 ms** on 2026-08-20. That note probably predates the 2026-08-17 compile-time
session. Re-measure before anyone budgets work against it. **Still unchecked after two sessions
carried this paragraph forward** — either measure it or delete it.

## Read before starting

- `CODE_STYLE.md` — especially the two-step rule.
- HANDOFF's 2026-08-23 entry — the packaged runtime seam, and why a successful build proves
  nothing about it.
- HANDOFF's 2026-08-22 entry — `-g`'s last four holes, and the two assertions that passed while
  broken.
- HANDOFF's 2026-08-21 entry — targets, and why `std.io` stopped being a prelude.
- `docs/DEBUGGING.md` — what `-g` says, and what it deliberately does not.
