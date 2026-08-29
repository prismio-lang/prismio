# M6 slice 2 — ordinary struct-path TBAA, and the g2 regression it caused

Measured on macOS arm64 with LLVM 22.1.8. The old compiler is `build/tbaa3` —
the last compiler green on all three platforms. The accepted candidate is
`build/m6-rc`, a two-generation fixpoint.

**Slice 2 ships for field reads and field assignments and is declined for struct
literal initialisers.** The decline is the whole of this document: tagging
initialisers is what cost 1.68x on g2, and declining them costs nothing anywhere
else — every other program is mnemonic-identical to the full slice.

## What changed

Ordinary struct field loads and stores use the same clang-rooted TBAA tree as
slice 1, but with a struct base and the field's byte offset. The backend builds
that base from the LLVM record it actually emitted, so it follows both LAYOUT 7
field reordering and LAYOUT 6 hot/cold splitting instead of reconstructing either
from declaration order.

The discriminating gate (`run_struct_path_tbaa_test`) checks five shapes:

- an unsplit `Vector { x: Float, y: Float }` has paths at byte 0 and byte 8;
- forced `Body.hot` has paths at 0, 8, 16, 24 and its link at 32;
- forced `Body.cold` has paths at 0, 8, 16, 24, 32, 36, 40 and 44;
- `Punned`, named beside raw `Ptr` in an extern signature, has no distinct base;
- `Initialised`, built by a literal and only read, has paths on its **loads** and
  on **none of its stores**, while `Assigned` — the positive control in the same
  file — carries paths on its stores.

Narrow scalars and aggregates remain conservative. `Ptr` is still one `any
pointer` class. A named struct sharing an extern signature with raw `Ptr` falls
back to slice 1's scalar tags: giving it a distinct base would silently turn
Prismio's explicit type-punning escape hatch into C strict aliasing.

## The g2 regression, and why a shorter listing was not a win

The first slice-2 candidate (`build/m6s2-4`) measured **1.680x old/new on g2**,
27.522 ms → 46.235 ms, checksums equal, on the official all-g ABBA run
(`xlang/results-m6-slice2-final-all-ab.json`).

A per-function mnemonic diff of the whole binary found **exactly one changed
function out of 187** — `cull` — 53 instructions down to 49:

```
   bl   _list_push_slot                bl   _list_push_slot
-  ldr  w8, [x24]                      ldp  d0, d1, [x24]
-  str  w8, [x0]                       stp  d0, d1, [x0]
-  ldr  w8, [x24, #0x4]                strb w23, [x0, #0x10]
-  str  w8, [x0, #0x4]
-  ldr  d0, [x24, #0x8]
-  str  d0, [x0, #0x8]
   strb w23, [x0, #0x10]
```

`DrawCmd`'s first 16 bytes coincide with `Renderable`'s, so struct paths let LLVM
prove the stores cannot alias the interleaved loads and merge all three into one
128-bit pair.

### It is the instruction, not the layout

Both functions begin at the same address and every instruction up to the change
is at the same address in both binaries, so the loop's alignment is identical.
To remove code layout as a variable entirely, the *old* binary was byte-patched
in place — the six scalar instructions replaced by the merged pair plus four
`nop`s, so every later address is unchanged — and re-signed. Randomised-order
interleaved runs, 21 rounds, `loop_ms` = the program's own summed `frame_ns`:

| patched into `build/tbaa3`'s g2 | median ms | vs unpatched |
|---|---:|---:|
| the original scalar sequence (control) | 27.11 | 1.000x |
| `ldp d0,d1` / `stp d0,d1` (what slice 2 emits) | 45.12 | **1.664x** |
| `ldp x8,x9` / `stp x8,x9` — integer registers | 45.37 | 1.674x |
| `ldr q0` / `str q0` — one 128-bit register | 44.59 | 1.645x |
| `ldp d0,d1` + two 8-byte `str` — same bytes, same addresses | 28.47 | **1.049x** |

Four identical binaries measured within 0.8% of each other, so the harness is not
the source. The regression follows the **128-bit store** and nothing else: the
register file does not matter, and splitting the same 16 bytes into two 8-byte
stores at the same addresses removes it.

Ruled out, each by measurement rather than argument:

- **Alignment.** Patching the element stride from 24 to 32, 40 and 48 bytes — 32
  and 48 make every slot 16-byte aligned — leaves the new/old ratio at
  1.63x–1.72x throughout.
- **The allocator.** `MallocNanoZone=0` reproduces it: 1.642x against 1.668x.
- **Startup and DVFS.** At ten times the frame count the ratio is 1.661x.
- **Cold destination memory.** Reusing one pre-grown element block across frames
  instead of allocating a fresh one still measures 1.53x.

### What it actually is

`aif/evidence/bench/g2_cull_probe.c` reproduces the loop in C — boxed scene,
`RtList` header, out-of-line `list_push_slot`, warm pre-grown element block — and
varies only how the slot pointer is obtained:

| | scalar | 128-bit pair | pair / scalar |
|---|---:|---:|---:|
| slot from an out-of-line call that reads and writes the `RtList` header | 18.74 ms | 50.93 ms | **2.74x** |
| slot from an out-of-line call that touches an unrelated global | 10.37 ms | 9.55 ms | **0.92x** |
| slot computed inline, no call | 10.41 ms | 7.84 ms | **0.76x** |

**The merge is a win — 0.76x — wherever the optimiser can see the destination.**
It is a 2.74x loss only against `list_push_slot`, whose next call reloads the
same `RtList` header the store ran ahead of. The cost is ~6 cycles per pushed
element in a loop that otherwise runs at ~5 cycles per element.

`list_push_slot` is not in `PRISMIO_CURATED_OPS` for a recorded reason: it
reaches `list_inline_grow` and `list_set_elem_inline`, both `static`, which is
the exact rule `list_push_grow` was outlined to satisfy for `list_push`.
**Curating it is the fix, and it is v0.2 work** — a new optimisation, not a
release task.

### The decline, and why it is this line and not g2's

Until that seam closes, a struct **literal's initialising stores** keep slice 1's
scalar tags; field reads and field assignments keep their paths. The line is not
"g2" — it is that *every* struct literal pushed into a container is written into
a slot handed back by `list_push_slot`, which is idiomatic Prismio.

Declining only initialisers was checked against declining nothing, by diffing
every function of every program:

| | full slice 2 vs `tbaa3` | initialisers declined vs `tbaa3` |
|---|---:|---:|
| g1 | 2 functions changed | 2 — identical to full |
| g2 | 1 (`cull`, the regression) | **0** |
| g3 | 2 | 2 — identical to full |
| g4 | 3 | 3 — identical to full |
| g5 | 2 | 2 — identical to full |
| g6 | 1 | 1 — identical to full |
| g9 | 0 | 0 |

Narrow and full differ in exactly one function of one program, and it is the
regression. The prize is kept in full; the loss is gone.

## Generated code before timings

| program | functions | changed vs `tbaa3` | what |
|---|---:|---:|---|
| g1 | 190 | 2 | `fade`, `main` — same count, reordered |
| g2 | 187 | **0** | |
| g3 | 190 | 2 | `link_child` 23 → 22, `build_hierarchy` 191 → 190 |
| g4 | 191 | 3 | `system_movement` 48 → 44, `system_regen`, `main` |
| g5 | 198 | 2 | `release` 35 → 33, `main` 669 → 667 |
| g6 | 198 | 1 | `world_step` 60 → 56 |
| g9 | 184 | **0** | |

g4's and g6's hot loops replace three scalar field updates with a paired NEON
update plus the remaining scalar lane. g5's `release` forwards the refcount it
just stored instead of reloading it through two dependent loads:

```
   str  w10, [x9]              str  w10, [x9]
-  ldr  x9, [x8, #0x8]         cmp  w10, #0x0
-  ldr  w9, [x9]
-  cmp  w9, #0x0
```

## All-g old/new — `build/tbaa3` → `build/m6-rc`

25 interleaved runs, `tools/milestone_bench.py`, checksums equal on every arm.
Raw: [`xlang/results-m6-slice2-rc-ab.json`](xlang/results-m6-slice2-rc-ab.json).

| | g1 | g2 | g3 | g4 | g5 | g6 | g9 |
|---|---:|---:|---:|---:|---:|---:|---:|
| new / old | 1.007x | **0.995x** | 0.999x | **0.963x** | 1.142x † | **0.993x** | 1.000x |
| RSS | 1.000x | 0.992x | 1.008x | 0.992x | 0.990x | 1.020x | 1.000x |

Corpus median 0.999x, gate passed.

**† g5's 1.142x is not real, and this is the third time this program has produced
one.** Its two changed functions are both *shorter* and one strictly removes two
dependent loads. An A/A calibration of `build/tbaa3` against itself spans
28.1–54.2 ms on the same binary — a 1.93x range within one arm. Measuring the two
g5 binaries directly, randomised order, 25 rounds: **0.574x median, 0.756x
min/min, in the new compiler's favour.** Diff the functions before believing
either harness on g5.

## Five-arm standing

25 runs per arm, cyclic rotation of the arm order,
`tools/five_arm_bench.py`. Raw:
[`xlang/results-m6-slice2-rc-five-arm.json`](xlang/results-m6-slice2-rc-five-arm.json).

| loop ms | g1 | g2 | g3 | g4 | g5 | g6 | g9 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Prismio (old) | 19.375 | 28.033 | 44.103 | 34.591 | 45.580 | 88.898 | 103.947 |
| **Prismio (new)** | 19.794 | 27.389 | 44.057 | 33.632 | 36.905 | 87.757 | 103.815 |
| Prismio hand-tuned | 4.620 | 12.329 | 35.194 | 20.828 | 8.239 | 67.095 | — |
| Rust idiomatic | 18.175 | 18.185 | 45.171 | 21.749 | 28.925 | 55.087 | 113.953 |
| Rust hand-tuned | 4.601 | 10.140 | 30.299 | 17.776 | 4.324 | 40.295 | 71.914 |

**Prismio / Rust idiomatic: 1.09x, 1.51x, 0.98x, 1.55x, 1.28x, 1.59x, 0.91x** —
a standing range of **0.91x–1.59x**, with Prismio ahead on g3 and g9. g4 improves
from 1.59x to 1.55x and g6 from 1.61x to 1.59x.

g9 has no Prismio hand-tuned arm; that is task 2's subject, not a gap here.

## Gate

- two generations reach a byte-identical compiler IR fixpoint (`rc3`/`rc4`);
- suite **199/199**, including the five-shape struct-path gate above;
- all 30 corpus programs build and run;
- AIF oracle agrees on 18/18 sources;
- `--verify` on every changed program: 0 leaked, 0 violations —
  g1 10026/10026, g3 15489/15489, g4 13076/13076, g5 8097/8097, g6 46818/46818;
- g1, g3, g4, g5 and g6 clean under AddressSanitizer;
- source lists agree.

## Commands

```bash
bash tools/bootstrap.sh --compiler build/tbaa3 --out build/rc3
bash tools/bootstrap.sh --compiler build/rc3   --out build/rc4
./build/rc3 build src/main.psm -o build/rc3.ll
./build/rc4 build src/main.psm -o build/rc4.ll
cmp build/rc3.ll build/rc4.ll
cd tests && PRISMIO=../build/m6-rc python3 test_runner.py
python3 tools/aif_differential.py --compiler build/m6-rc
python3 tools/milestone_bench.py --old build/tbaa3 --new build/m6-rc --runs 25 \
    --label "M6 slice 2 narrow-decline, all-g" \
    --json aif/evidence/xlang/results-m6-slice2-rc-ab.json
python3 tools/five_arm_bench.py --old build/tbaa3 --new build/m6-rc --runs 25 \
    --json aif/evidence/xlang/results-m6-slice2-rc-five-arm.json
clang -O2 -o /tmp/g2_cull_probe aif/evidence/bench/g2_cull_probe.c && /tmp/g2_cull_probe
```
