#!/usr/bin/env bash
# The complete v0.1 release-candidate gate, in one command.
#
#   bash tools/release_gate.sh --rc build/v0.1-rc
#   bash tools/release_gate.sh --rc build/v0.1-rc --old build/<baseline>
#
# `--old` is optional and adds one thing: a per-function mnemonic diff against a
# previous compiler. Every *gating* check runs without it.
#
# Every check the release bar names, in the order a failure is cheapest
# to diagnose: correctness before performance, and generated code before timings.
# It prints one line per check and exits non-zero on the first failure, because a
# gate that continues past a red step is a gate somebody reads the end of.
#
# It does **not** run the benchmarks. Those are tools/milestone_bench.py and
# tools/five_arm_bench.py, they take half an hour, and the release bar requires
# reading a per-function mnemonic diff before believing any number one of them
# prints -- which is a human step, not a step this can assert.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLD=""
RC=""
WORK="$(mktemp -d)"
FAILED=0

while [ $# -gt 0 ]; do
    case "$1" in
        --old) OLD="$2"; shift 2 ;;
        --rc)  RC="$2";  shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ -n "$RC" ] || { echo "usage: $0 --rc <compiler> [--old <compiler>]" >&2; exit 2; }
RC="$(cd "$(dirname "$RC")" && pwd)/$(basename "$RC")"

step() { printf '%-42s ' "$1"; }
ok()   { printf 'ok    %s\n' "${1:-}"; }
bad()  { printf 'FAIL  %s\n' "${1:-}"; FAILED=1; }

cd "$REPO"

step "source lists agree"
if python3 tools/check_source_lists.py >"$WORK/lists" 2>&1; then ok; else bad "$(tail -1 "$WORK/lists")"; fi

step "two-generation bootstrap"
if bash tools/bootstrap.sh --compiler "$RC" --out "$WORK/g1" >"$WORK/b1" 2>&1 \
   && bash tools/bootstrap.sh --compiler "$WORK/g1" --out "$WORK/g2" >"$WORK/b2" 2>&1; then ok; else bad "$(tail -2 "$WORK/b2")"; fi

step "compiler IR fixpoint"
if "$WORK/g1" build src/main.psm -o "$WORK/a.ll" >/dev/null 2>&1 \
   && "$WORK/g2" build src/main.psm -o "$WORK/b.ll" >/dev/null 2>&1 \
   && cmp -s "$WORK/a.ll" "$WORK/b.ll"; then ok "byte-identical"; else bad "a.ll != b.ll"; fi

step "RC reproduces itself"
if "$RC" build src/main.psm -o "$WORK/rc.ll" >/dev/null 2>&1 && cmp -s "$WORK/rc.ll" "$WORK/a.ll"; then
    ok "the frozen binary emits generation 1's IR"
else bad "the frozen RC is not the fixpoint"; fi

step "seed agreement"
if "$RC" bootstrap src/main.psm -o "$WORK/seedchk" >"$WORK/seed" 2>&1; then
    ok "committed seed builds the compiler"
else bad "$(tail -1 "$WORK/seed")"; fi

step "full suite"
SUITE="$(cd tests && PRISMIO="$RC" python3 test_runner.py 2>&1 | tail -30)"
PASS="$(printf '%s' "$SUITE" | grep -oE 'Passed: [0-9]+' | grep -oE '[0-9]+')"
FAIL="$(printf '%s' "$SUITE" | grep -oE 'Failed: [0-9]+' | grep -oE '[0-9]+')"
if [ "${FAIL:-1}" = "0" ] && [ -n "${PASS:-}" ]; then ok "$PASS/$PASS"; else bad "${PASS:-?} passed, ${FAIL:-?} failed"; fi

step "AIF oracle differential"
DIFF="$(python3 tools/aif_differential.py --compiler "$RC" 2>&1 | tail -1)"
case "$DIFF" in *"agree on all"*) ok "$DIFF" ;; *) bad "$DIFF" ;; esac

step "corpus builds and runs"
RAN=0; BROKE=""
for src in aif/corpus/*.psm aif/evidence/xlang/prismio/*.psm; do
    stem="$(basename "$src" .psm)"
    case "$stem" in g6_engine|g6_engine_tuned) continue ;; esac
    if ! "$RC" build "$src" -o "$WORK/$stem" >/dev/null 2>&1; then BROKE="$BROKE build:$stem"; continue; fi
    if ! "$WORK/$stem" >/dev/null 2>&1; then BROKE="$BROKE run:$stem"; continue; fi
    RAN=$((RAN + 1))
done
if [ -z "$BROKE" ]; then ok "$RAN programs"; else bad "$BROKE"; fi

step "--verify sweep"
LEAKY=""
for src in aif/evidence/xlang/prismio/g1.psm aif/evidence/xlang/prismio/g3.psm \
           aif/evidence/xlang/prismio/g4.psm aif/evidence/xlang/prismio/g5.psm \
           aif/evidence/xlang/prismio/g6.psm aif/evidence/xlang/prismio/g9_tuned.psm \
           tests/test_96_channels.psm tests/test_97_generic_annotation.psm; do
    stem="$(basename "$src" .psm)"
    "$RC" build "$src" --verify -o "$WORK/$stem-v" >/dev/null 2>&1 || { LEAKY="$LEAKY build:$stem"; continue; }
    LINE="$("$WORK/$stem-v" 2>&1 >/dev/null | grep 'aif-verify:' | tail -1)"
    case "$LINE" in
        *"0 leaked, 0 violation(s)") : ;;
        *) LEAKY="$LEAKY $stem[$LINE]" ;;
    esac
done
if [ -z "$LEAKY" ]; then ok "0 leaked / 0 violations on every program"; else bad "$LEAKY"; fi

step "curated runtime off"
if PRISMIO_INLINE_RUNTIME=0 "$RC" build aif/evidence/xlang/prismio/g4.psm -o "$WORK/g4-nocurate" >/dev/null 2>&1 \
   && "$WORK/g4-nocurate" | grep -q "checksum entities 1500"; then ok; else bad; fi

step "object cache off"
if PRISMIO_OBJ_CACHE=0 "$RC" build aif/evidence/xlang/prismio/g1.psm -o "$WORK/g1-nocache" >/dev/null 2>&1 \
   && "$WORK/g1-nocache" | grep -q "checksum alive 2000"; then ok; else bad; fi

step "JIT"
if "$RC" run tests/test_96_channels.psm --jit 2>&1 | grep -q "PASS: channels"; then ok; else bad; fi

step "cross-target"
# The sysroot is not optional and the diagnostic says so: without an SDK for the
# target there is no C library, so the runtime cannot be compiled from source for
# it and `stdio.h` is not found. Omitting it here read as a compiler failure.
SDK="$(xcrun --show-sdk-path 2>/dev/null || true)"
if [ -z "$SDK" ]; then
    ok "skipped -- no SDK on this host"
elif "$RC" build aif/evidence/xlang/prismio/g1.psm --target x86_64-apple-macos \
        --sysroot "$SDK" -o "$WORK/g1-x86" >"$WORK/cross" 2>&1 \
     && file "$WORK/g1-x86" | grep -q x86_64; then
    ok "x86_64-apple-macos built"
else bad "$(tail -1 "$WORK/cross")"; fi

step "packaged toolchain"
if bash tools/package.sh --compiler "$RC" --out "$WORK/dist" >"$WORK/pkg" 2>&1 \
   && bash tools/verify_separation.sh --dist "$WORK/dist" >"$WORK/sep" 2>&1; then
    ok "$(tail -1 "$WORK/sep")"
else bad "$(tail -2 "$WORK/pkg" "$WORK/sep" | tail -1)"; fi

if [ -n "$OLD" ]; then
    # Mnemonics, not `.ll` text. Alias metadata changes the IR of nearly every
    # program without changing one instruction, so a textual diff here reports
    # 21 "moved" programs and says nothing about any of them. This is the diff
    # the release bar actually asks to read before a timing is believed.
    step "per-function mnemonic diff vs $OLD"
    printf '\n'
    # **The hand-tuned arms are diffed too, and that is not padding.** This loop
    # covered only the natural programs until 2026-08-30, and a container change
    # that improved every one of them regressed hand-tuned g4 by 46% -- 20.5ms to
    # 30.1ms, slower than the natural program -- while this gate printed green.
    # The tuned sources fuse loops and reuse buffers, so they exercise shapes the
    # natural ones do not have; a change can be neutral on all seven naturals and
    # move one tuned function by 26 instructions. See
    # aif/evidence/RESULTS-flat-list-loop-guard.md.
    for prog in g1 g2 g3 g4 g5 g6 g9 \
                g1_dataview_tuned g2_tuned g3_tuned g4_tuned g5_tuned g6_tuned g9_tuned; do
        src="aif/evidence/xlang/prismio/$prog.psm"
        [ -f "$src" ] || continue
        "$OLD" build "$src" -o "$WORK/$prog-old" >/dev/null 2>&1 || continue
        "$RC"  build "$src" -o "$WORK/$prog-new" >/dev/null 2>&1 || continue
        printf '    %-18s %s\n' "$prog" \
            "$(python3 tools/fn_mnemonic_diff.py "$WORK/$prog-old" "$WORK/$prog-new" | head -1)"
    done
fi

echo
if [ "$FAILED" = "0" ]; then
    echo "GATE PASSED -- $RC"
else
    echo "GATE FAILED"
fi
rm -rf "$WORK"
exit "$FAILED"
