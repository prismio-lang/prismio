# Session prompt — compiler work, with no list

**This file is the one live prompt.** `NEXT-SESSION.md` is the archive of past ones; when this
session is done, fold a summary of it into that file and rewrite this one for the session after.

Everything below is **compiler work only**. The motivation behind it is a cross-platform app
framework built in Prismio, but no task here is framework work — the framework's runtime,
embedders, host imports and packaging are deliberately outside the compiler.

The rule that decides which side anything falls on:

> **If getting it wrong produces a miscompile, it belongs to the compiler.**
> **If getting it wrong produces a link error or a missing feature, it does not.**

**Last-good: `build/E2`.** Suite 136/136, fixpoint `E1b == E2`, cold seed chain `Es1 == E2`, IR
snapshot clean.

---

## Read this before looking for something to do

**The candidate list is empty.** Four sessions ran off a list of findings; on 2026-08-24 the last
five were taken in order and all five landed. That is a different situation from the last four
sessions and should be treated as one: **the first job here is deciding what the compiler is for
next, not picking the top item.**

Nothing below is a queue. The two sections are (1) what is genuinely blocked and on whom, and
(2) what was considered and deliberately declined, with the reasoning, so it is not rediscovered.

If you find yourself with nothing to do, the honest answers in rough order of value are:

1. **Ask what the framework needs next.** Every remaining gap in this compiler is a language gap —
   methods, closures, slices, an error-handling story past `Option`/`Result` — and which one
   matters is a question about what is being built, not about the compiler.
2. **Take a real program and compile it.** Every defect found in the last two sessions came from
   *running* something nobody had run — a packaging script, an installer probe, a spec-required
   check — not from reading code. `tools/` is now clean; the next unexercised surface is whatever a
   framework does that `tests/` does not.
3. **Pick from "deliberately not in this list" and re-argue it.** Those entries are decisions, not
   facts, and two of them (PDB/CodeView, `--verify` instrumenting reads) would change if the target
   audience changed.

---

## How to work this

**One task at a time. Do not start task N+1 until task N is green.**

If a task turns out to be wrong, stop and say so rather than pushing through.

### The standing gate

Written once here; every task is "done" only when all of it is green.

```bash
# snapshot BEFORE you start, with the last-good compiler
python3 tools/ir_snapshot.py --compiler build/<last-good> --out /tmp/base

bash tools/bootstrap.sh --compiler build/<last-good> --out build/N1
bash tools/bootstrap.sh --compiler build/N1 --out build/N2
# N1 and N2 must emit byte-identical IR for src/main.psm

cd tests && PRISMIO=../build/N2 python3 test_runner.py     # 136/136 or more
python3 tools/aif_differential.py --compiler build/N2      # 17 sources agree
python3 tools/ir_snapshot.py --compiler build/N2 --out /tmp/after && diff -rq /tmp/base /tmp/after
bash tools/bootstrap.sh --seed --out build/Ns0
bash tools/bootstrap.sh --compiler build/Ns0 --out build/Ns1
# Ns1's src/main.ll must match N2's
```

The snapshot must be identical except `src/main.ll`, plus any fixture a task deliberately extends.
Five sessions running have held to that, so a diff anywhere else is a real finding.

After any change to `runtime/*.c`: `python3 runtime/generate_embedded_sources.py` **and**
`python3 tools/check_source_lists.py`.

**Adding an FFI function is one step; removing one is two.** The committed seed's IR calls the C it
was built against, so deleting a C function that `bootstrap/prismio-seed.ll` still names breaks a
fresh checkout, and only CI's first step catches it. Stop calling it from `src/`, refresh the seed,
*then* delete the C. Adding is safe in one step — the seed never calls what it does not know.

**A new string literal in `src/` renumbers the whole string table.** It shows up as a several
hundred line `src/main.ll` diff that is entirely `@.str.sNNNN` shifting by one. Read the first few
hunks before assuming a change was bigger than it was.

**Break every new assertion before believing it.** Five sessions of house standard, and it has
caught a test that passed against a broken compiler at least twice. The cheap form is a mutated
copy of the file under test in the scratchpad; the honest form is a mutated *compiler*, which costs
one bootstrap and is what the 2026-08-24 session used for all five of its tasks.

**`build/` accumulates.** Keep the last-good and delete the rest; nothing in it is an input to
anything.

---

## Blocked, and on whom

### wasm32 past IR

All 78 fixtures produce verifying wasm32 IR, `run_runtime_library_test` proves the compiler would
find and link `runtime-wasm32-unknown-unknown.a` under exactly that name, and nothing links.

Two things are missing and **neither can be produced from this repo**:

- **`wasm-ld`** (`brew install lld`), which is a host setup step rather than compiler work.
- **`runtime-wasm32-unknown-unknown.a`**, which cannot be built here at all:
  `wasm32-unknown-unknown` has **no C library**, so the runtime sources stop at
  `#include <stdio.h>`. What `print` resolves to on the web is an embedder's decision. Measured
  rather than assumed, and the compiler now says so in the diagnostic, naming the archive it
  looked for and where it looked.

**The compiler side is finished.** Do not reopen this as a compiler task; it is a request to
whoever owns the embedder.

---

## Deliberately not in this list

- **Hot reload / live patching.** Not a compiler feature at the level that matters: swapping
  behaviour at a component boundary through a registry is a framework design and needs no compiler
  support. True function-level patching would need incremental compilation plus indirection at
  every swappable call site — a cost paid in release too.
- **Incremental / separate compilation.** A whole-program rebuild of an app the size of this
  compiler is **83 ms frontend + 116 ms LLVM at `-O0` ≈ 200 ms**, and `run --jit` now takes the
  clang compile and the link out of the loop entirely — 10–20 ms against 220–530 ms for a small
  program. Revisit only when something real is measured to be too slow.
- **PDB / CodeView.** `-g` emits DWARF. An MSVC-targeted build wants CodeView and nothing here
  emits it. `--target x86_64-pc-windows-msvc` works as far as the IR, so this is reachable — it is
  declined for want of an audience, not for difficulty.
- **`--verify` that instruments reads.** Today it catches a double free and a leak; a
  use-after-free is only made *loud*, by poisoning released memory with `0xDD`. SPEC 7.3's table
  and the header over the shims in `runtime/lang_runtime.c` say what each remaining row needs.
- **`List<T>` / `T?` / arrays as real DWARF types.** Opaque pointers under `-g` today. Each needs a
  layout this layer does not have.
- **A bare enum variant's type.** `Colour.RED` is an `Int` to sema, so `let c = Colour.RED` is
  described as an `Int`. Making it a `Colour` is a semantic change — assignability, comparisons,
  `as`, match patterns — and is not a debug-info task. See HANDOFF 2026-08-22 §3.
- **`-Woverride-module`.** Settled 2026-08-24 and not worth reopening. clang's driver always
  compiles for the SDK's deployment target while a module carries at most LLVM's default triple,
  and clang warns identically against a module with **no triple at all** — so nothing written on
  the module could ever have silenced it. Suppressed, and the check it could in principle have made
  is now an assertion in `run_target_test` that our data layout equals clang's.
- **`aifTypeBytes`'s remaining literals.** `Float` is 8 and an enum is 4 because `Float` lowers to
  `double` and an enum falls through to `i32`, on every target LLVM emits for. Routing them through
  the target would advertise a variation that does not exist. The comment above them says so.

## Read before starting

- `CODE_STYLE.md` — especially the two-step rule.
- HANDOFF's 2026-08-24 entry — all five candidates, and the pattern in how the prompt was wrong
  about three of them: **the real defect was one or two lines from where it pointed.**
- HANDOFF's 2026-08-23 entry — the packaged runtime seam, and why a successful build proves
  nothing about it.
- HANDOFF's 2026-08-22 entry — `-g`'s last four holes, and the two assertions that passed while
  broken.
- `docs/DEBUGGING.md` — what `-g` says, and what it deliberately does not.
