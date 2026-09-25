# Releasing Prismio

The v0.1.0 procedure, written down because the interesting part is the order:
**nothing is tagged until three platforms have agreed on the exact commit that
would be tagged.** A tag is the one artifact that cannot be corrected quietly.

This file is *how*. What is still left before 0.1.0 can be cut is
[RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md). The numbers a previous candidate
produced (suite 202/202, a macOS checksum from `63a5bcf`) were removed on
2026-09-25, because the tree has moved past that candidate. Fill them in again
from the candidate that is tagged.

## 0 · The commit

The RC is **`main`'s head at push time**. Check it:

```bash
git log --oneline -1                                    # the commit CI will run on
python tools/release_gate.py --rc build/v0.1-rc         # must be green on it
```

A clean checkout of the RC commit, bootstrapped once, must emit
**byte-identical compiler IR** to the frozen `build/v0.1-rc`. That is what makes
the tag reproduce the RC rather than sit beside it.

**Re-run the gate on the commit you are about to tag.** It takes minutes and it
is the only thing that makes the tag mean what the release notes say it means.

## 1 · The local gate

```bash
python tools/release_gate.py --rc build/v0.1-rc
```

Every check must be green: the two-generation byte-identical fixpoint, the RC
reproducing, the seed, the suite, the AIF differential, the corpus built and
run, the `--verify` sweep, the JIT, the cross target, and packaging with
toolchain separation. `--old <compiler>` adds a per-function mnemonic diff
against a previous build. It is optional, and any baseline is a
`tools/bootstrap.sh` away from the commit that had it. Record the run in
`aif/evidence/`, as the first candidate did in
`RESULTS-v01-release-candidate.md`.

## 2 · The three-platform matrix — **needs authorisation**

CI runs on push. The workflow (`.github/workflows/ci.yml`) does source lists, a
three-generation bootstrap **from the committed seed**, the fixpoint, the suite
(which contains the corpus and JIT checks), the AIF differential, the seed
check, packaging, `verify_separation`, and a **clean-environment smoke test** of
the packaged toolchain outside the checkout — on `windows-latest`,
`ubuntu-latest` and `macos-latest`.

The packaging, separation and smoke-test steps are new in this commit. Before
it, nothing in CI exercised the thing a user installs, and an uninstalled
compiler falls back to the runtime sources embedded in its own binary —
silently, so a packaging mistake looked like success.

```bash
git push origin main                       # needs the owner's go-ahead
gh run watch --exit-status                 # then: wait for all three
```

Do not proceed past this step until all three jobs are green **on the exact
commit you pushed**. If any is red, fix, re-run the local gate, and the commit hash in
this file changes.

## 3 · Artifacts and checksums

Run on **each** platform, against that platform's own gate-green build:

```bash
python tools/release.py --compiler build/v0.1-rc --version 0.1.0 --out dist/release
```

It refuses to build from a compiler that is not a fixpoint, packages, runs the
separation checks, archives as `prismio-<version>-<triple>.tar.gz`, and writes a
SHA-256 beside it. The three `.sha256` files concatenate into one manifest, which
is what lets three machines produce one checksum file without any of them
trusting the others.

**`POST_INSTALL.txt` is not dead weight.** Nothing in this repository reads it —
the Windows `.exe` installer, which lives outside this tree, displays it after a
successful install. A grep for it inside the repo finds nothing, which is exactly
why this sentence exists.

**Signing.** This project does not sign artifacts today and the release notes do
not claim it does. The checksum is the integrity story; if signing is added it
belongs in `tools/release.py` beside the checksum, not in a separate manual step.

## 4 · Clean-environment smoke test

Unpack somewhere that is **not** the checkout — the tree would otherwise supply
whatever the package forgot — and build a program the checkout does not contain:

```bash
tar -xzf prismio-0.1.0-arm64-apple-darwin.tar.gz
cd /tmp/clean && ./prismio-0.1.0-arm64-apple-darwin/bin/prismio --version
./prismio-0.1.0-arm64-apple-darwin/bin/prismio build smoke.psm -o smoke && ./smoke
```

`smoke.psm` is the one in the CI step: it exercises `sort`, an **annotated**
`Map<Int, Int>` and a `Channel<T>` round trip, and prints `18`. Those three are
not arbitrary — the annotated generic is the shape that did not link until this
commit, and the channel is the feature this release adds.

## 5 · Tag and publish — **needs explicit authorisation**

Only after steps 2–4 are green on all three platforms:

```bash
git tag -a v0.1.0 -m "Prismio 0.1.0"        # on main's head, gate-green
git push origin v0.1.0

gh release create v0.1.0 \
    --title "Prismio 0.1.0" \
    --notes-file CHANGELOG.md \
    dist/release/prismio-0.1.0-*.tar.gz \
    dist/release/prismio-0.1.0-*.tar.gz.sha256
```

**A `v1.0.0` tag already exists in this repository and is older than this work.**
It is not what 0.1.0 releases from and it is not touched here; whether it should
be deleted is a separate decision, and deleting a published tag is the kind of
thing that breaks other people's checkouts.

Then publish the docs site from `../website`, at the commit whose
`verify-doc-examples.mjs` passed in both apps against this toolchain. Its
release-notes page must match `CHANGELOG.md`.
