#!/usr/bin/env python3
"""Rotated, interleaved comparison of preserved and candidate dispatchers.

Run from the repository root after benchmarks/run.py builds the candidate.
Accepts --all to cover every implemented workload; otherwise the four targets.
"""
import argparse
import hashlib
import json
import platform
import statistics
import subprocess
import tempfile
from pathlib import Path
import importlib.util

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('bench_runner', ROOT / 'benchmarks/run.py')
bench = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bench)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--all', action='store_true')
    parser.add_argument('--runs', type=int, default=25)
    parser.add_argument('--output', type=Path, default=Path(__file__).with_name('paired.json'))
    args = parser.parse_args()
    arms = {
        'before': ROOT / 'build/critical-baseline-suite',
        'source_before': ROOT / 'build/critical-source-base-suite',
        'after': ROOT / 'benchmarks/build/prismio-suite',
        'cpp': ROOT / 'benchmarks/build/cpp-suite',
        'rust': ROOT / 'benchmarks/build/rust-suite',
    }
    wanted = {'transient_allocation', 'allocation_mutation', 'graph_bfs', 'gcd_lcm'}
    manifest = json.loads((ROOT / 'benchmarks/benchmarks.json').read_text())
    names = [b['name'] for b in manifest['benchmarks']
             if b['status'] == 'implemented' and (args.all or b['name'] in wanted)]
    report = {'platform': platform.platform(), 'runs': args.runs, 'warmups': 3,
              'binaries': {k: {'path': str(p.relative_to(ROOT)),
                               'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                           for k, p in arms.items()}, 'benchmarks': {}}
    with tempfile.TemporaryDirectory(prefix='prismio-paired-') as tmp:
        fixture = bench.make_fixture(Path(tmp))
        output = Path(tmp) / 'output.txt'
        labels = list(arms)
        for name in names:
            samples = {label: [] for label in labels}
            expected = None
            for turn in range(-3, args.runs):
                rotation = turn % len(labels)
                order = labels[rotation:] + labels[:rotation]
                if turn % 2:
                    order.reverse()
                for label in order:
                    result = bench.execute(arms[label], name, fixture, output)
                    if expected is None:
                        expected = result['result']
                    assert expected == result['result'], (name, label, expected, result)
                    if turn >= 0:
                        samples[label].append(result['elapsed_ns'])
            medians = {k: statistics.median(v) for k, v in samples.items()}
            paired = statistics.median(a / b for a, b in zip(samples['after'], samples['before']))
            report['benchmarks'][name] = {'result': expected, 'median_ns': medians,
                                         'after_before_paired_median': paired,
                                         'samples_ns': samples}
            print(name, {k: round(v / 1e6, 4) for k, v in medians.items()}, flush=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
