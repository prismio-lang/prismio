import json
import re
import subprocess
import sys
import os
import tempfile
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
    """SPEC 5.2 / 5.2.1 -- the arena diagnostics, which shipped 2026-08-14.

    test_58 asserts at run time that an arena serves what it claims. This asserts
    the three *reporting* halves, each of which was a live defect:

      * a region serving nothing warns, and one serving something does NOT. The
        second half is the discriminator -- a warning that fired on every region
        would satisfy any test that only looked for the text.
      * a T1 site with no arena reports `region:none`. It reported
        `region:scope`, one column away from the real placements `region:auto`
        and `region:<name>`, so g2_region.psm's manifest showed `region:` on
        every T1 line while the arena served nothing and a reader took it as
        confirmation.
      * `peak-bytes` counts only what the code generator will actually route to
        the arena. The cost model omitted the `in_container` clause the codegen
        gate has, so REQUIREMENTS 19's budget number -- which a `region name
        pin(N)` gate reads -- was inflated: test_49 reported 64 bytes for an
        arena holding zero.
    """
    print(f"\n{BLUE}--- Running region_diagnostics ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_58_region_serves.psm"
    exe = TEST_DIR / "test_58_region_serves.exe"
    build = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(exe)])
    text = (build.stdout or "") + (build.stderr or "")

    if "region callee_work serves no allocation" not in text:
        problems.append("no warning for the region whose allocation is in a callee")
    if "region work serves no allocation" in text:
        problems.append("warned about `work`, which serves 50 allocations -- the "
                        "diagnostic is firing on every region, not on inert ones")
    if "cannot reach it" not in text:
        problems.append("the warning lost its note, which is the half that names the repair")
    cleanup_files(exe)

    manifest = run_command([str(PRISMIO_EXE), "aif", str(fixture)])
    placements = {}
    for line in manifest.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3 and "#" in parts[0]:
            placements[parts[0]] = parts[2]
    if placements.get("serves__Void#1") != "region:work":
        problems.append(f"serves__Void#1: expected region:work, got "
                        f"{placements.get('serves__Void#1')}")
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
    why = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--why=make__Int#0"])
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

    if problems:
        print(f"{RED}[FAIL] the arena diagnostics do not describe the build{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] region diagnostics: inert regions warn, served ones do not, "
          f"and --why names every blocker{RESET}")
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
    got = {}
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 6 and parts[0] in want:
            got[parts[0]] = (parts[1], parts[2], parts[5])

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


TIER_ORDER = {"T0": 0, "T1": 1, "T2": 2, "T3": 3, "T4b": 4}


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
    out = {}
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 6 and "#" in parts[0] and parts[1] in TIER_ORDER:
            out[parts[0]] = (parts[1], "budget-exhausted" in line, parts[5])
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

    if run_bracket_summary_test():
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
