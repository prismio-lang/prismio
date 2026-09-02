# M2.1b — consuming same-tag rebuilds reuse their input block

**Status: LANDED, 2026-09-02.** This closes the 8,188-allocation residue left
after the recursive ownership fix. It was not another transfer defect:
`mapAdd(sink t, k)` destructured an owned `Tree.Node` and allocated a replacement
of the same representation without reclaiming the dead block. The workload was
written to measure exactly this pairing.

## Shape accepted

The first slice is deliberately narrow. A token is emitted only when all of the
following are proved:

1. the match scrutinee is a direct `sink` parameter of the current function;
2. the converged AIF parameter points-to set is non-empty, consuming, move-only,
   at most `Borrowed`, at most `Transferred`, non-foreign, and not stored in a
   container;
3. the arm consists of one direct return of the same enum representation and
   the same tag; and
4. every move-only payload binder is transferred into the returned constructor.

Sema stamps the exact identifier uses that perform a move. Statement lowering
uses those stamps to establish the arm-local pairing, then the struct-literal
lowering consumes the token: it writes the new fields into the matched block and
skips allocation and allocation profiling. Any failed or missing fact declines
to the ordinary constructor path.

The block may consequently be visible through both the consumed source binding
and its result binding on the conservative scope-drop list. Scope unwinding now
deduplicates pointer-valued drops by physical address, so the newer occurrence
performs the teardown and the older alias does not release it a second time.
This is intentionally an unwind rule, not a blanket suppression of moved
bindings: the latter was tested and regressed the existing recursive-field
release in `test_49`.

## Semantic fallback guard

`tests/test_100_reuse_token.psm` puts one `Tree` into two live lists, consumes a
view from one list through `mapAdd`, and observes both the original and returned
roots. The original remains `1` and the returned value becomes `11`. Mutating
the shared block in place would make the test fail; the query instead sees the
container/shared path and keeps the allocating constructor.

The test exits after that assertion because deliberately consuming a borrowed
container view reaches a separate, already-covered T3 teardown limitation. The
fixture's job is to discriminate reuse eligibility, not duplicate that ledger
test.

## Ledger result

Same source, depth 10, five rebuild passes, checksum `tree 528891` throughout:

| build | allocated | released | leaked | violations |
|---|---:|---:|---:|---:|
| before reuse | 12,284 | 4,096 | 8,188 | 0 |
| reuse token | 2,049 | 2,049 | **0** | 0 |

`test_74_reinit_assignment` moves from 255 / 162 / 93 to **69 / 69 / 0**.
The neighbouring ownership discriminators remain balanced:
`test_49` 3 / 3 / 0, `test_73` 50 / 50 / 0, and the cycle-collector fixture
`test_52` 12 / 12 / 0.

## Performance result

`aif/evidence/xlang/bench.py` now includes `g8_tree_rebuild` in `PROGRAMS`.
The standard harness was run 20 times per build on Apple arm64; this program has
one timed frame per process, so p50, p99 and p999 are the same sample statistic.
Allocator counts come from the harness's workload window and include runtime
allocations beyond AIF's typed-object ledger.

| build | p50 frame | spread | window allocs | process allocs/frees |
|---|---:|---:|---:|---:|
| before reuse | 189.92 us | 146.08–313.71 us | 12,539 | 12,542 / 4,173 |
| reuse token | **51.94 us** | 42.67–86.54 us | **2,304** | 2,307 / 2,126 |

That is **3.66x faster** at the median and **5.44x fewer** allocator calls in
the measured workload window. Executable size is unchanged at 79,848 bytes.

## Gates

- Generated compiler IR is byte-identical across the final two generations:
  `a4fa5091d43a1862693f85db36dd958e9f1ac3a61865fe6d74f14b8210b8b4d9`.
- AIF differential: **19 / 19** sources agree in both modes.
- Source-list agreement and the focused `--verify` sweep pass.
- On the 169-fixture snapshot used to build the fixpoint compiler, every file
  fixture passes. A later full invocation saw **218 / 224**: five generic-trait
  fixtures had appeared after that compiler was built and correctly exposed it
  as stale, while the remaining failure is the already-reproduced `rc_alloc`
  expectation from the overlapping uncommitted report/UMS work. All other 49
  special gates pass, including `aif_verify` and the packaged-runtime gate.

## Boundary retained

This is not a general reuse optimiser. Locals, tag changes, constructors nested
under other expressions, multi-statement arms, and tokens whose lifetime crosses
an arm boundary all decline. Extending any one of those shapes needs its own
liveness or representation proof; none is silently approximated here.
