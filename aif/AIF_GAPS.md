# AIF and memory gap tracker

Open holes in ownership, allocation, release, and the AIF analysis — plus the
checks that are supposed to catch them and do not.

This is a **working tracker**, not a results file. Measurements belong in
`aif/evidence/RESULTS-*.md`; what shipped belongs in `CHANGELOG.md`; broad
open issues belong in `KNOWN_ISSUES.md`. What lands here is narrower: a
specific memory-safety hole, a wrong or vacuous guard, or an invariant that no
longer holds, recorded the moment it is found so it is not rediscovered.

## How to use it

One `###` entry per gap. Every entry states:

- **What** — the invariant that is violated, or the check that is wrong.
- **Evidence** — the command and its output. Not a claim; a reproduction.
- **Blocking?** — yes means fix it before continuing; no means record and move on.
- **Status** — `open`, `fixed <date>`, or `invalid <why>`.

Two rules earned the hard way, both worth repeating because they cost whole
sessions:

- **A green check can be vacuous.** A fixture can pass while placing no arena at
  all. Assert the thing is present before asserting it is correct.
- **A proxy is not the property.** A check that counts a symbol is measuring a
  stand-in. When the stand-in and the property disagree, it is usually the
  check that is stale — see G-001, which is exactly that.

---

### G-001 — `aif_rc` asserts a proxy that no longer tracks its property

**What.** `run_aif_rc_test` in `tests/test_runner.py` documents a real and
load-bearing invariant: *an OPAQUE site must never be refcounted*, because the
pointer came back from a function this compilation cannot see, there is no
header in front of it, and `rc_release` would decrement whatever the real
allocator put there.

It then checks that invariant with a proxy — `src/main.psm` must emit **zero**
calls to `rc_alloc` — justified by "every one of the compiler's 37 T3 sites is
an opaque extern return". That justification has expired. UMS now has T3 sites
that are ordinary Prismio struct allocations, which are supposed to be
refcounted, so the proxy fires on correct code.

**Evidence.**

```
$ build/t10-fx2 build src/main.psm -o main_rc.ll
$ grep -c 'call ptr @rc_alloc' main_rc.ll
2

$ awk '/^define /{fn=$0} /call ptr @rc_alloc/{print fn}' main_rc.ll
define ptr @umsLinkInput__Enum_UmsLinkKind_String_Int_Int_Int(...)
define ptr @parseValue__Struct_UmsParser(ptr %0)

$ grep -E '^%(UmsLinkInput|UmsAstValue) = type' main_rc.ll
%UmsLinkInput = type { i32, i32, %prismio.str, i32, i32 }
%UmsAstValue  = type { i32, i32, %prismio.str, i32, i32 }
```

Both sites size their allocation from a declared Prismio struct
(`getelementptr (%T, ptr null, i32 1)`), which is the shape of memory this
compilation allocated *with* a header — not a foreign pointer being wrapped.
The documented invariant holds; only the proxy is wrong.

Pre-existing, and not caused by the T07–T10 trait work: the T06 baseline
compiler emits the same two.

```
$ build/t06-fx2 build src/main.psm -o main_t06.ll
$ grep -c 'call ptr @rc_alloc' main_t06.ll
2
```

**Blocking?** No. Nothing is mis-compiled and no memory is corrupted. But it is
the only failing test in the suite, so the suite is permanently red and a real
regression would land in a file nobody is watching. Worth fixing for that
reason alone, and the fix must check the documented property rather than relax
the count until it passes.

**Negative control.** The replacement guard was checked against two mutations of
the real IR, because a check that cannot fail is worse than no check:

| mutation | caught |
|---|---|
| `rc_alloc(i64 %opaque_len)` — a foreign pointer wrapped, not struct-sized | yes |
| `rc_alloc` sized from an undeclared `%NotDeclared` | yes |

**Status.** `fixed 2026-09-02` — the check now asserts the property directly:
every `rc_alloc` in the compiler must size a declared Prismio struct type. An
opaque extern return cannot take that shape, so the invariant the docstring
describes is what is now enforced, on the same program that was large enough to
violate it.

---

### G-002 — ownership annotations are not part of trait conformance

**What.** A trait may declare `fn consume(sink self)`, and an `impl` may satisfy
it with `fn consume(self)`. The annotations are parsed and then ignored by
conformance, so a trait cannot state an ownership obligation and generic code
behind a bound cannot rely on one. In a language whose defining feature is
explicit ownership, this is the trait system's largest hole.

**Evidence.**

```prismio
trait Consume { fn consume(sink self) -> Int }

// Accepted today. `sink` in the trait obliges nothing.
impl Consume for String {
    fn consume(self) -> Int { return 1 }
}
```

```
$ build/t10-fx2 check probe_conf.psm
$ echo $?
0
```

**Blocking?** No, and it was not a soundness bug on its own — the impl's own
signature is still checked where it is called. It was a missing guarantee, not a
wrong one.

**Status.** `fixed 2026-09-02` — conformance now compares each parameter's
convention and reports the one that differs, separately from signature matching
so the message is the convention rather than "no such method" for a method the
reader can see:

```
error: parameter `self` is `sink` in the trait, and a borrow
  --> probe_conf.psm:7:16
  note: the trait declares the convention here
  --> probe_conf.psm:3:16
```

Covered by `tests/test_109_trait_ownership.psm` (a trait each for `sink`,
`inout` and a borrow, all honoured) and `neg_95` / `neg_96` (each convention
quietly weakened to a borrow). Shipped as milestone **T18** in
[TRAIT_SYSTEM_ROADMAP.md](../TRAIT_SYSTEM_ROADMAP.md).

**Still open, deliberately.** Return-position `produce`/`alias` contracts are
not yet part of conformance — only parameter conventions are. A trait cannot yet
oblige an implementation to *return* an owned value rather than an alias, which
is the half that matters for `cli_arg`-shaped APIs. Tracked as G-003.


---

### G-003 — return-position ownership is not part of trait conformance

**Status.** `invalid 2026-09-02` — the premise was wrong, and checking the tree
before building against it is the only reason this did not become a feature
implemented for a case that cannot occur.

**What was claimed.** That a trait could state a return-position
`produce`/`alias` contract which conformance then failed to check, leaving the
`cli_arg` hazard reachable through a trait.

**What is actually true.** `parseFfiContract` is called in exactly two places —
`src/parse/decl.psm:633` for an extern parameter and `:668` for an extern return.
An ordinary function or trait method cannot carry a contract at all; the syntax
is refused before it reaches sema:

```
$ prismio check g3a.psm      # fn make() -> String produce { ... }
error[P3201]: expected `{` in block, found `produce`

$ prismio check g3b.psm      # trait Make { fn make(self) -> String produce }
error[P3201]: a `trait` holds `fn` signatures, `let` constants and `type`
              members, found `produce`
```

So there is no unchecked contract. Contracts describe an *FFI boundary*, where
the other side's convention is unknown and has to be stated. Inside Prismio a
return transfers, uniformly, and there is nothing for a trait to say about it.

**What remains, as a question rather than a defect.** Whether ordinary and trait
returns *should* be able to state ownership is a language design decision, not a
missing check — and it is only worth asking if a case appears where a Prismio
function wants to return something it does not own. None exists in this tree.
Recorded here so the next reader does not re-derive the claim from the same
plausible-sounding assumption.


---

### G-004 — a node field assigned a local String, and a field overwritten while aliased

**What.** Two ownership mistakes in compiler source, made together while writing
the T20 operator routing. Both are easy to reintroduce and neither points at
itself when it fails.

1. `callee.s1 = method` where `method` is a local `String`. A node field must own
   its string; the codebase idiom is `strClone`, and every other assignment of a
   local into a node field in `checker.psm` uses it.
2. `let op = expr.s1` … later `expr.s1 = "=="`. Overwriting the field frees the
   string `op` is still reading.

**Why it is worth an entry.** The failure did not appear at either site. It
surfaced as garbage inside *unrelated* diagnostics elsewhere in the same
compile:

```
error[P4001]: module `mo` declares no `q!`
error[P4001]: module `
```

A reader seeing that would start on the module-qualifier code, which is correct.
Nothing connects the symptom to a rewrite in the comparison path.

**Blocking?** It was — the compiler mis-reported eight errors on a valid program.
Fixed in the same pass.

**Status.** `fixed 2026-09-02`. The overwrite was removed rather than reordered:
comparing `eq(a, b)` against `true` lets `==` and `!=` each keep their own
operator, so `expr.s1` is never written at all. Not writing a field is a stronger
guarantee than writing it in the right order.

**How to catch the next one.** Garbage or truncated text in a diagnostic about
code you did not touch is a freed `String`, not a logic error in the code the
message names. Look for a node field assigned a local, or a field overwritten
while something still reads it.
