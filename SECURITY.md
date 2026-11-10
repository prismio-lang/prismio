# Security Policy

## Reporting a Vulnerability

Security issues affecting the Prismio compiler, runtime, tooling, package infrastructure, or associated ecosystem components should be reported responsibly and privately.

Please do not open public GitHub issues for security vulnerabilities.

Instead, report vulnerabilities confidentially via email:

- security@prismio.org

Include the following information where possible:

- A clear description of the issue
- Steps required to reproduce it
- Affected component(s) and platform(s)
- Relevant proof-of-concept code, logs, screenshots, or test cases
- Potential impact assessment
- Contact information for follow-up communication

---

## Scope

This policy currently applies to:

- Prismio compiler
- Runtime library
- LLVM bridge layer
- Package and build tooling
- Official Prismio infrastructure and repositories

## What to trust

Building a project is running code, and the policy is written with that in mind:

- A project's `build.ums` can declare commands that run scripts, `native` blocks that
  compile and link C sources with the system's C compiler, and a `toolchain.host`
  that is an executable the build runs. Do not build or run a project you do not trust
  any more than you would run its install script.
- Release archives are published with a SHA-256 beside each one. **They are not
  signed**; the checksum proves the download is intact, not who made it. Take both
  from the same release page, over HTTPS.
- The compiler links one pinned LLVM (23.1.5, verified by SHA-256 when it is
  downloaded) statically. LLVM's own vulnerabilities are reported to LLVM, and the
  pin is moved when they require it.

Third-party dependencies and external LLVM vulnerabilities should be reported to their respective maintainers when applicable.

---

## Response Timeline

Prismio aims to:

- Acknowledge reports within 48 hours
- Provide an initial assessment within 7 days
- Coordinate fixes and responsible disclosure timelines where necessary

Response times may vary depending on issue complexity and project activity.

---

## Supported Versions

Security support is currently focused on:

| Version | Support Status |
|---|---|
| `main` (development) | Fully supported |
| 0.1.x, the latest release | Fully supported |
| The previous minor release, once there is one | Critical issues only |
| Anything older, and pre-release candidates | Not supported |

Prismio is pre-1.0: the language and library can change incompatibly between minor
releases, and a security fix may ship only in the newest one. Stay on the latest.

---

## Responsible Disclosure

Please avoid publicly disclosing vulnerabilities until:
- the issue has been verified,
- a fix or mitigation has been prepared,
- and coordinated disclosure has been discussed.

This helps protect users and downstream projects relying on the Prismio ecosystem.

---

## Acknowledgements

Responsible security disclosures that help improve the stability and safety of the Prismio ecosystem are appreciated.

Thank you for helping improve the reliability and security of the project.