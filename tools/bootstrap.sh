#!/usr/bin/env bash
# Build a prismio compiler generation on macOS or Linux.
#
#   tools/bootstrap.sh --seed --out build/gen0            # first ever build on a host
#   tools/bootstrap.sh --compiler build/gen0 --out build/gen1
#
# POSIX counterpart of tools/bootstrap.ps1, and the same idea: do the link by hand
# so every runtime source is compiled fresh from the working tree. Asking an
# existing binary to `build src/main.psm` instead would have it supply the runtime
# from the copy embedded inside itself, which silently carries the *previous*
# generation's runtime/*.c into the new compiler.
#
# --seed starts from bootstrap/prismio-seed.ll, committed LLVM IR for the compiler.
# A host with no prismio binary cannot compile src/main.psm to get one, and that is
# the only way out of the cycle. The seed carries no target triple, so llc targets
# whatever host it runs on.
#
# Requires llc and clang on PATH. On macOS that means either Xcode Command Line
# Tools plus a Homebrew llvm (`brew install llvm`, which is where llc comes from --
# Apple's bundled clang ships no llc), or a full LLVM install.

set -eu

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILER=""
SEED=""
OUT=""
KEEP=0

while [ $# -gt 0 ]; do
    case "$1" in
        --compiler) COMPILER="$2"; shift 2 ;;
        --seed)
            # Optional path; bare --seed means the committed default.
            if [ $# -ge 2 ] && [ "${2#--}" = "$2" ]; then SEED="$2"; shift 2
            else SEED="$REPO/bootstrap/prismio-seed.ll"; shift 1; fi ;;
        --out)  OUT="$2"; shift 2 ;;
        --repo) REPO="$2"; shift 2 ;;
        --keep) KEEP=1; shift 1 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$OUT" ]; then
    echo "usage: $0 (--compiler <prismio> | --seed [ir]) --out <path> [--repo <dir>] [--keep]" >&2
    exit 2
fi
if [ -z "$COMPILER" ] && [ -z "$SEED" ]; then
    echo "error: one of --compiler or --seed is required" >&2
    exit 2
fi

for tool in llc clang; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: $tool not found on PATH" >&2; exit 1; }
done

# Must match prismio_toolchain_files[] in runtime/build_driver.c.
RUNTIME_SOURCES="lang_runtime.c program_support.c build_driver.c ir_symbols.c aif_support.c diagnostics.c llvm-api-backend.c"

OUT_DIR="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd || true)"
if [ -z "$OUT_DIR" ]; then mkdir -p "$(dirname "$OUT")"; OUT_DIR="$(cd "$(dirname "$OUT")" && pwd)"; fi
OUT="$OUT_DIR/$(basename "$OUT")"
WORK="$OUT_DIR/.bootstrap-$(basename "$OUT")"
mkdir -p "$WORK"
cleanup() { [ "$KEEP" -eq 1 ] || rm -rf "$WORK"; }
trap cleanup EXIT

green() { printf '\033[32m%s\033[0m\n' "$1"; }
step()  { printf '\033[90m[%s]\033[0m\n' "$1"; }
die()   { printf '\033[31mFAILED: %s\033[0m\n' "$1" >&2; exit 1; }

LL="$WORK/compiler.ll"

# 1. Obtain IR for the compiler, either from the seed or from a working frontend.
if [ -n "$COMPILER" ]; then
    step "psm -> ll"
    "$COMPILER" build "$REPO/src/main.psm" -o "$LL" || die "psm -> ll"
    [ -f "$LL" ] || die "no IR produced"
else
    step "seed -> ll"
    [ -f "$SEED" ] || die "seed not found: $SEED"
    cp "$SEED" "$LL"
fi

# Duplicate symbols mean import resolution merged a module more than once. llc would
# reject them anyway, but name them explicitly so the cause is obvious.
SYMS="$WORK/symbols.txt"
grep -oE '^(define|declare)[^@]*@[A-Za-z0-9_.$]+\(' "$LL" \
    | sed -E 's/.*@([A-Za-z0-9_.$]+)\(/\1/' | sort > "$SYMS"
DUPES="$(uniq -d "$SYMS" || true)"
if [ -n "$DUPES" ]; then
    printf '\033[31mDUPLICATE SYMBOLS IN IR:\033[0m\n' >&2
    echo "$DUPES" | head -20 | sed 's/^/  /' >&2
    exit 1
fi
green "IR: $(wc -l < "$SYMS" | tr -d ' ') symbols, all unique"

# 2. Backend: IR -> object. No target triple in the seed means the host default.
step "ll -> obj"
llc "$LL" -filetype=obj -o "$WORK/program.o" || die "ll -> obj"

# 3. Runtime and backend C sources, compiled fresh from the working tree.
# The backend is built on the LLVM C API, so this needs LLVM's headers and its C
# API link library. tools/setup_llvm.py finds or fetches one and records it in
# third_party/llvm-paths.json; PRISMIO_LLVM_DIR overrides that.
if [ -n "${PRISMIO_LLVM_DIR:-}" ]; then
    LLVM_INC="$PRISMIO_LLVM_DIR/include"; LLVM_LIB="$PRISMIO_LLVM_DIR/lib"
elif [ -f "$REPO/third_party/llvm-paths.json" ]; then
    LLVM_INC="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["include"])' "$REPO/third_party/llvm-paths.json")"
    LLVM_LIB="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["lib"])' "$REPO/third_party/llvm-paths.json")"
else
    die "no LLVM toolchain configured -- run: python3 tools/setup_llvm.py"
fi

OBJS="$WORK/program.o"
for c in $RUNTIME_SOURCES; do
    obj="$WORK/${c%.c}.o"
    step "cc $c"
    clang -DPRISMIO_LLVM_REAL_HEADERS -Wno-deprecated-declarations \
          -I"$LLVM_INC" -I"$REPO/runtime" \
          -c "$REPO/runtime/$c" -o "$obj" || die "cc $c"
    OBJS="$OBJS $obj"
done

# 4. Link, including LLVM's C API.
step "link"
# shellcheck disable=SC2086
clang $OBJS -o "$OUT" -L"$LLVM_LIB" -lLLVM-C || die "link"

green "Built $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
