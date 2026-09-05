#!/bin/sh
# The ablations that priced the two open levers. Each is one sed over ceiling.c.
#
# The numbers below each arm are SINGLE COLD RUNS and are 2-3x the medians quoted
# in RESULTS-adaptive-map-hash.md, which came from 21-25 interleaved samples with
# the arms shuffled. Use these to confirm the shape reproduces, then measure
# properly before believing a ratio.
set -e
D="$(dirname "$0")"
# Inlining: 3.573 all inlined / 5.809 im_set out / 6.637 im_probe out / 9.269 all out
sed 's/^static int im_set/__attribute__((noinline)) static int im_set/' "$D/ceiling.c" > /tmp/c_setout.c
sed 's/^static int im_probe/__attribute__((noinline)) static int im_probe/' "$D/ceiling.c" > /tmp/c_probeout.c
sed -e 's/^static int im_probe/__attribute__((noinline)) static int im_probe/' \
    -e 's/^static int im_set/__attribute__((noinline)) static int im_set/' \
    -e 's/^static int im_get_or/__attribute__((noinline)) static int im_get_or/' "$D/ceiling.c" > /tmp/c_allout.c
# Frame vs heap: 3.256 stack / 5.660 heap. The RUN macro holds the map by value;
# this gives it a malloc'd pointer instead, which is what Prismio's Map is.
python3 - "$D/ceiling.c" > /tmp/c_heap.c <<'PY'
import sys, re
s = open(sys.argv[1]).read()
s = s.replace('TYPE m; INIT(&m);', 'TYPE *mp = malloc(sizeof(TYPE)); INIT(mp);')
s = re.sub(r'\b(SET|GETOR)\(&m,', r'\1(mp,', s)
sys.stdout.write(s)
PY
for v in c_setout c_probeout c_allout c_heap; do
    clang -O3 -std=c11 "/tmp/$v.c" -o "/tmp/$v"
    printf '%-12s ' "$v"; "/tmp/$v" index
done
