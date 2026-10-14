# async / await, and structured concurrency

The plan for `async fn`, `Future<T>`, `await`, `scope { }` and `spawn { }`, and the
record of what the first cut is and is not. It sits on the task runtime that
`spawn f(x)` and `join t` already were ([CHANNELS_PLAN.md](CHANNELS_PLAN.md) has the
channel half); what it adds is a way to write a task that does not start yet, and a
block that cannot be left until the tasks started in it are done.

## 1 · What a program writes

```
async fn fetchUser(id: Int) -> User { ... }

async fn run() -> Int {
    scope {
        let a = spawn { await fetchUser(1) }
        let b = spawn { await fetchUser(2) }

        let first = await a
        let second = await b
    }
    return 0
}
```

| Spelling | Meaning |
|---|---|
| `async fn f(...) -> T` | A function whose call is a `Future<T>`. Its body may `await`. |
| `f(x)` | **Lazy.** A `Future<T>` holding `x`; nothing runs. A future that is built and dropped does no work. |
| `await e` | The value of the future `e`. If `e` is an `async fn` call written right there, it is just the call. |
| `scope { ... }` | A block every task started inside is finished by the time it is left, on every path out. |
| `spawn { ... }` | A task whose body is the block, started now. Only inside a `scope`. Yields a `Future<T>`. |
| `spawn f(x)` | As before: `f` on a task, started now. `f` may be an `async fn`. |
| `spawn fut` | Starts a future that was built earlier, and is that future. |
| `join fut` | The synchronous `await`: a function that is not `async` runs a future with it. |

`async`, `await` and `scope` are **contextual** like `spawn` and `join`: `async` before
`fn`, `await` before a name, `scope` before `{` at the start of a statement. A variable
called any of them keeps compiling, and none of `src/`, `std/`, `tests/` or the corpus
used the words.

## 2 · The model, and why it is this one

**`Future<T>` is `Task<T>`.** One type, one runtime object, two spellings
(`Task<T>` is still accepted where a type is written, and the display name is `Future<T>`).
A `spawn f(x)` task has always been "a call, packaged, run on a thread"; a future is the
same package that has not been run yet. So:

- the **call** of an `async fn` is a `prismio_future_new(fn, rkind, n, a0, a1, a2)`: a task
  with its arguments in its three slots, `started = 0`;
- **`await`** on it runs the body *on the awaiting thread*, as a call (the task's state
  moves to started+joined, and the result is stored for a second await);
- **`spawn`** on it puts it on a thread, and **`await`** then joins the thread.

`async fn` itself is compiled as an ordinary function returning `T`. There is no state
machine and no second compilation of the body: the flag only changes what a *call* is.
That is also why **`await f(x)` of a direct call allocates nothing**: sema rewrites it to
the call (`JOIN_EXPR` → `CALL_EXPR`), with the ownership of any call, so
`let u = await fetchUser(1)` is leak-free and as fast as `fetchUser(1)`.

### Lowering

| Source | After sema |
|---|---|
| `await f(x)`, `f` async | `f(x)` (the `JOIN_EXPR` becomes the `CALL_EXPR`) |
| `f(x)`, `f` async, not awaited | `SPAWN_EXPR` with `i2 = 1` around a copy of the call → `prismio_future_new` |
| `spawn f(x)` | `SPAWN_EXPR`, `i2 = 0` → `prismio_task_spawn` (`prismio_scope_spawn` inside a scope) |
| `spawn { b }` | the block lifted to `fn Spawn$L$N(captures...) -> T`, flagged async; then `spawn Spawn$L$N(captures)` |
| `spawn fut` | `SPAWN_EXPR`, `i2 = 3` → `prismio_task_start(scope, fut)` |
| `await fut` / `join fut` | `JOIN_EXPR` → `prismio_task_join*`, which runs an unstarted task inline |
| `scope { b }` | `REGION_STATEMENT` with `i3 = 1` → `prismio_scope_new` … `prismio_scope_end` |

A `spawn { }` block is lifted rather than turned into a closure: a closure is a struct and
a method, and a task wants a function and three words. The captures *are* the task's
arguments, so they are moved into it exactly as `spawn f(x)` moves `x`, and the body
borrows them exactly as a parameter does. At most three.

### Scalars

A task is started through three `void*` slots and answers through an `i32`, a word or
nothing. `async fn half(x: Float) -> Float` needs neither a scalar slot nor a Float lane in
the runtime: the function is called through a thunk (`name__task`) that has the runtime's
shape and converts each argument and the result with `scalarToSlot` / `slotToScalar`, the
conversions a `Vec` already uses. `functionNeedsTaskThunk` decides; a function whose
arguments are all references and whose result is an `Int`, a reference or nothing (every
function a program could spawn before this) gets no thunk and the same IR as before.

### `scope`

`prismio_scope_new` makes a list; a `spawn` inside registers its task with the innermost
one; `prismio_scope_end` awaits each and drops the scope's reference to it. The end is
emitted on **every** way out. A scope takes a *region level* (`ir_region_enter`), the
counter that already says which arenas an `return`, `break` or `continue` leaves, so an exit
that leaves a scope and an arena closes them in order and a scope needs no mechanism of its
own to be left correctly. Tasks are reference counted (`refs`): the binding that got the
handle and the scope each hold one, so the handle's drop and the scope's end may come in
either order. A `spawn { }` used as a statement releases its own reference at once.

## 3 · What it does not do (and why)

- **`await` blocks a thread.** A task that awaits a future that is running on another thread
  waits in `pthread_join`. There is no scheduler to hand the thread back to, because there
  is no state machine to suspend: that is the next stage, below. What this stage gives is
  the *semantics* (laziness, structured scope, cancellation by never starting) and real
  parallelism for `spawn`; what it does not give is "a million tasks on eight threads".
- **At most three arguments for a held future or a task**; `await f(a, b, c, d)` is only a
  call and takes any number. Pack the rest in a struct.
- **A task's result that is a struct or a String is not freed by the awaiter** when it came
  through a *handle* (`let a = spawn { ... }; let v = await a`). `join` has always done this
  (`tests/test_69_task_results.psm` leaks the same way); `await f(x)` does not, because it
  is a call. Fixing it means teaching the AIF solver that a join yields the callee's return
  sites, which also moves the Python oracle's `T` distribution; see KNOWN_ISSUES.
- **A capture is a borrow inside the body**: it cannot be assigned to or consumed by a
  `sink` parameter. A task that needs a mutable value declares a local copy.
- **A `spawn { }` block cannot borrow** from the enclosing function, only take: sharing a
  value across tasks needs the sharing rules `chan_share` exists for.
- **Freestanding.** `await f(x)` of a direct call is a call and needs nothing, but a held future,
  `spawn` and `scope` need the hosted task runtime (`--freestanding` has no threads). A program
  that only awaits calls never enables the runtime's thread mode either.
- **No cancellation beyond "not started".** A future that is never awaited never runs; a
  task that has started runs to the end. A `scope` waits, it does not stop.

## 4 · Later

1. **A worker pool** under `prismio_task_begin`, so that `spawn` is a queue push and
   `prismio_scope_end` helps run tasks while it waits. Nothing in the language changes.
2. **Suspendable `await`**: compile an `async fn` that contains an `await` of something that
   may wait (a channel, a timer, I/O) to a state machine, so the thread goes back to the
   pool. The lowering above is the interface it has to keep: a call yields a task, `await`
   runs or joins it.
3. **Join results owned** (above), then `select` over futures and `timeout`.
4. **More than three arguments**, by packing into a heap record the thunk unpacks.

## 5 · Tests

`tests/test_289_async_await.psm` (laziness at two exact lines, scalar results, methods,
generics, recursion, a `Vec` of futures, `join` as the synchronous bridge),
`tests/test_290_scope_spawn.psm` (the scope waits on fall-through, `return`, `break`,
`continue` and when nested; captures; detached tasks; `spawn fut`) and
`tests/neg_271` … `neg_278` for each diagnostic.
