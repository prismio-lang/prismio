"""The `std` suite's harness tests (the design record, section 4; see tools/testkit/__init__.py)."""
import os
import platform
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from harness.common import *


@harness_test(suite="std")
def run_std_input_test():
    """std.io.input over exact bytes: lines, tokens, bytes, `Result` parsing and one cursor.

    Starts tests/stdin_input_probe.psm once per case with the stdin bytes the case names
    -- including NULs, bytes that are not UTF-8, lines at and past the 64 KiB buffer, and
    two tasks reading at once -- and compares what it prints. Binary input is why this is
    not a Prismio fixture: a parent written in Prismio sends Strings, which end at a NUL.
    """
    print(f"\n{BLUE}--- Running std_input ---{RESET}")
    problems = []
    exe_suffix = ".exe" if platform.system() == "Windows" else ""
    chunk = 65536
    with tempfile.TemporaryDirectory(prefix="prismio-std-input-") as tmp:
        probe = Path(tmp) / ("probe" + exe_suffix)
        built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "stdin_input_probe.psm"),
                             "--verify", "-o", str(probe)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] std.io.input probe did not build: {built.stdout} {built.stderr}{RESET}")
            return False
        every_byte = bytes(range(256))
        cases = (
            # name, args, stdin, stdout
            ("lines: none", ["lines"], b"", "end\n"),
            ("lines: no terminator", ["lines"], b"hello", "[hello]\nend\n"),
            ("lines: one line", ["lines"], b"hello\n", "[hello]\nend\n"),
            ("lines: a blank second line", ["lines"], b"hello\n\n", "[hello]\n[]\nend\n"),
            ("lines: CRLF", ["lines"], b"a\r\nb\r\nc", "[a]\n[b]\n[c]\nend\n"),
            ("line: 64 KiB", ["linelen"], b"x" * chunk + b"\n", f"{chunk}\ntrue\n"),
            ("line: 64 KiB + 1", ["linelen"], b"x" * (chunk + 1) + b"\n", f"{chunk + 1}\ntrue\n"),
            ("line: 64 KiB - 1, no terminator", ["linelen"], b"x" * (chunk - 1), f"{chunk - 1}\ntrue\n"),
            ("line: 200 KiB crossing three fills", ["linelen"], b"y" * 200000 + b"\r\n", "200000\ntrue\n"),
            ("tokens: none", ["tokens"], b"", "end\n"),
            ("tokens: only whitespace", ["tokens"], b" \n\t \r\n", "end\n"),
            ("tokens: mixed whitespace", ["tokens"], b"5\n10 20  30\n40\t50",
             "<5>\n<10>\n<20>\n<30>\n<40>\n<50>\nend\n"),
            ("tokens: eager and lazy agree", ["tokenlist"], b"a b\nc\n", "3\nc\n"),
            ("token then the rest of its line", ["token_then_line"], b"42 tail\nnext\n",
             "42\n[ tail]\n[next]\n"),
            ("line then tokens", ["line_then_token"], b"head\n  7 8\n", "head\n7\n8\n"),
            ("token then readAll", ["token_then_all"], b"first  rest\nmore\n", "first\n[  rest\nmore\n]\n"),
            ("tokens: count and size over many fills", ["tokencount"],
             b"".join(b"token%d\n" % i for i in range(30000)),
             "30000\n%d\n" % sum(len(b"token%d" % i) for i in range(30000))),
            ("tokens: one token spanning a buffer boundary", ["tokencount"],
             b"ab " + b"z" * (chunk - 4) + b" tail", "3\n%d\n" % (2 + chunk - 4 + 4)),
            ("tokens: one token longer than the buffer", ["tokencount"], b"q" * (3 * chunk), "1\n%d\n" % (3 * chunk)),
            ("bytes: NUL and every value are kept", ["allbytes"], every_byte + every_byte,
             "512\n%d\n2\n2\n0\n" % (2 * sum(range(256)))),
            ("bytes: invalid UTF-8 is kept", ["allbytes"], b"\xff\xfe\xc3\x28\x80",
             "5\n%d\n0\n1\n0\n" % sum(b"\xff\xfe\xc3\x28\x80")),
            ("bytes: empty input", ["allbytes"], b"", "0\n0\n0\n0\n0\n"),
            ("bytes: large readAllBytes is not truncated", ["allbytes"], bytes(range(251)) * 40000,
             "%d\n%d\n%d\n0\n0\n" % (251 * 40000, sum(range(251)) * 40000, 40000)),
            ("bytes: a count, then the rest", ["bytes", "100"], bytes(range(200)),
             "100\n%d\n100\n%d\n" % (sum(range(100)), sum(range(100, 200)))),
            ("bytes: fewer than asked at the end", ["bytes", "100"], b"\x01\x02\x03", "3\n6\n0\n0\n"),
            ("bytes: a count of zero", ["bytes", "0"], b"abc", "0\n0\n3\n%d\n" % sum(b"abc")),
            ("byte: one at a time", ["byteloop"], b"\x00\x01\xff", "3\n256\ntrue\n"),
            ("byte: across fills", ["byteloop"], b"\x01" * (chunk * 2 + 5), f"{chunk * 2 + 5}\n{chunk * 2 + 5}\ntrue\n"),
            ("mixed: a line, then bytes from where it stopped", ["line_then_bytes"],
             b"head\n\x00\x00body\x00", "head\n7\n3\n"),
            ("mixed: line, readBytes, readText, readAll", ["line_bytes_text"],
             b"Length: 8\nabcdefghij\n", "Length: 8\n5\nfgh\nij\n\n"),
            ("text: a NUL cuts the text, the bytes stay consumed", ["text_nul"], b"ab\x00cdefgh", "2\n3\n"),
            ("ints: values, bad lines and the end", ["ints"], b" 42 \nhello\n-7\n\n9",
             "ok 42\nnot-a-number\nok -7\nnot-a-number\nok 9\neof\n"),
            ("floats: values, bad lines and the end", ["floats"], b"2.5\nx\n3\n", "ok 2.5\nnot-a-number\nok 3\neof\n"),
            ("readInt falls back with ??", ["int_fallback"], b"12\nnope\n", "12\n18\nstranger\n"),
            ("two tasks share one cursor", ["race"],
             b"".join(b"w%d " % i for i in range(50000)), "50000\n"),
        )
        for name, args, data, want in cases:
            ran = subprocess.run([str(probe)] + args, input=data, capture_output=True, cwd=PROJECT_ROOT)
            out = ran.stdout.decode("utf-8", errors="replace")
            err = ran.stderr.decode("utf-8", errors="replace")
            if ran.returncode != 0:
                problems.append(f"{name}: exit {ran.returncode}: {err.strip()[:200]!r}")
            elif out != want:
                problems.append(f"{name}: got {out[:200]!r}, expected {want[:200]!r}")
            elif " 0 violation(s)" not in err or " 0 leaked," not in err:
                problems.append(f"{name}: no clean ledger: {err.strip()[-300:]!r}")
        # A descriptor that fails is not the end of input: `readIntResult` says `io`, and the
        # plain reads still just stop. A directory cannot be read, on every host but Windows.
        if platform.system() != "Windows":
            descriptor = os.open(str(PROJECT_ROOT), os.O_RDONLY)
            try:
                for args, want in ((["ints"], "io\n"), (["lines"], "end\n")):
                    ran = subprocess.run([str(probe)] + args, stdin=descriptor, capture_output=True, cwd=PROJECT_ROOT)
                    if ran.stdout.decode(errors="replace") != want:
                        problems.append(f"unreadable stdin, {args[0]}: got {ran.stdout.decode(errors='replace')!r}, expected {want!r}")
            finally:
                os.close(descriptor)
    if problems:
        print(f"{RED}[FAIL] std.io.input{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] std.io.input: {len(cases)} cases, one cursor, bytes kept, clean ledger{RESET}")
    return True


def library_toolchain(root, files):
    """A toolchain under `root/toolchain` -- a copy of the compiler under test, its runtime, and a
    `stdlib/` of the `std/...` files -- with every other file written under `root`. Returns the
    compiler, which resolves `std.*` from that library."""
    toolchain = root / "toolchain"
    suffix = ".exe" if platform.system() == "Windows" else ""
    compiler = toolchain / "bin" / ("layout-compiler" + suffix)
    compiler.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PRISMIO_EXE, compiler)
    shutil.copytree(Path(PRISMIO_EXE).resolve().parent.parent / "lib", toolchain / "lib")
    for name, text in files.items():
        target = toolchain / "stdlib" / name[len("std/"):] if name.startswith("std/") else root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    return compiler


@harness_test(suite="std")
def run_std_layout_test():
    """The tree a library is written as: nested modules, packages, sealing, and the two markers.

    The library under test is a toolchain's `stdlib/` made of source, beside a copy of the compiler:
    `std.a.b` is `a/b.psm`, a directory with no file of its name is the modules inside it, a path
    segment that begins with `_` seals a module to the library, the library index never offers a
    sealed module, and a library file may carry the `module` header and `lang("id")`. A module checked
    on its own (`--module`) finds its siblings in its own tree.
    """
    print(f"\n{BLUE}--- Running std_layout ---{RESET}")
    problems = []
    exe_suffix = ".exe" if platform.system() == "Windows" else ""
    files = {
        "std/string.psm": "public fn strMark() -> Int { return 1 }\n",
        "std/core/answer.psm": ("module prelude freestanding\n\n"
                                "lang(\"answer\") public fn answer() -> Int { return 42 }\n"),
        "std/core/shape.psm": ("module freestanding(runtime)\n\n"
                               "lang(\"shape\") public struct Shape { public sides: Int }\n"
                               "lang(\"shape_kind\") public enum Kind { Flat, Round }\n"
                               "lang(\"measure\") trait Measure {\n"
                               "    lang(\"measure_area\") fn area(self) -> Int\n"
                               "}\n"),
        "std/net/output.psm": "public fn say(x: Int) -> Int { return x }\n",
        "std/net/input.psm": "public fn hear() -> Int { return 7 }\n",
        "std/_hidden/tables.psm": "public fn table() -> Int { return 5 }\n",
        "std/text.psm": ("import std._hidden.tables\n\n"
                         "public fn tableTotal() -> Int { return table() + 1 }\n"),
        "std/both.psm": "public fn bothFile() -> Int { return 1 }\n",
        "std/both/inner.psm": "public fn bothInner() -> Int { return 2 }\n",
        "app/ok.psm": ("import std.core.answer\n"
                       "import std.core.shape\n"
                       "import std.net\n"
                       "import std.text\n"
                       "import std.both\n\n"
                       "fn main() -> Int {\n"
                       "    let shape = Shape { sides: 4 }\n"
                       "    let sum = answer() + say(1) + hear() + tableTotal() + bothFile() + shape.sides\n"
                       "    if (sum != 42 + 1 + 7 + 6 + 1 + 4) { return 1 }\n"
                       "    return 0\n"
                       "}\n"),
        "app/selected.psm": ("import std.net.hear\n\n"
                             "fn main() -> Int {\n"
                             "    if (hear() != 7) { return 1 }\n"
                             "    return 0\n"
                             "}\n"),
        "app/wholepackage.psm": ("import std.net.*\n\n"
                                 "fn main() -> Int { return hear() + say(0) - 7 }\n"),
        "app/sealed.psm": ("import std._hidden.tables\n\n"
                           "fn main() -> Int { return table() }\n"),
        "app/sealed_package.psm": ("import std._hidden.*\n\n"
                                   "fn main() -> Int { return table() }\n"),
        "app/suggest.psm": ("fn main() -> Int { return tableTotal() }\n"),
        "app/suggest_sealed.psm": ("fn main() -> Int { return table() }\n"),
        "app/inner.psm": ("import std.both\n\n"
                          "fn main() -> Int { return bothInner() }\n"),
    }
    with tempfile.TemporaryDirectory(prefix="prismio-std-layout-") as tmp:
        root = Path(tmp)
        compiler = library_toolchain(root, files)

        def build(name):
            exe = root / "app" / (name + exe_suffix)
            result = run_command([str(compiler), "build", str(root / "app" / (name + ".psm")), "-o", str(exe)])
            return result, exe

        for name in ("ok", "selected", "wholepackage"):
            result, exe = build(name)
            if result.returncode != 0:
                problems.append(f"{name}: did not build: {(result.stdout + result.stderr).strip()[:400]}")
                continue
            ran = run_command([str(exe)])
            if ran.returncode != 0:
                problems.append(f"{name}: exited {ran.returncode}")

        def refused(name, wanted, absent=()):
            result, _ = build(name)
            output = result.stdout + result.stderr
            if result.returncode == 0:
                problems.append(f"{name}: built, and should have been refused")
            for text in wanted:
                if text not in output:
                    problems.append(f"{name}: no `{text}` in: {output.strip()[:400]}")
            for text in absent:
                if text in output:
                    problems.append(f"{name}: names `{text}`, which a program is never told about: {output.strip()[:400]}")

        refused("sealed", ["`std._hidden.tables` is sealed inside `std`"])
        refused("sealed_package", ["is sealed inside `std`"])
        # The library index: an unimported name is offered its module (the control), and a name only a
        # sealed module declares is not offered one.
        refused("suggest", ["`tableTotal` is declared in `std.text`, which this file does not import"])
        refused("suggest_sealed", ["unknown"], absent=["std._hidden"])
        # A file and a directory of one name: the import means the file alone.
        refused("inner", ["bothInner"])

        # A module checked on its own reads its siblings from its own tree, not the library beside
        # the compiler: `std.edited` is in this tree and nowhere in the library.
        tree = root / "tree"
        for name, text in {"std/edited.psm": "public fn edited() -> Int { return 2 }\n",
                           "std/user.psm": "import std.edited\n\npublic fn use2() -> Int { return edited() }\n"}.items():
            (tree / name).parent.mkdir(parents=True, exist_ok=True)
            (tree / name).write_text(text, encoding="utf-8")
        alone = run_command([str(compiler), "check", str(tree / "std" / "user.psm"), "--module", "std.user"])
        if alone.returncode != 0:
            problems.append("check --module did not read the entry's own tree: "
                            + (alone.stdout + alone.stderr).strip()[:400])
    # The compiler asks for a library item by its marker, never by its name: a library that calls the
    # equality trait `Same` and the pair type `Pair` is the library, and `==` and `(a, b)` still work.
    renamed = {
        "std/string.psm": "public fn strMark() -> Int { return 1 }\n",
        "std/core/cmp.psm": ("lang(\"eq\") trait Same {\n"
                             "    lang(\"eq.eq\") fn same(self, other: Self) -> Bool\n"
                             "}\n"),
        "std/core/pair.psm": ("lang(\"tuple2\") public struct Pair<A, B> { public _0: A, public _1: B }\n"
                              "lang(\"tuple2_new\") public fn pair<A, B>(sink a: A, sink b: B) -> Pair<A, B> {\n"
                              "    return Pair<A, B> { _0: a, _1: b }\n"
                              "}\n"),
        "app/renamed.psm": ("import std.core.cmp\n\n"
                            "struct Point { x: Int }\n"
                            "impl Same for Point { fn same(self, other: Self) -> Bool { return self.x == other.x } }\n\n"
                            "fn main() -> Int {\n"
                            "    let t = (1, 2)\n"
                            "    let a = Point { x: 3 }\n"
                            "    let b = Point { x: 3 }\n"
                            "    if (a == b and t.0 + t.1 == 3) { return 0 }\n"
                            "    return 1\n"
                            "}\n"),
    }
    missing = {
        "std/string.psm": "public fn strMark() -> Int { return 1 }\n",
        "app/missing.psm": "fn main() -> Int {\n    let t = (1, 2)\n    return t.0 - 1\n}\n",
    }
    for label, tree, program, want in (("renamed items", renamed, "renamed", None),
                                       ("missing item", missing, "missing", "the standard library declares no")):
        with tempfile.TemporaryDirectory(prefix="prismio-lang-items-") as tmp2:
            compiler = library_toolchain(Path(tmp2), tree)
            exe = Path(tmp2) / "app" / (program + exe_suffix)
            result = run_command([str(compiler), "build", str(Path(tmp2) / "app" / (program + ".psm")), "-o", str(exe)])
            output = result.stdout + result.stderr
            if want is None:
                if result.returncode != 0:
                    problems.append(f"{label}: did not build: {output.strip()[:400]}")
                elif run_command([str(exe)]).returncode != 0:
                    problems.append(f"{label}: ran and answered wrongly")
            elif result.returncode == 0 or want not in output:
                problems.append(f"{label}: expected `{want}`, got: {output.strip()[:400]}")
    if problems:
        print(f"{RED}[FAIL] std_layout{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] std_layout: nested modules, packages, sealing, the library index and the markers{RESET}")
    return True


@harness_test(suite="std")
def run_failure_builtins_test():
    """`panic`, `unreachable`, a failed `assert` and `exit`, run for real.

    test_182 checks the paths that return. This runs failure_builtins_probe.psm
    once per mode: each failure prints its kind, its message and `--> file:line:col`
    to stderr and exits 101, and `exit(7)` exits 7 after its output. A program
    that declares its own `assert` and `exit` keeps both. And an `assert` whose
    message calls something keeps its loop's flat guard: the message runs only on
    the way out of the process.
    """
    print(f"\n{BLUE}--- Running failure_builtins ---{RESET}")
    problems = []
    exe_suffix = ".exe" if platform.system() == "Windows" else ""
    with tempfile.TemporaryDirectory(prefix="prismio-failure-builtins-") as tmp:
        probe = Path(tmp) / ("probe" + exe_suffix)
        built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "failure_builtins_probe.psm"),
                             "-o", str(probe)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] failure builtins probe did not build: {built.stdout} {built.stderr}{RESET}")
            return False
        cases = (
            # mode, status, stderr must contain, stdout must be
            ("ok", 0, "", "done"),
            ("panic", 101, "panic: no sign for zero\n  --> ", ""),
            ("assert", 101, "assertion failed: if (mode.equals(\"assert\")) { assert(label.length > 9) }", ""),
            ("assertmsg", 101, "assertion failed: custom tail\n  --> ", ""),
            ("unreachable", 101, "panic: entered unreachable code: mode\n  --> ", ""),
            ("exit", 7, "", "before exit"),
        )
        for mode, status, err, out in cases:
            ran = subprocess.run([str(probe), mode], cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
            if ran.returncode != status:
                problems.append(f"{mode}: exit status {ran.returncode}, expected {status}")
            if err and err not in ran.stderr:
                problems.append(f"{mode}: stderr {ran.stderr.strip()[:200]!r} lacks {err!r}")
            if ran.stdout.strip() != out:
                problems.append(f"{mode}: stdout {ran.stdout.strip()!r}, expected {out!r}")
        ran = subprocess.run([str(probe), "panic"], cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if "failure_builtins_probe.psm:9:5" not in ran.stderr:
            problems.append(f"panic does not name line 9 column 5: {ran.stderr.strip()[:200]!r}")

        owned = Path(tmp) / ("owned" + exe_suffix)
        built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "failure_builtins_owned_probe.psm"),
                             "-o", str(owned)])
        if built.returncode != 0:
            problems.append(f"a program's own assert/exit did not build: {built.stdout} {built.stderr}")
        else:
            ran = subprocess.run([str(owned)], cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
            if ran.stdout.strip() != "42" or ran.returncode != 3:
                problems.append(f"own assert/exit: stdout {ran.stdout.strip()!r}, status {ran.returncode}")

        ir_path = Path(tmp) / "guard.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "test_182_failure_builtins.psm"),
                             "-o", str(ir_path)])
        if built.returncode != 0:
            problems.append(f"test_182 IR did not build: {built.stderr}")
        else:
            ir = ir_path.read_text()
            match = re.search(r'^define [^\n]*@checkedSum__[^\n]*\n(.*?)^}', ir, re.MULTILINE | re.DOTALL)
            if not match:
                problems.append("missing function checkedSum")
            elif "flatguard" not in match.group(1):
                problems.append("an assert with a calling message cost checkedSum its flat guard")
    if problems:
        print(f"{RED}[FAIL] failure builtins{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] panic, unreachable, assert and exit report, exit and keep the guard{RESET}")
    return True


@harness_test(suite="std")
def run_std_mem_failures_test():
    """std.mem's checked failures, and what `--verify` says about manual memory.

    A Buffer access out of range is a runtime error naming the offset and the
    length; an Arena that cannot fit an allocation, or is asked for an alignment
    that is not a power of two, panics. The raw blocks are the program's to free,
    so the ledger is the check: a block never freed reads as leaked, and one
    freed twice as a violation -- the two answers `alloc` and `free` going through
    the runtime's allocator seam, rather than bare malloc, exist to give.
    """
    print(f"\n{BLUE}--- Running std_mem_failures ---{RESET}")
    problems = []
    exe_suffix = ".exe" if platform.system() == "Windows" else ""
    source = str(TEST_DIR / "std_mem_failures_probe.psm")
    with tempfile.TemporaryDirectory(prefix="prismio-std-mem-") as tmp:
        probe = Path(tmp) / ("probe" + exe_suffix)
        verified = Path(tmp) / ("verified" + exe_suffix)
        for exe, extra in ((probe, []), (verified, ["--verify"])):
            built = run_command([str(PRISMIO_EXE), "build", source, *extra, "-o", str(exe)])
            if built.returncode != 0:
                print(f"{RED}[FAIL] std.mem failure probe did not build {extra}: "
                      f"{built.stdout} {built.stderr}{RESET}")
                return False
        cases = (
            # mode, status, stderr must contain
            ("range", 1, "4 byte(s) at offset 13 are out of range for a Buffer of 16"),
            ("index", 1, "1 byte(s) at offset 16 are out of range for a Buffer of 16"),
            ("negative", 101, "a slice's count must not be negative, found -1"),
            ("align", 101, "Arena.alloc: align must be a power of two, found 3"),
            ("full", 101, "Arena.alloc: 40 bytes do not fit; 24 of 64 remain"),
        )
        for mode, status, err in cases:
            ran = subprocess.run([str(probe), mode], capture_output=True, text=True,
                                 encoding="utf-8", errors="replace")
            if ran.returncode != status or err not in ran.stderr:
                problems.append(f"{mode}: status {ran.returncode} (expected {status}), "
                                f"stderr {ran.stderr.strip()[:200]!r} lacks {err!r}")
        ledgers = (
            # mode, the ledger must say
            ("leak", " 1 leaked, 0 violation(s)"),
            ("double", " 1 violation(s)"),
        )
        for mode, want in ledgers:
            ran = subprocess.run([str(verified), mode], capture_output=True, text=True,
                                 encoding="utf-8", errors="replace")
            output = (ran.stdout or "") + (ran.stderr or "")
            if want not in output:
                problems.append(f"{mode} under --verify: {elide_middle(output)!r} lacks {want!r}")
    if problems:
        print(f"{RED}[FAIL] std.mem failures{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] std.mem reports a bad access, a full arena, a leak and a double free{RESET}")
    return True


@harness_test(suite="std", resources={"cpu": 2, "mem": 800})
def run_prelude_test():
    """What the language uses needs no import, the program's own declarations win, and an imported
    package brings only the parts a program names."""
    print(f"\n{BLUE}--- Running prelude ---{RESET}")
    problems = []
    env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
    with tempfile.TemporaryDirectory(prefix="prismio-prelude-") as tmp:
        wd = Path(tmp)

        def run(name, source):
            src = wd / (name + ".psm")
            src.write_text(source)
            return subprocess.run([str(PRISMIO_EXE), "run", str(src), "-o", str(wd / name)],
                                  capture_output=True, text=True, encoding="utf-8", errors="replace",
                                  cwd=str(wd), env=env)

        reaches = ('import std.io\n\n'
                   'struct Point { x: Int }\n'
                   'impl Eq for Point { fn eq(self, other: Point) -> Bool { return self.x == other.x } }\n\n'
                   'fn find(x: Int) -> Int? {\n    if (x > 0) { return x }\n    return none\n}\n\n'
                   'fn main() -> Int {\n'
                   '    let mut v: Vec<Int> = [3, 1, 2]\n    v.sort()\n    println(v[0])\n'
                   '    let ages = { "ada": 36 }\n    println(ages.getOr("ada", 0))\n'
                   '    println(find(0) ?? 5)\n'
                   '    println(Vec<String>.filled(2, "x").length)\n'
                   '    let a = Point { x: 1 }\n    println(a == a)\n    return 0\n}\n')
        with_it = run("reaches", reaches)
        if with_it.returncode != 0 or with_it.stdout.split()[-5:] != ["1", "36", "5", "2", "true"]:
            problems.append("the language names did not resolve without imports: "
                            + (with_it.stdout + with_it.stderr)[-400:])

        own = ('import std.io\n\n'
               'trait Ord { fn before(self, other: Int) -> Bool }\n'
               'struct Stack { n: Int }\n'
               'impl Stack {\n    fn push(self, x: Int) -> Int { return self.n + x }\n}\n'
               'fn min(a: Int, b: Int) -> Int { return 100 }\n\n'
               'fn main() -> Int {\n'
               '    let mut v: Vec<Int> = Vec<Int>.withCapacity(4)\n    v.push(9)\n'
               '    println(v.length)\n    println(min(3, 1))\n'
               '    let s = Stack { n: 4 }\n    println(s.push(1))\n    return 0\n}\n')
        shadowed = run("own", own)
        if shadowed.returncode != 0 or shadowed.stdout.split()[-3:] != ["1", "100", "5"]:
            problems.append("the program's own names did not win over the library's: "
                            + (shadowed.stdout + shadowed.stderr)[-400:])

        no_io = run("no_io", "fn main() -> Int {\n    println(1)\n    return 0\n}\n")
        if no_io.returncode == 0 or "add `import std.io`" not in no_io.stdout + no_io.stderr:
            problems.append("printing needed no import")

        # A package is read by the part: a program that prints carries none of the input code, and
        # one that reads carries it.
        for name, source, wants_input in (
                ("hello", 'import std.io\n\nfn main() -> Int {\n    println("hello")\n    return 0\n}\n', False),
                ("reads", 'import std.io\n\nfn main() -> Int {\n    println(readLine() ?? "")\n    return 0\n}\n', True)):
            src = wd / (name + ".psm")
            src.write_text(source)
            made = subprocess.run([str(PRISMIO_EXE), "build", str(src), "-o", str(wd / (name + ".ll"))],
                                  capture_output=True, text=True, encoding="utf-8", errors="replace",
                                  cwd=str(wd), env=env)
            if made.returncode != 0:
                problems.append(f"{name} did not build: {made.stderr[-300:]}")
            elif ("io_stdin_" in (wd / (name + ".ll")).read_text()) != wants_input:
                problems.append(f"{name}: the input part of std.io was read: {not wants_input}")

    if problems:
        print(f"{RED}[FAIL] prelude{RESET}")
        for problem in problems:
            print("  - " + problem)
        return False
    print(f"{GREEN}[PASS] prelude: language names, own names winning, packages read by the part{RESET}")
    return True
