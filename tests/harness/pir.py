"""The `pir` suite's harness tests (the design record, section 4; see tools/testkit/__init__.py)."""
import platform
import subprocess
import tempfile
from pathlib import Path

from harness.common import *


@harness_test(suite="pir")
def run_pir_plan_test():
    """`--pir=plan`: moves at last use (PIR_PLAN §20, P2) and drops on exit edges (P3).

    Each program leaks without the plan (default pins are elsewhere) and is held to its
    count with it, 0 violations. The last one holds the shapes the plan must leave alone.
    Every program asserts its values, and each is also built without the ledger and
    interpreted, whose run stops at a read of what a move emptied or a drop ended: a
    balanced ledger sees neither a read of released memory nor a read of a nulled slot.
    """
    print(f"\n{BLUE}--- Running pir_plan ---{RESET}")
    programs = (
        ("test_273_match_payload_returned.psm", "PASS: match payload returned", 0),
        ("test_399_move_at_last_use.psm", "PASS: move at last use", 0),
        ("test_205_return_on_one_path.psm", "return on one path: ok", 0),
        ("test_406_drops_on_exit_edges.psm", "PASS: drops on exit edges", 0),
        ("test_407_drops_declined.psm", "PASS: drops declined", 146),
    )
    problems = []
    exe_suffix = ".exe" if platform.system() == "Windows" else ""
    with tempfile.TemporaryDirectory(prefix="prismio-pir-plan-") as tmp:
        exe = Path(tmp) / ("plan" + exe_suffix)
        for name, want, leaked in programs:
            source = str(TEST_DIR / name)
            for flags in (["--verify"], []):
                built = run_command([str(PRISMIO_EXE), "build", source, "--pir=plan", *flags, "-o", str(exe)])
                if built.returncode != 0:
                    problems.append(f"{name} {flags} did not build: "
                                    f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")
                    continue
                ran = subprocess.run([str(exe)], capture_output=True, text=True, encoding="utf-8", errors="replace")
                output = (ran.stdout or "") + (ran.stderr or "")
                if ran.returncode != 0 or want not in (ran.stdout or ""):
                    problems.append(f"{name} {flags} exited {ran.returncode} without {want!r}: "
                                    f"{elide_middle(output)}")
                elif flags and (" 0 violation(s)" not in output or f" {leaked} leaked," not in output):
                    problems.append(f"{name} is not clean under the ledger: {elide_middle(output)}")
            interpreted = run_command([str(PRISMIO_EXE), "build", source, "--pir=plan", "--pir-run", "-o", str(exe)])
            if (interpreted.returncode != 0 or want not in (interpreted.stdout or "")
                    or "pir violation" in (interpreted.stderr or "")):
                problems.append(f"{name} interpreted: exit {interpreted.returncode}: "
                                f"{elide_middle((interpreted.stdout or '') + (interpreted.stderr or ''))}")
        reported = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "test_399_move_at_last_use.psm"),
                                "--pir=plan", "--pir-coverage", "-o", str(Path(tmp) / "plan.ll")])
        if "pir plan: 14 read(s) take" not in (reported.stdout or ""):
            problems.append(f"test_399 did not take its 14 reads: {elide_middle(reported.stdout or '')}")
        reported = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "test_406_drops_on_exit_edges.psm"),
                                "--pir=plan", "--pir-coverage", "-o", str(Path(tmp) / "plan.ll")])
        if "pir plan: 9 value(s) end in an `and`/`or` arm, 5 binding(s)" not in (reported.stdout or ""):
            problems.append(f"test_406 did not plan its drops: {elide_middle(reported.stdout or '')}")
    if problems:
        print(f"{RED}[FAIL] pir plan{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] pir plan: moves and drops are clean, right and interpreted alike{RESET}")
    return True
