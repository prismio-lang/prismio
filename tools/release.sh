#!/usr/bin/env bash
# Build the distributable artifacts for a release, and their checksums.
#
#   bash tools/release.sh --compiler build/v0.1-rc --version 0.1.0 --out dist/release
#
# One archive per host, named for the triple it was built on, plus a SHA-256
# manifest covering every archive in the directory. Run it on each platform; the
# manifests concatenate, which is what lets three machines produce one checksum
# file without any of them trusting the others.
#
# **It refuses to build from a compiler that is not a fixpoint.** A release
# artifact whose compiler does not reproduce its own IR is a compiler caught
# mid-migration, and that is the one defect this project has burned commits on.

set -eu

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILER=""
VERSION=""
OUTDIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --compiler) COMPILER="$2"; shift 2 ;;
        --version)  VERSION="$2";  shift 2 ;;
        --out)      OUTDIR="$2";   shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ -n "$COMPILER" ] && [ -n "$OUTDIR" ] || {
    echo "usage: $0 --compiler <prismio> --out <dir> [--version <x.y.z>]" >&2; exit 2; }

COMPILER="$(cd "$(dirname "$COMPILER")" && pwd)/$(basename "$COMPILER")"
cd "$REPO"
mkdir -p "$OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd)"

# The version the compiler reports is the version that ships. Taking it from a
# flag would let an archive be named for a number the binary inside it does not
# say, which is the kind of mismatch nobody checks until a bug report.
REPORTED="$("$COMPILER" --version | head -1 | awk '{print $2}')"
if [ -n "$VERSION" ] && [ "$VERSION" != "$REPORTED" ]; then
    echo "error: --version $VERSION but the compiler reports $REPORTED" >&2
    echo "       PRISMIO_VERSION in src/main.psm is the source of truth." >&2
    exit 1
fi
VERSION="$REPORTED"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== fixpoint check"
bash tools/bootstrap.sh --compiler "$COMPILER" --out "$WORK/gen" >/dev/null 2>&1
"$COMPILER" build src/main.psm -o "$WORK/frozen.ll" >/dev/null
"$WORK/gen"  build src/main.psm -o "$WORK/next.ll"  >/dev/null
cmp -s "$WORK/frozen.ll" "$WORK/next.ll" || {
    echo "error: $COMPILER is not a fixpoint -- it does not reproduce its own IR" >&2
    exit 1; }
echo "   ok -- the frozen compiler reproduces its own IR"

case "$(uname -s)" in
    Darwin) HOST="$(uname -m)-apple-darwin" ;;
    Linux)  HOST="$(uname -m)-unknown-linux-gnu" ;;
    *)      HOST="$(uname -s | tr '[:upper:]' '[:lower:]')" ;;
esac
STEM="prismio-$VERSION-$HOST"

echo "== packaging $STEM"
rm -rf "$WORK/$STEM"
bash tools/package.sh --compiler "$COMPILER" --out "$WORK/$STEM" >/dev/null
bash tools/verify_separation.sh --dist "$WORK/$STEM" >/dev/null || {
    echo "error: the packaged toolchain failed its separation checks" >&2; exit 1; }
cp "$REPO/LICENSE" "$WORK/$STEM/" 2>/dev/null || true
cp "$REPO/CHANGELOG.md" "$WORK/$STEM/" 2>/dev/null || true

echo "== archiving"
tar -czf "$OUTDIR/$STEM.tar.gz" -C "$WORK" "$STEM"

echo "== checksums"
( cd "$OUTDIR" && \
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$STEM.tar.gz"
  else sha256sum "$STEM.tar.gz"; fi ) > "$OUTDIR/$STEM.tar.gz.sha256"
cat "$OUTDIR/$STEM.tar.gz.sha256"

echo
echo "artifact: $OUTDIR/$STEM.tar.gz"
echo "checksum: $OUTDIR/$STEM.tar.gz.sha256"
