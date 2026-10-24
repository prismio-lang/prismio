#!/usr/bin/env python3
"""Build the scratch toolchains the allocator A/B compares.

    python3 benchmarks/allocator_proto/mk_toolchains.py <scratch-dir>

Each `<scratch>/tcN/` is a copy of the project toolchain (`.prismio/build`) whose
`lib/runtime/lang_runtime.bc` is rebuilt from the working tree with different flags:

    tc0  the runtime as it ships: the slab on 64-bit POSIX
    tc5  -DSLAB_STAGGER=0   (the aliasing control)

The prototype's other variants (the recycler, its lifted cap, a size header, the
region-per-class layout, inlined entry points) were deleted when the slab became the
default; their numbers are in docs/ALLOCATOR_PLAN.md and their code in Git history.

    python3 benchmarks/allocator_proto/mk_toolchains.py <scratch-dir> [--compiler PATH] [--only 2,6]

`bin/pgen` is the project's debug compiler unless `--compiler` names another (a bare
generation from tools/bootstrap.py, say one built with the slab as its default); it is
not named `prismio`, so it is not a launcher. Run it with PRISMIO_INTERNAL_HOSTED=1, from a directory outside the checkout
unless the runtime.hash written here matches the sources (it does, until runtime/ changes).
"""
import argparse, os, shutil, subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
build = REPO / ".prismio" / "build"
parser = argparse.ArgumentParser()
parser.add_argument("scratch")
parser.add_argument("--compiler", default=str(build / "debug" / "prismio"))
parser.add_argument("--only", help="comma-separated toolchain numbers")
cli = parser.parse_args()
scratch = Path(cli.scratch).resolve()
scratch.mkdir(parents=True, exist_ok=True)
host = Path(cli.compiler).resolve()
MODES = {0: [], 5: ["-DSLAB_STAGGER=0"]}
env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
triple = subprocess.run(["clang", "-print-target-triple"], capture_output=True, text=True).stdout.strip()
only = {int(x) for x in cli.only.split(",")} if cli.only else set(MODES)
for n, flags in MODES.items():
    if n not in only:
        continue
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
