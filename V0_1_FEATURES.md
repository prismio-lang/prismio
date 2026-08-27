# v0.1 — the feature work

The plan for the language features v0.1 still owes. `TODO.md` is the *compiler
improvement* plan (measured optimisations, defects); this file is the *language
surface* plan. They share the gate in §2 and neither supersedes the other.

**The published roadmap disagrees with this file and must be corrected.**
`../docs/content/roadmap.md` currently ships "Traits and `impl` blocks — Coming
Soon", "Closures — Coming Soon", "Package manager — Coming Soon". If these are
v0.1, that table is wrong and users are reading it. Fixing it is part of the
first task that lands any of them, not a follow-up.

---

## 1 · The bar

The one from `V1_GAP_ANALYSIS.md`, unchanged:

> A competent third party who has never read the compiler's source can write a
> non-trivial program, build it, ship it, and debug it — without working around
> the compiler, without reading its internals to find out what's implemented,
> and without hitting silent wrong answers.

Plus a v0.1-specific one: **a user should be able to write `list.sort()` and
`text.trim()`**, the way they would in Kotlin or Swift. Not because method
syntax is important in itself, but because it is the difference between a
standard library that reads like one and a pile of prefixed free functions.

**Small is fine; wrong-shaped is not.** Every item below should land in the
smallest form that has the *right structure* — the version a later release can
grow without a rewrite. A trait system that handles one bound is v0.1. A trait
system that cannot ever express two is not.

---

## 2 · The gate — after **every** task, no exceptions

### 2.1 · Correctness first

```bash
./tools/bootstrap.sh --compiler build/<lastgood> --out build/<next>
./tools/bootstrap.sh --compiler build/<next>     --out build/<next2>
./build/<next> build src/main.psm -o build/a.ll
./build/<next2> build src/main.psm -o build/b.ll
cmp build/a.ll build/b.ll                                    # fixpoint

PRISMIO=$PWD/build/<next2> python3 tests/test_runner.py      # 175/175 or higher
python3 tools/aif_differential.py --compiler build/<next2>   # 18/18
python3 tools/check_source_lists.py
git diff --check
```

Plus, for anything touching allocation or the drop path:

- the `--verify` sweep over `tests/`, `aif/corpus/` and
  `aif/evidence/xlang/prismio/` — **`violations` first**, then `released`
  against `allocated`;
- **AddressSanitizer on every program whose emitted IR changed.** `--verify`
  balances on a read-after-free and reports `0 violation(s)` while the program
  segfaults — that is how a heap corruption survived on two platforms until
  2026-08-29. The recipe:

```bash
prismio build <src> -o out.ll
clang -fsanitize=address -g -O1 out.ll runtime/lang_runtime.c \
      runtime/program_support.c -Iruntime -o probe && ./probe
```

### 2.2 · The five-arm benchmark

**Every task ends with all five arms**, on the whole corpus, 25 runs,
checksums enforced:

| arm | what it is |
|---|---|
| **old Prismio** | the last-good compiler, before this task |
| **new Prismio** | after this task |
| **Prismio hand-tuned** | the same program written the way a Prismio expert would |
| **Rust idiomatic** | the honest peer |
| **Rust hand-tuned** | the ceiling |

```bash
python3 tools/milestone_bench.py --old build/<lastgood> --new build/<next2> \
    --runs 25 --label "<task>" --json aif/evidence/results-<task>.json

python3 aif/evidence/xlang/bench.py --compiler build/<next2> --runs 25 \
    --json aif/evidence/xlang/results-<task>.json
```

**The harness supports four of the five arms today.** `milestone_bench.py` gives
old / new / Rust idiomatic / Rust hand-tuned, and `xlang/bench.py` adds the Rust
arena arm. What is missing is a **Prismio hand-tuned arm for every corpus
program** — only `g1_dataview_tuned.psm` and `g2_tuned.psm` exist, against
`g1_tuned.rs`, `g2_tuned.rs`, `g3_tuned.rs` and more on the Rust side. Filling
that in is part of §4's corpus work, and until it is filled the fifth column is
"absent", never "equal".

**Rules that have already been paid for:**

- **Never run the suite and benchmarks concurrently.** They share fixed paths
  and caches; contention shows up as `aif exited -9` cascades.
- **Do not claim Prismio beats Rust without a controlled side-by-side.** When it
  loses, read the emitted IR *and the machine code* and name a concrete cause.
- **Price on the corpus, never on a model.** A synthetic model mispredicted the
  real program twice on 2026-08-29 — once by omitting a level of indirection,
  once by reversing sign (1.49× on the model, 1.80× *slower* on real g4).
- **Repeat before attributing.** A single sample plus a plausible mechanism is
  how g1's "1.083× regression" got written down; it was noise.

---

## 3 · The features

Ordered so each one makes the next cheaper. Every entry names **the seam**,
because finding it is most of the work.

### 3.1 · Method call syntax — **DONE 2026-08-29**

`x.f(a)` is `f(x, a)`, rewritten in `semaExpr` before overload resolution. The
parser already accepted the shape; the receiver was being read off as the name
and dropped. Everything downstream sees an ordinary call.

**Known limit**: a postfix `.` directly on a literal (`"a,b".contains(",")`) is
still a parse error — the receiver must be a name. Parser gap, worth closing
with §3.6.

### 3.2 · `impl` blocks

**Cheap now, because §3.1 exists.** A method *is* a free function whose first
parameter is the receiver, so an `impl` block is a **naming construct**, not a
second dispatch mechanism.

```prismio
impl String {
    fn trim(self) -> String { ... }
}
```

- **Seam**: parse `impl <Type> { fn ... }` as a top-level declaration and lower
  each method to a plain `fn name(self: Type, ...)`. `impl` and `trait` are
  **already reserved keywords** in `src/lexer/token.psm` and
  `src/parse/parser.psm`.
- **Why it matters beyond syntax**: it gives the standard library short names
  without a rename. `std/string.psm` has 46 `str*`-prefixed functions and **848
  call sites in `src/` alone** — the prefix exists because there is no
  namespacing. `impl String { fn trim(self) }` delegating to `strTrim` is
  additive and costs no churn.
- **Update**: `std/string.psm`, `std/map.psm`, `std/io.psm` gain `impl` blocks;
  the docs' language reference gains a page.

### 3.3 · Traits, and bounded generics

The first thing that is **not** sugar. Method syntax and overloading already
cover ad-hoc polymorphism — `std.io` has 28 `print`/`println` overloads. What is
missing is *abstraction over behaviour*, and `std/map.psm` documents the exact
price in its own header:

> *"Association list, not a hash table, and the reason is a missing language
> feature rather than a shortcut."* … *"the only operation the language can
> perform on every `K` it is instantiated at, which is `=="`* … *"Keys must be
> comparable with `==`, which means scalar keys."*

So `Map` is a **linear scan** and rejects `String` and struct keys. That is the
concrete thing traits buy.

- **Smallest right-shaped version**: `trait` declarations with method
  signatures; `impl <Trait> for <Type>`; **one bound per type parameter**
  (`fn sort<T: Ord>(...)`), resolved statically at monomorphisation. No dynamic
  dispatch, no associated types, no blanket impls — but the syntax must not
  preclude them.
- **Seam**: monomorphisation (`src/sema/generics.psm`) already specialises before
  type checking reaches the body. A bound is a check *at instantiation*, which is
  exactly where the concrete type is known.
- **Then**: `Map` becomes a hash table, `sort<T: Ord>` becomes writable, and
  `list.sort()` works. **Re-benchmark `Map` explicitly** — the linear scan is a
  measured cost this is meant to remove.

### 3.4 · Closures

Needed for `list.sortBy { ... }`, `map`, `filter` — the second half of what
makes a standard library feel modern.

- **Seam**: capture analysis, then lowering to a struct plus a function pointer.
  AIF has to be taught what a capture *is* — a captured binding escapes into the
  closure, which is an escape route the lattice does not currently model. **This
  is the item most likely to be underestimated.** Do it after traits, and expect
  the ownership work to dominate the syntax work.

### 3.5 · Module namespacing and visibility

`resolve_imports` flattens every module into one AST; file identity survives on
each node's `file` id, which is why diagnostics still name the right file, but
there is **no namespacing and no visibility**. That is why the standard library
is prefixed.

- **Seam**: `resolve_imports` in `src/main.psm`, plus name resolution in
  `src/sema/symbols.psm`.
- **Pairs with §3.2**: with namespacing, `string.trim` is available and the
  `str*` prefix can retire — but that is the 848-call-site rename, so it should
  happen *once*, deliberately, with byte-identical IR as the check.

### 3.6 · First-class pointers, and the parser gaps

`ASTNode.child1: Ptr` with `ptr_to_node`/`node_to_ptr` is the compiler routing
around its own missing feature. Also here: postfix `.` on a literal (§3.1), and
anything else `V1_GAP_ANALYSIS.md` §"central finding" lists as a workaround —
that table is the checklist.

### 3.7 · Package manager

Deliberately last and deliberately small: a manifest, a lockfile, a local path
dependency, and a registry-shaped fetch that need not have a registry behind it
yet. **The structure is the deliverable**; the network is not.

`ums/` already exists and `prismio build` with no source discovers `build.ums`,
so this extends something rather than starting one.

---

## 4 · The corpus must move with the language

**This is a standing instruction, not a task.** When a feature lands that makes
corpus or test code better, *rewrite that code to use it* — and say so in the
commit.

- If a program reads better with `impl`/traits, **use them**. The corpus exists
  to measure what a real Prismio program looks like, and a corpus frozen in the
  language of 2026-08 stops being that the moment the language moves.
- Every such rewrite must keep the program's **checksums identical**. That is
  what makes it a rewrite and not a different benchmark. Report old-vs-new for it
  like any other change.
- **Add the missing Prismio hand-tuned arms** (§2.2) as the features that make
  them expressible land. `g9`'s note already says a thread pool is what
  hand-tuned Rust has and Prismio *cannot express* — when it can, that arm gets
  written and the 1.45× gap gets re-measured.
- The files that move together with any language change: `tests/*.psm`,
  `tests/test_runner.py` (hardcoded manifest and leak expectations),
  `aif/corpus/*.psm`, `aif/evidence/xlang/prismio/*.psm`, `std/*.psm`,
  `bootstrap/prismio-seed.ll` **if the frontend changed** — new syntax lands in
  two steps, teach the frontend, refresh the seed, *then* use it in `src/` — and
  the sibling docs repo at `../docs/content/`.

---

## 5 · What "done" means for v0.1

1. Every item in §3 landed in its smallest right-shaped form.
2. `../docs/content/roadmap.md` reflects reality — no "Coming Soon" on anything
   shipped, and no "Implemented" on anything the matrix has not run green.
3. The three-platform CI matrix **observed green**, not merely expected to be.
   As of 2026-08-29: macOS green, Ubuntu green, Windows 172/175.
4. `V1_GAP_ANALYSIS.md`'s "central finding" table — the workarounds in the
   compiler's own source — is empty, or every remaining row has a reason.
5. The five-arm benchmark exists for every corpus program, and the standing
   against idiomatic Rust is recorded. As of 2026-08-29: **0.90×–1.81×**.
