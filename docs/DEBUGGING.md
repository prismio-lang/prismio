# Debugging Prismio programs

There are two debugging stories here, and they answer different questions.

The first is the ordinary one. `prismio build x.psm -g` emits DWARF, and lldb or gdb
gives you breakpoints, stack traces, frame variables and struct members. That is table
stakes, it works, and the rest of this document's first half is how to use it and what it
deliberately declines to tell you.

The second is the one worth reading even if you never open a debugger. Prismio *infers*
where every value lives — stack, arena, owned, counted — instead of asking you to declare
it. A compiler that infers something has an answer to explain, and three tools exist to
make it explain: the **manifest** says where each allocation went, `--why` says how it
derived that, and `--verify` runs the program and checks the answer held. Between them
they answer "where did my memory go, and why" without a debugger being involved, and they
answer it per allocation site rather than per byte.

---

## Part 1 — `-g`

```bash
prismio build hello.psm -g -o hello
lldb hello
```

`-g` emits, for the whole merged program including any `std.*` and imported modules:

| | |
|---|---|
| line table | every statement, with column, so a breakpoint on a `for` header does not stop in its body |
| `DW_TAG_subprogram` | per source function, with both the source name and the mangled symbol |
| `DW_TAG_lexical_block` | per `{ }`, so two `let x` in sibling blocks are two variables |
| `DW_TAG_formal_parameter` / `DW_TAG_variable` | per binding, at its frame slot |
| `DW_TAG_structure_type` | per declared struct, with members at their **real** offsets |

`String` is described as `char *`, which is what it is — a NUL-terminated buffer — so a
debugger prints the characters rather than the address.

```
(lldb) breakpoint set --file hello.psm --line 21
Breakpoint 1: where = hello`main + 104 at hello.psm:21:13
(lldb) type lookup Point
struct Point {
    int x;
    int y;
}
```

Two things `-g` changes about the build, both on purpose:

- **The object step drops to `-O0`.** A normal build compiles the program's IR at `-O2`,
  and at `-O2` a local is promoted out of its stack slot in the first hundred milliseconds
  of the pipeline. LLVM does not lie about that — it drops the location rather than keeping
  a stale one — so what you get is not a wrong answer, it is `<optimized out>` on every
  variable, which is what people report as "`-g` does not work". If you want both, ask:
  `prismio build x.psm -O2 -g` runs the IR pipeline and records `isOptimized` in the
  compile unit, so the debugger tells you what it is looking at.
- **On macOS, a `.dSYM` is written.** Mach-O keeps DWARF in the object file and puts only a
  debug map in the executable, and the compiler deletes the object after linking. `dsymutil`
  runs before that happens.

`-g` is unrelated to `--debug`, which is SPEC 7.1's zero-analysis level and says nothing
about debug info. The collision of names is unfortunate; both spellings are the ones their
users expect.

### What `-g` will not tell you, and why

The rule the emitter is built around is that **a location that is wrong is worse than no
location**. A debugger that admits it does not know where `x` lives sends you to a print
statement. One that confidently names the wrong frame slot sends you after a bug that does
not exist. Three places where Prismio's memory model makes that a live question:

**A T0 value's storage is one slot for every iteration of its loop.** When the analysis
proves a struct cannot outlive the scope that builds it, the allocation becomes an `alloca`
hoisted to the entry block, and a `let p = Point { … }` inside a `while` reuses it:

```llvm
entry:
  %0 = alloca %Point                  ; one slot ...
  %p.40 = alloca ptr
  br label %label_42
label_43:                             ; ... rewritten every iteration
  store i32 %3, ptr %4
  #dbg_declare(ptr %p.40, !333, !DIExpression(), !341)
```

The DWARF is true: at any instruction inside the loop body, `p` names that iteration's
object, and the lexical block bounds the name to the block that declares it — exactly as a
C loop-body local is bounded. What is *not* expressible is that a pointer to `p` saved in
iteration 1 refers to iteration 2's object afterwards. DWARF has no vocabulary for it. AIF
proves that pointer cannot escape, which is why the promotion is legal; if you want to see
that proof rather than take it, that is Part 2.

**An arena-placed value has no individual lifetime.** Its slot holds a pointer, and the
pointer is right for as long as the binding is in scope. The storage behind it does not die
when the binding does — it dies with the enclosing region, all at once. Scoping covers the
binding; nothing in DWARF can say "this address is live until some other PC", so nothing
tries to.

**A field may not be where you wrote it.** The layout search (LAYOUT 7.2) permutes field
order within a record, and LAYOUT 6 can move a record's tail into a separately allocated
cold block. Member offsets are therefore never computed from the declaration — they come
from `LLVMOffsetOfElement` over the struct LLVM actually built. A permutation is described
rather than papered over, and a split type is described as what it is:

```
DW_TAG_structure_type  "Particle"        byte_size 0x20
  DW_TAG_member  "id"      offset 0x00
  DW_TAG_member  "x"       offset 0x08
  DW_TAG_member  "y"       offset 0x10
  DW_TAG_member  "__cold"  offset 0x18   type "Particle.cold *"

DW_TAG_structure_type  "Particle.cold"   byte_size 0x28
  DW_TAG_member  "tag"     offset 0x00
  DW_TAG_member  "vx"      offset 0x08
  …
```

`p obj->__cold->vx` is a longer thing to type than `p obj->vx`. It is also the truth, and
the alternative — listing all eight fields at eight offsets in a 32-byte record — is a
debugger reading someone else's memory and reporting it as yours.

Two smaller omissions, recorded rather than smoothed over:

- **A node with no source span gets no location.** Desugared compound assignment, inserted
  drops and monomorphised clones carry line 0. Rather than claim line 0 — which puts the
  debugger at the top of the file — the previous location stands, so the instruction is
  attributed to the statement that caused it.
- **Cleanup code inherits the preceding statement's line.** A scope's drops, an arena pop
  and a region exit are emitted after the last statement of a block, and the AST records no
  closing-brace position, so there is no `}` to point at. Attributing them to the last real
  statement is the closest true answer available; giving the block's *opening* line would
  make the debugger appear to jump backwards.
- **Debug info needs a compiler built against real llvm-c headers.** `tools/setup_llvm.py`
  requires them, so the supported configuration has it. A compiler built against the
  fallback declarations in `runtime/prismio_llvm.h` says so and exits rather than emitting
  nothing and letting `-g` look as though it worked. The reason is in that file: DIBuilder's
  signatures are long and mostly integers, the linker checks names and not signatures, and a
  transcription slip there would produce DWARF that is subtly wrong rather than a build that
  fails.

---

## Part 2 — where the memory went, and why

A debugger is good at "what is in this variable right now". It is bad at "why is this
object on the heap", because by the time you are in the debugger, that decision is a fact
about the binary and not about anything you can inspect.

Prismio's decisions are inferred, so the compiler has to have had a reason, and it can be
asked for it. Three tools, in the order you would reach for them.

### The manifest — where each site went

```bash
prismio aif leak.psm
```

```
aif-manifest 1
level       AIF-1
converged   yes
rounds      5 (points-to 3)
sites       7
#
# symbol                    tier  thread     placement      type     layout   origin
localOnly__Int#0            T0    Isolated   stack          Node     AoS      leak.psm:13:24
main#0                      T1    Isolated   region:auto    String   AoS      leak.psm:26:13
makeNode__Int#0             T2    Isolated   owned          Node     AoS      leak.psm:9:17
```

One row per allocation site, keyed by the function that contains it. `tier` is what the
analysis proved (T0 stack, T1 region, T2 owned, T3 counted, T4 shared/collected);
`placement` is what codegen actually emitted for it, which is a different claim — `rc:none`
means the facts permit a count and no count was emitted, and printing `rc` there would
assert a mechanism the binary does not contain.

`--summary` collapses it to a distribution, which is the form to use on a large program:

```
$ prismio aif src/main.psm --summary
sites        678
  T0   2       0%
  T1   471     69%   #########################################
  T2   203     29%   #################
  T3   2       0%
  T0-T2 (no runtime bookkeeping): 676 / 678 = 99%
```

That is the compiler compiling itself: 678 allocation sites, 465 of them served from
automatically placed arenas, 203 owned outright, and no cycle collector in the binary at
all because no struct type lies in a non-trivial SCC. The two T3 rows read `rc:none` —
the facts permit a count, and none was emitted, because both are opaque extern returns
with no header of ours in front of them.

### `--why` — the derivation, and the repair

The manifest says a site is T2. `--why` says how it got there and what would move it:

```bash
prismio aif leak.psm --why=makeNode__Int#0
```

```
makeNode__Int#0                   T2

  minimal cause
    E rose to Caller
      <- E-RETURN  leak.psm  9:42

  placement
    heap  -- no arena serves this site
      because  the tier is not T1 -- see the cause above
      and      no `region` encloses this allocation *in its own function*
      note     an arena is a lexical scope (SPEC 5.2.1). A `region` in a
               caller cannot reach an allocation made in a callee, so no
               change to the escape lattice moves this site.

  repairs, cheapest first
    1. have the caller allocate and pass it in       restores T1, no runtime cost
    2. pin(T1) on the binding      rejected -- inference converged, so this is proven false
```

The second repair being *rejected* is the interesting half. A converged analysis has
proved the value escapes; `pin(T1)` would be a false assertion about your own program, and
the tool says so rather than offering it. `pin` is checked (SPEC 5.4.1) — a refuted pin
fails the build.

### `--verify` — did the inference hold?

```bash
prismio build leak.psm --verify -o leakv
./leakv
```

```
node
12
aif-verify: leaked #1 (16 bytes)
aif-verify: 1 allocated, 0 released, 1 leaked, 0 violation(s)
aif-verify: FAILED -- an inferred fact did not hold at run time
```

`--verify` swaps the allocator and deallocator names through the memory-model seam and
compiles the runtime with its own allocator pointed at the same shims. **Codegen is
byte-identical to a release build** — the swap is a name, not a different program — so what
you are checking is the real one.

What it reports:

- **`violations`** — precisely: a release of a pointer that is not live. A double free, or
  a free of something that never came from the shim. Either means the value was reclaimed
  on a path the analysis did not account for, which is an inferred fact being wrong, and
  that is the number to watch: it is the mechanism checking itself.
  Reads are *not* instrumented — the shims poison memory before returning it, so a read
  that should not have happened comes back as `0xDD` bytes rather than data that is merely
  stale and plausible. That makes a use-after-free loud, not impossible.
- **`released`** — how many of the allocations found their reclamation point. Compare this
  across two builds; it is the stable half.
- **`allocated` / `leaked`** — noisy run to run, because they count whatever the program
  did on that run. Do not diff them.

Read the example above against the manifest. `localOnly`'s `Node` is T0, so it never
appears in the accounting at all — it was never an allocation. `makeNode`'s `Node` is T2,
allocated once and returned, and a returned value has no free point in the callee, so it
leaks. `--why` already said exactly that, and named the repair, before the program ran.

That is the loop: **the manifest predicts, `--verify` checks, `--why` explains the gap.**

### Why this exists here and not elsewhere

Not because the idea is clever — because the memory model is inferred rather than declared.

In a language where you write `Box`, `Rc`, or `let` versus `var`, the compiler has nothing
to explain: the placement is in your source, and a tool that told you "this is on the heap
because you wrote `Box::new`" would be reading your code back to you. Ownership errors are
worth explaining there, and `rustc` explains them well; placement is not a question anyone
has.

Prismio moved that decision into the compiler, which creates the obligation to answer for
it. `--why` exists because "the analysis put this on the heap" is not an acceptable answer
on its own. `--verify` exists because an inference that is merely *asserted* is a claim
about your program that nobody has checked. And the manifest is diffable — `tools/
aif_manifest_diff.py old new --compiler build/prismio` prints a minimal cause under every
regression, so "this change made 40 sites fall out of T1" is a build failure with a reason
attached rather than a performance mystery three weeks later.

---

## Which tool answers which question

| Question | Tool |
|---|---|
| What is in this variable, here, now? | `-g` and lldb/gdb |
| Where did it crash? | `-g` — stack traces need nothing else |
| Which field is at which offset? | `-g` — the offsets are the emitted ones, permutations and splits included |
| Where does this allocation live? | `prismio aif x.psm` |
| How does this program's memory behave overall? | `prismio aif x.psm --summary` |
| Why is *this* site on the heap? | `prismio aif x.psm --why=<symbol>` |
| What would move it? | the same — `--why` ranks the repairs and rejects the false ones |
| Did any of that actually hold? | `prismio build x.psm --verify`, then run it |
| Did my change make it worse? | `tools/aif_manifest_diff.py old new --compiler <prismio>` |
| Why is this struct laid out this way? | `prismio aif x.psm --layout` |

`--verify` is slower and heavier by design; it is a mode for CI and for a bad afternoon,
not a default. `-g` is a normal thing to leave on during development, at the cost of the
`-O0` object step.

---

## See also

- `aif/spec/SPEC.md` — the memory model the manifest reports on; §5.4 for `pin`, §6.3 for
  minimal cause, §7.3 for `--verify`.
- `aif/implementation/COMPILER-AUDIT.md` — what each level does and does not close.
- `runtime/llvm-api-backend.c`, the "Debug information (DWARF)" section — every honest
  omission listed above, at the code that makes it.
- `src/ir/debug.psm` — the frontend half, and the one place the "no wrong location" rule is
  written down.
