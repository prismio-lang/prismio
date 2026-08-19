#!/usr/bin/env python3
"""Compare two IR snapshot trees, tolerating a global renumbering of slot names.

`%name.N` is the LLVM-level name of a stack slot; N comes from a per-module
serial. A change that alters how many serials are consumed renames every slot in
the module without changing an instruction, and that is what this reports
separately from a real difference.

Two checks, because the first alone would hide the failure that matters. A bug
that made two distinct bindings share one slot -- the exact defect the interning
comment in ir_symbols.c records -- collapses two names into one, so the count of
distinct slot names is compared as well as the normalised text.
"""
import re, sys, os

SLOT = re.compile(r"%([A-Za-z_][A-Za-z0-9_]*)\.(\d+)\b")

def normalise(text):
    return SLOT.sub(lambda m: "%" + m.group(1) + ".#", text)

def slot_names(text):
    return set(m.group(0) for m in SLOT.finditer(text))

def main(a, b):
    names = sorted(set(os.listdir(a)) | set(os.listdir(b)))
    identical = renamed = differ = missing = 0
    for n in names:
        pa, pb = os.path.join(a, n), os.path.join(b, n)
        if not (os.path.exists(pa) and os.path.exists(pb)):
            print("MISSING  %s" % n); missing += 1; continue
        ta, tb = open(pa).read(), open(pb).read()
        if ta == tb:
            identical += 1
            continue
        na, nb = normalise(ta), normalise(tb)
        ca, cb = len(slot_names(ta)), len(slot_names(tb))
        if na == nb and ca == cb:
            renamed += 1
        else:
            why = []
            if na != nb: why.append("text differs after normalising slot serials")
            if ca != cb: why.append("distinct slot names %d -> %d" % (ca, cb))
            print("DIFFER   %s  (%s)" % (n, "; ".join(why)))
            differ += 1
    print("\n%d identical, %d slot-renumbered only, %d really differ, %d missing"
          % (identical, renamed, differ, missing))
    return 1 if (differ or missing) else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
