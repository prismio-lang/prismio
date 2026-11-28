"""The `tooling` suite's harness tests (the design record, section 4; see tools/testkit/__init__.py)."""
import io
import contextlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace

from harness.common import *


@harness_test(suite="tooling")
def run_check_overlay_test():
    """`check --overlay` and `--module`: one file of a program, checked as the editor sees it.

    A module is not a program. Its imports resolve against the entry's directory, and it may
    use a name its program shares without importing it -- src/parse/stmt.psm uses `Parser` --
    so an editor that checked the file alone showed errors that are not there (the first
    assertion reproduces that). Checked through the program, with the unsaved text overlaid,
    it is clean; an error typed into the buffer is reported on the file's own path and line;
    an import cycle back to it does not merge it twice; and a program that never reaches it
    says so with P1075 rather than calling it clean.
    """
    print(f"\n{BLUE}--- Running check_overlay ---{RESET}")
    problems = []

    def check(*args):
        result = run_command([str(PRISMIO_EXE), "check", *[str(a) for a in args]])
        records = [json.loads(line) for line in result.stderr.splitlines() if line.startswith("{")]
        return result.returncode, [r for r in records if r.get("kind") == "diagnostic"]

    with tempfile.TemporaryDirectory(prefix="prismio-overlay-") as tmp:
        root = Path(tmp).resolve()
        (root / "src" / "util").mkdir(parents=True)
        main = root / "src" / "main.psm"
        main.write_text("import std.io\nimport util.shapes\n\n"
                        "fn main() -> Int {\n    println(doubled(Shape { w: 2, h: 3 }))\n    return 0\n}\n")
        (root / "src" / "util" / "shapes.psm").write_text(
            "import util.area\n\npublic struct Shape { public w: Int, public h: Int }\n\n"
            "public fn doubled(s: Shape) -> Int { return 2 * areaOf(s) }\n")
        area = root / "src" / "util" / "area.psm"
        # Uses `Shape` without importing util.shapes, and is reached through a cycle.
        area.write_text("public fn areaOf(s: Shape) -> Int {\n    return s.w * s.h\n}\n")
        other = root / "other.psm"
        other.write_text("fn main() -> Int { return 0 }\n")
        buffer = root / "buffer.psm"

        code, alone = check(area, "--diagnostic-format=json")
        if code == 0 or not any(d.get("severity") == "error" for d in alone):
            problems.append(f"checked alone, area.psm should not resolve `Shape`: {alone}")

        buffer.write_text(area.read_text())
        code, clean = check(main, "--diagnostic-format=json", "--overlay", area, buffer)
        if code != 0 or clean:
            problems.append(f"through its program, the unchanged module is not clean: {clean}")

        buffer.write_text("public fn areaOf(s: Shape) -> Int {\n    return s.w * \"wide\"\n}\n")
        code, edited = check(main, "--diagnostic-format=json", "--overlay", area, buffer)
        placed = [d for d in edited if d.get("severity") == "error" and d.get("file") == str(area) and d.get("line") == 2]
        if code == 0 or not placed:
            problems.append(f"the unsaved error is not reported on area.psm line 2: {edited}")
        if any(d.get("file") == str(buffer) for d in edited):
            problems.append("a diagnostic names the buffer instead of the file")

        # One file spelled two ways: the entry relative to the working directory, the
        # overlay absolute, as a person typing the command may well write them.
        buffer.write_text(area.read_text())
        mixed = subprocess.run([str(PRISMIO_EXE), "check", "src/main.psm", "--diagnostic-format=json",
                                "--overlay", str(area), str(buffer)], cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if mixed.returncode != 0 or "P1075" in mixed.stderr:
            problems.append(f"a relative entry did not match the absolute overlay: {mixed.stderr.strip()[:300]}")

        code, unread = check(other, "--diagnostic-format=json", "--overlay", area, buffer)
        if not any(d.get("code") == "P1075" for d in unread):
            problems.append(f"a program that never reads the file did not say so: {unread}")

        code, missing = check(main, "--diagnostic-format=json", "--overlay", area)
        if code == 0 or not any(d.get("code") == "P1073" for d in missing):
            problems.append(f"`--overlay` with one path was accepted: {missing}")
        code, missing = check(main, "--diagnostic-format=json", "--module")
        if code == 0 or not any(d.get("code") == "P1076" for d in missing):
            problems.append(f"`--module` with no name was accepted: {missing}")

    std_map = PROJECT_ROOT / "std" / "collections" / "map.psm"
    code, as_module = check(std_map, "--diagnostic-format=json", "--module", "std.collections.map")
    if code != 0 or as_module:
        problems.append(f"std/collections/map.psm as std.collections.map is not clean: {as_module[:2]}")
    code, as_program = check(std_map, "--diagnostic-format=json")
    if code == 0:
        problems.append("std/collections/map.psm checked as a program of its own reached the standard library's internals")

    if problems:
        print(f"{RED}[FAIL] check overlay{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] a module is checked through its program, with the editor's text overlaid{RESET}")
    return True


@harness_test(suite="tooling", resources={"mem": 500}, timeout=300)
def run_check_partial_test():
    """`check --partial`: type checking over a program the parser could only partly read.

    Without it a syntax error ends the analysis, so an editor shows nothing about the rest of
    the file while one declaration is half typed. With it, the declarations that parsed are
    checked, and an "unknown ..." error that only exists because text was dropped is held back
    -- the cascade, not the finding. The default must not change: a plain `check` still stops
    at the syntax error, and so does `build`.
    """
    print(f"\n{BLUE}--- Running check_partial ---{RESET}")
    problems = []

    def check(path, *flags):
        result = run_command([str(PRISMIO_EXE), "check", str(path), "--diagnostic-format=json", *flags])
        records = [json.loads(line) for line in result.stderr.splitlines() if line.startswith("{")]
        errors = [r["message"] for r in records if r.get("kind") == "diagnostic" and r.get("severity") == "error"]
        return result.returncode, errors

    def mentions(errors, text):
        return any(text in message for message in errors)

    with tempfile.TemporaryDirectory(prefix="prismio-partial-") as tmp:
        root = Path(tmp).resolve()

        # `helper` does not parse and is dropped; `typo` has a real type error; `uses` calls both
        # the dropped function (a cascade) and one that never existed (a finding).
        broken = root / "broken.psm"
        broken.write_text(
            "import std.io\n\n"
            "fn helper(x: Int) -> Int {\n    return x +\n}\n\n"
            "fn typo() -> Int {\n    let n: Int = \"text\"\n    return n\n}\n\n"
            "fn uses() -> Int {\n    return helper(1) + missing(2)\n}\n\n"
            "fn main() -> Int {\n    println(uses())\n    return typo()\n}\n")

        code, errors = check(broken)
        if code == 0 or len(errors) != 1 or not mentions(errors, "expected an expression"):
            problems.append(f"plain check should stop at the one syntax error: {errors}")

        code, errors = check(broken, "--partial")
        if code == 0:
            problems.append("--partial accepted a program with errors")
        if not mentions(errors, "expected an expression"):
            problems.append(f"--partial lost the syntax error: {errors}")
        if not mentions(errors, "expected Int, found String"):
            problems.append(f"--partial did not type-check the declarations that parsed: {errors}")
        if not mentions(errors, "unknown function `missing`"):
            problems.append(f"--partial hid a real unknown name: {errors}")
        if mentions(errors, "unknown function `helper`"):
            problems.append(f"--partial reported the dropped declaration as unknown: {errors}")
        if mentions(errors, "requires numeric operands"):
            problems.append(f"--partial blamed the operator for an operand that already failed: {errors}")

        # A broken method drops itself, not its `impl`: the methods around it are still read and
        # checked, and the trait it was meant to satisfy is not blamed for the method it lost.
        members = root / "members.psm"
        members.write_text(
            "import std.io\n\n"
            "trait Named { fn name(self) -> Int }\n"
            "struct Counter { n: Int }\n\n"
            "impl Named for Counter {\n    fn name(self) -> Int {\n        return 7 +\n    }\n}\n\n"
            "impl Counter {\n"
            "    fn first(self) -> Int {\n        let n: Int = \"text\"\n        return n\n    }\n"
            "    fn broken(self, {\n        return 1\n    }\n"
            "    fn last(self) -> Int {\n        return self.first() + self.broken()\n    }\n}\n\n"
            "fn main() -> Int {\n    let c = Counter { n: 1 }\n    println(c.last())\n    return 0\n}\n")
        code, errors = check(members, "--partial")
        if not mentions(errors, "parameter name") or not mentions(errors, "expected an expression"):
            problems.append(f"--partial lost a syntax error inside an impl: {errors}")
        if not mentions(errors, "expected Int, found String"):
            problems.append(f"--partial did not check the method before the broken one: {errors}")
        if mentions(errors, "unknown function `first`") or mentions(errors, "unknown function `last`"):
            problems.append(f"--partial lost a method that parsed: {errors}")
        if mentions(errors, "does not implement"):
            problems.append(f"--partial blamed the impl for the method it dropped: {errors}")
        if mentions(errors, "unknown function `broken`"):
            problems.append(f"--partial reported the dropped method as unknown: {errors}")

        # A statement that does not parse drops itself, not the function around it: the lines before and after it
        # are checked, a name only the dropped statement declared is not blamed, and a function whose last
        # statement was the `return` is not reported as falling off its end.
        statements = root / "statements.psm"
        statements.write_text(
            "import std.io\n\n"
            "fn tail() -> Int {\n    let k = 4\n    return k +\n}\n\n"
            "fn middle(v: Int) -> Int {\n    let bad = v +\n    let n: Int = \"text\"\n    println(bad)\n"
            "    if (v > 1 {\n        println(v)\n    }\n    return missing(v)\n}\n\n"
            "fn main() -> Int {\n    return tail() + middle(1)\n}\n")
        code, errors = check(statements)
        if len(errors) != 3 or not all(mentions([e], "expected") for e in errors):
            problems.append(f"plain check should report all three syntax errors, `middle`'s two included, and stop: {errors}")
        code, errors = check(statements, "--partial")
        if sum(1 for e in errors if "expected an expression" in e or "parenthesized expression" in e) != 3:
            problems.append(f"--partial lost a syntax error: {errors}")
        if not mentions(errors, "expected Int, found String"):
            problems.append(f"--partial did not check the statement after the broken one: {errors}")
        if not mentions(errors, "unknown function `missing`"):
            problems.append(f"--partial hid a real unknown name after a dropped statement: {errors}")
        if mentions(errors, "unknown identifier `bad`"):
            problems.append(f"--partial reported a name the dropped statement declared: {errors}")
        if mentions(errors, "must return"):
            problems.append(f"--partial blamed a function for the `return` it lost: {errors}")

        # An import that cannot be read: any name may have come from it, so no "unknown" is
        # trustworthy -- but a type error is still one.
        lost = root / "lost.psm"
        lost.write_text(
            "import std.io\nimport no_such_module\n\n"
            "fn main() -> Int {\n    let n: Int = \"text\"\n    println(from_the_missing_module(n))\n    return 0\n}\n")
        code, errors = check(lost, "--partial")
        if not mentions(errors, "cannot read imported module"):
            problems.append(f"--partial lost the import error: {errors}")
        if not mentions(errors, "expected Int, found String"):
            problems.append(f"--partial did not type-check past an unreadable import: {errors}")
        if mentions(errors, "unknown function"):
            problems.append(f"--partial blamed the program for a name the lost import may provide: {errors}")

        # Nothing wrong means nothing said, with or without the flag.
        fine = root / "fine.psm"
        fine.write_text("import std.io\n\nfn main() -> Int {\n    println(1)\n    return 0\n}\n")
        for flags in ((), ("--partial",)):
            code, errors = check(fine, *flags)
            if code != 0 or errors:
                problems.append(f"a valid program was rejected with {flags}: {errors}")

        # An unknown name inside arithmetic is one error, not two.
        sums = root / "sums.psm"
        sums.write_text("fn main() -> Int {\n    return foo(1) + bar(2)\n}\n")
        code, errors = check(sums)
        if len(errors) != 2 or mentions(errors, "requires numeric operands"):
            problems.append(f"an unresolved operand should be reported once, not again as an operator error: {errors}")

    if problems:
        print(f"{RED}[FAIL] check --partial{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] --partial type-checks what parsed and holds back errors the dropped text caused{RESET}")
    return True


@harness_test(suite="tooling",
              reads=["src/**"])
def run_token_tables_test():
    """`prismio dump-tokens`: the vocabulary an editor copies, and the copies.

    The compiler's lexical tables are exported once so no editor has to keep its own. Three
    things are held to it:

    - the export is well formed and not empty (a table that printed nothing would let every
      check below pass),
    - every word the parser compares an identifier with is in it, which is what keeps the table
      from drifting behind the grammar (the contextual keywords are spelled in the parser, so
      the table cannot be derived from it and this is the guard),
    - the IntelliJ plugin's hand-written word tables, when its checkout is beside this one,
      list exactly the same words.
    """
    print(f"\n{BLUE}--- Running token_tables ---{RESET}")
    problems = []
    result = run_command([str(PRISMIO_EXE), "dump-tokens"])
    try:
        tables = json.loads(result.stdout)
    except ValueError:
        print(f"{RED}[FAIL] token_tables{RESET}\n  dump-tokens printed no JSON: {result.stdout[:200]!r} {result.stderr[:200]!r}")
        return False

    keywords = set(tables["keywords"])
    contextual = {entry["word"] for entry in tables["contextualKeywords"]}
    types = tables["types"]
    if len(keywords) < 30 or len(contextual) < 30 or len(tables["operators"]) < 25 or len(tables["separators"]) < 10:
        problems.append("dump-tokens exported too little to be the language's vocabulary")
    if len(contextual) != len(tables["contextualKeywords"]):
        problems.append("a contextual keyword is listed twice")
    if keywords & contextual:
        problems.append(f"reserved and contextual at once: {sorted(keywords & contextual)}")
    if any(not entry["context"] for entry in tables["contextualKeywords"]):
        problems.append("a contextual keyword has no context")
    if not all(types[kind] for kind in ("integer", "float", "other")):
        problems.append("a type family is empty")

    # Every identifier spelling the parser tests against is a contextual word.
    import re
    compared = set()
    for source in (PROJECT_ROOT / "src" / "parse").glob("*.psm"):
        text = source.read_text()
        compared.update(re.findall(r'(?:checkVal|matchVal|expectVal)\(TokenType\.IDENTIFIER, *"(\w+)"', text))
        compared.update(re.findall(r'\.value\.equals\("(\w+)"\)', text))
    # Words that are reserved, are an operator spelling, or are not language words at all.
    known = keywords | set(tables["wordOperators"]) | {"_"}
    missing = sorted(w for w in compared if w not in known and w not in contextual)
    if not compared:
        problems.append("found no identifier comparisons in src/parse: the scan is vacuous")
    if missing:
        problems.append(f"the parser compares identifiers with words the token table lacks: {missing}")

    # The IntelliJ plugin's copy, if it is checked out beside this repository.
    words_java = PROJECT_ROOT.parent / "jetbrains-plugin" / "src/main/java/io/prismio/lang/PrismioWords.java"
    if words_java.exists():
        java = words_java.read_text()

        def java_set(name):
            body = re.search(name + r"\s*=\s*Set\.of\((.*?)\);", java, re.S).group(1)
            body = re.sub(r"/\*.*?\*/|//[^\n]*", "", body, flags=re.S)
            return set(re.findall(r'"(\w+)"', body))

        # Words the plugin's lexer reads as plain names on purpose, or does not know yet. Listed
        # so a new word cannot be left out by accident, and so the list shrinks when the plugin
        # learns one: a word here that the plugin does highlight is itself reported. (`codeset`,
        # `typelist`, `workload`, `setup` and `measure` were here until the plugin learned them.)
        plugin_plain = {"C", "Fn", "always", "never"}
        plugin_gaps = set()
        for name, expected in (
            ("KEYWORDS", keywords),
            ("CONTEXTUAL_KEYWORDS", contextual - plugin_plain - plugin_gaps),
            ("BUILTIN_TYPES", set(types["integer"]) | set(types["float"]) | set(types["other"])),
        ):
            have = java_set(name)
            if name == "CONTEXTUAL_KEYWORDS" and have & (plugin_plain | plugin_gaps):
                problems.append(f"the plugin now knows {sorted(have & (plugin_plain | plugin_gaps))}: take them off the allowance")
            if have != expected:
                problems.append(f"plugin {name} disagrees with dump-tokens: "
                                f"only in the plugin {sorted(have - expected)}, only in the compiler {sorted(expected - have)}")
    else:
        print(f"  (the IntelliJ plugin is not beside this checkout; its tables were not compared)")

    if problems:
        print(f"{RED}[FAIL] token_tables{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] dump-tokens exports the vocabulary, the parser stays inside it{RESET}")
    return True


@harness_test(suite="tooling", resources={"cpu": 2, "mem": 800})
def run_fmt_test():
    """`prismio fmt`: the formatter, held to the rules it was written from and to the repository.

    The cases are the IntelliJ plugin's formatter tests, which is where the rules came from; each
    was a change the old formatter made to the compiler's own source, and is kept as the proof the
    new one does not. Then the whole of it is run over every source in the checkout
    (tools/check_fmt.py: whitespace only, settles, damaged copies, IR unchanged), the flags are
    exercised, and the ranges leave the rest of the file alone.
    """
    print(f"\n{BLUE}--- Running fmt ---{RESET}")
    problems = []

    def fmt(text, *flags):
        # Bytes in and out: the text mode would turn CRLF into LF on the way and hide what is tested.
        result = subprocess.run([str(PRISMIO_EXE), "fmt", "--stdin", *flags], input=text.encode("utf-8"),
                                capture_output=True)
        if result.returncode != 0:
            return f"<exit {result.returncode}: {result.stderr[:120]!r}>"
        return result.stdout.decode("utf-8")

    cases = [
        # Word operators and keywords after an operand keep their spaces.
        ("let ok = a and b\n", "let ok = a and b\n"),
        ("let ok = a and b or c\n", "let ok = a and b or c\n"),
        ("let n = value as Int\n", "let n = value as Int\n"),
        ("for item in items { }\n", "for item in items { }\n"),
        # `default` is a name after `.` and `fn`, a keyword elsewhere.
        ("let c = Config.default()\n", "let c = Config.default()\n"),
        ("fn default() -> Self { }\n", "fn default() -> Self { }\n"),
        ("let c: Config = default\n", "let c: Config = default\n"),
        # Labels, ranges, step and repeat.
        ("outer@ for i in 0..<n { break@outer }\n", "outer@ for i in 0..<n { break@outer }\n"),
        ("for i in 10..0 step 2 { }\n", "for i in 10..0 step 2 { }\n"),
        ("repeat(3) { }\n", "repeat(3) { }\n"),
        ("let s = \"ab\".repeat(3)\n", "let s = \"ab\".repeat(3)\n"),
        ("import {io, string} from std\n", "import {io, string} from std\n"),
        # An operand keeps its space before a bracket.
        ("let p = power * (2 as U64)\n", "let p = power * (2 as U64)\n"),
        ("let v = [1, 2]\n", "let v = [1, 2]\n"),
        ("fn f() -> [Int] { }\n", "fn f() -> [Int] { }\n"),
        ("let xs = listOf<Int>(1, 2)\n", "let xs = listOf<Int>(1, 2)\n"),
        # Signs hug, subtraction does not.
        ("f(-1, 0)\n", "f(-1, 0)\n"),
        ("let x = -y\n", "let x = -y\n"),
        ("return -1\n", "return -1\n"),
        ("let d = a - b\n", "let d = a - b\n"),
        ("let d=f(a)-1\n", "let d = f(a) - 1\n"),
        # A word before punctuation closes up.
        ("extern fn f(name: String borrow) -> Int\n", "extern fn f(name: String borrow) -> Int\n"),
        ("f(current.type, none)\n", "f(current.type, none)\n"),
        ("struct S { type: Int }\n", "struct S { type: Int }\n"),
        # Continuation lines keep their indentation; too shallow ones move one step in.
        ("fn f() {\n    if (a\n        or b) {\n        g()\n    }\n}\n",
         "fn f() {\n    if (a\n        or b) {\n        g()\n    }\n}\n"),
        ("fn f() {\n    let s = join(a,\n                 b)\n}\n",
         "fn f() {\n    let s = join(a,\n                 b)\n}\n"),
        ("fn f() {\n    let s = a +\nb\n}\n", "fn f() {\n    let s = a +\n        b\n}\n"),
        ("fn f() -> Int {\n    return a\n+ b\n}\n", "fn f() -> Int {\n    return a\n        + b\n}\n"),
        ("import ir.*\nimport std.io\n", "import ir.*\nimport std.io\n"),
        ("enum E {\n  A,\n    B\n}\n", "enum E {\n    A,\n    B\n}\n"),
        ("fn f() {\n    xs.sortBy(fn(a: Int, b: Int) -> Bool {\n        return a < b\n    })\n}\n",
         "fn f() {\n    xs.sortBy(fn(a: Int, b: Int) -> Bool {\n        return a < b\n    })\n}\n"),
        # Type arguments are not comparisons.
        ("let items: List<Int> = list_new()\n", "let items: List<Int> = list_new()\n"),
        ("fn first<T>(values: List<T>) -> T { }\n", "fn first<T>(values: List<T>) -> T { }\n"),
        ("let a: Int<24> = 5\n", "let a: Int<24> = 5\n"),
        ("let v: Vec<Int<24>> = []\n", "let v: Vec<Int<24>> = []\n"),
        ("if (a<24 and b>3) { }\n", "if (a < 24 and b > 3) { }\n"),
        ("let grid: Array<Array<U8, 4>, 4> = default\n", "let grid: Array<Array<U8, 4>, 4> = default\n"),
        ("fn map<T, U, F: Fn(T) -> U>(o: T?, f: F) -> U? { }\n", "fn map<T, U, F: Fn(T) -> U>(o: T?, f: F) -> U? { }\n"),
        ("let g: Array<Int, N * N>\n", "let g: Array<Int, N * N>\n"),
        ("impl<T, E> Result<T, E> { }\n", "impl<T, E> Result<T, E> { }\n"),
        ("let n = x<y\n", "let n = x < y\n"),
        # Bitwise not, comparisons, none-coalescing, indexing, optional.
        ("let m = a & ~ b\n", "let m = a & ~b\n"),
        ("if (a<b) { }\n", "if (a < b) { }\n"),
        ("let n = a??0\n", "let n = a ?? 0\n"),
        ("let x = values[0]\n", "let x = values[0]\n"),
        ("let maybe: Int? = none\n", "let maybe: Int? = none\n"),
        # A closure's bars hug its parameters.
        ("let f = xs.map(|x: Int| x + 1)\n", "let f = xs.map(|x: Int| x + 1)\n"),
        ("let f = xs.map(| x: Int | x+1)\n", "let f = xs.map(|x: Int| x + 1)\n"),
        ("let f = a | b\n", "let f = a | b\n"),
        # Trailing comments keep their column; trailing blanks and extra blank lines go.
        ("let a = 1   // one\nlet bb = 2 // two\n", "let a = 1   // one\nlet bb = 2 // two\n"),
        ("let a = 1   \n\n\n\n\nlet b = 2\n", "let a = 1\n\n\nlet b = 2\n"),
        ("let a = 1", "let a = 1\n"),
        ("\n\nlet a = 1\n\n\n", "let a = 1\n"),
        # Interpolation is one token whatever it holds.
        ("let s = \"a ${f( x ,y)} b\"\n", "let s = \"a ${f( x ,y)} b\"\n"),
        ("let s = \"\"\"\n  keep   this\n  \"\"\"\n", "let s = \"\"\"\n  keep   this\n  \"\"\"\n"),
        # A block comment's body goes under its opener.
        ("fn f() {\n/*\nnote\n*/\n}\n", "fn f() {\n    /*\n       note\n    */\n}\n"),
        ("/*\n * doc\n   */\nlet a = 1\n", "/*\n * doc\n */\nlet a = 1\n"),
        # A bracket left open does not indent what follows a new declaration.
        ("fn a(x: Int,\nfn b() {\n    g()\n}\n", "fn a(x: Int,\nfn b() {\n    g()\n}\n"),
        # Aligned braces stay aligned; a lone gap is one space.
        ("impl Eq for Int    { }\nimpl Eq for Float  { }\n", "impl Eq for Int    { }\nimpl Eq for Float  { }\n"),
        ("struct P{ x: Int }\n", "struct P { x: Int }\n"),
        # `Ptr<mut T>` is a type-argument list: the keyword inside it does not make `<` a comparison.
        ("public fn allocOf<T>(count: Int) -> Ptr<mut T> { }\n", "public fn allocOf<T>(count: Int) -> Ptr<mut T> { }\n"),
        ("let one = Ptr<mut T>.atUnchecked(4096)\n", "let one = Ptr<mut T>.atUnchecked(4096)\n"),
        # An `if` that has an `else` is written over several lines, one branch to a block and
        # `} else {` together; an `if` with no `else` stays as written.
        ("fn f() {\n    if (a) { b() } else { c() }\n}\n",
         "fn f() {\n    if (a) {\n        b()\n    } else {\n        c()\n    }\n}\n"),
        ("fn f() {\n    if (a) { b() } else if (c) { d() } else { e() }\n}\n",
         "fn f() {\n    if (a) {\n        b()\n    } else if (c) {\n        d()\n    } else {\n        e()\n    }\n}\n"),
        ("fn f() {\n    if (a) { b() } else if (c) { d() }\n}\n",
         "fn f() {\n    if (a) {\n        b()\n    } else if (c) {\n        d()\n    }\n}\n"),
        ("fn f() {\n    if (a) { b() }\n}\n", "fn f() {\n    if (a) { b() }\n}\n"),
        ("fn f() {\n    if (a) {\n        b()\n    }\n}\n", "fn f() {\n    if (a) {\n        b()\n    }\n}\n"),
        ("fn f() {\n    if (a) { } else { }\n}\n", "fn f() {\n    if (a) { } else { }\n}\n"),
        ("fn f() {\n    if (a) { b() } else { }\n}\n", "fn f() {\n    if (a) {\n        b()\n    } else { }\n}\n"),
        ("fn f() {\n    for i in 0..3 {\n        if (a) { b() } else { c() }\n    }\n}\n",
         "fn f() {\n    for i in 0..3 {\n        if (a) {\n            b()\n        } else {\n            c()\n        }\n    }\n}\n"),
        ("fn f() {\n    if (a) { b() } else { if (c) { d() } else { e() } }\n}\n",
         "fn f() {\n    if (a) {\n        b()\n    } else {\n        if (c) {\n            d()\n        } else {\n            e()\n        }\n    }\n}\n"),
        ("fn f() {\n    if (a\n        or b) { c() } else { d() }\n}\n",
         "fn f() {\n    if (a\n        or b) {\n        c()\n    } else {\n        d()\n    }\n}\n"),
        ("let x = if (c) { f() } else { g() }\n", "let x = if (c) {\n    f()\n} else {\n    g()\n}\n"),
        ("fn f() {\n    if (a) { b() /* note */ } else { c() }\n}\n",
         "fn f() {\n    if (a) {\n        b() /* note */\n    } else {\n        c()\n    }\n}\n"),
        # An `else` the author put on its own line stays there; a half-typed chain is left alone.
        ("fn f() {\n    if (a) {\n        b()\n    }\n    else {\n        c()\n    }\n}\n",
         "fn f() {\n    if (a) {\n        b()\n    }\n    else {\n        c()\n    }\n}\n"),
        ("fn f() {\n    if (a) { b() } else\n}\n", "fn f() {\n    if (a) { b() } else\n}\n"),
        ("fn f() {\n    if (a) { b() } else if (c\n}\n", "fn f() {\n    if (a) { b() } else if (c\n}\n"),
        # Destructuring, tuples, `?`, a nested struct, and a `match` without parentheses or braces: `..` in a
        # pattern is a word of the list, not a range, so it keeps the air a range does not.
        ("fn f() {\n    let Point { x, y: b,.. } = p\n    let (a,b)=t\n    let n=parse(s) ?\n}\n",
         "fn f() {\n    let Point { x, y: b, .. } = p\n    let (a, b) = t\n    let n = parse(s)?\n}\n"),
        ("fn f() {\n    let Point { x, .. } = p\n}\n", "fn f() {\n    let Point { x, .. } = p\n}\n"),
        ("fn f() {\n    for i in 0..n { g(i) }\n    let s = v[1..3]\n}\n", "fn f() {\n    for i in 0..n { g(i) }\n    let s = v[1..3]\n}\n"),
        ("struct W{ size: struct{ w: Int,h: Int }, p: (Int,Int) }\n", "struct W { size: struct { w: Int, h: Int }, p: (Int, Int) }\n"),
        ("struct Config {\n    struct Limits { max: Int }\n    limits: Limits\n}\n",
         "struct Config {\n    struct Limits { max: Int }\n    limits: Limits\n}\n"),
        ("fn f() {\n    match s{\n    Shape.Circle=>print(),\n    _=>\n    }\n}\n",
         "fn f() {\n    match s {\n        Shape.Circle => print(),\n        _ =>\n    }\n}\n"),
        ("fn f() {\n    let a = match s { A => 1, _ => 2 }\n    let b = (1,2)\n    let c = t.0.1\n}\n",
         "fn f() {\n    let a = match s { A => 1, _ => 2 }\n    let b = (1, 2)\n    let c = t.0.1\n}\n"),
    ]
    for given, expected in cases:
        got = fmt(given)
        if got != expected:
            problems.append(f"fmt({given!r})\n      = {got!r}\n   want {expected!r}")
        elif fmt(got) != got:
            problems.append(f"fmt does not settle on {got!r}")

    # A range formats the lines it names and nothing else.
    text = "let   a = 1\nlet   b = 2\nlet   c = 3\n"
    if fmt(text, "--range", "2:2") != "let   a = 1\nlet b = 2\nlet   c = 3\n":
        problems.append(f"--range changed lines outside its range: {fmt(text, '--range', '2:2')!r}")
    if fmt(text, "--range", "2:9") == "<exit":
        problems.append("--range past the end of the file failed")

    # CRLF stays CRLF.
    crlf = fmt("fn f() {\r\nlet a=1\r\n}\r\n")
    if crlf != "fn f() {\r\n    let a = 1\r\n}\r\n":
        problems.append(f"fmt did not keep CRLF line ends: {crlf!r}")

    # Files: --check, --write, and the default.
    with tempfile.TemporaryDirectory(prefix="prismio-fmt-") as tmp:
        messy = Path(tmp) / "messy.psm"
        tidy = Path(tmp) / "tidy.psm"
        messy.write_text("fn f( ) {\nlet a=1\n}\n")
        tidy.write_text("fn f() {\n    let a = 1\n}\n")
        check = run_command([str(PRISMIO_EXE), "fmt", "--check", str(messy), str(tidy)])
        if check.returncode != 1 or "messy.psm" in check.stdout and "tidy.psm" in check.stdout:
            problems.append(f"--check should name only the file it would change and exit 1: {check.returncode} {check.stdout!r}")
        if messy.read_text() != "fn f( ) {\nlet a=1\n}\n":
            problems.append("--check wrote a file")
        if run_command([str(PRISMIO_EXE), "fmt", "--check", str(tidy)]).returncode != 0:
            problems.append("--check failed on formatted source")
        run_command([str(PRISMIO_EXE), "fmt", "--write", str(messy)])
        if messy.read_text() != "fn f() {\n    let a = 1\n}\n":
            problems.append(f"--write left {messy.read_text()!r}")
        # Folders: every `.psm` under them, any number, mixed with files; hidden folders and other
        # extensions are left alone. A folder with nothing to format is formatted already.
        messy_text = "fn f( ) {\nlet a=1\n}\n"
        tree = Path(tmp) / "tree"
        for relative in ("proj/a.psm", "proj/sub/deep/b.psm", "proj/.hidden/c.psm", "proj/notes.txt", "other/d.psm"):
            target = tree / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(messy_text)
        (tree / "empty").mkdir()
        proj, other = str(tree / "proj"), str(tree / "other")
        listed = run_command([str(PRISMIO_EXE), "fmt", "--check", proj, other])
        names = {re.split(r"[\\/]", line)[-1] for line in listed.stdout.splitlines()}
        if listed.returncode != 1 or names != {"a.psm", "b.psm", "d.psm"}:
            problems.append(f"fmt --check over two folders should name a, b and d (not the hidden c or notes.txt): "
                            f"{listed.returncode} {listed.stdout!r}")
        mixed = run_command([str(PRISMIO_EXE), "fmt", "--check", str(tree / "proj" / "a.psm"), other])
        if mixed.returncode != 1 or mixed.stdout.count("would reformat") != 2:
            problems.append(f"fmt --check over a file and a folder should name both: {mixed.stdout!r}")
        several = run_command([str(PRISMIO_EXE), "fmt", proj])
        if several.returncode == 0 or "--write" not in several.stdout + several.stderr:
            problems.append(f"fmt over a folder of several files needs --write or --check: {several.returncode}")
        if run_command([str(PRISMIO_EXE), "fmt", "--check", str(tree / "empty")]).returncode != 0:
            problems.append("fmt --check of a folder with no source failed")
        run_command([str(PRISMIO_EXE), "fmt", "--write", proj, other])
        tidy_text = "fn f() {\n    let a = 1\n}\n"
        if [(tree / r).read_text() for r in ("proj/a.psm", "proj/sub/deep/b.psm", "other/d.psm")] != [tidy_text] * 3:
            problems.append("fmt --write over folders did not rewrite every file")
        if (tree / "proj/.hidden/c.psm").read_text() != messy_text or (tree / "proj/notes.txt").read_text() != messy_text:
            problems.append("fmt --write over a folder touched a hidden folder or a file that is not .psm")
        if run_command([str(PRISMIO_EXE), "fmt", "--check", proj, other]).returncode != 0:
            problems.append("fmt --check over folders failed after --write")
        if run_command([str(PRISMIO_EXE), "fmt", str(Path(tmp) / "missing.psm")]).returncode == 0:
            problems.append("fmt of a missing file succeeded")

    # The whole checkout.
    result = run_command([sys.executable, str(PROJECT_ROOT / "tools" / "check_fmt.py"), "--compiler", str(PRISMIO_EXE),
                          "--damaged", "150", "--ir", "10"])
    if result.returncode != 0:
        problems.append("tools/check_fmt.py failed:\n" + "\n".join(
            line for line in result.stdout.splitlines() if line.startswith("FAIL") or "files," in line)[:2000]
            + "\n" + result.stderr[-2000:])

    if problems:
        print(f"{RED}[FAIL] fmt{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] fmt follows its rules, moves only whitespace, settles, and leaves programs unchanged{RESET}")
    return True


@harness_test(suite="tooling", resources={"cpu": 2, "mem": 800})
def run_index_test():
    """`check --emit-index`: the semantic index an editor answers hover, definition and completion from.

    Three layers. The corpus (tools/check_index.py) indexes every compilable program, every standard
    library module and the compiler itself, and holds the index to the text: no dangling reference, the
    name under every span is the name it points at, nothing unresolved in a program that compiles, and
    something was indexed at all. Then a small program is indexed and asked about by name, so a wrong
    answer is a specific one: what a call points at, the signature as written, the comment above, a
    generic nothing instantiates, a variant with no payload, a closure's capture. Then completion: members
    after a dot, names in scope, a module's contents, a Vec's builtins. Last, the structured fix a missing
    import carries.
    """
    print(f"\n{BLUE}--- Running index ---{RESET}")
    problems = []

    result = run_command([sys.executable, str(PROJECT_ROOT / "tools" / "check_index.py"), "--compiler", str(PRISMIO_EXE)])
    if result.returncode != 0:
        problems.append("tools/check_index.py failed:\n" + "\n".join(
            line for line in result.stdout.splitlines() if line.startswith("FAIL") or "programs," in line)[:3000])

    source = (
        "import std.io\n"                                         # 1
        "\n"
        "// A point in the plane.\n"                              # 3
        "struct Point { x: Int, y: Int }\n"                      # 4
        "\n"
        "enum Shape {\n"                                          # 6
        "    Empty,\n"
        "    Circle(Int)\n"
        "}\n"
        "\n"
        "impl Point {\n"                                          # 11
        "    // The sum of both coordinates.\n"
        "    fn sum(self) -> Int { return self.x + self.y }\n"   # 13
        "}\n"
        "\n"
        "fn first<T>(a: T, b: T) -> T { return a }\n"            # 16
        "\n"
        "fn unused<U>(u: U) -> U { return u }\n"                 # 18
        "\n"
        "fn main() -> Int {\n"                                    # 20
        "    let p = Point { x: 1, y: 2 }\n"
        "    let mut total = 0\n"
        "    let f = |v: Int| v + total\n"                       # 23
        "    total = first(p.sum(), 3)\n"                        # 24
        "    match (Shape.Circle(2)) {\n"
        "        Shape.Empty => { total = 0 }\n"                 # 26
        "        Shape.Circle(r) => { total = r }\n"
        "    }\n"
        "    println(f(total))\n"                                # 29
        "    return 0\n"
        "}\n")
    with tempfile.TemporaryDirectory(prefix="prismio-index-") as tmp:
        root = Path(tmp).resolve()
        program = root / "p.psm"
        program.write_text(source)
        env = dict(os.environ, PRISMIO_INTERNAL_HOSTED="1")

        def indexed(*extra, target=program, buffer=None):
            out = root / "out.idx"
            if out.exists():
                out.unlink()
            args = [str(PRISMIO_EXE), "check", str(target), "--partial", "--emit-index", str(out), *extra]
            if buffer is not None:
                args += ["--overlay", str(target), str(buffer)]
            done = subprocess.run(args, capture_output=True, text=True, env=env)
            records = [json.loads(line) for line in out.read_text().splitlines()] if out.exists() else []
            return done, records

        done, records = indexed()
        if done.returncode != 0:
            problems.append(f"the sample program should check clean: {done.stderr[:300]}")
        decls = {(d["name"], d["kind"]): d for d in records if d["k"] == "decl" and d["user"]}
        refs = [r for r in records if r["k"] == "ref"]
        by_id = {d["id"]: d for d in records if d["k"] == "decl"}

        def named(name, kind):
            found = decls.get((name, kind))
            if found is None:
                problems.append(f"no {kind} `{name}` in the index")
            return found

        def points_at(line, col, name, kind):
            hit = [r for r in refs if r["l"] == line and r["c"] == col and r["to"] >= 0]
            if not hit:
                problems.append(f"no reference at {line}:{col}")
                return
            target = by_id.get(hit[0]["to"])
            if target is None or target["name"] != name or target["kind"] != kind:
                problems.append(f"{line}:{col} points at {target and (target['name'], target['kind'])}, not {(name, kind)}")

        sum_decl = named("sum", "method")
        if sum_decl:
            if sum_decl["sig"] != "fn sum(self) -> Int":
                problems.append(f"the signature of `sum` reads {sum_decl['sig']!r}")
            if sum_decl.get("doc") != "The sum of both coordinates.":
                problems.append(f"the doc of `sum` reads {sum_decl.get('doc')!r}")
            if sum_decl.get("owner") != "Point" or (sum_decl["sl"], sum_decl["el"]) != (13, 13):
                problems.append(f"`sum` owner/extent wrong: {sum_decl.get('owner')} {sum_decl['sl']}-{sum_decl['el']}")
        point = named("Point", "struct")
        if point and point.get("doc") != "A point in the plane.":
            problems.append(f"the doc of `Point` reads {point.get('doc')!r}")
        shape = named("Shape", "enum")
        if shape and (shape["sl"], shape["el"]) != (6, 9):
            problems.append(f"`Shape` extent {shape['sl']}-{shape['el']}, want 6-9")
        for variant in ("Empty", "Circle"):
            v = named(variant, "variant")
            if v and shape and v["container"] != shape["id"]:
                problems.append(f"variant `{variant}` is not inside `Shape`")
        if named("first", "fn") is None or named("unused", "fn") is None:
            problems.append("a generic, instantiated or not, is a declaration")
        generic = named("T", "typeparam")
        if generic and generic["container"] != (decls.get(("first", "fn")) or {}).get("id"):
            problems.append("`T` is not the parameter of `first`")
        named("total", "let")
        named("f", "let")
        named("v", "param")
        named("r", "let")
        named("std.io", "import")

        points_at(24, 21, "sum", "method")            # p.sum()
        points_at(24, 13, "first", "fn")              # first(...)
        points_at(24, 5, "total", "let")              # total = ...
        points_at(21, 13, "Point", "struct")          # Point { ... }
        points_at(23, source.split("\n")[22].index("total") + 1, "total", "let")   # the closure's use of total
        points_at(26, 15, "Empty", "variant")         # a variant with no payload
        points_at(27, 15, "Circle", "variant")
        points_at(27, source.split("\n")[26].rindex("r") + 1, "r", "let")

        # A struct written inside another, a pattern's new name, and a tuple's type: the index reads the program the
        # parser lifted them out of, so each has to land where the program wrote it.
        nested_source = (
            "struct Window {\n"                                         # 1
            "    size: struct { w: Int, h: Int }\n"                     # 2
            "    struct Limits { max: Int }\n"                          # 3
            "}\n"
            "struct Point { x: Int, y: Int }\n"                         # 5
            "fn pair() -> (Int, Int) { return (1, 2) }\n"               # 6
            "fn main() -> Int {\n"
            "    let win = Window { size: { w: 4, h: 5 } }\n"           # 8
            "    let Point { x, y: why } = Point { x: 1, y: 2 }\n"      # 9
            "    let t = pair()\n"                                      # 10
            "    return win.size.w + x + why + t.0\n"                   # 11
            "}\n")
        nested = root / "n.psm"
        nested.write_text(nested_source)
        sample_state = (done, records, decls, refs, by_id)
        done, records = indexed(target=nested)
        if done.returncode != 0:
            problems.append(f"the nested-struct program should check clean: {done.stderr[:300]}")
        decls = {(d["name"], d["kind"]): d for d in records if d["k"] == "decl" and d["user"]}
        refs = [r for r in records if r["k"] == "ref"]
        by_id = {d["id"]: d for d in records if d["k"] == "decl"}
        window = named("Window", "struct")
        limits = named("Limits", "struct")
        if window and limits and limits["container"] != window["id"]:
            problems.append("a struct written inside `Window` is not inside it in the outline")
        size = named("size", "field")
        if size and size.get("ty") != "Window.size":
            problems.append(f"the type of the field `size` reads {size.get('ty')!r}, want 'Window.size'")
        w = named("w", "field")
        if w and size and w["container"] != size["id"]:
            problems.append("the fields of an inline struct are not inside the field that declares it")
        named("why", "let")
        t = named("t", "let")
        if t and t.get("ty") != "(Int, Int)":
            problems.append(f"the type of a tuple reads {t.get('ty')!r}, want '(Int, Int)'")
        points_at(11, nested_source.split("\n")[10].index(".w") + 2, "w", "field")   # win.size.w
        done, records, decls, refs, by_id = sample_state   # the checks below are about the first program
        points_at(29, source.split("\n")[28].index("total") + 1, "total", "let")
        hints = [r for r in records if r["k"] == "arg" and r["l"] == 24]
        if sorted((h["p"], h["i"]) for h in hints) != [("a", 0), ("b", 1)]:
            problems.append(f"argument hints on line 24: {hints}")
        stats = [r for r in records if r["k"] == "stats"]
        if not stats or stats[0]["unresolved"] != 0:
            problems.append(f"stats: {stats}")

        # A name that is nothing is unresolved, with its place.
        broken = root / "broken.psm"
        broken.write_text("fn main() -> Int {\n    return nothing(1)\n}\n")
        done, records = indexed(target=broken)
        unresolved = [r for r in records if r["k"] == "unresolved"]
        if not unresolved or unresolved[0]["name"] != "nothing" or (unresolved[0]["l"], unresolved[0]["c"]) != (2, 12):
            problems.append(f"an unknown function should be unresolved at 2:12: {unresolved}")

        # A type the program never declared is unresolved, even when its name looks like a numeric one:
        # `Item`, `Frame` and `Index` are two to five letters starting with I, F or B-and-friends, which is
        # all the old built-in test looked at. The real numeric names must stay resolved.
        broken_types = root / "broken_types.psm"
        broken_types.write_text(
            "fn main() -> Int {\n"
            "    let a: Item = 1\n"
            "    let b: Frame = 2\n"
            "    let c: I32 = 3\n"
            "    let d: F32 = 1.0\n"
            "    let e: Usize = 4\n"
            "    let f: UInt = 5\n"
            "    let g: Index = 6\n"
            "    return 0\n"
            "}\n")
        done, records = indexed(target=broken_types)
        names = sorted((r["l"], r["name"]) for r in records if r["k"] == "unresolved" and r["what"] == "type")
        if names != [(2, "Item"), (3, "Frame"), (8, "Index")]:
            problems.append(f"only the undeclared types should be unresolved, got {names}")

        # Completion: the placeholder is where the word being typed starts.
        def complete(replacement, line, col):
            buffer = root / "buffer.psm"
            lines = source.split("\n")
            lines[line - 1] = replacement
            buffer.write_text("\n".join(lines))
            done, records = indexed("--complete", str(program), str(line), str(col), buffer=buffer)
            return [(r["label"], r["kind"]) for r in records if r["k"] == "completion"]

        members = complete("    total = p.ixcursor__", 24, 15)
        if ("x", "field") not in members or ("y", "field") not in members or ("sum", "method") not in members:
            problems.append(f"members of a Point: {members}")
        if any(label in ("total", "first") for label, _ in members):
            problems.append(f"locals and functions are not members of a Point: {members}")
        scope = complete("    total = ixcursor__", 24, 13)
        for want in (("p", "let"), ("total", "let"), ("f", "let"), ("first", "fn"), ("Point", "struct"), ("main", "fn")):
            if want not in scope:
                problems.append(f"{want} is in scope at 24:13: {scope[:12]}")
        if any(label.startswith("prismioStd") for label, _ in scope):
            problems.append("a private function of another file is not in scope")
        if scope.count(("first", "fn")) != 1:
            problems.append("a function is offered once")
        module = complete("    total = io.ixcursor__", 24, 16)
        if ("println", "fn") not in module or any(label == "total" for label, _ in module):
            problems.append(f"members of a module: {module[:8]}")
        variants = complete("    total = Shape.ixcursor__", 24, 19)
        if ("Empty", "variant") not in variants or ("Circle", "variant") not in variants:
            problems.append(f"members of an enum: {variants}")
        # What a program may not name is not offered, and what it may is ordered by how likely it is: the type's own members
        # before a free function that merely takes one first, the program's names before the library's.
        if any(label.startswith("__builtin") for label, _ in scope):
            problems.append("a compiler builtin is the library's vocabulary and is not offered to a program")
        buffer = root / "buffer.psm"
        lines = source.split("\n")
        lines[23] = "    total = p.ixcursor__"
        buffer.write_text("\n".join(lines))
        done, records = indexed("--complete", str(program), "24", "15", buffer=buffer)
        ranks = {r["label"]: r["rank"] for r in records if r["k"] == "completion"}
        if ranks.get("x") != 0 or ranks.get("sum") != 0:
            problems.append(f"a type's own fields and methods rank first: {ranks}")
        lines[23] = "    total = ixcursor__"
        buffer.write_text("\n".join(lines))
        done, records = indexed("--complete", str(program), "24", "13", buffer=buffer)
        ranks = {r["label"]: r["rank"] for r in records if r["k"] == "completion"}
        if not (ranks.get("p") == 0 and ranks.get("first") == 1 and ranks.get("println", 2) >= 2):
            problems.append(f"a local ranks before the program's names, and those before the library's: {ranks.get('p')} {ranks.get('first')} {ranks.get('println')}")
        # A struct literal's field name: the fields the literal has not written, and nothing else.
        literal = complete("    let q = Point { x: 1, ixcursor__: 0 }", 24, 27)
        if literal != [("y", "field")]:
            problems.append(f"the fields a Point literal has not set: {literal}")
        # A field no other module may touch, and a library's own machinery, are not members of a library type.
        mapped = root / "mapped.psm"
        mapped.write_text("fn main() -> Int {\n    let m = HashMap<String, Int>()\n    m.ixcursor__\n    return 0\n}\n")
        done, records = indexed("--complete", str(mapped), "3", "7", target=mapped)
        offered = {r["label"] for r in records if r["k"] == "completion"}
        if offered & {"slots", "mask", "tombstones", "entryKeys"} or not {"set", "get", "contains"} <= offered:
            problems.append(f"a HashMap offers its methods and not its private fields: {sorted(offered)[:20]}")
        vec = root / "vec.psm"
        vec.write_text("fn main() -> Int {\n    let v: Vec<Int> = []\n    v.ixcursor__\n    return 0\n}\n")
        done, records = indexed("--complete", str(vec), "3", "7", target=vec)
        builtin = sorted(r["label"] for r in records if r["k"] == "completion")
        # The compiler's own table of what it lowers is the reference.
        vec_source = (PROJECT_ROOT / "src" / "sema" / "vec.psm").read_text()
        table = vec_source[vec_source.index("fn semaVecArity"):]
        table = table[:table.index("\n}\n")]
        lowered = sorted(set(re.findall(r'name\.equals\("(\w+)"\)', table)))
        if builtin != lowered:
            problems.append(f"a Vec's members {builtin} differ from what sema lowers {lowered}")
        # What the compiler lowers carries its signature, in completion and on the reference at a use, so an
        # editor needs no table of its own (index/lowered.psm).
        details = {r["label"]: r.get("detail", "") for r in records if r["k"] == "completion"}
        if details.get("push") != "fn push(self, value: T)" or details.get("length") != "prop length(self) -> Int":
            problems.append(f"a Vec's lowered members should complete with their signatures: {details}")
        used = root / "vecuse.psm"
        used.write_text("fn main() -> Int {\n    let mut v: Vec<Int> = []\n    v.push(1)\n    v.clear()\n    return v.length\n}\n")
        done, records = indexed(target=used)
        members = {(r["l"], r["c"]): r for r in records if r["k"] == "ref" and r.get("builtin") == "member"}
        for where, sig in (((3, 7), "fn push(self, value: T)"), ((4, 7), "fn clear(self)"), ((5, 14), "prop length(self) -> Int")):
            if members.get(where, {}).get("sig") != sig:
                problems.append(f"the use at {where} of a lowered member should carry {sig!r}: {members.get(where)}")
        # An overload of a library function the program used is written with it, and `Type.f(` resolves.
        calls = root / "calls.psm"
        calls.write_text("import std.io\n\nstruct Counter { n: Int }\n\nimpl Counter {\n    public fn new() -> Counter { return Counter { n: 0 } }\n}\n\n"
                         "fn main() -> Int {\n    let c = Counter.new()\n    println(c.n)\n    return 0\n}\n")
        done, records = indexed(target=calls)
        printlns = [r for r in records if r["k"] == "decl" and r["name"] == "println"]
        if len(printlns) < 2:
            problems.append(f"overloads of a used library function should be written with it: {len(printlns)}")
        creates = [r for r in records if r["k"] == "ref" and r["l"] == 10 and r["c"] == 21]
        if not creates or creates[0]["to"] < 0:
            problems.append(f"`Counter.new()` should resolve to its function: {creates}")

        # A missing import is a diagnostic with a fix an editor can apply: `joinPath` is in a module the
        # program has (a helper imports it) and this file does not.
        (root / "helper.psm").write_text("import std.fs\n\npublic fn size(s: String) -> Int {\n    return joinPath(s, s).length\n}\n")
        fixme = root / "fixme.psm"
        fixme.write_text("import helper\nimport std.io\n\nfn main() -> Int {\n    let s = joinPath(\"a\", \"b\")\n    return size(s)\n}\n")
        done = subprocess.run([str(PRISMIO_EXE), "check", str(fixme), "--diagnostic-format=json"], capture_output=True,
                              text=True, env=env)
        fixes = [json.loads(line).get("fix") for line in done.stderr.splitlines() if line.startswith("{")]
        fixes = [f for f in fixes if f]
        if fixes != [{"addImport": "std.fs"}]:
            problems.append(f"the missing import should carry a fix, got {fixes} from {done.stderr[:300]}")

    if problems:
        print(f"{RED}[FAIL] index{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] the index is true to the text, answers by name, completes, and carries the import fix{RESET}")
    return True


@harness_test(suite="tooling")
def run_lsp_manifest_test():
    """`prismio lsp` and `build.ums`: its diagnostics and its completion, in process.

    A manifest open in the editor is checked as the manifest language (ums/), not as a Prismio program:
    a mistake in it is published with its UMS code and range, fixing it clears the list, closing it
    withdraws what was said. Completion offers what the manifest can say at the cursor, and every
    key it offers is one the lowering accepts (the table is guarded against the language, not the other way).
    """
    print(f"\n{BLUE}--- Running lsp_manifest ---{RESET}")
    sys.path.insert(0, str(TEST_DIR))
    from lsp_client import LspClient

    problems = []

    def note(condition, message):
        if not condition:
            problems.append(message)
        return condition

    good = ('project {\n    name = "demo"\n    version = "0.1.0"\n    prismio = "0.1.0"\n}\n\n'
            'targets {\n    executable("demo") {\n        entry = "main.psm"\n    }\n}\n')
    with tempfile.TemporaryDirectory(prefix="prismio-lspm-") as tmp:
        root = Path(tmp).resolve()
        manifest = root / "build.ums"
        (root / "main.psm").write_text("fn main() -> Int { return 0 }\n")
        manifest.write_text(good)
        uri = manifest.as_uri()
        client = LspClient([str(PRISMIO_EXE), "lsp"], env={"PRISMIO_INTERNAL_HOSTED": "1"})
        try:
            client.initialize(root.as_uri(), {"general": {"positionEncodings": ["utf-16"]}})

            def open_text(text, version):
                client.notify("textDocument/didOpen", {"textDocument": {"uri": uri, "languageId": "ums",
                                                                         "version": version, "text": text}})

            def change(text, version):
                client.notify("textDocument/didChange", {"textDocument": {"uri": uri, "version": version},
                                                         "contentChanges": [{"text": text}]})

            open_text(good, 1)
            published = client.diagnostics_for(uri)
            note(published["diagnostics"] == [] and published.get("version") == 1,
                 f"a good manifest is clean: {published}")

            # --- a mistake is published with its code and range, and fixing it clears it ---
            bad = good.replace('    version = "0.1.0"\n', '    version = "0.1.0"\n    colour = "red"\n')
            change(bad, 2)
            published = client.diagnostics_for(uri)
            found = published["diagnostics"]
            note(len(found) == 1 and found[0]["code"] == "UMS2004" and found[0]["range"]["start"]["line"] == 3
                 and "colour" in found[0]["message"] and found[0]["source"] == "prismio",
                 f"an unknown project property: {published}")
            change(good, 3)
            published = client.diagnostics_for(uri)
            note(published["diagnostics"] == [] and published.get("version") == 3, f"fixed: {published}")

            # --- completion ---
            def complete(text, needle, delta=0, occurrence=0):
                change(text, complete.version)
                complete.version += 1
                at = -1
                for _ in range(occurrence + 1):
                    at = text.index(needle, at + 1)
                before = text[:at + delta]
                line = before.count("\n")
                character = len(before) - (before.rfind("\n") + 1)
                reply = client.request("textDocument/completion", {"textDocument": {"uri": uri},
                                                                    "position": {"line": line, "character": character}})
                note("error" not in reply, f"completion failed: {reply}")
                return [i["label"] for i in reply["result"]["items"]], reply["result"]["items"]
            complete.version = 10

            labels, _ = complete("pro\n", "pro", 3)
            note({"project", "targets", "commands", "toolchain", "dependencies", "profiles"} <= set(labels),
                 f"blocks at the top: {labels}")
            labels, _ = complete(good.replace('    version = "0.1.0"\n', "    \n"), "    \n", 4)
            note({"name", "version", "prismio", "license"} <= set(labels) and "entry" not in labels,
                 f"keys in project: {labels}")
            labels, _ = complete(good.replace('        entry = "main.psm"\n', "        \n"), "        \n", 8)
            note({"entry", "runtime", "native", "link", "codeModel"} <= set(labels) and "name" not in labels,
                 f"keys in a target: {labels}")
            labels, _ = complete(good.replace('    executable("demo")', '    exe("demo")'), "exe", 3)
            note({"executable", "library", "test"} <= set(labels), f"target kinds: {labels}")
            labels, _ = complete(good.replace('entry = "main.psm"', 'runtime = '), "runtime = ", 10)
            note(labels == ['"installed"', '"none"'], f"values of runtime: {labels}")
            labels, _ = complete(good.replace('entry = "main.psm"', 'freestanding = '), "freestanding = ", 15)
            note(labels == ["true", "false"], f"values of a flag: {labels}")
            labels, _ = complete(good.replace('executable("demo")', 'executable("de'), "executable(\"de", 14)
            note(labels == [], f"nothing offered inside a call's arguments: {labels}")

            # --- the table against the language: no key it offers is one the manifest rejects ---
            scopes = {
                "": ("", "{}"), "project": ("project {\n    ", "\n}"), "toolchain": ("toolchain {\n    ", "\n}"),
                "targets": ("targets {\n    ", "\n}"),
                "target": ('targets {\n    executable("t") {\n        ', '\n    }\n}'),
                "native": ('targets {\n    executable("t") {\n        native {\n            ', '\n        }\n    }\n}'),
                "link": ('targets {\n    executable("t") {\n        link {\n            ', '\n        }\n    }\n}'),
                "commands": ("commands {\n    ", "\n}"),
                "command": ('commands {\n    command("c") {\n        ', '\n    }\n}'),
                "profiles": ("profiles {\n    ", "\n}"), "profile": ("profiles {\n    debug {\n        ", "\n    }\n}"),
                "dependencies": ("dependencies {\n    ", "\n}"),
            }
            offered = 0
            for name, (head, tail) in scopes.items():
                if name == "":
                    items = complete("\n", "\n", 0)[1]
                else:
                    items = complete(head + tail, head, len(head))[1]
                note(items, f"{name or 'top level'} offers something")
                for item in items:
                    # A block's body is left empty; a call's or key's value gets a stand-in.
                    text = item["insertText"].replace("$1", "x").replace("$0", "" if item["kind"] == 14 or item["label"] in ("command",) else "x")
                    if name == "":
                        attempt = text
                    else:
                        attempt = head + text + tail
                    change(attempt, complete.version)
                    complete.version += 1
                    shown = client.diagnostics_for(uri)["diagnostics"]
                    rejected = [d["message"] for d in shown if d["message"].startswith("unknown")
                                or "contains only" in d["message"] or "holds debug" in d["message"]]
                    note(not rejected, f"`{item['label']}` offered in {name or 'top level'} but rejected: {rejected}")
                    offered += 1
            note(offered > 50, f"the table was exercised: {offered} entries")

            # --- closing a manifest withdraws what was said about it ---
            change(bad, complete.version)
            client.diagnostics_for(uri)
            client.notify("textDocument/didClose", {"textDocument": {"uri": uri}})
            published = client.diagnostics_for(uri)
            note(published["diagnostics"] == [], f"closed: {published}")
            note(client.request("shutdown").get("result") is None, "shutdown")
            client.notify("exit")
            client.process.wait(timeout=20)
        except Exception as error:
            problems.append(f"the session failed: {type(error).__name__}: {error}; server said: {client.stderr_text[:300]!r}")
        finally:
            client.close()

    if problems:
        print(f"{RED}[FAIL] lsp_manifest{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] lsp_manifest: manifest diagnostics, completion by scope, and the table against the language{RESET}")
    return True


@harness_test(suite="tooling")
def run_lsp_workspace_test():
    """`prismio lsp` over a workspace of several programs, and files that change on disk.

    Two programs live in one root, each with its own `build.ums`: a file is checked as the program it
    belongs to, so an error in one is not published against the other. A module nobody has open is edited
    on disk and the client reports it (`workspace/didChangeWatchedFiles`): the open importer is checked
    again and the error appears in the module's own file; fixing it on disk clears it.
    """
    print(f"\n{BLUE}--- Running lsp_workspace ---{RESET}")
    sys.path.insert(0, str(TEST_DIR))
    from lsp_client import LspClient

    problems = []

    def note(condition, message):
        if not condition:
            problems.append(message)
        return condition

    def manifest(entry):
        return ('project {\n    name = "p"\n    version = "0.1.0"\n    prismio = "0.1.0"\n}\n\n'
                f'targets {{\n    executable("p") {{\n        entry = "{entry}"\n    }}\n}}\n')

    with tempfile.TemporaryDirectory(prefix="prismio-lspw-") as tmp:
        root = Path(tmp).resolve()
        (root / "alpha").mkdir()
        (root / "beta").mkdir()
        (root / "alpha" / "build.ums").write_text(manifest("main.psm"))
        (root / "beta" / "build.ums").write_text(manifest("main.psm"))
        alpha_main = root / "alpha" / "main.psm"
        alpha_util = root / "alpha" / "util.psm"
        beta_main = root / "beta" / "main.psm"
        alpha_main.write_text("import util\n\nfn main() -> Int { return value() }\n")
        alpha_util.write_text("public fn value() -> Int { return 1 }\n")
        beta_main.write_text("fn main() -> Int { return 2 }\n")
        client = LspClient([str(PRISMIO_EXE), "lsp"], env={"PRISMIO_INTERNAL_HOSTED": "1"})
        try:
            client.initialize(root.as_uri(), {"general": {"positionEncodings": ["utf-16"]}})
            for path in (alpha_main, beta_main):
                client.notify("textDocument/didOpen", {"textDocument": {"uri": path.as_uri(), "languageId": "prismio",
                                                                         "version": 1, "text": path.read_text()}})
            for path in (alpha_main, beta_main):
                shown = client.diagnostics_for(path.as_uri())
                note(shown["diagnostics"] == [], f"{path.name} of {path.parent.name} is clean: {shown}")

            # An error appears on disk in a module nobody has open.
            alpha_util.write_text("public fn value() -> Int { return missing }\n")
            client.notify("workspace/didChangeWatchedFiles", {"changes": [{"uri": alpha_util.as_uri(), "type": 2}]})
            shown = client.diagnostics_for(alpha_util.as_uri(), timeout=30)
            note(len(shown["diagnostics"]) == 1 and shown["diagnostics"][0]["code"].startswith("P"),
                 f"the closed module's error is published against it: {shown}")
            note(client.quiet_for(1.0) or True, "")
            # ... and not against the other program.
            reply = client.request("textDocument/documentSymbol", {"textDocument": {"uri": beta_main.as_uri()}})
            note([s["name"] for s in reply["result"]] == ["main"], f"the other program still answers: {reply}")

            alpha_util.write_text("public fn value() -> Int { return 3 }\n")
            client.notify("workspace/didChangeWatchedFiles", {"changes": [{"uri": alpha_util.as_uri(), "type": 2}]})
            shown = client.diagnostics_for(alpha_util.as_uri(), timeout=30)
            note(shown["diagnostics"] == [], f"fixed on disk: {shown}")

            # Two targets share a directory and the module belongs to the second: the first never reads it (P1075),
            # so the next is tried, and the error in the module is shown.
            (root / "multi").mkdir()
            (root / "multi" / "build.ums").write_text(
                'project {\n    name = "m"\n    version = "0.1.0"\n    prismio = "0.1.0"\n}\n\n'
                'targets {\n    executable("a") {\n        entry = "a.psm"\n    }\n'
                '    executable("b") {\n        entry = "b.psm"\n    }\n}\n')
            (root / "multi" / "a.psm").write_text("fn main() -> Int { return 0 }\n")
            (root / "multi" / "b.psm").write_text("import lib\n\nfn main() -> Int { return value() }\n")
            multi_lib = root / "multi" / "lib.psm"
            multi_lib.write_text("public fn value() -> Int { return missing }\n")
            client.notify("textDocument/didOpen", {"textDocument": {"uri": multi_lib.as_uri(), "languageId": "prismio",
                                                                     "version": 1, "text": multi_lib.read_text()}})
            shown = client.wait_for(lambda m: m.get("method") == "textDocument/publishDiagnostics"
                                    and m["params"]["uri"] == multi_lib.as_uri() and m["params"]["diagnostics"], timeout=40)
            note("missing" in shown["params"]["diagnostics"][0]["message"],
                 f"the program that reads a module is found by trying the manifest's targets in turn: {shown}")

            # No manifest: a module is checked through a program that imports it, found from the file upward.
            (root / "loose" / "sub").mkdir(parents=True)
            loose_main = root / "loose" / "main.psm"
            loose_tool = root / "loose" / "sub" / "tool.psm"
            loose_main.write_text("import sub.tool\n\nfn main() -> Int { return answer() }\n")
            loose_tool.write_text("import sub.other\n\npublic fn answer() -> Int { return other() }\n")
            (root / "loose" / "sub" / "other.psm").write_text("public fn other() -> Int { return 4 }\n")
            client.notify("textDocument/didOpen", {"textDocument": {"uri": loose_tool.as_uri(), "languageId": "prismio",
                                                                     "version": 1, "text": loose_tool.read_text()}})
            shown = client.diagnostics_for(loose_tool.as_uri(), timeout=30)
            note(shown["diagnostics"] == [], f"a module is checked through the program that imports it: {shown}")
            broken = "import sub.other\n\npublic fn answer() -> Int { return nothere() }\n"
            client.notify("textDocument/didChange", {"textDocument": {"uri": loose_tool.as_uri(), "version": 2},
                                                     "contentChanges": [{"text": broken}]})
            shown = client.diagnostics_for(loose_tool.as_uri(), timeout=30)
            note(len(shown["diagnostics"]) == 1 and "nothere" in shown["diagnostics"][0]["message"],
                 f"and an error in it is shown: {shown}")

            note(client.request("shutdown").get("result") is None, "shutdown")
            client.notify("exit")
            client.process.wait(timeout=20)
        except Exception as error:
            problems.append(f"the session failed: {type(error).__name__}: {error}; server said: {client.stderr_text[:300]!r}")
        finally:
            client.close()

    if problems:
        print(f"{RED}[FAIL] lsp_workspace{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] lsp_workspace: programs kept apart, files changed on disk reported and rechecked{RESET}")
    return True


def process_rss_kib(pid):
    """Resident size of a process in KiB, or None where it cannot be read for the process the test holds.

    `ps` on POSIX, where `prismio lsp` replaces itself with the server and the pid is the server's. On Windows `exec`
    is a launcher that waits for the server, so the pid is not the server's and the memory checks do not run there:
    they report themselves as skipped, never as passed."""
    if sys.platform == "win32":
        return None
    out = subprocess.run(["ps", "-o", "rss=", "-p", str(pid)], capture_output=True, text=True)
    return int(out.stdout.strip() or 0) if out.returncode == 0 else 0


def lsp_problems():
    """(problems, note): `note` records `message` when `condition` is false, and returns it."""
    problems = []

    def note(condition, message):
        if not condition:
            problems.append(message)
        return condition

    return problems, note


def lsp_report(name, problems, passed):
    if problems:
        print(f"{RED}[FAIL] {name}{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] {passed}{RESET}")
    return True


def lsp_where(text, needle, occurrence=0, within=None):
    """(line, character) of an occurrence of `needle`, 0-based; `within` narrows to a line's text."""
    lines = text.split("\n")
    seen = 0
    for number, line in enumerate(lines):
        if within is not None and within not in line:
            continue
        start = 0
        while True:
            at = line.find(needle, start)
            if at < 0:
                break
            if seen == occurrence:
                return {"line": number, "character": at}
            seen += 1
            start = at + 1
    raise AssertionError(f"{needle!r} not found")


@contextlib.contextmanager
def lsp_session(note, problems):
    """The two-file program every feature is asked about, open in a server of its own. A
    scenario that raises is one problem, and the server is closed either way."""
    from lsp_client import LspClient

    main_text = (
        "import std.io\n"                                         # 1
        "import shapes\n"                                         # 2
        "\n"
        "// Add two numbers.\n"                                   # 4
        "fn add(a: Int, b: Int) -> Int {\n"                       # 5
        "    let total = a + b\n"                                 # 6
        "    return total\n"                                      # 7
        "}\n"                                                     # 8
        "\n"
        "fn main() -> Int {\n"                                    # 10
        "    let p = Point { x: 1, y: 2 }\n"                      # 11
        "    let n = add(p.x, p.sum())\n"                         # 12
        "    println(n)\n"                                        # 13
        "    return 0\n"                                          # 14
        "}\n")
    shapes_text = (
        "public struct Point { public x: Int, public y: Int }\n"   # 1
        "\n"
        "impl Point {\n"                                          # 3
        "    // The sum of both coordinates.\n"
        "    public fn sum(self) -> Int { return self.x + self.y }\n"   # 5
        "}\n")


    with tempfile.TemporaryDirectory(prefix="prismio-lspf-") as tmp:
        root = Path(tmp).resolve()
        main_path = root / "main.psm"
        shapes_path = root / "shapes.psm"
        main_path.write_text(main_text)
        shapes_path.write_text(shapes_text)
        # A manifest says which program the modules belong to; without one each file would be its own.
        (root / "build.ums").write_text(
            'project {\n    name = "demo"\n    version = "0.1.0"\n    prismio = "0.1.0"\n}\n\n'
            'targets {\n    executable("demo") {\n        entry = "main.psm"\n    }\n}\n')
        main_uri = main_path.as_uri()
        shapes_uri = shapes_path.as_uri()

        client = LspClient([str(PRISMIO_EXE), "lsp"], env={"PRISMIO_INTERNAL_HOSTED": "1"})
        try:
            init = client.initialize(root.as_uri(), {"general": {"positionEncodings": ["utf-16"]}})
            caps = init["result"]["capabilities"]
            for name in ("hoverProvider", "definitionProvider", "referencesProvider", "documentSymbolProvider",
                         "renameProvider", "completionProvider", "semanticTokensProvider", "inlayHintProvider",
                         "signatureHelpProvider", "foldingRangeProvider", "codeActionProvider",
                         "documentFormattingProvider", "workspaceSymbolProvider", "typeDefinitionProvider",
                         "documentHighlightProvider"):
                note(name in caps, f"the server should advertise {name}")
            for uri, text in ((main_uri, main_text), (shapes_uri, shapes_text)):
                client.notify("textDocument/didOpen", {"textDocument": {"uri": uri, "languageId": "prismio",
                                                                         "version": 1, "text": text}})
            first = client.diagnostics_for(main_uri)
            note(first["diagnostics"] == [], f"the sample program should be clean: {first['diagnostics']}")

            def ask(method, uri=main_uri, **extra):
                reply = client.request(method, {"textDocument": {"uri": uri}, **extra})
                note("error" not in reply, f"{method} failed: {reply.get('error')}")
                return reply.get("result")

            yield SimpleNamespace(client=client, root=root, ask=ask, main_text=main_text,
                                  shapes_text=shapes_text, main_uri=main_uri,
                                  shapes_uri=shapes_uri)
            client.shutdown()
        except Exception as error:
            problems.append(f"the session failed: {type(error).__name__}: {error}")
            try:
                client.close()
            except Exception:
                pass


@harness_test("lsp_features_navigation", suite="tooling", resources={"cpu": 2, "mem": 500})
def run_lsp_features_navigation_test():
    """`prismio lsp`, past diagnostics: hover (signature, doc and type, across files), definition,
    type definition, references, highlights, the outline, workspace symbols, signature help with the
    active parameter and inlay hints, each asked about a place whose answer is known from the text."""
    print(f"\n{BLUE}--- Running lsp_features_navigation ---{RESET}")
    sys.path.insert(0, str(TEST_DIR))
    problems, note = lsp_problems()
    with lsp_session(note, problems) as s:
        client = s.client
        root = s.root
        ask = s.ask
        main_text = s.main_text
        shapes_text = s.shapes_text
        main_uri = s.main_uri
        shapes_uri = s.shapes_uri

        # --- hover ---
        hover = ask("textDocument/hover", position=lsp_where(main_text, "add", 0, "add(p.x"))
        value = (hover or {}).get("contents", {}).get("value", "")
        note("fn add(a: Int, b: Int) -> Int" in value and "Add two numbers." in value,
             f"hover on a call shows the signature and the comment: {value!r}")
        hover = ask("textDocument/hover", position=lsp_where(main_text, "sum", 0, "p.sum"))
        value = (hover or {}).get("contents", {}).get("value", "")
        note("fn sum(self) -> Int" in value and "The sum of both coordinates." in value,
             f"hover on a method of another file: {value!r}")
        hover = ask("textDocument/hover", position=lsp_where(main_text, "n", 0, "let n"))
        note("let n: Int" in ((hover or {}).get("contents", {}).get("value", "")), f"hover on a binding: {hover}")
        note(ask("textDocument/hover", position={"line": 3, "character": 3}) is None, "hover on a comment says nothing")

        # --- definition, type definition ---
        definition = ask("textDocument/definition", position=lsp_where(main_text, "Point", 0, "Point {"))
        note(len(definition) == 1 and definition[0]["uri"] == shapes_uri
             and definition[0]["range"]["start"] == {"line": 0, "character": 14},
             f"definition of a type declared in another file: {definition}")
        definition = ask("textDocument/definition", position=lsp_where(main_text, "add", 0, "add(p.x"))
        note(len(definition) == 1 and definition[0]["uri"] == main_uri
             and definition[0]["range"]["start"] == {"line": 4, "character": 3}, f"definition of a function: {definition}")
        kinds = ask("textDocument/typeDefinition", position=lsp_where(main_text, "p", 0, "let p"))
        note(len(kinds) == 1 and kinds[0]["uri"] == shapes_uri, f"type definition of a variable: {kinds}")

        # --- references and highlights ---
        references = ask("textDocument/references", position=lsp_where(main_text, "add", 0, "fn add"),
                         context={"includeDeclaration": True})
        note(len(references) == 2, f"references of add, with its declaration: {references}")
        references = ask("textDocument/references", position=lsp_where(main_text, "add", 0, "fn add"),
                         context={"includeDeclaration": False})
        note(len(references) == 1, f"references of add, without its declaration: {references}")
        references = ask("textDocument/references", position=lsp_where(shapes_text, "Point", 0, "struct"), uri=shapes_uri,
                         context={"includeDeclaration": True})
        note({r["uri"] for r in references} == {main_uri, shapes_uri}, f"a type's references span files: {references}")
        highlights = ask("textDocument/documentHighlight", position=lsp_where(main_text, "total", 0, "return total"))
        note(len(highlights) == 2 and sorted(h["kind"] for h in highlights) == [2, 3], f"highlights of total: {highlights}")

        # --- outline and workspace symbols ---
        symbols = ask("textDocument/documentSymbol", uri=shapes_uri)
        names = [(s["name"], [c["name"] for c in s.get("children", [])]) for s in symbols]
        note(("Point", ["x", "y"]) in names and ("impl Point", ["sum"]) in names, f"outline of shapes.psm: {names}")
        symbols = ask("textDocument/documentSymbol")
        note([s["name"] for s in symbols] == ["add", "main"], f"outline of main.psm: {[s['name'] for s in symbols]}")
        found = client.request("workspace/symbol", {"query": "poi"})["result"]
        note([s["name"] for s in found] == ["Point"] and found[0]["location"]["uri"] == shapes_uri,
             f"workspace symbols: {found}")

        # --- signature help ---
        inside = lsp_where(main_text, "p.x", 0, "add(p.x")
        help_ = ask("textDocument/signatureHelp", position={"line": inside["line"], "character": inside["character"] + 1})
        note(help_ and help_["signatures"][0]["label"] == "fn add(a: Int, b: Int) -> Int" and help_["activeParameter"] == 0,
             f"signature help in the first argument: {help_}")
        comma = lsp_where(main_text, ", p.sum", 0, "add(p.x")
        help_ = ask("textDocument/signatureHelp", position={"line": comma["line"], "character": comma["character"] + 2})
        note(help_ and help_["activeParameter"] == 1, f"signature help in the second argument: {help_}")
        labels = [help_["signatures"][0]["label"][a:b] for a, b in
                  (p["label"] for p in help_["signatures"][0]["parameters"])] if help_ else []
        note(labels == ["a: Int", "b: Int"], f"the parameters' labels point into the signature: {labels}")

        # --- inlay hints ---
        hints = ask("textDocument/inlayHint", range={"start": {"line": 0, "character": 0}, "end": {"line": 20, "character": 0}})
        texts = sorted(h["label"] for h in hints)
        note(texts == [": Int", ": Int", ": Point", "a:", "b:"], f"inlay hints (a pack parameter gets none): {texts}")

        # A half-typed statement (`xs.` with the next line already written) takes that statement out of the analysis,
        # not the function around it: the rest of `main` keeps its hints and its hover.
        half_text = ("fn grow(k: Int, extra: Int) -> Int {\n    return k + extra\n}\n\n"
                     "fn main() -> Int {\n    let mut xs: Vec<Int> = []\n    xs.push(1)\n"
                     "    let unfinished = xs.\n    let n = grow(1, 2)\n    return n\n}\n")
        half_path = root / "half.psm"
        half_path.write_text(half_text)
        half_uri = half_path.as_uri()
        client.notify("textDocument/didOpen", {"textDocument": {"uri": half_uri, "languageId": "prismio",
                                                                 "version": 1, "text": half_text}})
        half = client.diagnostics_for(half_uri)
        note(len(half["diagnostics"]) == 1, f"one syntax error in the half-typed function: {half['diagnostics']}")
        half_hints = sorted(h["label"] for h in
                            ask("textDocument/inlayHint", uri=half_uri,
                                range={"start": {"line": 0, "character": 0}, "end": {"line": 20, "character": 0}}))
        note(half_hints == [": Int", "extra:", "k:"], f"hints after a half-typed line in the same function: {half_hints}")
        half_hover = ask("textDocument/hover", uri=half_uri, position=lsp_where(half_text, "grow", 0, "let n = grow"))
        note("fn grow(k: Int, extra: Int) -> Int" in ((half_hover or {}).get("contents", {}).get("value", "")),
             f"hover after a half-typed line in the same function: {half_hover}")
        client.notify("textDocument/didClose", {"textDocument": {"uri": half_uri}})


    return lsp_report("lsp_features_navigation", problems,
                      "the server answers hover, definition, references, symbols and hints")


@harness_test("lsp_features_editing", suite="tooling", resources={"cpu": 2, "mem": 500})
def run_lsp_features_editing_test():
    """Semantic tokens, folding, and rename with its refusals."""
    print(f"\n{BLUE}--- Running lsp_features_editing ---{RESET}")
    sys.path.insert(0, str(TEST_DIR))
    problems, note = lsp_problems()
    with lsp_session(note, problems) as s:
        client = s.client
        ask = s.ask
        main_text = s.main_text
        shapes_text = s.shapes_text
        main_uri = s.main_uri
        shapes_uri = s.shapes_uri

        # --- semantic tokens, folding ---
        tokens = ask("textDocument/semanticTokens/full")["data"]
        note(len(tokens) > 20 and len(tokens) % 5 == 0, f"semantic tokens: {len(tokens)} numbers")
        line, character, found_function = 0, 0, False
        for i in range(0, len(tokens), 5):
            line += tokens[i]
            character = tokens[i + 1] if tokens[i] else character + tokens[i + 1]
            if line == 4 and character == 3 and tokens[i + 3] == 10:
                found_function = True
        note(found_function, "the name in `fn add` is coloured as a function")
        ranges = ask("textDocument/foldingRange")
        note({"startLine": 4, "endLine": 6} in [{k: v for k, v in r.items() if k != "kind"} for r in ranges],
             f"folding ranges: {ranges}")

        # --- rename ---
        prepared = ask("textDocument/prepareRename", position=lsp_where(main_text, "total", 0, "let total"))
        note(prepared and prepared["placeholder"] == "total", f"prepareRename: {prepared}")
        note(ask("textDocument/prepareRename", position={"line": 0, "character": 3}) is None, "nothing to rename in an import")
        changes = ask("textDocument/rename", position=lsp_where(main_text, "total", 0, "let total"), newName="sum")["changes"]
        note(list(changes) == [main_uri] and len(changes[main_uri]) == 2, f"rename a local: {changes}")
        changes = ask("textDocument/rename", position=lsp_where(shapes_text, "Point", 0, "struct"), uri=shapes_uri,
                      newName="Dot")["changes"]
        note(set(changes) == {main_uri, shapes_uri}, f"rename a type across files: {list(changes)}")
        for bad, why in (("b", "already declared"), ("fn", "keyword"), ("9x", "not a name")):
            reply = client.request("textDocument/rename", {"textDocument": {"uri": main_uri},
                                                          "position": lsp_where(main_text, "a: Int", 0, "fn add"), "newName": bad})
            note("error" in reply and why in reply["error"]["message"], f"renaming to {bad!r} should be refused ({why}): {reply}")


    return lsp_report("lsp_features_editing", problems,
                      "the server answers semantic tokens, folding and rename")


@harness_test("lsp_features_completion", suite="tooling", resources={"cpu": 2, "mem": 500})
def run_lsp_features_completion_test():
    """Completion: members, scope, keywords, library names with the import they need."""
    print(f"\n{BLUE}--- Running lsp_features_completion ---{RESET}")
    sys.path.insert(0, str(TEST_DIR))
    problems, note = lsp_problems()
    with lsp_session(note, problems) as s:
        client = s.client
        ask = s.ask
        main_text = s.main_text
        main_uri = s.main_uri

        # --- completion ---
        edited = main_text.replace("add(p.x, p.sum())", "add(p., p.sum())")
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": 2},
                                                 "contentChanges": [{"text": edited}]})
        at = lsp_where(edited, "p.", 0, "add(p.")
        items = ask("textDocument/completion", position={"line": at["line"], "character": at["character"] + 2})
        labels = {i["label"] for i in items["items"]}
        note({"x", "y", "sum"} <= labels and "total" not in labels and "if" not in labels,
             f"members after a dot: {sorted(labels)[:12]}")
        edited = main_text.replace("    println(n)\n", "    pri\n")
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": 3},
                                                 "contentChanges": [{"text": edited}]})
        at = lsp_where(edited, "pri", 0, "    pri")
        items = ask("textDocument/completion", position={"line": at["line"], "character": at["character"] + 3})
        labels = {i["label"] for i in items["items"]}
        note({"println", "add", "main", "p", "n", "Point", "if", "return"} <= labels, f"names in scope: {sorted(labels)[:14]}")

        # --- members the compiler provides, and overloads ---
        lib = main_text + ("\nfn useVec() -> Int {\n    let mut v: Vec<Int> = []\n    v.push(3)\n"
                          "    println(v.length)\n    return 0\n}\n")
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": 40},
                                                 "contentChanges": [{"text": lib}]})
        at = lsp_where(lib, "push", 0, "v.push(3)")
        hover = ask("textDocument/hover", position=at)
        value = (hover or {}).get("contents", {}).get("value", "")
        note("fn push(self, value: T)" in value and "Appends" in value, f"hover on a lowered member: {value!r}")
        help_ = ask("textDocument/signatureHelp", position={"line": at["line"], "character": at["character"] + 5})
        labels = [sig["label"] for sig in (help_ or {}).get("signatures", [])]
        note(labels == ["fn push(self, value: T)"], f"signature help on a lowered member: {labels}")
        note((help_ or {}).get("activeParameter") == 1, f"the receiver fills `self`, so the first argument is parameter 1: {help_}")
        at = lsp_where(lib, "println(v.length)", 0, "println(v.length)")
        help_ = ask("textDocument/signatureHelp", position={"line": at["line"], "character": at["character"] + 8})
        labels = [sig["label"] for sig in (help_ or {}).get("signatures", [])]
        note(len(labels) == 2 and all("println" in label for label in labels), f"every overload of println is offered: {labels}")
        first = (help_ or {}).get("signatures", [{}])[0]
        note(bool(first.get("parameters")), f"a library function's parameters are located in its label: {first}")

        # --- completion: library names from modules the file does not import, with the import they need ---
        bare = "fn main() -> Int {\n    slee\n    return 0\n}\n"
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": 41},
                                                 "contentChanges": [{"text": bare}]})
        at = lsp_where(bare, "slee", 0, "slee")
        items = ask("textDocument/completion", position={"line": at["line"], "character": at["character"] + 4})["items"]
        found = [i for i in items if i["label"] == "sleep"]
        edits = (found[0].get("additionalTextEdits") if found else None) or []
        note(found and edits and edits[0]["newText"] == "import std.time\n",
             f"a name from a module the file does not import carries the import: {found[:1]}")
        # An import already there is not added again, and a new one goes in sorted place.
        sorted_text = "import std.io\nimport std.term\n\nfn main() -> Int {\n    allo\n    return 0\n}\n"
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": 42},
                                                 "contentChanges": [{"text": sorted_text}]})
        at = lsp_where(sorted_text, "allo", 0, "allo")
        items = ask("textDocument/completion", position={"line": at["line"], "character": at["character"] + 4})["items"]
        found = [i for i in items if i["label"] == "alloc"]
        edits = (found[0].get("additionalTextEdits") if found else None) or []
        note(found and edits and edits[0]["range"]["start"]["line"] == 1,
             f"the new import goes before the first that sorts after it (std.io, std.mem, std.term): {edits}")
        # What the language uses is offered with no import to add.
        method = "fn main() -> Int {\n    let s = \"abc\"\n    s.tr\n    return 0\n}\n"
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": 43},
                                                 "contentChanges": [{"text": method}]})
        at = lsp_where(method, "s.tr", 0, "s.tr")
        items = ask("textDocument/completion", position={"line": at["line"], "character": at["character"] + 4})["items"]
        found = [i for i in items if i["label"] == "trim"]
        note(found and not found[0].get("additionalTextEdits"), f"a String method needs no import: {found[:1]}")
        # Import lines, a type annotation, and a syntax error on another line of the same function.
        version = 44
        for text, probe, want, forbid in (
                ("import \n", "import ", ["std", "std.io", "std.fs"], ["std.io.input", "std.collections.vec"]),
                ("import std.\n", "import std.", ["io", "fs", "task"], ["vec", "input"]),
                ("import std.task.\n", "import std.task.", ["poll"], ["io"]),
                ("import {io} \n", "import {io} ", ["from"], ["import", "return"]),
                ("fn main() {\n    let v: \n}\n", "let v: ", ["Int", "String", "Vec", "StringBuilder"], ["println", "return"]),
                ("import std.io\n\nfn main() -> Int {\n    println(1.)\n    pri\n    return 0\n}\n", "    pri", ["print", "println"], []),
                # A declaration still being written: the parser drops a signature or a struct it cannot close,
                # so the server closes the caret's line in its scratch copy before giving up on the type position.
                ("struct Point { x: Int }\n\nfn helper(first: In\n\nfn main() -> Int {\n    return 0\n}\n",
                 "fn helper(first: In", ["Int", "String", "Point"], ["return", "main"]),
                ("struct Point { x: Int }\n\nfn helper(first: Int, second: Po\n\nfn main() -> Int {\n    return 0\n}\n",
                 "second: Po", ["Int", "Point"], ["return", "main"]),
                ("struct Point { x: Int }\n\nfn main() -> Int {\n    return 0\n}\n\nstruct Pair { left: In\n",
                 "struct Pair { left: In", ["Int", "String", "Point"], ["return", "main"])):
            version += 1
            client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": version},
                                                     "contentChanges": [{"text": text}]})
            lines = text.split("\n")
            row = next(n for n, l in enumerate(lines) if l.endswith(probe))
            items = ask("textDocument/completion", position={"line": row, "character": len(lines[row])})
            labels = {i["label"] for i in (items or {}).get("items", [])}
            note(all(w in labels for w in want) and not any(f in labels for f in forbid),
                 f"completion at {probe!r}: wanted {want}, not {forbid}; got {sorted(labels)[:12]}")

        # --- completion: what is inserted, one row for an overloaded name, what is offered and in what order ---
        richer = 200

        def items_at(text, probe):
            nonlocal richer
            richer += 1
            client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": richer},
                                                     "contentChanges": [{"text": text}]})
            lines = text.split("\n")
            row = next(n for n, l in enumerate(lines) if l.endswith(probe))
            reply = ask("textDocument/completion", position={"line": row, "character": len(lines[row])})
            return (reply or {}).get("items", [])

        string_members = items_at("import std.io\nimport std.string\n\nfn main() -> Int {\n    let s = \"abc\"\n    s.\n    return 0\n}\n", "    s.")
        by_label = {}
        for item in string_members:
            by_label.setdefault(item["label"], []).append(item)
        note(len(by_label.get("concat", [])) == 1, f"an overloaded name is one row: {len(by_label.get('concat', []))} concat rows")
        concat = (by_label.get("concat") or [{}])[0]
        note("overload" in concat.get("labelDetails", {}).get("detail", ""), f"the row says how many overloads it stands for: {concat.get('labelDetails')}")
        note("Also:" in concat.get("documentation", {}).get("value", "") and "public fn concat(self, b: String" in concat["documentation"]["value"],
             "the other overloads are listed in its documentation")
        note(concat.get("insertText") == "concat(${1:other})" and concat.get("insertTextFormat") == 2,
             f"the simplest overload is the one shown and inserted, receiver left out: {concat.get('insertText')!r}")
        trim = (by_label.get("trim") or [{}])[0]
        note(trim.get("insertText") == "trim()" and trim.get("insertTextFormat") == 2, f"a method without arguments inserts its parentheses: {trim.get('insertText')!r}")
        length = (by_label.get("length") or [{}])[0]
        note("insertText" not in length, f"a property is inserted bare: {length.get('insertText')!r}")
        note(not ({"asmOps", "asmOpsOut", "offsetOf", "asm"} & set(by_label)),
             f"the library's machine-level names are not members of a String: {sorted({'asmOps', 'asmOpsOut', 'offsetOf', 'asm'} & set(by_label))}")
        note(all("-----" not in i.get("documentation", {}).get("value", "") for i in string_members), "no section banner reaches a documentation popup")
        note(all(len(i.get("documentation", {}).get("value", "")) < 1400 for i in string_members), "documentation is a paragraph, not a design note")

        vec_members = items_at("import std.io\n\nfn main() -> Int {\n    let mut v: Vec<Int> = []\n    v.\n    return 0\n}\n", "    v.")
        vec_by = {i["label"]: i for i in vec_members}
        note(vec_by.get("push", {}).get("insertText") == "push(${1:value})", f"a lowered member inserts its parameter: {vec_by.get('push', {}).get('insertText')!r}")
        note(vec_by.get("sort", {}).get("insertText") == "sort()" and vec_by["sort"].get("kind") == 2,
             f"a free function that takes the vector first is a method after the dot, its receiver not asked for again: {vec_by.get('sort')}")
        note(vec_by.get("push", {}).get("sortText", "9")[0] < vec_by.get("sort", {}).get("sortText", "0")[0],
             "what the type provides comes before a free function that takes it")

        scope_items = items_at("import std.io\n\nfn add(a: Int, b: Int) -> Int { return a + b }\n\nfn main() -> Int {\n    let counter = 3\n    \n    return 0\n}\n", "    ")
        scope_by = {i["label"]: i for i in scope_items}
        note(not any(label.startswith("__") for label in scope_by), "a program is not offered the compiler's builtins")
        note(scope_by.get("counter", {}).get("sortText", "9").startswith("0") and scope_by.get("add", {}).get("sortText", "9").startswith("1")
             and scope_by.get("println", {}).get("sortText", "0").startswith("2"),
             "a local, then the program's names, then the library's: "
             f"{[scope_by.get(n, {}).get('sortText') for n in ('counter', 'add', 'println')]}")
        note(scope_by.get("add", {}).get("insertText") == "add(${1:a}, ${2:b})", f"a call inserts a placeholder per parameter: {scope_by.get('add', {}).get('insertText')!r}")
        parens = "import std.io\n\nfn add(a: Int, b: Int) -> Int { return a + b }\n\nfn main() -> Int {\n    ad(1, 2)\n    return 0\n}\n"
        richer += 1
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": richer}, "contentChanges": [{"text": parens}]})
        row = parens.split("\n").index("    ad(1, 2)")
        reply = ask("textDocument/completion", position={"line": row, "character": len("    ad")})
        called = {i["label"]: i for i in (reply or {}).get("items", [])}
        note("add" in called and "insertText" not in called["add"], "a name in front of parentheses already written does not get a second pair")

        lit = "import std.io\n\nstruct Pair { left: Int, right: Int }\n\nfn main() -> Int {\n    let q = Pair { left: 1, }\n    return 0\n}\n"
        richer += 1
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": richer}, "contentChanges": [{"text": lit}]})
        row = lit.split("\n").index("    let q = Pair { left: 1, }")
        reply = ask("textDocument/completion", position={"line": row, "character": len("    let q = Pair { left: 1, ")})
        literal_items = {i["label"]: i for i in (reply or {}).get("items", [])}
        note(set(literal_items) == {"right"} and literal_items["right"].get("insertText") == "right: ",
             f"the fields a literal has not set, inserted with their colon: {sorted(literal_items)[:8]}")
        richer += 1
        call_arg = "import std.io\n\nfn add(a: Int, b: Int) -> Int { return a + b }\n\nfn main() -> Int {\n    let n = add(1, )\n    return 0\n}\n"
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": richer}, "contentChanges": [{"text": call_arg}]})
        row = call_arg.split("\n").index("    let n = add(1, )")
        reply = ask("textDocument/completion", position={"line": row, "character": len("    let n = add(1, ")})
        note("add" in {i["label"] for i in (reply or {}).get("items", [])}, "a comma in an argument list is not a field position")


    return lsp_report("lsp_features_completion", problems,
                      "the server completes members, scope names, keywords and imports")


@harness_test("lsp_features_requests", suite="tooling", resources={"cpu": 2, "mem": 500})
def run_lsp_features_requests_test():
    """A request made while a check is pending waits for it and sees the edit, a waiting request
    can be cancelled, the import quick fix and formatting."""
    print(f"\n{BLUE}--- Running lsp_features_requests ---{RESET}")
    sys.path.insert(0, str(TEST_DIR))
    problems, note = lsp_problems()
    with lsp_session(note, problems) as s:
        client = s.client
        root = s.root
        ask = s.ask
        main_text = s.main_text
        main_uri = s.main_uri

        # --- a request made while a check is pending waits for it ---
        added = main_text + "\nfn fresh() -> Int { return 7 }\n"
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": 4},
                                                 "contentChanges": [{"text": added}]})
        symbols = ask("textDocument/documentSymbol")
        note("fresh" in [s["name"] for s in symbols], "a request after an edit sees the edit")

        # --- a waiting request can be cancelled ---
        client.notify("textDocument/didChange", {"textDocument": {"uri": main_uri, "version": 5},
                                                 "contentChanges": [{"text": main_text}]})
        waiting = client.next_id
        client.send({"jsonrpc": "2.0", "id": waiting, "method": "textDocument/documentSymbol",
                     "params": {"textDocument": {"uri": main_uri}}})
        client.next_id += 1
        client.notify("$/cancelRequest", {"id": waiting})
        reply = client.wait_for(lambda m: m.get("id") == waiting and "method" not in m)
        note(reply.get("error", {}).get("code") == -32800, f"a cancelled request is answered as cancelled: {reply}")

        # --- the import quick fix, and formatting ---
        (root / "helper.psm").write_text("import std.fs\n\npublic fn size(s: String) -> Int {\n    return joinPath(s, s).length\n}\n")
        fixme = root / "fixme.psm"
        fixme_text = "import helper\nimport std.io\n\nfn main() -> Int {\n    let s = joinPath(\"a\", \"b\")\n    return size(s)\n}\n"
        fixme.write_text(fixme_text)
        client.notify("textDocument/didOpen", {"textDocument": {"uri": fixme.as_uri(), "languageId": "prismio",
                                                                 "version": 1, "text": fixme_text}})
        published = client.diagnostics_for(fixme.as_uri())["diagnostics"]
        fixable = [d for d in published if d.get("data", {}).get("addImport") == "std.fs"]
        note(len(fixable) == 1, f"the diagnostic carries the fix: {published}")
        if fixable:
            actions = ask("textDocument/codeAction", uri=fixme.as_uri(), range=fixable[0]["range"],
                          context={"diagnostics": fixable})
            edit = actions[0]["edit"]["changes"][fixme.as_uri()][0] if actions else None
            note(actions and actions[0]["title"] == "Add `import std.fs`" and edit["newText"] == "import std.fs\n"
                 and edit["range"]["start"] == {"line": 2, "character": 0}, f"the quick fix: {actions}")

        # A library function no import brings in: the compiler names the module from the library, so the fix is
        # offered though nothing in the program reads std.io.
        unimported = root / "unimported.psm"
        unimported_text = "fn main() -> Int {\n    println(1)\n    return 0\n}\n"
        unimported.write_text(unimported_text)
        client.notify("textDocument/didOpen", {"textDocument": {"uri": unimported.as_uri(), "languageId": "prismio",
                                                                 "version": 1, "text": unimported_text}})
        published = client.diagnostics_for(unimported.as_uri())["diagnostics"]
        fixable = [d for d in published if d.get("data", {}).get("addImport") == "std.io"]
        note(len(fixable) == 1 and fixable[0]["message"].startswith("`println` is declared in `std.io`, which this file does not import"),
             f"a library name nothing imports carries the fix: {published}")
        if fixable:
            actions = ask("textDocument/codeAction", uri=unimported.as_uri(), range=fixable[0]["range"],
                          context={"diagnostics": fixable})
            edit = actions[0]["edit"]["changes"][unimported.as_uri()][0] if actions else None
            note(actions and actions[0]["title"] == "Add `import std.io`" and edit["newText"] == "import std.io\n"
                 and edit["range"]["start"] == {"line": 0, "character": 0}, f"the library quick fix: {actions}")
        # Reached through a module that imports it, a generic is named as written, not as its instance.
        (root / "printer.psm").write_text("import std.io\n\npublic fn printed() -> Int {\n    println(1)\n    return 1\n}\n")
        through = root / "through.psm"
        through_text = "import printer\n\nfn main() -> Int {\n    println(printed())\n    return 0\n}\n"
        through.write_text(through_text)
        client.notify("textDocument/didOpen", {"textDocument": {"uri": through.as_uri(), "languageId": "prismio",
                                                                 "version": 1, "text": through_text}})
        published = client.diagnostics_for(through.as_uri())["diagnostics"]
        note(len(published) == 1 and published[0]["message"].startswith("`println` is declared in `std.io`")
             and published[0].get("data", {}).get("addImport") == "std.io",
             f"the diagnostic names the function written, not its instance: {published}")

        messy = "fn  f( ) {\nlet a=1\n   return  a\n}\n"
        ugly = root / "ugly.psm"
        ugly.write_text(messy)
        client.notify("textDocument/didOpen", {"textDocument": {"uri": ugly.as_uri(), "languageId": "prismio",
                                                                 "version": 1, "text": messy}})
        edits = ask("textDocument/formatting", uri=ugly.as_uri(), options={"tabSize": 4, "insertSpaces": True})
        applied = messy
        for edit in sorted(edits, key=lambda e: -e["range"]["start"]["line"]):
            lines = applied.split("\n")
            start, end = edit["range"]["start"], edit["range"]["end"]
            head = "\n".join(lines[:start["line"]]) + ("\n" if start["line"] else "") + lines[start["line"]][:start["character"]]
            tail = lines[end["line"]][end["character"]:] + ("\n" + "\n".join(lines[end["line"] + 1:]) if end["line"] + 1 < len(lines) else "")
            applied = head + edit["newText"] + tail
        note(applied == "fn f() {\n    let a = 1\n    return a\n}\n", f"formatting: {applied!r}")
        edits = ask("textDocument/rangeFormatting", uri=ugly.as_uri(), options={"tabSize": 4, "insertSpaces": True},
                    range={"start": {"line": 1, "character": 0}, "end": {"line": 1, "character": 5}})
        note(len(edits) == 1 and edits[0]["range"]["start"]["line"] == 1 and edits[0]["range"]["end"]["line"] == 1,
             f"range formatting touches only its line: {edits}")


    return lsp_report("lsp_features_requests", problems,
                      "the server orders, cancels, fixes and formats")


@harness_test("lsp_features_memory", suite="tooling", resources={"cpu": 2, "mem": 800})
def run_lsp_features_memory_test():
    """The features leave the server's memory where they found it."""
    print(f"\n{BLUE}--- Running lsp_features_memory ---{RESET}")
    sys.path.insert(0, str(TEST_DIR))
    from lsp_client import LspClient
    problems, note = lsp_problems()
    with tempfile.TemporaryDirectory(prefix="prismio-lspf-") as tmp:
        root = Path(tmp).resolve()
        (root / "build.ums").write_text(
            'project {\n    name = "demo"\n    version = "0.1.0"\n    prismio = "0.1.0"\n}\n\n'
            'targets {\n    executable("demo") {\n        entry = "main.psm"\n    }\n}\n')

        # --- the features leave the server's memory where they found it ------------------------------
        # Each request is a pass over a file and builds its answer from scratch; none may keep a copy of
        # what it read. A 100 KiB document is edited and asked about 150 times (a check, hover, the
        # outline, the tokens, completion, hints, references); after a warm-up the server must not grow.
        big_path = root / "big.psm"
        big = "fn main() -> Int {\n" + "".join(f"    let v{i}: Int = {i}\n" for i in range(4000)) + "    return v1\n}\n"
        big_path.write_text(big)
        client = LspClient([str(PRISMIO_EXE), "lsp"], env={"PRISMIO_INTERNAL_HOSTED": "1"})
        try:
            client.initialize(root.as_uri(), {"general": {"positionEncodings": ["utf-16"]}})
            big_uri = big_path.as_uri()
            client.notify("textDocument/didOpen", {"textDocument": {"uri": big_uri, "languageId": "prismio",
                                                                     "version": 1, "text": big}})
            client.diagnostics_for(big_uri, timeout=60)

            def rss():
                return process_rss_kib(client.process.pid)

            def round_(version):
                client.notify("textDocument/didChange", {"textDocument": {"uri": big_uri, "version": version},
                                                         "contentChanges": [{"text": big + "\n" * (version % 4)}]})
                at = {"line": 100, "character": 8}
                td = {"uri": big_uri}
                for method, extra in (("textDocument/hover", {"position": at}),
                                      ("textDocument/documentSymbol", {}),
                                      ("textDocument/semanticTokens/full", {}),
                                      ("textDocument/inlayHint", {"range": {"start": {"line": 0, "character": 0},
                                                                            "end": {"line": 400, "character": 0}}}),
                                      ("textDocument/references", {"position": at, "context": {"includeDeclaration": True}}),
                                      ("textDocument/completion", {"position": {"line": 100, "character": 6}})):
                    client.request(method, {"textDocument": td, **extra}, timeout=60)

            for version in range(2, 22):
                round_(version)
            before = rss()
            for version in range(22, 152):
                round_(version)
            if before is None:
                print(f"  (the features' memory is not measured on Windows)")
            else:
                growth = rss() - before
                note(growth < 6000, f"130 rounds of requests on a {len(big) // 1024} KiB document grew the server by {growth} KiB (limit 6,000)")
        except Exception as error:
            problems.append(f"the features' memory: {type(error).__name__}: {error}; server said: {client.stderr_text[:300]!r}")
        finally:
            client.close()

    return lsp_report("lsp_features_memory", problems,
                      "the server does not grow under repeated requests")


@harness_test("lsp_features_library_source", suite="tooling",
              reads=[])
def run_lsp_features_library_source_test():
    """The source a compiled library module carries is printed by `library-source`."""
    print(f"\n{BLUE}--- Running lsp_features_library_source ---{RESET}")
    problems, note = lsp_problems()

    # The source a compiled library module carries, which the server shows for a definition in the library: a
    # `.plib` begins with NUL bytes, so the compiler is the one that reads it. A compiler with no packaged
    # library beside it (the suite's bare generations) has nothing to ask.
    plib = Path(PRISMIO_EXE).resolve().parent.parent / "stdlib" / "collections" / "vec.plib"
    if plib.exists():
        shown = run_command([str(PRISMIO_EXE), "library-source", str(plib), "std.collections.vec"])
        note(shown.returncode == 0 and "public fn contains<T: Eq>(items: Vec<T>, needle: T) -> Bool {" in shown.stdout,
             f"library-source prints the module's source: {shown.returncode} {shown.stdout[:80]!r}")
        refused = run_command([str(PRISMIO_EXE), "library-source", str(plib), "std.io"])
        note(refused.returncode != 0 and "std.collections.vec" in (refused.stdout + refused.stderr),
             f"library-source refuses the wrong module name: {refused.returncode}")

    return lsp_report("lsp_features_library_source", problems,
                      "library-source prints a module's source and refuses a wrong name")


@harness_test(suite="tooling", resources={"cpu": 2, "mem": 800})
def run_lsp_test():
    """`prismio lsp`: the language server, spoken to over its pipes as an editor does.

    The server holds no knowledge of Prismio -- every diagnostic is the compiler's -- so what is
    tested is the protocol and the plumbing around the compiler: negotiation, positions in the
    unit the client counts, unsaved buffers reaching the compiler, a burst of edits becoming
    one check, a check that dies leaving the last answer in place, input that is not valid, and
    that none of it leaks a byte per keystroke. The client is Python (tests/lsp_client.py), so
    a framing bug in the server is a failure here and not something both halves agree on.
    """
    print(f"\n{BLUE}--- Running lsp ---{RESET}")
    sys.path.insert(0, str(TEST_DIR))
    from lsp_client import LspClient
    import subprocess as sp

    problems = []
    # The servers under test get a temporary directory of their own, so "no scratch files were left
    # behind" is a claim about them. Looked for in the shared one, it failed whenever any other
    # server was alive on the machine (an editor's) or had been killed there.
    scratch_holder = tempfile.TemporaryDirectory(prefix="prismio-lspscratch-")
    env = {"PRISMIO_INTERNAL_HOSTED": "1", "TMPDIR": scratch_holder.name}

    def note(condition, message):
        if not condition:
            problems.append(message)
        return condition

    def start(extra_env=None):
        merged = dict(env)
        if extra_env:
            merged.update(extra_env)
        return LspClient([str(PRISMIO_EXE), "lsp"], env=merged)

    def opened(client, path, text, version=1):
        uri = path.resolve().as_uri()
        client.notify("textDocument/didOpen", {"textDocument": {
            "uri": uri, "languageId": "prismio", "version": version, "text": text}})
        return uri

    def edited(client, uri, text, version):
        client.notify("textDocument/didChange", {
            "textDocument": {"uri": uri, "version": version},
            "contentChanges": [{"text": text}]})

    def messages_of(diagnostics):
        return sorted(d["message"] for d in diagnostics["diagnostics"])

    def server_rss(client):
        return process_rss_kib(client.process.pid)

    wrong = "fn main() -> Int {\n    let n: Int = \"x\"\n    return n\n}\n"
    right = "fn main() -> Int {\n    let n: Int = 1\n    return n\n}\n"

    with tempfile.TemporaryDirectory(prefix="prismio-lsp-") as tmp:
        root = Path(tmp).resolve()

        # --- negotiation and the protocol's refusals ------------------------------------
        client = start()
        try:
            early = client.request("textDocument/hover", {})
            note(early.get("error", {}).get("code") == -32002,
                 f"a request before initialize should be refused with -32002: {early}")
            reply = client.initialize()
            caps = reply["result"]["capabilities"]
            note(caps.get("positionEncoding") == "utf-16", f"UTF-16 unless the client offers UTF-8: {caps}")
            note(caps["textDocumentSync"] == {"openClose": True, "change": 1, "save": {"includeText": False}},
                 f"full-text synchronisation: {caps}")
            note(reply["result"]["serverInfo"]["name"] == "prismio", "serverInfo")
            unknown = client.request("textDocument/linkedEditingRange", {})
            note(unknown.get("error", {}).get("code") == -32601, f"an unknown request is -32601: {unknown}")
            client.notify("$/somethingNew", {"x": 1})
            client.notify("workspace/didChangeConfiguration", {"settings": {}})
            note(client.request("shutdown").get("result") is None, "shutdown answers null")
            client.notify("exit")
            client.process.wait(timeout=20)
            note(client.process.returncode == 0, f"exit after shutdown is 0: {client.process.returncode}")
        except Exception as error:
            problems.append(f"negotiation: {error!r}; server said: {client.stderr_text[:300]!r}")
        finally:
            client.close()

        client = start()
        try:
            client.initialize(capabilities={"general": {"positionEncodings": ["utf-8", "utf-16"]}})
            reply = client.request("shutdown")
            client.close()
            client = start()
            reply = client.initialize(capabilities={"general": {"positionEncodings": ["utf-8", "utf-16"]}})
            note(reply["result"]["capabilities"]["positionEncoding"] == "utf-8",
                 f"UTF-8 when the client offers it: {reply}")
            client.close()
            note(client.process.returncode == 1, f"stdin closed without shutdown exits 1: {client.process.returncode}")
        except Exception as error:
            problems.append(f"utf-8 negotiation: {error!r}")
        finally:
            client.close()

        # --- diagnostics, positions, and a fix clearing them ----------------------------
        client = start()
        try:
            client.initialize()
            path = root / "one.psm"
            path.write_text(wrong)
            uri = opened(client, path, wrong)
            published = client.diagnostics_for(uri)
            note(published["version"] == 1, f"the document's version rides along: {published}")
            note(len(published["diagnostics"]) == 1, f"one error expected: {published}")
            found = published["diagnostics"][0]
            note(found["range"] == {"start": {"line": 1, "character": 17}, "end": {"line": 1, "character": 20}},
                 f"the error underlines the string literal: {found['range']}")
            note(found["severity"] == 1 and found["code"] == "P4001" and found["source"] == "prismio",
                 f"severity, code and source: {found}")
            edited(client, uri, right, 2)
            cleared = client.diagnostics_for(uri)
            note(cleared["diagnostics"] == [] and cleared["version"] == 2, f"fixing it clears it: {cleared}")
        except Exception as error:
            problems.append(f"diagnostics: {error!r}; server said: {client.stderr_text[:300]!r}")
        finally:
            client.close()

        # --- a column after non-ASCII text, in both units -------------------------------
        # `    let s = ["é😀", 5]`: the error is on the `5`, byte column 24. Before it sit a
        # two-byte and a four-byte scalar, which are one and two UTF-16 units, so the client
        # that counts UTF-16 is told 20 and the one that counts bytes is told 23.
        accented = 'fn main() -> Int {\n    let s = ["\u00e9\U0001F600", 5]\n    return 0\n}\n'
        for encodings, want in ((None, 20), (["utf-8"], 23)):
            client = start()
            try:
                capabilities = {"general": {"positionEncodings": encodings}} if encodings else {}
                client.initialize(capabilities=capabilities)
                path = root / "accented.psm"
                path.write_text(accented, encoding="utf-8")
                uri = opened(client, path, accented)
                published = client.diagnostics_for(uri)
                starts = [d["range"]["start"] for d in published["diagnostics"]]
                note(starts == [{"line": 1, "character": want}],
                     f"{encodings or 'utf-16'}: the error's start should be line 1, character {want}: {starts}")
            except Exception as error:
                problems.append(f"positions {encodings}: {error!r}")
            finally:
                client.close()

        # --- unsaved text in a file the program imports ---------------------------------
        (root / "app").mkdir()
        (root / "app" / "main.psm").write_text(
            "import std.io\nimport helper\n\nfn main() -> Int {\n    println(twice(2))\n    return 0\n}\n")
        helper_ok = "public fn twice(n: Int) -> Int {\n    return n * 2\n}\n"
        helper_bad = "public fn twice(n: Int) -> Int {\n    return n * \"2\"\n}\n"
        (root / "app" / "helper.psm").write_text(helper_ok)
        client = start()
        try:
            client.initialize()
            main_uri = opened(client, root / "app" / "main.psm", (root / "app" / "main.psm").read_text())
            helper_uri = opened(client, root / "app" / "helper.psm", helper_bad)
            first = client.diagnostics_for(helper_uri)
            note(len(first["diagnostics"]) >= 1, f"the unsaved helper's error is reported on the helper: {first}")
            edited(client, helper_uri, helper_ok, 2)
            second = client.diagnostics_for(helper_uri)
            note(second["diagnostics"] == [], f"fixing the buffer clears it, though the disk never changed: {second}")
        except Exception as error:
            problems.append(f"overlays: {error!r}; server said: {client.stderr_text[:300]!r}")
        finally:
            client.close()

        # --- a syntax error beside a type error: partial analysis ---------------------------
        both = ("import std.io\n\nfn broken(x: Int) -> Int {\n    return x +\n}\n\n"
                "fn typo() -> Int {\n    let n: Int = \"text\"\n    return n\n}\n\n"
                "fn main() -> Int {\n    println(typo())\n    return 0\n}\n")
        client = start()
        try:
            client.initialize()
            path = root / "both.psm"
            path.write_text(both)
            uri = opened(client, path, both)
            published = client.diagnostics_for(uri)
            texts = messages_of(published)
            note(any("expected an expression" in t for t in texts), f"the syntax error: {texts}")
            note(any("expected Int, found String" in t for t in texts), f"and the type error beside it: {texts}")
        except Exception as error:
            problems.append(f"partial: {error!r}")
        finally:
            client.close()

        # --- a burst of edits is one check, and the last text wins ------------------------------
        client = start()
        try:
            client.initialize()
            path = root / "burst.psm"
            path.write_text(wrong)
            uri = opened(client, path, wrong)
            for version in range(2, 42):
                edited(client, uri, (wrong if version % 2 == 0 else right), version)
            edited(client, uri, wrong, 99)
            last = None
            while True:
                try:
                    last = client.diagnostics_for(uri, timeout=3)
                except TimeoutError:
                    break
            note(last is not None and last["version"] == 99 and len(last["diagnostics"]) == 1,
                 f"the burst should end on the last text's diagnostics: {last}")
        except Exception as error:
            problems.append(f"burst: {error!r}")
        finally:
            client.close()

        # --- a check that dies leaves the last answer alone ---------------------------------------
        # The stand-in compiler is a shell script that kills itself, so it needs a POSIX shell: not run on Windows.
        if sys.platform == "win32":
            print("  (a check that is killed is not exercised on Windows)")
        else:
            crasher = root / "crasher.py"
            crasher.write_text("#!/bin/sh\nkill -9 $$\n")
            crasher.chmod(0o755)
            client = start({"PRISMIO_LSP_CHECK": str(crasher)})
            try:
                client.initialize()
                path = root / "crash.psm"
                path.write_text(wrong)
                opened(client, path, wrong)
                logged = client.wait_for(lambda m: m.get("method") == "window/logMessage", timeout=15)
                note("without a result" in logged["params"]["message"],
                     f"a check that is killed is logged, not published: {logged}")
                note(client.quiet_for(1.0), "nothing is published for a check that never finished")
                note(client.request("shutdown").get("result") is None, "the server is still alive after a crashed check")
                client.notify("exit")
            except Exception as error:
                problems.append(f"crashing check: {error!r}; server said: {client.stderr_text[:300]!r}")
            finally:
                client.close()

        # --- input that is not valid -------------------------------------------------------------
        client = start()
        try:
            client.initialize()
            client.send_raw("{not json")
            bad = client.wait_for(lambda m: "error" in m and m["error"]["code"] == -32700, timeout=10)
            note(bad["id"] is None, f"a parse error answers with a null id: {bad}")
            client.process.stdin.write(b"X-Unknown: 1\r\n\r\n")
            client.process.stdin.flush()
            client.send({"jsonrpc": "2.0", "id": 77, "method": "textDocument/linkedEditingRange", "params": {}})
            after = client.wait_for(lambda m: m.get("id") == 77, timeout=10)
            note(after["error"]["code"] == -32601, f"the server survives a block without Content-Length: {after}")
            client.send({"jsonrpc": "2.0", "id": "string-id", "method": "nope"})
            string_id = client.wait_for(lambda m: m.get("id") == "string-id", timeout=10)
            note(string_id["id"] == "string-id", "a string id comes back as a string")
            # Half a message, then the client goes away.
            client.process.stdin.write(b"Content-Length: 500\r\n\r\n{\"jsonrpc\"")
            client.process.stdin.flush()
        except Exception as error:
            problems.append(f"invalid input: {error!r}; server said: {client.stderr_text[:300]!r}")
        finally:
            client.close()
            note(client.process.returncode is not None, "a message cut off by EOF ends the server")

        # --- a big document, and no growth per keystroke ------------------------------------------
        # The failure this guards is quiet and large: the server once held every previous text of a
        # document it had been sent (a Vec element store parks what it displaces), which at 100 KiB
        # a keystroke is a gigabyte in ten thousand. A document of that size, edited 600 times,
        # must leave the server's memory where it found it.
        client = start()
        try:
            client.initialize()
            path = root / "big.psm"
            big = "fn main() -> Int {\n" + "".join(f"    let v{i}: Int = {i}\n" for i in range(4000)) + "    return 0\n}\n"
            path.write_text(big)
            uri = opened(client, path, big)
            published = client.diagnostics_for(uri, timeout=60)
            note(published["diagnostics"] == [], f"a {len(big) // 1024} KiB document is accepted: {published}")
            for version in range(2, 52):
                edited(client, uri, big + "\n" * (version % 4), version)
            client.diagnostics_for(uri, timeout=60)
            before = server_rss(client)
            for version in range(52, 652):
                edited(client, uri, big + "\n" * (version % 4), version)
            client.diagnostics_for(uri, timeout=60)
            if before is None:
                print("  (the server's memory is not measured on Windows)")
            else:
                growth = server_rss(client) - before
                note(growth < 3000, f"600 edits of a {len(big) // 1024} KiB document grew the server by {growth} KiB (limit 3,000)")
        except Exception as error:
            problems.append(f"size and memory: {error!r}; server said: {client.stderr_text[:300]!r}")
        finally:
            client.close()

        # --- `prismio lsp` without the server beside it says so ---------------------------------------
        lone = root / "lone"
        (lone / "bin").mkdir(parents=True)
        shutil.copy2(PRISMIO_EXE, lone / "bin" / PRISMIO_EXE.name)
        for directory in ("lib", "stdlib"):
            if (PRISMIO_EXE.parent.parent / directory).is_dir():
                shutil.copytree(PRISMIO_EXE.parent.parent / directory, lone / directory)
        refused = sp.run([str(lone / "bin" / PRISMIO_EXE.name), "lsp"], capture_output=True, text=True,
                         env=dict(os.environ, **env), stdin=sp.DEVNULL, timeout=30)
        note(refused.returncode != 0 and "P1099" in refused.stderr,
             f"a compiler with no server beside it should refuse with P1099: {refused.stderr[:300]}")

    note(not [p for p in Path(scratch_holder.name).glob("prismio-lsp-*") if p.is_dir() and any(p.iterdir())],
         "scratch files were left behind")
    scratch_holder.cleanup()

    if problems:
        print(f"{RED}[FAIL] lsp{RESET}")
        for problem in problems:
            print(f"  {problem}")
        return False
    print(f"{GREEN}[PASS] lsp: negotiation, positions, unsaved buffers, partial analysis, bursts, "
          f"a crashed check, invalid input, size and memory{RESET}")
    return True
