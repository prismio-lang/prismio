// The Prismio runtime for a program with no operating system: lang_runtime.c,
// compiled with PRISMIO_FREESTANDING for the program's own triple and CPU
// features, so `Vec`, `String` and the standard modules over them work in a
// kernel. prismio_freestanding.h says what stands in for the C library.
//
// `--freestanding` compiles this to bitcode and merges it into the program the way
// a hosted build merges the installed runtime, so what the program never calls is
// dropped with the rest of the module's dead code: a kernel that imports nothing
// from `std` links none of it. Found beside lang_runtime.c in a checkout, and as a
// copy of it in an installed toolchain's `lib/runtime/freestanding/`.
#define PRISMIO_FREESTANDING 1
#if __has_include("../lang_runtime.c")
#include "../lang_runtime.c"
#else
#include "lang_runtime.c"
#endif
