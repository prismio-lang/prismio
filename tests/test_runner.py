import subprocess
import sys
import os
from pathlib import Path
from shutil import which

GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

TEST_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = TEST_DIR.parent

def find_prismio_exe():
    # $PRISMIO wins, so a freshly bootstrapped compiler can be tested without
    # installing it first. Without this the runner silently exercises whatever
    # older prismio happens to be on PATH, and reports its failures as yours.
    override = os.environ.get("PRISMIO")
    if override:
        path = Path(override)
        if path.is_file():
            return path
        print(f"{RED}[FAIL] $PRISMIO is set but not a file: {override}{RESET}")
        sys.exit(1)

    # Prismio Path
    prismio = which("prismio")

    if prismio:
        return Path(prismio)

    print(f"{RED}[FAIL] prismio not found in PATH{RESET}")
    print("Make sure Prismio is installed, added to PATH, or set $PRISMIO.")
    sys.exit(1)


PRISMIO_EXE = find_prismio_exe()


def run_command(cmd, capture=True):
    if capture:
        return subprocess.run(cmd, capture_output=True, text=True)
    return subprocess.run(cmd)


def cleanup_files(*files):
    for file in files:
        if os.path.exists(file):
            try:
                os.remove(file)
            except OSError:
                pass


def compile_prismio_file(test_file, exe_file):
    print(f"  Compiling {test_file}...")
    result = run_command([str(PRISMIO_EXE), "build", str(test_file), "-o", str(exe_file)])

    if result.returncode != 0:
        print(f"{RED}[FAIL] Compilation failed{RESET}")
        print(result.stdout)
        print(result.stderr)
        return False

    if not os.path.exists(exe_file):
        print(f"{RED}[FAIL] Compiler did not produce {exe_file}{RESET}")
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr)
        return False

    return True


def run_program(exe_file):
    result = run_command([str(exe_file)])
    if result.returncode != 0:
        print(f"  (program exited with code {result.returncode})")
        return False, result.stdout, result.stderr
    return True, result.stdout, result.stderr


def run_test(test_file):
    test_name = Path(test_file).stem
    exe_file = TEST_DIR / f"{test_name}.exe"

    print(f"\n{BLUE}--- Running {test_name} ---{RESET}")

    cleanup_files(exe_file)
    if not compile_prismio_file(test_file, exe_file):
        cleanup_files(exe_file)
        return False

    print("  Executing...")
    success, output, error_output = run_program(exe_file)

    if success:
        print(f"{GREEN}[PASS] Test passed{RESET}")
        if output:
            print(f"  Output: {output.strip()}")
    else:
        print(f"{RED}[FAIL] Execution failed{RESET}")
        if output:
            print(output.strip())
        if error_output:
            print(error_output.strip())

    cleanup_files(exe_file)
    return success


def expected_errors(test_file):
    """Substrings the diagnostics must contain, from `// expect-error:` lines.

    Without these a negative test passes as long as *something* went wrong, so a
    test written for one bug quietly keeps passing when an unrelated error starts
    firing first -- which is exactly how a regression hides.
    """
    wanted = []
    with open(test_file, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            marker = "// expect-error:"
            if marker in line:
                wanted.append(line.split(marker, 1)[1].strip())
    return wanted


def run_negative_test(test_file):
    test_name = Path(test_file).stem
    exe_file = TEST_DIR / f"{test_name}.exe"

    print(f"\n{BLUE}--- Running {test_name} ---{RESET}")
    cleanup_files(exe_file)

    print(f"  Compiling {test_file} (expected failure)...")
    result = run_command([str(PRISMIO_EXE), "build", str(test_file), "-o", str(exe_file)])
    cleanup_files(exe_file)

    output = f"{result.stdout}\n{result.stderr}"

    def fail(reason):
        print(f"{RED}[FAIL] {reason}{RESET}")
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr)
        return False

    if result.returncode == 0:
        return fail("Negative test compiled successfully; it should have been rejected")

    # "aborting due to N previous error(s)" is printed only by diag_finish(), so
    # it distinguishes a program the compiler deliberately rejected from one that
    # crashed it -- a distinction a plain non-zero exit code cannot make.
    if "aborting due to" not in output:
        return fail("Compiler failed without reporting a diagnostic (crash or "
                    "toolchain error, not a rejection)")

    missing = [want for want in expected_errors(test_file) if want not in output]
    if missing:
        return fail(f"Rejected, but not for the expected reason. Missing: {missing}")

    print(f"{GREEN}[PASS] Negative test rejected invalid program{RESET}")
    for line in output.strip().splitlines():
        if line.startswith("error:") and "aborting due to" not in line:
            print(f"  {line}")
    return True


def run_cli_test():
    """`prismio run` with a forward-slash -o path.

    Every other test goes through `build`, so `run` had no coverage at all -- and
    it was broken on Windows for exactly this input: cmd.exe reads `build/x.exe`
    as the command `build` with the switch `/x.exe`, and the failure was reported
    as "Program exited with failure", blaming the compiled program.
    """
    print(f"\n{BLUE}--- Running cli_run_forward_slash ---{RESET}")
    exe_file = TEST_DIR / "cli_probe.exe"
    cleanup_files(exe_file)

    # Deliberately spelled with '/' even on Windows.
    out_arg = f"{TEST_DIR.as_posix()}/cli_probe.exe"
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


AIF_EXPECTED = {
    "tier_zero__Void#0":        "T0",
    "tier_one_string__Void#0":  "T1",
    "tier_one_wide__Void#0":    "T1",
    "tier_two__Void#0":         "T2",
    "tier_three__Void#0":       "T3",
}


def run_aif_test():
    """The AIF memory model's tier derivation, one fixture per SPEC 4.2 clause.

    Asserts the tier of each named record rather than a distribution, because a
    distribution can stay plausible while a clause is broken -- and a broken
    clause here yields a silently wrong tier rather than a crash, which is the
    whole reason aif/prototype/aif.py is kept as an oracle.

    This is the cheap in-suite half of that. The full differential run against
    the oracle is tools/aif_differential.py.
    """
    print(f"\n{BLUE}--- Running aif_tiers ---{RESET}")
    fixture = TEST_DIR / "aif_tiers.psm"

    result = run_command([str(PRISMIO_EXE), "aif", str(fixture)])
    if result.returncode != 0:
        print(f"{RED}[FAIL] `prismio aif` exited {result.returncode}{RESET}")
        print(result.stdout or result.stderr)
        return False

    if "converged   yes" not in result.stdout:
        print(f"{RED}[FAIL] inference did not converge on the fixture{RESET}")
        print(result.stdout)
        return False

    got = {}
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] in AIF_EXPECTED:
            got[parts[0]] = parts[1]

    problems = []
    for symbol, want in AIF_EXPECTED.items():
        if symbol not in got:
            problems.append(f"{symbol}: no manifest record")
        elif got[symbol] != want:
            problems.append(f"{symbol}: expected {want}, got {got[symbol]}")

    if problems:
        print(f"{RED}[FAIL] tier assignment changed{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] AIF assigns every SPEC 4.2 clause its expected tier{RESET}")
    return True


def main():
    print(f"{YELLOW}{'='*60}{RESET}")
    print(f"{YELLOW}Prismio Compiler Test Suite{RESET}")
    print(f"{YELLOW}{'='*60}{RESET}")

    if not PRISMIO_EXE.exists():
        print(f"{RED}[FAIL] Compiler not found at {PRISMIO_EXE}{RESET}")
        sys.exit(1)

    test_files = sorted(TEST_DIR.glob('test_*.psm'))
    neg_test_files = sorted(TEST_DIR.glob('neg_*.psm'))

    if not test_files and not neg_test_files:
        print(f"{RED}[FAIL] No test files found!{RESET}")
        print("Test files should be named test_XX_*.psm or neg_XX_*.psm")
        sys.exit(1)

    print(f"\nFound {len(test_files)} positive test(s)")
    print(f"Found {len(neg_test_files)} negative test(s)")

    passed = 0
    failed = 0

    for test_file in test_files:
        if run_test(test_file):
            passed += 1
        else:
            failed += 1

    for test_file in neg_test_files:
        if run_negative_test(test_file):
            passed += 1
        else:
            failed += 1

    if run_cli_test():
        passed += 1
    else:
        failed += 1

    if run_aif_test():
        passed += 1
    else:
        failed += 1

    print(f"\n{YELLOW}{'='*60}{RESET}")
    print(f"{YELLOW}Test Results{RESET}")
    print(f"{YELLOW}{'='*60}{RESET}")
    print(f"{GREEN}Passed: {passed}{RESET}")
    print(f"{RED}Failed: {failed}{RESET}")
    print(f"Total:  {passed + failed}")

    if failed > 0:
        sys.exit(1)

    print(f"\n{GREEN}All tests passed!{RESET}")
    sys.exit(0)


if __name__ == "__main__":
    main()
