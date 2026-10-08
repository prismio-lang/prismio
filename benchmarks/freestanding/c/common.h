// Types and the one generator every workload uses. The generator is a linear
// congruential step written out where it is used rather than called through a
// pointer, so the three arms express the same arithmetic and not three different
// ways of threading state.
#ifndef BENCH_COMMON_H
#define BENCH_COMMON_H

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long u64;
typedef int i32;
typedef long i64;

#define LCG(s) ((s) = (s) * 1664525u + 1013904223u)

#endif
