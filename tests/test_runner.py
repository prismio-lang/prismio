import argparse
import json
import platform
import re
import subprocess
import sys
import os
import tempfile
import io
import time
import threading
import contextlib
import concurrent.futures
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


PRISMIO_EXE = None


def parse_runner_args():
    parser = argparse.ArgumentParser(
        description="Run the Prismio compiler suite or selected file fixtures."
    )
    parser.add_argument(
        "patterns",
        nargs="*",
        help="fixture stem or substring, for example test_92_field_view_provenance",
    )
    parser.add_argument(
        "-k",
        "--filter",
        action="append",
        default=[],
        dest="filters",
        help="additional fixture stem or substring (repeatable)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="list file fixtures without running them",
    )
    return parser.parse_args()


def select_test_files(files, patterns):
    """Select fixtures by exact stem first, then by case-insensitive substring."""
    selected = []
    for pattern in patterns:
        key = Path(pattern).stem.lower()
        exact = [path for path in files if path.stem.lower() == key]
        matches = exact or [path for path in files if key in path.stem.lower()]
        for path in matches:
            if path not in selected:
                selected.append(path)
    return sorted(selected)


# How many test processes to run at once, and why this is safe.
#
# Every file fixture compiles to its *own* `.exe` beside the source and deletes
# it again, so two fixtures never touch the same path. The one piece of shared
# state is the object cache, and `build_driver.c` writes it to a pid-qualified
# sibling and `rename()`s it into place precisely so concurrent writers are fine
# -- see the comment above `cache_store`.
#
# Measured on this host, 202 tests: **178s sequential, 41s at 8 workers.** The
# suite was one sequential chain of ~1200 subprocess calls, and the compiler is
# single-threaded, so almost all of that was cores sitting idle.
#
# PRISMIO_TEST_JOBS=1 restores the old sequential order, which is what to reach
# for when a failure looks like it might be interference rather than a bug.
def test_jobs():
    env = os.environ.get("PRISMIO_TEST_JOBS")
    if env:
        try:
            return max(1, int(env))
        except ValueError:
            pass
    return min(8, (os.cpu_count() or 4))


_progress_lock = threading.Lock()
_progress_done = 0
_progress_total = 0


def progress(label, ok, seconds):
    """One line per finished test, in completion order, with its own duration.

    Printed under a lock because the workers share stdout. The counter is what
    makes a long run legible -- a suite that prints nothing for three minutes is
    indistinguishable from a hung one, which is how a 90-second compile hid in
    here.
    """
    global _progress_done
    with _progress_lock:
        _progress_done += 1
        n = _progress_done
    mark = f"{GREEN}ok  {RESET}" if ok else f"{RED}FAIL{RESET}"
    print(f"  [{n:3d}/{_progress_total}] {mark} {seconds:6.2f}s  {label}", flush=True)


def run_parallel(fn, items, label_of):
    """Map `fn` over `items` in a thread pool, printing each result as it lands.

    Threads rather than processes: every one of these blocks in `subprocess`, so
    the GIL is never the constraint.
    """
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=test_jobs()) as pool:
        futures = {pool.submit(_timed, fn, it): it for it in items}
        for fut in concurrent.futures.as_completed(futures):
            it = futures[fut]
            ok, seconds, out = fut.result()
            progress(label_of(it), ok, seconds)
            if out:
                sys.stdout.write(out)
            results.append(ok)
    return results


class _ThreadOut(io.TextIOBase):
    """A `sys.stdout` that routes each worker thread's writes to its own buffer.

    **`contextlib.redirect_stdout` cannot be used here and the reason is not
    obvious.** It swaps a global, so with eight workers one thread's redirect
    captures every other thread's output for as long as it is open -- and the
    unwinding is out of order, so `sys.stdout` is left pointing at a discarded
    buffer afterwards. The first parallel version of this file did exactly that:
    the run was correct and silent, printing 2 of 154 progress lines and no
    final summary, while still exiting 0.

    A thread that has set no buffer -- the main one, which prints the progress
    lines and the summary -- writes straight through.
    """

    def __init__(self, real):
        self._real = real
        self._local = threading.local()

    def set_buffer(self, buf):
        self._local.buf = buf

    def write(self, text):
        buf = getattr(self._local, "buf", None)
        return (self._real if buf is None else buf).write(text)

    def flush(self):
        buf = getattr(self._local, "buf", None)
        if buf is None:
            self._real.flush()


def _timed(fn, item):
    buf = io.StringIO()
    out = sys.stdout
    t0 = time.time()
    try:
        if isinstance(out, _ThreadOut):
            out.set_buffer(buf)
        ok = fn(item)
    except Exception as exc:                     # a crashed worker is a failure
        ok = False
        buf.write(f"    {exc}\n")
    finally:
        if isinstance(out, _ThreadOut):
            out.set_buffer(None)
    dt = time.time() - t0
    # A passing test's chatter is noise at eight workers interleaved; a failing
    # one's output is the whole point, so it is kept and printed after its line.
    return ok, dt, ("" if ok else buf.getvalue())


def run_command(cmd, capture=True):
    if capture:
        return subprocess.run(cmd, capture_output=True, text=True)
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
        if re.match(r"error(?:\[P\d{4}\])?:", line) and "aborting due to" not in line:
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


def run_corpus_test():
    """Build and *run* every benchmark corpus program.

    These were not executed by anything in CI. On 2026-08-30 an AIF solver change
    emitted a double release for a List consumed into a DataView; `g1_dataview`
    aborted in `list_release` and the entire suite still passed. The only reason
    it surfaced was that someone happened to run a benchmark.

    Building is not enough -- the failure was at run time -- so each program is
    executed and its exit status checked. `g6_engine` and `g6_engine_tuned` are
    library modules with no `main` and never link; they are skipped by name rather
    than by tolerating link failures generally. That is **three files, not two**:
    `g6_engine.psm` exists in both roots. 33 sources, 3 skipped, 30 run -- and the
    count is printed rather than asserted, because a corpus that grows should not
    need a test edit to stay green.
    """
    print(f"\n{BLUE}--- Running corpus ---{RESET}")

    NO_MAIN = {"g6_engine", "g6_engine_tuned"}
    roots = [PROJECT_ROOT / "aif" / "evidence" / "xlang" / "prismio",
             PROJECT_ROOT / "aif" / "corpus"]
    sources = sorted(p for r in roots if r.is_dir() for p in r.glob("*.psm"))
    if not sources:
        print(f"{RED}[FAIL] corpus: no programs found{RESET}")
        return False

    # `clock_gettime_nsec_np` is an Apple libc symbol. 23 of the 33 corpus
    # programs declare it to timestamp their measured loop, so those cannot link
    # anywhere but macOS -- this check ran all of them and turned a green Ubuntu
    # red. Skipped by *reading the source* for the symbol rather than by a list of
    # names, so a program that stops using it is covered again automatically, and
    # one that starts is skipped rather than failing the build.
    darwin_only = sys.platform != "darwin"

    problems = []
    ran = 0
    skipped_platform = 0
    with tempfile.TemporaryDirectory(prefix="prismio-corpus-") as temp_dir:
        # Each program already builds to its own executable in this directory,
        # so the only thing that made this sequential was the loop. Thirty
        # build-and-run pairs is the second largest block in the suite after
        # run_no_inference_test.
        def build_and_run(src):
            if src.stem in NO_MAIN:
                return ("skip_nomain", None)
            if darwin_only and "clock_gettime_nsec_np" in src.read_text(encoding="utf-8"):
                return ("skip_platform", None)
            exe = Path(temp_dir) / (src.stem + (".exe" if os.name == "nt" else ""))
            built = run_command([str(PRISMIO_EXE), "build", str(src), "-o", str(exe)])
            if built.returncode != 0:
                return ("problem", f"{src.stem}: did not build")
            out = run_command([str(exe)])
            if out.returncode != 0:
                return ("problem", f"{src.stem}: exited {out.returncode}")
            return ("ran", None)

        with concurrent.futures.ThreadPoolExecutor(max_workers=test_jobs()) as pool:
            for kind, payload in pool.map(build_and_run, sources):
                if kind == "problem":
                    problems.append(payload)
                elif kind == "ran":
                    ran += 1
                elif kind == "skip_platform":
                    skipped_platform += 1

    if problems:
        print(f"{RED}[FAIL] corpus: {len(problems)} program(s) failed{RESET}")
        for line in problems[:12]:
            print(f"  - {line}")
        return False

    note = f", {skipped_platform} skipped (macOS-only clock)" if skipped_platform else ""
    print(f"{GREEN}[PASS] corpus: {ran} programs build and run{note}{RESET}")
    return True


def run_ums_test():
    """v0.1 3.7 -- UMS manifest, dependency resolution, and the lockfile.

    `ums/test_ums.psm` has existed since UMS landed and the suite never ran it,
    so the whole manifest subsystem was unexercised in CI. It runs from the
    project root because its fixture paths are relative to that.
    """
    print(f"\n{BLUE}--- Running ums ---{RESET}")

    source = PROJECT_ROOT / "ums" / "test_ums.psm"
    if not source.exists():
        print(f"{RED}[FAIL] ums: {source} is missing{RESET}")
        return False

    with tempfile.TemporaryDirectory(prefix="prismio-ums-") as temp_dir:
        exe = Path(temp_dir) / ("ums_test.exe" if os.name == "nt" else "ums_test")
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(exe)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] ums: the test program did not build{RESET}")
            print(built.stdout or built.stderr)
            return False

        # subprocess directly rather than run_command: the fixture paths inside
        # test_ums.psm are relative to the project root, and run_command has no cwd.
        ran = subprocess.run([str(exe)], capture_output=True, text=True,
                             cwd=str(PROJECT_ROOT))
        if ran.returncode != 0 or "PASS:" not in (ran.stdout or ""):
            print(f"{RED}[FAIL] ums: manifest, resolution or lockfile assertions failed{RESET}")
            print(ran.stdout or ran.stderr)
            return False

    # Native linkage belongs to an executable target, not to a compiler-only
    # target kind. Exercise both a searched archive and an exact object path so
    # this checks the real clang command rather than only the lowered model.
    with tempfile.TemporaryDirectory(prefix="prismio-native-link-") as temp_dir:
        project = Path(temp_dir)
        native = project / "native"
        source_dir = project / "src"
        native.mkdir()
        source_dir.mkdir()

        (native / "answer.c").write_text(
            "long long prismio_native_answer(void) { return 40; }\n",
            encoding="utf-8",
        )
        (native / "bonus.c").write_text(
            "long long prismio_native_bonus(void) { return 2; }\n",
            encoding="utf-8",
        )
        (source_dir / "main.psm").write_text(
            "extern fn prismio_native_answer() -> Int\n"
            "extern fn prismio_native_bonus() -> Int\n\n"
            "fn main() -> Int {\n"
            "    if (prismio_native_answer() + prismio_native_bonus() == 42) {\n"
            "        return 0\n"
            "    }\n"
            "    return 1\n"
            "}\n",
            encoding="utf-8",
        )
        framework_link = (
            "            framework(\"Security\")\n"
            if sys.platform == "darwin" else ""
        )
        (project / "build.ums").write_text(
            "project { name = \"native-link\" version = \"0.1.0\" prismio = \"0.1\" }\n"
            "targets {\n"
            "    executable(\"native-link\") {\n"
            "        entry = \"src/main.psm\"\n"
            "        link {\n"
            "            search(\"native\")\n"
            "            library(\"answer\")\n"
            "            file(\"native/bonus.o\")\n"
            + framework_link +
            "        }\n"
            "    }\n"
            "}\n",
            encoding="utf-8",
        )

        clang = shutil.which("clang")
        archiver = shutil.which("llvm-ar") or shutil.which("ar")
        if not clang or not archiver:
            print(f"{RED}[FAIL] ums: clang and an archive tool are required{RESET}")
            return False
        answer_object = native / "answer.o"
        bonus_object = native / "bonus.o"
        answer_archive = native / "libanswer.a"
        native_steps = [
            [clang, "-c", str(native / "answer.c"), "-o", str(answer_object)],
            [archiver, "rcs", str(answer_archive), str(answer_object)],
            [clang, "-c", str(native / "bonus.c"), "-o", str(bonus_object)],
        ]
        for command in native_steps:
            step = subprocess.run(command, capture_output=True, text=True)
            if step.returncode != 0:
                print(f"{RED}[FAIL] ums: native link fixture setup failed{RESET}")
                print(step.stdout or step.stderr)
                return False

        native_build = subprocess.run(
            [str(PRISMIO_EXE), "build"], capture_output=True, text=True,
            cwd=str(project),
        )
        native_exe = project / ".prismio" / "build" / "debug" / "native-link"
        if native_build.returncode != 0 or not native_exe.exists():
            print(f"{RED}[FAIL] ums: declared native inputs did not link{RESET}")
            print(native_build.stdout or native_build.stderr)
            return False
        native_run = subprocess.run([str(native_exe)], capture_output=True, text=True)
        if native_run.returncode != 0:
            print(f"{RED}[FAIL] ums: native-linked executable returned the wrong result{RESET}")
            print(native_run.stdout or native_run.stderr)
            return False

    # Prismio is itself described by the repository's build.ums. A user-facing
    # binary is named `prismio`; named bootstrap generations deliberately do not
    # redirect, so copy the tested generation under its launcher name here.
    # The first build has no host and therefore runs under stage 0. The second
    # must forward the complete command before the local host parses build.ums.
    #
    # Build from a descendant directory to cover upward discovery and,
    # crucially, executable("prismio")'s backend component/LLVM link path. A
    # model-only assertion cannot cover whether that component really links.
    compiler_artifact = PROJECT_ROOT / ".prismio" / "build" / "debug" / "prismio"
    compiler_candidate = compiler_artifact.with_name(compiler_artifact.name + ".next")
    if compiler_artifact.exists():
        compiler_artifact.unlink()
    if compiler_candidate.exists():
        compiler_candidate.unlink()

    with tempfile.TemporaryDirectory(prefix="prismio-launcher-") as launcher_dir:
        launcher = Path(launcher_dir) / ("prismio.exe" if os.name == "nt" else "prismio")
        shutil.copy2(PRISMIO_EXE, launcher)

        project_build = subprocess.run(
            [str(launcher), "build"], capture_output=True, text=True,
            cwd=str(PROJECT_ROOT / "ums"),
        )
        if (project_build.returncode != 0 or not compiler_artifact.exists()
                or "compiler host: stage-0" not in project_build.stdout):
            print(f"{RED}[FAIL] ums: stage 0 did not build the first project host{RESET}")
            print(project_build.stdout or project_build.stderr)
            return False

        local_build = subprocess.run(
            [str(launcher), "build"], capture_output=True, text=True,
            cwd=str(PROJECT_ROOT / "ums"),
        )
        if (local_build.returncode != 0
                or "compiler host: project-local" not in local_build.stdout
                or "staged project compiler:" not in local_build.stdout
                or "promoted project compiler:" not in local_build.stdout):
            print(f"{RED}[FAIL] ums: the complete build command was not hosted{RESET}")
            print(local_build.stdout or local_build.stderr)
            return False

        forwarded_version = subprocess.run(
            [str(launcher), "--version"], capture_output=True, text=True,
            cwd=str(PROJECT_ROOT),
        )
        if (forwarded_version.returncode != 0
                or "compiler host: project-local" not in forwarded_version.stdout
                or "prismio 0.1.0" not in forwarded_version.stdout):
            print(f"{RED}[FAIL] ums: a non-build command was not forwarded to the host{RESET}")
            print(forwarded_version.stdout or forwarded_version.stderr)
            return False

        # A direct local invocation has no global parent waiting to promote its
        # sibling candidate, so it must fail rather than overwrite itself.
        self_build = subprocess.run(
            [str(compiler_artifact), "build"], capture_output=True, text=True,
            cwd=str(PROJECT_ROOT),
        )
        if self_build.returncode == 0 or "P1051" not in (self_build.stdout + self_build.stderr):
            print(f"{RED}[FAIL] ums: a project compiler tried to replace itself{RESET}")
            print(self_build.stdout or self_build.stderr)
            return False

        # A corrupt active generation falls back to stage 0 rather than becoming
        # a permanent dead end. The command is not replayed after a host failure;
        # fallback happens only because the preflight could not start the host.
        compiler_artifact.write_bytes(b"not a Prismio compiler\n")
        fallback_build = subprocess.run(
            [str(launcher), "build"], capture_output=True, text=True,
            cwd=str(PROJECT_ROOT),
        )
        fallback_output = fallback_build.stdout + fallback_build.stderr
        if (fallback_build.returncode != 0 or "P1052" not in fallback_output
                or "compiler host: stage-0" not in fallback_output):
            print(f"{RED}[FAIL] ums: a broken project compiler did not fall back to stage 0{RESET}")
            print(fallback_output)
            return False

        clean = subprocess.run(
            [str(launcher), "clean"], capture_output=True, text=True,
            cwd=str(PROJECT_ROOT / "ums"),
        )
        if (clean.returncode != 0 or compiler_artifact.exists()
                or "compiler host: project-local" not in clean.stdout):
            print(f"{RED}[FAIL] ums: hosted clean did not remove the compiler after it exited{RESET}")
            print(clean.stdout or clean.stderr)
            return False

    print(f"{GREEN}[PASS] ums: manifest lowering, validation, build planning, "
          f"native linkage, host routing, dependency resolution and the lockfile{RESET}")
    return True


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
        problems.append("Tree reaches itself through List<Tree>, but the "
                        "cyclicity report does not say so")

    if problems:
        print(f"{RED}[FAIL] tier assignment changed{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] AIF assigns every SPEC 4.2 clause its expected tier{RESET}")
    return True


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
                       "std.io:", "unique heap", "returned to the caller",
                       "--why=<ID>", "--manifest"):
            if wanted not in text:
                problems.append(f"default report does not contain {wanted!r}")
        if "aif-manifest 1" in text:
            problems.append("default report still prints the compiler manifest")
        if "prismioStdIo" in text:
            problems.append("default report exposes mangled stdlib symbols")
        if "/stdlib/" in text:
            problems.append("default report exposes the installed stdlib path")

    why = run_command([str(PRISMIO_EXE), "aif", str(fixture), "--why=1"])
    if why.returncode != 0:
        problems.append(f"numeric --why exited {why.returncode}")
    else:
        for wanted in ("Allocation 1", "Storage    unique heap",
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


def run_elem_mode_agreement_test():
    """The element-ownership mode is one wire protocol with three definitions.

    Codegen emits the mode from `AIF_ELEM_*` in src/ir/context.psm, the analysis
    answers with `AIF_ELEM_*` in runtime/aif_support.c, and the runtime compares
    against `AIF_ELEM_*` in runtime/lang_runtime.c. The int crosses two seams and
    is never re-derived, so all three have to agree on every name *and* every
    value, forever.

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
        "src/ir/context.psm":        r"let\s+AIF_ELEM_([A-Z_]+)\s*=\s*(\d+)",
        "runtime/aif_support.c":     r"#define\s+AIF_ELEM_([A-Z_]+)\s+(\d+)",
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
                            f"which puts the third definition back out of grep "
                            f"range of the other two")

    if problems:
        print(f"{RED}[FAIL] the three element-mode tables disagree -- elements "
              f"will be released with the wrong deallocator{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] all {len(reference)} element modes agree across "
          f"src/ir/context.psm, aif_support.c and lang_runtime.c{RESET}")
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

    # `strEquals` returns Bool, so the C-era `== 1` is gone. This scraper is the
    # thing the check depends on seeing, so when the compiler moved off the C
    # string layer in 2026-08 this pattern stopped matching and the check
    # correctly reported itself blind rather than passing on an empty set.
    produces = set(re.findall(
        r'strEquals\(name,\s*"([a-z_0-9]+)"\)\)\s*\{\s*return true\s*\}', contracts))
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
    exe = TEST_DIR / "test_58_region_serves.exe"
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
                            capture_output=True, text=True, env=env)
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
        mutant = TEST_DIR / ".prismio-placement-pin-mutant.psm"
        # A call *outside* the region, with its result discarded. Outside because
        # regime (a) now permits a second call inside one -- test_63 already has
        # one, and it is served. Discarded because a binding out here would hold
        # the loop's sites as well and obligation 3 would reject the mutant for a
        # reason that has nothing to do with regime (a).
        mutant.write_text(
            source.replace(marker, "    bracketed_make(99)"),
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

    **The bootstrap is done with `-g`**, which costs about a second and buys two
    things a separate test would pay a whole second bootstrap for again. First,
    the flag reaches this command at all: `build` and `run` parsed it and
    `bootstrap` did not, so the largest Prismio program in existence was the one
    that could not be stepped through. Second, and this is the assertion with
    teeth, the compiler built *with* `-g` must still emit byte-identical IR --
    debug info describes a program, it does not change one, and a `-g` build that
    compiled differently would be a different compiler.

    On Mach-O the `.dSYM` is checked too, because the executable carries only a
    debug map and the DWARF it points at is in an object file the build deletes.
    `compiler_build_executable` ran dsymutil before that delete and
    `compiler_bootstrap_executable` did not, so `bootstrap -g` emitted every byte
    of the metadata and then threw away the half describing Prismio code.
    """
    print(f"\n{BLUE}--- Running bootstrap_command ---{RESET}")
    problems = []

    with tempfile.TemporaryDirectory(prefix="prismio-bootstrap-cmd-") as wd:
        built = Path(wd) / "selfbuilt"
        r = subprocess.run([str(Path(PRISMIO_EXE).resolve()), "bootstrap",
                            str(TEST_DIR.parent / "src" / "main.psm"), "-o", str(built),
                            "-g"],
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

            # **A compiler that links and cannot JIT is the disagreement this
            # test exists to make loud.** Two places know how to link a compiler
            # -- this command and tools/bootstrap.{sh,ps1} -- and on Windows they
            # need different things for ORC to reach the runtime: a COFF
            # executable exports nothing, so the script builds an export table
            # from the objects and the driver had to learn to do the same. The IR
            # comparison above cannot see that, because such a compiler compiles
            # correctly and fails only when asked to *run* something.
            #
            # The same fixture, so no second program has to be kept in step, and
            # a string-heavy one at that: `--jit` resolves the runtime out of the
            # compiler process, so every allocation crosses the seam and every
            # release has to come back to the same allocator. It must be run from
            # the repo, because a compiler in a temp directory resolves `std/`
            # relative to the source it is given.
            j = run_command([str(built), "run", str(fixture), "--jit"])
            if j.returncode != 0 or "PASS: strings" not in (j.stdout or ""):
                problems.append(
                    f"the compiler `prismio bootstrap` built cannot `run --jit` "
                    f"(exit {j.returncode}): "
                    + elide_middle((j.stdout or "") + (j.stderr or "")))

            if sys.platform == "darwin":
                if not Path(str(built) + ".dSYM").is_dir():
                    problems.append("`bootstrap -g` produced no .dSYM: on Mach-O the "
                                    "executable carries a debug map and the DWARF it "
                                    "points at is in the program object, which the "
                                    "build deletes -- so the metadata was emitted and "
                                    "then thrown away")
            else:
                print(f"  (no .dSYM check: only Mach-O keeps DWARF outside the binary)")

    # `-g` has to be named in the guard that decides whether argument 2 is the
    # source path, or `prismio bootstrap -g` compiles a file called `-g`. Run
    # where `src/main.psm` cannot resolve, so the two outcomes are told apart by
    # *which* path is reported missing and neither one builds anything.
    with tempfile.TemporaryDirectory(prefix="prismio-bootstrap-flag-") as wd:
        r = subprocess.run([str(Path(PRISMIO_EXE).resolve()), "bootstrap", "-g",
                            "-o", str(Path(wd) / "out")],
                           capture_output=True, text=True, cwd=wd)
        said = ((r.stdout or "") + (r.stderr or ""))
        if r.returncode == 0:
            problems.append("`prismio bootstrap -g` succeeded in a directory with no "
                            "`src/main.psm`, so it built something other than the "
                            "default source")
        elif "cannot read -g" in said:
            problems.append("`prismio bootstrap -g` reports `-g` as the missing source: "
                            "the flag was taken for the source path")
        elif "cannot read src/main.psm" not in said:
            problems.append("`prismio bootstrap -g` failed for a reason this test did "
                            f"not expect, so it is not checking the guard: {said.strip()[:120]}")

    if problems:
        print(f"{RED}[FAIL] `prismio bootstrap` does not build a working compiler{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] `prismio bootstrap -g` builds a debuggable compiler whose "
          f"IR matches this one's{RESET}")
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
            released_by_cut[cut] = int(ledger.group(2))
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
                f"forced split released {gap} more objects than forced unsplit, "
                f"expected exactly {expected_gap} -- one cold block per body. "
                f"A force that only moved the manifest would read 0 here.")

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


def run_slice_gate_test():
    """M4.1's discriminating representation, lifetime, and bounds gate."""
    print(f"\n{BLUE}--- Running slice_gate ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_79_slices.psm"
    out = TEST_DIR / "t79_slices.ll"
    result = run_command([str(PRISMIO_EXE), "build", str(fixture), "-o", str(out)])
    if result.returncode != 0:
        problems.append(f"test_79 IR build exited {result.returncode}: "
                        f"{result.stdout or result.stderr}")
    else:
        ir = out.read_text(encoding="utf-8", errors="replace")
        if not re.search(r"%prismio\.slice(?:\.\d+)? = type \{ ptr, i32, i32 \}", ir):
            problems.append("Slice is not emitted as { handle, offset, length }")
        for symbol in ("prismio_slice_check", "list_slice_get_inline",
                       "list_slice_set_inline", "list_slice_get"):
            if not re.search(rf"call [^\n]*@{symbol}\b", ir):
                problems.append(f"test_79 does not exercise @{symbol}")
    cleanup_files(out)

    escape = TEST_DIR / "fixture_slice_escape.psm"
    escape_ir = TEST_DIR / "t79_slice_escape.ll"
    escape_exe = TEST_DIR / "fixture_slice_escape.exe"
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
    bounds_exe = TEST_DIR / "fixture_slice_bounds.exe"
    result = run_command([str(PRISMIO_EXE), "build", str(bounds), "-o", str(bounds_exe)])
    if result.returncode != 0:
        problems.append(f"slice bounds fixture build exited {result.returncode}")
    else:
        ran = run_command([str(bounds_exe)])
        if ran.returncode == 0:
            problems.append("an out-of-range Slice was accepted")
        if "slice range [0..2] is outside collection length 1" not in ran.stderr:
            problems.append("the Slice bounds failure did not name the range and length")
    cleanup_files(bounds_exe)

    if problems:
        print(f"{RED}[FAIL] first-class Slice invariants are not all enforced{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False

    print(f"{GREEN}[PASS] Slice is handle-based, growth-safe, range-checked, "
          f"and covered by E-VIEW{RESET}")
    return True


def run_data_view_gate_test():
    """M4.3's real-column, mutable round-trip, alias, and release gate."""
    print(f"\n{BLUE}--- Running data_view_gate ---{RESET}")
    problems = []
    fixture = TEST_DIR / "test_80_data_view_conversion.psm"
    out = TEST_DIR / "t80_data_view.ll"
    exe = TEST_DIR / "test_80_data_view_verify.exe"
    drop_fixture = TEST_DIR / "test_81_data_view_drop.psm"
    drop_exe = TEST_DIR / "test_81_data_view_drop_verify.exe"

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


def run_generic_layout_specialization_test():
    """M4.4: generic clones choose storage only after T is concrete."""
    print(f"\n{BLUE}--- Running generic_layout_specialization_gate ---{RESET}")
    problems = []
    fixture = TEST_DIR / "test_82_generic_layout.psm"
    out = TEST_DIR / "t82_generic_layout.ll"
    exe = TEST_DIR / "test_82_generic_layout_verify.exe"

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


# ---------------------------------------------------------------------------
# Cross-compilation
# ---------------------------------------------------------------------------

def _target_di_member_bit(ir, struct_name, field):
    """The bit offset DWARF gives one member of one composite, or None."""
    nodes = _di_nodes(ir)
    members, _ = _di_composite(nodes, struct_name)
    if members is None:
        return None
    for name, offset, _size in members:
        if name == field:
            return offset
    return None


def run_target_test():
    """`--target`, checked on the four things it can get wrong silently.

    `--target wasm32` used to exist and build *nothing*: `Isize`/`Usize` lowered
    to i32 in codegen while `ast.types` told sema they were i64, so std.io's
    `value as U64` was a cast between two equal keys -- which emits nothing --
    and every program failed LLVMVerifyModule on a 32-bit value handed to a
    64-bit parameter. That is the shape of failure this test exists for: sema and
    codegen quietly disagreeing about what the target is.

      1. *An unnamed target stamps nothing.* The host case must emit the module
         it emitted before targets existed. A stray unconditional stamp would
         move every program's IR at once.
      2. *A named target reaches the module*, triple and data layout both, from
         LLVM rather than from a table anyone can mistype.
      3. *Pointer width follows the target, in sema as well as codegen.* On
         wasm32 the allocator takes an i32 and the widening cast in std.io is
         real, so it appears in the IR. Either half alone is a miscompile.
      4. *`-g` reads member offsets from the target, not the host.* A
         pointer-width `Usize` after an `Int` sits at bit 64 on a 64-bit target
         and at bit 32 on wasm32, and the `String` behind it follows at bit 128
         or bit 64. Getting this from the host is the exact bug the DWARF
         layer's data-layout pin was built to prevent, and cross-compilation is
         the case that can reintroduce it.

         Both members are checked because each can go stale in the way the
         String already did: when a String was one pointer it carried this
         assertion alone, and the fat `{ptr, i64}` -- 16 bytes and 8-aligned
         everywhere -- made host and wasm32 agree on its offset, so the check
         passed without being able to fail. Whatever a member's own width does,
         the two targets have to disagree about where it sits.

    Plus the object cache, where sharing one object between two targets is
    silent: the same source and the same -D flags, a different triple.

    A real cross *link* is checked only where this host can run the result --
    arm64 macOS, where x86_64 runs under Rosetta. Everywhere else the IR-level
    assertions above still run, and the link is reported as skipped rather than
    passed.
    """
    print(f"\n{BLUE}--- Running target_cross ---{RESET}")
    source = TEST_DIR / "target_cross.psm"
    host_ll = TEST_DIR / "target_host.ll"
    wasm_ll = TEST_DIR / "target_wasm.ll"
    host_g = TEST_DIR / "target_host_g.ll"
    wasm_g = TEST_DIR / "target_wasm_g.ll"
    problems = []

    builds = ((host_ll, []),
              (wasm_ll, ["--target", "wasm32-unknown-unknown"]),
              (host_g, ["-g"]),
              (wasm_g, ["-g", "--target", "wasm32-unknown-unknown"]))
    for out, extra in builds:
        result = run_command([str(PRISMIO_EXE), "build", str(source),
                              "-o", str(out)] + extra)
        if result.returncode != 0:
            print(f"{RED}[FAIL] build {' '.join(extra) or '(host)'} exited "
                  f"{result.returncode}{RESET}")
            print(result.stdout or result.stderr)
            cleanup_files(host_ll, wasm_ll, host_g, wasm_g)
            return False

    host_ir = host_ll.read_text(encoding="utf-8", errors="replace")
    wasm_ir = wasm_ll.read_text(encoding="utf-8", errors="replace")
    host_g_ir = host_g.read_text(encoding="utf-8", errors="replace")
    wasm_g_ir = wasm_g.read_text(encoding="utf-8", errors="replace")
    cleanup_files(host_ll, wasm_ll, host_g, wasm_g)

    # 1. The host stamps nothing -- **except the Windows triple, which is
    #    deliberate and has to be asserted rather than forbidden.**
    #
    # On macOS and Linux LLVM's own host triple is a better answer than a guess,
    # so an implicit-host build emits neither marker and clang fills its default
    # in. Windows is a real fork -- msvc and mingw are different ABIs and msvc is
    # the configuration this project verifies -- so ir_module_start pins
    # `x86_64-pc-windows-msvc` there and has since before this matrix ever ran.
    #
    # This check was written on a platform where that branch does not exist and
    # asserted "stamps nothing" everywhere, so the first green Windows run
    # reported the pin as a defect. Asserting it from both sides instead: absent
    # off Windows, present *and correct* on it, so the pin cannot silently
    # disappear either. The datalayout is never stamped on any host -- only
    # LLVMSetTarget is called in that branch.
    if platform.system() == "Windows":
        if 'target triple = "x86_64-pc-windows-msvc"' not in host_ir:
            problems.append("a host build on Windows did not pin "
                            "`x86_64-pc-windows-msvc` -- without it clang may pick "
                            "the mingw fork, which is a different ABI")
        if "target datalayout" in host_ir:
            problems.append("a host build emitted `target datalayout`; only the "
                            "triple is pinned on Windows")
    else:
        for marker in ("target triple", "target datalayout"):
            if marker in host_ir:
                problems.append(f"a build with no --target emitted `{marker}` -- the "
                                "implicit host is stamping the module, which moves "
                                "the IR of every program at once")

    # 2. A named target reaches the module, both halves.
    if 'target triple = "wasm32-unknown-unknown"' not in wasm_ir:
        problems.append("--target wasm32-unknown-unknown did not put its triple "
                        "on the module")
    if not re.search(r'^target datalayout = "e-m:e-p:32:32', wasm_ir, re.M):
        problems.append("--target wasm32-unknown-unknown did not put a 32-bit "
                        "data layout on the module")

    # 3. Pointer width, in both halves of the compiler.
    if "declare ptr @malloc(i32)" not in wasm_ir:
        problems.append("the allocator still takes a 64-bit size on wasm32 -- "
                        "codegen is not reading the target's pointer width")
    if "declare ptr @malloc(i64)" not in host_ir:
        problems.append("the allocator does not take a 64-bit size on the host")
    if not re.search(r"= (zext|sext) i32 %\d+ to i64", wasm_ir):
        problems.append("no widening cast in the wasm32 module: sema still "
                        "believes Isize/Usize are 64-bit while codegen emits 32, "
                        "so `value as U64` in std.io compiled to nothing. This is "
                        "exactly how --target wasm32 used to build nothing at all")

    # 4. -g offsets come from the target.
    #
    # Recomputed from the struct each build actually emitted rather than compared
    # against fixed numbers. The layout search is free to order `Mixed`'s fields
    # however it likes -- and it orders the two targets *differently*, because
    # `Usize` is a different size on each -- so a hardcoded offset is a statement
    # about the search, which this test is not for. What it is for is that the
    # DWARF offsets agree with the target's own data layout applied to the type
    # in that module.
    seen = {}
    for ir, label, ptr_bits in ((host_g_ir, "host", 64), (wasm_g_ir, "wasm32", 32)):
        seen[label] = {}
        for sname in ("Mixed", "Span"):
            members, total = _di_composite(_di_nodes(ir), sname)
            elements = _emitted_struct(ir, sname)
            if members is None or not elements:
                problems.append(f"no DWARF composite or no emitted `%{sname}` in "
                                f"the {label} -g build, so the offset half of "
                                "this test did not run")
                continue
            want_offsets, want_total = _expected_layout(elements, ptr_bits)
            if want_offsets is None or len(want_offsets) != len(members):
                problems.append(f"could not recompute `{sname}`'s layout from the "
                                f"emitted `{elements}` in the {label} build -- "
                                "this half of the test stopped checking offsets")
                continue
            seen[label][sname] = [off for _, off, _ in members]
            for (fname, got, _), want in zip(members, want_offsets):
                if got != want:
                    problems.append(f"`{sname}.{fname}` is described at bit {got} "
                                    f"in the {label} -g build and belongs at "
                                    f"{want} -- the member offsets came from the "
                                    "wrong data layout, which is a debugger "
                                    "confidently reading the wrong bytes")
            if total != want_total:
                problems.append(f"`{sname}` is described as {total} bits in the "
                                f"{label} -g build and computes to {want_total}")

    # And that comparison has to be one that could have failed. Reading the host
    # layout for both targets is the bug being guarded against, so if the two
    # agree everywhere the check passes without touching it. That is not
    # hypothetical: it is what happened when `String` went from one pointer to a
    # pair, which is 16 bytes and 8-aligned on both targets.
    if seen.get("host") and seen["host"] == seen.get("wasm32"):
        problems.append(f"every member sits at {seen['host']} on both targets, so "
                        "these offsets cannot distinguish the target's data "
                        "layout from the host's -- the fixture needs a member "
                        "whose offset moves with pointer width")

    # 5. An unknown triple is refused rather than silently ignored.
    bad = run_command([str(PRISMIO_EXE), "build", str(source),
                       "--target", "not-a-real-triple", "-o", str(host_ll)])
    cleanup_files(host_ll)
    if bad.returncode == 0:
        problems.append("`--target not-a-real-triple` was accepted; a target the "
                        "compiler cannot resolve must not produce a binary")
    elif "unknown target triple" not in (bad.stdout or "") + (bad.stderr or ""):
        problems.append("an unresolvable triple was rejected for the wrong reason")

    # 6. Two targets must not share one cached object.
    with tempfile.TemporaryDirectory() as cache:
        env = dict(os.environ, PRISMIO_OBJ_CACHE_DIR=cache,
                   PRISMIO_OBJ_CACHE_TRACE="1")
        exe = TEST_DIR / ("target_cache" + (".exe" if os.name == "nt" else ""))
        seen = []
        for extra in ([], ["--target", "wasm32-unknown-unknown"]):
            r = subprocess.run([str(PRISMIO_EXE), "build", str(source),
                                "-o", str(exe)] + extra,
                               capture_output=True, text=True, env=env)
            seen.append(r.stderr or "")
        cleanup_files(exe)
        # The host build populates the cache; the cross build must miss it. A hit
        # there means one object is being served to two targets, which links and
        # then misbehaves.
        if "[objcache miss] lang_runtime" not in seen[0]:
            problems.append("the host build did not populate an empty object "
                            "cache, so the sharing half of this test did not run")
        elif "[objcache hit] lang_runtime" in seen[1]:
            problems.append("a cross build reused the host's cached runtime "
                            "object: the object cache key does not include the "
                            "target, and two targets are sharing one object")

    # 7. The real thing, where this host can run the result.
    linked = "not attempted on this host"
    if sys.platform == "darwin" and platform.machine() == "arm64":
        sdk = run_command(["xcrun", "--show-sdk-path"])
        if sdk.returncode == 0 and sdk.stdout.strip():
            exe = TEST_DIR / "target_x86"
            built = run_command([str(PRISMIO_EXE), "build", str(source),
                                 "--target", "x86_64-apple-macos",
                                 "--sysroot", sdk.stdout.strip(), "-o", str(exe)])
            if built.returncode != 0:
                problems.append("a cross build for x86_64-apple-macos failed: "
                                + (built.stdout or built.stderr or "").strip())
            else:
                kind = run_command(["file", str(exe)]).stdout
                if "x86_64" not in kind:
                    problems.append(f"the cross build produced {kind.strip()!r} "
                                    "rather than an x86_64 binary")
                ran = run_command([str(exe)])
                if ran.returncode != 0 or "cross" not in (ran.stdout or ""):
                    problems.append("the cross-built binary did not run: "
                                    f"exit {ran.returncode}, "
                                    f"stdout {(ran.stdout or '').strip()!r}")
                else:
                    linked = "x86_64-apple-macos built and ran"
            cleanup_files(exe)

    # 7b. The data layout we stamp must be the one clang computes for the same
    # target.
    #
    # This is what `-Woverride-module` is *for*, and it is suppressed in
    # compile_ir_to_object because it could never do the job: the clang driver
    # always compiles for the SDK's deployment target
    # (arm64-apple-macosx26.0.0) while a module carries at most LLVM's default
    # triple (arm64-apple-darwin25.5.0), so it fired on literally every macOS
    # build -- including, measured, a module with no triple at all. A warning
    # nobody can act on and everybody scrolls past is worth less than this.
    #
    # The triple is deliberately *not* compared, because the two forms name one
    # machine and never match textually. The data layout is the half with teeth:
    # it is what `-g` member offsets and every size in the AIF model are derived
    # from, and a disagreement there is an ABI disagreement.
    layouts = "not attempted on this host"
    if which("clang"):
        def clang_layout(extra):
            r = subprocess.run(["clang"] + extra + ["-S", "-emit-llvm", "-x", "c",
                                                    "-", "-o", "-"],
                               input="", capture_output=True, text=True)
            m = re.search(r'target datalayout = "([^"]*)"', r.stdout or "")
            return m.group(1) if m else None

        def ours(ir):
            m = re.search(r'target datalayout = "([^"]*)"', ir)
            return m.group(1) if m else None

        checked = 0
        for label, ir, extra in (("host", host_g_ir, []),
                                 ("wasm32", wasm_g_ir,
                                  ["--target=wasm32-unknown-unknown"])):
            theirs = clang_layout(extra)
            mine = ours(ir)
            if theirs is None:
                continue
            if mine is None:
                problems.append(f"a -g build for {label} stamped no data layout, "
                                "so -g offsets are being computed against nothing")
            elif mine != theirs:
                problems.append(f"for {label} the module stamps data layout "
                                f"{mine!r} and clang compiles it as {theirs!r}: "
                                "the target this compiler describes and the one "
                                "clang codegens for disagree about the ABI")
            else:
                checked += 1
        layouts = f"{checked} target(s) agree with clang"
        if checked == 0:
            problems.append("neither data layout could be compared against "
                            "clang, so the check that replaced "
                            "-Woverride-module did not run")

    # 8. The AIF layout model must follow the target too, not just codegen.
    #
    # `aifTypeBytes` sizes a String field, a reference edge and an `Isize` from
    # the target, and hardcoded **8** for `[T]` and `List<T>` -- with the comment
    # "both a pointer to elements held elsewhere" sitting directly above the
    # literal. On wasm32 a pointer is four bytes, so every container field was
    # modelled at twice its width, and Theta_stack is what decides T0.
    #
    # The assertion is differential rather than absolute: three `List<T>` fields
    # and three `String` fields are three pointers either way, so the two structs
    # must model the same size on any one target. String was already correct, so
    # this compares the suspect path against a known-good one in the same
    # function and needs no magic number of its own. It also requires the wasm32
    # figure to be *smaller* than the host's, which is what stops both paths
    # being wrong in the same direction.
    with tempfile.TemporaryDirectory(prefix="prismio-ptr-width-") as tmp:
        probe = Path(tmp) / "widths.psm"
        probe.write_text("import std.io\n"
                         "\n"
                         "struct OfList { a: List<Int>, b: List<Int>, c: List<Int> }\n"
                         "struct OfArray { a: [Int], b: [Int], c: [Int] }\n"
                         "struct OfString { a: String, b: String, c: String }\n"
                         "\n"
                         "fn main() -> Int {\n"
                         "    let x = OfList { a: list_new(), b: list_new(), c: list_new() }\n"
                         "    let y = OfArray { a: [1], b: [2], c: [3] }\n"
                         "    let z = OfString { a: \"p\", b: \"q\", c: \"r\" }\n"
                         "    println(1)\n"
                         "    return 0\n"
                         "}\n")

        def modelled(extra):
            r = run_command([str(PRISMIO_EXE), "aif", str(probe), "--layout"] + extra)
            if r.returncode != 0:
                return None
            out = {}
            for line in (r.stdout or "").splitlines():
                parts = line.split()
                # "  <type> <fields> <trav> <candidate...> <hotB> <coldB> ..."
                if len(parts) >= 6 and parts[0].startswith("Of") and "unsplit" in line:
                    hot = [p for p in parts if p.isdigit()]
                    if len(hot) >= 3:
                        out[parts[0]] = int(hot[2])
            return out

        host = modelled([])
        wasm = modelled(["--target", "wasm32-unknown-unknown"])
        if not host or not wasm:
            problems.append("`prismio aif --layout` produced no sizes for the "
                            "pointer-width probe, so the layout half of this "
                            "test did not run")
        else:
            for name in ("OfList", "OfArray"):
                if name not in host or name not in wasm or "OfString" not in wasm:
                    problems.append(f"{name} or OfString is missing from the "
                                    "layout table")
                elif wasm[name] != wasm["OfString"]:
                    problems.append(f"on wasm32 {name} models {wasm[name]} bytes "
                                    f"where three String fields model "
                                    f"{wasm['OfString']}: a container field is a "
                                    "pointer and is not being sized from the "
                                    "target")
                elif wasm[name] >= host[name]:
                    problems.append(f"{name} models {wasm[name]} bytes on wasm32 "
                                    f"and {host[name]} on the host: a 32-bit "
                                    "target must make a struct of pointers "
                                    "smaller, not the same or larger")

    if problems:
        print(f"{RED}[FAIL] --target{RESET}")
        for p in problems:
            print(f"  - {p}")
        return False

    print(f"{GREEN}[PASS] --target: triple and layout from LLVM, pointer width "
          f"agreed by sema and codegen, -g offsets from the target, cache keyed "
          f"per target, container fields sized from the target; layout vs clang: "
          f"{layouts}; link: {linked}{RESET}")
    return True


def run_incremental_manifest_test():
    """INFERENCE 9's required check: an incremental result must equal a cold one.

    `tools/incremental_manifest.py` is the check INFERENCE 9 asks for. The spec
    permits reusing a per-function inference summary across a rebuild and then
    says an implementation SHOULD verify that doing so changes no answer,
    "because summary-cache bugs are silent and produce wrong-tier binaries rather
    than crashes". The script applies four edits to one file and requires the
    manifests to be discriminating, reversible and budget-sensitive.

    It is called from here for the same reason `run_runtime_library_test` calls
    `tools/verify_separation.*`, and it is the second script found in the same
    state: **nothing called it, and all three of its program templates stopped
    compiling the day `std.io` stopped being a prelude.** A required check that
    nobody runs is not coverage, and two of them broke on one day without a
    single failure anywhere. It costs about 150 ms.
    """
    print(f"\n{BLUE}--- Running incremental_manifest ---{RESET}")
    script = PROJECT_ROOT / "tools" / "incremental_manifest.py"
    r = subprocess.run([sys.executable, str(script),
                        "--compiler", str(Path(PRISMIO_EXE).resolve())],
                       capture_output=True, text=True, cwd=str(PROJECT_ROOT))
    said = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0 or "OK" not in said:
        print(f"{RED}[FAIL] incremental manifest{RESET}")
        print("  - " + (said.strip()[-500:] or f"exit {r.returncode}"))
        return False

    print(f"{GREEN}[PASS] incremental manifest: cold and incremental agree, "
          f"discriminating, reversible and budget-sensitive{RESET}")
    return True


def run_jit_test():
    """`prismio run --jit`: the same program, without clang and without a link.

    `run` otherwise compiles the module to an object, links an executable,
    executes it and deletes it. The module is already in memory, so `--jit` hands
    it to LLJIT and calls `main` in this process instead. Measured on this host
    for a small program: **10-20 ms against 220-530 ms**, which is the whole
    argument for it.

    It is an *execution* path, not an emission path -- codegen is not told the
    JIT exists -- so the assertion with real teeth is the first one: what the JIT
    runs must be indistinguishable from what a build of the same source produces.

    Six assertions:

      1. *Same output, same status.* `run --jit` and `run` are compared on
         stdout and exit code for one program. A JIT that ran a different module,
         resolved a different runtime, or lost a write would show here.
      2. *`cli_arg_count()` reports the program's arguments, not the compiler's.*
         **This is the trap the design note in ir_jit_run_main is about.**
         Generated code *defines* `@prismio_argc`, so the jitted module holds its
         own copy while the runtime shims linked into this process read the
         compiler's -- which holds `prismio run --jit prog.psm`. Without the host
         globals being set, a jitted program asking for its arguments is quietly
         told about the compiler's command line. The fixture prints the count and
         both paths must say 1.
      3. *A failing program fails the same way.* Same exit status and the same
         diagnostic, so no caller can tell which path ran.
      4. *`--jit` with `--target` is refused, in both orders.* The JIT emits for
         this process, so a named target could only ever be ignored; silently
         running host code for someone who asked for wasm32 is the worst of the
         three available behaviours.
      5. *`--jit` on `build` is refused.* There is nothing to run.
      6. *Nothing is left on disk.* No IR, no executable, no temporary -- if
         `--jit` still writes an object then it is not the path it claims to be.
    """
    print(f"\n{BLUE}--- Running jit ---{RESET}")
    problems = []

    with tempfile.TemporaryDirectory(prefix="prismio-jit-") as tmp:
        wd = Path(tmp)
        prog = wd / "jitted.psm"
        # cli_arg_count is the compiler's own extern rather than a std.io export,
        # so the fixture declares it. That is the point: it reaches the runtime
        # already linked into the compiler process, which is where the two
        # prismio_argc can differ.
        prog.write_text('import std.io\n'
                        '\n'
                        'extern fn cli_arg_count() -> Int\n'
                        '\n'
                        'struct Point { x: Int, y: Int }\n'
                        '\n'
                        'fn total(p: Point) -> Int {\n'
                        '    return p.x + p.y\n'
                        '}\n'
                        '\n'
                        'fn main() -> Int {\n'
                        '    let p = Point { x: 40, y: 2 }\n'
                        '    let items = list_new()\n'
                        '    list_push(items, "jit")\n'
                        '    print("answer: ")\n'
                        '    println(total(p))\n'
                        '    print("argc: ")\n'
                        '    println(cli_arg_count())\n'
                        '    return 0\n'
                        '}\n')

        failing = wd / "failing.psm"
        failing.write_text('import std.io\n'
                           '\n'
                           'fn main() -> Int {\n'
                           '    println("about to fail")\n'
                           '    return 3\n'
                           '}\n')

        exe = wd / ("built" + (".exe" if os.name == "nt" else ""))
        jit = run_command([str(PRISMIO_EXE), "run", str(prog), "--jit"])
        native = run_command([str(PRISMIO_EXE), "run", str(prog), "-o", str(exe)])

        if jit.returncode != 0:
            # The exit code is part of the evidence and not a detail. A jitted
            # program that prints and *then* fails has resolved its symbols and
            # died afterwards, which is a different bug from one that never ran
            # -- and on Windows the code says which: 3221225477 is an access
            # violation, 3221226356 is heap corruption, and a small number is
            # the program's own `return`.
            problems.append(f"`run --jit` exited {jit.returncode}: "
                            + elide_middle((jit.stdout or "") + (jit.stderr or "")))
        elif native.returncode != 0:
            problems.append("the non-JIT `run` failed, so there is nothing to "
                            "compare against: "
                            + elide_middle((native.stdout or "") + (native.stderr or "")))
        else:
            # The native path prints `Built <path>` first; the JIT has nothing to
            # report because it wrote nothing. Compare what the program said.
            native_out = [l for l in (native.stdout or "").splitlines()
                          if not l.startswith("Built ")]
            jit_out = (jit.stdout or "").splitlines()
            if jit_out != native_out:
                problems.append(f"`run --jit` printed {jit_out!r} and `run` "
                                f"printed {native_out!r}: the JIT is not running "
                                "the module a build produces")
            elif "argc: 1" not in jit_out:
                problems.append(f"a jitted program reported {jit_out!r} rather "
                                "than `argc: 1`: cli_arg_count is reading the "
                                "compiler's prismio_argc, so the program was "
                                "told about the compiler's command line")

        # 3. A failing program fails identically.
        jit_fail = run_command([str(PRISMIO_EXE), "run", str(failing), "--jit"])
        native_fail = run_command([str(PRISMIO_EXE), "run", str(failing),
                                   "-o", str(wd / ("failing" + (".exe" if os.name == "nt" else "")))])
        if jit_fail.returncode == 0:
            problems.append("a jitted program returning 3 exited 0: the JIT is "
                            "swallowing the program's status")
        elif jit_fail.returncode != native_fail.returncode:
            problems.append(f"a failing program exits {jit_fail.returncode} under "
                            f"--jit and {native_fail.returncode} without it: a "
                            "caller can tell which path ran")
        if "about to fail" not in (jit_fail.stdout or ""):
            problems.append("a jitted program's output was lost when it returned "
                            "non-zero")

        # 4. --jit and --target, both orders.
        for order in (["--jit", "--target", "wasm32-unknown-unknown"],
                      ["--target", "wasm32-unknown-unknown", "--jit"]):
            r = run_command([str(PRISMIO_EXE), "run", str(prog)] + order)
            said = (r.stdout or "") + (r.stderr or "")
            if r.returncode == 0 or "cannot be combined" not in said:
                problems.append(f"`{' '.join(order)}` was accepted: the JIT emits "
                                "for this process and would have ignored the "
                                "target while appearing to honour it")

        # 5. Nothing to run on a build.
        r = run_command([str(PRISMIO_EXE), "build", str(prog), "--jit",
                         "-o", str(wd / "unused")])
        if r.returncode == 0:
            problems.append("`build --jit` was accepted, which can only mean the "
                            "flag was ignored")

        # 6. The JIT leaves nothing behind. Run it in a directory of its own and
        #    require that directory to hold only the two sources it started with.
        before = {p.name for p in wd.iterdir()}
        run_command([str(PRISMIO_EXE), "run", str(prog), "--jit"])
        after = {p.name for p in wd.iterdir()}
        if after != before:
            problems.append(f"`run --jit` left {sorted(after - before)} behind: it "
                            "is still writing IR or an object, which is the cost "
                            "it exists to avoid")

    if problems:
        print(f"{RED}[FAIL] jit{RESET}")
        for p in problems:
            print(f"  - {p}")
        return False

    print(f"{GREEN}[PASS] jit: same output and status as a built run, arguments "
          f"are the program's, --target refused both ways, nothing written{RESET}")
    return True


def run_runtime_library_test():
    """A packaged toolchain links the prebuilt runtime archive, and a foreign target does not.

    `tools/package.sh` builds `lib/runtime.a` and, until this test, nothing in the
    tree linked against one. A dev checkout runs the compiler out of `build/`,
    where `find_in_lib_dir` looks in `build/../lib` and `build/lib` and finds
    nothing, so every build in this suite took the `build_from_toolchain_sources`
    fallback instead. `find_runtime_library` -> `link_against_runtime_library` was
    reached only on an installed toolchain, and nothing in CI assembles one.

    That is the seam the whole target story rests on. A framework ships a
    `runtime-<triple>.a` for a platform this compiler cannot build a runtime for
    -- which module `print` is imported from on the web is an embedder's
    decision, not a compiler's -- and the compiler links whatever it is pointed
    at. **A missing archive is invisible**: the fallback compiles the runtime
    from the sources embedded in the compiler binary and the build succeeds
    anyway, which is exactly why "an installed toolchain compiles a program" is
    not an assertion about this at all.

    So every assertion here is made against `PRISMIO_OBJ_CACHE_TRACE`, which
    prints one `[objcache ...] <role>` line per toolchain source the fallback
    compiles. No line means the archive was linked; a line means it was not. The
    negative control is not optional -- without it, "no trace lines" is also what
    a compiler with a broken trace would print.

    Eight assertions:

      1. *The archive is linked*, and the program it produces runs. This resolves
         `import std.io` out of the installed `stdlib/` too, which is the same
         never-exercised layout.
      2. *The negative control.* With the archive moved aside, the same build
         must fall back and say so.
      3. *A foreign target does not get the host's archive.* `runtime.a` here was
         built for the host; linking it into a foreign binary is a miscompile the
         linker will not always catch. `find_runtime_library` must look for
         `runtime-<triple>.a` and fall back when it is absent. The runner tries
         foreign triples until this host's clang can codegen one: Apple clang, for
         example, cannot codegen wasm32 and would otherwise fail before runtime
         selection was exercised at all.
      4. *A shipped `runtime-<triple>.a` is found and linked*, and the
         cross-built binary runs. Checked where this host can run the result --
         arm64 macOS, where x86_64 runs under Rosetta -- and reported as skipped
         elsewhere.
      5. *`--verify` bypasses the archive even when it is there*, because an
         installed runtime was compiled without `-DPRISMIO_AIF_VERIFY` and half
         the allocations would be outside the accounting.
      6. *A freshly packaged toolchain is not stale*, checked from the repository
         root where the sources are visible. This is what keeps `package.sh` and
         `compiler_runtime_source_hash` agreeing about how the hash is derived;
         they cannot disagree by construction, because packaging asks the
         compiler for it, and this is what makes a change to that arrangement
         loud.
      7. *The staleness guard fires* when `lib/runtime.hash` disagrees with
         `runtime/*.c` on disk, rather than linking a runtime that no longer
         matches the code in front of you.
      8. *No backend symbol reaches a user binary*, by handing the packaged
         toolchain to `tools/verify_separation.*` -- which is called from here
         because it is otherwise called from nowhere, and spent two days broken
         proving it. It reads the archive symbol tables and scans the linked
         binary for backend-only strings, neither of which this test can do:
         a linked binary's symbol table says nothing about which static-archive
         members were folded into it.

    The triple in the archive name is the one **as typed on the command line**,
    not LLVM's normalisation of it: `ir_target_select` stores `use` verbatim, so
    `--target x86_64-apple-macos` and `--target x86_64-apple-macosx26.0.0` look
    for two different files describing one machine. Assertion 4 pins that,
    because it is the name a framework has to ship under and nothing else in the
    tree says so.
    """
    print(f"\n{BLUE}--- Running runtime_library ---{RESET}")
    problems = []

    if os.name == "nt":
        shell = which("pwsh") or which("powershell")
        if not shell:
            print(f"{RED}[FAIL] runtime_library: no PowerShell to run "
                  f"tools/package.ps1{RESET}")
            return False
        package = [shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                   str(PROJECT_ROOT / "tools" / "package.ps1")]
    else:
        package = ["bash", str(PROJECT_ROOT / "tools" / "package.sh")]

    with tempfile.TemporaryDirectory(prefix="prismio-runtime-lib-") as tmp:
        wd = Path(tmp)
        dist = wd / "dist"
        cache = wd / "objcache"
        probe = wd / "probe.psm"
        # std.io is an ordinary import, not a prelude, as of 2026-08-21. A probe
        # that prints is the point: without I/O there is nothing in the module for
        # the runtime archive to resolve, and the link would succeed against
        # nothing at all.
        probe.write_text('import std.io\n'
                         '\n'
                         'fn main() -> Int {\n'
                         '    println("archive")\n'
                         '    return 0\n'
                         '}\n')

        compiler = Path(PRISMIO_EXE).resolve()
        if os.name == "nt":
            package += ["-Compiler", str(compiler), "-OutDir", str(dist)]
        else:
            package += ["--compiler", str(compiler), "--out", str(dist)]

        packaged = subprocess.run(package, capture_output=True, text=True,
                                  cwd=str(PROJECT_ROOT))
        installed = dist / "bin" / ("prismio.exe" if os.name == "nt" else "prismio")
        lib = dist / "lib"
        archive = next((lib / f"runtime{ext}" for ext in (".a", ".lib")
                        if (lib / f"runtime{ext}").exists()), None)
        if packaged.returncode != 0 or not installed.exists() or archive is None:
            print(f"{RED}[FAIL] runtime_library: packaging a toolchain failed{RESET}")
            print("  - " + ((packaged.stderr or packaged.stdout or "").strip()[-500:]
                            or f"exit {packaged.returncode}, no runtime archive"))
            return False

        def build(args, cwd=wd):
            env = dict(os.environ, PRISMIO_OBJ_CACHE_DIR=str(cache),
                       PRISMIO_OBJ_CACHE_TRACE="1")
            return subprocess.run([str(installed), "build", str(probe)] + args,
                                  capture_output=True, text=True, cwd=str(cwd),
                                  env=env)

        # One line per toolchain source the fallback compiled -- hit, miss or
        # off. Any of the three means the archive was not what got linked.
        def from_source(r):
            return "[objcache" in (r.stderr or "")

        exe_suffix = ".exe" if os.name == "nt" else ""

        # 1. The archive is linked, and what comes out runs.
        exe = wd / ("probe" + exe_suffix)
        built = build(["-o", str(exe)])
        if built.returncode != 0 or not exe.exists():
            problems.append("a packaged toolchain could not compile a program: "
                            + (built.stdout or built.stderr or "").strip()[-300:])
        else:
            if from_source(built):
                problems.append("the packaged toolchain compiled the runtime from "
                                "source with the archive sitting in its own lib/: "
                                "find_runtime_library did not find "
                                f"{archive.name}")
            ran = run_command([str(exe)])
            if ran.returncode != 0 or "archive" not in (ran.stdout or ""):
                problems.append("the program linked against the runtime archive "
                                f"did not run: exit {ran.returncode}, stdout "
                                f"{(ran.stdout or '').strip()!r}")

        # 2. The negative control, without which assertion 1 proves nothing.
        aside = archive.with_name(archive.name + ".aside")
        archive.rename(aside)
        without = build(["-o", str(wd / ("probe_nolib" + exe_suffix))])
        aside.rename(archive)
        if not from_source(without):
            problems.append("with the archive moved aside the build still "
                            "reported no toolchain object compiled, so the trace "
                            "this test reads is not reporting and assertion 1 "
                            "would pass however the lookup behaved")

        # 3. A foreign target must not be handed the host's archive. Do not pin
        # this to wasm32: the clang shipped with Xcode has no wasm code generator,
        # so it fails while compiling the *program object*, before the compiler has
        # chosen any runtime. Such a failure says nothing about this seam.
        if sys.platform == "darwin":
            foreign_targets = ["x86_64-unknown-linux-gnu",
                               "x86_64-pc-windows-msvc",
                               "wasm32-unknown-unknown"]
        elif os.name == "nt":
            foreign_targets = ["x86_64-unknown-linux-gnu",
                               "aarch64-unknown-linux-gnu",
                               "wasm32-unknown-unknown"]
        else:
            foreign_targets = ["x86_64-pc-windows-msvc",
                               "aarch64-apple-macos",
                               "wasm32-unknown-unknown"]

        foreign = None
        foreign_target = None
        early_failures = []
        for triple in foreign_targets:
            attempted = build(["--target", triple,
                               "-o", str(wd / f"probe_{triple}")])
            if from_source(attempted):
                foreign, foreign_target = attempted, triple
                break
            said = ((attempted.stderr or attempted.stdout or "").strip()
                    .splitlines())
            early_failures.append(f"{triple}: {said[-1] if said else 'no output'}")

        if foreign is None:
            problems.append("no candidate foreign target reached runtime "
                            "selection; each failed before the source fallback "
                            "could report a cache event (" +
                            "; ".join(early_failures) + ")")

        # 3b. When the fallback fails, the note has to name the target archive.
        # It used to recommend `prismio bootstrap`, which builds a compiler for
        # the host and cannot help a cross build. A host with a suitable foreign
        # C library may succeed, in which case there is no diagnostic to inspect.
        if foreign is not None and foreign.returncode != 0:
            told = (foreign.stdout or "") + (foreign.stderr or "")
            expected_archive = f"runtime-{foreign_target}.a"
            if expected_archive not in told:
                problems.append("a cross build failed without naming "
                                f"{expected_archive}, so the one thing a "
                                "framework has to know -- the exact filename to "
                                "ship -- is not in the diagnostic")
            if "prismio bootstrap" in told:
                problems.append("a failed cross build told the user to run "
                                "`prismio bootstrap`, which builds a compiler for "
                                "the host and cannot help a cross build")

        # 4. The real thing: an archive shipped for a target, where this host can
        #    run the result.
        cross = "not attempted on this host"
        if sys.platform == "darwin" and platform.machine() == "arm64":
            sdk = run_command(["xcrun", "--show-sdk-path"])
            clang = which("clang")
            ar = which("ar") or which("llvm-ar")
            triple = "x86_64-apple-macos"
            if sdk.returncode == 0 and sdk.stdout.strip() and clang and ar:
                objs = []
                failed = None
                for name in ("lang_runtime.c", "program_support.c"):
                    obj = wd / (name[:-2] + ".x86.o")
                    made = run_command([clang, "-target", triple,
                                        "-isysroot", sdk.stdout.strip(),
                                        "-Wno-deprecated-declarations", "-c",
                                        str(PROJECT_ROOT / "runtime" / name),
                                        "-o", str(obj)])
                    if made.returncode != 0:
                        failed = f"could not build {name} for {triple}"
                        break
                    objs.append(str(obj))

                shipped = lib / f"runtime-{triple}.a"
                if not failed:
                    made = run_command([ar, "rcs", str(shipped)] + objs)
                    if made.returncode != 0:
                        failed = f"could not archive a {triple} runtime"

                if failed:
                    # A missing cross toolchain is not a compiler defect; say so
                    # rather than failing the suite for the host's setup.
                    cross = f"skipped -- {failed}"
                else:
                    exe = wd / "probe_x86"
                    r = build(["--target", triple,
                               "--sysroot", sdk.stdout.strip(), "-o", str(exe)])
                    if r.returncode != 0 or not exe.exists():
                        problems.append(f"a build for {triple} with "
                                        f"{shipped.name} beside the compiler "
                                        "failed: "
                                        + (r.stdout or r.stderr or "").strip()[-300:])
                    elif from_source(r):
                        problems.append(f"{shipped.name} was shipped for "
                                        f"{triple} and the compiler compiled the "
                                        "runtime from source anyway: the archive "
                                        "a framework ships is never reached")
                    else:
                        kind = run_command(["file", str(exe)]).stdout
                        ran = run_command([str(exe)])
                        if "x86_64" not in kind:
                            problems.append("the cross build produced "
                                            f"{kind.strip()!r} rather than an "
                                            "x86_64 binary")
                        elif ran.returncode != 0 or "archive" not in (ran.stdout or ""):
                            problems.append("a binary linked against the shipped "
                                            f"{shipped.name} did not run: exit "
                                            f"{ran.returncode}, stdout "
                                            f"{(ran.stdout or '').strip()!r}")
                        else:
                            cross = f"{shipped.name} linked and ran"
                    cleanup_files(shipped)

        # 5. --verify must not use an archive built without its define.
        verify = build(["--verify", "-o", str(wd / ("probe_verify" + exe_suffix))])
        if not from_source(verify):
            problems.append("--verify linked the installed runtime archive, which "
                            "was compiled without -DPRISMIO_AIF_VERIFY: half the "
                            "allocations would sit outside the accounting the "
                            "flag exists to keep")

        # 6 and 7. Freshness, from the repository root -- the guard needs both an
        # installed hash and a source tree to compare it against, and only the
        # repository root has the second.
        hash_file = lib / "runtime.hash"
        if not hash_file.exists():
            problems.append("packaging recorded no lib/runtime.hash, so a stale "
                            "installed runtime cannot be detected at all")
        else:
            fresh = build(["-o", str(wd / ("probe_fresh" + exe_suffix))],
                          cwd=PROJECT_ROOT)
            if fresh.returncode != 0 or "stale" in (fresh.stdout or "") + (fresh.stderr or ""):
                problems.append("a toolchain packaged from these very sources was "
                                "reported stale against them: packaging and "
                                "compiler_runtime_source_hash disagree about the "
                                "hash")

            recorded = hash_file.read_text()
            bogus = "1" * 16 if recorded.strip().startswith("0") else "0" * 16
            hash_file.write_text(bogus)
            stale = build(["-o", str(wd / ("probe_stale" + exe_suffix))],
                          cwd=PROJECT_ROOT)
            hash_file.write_text(recorded)
            said = (stale.stdout or "") + (stale.stderr or "")
            if stale.returncode == 0 or "stale" not in said:
                problems.append("a runtime archive whose recorded hash disagrees "
                                "with runtime/*.c on disk was linked anyway: exit "
                                f"{stale.returncode}")

        # 8. The runtime/backend boundary, checked by the script that owns it.
        #
        # `tools/verify_separation.*` is called from here rather than left as a
        # tool nobody runs. Its probe program stopped compiling the day std.io
        # stopped being a prelude and it went two days broken with three of its
        # checks silently not running, because nothing in the tree called it.
        # It builds no toolchain of its own -- it takes a --dist, and this test
        # has already packaged one -- so wiring it in costs one process and makes
        # the next break loud.
        #
        # It also makes two assertions this test cannot. `nm` over the archives
        # proves the libraries were built from the right translation units in the
        # first place, and a byte signature in the linked binary proves the *link
        # step* pulled in only the runtime: a linked binary's symbol table says
        # nothing about which static-archive members were folded into it, so nm
        # cannot answer that one at all.
        if os.name == "nt":
            script = PROJECT_ROOT / "tools" / "verify_separation.ps1"
            symbols = which("llvm-nm")
            command = [shell, "-NoProfile", "-ExecutionPolicy", "Bypass",
                       "-File", str(script), "-Dist", str(dist)]
        else:
            script = PROJECT_ROOT / "tools" / "verify_separation.sh"
            symbols = which("llvm-nm") or which("nm")
            command = ["bash", str(script), "--dist", str(dist)]

        if not symbols:
            # The script exits 1 for a missing nm exactly as it does for a failed
            # check, so the two are told apart here rather than by its exit code.
            separation = "skipped -- no nm or llvm-nm on PATH"
        else:
            ran = subprocess.run(command, capture_output=True, text=True,
                                 cwd=str(PROJECT_ROOT))
            said = (ran.stdout or "") + (ran.stderr or "")
            if ran.returncode != 0:
                # The script colours its own output; the escapes would otherwise
                # be quoted straight into this runner's failure line.
                plain = re.sub(r"\x1b\[[0-9;]*m", "", said)
                named = [l.split("[FAIL]", 1)[1].strip()
                         for l in plain.splitlines() if "[FAIL]" in l]
                problems.append(f"{script.name} failed against the packaged "
                                "toolchain: "
                                + ("; ".join(named) if named
                                   else plain.strip()[-300:] or f"exit {ran.returncode}"))
                separation = f"{script.name} failed"
            else:
                separation = f"{script.name} passed"

    if problems:
        print(f"{RED}[FAIL] runtime library{RESET}")
        for p in problems:
            print(f"  - {p}")
        return False

    print(f"{GREEN}[PASS] runtime library: a packaged toolchain links its own "
          f"archive, a foreign target does not get the host's, --verify bypasses "
          f"it, staleness is caught; cross: {cross}; separation: "
          f"{separation}{RESET}")
    return True


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
            seen = next((t for t in nodes.values()
                         if "DILocalVariable" in t and 'name: "seen"' in t), "")
            ref = re.search(r"type: !(\d+)", seen)
            if not seen:
                problems.append("no DILocalVariable for `seen`, so the "
                                "inferred-enum case is not being checked")
            elif not ref or "DW_TAG_enumeration_type" not in nodes.get(int(ref.group(1)), ""):
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

    # Two compiles and two runs per fixture, which is four subprocesses times
    # every `test_*.psm` in the suite: **129s of the suite's 178s was here.**
    # They are independent, so they go through the pool -- and each fixture gets
    # its own pair of executables, because the single shared `ni_release.exe`
    # was the only thing that made this sequential.
    def check_one(src):
        text = src.read_text(encoding="utf-8", errors="replace")
        if any(p in text for p in PROBES):
            return ("skip", src.name)
        rel_exe = TEST_DIR / f"ni_release_{src.stem}.exe"
        dbg_exe = TEST_DIR / f"ni_debug_{src.stem}.exe"
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
    with concurrent.futures.ThreadPoolExecutor(max_workers=test_jobs()) as pool:
        for kind, payload in pool.map(check_one, fixtures):
            if kind == "skip":
                skipped.append(payload)
            elif kind == "problem":
                problems.append(payload)
            elif kind == "checked":
                checked += 1

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
    out = TEST_DIR / "t70_fields.ll"

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
        # The four that remain, and the count is load-bearing rather than
        # incidental -- a wrong free in this fixture is a *legal* release as far
        # as the accounting goes, so it shows up here as one fewer leak and not
        # as a violation:
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
        "test_45_aif_affine_collections": 2,
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
        # The 2 are both deliberate: borrow_reassign's initialiser, which the
        # guard must decline because the slot ends up holding `h.name`, and
        # `piece` in main -- callee_accumulator returns a value makePiece
        # allocated, so main owns it only two hops from its site and ownership
        # transfer survives one. A drop to 1 means the two-hop case landed; a rise
        # to 8 means M2.0b's predicate stopped firing.
        "test_72_reassigned_ownership": 2,
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
    cmd = [str(PRISMIO_EXE), "aif", str(source), "--manifest"]
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


def run_inline_runtime_default_test():
    """The curated runtime merge is the default and really runs on this host.

    The merge is deliberately fail-open: if its runtime-IR compile, curation, or
    C-API link fails, the compiler builds the ordinary separate-runtime program.
    That is the safe product behavior, but it means a value test alone can pass
    while the optimization did nothing. `PRISMIO_OBJ_CACHE_TRACE` exposes a
    marker only after a successful merge; requiring it makes the existing
    Windows/Linux/macOS suite the portability gate the default was waiting for.

    The second build pins `PRISMIO_INLINE_RUNTIME=0` as a rollback and
    measurement control. It must still build the same program, but it must not
    report a merge.
    """
    print(f"\n{BLUE}--- Running inline_runtime_default ---{RESET}")

    fixture = TEST_DIR / "test_28_list.psm"
    marker = "[inline runtime] merged curated module"

    with tempfile.TemporaryDirectory(prefix="prismio-inline-runtime-") as td:
        root = Path(td)
        cache = root / "cache"

        def build_and_run(label, setting, expect_merge):
            exe = root / f"{label}.exe"
            env = os.environ.copy()
            env["PRISMIO_OBJ_CACHE_DIR"] = str(cache)
            env["PRISMIO_OBJ_CACHE_TRACE"] = "1"
            if setting is None:
                env.pop("PRISMIO_INLINE_RUNTIME", None)
            else:
                env["PRISMIO_INLINE_RUNTIME"] = setting

            built = subprocess.run(
                [str(PRISMIO_EXE), "build", str(fixture), "-o", str(exe)],
                capture_output=True, text=True, env=env)
            output = f"{built.stdout}\n{built.stderr}"
            if built.returncode != 0 or not exe.is_file():
                print(f"{RED}[FAIL] inline runtime {label}: build failed{RESET}")
                print(output[:1200])
                return False

            merged = marker in output
            if merged != expect_merge:
                wanted = "a real curated-module merge" if expect_merge else "the opt-out path"
                print(f"{RED}[FAIL] inline runtime {label}: expected {wanted}{RESET}")
                print(output[:1200])
                return False

            ran = subprocess.run([str(exe)], capture_output=True, text=True)
            if ran.returncode != 0 or "PASS: list" not in ran.stdout:
                print(f"{RED}[FAIL] inline runtime {label}: compiled program failed{RESET}")
                print(f"{ran.stdout}\n{ran.stderr}"[:1200])
                return False
            return True

        if not build_and_run("default", None, True):
            return False
        if not list(cache.glob("curated-*.ll")):
            print(f"{RED}[FAIL] inline runtime default: no curated cache entry was produced{RESET}")
            return False
        if not build_and_run("disabled", "0", False):
            return False

    print(f"{GREEN}[PASS] inline runtime merged by default; `=0` retained the old path{RESET}")
    return True


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
    exe = TEST_DIR / "overflow_checks_probe.exe"
    ll = TEST_DIR / "overflow_checks_probe.ll"
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
            capture_output=True, text=True)
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


def run_runtime_object_from_ir_test():
    """A cold inline-runtime build lowers the runtime object from the curated
    bitcode, and did not quietly fall back to recompiling the C.

    The build already produced `lang_runtime.c` as an optimised module in order to
    cut the curated ops out of it. Compiling that same translation unit a second
    time to get the object was the whole of the 19-28% cold regression, so the
    object is lowered from the retained bitcode with the target backend alone.

    Like the merge, this fails open: a clang that rejects
    `-Xclang -disable-llvm-passes` compiles from source instead of failing the
    build. That is the right product behaviour and it is exactly why a value test
    cannot gate it -- the fallback produces the same program, just slower. The
    stage trace names which path ran, so requiring `(from IR)` here makes the
    three-platform suite the portability gate for it.

    `PRISMIO_OBJ_CACHE=0` because a warm build has no runtime object to compile
    and no raw module to retain; the reuse exists only on the cold path.
    """
    print(f"\n{BLUE}--- Running runtime_object_from_ir ---{RESET}")

    fixture = TEST_DIR / "test_28_list.psm"
    from_ir = "lang_runtime (from IR)"

    with tempfile.TemporaryDirectory(prefix="prismio-runtime-from-ir-") as td:
        root = Path(td)

        def build(label, inline_runtime):
            exe = root / f"{label}.exe"
            env = os.environ.copy()
            env["PRISMIO_OBJ_CACHE"] = "0"
            env["PRISMIO_BUILD_TRACE"] = "1"
            if inline_runtime is None:
                env.pop("PRISMIO_INLINE_RUNTIME", None)
            else:
                env["PRISMIO_INLINE_RUNTIME"] = inline_runtime

            built = subprocess.run(
                [str(PRISMIO_EXE), "build", str(fixture), "-o", str(exe)],
                capture_output=True, text=True, env=env)
            output = f"{built.stdout}\n{built.stderr}"
            if built.returncode != 0 or not exe.is_file():
                print(f"{RED}[FAIL] runtime object {label}: build failed{RESET}")
                print(output[:1200])
                return None
            ran = subprocess.run([str(exe)], capture_output=True, text=True)
            if ran.returncode != 0 or "PASS: list" not in ran.stdout:
                print(f"{RED}[FAIL] runtime object {label}: compiled program failed{RESET}")
                print(f"{ran.stdout}\n{ran.stderr}"[:1200])
                return None
            return output, ran.stdout

        default = build("default", None)
        if default is None:
            return False
        if from_ir not in default[0]:
            print(f"{RED}[FAIL] runtime object: the cold build recompiled lang_runtime.c "
                  f"instead of lowering the retained bitcode{RESET}")
            print(default[0][:1200])
            return False

        # The opt-out never produces a curated module, so there is nothing to
        # retain and this stage must report the ordinary compile. Without this
        # arm, a trace that printed `(from IR)` unconditionally would pass.
        opt_out = build("disabled", "0")
        if opt_out is None:
            return False
        if from_ir in opt_out[0]:
            print(f"{RED}[FAIL] runtime object: the opt-out path claimed to lower "
                  f"from IR, but it builds no curated module{RESET}")
            print(opt_out[0][:1200])
            return False

        if default[1] != opt_out[1]:
            print(f"{RED}[FAIL] runtime object: the two paths disagree on output{RESET}")
            return False

    print(f"{GREEN}[PASS] runtime object lowered from the curated bitcode; "
          f"`=0` compiled it from source; both agree{RESET}")
    return True


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
    waived = {
        "list_set_inline": "curating it measured 0.999x for +3.1% compile time (2026-08-29)",
        "list_push_inline": "curating it measured 0.999x for +3.1% compile time (2026-08-29)",
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
            capture_output=True, text=True)
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


def main():
    global PRISMIO_EXE
    args = parse_runner_args()

    print(f"{YELLOW}{'='*60}{RESET}")
    print(f"{YELLOW}Prismio Compiler Test Suite{RESET}")
    print(f"{YELLOW}{'='*60}{RESET}")

    all_test_files = sorted(TEST_DIR.glob('test_*.psm'))
    all_neg_test_files = sorted(TEST_DIR.glob('neg_*.psm'))
    all_files = all_test_files + all_neg_test_files

    if args.list:
        for test_file in all_files:
            print(test_file.stem)
        return

    PRISMIO_EXE = find_prismio_exe()
    if not PRISMIO_EXE.exists():
        print(f"{RED}[FAIL] Compiler not found at {PRISMIO_EXE}{RESET}")
        sys.exit(1)

    patterns = args.patterns + args.filters
    selected = select_test_files(all_files, patterns) if patterns else all_files
    test_files = [path for path in selected if path.name.startswith("test_")]
    neg_test_files = [path for path in selected if path.name.startswith("neg_")]

    if not test_files and not neg_test_files:
        if patterns:
            print(f"{RED}[FAIL] No fixture matched: {', '.join(patterns)}{RESET}")
            print("Use --list to see available fixture names.")
            sys.exit(2)
        print(f"{RED}[FAIL] No test files found!{RESET}")
        print("Test files should be named test_XX_*.psm or neg_XX_*.psm")
        sys.exit(1)

    if patterns:
        print(f"\nFilter: {', '.join(patterns)} (file fixtures only)")
    print(f"\nFound {len(test_files)} positive test(s)")
    print(f"Found {len(neg_test_files)} negative test(s)")

    passed = 0
    failed = 0

    global _progress_total
    _progress_total = len(test_files) + len(neg_test_files)
    print(f"Running file fixtures on {test_jobs()} worker(s)\n")

    t_files = time.time()
    real_stdout = sys.stdout
    sys.stdout = _ThreadOut(real_stdout)
    try:
        outcomes = (run_parallel(run_test, test_files, lambda f: Path(f).stem)
                    + run_parallel(run_negative_test, neg_test_files, lambda f: Path(f).stem))
    finally:
        sys.stdout = real_stdout
    for ok in outcomes:
        if ok:
            passed += 1
        else:
            failed += 1
    print(f"\n  file fixtures: {time.time() - t_files:.1f}s "
          f"({passed} passed, {failed} failed)\n")

    if patterns:
        print(f"{YELLOW}{'='*60}{RESET}")
        print(f"{YELLOW}Filtered Test Results{RESET}")
        print(f"{YELLOW}{'='*60}{RESET}")
        print(f"{GREEN}Passed: {passed}{RESET}")
        print(f"{RED}Failed: {failed}{RESET}")
        print(f"Total:  {passed + failed}")
        if failed:
            sys.exit(1)
        print(f"\n{GREEN}All selected tests passed!{RESET}")
        sys.exit(0)

    if run_cli_test():
        passed += 1
    else:
        failed += 1

    if run_check_command_test():
        passed += 1
    else:
        failed += 1

    if run_ums_test():
        passed += 1
    else:
        failed += 1

    if run_corpus_test():
        passed += 1
    else:
        failed += 1

    if run_aif_test():
        passed += 1
    else:
        failed += 1

    if run_aif_human_report_test():
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

    if run_nonlexical_extent_test():
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

    if run_elem_mode_agreement_test():
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

    if run_slice_gate_test():
        passed += 1
    else:
        failed += 1

    if run_data_view_gate_test():
        passed += 1
    else:
        failed += 1

    if run_struct_path_tbaa_test():
        passed += 1
    else:
        failed += 1

    if run_generic_layout_specialization_test():
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

    if run_inline_runtime_default_test():
        passed += 1
    else:
        failed += 1

    if run_runtime_object_from_ir_test():
        passed += 1
    else:
        failed += 1

    if run_single_loop_inline_test():
        passed += 1
    else:
        failed += 1

    if run_task_release_test():
        passed += 1
    else:
        failed += 1

    if run_overflow_checks_test():
        passed += 1
    else:
        failed += 1

    if run_curated_closure_test():
        passed += 1
    else:
        failed += 1

    if run_curated_emits_test():
        passed += 1
    else:
        failed += 1

    if run_target_test():
        passed += 1
    else:
        failed += 1

    if run_runtime_library_test():
        passed += 1
    else:
        failed += 1

    if run_incremental_manifest_test():
        passed += 1
    else:
        failed += 1

    if run_jit_test():
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
