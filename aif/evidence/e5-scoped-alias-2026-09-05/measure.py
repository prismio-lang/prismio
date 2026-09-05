#!/usr/bin/env python3
"""Measure frozen compilers on identical, unmodified cross-language sources."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import re
import shutil
import statistics
import subprocess

REPO = Path(__file__).resolve().parents[2]
HERE = REPO / 'aif/evidence/e5-scoped-alias-2026-09-05'


def run(command, env):
    return subprocess.run(list(map(str, command)), cwd=REPO, env=env,
                          capture_output=True, text=True, check=True, timeout=180)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--work', type=Path, default=REPO / 'build/e5-measure')
    ap.add_argument('--phase', choices=('build', 'measure', 'verify'), required=True)
    args = ap.parse_args()
    work = args.work.resolve()
    snap = work / 'snapshot'
    env = os.environ.copy()
    env['PATH'] = '/opt/homebrew/opt/llvm/bin:' + env.get('PATH', '')
    compilers = {'before': work / 'before', 'after': work / 'compiler'}
    executables = {arm: work / (arm + '-suite') for arm in compilers}
    executables.update(cpp=work / 'cpp-suite', rust=work / 'rust-suite')
    manifest = json.loads((REPO / 'benchmarks/benchmarks.json').read_text())
    names = [b['name'] for b in manifest['benchmarks'] if b['status'] == 'implemented']
    fixture = work / 'input.txt'
    fixture.write_bytes(b'alpha beta gamma delta 0123456789\n' * 8192)

    if args.phase == 'build':
        for arm, compiler in compilers.items():
            for verify in (False, True):
                command = [compiler, 'build', snap / 'benchmarks/prismio/suite.psm']
                if verify:
                    command += ['--verify']
                command += ['-o', work / (arm + ('-verify' if verify else '-suite'))]
                run(command, env)
        cpp = snap / 'benchmarks/cpp'
        run(['clang++', '-O3', '-std=c++20', '-pthread',
             *(cpp / n for n in ('suite.cpp', 'algorithms.cpp', 'data_structures.cpp',
                                'compute.cpp', 'memory.cpp', 'io.cpp')),
             '-o', executables['cpp']], env)
        run(['rustc', '-C', 'opt-level=3', '--edition=2021',
             snap / 'benchmarks/rust/suite.rs', '-o', executables['rust']], env)
        print('Built four timing arms and two verify arms from one snapshot.')
        return

    if args.phase == 'verify':
        report = {}
        for name in names:
            report[name] = {}
            for arm in compilers:
                result = run([work / (arm + '-verify'), name, fixture,
                              work / (arm + '.out')], env)
                text = result.stdout + result.stderr
                match = re.search(r'aif-verify: (\d+) allocated, (\d+) released, '
                                  r'(\d+) leaked, (\d+) violation', text)
                if not match:
                    raise ValueError(f'Missing verify report: {arm} {name}')
                report[name][arm] = dict(zip(('allocated', 'released', 'leaked', 'violations'),
                                             map(int, match.groups())))
                report[name][arm]['output'] = text
        (HERE / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
        print('Verified', len(report), 'benchmarks:',
              {a: sum(b[a]['violations'] for b in report.values()) for a in compilers})
        return

    # Timing starts only after all compilation and other validation have ended.
    executables['before_repeat'] = executables['before']
    report = {'compiler_sha256': {a: digest(c) for a, c in compilers.items()},
              'binary_sha256': {a: digest(c) for a, c in executables.items()},
              'source_sha256': {str(p.relative_to(snap)): digest(p)
                                for p in sorted(snap.rglob('*')) if p.is_file()},
              'toolchains': {t: run([t, '--version'], env).stdout.splitlines()[0]
                             for t in ('clang++', 'rustc')},
              'benchmarks': {}}
    rng = random.Random(319127)
    for name in names:
        target = name in ('large_buffer_copy', 'struct_creation', 'transient_allocation',
                          'vector_growth', 'nested_collection', 'knapsack')
        warmup, count = (20, 31) if target else (4, 9)
        samples = {arm: [] for arm in executables}
        checksums = set()
        for iteration in range(warmup + count):
            order = list(executables)
            rng.shuffle(order)
            for arm in order:
                result = run([executables[arm], name, fixture, work / (arm + '.out')], env)
                fields = dict(line.split(': ', 1) for line in result.stdout.splitlines()
                              if line.startswith(('result: ', 'elapsed_ns: ')))
                checksums.add(int(fields['result']))
                elapsed = int(fields['elapsed_ns'])
                if elapsed < 0:
                    raise ValueError('elapsed_ns overflow')
                if iteration >= warmup:
                    samples[arm].append(elapsed)
        if len(checksums) != 1:
            raise ValueError(f'{name}: checksum mismatch {checksums}')
        result = {'checksum': checksums.pop(), 'warmup': warmup, 'runs': count,
                  'samples_ns': samples,
                  'median_ns': {a: statistics.median(v) for a, v in samples.items()},
                  'min_ns': {a: min(v) for a, v in samples.items()}}
        report['benchmarks'][name] = result
        print(name, result['median_ns'], flush=True)
        (HERE / 'measurements.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
