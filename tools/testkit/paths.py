"""Where the engine finds things in the checkout."""
import os
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
TOOLS = REPO / "tools"
TESTS = REPO / "tests"
# Redirected by the engine's own tests, so that they cannot touch the checkout's results.
CACHE_DIR = Path(os.environ.get("PRISMIO_TEST_CACHE_DIR") or REPO / ".prismio" / "test-cache")
EXE = ".exe" if os.name == "nt" else ""


def shown(path) -> str:
    try:
        return str(Path(path).resolve().relative_to(REPO))
    except ValueError:
        return str(path)
