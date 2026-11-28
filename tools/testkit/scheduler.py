"""One resource-aware pool for everything (docs/TEST_ORCHESTRATION_PLAN.md, section 6).

A test starts when its cpu tokens and memory fit and nothing holds a lock it wants. The queue
is ordered and the first test that fits starts, except that nothing overtakes a test waiting
for the whole machine (`cpu="all"`).
"""
import os
import threading

from testkit import process
from testkit.model import FAIL, QUIET_WAVE, SKIP, SMOKE_WAVE, Result


def total_cpus() -> int:
    return os.cpu_count() or 4


def total_memory() -> int:
    """MB the pool may promise out: three quarters of the machine."""
    try:
        return os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES") // (1 << 20) * 3 // 4
    except (AttributeError, ValueError, OSError):
        return 8000


def requested_jobs():
    """PRISMIO_TEST_JOBS: how many tests may run at once. 1 means one at a time, for when a
    failure looks like it might be interference rather than a bug."""
    try:
        return max(1, int(os.environ["PRISMIO_TEST_JOBS"]))
    except (KeyError, ValueError):
        return None


class Pool:
    def __init__(self, execute, finished, started, cpus=None, memory=None, jobs=None):
        self.execute = execute          # (test, granted cpus) -> Result
        self.finished = finished        # (Result) -> None, called on the scheduling thread
        self.started = started          # (test) -> None
        self.cpus = cpus or total_cpus()
        self.memory = memory or total_memory()
        self.jobs = jobs or requested_jobs() or self.cpus
        self.condition = threading.Condition()
        self.done = []
        self.outcomes = {}

    def _cost(self, test):
        cpu = self.cpus if test.cpu == "all" else min(test.cpu, self.cpus)
        return cpu, min(test.mem, self.memory)

    def _worker(self, test, cpu):
        try:
            result = self.execute(test, cpu)
        except Exception as error:      # a crashed worker is a failure
            import traceback
            result = Result(test, FAIL, output=f"    {error}\n{traceback.format_exc()}")
        with self.condition:
            self.done.append((test, result))
            self.condition.notify_all()

    def run(self, waves: list, fail_fast: bool) -> list:
        """`waves`: [(wave, [tests in priority order])]. Returns the tests never run."""
        not_run = []
        stopped = False
        for wave, tests in waves:
            if stopped:
                not_run += tests
                continue
            failed = self._wave(list(tests), 1 if wave == QUIET_WAVE else self.jobs)
            if failed and wave == SMOKE_WAVE and fail_fast:
                stopped = True
        return not_run

    def _wave(self, queue, jobs) -> bool:
        running = {}
        used_cpu = used_memory = 0
        locked = set()
        failed = False
        waiting_on = {t.id for t in queue}
        try:
            while queue or running:
                for test in list(queue):
                    blockers = [a for a in test.after if a in self.outcomes
                                and self.outcomes[a] in (FAIL, SKIP)]
                    if blockers:
                        queue.remove(test)
                        result = Result(test, SKIP, detail=f"blocked by {blockers[0]}")
                        self.outcomes[test.id] = SKIP
                        self.finished(result)
                        continue
                    if any(a in waiting_on and a not in self.outcomes for a in test.after):
                        continue
                    if len(running) >= jobs:
                        break
                    cpu, memory = self._cost(test)
                    if locked & set(test.locks):
                        continue
                    if running and (used_cpu + cpu > self.cpus
                                    or used_memory + memory > self.memory):
                        # Smaller tests fill the gap. One that wants the whole machine
                        # would then never start, so nothing overtakes it.
                        if test.cpu == "all":
                            break
                        continue
                    queue.remove(test)
                    used_cpu += cpu
                    used_memory += memory
                    locked |= set(test.locks)
                    thread = threading.Thread(target=self._worker, args=(test, cpu), daemon=True)
                    running[test.id] = (thread, cpu, memory)
                    self.started(test)
                    thread.start()
                if not running:
                    if queue:           # a dependency that is not part of this run
                        for test in queue:
                            self.outcomes[test.id] = SKIP
                            self.finished(Result(test, SKIP, detail="its prerequisite did not run"))
                        queue.clear()
                    continue
                with self.condition:
                    while not self.done:
                        self.condition.wait(0.5)
                    finished, self.done = self.done, []
                for test, result in finished:
                    thread, cpu, memory = running.pop(test.id)
                    thread.join()
                    used_cpu -= cpu
                    used_memory -= memory
                    locked -= set(test.locks)
                    self.outcomes[test.id] = result.outcome
                    failed |= result.outcome == FAIL
                    self.finished(result)
        except KeyboardInterrupt:
            process.terminate_all()
            for thread, _, _ in running.values():
                thread.join(timeout=60)
            raise
        return failed
