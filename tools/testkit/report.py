"""What a run says while it runs and when it ends: lines, a live meter, JSON and JUnit."""
import json
import os
import re
import shutil
import sys
import threading
import time
from xml.sax.saxutils import escape, quoteattr

from testkit.model import CACHED, FAIL, PASS, SKIP

GREEN, RED, YELLOW, DIM, RESET = "\033[92m", "\033[91m", "\033[93m", "\033[2m", "\033[0m"
ANSI = re.compile(r"\x1b\[[0-9;]*m")


class Progress:
    """A line per finished test and, on a terminal, a meter of what is still running."""

    def __init__(self, total, interactive=None, stream=None):
        self.total = max(total, 1)
        self.done = 0
        self.stream = stream or sys.stdout
        if interactive is None:
            setting = os.environ.get("PRISMIO_TEST_INTERACTIVE")
            interactive = setting == "1" if setting in ("0", "1") \
                else getattr(self.stream, "isatty", lambda: False)()
        self.interactive = interactive
        self.lock = threading.RLock()
        self.active = {}
        self.start = time.time()
        self.stopped = threading.Event()
        self.thread = None
        if self.interactive:
            self.thread = threading.Thread(target=self._tick, daemon=True)
            self.thread.start()

    def _tick(self):
        while not self.stopped.wait(0.2):
            self._draw()

    def _draw(self):
        with self.lock:
            if not self.interactive or self.stopped.is_set():
                return
            filled = min(18, 18 * self.done // self.total)
            running = sorted(self.active.items(), key=lambda item: item[1])
            now = time.time()
            shown = ", ".join(f"{name} ({now - since:.0f}s)" for name, since in running[:2])
            if len(running) > 2:
                shown += f" +{len(running) - 2} more"
            line = (f"  [{'#' * filled}{'.' * (18 - filled)}] {self.done}/{self.total} "
                    f"[{now - self.start:.0f}s] {shown}")
            width = shutil.get_terminal_size((80, 24)).columns
            if len(line) > width - 1:
                line = line[:max(10, width - 4)] + "..."
            self.stream.write("\r\033[K" + line)
            self.stream.flush()

    def started(self, test):
        with self.lock:
            self.active[test.id] = time.time()

    def finished(self, result):
        with self.lock:
            self.done += 1
            self.active.pop(result.test.id, None)
            if self.interactive:
                self.stream.write("\r\033[K")
            mark = {PASS: f"{GREEN}ok  {RESET}", FAIL: f"{RED}FAIL{RESET}",
                    CACHED: f"{DIM}ok  {RESET}", SKIP: f"{YELLOW}skip{RESET}"}[result.outcome]
            note = ""
            if result.outcome == CACHED:
                note = f"  {DIM}(cached, {result.detail}){RESET}"
            elif result.test.kind == "check" and result.detail:
                note = f"  {DIM}{result.detail}{RESET}"
            elif result.outcome == SKIP:
                note = f"  {DIM}{result.detail}{RESET}"
            percent = 100 * self.done // self.total
            self.stream.write(f"  [{self.done:4d}/{self.total}] ({percent:3d}%) {mark} "
                              f"{result.seconds:6.2f}s  {result.test.id}{note}\n")
            if result.outcome == FAIL:
                self.stream.write(result.output)
            self.stream.flush()

    def stop(self):
        self.stopped.set()
        if self.thread:
            self.thread.join(timeout=1)
            self.stream.write("\r\033[K")


def summary(results, wall, *, profile, compiler, filtered, not_run, cache) -> dict:
    by = {outcome: [r for r in results if r.outcome == outcome]
          for outcome in (PASS, FAIL, CACHED, SKIP)}
    levels = {}
    for result in by[CACHED]:
        levels[result.level] = levels.get(result.level, 0) + 1
    return {
        "profile": profile, "compiler": compiler, "wall_seconds": round(wall, 2),
        "filtered": filtered, "cache": cache,
        "total": len(results), "passed": len(by[PASS]) + len(by[CACHED]),
        "executed": len(by[PASS]) + len(by[FAIL]), "cached": len(by[CACHED]),
        "cached_by_level": levels, "failed": len(by[FAIL]), "skipped": len(by[SKIP]),
        "not_run": len(not_run),
        "changed_output": [r.test.id for r in results if r.changed_output],
        "flaky": [r.test.id for r in results if r.flaky],
        "slowest": [[r.test.id, round(r.seconds, 2)] for r in sorted(
            (r for r in results if r.outcome in (PASS, FAIL)), key=lambda r: -r.seconds)[:10]],
        "failures": [r.test.id for r in by[FAIL]],
        "tests": [{"id": r.test.id, "kind": r.test.kind, "suite": r.test.suite,
                   "outcome": r.outcome, "level": r.level, "seconds": round(r.seconds, 3),
                   "detail": r.detail} for r in results],
    }


def print_summary(data, results):
    line = "=" * 60
    changed = [r for r in results if r.changed_output]
    if changed:
        print(f"\n{YELLOW}changed output{RESET} (passed, but prints something new):")
        for result in changed:
            print(f"  {result.test.id}")
            for text in result.changed_output.splitlines():
                print(f"      {text}")
    if data["flaky"]:
        print(f"\n{YELLOW}flaky{RESET} (failed before on these same inputs, passed now; "
              "nothing was retried):")
        for name in data["flaky"]:
            print(f"  {name}")
    if data["slowest"] and data["executed"] > 10:
        print("\nslowest:")
        for name, seconds in data["slowest"]:
            print(f"  {seconds:8.2f}s  {name}")
    print(f"\n{line}")
    levels = ", ".join(f"{level} {count}" for level, count in sorted(data["cached_by_level"].items()))
    print(f"{GREEN}Passed: {data['passed']}{RESET}"
          + (f"  ({data['cached']} cached: {levels})" if data["cached"] else ""))
    print(f"{RED}Failed: {data['failed']}{RESET}")
    if data["skipped"]:
        print(f"Skipped: {data['skipped']}")
    if data["not_run"]:
        print(f"Not run: {data['not_run']} (the smoke wave failed; --keep-going runs them)")
    print(f"Total:  {data['total']}   executed {data['executed']}, "
          f"{data['wall_seconds']:.1f}s, cache {data['cache']}")
    for name in data["failures"][:40]:
        print(f"  {RED}failed:{RESET} {name}")
    print(line)


def write_json(data, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=1), encoding="utf-8")


def _clean(text: str) -> str:
    # XML 1.0 has no way to spell most control characters.
    return "".join(c for c in ANSI.sub("", text) if c in "\t\n" or ord(c) >= 32)


def write_junit(results, path, wall):
    suites = {}
    for result in results:
        suites.setdefault(result.test.suite, []).append(result)
    parts = ['<?xml version="1.0" encoding="UTF-8"?>',
             f'<testsuites tests="{len(results)}" time="{wall:.3f}" failures='
             f'"{sum(r.outcome == FAIL for r in results)}">']
    for name, members in sorted(suites.items()):
        parts.append(f'<testsuite name={quoteattr(name)} tests="{len(members)}" '
                     f'failures="{sum(r.outcome == FAIL for r in members)}" '
                     f'skipped="{sum(r.outcome == SKIP for r in members)}" '
                     f'time="{sum(r.seconds for r in members):.3f}">')
        for result in members:
            head = (f'<testcase classname={quoteattr(name)} name={quoteattr(result.test.id)} '
                    f'time="{result.seconds:.3f}"')
            if result.outcome == FAIL:
                parts.append(f"{head}><failure message=\"failed\">"
                             f"{escape(_clean(result.output))}</failure></testcase>")
            elif result.outcome == SKIP:
                parts.append(f"{head}><skipped message={quoteattr(_clean(result.detail))}/>"
                             "</testcase>")
            elif result.outcome == CACHED:
                parts.append(f"{head}><system-out>{escape('cached: ' + result.detail)}"
                             "</system-out></testcase>")
            else:
                parts.append(f"{head}/>")
        parts.append("</testsuite>")
    parts.append("</testsuites>")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(parts) + "\n", encoding="utf-8")
