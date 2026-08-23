Continue the string/runtime work on Prismio. **Verify the tree before planning — this brief has been wrong in both directions before.**

```bash
git status --porcelain | grep -v graphify-out
bash tools/bootstrap.sh --seed --out build/v0 && bash tools/bootstrap.sh --compiler build/v0 --out build/v1
PRISMIO=$PWD/build/v1 python3 tests/test_runner.py 2>&1 | tail -4
```

Expect **144/147**. Two failures live in uncommitted `aif_support.c`/`ownership.psm` work that predates this line (`forced split released 4095 more objects`, `verify mode reported a fact that did not hold`), and `aif_layout` is **flaky** — the same binary has scored both 143 and 144. The pass count is not a reliable gate; use byte-identical output.

**State.** Committed as `Port 1/2`: `std/string.psm`, `std/fs.psm`, `std/process.psm`, `RUNTIME.md`, `C_CODE_STYLE.md`, `tests/test_75_std_string.psm`, `tests/test_76_std_fs.psm`, and the `Ptr` migration (handles no longer punned through `String`; absent is real `NULL`). Uncommitted: the C comment cleanup, the fat-String scaffolding, and `tests/test_77_spawn_literal.psm`.

Benchmarks vs **pure C and pure Rust** (native programs, outputs verified identical, startup subtracted): search 0.361 / 0.063 / **0.047s**; uppercase 0.070 / 0.112 / 0.131s; int→string 0.080 / 0.036 / **0.034s**.

---

## 1 — Fat String: reconcile with the ownership analysis (main job)

`String` as `{ptr, i64}` is implemented and **off**. With it on: **78/78 compile, 68/78 run.** The 10 failures are all AIF/ownership tests and they **segfault at run time** — the violation class, a wrong free. That is why it is off.

Turn it on at four sites:

- `src/ir/types.psm` `mapType` — `"ptr"` → `"struct:prismio.str"`
- `src/ast/types.psm` `typeIrKey` — same, for `TypeKind.STRING`
- `src/ir/expr.psm` literal emission — `ir_string_ptr(expr.s2)` → `ir_const_str(expr.s2, str_length(expr.s1))`
- `src/ir/types.psm` `fieldStorageType` — a String field keeps the pair

Everything else is in place and inert: backend aggregates (`ir_undef` / `ir_insert_value` / `ir_extract_value` / `ir_const_str` / `ir_global_str_var`), `coerce_for` in `llvm-api-backend.c` (a fat String where a pointer is wanted yields its pointer half — fixes all ~25 hand-written `ir_call_arg("ptr", …)` sites at one point), `callIsPrismioFn`, `fatFromPtr`, and marshalling for extern calls, struct fields, `match` payloads, `Task<String>` joins and container slots.

**The remaining bug is that AIF and codegen disagree about which value owns the buffer once a String is a pair.** Start with `test_43_aif_scope_drop` (smallest failure); compare the drop sites the analysis expects against the frees codegen emits. `--verify` is the tool — read `violations` before `leaked`.

`prismio_cstr_len` is the strlen codegen calls at FFI boundaries; it cannot use `str_length`, which takes a fat String and would regress infinitely.

**Payoff, measured:** the entire uppercase gap is `str_length`. The identical loop with the length passed in runs **0.067s against C's 0.070s and Rust's 0.112s** — finishing this beats both on all three benchmarks. `strToUpper` already vectorises (`ldp q3, q4` / `add.16b`, 64 bytes/iteration) and byte access is already an intrinsic.

## 2 — Split `aif_support.c` (7014 lines)

C_CODE_STYLE.md's standing refactor, item 1. Six responsibilities its own section comments already mark: interning and keys, fact encodings, the constraint store, the fixed point, tiers and dispositions, the manifest. Six files under `runtime/aif/`, one header.

The file list is duplicated in four checked places: `prismio_toolchain_files[]` in `build_driver.c`, `RUNTIME_SOURCES` in **both** `tools/bootstrap.sh` and `tools/bootstrap.ps1`, `embedded_sources.h` (regenerate with `runtime/generate_embedded_sources.py`), and `tools/check_source_lists.py`.

Behaviour-preserving → the bar is byte-identical compiler output. `llvm-api-backend.c` (3032 lines) is the same shape and can follow.

## 3 — Hoist the `rt_base_alloc` seam

`lang_runtime.c` still defines its own copy of the macros ahead of its includes; `prismio_runtime.h` now carries the canonical pair and the `#ifndef` guard tolerates both. One definition beats two that happen to agree.

## 4 — Four missing contract entries

`str_replace`, `str_clone`, `str_trim`, `str_split` allocate on every path and appear in neither `aifFfiProduces` (`src/aif/contracts.psm`) nor `FFI_RETURNS_PRODUCE` (`aif/prototype/aif.py`). No `std.*` path calls them, so nothing shipped is affected, but a hand-written `extern fn` for one still leaks without `produce(free)`.

`run_oracle_vocabulary_test` **cannot catch this class** — it compares the two tables against each other and both omit the same four names. Extend it to scan `lang_runtime.c` for pointer-returning functions and assert each appears in both. Adding the entries is a behaviour change: two-generation fixpoint plus `tools/aif_differential.py`.

## 5 — `tools/package.sh` breaks whenever the backend uses new LLVM API

**Recurring, not fixed.** Packaging compiles `llvm-api-backend.c` *without* `-DPRISMIO_LLVM_REAL_HEADERS`, against the hand-maintained shim in `runtime/prismio_llvm.h`. So a bootstrap and the whole test suite can pass while `package.sh` fails on an implicit declaration. It bit three times in one session; each time the fix was adding a declaration to the shim after the fact.

Worth a structural fix: either have CI/`check_source_lists.py` compile the backend both ways, or drop the shim and require real headers. Note `LLVMConstExtractValue` no longer exists in LLVM 22 — use `LLVMGetAggregateElement`.

## 6 — Channels and tasks are still unwrapped

`chan_new` / `chan_send` / `chan_recv` / `chan_close` / `chan_share` / `chan_len` / `chan_free` and the `prismio_task_*` family have no `std` module and no ownership contracts written down (`RUNTIME.md` §4 lists them as "not yet wrapped"). `spawn` / `join` are keywords and need nothing; channels do.

## 7 — Docs

`RUNTIME.md`'s performance section carries older numbers. The sibling docs repo at `../docs` is compiler-checked: `cd ../docs && PRISMIO=<compiler> node scripts/verify-doc-examples.mjs`, expect 116/116. `stdlib/strings.md` has a "Performance" section that should match.

---

## Things that cost time last session — don't repeat them

- **Benchmarks.** Subprocess wall-clock timing let clang hoist entire loop-invariant computations out of the C and Rust loops, producing a bogus "C = 0.001s". Mutate the input each iteration, size each run to multiple seconds, warm up first, and **assert every language prints the same checksum** before comparing. A shell helper using `i` as its loop variable silently clobbered the workload index. For attributing a gap *within* one program, prefer in-process `clock_gettime` over timing whole processes.
- **Two type→LLVM mappings exist** — `mapType` (from a type *name*) and `typeIrKey` (from a `TypeInfo`). Changing one and not the other gives calls that disagree with their own declarations.
- **Building an instruction on a constant aggregate crashes inside LLVM's `Value::setName`** rather than failing cleanly. Guard with `LLVMIsConstant`.
- **The LLVM context outlives a module**, so a process compiling two of them registers `prismio.str` twice and the second is uniqued to `prismio.str.0`. Match the type by prefix, not equality.
- **`str_length` and `str_char_at` are both O(n)** — `str_char_at` calls `strlen` to range-check every byte read. Never put either in a loop condition: 15.08s against 0.48s hoisted. `str_byte_at` / `str_put_byte` are the O(1) unchecked pair and are now compiler intrinsics (GEP + load/store, no call).
- **A pass-through return is not owned.** `return helper(x)` where `helper` allocated gets no drop at the caller; the returned expression must be this function's own allocation. That is why `strToUpper` and `strToLower` are written out twice instead of sharing a body.
- **`collect_strings` enumerates node kinds**, so a literal under a kind it has no case for is never named. That was the `spawn f("literal")` bug (`internal backend error: unknown string global ()`), fixed by making the literal's codegen name itself on the spot; `tests/test_77_spawn_literal.psm` covers it. If you add a construct with a subtree, you no longer need to touch the pre-pass — but check.
