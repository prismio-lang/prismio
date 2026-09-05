#!/usr/bin/env python3
"""Investigation-only clang shim: retain the exact IR passed to native codegen.

Symlink this as clang on a temporary PATH. Set MEMORY_CAPTURE_DIR and
MEMORY_REAL_CLANG. The normal invocation runs unchanged; supplementary outputs
are diagnostic and are not linked into the measured executable.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

args = sys.argv[1:]
real = os.environ["MEMORY_REAL_CLANG"]
dest = Path(os.environ["MEMORY_CAPTURE_DIR"])
inputs = [Path(a) for a in args if a.endswith(".ll") and Path(a).is_file()]
if "-c" in args and inputs:
    dest.mkdir(parents=True, exist_ok=True)
    source = inputs[0]
    shutil.copy2(source, dest / "merged.ll")
    (dest / "clang-command.json").write_text(json.dumps([real, *args], indent=2) + "\n")
    result = subprocess.run([real, *args])
    if result.returncode:
        sys.exit(result.returncode)
    base = list(args)
    at = base.index("-o")
    del base[at:at + 2]
    base.remove("-c")
    for extra, name in [(["-S", "-emit-llvm"], "optimized.ll"),
                        (["-S", "-Rpass=loop-vectorize", "-Rpass-missed=loop-vectorize",
                          "-Rpass-analysis=loop-vectorize"], "program.s")]:
        with (dest / (name + ".remarks.txt")).open("w") as log:
            p = subprocess.run([real, *base, *extra, "-o", str(dest / name)],
                               stdout=log, stderr=log)
            if p.returncode:
                sys.exit(p.returncode)
    sys.exit(0)
os.execv(real, [real, *args])
