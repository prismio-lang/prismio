"""The process a harness test runs in: `child.py <suite> <test> [--audit=<file>]`.

Exits 0 when the test's function returned true.
"""
import importlib
import signal
import sys
import traceback
from pathlib import Path

TOOLS = Path(__file__).resolve().parent.parent
sys.path[:0] = [str(TOOLS), str(TOOLS.parent / "tests")]


def _stop(number, frame):
    # A test asked to stop unwinds, so that whatever it moved aside is put back.
    raise KeyboardInterrupt(f"stopped by signal {number}")


def main(argv) -> int:
    suite, name = argv[0], argv[1]
    audit = next((a.split("=", 1)[1] for a in argv[2:] if a.startswith("--audit=")), None)
    signal.signal(signal.SIGTERM, _stop)
    recorder = None
    if audit:
        from testkit.audit import Recorder
        recorder = Recorder()
        recorder.install()
    importlib.import_module(f"harness.{suite}")
    from testkit.api import REGISTRY
    try:
        ok = REGISTRY[name]["function"]()
    except Exception as error:
        ok = False
        print(f"[FAIL] {name}: uncaught exception: {error}", flush=True)
        # The message alone names no file and no line.
        traceback.print_exc(file=sys.stdout)
    if recorder:
        recorder.write(audit)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
