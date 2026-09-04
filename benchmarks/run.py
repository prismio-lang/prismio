#!/usr/bin/env python3
"""Build, validate, and measure the Prismio/C++/Rust benchmark matrix."""

import argparse
from datetime import datetime, timezone
from html import escape
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import tempfile
import time
import webbrowser

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
MANIFEST = HERE / "benchmarks.json"
BUILD = HERE / "build"
RESULTS = HERE / "results"
LANGUAGES = ("prismio", "cpp", "rust")
LANGUAGE_LABELS = {"prismio": "Prismio", "cpp": "C++", "rust": "Rust"}
CPP_SOURCES = tuple(HERE / "cpp" / name for name in (
    "suite.cpp",
    "algorithms.cpp",
    "data_structures.cpp",
    "compute.cpp",
    "memory.cpp",
    "io.cpp",
))


class Progress:
    def __init__(self, total):
        self.total = max(total, 1)
        self.current = 0
        self.interactive = sys.stdout.isatty()
        self.width = 0

    def show(self, label):
        if not self.interactive:
            return
        columns = 24
        filled = min(columns, int(columns * self.current / self.total))
        bar = "█" * filled + "░" * (columns - filled)
        line = "  [{}] {:3d}%  {}".format(bar, int(100 * self.current / self.total), label)
        self.width = max(self.width, len(line))
        sys.stdout.write("\r" + line.ljust(self.width))
        sys.stdout.flush()

    def advance(self, label):
        self.current += 1
        self.show(label)

    def finish(self):
        if self.interactive:
            sys.stdout.write("\r" + (" " * self.width) + "\r")
            sys.stdout.flush()


def command_text(command):
    return " ".join(str(part) for part in command)


def run_command(command, *, env=None):
    return subprocess.run(command, cwd=REPO, env=env, capture_output=True, text=True)


def llvm_bin_from(args):
    if args.llvm_bin:
        return Path(args.llvm_bin).resolve()
    homebrew = Path("/opt/homebrew/opt/llvm/bin")
    return homebrew if homebrew.is_dir() else None


def build_all(args, progress):
    BUILD.mkdir(parents=True, exist_ok=True)
    llvm_bin = llvm_bin_from(args)
    env = os.environ.copy()
    if llvm_bin:
        env["PATH"] = str(llvm_bin) + os.pathsep + env.get("PATH", "")
    cxx = str(llvm_bin / "clang++") if llvm_bin and (llvm_bin / "clang++").exists() else "clang++"
    commands = {
        "prismio": [str(Path(args.compiler).resolve()), "build", str(HERE / "prismio/suite.psm"), "-o", str(BUILD / "prismio-suite")],
        "cpp": [cxx, "-O3", "-std=c++20", "-pthread", *(str(path) for path in CPP_SOURCES),
                "-o", str(BUILD / "cpp-suite")],
        "rust": ["rustc", "-C", "opt-level=3", "--edition=2021", str(HERE / "rust/suite.rs"), "-o", str(BUILD / "rust-suite")],
    }
    elapsed = {}
    for language in LANGUAGES:
        progress.show("Building " + LANGUAGE_LABELS[language])
        started = time.perf_counter_ns()
        result = run_command(commands[language], env=env)
        elapsed[language] = time.perf_counter_ns() - started
        if result.returncode:
            sys.exit("build failed for {}:\n{}\n{}\n{}".format(
                language, command_text(commands[language]), result.stdout, result.stderr))
        progress.advance("Built {}".format(LANGUAGE_LABELS[language]))
    return commands, elapsed


def parse_output(language, benchmark, output):
    fields = {}
    for line in output.splitlines():
        if ": " in line:
            key, value = line.split(": ", 1)
            if key in ("result", "elapsed_ns"):
                fields[key] = int(value)
    if set(fields) != {"result", "elapsed_ns"}:
        raise RuntimeError("{} {} emitted invalid output:\n{}".format(language, benchmark, output))
    return fields


def make_fixture(directory):
    path = directory / "input.txt"
    part = b"alpha beta gamma delta 0123456789\n"
    with path.open("wb") as output:
        for _ in range(8192):
            output.write(part)
    return path


def execute(executable, benchmark, input_path, output_path):
    command = [str(executable), benchmark, str(input_path), str(output_path)]
    started = time.perf_counter_ns()
    result = run_command(command)
    wall_ns = time.perf_counter_ns() - started
    if result.returncode:
        raise RuntimeError("run failed:\n{}\n{}\n{}".format(command_text(command), result.stdout, result.stderr))
    fields = parse_output(executable.name, benchmark, result.stdout)
    fields["wall_ns"] = wall_ns
    return fields


def select_benchmarks(manifest, names):
    requested = set(names or [])
    known = {item["name"] for item in manifest["benchmarks"]}
    unknown = sorted(requested - known)
    if unknown:
        sys.exit("unknown benchmark(s): " + ", ".join(unknown))
    return [item for item in manifest["benchmarks"] if not requested or item["name"] in requested]


def measured_benchmarks(report):
    return [item for item in report["benchmarks"] if item["status"] == "implemented"]


def write_html_report(report, path, raw_data_name):
    embedded = json.dumps(report, separators=(",", ":")).replace("</", "<\\/")
    template = r'''<!doctype html>
<html lang="en" data-theme="dark">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark light">
  <title>Prismio Benchmark Intelligence Report</title>
  <style>
    :root {
      --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, -system-ui, sans-serif;
      --font-mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;

      --prismio: #47d7b5;
      --prismio-dim: rgba(71, 215, 181, 0.14);
      --prismio-glow: rgba(71, 215, 181, 0.25);
      --cpp: #ffb454;
      --cpp-dim: rgba(255, 180, 84, 0.14);
      --rust: #a991ff;
      --rust-dim: rgba(169, 145, 255, 0.14);

      --good: #47d7b5;
      --good-bg: rgba(71, 215, 181, 0.12);
      --bad: #ff6e7f;
      --bad-bg: rgba(255, 110, 127, 0.12);
      --neutral: #8e9cae;
      --neutral-bg: rgba(142, 156, 174, 0.12);
    }

    html[data-theme="dark"] {
      --bg: #07090e;
      --bg-gradient: radial-gradient(circle at 18% -10%, rgba(71, 215, 181, 0.08) 0%, transparent 40%),
                          radial-gradient(circle at 82% -10%, rgba(169, 145, 255, 0.08) 0%, transparent 40%),
                          #07090e;
      --surface: #0e1219;
      --surface-raised: #141a24;
      --surface-elevated: #192230;
      --border: rgba(255, 255, 255, 0.08);
      --border-subtle: rgba(255, 255, 255, 0.04);
      --border-focus: var(--prismio);
      --text: #f3f6fa;
      --text-muted: #8b97a8;
      --text-faint: #535e6f;
      --card-shadow: 0 4px 24px -2px rgba(0, 0, 0, 0.5), 0 1px 2px 0 rgba(0, 0, 0, 0.3);
      --track-bg: #141a24;
      --table-stripe: rgba(255, 255, 255, 0.015);
      --table-hover: rgba(71, 215, 181, 0.04);
    }

    html[data-theme="light"] {
      --bg: #f8fafc;
      --bg-gradient: radial-gradient(circle at 18% -10%, rgba(71, 215, 181, 0.12) 0%, transparent 45%),
                          radial-gradient(circle at 82% -10%, rgba(169, 145, 255, 0.12) 0%, transparent 45%),
                          #f8fafc;
      --surface: #ffffff;
      --surface-raised: #f1f5f9;
      --surface-elevated: #e2e8f0;
      --border: rgba(0, 0, 0, 0.08);
      --border-subtle: rgba(0, 0, 0, 0.04);
      --border-focus: #0f766e;
      --text: #0f172a;
      --text-muted: #64748b;
      --text-faint: #94a3b8;
      --card-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.06), 0 1px 3px 0 rgba(0, 0, 0, 0.04);
      --track-bg: #e2e8f0;
      --table-stripe: rgba(0, 0, 0, 0.015);
      --table-hover: rgba(71, 215, 181, 0.07);
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    html { scroll-behavior: smooth; }
    body {
      background: var(--bg-gradient);
      background-attachment: fixed;
      color: var(--text);
      font-family: var(--font-sans);
      font-size: 14px;
      line-height: 1.55;
      min-height: 100vh;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
    }

    body::before {
      content: "";
      position: fixed;
      top: 0; left: 0; right: 0;
      height: 3px;
      background: linear-gradient(90deg, var(--prismio) 0%, var(--cpp) 50%, var(--rust) 100%);
      z-index: 1000;
    }

    a { color: inherit; text-decoration: none; }
    button, input, select { font: inherit; color: inherit; }

    .shell {
      width: min(1520px, calc(100% - 48px));
      margin: 0 auto;
    }

    /* HEADER */
    header {
      padding: 56px 0 32px;
      border-bottom: 1px solid var(--border);
      position: relative;
    }

    .nav-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 20px;
      flex-wrap: wrap;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .brand-logo {
      width: 42px;
      height: 42px;
      border-radius: 12px;
      background: linear-gradient(135deg, rgba(71, 215, 181, 0.2), rgba(169, 145, 255, 0.2));
      border: 1px solid var(--border);
      display: grid;
      place-items: center;
      box-shadow: 0 0 20px var(--prismio-glow);
    }

    .brand-title {
      font-size: clamp(1.4rem, 2.8vw, 2.2rem);
      font-weight: 800;
      letter-spacing: -0.035em;
      line-height: 1.1;
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .brand-badge {
      font-size: 11px;
      font-weight: 600;
      padding: 3px 8px;
      border-radius: 999px;
      background: var(--prismio-dim);
      color: var(--prismio);
      border: 1px solid rgba(71, 215, 181, 0.3);
      letter-spacing: 0.04em;
      text-transform: uppercase;
    }

    .brand-sub {
      color: var(--text-muted);
      font-size: 14px;
      margin-top: 5px;
      max-width: 72ch;
    }

    .header-actions {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .btn {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      height: 38px;
      padding: 0 14px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 10px;
      color: var(--text);
      font-size: 13px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.16s ease;
      white-space: nowrap;
    }

    .btn:hover {
      background: var(--surface-raised);
      border-color: rgba(255, 255, 255, 0.18);
      transform: translateY(-1px);
    }

    .btn:active {
      transform: translateY(0);
    }

    .btn-primary {
      background: var(--prismio-dim);
      color: var(--prismio);
      border-color: rgba(71, 215, 181, 0.4);
    }

    .btn-primary:hover {
      background: rgba(71, 215, 181, 0.22);
      border-color: var(--prismio);
    }

    .icon-btn {
      width: 38px;
      height: 38px;
      padding: 0;
      display: grid;
      place-items: center;
      border-radius: 10px;
    }

    /* EXECUTIVE SUMMARY & KPI CARDS */
    .kpi-section {
      margin-top: 32px;
    }

    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 24px;
    }

    .kpi-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 32px;
      position: relative;
      overflow: hidden;
      box-shadow: var(--card-shadow);
      transition: transform 0.2s ease, border-color 0.2s ease;
    }

    .kpi-card:hover {
      transform: translateY(-2px);
      border-color: rgba(255, 255, 255, 0.14);
    }

    .kpi-card::after {
      content: "";
      position: absolute;
      top: 0; left: 0; right: 0;
      height: 3px;
      background: var(--card-accent, var(--border));
    }

    .kpi-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      color: var(--text-muted);
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      margin-bottom: 12px;
    }

    .kpi-value-row {
      display: flex;
      align-items: baseline;
      gap: 10px;
    }

    .kpi-number {
      font-size: clamp(2rem, 3.2vw, 2.75rem);
      font-weight: 800;
      line-height: 1;
      letter-spacing: -0.04em;
      font-family: var(--font-mono);
      font-variant-numeric: tabular-nums;
    }

    .kpi-delta {
      font-size: 12px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 6px;
      white-space: nowrap;
      font-family: var(--font-mono);
    }

    .kpi-desc {
      margin-top: 10px;
      font-size: 13px;
      color: var(--text-muted);
      line-height: 1.4;
    }

    .kpi-detail-list {
      margin-top: 12px;
      display: flex;
      flex-direction: column;
      gap: 6px;
      font-size: 12px;
      font-family: var(--font-mono);
    }

    .kpi-detail-item {
      display: flex;
      justify-content: space-between;
      color: var(--text-muted);
    }

    .kpi-detail-item strong {
      color: var(--text);
    }

    /* WIN/LOSS/TIE BARS */
    .distribution-bar {
      height: 8px;
      border-radius: 999px;
      background: var(--surface-raised);
      display: flex;
      overflow: hidden;
      margin-top: 12px;
      gap: 2px;
    }

    .dist-seg {
      height: 100%;
      transition: width 0.4s ease;
    }

    .dist-seg.win { background: var(--good); }
    .dist-seg.tie { background: var(--neutral); }
    .dist-seg.loss { background: var(--bad); }

    /* CATEGORY CARDS GRID */
    .category-section {
      margin-top: 40px;
    }

    .category-grid {
      display: grid;
      grid-template-columns: repeat(5, 1fr);
      gap: 20px;
    }

    .cat-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 20px 24px;
      cursor: pointer;
      transition: all 0.16s ease;
      position: relative;
    }

    .cat-card:hover, .cat-card.active {
      border-color: var(--prismio);
      background: var(--surface-raised);
      transform: translateY(-2px);
    }

    .cat-card.active::before {
      content: "";
      position: absolute;
      top: 0; left: 16px; right: 16px;
      height: 2px;
      background: var(--prismio);
      border-radius: 0 0 2px 2px;
    }

    .cat-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 8px;
    }

    .cat-name {
      font-weight: 700;
      font-size: 13px;
      text-transform: capitalize;
    }

    .cat-count {
      font-size: 11px;
      color: var(--text-faint);
      font-family: var(--font-mono);
      background: var(--surface-raised);
      padding: 2px 6px;
      border-radius: 4px;
    }

    .cat-metrics {
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      font-family: var(--font-mono);
      margin-top: 4px;
    }

    .cat-metric-label {
      color: var(--text-muted);
      font-size: 11px;
    }

    /* MAIN CONTENT & TOOLBAR */
    main {
      padding: 40px 0 96px;
    }

    .toolbar-container {
      position: sticky;
      top: 0;
      z-index: 100;
      padding: 16px 0;
      background: color-mix(in srgb, var(--bg) 88%, transparent);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border-bottom: 1px solid var(--border);
      margin-bottom: 32px;
    }

    .toolbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      flex-wrap: wrap;
    }

    .search-wrapper {
      position: relative;
      flex: 1;
      min-width: 240px;
      max-width: 440px;
    }

    .search-icon {
      position: absolute;
      left: 14px;
      top: 50%;
      transform: translateY(-50%);
      color: var(--text-faint);
      pointer-events: none;
    }

    .search-input {
      width: 100%;
      height: 40px;
      padding: 0 38px 0 40px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 10px;
      color: var(--text);
      font-size: 13px;
      outline: none;
      transition: border-color 0.16s ease, box-shadow 0.16s ease;
    }

    .search-input:focus {
      border-color: var(--border-focus);
      box-shadow: 0 0 0 3px var(--prismio-dim);
    }

    .clear-search {
      position: absolute;
      right: 12px;
      top: 50%;
      transform: translateY(-50%);
      background: none;
      border: none;
      color: var(--text-faint);
      cursor: pointer;
      display: none;
    }

    .clear-search.visible {
      display: block;
    }

    .toolbar-filters {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
    }

    .select-wrap {
      position: relative;
    }

    .toolbar-select {
      height: 40px;
      padding: 0 32px 0 14px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 10px;
      color: var(--text);
      font-size: 13px;
      outline: none;
      cursor: pointer;
      appearance: none;
    }

    .toolbar-select:focus {
      border-color: var(--border-focus);
    }

    .select-arrow {
      position: absolute;
      right: 12px;
      top: 50%;
      transform: translateY(-50%);
      pointer-events: none;
      color: var(--text-faint);
    }

    .tab-group {
      display: inline-flex;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 3px;
      gap: 2px;
    }

    .tab-btn {
      padding: 6px 12px;
      font-size: 12px;
      font-weight: 600;
      border: none;
      background: transparent;
      color: var(--text-muted);
      border-radius: 7px;
      cursor: pointer;
      transition: all 0.16s ease;
    }

    .tab-btn:hover {
      color: var(--text);
    }

    .tab-btn.active {
      background: var(--surface-raised);
      color: var(--prismio);
      box-shadow: 0 1px 4px rgba(0, 0, 0, 0.2);
    }

    /* FILTER CHIPS ROW */
    .filter-chips-row {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-top: 10px;
      flex-wrap: wrap;
    }

    .chip-label {
      font-size: 11px;
      font-weight: 600;
      color: var(--text-faint);
      text-transform: uppercase;
      letter-spacing: 0.06em;
      margin-right: 4px;
    }

    .chip {
      font-size: 11px;
      font-weight: 600;
      padding: 4px 10px;
      border-radius: 999px;
      background: var(--surface);
      border: 1px solid var(--border);
      color: var(--text-muted);
      cursor: pointer;
      transition: all 0.16s ease;
    }

    .chip:hover {
      color: var(--text);
      border-color: rgba(255, 255, 255, 0.2);
    }

    .chip.active {
      background: var(--prismio-dim);
      color: var(--prismio);
      border-color: rgba(71, 215, 181, 0.4);
    }

    /* SECTION HEADERS */
    .section-header {
      display: flex;
      align-items: flex-end;
      justify-content: space-between;
      gap: 20px;
      margin: 48px 0 20px;
    }

    .section-title-wrap {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .section-title {
      font-size: 1.5rem;
      font-weight: 700;
      letter-spacing: -0.03em;
    }

    .section-subtitle {
      color: var(--text-muted);
      font-size: 13px;
    }

    .section-controls {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    /* CHARTS SECTION */
    .chart-container {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 16px;
      box-shadow: var(--card-shadow);
      overflow: hidden;
    }

    .chart-legend {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 16px 24px;
      border-bottom: 1px solid var(--border);
      background: var(--surface-raised);
      flex-wrap: wrap;
      gap: 16px;
    }

    .legend-items {
      display: flex;
      align-items: center;
      gap: 20px;
      font-size: 13px;
      font-weight: 600;
    }

    .legend-item {
      display: inline-flex;
      align-items: center;
      gap: 8px;
    }

    .legend-dot {
      width: 10px;
      height: 10px;
      border-radius: 3px;
    }

    .legend-dot.prismio { background: var(--prismio); box-shadow: 0 0 8px var(--prismio-glow); }
    .legend-dot.cpp { background: var(--cpp); }
    .legend-dot.rust { background: var(--rust); }

    .chart-list {
      padding: 8px 0;
    }

    .category-group-header {
      padding: 14px 24px;
      background: var(--surface-raised);
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.05em;
      text-transform: uppercase;
      color: var(--text-muted);
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-top: 1px solid var(--border);
      border-bottom: 1px solid var(--border);
    }

    .category-group-header:first-child {
      border-top: none;
    }

    .bench-row {
      display: grid;
      grid-template-columns: 280px minmax(0, 1fr);
      gap: 40px;
      padding: 32px 32px;
      border-bottom: 1px solid var(--border-subtle);
      transition: background 0.16s ease;
      align-items: center;
    }

    .bench-row:last-child {
      border-bottom: none;
    }

    .bench-row:hover {
      background: var(--table-hover);
    }

    .bench-info {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .bench-title-row {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
    }

    .bench-name {
      font-family: var(--font-mono);
      font-weight: 700;
      font-size: 14px;
      letter-spacing: -0.01em;
    }

    .winner-badge {
      font-size: 10px;
      font-weight: 700;
      padding: 2px 6px;
      border-radius: 4px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }

    .winner-badge.prismio {
      background: var(--prismio-dim);
      color: var(--prismio);
      border: 1px solid rgba(71, 215, 181, 0.3);
    }

    .winner-badge.cpp {
      background: var(--cpp-dim);
      color: var(--cpp);
      border: 1px solid rgba(255, 180, 84, 0.3);
    }

    .winner-badge.rust {
      background: var(--rust-dim);
      color: var(--rust);
      border: 1px solid rgba(169, 145, 255, 0.3);
    }

    .bench-tags {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-top: 2px;
    }

    .bench-tag {
      font-size: 11px;
      color: var(--text-faint);
      text-transform: capitalize;
    }

    .bench-tag.profile {
      background: var(--surface-raised);
      padding: 1px 6px;
      border-radius: 4px;
      font-family: var(--font-mono);
      font-size: 10px;
    }

    .bars-stack {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .bar-line {
      display: grid;
      grid-template-columns: 64px minmax(0, 1fr) 140px;
      gap: 20px;
      align-items: center;
    }

    .bar-lang-label {
      font-size: 12px;
      font-weight: 600;
      color: var(--text-muted);
    }

    .bar-track {
      height: 6px;
      background: var(--track-bg);
      border-radius: 999px;
      overflow: hidden;
      position: relative;
    }

    .bar-fill {
      height: 100%;
      border-radius: 999px;
      transition: width 0.5s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .bar-fill.prismio { background: var(--prismio); }
    .bar-fill.cpp { background: var(--cpp); }
    .bar-fill.rust { background: var(--rust); }

    .bar-stats {
      font-family: var(--font-mono);
      font-size: 12px;
      color: var(--text-muted);
      text-align: right;
      white-space: nowrap;
      font-variant-numeric: tabular-nums;
    }

    .bar-stats strong {
      color: var(--text);
    }

    /* DIVERGING DELTA CHART */
    .diverging-container {
      display: grid;
      grid-template-columns: 1fr 2px 1fr;
      align-items: center;
      position: relative;
      height: 20px;
    }

    .diverging-center-line {
      width: 2px;
      height: 100%;
      background: var(--border);
      position: relative;
    }

    .diverging-bar {
      height: 10px;
      border-radius: 4px;
      transition: width 0.4s ease;
    }

    /* DATA MATRIX (TABLE) */
    .table-container {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 16px;
      box-shadow: var(--card-shadow);
      overflow: hidden;
    }

    .table-scroll {
      overflow-x: auto;
      max-width: 100%;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      font-variant-numeric: tabular-nums;
      text-align: left;
    }

    thead th {
      background: var(--surface-raised);
      padding: 14px 16px;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      color: var(--text-muted);
      border-bottom: 1px solid var(--border);
      white-space: nowrap;
      user-select: none;
      cursor: pointer;
      transition: color 0.16s ease, background 0.16s ease;
    }

    thead th:hover {
      color: var(--text);
      background: var(--surface-elevated);
    }

    thead th.sortable {
      position: relative;
    }

    thead th.sort-asc::after { content: " ▲"; color: var(--prismio); }
    thead th.sort-desc::after { content: " ▼"; color: var(--prismio); }

    tbody tr.data-row {
      border-bottom: 1px solid var(--border-subtle);
      cursor: pointer;
      transition: background 0.16s ease;
    }

    tbody tr.data-row:hover {
      background: var(--table-hover);
    }

    tbody tr.data-row.expanded {
      background: var(--surface-raised);
    }

    tbody td {
      padding: 14px 16px;
      font-size: 13px;
      font-family: var(--font-mono);
      color: var(--text-muted);
      white-space: nowrap;
    }

    tbody td.cell-primary {
      font-family: var(--font-sans);
      color: var(--text);
      font-weight: 600;
    }

    .num-p { color: var(--prismio); font-weight: 600; }
    .num-c { color: var(--cpp); }
    .num-r { color: var(--rust); }

    /* DELTA PILLS */
    .delta-pill {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 700;
      font-family: var(--font-mono);
    }

    .delta-pill.faster {
      background: var(--good-bg);
      color: var(--good);
    }

    .delta-pill.slower {
      background: var(--bad-bg);
      color: var(--bad);
    }

    .delta-pill.parity {
      background: var(--neutral-bg);
      color: var(--neutral);
    }

    /* ROW DETAILS DRAWER */
    tr.drawer-row {
      display: none;
    }

    tr.drawer-row.open {
      display: table-row;
    }

    .drawer-cell {
      padding: 0 !important;
      background: var(--surface-raised);
    }

    .drawer-content {
      padding: 24px;
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 24px;
      border-bottom: 1px solid var(--border);
    }

    .drawer-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 16px;
    }

    .drawer-card-title {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--text-muted);
      margin-bottom: 12px;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .samples-plot {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .sample-plot-line {
      display: grid;
      grid-template-columns: 56px 1fr;
      gap: 10px;
      align-items: center;
    }

    .sample-dots-track {
      height: 20px;
      background: var(--surface-raised);
      border-radius: 6px;
      position: relative;
      overflow: hidden;
    }

    .sample-dot {
      position: absolute;
      top: 50%;
      transform: translate(-50%, -50%);
      width: 6px;
      height: 6px;
      border-radius: 50%;
      opacity: 0.8;
    }

    .sample-median-marker {
      position: absolute;
      top: 2px;
      bottom: 2px;
      width: 2px;
      border-radius: 1px;
      transform: translateX(-50%);
    }

    /* UNSUPPORTED SECTION */
    .unsupported-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 16px;
    }

    .unsupported-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 18px 20px;
      position: relative;
      box-shadow: var(--card-shadow);
    }

    .unsupported-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 8px;
    }

    .unsupported-name {
      font-family: var(--font-mono);
      font-weight: 700;
      font-size: 14px;
      color: var(--text);
    }

    .unsupported-badge {
      font-size: 10px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      padding: 2px 7px;
      border-radius: 4px;
      background: rgba(255, 180, 84, 0.12);
      color: var(--cpp);
      border: 1px solid rgba(255, 180, 84, 0.25);
    }

    .unsupported-meta {
      display: flex;
      gap: 8px;
      font-size: 12px;
      color: var(--text-faint);
    }

    /* FOOTER */
    footer {
      padding: 48px 0;
      border-top: 1px solid var(--border);
      color: var(--text-faint);
      font-size: 13px;
      margin-top: 64px;
    }

    .footer-inner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 16px;
    }

    .empty-message {
      padding: 64px 24px;
      text-align: center;
      color: var(--text-muted);
      font-size: 14px;
    }

    /* TOAST NOTIFICATION */
    .toast {
      position: fixed;
      bottom: 24px;
      right: 24px;
      background: var(--surface-elevated);
      color: var(--text);
      border: 1px solid var(--border);
      padding: 12px 18px;
      border-radius: 10px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);
      font-size: 13px;
      font-weight: 600;
      z-index: 9999;
      transform: translateY(100px);
      opacity: 0;
      transition: all 0.24s cubic-bezier(0.16, 1, 0.3, 1);
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .toast.show {
      transform: translateY(0);
      opacity: 1;
    }

    @media (max-width: 1200px) {
      .kpi-grid { grid-template-columns: repeat(2, 1fr); }
      .category-grid { grid-template-columns: repeat(3, 1fr); }
      .drawer-content { grid-template-columns: 1fr; }
    }

    @media (max-width: 768px) {
      .shell { width: calc(100% - 28px); }
      header { padding-top: 36px; }
      .kpi-grid { grid-template-columns: 1fr; }
      .category-grid { grid-template-columns: 1fr 1fr; }
      .bench-row { grid-template-columns: 1fr; gap: 14px; }
      .bar-line { grid-template-columns: 56px 1fr 110px; gap: 8px; }
      .toolbar { flex-direction: column; align-items: stretch; }
      .search-wrapper { max-width: 100%; }
    }
  </style>
</head>
<body>
  <div class="shell">
    <header>
      <div class="nav-bar">
        <div class="brand">
          <div class="brand-logo">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polygon points="12 2 22 8.5 22 15.5 12 22 2 15.5 2 8.5 12 2" stroke="var(--prismio)"/>
              <line x1="12" y1="22" x2="12" y2="12" stroke="var(--prismio)"/>
              <line x1="22" y1="8.5" x2="12" y2="12" stroke="var(--cpp)"/>
              <line x1="2" y1="8.5" x2="12" y2="12" stroke="var(--rust)"/>
            </svg>
          </div>
          <div>
            <div class="brand-title">
              Prismio Benchmark Intelligence
              <span class="brand-badge">Cross-Language</span>
            </div>
            <p class="brand-sub">Canonical workload matrix evaluating Prismio against Clang++ C++20 (-O3) and Rustc 2021 (opt-level 3).</p>
          </div>
        </div>
        <div class="header-actions">
          <button class="btn icon-btn" id="theme-toggle" title="Toggle Light/Dark Theme" aria-label="Toggle Theme">
            <svg id="theme-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
            </svg>
          </button>
          <button class="btn" id="copy-summary-btn" title="Copy markdown summary for PRs or documentation">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
              <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
            </svg>
            Copy Summary
          </button>
          <a class="btn" href="__RAW_FILE__" target="_blank" rel="noopener">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
              <polyline points="14 2 14 8 20 8"></polyline>
              <line x1="16" y1="13" x2="8" y2="13"></line>
              <line x1="16" y1="17" x2="8" y2="17"></line>
            </svg>
            Raw JSON
          </a>
        </div>
      </div>

      <!-- EXECUTIVE KPI SECTION -->
      <section class="kpi-section" aria-label="Executive KPI Overview">
        <div class="kpi-grid" id="kpi-grid"></div>
      </section>

      <!-- CATEGORY SCORECARDS -->
      <section class="category-section" aria-label="Category Summaries">
        <div class="category-grid" id="category-grid"></div>
      </section>
    </header>

    <main>
      <!-- CONTROLS TOOLBAR -->
      <div class="toolbar-container">
        <div class="toolbar" role="toolbar" aria-label="Dashboard controls">
          <div class="search-wrapper">
            <svg class="search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="11" cy="11" r="8"></circle>
              <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
            </svg>
            <input class="search-input" id="search-input" type="search" placeholder="Search workloads (e.g. quicksort, fft, memory)..." autocomplete="off" spellcheck="false">
            <button class="clear-search" id="clear-search" title="Clear search">✕</button>
          </div>

          <div class="toolbar-filters">
            <div class="select-wrap">
              <select class="toolbar-select" id="profile-filter" aria-label="Filter by profile">
                <option value="all">All Workload Profiles</option>
                <option value="cpu">CPU Intensive</option>
                <option value="cpu-memory">CPU & Memory</option>
                <option value="memory">Memory Intensive</option>
                <option value="allocation">Allocation Heavy</option>
                <option value="io">I/O Intensive</option>
                <option value="concurrency">Concurrency</option>
              </select>
              <span class="select-arrow">▼</span>
            </div>

            <div class="select-wrap">
              <select class="toolbar-select" id="sort-select" aria-label="Sort workloads">
                <option value="catalog">Sort: Catalog Order</option>
                <option value="prismio-fastest">Sort: Prismio Fastest First</option>
                <option value="prismio-slowest">Sort: Prismio Slowest First</option>
                <option value="cpp-ratio-best">Sort: Best vs C++</option>
                <option value="cpp-ratio-worst">Sort: Worst vs C++</option>
                <option value="rust-ratio-best">Sort: Best vs Rust</option>
                <option value="rust-ratio-worst">Sort: Worst vs Rust</option>
              </select>
              <span class="select-arrow">▼</span>
            </div>

            <div class="tab-group" id="chart-mode-tabs" role="tablist" aria-label="Chart representation">
              <button class="tab-btn active" data-mode="relative" role="tab" aria-selected="true">Speedup Ratio</button>
              <button class="tab-btn" data-mode="absolute" role="tab" aria-selected="false">Absolute Time</button>
              <button class="tab-btn" data-mode="diverging" role="tab" aria-selected="false">Prismio Delta</button>
            </div>
          </div>
        </div>

        <div class="filter-chips-row">
          <span class="chip-label">Outcome:</span>
          <button class="chip active" data-filter="outcome" data-val="all">All (<span id="count-all">34</span>)</button>
          <button class="chip" data-filter="outcome" data-val="prismio-win">Prismio Wins (<span id="count-win">0</span>)</button>
          <button class="chip" data-filter="outcome" data-val="parity">Within ±5% (<span id="count-parity">0</span>)</button>
          <button class="chip" data-filter="outcome" data-val="prismio-loss">Prismio Behind (<span id="count-loss">0</span>)</button>
        </div>
      </div>

      <!-- VISUAL COMPARISON SECTION -->
      <section aria-labelledby="chart-section-title">
        <div class="section-header">
          <div class="section-title-wrap">
            <h2 class="section-title" id="chart-section-title">Visual Comparison</h2>
            <p class="section-subtitle" id="chart-subtitle">Direct workload comparison with winner highlighting and normalized scaling</p>
          </div>
          <div class="section-controls">
            <button class="btn" id="toggle-grouping-btn">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="8" y1="6" x2="21" y2="6"></line>
                <line x1="8" y1="12" x2="21" y2="12"></line>
                <line x1="8" y1="18" x2="21" y2="18"></line>
                <line x1="3" y1="6" x2="3.01" y2="6"></line>
                <line x1="3" y1="12" x2="3.01" y2="12"></line>
                <line x1="3" y1="18" x2="3.01" y2="18"></line>
              </svg>
              <span id="grouping-label">Group by Category</span>
            </button>
          </div>
        </div>

        <div class="chart-container">
          <div class="chart-legend">
            <div class="legend-items">
              <div class="legend-item"><span class="legend-dot prismio"></span><span>Prismio</span></div>
              <div class="legend-item"><span class="legend-dot cpp"></span><span>C++ (Clang -O3)</span></div>
              <div class="legend-item"><span class="legend-dot rust"></span><span>Rust (opt-level 3)</span></div>
            </div>
            <div style="font-size:12px; color:var(--text-faint); font-family:var(--font-mono);" id="visible-status">
              Showing 34 of 34 workloads
            </div>
          </div>
          <div class="chart-list" id="chart-list"></div>
        </div>
      </section>

      <!-- PRECISE TIMING MATRIX TABLE -->
      <section aria-labelledby="table-section-title" style="margin-top: 64px;">
        <div class="section-header">
          <div class="section-title-wrap">
            <h2 class="section-title" id="table-section-title">Detailed Performance Matrix</h2>
            <p class="section-subtitle">Median timings across samples, relative slowdown/speedup factors, and run stability</p>
          </div>
          <div class="section-controls">
            <button class="btn" id="copy-table-md-btn">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
              </svg>
              Copy Markdown
            </button>
            <button class="btn" id="copy-table-csv-btn">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                <polyline points="7 10 12 15 17 10"></polyline>
                <line x1="12" y1="15" x2="12" y2="3"></line>
              </svg>
              Export CSV
            </button>
          </div>
        </div>

        <div class="table-container">
          <div class="table-scroll">
            <table id="performance-table">
              <thead>
                <tr>
                  <th class="sortable" data-col="name">Workload</th>
                  <th class="sortable" data-col="category">Category</th>
                  <th class="sortable" data-col="profile">Profile</th>
                  <th class="sortable" data-col="result">Checksum</th>
                  <th class="sortable" data-col="prismio">Prismio Median</th>
                  <th class="sortable" data-col="cpp">C++ Median</th>
                  <th class="sortable" data-col="rust">Rust Median</th>
                  <th class="sortable" data-col="vs-cpp">vs C++</th>
                  <th class="sortable" data-col="vs-rust">vs Rust</th>
                  <th class="sortable" data-col="jitter">Stability (±)</th>
                </tr>
              </thead>
              <tbody id="table-body"></tbody>
            </table>
          </div>
        </div>
      </section>

      <!-- UNSUPPORTED CAPABILITIES SECTION -->
      <section id="unsupported-section" aria-labelledby="unsupported-title" style="margin-top: 64px;">
        <div class="section-header">
          <div class="section-title-wrap">
            <h2 class="section-title" id="unsupported-title">Cataloged & Pending Capabilities</h2>
            <p class="section-subtitle">Cataloged benchmark workloads awaiting upcoming Prismio language or runtime features</p>
          </div>
        </div>
        <div class="unsupported-grid" id="unsupported-grid"></div>
      </section>
    </main>

    <footer>
      <div class="footer-inner">
        <div id="footer-meta">Prismio Cross-Language Performance Matrix</div>
        <div>All 34 implemented benchmarks verified with identical canonical checksums across all 3 languages.</div>
      </div>
    </footer>
  </div>

  <div class="toast" id="toast" role="status" aria-live="polite">Copied to clipboard!</div>

  <script>
    const report = __REPORT_DATA__;
    const languages = ["prismio", "cpp", "rust"];
    const labels = {prismio: "Prismio", cpp: "C++", rust: "Rust"};
    const implemented = report.benchmarks.filter(b => b.status === "implemented");
    const unsupported = report.benchmarks.filter(b => b.status === "unsupported");

    // Math & Formatting Helpers
    const median = (item, lang) => item.languages[lang].elapsed_ns_median;
    const wallMedian = (item, lang) => item.languages[lang].wall_ns_median;
    const ratio = (item, baseline) => median(item, "prismio") / Math.max(median(item, baseline), 1);

    function geomean(values) {
      if (!values.length) return 1;
      const logSum = values.reduce((acc, v) => acc + Math.log(Math.max(v, 1e-9)), 0);
      return Math.exp(logSum / values.length);
    }

    function jitterPercent(samples, med) {
      if (!samples || samples.length <= 1 || !med) return null;
      const min = Math.min(...samples);
      const max = Math.max(...samples);
      return ((max - min) / (2 * med)) * 100;
    }

    function duration(ns) {
      if (ns >= 1e9) return `${(ns / 1e9).toFixed(3)} s`;
      if (ns >= 1e6) return `${(ns / 1e6).toFixed(3)} ms`;
      if (ns >= 1e3) return `${(ns / 1e3).toFixed(2)} µs`;
      return `${ns} ns`;
    }

    function formatNumber(num) {
      return Number(num).toLocaleString("en-US");
    }

    function escapeHtml(str) {
      return String(str).replace(/[&<>'"]/g, c => ({
        "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
      }[c]));
    }

    // State
    let currentCategory = "all";
    let currentProfile = "all";
    let currentOutcome = "all";
    let currentSearch = "";
    let currentSort = "catalog";
    let chartMode = "relative"; // "relative" | "absolute" | "diverging"
    let isGrouped = true;
    let expandedRows = new Set();
    let sortColumn = null;
    let sortDirection = "asc";

    // Theme Switcher
    const htmlEl = document.documentElement;
    const themeBtn = document.querySelector("#theme-toggle");
    const themeIcon = document.querySelector("#theme-icon");

    function setTheme(t) {
      htmlEl.setAttribute("data-theme", t);
      localStorage.setItem("prismio-theme", t);
      themeIcon.innerHTML = t === "dark"
        ? '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>'
        : '<circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>';
    }
    const savedTheme = localStorage.getItem("prismio-theme") || "dark";
    setTheme(savedTheme);
    themeBtn.addEventListener("click", () => {
      const next = htmlEl.getAttribute("data-theme") === "dark" ? "light" : "dark";
      setTheme(next);
    });

    // Toast Utility
    const toast = document.querySelector("#toast");
    let toastTimer = null;
    function showToast(msg) {
      toast.textContent = msg;
      toast.classList.add("show");
      clearTimeout(toastTimer);
      toastTimer = setTimeout(() => toast.classList.remove("show"), 2800);
    }

    // Compute Executive Stats
    const cppRatios = implemented.map(item => ratio(item, "cpp"));
    const rustRatios = implemented.map(item => ratio(item, "rust"));
    const cppGeomean = geomean(cppRatios);
    const rustGeomean = geomean(rustRatios);

    const winsVsCpp = implemented.filter(item => ratio(item, "cpp") < 0.95).length;
    const parityVsCpp = implemented.filter(item => ratio(item, "cpp") >= 0.95 && ratio(item, "cpp") <= 1.05).length;
    const lossesVsCpp = implemented.filter(item => ratio(item, "cpp") > 1.05).length;

    const winsVsRust = implemented.filter(item => ratio(item, "rust") < 0.95).length;
    const parityVsRust = implemented.filter(item => ratio(item, "rust") >= 0.95 && ratio(item, "rust") <= 1.05).length;
    const lossesVsRust = implemented.filter(item => ratio(item, "rust") > 1.05).length;

    // Render KPI Cards
    function renderKPIs() {
      const kpiGrid = document.querySelector("#kpi-grid");
      const fmtRatio = r => `${r.toFixed(2)}×`;
      const deltaText = r => r <= 1
        ? `${((1 - r) * 100).toFixed(1)}% faster`
        : `${((r - 1) * 100).toFixed(1)}% slower`;

      const compilePrismio = report.compile_ns ? report.compile_ns.prismio : null;
      const compileCpp = report.compile_ns ? report.compile_ns.cpp : null;
      const compileRust = report.compile_ns ? report.compile_ns.rust : null;
      const compileSpeedup = (compilePrismio && compileCpp) ? (compileCpp / compilePrismio).toFixed(2) : null;

      kpiGrid.innerHTML = `
        <div class="kpi-card" style="--card-accent: var(--prismio)">
          <div class="kpi-header">
            <span>Overall vs C++</span>
            <span style="color:var(--cpp)">Clang++ -O3</span>
          </div>
          <div class="kpi-value-row">
            <div class="kpi-number" style="color:var(--prismio)">${fmtRatio(cppGeomean)}</div>
            <span class="kpi-delta" style="background:${cppGeomean <= 1 ? 'var(--good-bg)' : 'var(--bad-bg)'}; color:${cppGeomean <= 1 ? 'var(--good)' : 'var(--bad)'}">${deltaText(cppGeomean)}</span>
          </div>
          <p class="kpi-desc">Geometric mean across all ${implemented.length} implemented workloads.</p>
          <div class="distribution-bar" title="Prismio vs C++: ${winsVsCpp} faster, ${parityVsCpp} parity, ${lossesVsCpp} slower">
            <div class="dist-seg win" style="width:${(winsVsCpp / implemented.length * 100).toFixed(1)}%"></div>
            <div class="dist-seg tie" style="width:${(parityVsCpp / implemented.length * 100).toFixed(1)}%"></div>
            <div class="dist-seg loss" style="width:${(lossesVsCpp / implemented.length * 100).toFixed(1)}%"></div>
          </div>
          <div class="kpi-detail-list">
            <div class="kpi-detail-item"><span>Prismio faster / parity</span><strong>${winsVsCpp + parityVsCpp} of ${implemented.length}</strong></div>
            <div class="kpi-detail-item"><span>Fastest margin</span><strong>${(Math.min(...cppRatios)).toFixed(2)}×</strong></div>
          </div>
        </div>

        <div class="kpi-card" style="--card-accent: var(--rust)">
          <div class="kpi-header">
            <span>Overall vs Rust</span>
            <span style="color:var(--rust)">rustc opt-3</span>
          </div>
          <div class="kpi-value-row">
            <div class="kpi-number" style="color:var(--prismio)">${fmtRatio(rustGeomean)}</div>
            <span class="kpi-delta" style="background:${rustGeomean <= 1 ? 'var(--good-bg)' : 'var(--bad-bg)'}; color:${rustGeomean <= 1 ? 'var(--good)' : 'var(--bad)'}">${deltaText(rustGeomean)}</span>
          </div>
          <p class="kpi-desc">Geometric mean across all ${implemented.length} implemented workloads.</p>
          <div class="distribution-bar" title="Prismio vs Rust: ${winsVsRust} faster, ${parityVsRust} parity, ${lossesVsRust} slower">
            <div class="dist-seg win" style="width:${(winsVsRust / implemented.length * 100).toFixed(1)}%"></div>
            <div class="dist-seg tie" style="width:${(parityVsRust / implemented.length * 100).toFixed(1)}%"></div>
            <div class="dist-seg loss" style="width:${(lossesVsRust / implemented.length * 100).toFixed(1)}%"></div>
          </div>
          <div class="kpi-detail-list">
            <div class="kpi-detail-item"><span>Prismio faster / parity</span><strong>${winsVsRust + parityVsRust} of ${implemented.length}</strong></div>
            <div class="kpi-detail-item"><span>Fastest margin</span><strong>${(Math.min(...rustRatios)).toFixed(2)}×</strong></div>
          </div>
        </div>

        <div class="kpi-card" style="--card-accent: var(--cpp)">
          <div class="kpi-header">
            <span>Compilation Speed</span>
            <span>Release Suite</span>
          </div>
          <div class="kpi-value-row">
            <div class="kpi-number" style="color:var(--text)">${compilePrismio ? duration(compilePrismio) : "Reused"}</div>
            ${compileSpeedup ? `<span class="kpi-delta" style="background:var(--good-bg); color:var(--good)">${compileSpeedup}× faster vs C++</span>` : ''}
          </div>
          <p class="kpi-desc">Time taken to build full dispatch suite from sources.</p>
          <div class="kpi-detail-list" style="margin-top:16px;">
            <div class="kpi-detail-item"><span>Prismio compiler</span><strong>${compilePrismio ? duration(compilePrismio) : "cached"}</strong></div>
            <div class="kpi-detail-item"><span>Clang++ (-O3)</span><strong>${compileCpp ? duration(compileCpp) : "cached"}</strong></div>
            <div class="kpi-detail-item"><span>Rustc (opt-3)</span><strong>${compileRust ? duration(compileRust) : "cached"}</strong></div>
          </div>
        </div>

        <div class="kpi-card" style="--card-accent: #38bdf8">
          <div class="kpi-header">
            <span>Suite Scale & Integrity</span>
            <span style="color:var(--good)">✓ Verified</span>
          </div>
          <div class="kpi-value-row">
            <div class="kpi-number" style="color:var(--text)">${implemented.length}<span style="font-size:1.4rem; color:var(--text-muted);">/${report.benchmarks.length}</span></div>
            <span class="kpi-delta" style="background:var(--good-bg); color:var(--good)">100% Match</span>
          </div>
          <p class="kpi-desc">Identical outputs validated across all language binaries.</p>
          <div class="kpi-detail-list" style="margin-top:16px;">
            <div class="kpi-detail-item"><span>Sample iterations</span><strong>${report.runs} runs (${report.runs * implemented.length * 3} total)</strong></div>
            <div class="kpi-detail-item"><span>Unsupported catalog</span><strong>${unsupported.length} capabilities</strong></div>
            <div class="kpi-detail-item"><span>Generated</span><strong>${new Date(report.generated_at).toLocaleDateString(undefined, {month:'short', day:'numeric', hour:'2-digit', minute:'2-digit'})}</strong></div>
          </div>
        </div>
      `;
    }

    // Render Category Grid
    function renderCategories() {
      const catGrid = document.querySelector("#category-grid");
      const categories = [...new Set(report.benchmarks.map(b => b.category))];
      catGrid.innerHTML = categories.map(cat => {
        const catItems = implemented.filter(b => b.category === cat);
        const count = catItems.length;
        const catCppGeomean = geomean(catItems.map(item => ratio(item, "cpp")));
        const catRustGeomean = geomean(catItems.map(item => ratio(item, "rust")));
        const isActive = currentCategory === cat;
        return `
          <div class="cat-card ${isActive ? 'active' : ''}" data-category="${cat}">
            <div class="cat-head">
              <span class="cat-name">${escapeHtml(cat.replace(/_/g, " "))}</span>
              <span class="cat-count">${count}</span>
            </div>
            <div class="cat-metrics">
              <span class="cat-metric-label">vs C++: <strong style="color:${catCppGeomean <= 1 ? 'var(--good)' : 'var(--text)'}">${catCppGeomean.toFixed(2)}×</strong></span>
              <span class="cat-metric-label">vs Rust: <strong style="color:${catRustGeomean <= 1 ? 'var(--good)' : 'var(--text)'}">${catRustGeomean.toFixed(2)}×</strong></span>
            </div>
          </div>
        `;
      }).join("");

      catGrid.querySelectorAll(".cat-card").forEach(card => {
        card.addEventListener("click", () => {
          const cat = card.getAttribute("data-category");
          currentCategory = currentCategory === cat ? "all" : cat;
          updateFilters();
        });
      });
    }

    // Filter Logic
    function getFilteredBenchmarks() {
      const q = currentSearch.toLowerCase().trim();
      return implemented.filter(item => {
        if (currentCategory !== "all" && item.category !== currentCategory) return false;
        if (currentProfile !== "all" && !item.profile.includes(currentProfile)) return false;
        if (q) {
          const matchName = item.name.toLowerCase().includes(q);
          const matchCat = item.category.toLowerCase().includes(q);
          const matchProf = (item.profile || "").toLowerCase().includes(q);
          if (!matchName && !matchCat && !matchProf) return false;
        }
        if (currentOutcome !== "all") {
          const fastest = Math.min(...languages.map(l => median(item, l)));
          const isFastest = median(item, "prismio") === fastest;
          const cppR = ratio(item, "cpp");
          const rustR = ratio(item, "rust");
          const isParity = (cppR >= 0.95 && cppR <= 1.05) || (rustR >= 0.95 && rustR <= 1.05);
          if (currentOutcome === "prismio-win" && !isFastest) return false;
          if (currentOutcome === "parity" && !isParity) return false;
          if (currentOutcome === "prismio-loss" && (isFastest || isParity)) return false;
        }
        return true;
      });
    }

    function sortBenchmarks(items) {
      const sorted = [...items];
      if (sortColumn) {
        sorted.sort((a, b) => {
          let valA, valB;
          if (sortColumn === "name") { valA = a.name; valB = b.name; }
          else if (sortColumn === "category") { valA = a.category; valB = b.category; }
          else if (sortColumn === "profile") { valA = a.profile; valB = b.profile; }
          else if (sortColumn === "result") { valA = a.result; valB = b.result; }
          else if (sortColumn === "prismio") { valA = median(a, "prismio"); valB = median(b, "prismio"); }
          else if (sortColumn === "cpp") { valA = median(a, "cpp"); valB = median(b, "cpp"); }
          else if (sortColumn === "rust") { valA = median(a, "rust"); valB = median(b, "rust"); }
          else if (sortColumn === "vs-cpp") { valA = ratio(a, "cpp"); valB = ratio(b, "cpp"); }
          else if (sortColumn === "vs-rust") { valA = ratio(a, "rust"); valB = ratio(b, "rust"); }
          else if (sortColumn === "jitter") {
            valA = jitterPercent(a.languages.prismio.elapsed_ns_samples, median(a, "prismio")) || 0;
            valB = jitterPercent(b.languages.prismio.elapsed_ns_samples, median(b, "prismio")) || 0;
          }
          if (typeof valA === "string") {
            return sortDirection === "asc" ? valA.localeCompare(valB) : valB.localeCompare(valA);
          }
          return sortDirection === "asc" ? valA - valB : valB - valA;
        });
        return sorted;
      }

      if (currentSort === "prismio-fastest") sorted.sort((a, b) => median(a, "prismio") - median(b, "prismio"));
      else if (currentSort === "prismio-slowest") sorted.sort((a, b) => median(b, "prismio") - median(a, "prismio"));
      else if (currentSort === "cpp-ratio-best") sorted.sort((a, b) => ratio(a, "cpp") - ratio(b, "cpp"));
      else if (currentSort === "cpp-ratio-worst") sorted.sort((a, b) => ratio(b, "cpp") - ratio(a, "cpp"));
      else if (currentSort === "rust-ratio-best") sorted.sort((a, b) => ratio(a, "rust") - ratio(b, "rust"));
      else if (currentSort === "rust-ratio-worst") sorted.sort((a, b) => ratio(b, "rust") - ratio(a, "rust"));
      return sorted;
    }

    // Render Charts
    function renderCharts(items) {
      const container = document.querySelector("#chart-list");
      if (!items.length) {
        container.innerHTML = `<div class="empty-message">No benchmark workloads match the selected filters.</div>`;
        return;
      }

      function renderWorkloadRow(item) {
        const pMed = median(item, "prismio");
        const cMed = median(item, "cpp");
        const rMed = median(item, "rust");
        const fastest = Math.min(pMed, cMed, rMed);

        let winner = "prismio";
        if (cMed < pMed && cMed <= rMed) winner = "cpp";
        else if (rMed < pMed && rMed < cMed) winner = "rust";

        let chartHtml = "";
        if (chartMode === "relative") {
          const maxSlowdown = Math.max(pMed / fastest, cMed / fastest, rMed / fastest, 1.5);
          chartHtml = languages.map(lang => {
            const val = median(item, lang);
            const r = val / fastest;
            const widthPct = Math.max((r / maxSlowdown) * 100, 4);
            const isWinner = lang === winner;
            return `
              <div class="bar-line">
                <span class="bar-lang-label" style="${isWinner ? 'color:var(--text);font-weight:700;' : ''}">${labels[lang]}</span>
                <div class="bar-track">
                  <div class="bar-fill ${lang}" style="width:${widthPct.toFixed(1)}%"></div>
                </div>
                <div class="bar-stats">
                  ${isWinner ? '<span style="color:var(--good);margin-right:4px;">🥇</span>' : ''}
                  <strong>${r.toFixed(2)}×</strong> · ${duration(val)}
                </div>
              </div>
            `;
          }).join("");
        } else if (chartMode === "absolute") {
          const maxVal = Math.max(pMed, cMed, rMed);
          chartHtml = languages.map(lang => {
            const val = median(item, lang);
            const widthPct = Math.max((val / maxVal) * 100, 3);
            return `
              <div class="bar-line">
                <span class="bar-lang-label">${labels[lang]}</span>
                <div class="bar-track">
                  <div class="bar-fill ${lang}" style="width:${widthPct.toFixed(1)}%"></div>
                </div>
                <div class="bar-stats"><strong>${duration(val)}</strong></div>
              </div>
            `;
          }).join("");
        } else if (chartMode === "diverging") {
          const vsCpp = (pMed - cMed) / cMed;
          const vsRust = (pMed - rMed) / rMed;
          const renderDelta = (baselineName, delta) => {
            const isFaster = delta < 0;
            const pct = Math.min(Math.abs(delta) * 100, 100);
            return `
              <div class="bar-line" style="grid-template-columns: 80px minmax(0, 1fr) 120px;">
                <span class="bar-lang-label" style="font-size:11px;">vs ${baselineName}</span>
                <div class="diverging-container">
                  <div style="display:flex; justify-content:flex-end; padding-right:4px;">
                    ${isFaster ? `<div class="diverging-bar" style="width:${pct}%; background:var(--good);"></div>` : ''}
                  </div>
                  <div class="diverging-center-line"></div>
                  <div style="display:flex; justify-content:flex-start; padding-left:4px;">
                    ${!isFaster ? `<div class="diverging-bar" style="width:${pct}%; background:var(--bad);"></div>` : ''}
                  </div>
                </div>
                <div class="bar-stats" style="color:${isFaster ? 'var(--good)' : 'var(--bad)'}">
                  <strong>${isFaster ? '-' : '+'}${Math.abs(delta * 100).toFixed(1)}%</strong>
                </div>
              </div>
            `;
          };
          chartHtml = `
            ${renderDelta("C++", vsCpp)}
            ${renderDelta("Rust", vsRust)}
          `;
        }

        return `
          <div class="bench-row">
            <div class="bench-info">
              <div class="bench-title-row">
                <span class="bench-name">${escapeHtml(item.name)}</span>
                <span class="winner-badge ${winner}">🥇 ${labels[winner]}</span>
              </div>
              <div class="bench-tags">
                <span class="bench-tag">${escapeHtml(item.category.replace(/_/g, " "))}</span>
                <span class="bench-tag profile">${escapeHtml(item.profile)}</span>
              </div>
            </div>
            <div class="bars-stack">
              ${chartHtml}
            </div>
          </div>
        `;
      }

      if (isGrouped && currentCategory === "all") {
        const groups = {};
        items.forEach(item => {
          if (!groups[item.category]) groups[item.category] = [];
          groups[item.category].push(item);
        });
        container.innerHTML = Object.entries(groups).map(([cat, groupItems]) => `
          <div class="category-group-header">
            <span>${escapeHtml(cat.replace(/_/g, " "))}</span>
            <span>${groupItems.length} workloads</span>
          </div>
          ${groupItems.map(renderWorkloadRow).join("")}
        `).join("");
      } else {
        container.innerHTML = items.map(renderWorkloadRow).join("");
      }
    }

    // Render Table Matrix
    function renderTable(items) {
      const tbody = document.querySelector("#table-body");
      if (!items.length) {
        tbody.innerHTML = `<tr><td colspan="10" class="empty-message">No benchmark workloads match the selected filters.</td></tr>`;
        return;
      }

      let html = "";
      items.forEach((item) => {
        const pMed = median(item, "prismio");
        const cMed = median(item, "cpp");
        const rMed = median(item, "rust");
        const rCpp = ratio(item, "cpp");
        const rRust = ratio(item, "rust");
        const jitter = jitterPercent(item.languages.prismio.elapsed_ns_samples, pMed);

        const pill = r => {
          if (r < 0.95) return `<span class="delta-pill faster">${r.toFixed(2)}× (-${((1 - r) * 100).toFixed(0)}%)</span>`;
          if (r <= 1.05) return `<span class="delta-pill parity">${r.toFixed(2)}× (±${Math.abs((r - 1) * 100).toFixed(0)}%)</span>`;
          return `<span class="delta-pill slower">${r.toFixed(2)}× (+${((r - 1) * 100).toFixed(0)}%)</span>`;
        };

        const isExpanded = expandedRows.has(item.name);
        html += `
          <tr class="data-row ${isExpanded ? 'expanded' : ''}" data-name="${escapeHtml(item.name)}">
            <td class="cell-primary">
              <span style="display:inline-flex; align-items:center; gap:6px;">
                <span style="font-size:10px; color:var(--text-faint);">${isExpanded ? '▼' : '▶'}</span>
                ${escapeHtml(item.name)}
              </span>
            </td>
            <td><span style="text-transform:capitalize;">${escapeHtml(item.category.replace(/_/g, " "))}</span></td>
            <td><span class="bench-tag profile">${escapeHtml(item.profile)}</span></td>
            <td style="color:var(--text-faint); font-size:11px;">${formatNumber(item.result)}</td>
            <td class="num-p">${duration(pMed)}</td>
            <td class="num-c">${duration(cMed)}</td>
            <td class="num-r">${duration(rMed)}</td>
            <td>${pill(rCpp)}</td>
            <td>${pill(rRust)}</td>
            <td>${jitter !== null ? `±${jitter.toFixed(1)}%` : '—'}</td>
          </tr>
          <tr class="drawer-row ${isExpanded ? 'open' : ''}" id="drawer-${escapeHtml(item.name)}">
            <td colspan="10" class="drawer-cell">
              <div class="drawer-content">
                <div class="drawer-card">
                  <div class="drawer-card-title">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
                    Sample Runs Spread (${report.runs} runs)
                  </div>
                  <div class="samples-plot">
                    ${languages.map(lang => {
                      const samples = item.languages[lang].elapsed_ns_samples || [];
                      const min = Math.min(...samples);
                      const max = Math.max(...samples);
                      const med = median(item, lang);
                      return `
                        <div class="sample-plot-line">
                          <span style="font-size:11px; font-weight:600; color:var(--${lang});">${labels[lang]}</span>
                          <div class="sample-dots-track" title="${labels[lang]}: min ${duration(min)}, median ${duration(med)}, max ${duration(max)}">
                            ${samples.map(s => {
                              const pct = max > min ? ((s - min) / (max - min)) * 92 + 4 : 50;
                              return `<div class="sample-dot" style="left:${pct.toFixed(1)}%; background:var(--${lang});"></div>`;
                            }).join("")}
                            <div class="sample-median-marker" style="left:${(max > min ? ((med - min) / (max - min)) * 92 + 4 : 50).toFixed(1)}%; background:var(--text);"></div>
                          </div>
                        </div>
                      `;
                    }).join("")}
                  </div>
                  <div style="font-size:11px; color:var(--text-faint); margin-top:8px;">Line marks median sample; dots represent individual run timings.</div>
                </div>

                <div class="drawer-card">
                  <div class="drawer-card-title">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect><line x1="8" y1="21" x2="16" y2="21"></line><line x1="12" y1="17" x2="12" y2="21"></line></svg>
                    Execution & Wall Clock Overhead
                  </div>
                  <div class="kpi-detail-list">
                    <div class="kpi-detail-item"><span>Prismio compute ns</span><strong>${formatNumber(pMed)} ns</strong></div>
                    <div class="kpi-detail-item"><span>Prismio total wall ns</span><strong>${formatNumber(wallMedian(item, "prismio"))} ns</strong></div>
                    <div class="kpi-detail-item"><span>Overhead (wall - compute)</span><strong>${duration(wallMedian(item, "prismio") - pMed)}</strong></div>
                    <div class="kpi-detail-item"><span>C++ overhead</span><strong>${duration(wallMedian(item, "cpp") - cMed)}</strong></div>
                    <div class="kpi-detail-item"><span>Rust overhead</span><strong>${duration(wallMedian(item, "rust") - rMed)}</strong></div>
                  </div>
                </div>

                <div class="drawer-card">
                  <div class="drawer-card-title">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
                    Verification & Workload Profile
                  </div>
                  <div class="kpi-detail-list">
                    <div class="kpi-detail-item"><span>Checksum status</span><strong style="color:var(--good);">Verified Identical ✓</strong></div>
                    <div class="kpi-detail-item"><span>Expected value</span><code>${item.result}</code></div>
                    <div class="kpi-detail-item"><span>Workload profile</span><code>${item.profile}</code></div>
                    <div class="kpi-detail-item"><span>Category</span><strong style="text-transform:capitalize;">${item.category.replace(/_/g, " ")}</strong></div>
                  </div>
                </div>
              </div>
            </td>
          </tr>
        `;
      });
      tbody.innerHTML = html;

      tbody.querySelectorAll("tr.data-row").forEach(row => {
        row.addEventListener("click", () => {
          const name = row.getAttribute("data-name");
          if (expandedRows.has(name)) expandedRows.delete(name);
          else expandedRows.add(name);
          renderTable(items);
        });
      });
    }

    // Render Unsupported
    function renderUnsupported() {
      const grid = document.querySelector("#unsupported-grid");
      if (!unsupported.length) {
        document.querySelector("#unsupported-section").hidden = true;
        return;
      }
      grid.innerHTML = unsupported.map(item => `
        <div class="unsupported-card">
          <div class="unsupported-top">
            <span class="unsupported-name">${escapeHtml(item.name)}</span>
            <span class="unsupported-badge">Pending</span>
          </div>
          <div class="unsupported-meta">
            <span style="text-transform:capitalize;">Category: ${escapeHtml(item.category.replace(/_/g, " "))}</span>
            <span>·</span>
            <span>Profile: ${escapeHtml(item.profile)}</span>
          </div>
        </div>
      `).join("");
    }

    // Master Update
    function updateFilters() {
      renderCategories();
      const filtered = getFilteredBenchmarks();
      const sorted = sortBenchmarks(filtered);

      document.querySelector("#visible-status").textContent = `Showing ${sorted.length} of ${implemented.length} workloads`;

      const fastestPrismioCount = implemented.filter(b => median(b, "prismio") === Math.min(...languages.map(l => median(b, l)))).length;
      const parityCount = implemented.filter(b => {
        const cr = ratio(b, "cpp");
        const rr = ratio(b, "rust");
        return (cr >= 0.95 && cr <= 1.05) || (rr >= 0.95 && rr <= 1.05);
      }).length;
      document.querySelector("#count-all").textContent = implemented.length;
      document.querySelector("#count-win").textContent = fastestPrismioCount;
      document.querySelector("#count-parity").textContent = parityCount;
      document.querySelector("#count-loss").textContent = implemented.length - fastestPrismioCount;

      renderCharts(sorted);
      renderTable(sorted);
    }

    // Search and Filters Event Handlers
    const searchInput = document.querySelector("#search-input");
    const clearSearch = document.querySelector("#clear-search");
    searchInput.addEventListener("input", e => {
      currentSearch = e.target.value;
      clearSearch.classList.toggle("visible", Boolean(currentSearch));
      updateFilters();
    });
    clearSearch.addEventListener("click", () => {
      searchInput.value = "";
      currentSearch = "";
      clearSearch.classList.remove("visible");
      updateFilters();
    });

    document.querySelector("#profile-filter").addEventListener("change", e => {
      currentProfile = e.target.value;
      updateFilters();
    });

    document.querySelector("#sort-select").addEventListener("change", e => {
      currentSort = e.target.value;
      sortColumn = null;
      document.querySelectorAll("thead th").forEach(th => th.classList.remove("sort-asc", "sort-desc"));
      updateFilters();
    });

    // Chart Mode Switcher
    document.querySelectorAll("#chart-mode-tabs .tab-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        document.querySelectorAll("#chart-mode-tabs .tab-btn").forEach(b => {
          b.classList.remove("active");
          b.setAttribute("aria-selected", "false");
        });
        btn.classList.add("active");
        btn.setAttribute("aria-selected", "true");
        chartMode = btn.getAttribute("data-mode");
        const subtitles = {
          relative: "Direct workload comparison with winner highlighting and normalized scaling",
          absolute: "Exact execution durations displayed in nanoseconds, microseconds, or milliseconds",
          diverging: "Speedup and slowdown delta percentage of Prismio relative to C++ and Rust baselines"
        };
        document.querySelector("#chart-subtitle").textContent = subtitles[chartMode];
        updateFilters();
      });
    });

    // Outcome Filter Chips
    document.querySelectorAll('.chip[data-filter="outcome"]').forEach(chip => {
      chip.addEventListener("click", () => {
        document.querySelectorAll('.chip[data-filter="outcome"]').forEach(c => c.classList.remove("active"));
        chip.classList.add("active");
        currentOutcome = chip.getAttribute("data-val");
        updateFilters();
      });
    });

    // Grouping Toggle
    const toggleGroupingBtn = document.querySelector("#toggle-grouping-btn");
    toggleGroupingBtn.addEventListener("click", () => {
      isGrouped = !isGrouped;
      document.querySelector("#grouping-label").textContent = isGrouped ? "Group by Category" : "Show Flat List";
      toggleGroupingBtn.classList.toggle("btn-primary", isGrouped);
      updateFilters();
    });

    // Table Column Sorting
    document.querySelectorAll("thead th.sortable").forEach(th => {
      th.addEventListener("click", () => {
        const col = th.getAttribute("data-col");
        if (sortColumn === col) {
          sortDirection = sortDirection === "asc" ? "desc" : "asc";
        } else {
          sortColumn = col;
          sortDirection = "asc";
        }
        document.querySelectorAll("thead th").forEach(h => h.classList.remove("sort-asc", "sort-desc"));
        th.classList.add(sortDirection === "asc" ? "sort-asc" : "sort-desc");
        updateFilters();
      });
    });

    // Export Utilities
    document.querySelector("#copy-summary-btn").addEventListener("click", () => {
      const summaryMd = `### Prismio Performance Benchmark Summary
- **Overall vs C++ (Clang -O3)**: **${cppGeomean.toFixed(2)}×** (${cppGeomean <= 1 ? ((1 - cppGeomean) * 100).toFixed(1) + '% faster' : ((cppGeomean - 1) * 100).toFixed(1) + '% slower'})
- **Overall vs Rust (rustc opt-3)**: **${rustGeomean.toFixed(2)}×** (${rustGeomean <= 1 ? ((1 - rustGeomean) * 100).toFixed(1) + '% faster' : ((rustGeomean - 1) * 100).toFixed(1) + '% slower'})
- **Prismio Wins / Parity**: ${winsVsCpp + parityVsCpp}/${implemented.length} vs C++, ${winsVsRust + parityVsRust}/${implemented.length} vs Rust
- **Release Suite Build Time**: Prismio ${report.compile_ns ? duration(report.compile_ns.prismio) : 'cached'} | C++ ${report.compile_ns ? duration(report.compile_ns.cpp) : 'cached'} | Rust ${report.compile_ns ? duration(report.compile_ns.rust) : 'cached'}
- **Coverage**: ${implemented.length} implemented canonical workloads across 5 categories (${unsupported.length} pending).
- **Integrity**: 100% checksum consistency across all languages over ${report.runs} runs.`;
      navigator.clipboard.writeText(summaryMd).then(() => showToast("Summary markdown copied to clipboard!"));
    });

    document.querySelector("#copy-table-md-btn").addEventListener("click", () => {
      const items = sortBenchmarks(getFilteredBenchmarks());
      let md = `| Workload | Category | Profile | Prismio ns | C++ ns | Rust ns | vs C++ | vs Rust |\n|---|---|---|---:|---:|---:|---:|---:|\n`;
      items.forEach(item => {
        md += `| \`${item.name}\` | ${item.category} | ${item.profile} | ${median(item, "prismio")} | ${median(item, "cpp")} | ${median(item, "rust")} | ${ratio(item, "cpp").toFixed(2)}× | ${ratio(item, "rust").toFixed(2)}× |\n`;
      });
      navigator.clipboard.writeText(md).then(() => showToast("Table copied as Markdown!"));
    });

    document.querySelector("#copy-table-csv-btn").addEventListener("click", () => {
      const items = sortBenchmarks(getFilteredBenchmarks());
      let csv = "Workload,Category,Profile,Checksum,Prismio_ns,Cpp_ns,Rust_ns,Ratio_vs_Cpp,Ratio_vs_Rust\n";
      items.forEach(item => {
        csv += `"${item.name}","${item.category}","${item.profile}",${item.result},${median(item, "prismio")},${median(item, "cpp")},${median(item, "rust")},${ratio(item, "cpp").toFixed(3)},${ratio(item, "rust").toFixed(3)}\n`;
      });
      navigator.clipboard.writeText(csv).then(() => showToast("Table copied as CSV!"));
    });

    // Initial Render
    renderKPIs();
    renderCategories();
    renderUnsupported();
    updateFilters();
  </script>
</body>
</html>
'''
    path.write_text(template.replace("__REPORT_DATA__", embedded).replace("__RAW_FILE__", escape(raw_data_name)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", default=os.environ.get("PRISMIO"), help="Prismio compiler executable (or set PRISMIO)")
    parser.add_argument("--llvm-bin", help="LLVM bin directory prepended to PATH for Prismio and C++ builds")
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--only", action="append", metavar="NAME", help="run one benchmark; repeat the option for more")
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--output", type=Path, default=RESULTS / "results.json")
    parser.add_argument("--open", action="store_true", help="open the generated HTML report in the default browser")
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text())
    selected = select_benchmarks(manifest, args.only)
    if args.list:
        for item in selected:
            print("{category:16} {status:11} {name}".format(**item))
        return
    if args.runs < 1:
        sys.exit("--runs must be positive")
    if not args.skip_build and not args.compiler:
        sys.exit("--compiler is required (or set PRISMIO)")

    build_steps = 0 if args.skip_build else len(LANGUAGES)
    workload_steps = sum(1 if item["status"] == "unsupported" else args.runs * len(LANGUAGES)
                         for item in selected)
    artifact_steps = 2
    progress = Progress(build_steps + workload_steps + artifact_steps)
    progress.show("Preparing benchmark suite")

    build_commands = None
    compile_ns = None
    if not args.skip_build:
        build_commands, compile_ns = build_all(args, progress)
    executables = {language: BUILD / (language + "-suite") for language in LANGUAGES}
    missing = [str(path) for path in executables.values() if not path.exists()]
    if missing:
        sys.exit("missing built executable(s): " + ", ".join(missing))

    report = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "runs": args.runs,
        "build_commands": {key: command_text(value) for key, value in (build_commands or {}).items()},
        "compile_ns": compile_ns,
        "benchmarks": [],
    }
    with tempfile.TemporaryDirectory(prefix="prismio-bench-") as temp_name:
        temp = Path(temp_name)
        fixture = make_fixture(temp)
        for item in selected:
            if item["status"] == "unsupported":
                report["benchmarks"].append(dict(item))
                progress.advance("Skipped {} (unsupported)".format(item["name"]))
                continue
            samples = {language: [] for language in LANGUAGES}
            expected = None
            for run_index in range(args.runs):
                for language in LANGUAGES:
                    progress.show("{} · run {}/{} · {}".format(
                        item["name"], run_index + 1, args.runs, LANGUAGE_LABELS[language]))
                    output_path = temp / "{}-{}-{}.txt".format(item["name"], language, run_index)
                    fields = execute(executables[language], item["name"], fixture, output_path)
                    if expected is None:
                        expected = fields["result"]
                    elif fields["result"] != expected:
                        raise RuntimeError("checksum mismatch for {}: expected {}, {} returned {}".format(
                            item["name"], expected, language, fields["result"]))
                    samples[language].append(fields)
                    progress.advance("{} · run {}/{} · {}".format(
                        item["name"], run_index + 1, args.runs, LANGUAGE_LABELS[language]))
            measured = dict(item)
            measured["result"] = expected
            measured["languages"] = {}
            for language in LANGUAGES:
                measured["languages"][language] = {
                    "elapsed_ns_median": int(statistics.median(sample["elapsed_ns"] for sample in samples[language])),
                    "wall_ns_median": int(statistics.median(sample["wall_ns"] for sample in samples[language])),
                    "elapsed_ns_samples": [sample["elapsed_ns"] for sample in samples[language]],
                }
            report["benchmarks"].append(measured)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    html_path = args.output.parent / "report.html"
    report["artifacts"] = {
        "html_report": str(html_path),
        "raw_data": str(args.output),
    }
    progress.show("Writing JSON results")
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    progress.advance("Wrote JSON results")
    progress.show("Rendering HTML report")
    write_html_report(report, html_path, args.output.name)
    progress.advance("Complete")
    progress.finish()

    implemented = len(measured_benchmarks(report))
    unsupported = sum(item["status"] == "unsupported" for item in report["benchmarks"])
    sample_text = "1 run" if args.runs == 1 else "{} runs".format(args.runs)
    print("Completed {} benchmarks ({} unsupported) · {}".format(
        implemented, unsupported, sample_text))
    print("Report   " + str(html_path))
    print("Data     " + str(args.output))
    if args.open:
        webbrowser.open(html_path.resolve().as_uri())


if __name__ == "__main__":
    main()
