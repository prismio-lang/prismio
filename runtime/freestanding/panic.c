// The failure half of the runtime, with no C library under it.
//
// A program built with `--freestanding` does not link the installed runtime,
// because the installed runtime is libc code: its failure paths call `fprintf`
// and `exit`. Generated code still calls the same six functions when something
// goes wrong, so a freestanding program has to define them. These are those six,
// each reduced to one call: `prismio_panic_hook`, which the program provides.
//
// `--freestanding` adds it to the build. It includes nothing, so it needs no sysroot
// and no headers. **Every function here is weak**, so a program may define any of
// them itself -- a different message, a trap into a debugger -- and the program's
// definition wins without a duplicate-symbol error.
//
// The signatures are the ones in lang_runtime.c and the ones codegen declares
// (`ir_checked_binop` in llvm-api-backend.c for the first). Change one place and
// the other builds a call that passes the wrong arguments, and nothing at link
// time says so.

// Where a freestanding program says it cannot go on: print to a serial port, halt
// the cores, reboot. It must not return. `kind` and `detail` are string literals
// (`detail` may be empty), `file` is the source file and may be empty, and `line`
// and `col` are 1-based; `col` is 0 where the failure site has none.
//
// Weak, with a default that stops the machine and says nothing, so that a program
// which never fails does not have to define it. A kernel should define it.
__attribute__((weak, noreturn)) void
prismio_panic_hook(const char* kind, const char* detail, const char* file,
                   int line, int col) {
    (void)kind; (void)detail; (void)file; (void)line; (void)col;
    for (;;) {}
}

// A checked `+`, `-` or `*` that wrapped (`--overflow-checks`).
__attribute__((weak)) void prismio_overflow_trap(const char* op, const char* file, int line) {
    prismio_panic_hook("integer overflow", op, file, line, 0);
}

// A range `for` whose computed step was zero or negative.
__attribute__((weak)) void prismio_step_check(int step, const char* file, int line) {
    if (step > 0) return;
    prismio_panic_hook("range step must be positive", "", file, line, 0);
}

__attribute__((weak)) void prismio_panic(const char* message, const char* file, int line, int col) {
    prismio_panic_hook("panic", message, file, line, col);
}

__attribute__((weak)) void prismio_unreachable(const char* message, const char* file, int line, int col) {
    prismio_panic_hook("entered unreachable code", message, file, line, col);
}

// `source` is the assertion's source text, used when the program gave no message.
__attribute__((weak)) void prismio_assert_failed(const char* message, const char* source,
                           const char* file, int line, int col) {
    prismio_panic_hook("assertion failed",
                       (message && *message) ? message : source, file, line, col);
}

// The checked unwrap behind `expect(x)`: its argument, or a panic if it is null.
__attribute__((weak)) void* prismio_expect(void* p) {
    if (!p) prismio_panic_hook("expect() called on a `none` value", "", "", 0, 0);
    return p;
}
