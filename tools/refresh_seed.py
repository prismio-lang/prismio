#!/usr/bin/env python3
"""Cut a bootstrap seed from a known-good compiler.

    python3 tools/refresh_seed.py --compiler build/gen2

Writes bootstrap/seed.ll. The seed is LLVM IR for src/main.psm and is the only way to
build a first compiler on a host that has none. The file is tracked, but **a refreshed
seed is not staged or committed until the maintainer says so** (.githooks/pre-commit
refuses it): at ~20 MB a commit per refresh would bloat the history. Cut a new one
whenever a language or codegen change would stop the committed seed from compiling the
current sources -- not on every commit, since a stale seed is harmless as long as the
compiler it produces can still build the tree.

Two things make the file portable, and both are enforced here:
  * the target triple and data layout are stripped, so clang targets whatever host it
    runs on;
  * the compiler supplied must already be at a gen1/gen2 fixed point, so the seed encodes
    a settled compiler rather than a half-migrated one. This is checked, not assumed: the
    compiler is required to reproduce its own IR.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from executable import resolve_executable

REPO = Path(__file__).resolve().parent.parent
WINDOWS = os.name == "nt"
GREEN = "" if WINDOWS else "\033[32m"
RED = "" if WINDOWS else "\033[31m"
RESET = "" if WINDOWS else "\033[0m"

HEADER = """\
; Prismio bootstrap seed -- LLVM IR for the Prismio compiler (src/main.psm).
;
; Committed because a new platform has no prismio binary to
; compile src/main.psm with, and this is the smallest artifact that breaks that
; cycle. Produced by a compiler that had reached a byte-identical gen1/gen2 fixed
; point.
;
; Deliberately carries no 'target triple' or 'target datalayout' line, so llc
; targets whatever host it runs on. That is safe here because the IR is entirely
; target-neutral: every function signature uses only i1/i8/i32/ptr/void, no struct
; is passed by value, and there are no byval/sret attributes or target intrinsics.
; The libc names that differ per platform -- errno's accessor, the console write,
; EAGAIN -- are calls to rt_seed_* in runtime/program_support.c (PRISMIO_SEED_IR).
;
; Rebuild with: tools/refresh_seed.py
;
"""


def die(message: str) -> None:
    print(f"{RED}FAILED: {message}{RESET}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="Cut a bootstrap seed from a known-good compiler.")
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--repo", default=str(REPO))
    args = parser.parse_args()
    repo = Path(args.repo).resolve()
    compiler = resolve_executable(args.compiler)

    work = repo / "build" / ".seed"
    work.mkdir(parents=True, exist_ok=True)
    (repo / "bootstrap").mkdir(exist_ok=True)
    raw, again = work / "seed-raw.ll", work / "seed-raw-2.ll"

    # The three libc names that differ per platform (errno's accessor, the console write,
    # EAGAIN) become calls into program_support.c, so the seed does not carry this host's
    # spelling of them. See errno_location_symbol in runtime/llvm-api-backend.c.
    env = dict(os.environ, PRISMIO_SEED_IR="1")

    # Built from the repository root with a relative path. The compiler records source
    # paths in the IR (the AIF profile keys), and an absolute one would put the refreshing
    # machine's checkout location in the seed.
    def build(target: Path, what: str) -> None:
        result = subprocess.run([str(compiler), "build", "src/main.psm", "-o", str(target)],
                                cwd=repo, env=env, capture_output=True)
        if result.returncode != 0 or not target.is_file():
            die(what)

    build(raw, "compiler could not build src/main.psm")
    # Fixed-point check: a compiler that does not reproduce its own IR is mid-migration,
    # and freezing that state into the seed would hand every new host a compiler that
    # disagrees with the one everyone else is running.
    build(again, "second build failed")
    if raw.read_bytes() != again.read_bytes():
        die("compiler is not deterministic")

    # Strip CR so a seed refreshed on a CRLF checkout matches one refreshed elsewhere, and
    # drop the target directives.
    lines = raw.read_bytes().decode("utf-8").replace("\r\n", "\n").split("\n")
    drop = re.compile(r"^target (triple|datalayout)\s*=")
    body = [line for line in lines if not drop.match(line)]
    seed = repo / "bootstrap" / "seed.ll"
    with open(seed, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(HEADER + "\n".join(body))
    shutil.rmtree(work, ignore_errors=True)

    print(f"{GREEN}Wrote {seed} ({seed.stat().st_size:,} bytes, "
          f"{len(lines) - len(body)} target directive(s) stripped){RESET}")
    print("Left uncommitted: a refreshed seed is committed only when the maintainer says so.")
    print("Verify with: python3 tools/bootstrap.py --seed --out build/seedcheck")


if __name__ == "__main__":
    main()
