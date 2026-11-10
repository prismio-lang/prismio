#!/usr/bin/env python3
"""The smoke test a release artifact has to pass: the packaged compiler, moved away from the
checkout, building a program that is not in the checkout either, and running it.

    python3 tools/smoke_package.py --dist dist/Prismio

Run from the repository root the tree would supply whatever the package forgot, so the toolchain
is copied to a scratch directory and the program built there. It lives in a script, not in the CI
workflow, because the program is source code: it named `Map` for a week after the rename to
`HashMap` and nothing but a CI run noticed, since `prismio gate` did not run it. Both do now.
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROGRAM = """\
import std.io
import std.vec
import std.map
import std.option

struct Note { id: Int }

fn main() -> Int {
    let mut ids: Vec<Int> = []
    ids.push(3)
    ids.push(1)
    ids.push(2)
    ids.sort()

    let m: HashMap<Int, Int> = mapNew<Int, Int>()
    mapSet(m, ids[0], 10)

    let c = Channel<Note>(2)
    c.send(Note { id: 7 })
    c.close()
    let taken = c.receive()
    let mut got = 0
    if (taken != none) {
        let note = expect(taken)
        got = note.id
    }
    c.free()

    println(ids[0] + mapGetOr(m, 1, 0) + got)
    return 0
}
"""

EXPECTED = "18"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--dist", required=True, help="a packaged toolchain directory (bin/, lib/, stdlib/)")
    args = parser.parse_args()
    exe = ".exe" if sys.platform == "win32" else ""
    dist = Path(args.dist).resolve()
    with tempfile.TemporaryDirectory(prefix="prismio-smoke-") as scratch:
        root = Path(scratch)
        toolchain = root / "toolchain"
        shutil.copytree(dist, toolchain, symlinks=True)
        (root / "smoke.psm").write_text(PROGRAM)
        built = subprocess.run([str(toolchain / "bin" / ("prismio" + exe)), "build", "smoke.psm",
                                "-o", "smoke" + exe], cwd=root, capture_output=True, text=True)
        if built.returncode != 0:
            print("smoke: the packaged compiler could not build the program\n"
                  + (built.stdout + built.stderr).strip(), file=sys.stderr)
            return 1
        ran = subprocess.run([str(root / ("smoke" + exe))], cwd=root, capture_output=True, text=True)
        output = ran.stdout.strip()
        print("smoke output: " + output)
        if ran.returncode != 0 or output != EXPECTED:
            print("smoke: expected {} and exit 0, got {!r} and exit {}".format(EXPECTED, output, ran.returncode),
                  file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
