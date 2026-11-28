"""The benchmark suite's workloads as correctness checks: build them, run them, compare the
checksum each prints with the one benchmarks/results/results.json records -- which the C++ and
Rust arms reproduce -- so a miscompile that exits 0 is a failure too."""
import json
import re

from testkit.paths import REPO

# The realistic programs the gate builds and runs are the benchmark suite's own workloads: one
# binary, `suite <workload> <input> <output>`, printing `result: N`. The set spans what the old
# AIF corpus was for: a wide record (aos_vs_soa), per-frame transients
# (transient_allocation), a component world (ecs_component_update), retained trees, shared
# maps, tasks and a channel pipeline.
SUITE = "benchmarks/hosted/prismio/suite.psm"
GATE_WORKLOADS = (
    "ecs_component_update", "aos_vs_soa", "transient_allocation", "tree_traversal",
    "recursive_tree_rebuild", "hashmap_insert_lookup", "nested_collection",
    "parallel_reduction", "channel_pipeline", "word_frequency",
)


def recorded_results() -> dict:
    """workload -> the checksum benchmarks/results/results.json holds for it."""
    report = json.loads((REPO / "benchmarks" / "results" / "results.json")
                        .read_text(encoding="utf-8"))
    # Schema 4 holds one report per suite; the gate's workloads are the hosted ones.
    hosted = report.get("suites", {}).get("hosted", report)
    return {item["name"]: item.get("result") for item in hosted["benchmarks"]
            if item.get("status") == "implemented"}


def printed_result(output: str):
    found = re.search(r"result: (-?\d+)", output)
    return found.group(1) if found else None
