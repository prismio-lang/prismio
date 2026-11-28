"""The `ums` suite's harness tests (the design record, section 4; see tools/testkit/__init__.py)."""
import json
import os
import platform
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
from shutil import which
from pathlib import Path

from harness.common import *


def project_host_profile():
    """The profile the root build.ums's `toolchain.host` lives in: "release" or "debug".

    The fixtures below build, park and promote *the real project's host*, so they have
    to look where the manifest says it is. They hard-coded `.prismio/build/debug`, and
    failed all of `ums` once the manifest named `.prismio/build/release/prismio` -- plain
    `prismio build` writes the debug profile, so nothing ever produced the host.
    """
    try:
        manifest = (PROJECT_ROOT / "build.ums").read_text(encoding="utf-8")
    except OSError:
        return "debug"
    found = re.search(r'host\s*=\s*"([^"]+)"', manifest)
    if found and "/release/" in found.group(1).replace("\\", "/"):
        return "release"
    return "debug"


HOST_PROFILE = project_host_profile()


HOST_FLAGS = ["--release"] if HOST_PROFILE == "release" else []


def trust_host(path):
    """Record `path` as a host this machine promoted, exactly as the launcher does.

    The stamp is the file's identity (runtime/build_driver.c, host_identity):
    device, inode, size and modification time to the nanosecond on POSIX; volume
    serial, file index, size and last-write FILETIME on Windows. A test that puts
    a stand-in where the host lives has to trust it before the launcher will run
    it, which is the behaviour under test in the other direction.
    """
    st = os.stat(path)
    if os.name == "nt":
        # Asked of Win32, not `os.stat`: Python 3.12 widened `st_dev` to a 64-bit
        # volume id, while the launcher records `dwVolumeSerialNumber`, the
        # 32-bit serial, and a stamp that differs in that one field is untrusted.
        import ctypes
        from ctypes import wintypes

        class FileTime(ctypes.Structure):
            _fields_ = [("low", wintypes.DWORD), ("high", wintypes.DWORD)]

        class FileInformation(ctypes.Structure):
            _fields_ = [("attributes", wintypes.DWORD), ("created", FileTime),
                        ("accessed", FileTime), ("written", FileTime),
                        ("serial", wintypes.DWORD), ("size_high", wintypes.DWORD),
                        ("size_low", wintypes.DWORD), ("links", wintypes.DWORD),
                        ("index_high", wintypes.DWORD), ("index_low", wintypes.DWORD)]

        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.CreateFileW.restype = wintypes.HANDLE
        kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                       wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD,
                                       wintypes.HANDLE]
        kernel.GetFileInformationByHandle.argtypes = [wintypes.HANDLE, ctypes.c_void_p]
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = kernel.CreateFileW(str(path), 0x80000000, 7, None, 3, 0, None)
        info = FileInformation()
        found = handle not in (None, ctypes.c_void_p(-1).value) and \
            kernel.GetFileInformationByHandle(handle, ctypes.byref(info))
        if handle not in (None, ctypes.c_void_p(-1).value):
            kernel.CloseHandle(handle)
        if not found:
            raise OSError(f"could not read the identity of {path}")
        identity = (f"{info.serial} {info.index_high} {info.index_low} "
                    f"{info.size_high} {info.size_low} "
                    f"{info.written.high} {info.written.low}")
    else:
        identity = (f"{st.st_dev} {st.st_ino} {st.st_size} "
                    f"{st.st_mtime_ns // 1_000_000_000} {st.st_mtime_ns % 1_000_000_000}")
    # Bytes: `write_text` would write CRLF on Windows, and the launcher compares the
    # stamp as written, header and newlines included.
    Path(f"{path}.trusted").write_bytes(f"prismio-host-stamp 1\n{identity}\n".encode("ascii"))


def project_version():
    """`version` in the repository's build.ums: the version the compiler built from this tree
    reports (`import build`), so a test names it by reading the manifest rather than by repeating it."""
    manifest = (PROJECT_ROOT / "build.ums").read_text(encoding="utf-8")
    match = re.search(r'project\s*\{[^}]*?\bversion\s*=\s*"([^"]+)"', manifest)
    if not match:
        raise RuntimeError("build.ums has no literal project version")
    return match.group(1)


def show_run(result):
    """Everything a failed ums step said: its exit status and both streams.

    `print(r.stdout or r.stderr)` showed a successful `Built ...` line from a
    build whose error had gone to stderr, three times, and each time the report
    read as "the build worked, and the check is wrong".
    """
    print(f"exit status {result.returncode}")
    print(f"stdout:\n{elide_middle(result.stdout or '')}")
    print(f"stderr:\n{elide_middle(result.stderr or '')}")


@harness_test(suite="ums", resources={"mem": 500}, timeout=300)
def run_ums_after_test():
    """A target's `after { ... }` steps: run once it is built, `output` naming the file just built,
    a failing step failing the build; a `build` step and a target with its own after steps refused."""
    print(f"\n{BLUE}--- Running ums_after ---{RESET}")
    problems = []
    manifest = """project {{
    name = "app"
    version = "0.1.0"
    prismio = "0.2.0"
}}

targets {{
    executable("helper") {{
        entry = "src/helper.psm"
        {helper}
    }}
    executable("app") {{
        entry = "src/main.psm"
        after {{
            {steps}
        }}
    }}
}}
"""
    with tempfile.TemporaryDirectory(prefix="prismio-ums-after-") as temp_dir:
        project = Path(temp_dir) / "app"
        (project / "src").mkdir(parents=True)
        (project / "src" / "main.psm").write_text("fn main() -> Int { return 0 }\n")
        # Writes what it was told into the file it was told, so the test reads what `output` was.
        (project / "src" / "helper.psm").write_text(
            "import std.fs\nimport std.process\n\n"
            "fn main() -> Int {\n"
            "    if (writeFile(process.args[1], process.args[2]) == false) { return 1 }\n"
            "    if (process.args.count > 3) { return 7 }\n"
            "    return 0\n}\n")
        (project / "tool.psm").write_text(
            "import std.fs\nimport std.process\n\n"
            "fn main() -> Int {\n"
            "    if (writeFile(\"script.txt\", process.args[1]) == false) { return 1 }\n"
            "    return 0\n}\n")
        env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")

        def build(steps, helper=""):
            (project / "build.ums").write_text(manifest.format(steps=steps, helper=helper))
            return subprocess.run([str(PRISMIO_EXE), "build", "app"], cwd=str(project), env=env,
                                  capture_output=True, text=True, encoding="utf-8", errors="replace")

        ran = build('run("helper", "helper.txt", output)\n            run("tool.psm", output)')
        suffix = ".exe" if os.name == "nt" else ""
        for written in ("helper.txt", "script.txt"):
            file = project / written
            text = file.read_text() if file.exists() else ""
            if not text.replace("\\", "/").endswith(".prismio/build/debug/app" + suffix):
                problems.append(f"after step did not receive the built file in {written}: {text!r}\n{ran.stderr[-600:]}")
        failing = build('run("helper", "helper.txt", output, "extra")')
        if failing.returncode == 0 or "after step 1" not in failing.stdout + failing.stderr:
            problems.append(f"a failing after step did not fail the build: {failing.stderr[-400:]}")
        for steps, helper, code in (('build("helper")', "", "UMS2117"),
                                    ('run("helper", "a", args)', "", "UMS2508"),
                                    ('run("helper", "a", output)',
                                     'after { shell("true") }', "UMS2118")):
            refused = build(steps, helper)
            if refused.returncode == 0 or code not in refused.stdout + refused.stderr:
                problems.append(f"expected {code} for `{steps}`: {(refused.stdout + refused.stderr)[-400:]}")
    if problems:
        print(f"{RED}[FAIL] ums_after{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] ums_after: after steps get the built file, fail the build, and refuse recursion{RESET}")
    return True


@harness_test(suite="ums", resources={"cpu": 2, "mem": 800, "objcache": EXCLUSIVE})
def run_ums_project_test():
    """What a project's user sees: `run`, `test`, `clean`, commands, native code.

    Each check is one of the defects the UMS release audit reproduced,
    asserted from the outside, in a project outside
    the checkout so nothing in the tree can stand in for the installed toolchain.
    """
    print(f"\n{BLUE}--- Running ums_project ---{RESET}")
    problems = []
    exe_suffix = ".exe" if os.name == "nt" else ""

    with tempfile.TemporaryDirectory(prefix="prismio-ums-project-") as temp_dir:
        project = Path(temp_dir) / "app"
        env = dict(os.environ)
        env.pop("PRISMIO_INTERNAL_HOSTED", None)
        env["PRISMIO_OBJ_CACHE_DIR"] = str(Path(temp_dir) / "objcache")
        env["PRISMIO_OBJ_CACHE_TRACE"] = "1"

        def prismio(*args, cwd=project):
            return subprocess.run([str(PRISMIO_EXE), *args], capture_output=True,
                                  text=True, encoding="utf-8", errors="replace", cwd=str(cwd), env=env)

        created = prismio("init", "app", cwd=Path(temp_dir))
        if created.returncode != 0:
            print(f"{RED}[FAIL] ums_project: `prismio init` failed{RESET}")
            show_run(created)
            return False

        (project / "src" / "main.psm").write_text(
            "import std.io\nimport std.process\nimport std.string\n"
            "extern fn native_answer() -> Int\n\n"
            "fn main() -> Int {\n"
            "    for i in 1..<process.args.count {\n"
            "        println(process.args[i])\n"
            "    }\n"
            "    println(native_answer().toString())\n"
            "    return 3\n"
            "}\n", encoding="utf-8")
        (project / "csrc" / "include").mkdir(parents=True)
        (project / "csrc" / "include" / "answer.h").write_text("#define BASE 40\n", encoding="utf-8")
        (project / "csrc" / "answer.c").write_text(
            '#include "answer.h"\nint native_answer(void) { return BASE + BONUS; }\n', encoding="utf-8")
        (project / "csrc" / "flags.rsp").write_text("-DBONUS=2\n", encoding="utf-8")
        (project / "tools").mkdir()
        (project / "tools" / "probe.py").write_text(
            "import os, sys\n"
            "print('cwd=' + os.path.basename(os.getcwd()))\n"
            "print('argv=' + '|'.join(sys.argv[1:]))\n"
            "sys.exit(int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0)\n",
            encoding="utf-8")
        (project / "tools" / "app.psm").write_text(
            "fn main() -> Int {\n    return 0\n}\n", encoding="utf-8")
        (project / "tests").mkdir()
        (project / "tests" / "pass.psm").write_text("fn main() -> Int {\n    return 0\n}\n", encoding="utf-8")
        (project / "tests" / "broken.psm").write_text("fn main() -> Int {\n    return nope\n}\n", encoding="utf-8")
        (project / "build.ums").write_text(
            'project {\n    name = "app"\n    version = "1.0.0-beta.1"\n    prismio = "0.1"\n}\n'
            'targets {\n'
            '    executable("app") {\n'
            '        entry = "src/main.psm"\n'
            '        native {\n'
            '            source("csrc/answer.c")\n'
            '            include("csrc/include")\n'
            '            responseFile("csrc/flags.rsp")\n'
            '        }\n'
            '    }\n'
            '    test("pass") { entry = "tests/pass.psm" }\n'
            '    test("broken") { entry = "tests/broken.psm" }\n'
            '}\n'
            'commands {\n'
            '    command("probe") { run("tools/probe.py", args) }\n'
            '    command("tool") { run("tools/app.psm") }\n'
            '}\n', encoding="utf-8")

        # 1. `run` forwards what follows `--` to the program verbatim, and the
        #    program's own exit status is the command's.
        ran = prismio("run", "--", "a", "b c", "$(echo x)")
        lines = (ran.stdout or "").splitlines()
        if ran.returncode != 3 or lines[-4:] != ["a", "b c", "$(echo x)", "42"]:
            problems.append("`prismio run -- args` did not pass the arguments through, "
                            f"or lost the exit status (got {ran.returncode}, {lines[-4:]})")
        if "P1023" in (ran.stderr or ""):
            problems.append("a program's own non-zero exit was reported as a toolchain error")

        # 2. The native source compiled with its include directory and its
        #    response file (42 above), and a header edit reaches the next build.
        (project / "csrc" / "include" / "answer.h").write_text("#define BASE 100\n", encoding="utf-8")
        edited = prismio("run")
        if "[objcache miss] answer" not in edited.stderr or "102" not in edited.stdout:
            problems.append("editing a header a native source includes did not rebuild it")
        again = prismio("run")
        if "[objcache hit] answer" not in again.stderr:
            problems.append("an unchanged native source was not served from the cache")

        # 3. The debug and release profiles are different builds.
        prismio("build", "--release")
        debug_exe = project / ".prismio" / "build" / "debug" / f"app{exe_suffix}"
        release_exe = project / ".prismio" / "build" / "release" / f"app{exe_suffix}"
        if (not debug_exe.is_file() or not release_exe.is_file()
                or debug_exe.read_bytes() == release_exe.read_bytes()):
            problems.append("`--release` built the same binary as the debug profile")

        # 4. Command steps: arguments are never shell syntax, every step runs
        #    in the project root, and a failing step's status is the command's.
        probe = prismio("probe", "7", "$HOME", "trail\\", cwd=project / "src")
        if ("cwd=app" not in probe.stdout or "argv=7|$HOME|trail\\" not in probe.stdout
                or probe.returncode != 7):
            problems.append("a project command step was shell-interpreted, ran outside the "
                            f"project root, or lost its status ({probe.returncode})")
            show_run(probe)

        # 5. A `.psm` tool is built under tools/, never over a target.
        before = debug_exe.read_bytes()
        prismio("tool")
        if (not (project / ".prismio" / "build" / "debug" / "tools" / f"app{exe_suffix}").is_file()
                or debug_exe.read_bytes() != before):
            problems.append("a .psm tool named like a target overwrote it")

        # 6. `test` runs every test even when one does not build, and fails.
        tested = prismio("test")
        if tested.returncode == 0 or "ok    pass" not in tested.stdout or "did not build" not in tested.stdout:
            problems.append("`prismio test` stopped at a test that does not build")
        only = prismio("test", "pass")
        if only.returncode != 0 or "broken" in only.stdout:
            problems.append("`prismio test <name>` did not run just the named test")

        # 7. A target name is a target, not a file that cannot be read.
        named = prismio("build", "nope")
        if "P1080" not in named.stderr:
            problems.append("`prismio build <unknown>` did not name the declared targets")

        # 8. `clean` removes the whole profile, tools included.
        cleaned = prismio("clean")
        if cleaned.returncode != 0 or (project / ".prismio" / "build" / "debug").exists():
            problems.append("`prismio clean` left the profile directory behind")

        # 9. A project that needs a newer Prismio says so.
        manifest = (project / "build.ums").read_text(encoding="utf-8")
        (project / "build.ums").write_text(manifest.replace('prismio = "0.1"', 'prismio = "99.0"'),
                                           encoding="utf-8")
        newer = prismio("build")
        if newer.returncode == 0 or "P1078" not in newer.stderr:
            problems.append("a manifest asking for Prismio 99.0 was built anyway")

    if problems:
        print(f"{RED}[FAIL] ums_project:{RESET}")
        for problem in problems:
            print(f"  - {problem}")
        return False
    print(f"{GREEN}[PASS] ums_project: run arguments and status, native sources, profiles, "
          f"command steps, tools, tests, targets, clean and the version check{RESET}")
    return True


def without_library_paths(ir, libraries):
    """An IR file with each of `libraries` spelled the same, and the string constants that hold a
    path under one renamed and re-measured to match."""
    data = ir.read_bytes()
    for library in sorted((str(p).encode() for p in libraries), key=len, reverse=True):
        data = data.replace(library, b"LIBRARY")
    data = re.sub(rb"@\.aifprof\.[0-9a-f]+\.\d+", b"@.aifprof", data)
    return re.sub(rb'\[\d+ x i8\] c"LIBRARY', b'[N x i8] c"LIBRARY', data)


@harness_test("ums_manifest", suite="ums", resources={"mem": 500}, timeout=300)
def run_ums_manifest_test():
    """v0.1 3.7 -- UMS manifest, dependency resolution, and the lockfile.

    `ums/test_ums.psm` has existed since UMS landed and the suite never ran it,
    so the whole manifest subsystem was unexercised in CI. It runs from the
    project root because its fixture paths are relative to that.
    """
    print(f"\n{BLUE}--- Running ums_manifest ---{RESET}")

    source = PROJECT_ROOT / "ums" / "test_ums.psm"
    if not source.exists():
        print(f"{RED}[FAIL] ums: {source} is missing{RESET}")
        return False

    with tempfile.TemporaryDirectory(prefix="prismio-ums-") as temp_dir:
        exe = Path(temp_dir) / ("ums_test.exe" if os.name == "nt" else "ums_test")
        built = run_command([str(PRISMIO_EXE), "build", str(source), "-o", str(exe)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] ums: the test program did not build{RESET}")
            show_run(built)
            return False

        # subprocess directly rather than run_command: the fixture paths inside
        # test_ums.psm are relative to the project root, and run_command has no cwd.
        ran = subprocess.run([str(exe)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                             cwd=str(PROJECT_ROOT))
        if ran.returncode != 0 or "PASS:" not in (ran.stdout or ""):
            print(f"{RED}[FAIL] ums: manifest, resolution or lockfile assertions failed{RESET}")
            show_run(ran)
            return False

    print(f"{GREEN}[PASS] ums: manifest lowering, validation, build planning, dependency "
          f"resolution and the lockfile{RESET}")
    return True


@harness_test("ums_native_link", suite="ums", resources={"mem": 500}, timeout=300)
def run_ums_native_link_test():
    """Native linkage declared by an executable target reaches the real link."""
    print(f"\n{BLUE}--- Running ums_native_link ---{RESET}")

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
        # `library("answer")` names `answer.lib` on Windows, which is what
        # link.exe -- and clang targeting MSVC before it -- look for, and
        # `libanswer.a` everywhere else. The archive format is the same.
        answer_archive = native / ("answer.lib" if os.name == "nt" else "libanswer.a")
        native_steps = [
            [clang, "-c", str(native / "answer.c"), "-o", str(answer_object)],
            [archiver, "rcs", str(answer_archive), str(answer_object)],
            [clang, "-c", str(native / "bonus.c"), "-o", str(bonus_object)],
        ]
        for command in native_steps:
            step = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
            if step.returncode != 0:
                print(f"{RED}[FAIL] ums: native link fixture setup failed{RESET}")
                show_run(step)
                return False

        native_build = subprocess.run(
            [str(PRISMIO_EXE), "build"], capture_output=True, text=True, encoding="utf-8", errors="replace",
            cwd=str(project),
        )
        native_exe = (project / ".prismio" / "build" / "debug"
                      / ("native-link.exe" if os.name == "nt" else "native-link"))
        if native_build.returncode != 0 or not native_exe.exists():
            print(f"{RED}[FAIL] ums: declared native inputs did not link{RESET}")
            show_run(native_build)
            return False
        native_run = subprocess.run([str(native_exe)], capture_output=True, text=True, encoding="utf-8", errors="replace")
        if native_run.returncode != 0:
            print(f"{RED}[FAIL] ums: native-linked executable returned the wrong result{RESET}")
            show_run(native_run)
            return False

    print(f"{GREEN}[PASS] ums: declared native inputs link and run{RESET}")
    return True


def project_copy():
    """A copy of this checkout, as much of it as building the compiler reads.

    The compiler is described by the repository's own `build.ums`, so the only honest way to
    test host routing is against that project: the launcher protocol, upward discovery and the
    backend link are properties of *that* manifest, and a fixture cannot stand in for them. A
    copy has the same manifest and the same sources, and its project host is this test's own --
    these tests delete it, overwrite it with garbage and check that a hosted `clean` removes
    it, which done in the checkout took the developer's working compiler away for the length
    of the suite and made the scenarios wait for one another.
    """
    root = scratch() / "checkout"
    skipped = shutil.ignore_patterns("__pycache__", ".prismio*", "*.pyc")
    for directory in ("src", "runtime", "std", "lsp", "tools", "ums"):
        shutil.copytree(PROJECT_ROOT / directory, root / directory, ignore=skipped)
    shutil.copy2(PROJECT_ROOT / "build.ums", root / "build.ums")
    # A manifest command's script is checked to exist when the manifest is read.
    (root / "benchmarks").mkdir()
    shutil.copy2(PROJECT_ROOT / "benchmarks" / "run.py", root / "benchmarks" / "run.py")
    # The pinned LLVM is gigabytes; its response files name it by absolute path.
    os.symlink(PROJECT_ROOT / "third_party", root / "third_party", target_is_directory=True)
    return root.resolve()


def launcher_toolchain():
    """A toolchain as an install is, its compiler under the name `prismio`: what routes to a
    project host, and builds one with its own library. (path, environment)"""
    directory = scratch() / "launcher"
    launcher = directory / "bin" / ("prismio.exe" if os.name == "nt" else "prismio")
    launcher.parent.mkdir(parents=True)
    shutil.copy2(PRISMIO_EXE, launcher)
    for library in ("lib", "stdlib"):
        shutil.copytree(Path(PRISMIO_EXE).resolve().parent.parent / library, directory / library)
    environment = os.environ.copy()
    environment.pop("PRISMIO_INTERNAL_HOSTED", None)
    return launcher, environment


def host_paths(root):
    artifact = root / ".prismio" / "build" / HOST_PROFILE / (
        "prismio.exe" if os.name == "nt" else "prismio")
    artifact.parent.mkdir(parents=True, exist_ok=True)
    return artifact




@harness_test("ums_host_bootstrap", suite="ums", resources={"cpu": 2, "mem": 1500}, timeout=900)
def run_ums_host_bootstrap_test():
    """Stage 0 builds the first project host from an empty cache, the host builds itself, the
    manifest-built compiler emits the IR the tested one does, and the toolchain is beside it.

    Prismio is itself described by the repository's build.ums. A user-facing binary is named
    `prismio`; named bootstrap generations deliberately do not redirect, so the tested
    generation is copied under its launcher name. The first build has no host and therefore
    runs under stage 0. The second must forward the complete command before the local host
    parses build.ums.

    Building from a descendant directory covers upward discovery and, crucially,
    executable("prismio")'s backend component/LLVM link path: a model-only assertion cannot
    cover whether that component really links. The routing banner is asserted on stderr. It
    says which compiler is running, which is status rather than output, and while it went to
    stdout it prefixed `aif --manifest` with a human line and broke that format's one
    guarantee: that its first line is `aif-manifest 1`.
    """
    print(f"\n{BLUE}--- Running ums_host_bootstrap ---{RESET}")

    root = project_copy()
    launcher, launcher_env = launcher_toolchain()
    launcher_dir = launcher.parent.parent
    compiler_artifact = host_paths(root)
    cold_tmp = scratch() / "cold"
    cold_tmp.mkdir()

    # **A cold cache, always.** The first project build is the one that compiles the runtime
    # and writes the curated module and the native objects into the cache under TMPDIR. A warm
    # cache skips all of that, which is how a bad `free` on that path (a block from
    # command_quote_arg, a slab block, released with libc `free`) passed on every machine that had
    # built anything and aborted only in a fresh one: this suite's, and CI's.
    cold_env = dict(launcher_env, TMPDIR=str(cold_tmp))
    project_build = subprocess.run(
        [str(launcher), "build", *HOST_FLAGS], capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(root / "ums"), env=cold_env,
    )
    if (project_build.returncode != 0 or not compiler_artifact.exists()
            or "Using global toolchain" not in project_build.stderr):
        print(f"{RED}[FAIL] ums: stage 0 did not build the first project host{RESET}")
        # All three conditions, and both streams: printing only stdout
        # showed a successful build and hid which check had failed.
        print(f"host exists {compiler_artifact.exists()}")
        show_run(project_build)
        return False

    local_build = subprocess.run(
        [str(launcher), "build", *HOST_FLAGS], capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(root / "ums"), env=launcher_env,
    )
    if (local_build.returncode != 0
            or "Using local toolchain" not in local_build.stderr
            or "staged project compiler:" not in local_build.stdout
            or "promoted project compiler:" not in local_build.stdout):
        print(f"{RED}[FAIL] ums: the complete build command was not hosted{RESET}")
        show_run(local_build)
        return False

    # **The manifest-built compiler is the compiler under test.** It is
    # built from build.ums -- its C sources, `runtime = "none"`, the LLVM
    # response files -- rather than from a table inside the toolchain, and
    # the proof that the two recipes agree is that both compilers emit
    # the same IR for the compiler's own source.
    with tempfile.TemporaryDirectory(prefix="prismio-host-ir-") as ir_dir:
        ours = Path(ir_dir) / "tested.ll"
        theirs = Path(ir_dir) / "host.ll"
        env = dict(launcher_env, PRISMIO_INTERNAL_HOSTED="1")
        subprocess.run([str(PRISMIO_EXE), "build", "src/main.psm", "-o", str(ours)],
                       capture_output=True, cwd=str(root), env=env)
        subprocess.run([str(compiler_artifact), "build", "src/main.psm", "-o", str(theirs)],
                       capture_output=True, cwd=str(root), env=env)
        # Each reads the library of its own toolchain, so the paths its failure messages
        # name -- and the names and lengths of those strings -- are the only differences allowed.
        libraries = (Path(PRISMIO_EXE).resolve().parent.parent / "stdlib",
                     root / ".prismio" / "build" / "stdlib")
        if (not ours.is_file() or not theirs.is_file()
                or without_library_paths(ours, libraries) != without_library_paths(theirs, libraries)):
            print(f"{RED}[FAIL] ums: the compiler build.ums produces does not emit "
                  f"the IR the compiler under test emits{RESET}")
            return False

    # A host alone in a build directory can build itself and nothing
    # else: the runtime is installed bitcode with no source fallback, and
    # `lib/runtime` is looked for beside the executable. So the host
    # build produces the rest of the toolchain, and `.prismio/build` is a
    # prefix with the profile directory as its `bin`.
    build_root = root / ".prismio" / "build"
    local_runtime = build_root / "lib" / "runtime"
    local_stdlib = build_root / "stdlib"
    expected_runtime = {"lang_runtime.bc", "lang_runtime.verify.bc",
                        "program_support.bc", "program_support.verify.bc"}
    present = {p.name for p in local_runtime.glob("*.bc")}
    std_sources = {p.relative_to(root / "std").with_suffix("").as_posix()
                   for p in (root / "std").rglob("*.psm")}
    local_plibs = {p.relative_to(local_stdlib).with_suffix("").as_posix()
                   for p in local_stdlib.rglob("*.plib")}
    if (not expected_runtime <= present
            or not (build_root / "lib" / "runtime.hash").is_file()
            or local_plibs != std_sources):
        print(f"{RED}[FAIL] ums: the host build did not produce a usable "
              f"toolchain beside it{RESET}")
        print(f"runtime {sorted(present)}\n"
              f"stdlib missing {sorted(std_sources - local_plibs)}, "
              f"extra {sorted(local_plibs - std_sources)}")
        return False

    print(f"{GREEN}[PASS] ums: stage 0 and the hosted rebuild produce the project compiler "
          f"and its toolchain{RESET}")
    return True


@harness_test("ums_host_toolchain", suite="ums", resources={"cpu": 2, "mem": 1500}, timeout=900)
def run_ums_host_toolchain_test():
    """The toolchain beside a project host is rebuilt when the cache is bypassed and reused by
    the unchanged build after it."""
    print(f"\n{BLUE}--- Running ums_host_toolchain ---{RESET}")

    root = project_copy()
    launcher, launcher_env = launcher_toolchain()
    launcher_dir = launcher.parent.parent
    compiler_artifact = host_paths(root)
    for stage in ("stage 0",):
        built = subprocess.run(
            [str(launcher), "build", *HOST_FLAGS], capture_output=True, text=True, encoding="utf-8", errors="replace",
            cwd=str(root / "ums"), env=launcher_env,
        )
        if built.returncode != 0 or not compiler_artifact.exists():
            print(f"{RED}[FAIL] ums: the {stage} build of the project host failed{RESET}")
            show_run(built)
            return False
    build_root = root / ".prismio" / "build"
    local_runtime = build_root / "lib" / "runtime"
    local_stdlib = build_root / "stdlib"
    std_sources = {p.relative_to(root / "std").with_suffix("").as_posix()
                   for p in (root / "std").rglob("*.psm")}

    # **The second build must not build any of that again.** Emission
    # is four clang invocations and, per standard library module, two
    # compiler runs and two more clang runs -- 1.5s of an 8s self-build
    # on the machine this was measured on, spent reproducing files that
    # are already on disk byte for byte.
    #
    # Asserted against `PRISMIO_TOOLCHAIN_CACHE_TRACE` rather than
    # against mtimes or a stopwatch, for the reason the object cache
    # states: "the build was faster" is not an observation a test can
    # make reliably on a shared host, and an mtime comparison cannot tell
    # a file that was not rewritten from one that was rewritten with the
    # same bytes.
    #
    # Reuse is
    # cheap to get right and easy to get *wrong in the safe direction*
    # -- a cache that never hits still builds correctly -- so the test
    # that a hit is real is the test that a deleted artifact comes back
    # (`ums_host_repair`).
    cache_env = dict(launcher_env, PRISMIO_TOOLCHAIN_CACHE_TRACE="1")

    def toolchain_trace(env):
        run = subprocess.run(
            [str(launcher), "build", *HOST_FLAGS], capture_output=True, text=True, encoding="utf-8", errors="replace",
            cwd=str(root / "ums"), env=env,
        )
        reused, rebuilt = set(), set()
        for line in run.stderr.splitlines():
            if line.startswith("[toolchain reused] "):
                reused.add(line[len("[toolchain reused] "):])
            elif line.startswith("[toolchain rebuilt] "):
                rebuilt.add(line[len("[toolchain rebuilt] "):])
        return run, reused, rebuilt

    expected_entries = {"runtime"} | {f"std.{name.replace('/', '.')}" for name in std_sources}

    # The bypassed build is also the first hosted one, so the unchanged build after it is
    # the one that has to reuse everything.
    #
    # PRISMIO_TOOLCHAIN_CACHE=0 must not consult the stamp -- and must
    # still write one, so that a single bypassed build does not cost the
    # next one its hits too.
    off_run, off_reused, off_rebuilt = toolchain_trace(
        dict(cache_env, PRISMIO_TOOLCHAIN_CACHE="0"))
    if off_run.returncode != 0 or off_rebuilt != expected_entries or off_reused:
        print(f"{RED}[FAIL] ums: PRISMIO_TOOLCHAIN_CACHE=0 did not "
              f"rebuild the whole local toolchain{RESET}")
        print(f"reused {sorted(off_reused)}\nrebuilt {sorted(off_rebuilt)}")
        return False

    # Every stdlib key hashes the compiler binary, so a stdlib miss here
    # usually means the host relinked to different bytes. Which bytes is
    # what the fix depends on (a PE timestamp, a debug-info path, a
    # temporary's name), so a failure says where they differ.
    host_before = compiler_artifact.read_bytes()
    cached_run, reused, rebuilt = toolchain_trace(cache_env)
    if cached_run.returncode != 0 or reused != expected_entries or rebuilt:
        print(f"{RED}[FAIL] ums: an unchanged rebuild did not reuse the "
              f"local toolchain{RESET}")
        print(f"reused {sorted(reused)}\nrebuilt {sorted(rebuilt)}")
        host_after = compiler_artifact.read_bytes()
        offsets = [i for i, (a, b) in enumerate(zip(host_before, host_after))
                   if a != b]
        print(f"host {len(host_before)} -> {len(host_after)} bytes, "
              f"{len(offsets)} differ in the common length")
        for offset in offsets[:8]:
            start = max(0, offset - 16)
            print(f"  @{offset:#x}: {host_before[start:offset + 16]!r}")
            print(f"  {' ' * len(f'@{offset:#x}')}  {host_after[start:offset + 16]!r}")
        return False

    print(f"{GREEN}[PASS] ums: a bypassed build rebuilds the host's whole toolchain, and the "
          f"unchanged build after it reuses it{RESET}")
    return True


@harness_test("ums_host_repair", suite="ums", resources={"cpu": 2, "mem": 1500}, timeout=900)
def run_ums_host_repair_test():
    """A deleted toolchain artifact is rebuilt rather than served from the stamp, and the
    project host builds a program outside the checkout."""
    print(f"\n{BLUE}--- Running ums_host_repair ---{RESET}")

    root = project_copy()
    launcher, launcher_env = launcher_toolchain()
    launcher_dir = launcher.parent.parent
    compiler_artifact = host_paths(root)
    for stage in ("stage 0", "hosted"):
        built = subprocess.run(
            [str(launcher), "build", *HOST_FLAGS], capture_output=True, text=True, encoding="utf-8", errors="replace",
            cwd=str(root / "ums"), env=launcher_env,
        )
        if built.returncode != 0 or not compiler_artifact.exists():
            print(f"{RED}[FAIL] ums: the {stage} build of the project host failed{RESET}")
            show_run(built)
            return False
    build_root = root / ".prismio" / "build"
    local_runtime = build_root / "lib" / "runtime"
    local_stdlib = build_root / "stdlib"
    std_sources = {p.relative_to(root / "std").with_suffix("").as_posix()
                   for p in (root / "std").rglob("*.psm")}

    cache_env = dict(launcher_env, PRISMIO_TOOLCHAIN_CACHE_TRACE="1")

    def toolchain_trace(env):
        run = subprocess.run(
            [str(launcher), "build", *HOST_FLAGS], capture_output=True, text=True, encoding="utf-8", errors="replace",
            cwd=str(root / "ums"), env=env,
        )
        reused, rebuilt = set(), set()
        for line in run.stderr.splitlines():
            if line.startswith("[toolchain reused] "):
                reused.add(line[len("[toolchain reused] "):])
            elif line.startswith("[toolchain rebuilt] "):
                rebuilt.add(line[len("[toolchain rebuilt] "):])
        return run, reused, rebuilt

    expected_entries = {"runtime"} | {f"std.{name.replace('/', '.')}" for name in std_sources}

    # A missing artifact is not a stale one, and the key cannot see it:
    # the inputs are unchanged, so only the existence check stands
    # between a hit and a toolchain with a hole in it. A module no target of this
    # project imports: the host compiles the compiler against this library, so a hole in
    # a module it does import is repaired by `prismio bootstrap --promote` instead.
    missing_plib = local_stdlib / "sys" / "asm.plib"
    missing_bc = local_runtime / "program_support.verify.bc"
    missing_plib.unlink()
    missing_bc.unlink()
    repair_run, _, repaired = toolchain_trace(cache_env)
    if (repaired != {"runtime", "std.sys.asm"}
            or not missing_plib.is_file() or not missing_bc.is_file()):
        print(f"{RED}[FAIL] ums: a deleted toolchain artifact was served "
              f"from the stamp instead of rebuilt{RESET}")
        print(f"rebuilt {sorted(repaired)}")
        # Seen once in a full run (2026-09-24) and never in isolation, with
        # `rebuilt []` -- which a build that failed outright also reads as.
        show_run(repair_run)
        return False

    # The behaviour all of that is for: a program outside the checkout,
    # built by the project host against the toolchain built beside it.
    with tempfile.TemporaryDirectory(prefix="prismio-outside-") as outside_dir:
        outside = Path(outside_dir) / "outside.psm"
        outside.write_text(
            "import std.io\n"
            "import std.string\n\n"
            "fn main() -> Int {\n"
            '    let greeting = "local".concat("-toolchain")\n'
            "    println(greeting)\n"
            "    return 0\n"
            "}\n",
            encoding="utf-8")
        outside_exe = Path(outside_dir) / ("outside.exe" if os.name == "nt" else "outside")
        outside_build = subprocess.run(
            [str(compiler_artifact), "build", str(outside),
             "-o", str(outside_exe)],
            capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=outside_dir, env=launcher_env)
        outside_run = (subprocess.run([str(outside_exe)], capture_output=True,
                                      text=True, encoding="utf-8", errors="replace")
                       if outside_exe.is_file() else None)
        if (outside_build.returncode != 0 or outside_run is None
                or outside_run.stdout.strip() != "local-toolchain"):
            print(f"{RED}[FAIL] ums: the project host cannot build a "
                  f"program outside the checkout{RESET}")
            show_run(outside_build)
            return False

    print(f"{GREEN}[PASS] ums: the host's toolchain is repaired, and builds outside the "
          f"checkout{RESET}")
    return True


@harness_test("ums_host_trust", suite="ums", resources={"cpu": 2, "mem": 1500}, timeout=900)
def run_ums_host_trust_test():
    """A host this machine did not promote is never run, a stale one is cleaned or rebuilt, the
    host-generation handshake answers for the compiler asked, and a host cannot replace itself."""
    print(f"\n{BLUE}--- Running ums_host_trust ---{RESET}")

    root = project_copy()
    launcher, launcher_env = launcher_toolchain()
    launcher_dir = launcher.parent.parent
    compiler_artifact = host_paths(root)

    # A stand-in for that older generation, rather than a kept copy of
    # one: what is under test is the handshake, not any particular
    # release. It starts, it answers `--version`, and it rejects
    # `--internal-host-abi` the way a compiler that predates the command
    # rejects an unknown argument. C rather than a shell script because
    # the launcher spawns a host as an executable image, which on Windows
    # a `.cmd` is not.
    clang_path = shutil.which("clang")
    if not clang_path:
        print(f"{RED}[FAIL] ums: clang is required to build the stale-host "
              f"stand-in{RESET}")
        return False
    stale_source = Path(launcher_dir) / "stale_host.c"
    stale_source.write_text(
        "#include <string.h>\n"
        "int main(int argc, char** argv) {\n"
        "    for (int i = 1; i < argc; i++) {\n"
        '        if (strcmp(argv[i], "--internal-host-abi") == 0) return 1;\n'
        "    }\n"
        "    return 0;\n"
        "}\n",
        encoding="utf-8",
    )
    stale_host = Path(launcher_dir) / ("stale.exe" if os.name == "nt" else "stale")
    stale_built = subprocess.run(
        [clang_path, str(stale_source), "-o", str(stale_host)],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    if stale_built.returncode != 0:
        print(f"{RED}[FAIL] ums: could not build the stale-host stand-in{RESET}")
        show_run(stale_built)
        return False

    # **A host this machine did not promote is never started**, for any
    # command -- `--version` and `check` included, which an editor sends
    # when a file is opened. The stand-in writes a marker when it runs, so
    # "not run" is observed rather than inferred from the output.
    marker = Path(launcher_dir) / "untrusted-ran"
    marker_source = Path(launcher_dir) / "marker_host.c"
    marker_source.write_text(
        "#include <stdio.h>\n"
        "int main(void) {\n"
        f"    FILE* f = fopen({json.dumps(str(marker))}, \"w\");\n"
        "    if (f) fclose(f);\n"
        "    return 0;\n"
        "}\n",
        encoding="utf-8",
    )
    marker_host = Path(launcher_dir) / ("marker.exe" if os.name == "nt" else "marker")
    if subprocess.run([clang_path, str(marker_source), "-o", str(marker_host)],
                      capture_output=True).returncode != 0:
        print(f"{RED}[FAIL] ums: could not build the untrusted-host stand-in{RESET}")
        return False
    shutil.copy2(marker_host, compiler_artifact)
    untrusted = subprocess.run(
        [str(launcher), "--version"], capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(root), env=launcher_env,
    )
    if (marker.exists() or "P1077" not in untrusted.stderr
            or "Using global toolchain" not in untrusted.stderr):
        print(f"{RED}[FAIL] ums: a project host this machine did not build was run{RESET}")
        print(f"marker written: {marker.exists()}")
        show_run(untrusted)
        return False

    # `clean` is the one command exempt from the repair. It removes this
    # project's artifacts and then the launcher removes the host itself,
    # so rebuilding the binary about to be deleted is work thrown away.
    shutil.copy2(stale_host, compiler_artifact)
    trust_host(compiler_artifact)
    stale_clean = subprocess.run(
        [str(launcher), "clean", *HOST_FLAGS], capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(root / "ums"), env=launcher_env,
    )
    stale_clean_output = stale_clean.stdout + stale_clean.stderr
    if (stale_clean.returncode != 0 or "P1064" in stale_clean_output
            or compiler_artifact.exists()):
        print(f"{RED}[FAIL] ums: `clean` rebuilt the host it was about to "
              f"delete{RESET}")
        print(stale_clean_output)
        return False

    # Every other command repairs first, then runs. `--version` is
    # forwarded here because the assertion is about the rebuild in front
    # of it: the repair is stage 0 building and promoting a new host, and
    # the command that follows must reach *that* binary.
    shutil.copy2(stale_host, compiler_artifact)
    trust_host(compiler_artifact)
    repaired = subprocess.run(
        [str(launcher), "--version"], capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(root), env=launcher_env,
    )
    repaired_output = repaired.stdout + repaired.stderr
    if (repaired.returncode != 0 or "P1064" not in repaired_output
            or "Using global toolchain" not in repaired_output
            or "promoted project compiler:" not in repaired.stdout
            or "Using local toolchain" not in repaired.stderr
            or f"prismio {project_version()}" not in repaired.stdout):
        print(f"{RED}[FAIL] ums: a stale project host was not rebuilt "
              f"before the command it could not have served{RESET}")
        print(repaired_output)
        return False

    forwarded_version = subprocess.run(
        [str(launcher), "--version"], capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(root), env=launcher_env,
    )
    # The repair is not a per-command tax: the host it promoted answers
    # the handshake, so this second command forwards with no rebuild.
    if "P1064" in forwarded_version.stdout + forwarded_version.stderr:
        print(f"{RED}[FAIL] ums: a repaired host was rebuilt again by the "
              f"next command{RESET}")
        show_run(forwarded_version)
        return False
    if (forwarded_version.returncode != 0
            or "Using local toolchain" not in forwarded_version.stderr
            or f"prismio {project_version()}" not in forwarded_version.stdout):
        print(f"{RED}[FAIL] ums: a non-build command was not forwarded to the host{RESET}")
        show_run(forwarded_version)
        return False

    # The generation handshake, on its own, before the routing built on
    # it. It exists because the one failure the launcher cannot see by
    # starting a host is a host from an earlier generation: it runs, it
    # answers `--version`, and the code it emits names runtime symbols
    # the installed runtime no longer defines. `list_set_elem_inline` was
    # exactly that, and the linker reported it as undefined references
    # from *generated* functions -- nothing in that output named the
    # compiler that emitted them.
    abi = subprocess.run(
        [str(launcher), "--internal-host-abi"], capture_output=True,
        text=True, encoding="utf-8", errors="replace", cwd=str(root), env=launcher_env,
    )
    token = abi.stdout.strip()
    agrees = subprocess.run(
        [str(launcher), "--internal-host-abi", token], capture_output=True,
        text=True, encoding="utf-8", errors="replace", cwd=str(root), env=launcher_env,
    )
    disagrees = subprocess.run(
        [str(launcher), "--internal-host-abi", token + "-other"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(root),
        env=launcher_env,
    )
    # Asked in a project with a host, and answered by the binary asked.
    # A forwarded answer would describe the host rather than the compiler
    # holding the question, and the launcher's own probe would recurse.
    if (not token or agrees.returncode != 0 or disagrees.returncode == 0
            or "Using local toolchain" in abi.stderr):
        print(f"{RED}[FAIL] ums: the host-generation handshake does not "
              f"answer for the compiler asked{RESET}")
        print(abi.stdout + abi.stderr + agrees.stderr + disagrees.stderr)
        return False

    # A direct local invocation has no global parent waiting to promote its
    # sibling candidate, so it must fail rather than overwrite itself.
    self_build = subprocess.run(
        [str(compiler_artifact), "build", *HOST_FLAGS], capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(root), env=launcher_env,
    )
    if self_build.returncode == 0 or "P1051" not in (self_build.stdout + self_build.stderr):
        print(f"{RED}[FAIL] ums: a project compiler tried to replace itself{RESET}")
        show_run(self_build)
        return False

    print(f"{GREEN}[PASS] ums: untrusted and stale hosts, the handshake and self-replacement"
          f"{RESET}")
    return True


@harness_test("ums_host_fallback", suite="ums", resources={"cpu": 2, "mem": 1500}, timeout=900)
def run_ums_host_fallback_test():
    """A project host that cannot start falls back to stage 0, and a hosted `clean` removes
    the compiler after it exits."""
    print(f"\n{BLUE}--- Running ums_host_fallback ---{RESET}")

    root = project_copy()
    launcher, launcher_env = launcher_toolchain()
    launcher_dir = launcher.parent.parent
    compiler_artifact = host_paths(root)

    # A corrupt active generation falls back to stage 0 rather than becoming
    # a permanent dead end. The command is not replayed after a host failure;
    # fallback happens only because the preflight could not start the host.
    # Trusted first, so this reaches the start check rather than stopping
    # at the stamp -- an overwritten host no longer matches its own.
    compiler_artifact.write_bytes(b"not a Prismio compiler\n")
    trust_host(compiler_artifact)
    fallback_build = subprocess.run(
        [str(launcher), "build", *HOST_FLAGS], capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(root), env=launcher_env,
    )
    fallback_output = fallback_build.stdout + fallback_build.stderr
    if (fallback_build.returncode != 0 or "P1052" not in fallback_output
            or "Using global toolchain" not in fallback_output):
        print(f"{RED}[FAIL] ums: a broken project compiler did not fall back to stage 0{RESET}")
        print(fallback_output)
        return False

    clean = subprocess.run(
        [str(launcher), "clean", *HOST_FLAGS], capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(root / "ums"), env=launcher_env,
    )
    if (clean.returncode != 0 or compiler_artifact.exists()
            or "Using local toolchain" not in clean.stderr):
        print(f"{RED}[FAIL] ums: hosted clean did not remove the compiler after it exited{RESET}")
        show_run(clean)
        return False

    print(f"{GREEN}[PASS] ums: fallback to stage 0 and hosted clean{RESET}")
    return True


@harness_test(suite="ums")
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
                       capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(PROJECT_ROOT))
    said = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0 or "OK" not in said:
        print(f"{RED}[FAIL] incremental manifest{RESET}")
        print("  - " + (said.strip()[-500:] or f"exit {r.returncode}"))
        return False

    print(f"{GREEN}[PASS] incremental manifest: cold and incremental agree, "
          f"discriminating, reversible and budget-sensitive{RESET}")
    return True


def run_runtime_library_test():
    """A packaged toolchain links the prebuilt runtime archive, and a foreign target does not.

    `tools/package.py` builds `lib/runtime.a` and, until this test, nothing in the
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

    Nine assertions:

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
         root where the sources are visible. This is what keeps `package.py` and
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

    package = [sys.executable, str(PROJECT_ROOT / "tools" / "package.py")]

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
        # One argument spelling on every platform. This used to branch, because
        # packaging was a .sh/.ps1 pair and PowerShell took `-Compiler`; the
        # Windows arm outlived the script it was written for and would have
        # failed there against tools/package.py.
        package += ["--compiler", str(compiler), "--out", str(dist)]

        packaged = subprocess.run(package, capture_output=True, text=True, encoding="utf-8", errors="replace",
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

        # The same binary under a name that is not the launcher's.
        #
        # `isGlobalLauncher` is a test on argv[0]: a binary called `prismio`
        # forwards the whole command to the project host named by the nearest
        # `build.ums`. Checks 6 and 7 build from the repository root, where that
        # manifest is *this* project's -- so under its installed name the packaged
        # compiler hands the command to `.prismio/build/debug/prismio` and the
        # freshness guard it is being asked about never runs.
        #
        # That went unnoticed because `run_ums_test` deletes the project host and
        # used to leave it deleted, so by the time this test ran there was nothing
        # to forward to. The checks passed on an accident of ordering. Naming the
        # probe copy something else is the same trick the repository already uses
        # for `build/gen1` and `build/gen2`, and for the same reason: a named
        # generation is an exact tool, not a launcher.
        exe_suffix = ".exe" if os.name == "nt" else ""
        probe_compiler = installed.with_name("prismio-probe" + exe_suffix)
        shutil.copy2(installed, probe_compiler)

        def build(args, cwd=wd, compiler=None, source=None):
            env = dict(os.environ, PRISMIO_OBJ_CACHE_DIR=str(cache),
                       PRISMIO_OBJ_CACHE_TRACE="1")
            return subprocess.run([str(compiler or installed), "build", str(source or probe)] + args,
                                  capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(cwd),
                                  env=env)

        # One line per toolchain source the fallback compiled -- hit, miss or
        # off. Any of the three means the archive was not what got linked.
        def from_source(r):
            return "[objcache" in (r.stderr or "")

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
                          cwd=PROJECT_ROOT, compiler=probe_compiler)
            if fresh.returncode != 0 or "stale" in (fresh.stdout or "") + (fresh.stderr or ""):
                problems.append("a toolchain packaged from these very sources was "
                                "reported stale against them: packaging and "
                                "compiler_runtime_source_hash disagree about the "
                                "hash")

            recorded = hash_file.read_text()
            bogus = "1" * 16 if recorded.strip().startswith("0") else "0" * 16
            hash_file.write_text(bogus)
            stale = build(["-o", str(wd / ("probe_stale" + exe_suffix))],
                          cwd=PROJECT_ROOT, compiler=probe_compiler)
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
        script = PROJECT_ROOT / "tools" / "verify_separation.py"
        symbols = which("llvm-nm") or (None if os.name == "nt" else which("nm"))
        command = [sys.executable, str(script), "--dist", str(dist)]

        if not symbols:
            # The script exits 1 for a missing nm exactly as it does for a failed
            # check, so the two are told apart here rather than by its exit code.
            separation = "skipped -- no nm or llvm-nm on PATH"
        else:
            ran = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace",
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


def plib_meta(path):
    """A PLIB v4's metadata lines."""
    data = path.read_bytes()
    module_len, meta_len = struct.unpack_from("<II", data, 8)
    return data[28 + module_len:28 + module_len + meta_len].decode("utf-8", "replace").splitlines()


def run_plib_triple_sections(compiler_source, work, env, llvm_dis, problems):
    """A cross build takes `std` bitcode compiled for its own target.

    A PLIB used to carry one code section, built for the host, and every build
    merged it whatever `--target` said: an arm64 Mac building for
    x86_64-apple-macos linked arm64 bitcode for every non-generic `std` function,
    LLVM warned that the triples and data layouts differed, and the build
    succeeded. Packaging a target now adds a section for it, and a triple with
    runtime bitcode but no section is refused.

    Needs a C SDK for the target, because packaging compiles the runtime for it;
    only a macOS host with Xcode has one for a second architecture. The binary is
    not run -- Rosetta may be absent -- so the assertion is on what the linker
    said and what `file` reports.
    """
    target = "x86_64-apple-macos"
    sdk = ""
    if sys.platform == "darwin" and shutil.which("xcrun"):
        probe = subprocess.run(["xcrun", "--show-sdk-path"], capture_output=True, text=True, encoding="utf-8", errors="replace")
        sdk = probe.stdout.strip() if probe.returncode == 0 else ""
    if not sdk:
        return "skipped: no second-architecture SDK on this host"

    dist = work / "cross-dist"
    packaged = subprocess.run(
        [sys.executable, str(PROJECT_ROOT / "tools" / "package.py"),
         "--compiler", str(compiler_source), "--out", str(dist),
         "--target", target, "--sysroot", f"{target}={sdk}"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(PROJECT_ROOT), env=env)
    if packaged.returncode != 0:
        problems.append(f"packaging with --target {target} failed: "
                        + (packaged.stderr or packaged.stdout).strip()[-300:])
        return "failed"

    for module in ("lang_runtime", "program_support"):
        for variant in ("", ".verify"):
            if not (dist / "lib" / "runtime" / target / f"{module}{variant}.bc").is_file():
                problems.append(f"--target {target} did not package "
                                f"lib/runtime/{target}/{module}{variant}.bc")
    io_plib = dist / "stdlib" / "io" / "output.plib"
    sections = plib_sections(io_plib) if io_plib.is_file() else None
    if sections is None or [t for t, _ in sections] != ["", target]:
        problems.append(f"io/output.plib from a --target {target} package has sections "
                        f"{None if sections is None else [t for t, _ in sections]}, "
                        f"expected ['', '{target}']")
    elif llvm_dis:
        bitcode = work / "io-cross.bc"
        bitcode.write_bytes(sections[1][1])
        shown = subprocess.run([str(llvm_dis), str(bitcode), "-o", "-"],
                               capture_output=True, text=True, encoding="utf-8", errors="replace")
        if not re.search(r'^target triple = "x86_64-', shown.stdout, re.M):
            problems.append(f"io/output.plib's {target} section is not x86_64 bitcode")

    compiler = dist / "bin" / "prismio"
    asker = work / "cross-asker.psm"
    asker.write_text('import std.io\nimport std.string\nimport std.platform\n\n'
                     'fn main() -> Int {\n'
                     '    if (platform.isMacOS) { println("macos".concat("!")) }\n'
                     '    return 0\n}\n')
    built = subprocess.run([str(compiler), "build", str(asker), "--target", target,
                            "--sysroot", sdk, "-o", str(work / "cross-asker")],
                           capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(work), env=env)
    said = (built.stdout or "") + (built.stderr or "")
    if built.returncode != 0:
        problems.append(f"a {target} build against its packaged sections failed: "
                        + said.strip()[-300:])
    elif "different target triples" in said or "different data layouts" in said:
        problems.append(f"a {target} build still merged bitcode for another target: "
                        + said.strip()[-300:])
    elif "x86_64" not in subprocess.run(["file", str(work / "cross-asker")],
                                        capture_output=True, text=True, encoding="utf-8", errors="replace").stdout:
        problems.append(f"the {target} build did not produce an x86_64 binary")

    # Runtime bitcode for a triple the PLIBs were not packaged for: the build
    # must refuse rather than fall back to some other section.
    unpackaged = "x86_64-apple-darwin"
    shutil.copytree(dist / "lib" / "runtime" / target,
                    dist / "lib" / "runtime" / unpackaged)
    refused = subprocess.run([str(compiler), "build", str(asker), "--target", unpackaged,
                              "--sysroot", sdk, "-o", str(work / "refused")],
                             capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(work), env=env)
    said = (refused.stdout or "") + (refused.stderr or "")
    if refused.returncode == 0 or \
            f"Missing standard-library bitcode for {unpackaged}" not in said:
        problems.append(f"a build for {unpackaged}, whose PLIB section was never "
                        "packaged, was not refused naming it: " + said.strip()[-300:])
    return f"{target} sections packaged and linked"


@harness_test("module_artifacts", suite="ums", resources={"cpu": 3, "mem": 1500, "objcache": EXCLUSIVE})
def run_module_artifact_test():
    """Installed std/runtime artifacts are sharded, mandatory, and executable."""
    print(f"\n{BLUE}--- Running module_artifacts ---{RESET}")
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-module-artifacts-") as tmp:
        wd = Path(tmp)
        dist = wd / "dist"
        package = subprocess.run(
            [sys.executable, str(PROJECT_ROOT / "tools" / "package.py"),
             "--compiler", str(Path(PRISMIO_EXE).resolve()), "--out", str(dist)],
            capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(PROJECT_ROOT),
            env=dict(os.environ, PRISMIO_INTERNAL_HOSTED="1"))
        if package.returncode != 0:
            print(f"{RED}[FAIL] module artifacts: packaging failed{RESET}")
            print("  " + (package.stderr or package.stdout).strip()[-500:])
            return False

        runtime = dist / "lib" / "runtime"
        expected_runtime = {
            "lang_runtime.bc", "lang_runtime.verify.bc",
            "program_support.bc", "program_support.verify.bc",
        }
        actual_runtime = {path.name for path in runtime.glob("*.bc")}
        if actual_runtime != expected_runtime:
            problems.append(f"runtime modules are {sorted(actual_runtime)}, expected "
                            f"{sorted(expected_runtime)}")
        if any((dist / "lib" / name).exists()
               for name in ("runtime.a", "runtime.lib", "runtime.bc")):
            problems.append("a monolithic runtime archive/bitcode artifact was shipped")

        expected_std = {path.relative_to(PROJECT_ROOT / "std").with_suffix(".plib").as_posix()
                        for path in (PROJECT_ROOT / "std").rglob("*.psm")}
        actual_std = {path.relative_to(dist / "stdlib").as_posix()
                      for path in (dist / "stdlib").rglob("*.plib")}
        if actual_std != expected_std:
            problems.append("stdlib PLIB set does not match std/**/*.psm")
        if list((dist / "stdlib").rglob("*.psm")):
            problems.append("standard-library source files were shipped")
        option = next((dist / "stdlib").rglob("option.plib"), None)
        if option is not None:
            meta = plib_meta(option)
            if "module prelude freestanding" not in meta or not any(
                    line.startswith("lang option_coalesce ") for line in meta):
                problems.append(f"option.plib's metadata lacks its header or lang items: {meta}")
        for plib in (dist / "stdlib").rglob("*.plib"):
            sections = plib_sections(plib)
            if sections is None:
                problems.append(f"{plib.name} is not a PLIB v4 artifact")
            elif [triple for triple, _ in sections] != [""]:
                problems.append(f"{plib.name} carries sections {[t for t, _ in sections]} "
                                "from a package run that named no --target")

        compiler = dist / "bin" / ("prismio.exe" if os.name == "nt" else "prismio")
        source = wd / "probe.psm"
        source.write_text('import std.io\nimport std.string\n\n'
                          'fn main() -> Int {\n'
                          '    println("module".concat("-", "wise"))\n'
                          '    return 0\n}\n')
        env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")

        def build(output, extra=None):
            return subprocess.run(
                [str(compiler), "build", str(source), *(extra or []),
                 "-o", str(output)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                cwd=str(wd), env=env)

        # The allocation contract must be semantic LLVM IR, not a string that
        # merely prints like an attribute and is ignored by optimization.
        contract_ir = wd / "contract.ll"
        contract = build(contract_ir)
        contract_text = contract_ir.read_text() if contract_ir.exists() else ""
        if (contract.returncode != 0
                or 'allockind("alloc,uninitialized")' not in contract_text
                or 'allockind("free")' not in contract_text
                or '"allockind"=' in contract_text
                or "allocptr" not in contract_text):
            problems.append("allocator/deallocator semantics were not preserved in LLVM IR")

        # Production bitcode uses an immutable layout constructor. The mutable
        # post-construction stamp exists only under PRISMIO_BOOTSTRAP_COMPAT so
        # a preceding compiler generation can build the next one.
        llvm_dis = pinned_llvm_tool("llvm-dis")
        if llvm_dis:
            runtime_ir = wd / "lang_runtime.ll"
            disassembled = subprocess.run(
                [str(llvm_dis), str(runtime / "lang_runtime.bc"), "-o", str(runtime_ir)],
                capture_output=True, text=True, encoding="utf-8", errors="replace")
            runtime_text = runtime_ir.read_text() if runtime_ir.exists() else ""
            if (disassembled.returncode != 0
                    or not re.search(r'^define[^@]*@list_new_inline\(', runtime_text, re.M)
                    or re.search(r'^define[^@]*@list_set_elem_inline\(', runtime_text, re.M)):
                problems.append("production runtime does not enforce immutable list layout")

        for name, extra in (("normal", []), ("verify", ["--verify"])):
            executable = wd / (name + (".exe" if os.name == "nt" else ""))
            made = build(executable, extra)
            ran = (subprocess.run([str(executable)], capture_output=True, text=True, encoding="utf-8", errors="replace")
                   if executable.exists() else None)
            if (made.returncode != 0 or ran is None or ran.returncode != 0
                    or ran.stdout.strip() != "module-wise"):
                problems.append(f"packaged {name} build did not compile and run")

        # A module path from before the library had folders resolves where it is now, and says so.
        renamed = wd / "renamed.psm"
        renamed.write_text('import std.io\nimport std.option\nfrom std import {vec}\n\n'
                           'fn main() -> Int {\n    let v: Vec<Int> = [1]\n'
                           '    println(v.first)\n    return 0\n}\n')
        made = subprocess.run([str(compiler), "build", str(renamed), "-o", str(wd / "renamed")],
                              capture_output=True, text=True, encoding="utf-8", errors="replace",
                              cwd=str(wd), env=env)
        said = made.stdout + made.stderr
        for old in ("std.option", "std.vec"):
            if made.returncode != 0 or "P1135" not in said or f"`{old}` needs no import" not in said:
                problems.append(f"an import of {old} did not resolve with a warning: {said[-300:]}")

        # Imported functions with no IR users are removed after the final
        # module merge. This keeps full bitcode from turning every executable
        # into an export of the entire runtime surface.
        nm = shutil.which("nm")
        normal_exe = wd / ("normal" + (".exe" if os.name == "nt" else ""))
        if nm and normal_exe.exists():
            symbols = subprocess.run(
                [nm, str(normal_exe)], capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
            if "data_view_to_list" in symbols:
                problems.append("an unreachable runtime function survived whole-program pruning")

        missing_path = runtime / "program_support.bc"
        aside = runtime / "program_support.bc.aside"
        missing_path.rename(aside)
        missing = build(wd / "missing")
        aside.rename(missing_path)
        said = (missing.stdout or "") + (missing.stderr or "")
        if (missing.returncode == 0 or "Missing runtime module" not in said
                or "Reinstall Prismio" not in said):
            problems.append("a missing runtime module did not demand reinstall")

        original = missing_path.read_bytes()
        missing_path.write_bytes(b"not LLVM bitcode")
        corrupt = build(wd / "corrupt")
        missing_path.write_bytes(original)
        said = (corrupt.stdout or "") + (corrupt.stderr or "")
        if (corrupt.returncode == 0 or "runtime module is invalid" not in said
                or "Reinstall Prismio" not in said):
            problems.append("a corrupt runtime module did not demand reinstall")

        separation = subprocess.run(
            [sys.executable, str(PROJECT_ROOT / "tools" / "verify_separation.py"),
             "--dist", str(dist)], capture_output=True, text=True, encoding="utf-8", errors="replace",
            cwd=str(PROJECT_ROOT), env=env)
        if separation.returncode != 0:
            problems.append("verify_separation.py rejected the packaged artifacts")

        # `std.platform` from the installed `stdlib/platform.plib`. Its answers
        # must be the program's target's, and a PLIB's bitcode is built once, for
        # the host -- so a function that asks the target is left out of the PLIB
        # and compiled into the program (`shouldEmitFunctionFromSource`). Natively
        # that must still link, with no second definition coming from the PLIB;
        # for a foreign triple the IR must define `isWindows` itself, answering
        # for that target. Declared instead, it would be the PLIB's host answer.
        asker = wd / "asker.psm"
        asker.write_text('import std.io\nimport std.platform\n\n'
                         'fn main() -> Int {\n'
                         '    if (platform.isWindows) { println("windows") }\n'
                         '    if (platform.isLinux) { println("linux") }\n'
                         '    if (platform.isMacOS) { println("macos") }\n'
                         '    return 0\n}\n')
        asker_exe = wd / ("asker" + (".exe" if os.name == "nt" else ""))
        asked = subprocess.run([str(compiler), "build", str(asker), "-o", str(asker_exe)],
                               capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(wd), env=env)
        answered = (subprocess.run([str(asker_exe)], capture_output=True, text=True, encoding="utf-8", errors="replace")
                    if asker_exe.exists() else None)
        named = (answered.stdout or "").split() if answered else []
        if asked.returncode != 0 or answered is None or len(named) != 1:
            problems.append("a program asking std.platform could not be built against "
                            "the installed stdlib/platform.plib, or did not name exactly "
                            f"one platform: {named!r} "
                            + ((asked.stdout or "") + (asked.stderr or "")).strip()[-200:])
        asker_ll = wd / "asker-windows.ll"
        cross = subprocess.run([str(compiler), "build", str(asker), "--target",
                                "x86_64-pc-windows-msvc", "-o", str(asker_ll)],
                               capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(wd), env=env)
        body = None
        if cross.returncode == 0 and asker_ll.exists():
            body = re.search(r'define i1 @"?isWindows__[^\n]*\{(.*?)\n\}',
                             asker_ll.read_text(encoding="utf-8", errors="replace"), re.S)
        if body is None or "ret i1 true" not in body.group(1):
            problems.append("built for x86_64-pc-windows-msvc against the installed "
                            "stdlib, `isWindows` is not defined in the program "
                            "answering true: the host-built PLIB supplied it")

        # `sort` from the installed `stdlib/collections/vec.plib`, on the two element
        # representations it is most used at. `sort` hands `sortBy` a closure,
        # and the closure's `call` is lowered inside the program's instantiation
        # of a `.plib` generic. It was once filtered out as a concrete stdlib
        # function the PLIB supplies, so every installed program calling `sort`
        # failed to link -- and no fixture under `tests/` can see that, because
        # `std.*` resolves from source by walking up from the entry file.
        sorter = wd / "sorter.psm"
        sorter.write_text('import std.io\n\n'
                          'fn main() -> Int {\n'
                          '    let mut numbers: Vec<Int> = [3, 1, 2]\n'
                          '    sort(numbers)\n'
                          '    let mut words: Vec<String> = ["pear", "apple"]\n'
                          '    sort(words)\n'
                          '    if (isSorted(numbers) and isSorted(words)) { println("sorted") }\n'
                          '    return 0\n}\n')
        sorter_exe = wd / ("sorter" + (".exe" if os.name == "nt" else ""))
        sorted_build = subprocess.run([str(compiler), "build", str(sorter), "-o", str(sorter_exe)],
                                      capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(wd), env=env)
        sorted_run = (subprocess.run([str(sorter_exe)], capture_output=True, text=True, encoding="utf-8", errors="replace")
                      if sorter_exe.exists() else None)
        if (sorted_build.returncode != 0 or sorted_run is None
                or (sorted_run.stdout or "").strip() != "sorted"):
            said = (sorted_build.stdout or "") + (sorted_build.stderr or "")
            problems.append("a program calling `sort` could not be built against "
                            "the installed stdlib/collections/vec.plib: "
                            + (said.strip()[-300:] if sorted_run is None else
                               f"it ran and printed {(sorted_run.stdout or '').strip()!r}"))

        # A struct crossing a PLIB. `sort` and `std.platform` are functions; this
        # is the program writing fields of `std.process`'s `Process` and the
        # PLIB's `spawn` reading them. Each side used to lay the struct out from
        # its own access profile, and assigning `stdout` -- the one mode this
        # program writes -- moved it ahead of `stdin` in the program only. Every
        # mode then arrived one field off: the discarded child printed, the piped
        # one was not redirected, and `out` was empty. No diagnostic either way,
        # and nothing under `tests/` can see it, because std resolves from source
        # there.
        crossing = wd / "crossing.psm"
        crossing.write_text('import std.io\nimport std.string\n'
                            'import std.platform\nimport std.process\n\n'
                            'fn echo(word: String) -> Process {\n'
                            '    let p = Process()\n'
                            '    if (platform.isWindows) {\n'
                            '        p.program = "cmd"\n'
                            '        p.arguments = ["/c", "echo", word]\n'
                            '    } else {\n'
                            '        p.program = "/bin/echo"\n'
                            '        p.arguments = [word]\n'
                            '    }\n'
                            '    return p\n}\n\n'
                            'fn main() -> Int {\n'
                            '    let quiet = echo("discarded")\n'
                            '    quiet.stdout = StreamMode.Discard\n'
                            '    let status = quiet.run()\n'
                            '    let loud = echo("piped")\n'
                            '    loud.stdout = StreamMode.Pipe\n'
                            '    let child = loud.spawn()\n'
                            '    let out = child.stdout.readAll()\n'
                            '    child.wait()\n'
                            '    println("status=".concat(status.toString(), " out=", out.trim()))\n'
                            '    return 0\n}\n')
        crossing_exe = wd / ("crossing" + (".exe" if os.name == "nt" else ""))
        crossed_build = subprocess.run([str(compiler), "build", str(crossing),
                                        "-o", str(crossing_exe)],
                                       capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(wd), env=env)
        crossed = (subprocess.run([str(crossing_exe)], capture_output=True, text=True, encoding="utf-8", errors="replace")
                   if crossing_exe.exists() else None)
        if (crossed_build.returncode != 0 or crossed is None
                or (crossed.stdout or "").strip() != "status=0 out=piped"):
            said = (crossed_build.stdout or "") + (crossed_build.stderr or "")
            problems.append("`std.process`'s Process, set by a program and read by the "
                            "installed stdlib/process.plib, did not arrive field for field: "
                            + (said.strip()[-300:] if crossed is None else
                               f"it printed {(crossed.stdout or '').strip()!r}"))

        cross = run_plib_triple_sections(Path(PRISMIO_EXE).resolve(), wd, env,
                                         llvm_dis, problems)

    if problems:
        print(f"{RED}[FAIL] module artifacts{RESET}")
        for problem in problems:
            print(f"  - {problem}")
        return False
    print(f"{GREEN}[PASS] per-module PLIB/runtime bitcode, normal + verify, "
          f"strict reinstall diagnostics, `sort`, std.platform and a std.process "
          f"struct from the installed stdlib; per-triple sections: {cross}{RESET}")
    return True
