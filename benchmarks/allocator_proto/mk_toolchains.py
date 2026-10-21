#!/usr/bin/env python3
"""Build the scratch toolchains the allocator A/B compares.

    python3 benchmarks/allocator_proto/mk_toolchains.py <scratch-dir>

Each `<scratch>/tcN/` is a copy of the project toolchain (`.prismio/build`) whose
`lib/runtime/lang_runtime.bc` is rebuilt from the working tree with a different
`-DPRISMIO_ALLOC_MODE`:

    tc0  0  the recycler, as it is today
    tc1  1  the recycler with its cap lifted            (option b, honest)
    tc2  2  the address-range slab                      (option a)
    tc3  3  a size-header recycler                      (option b, ceiling; unsound by design)
    tc4  2 + PRISMIO_SLAB_INLINE
    tc5  2 + SLAB_STAGGER=0   (the aliasing control)
    tc6  2 + SLAB_SPANS       (64 KiB spans and a class table: the production layout)

`bin/pgen` is the project's debug compiler: it is not named `prismio`, so it is not a
launcher. Run it with PRISMIO_INTERNAL_HOSTED=1, from a directory outside the checkout
unless the runtime.hash written here matches the sources (it does, until runtime/ changes).
"""
import os, shutil, subprocess, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
scratch = Path(sys.argv[1]).resolve()
scratch.mkdir(parents=True, exist_ok=True)
build = REPO / ".prismio" / "build"
host = build / "debug" / "prismio"
MODES = {0: ["-DPRISMIO_ALLOC_MODE=0"], 1: ["-DPRISMIO_ALLOC_MODE=1"], 2: ["-DPRISMIO_ALLOC_MODE=2"],
         3: ["-DPRISMIO_ALLOC_MODE=3"], 4: ["-DPRISMIO_ALLOC_MODE=2", "-DPRISMIO_SLAB_INLINE"],
         5: ["-DPRISMIO_ALLOC_MODE=2", "-DSLAB_STAGGER=0"], 6: ["-DPRISMIO_ALLOC_MODE=2", "-DSLAB_SPANS"]}
env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
triple = subprocess.run(["clang", "-print-target-triple"], capture_output=True, text=True).stdout.strip()
for n, flags in MODES.items():
    root = scratch / f"tc{n}"
    shutil.rmtree(root, ignore_errors=True)
    (root / "bin").mkdir(parents=True)
    shutil.copytree(build / "lib", root / "lib")
    (root / "stdlib").symlink_to(build / "stdlib")
    shutil.copy2(host, root / "bin" / "pgen")
    subprocess.run(["clang", f"--target={triple}", "-O2", "-fno-stack-check", "-fno-stack-protector",
                    "-ffile-compilation-dir=.", "-Wno-deprecated-declarations", "-emit-llvm", "-c", *flags,
                    str(REPO / "runtime" / "lang_runtime.c"), "-o", str(root / "lib/runtime/lang_runtime.bc")],
                   check=True)
    # The toolchain refuses a runtime whose recorded source hash is not the tree's.
    probe = subprocess.run([str(root / "bin" / "pgen"), "build", str(REPO / "tests/test_302_struct_in_two_vecs.psm"),
                            "-o", str(scratch / "probe")], capture_output=True, text=True, env=env, cwd=REPO)
    for line in probe.stderr.splitlines():
        if "now hash" in line:
            (root / "lib" / "runtime.hash").write_text(line.split()[-1])
    print("built", root)
