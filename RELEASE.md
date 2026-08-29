# Releasing Prismio

The v0.1.0 procedure, written down because the interesting part is the order:
**nothing is tagged until three platforms have agreed on the exact commit that
would be tagged.** A tag is the one artifact that cannot be corrected quietly.

## 0 · The commit

    63a5bcf7fb266dc9a5a069e1df055f1ab32e94ca      prismio
    1abc716c6e1d763681e45d679e613786eb6daba0      ../docs

Verified: a clean checkout of the compiler commit, bootstrapped once, emits
**byte-identical compiler IR** to the frozen `build/v0.1-rc`. The RC is
reproducible from the tag rather than merely adjacent to it.

## 1 · The local gate — done

```bash
bash tools/release_gate.sh --old build/tbaa3 --rc build/v0.1-rc
```

Fourteen checks, all green. Suite 202/202, two-generation byte-identical
fixpoint, differential 19/19, corpus 30/30 built and run, `--verify` 0 leaked /
0 violations, ASan and TSan clean, packaged toolchain separation verified.
Evidence: `aif/evidence/RESULTS-v01-release-candidate.md`.

## 2 · The three-platform matrix — **BLOCKED, needs authorisation**

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
git push origin main                       # this is the blocked action
gh run watch --exit-status                 # then: wait for all three
```

Do not proceed past this step until all three jobs are green **on
`63a5bcf`**. If any is red, fix, re-run the local gate, and the commit hash in
this file changes.

## 3 · Artifacts and checksums

Run on **each** platform, against that platform's own gate-green build:

```bash
bash tools/release.sh --compiler build/v0.1-rc --version 0.1.0 --out dist/release
```

It refuses to build from a compiler that is not a fixpoint, packages, runs the
separation checks, archives as `prismio-<version>-<triple>.tar.gz`, and writes a
SHA-256 beside it. The three `.sha256` files concatenate into one manifest, which
is what lets three machines produce one checksum file without any of them
trusting the others.

macOS arm64, built from `63a5bcf`:

```
d63a9349f1f9b521c616922b7dc0c56c05f0a2156bf9bc49a080d662a12cb98e  prismio-0.1.0-arm64-apple-darwin.tar.gz
```

**Signing.** This project does not sign artifacts today and the release notes do
not claim it does. The checksum is the integrity story; if signing is added it
belongs in `tools/release.sh` beside the checksum, not in a separate manual step.

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

Done on macOS arm64: `prismio 0.1.0 / llvm 22.1.8`, output `18`.

## 5 · Tag and publish — **needs explicit authorisation**

Only after steps 2–4 are green on all three platforms:

```bash
git tag -a v0.1.0 -m "Prismio 0.1.0" 63a5bcf
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

Then publish the docs site from `../docs` at `1abc716`, whose release-notes page
must match `CHANGELOG.md`. Both were written from the same gate run.
