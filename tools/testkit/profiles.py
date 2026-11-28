"""The profiles (the design record, section 8; see tools/testkit/__init__.py).

A profile says which tests, whether a recorded pass may be used, what is prepared first and
which checks run beside the tests. `full` and everything after it record results and never use
one: the gate's statement is "this candidate ran every test", and a cache cannot make it.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class Profile:
    name: str
    summary: str
    read_cache: bool = False
    only: tuple = ()              # empty: every test
    prepare: tuple = ()           # "lint", "package": in order, before anything else
    package_to: str = ""
    checks: tuple = ()
    pinned_llvm: bool = False     # the pinned LLVM first on PATH


# One per suite and per pipeline stage, plus the shapes that have caught the most: each has to
# stay fast, since this set also runs first in every other profile.
SMOKE = (
    "test_01_variables", "test_04_structs", "test_09_strings", "test_28_list",
    "test_73_recursive_release", "test_80_data_view_conversion", "test_92_field_view_provenance",
    "test_96_channels", "test_97_generic_annotation", "test_169_loop_range_proofs",
    "test_238_scalar_optionals", "test_302_struct_in_two_vecs", "test_399_move_at_last_use",
    "neg_01_type_mismatch", "neg_03_use_after_move", "neg_08_missing_return",
    "neg_13_syntax_recovery",
    "cli_run_forward_slash", "cli_check_protocol", "cli_usage", "source_not_utf8",
    "counted_fill_codegen", "proved_index_nsw", "string_dispatch_codegen",
    "aif_tiers", "aif_human_report", "global_store_escape",
    "pir_plan", "failure_builtins", "std_mem_failures", "token_tables", "check_overlay",
    "lsp_manifest", "ums_manifest", "kmalloc_heap", "engine_keys",
)

_VERIFY = ("source_lists", "externs", "aif_differential", "pir_differential", "corpus")
_GATE = _VERIFY + (
    "generations", "fixpoint", "candidate_reproduces", "seed", "gate_workloads", "verify_sweep",
    "curated_runtime_off", "object_cache_off", "jit_run", "cross_target", "packaged_toolchain",
)
_RELEASE = _GATE + ("sanitizer_smoke", "benchmark_smoke", "docs_examples",
                    "developer_docs_examples", "ci_matrix")

PROFILES = {p.name: p for p in (
    Profile("smoke", "a fast cross-section; for every edit", read_cache=True, only=SMOKE),
    Profile("dev", "every test, skipping what a cache key proves unchanged", read_cache=True),
    Profile("full", "every test, nothing skipped"),
    Profile("verify", "full on a packaged toolchain, plus lists, externs, differentials, corpus",
            prepare=("package",), package_to="dist/Prismio", checks=_VERIFY),
    Profile("gate", "the pre-push gate: lint, then verify and the self-hosting checks on a "
            "packaged candidate", prepare=("lint", "package"), package_to="build/gate-rc",
            checks=_GATE, pinned_llvm=True),
    Profile("release", "gate plus sanitizer, benchmark smoke and the documentation examples",
            prepare=("lint", "package"), package_to="build/gate-rc", checks=_RELEASE,
            pinned_llvm=True),
)}
