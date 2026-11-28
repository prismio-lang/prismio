"""The `diagnostics` suite's harness tests (the design record, section 4; see tools/testkit/__init__.py)."""
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

from harness.common import *


@harness_test("cli_run_forward_slash", suite="diagnostics",
              reads=["tests/test_01_variables.psm"])
def run_cli_test():
    """`prismio run` with a forward-slash -o path.

    Every other test goes through `build`, so `run` had no coverage at all -- and
    it was broken on Windows for exactly this input: cmd.exe reads `build/x.exe`
    as the command `build` with the switch `/x.exe`, and the failure was reported
    as "Program exited with failure", blaming the compiled program.
    """
    print(f"\n{BLUE}--- Running cli_run_forward_slash ---{RESET}")
    exe_file = scratch() / "cli_probe.exe"
    cleanup_files(exe_file)

    # Deliberately spelled with '/' even on Windows.
    out_arg = f"{scratch().as_posix()}/cli_probe.exe"
    result = run_command([str(PRISMIO_EXE), "run",
                          str(TEST_DIR / "test_01_variables.psm"), "-o", out_arg])
    cleanup_files(exe_file)

    if result.returncode == 0 and "PASS" in result.stdout:
        print(f"{GREEN}[PASS] `prismio run` works with a forward-slash output path{RESET}")
        return True

    print(f"{RED}[FAIL] `prismio run` failed{RESET}")
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr)
    return False


@harness_test(suite="diagnostics")
def run_cli_usage_test():
    """CLI usage text presentation and exit codes across help and error paths."""
    print(f"\n{BLUE}--- Running cli_usage ---{RESET}")

    # 1. `prismio --help` exits 0 and prints usage text
    res_help = run_command([str(PRISMIO_EXE), "--help"])
    if res_help.returncode != 0:
        print(f"{RED}[FAIL] `prismio --help` returned non-zero exit code: {res_help.returncode}{RESET}")
        return False
    if "Usage:" not in res_help.stdout or "Project commands" not in res_help.stdout or "Single-file commands" not in res_help.stdout:
        print(f"{RED}[FAIL] `prismio --help` output missing expected sections{RESET}")
        print(res_help.stdout)
        return False

    # 2. `prismio -h` exits 0 and produces identical stdout
    res_h = run_command([str(PRISMIO_EXE), "-h"])
    if res_h.returncode != 0 or res_h.stdout != res_help.stdout:
        print(f"{RED}[FAIL] `prismio -h` output does not match `prismio --help`{RESET}")
        return False

    # 3. Invocation with no arguments exits 1 and prints usage
    res_empty = run_command([str(PRISMIO_EXE)])
    if res_empty.returncode != 1 or res_empty.stdout != res_help.stdout:
        print(f"{RED}[FAIL] `prismio` with no args did not exit 1 or print usage{RESET}")
        return False

    # 4. An argument error says what is wrong and points at the usage, rather
    #    than burying the one line that matters under the whole page.
    res_missing = run_command([str(PRISMIO_EXE), "check"])
    if (res_missing.returncode != 1 or "P1025" not in res_missing.stderr
            or "prismio --help" not in res_missing.stderr or res_missing.stdout):
        print(f"{RED}[FAIL] `prismio check` without source did not print a diagnostic "
              f"pointing at --help{RESET}")
        return False

    # 5. The compiler-development commands are in --help-all, not --help.
    res_all = run_command([str(PRISMIO_EXE), "--help-all"])
    if (res_all.returncode != 0 or "Compiler-development commands" not in res_all.stdout
            or "dump-ast" in res_help.stdout):
        print(f"{RED}[FAIL] --help and --help-all do not split the user and "
              f"compiler-development commands{RESET}")
        return False

    print(f"{GREEN}[PASS] CLI usage and help formatting verified{RESET}")
    return True


@harness_test(suite="diagnostics")
def run_crlf_triple_string_test():
    """A triple-quoted string's line breaks are `\\n` in a CRLF source too.

    Written here rather than as a tests/*.psm, because git decides a checked-in
    file's line endings: on CI's Windows runner `test_150` arrived as CRLF and
    its string carried a `\\r` per line, while every other platform saw LF. This
    writes the CRLF bytes itself, so every platform tests the CRLF case.
    """
    print(f"\n{BLUE}--- Running crlf_triple_string ---{RESET}")
    source = (
        'import std.io\r\n'
        'import std.string\r\n'
        '\r\n'
        'fn main() -> Int {\r\n'
        '    let s = """one\r\n'
        'two\r\n'
        'three"""\r\n'
        '    if (s.equals("one\\ntwo\\nthree") == false) {\r\n'
        '        println("FAIL: CRLF reached the string")\r\n'
        '        return 1\r\n'
        '    }\r\n'
        '    println("ok")\r\n'
        '    return 0\r\n'
        '}\r\n'
    )
    with tempfile.TemporaryDirectory(prefix="prismio-crlf-") as temp_dir:
        path = Path(temp_dir) / "crlf.psm"
        path.write_bytes(source.encode("utf-8"))
        exe = Path(temp_dir) / ("crlf.exe" if os.name == "nt" else "crlf")
        built = run_command([str(PRISMIO_EXE), "build", str(path), "-o", str(exe)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] a CRLF source did not build{RESET}")
            print(elide_middle(built.stderr))
            return False
        ran = run_command([str(exe)])
        if ran.returncode != 0 or ran.stdout.strip() != "ok":
            print(f"{RED}[FAIL] a CRLF line break reached a triple-quoted string{RESET}")
            print(ran.stdout.strip())
            return False
    print(f"{GREEN}[PASS] CRLF line breaks in a triple-quoted string read as \\n{RESET}")
    return True


@harness_test(suite="diagnostics")
def run_source_not_utf8_test():
    """A byte that begins no UTF-8 character is named as a byte, at its column.

    Written here rather than as a tests/*.psm because the file cannot be UTF-8,
    and tools/lint.py, tools/format_sources.py and every editor read the tests
    directory as UTF-8.
    """
    print(f"\n{BLUE}--- Running source_not_utf8 ---{RESET}")
    source = b"fn main() -> Int {\n    let \xff = 1\n    return 0\n}\n"
    with tempfile.TemporaryDirectory(prefix="prismio-utf8-") as temp_dir:
        path = Path(temp_dir) / "bad.psm"
        path.write_bytes(source)
        exe = Path(temp_dir) / ("bad.exe" if os.name == "nt" else "bad")
        # Bytes, not text: the diagnostic quotes the source line, and that line
        # is the one holding the byte that is not UTF-8.
        built = subprocess.run([str(PRISMIO_EXE), "build", str(path), "-o", str(exe)],
                               capture_output=True)
        output = (built.stdout + built.stderr).decode("utf-8", errors="replace")
        wanted = "invalid UTF-8: byte 255 does not begin a character"
        if built.returncode == 0 or wanted not in output or "bad.psm:2:9" not in output:
            print(f"{RED}[FAIL] a non-UTF-8 source byte was not reported as one{RESET}")
            print(elide_middle(output))
            return False
    print(f"{GREEN}[PASS] a non-UTF-8 byte is reported by value, at its column{RESET}")
    return True


@harness_test(suite="diagnostics")
def run_source_file_limit_test():
    """A program may read thousands of source files, and past the limit says so.

    The registry of files read was 256 long and returned -1 beyond it, which the import
    resolver ignored: the module was parsed with every token carrying file -1, and its
    diagnostics lost their location. The compiler's own program uses about 140, so a workspace
    that checks several programs at once, or a monorepo, reaches 256 first. 300 modules is
    past the old limit and must check clean; past the new one the first unread module is named.
    """
    print(f"\n{BLUE}--- Running source_file_limit ---{RESET}")
    problems = []

    def program(directory, count):
        for i in range(count):
            (directory / f"m{i}.psm").write_text(f"public fn f{i}() -> Int {{ return {i} }}\n")
        imports = "".join(f"import m{i}\n" for i in range(count))
        main = directory / "main.psm"
        main.write_text(imports + "\nfn main() -> Int {\n    return f0() + f%d()\n}\n" % (count - 1))
        return main

    def check(path):
        result = run_command([str(PRISMIO_EXE), "check", str(path), "--diagnostic-format=json"])
        records = [json.loads(line) for line in result.stderr.splitlines() if line.startswith("{")]
        return result.returncode, [r for r in records if r.get("kind") == "diagnostic" and r.get("severity") == "error"]

    with tempfile.TemporaryDirectory(prefix="prismio-files-") as tmp:
        under = Path(tmp) / "under"
        under.mkdir()
        code, errors = check(program(under, 300))
        if code != 0 or errors:
            problems.append(f"300 modules (past the old limit of 256) should check clean: {errors[:2]}")

        over = Path(tmp) / "over"
        over.mkdir()
        code, errors = check(program(over, 4200))
        if not any(e.get("code") == "P1098" and "was not read" in e.get("message", "") for e in errors):
            problems.append(f"4200 modules should report P1098 for the first one past the limit: {errors[:2]}")
        if any(e.get("file") is None and e.get("code") != "P0001" for e in errors):
            problems.append("an error lost its location")

    if problems:
        print(f"{RED}[FAIL] source file limit{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] 300 modules check clean; the limit, when reached, names the module it stopped at{RESET}")
    return True


@harness_test("cli_check_protocol", suite="diagnostics")
def run_check_command_test():
    """The analysis-only IDE boundary and its versioned JSON Lines output."""
    print(f"\n{BLUE}--- Running cli_check_protocol ---{RESET}")

    valid = TEST_DIR / "test_01_variables.psm"
    invalid = TEST_DIR / "neg_01_type_mismatch.psm"
    artifact = TEST_DIR / "test_01_variables.exe"
    cleanup_files(artifact)

    with tempfile.TemporaryDirectory(prefix="prismio-check-") as temp_dir:
        empty = Path(temp_dir) / "empty.psm"
        empty.write_text("", encoding="utf-8")
        empty_result = run_command([str(PRISMIO_EXE), "check", str(empty)])
    if empty_result.returncode != 0:
        print(f"{RED}[FAIL] `prismio check` rejected an empty source file{RESET}")
        print(empty_result.stdout or empty_result.stderr)
        return False

    human = run_command([str(PRISMIO_EXE), "check", str(valid)])
    if human.returncode != 0:
        print(f"{RED}[FAIL] `prismio check` rejected a valid program{RESET}")
        print(human.stdout or human.stderr)
        return False
    if artifact.exists():
        print(f"{RED}[FAIL] `prismio check` created a native artifact{RESET}")
        cleanup_files(artifact)
        return False

    machine_ok = run_command([
        str(PRISMIO_EXE), "check", str(valid), "--diagnostic-format=json"
    ])
    machine_bad = run_command([
        str(PRISMIO_EXE), "check", str(invalid), "--diagnostic-format=json"
    ])

    def records(result):
        try:
            return [json.loads(line) for line in result.stderr.splitlines() if line]
        except json.JSONDecodeError as error:
            print(f"{RED}[FAIL] diagnostic stream is not JSON Lines: {error}{RESET}")
            print(result.stderr)
            return None

    ok_records = records(machine_ok)
    bad_records = records(machine_bad)
    if ok_records is None or bad_records is None:
        return False

    if machine_ok.returncode != 0 or ok_records != [{
        "kind": "summary", "schemaVersion": 1, "errors": 0, "warnings": 0
    }]:
        print(f"{RED}[FAIL] successful JSON check did not emit a clean summary{RESET}")
        print(machine_ok.stderr)
        return False

    diagnostics = [r for r in bad_records if r.get("kind") == "diagnostic"]
    summaries = [r for r in bad_records if r.get("kind") == "summary"]
    located_errors = [
        r for r in diagnostics
        if r.get("severity") == "error"
        and re.fullmatch(r"P\d{4}", str(r.get("code", "")))
        and str(r.get("file", "")).endswith(invalid.name)
        and r.get("line", 0) > 0
        and r.get("column", 0) > 0
        and r.get("length", 0) > 0
        and r.get("message")
    ]

    if machine_bad.returncode == 0 or not located_errors:
        print(f"{RED}[FAIL] rejected JSON check has no located error{RESET}")
        print(machine_bad.stderr)
        return False
    if located_errors[0].get("code") != "P4001":
        print(f"{RED}[FAIL] type mismatch diagnostic code is not stable (expected P4001){RESET}")
        print(machine_bad.stderr)
        return False
    if len(summaries) != 1 or summaries[0].get("errors", 0) < 1:
        print(f"{RED}[FAIL] rejected JSON check has no final error summary{RESET}")
        print(machine_bad.stderr)
        return False
    if "-->" in machine_bad.stderr or "aborting due to" in machine_bad.stderr:
        print(f"{RED}[FAIL] human diagnostic rendering leaked into JSON mode{RESET}")
        print(machine_bad.stderr)
        return False

    print(f"{GREEN}[PASS] check is analysis-only and emits schema v1 JSON Lines{RESET}")
    return True


@harness_test(suite="diagnostics")
def run_identifier_security_test():
    """UTS #39's two warnings: P2003 (a restricted character) and P2004 (confusable
    identifiers), from src/lexer/identifier_security.psm.

    Warnings, so the program still builds and runs: the exit status is half of
    what is asserted. The other half is where and what -- the JSON stream for the
    code, severity and position an IDE reads, the rendered text for the message a
    person reads. An ASCII-only program is the control: the check does not run for
    one at all, and a pair of ASCII names is not reported.
    """
    print(f"\n{BLUE}--- Running identifier_security ---{RESET}")
    probe = TEST_DIR / "identifier_security_probe.psm"
    control = TEST_DIR / "byte_loop_probe.psm"
    problems = []

    with tempfile.TemporaryDirectory(prefix="prismio-idsec-") as td:
        exe = Path(td) / ("probe" + (".exe" if os.name == "nt" else ""))
        built = subprocess.run([str(PRISMIO_EXE), "build", str(probe), "-o", str(exe)],
                               capture_output=True, text=True, encoding="utf-8", errors="replace")
        text = (built.stdout or "") + (built.stderr or "")
        if built.returncode != 0:
            problems.append(f"the probe did not build; warnings must not fail it: {elide_middle(text)}")
        else:
            ok, out, _ = run_program(exe)
            if not ok or out.strip() != "2":
                problems.append(f"the probe printed {out.strip()!r}, expected 2")
        for want in ("warning[P2003]: identifier `ſum` contains U+017F",
                     "identifier_security_probe.psm:12:9",
                     "warning[P2004]: identifier `pаypal` looks like `paypal`",
                     "identifier_security_probe.psm:14:9"):
            if want not in text:
                problems.append(f"missing from the build's output: {want!r}")

    def json_diagnostics(src):
        r = subprocess.run([str(PRISMIO_EXE), "check", str(src), "--diagnostic-format=json"],
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        records = []
        for line in ((r.stdout or "") + (r.stderr or "")).splitlines():
            if line.startswith("{"):
                records.append(json.loads(line))
        return r.returncode, records

    status, records = json_diagnostics(probe)
    found = [(d.get("code"), d.get("severity"), d.get("line"), d.get("column"))
             for d in records if d.get("kind") == "diagnostic"]
    if status != 0:
        problems.append(f"`check` exited {status} on warnings alone")
    if sorted(found) != [("P2003", "warning", 12, 9), ("P2004", "warning", 14, 9)]:
        problems.append(f"JSON diagnostics were {found}")
    summary = [d for d in records if d.get("kind") == "summary"]
    if not summary or summary[0].get("errors") != 0 or summary[0].get("warnings") != 2:
        problems.append(f"JSON summary was {summary}")

    status, records = json_diagnostics(control)
    stray = [d for d in records if d.get("kind") == "diagnostic"]
    if status != 0 or stray:
        problems.append(f"the ASCII control reported {stray} (exit {status})")

    if problems:
        print(f"{RED}[FAIL] identifier security warnings{RESET}")
        for p in problems:
            print(f"  {p}")
        return False
    print(f"{GREEN}[PASS] P2003 and P2004 warn, at the right place, and the build succeeds{RESET}")
    return True
