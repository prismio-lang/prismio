"""Helpers shared by the harness suites: where things are, and how a test runs a command."""
import json
import os
import re
import struct
import subprocess
from pathlib import Path

from testkit.api import EXCLUSIVE, harness_test

GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

TEST_DIR = Path(__file__).resolve().parent.parent
PROJECT_ROOT = TEST_DIR.parent

# The compiler under test. The engine names it before a suite module is imported.
PRISMIO_EXE = Path(os.environ.get("PRISMIO_TEST_COMPILER", "prismio"))


def scratch():
    """This test's own directory: every file a test writes goes here, never into tests/."""
    return Path(os.environ.get("PRISMIO_TEST_SCRATCH") or tempfile.gettempdir())


def test_jobs():
    """How many compiles this test may run at once: the cpu tokens it declared, and no more
    than PRISMIO_TEST_JOBS, whose 1 means nothing at all runs side by side."""
    granted = max(1, int(os.environ.get("PRISMIO_TEST_CPUS", "1")))
    try:
        return min(granted, max(1, int(os.environ["PRISMIO_TEST_JOBS"])))
    except (KeyError, ValueError):
        return granted


def run_command(cmd, capture=True):
    if capture:
        return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return subprocess.run(cmd)


def elide_middle(text, head=700, tail=300):
    """Keep both ends of a diagnostic rather than one of them.

    Truncating to the last N characters keeps the wrong half. An ORC failure
    reads `Symbols not found: [ ... ] Failed to materialize symbols: { (main,
    { ... }) }`: the first clause is the cause and the second is a list of every
    symbol in the module, so the tail is the part that carries no information.
    The Windows job's report of the `--jit` failure began mid-symbol-name,
    which is what a tail slice of a message like that looks like.
    """
    text = (text or "").strip()
    if len(text) <= head + tail:
        return text
    return (text[:head]
            + f"\n  [... {len(text) - head - tail} characters elided ...]\n"
            + text[-tail:])


def cleanup_files(*files):
    for file in files:
        if os.path.exists(file):
            try:
                os.remove(file)
            except OSError:
                pass


def run_program(exe_file):
    result = run_command([str(exe_file)])
    if result.returncode != 0:
        print(f"  (program exited with code {result.returncode})")
        return False, result.stdout, result.stderr
    return True, result.stdout, result.stderr


# ---------------------------------------------------------------------------
# -g
# ---------------------------------------------------------------------------

def _di_nodes(ir):
    """Every `!N = ...` line of a module, as {N: text}."""
    return {int(m.group(1)): m.group(2)
            for m in re.finditer(r"^!(\d+) = (.*)$", ir, re.M)}


def _di_tuple(nodes, ref):
    """The members of a metadata tuple `!{!1, !2, ...}`, as ints."""
    body = nodes.get(ref, "")
    return [int(x) for x in re.findall(r"!(\d+)", body)]


def _di_composite(nodes, name):
    """The DICompositeType with this name, and its members as
    [(field, offset_bits, size_bits)] in declaration order within the record."""
    for num, text in nodes.items():
        if "DICompositeType" not in text:
            continue
        if re.search(r'name: "%s"' % re.escape(name), text) is None:
            continue
        elems = re.search(r"elements: !(\d+)", text)
        members = []
        if elems:
            for ref in _di_tuple(nodes, int(elems.group(1))):
                body = nodes.get(ref, "")
                if "DW_TAG_member" not in body:
                    continue
                fname = re.search(r'name: "([^"]*)"', body)
                size = re.search(r"size: (\d+)", body)
                offset = re.search(r"offset: (\d+)", body)
                members.append((fname.group(1) if fname else "?",
                                int(offset.group(1)) if offset else 0,
                                int(size.group(1)) if size else 0))
        size = re.search(r"size: (\d+)", text)
        return members, (int(size.group(1)) if size else 0)
    return None, 0


# Natural alignment, which is what every target this compiler supports uses for
# these seven types. Written out here rather than asked of the compiler on
# purpose: a test that computed offsets the same way the thing under test does
# would agree with it while both were wrong.
# (size, alignment) in bits, which the fat String is the first element to make
# two different numbers: `%prismio.str` is {ptr, i64}, so it is two words wide
# and still only word-aligned. A model that aligned every element to its own
# width -- which is what this was, when width was all it knew -- puts a String
# field 64 bits further along than LLVM does, and then reports the *compiler* as
# having described the wrong offsets.
_LLVM_LAYOUT_BITS = {"i1": (8, 8), "i8": (8, 8), "i16": (16, 16),
                     "i32": (32, 32), "i64": (64, 64), "double": (64, 64),
                     "%prismio.str": (128, 64)}


def _expected_layout(elements, ptr_bits=64):
    """(offsets, total_size), in bits, for a C-style struct of these elements.

    `ptr_bits` is the target's pointer width. It is a parameter rather than a
    constant because a cross build is exactly the case where assuming the host's
    64 produces offsets that look right on this machine and describe the wrong
    bytes on the one the DWARF is for.

    `%prismio.str` is {ptr, i64} and comes out 128 bits wide, 64-bit aligned, on
    both widths -- the i64 half carries the alignment either way -- so it needs
    no parameter of its own.
    """
    table = dict(_LLVM_LAYOUT_BITS, ptr=(ptr_bits, ptr_bits))
    offset = 0
    worst = 8
    offsets = []
    for e in elements:
        entry = table.get(e)
        if entry is None:
            return None, 0
        size, align = entry
        worst = max(worst, align)
        if offset % align:
            offset += align - (offset % align)
        offsets.append(offset)
        offset += size
    if offset % worst:
        offset += worst - (offset % worst)
    return offsets, offset


def _emitted_struct(ir, name):
    m = re.search(r"^%%%s = type \{(.*)\}" % re.escape(name), ir, re.M)
    if not m:
        return None
    return [e.strip() for e in m.group(1).split(",") if e.strip()]


def pinned_llvm_tool(name):
    """A tool of the LLVM this compiler is built on (third_party/llvm-paths.json), or None."""
    llvm_paths = PROJECT_ROOT / "third_party" / "llvm-paths.json"
    try:
        llvm_bin = Path(json.loads(llvm_paths.read_text())["bin"])
    except (KeyError, ValueError, OSError):
        return None
    candidate = llvm_bin / (name + ".exe" if os.name == "nt" else name)
    return candidate if candidate.is_file() else None


def plib_sections(path):
    """A PLIB v4's code sections as (triple, normal bitcode), or None.

    The layout runtime/build_driver.c reads and writes: a 28-byte header, the module name, the
    metadata and interface, then per section a 20-byte header, the triple, and the normal and
    verify bitcode.
    """
    data = path.read_bytes()
    if data[:8] != b"PRPLIB4\n" or len(data) < 28:
        return None
    module_len, meta_len, interface_len, count = struct.unpack_from("<IIQI", data, 8)
    at = 28 + module_len + meta_len + interface_len
    sections = []
    for _ in range(count):
        if at + 20 > len(data):
            return None
        triple_len, code_len, verify_len = struct.unpack_from("<IQQ", data, at)
        at += 20
        triple = data[at:at + triple_len].decode("utf-8", "replace")
        at += triple_len
        sections.append((triple, data[at:at + code_len]))
        at += code_len + verify_len
    return sections if at == len(data) else None


__all__ = [
    "BLUE",
    "EXCLUSIVE",
    "GREEN",
    "PRISMIO_EXE",
    "PROJECT_ROOT",
    "RED",
    "RESET",
    "TEST_DIR",
    "YELLOW",
    "_LLVM_LAYOUT_BITS",
    "_di_composite",
    "_di_nodes",
    "_di_tuple",
    "_emitted_struct",
    "_expected_layout",
    "cleanup_files",
    "elide_middle",
    "harness_test",
    "pinned_llvm_tool",
    "plib_sections",
    "run_command",
    "run_program",
    "scratch",
    "test_jobs",
]
