#!/usr/bin/env bash
# Verify the runtime/backend boundary against real artifacts on macOS or Linux.
#
#   tools/verify_separation.sh --dist dist/Prismio
#
# The rule being checked: the LLVM backend is a compiler-only component. A program
# compiled by Prismio links runtime.a and nothing else, so no backend symbol may
# appear in a user binary -- while the compiler itself must contain the backend.
#
# Two independent checks, because they can fail separately:
#   1. Archive symbol tables (nm) -- proves the libraries were built from the right
#      translation units in the first place.
#   2. A byte signature in the produced executable -- proves the *link step* only
#      pulled in the runtime. A linked binary's symbol table says nothing about
#      which static-archive members were folded in, so nm cannot answer this one;
#      instead look for IR-emitter format strings that exist only in llvm-bridge.c
#      (e.g. "  %%t%d = icmp %s %s %s, %s").

set -u

DIST=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dist) DIST="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ -n "$DIST" ] || { echo "usage: $0 --dist <dir>" >&2; exit 2; }
[ -d "$DIST" ] || { echo "error: no such directory: $DIST" >&2; exit 1; }
# Absolute, because the probe build below runs from a scratch directory and a
# relative --dist would stop resolving the moment we cd out of here.
DIST="$(cd "$DIST" && pwd)"

NM="$(command -v llvm-nm || command -v nm)"
[ -n "$NM" ] || { echo "error: neither llvm-nm nor nm found on PATH" >&2; exit 1; }

FAILURES=0
check() {
    label="$1"; ok="$2"; detail="${3:-}"
    if [ "$ok" -eq 1 ]; then printf '  \033[32m[PASS]\033[0m %s%s\n' "$label" "${detail:+ -- $detail}"
    else printf '  \033[31m[FAIL]\033[0m %s%s\n' "$label" "${detail:+ -- $detail}"; FAILURES=$((FAILURES + 1)); fi
}
bool() { [ "$1" = "0" ] && echo 1 || echo 0; }

echo "Archive contents"
RUNTIME_LIB=""; BACKEND_LIB=""
for ext in a lib; do
    [ -z "$RUNTIME_LIB" ] && [ -f "$DIST/lib/runtime.$ext" ] && RUNTIME_LIB="$DIST/lib/runtime.$ext"
    [ -z "$BACKEND_LIB" ] && [ -f "$DIST/lib/backend.$ext" ] && BACKEND_LIB="$DIST/lib/backend.$ext"
done
check 'runtime library exists' "$([ -n "$RUNTIME_LIB" ] && echo 1 || echo 0)" "$(basename "${RUNTIME_LIB:-none}")"
check 'backend library exists' "$([ -n "$BACKEND_LIB" ] && echo 1 || echo 0)" "$(basename "${BACKEND_LIB:-none}")"

if [ -n "$RUNTIME_LIB" ] && [ -n "$BACKEND_LIB" ]; then
    RSYMS="$("$NM" --defined-only "$RUNTIME_LIB" 2>/dev/null || true)"
    BSYMS="$("$NM" --defined-only "$BACKEND_LIB" 2>/dev/null || true)"

    # Mach-O nm prefixes C symbols with an underscore; match both flavours.
    ir_count() { echo "$1" | grep -cE '^[^ ]* +[TtDdSsBb] +_?ir_[a-z]' || true; }
    IR_IN_RUNTIME="$(ir_count "$RSYMS")"
    IR_IN_BACKEND="$(ir_count "$BSYMS")"
    check 'runtime library defines no ir_* backend symbols' "$([ "$IR_IN_RUNTIME" -eq 0 ] && echo 1 || echo 0)" "found $IR_IN_RUNTIME"
    check 'backend library defines the ir_* backend symbols' "$([ "$IR_IN_BACKEND" -gt 0 ] && echo 1 || echo 0)" "found $IR_IN_BACKEND"

    echo "$RSYMS" | grep -q 'cli_arg_count'; check 'runtime library provides cli_arg_count' "$(bool $?)"
    echo "$BSYMS" | grep -q 'compiler_build_executable'; check 'backend library provides compiler_build_executable' "$(bool $?)"
    echo "$RSYMS" | grep -q 'compiler_build_executable'
    check 'runtime library does NOT provide compiler_build_executable' "$([ $? -ne 0 ] && echo 1 || echo 0)"
fi

printf '\nCompiled user program\n'
PRISMIO="$DIST/bin/prismio"
PROBE_DIR="$(mktemp -d)"
PROBE_SRC="$PROBE_DIR/probe.psm"
PROBE_EXE="$PROBE_DIR/probe"
cat > "$PROBE_SRC" <<'EOF'
fn main() -> Int {
    println("ok")
    return 0
}
EOF

# Build from a directory with no runtime/ anywhere nearby, so a source-based build
# could only succeed via sources embedded in the binary -- which the signature check
# below would then catch.
( cd "$PROBE_DIR" && "$PRISMIO" build "$PROBE_SRC" -o "$PROBE_EXE" >"$PROBE_DIR/log" 2>&1 )
check 'installed toolchain compiles a program' "$(bool $?)" "$(tr '\n' ' ' < "$PROBE_DIR/log")"

if [ -f "$PROBE_EXE" ]; then
    [ "$("$PROBE_EXE" 2>/dev/null)" = "ok" ]; check 'compiled program runs' "$(bool $?)"

    # Strings only llvm-api-backend.c contributes. grep -a rather than
    # strings(1): strings lives in binutils and is not guaranteed to be installed,
    # and when it is missing the pipeline yields no matches -- which reads as a
    # clean binary and turns this whole section into a check that always passes.
    scan() { LC_ALL=C grep -c -a -F "$2" "$1" 2>/dev/null || true; }
    HITS=""
    for sig in 'internal backend error: ' 'generated module failed verification' 'optimization pipeline failed'; do
        n="$(scan "$PROBE_EXE" "$sig")"
        [ "$n" -gt 0 ] && HITS="$HITS $sig x$n"
    done
    check 'no LLVM backend code in the user binary' "$([ -z "$HITS" ] && echo 1 || echo 0)" "${HITS:-clean}"

    # Sanity: the same signatures must be present in the compiler, otherwise the
    # check above would pass trivially for the wrong reason.
    CN="$(scan "$PRISMIO" 'internal backend error: ')"
    check 'the compiler itself does contain the backend' "$([ "$CN" -gt 0 ] && echo 1 || echo 0)" "backend signature x$CN"
fi
rm -rf "$PROBE_DIR"

echo ""
if [ "$FAILURES" -gt 0 ]; then
    printf '\033[31m%s check(s) FAILED\033[0m\n' "$FAILURES"
    exit 1
fi
printf '\033[32mAll separation checks passed\033[0m\n'
