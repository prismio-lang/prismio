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
# Requires clang on PATH, and a clang new enough to read the seed's LLVM IR. On
# macOS that means a Homebrew llvm (`brew install llvm`), not Apple's bundled
# clang, because the two disagree on IR version.

set -eu

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILER=""
SEED=""
OUT=""
KEEP=0
PRINT_KEY=""

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
        # The object cache's key for one runtime source, and nothing else. Exists
        # so a test can assert that the key moves when the inputs move without
        # paying for a bootstrap to find out.
        --print-cache-key) PRINT_KEY="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$OUT" ] && [ -z "$PRINT_KEY" ]; then
    echo "usage: $0 (--compiler <prismio> | --seed [ir]) --out <path> [--repo <dir>] [--keep]" >&2
    echo "       $0 --print-cache-key <runtime-source.c> [--repo <dir>]" >&2
    exit 2
fi
if [ -z "$COMPILER" ] && [ -z "$SEED" ] && [ -z "$PRINT_KEY" ]; then
    echo "error: one of --compiler or --seed is required" >&2
    exit 2
fi

for tool in clang; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: $tool not found on PATH" >&2; exit 1; }
done

# Must match prismio_toolchain_files[] in runtime/build_driver.c.
RUNTIME_SOURCES="lang_runtime.c program_support.c build_driver.c ir_symbols.c aif_support.c diagnostics.c llvm-api-backend.c"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
step()  { printf '\033[90m[%s]\033[0m\n' "$1"; }
die()   { printf '\033[31mFAILED: %s\033[0m\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Toolchain object cache
#
# 1.44 s of this script's ~3.0 s is recompiling seven C files that did not
# change, and the loop it sits in is the one this project runs most. The build
# driver caches the same objects for user builds; this is the same idea for the
# path that builds the compiler, with the same $PRISMIO_OBJ_CACHE knobs.
#
# **The key is content, and it has to be, because this is the one path whose
# contract is that an edit to runtime/*.c reaches the next generation.** A stale
# entry here poisons a compiler generation rather than a test binary. So:
#
#   * every runtime/*.h goes into every entry -- a header changes what a .c
#     compiles to without changing a byte of it. embedded_sources.h is one of
#     them and is regenerated whenever any runtime/*.c changes, so a session
#     editing the runtime invalidates all seven and gets nothing from the cache.
#     That is the right side to be wrong on, and the session editing only .psm
#     files -- which is most of them -- hits all seven;
#   * the compile flags go in, including the LLVM include path, because
#     -DPRISMIO_LLVM_REAL_HEADERS makes the backend's object depend on which
#     LLVM's headers it saw;
#   * with no usable hasher the cache turns itself off rather than guessing.
#     An incomplete key is worse than no cache.
#
# Not covered, exactly as in build_driver.c: an in-place upgrade of clang.
# PRISMIO_OBJ_CACHE=0 is the escape.
# ---------------------------------------------------------------------------

# openssl first because it is a C binary and `shasum` is a Perl script: eight
# invocations of it cost 0.178 s against 0.070 s, which is 9% of what the cache
# saves rather than 2%. Any of them produces a usable key; they just have to be
# consistent within a run, and they are, because the choice is made once here.
if command -v openssl >/dev/null 2>&1; then
    hash_stdin() { openssl dgst -sha256 | cut -d' ' -f2; }
elif command -v shasum >/dev/null 2>&1; then
    hash_stdin() { shasum -a 256 | cut -d' ' -f1; }
elif command -v sha256sum >/dev/null 2>&1; then
    hash_stdin() { sha256sum | cut -d' ' -f1; }
else
    hash_stdin() { echo ""; }
fi

CACHE_DIR="${PRISMIO_OBJ_CACHE_DIR:-${TMPDIR:-/tmp}/prismio-objcache}"

# Echoes the cache path for one source, or nothing when the cache is off or
# cannot be keyed.
cache_entry() {
    entry_src="$1"
    entry_inc="$2"
    [ "${PRISMIO_OBJ_CACHE:-1}" = "0" ] && return 0
    [ -f "$REPO/runtime/$entry_src" ] || return 0

    # Hashed once for the whole run, not once per source: embedded_sources.h
    # alone is half a megabyte, and seven passes over it was most of what the
    # cache cost on a miss.
    if [ -z "${HEADER_KEY:-}" ]; then
        HEADER_KEY="$( { for h in "$REPO"/runtime/*.h; do printf '|%s|' "${h##*/}"; cat "$h"; done; } | hash_stdin )"
        [ -n "$HEADER_KEY" ] || return 0
    fi

    entry_key="$( { printf 'bootstrap|%s|-O2 -DPRISMIO_LLVM_REAL_HEADERS -I%s|%s|' \
                           "$entry_src" "$entry_inc" "$HEADER_KEY"
                    cat "$REPO/runtime/$entry_src"
                  } | hash_stdin )"
    [ -n "$entry_key" ] || return 0

    mkdir -p "$CACHE_DIR" 2>/dev/null || return 0
    echo "$CACHE_DIR/bootstrap-${entry_src%.c}-$entry_key.o"
}

# The backend is built on the LLVM C API, so this needs LLVM's headers and its C
# API link library. tools/setup_llvm.py finds or fetches one and records it in
# third_party/llvm-paths.json; PRISMIO_LLVM_DIR overrides that.
resolve_llvm() {
    if [ -n "${PRISMIO_LLVM_DIR:-}" ]; then
        LLVM_INC="$PRISMIO_LLVM_DIR/include"; LLVM_LIB="$PRISMIO_LLVM_DIR/lib"
    elif [ -f "$REPO/third_party/llvm-paths.json" ]; then
        LLVM_INC="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["include"])' "$REPO/third_party/llvm-paths.json")"
        LLVM_LIB="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["lib"])' "$REPO/third_party/llvm-paths.json")"
    else
        die "no LLVM toolchain configured -- run: python3 tools/setup_llvm.py"
    fi
}

if [ -n "$PRINT_KEY" ]; then
    resolve_llvm
    key_path="$(cache_entry "$PRINT_KEY" "$LLVM_INC")"
    if [ -z "$key_path" ]; then
        echo "no key: the cache is disabled, the source does not exist, or no hasher is available" >&2
        exit 1
    fi
    basename "$key_path"
    exit 0
fi

OUT_DIR="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd || true)"
if [ -z "$OUT_DIR" ]; then mkdir -p "$(dirname "$OUT")"; OUT_DIR="$(cd "$(dirname "$OUT")" && pwd)"; fi
OUT="$OUT_DIR/$(basename "$OUT")"
WORK="$OUT_DIR/.bootstrap-$(basename "$OUT")"
mkdir -p "$WORK"
cleanup() { [ "$KEEP" -eq 1 ] || rm -rf "$WORK"; }
trap cleanup EXIT

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
#
# clang rather than llc, and -O2, for the same reason compile_ir_to_object uses
# them: llc runs the codegen pipeline but not the IR pipeline, so a compiler
# built with it has every local in a stack slot. Worth 1.4x-3.0x on user
# programs (RESULTS-xlang 3.1) and the compiler is a user program too.
step "ll -> obj"
clang -O2 -c "$LL" -o "$WORK/program.o" || die "ll -> obj"

# 3. Runtime and backend C sources, compiled fresh from the working tree --
# except where the cache above already holds the object this source and these
# headers compile to.
resolve_llvm

# The misses are compiled in parallel. They are seven independent translation
# units writing seven distinct objects, so the only thing this changes is how
# long it takes: `aif_support.c` alone is 0.73 s of the 1.44 s the seven cost
# sequentially, and it is the floor. A failed compile is still a failed build --
# every job is waited on individually and named in the message.
OBJS="$WORK/program.o"
miss_count=0
for c in $RUNTIME_SOURCES; do
    entry="$(cache_entry "$c" "$LLVM_INC")"

    if [ -n "$entry" ] && [ -f "$entry" ]; then
        step "cc $c (cached)"
        OBJS="$OBJS $entry"
        continue
    fi

    step "cc $c"
    clang -O2 -DPRISMIO_LLVM_REAL_HEADERS -Wno-deprecated-declarations \
          -I"$LLVM_INC" -I"$REPO/runtime" \
          -c "$REPO/runtime/$c" -o "$WORK/${c%.c}.o" &

    # The key is carried rather than recomputed after the wait. Recomputing it
    # reads the source a second time, and a source edited *during* the build
    # would then key the object that was compiled from the old text under the
    # new text's name -- a poisoned entry that every later build would hit.
    miss_pid[$miss_count]=$!
    miss_src[$miss_count]=$c
    miss_entry[$miss_count]=$entry
    miss_count=$((miss_count + 1))
done

i=0
while [ $i -lt $miss_count ]; do
    wait "${miss_pid[$i]}" || die "cc ${miss_src[$i]}"
    i=$((i + 1))
done

# Installed after the wait rather than inside the loop above: a job that has not
# finished has not written its object yet, and copying one would cache a
# truncated file. Installed by a rename *inside* the cache directory, so it is
# atomic and two concurrent bootstraps cannot link a half-written object. A
# failed install is not a failed build -- link the local copy and pay again.
i=0
while [ $i -lt $miss_count ]; do
    c="${miss_src[$i]}"
    entry="${miss_entry[$i]}"
    obj="$WORK/${c%.c}.o"
    i=$((i + 1))

    if [ -n "$entry" ]; then
        tmp="$(dirname "$entry")/.tmp-$$-$(basename "$entry")"
        if cp "$obj" "$tmp" 2>/dev/null && mv "$tmp" "$entry" 2>/dev/null; then
            OBJS="$OBJS $entry"
            continue
        fi
        rm -f "$tmp" 2>/dev/null || true
    fi
    OBJS="$OBJS $obj"
done

# 4. Link, including LLVM's C API.
step "link"
# shellcheck disable=SC2086
clang $OBJS -o "$OUT" -L"$LLVM_LIB" -lLLVM-C || die "link"

green "Built $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
