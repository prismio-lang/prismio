# Prismio in the Linux kernel: benchmarks

Two kernel functions ported to Prismio and run inside a Linux kernel, each checked
against the kernel's own implementation and timed against it. Measured 2026-10-08.
The modules are `samples/prismio/prismio_glob.psm` and
`samples/prismio/prismio_crc32_main.psm` in the Linux tree; the missing features
they ran into are in [LINUX_PLAN.md](LINUX_PLAN.md).

## Setup

| | |
|---|---|
| Kernel | Linux 7.3-rc6, arm64, `allnoconfig` plus a PL011 console, initramfs, modules and the three samples |
| Machine | QEMU 11.1.1 on an Apple M5, `-accel hvf -cpu host -smp 2`, so the guest runs on the real core |
| C arm | the kernel's compiler, gcc 15.2.0 (`aarch64-linux-gnu`), the kernel's flags, `-O2` |
| Prismio arm | the freestanding compiler writes IR (`--freestanding --target aarch64-unknown-linux-gnu`), clang 23.1.1 `-O2` lowers it |
| Timer | `ktime_get()` around each run; each figure is the best of 7 runs inside the module |
| Repeats | six loads of each module (one, then five more); the tables give the median |

Prismio code is built without FP/SIMD (`-neon,-fp-armv8`) and with x18 reserved, as the
kernel's C code is. Inputs reach the code under test through memory and a volatile load, so
neither side can be hoisted out of the loop; the C and Prismio arms use the same harness.

## Correctness

Each module refuses to run its benchmark unless it first agrees with the kernel.

- **glob**: all 64 cases of `lib/tests/glob_kunit.c`, plus 8 more (escapes, an unclosed
  class, a leading `]`, a range followed by a dash), through both implementations.
  Every case gives the same answer in both, and the one expectation that was wrong
  (`[a-c-e]` against `-`) was wrong in the test, not in either implementation.
- **CRC-32**: every length 0 to 160 from every start offset 0 to 7 (1,288 cases), three
  ways: `crc32_le()`, the C slicing-by-8, and the Prismio slicing-by-8. All agree.

## Results

### `glob_match` (eight pattern and string pairs, backtracking-heavy)

| | ns per call | vs C |
|---|---|---|
| C (`lib/glob.c`) | 13.0 | 1.00 |
| Prismio | 13.9 | **1.06x slower (median)** |

Six runs gave 1.16, 1.09, 1.05, 1.07, 1.02 and 0.86 times the C time. The spread is the
noise of a guest on a shared host, so read it as "within about 10% of gcc", not as a
ranking. The two inner loops are structurally the same: both call the matcher
out of line with a null end pointer. gcc folds the `end` test into compare-conditional
instructions; clang leaves a branch around the load. That is the only difference found.

### CRC-32, reflected 0xEDB88320, slicing by 8 (MB/s, higher is better)

| Block | Kernel `crc32_le` (hardware) | C slicing-by-8 | Prismio slicing-by-8 | Prismio / C |
|---|---|---|---|---|
| 64 B | 9,800 | 2,640 | 2,850 | **1.08x** |
| 4 KiB | 34,400 | 2,660 | 2,990 | **1.12x** |
| 64 KiB | 34,300 | 2,610 | 2,930 | **1.12x** |

Prismio's software CRC is 8 to 12 percent faster than the same algorithm in gcc's C, in
all six runs. The kernel's own `crc32_le` is twelve times faster than either, because
on this CPU it uses the `crc32` instructions. Prismio cannot emit those yet (inline
assembly takes one operand), so that gap is a missing feature, not a code-generation
result.

## Reproduce

```bash
# in the Linux tree, with prismio and clang on PATH:
make ARCH=arm64 allnoconfig
scripts/config -e MODULES -e BLK_DEV_INITRD -e TTY -e SERIAL_AMBA_PL011 \
  -e SERIAL_AMBA_PL011_CONSOLE -e DEVTMPFS -e PRISMIO -e SAMPLES -e SAMPLES_PRISMIO \
  -m SAMPLE_PRISMIO_GLOB -m SAMPLE_PRISMIO_CRC32
make ARCH=arm64 olddefconfig && make ARCH=arm64 -j"$(nproc)" Image modules
# then boot Image under QEMU with an initramfs whose /init runs
#   insmod prismio_glob.ko; rmmod prismio_glob; insmod prismio_crc32.ko; rmmod prismio_crc32
# and read the "prismio_glob:" and "prismio_crc32:" lines from the console.
```

## What this does not show

- One machine, one CPU, a guest under HVF: not a bare-metal result.
- Two functions. Both are byte and word loops with no allocation, which is where the
  freestanding benchmarks already showed parity with C; they say nothing about code
  that is struct- or pointer-heavy.
- glob is the one to repeat on quieter hardware before quoting a ratio.
