import json
import re
import subprocess
import sys
import os
import tempfile
from pathlib import Path
import shutil
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


def run_punned_slot_invariant_test():
    """Nothing may take ordinal 0 in NodeKind or TypeKind.

    A source check, because the property is about a declaration order and no
    runtime observation can distinguish "the invariant holds" from "the invariant
    is broken but nothing has punned a zero-kinded node yet". That gap is exactly
    how MODULE sat at ordinal 0 making every module root read as an empty slot,
    with a green suite, for as long as nobody tested a root.

    tests/test_41_punned_slot_bytes.psm covers the mechanism; this covers the fix.
    """
    print(f"\n{BLUE}--- Running punned_slot_invariant ---{RESET}")

    checks = [
        (PROJECT_ROOT / "src" / "ast" / "nodes.psm", "NodeKind"),
        (PROJECT_ROOT / "src" / "ast" / "types.psm", "TypeKind"),
    ]

    problems = []
    for path, enum_name in checks:
        text = path.read_text(encoding="utf-8")
        m = re.search(rf"enum\s+{enum_name}\s*\{{(.*?)\}}", text, re.S)
        if not m:
            problems.append(f"{path.name}: no `enum {enum_name}` found")
            continue
        variants = [v.strip() for v in re.sub(r"//[^\n]*", "", m.group(1)).split(",")]
        variants = [v for v in variants if v]
        if not variants or variants[0] != "NEVER_ZERO":
            first = variants[0] if variants else "(empty)"
            problems.append(
                f"{enum_name}: ordinal 0 is `{first}`, not NEVER_ZERO. "
                f"A {enum_name}-first struct punned as String would read as an empty slot."
            )

    if problems:
        print(f"{RED}[FAIL] punned-pointer invariant broken{RESET}")
        for p in problems:
            print(f"  {p}")
        print("  see the invariant in src/ast/nodes.psm")
        return False

    print(f"{GREEN}[PASS] NodeKind and TypeKind both reserve ordinal 0{RESET}")
    return True


AIF_EXPECTED = {
    "tier_zero__Void#0":        "T0",
    "tier_one_string__Void#0":  "T1",
    "tier_one_wide__Void#0":    "T1",
    "tier_one_dropped__Void#0": "T1",
    "tier_two__Void#0":         "T2",
    "tier_three__Void#0":       "T3",
    "tier_four_cyclic__Void#0": "T4b",
    # #0 is the array; #1 and #2 are the two allocations nested in its elements,
    # which exist only if the walk descends into them.
    "tier_array_elements__Void#0": "T1",
    "tier_array_elements__Void#1": "T1",
    "tier_array_elements__Void#2": "T1",
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

    # Asserted separately from the tiers because the type graph can be wrong in
    # the direction that reports *fewer* cycles without any tier moving. Lives
    # in --summary, hence the second run.
    summary = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--summary"])
    if "collector needed: 1 of" not in summary.stdout:
        problems.append("Tree reaches itself through List<Tree>, but the "
                        "cyclicity report does not say so")

    if problems:
        print(f"{RED}[FAIL] tier assignment changed{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] AIF assigns every SPEC 4.2 clause its expected tier{RESET}")
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
    result = run_command([str(PRISMIO_EXE), "aif", str(source)])
    if result.returncode != 0:
        return None, result
    got = {r: (v["tier"], v["thread"])
           for r, v in manifest_records(result.stdout).items()}
    return got, result


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


def run_oracle_vocabulary_test():
    """The compiler and `aif/prototype/aif.py` must know the same builtins.

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
    oracle_src = (PROJECT_ROOT / "aif" / "prototype" / "aif.py").read_text(encoding="utf-8")

    produces = set(re.findall(
        r'str_equals\(name,\s*"([a-z_0-9]+)"\)\s*==\s*1\)\s*\{\s*return true\s*\}', contracts))
    at = oracle_src.find("FFI_RETURNS_PRODUCE = {")
    if at < 0 or not produces:
        print(f"{RED}[FAIL] could not locate both produce lists -- this check has "
              f"gone blind, which is the thing it exists to prevent{RESET}")
        return False
    block = oracle_src[at:oracle_src.index("}", at)]
    oracle = set(re.findall(r"'([a-z_0-9]+)'", block))

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

    print(f"{GREEN}[PASS] compiler and oracle agree on all {len(produces)} "
          f"producing runtime calls{RESET}")
    return True


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

    sources = sorted((PROJECT_ROOT / "aif" / "corpus").glob("*.psm"))
    sources += [TEST_DIR / "test_57_pin_tiers.psm", TEST_DIR / "test_58_region_serves.psm"]

    problems = []
    tmp = TEST_DIR / "_manifest_parse.txt"
    for src in sources:
        result = run_command([str(PRISMIO_EXE), "aif", str(src)])
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


def run_region_diagnostic_test():
    """SPEC 5.2 / 5.2.1 / 5.2.1.1 -- the arena diagnostics, and which regions the
    warning is allowed to fire on.

    test_58 asserts at run time that an arena serves what it claims. This asserts
    the *reporting* halves, each of which was a live defect:

      * a region serving nothing warns, and one serving something does NOT. The
        second half is the discriminator -- a warning that fired on every region
        would satisfy any test that only looked for the text. Since call-site
        placement landed (2026-08-16) the fixture has two of each, so the pairing
        is checked in both directions on one compilation.
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
    exe = TEST_DIR / "test_58_region_serves.exe"
    build = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(exe)])
    text = (build.stdout or "") + (build.stderr or "")

    # Two regions serve and two do not, in one compilation. Asserting all four is
    # what makes this a discriminator rather than a substring search: a warning
    # that fired on everything fails the second pair, one that fired on nothing
    # fails the first.
    for region in ("outlived_work", "shared_work"):
        if f"region {region} serves no allocation" not in text:
            problems.append(f"no warning for `{region}`, which serves nothing -- "
                            f"the region that a bracket declines is exactly the one "
                            f"a programmer needs told about")
    for region in ("work", "callee_work"):
        if f"region {region} serves no allocation" in text:
            problems.append(f"warned about `{region}`, which serves 50 allocations -- "
                            f"the diagnostic is firing on every region, not on inert ones")
    if "cannot reach it" not in text:
        problems.append("the warning lost its note, which is the half that names the repair")
    cleanup_files(exe)

    manifest = run_command([str(PRISMIO_EXE), "aif", str(fixture)])
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
    if placements.get("make_shared__Int#0") == "region:shared_work":
        problems.append("make_shared__Int#0 was bracketed with two call sites -- "
                        "regime (a) is not being applied")
    # The bracket is recorded, which SPEC 5.2.1.1 requires of an implementation
    # using regime (a): the placement can be removed by an edit somewhere else in
    # the file, so it has to be visible in a diff.
    if "bracketed calls (SPEC 5.2.1.1 regime (a))" not in manifest.stdout:
        problems.append("the manifest does not record which call sites were bracketed")
    elif "#   make " not in manifest.stdout:
        problems.append("the bracketed-calls section does not name `make`")
    if "peak-bytes  128 bytes" not in manifest.stdout:
        problems.append("peak-bytes for a region that serves 50 sites is not 128")

    # `region:none` -- a T1 site the heap serves. test_57's list sites are the
    # case, and `region:scope` must not come back.
    other = run_command([str(PRISMIO_EXE), "aif", str(TEST_DIR / "test_57_pin_tiers.psm")])
    if "region:none" not in other.stdout:
        problems.append("no T1 site reports region:none")
    if "region:scope" in other.stdout:
        problems.append("region:scope is back -- it reads as a placement and is not one")

    # The corrected budget estimate. 64 before the cost model learned the
    # codegen gate's in_container clause, 0 after, and the arena holds zero.
    budget = run_command([str(PRISMIO_EXE), "aif", str(TEST_DIR / "test_49_aif_struct_fields.psm")])
    if "peak-bytes  0 bytes" not in budget.stdout:
        problems.append("test_49 still estimates arena bytes for an arena that "
                        "serves nothing (REQUIREMENTS 19's gate reads this)")

    # SPEC 6.3's placement witness. `--why` explained the tier and said nothing
    # about where the value lives, so a reader who fixed the tier found the
    # binary unchanged -- three sessions running. The gate short-circuits, so the
    # load-bearing property is that EVERY blocker is listed, not the first.
    # `make_shared` and not `make`: since 2026-08-16 `make` is bracketed and so
    # reports a placement rather than a blocker list. `make_shared` is the same
    # allocation in the same shape that regime (a) declines, so it is the record
    # that still exercises every clause of the gate.
    why = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--why=make_shared__Int#0"])
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


def run_placement_pin_test():
    """SPEC 5.4 applied to placement -- `pin(<region-name>)` can fail a build.

    **The point of this check is that the annotation can refute, on a program
    that otherwise compiles.** `test_63_placement_pin.psm` compiles and both its
    pins are honoured; `neg_26_placement_pin_refuted.psm` is rejected. Neither
    alone is evidence: a compiler that honoured every placement pin passes the
    first, one that refuted every placement pin passes the second, and an
    annotation that cannot fail is this project's most-produced defect.

    So this takes the file that compiles, adds a second call to its bracketed
    callee -- the exact edit SPEC 5.2.1.1 says silently removes the placement --
    and requires the compiler to reject the result *for that reason*. One edit,
    both directions, on one program.

    It also reads the manifest, because "honoured" has to be visible there
    (SPEC 5.4) and because a pin that was silently dropped and one that was
    honoured are indistinguishable from the exit code alone.
    """
    print(f"\n{BLUE}--- Running placement_pin ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_63_placement_pin.psm"
    manifest = run_command([str(PRISMIO_EXE), "aif", str(fixture)])

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
    marker = "        // MUTATION-POINT-SECOND-CALL"
    if marker not in source:
        problems.append("test_63 lost its MUTATION-POINT marker, so the "
                        "can-it-fail half of this check did not run")
    else:
        mutant = TEST_DIR / ".prismio-placement-pin-mutant.psm"
        mutant.write_text(
            source.replace(marker,
                           "        let extra = bracketed_make(99)\n"
                           "        if (extra.id != 99) { return fail(\"mutant\") }"),
            encoding="utf-8")
        out = TEST_DIR / ".prismio-placement-pin-mutant.exe"
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
            if "may have exactly one" not in text:
                problems.append("the refusal does not name regime (a)'s call-site "
                                "count, which is the one thing that tells a reader "
                                "which edit to undo")
        cleanup_files(mutant, out)

    if problems:
        print(f"{RED}[FAIL] pin(<region-name>) does not guard the placement{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] pin(<region-name>) is recorded honoured, and a second call "
          f"site to a bracketed callee fails the build{RESET}")
    return True


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

    The same disagreement is 2/12 against 8/12 on `aif/corpus/g1_particles.psm`,
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

    manifest = run_command([str(PRISMIO_EXE), "aif", str(fixture)])
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
            if released < 2 * bodies:
                problems.append(
                    f"{released} released against {bodies} split objects. Both "
                    f"halves of every body have to be reclaimed, so this cannot "
                    f"be below {2 * bodies}: the cold blocks are leaking.")
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


def run_object_cache_test():
    """REQUIREMENTS 10, applied to the one module every build shares: the runtime.

    Every build used to compile `lang_runtime.c` and `program_support.c` from
    source and delete the objects, which on this host is 203 ms of a 411 ms build
    of a 34-line program. They are cached now, keyed on the content of the source
    and the compile flags.

    Three assertions, because the first two alone are satisfied by a cache that is
    never invalidated -- and a stale object cache is a silently wrong binary,
    which is the failure this project produces most.

      1. **A cold cache misses and a warm one hits.** Read off the trace rather
         than off the clock: "the second build was faster" is not something a
         test can assert on a shared host.
      2. **A hit still produces a working program.** The cached object is linked,
         so a cache that stored the wrong file would link the wrong runtime.
      3. **A `--verify` build misses on a warm release cache, and hits itself.**
         `--verify` compiles the same file with -DPRISMIO_AIF_VERIFY, so the two
         objects are different objects. Serving the release one to a verify build
         puts half the allocations outside the ledger, silently -- the same
         failure the verify path already refuses an installed runtime.lib for.

    And `PRISMIO_OBJ_CACHE=0` must not consult the cache at all, because a bypass
    that does not bypass is how a stale entry survives the one instruction given
    for getting rid of it.

    **What this cannot check, and why.** The other half of the key is the source
    text, and no test here can move it: a normal build unpacks the runtime
    *embedded in the compiler binary* rather than reading runtime/ from disk
    (build_driver.c, PRISMIO_EMBEDDED_SOURCE_AVAILABLE), so editing the tree
    changes nothing a user build compiles. Content still belongs in the key --
    `prismio bootstrap` does read the filesystem -- but the assertion that would
    exercise it costs a bootstrap, which is minutes.
    """
    print(f"\n{BLUE}--- Running object_cache ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_09_strings.psm"
    out = TEST_DIR / ".prismio-objcache-check.exe"

    with tempfile.TemporaryDirectory(prefix="prismio-objcache-test-") as cache_dir:
        def build(extra_env=None, extra_args=None):
            env = dict(os.environ)
            # Cleared rather than inherited: this check is about what the cache
            # does, so an ambient PRISMIO_OBJ_CACHE=0 -- someone running the
            # suite with caching off to measure it -- would otherwise fail the
            # test for a reason that has nothing to do with the code.
            env.pop("PRISMIO_OBJ_CACHE", None)
            env["PRISMIO_OBJ_CACHE_DIR"] = cache_dir
            env["PRISMIO_OBJ_CACHE_TRACE"] = "1"
            env.update(extra_env or {})
            cmd = [str(Path(PRISMIO_EXE).resolve()), "build", str(fixture), "-o", str(out)]
            r = subprocess.run(cmd + (extra_args or []), capture_output=True, text=True, env=env)
            return r, (r.stdout or "") + (r.stderr or "")

        cold, cold_text = build()
        warm, warm_text = build()

        if cold.returncode != 0 or warm.returncode != 0:
            problems.append("the build failed with the object cache enabled")
        if "[objcache miss] lang_runtime" not in cold_text:
            problems.append("the first build into an empty cache did not report a miss, "
                            "so the trace this check reads is not being produced and "
                            "every assertion below it is vacuous")
        if "[objcache hit] lang_runtime" not in warm_text:
            problems.append("the second build did not hit the cache -- the entry was "
                            "not installed, or the key is not stable across runs")

        # Said directly rather than inferred from the hit above, because the way
        # an install fails is silent: `rename()` cannot cross a filesystem, so a
        # cache directory on a different volume from the temporary would leave a
        # working build that never populates anything.
        installed = [n for n in os.listdir(cache_dir) if n.endswith(".obj")]
        if not installed:
            problems.append("the cache directory is empty after a build that reported a "
                            "miss -- the object was compiled and never installed")
        leftovers = [n for n in os.listdir(cache_dir) if n.startswith(".tmp-")]
        if leftovers:
            problems.append(f"the cache directory holds temporaries after a successful "
                            f"build: {leftovers[:3]} -- an install failed, or the temporary "
                            f"is not being cleaned up")

        # 2. The cached object is the one that gets linked.
        ran = run_command([str(out)])
        if ran.returncode != 0 or "PASS" not in (ran.stdout or ""):
            problems.append("the program built from the cached runtime object does not "
                            "run correctly, so the cache is serving the wrong file")

        # The documented bypass has to bypass.
        _, bypass_text = build({"PRISMIO_OBJ_CACHE": "0"})
        if "[objcache off] lang_runtime" not in bypass_text:
            problems.append("PRISMIO_OBJ_CACHE=0 did not report the cache as off")
        if "[objcache hit]" in bypass_text:
            problems.append("PRISMIO_OBJ_CACHE=0 still served an object from the cache")

        # 3. The flags are part of the key.
        verify_first, verify_text = build(extra_args=["--verify"])
        if verify_first.returncode != 0:
            problems.append("the --verify build failed with the object cache enabled")
        if "[objcache miss] lang_runtime" not in verify_text:
            problems.append("a --verify build hit the entry a release build filled -- "
                            "the flags are not in the key, so half the allocations in a "
                            "verify build would be outside the ledger")
        _, verify_again = build(extra_args=["--verify"])
        if "[objcache hit] lang_runtime" not in verify_again:
            problems.append("a second --verify build missed, so verify builds are not "
                            "cached at all rather than cached separately")

    cleanup_files(out)

    if problems:
        print(f"{RED}[FAIL] the toolchain object cache is not sound{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] the runtime object is cached: cold misses, warm hits, the "
          f"program still runs, --verify keys separately, and the bypass bypasses{RESET}")
    return True


def run_bootstrap_command_test():
    """`prismio bootstrap` builds a compiler, and the compiler it builds is right.

    This command could not link between the move to the LLVM C API and
    2026-08-17: its link line had no `-lLLVM-C`, so it compiled everything and
    then failed with several hundred undefined `_LLVM*` symbols. Nothing in the
    tree ran it -- CI and every session use `tools/bootstrap.sh` -- so nothing
    noticed for months, while `compiler_build_executable` printed a NOTE
    recommending it.

    Two assertions, and the second is the one with teeth. "It linked" is what a
    smoke test would check, and a compiler can link and still be wrong -- built
    against stub headers, or against a different LLVM. So the binary it produces
    is asked to compile a program, and its IR has to match byte for byte what
    the compiler running this suite produces for the same program.

    That is also what keeps the two recipes honest. There are two places that
    know how to link a compiler now -- this command and the bootstrap scripts --
    and two copies of a recipe that must agree is how this broke in the first
    place. This is the check that makes a disagreement loud.
    """
    print(f"\n{BLUE}--- Running bootstrap_command ---{RESET}")
    problems = []

    with tempfile.TemporaryDirectory(prefix="prismio-bootstrap-cmd-") as wd:
        built = Path(wd) / "selfbuilt"
        r = subprocess.run([str(Path(PRISMIO_EXE).resolve()), "bootstrap",
                            str(TEST_DIR.parent / "src" / "main.psm"), "-o", str(built)],
                           capture_output=True, text=True)
        if r.returncode != 0 or not built.exists():
            text = ((r.stdout or "") + (r.stderr or "")).strip().splitlines()
            problems.append("`prismio bootstrap` did not produce a compiler: "
                            + " | ".join(text[-4:]))
        else:
            fixture = TEST_DIR / "test_09_strings.psm"
            mine, theirs = Path(wd) / "a.ll", Path(wd) / "b.ll"
            a = run_command([str(built), "build", str(fixture), "-o", str(mine)])
            b = run_command([str(Path(PRISMIO_EXE).resolve()), "build", str(fixture),
                             "-o", str(theirs)])
            if a.returncode != 0 or not mine.exists():
                problems.append("the compiler `prismio bootstrap` built cannot compile a program")
            elif b.returncode != 0 or not theirs.exists():
                problems.append("the compiler running this suite could not emit the "
                                "reference IR, so there was nothing to compare against")
            elif mine.read_bytes() != theirs.read_bytes():
                problems.append("the compiler `prismio bootstrap` built emits different IR "
                                "from the one running this suite -- it linked, and it is not "
                                "the same compiler")

    if problems:
        print(f"{RED}[FAIL] `prismio bootstrap` does not build a working compiler{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] `prismio bootstrap` builds a compiler whose IR matches this one's"
          f"{RESET}")
    return True


def run_bootstrap_cache_key_test():
    """The bootstrap scripts cache toolchain objects, and the key has to be content.

    `tools/bootstrap.sh` and `tools/bootstrap.ps1` compile seven C sources on
    every generation -- 1.44 s of a 2.7 s self-build -- and now reuse them from
    `$TMPDIR/prismio-objcache`. This is the one build path whose contract is that
    an edit to `runtime/*.c` reaches the next generation, so a stale entry here
    poisons a compiler generation rather than a test binary.

    Both scripts therefore expose `--print-cache-key` / `-PrintCacheKey`, which
    computes the key and nothing else, so this can assert the four properties
    that matter in milliseconds instead of by bootstrapping:

      1. **Stable.** The same tree twice gives the same key, or nothing is ever
         reused and the cache is only overhead.
      2. **Sensitive to the source.** Editing the `.c` changes its key.
      3. **Sensitive to the headers.** Editing `prismio_runtime.h` changes the
         key of a `.c` that was not touched. This is the assertion with teeth: a
         header changes what a source compiles to without changing a byte of it,
         and keying on the `.c` alone serves an object built against the previous
         header — which is precisely what a session that regenerates
         `embedded_sources.h` does.
      4. **Distinct per source.** Two sources do not share an entry.

    The edits are made in a copied tree, passed with `--repo`, so the real
    `runtime/` is never touched. `PRISMIO_LLVM_DIR` is set to a fixed string so
    the key does not depend on how this host found LLVM — no compiling happens
    here, only hashing.
    """
    print(f"\n{BLUE}--- Running bootstrap_cache_key ---{RESET}")
    problems = []

    repo = TEST_DIR.parent
    if os.name == "nt":
        script = ["powershell", "-NoProfile", "-File", str(repo / "tools" / "bootstrap.ps1")]
        key_flag, repo_flag = "-PrintCacheKey", "-Repo"
    else:
        script = ["bash", str(repo / "tools" / "bootstrap.sh")]
        key_flag, repo_flag = "--print-cache-key", "--repo"

    with tempfile.TemporaryDirectory(prefix="prismio-cachekey-") as tree:
        shutil.copytree(repo / "runtime", Path(tree) / "runtime")

        def key(source):
            env = dict(os.environ)
            env["PRISMIO_LLVM_DIR"] = "/fixed/llvm"
            env.pop("PRISMIO_OBJ_CACHE", None)
            r = subprocess.run(script + [key_flag, source, repo_flag, tree],
                               capture_output=True, text=True, env=env)
            if r.returncode != 0:
                problems.append(f"printing the cache key for {source} failed: "
                                f"{(r.stderr or r.stdout).strip()[:200]}")
                return None
            return (r.stdout or "").strip()

        source = Path(tree) / "runtime" / "lang_runtime.c"
        header = Path(tree) / "runtime" / "prismio_runtime.h"
        original_source = source.read_text(encoding="utf-8")
        original_header = header.read_text(encoding="utf-8")

        base = key("lang_runtime.c")
        if base and key("lang_runtime.c") != base:
            problems.append("the key is not stable across two runs on one tree, so nothing "
                            "would ever be reused and the cache is pure overhead")

        other = key("aif_support.c")
        if base and other == base:
            problems.append("two different sources produce the same cache entry")

        source.write_text(original_source + "\n// cache key check\n", encoding="utf-8")
        edited = key("lang_runtime.c")
        if base and edited == base:
            problems.append("editing lang_runtime.c did not change its key -- the key is not "
                            "the content, and the next generation would link the old object")
        source.write_text(original_source, encoding="utf-8")

        header.write_text("/* cache key check */\n" + original_header, encoding="utf-8")
        after_header = key("lang_runtime.c")
        if base and after_header == base:
            problems.append("editing prismio_runtime.h did not change lang_runtime.c's key -- "
                            "a header changes what a source compiles to without changing a byte "
                            "of it, so this serves an object built against the old header")
        header.write_text(original_header, encoding="utf-8")

        if base and key("lang_runtime.c") != base:
            problems.append("restoring the tree did not restore the key, so at least one of the "
                            "differences above was caused by something other than the edit")

    if problems:
        print(f"{RED}[FAIL] the bootstrap object cache key is not sound{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] the bootstrap cache key is stable, per-source, and moves when "
          f"either the source or a header does{RESET}")
    return True


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
         Forced unsplit releases 4096 fewer objects than a forced split, and that
         gap is what proves the force reached codegen rather than only the report.
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
            released_by_cut[cut] = int(ledger.group(2))
            if int(ledger.group(4)) != 0:
                problems.append(
                    f"{ledger.group(4)} violation(s) at a forced cut of {cut}. The "
                    f"release path has to be right for every candidate §8 can "
                    f"compile, not only for the argmin.")

    if 4 in released_by_cut and 12 in released_by_cut:
        # A split allocates the cold block per object; unsplit does not. The gap is
        # the object count, and it is the check that separates "the force reached
        # codegen" from "the report agreed with itself".
        gap = released_by_cut[4] - released_by_cut[12]
        if gap != bodies:
            problems.append(
                f"forced split released {gap} more objects than forced unsplit, "
                f"expected exactly {bodies} -- one cold block per body. A force "
                f"that only moved the manifest would read 0 here.")

    if problems:
        for p in problems:
            print(f"{RED}[FAIL] {p}{RESET}")
        return False
    print(f"{GREEN}[PASS] a named candidate is emitted, runs correct at every cut, "
          f"and an unmatched force changes nothing{RESET}")
    return True


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
    # alone reads non-zero here. On test_58 exactly one call is placed, and the
    # same number has to come back off a second, independent surface: `--summary`
    # counts it from the call graph, the manifest prints one line per bracket. If
    # either wording moves, the two stop agreeing and this fails; a check that
    # read only one of them would go quietly to zero.
    def bracketed_count(path):
        out = run_command([str(PRISMIO_EXE), "aif", str(path), "--summary"]).stdout
        m = re.search(r"^bracketed\s+(\d+)", out, re.M)
        return int(m.group(1)) if m else -1

    def bracket_lines(path):
        out = run_command([str(PRISMIO_EXE), "aif", str(path)]).stdout
        if "bracketed calls (SPEC 5.2.1.1 regime (a))" not in out:
            return 0
        at = out.index("bracketed calls (SPEC 5.2.1.1 regime (a))")
        return len([l for l in out[at:].splitlines()[1:] if l.startswith("#   ")])

    if bracketed_count(fixture) != 0:
        problems.append(f"test_59 has no `region` and still reports "
                        f"{bracketed_count(fixture)} bracketed call(s) -- a function "
                        f"clearing the obligations is not a placement")
    served = TEST_DIR / "test_58_region_serves.psm"
    if bracketed_count(served) != 1:
        problems.append(f"--summary reports {bracketed_count(served)} bracketed "
                        f"call(s) on test_58, expected exactly 1 (`make`; `make_out` "
                        f"fails obligation 3 and `make_shared` fails regime (a))")
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

    result = run_command([str(PRISMIO_EXE), "aif", str(fixture)])
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
    ll = TEST_DIR / "test_57_pin_tiers.ll"
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
    out = TEST_DIR / "t42_slots.ll"

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


def run_aif_rc_test():
    """AIF Level 5, checked in the IR because neither half shows in a value.

    The negative half is the load-bearing one. An OPAQUE site must never be
    refcounted -- the pointer came back from a function this compilation cannot
    see, so there is no header in front of it and `rc_release` would decrement
    whatever the real allocator put there. Every one of the compiler's 37 T3 sites
    is an opaque extern return, so `src/main.psm` must emit **zero** calls to
    rc_alloc while still declaring it. That makes this the only check that the
    exclusion holds on the one program large enough to violate it.
    """
    print(f"\n{BLUE}--- Running aif_rc ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_48_aif_shared_elements.psm"
    out = TEST_DIR / "t48_rc.ll"
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

    compiler_out = TEST_DIR / "main_rc.ll"
    result = run_command([str(PRISMIO_EXE), "build",
                          str(TEST_DIR.parent / "src" / "main.psm"), "-o", str(compiler_out)])
    if result.returncode != 0:
        problems.append(f"building src/main.psm exited {result.returncode}")
    else:
        cir = compiler_out.read_text(encoding="utf-8", errors="replace")
        cleanup_files(compiler_out)
        n = len(re.findall(r"call ptr @rc_alloc\b", cir))
        if n:
            problems.append(f"{n} call(s) to rc_alloc in the compiler -- every T3 "
                            "site there is an opaque extern return, and a header "
                            "in front of one of those is memory we never allocated")

    if problems:
        print(f"{RED}[FAIL] refcounting is not where it should be{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] T3 is counted where it is ours and nowhere else{RESET}")
    return True


def run_aif_view_test():
    """SPEC 8.4's E-VIEW, checked in the manifest and in the IR.

    Both halves are load-bearing and the *negative* one is what took three
    attempts to get right. E-VIEW couples a collection's lifetime to a reference
    read out of it, and the obvious implementations couple far too much:

      - reading the element key directly makes every read a view of every list
        in the file, because that key is object-insensitive. It demoted three
        untouched containers in test_47.
      - treating a scalar read as a view demoted a `List<Int>` for returning an
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

    result = run_command([str(PRISMIO_EXE), "aif", str(fixture)])
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
         "an Int read out of a List<Int> is a copy, not a view"),
        ("view_in_a_callee__Void#0",
         "the view is taken in a callee, so it dies inside this activation"),
    ):
        got = tiers.get(sym)
        if got is None:
            problems.append(f"{sym}: not in the manifest")
        elif got[0] != "T1":
            problems.append(f"{sym}: {got[0]}, expected T1 -- {why}")

    # The IR half. The tier is only interesting because of what it deletes.
    out = TEST_DIR / "t53_view.ll"
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

    measured_ll = TEST_DIR / "workload_measured.ll"
    static_src = TEST_DIR / "workload_static_control.psm"
    static_ll = TEST_DIR / "workload_static.ll"

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
            exe = TEST_DIR / f"workload_{label}.exe"
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
        failing_src = TEST_DIR / "workload_failing.psm"
        failing_exe = TEST_DIR / "workload_failing.exe"
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
        for leftover in TEST_DIR.glob(".prismio-*"):
            try:
                leftover.unlink()
            except OSError:
                pass

    return ok


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
_LLVM_WIDTH_BITS = {"i1": 8, "i8": 8, "i16": 16, "i32": 32, "i64": 64,
                    "double": 64, "ptr": 64}


def _expected_layout(elements):
    """(offsets, total_size), in bits, for a C-style struct of these elements."""
    offset = 0
    worst = 8
    offsets = []
    for e in elements:
        width = _LLVM_WIDTH_BITS.get(e)
        if width is None:
            return None, 0
        worst = max(worst, width)
        if offset % width:
            offset += width - (offset % width)
        offsets.append(offset)
        offset += width
    if offset % worst:
        offset += worst - (offset % worst)
    return offsets, offset


def _emitted_struct(ir, name):
    m = re.search(r"^%%%s = type \{(.*)\}" % re.escape(name), ir, re.M)
    if not m:
        return None
    return [e.strip() for e in m.group(1).split(",") if e.strip()]


def run_debug_info_test():
    """`-g`, checked on the two things it can get wrong silently.

    Neither is visible from a value test. A program with debug info computes
    exactly what the same program without it computes -- that is the point of the
    feature -- so the only evidence is the metadata itself.

    **1. A release build must carry none of it.** The whole feature is gated on
    one flag, and the property that let it land is that `prismio build` without
    `-g` emits the IR it emitted before debug info existed. A stray unconditional
    call to the DWARF layer would not fail anything else in this suite; it would
    change 98 programs' output and nobody would notice until the next IR diff.

    **2. A location must not be wrong.** This is the sharp half. Two ways it can
    be, and both are checked:

      - *the line table shifts.* Every `// MARK` in the fixture names a statement
        whose line must appear in a DILocation. An off-by-one -- or a location
        taken from the enclosing node rather than the statement -- moves them all.
      - *a member offset is computed from the wrong layout.* A module with no
        `target datalayout` is laid out by LLVM's default specification, in which
        i64 has a 4-byte ABI alignment; `{ i32, i64 }` is 12 bytes there and 16 on
        every target this compiler supports. Emitting the default's offsets puts
        DW_AT_data_member_location four bytes from the field on every struct with
        a 64-bit member after a 32-bit one, and a debugger would confidently print
        the wrong value. So: -g pins the layout, and every 64-bit member is
        required to be 64-bit aligned.

    And the case AIF makes hard, which is why it is worth a fixture of its own:
    LAYOUT 6 can move the tail of a record into a separately allocated cold block.
    There is no offset in the hot record that names a cold field, so the type must
    describe what is really there -- hot members, a `__cold` pointer, and a second
    composite behind it. A build that listed all eight fields at eight offsets in
    a 32-byte record would be the exact failure this feature must not have.
    """
    print(f"\n{BLUE}--- Running debug_info ---{RESET}")
    source = TEST_DIR / "debug_info.psm"
    plain = TEST_DIR / "debug_plain.ll"
    dbg = TEST_DIR / "debug_g.ll"
    split = TEST_DIR / "debug_split.ll"

    # Which cut to force is read from the model rather than written down here.
    # A forced candidate the search does not offer is a warning and no split, so
    # a hardcoded number would turn "the model reranked" into "this test quietly
    # stopped checking the split".
    layout = run_command([str(PRISMIO_EXE), "aif", str(source), "--layout"])
    cuts = re.findall(r"^\s+Reading\s+\d+\s+\d+\s+split (\d+)/\d+",
                      layout.stdout or "", re.M)
    if not cuts:
        print(f"{RED}[FAIL] the model offers no split candidate for `Reading`, "
              f"so the cold-block half of this test cannot run{RESET}")
        print(layout.stdout or layout.stderr)
        return False
    hot_cut = cuts[0]

    for out, extra in ((plain, []), (dbg, ["-g"]),
                       (split, ["-g", f"--force-layout=Reading:{hot_cut}"])):
        result = run_command([str(PRISMIO_EXE), "build", str(source),
                              "-o", str(out)] + extra)
        if result.returncode != 0:
            print(f"{RED}[FAIL] build {' '.join(extra) or '(no flags)'} exited "
                  f"{result.returncode}{RESET}")
            print(result.stdout or result.stderr)
            cleanup_files(plain, dbg, split)
            return False

    plain_ir = plain.read_text(encoding="utf-8", errors="replace")
    dbg_ir = dbg.read_text(encoding="utf-8", errors="replace")
    split_ir = split.read_text(encoding="utf-8", errors="replace")
    cleanup_files(plain, dbg, split)

    problems = []

    # 1. A release build carries nothing.
    for marker in ("!DICompileUnit", "!DILocation", "!DISubprogram", "!dbg",
                   "target datalayout"):
        if marker in plain_ir:
            problems.append(f"a build without -g emitted `{marker}` -- debug info "
                            "is no longer gated on the flag, and every program's "
                            "IR has moved with it")

    # 2a. A -g build carries the whole chain.
    for marker in ('!DICompileUnit', '"Debug Info Version"', 'target datalayout'):
        if marker not in dbg_ir:
            problems.append(f"a -g build is missing `{marker}`")

    for fn in ("scaled", "describe", "main"):
        if re.search(r'!DISubprogram\(name: "%s"' % fn, dbg_ir) is None:
            problems.append(f"no subprogram for `{fn}`")

    # 2b. The line table names the lines the statements are on.
    marks = {}
    for i, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
        m = re.search(r"// MARK ([\w-]+)", line)
        if m:
            marks[m.group(1)] = i
    if not marks:
        problems.append("the fixture has no `// MARK` comments -- this test "
                        "stopped checking the line table")

    located = {int(m.group(1))
               for m in re.finditer(r"!DILocation\(line: (\d+)", dbg_ir)}
    for name, line in sorted(marks.items()):
        if line not in located:
            problems.append(f"nothing is attributed to line {line} "
                            f"(`{name}`) -- the line table has shifted")
    if 0 in located:
        problems.append("a DILocation claims line 0 -- a synthesised node was "
                        "given a location instead of inheriting the statement's")

    # 2c. Members sit where the host layout puts them, not where LLVM's default
    # specification would.
    nodes = _di_nodes(dbg_ir)
    members, total = _di_composite(nodes, "Reading")
    if members is None:
        problems.append("no composite type for `Reading` -- struct layouts are "
                        "not being described at all")
    else:
        names = [f for f, _, _ in members]
        if sorted(names) != sorted(["id", "label", "scale", "magnitude",
                                    "channel", "revision", "weight", "offset"]):
            problems.append(f"unsplit `Reading` describes {names}, which is not "
                            "its eight fields")
        elements = _emitted_struct(dbg_ir, "Reading")
        want_offsets, want_total = _expected_layout(elements or [])
        if want_offsets is None or len(want_offsets) != len(members):
            problems.append("could not recompute `Reading`'s layout from the "
                            f"emitted `%Reading = type {{{elements}}}` -- this "
                            "test stopped checking offsets")
        else:
            if total != want_total:
                problems.append(f"`Reading` is described as {total} bits and "
                                f"natural alignment makes it {want_total} -- the "
                                "offsets came from LLVM's default data layout, "
                                "where i64 is 4-byte aligned, rather than the "
                                "host's")
            for (field, offset, size), want in zip(members, want_offsets):
                if offset != want:
                    problems.append(f"`Reading.{field}` is described at bit "
                                    f"{offset} and belongs at {want}")

    # 2d. And the one shape where the two layouts actually disagree. Reading
    # happens to come out the same either way -- the search packs its two 32-bit
    # fields into one 8-byte slot, so nothing lands at a bad offset. Checkpoint
    # cannot: field 0 is pinned, so its i64 sits behind a lone i32 and is at bit
    # 64 on every supported target and at bit 32 under LLVM's default
    # specification. That difference is a debugger reading four bytes early.
    cmembers, ctotal = _di_composite(nodes, "Checkpoint")
    if cmembers is None:
        problems.append("no composite type for `Checkpoint`")
    else:
        want = {"tick": 0, "stamp": 64}
        for field, offset, _ in cmembers:
            if field in want and offset != want[field]:
                problems.append(f"`Checkpoint.{field}` is described at bit "
                                f"{offset} and is at {want[field]} -- a debugger "
                                "would read the wrong bytes for it")
        if ctotal != 128:
            problems.append(f"`Checkpoint` is described as {ctotal} bits and is "
                            "128")

    # 3. A split type is described as what it is.
    snodes = _di_nodes(split_ir)
    hot, hot_size = _di_composite(snodes, "Reading")
    cold, _ = _di_composite(snodes, "Reading.cold")
    if hot is None or cold is None:
        problems.append("--force-layout produced no split composite: hot="
                        f"{hot is not None} cold={cold is not None}")
    else:
        hot_names = [f for f, _, _ in hot]
        cold_names = [f for f, _, _ in cold]
        if "__cold" not in hot_names:
            problems.append("the hot record has no `__cold` member, so nothing "
                            "in the debug info reaches the cold fields")
        for field, offset, size in hot:
            if offset + size > hot_size:
                problems.append(f"`Reading.{field}` is at bit {offset} of a "
                                f"{hot_size}-bit hot record -- a cold field has "
                                "been given an offset in a record it is not in")
        overlap = set(hot_names) & set(cold_names)
        if overlap:
            problems.append(f"{sorted(overlap)} appear in both the hot and the "
                            "cold record")
        covered = set(hot_names) - {"__cold"} | set(cold_names)
        if covered != {"id", "label", "scale", "magnitude", "channel",
                       "revision", "weight", "offset"}:
            problems.append(f"the split describes {sorted(covered)}, not the "
                            "eight declared fields")

    if problems:
        print(f"{RED}[FAIL] -g emits debug info that is missing or wrong{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] -g: {len(marks)} marked lines located, "
          f"{len(members)} members at host offsets, a split type describes its "
          f"cold block{RESET}")
    return True


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
    out = TEST_DIR / "layout_probe.ll"
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
               "U32": "i32", "U64": "i64", "Isize": "i64", "Usize": "i64"}
    emitted = {m.group(1): [f.strip() for f in m.group(2).split(",")]
               for m in re.finditer(r"^%(\w+) = type \{(.*)\}", ir, re.M)}

    # Enums lower to i32; everything else that is not a scalar is a pointer.
    # Read the declarations rather than guessing from the name -- `TokenType` is
    # an enum and does not look like one.
    sources = {p: p.read_text(encoding="utf-8") for p in sorted(src_dir.rglob("*.psm"))}
    enums = {m.group(1) for text in sources.values()
             for m in re.finditer(r"enum\s+(\w+)\s*\{", text)}

    problems = []
    checked = 0
    for path, text in sources.items():
        for m in re.finditer(r"struct\s+(\w+)\s*\{(.*?)\}", text, re.S):
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
    """
    print(f"\n{BLUE}--- Running aif_drop_emission ---{RESET}")
    fixture = TEST_DIR / "test_43_aif_scope_drop.psm"
    out = TEST_DIR / "t43_drops.ll"

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
        elif current and re.search(r"call void @free\(", line):
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
    release_exe = TEST_DIR / "ni_release.exe"
    debug_exe = TEST_DIR / "ni_debug.exe"

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

    problems = []
    checked = 0
    skipped = []
    for src in fixtures:
        text = src.read_text(encoding="utf-8", errors="replace")
        if any(p in text for p in PROBES):
            skipped.append(src.name)
            continue
        rel = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(release_exe)])
        dbg = run_command([str(PRISMIO_EXE), "build", str(src), "--debug", "-o", str(debug_exe)])

        # A fixture that does not build either way is some other test's problem.
        if rel.returncode != 0 and dbg.returncode != 0:
            continue
        if rel.returncode != dbg.returncode:
            problems.append(f"{src.name}: build exit {rel.returncode} at release, "
                            f"{dbg.returncode} at --debug -- a level changed which "
                            "programs compile (SPEC 7.2)")
            continue

        ran_rel = run_command([str(release_exe)])
        ran_dbg = run_command([str(debug_exe)])
        checked += 1

        if ran_rel.stdout != ran_dbg.stdout:
            problems.append(f"{src.name}: stdout differs between release and --debug")
        if ran_rel.returncode != ran_dbg.returncode:
            problems.append(f"{src.name}: exit {ran_rel.returncode} at release, "
                            f"{ran_dbg.returncode} at --debug")

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
    fixture = TEST_DIR / "test_49_aif_struct_fields.psm"
    out = TEST_DIR / "t49_fields.ll"

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
        if re.search(r"call void @free\(", line):
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


def run_aif_verify_test():
    """SPEC 7.3's verify mode, run over the fixtures that allocate structs.

    The hard invariant is `0 violation(s)`: nothing is released twice and nothing
    is released that the allocator never handed out. That is what a wrong escape
    fact looks like from the outside, and unlike a leak it is a crash waiting to
    happen rather than a slowdown.

    Leak counts are asserted exactly, because right now they are not noise --
    each one is a T2 value returned to a caller, and T2 has no free point until
    ownership transfer is modelled. When that lands these numbers go to zero and
    this test says so.
    """
    print(f"\n{BLUE}--- Running aif_verify ---{RESET}")
    expected_leaks = {
        "test_24_drop": 0,
        "test_25_conventions": 0,
        "test_42_aif_stack_promotion": 1,   # escapes() -> Point
        "test_43_aif_scope_drop": 1,        # escapes() -> Wide
        # Every other allocation in test_44 is served by an arena and released in
        # bulk, so verify never sees it. Two are not.
        #
        # The inner assignment in escapes_inner, whose escape is the *enclosing*
        # region's scope: too long-lived for the inner arena, and not its own
        # scope, so the scope drop declines it too. Correct but imprecise -- it is
        # the case a threaded arena handle would place in the outer arena.
        #
        # And string_escapes' str_concat, for the same reason on the Level 4 side:
        # it outlives the region so the arena declines it, and it reaches its
        # binding through an assignment rather than a `let`, so it never enters a
        # drop list. Droppability is a property of a binding's initialiser.
        "test_44_aif_region": 2,
        # AIF Level 4, and the first fixture where strings and lists are in the
        # accounting at all -- the runtime allocates them, so a verify build
        # compiles the runtime with PRISMIO_AIF_VERIFY to put both ends of every
        # pairing on the same side of the swap. Without that these would be
        # violations, not leaks.
        #
        # The four that remain, and the count is load-bearing rather than
        # incidental -- a wrong free in this fixture is a *legal* release as far
        # as the accounting goes, so it shows up here as one fewer leak and not
        # as a violation:
        #
        #   4 bytes  escapes() -> String, the T2 return, as above.
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
        "test_45_aif_affine_collections": 3,
        # AIF item 3. Every container in this fixture releases its elements, and
        # every binding that receives one from a known callee releases the
        # container -- so the ordinary cases are zero and what is left is one
        # shape:
        #
        #   6  the result of forwards(), which is `build`'s list and its four
        #      Items. Ownership transfer survives one hop, because it requires the
        #      returned site to belong to the callee, and `forwards` returns
        #      `build`'s. Two hops needs INFERENCE 6's contexts.
        #
        # A doubled release here is a violation rather than a missing leak, unlike
        # test_45: these are struct allocations the seam handed out, so releasing
        # one twice is something the accounting can see.
        "test_47_aif_containers": 6,
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
        # REQUIREMENTS 4. One heap allocation in the whole fixture, and it leaks
        # for a reason that has nothing to do with optionals:
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
        # Everything else in the fixture is T0. If this number goes to 0, contexts
        # landed; if it goes up, something stopped being stack-promoted.
        "test_51_optional_refs": 1,
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
        # drop declines it -- 7 leaked, which is the two lists, their four Items
        # and one Int.
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
        # These 7 go to zero when a T2 return gains a free point, and not before.
        "test_53_aif_views": 7,
    }

    exe = TEST_DIR / "aif_verify_probe.exe"
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

        leaked, violations = int(report.group(3)), int(report.group(4))
        if violations:
            problems.append(f"{name}: {violations} violation(s) -- a value was "
                            "released twice, or released without being allocated")
        if leaked != want_leaks:
            problems.append(f"{name}: {leaked} leaked, expected {want_leaks} "
                            "(if this dropped, T2 now has a free point and the "
                            "expectation should follow)")

    cleanup_files(exe)
    if problems:
        print(f"{RED}[FAIL] verify mode reported a fact that did not hold{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] verify: no double frees, and leaks are only the T2 returns{RESET}")
    return True


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
# T4b -- see AIF_T4A in runtime/aif_support.c for the argument. This dict is not
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
    cmd = [str(PRISMIO_EXE), "aif", str(source)]
    if budget is not None:
        cmd.append(f"--budget={budget}")
    result = run_command(cmd)
    if result.returncode != 0:
        return None, result
    out = {r: (v["tier"], v["origin"] == "budget-exhausted", v["origin"])
           for r, v in manifest_records(result.stdout).items()}
    return out, result


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
    sources += sorted((TEST_DIR.parent / "aif" / "corpus").glob("*.psm"))

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

    if run_check_command_test():
        passed += 1
    else:
        failed += 1

    if run_aif_test():
        passed += 1
    else:
        failed += 1

    if run_aif_concurrency_test():
        passed += 1
    else:
        failed += 1

    if run_aif_widening_test():
        passed += 1
    else:
        failed += 1

    if run_aif_stack_slot_test():
        passed += 1
    else:
        failed += 1

    if run_pin_tier_test():
        passed += 1
    else:
        failed += 1

    if run_region_diagnostic_test():
        passed += 1
    else:
        failed += 1

    if run_placement_pin_test():
        passed += 1
    else:
        failed += 1

    if run_bracket_summary_test():
        passed += 1
    else:
        failed += 1

    if run_layout_cost_model_test():
        passed += 1
    else:
        failed += 1

    if run_split_release_test():
        passed += 1
    else:
        failed += 1

    if run_forced_layout_test():
        passed += 1
    else:
        failed += 1

    if run_object_cache_test():
        passed += 1
    else:
        failed += 1

    if run_bootstrap_cache_key_test():
        passed += 1
    else:
        failed += 1

    if run_bootstrap_command_test():
        passed += 1
    else:
        failed += 1

    if run_manifest_parseable_test():
        passed += 1
    else:
        failed += 1

    if run_oracle_vocabulary_test():
        passed += 1
    else:
        failed += 1

    if run_aif_drop_emission_test():
        passed += 1
    else:
        failed += 1

    if run_aif_rc_test():
        passed += 1
    else:
        failed += 1

    if run_aif_view_test():
        passed += 1
    else:
        failed += 1

    if run_aif_layout_test():
        passed += 1
    else:
        failed += 1

    if run_workload_test():
        passed += 1
    else:
        failed += 1

    if run_aif_struct_field_test():
        passed += 1
    else:
        failed += 1

    if run_no_inference_test():
        passed += 1
    else:
        failed += 1

    if run_aif_verify_test():
        passed += 1
    else:
        failed += 1

    if run_aif_annotation_test():
        passed += 1
    else:
        failed += 1

    if run_aif_minimal_cause_test():
        passed += 1
    else:
        failed += 1

    if run_punned_slot_invariant_test():
        passed += 1
    else:
        failed += 1

    if run_debug_info_test():
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
