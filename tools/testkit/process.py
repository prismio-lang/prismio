"""Running a command with a deadline that takes its whole process group with it."""
import os
import signal
import subprocess
import threading

# Process groups still running, so that an interrupted run can stop them.
RUNNING = set()
RUNNING_LOCK = threading.Lock()


class Finished:
    def __init__(self, returncode, stdout, stderr, timed_out=False):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr
        self.timed_out = timed_out

    @property
    def text(self) -> str:
        return (self.stdout or "") + (self.stderr or "")


def _signal(process, number):
    try:
        if os.name == "nt":
            process.kill()
        else:
            os.killpg(process.pid, number)
    except (ProcessLookupError, PermissionError, OSError):
        pass


def terminate_all():
    with RUNNING_LOCK:
        running = list(RUNNING)
    for process in running:
        _signal(process, signal.SIGTERM)


def run(command, *, timeout, cwd=None, env=None, grace=20) -> Finished:
    """`command` in a process group of its own; at the deadline it is asked to stop, so that a
    test holding a resource can put it back, and then killed."""
    try:
        process = subprocess.Popen(
            [str(c) for c in command], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            stdin=subprocess.DEVNULL, text=True, encoding="utf-8", errors="replace", cwd=cwd,
            env=env, start_new_session=os.name != "nt")
    except OSError as error:
        return Finished(127, "", f"could not start {command[0]}: {error}")
    with RUNNING_LOCK:
        RUNNING.add(process)
    try:
        try:
            stdout, stderr = process.communicate(timeout=timeout)
            return Finished(process.returncode, stdout, stderr)
        except subprocess.TimeoutExpired:
            _signal(process, signal.SIGTERM)
            try:
                stdout, stderr = process.communicate(timeout=grace)
            except subprocess.TimeoutExpired:
                _signal(process, getattr(signal, "SIGKILL", signal.SIGTERM))
                stdout, stderr = process.communicate()
            return Finished(process.returncode, stdout, stderr, timed_out=True)
    finally:
        # Nothing the test started outlives it.
        if os.name != "nt":
            _signal(process, signal.SIGKILL)
        with RUNNING_LOCK:
            RUNNING.discard(process)
