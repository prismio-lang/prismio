# Releasing Prismio

The order is the point: **nothing is tagged until three platforms have agreed on
the exact commit that would be tagged.** A tag is the one artifact that cannot be
corrected quietly.

Everything below is a project command from `build.ums`, run as `prismio <command>`
from the checkout. What is still open is [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)
plus whichever step below has not yet gone green on all three platforms; there is
no separate checklist. Fill the numbers into the release notes from the candidate
that is tagged, never from an earlier one.

| Command | What it is for |
|---|---|
| `prismio build` | builds the compiler this checkout runs (`.prismio/build/debug/prismio`) |
| `prismio suite` | the test suite, for the fast loop |
| `prismio verify` | suite, source lists, externs, AIF differential |
| `prismio gate` | the pre-push gate: lint, then the release gate on a packaged candidate |
| `prismio release` | the archive and its checksum for **this** host |
| `prismio bench` | the cross-language benchmarks |

## 0 · The commit

The release candidate is **`main`'s head at push time**, so everything that is
generated from the tree is refreshed *first*, in the commit that gets tested,
never after it. A refresh after the gate makes a new commit the gate has not seen.

```bash
prismio build && prismio build       # twice: the host must be a fixpoint of this src/
graphify update .                    # AST only, no API cost
git status --short                   # only the intended files; no stray .prismio-* or build/
```

The **seed** is what a new machine builds the compiler from. It is not part of the
tree: it is a release asset, and `bootstrap/seed.json` pins which one by version and
SHA-256 (`tools/fetch_seed.py` downloads and checks it). The gate builds from it, so a
commit is releasable only while the pinned seed can still parse `src/`. A new seed is
cut *after* a tag, from the compiler that was tagged (step 5), so there is nothing to
refresh before the gate. `graphify-out/` (`graph.json`, `GRAPH_REPORT.md`, `manifest.json`,
`graph.html`) is committed with the change that moved it.

```bash
git log --oneline -1     # the commit CI will run on
prismio gate             # must be green on it
```

A clean checkout of that commit, bootstrapped once, must emit byte-identical
compiler IR to the packaged candidate. The gate checks it, and it is what makes
the tag reproduce the candidate rather than sit beside it. **Re-run the gate on the
commit you are about to tag.** It takes minutes and is the only thing that makes
the tag mean what the release notes say.

## 1 · The local gate

```bash
prismio gate
```

It lints, packages the host the way a user installs it (a bare generation has no
`lib/runtime/*.bc`, so every program the suite builds would fail), puts the pinned
LLVM first on `PATH` (the system's `clang` and `llvm-nm` cannot read LLVM 23
bitcode), and runs the release gate: the two-generation byte-identical fixpoint,
the candidate reproducing, the pinned release seed, the suite, the AIF differential,
the corpus built and run, the `--verify` sweep, the JIT, the cross target, and
packaging with toolchain separation. Every check must be green.

Record the run in the release commit's message; it carries its own evidence.
`prismio verify` is the cheaper subset for the fast loop. Two fixtures cannot be
trusted through the `prismio` command itself, because they replace the compiler
the command is running on: the suite's ums host-routing test reports one failure
there that `python3 tools/run_suite.py` does not, so use the direct form as the
final word.

## 2 · The three-platform matrix — **needs authorisation**

CI does not run on push: it is started by hand on the commit being judged.
Once that commit is pushed, run it with `gh workflow run ci.yml --ref main` (or the
Actions tab's **Run workflow**) and find the run with `gh run list --workflow ci.yml`.
It does source lists, a three-generation bootstrap **from the pinned
release seed**, the fixpoint, the suite, the AIF differential, the seed neutrality check, packaging,
`verify_separation`, and a clean-environment smoke test of the packaged toolchain
outside the checkout, on `windows-latest`, `ubuntu-latest` and `macos-latest`.

```bash
git push origin main                       # needs the owner's go-ahead
gh workflow run ci.yml --ref main          # nothing runs until this
gh run watch --exit-status                 # pick the new run; wait for all three
```

Do not go past this step until all three jobs are green **on the exact commit you
pushed**. If one is red, fix, re-run `prismio gate`, and push again; the commit
changes, so the earlier runs prove nothing about it.

## 3 · Artifacts and checksums

On **each** platform, from a checkout of the gate-green commit:

```bash
prismio build
prismio release
```

`prismio release` has the project host run `build --release`, checks the result is
a fixpoint, packages it with runtime bitcode and `std` rebuilt from source, runs
the separation checks, and writes `dist/release/prismio-<version>-<os>-<arch>`:
`.tar.gz` on macOS and Linux, `.zip` on Windows, with a `.sha256` beside it. The
three `.sha256` files concatenate into one manifest, which is how three machines
produce one checksum file without any trusting the others. To ship an already
gate-green compiler instead of rebuilding, pass its binary (a bare
generation is fine; `release.py` packages it): `prismio release --compiler <binary>`.

**It reads the oldest system the artifact runs on off the binaries**, because
nothing else would notice. A macOS archive must say `minos 14.0` for the compiler
(the LLVM it links) and `11.0` for the programs it builds; the 0.1.0 candidate said
`minos 27.0`, the build machine's version, and would not start on macOS 26. A
Windows archive must not import the Visual C++ runtime. **Linux has no such
check**: glibc binds every symbol to the build machine's version, so build the
Linux artifact on the oldest distribution you mean to support and copy the glibc
version it prints into the release notes.

`POST_INSTALL.txt` is read by nothing in this repository: the Windows `.exe`
installer, which lives elsewhere, displays it after a successful install. Do not
remove it because a grep finds no user.

**Signing.** Artifacts are not signed and the release notes do not claim they are.
The checksum is the integrity story. If signing is added it belongs in
`tools/release.py` beside the checksum, not in a manual step.

## 4 · Clean-environment smoke test

Unpack somewhere that is **not** the checkout, which would otherwise supply
whatever the package forgot, and build a program the checkout does not contain:

```bash
tar -xzf prismio-0.1.0-macos-arm64.tar.gz       # Windows: unzip the .zip
cd /tmp/clean && ./prismio-0.1.0-macos-arm64/bin/prismio --version
./prismio-0.1.0-macos-arm64/bin/prismio build smoke.psm -o smoke && ./smoke
```

The installer has its own check, because `curl ... | sh` is how most people arrive: from
the unpacked archive's directory, `PRISMIO_INSTALL=$(mktemp -d)/p PRISMIO_NO_MODIFY_PATH=1
PRISMIO_TARBALL=<archive> sh install.sh` must verify the `.sha256`, report the version, and
leave a compiler that builds `smoke.psm`. After the tag, `curl -fsSL https://prismio.org/install.sh | sh`
must do the same from the published release (the site's copy is
`../website/apps/web/public/install.sh`; keep it identical to the root `install.sh`).

`smoke.psm` is the program inlined in `.github/workflows/ci.yml`. It exercises
`sort`, an annotated `Map<Int, Int>` and a `Channel<T>` round trip, and prints
`18`: the annotated generic is the shape that once did not link, and the channel is
what 0.1.0 adds.

## 5 · Tag and publish — **needs explicit authorisation**

Only after steps 2–4 are green on all three platforms:

```bash
git tag -a v0.1.0 -m "Prismio 0.1.0"        # on main's head, gate-green
git push origin v0.1.0

# The notes are the docs site's page, `../website/apps/docs/content/releases/0.1.0.md`;
# there is no CHANGELOG.md. gh wants the body without the page's front matter:
awk '/^---$/ && n < 2 { n++; next } n >= 2' \
    ../website/apps/docs/content/releases/0.1.0.md > dist/release/NOTES.md

gh release create v0.1.0 \
    --title "Prismio 0.1.0" \
    --notes-file dist/release/NOTES.md \
    dist/release/prismio-0.1.0-*.tar.gz dist/release/prismio-0.1.0-*.zip \
    dist/release/prismio-0.1.0-*.sha256
```

**Then cut the release's seed**, from the compiler that was just tagged. It is a
release asset like the archives, and the next release's `bootstrap/seed.json` pins it:

```bash
tools/refresh_seed.sh --compiler <the tagged compiler>    # .ps1 on Windows; writes bootstrap/prismio-seed-0.1.0.ll and the pin
gh release upload v0.1.0 bootstrap/prismio-seed-0.1.0.ll
git add bootstrap/seed.json && git commit -m "bootstrap: pin the 0.1.0 seed"
```

The seed is never in the tagged tree (its hash cannot be known before it exists), so a
tag always builds from the *previous* release's seed, and the gate has already proved
that one can parse `src/`.

**A `v1.0.0` tag already exists in this repository and is older than this work.**
It is not what 0.1.0 releases from and is not touched here. Deleting a published
tag breaks other people's checkouts, so whether to delete it is a separate
decision.

Then publish the docs site from `../website`, at the commit whose
`verify-doc-examples.mjs` passed in both apps against this toolchain. Its
release-notes page is the one the GitHub release was created from, so the two
cannot differ.
