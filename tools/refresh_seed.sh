#!/usr/bin/env bash
# Cut a bootstrap seed from a known-good compiler, for a release.
#
#   tools/refresh_seed.sh --compiler build/gen2
#
# Writes bootstrap/prismio-seed-<version>.ll (untracked), pins its SHA-256 in
# bootstrap/seed.json, and says how to upload it. The seed is a release asset, not a
# tracked file: see tools/fetch_seed.py. POSIX counterpart of tools/refresh_seed.ps1;
# the two must stay in step, since either platform can cut the seed.

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

# PRISMIO_SEED_IR: the three libc names that differ per platform (errno's
# accessor, the console write, EAGAIN) become calls into program_support.c, so the
# seed does not carry this host's spelling of them. See errno_location_symbol in
# runtime/llvm-api-backend.c.
export PRISMIO_SEED_IR=1

# Built from the repository root with a relative path. The compiler records source
# paths in the IR (the AIF profile keys), and an absolute one would put the
# refreshing machine's checkout location in the pinned seed.
COMPILER="$(cd "$(dirname "$COMPILER")" && pwd)/$(basename "$COMPILER")"
cd "$REPO"

"$COMPILER" build src/main.psm -o "$RAW" >/dev/null || die "compiler could not build src/main.psm"
[ -f "$RAW" ] || die "no IR produced"

# Fixed-point check: a compiler that does not reproduce its own IR is mid-migration,
# and freezing that state into the seed would hand every new host a compiler that
# disagrees with the one everyone else is running.
"$COMPILER" build src/main.psm -o "$AGAIN" >/dev/null || die "second build failed"
cmp -s "$RAW" "$AGAIN" || die "compiler is not deterministic"

VERSION="$(sed -n 's/^let PRISMIO_VERSION = "\([^"]*\)".*/\1/p' "$REPO/src/main.psm")"
[ -n "$VERSION" ] || die "PRISMIO_VERSION not found in src/main.psm"
SEED="$REPO/bootstrap/prismio-seed-$VERSION.ll"
cat > "$SEED" <<'EOF'
; Prismio bootstrap seed -- LLVM IR for the Prismio compiler (src/main.psm).
;
; Published as a release asset because a new platform has no prismio binary to
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
; Rebuild with: tools/refresh_seed.sh
;
EOF
# Strip CR so a seed refreshed on a CRLF checkout matches one refreshed here.
tr -d '\r' < "$RAW" | grep -vE '^target (triple|datalayout)[[:space:]]*=' >> "$SEED"
rm -rf "$WORK"

printf '\033[32mWrote %s (%s bytes)\033[0m\n' "$SEED" "$(wc -c < "$SEED" | tr -d ' ')"
python3 "$REPO/tools/fetch_seed.py" --pin "$SEED" --version "$VERSION"
echo "Verify with: tools/bootstrap.sh --seed --out build/seedcheck"
