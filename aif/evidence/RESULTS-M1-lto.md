# M1.0 — why `-flto` declines the inline

## Default decision update — 2026-08-25

The working tree now enables the curated runtime merge by default and retains
`PRISMIO_INLINE_RUNTIME=0` as the opt-out. This is not based only on the older PATH test: the suite
now compiles and runs a container program, requires the trace marker emitted only after the
in-process curated merge succeeds, then rebuilds with `=0` and requires that marker to be absent.
The ordinary suite is the repository's Windows/Linux/macOS matrix, so a platform where the
fail-open optimization silently declines can no longer look green.

Local gates with `build/inline-default-2`: fixed point, fresh-seed agreement, AIF differential
17/17, suite **150/150**. The 25-run default-off/default-on comparison is corpus median **0.948×**,
range 0.635×–1.000×, RSS 0.993×–1.008×, equal checksums, and unchanged executable sizes. The
refreshed standing is **1.10×–3.11× idiomatic Rust**. Raw evidence:

- `aif/evidence/xlang/results-inline-runtime-default.json`
- `aif/evidence/xlang/results-current-inline-runtime.json`
- `aif/evidence/xlang/results-current-inline-runtime-pass2.json`

The TODO parent remains unchecked until this new test is observed green on the remote
three-platform matrix; these working-tree changes have not been pushed.

---

The one cheap experiment TODO.md M1.0 asks for, run before anything else in M1 on the grounds that
it might reduce the whole milestone to a flag. It does not, and the reason it does not is the
useful part.

Host: macOS 25.5.0, arm64, Homebrew clang/LLVM **22.1.8**, ld64. Compiler `build/S10b`.
No compiler source was changed for any measurement here.

---

## 0 · The answer

`-flto` does not decline the inline on cost. It refuses it outright:

```
LTO remark: 'list_get' not inlined into 'main' because it should never be inlined
            (cost=never): conflicting attributes
```

`conflicting attributes` is LLVM's `areInlineCompatible`. The cause is visible in the IR: the
backend emits program functions carrying **no function attributes at all** —

```
$ grep -c '^attributes #' g2t.ll
0
$ grep '^define' g2t.ll | head -1
define void @__aif_release_Renderable(ptr %0) {
```

— while the C runtime, compiled by clang, carries `"target-cpu"="apple-m1"` and a 33-entry
`"target-features"` string on every function. Caller and callee therefore disagree about the
subtarget, and the inliner returns `never` before it ever prices the call.

**Stamping the runtime's exact attribute string onto the program's functions removes every
container call, and `-flto` then does the whole job:**

| g2_tuned, 9 interleaved runs | loop ms | vs shipped | `bl _list_get` | exe bytes |
|---|---:|---:|---:|---:|
| `-O2`, as shipped | 25.00 | 1.00× | 7 | 61,624 |
| `-flto`, program bitcode only | 25.00 | 1.00× | 4 | 36,536 |
| `-flto` on program *and* runtime | 25.00 | 1.00× | 4 | 35,912 |
| `llvm-link` IR merge (§9.2's method) | 13.32 | **1.88×** | 0 | 61,656 |
| **`-flto` + target attributes stamped** | **13.34** | **1.87×** | **0** | **35,672** |

Checksums identical across all five. This reproduces RESULTS-final §9.2's 24.7 → 13.2 ms to
within noise, and the LTO route matches the merge on speed while producing a binary **42% smaller**
than either the shipped build or the merge, because LTO strips dead code the merge keeps.

## 1 · Why the `llvm-link` merge escaped this and LTO did not

Both routes hold the same mismatched IR. The merge is then handed to `clang -O2`, whose
TargetMachine supplies its own CPU and feature defaults to the attribute-less functions, so both
sides of every call site land on the same subtarget and the check passes. The LTO pipeline inside
the linker has no such driver to fill the blanks in. The merge was never doing something LTO
cannot do — it was accidentally repairing the input first.

## 2 · The part that decides how M1.1 is built: the match must be exact

The obvious implementation is to ask LLVM for the host CPU at IR-generation time. **That produces
the wrong string on this host**, and produces it silently:

```
LLVMGetHostCPUName()     -> "apple-m4"
LLVMGetHostCPUFeatures() -> ""            (unimplemented for AArch64)
```

clang stamps `apple-m1`. Every near-miss was tried against g2_tuned, and every one of them leaves
all four `bl _list_get` in place:

| stamped on the program's functions | inlined? |
|---|---|
| `target-cpu=apple-m1` alone | no |
| `target-cpu=apple-m4` alone (a *newer* chip) | no |
| `target-cpu=generic` alone | no |
| full `target-features`, no `target-cpu` | no |
| full `target-features` **minus** `+sha3,+jsconv` | no |
| full `target-features` **plus** `+v8.5a,+bf16,+i8mm` | no |
| `target-cpu=apple-m4` + the full feature list | no |
| **`target-cpu=apple-m1` + the full feature list** — clang's exact string | **yes** |

The last two rows differ in one token. It is not a subset test that a generous feature list can
satisfy from above; a superset fails, a newer CPU fails, and the feature list without the CPU
fails. **Nothing short of the string clang actually used works.**

So M1.1 must not guess. It must pin: choose a CPU, pass `-mcpu=<X>` to the runtime's compile, and
stamp the attribute string clang emits for that same `-mcpu` on the program's functions. Read back
from a one-line probe TU rather than reconstructed. Verified end to end for three choices of `<X>`:

```
-mcpu=generic    bl _list_get=0   14.16 ms (1.77x)
-mcpu=apple-m1   bl _list_get=0   13.34 ms (1.87x)
-mcpu=apple-m4   bl _list_get=0
```

`generic` works but gives up some of the win, so the CPU choice is a real decision, not a
formality.

## 3 · It generalises across the corpus

Each program built two ways by hand — both `clang -O2`, so the ratio is controlled — and run
7 times interleaved. Baseline is the shipped pipeline; the other is `-flto` with attributes
stamped and the runtime compiled to bitcode.

| prog | shipped ms | stamped + LTO ms | worth | exe base | exe LTO | checksums |
|---|---:|---:|---:|---:|---:|---|
| g1 | 23.50 | 21.00 | 1.12× | 61,784 | 35,656 | same |
| g2 | 102.50 | 94.16 | 1.09× | 61,496 | 35,672 | same |
| g3 | 48.75 | 45.42 | 1.07× | 61,864 | 35,720 | same |
| g4 | 68.33 | 51.66 | 1.32× | 61,784 | 35,656 | same |
| g5 | 76.33 | 38.17 | **2.00×** | 62,424 | 35,736 | same |
| g6 | 198.75 | 170.01 | 1.17× | 62,600 | 35,752 | same |
| g2_tuned | 25.00 | 13.34 | **1.87×** | 61,624 | 35,672 | same |

Consistent with RESULTS-final §9.3 (g1 1.17×, g3 1.07×, g4 1.28×, g5 1.82×) and extends it to g6
and untuned g2, which §9.3 did not cover. Executable size falls ~42% on every program, which is
the opposite direction from the tradeoff §5.2 accepts.

## 4 · What this does and does not settle

Settled:

- The seam is not a codegen problem and not an LTO capability problem. It is one missing pair of
  attributes at `materialize_function()` (`runtime/llvm-api-backend.c:660`), the single site where
  every program function is created.
- The runtime must reach the linker as **bitcode**. With a native runtime archive, `-flto` on the
  program alone leaves the calls in place no matter what is stamped — the row above proves it.
- The fix is worth 1.07×–2.00× and *reduces* binary size.

Not settled, and M1.1/M1.2 own them:

- **Portability.** `compile_ir_to_object`'s comment already declines `-flto` as default because it
  "needs linker plugin support that is not portable enough". Everything above is ld64 on one host.
  lld and gold are untested here, and portability is the whole reason the flag was rejected before.
- **Cross-compilation.** `--target` exists. A stamped host CPU on a cross build is a correctness
  hazard, not just a lost optimisation. The pinning must be per-target or absent.
- **`-g`.** Untested. `-g` drops the program object to `-O0`; the interaction with an LTO link is
  not measured here, and TODO.md M1.2 already flags it as the risk.
- **The object cache and `--verify`.** Untested with bitcode objects.
- **Compile time.** Not measured. The cold path already regressed 19–28%; LTO moves work to link.
- **RSS.** Not measured.
- **Why exactly `apple-m4` fails against `apple-m1`.** A superset CPU refusing is unintuitive and
  the mechanism was not chased past the remark. It does not block M1.1 — pinning sidesteps it —
  but it is the one loose thread.

## 5 · Reproducing

```bash
W=$(mktemp -d); cd $W
P=/path/to/prismio; R=$P/runtime
$P/build/S10b build $P/aif/evidence/xlang/prismio/g2_tuned.psm -o g2t.ll

# the shipped pipeline
clang -Wno-override-module -O2 -c g2t.ll -o prog.o
clang -O2 -Wno-deprecated-declarations -I $R -c $R/lang_runtime.c    -o lr.o
clang -O2 -Wno-deprecated-declarations -I $R -c $R/program_support.c -o ps.o
clang prog.o lr.o ps.o -o shipped

# the remark that answers the question
clang -O2 -Wno-override-module -flto -c g2t.ll -o lprog.o
clang -O2 -Wno-deprecated-declarations -I $R -flto -c $R/lang_runtime.c    -o llr.o
clang -O2 -Wno-deprecated-declarations -I $R -flto -c $R/program_support.c -o lps.o
clang -flto -O2 -Wl,-mllvm,-pass-remarks-missed=inline lprog.o llr.o lps.o -o lto 2>&1 \
  | grep list_get

# pin both sides, then it inlines
printf 'void probe(void){}\n' > probe.c
clang -O2 -mcpu=apple-m1 -S -emit-llvm probe.c -o probe.ll
ATTR=$(grep -o '"target-cpu"="[^"]*" "target-features"="[^"]*"' probe.ll | head -1)
python3 - "$ATTR" <<'PY'
import re, sys, pathlib
src = pathlib.Path("g2t.ll").read_text()
out, n = re.subn(r'^(define [^\n]*?\)) \{$', r'\1 #99 {', src, flags=re.M)
pathlib.Path("g2t_attr.ll").write_text(out + f'\nattributes #99 = {{ {sys.argv[1]} }}\n')
PY
clang -O2 -mcpu=apple-m1 -Wno-deprecated-declarations -I $R -flto -c $R/lang_runtime.c    -o plr.o
clang -O2 -mcpu=apple-m1 -Wno-deprecated-declarations -I $R -flto -c $R/program_support.c -o pps.o
clang -Wno-override-module -O2 -flto -c g2t_attr.ll -o pprog.o
clang -flto -O2 pprog.o plr.o pps.o -o pinned

objdump -d shipped | grep -c 'bl.*_list_get'   # 7
objdump -d lto     | grep -c 'bl.*_list_get'   # 4
objdump -d pinned  | grep -c 'bl.*_list_get'   # 0
```

Timing is the median `frame_ns` line times the frame count; the corpus table interleaves the
variants run-by-run rather than timing one to completion and then the other.

## 7 · Which route M1.1 should take — measured, and it is not the one §2 implies

§2 establishes what `-flto` needs to work. It does not establish that `-flto` is the right route.
Four routes were built and measured against the same program, same host, same clang.

| route | run ms | speed | compile ms | cc | exe bytes | checksums |
|---|---:|---:|---:|---:|---:|---|
| shipped: `-O2 -c` + native link | 25.00 | 1.00× | 77 | 1.00× | 61,624 | same |
| **curated: `llvm-link` 8 fns + `-O2 -c` + link** | **12.50** | **2.00×** | **91** | **1.18×** | 61,624 | same |
| full merge: whole runtime (§9.2's method) | 13.32 | 1.88× | 145 | 1.88× | 61,656 | same |
| LTO: `-flto` + stamped attributes | 13.34 | 1.87× | 94 | 1.21× | **35,672** | same |

Compile time is program-side steps only, with the runtime's objects/bitcode already cached — the
cost a warm incremental build actually pays.

**The curated module wins on every axis but binary size**, and TODO.md's gate makes exe size
"reported, never a gate". It is also the only route that needs *neither* `-flto` *nor* the
attribute stamping §2 describes:

- No `-flto`, so the linker-plugin portability question that declined the flag in
  `compile_ir_to_object`'s comment never arises. The link stays an ordinary native link.
- No attribute stamping, because `clang -O2` on the merged module fills its own CPU and feature
  defaults into the attribute-less program functions — the same accident §1 describes, except here
  it is load-bearing by design rather than by luck, and it is self-consistent under `--target`
  because one clang invocation supplies both halves.

The full merge is what §9.2 measured and it is the worst of the three: it pays **1.88×** compile
time to move the *entire* runtime through `-O2` for every program, for less speed than curating 8
functions.

### 7.1 · The mechanism

`llvm-extract` the hot ops out of the runtime's IR, then rewrite their linkage to
**`available_externally`** — the body is available to the inliner but emits no code, so calls that
do not get inlined still resolve to the runtime archive's copy and nothing is defined twice. This
is Swift's `@inlinable` spelled at IR level, which is what the original M1.1 asked for.

```
list_get  list_set  list_len  list_push
list_set_elem_owner  list_set_elem_releaser  rc_retain  rc_release
```

Corpus, 7 interleaved runs each, curated route against the shipped pipeline:

| prog | shipped ms | curated ms | worth | vs LTO route |
|---|---:|---:|---:|---:|
| g1 | 24.25 | 22.00 | 1.10× | 1.12× |
| g2 | 103.34 | 93.34 | 1.11× | 1.09× |
| g3 | 49.58 | 47.50 | 1.04× | 1.07× |
| g4 | 67.08 | 50.00 | 1.34× | 1.32× |
| g5 | 76.34 | 36.34 | **2.10×** | 2.00× |
| g6 | 204.99 | 163.74 | 1.25× | 1.17× |
| g2_tuned | 25.00 | 12.50 | **2.00×** | 1.87× |

All checksums identical. Curated matches or beats the LTO route on five of seven programs.

### 7.2 · Implementation notes

- The merge can run **in-process**: `llvm-c/Linker.h` (`LLVMLinkModules2`) is in the pinned LLVM,
  and `llvm-api-backend.c:2667` already parses IR in-process with `LLVMParseIRInContext` for the
  JIT path. So no new binary dependency — importantly *not* a dependency on the `llvm-link` and
  `llvm-extract` executables, which the measurements above used for convenience.
- `prismio_llvm.h` would need `LLVMLinkModules2` added for the non-`PRISMIO_LLVM_REAL_HEADERS`
  path, per that file's own rule about keeping the two paths interchangeable.
- The curated module is program-independent, so it is built once and cached on the same key shape
  the object cache already uses (runtime source content + flags).
- `available_externally` is what keeps the native runtime archive linkable unchanged, so the
  installed-runtime path (`link_against_runtime_library`) does not have to be restructured.

### 7.3 · What this corrects

An earlier revision of TODO.md's M1.1 — written from §2 alone, before the routes were measured —
redirected M1.1 from "curated bitcode module" to "stamp the target attributes". That was wrong.
§2 explains why `-flto` fails; it does not make `-flto` the right answer. The curated module the
original M1.1 specified is faster, cheaper to compile, and avoids both of M1.2's named risks.

## 8 · M1.1 built, and measured through the real driver

Everything above is hand-built binaries. This section is the compiler doing it:
`compile_ir_to_object` merges the curated module before `-O2`, behind
`PRISMIO_INLINE_RUNTIME=1`. Compiler `build/S12b`, `milestone_bench.py --runs 25`, both arms the
same binary so only the variable differs.

```
corpus median new/old: 0.864x   range 0.481-0.982x
GATE PASSED (corpus median within 3.0%, fewer than 2 programs past 10.0%)
```

| prog | old ms | new ms | new/old | RSS | vs idiomatic Rust |
|---|---:|---:|---:|---:|---|
| g1 | 22.8 | 22.4 | 0.982x (flat) | 1.000x | 1.25x -> 1.22x |
| g2 | 107.1 | 95.5 | **0.892x** | 1.000x | 5.91x -> 5.27x |
| g3 | 50.8 | 47.7 | 0.940x | 1.000x | 1.12x -> **1.05x** |
| g4 | 67.4 | 52.0 | **0.772x** | 0.994x | 3.09x -> 2.38x |
| g5 | 77.2 | 37.1 | **0.481x** | 0.968x | 2.69x -> **1.29x** |
| g6 | 226.4 | 189.4 | **0.837x** | 0.992x | 4.14x -> 3.47x |

Checksums agree across all five variants on every program. **RSS does not regress anywhere** and
improves slightly on three -- worth stating plainly because §5.3 records that axis reversing once
with nobody watching. Executable size is unchanged at 60-61 KB, because the merged bodies are
`available_externally` and emit no code.

g5 is the result: **2.08x faster**, and it moves from 2.69x of idiomatic Rust to **1.29x**.

### 8.1 · M1's exit gate is **not** met, and the reason matters

TODO.md's M1 exit gate is the standard gate *plus* "`--only g3` must show < 1.00x of idiomatic
Rust". Measured: **1.05x**. Close, and the wrong side of the line.

The prediction came from §9.3 of RESULTS-final, which had g3 at 1.01x of idiomatic Rust before the
change and 0.94x after. The driver-built measurement disagrees about the *starting point*:
`milestone_bench` puts g3 at 1.12x before, not 1.01x. The *worth* of the change agrees well
(1.064x here against §9.3's 1.07x) -- what did not reproduce is the baseline ratio it was applied
to.

So the headline in TODO.md and RESULTS-final §9.3 -- "the first Prismio program to beat idiomatic
Rust" -- **is not currently supported by a driver-built measurement**, and §9.3's table is
hand-built with `clang -O2` invoked directly. This is exactly why the exit gate says §9's table
"must be re-measured rather than cited". It has now been re-measured, and it moved.

M1.1 passes the standard gate and is a real 13.6% corpus-median win. M1 as a milestone is not done.

**Re-measured after the §10 port, g3 reads 1.05x again** (1.11x -> 1.05x, against the first pass's
1.12x -> 1.05x). Two independent passes agreeing puts the shortfall outside this host's noise: it
is a result, not a bad draw.

### 8.2 · What landed

- `runtime/build_driver.c`: `PRISMIO_CURATED_OPS`, `build_curated_module`,
  `merge_curated_into_program`, and the merge wired into `compile_ir_to_object`. Cached in the
  object-cache directory on the runtime source content plus the compile flags, so it is built once
  per toolchain per target.
- **Declined under `-g`.** The object step is `-O0` there, so the merge would produce identical
  code at the cost of two extra tool invocations -- and it would put runtime bodies into the module
  a debugger walks. M1.2 named that risk; this is the answer to it.
- `tests/test_runner.py`: `run_curated_closure_test`, which reads `PRISMIO_CURATED_OPS` out of
  build_driver.c rather than duplicating it and asserts every curated body references only exported
  symbols. Verified to fail on the real hazard: adding `list_push` back produces
  `'list_push' references non-exported symbol(s): arena_alloc_slot, arena_depth, rt_arena_hint`.
- Suite **137/137** with the feature off and 137/137 with it on. Fixpoint holds.

### 8.3 · Why it stayed opt-in during M1.1

Three things are unfinished, and each is a reason not to flip the default yet:

1. **`llvm-extract` and `llvm-link` are shelled out to.** Both ship with LLVM, but
   `prismio_llvm.h` exists precisely because the official Windows installer is minimal, and CI
   runs three platforms. The C API port (`LLVMLinkModules2`, plus basic-block deletion to build the
   curated module in process) removes the dependency; `llvm-api-backend.c:2667` already parses IR
   that way.
2. **Cold compile time is unmeasured.** §7's 1.18x is warm and one program. The cold path already
   regressed 19-28% and this adds two tool invocations to a cold build.
3. **`--verify`, the object cache and `--target` are covered by construction, not by measurement.**
   The verify define and the target flags are both in the cache key, and `-g` is declined outright,
   but none of that has been exercised on a cross build.

## 9 · M1.1b — the three things that kept it opt-in, two of them now measured

### 9.1 · Compile time

`build/S13b`, median of 7, g1 unless noted.

| | feature off | feature on | ratio |
|---|---:|---:|---:|
| first build, empty cache | 212 ms | 286 ms | **1.35x** |
| every build after, cache warm | 91 ms | 107 ms | **1.18x** |
| permanently uncached (`PRISMIO_OBJ_CACHE=0`), g1 | 212 ms | 286 ms | 1.35x |
| permanently uncached, g6 | 216 ms | 297 ms | 1.37x |
| permanently uncached, g3 | 233 ms | 306 ms | 1.31x |

**The +74 ms is one-time, not per-build.** The curated module is program-independent and cached, so
a first build pays for it and every build after pays only the `llvm-link` of the program's module:
**+16 ms**. The `PRISMIO_OBJ_CACHE=0` rows are the uncached-CI case, where it is paid every time.

Where the one-time cost goes:

```
lang_runtime.c -> .o    72 ms   what a cold build already paid
lang_runtime.c -> .ll   49 ms   what the curated module adds
llvm-extract 7 fns       8 ms
.ll -> .o               58 ms   codegen only, if the object were reused
```

Reusing the IR to produce the object as well -- `.c -> .ll -> .o` instead of `.c -> .o` -- would cost
+35 ms for the object against the 49 ms it saves, so it recovers about 14 ms of 57. Not nothing,
but not the fix it looks like: clang re-parsing the `.ll` costs nearly as much as compiling the
`.c`.

### 9.2 · `--verify`, `--target` and the object cache -- exercised, not assumed

- **`PRISMIO_OBJ_CACHE=0` did not reach the curated module, and now does.** That was a real defect:
  the key covers the runtime source and the flags but not the clang that turned one into the other,
  which is the exact hazard the object-cache bypass exists for. A bypass that skipped only half the
  build products is a bypass that does not bypass. `PRISMIO_OBJ_CACHE_TRACE=1` now reports
  `[objcache off|hit|miss] curated` alongside the objects.
- **`--verify` works and gets its own entry.** `g2.psm --verify` with the merge on: 0
  `bl _list_get`, `0 violation(s)`, and a second `curated-*.ll` appears rather than the non-verify
  one being reused -- which is the failure mode the verify define is in the key to prevent.
- **`--target x86_64-apple-macos --sysroot <SDK>` works.** Cross-built binary is
  `Mach-O 64-bit executable x86_64`, `call _list_get` goes **9 -> 0**, checksums correct, and it
  takes a third cache entry. Without `--sysroot` the cross build fails on `'stdio.h' file not
  found` -- **but it fails identically with the feature off**, so that is the pre-existing
  requirement `compiler_build_executable`'s NOTE already documents, not a regression. The merge
  degrades correctly there: `build_curated_module` returns NULL and the build proceeds unmerged.

### 9.3 · What is still open

Only the portability item -- **and §10 closes it.**

## 10 · The merge moves in process, and the last blocker goes

§9.3 left one item: the merge shelled out to `llvm-extract` and `llvm-link`. Both ship with LLVM,
but `prismio_llvm.h` exists because the official Windows installer ships `LLVM-C.lib`, the DLL and
very little else, and CI runs three platforms. A feature that silently does nothing on one of them
is worse than a feature that is off.

`ir_curate_module` and `ir_link_modules` now live in `llvm-api-backend.c`, where the C API
dependency already is; `build_driver.c` keeps the caching and the decision to merge and calls them.
`LLVMLinkModules2` was added to `prismio_llvm.h` on both paths, per that file's rule about keeping
them interchangeable -- it qualifies for hand-transcription where LLJIT and DIBuilder do not,
because its shape is two opaque module handles and an int.

### 10.1 · Emptying a function body without a `deleteBody`

The C API has no `Function::deleteBody`, and the obvious loop -- erase basic blocks front to back
-- breaks on any loop in the CFG: a back edge is a terminator in a later block naming an earlier
one, so the earlier block still has a use when it is erased. Three passes avoid needing to know the
CFG at all:

1. replace every non-void instruction's uses with `undef`;
2. erase the instructions -- which is what removes the *block-to-block* references, since a
   terminator is an instruction;
3. erase the now-unreferenced blocks.

Then a fixpoint sweep deletes declarations and globals nothing refers to, which is what
`llvm-extract` gets from GlobalDCE. Without that sweep the module carries every declaration in the
runtime: valid, but 49,935 bytes against 13,437, roughly four times the bytes for the merge to
parse on every build.

### 10.2 · Checked against the tool it replaces

The in-process module is **byte-identical** to
`llvm-extract --func=... ` plus the linkage rewrite, except for the `ModuleID` and
`source_filename` lines, which carry the input path. Structurally: 7 defines, 7
`available_externally`, 1 declare, 0 globals, both ways.

End to end with **only `clang` on PATH** -- no `llvm-extract`, no `llvm-link` -- `g2_tuned` builds,
`bl _list_get` and `bl _list_len` are both 0, no undefined statics, checksums correct. That is the
portability claim, demonstrated rather than argued.

### 10.3 · It is also cheaper

Two process spawns removed. Median of 4, g1, cache cleared between first-build runs:

| | first build | warm build |
|---|---:|---:|
| feature off | 238 ms | 96 ms |
| on, shell-out | 299 ms (1.26x) | 111 ms (1.16x) |
| **on, in process** | **277 ms (1.16x)** | **101 ms (1.05x)** |

The steady-state compile-time cost falls from about 16% to about **5%**. (Absolutes here are ~12%
higher than §9.1's on the same machine, which is host drift between passes -- the ratios are the
comparable figures, and all three rows were taken in one pass.)

### 10.4 · The corpus, re-measured after the port

`build/S14b` against itself with the variable set, `--runs 25`:

```
corpus median new/old: 0.858x   range 0.479-0.943x
GATE PASSED (corpus median within 3.0%, fewer than 2 programs past 10.0%)
```

| prog | §8 (shell-out) | §10 (in process) | RSS |
|---|---:|---:|---:|
| g1 | 0.982x | 0.936x | 1.000x |
| g2 | 0.892x | 0.888x | 1.000x |
| g3 | 0.940x | 0.943x | 1.000x |
| g4 | 0.772x | 0.743x | 1.000x |
| g5 | 0.481x | **0.479x** | 0.968x |
| g6 | 0.837x | 0.827x | 0.996x |
| **median** | **0.864x** | **0.858x** | |

The two passes agree to within the host's own reproducibility. g1 moves 0.982x -> 0.936x and g3
0.940x -> 0.943x in opposite directions, which is the A/A floor §0 describes rather than an effect
of the port -- the port changes *which process* builds the module, not the IR it produces, and §10.2
establishes the IR is the same. **The corpus median is the number that holds: 0.864x and 0.858x.**

## 11 · M1.3 — the deeper form, decided by measurement

TODO.md offered two options: write the hot container ops in Prismio itself, or adopt ThinLTO-style
summaries "if the merge stops scaling". Measurement rejected both and produced a third.

### 11.1 · Why neither option was the answer

**The merge has not stopped scaling.** §10.3 puts the steady-state compile-time cost at ~5% with a
13.4 KB cached module. ThinLTO's trigger condition is simply not met.

**And the seam is already closed where it mattered.** With the merge on, g3's hot functions --
`propagate` and `count_visible` -- contain **zero** runtime calls; only `build_hierarchy`, which
runs once during setup, still calls out. Writing those ops in Prismio so they "land in the same
module for free" would change nothing, because they are already in the same module. The real
benefit of Prismio-native ops is monomorphisation and layout -- a `List<Node>` specialised to its
element type -- and that is M4's inline-storage work, not M1's seam.

### 11.2 · What the corpus actually still called, and the false lead

The one op still reached from program code across every program was **`list_push`**. It was
excluded from the curated set by the closure rule (§8.2), so the obvious move was to export the
three `static`s it reads -- `rt_arena_hint`, `arena_depth`, `arena_alloc_slot` -- and curate it.

That was built and measured, and it **changed nothing**. `bl _list_push` counts were identical
between the seven-op and eight-op builds on all six programs: 3/3, 5/5, 3/3, 6/6, 15/15, 9/9. The
inliner declines it regardless of availability:

```
'list_push' not inlined into 'load_texture__Struct_AssetCache_Int_Int'
  because too costly to inline (cost=675, threshold=225)
```

**This is worth recording as a measurement lesson.** The timing table from that experiment showed
g5 apparently improving from 1.48x to 2.57x -- a 1.7x swing -- from a change that provably emitted
identical code. §0's A/A warning is not theoretical, and "the corpus median is the number that
holds" is what stopped a noise reading from being written down as a result.

### 11.3 · The answer: outline the growth path

`list_push` is 227 IR lines, of which 159 are realloc-and-copy that runs once per *doubling*
rather than once per push. Outlining that into `list_push_grow` drops the remaining fast path to
**69 IR lines** -- comfortably inlinable -- and takes all three `static`s with it, so the half that
gets inlined references only `list_push_grow` itself. **The split alone makes `list_push` curatable;
no mutable global has to be exported at all.**

Every `bl _list_push` in the corpus disappears: 3, 5, 3, 6, 15, 9 -> **0, 0, 0, 0, 0, 0**.

### 11.4 · Measured, through the driver

`build/S15b`, `--runs 25`, both arms the same binary:

```
corpus median new/old: 0.812x   range 0.450-0.963x
GATE PASSED (corpus median within 3.0%, fewer than 2 programs past 10.0%)
```

| prog | §10 (7 ops) | §11 (8 ops + split) | RSS | vs idiomatic Rust |
|---|---:|---:|---:|---|
| g1 | 0.936x | 0.905x | 1.000x | 1.34x -> 1.21x |
| g2 | 0.888x | **0.828x** | 1.000x | 5.74x -> 4.75x |
| g3 | 0.943x | 0.963x | 1.000x | 1.08x -> **1.04x** |
| g4 | 0.743x | 0.758x | 1.000x | 3.13x -> 2.37x |
| g5 | 0.479x | **0.450x** | 0.976x | 2.81x -> **1.26x** |
| g6 | 0.827x | **0.796x** | 0.985x | 4.02x -> 3.20x |
| **median** | 0.858x | **0.812x** | | |

RSS still regresses nowhere. **g5 ends at 1.26x of idiomatic Rust, from 2.69x before M1 began.**

### 11.5 · The split is invisible with the feature off

It is a change to the runtime, not to codegen, so the compiler emits byte-identical IR either way
-- checked on g1, g3, g5 and on `src/main.psm` itself, S14b against S15b. That is CODE_STYLE's
"a behaviour-preserving change must produce byte-identical compiler output", and it holds.

It costs nothing at run time either. S14b against S15b, both with the merge **off**, `--runs 25`:

```
corpus median new/old: 1.003x   range 0.997-1.017x     GATE PASSED
g1 1.007x   g2 1.017x   g3 0.997x   g4 1.011x   g5 0.998x   g6 0.998x    RSS 1.000x everywhere
```

Flat on all six. The extra call to `list_push_grow` on the non-inlined path runs once per doubling,
which is what that predicts. So a build that never turns the merge on is unaffected by the split,
and a build that does gets the corpus median in §11.4.

## 6 · Threats to validity

- **One host, one linker, one LLVM.** ld64 and LLVM 22.1.8. The portability question that killed
  `-flto` before is exactly the question this does not answer.
- **Hand-built baselines.** Both sides are `clang -O2` by hand, mirroring `build_driver.c`'s
  commands but not run through the driver, so absolutes differ a little from a driver-built binary.
  §9.3 has the same limitation for the same reason.
- **The attribute stamp is a text rewrite over the emitted `.ll`**, not the compiler doing it.
  It regexes `define … ) {`, which matches because the backend currently emits no attributes at
  all. Once the backend stamps them the rewrite stops being valid, which is the intent.
- **`-mcpu=apple-m4` was checked for call count only**, not timed.
- **§7's routes were built with the `llvm-link` and `llvm-extract` executables**, not with the
  in-process C API the implementation will use. The IR is the same either way, but that
  equivalence is asserted here, not measured.
- **§7 measures one program for compile time** (g2_tuned) and does not separate cold from warm.
- **§8's two arms are the same binary** with an environment variable between them, which controls
  for compiler-generation drift but means the measurement cannot see a cost paid before
  `compile_ir_to_object` runs.
- **§9.1's first-build rows clear the whole object cache**, so they also re-pay for
  `program_support.c`; the +74 ms is the delta between two identically-cleared runs, not the
  curated module measured in isolation.
- **§9.2's cross-build check is one target on one host** (`x86_64-apple-macos` with the Xcode SDK),
  which is the same single target HANDOFF records as the only one ever built and run.
- **§11.2's false lead was caught only because the call counts were checked.** Had the timing
  table been trusted on its own, a 1.7x noise reading on g5 would have been recorded as the effect
  of a change that emitted identical instructions. Check what was emitted before believing what was
  timed.
- **§11's g5 result carries the corpus.** The median moves 0.858x -> 0.812x, but four of six
  programs move by less than 4%; g5 and g2 are most of it. `list_push`-heavy code benefits,
  other code barely.
- **§10's portability claim is a PATH test on macOS**, not a build on Windows or Linux. It shows
  the compiler no longer *invokes* those tools; it does not show CI is green on three platforms.
- **§8 is one pass.** §0's A/A note applies: the corpus median is the number that holds, and g1 at
  0.982x is inside this host's measured A/A floor rather than a result.
- Nothing here ran the suite or the fixpoint, because nothing here changed the compiler.
