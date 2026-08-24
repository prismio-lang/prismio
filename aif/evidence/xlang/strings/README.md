# Cross-language string microbenchmarks

This suite compares the same six allocation-and-scan workloads in Prismio,
C, Rust's standard library, and (for substring search) `memchr::memmem` 2.8.3.
Every timed loop mutates an input so the compiler cannot hoist the operation,
and the runner refuses to report variants whose checksums differ.

```bash
python3 aif/evidence/xlang/strings/run.py --compiler build/v21 --runs 5
```

Each binary times only its inner loop with `clock_gettime_nsec_np`; setup,
startup, and printing are outside the interval. The suite currently targets
macOS because that is the host on which Prismio's string performance record is
maintained.

The three search distributions matter:

- `search_rare`: a four-byte miss whose selected pair never occurs. This is the
  packed-pair SIMD throughput case.
- `search_dense`: the selected pair occurs every four bytes and full matches
  always fail. This drives the effectiveness guard into pure Two-Way search.
- `search_long`: a 40-byte miss whose pair is selective. This measures the
  packed-pair prefilter around Two-Way.

`concat` reads one byte from each input half of the result. Reading only the
first half lets C/Rust delete the second copy and produces an invalid comparison.
