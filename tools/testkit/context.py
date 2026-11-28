"""What every running test shares."""
import os
import shutil
import tempfile
import threading
from pathlib import Path

from testkit.paths import REPO

# Content-addressed, and written to be shared by concurrent builds: every test keeps using the
# machine's caches, each from its own TMPDIR, unless it holds the `objcache` lock -- those
# tests assert what a build recompiles and get empty caches of their own.
SHARED_CACHES = ("prismio-objcache", "prismio-link-cache")


class Context:
    def __init__(self, *, options, copy, candidate, fingerprint, store, read_cache, run_id,
                 audit=None):
        self.root = REPO
        self.options = options
        self.compiler = copy.compiler
        self.candidate = Path(candidate)
        self.fingerprint = fingerprint
        self.store = store
        self.read_cache = read_cache
        self.run_id = run_id
        self.audit = audit
        self.state = {}
        self.granted = {}
        self.base_environment = dict(os.environ)
        self.work = Path(tempfile.mkdtemp(prefix="prismio-run-"))
        self.system_temp = Path(tempfile.gettempdir())
        self.lock = threading.Lock()
        for name in SHARED_CACHES:
            (self.system_temp / name).mkdir(exist_ok=True)

    def directory(self, test) -> Path:
        """This test's own directory; `tmp/` inside it is its TMPDIR."""
        path = self.work / test.id
        with self.lock:
            if not (path / "tmp").is_dir():
                (path / "tmp").mkdir(parents=True)
                if "objcache" not in test.resources:
                    for name in SHARED_CACHES:
                        try:
                            os.symlink(self.system_temp / name, path / "tmp" / name,
                                       target_is_directory=True)
                        except OSError:
                            pass        # Windows without the privilege: a cold cache
        return path

    def environment(self, test) -> dict:
        env = dict(self.base_environment)
        temporary = str(self.directory(test) / "tmp")
        env.update(TMPDIR=temporary, TEMP=temporary, TMP=temporary)
        return env

    def granted_cpus(self, test) -> int:
        return self.granted.get(test.id, 1)

    def close(self):
        shutil.rmtree(self.work, ignore_errors=True)
