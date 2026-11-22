# What Xefy needs from Prismio

Written 2026-11-12. This is a planner in the style of the other `docs/*_PLAN.md` files: what
the language, the standard library and the toolchain are missing for Xefy, in the order to
build it. Nothing in it is built. Where a row is already tracked in another plan, this file
names that row and adds only what Xefy changes about its priority or its shape.

**Xefy** is a cross-platform UI framework written in Prismio (`../../Xefy`): a Jetpack
Compose-style declarative API over a retained render tree, Skia for 2D, bgfx for 3D scenes,
and one native embedder per platform behind a C ABI. Its second target is a desktop OS on the
Linux kernel, where the framework ships as a system library and apps are ELF executables in a
bundle. It is the first large program written against Prismio that is not the compiler, so it
is also the first that needs callbacks that outlive a call, trees of mixed node types, shared
mutable state, and a library artifact.

## How this list was made

1. The rows of `LANGUAGE_GAPS_PLAN.md`, `INTEROP_PLAN.md` section 1.1, `KNOWN_ISSUES.md` and the
   "Not in 0.2" sections of `../website/apps/docs/content/language/*.md`, read against what a
   Compose-style framework does.
2. A probe: each feature written as a small `.psm` and run through `prismio check` with the
   installed toolchain (`prismio 0.2.0`, `llvm 23.1.5`, macOS arm64, 2026-11-12). **Probed**
   means the compiler's own answer, quoted. **Per docs** means the documentation says so and no
   probe was run. Sources are in the [appendix](#appendix-the-probes).

A probe that fails proves the spelling tried is not accepted, not that no spelling exists.

## What already works (do not rebuild)

Probed OK:

- **Nested block closures as content.** `Column(|| { Text("a")  Column(|| { Text("b") }) })`
  checks with `fn Column<F>(content: F)`. The shape of a Compose tree is expressible today; what
  is missing is the sugar and the ability to keep the closure.
- **Generic methods on a struct with a closure bound**: `fn remember<T, F: Fn() -> T>(self, init: F) -> T`.
- **A tree of one node type**: `struct Node { parent: Node?, kids: Vec<Node>, w: F32 }`.
- **Enum-dispatched polymorphism**: an enum whose variants hold structs, matched and forwarded
  to a trait method. This is the workaround for X7 below.
- **`F32`**, which is what Skia's `SkScalar` is.
- **`export fn` plus `functionAddress("name")`** (`std.raw`): a top-level function's address as a
  `Usize`, handed to C as a callback. `Xefy/engine/src/main.psm` drives its whole host this way.
- **C++ in a `native` block**: `Xefy/engine/build.ums` lists `src/platform_macos.cpp` with
  `-xobjective-c++` and the built `.app` bundles are in `Xefy/engine/dist`. Not re-run here.
  `INTEROP_PLAN.md` 1.1 still says user docs reject `.cpp`; one of the two is stale.
- **`--freestanding`**, which Xefy's OS work may use for early boot and nothing else. Apps on
  the OS are hosted Linux programs.

## The gaps

Priority is Xefy's, not the language's: **P0** blocks the Compose API or the first shipped
platform, **P1** blocks a later milestone or forces a workaround that leaks into user code,
**P2** is polish.

### A. The Compose surface

What a user of Xefy writes. Today's nearest spelling is at the end of the section.

| # | Gap | Evidence | Tracked as | Pri |
|---|---|---|---|---|
| X1 | **Function types, and a closure that can be stored.** `onClick` must outlive the call that built the button; a recomposition scope keeps its content closure to re-run it. Needs a spellable type (`fn() `, `fn(Int) -> Bool`) usable as a struct field, a `Vec` element and a return type, with an owned (boxed) representation | Probed: `struct Button { onClick: fn() }` gives `P3201 expected IDENTIFIER in field name, found (`. `closures.md` "Not in 0.2" | GAPS C2; INTEROP D8 "retained callbacks" | P0 |
| X2 | **Trailing closure syntax.** `Column { ... }` and `Button(onClick = save) { Text("Save") }`: a block after a call is that call's last closure argument | Probed: `Column { let x = 1 }` gives `P3201 expected IDENTIFIER in struct literal field, found let`. The block is read as a struct literal, so this is a grammar decision, not only an addition | new | P0 |
| X3 | **Default and named arguments.** A composable has many optional parameters (`Text(value, size, color, weight, maxLines, ...)`); positional-only calls are unreadable and every new parameter breaks every caller | Probed: `size: Int = 14` gives `P3201 expected ) in params, found =`; `size: 3` at the call gives `expected ) in function call, found :` | GAPS C3 (P2 there) | P0 |
| X4 | **Attributes, and the composable transform.** A composable call needs an implicit composer and a key that identifies its call site, so `remember` finds last frame's value. Kotlin does this in a compiler plugin. See [the design note](#x4-the-composable-transform-design-note) for a smaller first step | Probed: `@Composable` gives `P3201 expected a declaration, found @`. `#` is rejected by the lexer (GAPS C4). `macros.md`: no macro system | GAPS C4 | P0 |
| X5 | **Inferred closure parameter types.** `items(todos) { todo -> Row(todo) }` rather than `\|todo: Todo\|` on every lambda | Per docs: `closures.md` "Not in 0.2" | GAPS C2 | P1 |
| X6 | **A closure that mutates what it captured.** Captures are by value, so `run(\|\| { count = count + 1 })` checks, builds and leaves `count` at 0 with no diagnostic. In UI code this is the most natural way to write an event handler, and it silently does nothing | Probed: the program returns 0 | new | P0 for the diagnostic, P1 for by-reference captures |
| X6b | **A receiver-scoped block**, so `Column { }`'s content sees `weight()` and `align()` and `Row { }`'s sees a different set (Compose's `ColumnScope`). An explicit `\|scope: ColumnScope\|` parameter works once X1/X2 exist; this row is the sugar | Not probed | new | P2 |

**X6 needs a decision before code**, because the fix for the silent case is cheap and the full
feature is not: an assignment to a captured local inside a closure body can be an error today
(the copy is never read back), independent of whether by-reference captures ever arrive.

What X1 to X4 buy, side by side. Today, from `Xefy/engine/src/main.psm`:

```prismio
let screen = Column(vecOf(
    Text("Xefy Text", 30, 0x7D73FF, true),
    TextEditor(document, cursor, 260)
), 12, 28)
Compose(screen, width, height)

export fn handleEvent(id: Int) { ... }      // every button routed by a hand-assigned Int
```

The target (illustrative syntax):

```prismio
@Composable
fn Counter() {
    let count = remember { stateOf(0) }
    Column(spacing = 12.dp, padding = 28.dp) {
        Text("Clicked {count.value} times", size = 30.sp, weight = Bold)
        Button(onClick = { count.value += 1 }) { Text("Add") }
    }
}
```

### B. Trees and state

| # | Gap | Evidence | Tracked as | Pri |
|---|---|---|---|---|
| X7 | **An owned trait object.** A render tree holds nodes of many types (`RenderFlex`, `RenderParagraph`, ...) as children of one another; a modifier chain is a list of different modifier types. `dyn Trait` is a borrow, parameter position only | Probed: `struct Tree { kids: Vec<dyn Node> }` gives `P4001 dyn Node cannot be a struct field: a trait object is a borrow and cannot outlive the call it is passed to` | new | P0 |
| X8 | **Shared ownership with interior mutation, and a weak reference.** One `State<T>` is read by several composables and written by an event handler; a render node points back at its parent; the composer holds every live state. A struct moved into one owner is gone for the next | Probed: `A { s: s }` then `B { s: s }` gives `P4001 use of moved value s`. No `Rc`, `Weak` or `Cell` in `std/` | new; touches AIF tier 4 (reference count), which the compiler picks but a program cannot ask for | P0 |
| X9 | **Operator overloading.** `Offset + Offset`, `Size * scale`, `Rect == Rect`, `Dp + Dp`. Geometry code is most of a layout engine and reads as noise without it | Probed: `a + a` on a struct gives `P4001 operator + requires numeric operands` | GAPS C1 | P1 |
| X10 | **Extension members on a built-in type**, for units: `12.dp`, `30.sp`, `0.5.seconds` | Probed, one spelling: `impl Int { prop dp: Dp { ... } }` gives `P3201 expected ( in params, found :`. Whether `impl Int` with an `fn` is accepted was not probed | new | P1 |
| X11 | **Type aliases**: `type Color = U32`, `type Content = fn()` | Probed: `P3201 expected a declaration, found type` | GAPS A9 | P1 |
| X12 | **Field defaults and struct update.** A style or constraints struct with 20 fields where a caller sets two; `style.copy(size = 14)` | Per GAPS probes | GAPS A6, A5 | P1 |
| X13 | **Compound assignment on a field or index**: `count.value += 1`, `offset.x += dx` | Per GAPS probe | GAPS A8 | P1 |
| X14 | **Re-exports**, so `import xefy` gives an app the whole public surface instead of a dozen imports per file | Per docs: `modules.md` "Not implemented" | GAPS C7 | P1 |
| X15 | **Generic methods declared by a trait** (`trait Modifier { fn fold<R, F: Fn(R, Element) -> R>(...) }`) | Per docs: `traits.md` "Not in 0.2" | new | P2 |
| X16 | **A thread-local**, for the current composer and the current snapshot. X4's implicit parameter removes the first need; the snapshot system still wants one | Probed, one spelling: `thread let mut` gives `P3201 expected a declaration, found thread` | new | P2 |

| X40 | **A global that holds a runtime value.** A global is a literal, so there is no process-wide composer, state store or render tree: a `Vec`, a struct and even `none` are refused. Everything the framework keeps between frames must be a local in `main` and be passed down every call | Probed: `let mut ints: Vec<Int> = []` and `let mut store: Store? = none` both give `P4001 global ... needs a constant initializer` | new; X16 is the same need per thread | P0: it decides the interim API's shape (an explicit `scope` parameter on every composable) and rules out C callbacks, because an `export fn` has nowhere to find the framework's state |
| X41 | **A small handle struct is moved into a closure, not copied.** `struct Handle { id: Int }` captured by one content closure is dead for the next statement, so a state handle has to be a bare `Int` and the type system cannot tell a state id from a node id | Probed: `let count = rememberInt(0)` used in two closures gives `P4001 use of moved value count` | new: a way to declare a struct `Copy` by value (scalars and enums already are) | P1 |

X7 and X8 are one design question seen twice: both are "a value on the heap that more than one
place can reach, whose type the holder does not fully know". The memory model already has a
reference-counted tier; what is missing is a way to *spell* a value that must live there. Decide
them together.

### C. The native boundary

Xefy's engine is C++ (Skia) and C (bgfx's `c99/bgfx.h`) behind one C header, `xefy_engine.h`.
The Prismio side is several hundred `extern fn` declarations.

| # | Gap | Evidence | Tracked as | Pri |
|---|---|---|---|---|
| X17 | **Small integers reach C unextended.** Colours, flags, key codes and booleans cross this boundary on every draw call. Xefy can dodge it by declaring every parameter `Int`/`U32`, which is a rule that will be broken once | `KNOWN_ISSUES.md`: `widen(301 as U8)` returns 301 on macOS arm64 | INTEROP step 0 | P0 |
| X18 | **Structs by value to and from C.** `SkRect`, `SkPoint`, `SkMatrix`, `SkColor4f` are passed and returned by value by every Skia-shaped C API; today each needs an out-pointer wrapper written by hand | `INTEROP_PLAN.md` 1.1: "Always by pointer" | INTEROP step 1 | P1 |
| X19 | **Import a C header.** bgfx's C99 API is about 200 functions and Xefy's own header will pass that; hand-written externs for both, kept in step with two headers, is where ABI bugs come from | `INTEROP_PLAN.md` 1.1: "None; every extern fn is written by hand" | INTEROP step 3 | P1. Until then Xefy generates externs with a Python script |
| X20 | **A callback that carries state.** `functionAddress` covers a top-level function. A closure handed to the embedder (a timer, a platform channel reply) needs the trampoline and the boxed closure | `INTEROP_PLAN.md` D8 | INTEROP D8; depends on X1 | P1 |
| X21 | **Prismio code on a thread Prismio did not create.** The embedder calls `export fn`s from the platform's main thread and from a vsync or raster thread it owns. Each must call `prismio_memory_thread_enter` first, and that is not a documented public surface | `INTEROP_PLAN.md` D10 | INTEROP D10 | P0: document and expose it, or make the slab's lookup lazy |

### D. Artifacts and targets

| # | Gap | Evidence | Tracked as | Pri |
|---|---|---|---|---|
| X22 | **A path or package dependency on the import search.** Xefy is a framework: an app in its own directory imports `xefy.*` from an installed SDK. Today the only way is to vendor the framework's source below the app's entry root | Per docs: `modules.md` "a resolved path dependency is not yet on the import search" | GAPS E3 | P0 |
| X23 | **Shipping a library as a `.plib`** that a program outside the Prismio tree consumes, with generics intact. `std` does this; whether a third party can is untested (`KNOWN_ISSUES.md`: "Almost nothing in `../tests` reads a `.plib`") | Per docs | new | P0, with X22 |
| X24 | **Cross-compiling a hosted program.** Building a Linux app from macOS | Probed: `--target aarch64-unknown-linux-gnu` gives `Missing runtime module: lib/runtime/aarch64-unknown-linux-gnu/lang_runtime.bc`. Same for `x86_64-unknown-linux-gnu`, `-musl`, `x86_64-pc-windows-msvc` | new: per-target runtime packs, and a sysroot story | P1 |
| X25 | **Emitting a static or shared library.** The OS ships `libxefy.so` once and every app links it, as Apple's frameworks do; an embedder that owns `main` (Android, iOS) loads the app as a library | `calling-c.md`: "A `library(...)` target is validated, and emitting the artifact is not implemented yet" | INTEROP step 2 | P1 |
| X26 | **A stable ABI across compiler versions**, for X25's shared library to survive an OS update without rebuilding every app. Includes: one runtime per process (INTEROP D10's "block allocated by A must be freed by A"), frozen layout for public structs, and generics across the boundary | `ffi.md`: "a stable cross-version Prismio ABI [is] not implemented" | new | P2, but it decides the OS design. Until it exists the OS links Xefy statically into each app |
| X27 | **musl and static linking on Linux**, for app bundles that do not depend on the host's glibc version (today: programs need glibc 2.34) | Probed with X24 | LINUX_PLAN | P1 |
| X28 | **Android and iOS targets.** No runtime, no triple | Probed: `aarch64-linux-android`, `aarch64-apple-ios` fail as X24 does | new | P2 |
| X29 | **A custom artifact step after link**, so the bundle (`.app`, `.xapp`) is part of `prismio build`. `build.ums` commands may already cover this; not checked | Not probed | ums | P2 |

### E. Concurrency

Xefy runs three threads the way Flutter does: platform, UI and raster. It can start on one.

| # | Gap | Evidence | Tracked as | Pri |
|---|---|---|---|---|
| X30 | **Mutexes and atomics.** The UI thread hands a finished layer tree to the raster thread; the vsync thread sets a flag the UI thread reads | `concurrency.md` "Not implemented" | GAPS D5 | P1 |
| X31 | **A non-blocking receive and `select`.** The UI thread's loop waits on input, vsync and task completion at once | `concurrency.md` | GAPS D5; CHANNELS_PLAN | P1 |
| X32 | **An `await` that gives its thread back**, driven by a loop the program owns. `LaunchedEffect { let user = await fetch() }` must not block the UI thread, and its continuation must run on it | `concurrency.md`: "A task is an operating-system thread" | ASYNC_PLAN | P1 |
| X33 | **Cancellation.** A coroutine started by a composable is cancelled when the composable leaves the tree | `concurrency.md` | GAPS D5 | P1 |
| X34 | **Timers and a monotonic clock in `std`** | roadmap | GAPS D4 | P1 |
| X35 | **A struct or String returned through a task handle leaks** | `KNOWN_ISSUES.md` Concurrency | KNOWN_ISSUES | P1: image decode and file loads return exactly this |

### F. Tooling

| # | Gap | Evidence | Tracked as | Pri |
|---|---|---|---|---|
| X36 | **Hot reload.** The reason people choose Flutter and Compose. `prismio run --jit` exists; what is needed is reloading changed functions into a running process and keeping its state | Not probed | new | P1 |
| X37 | **Doc comments a tool can extract**, for the framework's API reference | `lexical-structure.md` | GAPS D6 | P2 |
| X38 | **A test attribute and a test runner a package can use**, for widget tests | Probed with X4 | GAPS C4 | P2 |
| X39 | **Editor support for every new syntax here**: the language server, the formatter, the VS Code grammar and the JetBrains lexer. X2 changes how `Name {` parses, which all four hard-code | `LANGUAGE_GAPS_PLAN.md` constraints | per item | with each item |
| X42 | **Check a string literal at compile time.** Xefy styles components with utility class strings (`"p-4 bg-surface hover:bg-primary"`, Xefy decision 0017). A misspelt class is a run-time warning today. A `const fn` over a string literal that can reject it, or a hook for a checked string-literal kind, would make it a compile error | `macros.md`: no compile-time execution over strings; a `const` cannot hold a `String` | new | P1 |

## Defects found while building Xefy

Bugs in what exists, as opposed to features that do not. Each was hit by Xefy code and has a
workaround in that code; each belongs in `KNOWN_ISSUES.md` once triaged.

### XD1: a `String` reassigned in a branch and then moved into a returned struct reads as garbage

Found 2026-11-12 writing `Xefy/xefy/cli/src/create.psm`, reproduced the same day with the
installed 0.2.0 on macOS arm64:

```prismio
import std.io
import std.string

struct Opts { error: String }

fn parse(flag: Int) -> Opts {
    let mut error = ""
    if (flag == 1) { error = "missing app name" }
    return Opts { error: error }
}

fn main() -> Int {
    let a = parse(1)
    println("[" + a.error + "]")        // prints [[[[[[[[[[[[[[[[[]
    let b = parse(0)
    println("[" + b.error + "]")        // prints [] : correct
    return 0
}
```

Expected `[missing app name]`. The branch that is **not** taken is fine; the one that assigns a
second literal returns a `String` whose bytes are not the literal's. The program does not crash,
and the session that found it reports that a `--verify` build of the same shape showed 0
violations, so the ledger does not see it (that half was not re-run here). It looks like the
binding's storage being released or reused at the reassignment while the struct field still
points at it: the same family as the `KNOWN_ISSUES.md` entry on a payload assigned to a
variable declared above a `match`, but this one reads freed or foreign memory instead of
leaking.

- **Severity:** P0 for the language. It is silent wrong output from five ordinary lines, and
  "collect an optional error message, then return it in a result struct" is how most argument
  and config parsing is written.
- **Workaround in Xefy:** `cli/src/create.psm` returns error strings directly from helper
  functions and tracks argument positions as `Int`s. Initialising with `"x".clone()` instead of
  a literal also avoided it.
- **Not yet known:** whether it needs the struct (or a bare `return error` shows it), whether
  the first value must be a literal, and whether Linux behaves the same.

Two smaller things from the same session, neither a defect: a `const` cannot hold a `String`
(only integers and `Bool`), and a `String` moved in one branch of an `if` (`created.push(to)`)
is reported leaked by `--verify` on the other branch unless the value is built inside each branch.

## X4: the composable transform, design note

The full Kotlin design rewrites every composable: a hidden `Composer` parameter, a group
start and end around the body, a key per call site, parameter comparison so an unchanged call
is skipped, and a restart lambda so one function re-runs alone. That is a compiler pass of its
own and should not be the first step.

A first step that is two small features and no pass:

1. **An implicit parameter.** A function marked composable has a hidden first parameter, and a
   call from one composable to another forwards it. This is a desugar in sema, in place, like
   `src/sema/enum_struct_variants.psm`: after it, type checking and codegen see ordinary
   functions with one more parameter. A call from a non-composable function is an error, which
   is the rule Compose has too.
2. **A call-site key intrinsic.** A builtin that folds to a distinct integer constant per source
   position (a hash of module, line and column), read by the callee from the hidden parameter.
   `remember` uses it to find its slot. Loops add an index key in the framework, not the compiler.

With those two, Xefy's composer, slot table and recomposition are library code. Skipping and
per-function restart are optimisations that can come later as a real pass, behind the same
source syntax.

The marker's spelling is a language decision: an attribute (`@Composable`, which needs GAPS C4
and a free `@`), or a modifier keyword (`composable fn`). A general attribute system is the
larger investment and also serves `#[test]` and derive.

## Order of work

Each step names the Xefy milestone it unblocks, so the two projects can be scheduled together.

| Step | Items | Unblocks in Xefy |
|---|---|---|
| 1 | XD1 (the `String` defect), X17 (integer extension), X21 (foreign threads), X22 + X23 (framework as a package), X40 (a global that holds a runtime value) | The engine boundary and a framework that lives outside the app's tree. Everything else can be worked around; these cannot |
| 2 | X7 + X8, designed together (owned trait object, shared handle, weak) | The render tree port from Flutter's `rendering/` and a real `State<T>` |
| 3 | X1 (function types, stored closures), then X6's diagnostic | Event handlers without integer ids; recomposition scopes |
| 4 | X3 (default and named arguments), X2 (trailing closure) | The Compose API reads like Compose |
| 5 | X4 steps 1 and 2 (implicit parameter, call-site key) | `remember`, recomposition, the first public API |
| 6 | X9, X11, X12, X13, X14, X10 | Geometry and style code; `import xefy` |
| 7 | X30 to X35 | A raster thread; effects and async loading |
| 8 | X18, X19, X20 | Dropping the generated externs and out-pointer shims |
| 9 | X24, X27, X25 | Linux builds from macOS; the OS bundle; embedders that own `main` |
| 10 | X36, then X26, X28 | Hot reload; a shared system framework; mobile |

Steps 3, 4 and 5 are new syntax, so each goes through the seed two-step before the compiler's
own source may use it.

## What Xefy does until then

So that the framework is not idle while the language moves. Everything here was run on 0.2.0
(the last probe in the appendix), including under `--verify` with 0 bytes live at exit.

- **No global state (X40):** `main` owns one `Scope` value and every composable takes it as its
  first parameter. A struct passed to an ordinary parameter is borrowed and its fields are
  assignable through the borrow, so `scope` is threaded, never captured.
- **Content closures (X1, X2):** a container takes a generic `F` and calls it inside the call,
  passing `scope` back in: `Column(scope, |scope: Scope| { Text(scope, "a") })`. Nothing is stored.
- **Event handlers (X1, X6):** immediate mode. A control answers whether it was activated since
  the last frame: `if Button(scope, "Add") { ... }`. No closure outlives a call and nothing is
  routed by a hand-assigned id.
- **State (X8, X41):** values live in typed pools inside `Scope` and are addressed by a bare `Int`
  handle (`let count = rememberInt(scope, 0)`, `getInt(scope, count)`, `setInt(scope, count, v)`), which a
  closure copies. A slot is found by its position in the parent, with an explicit key for loops.
- **Optional parameters (X3):** overloads by parameter count (`Text(scope, s)`, `Text(scope, s, modifier)`),
  and a `Modifier` value built by chained methods that each take and return it.
- **Mixed trees (X7):** one `enum` with a struct variant per node type, held in a `Vec` and
  addressed by index; a parent is an index too. Closed to third-party node types.
- **The event loop (X40, X20):** the engine's C ABI is pull-style. `main` calls
  `xefy_app_poll_event` in a loop and draws between `begin_frame` and `end_frame`; there are no
  callbacks into Prismio at all.
- **Externs (X19):** generated from `xefy_engine.h` by a Python script; every parameter 32 bits
  or wider (X17).
- **Framework distribution (X22):** `xefy create` copies or symlinks the framework source below
  the app's entry root.

The explicit `scope` parameter, the `Int` handles and the copied framework source reach user code.
That is why steps 1 and 3 to 5 come before a public release of Xefy: the interim API is what the
framework is built and tested on, not what it ships.

## Open decisions

1. **X2 and struct literals.** `Name { ... }` is a struct literal today. Options: decide by
   what `Name` resolves to (a function means a trailing closure), or require a distinct spelling.
   The first needs name resolution before the block is parsed, or a parse that defers.
2. **X7/X8: what the user writes for a shared heap value.** A library type (`Shared<T>`,
   `Weak<T>`, `Box<dyn Trait>`) backed by the reference-count tier, or a declaration-site marker
   on the struct. This is the largest design question in the file and it is AIF's, not Xefy's.
3. **X4's marker**: attribute or keyword.
4. **X6**: reject an assignment to a captured local now, or wait for by-reference captures.
5. **X26**: whether Prismio commits to a stable ABI at all before 1.0. If not, Xefy's OS links
   the framework statically and X25 is only for embedders that own `main`.
6. **X1's representation**: one boxed closure type with an indirect call, or a function type
   that is generic sugar where the closure does not escape and boxed where it does.

## Done when

- The target `Counter` composable in section A compiles as written, modulo the spellings
  decided in *Open decisions*.
- A Xefy app in its own directory builds against an installed framework with no framework
  source below its entry root.
- The render tree holds user-defined node types.
- A Linux x86-64 app bundle builds on macOS arm64.

## Appendix: the probes

Run 2026-11-12 with `prismio check` (0.2.0). Each is a whole file apart from an empty `main`
where one is not shown.

```prismio
// X1
struct Button { onClick: fn() }

// X2
fn Column<F>(content: F) { content() }
fn main() -> Int { Column { let x = 1 }  return 0 }

// X3
fn Text(value: String, size: Int = 14) -> Int { return size }
fn main() -> Int { return Text("a", size: 3) }

// X4
@Composable
fn Greeting() { }

// X6: checks, builds, exits 0
fn run<F>(f: F) { f() }
fn main() -> Int {
    let mut count = 0
    run(|| { count = count + 1 })
    return count
}

// X7
trait Node { fn paint(self) -> Int }
struct Tree { kids: Vec<dyn Node> }

// X8
struct State { value: Int }
struct A { s: State }
struct B { s: State }
fn main() -> Int {
    let s = State { value: 1 }
    let a = A { s: s }
    let b = B { s: s }
    return b.s.value
}

// X9
struct Offset { x: F32, y: F32 }
fn main() -> Int {
    let a = Offset { x: 1.0, y: 2.0 }
    let b = a + a
    return 0
}

// X10
struct Dp { v: F32 }
impl Int { prop dp: Dp { return Dp { v: self as F32 } } }

// X11
type Dp = F32

// X16
thread let mut current: Int = 0

// X24, X28
// prismio build plain.psm --target <triple> -o out
```

Probed OK (see *What already works*):

```prismio
import std.io
fn Column<F>(content: F) { content() }
fn Text(s: String) { println(s) }
fn main() -> Int {
    Column(|| {
        Text("a")
        Column(|| { Text("b") })
    })
    return 0
}

struct Composer { n: Int }
impl Composer {
    fn remember<T, F: Fn() -> T>(self, init: F) -> T { return init() }
}

import std.raw
export fn onFrame(w: Int, h: Int) { }
fn main() -> Int {
    let a: Usize = functionAddress("onFrame")
    return 0
}
```

The interim shape described in *What Xefy does until then*, which runs and is clean under `--verify`:

```prismio
import std.io
import std.string
import std.vec

enum Node { Text { label: String, parent: Int }, Box { parent: Int } }
struct Scope { ints: Vec<Int>, nodes: Vec<Node>, parent: Int, clicked: Bool }

fn rememberInt(scope: Scope, init: Int) -> Int {
    scope.ints.push(init)
    return scope.ints.length - 1
}
fn getInt(scope: Scope, h: Int) -> Int { return scope.ints[h] }
fn setInt(scope: Scope, h: Int, v: Int) { scope.ints[h] = v }

fn Column<F>(scope: Scope, content: F) {
    let saved = scope.parent
    scope.nodes.push(Node.Box { parent: saved })
    scope.parent = scope.nodes.length - 1
    content(scope)
    scope.parent = saved
}
fn Text(scope: Scope, s: String) { scope.nodes.push(Node.Text { label: s, parent: scope.parent }) }
fn Button(scope: Scope, label: String) -> Bool { return scope.clicked }

fn App(scope: Scope) {
    let count = rememberInt(scope, 0)
    Column(scope, |scope: Scope| {
        Text(scope, "count " + getInt(scope, count).toString())
        if Button(scope, "Add") { setInt(scope, count, getInt(scope, count) + 1) }
    })
}
```

```prismio
// X40
import std.vec
let mut ints: Vec<Int> = []

// X41
struct Handle { id: Int }
// let count = Handle { id: 0 }, then two closures that each read count.id
```

Two spellings that failed for a reason other than the feature: `F: Fn()` with no result type
gives `P3201 expected -> in a closure bound's result type, found >` (a bound on a closure that
answers nothing cannot be written; use a plain `F`), and a generic struct literal holding a
closure, `Holder { f: || 42 }`, gives `P4001 unknown struct Holder`.
