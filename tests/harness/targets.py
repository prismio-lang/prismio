"""The `targets` suite's harness tests (the design record, section 4; see tools/testkit/__init__.py)."""
import io
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
from shutil import which
from pathlib import Path

from harness.common import *


@harness_test(suite="targets", resources={"cpu": 2, "mem": 800, "qemu": EXCLUSIVE}, timeout=900)
def run_freestanding_test():
    """`--freestanding`: a program with no operating system under it.

    Three things, in the order they can fail. The language core links with no
    runtime at all (docs/FREESTANDING_PLAN.md, section 1: this is the regression
    guard for that measurement). A `std` import that needs an operating system is
    refused with a message that names it. And the programs actually run: on QEMU's `virt` board, with the
    boot stub in tests/freestanding/, the exit status and the serial output are
    what the program computed.

    Needs `ld.lld` and `qemu-system-aarch64`, neither of which a Prismio install
    ships; without them the test says so and passes, as `curated closure` does
    without clang.
    """
    print(f"\n{BLUE}--- Running freestanding ---{RESET}")
    lld = shutil.which("ld.lld")
    qemu = shutil.which("qemu-system-aarch64")
    # A `ld.lld` that is on PATH and cannot run is not a linker: the LLVM tarball's
    # was built against another distribution's ICU, and on Ubuntu it dies loading
    # libicui18n. GNU ld links a bare-metal ELF for its own architecture, so on an
    # AArch64 Linux host the AArch64 kernels fall back to it (`-fuse-ld=bfd`, which
    # a later flag overrides the default with) and the x86 ones, which need a
    # linker that targets another architecture, are skipped.
    lld_runs = False
    if lld:
        try:
            lld_runs = subprocess.run([lld, "--version"], capture_output=True,
                                      timeout=30).returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            lld_runs = False
    link_fallback = []
    if not lld_runs:
        if (sys.platform.startswith("linux") and platform.machine() in ("aarch64", "arm64")
                and shutil.which("ld.bfd")):
            link_fallback = ["--link-arg", "-fuse-ld=bfd"]
        else:
            lld = None
    if not lld_runs and not link_fallback or not qemu:
        missing = ", ".join(n for n, p in (("a working ld.lld", lld), ("qemu-system-aarch64", qemu)) if not p)
        print(f"{YELLOW}[SKIP] freestanding: {missing} not found{RESET}")
        return True

    fixtures = TEST_DIR / "freestanding"
    out_dir = scratch() / "freestanding_out"
    shutil.rmtree(out_dir, ignore_errors=True)
    out_dir.mkdir()
    env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")
    target = ["--target", "aarch64-unknown-none-elf", "--freestanding"]
    failures = []

    def build(source, output, extra=()):
        return subprocess.run(
            [str(PRISMIO_EXE), "build", str(fixtures / source), *target, *link_fallback, *extra,
             "-o", str(output)],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            env=env, cwd=str(fixtures))

    def boot(output):
        try:
            run = subprocess.run(
                [qemu, "-M", "virt", "-cpu", "cortex-a57", "-nographic", "-semihosting",
                 "-kernel", str(output)],
                capture_output=True, text=True, timeout=30)
        except subprocess.TimeoutExpired:
            return None, "(the kernel did not exit: a fault with no vector table hangs silently)"
        return run.returncode, run.stdout

    # 1. No runtime at all: linking succeeds, and lld refuses an undefined symbol,
    # so success is the absence of every libc and runtime import.
    bare = build("kernel_aarch64.psm", out_dir / "bare.elf")
    if bare.returncode != 0:
        failures.append(f"a scalar-only program did not link without a runtime:\n{bare.stderr}")

    # 1b. The `std` modules that need nothing: they import, and the program links.
    core = build("imports_core.psm", out_dir / "core.elf")
    if core.returncode != 0:
        failures.append(f"a program importing std.core.option and std.platform did not link:\n{core.stderr}")

    # 2. The import gate: a module that needs an operating system.
    gated = build("imports_io.psm", out_dir / "gated.elf")
    if gated.returncode == 0 or "`std.io` cannot be imported by a `--freestanding` program" not in gated.stderr:
        failures.append("importing std.io was not refused by name:\n" + gated.stderr)

    # 3. Running. The stub and linker script are the same in each; the failure core
    # (runtime/freestanding/panic.c) is added by `--freestanding` itself.
    stub = [
        "--native", "boot_aarch64_virt.c",
        "--native-flag", "-mgeneral-regs-only",
        "--target-features", "-neon,-fp-armv8",
        "--link-arg", "-T", "--link-arg", "link_aarch64_virt.ld",
    ]
    cases = [
        # (source, seed, extra flags, expected exit status, text in the output).
        # The failure site is matched by file and line without the directory: the
        # hook prints the path the compiler was given.
        ("kernel_aarch64.psm", 0, [], 0, ["result=252\n"]),
        ("kernel_trap_aarch64.psm", 0, ["--overflow-checks"], 0, ["result=7\n"]),
        ("kernel_trap_aarch64.psm", 1, ["--overflow-checks"], 1,
         ["integer overflow: + at ", "kernel_trap_aarch64.psm:10"]),
        # The same program without the check wraps, which is what `Int` means
        # in a release build.
        ("kernel_trap_aarch64.psm", 1, [], 0, ["result=-2\n"]),
        ("kernel_trap_aarch64.psm", 2, [], 1, ["panic: boom at ", "kernel_trap_aarch64.psm:13"]),
        # The same machine reached from Prismio itself: volatile stores to the UART,
        # atomics, a fence and inline assembly, with the stub doing none of it.
        ("kernel_mmio_aarch64.psm", 0, [], 0, ["PAA\nresult=0\n"]),
        # A heap: std.mem, `Vec` and `String` over the freestanding runtime and an
        # allocator the kernel writes in Prismio; and a Buffer read past its end,
        # which the runtime reports through the panic hook.
        ("kernel_mem_aarch64.psm", 0, [], 0, ["result=0\n"]),
        ("kernel_mem_aarch64.psm", 1, [], 1,
         ["runtime error: %d byte(s) at offset %d are out of range for a Buffer of %d"]),
    ]
    # A kernel that formats and parses Floats: the FPU is switched on by the stub
    # (-DENABLE_FP), so unlike every other case it is built with the FP unit.
    fp_stub = [
        "--native", "boot_aarch64_virt.c",
        "--native-flag", "-DENABLE_FP",
        # The MMU is off, so every access is device memory and an unaligned one
        # faults; the compiler has to be told not to emit them.
        "--native-flag", "-mstrict-align", "--target-features", "+strict-align",
        "--link-arg", "-T", "--link-arg", "link_aarch64_virt.ld",
    ]
    float_elf = out_dir / "float.elf"
    built = build("kernel_float_aarch64.psm", float_elf, fp_stub)
    if built.returncode != 0:
        failures.append(f"kernel_float_aarch64.psm did not build:\n{built.stderr}")
    else:
        code, output = boot(float_elf)
        if code != 0 or "result=0\n" not in output:
            failures.append(f"kernel_float_aarch64.psm: exit {code}, output {output!r}; "
                            f"wanted exit 0 containing 'result=0'")

    for index, (source, seed, extra, status, expected) in enumerate(cases):
        elf = out_dir / f"case{index}.elf"
        built = build(source, elf, [*stub, "--native-flag", f"-DSEED={seed}", *extra])
        if built.returncode != 0:
            failures.append(f"{source} (seed {seed}) did not build:\n{built.stderr}")
            continue
        code, output = boot(elf)
        if code != status or any(part not in output for part in expected):
            failures.append(f"{source} (seed {seed}): exit {code}, output {output!r}; "
                            f"wanted exit {status} containing {expected!r}")

    # 4. A kernel with no C of its own but the failure core: entry stub, serial
    # output, exit and panic hook all Prismio. Two builds of one source, the second
    # with the constant changed so `main` panics.
    pure_stub = [
        "--native-flag", "-mgeneral-regs-only",
        "--target-features", "-neon,-fp-armv8",
        "--link-arg", "-T", "--link-arg", "link_aarch64_pure.ld",
    ]
    pure_source = (fixtures / "kernel_pure_aarch64.psm").read_text(encoding="utf-8")
    for mode, status, expected in ((0, 0, "PM:42\n"), (1, 1, "PM:142\npanic: boom\n")):
        patched = out_dir / f"pure{mode}.psm"
        patched.write_text(pure_source.replace("let MODE = 0", f"let MODE = {mode}"),
                           encoding="utf-8")
        elf = out_dir / f"pure{mode}.elf"
        built = subprocess.run(
            [str(PRISMIO_EXE), "build", str(patched), *target, *link_fallback, *pure_stub,
             "-o", str(elf)],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            env=env, cwd=str(fixtures))
        if built.returncode != 0:
            failures.append(f"kernel_pure_aarch64.psm (mode {mode}) did not build:\n{built.stderr}")
            continue
        code, output = boot(elf)
        if code != status or output != expected:
            failures.append(f"kernel_pure_aarch64.psm (mode {mode}): exit {code}, output "
                            f"{output!r}; wanted exit {status} and {expected!r}")

    # 4b. 32-bit x86, through port I/O. QEMU's x86 loader wants a Xen PVH note and
    # the board has no semihosting, so the exit is the `isa-debug-exit` device: the
    # status written to port 0xF4 comes back as (status << 1) | 1.
    qemu_x86 = shutil.which("qemu-system-i386") if lld_runs else None
    if qemu_x86:
        x86_stub = [
            "--native-flag", "-mno-sse", "--native-flag", "-mno-mmx",
            "--target-features", "-sse,-sse2,-mmx",
            "--link-arg", "-T", "--link-arg", "link_i686.ld",
        ]
        x86_source = (fixtures / "kernel_i686.psm").read_text(encoding="utf-8")
        for mode, status, expected in ((0, 1, "X86:42\n"), (1, 3, "X86:142\npanic: boom\n")):
            patched = out_dir / f"x86_{mode}.psm"
            patched.write_text(x86_source.replace("let MODE = 0", f"let MODE = {mode}"),
                               encoding="utf-8")
            elf = out_dir / f"x86_{mode}.elf"
            built = subprocess.run(
                [str(PRISMIO_EXE), "build", str(patched), "--target", "i686-unknown-none-elf",
                 "--freestanding", *x86_stub, "-o", str(elf)],
                capture_output=True, text=True, encoding="utf-8", errors="replace",
                env=env, cwd=str(fixtures))
            if built.returncode != 0:
                failures.append(f"kernel_i686.psm (mode {mode}) did not build:\n{built.stderr}")
                continue
            try:
                run = subprocess.run(
                    [qemu_x86, "-kernel", str(elf), "-display", "none", "-serial", "stdio",
                     "-monitor", "none", "-device", "isa-debug-exit,iobase=0xf4,iosize=0x04",
                     "-no-reboot"],
                    capture_output=True, text=True, timeout=30)
            except subprocess.TimeoutExpired:
                failures.append(f"kernel_i686.psm (mode {mode}) did not exit")
                continue
            if run.returncode != status or run.stdout != expected:
                failures.append(f"kernel_i686.psm (mode {mode}): exit {run.returncode}, output "
                                f"{run.stdout!r}; wanted exit {status} and {expected!r}"
                                f" ({run.stderr.strip()})")

    # 4c. The same kernel declared in a manifest: the triple, code generation
    # settings, a linker script and a native source in `build.ums`, built by the
    # project command with its debug profile (-g and overflow checks), which is the
    # configuration a user's first build is in.
    project = out_dir / "project"
    project.mkdir()
    shutil.copy(fixtures / "kernel_pure_aarch64.psm", project / "kernel.psm")
    shutil.copy(fixtures / "link_aarch64_pure.ld", project / "link.ld")
    shutil.copy(TEST_DIR.parent / "runtime" / "freestanding" / "panic.c", project / "panic.c")
    (project / "build.ums").write_text(
        'project {\n    name = "kernel"\n    version = "0.1.0"\n    prismio = "0.1.0"\n}\n\n'
        'targets {\n    executable("kernel") {\n        entry = "kernel.psm"\n'
        '        freestanding = true\n        triple = "aarch64-unknown-none-elf"\n'
        '        features = "-neon,-fp-armv8"\n'
        '        native {\n            source("panic.c")\n            flag("-mgeneral-regs-only")\n        }\n'
        '        link {\n            script("link.ld")\n'
        + ('            arg("-fuse-ld=bfd")\n' if link_fallback else "")
        + '        }\n    }\n}\n',
        encoding="utf-8")
    managed = subprocess.run(
        [str(PRISMIO_EXE), "build"], capture_output=True, text=True, encoding="utf-8",
        errors="replace", env=env, cwd=str(project))
    kernel = project / ".prismio" / "build" / "debug" / "kernel"
    if managed.returncode != 0 or not kernel.is_file():
        failures.append("a freestanding target in build.ums did not build:\n"
                        + managed.stdout + managed.stderr)
    else:
        code, output = boot(kernel)
        if code != 0 or output != "PM:42\n":
            failures.append(f"the build.ums kernel: exit {code}, output {output!r}; "
                            "wanted exit 0 and 'PM:42\\n'")

    # 5. Layout. A program cannot take a field's address, so the emitted type is
    # what is read: declaration order for `repr(C)`, no padding for `packed`.
    layout = subprocess.run(
        [str(PRISMIO_EXE), "build", str(fixtures / "layout_c.psm"), "-o", str(out_dir / "layout.ll")],
        capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    ir = (out_dir / "layout.ll").read_text(encoding="utf-8") if layout.returncode == 0 else ""
    for want in ("%Gate = type { i8, i32, i16 }", "%Wire = type <{ i8, i32 }>",
                 "%Both = type <{ i8, i32 }>"):
        if want not in ir:
            failures.append(f"layout_c.psm: the IR does not declare `{want}`:\n"
                            + (layout.stderr or ir[:600]))

    shutil.rmtree(out_dir, ignore_errors=True)
    if failures:
        print(f"{RED}[FAIL] freestanding:{RESET}")
        for failure in failures:
            print(failure)
        return False
    print(f"{GREEN}[PASS] freestanding: no runtime for the core, std imports refused, "
          f"{len(cases) + 3 + (2 if qemu_x86 else 0)} kernels booted under QEMU, struct layout{RESET}")
    return True


@harness_test(suite="targets", resources={"cpu": 4, "mem": 1500, "qemu": EXCLUSIVE}, timeout=900)
def run_freestanding_bench_test():
    """The freestanding benchmark suite builds, boots and agrees with itself.

    Runs `benchmarks/run.py --suite freestanding`: the C, Rust and Prismio arms are built
    for bare-metal AArch64, each boots under QEMU, and the runner refuses to report a
    workload whose three arms return different checksums. This asserts that it did, that
    every workload in the catalog was measured in all three languages, and that the counts
    are deterministic across boots. It does not assert a ratio: performance is recorded,
    not gated.

    The suite needs clang, a linker that runs, qemu-system-aarch64 and rustc with the
    Rust source component. Without them the runner says what is missing and this test
    skips, as `freestanding` does.
    """
    print(f"\n{BLUE}--- Running freestanding_bench ---{RESET}")
    runner = PROJECT_ROOT / "benchmarks" / "run.py"
    catalog = json.loads((PROJECT_ROOT / "benchmarks" / "freestanding" / "benchmarks.json")
                         .read_text(encoding="utf-8"))["benchmarks"]
    with tempfile.TemporaryDirectory(prefix="prismio-fsbench-") as temp_dir:
        output = Path(temp_dir) / "results.json"
        done = subprocess.run(
            [sys.executable, str(runner), "--suite", "freestanding", "--compiler", str(PRISMIO_EXE),
             "--runs", "2", "--allow-stale-compiler", "--output", str(output)],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            env=dict(os.environ, PRISMIO_INTERNAL_HOSTED="1"), cwd=str(PROJECT_ROOT))
        text = (done.stdout or "") + (done.stderr or "")
        if done.returncode != 0 and "the freestanding suite needs" in text:
            print(f"{YELLOW}[SKIP] freestanding_bench: {text.strip().splitlines()[-1]}{RESET}")
            return True
        if done.returncode != 0:
            print(f"{RED}[FAIL] freestanding_bench: the runner failed{RESET}")
            print(text[-2500:])
            return False
        report = json.loads(output.read_text(encoding="utf-8"))["suites"]["freestanding"]

    problems = []
    measured = {item["name"]: item for item in report["benchmarks"]}
    for entry in catalog:
        item = measured.get(entry["name"])
        if item is None:
            problems.append(f"{entry['name']} was not measured")
            continue
        for language in ("prismio", "c", "rust"):
            count = item["languages"].get(language, {}).get("instructions", 0)
            if count <= 0:
                problems.append(f"{entry['name']}: no instruction count for {language}")
        if "result" not in item:
            problems.append(f"{entry['name']}: no checksum recorded")
    if not report.get("deterministic"):
        problems.append("repeated boots of one image gave different counts")
    if problems:
        print(f"{RED}[FAIL] freestanding_bench:{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] freestanding_bench: {len(measured)} workloads in Prismio, C and Rust agree "
          f"on every checksum, and the counts repeat{RESET}")
    return True


@harness_test(suite="targets")
def run_kmalloc_heap_test():
    """A `Vec`, a `HashMap` and a `String` on a heap the program supplies over the kernel's allocator.

    tests/kmalloc_heap_probe.psm defines `prismio_alloc`, `prismio_realloc` and `prismio_free` over
    `__kmalloc`, `krealloc` and `kfree`, as a module would. Read as IR for AArch64 Linux: the three
    are exported under their C names, the kernel's allocator is what they call, and nothing in the
    object reaches the C library's.
    """
    print(f"\n{BLUE}--- Running kmalloc_heap ---{RESET}")
    problems = []
    with tempfile.TemporaryDirectory(prefix="prismio-kmalloc-") as tmp:
        ll = Path(tmp) / "kmalloc.ll"
        built = run_command([str(PRISMIO_EXE), "build", str(TEST_DIR / "kmalloc_heap_probe.psm"), "--freestanding",
                             "--target", "aarch64-unknown-linux-gnu", "-o", str(ll)])
        if built.returncode != 0:
            print(f"{RED}[FAIL] kmalloc heap probe did not build: {built.stdout} {built.stderr}{RESET}")
            return False
        ir = ll.read_text(encoding="utf-8", errors="replace")
        for text, why in (
            ("@prismio_alloc = alias ptr (i64), ptr @prismio_alloc__Usize", "prismio_alloc under its C name"),
            ("@prismio_realloc = alias ptr (ptr, i64), ptr @prismio_realloc__Ptr_Usize", "prismio_realloc under its C name"),
            ("@prismio_free = alias void (ptr), ptr @prismio_free__Ptr", "prismio_free under its C name"),
            ("call ptr @__kmalloc(i64", "allocation goes to kmalloc"),
            ("call ptr @krealloc(ptr", "growth goes to krealloc"),
            ("call void @kfree(ptr", "release goes to kfree"),
        ):
            if text not in ir:
                problems.append(f"missing {text!r}: {why}")
        for libc in ("declare ptr @malloc(", "declare void @free(", "declare ptr @realloc("):
            if libc in ir:
                problems.append(f"{libc!r}: the heap reached the C library")
    if problems:
        print(f"{RED}[FAIL] kmalloc heap{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] kmalloc heap: Vec, HashMap and String over the kernel's allocator{RESET}")
    return True


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


@harness_test("target_cross", suite="targets", resources={"cpu": 2, "mem": 800, "objcache": EXCLUSIVE})
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
    host_ll = scratch() / "target_host.ll"
    wasm_ll = scratch() / "target_wasm.ll"
    host_g = scratch() / "target_host_g.ll"
    wasm_g = scratch() / "target_wasm_g.ll"
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
        # The pin follows the host's architecture (ir_module_start): a native ARM64
        # compiler stamping x86_64 merged aarch64 runtime bitcode into an x86_64 module.
        arch = "aarch64" if platform.machine().lower() in ("arm64", "aarch64") else "x86_64"
        if f'target triple = "{arch}-pc-windows-msvc"' not in host_ir:
            problems.append("a host build on Windows did not pin "
                            f"`{arch}-pc-windows-msvc` -- without it clang may pick "
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
    if "declare ptr @rt_base_alloc(i32)" not in wasm_ir:
        problems.append("the allocator still takes a 64-bit size on wasm32 -- "
                        "codegen is not reading the target's pointer width")
    if "declare ptr @rt_base_alloc(i64)" not in host_ir:
        problems.append("the allocator does not take a 64-bit size on the host")
    # std.io's own code, as the library module a wasm32 package carries: the program above links it
    # compiled rather than emitting it.
    with tempfile.TemporaryDirectory(prefix="prismio-wasm-io-") as io_dir:
        plib = Path(io_dir) / "output.plib"
        emitted = run_command([str(PRISMIO_EXE), "build", str(PROJECT_ROOT / "std" / "io" / "output.psm"),
                               "--emit", "plib", "--module", "std.io.output", "--target", "wasm32-unknown-unknown",
                               "-o", str(plib)])
        llvm_dis = pinned_llvm_tool("llvm-dis")
        sections = plib_sections(plib) if emitted.returncode == 0 else None
        if sections is None:
            problems.append(f"std.io did not compile for wasm32: {emitted.stderr[-300:]}")
        elif llvm_dis:
            code = Path(io_dir) / "io.bc"
            code.write_bytes(sections[1][1])
            wasm_ir = wasm_ir + subprocess.run(
                [str(llvm_dis), str(code), "-o", "-"], capture_output=True, text=True,
                encoding="utf-8", errors="replace").stdout
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

    # 6. Runtime bitcode is target-specific. An installed host package must not
    # silently use its host modules for a different target; absent modules are
    # an installation error naming every required artifact.
    with tempfile.TemporaryDirectory() as cache:
        env = dict(os.environ, PRISMIO_OBJ_CACHE_DIR=cache,
                   PRISMIO_OBJ_CACHE_TRACE="1")
        exe = scratch() / ("target_cache" + (".exe" if os.name == "nt" else ""))
        host = subprocess.run([str(PRISMIO_EXE), "build", str(source),
                              "-o", str(exe)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              env=env)
        cross = subprocess.run(
            [str(PRISMIO_EXE), "build", str(source), "-o", str(exe),
             "--target", "wasm32-unknown-unknown"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
        cleanup_files(exe)
        cross_output = (cross.stdout or "") + (cross.stderr or "")
        if host.returncode != 0:
            problems.append("the host runtime bitcode build failed")
        if cross.returncode == 0:
            problems.append("a wasm32 build silently reused host runtime bitcode")
        expected = "lib/runtime/wasm32-unknown-unknown/*.bc"
        if expected not in cross_output:
            problems.append(f"the missing-target diagnostic did not name `{expected}`")
        if "Reinstall Prismio and try again" not in cross_output:
            problems.append("missing target runtime bitcode did not recommend reinstalling Prismio")

    # 7. The real thing, where this host can run the result.
    linked = "not attempted on this host"
    if sys.platform == "darwin" and platform.machine() == "arm64":
        sdk = run_command(["xcrun", "--show-sdk-path"])
        if sdk.returncode == 0 and sdk.stdout.strip():
            exe = scratch() / "target_x86"
            built = run_command([str(PRISMIO_EXE), "build", str(source),
                                 "--target", "x86_64-apple-macos",
                                 "--sysroot", sdk.stdout.strip(), "-o", str(exe)])
            build_output = (built.stdout or "") + (built.stderr or "")
            if (built.returncode != 0
                    and "Missing runtime module: lib/runtime/x86_64-apple-macos/"
                        in build_output):
                linked = "x86_64 runtime modules not packaged"
            elif built.returncode != 0:
                problems.append("a cross build for x86_64-apple-macos failed: "
                                + build_output.strip())
            else:
                kind = run_command(["file", str(exe)]).stdout
                if "x86_64" not in kind:
                    problems.append(f"the cross build produced {kind.strip()!r} "
                                    "rather than an x86_64 binary")
                # An arm64 Mac without Rosetta cannot exec an x86_64 binary at
                # all (`Bad CPU type`): that says nothing about the build, which
                # the `file` check above has already judged.
                try:
                    ran = run_command([str(exe)])
                except OSError as err:
                    ran = None
                    linked = f"x86_64-apple-macos built, not run here ({err.strerror})"
                if ran is None:
                    pass
                elif ran.returncode != 0 or "cross" not in (ran.stdout or ""):
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
                               input="", capture_output=True, text=True, encoding="utf-8", errors="replace")
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
    # must model the same size on any one target. A `[T]` field was the third
    # pointer until array fields had to carry a length; it is refused now. String was already correct, so
    # this compares the suspect path against a known-good one in the same
    # function and needs no magic number of its own. It also requires the wasm32
    # figure to be *smaller* than the host's, which is what stops both paths
    # being wrong in the same direction.
    with tempfile.TemporaryDirectory(prefix="prismio-ptr-width-") as tmp:
        probe = Path(tmp) / "widths.psm"
        probe.write_text("import std.io\n"
                         "\n"
                         "struct OfList { a: Vec<Int>, b: Vec<Int>, c: Vec<Int> }\n"
                         "struct OfString { a: String, b: String, c: String }\n"
                         "\n"
                         "fn main() -> Int {\n"
                         "    let x = OfList { a: [], b: [], c: [] }\n"
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
            for name in ("OfList",):
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
          f"agreed by sema and codegen, -g offsets from the target, runtime "
          f"selected per target, container fields sized from the target; layout vs clang: "
          f"{layouts}; link: {linked}{RESET}")
    return True


@harness_test(suite="targets")
def run_platform_target_test():
    """`std.platform`'s three builtins answer for the target, on nine triples.

    The target builtins lower to constants read off the triple (`targetOsCode` and
    its siblings in src/common/target.psm), and `std.platform` maps the constants
    onto its enums. test_147 can only check the host it runs on, so this reads the
    answer out of the IR for every triple the mapping has a rule for, where nothing
    has to run: `platformCodes` in tests/platform_target.psm returns
    os * 100 + arch * 10 + env through std.platform's methods, and `opt` at -O1
    inlines them and folds the whole thing to a single `ret`.

    The triples are the spellings the mapping has to survive: an unnormalised
    Android triple, MinGW spelt both ways LLVM spells it, and a target that
    matches nothing and must answer 0 rather than a guess.
    """
    print(f"\n{BLUE}--- Running platform_target ---{RESET}")
    source = TEST_DIR / "platform_target.psm"
    expected = (
        ("x86_64-pc-windows-msvc", 113),
        ("x86_64-pc-windows-gnu", 114),
        ("x86_64-w64-mingw32", 114),
        ("x86_64-unknown-linux-gnu", 211),
        ("aarch64-unknown-linux-musl", 222),
        ("aarch64-linux-android", 220),
        ("arm64-apple-macos", 320),
        ("x86_64-apple-darwin", 310),
        ("wasm32-unknown-unknown", 0),
    )
    problems = []
    for triple, want in expected:
        out = scratch() / f"platform_target_{triple}.ll"
        result = run_command([str(PRISMIO_EXE), "build", str(source),
                              "--target", triple, "-o", str(out)])
        if result.returncode != 0 or not out.exists():
            problems.append(f"{triple}: build exited {result.returncode}: "
                            + (result.stdout or result.stderr or "").strip()[-200:])
            cleanup_files(out)
            continue
        folded = scratch() / f"platform_target_{triple}.folded.ll"
        opt = PROJECT_ROOT / "third_party" / "llvm" / "bin" / ("opt.exe" if os.name == "nt" else "opt")
        result = run_command([str(opt), "-passes=default<O1>", "-S", str(out), "-o", str(folded)])
        cleanup_files(out)
        if result.returncode != 0 or not folded.exists():
            problems.append(f"{triple}: opt exited {result.returncode}: "
                            + (result.stdout or result.stderr or "").strip()[-200:])
            cleanup_files(folded)
            continue
        ir = folded.read_text(encoding="utf-8", errors="replace")
        cleanup_files(folded)
        body = re.search(r'define [^\n]*@"?platformCodes[^\n]*\{(.*?)\n\}', ir, re.S)
        got = re.search(r"ret i32 (-?\d+)", body.group(1)) if body else None
        if not got:
            problems.append(f"{triple}: platformCodes did not fold to one `ret i32`")
        elif int(got.group(1)) != want:
            problems.append(f"{triple}: os*100 + arch*10 + env is {got.group(1)}, "
                            f"expected {want}")

    if problems:
        print(f"{RED}[FAIL] platform_target{RESET}")
        for p in problems:
            print(f"  - {p}")
        return False
    print(f"{GREEN}[PASS] platform_target: {len(expected)} triples fold to the "
          f"expected OS, architecture and environment{RESET}")
    return True


@harness_test(suite="targets", resources={"cpu": 2, "mem": 800})
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
      2. *`process.args.count` reports the program's arguments, not the
         compiler's.* **This is the trap the design note in ir_jit_run_main is
         about.** Generated code *defines* `@prismio_argc`, and this process has
         a second one -- the compiler's, which holds `prismio run --jit
         prog.psm`. std.process reads the symbol through `extern let`, so a
         declaration that resolved to the wrong copy would quietly report the
         compiler's command line. The fixture prints the count and both paths
         must say 1.
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
        # Through std.process, which names `prismio_argc` with `extern let`:
        # the declaration is where the jitted module's copy and the compiler's
        # can be confused.
        # And through std.core.map, whose non-generic functions ship compiled in
        # `map.plib`: this runs outside any checkout, so a JIT that ran the
        # program's module alone found none of them.
        prog.write_text('import std.io\n'
                        'import std.process\n'
                        ''
                        '\n'
                        'struct Point { x: Int, y: Int }\n'
                        '\n'
                        'fn total(p: Point) -> Int {\n'
                        '    return p.x + p.y\n'
                        '}\n'
                        '\n'
                        'fn main() -> Int {\n'
                        '    let p = Point { x: 40, y: 2 }\n'
                        '    let mut items: Vec<String> = []\n'
                        '    items.push("jit")\n'
                        '    print("answer: ")\n'
                        '    println(total(p))\n'
                        '    print("argc: ")\n'
                        '    println(process.args.count)\n'
                        '    let m: HashMap<String, Int> = mapNew<String, Int>()\n'
                        '    m.set("k", 7)\n'
                        '    print("map: ")\n'
                        '    println(m.count)\n'
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
                                "than `argc: 1`: std.process is reading the "
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
