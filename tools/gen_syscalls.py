#!/usr/bin/env python3
"""Writes std/syscall.psm: the system-call numbers and constants of Linux and macOS.

The numbers are not typed here. They are read from the headers each kernel ships:

  Linux x86_64   <sysroot>/x86_64-linux-android/asm/unistd_64.h      (the kernel's uapi header)
  Linux arm64    <sysroot>/aarch64-linux-android/asm/unistd_64.h
  macOS          <MacOSX.sdk>/usr/include/sys/syscall.h               (XNU's syscalls.master)

and the constants (open flags, protection bits, errno, ...) from the same trees. A call that
a header does not number on an OS is simply not generated for it. `--check` regenerates in
memory and fails when std/syscall.psm differs, which is what keeps a hand edit from drifting
from the headers.

    python3 tools/gen_syscalls.py [--check] [--sysroot DIR] [--sdk DIR]

Linux arm64 has no `open`, `pipe`, `dup2`, `mkdir`, `unlink`, `rename`, `rmdir` or `readlink`
(only the `*at` forms), so the Linux wrappers use the `*at` form on both architectures and
one wrapper answers the same on x86_64 and arm64.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "std" / "syscall.psm"

NDK_GLOB = Path.home() / "Library/Android/sdk/ndk"

# Parameter types and how each reaches the kernel as a U64.
CONVERT = {
    "Int": "{} as U64",
    "I64": "{} as U64",
    "Usize": "{} as U64",
}

# One entry per wrapper: the name, its parameters, and for each OS the header name of the call
# and the six argument expressions (a parameter's name, or an integer literal such as -100).
# `None` for an OS means that OS has no such call, or has it with a convention the wrapper
# cannot honour (macOS `pipe` answers its two descriptors in registers, not through a pointer).
CALLS = [
    ("read", "reads up to `count` bytes from `fd`; answers the count, 0 at end of file",
     [("fd", "Int"), ("buffer", "Usize"), ("count", "Usize")],
     ("read", ["fd", "buffer", "count"]), ("read", ["fd", "buffer", "count"])),
    ("write", "writes `count` bytes to `fd`; answers the count written",
     [("fd", "Int"), ("buffer", "Usize"), ("count", "Usize")],
     ("write", ["fd", "buffer", "count"]), ("write", ["fd", "buffer", "count"])),
    ("open", "opens the NUL-terminated `path`; answers a descriptor (Linux: openat(AT_FDCWD, ...))",
     [("path", "Usize"), ("flags", "Int"), ("mode", "Int")],
     ("openat", ["-100", "path", "flags", "mode"]), ("open", ["path", "flags", "mode"])),
    ("close", "closes a descriptor",
     [("fd", "Int")],
     ("close", ["fd"]), ("close", ["fd"])),
    ("lseek", "moves the file offset; answers the new offset",
     [("fd", "Int"), ("offset", "I64"), ("whence", "Int")],
     ("lseek", ["fd", "offset", "whence"]), ("lseek", ["fd", "offset", "whence"])),
    ("mmap", "maps memory; answers the address, or -errno",
     [("address", "Usize"), ("length", "Usize"), ("protection", "Int"), ("flags", "Int"),
      ("fd", "Int"), ("offset", "I64")],
     ("mmap", ["address", "length", "protection", "flags", "fd", "offset"]),
     ("mmap", ["address", "length", "protection", "flags", "fd", "offset"])),
    ("munmap", "unmaps memory",
     [("address", "Usize"), ("length", "Usize")],
     ("munmap", ["address", "length"]), ("munmap", ["address", "length"])),
    ("mprotect", "changes the protection of mapped memory",
     [("address", "Usize"), ("length", "Usize"), ("protection", "Int")],
     ("mprotect", ["address", "length", "protection"]), ("mprotect", ["address", "length", "protection"])),
    ("brk", "moves the program break (Linux only); answers the new break",
     [("address", "Usize")],
     ("brk", ["address"]), None),
    ("ioctl", "device control; `argument` is the request's operand",
     [("fd", "Int"), ("request", "Usize"), ("argument", "Usize")],
     ("ioctl", ["fd", "request", "argument"]), ("ioctl", ["fd", "request", "argument"])),
    ("fcntl", "file descriptor control",
     [("fd", "Int"), ("command", "Int"), ("argument", "Usize")],
     ("fcntl", ["fd", "command", "argument"]), ("fcntl", ["fd", "command", "argument"])),
    ("dup", "duplicates a descriptor",
     [("fd", "Int")],
     ("dup", ["fd"]), ("dup", ["fd"])),
    ("dup2", "duplicates `fd` onto `target` (Linux: dup3 with no flags)",
     [("fd", "Int"), ("target", "Int")],
     ("dup3", ["fd", "target", "0"]), ("dup2", ["fd", "target"])),
    ("pipe", "creates a pipe; `fds` receives two Ints (Linux only: macOS answers the pair in registers)",
     [("fds", "Usize")],
     ("pipe2", ["fds", "0"]), None),
    ("chdir", "changes the working directory",
     [("path", "Usize")],
     ("chdir", ["path"]), ("chdir", ["path"])),
    ("getcwd", "writes the working directory into `buffer` (Linux only)",
     [("buffer", "Usize"), ("size", "Usize")],
     ("getcwd", ["buffer", "size"]), None),
    ("mkdir", "creates a directory (Linux: mkdirat(AT_FDCWD, ...))",
     [("path", "Usize"), ("mode", "Int")],
     ("mkdirat", ["-100", "path", "mode"]), ("mkdir", ["path", "mode"])),
    ("unlink", "removes a file (Linux: unlinkat(AT_FDCWD, ..., 0))",
     [("path", "Usize")],
     ("unlinkat", ["-100", "path", "0"]), ("unlink", ["path"])),
    ("rmdir", "removes an empty directory (Linux: unlinkat with AT_REMOVEDIR)",
     [("path", "Usize")],
     ("unlinkat", ["-100", "path", "0x200"]), ("rmdir", ["path"])),
    ("rename", "renames a file (Linux: renameat)",
     [("from", "Usize"), ("to", "Usize")],
     ("renameat", ["-100", "from", "-100", "to"]), ("rename", ["from", "to"])),
    ("readlink", "reads a symbolic link into `buffer`; answers the length",
     [("path", "Usize"), ("buffer", "Usize"), ("size", "Usize")],
     ("readlinkat", ["-100", "path", "buffer", "size"]), ("readlink", ["path", "buffer", "size"])),
    ("execve", "replaces the process image",
     [("path", "Usize"), ("argv", "Usize"), ("envp", "Usize")],
     ("execve", ["path", "argv", "envp"]), ("execve", ["path", "argv", "envp"])),
    ("wait4", "waits for a child; answers its pid",
     [("pid", "Int"), ("status", "Usize"), ("options", "Int"), ("usage", "Usize")],
     ("wait4", ["pid", "status", "options", "usage"]), ("wait4", ["pid", "status", "options", "usage"])),
    ("exit", "ends the calling thread (macOS: the process)",
     [("code", "Int")],
     ("exit", ["code"]), ("exit", ["code"])),
    ("exitGroup", "ends every thread of the process (Linux only: macOS `exit` already does)",
     [("code", "Int")],
     ("exit_group", ["code"]), None),
    ("getpid", "the process id",
     [],
     ("getpid", []), ("getpid", [])),
    ("getppid", "the parent's process id",
     [],
     ("getppid", []), ("getppid", [])),
    ("getuid", "the real user id",
     [],
     ("getuid", []), ("getuid", [])),
    ("gettid", "the thread id (Linux only)",
     [],
     ("gettid", []), None),
    ("kill", "sends a signal",
     [("pid", "Int"), ("signal", "Int")],
     ("kill", ["pid", "signal"]), ("kill", ["pid", "signal"])),
    ("clockGettime", "reads a clock into a `{ seconds: I64, nanoseconds: I64 }` at `time` (Linux only)",
     [("clock", "Int"), ("time", "Usize")],
     ("clock_gettime", ["clock", "time"]), None),
    ("gettimeofday", "reads the wall clock into a `{ seconds: I64, microseconds: I64 }` at `time` (macOS only)",
     [("time", "Usize"), ("zone", "Usize")],
     None, ("gettimeofday", ["time", "zone"])),
    ("getrandom", "fills `buffer` with random bytes (Linux only; macOS: getentropy)",
     [("buffer", "Usize"), ("length", "Usize"), ("flags", "Int")],
     ("getrandom", ["buffer", "length", "flags"]), None),
    ("getentropy", "fills `buffer` with up to 256 random bytes (macOS only)",
     [("buffer", "Usize"), ("length", "Usize")],
     None, ("getentropy", ["buffer", "length"])),
    ("socket", "creates a socket",
     [("domain", "Int"), ("kind", "Int"), ("protocol", "Int")],
     ("socket", ["domain", "kind", "protocol"]), ("socket", ["domain", "kind", "protocol"])),
    ("connect", "connects a socket to the address at `address`",
     [("fd", "Int"), ("address", "Usize"), ("length", "Int")],
     ("connect", ["fd", "address", "length"]), ("connect", ["fd", "address", "length"])),
    ("bind", "binds a socket to the address at `address`",
     [("fd", "Int"), ("address", "Usize"), ("length", "Int")],
     ("bind", ["fd", "address", "length"]), ("bind", ["fd", "address", "length"])),
    ("listen", "marks a socket as accepting connections",
     [("fd", "Int"), ("backlog", "Int")],
     ("listen", ["fd", "backlog"]), ("listen", ["fd", "backlog"])),
    ("accept", "accepts a connection; answers its descriptor",
     [("fd", "Int"), ("address", "Usize"), ("length", "Usize")],
     ("accept", ["fd", "address", "length"]), ("accept", ["fd", "address", "length"])),
    ("shutdown", "shuts down part of a connection",
     [("fd", "Int"), ("how", "Int")],
     ("shutdown", ["fd", "how"]), ("shutdown", ["fd", "how"])),
    ("sendto", "sends a datagram or stream bytes",
     [("fd", "Int"), ("buffer", "Usize"), ("length", "Usize"), ("flags", "Int"), ("address", "Usize"),
      ("addressLength", "Int")],
     ("sendto", ["fd", "buffer", "length", "flags", "address", "addressLength"]),
     ("sendto", ["fd", "buffer", "length", "flags", "address", "addressLength"])),
    ("recvfrom", "receives bytes",
     [("fd", "Int"), ("buffer", "Usize"), ("length", "Usize"), ("flags", "Int"), ("address", "Usize"),
      ("addressLength", "Usize")],
     ("recvfrom", ["fd", "buffer", "length", "flags", "address", "addressLength"]),
     ("recvfrom", ["fd", "buffer", "length", "flags", "address", "addressLength"])),
    ("sched_yield", "gives up the processor",
     [],
     ("sched_yield", []), ("swtch", [])),
]

# Constants copied by name from the headers. (Prismio name, [header names to try]).
# **Only values equal on x86_64 and arm64 Linux are listed**: O_DIRECTORY, O_NOFOLLOW and
# O_DIRECT differ between them, so a program that needs one writes the number for its target.
LINUX_CONSTANTS = [
    ("O_RDONLY", ["O_RDONLY"]), ("O_WRONLY", ["O_WRONLY"]), ("O_RDWR", ["O_RDWR"]),
    ("O_CREAT", ["O_CREAT"]), ("O_EXCL", ["O_EXCL"]), ("O_TRUNC", ["O_TRUNC"]),
    ("O_APPEND", ["O_APPEND"]), ("O_NONBLOCK", ["O_NONBLOCK"]), ("O_CLOEXEC", ["O_CLOEXEC"]),
    ("AT_FDCWD", ["AT_FDCWD"]),
    ("SEEK_SET", ["SEEK_SET"]), ("SEEK_CUR", ["SEEK_CUR"]), ("SEEK_END", ["SEEK_END"]),
    ("PROT_NONE", ["PROT_NONE"]), ("PROT_READ", ["PROT_READ"]), ("PROT_WRITE", ["PROT_WRITE"]),
    ("PROT_EXEC", ["PROT_EXEC"]),
    ("MAP_SHARED", ["MAP_SHARED"]), ("MAP_PRIVATE", ["MAP_PRIVATE"]), ("MAP_FIXED", ["MAP_FIXED"]),
    ("MAP_ANONYMOUS", ["MAP_ANONYMOUS", "MAP_ANON"]),
    ("F_GETFD", ["F_GETFD"]), ("F_SETFD", ["F_SETFD"]), ("F_GETFL", ["F_GETFL"]), ("F_SETFL", ["F_SETFL"]),
    ("AF_UNIX", ["AF_UNIX"]), ("AF_INET", ["AF_INET"]), ("AF_INET6", ["AF_INET6"]),
    ("SOCK_STREAM", ["SOCK_STREAM"]), ("SOCK_DGRAM", ["SOCK_DGRAM"]),
    ("SIGHUP", ["SIGHUP"]), ("SIGINT", ["SIGINT"]), ("SIGKILL", ["SIGKILL"]), ("SIGTERM", ["SIGTERM"]),
    ("CLOCK_REALTIME", ["CLOCK_REALTIME"]), ("CLOCK_MONOTONIC", ["CLOCK_MONOTONIC"]),
    ("EPERM", ["EPERM"]), ("ENOENT", ["ENOENT"]), ("EINTR", ["EINTR"]), ("EIO", ["EIO"]),
    ("EBADF", ["EBADF"]), ("EAGAIN", ["EAGAIN"]), ("ENOMEM", ["ENOMEM"]), ("EACCES", ["EACCES"]),
    ("EEXIST", ["EEXIST"]), ("ENOTDIR", ["ENOTDIR"]), ("EISDIR", ["EISDIR"]), ("EINVAL", ["EINVAL"]),
    ("EMFILE", ["EMFILE"]), ("ENOSPC", ["ENOSPC"]), ("EPIPE", ["EPIPE"]), ("ENOSYS", ["ENOSYS"]),
]
MACOS_CONSTANTS = [(n, alts) for n, alts in LINUX_CONSTANTS if n != "AT_FDCWD"] + [
    ("AT_FDCWD", ["AT_FDCWD"]),
]

LINUX_HEADERS = ["asm-generic/fcntl.h", "asm-generic/mman-common.h", "asm-generic/mman.h",
                 "asm-generic/errno-base.h", "asm-generic/errno.h", "linux/fcntl.h",
                 "linux/mman.h", "linux/signal.h", "asm-generic/signal.h", "linux/time.h",
                 "linux/stat.h", "linux/socket.h", "asm-generic/socket.h", "linux/net.h"]
MACOS_HEADERS = ["sys/fcntl.h", "sys/mman.h", "sys/errno.h", "sys/signal.h", "sys/socket.h",
                 "sys/_types/_seek_set.h", "sys/stdio.h", "sys/unistd.h", "sys/_types.h",
                 "time.h", "sys/time.h", "sys/syslimits.h", "sys/fcntl.h"]


class Failure(Exception):
    pass


def find_sysroot():
    for ndk in sorted(NDK_GLOB.glob("*")):
        for sysroot in ndk.glob("toolchains/llvm/prebuilt/*/sysroot/usr/include"):
            if (sysroot / "x86_64-linux-android/asm/unistd_64.h").exists():
                return sysroot
    raise Failure("no Linux uapi headers found: pass --sysroot (an NDK's sysroot/usr/include)")


def find_sdk():
    try:
        out = subprocess.run(["xcrun", "--show-sdk-path"], capture_output=True, text=True, check=True)
        sdk = Path(out.stdout.strip())
    except (OSError, subprocess.CalledProcessError):
        sdk = Path("/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")
    if not (sdk / "usr/include/sys/syscall.h").exists():
        raise Failure("no macOS SDK found: pass --sdk")
    return sdk


DEFINE = re.compile(r"^\s*#\s*define\s+(\w+)\s+(.+?)\s*(?:/\*.*)?$")


def read_defines(paths):
    defines = {}
    for path in paths:
        if not path.exists():
            continue
        for line in path.read_text(errors="replace").splitlines():
            m = DEFINE.match(line)
            if m and m.group(1) not in defines:
                defines[m.group(1)] = m.group(2).strip()
    return defines


def evaluate(text, defines, depth=0):
    """A define's integer value, following references to other defines. None if it is not one."""
    if depth > 8:
        return None
    text = text.strip()
    text = re.sub(r"\b(\d+|0x[0-9a-fA-F]+)[uUlL]+\b", r"\1", text)
    # A leading 0 is octal in C and a SyntaxError in Python.
    text = re.sub(r"\b0([0-7]+)\b", lambda m: str(int(m.group(1), 8)), text)

    def name(m):
        word = m.group(0)
        if word in defines:
            inner = evaluate(defines[word], defines, depth + 1)
            if inner is not None:
                return str(inner)
        return word

    text = re.sub(r"\b[A-Za-z_]\w*\b", name, text)
    if not re.fullmatch(r"[-+*/%<>|&^~()\d\sxXa-fA-F]+", text):
        return None
    try:
        return int(eval(text, {"__builtins__": {}}, {}))
    except Exception:
        return None


def numbers(path, prefix):
    result = {}
    defines = read_defines([path])
    for key, value in defines.items():
        if key.startswith(prefix):
            n = evaluate(value, defines)
            if n is not None:
                result[key[len(prefix):]] = n
    return result


def constants(wanted, defines):
    out = []
    for name, alternatives in wanted:
        for alt in alternatives:
            if alt in defines:
                n = evaluate(defines[alt], defines)
                if n is not None:
                    out.append((name, n))
                    break
    return out


def literal(value):
    """An argument that is a number: the 64-bit pattern, in hex when negative."""
    n = int(value, 0)
    if n < 0:
        n += 1 << 64
        return "0x{:X}".format(n)
    return str(n)


def argument(expr, params):
    types = dict(params)
    if expr in types:
        return CONVERT[types[expr]].format(expr)
    return literal(expr)


def sources_label(sysroot, sdk):
    """Which headers the table was read from, written into the file. The numbers move between
    NDK and SDK releases, so a machine with other ones regenerates a different file and `--check`
    there would call a correct table stale (the macOS CI runner did, 2026-11-10)."""
    ndk = next((part for previous, part in zip(sysroot.parts, sysroot.parts[1:]) if previous == "ndk"), "unknown")
    try:
        version = json.loads((sdk / "SDKSettings.json").read_text())["Version"]
    except (OSError, ValueError, KeyError):
        version = "unknown"
    return "Android NDK {}, macOS SDK {}".format(ndk, version)


def render(sysroot, sdk):
    lx = numbers(sysroot / "x86_64-linux-android/asm/unistd_64.h", "__NR_")
    la = numbers(sysroot / "aarch64-linux-android/asm/unistd_64.h", "__NR_")
    mac = numbers(sdk / "usr/include/sys/syscall.h", "SYS_")

    linux_defines = read_defines([sysroot / h for h in LINUX_HEADERS]
                                 + [sysroot / "x86_64-linux-android" / "asm" / "fcntl.h"])
    mac_defines = read_defines([sdk / "usr/include" / h for h in MACOS_HEADERS])

    out = []
    w = out.append
    w("// GENERATED by tools/gen_syscalls.py -- edit the generator, not this file.")
    w("// Read from {}.\n".format(sources_label(sysroot, sdk)))
    w(HEADER)

    for name, doc, params, lin, mc in CALLS:
        pass

    # Raw
    w(RAW)

    # Constants
    for prefix, table in (("LINUX", constants(LINUX_CONSTANTS, linux_defines)),
                          ("MACOS", constants(MACOS_CONSTANTS, mac_defines))):
        w("")
        w("// {} constants, read from {}.".format(
            prefix.capitalize() if prefix == "LINUX" else "macOS",
            "the kernel's uapi headers (the values are the same on x86_64 and arm64)" if prefix == "LINUX"
            else "the macOS SDK (the same on x86_64 and arm64)"))
        for cname, value in table:
            w("public const {}_{} = {}".format(prefix, cname, value))

    # Linux
    w(LINUX_TYPES)
    for name, doc, params, lin, mc in CALLS:
        if lin is None:
            continue
        header, args = lin
        if header not in lx or header not in la:
            continue
        w(method(name, doc, params, args, "linuxNumber({}, {})".format(lx[header], la[header]), "LinuxSyscalls"))
    w("}")

    # macOS
    w(MACOS_TYPES)
    for name, doc, params, mc_ in [(n, d, p, m) for n, d, p, l, m in CALLS]:
        if mc_ is None:
            continue
        header, args = mc_
        if header not in mac:
            continue
        w(method(name, re.sub(r" \((Linux|macOS)[^)]*\)", "", doc), params, args, str(mac[header]), "MacosSyscalls"))
    w("}")
    return "\n".join(out) + "\n"


def method(name, doc, params, args, number, owner):
    signature = ", ".join(["self"] + ["{}: {}".format(n, t) for n, t in params])
    padded = [argument(a, params) for a in args] + ["0"] * (6 - len(args))
    return "\n    // {}.\n    public fn {}({}) -> I64 {{\n        return __builtin_syscall({}, {})\n    }}".format(
        doc[0].upper() + doc[1:], name, signature, number, ", ".join(padded))


HEADER = '''//
// System calls, with no C library under them: the raw instruction, and the calls of Linux and
// macOS by name.
//
//     import std.syscall
//
//     linux.syscall.write(1, buffer, count)
//     macos.syscall.write(1, buffer, count)
//     let pid = syscall(39)                      // the raw form: a number and up to six operands
//
//     linux {                                    // only compiled when the target is Linux
//         let n = linux.syscall.getpid()
//     }
//
// **A call answers what the kernel answers, with a failure as `-errno` on every target.**
// Linux already does. macOS reports failure with the carry flag and a positive errno, and the
// instruction sequence the compiler emits negates it, so `if (result < 0)` and
// `syscallErrno(result)` mean one thing everywhere. A result between -4095 and -1 is an error;
// a larger magnitude is a valid answer (an address from `mmap` can look negative as an `I64`).
//
// **The numbers are read from the kernels' headers**, not typed: Linux x86_64 and arm64 from
// the uapi `unistd_64.h` of each, macOS from the SDK's `sys/syscall.h`. tools/gen_syscalls.py
// writes this file, and `--check` fails when it differs. A call the headers do not number on an
// OS is not in that OS's table: arm64 Linux has no `open` or `pipe`, so the Linux wrappers use
// `openat` and `pipe2` on both architectures and answer alike.
//
// **A system call is not portable and this file does not pretend it is.** `linux.syscall`
// exists on every target, and on one that is not Linux the call answers `-ENOSYS` (-38) without
// running anything; write the Linux path in a `linux { }` block to keep it out of the other
// builds. Windows has no stable system-call interface (its numbers change between releases),
// so there is no `windows.syscall`; a `windows { }` block calls the Win32 API with `extern fn`.
//
// **Nothing here checks anything.** An address is a number, a length is whatever is passed, and
// a bad one is as undefined as it is in C. A path is a pointer to a NUL-terminated byte string
// -- a `Buffer` or an `alloc` block -- not a `String`. **An address is a `Usize`**, as in std.raw
// and std.mem, so what `alloc` answers goes in as it is.

'''

RAW = '''
// The raw instruction: the system call `number`, with up to six operands. The number is the
// target's own: Linux's differ between x86_64 and arm64, and macOS's are the BSD numbers.
public fn syscall(number: U64) -> I64 {
    return __builtin_syscall(number, 0, 0, 0, 0, 0, 0)
}

public fn syscall(number: U64, a0: U64) -> I64 {
    return __builtin_syscall(number, a0, 0, 0, 0, 0, 0)
}

public fn syscall(number: U64, a0: U64, a1: U64) -> I64 {
    return __builtin_syscall(number, a0, a1, 0, 0, 0, 0)
}

public fn syscall(number: U64, a0: U64, a1: U64, a2: U64) -> I64 {
    return __builtin_syscall(number, a0, a1, a2, 0, 0, 0)
}

public fn syscall(number: U64, a0: U64, a1: U64, a2: U64, a3: U64) -> I64 {
    return __builtin_syscall(number, a0, a1, a2, a3, 0, 0)
}

public fn syscall(number: U64, a0: U64, a1: U64, a2: U64, a3: U64, a4: U64) -> I64 {
    return __builtin_syscall(number, a0, a1, a2, a3, a4, 0)
}

public fn syscall(number: U64, a0: U64, a1: U64, a2: U64, a3: U64, a4: U64, a5: U64) -> I64 {
    return __builtin_syscall(number, a0, a1, a2, a3, a4, a5)
}

// Whether a result is a failure: `-errno`, which is between -4095 and -1.
public fn syscallFailed(result: I64) -> Bool {
    return result < 0 and result >= -4095
}

// The errno of a failed result, or 0 for a result that is not a failure.
public fn syscallErrno(result: I64) -> Int {
    if (result < 0 and result >= -4095) { return (0 - result) as Int }
    return 0
}

// Linux numbers a call differently on each architecture; the table is read at compile time.
// A function that asks the target is compiled into each program (std/platform.psm says why).
fn linuxNumber(x86_64: U64, arm64: U64) -> U64 {
    if (__builtin_target_arch() == 1) { return x86_64 }
    return arm64
}
'''

LINUX_TYPES = '''
// The type of `linux`: it holds nothing, and `linux.syscall` is the table of Linux calls.
public struct LinuxSyscalls {
}

public struct LinuxPlatform {
    public syscall: LinuxSyscalls
}

// Uninitialised on purpose, as `platform` is: an empty struct has nothing to initialise.
let linux: LinuxPlatform

impl LinuxSyscalls {'''

MACOS_TYPES = '''
// The type of `macos`, and `macos.syscall` its table.
public struct MacosSyscalls {
}

public struct MacosPlatform {
    public syscall: MacosSyscalls
}

let macos: MacosPlatform

impl MacosSyscalls {'''


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--check", action="store_true", help="fail if std/syscall.psm differs")
    parser.add_argument("--sysroot", type=Path, help="an NDK's sysroot/usr/include (Linux uapi headers)")
    parser.add_argument("--sdk", type=Path, help="a macOS SDK")
    args = parser.parse_args()
    try:
        sysroot, sdk = args.sysroot or find_sysroot(), args.sdk or find_sdk()
        text = render(sysroot, sdk)
        if args.check and OUT.exists():
            recorded = OUT.read_text().splitlines()[1:2]
            here = "// Read from {}.".format(sources_label(sysroot, sdk))
            if recorded and recorded[0].startswith("// Read from ") and recorded[0] != here:
                raise Failure("no headers to compare: std/syscall.psm was {}, this machine has {}".format(
                    recorded[0][len("// "):].rstrip(".").replace("Read from", "read from"),
                    here[len("// Read from "):].rstrip(".")))
    except Failure as error:
        print("gen_syscalls: {}".format(error), file=sys.stderr)
        return 1
    if args.check:
        if not OUT.exists() or OUT.read_text() != text:
            print("std/syscall.psm is out of date: run tools/gen_syscalls.py", file=sys.stderr)
            return 1
        return 0
    OUT.write_text(text)
    print("wrote {} ({} bytes)".format(OUT.relative_to(REPO), len(text)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
