# v0.1 concurrency — the blocking typed `Channel<T>`, and g9's fifth arm

The runtime channel has existed since REQUIREMENTS 15 and had no type, no
ownership contract and no wrapper. `RUNTIME.md` listed `chan_new` and its six
siblings under *"not yet wrapped … `extern fn` at your own risk"*, and
`V0_1_FEATURES.md` §4 recorded the consequence: g9's hand-tuned arm was **not
writable**, because Prismio had no way to keep a task alive past its join.

This closes both. There is no executor, no future and no `await`: a send blocks
while the channel is full, a receive blocks until a message arrives or the
channel closes, and that is the whole surface.

## The surface

Seven compiler builtins, the same category `list_get` and `list_push` are in —
sema owns their types and codegen emits the existing C call by name.

| source | type | what it does |
|---|---|---|
| `chan_new(cap)` | `Channel<T>` | T from the annotation, as `list_new`'s is |
| `chan_send(c, v)` | `Int` | 1 delivered, 0 dropped because closed. **Moves `v`** |
| `chan_recv(c)` | `T?` | blocks; `none` once closed *and* drained |
| `chan_share(c)` | `Channel<T>` | the duplication, spelled out loud |
| `chan_close(c)` | `Void` | wakes every blocked party |
| `chan_len(c)` | `Int` | messages queued |
| `chan_free(c)` | `Void` | after close, after every join |

`Channel<T>` is `TypeKind.PTR` with a name and a child, exactly as `Task<R>` is:
the endpoint is an opaque word, every PTR arm in sema, AIF and codegen already
handles it, and a TypeKind of its own would have to be added to all of them to
arrive at the same behaviour. `typeEquals` gets the same clause `Task<R>` has, so
`let c: Channel<Job> = chan_new(4)` does not accept a `Channel<Answer>`, and
`typeSemKey` gets `chan:` so the type survives a binding.

**T must be reference-shaped.** The runtime moves one `void*` per message and the
receive answers `T?`, which REQUIREMENTS 4 defines for references only.

## The four rules, and where each is enforced

**1 · Ownership of a sent value.** `chan_send` moves. The receiver takes the
message out and owns it from then on, so the sender naming it again names memory
another thread may already have freed — a stronger reason than `list_push`'s,
where the list at least still exists. Enforced by `semaConsumeOperand` and by an
`AIF_FFI_CONSUME` contract. `neg_56_channel_send_moves.psm` is the negative half;
`test_96_channels.psm` is the positive one, without which it would pass with
channels removed from the language.

**2 · Shared endpoint lifetime.** `chan_share` is SPEC 11 item 10's
"syntactically identifiable event": every handle the language can name is affine,
so without it `spawn worker(c)` moves the endpoint away and the parent cannot
send through it again. It returns the same endpoint. It is not a second owner —
only the endpoint `chan_new` returned is freed.

**3 · Receive after close.** A receive drains what was queued before the close and
then answers `none`, for ever, rather than blocking. That is what ends a worker
loop without a sentinel message, and it is why the return is `T?`.

**4 · Destruction.** Close, then join, then free. The join is the synchronisation
edge that makes the free safe, and it is the same edge that keeps every element
count non-atomic.

## Three model changes the feature needed, each found by a failing check

**`chan_send` consumes, it does not retain.** The first model reused
`list_push`'s `RETAIN_IN`. A list releases its elements at teardown and a channel
does not, so every message landed under an owner that never released it: a
two-message program leaked both.

**A site whose static type is `T?` allocates a `T`.** `aif_is_struct("Job?")` is
0, so the received value's site was `opaque` kind and nothing released it.
Optionality is a state of the slot, not a kind of allocation — which is what
`typeIsMoveOnly` already says on the type side. Fixed in `aifNewSite`, the one
place a site's type is decided.

**A produced return that allocates *nothing here* is neither stack- nor
arena-placeable.** `chan_recv` hands back a block another thread made; T0 says
"lives in this frame" and an arena says "this region reclaims it", and both were
reached. A new fact, `foreign`, refuses each without claiming somebody else
performs the free — which is what `no_stack` would have said, and it bars the
scope release. Narrower than `produces` on purpose: `strConcat` produces *and*
allocates through `rt_alloc`, which an enclosing region really does serve, and
test_44 counts 209 arena objects that prove it. Declining those too cost 2.

The suite caught the second and third the way it is designed to:
`run_oracle_vocabulary_test` reported *"chan_recv: the compiler produces it,
aif.py does not know it"* before any of it could be believed.

## A data race in `--verify` itself

Two tasks allocating at once race the ledger's `malloc`ed hash chains. Three runs
of one `g9_tuned` binary, before the fix:

```
aif-verify: 17909 allocated, 18002 released, 0 leaked, 0 violation(s)
aif-verify: 17909 allocated, 18008 released, 0 leaked, 0 violation(s)
aif-verify: 17863 allocated, 18004 released, 0 leaked, 0 violation(s)
```

Both invariants held and neither count did, which is the shape of a data race and
not of a leak. The ledger now takes a lock — in `--verify` builds only, so a
released program pays nothing — and the threading macros moved to
`prismio_runtime.h` so there is one spelling of them. After:

```
aif-verify: 18013 allocated, 18013 released, 0 leaked, 0 violation(s)   (x3, identical)
```

## g9's fifth arm

`aif/evidence/xlang/prismio/g9_tuned.psm` is `g9_tuned.rs`'s architecture line for
line: one job channel per worker, one shared result channel because the four
results are summed, four workers created **once** before the loop and joined once
after it. The per-frame cost is four sends and four receives instead of four
`pthread_create`/`pthread_join` pairs. Kernel, constants and checksums are
`g9.psm`'s unchanged — `checksum total 1856014121`, `checksum last 1579165008`.

25 runs per arm, cyclic rotation, `tools/five_arm_bench.py`. Raw:
[`xlang/results-g9-channels-five-arm.json`](xlang/results-g9-channels-five-arm.json).

| arm | loop ms | vs Rust idiomatic |
|---|---:|---:|
| Prismio | 103.027 | 0.90x |
| **Prismio hand-tuned** | **82.034** | **0.72x** |
| Rust idiomatic | 114.459 | 1.00x |
| Rust hand-tuned | 71.270 | 0.62x |

**Prismio hand-tuned against Rust hand-tuned is 1.15x**, and that is the number
V0_1_FEATURES.md §4 said would be re-measured. The 1.45x it replaces was
Prismio's *idiomatic* arm against Rust's tuned one — the only comparison
available while the arm could not be written. Prismio's own tuning is worth
**0.80x**, against the 0.62x Rust's is worth on the same program.

Idiomatic g9 keeps its per-frame spawn, deliberately: it is `g9_idiomatic.rs`'s
peer and the program exists to price task creation.

## Gate

- suite **201/201** (`test_96_channels`, `neg_56_channel_send_moves` are new);
- two generations reach a byte-identical compiler IR fixpoint;
- AIF oracle agrees on **19/19** sources — `test_96_channels.psm` is now one of
  them, for the reason `test_56_list_capacity.psm` is: a builtin's contract lives
  only in the two fallback tables, so nothing else can catch an omission. Adding
  it exposed a real pre-existing gap, `expect` missing from the oracle's alias
  table, which is now fixed;
- corpus 30/30 build and run;
- `--verify` on `test_96_channels`: 14/14, 0 leaked, 0 violations. On `g9_tuned`:
  18013/18013, 0 leaked, 0 violations, identical across runs;
- both clean under **AddressSanitizer** and under **ThreadSanitizer**;
- **141 existing programs emit byte-identical IR** against the pre-channel
  compiler, so this is additive: no existing program's codegen moved.

## Commands

```bash
cd tests && PRISMIO=../build/v0.1-rc python3 test_runner.py
python3 tools/aif_differential.py --compiler build/v0.1-rc
./build/v0.1-rc build tests/test_96_channels.psm --verify -o /tmp/ch && /tmp/ch
./build/v0.1-rc build aif/evidence/xlang/prismio/g9_tuned.psm --verify -o /tmp/g9t && /tmp/g9t
./build/v0.1-rc build aif/evidence/xlang/prismio/g9_tuned.psm -o /tmp/g9t.ll
clang -fsanitize=thread -g -O1 -o /tmp/g9t-tsan /tmp/g9t.ll \
    runtime/lang_runtime.c runtime/program_support.c -I runtime && /tmp/g9t-tsan
python3 tools/five_arm_bench.py --old build/tbaa3 --new build/v0.1-rc --only g9 --runs 25 \
    --json aif/evidence/xlang/results-g9-channels-five-arm.json
```
