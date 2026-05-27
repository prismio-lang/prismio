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
| Latest development version | Fully supported |
| Previous stable release | Critical issues only |
| Older releases | Not actively supported |

Users are strongly encouraged to remain on the latest stable release.

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