// AIF Level 4. Strings and lists are affine now, so codegen emits a release for
// them -- and the allocation at the other end of that pairing is in *this* file,
// not behind ir_alloc_object. Both ends have to swap together or a verify build
// reports every string release as a pointer that was never live.
//
// The build driver compiles this file with -DPRISMIO_AIF_VERIFY for `--verify`,
// which is why verify mode still changes no codegen: the swap happens when the
// runtime is compiled, not when the program is generated.
#ifdef PRISMIO_AIF_VERIFY
#include <stddef.h>
void* aif_verify_alloc(size_t size);
void  aif_verify_release(void* p);
void  aif_verify_arm(void);
#define rt_base_alloc(n) aif_verify_alloc(n)
#define rt_free(p)       aif_verify_release(p)
#else
#define rt_base_alloc(n) malloc(n)
#define rt_free(p)       free(p)
#endif

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(__aarch64__) || defined(_M_ARM64)
#include <arm_neon.h>
#elif defined(__SSE2__)
#include <emmintrin.h>
#endif

// AIF Level 4, second half: `region` absorbs collections too.
//
// COMPILER-AUDIT scheduled Level 4 after Level 3 so that regions would already
// exist to take the string traffic -- but the arena is reached through
// ir_alloc_region, and only a struct literal goes through that. A string is
// allocated in this file, by str_concat, which has no idea where it is being
// called from.
//
// So the *call site* says. Codegen brackets a producing runtime call whose value
// aif_arena_at_node accepted with rt_arena_hint_push/pop, and the allocation
// inside bumps from the arena instead of the heap. The bracket goes around the
// call only -- arguments are already evaluated by then -- so a nested allocation
// that was not accepted does not inherit the hint.
//
// The hint is a depth, not a flag, because a producing call can be an argument
// to another one. It is never pushed outside a region: aif_arena_at_node needs an
// enclosing one before it says yes.
void* arena_alloc(size_t size);
void* arena_alloc_at(int slot, size_t size);
int arena_current_slot(void);

static int rt_arena_hint = 0;

void rt_arena_hint_push(void) { rt_arena_hint++; }
void rt_arena_hint_pop(void)  { if (rt_arena_hint > 0) rt_arena_hint--; }

static void* rt_alloc(size_t size) {
    if (rt_arena_hint > 0) return arena_alloc(size);
    return rt_base_alloc(size);
}

// Which arena an allocation made right now would come from, 1-based, or 0 for
// "the heap". A container is handed this at construction so that a *later*
// reallocation can go back to the same arena rather than to whichever one is on
// top at the time -- see list_push. A flag would not do: a nested `region`
// inside the one that owns the list would take the new element block and free it
// at its own exit, with the list still pointing at it.
static int rt_arena_slot(void) { return rt_arena_hint > 0 ? arena_current_slot() : 0; }

// Println function - prints a string and adds a newline
void println(const char* str) {
    printf("%s\n", str);
    fflush(stdout);
}

// Print function - prints a string without newline
void print(const char* str) {
    printf("%s", str);
    fflush(stdout);
}

void print_int(int value) {
    printf("%d", value);
    fflush(stdout);
}

// Print integer with newline
void println_int(int value) {
    printf("%d\n", value);
    fflush(stdout);
}

void print_float(double value) {
    printf("%g", value);
    fflush(stdout);
}

// Print float with newline
void println_float(double value) {
    printf("%g\n", value);
    fflush(stdout);
}

// Private ABI used by std/io.psm. See the WASM branch for why the old symbols
// remain available even though new Prismio programs do not declare them.
void prismio_rt_print(const char* str) {
    print(str);
}

void prismio_rt_println(const char* str) {
    println(str);
}

void prismio_rt_print_float(double value) {
    print_float(value);
}

void prismio_rt_println_float(double value) {
    println_float(value);
}

void print_bool(int value) {
    printf("%s", value ? "true" : "false");
    fflush(stdout);
}

// Print boolean with newline
void println_bool(int value) {
    printf("%s\n", value ? "true" : "false");
    fflush(stdout);
}

void print_char(char c) {
    printf("%c", c);
    fflush(stdout);
}

// Print character with newline
void println_char(char c) {
    printf("%c\n", c);
    fflush(stdout);
}

int str_equals(const char* s1, const char* s2) {
    return strcmp(s1, s2) == 0 ? 1 : 0;
}

// `strcat` here was a third and a fourth pass over the data: it walks `result`
// from the start to find the end it was just told, then copies. With both
// lengths already in hand, two `memcpy`s are the whole operation -- the second
// takes len2 + 1 so it carries the terminator rather than needing a separate
// store. Measured on 400 000 concatenations of two 20 KB strings: 1080ms before,
// against 117ms for the same work in C with the lengths passed in.
//
// The two `strlen`s that remain are the caller's own lengths, recomputed. They
// are visible to native Prismio -- `String` is `{ptr, i64}` -- but this C ABI
// deliberately accepts plain pointers. A future length-aware ABI can avoid them.
char* str_concat(const char* s1, const char* s2) {
    size_t len1 = strlen(s1);
    size_t len2 = strlen(s2);
    char* result = (char*)rt_alloc(len1 + len2 + 1);

    memcpy(result, s1, len1);
    memcpy(result + len1, s2, len2 + 1);

    return result;
}

char* str_substring(const char* s, int start, int length) {
    int str_len = strlen(s);

    // The out-of-range answer is an empty string the caller *owns*. It used to be
    // the literal "", which was fine while nothing freed a string and is a free
    // of a .rodata pointer now that they are affine (AIF Level 4). Anything
    // declared to return String hands back something a release can take.
    if (start < 0 || start >= str_len) {
        start = str_len;
        length = 0;
    }

    if (start + length > str_len) {
        length = str_len - start;
    }

    char* result = (char*)rt_alloc(length + 1);
    strncpy(result, s + start, length);
    result[length] = '\0';

    return result;
}

// The length-carrying slice, and the reason it has to exist.
//
// `str_substring` above cannot be made linear. A String here is a
// NUL-terminated `char*`, so the only way it can bound `start` or clamp
// `length` is to strlen the whole buffer -- once per call, over the entire
// source. A lexer calls it once per token, which makes scanning a file
// O(n x tokens). Measured on a 21 KB buffer: 1.808 ms against 0.031 ms for the
// identical scan with the call removed, i.e. **98% of the work**, and doubling
// the input multiplies the time by ~2.9 rather than by 2.
//
// This is the same defect the old C `str_char_at` had, fixed the same way --
// that function is gone now, and `strCharAt` in std/string.psm is the O(1)
// replacement that reads the carried length. createLexer
// already measures the input once and holds it in `Lexer.length` precisely
// because a per-character strlen made scanning quadratic; the comment there
// says so. That fix stopped at the character reads and never reached the
// slices, which is where the tokens are actually cut.
//
// The caller passes the base's length, which it already knows, and the bounds
// become constant time. This is SPEC 8.4's `(handle, offset, length)` reduced
// to what today's String can carry -- and it is only half of a view, because it
// still allocates and copies. Deleting that half needs the value to *be*
// (base, offset, length) rather than a fresh NUL-terminated buffer, which is
// the representation work. Priced in Rust on the same workload, the copy is
// worth a further 5.57x.
//
// Clamping rather than rejecting, exactly as str_substring does, so a caller
// that passes a stale or wrong `base_len` gets a short string and never a read
// past the end.
char* str_slice(const char* s, int start, int length, int base_len) {
    if (base_len < 0) base_len = 0;
    if (start < 0 || start >= base_len) {
        start = base_len;
        length = 0;
    }
    if (length < 0) length = 0;
    if (start + length > base_len) {
        length = base_len - start;
    }

    char* result = (char*)rt_alloc(length + 1);
    strncpy(result, s + start, length);
    result[length] = '\0';

    return result;
}

// The length of a C string, for codegen's use only.
//
// A `String` is `{ptr, i64}` inside Prismio and a bare `const char*` across the
// FFI, so a result coming *back* from an extern has to be given a length. The
// native length builtin requires that fat value, which does not exist yet at
// this point. This dedicated boundary helper takes the raw pointer.
int prismio_cstr_len(const char* s) { return s ? (int)strlen(s) : 0; }

// The first occurrence of `b` at or after `from`, or -1.
//
// `strchr`, which libc vectorises. This is the primitive that separates a
// competitive search from a naive one, and the gap is not small: on 40 000
// searches of a 40 000-byte string, a byte-at-a-time scan costs 0.38s in C at
// -O2 against 0.02s for the same search skipping to candidate first bytes with
// `memchr`. Rust's `str::find` is built on exactly this, for exactly this reason.
//
// `from` must not exceed the string's length -- the caller has the length in
// hand at every call site, and re-deriving it here would put a `strlen` back on
// the path this exists to make fast.
int str_find_byte(const char* s, int from, char b) {
    if (!s || from < 0) return -1;
    const char* hit = strchr(s + from, b);
    return hit ? (int)(hit - s) : -1;
}

// Find a candidate start where two bytes of a needle occur at their respective
// offsets. Checking a pair rather than one byte is what keeps common individual
// bytes in the vector loop: only the much rarer conjunction returns to scalar
// Prismio for full verification. This is the "packed pair" form of generic SIMD
// substring search used by memchr::memmem directly for needles up to 32 bytes
// and as a Two-Way prefilter for longer needles.
//
// `last` is the final legal candidate start. Both offsets must be within the
// needle, which makes the two unaligned vector loads stay within the String when
// the caller supplies `last = string_length - needle_length`.
int str_find_byte_pair(const char* s, int from, int last,
                       int offset1, char byte1, int offset2, char byte2) {
    if (!s || from < 0 || last < from || offset1 < 0 || offset2 < 0) return -1;

    int i = from;
#if defined(__aarch64__) || defined(_M_ARM64)
    uint8x16_t want1 = vdupq_n_u8((uint8_t)byte1);
    uint8x16_t want2 = vdupq_n_u8((uint8_t)byte2);
    // A two-vector unroll gives the core two independent load/compare chains;
    // on AArch64 this hides their latency without the instruction-cache cost
    // of the four-vector form.
    for (; i <= last - 31; i += 32) {
        uint8x16_t match0 = vandq_u8(
            vceqq_u8(vld1q_u8((const uint8_t*)s + i + offset1), want1),
            vceqq_u8(vld1q_u8((const uint8_t*)s + i + offset2), want2));
        uint8x16_t match1 = vandq_u8(
            vceqq_u8(vld1q_u8((const uint8_t*)s + i + 16 + offset1), want1),
            vceqq_u8(vld1q_u8((const uint8_t*)s + i + 16 + offset2), want2));
        uint8x8_t packed0 = vshrn_n_u16(vreinterpretq_u16_u8(match0), 4);
        uint8x8_t packed1 = vshrn_n_u16(vreinterpretq_u16_u8(match1), 4);
        uint64_t mask0 = vget_lane_u64(vreinterpret_u64_u8(packed0), 0)
                       & UINT64_C(0x8888888888888888);
        uint64_t mask1 = vget_lane_u64(vreinterpret_u64_u8(packed1), 0)
                       & UINT64_C(0x8888888888888888);
        if (mask0 != 0) return i + (__builtin_ctzll(mask0) >> 2);
        if (mask1 != 0) return i + 16 + (__builtin_ctzll(mask1) >> 2);
    }
    for (; i <= last - 15; i += 16) {
        uint8x16_t got1 = vld1q_u8((const uint8_t*)s + i + offset1);
        uint8x16_t got2 = vld1q_u8((const uint8_t*)s + i + offset2);
        uint8x16_t match = vandq_u8(vceqq_u8(got1, want1),
                                    vceqq_u8(got2, want2));
        // Each matching lane is 0xFF. Narrow adjacent byte pairs after a
        // four-bit shift so one scalar bit at positions 3,7,... represents
        // each lane; this is NEON's three-instruction equivalent of movemask.
        uint8x8_t packed = vshrn_n_u16(vreinterpretq_u16_u8(match), 4);
        uint64_t mask = vget_lane_u64(vreinterpret_u64_u8(packed), 0)
                      & UINT64_C(0x8888888888888888);
        if (mask != 0) return i + (__builtin_ctzll(mask) >> 2);
    }
#elif defined(__SSE2__)
    __m128i want1 = _mm_set1_epi8(byte1);
    __m128i want2 = _mm_set1_epi8(byte2);
    for (; i <= last - 31; i += 32) {
        __m128i match0 = _mm_and_si128(
            _mm_cmpeq_epi8(_mm_loadu_si128((const __m128i*)(s + i + offset1)), want1),
            _mm_cmpeq_epi8(_mm_loadu_si128((const __m128i*)(s + i + offset2)), want2));
        __m128i match1 = _mm_and_si128(
            _mm_cmpeq_epi8(_mm_loadu_si128((const __m128i*)(s + i + 16 + offset1)), want1),
            _mm_cmpeq_epi8(_mm_loadu_si128((const __m128i*)(s + i + 16 + offset2)), want2));
        unsigned mask0 = (unsigned)_mm_movemask_epi8(match0);
        unsigned mask1 = (unsigned)_mm_movemask_epi8(match1);
        if (mask0 != 0) return i + __builtin_ctz(mask0);
        if (mask1 != 0) return i + 16 + __builtin_ctz(mask1);
    }
    for (; i <= last - 15; i += 16) {
        __m128i got1 = _mm_loadu_si128((const __m128i*)(s + i + offset1));
        __m128i got2 = _mm_loadu_si128((const __m128i*)(s + i + offset2));
        __m128i match = _mm_and_si128(_mm_cmpeq_epi8(got1, want1),
                                      _mm_cmpeq_epi8(got2, want2));
        unsigned mask = (unsigned)_mm_movemask_epi8(match);
        if (mask != 0) return i + __builtin_ctz(mask);
    }
#endif
    for (; i <= last; i++) {
        if (s[i + offset1] == byte1 && s[i + offset2] == byte2) return i;
    }
    return -1;
}

// A String of `length` bytes the caller fills in, plus its NUL.
//
// The primitive the language was missing, and its absence shaped std/string.psm
// more than anything else in this file. With only `str_concat` and
// a one-character string to build with, producing an n-byte string costs n allocations
// and copies O(n^2) bytes, and it has to recurse because the loop form leaks --
// which put a stack ceiling on it at 150 000 characters. One allocation the
// caller writes into removes all three problems at once, and moves `strToUpper`,
// `strReverse`, `strRepeat`, `strJoin` and `strPadStart` into plain loops.
//
// **The caller must write every byte in [0, length).** Only the terminator is
// set here.
//
// This used to `memset` the whole buffer so that a partially written one was
// still a valid, shorter string. That safety was worth measuring rather than
// assuming, and it cost a full extra pass over memory that every caller then
// immediately overwrote: on 100 000 uppercase transforms of a 40 KB string the
// zero-fill was 0.0074s against 0.0064s without it, ~15% of the operation, for a
// guarantee no caller in std/string.psm needs -- each of `strRepeat`,
// `strPadStart`, `strPadEnd`, `strToUpper`, `strToLower`, `strReverse`,
// `strJoin` and `strFromUnsigned` fills its buffer completely.
//
// A caller that does not fill it gets whatever the allocator handed over, up to
// the terminator. That is the same contract C gives `malloc`, and it is why this
// is not a general-purpose allocation function.
//
// **`length` is the result's length, not merely its capacity.** Since `String`
// became `{ptr, i64}` the frontend builds this call's pair from the argument
// rather than measuring the buffer -- it has to, because measuring uninitialised
// bytes is what the paragraph above describes. The consequence is that the
// length is fixed here and a later write cannot change it: a NUL written into
// the middle no longer shortens the string, it just puts a NUL in it. Nothing in
// std/string.psm ever did that -- every builder listed above fills its buffer
// completely -- but a caller wanting a shorter result must now ask for a shorter
// one rather than terminating early. See the `str_with_capacity` intrinsic in
// src/ir/expr.psm.
char* str_with_capacity(int length) {
    if (length < 0) length = 0;
    char* result = (char*)rt_alloc((size_t)length + 1);
    result[length] = '\0';
    return result;
}

char* int_to_str(int n) {
    char* result = (char*)rt_alloc(32);  // enough for any int
    sprintf(result, "%d", n);
    return result;
}

char* str_clone(const char* s) {
    int len = strlen(s);
    char* result = (char*)rt_alloc(len + 1);
    strcpy(result, s);
    return result;
}

// Helpers for type punning ASTNode pointers in Prismio
// The absent pointer, and the test for it.
//
// Until now "absent" was a pointer to the empty string and the test was
// `str_equals(p, "")` -- a strcmp on a machine pointer. That is what forces
// CODE_STYLE.md's rule that no type punned through `String` may have a
// zero-valued first field: an absent slot and a live node whose first byte
// happens to be zero are the same bytes. Real NULL makes the two distinguishable
// by construction, and the test a compare rather than a call.
void* ptr_null(void) { return 0; }
int   ptr_is_null(void* p) { return p == 0 ? 1 : 0; }

void* ptr_to_node(void* ptr) { return ptr; }
void* node_to_ptr(void* ptr) { return ptr; }
void* ptr_to_token(void* ptr) { return ptr; }
void* token_to_ptr(void* ptr) { return ptr; }
void* ptr_to_type(void* ptr) { return ptr; }
void* type_to_ptr(void* ptr) { return ptr; }

// A note on how the frontend spells "this slot is empty", because it is not
// what it looks like and getting it wrong is a segfault rather than a warning.
//
// An absent child is the **empty string**, not a null pointer -- create_node()
// initialises every pointer slot to "". So `str_equals(p, "")` is the right
// question and a null test is not: a null test says "present" for an empty slot
// and the caller then dereferences it.
//
// What makes `str_equals(p, "")` fragile is the other direction. A punned
// pointer is a `char*`, so strcmp reads the *bytes of the pointed-to struct*,
// and a struct beginning with a zero-valued enum begins with a NUL byte -- so
// it compares equal to "" and a live node reads as an empty slot. src/ast.psm
// states the invariant that keeps this from firing and enforces it at the two
// enums that matter.

// Native builds use libc malloc; the per-frame arena reset is a no-op here.
void heap_reset(void) { }

// Arenas (AIF Level 3, SPEC 5.2)
// A stack of bump allocators. `region r { ... }` pushes one on entry and pops it
// on every exit; an allocation the analysis proved cannot outlive that region
// comes from the top of the stack, and the whole block goes back at once.
// COMPILER-AUDIT 3 expected the arena handle to be *threaded* to each allocation
// site as a second argument. It is dynamically scoped instead, which keeps
// ir_alloc_region a `fn(size) -> ptr` like the other two hooks and needs no new
// frontend plumbing. The cost of that choice is that a callee cannot be given a
// different arena from its caller's -- which does not arise, because only sites
// lexically inside the block are routed here (SPEC 5.2's own wording), and the
// analysis has already proved each of those dies no later than this region.
// Chunks are a linked list so a region that outgrows its first block keeps
// going rather than falling back to the heap; pointers already handed out stay
// valid because earlier chunks are not moved.

#define ARENA_CHUNK_MIN 8192
#define ARENA_MAX_DEPTH 64

typedef struct ArenaChunk {
    struct ArenaChunk* next;
    size_t used, cap;
    unsigned char* base;
} ArenaChunk;

static ArenaChunk* arena_stack[ARENA_MAX_DEPTH];
static int arena_depth = 0;

// Reported by arena_stats so a test can assert an allocation came from a region
// rather than from malloc -- the two are indistinguishable from the value.
static long arena_bytes_served, arena_objects_served, arena_regions_entered;

// Chunks are pooled rather than returned to libc, and that is what makes
// LAYOUT 4's `arenaSetupCost` of ~40 cycles a real number instead of an
// aspiration. Without the pool a region that serves one allocation pays a malloc
// for its chunk and a free at the pop -- 180 cycles, more than the 87 an arena
// saves per allocation -- so the cost model would have to decline every small
// scope and automatic placement (LAYOUT 7.1) could never fire. With it, entering
// a region is a depth increment and a pointer swap.
//
// Only default-sized chunks are pooled. An oversized one was cut for a single
// large allocation and holding it would keep an arbitrary amount of memory live
// for the rest of the program.
//
// The pool is capped, and the cap is the difference between "pooled" and
// "never returned to the OS". Uncapped, a program's peak arena footprint stays
// resident for the rest of its life: one pass that nests deeply or chains many
// chunks sets a high-water mark nothing ever gives back, and peak RSS carries it
// to exit. Trimming rather than removing, because removing the pool is what the
// note above says would stop automatic placement firing at all.
//
// ARENA_POOL_MAX * ARENA_CHUNK_MIN is the resident ceiling: 64 KB. The cap has
// to clear ordinary *nesting* -- chunks held by live regions are on the stack,
// not in the pool, so it only has to cover what a single pop hands back plus
// reuse across iterations, and a loop entering one region reuses one chunk.
#define ARENA_POOL_MAX 8
static ArenaChunk* arena_pool;
static int arena_pool_count;

static ArenaChunk* arena_chunk_new(size_t need) {
    if (need <= ARENA_CHUNK_MIN && arena_pool) {
        ArenaChunk* c = arena_pool;
        arena_pool = c->next;
        arena_pool_count--;
        c->used = 0;
        c->next = NULL;
        return c;
    }

    size_t cap = need > ARENA_CHUNK_MIN ? need : ARENA_CHUNK_MIN;
    ArenaChunk* c = (ArenaChunk*)malloc(sizeof(ArenaChunk));
    if (!c) return NULL;
    c->base = (unsigned char*)malloc(cap);
    if (!c->base) { free(c); return NULL; }
    c->used = 0;
    c->cap = cap;
    c->next = NULL;
    return c;
}

void arena_push(void) {
#ifdef PRISMIO_AIF_VERIFY
    aif_verify_arm();
#endif
    if (arena_depth >= ARENA_MAX_DEPTH) {
        fprintf(stderr, "internal error: regions nested more than %d deep\n", ARENA_MAX_DEPTH);
        exit(1);
    }
    arena_stack[arena_depth++] = NULL;   // chunks are taken on first use
    arena_regions_entered++;
}

void arena_pop(void) {
    if (arena_depth <= 0) return;
    ArenaChunk* c = arena_stack[--arena_depth];
    while (c) {
        ArenaChunk* next = c->next;
        if (c->cap == ARENA_CHUNK_MIN && arena_pool_count < ARENA_POOL_MAX) {
            c->next = arena_pool;
            arena_pool = c;
            arena_pool_count++;
        } else {
            free(c->base);
            free(c);
        }
        c = next;
    }
    arena_stack[arena_depth] = NULL;
}

static void* arena_alloc_slot(int index, size_t size) {
    size_t need = (size + 15u) & ~(size_t)15u;   // 16-byte aligned, as malloc is
    ArenaChunk* c = arena_stack[index];
    if (!c || c->used + need > c->cap) {
        ArenaChunk* fresh = arena_chunk_new(need);
        if (!fresh) return rt_base_alloc(size);
        fresh->next = c;
        arena_stack[index] = fresh;
        c = fresh;
    }

    void* p = c->base + c->used;
    c->used += need;
    arena_bytes_served += (long)need;
    arena_objects_served++;
    return p;
}

void* arena_alloc(size_t size) {
    // No region active. Codegen only routes a site here when one is, so this is
    // a corrupted arena stack rather than an ordinary case -- but falling back
    // to the ordinary allocator keeps SPEC 1's invariant (never wrong, only
    // slower) instead of returning NULL into code that will not check it. Through
    // rt_base_alloc rather than malloc so a verify build still accounts for it.
    if (arena_depth <= 0) return rt_base_alloc(size);
    return arena_alloc_slot(arena_depth - 1, size);
}

int arena_current_slot(void) { return arena_depth; }

// SPEC 5.2.1.1. Allocate from a *named* arena rather than from the innermost
// one, so a container can grow back into the region that owns it after an inner
// region has been entered. `slot` is 1-based, as arena_current_slot returns it.
//
// A slot past the current depth is a region that has already exited, which
// obligation 3 rules out -- the container is dead by then. Falling back to the
// heap rather than trusting it keeps SPEC 1's invariant, and it is the direction
// that leaks rather than the one that corrupts.
void* arena_alloc_at(int slot, size_t size) {
    if (slot <= 0 || slot > arena_depth) return rt_base_alloc(size);
    return arena_alloc_slot(slot - 1, size);
}

long arena_objects(void) { return arena_objects_served; }
long arena_bytes(void)   { return arena_bytes_served; }
long arena_regions(void) { return arena_regions_entered; }

// AIF `verify` mode (SPEC 7.3)
// A verify build swaps the allocator and deallocator names through
// ir_set_alloc_function / ir_set_free_function and changes nothing else -- the
// same seam COMPILER-AUDIT 3 describes for T2, used here for its first real
// purpose. Codegen is identical to a release build.
// What this covers, of SPEC 7.3's table:
//   Tier T0/T1, "no access after frame or region exit" -- partially. Released
//   memory is poisoned before it goes back to the allocator, so a read that
//   should not have happened returns a recognisable pattern rather than data
//   that is merely stale-but-plausible. Reads are not instrumented, so this
//   makes such a bug loud rather than impossible.
//   The balance itself, which is not in the table and should be: every object
//   released exactly once, and none left over. That is what catches a missed
//   drop path (leak) and a doubled one (release of something not live), which
//   are the two ways Level 2 can be wrong.
// What it does not cover, and why:
//   A = Unique / A <= Borrowed  need a count word in the object header, which
//                               is the same layout change T3 needs.
//   E = Region(r)               needs arenas; Level 3.
//   E <= Caller                 needs static-root reachability at return.
//   T = Isolated / Transferred  vacuous -- the language has no tasks.
//   C = Acyclic                 needs a periodic heap walk.

#define AIF_VERIFY_BUCKETS 4096
#define AIF_VERIFY_POISON  0xDD

typedef struct AifLive {
    struct AifLive* next;
    void* p;
    size_t size;
    long serial;        // allocation order, so a leak report names something
} AifLive;

static AifLive* aif_live[AIF_VERIFY_BUCKETS];
static long aif_allocs, aif_releases, aif_violations;
static int aif_report_armed;

static unsigned aif_live_hash(const void* p) {
    uintptr_t v = (uintptr_t)p;
    v ^= v >> 33;
    v *= 0xff51afd7ed558ccdull;
    v ^= v >> 29;
    return (unsigned)v & (AIF_VERIFY_BUCKETS - 1);
}

void aif_verify_report(void) {
    long leaked = 0;
    for (int i = 0; i < AIF_VERIFY_BUCKETS; i++) {
        for (AifLive* n = aif_live[i]; n; n = n->next) {
            // The serial is the allocation's order in the run, which is the only
            // handle a leak report can offer without debug info: "the 116th
            // object" is enough to find the site by counting sites.
            if (leaked < 20) {
                fprintf(stderr, "aif-verify: leaked #%ld (%lu bytes)\n",
                        n->serial, (unsigned long)n->size);
            }
            leaked++;
        }
    }
    fprintf(stderr, "aif-verify: %ld allocated, %ld released, %ld leaked, %ld violation(s)\n",
            aif_allocs, aif_releases, leaked, aif_violations);
    if (leaked || aif_violations) {
        fprintf(stderr, "aif-verify: FAILED -- an inferred fact did not hold at run time\n");
    }
}

// Armed by the first allocation *or* the first region entry. Once LAYOUT 7.1
// places arenas automatically, a program can run to completion without a single
// call through the seam -- every allocation served from a bump block -- and
// arming only there would print no report at all, which reads as "the seam was
// not redirected" rather than as "nothing needed accounting".
void aif_verify_arm(void) {
    if (!aif_report_armed) {
        aif_report_armed = 1;
        atexit(aif_verify_report);
    }
}

void* aif_verify_alloc(size_t size) {
    aif_verify_arm();
    void* p = malloc(size);
    if (!p) return NULL;

    aif_allocs++;
    AifLive* n = (AifLive*)malloc(sizeof(AifLive));
    if (n) {
        n->p = p;
        n->size = size;
        n->serial = aif_allocs;
        unsigned b = aif_live_hash(p);
        n->next = aif_live[b];
        aif_live[b] = n;
    }
    return p;
}

void aif_verify_release(void* p) {
    if (!p) return;

    unsigned b = aif_live_hash(p);
    AifLive** link = &aif_live[b];
    while (*link && (*link)->p != p) link = &(*link)->next;

    if (!*link) {
        // Either released twice, or never came from here. Both mean a fact was
        // wrong: the value was freed on a path the analysis did not account for.
        fprintf(stderr, "aif-verify: release of a pointer that is not live (%p)\n", p);
        aif_violations++;
        return;
    }

    AifLive* n = *link;
    *link = n->next;
    memset(p, AIF_VERIFY_POISON, n->size);
    free(n);
    free(p);
    aif_releases++;
}

// Growable list (List<T> for reference elements) — backs Prismio's List<T>.
// Stores pointer-sized elements.
// AIF Level 5 -- T3, non-atomic reference counting (SPEC 3, T3).
// The count lives in a **prefix header**: rc_alloc returns base + RC_HDR, and the
// count is the word immediately in front of the pointer the program holds. That
// choice is what keeps the seam a fourth allocator name and nothing else.
// COMPILER-AUDIT 3's table says T3 is only "partly" expressible because "the
// header word changes struct layout, which named_struct and every
// ir_struct_field_ptr index would have to account for" -- true of a header word
// inside the object, and avoided entirely by putting it in front. The struct type
// LLVM sees is unchanged and every field index still means what it meant.
// **The count starts at zero, not one**, and that is the whole design rather than
// an off-by-one. What is counted here is *container edges*, because they are the
// only holder class this compiler both tracks and releases: a T3 value's escape is
// Caller or Global by definition of the tier, so aif_frees_at_scope_node can never
// admit its binding, and a struct field has no teardown yet. A value in no
// container is therefore held by nothing that will ever release, and counting the
// creating expression would put every such value permanently at one. At zero it
// simply leaks, which is exactly what it did before this existed.
// So: one container is one count, the teardown decrements, and the value dies with
// the last container that held it. A release without a matching retain cannot
// happen -- only a container retains, and only the same container releases.
// **An OPAQUE site is never refcounted.** The pointer came back from a function
// this compilation cannot see, so there is no header in front of it and reading
// one is reading whatever the allocator put there. That excludes all 37 of the
// compiler's own T3 sites, which is why the self-host exercises none of this.

#define RC_HDR 16       // >= sizeof(size_t), and keeps the payload 16-byte aligned

static size_t* rc_slot(void* p) {
    return &((size_t*)p)[-1];
}

// LAYOUT 6's hot/cold split, the T3 half.
//
// `rc_release` frees one block and cannot name the type -- a counted value's last
// holder is a container's teardown, which arrives holding a bare pointer. That is
// the one release path the generated `__aif_release_T` does not cover, and it is
// where a split would leak its cold block.
//
// **RC_HDR is 16 bytes with 8 in use, so the fix is already paid for.** The
// second word holds the *byte offset* of the link within the payload, stamped at
// construction exactly as `cyc_set_type` stamps a descriptor, and `rc_release`
// reads the cold pointer from there. No function pointer, no per-type table, and
// no extra call on the release path.
//
// Offset 0 means "not split", and it is sound rather than convenient: field 0 is
// pinned hot and placed first, so no hot record can carry its link at byte 0.
static size_t* rc_cold_slot(void* p) {
    return &((size_t*)p)[-2];
}

void* rc_alloc(size_t size) {
    unsigned char* base = (unsigned char*)rt_base_alloc(size + RC_HDR);
    if (!base) return 0;
    void* payload = base + RC_HDR;
    *rc_slot(payload) = 0;
    *rc_cold_slot(payload) = 0;
    return payload;
}

// Allocates the cold half of a split T3 object, links it, and records where the
// link is. Emitted by ir_alloc_rc immediately after rc_alloc, so the object is
// whole before any field initialiser runs.
//
// Through rt_base_alloc, like rc_alloc itself, so a verify build accounts for
// both halves in one ledger and rc_release's rt_free pairs with it.
void rc_attach_cold(void* p, size_t cold_size, size_t link_offset) {
    if (!p || link_offset == 0) return;
    void* cold = rt_base_alloc(cold_size);
    *(void**)((unsigned char*)p + link_offset) = cold;
    *rc_cold_slot(p) = link_offset;
}

void rc_retain(void* p) {
    if (p) (*rc_slot(p))++;
}

// AIF T4a (SPEC 3, REQUIREMENTS 15). The same count, touched atomically.
//
// **A separate entry point, chosen at compile time, and that is the whole
// design.** The obvious alternative is one `rc_release` that branches on a bit
// in the header -- and it puts a load and a branch on the path SPEC 11 item 10
// exists to keep clear. The point of inferring thread affinity at all is that
// the answer is known statically, so a value that never crosses a thread
// boundary should not pay even a predictable branch to find that out. The
// compiler picks the symbol; there is nothing to test at run time.
//
// Relaxed on the increment, acq_rel on the decrement, which is the standard
// pairing and not an optimisation: a retain only needs the count to be right,
// while the decrement that reaches zero must see every write any other thread
// made through its own reference before the free runs.
//
// Built from __atomic rather than <stdatomic.h> because the count is an
// ordinary `size_t` in a header this file shares with the non-atomic path --
// declaring it _Atomic would change rc_slot's type for both. The generic
// builtins are the supported way to do exactly that, and clang is the compiler
// on all three CI platforms.
#if defined(_MSC_VER) && !defined(__clang__)
#include <intrin.h>
#define PRISMIO_ATOMIC_INC(p) ((size_t)_InterlockedIncrement64((volatile __int64*)(p)))
#define PRISMIO_ATOMIC_DEC(p) ((size_t)_InterlockedDecrement64((volatile __int64*)(p)))
#else
#define PRISMIO_ATOMIC_INC(p) __atomic_add_fetch((p), 1, __ATOMIC_RELAXED)
#define PRISMIO_ATOMIC_DEC(p) __atomic_sub_fetch((p), 1, __ATOMIC_ACQ_REL)
#endif

void rc_retain_atomic(void* p) {
    if (p) PRISMIO_ATOMIC_INC(rc_slot(p));
}

void rc_release_atomic(void* p) {
    if (!p) return;
    size_t* c = rc_slot(p);
    // The zero test is not a race the atomics have to cover. A count of zero
    // means nothing ever retained the value, so no second reference exists to
    // be decrementing concurrently -- the same reasoning rc_release relies on,
    // and the reason this reads the slot plainly first.
    if (*c == 0) return;
    if (PRISMIO_ATOMIC_DEC(c) == 0) {
        size_t off = *rc_cold_slot(p);
        if (off) rt_free(*(void**)((unsigned char*)p + off));
        rt_free((unsigned char*)p - RC_HDR);
    }
}

void rc_release(void* p) {
    if (!p) return;
    size_t* c = rc_slot(p);
    if (*c == 0) return;            // never retained: nothing holds it, nothing frees it
    if (--(*c) == 0) {
        // The cold block first: its pointer lives *inside* the payload, so reading
        // it after the base has gone is a use-after-free -- and in a verify build,
        // a read of poisoned bytes handed straight to the deallocator.
        size_t off = *rc_cold_slot(p);
        if (off) rt_free(*(void**)((unsigned char*)p + off));
        rt_free((unsigned char*)p - RC_HDR);
    }
}

// AIF T4b -- the cycle collector (CYCLES 3)
// Trial deletion (Bacon-Rajan), scoped to the T4b residue, traversing **only
// cyclic edges** (CYCLES 4). That restriction is the design's own contribution
// and it is available because the compiler owns the type graph: every edge of a
// value-level cycle connects two types in one SCC, so traversing only fields
// whose type is in the owner's SCC finds every cycle and never leaves the
// skeleton. A Node with two child pointers and six fields of strings and spans
// is walked through two edges, not eight, and the collector never descends into
// the string graph at all.
// **A T4b object is told what its cyclic children are.** `cyc_set_type` stamps a
// per-type function generated by codegen, for the same reason `list_set_elem_owner`
// exists: reading a header in front of a pointer to find out would be reading
// memory this compilation did not allocate.
// The count is container edges, exactly as at Level 5 -- a T4b value's escape is
// Caller or Global by the tier's definition, so no binding ever releases it.
// What T4b adds over T3 is the case Level 5 cannot handle: a decrement that does
// *not* reach zero is the only way a cycle can become garbage, so that is when a
// candidate root is buffered.

#define CYC_BLACK  0
#define CYC_GREY   1
#define CYC_WHITE  2
#define CYC_PURPLE 3

typedef void (*CycVisitor)(void*);

typedef struct {
    size_t rc;
    unsigned char colour;
    unsigned char buffered;
    void (*children)(void*, CycVisitor);
    void (*release)(void*);
} CycHeader;

// Rounded so the payload stays 16-byte aligned, like RC_HDR above.
#define CYC_HDR ((sizeof(CycHeader) + 15u) & ~(size_t)15u)

static CycHeader* cyc_hdr(void* p) {
    return (CycHeader*)((unsigned char*)p - CYC_HDR);
}

// CYCLES 6.1: collection is triggered by candidate-buffer occupancy, never by a
// timer -- a timer would make a program's pause profile a function of how fast
// the machine is, which is exactly the unpredictability SPEC's latency claim
// rejects. CYCLES 10 lists both of these as tuning constants needing
// measurement; they are the document's defaults and are not measured here.
#define CYC_THETA_BUFFER 4096
#define CYC_K_ROOTS      256

static void** cyc_candidates;
static int cyc_cand_count, cyc_cand_cap;

// The traversal's child window. Recursion uses a slice of this rather than a
// local array, so a wide object does not put its whole fan-out on the C stack.
static void** cyc_walk;
static int cyc_walk_len, cyc_walk_cap;

static long long cyc_allocated, cyc_collected, cyc_collections;

static void cyc_walk_push(void* p) {
    if (cyc_walk_len == cyc_walk_cap) {
        int grow = cyc_walk_cap ? cyc_walk_cap * 2 : 64;
        cyc_walk = (void**)realloc(cyc_walk, (size_t)grow * sizeof(void*));
        cyc_walk_cap = grow;
    }
    cyc_walk[cyc_walk_len++] = p;
}

static void cyc_buffer(void* p) {
    if (cyc_cand_count == cyc_cand_cap) {
        int grow = cyc_cand_cap ? cyc_cand_cap * 2 : 256;
        cyc_candidates = (void**)realloc(cyc_candidates, (size_t)grow * sizeof(void*));
        cyc_cand_cap = grow;
    }
    cyc_candidates[cyc_cand_count++] = p;
}

static void cyc_free_object(void* p) {
    CycHeader* h = cyc_hdr(p);
    cyc_collected++;
    // The generated release reclaims the object's *non*-cyclic owned fields and
    // the storage. Struct-field ownership declines a cyclic field precisely so
    // that it is the collector, not a recursive release, that follows it.
    if (h->release) {
        h->release(p);
    } else {
        rt_free((unsigned char*)p - CYC_HDR);
    }
}

static void cyc_mark_grey(void* x) {
    CycHeader* h = cyc_hdr(x);
    if (h->colour == CYC_GREY) return;
    h->colour = CYC_GREY;
    if (!h->children) return;

    int base = cyc_walk_len;
    h->children(x, cyc_walk_push);
    int end = cyc_walk_len;
    for (int i = base; i < end; i++) {
        void* y = cyc_walk[i];
        if (!y) continue;
        // Trial deletion of an internal reference. What survives with a non-zero
        // count is what something outside the candidate subgraph still holds.
        CycHeader* yh = cyc_hdr(y);
        if (yh->rc > 0) yh->rc--;
        cyc_mark_grey(y);
    }
    cyc_walk_len = base;
}

static void cyc_scan_black(void* x) {
    CycHeader* h = cyc_hdr(x);
    h->colour = CYC_BLACK;
    if (!h->children) return;

    int base = cyc_walk_len;
    h->children(x, cyc_walk_push);
    int end = cyc_walk_len;
    for (int i = base; i < end; i++) {
        void* y = cyc_walk[i];
        if (!y) continue;
        cyc_hdr(y)->rc++;
        if (cyc_hdr(y)->colour != CYC_BLACK) cyc_scan_black(y);
    }
    cyc_walk_len = base;
}

static void cyc_scan(void* x) {
    CycHeader* h = cyc_hdr(x);
    if (h->colour != CYC_GREY) return;
    if (h->rc > 0) {
        cyc_scan_black(x);         // reachable from outside; the cycle is live
        return;
    }
    h->colour = CYC_WHITE;
    if (!h->children) return;

    int base = cyc_walk_len;
    h->children(x, cyc_walk_push);
    int end = cyc_walk_len;
    for (int i = base; i < end; i++) {
        if (cyc_walk[i]) cyc_scan(cyc_walk[i]);
    }
    cyc_walk_len = base;
}

static void cyc_collect_white(void* x) {
    CycHeader* h = cyc_hdr(x);
    if (h->colour != CYC_WHITE || h->buffered) return;
    h->colour = CYC_BLACK;

    // Children are gathered *before* the object is freed: cyc_free_object hands
    // the storage back, and reading the field afterwards is a use-after-free.
    int base = cyc_walk_len;
    if (h->children) h->children(x, cyc_walk_push);
    int end = cyc_walk_len;

    int n = end - base;
    void** kids = NULL;
    if (n > 0) {
        kids = (void**)malloc((size_t)n * sizeof(void*));
        for (int i = 0; i < n; i++) kids[i] = cyc_walk[base + i];
    }
    cyc_walk_len = base;

    cyc_free_object(x);

    for (int i = 0; i < n; i++) {
        if (kids[i]) cyc_collect_white(kids[i]);
    }
    free(kids);
}

// CYCLES 6.2: at most K roots per collection, and the rest stay buffered.
// Bounding by roots rather than by traversal steps is what removes the need for
// an abort path in the common case -- the walk from K roots through cyclic edges
// only is bounded by the cyclic skeleton reachable from them.
static void cyc_collect(int all) {
    int take = all ? cyc_cand_count : (cyc_cand_count < CYC_K_ROOTS ? cyc_cand_count : CYC_K_ROOTS);
    if (take <= 0) return;
    cyc_collections++;

    void** roots = (void**)malloc((size_t)take * sizeof(void*));
    for (int i = 0; i < take; i++) roots[i] = cyc_candidates[i];
    for (int i = take; i < cyc_cand_count; i++) cyc_candidates[i - take] = cyc_candidates[i];
    cyc_cand_count -= take;

    // Unbuffered before the walk, so CollectWhite is allowed to reclaim a root:
    // its own `buffered` flag is what would otherwise stop it.
    for (int i = 0; i < take; i++) cyc_hdr(roots[i])->buffered = 0;

    for (int i = 0; i < take; i++) cyc_mark_grey(roots[i]);
    for (int i = 0; i < take; i++) cyc_scan(roots[i]);
    for (int i = 0; i < take; i++) cyc_collect_white(roots[i]);

    free(roots);
}

// A final pass at exit, which is CYCLES 6.1's "explicit request". Without it a
// short program never reaches Theta_buffer and the collector never runs, so a
// fixture could not tell an implemented collector from an absent one.
static int cyc_exit_registered;

static void cyc_final(void) {
    while (cyc_cand_count > 0) cyc_collect(1);
}

void* cyc_alloc(size_t size) {
    if (!cyc_exit_registered) {
        cyc_exit_registered = 1;
        atexit(cyc_final);
    }
    unsigned char* base = (unsigned char*)rt_base_alloc(size + CYC_HDR);
    if (!base) return 0;
    void* payload = base + CYC_HDR;
    CycHeader* h = cyc_hdr(payload);
    h->rc = 0;
    h->colour = CYC_BLACK;
    h->buffered = 0;
    h->children = 0;
    h->release = 0;
    cyc_allocated++;
    return payload;
}

void cyc_set_type(void* p, void (*children)(void*, CycVisitor), void (*release)(void*)) {
    if (!p) return;
    CycHeader* h = cyc_hdr(p);
    h->children = children;
    h->release = release;
}

void cyc_retain(void* p) {
    if (p) cyc_hdr(p)->rc++;
}

void cyc_release(void* p) {
    if (!p) return;
    CycHeader* h = cyc_hdr(p);
    if (h->rc == 0) return;         // never retained: nothing holds it, nothing frees it
    if (--h->rc == 0) {
        cyc_free_object(p);
        return;
    }
    // CYCLES 3.2. A count that dropped without reaching zero is the only way a
    // cycle can become garbage, so this is the one place a candidate is born.
    if (!h->buffered) {
        h->colour = CYC_PURPLE;
        h->buffered = 1;
        cyc_buffer(p);
        if (cyc_cand_count >= CYC_THETA_BUFFER) cyc_collect(0);
    }
}

// CYCLES 6.1's third trigger, "or on explicit request". Exposed because the
// other two -- buffer occupancy and allocation failure -- are both unreachable
// in a fixture small enough to reason about, and a collector that only ever runs
// at exit cannot be shown to restore counts on a *live* cycle.
void cyc_collect_now(void) { cyc_collect(1); }

long long cyc_objects(void)     { return cyc_allocated; }
long long cyc_reclaimed(void)   { return cyc_collected; }
long long cyc_collections_run(void) { return cyc_collections; }

// AIF item 3. `elem_own` is what the container was told about its elements at
// construction, and being told is the only way it can know: the elements are
// plain pointers, and reading a header in front of one to find out would be
// reading memory this program may not have allocated.
//
// Set once, by codegen, from aif_elem_owner_at_node -- which answers NONE unless
// every element site agrees, so a list that reaches here with a mode is a list
// whose elements are uniformly reclaimable.
// **These eight values are one wire protocol with three definitions, and nothing
// but this comment holds them together.** Codegen emits the mode from
// `AIF_ELEM_*` in src/ir/context.psm; the analysis answers with `AIF_ELEM_*` in
// aif_support.c; the runtime compares against these. A variant inserted in one
// list and not the others does not fail to build -- it releases elements with
// the wrong deallocator, which is a violation rather than a leak.
//
// They were `XEFY_ELEM_*` here until 2026-08-23, named after Xefy, the framework
// this language is being built to carry (aif/implementation/TARGET.md). That is
// backwards -- the list belongs to Prismio, not to a consumer of it -- and the
// odd prefix was also what made the drift invisible: a grep for
// `AIF_ELEM_CYCLE` found two of the three sites. `run_elem_mode_agreement_test`
// in tests/test_runner.py now checks all three.
#define AIF_ELEM_NONE   0
#define AIF_ELEM_OBJECT 1
#define AIF_ELEM_LIST   2
#define AIF_ELEM_RC     3   // Level 5: a decrement, and the last holder frees
#define AIF_ELEM_TYPED  4   // struct-field ownership: the element type's own release
#define AIF_ELEM_CYCLE  5   // T4b: a decrement, and a non-zero result is a candidate root
// REQUIREMENTS 15. The two above, one tier up: T4a is a count two threads can
// touch, so the same decrement has to be atomic. Two constants rather than one
// plus a flag, because SPEC 3 requires an implementation to "distinguish the
// sub-classes" and specifically forbids charging collector participation to a
// T4a value that is provably acyclic -- which is exactly the difference here.
#define AIF_ELEM_RC_ATOMIC    6
#define AIF_ELEM_CYCLE_ATOMIC 7

typedef struct {
    void** data;
    int len;
    int cap;
    int elem_own;
    // Struct-field ownership. Under AIF_ELEM_TYPED the release differs per
    // element *type*, and an int cannot name a type -- so the container is told
    // the function. Same rule as elem_own, one step less abstract: the container
    // is told what to do because it has no way to ask.
    void (*elem_release)(void*);
    // SPEC 5.2.1.1. The arena this list came from, 1-based, or 0 for the heap.
    //
    // A list is two allocations and one of them is *rewritten* long after the
    // site that made it: list_push doubles the element block and frees the old
    // one. That is the whole of the `is_list` clause the placement gate used to
    // reject an arena-served list with -- and the reason it can be lifted for a
    // bracketed extent is that the answer is recorded here rather than guessed
    // at from the arena depth that happens to be current. Without it, a list
    // whose handle is a bump pointer would hand its old element block to free().
    int arena;
    // M4.2. Bytes per element when the elements are stored **inline** -- `data`
    // holds the element bodies rather than pointers to them -- and 0 when they
    // are boxed, which is every list this is not stamped on.
    //
    // Stamped from the element type, and only for a type the compiler calls
    // *flat*: no pointer anywhere inside it, and not split hot/cold. Both halves
    // are the frontend's to decide (ir_struct_is_flat), because both are
    // properties of the layout it chose.
    //
    // **The three hot ops above do not branch on it.** `list_get`, `list_push`
    // and `list_set` are byte-for-byte what they were, and the inline mode has
    // its own entry points that codegen calls instead -- because the element
    // type is a static fact at every call site, so the branch belongs at compile
    // time. A first version put the branch in `list_get` and `list_push`
    // themselves and cost **1.159x on the corpus with no list inline at all**:
    // one extra load and predictable branch, in the two functions the corpus
    // spends most of its time in. That measurement is the reason this file has
    // two families of entry points instead of one.
    //
    // It also fits in the padding after `arena`, so the header is the same 40
    // bytes it was.
    int elem_size;
} RtList;

static void* list_new_cap(int cap) {
    RtList* l = (RtList*)rt_alloc(sizeof(RtList));
    l->len = 0;
    l->cap = cap;
    l->elem_own = AIF_ELEM_NONE;
    l->elem_release = 0;
    l->arena = rt_arena_slot();
    l->elem_size = 0;
    l->data = (void**)rt_alloc(sizeof(void*) * (size_t)cap);
    return l;
}

void* list_new(void) { return list_new_cap(4); }

// Vec::with_capacity. A hint about size, not a bound: the list still grows by
// doubling past `n`, so a wrong hint costs memory or a realloc and never
// correctness. That is what keeps it outside SPEC 5's annotation budget -- it is
// a library call whose argument is a value, not a fact the analysis has to trust.
//
// Worth 0.926x on g2 (aif/evidence/xlang/prismio/g2.psm, 9 interleaved runs),
// where `cull` builds a fresh ~501-element list every frame for 20 000 frames and
// paid seven reallocations and 508 pointer copies each time. Measured before this
// was written, by raising the default capacity to 512 and timing the frame loop --
// which is the upper bound this API can reach, since it removes exactly the same
// reallocations.
//
// A non-positive hint is clamped rather than rejected: `list_new_with_capacity(0)`
// is the natural thing to write when the count is computed and comes out empty,
// and a zero-length data block would make the first push read cap 0 and double it
// to 0 forever.
void* list_new_with_capacity(int n) {
    return list_new_cap(n > 0 ? n : 4);
}

void list_set_elem_owner(void* lp, int mode) {
    if (lp) ((RtList*)lp)->elem_own = mode;
}

void list_set_elem_releaser(void* lp, void (*fn)(void*)) {
    if (lp) ((RtList*)lp)->elem_release = fn;
}

// M4.2 -- inline element storage
// A `List<T>` whose T is *flat* (SPEC 8.2's unboxed layout: no pointer anywhere
// inside the type, and not split hot/cold) stores element **bodies** in the list
// rather than pointers to separately allocated ones. What that removes is an
// allocation per element and a pointer chase per access -- the pair
// ARCHITECTURE-DIRECTION measured, where Prismio's boxed layout mutated in place
// ran at 0.86x of an inline Vec: indirection was never the cost, the allocations
// were.
// **Everything here is a separate entry point.** The element type is a static
// fact at every call site, so codegen picks the family and the boxed ops keep
// the code they had. See the note on `elem_size` for the 1.159x that established
// this shape.
// Four facts hold the mode together, and each is load-bearing:
//  1. **A push builds in place where it can.** `list_push(l, T { ... })` lowers
//     to `list_push_slot` plus the literal's field stores, so the common push
//     allocates nothing and copies nothing. Five of the six corpus programs push
//     exactly that shape.
//  2. **A push that cannot build in place releases its source**, with the
//     container's own disposition: the bytes are copied out and the producer's
//     block is reclaimed exactly as `list_release` would have reclaimed it at
//     teardown. One owner, still the container; only the timing moved. Sound
//     because `list_push` is a move (semaConsumeOperand), so nothing may read
//     the source afterwards.
//  3. **Flat implies nothing to release per element.** No pointer inside T means
//     no owned field inside T, so an inline element's death is the block's and
//     teardown has no per-element work at all.
//  4. **Every entry point falls back to the boxed path when the list is not
//     inline.** Codegen decides per element *type* and the runtime stamps
//     lazily, so the two can only disagree by the list having been boxed first
//     -- and then the fallback keeps it boxed instead of writing a body where a
//     pointer belongs.

void list_push(void* lp, void* value);
void list_set(void* lp, int index, void* value);
void list_release(void* lp);
void rc_release(void* p);
void cyc_release(void* p);
void rc_release_atomic(void* p);

// Opt-out, kept while the mode is measured, exactly as PRISMIO_INLINE_RUNTIME is
// for M1.1: with it off the same binary runs every list boxed, so a result is a
// variable away rather than a revert.
static int list_inline_enabled(void) {
    static int cached = -1;
    if (cached < 0) {
        const char* v = getenv("PRISMIO_INLINE_ELEMS");
        cached = (v && v[0] == '0' && v[1] == 0) ? 0 : 1;
    }
    return cached;
}

// An element body is a handful of words, and its size is a constant at every
// site that matters -- but it reaches the runtime as a variable, so `memcpy`
// here would be a libc call with a dynamic length. This is what a constant-size
// memcpy would have become.
static void list_copy_elem(void* dst, const void* src, size_t size) {
    if ((size & 7) == 0) {
        unsigned long long* d = (unsigned long long*)dst;
        const unsigned long long* s = (const unsigned long long*)src;
        for (size_t i = 0, n = size >> 3; i < n; i++) d[i] = s[i];
        return;
    }
    if ((size & 3) == 0) {
        unsigned int* d = (unsigned int*)dst;
        const unsigned int* s = (const unsigned int*)src;
        for (size_t i = 0, n = size >> 2; i < n; i++) d[i] = s[i];
        return;
    }
    memcpy(dst, src, size);
}

// Switch an empty list to inline storage. Stamped by codegen at construction
// when the element type is known there, and lazily by the push entry points when
// it is not -- `list_new()` types as `List<Invalid>` on its own, so an
// unannotated binding has no element type until something is pushed into it.
//
// Refused once anything is in the list, which is fact 4: a half-converted list
// would read a pointer block as a body block.
void list_set_elem_inline(void* lp, int elem_size) {
    if (!lp || elem_size <= 0) return;
    if (!list_inline_enabled()) return;
    RtList* l = (RtList*)lp;
    if (l->elem_size || l->len) return;
    // **A counted element cannot be inline.** A reference count lives in a
    // header in front of the object, and an inline body has no header and no
    // identity of its own -- so `rc_retain` on a push and `rc_release` on a
    // teardown would both be operating on the middle of the element block. The
    // container is told its disposition before its first push
    // (`list_set_elem_owner`), which is what makes this the one place both the
    // stamp codegen emits and the lazy stamp below can be gated.
    //
    // test_48 is the fixture: an `Item` shared between two containers is T3, and
    // pushing `list_get(a, 0)` into `b` released an interior pointer.
    if (l->elem_own == AIF_ELEM_RC || l->elem_own == AIF_ELEM_CYCLE
        || l->elem_own == AIF_ELEM_RC_ATOMIC || l->elem_own == AIF_ELEM_CYCLE_ATOMIC) {
        return;
    }
    l->elem_size = elem_size;
    // The pointer block `list_new` made is the wrong width for bodies. Replaced
    // rather than reused, once, at a point where the list is empty.
    if (!l->arena) rt_free(l->data);
    size_t bytes = (size_t)l->cap * (size_t)elem_size;
    l->data = (void**)(l->arena ? arena_alloc_at(l->arena, bytes) : rt_alloc(bytes));
}

// Storage is one contiguous block that **doubles like the boxed one does**, so a
// sequential walk is a sequential walk and LLVM sees a constant stride.
//
// The consequence is the one SPEC 8.4 is about: growth moves the block, so the
// address of an element is not stable across a push. Nothing in the language
// hands that address out today -- `list_get` on an inline list is resolved at
// each access from the list handle, which is exactly the (handle, index) view
// SPEC 8.4 requires and not an interior pointer the program may keep. A chunked
// layout that *did* keep addresses stable was measured first, and cost 1.14x
// against this one on the corpus: two dependent loads and a count-leading-zeros
// per access, against a load and a multiply-add.
static void list_inline_grow(RtList* l) {
    int nc = l->cap * 2;
    size_t bytes = (size_t)nc * (size_t)l->elem_size;
    unsigned char* nd = l->arena ? (unsigned char*)arena_alloc_at(l->arena, bytes)
                                 : (unsigned char*)rt_alloc(bytes);
    list_copy_elem(nd, l->data, (size_t)l->len * (size_t)l->elem_size);
    if (!l->arena) rt_free(l->data);
    l->data = (void**)nd;
    l->cap = nc;
}

// Fact 2. The disposition `list_release` would have applied to this element at
// teardown, applied now that its bytes have been copied out of it.
//
// The arena guard is `list_release`'s, for its reason: a region reclaims in bulk
// and every pointer inside one is interior to a chunk.
static void list_release_source(RtList* l, void* e) {
    if (!e || l->arena) return;
    if (l->elem_own == AIF_ELEM_NONE) return;
    if (l->elem_own == AIF_ELEM_LIST)              list_release(e);
    else if (l->elem_own == AIF_ELEM_RC)           rc_release(e);
    else if (l->elem_own == AIF_ELEM_CYCLE)        cyc_release(e);
    else if (l->elem_own == AIF_ELEM_RC_ATOMIC)    rc_release_atomic(e);
    else if (l->elem_own == AIF_ELEM_CYCLE_ATOMIC) { rc_release_atomic(e); cyc_release(e); }
    else if (l->elem_own == AIF_ELEM_TYPED) { if (l->elem_release) l->elem_release(e); }
    else                                            rt_free(e);
}

// Fact 1. The address of a freshly reserved element, so a pushed struct literal
// is built in the list instead of built somewhere and copied in. Codegen emits
// the literal's field stores against what this returns.
//
// The size is a parameter so an unstamped-but-empty list can stamp itself here:
// this is the one entry point that has the element type and the list together
// with nothing pushed yet.
void* list_push_slot(void* lp, int elem_size) {
    RtList* l = (RtList*)lp;
    if (!l->elem_size) {
        if (l->len == 0) list_set_elem_inline(lp, elem_size);
        // Fact 4: still boxed, either because the knob is off or because this
        // list was pushed into through the boxed path first. A body written into
        // a pointer slot would be silent corruption, so allocate one.
        if (!l->elem_size) {
            void* box = rt_alloc((size_t)(elem_size > 0 ? elem_size : 1));
            list_push(lp, box);
            return box;
        }
    }
    if (l->len >= l->cap) list_inline_grow(l);
    void* slot = (unsigned char*)l->data + (size_t)l->len * (size_t)l->elem_size;
    l->len = l->len + 1;
    return slot;
}

// The push a value that already exists takes: g1's `list_push(ps,
// spawn_particle(f))` is the shape, where the producer is a call and there is no
// literal to redirect.
void list_push_inline(void* lp, void* value, int elem_size) {
    RtList* l = (RtList*)lp;
    if (!l->elem_size) {
        if (l->len == 0) list_set_elem_inline(lp, elem_size);
        if (!l->elem_size) { list_push(lp, value); return; }
    }
    if (l->len >= l->cap) list_inline_grow(l);
    list_copy_elem((unsigned char*)l->data + (size_t)l->len * (size_t)l->elem_size,
                   value, (size_t)l->elem_size);
    l->len = l->len + 1;
    list_release_source(l, value);
}

// SPEC 8.4's element view, resolved. The address is computed from the list
// handle and the index at every access rather than kept, which is what makes a
// moving block safe.
void* list_get_inline(void* lp, int index) {
    RtList* l = (RtList*)lp;
    if (index < 0 || index >= l->len) return 0;
    if (!l->elem_size) return l->data[index];
    return (unsigned char*)l->data + (size_t)index * (size_t)l->elem_size;
}

// Overwriting an inline element overwrites bytes, so the leak `list_set`'s own
// note describes cannot arise here: a flat element owns nothing, and what
// occupied the slot was never separately allocated.
void list_set_inline(void* lp, int index, void* value) {
    RtList* l = (RtList*)lp;
    if (!l->elem_size) { list_set(lp, index, value); return; }
    if (index < 0 || index >= l->len) return;
    list_copy_elem((unsigned char*)l->data + (size_t)index * (size_t)l->elem_size,
                   value, (size_t)l->elem_size);
    list_release_source(l, value);
}

// REQUIREMENTS 4. The checked unwrap behind `expect(x)`.
//
// A function rather than a branch in codegen, and returning its argument rather
// than being void, so the whole thing is one ordinary call expression -- no new
// blocks, no new backend surface, and the failure is loud instead of a null
// dereference somewhere downstream.
void* prismio_expect(void* p) {
    if (!p) {
        fprintf(stderr, "runtime error: expect() called on a `none` value\n");
        exit(1);
    }
    return p;
}

// The growth half of list_push, outlined so the other half can be inlined.
//
// M1.1 makes the hot container ops available to the inliner as
// `available_externally` bodies. `list_push` was the one that never took: the
// inliner priced it at **cost=675 against a threshold of 225** and declined at
// every site, because the realloc-and-copy below is 159 of its 227 IR lines and
// runs once per doubling rather than once per push. Measured: with it outlined,
// `list_push` drops to 69 IR lines, every `bl _list_push` in the corpus
// disappears, and g5 -- fifteen push sites -- runs **1.87x** faster than with
// the seven-op curated set.
//
// It takes `void*` rather than `RtList*` so the exported surface stays the
// same shape as every other op here and the struct stays private to this file.
//
// **It has to be exported.** A curated body may only reference symbols the
// runtime object actually defines; `static` here would put an undefined
// `_list_push_grow` in every program that inlined the fast path.
// run_curated_closure_test is what enforces that, and it is why the three
// `static`s this function still touches -- rt_arena_hint, arena_depth,
// arena_alloc_slot, all reached through rt_alloc -- stay on this side of the
// split and out of the inlined half.
void list_push_grow(void* lp) {
    RtList* l = (RtList*)lp;
    int nc = l->cap * 2;
    // Back into the arena that owns this list, not into whatever the hint
    // says right now: the push is usually outside the bracket that created
    // the list, so rt_alloc here would take the heap and the block below
    // would be an arena pointer handed to free().
    void** nd = l->arena ? (void**)arena_alloc_at(l->arena, sizeof(void*) * (size_t)nc)
                         : (void**)rt_alloc(sizeof(void*) * (size_t)nc);
    for (int i = 0; i < l->len; i++) nd[i] = l->data[i];
    if (!l->arena) rt_free(l->data);
    l->data = nd;
    l->cap = nc;
}

void list_push(void* lp, void* value) {
    RtList* l = (RtList*)lp;
    // AIF Level 5. The retain and the release are the same container's, driven by
    // the same stamped mode, so they cannot disagree about whether an element is
    // counted -- which is the failure a per-element answer would invite.
    if (l->elem_own == AIF_ELEM_RC) rc_retain(value);
    if (l->elem_own == AIF_ELEM_CYCLE) cyc_retain(value);
    if (l->elem_own == AIF_ELEM_RC_ATOMIC) rc_retain_atomic(value);
    if (l->elem_own == AIF_ELEM_CYCLE_ATOMIC) { rc_retain_atomic(value); cyc_retain(value); }
    if (l->len >= l->cap) list_push_grow(lp);
    l->data[l->len] = value;
    l->len = l->len + 1;
}

// AIF Level 4. A list is two allocations -- the handle and the element block --
// so the deallocator seam, which takes one pointer and frees it, cannot reclaim
// it: `free(list)` leaks the block. Codegen calls this instead for a droppable
// List binding, which is why the drop list carries a kind and not just a slot.
//
// AIF item 3: the elements go too, when the container was told it owns them.
// That reverses Level 4's rule, and the reason the old one was right then is the
// reason it is wrong now. It read `list_push` as `retain_in(0)` -- the element's
// escape becomes the list's -- and concluded that whoever owns the element owns
// it at its own binding. Nobody does: an element's escape is the container's, so
// aif_frees_at_scope_node declines the binding, and until something released
// here every element of every list leaked. One owner, and it is this one.
//
// Reverse order, as everywhere else a scope unwinds: an element may hold a
// reference to one pushed before it, never after.
void list_release(void* lp) {
    if (!lp) return;
    RtList* l = (RtList*)lp;
    // SPEC 5.2.1.1. An arena reclaims in bulk when its region exits, so there is
    // nothing here to do and every free below would be a pointer into the middle
    // of a chunk. Codegen should not emit this call at all for such a list --
    // aif_frees_at_scope_node and aif_owns_call_result_at_node both decline once
    // the site is arena-served -- so this is the second line of defence, not the
    // mechanism. It is here because the failure it guards is heap corruption and
    // the cost of the guard is one predictable branch.
    if (l->arena) return;
    // M4.2, fact 3: a flat element owns nothing and was never separately
    // allocated, so the whole of an inline list's teardown is its block. Once
    // per list, unlike the three hot ops, so the branch is affordable here.
    if (l->elem_size) { rt_free(l->data); rt_free(l); return; }
    if (l->elem_own != AIF_ELEM_NONE) {
        for (int i = l->len - 1; i >= 0; i--) {
            void* e = l->data[i];
            if (!e) continue;
            if (l->elem_own == AIF_ELEM_LIST)    list_release(e);
            else if (l->elem_own == AIF_ELEM_RC) rc_release(e);
            else if (l->elem_own == AIF_ELEM_CYCLE) cyc_release(e);
            else if (l->elem_own == AIF_ELEM_RC_ATOMIC) rc_release_atomic(e);
            // SPEC 3's "a value meeting both conditions pays both", and the
            // order is forced: cyc_release is what buffers a candidate root, so
            // it has to see the count *after* this thread's decrement.
            else if (l->elem_own == AIF_ELEM_CYCLE_ATOMIC) { rc_release_atomic(e); cyc_release(e); }
            else if (l->elem_own == AIF_ELEM_TYPED) {
                // Struct-field ownership. The element owns fields of its own, so
                // rt_free(e) here would reclaim the object and leak everything
                // hanging off it -- which is exactly what g3_scene_graph did with
                // 1365 Nodes and three owned fields each.
                if (l->elem_release) l->elem_release(e);
            }
            else                                  rt_free(e);
        }
    }
    rt_free(l->data);
    rt_free(l);
}

void* list_get(void* lp, int index) {
    RtList* l = (RtList*)lp;
    if (index < 0 || index >= l->len) return 0;
    return l->data[index];
}

// The overwritten element is released only under RC, where the container's own
// count says whether anything else still holds it. Under OBJECT it leaks: the
// container owns it, but so might the binding the value came from, and a free
// here would be the double free the whole ownership rule exists to prevent.
void list_set(void* lp, int index, void* value) {
    RtList* l = (RtList*)lp;
    if (index < 0 || index >= l->len) return;
    if (l->elem_own == AIF_ELEM_RC) {
        rc_retain(value);
        rc_release(l->data[index]);
    } else if (l->elem_own == AIF_ELEM_RC_ATOMIC
               || l->elem_own == AIF_ELEM_CYCLE_ATOMIC) {
        // Retain before release, as above: if the incoming value is the one
        // already in the slot, releasing first can take the count to zero and
        // free what is about to be stored.
        rc_retain_atomic(value);
        rc_release_atomic(l->data[index]);
    }
    l->data[index] = value;
}

// Boxed replacement with a compiler-proved exclusive handle. Unlike list_set,
// this operation owns the displaced slot and may apply the same release that
// list teardown would. The store happens first so a counted self-replacement
// cannot leave the slot pointing at memory released by the old ownership edge.
// Sema admits this symbol only for non-flat struct Lists created locally and
// not observed through list_get, indexing, slicing, or an arbitrary call.
void list_set_exclusive(void* lp, int index, void* value) {
    RtList* l = (RtList*)lp;
    if (index < 0 || index >= l->len) {
        fprintf(stderr, "runtime error: list_set_exclusive index %d out of bounds for length %d\n",
                index, l->len);
        exit(1);
    }
    if (l->elem_size) {
        fprintf(stderr, "runtime error: list_set_exclusive requires boxed elements\n");
        exit(1);
    }
    void* old = l->data[index];
    l->data[index] = value;
    list_release_source(l, old);
}

int list_len(void* lp) {
    RtList* l = (RtList*)lp;
    return l->len;
}

// M4.3 -- explicit AoS <-> SoA data views. `soa` consumes one ordinary
// List<T> at one program point and builds one allocation per physical field;
// `aos` consumes that view and materialises rows again.
typedef struct {
    unsigned char* data;
    int offset;
    int size;
} RtDataColumn;

typedef struct {
    RtList* source;
    RtDataColumn* columns;
    int len;
    int field_count;
    int built_fields;
    int elem_size;
    int arena;
} RtDataView;

// Kept in program_support.c so the curated -O2 compile of this translation unit
// sees an opaque exported call. If the noreturn body is visible here, Clang
// outlines each failure edge into a private `.cold` helper; extracting only the
// inlinable check then leaves those private helpers undefined.
__attribute__((noreturn)) void data_view_fail(const char* message);
__attribute__((noreturn)) void data_view_access_fail(int reason);

void* data_view_begin(void* list, int field_count, int elem_size) {
    if (!list) data_view_fail("null source list");
    if (field_count <= 0 || elem_size <= 0) data_view_fail("invalid struct layout");

    RtList* source = (RtList*)list;
    RtDataView* view = (RtDataView*)rt_alloc(sizeof(RtDataView));
    view->source = source;
    view->columns = (RtDataColumn*)rt_alloc(sizeof(RtDataColumn) * (size_t)field_count);
    view->len = source->len;
    view->field_count = field_count;
    view->built_fields = 0;
    view->elem_size = elem_size;
    view->arena = rt_arena_slot();
    for (int i = 0; i < field_count; i++) {
        view->columns[i].data = 0;
        view->columns[i].offset = 0;
        view->columns[i].size = 0;
    }
    return view;
}

void data_view_add_column(void* vp, int field_index, int offset, int size) {
    RtDataView* view = (RtDataView*)vp;
    if (!view || !view->source) data_view_fail("column added outside construction");
    if (field_index < 0 || field_index >= view->field_count) data_view_fail("field index out of range");
    if (offset < 0 || size <= 0 || offset + size > view->elem_size) {
        data_view_fail("field layout outside element");
    }
    RtDataColumn* column = &view->columns[field_index];
    if (column->data) data_view_fail("field column added twice");

    column->offset = offset;
    column->size = size;
    if (view->len > 0) {
        column->data = (unsigned char*)rt_alloc((size_t)view->len * (size_t)size);
        for (int i = 0; i < view->len; i++) {
            unsigned char* row = view->source->elem_size
                ? (unsigned char*)view->source->data + (size_t)i * (size_t)view->source->elem_size
                : (unsigned char*)view->source->data[i];
            if (!row) data_view_fail("null row in source list");
            memcpy(column->data + (size_t)i * (size_t)size,
                   row + (size_t)offset,
                   (size_t)size);
        }
    }
    view->built_fields = view->built_fields + 1;
}

void data_view_finish(void* vp) {
    RtDataView* view = (RtDataView*)vp;
    if (!view || !view->source) data_view_fail("conversion already finished");
    if (view->built_fields != view->field_count) data_view_fail("not all field columns were built");
    list_release(view->source);
    view->source = 0;
}

int data_view_len(void* vp) {
    RtDataView* view = (RtDataView*)vp;
    return view ? view->len : 0;
}

// M4.3b. Validate the index once when the compiler forms the two-word element
// descriptor. Every field projection can then be a branch-free column lookup;
// the descriptor keeps the owning handle rather than an interior pointer.
void data_view_check_index(void* vp, int index) {
    RtDataView* view = (RtDataView*)vp;
    if (!view || view->source) data_view_access_fail(1);
    if (index < 0 || index >= view->len) data_view_access_fail(2);
}

// Ready-view metadata is immutable until the consuming release/materialisation.
// `const` exposes that language rule to non-curated builds too. The curated
// module additionally marks the two metadata loads invariant before this body
// is inlined, allowing LICM and vectorisation without executable assumptions.
__attribute__((const)) void* data_view_column(void* vp, int field_index) {
    RtDataView* view = (RtDataView*)vp;
    return view->columns[field_index].data;
}

void data_view_release(void* vp) {
    if (!vp) return;
    RtDataView* view = (RtDataView*)vp;
    if (view->source) list_release(view->source);
    if (view->arena) return;
    for (int i = view->field_count - 1; i >= 0; i--) {
        if (view->columns[i].data) rt_free(view->columns[i].data);
    }
    rt_free(view->columns);
    rt_free(view);
}

void* data_view_to_list(void* vp) {
    RtDataView* view = (RtDataView*)vp;
    if (!view || view->source) data_view_fail("view is not ready for materialisation");

    RtList* rows = (RtList*)list_new_with_capacity(view->len);
    list_set_elem_inline(rows, view->elem_size);
    for (int i = 0; i < view->len; i++) {
        unsigned char* row = (unsigned char*)list_push_slot(rows, view->elem_size);
        memset(row, 0, (size_t)view->elem_size);
        for (int field = 0; field < view->field_count; field++) {
            RtDataColumn* column = &view->columns[field];
            memcpy(row + (size_t)column->offset,
                   column->data + (size_t)i * (size_t)column->size,
                   (size_t)column->size);
        }
    }
    data_view_release(view);
    return rows;
}

// M4.1 -- handle-based List slices (SPEC 8.4)
//
// A Slice<T> is emitted as `{ RtList*, offset, length }` in Prismio code. The C
// runtime never owns or stores that aggregate; it receives its fields at the
// point of construction/access. Keeping the handle rather than `data + offset`
// is what makes a view survive list growth: every operation resolves the list's
// current data block after any reallocations have happened.
void prismio_slice_check(int available, int start, int end) {
    if (available < 0 || start < 0 || end < start || end > available) {
        fprintf(stderr,
                "runtime error: slice range [%d..%d] is outside collection length %d\n",
                start, end, available);
        exit(1);
    }
}

static int list_slice_index(void* lp, int offset, int length, int index) {
    if (!lp) {
        fprintf(stderr, "runtime error: slice refers to a null List handle\n");
        exit(1);
    }
    RtList* l = (RtList*)lp;
    long long actual = (long long)offset + (long long)index;
    if (offset < 0 || length < 0 || index < 0 || index >= length
        || actual < 0 || actual >= l->len) {
        fprintf(stderr,
                "runtime error: slice index %d is outside view [%d..%d] of collection length %d\n",
                index, offset, offset + length, l->len);
        exit(1);
    }
    return (int)actual;
}

void* list_slice_get(void* lp, int offset, int length, int index) {
    return list_get(lp, list_slice_index(lp, offset, length, index));
}

void* list_slice_get_inline(void* lp, int offset, int length, int index) {
    return list_get_inline(lp, list_slice_index(lp, offset, length, index));
}

void list_slice_set(void* lp, int offset, int length, int index, void* value) {
    list_set(lp, list_slice_index(lp, offset, length, index), value);
}

void list_slice_set_inline(void* lp, int offset, int length, int index, void* value) {
    list_set_inline(lp, list_slice_index(lp, offset, length, index), value);
}

// LAYOUT 2 -- the measured access profile
// These counters exist only in a workload driver: an instrumented build the
// compiler produces, runs and throws away (LAYOUT 3.2). A shipped program never
// calls any of them, which is why they are compiled unconditionally rather than
// behind a -D like PRISMIO_AIF_VERIFY. That define was needed because verify
// changes allocation *pairing* and both ends have to swap together; profiling
// changes nothing at all, it only counts, so a second runtime compile mode would
// buy nothing and would be one more thing that can be half-applied.
// **W4 is what this arrangement is for.** "Two builds with different profiles
// SHALL produce behaviourally identical programs" is not enforced here by
// checking anything -- it holds because the profile reaches codegen only through
// the layout search, and the shipped binary contains no call to any function
// below. The instrumented binary is a different artifact with a different main.
// The counters are deliberately unsynchronised. A workload runs single-threaded
// by construction (the driver is generated, and the corpus is single-threaded);
// if that stops being true this is the line that breaks, and it should become a
// per-task table merged at the end rather than a lock, so the measurement does
// not serialise the thing it is measuring.

#define RT_PROF_SLOTS 8192

typedef struct {
    const char* type;
    const char* field;
    long long   reads;
    long long   writes;
    long long   lo;
    long long   hi;
    int         has_range;
    int         used;
} RtProfField;

typedef struct {
    const char* type;
    long long   allocs;
    long long   live;
    long long   peak_live;
    int         used;
} RtProfType;

static RtProfField g_prof_fields[RT_PROF_SLOTS];
static RtProfType  g_prof_types[RT_PROF_SLOTS];

// `setup` runs with this at 0 and `measure` with it at 1, which is the whole of
// LAYOUT 3.1's "setup is excluded". It is a counter rather than a flag so a
// nested measure region -- which the grammar does not have today -- could not
// switch it off early.
static int g_prof_depth = 0;

static unsigned rt_prof_hash(const char* a, const char* b) {
    unsigned h = 2166136261u;
    for (const char* p = a; p && *p; p++) { h ^= (unsigned char)*p; h *= 16777619u; }
    h ^= '.'; h *= 16777619u;
    for (const char* p = b; p && *p; p++) { h ^= (unsigned char)*p; h *= 16777619u; }
    return h;
}

// Linear probing, and a full table drops counts rather than growing. Dropping is
// the right failure here: a profile is an estimate consumed by a cost model, and
// a rehash in the middle of a measured region would cost more than the sample is
// worth. RT_PROF_SLOTS is 8192 against a corpus whose largest program has 34
// (type, field) pairs, so the table is three orders of magnitude oversized; if it
// ever fills, the dropped counts make the profile wrong in the *conservative*
// direction -- a field that looks colder than it is stays where the source put it.
static RtProfField* rt_prof_slot(const char* type, const char* field) {
    unsigned h = rt_prof_hash(type, field) & (RT_PROF_SLOTS - 1);
    for (int probe = 0; probe < RT_PROF_SLOTS; probe++) {
        RtProfField* s = &g_prof_fields[(h + probe) & (RT_PROF_SLOTS - 1)];
        if (!s->used) {
            s->used = 1;
            s->type = type;
            s->field = field;
            return s;
        }
        if (strcmp(s->type, type) == 0 && strcmp(s->field, field) == 0) return s;
    }
    return 0;
}

static RtProfType* rt_prof_type_slot(const char* type) {
    unsigned h = rt_prof_hash(type, "") & (RT_PROF_SLOTS - 1);
    for (int probe = 0; probe < RT_PROF_SLOTS; probe++) {
        RtProfType* s = &g_prof_types[(h + probe) & (RT_PROF_SLOTS - 1)];
        if (!s->used) {
            s->used = 1;
            s->type = type;
            return s;
        }
        if (strcmp(s->type, type) == 0) return s;
    }
    return 0;
}

void rt_profile_begin(void) { g_prof_depth++; }
void rt_profile_end(void)   { if (g_prof_depth > 0) g_prof_depth--; }

void rt_profile_field(const char* type, const char* field, int is_write) {
    if (!g_prof_depth) return;
    RtProfField* s = rt_prof_slot(type, field);
    if (!s) return;
    if (is_write) s->writes++; else s->reads++;
}

// LAYOUT 2.1 marks `range` **dynamic only**, and this is why: it is the observed
// value range, which no amount of reading the source supplies. It is also the
// only input bit-packing has -- without a workload there is nothing to pack
// against, which is why the packing dimension could not be searched before now.
//
// Recorded on writes only. A read observes a value some write already put there,
// so counting reads would weight the range by how often a field is looked at
// rather than by what it can hold.
void rt_profile_range(const char* type, const char* field, long long value) {
    if (!g_prof_depth) return;
    RtProfField* s = rt_prof_slot(type, field);
    if (!s) return;
    if (!s->has_range) {
        s->has_range = 1;
        s->lo = value;
        s->hi = value;
        return;
    }
    if (value < s->lo) s->lo = value;
    if (value > s->hi) s->hi = value;
}

void rt_profile_alloc(const char* type) {
    if (!g_prof_depth) return;
    RtProfType* s = rt_prof_type_slot(type);
    if (!s) return;
    s->allocs++;
    s->live++;
    if (s->live > s->peak_live) s->peak_live = s->live;
}

// `live` is decremented wherever the object is released. It is best-effort by
// construction: a value reclaimed with its arena is never individually freed, so
// peak_live reads as the high-water of *allocations* for arena-served types
// rather than of live instances. LAYOUT 2.1 wants peak live instances; this
// over-reports it, which biases mu_for toward a larger footprint and therefore
// toward the layout that touches fewer bytes. Conservative in the direction that
// matters, and recorded here rather than presented as exact.
void rt_profile_release(const char* type) {
    if (!g_prof_depth) return;
    RtProfType* s = rt_prof_type_slot(type);
    if (!s) return;
    if (s->live > 0) s->live--;
}

// LAYOUT 2.2's format, sorted, so two runs of the same workload produce
// byte-identical files and the profile can be diffed and checked in.
static int rt_prof_field_cmp(const void* a, const void* b) {
    const RtProfField* x = *(const RtProfField* const*)a;
    const RtProfField* y = *(const RtProfField* const*)b;
    int c = strcmp(x->type, y->type);
    return c ? c : strcmp(x->field, y->field);
}

static int rt_prof_type_cmp(const void* a, const void* b) {
    const RtProfType* x = *(const RtProfType* const*)a;
    const RtProfType* y = *(const RtProfType* const*)b;
    return strcmp(x->type, y->type);
}

int rt_profile_dump(const char* path, const char* workload, int runs) {
    FILE* f = fopen(path, "w");
    if (!f) return 1;

    fprintf(f, "aif-profile 1\n");
    fprintf(f, "source      workload:%s\n", workload ? workload : "?");
    fprintf(f, "runs        %d\n", runs);
    fprintf(f, "#\n# type              allocs      live\n");

    RtProfType* types[RT_PROF_SLOTS];
    int ntypes = 0;
    for (int i = 0; i < RT_PROF_SLOTS; i++) {
        if (g_prof_types[i].used) types[ntypes++] = &g_prof_types[i];
    }
    qsort(types, (size_t)ntypes, sizeof(types[0]), rt_prof_type_cmp);
    for (int i = 0; i < ntypes; i++) {
        fprintf(f, "type  %-16s %10lld %9lld\n",
                types[i]->type, types[i]->allocs, types[i]->peak_live);
    }

    fprintf(f, "#\n# type.field         reads       writes    range\n");
    RtProfField* fields[RT_PROF_SLOTS];
    int nfields = 0;
    for (int i = 0; i < RT_PROF_SLOTS; i++) {
        if (g_prof_fields[i].used) fields[nfields++] = &g_prof_fields[i];
    }
    qsort(fields, (size_t)nfields, sizeof(fields[0]), rt_prof_field_cmp);
    for (int i = 0; i < nfields; i++) {
        RtProfField* s = fields[i];
        if (s->has_range) {
            fprintf(f, "field %s.%-14s %10lld %10lld %lld..%lld\n",
                    s->type, s->field, s->reads, s->writes, s->lo, s->hi);
        } else {
            fprintf(f, "field %s.%-14s %10lld %10lld -\n",
                    s->type, s->field, s->reads, s->writes);
        }
    }

    fclose(f);
    return 0;
}

// W3. Every extern the workload's module declares that the Prismio runtime does
// not itself define is replaced by a stub with this body, rather than linked
// against whatever libc happens to export. A workload that calls `system` or
// `fopen` is not reproducible, so it is not a workload -- but refusing to build
// it would fail the build, which W2 forbids. Warning and returning zero is the
// third option and the one the clause asks for.
//
// Warns once per symbol. A stubbed call inside the measured loop would otherwise
// print millions of lines and turn a diagnostic into the dominant cost of the
// run.
#define RT_STUB_WARNED_MAX 64
static const char* g_stub_warned[RT_STUB_WARNED_MAX];
static int g_stub_warned_n = 0;

long long rt_workload_stub(const char* name) {
    for (int i = 0; i < g_stub_warned_n; i++) {
        if (strcmp(g_stub_warned[i], name) == 0) return 0;
    }
    if (g_stub_warned_n < RT_STUB_WARNED_MAX) {
        g_stub_warned[g_stub_warned_n++] = name;
    }
    fprintf(stderr,
            "warning: workload called `%s`, which the build sandbox does not provide; "
            "it returned 0\n", name);
    return 0;
}
