#!/usr/bin/env bash
# Assemble an installed Prismio toolchain on macOS or Linux:
#
#   <OutDir>/bin/prismio
#   <OutDir>/lib/runtime.a      linked into every compiled program
#   <OutDir>/lib/backend.a      linked into the compiler only
#   <OutDir>/stdlib/
#
#   tools/package.sh --compiler build/gen2 --out dist/Prismio
#
# POSIX counterpart of tools/package.ps1. The runtime/backend split is enforced
# here, at the point the libraries are built: runtime.a gets lang_runtime.c +
# program_support.c, backend.a gets build_driver.c + ir_symbols.c + diagnostics.c +
# llvm-api-backend.c. Because a
# compiled program links only runtime.a (see find_toolchain_library and
# link_against_runtime_library in build_driver.c), no ir_* backend symbol can reach
# a user binary -- tools/verify_separation.sh checks that against the artifacts.

set -eu

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILER=""
OUTDIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --compiler) COMPILER="$2"; shift 2 ;;
        --out)      OUTDIR="$2";   shift 2 ;;
        --repo)     REPO="$2";     shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$COMPILER" ] || [ -z "$OUTDIR" ]; then
    echo "usage: $0 --compiler <prismio> --out <dir> [--repo <dir>]" >&2
    exit 2
fi

COMPILER="$(cd "$(dirname "$COMPILER")" && pwd)/$(basename "$COMPILER")"
mkdir -p "$OUTDIR"; OUTDIR="$(cd "$OUTDIR" && pwd)"

BIN="$OUTDIR/bin"; LIB="$OUTDIR/lib"; STDLIB="$OUTDIR/stdlib"; WORK="$OUTDIR/.objs"
mkdir -p "$BIN" "$LIB" "$STDLIB" "$WORK"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
die()   { printf '\033[31mFAILED: %s\033[0m\n' "$1" >&2; exit 1; }

# macOS and Linux both ship ar; llvm-ar is the fallback for a bare LLVM install
# with no binutils/Xcode alongside it. Both write the same archive format.
AR="$(command -v ar || command -v llvm-ar || true)"
[ -n "$AR" ] || die "neither ar nor llvm-ar found on PATH"
command -v clang >/dev/null 2>&1 || die "clang not found on PATH"

# Must match prismio_toolchain_files[] in runtime/build_driver.c.
build_archive() {
    name="$1"; shift
    objs=""
    for src in "$@"; do
        obj="$WORK/${src%.c}.o"
        clang -Wno-deprecated-declarations -c "$REPO/runtime/$src" -o "$obj" || die "cc $src"
        objs="$objs $obj"
    done
    archive="$LIB/$name.a"
    rm -f "$archive"
    # shellcheck disable=SC2086
    "$AR" rcs "$archive" $objs || die "ar $name"
    printf '  %-12s %8s bytes  <- %s\n' "$name.a" "$(wc -c < "$archive" | tr -d ' ')" "$*"
}

build_archive runtime lang_runtime.c program_support.c
build_archive backend build_driver.c ir_symbols.c diagnostics.c llvm-api-backend.c

cp "$COMPILER" "$BIN/prismio"
chmod +x "$BIN/prismio"
rm -rf "$WORK"

# Record what runtime.a was built from, so a later build can tell whether the
# library still matches the sources. Computed by the compiler itself
# (`prismio runtime-hash`) rather than reimplemented here, so the packaging step and
# the freshness check can never disagree about how the hash is derived.
RUNTIME_HASH="$(cd "$REPO" && "$COMPILER" runtime-hash | tail -n 1 | tr -d '[:space:]')"
case "$RUNTIME_HASH" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
    *) die "could not compute runtime hash ($RUNTIME_HASH)" ;;
esac
printf '%s' "$RUNTIME_HASH" > "$LIB/runtime.hash"
printf '  %-12s %s\n' "runtime.hash" "$RUNTIME_HASH"

# stdlib/ is part of the published layout but has no content yet: Prismio has no
# module library, only the runtime externs declared per-file in .psm source.
if [ ! -f "$STDLIB/README.md" ]; then
    cat > "$STDLIB/README.md" <<'EOF'
# stdlib

Reserved for the Prismio module library. Empty for now -- the language currently
exposes runtime functionality through `extern fn` declarations resolved against
runtime.a, not through importable stdlib modules.
EOF
fi

green "Packaged toolchain at $OUTDIR"
find "$OUTDIR" -type f | sed "s|^$OUTDIR/|  |"
