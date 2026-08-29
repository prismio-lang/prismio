#!/usr/bin/env python3
"""Per-function mnemonic diff of two linked binaries, via objdump -d.

    python3 tools/fn_mnemonic_diff.py old new          # what changed
    python3 tools/fn_mnemonic_diff.py --text old new cull   # and how

**Read this before believing a timing.** V0_1_FEATURES.md 2.2 requires it, and
the reason is on record twice. Both benchmark harnesses have reported a g5
regression that was not real -- an A/A calibration of one binary against itself
spans 1.93x on that program -- and M6 slice 2's g2 regression *was* real and was
one function out of 187. Neither question is answerable from a number; both are
answerable in seconds from this.

A `.ll` or binary comparison is the wrong instrument for the same reason: alias
metadata changes the IR of nearly every program without changing one instruction,
so a textual diff reports everything and distinguishes nothing.

Two modes. The default compares the **mnemonic sequence**, which ignores the
branch and literal addresses that shift when anything earlier in the binary moves
-- that is what makes "0 changed" mean "this program is untouched". `--text`
compares the full instruction text with absolute addresses canonicalised, and
takes a third argument naming a function to print a unified diff of.
"""
import subprocess, sys, re, collections, difflib

MODE_TEXT = "--text" in sys.argv
args = [a for a in sys.argv[1:] if not a.startswith("--")]

def funcs(path):
    out = subprocess.run(["objdump","-d","--no-show-raw-insn",path],
                         capture_output=True, text=True).stdout
    cur, d = None, collections.OrderedDict()
    for line in out.splitlines():
        m = re.match(r'^[0-9a-f]+\s+<(.+)>:$', line.strip())
        if m:
            cur = m.group(1); d[cur] = []; continue
        if cur is None: continue
        m = re.match(r'^\s*[0-9a-f]+:\s+(.*)$', line)
        if m:
            t = m.group(1).strip()
            t = re.sub(r'\s+', ' ', t)
            if MODE_TEXT:
                # canonicalise branch targets: keep the symbol, drop the address
                t = re.sub(r'\b0x[0-9a-f]+ <([^>]+)>', r'<\1>', t)
                t = re.sub(r'<([^>+]+)\+0x[0-9a-f]+>', r'<\1+N>', t)
                t = re.sub(r'\b0x[0-9a-f]{5,}\b', 'ADDR', t)
            else:
                t = t.split(' ')[0]
            d[cur].append(t)
    return d

a, b = funcs(args[0]), funcs(args[1])
onlya = [k for k in a if k not in b]
onlyb = [k for k in b if k not in a]
changed = [k for k in a if k in b and a[k] != b[k]]
print(f"mode={'text' if MODE_TEXT else 'mnemonic'} functions: old={len(a)} new={len(b)} "
      f"only_old={len(onlya)} only_new={len(onlyb)} changed={len(changed)}")
for k in onlya: print("  ONLY OLD:", k)
for k in onlyb: print("  ONLY NEW:", k)
for k in changed:
    print(f"  CHANGED: {k}  {len(a[k])} -> {len(b[k])} insns")
if len(args) > 2:
    want = args[2]
    for k in changed:
        if want in k:
            print(f"\n===== {k} =====")
            for l in difflib.unified_diff(a[k], b[k], "old", "new", lineterm="", n=8):
                print(l)
