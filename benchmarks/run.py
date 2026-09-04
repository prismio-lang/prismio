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
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <title>Prismio benchmark report</title>
  <style>
    :root {
      --ink: #f4f7fb;
      --muted: #8e99a9;
      --faint: #596373;
      --canvas: #090c10;
      --surface: #10151c;
      --surface-raised: #151c25;
      --line: #26303d;
      --prismio: #47d7b5;
      --cpp: #ffb454;
      --rust: #a991ff;
      --danger: #ff7d7d;
    }
    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    body {
      margin: 0;
      background: var(--canvas);
      color: var(--ink);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 15px;
      line-height: 1.5;
    }
    body::before {
      content: "";
      position: fixed;
      inset: 0 0 auto;
      height: 3px;
      background: linear-gradient(90deg, var(--prismio), var(--cpp) 52%, var(--rust));
      z-index: 20;
    }
    a { color: inherit; }
    button, input, select { font: inherit; }
    .shell { width: min(1480px, calc(100% - 48px)); margin: 0 auto; }
    header { padding: 76px 0 42px; border-bottom: 1px solid var(--line); }
    .title-row { display: flex; align-items: end; justify-content: space-between; gap: 32px; }
    h1 { margin: 0; font-size: clamp(2.4rem, 5vw, 5rem); line-height: .96; letter-spacing: -.04em; }
    .lede { margin: 20px 0 0; max-width: 68ch; color: var(--muted); font-size: 1rem; }
    .raw-link {
      display: inline-flex; align-items: center; min-height: 42px; padding: 0 16px;
      border: 1px solid var(--line); border-radius: 12px; text-decoration: none;
      color: var(--muted); white-space: nowrap; transition: color 160ms ease, border-color 160ms ease;
    }
    .raw-link:hover, .raw-link:focus-visible { color: var(--ink); border-color: #566275; }
    .run-strip {
      display: grid; grid-template-columns: repeat(3, minmax(0, 1fr));
      margin-top: 44px; border-top: 1px solid var(--line); border-bottom: 1px solid var(--line);
    }
    .run-fact { padding: 18px 0; }
    .run-fact + .run-fact { padding-left: 24px; border-left: 1px solid var(--line); }
    .run-fact span { display: block; color: var(--faint); font-size: 11px; letter-spacing: .08em; text-transform: uppercase; }
    .run-fact strong { display: block; margin-top: 5px; font: 600 15px ui-monospace, SFMono-Regular, Menlo, monospace; }
    main { padding: 48px 0 96px; }
    .toolbar {
      position: sticky; top: 0; z-index: 10; display: grid;
      grid-template-columns: minmax(220px, 1fr) 210px 250px; gap: 10px;
      padding: 12px 0; background: color-mix(in srgb, var(--canvas) 94%, transparent);
      backdrop-filter: blur(14px); border-bottom: 1px solid var(--line);
    }
    .control {
      width: 100%; height: 44px; padding: 0 14px; color: var(--ink);
      background: var(--surface); border: 1px solid var(--line); border-radius: 12px; outline: none;
    }
    .control:focus { border-color: var(--prismio); box-shadow: 0 0 0 3px rgb(71 215 181 / .12); }
    section { margin-top: 64px; }
    .section-head { display: flex; align-items: end; justify-content: space-between; gap: 24px; margin-bottom: 22px; }
    h2 { margin: 0; font-size: clamp(1.5rem, 3vw, 2.4rem); letter-spacing: -.03em; }
    .section-note { margin: 0; color: var(--muted); text-align: right; }
    .legend { display: flex; flex-wrap: wrap; gap: 18px; margin: 18px 0 4px; color: var(--muted); font-size: 13px; }
    .legend span { display: inline-flex; align-items: center; gap: 7px; }
    .swatch { width: 9px; height: 9px; border-radius: 3px; }
    .chart { border-top: 1px solid var(--line); }
    .bench-row {
      display: grid; grid-template-columns: 260px minmax(0, 1fr); gap: 28px;
      padding: 24px 0; border-bottom: 1px solid var(--line);
    }
    .bench-name { font: 600 14px ui-monospace, SFMono-Regular, Menlo, monospace; overflow-wrap: anywhere; }
    .bench-category { margin-top: 5px; color: var(--faint); font-size: 12px; text-transform: capitalize; }
    .bars { display: grid; gap: 8px; }
    .bar-line { display: grid; grid-template-columns: 68px minmax(0, 1fr) 130px; gap: 12px; align-items: center; min-width: 0; }
    .language { color: var(--muted); font-size: 12px; }
    .track { position: relative; height: 10px; background: #171e28; border-radius: 3px; overflow: hidden; }
    .bar { height: 100%; width: var(--width); border-radius: inherit; transform-origin: left; animation: reveal 650ms cubic-bezier(.16, 1, .3, 1) both; }
    .bar.prismio { background: var(--prismio); }
    .bar.cpp { background: var(--cpp); }
    .bar.rust { background: var(--rust); }
    .bar-value { color: var(--muted); font: 11px ui-monospace, SFMono-Regular, Menlo, monospace; white-space: nowrap; }
    @keyframes reveal { from { transform: scaleX(.02); filter: saturate(.5); } }
    .table-wrap { overflow-x: auto; border-top: 1px solid var(--line); border-bottom: 1px solid var(--line); }
    table { width: 100%; min-width: 1040px; border-collapse: collapse; font-variant-numeric: tabular-nums; }
    th { padding: 13px 14px; color: var(--muted); font-size: 11px; font-weight: 600; letter-spacing: .05em; text-align: right; text-transform: uppercase; }
    th:first-child, td:first-child { padding-left: 0; text-align: left; }
    td { padding: 13px 14px; border-top: 1px solid #1c2430; text-align: right; font: 12px ui-monospace, SFMono-Regular, Menlo, monospace; }
    td:first-child { color: var(--ink); font-weight: 600; }
    .p { color: var(--prismio); } .c { color: var(--cpp); } .r { color: var(--rust); }
    .ratio-good { color: var(--prismio); } .ratio-bad { color: var(--danger); }
    .unsupported { border-top: 1px solid var(--line); }
    .unsupported-row { display: grid; grid-template-columns: 260px 1fr; gap: 28px; padding: 18px 0; border-bottom: 1px solid var(--line); }
    .unsupported-row code { color: var(--muted); }
    .unsupported-row span { color: var(--faint); }
    .empty { padding: 48px 0; color: var(--muted); border-bottom: 1px solid var(--line); }
    footer { padding: 28px 0 56px; color: var(--faint); font-size: 12px; border-top: 1px solid var(--line); }
    @media (max-width: 780px) {
      .shell { width: min(100% - 28px, 1480px); }
      header { padding-top: 56px; }
      .title-row, .section-head { align-items: start; flex-direction: column; }
      .section-note { text-align: left; }
      .run-strip { grid-template-columns: 1fr 1fr; }
      .run-fact:nth-child(3) { padding-left: 0; border-left: 0; border-top: 1px solid var(--line); }
      .run-fact:nth-child(4) { border-top: 1px solid var(--line); }
      .toolbar { grid-template-columns: 1fr; position: static; }
      .bench-row, .unsupported-row { grid-template-columns: 1fr; gap: 14px; }
      .bar-line { grid-template-columns: 58px minmax(90px, 1fr) 112px; gap: 8px; }
    }
    @media (prefers-reduced-motion: reduce) { html { scroll-behavior: auto; } .bar { animation: none; } }
  </style>
</head>
<body>
  <!--
  THESIS: Benchmark evidence should read like an instrument panel, not a pile of exported charts.
  OWN-WORLD: Near-black measurement surface, restrained rules, and one distinct color per language.
  STORY: Scan the run, compare relative performance, inspect exact timings, then reach raw evidence.
  FIRST VIEWPORT: Run identity and metadata lead; filtering stays close to the comparison field.
  FORM: A self-contained, dependency-free developer report generated directly from benchmark truth.
  -->
  <header>
    <div class="shell">
      <div class="title-row">
        <div>
          <h1>Benchmark report</h1>
          <p class="lede">A cross-language view of Prismio, C++, and Rust. Each benchmark runs one canonical workload for directly comparable results.</p>
        </div>
        <a class="raw-link" href="__RAW_FILE__">Open raw JSON</a>
      </div>
      <div class="run-strip" id="run-strip"></div>
    </div>
  </header>
  <main class="shell">
    <div class="toolbar" aria-label="Report controls">
      <input class="control" id="search" type="search" placeholder="Filter benchmarks…" aria-label="Filter benchmarks">
      <select class="control" id="category" aria-label="Filter by category"></select>
      <select class="control" id="sort" aria-label="Sort benchmarks">
        <option value="catalog">Catalog order</option>
        <option value="prismio">Prismio duration</option>
        <option value="cpp-ratio">Prismio vs C++</option>
        <option value="rust-ratio">Prismio vs Rust</option>
      </select>
    </div>

    <section aria-labelledby="comparison-title">
      <div class="section-head">
        <h2 id="comparison-title">Relative performance</h2>
        <p class="section-note"><span id="visible-count"></span> · logarithmic slowdown from each workload’s fastest result</p>
      </div>
      <div class="legend">
        <span><i class="swatch" style="background:var(--prismio)"></i>Prismio</span>
        <span><i class="swatch" style="background:var(--cpp)"></i>C++</span>
        <span><i class="swatch" style="background:var(--rust)"></i>Rust</span>
      </div>
      <div class="chart" id="chart"></div>
    </section>

    <section aria-labelledby="precise-title">
      <div class="section-head">
        <h2 id="precise-title">Precise timings</h2>
        <p class="section-note">Exact median nanoseconds and Prismio comparison ratios</p>
      </div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Benchmark</th><th>Checksum</th><th>Prismio ns</th><th>C++ ns</th><th>Rust ns</th><th>vs C++</th><th>vs Rust</th></tr></thead>
          <tbody id="timings"></tbody>
        </table>
      </div>
    </section>

    <section id="unsupported-section" aria-labelledby="unsupported-title">
      <div class="section-head">
        <h2 id="unsupported-title">Currently unsupported</h2>
        <p class="section-note">Retained in the catalog; omitted from execution</p>
      </div>
      <div class="unsupported" id="unsupported"></div>
    </section>
  </main>
  <footer><div class="shell" id="footer-copy"></div></footer>

  <script>
    const report = __REPORT_DATA__;
    const languages = ["prismio", "cpp", "rust"];
    const labels = {prismio: "Prismio", cpp: "C++", rust: "Rust"};
    const implemented = report.benchmarks.filter(item => item.status === "implemented");
    const unsupported = report.benchmarks.filter(item => item.status === "unsupported");
    const median = (item, language) => item.languages[language].elapsed_ns_median;
    const ratio = (item, baseline) => median(item, "prismio") / Math.max(median(item, baseline), 1);
    const escapeHtml = value => String(value).replace(/[&<>'"]/g, character => ({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;",'"':"&quot;"})[character]);
    const exact = value => Number(value).toLocaleString("en-US");
    const duration = value => {
      if (value >= 1e9) return `${(value / 1e9).toFixed(3)} s`;
      if (value >= 1e6) return `${(value / 1e6).toFixed(3)} ms`;
      if (value >= 1e3) return `${(value / 1e3).toFixed(3)} µs`;
      return `${value} ns`;
    };
    const runStrip = document.querySelector("#run-strip");
    const buildText = report.compile_ns
      ? languages.map(language => `${labels[language]} ${duration(report.compile_ns[language])}`).join(" · ")
      : "Reused existing binaries";
    runStrip.innerHTML = [
      ["Samples", report.runs === 1 ? "1 run" : `${report.runs} runs`],
      ["Coverage", `${implemented.length} implemented / ${unsupported.length} unsupported`],
      ["Build", buildText],
    ].map(([label, value]) => `<div class="run-fact"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>`).join("");

    const category = document.querySelector("#category");
    const categories = [...new Set(implemented.map(item => item.category))];
    category.innerHTML = `<option value="all">All categories</option>` + categories.map(value =>
      `<option value="${escapeHtml(value)}">${escapeHtml(value.replaceAll("_", " "))}</option>`).join("");

    function selectedRows() {
      const query = document.querySelector("#search").value.trim().toLowerCase();
      const chosenCategory = category.value;
      const order = document.querySelector("#sort").value;
      const rows = implemented.filter(item =>
        (chosenCategory === "all" || item.category === chosenCategory) &&
        (!query || item.name.toLowerCase().includes(query)));
      if (order === "prismio") rows.sort((a, b) => median(b, "prismio") - median(a, "prismio"));
      if (order === "cpp-ratio") rows.sort((a, b) => ratio(b, "cpp") - ratio(a, "cpp"));
      if (order === "rust-ratio") rows.sort((a, b) => ratio(b, "rust") - ratio(a, "rust"));
      return rows;
    }

    function render() {
      const rows = selectedRows();
      document.querySelector("#visible-count").textContent = `${rows.length} shown`;
      const allRatios = rows.flatMap(item => {
        const fastest = Math.max(Math.min(...languages.map(language => median(item, language))), 1);
        return languages.map(language => median(item, language) / fastest);
      });
      const maxRatio = Math.max(...allRatios, 2);
      const scale = value => 4 + 96 * Math.log2(Math.max(value, 1)) / Math.log2(maxRatio);
      document.querySelector("#chart").innerHTML = rows.length ? rows.map(item => {
        const fastest = Math.max(Math.min(...languages.map(language => median(item, language))), 1);
        const bars = languages.map(language => {
          const value = median(item, language);
          const relative = value / fastest;
          return `<div class="bar-line"><span class="language">${labels[language]}</span><div class="track"><div class="bar ${language}" style="--width:${scale(relative).toFixed(2)}%"></div></div><span class="bar-value">${relative.toFixed(2)}× · ${duration(value)}</span></div>`;
        }).join("");
        return `<article class="bench-row"><div><div class="bench-name">${escapeHtml(item.name)}</div><div class="bench-category">${escapeHtml(item.category.replaceAll("_", " "))}</div></div><div class="bars">${bars}</div></article>`;
      }).join("") : `<div class="empty">No benchmarks match this filter.</div>`;

      document.querySelector("#timings").innerHTML = rows.map(item => {
        const cppRatio = ratio(item, "cpp");
        const rustRatio = ratio(item, "rust");
        const ratioCell = value => `<td class="${value <= 1 ? "ratio-good" : "ratio-bad"}">${value.toFixed(3)}×</td>`;
        return `<tr><td>${escapeHtml(item.name)}</td><td>${exact(item.result)}</td><td class="p">${exact(median(item, "prismio"))}</td><td class="c">${exact(median(item, "cpp"))}</td><td class="r">${exact(median(item, "rust"))}</td>${ratioCell(cppRatio)}${ratioCell(rustRatio)}</tr>`;
      }).join("");
    }

    document.querySelector("#unsupported").innerHTML = unsupported.length ? unsupported.map(item =>
      `<div class="unsupported-row"><code>${escapeHtml(item.name)}</code><span>${escapeHtml(item.category.replaceAll("_", " "))}</span></div>`).join("") : `<div class="empty">Every selected benchmark is supported.</div>`;
    document.querySelector("#unsupported-section").hidden = unsupported.length === 0;
    document.querySelector("#footer-copy").textContent = `Generated ${new Date(report.generated_at).toLocaleString()} · schema ${report.schema_version} · lower timing is better`;
    document.querySelectorAll("#search, #category, #sort").forEach(control => control.addEventListener("input", render));
    render();
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
