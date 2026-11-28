"""One record for every check the engine can run (docs/TEST_ORCHESTRATION_PLAN.md, section 4)."""
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional

from testkit.api import EXCLUSIVE

# Wave order inside a profile (section 6).
SMOKE_WAVE, BULK_WAVE, QUIET_WAVE = 0, 1, 2

PASS, FAIL, CACHED, SKIP = "pass", "fail", "cached", "skip"


@dataclass
class Test:
    id: str
    kind: str                      # "run", "reject", "harness" or "check"
    suite: str
    tags: set = field(default_factory=set)
    path: Optional[Path] = None    # a fixture's source
    resources: dict = field(default_factory=dict)
    cache: bool = True             # False: always run (`cache=never`)
    reads: tuple = ()              # harness: repository globs that go into K1
    timeout: int = 60
    order: int = 0
    # A check's body, and the checks that must pass before it can run.
    run: Optional[Callable] = None
    after: tuple = ()

    @property
    def locks(self) -> list:
        return [name for name, value in self.resources.items() if value is EXCLUSIVE]

    @property
    def cpu(self):
        return self.resources.get("cpu", 1)

    @property
    def mem(self) -> int:
        return self.resources.get("mem", 300)


@dataclass
class Result:
    test: Test
    outcome: str                   # PASS, FAIL, CACHED or SKIP
    seconds: float = 0.0
    output: str = ""               # shown when it failed
    detail: str = ""               # one line: a check's finding, a cache hit's origin
    level: str = ""                # the cache level that matched: "K1", "K2", "K3"
    stdout_hash: str = ""
    stdout: str = ""
    stderr_hash: str = ""
    keys: dict = field(default_factory=dict)
    deps: tuple = ()               # a fixture's recorded closure
    changed_output: str = ""       # a diff, when the program prints something new
    flaky: bool = False

    @property
    def ok(self) -> bool:
        return self.outcome != FAIL
