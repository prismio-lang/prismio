"""A minimal Language Server Protocol client, for testing `prismio lsp` end to end.

It speaks the wire format and nothing else: `Content-Length` framing over a child's pipes,
JSON-RPC bodies, a reader thread that queues every message so a test can wait for the one it
cares about with a deadline, and a stderr drain so the server never blocks writing its log.
Deliberately independent of the server's own code (it is written in Python, not Prismio), so a
framing bug on the server's side is a failure here and not a bug both halves share.
"""
import json
import os
import queue
import subprocess
import threading
import time


class LspClient:
    def __init__(self, command, cwd=None, env=None):
        full_env = dict(os.environ)
        if env:
            full_env.update(env)
        self.process = subprocess.Popen(command, cwd=cwd, env=full_env, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.messages = queue.Queue()
        self.stderr_text = b""
        self.next_id = 1
        self.reader = threading.Thread(target=self._read_loop, daemon=True)
        self.reader.start()
        self.drain = threading.Thread(target=self._drain_stderr, daemon=True)
        self.drain.start()

    def _read_loop(self):
        stream = self.process.stdout
        while True:
            length = None
            while True:
                line = stream.readline()
                if not line:
                    self.messages.put(None)
                    return
                line = line.rstrip(b"\r\n")
                if line == b"":
                    break
                name, _, value = line.partition(b":")
                if name.strip().lower() == b"content-length":
                    length = int(value)
            if length is None:
                continue
            body = stream.read(length)
            if len(body) < length:
                self.messages.put(None)
                return
            self.messages.put(json.loads(body.decode("utf-8")))

    def _drain_stderr(self):
        for chunk in iter(lambda: self.process.stderr.read1(4096), b""):
            self.stderr_text += chunk

    def send_raw(self, body):
        data = body if isinstance(body, bytes) else body.encode("utf-8")
        self.process.stdin.write(b"Content-Length: %d\r\n\r\n" % len(data) + data)
        self.process.stdin.flush()

    def send(self, message):
        self.send_raw(json.dumps(message, separators=(",", ":"), ensure_ascii=False))

    def notify(self, method, params=None):
        self.send({"jsonrpc": "2.0", "method": method, "params": params if params is not None else {}})

    def request(self, method, params=None, timeout=20):
        identifier = self.next_id
        self.next_id += 1
        self.send({"jsonrpc": "2.0", "id": identifier, "method": method,
                   "params": params if params is not None else {}})
        return self.wait_for(lambda m: m.get("id") == identifier and "method" not in m, timeout)

    def wait_for(self, predicate, timeout=20):
        """The first queued message the predicate accepts; others are kept in order and dropped."""
        deadline = time.time() + timeout
        while True:
            remaining = deadline - time.time()
            if remaining <= 0:
                raise TimeoutError("no matching message within %ss" % timeout)
            try:
                message = self.messages.get(timeout=remaining)
            except queue.Empty:
                raise TimeoutError("no matching message within %ss" % timeout)
            if message is None:
                raise EOFError("the server closed its output")
            if predicate(message):
                return message

    def diagnostics_for(self, uri, timeout=20):
        message = self.wait_for(lambda m: m.get("method") == "textDocument/publishDiagnostics"
                                and m["params"]["uri"] == uri, timeout)
        return message["params"]

    def quiet_for(self, seconds):
        """True when nothing arrives for `seconds`."""
        try:
            message = self.messages.get(timeout=seconds)
        except queue.Empty:
            return True
        self.messages.put(message)
        return False

    def initialize(self, root=None, capabilities=None):
        reply = self.request("initialize", {"processId": os.getpid(), "rootUri": root,
                                            "capabilities": capabilities or {}})
        self.notify("initialized")
        return reply

    def shutdown(self, timeout=20):
        reply = self.request("shutdown", timeout=timeout)
        self.notify("exit")
        try:
            self.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            self.process.kill()
            raise
        return reply

    def close(self):
        try:
            self.process.stdin.close()
        except Exception:
            pass
        try:
            self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
