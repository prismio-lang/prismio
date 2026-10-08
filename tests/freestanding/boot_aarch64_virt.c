// The boot stub for tests/freestanding/kernel_aarch64.psm on QEMU's `virt` board.
//
// Built with `-mgeneral-regs-only` (and the program with `-neon,-fp-armv8`): at the
// exception level QEMU enters, the first floating-point or SIMD instruction
// traps, and nothing has installed a vector table to catch it. The first version
// of this stub loaded a constant with `ldr q0` and the kernel hung without a
// word. A kernel keeps the FP unit off for the same reason and saves its state
// explicitly if it uses it.
//
// Everything a Prismio program cannot yet say for itself is here: the entry
// point, the stack, a write to a device register, and the exit. They move into
// Prismio as the language grows the primitives (docs/FREESTANDING_PLAN.md,
// steps 3 and 4); until then this file is the whole of the C a kernel needs.

typedef unsigned long u64;

#define UART0 ((volatile unsigned int*)0x09000000UL)

extern int main(int argc, char** argv);

// Named from the assembly below, which the compiler cannot see: without `used` a
// static is discarded as unreferenced.
char kstack[16384] __attribute__((aligned(16), used));

// QEMU loads the ELF and jumps to its entry with the MMU off and no stack.
__attribute__((naked, section(".text.boot"))) void _start(void) {
    __asm__ volatile(
        "adrp x0, kstack\n"
        "add  x0, x0, :lo12:kstack\n"
        "mov  x1, #16384\n"
        "add  sp, x0, x1\n"
        "mov  w0, wzr\n"
        "mov  x1, xzr\n"
        "bl   kernel_start\n"
        "1: wfi\n"
        "b 1b\n");
}

static void put(char c) { *UART0 = (unsigned int)c; }

static void put_str(const char* s) {
    while (*s) put(*s++);
}

static void put_int(int v) {
    char digits[12];
    int n = 0;
    if (v == 0) digits[n++] = '0';
    unsigned int u = v < 0 ? 0u - (unsigned int)v : (unsigned int)v;
    while (u) { digits[n++] = (char)('0' + u % 10); u /= 10; }
    if (v < 0) put('-');
    while (n) put(digits[--n]);
}

// ARM semihosting SYS_EXIT (needs `qemu -semihosting`): the exit status of the
// emulator is the status of the program, so a test can read it back.
static void semihost_exit(int status) {
    static u64 block[2];
    block[0] = 0x20026; // ADP_Stopped_ApplicationExit
    block[1] = (u64)status;
    register u64 op __asm__("x0") = 0x18; // SYS_EXIT
    register u64 arg __asm__("x1") = (u64)block;
    __asm__ volatile("hlt #0xf000" : : "r"(op), "r"(arg) : "memory");
}

// What the trap program (kernel_trap_aarch64.psm) reads to choose a path. A
// `volatile` the compiler cannot see through, so the checked operation is not
// folded away: the first draft of the overflow test built a program whose trap
// had been optimised out, and it passed.
#ifndef SEED
#define SEED 0
#endif
volatile int seed = SEED;

// The one function the panic core (runtime/freestanding/panic.c) asks of a
// program: say what failed and stop. Exit status 1 so a test can tell it from a
// program that returned.
void prismio_panic_hook(const char* kind, const char* detail, const char* file,
                        int line, int col) {
    (void)col;
    put_str(kind);
    if (*detail) {
        put_str(": ");
        put_str(detail);
    }
    put_str(" at ");
    put_str(file);
    put(':');
    put_int(line);
    put('\n');
    semihost_exit(1);
    for (;;) {}
}

void kernel_start(void) {
    int result = main(0, 0);
    put_str("result=");
    put_int(result);
    put('\n');
    semihost_exit(0);
}
