"""The `bootstrap` suite's harness tests (the design record, section 4; see tools/testkit/__init__.py)."""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from harness.common import *


def run_object_cache_test():
    """REQUIREMENTS 10, applied to the one module every build shares: the runtime.

    Every build used to compile `lang_runtime.c` and `program_support.c` from
    source and delete the objects, which on this host is 203 ms of a 411 ms build
    of a 34-line program. They are cached now, keyed on the content of the source
    and the compile flags.

    Three assertions, because the first two alone are satisfied by a cache that is
    never invalidated -- and a stale object cache is a silently wrong binary,
    which is the failure this project produces most.

      1. **A cold cache misses and a warm one hits.** Read off the trace rather
         than off the clock: "the second build was faster" is not something a
         test can assert on a shared host.
      2. **A hit still produces a working program.** The cached object is linked,
         so a cache that stored the wrong file would link the wrong runtime.
      3. **A `--verify` build misses on a warm release cache, and hits itself.**
         `--verify` compiles the same file with -DPRISMIO_AIF_VERIFY, so the two
         objects are different objects. Serving the release one to a verify build
         puts half the allocations outside the ledger, silently -- the same
         failure the verify path already refuses an installed runtime.lib for.

    And `PRISMIO_OBJ_CACHE=0` must not consult the cache at all, because a bypass
    that does not bypass is how a stale entry survives the one instruction given
    for getting rid of it.

    **What this cannot check, and why.** The other half of the key is the source
    text, and no test here can move it: a normal build unpacks the runtime
    *embedded in the compiler binary* rather than reading runtime/ from disk
    (build_driver.c, PRISMIO_EMBEDDED_SOURCE_AVAILABLE), so editing the tree
    changes nothing a user build compiles. Content still belongs in the key --
    `prismio bootstrap` does read the filesystem -- but the assertion that would
    exercise it costs a bootstrap, which is minutes.
    """
    print(f"\n{BLUE}--- Running object_cache ---{RESET}")
    problems = []

    fixture = TEST_DIR / "test_09_strings.psm"
    out = scratch() / ".prismio-objcache-check.exe"

    with tempfile.TemporaryDirectory(prefix="prismio-objcache-test-") as cache_dir:
        def build(extra_env=None, extra_args=None):
            env = dict(os.environ)
            # Cleared rather than inherited: this check is about what the cache
            # does, so an ambient PRISMIO_OBJ_CACHE=0 -- someone running the
            # suite with caching off to measure it -- would otherwise fail the
            # test for a reason that has nothing to do with the code.
            env.pop("PRISMIO_OBJ_CACHE", None)
            env["PRISMIO_OBJ_CACHE_DIR"] = cache_dir
            env["PRISMIO_OBJ_CACHE_TRACE"] = "1"
            env.update(extra_env or {})
            cmd = [str(Path(PRISMIO_EXE).resolve()), "build", str(fixture), "-o", str(out)]
            r = subprocess.run(cmd + (extra_args or []), capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
            return r, (r.stdout or "") + (r.stderr or "")

        cold, cold_text = build()
        warm, warm_text = build()

        if cold.returncode != 0 or warm.returncode != 0:
            problems.append("the build failed with the object cache enabled")
        if "[objcache miss] lang_runtime" not in cold_text:
            problems.append("the first build into an empty cache did not report a miss, "
                            "so the trace this check reads is not being produced and "
                            "every assertion below it is vacuous")
        if "[objcache hit] lang_runtime" not in warm_text:
            problems.append("the second build did not hit the cache -- the entry was "
                            "not installed, or the key is not stable across runs")

        # Said directly rather than inferred from the hit above, because the way
        # an install fails is silent: `rename()` cannot cross a filesystem, so a
        # cache directory on a different volume from the temporary would leave a
        # working build that never populates anything.
        installed = [n for n in os.listdir(cache_dir) if n.endswith(".obj")]
        if not installed:
            problems.append("the cache directory is empty after a build that reported a "
                            "miss -- the object was compiled and never installed")
        leftovers = [n for n in os.listdir(cache_dir) if n.startswith(".tmp-")]
        if leftovers:
            problems.append(f"the cache directory holds temporaries after a successful "
                            f"build: {leftovers[:3]} -- an install failed, or the temporary "
                            f"is not being cleaned up")

        # 2. The cached object is the one that gets linked.
        ran = run_command([str(out)])
        if ran.returncode != 0 or "PASS" not in (ran.stdout or ""):
            problems.append("the program built from the cached runtime object does not "
                            "run correctly, so the cache is serving the wrong file")

        # The documented bypass has to bypass.
        _, bypass_text = build({"PRISMIO_OBJ_CACHE": "0"})
        if "[objcache off] lang_runtime" not in bypass_text:
            problems.append("PRISMIO_OBJ_CACHE=0 did not report the cache as off")
        if "[objcache hit]" in bypass_text:
            problems.append("PRISMIO_OBJ_CACHE=0 still served an object from the cache")

        # 3. The flags are part of the key.
        verify_first, verify_text = build(extra_args=["--verify"])
        if verify_first.returncode != 0:
            problems.append("the --verify build failed with the object cache enabled")
        if "[objcache miss] lang_runtime" not in verify_text:
            problems.append("a --verify build hit the entry a release build filled -- "
                            "the flags are not in the key, so half the allocations in a "
                            "verify build would be outside the ledger")
        _, verify_again = build(extra_args=["--verify"])
        if "[objcache hit] lang_runtime" not in verify_again:
            problems.append("a second --verify build missed, so verify builds are not "
                            "cached at all rather than cached separately")

    cleanup_files(out)

    if problems:
        print(f"{RED}[FAIL] the toolchain object cache is not sound{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] the runtime object is cached: cold misses, warm hits, the "
          f"program still runs, --verify keys separately, and the bypass bypasses{RESET}")
    return True


@harness_test(suite="bootstrap", resources={"cpu": 2, "mem": 800, "objcache": EXCLUSIVE})
def run_bootstrap_cache_key_test():
    """The bootstrap script caches toolchain objects, and the key has to be content.

    `tools/bootstrap.py` compiles seven C sources on
    every generation -- 1.44 s of a 2.7 s self-build -- and now reuse them from
    `$TMPDIR/prismio-objcache`. This is the one build path whose contract is that
    an edit to `runtime/*.c` reaches the next generation, so a stale entry here
    poisons a compiler generation rather than a test binary.

    The script therefore exposes `--print-cache-key`, which
    computes the key and nothing else, so this can assert the four properties
    that matter in milliseconds instead of by bootstrapping:

      1. **Stable.** The same tree twice gives the same key, or nothing is ever
         reused and the cache is only overhead.
      2. **Sensitive to the source.** Editing the `.c` changes its key.
      3. **Sensitive to the headers.** Editing `prismio_runtime.h` changes the
         key of a `.c` that was not touched. This is the assertion with teeth: a
         header changes what a source compiles to without changing a byte of it,
         and keying on the `.c` alone serves an object built against the previous
         header — which is precisely what a session that regenerates
         `embedded_sources.h` does.
      4. **Distinct per source.** Two sources do not share an entry.

    The edits are made in a copied tree, passed with `--repo`, so the real
    `runtime/` is never touched. `PRISMIO_LLVM_DIR` is set to a fixed string so
    the key does not depend on how this host found LLVM — no compiling happens
    here, only hashing.
    """
    print(f"\n{BLUE}--- Running bootstrap_cache_key ---{RESET}")
    problems = []

    repo = TEST_DIR.parent
    script = [sys.executable, str(repo / "tools" / "bootstrap.py")]
    key_flag, repo_flag = "--print-cache-key", "--repo"

    with tempfile.TemporaryDirectory(prefix="prismio-cachekey-") as tree:
        shutil.copytree(repo / "runtime", Path(tree) / "runtime")

        def key(source):
            env = dict(os.environ)
            env["PRISMIO_LLVM_DIR"] = "/fixed/llvm"
            env.pop("PRISMIO_OBJ_CACHE", None)
            r = subprocess.run(script + [key_flag, source, repo_flag, tree],
                               capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
            if r.returncode != 0:
                problems.append(f"printing the cache key for {source} failed: "
                                f"{(r.stderr or r.stdout).strip()[:200]}")
                return None
            return (r.stdout or "").strip()

        source = Path(tree) / "runtime" / "lang_runtime.c"
        header = Path(tree) / "runtime" / "prismio_runtime.h"
        # Bytes, not text: on Windows `write_text` turns every LF into CRLF, so
        # "restoring" a file through it changed its content and its key.
        original_source = source.read_bytes()
        original_header = header.read_bytes()

        base = key("lang_runtime.c")
        if base and key("lang_runtime.c") != base:
            problems.append("the key is not stable across two runs on one tree, so nothing "
                            "would ever be reused and the cache is pure overhead")

        other = key("program_support.c")
        if base and other == base:
            problems.append("two different sources produce the same cache entry")

        source.write_bytes(original_source + b"\n// cache key check\n")
        edited = key("lang_runtime.c")
        if base and edited == base:
            problems.append("editing lang_runtime.c did not change its key -- the key is not "
                            "the content, and the next generation would link the old object")
        source.write_bytes(original_source)

        header.write_bytes(b"/* cache key check */\n" + original_header)
        after_header = key("lang_runtime.c")
        if base and after_header == base:
            problems.append("editing prismio_runtime.h did not change lang_runtime.c's key -- "
                            "a header changes what a source compiles to without changing a byte "
                            "of it, so this serves an object built against the old header")
        header.write_bytes(original_header)

        if base and key("lang_runtime.c") != base:
            problems.append("restoring the tree did not restore the key, so at least one of the "
                            "differences above was caused by something other than the edit")

    if problems:
        print(f"{RED}[FAIL] the bootstrap object cache key is not sound{RESET}")
        for p in problems:
            print(f"  {p}")
        return False

    print(f"{GREEN}[PASS] the bootstrap cache key is stable, per-source, and moves when "
          f"either the source or a header does{RESET}")
    return True
