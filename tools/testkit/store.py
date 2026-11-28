"""The results store, `.prismio/test-cache/results.sqlite`: local and untracked.

Two tables. `cache` holds passes only, keyed (test, level, key). `history` holds the outcome
and duration of every executed test, which the scheduler orders by, failures are re-run from,
and flakiness and changed output are judged against -- those work with the cache off too.
"""
import json
import sqlite3
import threading
import time

from testkit.paths import CACHE_DIR

# Rows kept per test: enough to move between a few branches and still hit.
KEEP_KEYS = 6
KEEP_HISTORY = 20
KEEP_TEXT = 64 * 1024

SCHEMA = """
CREATE TABLE IF NOT EXISTS cache (
    test TEXT, level TEXT, key TEXT, outcome TEXT, seconds REAL, stdout_hash TEXT,
    stderr_hash TEXT, deps TEXT, compiler TEXT, recorded REAL, run TEXT,
    PRIMARY KEY (test, level, key));
CREATE TABLE IF NOT EXISTS history (
    test TEXT, run TEXT, outcome TEXT, seconds REAL, inputs TEXT, artifact TEXT,
    stdout_hash TEXT, stdout TEXT, recorded REAL);
CREATE INDEX IF NOT EXISTS history_test ON history (test, recorded);
"""


class Store:
    def __init__(self, path=None):
        path = path or CACHE_DIR / "results.sqlite"
        path.parent.mkdir(parents=True, exist_ok=True)
        self.path = path
        self.lock = threading.Lock()
        self.db = sqlite3.connect(str(path), check_same_thread=False, timeout=60)
        self.db.executescript(SCHEMA)
        self.db.commit()

    def close(self):
        self.db.close()

    def clear(self):
        """`--cache-clear`: forget every recorded pass. Durations and history stay."""
        with self.lock:
            self.db.execute("DELETE FROM cache")
            self.db.commit()

    # ----- passes ---------------------------------------------------------------------

    def rows(self, test: str, level: str) -> list:
        with self.lock:
            cursor = self.db.execute(
                "SELECT key, stdout_hash, deps, compiler, recorded, run FROM cache "
                "WHERE test = ? AND level = ? ORDER BY recorded DESC", (test, level))
            return [{"key": k, "stdout_hash": s, "deps": json.loads(d or "[]"), "compiler": c,
                     "recorded": t, "run": r} for k, s, d, c, t, r in cursor.fetchall()]

    def hit(self, test: str, level: str, key: str):
        return next((row for row in self.rows(test, level) if row["key"] == key), None)

    def record_pass(self, test: str, level: str, key: str, *, seconds, stdout_hash,
                    stderr_hash, deps, compiler, run):
        with self.lock:
            self.db.execute(
                "INSERT OR REPLACE INTO cache VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                (test, level, key, "pass", seconds, stdout_hash, stderr_hash,
                 json.dumps(list(deps)), compiler, time.time(), run))
            self.db.execute(
                "DELETE FROM cache WHERE test = ? AND level = ? AND key NOT IN (SELECT key "
                "FROM cache WHERE test = ? AND level = ? ORDER BY recorded DESC LIMIT ?)",
                (test, level, test, level, KEEP_KEYS))

    def forget(self, test: str):
        """A failure invalidates every recorded pass of the test: it always reruns."""
        with self.lock:
            self.db.execute("DELETE FROM cache WHERE test = ?", (test,))
            self.db.commit()

    # ----- history --------------------------------------------------------------------

    def record_history(self, test: str, run: str, outcome: str, seconds: float, inputs: str,
                       artifact: str, stdout_hash: str, stdout: str):
        with self.lock:
            self.db.execute("INSERT INTO history VALUES (?,?,?,?,?,?,?,?,?)",
                            (test, run, outcome, seconds, inputs, artifact, stdout_hash,
                             stdout[:KEEP_TEXT], time.time()))
            self.db.execute(
                "DELETE FROM history WHERE test = ? AND rowid NOT IN (SELECT rowid FROM "
                "history WHERE test = ? ORDER BY recorded DESC LIMIT ?)",
                (test, test, KEEP_HISTORY))

    def durations(self) -> dict:
        """test -> the seconds its last executed run took."""
        with self.lock:
            cursor = self.db.execute(
                "SELECT test, seconds FROM history WHERE outcome != 'cached' ORDER BY recorded")
            return {test: seconds for test, seconds in cursor.fetchall()}

    def failed_last_time(self) -> set:
        with self.lock:
            cursor = self.db.execute("SELECT test, outcome FROM history ORDER BY recorded")
            return {test for test, outcome in dict(cursor.fetchall()).items() if outcome == "fail"}

    def last_pass(self, test: str):
        with self.lock:
            row = self.db.execute(
                "SELECT artifact, stdout_hash, stdout FROM history WHERE test = ? AND "
                "outcome = 'pass' ORDER BY recorded DESC LIMIT 1", (test,)).fetchone()
        return None if row is None else {"artifact": row[0], "stdout_hash": row[1], "stdout": row[2]}

    def failed_with_inputs(self, test: str, inputs: str) -> bool:
        """Whether this test failed before on exactly these inputs: a pass now is flaky."""
        if not inputs:
            return False
        with self.lock:
            row = self.db.execute(
                "SELECT 1 FROM history WHERE test = ? AND inputs = ? AND outcome = 'fail' "
                "LIMIT 1", (test, inputs)).fetchone()
        return row is not None

    def commit(self):
        with self.lock:
            self.db.commit()
