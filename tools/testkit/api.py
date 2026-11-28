"""What a harness module declares a test with."""
import fnmatch

__all__ = ["EXCLUSIVE", "harness_test", "REGISTRY"]


class _Exclusive:
    def __repr__(self):
        return "EXCLUSIVE"


# A resource no two running tests may hold at once: `{"objcache": EXCLUSIVE}`.
EXCLUSIVE = _Exclusive()

REGISTRY = {}


def harness_test(name=None, *, suite, resources=None, reads=None, timeout=600, tags=(),
                 cache=None):
    """Register a programmatic test.

    `resources` takes "cpu" tokens, a "mem" budget in MB and exclusive locks. `reads` lists the
    repository files the result depends on beyond the compiler (globs, relative to the checkout);
    it is what goes into the test's cache key, and `--audit` checks it. A test without `reads` is
    never cached (`reads=[]` declares that there are none), and neither is one marked
    `cache=False` -- a result that depends on timing,
    threads or the machine is not a function of any key.
    """
    def register(function):
        test_name = name or function.__name__.removeprefix("run_").removesuffix("_test")
        if test_name in REGISTRY:
            raise ValueError(f"two harness tests are named {test_name!r}")
        REGISTRY[test_name] = {
            "function": function, "suite": suite, "resources": dict(resources or {}),
            "reads": tuple(reads or ()), "timeout": timeout, "tags": tuple(tags),
            "cache": reads is not None if cache is None else cache,
        }
        return function
    return register


def matches(path, patterns) -> bool:
    """Whether a repository-relative path is covered by any declared glob (`**` crosses `/`).

    A path or pattern ending in `/` is a directory's *listing*: `tests/` covers asking which
    modules are in `tests`, and no file in it; `src/**` covers both.
    """
    for pattern in patterns:
        if not pattern.endswith("/") and not (path.endswith("/") and not pattern.endswith("**")) \
                and fnmatch.fnmatchcase(path, pattern):
            return True
        if pattern.endswith("/**") and (path == pattern[:-3] or path.startswith(pattern[:-2])):
            return True
        if pattern.endswith("/") and path.endswith("/"):
            if fnmatch.fnmatchcase(path, pattern):
                return True
    return False
