#!/usr/bin/env python3
"""INFERENCE 9's required test: an incremental result must equal a cold one.

    python3 tools/incremental_manifest.py --compiler build/<gen>

INFERENCE 9 permits an implementation to reuse per-function inference summaries
across a rebuild, and then says an implementation SHOULD verify that doing so
changes no answer, "because summary-cache bugs are silent and produce wrong-tier
binaries rather than crashes". This is that check, and it is written to be
runnable before any summary cache exists -- because the compiler already carries
state across invocations that can leak into the analysis:

  * the workload profile, whose path LAYOUT 2.2 deliberately makes predictable
    and therefore shared between runs (`.prismio-<stem>-profile.txt`);
  * the toolchain object cache under $TMPDIR/prismio-objcache;
  * any `.prismio-*` build temporary a previous run left behind.

Both halves of every comparison use the same file, at the same path, with the
same text. The *only* difference is that the cold half deletes that state first.
A manifest that differs is therefore a manifest that depended on it.

Non-vacuity is asserted, not assumed. A compiler that emitted a constant
manifest would pass every equality check here, so the run fails unless the edit
series actually moves the manifest, and unless a deliberately truncated analysis
(`--budget=1`) differs from the converged one. An instrument that cannot tell
two answers apart has not agreed about anything.
"""

import argparse, os, shutil, subprocess, sys, tempfile

# The three sources below open with `import std.io` because std.io stopped being a
# prelude on 2026-08-21 and they print. Nothing calls this script, so all three
# went on failing to compile for two days without anyone seeing it -- the same
# break, on the same day, as the one in tools/verify_separation.*.
#
# Each entry is (name, source). The series is ordered: every step is applied to
# the same working file, and the last one returns to the first one's text. That
# last step is the one a cache that never invalidates fails -- the text is the
# base's, so the manifest must be the base's too.
BASE = """\
import std.io

struct Point { x: Int, y: Int }

fn make(a: Int) -> Point {
    let p = Point { x: a, y: a * 2 }
    return p
}

fn local(a: Int) -> Int {
    let p = Point { x: a, y: a }
    return p.x + p.y
}

fn main() -> Int {
    let mut total = 0
    let mut i = 0
    while (i < 4) {
        total = total + local(i)
        let m = make(i)
        total = total + m.x
        i = i + 1
    }
    println(total)
    return 0
}
"""

# `local`'s Point stops being scope-local: it is handed to a function that keeps
# it, so its escape rises and the tier with it. The edit is in `keep`, and the
# site whose tier moves is in `local` -- which is the whole point. A per-function
# cache that invalidated only the edited function would keep the stale answer.
ESCAPE = """\
import std.io

struct Point { x: Int, y: Int }

fn make(a: Int) -> Point {
    let p = Point { x: a, y: a * 2 }
    return p
}

fn keep(box: List<Point>, sink p: Point) {
    list_push(box, p)
}

fn local(a: Int, box: List<Point>) -> Int {
    let p = Point { x: a, y: a }
    let sum = p.x + p.y
    keep(box, p)
    return sum
}

fn main() -> Int {
    let mut total = 0
    let mut i = 0
    let box = list_new()
    while (i < 4) {
        total = total + local(i, box)
        let m = make(i)
        total = total + m.x
        i = i + 1
    }
    println(total)
    return 0
}
"""

# A `region` over the loop: placement moves, tiers may not.
REGION = """\
import std.io

struct Point { x: Int, y: Int }

fn make(a: Int) -> Point {
    let p = Point { x: a, y: a * 2 }
    return p
}

fn local(a: Int) -> Int {
    let p = Point { x: a, y: a }
    return p.x + p.y
}

fn main() -> Int {
    let mut total = 0
    region frame {
        let mut i = 0
        while (i < 4) {
            total = total + local(i)
            let m = make(i)
            total = total + m.x
            i = i + 1
        }
    }
    println(total)
    return 0
}
"""

SERIES = [
    ("base", BASE),
    ("escape", ESCAPE),
    ("region", REGION),
    ("back-to-base", BASE),
]


def wipe_state(workdir, cache_dir):
    """Everything the compiler may have left behind that a later run could read."""
    for name in os.listdir(workdir):
        if name.startswith(".prismio-"):
            path = os.path.join(workdir, name)
            shutil.rmtree(path, ignore_errors=True) if os.path.isdir(path) else os.remove(path)
    shutil.rmtree(cache_dir, ignore_errors=True)


def manifest(compiler, source, cache_dir, extra=None):
    env = dict(os.environ)
    env["PRISMIO_OBJ_CACHE_DIR"] = cache_dir
    cmd = [compiler, "aif", source, "--manifest"] + (extra or [])
    p = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if p.returncode != 0:
        print(p.stdout)
        print(p.stderr, file=sys.stderr)
        raise SystemExit("`%s` failed with %d" % (" ".join(cmd), p.returncode))
    return p.stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compiler", required=True)
    ap.add_argument("--keep", action="store_true", help="leave the working directory behind")
    args = ap.parse_args()

    compiler = os.path.abspath(args.compiler)
    workdir = tempfile.mkdtemp(prefix="prismio-incremental-")
    cache_dir = os.path.join(workdir, "objcache")
    source = os.path.join(workdir, "prog.psm")

    failures = 0
    seen = []

    print("comparing cold and incremental manifests over %d edits\n" % len(SERIES))
    for name, text in SERIES:
        # Incremental: apply the edit on top of whatever the previous steps left.
        with open(source, "w") as f:
            f.write(text)
        incremental = manifest(compiler, source, cache_dir)

        # Cold: same text, same path, nothing carried over.
        wipe_state(workdir, cache_dir)
        with open(source, "w") as f:
            f.write(text)
        cold = manifest(compiler, source, cache_dir)

        ok = incremental == cold
        failures += 0 if ok else 1
        print("  %-14s %s" % (name, "same" if ok else "DIFFERS"))
        if not ok:
            import difflib
            for line in list(difflib.unified_diff(cold.splitlines(), incremental.splitlines(),
                                                  "cold", "incremental", lineterm=""))[:40]:
                print("      " + line)
        seen.append(records(incremental))

    # --- the two non-vacuity checks ---------------------------------------
    print()
    distinct = len(set(seen))
    if distinct < 2:
        print("  NOT DISCRIMINATING: every edit produced the same records; the equality")
        print("                      above would hold for a compiler that ignored the source")
        failures += 1
    else:
        print("  discriminating: the %d edits produced %d distinct record sets" % (len(SERIES), distinct))

    if seen[0] != seen[-1]:
        print("  NOT REVERSIBLE: the last edit restores the first edit's text and did not")
        print("                  restore its records -- state accumulated across rebuilds")
        failures += 1
    else:
        print("  reversible: returning to the base text returns the base records")

    with open(source, "w") as f:
        f.write(BASE)
    wipe_state(workdir, cache_dir)
    converged = records(manifest(compiler, source, cache_dir))
    truncated = records(manifest(compiler, source, cache_dir, ["--budget=1"]))
    if converged == truncated:
        print("  NOT SENSITIVE: a 1-round analysis produced the same records as a converged")
        print("                 one, so this comparison cannot see a tier change at all")
        failures += 1
    else:
        print("  sensitive: a --budget=1 analysis differs from the converged one")

    if not args.keep:
        shutil.rmtree(workdir, ignore_errors=True)
    else:
        print("\nworking directory: %s" % workdir)

    print("\n%s" % ("FAILED (%d)" % failures if failures else "OK"))
    return 1 if failures else 0


def records(text):
    """The tier records only: the header carries a budget and a round count, and
    `--budget=1` is supposed to change those. What must not change is the answer."""
    out = []
    body = False
    for line in text.splitlines():
        if line.startswith("#"):
            body = True
            continue
        if body and line.strip():
            out.append(line.rstrip())
    return "\n".join(out)


if __name__ == "__main__":
    sys.exit(main())
