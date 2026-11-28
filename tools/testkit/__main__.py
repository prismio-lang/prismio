"""`python3 tools/testkit [profile] [patterns] [options]`."""
import sys
from pathlib import Path

if __package__ in (None, ""):
    # Run as a directory (`python3 tools/testkit`): the package's parent has to be importable.
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from testkit.cli import main  # noqa: E402

if __name__ == "__main__":
    # -X utf8: the compiler and every program under test write UTF-8, and on Windows Python
    # otherwise reads and writes with the ANSI code page.
    if sys.platform == "win32" and not sys.flags.utf8_mode:
        import subprocess
        sys.exit(subprocess.call([sys.executable, "-X", "utf8", *sys.argv]))
    sys.exit(main(sys.argv[1:]))
