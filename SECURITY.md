# Security policy

## Reporting

Email **security@prismio.org**. Do not open a public issue for something you
believe is exploitable.

Include what you can:

- The Prismio version or commit (`prismio --version`), and the platform.
- A minimal program or input that shows the problem, and what happens.
- What an attacker controls, and what they gain.

You will get an acknowledgement, and a fix or mitigation will be coordinated with
you before anything is disclosed. The project is maintained by a small team
before its first release, so there is no promised response time, but reports are
treated as the first priority.

## What counts

A compiler's security issues are mostly about the programs it builds:

- **Generated code that corrupts memory**: a use after free, a double free, or
  an out-of-bounds access in a program the compiler accepted, where the input
  that triggers it can come from outside the program. `prismio run --verify`
  reports such a free as a *violation*.
- **The runtime** (`runtime/*.c`): the allocator, strings, collections, files,
  processes, channels.
- **The toolchain and its distribution**: `install.sh`, the release archives and
  their SHA-256 checksums, and the build driver's handling of paths and
  subprocesses.

A memory-safety bug you can only reach from the program's own source, with no
outside input, is a correctness bug. Open a public issue for it, with the
program and its `--verify` output. [KNOWN_ISSUES.md](KNOWN_ISSUES.md) lists the
shapes already known.

Report vulnerabilities in LLVM, the C library or other dependencies to their
maintainers. If Prismio's pinned LLVM needs updating as a result, tell us too.

## Supported versions

Prismio has not had a release yet. Fixes land on `main`. Once 0.1.0 is
published, security fixes will go to the latest release and `main`.
