"""The `codegen` suite's harness tests (docs/TEST_ORCHESTRATION_PLAN.md, section 4)."""
import io
import os
import platform
import re
import shutil
import subprocess
import tempfile
from shutil import which
from pathlib import Path

from harness.common import *


@harness_test(suite="codegen",
              reads=["src/ast/nodes.psm", "src/ast/types.psm"])
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


@harness_test(suite="codegen",
              reads=["tests/array_zero_fill.psm"])
def run_array_zero_fill_test():
    """A large zeroed array is a memset; a small one stays a store.

    The two halves guard opposite mistakes. Without the memset, `let big:
    Array<Int, N>` costs compile time linear in N with a large constant -- LLVM
    scalarises the aggregate store before it recovers the memset -- and without
    the threshold every small array's IR would change for no benefit.
    """
    print(f"\n{BLUE}--- Running array_zero_fill ---{RESET}")
    fixture = TEST_DIR / "array_zero_fill.psm"
    out = scratch() / "array_zero_fill.ll"
    built = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(out)])
    if built.returncode != 0:
        print(f"{RED}[FAIL] array_zero_fill: build exited {built.returncode}{RESET}")
        print(built.stdout or built.stderr)
        return False
    ir = out.read_text(encoding="utf-8", errors="replace")
    cleanup_files(out)
    problems = []
    if not re.search(r"call void @llvm\.memset\.p0\.i64\(ptr align 4 %\S+, i8 0, i64 4000,", ir):
        problems.append("no 4000-byte memset for Array<Int, 1000>")
    if re.search(r"store \[1000 x i32\] zeroinitializer", ir):
        problems.append("the large array is still zeroed by an aggregate store")
    if not re.search(r"store \[4 x i32\] zeroinitializer", ir):
        problems.append("the small array no longer zeroes by one store, so its IR moved")
    if problems:
        print(f"{RED}[FAIL] array zero fill{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] a large zeroed array is a memset and a small one is still a store{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/array_return_huge.psm", "tests/test_262_array_return_large.psm"])
def run_array_return_pointer_test():
    """A large `-> Array<T, N>` returns through `ptr sret`; a small one by value.

    Two facts, because each guards a different mistake. The IR half pins the
    threshold: 1,023 Ints (4,092 bytes) is still a `[N x i32]` return and 2,000 is
    `void` with an `sret` pointer, so the small case's IR cannot move unnoticed.
    The time half is the reason the change exists -- LLVM legalises a first-class
    aggregate return in time that grows faster than N, and a 100,000-element one
    did not finish in minutes -- so a regression shows as a timeout, not as a slow
    test somebody has to notice.
    """
    print(f"\n{BLUE}--- Running array_return_pointer ---{RESET}")
    problems = []
    out = scratch() / "array_return_pointer.ll"

    built = run_command([str(PRISMIO_EXE), "build",
                         str(TEST_DIR / "test_262_array_return_large.psm"), "-o", str(out)])
    if built.returncode != 0:
        problems.append(f"build exited {built.returncode}")
    else:
        ir = out.read_text(encoding="utf-8", errors="replace")
        cleanup_files(out)
        if not re.search(r"define void @big__Int\(ptr noalias sret\(\[2000 x i32\]\)", ir):
            problems.append("`big` does not return through an sret pointer")
        if not re.search(r"define void @exactly__Int\(ptr noalias sret\(\[1024 x i32\]\)", ir):
            problems.append("`exactly` (4,096 bytes) is not at or over the threshold")
        if not re.search(r"define \[1023 x i32\] @below__Int\(", ir):
            problems.append("`below` (4,092 bytes) no longer returns by value")
        if not re.search(r"call void @big__Int\(ptr sret\(\[2000 x i32\]\)", ir):
            problems.append("a call to `big` does not pass the sret slot")

    huge = TEST_DIR / "array_return_huge.psm"
    try:
        timed = subprocess.run([str(PRISMIO_EXE), "build", str(huge), "-o", str(out)],
                               capture_output=True, text=True, encoding="utf-8",
                               errors="replace", timeout=90)
        if timed.returncode != 0:
            problems.append(f"the 100,000-element return did not build: {timed.stderr.strip()[:200]}")
    except subprocess.TimeoutExpired:
        problems.append("a 100,000-element array return took over 90 s to compile")
    cleanup_files(out)

    if problems:
        print(f"{RED}[FAIL] array return pointer{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] a large array returns through sret, a small one by value, and it compiles quickly{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_169_loop_range_proofs.psm"])
def run_loop_range_proofs_test():
    """Every loop in test_169 is proved exactly as its `// range: P/T` says.

    The fixture's own run checks answers, and a guard that never holds passes
    every one of them -- the checked copy is correct by construction. So the
    counts are asserted from the compiler's side too: each annotated loop header
    must report that many proved accesses out of that many, and no loop may report
    without an annotation, which is what catches a proof that silently stops
    firing or starts covering an access it must refuse.

    A range `for` whose direction only its values settle is two loops, each with
    its own proof, and emits its descending copy first; its annotation names both,
    in that order: `// range: 1/2 2/2`.
    """
    print(f"\n{BLUE}--- Running loop_range_proofs ---{RESET}")
    source = TEST_DIR / "test_169_loop_range_proofs.psm"
    want = {}
    for number, line in enumerate(source.read_text().splitlines(), start=1):
        found = re.search(r"// range: ((?:\d+/\d+ ?)+)\s*$", line)
        if found:
            want[number] = [tuple(int(n) for n in pair.split("/"))
                            for pair in found.group(1).split()]
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-range-proofs-") as tmp:
        env = os.environ.copy()
        env["PRISMIO_RANGE_TRACE"] = "1"
        built = subprocess.run([str(PRISMIO_EXE), "build", str(source), "-o",
                                str(Path(tmp) / "ranges.ll")],
                               cwd=PROJECT_ROOT, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if built.returncode != 0:
            print(f"{RED}[FAIL] loop range proofs: {built.stdout} {built.stderr}{RESET}")
            return False
        got = {}
        for found in re.finditer(r"range proof: line (\d+) proved (\d+) of (\d+)", built.stderr):
            got.setdefault(int(found.group(1)), []).append((int(found.group(2)),
                                                            int(found.group(3))))
    for number, counts in sorted(want.items()):
        if got.get(number) != counts:
            problems.append(f"line {number}: expected {counts}, got {got.get(number)}")
    for number in sorted(set(got) - set(want)):
        problems.append(f"line {number}: proved {got[number]} with no annotation")
    if problems:
        print(f"{RED}[FAIL] loop range proofs{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] {len(want)} loops proved as annotated{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_286_stride_tiling.psm"])
def run_stride_tiling_test():
    """test_286's tiled nests are exactly the loops it marks `// tile`.

    Every tiled copy hands back to the loop as written when it cannot match it, so
    a copy that is never emitted gives every right answer. The fixture's run checks
    the answers; this checks, from PRISMIO_TILE_TRACE, that each marked loop got
    the copy and that nothing else did.
    """
    print(f"\n{BLUE}--- Running stride_tiling ---{RESET}")
    source = TEST_DIR / "test_286_stride_tiling.psm"
    want = {number for number, line in enumerate(source.read_text().splitlines(), start=1)
            if re.search(r"\S.*// tile\s*$", line)}
    with tempfile.TemporaryDirectory(prefix="prismio-stride-tiling-") as tmp:
        env = os.environ.copy()
        env["PRISMIO_TILE_TRACE"] = "1"
        built = subprocess.run([str(PRISMIO_EXE), "build", str(source), "-o",
                                str(Path(tmp) / "tiling.ll")],
                               cwd=PROJECT_ROOT, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if built.returncode != 0:
            print(f"{RED}[FAIL] stride tiling: {built.stdout} {built.stderr}{RESET}")
            return False
        got = {int(found.group(1))
               for found in re.finditer(r"stride tiling: line (\d+)", built.stderr)}
    if not want or got != want:
        print(f"{RED}[FAIL] stride tiling: expected lines {sorted(want)}, got {sorted(got)}{RESET}")
        return False
    print(f"{GREEN}[PASS] {len(want)} nests tiled as annotated, and no other{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_179_proved_index_nsw.psm"])
def run_proved_index_nsw_test():
    """A proved index's `+`/`-` is `nsw` exactly where nothing in it can wrap.

    test_179 checks the answers, including one whose intermediate really wraps,
    but a wrongly placed `nsw` is poison that may still print the right number.
    So the marks are read from the IR: present on knapsack's `at - weight` and on
    the operand of a `%` and on both ops of `base + c - 1`; absent from
    `base + c - 2`, from `(i + k) - k` and from an index the proof cannot bound. A loop counter's own `add nsw ..., 1` is the older mark; an op
    with two register operands is the one this places.
    """
    print(f"\n{BLUE}--- Running proved_index_nsw ---{RESET}")
    source = TEST_DIR / "test_179_proved_index_nsw.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-proved-index-") as tmp:
        ir_path = Path(tmp) / "index.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] proved index IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()

    def body(name):
        match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}', ir, re.MULTILINE | re.DOTALL)
        if not match:
            problems.append(f"missing function {name}")
            return ""
        return match.group(1)

    marked_sub = r'sub nsw i32 %\S+, %\S+'
    marked_add = r'add nsw i32 %\S+, %\S+'
    for name in ("knapsack", "knapsackLet"):
        if not re.search(marked_sub, body(name)):
            problems.append(f"{name}: the proved `at - weight` is not nsw")
    if not re.search(marked_add, body("rotated")):
        problems.append("rotated: the `%` operand is not nsw")
    shifted = body("shiftedBack")
    if not re.search(marked_add, shifted) or not re.search(r'sub nsw i32 %\S+, 1\b', shifted):
        problems.append("shiftedBack: `base + c - 1` is not nsw throughout")
    for name in ("shiftedBackTwo", "offsetBack", "lookedUp"):
        text = body(name)
        if re.search(marked_sub, text) or re.search(marked_add, text):
            problems.append(f"{name}: an index op that can wrap is nsw")
    if "mul nsw" in ir:
        problems.append("a multiply is nsw")
    if problems:
        print(f"{RED}[FAIL] proved index nsw{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] proved index arithmetic is nsw, and only there{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["std/_fmt/float.psm", "tests/test_386_float_reductions.psm"])
def run_float_reductions_test():
    """`reassoc` is on the update of a loop reduction, and on nothing else.

    test_386 checks the answers, but a flag in the wrong place changes them only in the
    last bits, which a tolerance forgives. So the IR is read, by function: every
    row of the developer docs' Float loop reductions table that is a reduction carries the flag
    (on the `llvm.fmuladd` of a dot product too), and every row that is not carries
    none. `--strict-float` removes every mark. The trace names the same sites, and
    std._fmt.float, whose correct rounding depends on the order of its arithmetic,
    takes none.
    """
    print(f"\n{BLUE}--- Running float_reductions ---{RESET}")
    source = TEST_DIR / "test_386_float_reductions.psm"
    reductions = {"sumPlus", "sumSpelled", "sumCall", "dotProduct", "sumMinus", "sumMinusSpelled",
                  "sumGuarded", "sumTwice", "sumInner", "sumSingle", "readAfter", "scaledInto",
                  "logged"}
    sequential = {"kahan", "timeStep", "decay", "reversed", "selfTerm", "product", "countInt",
                  "condition", "fieldSum", "globalSum", "rebound"}
    problems = []
    env = os.environ.copy()
    env["PRISMIO_REDUCTION_TRACE"] = "1"

    def build(args, extra_env=None, target=source):
        with tempfile.TemporaryDirectory(prefix="prismio-float-reductions-") as tmp:
            ir_path = Path(tmp) / "reductions.ll"
            built = subprocess.run([str(PRISMIO_EXE), "build", str(target), *args, "-o", str(ir_path)],
                                   cwd=PROJECT_ROOT, env=extra_env or env, capture_output=True,
                                   text=True, encoding="utf-8", errors="replace")
            ir = ir_path.read_text() if built.returncode == 0 else ""
            return built, ir

    built, ir = build([])
    if built.returncode != 0:
        print(f"{RED}[FAIL] float reductions IR: {built.stdout} {built.stderr}{RESET}")
        return False

    def body(text, name):
        match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}', text, re.MULTILINE | re.DOTALL)
        if not match:
            problems.append(f"missing function {name}")
            return ""
        return match.group(1)

    for name in sorted(reductions):
        if "reassoc" not in body(ir, name):
            problems.append(f"{name}: a loop reduction's update is not reassoc")
    for name in sorted(sequential):
        if "reassoc" in body(ir, name):
            problems.append(f"{name}: an order-sensitive update is reassoc")
    if not re.search(r"call reassoc double @llvm\.fmuladd", body(ir, "dotProduct")):
        problems.append("dotProduct: the fused multiply-add is not reassoc")
    if not re.search(r"fsub reassoc contract double", body(ir, "sumMinus")):
        problems.append("sumMinus: the subtract is not reassoc")
    if not re.search(r"fadd reassoc contract float", body(ir, "sumSingle")):
        problems.append("sumSingle: the F32 add is not reassoc")
    if re.search(r"= (fmul|fdiv|frem) (\w+ )*reassoc", ir):
        problems.append("a multiply, divide or remainder is reassoc")

    traced = {int(n) for n in re.findall(r"float reduction: \S*test_386_float_reductions\.psm:(\d+)",
                                         built.stderr)}
    if not traced:
        problems.append("PRISMIO_REDUCTION_TRACE named no site")

    strict, strict_ir = build(["--strict-float"], extra_env=env)
    if strict.returncode != 0:
        problems.append(f"--strict-float build failed: {strict.stderr}")
    elif "reassoc" in strict_ir or "float reduction" in strict.stderr:
        problems.append("--strict-float left a reassoc mark")

    with tempfile.TemporaryDirectory(prefix="prismio-float-plib-") as plib_dir:
        plib = Path(plib_dir) / "float_text.plib"
        env = dict(os.environ, PRISMIO_REDUCTION_TRACE="1", PRISMIO_INTERNAL_HOSTED="1")
        text = subprocess.run([str(PRISMIO_EXE), "build", str(PROJECT_ROOT / "std" / "_fmt" / "float.psm"),
                               "--emit", "plib", "--module", "std._fmt.float", "-o", str(plib)],
                              capture_output=True, text=True, encoding="utf-8", errors="replace", env=env,
                              cwd=str(PROJECT_ROOT))
        llvm_dis = pinned_llvm_tool("llvm-dis")
        if text.returncode != 0:
            problems.append(f"std._fmt.float did not build: {text.stderr}")
        elif "float reduction" in text.stderr:
            problems.append("std._fmt.float takes a reduction mark")
        elif llvm_dis:
            code = Path(plib_dir) / "float_text.bc"
            code.write_bytes(plib_sections(plib)[0][1])
            shown = subprocess.run([str(llvm_dis), str(code), "-o", "-"], capture_output=True, text=True,
                                   encoding="utf-8", errors="replace")
            if "reassoc" in shown.stdout:
                problems.append("std._fmt.float takes a reduction mark")

    if problems:
        print(f"{RED}[FAIL] float reductions{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] reassoc on {len(reductions)} reduction functions, none on "
          f"{len(sequential)} sequential ones; --strict-float and std._fmt.float take none{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_314_param_ranges.psm"])
def run_param_ranges_test():
    """A private function's integer parameters carry the join of what every call passes
    (src/ir/param_ranges.psm), as LLVM `range` attributes, and only where every call is
    one the walk saw.

    test_314 checks the answers; a wrong range is poison that may still print them, so
    the IR is read: `scaled` gets [0, 150) and [150, 151) from two loops, `halved` the
    quotient 1023, `countDown` a non-negative bound from its own guarded `n - 1`, and the
    public function its one literal, since this module is the whole program; the unbounded
    argument, the exported function and the one also called from a closure get none.
    """
    print(f"\n{BLUE}--- Running param_ranges ---{RESET}")
    source = TEST_DIR / "test_314_param_ranges.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-param-ranges-") as tmp:
        ir_path = Path(tmp) / "ranges.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] param ranges IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()

    def signature(name):
        match = re.search(rf'^define [^\n]*@{name}__[^\n]*', ir, re.MULTILINE)
        if not match:
            problems.append(f"missing function {name}")
            return ""
        return match.group(0)

    wanted = {
        "scaled": ["range(i32 0, 150)", "range(i32 150, 151)"],
        "halved": ["range(i32 1023, 1024)"],
        "exposed": ["range(i32 5, 6)"],
    }
    for name, ranges in wanted.items():
        text = signature(name)
        for want in ranges:
            if want not in text:
                problems.append(f"{name}: no `{want}` in `{text}`")
    # Narrowed a little further each round, so its top edge is a matter of how many there are.
    if "range(i32 0, " not in signature("countDown"):
        problems.append(f"countDown: no non-negative range in `{signature('countDown')}`")
    for name in ("unbounded", "fromClosure"):
        if "range(" in signature(name):
            problems.append(f"{name}: a range on a parameter not every call bounds")
    if "range(" in signature("reachable"):
        problems.append("reachable: an exported function has a range")
    if problems:
        print(f"{RED}[FAIL] param ranges{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] parameter ranges are the join of every call, and only then{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_315_index_strides.psm"])
def run_index_strides_test():
    """An immutable `let` keeps a congruence and a literal array its elements
    (src/ir/strides.psm), which proves an index into a flattened record array.

    test_315 checks the answers and the trap; the IR is read for which checks are left:
    none in `run`, whose `a` and `b` fields are below 4; `runMutable`'s through a
    `let mut` base, which keeps no congruence; and `wideField`'s, whose field is 9.
    """
    print(f"\n{BLUE}--- Running index_strides ---{RESET}")
    source = TEST_DIR / "test_315_index_strides.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-index-strides-") as tmp:
        ir_path = Path(tmp) / "strides.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] index strides IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()

    def checks(name):
        match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}', ir, re.MULTILINE | re.DOTALL)
        if not match:
            problems.append(f"missing function {name}")
            return 0
        return match.group(1).count("array_index_fail")

    if checks("run") != 0:
        problems.append("run: a field below 4 still has a bounds check")
    if checks("runMutable") == 0:
        problems.append("runMutable: a `let mut` base proved an index it cannot")
    if checks("wideField") == 0:
        problems.append("wideField: a field of 9 lost its check")
    if problems:
        print(f"{RED}[FAIL] index strides{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] record fields proved by congruence, and only there{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_317_overwrite_release.psm"])
def run_overwrite_release_test():
    """`v[k] = x` releases what it displaces at once only where no view of an element
    can be live (src/ir/overwrites.psm).

    test_317 checks the answers and `aif_verify` the ledger; a release that reached a
    live view could still print the right answer, so the IR is read for each
    function's setter: `list_set_now` in the three that read or lend a view before the
    store, or take it after; `list_set` in the five that read it after the store,
    iterate the Vec, keep it outside the loop, build the new element from it, or
    replace into a Vec they were handed.
    """
    print(f"\n{BLUE}--- Running overwrite_release ---{RESET}")
    source = TEST_DIR / "test_317_overwrite_release.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-overwrite-") as tmp:
        ir_path = Path(tmp) / "overwrite.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] overwrite release IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()

    def body(name):
        match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}', ir, re.MULTILINE | re.DOTALL)
        if not match:
            problems.append(f"missing function {name}")
            return ""
        return match.group(1)

    for name in ("readThenReplace", "lendThenReplace", "replaceThenRead"):
        text = body(name)
        if "@list_set_now(" not in text or "@list_set(" in text:
            problems.append(f"{name}: the store does not release at once")
    for name in ("readAfterReplace", "replaceWhileIterating", "keptOutside", "rebuiltFromOld",
                 "replaceInBorrowed"):
        if "@list_set_now(" in body(name):
            problems.append(f"{name}: a store releases while a view may be live")
    if problems:
        print(f"{RED}[FAIL] overwrite release{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] overwrites release at once exactly where no view is live{RESET}")
    return True


def nsw_sources(body):
    """The variable each `add nsw`/`sub nsw` in a function's IR loaded its left operand
    from, or `elem` for an array element and `other` for anything else.

    Unoptimised IR names a local's slot after it (`%k.3`), so `k = k + 1` is
    `load i32, ptr %k.3` then `add nsw i32 %N, 1`. An element is loaded through a
    numbered `getelementptr` instead.
    """
    slots = dict(re.findall(r'^\s*(%\S+) = load i32, ptr %([A-Za-z_]\w*)\.\d+', body, re.MULTILINE))
    elements = set(re.findall(r'^\s*(%\S+) = load i32, ptr %\d+', body, re.MULTILINE))
    sources = []
    for left in re.findall(r'= (?:add|sub) nsw i32 ([^,\s]+),', body):
        sources.append(slots.get(left) or ("elem" if left in elements else "other"))
    return sources


@harness_test(suite="codegen",
              reads=["tests/test_271_array_contents.psm"])
def run_array_contents_test():
    """A local array's elements and a counted loop's counter make `nsw` exactly where
    nothing can wrap.

    test_271 checks the answers, most of them from elements or counters that really
    go past `Int`; a wrongly placed `nsw` is poison that may still print the right
    number, so the IR is read as well. The edit-distance rows, the counter's `i - 2`,
    the array that reads only itself and the literal-initialised one are marked; in
    the eight where the bound is gone or never held, the one `nsw` left is the step
    of their counted loop, and in the two whose loop does not count, none.
    """
    print(f"\n{BLUE}--- Running array_contents ---{RESET}")
    source = TEST_DIR / "test_271_array_contents.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-array-contents-") as tmp:
        ir_path = Path(tmp) / "contents.ll"
        built = subprocess.run([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)],
                               cwd=PROJECT_ROOT, capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
        if built.returncode != 0:
            print(f"{RED}[FAIL] array contents IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()

    def sources(name):
        match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}', ir, re.MULTILINE | re.DOTALL)
        if not match:
            problems.append(f"missing function {name}")
            return []
        return nsw_sources(match.group(1))

    for name, wanted in (("editRows", 3), ("independent", 1), ("literalInit", 1)):
        marked = sources(name).count("elem")
        if marked < wanted:
            problems.append(f"{name}: {marked} element adds are nsw, expected at least {wanted}")
    if "i" not in sources("counted"):
        problems.append("counted: the counter's `i - 2` is not nsw")
    # Each function's steps that its loop's condition bounds. movingBound's `n` and
    # `i` and stepThenUse's `i` are found by the loop invariants (nowrapInvariants):
    # `n < 20` and `i < n`, `i < 10`, hold where each is stepped. What those two are
    # about is the large sum after the step, which must stay plain, and is read below.
    steps = {"escaped": ("k",), "shadowedArrays": ("k",), "continued": ("k",),
             "doubling": ("k",), "readsFailed": ("k",), "movingBound": ("n", "i"),
             "stepThenUse": ("i",), "conjunctBefore": ("i",)}
    for name, allowed in steps.items():
        stray = [source for source in sources(name) if source not in allowed]
        if stray:
            problems.append(f"{name}: an op that can wrap is nsw ({', '.join(stray)})")
    for name, literal in (("movingBound", 2147483640), ("stepThenUse", 2147483638)):
        match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}', ir, re.MULTILINE | re.DOTALL)
        if match and re.search(rf'add nsw i32 %\S+, {literal}\b', match.group(1)):
            problems.append(f"{name}: the sum with {literal}, which can wrap, is nsw")
    if problems:
        print(f"{RED}[FAIL] array contents{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] array elements and counted loops make nsw exactly where nothing can wrap{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_311_proved_indices.psm"])
def run_proved_indices_test():
    """An array index the interval walk proves in range carries no check, and one it
    cannot prove keeps its check.

    test_311 runs every shape, and its trap cases stop where they should; but a check
    left in place still gives the right answer, so the IR is read as well. Binary
    search over `U32`, a pointer chase through two arrays whose contents are indices,
    a small interpreter whose `pc` cycles 0..3, an `!=` at the interval's edge and a
    mask and remainder that fit lose every check. The twelve that look provable and
    are not -- an off-by-one `<=`, a `U32` below zero, a `break` or `continue`
    (labelled too) the end of the body does not see, `!=` away from the edge, a large
    `U32` cast, a mask or remainder one too wide, a step past the end, a store nothing
    bounds and a `let` bound twice -- each keep at least one.
    """
    print(f"\n{BLUE}--- Running proved_indices ---{RESET}")
    source = TEST_DIR / "test_311_proved_indices.psm"
    with tempfile.TemporaryDirectory(prefix="prismio-proved-indices-") as tmp:
        ir_path = Path(tmp) / "proved.ll"
        built = subprocess.run([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)],
                               cwd=PROJECT_ROOT, capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
        if built.returncode != 0:
            print(f"{RED}[FAIL] proved indices IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()

    def checks(name):
        match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}', ir, re.MULTILINE | re.DOTALL)
        if not match:
            return None
        return match.group(1).count("call void @array_index_fail")

    problems = []
    for name in ("binarySearch", "chase", "bytecode", "atEdge", "masked"):
        count = checks(name)
        if count is None:
            problems.append(f"missing function {name}")
        elif count:
            problems.append(f"{name}: {count} index checks left, expected none")
    for name in ("offByOne", "below", "afterBreak", "continuePath", "continueOuter", "notAtEdge",
                 "bigCast", "wideMask", "wideRemainder", "stepping", "unboundedContents",
                 "shadowedAlias"):
        count = checks(name)
        if count is None:
            problems.append(f"missing function {name}")
        elif count == 0:
            problems.append(f"{name}: its unprovable index lost its check")
    if problems:
        print(f"{RED}[FAIL] proved indices{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] proved indices lose their check, and only they do{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_270_array_nowrap.psm"])
def run_array_nowrap_test():
    """An unchecked array access's facts make `nsw` exactly where nothing can wrap.

    test_270 checks the answers, most of them programs whose arithmetic really
    wraps, but a wrongly placed `nsw` is poison that may still print the right
    number. So the IR is read as well: quicksort's scans and swap step and
    knapsack's `c - w` and `c - 1` are marked; in the seven functions where the fact
    is gone, never held or only maybe held, the one `nsw` left is the step of their
    counted loop (`k` or `n`). The trace shows knapsack's capacity loop versioned on
    its array's facts, and its item loop, which holds another loop, not versioned.
    """
    print(f"\n{BLUE}--- Running array_nowrap ---{RESET}")
    source = TEST_DIR / "test_270_array_nowrap.psm"
    lines = source.read_text().splitlines()
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-array-nowrap-") as tmp:
        ir_path = Path(tmp) / "nowrap.ll"
        env = os.environ.copy()
        env["PRISMIO_RANGE_TRACE"] = "1"
        built = subprocess.run([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)],
                               cwd=PROJECT_ROOT, env=env, capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
        if built.returncode != 0:
            print(f"{RED}[FAIL] array nowrap IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()

    def body(name):
        match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}', ir, re.MULTILINE | re.DOTALL)
        if not match:
            problems.append(f"missing function {name}")
            return ""
        return match.group(1)

    def line_of(text):
        return next(n for n, line in enumerate(lines, start=1) if text in line)

    quick = body("quick")
    if len(re.findall(r'add nsw i32 %\S+, 1\b', quick)) < 2 or len(re.findall(r'sub nsw i32 %\S+, 1\b', quick)) < 2:
        problems.append("quick: the scans' and the swap's steps are not all nsw")
    knapsack = body("knapsack")
    if not re.search(r'sub nsw i32 %\S+, %\S+', knapsack):
        problems.append("knapsack: the subscript `c - w` is not nsw")
    if not re.search(r'sub nsw i32 %\S+, 1\b', knapsack):
        problems.append("knapsack: `c - 1` is not nsw")
    # shortCircuit's `hits` is bounded by its loop's `hits < 1` where both of its sums
    # run (nowrapInvariants); what the function is about is the `i + 1` on Int.MAX after
    # the loop, which must stay plain.
    for name in ("reassigned", "shortCircuit", "coalesced", "shadowed", "headKill", "negativeLeft",
                 "viewBelow"):
        allowed = ("k", "n", "hits") if name == "shortCircuit" else ("k", "n")
        stray = [source for source in nsw_sources(body(name)) if source not in allowed]
        if stray:
            problems.append(f"{name}: an op that can wrap is nsw ({', '.join(stray)})")
    short = body("shortCircuit")
    if len(re.findall(r'add nsw i32 %\S+, 1\b', short)) > 1:
        problems.append("shortCircuit: the `i + 1` on Int.MAX is nsw")
    traced = {int(n): (int(p), int(t)) for n, p, t in
              re.findall(r"range proof: line (\d+) proved (\d+) of (\d+)", built.stderr)}
    capacity = line_of("while (c >= w)")
    if traced.get(capacity) != (3, 3):
        problems.append(f"knapsack's capacity loop (line {capacity}): expected 3 of 3 proved, "
                        f"got {traced.get(capacity)}")
    items = line_of("let w = weight[i]") - 1
    if items in traced:
        problems.append(f"knapsack's item loop (line {items}) was versioned around another loop")
    if problems:
        print(f"{RED}[FAIL] array nowrap{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] array accesses make nsw exactly where nothing can wrap{RESET}")
    return True


@harness_test(suite="codegen")
def run_range_direction_test():
    """A range's direction comes from its values, settled at compile time where
    the source settles it.

    test_180 checks what the loops compute. This checks what the compiler does
    around them: the body is emitted once where the direction is known (literal
    ends, `0..<` a length, a `repeat` count) and twice where only the values can
    tell; `0..n - 1` warns, since it counts down rather than not at all when `n`
    is 0; and a computed step of zero stops the program, naming the line.
    """
    print(f"\n{BLUE}--- Running range_direction ---{RESET}")
    source = TEST_DIR / "range_direction_probe.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-range-direction-") as tmp:
        ir_path = Path(tmp) / "direction.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] range direction IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()
        warned = built.stdout + built.stderr
        if "warning[P4003]: this range counts down" not in warned:
            problems.append("`0..n - 1` did not warn")
        if warned.count("warning[P4003]") != 1:
            problems.append(f"expected one range warning: {warned.strip()[:300]!r}")

        for name, copies in (("literalUp", 1), ("literalDown", 1), ("lengthUp", 1),
                             ("counted", 1), ("eitherWay", 2)):
            match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}', ir, re.MULTILINE | re.DOTALL)
            if not match:
                problems.append(f"missing function {name}")
                continue
            found = match.group(1).count("call void @mark__Int(")
            if found != copies:
                problems.append(f"{name}: the body is emitted {found} time(s), expected {copies}")

        exe = Path(tmp) / ("direction.exe" if platform.system() == "Windows" else "direction")
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(exe)])
        if built.returncode != 0:
            problems.append(f"build failed: {built.stdout} {built.stderr}")
        else:
            ran = subprocess.run([str(exe)], cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
            if ran.stdout.strip() != "012332100122210012":
                problems.append(f"loops printed {ran.stdout.strip()!r}")
            if ran.returncode == 0:
                problems.append("a zero step ran to completion")
            if "a `step` must be positive, found 0" not in ran.stderr:
                problems.append(f"no step diagnostic: {ran.stderr.strip()[:200]!r}")
            if "range_direction_probe.psm:23" not in ran.stderr:
                problems.append(f"the diagnostic does not name line 23: {ran.stderr.strip()[:200]!r}")
    if problems:
        print(f"{RED}[FAIL] range direction{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] range direction folded where known, warned, and a zero step stopped{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/asm_ops_probe.psm"])
def run_asm_ops_test():
    """`asmOps` and `asmOpsOut` (std.sys.asm): operands, results and clobbers, read as IR.

    Built for AArch64 whatever the host, so the check is on what the compiler decides --
    the constraint string, the operand count and how each operand reaches its register --
    and not on what an assembler makes of the text.
    """
    print(f"\n{BLUE}--- Running asm_ops ---{RESET}")
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-asm-ops-") as tmp:
        ll = Path(tmp) / "asm_ops.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "asm_ops_probe.psm"), "--freestanding",
                             "--target", "aarch64-unknown-linux-gnu", "-o", str(ll)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] asm ops probe did not build: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ll.read_text(encoding="utf-8", errors="replace")
        wants = (
            ('asm sideeffect "add $0, $1, $2", "=r,r,r,~{memory}"', "a result and two inputs"),
            ('asm sideeffect "mov x8, $0\\0Amov x0, $1\\0Asvc #0", "r,r,~{memory},~{x0},~{x8}"', "two inputs and two clobbers, spaces trimmed"),
            ('"=r,r,r,~{memory},~{cc}"', "a clobber with no operand of its own"),
            ('asm sideeffect "mov $0, #7", "=r,~{memory}"', "a result and no inputs"),
            ('crc32cw ${0:w}, ${1:w}, ${2:w}"', "a hardware CRC step, with operand modifiers"),
            ("ptrtoint ptr", "a pointer travels as its address"),
            ("zext i8", "an unsigned byte widens to the register"),
            ("sext i16", "a signed halfword sign-extends"),
        )
        for text, why in wants:
            if text not in ir:
                problems.append(f"missing {text!r}: {why}")
    if problems:
        print(f"{RED}[FAIL] asm ops{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] asm ops: constraints, clobbers and operand widening{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/data_placement_probe.psm"])
def run_data_placement_test():
    """`export`, `section` and `align` before a global `let`, read as IR.

    The compiler decides the linkage, the section and the alignment of each global; what a
    linker makes of them is the linker's. Built for AArch64 Linux whatever the host.
    """
    print(f"\n{BLUE}--- Running data_placement ---{RESET}")
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-data-placement-") as tmp:
        ll = Path(tmp) / "data_placement.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "data_placement_probe.psm"), "--freestanding",
                             "--target", "aarch64-unknown-linux-gnu", "-o", str(ll)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] data placement probe did not build: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ll.read_text(encoding="utf-8", errors="replace")
        wants = (
            ('@license = dso_local constant [12 x i8] c"license=GPL\\00", section ".modinfo", align 1', "exported bytes in .modinfo"),
            ('@counter = global i32 5, section ".data.counters", align 64', "a mutable scalar, placed and aligned"),
            ('@table = internal constant [3 x i16] [i16 1, i16 2, i16 3], section ".rodata.table", align 16', "a private table, placed"),
            ('@pagetable = dso_local global [512 x i64] zeroinitializer, section ".bss.pagetable", align 4096', "a sized, zeroed, page-aligned table"),
            ('@ops = dso_local constant %Operations { i64 ptrtoint (ptr @bump__Void to i64), i32 3 }, section ".data.rel.ro", align 8', "a static operations table holding a function's address"),
            ("@hidden = internal global i32 2", "a global is private unless exported"),
            ("@visible = global i32 1", "export alone is only linkage"),
        )
        for text, why in wants:
            if text not in ir:
                problems.append(f"missing {text!r}: {why}")
    if problems:
        print(f"{RED}[FAIL] data placement{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] data placement: export, section and align on globals{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/module_asm_probe.psm"])
def run_module_asm_test():
    """A top-level `asm "text"`: assembly for the module, outside any function, read as IR."""
    print(f"\n{BLUE}--- Running module_asm ---{RESET}")
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-module-asm-") as tmp:
        ll = Path(tmp) / "module_asm.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "module_asm_probe.psm"), "--freestanding",
                             "--target", "aarch64-unknown-linux-gnu", "-o", str(ll)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] module asm probe did not build: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ll.read_text(encoding="utf-8", errors="replace")
        # LLVM prints the module's assembly one quoted line per instruction line, under `module asm`.
        block = re.search(r'^module asm\n((?:[ \t]+".*"\n)+)', ir, re.M)
        text = block.group(1).replace('"', "") if block else ""
        for needle, why in (
            ("globl legacy_entry", "the first block"),
            ("set legacy_entry, entry_point", "its second line"),
            ("pushsection .modinfo", "the second block"),
            ("author=prismio", "its string"),
        ):
            if needle not in text:
                problems.append(f"module asm lacks {needle!r}: {why}")
        if "moduleasm" in ir:
            problems.append("the stand-in global reached the IR")
    if problems:
        print(f"{RED}[FAIL] module asm{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] module asm: top-level assembly, in order, with no global{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/ptr_access_ir_probe.psm"])
def run_typed_pointer_ir_test():
    """What each access through a typed `Ptr<T>` is emitted as (PTR_PLAN (removed; git history)).

    Volatility and an ordering are invisible to a program's output, so the only
    check that means anything is the instruction: a `Ptr<volatile T>` access is
    `load volatile` or `store volatile` whatever it reads (a scalar, a field, an
    operand), a plain one is neither, an atomic carries the ordering written at the
    call, and a compare-exchange takes its failure ordering from the success one
    without the release half. The parameter line is checked as well, because the
    type is what tells LLVM a pointer is non-null, aligned and -- unless `mut` -- not
    written through, and never `dereferenceable`: a pointer may be one past its
    allocation. No access carries a TBAA tag (`cast` makes two types the same bytes),
    `advance` steps with a plain GEP and divides without `exact`, and a packed
    struct's field is read and written at one byte.
    """
    print(f"\n{BLUE}--- Running typed_pointer_ir ---{RESET}")
    problems = []
    source = str(TEST_DIR / "ptr_access_ir_probe.psm")
    with tempfile.TemporaryDirectory(prefix="prismio-ptr-ir-") as tmp:
        ll = Path(tmp) / "probe.ll"
        built = run_command([str(PRISMIO_EXE), "build", source, "-o", str(ll)])
        if built.returncode != 0 or not ll.exists():
            print(f"{RED}[FAIL] typed pointer probe did not emit IR: "
                  f"{built.stdout} {built.stderr}{RESET}")
            return False
        text = ll.read_text(encoding="utf-8")

    def function(name):
        found = re.search(r"^(define [^\n]*@" + name + r"__[^\n]*)\{\n(.*?)^\}", text,
                          re.S | re.M)
        return (found.group(1), found.group(2)) if found else (None, None)

    # name -> (instructions the body must have, text it must not have, parameter facts it
    # must have, parameter facts it must not)
    cases = {
        "plainLoad": ([r"load i32, ptr %\S+, align 4"], ["volatile", "atomic", "!tbaa"],
                      ["readonly", "nonnull", "align 4"], ["dereferenceable"]),
        "plainField": ([r"load i32, ptr %\S+, align 4"], ["volatile", "atomic", "!tbaa"], ["readonly"],
                       ["dereferenceable"]),
        "volatileLoad": ([r"load volatile i32, ptr %\S+, align 4"], [],
                         ["readonly", "nonnull"], ["dereferenceable"]),
        "volatileStore": ([r"store volatile i32 1, ptr %\S+, align 4"], [], ["nonnull"],
                          ["readonly", "dereferenceable"]),
        "volatileOperand": ([r"load volatile i32, ptr %\S+, align 4"], [], [], []),
        "volatileFieldRead": ([r"load volatile i32, ptr %\S+, align 4"], [], [], ["dereferenceable"]),
        "volatileFieldWrite": ([r"store volatile i32 5, ptr %\S+, align 4"], [], [], ["readonly"]),
        "oneOffRead": ([r"load volatile i32, ptr %\S+, align 4"], [], [], ["dereferenceable"]),
        "oneOffWrite": ([r"store volatile i32 2, ptr %\S+, align 4"], [], [], []),
        "atomicLoadAcquire": ([r"load atomic i32, ptr %\S+ acquire, align 4"], ["volatile"], [], []),
        "atomicLoadRelaxed": ([r"load atomic i32, ptr %\S+ monotonic, align 4"], [], [], []),
        "atomicStoreRelease": ([r"store atomic i32 3, ptr %\S+ release, align 4"], [], [], []),
        "atomicAddAcqRel": ([r"atomicrmw add ptr %\S+, i32 1 acq_rel, align 4"], [], [], []),
        "atomicSwapSeqCst": ([r"atomicrmw xchg ptr %\S+, i8 1 seq_cst, align 1"], [], [], []),
        "atomicCasRelease": ([r"cmpxchg ptr %\S+, i32 1, i32 2 release monotonic, align 4"], [], [], []),
        "atomicCasAcqRel": ([r"cmpxchg ptr %\S+, i32 1, i32 2 acq_rel acquire, align 4"], [], [], []),
        "advanceStep": ([r"= getelementptr i32, ptr %\S+, i64", r"sdiv i64 %\S+, 4"],
                        ["getelementptr inbounds", "sdiv exact"], [], ["dereferenceable"]),
        "packedField": ([r"load i32, ptr %\S+, align 1"], ["align 4", "!tbaa"], ["align 1"], []),
        "packedFieldWrite": ([r"store i32 5, ptr %\S+, align 1"], ["align 4"], [], []),
    }
    for name, (musts, must_nots, param_musts, param_must_nots) in cases.items():
        header, body = function(name)
        if header is None:
            problems.append(f"{name}: not in the emitted IR")
            continue
        for want in musts:
            if not re.search(want, body):
                problems.append(f"{name}: no `{want}` in its body")
        for bad in must_nots:
            if re.search(bad, body):
                problems.append(f"{name}: has `{bad}` and must not")
        for want in param_musts:
            if not re.search(want, header):
                problems.append(f"{name}: parameter lacks `{want}`: {header.strip()}")
        for bad in param_must_nots:
            if re.search(bad, header):
                problems.append(f"{name}: parameter has `{bad}` and must not: {header.strip()}")
    if problems:
        print(f"{RED}[FAIL] typed pointer IR{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] typed pointer accesses are volatile, atomic, aligned and attributed as their type says{RESET}")
    return True


@harness_test(suite="codegen")
def run_scalar_optional_test():
    """A scalar `T?` is a value: no allocation, and `expect` on `none` panics.

    test_238 checks the answers; this checks the two things an answer cannot. A
    boxed payload enum would pass test_238 too, so `half`'s IR must hold no
    allocation. And the probe's `expect(none)` must exit 101 naming its line.
    """
    print(f"\n{BLUE}--- Running scalar_optional ---{RESET}")
    problems = []
    # `call (attrs) ptr`: the seam's `rt_base_alloc` carries malloc's attributes at the call.
    alloc = re.compile(r"call (?:\w+ )*ptr @(malloc|rt_alloc|rt_base_alloc|rc_alloc|arena_alloc|cyc_alloc)\b")
    exe_suffix = ".exe" if platform.system() == "Windows" else ""
    with tempfile.TemporaryDirectory(prefix="prismio-scalar-optional-") as tmp:
        ir_path = Path(tmp) / "optionals.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "test_238_scalar_optionals.psm"),
                             "-o", str(ir_path)])
        if built.returncode != 0:
            problems.append(f"test_238 IR did not build: {built.stdout} {built.stderr}")
        else:
            ir = ir_path.read_text()
            m = re.search(r"^define [^\n]*@half(__[\w$]*)?\(.*?^}", ir, re.M | re.S)
            if not m:
                problems.append("missing function half")
            elif alloc.search(m.group(0)):
                problems.append("half allocates: a scalar T? is not a value")

        probe = Path(tmp) / ("probe" + exe_suffix)
        built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "scalar_optional_expect_probe.psm"),
                             "-o", str(probe)])
        if built.returncode != 0:
            problems.append(f"expect probe did not build: {built.stdout} {built.stderr}")
        else:
            ran = subprocess.run([str(probe)], cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
            if ran.returncode != 101:
                problems.append(f"expect(none): exit status {ran.returncode}, expected 101")
            if ran.stdout.strip() != "7":
                problems.append(f"expect(present): stdout {ran.stdout.strip()!r}, expected '7'")
            if "panic: expect() called on a `none` value" not in ran.stderr \
                    or "scalar_optional_expect_probe.psm:13:" not in ran.stderr:
                problems.append(f"expect(none) did not name itself and line 13: {ran.stderr.strip()[:200]!r}")
    if problems:
        print(f"{RED}[FAIL] scalar optionals{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] scalar T? allocates nothing and expect(none) panics at its line{RESET}")
    return True


@harness_test(suite="codegen")
def run_produce_deallocator_test():
    """`produce(f)` calls `f` when `f` is not the seam's `rt_free`.

    tests/produce_deallocators/ is a C library that counts the blocks its own
    deallocator gets back, and a program that pushes, returns and reads its strings
    and some `strdup`'d ones. A String with a foreign deallocator is copied in at
    the call and `f` releases the original there (src/ir/expr.psm, fatAdopted), so
    the IR must show the copy and the named call, the program must see all three
    blocks returned, and the `--verify` ledger must be clean. Before, every one of
    those blocks reached `rt_free` -- 5 ledger violations, and none returned to the
    library -- which with a slab behind the seam is a libc `free` of a foreign block.
    """
    print(f"\n{BLUE}--- Running produce_deallocator ---{RESET}")
    fixture = TEST_DIR / "produce_deallocators"
    source, native = fixture / "main.psm", fixture / "strings.c"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-produce-") as tmp:
        ir_path = Path(tmp) / "produce.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] produce deallocator IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()
        made = re.search(r"^define [^\n]*@made(__[\w$]*)?\(.*?^}", ir, re.M | re.S)
        made = made.group(0) if made else ""
        if not re.search(r"@lib_string_make\(.*?@str_clone_n\(.*?call void @lib_string_free\(", made, re.S):
            problems.append("`made` does not copy the library's string in and call "
                            "lib_string_free on the original")
        if not re.search(r"@strdup\(.*?@str_clone_n\(.*?call void @free\(", ir, re.S):
            problems.append("a `produce(free)` strdup is not copied in and released by libc `free`")

        for verify in (False, True):
            exe = Path(tmp) / ("produce-verify" if verify else "produce")
            command = [str(PRISMIO_EXE), "build", str(source), "--native", str(native), "-o", str(exe)]
            if verify:
                command.insert(3, "--verify")
            built = run_command(command)
            if built.returncode != 0:
                problems.append(f"the fixture did not build{' under --verify' if verify else ''}: "
                                f"{built.stdout} {built.stderr}")
                continue
            ran = run_command([str(exe)])
            if ran.returncode != 0 or "PASS" not in (ran.stdout or ""):
                problems.append(f"the fixture failed{' under --verify' if verify else ''}: exit "
                                f"{ran.returncode}, {(ran.stdout or '').strip()!r}")
            if not verify:
                continue
            ledger = re.search(r"aif-verify:\s+(\d+) allocated,\s+(\d+) released,"
                               r"\s+(\d+) leaked,\s+(\d+) violation", ran.stdout + ran.stderr)
            if ledger is None:
                problems.append("no aif-verify ledger line, so the --verify half checked nothing")
            elif int(ledger.group(4)) != 0 or ledger.group(1) != ledger.group(2):
                problems.append(f"the ledger is not clean: {ledger.group(0)} -- a foreign "
                                f"block reached the seam's release")

    if problems:
        for p in problems:
            print(f"{RED}[FAIL] {p}{RESET}")
        return False
    print(f"{GREEN}[PASS] produce(f): a foreign String is copied in and f releases the "
          f"original at the call; ledger clean{RESET}")
    return True


@harness_test(suite="codegen")
def run_channel_copies_test():
    """Plain-data channels copy through the ring; owned messages stay boxed.

    Reads test_232_channel_copies' IR for which entry point each channel used
    and where each received value lives, then runs it under `--verify`. The
    functional test alone would pass with every channel on the pointer path --
    the copy is an optimisation, so only the IR can say it happened.
    """
    print(f"\n{BLUE}--- Running channel_copies ---{RESET}")
    source = TEST_DIR / "test_232_channel_copies.psm"
    problems = []
    # Attributes sit between `call` and the type when the allocator is the seam's `rt_base_alloc`
    # (`call noalias ptr @rt_base_alloc`: it carries malloc's attributes, docs/ALLOCATOR_PLAN.md).
    alloc = re.compile(r"call (?:\w+ )*ptr @(malloc|rt_alloc|rt_base_alloc|rc_alloc|arena_alloc|cyc_alloc)\b")
    with tempfile.TemporaryDirectory(prefix="prismio-channel-copies-") as tmp:
        ir_path = Path(tmp) / "copies.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] channel copies IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()

        def body(name):
            # Mangled by signature: `@double__Ptr_Ptr(`.
            m = re.search(r"^define [^\n]*@" + name + r"(__[\w$]*)?\(.*?^}", ir, re.M | re.S)
            if not m:
                problems.append(f"no function {name} in the IR")
                return ""
            return m.group(0)

        # The relay stage is the whole point: no box made, none freed.
        for name in ("double", "produceTicks"):
            text = body(name)
            if "@chan_send_copy(" not in text:
                problems.append(f"{name} does not send through the ring")
            if alloc.search(text) or "@rt_free(" in text:
                problems.append(f"{name} still allocates or frees a message")
        for name in ("double", "tickPipeline", "samplePipeline"):
            if "@chan_recv_copy(" not in body(name):
                problems.append(f"{name} does not receive from the ring")
        # T0: received straight into a frame slot, so nothing is allocated.
        if alloc.search(body("tickPipeline")):
            problems.append("a receive whose value stays in the frame allocated")
        # A value that outlives the iteration is copied out into storage of
        # its own tier -- never left in the next receive's scratch slot.
        for name in ("receivedIntoVec", "keptAcrossIterations"):
            text = body(name)
            if "@chan_recv_copy(" not in text or not alloc.search(text):
                problems.append(f"{name} kept a received value in the scratch slot")
        # A message that owns a String is not plain data -- and a send the
        # closed channel refuses releases it, with its fields.
        produce_notes = body("produceNotes")
        if "@chan_send(" not in produce_notes:
            problems.append("an owned message left the pointer path on send")
        if not re.search(r"@chan_send\(.*?icmp eq i32 .*?@__aif_release_Note\(",
                         produce_notes, re.S):
            problems.append("a send to a closed channel does not release the message")
        notes = body("notesStayBoxed")
        if "@chan_recv(" not in notes:
            problems.append("an owned message left the pointer path on receive")
        if "@__aif_release_Note(" not in notes:
            problems.append("a received owned message is not released with its fields")

        exe = Path(tmp) / ("copies.exe" if platform.system() == "Windows" else "copies")
        for program in (source, TEST_DIR / "test_96_channels.psm",
                        TEST_DIR / "test_235_channel_owned_messages.psm"):
            built = run_command([str(PRISMIO_EXE), "build", str(program), "--verify",
                                 "-o", str(exe)])
            if built.returncode != 0:
                problems.append(f"verify build of {program.name} failed: {built.stdout} {built.stderr}")
                continue
            ran = subprocess.run([str(exe)], cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
            output = ran.stdout + ran.stderr
            if ran.returncode or "PASS:" not in output:
                problems.append(f"{program.name} run: {output}")
            if not re.search(r"0 leaked, 0 violation\(s\)", output):
                problems.append(f"{program.name}: no clean verify ledger: {output}")
    if problems:
        print(f"{RED}[FAIL] channel copies: " + "\n".join(problems) + RESET)
        return False
    print(f"{GREEN}[PASS] plain-data channels copy through the ring, owned ones stay "
          f"boxed and release their fields -- refused ones too -- and every ledger is clean{RESET}")
    return True


@harness_test(suite="codegen")
def run_counted_fill_codegen_test():
    """The pure fill grows early; observable calls and early exits do not."""
    print(f"\n{BLUE}--- Running counted_fill_codegen ---{RESET}")
    source = TEST_DIR / "test_132_counted_fill.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-counted-fill-") as tmp:
        ir_path = Path(tmp) / "fill.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] counted fill IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()

        def body(name):
            match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}',
                              ir, re.MULTILINE | re.DOTALL)
            if not match:
                problems.append(f"missing function {name}")
                return ""
            return match.group(1)

        # The preparation is one exact `list_reserve`, not a doubling loop
        # around `list_inline_grow`; either call in a declined loop is a
        # speculative reservation.
        for name in ("fill", "inclusiveFill"):
            if "call void @list_reserve(" not in body(name):
                problems.append(f"{name} did not prepare its empty buffer")
            if "call void @list_inline_grow(" in body(name):
                problems.append(f"{name} prepared its buffer by doubling")
        for name in ("interruptedFill", "observedFill", "queueGrowth"):
            if re.search(r"call void @list_(reserve|inline_grow)\(", body(name)):
                problems.append(f"{name} speculatively grew its buffer")
        if not re.search(r'store i32 .*alias.scope .*noalias', body("structFill")):
            problems.append("struct element initialisation has no region proof")
        if not re.search(r'load i32, .*range', body("fill")):
            problems.append("list counts have no nonnegative range")
        if not re.search(r'store i1 false, ptr %pushguard\.', body("wrappingInclusiveFill")):
            problems.append("inclusive Int.MAX loop received a finite capacity guard")
        bools = body("boolFill")
        if not re.search(r'store i8 1, ptr %\d+', bools):
            problems.append("a Bool element push does not store a byte")
        if re.search(r'store i1 (true|false|%\S+), ptr %\d+', bools):
            problems.append("a Bool element is stored as i1")
        if not re.search(r'icmp ne i8 ', bools):
            problems.append("a Bool element read is not a byte test")

        exe = Path(tmp) / ("fill.exe" if platform.system() == "Windows" else "fill")
        built = run_command([str(PRISMIO_EXE), "build", str(source), "--verify",
                             "-o", str(exe)])
        if built.returncode != 0:
            problems.append(f"verify build failed: {built.stdout} {built.stderr}")
        else:
            # One mode: the run-time PRISMIO_INLINE_ELEMS opt-out is gone. It
            # changed the representation after the compiler had decided the
            # element disposition, which is why boxed runs leaked.
            ran = subprocess.run([str(exe)], cwd=PROJECT_ROOT,
                                 capture_output=True, text=True, encoding="utf-8", errors="replace")
            output = ran.stdout + ran.stderr
            if ran.returncode or "PASS:" not in output:
                problems.append(f"run: {output}")
            if not re.search(r'0 leaked, 0 violation\(s\)', output):
                problems.append(f"no clean verify ledger: {output}")
    if problems:
        print(f"{RED}[FAIL] counted fill: " + "\n".join(problems) + RESET)
        return False
    print(f"{GREEN}[PASS] counted fill guards, struct regions, and a clean verify ledger{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_288_remainder_steps.psm"])
def run_remainder_steps_codegen_test():
    """A `%` by a literal whose dividend the facts bound is a conditional step.

    test_288 checks that the reduced and unreduced remainders agree; this checks
    that the reduced ones were reduced, which a pass of two `srem`s would also
    satisfy, and that the ones that must stay remainders did.
    """
    print(f"\n{BLUE}--- Running remainder_steps_codegen ---{RESET}")
    source = TEST_DIR / "test_288_remainder_steps.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-remainder-") as tmp:
        ir_path = Path(tmp) / "remainder.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] remainder steps IR: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ir_path.read_text()

        def body(name):
            match = re.search(rf'^define [^\n]*@{name}__[^\n]*\n(.*?)^}}',
                              ir, re.MULTILINE | re.DOTALL)
            if not match:
                problems.append(f"missing function {name}")
                return ""
            return match.group(1)

        def srem_by(name, divisor):
            return re.search(rf'srem i32 [^,\n]+, {divisor}\b', body(name)) is not None

        def divides_by(name, divisor):
            return re.search(rf'[su]rem i32 [^,\n]+, {divisor}\b', body(name)) is not None

        for name, divisor in (("checksumValue", 1000000007), ("checksumBoth", 1000000007),
                              ("smallBoth", 11), ("subtractOnly", 17), ("identity", 13),
                              ("nested", 997)):
            if srem_by(name, divisor):
                problems.append(f"{name} kept its % {divisor}")
        if not re.search(r'icmp sle i32 [^,\n]+, -11\b', body("smallBoth")):
            problems.append("smallBoth has no add step for a negative dividend")
        for name, divisor in (("notKept", 1009), ("edge", 2147483647)):
            if not divides_by(name, divisor):
                problems.append(f"{name} lost a % {divisor} its facts do not bound")
    if problems:
        print(f"{RED}[FAIL] remainder steps: " + "\n".join(problems) + RESET)
        return False
    print(f"{GREEN}[PASS] bounded remainders by a literal are steps; unbounded ones stay `srem`{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_04_structs.psm", "tests/test_62_split_release.psm", "tests/test_95_literal_tbaa.psm"])
def run_struct_path_tbaa_test():
    """M6 slice 2: ordinary fields carry their selected record and byte offset.

    Both halves are asserted, because the second one is a performance fix that a
    later reader would otherwise delete as an inconsistency: a field *read* or
    *assignment* carries a struct path, and a struct *literal's* initialiser
    deliberately does not. Tagging initialisers lets LLVM merge them into one
    wide store, which costs 1.68x on g2 -- see
    aif/evidence/RESULTS-M6-struct-path-tbaa.md.
    """
    print(f"\n{BLUE}--- Running struct_path_tbaa ---{RESET}")
    problems = []

    def check_path(ir, name, base_offsets, access_offsets):
        base = re.search(
            rf'^!(\d+) = !\{{!"{re.escape(name)}"([^\n]*)$', ir, re.MULTILINE)
        if not base:
            problems.append(f"{name} has no struct-path base node")
            return
        got_base = [int(n) for n in re.findall(r'i64 (\d+)', base.group(2))]
        if got_base != base_offsets:
            problems.append(f"{name} describes offsets {got_base}, expected {base_offsets}")

        base_id = base.group(1)
        tags = {}
        for tag in re.finditer(
                rf'^!(\d+) = !\{{!{base_id}, !\d+, i64 (\d+)\}}$', ir, re.MULTILINE):
            tags[int(tag.group(1))] = int(tag.group(2))
        used = {
            offset for tag_id, offset in tags.items()
            if re.search(rf'^(?!\!).*!tbaa !{tag_id}\b', ir, re.MULTILINE)
        }
        missing = sorted(set(access_offsets) - used)
        if missing:
            problems.append(f"{name} has no field access tagged at offset(s) {missing}")

    with tempfile.TemporaryDirectory(prefix="prismio-struct-tbaa-") as tmp:
        ordinary = Path(tmp) / "ordinary.ll"
        built = run_command([str(PRISMIO_EXE), "build",
                             str(TEST_DIR / "test_04_structs.psm"),
                             "-o", str(ordinary)])
        if built.returncode != 0:
            problems.append(f"ordinary struct IR build failed: {built.stdout or built.stderr}")
        else:
            ir = ordinary.read_text(encoding="utf-8", errors="replace")
            check_path(ir, "Prismio struct Vector", [0, 8], [0, 8])
            if '"Prismio struct Punned"' in ir:
                problems.append("a struct exposed through raw Ptr received a distinct TBAA base")

        split = Path(tmp) / "split.ll"
        built = run_command([str(PRISMIO_EXE), "build",
                             str(TEST_DIR / "test_62_split_release.psm"),
                             "--force-layout=Body:4", "-o", str(split)])
        if built.returncode != 0:
            problems.append(f"split struct IR build failed: {built.stdout or built.stderr}")
        else:
            ir = split.read_text(encoding="utf-8", errors="replace")
            check_path(ir, "Prismio struct Body.hot",
                       [0, 8, 16, 24, 32], [0, 8, 16, 24, 32])
            check_path(ir, "Prismio struct Body.cold",
                       [0, 8, 16, 24, 32, 36, 40, 44],
                       [0, 8, 16, 24, 32, 36, 40, 44])

        literal = Path(tmp) / "literal.ll"
        built = run_command([str(PRISMIO_EXE), "build",
                             str(TEST_DIR / "test_95_literal_tbaa.psm"),
                             "-o", str(literal)])
        if built.returncode != 0:
            problems.append(f"literal IR build failed: {built.stdout or built.stderr}")
        else:
            ir = literal.read_text(encoding="utf-8", errors="replace")

            def tagged(struct, opcode):
                base = re.search(rf'^!(\d+) = !\{{!"Prismio struct {struct}"',
                                 ir, re.MULTILINE)
                if not base:
                    return None
                paths = {m.group(1) for m in re.finditer(
                    rf'^!(\d+) = !\{{!{base.group(1)}, !\d+, i64 \d+\}}$',
                    ir, re.MULTILINE)}
                body = ir[ir.index("define"):]
                return [ln for ln in body.splitlines()
                        if re.match(rf'\s*(%\S+ = )?{opcode} ', ln)
                        and any(f"!tbaa !{p}" in ln for p in paths)]

            # positive control: without it, the check below passes with the slice
            # deleted rather than declined.
            assigned = tagged("Assigned", "store")
            if assigned is None:
                problems.append("Assigned has no struct-path base at all")
            elif not assigned:
                problems.append("no field assignment carries a struct path")
            initialised = tagged("Initialised", "load")
            if not initialised:
                problems.append("no field read of a literal-built struct carries a "
                                "struct path, so the decline below proves nothing")
            declined = tagged("Initialised", "store") or []
            if declined:
                problems.append(f"{len(declined)} struct-literal initialiser(s) carry a "
                                f"struct path; that merge costs 1.68x on g2")

    if problems:
        print(f"{RED}[FAIL] ordinary struct-path alias metadata is incomplete{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False

    print(f"{GREEN}[PASS] ordinary, reordered and split field accesses carry "
          f"target-layout struct paths; literal initialisers and raw-Ptr-exposed "
          f"structs stay conservative{RESET}")
    return True


@harness_test("generic_layout_specialization_gate", suite="codegen")
def run_generic_layout_specialization_test():
    """M4.4: generic clones choose storage only after T is concrete."""
    print(f"\n{BLUE}--- Running generic_layout_specialization_gate ---{RESET}")
    problems = []
    fixture = TEST_DIR / "test_82_generic_layout.psm"
    out = scratch() / "t82_generic_layout.ll"
    exe = scratch() / "test_82_generic_layout_verify.exe"

    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(out)])
    if result.returncode != 0:
        problems.append(f"generic-layout IR build exited {result.returncode}: "
                        f"{result.stdout or result.stderr}")
    else:
        ir = out.read_text(encoding="utf-8", errors="replace")

        def body(symbol):
            # Generic clone symbols contain '$', so LLVM quotes them.
            match = re.search(r"^define[^\n]*" + re.escape(f'@"{symbol}"') +
                              r"\(.*?^}", ir, re.MULTILINE | re.DOTALL)
            return match.group(0) if match else ""

        symbols = {
            "flat singleton": "singleton$Struct_Flat__Struct_Flat",
            "flat get": "genericGet$Struct_Flat__List_Struct_Flat_Int",
            "flat set": "genericSet$Struct_Flat__List_Struct_Flat_Int_Struct_Flat",
            "boxed singleton": "singleton$Struct_Named__Struct_Named",
            "boxed get": "genericGet$Struct_Named__List_Struct_Named_Int",
            "boxed set": "genericSet$Struct_Named__List_Struct_Named_Int_Struct_Named",
        }
        bodies = {label: body(symbol) for label, symbol in symbols.items()}
        for label, clone_body in bodies.items():
            if not clone_body:
                problems.append(f"could not find the {label} generic clone in IR")

        expected = {
            "flat singleton": "list_push_inline",
            "flat get": "list_get_inline",
            "flat set": "list_set_inline",
            "boxed singleton": "list_push",
            "boxed get": "list_get",
            "boxed set": "list_set",
        }
        for label, operation in expected.items():
            clone_body = bodies[label]
            if clone_body and not re.search(rf"call [^\n]*@{operation}\b", clone_body):
                problems.append(f"the {label} clone does not call @{operation}")

        for label in ("boxed singleton", "boxed get", "boxed set"):
            if "_inline" in bodies[label]:
                problems.append(f"the {label} clone incorrectly selected inline storage")

    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "--verify",
                          "-o", str(exe)])
    if result.returncode != 0:
        problems.append(f"generic-layout --verify build exited {result.returncode}: "
                        f"{result.stdout or result.stderr}")
    else:
        ran = run_command([str(exe)])
        if ran.returncode != 0 or "PASS: generic layout specialization" not in ran.stdout:
            problems.append("the two concrete generic instantiations did not execute correctly")
        report = re.search(r"aif-verify: (\d+) allocated, (\d+) released, "
                           r"(\d+) leaked, (\d+) violation", ran.stderr)
        if not report:
            problems.append("generic-layout --verify run emitted no allocator ledger")
        elif report.group(3) != "0" or report.group(4) != "0":
            problems.append(f"generic-layout run leaked {report.group(3)} allocation(s) "
                            f"with {report.group(4)} violation(s)")

    cleanup_files(out, exe)
    if problems:
        print(f"{RED}[FAIL] generic layout specialization is not discriminating{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False

    print(f"{GREEN}[PASS] generic clones select inline storage only after "
          f"concrete layout substitution{RESET}")
    return True


def _di_scope_file(nodes, ref, depth=0):
    """The DIFile a metadata node belongs to, following `scope:` upwards."""
    text = nodes.get(ref, "")
    if depth > 8:
        return None
    m = re.search(r"file: !(\d+)", text)
    if m:
        return int(m.group(1))
    m = re.search(r"scope: !(\d+)", text)
    if m:
        return _di_scope_file(nodes, int(m.group(1)), depth + 1)
    return None


def _di_located_lines(nodes, filename):
    """Every line a DILocation names *in one source file*.

    Pooling every file's locations is how a marked line can be `located` by
    coincidence: `std/io.psm` is 170 lines long and is merged into every program
    here, so any line number under 170 is in the set whether or not the fixture
    put anything there. That made the `// MARK` assertions pass against a
    compiler with the off-by-one they exist to catch.
    """
    files = {n for n, t in nodes.items() if "DIFile" in t and filename in t}
    lines = set()
    for text in nodes.values():
        if not text.startswith("!DILocation"):
            continue
        at = re.search(r"line: (\d+)", text)
        scope = re.search(r"scope: !(\d+)", text)
        if not at or not scope:
            continue
        if _di_scope_file(nodes, int(scope.group(1))) in files:
            lines.add(int(at.group(1)))
    return lines


def _di_located_spans(nodes, filename):
    """Every (line, column) a DILocation names in one source file.

    The column half matters for exactly one class of defect: a statement whose
    node is built *after* part of its own text is consumed is stamped with
    wherever the parser ended up. `_di_located_lines` cannot see that when the
    parser lands on the same line, which is the usual case for an assignment.
    """
    files = {n for n, t in nodes.items() if "DIFile" in t and filename in t}
    spans = set()
    for text in nodes.values():
        if not text.startswith("!DILocation"):
            continue
        at = re.search(r"line: (\d+)", text)
        col = re.search(r"column: (\d+)", text)
        scope = re.search(r"scope: !(\d+)", text)
        if not at or not col or not scope:
            continue
        if _di_scope_file(nodes, int(scope.group(1))) in files:
            spans.add((int(at.group(1)), int(col.group(1))))
    return spans


@harness_test(suite="codegen", resources={"cpu": 2, "mem": 800},
              reads=["tests/debug_info.psm"])
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
    plain = scratch() / "debug_plain.ll"
    dbg = scratch() / "debug_g.ll"
    split = scratch() / "debug_split.ll"

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

    dbg_nodes = _di_nodes(dbg_ir)
    located = _di_located_lines(dbg_nodes, "debug_info.psm")
    for name, line in sorted(marks.items()):
        if line not in located:
            problems.append(f"nothing is attributed to line {line} "
                            f"(`{name}`) -- the line table has shifted")
    if 0 in {int(m.group(1))
             for m in re.finditer(r"!DILocation\(line: (\d+)", dbg_ir)}:
        problems.append("a DILocation claims line 0 -- a synthesised node was "
                        "given a location instead of inheriting the statement's")

    # The closing braces. Same mechanism as `// MARK`, said separately because it
    # is a different claim: a `}` is not a statement and carries a location only
    # because the code that leaves the scope is emitted there. A block with
    # nothing to emit on the way out is not marked and must not be.
    closes = {}
    for i, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
        m = re.search(r"// CLOSE ([\w-]+)", line)
        if m:
            closes[m.group(1)] = i
    if not closes:
        problems.append("the fixture has no `// CLOSE` comments -- this test "
                        "stopped checking that a scope exit is attributed to the "
                        "brace it leaves through")
    for name, line in sorted(closes.items()):
        if line not in located:
            problems.append(f"nothing is attributed to line {line} (`{name}`), the "
                            "closing brace of a block with cleanup -- the scope "
                            "exit is inheriting the last statement's line instead")

    # 2b-ii. An assignment is stamped from its target, not from wherever the
    # parser ended up.
    #
    # `// ASSIGN <name>` marks a statement whose location must be its own first
    # non-space column. Two different defects, and the line check above catches
    # only one of them:
    #
    #   - `x = e` built its node *after* `=` was consumed, so it took the column
    #     of the right-hand side. Same line, one token to the right, invisible to
    #     any assertion that only looks at line numbers.
    #   - `x op= e` built its node after the whole RHS, so it took the *next
    #     statement's* token -- the 2026-08-22 expression-statement bug again.
    #     Under `-g` it left the compound assignment with no location of its own
    #     at all: the two statements collapsed into one entry and a debugger
    #     stepped straight over it.
    assigns = {}
    for i, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
        m = re.search(r"// ASSIGN ([\w-]+)", line)
        if m:
            assigns[m.group(1)] = (i, len(line) - len(line.lstrip()) + 1)
    if not assigns:
        problems.append("the fixture has no `// ASSIGN` comments -- this test "
                        "stopped checking where an assignment is stamped")
    spans = _di_located_spans(dbg_nodes, "debug_info.psm")
    for name, (line, col) in sorted(assigns.items()):
        if (line, col) not in spans:
            got = sorted(c for (l, c) in spans if l == line)
            problems.append(f"the assignment on line {line} (`{name}`) is not "
                            f"attributed to column {col}, where it starts; "
                            + (f"line {line} carries columns {got} instead"
                               if got else
                               f"nothing is attributed to line {line} at all, so "
                               "the statement inherited a neighbour's location"))

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

    # 2e. Module-level globals. A global has no alloca and no scope stack, so
    # nothing in 2b or 2c reaches it: the description hangs off the global's own
    # value and is collected by the compile unit. Three ways it can be wrong, and
    # the third is the one that matters -- describing something the program never
    # declared is worse than describing nothing.
    globals_wanted = {}
    for i, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
        m = re.search(r"// GLOBAL (\w+) (\w+)", line)
        if m:
            globals_wanted[m.group(1)] = (i, m.group(2))
    if not globals_wanted:
        problems.append("the fixture has no `// GLOBAL` comments -- this test "
                        "stopped checking module-level globals")

    # What di_type_for owes each storage key. A global's type must come from its
    # own declaration: getting it from the previous global, or from the
    # initializer where an annotation disagrees, is a debugger printing an i64 as
    # an int and being wrong about half of it.
    want_basic = {"i32": ("Int", 32), "i64": ("I64", 64),
                  "double": ("Float", 64), "i1": ("Bool", 8)}

    described = {m.group(1): m.group(0) for m in
                 re.finditer(r'!DIGlobalVariable\(name: "(\w+)".*', dbg_ir)}
    for name, (line, key) in sorted(globals_wanted.items()):
        text = described.get(name)
        if text is None:
            problems.append(f"no DIGlobalVariable for `{name}` -- a debugger "
                            "cannot name a module-level global")
            continue
        at = re.search(r"line: (\d+)", text)
        if at is None or int(at.group(1)) != line:
            problems.append(f"`{name}` is described at line "
                            f"{at.group(1) if at else '?'} and is declared on "
                            f"{line}")
        # The declaration must be attached to the global itself, not merely
        # listed in the compile unit: lldb's `target variable` reaches it through
        # the !dbg on the global.
        if re.search(r"^@%s = .*!dbg !\d+" % re.escape(name), dbg_ir, re.M) is None:
            problems.append(f"`@{name}` carries no `!dbg` attachment, so the "
                            "description is not reachable from the global")
        ref = re.search(r"type: !(\d+)", text)
        ty = nodes.get(int(ref.group(1)), "") if ref else ""
        if key in want_basic:
            tname, bits = want_basic[key]
            if (f'name: "{tname}"' not in ty) or (f"size: {bits}" not in ty):
                problems.append(f"`{name}` is declared `{key}` and is described "
                                f"as `{ty}` -- a global's type is not coming "
                                "from its own declaration")
        elif key == "str":
            # A String is the {ptr, i64} pair, so it is a composite and not a
            # pointer -- and the half a debugger prints has to still be reachable
            # through it. Checking only "is a composite" would pass on a struct
            # whose pointer half had been described as an opaque address, which
            # is precisely what this layer did before it learned the pair.
            member_ty = ""
            if 'name: "String"' in ty:
                elems = re.search(r"elements: !(\d+)", ty)
                for ref in _di_tuple(nodes, int(elems.group(1))) if elems else []:
                    body = nodes.get(ref, "")
                    if 'name: "ptr"' not in body:
                        continue
                    base = re.search(r"baseType: !(\d+)", body)
                    member_ty = nodes.get(int(base.group(1)), "") if base else ""
            if 'name: "String"' not in ty:
                problems.append(f"`{name}` is a String and is described as "
                                f"`{ty}` -- not the pair it is stored as")
            elif "DW_TAG_pointer_type" not in member_ty:
                problems.append(f"`{name}` is a String whose `ptr` half is "
                                f"described as `{member_ty}` -- a debugger "
                                "cannot reach the characters through it")
        elif key == "ptr" and "DW_TAG_pointer_type" not in ty:
            problems.append(f"`{name}` is a pointer and is described as `{ty}`")

    # The compile unit has to list them, or the debug info is unreachable from
    # the top of the module even with the attachments in place.
    cu = next((t for t in nodes.values() if "DICompileUnit" in t), "")
    listed = re.search(r"globals: !(\d+)", cu)
    if not listed:
        problems.append("the compile unit lists no `globals:` tuple")
    elif len(_di_tuple(nodes, int(listed.group(1)))) != len(globals_wanted):
        problems.append("the compile unit's `globals:` tuple does not hold one "
                        f"entry per declared global ({len(globals_wanted)})")

    # And nothing describes what the program did not declare. `prismio_argc` and
    # the string-literal globals are codegen's own; naming them in the debug info
    # would put compiler internals in a user's `target variable` output.
    for internal in [n for n in described if n not in globals_wanted]:
        problems.append(f"`{internal}` is described as a source-level global and "
                        "is not one -- it is codegen's own")

    # 2e-bis. A String prints its characters, which is a property of one word.
    # lldb auto-summarises a `char *` and does not auto-summarise a
    # `signed char *`, and it tells them apart by the base type's name -- so
    # docs/DEBUGGING.md's promise that a String shows its contents rests on this
    # basic type being spelled in lower case.
    string_ptr = next((t for t in nodes.values()
                       if "DW_TAG_pointer_type" in t
                       and re.search(r"baseType: !(\d+)", t)
                       and 'name: "char"' in nodes.get(
                           int(re.search(r"baseType: !(\d+)", t).group(1)), "")), None)
    if string_ptr is None:
        problems.append("no `char *` in the module: a String's base type is not "
                        "spelled `char`, and a debugger prints the address "
                        "instead of the characters (docs/DEBUGGING.md)")

    # 2f. Enums. Every Prismio enum lowers to i32, so the storage key cannot
    # tell `Channel` from `Int` and only the source-level name can. Three things
    # are checked, and the second is the one with teeth.
    src_text = source.read_text(encoding="utf-8")
    want_enum = re.search(r"^enum (\w+) \{(.*?)^\}", src_text, re.M | re.S)
    if not want_enum:
        problems.append("the fixture declares no enum -- this test stopped "
                        "checking DW_TAG_enumeration_type")
    else:
        ename = want_enum.group(1)
        eline = src_text[:want_enum.start()].count("\n") + 1
        variants = [v.strip() for v in want_enum.group(2).split(",")
                    if v.strip() and not v.strip().startswith("//")]

        etext = next((t for t in nodes.values()
                      if "DW_TAG_enumeration_type" in t
                      and re.search(r'name: "%s"' % re.escape(ename), t)), None)
        if etext is None:
            problems.append(f"no DW_TAG_enumeration_type for `{ename}` -- an enum "
                            "is described as the i32 it is stored as, so a "
                            "debugger prints an ordinal")
        else:
            at = re.search(r"line: (\d+)", etext)
            if at is None or int(at.group(1)) != eline:
                problems.append(f"`{ename}` is described at line "
                                f"{at.group(1) if at else '?'} and is declared "
                                f"on {eline}")
            elems = re.search(r"elements: !(\d+)", etext)
            got = []
            for ref in (_di_tuple(nodes, int(elems.group(1))) if elems else []):
                m = re.search(r'DIEnumerator\(name: "(\w+)", value: (-?\d+)',
                              nodes.get(ref, ""))
                if m:
                    got.append((m.group(1), int(m.group(2))))
            if got != [(v, i) for i, v in enumerate(variants)]:
                problems.append(f"`{ename}` is described as {got} and is declared "
                                f"{[(v, i) for i, v in enumerate(variants)]} -- "
                                "an enumerator with the wrong value is a debugger "
                                "printing the wrong name")

            # The assertion with teeth. `let seen = pr.channel` names no type:
            # sema infers it from the field, and the debug layer has to carry
            # that through. Bound from a field with no annotation is how this
            # compiler binds an enum nearly everywhere.
            # *Every* `seen`, not the first one. The standard library is
            # compiled into this program, so a local named `seen` anywhere in
            # std/*.psm used to be the one this found -- and the fixture failed
            # describing a variable it was never about. The assertion keeps its
            # teeth either way: if the inferred enum were flattened to Int, none
            # of them would be an enumeration.
            candidates = [t for t in nodes.values()
                          if "DILocalVariable" in t and 'name: "seen"' in t]
            def describes_enum(text):
                ref = re.search(r"type: !(\d+)", text)
                return bool(ref) and "DW_TAG_enumeration_type" in nodes.get(int(ref.group(1)), "")
            if not candidates:
                problems.append("no DILocalVariable for `seen`, so the "
                                "inferred-enum case is not being checked")
            elif not any(describes_enum(t) for t in candidates):
                problems.append("`seen` is bound from an enum-typed struct field "
                                "and is not described as the enum -- an inferred "
                                "enum is being flattened to Int")

            # A struct field of enum type. The member is stored as an i32 and
            # has to be described as the enumeration.
            #
            # Found through `Probe`'s own element list, not by searching the
            # module for a member named "channel": `Reading` has a `channel: Int`
            # too, and the first version of this assertion read that one and
            # failed against a compiler that was right.
            probe = next((t for t in nodes.values()
                          if "DICompositeType" in t and 'name: "Probe"' in t), "")
            elems = re.search(r"elements: !(\d+)", probe)
            if not elems:
                problems.append("no composite type for `Probe`")
            else:
                base = None
                for ref in _di_tuple(nodes, int(elems.group(1))):
                    text = nodes.get(ref, "")
                    if 'name: "channel"' not in text:
                        continue
                    m = re.search(r"baseType: !(\d+)", text)
                    base = nodes.get(int(m.group(1)), "") if m else ""
                if base is None:
                    problems.append("`Probe` has no `channel` member")
                elif "DW_TAG_enumeration_type" not in base:
                    problems.append("`Probe.channel` is declared `Channel` and is "
                                    f"described as `{base}` -- the field is being "
                                    "described as the i32 it is stored as")

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

    print(f"{GREEN}[PASS] -g: {len(marks)} marked lines and {len(closes)} "
          f"closing braces located, "
          f"{len(members)} members at host offsets, {len(globals_wanted)} "
          f"globals described, an enum with {len(variants)} enumerators, "
          f"a split type describes its cold block{RESET}")
    return True


@harness_test(suite="codegen", resources={"mem": 500, "objcache": EXCLUSIVE}, timeout=300)
def run_inline_runtime_default_test():
    """Installed runtime bitcode is merged on every ordinary release build.

    The former curated-source path was optional and fail-open, so a build could
    silently fall back to an opaque runtime object. There is deliberately no
    switch or fallback now: the library merge must run even when the obsolete
    `PRISMIO_INLINE_RUNTIME=0` variable is present, and no curated-source marker
    or runtime-object cache entry may appear.
    """
    print(f"\n{BLUE}--- Running inline_runtime_default ---{RESET}")

    fixture = TEST_DIR / "test_28_list.psm"
    with tempfile.TemporaryDirectory(prefix="prismio-inline-runtime-") as td:
        root = Path(td)
        cache = root / "cache"

        def build_and_run(label, setting):
            exe = root / f"{label}.exe"
            env = os.environ.copy()
            env["PRISMIO_OBJ_CACHE_DIR"] = str(cache)
            env["PRISMIO_OBJ_CACHE_TRACE"] = "1"
            env["PRISMIO_BUILD_TRACE"] = "1"
            if setting is None:
                env.pop("PRISMIO_INLINE_RUNTIME", None)
            else:
                env["PRISMIO_INLINE_RUNTIME"] = setting

            built = subprocess.run(
                [str(PRISMIO_EXE), "build", str(fixture), "-o", str(exe)],
                capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
            output = f"{built.stdout}\n{built.stderr}"
            if built.returncode != 0 or not exe.is_file():
                print(f"{RED}[FAIL] inline runtime {label}: build failed{RESET}")
                print(output[:1200])
                return False

            required = ("[build trace] library bitcode merge",)
            if (any(marker not in output for marker in required)
                    or "[inline runtime]" in output
                    or "[objcache " in output):
                print(f"{RED}[FAIL] inline runtime {label}: bitcode-only merge "
                      f"contract changed{RESET}")
                print(output[:1200])
                return False

            ran = subprocess.run([str(exe)], capture_output=True, text=True, encoding="utf-8", errors="replace")
            if ran.returncode != 0 or "PASS: list" not in ran.stdout:
                print(f"{RED}[FAIL] inline runtime {label}: compiled program failed{RESET}")
                print(f"{ran.stdout}\n{ran.stderr}"[:1200])
                return False
            return True

        if not build_and_run("default", None):
            return False
        if cache.exists() and any(cache.iterdir()):
            print(f"{RED}[FAIL] inline runtime default: a user build produced "
                  f"runtime cache artifacts{RESET}")
            return False
        if not build_and_run("obsolete-switch", "0"):
            return False

    print(f"{GREEN}[PASS] runtime bitcode always merges; no source/object fallback "
          f"or opt-out remains{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_88_single_loop_inline.psm"])
def run_single_loop_inline_test():
    """Only a unique call that is alone in its loop receives alwaysinline.

    This is the discriminating G4/G5 pair in miniature: marking both calls in a
    multi-system loop recreated the measured G4 code-growth regression, while
    omitting the one-call case prevents G5's caller from seeing stable list
    invariants. Debug IR deliberately stays structurally faithful.
    """
    print(f"\n{BLUE}--- Running single_loop_inline ---{RESET}")
    src = TEST_DIR / "test_88_single_loop_inline.psm"
    problems = []

    def marked_functions(text):
        return set(re.findall(
            r"; Function Attrs: [^\n]*alwaysinline[^\n]*\n"
            r"define [^@\n]*@([^\s(]+)", text))

    with tempfile.TemporaryDirectory(prefix="prismio-loop-inline-") as td:
        release = Path(td) / "release.ll"
        debug = Path(td) / "debug.ll"
        for label, out, extra in (("release", release, []),
                                  ("debug", debug, ["-g"])):
            built = run_command([str(PRISMIO_EXE), "build", str(src),
                                 *extra, "-o", str(out)])
            if built.returncode != 0 or not out.exists():
                problems.append(f"{label} IR build failed: "
                                f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")

        if release.exists():
            marked = marked_functions(release.read_text(
                encoding="utf-8", errors="replace"))
            expected = {"hot__Int"}
            if marked != expected:
                problems.append(f"release marked {sorted(marked)}, expected "
                                f"only {sorted(expected)}")
        if debug.exists():
            marked = marked_functions(debug.read_text(
                encoding="utf-8", errors="replace"))
            if marked:
                problems.append(f"debug IR unexpectedly marked {sorted(marked)}")

    if problems:
        print(f"{RED}[FAIL] single-loop inline classifier changed{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] unique single-loop call is inlined; crowded and "
          f"debug calls retain boundaries{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_133_string_dispatch.psm"])
def run_string_dispatch_codegen_test():
    """Release CSDO is two-stage; debug keeps source-level conditions."""
    print(f"\n{BLUE}--- Running string_dispatch_codegen ---{RESET}")
    src = TEST_DIR / "test_133_string_dispatch.psm"
    problems = []

    def function_body(ir):
        match = re.search(r'^define i32 @classify__String\([^\n]*\) [^{]*\{\n(.*?)^}',
                          ir, re.MULTILINE | re.DOTALL)
        if not match:
            problems.append("classify__String is missing from emitted IR")
            return ""
        return match.group(1)

    with tempfile.TemporaryDirectory(prefix="prismio-string-dispatch-") as td:
        release = Path(td) / "release.ll"
        debug = Path(td) / "debug.ll"
        wasm = Path(td) / "wasm.ll"
        for label, out, extra in (("release", release, []),
                                  ("debug", debug, ["-g"])):
            built = run_command([str(PRISMIO_EXE), "build", str(src),
                                 *extra, "-o", str(out)])
            if built.returncode != 0 or not out.exists():
                problems.append(f"{label} IR build failed: "
                                f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")

        built = run_command([str(PRISMIO_EXE), "build", str(src),
                             "--target", "wasm32-unknown-unknown", "-o", str(wasm)])
        if built.returncode != 0 or not wasm.exists():
            problems.append("wasm IR build failed: "
                            f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")

        if release.exists():
            body = function_body(release.read_text(encoding="utf-8", errors="replace"))
            if body.count("switch i32") != 3:
                problems.append("release IR lacks one length and two selected-byte switches")
            if len(re.findall(r'call [^\n]*@memcmp\(', body)) != 7:
                problems.append("release IR does not expose all seven fixed-width comparisons")
            if re.search(r'call [^\n]*@equals__String_String\(', body):
                problems.append("release IR retained the linear String.equals chain")

        if wasm.exists():
            body = function_body(wasm.read_text(encoding="utf-8", errors="replace"))
            calls = re.findall(r'call i32 @memcmp\([^\n]+\)', body)
            if len(calls) != 7 or any(
                    not re.search(r', i32 \d+\)$', call) for call in calls):
                problems.append("wasm literal comparisons do not use 32-bit size_t")

        if debug.exists():
            body = function_body(debug.read_text(encoding="utf-8", errors="replace"))
            if "switch i32" in body or "@memcmp(" in body:
                problems.append("debug IR unexpectedly applied CSDO")
            if len(re.findall(r'call [^\n]*@equals__String_String\(', body)) != 7:
                problems.append("debug IR did not retain all seven source conditions")

    if problems:
        print(f"{RED}[FAIL] constant-string dispatch lowering changed{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] release uses length/byte dispatch; debug preserves the chain{RESET}")
    return True


@harness_test(suite="codegen")
def run_overflow_checks_test():
    """RFC 0560's model: check in debug, wrap in release.

    `Int` is signed 32-bit and wraps, decided by measurement in
    RESULTS-int-width.md. `--overflow-checks` is what makes that wrap a
    diagnostic instead of a silence, and it is off by default because a checked
    operation is 5.4x-6.0x the plain one -- not because the check is expensive,
    but because a branch per operation defeats vectorization outright.

    Three facts, and the first two are the discriminating pair. Asserting only
    that the checked build traps would pass against a compiler that checked
    *always*, which is the version that must never ship:

      default            wraps to -2147483596, exit 0, and emits no intrinsic
      --overflow-checks  reports the overflow with the operator and the line
      default IR         contains no llvm.*.with.overflow at all
    """
    print(f"\n{BLUE}--- Running overflow_checks ---{RESET}")
    src = TEST_DIR / "overflow_checks_probe.psm"
    exe = scratch() / "overflow_checks_probe.exe"
    ll = scratch() / "overflow_checks_probe.ll"
    problems = []

    # 1. The default build wraps and says nothing.
    built = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(exe)])
    if built.returncode != 0:
        problems.append(f"default build exited {built.returncode}")
    else:
        got = run_program(exe)
        if not got[0]:
            problems.append("default build did not exit 0 -- it must wrap, not trap")
        elif "-2147483596" not in got[1]:
            problems.append(f"default build printed {got[1].strip()!r}, expected the wrapped -2147483596")

    # 2. The checked build reports it, naming the operator and the line.
    built = run_command([str(PRISMIO_EXE), "build", str(src), "--overflow-checks", "-o", str(exe)])
    if built.returncode != 0:
        problems.append(f"--overflow-checks build exited {built.returncode}")
    else:
        ok, out, err = run_program(exe)
        both = (out or "") + (err or "")
        if ok:
            problems.append("--overflow-checks build exited 0; the overflow was not reported")
        if "integer overflow" not in both:
            problems.append(f"no overflow diagnostic in output: {both.strip()[:200]!r}")
        if "`+`" not in both:
            problems.append("the diagnostic does not name the operator that overflowed")
        if "overflow_checks_probe.psm:13" not in both:
            problems.append(f"the diagnostic does not name the overflowing line (13): {both.strip()[:200]!r}")

    # 3. The default really is inert -- no intrinsic, not merely no trap.
    emitted = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(ll)])
    if emitted.returncode == 0 and ll.exists():
        text = ll.read_text(encoding="utf-8", errors="replace")
        if "with.overflow" in text:
            problems.append("the default build emitted an overflow intrinsic; the flag is not off")
    cleanup_files(exe, ll)

    if problems:
        print(f"{RED}[FAIL] overflow checks{RESET}")
        for p in problems:
            print(f"  {p}")
        return False
    print(f"{GREEN}[PASS] overflow checks: default wraps and emits no intrinsic; "
          f"--overflow-checks names the operator and the line{RESET}")
    return True


@harness_test(suite="codegen")
def run_repeated_copy_test():
    """A block copy repeated eight times leaves one `memcpy`.

    `for i in 0..<n { target[i] = source[i] }` is MEM-006's block transfer, and
    in `large_buffer_copy` it runs eight identical rounds. C++ and Rust keep one:
    their buffers are `noalias` allocations, so DSE sees each round overwrite the
    last without reading it. A Prismio buffer is a load out of a list header, and
    without `separate_storage` on the copy LLVM kept all eight -- 1.16x of C++.

    Exactly one, read in the optimised IR of the probe's function: none means the
    `for` form no longer reaches the block copy, and eight means the rounds are
    no longer deleted. The output checks that what was kept is the right copy.
    """
    print(f"\n{BLUE}--- Running repeated_copy ---{RESET}")
    src = TEST_DIR / "repeated_copy_probe.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-repeated-copy-") as td:
        ll = Path(td) / "probe.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(src), "-O3", "-o", str(ll)])
        if built.returncode != 0 or not ll.exists():
            problems.append(f"IR build failed: "
                            f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")
        else:
            text = ll.read_text(encoding="utf-8", errors="replace")
            m = re.search(r"define [^@\n]*@rounds__Int\(.*?\n}\n", text, re.S)
            body = m.group(0) if m else ""
            copies = body.count("call void @llvm.memcpy")
            if not body:
                problems.append("rounds__Int is not in the IR")
            elif copies != 1:
                problems.append(f"rounds__Int has {copies} memcpy calls, expected 1")
            elif "separate_storage" not in body:
                problems.append("the copy is not behind a separate_storage assume")

        exe = Path(td) / ("probe" + (".exe" if os.name == "nt" else ""))
        built = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(exe)])
        if built.returncode != 0:
            problems.append(f"build failed: "
                            f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")
        else:
            ok, out, _ = run_program(exe)
            if not ok or out.strip() != "46995":
                problems.append(f"probe printed {out.strip()!r}, expected 46995")

    if problems:
        print(f"{RED}[FAIL] repeated copy{RESET}")
        for p in problems:
            print(f"  {p}")
        return False
    print(f"{GREEN}[PASS] repeated copy{RESET}")
    return True


@harness_test(suite="codegen")
def run_byte_loop_vectorise_test():
    """A `byteAt` loop over a String parameter vectorises.

    A String parameter's bytes are located once, in the entry block, so a byte
    loop indexes a pointer (src/ir/module.psm). Done in a *loop-free* function,
    that was three stores to a scratch slot, and inlining `strByteAt` into a
    caller's loop brought them into the loop between lifetime markers LICM will
    not hoist past: summing 1 MB with `s.byteAt(i)` measured 18.8 ms against
    0.58 ms vectorised. So it is done only where a loop amortises it.

    Three facts, and the pair of IR facts is what discriminates:

      sumBytes    has a loop, so its entry resolves `s` (`%str.inline`)
      firstByte   has none, so it does not
      optimised   sumBytes's loop has a `vector.body`

    An executable internalises everything but `main`, so the optimiser inlines
    single-caller `sumBytes` into `main` and deletes it before the vectoriser
    runs; the loop is read wherever it ends up. `main`'s only other loop builds
    a StringBuilder through calls, which cannot vectorise, so a `vector.body`
    in the dump is still the byte loop's.

    The last alone would pass a compiler that stopped resolving anywhere, which
    is the tokenizer's 204,000 per-character tests back; the first two alone
    would pass one whose loop still did not vectorise. PRISMIO_LLVM_ARGS is a
    measurement switch, and the one way to read IR after LLVM's own passes.
    """
    print(f"\n{BLUE}--- Running byte_loop_vectorise ---{RESET}")
    src = TEST_DIR / "byte_loop_probe.psm"
    problems = []

    def function_body(text, symbol):
        m = re.search(r"define [^@\n]*@" + re.escape(symbol) + r"\(.*?\n}\n", text, re.S)
        return m.group(0) if m else ""

    with tempfile.TemporaryDirectory(prefix="prismio-byte-loop-") as td:
        ll = Path(td) / "probe.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(ll)])
        if built.returncode != 0 or not ll.exists():
            problems.append(f"IR build failed: "
                            f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")
        else:
            text = ll.read_text(encoding="utf-8", errors="replace")
            if "%str.inline" not in function_body(text, "sumBytes__String"):
                problems.append("sumBytes no longer resolves its parameter at entry")
            if "%str.inline" in function_body(text, "firstByte__String"):
                problems.append("firstByte, which has no loop, resolves its parameter")

        exe = Path(td) / ("probe" + (".exe" if os.name == "nt" else ""))
        env = dict(os.environ)
        env["PRISMIO_LLVM_ARGS"] = ("-print-after=loop-vectorize "
                                    "-filter-print-funcs=sumBytes__String,main")
        opt = subprocess.run([str(PRISMIO_EXE), "build", str(src), "-o", str(exe)],
                             capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
        dump = (opt.stdout or "") + (opt.stderr or "")
        if opt.returncode != 0:
            problems.append(f"optimised build failed: {elide_middle(dump)}")
        else:
            if "sumBytes__String" not in dump and "@main(" not in dump:
                problems.append("LLVM printed nothing for sumBytes or main; "
                                "the switch was not honoured")
            elif "vector.body" not in dump:
                problems.append("sumBytes's byte loop did not vectorise")
            ok, out, _ = run_program(exe)
            if not ok or out.strip() != "51553":
                problems.append(f"probe printed {out.strip()!r}, expected 51553")

    if problems:
        print(f"{RED}[FAIL] byte loop vectorisation{RESET}")
        for p in problems:
            print(f"  {p}")
        return False
    print(f"{GREEN}[PASS] a byteAt loop vectorises; parameters resolve only where a loop is{RESET}")
    return True


def llvm_function_attributes(text):
    """A function `attrs(prefix)` over IR text: the attributes of the first `define`
    whose symbol starts with `prefix`, or None when none was emitted. Attribute
    groups (`#4`) are resolved through the `attributes #4 = { ... }` lines."""
    groups = {}
    for m in re.finditer(r"^attributes (#\d+) = \{ (.*?) \}$", text, re.M):
        groups[m.group(1)] = m.group(2).split()

    def attrs(prefix):
        m = re.search(r"^define [^@\n]*@\"?" + re.escape(prefix) + r"[^(]*\([^)]*\)([^{]*)\{",
                      text, re.M)
        if not m:
            return None
        found = []
        for ref in re.findall(r"#\d+", m.group(1)):
            found += groups.get(ref, [])
        return found

    return attrs


@harness_test(suite="codegen",
              reads=["tests/test_231_cold_functions.psm"])
def run_cold_function_test():
    """`cold fn` lowers to LLVM `cold` and `noinline`, and nothing else does.

    test_231_cold_functions checks that every placement runs; this reads its IR,
    because the marker changes no behaviour and a lowering that dropped it would
    pass any output check. It is load-bearing for performance: an executable
    internalises every function but `main`, LLVM inlines an internal function's
    only call whatever its size, and std's `mapInsert` is `cold` so that it is
    not folded back into `mapSet` (key_value_update measured 1.28x without it).

    Marked: a free function, a `private` one, an `impl` method and a generic
    instantiation. Unmarked: a function *named* `cold` and ordinary neighbours.
    """
    print(f"\n{BLUE}--- Running cold_function ---{RESET}")
    src = TEST_DIR / "test_231_cold_functions.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-cold-") as td:
        ll = Path(td) / "cold.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(ll)])
        if built.returncode != 0 or not ll.exists():
            problems.append(f"IR build failed: "
                            f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")
        else:
            text = ll.read_text(encoding="utf-8", errors="replace")
            groups = {}
            for m in re.finditer(r"^attributes (#\d+) = \{ (.*?) \}$", text, re.M):
                groups[m.group(1)] = m.group(2).split()

            def attrs(prefix):
                m = re.search(r"^define [^@\n]*@\"?" + re.escape(prefix) + r"[^(]*\([^)]*\)([^{]*)\{",
                              text, re.M)
                if not m:
                    return None
                found = []
                for ref in re.findall(r"#\d+", m.group(1)):
                    found += groups.get(ref, [])
                return found

            for name in ("failWith__", "sumSquares__", "reset__Struct_Counter", "lengthOr$Int"):
                got = attrs(name)
                if got is None:
                    problems.append(f"{name} was not emitted")
                elif "cold" not in got or "noinline" not in got:
                    problems.append(f"{name} is cold but carries {got}")
            for name in ("cold__Int", "bumped__Struct_Counter", "clamp__Int"):
                got = attrs(name)
                if got is None:
                    problems.append(f"{name} was not emitted")
                elif "cold" in got or "noinline" in got:
                    problems.append(f"{name} is not cold but carries {got}")

    if problems:
        print(f"{RED}[FAIL] cold functions{RESET}")
        for p in problems:
            print(f"  {p}")
        return False
    print(f"{GREEN}[PASS] cold functions lower to cold+noinline, and only they do{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_312_inline_fn.psm"])
def run_inline_fn_test():
    """`inline fn` lowers to LLVM `inlinehint` -- a hint, not `alwaysinline` -- and
    nothing else does. (A marked function may *also* be `alwaysinline`: codegen forces
    that on its own for a function with one callsite inside a loop, whatever it says.)

    test_312_inline_fn checks that every placement runs; this reads its IR, because
    the marker changes no behaviour and a lowering that dropped it would pass any
    output check. `inline(always)`, the spelling that forces it, is
    run_fn_attributes_test's.

    Marked: a free function, a `private` one, a looping one, a generic instantiation,
    an `impl` method, a `private` method and an `export` one. Unmarked: a function
    *named* `inline` and ordinary neighbours.
    """
    print(f"\n{BLUE}--- Running inline_fn ---{RESET}")
    src = TEST_DIR / "test_312_inline_fn.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-inline-") as td:
        ll = Path(td) / "inline.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(ll)])
        if built.returncode != 0 or not ll.exists():
            problems.append(f"IR build failed: "
                            f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")
        else:
            text = ll.read_text(encoding="utf-8", errors="replace")
            groups = {}
            for m in re.finditer(r"^attributes (#\d+) = \{ (.*?) \}$", text, re.M):
                groups[m.group(1)] = m.group(2).split()

            def attrs(prefix):
                m = re.search(r"^define [^@\n]*@\"?" + re.escape(prefix) + r"[^(]*\([^)]*\)([^{]*)\{",
                              text, re.M)
                if not m:
                    return None
                found = []
                for ref in re.findall(r"#\d+", m.group(1)):
                    found += groups.get(ref, [])
                return found

            for name in ("square__Int", "addOne__Int", "sumTo__Int", "firstOr$Int", "bumped__Struct_Counter",
                         "doubled__Struct_Counter", "exported__Int"):
                got = attrs(name)
                if got is None:
                    problems.append(f"{name} was not emitted")
                elif "inlinehint" not in got:
                    problems.append(f"{name} is inline but carries {got}")
            for name in ("inline__Int", "quadrupled__Struct_Counter", "reset__Struct_Counter", "plain__Int"):
                got = attrs(name)
                if got is None:
                    problems.append(f"{name} was not emitted")
                elif "inlinehint" in got or "alwaysinline" in got:
                    problems.append(f"{name} is not inline but carries {got}")

    if problems:
        print(f"{RED}[FAIL] inline functions{RESET}")
        for p in problems:
            print(f"  {p}")
        return False
    print(f"{GREEN}[PASS] inline functions lower to inlinehint, and only they do{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_334_fn_attributes.psm"])
def run_fn_attributes_test():
    """`inline(always)`, `inline(never)`, `noinline`, `hot`, `noreturn` and `cold`
    lower to the LLVM attributes they name, and only to those.

    test_334_fn_attributes checks that every placement runs; this reads its IR,
    because none of the markers changes what a program computes, so a lowering that
    dropped one would pass any output check. Marked: free functions, a `private` one,
    generic instantiations, `impl` methods, and combinations in either order.
    Unmarked: functions *named* after the markers, and ordinary neighbours.
    """
    print(f"\n{BLUE}--- Running fn_attributes ---{RESET}")
    src = TEST_DIR / "test_334_fn_attributes.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-fnattrs-") as td:
        ll = Path(td) / "attrs.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(ll)])
        if built.returncode != 0 or not ll.exists():
            problems.append(f"IR build failed: "
                            f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")
        else:
            attrs = llvm_function_attributes(ll.read_text(encoding="utf-8", errors="replace"))
            expected = {
                "square__Int": {"alwaysinline"},
                "addOne__Int": {"alwaysinline"},
                "firstOr$Int": {"alwaysinline"},
                "bumped__Struct_Counter": {"alwaysinline"},
                "plusTwo__Int": {"noinline"},
                "plusThree__Int": {"noinline"},
                "lastOr$Int": {"noinline"},
                "doubled__Struct_Counter": {"noinline"},
                "reset__Struct_Counter": {"noinline"},
                "sumTo__Int": {"hot"},
                "tripled__Struct_Counter": {"hot"},
                "combined__Int": {"alwaysinline", "hot"},
                "hotAndNotInlined__Int": {"hot", "noinline"},
                "die__Int": {"noreturn"},
                "dieSlowly__Int": {"cold", "noinline", "noreturn"},
                "abort__Struct_Counter": {"cold", "noinline", "noreturn"},
            }
            for name, want in expected.items():
                got = attrs(name)
                if got is None:
                    problems.append(f"{name} was not emitted")
                elif set(got) != want:
                    problems.append(f"{name} should carry exactly {sorted(want)} but carries {got}")
            for name in ("checked__Int", "hot__Int", "noinline__Int", "noreturn__Int",
                         "plain__Int", "quadrupled__Struct_Counter"):
                got = attrs(name)
                if got is None:
                    problems.append(f"{name} was not emitted")
                elif got:
                    problems.append(f"{name} is unmarked but carries {got}")

    if problems:
        print(f"{RED}[FAIL] function attributes{RESET}")
        for p in problems:
            print(f"  {p}")
        return False
    print(f"{GREEN}[PASS] function markers lower to the attributes they name, and only those{RESET}")
    return True


@harness_test(suite="codegen")
def run_c_abi_extension_test():
    """A `bool`, `char` or 8-/16-bit integer crossing to or from C is widened as C's ABI says.

    On Apple arm64, x86 SysV, i686 and wasm the *caller* widens these to 32 bits and
    the callee trusts it (`int widen(uint8_t x) { return x; }` is `mov w0, w0`).
    Before `zeroext`/`signext` were emitted, `widen(401 as U8)` answered 401 rather
    than 145 on Apple arm64, and C reading an `export fn ... -> U8` saw 401 too.

    Two halves. The run catches the defect on a host whose ABI widens in the caller
    (it passes either way on Linux arm64, where the callee does). The IR half checks
    each triple against clang's own table -- the attribute is as wrong where the ABI
    does not want it as missing where it does, so absence is asserted as well.
    """
    print(f"\n{BLUE}--- Running c_abi_extension ---{RESET}")
    problems = []
    c_source = (
        "#include <stdint.h>\n#include <stdbool.h>\n"
        "int widen(uint8_t x) { return x; }\n"
        "int widen_signed(int8_t x) { return x; }\n"
        "int pick(bool b) { return b ? 7 : 3; }\n"
        "uint8_t narrow(int x);\n"
        "int via_export(int x) { return narrow(x); }\n")
    # A loop and a call keep the narrowed value in a register LLVM did not just
    # build from a constant, which is the case that reached C unextended.
    program = (
        "import std.io\nimport std.string\n\n"
        "extern fn widen(x: U8) -> Int\nextern fn widen_signed(x: I8) -> Int\n"
        "extern fn pick(b: Bool) -> Int\nextern fn via_export(x: Int) -> Int\n\n"
        "export fn narrow(x: Int) -> U8 { return x as U8 }\n\n"
        "fn bump(n: Int) -> Int { return n * 3 + 1 }\n\n"
        "fn main() {\n    let mut i = 0\n    while (i < 3) {\n"
        "        let wide = bump(100 + i) + 100\n"
        "        println(\"u8 \".concat(widen(wide as U8) as String))\n"
        "        println(\"i8 \".concat(widen_signed(wide as I8) as String))\n"
        "        println(\"bool \".concat(pick((wide & 256) != 0) as String))\n"
        "        println(\"export \".concat(via_export(wide) as String))\n"
        "        i = i + 1\n    }\n}\n")
    expected = "".join(f"u8 {w & 0xFF}\ni8 {(w & 0xFF) - 256 if w & 0x80 else w & 0xFF}\n"
                       f"bool 7\nexport {w & 0xFF}\n" for w in (401, 404, 407))

    # Each triple's expected signature, read from `clang -target <t> -S -emit-llvm`.
    widened = {"takes": ("zeroext i8", ["i8 zeroext", "i16 signext", "i1 zeroext", "i8 signext", "i32"]),
               "gives": ("signext i8", ["i16 zeroext", "i1 zeroext"])}
    bool_only = {"takes": ("i8", ["i8", "i16", "i1 zeroext", "i8", "i32"]),
                 "gives": ("i8", ["i16", "i1 zeroext"])}
    plain = {"takes": ("i8", ["i8", "i16", "i1", "i8", "i32"]),
             "gives": ("i8", ["i16", "i1"])}
    triples = [("arm64-apple-macosx14.0.0", widened), ("x86_64-unknown-linux-gnu", widened),
               ("wasm32-unknown-unknown", widened), ("x86_64-pc-windows-msvc", bool_only),
               ("aarch64-unknown-linux-gnu", plain), ("aarch64-pc-windows-msvc", plain)]
    signatures = (
        "extern fn takes(a: U8, b: I16, c: Bool, d: Char, e: Int) -> U8\n"
        "export fn gives(a: U16, b: Bool) -> I8 { return 1 }\n"
        "fn main() -> Int {\n    let r = takes(1, 2, true, 'a', 5)\n"
        "    return r as Int + gives(3, false) as Int\n}\n")
    noise = {"noundef", "dso_local", "local_unnamed_addr", "hidden", "dllexport"}

    def signature(text, name):
        m = re.search(r"^(?:declare|define) ([^@\n]*)@\"?" + re.escape(name) + r"[^(\"]*\"?\(([^)]*)\)",
                      text, re.M)
        if not m:
            return None
        ret = " ".join(w for w in m.group(1).split() if w not in noise)
        params = [" ".join(w for w in p.split() if w not in noise and not w.startswith("%"))
                  for p in m.group(2).split(",") if p.strip()]
        return ret, params

    with tempfile.TemporaryDirectory(prefix="prismio-c-abi-") as td:
        work = Path(td)
        (work / "abi.c").write_text(c_source, encoding="utf-8")
        (work / "main.psm").write_text(program, encoding="utf-8")
        exe = work / ("abi" + (".exe" if os.name == "nt" else ""))
        built = run_command([str(PRISMIO_EXE), "build", str(work / "main.psm"),
                             "--native", str(work / "abi.c"), "-o", str(exe)])
        if built.returncode != 0 or not exe.exists():
            problems.append(f"the probe did not build: "
                            f"{elide_middle((built.stdout or '') + (built.stderr or ''))}")
        else:
            ran = run_command([str(exe)])
            if ran.stdout.replace("\r\n", "\n") != expected:
                problems.append(f"C saw unextended values:\n  expected {expected!r}\n"
                                f"  got      {ran.stdout!r}")

        (work / "sig.psm").write_text(signatures, encoding="utf-8")
        for triple, want in triples:
            ll = work / f"sig-{triple}.ll"
            emitted = run_command([str(PRISMIO_EXE), "build", str(work / "sig.psm"),
                                   "--target", triple, "-o", str(ll)])
            if emitted.returncode != 0 or not ll.exists():
                problems.append(f"{triple}: IR build failed: "
                                f"{elide_middle((emitted.stdout or '') + (emitted.stderr or ''))}")
                continue
            text = ll.read_text(encoding="utf-8", errors="replace")
            for name, sig in want.items():
                got = signature(text, name)
                if got != sig:
                    problems.append(f"{triple}: {name} is {got}, clang's ABI says {sig}")

    if problems:
        print(f"{RED}[FAIL] c_abi_extension{RESET}")
        for p in problems:
            print(f"  {p}")
        return False
    print(f"{GREEN}[PASS] narrow values cross to and from C widened as each target's C ABI says{RESET}")
    return True


@harness_test(suite="codegen", resources={"mem": 500, "objcache": EXCLUSIVE}, timeout=300)
def run_runtime_object_from_ir_test():
    """Ordinary builds consume installed modules, never runtime C or objects."""
    print(f"\n{BLUE}--- Running runtime_object_from_ir ---{RESET}")

    fixture = TEST_DIR / "test_28_list.psm"
    with tempfile.TemporaryDirectory(prefix="prismio-runtime-from-ir-") as td:
        root = Path(td)
        cache = root / "cache"

        def build(label):
            exe = root / f"{label}.exe"
            env = os.environ.copy()
            env["PRISMIO_OBJ_CACHE_DIR"] = str(cache)
            env["PRISMIO_OBJ_CACHE_TRACE"] = "1"
            env["PRISMIO_BUILD_TRACE"] = "1"

            built = subprocess.run(
                [str(PRISMIO_EXE), "build", str(fixture), "-o", str(exe)],
                capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
            output = f"{built.stdout}\n{built.stderr}"
            if built.returncode != 0 or not exe.is_file():
                print(f"{RED}[FAIL] runtime object {label}: build failed{RESET}")
                print(output[:1200])
                return None
            ran = subprocess.run([str(exe)], capture_output=True, text=True, encoding="utf-8", errors="replace")
            if ran.returncode != 0 or "PASS: list" not in ran.stdout:
                print(f"{RED}[FAIL] runtime object {label}: compiled program failed{RESET}")
                print(f"{ran.stdout}\n{ran.stderr}"[:1200])
                return None
            return output, ran.stdout

        default = build("default")
        if default is None:
            return False
        output = default[0]
        if ("[build trace] library bitcode merge" not in output
                or "lang_runtime (from IR)" in output
                or "[objcache " in output
                or (cache.exists() and any(cache.iterdir()))):
            print(f"{RED}[FAIL] runtime modules: an ordinary build used the "
                  f"retired source/object path{RESET}")
            print(output[:1200])
            return False

    print(f"{GREEN}[PASS] ordinary build merged installed runtime modules without "
          f"creating source/object cache artifacts{RESET}")
    return True


@harness_test(suite="codegen")
def run_single_thread_state_test():
    """A program that never spawns carries none of the runtime's thread state.

    The slab allocator's thread key, the cycle collector's lock and the worker
    thread-locals are reachable only from a second thread. Each is initialised
    data, so one of them left in a program is a 16 KiB page of `__DATA` on macOS:
    hello was 51,160 bytes instead of 34,120 for a `volatile` flag and a
    thread-local's address compared against a global's, neither of which LLVM
    folds. Nothing else in the suite looks at what a build leaves behind.
    """
    print(f"\n{BLUE}--- Running single_thread_state ---{RESET}")
    nm = shutil.which("llvm-nm") or (None if os.name == "nt" else shutil.which("nm"))
    if nm is None:
        print(f"{GREEN}[PASS] single_thread_state: skipped -- no nm or llvm-nm on PATH{RESET}")
        return True
    banned = ("slab_tls", "slab_key", "cyc_lock_once", "prismio_memory_worker",
              "arena_worker_state", "rt_worker_arena_hint")
    # test_100 builds a cyclic structure, so it reaches the collector's lock.
    fixtures = ("test_28_list.psm", "test_100_reuse_token.psm")
    with tempfile.TemporaryDirectory(prefix="prismio-single-thread-") as td:
        for name in fixtures:
            exe = Path(td) / (name[:-4] + ".exe")
            built = subprocess.run(
                [str(PRISMIO_EXE), "build", str(TEST_DIR / name), "-o", str(exe)],
                capture_output=True, text=True, encoding="utf-8", errors="replace")
            if built.returncode != 0 or not exe.is_file():
                print(f"{RED}[FAIL] single_thread_state: {name} did not build{RESET}")
                print(f"{built.stdout}\n{built.stderr}"[:1200])
                return False
            listed = subprocess.run([nm, str(exe)], capture_output=True, text=True,
                                    encoding="utf-8", errors="replace")
            if listed.returncode != 0 or "main" not in listed.stdout:
                print(f"{RED}[FAIL] single_thread_state: could not list {name}'s symbols{RESET}")
                print(listed.stderr[:600])
                return False
            kept = sorted({word for word in banned if word in listed.stdout})
            if kept:
                print(f"{RED}[FAIL] single_thread_state: {name} never spawns and keeps "
                      f"{', '.join(kept)}{RESET}")
                return False
    print(f"{GREEN}[PASS] {len(fixtures)} programs that never spawn keep no thread state{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["runtime/build_driver.c", "src/ir/expr.psm"])
def run_curated_emits_test():
    """Every op codegen *emits* for a flat element type must be curated.

    This is the check whose absence cost a whole milestone. M1.1 curated
    `list_get`; M4.2 added the `_inline` family and taught `inlineOpName` to emit
    *those* wherever the element type is statically flat, and
    `PRISMIO_CURATED_OPS` was never updated. So codegen emitted
    `list_get_inline`, the curated module contained `list_get`, and every
    flat-element access in the corpus paid a real `bl` into a five-line function
    -- with the seam that mechanism exists to remove sitting back in the hot
    loop. Curating it was worth a corpus median of 0.861x.

    Nothing connected the two lists, so nothing noticed. This connects them.

    **A name may be absent only with a reason recorded beside it**, because two
    of the three genuinely cannot be curated yet: `list_set_inline` and
    `list_push_inline` reach `static` helpers in lang_runtime.c, which is the
    closure violation `PRISMIO_CURATED_OPS`' own comment records for `list_push`.
    The waiver list here is that fact written down where the check can see it --
    so removing the blocker and forgetting to curate the op still fails.
    """
    print(f"\n{BLUE}--- Running curated_emits ---{RESET}")

    expr = (PROJECT_ROOT / "src" / "ir" / "expr.psm").read_text(encoding="utf-8")
    driver = (PROJECT_ROOT / "runtime" / "build_driver.c").read_text(encoding="utf-8")

    body = re.search(r"fn inlineOpName\(.*?\n\}", expr, re.S)
    if not body:
        print(f"{RED}[FAIL] curated emits: could not find inlineOpName in src/ir/expr.psm{RESET}")
        return False
    emitted = set(re.findall(r'return "([a-z_0-9]+)"', body.group(0)))
    # The scalar calls refine that generic mapping after the element width is
    # known. They are emitted ops too; omitting them here recreates the stale
    # curated-list hole this gate exists to catch.
    emitted.update(re.findall(r'inlineName\s*=\s*"([a-z_0-9]+)"', expr))
    emitted.discard("")

    ops = re.search(r"PRISMIO_CURATED_OPS\[\] = \{(.*?)\};", driver, re.S)
    if not ops:
        print(f"{RED}[FAIL] curated emits: could not find PRISMIO_CURATED_OPS{RESET}")
        return False
    curated = set(re.findall(r'"([a-z_0-9]+)"', ops.group(1)))

    # Absent on purpose. Remove an entry the day its reason stops holding, and
    # this check then requires the op to be curated.
    #
    # **Both were tried, and the reason they are still waived is now a
    # measurement rather than a blocker (2026-08-29).** The blocker was real and
    # is removable: curating them needs `list_release_source` and
    # `list_inline_grow` given external linkage, which was done and made
    # `run_curated_closure_test` pass at 14 ops. `list_copy_elem` never needed
    # it -- clang inlines it into both callers before curation.
    #
    # It is worth **nothing**: corpus median **0.999x** (range 0.981-1.024x)
    # for **+3.1% compile time** (415 -> 428 ms on src/main.psm). The prediction
    # that "g6 and g2 are write-heavy so they would move" was wrong -- they push
    # in a setup phase, not in the hot loop, and read is what the loops do.
    # Reverted on the gate's own prize-over-cost rule.
    #
    # So: do not re-attempt this expecting a win. Re-attempt it only with a
    # program whose *hot loop* pushes, and check that program exists first.
    #
    # The insert pair (2026-09-17) is waived on cost shape, not on a measurement:
    # an insert is a push followed by an O(n) memmove through lang_runtime.c's
    # static `list_move_last`, so the call is not what an insert costs, and no
    # benchmark or corpus program inserts at all. Curating them would also need
    # the push_inline closure work above.
    waived = {
        "list_set_inline": "curating it measured 0.999x for +3.1% compile time (2026-08-29)",
        "list_push_inline": "curating it measured 0.999x for +3.1% compile time (2026-08-29)",
        "list_insert_inline": "an O(n) shift behind a static helper; no program inserts in a hot loop (2026-09-17)",
        "list_insert_inline_scalar": "an O(n) shift behind a static helper; no program inserts in a hot loop (2026-09-17)",
    }

    problems = []
    for op in sorted(emitted):
        if op in curated or op in waived:
            continue
        problems.append(f"codegen emits {op!r} but PRISMIO_CURATED_OPS does not carry it")
    for op in sorted(waived):
        if op in curated:
            problems.append(f"{op!r} is curated but still listed as waived here; drop the waiver")
        if op not in emitted:
            problems.append(f"{op!r} is waived but inlineOpName no longer emits it; drop the waiver")

    if problems:
        print(f"{RED}[FAIL] curated emits{RESET}")
        for p in problems:
            print(f"  {p}")
        return False
    print(f"{GREEN}[PASS] curated emits: {len(emitted)} op(s) codegen emits, "
          f"{len(emitted) - len(waived)} curated and {len(waived)} waived with a recorded reason{RESET}")
    return True


@harness_test(suite="codegen")
def run_curated_closure_test():
    """M1.1's curated inlinable module: the set must be closed over exported symbols.

    `compile_ir_to_object` merges a handful of the runtime's container ops into
    the program's module as `available_externally` bodies, so the inliner can see
    through the call. That is only sound for a function whose body references
    nothing the runtime object keeps to itself: a `static` in lang_runtime.c is
    absent from that object's symbol table, so inlining a body that reads one
    produces a program referencing a symbol nothing defines.

    **The failure it exists to prevent, stated exactly.** Before `list_push` was
    split, its body read `rt_arena_hint`, `arena_depth` and `arena_alloc_slot` on
    the growth path. Curating it and forcing the inline produced:

        Undefined symbols for architecture arm64:
          "_arena_alloc_slot", referenced from: _main in program.o

    That is a reproduced failure, not a worry. It is also why `list_push_grow`
    exists and why it is exported rather than `static`: the outlined half keeps
    those three statics on the runtime's side of the split, and the half that
    gets inlined references only `list_push_grow` itself.

    **Why it cannot be left to code review.** The rule is invisible at the call
    site -- a curated op that violates it still compiles, still passes every
    value test, and fails only at link time in whatever program happens to
    inline it. `list_push` sat in violation harmlessly for a while purely because
    the inliner priced it at cost=675 against a threshold of 225 and declined
    everywhere. A refactor that shrinks a body, or a threshold that moves, is
    enough to turn that silence into somebody else's link error.

    The curated list is read out of build_driver.c rather than duplicated, for
    the reason check_source_lists.py exists: two lists that must agree will
    eventually not.
    """
    print(f"\n{BLUE}--- Running curated_closure ---{RESET}")

    driver = PROJECT_ROOT / "runtime" / "build_driver.c"
    runtime_c = PROJECT_ROOT / "runtime" / "lang_runtime.c"
    if not driver.is_file() or not runtime_c.is_file():
        print(f"{RED}[FAIL] curated closure: runtime sources not found{RESET}")
        return False

    text = driver.read_text()
    m = re.search(r"PRISMIO_CURATED_OPS\[\]\s*=\s*\{(.*?)\};", text, re.S)
    if not m:
        print(f"{RED}[FAIL] curated closure: PRISMIO_CURATED_OPS not found in build_driver.c{RESET}")
        return False
    curated = re.findall(r'"([A-Za-z0-9_]+)"', m.group(1))
    if not curated:
        print(f"{RED}[FAIL] curated closure: PRISMIO_CURATED_OPS is empty{RESET}")
        return False

    clang = which("clang")
    if not clang:
        print(f"{YELLOW}[SKIP] curated closure: clang not found{RESET}")
        return True

    with tempfile.TemporaryDirectory() as td:
        ll = Path(td) / "lang_runtime.ll"
        proc = subprocess.run(
            [clang, "-O2", "-Wno-deprecated-declarations",
             "-I", str(PROJECT_ROOT / "runtime"),
             "-S", "-emit-llvm", str(runtime_c), "-o", str(ll)],
            capture_output=True, text=True, encoding="utf-8", errors="replace")
        if proc.returncode != 0:
            print(f"{RED}[FAIL] curated closure: could not compile lang_runtime.c to IR{RESET}")
            print(proc.stderr[:600])
            return False

        ir = ll.read_text()

    # Everything the runtime keeps to itself. `internal` and `private` are the
    # two linkages that do not reach the object's symbol table.
    internal = set()
    for mm in re.finditer(r'^define\s+((?:internal|private)\s+)?[^@\n]*@"?([A-Za-z0-9_.$]+)"?\(',
                          ir, re.M):
        if mm.group(1):
            internal.add(mm.group(2))
    for mm in re.finditer(r'^@"?([A-Za-z0-9_.$]+)"?\s*=\s*((?:internal|private)\s+)?', ir, re.M):
        if mm.group(2):
            internal.add(mm.group(1))

    bodies = dict()
    for mm in re.finditer(r'^define[^\n]*@"?([A-Za-z0-9_.$]+)"?\((.*?)^\}', ir, re.M | re.S):
        bodies[mm.group(1)] = mm.group(2)

    ok = True
    for name in curated:
        body = bodies.get(name)
        if body is None:
            print(f"{RED}[FAIL] curated closure: '{name}' is curated but has no body in the runtime IR{RESET}")
            ok = False
            continue
        leaked = sorted(
            symbol for symbol in
            (set(re.findall(r'@"?([A-Za-z0-9_.$]+)"?', body)) & internal)
            if not symbol.startswith(name + ".cold.")
        )
        if leaked:
            print(f"{RED}[FAIL] curated closure: '{name}' references non-exported "
                  f"symbol(s): {', '.join(leaked)}{RESET}")
            print(f"       Inlining it emits references the runtime object does not define,")
            print(f"       and the link fails. Remove it from PRISMIO_CURATED_OPS, or give")
            print(f"       those symbols external linkage in lang_runtime.c.")
            ok = False

    if not ok:
        return False

    print(f"{GREEN}[PASS] curated closure: {len(curated)} op(s) reference only exported "
          f"symbols{RESET}")
    return True


@harness_test(suite="codegen")
def run_list_header_promotion_test():
    """A promoted header is written back before the runtime sees it.

    test_401 checks the answers. This runs the out-of-range read, whose message must carry the
    live length, which at that point exists only in a register.
    """
    print(f"\n{BLUE}--- Running list_header_promotion ---{RESET}")
    source = TEST_DIR / "test_401_list_header_promotion.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-header-promotion-") as tmp:
        exe = Path(tmp) / ("promotion.exe" if platform.system() == "Windows" else "promotion")
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(exe)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] header promotion: {built.stdout} {built.stderr}{RESET}")
            return False
        ran = subprocess.run([str(exe), "past-the-end"], capture_output=True, text=True,
                             encoding="utf-8", errors="replace")
        if ran.returncode == 0 or "index 37 is out of range for a Vec of length 37" not in ran.stderr:
            problems.append(f"past-the-end: {ran.returncode} {ran.stderr.strip()[:200]!r}")
        ran = subprocess.run([str(exe)], capture_output=True, text=True, encoding="utf-8", errors="replace")
        if ran.returncode != 0:
            problems.append(f"the program itself: {ran.stdout.strip()[:200]!r}")
    if problems:
        print(f"{RED}[FAIL] list header promotion{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] a promoted header reaches the runtime whole{RESET}")
    return True


def _function_bodies(ir):
    return {m.group(1): m.group(2) for m in re.finditer(
        r'^define [^\n]*@(\w+?)__[^\n]*\n(.*?)^}', ir, re.MULTILINE | re.DOTALL)}


@harness_test(suite="codegen")
def run_list_contents_codegen_test():
    """What a local Vec holds, a checked access says of its index, and a division `let` says of
    its dividend reach codegen, and stop where they should.

    test_402 checks the answers. The IR is read for what the facts did: `bfs`'s checksum is a
    step, its `%` and `/` by `width` unsigned, and its four neighbour accesses unchecked;
    `pushedNegative`'s and `rebound`'s `%` stay signed, `movedBase` keeps a check on the base
    that moved, and the two out-of-range programs stop with the runtime's message.
    """
    print(f"\n{BLUE}--- Running list_contents_codegen ---{RESET}")
    source = TEST_DIR / "test_402_list_contents.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-list-contents-") as tmp:
        ir_path = Path(tmp) / "contents.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] list contents IR: {built.stdout} {built.stderr}{RESET}")
            return False
        bodies = _function_bodies(ir_path.read_text())

        exe = Path(tmp) / ("contents.exe" if platform.system() == "Windows" else "contents")
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(exe)])
        if built.returncode != 0:
            problems.append(f"build failed: {built.stdout} {built.stderr}")
        else:
            for case, index, length in (("past-the-end", 16, 16), ("moved-base", 16, 16)):
                ran = subprocess.run([str(exe), case], capture_output=True, text=True,
                                     encoding="utf-8", errors="replace")
                wanted = f"index {index} is out of range for a Vec of length {length}"
                if ran.returncode == 0 or wanted not in ran.stderr:
                    problems.append(f"{case}: {ran.returncode} {ran.stderr.strip()[:200]!r}")

    bfs = bodies.get("bfs", "")
    if re.search(r'srem i32 [^,\n]+, 1000000007\b', bfs):
        problems.append("bfs: the checksum kept its remainder")
    if not re.search(r'icmp sge i32 [^,\n]+, 1000000007\b', bfs):
        problems.append("bfs: the checksum is not a one-sided step")
    if "urem i32" not in bfs or "udiv i32" not in bfs:
        problems.append("bfs: `node % width` and `node / width` are not unsigned")
    for name in ("pushedNegative", "rebound", "stored"):
        if not re.search(r'srem i32 [^,\n]+, 1009\b', bodies.get(name, "")):
            problems.append(f"{name}: a % that can see a negative element is not signed")
    if "sdiv i32" not in bodies.get("signedDividend", "") and "srem i32" not in bodies.get("signedDividend", ""):
        problems.append("signedDividend: a dividend of unknown sign lost its signed remainder")
    if problems:
        print(f"{RED}[FAIL] list contents{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] list contents and division ties reach codegen, and stop where they should{RESET}")
    return True


@harness_test(suite="codegen",
              reads=["tests/test_403_mersenne_remainder.psm"])
def run_mersenne_codegen_test():
    """`x % (2^k - 1)` is a shift, a mask and one step wherever the facts bound `x` (test_403)."""
    print(f"\n{BLUE}--- Running mersenne_codegen ---{RESET}")
    source = TEST_DIR / "test_403_mersenne_remainder.psm"
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-mersenne-") as tmp:
        ir_path = Path(tmp) / "mersenne.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(ir_path)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] mersenne IR: {built.stdout} {built.stderr}{RESET}")
            return False
        bodies = _function_bodies(ir_path.read_text())

    def reduced(name, width, divisor, shift):
        body = bodies.get(name, "")
        if re.search(rf'srem i{width} [^,\n]+, {divisor}\b', body):
            problems.append(f"{name}: kept its % {divisor}")
        if not re.search(rf'(ashr|lshr) i{width} [^,\n]+, {shift}\b', body):
            problems.append(f"{name}: no shift by {shift}")

    reduced("step", 64, 2147483647, 31)
    reduced("multiples", 64, 2147483647, 31)
    reduced("wide", 64, 2147483647, 31)
    reduced("positive", 64, 2147483647, 31)
    reduced("narrow", 32, 65535, 16)
    if "lshr i64" not in bodies.get("positive", ""):
        problems.append("positive: a dividend at zero or above looks at its sign")
    if problems:
        print(f"{RED}[FAIL] mersenne remainders{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] remainders by a Mersenne number need no multiply{RESET}")
    return True


@harness_test(suite="codegen")
def run_args_views_test():
    """`process.args[i]` is a view of `argv`, and `overwrite` checks before it writes.

    args_views_probe checks the answers, which need these four arguments. The ledger is read
    as well: a view allocates nothing, so what the program allocates is only what it kept,
    and everything it kept it released, with `argv` never reaching the deallocator.
    """
    print(f"\n{BLUE}--- Running args_views ---{RESET}")
    source = TEST_DIR / "args_views_probe.psm"
    problems = []
    arguments = ["alpha-is-a-long-argument", "bet", ""]
    with tempfile.TemporaryDirectory(prefix="prismio-args-views-") as tmp:
        exe = Path(tmp) / ("views.exe" if platform.system() == "Windows" else "views")
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(exe)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] args views: {built.stdout} {built.stderr}{RESET}")
            return False
        ran = subprocess.run([str(exe), *arguments], capture_output=True, text=True, encoding="utf-8", errors="replace")
        if ran.returncode != 0 or "PASS: argument views" not in ran.stdout:
            problems.append(f"the program: {ran.returncode} {ran.stdout.strip()[:300]!r} {ran.stderr.strip()[:200]!r}")
        checked = Path(tmp) / ("verified.exe" if platform.system() == "Windows" else "verified")
        built = run_command([str(PRISMIO_EXE), "build", str(source), "--verify", "-o", str(checked)])
        if built.returncode != 0:
            problems.append(f"--verify build: {built.stdout} {built.stderr}")
        else:
            ran = subprocess.run([str(checked), *arguments], capture_output=True, text=True, encoding="utf-8", errors="replace")
            if " 0 leaked, 0 violation(s)" not in ran.stderr + ran.stdout:
                problems.append(f"the ledger: {(ran.stderr + ran.stdout).strip()[-300:]!r}")
    if problems:
        print(f"{RED}[FAIL] args views{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] an argument is a view, and a write to one is checked first{RESET}")
    return True
