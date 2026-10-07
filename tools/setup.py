#!/usr/bin/env python3
"""Make this machine able to build Prismio, and say exactly what is missing if not.

`tools/setup_llvm.py` provisions the one thing the checkout owns, the pinned
LLVM. Everything else a build needs comes from the machine, and used to be a line
in the README: a missing linker or C library surfaced as an unrelated-looking
error halfway through a bootstrap. This checks each of them first, with a probe
that does what the build does rather than a guess at a file name, then provisions
LLVM, and finishes by naming the next command.

What it will and will not change:

* It **checks** every prerequisite and changes nothing without being asked.
* It **provisions LLVM** by default: the pinned release, verified by SHA-256, into
  `third_party/llvm`. That belongs to the checkout, so no flag is needed.
* It **installs system packages only with `--install-system-deps`** (and asks
  first unless `--yes`): a compiler toolchain, `git`, Visual Studio's C++ tools.
  Those are machine-wide, need administrator rights, and in Visual Studio's case
  a licence, so they are never a side effect.

Python 3.9 or later is the one prerequisite this cannot install, since it is
what runs it.

Usage:
    python tools/setup.py                          # check, then provision LLVM
    python tools/setup.py --check                  # check only; exit 1 if the machine cannot build
    python tools/setup.py --install-system-deps    # also install what is missing (asks first)
    python tools/setup.py --install-system-deps --yes
    python tools/setup.py --skip-llvm              # the system checks alone
"""

from __future__ import annotations

import argparse
import glob
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import setup_llvm  # noqa: E402  (after the path edit)

MIN_PYTHON = (3, 9)

# The download is 1-2 GiB, extraction needs the archive and the tree at once, and
# preparing LLVM lowers a few thousand bitcode objects beside them.
MIN_FREE_GIB = 8

OK, WARN, FAIL = "ok", "warn", "missing"


@dataclass
class Check:
    name: str
    status: str
    detail: str
    # What to do about it, as commands a person can run. Empty when ok.
    fix: list = field(default_factory=list)
    # What `--install-system-deps` would run for it: an argv list, or a Download
    # (an installer fetched from its vendor and run), in order.
    install: list = field(default_factory=list)


@dataclass
class Download:
    """An installer fetched over HTTPS from its publisher and run with `args`."""
    url: str
    args: list
    # Exit codes that mean it worked: 3010 is "installed, restart when convenient".
    ok_codes: tuple = (0, 3010)


def run(argv, **kw):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=kw.pop("timeout", 120), **kw)
    except (OSError, subprocess.SubprocessError):
        return None


def first(*names):
    for name in names:
        found = shutil.which(name)
        if found:
            return found
    return None


# --------------------------------------------------------------------------
# Python, platform, disk, network
# --------------------------------------------------------------------------

def check_python():
    have = sys.version_info[:2]
    detail = f"Python {platform.python_version()}"
    if have >= MIN_PYTHON:
        return Check("Python", OK, detail)
    return Check("Python", FAIL, f"{detail}; Prismio needs {MIN_PYTHON[0]}.{MIN_PYTHON[1]} or later",
                 ["install a newer Python from https://www.python.org/downloads/"])


def check_platform():
    key = (platform.system(), platform.machine())
    label = f"{key[0]}/{key[1]}"
    if key in setup_llvm.ASSETS:
        return Check("Platform", OK, f"{label}, LLVM {setup_llvm.LLVM_VERSION} publishes an archive")
    return Check("Platform", FAIL, f"{label}: LLVM {setup_llvm.LLVM_VERSION} publishes no archive for it",
                 ["build LLVM yourself and adopt it: python tools/setup_llvm.py --llvm-dir <path>"])


def check_disk():
    try:
        free = shutil.disk_usage(REPO_ROOT).free / (1 << 30)
    except OSError as err:
        return Check("Disk space", WARN, f"could not measure ({err})")
    detail = f"{free:.1f} GiB free where the checkout is"
    if free >= MIN_FREE_GIB:
        return Check("Disk space", OK, detail)
    return Check("Disk space", FAIL, f"{detail}; the LLVM download and preparation need about {MIN_FREE_GIB}",
                 ["free some space, or move the checkout to a larger volume"])


def llvm_prepared():
    marker = setup_llvm.prepared_marker()
    return bool(marker) and setup_llvm.CONFIG_PATH.is_file()


def reach(url):
    request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "prismio-setup"})
    with urllib.request.urlopen(request, timeout=15):
        return True


def reach_with_windows(url):
    """The same question put to Windows' own TLS stack.

    A fresh Windows machine installs root CAs on demand inside that stack, so
    Python can fail with CERTIFICATE_VERIFY_FAILED for a host PowerShell reaches.
    setup_llvm.download falls back to PowerShell for the same reason.
    """
    if sys.platform != "win32":
        return False
    script = ("$ProgressPreference='SilentlyContinue'; "
              "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; "
              f"Invoke-WebRequest -Uri '{url}' -Method Head -UseBasicParsing -TimeoutSec 30 | Out-Null")
    result = run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script], timeout=60)
    return result is not None and result.returncode == 0


def check_network():
    """Only asked when LLVM still has to be downloaded."""
    if llvm_prepared():
        return None
    # The archive itself, not github.com: the release is served from a CDN host
    # after a redirect, and that host is the one a fresh machine can fail to trust.
    asset = setup_llvm.ASSETS.get((platform.system(), platform.machine()))
    url = (setup_llvm.RELEASE_URL.format(version=setup_llvm.LLVM_VERSION, name=asset[0])
           if asset else "https://github.com/llvm/llvm-project/releases/")
    try:
        reach(url)
        return Check("Network", OK, "the LLVM release download is reachable")
    except (urllib.error.URLError, OSError) as err:
        if setup_llvm.trust_failure(err) and reach_with_windows(url):
            return Check("Network", OK,
                         "the LLVM release download is reachable through Windows' own TLS stack "
                         "(Python does not trust the host's certificate yet; the download falls back to it)")
        return Check("Network", FAIL, f"cannot reach the LLVM release download ({err})",
                     ["behind a proxy, set HTTPS_PROXY (and SSL_CERT_FILE for a private CA)",
                      "or download the archive by hand into third_party/.downloads/ "
                      "(the name is in tools/setup_llvm.py)"])


def check_git():
    found = shutil.which("git")
    if found:
        return Check("git", OK, found)
    return Check("git", WARN, "not found: fine to build, needed to clone and to run the tests' git fixtures",
                 ["install it from https://git-scm.com/downloads"],
                 install=GIT_INSTALL.get(system_family(), []))


# --------------------------------------------------------------------------
# The system C toolchain, probed the way the build uses it
# --------------------------------------------------------------------------

PROBE = """\
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char** argv) {
    char buf[16];
    snprintf(buf, sizeof buf, "%d", argc);
    return (int)sqrt((double)strlen(buf)) > 99 ? 1 : (argv[0] == NULL);
}
"""


def pinned_clang():
    config = setup_llvm.CONFIG_PATH
    if not config.is_file():
        return None
    try:
        import json
        bin_dir = Path(json.loads(config.read_text())["bin"])
    except (OSError, ValueError, KeyError):
        return None
    candidate = bin_dir / setup_llvm.exe("clang")
    return str(candidate) if candidate.is_file() else None


def probe_link(compiler):
    """Compile and link a small C program that needs the C library and libm."""
    with tempfile.TemporaryDirectory() as tmp:
        source = Path(tmp) / "probe.c"
        source.write_text(PROBE)
        out = Path(tmp) / ("probe.exe" if sys.platform == "win32" else "probe")
        argv = [compiler, str(source), "-o", str(out)]
        if sys.platform != "win32":
            argv.append("-lm")
        result = run(argv)
        if result is None:
            return False, "the compiler did not run"
        if result.returncode != 0:
            lines = (result.stderr or result.stdout).strip().splitlines()
            return False, (lines[0] if lines else "link failed")
        return True, ""


def system_family():
    if sys.platform == "darwin":
        return "macos"
    if sys.platform == "win32":
        return "windows"
    ids = ""
    try:
        ids = Path("/etc/os-release").read_text().lower()
    except OSError:
        pass
    for family, needles in (("debian", ("debian", "ubuntu")),
                            ("fedora", ("fedora", "rhel", "centos", "rocky", "almalinux")),
                            ("arch", ("arch", "manjaro")),
                            ("suse", ("suse",)),
                            ("alpine", ("alpine",))):
        if any(f"={n}" in ids or f'="{n}' in ids or f" {n}" in ids for n in needles):
            return family
    return "linux"


# argv lists, run through sudo when not root. One package manager per family.
LINUX_TOOLCHAIN = {
    "debian": [["apt-get", "update"], ["apt-get", "install", "-y", "build-essential"]],
    "fedora": [["dnf", "install", "-y", "gcc", "gcc-c++", "make", "glibc-devel"]],
    "arch": [["pacman", "-S", "--needed", "--noconfirm", "base-devel"]],
    "suse": [["zypper", "--non-interactive", "install", "gcc", "gcc-c++", "make", "glibc-devel"]],
    "alpine": [["apk", "add", "build-base"]],
}
GIT_INSTALL = {
    "debian": [["apt-get", "install", "-y", "git"]],
    "fedora": [["dnf", "install", "-y", "git"]],
    "arch": [["pacman", "-S", "--needed", "--noconfirm", "git"]],
    "suse": [["zypper", "--non-interactive", "install", "git"]],
    "alpine": [["apk", "add", "git"]],
    "macos": [["xcode-select", "--install"]],
    # winget only when it is there; without it git stays a warning with no plan.
    "windows": ([["winget", "install", "--id", "Git.Git", "-e", "--accept-package-agreements",
                  "--accept-source-agreements"]] if shutil.which("winget") else []),
}


def check_toolchain_posix():
    if sys.platform == "darwin":
        sdk = run(["xcrun", "--show-sdk-path"])
        if sdk is None or sdk.returncode != 0 or not sdk.stdout.strip():
            return Check("C toolchain", FAIL, "Xcode's command line tools are not installed",
                         ["xcode-select --install   (a dialog opens; run this again when it finishes)"],
                         [["xcode-select", "--install"]])
        compiler = pinned_clang() or first("clang", "cc")
    else:
        compiler = pinned_clang() or first("cc", "gcc", "clang")
    family = system_family()
    install = LINUX_TOOLCHAIN.get(family, []) if sys.platform != "darwin" else []
    fix = [" && ".join(" ".join(c) for c in install) or
           "install a C compiler and the C library headers (the equivalent of build-essential)"]
    if compiler is None:
        return Check("C toolchain", FAIL, "no C compiler found", fix, install)
    linked, why = probe_link(compiler)
    which = "the pinned clang" if compiler == pinned_clang() else compiler
    if linked:
        return Check("C toolchain", OK, f"{which} compiles and links a program against libc and libm")
    return Check("C toolchain", FAIL, f"{which} could not link a program: {why}", fix, install)


def vswhere_path():
    for root in (os.environ.get("ProgramFiles(x86)"), os.environ.get("ProgramFiles")):
        if root:
            candidate = Path(root) / "Microsoft Visual Studio" / "Installer" / "vswhere.exe"
            if candidate.is_file():
                return str(candidate)
    return None


# Microsoft's own bootstrapper, not winget: winget is absent from Windows Server,
# LTSC and fresh images, and a build prerequisite should not depend on it.
# `--includeRecommended` brings the Windows SDK the workload recommends; ARM64
# tools are a separate component and are only asked for on an ARM64 machine.
def vs_build_tools():
    args = ["--quiet", "--wait", "--norestart", "--nocache",
            "--add", "Microsoft.VisualStudio.Workload.VCTools", "--includeRecommended"]
    if platform.machine().upper() == "ARM64":
        args += ["--add", "Microsoft.VisualStudio.Component.VC.Tools.ARM64"]
    return Download("https://aka.ms/vs/17/release/vs_BuildTools.exe", args)


def check_toolchain_windows():
    arm = platform.machine().upper() == "ARM64"
    component = ("Microsoft.VisualStudio.Component.VC.Tools.ARM64" if arm
                 else "Microsoft.VisualStudio.Component.VC.Tools.x86.x64")
    arch_dir = "arm64" if arm else "x64"
    fix = ["install \"Desktop development with C++\" from https://visualstudio.microsoft.com/downloads/ "
           "(Build Tools for Visual Studio is enough), or run: python tools/setup.py --install-system-deps"]

    tools = os.environ.get("VCToolsInstallDir")
    if not tools:
        vswhere = vswhere_path()
        if vswhere is None:
            return Check("C toolchain", FAIL, "Visual Studio's C++ build tools are not installed", fix,
                         [vs_build_tools()])
        found = run([vswhere, "-latest", "-products", "*", "-requires", component,
                     "-property", "installationPath"])
        root = found.stdout.strip().splitlines()[0] if found and found.stdout.strip() else ""
        if not root:
            return Check("C toolchain", FAIL,
                         f"no Visual Studio instance has the {arch_dir} C++ tools",
                         fix, [vs_build_tools()])
        versions = sorted(glob.glob(str(Path(root) / "VC" / "Tools" / "MSVC" / "*")))
        tools = versions[-1] if versions else ""
    links = glob.glob(str(Path(tools) / "bin" / "Host*" / arch_dir / "link.exe")) if tools else []
    if not links:
        return Check("C toolchain", FAIL, f"no {arch_dir} link.exe under {tools or 'Visual Studio'}",
                     fix, [vs_build_tools()])

    sdk_root = os.environ.get("WindowsSdkDir") or str(
        Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Windows Kits" / "10")
    ucrt = glob.glob(str(Path(sdk_root) / "Lib" / "*" / "ucrt" / arch_dir / "ucrt.lib"))
    if not ucrt:
        return Check("C toolchain", FAIL,
                     f"link.exe is there but the Windows SDK's {arch_dir} C runtime is not",
                     ["add the \"Windows 11 SDK\" component in the Visual Studio Installer"] + fix[:1],
                     [vs_build_tools()])
    return Check("C toolchain", OK, f"MSVC link.exe ({arch_dir}) and the Windows SDK C runtime")


def check_toolchain():
    return check_toolchain_windows() if sys.platform == "win32" else check_toolchain_posix()


# --------------------------------------------------------------------------
# LLVM
# --------------------------------------------------------------------------

def check_llvm():
    if llvm_prepared():
        return Check("LLVM", OK, f"{setup_llvm.LLVM_VERSION} prepared in third_party/llvm")
    return Check("LLVM", WARN, f"{setup_llvm.LLVM_VERSION} is not provisioned yet (this script does it)")


# --------------------------------------------------------------------------
# Running it
# --------------------------------------------------------------------------

def report(checks):
    width = max(len(c.name) for c in checks)
    for c in checks:
        print(f"  {c.status:<7} {c.name:<{width}}  {c.detail}")
        if c.status != OK:
            for line in c.fix:
                print(f"          {'':<{width}}  -> {line}")
    print()


def privileged(argv):
    if sys.platform == "win32" or os.geteuid() == 0:
        return argv
    return ["sudo"] + argv if shutil.which("sudo") else argv


def fetch(url, dest):
    request = urllib.request.Request(url, headers={"User-Agent": "prismio-setup"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response, open(dest, "wb") as out:
            shutil.copyfileobj(response, out)
    except (urllib.error.URLError, OSError) as err:
        if sys.platform == "win32" and setup_llvm.trust_failure(err) and setup_llvm.powershell_download(url, dest):
            return
        raise


def signed_by_microsoft(path):
    """A downloaded installer is run as administrator, so it must be Microsoft's."""
    script = (f"$s = Get-AuthenticodeSignature -LiteralPath '{path}'; "
              "if ($s.Status -eq 'Valid' -and $s.SignerCertificate.Subject -like '*O=Microsoft Corporation*') "
              "{ exit 0 } else { exit 1 }")
    result = run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script])
    return result is not None and result.returncode == 0


def describe(plan):
    if isinstance(plan, Download):
        return f"download {plan.url} and run it: {' '.join(plan.args)}"
    return " ".join(privileged(plan))


def execute(plan):
    """Run one plan; True when it worked."""
    if isinstance(plan, Download):
        # Not TemporaryDirectory: an installer can still hold its own file for a
        # moment after it exits (Windows says "Access is denied"), and failing to
        # delete a download must not turn a finished install into a failed run.
        tmp = tempfile.mkdtemp(prefix="prismio-setup-")
        try:
            installer = Path(tmp) / Path(plan.url).name
            print(f"+ download {plan.url}", flush=True)
            try:
                fetch(plan.url, installer)
            except (urllib.error.URLError, OSError) as err:
                print(f"  download failed: {err}")
                return False
            if not signed_by_microsoft(installer):
                print("  the download is not validly signed by Microsoft; not running it.")
                return False
            print(f"+ {installer.name} {' '.join(plan.args)}  (this can take several minutes)", flush=True)
            code = subprocess.call([str(installer)] + plan.args)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        if code not in plan.ok_codes:
            print(f"  exited {code}; stopping here.")
            return False
        if code == 3010:
            print("  installed; Windows asks for a restart when convenient.")
        return True
    argv = privileged(plan)
    print(f"+ {' '.join(argv)}", flush=True)
    try:
        code = subprocess.call(argv)
    except OSError as err:
        print(f"  could not run {argv[0]}: {err}")
        return False
    if code != 0:
        print(f"  exited {code}; stopping here.")
        return False
    return True


def install_missing(checks, assume_yes):
    plans = []
    for c in checks:
        if c.status in (FAIL, WARN) and c.install:
            plans.extend(c.install)
    if not plans:
        print("Nothing to install: what is missing has to be fixed by hand (see above).\n")
        return False
    unique = []
    for plan in plans:
        if plan not in unique:
            unique.append(plan)
    print("This will install system packages:")
    for plan in unique:
        print("  " + describe(plan))
    if not assume_yes:
        if not sys.stdin.isatty():
            print("\nNot a terminal, so not asking: pass --yes to run them.")
            return False
        if input("\nRun them? [y/N] ").strip().lower() not in ("y", "yes"):
            print("Skipped.\n")
            return False
    for plan in unique:
        if not execute(plan):
            return False
    print()
    return True


def gather(skip_llvm):
    checks = [check_python(), check_platform(), check_disk(), check_toolchain(), check_git()]
    if not skip_llvm:
        network = check_network()
        if network is not None:
            checks.append(network)
        checks.append(check_llvm())
    return checks


def blocked(checks):
    return [c for c in checks if c.status == FAIL]


def next_steps():
    if sys.platform == "win32":
        shell = "pwsh" if shutil.which("pwsh") else "powershell -ExecutionPolicy Bypass"
        return (f"  {shell} -File tools/bootstrap.ps1 -Out build/gen0.exe\n"
                "  (the README has the rest of the bootstrap)")
    return ("  tools/bootstrap.sh --seed --out build/gen0\n"
            "  (the README has the rest of the bootstrap)")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="only check; exit 1 if the machine cannot build Prismio")
    ap.add_argument("--install-system-deps", action="store_true",
                    help="install missing system packages (asks first)")
    ap.add_argument("--yes", action="store_true", help="do not ask before installing")
    ap.add_argument("--skip-llvm", action="store_true", help="do not look at or provision LLVM")
    args = ap.parse_args()

    print("Checking this machine for a Prismio build\n")
    checks = gather(args.skip_llvm)
    report(checks)

    if blocked(checks) and args.install_system_deps and not args.check:
        if install_missing(checks, args.yes):
            print("Checking again\n")
            checks = gather(args.skip_llvm)
            report(checks)

    if blocked(checks):
        print("Not ready: fix what is marked missing above, then run this again.")
        return 1
    if args.check:
        print("Ready to build.")
        return 0

    if not args.skip_llvm and not llvm_prepared():
        print("Provisioning the pinned LLVM\n")
        code = subprocess.call([sys.executable, str(HERE / "setup_llvm.py")])
        if code != 0:
            return code
        print()
    print("Ready. Next:\n" + next_steps())
    return 0


if __name__ == "__main__":
    sys.exit(main())
