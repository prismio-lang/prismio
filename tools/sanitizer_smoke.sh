#!/usr/bin/env bash
# Compile representative ownership and concurrency fixtures with AddressSanitizer.

set -eu

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILER=""

while [ $# -gt 0 ]; do
    case "$1" in
        --compiler) COMPILER="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -n "$COMPILER" ] || { echo "usage: $0 --compiler <prismio>" >&2; exit 2; }
case "$COMPILER" in
    /*) ;;
    *) COMPILER="$PWD/$COMPILER" ;;
esac
[ -x "$COMPILER" ] || { echo "compiler is not executable: $COMPILER" >&2; exit 1; }
command -v clang >/dev/null 2>&1 || { echo "clang not found on PATH" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/prismio-asan.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

run_fixture() {
    source_name="$1"
    detect_leaks="$2"
    stem="${source_name%.psm}"
    ll="$WORK/$stem.ll"
    exe="$WORK/$stem"

    printf '%-42s ' "$source_name"
    "$COMPILER" build "$REPO/tests/$source_name" -o "$ll" >/dev/null
    clang -O1 -g -fno-omit-frame-pointer -fsanitize=address \
        -Wno-deprecated-declarations -Wno-override-module -pthread \
        "$ll" "$REPO/runtime/lang_runtime.c" "$REPO/runtime/program_support.c" \
        -I"$REPO/runtime" -o "$exe"
    ASAN_OPTIONS="detect_leaks=$detect_leaks:halt_on_error=1:abort_on_error=1" "$exe" >/dev/null
    echo "ok"
}

# Recursive release and channels must also be leak-free. The provenance fixture
# intentionally retains unbound temporaries (documented in the fixture), so its
# ASan run targets the use-after-free class that originally motivated this gate.
run_fixture test_73_recursive_release.psm 1
run_fixture test_92_field_view_provenance.psm 0
run_fixture test_96_channels.psm 1

echo "AddressSanitizer smoke suite passed."
