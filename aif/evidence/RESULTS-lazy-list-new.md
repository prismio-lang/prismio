# `list_new` allocates nothing until the first push

**Status: GREEN but performance-NEUTRAL, 2026-08-30.** Compiler
`build/lazy-gen3`, LLVM 22.1.8 on Apple Silicon. Fixed point, suite **202/202**,
AIF differential **19/19**, `--verify` sweep clean, gate passed.

**Corpus median 1.000x. No program moved outside the A/A floor.** This is a
correctness-and-waste change, not a speedup, and the number below is the whole
reason it says so.

## The defect

`list_new()` called `list_new_cap(4)`, which allocated a **four-pointer** data
block. For the inline representation that block is the wrong width, so the first
push ran `list_set_elem_inline`, which freed it and allocated a body block in its
place:

```c
l->elem_size = elem_size;
if (!l->arena) rt_free(l->data);          // the block list_new just made
l->data = rt_alloc(l->cap * elem_size);   // the one it actually needed
```

So every inline list paid a malloc and a free of pure waste before doing any real
work.

Rust does not: [`RawVec::NEW`](https://rust-for-linux.github.io/docs/rust/src/alloc/raw_vec.rs.html)
is capacity 0 with a dangling pointer, and only `push` allocates. `list_new` now
does the same — capacity 0, `data` NULL — and both growth paths start at 4 when
they find capacity 0, so the sequence a list sees from its first push onwards is
unchanged.

## The measurement, and why it says nothing

Twenty-five interleaved runs against `build/ums-gen3`, with the A/A calibration
first, which is what makes the A/B readable:

```text
A/A  corpus median 0.998x   range 0.816 - 1.029x
A/B  corpus median 1.000x   range 0.857 - 1.065x
```

**Every A/B reading is inside the A/A envelope.** g5's 0.857x is on the same side
as, and smaller than, the A/A floor's 0.816x; g1's 1.065x and g4's 1.040x sit
against an A/A ceiling of 1.029x. Nothing here is a result.

An earlier seven-run median reported g6 at 0.968x and this file claimed 3.2%.
Re-running swapped the absolute values and gave 1.033x. **That was noise quoted
as a result**, and it is recorded here because the same seven-run shortcut is
what produced it.

## Why keep it

- It removes one `malloc` and one `free` per inline list. The allocator traffic
  is real even where the wall clock cannot see it — g6's ledger drops 46818 to
  45318 allocations.
- The invariant gets simpler: a list either has a block sized for its elements or
  has no block, instead of possibly having one sized for the wrong
  representation.
- `run_forced_layout_test`'s expected gap went from `bodies - 1` to `bodies`, and
  the `-1` in its docstring was described as "switching an empty boxed list to
  inline storage replaces its initial pointer block". The exception existed only
  to describe this waste; removing the waste removed the exception.

## Host noise, for whoever measures next

The A/A range on this host at this time was **0.816 to 1.029**. That is far wider
than the 1.03x corpus-median gate, and wide enough to manufacture a plausible
double-digit win or loss on a single program. Calibrate before believing
anything, and prefer `tools/fn_mnemonic_diff.py` — a program whose functions did
not change did not get faster.
