# Session prompt — compiler work, in order

**This file is the one live prompt.** `NEXT-SESSION.md` is the archive of past ones; when this
session is done, fold a summary of it into that file and rewrite this one for the session after.

Everything below is **compiler work only**. The motivation behind it is a cross-platform app
framework built in Prismio, but no task here is framework work — the framework's runtime,
embedders, host imports and packaging are deliberately outside the compiler, and two of the tasks
below exist specifically to move things back across that line.

The rule that decides which side anything falls on:

> **If getting it wrong produces a miscompile, it belongs to the compiler.**
> **If getting it wrong produces a link error or a missing feature, it does not.**

Pointer width wrong is a miscompile — compiler's. `print` missing on a target is a link error —
not the compiler's.

**Last-good: `build/S10d`.** Suite 132/132, fixpoint `S10c == S10d`, cold seed chain clean, only
`src/main.ll` moved in the IR snapshot.

---

## How to work this

**One task at a time, in order. Do not start task N+1 until task N is green.** Several change IR
for every program, and a failure two tasks later is unattributable if three landed together.

If a task turns out to be wrong, stop and say so rather than pushing through. Some of the ordering
below is a judgement call made from outside the code.

### The standing gate

Written once here; every task is "done" only when all of it is green.

```bash
# snapshot BEFORE you start, with the last-good compiler
python3 tools/ir_snapshot.py --compiler build/<last-good> --out /tmp/base

bash tools/bootstrap.sh --compiler build/<last-good> --out build/N1
bash tools/bootstrap.sh --compiler build/N1 --out build/N2
# N1 and N2 must emit byte-identical IR for src/main.psm

cd tests && PRISMIO=../build/N2 python3 test_runner.py     # 132/132 or more
python3 tools/aif_differential.py --compiler build/N2      # 17 sources agree
python3 tools/ir_snapshot.py --compiler build/N2 --out /tmp/after && diff -rq /tmp/base /tmp/after
bash tools/bootstrap.sh --seed --out build/Ns0
bash tools/bootstrap.sh --compiler build/Ns0 --out build/Ns1
# Ns1's src/main.ll must match N2's
```

For a behaviour-preserving task, the snapshot must be identical except `src/main.ll`. For a task
that deliberately changes output (2, 4), **the diff is the deliverable** — read it and record what
moved and why.

After any change to `runtime/*.c`: `python3 runtime/generate_embedded_sources.py` **and**
`python3 tools/check_source_lists.py`.

---

## Phase 1 — layering (hard prerequisite for everything after)

### Task 1. Remove the wasm runtime and the broken wasm flag

`runtime/lang_runtime.c` lines 21–539 are `#ifdef PRISMIO_WASM`: a bump allocator over
`__heap_base`, a hand-written `memcpy`, `free` as a no-op, and four host imports from the `env`
module. About a fifth of the file. **Nothing in this repo defines `PRISMIO_WASM`** — zero
occurrences in `build_driver.c` and in both bootstrap scripts. It is dead code *and* it is on the
wrong side of the line above: which host functions exist, and what module they come from, is an
embedder decision.

Delete `--target wasm32` with it. It does not merely not work, it builds **nothing**:
`Isize`/`Usize` lower to `i32` there while `std/io.psm` declares `I64`, and `std/io.psm` is a
prelude merged into every module, so even `fn main() -> Int { let a = 2  return a }` fails
`LLVMVerifyModule`. And `build_driver.c` never passes `--target` to clang (zero occurrences), so
even with the verifier satisfied it would emit wasm-triple IR and compile it for the host. A flag
that silently produces a host binary is worse than no flag. Task 3 reintroduces targets properly.

**The trap — this is the one place a single wrong step breaks a fresh checkout.**
`ir_module_start_wasm` is FFI surface, and **the committed seed's IR calls it twice**:

```bash
grep -c ir_module_start_wasm bootstrap/prismio-seed.ll   # -> 2
```

Remove the C function in one step and the seed cannot link. CI's first step is the only thing that
catches it; a warm local build never touches the seed. So this is CODE_STYLE's two-step rule
mirrored for *removing* FFI:

1. Stop calling it from `src/` — drop the `--target` branch in `main.psm`, the `irTargetWasm`
   global in `src/ir/context.psm`, and `ir_module_start_wasm` from `src/ir/module.psm` and
   `src/ir/bridge.psm`. Build two generations, run the full gate, **then**
   `bash tools/refresh_seed.sh --compiler build/<gen2>`.
2. *Only then* delete `ir_module_start_wasm` and the `PRISMIO_WASM` block from the C, regenerate
   the embedded sources, and run the gate again **including the cold seed build**.

Do not merge those steps.

**Done when** the gate is green after both, and no output moved except `src/main.ll`.

**Leave a note at `irPtrIntType()`**, which becomes an unconditional `i64` here and gets a real
answer back in Task 3 — otherwise someone deletes it as dead.

### Task 2. `std.io` stops being a prelude

`src/main.psm:392` loads `std.io` into **every** program. That is why a program containing no I/O
still fails on a target with no stdout, and it is why every binary carries `println` and an integer
formatter it may never have named.

Make it an ordinary `import std.io`. `src/main.psm` has 39 uses of `print`/`println` and will need
the import; so will most of `tests/`.

**This changes IR for every program that does not use I/O**, so the snapshot diff is the
deliverable, not a failure. Expect most fixtures to shrink; read two or three and confirm what
vanished is only unused `std/io` bodies.

**Traps.** Most `tests/*.psm` print their PASS line, so this is a mechanical edit across ~89 files
— script it. Check the negative fixtures separately: a `neg_*.psm` that now fails with "unknown
function println" instead of the diagnostic it was written to assert is a silently broken test.
`test_runner.py` asserts *which* diagnostic each expects, so it should catch that — confirm it
does rather than assuming.

**Decision to make and record:** whether `std.io` stays implicit for `prismio run` and becomes
explicit only for `build`. Recommendation is no — one rule, always explicit — but say which was
chosen and why.

---

## Phase 2 — targets

This is the phase that unblocks everything downstream. It moved ahead of `-g` because the
debug-tooling tasks block nothing, and this blocks every non-host platform.

### Task 3. A target record, replacing the boolean

`src/ir/context.psm` has `let mut irTargetWasm = false`. A boolean does not become web + Android +
macOS + Windows + Linux. Replace it with a record: **triple, pointer width, datalayout**.

Five of six targets are the same shape — 64-bit, libc, clang drives the linker. Only web differs.

| target | triple | ptr |
|---|---|---|
| macOS | `arm64-apple-macos` / `x86_64-apple-macos` | 64 |
| Android | `aarch64-linux-android` | 64 |
| Windows | `x86_64-pc-windows-msvc` | 64 |
| Linux | `x86_64-unknown-linux-gnu` | 64 |
| Web | `wasm32-unknown-unknown` | **32** |

**Build the table from the target you actually run, not from the table above.** Pick one non-host
target — web is the one that matters here — and make it work end to end before generalising. A
target list written from a table is a target list nobody has run.

The host hardcoding you are replacing is small: one `#ifdef _WIN32` in `llvm-api-backend.c` setting
a triple, plus the `-g` path's `LLVMGetDefaultTargetTriple()`.

### Task 4. `--target` and `--sysroot` reach clang; the runtime becomes per-target

`build_driver.c` names no target today. Pass the record's triple to both `compile_ir_to_object` and
the link step, plus a sysroot for SDK-based targets.

Then `find_toolchain_library(..., "runtime")` becomes `runtime-<triple>`. **This is the seam** —
the point is that a framework ships `runtime-wasm32.a` and friends, defines the host-import ABI for
each, and the compiler links whatever it is pointed at.

**Two things that will bite:**

- **`pin_data_layout()` must read the target record, not the host.** It asks
  `LLVMGetDefaultTargetTriple()` today. Once cross-compilation is real, a cross-compiled `-g` build
  would get the *host's* member offsets — which is precisely the bug the DWARF session was built to
  prevent. Read the "Debug information (DWARF)" section header in `llvm-api-backend.c` first.
- **The object cache keys on the compile flags.** The triple must be in the key or two targets will
  share one object, which is a silent and genuinely nasty failure.

Also fix, on the way: `Isize`/`Usize` are `i32` on wasm32 while `std/io.psm` declares `I64`. Either
`std/io` takes `Isize`/`Usize`, or the call site widens. Pick one and say why.

**Done when** one non-host target builds and runs end to end.

**Note for whoever reaches Windows:** `-g` emits DWARF. An MSVC-targeted build wants CodeView/PDB,
and nothing here emits it.

---

## Phase 3 — finish `-g`

Four independent holes found in the 2026-08-20 session. All small, none blocks anything, all worth
doing before the feature rots. Read `docs/DEBUGGING.md` and HANDOFF's 2026-08-20 entry §2 and §6
first — especially the data-layout note, which is not visible from the code.

The rule the whole DWARF layer is built on, and which every task here must keep: **a location that
is wrong is worse than no location.** Every entry point has an "I cannot answer that" path and
takes it. Extend `run_debug_info_test` for each of these, and **break it once** to confirm the new
assertion actually fires — that is the house standard and it caught real mistakes last time.

### Task 5. `DIGlobalVariable` for module-level globals

Verified missing: a program with `let mut counter = 0` at the top level emits `@counter` and
**zero** `DIGlobalVariable`. A debugger cannot name it.

`LLVMDIBuilderCreateGlobalVariableExpression`, called from `generateModule`'s global loop (the
`ir_global_var` site in `src/ir/module.psm`), which already has the name, type key and span.
Backend half goes beside `ir_debug_local`; `LLVMGetNamedGlobal(g_module, name)` gives you the
value. A global whose type key does not map gets **no** entry rather than a guess.

### Task 6. `-g` for `prismio bootstrap`

The flag is parsed on `build`/`run` only, so the one program in this repo that would most repay
stepping through cannot be. `src/main.psm:1230` passes `false` today.

Then decide and record: whether `build_from_toolchain_sources` should pass `-g` to the runtime's C
objects too, so a stack trace crosses the FFI boundary with source lines on both sides instead of
stopping at `str_concat`. Probably yes; it costs a slower bootstrap, and the object cache keys on
compile flags so `-g` and non-`-g` objects will not collide.

**This task is only done when someone has actually stepped through the compiler under lldb** and
written down what they saw. A 155 KB self-hosted program is a far harder test of the line table
than any fixture.

### Task 7. Enums as `DW_TAG_enumeration_type`

`p kind` prints `12` instead of `STRUCT_DECL`. On this codebase — `NodeKind`, `TypeKind`,
`TokenType` everywhere — that is worth more than it sounds.

`ir_register_enum_variant` already holds the map in `ir_symbols.c`; it needs a count/at accessor
pair like the one `ir_get_struct_field_name_at` got, then `LLVMDIBuilderCreateEnumerator` +
`LLVMDIBuilderCreateEnumerationType`, and `di_type_for` returning it when the key is `i32` and the
name is a registered enum.

**Trap:** use `ir_named_type_kind` to tell struct from enum. Guessing from the name is wrong —
`TokenType` is an enum and does not look like one.

### Task 8. A closing-brace span on BLOCK

`parseBlock` knows the `}` token and throws it away, so every scope drop, arena pop and region exit
inherits the **previous statement's** line.

**Be clear what this does not fix.** It does *not* affect variable liveness — LLVM derives a
`DW_TAG_lexical_block`'s `low_pc`/`high_pc` from the instructions in the scope, not from the
DILexicalBlock's line, and the dumps confirm scoping is already correct. This is line attribution
only, which is why it is last.

Stamp the closing token's line/col onto the BLOCK node. Check whether `i1`/`i2` are free on a BLOCK
before reusing them.

---

## Phase 4 — optional

### Task 9. `prismio run --jit`

**Confirmed feasible with no new dependency:** `llvm-c/LLJIT.h`, `Orc.h` and `OrcEE.h` are in the
LLVM-C this compiler already links.

`run` pays a full clang compile plus link every time. You already have the `LLVMModuleRef` — hand
it to `LLVMOrcCreateLLJIT`, resolve runtime symbols, look up `main`, call it.

**Demoted to optional**, and the reason should be recorded rather than rediscovered: the original
argument for JIT was debug-mode execution for an app framework. iOS is out of scope, and web needs
no JIT at all — measured, a whole-program rebuild of an app the size of this compiler is **83 ms
frontend + 116 ms LLVM at `-O0` ≈ 200 ms**, which is fast enough to reload without any incremental
compilation. So this is a desktop developer convenience, not infrastructure.

Keep it behind `--jit` and off by default, so codegen is untouched and this adds an execution path
rather than an emission path.

**Traps:** register runtime symbols explicitly with the JIT rather than relying on the host
process's dynamic symbols — the latter works on one platform and not the next. And
`prismio_argc`/`prismio_argv` are globals that generated code fills from `main`'s parameters, so a
JIT `main` must set them the same way.

---

## Deliberately not in this list

- **Hot reload / live patching.** Not a compiler feature at the level that matters: swapping
  behaviour at a component boundary through a registry is a framework design, and needs no compiler
  support. True function-level patching would need incremental compilation plus indirection at
  every swappable call site — a cost paid in release too — and the measurement above says it is not
  needed.
- **Incremental / separate compilation.** Same measurement. 200 ms whole-program at `-O0` for a
  compiler-sized app. Revisit only when something real is measured to be too slow.
- **PDB / CodeView.** Note it when Task 4 reaches Windows.
- **`--verify` that instruments reads.** Today it catches a double free and a leak; a
  use-after-free is only made *loud*, by poisoning released memory with `0xDD`. SPEC 7.3's table
  and the header over the shims in `runtime/lang_runtime.c` say what each remaining row needs.
- **`List<T>` / `T?` / arrays as real DWARF types.** Opaque pointers under `-g` today. Each needs a
  layout this layer does not have.

## Suspected stale, worth re-checking before planning around it

`HANDOFF.md`'s "Known gaps" says compile time is superlinear, ~290 ms for the 155 KB compiler. The
frontend measured **83 ms** on 2026-08-20. That note probably predates the 2026-08-17 compile-time
session. Re-measure before anyone budgets work against it.

## Read before starting

- `CODE_STYLE.md` — especially the two-step rule. Task 1 is its mirror image for removing FFI.
- `HANDOFF.md`'s 2026-08-20 entry, §2 (the data-layout pin) and §6 (where `-g`'s fidelity stops).
- `docs/DEBUGGING.md` — what `-g` deliberately does not say, and why.
