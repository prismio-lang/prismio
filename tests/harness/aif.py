"""The `aif` suite's harness tests (docs/TEST_ORCHESTRATION_PLAN.md, section 4)."""
import os
import platform
import re
import subprocess
import sys
import tempfile
import time
import traceback
import concurrent.futures
from pathlib import Path

from harness.common import *


AIF_EXPECTED = {
    "tier_zero__Void#0":        "T0",
    "tier_one_string__Void#0":  "T1",
    "tier_one_wide__Void#0":    "T1",
    "tier_one_dropped__Void#0": "T1",
    "tier_two__Void#0":         "T2",
    "tier_three__Void#0":       "T3",
    "tier_four_cyclic__Void#0": "T4b",
    # #0 is the array, a frame slot at every tier and so T0; #1 and #2 are the two
    # allocations nested in its elements, which exist only if the walk descends
    # into them.
    "tier_array_elements__Void#0": "T0",
    "tier_array_elements__Void#1": "T1",
    "tier_array_elements__Void#2": "T1",
}


@harness_test("aif_tiers", suite="aif",
              reads=["tests/aif_tiers.psm"])
def run_aif_test():
    """The AIF memory model's tier derivation, one fixture per SPEC 4.2 clause.

    Asserts the tier of each named record rather than a distribution, because a
    distribution can stay plausible while a clause is broken -- and a broken
    clause here yields a silently wrong tier rather than a crash, which is the
    whole reason tools/aif_oracle/aif.py is kept as an oracle.

    This is the cheap in-suite half of that. The full differential run against
    the oracle is tools/aif_differential.py.
    """
    print(f"\n{BLUE}--- Running aif_tiers ---{RESET}")
    fixture = TEST_DIR / "aif_tiers.psm"

    result = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--manifest"])
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

    # Asserted separately from the tiers because the type graph can be wrong in
    # the direction that reports *fewer* cycles without any tier moving. Lives
    # in --summary, hence the second run.
    summary = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--summary"])
    if "collector needed: 1 of" not in summary.stdout:
        problems.append("Tree reaches itself through Vec<Tree>, but the "
                        "cyclicity report does not say so")

    if problems:
        print(f"{RED}[FAIL] tier assignment changed{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] AIF assigns every SPEC 4.2 clause its expected tier{RESET}")
    return True


@harness_test(suite="aif",
              reads=["tests/aif_loop_bracket.psm"])
def run_aif_loop_bracket_test():
    """Regime (a) keeps a per-iteration allocation out of the caller's region.

    `perIteration`'s Vec dies at the end of each iteration; bracketed into the
    caller's region it stayed until the call returned, and `transient_allocation`
    read 34.7 MB peak for what its own tier holds in 1.75 MB. `wholeCall`'s Vec is
    the control: the same function shape without the loop, still bracketed, so
    this cannot pass by bracketing nothing.
    """
    print(f"\n{BLUE}--- Running aif_loop_bracket ---{RESET}")
    fixture = TEST_DIR / "aif_loop_bracket.psm"
    report = run_command([str(PRISMIO_EXE), "aif", str(fixture)])
    problems = []
    if report.returncode != 0:
        problems.append(f"aif exited {report.returncode}")
    placements = {}
    for line in report.stdout.splitlines():
        found = re.match(r"^\d+\s+aif_loop_bracket\.psm:(\d+):\d+\s+Vec<Int>\s+(.+?)\s{2,}(.+)$", line)
        if found:
            placements[int(found.group(1))] = (found.group(2).strip(), found.group(3).strip())
    per = placements.get(9)
    whole = placements.get(19)
    if per is None or whole is None:
        problems.append(f"expected sites on lines 9 and 19, found {sorted(placements)}")
    else:
        if per[1] == "caller region selected":
            problems.append(f"the per-iteration Vec was bracketed: {per}")
        if whole[1] != "caller region selected":
            problems.append(f"the whole-call control was not bracketed, so the check is vacuous: {whole}")
    if problems:
        print(f"{RED}[FAIL] aif loop bracket{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] a per-iteration Vec keeps its own tier; a whole-call one is still bracketed{RESET}")
    return True


@harness_test(suite="aif")
def run_global_store_escape_test():
    """A value stored into a global is never placed on the storing function's frame.

    The fixture's own exit code says the values come back right, but the frame is
    only reused by luck on a given target, so the placement is asserted as well:
    every allocation it marks `site:` is stored into a module-level `let`, a field
    of one or a container reached through one, and must not be `stack`. The three
    in `clobber` are the control -- the same struct, stored nowhere -- and stay
    on the frame, so this cannot pass by moving everything off it.
    """
    print(f"\n{BLUE}--- Running global_store_escape ---{RESET}")
    fixture = TEST_DIR / "test_352_global_store_escapes.psm"
    problems = []

    marked, control = [], []
    for number, line in enumerate(fixture.read_text(encoding="utf-8").splitlines(), 1):
        if "// site:" in line:
            marked.append(number)
        elif re.match(r"\s+let [abc] = Entry \{", line):
            control.append(number)

    report = run_command([str(PRISMIO_EXE), "aif", str(fixture)])
    if report.returncode != 0:
        problems.append(f"aif exited {report.returncode}")
    placed = {}
    for line in report.stdout.splitlines():
        found = re.match(r"^\d+\s+test_352_global_store_escapes\.psm:(\d+):\d+\s+Entry\s+(.+?)\s{2,}(.+)$",
                         line)
        if found:
            placed[int(found.group(1))] = found.group(2).strip()
    for number in marked:
        if number not in placed:
            problems.append(f"line {number}: no report row for the stored Entry")
        elif placed[number] == "stack":
            problems.append(f"line {number}: stored into a global but placed on the frame")
    if len(marked) < 8:
        problems.append(f"expected at least 8 marked sites, found {len(marked)}")
    for number in control:
        if placed.get(number) != "stack":
            problems.append(f"line {number}: the control is {placed.get(number)!r}, not 'stack', "
                            "so the check is vacuous")

    exe = scratch() / "global_store_escape_probe.exe"
    built = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(exe)])
    if built.returncode != 0:
        problems.append(f"build exited {built.returncode}")
    else:
        ran = run_command([str(exe)])
        if ran.returncode != 0:
            problems.append(f"the fixture exited {ran.returncode}")
        cleanup_files(exe)

    if problems:
        print(f"{RED}[FAIL] global store escape{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] a value stored into a global is not placed on the frame{RESET}")
    return True


@harness_test(suite="aif",
              reads=["tests/aif_array_frame.psm", "tests/aif_array_frame_vec.psm"])
def run_aif_array_frame_test():
    """An array literal is T0, reports as a frame array, and brings no arena.

    The IR half is the one that matters. Reporting an array as a heap block was
    harmless on its own; what it cost was that the analysis counted the array as
    served by an arena, so a call to a function that only built an array was
    wrapped in an arena_push/arena_pop pair serving nothing. The Vec fixture is the
    control: a real allocation, which keeps its bracket, so the count of pushes
    cannot fall to zero by bracketing nothing.
    """
    print(f"\n{BLUE}--- Running aif_array_frame ---{RESET}")
    fixture = TEST_DIR / "aif_array_frame.psm"
    out = scratch() / "aif_array_frame.ll"
    problems = []

    report = run_command([str(PRISMIO_EXE), "aif", str(fixture)])
    found = None
    for line in report.stdout.splitlines():
        match = re.match(r"^\d+\s+aif_array_frame\.psm:(\d+):\d+\s+\[Int\]\s+(.+?)\s{2,}(.+)$", line)
        if match and match.group(1) == "8":
            found = (match.group(2).strip(), match.group(3).strip())
    if found is None:
        problems.append("no report row for the array literal on line 8")
    elif found[0] != "stack":
        problems.append(f"the array is reported as {found[0]!r}, not 'stack'")

    def pushes_in(source: Path):
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(out)])
        if built.returncode != 0:
            problems.append(f"{source.name}: build exited {built.returncode}")
            return None, ""
        ir = out.read_text(encoding="utf-8", errors="replace")
        cleanup_files(out)
        return len(re.findall(r"call void @arena_push\(", ir)), ir

    pushes, ir = pushes_in(fixture)
    if pushes is not None:
        if not re.search(r"alloca \[3 x i32\]", ir):
            problems.append("the array is not an alloca, so the check below is vacuous")
        if pushes != 0:
            problems.append(f"{pushes} arena_push call(s) for a function that builds only an array")
    control, _ = pushes_in(TEST_DIR / "aif_array_frame_vec.psm")
    if control is not None and control != 1:
        problems.append(f"the Vec control has {control} arena_push calls, expected 1, "
                        "so the array check cannot tell a missing bracket from none")

    if problems:
        print(f"{RED}[FAIL] aif array frame{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] an array is T0 and reports as one, brings no arena, and the Vec control still does{RESET}")
    return True


@harness_test(suite="aif",
              reads=["tests/aif_human_report.psm", "tests/aif_vec_display.psm"])
def run_aif_human_report_test():
    """The default is an interactive explanation; the manifest is explicit.

    This fixture deliberately imports std.io without calling it. It is the shape
    that made the old report especially confusing: four mangled library records
    looked like four allocations performed by an otherwise empty main.
    """
    print(f"\n{BLUE}--- Running aif_human_report ---{RESET}")
    fixture = TEST_DIR / "aif_human_report.psm"
    problems = []

    human = run_command([str(PRISMIO_EXE), "aif", str(fixture)])
    if human.returncode != 0:
        problems.append(f"default report exited {human.returncode}")
    else:
        text = human.stdout
        for wanted in ("AIF analysis", "Storage plan", "Your code",
                       "No allocation sites found", "Imported modules",
                       "potential allocation site(s), not runtime allocation counts",
                       "std.io.output:", "unique heap", "returned to the caller",
                       "--why=<ID>", "--manifest"):
            if wanted not in text:
                problems.append(f"default report does not contain {wanted!r}")
        if "aif-manifest 1" in text:
            problems.append("default report still prints the compiler manifest")
        if "prismioStdIo" in text:
            problems.append("default report exposes mangled stdlib symbols")
        if "/stdlib/" in text:
            problems.append("default report exposes the installed stdlib path")

    # The ID is read off the report rather than hardcoded. Site numbering runs
    # backwards through std.io's source, so any edit to that module renumbers
    # every site, and asking for `--why=1` asserted whichever allocation
    # happened to sort first rather than the one this case is about.
    returned = re.search(r"^(\d+)\s+\S+\s+\S+\s+unique heap\s+returned to the caller\s*$",
                         human.stdout, re.M)
    if not returned:
        problems.append("default report lists no unique-heap site to explain")
    else:
        site = returned.group(1)
        why = run_command([str(PRISMIO_EXE), "aif", str(fixture), f"--why={site}"])
        if why.returncode != 0:
            problems.append(f"numeric --why exited {why.returncode}")
        else:
            for wanted in (f"Allocation {site}", "Storage    unique heap",
                           "Reason     returned to the caller", "E-RETURN"):
                if wanted not in why.stdout:
                    problems.append(f"numeric --why does not contain {wanted!r}")

    manifest = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--manifest"])
    if manifest.returncode != 0:
        problems.append(f"--manifest exited {manifest.returncode}")
    else:
        if not manifest.stdout.startswith("aif-manifest 1\n"):
            problems.append("--manifest no longer emits the stable manifest")
        if "prismioStdIo" not in manifest.stdout:
            problems.append("--manifest lost stable allocation symbols")

    # The report shows a vector as `Vec`; the manifest keeps the `List` key the
    # oracle and the manifest diff compare against (docs/COLLECTIONS.md).
    vec_fixture = TEST_DIR / "aif_vec_display.psm"
    vec_human = run_command([str(PRISMIO_EXE), "aif", str(vec_fixture)])
    vec_row = re.search(r"^(\d+)\s+aif_vec_display\.psm:\S+\s+(\S+)", vec_human.stdout, re.M)
    if vec_human.returncode != 0 or not vec_row:
        problems.append("the Vec fixture's report lists no site of its own")
    else:
        if vec_row.group(2) != "Vec<Vec<Int>>":
            problems.append(f"the report spells a vector type {vec_row.group(2)!r}, not 'Vec<Vec<Int>>'")
        vec_why = run_command([str(PRISMIO_EXE), "aif", str(vec_fixture),
                               f"--why={vec_row.group(1)}"])
        if "Type       Vec<Vec<Int>>" not in vec_why.stdout:
            problems.append("--why does not spell the vector type `Vec<Vec<Int>>`")
    vec_manifest = run_command([str(PRISMIO_EXE), "aif", str(vec_fixture), "--manifest"])
    if "List<List<Int>>" not in vec_manifest.stdout:
        problems.append("--manifest no longer carries the `List<List<Int>>` key")

    if problems:
        print(f"{RED}[FAIL] the AIF interactive and manifest surfaces are not separated{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False

    print(f"{GREEN}[PASS] AIF defaults to human storage decisions; --manifest preserves the CI form{RESET}")
    return True


# REQUIREMENTS 15. symbol -> (tier, thread affinity).
#
# The thread column carries the weight here, not the tier. Two of these records
# assert `Transferred` at a tier that has no count at all, which is a fact the
# ladder cannot express and the whole reason the manifest grew the column: a
# value sliding Transferred -> CrossThread turns a non-atomic count into an
# atomic one and moves no tier at all in either direction.
AIF_CONCURRENCY_EXPECTED = {
    # E-SPAWN-J. The task is joined before the scope exits, so the argument
    # never leaves the frame it was allocated in -- a stack slot handed to
    # another thread, which is sound only because the join is proved.
    "joined_stays_local__Void#0":            ("T0", "Transferred"),
    # T-SPAWN-MOVE, and the assertion this session lives or dies by. Moved into
    # the task through the list that holds it, so one thread reaches it at a
    # time. Transferred, never CrossThread.
    "transferred_is_not_atomic__Void#0":     ("T1", "Transferred"),
    "transferred_is_not_atomic__Void#1":     ("T1", "Transferred"),
    # The control. Same shape, no task -- and if this ever reads Transferred the
    # rules are firing on everything rather than on task boundaries, which is
    # the failure mode that would otherwise still look green.
    "no_task_at_all__Void#0":                ("T0", "Isolated"),
    # T-STATIC: retained by an FFI callee, so E = Global, in a program with
    # tasks.
    "static_root_is_cross_thread__Void#0":   ("T4a", "CrossThread"),
    "static_root_is_cross_thread__Void#1":   ("T0", "Transferred"),
    # E-SPAWN with an early return between spawn and join, so nothing proves the
    # task is awaited and escape goes to Global.
    "unjoined_is_cross_thread__Void#0":      ("T4a", "CrossThread"),

    # E-SPAWN-J where the join is not the next statement. Every one of these
    # read T4a/CrossThread under the original forward scan, whose early-exit
    # helper walked the rest of the block instead of the statement it was given
    # and so was answered by the block's own closing `return join t`. A single
    # inert statement between a spawn and its join cost an atomic count.
    #
    # They are asserted as a group because the failure was a group: no single
    # one of them is exotic, and the shape that *did* work -- joining on the
    # very next statement -- is the one nobody writes.
    "one_statement_between__Void#0":         ("T0", "Transferred"),
    "loop_between_spawn_and_join__Void#0":   ("T0", "Transferred"),
    "break_is_absorbed_by_its_loop__Void#0": ("T0", "Transferred"),
    "join_on_both_paths__Void#0":            ("T0", "Transferred"),
    # ...and the direction that must NOT move. One arm leaves without joining,
    # so escape goes to Global even though a join is visible further down.
    # Being wrong here is a use-after-free, not a lost tier.
    "one_path_escapes_unjoined__Void#0":     ("T4a", "CrossThread"),
}


# T-SPAWN-SHARE, in its own file because the `@elem` key is one per container
# base type -- see that file's header for why the contrast cannot be local.
AIF_CONCURRENCY_SHARED_EXPECTED = {
    "shared_element_crosses__List_Struct_Item#0": ("T1", "Transferred"),
    "shared_element_crosses__List_Struct_Item#1": ("T4a", "CrossThread"),
}


# The other half of that contrast, and the reason it is asserted here rather
# than described in a comment: identical aliasing, identical `list_get` between
# two containers, no spawn anywhere -- and a **non-atomic** count. If a change
# lands this at T4a then T-SPAWN-SHARE has stopped testing the task boundary and
# started testing sharing, which is a different and much more expensive claim.
AIF_NO_TASK_CONTROL = {
    "overwrite_releases__Void#1": ("T3", "Isolated"),
    "overwrite_releases__Void#2": ("T3", "Isolated"),
}


def aif_thread_records(source):
    """symbol -> (tier, thread) from a manifest run."""
    result = run_command([str(PRISMIO_EXE), "aif", str(source), "--manifest"])
    if result.returncode != 0:
        return None, result
    got = {r: (v["tier"], v["thread"])
           for r, v in manifest_records(result.stdout).items()}
    return got, result


@harness_test(suite="aif",
              reads=["tests/aif_concurrency.psm", "tests/aif_concurrency_shared.psm", "tests/test_48_aif_shared_elements.psm"])
def run_aif_concurrency_test():
    """INFERENCE 4.3's thread module, one fixture function per rule.

    The `T` domain was vacuous for the whole life of this compiler -- the
    language had no tasks, so every value was Isolated, T4a was unreachable by
    construction, and SPEC 4.2's two `T` conjuncts were tautologies. There was
    therefore no program at all that could tell a correct thread module from an
    absent one, and COMPILER-AUDIT finding 7 recorded that as "actually
    simplifying, for now". REQUIREMENTS 15 ended it; this is the coverage.

    Asserts the thread affinity as well as the tier, because the regression this
    domain has does not move a tier. SPEC 11 item 10 promises no atomic counts
    on the common path, and what breaks that promise is a value drifting from
    Transferred to CrossThread -- which at T1 changes nothing on the ladder and
    everything in the emitted code.
    """
    print(f"\n{BLUE}--- Running aif_concurrency ---{RESET}")

    problems = []
    for fixture, expected in (
            ("aif_concurrency.psm", AIF_CONCURRENCY_EXPECTED),
            ("aif_concurrency_shared.psm", AIF_CONCURRENCY_SHARED_EXPECTED),
            ("test_48_aif_shared_elements.psm", AIF_NO_TASK_CONTROL)):
        src = TEST_DIR / fixture
        got, result = aif_thread_records(src)
        if got is None:
            problems.append(f"{fixture}: `aif` exited {result.returncode}")
            continue
        if "converged   yes" not in result.stdout:
            problems.append(f"{fixture}: inference did not converge")
            continue
        for symbol, want in expected.items():
            if symbol not in got:
                problems.append(f"{fixture}: {symbol}: no manifest record")
            elif got[symbol] != want:
                problems.append(f"{fixture}: {symbol}: expected "
                                f"{want[0]}/{want[1]}, got "
                                f"{got[symbol][0]}/{got[symbol][1]}")

    # T4a had never been emitted by this compiler before REQUIREMENTS 15.
    # Asserting that it now is, separately from the per-record checks, so that
    # deleting the fixture functions cannot quietly turn this back into a test
    # of nothing.
    got, _ = aif_thread_records(TEST_DIR / "aif_concurrency.psm")
    if got is not None and not any(t == "T4a" for t, _th in got.values()):
        problems.append("no T4a record: the sub-class is unreachable again")

    # And the half the manifest cannot show: that the distinction survives into
    # emitted code.
    #
    # T4a had never been emitted by this compiler, so "the solver derives it"
    # and "the binary counts it atomically" are two claims and only the first is
    # a manifest fact. The pair below is the discrimination itself -- identical
    # aliasing in both programs, `list_get` between two containers in both, and
    # the only difference is that one hands a container to a task.
    with tempfile.TemporaryDirectory() as tmp:
        emitted = {}
        for fixture in ("aif_concurrency_shared.psm", "test_48_aif_shared_elements.psm"):
            out = os.path.join(tmp, fixture + ".ll")
            r = run_command([str(PRISMIO_EXE), "build",
                             str(TEST_DIR / fixture), "-o", out])
            if r.returncode != 0 or not os.path.exists(out):
                problems.append(f"{fixture}: build failed, cannot check the count")
                continue
            text = Path(out).read_text(encoding="utf-8", errors="replace")
            emitted[fixture] = set(
                re.findall(r"@list_set_elem_owner\(ptr [^,]*, i32 (\d+)\)", text))

        # 6 is AIF_ELEM_RC_ATOMIC, 3 is AIF_ELEM_RC -- src/ir/context.psm.
        if emitted.get("aif_concurrency_shared.psm") != {"6"}:
            problems.append(
                "the cross-thread element is not counted atomically: expected "
                "list_set_elem_owner disposition {'6'}, got "
                f"{emitted.get('aif_concurrency_shared.psm')}")
        if emitted.get("test_48_aif_shared_elements.psm") != {"3"}:
            problems.append(
                "the thread-local element stopped using a plain count: expected "
                "list_set_elem_owner disposition {'3'}, got "
                f"{emitted.get('test_48_aif_shared_elements.psm')} -- SPEC 11 "
                "item 10 is that atomics stay off the common path")

    if problems:
        print(f"{RED}[FAIL] thread affinity changed{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] INFERENCE 4.3 assigns every rule its expected "
          f"affinity; T4a is reachable and counts atomically{RESET}")
    return True


@harness_test(suite="aif",
              reads=["runtime/lang_runtime.c", "src/ir/context.psm"])
def run_elem_mode_agreement_test():
    """The element-ownership mode is one wire protocol with two definitions.

    Codegen emits the mode from `AIF_ELEM_*` in src/ir/context.psm, the analysis
    (src/aifcore, which imports that same list) answers with it, and the runtime
    compares against `AIF_ELEM_*` in runtime/lang_runtime.c. The int crosses one
    seam and is never re-derived, so both have to agree on every name *and* every
    value, forever. It was three definitions until the analysis moved out of C.

    Nothing checked that until now, and the failure is silent in the worst way: a
    variant inserted in one list and not the others still builds, and releases
    elements with the wrong deallocator -- a violation rather than a leak, and
    therefore memory corruption rather than lost bytes.

    The runtime's copy was spelled `XEFY_ELEM_*` until 2026-08-23, after Xefy, the
    framework this language is built to carry. Besides being backwards -- the list
    is Prismio's, not a consumer's -- the odd prefix is what made the drift
    invisible: a grep for `AIF_ELEM_CYCLE` found two of the three sites and gave
    no sign the third existed.
    """
    print(f"\n{BLUE}--- Running elem_mode_agreement ---{RESET}")

    sources = {
        "src/ir/context.psm":        r"(?:let|const)\s+AIF_ELEM_([A-Z_]+)\s*=\s*(\d+)",
        "runtime/lang_runtime.c":    r"#define\s+AIF_ELEM_([A-Z_]+)\s+(\d+)",
    }

    tables = {}
    for path, pattern in sources.items():
        text = (PROJECT_ROOT / path).read_text(encoding="utf-8")
        found = dict(re.findall(pattern, text))
        if not found:
            print(f"{RED}[FAIL] no AIF_ELEM_* definitions found in {path} -- this "
                  f"check has gone blind, which is the thing it exists to "
                  f"prevent{RESET}")
            return False
        tables[path] = found

    # Compared pairwise against the frontend's copy, because that is the one that
    # decides what the emitted int means.
    reference_path = "src/ir/context.psm"
    reference = tables[reference_path]
    problems = []
    for path, table in tables.items():
        if path == reference_path:
            continue
        for name in sorted(set(reference) | set(table)):
            if name not in table:
                problems.append(f"{path} is missing AIF_ELEM_{name}, which "
                                f"{reference_path} defines as {reference[name]}")
            elif name not in reference:
                problems.append(f"{path} defines AIF_ELEM_{name}={table[name]}, "
                                f"which {reference_path} does not know")
            elif table[name] != reference[name]:
                problems.append(f"AIF_ELEM_{name} is {reference[name]} in "
                                f"{reference_path} and {table[name]} in {path}")

    # Code only. The comment above the defines explains what they used to be
    # called, and a bare substring search over the file trips on that -- which it
    # did, the first time this check ran.
    for path in ("runtime/lang_runtime.c",):
        text = (PROJECT_ROOT / path).read_text(encoding="utf-8")
        code = "\n".join(line.split("//")[0] for line in text.split("\n"))
        if "XEFY_ELEM_" in code:
            problems.append(f"{path} still spells these XEFY_ELEM_* in code, "
                            f"which puts the second definition back out of grep "
                            f"range of the first")

    if problems:
        print(f"{RED}[FAIL] the two element-mode tables disagree -- elements "
              f"will be released with the wrong deallocator{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] all {len(reference)} element modes agree across "
          f"src/ir/context.psm and lang_runtime.c{RESET}")
    return True


@harness_test(suite="aif", timeout=300,
              reads=["src/aif/contracts.psm", "tools/aif_oracle/aif.py"])
def run_oracle_vocabulary_test():
    """The compiler and `tools/aif_oracle/aif.py` must know the same builtins.

    The differential compares *answers* on a fixed list of sources. It cannot see
    a builtin neither list happens to call -- and that is not hypothetical: when
    `list_new_with_capacity` was added on 2026-08-14 the oracle was not told, the
    differential agreed on all 13 sources, and any program using it disagreed by
    eight tiers (`opaque-ret: compiler=0 oracle=5`).

    The asymmetry that makes this class of omission silent is worth stating: every
    `extern fn` a *source* declares carries its FFI contract in the AST, so the
    oracle reads it and its fallback tables never fire. A **builtin** is never
    declared by anyone, so the tables are the only place it can be known, and an
    omission costs nothing until some source calls it.

    So this compares the two tables directly rather than comparing answers. It is
    the cheap half of "adding a builtin is an oracle change even when no rule
    moved"; `tests/test_56_list_capacity.psm` in the differential's source list is
    the expensive half.
    """
    print(f"\n{BLUE}--- Running oracle_vocabulary ---{RESET}")
    contracts = (PROJECT_ROOT / "src" / "aif" / "contracts.psm").read_text(encoding="utf-8")
    oracle_src = (PROJECT_ROOT / "tools" / "aif_oracle" / "aif.py").read_text(encoding="utf-8")

    # This scraper is the thing the check depends on seeing, and it has now gone
    # blind twice: once when the compiler moved off the C string layer in 2026-08
    # and `== 1` disappeared, and again on 2026-09-03 when `strEquals(name, "x")`
    # became `name.equals("x")`. Both times it reported itself blind rather than
    # passing on an empty set, which is the whole reason the `not produces` guard
    # below is part of the failure condition. Accepts either spelling, so the
    # remaining `strEquals` call sites elsewhere in the tree can migrate without
    # breaking it a third time.
    # Scoped to one function's body: contracts.psm holds more than one table of
    # this shape, and scraping the whole file merges them.
    def compiler_table(function):
        at = contracts.find(f"fn {function}(name: String) -> Bool {{")
        if at < 0:
            return set()
        body = contracts[at:contracts.index("\n}\n", at)]
        found = re.findall(
            r'(?:strEquals\(name,\s*"([a-z_0-9]+)"\)|name\.equals\("([a-z_0-9]+)"\))'
            r'\)\s*\{\s*return true\s*\}', body)
        return {a or b for a, b in found}

    def oracle_table(name):
        at = oracle_src.find(f"{name} = {{")
        if at < 0:
            return set()
        return set(re.findall(r"'([a-z_0-9]+)'", oracle_src[at:oracle_src.index("}", at)]))

    produces = compiler_table("aifFfiProduces")
    oracle = oracle_table("FFI_RETURNS_PRODUCE")
    if not produces or not oracle:
        print(f"{RED}[FAIL] could not locate both produce lists -- this check has "
              f"gone blind, which is the thing it exists to prevent{RESET}")
        return False

    missing = sorted(produces - oracle)
    extra = sorted(oracle - produces)
    if missing or extra:
        print(f"{RED}[FAIL] the compiler and the oracle disagree about which "
              f"runtime calls produce an owned value{RESET}")
        for name in missing:
            print(f"  {name}: the compiler produces it, aif.py does not know it -- "
                  f"the oracle will call it opaque and sink every user to T3")
        for name in extra:
            print(f"  {name}: aif.py produces it, the compiler does not")
        return False

    # The producers an arena may serve. A name on one list only is placed in an
    # arena by one engine and not the other, and the oracle's `foreign` set --
    # which decides T0 for a struct return -- drifts with it.
    arena = compiler_table("aifFfiAllocatesThroughArenaHint")
    oracle_arena = oracle_table("FFI_ALLOCATES_THROUGH_ARENA_HINT")
    if not arena or not oracle_arena:
        print(f"{RED}[FAIL] could not locate both arena-hint lists -- this check has "
              f"gone blind{RESET}")
        return False
    if arena != oracle_arena:
        print(f"{RED}[FAIL] the compiler and the oracle disagree about which "
              f"runtime calls allocate through the arena hint{RESET}")
        for name in sorted(arena - oracle_arena):
            print(f"  {name}: only src/aif/contracts.psm lists it")
        for name in sorted(oracle_arena - arena):
            print(f"  {name}: only aif.py lists it")
        return False

    print(f"{GREEN}[PASS] compiler and oracle agree on all {len(produces)} "
          f"producing runtime calls and all {len(arena)} arena-served ones{RESET}")
    return True


@harness_test(suite="aif",
              reads=["tools/aif_manifest_diff.py", "benchmarks/**", "tests/test_57_pin_tiers.psm", "tests/test_58_region_serves.psm"])
def run_manifest_parseable_test():
    """SPEC 6.2 / 11 item 8 -- every record the manifest emits must be a record
    the gate can read.

    `tools/aif_manifest_diff.py` ignores lines it cannot parse, which is right for
    comments and blank lines and was silently wrong for real records: a field
    wider than its column was emitted unpadded and ran into the next one, so the
    line stopped matching the record shape and the symbol vanished from the diff.
    `g5_asset_cache.psm` emitted 14 records and the differ saw 13 -- a **tier
    regression on `load_material` could not have failed CI**, on a symbol in this
    project's own corpus.

    Checked by counting rather than by looking for that one symbol, because the
    next overflow will be a different name: any record line the emitter writes and
    the parser drops is the same defect.
    """
    print(f"\n{BLUE}--- Running manifest_parseable ---{RESET}")
    sys.path.insert(0, str(PROJECT_ROOT / "tools"))
    try:
        from aif_manifest_diff import parse as parse_manifest
    except ImportError as exc:
        print(f"{RED}[FAIL] cannot import the manifest differ: {exc}{RESET}")
        return False

    sources = sorted((PROJECT_ROOT / "benchmarks" / "hosted" / "prismio").glob("*.psm"))
    sources += [TEST_DIR / "test_57_pin_tiers.psm", TEST_DIR / "test_58_region_serves.psm"]

    problems = []
    tmp = scratch() / "_manifest_parse.txt"
    for src in sources:
        result = run_command([str(PRISMIO_EXE), "aif", str(src), "--manifest"])
        if result.returncode != 0:
            continue
        tmp.write_text(result.stdout, encoding="utf-8")
        _header, records = parse_manifest(tmp)
        # A record line is one carrying a `symbol#ordinal`, which is exactly what
        # the emitter writes and nothing else in the manifest does.
        emitted = [l for l in result.stdout.splitlines()
                   if "#" in l and not l.startswith("#") and l.strip()]
        if len(records) != len(emitted):
            missing = len(emitted) - len(records)
            problems.append(f"{src.name}: emitted {len(emitted)} records, differ "
                            f"parsed {len(records)} -- {missing} invisible to the gate")
    if tmp.exists():
        tmp.unlink()

    if problems:
        print(f"{RED}[FAIL] the manifest emits records its own differ cannot read{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] every manifest record is parseable by the CI differ{RESET}")
    return True


@harness_test("region_diagnostics", suite="aif",
              reads=["tests/test_49_aif_struct_fields.psm", "tests/test_57_pin_tiers.psm", "tests/test_58_region_serves.psm"])
def run_region_diagnostic_test():
    """SPEC 5.2 / 5.2.1 / 5.2.1.1 -- the arena diagnostics, and which regions the
    warning is allowed to fire on.

    test_58 asserts at run time that an arena serves what it claims. This asserts
    the *reporting* halves, each of which was a live defect:

      * a region serving nothing warns, and one serving something does NOT. The
        second half is the discriminator -- a warning that fired on every region
        would satisfy any test that only looked for the text. Since call-site
        placement landed (2026-08-16) the fixture has both, so the pairing is
        checked in both directions on one compilation. Regime (a)'s
        generalisation (2026-08-28) moved `shared_work` from the inert side to
        the serving side, and `outside_work` took its place.
      * a T1 site with no arena reports `region:none`. It reported
        `region:scope`, one column away from the real placements `region:auto`
        and `region:<name>`, so g2_region.psm's manifest showed `region:` on
        every T1 line while the arena served nothing and a reader took it as
        confirmation.
      * `peak-bytes` counts what the code generator will actually route to the
        arena, and nothing else. It has been wrong in both directions: inflated
        when the cost model omitted the codegen gate's `in_container` clause
        (test_49 reported 64 bytes for an arena holding zero), and deflated when
        call-site placement started routing a callee's allocations to a region
        the estimator was not counting -- which is the direction that makes a
        `region name pin(N)` gate pass a budget the binary exceeds.
    """
    print(f"\n{BLUE}--- Running region_diagnostics ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_58_region_serves.psm"
    exe = scratch() / "test_58_region_serves.exe"
    build = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(exe)])
    text = (build.stdout or "") + (build.stderr or "")

    # Two regions serve and two do not, in one compilation. Asserting all four is
    # what makes this a discriminator rather than a substring search: a warning
    # that fired on everything fails the second pair, one that fired on nothing
    # fails the first.
    for region in ("outlived_work", "outside_work"):
        if f"region {region} serves no allocation" not in text:
            problems.append(f"no warning for `{region}`, which serves nothing -- "
                            f"the region that a bracket declines is exactly the one "
                            f"a programmer needs told about")
    for region in ("work", "callee_work", "shared_work"):
        if f"region {region} serves no allocation" in text:
            problems.append(f"warned about `{region}`, which serves 50 allocations -- "
                            f"the diagnostic is firing on every region, not on inert ones")
    if "cannot reach it" not in text:
        problems.append("the warning lost its note, which is the half that names the repair")
    cleanup_files(exe)

    manifest = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--manifest"])
    placements = {r: v["placement"]
                  for r, v in manifest_records(manifest.stdout).items()}
    if placements.get("serves__Void#1") != "region:work":
        problems.append(f"serves__Void#1: expected region:work, got "
                        f"{placements.get('serves__Void#1')}")
    # SPEC 5.2.1.1. The bracketed site, and the two that are deliberately not.
    # `make` and `make_out` have identical bodies and identical tiers, so the
    # placement column is the only place the difference is visible at all.
    if placements.get("make__Int#0") != "region:callee_work":
        problems.append(f"make__Int#0: expected region:callee_work from the "
                        f"bracketed call, got {placements.get('make__Int#0')}")
    if placements.get("make_out__Int#0") == "region:outlived_work":
        problems.append("make_out__Int#0 was bracketed into a region its return "
                        "value outlives -- obligation 3 is not being applied")
    # Regime (a) generalised, 2026-08-28: `make_shared` has two call sites and
    # both are inside `shared_work`, so the body only ever runs with that arena
    # innermost and the bracket is legal. This assertion used to read the other
    # way; `make_outside` below is what keeps it honest.
    if placements.get("make_shared__Int#0") != "region:shared_work":
        problems.append(f"make_shared__Int#0: expected region:shared_work -- two "
                        f"call sites inside one region is one placement regime -- "
                        f"got {placements.get('make_shared__Int#0')}")
    if placements.get("make_outside__Int#0") == "region:outside_work":
        problems.append("make_outside__Int#0 was bracketed with a call site outside "
                        "the region -- that body would allocate from an arena on one "
                        "path and the heap on another, and regime (a) is not being "
                        "applied")
    # The bracket is recorded, which SPEC 5.2.1.1 requires of an implementation
    # using regime (a): the placement can be removed by an edit somewhere else in
    # the file, so it has to be visible in a diff.
    if "bracketed calls (SPEC 5.2.1.1 regime (a))" not in manifest.stdout:
        problems.append("the manifest does not record which call sites were bracketed")
    elif "#   make " not in manifest.stdout:
        problems.append("the bracketed-calls section does not name `make`")
    # 136 and not 128 since `shared_work` started serving its 51 too: the peak is
    # the largest root-to-leaf chain, and these regions are siblings, so it is the
    # largest single one rather than the sum.
    if "peak-bytes  136 bytes" not in manifest.stdout:
        problems.append("peak-bytes for a region that serves 51 sites is not 136")

    # `region:none` -- a T1 site the heap serves. test_57's list sites are the
    # case, and `region:scope` must not come back.
    other = run_command([str(PRISMIO_EXE), "aif",
                         str(TEST_DIR / "test_57_pin_tiers.psm"), "--manifest"])
    if "region:none" not in other.stdout:
        problems.append("no T1 site reports region:none")
    if "region:scope" in other.stdout:
        problems.append("region:scope is back -- it reads as a placement and is not one")

    # The budget estimate, and it has read three different numbers for three
    # different reasons: 64 before the cost model learned the codegen gate's
    # in_container clause, 0 after, and 108 once automatic call-site placement
    # gave test_49 an arena that actually holds something. The assertion is not
    # "zero" and never was -- it is that the estimate describes the build, so a
    # non-zero arena must report non-zero bytes and an inert one must report 0.
    # test_57 below still covers the inert direction.
    budget = run_command([str(PRISMIO_EXE), "aif",
                          str(TEST_DIR / "test_49_aif_struct_fields.psm"), "--manifest"])
    if "peak-bytes  108 bytes" not in budget.stdout:
        problems.append("test_49's arena bytes do not describe the build: expected "
                        "108, the arena automatic placement gives it "
                        "(REQUIREMENTS 19's gate reads this)")

    # SPEC 6.3's placement witness. `--why` explained the tier and said nothing
    # about where the value lives, so a reader who fixed the tier found the
    # binary unchanged -- three sessions running. The gate short-circuits, so the
    # load-bearing property is that EVERY blocker is listed, not the first.
    # `make_outside` and not `make`: since 2026-08-16 `make` is bracketed and so
    # reports a placement rather than a blocker list, and since 2026-08-28 so is
    # `make_shared`. `make_outside` is the same allocation in the same shape that
    # regime (a) still declines -- a call site outside the region -- so it is the
    # record that exercises every clause of the gate.
    why = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--why=make_outside__Int#0"])
    if "placement" not in why.stdout:
        problems.append("--why does not report placement at all")
    if "the tier is not T1" not in why.stdout:
        problems.append("--why does not report the tier blocker")
    if "in its own function" not in why.stdout:
        problems.append("--why stopped at the tier and did not report no_region -- "
                        "the short-circuit this exists to defeat")
    if "lexical scope (SPEC 5.2.1)" not in why.stdout:
        problems.append("--why lost the note explaining why no escape-lattice "
                        "change moves a callee's allocation")

    served_why = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--why=serves__Void#1"])
    if "region:work" not in served_why.stdout:
        problems.append("--why does not name the arena for a site that IS served")
    if "no arena serves this site" in served_why.stdout:
        problems.append("--why reports a served site as heap-placed")
    if "this call was bracketed" in served_why.stdout:
        problems.append("--why calls a lexically-served site bracketed -- the two "
                        "are different facts and a reader acts on them differently")

    # SPEC 5.2.1.1. A bracketed site names the arena *and* says it is in a caller.
    # Without the second half a reader cannot tell a placement they wrote from one
    # the compiler inferred on their behalf, and only the second can disappear
    # because of an edit to a different function.
    bracketed_why = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--why=make__Int#0"])
    if "region:callee_work" not in bracketed_why.stdout:
        problems.append("--why does not name the arena for the bracketed site")
    if "this call was bracketed" not in bracketed_why.stdout:
        problems.append("--why reports a bracketed site as an ordinary lexical "
                        "placement, so nothing says the placement depends on there "
                        "being exactly one call site")

    if problems:
        print(f"{RED}[FAIL] the arena diagnostics do not describe the build{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] region diagnostics: inert regions warn, served ones do not, "
          f"and --why names every blocker{RESET}")
    return True


@harness_test(suite="aif")
def run_nonlexical_extent_test():
    """M3.2 -- an arena bracketed between statements rather than at the braces.

    `generateBlock` opens the arena at the first statement that puts something in
    it and closes it after the last statement that still reads something it
    holds. Every early exit taken *between* those two points then has to pop
    exactly once, and the two ways to get it wrong are invisible in a value on
    their own: a missed pop holds the chunks for the rest of the program, and a
    doubled one releases the caller's arena and lets the next allocation bump
    over memory that is still live.

    Three assertions, in the order that makes the later ones mean anything:

      1. **The arenas are there.** `test_71_nonlexical_extent.psm` is only a
         guard while the feature actually fires on it -- the first version of the
         fixture shared one `build` helper across all five shapes, which made
         every callee `br-shared`, placed **no arena at all**, and passed. So the
         extents are read from `AIF_STMT_TRACE` first, and a fixture that stopped
         being bracketed fails here rather than reporting a pass.
      2. **At least one arena opens after the block's first statement.** That is
         the thing a lexical bracket cannot do, and it is what separates "the
         range was computed" from "the range was computed and then ignored".
      3. **The program is right and the ledger is clean.** The five shapes are
         the five ways out of an extent; a doubled pop shows up as a wrong sum
         from `nested_extents`, whose outer arena holds the handle the inner loop
         would bump over.

    `released` and `violation(s)`, never `leaked` -- arena memory does not pass
    the shim, so the heap side of this program is small and what matters is that
    whatever *is* on the heap is fully reclaimed and nothing is freed twice.
    """
    print(f"\n{BLUE}--- Running nonlexical_extent ---{RESET}")
    problems = []
    fixture = TEST_DIR / "test_71_nonlexical_extent.psm"

    env = dict(os.environ)
    env["AIF_STMT_TRACE"] = "1"
    traced = subprocess.run([str(PRISMIO_EXE), "aif", str(fixture)],
                            capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    extents = [(int(m.group(1)), int(m.group(2)), int(m.group(3)))
               for m in re.finditer(r"arena scope (\d+) emit \[(\d+),(\d+)\]",
                                    traced.stderr)]
    # std/io's `print`/`println` are one-statement bodies and emit [0,0], which a
    # lexical bracket produces too. The fixture's own six extents are the ones
    # that span more than a single statement.
    spanning = [e for e in extents if e[2] > e[1] or e[1] > 0]
    if len(spanning) < 10:
        problems.append(
            f"{len(spanning)} arena(s) with a non-trivial extent, expected at "
            f"least 10 -- one per shape, one per `held` list that outlives a "
            f"loop, and one in each of the two returning callees. The fixture is "
            f"no longer being bracketed, so every assertion below passes against "
            f"a program this feature never touched, and it has to be rewritten "
            f"rather than trusted. `AIF_BRACKET_TRACE=1` names the site and the "
            f"binding that blocked it.")
    if not any(lo > 0 for _, lo, _ in extents):
        problems.append(
            "no arena opens after its block's first statement, so nothing here "
            "exercises a non-lexical *start* -- which is the half a lexical "
            "bracket cannot express, and the half `g2.psm` needs")

    with tempfile.TemporaryDirectory() as tmp:
        exe = os.path.join(tmp, "t71")
        build = run_command([str(PRISMIO_EXE), "build", str(fixture),
                             "--verify", "-o", exe])
        if build.returncode != 0 or not os.path.exists(exe):
            print(f"{RED}[FAIL] the non-lexical extent fixture did not build{RESET}")
            print(build.stdout + build.stderr)
            return False
        ran = run_command([exe])
        if ran.returncode != 0 or "PASS" not in (ran.stdout or ""):
            problems.append(
                f"the fixture did not pass: exit {ran.returncode}, output "
                f"{(ran.stdout or '').strip()!r}. Each FAIL line names the shape "
                f"whose arena was popped at the wrong point.")

        ledger = None
        for line in (ran.stdout + ran.stderr).splitlines():
            m = re.search(r"aif-verify:\s+(\d+) allocated,\s+(\d+) released,"
                          r"\s+(\d+) leaked,\s+(\d+) violation", line)
            if m:
                ledger = m
        if ledger is None:
            problems.append(
                "no aif-verify ledger line was matched at all, so nothing above "
                "was checked -- the instrument is broken, not the program")
        else:
            allocated, released, violations = (int(ledger.group(1)), int(ledger.group(2)),
                                               int(ledger.group(4)))
            if released != allocated:
                problems.append(
                    f"{released} released against {allocated} allocated. Whatever "
                    f"stays on the heap has to be reclaimed whatever the arena "
                    f"does; a difference here is a drop the narrowed extent lost.")
            if violations != 0:
                problems.append(
                    f"{violations} violation(s) -- something was freed twice, "
                    f"which is what a doubled pop looks like from the heap side")

    if problems:
        for p in problems:
            print(f"{RED}[FAIL] {p}{RESET}")
        return False
    print(f"{GREEN}[PASS] non-lexical extents: {len(extents)} arena(s) bracketed "
          f"between statements, five exit shapes correct, ledger clean{RESET}")
    return True


@harness_test(suite="aif")
def run_placement_pin_test():
    """SPEC 5.4 applied to placement -- `pin(<region-name>)` can fail a build.

    **The point of this check is that the annotation can refute, on a program
    that otherwise compiles.** `test_63_placement_pin.psm` compiles and both its
    pins are honoured; `neg_26_placement_pin_refuted.psm` is rejected. Neither
    alone is evidence: a compiler that honoured every placement pin passes the
    first, one that refuted every placement pin passes the second, and an
    annotation that cannot fail is this project's most-produced defect.

    So this takes the file that compiles, adds a second call to its bracketed
    callee **outside the region** -- the exact edit SPEC 5.2.1.1 says silently
    removes the placement -- and requires the compiler to reject the result *for
    that reason*. One edit, both directions, on one program.

    Outside, and not merely second: since 2026-08-28 regime (a) permits any
    number of call sites as long as they are all bracketed into the same region,
    so test_63 carries a second call *inside* `call_arena` that is served. The
    edit that still removes the placement is one the region does not contain.

    It also reads the manifest, because "honoured" has to be visible there
    (SPEC 5.4) and because a pin that was silently dropped and one that was
    honoured are indistinguishable from the exit code alone.
    """
    print(f"\n{BLUE}--- Running placement_pin ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_63_placement_pin.psm"
    manifest = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--manifest"])

    records = {r: (v["placement"], v["origin"])
               for r, v in manifest_records(manifest.stdout).items()}

    # SPEC 5.2 and SPEC 5.2.1.1, one each. The second is the one that can vanish
    # because of an edit to a different function, and it is the reason the
    # annotation exists at all.
    wanted = {
        "lexical_pin__Void#1": "region:lex_arena",
        "bracketed_make__Int#0": "region:call_arena",
    }
    matched = 0
    for symbol, placement in wanted.items():
        if symbol not in records:
            problems.append(f"no manifest record named {symbol} -- this check is "
                            f"reading nothing, which is how a comparison that "
                            f"matched no program reported 45 of them identical")
            continue
        matched += 1
        got_placement, got_origin = records[symbol]
        if got_placement != placement:
            problems.append(f"{symbol}: expected {placement}, got {got_placement}")
        if got_origin != "pin":
            problems.append(f"{symbol}: origin is {got_origin}, not `pin` -- SPEC 5.4 "
                            f"requires an honoured pin to be recorded as honoured, "
                            f"and a silently dropped one reads exactly like this")
    if matched == 0:
        problems.append("the manifest parse matched neither pinned symbol, so every "
                        "assertion above it was vacuous")

    # The regression, performed. test_63 marks the spot rather than letting this
    # guess at one: an edit that landed in the wrong scope would fail obligation 3
    # as well, and the mutant would then be rejected for a reason that has nothing
    # to do with regime (a).
    source = fixture.read_text(encoding="utf-8")
    marker = "    // MUTATION-POINT-SECOND-CALL"
    if marker not in source:
        problems.append("test_63 lost its MUTATION-POINT marker, so the "
                        "can-it-fail half of this check did not run")
    else:
        mutant = scratch() / ".prismio-placement-pin-mutant.psm"
        # A call *outside* the region, with its result discarded. Outside because
        # regime (a) now permits a second call inside one -- test_63 already has
        # one, and it is served. Discarded because a binding out here would hold
        # the loop's sites as well and obligation 3 would reject the mutant for a
        # reason that has nothing to do with regime (a).
        mutant.write_text(
            source.replace(marker, "    bracketed_make(99)"),
            encoding="utf-8")
        out = scratch() / ".prismio-placement-pin-mutant.exe"
        built = run_command([str(PRISMIO_EXE), "build", str(mutant), "-o", str(out)])
        text = (built.stdout or "") + (built.stderr or "")
        if built.returncode == 0:
            problems.append("a second call to the bracketed callee removed the "
                            "placement and the build SUCCEEDED -- the pin cannot fail, "
                            "which makes it worse than no annotation")
        else:
            if "pin(call_arena) cannot hold" not in text:
                problems.append(f"the mutant was rejected, but not by the placement "
                                f"pin: {text.strip().splitlines()[:2]}")
            if "outside the region" not in text:
                problems.append("the refusal does not name regime (a)'s condition -- "
                                "a call site outside the region -- which is the one "
                                "thing that tells a reader which edit to undo")
        cleanup_files(mutant, out)

    if problems:
        print(f"{RED}[FAIL] pin(<region-name>) does not guard the placement{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] pin(<region-name>) is recorded honoured, and a second call "
          f"site to a bracketed callee fails the build{RESET}")
    return True


@harness_test(suite="aif",
              reads=["tests/test_55_workload_profile.psm", "tests/test_61_layout_cost_model.psm"])
def run_layout_cost_model_test():
    """LAYOUT 5's cost model ranks hot/cold cuts, and ranks them by cost rather
    than by the access counts.

    **What this discriminates against is the cheap rule, not a broken model.**
    A hot/cold cut looks like it needs only the frequency ranking: cut where the
    count drops. `test_61_layout_cost_model.psm` is built so that rule is wrong
    -- its first frequency boundary is 2/13, which pushes all six of `advance`'s
    fields behind the cold pointer and scores **413** against not splitting at
    all. The model picks **9/13** at **76**. An implementation that read the
    ranking instead of scoring it would pick 2/13 and this test would fail, which
    is the only reason the fixture has three access groups instead of two.

    The same disagreement is 2/12 against 8/12 on the retired corpus program g1_particles,
    and 8/12 is the cut `aif/evidence/bench/layout_repr.c` measures at 0.87x --
    so the corpus is the evidence that the model's answer is the right one and
    this fixture is the assertion that it still gives it.

    Also asserted: the ranking is **acted on**. This is the assertion that changed
    when the split landed (2026-08-17) and it changed on purpose, the way
    `test_58_region_serves` was rewritten when call-site placement landed. Until
    then a split object had no release path, so `--layout` said "Reported only"
    and the manifest's `layout` column read plain `AoS` for a type the model
    wanted to split. Both are now the other way round: the row the model chose
    carries `emitted`, and the manifest reads `AoS*+9/13`.

    Keeping the ranking assertions above alongside the emission ones is the point.
    A compiler that emitted *some* cut would pass the emission half on its own;
    only the pair says it emitted the cut the model chose.

    The release half of the split is `test_62_split_release.psm`, which is a
    different question -- whether the object the model picked can be reclaimed --
    and is checked by running one rather than by reading a manifest.
    """
    print(f"\n{BLUE}--- Running layout_cost_model ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_61_layout_cost_model.psm"
    result = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--layout"])

    rows = {}
    chosen = None
    emitted = None
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 7 and parts[0] == "Sample":
            # "Sample 13 2 split 9/13 * 80 32 76 emitted" | "Sample 13 2 unsplit 104 0 100"
            star = "*" in parts
            is_emitted = "emitted" in parts
            tail = [p for p in parts if p not in ("*", "emitted")]
            label = tail[3] if tail[3] == "unsplit" else f"{tail[3]} {tail[4]}"
            ratio = int(tail[-1])
            rows[label] = ratio
            if star:
                chosen = label
            if is_emitted:
                emitted = label

    if not rows:
        problems.append("--layout printed no candidate rows for Sample at all")
    if chosen != "split 9/13":
        problems.append(
            f"the model chose {chosen!r}, expected 'split 9/13'. The first "
            f"frequency boundary is 2/13; choosing it means the ranking is being "
            f"read off the access counts instead of scored.")
    if rows.get("split 2/13", 0) <= 100:
        problems.append(
            f"split 2/13 scores {rows.get('split 2/13')}, which is not worse "
            f"than not splitting (100). A cold touch must be priced as a pointer "
            f"chase; if it is priced as a longer scan, this cut looks cheap and "
            f"the model picks it.")
    if not (0 < rows.get("split 9/13", 0) < 100):
        problems.append(
            f"split 9/13 scores {rows.get('split 9/13')}, which does not beat "
            f"the unsplit record -- the cut the corpus measures at 0.87x should")

    # Acted on: the cut the model chose is the one codegen produced.
    if emitted != "split 9/13":
        problems.append(
            f"codegen emitted {emitted!r} for Sample, expected 'split 9/13'. A "
            f"model whose argmin is not what the binary contains is a manifest "
            f"describing a program nobody built.")

    manifest = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--manifest"])
    saw_record = False
    for line in manifest.stdout.splitlines():
        if "Sample" in line and line.strip().startswith("make__"):
            saw_record = True
            if "+9/13" not in line:
                problems.append(
                    f"the manifest does not report the split in its layout "
                    f"column: {line.strip()!r}. The column is what a reader and "
                    f"the CI differ see; a split codegen emitted and the manifest "
                    f"does not name is a layout change nothing can regress on.")
    if not saw_record:
        problems.append(
            "the manifest printed no record for Sample, so the layout column was "
            "never read -- the assertion below it matched nothing")

    if "emitted" not in result.stdout:
        problems.append("--layout does not say which candidate codegen produced")

    # A declared `workload` runs the whole engine twice in one process (LAYOUT
    # 3.2), so anything the analysis accumulates and does not tear down is
    # doubled on exactly those sources and correct everywhere else -- the failure
    # mode that hid in the call graph until 2026-08-16. The traversal table is
    # accumulated per loop id, and a surviving one does not merely double the
    # counts: the second run's loops get fresh ids, so they arrive as *extra
    # traversals* and every candidate's cost scales with how many times the
    # engine ran.
    #
    # `test_55_workload_profile.psm` declares a workload and its `Cell` has three
    # traversals. **Verified discriminating**: with traversals_reset() removed
    # from aif_reset this reads 6 and the assertion fires.
    wl = run_command([str(PRISMIO_EXE), "aif",
                      str(TEST_DIR / "test_55_workload_profile.psm"), "--layout"])
    trav = None
    for line in wl.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[0] == "Cell":
            trav = int(parts[2])
            break
    if trav != 3:
        problems.append(
            f"Cell reports {trav} traversals on a source that declares a "
            f"workload, expected 3. The engine runs twice there; a traversal "
            f"table that survives aif_reset accumulates the second run as extra "
            f"traversals and every modelled cost scales with the run count.")

    if problems:
        for p in problems:
            print(f"{RED}[FAIL] {p}{RESET}")
        return False
    print(f"{GREEN}[PASS] the cost model ranks cuts by cost, not by frequency "
          f"rank, and codegen emits the cut it chose{RESET}")
    return True


@harness_test(suite="aif")
def run_split_release_test():
    """LAYOUT 6's hot/cold split -- the release half, checked by running it.

    A split object is **two allocations**, and the two ways to get that wrong are
    named in opposite directions: leak the cold block on the good path, or free it
    twice on the bad one. Neither is visible in a manifest and neither is visible
    in the IR; both are visible in `--verify`'s ledger, which is why this test
    builds and runs rather than reads.

    `test_62_split_release.psm` puts 4096 split `Body` objects through a
    container's teardown -- the path where the release arrives holding nothing but
    a pointer, and the one the type-blind `ir_free_object` cannot serve. What makes
    it work is one clause: `aif_type_releases` is forced true for a split type, so
    the element disposition is TYPED, `list_release` calls `__aif_release_Body`
    per element, and that is where the cold block goes.

    **`released` and `violation(s)` only.** `allocated` moves legitimately -- it is
    two allocations per object now -- which is exactly why it is not compared.

    Verified discriminating, both directions, 2026-08-17, by breaking the compiler
    on purpose and rebuilding it:

      * `ir_free_cold` made a no-op -- 4108 released against 8204, and 4100 leaked
        against 4. Both the released and the leaked assertions fire.
      * the cold block freed a second time inside `ir_free_cold` -- 4096
        violation(s) against 0. The violation assertion fires.

    The fixture is worthless if `Body` stops being split, because both assertions
    then pass against an unsplit object -- so the split is asserted **first**, from
    `--layout`'s `emitted` column, and a fixture that stopped discriminating fails
    here rather than reporting a pass.
    """
    print(f"\n{BLUE}--- Running split_release ---{RESET}")
    problems = []
    fixture = TEST_DIR / "test_62_split_release.psm"
    bodies = 4096

    layout = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--layout"])
    emitted = None
    for line in layout.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 7 and parts[0] == "Body" and "emitted" in parts:
            tail = [p for p in parts if p not in ("*", "emitted")]
            emitted = tail[3] if tail[3] == "unsplit" else f"{tail[3]} {tail[4]}"
    if emitted is None or not emitted.startswith("split"):
        problems.append(
            f"codegen emitted {emitted!r} for Body, not a split. Every assertion "
            f"below passes trivially on an unsplit object, so this fixture is no "
            f"longer discriminating and has to be rewritten rather than trusted.")

    with tempfile.TemporaryDirectory() as tmp:
        exe = os.path.join(tmp, "t62")
        build = run_command([str(PRISMIO_EXE), "build", str(fixture),
                             "--verify", "-o", exe])
        if build.returncode != 0 or not os.path.exists(exe):
            print(f"{RED}[FAIL] the split-release fixture did not build{RESET}")
            print(build.stdout + build.stderr)
            return False
        run = run_command([exe])

        # The value is exact integer arithmetic on the cold fields plus a count of
        # the hot ones: 15 + 15 + 4096. A field-access redirect that read the wrong
        # side of the split cannot produce it.
        if "4126" not in run.stdout:
            problems.append(
                f"the fixture printed {run.stdout.strip()!r}, expected 4126 -- "
                f"cold fields are being read from the wrong block")

        ledger = None
        for line in (run.stdout + run.stderr).splitlines():
            m = re.search(r"aif-verify:\s+(\d+) allocated,\s+(\d+) released,"
                          r"\s+(\d+) leaked,\s+(\d+) violation", line)
            if m:
                ledger = m
        if ledger is None:
            problems.append(
                "no aif-verify ledger line was matched at all, so nothing below "
                "was checked -- the instrument is broken, not the program")
        else:
            released, leaked, violations = (int(ledger.group(2)), int(ledger.group(3)),
                                            int(ledger.group(4)))
            # **Reclamation is counted where it happens, which is the arena.**
            # `Body` reads `arena:auto -- caller region selected`, so both halves
            # are bulk-reclaimed at region exit and never reach the heap ledger:
            # `released` is 1 here and would be 1 whether the cold block was
            # reclaimed or not. `aif-arena` can see it -- one object per half,
            # against one per body when the same fixture is forced unsplit, which
            # `forced_layout` measures as exactly `bodies` of difference.
            arena = None
            for line in (run.stdout + run.stderr).splitlines():
                m = re.search(r"aif-arena:\s+(\d+) object", line)
                if m:
                    arena = int(m.group(1))
            if arena is None:
                problems.append(
                    "no aif-arena line was matched, so the reclamation of the "
                    "split halves was not checked at all")
            elif arena < 2 * bodies:
                problems.append(
                    f"{arena} arena object(s) against {bodies} split objects. "
                    f"Both halves of every body have to be placed and reclaimed, "
                    f"so this cannot be below {2 * bodies}: the cold blocks are "
                    f"not being allocated beside their hot halves.")
            if violations != 0:
                problems.append(
                    f"{violations} violation(s). A split object freed twice is "
                    f"the other failure mode -- the cold block must be reclaimed "
                    f"once, from the generated release and nowhere else.")
            if leaked > bodies:
                problems.append(
                    f"{leaked} leaked, which is more than the {bodies} objects "
                    f"this program allocates -- consistent with every cold block "
                    f"surviving its object")

    if problems:
        for p in problems:
            print(f"{RED}[FAIL] {p}{RESET}")
        return False
    print(f"{GREEN}[PASS] a split object is reclaimed whole: both halves released, "
          f"no double free, cold fields read back exact{RESET}")
    return True


def emitted_layout_for(fixture, type_name, extra=None):
    """The candidate `--layout` marks `emitted` for one type, as a label string.

    Returns None when the type has no rows at all, which is a different failure
    from "emitted the unsplit record" and has to stay distinguishable: the first
    means the table lost the type, the second is a real answer.
    """
    cmd = [str(PRISMIO_EXE), "aif", str(fixture), "--layout"]
    if extra:
        cmd += extra
    out = run_command(cmd)
    emitted, seen = None, False
    for line in out.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 7 and parts[0] == type_name:
            seen = True
            if "emitted" in parts:
                tail = [p for p in parts if p not in ("*", "emitted")]
                emitted = tail[3] if tail[3] == "unsplit" else f"{tail[3]} {tail[4]}"
    return (emitted, seen, out.stdout + out.stderr)


@harness_test(suite="aif")
def run_forced_layout_test():
    """LAYOUT 8's forced candidate -- `--force-layout=<Type>:<hot>`.

    §8 selects a layout by *measuring* the top-k candidates rather than trusting
    §7.2's argmin, so the one mechanism it needs beyond `workload` is a way to emit
    a candidate the model did not choose. This checks that mechanism in the three
    directions it can be wrong, on `test_62_split_release.psm`, whose `Body` has
    three candidates: `unsplit`, `split 4/12`, and `split 7/12` (the argmin).

      1. **A force applies.** `Body:4` has to move the `emitted` column off the
         argmin. A flag that parsed and did nothing would leave it on 7/12 -- and
         would leave a search measuring the same binary k times while reporting k
         candidates.
      2. **A forced cut is still correct.** Every cut prints 4126 -- exact integer
         arithmetic over the cold fields -- with 0 violations and both halves
         released. This is the assertion that says the release path is right for
         cuts *the model never chose*, which is precisely what §8 will compile.
         Forced split releases 4096 more objects than forced unsplit, one cold
         block per body. That gap is what proves the force reached codegen rather
         than only the report. It was 4095 while `list_new` allocated a pointer
         block eagerly and `list_set_elem_inline` replaced it -- one wasted
         allocation on the unsplit path, cancelling one cold block. Lazy
         allocation removed the waste and the exception with it.
      3. **A force that does not apply changes nothing.** This is the one that
         caught a real defect on the day it was written. `Body:5` is not a
         candidate; the first version left `hot_count` at 0 for it, so a mistyped
         cut did not fall back to the argmin -- it silently turned the split
         *off*. The warning fired, so it was not silent, but a search script would
         have filed a real number against a cut nothing emitted. "Did not apply"
         has to mean the layout is what it would have been with no flag at all.

    Verified discriminating: with the `pick < 0` fallback reverted to `continue`,
    assertion 3 fires and the other two still pass -- which is why 3 is here rather
    than left to the warning.
    """
    print(f"\n{BLUE}--- Running forced_layout ---{RESET}")
    problems = []
    fixture = TEST_DIR / "test_62_split_release.psm"
    bodies = 4096

    baseline, seen, _ = emitted_layout_for(fixture, "Body")
    if not seen:
        print(f"{RED}[FAIL] `aif --layout` printed no Body rows at all, so nothing "
              f"below was checked -- the instrument is broken{RESET}")
        return False
    if baseline != "split 7/12":
        problems.append(
            f"Body's unforced layout is {baseline!r}, not 'split 7/12'. The forces "
            f"below are chosen against that table, so they no longer test what "
            f"they were written to test and have to be re-picked rather than "
            f"trusted.")

    # 1. A force applies, and lands on the candidate asked for.
    forced, _, _ = emitted_layout_for(fixture, "Body", ["--force-layout=Body:4"])
    if forced != "split 4/12":
        problems.append(
            f"--force-layout=Body:4 emitted {forced!r}, expected 'split 4/12' -- "
            f"the flag parsed but did not reach the selection")

    # 3. An unmatched force falls back to the argmin *and* says so. Both halves:
    #    the layout must not move, and the warning must be there to be read.
    missed, _, missed_out = emitted_layout_for(fixture, "Body",
                                               ["--force-layout=Body:5"])
    if missed != baseline:
        problems.append(
            f"a force that matched no candidate changed the layout to {missed!r} "
            f"from {baseline!r}. 'Did not apply' has to mean nothing changed, or a "
            f"typo produces a real measurement of a cut nobody asked for.")
    if "did not apply" not in missed_out:
        problems.append(
            "a force that matched no candidate produced no warning, which is the "
            "instrument-matched-nothing failure this project keeps rediscovering")

    # 2. Every cut runs correctly, and the forced-unsplit ledger proves the force
    #    reached codegen rather than only the manifest.
    released_by_cut = {}
    with tempfile.TemporaryDirectory() as tmp:
        for cut in (4, 7, 12):
            exe = os.path.join(tmp, f"t62_{cut}")
            build = run_command([str(PRISMIO_EXE), "build", str(fixture), "--verify",
                                 f"--force-layout=Body:{cut}", "-o", exe])
            if build.returncode != 0 or not os.path.exists(exe):
                problems.append(f"the fixture did not build at a forced cut of {cut}")
                continue
            run = run_command([exe])
            if "4126" not in run.stdout:
                problems.append(
                    f"at a forced cut of {cut} the fixture printed "
                    f"{run.stdout.strip()!r}, expected 4126 -- a field access is "
                    f"reading the wrong side of this cut")
            ledger = None
            for line in (run.stdout + run.stderr).splitlines():
                m = re.search(r"aif-verify:\s+(\d+) allocated,\s+(\d+) released,"
                              r"\s+(\d+) leaked,\s+(\d+) violation", line)
                if m:
                    ledger = m
            if ledger is None:
                problems.append(
                    f"no aif-verify ledger at a forced cut of {cut}, so its "
                    f"accounting was not checked")
                continue
            # The heap ledger cannot see this fixture's objects: `Body` reads
            # `arena:auto -- caller region selected`, so every body is
            # bulk-reclaimed at region exit and `released` is 1 at every cut.
            # The arena's own object count is where a cold block shows up.
            arena = None
            for line in (run.stdout + run.stderr).splitlines():
                m = re.search(r"aif-arena:\s+(\d+) object", line)
                if m:
                    arena = int(m.group(1))
            if arena is None:
                problems.append(
                    f"no aif-arena line at a forced cut of {cut}, so its "
                    f"placement was not checked")
                continue
            released_by_cut[cut] = arena
            if int(ledger.group(4)) != 0:
                problems.append(
                    f"{ledger.group(4)} violation(s) at a forced cut of {cut}. The "
                    f"release path has to be right for every candidate §8 can "
                    f"compile, not only for the argmin.")

    if 4 in released_by_cut and 12 in released_by_cut:
        # A split allocates one cold block per object and cannot use inline list
        # storage, so the gap is one block per body.
        #
        # **It was `bodies - 1` until 2026-08-30, and the missing one was waste.**
        # `list_new` used to allocate a four-pointer block eagerly, which
        # `list_set_elem_inline` then freed and replaced with a body block on the
        # first push -- so the unsplit path carried one extra allocation that
        # offset a cold block. `list_new` now allocates nothing until the first
        # push, the way Rust's `RawVec::NEW` does, so there is no replacement and
        # no offset. The number got simpler because the runtime did.
        gap = released_by_cut[4] - released_by_cut[12]
        expected_gap = bodies
        if gap != expected_gap:
            problems.append(
                f"a forced split placed {gap} more arena objects than a forced "
                f"unsplit, expected exactly {expected_gap} -- one cold block per "
                f"body. A force that only moved the manifest would read 0 here.")

    if problems:
        for p in problems:
            print(f"{RED}[FAIL] {p}{RESET}")
        return False
    print(f"{GREEN}[PASS] a named candidate is emitted, runs correct at every cut, "
          f"and an unmatched force changes nothing{RESET}")
    return True


@harness_test(suite="aif",
              reads=["tests/test_55_workload_profile.psm", "tests/test_58_region_serves.psm", "tests/test_59_bracket_summary.psm"])
def run_bracket_summary_test():
    """SPEC 5.2.1 -- the per-function bracketing summary reports the obligations,
    and reports them over the call graph rather than one function at a time.

    `test_59_bracket_summary.psm` has one function per verdict, and the two
    counts asserted here are the two that can be wrong in opposite directions:

      br-param == 1   exactly `stores_param`, which pushes into a list its caller
                      owns. Not `bracketable`, which pushes into its own -- so a
                      clause that fired on every container store would read 2,
                      and one that stopped firing would read 0. This is
                      obligation 2, and it is the counterexample the summary
                      exists for.
      br-drop  == 3   `drops`, which calls drop(), and `middle` and `main`
                      above it. That is obligation 4: the transitive callee set
                      is a closure, and a blocker anywhere inside it blocks the
                      whole extent. Two levels, deliberately -- **verified
                      discriminating**: with the closure replaced by a one-step
                      walk, this reads 2 and the test fails. One level would not
                      have caught it, because a direct-callee walk finds a direct
                      callee, and that is the first version of this assertion.

    Note what does NOT appear: `main` has no br-param, because the list
    `stores_param` writes into was allocated by `bracketable`, which is *inside*
    main's extent. Bracketing main would put both in the same arena, so the store
    is sound there and unsound one level down. A summary that answered
    per-function instead of per-extent could not tell those two apart.
    """
    print(f"\n{BLUE}--- Running bracket_summary ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_59_bracket_summary.psm"
    result = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--summary"])
    counts = {}
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].startswith("br-"):
            counts[parts[0]] = int(parts[1])
        if len(parts) >= 2 and parts[0] in ("bracketable", "sole-regime"):
            counts[parts[0]] = int(parts[1])

    if not counts:
        problems.append("--summary printed no bracketing section at all")
    if counts.get("br-param") != 1:
        problems.append(f"br-param is {counts.get('br-param')}, expected 1 "
                        f"(only `stores_param` writes into a container it does "
                        f"not own)")
    if counts.get("br-drop") != 3:
        problems.append(f"br-drop is {counts.get('br-drop')}, expected 3 "
                        f"(`drops`, `middle` and `main` -- obligation 4's "
                        f"closure over the call graph, two levels deep)")
    if counts.get("bracketable", 0) < 1:
        problems.append("no function qualifies at all, so the positive half of "
                        "the fixture is not discriminating anything")

    # SPEC 5.2.1.1's per-site verdict, which is what makes the counts above
    # auditable rather than a claim: a reader who wants to know *which* function
    # failed and why runs `--why` on the record, exactly as they would for a
    # tier. Three records, three different answers -- and the third is the
    # discriminator, because a verdict that said "no" to everything would satisfy
    # the first two.
    verdicts = [
        ("stores_param__List_Struct_Cmd_Int#0",
         "stores into a container or field it did not allocate",
         "obligation 2 is not reported per site"),
        ("drops__Int#1",
         "inside the extent frees one of its allocations",
         "the DROP obligation is not reported per site"),
        ("bracketable__Int#1",
         "yes  -- every obligation holds",
         "the one function that DOES qualify is not reported as qualifying -- "
         "a verdict that says no to everything passes the two checks above"),
    ]
    for symbol, phrase, complaint in verdicts:
        why = run_command([str(PRISMIO_EXE), "aif", str(fixture), f"--why={symbol}"])
        if "bracketing (SPEC 5.2.1.1)" not in why.stdout:
            problems.append(f"--why={symbol} prints no bracketing section")
        elif phrase not in why.stdout:
            problems.append(f"{complaint} (--why={symbol})")

    # The half the obligations do not carry. `bracketable` clears every one of
    # them and is still never placed, because its only call site is not in a
    # region -- and a report that said "yes" without saying that is the manifest
    # defect `region:none` exists to prevent, one level up.
    why = run_command([str(PRISMIO_EXE), "aif", str(fixture),
                       "--why=bracketable__Int#1"])
    if "0 of 1 call sites lie inside a region" not in why.stdout:
        problems.append("--why does not report how many of the function's call "
                        "sites are inside a region, so `yes` reads as a placement")

    # A declared `workload` runs the whole engine twice in one process (LAYOUT
    # 3.2), so anything the analysis accumulates and does not tear down is
    # doubled on exactly those sources and correct everywhere else. The call
    # graph was, when it first landed: every callee reported two call sites, so
    # regime (a) rejected every function in the program and `sole-regime` read 0.
    #
    # Asserted on `test_55_workload_profile.psm` and not on
    # `test_46_aif_annotations.psm`, which also declares one -- measured: 46's
    # workload run falls back (W2) and the engine only runs once there, so it
    # cannot discriminate. **Verified**: on the compiler before aif_reset tore
    # the graph down, 55 reads 0 here and 46 reads the same 6 either way.
    #
    # `>= 1` rather than the exact count on purpose: under the doubling *every*
    # function has two call sites, so the failure is total and the exact number
    # would only couple this to how many functions std/io has.
    workload = run_command([str(PRISMIO_EXE), "aif",
                            str(TEST_DIR / "test_55_workload_profile.psm"), "--summary"])
    sole = 0
    for line in workload.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] == "sole-regime":
            sole = int(parts[1])
    if sole < 1:
        problems.append("no function is sole-regime on a source with a declared "
                        "workload, which is what a call graph accumulated across "
                        "the two engine runs looks like -- see aif_reset")

    # SPEC 5.2.1.1's placement counter, and the pairing is the check. On test_59
    # four functions clear the obligations and **nothing is placed**, because the
    # fixture has no `region` -- so a placement pass that fired on the summary
    # alone reads non-zero here. On test_58 exactly three calls are placed, and
    # the same number has to come back off a second, independent surface:
    # `--summary` counts it from the call graph, the manifest prints one line per
    # bracket. If either wording moves, the two stop agreeing and this fails; a
    # check that read only one of them would go quietly to zero.
    #
    # Three and not one since regime (a) was generalised (2026-08-28): `make`
    # once, and `make_shared` twice, because both of its call sites are inside
    # `shared_work` and each is its own bracket. `make_out` still fails
    # obligation 3 and `make_outside` still fails regime (a).
    def bracketed_count(path):
        out = run_command([str(PRISMIO_EXE), "aif", str(path), "--summary"]).stdout
        m = re.search(r"^bracketed\s+(\d+)", out, re.M)
        return int(m.group(1)) if m else -1

    def bracket_lines(path):
        out = run_command([str(PRISMIO_EXE), "aif", str(path), "--manifest"]).stdout
        if "bracketed calls (SPEC 5.2.1.1 regime (a))" not in out:
            return 0
        at = out.index("bracketed calls (SPEC 5.2.1.1 regime (a))")
        return len([l for l in out[at:].splitlines()[1:] if l.startswith("#   ")])

    if bracketed_count(fixture) != 0:
        problems.append(f"test_59 has no `region` and still reports "
                        f"{bracketed_count(fixture)} bracketed call(s) -- a function "
                        f"clearing the obligations is not a placement")
    served = TEST_DIR / "test_58_region_serves.psm"
    if bracketed_count(served) != 3:
        problems.append(f"--summary reports {bracketed_count(served)} bracketed "
                        f"call(s) on test_58, expected exactly 3 (`make` once and "
                        f"`make_shared` twice; `make_out` fails obligation 3 and "
                        f"`make_outside` fails regime (a))")
    if bracket_lines(served) != bracketed_count(served):
        problems.append(f"the manifest lists {bracket_lines(served)} bracketed "
                        f"call(s) and --summary counts {bracketed_count(served)} -- "
                        f"two surfaces for one decision, and they disagree")

    if problems:
        print(f"{RED}[FAIL] the bracketing summary does not report the "
              f"obligations{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] bracketing summary: obligation 2 fires on the callee "
          f"that stores into a parameter, and only on it; a blocker propagates "
          f"to its caller{RESET}")
    return True


@harness_test("pin_tiers", suite="aif",
              reads=["tests/test_57_pin_tiers.psm"])
def run_pin_tier_test():
    """SPEC 5.4 -- a honoured pin freezes the tier, and only where the mechanism
    exists.

    test_57 asserts its own *values*; this asserts the thing the values cannot
    see. Three distinct ways the feature could be broken while the program still
    printed `test_57 ok`:

      * the pin moves the manifest but not codegen, so `pin(T3)` reports `rc` and
        emits an ordinary malloc;
      * the pin is dropped entirely and the derived tier is reported, which looks
        identical unless you know what was derived;
      * `pin(T3)` on a value no container holds reports `rc` rather than
        `rc:none` -- the manifest asserting a mechanism the binary does not
        contain, which is the exact defect the rc/rc:none split was introduced to
        prevent.

    The `origin` column is checked too: a record can carry the right tier for the
    wrong reason, and `pin` vs `inferred` is what separates them.
    """
    print(f"\n{BLUE}--- Running pin_tiers ---{RESET}")
    fixture = TEST_DIR / "test_57_pin_tiers.psm"

    result = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--manifest"])
    if result.returncode != 0:
        print(f"{RED}[FAIL] `prismio aif` exited {result.returncode}{RESET}")
        print(result.stdout or result.stderr)
        return False

    # symbol -> (tier, placement, origin)
    want = {
        "boxed_elements__Void#1":           ("T2", "owned",   "pin"),
        "counted_elements__Void#1":         ("T3", "rc",      "pin"),
        "counted_but_uncounted__Void#0":    ("T3", "rc:none", "pin"),
        "deliberate_pessimisation__Void#1": ("T3", "rc",      "pin"),
    }
    got = {r: (v["tier"], v["placement"], v["origin"])
           for r, v in manifest_records(result.stdout).items() if r in want}

    problems = []
    for sym, expect in want.items():
        if sym not in got:
            problems.append(f"{sym}: no manifest record")
        elif got[sym] != expect:
            problems.append(f"{sym}: expected {expect}, got {got[sym]}")

    # The codegen half. A pinned-T3 site in a container must reach rc_alloc; the
    # one no container holds must not, and there is exactly one of each here.
    ll = scratch() / "test_57_pin_tiers.ll"
    build = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(ll)])
    if build.returncode != 0 or not ll.exists():
        problems.append("could not emit IR for the fixture")
    else:
        ir = ll.read_text(encoding="utf-8", errors="replace")
        calls = sum(1 for line in ir.splitlines() if "call ptr @rc_alloc" in line)
        if calls != 2:
            problems.append(f"expected 2 rc_alloc call sites (the two pinned-T3 "
                            f"sites a container holds), got {calls}")
        ll.unlink()

    if problems:
        print(f"{RED}[FAIL] pin does not freeze the tier as SPEC 5.4 specifies{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] pin freezes the tier, and only where the mechanism exists{RESET}")
    return True


@harness_test(suite="aif",
              reads=["tests/test_42_aif_stack_promotion.psm"])
def run_aif_stack_slot_test():
    """The T0 path has to be checked in the IR, not only in the output: falling
    back to the heap is silently correct, so every value test here passes just as
    well with stack promotion switched off entirely.

    `Nested` exists in the fixture for one reason -- its literal starts at the
    same file:line:col as the array literal holding it, and those get different
    tiers. A tier lookup keyed by position cannot tell them apart and has to take
    the higher one, which loses this promotion.
    """
    print(f"\n{BLUE}--- Running aif_stack_slot ---{RESET}")
    fixture = TEST_DIR / "test_42_aif_stack_promotion.psm"
    out = scratch() / "t42_slots.ll"

    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(out)])
    if result.returncode != 0:
        print(f"{RED}[FAIL] build exited {result.returncode}{RESET}")
        print(result.stdout or result.stderr)
        return False

    ir = out.read_text(encoding="utf-8", errors="replace")
    cleanup_files(out)
    problems = []
    if not re.search(r"alloca %Point\b", ir):
        problems.append("no `alloca %Point` -- T0 promotion is not reaching codegen")
    if not re.search(r"alloca %Nested\b", ir):
        problems.append("no `alloca %Nested` -- the struct literal nested in an "
                        "array literal lost its T0 to a key collision")

    if problems:
        print(f"{RED}[FAIL] stack promotion is not being emitted{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] T0 sites reach codegen as allocas, collisions included{RESET}")
    return True


@harness_test(suite="aif", resources={"cpu": 3, "mem": 2000},
              reads=["src/**", "tests/test_48_aif_shared_elements.psm", "ums/builder/build_plan.psm", "ums/commands/command.psm", "ums/dependency/dependency.psm", "ums/dependency/resolve.psm", "ums/model/build_module.psm", "ums/model/constants.psm", "ums/model/diagnostic.psm", "ums/model/lowering.psm", "ums/model/manifest_writer.psm", "ums/model/project.psm", "ums/model/validation.psm", "ums/model/workspace.psm", "ums/parser/ast.psm", "ums/parser/lexer.psm", "ums/parser/parser.psm", "ums/parser/token.psm", "ums/resolver/discovery.psm", "ums/targets/target.psm", "ums/ums.psm"])
def run_aif_rc_test():
    """AIF Level 5, checked in the IR because neither half shows in a value.

    The negative half is the load-bearing one. An OPAQUE site must never be
    refcounted -- the pointer came back from a function this compilation cannot
    see, so there is no header in front of it and `rc_release` would decrement
    whatever the real allocator put there. `src/main.psm` is the one program
    large enough to violate that, so the exclusion is checked there.

    It is checked directly rather than by counting. This used to assert zero
    calls to rc_alloc in the compiler, which was a proxy justified by every T3
    site there being an opaque extern return. UMS has since added T3 sites that
    are ordinary struct allocations and *are* supposed to be counted, so the
    proxy began firing on correct code. What is asserted now is the property
    itself: a refcounted allocation must be sized from a declared Prismio struct,
    which is the one shape a pointer from foreign code cannot take.
    """
    print(f"\n{BLUE}--- Running aif_rc ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_48_aif_shared_elements.psm"
    out = scratch() / "t48_rc.ll"
    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(out)])
    if result.returncode != 0:
        print(f"{RED}[FAIL] build exited {result.returncode}{RESET}")
        print(result.stdout or result.stderr)
        return False
    ir = out.read_text(encoding="utf-8", errors="replace")
    cleanup_files(out)
    if not re.search(r"call ptr @rc_alloc\b", ir):
        problems.append("no call to rc_alloc -- a value two containers hold is "
                        "not being counted, so T3 is not reaching codegen")

    compiler_out = scratch() / "main_rc.ll"
    result = run_command([str(PRISMIO_EXE), "build",
                          str(TEST_DIR.parent / "src" / "main.psm"), "-o", str(compiler_out)])
    if result.returncode != 0:
        problems.append(f"building src/main.psm exited {result.returncode}")
    else:
        cir = compiler_out.read_text(encoding="utf-8", errors="replace")
        cleanup_files(compiler_out)
        declared = set(re.findall(r"^(%[\w.$]+) = type \{", cir, re.M))
        counted = 0
        for line in cir.splitlines():
            if "call ptr @rc_alloc" not in line:
                continue
            counted += 1
            m = re.search(r"getelementptr \((%[\w.$]+), ptr null, i32 1\)", line)
            if not m:
                problems.append("rc_alloc in the compiler is not sized from a struct: "
                                + line.strip()
                                + " -- a header in front of memory we never allocated")
            elif m.group(1) not in declared:
                problems.append(f"rc_alloc in the compiler allocates {m.group(1)}, "
                                "which is not a declared struct type")
        if counted and not problems:
            print(f"  {counted} refcounted allocation(s) in the compiler, all struct-sized")

    if problems:
        print(f"{RED}[FAIL] refcounting is not where it should be{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] T3 is counted where it is ours and nowhere else{RESET}")
    return True


@harness_test(suite="aif",
              reads=["tests/test_53_aif_views.psm"])
def run_aif_view_test():
    """SPEC 8.4's E-VIEW, checked in the manifest and in the IR.

    Both halves are load-bearing and the *negative* one is what took three
    attempts to get right. E-VIEW couples a collection's lifetime to a reference
    read out of it, and the obvious implementations couple far too much:

      - reading the element key directly makes every read a view of every list
        in the file, because that key is object-insensitive. It demoted three
        untouched containers in test_47.
      - treating a scalar read as a view demoted a `Vec<Int>` for returning an
        `Int`, which is a copy in a register and keeps nothing alive.
      - bounding the collection by "the caller" when the view is bound in
        another function cost g5_asset_cache its list_release, for a view that
        cannot outlive the activation it was taken in.

    So the assertion is exact: two sites rise, three named controls do not, and
    the release disappears from the escaping function while staying in the local
    one. A rule that fires everywhere passes the first half and is useless.
    """
    print(f"\n{BLUE}--- Running aif_view ---{RESET}")
    problems = []
    fixture = TEST_DIR / "test_53_aif_views.psm"

    result = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--manifest"])
    if result.returncode != 0:
        print(f"{RED}[FAIL] aif exited {result.returncode}{RESET}")
        print(result.stdout or result.stderr)
        return False

    tiers = {}
    for line in result.stdout.splitlines():
        m = re.match(r"^(\S+?)\s*(T[0-9])\s+(\S+)\s+(\S+)\s", line)
        if m:
            tiers[m.group(1)] = (m.group(2), m.group(3))

    # The collection sinks a tier because a reference into it outlives the
    # scope. SPEC 8.4: "The collection's escape rises to match."
    for sym in ("view_escapes_by_return__Int#0",
                "view_escapes_through_a_binding__Int#0"):
        got = tiers.get(sym)
        if got is None:
            problems.append(f"{sym}: not in the manifest")
        elif got[0] != "T2":
            problems.append(f"{sym}: {got[0]}, expected T2 -- a reference into "
                            "this list is returned, so the list must escape "
                            "with it or the caller reads freed memory")

    # ...and the three that must not move. Each one is a way the rule
    # over-fired while it was being built.
    for sym, why in (
        ("view_stays_local__Void#0",
         "the view never leaves the scope that owns the list"),
        ("scalar_read_is_not_a_view__Void#0",
         "an Int read out of a Vec<Int> is a copy, not a view"),
        ("view_in_a_callee__Void#0",
         "the view is taken in a callee, so it dies inside this activation"),
    ):
        got = tiers.get(sym)
        if got is None:
            problems.append(f"{sym}: not in the manifest")
        elif got[0] != "T1":
            problems.append(f"{sym}: {got[0]}, expected T1 -- {why}")

    # The IR half. The tier is only interesting because of what it deletes.
    out = scratch() / "t53_view.ll"
    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(out)])
    if result.returncode != 0:
        problems.append(f"build exited {result.returncode}")
    else:
        ir = out.read_text(encoding="utf-8", errors="replace")
        cleanup_files(out)

        def body(name):
            # The mangled name carries the parameter suffix, and `\b` does not
            # separate `return` from `__Int` -- an underscore is a word
            # character. Match the whole symbol.
            m = re.search(r"^define[^\n]*@" + re.escape(name) + r"\(.*?^}", ir,
                          re.S | re.M)
            return m.group(0) if m else ""

        escaping = body("view_escapes_by_return__Int")
        local = body("view_stays_local__Void")
        if not escaping or not local:
            problems.append("could not find the fixture's functions in the IR")
        else:
            if "list_release" in escaping:
                problems.append("view_escapes_by_return still calls list_release "
                                "-- it frees the list and its elements and then "
                                "returns a pointer into them")
            if "list_release" not in local:
                problems.append("view_stays_local no longer calls list_release "
                                "-- E-VIEW is over-firing and the container leaks")

    if problems:
        print(f"{RED}[FAIL] E-VIEW is not coupling what it should{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] a collection outlives every view of it, and only "
          f"then{RESET}")
    return True


@harness_test(suite="aif")
def run_slice_gate_test():
    """M4.1's discriminating representation, lifetime, and bounds gate."""
    print(f"\n{BLUE}--- Running slice_gate ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_79_slices.psm"
    out = scratch() / "t79_slices.ll"
    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(out)])
    if result.returncode != 0:
        problems.append(f"test_79 IR build exited {result.returncode}: "
                        f"{result.stdout or result.stderr}")
    else:
        ir = out.read_text(encoding="utf-8", errors="replace")
        if not re.search(r"%prismio\.slice(?:\.\d+)? = type \{ ptr, i32, i32 \}", ir):
            problems.append("Slice is not emitted as { handle, offset, length }")
        for symbol in ("prismio_slice_check", "list_slice_get_inline",
                       "list_slice_set_inline", "list_slice_get",
                       "list_slice_str_data", "list_slice_set_str"):
            if not re.search(rf"call [^\n]*@{symbol}\b", ir):
                problems.append(f"test_79 does not exercise @{symbol}")
    cleanup_files(out)

    escape = TEST_DIR / "fixture_slice_escape.psm"
    escape_ir = scratch() / "t79_slice_escape.ll"
    escape_exe = scratch() / "fixture_slice_escape.exe"
    result = run_command([str(PRISMIO_EXE), "build", str(escape), "-o", str(escape_ir)])
    if result.returncode != 0:
        problems.append(f"slice escape IR build exited {result.returncode}: "
                        f"{result.stdout or result.stderr}")
    else:
        ir = escape_ir.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"^define[^\n]*@escaping_slice__Int\b.*?^\}",
                          ir, re.MULTILINE | re.DOTALL)
        if not match:
            problems.append("could not find escaping_slice__Int in emitted IR")
        elif re.search(r"call void @list_release\b", match.group(0)):
            problems.append("escaping_slice releases the List whose handle it returns")

        result = run_command([str(PRISMIO_EXE), "build", str(escape),
                              "-o", str(escape_exe)])
        if result.returncode != 0:
            problems.append(f"slice escape executable build exited {result.returncode}")
        else:
            ran = run_command([str(escape_exe)])
            if ran.returncode != 0 or "PASS: slice escape" not in ran.stdout:
                problems.append("an escaping Slice read freed or incorrect storage")
    cleanup_files(escape_ir, escape_exe)

    bounds = TEST_DIR / "fixture_slice_bounds.psm"
    bounds_exe = scratch() / "fixture_slice_bounds.exe"
    result = run_command([str(PRISMIO_EXE), "build", str(bounds), "-o", str(bounds_exe)])
    if result.returncode != 0:
        problems.append(f"slice bounds fixture build exited {result.returncode}")
    else:
        ran = run_command([str(bounds_exe)])
        if ran.returncode == 0:
            problems.append("an out-of-range Slice was accepted")
        if "slice range [0..<2] is outside collection length 1" not in ran.stderr:
            problems.append("the Slice bounds failure did not name the range and length")
    cleanup_files(bounds_exe)

    # `v[0..2]` is inclusive in source; the failure must say `0..2`, not the
    # half-open `0..<3` it is lowered to.
    inclusive = TEST_DIR / "fixture_slice_bounds_inclusive.psm"
    inclusive_exe = scratch() / "fixture_slice_bounds_inclusive.exe"
    result = run_command([str(PRISMIO_EXE), "build", str(inclusive), "-o", str(inclusive_exe)])
    if result.returncode != 0:
        problems.append(f"inclusive slice bounds fixture build exited {result.returncode}")
    else:
        ran = run_command([str(inclusive_exe)])
        if ran.returncode == 0:
            problems.append("an out-of-range inclusive Slice was accepted")
        if "slice range [0..2] is outside collection length 1" not in ran.stderr:
            problems.append("the inclusive Slice bounds failure did not echo the range as written")
    cleanup_files(inclusive_exe)

    if problems:
        print(f"{RED}[FAIL] first-class Slice invariants are not all enforced{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False

    print(f"{GREEN}[PASS] Slice is handle-based, growth-safe, range-checked, "
          f"and covered by E-VIEW{RESET}")
    return True


@harness_test(suite="aif")
def run_data_view_gate_test():
    """M4.3's real-column, mutable round-trip, alias, and release gate."""
    print(f"\n{BLUE}--- Running data_view_gate ---{RESET}")
    problems = []
    fixture = TEST_DIR / "test_80_data_view_conversion.psm"
    out = scratch() / "t80_data_view.ll"
    exe = scratch() / "test_80_data_view_verify.exe"
    drop_fixture = TEST_DIR / "test_81_data_view_drop.psm"
    drop_exe = scratch() / "test_81_data_view_drop_verify.exe"

    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(out)])
    if result.returncode != 0:
        problems.append(f"DataView IR build exited {result.returncode}: "
                        f"{result.stdout or result.stderr}")
    else:
        ir = out.read_text(encoding="utf-8", errors="replace")
        for symbol in ("data_view_begin", "data_view_add_column",
                       "data_view_finish", "data_view_check_index",
                       "data_view_column", "data_view_to_list"):
            if not re.search(rf"call [^\n]*@{symbol}\b", ir):
                problems.append(f"conversion does not exercise @{symbol}")
        # Sample has four source fields. One projection or one row-copy helper
        # could pass the runtime fixture; four emitted column builds cannot.
        if len(re.findall(r"call void @data_view_add_column\b", ir)) != 4:
            problems.append("the compiler did not emit one physical column per Sample field")
        if not re.search(r"%prismio\.data_element\s*=\s*type\s*\{\s*ptr,\s*i32\s*\}", ir):
            problems.append("DataView indexing is not represented as a (handle, index) descriptor")
        if not re.search(r"load (?:i8|i16|i32|i64|double), ptr [^\n]*!tbaa", ir):
            problems.append("DataView column reads carry no field-disjoint alias metadata")
        if not re.search(r"store (?:i8|i16|i32|i64|double) [^\n]*!tbaa", ir):
            problems.append("DataView column writes carry no field-disjoint alias metadata")

    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "--verify",
                          "-o", str(exe)])
    if result.returncode != 0:
        problems.append(f"DataView --verify build exited {result.returncode}: "
                        f"{result.stdout or result.stderr}")
    else:
        ran = run_command([str(exe)])
        if ran.returncode != 0 or "PASS: data view conversion" not in ran.stdout:
            problems.append("AoS -> SoA -> AoS did not preserve every tested field")
        report = re.search(r"aif-verify: (\d+) allocated, (\d+) released, "
                           r"(\d+) leaked", ran.stderr)
        if not report:
            problems.append("DataView --verify run emitted no allocator ledger")
        elif report.group(3) != "0":
            problems.append(f"DataView round-trip leaked {report.group(3)} allocation(s)")

    result = run_command([str(PRISMIO_EXE), "build", str(drop_fixture), "--verify",
                          "-o", str(drop_exe)])
    if result.returncode != 0:
        problems.append(f"DataView scope-drop build exited {result.returncode}: "
                        f"{result.stdout or result.stderr}")
    else:
        ran = run_command([str(drop_exe)])
        report = re.search(r"aif-verify: (\d+) allocated, (\d+) released, "
                           r"(\d+) leaked", ran.stderr)
        if ran.returncode != 0:
            problems.append("a DataView left in scope did not execute cleanly")
        if not report:
            problems.append("DataView scope-drop emitted no allocator ledger")
        elif report.group(3) != "0":
            problems.append(f"DataView scope-drop leaked {report.group(3)} allocation(s)")

    cleanup_files(out, exe, drop_exe)
    if problems:
        print(f"{RED}[FAIL] DataView conversion invariants are not all enforced{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False

    print(f"{GREEN}[PASS] DataView emits disjoint columns, round-trips mutations "
          f"through padding-aware rows, and releases cleanly{RESET}")
    return True


# `run_ownership_probes_test`'s programs, which tools/sanitizer_smoke.py also runs under ASan.
OWNERSHIP_PROBES = (
    # file, text stdout must contain, and whether it must not leak either
    ("option_methods_probe.psm", "fallback", False),
    ("forwarding_literal_probe.psm", "fallback", False),
    ("binder_return_probe.psm", "a literal payload, past twelve bytes", False),
    ("binder_rewrap_probe.psm", "not a seven: y", False),
    # `??` over Strings: both operands' ownership is the function's, and the
    # right side is evaluated lazily, so a fallback that never ran must not be
    # released and one that ran must be.
    ("coalesce_probe.psm", "PASS", True),
    # HashMap removal swaps a String key to the end and truncates it: a key the
    # removal failed to release is a leak, so this one is held to 0.
    ("test_193_map_methods.psm", "PASS", True),
    # HashSet get/take/algebra/bulk operations hand out copies of String keys; all must be released.
    ("test_set_api.psm", "ok", True),
    ("test_map_api.psm", "ok", True),
    # `upsert`, `modify` (a stored Vec or struct changed in place through an `inout` closure
    # parameter) and `getOrInsertDefault`: the copies they hand around are all released.
    ("test_map_entry.psm", "PASS", True),
    # `shrinkToFit` on a Vec, a HashMap and a HashSet (the new `list_shrink_to_fit`).
    ("test_map_shrink.psm", "PASS", True),
    # A HashMap, a HashSet or a generic struct moved or written into the field of a struct a function
    # returns: released once by the owner, not by the binding as well (it crashed) and not left
    # unreleased (it leaked). aifFieldTypeName called every generic struct field a `List`.
    ("test_map_in_struct.psm", "PASS", True),
    # A composite key hashed through `Hash` and `Hasher`, nested and with a String field.
    ("test_hash_hasher.psm", "PASS", True),
    # A map literal of more than twelve computed entries: one `mapEntriesN` per run of twelve,
    # merged; it was a `mapPut` chain that leaked 12 of 13 values.
    ("test_map_long_literal.psm", "PASS", True),
    # A child bound to a `let` and then stored into a recursive payload was
    # freed by the binding and by the tree: a double free, and a leak if the
    # fix declines the tree's release instead.
    ("recursive_enum_bindings_probe.psm", "PASS", True),
    # The same through a `Node?`, which also did not link: an optional's
    # drop named no release.
    ("recursive_optional_probe.psm", "PASS", True),
    ("test_195_string_builder.psm", "PASS", True),
    # One allocation site backs every `concat`; a builder storing `concat`
    # results stopped every `concat` argument being released.
    ("concat_argument_probe.psm", "PASS", True),
    # A Vec<String> only literals reach, and an element replaced under a
    # live view: both leaked, and releasing at the store would free the view.
    ("vec_element_replace_probe.psm", "PASS", True),
    ("test_217_vec_filled.psm", "ok", True),
    # `HashMap<K, V>()`, `HashMap()` from an annotation, and a bare `let` of a HashMap,
    # which was a zeroed struct until 2026-09-28.
    ("test_222_type_constructors.psm", "ok", True),
    # HashMap literals: a computed String key is an argument temporary, and a
    # literal of plain keys is a producer, clean in a field and a return.
    ("test_223_map_literals.psm", "ok", True),
    # HashSet holds its own columns: a set wrapping a HashMap in a field leaked
    # its whole table (7 allocated, 1 released for a HashSet<Int>).
    ("test_369_hash_set.psm", "PASS", True),
    # A HashMap that owns its values (`V: Copy`): every reader hands out a copy, so
    # no view of a stored value leaves the table and the container is released.
    # It read "leaks every value" when the readers returned the stored element.
    ("test_map_owned.psm", "PASS", True),
    # An owned temporary's String field or element compared in place (also on the right of
    # `or`), bound off a statement head, and a struct literal argument that a callee copies.
    ("test_owned_temporary_reads.psm", "PASS", True),
    # A scalar element of an owned temporary Vec on the right of `or`, in a `while`, a `let`.
    ("test_owned_temporary_scalars.psm", "PASS", True),
    # An owned call result compared with `none` has no binding to drop it: a
    # `while (next() != none)` leaked one block per iteration.
    ("test_370_compare_owned_temporary.psm", "ok", True),
    # std.mem: Buffers and Arenas release their bytes like any Vec, and the
    # test frees every raw block it allocates, so a leak here is a wrong
    # release or a Buffer that kept its bytes.
    ("test_274_std_mem.psm", "PASS", True),
    # The language-gaps forms: an owned String payload through `if let`, `let ... else`, guards and
    # nested patterns is released once.
    ("test_390_let_forms.psm", "PASS", True),
    ("test_391_match_tests.psm", "PASS", True),
    ("test_392_nested_patterns.psm", "PASS", True),
)


@harness_test(suite="aif", resources={"cpu": 2, "mem": 800})
def run_ownership_probes_test():
    """Shapes that released memory that was not live, under `--verify`.

    Each probe is its own program because the analysis is whole-program: in
    test_191, owned payloads elsewhere in the file changed its answer and the bad
    spelling of `unwrapOr` read 0 violations. A violation is corruption, and a
    run prints the right answer through one, so the ledger is what is checked --
    and, for the rewrap probe, the text, since a read of freed memory is not a
    ledger event.

    Leaks are not asserted: once any `String?` is stored from a literal, that
    value is never freed for any `String?` (KNOWN_ISSUES, Ownership), and the
    probes store literals on purpose.
    """
    print(f"\n{BLUE}--- Running ownership_probes ---{RESET}")
    problems = []
    exe_suffix = ".exe" if platform.system() == "Windows" else ""
    # A ledger that balances at exit says nothing about a loop that holds everything it ever
    # replaced until the end. test_map_owned replaces a value and removes a key 20,000 times,
    # and the map releases both at the store: the peak is ~54 KB, against ~750 KB when a
    # displaced element is parked with its container.
    peak_limits = {"test_map_owned.psm": 262144}
    with tempfile.TemporaryDirectory(prefix="prismio-ownership-probes-") as tmp:
        for name, want, no_leaks in OWNERSHIP_PROBES:
            exe = Path(tmp) / ("probe" + exe_suffix)
            built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / name),
                                 "--verify", "-o", str(exe)])
            if built.returncode != 0:
                problems.append(f"{name} did not build: "
                                f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")
                continue
            # Not run_command: a read of freed memory prints bytes that are not
            # UTF-8, and that has to be a failure here rather than a traceback.
            ran = subprocess.run([str(exe)], capture_output=True, text=True, encoding="utf-8", errors="replace")
            output = (ran.stdout or "") + (ran.stderr or "")
            if ran.returncode != 0 or want not in (ran.stdout or ""):
                problems.append(f"{name} exited {ran.returncode} without {want!r}: "
                                f"{elide_middle(output)}")
            elif " 0 violation(s)" not in output:
                problems.append(f"{name} released something not live: {elide_middle(output)}")
            elif no_leaks and " 0 leaked," not in output:
                problems.append(f"{name} leaked: {elide_middle(output)}")
            elif name in peak_limits:
                peak = re.search(r"(\d+) peak live bytes", output)
                if peak is None or int(peak.group(1)) > peak_limits[name]:
                    problems.append(f"{name} peaked at {peak.group(1) if peak else '?'} live bytes, over "
                                    f"{peak_limits[name]}: a displaced or removed element is parked, not released")
    if problems:
        print(f"{RED}[FAIL] ownership probes{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] ownership probes: {len(OWNERSHIP_PROBES)} shapes, right text and "
          f"0 violations{RESET}")
    return True


@harness_test(suite="aif", resources={"cpu": 2, "mem": 800},
              reads=["src/**", "ums/builder/build_plan.psm", "ums/commands/command.psm", "ums/dependency/dependency.psm", "ums/dependency/resolve.psm", "ums/model/build_module.psm", "ums/model/constants.psm", "ums/model/diagnostic.psm", "ums/model/lowering.psm", "ums/model/manifest_writer.psm", "ums/model/project.psm", "ums/model/validation.psm", "ums/model/workspace.psm", "ums/parser/ast.psm", "ums/parser/lexer.psm", "ums/parser/parser.psm", "ums/parser/token.psm", "ums/resolver/discovery.psm", "ums/targets/target.psm", "ums/ums.psm"])
def run_aif_layout_test():
    """LAYOUT 7.2's field-order search, checked where it is decided: the IR.

    The load-bearing assertion is the **pinned first field**, and the reason is
    the sharpest constraint in this item. The compiler puns a struct pointer as
    `String` and spells "this slot is empty" as a zero first byte, so a struct
    whose first field moved is a struct whose live values can read as absent --
    which is what NodeKind and TypeKind reserving ordinal 0 exists to prevent
    (test_41). The first build that sorted by width put an 8-byte pointer at
    offset 0 and the next generation could not parse its own source.

    A value test cannot see any of this: every layout computes the same answers,
    and a wrong one fails by not building at all one generation later.
    """
    print(f"\n{BLUE}--- Running aif_layout ---{RESET}")
    src_dir = TEST_DIR.parent / "src"
    out = scratch() / "layout_probe.ll"
    result = run_command([str(PRISMIO_EXE), "build",
                          str(src_dir / "main.psm"), "-o", str(out)])
    if result.returncode != 0:
        print(f"{RED}[FAIL] build exited {result.returncode}{RESET}")
        print(result.stdout or result.stderr)
        return False
    ir = out.read_text(encoding="utf-8", errors="replace")
    cleanup_files(out)

    lowered = {"Int": "i32", "Float": "double", "Bool": "i1", "Char": "i8",
               "I8": "i8", "I16": "i16", "I64": "i64", "U8": "i8", "U16": "i16",
               "U32": "i32", "U64": "i64", "Isize": "i64", "Usize": "i64",
               # Named rather than left to the `ptr` default: a String field is
               # the {ptr, i64} pair, and the default would report every struct
               # whose field 0 is a String as one the layout search had moved.
               "String": "%prismio.str"}
    emitted = {m.group(1): [f.strip() for f in m.group(2).split(",")]
               for m in re.finditer(r"^%(\w+) = type \{(.*)\}", ir, re.M)}

    # Enums lower to i32; everything else that is not a scalar is a pointer.
    # Read the declarations rather than guessing from the name -- `TokenType` is
    # an enum and does not look like one.
    sources = {p: p.read_text(encoding="utf-8") for p in sorted(src_dir.rglob("*.psm"))}
    # Declarations are top-level and begin a source line. Anchoring here matters:
    # src/ast/types.psm contains a comment with the example
    # `struct ASTNode { child1: String }`. The old unanchored regex treated that
    # prose as a second ASTNode declaration and reported a layout violation even
    # though the emitted type correctly began with the real `kind: NodeKind`.
    enums = {m.group(1) for text in sources.values()
             for m in re.finditer(r"(?m)^[ \t]*enum\s+(\w+)\s*\{", text)}

    problems = []
    checked = 0
    for path, text in sources.items():
        for m in re.finditer(r"^[ \t]*struct\s+(\w+)\s*\{(.*?)\}", text,
                             re.M | re.S):
            name, body = m.group(1), re.sub(r"//[^\n]*", "", m.group(2))
            fields = [f.strip() for f in body.split(",") if f.strip()]
            if name not in emitted or not fields:
                continue
            declared = fields[0].split(":", 1)[1].strip()
            want = lowered.get(declared, "i32" if declared in enums else "ptr")
            got = emitted[name][0]
            checked += 1
            if got != want:
                problems.append(f"{name}: first field is `{declared}` ({want}) but "
                                f"the emitted type starts with {got} -- the layout "
                                "search moved field 0, and the punning invariant "
                                "goes with it")

    if checked == 0:
        problems.append("no struct matched between src/ and the emitted IR -- "
                        "this test stopped checking anything")

    if problems:
        print(f"{RED}[FAIL] the layout search moved something it must not{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] layout reorders fields and never the first one "
          f"({checked} structs){RESET}")
    return True


@harness_test(suite="aif",
              reads=["tests/test_43_aif_scope_drop.psm"])
def run_aif_drop_emission_test():
    """Reclamation points, counted per function in the IR.

    test_43 running clean already proves the dynamic counts balance -- a double
    free exits 0xC0000374. What it cannot prove is that anything was emitted at
    all, since leaking is silently correct. These are the static counts, and the
    two that would be bugs rather than slowdowns are `escapes` (reclaiming a
    value that outlives the frame) and `explicit` (reclaiming again after
    `drop`).

    The counts moved from `free` to `arena_pop` when LAYOUT 7.1's automatic
    placement landed, and moved *without changing*: every scope exit that used to
    free one object now pops the arena that served it. That is the check worth
    having -- the mechanism is allowed to change, the number of points at which a
    scope reclaims what it allocated is not.

    `explicit` keeps its `free`, and that is not incidental either: an explicitly
    dropped value is barred from the arena, because `drop` emits a deallocator
    call and an arena pointer is not something a deallocator can take.

    The deallocator is spelled `rt_free` rather than `free` since the small-block
    recycler landed (lang_runtime.c): codegen emits the runtime's seam so that a
    program's releases and the runtime's own reach the same pool. That is the
    second time the *mechanism* moved without the counts moving, which is the
    property this test exists to hold on to.
    """
    print(f"\n{BLUE}--- Running aif_drop_emission ---{RESET}")
    fixture = TEST_DIR / "test_43_aif_scope_drop.psm"
    out = scratch() / "t43_drops.ll"

    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(out)])
    if result.returncode != 0:
        print(f"{RED}[FAIL] build exited {result.returncode}{RESET}")
        print(result.stdout or result.stderr)
        return False

    counts, current = {}, None
    for line in out.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"define .*@([A-Za-z0-9_]+)\(", line)
        if m:
            current = m.group(1)
            counts.setdefault(current, {"free": 0, "pop": 0, "push": 0})
        elif current and re.search(r"call void @rt_free\(", line):
            counts[current]["free"] += 1
        elif current and re.search(r"call void @arena_pop\(", line):
            counts[current]["pop"] += 1
        elif current and re.search(r"call void @arena_push\(", line):
            counts[current]["push"] += 1

    # fn -> (frees, arena pops). `escapes` returns its value, so 0 is not a floor
    # to relax; `explicit` calls drop(), so its 1 free is not a ceiling to relax.
    want = {
        "plain__Void":         (0, 1),
        "nested__Void":        (0, 2),
        "per_iteration__Void": (0, 1),
        "early_exits__Void":   (0, 4),   # continue, break, fall-through, return
        "early_return__Bool":  (0, 3),   # inner+outer, then outer
        "explicit__Void":      (1, 0),
        "escapes__Void":       (0, 0),
    }

    problems = []
    for fn, (want_free, want_pop) in want.items():
        if fn not in counts:
            problems.append(f"{fn}: not in the emitted IR")
            continue
        got = counts[fn]
        if got["free"] != want_free:
            problems.append(f"{fn}: {got['free']} free(s), expected {want_free}")
        if got["pop"] != want_pop:
            problems.append(f"{fn}: {got['pop']} arena_pop(s), expected {want_pop}")
        # An arena pushed on one path and popped on none leaks the whole block;
        # more pushes than pops in a function is that bug however the paths run.
        if got["push"] > got["pop"]:
            problems.append(f"{fn}: {got['push']} push(es) but only {got['pop']} pop(s)")

    cleanup_files(out)
    if problems:
        print(f"{RED}[FAIL] reclamation is not being emitted as expected{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] every scope exit reclaims what it allocated, and nowhere else does{RESET}")
    return True


@harness_test(suite="aif", resources={"cpu": 4, "mem": 1500})
def run_no_inference_test():
    """SPEC 7.1's zero-analysis mode, made falsifiable.

    `src/aif.psm` used to carry a comment asserting this invariant held by
    construction, "because nothing it produces is an input to codegen yet". That
    was true at Level 0 and has been false since Level 1: inference now drives
    codegen at eight points -- stack promotion, arena placement, scope drops,
    container element disposition, refcounting, struct-field release, cycle
    collection, and field order. Every one of those changes what is emitted.

    So the invariant is a property to test, not to assert. `--debug` is SPEC
    7.2's level as a budget of zero rounds: the same engine runs and records the
    same pins, but nothing is proved, so widening puts every value at its top
    tier. This asserts what 7.1 actually requires -- **identical observable
    output** -- across every value fixture in the suite.

    `max` is deliberately not offered. With today's engine it would be
    byte-identical to `release`: the bounds it raises are never reached on this
    corpus and there is no monomorphization cap to raise. A flag whose settings
    cannot be told apart is a check that cannot fail.
    """
    print(f"\n{BLUE}--- Running no_inference ---{RESET}")

    fixtures = sorted(TEST_DIR.glob("test_*.psm"))
    release_exe = scratch() / "ni_release.exe"
    debug_exe = scratch() / "ni_debug.exe"

    # SPEC 7.1 is explicit that "behaviourally identical" does NOT mean same tier
    # assignment, same layout or same performance -- only same observable program
    # semantics. A fixture that reads the allocator's own counters is measuring
    # exactly what 7.1 excludes: test_44 asserts 209 arena objects and gets 0 at
    # debug, which is SPEC 7.2's level table working rather than a violation.
    #
    # Detected by reading the source rather than by a name list, so a new fixture
    # that probes the mechanism excludes itself and one that does not is checked.
    PROBES = ("arena_objects", "arena_regions", "arena_bytes",
              "cyc_objects", "cyc_reclaimed", "cyc_collections_run")

    # Two compiles and two runs per fixture, which is four subprocesses times
    # every `test_*.psm` in the suite: **129s of the suite's 178s was here.**
    # They are independent, so they go through the pool -- and each fixture gets
    # its own pair of executables, because the single shared `ni_release.exe`
    # was the only thing that made this sequential.
    def check_one(src):
        text = src.read_text(encoding="utf-8", errors="replace")
        if any(p in text for p in PROBES):
            return ("skip", src.name)
        rel_exe = scratch() / f"ni_release_{src.stem}.exe"
        dbg_exe = scratch() / f"ni_debug_{src.stem}.exe"
        try:
            rel = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(rel_exe)])
            dbg = run_command([str(PRISMIO_EXE), "build", str(src), "--debug",
                               "-o", str(dbg_exe)])

            # A fixture that does not build either way is some other test's problem.
            if rel.returncode != 0 and dbg.returncode != 0:
                return ("ignore", None)
            if rel.returncode != dbg.returncode:
                return ("problem",
                        f"{src.name}: build exit {rel.returncode} at release, "
                        f"{dbg.returncode} at --debug -- a level changed which "
                        "programs compile (SPEC 7.2)")

            ran_rel = run_command([str(rel_exe)])
            ran_dbg = run_command([str(dbg_exe)])
            if ran_rel.stdout != ran_dbg.stdout:
                return ("problem", f"{src.name}: stdout differs between release and --debug")
            if ran_rel.returncode != ran_dbg.returncode:
                return ("problem",
                        f"{src.name}: exit {ran_rel.returncode} at release, "
                        f"{ran_dbg.returncode} at --debug")
            return ("checked", None)
        finally:
            cleanup_files(rel_exe, dbg_exe)

    problems = []
    checked = 0
    skipped = []
    total_fixtures = len(fixtures)
    total_processed = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=test_jobs()) as pool:
        futures = {pool.submit(check_one, f): f for f in fixtures}
        for fut in concurrent.futures.as_completed(futures):
            kind, payload = fut.result()
            total_processed += 1
            if kind == "skip":
                skipped.append(payload)
            elif kind == "problem":
                problems.append(payload)
            elif kind == "checked":
                checked += 1
            if total_processed % 100 == 0 or total_processed == total_fixtures:
                print(f"  [no_inference] {total_processed}/{total_fixtures} fixtures checked...", flush=True)

    cleanup_files(release_exe, debug_exe)
    if checked == 0:
        print(f"{RED}[FAIL] no fixture built at both levels -- the check ran over nothing{RESET}")
        return False
    if problems:
        print(f"{RED}[FAIL] a zero-analysis build is not behaviourally identical{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    note = ""
    if skipped:
        note = f" ({len(skipped)} probing the allocator's own counters, which 7.1 excludes)"
    print(f"{GREEN}[PASS] inference changes no observable output, over {checked} fixture(s){note}{RESET}")
    return True


@harness_test("aif_struct_fields", suite="aif",
              reads=["tests/test_70_struct_field_release.psm"])
def run_aif_struct_field_test():
    """Struct-field ownership, read out of the emitted IR.

    test_49 running clean proves the dynamic counts balance and that nothing is
    freed twice. It cannot prove a release was *generated*, because leaking is
    silently correct -- an implementation that emitted no release function at all
    passes every value assertion in the fixture.

    Two things are asserted here, and they are different claims:

      * the per-field dispositions, which is where a struct differs from a
        container. `Inventory` releases a struct field and a container field and
        steps over two scalars; a container reclaims nothing when its elements
        disagree, and a per-type answer here would have to do the same.
      * that `Slot` gets no release function, so a struct with nothing to own
        does not pay for a generated call.
    """
    print(f"\n{BLUE}--- Running aif_struct_fields ---{RESET}")
    # **Not test_49 any more, and the move is the point.** Automatic call-site
    # placement (SPEC 5.2.1.1, the M3.1 session) reaches test_49's
    # `make_inventory`: the Inventory is served by the arena, reclaimed in bulk,
    # and no `__aif_release_Inventory` is generated at all. That is correct --
    # test_49's ledger went from 146 allocated / 146 released to 9 / 9, still 0
    # leaked and 0 violations -- but it removed two of the three subjects here.
    # test_70 carries the same types with two call sites per constructor, which
    # regime (a) refuses to bracket, so they stay on the heap in the shipped
    # configuration and the generated release is once again the thing under test.
    fixture = TEST_DIR / "test_70_struct_field_release.psm"
    out = scratch() / "t70_fields.ll"

    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(out)])
    if result.returncode != 0:
        print(f"{RED}[FAIL] build exited {result.returncode}{RESET}")
        print(result.stdout or result.stderr)
        return False

    bodies, current = {}, None
    for line in out.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"define void @__aif_release_([A-Za-z0-9_]+)\(", line)
        if m:
            current = m.group(1)
            bodies.setdefault(current, {"free": 0, "list": 0, "typed": 0})
            continue
        if current is None:
            continue
        if line.startswith("define ") or line == "}":
            current = None
            continue
        if re.search(r"call void @rt_free\(", line):
            bodies[current]["free"] += 1
        elif re.search(r"call void @list_release\(", line):
            bodies[current]["list"] += 1
        elif re.search(r"call void @__aif_release_", line):
            bodies[current]["typed"] += 1

    problems = []

    # type -> (plain frees, list releases, typed releases). The plain-free count
    # includes the object's own storage, which is always the last statement --
    # that is what keeps the struct itself behind the allocator seam.
    want = {
        # items: List (list_release) + the object. `lead: Slot` used to be a
        # third: it was a pointer to a separate allocation. Slot is plain data,
        # so it is laid out inline now and lives inside Inventory's own storage
        # -- freeing it would hand a deallocator the middle of our own object.
        # capacity and version are scalars and contribute nothing, which is the
        # per-field claim.
        "Inventory": (1, 1, 0),
        # inner: Inventory, which owns things of its own, so this is a call to
        # that type's release rather than a free -- freeing it here would leak
        # everything hanging off it.
        "Crate":     (1, 0, 1),
        # items: List + the object. tag is a scalar.
        "Holder":    (1, 1, 0),
    }

    for ty, (want_free, want_list, want_typed) in want.items():
        if ty not in bodies:
            problems.append(f"{ty}: no release function was generated")
            continue
        got = bodies[ty]
        if got["free"] != want_free:
            problems.append(f"{ty}: {got['free']} free(s), expected {want_free}")
        if got["list"] != want_list:
            problems.append(f"{ty}: {got['list']} list_release(s), expected {want_list}")
        if got["typed"] != want_typed:
            problems.append(f"{ty}: {got['typed']} typed release(s), expected {want_typed}")

    # A struct with nothing to own must not get one. Item is the same: it is a
    # container element, reclaimed by the teardown rather than by a function.
    for ty in ("Slot", "Item"):
        if ty in bodies:
            problems.append(f"{ty}: owns nothing but got a release function")

    cleanup_files(out)
    if problems:
        print(f"{RED}[FAIL] struct-field releases are not being generated as expected{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] a struct releases the fields it owns, and only those{RESET}")
    return True


@harness_test(suite="aif", resources={"cpu": 2, "mem": 800})
def run_aif_verify_test():
    """SPEC 7.3's verify mode, run over the fixtures that allocate structs.

    The hard invariant is `0 violation(s)`: nothing is released twice and nothing
    is released that the allocator never handed out. That is what a wrong escape
    fact looks like from the outside, and unlike a leak it is a crash waiting to
    happen rather than a slowdown.

    Leak counts are asserted exactly, because they are not noise -- each one is a
    T2 value returned to a caller, and a returned value has a free point only
    where ownership transfer is modelled for its shape.

    **Three of them went to zero on 2026-08-28** and this docstring's promise is
    the reason they are edited rather than argued with: `aif_owns_call_result_at_node`
    now accepts a *plain object* return -- a String, or a struct that owns
    nothing -- where the callee's returns are all accounted for, which is the
    `fn_returns_partial` fact. What is left below is the shape it still does not
    reach: a value returned **two** hops, which needs INFERENCE 6's contexts.
    """
    print(f"\n{BLUE}--- Running aif_verify ---{RESET}")
    expected_leaks = {
        # 2026-09-30: every case in it leaked, dangled or failed to compile.
        "test_236_owned_temporaries_and_literals": 0,
        # 2026-10-09: an index read off an owned temporary in an `if`
        # (`v.sorted()[0]`) and a `match` on an owned call result each get a
        # binding now. Before, every use leaked a header and an element block.
        "test_272_temporary_hoists": 0,
        # 2026-10-09: 300 of 400, pinned. The arm returns the matched payload, so
        # the `Result` it was bound out of must outlive the match and is not
        # released -- a leak where the bound spelling used to return freed memory.
        # If this goes to 0, check the values first: the fixture asserts them.
        "test_273_match_payload_returned": 300,
        # 2026-09-30: scalar T? in every container, as values; Vec<Int?> did
        # not pass the LLVM verifier before.
        "test_238_scalar_optionals": 0,
        "test_242_optional_std": 0,
        "test_243_as_string": 0,
        "test_245_checked_conversions": 0,
        "test_24_drop": 0,
        "test_25_conventions": 0,
        # Both were 1 -- `escapes() -> Point` and `escapes() -> Wide`, each a T2
        # struct returned to a caller that had no way to own it. A plain-object
        # return is now transferred, so both are zero and a 1 reappearing here is
        # that transfer going away.
        "test_42_aif_stack_promotion": 0,   # escapes() -> Point
        "test_43_aif_scope_drop": 0,        # escapes() -> Wide
        # Every other allocation in test_44 is served by an arena and released in
        # bulk, so verify never sees it. One is not.
        #
        # The inner assignment in escapes_inner, whose escape is the *enclosing*
        # region's scope: too long-lived for the inner arena, and not its own
        # scope, so the scope drop declines it too. Correct but imprecise -- it is
        # the case a threaded arena handle would place in the outer arena.
        #
        # **This was 2 until the reassignment half of AIF Level 4 landed.** The
        # other was string_escapes' str_concat, and the reason recorded here was
        # "droppability is a property of a binding's initialiser" -- which was true
        # and was the defect rather than the explanation. An assignment now
        # releases what it displaces, so a binding reassigned only with owned
        # values owns its slot at every point instead of only at its `let`. If this
        # goes back to 2, that release stopped firing.
        "test_44_aif_region": 1,
        # AIF Level 4, and the first fixture where strings and lists are in the
        # accounting at all -- the runtime allocates them, so a verify build
        # compiles the runtime with PRISMIO_AIF_VERIFY to put both ends of every
        # pairing on the same side of the swap. Without that these would be
        # violations, not leaks.
        #
        # The two residual values used to be load-bearing heap leaks:
        #
        #   9 bytes  `owned` in main, which reborrow() binds to a local name.
        #            E-BIND cannot name a scope inside a callee, so it raises the
        #            escape to Caller -- sound, imprecise, and why the drop at
        #            main's exit declines it.
        #   6 bytes  holder.name, which reassigned_from_borrow must NOT free. If
        #            this number goes to 2, the reassignment guard is gone and the
        #            drop is taking a value the struct still owns.
        #
        # There were four until LAYOUT 7.1's automatic arena placement landed.
        # The fourth was the initialiser in reassigned_from_borrow, which is now
        # served by an arena and reclaimed with the block -- and the allocation
        # total fell from 420 to 7, which is the headline for that change.
        #
        # And three until plain-object ownership transfer landed: the fifth was
        # `escapes() -> String`, the 4-byte T2 return, which the caller now owns
        # and frees.
        # Both values are now short inline Strings and allocate no block at all.
        # Their ownership discrimination remains covered by the fixture's value
        # checks; the runtime ledger therefore correctly reads zero.
        "test_45_aif_affine_collections": 0,
        # AIF item 3. Every container in this fixture releases its elements, and
        # every binding that receives one from a known callee releases the
        # container -- so the ordinary cases are zero and what is left is one
        # shape:
        #
        #   2  the result of forwards(): `build`'s list handle and its inline
        #      element block. The four flat Items no longer allocate separately.
        #      Ownership transfer survives one hop, because it requires the
        #      returned site to belong to the callee, and `forwards` returns
        #      `build`'s. Two hops needs INFERENCE 6's contexts.
        #
        # A doubled release here is a violation rather than a missing leak, unlike
        # test_45: these are struct allocations the seam handed out, so releasing
        # one twice is something the accounting can see.
        # **2 -> 0 on 2026-08-29.** The 2 was the result of `forwards()` -- one
        # list handle and its inline element block -- and this docstring said
        # "ownership transfer survives one hop, because it requires the returned
        # site to belong to the callee; two hops needs INFERENCE 6's contexts".
        # It did not need contexts. The one-hop rule was approximating "a value
        # handed in and handed straight back is the caller's", and asking
        # `fn_may_return_param` directly answers that without declining the
        # ordinary producer. A rise back to 2 is that guard reverting.
        "test_47_aif_containers": 0,
        # AIF Level 5. The element shared between two containers is released by
        # the second teardown to reach it, so this is zero -- and it was 2 before
        # the count existed, which is the level's whole measurement on this
        # fixture. A regression shows up as a violation, not a leak: two
        # containers each decrementing a count that was only ever incremented once
        # is a free of live memory.
        "test_48_aif_shared_elements": 0,
        # Struct-field ownership. Zero, and every path in the fixture is a
        # different way of reaching it: a returned owning struct, a struct whose
        # field is another owning struct, and a T0 owner whose field must still
        # be released by its own binding.
        #
        # A regression in the last of those shows up here and only here. Barring
        # a binding because some type's release "will" take it, when that type
        # lives in the frame and is never released, deletes the release rather
        # than moving it -- it took g5_asset_cache from 47 leaked to 2049.
        "test_49_aif_struct_fields": 0,
        # REQUIREMENTS 20. Zero, and the *allocation* count is the interesting
        # half: 12 for six lists, which is two each -- the handle and the element
        # block, and nothing per element. A scalar element that was boxed would
        # make this 12 + one per push, and a scalar element the container thought
        # it owned would be a violation rather than a leak, because `rt_free(42)`
        # is not a pointer the allocator ever handed out.
        "test_50_scalar_lists": 0,
        # REQUIREMENTS 4. One heap allocation in the whole fixture. It leaked until
        # 2026-10-07, for a reason that had nothing to do with optionals:
        #
        #   16 bytes  presence_is_visible's `root`, whose escape is raised to
        #             Caller by an E-BIND in *depth_of_chain*. A field key is one
        #             per nominal type across the module, so both functions share
        #             `Node.parent`, and a bind in one raises the escape of a site
        #             in the other. The same object-insensitivity that keeps
        #             test_47 and test_48 in separate files, reached through a
        #             struct field instead of a container element. INFERENCE 6's
        #             contexts are what would fix it.
        #
        # Everything else in the fixture is T0.
        #
        # It was 1 until 2026-10-07, and the leak was exactly the one named above:
        # `presence_is_visible`'s `root`. Its escape was raised to Caller by the
        # shared `Node.parent` key, through the return of `expect(cur.parent)` in
        # *depth_of_chain* -- a return in another function, which the scope-exit
        # drop (`aif_frees_unless_returned_node`) used to read as "this value leaves
        # the scope". Such a lift (`ret_key == -1`) no longer declines the drop: returning
        # or storing the binding itself still raises its own escape or names its
        # key. Re-derived by running each function alone with the rule reverted:
        # only `presence_is_visible` leaked, 2 allocated / 1 released. Contexts are
        # still the general fix; this one needed only the narrower rule.
        "test_51_optional_refs": 0,
        # A struct handed to a function that returns one of its parameters, bound or
        # stored in a struct field. 0 released of 4 before the same day's rule above
        # (ret_key == -1 accepted); the fixture is the discriminating case.
        "test_268_struct_pass_through": 0,
        # The same where the result outlives the scope that made the arguments --
        # returned, pushed, carried round a loop, assigned outward. Which argument
        # comes back is a run-time fact, so the other has no owner the analysis can
        # name: 9 leaked of 13, 0 violations. Releasing the loser needs a release
        # guarded by pointer equality with the result (KNOWN_ISSUES, Ownership).
        "test_269_struct_pass_through_escapes": 9,
        # AIF T4b. Zero, and it is the first number in this table that a *tracing*
        # step produced: both cycles are unreachable at exit with every count
        # sitting at one, so nothing but trial deletion can tell that the
        # remaining references are internal.
        #
        # A doubled free here is a violation rather than a missing leak, and
        # live_cycle_survives is where that would show: it collects while the
        # cycle is still reachable, so ScanBlack has to restore every count trial
        # deletion removed. Before field edges were counted this fixture
        # segfaulted -- the collector subtracted references nobody had added.
        "test_52_aif_cycle_collector": 0,
        # SPEC 8.4 views, and the only entry in this table where a *rise* is the
        # correct answer. The two functions that return a reference into a list
        # they own make that list escape to the caller (E-VIEW), so the scope
        # drop declines it -- 4 leaked, the two list handles and their two inline
        # element blocks. Flat Items are built in those blocks and do not have
        # separate allocations.
        #
        # It was 0 before, and the 0 was wrong: the lists were freed with their
        # elements and the pointers handed back anyway. **`--verify` cannot see
        # that.** Its accounting is per allocation, and every one of these
        # allocations *was* correctly released -- reading one afterwards is a
        # different property. The fixture asserts the values itself for exactly
        # that reason, and on the pre-E-VIEW compiler it exits 1 while this
        # table reads 0 leaked, 0 violations.
        #
        # So a drop here is not progress. It means the container is being freed
        # under a live reference again, and only test_53's own exit code says so.
        # These 4 go to zero when a T2 return gains a free point, and not before.
        "test_53_aif_views": 4,
        # AIF Level 4's reassignment half. One, and it is the *negative* direction
        # of the feature: borrow_reassign's initialiser, which the guard has to
        # decline because the slot ends up holding `h.name`. Declining it leaks 6
        # bytes; not declining it frees a value the struct still owns, so this
        # entry going to 0 is a regression and not an improvement -- it would show
        # up as a violation here and a wrong length in the fixture's own exit code.
        #
        # The other end of the discrimination is the allocation count rather than
        # this number. It scales with the loop bounds because every case whose
        # point is the release *returns* its accumulator -- a confined one is
        # served by an arena and tests nothing.
        #
        # **Three generations, three numbers, and all three still matter**, which
        # is what makes this fixture a guard for M2.0 and M2.0b separately:
        #   S27b (before the release)       21 allocated,  3 released, 18 leaked
        #   S35b (M2.0, extern-allocated)   27 allocated, 19 released,  8 leaked
        #   S36b (M2.0b, callee-returned)   27 allocated, 25 released,  2 leaked
        #
        # Those two strings now fit in the inline representation and create no
        # physical allocation. Zero here is therefore allocation elimination,
        # not an illicit release; the fixture still checks that the borrowed
        # field remains intact.
        "test_72_reassigned_ownership": 0,
        # M2.1a, and the first entry in this table for a *self-referential* type.
        # Zero, against 100 on the generation before it with the same 106
        # allocations -- the feature reclaims, it does not allocate less, so a
        # change that moved the first number is not this one working.
        #
        # A rise here means `__aif_release_Tree` stopped recursing, or stopped
        # being generated at all: `field_closes_cycle` vetoed every field that
        # re-enters its owner's type, which left a consumed tree reclaimed by
        # nothing -- not by the release, and not by the collector either, which
        # wants `in_container`. Violations rather than leaks would mean the
        # opposite: the veto's own case, an edge the collector owns being freed
        # here as well. test_52 is what asserts that half.
        "test_73_recursive_release": 0,
        # M2.1c. The number here is **not** what this fixture is for -- it does
        # not compile at all on the generation before M2.1c, so a regression in
        # the feature is a build failure, and `neg_10_move_in_loop` guards the
        # other direction. What the count tracks is M2.1a-ii's residue: the trees
        # this fixture rebuilds are consumed through a `sink`; before M2.1b
        # nothing reclaimed or reused the destructured block.
        #
        # **504 -> 248 on 2026-08-29, and it is fewer allocations rather than
        # more frees**: 511 allocated / 7 released became 255 allocated / 7
        # released, with violations 0 in both. A payload-free enum variant used
        # to fill its unused pointer payload slots with freshly malloc'd,
        # entirely uninitialised nodes; they are `none` now. Exactly half this
        # fixture's allocations were those fillers.
        #
        # **248 -> 93 on 2026-09-01, and this time it is more frees rather than
        # fewer allocations**: 255 allocated / 7 released became 255 / 162, with
        # violations 0 in both. A self-recursive producer is one site serving the
        # root and every interior node, and the root inherited the child's
        # "already released by a field" answer -- so the caller was refused the
        # one drop that would have reclaimed the structure. The fall is this
        # note's own prediction; what remained was the `sink` residue above.
        #
        # **93 -> 0 on 2026-09-02, with allocations 255 -> 69.** M2.1b pairs
        # each consumed Tree constructor with the same-tag constructor returned
        # by mapAdd. The old block is the new block, so the scope-drop guard also
        # honours the stamped move; otherwise old and new bindings release one
        # physical tree twice. See RESULTS-M2-reuse-token.md.
        "test_74_reinit_assignment": 0,
        # Boxed OBJECT replacement through the explicit exclusive capability.
        # The displaced Named owns a String, so zero proves list_set_exclusive
        # invoked the typed element release; ordinary list_set leaves one leak
        # for exactly this shape. The two neg_4x fixtures guard the other half:
        # an observed list and an inline element type are both rejected.
        "test_83_list_set_exclusive": 0,
        # An owned call result consumed directly as an argument, 2026-08-29.
        # **Zero, and the file is built so that only ownership can move it**: it
        # runs the same loop twice, once binding the result to a `let` and once
        # passing it straight in, and both halves print the same answer. The
        # bound half was always 27/27/0; the unbound half was 107/27/80, because
        # codegen only asked aif_owns_call_result_at_node at a binding and a
        # temporary has none.
        #
        # A rise to 40 is the argument-position release going away. A *fall* in
        # `released` with this at zero would be the arena hiding the question
        # again -- the samples list and the clock calls in the fixture are there
        # to make call-site bracketing decline, and without them no arena leaves
        # anything for this to own.
        "owned_temporary_argument": 0,
        # The two guards that came back from `aif/evidence/xlang/` when that tree
        # was superseded on 2026-09-03. **They are asserted here rather than run
        # by the corpus test, and that is a promotion**: the corpus checks an exit
        # status, and neither defect changes one. `pointer_return_temp` leaked
        # 100 of 100 while exiting 0; `extern_alias_escape` printed an empty line
        # and exited 0 while double-owning a string.
        #
        # `wrap(make())` returns a fresh `Box` that cannot be the `String` it was
        # handed, so the argument-position release must fire. A rise to 100 is the
        # kind test coming back -- codegen withholding the release for any result
        # that carries a pointer. See RESULTS-pointer-return-temporary.md.
        "pointer_return_temp": 0,
        # `let t = make(); let x = <extern alias>(t); return x`. **Read
        # `violations` here, not `leaked`**: the defect was one allocation with two
        # owners, which reports as `release of a pointer that is not live` rather
        # than as a leak, and the loop above fails the fixture on any violation.
        # See RESULTS-extern-alias-escape.md.
        "extern_alias_escape": 0,
        # Consuming String append. The fixture performs 9,192 logical appends,
        # including self/view aliases and a concat site also stored in a list.
        # Geometric growth with allocation-free inline integer formatting and
        # short concat measures under 50 allocations; immutable
        # concat-per-iteration is over 10,000. The exact
        # leak count protects ownership, while the ceiling below protects the
        # amortised architecture rather than timing a noisy CI host.
        "test_100_string_append_reuse": 0,
        # `sortBy` over inline and boxed elements, and `list_swap`. What this
        # guards is the 0 violations: the sorts used to free an address inside a
        # flat-struct list's block. It read 1 until 2026-09-27: `words` holds only
        # literals written at a push, which no site describes, so the list was
        # never told it owned them (aif_elem_literal_copies_only).
        "test_144_sort_inline_elements": 0,
        # A flat element copied within its own list, whose release of that
        # interior address aborted in `free`. See list_release_source.
        "test_145_list_set_within_list": 0,
        # Vec's methods, and the removals above all. What this guards is the 0
        # violations: `removeAt` takes an element a live view still reads, and a
        # removal that released it at once would be a free under that view. The
        # 0 since 2026-09-30: the name inside the `Job` copy `removeAt` returns
        # was the last, declined because `Job.name` also held literals -- which
        # are tagged borrowed now, so the field releases what it owns. It read
        # 3 until 2026-09-27 (aif_elem_literal_copies_only).
        "test_155_vec_methods": 0,
        # `x[i] = v` across arrays, Vec and Slice. An array store is a plain
        # store with no release, admitted only for elements nobody owns, so a
        # leak here is an owning element getting through that gate.
        "test_156_index_store": 0,
        # An element read stored into a container -- another one or its own, as
        # `v[i] = v[j]`. Every shape was a double free and the flat one a wrong
        # answer; the violations are what this guards. A leak here would be the
        # counted tier's teardown missing an element, as a Vec holding both a
        # counted and an uncounted element of one type still does (KNOWN_ISSUES).
        "test_157_shared_container_elements": 0,
        # A Vec binding with no initializer is `= []`. A leak here would be the
        # synthesised literal missing the owner an explicit one gets.
        "test_159_vec_binding_empty": 0,
        # COLLECTIONS 1e. A removal with no live view releases at once; the peak
        # ceiling below is what says so, since parking balances the ledger too.
        "test_161_removal_releases_now": 0,
        # The removals that must park. The 7 were the known shape, identical on
        # the compiler before 1e: copies of one String site held by two Vecs were
        # counted (T3), which a String cannot use, so none was released. A fresh
        # String in two containers is no longer that (test_255), so they are
        # released. What this guards is the 0 violations.
        "test_162_removal_parks_under_view": 0,
        # Array fields are the struct's own bytes and release nothing. 0 since
        # 2026-09-30: `total(makeGrid(1).cells, 4)` reads a field off an unbound
        # temporary, which is released after the call now that the call's
        # result is a scalar and so cannot hold the view (memberChainRoot).
        "test_164_array_fields": 0,
        # A Vec literal in a struct literal and an assigned field. Both used to
        # leak the Vec: the struct lived on the frame, which releases no field,
        # and nothing else owned a value written straight into one.
        "test_149_list_literal": 0,
        # Ranges, `step`, `repeat` and labels. A leak here would be a labelled
        # jump skipping the scope drops between it and the loop it names.
        "test_165_ranges_repeat_labels": 0,
        # `for ... in` over every collection, computed ones bound to a hidden
        # `let`. The 1 was the long String in `names`: its copy site was held by
        # two Vecs and so counted, which a String cannot be released from. Fixed
        # with test_255's rule; a 1 back here is that rule going away.
        "test_166_for_each_collections": 0,
        # Fields of a struct on the frame. 22 leaked before its owned
        # temporaries had an owner; what this guards is that and the 0
        # violations. The 1 was a long String element whose copy site was counted
        # (T3) because two Vec literals share it; a fresh String in two
        # containers is no longer counted (test_255).
        "test_167_frame_struct_fields": 0,
        # std.term's methods chained on owned results. A leak here is a method
        # returning a helper's allocation -- a pass-through its caller gets no
        # drop for -- which leaks both strings of every `"x".red().bold()`.
        "test_168_terminal_styling": 0,
        # Call-result ownership asked of the call, not the allocation site
        # (call_result_held), and a temporary whose callee returns a view of it
        # given a binding (irHoistBorrowedTemporaries). 2,365 of 2,371 leaked
        # before: one `Box { text: make(n) }` in an uncalled function refused
        # the release to every `concat` result in the program.
        "test_184_call_result_ownership": 0,
        # Ten, and each is deliberate: `aliased` and `rebound` return the value
        # under a name the drop cannot see, five times each, so they keep the
        # refusal. Every other shape releases what it does not return. More than
        # ten is that release gone; a violation is it firing on a returned path.
        "test_205_return_on_one_path": 10,
        # A view of a binding kept past the binding's scope: pushed into a Vec,
        # or assigned outward. These leak by design -- the binding is kept -- and
        # what the fixture guards is the 0 violations and the strings reading
        # back right; the compiler before 2026-09-25 aborted on it. A fall here
        # is a copy-on-keep landing; a rise is a keeper the guards stopped seeing.
        # 18 since 2026-09-30 (was 22): four of the kept Strings were declined
        # only because a literal could reach the same place.
        # 13 since 2026-10-01 (was 18): a String view pushed into a Vec<String> is
        # now copied at the push (fatMarkedAsView), the copy-on-keep this comment
        # names, so the Vec owns the copy and frees it. The rest are views of a
        # binding's own storage that are kept, and still leak by design.
        # 4 since 2026-10-07 (was 13): `lookup` answers a `String?`, a pointer, where
        # it answered an `Option<String>`, a tagged struct holding one -- so the
        # fixture no longer pays an `Option` allocation per kept lookup.
        "test_185_view_outlives_binding": 4,
        # The same, pushed with no binding in between, including a temporary the
        # hoist gave one. 18 until the push copied the view (2026-10-01): each Vec
        # was declined for a view that might be a literal, so neither freed its
        # elements; a copy is an owned block and is freed. A rise is that copy
        # no longer being made, and the violations would follow.
        "test_186_view_pushed_directly": 0,
        # Copying a Vec<String>: take, skip, concat, reversed, sorted, toVec, clone,
        # filter, extend and a HashMap's keys. 273 leaked until a fresh String stored in
        # two containers stopped counting as one value held twice (A-CONTAIN).
        "test_255_string_vec_copies": 0,
        # The shape that rule must not reach: an element read pushed into two
        # containers is one block held three times. Codegen copies it into a block
        # of its own at the push (fatMarkedAsView), and the analysis counts the
        # store as that copy; 0 violations is the guard, and a leak here is the two
        # sides disagreeing about whether the copy is made.
        "test_256_string_view_pushed_twice": 0,
        # A struct made fresh and stored in two Vecs of one type: the first's
        # displaced elements were never released (A-CONTAIN counted the one `frag`
        # site as one value held twice). The exemption test_255 made for a String
        # now covers any move-only site. The 4 are the `Pair` blocks that an element
        # read pushed into two containers keeps held by design (one value, three
        # holders; 4 until a small Vec's header and elements became one block); 0 violations is the guard, and a rise in the leaks is the
        # exemption reaching `Frag`/`Node` no longer.
        "test_302_struct_in_two_vecs": 2,
        # Overwrites that release at once and overwrites that must park, side by side;
        # 0 violations is the guard that no release reached a view still read.
        "test_317_overwrite_release": 0,
        "test_318_overwrite_peak": 0,
        # A field store releases the value it displaces where no view is live
        # (test_320, 0 leaked) and keeps it where one may be (test_321: the 300
        # lists of `held`, `heldForNext` and `rebuilt`, one block each since a small
        # Vec's header and elements are one allocation; 0 violations is the guard).
        "test_320_field_store_release": 0,
        "test_321_field_store_parks": 300,
        # Two bindings of one name are two bindings: a `let` that stores an owner and a
        # later `for` binder of the same name (a view) used to share one analysis key,
        # which sent every site of the type to the counted tier and leaked all of it.
        "test_322_binding_keys": 0,
        # A private Vec field that no view of an element outlives is a closed column
        # (src/ir/columns.psm): 200,000 replacements of one element peak at 551 bytes where
        # they parked 8.4 MB. test_389 is the other half, the uses that must keep parking
        # (a bound view read after the store, the column passed on, iterated while stored
        # into, a view handed to a function that stores); 0 violations is the guard that no
        # release reached a view still read.
        "test_388_closed_columns": 0,
        "test_389_open_columns": 0,
        # A small Vec of known capacity is one block, header and elements; every way it
        # stops being one (growth, reserve, a field replaced) must free each block once.
        "test_323_fused_list": 0,
        # A value stored into a module-level `let`, a field of one or a container
        # reached through one. **Read `violations`, not `leaked`**: a global is never
        # released, so everything it holds at exit is counted -- 59 of 62, the
        # globals' values and every value of a site they share (all `concat` results
        # here come from one site, so the clobbering strings count too). The defect
        # was a double owner: the value's own function released it at scope end while
        # the global still pointed at it, which reports as a violation and, in the
        # fixture's own exit code, as the wrong string.
        "test_352_global_store_escapes": 59,
    }

    max_allocations = {
        "test_100_string_append_reuse": 80,
    }

    # Peak live bytes. test_161 clears and refills one Vec 400 times: released
    # at once it peaks at 208 bytes, parked at 35,102.
    max_peak_bytes = {
        "test_161_removal_releases_now": 2048,
        # 2,000 replacements of four Vec-owning structs: 528 bytes released at once,
        # 176,449 parked (src/ir/overwrites.psm).
        "test_318_overwrite_peak": 4096,
        # 2,000 replacements of a node's edge list, six ways: released at once the
        # peak is a few hundred bytes, leaked it is the sum of every list.
        "test_320_field_store_release": 4096,
        "test_322_binding_keys": 4096,
        "test_388_closed_columns": 4096,
    }

    # Objects served by an arena. test_164 builds 100,000 structs with an array
    # field in a loop and reads one element of each: an element read is a copy,
    # so each struct stays in the frame. Were the read a view of the struct, all
    # 100,000 would go to the function's arena and be held until it returns.
    max_arena_objects = {
        "test_164_array_fields": 8,
    }

    exe = scratch() / "aif_verify_probe.exe"
    problems = []
    for name, want_leaks in expected_leaks.items():
        src = TEST_DIR / f"{name}.psm"
        built = run_command([str(PRISMIO_EXE), "build", str(src), "--verify", "-o", str(exe)])
        if built.returncode != 0:
            problems.append(f"{name}: --verify build exited {built.returncode}")
            continue

        ran = run_command([str(exe)])
        report = re.search(r"aif-verify: (\d+) allocated, (\d+) released, "
                           r"(\d+) leaked, (\d+) violation\(s\)", ran.stderr or "")
        if not report:
            problems.append(f"{name}: no aif-verify report -- the allocator seam "
                            "was not redirected")
            continue

        allocated = int(report.group(1))
        leaked, violations = int(report.group(3)), int(report.group(4))
        if violations:
            problems.append(f"{name}: {violations} violation(s) -- a value was "
                            "released twice, or released without being allocated")
        if leaked != want_leaks:
            problems.append(f"{name}: {leaked} leaked, expected {want_leaks} "
                            "(if this dropped, T2 now has a free point and the "
                            "expectation should follow)")
        peak = re.search(r"(\d+) peak live bytes", ran.stderr or "")
        if name in max_peak_bytes and (not peak or int(peak.group(1)) > max_peak_bytes[name]):
            problems.append(f"{name}: peak live bytes {peak.group(1) if peak else '?'}, "
                            f"expected at most {max_peak_bytes[name]} (a removal parked what "
                            "it could have released)")
        arena = re.search(r"aif-arena:\s+(\d+) object", ran.stderr or "")
        if name in max_arena_objects and (not arena or int(arena.group(1)) > max_arena_objects[name]):
            problems.append(f"{name}: {arena.group(1) if arena else '?'} arena objects, "
                            f"expected at most {max_arena_objects[name]} (a struct read by "
                            "element left the frame)")
        if name in max_allocations and allocated > max_allocations[name]:
            problems.append(f"{name}: {allocated} allocations, expected at most "
                            f"{max_allocations[name]} (String append is no longer "
                            "growing geometrically)")

    cleanup_files(exe)
    if problems:
        print(f"{RED}[FAIL] verify mode reported a fact that did not hold{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] verify: no double frees, and leaks are only the T2 returns{RESET}")
    return True


@harness_test("aif_annotations", suite="aif",
              reads=["tests/test_46_aif_annotations.psm"])
def run_aif_annotation_test():
    """SPEC 5's annotations, read back out of the manifest.

    test_46 running clean proves they change no answer, which is SPEC 5's first
    requirement and the more important one. It cannot prove they did anything at
    all -- an implementation that parsed both and dropped them on the floor would
    pass it. This is the other half: the annotated site's tier and origin, against
    its unannotated twin's.
    """
    print(f"\n{BLUE}--- Running aif_annotations ---{RESET}")
    fixture = TEST_DIR / "test_46_aif_annotations.psm"
    records, _ = aif_records(fixture)
    if records is None:
        print(f"{RED}[FAIL] could not read a manifest for {fixture.name}{RESET}")
        return False

    # symbol -> (tier, origin). The twins differ only in the annotation, so any
    # difference in these columns is the annotation's doing and nothing else.
    want = {
        "annotated_unique__Void#0": ("T1", "unique"),
        "plain_unique__Void#0":     ("T1", "inferred"),
        # The pin freezes above the derived tier, so this one is deliberately
        # *worse* than its twin -- that is what freezing means, and it is what
        # keeps a manifest stable across an unrelated edit.
        "annotated_pin__Void#0":    ("T2", "pin"),
        "plain_pin__Void#0":        ("T1", "inferred"),
        "annotated_both__Void#0":   ("T2", "pin"),
        # `unique` on a parameter is keyed on what the caller passed, so the
        # origin lands on main's allocation rather than inside the callee.
        "main#0":                   ("T1", "unique"),
    }

    problems = []
    for symbol, (tier, origin) in want.items():
        if symbol not in records:
            problems.append(f"{symbol}: not in the manifest")
            continue
        got_tier, got_origin = records[symbol][0], records[symbol][2]
        if got_tier != tier:
            problems.append(f"{symbol}: tier {got_tier}, expected {tier}")
        if got_origin != origin:
            problems.append(f"{symbol}: origin {got_origin}, expected {origin}")

    if problems:
        print(f"{RED}[FAIL] annotations did not reach the manifest{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] `unique` cuts aliasing and `pin` freezes a tier, both recorded{RESET}")
    return True


@harness_test(suite="aif",
              reads=["tests/test_47_aif_minimal_cause.psm"])
def run_aif_minimal_cause_test():
    """SPEC 6.3's witness path, checked for shape rather than for prose.

    The interesting property is that the path is a *chain*: a value stored into a
    container inherits the container's escape, so explaining it takes both edges
    and in that order. An implementation that recorded only the last rule to fire
    would print one edge and look plausible, which is exactly the failure this
    catches.
    """
    print(f"\n{BLUE}--- Running aif_minimal_cause ---{RESET}")
    fixture = TEST_DIR / "test_47_aif_minimal_cause.psm"

    def why(symbol):
        return run_command([str(PRISMIO_EXE), "aif", str(fixture),
                            "--owned-collections", f"--why={symbol}"])

    # symbol -> the rules its witness path should visit, innermost edge first.
    want = {
        # The string is stored into the box, and the box is returned. Two edges,
        # and the return has to be the *last* one -- it is the root cause.
        "boxed__Void#1":  ["A-STORE", "E-RETURN"],
        "boxed__Void#0":  ["E-RETURN"],
        "direct__Void#0": ["E-RETURN"],
        # Dies where it was made, so the path is the allocation and there is
        # nothing to repair.
        "local__Void#0":  ["ALLOC"],
    }

    problems = []
    for symbol, rules in want.items():
        result = why(symbol)
        if result.returncode != 0:
            problems.append(f"{symbol}: --why exited {result.returncode}")
            continue
        got = re.findall(r"<- (\S+)", result.stdout)
        if got != rules:
            problems.append(f"{symbol}: path {got}, expected {rules}")
        # A repair list that is only the rejected pin means nothing actionable
        # was derived, which is right for a root and wrong for anything else.
        actionable = "rejected --" not in result.stdout.split("repairs")[-1].split("\n")[1]
        if rules == ["ALLOC"] and actionable:
            problems.append(f"{symbol}: a repair was offered for an allocation root")
        if rules != ["ALLOC"] and not actionable:
            problems.append(f"{symbol}: no repair derived from a path with {len(rules)} edge(s)")

    # An unknown symbol has to fail rather than print an empty explanation, or a
    # differ that mistypes one gets silence instead of an error.
    missing = why("no_such_symbol#0")
    if missing.returncode == 0:
        problems.append("--why on an unknown symbol exited 0")

    if problems:
        print(f"{RED}[FAIL] the witness path is not what the derivation says{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] minimal cause walks the derivation, and repairs follow the path{RESET}")
    return True


# REQUIREMENTS 15 added T4a. The order is the solver's ordinal order, T4a above
# T4b -- see AIF_T4A in src/aifcore/ for the argument. This dict is not
# decoration: aif_records() filters records by membership, so a tier missing
# here vanishes from the parse and reads as "the site population changed".
TIER_ORDER = {"T0": 0, "T1": 1, "T2": 2, "T3": 3, "T4b": 4, "T4a": 5}


# The manifest record table, by column *name*.
#
# Introduced when REQUIREMENTS 15 added the `thread` column and five separate
# parsers in this file broke at once, every one of them holding a hard-coded
# `parts[2]` or `parts[5]`. They failed loudly, which was luck: a parser whose
# index slides onto a neighbouring column reads a plausible string and asserts
# against it, and src/aif/report.psm already carries a comment about a tier
# regression that could not fail the gate for exactly that reason.
#
# Columns are whitespace-separated and only `site` may contain none of its own,
# so a split with a fixed field count is enough and the trailing path survives.
MANIFEST_COLUMNS = ("tier", "thread", "placement", "type", "layout", "origin", "site")


def manifest_records(text):
    """symbol -> {column name: value} for every record line in a manifest."""
    out = {}
    for line in text.splitlines():
        parts = line.split(None, len(MANIFEST_COLUMNS))
        if len(parts) <= len(MANIFEST_COLUMNS):
            continue
        if "#" not in parts[0] or parts[1] not in TIER_ORDER:
            continue
        out[parts[0]] = dict(zip(MANIFEST_COLUMNS, parts[1:]))
    return out


def aif_records(source, budget=None):
    """symbol -> (tier, was_widened, origin) from a manifest run.

    The columns are `symbol tier placement type layout origin site`, and the site
    is last because a path may contain spaces and nothing else may.
    """
    cmd = [str(PRISMIO_EXE), "aif", str(source), "--manifest"]
    if budget is not None:
        cmd.append(f"--budget={budget}")
    result = run_command(cmd)
    if result.returncode != 0:
        return None, result
    out = {r: (v["tier"], v["origin"] == "budget-exhausted", v["origin"])
           for r, v in manifest_records(result.stdout).items()}
    return out, result


@harness_test(suite="aif",
              reads=["benchmarks/**", "tests/aif_tiers.psm"])
def run_aif_widening_test():
    """INFERENCE 5.3: truncating the ascending iteration yields a *pre*-fixed
    point, whose facts are too optimistic -- so the widening that follows must
    leave every site at or above the tier full convergence gives it. Below is a
    use-after-free rather than a slowdown.

    Checked as a property over every budget from 1 to convergence, because the
    frontier is a different set at each one, and against sources whose fact
    phase is long enough for it to be a proper subset -- the compiler's own
    source converges in two fact rounds, so it only ever exercises widen-all.
    """
    print(f"\n{BLUE}--- Running aif_widening ---{RESET}")
    sources = [TEST_DIR / "aif_tiers.psm"]
    sources += sorted((TEST_DIR.parent / "benchmarks" / "hosted" / "prismio").glob("*.psm"))

    problems = []
    saw_partial = False
    for src in sources:
        converged, result = aif_records(src)
        if converged is None:
            problems.append(f"{src.name}: `aif` exited {result.returncode}")
            continue
        m = re.search(r"^rounds\s+(\d+)", result.stdout, re.M)
        if not m:
            problems.append(f"{src.name}: no round count in the manifest")
            continue

        for budget in range(1, int(m.group(1))):
            got, _ = aif_records(src, budget)
            if got is None:
                problems.append(f"{src.name} --budget={budget}: `aif` failed")
                continue
            if set(got) != set(converged):
                problems.append(f"{src.name} --budget={budget}: the site "
                                "population changed with the budget")
                continue
            widened = sum(1 for rec in got.values() if rec[1])
            if 0 < widened < len(got):
                saw_partial = True
            for sym, (tier, _, _origin) in got.items():
                if TIER_ORDER[tier] < TIER_ORDER[converged[sym][0]]:
                    problems.append(
                        f"{src.name} --budget={budget}: {sym} is {tier} "
                        f"truncated but {converged[sym][0]} converged -- "
                        "widening lowered a tier")

    # Without this the test would still pass if widening raised everything
    # every time, which is sound but would make the frontier dead code.
    if not saw_partial:
        problems.append("no budget produced a partial frontier, so the "
                        "narrowing in aif_widen was never exercised")

    if problems:
        print(f"{RED}[FAIL] widening is not monotone{RESET}")
        for p in problems[:10]:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] widening never lowers a tier, at any budget{RESET}")
    return True


@harness_test(suite="aif")
def run_task_release_test():
    """The task handle has an owner, and only where AIF proved it may.

    `prismio_task_release` existed from the day tasks did and codegen never
    emitted it, so every `spawn` leaked one handle. `--verify` cannot see it --
    the handle is plain `calloc`, correctly, because it is a runtime temporary
    the runtime frees itself -- so the assertion has to be on the emitted IR.

    Three facts, and all three are needed. The first alone would pass against a
    compiler that released *every* handle, which is a use-after-free on the two
    shapes below it:

      many_frames        proved joined and never copied -> one release per spawn
      copied_handle      `let u = t` aliases the handle -> no release
      join_inside_a_loop a `while` may run zero times, so E-SPAWN-J cannot prove
                         the join -> no release

    The fixture separately checks that all three still compute the right answer,
    which is what would break if a release landed in the wrong place.
    """
    print(f"\n{BLUE}--- Running task_release ---{RESET}")

    fixture = TEST_DIR / "test_84_task_release.psm"
    with tempfile.TemporaryDirectory(prefix="prismio-task-release-") as td:
        ll = Path(td) / "task.ll"
        built = subprocess.run(
            [str(PRISMIO_EXE), "build", str(fixture), "-o", str(ll)],
            capture_output=True, text=True, encoding="utf-8", errors="replace")
        if built.returncode != 0 or not ll.is_file():
            print(f"{RED}[FAIL] task release: build failed{RESET}")
            print(f"{built.stdout}\n{built.stderr}"[:1200])
            return False

        # Attribute every release to the function it is in, so "two releases
        # somewhere in the module" cannot stand in for "two releases in the one
        # function that may have them".
        current, found = None, {}
        for line in ll.read_text(encoding="utf-8").splitlines():
            if line.startswith("define "):
                current = line.split("@", 1)[1].split("(", 1)[0] if "@" in line else None
            elif "call void @prismio_task_release" in line and current:
                found[current] = found.get(current, 0) + 1

        want = {"many_frames__Void": 2}
        forbidden = ("copied_handle__Void", "join_inside_a_loop__Void")

        for fn, n in want.items():
            if found.get(fn, 0) != n:
                print(f"{RED}[FAIL] task release: {fn} emitted {found.get(fn, 0)} "
                      f"release(s), expected {n}{RESET}")
                return False
        for fn in forbidden:
            if found.get(fn, 0) != 0:
                print(f"{RED}[FAIL] task release: {fn} released a handle it does "
                      f"not exclusively own{RESET}")
                return False
        extra = set(found) - set(want)
        if extra:
            print(f"{RED}[FAIL] task release: unexpected release in {sorted(extra)}{RESET}")
            return False

    print(f"{GREEN}[PASS] task release: emitted where the join is proved, "
          f"withheld for a copied handle and an unprovable join{RESET}")
    return True


@harness_test(suite="aif")
def run_string_operator_ledger_test():
    """The String operators lower to methods that own their allocations.

    `a + b`, `s[i]`, `s[a..b]` and the four orderings are rewritten in
    src/sema/checker.psm into `concat`, `charAt`, `slice` and `compare`. Those
    five carry their bodies in `impl String` rather than delegating to a `str*`
    free function, and that is load-bearing rather than tidy: a function whose
    `return` is another function's allocation is a pass-through, so its caller
    gets no drop as soon as an argument is itself owned -- the callee's one site
    is then in the return's points-to set and in the parameter's at once.

    **Nothing else in the suite can see a regression to delegation.** It
    type-checks, it answers the same strings, and every value assertion in
    test_91 still passes; only the ledger moves. Measured on a 1,000-iteration
    `let t = f("a","b"); let u = f(t,"c")`: delegating reads 2,001 allocated /
    1 released / 2,000 leaked, owning the body reads 2,001 / 2,001 / 0.

    The fixture is ledger-clean by construction -- every owned result in it is
    bound -- so `released == allocated` is the whole assertion, and the
    owned-left-operand lines are the ones that would break. Asserted rather than
    stated in a comment, because a comment is not a check.
    """
    print(f"\n{BLUE}--- Running string_operator_ledger ---{RESET}")

    fixture = TEST_DIR / "test_91_string_ergonomics.psm"
    with tempfile.TemporaryDirectory(prefix="prismio-string-ledger-") as td:
        exe = os.path.join(td, "t91")
        built = run_command([str(PRISMIO_EXE), "build", str(fixture),
                             "--verify", "-o", exe])
        if built.returncode != 0 or not os.path.exists(exe):
            print(f"{RED}[FAIL] string operator ledger: the --verify build failed{RESET}")
            print(f"{built.stdout}\n{built.stderr}"[:1200])
            return False

        ran = run_command([exe])
        text = f"{ran.stdout}\n{ran.stderr}"
        m = re.search(r"aif-verify:\s+(\d+) allocated,\s+(\d+) released,"
                      r"\s+(\d+) leaked,\s+(\d+) violation", text)
        if not m:
            print(f"{RED}[FAIL] string operator ledger: no aif-verify ledger line, "
                  f"so nothing was asserted{RESET}")
            print(text[:1200])
            return False

        allocated, released, leaked, violations = (int(g) for g in m.groups())
        # A ledger of nothing balances trivially. The fixture allocates through
        # every one of the five, so a count this low means it stopped exercising
        # them and the balance below proves nothing. 12 rather than the 20 it
        # was: std's split functions keep a part of twelve bytes or fewer in the
        # pair, and a `List<String>` stores it there, which took this fixture's
        # `split` and `lines` calls from 21 allocations to 18 without it
        # exercising any operator less. 10 since 2026-10-07: `find` and `get` answer
        # an `Int?` and a `Char?` now, which allocate nothing, where an `Option`
        # allocated one each.
        if allocated < 10:
            print(f"{RED}[FAIL] string operator ledger: only {allocated} allocation(s), "
                  f"so the fixture is no longer exercising the operators and a "
                  f"balanced ledger says nothing{RESET}")
            return False
        if violations != 0:
            print(f"{RED}[FAIL] string operator ledger: {violations} violation(s) -- "
                  f"corruption, not a leak{RESET}")
            return False
        if leaked != 0 or released != allocated:
            print(f"{RED}[FAIL] string operator ledger: {allocated} allocated, "
                  f"{released} released, {leaked} leaked. An operator's lowering "
                  f"target stopped owning its result -- check that `concat`, "
                  f"`slice`, `charAt` and `compare` in std/string.psm still carry "
                  f"their bodies instead of delegating to a `str*` function{RESET}")
            return False

    print(f"{GREEN}[PASS] string operator ledger: {allocated} allocated, "
          f"{released} released, 0 leaked, 0 violations -- the five lowering "
          f"targets own what they return{RESET}")
    return True
