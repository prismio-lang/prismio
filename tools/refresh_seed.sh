#!/usr/bin/env bash
# Regenerate bootstrap/prismio-seed.ll from a known-good compiler.
#
#   tools/refresh_seed.sh --compiler build/gen2
#
# POSIX counterpart of tools/refresh_seed.ps1. See that file for why the seed
# exists and when to refresh it; the two must stay in step, since either platform
# can be the one that regenerates the committed seed.

set -eu

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILER=""

while [ $# -gt 0 ]; do
    case "$1" in
        --compiler) COMPILER="$2"; shift 2 ;;
        --repo)     REPO="$2";     shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ -n "$COMPILER" ] || { echo "usage: $0 --compiler <prismio> [--repo <dir>]" >&2; exit 2; }

WORK="$REPO/build/.seed"
mkdir -p "$WORK" "$REPO/bootstrap"
RAW="$WORK/seed-raw.ll"
AGAIN="$WORK/seed-raw-2.ll"

die() { printf '\033[31mFAILED: %s\033[0m\n' "$1" >&2; exit 1; }

"$COMPILER" build "$REPO/src/main.psm" -o "$RAW" >/dev/null || die "compiler could not build src/main.psm"
[ -f "$RAW" ] || die "no IR produced"

# Fixed-point check: a compiler that does not reproduce its own IR is mid-migration,
# and freezing that state into the seed would hand every new host a compiler that
# disagrees with the one everyone else is running.
"$COMPILER" build "$REPO/src/main.psm" -o "$AGAIN" >/dev/null || die "second build failed"
cmp -s "$RAW" "$AGAIN" || die "compiler is not deterministic"

SEED="$REPO/bootstrap/prismio-seed.ll"
cat > "$SEED" <<'EOF'
; Prismio bootstrap seed -- LLVM IR for the Prismio compiler (src/main.psm).
;
; Committed because a new platform has no prismio binary to compile src/main.psm
; with, and this is the smallest artifact that breaks that cycle. Produced by a
; compiler that had reached a byte-identical gen1/gen2 fixed point.
;
; Deliberately carries no 'target triple' or 'target datalayout' line, so llc
; targets whatever host it runs on. That is safe here because the IR is entirely
; target-neutral: every function signature uses only i1/i8/i32/ptr/void, no struct
; is passed by value, and there are no byval/sret attributes or target intrinsics.
;
; Rebuild with: tools/refresh_seed.sh
;
EOF
# Strip CR so a seed refreshed on a CRLF checkout matches one refreshed here.
tr -d '\r' < "$RAW" | grep -vE '^target (triple|datalayout)[[:space:]]*=' >> "$SEED"
rm -rf "$WORK"

printf '\033[32mWrote %s (%s bytes)\033[0m\n' "$SEED" "$(wc -c < "$SEED" | tr -d ' ')"
echo "Verify with: tools/bootstrap.sh --seed --out build/seedcheck"
