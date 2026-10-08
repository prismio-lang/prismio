// One translation unit for the whole C arm, as the hosted C++ arm has one dispatcher
// over its category files: this includes them so the compiler sees every workload
// at once, the way it sees the Prismio program and the Rust crate.
#include "algorithms.c"
#include "compute.c"
#include "memory.c"
#include "hardware.c"
