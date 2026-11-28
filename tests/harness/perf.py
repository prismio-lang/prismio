"""The `perf` suite's harness tests (docs/TEST_ORCHESTRATION_PLAN.md, section 4)."""
import os
import re
import sys
import tempfile
from pathlib import Path

from harness.common import *


@harness_test(suite="perf", resources={"cpu": 4, "mem": 1500, "quiet": EXCLUSIVE})
def run_workloads_test():
    """Build the benchmark suite and *run* its representative workloads, comparing checksums.

    Nothing in CI used to execute the realistic programs. On 2026-08-30 an AIF solver
    change emitted a double release for a List consumed into a DataView; a corpus program
    aborted in `list_release` and the entire suite still passed. The only reason it
    surfaced was that someone happened to run a benchmark. Building is not enough, so
    each workload is run and the checksum it prints is compared with the one recorded in
    benchmarks/results/results.json -- which the C++ and Rust arms reproduce -- so a
    miscompile that exits 0 is a failure here too. The set is tools/testkit/workloads.py's
    GATE_WORKLOADS: a wide record, per-frame transients, a component world, retained
    trees, shared maps, tasks and a channel pipeline.
    """
    print(f"\n{BLUE}--- Running workloads ---{RESET}")
    from testkit.workloads import GATE_WORKLOADS, SUITE, recorded_results

    expected = recorded_results()
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-workloads-") as temp_dir:
        exe = Path(temp_dir) / ("suite.exe" if os.name == "nt" else "suite")
        built = run_command([str(PRISMIO_EXE), "build", str(PROJECT_ROOT / SUITE), "-o", str(exe)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] workloads: the benchmark suite did not build{RESET}")
            print(built.stdout or built.stderr)
            return False
        for name in GATE_WORKLOADS:
            out = run_command([str(exe), name, "", ""])
            found = re.search(r"result: (-?\d+)", out.stdout)
            printed = found.group(1) if found else None
            if out.returncode != 0 or printed != str(expected.get(name)):
                problems.append(f"{name}: exited {out.returncode}, printed {printed}, "
                                f"expected {expected.get(name)}")
    if problems:
        print(f"{RED}[FAIL] workloads{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] workloads: {len(GATE_WORKLOADS)} benchmark workloads run and agree with their recorded checksums{RESET}")
    return True


@harness_test(suite="perf", resources={"cpu": 2, "mem": 800, "quiet": EXCLUSIVE})
def run_workload_test():
    """LAYOUT 3 -- `workload`, and the three normative constraints that are
    checkable from outside the compiler.

    The discriminating assertion is the last one, and it is the only one that
    can tell a workload that ran from a workload that was parsed and ignored.
    `test_55`'s `Cell` declares its two hot fields **last** and makes every
    field 4 bytes wide, so padding cannot decide the order and frequency is the
    only input left. A measured profile knows `hot` runs 40x more often than
    `cold` and pulls `hits`/`scratch` to the front; the static estimate weights
    both loops by depth alone, cannot see the ratio, and produces a different
    permutation. Comparing the two IRs is therefore a direct test of whether the
    measured counts reached the search.

    An earlier draft of the fixture declared the fields in frequency order. Both
    profiles then produced the source order, both builds emitted the same IR,
    and the test passed without exercising anything -- the same shape as
    "a rule that fires everywhere passes the positive half of its own test".
    """
    print(f"\n{BLUE}--- Running workload ---{RESET}")
    src = TEST_DIR / "test_55_workload_profile.psm"
    if not src.exists():
        print(f"{RED}[FAIL] {src.name} is missing{RESET}")
        return False

    measured_ll = scratch() / "workload_measured.ll"
    static_src = scratch() / "workload_static_control.psm"
    static_ll = scratch() / "workload_static.ll"

    # The control: the same program with the workload declaration deleted. That
    # is the only difference, so any difference in the IR is the profile's.
    text = src.read_text(encoding="utf-8")
    stripped = re.sub(r"^workload\s+\w+\s*\{.*?^\}\s*$", "", text,
                      flags=re.S | re.M)
    if stripped == text:
        print(f"{RED}[FAIL] could not find a workload declaration to strip{RESET}")
        return False
    static_src.write_text(stripped, encoding="utf-8")

    ok = True
    try:
        r1 = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(measured_ll)])
        if r1.returncode != 0:
            print(f"{RED}[FAIL] the workload build exited {r1.returncode}{RESET}")
            print(r1.stdout or r1.stderr)
            return False
        combined = (r1.stdout or "") + (r1.stderr or "")
        # W2 in the direction that matters here: the workload is supposed to
        # succeed on this fixture, so a fallback warning means the runner broke.
        if "using the static profile" in combined:
            print(f"{RED}[FAIL] the workload fell back to the static profile{RESET}")
            print(combined)
            return False

        r2 = run_command([str(PRISMIO_EXE), "build", str(static_src), "-o", str(static_ll)])
        if r2.returncode != 0:
            print(f"{RED}[FAIL] the static control build exited {r2.returncode}{RESET}")
            return False

        measured = measured_ll.read_text(encoding="utf-8", errors="replace")
        static = static_ll.read_text(encoding="utf-8", errors="replace")

        problems = []

        # W1: build-time only. Not one instrumentation call reaches the shipped
        # program -- and none is even *declared*, so it cannot be reinstated by
        # a later pass or resolved by a linker.
        for symbol in ("rt_profile_field", "rt_profile_alloc", "rt_profile_begin",
                       "rt_profile_dump", "rt_workload_stub"):
            if symbol in measured:
                problems.append(f"W1: {symbol} appears in the shipped IR")

        # The workload's own bodies must not be emitted either. `cell_traffic`
        # is the only caller of nothing, so the check is that no driver-only
        # construct survives: the driver's counter slot is uniquely named.
        if "%wl_i" in measured:
            problems.append("W1: the workload driver's loop counter is in the shipped IR")

        # The profile reached the search: the two builds disagree about where
        # `Cell`'s fields live. Compared on the *stores in make_cell*, which is
        # where a field's index is decided and is stable against renaming.
        def cell_indices(ir):
            body = re.search(r"define ptr @make_cell__Int.*?\n\}", ir, re.S)
            if not body:
                return None
            return re.findall(r"getelementptr inbounds nuw %Cell[\w.]*, ptr %\w+, i32 0, i32 (\d+)",
                              body.group(0))

        mi, si = cell_indices(measured), cell_indices(static)
        if mi is None or si is None:
            problems.append("could not find make_cell in one of the two builds")
        elif len(mi) != 6 or len(si) != 6:
            problems.append(f"expected 6 field stores, got {len(mi or [])} and {len(si or [])}")
        else:
            # The literal writes kind, hits, scratch, label, spare1, spare2 in
            # that order, so mi[1] and mi[2] are where `hits` and `scratch` went.
            if mi[0] != "0":
                problems.append(f"the pinned first field moved: kind is at index {mi[0]}")
            if mi == si:
                problems.append("the measured and static builds chose the same layout; "
                                "the profile did not reach the search")
            if not (mi[1] == "1" and mi[2] == "2"):
                problems.append(f"measured layout did not put the hot fields first: "
                                f"hits at {mi[1]}, scratch at {mi[2]}")

        # W4: two builds with different profiles are behaviourally identical.
        # Asserted by running both, because that is the property -- comparing
        # the IR would only show that they differ, which they are supposed to.
        for label, program in (("measured", src), ("static", static_src)):
            exe = scratch() / f"workload_{label}.exe"
            b = run_command([str(PRISMIO_EXE), "build", str(program), "-o", str(exe)])
            if b.returncode != 0:
                problems.append(f"W4: the {label} build did not produce an executable")
                continue
            run = run_command([str(exe)])
            cleanup_files(exe)
            if run.returncode != 0:
                problems.append(f"W4: the {label} build exited {run.returncode}")
            elif "checksum 3275" not in (run.stdout or ""):
                problems.append(f"W4: the {label} build printed {(run.stdout or '').strip()!r}")

        # W2: a workload that fails to run warns, falls back, and **does not
        # damage the program**. The second half is the one worth a test. The
        # runner leaves global state behind it -- the struct registry that the
        # driver's own generateModule filled -- and an early return that skipped
        # restoring it made the real build skip every struct body it thought was
        # already emitted. A workload that failed to link would then have
        # silently broken the shipped program's types.
        failing_src = scratch() / "workload_failing.psm"
        failing_exe = scratch() / "workload_failing.exe"
        failing_src.write_text(
            text.replace("    measure {\n        let cells = build(50)",
                         "    measure {\n        exit(3)\n        let cells = build(50)"),
            encoding="utf-8")
        try:
            r3 = run_command([str(PRISMIO_EXE), "build", str(failing_src),
                              "-o", str(failing_exe)])
            combined3 = (r3.stdout or "") + (r3.stderr or "")
            if r3.returncode != 0:
                problems.append("W2: a failing workload failed the build")
            elif "using the static profile" not in combined3:
                problems.append("W2: a failing workload did not warn and fall back")
            else:
                run3 = run_command([str(failing_exe)])
                if run3.returncode != 0 or "checksum 3275" not in (run3.stdout or ""):
                    problems.append(
                        f"W2: after a failing workload the program is wrong "
                        f"(exit {run3.returncode}, {(run3.stdout or '').strip()!r})")
        finally:
            cleanup_files(failing_src, failing_exe)

        # W3 for an `extern let`. The driver is linked, so a foreign global no
        # object defines would fail that link and fall back to the static
        # profile; the sandbox gives the driver a private zero instead, as it
        # gives a foreign function a stub. The shipped program still declares
        # the real symbol.
        global_src = scratch() / "workload_foreign_global.psm"
        global_ll = scratch() / "workload_foreign_global.ll"
        global_src.write_text(
            text.replace("struct Cell {",
                         "extern let prismio_workload_nowhere: Int\n\nstruct Cell {", 1)
                .replace("    measure {\n        let cells = build(50)",
                         "    measure {\n        let cells = build(50 + prismio_workload_nowhere)", 1),
            encoding="utf-8")
        try:
            r4 = run_command([str(PRISMIO_EXE), "build", str(global_src), "-o", str(global_ll)])
            combined4 = (r4.stdout or "") + (r4.stderr or "")
            if r4.returncode != 0:
                problems.append("W3: a workload reading a foreign global failed the build")
            elif "using the static profile" in combined4:
                problems.append("W3: a workload reading a foreign global fell back "
                                "instead of reading a stand-in")
            elif "@prismio_workload_nowhere = external global i32" not in \
                    global_ll.read_text(encoding="utf-8", errors="replace"):
                problems.append("W3: the shipped program does not declare the foreign global")
        finally:
            cleanup_files(global_src, global_ll)

        # W3 for a runtime capability. `fileExists` and `inputLines()` reach
        # `file_exists` and `io_stdin_*`, which the sandbox stubs -- and which the
        # runtime module also defines. The two definitions failed to link
        # ("symbol multiply defined"), so every workload importing std.fs,
        # std.process or std.io fell back to the static profile. The stub
        # has to win the link (yield_to_workload_stubs, llvm-api-backend.c).
        capability_src = scratch() / "workload_capability.psm"
        capability_ll = scratch() / "workload_capability.ll"
        capability_src.write_text(
            text.replace("import std.string\n",
                         "import std.string\nimport std.fs\n", 1)
                .replace("    setup {\n",
                         "    setup {\n        let seen = fileExists(\"/\")\n"
                         "        for line in inputLines() { println(line) }\n", 1),
            encoding="utf-8")
        try:
            r5 = run_command([str(PRISMIO_EXE), "build", str(capability_src),
                              "-o", str(capability_ll)])
            combined5 = (r5.stdout or "") + (r5.stderr or "")
            if r5.returncode != 0:
                problems.append("W3: a workload calling a runtime capability failed the build")
            elif "using the static profile" in combined5:
                problems.append("W3: a workload calling a runtime capability fell back: "
                                + elide_middle(combined5))
            elif "`io_stdin_has_line`, which the build sandbox does not provide" \
                    not in combined5:
                problems.append("W3: stdin reached a workload rather than its stub")
        finally:
            cleanup_files(capability_src, capability_ll)

        if problems:
            print(f"{RED}[FAIL] workload{RESET}")
            for p in problems:
                print(f"  {p}")
            ok = False
        else:
            print(f"{GREEN}[PASS] a measured profile changes the layout, and nothing "
                  f"else{RESET}")
    finally:
        cleanup_files(measured_ll, static_ll, static_src)
        # Only this test's own temporaries: other tests are compiling beside theirs now.
        for leftover in TEST_DIR.glob(".prismio-test_55_workload_profile-*"):
            try:
                leftover.unlink()
            except OSError:
                pass

    return ok
