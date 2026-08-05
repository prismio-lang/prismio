#!/usr/bin/env python3
"""Regenerate embedded_sources.h from the toolchain sources.

Cross-platform equivalent of generate_embedded_sources.ps1 (which requires
PowerShell). Run this after editing any runtime source, then rebuild
prismio.exe, or the compiler keeps embedding a stale runtime.

The set below must stay in step with prismio_toolchain_files[] in build_driver.c:
the two headers are embedded as well as the .c files because the unpacked sources
include them.
"""
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent


def escape_c_string(line: bytes) -> str:
    out = []
    for byte in line:
        if byte == 0x5C:
            out.append("\\\\")
        elif byte == 0x22:
            out.append('\\"')
        elif byte == 0x09:
            out.append("\\t")
        elif byte < 0x20 or byte > 0x7E:
            out.append("\\%03o" % byte)
        else:
            out.append(chr(byte))
    return "".join(out)


def add_c_string(lines: list, name: str, content: bytes) -> None:
    lines.append(f"static const char {name}[] =")
    normalized = content.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    parts = normalized.split(b"\n")
    for i, part in enumerate(parts):
        escaped = escape_c_string(part)
        if i == len(parts) - 1 and len(escaped) == 0:
            continue
        lines.append(f'"{escaped}\\n"')
    lines.append(";")
    lines.append("")


EMBEDDED_FILES = [
    ("prismio_platform.h", "prismio_embedded_prismio_platform_h"),
    ("prismio_runtime.h", "prismio_embedded_prismio_runtime_h"),
    ("lang_runtime.c", "prismio_embedded_lang_runtime_c"),
    ("program_support.c", "prismio_embedded_program_support_c"),
    ("build_driver.c", "prismio_embedded_build_driver_c"),
    ("ir_symbols.c", "prismio_embedded_ir_symbols_c"),
    ("aif_support.c", "prismio_embedded_aif_support_c"),
    ("diagnostics.c", "prismio_embedded_diagnostics_c"),
    ("llvm-api-backend.c", "prismio_embedded_llvm_api_backend_c"),
]


def main() -> None:
    lines = [
        "#ifndef PRISMIO_EMBEDDED_SOURCES_H",
        "#define PRISMIO_EMBEDDED_SOURCES_H",
        "",
        "#define PRISMIO_EMBEDDED_SOURCE_AVAILABLE 1",
        "",
    ]
    for filename, symbol in EMBEDDED_FILES:
        path = SCRIPT_DIR / filename
        if not path.exists():
            raise SystemExit(f"ERROR: missing toolchain source {path}")
        add_c_string(lines, symbol, path.read_bytes())
    lines.append("#endif")

    out_path = SCRIPT_DIR / "embedded_sources.h"
    out_path.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    sys.exit(main())
